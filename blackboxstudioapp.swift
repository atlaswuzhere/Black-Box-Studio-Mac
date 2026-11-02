//
//  BlackBoxStudioApp.swift
//  BLACKBOX Studio — Native macOS App (Xcode / SwiftUI + AppKit + WKWebView)
//
//  Wraps the BLACKBOX Personal Audio System web engine (index.html, app.js, style.css,
//  mini.html, mini.js, config.json) into a true native macOS application with:
//    1. Native NSOpenPanel + Security-Scoped Bookmarks polyfilling window.showDirectoryPicker()
//       and IndexedDB handle persistence so your music folder persists across app restarts.
//    2. Local embedded HTTP/Range asset & audio server (127.0.0.1) so Fetch, Web Audio API
//       (dual-deck crossfade + 10-band EQ + canvas visualizers), and BroadcastChannel work
//       with zero CORS restrictions.
//    3. Native floating Always-On-Top NSPanel for the BLACKBOX Mini Player (mini.html)
//       sharing the same WKProcessPool so BroadcastChannel('blackbox-player-v1') syncs live.
//    4. macOS Media Keys & Control Center integration (MPNowPlayingInfoCenter &
//       MPRemoteCommandCenter) for hardware Play/Pause, Next, Previous, and scrubbing.
//

import SwiftUI
import AppKit
import WebKit
import MediaPlayer
import Network

// MARK: - App Entry Point

@main
struct BlackBoxStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("BLACKBOX — Personal Audio System") {
            MainPlayerView(controller: appDelegate.playerController)
                .frame(minWidth: 1020, minHeight: 680)
                .background(Color(red: 0.06, green: 0.05, blue: 0.04))
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Connect Music Folder…") {
                    appDelegate.playerController.triggerConnectFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Rescan Music Library") {
                    appDelegate.playerController.evaluateJS(
                        "if (window.__blackboxRescanNative) window.__blackboxRescanNative();"
                    )
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Playback") {
                Button("Play / Pause") {
                    appDelegate.playerController.sendPlayerCommand("toggle-play")
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Next Track") {
                    appDelegate.playerController.sendPlayerCommand("next")
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Previous Track") {
                    appDelegate.playerController.sendPlayerCommand("previous")
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Divider()

                Button("Toggle Mini Player Window") {
                    appDelegate.playerController.toggleMiniPlayerWindow()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let playerController = BlackBoxPlayerController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        playerController.startServerAndMediaKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        playerController.stopServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Local Loopback HTTP + Audio Streaming Server

/// Replaces Start-BlackBox-Web.ps1 with a native Swift POSIX socket HTTP server bound strictly
/// to 127.0.0.1. Serves both the bundled web UI assets and user-selected Music Folder files
/// (including HTTP Range requests for instant audio seeking in WebKit).
final class LocalAudioHTTPServer {
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.blackboxstudio.httpserver", qos: .userInteractive, attributes: .concurrent)
    private(set) var port: UInt16 = 8765

    var webRootURL: URL
    var mountedMusicFolderURL: URL?

    init(webRootURL: URL) {
        self.webRootURL = webRootURL
    }

    func start() -> UInt16 {
        guard !isRunning else { return port }

        for candidatePort: UInt16 in 8765...8795 {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else { continue }

            var yes: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = candidatePort.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if bindResult == 0 && listen(sock, 128) == 0 {
                self.serverSocket = sock
                self.port = candidatePort
                self.isRunning = true
                acceptLoop()
                return candidatePort
            } else {
                close(sock)
            }
        }
        return port
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptLoop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            while self.isRunning && self.serverSocket >= 0 {
                var clientAddr = sockaddr_in()
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                let clientSock = withUnsafeMutablePointer(to: &clientAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        accept(self.serverSocket, $0, &len)
                    }
                }
                if clientSock >= 0 {
                    self.queue.async {
                        self.handleClient(clientSock)
                    }
                }
            }
        }
    }

    private func handleClient(_ sock: Int32) {
        var one: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        defer { close(sock) }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = recv(sock, &buffer, buffer.count - 1, 0)
        guard bytesRead > 0 else { return }

        let requestString = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }

        let rawPath = String(parts[1]).components(separatedBy: "?").first ?? "/"
        let decodedPath = rawPath.removingPercentEncoding ?? rawPath

        // Parse optional Range header for audio scrubbing
        var rangeHeader: String? = nil
        for line in lines where line.lowercased().hasPrefix("range:") {
            rangeHeader = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
        }

        // Route 1: /__native_music__/<relativePath> serves files from the user's selected Music Folder
        if decodedPath.hasPrefix("/__native_music__/") {
            guard let musicRoot = mountedMusicFolderURL else {
                send404(sock)
                return
            }
            let relPath = String(decodedPath.dropFirst("/__native_music__/".count))
            let targetURL = musicRoot.appendingPathComponent(relPath).standardizedFileURL
            guard targetURL.path.hasPrefix(musicRoot.standardizedFileURL.path) else {
                send404(sock)
                return
            }
            serveFile(sock: sock, fileURL: targetURL, rangeHeader: rangeHeader)
            return
        }

        // Route 2: Static web UI files (index.html, app.js, style.css, mini.html, mini.js, config.json)
        let cleanRel = decodedPath == "/" ? "index.html" : String(decodedPath.dropFirst())
        let fileURL = webRootURL.appendingPathComponent(cleanRel).standardizedFileURL
        guard fileURL.path.hasPrefix(webRootURL.standardizedFileURL.path) else {
            send404(sock)
            return
        }
        serveFile(sock: sock, fileURL: fileURL, rangeHeader: rangeHeader)
    }

