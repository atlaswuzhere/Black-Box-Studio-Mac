# BLACKBOX // AUDIO ENGINE v6 - Windows PowerShell 5.1 (ASCII-only source on purpose)
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
try { $script:Config = Get-Content -LiteralPath (Join-Path $script:Root 'config.json') -Raw | ConvertFrom-Json } catch { throw 'config.json could not be read.' }
function Get-RootPath([string]$P) { [IO.Path]::GetFullPath((Join-Path $script:Root $P)) }
$script:MusicRoot = Get-RootPath ([string]$script:Config.musicFolder)
$script:PlaylistRoot = Get-RootPath ([string]$script:Config.playlistFolder)
$script:DataRoot = Get-RootPath ([string]$script:Config.cacheFolder)
$script:LyricsRoot = Join-Path $script:DataRoot 'Lyrics'
$script:CachePath = Join-Path $script:DataRoot 'library.json'
$script:SettingsPath = Join-Path $script:DataRoot 'settings.json'
$script:FavPath = Join-Path $script:DataRoot 'favorites.json'
$script:Extensions = @($script:Config.extensions | ForEach-Object { $_.ToString().ToLowerInvariant() })
$script:SeekSeconds = [math]::Max(1, [int]$script:Config.seekSeconds)
$script:Unicode = ($script:Config.unicode -ne $false)
$script:BootAnim = ($script:Config.boot -ne $false)
$script:Pulse = ($script:Config.pulse -ne $false)
$script:Crossfade = 4; if ($null -ne $script:Config.crossfade) { $script:Crossfade = [math]::Max(0, [math]::Min(12, [int]$script:Config.crossfade)) }
$script:PlayPath = Join-Path $script:DataRoot 'plays.json'
$script:HistPath = Join-Path $script:DataRoot 'history.json'
$script:SessionPath = Join-Path $script:DataRoot 'session.json'
foreach ($D in @($script:MusicRoot, $script:PlaylistRoot, $script:DataRoot, $script:LyricsRoot)) { if (-not (Test-Path -LiteralPath $D)) { New-Item -ItemType Directory -Path $D -Force | Out-Null } }

# ---------- state ----------
$script:W = 98; $script:H = 32; $script:MW = 78; $script:LastDims = ''
$script:Library = @(); $script:Queue = New-Object System.Collections.ArrayList; $script:QueueIndex = -1
$script:CurrentTrack = $null; $script:Paused = $false; $script:TrackEnded = $false; $script:OpenOK = $false; $script:MediaError = $null
$script:Player = $null; $script:Closing = $false; $script:Shuffle = $false; $script:Repeat = 0
$script:Volume = [math]::Max(0, [math]::Min(100, [int]$script:Config.defaultVolume)); $script:Speed = 1.0
$script:Theme = 0; $script:Variant = 0; $script:Disco = $false; $script:VizMode = 0; $script:QueueView = $false; $script:Sens = 0
$script:Next = $null; $script:NextTrack = $null; $script:NextIndex = -1; $script:NextOpen = $false; $script:NextFail = $false; $script:XfActive = $false; $script:Preloading = $false
$script:LoopA = -1.0; $script:LoopB = -1.0; $script:Plays = @{}; $script:CountedKey = ''
$script:DStyle = 0; $script:SyncMs = 0; $script:Layout = 0; $script:AutoCur = 0; $script:AutoUntil = [datetime]::MinValue; $script:Hist = @()
$script:Lyrics = $null; $script:LyricMode = 'none'; $script:Notice = ''; $script:NoticeUntil = [datetime]::MinValue
$script:SleepAt = [datetime]::MinValue; $script:Favs = @{}
$script:Rng = New-Object System.Random
$script:Sb = New-Object System.Text.StringBuilder 16384
$script:E = [string][char]27
$script:Vt = $false; $script:Rs = ''
$script:EngineOK = $false; $script:EngineErr = ''
$script:VizNames = @('SPECTRUM', 'MIRROR', 'LED', 'OFF')
$script:DStyleNames = @('RAINBOW', 'PULSE', 'RIPPLE')
$script:VariantNames = @('GRADIENT', 'SOLID', 'REVERSE', 'DUO')
$script:ThemeNames = @('AMBER', 'PHOSPHOR', 'ICE', 'MAGENTA', 'CRIMSON', 'PRISM', 'SUNSET', 'OCEAN', 'VAPOR', 'GOLD', 'NEON', 'MONO', 'RGB')
$script:RainbowStops = @(255, 0, 0, 255, 200, 0, 0, 255, 80, 0, 170, 255, 180, 0, 255)
$script:ThemeAccent = @(@(255, 122, 0), @(0, 220, 90), @(0, 190, 255), @(255, 0, 200), @(255, 50, 60), @(255, 210, 0), @(255, 100, 80), @(0, 180, 230), @(190, 80, 255), @(255, 200, 40), @(255, 0, 170), @(220, 220, 220), @(255, 70, 170))
$script:ThemeStops = @(
    @(90, 30, 0, 255, 122, 0, 255, 214, 120),
    @(0, 70, 25, 0, 220, 90, 190, 255, 200),
    @(0, 50, 90, 0, 190, 255, 200, 245, 255),
    @(70, 0, 70, 255, 0, 200, 255, 190, 245),
    @(80, 0, 10, 255, 40, 50, 255, 190, 170),
    @(0, 90, 255, 0, 220, 200, 90, 255, 90, 255, 230, 0, 255, 60, 30),
    @(60, 0, 60, 255, 60, 90, 255, 170, 40, 255, 240, 170),
    @(0, 20, 70, 0, 110, 200, 0, 220, 210, 190, 255, 245),
    @(40, 0, 90, 150, 50, 255, 255, 70, 200, 90, 240, 255),
    @(70, 40, 0, 200, 140, 0, 255, 215, 60, 255, 245, 200),
    @(0, 40, 255, 150, 0, 255, 255, 0, 170, 0, 255, 230),
    @(40, 40, 40, 150, 150, 150, 250, 250, 250),
    @(255, 0, 0, 255, 200, 0, 0, 255, 80, 0, 170, 255, 180, 0, 255)
)
if ($script:Unicode) {
    $script:G = @{ TL = [string][char]0x2554; TR = [string][char]0x2557; BL = [string][char]0x255A; BR = [string][char]0x255D; H = [string][char]0x2550; V = [string][char]0x2551; ML = [string][char]0x2560; MR = [string][char]0x2563; Full = [string][char]0x2588; Light = [string][char]0x2591; Rec = [string][char]0x25CF; Heart = [string][char]0x2665; Dot = [string][char]0xB7; Sel = [string][char]0x25BA }
    $script:Blk = @(' ') + @(0x2581..0x2588 | ForEach-Object { [string][char]$_ })
}
else {
    $script:G = @{ TL = '+'; TR = '+'; BL = '+'; BR = '+'; H = '-'; V = '|'; ML = '+'; MR = '+'; Full = '#'; Light = '.'; Rec = '*'; Heart = '<3'; Dot = '-'; Sel = '>' }
    $script:Blk = @(' ', '.', ':', '-', '=', '+', '*', '#', '#')
}

# ---------- colors (24-bit ANSI; empty strings when the console cannot do it) ----------
function Sgr([int]$R, [int]$G, [int]$B) { if (-not $script:Vt) { return '' }; return ('{0}[38;2;{1};{2};{3}m' -f $script:E, $R, $G, $B) }
function Init-Colors {
    $script:Rs = if ($script:Vt) { $script:E + '[0m' } else { '' }
    $script:cW = Sgr 236 236 236; $script:cG = Sgr 150 150 150; $script:cX = Sgr 84 84 84
    $script:cY = Sgr 255 196 0; $script:cR = Sgr 255 64 64; $script:cOk = Sgr 90 220 120
    $script:Bd = if ($script:Vt) { $script:E + '[1m' } else { '' }
    $script:LyFade = @((Sgr 210 210 210), (Sgr 170 170 170), (Sgr 135 135 135), (Sgr 105 105 105), (Sgr 80 80 80))
}
function Get-Stops([int]$Th, [int]$Var) {
    $F = $script:ThemeStops[$Th]; $Tr = @()
    for ($i = 0; $i + 2 -lt $F.Count; $i += 3) { $Tr += , @($F[$i], $F[$i + 1], $F[$i + 2]) }
    switch ($Var) {
        1 { $M = $Tr[[int][math]::Floor($Tr.Count / 2)]; $Tr = @($M, $M, $M) }
        2 { [array]::Reverse($Tr) }
        3 { $Tr = @($Tr[0], $Tr[$Tr.Count - 1]) }
    }
    $Out = @(); foreach ($Tp in $Tr) { $Out += $Tp }
    return [int[]]$Out
}
function Apply-Palette {
    if (-not $script:EngineOK) { return }
    try {
        $Ac = $script:ThemeAccent[$script:Theme]
        [BBEngine]::SetAccent([int]$Ac[0], [int]$Ac[1], [int]$Ac[2])
        [BBEngine]::DStyle = [int]$script:DStyle
        [BBEngine]::SetPalette([int[]](Get-Stops $script:Theme $script:Variant))
        $Dm = 0; if ($script:Disco) { $Dm = 2 } elseif ($script:Theme -eq 12) { $Dm = 1 }
        [BBEngine]::SetDyn($Dm)
    } catch {}
}
function Set-Theme([int]$N) {
    $Cnt = $script:ThemeNames.Count
    $script:Theme = (($N % $Cnt) + $Cnt) % $Cnt
    $A = $script:ThemeAccent[$script:Theme]
    $script:cA = Sgr $A[0] $A[1] $A[2]
    $script:cD = Sgr ([int]($A[0] * 0.42)) ([int]($A[1] * 0.42)) ([int]($A[2] * 0.42))
    $script:cH = Sgr ([int](255 - (255 - $A[0]) * 0.35)) ([int](255 - (255 - $A[1]) * 0.35)) ([int](255 - (255 - $A[2]) * 0.35))
    Apply-Palette
}
function Swatch([int[]]$Flat, [int]$N = 26) {
    $Sw = New-Object System.Text.StringBuilder; $Cnt = [int]($Flat.Count / 3)
    for ($i = 0; $i -lt $N; $i++) {
        $P = $i / [double]($N - 1) * ($Cnt - 1); $K = [math]::Min([int][math]::Floor($P), $Cnt - 2); $Fr = $P - $K
        $Rr = [int]($Flat[$K * 3] + ($Flat[($K + 1) * 3] - $Flat[$K * 3]) * $Fr)
        $Gg = [int]($Flat[$K * 3 + 1] + ($Flat[($K + 1) * 3 + 1] - $Flat[$K * 3 + 1]) * $Fr)
        $Bb = [int]($Flat[$K * 3 + 2] + ($Flat[($K + 1) * 3 + 2] - $Flat[$K * 3 + 2]) * $Fr)
        [void]$Sw.Append((Sgr $Rr $Gg $Bb)).Append($script:G.Full)
    }
    [void]$Sw.Append($script:Rs)
    return $Sw.ToString()
}
function Save-Settings { try { [pscustomobject]@{ Volume = $script:Volume; Theme = $script:Theme; VizMode = $script:VizMode; Speed = $script:Speed; Shuffle = $script:Shuffle; Repeat = $script:Repeat; Variant = $script:Variant; Sens = $script:Sens; Crossfade = $script:Crossfade; DStyle = $script:DStyle; SyncMs = $script:SyncMs; Layout = $script:Layout } | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8 } catch {} }
function Load-Settings {
    try {
        $S = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json
        if ($null -ne $S.Volume) { $script:Volume = [int]$S.Volume }
        if ($null -ne $S.Theme) { $script:Theme = [int]$S.Theme }
        if ($null -ne $S.VizMode) { $script:VizMode = [int]$S.VizMode }
        if ($null -ne $S.Speed) { $script:Speed = [double]$S.Speed }
        if ($null -ne $S.Shuffle) { $script:Shuffle = [bool]$S.Shuffle }
        if ($null -ne $S.Repeat) { $script:Repeat = [int]$S.Repeat }
        if ($null -ne $S.Variant) { $script:Variant = [int]$S.Variant }
        if ($null -ne $S.Sens) { $script:Sens = [int]$S.Sens }
        if ($null -ne $S.DStyle) { $script:DStyle = [int]$S.DStyle }
        if ($null -ne $S.SyncMs) { $script:SyncMs = [int]$S.SyncMs }
        if ($null -ne $S.Layout) { $script:Layout = [int]$S.Layout }
        if ($null -ne $S.Crossfade) { $script:Crossfade = [math]::Max(0, [math]::Min(12, [int]$S.Crossfade)) }
    } catch {}
    if ($script:VizMode -lt 0 -or $script:VizMode -gt 3) { $script:VizMode = 0 }
    if ($script:DStyle -lt 0 -or $script:DStyle -gt 2) { $script:DStyle = 0 }
    if ($script:Layout -lt 0 -or $script:Layout -gt 2) { $script:Layout = 0 }
    $script:SyncMs = [math]::Max(0, [math]::Min(300, $script:SyncMs))
    if ($script:Variant -lt 0 -or $script:Variant -gt 3) { $script:Variant = 0 }
    Set-Theme $script:Theme
}
function Load-Favs { try { foreach ($F in @(Get-Content -LiteralPath $script:FavPath -Raw | ConvertFrom-Json)) { $script:Favs[[string]$F] = $true } } catch {} }
function Save-Favs { try { ConvertTo-Json -InputObject @($script:Favs.Keys) | Set-Content -LiteralPath $script:FavPath -Encoding UTF8 } catch {} }
function Is-Fav($T) { $script:Favs.ContainsKey($T.RelativePath.ToLowerInvariant()) }
function Toggle-Fav($T) { if (-not $T) { return }; $K = $T.RelativePath.ToLowerInvariant(); if ($script:Favs.ContainsKey($K)) { $script:Favs.Remove($K) } else { $script:Favs[$K] = $true }; Save-Favs }
function Load-Plays { try { $J = Get-Content -LiteralPath $script:PlayPath -Raw | ConvertFrom-Json; foreach ($Pr in $J.PSObject.Properties) { $script:Plays[[string]$Pr.Name] = [int]$Pr.Value } } catch {} }
function Save-Plays { try { $script:Plays | ConvertTo-Json | Set-Content -LiteralPath $script:PlayPath -Encoding UTF8 } catch {} }
function Get-PlayCount($T) { $K = $T.RelativePath.ToLowerInvariant(); if ($script:Plays.ContainsKey($K)) { return [int]$script:Plays[$K] }; return 0 }
# smart shuffle: weighted random (favorites and less-played tracks come up more), never the same artist twice in a row if avoidable
function Smart-Order([object[]]$Tracks, [int]$FirstId = -1) {
    $L = @($Tracks | Where-Object { $_ })
    if ($L.Count -le 1) { return $L }
    $Max = 1; foreach ($Tk in $L) { $Cn = Get-PlayCount $Tk; if ($Cn -gt $Max) { $Max = $Cn } }
    $Keyed = foreach ($Tk in $L) {
        $Wt = 1.0
        if (Is-Fav $Tk) { $Wt += 1.2 }
        $Wt += 1.5 * (1.0 - ((Get-PlayCount $Tk) / [double]$Max))
        [pscustomobject]@{ T = $Tk; K = [math]::Pow($script:Rng.NextDouble(), 1.0 / $Wt) }
    }
    $S = @($Keyed | Sort-Object K -Descending | ForEach-Object { $_.T })
    for ($i = 1; $i -lt $S.Count; $i++) {
        if ($S[$i].Artist -ieq $S[$i - 1].Artist) {
            for ($j = $i + 1; $j -lt [math]::Min($S.Count, $i + 8); $j++) {
                if ($S[$j].Artist -ine $S[$i - 1].Artist) { $Tmp = $S[$i]; $S[$i] = $S[$j]; $S[$j] = $Tmp; break }
            }
        }
    }
    if ($FirstId -ge 0) { $F = @($S | Where-Object { $_.Id -eq $FirstId } | Select-Object -First 1); if ($F.Count) { $S = @($F) + @($S | Where-Object { $_.Id -ne $FirstId }) } }
    return $S
}
function Load-Hist { try { $script:Hist = @(Get-Content -LiteralPath $script:HistPath -Raw | ConvertFrom-Json | ForEach-Object { [string]$_ }) } catch { $script:Hist = @() } }
function Add-History($T) {
    if (-not $T) { return }
    $K = $T.RelativePath.ToLowerInvariant()
    $script:Hist = @(@($K) + @($script:Hist | Where-Object { $_ -ne $K }) | Select-Object -First 50)
    try { ConvertTo-Json -InputObject @($script:Hist) | Set-Content -LiteralPath $script:HistPath -Encoding UTF8 } catch {}
}
function Save-Session {
    if (-not $script:CurrentTrack -or $script:Queue.Count -eq 0) { return }
    $Ps = 0.0; try { $Ps = $script:Player.Position.TotalSeconds } catch {}
    try { [pscustomobject]@{ queue = @($script:Queue | ForEach-Object { $_.RelativePath }); index = $script:QueueIndex; pos = [math]::Round($Ps, 1) } | ConvertTo-Json | Set-Content -LiteralPath $script:SessionPath -Encoding UTF8 } catch {}
}
function Set-Notice([string]$M) { $script:Notice = $M; $script:NoticeUntil = (Get-Date).AddSeconds(4) }
function Log-Err([string]$M) { try { ('{0}  {1}' -f (Get-Date), $M) | Add-Content -LiteralPath (Join-Path $script:DataRoot 'error.log') } catch {} }

