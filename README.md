# Garçon!

Garçon! is a lightweight macOS menu bar app that shows local web servers, their ports, and quick actions to open or stop them.

## What It Does

- Finds local TCP listeners and probes only HTTP/HTTPS servers.
- Prioritizes developer servers and groups system daemons under a `System` section.
- Shows page title (when available), server type badge, and URL.
- Opens server URLs when you click a row.
- Lets you stop a server with a hover-revealed trash action.
- Caches the last server list so the panel appears immediately.

## Requirements

- macOS `13+` (Ventura or newer).
- Xcode Command Line Tools:
```bash
xcode-select --install
```
- Runtime tools already available on macOS:
  - `/usr/sbin/lsof`
  - `/usr/bin/curl`
  - `/bin/ps`

## Install

### From GitHub Releases (Recommended)

1. Open the repo's **Releases** page.
2. Download `Garcon.app.zip`.
3. Unzip and move `Garcon.app` to `/Applications`.
4. Launch `Garcon.app`.

### From Source

```bash
git clone https://github.com/morganknutson/garson.git
cd garson
swift run Garcon
```

## Usage

- Click the menu bar icon to open the panel.
- Click a server row to open it in your browser.
- Hover a row and click the trash icon to stop that process.
- Click the refresh icon in the header to rescan.

## Build Release Artifacts

Creates:

- `dist/Garcon.app.zip`
- `dist/Garcon-macos-<arch>.tar.gz`
- `dist/SHA256SUMS.txt`

```bash
./scripts/package-release.sh 0.1.0
```

## Publish a GitHub Release

Requires authenticated GitHub CLI (`gh auth status` should succeed).

```bash
./scripts/create-release.sh v0.1.0
```

This script:

- builds release artifacts
- creates/pushes the git tag if needed
- creates (or updates) the GitHub Release
- uploads assets to the release
