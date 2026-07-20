# wewbo
An interactive terminal application for searching and watching anime from various streaming sources. [Install Here](#install)

> [!IMPORTANT]
> Original project by upi-0 is currently read-only. This is a fork. As of now, only downloading is expected to work.
> If the original upstream resumes development, this fork may be retired in its favor.

<p align="center">
  <img width="75%" src="https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/asset/tuiPreview.png">
</p>

## About

Wewbo is a command-line-based application that allows you to search for anime, select episodes, and watch them instantly using your favorite media player (MPV or FFplay). The application supports multiple anime sources with an easy-to-use interface.

## Sources Status
| Name | Web | Status | Issue |
|---------|-----------|----| -- |
| Mori | https://miruro.tv | ✅ | - |
| Alme | https://allanime.day | ? | - |
| Taku | https://otakudesu.best | ? | - |

## How to Use

### Downloading
```bash
wewbo ani-dl [anime title]
```

### Streaming (may not work)

```bash
wewbo [anime title]
wewbo stream [anime title]
```

### Usage Examples

```bash
# Search and watch anime from animepahe (default)
wewbo "slow loop"

# Search for anime from otakudesu
wewbo "slow loop:taku"

# Search for anime using FFplay as player
wewbo "attack on titan" -p:ffplay

# Search for anime from otakudesu using external MPV as player
wewbo "demon slayer:taku" --mpv:/path/to/mpv
```

## Install
Make sure [ffmpeg](https://www.ffmpeg.org) is available in your `$PATH`. [Learn how](https://www.google.com/search?q=adding+app+to+path)
Due to unfortunate spread of Cloudflare, [curl-impersonate](https://github.com/lexiforest/curl-impersonate) is now the extra dependency.

### Linux

<b>Curl</b>
```bash
curl -fsSL "https://upi.web.id/wewbo.sh" | bash
```

<b>AUR</b>
```bash
yay -S wewbo
```
```bash
paru -S wewbo
```

### macOS

<b>PPCPorts</b>
```bash
sudo port install curl-impersonate nim-wewbo
```

### Nim
<b>Git Clone</b>
```bash
git clone https://github.com/upi-0/wewbo; cd wewbo
nimble build -y
```
<b>Install directly</b>
```bash
nimble install wewbo
```

---

## For Developers

### Technologies Used

- **q**: parsing HTML using CSS selector
- **htmlparser**: parsing HTML
- **illwill**: TUI design
- **malebolgia**: multiprocessing

## Bantu Service Laptop

https://saweria.co/upi0