# ---------- native helpers (console VT mode + analyzer engine) ----------
function Init-Native {
    $script:Vt = $false
    try { Add-Type -TypeDefinition $script:WinSrc -Language CSharp -IgnoreWarnings; $script:Vt = [BBWin]::EnableVt() } catch { $script:Vt = $false }
    Init-Colors
}
function Start-Engine {
    $script:EngineOK = $false; $script:EngineErr = ''
    try {
        if (-not ('BBEngine' -as [type])) { Add-Type -TypeDefinition $script:EngineSrc -Language CSharp -IgnoreWarnings }
        [BBEngine]::SetGlyphs([bool]$script:Unicode, [bool]$script:Vt)
        $script:EngineOK = $true
        [BBEngine]::GainDb = [double]$script:Sens
        [BBEngine]::FxOn = [bool]$script:Pulse
        [BBEngine]::SyncMs = [int]$script:SyncMs
        Apply-Palette
        [void][BBEngine]::Start()
    } catch { $script:EngineErr = $_.Exception.Message; $script:EngineOK = $false; Log-Err ('Engine: ' + $_.Exception.Message) }
    return $script:EngineOK
}

function Init-Console {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
    try {
        $Raw = $Host.UI.RawUI; $Cur = $Raw.WindowSize
        $Raw.WindowSize = New-Object System.Management.Automation.Host.Size -ArgumentList ([math]::Min($Cur.Width, 100)), ([math]::Min($Cur.Height, 32))
        $Raw.BufferSize = New-Object System.Management.Automation.Host.Size -ArgumentList 100, 32
        $Raw.WindowSize = New-Object System.Management.Automation.Host.Size -ArgumentList 100, 32
    } catch {}
    try { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Gray' } catch {}
    Clear-Host
}
function Get-Dims {
    $Ww = 100; $Hh = 32
    try { $Ww = [Console]::WindowWidth; $Hh = [Console]::WindowHeight } catch {}
    $script:W = [math]::Max(80, [math]::Min(118, $Ww - 2)); $script:H = [math]::Max(24, $Hh)
}

# ---------- small text helpers ----------
function Say([string]$T = '', [string]$C = '') { [Console]::Write($C + $T + $script:Rs + "`r`n") }
function Ask([string]$Label = 'BLACKBOX') {
    [Console]::Write($script:cD + '  ' + $Label + ' ' + $script:cA + '> ' + $script:cW)
    $R = [Console]::ReadLine(); [Console]::Write($script:Rs)
    if ($null -eq $R) { return '' }
    return $R.Trim()
}
function Wait-Enter { [Console]::Write($script:cG + '  Press ENTER ' + $script:Rs); [void][Console]::ReadLine() }
function Fit([string]$S, [int]$N) { if ($N -lt 1) { return '' }; if ($S.Length -gt $N) { return $S.Substring(0, $N) }; return $S }
function Get-Strip([int]$N) { -join (0..($N - 1) | ForEach-Object { $script:Blk[[int](1 + 7 * [math]::Abs([math]::Sin($_ * 0.45) * [math]::Sin($_ * 0.13 + 1)))] }) }
function Menu-Rule([string]$L, [string]$R) { Say ($L + ($script:G.H * ($script:MW - 2)) + $R) $script:cD }
function Menu-Line([string]$Text, [string]$C, [string]$Right = '') {
    $Room = $script:MW - 4
    if ($Text.Length + $Right.Length + 1 -gt $Room) { $Text = $Text.Substring(0, [math]::Max(0, $Room - $Right.Length - 1)) }
    $Pad = [math]::Max(0, $Room - $Text.Length - $Right.Length)
    [Console]::Write($script:cD + $script:G.V + $script:Rs + ' ' + $C + $Text + $script:Rs + (' ' * $Pad) + $script:cD + $Right + $script:Rs + ' ' + $script:cD + $script:G.V + $script:Rs + "`r`n")
}
function Show-Header([string]$Sub = '') {
    Clear-Host
    Menu-Rule $script:G.TL $script:G.TR
    Menu-Line ($script:G.Rec + ' BLACKBOX // AUDIO ENGINE v6') $script:cA (Get-Strip 22)
    if ($Sub) { Menu-Rule $script:G.ML $script:G.MR; Menu-Line $Sub $script:cW }
    Menu-Rule $script:G.BL $script:G.BR
}
function Item([string]$K, [string]$Label) { return ($script:cD + '[' + $script:cA + $K + $script:cD + '] ' + $script:cW + $Label.PadRight(15) + $script:Rs) }
function Pump-Dispatcher([int]$Ms = 60) {
    $Frame = New-Object System.Windows.Threading.DispatcherFrame
    $Timer = New-Object System.Windows.Threading.DispatcherTimer
    $Timer.Interval = [TimeSpan]::FromMilliseconds([math]::Max(1, $Ms))
    $Timer.Add_Tick({ $Timer.Stop(); $Frame.Continue = $false })
    $Timer.Start(); [System.Windows.Threading.Dispatcher]::PushFrame($Frame)
}
function Format-Time([double]$S) {
    if ($S -lt 0 -or [double]::IsNaN($S) -or [double]::IsInfinity($S)) { return '00:00' }
    $Sp = [TimeSpan]::FromSeconds($S); if ($Sp.TotalHours -ge 1) { return $Sp.ToString('hh\:mm\:ss') }; return $Sp.ToString('mm\:ss')
}

# ---------- ID3v2 tags (title / artist / album) ----------
function Read-Id3([string]$Path) {
    $R = @{}
    try {
        $F = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        try {
            $H = New-Object byte[] 10
            if ($F.Read($H, 0, 10) -ne 10 -or $H[0] -ne 73 -or $H[1] -ne 68 -or $H[2] -ne 51 -or $H[3] -lt 3) { return $R }
            $Ver = $H[3]; $End = 10 + (($H[6] -shl 21) -bor ($H[7] -shl 14) -bor ($H[8] -shl 7) -bor $H[9]); $Pos = 10
            $Map = @{ TIT2 = 'Title'; TPE1 = 'Artist'; TALB = 'Album' }
            while ($Pos -lt ($End - 10) -and $R.Count -lt 3) {
                $F.Position = $Pos
                if ($F.Read($H, 0, 10) -ne 10) { break }
                $Id = [Text.Encoding]::ASCII.GetString($H, 0, 4)
                if ($Id -notmatch '^[A-Z0-9]{4}$') { break }
                if ($Ver -eq 4) { $Sz = ($H[4] -shl 21) -bor ($H[5] -shl 14) -bor ($H[6] -shl 7) -bor $H[7] } else { $Sz = ($H[4] -shl 24) -bor ($H[5] -shl 16) -bor ($H[6] -shl 8) -bor $H[7] }
                if ($Sz -le 0) { break }
                if ($Map.ContainsKey($Id)) {
                    $B = New-Object byte[] ([math]::Min($Sz, 2000)); [void]$F.Read($B, 0, $B.Length)
                    $Enc = switch ($B[0]) { 0 { [Text.Encoding]::GetEncoding(28591) } 1 { [Text.Encoding]::Unicode } 2 { [Text.Encoding]::BigEndianUnicode } default { [Text.Encoding]::UTF8 } }
                    $Txt = $Enc.GetString($B, 1, $B.Length - 1).Trim([char]0xFEFF, [char]0).Trim()
                    if ($Txt) { $R[$Map[$Id]] = $Txt }
                }
                $Pos += 10 + $Sz
            }
        } finally { $F.Dispose() }
    } catch {}
    return $R
}

# ---------- library (incremental index, cached by relative path) ----------
function Build-Library([bool]$Force = $false) {
    $Old = @{}
    if (-not $Force -and (Test-Path -LiteralPath $script:CachePath)) {
        try { $J = Get-Content -LiteralPath $script:CachePath -Raw -Encoding UTF8 | ConvertFrom-Json; if ($J.version -eq 3) { foreach ($T in @($J.tracks)) { $Old[[string]$T.Rel] = $T } } } catch {}
    }
    $Files = @(Get-ChildItem -LiteralPath $script:MusicRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $script:Extensions -contains $_.Extension.ToLowerInvariant() })
    $List = New-Object System.Collections.ArrayList; $N = 0
    foreach ($F in $Files) {
        $N++; if (($N % 20) -eq 0) { [Console]::Write("`r" + $script:cA + ('  Indexing {0}/{1}   ' -f $N, $Files.Count) + $script:Rs) }
        $Rel = $F.FullName.Substring($script:Root.Length).TrimStart('\'); $Ticks = [int64]$F.LastWriteTimeUtc.Ticks; $O = $Old[$Rel]
        if ($O -and [int64]$O.Length -eq [int64]$F.Length -and [int64]$O.Mod -eq $Ticks) { $Artist = [string]$O.Artist; $Title = [string]$O.Title; $Album = [string]$O.Album }
        else {
            $Title = [IO.Path]::GetFileNameWithoutExtension($F.Name) -replace '^\s*\d{1,3}[\s._-]+', ''
            $Artist = Split-Path (Split-Path $F.FullName -Parent) -Leaf; if ($Artist -ieq 'MUSIC') { $Artist = 'Unknown Artist' }
            if ($Title -match '^\s*(.+?)\s+-\s+(.+?)\s*$') { $Artist = $Matches[1].Trim(); $Title = $Matches[2].Trim() }
            $Album = ''
            if ($F.Extension -ieq '.mp3') { $Tg = Read-Id3 $F.FullName; if ($Tg.Title) { $Title = $Tg.Title }; if ($Tg.Artist) { $Artist = $Tg.Artist }; if ($Tg.Album) { $Album = $Tg.Album } }
        }
        [void]$List.Add([pscustomobject]@{ Id = 0; Path = $F.FullName; RelativePath = $Rel; Rel = $Rel; FileName = $F.Name; Artist = $Artist; Title = $Title; Album = $Album; Extension = $F.Extension.ToLowerInvariant(); SizeMB = [math]::Round($F.Length / 1MB, 2); Length = [int64]$F.Length; Mod = $Ticks })
    }
    $Sorted = @($List | Sort-Object Artist, Title); $I = 0; foreach ($T in $Sorted) { $I++; $T.Id = $I }
    $script:Library = $Sorted
    try { [pscustomobject]@{ version = 3; tracks = @($Sorted | Select-Object Rel, Length, Mod, Artist, Title, Album) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:CachePath -Encoding UTF8 } catch {}
    [Console]::Write("`r" + (' ' * 40) + "`r")
}

# ---------- media engine ----------
function New-Media {
    $P = New-Object System.Windows.Media.MediaPlayer
    $P.add_MediaOpened({ param($Sd, $Ev)
        if ([object]::ReferenceEquals($Sd, $script:Player)) { $script:OpenOK = $true; $script:MediaError = $null; try { $script:Player.Play() } catch {} }
        elseif ([object]::ReferenceEquals($Sd, $script:Next)) { $script:NextOpen = $true } })
    $P.add_MediaEnded({ param($Sd, $Ev) if ([object]::ReferenceEquals($Sd, $script:Player)) { $script:TrackEnded = $true } })
    $P.add_MediaFailed({ param($Sd, $Ev)
        if ([object]::ReferenceEquals($Sd, $script:Next)) { $script:NextFail = $true; return }
        try { $script:MediaError = $Ev.ErrorException.Message } catch { $script:MediaError = 'Windows could not decode this file.' }
        $script:OpenOK = $false })
    return $P
}
function Initialize-Media {
    try { Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName WindowsBase } catch { throw 'WPF media assemblies are unavailable on this Windows installation.' }
    $script:Player = New-Media
    $script:Next = New-Media
    $script:Player.Volume = $script:Volume / 100.0
    $script:Next.Volume = 0
}
# ---- crossfade: the next track is preloaded on the standby player and blended in over the last N seconds ----
function Cancel-Preload {
    try { $script:Next.Stop() } catch {}
    try { $script:Next.Volume = 0 } catch {}
    $script:Preloading = $false; $script:XfActive = $false; $script:NextOpen = $false; $script:NextFail = $false; $script:NextTrack = $null
    try { $script:Player.Volume = $script:Volume / 100.0 } catch {}
}
function Complete-Crossfade {
    $Old = $script:Player
    $script:Player = $script:Next; $script:Next = $Old
    try { $script:Next.Stop(); $script:Next.Volume = 0 } catch {}
    $script:CurrentTrack = $script:NextTrack; $script:QueueIndex = $script:NextIndex
    $script:Preloading = $false; $script:XfActive = $false; $script:NextOpen = $false; $script:NextFail = $false; $script:NextTrack = $null
    $script:TrackEnded = $false; $script:Paused = $false; $script:CountedKey = ''; $script:LoopA = -1.0; $script:LoopB = -1.0
    try { $script:Player.Volume = $script:Volume / 100.0 } catch {}
    Load-Lyrics $script:CurrentTrack; Add-History $script:CurrentTrack
}
function Update-Crossfade([double]$Pos, [double]$Dur) {
    $XF = [double]$script:Crossfade
    $Ok = ($XF -gt 0) -and ($Dur -gt 0) -and ($script:Repeat -ne 2) -and ($script:LoopB -lt 0)
    if (-not $Ok) { if ($script:Preloading -or $script:XfActive) { Cancel-Preload }; return }
    $Rem = ($Dur - $Pos) / [math]::Max(0.25, $script:Speed)
    if (-not $script:XfActive) {
        $Ni = $script:QueueIndex + 1
        if ($Ni -ge $script:Queue.Count) { if ($script:Repeat -eq 1 -and $script:Queue.Count -gt 1) { $Ni = 0 } else { return } }
        if (-not $script:Preloading -and $Rem -le ($XF + 8) -and $Rem -gt $XF) {
            $Tr = $script:Queue[$Ni]
            if (Test-Path -LiteralPath $Tr.Path) {
                try { $script:NextOpen = $false; $script:NextFail = $false; $script:Next.Volume = 0; $script:Next.Open([System.Uri]::new($Tr.Path)); $script:NextTrack = $Tr; $script:NextIndex = $Ni; $script:Preloading = $true }
                catch { $script:NextFail = $true; $script:Preloading = $true }
            }
        }
        if ($script:Preloading -and $script:NextOpen -and $Rem -le $XF) {
            try {
                $script:Next.Volume = 0; $script:Next.SpeedRatio = $script:Speed; $script:Next.Position = [TimeSpan]::Zero
                try { $script:Next.IsMuted = $script:Player.IsMuted } catch {}
                $script:Next.Play(); $script:XfActive = $true
            } catch { Cancel-Preload }
        }
        return
    }
    if ($Rem -gt ($XF + 0.5)) { Cancel-Preload; return }
    $Prog = [math]::Max(0.0, [math]::Min(1.0, 1.0 - ($Rem / $XF)))
    $Vol = $script:Volume / 100.0
    try { $script:Player.Volume = $Vol * [math]::Cos($Prog * [math]::PI / 2); $script:Next.Volume = $Vol * [math]::Sin($Prog * [math]::PI / 2) } catch {}
    if ($Prog -ge 1.0 -or $Rem -le 0.05) { Complete-Crossfade }
}
function Wait-ForMediaOpen([int]$Timeout = 6000) {
    $Start = Get-Date
    while (-not $script:OpenOK -and -not $script:MediaError) { if (((Get-Date) - $Start).TotalMilliseconds -ge $Timeout) { break }; Pump-Dispatcher 50 }
    return [bool]$script:OpenOK
}
function Start-Track($Track) {
    if (-not $Track) { return $false }
    if (-not (Test-Path -LiteralPath $Track.Path)) { Set-Notice ('File missing: ' + $Track.RelativePath); return $false }
    try {
        Cancel-Preload; $script:Player.Stop(); $script:OpenOK = $false; $script:MediaError = $null; $script:TrackEnded = $false; $script:Paused = $false; $script:CurrentTrack = $Track
        $script:Player.Open([System.Uri]::new($Track.Path))
        if (-not (Wait-ForMediaOpen 6000)) { Set-Notice ('Cannot play: ' + $Track.FileName); $script:CurrentTrack = $null; return $false }
        $script:Player.Volume = $script:Volume / 100.0; $script:Player.SpeedRatio = $script:Speed; $script:Player.Play()
        Load-Lyrics $Track; $script:LoopA = -1.0; $script:LoopB = -1.0; $script:CountedKey = ''; Add-History $Track
        return $true
    } catch { Set-Notice ('Playback error: ' + $_.Exception.Message); $script:CurrentTrack = $null; return $false }
}
function Set-Queue([object[]]$Tracks, [int]$FirstId = -1, [switch]$Ordered) {
    $script:Queue.Clear(); $L = @($Tracks | Where-Object { $_ })
    if ($script:Shuffle -and -not $Ordered) {
        $L = @(Smart-Order $L $FirstId)
        $Idx = 0
    } else { $Idx = 0; for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i].Id -eq $FirstId) { $Idx = $i; break } } }
    foreach ($T in $L) { [void]$script:Queue.Add($T) }
    $script:QueueIndex = if ($script:Queue.Count -gt 0) { $Idx } else { -1 }
}
function Play-List([object[]]$List, [int]$FirstId = -1, [switch]$Ordered) {
    Set-Queue $List $FirstId -Ordered:$Ordered
    if ($script:Queue.Count -gt 0 -and (Start-Track $script:Queue[$script:QueueIndex])) { Player-Loop } elseif ($script:Queue.Count -gt 0) { Say '  Could not start this track.' $script:cY; Wait-Enter }
}
function Next-Track {
    if ($script:Queue.Count -eq 0) { return }
    for ($k = 0; $k -lt 5; $k++) {
        $N = $script:QueueIndex + 1
        if ($N -ge $script:Queue.Count) {
            if ($script:Repeat -eq 0) { try { $script:Player.Stop() } catch {}; $script:CurrentTrack = $null; return }
            $N = 0
        }
        $script:QueueIndex = $N
        if (Start-Track $script:Queue[$N]) { return }
    }
}
function Previous-Track {
    if ($script:Queue.Count -eq 0) { return }
    if ($script:Player.Position.TotalSeconds -gt 3) { $script:Player.Position = [TimeSpan]::Zero; return }
    $script:QueueIndex = [math]::Max(0, $script:QueueIndex - 1); [void](Start-Track $script:Queue[$script:QueueIndex])
}
function Toggle-Pause {
    if (-not $script:CurrentTrack) { return }
    try {
        if ($script:Paused) { $script:Player.Play(); if ($script:XfActive) { $script:Next.Play() } }
        else { $script:Player.Pause(); if ($script:XfActive) { $script:Next.Pause() } }
        $script:Paused = -not $script:Paused
    } catch {}
}
function Set-Volume([int]$V) { $script:Volume = [math]::Max(0, [math]::Min(100, $V)); try { $script:Player.Volume = $script:Volume / 100.0 } catch {} }
function Seek-By([int]$S) {
    try {
        $N = [math]::Max(0, $script:Player.Position.TotalSeconds + $S)
        if ($script:Player.NaturalDuration.HasTimeSpan) { $N = [math]::Min($N, $script:Player.NaturalDuration.TimeSpan.TotalSeconds - 0.5) }
        $script:Player.Position = [TimeSpan]::FromSeconds([math]::Max(0, $N))
    } catch {}
}
function Set-Speed([int]$D) {
    $Steps = @(0.5, 0.75, 1.0, 1.25, 1.5, 2.0); $I = 0; for ($k = 0; $k -lt $Steps.Count; $k++) { if ([math]::Abs($Steps[$k] - $script:Speed) -lt 0.01) { $I = $k } }
    $script:Speed = $Steps[[math]::Max(0, [math]::Min($Steps.Count - 1, $I + $D))]; try { $script:Player.SpeedRatio = $script:Speed; if ($script:XfActive) { $script:Next.SpeedRatio = $script:Speed } } catch {}
}
function Toggle-Shuffle {
    $script:Shuffle = -not $script:Shuffle; Cancel-Preload
    if ($script:Shuffle -and $script:QueueIndex -ge 0 -and $script:QueueIndex + 1 -lt $script:Queue.Count) {
        $Head = @($script:Queue[0..$script:QueueIndex]); $Tail = @(Smart-Order @($script:Queue[($script:QueueIndex + 1)..($script:Queue.Count - 1)]))
        $script:Queue.Clear(); foreach ($T in ($Head + $Tail)) { [void]$script:Queue.Add($T) }
    }
}

