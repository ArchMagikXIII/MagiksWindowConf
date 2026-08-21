# MagikXIII Desktop Setup

One-click Windows installer for a complete tiling WM desktop environment.

## What's Included

| Component | Description |
|-----------|-------------|
| **GlazeWM** | Tiling window manager with custom keybindings |
| **Zebar** | Status bar (Odyssey Bar) with wallpaper-adaptive colors |
| **Alacritty** | GPU-accelerated terminal with BlexMono Nerd Font |
| **Brave** | Privacy-focused browser |
| **oh-my-posh** | Prompt theme (night-owl) |
| **fastfetch** | System info with custom ASCII art |
| **PowerShell** | Profile with zoxide, PSFzf, Terminal-Icons |

## Quick Start

1. Copy this folder to your new Windows machine
2. Right-click `install.ps1` → **Run with PowerShell** (as Admin)
3. Log out and back in for PATH changes
4. GlazeWM auto-starts on login

## Key Bindings

| Binding | Action |
|---------|--------|
| `Alt+Enter` | Alacritty terminal |
| `Alt+B` | Brave browser |
| `Alt+1-9` | Switch workspace |
| `Alt+H/L` | Focus left/right |
| `Alt+Shift+H/L` | Move window left/right |
| `Alt+R` | Resize mode |
| `Alt+Shift+E` | Exit GlazeWM |

## Wallpapers

The installer includes wallpapers and automatically extracts dominant colors from your current wallpaper to theme the status bar. Change your wallpaper and restart GlazeWM (`Alt+Shift+R`) to update colors.

## Requirements

- Windows 10/11
- Administrator access for installation

## Manual Steps

- **Zebar**: Download from [zebar releases](https://github.com/glzr-io/zebar/releases) if not installed
- **Zoxide**: Install via `winget install ajeetdsouza.zoxide` or `choco install zoxide`
