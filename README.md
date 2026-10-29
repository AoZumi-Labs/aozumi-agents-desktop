# Hachi for Mac

Releases of Hachi, AOZUMI's agents app (first released as AOZUMI Agents). Coding agents run on your Mac, or in the cloud on [AOZUMI](https://aozumi.dev).

**Install from Terminal** (checks the download, installs into Applications, and opens it):

```sh
curl -fsSL https://raw.githubusercontent.com/AoZumi-Labs/aozumi-agents-desktop/main/install.sh | sh
```

Or **[download the latest release →](https://github.com/AoZumi-Labs/aozumi-agents-desktop/releases/latest)** (the `.dmg`).

- Needs an Apple Silicon Mac (M1 or later) on macOS 13 or newer.
- Installed apps update themselves from these releases. Settings → Updates shows when one is ready.
- If you installed it as AOZUMI Agents, updates keep that app's name in Applications. Running the installer again swaps it for Hachi.app; your data stays.
- Test builds aren't notarized by Apple yet, so the first open needs **Open Anyway** in System Settings → Privacy & Security.

This repository holds releases only; the app's source is private. Hachi is licensed under the Apache License 2.0 (see `LICENSE` and `NOTICE`). It bundles git, licensed under the GNU GPL v2; each release attaches git's source as `git-source.tar.gz`.
