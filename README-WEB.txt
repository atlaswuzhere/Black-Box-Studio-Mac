BLACKBOX — PERSONAL AUDIO SYSTEM
LOCAL WEB EDITION
================================================

IN-APP GUIDE
-----------
The browser player includes a BLACKBOX Guide section in the left navigation. It explains folder connection, playback, queues, favorites, playlists, workspaces, visualizers, audio settings, profiles, Track Moments, backups, USB use, keyboard shortcuts and troubleshooting. It includes a Getting Music section with guidance on lawful sources and third-party tools. Open BLACKBOX Guide from the sidebar or search for it in the Ctrl+K command palette.

STARTING IT
-----------
1. Extract this folder anywhere on your laptop or USB drive.
2. Double-click Run-Music.bat.
3. Keep the black launcher window open; it serves the browser app on 127.0.0.1 only.
4. Use the browser tab that opens (Chrome or Edge recommended). BLACKBOX is built and tested primarily for Windows desktop and laptop computers; mobile is not a release target.
5. Click CONNECT MUSIC FOLDER. Choose the MUSIC folder itself, or choose the app/drive folder that contains MUSIC.
   Subfolders are scanned recursively. Browser permission is explicit and can be revoked later.

PORTABLE USB SETUP
------------------
Recommended drive layout:
  BLACKBOX-PERSONAL-AUDIO\
    Run-Music.bat                 browser edition launcher
    Run-Music-Console.bat         original Windows/console edition launcher
    Start-BlackBox-Web.ps1        localhost-only web server
    index.html / style.css / app.js / mini.html / mini.js
    BlackBox-Audio.ps1            original engine, preserved
    config.json                   original configuration, preserved
    MUSIC\                        your songs, with subfolders
    Playlists\                    portable .m3u8 playlists
    Data\                         index and compatible portable state

If the folder you choose contains a MUSIC subfolder, the browser edition treats it as the drive root and can read/write compatible Data and Playlists files. To set this up later, use Settings > CONNECT DRIVE ROOT. If you choose MUSIC directly, playback and browser-profile features still work, but the app cannot write beside MUSIC until you grant access to the parent/app folder.

FOLDER PICKER TROUBLESHOOTING
----------------------------
If CONNECT MUSIC FOLDER shows “The request is not allowed by the user agent or the platform in the current context”, start the app with Run-Music.bat instead of opening index.html directly. If Chrome/Edge still blocks its native folder picker, click BROWSER COMPATIBILITY PICKER and select the MUSIC folder. If you select the app folder instead, it looks inside its MUSIC subfolder. This fallback uses the browser's standard folder/file chooser and can index/play supported audio files and read selected adjacent .lrc/.txt lyric files. Because a standard chooser does not grant a persistent directory handle, reselect the folder after refreshing or reopening the browser. Direct portable writes to Data and Playlists require the native folder picker and a granted drive-root permission.

FEATURES — THE ORIGINAL ENGINE
------------------------------
- Recursive indexing of MP3, WAV, M4A, WMA, AAC, and FLAC files; incremental metadata cache; MP3 ID3v2 title/artist/album reading with file/folder-name fallback.
- Library filters and sorting, global search, favorites, play counts (a play is counted after 30 seconds), recently played, statistics, most-played list, and format breakdown.
- Queue, next/previous, auto-advance, weighted smart shuffle, same-artist avoidance, 25-track Smart Mix, and saved session queue/position recovery.
- Browser audio playback, seek, volume/mute, playback speed, repeat off/all/one, A–B loop, 0/2/4/6/8-second configurable crossfade, and sleep timer with a final 25-second fade.
- M3U8 playlist import/export; create, rename, delete, reorder, and play playlists; save current queue as a playlist; drive-backed Playlists\*.m3u8 support when a drive root is connected.
- Adjacent .lrc synced lyrics and .txt plain lyrics; optional LRCLIB request only after you press GET LYRICS; cached lyrics reused offline; Data\Lyrics cache when the drive root is connected.
- 13 color themes, 4 variants, working disco rainbow/pulse/ripple effects, SPECTRUM/MIRROR/LED/OFF plus TRAP RING and MONSTERCAT visualizers with smoothed audio response, 3 lyric/visual layouts, sensitivity, beat/kick/snare estimation, BPM estimate, beat indicators, visual delay, manual hit, and pulse options.
- Audio tone test, MP3 decoder test, analyzer information, settings/data import and export, and the existing keyboard shortcuts.

