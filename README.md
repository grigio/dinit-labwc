# Artix dinit labwc noctalia minimal config

A systemd-free minimalist Linux desktop setup using **dinit** init, **labwc** compositor, and **Noctalia v5** (native C++) desktop environment on **Artix Linux**.

![Screenshot](artix-dinit-labwc-noctalia.png)

## Overview

This configuration provides a lightweight Wayland desktop environment without systemd, using:

- **Init**: dinit (with turnstile for user sessions)
- **Display Manager**: ly (TUI-based)
- **Compositor**: labwc (Openbox-compatible)
- **Desktop Shell**: Noctalia v5 (native C++ binary)
- **Audio**: PipeWire + WirePlumber
- **Session**: elogind + turnstile

NB: `/home/user` is hardcoded — replace with your user path.

## Quick Start

### Installation

1. Install required packages:
   ```bash
   sudo pacman -S dinit turnstile elogind labwc wlroots pipewire pipewire-pulse wireplumber xdg-desktop-portal-wlr xdg-desktop-portal-gtk grim slurp wlsunset bluez bluez-utils gnome-keyring
   ```

2. Install dinit service scripts (system services):
   ```bash
   sudo pacman -S pipewire-dinit wireplumber-dinit
   ```

3. Install Noctalia (from AUR):
   ```bash
   # V5 native binary (recommended)
   yay -S noctalia-git
   # Or Quickshell version (legacy)
   # yay -S noctalia-qs
   ```

4. Copy configuration files:
   - Copy `.config/` to `~/.config/` (backup existing labwc config first)
   - Copy `ly/` to `/etc/ly` (or use `ly/setup.sh`)

5. Configure PAM for turnstile:
   Ensure `/etc/pam.d/ly` and `/etc/pam.d/ly-autologin` contain:
   ```
   session optional pam_turnstile.so
   ```

6. Free a console for ly (if needed):
   Edit `/etc/dinit.c/config/console.conf`:
   ```
   ACTIVE_CONSOLES="/dev/tty[2-6]"
   ```

7. Reboot and select "labwc" session in ly

## Architecture

### Service Management

User services are managed by dinit via turnstile. The dependency chain is:

```
dbus → gnome-keyring, pipewire → wireplumber + pipewire-pulse
dbus + wayland-ready → voxtype
wayland-ready → noctalia → wlr-randr
```

Check service status:
```bash
dinitctl list                    # System services
dinitctl --user list             # User services
dinitctl catlog <service>        # View logs
```

### Environment Variables

User dinit services do NOT inherit the full user environment. Use `env-file` in service definitions.

**User dinit environment** (`~/.config/dinit.d/environment`):
```bash
HOME=/home/user
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_DESKTOP=labwc
XDG_RUNTIME_DIR=/run/user/1000
XDG_DATA_DIRS=/home/user/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share
WAYLAND_DISPLAY=wayland-0
QT_QPA_PLATFORM=wayland
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
GNOME_KEYRING_CONTROL=/run/user/1000/keyring
XCURSOR_THEME=Adwaita
```

**Session environment** (`~/.config/labwc/environment`):
```bash
XDG_CONFIG_HOME=/home/user/.config
QT_QPA_PLATFORMTHEME=qt6ct
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=32
XKB_DEFAULT_LAYOUT=en
XKB_DEFAULT_OPTIONS=compose:caps
```

## Configuration Files

| Path | Purpose |
|------|---------|
| `~/.config/dinit.d/` | User service definitions |
| `~/.config/labwc/rc.xml` | labwc keybinds and config |
| `~/.config/labwc/environment` | Session environment variables |
| `~/.config/noctalia/config.toml` | Noctalia v5 main config |
| `~/.local/state/noctalia/settings.toml` | Noctalia v5 settings/app-managed overrides |
| `/etc/pam.d/ly`, `/etc/pam.d/ly-autologin` | PAM config for turnstile |
| `/etc/turnstile/turnstiled.conf` | Turnstile session management |

## Features

### Noctalia IPC

Noctalia v5 provides a Unix socket IPC at `$XDG_RUNTIME_DIR/noctalia-$WAYLAND_DISPLAY.sock`. Usage: `noctalia msg <command> [args]`

**Volume**:
```bash
noctalia msg volume-up [step]
noctalia msg volume-down [step]
noctalia msg volume-mute
noctalia msg mic-mute
```

**Session & Power**:
```bash
noctalia msg session lock
noctalia msg session suspend
noctalia msg session lock-and-suspend
noctalia msg session logout
noctalia msg session reboot
noctalia msg session shutdown
```

