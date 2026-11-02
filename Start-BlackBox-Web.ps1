# BLACKBOX - localhost static server for Windows PowerShell 5.1
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
$Listener = $null
$Port = 8765
for ($Try = 0; $Try -lt 10; $Try++) {
    try {
        $Candidate = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $Candidate.Start(64)
        $Listener = $Candidate
        break
    } catch {
        try { if ($Candidate) { $Candidate.Stop() } } catch {}
        $Port++
    }
}
if (-not $Listener) { throw 'Could not bind a localhost port between 8765 and 8784.' }
$BaseUrl = "http://127.0.0.1:$Port/"
Write-Host ''
Write-Host '  BLACKBOX' -ForegroundColor DarkYellow
Write-Host "  Local browser app: $BaseUrl" -ForegroundColor Green
Write-Host '  Only this PC can connect. No public network interface is opened.' -ForegroundColor Gray
Write-Host '  Keep this window open while using the player. Press Ctrl+C to stop.' -ForegroundColor Gray
Write-Host ''
try { Start-Process $BaseUrl } catch { Write-Host '  Browser did not open automatically; copy the URL above into Chrome or Edge.' -ForegroundColor Yellow }

function Get-MimeType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' }
        '.css' { 'text/css; charset=utf-8' }
        '.js' { 'text/javascript; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.txt' { 'text/plain; charset=utf-8' }
        '.svg' { 'image/svg+xml' }
        '.ico' { 'image/x-icon' }
        '.m3u8' { 'audio/x-mpegurl; charset=utf-8' }
        '.lrc' { 'text/plain; charset=utf-8' }
        default { 'application/octet-stream' }
    }
}
function Send-Response($Stream, [int]$Status, [string]$StatusText, [byte[]]$Body, [string]$Mime, [bool]$HeadOnly = $false) {
    $Headers = @(
        "HTTP/1.1 $Status $StatusText",
        "Content-Type: $Mime",
        "Content-Length: $($Body.Length)",
        'Connection: close',
        'Cache-Control: no-store',
        'X-Content-Type-Options: nosniff',
        'Referrer-Policy: no-referrer',
        "Content-Security-Policy: default-src 'self' blob: data:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' https://lrclib.net; media-src 'self' blob:; img-src 'self' blob: data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'",
        '', ''
    ) -join "`r`n"
    $HeaderBytes = [Text.Encoding]::ASCII.GetBytes($Headers)
    $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
    if (-not $HeadOnly -and $Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
}
try {
    while ($true) {
        $Client = $null
        try {
            $Client = $Listener.AcceptTcpClient()
            $Client.NoDelay = $true
            $Stream = $Client.GetStream()
            $Stream.ReadTimeout = 4000
            $Stream.WriteTimeout = 4000
            $Reader = [System.IO.StreamReader]::new($Stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
            $RequestLine = $Reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($RequestLine)) { $Client.Close(); continue }
            $Parts = $RequestLine.Split(' ')
            if ($Parts.Length -lt 2) { $Client.Close(); continue }
            $Method = $Parts[0].ToUpperInvariant()
            $RawPath = ($Parts[1] -split '\?', 2)[0]
            $RelPath = [Uri]::UnescapeDataString($RawPath.TrimStart('/'))
            while ($true) { $HeaderLine = $Reader.ReadLine(); if ([string]::IsNullOrEmpty($HeaderLine)) { break } }
            if ($Method -ne 'GET' -and $Method -ne 'HEAD') {
                $Body = [Text.Encoding]::UTF8.GetBytes('Method not allowed')
                Send-Response $Stream 405 'Method Not Allowed' $Body 'text/plain; charset=utf-8' ($Method -eq 'HEAD')
                continue
            }
            if ([string]::IsNullOrWhiteSpace($RelPath)) { $RelPath = 'index.html' }
            $FullPath = [IO.Path]::GetFullPath((Join-Path $Root $RelPath))
            $Prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if (-not ($FullPath.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase) -or $FullPath.Equals((Join-Path $Root 'index.html'), [StringComparison]::OrdinalIgnoreCase))) {
                $Body = [Text.Encoding]::UTF8.GetBytes('Forbidden')
                Send-Response $Stream 403 'Forbidden' $Body 'text/plain; charset=utf-8' ($Method -eq 'HEAD')
                continue
            }
            if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
                $Body = [Text.Encoding]::UTF8.GetBytes('Not found')
                Send-Response $Stream 404 'Not Found' $Body 'text/plain; charset=utf-8' ($Method -eq 'HEAD')
                continue
            }
            $Body = [IO.File]::ReadAllBytes($FullPath)
            Send-Response $Stream 200 'OK' $Body (Get-MimeType $FullPath) ($Method -eq 'HEAD')
        } catch {
            # Keep the localhost host alive when a browser closes a request early.
        } finally {
            if ($Client) { try { $Client.Close() } catch {} }
        }
    }
} finally {
    if ($Listener) { try { $Listener.Stop() } catch {} }
}