THE DARKROOM EXPERIENCE — ADDITIONS
-----------------------------------
- Premium dark-room visual design with BLACKBOX branding; no visible version/build label in the browser interface.
- Three workspaces: STUDIO (full controls and navigation), VOID (immersive full-screen visualizer whose controls fade away until pointer movement), and DECK (frosted-glass compact player with a spinning vinyl disc, embedded album artwork as the label, and an animated neon aurora ambience).
- Embedded album-cover extraction where available from MP3 ID3/APIC, FLAC picture blocks, M4A/MP4 cover atoms, and WAV files containing ID3 artwork. Current-track covers load immediately; visible library, search, favorites, queue and playlist rows load cover thumbnails lazily with a two-file concurrency limit to avoid reading every large file at startup.
- Optional artwork-color ambience that lightly tints player/visual surfaces without replacing your selected color theme. This can be disabled in Settings.
- Ten-band Web Audio equalizer with preamp, bypass, and presets (Flat, Bass Boost, Bass Cut, Vocal Presence, Treble Lift, Warm, Electronic, Rock, Night Listening). Custom band values are saved in local settings and portable Data settings.
- Waveform-based seeking for files that the browser can decode within the safety limit; click the waveform to seek. Large or unsupported files fall back to the standard seek controls to avoid excessive memory use.
- Ctrl+K command palette for navigation and playback commands, with text filtering and keyboard navigation.
- Automatically generated Smart Collections: Freshly Added, Heavy Rotation, Unheard, Forgotten Favorites, Discovery Queue, Recently Heard, Deep Cuts, and Your Favorites.
- Listening Laboratory adds a seven-day locally measured listening-time chart. This is separate from estimated listening time based on completed play counts.
- Drag-and-drop queue ordering; contextual track actions; track-information panel with file path, format, size, duration, modified time, play count, and favorite state.
- Browser Media Session integration where supported, including headset/system media controls and media notifications; browser support varies.
- Reduced-motion preference; keyboard-accessible waveform seeking; artwork-aware ambience; computer-first Studio/Void/Deck/Record layouts; independent display-module toggles for the visualizer, album artwork, lyrics, rhythm monitor and Up Next panel.
- The equalizer, workspace choice, artwork accent setting, and listening-time records can be saved in compatible Data JSON files when the drive root is connected.

IMPORTANT BROWSER DIFFERENCES
-----------------------------
The original Windows/console edition is preserved as Run-Music-Console.bat + BlackBox-Audio.ps1. Use that launcher for original Windows/WPF playback and audio-system behavior.

A browser cannot run WPF or capture arbitrary Windows audio via WASAPI loopback. The web visualizer analyzes audio played by BLACKBOX, not sound from other apps. It uses Web Audio and HTML media playback instead of Windows Media Player.

Browser/OS decoder support varies. MP3 and WAV are broadly supported; WMA is usually not supported by Chromium. M4A/AAC/FLAC support depends on the browser build and OS codecs. Unsupported tracks remain indexed but can fail to decode; the native console edition may play formats the browser cannot.

Browser crossfade uses two HTML audio decks and gain ramps. Timing depends on browser scheduling and decoder buffering; it is not sample-accurate. Beat detection/BPM are estimates from the player signal and are not identical to the original native C# engine. Web Audio EQ processing applies only to BLACKBOX playback.

The web app needs a localhost origin for directory selection and persistent permissions. Run-Music.bat starts a small PowerShell server bound only to 127.0.0.1 and opens the browser; it does not publish the app to the internet. Keep its window open while using the player. No external libraries or analytics are downloaded. The only intentional network request is to lrclib.net when you explicitly request lyrics.

