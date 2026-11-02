# BLACKBOX Player

A local-first music player for your own audio files. This repository contains the **application source code** for the browser player and the original Windows/PowerShell console edition. It does not contain the BLACKBOX Studio marketing website.

## What is included

- Browser player: HTML, CSS and JavaScript (`app/BLACKBOX-PERSONAL-AUDIO/index.html`, `style.css`, `app.js`).
- Compact mini-player (`mini.html`, `mini.js`).
- Windows launcher and local web server scripts (`Run-Music.bat`, `Start-BlackBox-Web.ps1`).
- Original PowerShell/console edition (`BlackBox-Audio.ps1`, `Run-Music-Console.bat`).
- Default configuration and setup/usage guides.

## Run on Windows

1. Download or clone this repository, then extract it if needed.
2. Open `app/BLACKBOX-PERSONAL-AUDIO/`.
3. Double-click `Run-Music.bat` to start the browser edition. Keep its launcher window open while using BLACKBOX.
4. In the browser, choose **CONNECT MUSIC FOLDER** and select a folder containing audio files.
5. To use the original console edition instead, run `Run-Music-Console.bat`.

Windows 10/11 is the intended desktop environment. The browser edition is primarily intended for current Chrome or Edge on desktop. Browser codec and folder-permission support can vary. See `README-WEB.txt` and the in-app BLACKBOX Guide for more detail.

## Your music and personal data

BLACKBOX does not include music files. Keep your music, playlists, lyrics, artwork, and personal app data out of public commits. The `.gitignore` in this repository excludes the contents of the app's `MUSIC/`, `Data/`, and `Playlists/` folders while retaining their explanatory README files. Never upload your personal `Data/` folder or an Everything ZIP backup to a public repository.

## Network behaviour

BLACKBOX is a local music player and does not provide online music streaming. The current app source includes an optional lyrics lookup against LRCLIB when the user explicitly requests lyrics. Cached lyrics may then be used offline. Review the current source and the LRCLIB service terms/privacy information before changing this behaviour.

The in-app Getting Music guide includes instructions and links for third-party tools. Users are responsible for downloading or copying only audio they are legally authorised to use.

## Development notes

The current browser edition uses plain HTML, CSS and JavaScript and the Windows editions use PowerShell and batch launchers. There is no Node/npm build step in the supplied project. Keep the app's relative folder layout intact: the launchers expect the application files to remain together.

Before submitting changes, test the browser edition and the console edition separately on Windows. Also test folder selection, playback, queue operations, playlists, persistence/export-import, lyrics, and the feature you changed.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Please discuss large changes in an issue first. Contributions are reviewed; a pull request is a proposal, not automatic permission to change the official release.

## Security

Read [SECURITY.md](SECURITY.md). Never commit passwords, API keys, tokens, private music, personal playlists, backups, or logs containing personal file paths.

## License

BLACKBOX Player is licensed under the **GNU General Public License v3.0 only (GPL-3.0-only)**. See [`LICENSE`](LICENSE) for the complete license text. Contributions submitted to this repository are offered under the same license, unless a contribution explicitly states otherwise and the maintainer accepts that arrangement.

The GPL license applies to the project code covered by this repository. It does not grant rights to third-party trademarks, music, album artwork, lyrics, external services, or other material that is not owned by the project. BLACKBOX and BLACKBOX Studio are project names; this repository does not grant trademark permission.

## Contact

BLACKBOX Studio: blackboxstudiofr@proton.me