# ---------- lyrics (.lrc synced, .txt plain; optional fetch from lrclib.net) ----------
function Get-SafeName($T) { (($T.Artist + ' - ' + $T.Title) -replace '[\\/:*?"<>|]', '').Trim() }
function Parse-Lrc([string[]]$Lines) {
    $Out = New-Object System.Collections.ArrayList
    foreach ($L in $Lines) {
        $Ms = [regex]::Matches($L, '\[(\d+):(\d+(?:\.\d+)?)\]')
        if ($Ms.Count -gt 0) {
            $Txt = ([regex]::Replace($L, '\[[^\]]*\]', '')).Trim(); if (-not $Txt) { $Txt = '~' }
            foreach ($M in $Ms) { [void]$Out.Add([pscustomobject]@{ T = [double]$M.Groups[1].Value * 60 + [double]$M.Groups[2].Value; Text = $Txt }) }
        }
    }
    return @($Out | Sort-Object T)
}
function Load-Lyrics($Track) {
    $script:Lyrics = $null; $script:LyricMode = 'none'
    $Cands = @([IO.Path]::ChangeExtension($Track.Path, '.lrc'), (Join-Path $script:LyricsRoot ((Get-SafeName $Track) + '.lrc')), [IO.Path]::ChangeExtension($Track.Path, '.txt'), (Join-Path $script:LyricsRoot ((Get-SafeName $Track) + '.txt')))
    foreach ($P in $Cands) {
        if (-not (Test-Path -LiteralPath $P)) { continue }
        try {
            $Lines = @(Get-Content -LiteralPath $P -Encoding UTF8)
            $Syn = @(Parse-Lrc $Lines)
            if ($Syn.Count -gt 0) { $script:Lyrics = $Syn; $script:LyricMode = 'synced' }
            else { $script:Lyrics = @($Lines | Where-Object { $_.Trim() } | ForEach-Object { [pscustomobject]@{ T = -1; Text = $_.Trim() } }); $script:LyricMode = 'plain' }
            if ($script:Lyrics.Count -gt 0) { return }
        } catch {}
    }
    $script:Lyrics = $null; $script:LyricMode = 'none'
}
function Fetch-Lyrics {
    $T = $script:CurrentTrack; if (-not $T) { return }
    Set-Notice 'Fetching lyrics from lrclib.net ...'; Draw-Screen 0.03
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Dur = 0; try { if ($script:Player.NaturalDuration.HasTimeSpan) { $Dur = [int]$script:Player.NaturalDuration.TimeSpan.TotalSeconds } } catch {}
        $A = [uri]::EscapeDataString($T.Artist); $Ti = [uri]::EscapeDataString($T.Title); $R = $null
        try { $R = Invoke-RestMethod -Uri "https://lrclib.net/api/get?artist_name=$A&track_name=$Ti&duration=$Dur" -TimeoutSec 8 -UserAgent 'BlackBox-Audio/4' } catch {}
        if (-not $R -or (-not $R.syncedLyrics -and -not $R.plainLyrics)) {
            $R = @(Invoke-RestMethod -Uri "https://lrclib.net/api/search?track_name=$Ti&artist_name=$A" -TimeoutSec 8 -UserAgent 'BlackBox-Audio/4') | Where-Object { $_.syncedLyrics -or $_.plainLyrics } | Select-Object -First 1
        }
        if ($R) {
            if ($R.syncedLyrics) { $Txt = $R.syncedLyrics; $Ext = '.lrc' } else { $Txt = $R.plainLyrics; $Ext = '.txt' }
            Set-Content -LiteralPath (Join-Path $script:LyricsRoot ((Get-SafeName $T) + $Ext)) -Value $Txt -Encoding UTF8
            Load-Lyrics $T; Set-Notice 'Lyrics saved to Data\Lyrics'
        } else { Set-Notice 'No lyrics found for this track' }
    } catch { Set-Notice 'Lyrics fetch failed (offline?)' }
}

# ---------- player screen: one full frame per write (no flicker) ----------
function Segs([object[]]$P) {
    $B = New-Object System.Text.StringBuilder; $N = 0
    for ($i = 0; $i + 1 -lt $P.Count; $i += 2) { $T = [string]$P[$i + 1]; [void]$B.Append([string]$P[$i]).Append($T); $N += $T.Length }
    [void]$B.Append($script:Rs)
    return [pscustomobject]@{ S = $B.ToString(); N = $N }
}
function Keys([string[]]$Items) {
    $P = @(); $N = 0; $Max = $script:W - 4
    foreach ($It in $Items) {
        $Kp = $It.Split('|'); $Need = $Kp[0].Length + $Kp[1].Length + 3
        if ($N + $Need -gt $Max) { break }
        $P += @($script:cA, $Kp[0], $script:cG, (' ' + $Kp[1] + '  ')); $N += $Need
    }
    return (Segs $P)
}
function Row([int]$Y, $L, $R, [string]$Bc) {
    $E = $script:E; $V = $script:G.V; $Rs = $script:Rs; $Y1 = $Y + 1
    [void]$script:Sb.Append(($E + '[' + $Y1 + ';1H' + $Bc + $V + $Rs + ' '))
    $Ln = 0
    if ($L) { [void]$script:Sb.Append($L.S); $Ln = $L.N }
    [void]$script:Sb.Append(($E + '[K'))
    if ($R -and ($Ln + $R.N + 2 -le ($script:W - 4))) { [void]$script:Sb.Append(($E + '[' + $Y1 + ';' + ($script:W - 1 - $R.N) + 'H' + $R.S)) }
    [void]$script:Sb.Append(($E + '[' + $Y1 + ';' + $script:W + 'H' + $Bc + $V + $Rs))
}
function HRule([int]$Y, [string]$Lc, [string]$Rc, [string]$Label, [string]$LblColor, $Right, [string]$Bc) {
    $E = $script:E; $H = $script:G.H; $Rs = $script:Rs
    $Rn = 0; if ($Right) { $Rn = $Right.N + 2 }
    $Fill = [math]::Max(1, $script:W - 4 - $Label.Length - $Rn)
    $Line = $Bc + ($H * $Fill) + $Rs
    if ($script:Disco -and $script:EngineOK -and $script:Vt -and ($Y -eq 0 -or $Y -eq 5 -or $Lc -eq $script:G.BL)) { $Rl = [BBEngine]::Rule($Fill, $H); if ($Rl) { $Line = $Rl } }
    $Out = $E + '[' + ($Y + 1) + ';1H' + $Bc + $Lc + $H + $Rs + $LblColor + $Label + $Rs + $Line
    if ($Right) { $Out = $Out + ' ' + $Right.S + ' ' }
    $Out = $Out + $Bc + $H + $Rc + $Rs
    [void]$script:Sb.Append($Out)
}
function Flush-Frame { [Console]::Write($script:Sb.ToString()); [void]$script:Sb.Clear() }

