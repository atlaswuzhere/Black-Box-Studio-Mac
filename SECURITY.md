# Security Policy

## Reporting a vulnerability

Please do **not** publish exploitable security details in a public issue. Send a private report to **blackboxstudiofr@proton.me** with:

- A concise description of the issue and its impact.
- The affected file/feature and the version or commit, if known.
- Reproduction steps or a proof of concept that does not access another person's data.
- Any suggested mitigation.

Please avoid sending music files, personal playlists, full backups, credentials, or logs containing private paths. The maintainer will acknowledge reports when able and coordinate a fix before public disclosure. Do not assume a report is fixed until a release or commit explicitly says so.

## Scope notes

BLACKBOX is designed to work with files and folders that the user explicitly selects. Treat imported media metadata, lyrics, playlist files, and filenames as untrusted input. Do not add code that executes content from a music folder or downloads/runs remote scripts.