Without a drive-root connection, favorites, settings, play counts, history, playlists, lyrics cache, and session state stay in the browser profile. Connect the drive root to mirror compatible Data JSON files and write portable Playlists\*.m3u8 and Data\Lyrics files. Browser folder permissions and the metadata acceleration cache remain profile-specific. Back up important data using Export Data JSON / Export Settings JSON. On another PC/browser profile, reconnect the folder and grant permission again; import a backup for state that was not written to the drive.

The supplied config.json is retained and used by both launch paths. When a drive root is connected, the browser edition mirrors settings, favorites, play counts, history, and session files into Data\ using the original engine's JSON field names and MUSIC-relative paths. Playlist files use MUSIC/... paths so both editions can read the same Playlists\*.m3u8 files. The browser directory handle cannot be written into a portable file; each browser profile must grant file access independently.


DECK VISUAL / VINYL NOTES
- The six visualizer modes remain SPECTRUM, MIRROR, LED, OFF, TRAP RING, and MONSTERCAT. Their existing drawing styles are preserved.
- The album-cover tile is separate from the vinyl record; the record spins independently during playback and gently pulses from smoothed bass data.
- The cover art is not drawn into the Trap Ring visualizer center. Theme and color-variant choices override signature visualizer palettes after the user changes a theme or variant.
- Glass panels use translucent fills, blur, edge highlights, and soft reflections; the Deck aurora is deliberately softened to preserve contrast.


LOCAL LISTENING STUDIO — ADDITIONAL FEATURES
------------------------------------------
- Full BLACKBOX ZIP backup/restore: one ZIP containing a BLACKBOX-BACKUP.json manifest with favorites, play counts, recent history, measured listening time, custom playlists and smart-playlist rules, track metadata overlays, per-track level-match gains, session queue/position, settings, listening profiles, track moments, lyric cache, visualizer looks, and custom cover-image blobs. Audio files are not included by default. Import supports Restore Everything (replace supported data sets) or Merge Data (merge supported collections). A recovery snapshot is created before import where possible; keep a separate backup before restoring.
- Metadata sidecar editor: change displayed title, artist, album, genre, year, rating, custom tags, optional gain dB and custom artwork without rewriting your source audio files. Edits are matched by MUSIC-relative path and included in full backups. Custom cover images live in the browser's IndexedDB until included in a full backup; they are not embedded into the original file.
- Library management: artist/album/title/genre/recent/play-count/rating sorting, searchable genre and custom tags, duplicate-candidate scan, missing-cover scan, favorites, ratings, and local similar-track matching. The duplicate checker never deletes files. Files larger than 80 MB use file size + head/tail fingerprints, so the result is a candidate list that should be reviewed rather than an automatic exact-match verdict.
- Smart playlists: build live rule-based playlists by genre, artist, album, custom tags, year, rating, duration, play count, or favorite status. Rules update as your library metadata/history changes and are included in full backups and portable Data/playlists.json. Also includes the five-star shelf, locally ranked similar-track finder, smart shuffle, weighted discovery queue, M3U8 playlists, and queue reordering.
- Audio controls: save/load/delete custom ten-band EQ presets; optional level matching using embedded ReplayGain tags where available or an RMS estimate during the first seconds of playback; per-track optional gain adjustment; configurable two-deck crossfade; system audio output picker when the browser supports actual Web Audio routing.
- Visualizer controls: six current modes remain SPECTRUM, MIRROR, LED, OFF, TRAP RING and MONSTERCAT. Save named custom color palettes, tune sensitivity/glow/smoothing/quality per mode, and switch to Performance quality when the circular Trap Ring needs lower CPU use. Drawing the Trap Ring batches particle and bar paths instead of using a per-bar blur.
- A separate mini-player popup communicates with the main player through BroadcastChannel on the same localhost origin. Play/pause, previous/next, seek, volume/mute, shuffle and favorite actions are shared with the main queue. A website cannot guarantee Windows always-on-top behavior; use the browser/window manager if you need to keep the popup above other windows.
- RECORD is a separate continuous vinyl-visualizer workspace, not an album-autoplay mode. The record keeps spinning while the current track plays; the cover art becomes its center label, smoothed bass energy drives a subtle pulse and speed variation, and the art/light transition blends to the next track while the disc continues rotating. The record can open a synchronized lyrics overlay and save track moments. Fullscreen visualizer, browser Media Session controls where supported, global shortcuts, sleep-after-current-track and timed fade-out are included.
- Navigation returns to the top when changing workspaces so controls do not stay hidden underneath the fixed header after a long scroll.