function Draw-Player([double]$Dt) {
    Get-Dims
    $G = $script:G; $In = $script:W - 4
    $A = $script:cA; $D = $script:cD; $Hc = $script:cH; $Wh = $script:cW; $Gy = $script:cG; $Dk = $script:cX
    $DimsKey = ('{0}x{1}x{2}' -f $script:W, $script:H, $script:Layout)
    if ($script:LastDims -ne $DimsKey) { $script:LastDims = $DimsKey; Clear-Host }
    $T = $script:CurrentTrack
    $Title0 = ' BLACKBOX // AUDIO ENGINE v6 '

    if (-not $T) {
        HRule 0 $G.TL $G.TR $Title0 $A (Segs @($script:cG, 'O IDLE')) $D
        Row 1 $null $null $D
        Row 2 (Segs @($script:cY, 'Nothing is playing. Open LIBRARY from the menu and pick a track.')) $null $D
        for ($y = 3; $y -le 9; $y++) { Row $y $null $null $D }
        Row 10 (Keys @('ESC|back')) $null $D
        HRule 11 $G.BL $G.BR '' '' $null $D
        Flush-Frame; return
    }

    $Pos = 0.0; $Dur = 0.0
    try { $Pos = $script:Player.Position.TotalSeconds } catch {}
    try { if ($script:Player.NaturalDuration.HasTimeSpan) { $Dur = $script:Player.NaturalDuration.TimeSpan.TotalSeconds } } catch {}
    $Active = (-not $script:Paused)

    # layout: 12 fixed rows, the rest is split between visualizer and lyrics
    $Rem = $script:H - 13
    switch ($script:Layout) {
        1 { $LyrH = [int][math]::Max(8, [math]::Min(16, [math]::Round($Rem * 0.72))) }
        2 { $LyrH = 3 }
        default { $LyrH = [int][math]::Max(6, [math]::Min(11, [math]::Round($Rem * 0.42))) }
    }
    $VizH = $Rem - $LyrH
    if ($VizH -gt 20) { $VizH = 20; $LyrH = $Rem - 20 }
    if ($VizH -lt 5) { $VizH = 5; $LyrH = [math]::Max(3, $Rem - 5) }
    $Nb = [math]::Max(8, [int][math]::Floor($In / 2))

    $Kick = 0.0; $Live = $false; $Rate = 0; $Vl = 0.0; $Vr = 0.0; $Bpm = 0.0; $BeatC = 0; $Glow = $D
    if ($script:EngineOK) {
        try {
            [BBEngine]::Update($Dt, $Nb, $Active)
            $Kick = [BBEngine]::Kick; $Live = [BBEngine]::Live; $Rate = [BBEngine]::Rate; $Vl = [BBEngine]::VuL; $Vr = [BBEngine]::VuR; $Bpm = [BBEngine]::Bpm; $BeatC = [BBEngine]::BeatCount
            # RGB theme and disco mode animate their own accent colors
            if ($script:Vt -and [BBEngine]::Dyn -ne 0 -and [BBEngine]::AccA) { $A = [BBEngine]::AccA; $D = [BBEngine]::AccD; $Hc = [BBEngine]::AccH }
            if ($script:Vt -and $script:Pulse) { $Glow = [BBEngine]::Glow } else { $Glow = $D }
        }
        catch { $script:EngineOK = $false; $script:EngineErr = $_.Exception.Message; Log-Err ('Engine update: ' + $_.Exception.Message) }
    }
    $Bc = $Glow

    # top bar: beat boxes + BPM + recorder status
    $Blink = ((Get-Date).Millisecond -lt 600)
    $Ch = ('  CH {0:D2}/{1}' -f ($script:QueueIndex + 1), $script:Queue.Count)
    $Lit = $BeatC % 4
    $Bx = @(); for ($q = 0; $q -lt 4; $q++) { if ($q -eq $Lit -and $Active -and $Bpm -gt 0) { $Bx += @($Hc, $G.Full) } else { $Bx += @($Dk, $G.Light) } }
    $BpmTxt = if ($Bpm -gt 0) { (' {0,3} BPM' -f [int][math]::Round($Bpm)) } else { ' --- BPM' }
    if ($script:Paused) { $Rp = @($script:cY, 'PAUSED') } else { $Rp = @($(if ($Blink) { $script:cR } else { $Dk }), ($G.Rec + ' REC')) }
    $Rec = Segs ($Bx + @($Gy, $BpmTxt, $Dk, '   ') + $Rp + @($Dk, '  T+', $Wh, (Format-Time $Pos), $Dk, $Ch))
    HRule 0 $G.TL $G.TR $Title0 $A $Rec $Bc

    # title (scrolls when too long) / artist + next up
    $Fv = if (Is-Fav $T) { ' ' + $G.Heart } else { '' }
    $Meta = $T.Extension.TrimStart('.').ToUpper() + '  ' + $T.SizeMB + 'MB'
    $Avail = $In - $Meta.Length - $Fv.Length - 2
    $Shown = $T.Title
    if ($Shown.Length -gt $Avail -and $Avail -gt 8) {
        $Loop = $Shown + '   ' + $G.Dot + '   '
        $Off = [int]([math]::Floor([datetime]::Now.Ticks / 3500000.0) % $Loop.Length)
        $Shown = ($Loop + $Loop).Substring($Off, $Avail)
    } else { $Shown = Fit $Shown $Avail }
    $TitleCol = if ($Kick -gt 0.5) { $Wh } else { $Hc }
    Row 1 (Segs @($TitleCol, $Shown, $script:cY, $Fv)) (Segs @($Dk, $Meta)) $Bc
    $Ar = $T.Artist; if ($T.Album) { $Ar = $Ar + '  ' + $G.Dot + '  ' + $T.Album }
    $NextT = $null; $Ni = $script:QueueIndex + 1
    if ($Ni -lt $script:Queue.Count) { $NextT = $script:Queue[$Ni] } elseif ($script:Repeat -eq 1 -and $script:Queue.Count -gt 1) { $NextT = $script:Queue[0] }
    $NxSeg = $null; if ($NextT) { $NxSeg = Segs @($Dk, 'NEXT ', $Gy, (Fit $NextT.Title 28)) }
    $ArMax = if ($NxSeg) { $In - $NxSeg.N - 3 } else { $In }
    Row 2 (Segs @($A, (Fit $Ar $ArMax))) $NxSeg $Bc

    # progress (the playhead flashes on the beat)
    $TL = Format-Time $Pos; $TR = Format-Time $Dur
    $BarW = [math]::Max(10, $In - $TL.Length - $TR.Length - 2)
    $Pct = if ($Dur -gt 0) { [math]::Max(0, [math]::Min(1, $Pos / $Dur)) } else { 0 }
    $Fill = [int][math]::Floor($Pct * $BarW)
    $Hd = if ($Fill -gt 0) { $Fill - 1 } else { 0 }
    $HeadCh = if ($Fill -gt 0) { $G.Full } else { '' }
    $HeadCol = if ($Kick -gt 0.3) { $Wh } else { $Hc }
    Row 3 (Segs @($Wh, ($TL + ' '), $A, ($G.Full * $Hd), $HeadCol, $HeadCh, $Dk, ($G.Light * ($BarW - $Fill)), $Wh, (' ' + $TR))) $null $Bc

    # status line: core settings + optional tags that fit, VU on the right
    $Vf = [int][math]::Floor($script:Volume / 10)
    $S = @($Dk, 'VOL ', $A, ($G.Full * $Vf), $Dk, ($G.Light * (10 - $Vf)), $Wh, (' {0,3}%' -f $script:Volume), $Dk, '  SPD ', $Wh, ('{0:N2}x' -f $script:Speed),
        $Dk, '  SHUF ', $(if ($script:Shuffle) { $A } else { $Dk }), $(if ($script:Shuffle) { 'smart' } else { 'off  ' }),
        $Dk, '  REP ', $(if ($script:Repeat) { $A } else { $Dk }), @('off', 'all', 'one')[$script:Repeat])
    $Len = (Segs $S).N
    $Cand = @()
    $Muted = $false; try { $Muted = [bool]$script:Player.IsMuted } catch {}
    if ($Muted) { $Cand += , @($script:cR, '  MUTE') }
    if ($script:Disco) { $Cand += , @($Hc, ('  DISCO ' + $script:DStyleNames[$script:DStyle])) }
    if ($script:LoopB -ge 0) { $Cand += , @($script:cY, '  A-B') } elseif ($script:LoopA -ge 0) { $Cand += , @($script:cY, '  A-') }
    if ($script:XfActive) { $Cand += , @($Hc, '  CROSSFADE') } elseif ($script:Crossfade -gt 0) { $Cand += , @($Dk, ('  XF ' + $script:Crossfade + 's')) }
    if ($script:SleepAt -gt [datetime]::MinValue) { $Cand += , @($script:cY, ('  SLEEP {0}m' -f [int][math]::Ceiling(($script:SleepAt - (Get-Date)).TotalMinutes))) }
    if ($script:SyncMs -gt 0) { $Cand += , @($Dk, ('  SYNC ' + $script:SyncMs + 'ms')) }
    if ($script:Sens -ne 0) { $Cand += , @($Dk, ('  SENS ' + $script:Sens)) }
    foreach ($Cd in $Cand) { if ($Len + $Cd[1].Length -le ($In - 24)) { $S += @($Cd[0], $Cd[1]); $Len += $Cd[1].Length } }
    $Nl = [int][math]::Round($Vl * 8); $Nr = [int][math]::Round($Vr * 8)
    $Vu = Segs @($Dk, 'L ', $A, ($G.Full * $Nl), $Dk, ($G.Light * (8 - $Nl)), $Dk, '  R ', $A, ($G.Full * $Nr), $Dk, ($G.Light * (8 - $Nr)))
    Row 4 (Segs $S) $Vu $Bc

    # visualizer block (or the up-next queue)
    $Mode = $script:VizMode
    $ThemeTag = $script:ThemeNames[$script:Theme] + '/' + $script:VariantNames[$script:Variant] + '  '
    if ($script:QueueView) { $VLabel = ' UP NEXT '; $VRight = $null }
    else {
        $VLabel = ' ' + $script:VizNames[$Mode] + ' '
        if (-not $script:EngineOK) { $VRight = Segs @($script:cR, 'ENGINE OFF') }
        elseif ($Live) { $VRight = Segs @($Dk, $ThemeTag, $A, 'LIVE ', $Dk, ('{0:N1}kHz' -f ($Rate / 1000.0))) }
        else { $VRight = Segs @($Dk, $ThemeTag, $script:cY, 'SIM') }
    }
    HRule 5 $G.ML $G.MR $VLabel $A $VRight $Bc
    if ($script:QueueView) {
        for ($k = 0; $k -lt $VizH; $k++) {
            $Qi = $script:QueueIndex - 1 + $k
            if ($Qi -ge 0 -and $Qi -lt $script:Queue.Count) {
                $Q = $script:Queue[$Qi]; $Cur = ($Qi -eq $script:QueueIndex)
                $Mk = if ($Cur) { $G.Sel + ' ' } else { '  ' }
                Row (6 + $k) (Segs @($A, $Mk, $(if ($Cur) { $Hc } elseif ($Qi -lt $script:QueueIndex) { $Dk } else { $Gy }), (Fit ('{0,3}  {1} - {2}' -f ($Qi + 1), $Q.Title, $Q.Artist) ($In - 2)))) $null $Bc
            } else { Row (6 + $k) $null $null $Bc }
        }
    }
    elseif ($Mode -ge 3 -or -not $script:EngineOK) {
        for ($k = 0; $k -lt $VizH; $k++) { Row (6 + $k) $null $null $Bc }
    }
    else {
        $Rows = [BBEngine]::Render($Mode, $In, $VizH)
        for ($k = 0; $k -lt $VizH; $k++) { Row (6 + $k) ([pscustomobject]@{ S = [string]$Rows[$k]; N = $In }) $null $Bc }
    }

    # ---- lyrics: bigger panel, centered, current line bold with a karaoke wipe, context fades away from it ----
    $Y0 = 6 + $VizH
    $Msg = $null
    if ((Get-Date) -lt $script:NoticeUntil) { $Msg = Segs @($script:cY, $script:Notice) }
    HRule $Y0 $G.ML $G.MR (' LYRICS [' + $script:LyricMode + '] ') $A $Msg $Bc
    $Ly = $script:Lyrics; $Idx = -1
    if ($Ly -and $Ly.Count -gt 0) {
        if ($script:LyricMode -eq 'synced') { for ($n = 0; $n -lt $Ly.Count; $n++) { if ($Ly[$n].T -le $Pos + 0.25) { $Idx = $n } else { break } } }
        else { $Idx = if ($Dur -gt 0) { [math]::Min($Ly.Count - 1, [int][math]::Floor($Pos / $Dur * $Ly.Count)) } else { 0 } }
    }
    if (-not $Ly -or $Ly.Count -eq 0) {
        $Mid = [int][math]::Floor($LyrH / 2) - 1
        for ($k = 0; $k -lt $LyrH; $k++) {
            $Tx = ''
            if ($k -eq $Mid) { $Tx = 'No lyrics for this track' } elseif ($k -eq $Mid + 1) { $Tx = 'Press G to fetch them online, or put a .lrc file next to the song' }
            if ($Tx) { $Pd = [math]::Max(0, [int](($In - $Tx.Length) / 2)); Row ($Y0 + 1 + $k) (Segs @($Dk, ((' ' * $Pd) + $Tx))) $null $Bc } else { Row ($Y0 + 1 + $k) $null $null $Bc }
        }
    }
    else {
        $CurRow = if ($LyrH -le 3) { 1 } else { [int][math]::Floor(($LyrH - 1) * 0.4) }
        for ($k = 0; $k -lt $LyrH; $k++) {
            $Li = $Idx - $CurRow + $k
            if ($Li -lt 0 -or $Li -ge $Ly.Count) { Row ($Y0 + 1 + $k) $null $null $Bc; continue }
            $Raw = [string]$Ly[$Li].Text; $Dist = $Li - $Idx
            if ($Dist -eq 0) {
                if ($Raw -eq '~') {
                    $Lt = $BeatC % 3; $Txt = (@(0, 1, 2) | ForEach-Object { if ($_ -le $Lt) { '*' } else { '.' } }) -join ' '
                } else { $Txt = Fit $Raw ($In - 6) }
                $Frac = 1.0
                if ($script:LyricMode -eq 'synced' -and $Raw -ne '~') {
                    $T0 = [double]$Ly[$Li].T
                    $T1 = if ($Li + 1 -lt $Ly.Count) { [double]$Ly[$Li + 1].T } else { $T0 + 6.0 }
                    $Span = [math]::Max(0.5, [math]::Min($T1 - $T0, [math]::Max(2.0, $Txt.Length * 0.11)))
                    $Frac = [math]::Max(0.0, [math]::Min(1.0, ($Pos - $T0) / $Span))
                }
                $Cut = [int][math]::Floor($Frac * $Txt.Length)
                $Pd = [math]::Max(0, [int](($In - $Txt.Length - 2) / 2))
                $Sung = $Txt.Substring(0, $Cut); $Rest = $Txt.Substring($Cut)
                $SungCol = $script:Bd + $(if ($Kick -gt 0.5) { $Hc } else { $Wh })
                Row ($Y0 + 1 + $k) (Segs @($A, ((' ' * $Pd) + $G.Sel + ' '), $SungCol, $Sung, ($script:Bd + $A), $Rest)) $null $Bc
            }
            else {
                $Txt = Fit $Raw ($In - 4)
                $Pd = [math]::Max(0, [int](($In - $Txt.Length) / 2))
                $Col = if ($Dist -lt 0) { if ($Dist -eq -1) { $D } else { $Dk } } else { $script:LyFade[[math]::Min($Dist - 1, 4)] }
                Row ($Y0 + 1 + $k) (Segs @($Col, ((' ' * $Pd) + $Txt))) $null $Bc
            }
        }
    }

    # controls
    $Yc = $Y0 + $LyrH + 1
    HRule $Yc $G.ML $G.MR ' CONTROLS ' $Dk $null $Bc
    Row ($Yc + 1) (Keys @('SPACE|pause', 'N/B|next/prev', 'LEFT/RIGHT|seek', 'UP/DOWN|volume', '[ ]|speed', 'M|mute', 'S|shuffle', 'R|repeat')) $null $Bc
    Row ($Yc + 2) (Keys @('1-4 / V|visual', 'C|theme', 'X|variant', 'D|disco', 'E|disco style', 'H|hit', 'Y|layout')) $null $Bc
    Row ($Yc + 3) (Keys @('ESC|back', 'TAB|queue', 'F|like', 'P|playlist', 'G|lyrics', 'A|loop A-B', 'W|crossfade', 'K/L|sync', ',/.|sens', 'T|sleep')) $null $Bc
    HRule ($Yc + 4) $G.BL $G.BR '' '' $null $Bc
    Flush-Frame
}
# used only if the console cannot do ANSI colors (very old Windows 10)
function Draw-PlayerBasic {
    $T = $script:CurrentTrack; $Lines = @()
    if (-not $T) { $Lines = @('BLACKBOX // AUDIO ENGINE v6', '', 'Nothing is playing. ESC = back') }
    else {
        $Pos = 0.0; $Dur = 0.0
        try { $Pos = $script:Player.Position.TotalSeconds } catch {}
        try { if ($script:Player.NaturalDuration.HasTimeSpan) { $Dur = $script:Player.NaturalDuration.TimeSpan.TotalSeconds } } catch {}
        $Pct = if ($Dur -gt 0) { [math]::Max(0, [math]::Min(1, $Pos / $Dur)) } else { 0 }; $Fill = [int][math]::Floor($Pct * 60)
        $Msg = if ((Get-Date) -lt $script:NoticeUntil) { $script:Notice } else { '' }
        $Lines = @('BLACKBOX // AUDIO ENGINE v6', '', $T.Title, ($T.Artist + '  ' + $T.Album), '', ('[' + ('#' * $Fill) + ('.' * (60 - $Fill)) + '] ' + (Format-Time $Pos) + ' / ' + (Format-Time $Dur)),
            ('VOL {0}%  SPD {1:N2}x  {2}' -f $script:Volume, $script:Speed, $(if ($script:Paused) { 'PAUSED' } else { 'playing' })), '', $Msg, '', 'SPACE pause  N/B next/prev  LEFT/RIGHT seek  UP/DOWN volume  ESC back')
    }
    try { [Console]::SetCursorPosition(0, 0) } catch {}
    foreach ($L in $Lines) { [Console]::WriteLine($L.PadRight(98).Substring(0, 98)) }
}
function Draw-Screen([double]$Dt) { if ($script:Vt) { Draw-Player $Dt } else { Draw-PlayerBasic } }

function Set-Sens([int]$Delta) {
    $script:Sens = [math]::Max(-12, [math]::Min(12, $script:Sens + $Delta))
    try { [BBEngine]::GainDb = [double]$script:Sens } catch {}
    Set-Notice ('Visualizer sensitivity ' + $script:Sens + ' dB'); Save-Settings
}
function Set-Sync([int]$Delta) {
    $script:SyncMs = [math]::Max(0, [math]::Min(300, $script:SyncMs + $Delta))
    try { [BBEngine]::SyncMs = [int]$script:SyncMs } catch {}
    Set-Notice ('Visual delay ' + $script:SyncMs + ' ms  (raise it until beats line up, e.g. with Bluetooth audio)'); Save-Settings
}
function Handle-Key($K) {
    switch ($K.Key) {
        'Spacebar' { Toggle-Pause; return $false }
        'LeftArrow' { Seek-By (-$script:SeekSeconds); return $false }
        'RightArrow' { Seek-By $script:SeekSeconds; return $false }
        'UpArrow' { Set-Volume ($script:Volume + 5); return $false }
        'DownArrow' { Set-Volume ($script:Volume - 5); return $false }
        'Tab' { $script:QueueView = -not $script:QueueView; return $false }
        'Escape' { return $true }
    }
    switch ($K.KeyChar.ToString().ToLowerInvariant()) {
        { $_ -match '^[1-4]$' } { $script:VizMode = [int]$_ - 1; $script:QueueView = $false; Save-Settings }
        'n' { Next-Track }
        'b' { Previous-Track }
        's' { Toggle-Shuffle; Set-Notice ('Smart shuffle ' + $(if ($script:Shuffle) { 'ON' } else { 'off' })) }
        'r' { $script:Repeat = ($script:Repeat + 1) % 3; Cancel-Preload }
        'v' { $script:VizMode = ($script:VizMode + 1) % $script:VizNames.Count; $script:QueueView = $false; Set-Notice ('Visualizer: ' + $script:VizNames[$script:VizMode]); Save-Settings }
        'g' { Fetch-Lyrics }
        'f' { Toggle-Fav $script:CurrentTrack; if ($script:CurrentTrack) { Set-Notice $(if (Is-Fav $script:CurrentTrack) { 'Added to Liked Songs' } else { 'Removed from Liked Songs' }) } }
        'm' { try { $Mm = -not $script:Player.IsMuted; $script:Player.IsMuted = $Mm; $script:Next.IsMuted = $Mm } catch {} }
        'c' { Set-Theme ($script:Theme + 1); Set-Notice ('Theme: ' + $script:ThemeNames[$script:Theme]); Save-Settings }
        'x' { $script:Variant = ($script:Variant + 1) % $script:VariantNames.Count; Apply-Palette; Set-Notice ('Color variant: ' + $script:VariantNames[$script:Variant]); Save-Settings }
        'd' { $script:Disco = -not $script:Disco; Apply-Palette; Set-Notice $(if ($script:Disco) { 'DISCO MODE on - E changes the style, H drops a hit' } else { 'Disco mode off' }) }
        'e' {
            $script:DStyle = ($script:DStyle + 1) % $script:DStyleNames.Count
            if (-not $script:Disco) { $script:Disco = $true }
            Apply-Palette; Set-Notice ('Disco style: ' + $script:DStyleNames[$script:DStyle]); Save-Settings
        }
        'h' { try { [BBEngine]::Hit() } catch {} }
        'y' { $script:Layout = ($script:Layout + 1) % 3; Set-Notice ('Layout: ' + @('balanced', 'lyrics focus', 'visual focus')[$script:Layout]); Save-Settings }
        'k' { Set-Sync -25 }
        'l' { Set-Sync 25 }
        ',' { Set-Sens -3 }
        '.' { Set-Sens 3 }
        '[' { Set-Speed -1 }
        ']' { Set-Speed 1 }
        '+' { Set-Volume ($script:Volume + 5) }
        '=' { Set-Volume ($script:Volume + 5) }
        '-' { Set-Volume ($script:Volume - 5) }
        'a' {
            $Pp = 0.0; try { $Pp = $script:Player.Position.TotalSeconds } catch {}
            if ($script:LoopA -lt 0) { $script:LoopA = $Pp; Set-Notice 'Loop start set - press A again for the end' }
            elseif ($script:LoopB -lt 0) { if ($Pp -gt $script:LoopA + 0.5) { $script:LoopB = $Pp; Set-Notice 'A-B loop ON (press A to clear)' } else { Set-Notice 'The end must come after the start' } }
            else { $script:LoopA = -1.0; $script:LoopB = -1.0; Set-Notice 'Loop cleared' }
        }
        'w' {
            $Opts = @(0, 2, 4, 6, 8); $Ix = [array]::IndexOf($Opts, [int]$script:Crossfade)
            $script:Crossfade = $Opts[($Ix + 1) % $Opts.Count]; Cancel-Preload; Save-Settings
            Set-Notice ('Crossfade: ' + $(if ($script:Crossfade -eq 0) { 'off' } else { [string]$script:Crossfade + 's' }))
        }
        'p' {
            if ($script:CurrentTrack) {
                try { [Console]::CursorVisible = $true } catch {}
                $Pm = Add-ToPlaylist @($script:CurrentTrack)
                try { [Console]::CursorVisible = $false } catch {}
                $script:LastDims = ''; Clear-Host
                if ($Pm) { Set-Notice $Pm }
            }
        }
        't' { $Opts = @(0, 15, 30, 45, 60, 90); $Cur = 0; if ($script:SleepAt -gt [datetime]::MinValue) { $Left = [int][math]::Ceiling(($script:SleepAt - (Get-Date)).TotalMinutes); for ($i = 0; $i -lt $Opts.Count; $i++) { if ($Opts[$i] -lt $Left) { $Cur = $i } } }
            $Nx = ($Cur + 1) % $Opts.Count; if ($Opts[$Nx] -eq 0) { $script:SleepAt = [datetime]::MinValue; try { $script:Player.Volume = $script:Volume / 100.0 } catch {} } else { $script:SleepAt = (Get-Date).AddMinutes($Opts[$Nx]) } }
        'q' { return $true }
    }
    return $false
}
function Player-Loop {
    Clear-Host; $script:LastDims = ''; try { [Console]::CursorVisible = $false } catch {}
    $Sw = [Diagnostics.Stopwatch]::StartNew(); $Last = 0.0; $Fails = 0
    try {
        while (-not $script:Closing) {
            if ($script:TrackEnded) {
                $script:TrackEnded = $false
                if ($script:XfActive) { Complete-Crossfade }
                elseif ($script:Repeat -eq 2 -and $script:CurrentTrack) { $script:Player.Position = [TimeSpan]::Zero; $script:Player.Play() }
                else { Next-Track; if (-not $script:CurrentTrack) { break } }
            }
            # sleep timer: fade the volume out over the last 25 seconds, then pause
            if ($script:SleepAt -gt [datetime]::MinValue) {
                $SLeft = ($script:SleepAt - (Get-Date)).TotalSeconds
                if ($SLeft -le 0) { try { $script:Player.Pause(); $script:Player.Volume = $script:Volume / 100.0 } catch {}; $script:Paused = $true; $script:SleepAt = [datetime]::MinValue; Set-Notice 'Sleep timer: paused' }
                elseif ($SLeft -le 25 -and -not $script:XfActive) { try { $script:Player.Volume = ($script:Volume / 100.0) * ($SLeft / 25.0) } catch {} }
            }
            # per-frame playback logic: A-B loop, play counts, crossfade
            $Pos = 0.0; $Dur = 0.0
            try { $Pos = $script:Player.Position.TotalSeconds; if ($script:Player.NaturalDuration.HasTimeSpan) { $Dur = $script:Player.NaturalDuration.TimeSpan.TotalSeconds } } catch {}
            if ($script:CurrentTrack) {
                if ($script:LoopB -ge 0 -and $Pos -ge $script:LoopB) { try { $script:Player.Position = [TimeSpan]::FromSeconds($script:LoopA) } catch {} }
                $Ck = $script:CurrentTrack.RelativePath.ToLowerInvariant()
                if ($Pos -ge 30 -and $script:CountedKey -ne $Ck) { $script:CountedKey = $Ck; $script:Plays[$Ck] = (Get-PlayCount $script:CurrentTrack) + 1; Save-Plays }
                if (-not $script:Paused -or $script:XfActive) { try { Update-Crossfade $Pos $Dur } catch { Log-Err ('Crossfade: ' + $_.Exception.Message); Cancel-Preload } }
            }
            $Now = $Sw.Elapsed.TotalSeconds; $Dt = [math]::Max(0.005, [math]::Min(0.25, $Now - $Last)); $Last = $Now
            try { Draw-Screen $Dt; $Fails = 0 }
            catch { $Fails++; Log-Err ('Draw: ' + $_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage); Set-Notice ('Draw error: ' + $_.Exception.Message); if ($Fails -gt 25) { throw } }
            while ([Console]::KeyAvailable) { $K = [Console]::ReadKey($true); if (Handle-Key $K) { return } }
            Pump-Dispatcher 18
        }
    } finally { try { [Console]::CursorVisible = $true } catch {}; [Console]::ResetColor(); Save-Session; Save-Settings; Save-Plays; Clear-Host }
}

