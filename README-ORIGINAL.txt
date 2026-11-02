BLACKBOX // AUDIO ENGINE v6

SETUP
  Copy your songs into MUSIC\ (subfolders are fine), then double-click Run-Music.bat.
  Works from any USB drive letter. Needs Windows 10/11 (PowerShell 5.1 is built in).
  If the text looks like boxes or question marks, set "unicode": false in config.json.

MENU
  1 Library   2 Search   3 Shuffle all   4 Now playing   5 Queue
  6 Favorites 7 Playlists 8 Statistics   9 Tools         0 Exit
  In any track list:  <id> play from here | A <id> add to queue | F <id> favorite
                      /text filter | N/P page | ALL play all | S shuffle | Q back

PLAYER KEYS
  SPACE pause   N/B next/prev   LEFT/RIGHT seek   UP/DOWN volume   [ ] speed
  M mute   S shuffle   R repeat (off/all/one)   F favorite   T sleep timer
  1-4 or V visualizer   C theme color
  TAB up-next queue   G get lyrics   ESC or Q back

LYRICS
  Synced lyrics: put Song.lrc next to Song.mp3 (same file name). Plain Song.txt also works.
  Press G in the player to download lyrics from lrclib.net. They are saved in Data\Lyrics
  and reused offline. This is the only feature that uses the internet, and only when you press G.

NEW IN v6
  BEAT SYNC
  - New beat tracker: a kick-drum detector on the raw audio (about 3 ms latency in synthetic tests),
    a separate snare/hat detector, and live BPM. Four boxes in the top bar step on every beat.
  - K / L = visual delay -/+ 25 ms. If flashes land before you hear the beat (Bluetooth speakers or
    headphones are the usual cause), press L until they line up. It is remembered.
  - H = manual hit: tap it on the beat to fire a flash.
  FLASH + PULSE
  - The window border glows smoothly with each beat, the title and playhead flash, and bars
    brighten on kicks (low end) and snares (highs). "pulse": false in config.json turns it off.
  DISCO (D on/off, E changes style)
  - RAINBOW: every bar its own hue, white flash on kicks, hue jumps on the beat.
  - PULSE: theme colors, hard full-width flashes.
  - RIPPLE: each kick sends a ring of light out from the center.
  - A bright comet runs around the borders once per beat.
  VISUALS (keys 1-4 / V)
  - SPECTRUM, MIRROR, LED (segmented), OFF. Clean bars: no peak caps and no floating particles.
  - Y = layout: balanced / lyrics focus / visual focus.
  LYRICS
  - Bigger panel (6-16 lines depending on layout), centered. The current line is bold and
    highlighted with a karaoke wipe that fills as it is sung, and flashes on kicks. Lines fade
    with distance. Instrumental gaps show a beat counter.
  MORE
  - R on the main menu resumes your last queue and position; H shows recently played.
  - The sleep timer fades the volume out over its last 25 seconds.

FROM v5
  VISUALS
  - Thin 1-column bars with more bands, soft reflection under the spectrum, light smoothing.
  - Modes (keys 1-7 / V): SPECTRUM, MIRROR, SCOPE, CURVE (smooth line), DOTS (dot matrix),
    SPARKS (particles fired by the beat), OFF. The old full-area waterfall is gone.
  - Colors: 13 themes (AMBER PHOSPHOR ICE MAGENTA CRIMSON PRISM SUNSET OCEAN VAPOR GOLD NEON MONO
    RGB). C = next theme, X = variant (GRADIENT / SOLID / REVERSE / DUO). RGB cycles hues forever.
    Tools > Colors shows a preview of every theme.
  - D = DISCO MODE: the whole palette and border jump to a new hue on every kick drum.
    It is color shifting, not strobing, but turn it off if flashing colors bother you.
  - , and . adjust visualizer sensitivity.
  PLAYBACK
  - Crossfade (W cycles off/2/4/6/8 s, default 4): the next song is preloaded and blended in, so
    songs flow into each other. Windows' media player cannot do sample-accurate gapless, so this
    is the smooth alternative. Set "crossfade": 0 in config.json for hard cuts.
  - Smart shuffle: weighted so liked and less-played songs come up more, and the same artist is
    kept from playing twice in a row. SMART MIX (menu 8) builds a 25-song mix.
  - Play counts (a play = 30 s) feed smart shuffle and the MOST PLAYED list in Statistics.
  - A = loop a section (press once for start, again for end, third time to clear).
  PLAYLISTS (menu 7)
  - LIKED SONGS is built in. Create / rename / delete playlists, open one to play, smart shuffle,
    add by library id (+ <id>), remove (X n), reorder (U n / D n).
  - Add songs from anywhere: P while playing, P <id> or PA (all listed) in any track list.
  - "S" in the playlist menu saves the current queue as a playlist.
  UI: scrolling title for long names, NEXT up shown beside the artist, status tags, 3 key rows.

FROM v4
  - Recorder-style look: double-line frame, REC light, T+ timecode, CH n/n, amber-on-black default.
  - REAL visualizer: listens to what your PC is playing (WASAPI loopback of the default output
    device) and runs an FFT. Spectrum with peak caps, mirror, oscilloscope, scrolling waterfall,
    live L/R VU meters, and the frame pulses softly on kicks. Nothing is recorded or saved.
  - 24-bit color and one-write-per-frame drawing (no flicker). Themes: AMBER PHOSPHOR ICE
    MAGENTA CRIMSON PRISM (press C).
  - Power-on self test at startup. Tools > 5 shows analyzer status.
  - If loopback is unavailable the header shows SIM and the visuals are animated, not analyzed.
  - config.json: "boot": false skips the startup animation, "pulse": false stops the beat pulse.

NOTES
  - Titles, artists and albums are read from MP3 (ID3v2) tags, else from file/folder names.
    The index is cached in Data\library.json and only new or changed files are re-read.
  - Visualizer needs Windows 10 1703+ for 24-bit console color (older builds get a basic screen).
  - Favorites, volume, theme, shuffle and repeat are remembered in Data\.
  - Playlists are .m3u8 files in Playlists\ (save the current queue from menu 7).
  - Auto-advance to the next song happens while the player screen (menu 4) is open.