**Panels**:
```bash
noctalia msg panel-toggle launcher
noctalia msg panel-toggle session
noctalia msg panel-toggle control-center
noctalia msg panel-toggle clipboard
```

**Wallpaper**:
```bash
noctalia msg wallpaper-set <path>
noctalia msg wallpaper-random [connector]
noctalia msg wallpaper-get [connector]
```

**Other**:
```bash
noctalia msg nightlight-toggle
noctalia msg caffeine-toggle
noctalia msg theme-mode-toggle
noctalia msg screenshot-region
noctalia msg screenshot-fullscreen [pick|monitor|all]
noctalia msg media <next|previous|toggle|stop>
noctalia msg dpms-on / dpms-off
noctalia msg config-reload
noctalia msg status
```

### Audio Control

- Services: pipewire → wireplumber (depends-on), pipewire-pulse
- Control: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`
- OSD: Noctalia v5 has built-in OSD via `noctalia msg volume-up/down/mute/mic-mute`
- Keybinds configured in `~/.config/labwc/rc.xml`

### Screenshots

```bash
grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
```

Noctalia v5 has built-in screenshot commands:
```bash
noctalia msg screenshot-region
noctalia msg screenshot-fullscreen
```

### Night Light

Noctalia v5 has built-in night light (gamma control):
```bash
noctalia msg nightlight-toggle
```
Configured via settings GUI or `~/.local/state/noctalia/settings.toml` under `[nightlight]`. If using Noctalia's night light, don't run `wlsunset` (they conflict).

### Wallpaper

**Config file** (`~/.config/noctalia/config.toml`):
```toml
[wallpaper]
directory = "/home/user/Pictures/Wallpapers"
```

**Via IPC**:
```bash
noctalia msg wallpaper-set /home/user/Pictures/Wallpapers/image.jpg
noctalia msg wallpaper-random
```

**Restart Noctalia after config changes**:
```bash
dinitctl --user stop wlr-randr && dinitctl --user stop noctalia && dinitctl --user start noctalia && dinitctl --user start wlr-randr
```

### Bluetooth

```bash
sudo dinitctl start bluetoothd           # Start service
sudo dinitctl status bluetoothd         # Check status
bluetoothctl                            # Pair devices (from bluez-utils)
```

### Power Management

Power button lock+suspend is handled via labwc keybind in `rc.xml`:
- Keybind `XF86PowerOff` → `/home/user/.local/bin/lock-suspend`
- Script mutes audio then runs: `noctalia msg session lock-and-suspend`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Wayland socket not created | Set `WLR_RENDERER=pixman` in `~/.config/labwc/environment` |
| Socket missing | `pgrep turnstiled`, check `/run/user/1000/` |
| Missing boot dir | `sudo mkdir -p /usr/lib/dinit.d/user/boot.d` |
| Service restarting quickly | `dinitctl catlog <service>` |
| Orphaned process | Kill manually, then `dinitctl --user start <service>` |
| polkit failing | Unload: `dinitctl --user unload polkit` (runs via D-Bus activation) |
| "failed to connect to display" | Check `dinitctl --user status wayland-ready` |
| Noctalia IPC not working | Verify socket: `ls $XDG_RUNTIME_DIR/noctalia-*` |
| Flatpak "dbus-launch" error | Add `DBUS_SESSION_BUS_ADDRESS` to `~/.config/dinit.d/environment` |
| Terminal opens to wrong directory | Add `HOME=/home/user` to `~/.config/dinit.d/environment` |

## Autostart Locations

Use `~/.config/dinit.d/` for user services (NOT `~/.config/labwc/autostart` or `~/.config/autostart/`).

## Useful Commands

```bash
loginctl suspend                    # Suspend system
xdg-user-dirs-update               # Update user directories
dinitctl --user reload <service>   # Reload user service
```

## Notes

- **Do NOT** `kill -HUP` user dinit — it loses track of processes
- Use `log-type = buffer` in user services to enable `dinitctl catlog` for debugging
- Labwc is started by ly (display manager), not by dinit
- Noctalia v5 comes from AUR as `noctalia-git` (native C++ binary); `noctalia-qs` is the legacy Quickshell version

## References

- [AGENTS.md](AGENTS.md) — Detailed configuration reference for LLM agents
- [AGENTS.md](.config/AGENTS.md) — Configuration guide within repo
- [Artix Linux](https://artixlinux.org/)
- [dinit](https://github.com/davidstrauss/dinit)
- [labwc](https://labwc.github.io/)
- [Noctalia](https://github.com/noctalia-dev/noctalia)