# ---------- browsing ----------
function Show-Tracks([object[]]$Tracks, [string]$Title, [switch]$Ordered) {
    $Page = 0; $Size = 15; $Filter = ''; $Flash = ''; $All = @($Tracks | Where-Object { $_ })
    while ($true) {
        $List = $All; if ($Filter) { $List = @($All | Where-Object { ($_.Title + ' ' + $_.Artist + ' ' + $_.Album) -like ('*' + $Filter + '*') }) }
        $Pages = [math]::Max(1, [int][math]::Ceiling($List.Count / $Size)); if ($Page -ge $Pages) { $Page = 0 }
        Show-Header ('{0}   {1} tracks   page {2}/{3}{4}' -f $Title, $List.Count, ($Page + 1), $Pages, $(if ($Filter) { '   filter: ' + $Filter } else { '' }))
        foreach ($T in @($List | Select-Object -Skip ($Page * $Size) -First $Size)) {
            $Ti = if ($T.Title.Length -gt 40) { $T.Title.Substring(0, 40) } else { $T.Title }; $Ar = if ($T.Artist.Length -gt 24) { $T.Artist.Substring(0, 24) } else { $T.Artist }
            $Col = if ($script:CurrentTrack -and $script:CurrentTrack.Id -eq $T.Id) { $script:cA } else { $script:cG }
            [Console]::Write($Col + ('  {0,4} ' -f $T.Id) + $script:cY + $(if (Is-Fav $T) { '*' } else { ' ' }) + $Col + (' {0,-40} {1,-24} {2}' -f $Ti, $Ar, $T.Extension.TrimStart('.')) + $script:Rs + "`r`n")
        }
        Say ''
        if ($Flash) { Say ('  ' + $Flash) $script:cOk; $Flash = '' }
        Say '  <id> play   A <id> queue   F <id> like   P <id> add to playlist   PA add all listed   /text filter' $script:cX
        Say ('  N next page   P prev page   ALL play all   S shuffle ({0})   Q back' -f $(if ($script:Shuffle) { 'ON' } else { 'off' })) $script:cX
        $Cmd = Ask 'BLACKBOX'
        switch -regex ($Cmd) {
            '^\d+$' { $Id = [int]$Cmd; if (@($List | Where-Object { $_.Id -eq $Id }).Count) { Play-List $List $Id -Ordered:$Ordered } }
            '^a\s+(\d+)$' { $Id = [int]$Matches[1]; $T = @($List | Where-Object { $_.Id -eq $Id })[0]; if ($T) { [void]$script:Queue.Add($T) } }
            '^f\s+(\d+)$' { $Id = [int]$Matches[1]; $T = @($List | Where-Object { $_.Id -eq $Id })[0]; if ($T) { Toggle-Fav $T } }
            '^p\s+(\d+)$' { $Id = [int]$Matches[1]; $T = @($List | Where-Object { $_.Id -eq $Id })[0]; if ($T) { $Flash = Add-ToPlaylist @($T) } }
            '^pa$' { if ($List.Count) { $Flash = Add-ToPlaylist $List } }
            '^/(.*)$' { $Filter = $Matches[1].Trim(); $Page = 0 }
            '^n$' { $Page++ }
            '^p$' { $Page = [math]::Max(0, $Page - 1) }
            '^all$' { if ($List.Count) { Play-List $List -1 -Ordered:$Ordered } }
            '^s$' { $script:Shuffle = -not $script:Shuffle; Save-Settings }
            '^q$' { return }
        }
    }
}
function Get-PlaylistFiles { @(Get-ChildItem -LiteralPath $script:PlaylistRoot -Filter *.m3u8 -File -ErrorAction SilentlyContinue | Sort-Object Name) }
function Safe-PlName([string]$N) { return (($N -replace '[\\/:*?"<>|]', '').Trim()) }
function Read-Playlist([string]$Path) {
    $Map = @{}; foreach ($Tk in $script:Library) { $Map[$Tk.RelativePath.ToLowerInvariant()] = $Tk }
    return @(Get-Content -LiteralPath $Path -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $Kk = $_.Trim().Replace('/', '\').ToLowerInvariant(); if ($Map.ContainsKey($Kk)) { $Map[$Kk] } })
}
function Write-Playlist([string]$Path, [object[]]$Tracks) { (@('#EXTM3U') + @($Tracks | Where-Object { $_ } | ForEach-Object { $_.RelativePath })) | Set-Content -LiteralPath $Path -Encoding UTF8 }
function Pick-Playlist([string]$Title = 'ADD TO PLAYLIST') {
    while ($true) {
        $Files = @(Get-PlaylistFiles)
        Show-Header $Title
        for ($i = 0; $i -lt $Files.Count; $i++) { Say ('  [{0,2}] {1}' -f ($i + 1), $Files[$i].BaseName) $script:cG }
        if ($Files.Count -eq 0) { Say '  No playlists yet.' $script:cY }
        Say ''; Say '  <n> choose   N new playlist   Q cancel' $script:cX
        $C = Ask 'BLACKBOX'
        if ($C -match '^\d+$') { $Ix = [int]$C - 1; if ($Ix -ge 0 -and $Ix -lt $Files.Count) { return $Files[$Ix].FullName } }
        elseif ($C -ieq 'n') {
            $Nm = Safe-PlName (Ask 'New playlist name')
            if ($Nm) { $Pp = Join-Path $script:PlaylistRoot ($Nm + '.m3u8'); if (-not (Test-Path -LiteralPath $Pp)) { Write-Playlist $Pp @() }; return $Pp }
        }
        elseif ($C -ieq 'q') { return $null }
    }
}
function Add-ToPlaylist([object[]]$Tracks) {
    $Pp = Pick-Playlist; if (-not $Pp) { return '' }
    $Cur = @(Read-Playlist $Pp); $Have = @{}; foreach ($Tk in $Cur) { $Have[$Tk.RelativePath.ToLowerInvariant()] = $true }
    $Add = @($Tracks | Where-Object { $_ -and -not $Have.ContainsKey($_.RelativePath.ToLowerInvariant()) })
    Write-Playlist $Pp (@($Cur) + $Add)
    return ('Added {0} track(s) to {1}' -f $Add.Count, [IO.Path]::GetFileNameWithoutExtension($Pp))
}
function Show-PlaylistView([string]$Name, [string]$Path) {
    $Page = 0; $Size = 13; $Flash = ''
    while ($true) {
        if ($Path) { $Tr = @(Read-Playlist $Path) } else { $Tr = @($script:Library | Where-Object { Is-Fav $_ }) }
        $Pages = [math]::Max(1, [int][math]::Ceiling($Tr.Count / $Size)); if ($Page -ge $Pages) { $Page = $Pages - 1 }; if ($Page -lt 0) { $Page = 0 }
        Show-Header ('{0}   {1} tracks   page {2}/{3}' -f $Name, $Tr.Count, ($Page + 1), $Pages)
        $Base = $Page * $Size
        for ($i = $Base; $i -lt [math]::Min($Tr.Count, $Base + $Size); $i++) {
            $Tk = $Tr[$i]; $Col = if ($script:CurrentTrack -and $script:CurrentTrack.Id -eq $Tk.Id) { $script:cA } else { $script:cG }
            [Console]::Write($Col + ('  {0,3} ' -f ($i + 1)) + (' {0,-40} {1,-24}' -f (Fit $Tk.Title 40), (Fit $Tk.Artist 24)) + $script:Rs + "`r`n")
        }
        if ($Tr.Count -eq 0) { Say '  Empty. Add songs with P while playing, or P <id> in the library.' $script:cY }
        Say ''
        if ($Flash) { Say ('  ' + $Flash) $script:cOk; $Flash = '' }
        Say '  <n> play from here   ALL play in order   S smart shuffle   N next page   P prev page   Q back' $script:cX
        if ($Path) { Say '  + <id> add library track   X <n> remove   U <n> move up   D <n> move down' $script:cX }
        $C = Ask 'BLACKBOX'
        switch -regex ($C) {
            '^\d+$' { $Ix = [int]$C - 1; if ($Ix -ge 0 -and $Ix -lt $Tr.Count) { Play-List $Tr $Tr[$Ix].Id -Ordered }; break }
            '^all$' { if ($Tr.Count) { Play-List $Tr -1 -Ordered }; break }
            '^s$' { if ($Tr.Count) { Play-List @(Smart-Order $Tr) -1 -Ordered }; break }
            '^n$' { $Page++; break }
            '^p$' { $Page = [math]::Max(0, $Page - 1); break }
            '^\+\s*(\d+)$' { if ($Path) { $Id = [int]$Matches[1]; $Tk = @($script:Library | Where-Object { $_.Id -eq $Id })[0]; if ($Tk) { $Flash = Add-ToPlaylistDirect $Path $Tk } }; break }
            '^x\s+(\d+)$' { if ($Path) { $Ix = [int]$Matches[1] - 1; if ($Ix -ge 0 -and $Ix -lt $Tr.Count) { $Keep = @(); for ($j = 0; $j -lt $Tr.Count; $j++) { if ($j -ne $Ix) { $Keep += $Tr[$j] } }; Write-Playlist $Path $Keep } }; break }
            '^u\s+(\d+)$' { if ($Path) { $Ix = [int]$Matches[1] - 1; if ($Ix -ge 1 -and $Ix -lt $Tr.Count) { $Tmp = $Tr[$Ix]; $Tr[$Ix] = $Tr[$Ix - 1]; $Tr[$Ix - 1] = $Tmp; Write-Playlist $Path $Tr } }; break }
            '^d\s+(\d+)$' { if ($Path) { $Ix = [int]$Matches[1] - 1; if ($Ix -ge 0 -and $Ix -lt $Tr.Count - 1) { $Tmp = $Tr[$Ix]; $Tr[$Ix] = $Tr[$Ix + 1]; $Tr[$Ix + 1] = $Tmp; Write-Playlist $Path $Tr } }; break }
            '^q$' { return }
        }
    }
}
function Add-ToPlaylistDirect([string]$Path, $Track) {
    $Cur = @(Read-Playlist $Path)
    foreach ($Tk in $Cur) { if ($Tk.Id -eq $Track.Id) { return 'Already in this playlist' } }
    Write-Playlist $Path (@($Cur) + @($Track)); return ('Added: ' + $Track.Title)
}
function Show-Playlists {
    $Flash = ''
    while ($true) {
        $Files = @(Get-PlaylistFiles)
        Show-Header 'PLAYLISTS'
        [Console]::Write($script:cA + '  [ 0] ' + $script:cW + ('{0,-34}' -f 'LIKED SONGS') + $script:cG + ('{0,4} tracks' -f @($script:Library | Where-Object { Is-Fav $_ }).Count) + $script:Rs + "`r`n")
        for ($i = 0; $i -lt $Files.Count; $i++) {
            $Cnt = @(Read-Playlist $Files[$i].FullName).Count
            [Console]::Write($script:cA + ('  [{0,2}] ' -f ($i + 1)) + $script:cW + ('{0,-34}' -f (Fit $Files[$i].BaseName 34)) + $script:cG + ('{0,4} tracks' -f $Cnt) + $script:Rs + "`r`n")
        }
        Say ''
        if ($Flash) { Say ('  ' + $Flash) $script:cOk; $Flash = '' }
        Say '  <n> open   P <n> play   S <n> smart shuffle   N new   R <n> rename   D <n> delete' $script:cX
        Say '  S (alone) save the current queue as a playlist   Q back' $script:cX
        $C = Ask 'BLACKBOX'
        switch -regex ($C) {
            '^0$' { Show-PlaylistView 'LIKED SONGS' ''; break }
            '^\d+$' { $Ix = [int]$C - 1; if ($Ix -ge 0 -and $Ix -lt $Files.Count) { Show-PlaylistView $Files[$Ix].BaseName $Files[$Ix].FullName }; break }
            '^p\s+(\d+)$' { $Ix = [int]$Matches[1] - 1; if ($Ix -ge 0 -and $Ix -lt $Files.Count) { $Tr = @(Read-Playlist $Files[$Ix].FullName); if ($Tr.Count) { Play-List $Tr -1 -Ordered } }; break }
            '^s\s+(\d+)$' { $Ix = [int]$Matches[1] - 1; if ($Ix -ge 0 -and $Ix -lt $Files.Count) { $Tr = @(Read-Playlist $Files[$Ix].FullName); if ($Tr.Count) { Play-List @(Smart-Order $Tr) -1 -Ordered } }; break }
            '^s$' {
                if ($script:Queue.Count -eq 0) { $Flash = 'Queue is empty.' }
                else { $Nm = Safe-PlName (Ask 'Name for this queue'); if ($Nm) { Write-Playlist (Join-Path $script:PlaylistRoot ($Nm + '.m3u8')) @($script:Queue); $Flash = 'Saved ' + $Nm } }
                break
            }
            '^n$' { $Nm = Safe-PlName (Ask 'New playlist name'); if ($Nm) { $Pp = Join-Path $script:PlaylistRoot ($Nm + '.m3u8'); if (-not (Test-Path -LiteralPath $Pp)) { Write-Playlist $Pp @(); $Flash = 'Created ' + $Nm } }; break }
            '^r\s+(\d+)$' {
                $Ix = [int]$Matches[1] - 1
                if ($Ix -ge 0 -and $Ix -lt $Files.Count) { $Nm = Safe-PlName (Ask 'New name'); if ($Nm) { try { Rename-Item -LiteralPath $Files[$Ix].FullName -NewName ($Nm + '.m3u8') -ErrorAction Stop; $Flash = 'Renamed to ' + $Nm } catch { $Flash = 'Rename failed' } } }
                break
            }
            '^d\s+(\d+)$' {
                $Ix = [int]$Matches[1] - 1
                if ($Ix -ge 0 -and $Ix -lt $Files.Count) { if ((Ask ('Delete ' + $Files[$Ix].BaseName + '? type YES')) -ceq 'YES') { Remove-Item -LiteralPath $Files[$Ix].FullName -Force; $Flash = 'Deleted' } }
                break
            }
            '^q$' { return }
        }
    }
}
function Show-Stats {
    Show-Header 'LIBRARY STATISTICS'
    $Lib = @($script:Library); $Size = 0.0; if ($Lib.Count) { $Size = [double](($Lib | Measure-Object SizeMB -Sum).Sum) }
    $Top = @($Lib | Group-Object Artist | Sort-Object Count -Descending | Select-Object -First 6)
    $Total = 0; foreach ($Pv in $script:Plays.Values) { $Total += [int]$Pv }
    Say ('  TRACKS  {0}    ARTISTS  {1}    SIZE  {2:N1} MB    LIKED  {3}    PLAYS  {4}' -f $Lib.Count, @($Lib | Group-Object Artist).Count, $Size, $script:Favs.Count, $Total) $script:cW
    Say ''; Say '  TOP ARTISTS' $script:cA
    $Max = if ($Top.Count) { $Top[0].Count } else { 1 }
    foreach ($Gr in $Top) { Say ('  {0,-26} {1} {2}' -f (Fit $Gr.Name 26), ($script:G.Full * [int][math]::Ceiling(36 * $Gr.Count / $Max)), $Gr.Count) $script:cA }
    Say ''; Say '  MOST PLAYED' $script:cA
    $Mp = @($Lib | Where-Object { (Get-PlayCount $_) -gt 0 } | Sort-Object { Get-PlayCount $_ } -Descending | Select-Object -First 6)
    if ($Mp.Count -eq 0) { Say '  Nothing yet - a play counts after 30 seconds of listening.' $script:cX }
    foreach ($Tk in $Mp) { Say ('  {0,-40} {1,-22} {2,4}x' -f (Fit $Tk.Title 40), (Fit $Tk.Artist 22), (Get-PlayCount $Tk)) $script:cG }
    Say ''; Say '  FORMATS' $script:cA
    foreach ($Gr in @($Lib | Group-Object Extension | Sort-Object Count -Descending)) { Say ('  {0,-8} {1} {2}' -f $Gr.Name, ($script:G.Full * [int][math]::Ceiling(36 * $Gr.Count / [math]::Max(1, $Lib.Count))), $Gr.Count) $script:cD }
    Say ''; Wait-Enter
}

# ---------- tools ----------
function Write-Test-Wav([string]$Path) {
    $Sr = 44100; $Ds = $Sr * 2; $St = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read); $Wr = New-Object IO.BinaryWriter($St)
    try {
        $Wr.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $Wr.Write([int](36 + $Ds)); $Wr.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $Wr.Write([int]16); $Wr.Write([short]1); $Wr.Write([short]1)
        $Wr.Write([int]$Sr); $Wr.Write([int]($Sr * 2)); $Wr.Write([short]2); $Wr.Write([short]16); $Wr.Write([Text.Encoding]::ASCII.GetBytes('data')); $Wr.Write([int]$Ds)
        for ($i = 0; $i -lt $Sr; $i++) { $Wr.Write([short]([math]::Round([math]::Sin(2 * [math]::PI * 880 * $i / $Sr) * 10000))) }
    } finally { $Wr.Dispose(); $St.Dispose() }
}
function Pick-Theme {
    while ($true) {
        Show-Header 'COLORS'
        for ($i = 0; $i -lt $script:ThemeNames.Count; $i++) {
            if ($i -eq 12) { $Fl = [int[]]$script:RainbowStops } else { $Fl = Get-Stops $i $script:Variant }
            $Mk = if ($i -eq $script:Theme) { $script:G.Sel } else { ' ' }
            [Console]::Write($script:cA + ' ' + $Mk + $script:cG + (' {0,2} {1,-9} ' -f ($i + 1), $script:ThemeNames[$i]) + (Swatch ([int[]]$Fl)) + "`r`n")
        }
        Say ''
        Say ('  Variant: {0}      Disco: {1}' -f $script:VariantNames[$script:Variant], $(if ($script:Disco) { 'ON' } else { 'off' })) $script:cW
        Say '  <n> pick theme   V next variant (gradient/solid/reverse/duo)   D disco on/off   Q back' $script:cX
        $C = Ask 'BLACKBOX'
        if ($C -match '^\d+$') { $Nn = [int]$C - 1; if ($Nn -ge 0 -and $Nn -lt $script:ThemeNames.Count) { Set-Theme $Nn; Save-Settings } }
        elseif ($C -ieq 'v') { $script:Variant = ($script:Variant + 1) % $script:VariantNames.Count; Apply-Palette; Save-Settings }
        elseif ($C -ieq 'd') { $script:Disco = -not $script:Disco; Apply-Palette }
        elseif ($C -ieq 'q') { return }
    }
}
function Get-LibMap { $Map = @{}; foreach ($Tk in $script:Library) { $Map[$Tk.RelativePath.ToLowerInvariant()] = $Tk }; return $Map }
function Show-Recent {
    $Map = Get-LibMap
    $Tr = @($script:Hist | ForEach-Object { if ($Map.ContainsKey($_)) { $Map[$_] } })
    if ($Tr.Count -eq 0) { Show-Header 'RECENTLY PLAYED'; Say '  Nothing played yet.' $script:cY; Wait-Enter; return }
    Show-Tracks $Tr 'RECENTLY PLAYED' -Ordered
}
function Resume-Session {
    $J = $null; try { $J = Get-Content -LiteralPath $script:SessionPath -Raw | ConvertFrom-Json } catch {}
    if (-not $J) { Show-Header 'RESUME'; Say '  No saved session yet. It is saved when you leave the player.' $script:cY; Wait-Enter; return }
    $Map = Get-LibMap
    $Tr = @(@($J.queue) | ForEach-Object { $Kk = ([string]$_).ToLowerInvariant(); if ($Map.ContainsKey($Kk)) { $Map[$Kk] } })
    if ($Tr.Count -eq 0) { return }
    $script:Queue.Clear(); foreach ($Tk in $Tr) { [void]$script:Queue.Add($Tk) }
    $script:QueueIndex = [math]::Max(0, [math]::Min($Tr.Count - 1, [int]$J.index))
    if (Start-Track $script:Queue[$script:QueueIndex]) {
        try { if ([double]$J.pos -gt 2) { $script:Player.Position = [TimeSpan]::FromSeconds([double]$J.pos) } } catch {}
        Player-Loop
    }
}
function Start-SmartMix {
    if ($script:Library.Count -eq 0) { return }
    $Mix = @(Smart-Order $script:Library | Select-Object -First 25)
    Play-List $Mix -1 -Ordered
}
function Show-Tools {
    while ($true) {
        Show-Header 'TOOLS'
        Say ('  ' + (Item '1' 'Rebuild index') + '  ' + (Item '2' 'Audio test'))
        Say ('  ' + (Item '3' 'Decoder test') + '  ' + (Item '4' 'Colors / themes'))
        Say ('  ' + (Item '5' 'Analyzer info') + '  ' + (Item 'Q' 'Back')); Say ''
        switch ((Ask 'BLACKBOX').ToLowerInvariant()) {
            '1' { Show-Header 'REBUILD'; Build-Library $true; Say ('  INDEXED: {0} tracks' -f $script:Library.Count) $script:cA; Pump-Dispatcher 800 }
            '2' {
                Show-Header 'AUDIO OUTPUT TEST'; $Wav = Join-Path $script:DataRoot 'blackbox-test.wav'
                try { Write-Test-Wav $Wav; $Sp = New-Object System.Media.SoundPlayer($Wav); $Sp.Load(); $Sp.PlaySync(); Say '  You should have heard a beep. If not, check the Windows output device.' $script:cY } catch { Say ('  TEST FAILED: ' + $_.Exception.Message) $script:cR }
                Wait-Enter
            }
            '3' {
                Show-Header 'DECODER TEST'; $T = @($script:Library | Where-Object { $_.Extension -eq '.mp3' } | Select-Object -First 1)
                if ($T.Count -eq 0) { Say '  No MP3 found.' $script:cY } else {
                    Say ('  ' + $T[0].RelativePath) $script:cG
                    if (Start-Track $T[0]) { Say '  Decoder ACCEPTED by Windows. Playing 5 seconds...' $script:cA; for ($i = 0; $i -lt 50; $i++) { Pump-Dispatcher 100 }; try { $script:Player.Stop() } catch {}; $script:CurrentTrack = $null }
                    else { Say ('  FAILED: ' + $script:MediaError) $script:cR }
                }
                Wait-Enter
            }
            '4' { Pick-Theme }
            '5' {
                Show-Header 'ANALYZER'
                Say '  The visualizer analyzes the real audio your PC is playing (WASAPI loopback of the' $script:cG
                Say '  default output device + FFT). It only reads what is being played; nothing is recorded.' $script:cG
                Say ''
                if (-not $script:EngineOK) { Say ('  Engine unavailable: ' + $script:EngineErr) $script:cR; Say '  Playback still works, the visualizer is disabled.' $script:cY }
                else {
                    Say '  Restarting capture ...' $script:cG
                    try { [void][BBEngine]::Start() } catch {}
                    if ([BBEngine]::Live) { Say ('  SIGNAL TAP LIVE   {0} Hz' -f [BBEngine]::Rate) $script:cOk }
                    else { Say ('  No loopback capture: ' + [BBEngine]::Error) $script:cY; Say '  The visualizer runs in SIM mode (animated, not real analysis).' $script:cY }
                }
                Say ''; Say ('  Console colors (24-bit ANSI): ' + $(if ($script:Vt) { 'ON' } else { 'OFF - basic player screen in use' })) $script:cG
                Wait-Enter
            }
            'q' { return }
        }
    }
}
function Boot-Line([string]$Tag, [string]$TagC, [string]$Text) {
    [Console]::Write($script:cD + '  [ ' + $TagC + $Tag + $script:cD + ' ] ' + $script:cG + $Text + $script:Rs + "`r`n")
    if ($script:BootAnim) { Start-Sleep -Milliseconds 80 }
}
function Run-Boot {
    Clear-Host
    Say ''
    Say ('  ' + $script:G.Rec + '  B L A C K B O X   //   A U D I O   E N G I N E   v 6') $script:cA
    Say ('  ' + (Get-Strip 60)) $script:cD
    Say '  POWER-ON SELF TEST' $script:cX
    Say ''
    Initialize-Media
    Boot-Line ' OK ' $script:cOk 'MEDIA CORE      Windows MediaPlayer (WPF)'
    Boot-Line ' .. ' $script:cY 'SIGNAL TAP      building analyzer engine'
    if (Start-Engine) {
        if ([BBEngine]::Live) { Boot-Line ' OK ' $script:cOk ('SIGNAL TAP      WASAPI loopback, {0} Hz - real spectrum' -f [BBEngine]::Rate) }
        else { Boot-Line 'WARN' $script:cY ('SIGNAL TAP      no loopback (' + (Fit ([string][BBEngine]::Error) 50) + ') - simulated visuals') }
    }
    else { Boot-Line 'FAIL' $script:cR ('SIGNAL TAP      analyzer unavailable - visualizer off (see Data\error.log)') }
    Set-Theme $script:Theme
    Boot-Line ' OK ' $script:cOk ('DISPLAY         ' + $(if ($script:Vt) { '24-bit color' } else { 'basic (no ANSI support)' }))
    Boot-Line ' OK ' $script:cOk ('PLAYBACK        smart shuffle, crossfade ' + $(if ($script:Crossfade -gt 0) { [string]$script:Crossfade + 's' } else { 'off' }))
    Build-Library
    Boot-Line ' OK ' $script:cOk ('LIBRARY         {0} tracks indexed' -f $script:Library.Count)
    if ($script:BootAnim) { Start-Sleep -Milliseconds 350 }
}
function Main-Menu {
    while (-not $script:Closing) {
        Show-Header ('{0} tracks   |   theme {1}' -f $script:Library.Count, $script:ThemeNames[$script:Theme])
        if ($script:CurrentTrack) { Say ('  NOW PLAYING: {0} - {1}' -f $script:CurrentTrack.Artist, $script:CurrentTrack.Title) $script:cA } else { Say ('  Drop songs in ' + (Split-Path $script:MusicRoot -Leaf) + ', then pick a track.') $script:cX }
        Say ''
        Say ('  ' + (Item '1' 'LIBRARY') + (Item '2' 'SEARCH') + (Item '3' 'SMART SHUFFLE'))
        Say ('  ' + (Item '4' 'NOW PLAYING') + (Item '5' 'QUEUE') + (Item '6' 'FAVORITES'))
        Say ('  ' + (Item '7' 'PLAYLISTS') + (Item '8' 'SMART MIX') + (Item '9' 'STATISTICS'))
        Say ('  ' + (Item 'T' 'TOOLS / COLORS') + (Item 'R' 'RESUME') + (Item 'H' 'RECENT'))
        Say ('  ' + (Item '0' 'EXIT'))
        Say ''
        switch (Ask 'BLACKBOX') {
            '1' { Show-Tracks $script:Library 'LIBRARY' }
            '2' { $Q = Ask 'Search artist/title/album'; if ($Q) { Show-Tracks @($script:Library | Where-Object { ($_.Title + ' ' + $_.Artist + ' ' + $_.Album + ' ' + $_.FileName) -like ('*' + $Q + '*') }) ('SEARCH: ' + $Q) } }
            '3' { if ($script:Library.Count) { $script:Shuffle = $true; Play-List $script:Library } }
            '4' { Player-Loop }
            '5' { Show-Tracks @($script:Queue) 'QUEUE' -Ordered }
            '6' { Show-Tracks @($script:Library | Where-Object { Is-Fav $_ }) 'FAVORITES' }
            '7' { Show-Playlists }
            '8' { Start-SmartMix }
            '9' { Show-Stats }
            't' { Show-Tools }
            'r' { Resume-Session }
            'h' { Show-Recent }
            '0' { $script:Closing = $true }
        }
    }
}

# ---------- embedded native sources ----------
$script:WinSrc = @'
#pragma warning disable
using System;
using System.Runtime.InteropServices;

public static class BBWin
{
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr hConsole, out int mode);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr hConsole, int mode);

    // ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004 on the stdout handle
    public static bool EnableVt()
    {
        try
        {
            IntPtr h = GetStdHandle(-11);
            int m;
            if (!GetConsoleMode(h, out m)) return false;
            if ((m & 4) != 0) return true;
            return SetConsoleMode(h, m | 4);
        }
        catch { return false; }
    }
}
'@
$script:EngineSrc = @'
#pragma warning disable
using System;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;

