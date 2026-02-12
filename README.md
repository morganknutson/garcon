<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/garcon-darkmode.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/garcon-lightmode.png">
  <img src="assets/garcon-lightmode.png" alt="Garçon logo" style="width: 300px">
</picture>

<br />

A lightweight macOS menu bar app that shows local web servers, their ports, and quick actions to open or stop them. Garçon!

## What It Does

- Finds local TCP listeners and probes only HTTP/HTTPS servers.
- Prioritizes developer servers and groups system daemons under a `System` section.
- Shows page title (when available), server type badge, and URL.
- Opens server URLs when you click a row.
- Lets you stop a server with a hover-revealed trash action.
- Caches the last server list so the panel appears immediately.

## Requirements

- macOS `13+` (Ventura or newer).

## Install

### From GitHub Releases (Recommended)

1. Open the repo's **Releases** page.
2. Download `Garcon.app.zip`.
3. Unzip and move `Garcon.app` to `/Applications`.
4. Launch `Garcon.app`.

## Usage

- Click the menu bar icon to open the panel.
- Click a server row to open it in your browser.
- Hover a row and click the trash icon to stop that process.
- Click the refresh icon in the header to rescan.