    private func serveFile(sock: Int32, fileURL: URL, rangeHeader: String?) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue,
              let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = (attrs[.size] as? NSNumber)?.intValue else {
            send404(sock)
            return
        }

        let mime = Self.mimeType(for: fileURL.pathExtension)
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            send404(sock)
            return
        }
        defer { try? fileHandle.close() }

        if let rangeStr = rangeHeader, rangeStr.hasPrefix("bytes=") {
            let spec = rangeStr.dropFirst("bytes=".count).split(separator: "-", omittingEmptySubsequences: false)
            let start = Int(spec.first ?? "0") ?? 0
            let end = (spec.count > 1 && !spec[1].isEmpty) ? (Int(spec[1]) ?? (fileSize - 1)) : (fileSize - 1)
            let clampedStart = max(0, min(start, fileSize - 1))
            let clampedEnd = max(clampedStart, min(end, fileSize - 1))
            let length = clampedEnd - clampedStart + 1

            let header = [
                "HTTP/1.1 206 Partial Content",
                "Content-Type: \(mime)",
                "Content-Length: \(length)",
                "Content-Range: bytes \(clampedStart)-\(clampedEnd)/\(fileSize)",
                "Accept-Ranges: bytes",
                "Access-Control-Allow-Origin: *",
                "Cache-Control: no-cache",
                "Connection: close",
                "",
                ""
            ].joined(separator: "\r\n")

            sendAll(sock: sock, data: Data(header.utf8))
            try? fileHandle.seek(toOffset: UInt64(clampedStart))
            if let chunk = try? fileHandle.read(upToCount: length) {
                sendAll(sock: sock, data: chunk)
            }
        } else {
            let header = [
                "HTTP/1.1 200 OK",
                "Content-Type: \(mime)",
                "Content-Length: \(fileSize)",
                "Accept-Ranges: bytes",
                "Access-Control-Allow-Origin: *",
                "Cache-Control: no-cache",
                "Connection: close",
                "",
                ""
            ].joined(separator: "\r\n")

            sendAll(sock: sock, data: Data(header.utf8))
            if let data = try? fileHandle.readToEnd() {
                sendAll(sock: sock, data: data)
            }
        }
    }

    private func send404(_ sock: Int32) {
        let body = "404 Not Found"
        let header = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        sendAll(sock: sock, data: Data(header.utf8))
    }

    private func sendAll(sock: Int32, data: Data) {
        data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return }
            var sent = 0
            while sent < data.count {
                let n = send(sock, base.advanced(by: sent), data.count - sent, 0)
                if n <= 0 { break }
                sent += n
            }
        }
    }

    static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js":   return "application/javascript; charset=utf-8"
        case "css":  return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "svg":  return "image/svg+xml"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "mp3":  return "audio/mpeg"
        case "wav":  return "audio/wav"
        case "flac": return "audio/flac"
        case "m4a", "m4b": return "audio/mp4"
        case "aac":  return "audio/aac"
        case "ogg", "opus": return "audio/ogg"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - Main Player Controller (WKWebView + Native Folder Bridge + Mini Window + Media Keys)