// ---------------- WASAPI COM interfaces (only the methods we call, in vtable order) ----------------
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class BBMMDeviceEnumerator { }

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IBBDeviceEnumerator
{
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IBBDevice device);
}

[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IBBDevice
{
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
}

[ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IBBAudioClient
{
    [PreserveSig] int Initialize(int shareMode, int streamFlags, long bufferDuration, long periodicity, IntPtr format, IntPtr sessionGuid);
    [PreserveSig] int GetBufferSize(out uint bufferSize);
    [PreserveSig] int GetStreamLatency(out long latency);
    [PreserveSig] int GetCurrentPadding(out uint padding);
    [PreserveSig] int IsFormatSupported(int shareMode, IntPtr format, out IntPtr closest);
    [PreserveSig] int GetMixFormat(out IntPtr format);
    [PreserveSig] int GetDevicePeriod(out long defaultPeriod, out long minPeriod);
    [PreserveSig] int Start();
    [PreserveSig] int Stop();
    [PreserveSig] int Reset();
    [PreserveSig] int SetEventHandle(IntPtr handle);
    [PreserveSig] int GetService(ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object service);
}

[ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IBBCaptureClient
{
    [PreserveSig] int GetBuffer(out IntPtr data, out uint frames, out uint flags, out ulong devicePosition, out ulong qpcPosition);
    [PreserveSig] int ReleaseBuffer(uint frames);
    [PreserveSig] int GetNextPacketSize(out uint frames);
}

public static class BBEngine
{
    const int N = 2048;
    const int RING = 16384;
    const int MASK = RING - 1;
    const int PN = 48;
    const string ESC = "\u001b";

    // ---- capture state ----
    static float[] ringL = new float[RING];
    static float[] ringR = new float[RING];
    static long total = 0;
    static int wp = 0;
    static object sync = new object();
    static Thread th;
    static volatile bool run = false;
    static volatile int state = 0;       // 0 = not started, 1 = capturing, -1 = failed (retrying)
    static volatile int lastData = 0;
    public static int Rate = 48000;
    public static string Error = "";

    public static bool Live { get { return state == 1; } }
    public static int State { get { return state; } }

    // ---- analysis state ----
    static double[] win = MakeWin();
    static double[] re = new double[N];
    static double[] im = new double[N];
    static double[] mag = new double[N / 2 + 2];
    static double[] raw = new double[N];
    static double[] vbuf = new double[0];
    static double[] dbv = new double[0];
    static double[] bars = new double[0];
    static double[] peaks = new double[0];
    static double[] hold = new double[0];
    static double ceilDb = -30;
    static double simT = 0;
    static double pkHoldL = 0, pkHoldR = 0;

    public static double GainDb = 0;
    public static string AccA = "", AccD = "", AccH = "";     // accent colors while RGB/disco palettes are animating
    static int dyn = 0;                                        // 0 = fixed theme, 1 = RGB cycle, 2 = disco (beat synced)
    static double hue = 0, hueTarget = 0;
    static Random rnd = new Random();
    const int NP = 200;
    static double[] px = new double[NP], py = new double[NP], pvx = new double[NP], pvy = new double[NP], pl = new double[NP], pl0 = new double[NP];
    public static int Dyn { get { return dyn; } }
    public static double Kick = 0, Energy = 0, VuL = 0, VuR = 0, PkL = 0, PkR = 0;
    public static double Snare = 0, Flash = 0, Bpm = 0, BeatPhase = 0;
    public static int BeatCount = 0;
    public static int SyncMs = 0;                 // delays the analysis window (Bluetooth audio lags behind the capture)
    public static bool FxOn = true;               // pulse + flash effects
    public static bool BeatNow = false;           // true for the one frame in which a beat was detected
    public static string Glow = "";               // continuously pulsing border color
    static int dstyle = 0;
    static int accR = 255, accG = 122, accB = 0;
    static double[] boost = new double[0], prevV = new double[0], wave = new double[0];
    static double fluxAvg = 0, sFluxAvg = 0, sCool = 0, kCool = 0, waveAcc = 0, waveEnv = 0.01, sinceKick = 0, procTime = 0;
    static double[] ivals = new double[8];
    static int ivN = 0;
    static double lastKickT = -9;
    static bool hitPending = false;
    static long procPos = 0;
    static double lpY = 0, envY = 0;
    static double[] eh = new double[6];
    static int coolSamples = 0;
    static double[] rawL = new double[N], rawR = new double[N];
    static double[] rAge = new double[] { 9, 9, 9, 9 };
    static double prevSimT = 0;
    public static int DStyle { get { return dstyle; } set { dstyle = value; } }

    // ---- palette / glyphs ----
    static int[] stops = new int[] { 90, 30, 0, 255, 122, 0, 255, 214, 120 };
    static string[] fg = new string[PN];
    static bool vt = true;
    static bool uni = true;
    static char[] blk = new char[] { ' ', '\u2581', '\u2582', '\u2583', '\u2584', '\u2585', '\u2586', '\u2587', '\u2588' };
    static char cFull = '\u2588', cUp = '\u2580', cLow = '\u2584', cCap = '\u2580';

    static BBEngine() { BuildPalette(); }

    static double[] MakeWin()
    {
        double[] w = new double[N];
        for (int i = 0; i < N; i++) w[i] = 0.5 - 0.5 * Math.Cos(2.0 * Math.PI * i / (N - 1));
        return w;
    }

    // =====================================================================================
    //  Public API
    // =====================================================================================
    public static void SetGlyphs(bool unicode, bool vtOn)
    {
        uni = unicode; vt = vtOn;
        if (unicode)
        {
            blk = new char[] { ' ', '\u2581', '\u2582', '\u2583', '\u2584', '\u2585', '\u2586', '\u2587', '\u2588' };
            cFull = '\u2588'; cUp = '\u2580'; cLow = '\u2584'; cCap = '\u2580';
        }
        else
        {
            blk = new char[] { ' ', '.', '.', ':', ':', '=', '=', '#', '#' };
            cFull = '#'; cUp = '\''; cLow = '.'; cCap = '-';
        }
    }

    public static void SetPalette(int[] s)
    {
        if (s == null || s.Length < 6) return;
        stops = s;
        BuildPalette();
    }

    public static void SetDyn(int mode)
    {
        dyn = mode;
        if (mode == 0) { AccA = ""; AccD = ""; AccH = ""; }
    }

    public static bool Start()
    {
        Stop();
        state = 0; Error = ""; run = true;
        th = new Thread(CaptureMain);
        th.IsBackground = true;
        th.Name = "BBCapture";
        th.Start();
        int waited = 0;
        while (state == 0 && waited < 3000) { Thread.Sleep(20); waited += 20; }
        return state == 1;
    }

    public static void Stop()
    {
        run = false;
        Thread t = th; th = null;
        if (t != null) { try { t.Join(1000); } catch { } }
        state = 0;
    }

    public static void SetAccent(int r, int g, int b) { accR = r; accG = g; accB = b; }
    public static void Hit() { hitPending = true; }

    // dt = seconds since the previous call, nb = number of spectrum bands, active = a track is playing
    public static void Update(double dt, int nb, bool active)
    {
        if (nb < 4) nb = 4;
        if (nb > 120) nb = 120;
        if (bars.Length != nb) Alloc(nb);

        bool live = (state == 1);
        bool fresh = live && (unchecked(Environment.TickCount - lastData) < 160);
        double dl = 0, dr = 0;
        bool onset = false;

        if (live)
        {
            if (fresh)
            {
                int dly = (int)(Rate * (SyncMs / 1000.0));
                if (dly < 0) dly = 0;
                if (dly > RING - N - 600) dly = RING - N - 600;
                lock (sync)
                {
                    int start = (wp - N - dly) & MASK;
                    for (int i = 0; i < N; i++)
                    {
                        int ix = (start + i) & MASK;
                        rawL[i] = ringL[ix]; rawR[i] = ringR[ix];
                        raw[i] = (rawL[i] + rawR[i]) * 0.5;
                    }
                    onset = DetectOnsets(total - dly);
                }
                double sl = 0, sr = 0; int vn = 1024;
                for (int i = N - vn; i < N; i++) { sl += rawL[i] * rawL[i]; sr += rawR[i] * rawR[i]; }
                dl = Math.Sqrt(sl / vn); dr = Math.Sqrt(sr / vn);
                Analyze(nb);
            }
            else
            {
                Array.Clear(raw, 0, N);
                Array.Clear(vbuf, 0, vbuf.Length);
                procPos = 0;
            }
        }
        else
        {
            onset = Simulate(dt, active, nb);
            if (onset) RegisterBeat(simT);
            if (active) { dl = 0.10 + 0.06 * Math.Sin(simT * 3.1); dr = 0.10 + 0.06 * Math.Sin(simT * 2.7 + 1.0); }
        }

        // ---- smoothing + peak hold ----
        double decay = Math.Exp(-dt * 7.0);
        for (int b = 0; b < nb; b++)
        {
            double x = vbuf[b];
            if (x >= bars[b]) bars[b] = bars[b] + (x - bars[b]) * 0.85;
            else bars[b] = Math.Max(x, bars[b] * decay);
            if (bars[b] >= peaks[b]) { peaks[b] = bars[b]; hold[b] = 0.45; }
            else if (hold[b] > 0) hold[b] -= dt;
            else peaks[b] = Math.Max(bars[b], peaks[b] - dt * 0.9);
        }

        // ---- beat / snare tracking ----
        double sum = 0; for (int b = 0; b < nb; b++) sum += bars[b];
        Energy = sum / nb;
        int nbass = Math.Max(2, nb / 6), m0 = nb / 3, m1 = (2 * nb) / 3;
        double fb = 0, fm = 0, bassNow = 0;
        for (int b = 0; b < nbass; b++) { fb += Math.Max(0.0, vbuf[b] - prevV[b]); bassNow += vbuf[b]; }
        for (int b = m0; b < m1; b++) fm += Math.Max(0.0, vbuf[b] - prevV[b]);
        Array.Copy(vbuf, prevV, nb);
        bassNow /= nbass;
        fluxAvg = fluxAvg * 0.92 + fb * 0.08;
        sFluxAvg = sFluxAvg * 0.92 + fm * 0.08;
        kCool -= dt; sCool -= dt; sinceKick += dt;
        Kick *= Math.Exp(-dt * 6.0);
        Snare *= Math.Exp(-dt * 8.0);
        Flash *= Math.Exp(-dt * 9.0);

        bool fluxBeat = (kCool <= 0) && (fb > fluxAvg * 1.7 + 0.10) && (bassNow > 0.22);
        if (fluxBeat && !onset && (sinceKick > 0.13)) { RegisterBeat(lastKickT + sinceKick); }
        bool manual = hitPending; hitPending = false;
        BeatNow = onset || manual || (fluxBeat && sinceKick > 0.13);
        if (BeatNow)
        {
            Kick = 1.0; Flash = 1.0; kCool = 0.13; sinceKick = 0;
            if (manual) BeatCount++;
            AddRipple();
        }
        if (sCool <= 0 && fm > sFluxAvg * 1.8 + 0.10) { Snare = 1.0; sCool = 0.12; }
        if (sinceKick > 3.0) { Bpm = 0; ivN = 0; }
        if (active) { double rate = ((Bpm > 0) ? Bpm : 120.0) / 60.0; BeatPhase += dt * rate; if (BeatPhase >= 1.0) BeatPhase -= 1.0; }
        for (int i = 0; i < 4; i++) rAge[i] += dt;

        // ---- scrolling waveform trace (one new column every 60 ms) ----
        waveAcc += dt;
        if (waveAcc >= 0.06)
        {
            waveAcc = (waveAcc > 0.18) ? 0 : waveAcc - 0.06;
            int span = Math.Min(N, Math.Max(64, (int)(Rate * 0.06)));
            double pk = 0;
            for (int i = N - span; i < N; i++) { double av = Math.Abs(raw[i]); if (av > pk) pk = av; }
            waveEnv = Math.Max(pk, waveEnv * 0.995);
            double wv = (pk < 0.002 || waveEnv < 0.003) ? 0.0 : Math.Pow(Math.Min(1.0, pk / waveEnv), 0.9);
            Array.Copy(wave, 1, wave, 0, nb - 1);
            wave[nb - 1] = wv;
        }

        ComputeBoost(nb);
        if (dyn != 0) DynStep(dt);
        UpdateGlow();

        // ---- VU meters ----
        double nl = VuNorm(dl), nr = VuNorm(dr);
        double vd = Math.Exp(-dt * 4.0);
        VuL = (nl >= VuL) ? nl : Math.Max(nl, VuL * vd);
        VuR = (nr >= VuR) ? nr : Math.Max(nr, VuR * vd);
        if (VuL >= PkL) { PkL = VuL; pkHoldL = 0.6; } else if (pkHoldL > 0) pkHoldL -= dt; else PkL = Math.Max(VuL, PkL - dt * 0.6);
        if (VuR >= PkR) { PkR = VuR; pkHoldR = 0.6; } else if (pkHoldR > 0) pkHoldR -= dt; else PkR = Math.Max(VuR, PkR - dt * 0.6);
    }

    // =====================================================================================
    //  Beat tracking
    // =====================================================================================
    // Streaming kick detector: a ~140 Hz low-pass feeds a peak-hold envelope. State persists across calls and every
    // sample is processed once in 5 ms blocks, so beats are timestamped in sample time (low latency, accurate BPM).
    static bool DetectOnsets(long target)
    {
        if (procPos == 0 || target < procPos || target - procPos > RING - 1024) procPos = target - 1024;
        double a = 1.0 - Math.Exp(-2.0 * Math.PI * 140.0 / Rate);
        double rel = Math.Exp(-1.0 / (0.030 * Rate));
        bool hit = false;
        while (procPos + 256 <= target)
        {
            for (int k = 0; k < 256; k++)
            {
                int ix = (int)((procPos + k) & MASK);
                double xs = (ringL[ix] + ringR[ix]) * 0.5;
                lpY += a * (xs - lpY);
                double mm = Math.Abs(lpY);
                envY = (mm > envY) ? mm : envY * rel;
            }
            procPos += 256;
            coolSamples -= 256;
            double e = envY;
            double prev = 0;
            for (int h = 0; h < 6; h++) if (eh[h] > prev) prev = eh[h];
            if (coolSamples <= 0 && e > Math.Max(1.8 * prev, 0.03))
            {
                coolSamples = (int)(0.13 * Rate);
                hit = true;
                procTime = procPos / (double)Rate;
                RegisterBeat(procTime);
            }
            for (int h = 0; h < 5; h++) eh[h] = eh[h + 1];
            eh[5] = e;
        }
        return hit;
    }

    static void RegisterBeat(double t)
    {
        double iv = t - lastKickT;
        lastKickT = t;
        if (iv > 0.28 && iv < 1.25) { ivals[ivN & 7] = iv; ivN++; }
        else if (iv >= 1.25) ivN = 0;
        int cnt = Math.Min(ivN, 8);
        if (cnt >= 4)
        {
            double[] tmp = new double[cnt];
            Array.Copy(ivals, tmp, cnt);
            Array.Sort(tmp);
            double bpm = 60.0 / tmp[cnt / 2];
            while (bpm < 75.0) bpm *= 2.0;
            while (bpm > 170.0) bpm /= 2.0;
            Bpm = (Bpm <= 0) ? bpm : Bpm * 0.7 + bpm * 0.3;
        }
        BeatCount++;
        BeatPhase = 0;
    }

    static void AddRipple()
    {
        for (int i = 0; i < 4; i++) if (rAge[i] > 1.6) { rAge[i] = 0; return; }
        rAge[0] = 0;
    }

    // per-bar brightness boost: the kick lights the low end, snares/hats the highs, ripples travel outward from the center
    static void ComputeBoost(int nb)
    {
        double mid = (nb - 1) / 2.0;
        for (int b = 0; b < nb; b++)
        {
            double lowW = 1.0 - Math.Min(1.0, b / (nb * 0.6));
            double hiW = Math.Max(0.0, (b - nb * 0.4) / (nb * 0.6));
            double v = 0;
            if (dyn == 2)
            {
                if (dstyle == 0) v = Flash * (0.15 + 0.35 * lowW) + Snare * 0.45 * hiW;
                else if (dstyle == 1) v = Flash * (0.40 + 0.35 * lowW) + Snare * 0.55 * hiW;
                else
                {
                    v = Flash * 0.12 + Snare * 0.25 * hiW;
                    for (int i = 0; i < 4; i++)
                    {
                        double age = rAge[i];
                        if (age > 1.6) continue;
                        double rad = age * nb * 1.5;
                        double w = 1.0 - Math.Abs(Math.Abs(b - mid) - rad) / 4.5;
                        if (w > 0) v += w * Math.Exp(-age * 2.0) * 0.9;
                    }
                }
            }
            else if (FxOn) v = Flash * 0.30 * (0.5 + 0.5 * lowW) + Snare * 0.18 * hiW;
            boost[b] = Math.Min(1.0, v);
        }
    }

    // smooth pulsing border color: dim accent -> bright accent as the beat flashes
    static void UpdateGlow()
    {
        double gl = FxOn ? Math.Min(1.0, Flash + Kick * 0.15) : 0.0;
        int d0r = (int)(accR * 0.42), d0g = (int)(accG * 0.42), d0b = (int)(accB * 0.42);
        int h0r = (int)(accR + (255 - accR) * 0.60), h0g = (int)(accG + (255 - accG) * 0.60), h0b = (int)(accB + (255 - accB) * 0.60);
        Glow = FgCode(d0r + (int)((h0r - d0r) * gl), d0g + (int)((h0g - d0g) * gl), d0b + (int)((h0b - d0b) * gl));
    }

    // mode: 0 spectrum, 1 mirror, 2 LED.
    public static string[] Render(int mode, int cols, int rows)
    {
        if (rows < 1) rows = 1;
        if (cols < 8) cols = 8;
        if (bars.Length < 4) Alloc(Math.Max(4, cols / 2));
        switch (mode)
        {
            case 0: return RenderBars(cols, rows, false);
            case 1: return RenderMirror(cols, rows, bars, false);
            default: return RenderBars(cols, rows, true);
        }
    }

    // =====================================================================================
    //  Capture (WASAPI loopback of the default output device)
    // =====================================================================================
    static void CaptureMain()
    {
        while (run)
        {
            try { Session(); }
            catch (Exception ex) { Error = ex.Message; state = -1; }
            if (!run) break;
            for (int i = 0; i < 40 && run; i++) Thread.Sleep(50);   // retry every ~2 s
        }
    }

    static void Chk(int hr, string what)
    {
        if (hr < 0) throw new Exception(what + " failed (0x" + hr.ToString("X8") + ")");
    }

    static void Session()
    {
        IBBDeviceEnumerator en = (IBBDeviceEnumerator)(new BBMMDeviceEnumerator());
        IBBDevice dev;
        Chk(en.GetDefaultAudioEndpoint(0, 0, out dev), "default output device");
        Guid iidAc = new Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2");
        object o;
        Chk(dev.Activate(ref iidAc, 23, IntPtr.Zero, out o), "activate audio client");
        IBBAudioClient ac = (IBBAudioClient)o;

        IntPtr pf;
        Chk(ac.GetMixFormat(out pf), "get mix format");
        int tag = Marshal.ReadInt16(pf, 0) & 0xFFFF;
        int ch = Marshal.ReadInt16(pf, 2);
        int rate = Marshal.ReadInt32(pf, 4);
        int bits = Marshal.ReadInt16(pf, 14);
        bool isFloat = (tag == 3);
        if (tag == 0xFFFE) isFloat = (Marshal.ReadInt32(pf, 24) == 3);
        int hr = ac.Initialize(0, 0x00020000, 10000000L, 0L, pf, IntPtr.Zero);   // shared mode + LOOPBACK
        Marshal.FreeCoTaskMem(pf);
        Chk(hr, "initialize loopback");

        Guid iidCap = new Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317");
        object o2;
        Chk(ac.GetService(ref iidCap, out o2), "get capture service");
        IBBCaptureClient cap = (IBBCaptureClient)o2;
        Chk(ac.Start(), "start capture");

        Rate = rate;
        lastData = Environment.TickCount;
        Error = "";
        state = 1;

        int bytesPer = bits / 8;
        if (ch < 1) ch = 1;
        byte[] buf = new byte[65536];
        while (run)
        {
            uint pkt;
            Chk(cap.GetNextPacketSize(out pkt), "packet size");
            while (pkt > 0 && run)
            {
                IntPtr data; uint frames; uint flags; ulong dp; ulong qp;
                Chk(cap.GetBuffer(out data, out frames, out flags, out dp, out qp), "get buffer");
                int nbytes = (int)frames * ch * bytesPer;
                if (nbytes > buf.Length) buf = new byte[nbytes];
                bool silent = (flags & 2) != 0;
                if (!silent && nbytes > 0) Marshal.Copy(data, buf, 0, nbytes);
                Feed(buf, (int)frames, ch, bytesPer, isFloat, silent);
                cap.ReleaseBuffer(frames);
                Chk(cap.GetNextPacketSize(out pkt), "packet size");
            }
            Thread.Sleep(6);
        }
        ac.Stop();
    }

    static void Feed(byte[] buf, int frames, int ch, int bytesPer, bool isFloat, bool silent)
    {
        double sl = 0, sr = 0;
        lock (sync)
        {
            for (int i = 0; i < frames; i++)
            {
                float l = 0f, r = 0f;
                if (!silent)
                {
                    int off = i * ch * bytesPer;
                    l = Sample(buf, off, bytesPer, isFloat);
                    r = (ch > 1) ? Sample(buf, off + bytesPer, bytesPer, isFloat) : l;
                }
                ringL[wp] = l; ringR[wp] = r;
                wp = (wp + 1) & MASK;
                total++;
                sl += l * l; sr += r * r;
            }
        }
        lastData = Environment.TickCount;
    }

    static float Sample(byte[] b, int o, int bytes, bool isFloat)
    {
        if (isFloat) return BitConverter.ToSingle(b, o);
        if (bytes == 2) return ((short)(b[o] | (b[o + 1] << 8))) / 32768f;
        if (bytes == 3) { int v = (b[o] << 8) | (b[o + 1] << 16) | (b[o + 2] << 24); return (v >> 8) / 8388608f; }
        if (bytes == 4) return BitConverter.ToInt32(b, o) / 2147483648f;
        return 0f;
    }

    // =====================================================================================
    //  Analysis
    // =====================================================================================
    static void Alloc(int nb)
    {
        bars = new double[nb]; peaks = new double[nb]; hold = new double[nb];
        vbuf = new double[nb]; dbv = new double[nb];
        boost = new double[nb]; prevV = new double[nb]; wave = new double[nb];
    }

    static double VuNorm(double rms)
    {
        if (rms < 1e-5) return 0;
        double n = (20.0 * Math.Log10(rms) + 48.0) / 48.0;
        if (n < 0) return 0;
        if (n > 1) return 1;
        return n;
    }

    static void Fft(double[] a, double[] b)
    {
        int n = a.Length;
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j)
            {
                double t = a[i]; a[i] = a[j]; a[j] = t;
                t = b[i]; b[i] = b[j]; b[j] = t;
            }
        }
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = -2.0 * Math.PI / len;
            double wr = Math.Cos(ang), wi = Math.Sin(ang);
            int half = len >> 1;
            for (int i = 0; i < n; i += len)
            {
                double cr = 1.0, ci = 0.0;
                for (int k = 0; k < half; k++)
                {
                    int p = i + k, q = i + k + half;
                    double tr = a[q] * cr - b[q] * ci;
                    double ti = a[q] * ci + b[q] * cr;
                    a[q] = a[p] - tr; b[q] = b[p] - ti;
                    a[p] += tr; b[p] += ti;
                    double ncr = cr * wr - ci * wi;
                    ci = cr * wi + ci * wr;
                    cr = ncr;
                }
            }
        }
    }

    static void Analyze(int nb)
    {
        double ss = 0;
        for (int i = 0; i < N; i++) { double s = raw[i]; ss += s * s; re[i] = s * win[i]; im[i] = 0; }
        double rms = Math.Sqrt(ss / N);
        if (rms < 1e-4) { Array.Clear(vbuf, 0, nb); return; }      // below about -80 dBFS: treat as silence

        Fft(re, im);
        double scale = 4.0 / N;                                     // full-scale sine -> about 0 dB
        int half = N / 2;
        for (int k = 0; k <= half; k++) mag[k] = Math.Sqrt(re[k] * re[k] + im[k] * im[k]) * scale;

        double binHz = Rate / (double)N;
        double fmin = 40.0;
        double fmax = Math.Min(16000.0, Rate * 0.45);
        double ratio = fmax / fmin;
        double frameMax = -200.0;
        for (int b = 0; b < nb; b++)
        {
            double f0 = fmin * Math.Pow(ratio, b / (double)nb);
            double f1 = fmin * Math.Pow(ratio, (b + 1) / (double)nb);
            double k0 = f0 / binHz, k1 = f1 / binHz, m;
            if (k1 - k0 < 1.0)
            {
                double kc = (k0 + k1) * 0.5;
                int ki = (int)kc;
                if (ki > half - 1) ki = half - 1;
                double fr = kc - ki;
                m = mag[ki] * (1.0 - fr) + mag[ki + 1] * fr;
            }
            else
            {
                int a = (int)Math.Ceiling(k0), z = (int)Math.Floor(k1);
                if (z < a) z = a;
                if (z > half) z = half;
                double mx = 0;
                for (int k = a; k <= z; k++) if (mag[k] > mx) mx = mag[k];
                m = mx;
            }
            double db = 20.0 * Math.Log10(m + 1e-7);
            db += 2.0 * Math.Log(Math.Sqrt(f0 * f1) / 1000.0, 2.0);   // +2 dB/oct tilt so highs stay visible
            dbv[b] = db;
            if (db > frameMax) frameMax = db;
        }

        // automatic gain: the ceiling follows the loudest band and relaxes slowly
        ceilDb = Math.Max(frameMax, ceilDb - 0.25);
        if (ceilDb < -60.0) ceilDb = -60.0;
        double range = 44.0;
        double floorDb = Math.Max(ceilDb - range, -85.0);
        double span = Math.Max(20.0, ceilDb - floorDb);
        for (int b = 0; b < nb; b++)
        {
            double v = (dbv[b] + GainDb - floorDb) / span;
            if (v < 0) v = 0;
            if (v > 1) v = 1;
            vbuf[b] = Math.Pow(v, 1.35);
        }
        // light 3-tap smoothing across neighbouring bands: softer, less jagged shapes
        for (int b = 0; b < nb; b++)
        {
            double pv = vbuf[(b > 0) ? b - 1 : b];
            double nx = vbuf[(b < nb - 1) ? b + 1 : b];
            dbv[b] = 0.2 * pv + 0.6 * vbuf[b] + 0.2 * nx;
        }
        for (int b = 0; b < nb; b++) vbuf[b] = Math.Max(dbv[b], vbuf[b] * 0.9);
    }

    // used only when loopback capture is not available
    static bool Simulate(double dt, bool active, int nb)
    {
        if (!active) { Array.Clear(vbuf, 0, nb); Array.Clear(raw, 0, N); return false; }
        prevSimT = simT;
        simT += dt;
        double beat = Math.Pow(Math.Abs(Math.Sin(simT * Math.PI * 2.05)), 8.0);
        for (int b = 0; b < nb; b++)
        {
            double f = b / (double)(nb - 1);
            double x = 0.30 * (1 + Math.Sin(simT * (2.1 + f * 9) + b * 1.7)) / 2
                     + 0.22 * (1 + Math.Sin(simT * (0.9 + f * 4) + b * 0.6)) / 2
                     + 0.55 * beat * Math.Pow(1 - f, 1.6);
            vbuf[b] = Math.Min(1.0, x * (1 - 0.5 * f) * 1.25);
        }
        for (int i = 0; i < N; i++)
            raw[i] = 0.35 * Math.Sin(simT * 6 + i * 0.045) * (0.6 + 0.4 * Math.Sin(i * 0.004 + simT))
                   + 0.15 * Math.Sin(i * 0.31 + simT * 11) * beat;
        return Math.Floor(simT * 2.05) != Math.Floor(prevSimT * 2.05);
    }

    // =====================================================================================
    //  Palette
    // =====================================================================================
    static void Lerp(int[] s, double t, out int r, out int g, out int b)
    {
        int n = s.Length / 3;
        if (t < 0) t = 0;
        if (t > 1) t = 1;
        double p = t * (n - 1);
        int i = (int)p;
        if (i > n - 2) i = n - 2;
        double f = p - i;
        r = (int)(s[i * 3] + (s[(i + 1) * 3] - s[i * 3]) * f + 0.5);
        g = (int)(s[i * 3 + 1] + (s[(i + 1) * 3 + 1] - s[i * 3 + 1]) * f + 0.5);
        b = (int)(s[i * 3 + 2] + (s[(i + 1) * 3 + 2] - s[i * 3 + 2]) * f + 0.5);
    }

    static void BuildPalette()
    {
        for (int i = 0; i < PN; i++)
        {
            double t = i / (double)(PN - 1);
            int r, g, b;
            Lerp(stops, t, out r, out g, out b);
            fg[i] = ESC + "[38;2;" + r + ";" + g + ";" + b + "m";
        }
    }

    static int PalIdx(double t)
    {
        int i = (int)(t * (PN - 1) + 0.5);
        if (i < 0) i = 0;
        if (i > PN - 1) i = PN - 1;
        return i;
    }

    // =====================================================================================
    //  Colors (row gradient normally; per-bar rainbow / ripples / flashes in disco mode)
    // =====================================================================================
    static string FgCode(int r, int g, int b)
    {
        if (r < 0) r = 0; if (r > 255) r = 255;
        if (g < 0) g = 0; if (g > 255) g = 255;
        if (b < 0) b = 0; if (b > 255) b = 255;
        return ESC + "[38;2;" + r + ";" + g + ";" + b + "m";
    }

    static void Hsv(double h, double sat, double val, out int r, out int g, out int b)
    {
        h = h % 360.0; if (h < 0) h += 360.0;
        if (sat < 0) sat = 0; if (sat > 1) sat = 1;
        if (val < 0) val = 0; if (val > 1) val = 1;
        double c = val * sat;
        double x = c * (1.0 - Math.Abs((h / 60.0) % 2.0 - 1.0));
        double m = val - c;
        double r1 = 0, g1 = 0, b1 = 0;
        if (h < 60) { r1 = c; g1 = x; }
        else if (h < 120) { r1 = x; g1 = c; }
        else if (h < 180) { g1 = c; b1 = x; }
        else if (h < 240) { g1 = x; b1 = c; }
        else if (h < 300) { r1 = x; b1 = c; }
        else { r1 = c; b1 = x; }
        r = (int)((r1 + m) * 255.0 + 0.5);
        g = (int)((g1 + m) * 255.0 + 0.5);
        b = (int)((b1 + m) * 255.0 + 0.5);
    }

    // color for bar b at relative height t (0 = bottom, 1 = top)
    static string Col(int b, double t)
    {
        if (b < 0) b = 0;
        if (b >= boost.Length) b = boost.Length - 1;
        double bo = boost[b];
        if (dyn == 2 && dstyle == 0)
        {
            int r, g, bl;
            Hsv(hue + b * (300.0 / Math.Max(1, boost.Length)), 1.0 - 0.5 * t * t, 0.40 + 0.60 * t, out r, out g, out bl);
            if (bo > 0.02) { r += (int)((255 - r) * bo); g += (int)((255 - g) * bo); bl += (int)((255 - bl) * bo); }
            return FgCode(r, g, bl);
        }
        if (bo < 0.03) return fg[PalIdx(t)];
        int r2, g2, b2;
        Lerp(stops, t, out r2, out g2, out b2);
        r2 += (int)((255 - r2) * bo); g2 += (int)((255 - g2) * bo); b2 += (int)((255 - b2) * bo);
        return FgCode(r2, g2, b2);
    }

    static void Put(StringBuilder sb, string c, ref string last)
    {
        if (!vt) return;
        if (c != last) { sb.Append(c); last = c; }
    }

    static void EndRow(StringBuilder sb)
    {
        if (vt) sb.Append(ESC).Append("[0m");
    }

    // =====================================================================================
    //  Renderers
    // =====================================================================================
    // Thin bars (1 column + 1 gap). led = segmented LED look. Soft reflection underneath. No caps, no particles.
    static string[] RenderBars(int cols, int rows, bool led)
    {
        int nb = bars.Length;
        int used = nb * 2;
        int left = (cols - used) / 2;
        if (left < 0) left = 0;
        int right = cols - left - used;
        if (right < 0) right = 0;
        int rr = (rows >= 10) ? Math.Max(2, rows / 5) : 0;     // reflection rows
        int mr = rows - rr;                                     // rows holding the bars
        int top = mr * 8;
        int[] eig = new int[nb];
        for (int b = 0; b < nb; b++)
        {
            eig[b] = (int)(bars[b] * top + 0.5); if (eig[b] > top) eig[b] = top;
        }
        string[] o = new string[rows];
        for (int r = 0; r < rows; r++)
        {
            StringBuilder sb = new StringBuilder(cols * 3);
            string last = null;
            sb.Append(' ', left);
            if (r < mr)
            {
                int lvl = mr - 1 - r;
                double t = (mr > 1) ? lvl / (double)(mr - 1) : 0.0;
                for (int b = 0; b < nb; b++)
                {
                    int f = eig[b] - lvl * 8;
                    if (f > 8) f = 8;
                    if (f > 0)
                    {
                        Put(sb, Col(b, t), ref last);
                        sb.Append((led && f >= 8) ? blk[7] : blk[f]);
                    }
                    else sb.Append(' ');
                    sb.Append(' ');
                }
            }
            else
            {
                int d = r - mr;                                 // 0 = just under the baseline
                double tr = Math.Max(0.02, 0.14 - d * 0.04);
                for (int b = 0; b < nb; b++)
                {
                    double ra = bars[b] * mr * 8.0 * 0.30;      // reflection is short and faint
                    if (ra > d * 8 + 3) { Put(sb, Col(b, tr), ref last); sb.Append(cUp); } else sb.Append(' ');
                    sb.Append(' ');
                }
            }
            EndRow(sb);
            sb.Append(' ', right);
            o[r] = sb.ToString();
        }
        return o;
    }

    // Symmetric bars around a center line.  vals = spectrum (mirror) or the scrolling waveform history (trace).
    static string[] RenderMirror(int cols, int rows, double[] vals, bool trace)
    {
        int nb = vals.Length;
        int used = nb * 2;
        int left = (cols - used) / 2;
        if (left < 0) left = 0;
        int right = cols - left - used;
        if (right < 0) right = 0;
        int hr = rows / 2;
        string[] o = new string[rows];
        for (int r = 0; r < rows; r++)
        {
            bool isTop = r < hr;
            bool isMid = (rows % 2 == 1) && (r == hr);
            int d = isMid ? 0 : (isTop ? (hr - 1 - r) : (r - (rows - hr)));
            double hf = (hr > 1) ? d / (double)(hr - 1) : 0.0;
            StringBuilder sb = new StringBuilder(cols * 3);
            string last = null;
            sb.Append(' ', left);
            for (int b = 0; b < nb; b++)
            {
                double v = vals[b];
                if (trace && v < 0.06) v = 0.06;                 // keep a flat "recorder" line when quiet
                char c = ' ';
                if (isMid) { if (v > 0.03) c = cFull; }
                else
                {
                    double amt = v * hr * 2.0 - d * 2.0;
                    if (amt >= 1.5) c = cFull;
                    else if (amt >= 0.5) c = isTop ? cLow : cUp;
                }
                if (c != ' ')
                {
                    bool newest = trace && (b >= nb - 2);        // freshest columns glow
                    Put(sb, Col(b, newest ? Math.Min(1.0, hf + 0.35) : hf), ref last);
                }
                sb.Append(c).Append(' ');
            }
            EndRow(sb);
            sb.Append(' ', right);
            o[r] = sb.ToString();
        }
        return o;
    }

    // =====================================================================================
    //  RGB / disco palettes
    // =====================================================================================
    static void DynStep(double dt)
    {
        if (dyn == 1) { hue += dt * 40.0; hueTarget = hue; }
        else
        {
            double jump = (dstyle == 0) ? 32.0 : ((dstyle == 1) ? 62.0 : 26.0);
            if (BeatNow) hueTarget += jump;
            hueTarget += dt * 14.0;
            hue += (hueTarget - hue) * Math.Min(1.0, dt * 14.0);       // snappy follow
        }
        double spread = (dyn == 1) ? 55.0 : 70.0;
        int r1, g1, b1, r2, g2, b2, r3, g3, b3;
        Hsv(hue, 1.0, 0.45, out r1, out g1, out b1);
        Hsv(hue + spread, 1.0, 1.0, out r2, out g2, out b2);
        Hsv(hue + spread * 2.0, 0.45, 1.0, out r3, out g3, out b3);
        stops = new int[] { r1, g1, b1, r2, g2, b2, r3, g3, b3 };
        BuildPalette();
        accR = r2; accG = g2; accB = b2;
        AccA = FgCode(r2, g2, b2);
        AccD = FgCode((int)(r2 * 0.42), (int)(g2 * 0.42), (int)(b2 * 0.42));
        AccH = FgCode((int)(255 - (255 - r2) * 0.35), (int)(255 - (255 - g2) * 0.35), (int)(255 - (255 - b2) * 0.35));
    }

    // Border line of n characters. In disco mode a bright comet runs along it once per beat.
    // Returns null outside disco mode (the caller then draws a plain line).
    public static string Rule(int n, string ch)
    {
        if (dyn != 2 || !vt || n < 2) return null;
        StringBuilder sb = new StringBuilder(n * 24);
        string last = null;
        double comet = BeatPhase * n;
        for (int i = 0; i < n; i++)
        {
            double d = Math.Abs(i - comet);
            if (n - d < d) d = n - d;
            double glow = Math.Max(0.0, 1.0 - d / 10.0);
            double fl = Math.Min(1.0, Flash * 0.35 + glow);
            int r, g, b;
            if (dstyle == 0) Hsv(hue + i * 4.0, 1.0 - 0.65 * fl, 0.38 + 0.62 * fl, out r, out g, out b);
            else
            {
                r = (int)(accR * (0.40 + 0.60 * fl) + (255 - accR) * fl * 0.6);
                g = (int)(accG * (0.40 + 0.60 * fl) + (255 - accG) * fl * 0.6);
                b = (int)(accB * (0.40 + 0.60 * fl) + (255 - accB) * fl * 0.6);
            }
            string c = FgCode(r, g, b);
            if (c != last) { sb.Append(c); last = c; }
            sb.Append(ch);
        }
        sb.Append(ESC).Append("[0m");
        return sb.ToString();
    }

    // =====================================================================================
    //  Particles (embers mode): sparks leave the bar tops on every beat and drift up
    // =====================================================================================
    static void Spawn(double x, double y, double vx, double vy, double life)
    {
        for (int i = 0; i < NP; i++)
        {
            if (pl[i] <= 0)
            {
                px[i] = x; py[i] = y; pvx[i] = vx; pvy[i] = vy; pl[i] = life; pl0[i] = life;
                return;
            }
        }
    }

    static void StepParticles(double dt, int nb)
    {
        if (BeatNow)
        {
            int count = 8 + (int)(Energy * 26.0);
            for (int k = 0; k < count; k++)
            {
                int b = rnd.Next(nb);
                for (int t = 0; t < 6; t++) { int c = rnd.Next(nb); if (rnd.NextDouble() < bars[c]) { b = c; break; } }
                Spawn((b + rnd.NextDouble()) / nb, Math.Max(0.05, bars[b]), (rnd.NextDouble() - 0.5) * 0.14, 0.5 + rnd.NextDouble() * 1.3, 0.9 + rnd.NextDouble() * 1.0);
            }
        }
        if (Snare > 0.9)
        {
            for (int k = 0; k < 4; k++)
            {
                int b = nb / 2 + rnd.Next(Math.Max(1, nb / 2));
                Spawn((b + 0.5) / nb, Math.Max(0.05, bars[b]), (rnd.NextDouble() - 0.5) * 0.10, 0.3 + rnd.NextDouble() * 0.7, 0.5 + rnd.NextDouble() * 0.5);
            }
        }
        for (int b = 0; b < nb; b++)
        {
            if (bars[b] > 0.45 && rnd.NextDouble() < dt * bars[b] * 2.2)
                Spawn((b + 0.5) / nb, bars[b], (rnd.NextDouble() - 0.5) * 0.05, 0.15 + rnd.NextDouble() * 0.4, 0.6 + rnd.NextDouble() * 0.5);
        }
        for (int i = 0; i < NP; i++)
        {
            if (pl[i] <= 0) continue;
            pl[i] -= dt;
            py[i] += pvy[i] * dt;
            px[i] += pvx[i] * dt;
            pvy[i] -= 0.9 * dt;
            if (py[i] < 0 || px[i] < 0 || px[i] > 1) pl[i] = 0;
        }
    }
}
'@

