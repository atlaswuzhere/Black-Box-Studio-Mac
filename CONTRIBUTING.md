# Contributing to BLACKBOX

Thanks for your interest in improving BLACKBOX. Contributions are welcome as proposals, but all changes are reviewed before they enter the official project.

## Before starting

- For a bug, search existing issues first and describe the exact steps to reproduce it.
- For a large feature or architecture change, open an issue before doing substantial work.
- Keep changes focused. Avoid unrelated visual or behavioural changes.
- Do not add online music streaming, analytics, tracking, telemetry, or external services without first discussing the privacy and product impact with the maintainer.

## Safe contribution workflow

1. Fork the repository to your own GitHub account.
2. Create a branch for your change (for example, `fix/queue-reorder`).
3. Make and test your change locally.
4. Commit and push to your fork.
5. Open a pull request against the original repository and explain what changed, why, and how you tested it.

Do not request direct write access. Maintainers will review pull requests and decide whether to merge them.

## Do not include

- Music files, personal playlists, `.m3u8` exports, lyrics, custom artwork, or app backup archives.
- Files from the `Data/`, `MUSIC/`, or generated cache folders.
- API keys, tokens, passwords, private keys, `.env` files, or personal machine paths.
- Screenshots or logs that reveal private file names, usernames, or listening history.

## Testing expectations

State clearly which edition you tested: browser, console, or both. Include Windows version and browser version where relevant. Test the feature you changed and check that unrelated playback, library, queue, playlist, and persistence behaviour still works. Do not claim tests you did not run.

## Pull request checklist

- [ ] The change is focused and explained.
- [ ] No personal data, music, secrets, or machine-specific paths are included.
- [ ] I tested the affected feature and described the test.
- [ ] I considered keyboard access and reduced-motion behaviour where relevant.
- [ ] I did not add an external dependency or network request without explaining why.