final class BlackBoxPlayerController: NSObject, ObservableObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
    private(set) var mainWebView: WKWebView!
    private var miniWebView: WKWebView?
    private var miniPanel: NSPanel?
    private var httpServer: LocalAudioHTTPServer!
    private let processPool = WKProcessPool()

    private let bookmarkDefaultsKey = "BlackBoxSavedMusicFolderBookmark"
    private var activeSecurityScopedURL: URL?

    private let supportedExtensions: Set<String> = [
        "mp3", "wav", "flac", "m4a", "m4b", "aac", "ogg", "opus", "wma", "lrc", "txt", "jpg", "jpeg", "png"
    ]

    override init() {
        super.init()

        // Locate bundled web root (either inside .app/Contents/Resources/WebUI or repo root)
        let bundleRoot = Bundle.main.resourceURL?.appendingPathComponent("WebUI")
        let fallbackRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedRoot: URL
        if let bundleRoot = bundleRoot,
           FileManager.default.fileExists(atPath: bundleRoot.appendingPathComponent("index.html").path) {
            resolvedRoot = bundleRoot
        } else if let resRoot = Bundle.main.resourceURL,
                  FileManager.default.fileExists(atPath: resRoot.appendingPathComponent("index.html").path) {
            resolvedRoot = resRoot
        } else {
            resolvedRoot = fallbackRoot
        }

        self.httpServer = LocalAudioHTTPServer(webRootURL: resolvedRoot)
        restoreSavedMusicFolderBookmark()
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let userContent = WKUserContentController()
        userContent.add(self, name: "blackboxNative")

        // Inject native macOS polyfill for window.showDirectoryPicker + IndexedDB handle cloning + NowPlaying sync
        let bridgeScript = WKUserScript(
            source: Self.nativeBridgeJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContent.addUserScript(bridgeScript)
        config.userContentController = userContent

        mainWebView = WKWebView(frame: .zero, configuration: config)
        mainWebView.uiDelegate = self
        mainWebView.navigationDelegate = self
        mainWebView.setValue(false, forKey: "drawsBackground")
    }

    func startServerAndMediaKeys() {
        let port = httpServer.start()
        setupRemoteTransportControls()
        if let url = URL(string: "http://127.0.0.1:\(port)/index.html") {
            mainWebView.load(URLRequest(url: url))
        }
    }

    func stopServer() {
        httpServer.stop()
        if let scoped = activeSecurityScopedURL {
            scoped.stopAccessingSecurityScopedResource()
        }
    }

    func evaluateJS(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.mainWebView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    // MARK: - Native Music Folder Picker & Security-Scoped Bookmark Persistence

    func triggerConnectFolder() {
        DispatchQueue.main.async { [weak self] in
            self?.presentNativeFolderPicker(requestId: nil)
        }
    }

    private func presentNativeFolderPicker(requestId: String?) {
        let panel = NSOpenPanel()
        panel.title = "Select Your BLACKBOX Music Folder"
        panel.message = "Choose a folder containing your local audio files (.mp3, .flac, .m4a, .wav, .ogg, .aac)."
        panel.prompt = "Connect Music Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let folderURL = panel.url {
                self.saveMusicFolderBookmark(folderURL)
                self.mountAndSendFolderManifest(folderURL: folderURL, requestId: requestId)
            } else if let reqId = requestId {
                self.evaluateJS("window.__blackboxResolvePicker && window.__blackboxResolvePicker('\(reqId)', null);")
            }
        }
    }

    private func saveMusicFolderBookmark(_ folderURL: URL) {
        if let old = activeSecurityScopedURL {
            old.stopAccessingSecurityScopedResource()
        }
        _ = folderURL.startAccessingSecurityScopedResource()
        activeSecurityScopedURL = folderURL
        httpServer.mountedMusicFolderURL = folderURL

        if let bookmarkData = try? folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkDefaultsKey)
        }
    }

    private func restoreSavedMusicFolderBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else { return }
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURL = url
                httpServer.mountedMusicFolderURL = url
            }
        }
    }

    private func mountAndSendFolderManifest(folderURL: URL, requestId: String?) {
        httpServer.mountedMusicFolderURL = folderURL
        let port = httpServer.port

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var entries: [[String: Any]] = []
            let fm = FileManager.default
            let basePath = folderURL.standardizedFileURL.path

            if let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard self.supportedExtensions.contains(ext) else { continue }
                    let fullPath = fileURL.standardizedFileURL.path
                    guard fullPath.hasPrefix(basePath) else { continue }

                    var relPath = String(fullPath.dropFirst(basePath.count))
                    if relPath.hasPrefix("/") { relPath.removeFirst() }

                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    let encodedRel = relPath
                        .split(separator: "/")
                        .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
                        .joined(separator: "/")

                    entries.append([
                        "name": fileURL.lastPathComponent,
                        "relativePath": relPath,
                        "size": size,
                        "type": LocalAudioHTTPServer.mimeType(for: ext),
                        "url": "http://127.0.0.1:\(port)/__native_music__/\(encodedRel)"
                    ])
                }
            }

            let payload: [String: Any] = [
                "folderName": folderURL.lastPathComponent,
                "folderPath": folderURL.path,
                "files": entries
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonStr = String(data: jsonData, encoding: .utf8) else { return }

            DispatchQueue.main.async {
                if let reqId = requestId {
                    self.evaluateJS("window.__blackboxResolvePicker && window.__blackboxResolvePicker('\(reqId)', \(jsonStr));")
                } else {
                    self.evaluateJS("window.__blackboxAutoMountNativeFolder && window.__blackboxAutoMountNativeFolder(\(jsonStr));")
                }
            }
        }
    }

    // MARK: - Floating Mini Player Window (mini.html)

    func toggleMiniPlayerWindow() {
        if let panel = miniPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        openMiniPlayerWindow()
    }

    @discardableResult
    private func openMiniPlayerWindow(configuration: WKWebViewConfiguration? = nil) -> WKWebView? {
        if let panel = miniPanel {
            panel.makeKeyAndOrderFront(nil)
            return miniWebView
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 120, y: 120, width: 380, height: 185),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "BLACKBOX MINI"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        panel.isMovableByWindowBackground = true

        let webConfig = configuration ?? mainWebView.configuration
        let miniWV = WKWebView(frame: panel.contentView!.bounds, configuration: webConfig)
        miniWV.autoresizingMask = [.width, .height]
        miniWV.uiDelegate = self
        miniWV.navigationDelegate = self
        panel.contentView?.addSubview(miniWV)

        self.miniPanel = panel
        self.miniWebView = miniWV

        if configuration == nil, let url = URL(string: "http://127.0.0.1:\(httpServer.port)/mini.html") {
            miniWV.load(URLRequest(url: url))
        }

        panel.makeKeyAndOrderFront(nil)
        return miniWV
    }

    // MARK: - WKUIDelegate (Handles window.open('mini.html') and <input type="file"> fallback)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        return openMiniPlayerWindow(configuration: configuration)
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Automatically restore saved Music Folder on startup once index.html finishes loading
        if webView === mainWebView, let savedFolder = activeSecurityScopedURL {
            mountAndSendFolderManifest(folderURL: savedFolder, requestId: nil)
        }
    }

    // MARK: - WKScriptMessageHandler (JS <-> Native Swift Bridge)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "blackboxNative",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "pickDirectory":
            let reqId = body["requestId"] as? String
            presentNativeFolderPicker(requestId: reqId)

        case "requestSavedDirectory":
            let reqId = body["requestId"] as? String
            if let savedFolder = activeSecurityScopedURL {
                mountAndSendFolderManifest(folderURL: savedFolder, requestId: reqId)
            } else if let reqId = reqId {
                evaluateJS("window.__blackboxResolvePicker && window.__blackboxResolvePicker('\(reqId)', null);")
            }

        case "nowPlaying":
            updateNowPlayingInfo(body)

        case "focusMainWindow":
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0 !== miniPanel }?.makeKeyAndOrderFront(nil)

        default:
            break
        }
    }

    // MARK: - macOS Media Keys & Control Center (MPNowPlayingInfoCenter)

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.sendPlayerCommand("toggle-play")
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.sendPlayerCommand("toggle-play")
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.sendPlayerCommand("toggle-play")
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.sendPlayerCommand("next")
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.sendPlayerCommand("previous")
            return .success
        }
    }

    func sendPlayerCommand(_ command: String) {
        let js = """
        (function() {
            try {
                const ch1 = new BroadcastChannel('blackbox-player-v1');
                ch1.postMessage({ command: '\(command)' });
                ch1.close();
                const map = { 'toggle-play': 'PLAY_PAUSE', 'next': 'NEXT', 'previous': 'PREV' };
                if (map['\(command)']) {
                    const ch2 = new BroadcastChannel('blackbox_mini');
                    ch2.postMessage({ type: map['\(command)'] });
                    ch2.close();
                }
            } catch (e) {}
        })();
        """
        evaluateJS(js)
    }

    private func updateNowPlayingInfo(_ payload: [String: Any]) {
        let title = (payload["title"] as? String) ?? "BLACKBOX"
        let artist = (payload["artist"] as? String) ?? "Local Audio"
        let album = (payload["album"] as? String) ?? "BLACKBOX Studio"
        let duration = (payload["duration"] as? Double) ?? 0
        let currentTime = (payload["currentTime"] as? Double) ?? 0
        let isPlaying = (payload["isPlaying"] as? Bool) ?? false

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let coverDataURI = payload["coverData"] as? String,
           let commaIdx = coverDataURI.firstIndex(of: ","),
           let imgData = Data(base64Encoded: String(coverDataURI[coverDataURI.index(after: commaIdx)...])),
           let nsImage = NSImage(data: imgData) {
            let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Injected JavaScript Polyfill for macOS WKWebView

    static let nativeBridgeJavaScript = #"""
    (function() {
        'use strict';
        if (window.__blackboxMacBridgeInstalled) return;
        window.__blackboxMacBridgeInstalled = true;

        const pendingPickers = new Map();

        // Build a synthetic FileSystemDirectoryHandle tree backed by our localhost Swift HTTP server
        // so BLACKBOX's native showDirectoryPicker() and entry.getFile() work seamlessly in WebKit!
        function buildDirectoryHandle(manifest) {
            function createFileHandle(fileInfo) {
                return {
                    __isBlackBoxNativeHandle: true,
                    kind: 'file',
                    name: fileInfo.name,
                    getFile: async function() {
                        const res = await fetch(fileInfo.url);
                        const blob = await res.blob();
                        return new File([blob], fileInfo.name, {
                            type: fileInfo.type || 'audio/mpeg',
                            lastModified: Date.now()
                        });
                    },
                    queryPermission: async () => 'granted',
                    requestPermission: async () => 'granted'
                };
            }

            const root = {
                __isBlackBoxNativeHandle: true,
                kind: 'directory',
                name: manifest.folderName || 'MUSIC',
                _children: new Map(),
                queryPermission: async () => 'granted',
                requestPermission: async () => 'granted',
                values: async function* () {
                    for (const child of this._children.values()) {
                        yield child;
                    }
                },
                entries: async function* () {
                    for (const [k, v] of this._children.entries()) {
                        yield [k, v];
                    }
                }
            };

            for (const f of (manifest.files || [])) {
                const parts = (f.relativePath || f.name).split('/').filter(Boolean);
                let curr = root;
                for (let i = 0; i < parts.length - 1; i++) {
                    const dirName = parts[i];
                    if (!curr._children.has(dirName)) {
                        const subDir = {
                            __isBlackBoxNativeHandle: true,
                            kind: 'directory',
                            name: dirName,
                            _children: new Map(),
                            queryPermission: async () => 'granted',
                            requestPermission: async () => 'granted',
                            values: async function* () {
                                for (const c of this._children.values()) yield c;
                            },
                            entries: async function* () {
                                for (const [k, v] of this._children.entries()) yield [k, v];
                            }
                        };
                        curr._children.set(dirName, subDir);
                    }
                    curr = curr._children.get(dirName);
                }
                curr._children.set(f.name, createFileHandle(f));
            }
            return root;
        }

        // Intercept IDBObjectStore.prototype.put & get so synthetic directory handles serialize cleanly
        const origPut = IDBObjectStore.prototype.put;
        IDBObjectStore.prototype.put = function(value, key) {
            if (value && value.__isBlackBoxNativeHandle) {
                return origPut.call(this, { __isBlackBoxNativeStub: true, name: value.name }, key);
            }
            return origPut.call(this, value, key);
        };

        const origGet = IDBObjectStore.prototype.get;
        IDBObjectStore.prototype.get = function(key) {
            const req = origGet.call(this, key);
            req.addEventListener('success', function() {
                const res = req.result;
                if (res && res.__isBlackBoxNativeStub && window.__blackboxLatestDirectoryHandle) {
                    Object.defineProperty(req, 'result', {
                        value: window.__blackboxLatestDirectoryHandle,
                        configurable: true
                    });
                }
            });
            return req;
        };

        window.__blackboxResolvePicker = function(reqId, manifest) {
            const callbacks = pendingPickers.get(reqId);
            if (!callbacks) return;
            pendingPickers.delete(reqId);
            if (!manifest) {
                const err = new Error('User cancelled folder selection');
                err.name = 'AbortError';
                callbacks.reject(err);
                return;
            }
            const handle = buildDirectoryHandle(manifest);
            window.__blackboxLatestDirectoryHandle = handle;
            callbacks.resolve(handle);
        };

        window.__blackboxAutoMountNativeFolder = async function(manifest) {
            if (!manifest) return;
            const handle = buildDirectoryHandle(manifest);
            window.__blackboxLatestDirectoryHandle = handle;
            if (typeof scanLibrary === 'function') {
                try { await scanLibrary(false, handle); } catch (e) {}
            }
        };

        window.__blackboxRescanNative = async function() {
            if (window.__blackboxLatestDirectoryHandle && typeof scanLibrary === 'function') {
                await scanLibrary(true, window.__blackboxLatestDirectoryHandle);
            } else {
                window.webkit.messageHandlers.blackboxNative.postMessage({
                    action: 'requestSavedDirectory'
                });
            }
        };

        // Polyfill window.showDirectoryPicker for macOS WKWebView
        window.showDirectoryPicker = function(options) {
            return new Promise((resolve, reject) => {
                const reqId = 'req_' + Date.now() + '_' + Math.random().toString(36).slice(2);
                pendingPickers.set(reqId, { resolve, reject });
                window.webkit.messageHandlers.blackboxNative.postMessage({
                    action: 'pickDirectory',
                    requestId: reqId
                });
            });
        };

        // Hook BroadcastChannel('blackbox-player-v1' and 'blackbox_mini') so macOS Control Center
        // & Media Keys stay synchronized with track metadata & play/pause state
        if ('BroadcastChannel' in window) {
            try {
                const macSyncChannel = new BroadcastChannel('blackbox-player-v1');
                macSyncChannel.addEventListener('message', (e) => {
                    const payload = e.data;
                    if (payload && payload.type === 'state' && payload.state) {
                        window.webkit.messageHandlers.blackboxNative.postMessage({
                            action: 'nowPlaying',
                            title: payload.state.title || 'No Active Track',
                            artist: payload.state.artist || 'Unknown Artist',
                            album: payload.state.album || 'BLACKBOX',
                            duration: payload.state.duration || 0,
                            currentTime: payload.state.currentTime || 0,
                            isPlaying: Boolean(payload.state.isPlaying),
                            coverData: payload.state.coverData || null
                        });
                    } else if (payload && payload.command === 'focus-main') {
                        window.webkit.messageHandlers.blackboxNative.postMessage({
                            action: 'focusMainWindow'
                        });
                    }
                });

                const legacySyncChannel = new BroadcastChannel('blackbox_mini');
                legacySyncChannel.addEventListener('message', (e) => {
                    const payload = e.data;
                    if (payload && payload.type === 'STATE_UPDATE') {
                        window.webkit.messageHandlers.blackboxNative.postMessage({
                            action: 'nowPlaying',
                            title: payload.title || 'No Active Track',
                            artist: payload.artist || 'Unknown Artist',
                            album: payload.album || 'BLACKBOX',
                            duration: payload.duration || 0,
                            currentTime: payload.currentTime || 0,
                            isPlaying: Boolean(payload.playing),
                            coverData: null
                        });
                    }
                });
            } catch (err) {}
        }
    })();
    """#
}

// MARK: - SwiftUI WebView Container

struct MainPlayerView: NSViewRepresentable {
    @ObservedObject var controller: BlackBoxPlayerController

    func makeNSView(context: Context) -> WKWebView {
        return controller.mainWebView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}