try {
    Init-Console
    [Console]::Write('  BLACKBOX starting ...')
    Init-Native; Load-Settings; Load-Favs; Load-Plays; Load-Hist
    Run-Boot; Main-Menu
} catch {
    $Where = ''; try { $Where = $_.InvocationInfo.PositionMessage } catch {}
    try { ('{0}  {1}{2}{3}' -f (Get-Date), $_.Exception.Message, [Environment]::NewLine, $Where) | Add-Content -LiteralPath (Join-Path $script:DataRoot 'error.log') } catch {}
    try { [Console]::CursorVisible = $true } catch {}
    Clear-Host; Write-Host ''; Write-Host ('  FATAL: ' + $_.Exception.Message) -ForegroundColor Red; Write-Host ('  ' + ($Where -replace '\s+', ' ')) -ForegroundColor DarkGray; Write-Host '  (also saved to Data\error.log)' -ForegroundColor DarkGray; Write-Host ''
    Write-Host '  Run-Music.bat starts Windows PowerShell 5.1 in STA mode (Windows 10/11).' -ForegroundColor Yellow; Read-Host '  Press ENTER' | Out-Null; exit 1
} finally {
    try { Save-Session; Save-Settings; Save-Plays; if ($script:EngineOK) { [BBEngine]::Stop() }; if ($script:Player) { $script:Player.Stop(); $script:Player.Close() }; if ($script:Next) { $script:Next.Stop(); $script:Next.Close() } } catch {}
    [Console]::ResetColor()
}
