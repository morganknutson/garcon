<div style="margin-bottom: 40px;">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/garcon-darkmode.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/garcon-lightmode.png">
    <img src="assets/garcon-lightmode.png" alt="Garçon logo" width="350">
  </picture>
</div>

<br />

A lightweight macOS menu bar app that shows local web servers, their ports, and quick actions to open or stop them. Garçon!

<br />


[![Download for macOS](https://img.shields.io/badge/Download%20for%20macOS-black?style=for-the-badge&logo=apple)](https://github.com/OWNER/REPO/releases/latest/download/garcon.zip)


<br />


## What It Does

- Finds local TCP listeners and probes only HTTP/HTTPS servers.
- Prioritizes developer servers and groups system daemons under a `System` section.
- Shows page title (when available), server type badge, and URL.
- Opens server URLs when you click a row.
- Lets you stop a server with a hover-revealed trash action.
- Caches the last server list so the panel appears immediately.

<img src="assets/garcon-what-it-does.png" alt="Garçon menu bar panel screenshot" width="400">

## Requirements

- macOS `13+` (Ventura or newer).

## Install

### From GitHub Releases (Recommended)

Use the stable latest-download link:

- [Download latest Garçon (`garcon.zip`)](https://github.com/morganknutson/garcon/releases/latest/download/garcon.zip)

1. Download `garcon.zip`.
2. Unzip and move `Garcon.app` to `/Applications`.
3. Launch `Garcon.app`.

## Usage

- Click the menu bar icon to open the panel.
- Click a server row to open it in your browser.
- Hover a row and click the trash icon to stop that process.
- Click the refresh icon in the header to rescan.