RECORD / PROFILES / LYRICS / VISUALIZER STUDIO PRO
-------------------------------------------------
- RECORD is an independent continuous vinyl-animation workspace. It does not automatically play an entire album. It shows the currently playing track's cover as the record label, spins while playback runs, smoothly pulses from bass energy, and blends the art label and ambient lighting to the next track without needing the record animation to stop.
- The RECORD lyrics overlay reuses BLACKBOX's current synchronized local lyrics/cache. LRC timing is highlighted with the song; TXT lyrics remain plain text. Lyrics move with track position and can be dismissed while the record continues.
- Listening Profiles save a named snapshot of workspace, theme/variant, visualizer, palette, EQ, playback and motion preferences. Profiles can be created, renamed, applied, and deleted. They are written to Data/listeningProfiles.json when the drive root is connected.
- Track Moments stores timestamps and private notes against a track identity, supports jumping back to a saved timestamp, and is saved into Data/trackMoments.json. Moments can be used for favorite passages or places to return to in a long track.
- Visualizer Studio Pro lets you save/apply/delete named looks that include the current six-mode selection, theme/variant/custom palette, Disco state/style, sensitivity, glow, smoothing and render quality. The six existing visualizer designs remain SPECTRUM, MIRROR, LED, OFF, TRAP RING, and MONSTERCAT; no Scope/Ribbons/Terrain modes are added.
- Trap Ring performance work batches glow/bar/particle drawing rather than issuing an expensive shadow blur for every bar. The existing appearance and audio-reactive behavior are retained; use Performance quality on lower-power hardware.
- Full backup export creates one ZIP containing BLACKBOX-BACKUP.json, including settings, library state, favorites, playlist/smart-playlist definitions, profiles, moments, histories, custom metadata/cover artwork, lyrics cache, visualizer looks, and queue/session data. Restore Everything replaces supported application data; Merge Data combines compatible collections. Music audio files are excluded by default so backups stay manageable.
- Connect the app/USB folder that contains MUSIC, Playlists, and Data to make the files in Data the portable source of truth. The app mirrors its compatible data JSON files to that folder; browser storage remains a cache/fallback. Clearing browser history/cookies will not delete files on the drive, but you may need to reconnect the folder and grant access again. If the folder is not connected, browser-profile-only changes can still be lost if browser site data is cleared; export a full ZIP backup before clearing it.
- Write failures must not be treated as success: the UI reports when the portable folder is unavailable. Keep backups on a second location as protection against USB failure.

PLATFORM / FEATURE LIMITATIONS
------------------------------
BLACKBOX is still a local player; this build does not add online music search or streaming. Existing GET LYRICS remains an explicit optional request for lyrics; local .lrc/.txt files and cached lyrics work offline. The normalizer is a ReplayGain/RMS-based approximation rather than calibrated LUFS loudness matching. The optional stereo-width control uses a simple mid-side widening matrix; it is not a Dolby Atmos decoder or object-based surround renderer. Output device switching requires browser support for AudioContext.setSinkId; listing devices does not guarantee the browser can route the Web Audio graph to every device. Crossfade is best-effort browser audio scheduling, not sample-accurate gapless playback. The separate mini-window is browser-controlled and cannot force always-on-top. Playlist/session file paths require the same local music files and a freshly granted folder permission on each browser profile/device.

