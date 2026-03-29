# Agent Configuration

## Quick Reference
- **Distro**: Artix Linux | **Init**: dinit | **DM**: ly
- **Compositor**: labwc | **Desktop Shell**: Noctalia (Quickshell)
- **Audio**: PipeWire + WirePlumber | **Session**: elogind + turnstile

## Packages (Installed)
| Category | Packages |
|----------|----------|
| Init/Session | dinit, turnstile, elogind |
| Compositor | labwc, wlroots |
| Audio | pipewire, wireplumber, pipewire-pulse |
| Portals | xdg-desktop-portal-wlr, xdg-desktop-portal-gtk |
| Screenshots | grim, slurp |
| Utilities | wlsunset |
| Desktop Shell | quickshell, noctalia |
| D-Bus | dbus |
| Bluetooth | bluez, bluez-utils, bluez-dinit |

## Key Configurations
| Path | Purpose |
|------|---------|
| `~/.config/dinit.d/` | User services |
| `~/.config/labwc/rc.xml` | labwc config, keybinds |
| `~/.config/labwc/environment` | Session environment variables |
| `~/.config/noctalia/settings.json` | Noctalia wallpapers |
| `/etc/pam.d/ly`, `/etc/pam.d/ly-autologin` | PAM for turnstile |
| `/etc/elogind/logind.conf.d/` | Power button, lid switch, sleep settings |
| `/etc/elogind/logind.conf` | Power button, lid, sleep settings |

## Environment Variables
- **Session vars** (XDG, cursor, keyboard, etc.): `~/.config/labwc/environment`
- **User dinit services**: `~/.config/dinit.d/environment` (use `env-file` parameter)

### User Dinit Environment (Critical for Wayland/X11 apps)

User services started by dinit (via turnstile) do NOT inherit the full user environment. Use `env-file` to pass variables:

```
~/.config/dinit.d/environment:
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
XDG_RUNTIME_DIR=/run/user/1000
XDG_DATA_DIRS=/home/user/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share
XDG_CONFIG_HOME=/home/user/.config
WAYLAND_DISPLAY=wayland-0
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt6ct
DISPLAY=:0
```

Then reference it in the service file:
```
type = process
command = /bin/sh -c "while [ ! -S /run/user/1000/wayland-0 ]; do sleep 0.1; done; exec /usr/sbin/qs -c noctalia-shell"
env-file = /home/user/.config/dinit.d/environment
log-type = buffer
```

Example `~/.config/labwc/environment`:
```
XDG_CONFIG_HOME=/home/user/.config
QT_QPA_PLATFORMTHEME=qt6ct
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=32
XKB_DEFAULT_LAYOUT=en
XKB_DEFAULT_OPTIONS=compose:caps
```

## Service Management
- Use `dinitctl` (system) or `dinitctl --user` (user services)
- User services: `~/.config/dinit.d/`, socket: `/run/user/1000/dinitctl`
- Service types: `process` (foreground), `scripted`, `bgprocess` (PID file)
- **DO NOT** `kill -HUP` user dinit — it loses track of processes
- Enable `log-type = buffer` in all services to allow `dinitctl catlog` for debugging

## User Dinit Services
Labwc is started by `ly` (display manager), not by dinit.

Service dependency order: `dbus` → `quickshell` → `wlr-randr`

Current services:
- `quickshell` — desktop shell (waits for Wayland socket, uses `env-file` for environment)
- `wlr-randr` — display configuration (depends on quickshell)
- `dbus`, `pipewire`, `wireplumber`, `pipewire-pulse` — system services

### Service Configuration Notes
- Use absolute paths for binaries (`/usr/sbin/qs`, `/usr/sbin/wlr-randr`)
- Services depending on quickshell don't need to wait for Wayland socket explicitly
- Use `env-file` to pass environment variables to user services (NOT inline in command)
- Use `type = process` for scripted commands that need shell features
- Use double quotes for shell commands: `command = /bin/sh -c "..."`

## Turnstile + PAM (Critical)
```
/etc/pam.d/ly:
  session optional pam_turnstile.so
  session optional pam_elogind.so

/etc/pam.d/ly-autologin:
  session optional pam_turnstile.so
  session optional pam_elogind.so
```
Without `pam_turnstile.so`, user dinit won't start at boot.

## Audio
- Services: pipewire → wireplumber (depends-on), pipewire-pulse
- Control: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`
- OSD: Noctalia has built-in OSD (enabled in settings). Use quickshell IPC to trigger OSD:
  - Volume up: `qs -c noctalia-shell ipc --any-display call volume increase`
  - Volume down: `qs -c noctalia-shell ipc --any-display call volume decrease`
  - Mute: `qs -c noctalia-shell ipc --any-display call volume muteOutput`
  - Mic mute: `qs -c noctalia-shell ipc --any-display call volume muteInput`
- Keybinds are in `~/.config/labwc/rc.xml`
- Note: IPC commands require `--any-display` flag to find running quickshell instance

## Screenshot
```bash
grim -g "$(slurp)" ~/Pictures/screenshot-$(Y%m%d-%H%M%S).png
```

## Night Light
```bash
wlsunset -S 07:30 -s 18:30 -t 3500 -T 6500 &
```

## Troubleshooting
| Error | Fix |
|-------|-----|
| Socket missing | `pgrep turnstiled`, check `/run/turnstiled/1000/` |
| Missing boot dir | `sudo mkdir -p /usr/lib/dinit.d/user/boot.d` |
| Service restarting quickly | `dinitctl catlog <service>` |
| Orphaned process | Kill manually, then `dinitctl --user start <service>` |
| Bluetooth pairing | Install `bluez-utils` for `bluetoothctl`, start service with `dinitctl start bluetoothd` |
| polkit failing | Unload bad service: `dinitctl --user unload polkit`; polkit runs via D-Bus activation (no dinit service needed) |
| quickshell/display "failed to connect to display" | Services wait for Wayland socket; check `ls -la /run/user/1000/wayland-*` and `pgrep labwc` |
| Super+Space / IPC not working | Use `--any-display` flag: `qs -c noctalia-shell ipc --any-display call launcher toggle` |

## Useful Commands
```bash
loginctl suspend
xdg-user-dirs-update
dinitctl --user reload <service>
```

## Noctalia Wallpaper
Edit `~/.config/noctalia/settings.json`:
```json
"enableMultiMonitorDirectories": true,
"monitorDirectories": [
  {"directory": "/home/user/Pictures/Wallpapers", "name": "eDP-1", "wallpaper": "/home/user/Pictures/Wallpapers/image.jpg"}
]
```
Restart: `pkill -f "qs -c"; qs -c noctalia-shell &`

## Autostart Locations
1. `~/.config/dinit.d/` — daemons (dbus, pipewire, etc.)
2. `~/.config/labwc/autostart` — compositor-specific
3. `~/.config/autostart/` — XDG (keep disabled unless needed)

## Bluetooth
- Service: `sudo dinitctl start bluetoothd` (system) or `dinitctl --user start bluetoothd`
- Status: `sudo dinitctl status bluetoothd`
- Pairing: Install `bluez-utils` for `bluetoothctl`, or use `blueman` (GUI)
- Config: `/etc/bluetooth/main.conf`

## Zram (Compressed RAM Swap)
- Service: `sudo dinitctl start zramen` (system) — runs as swap
- Status: `zramctl`
- Devices: `/sys/block/zram*`

## Polkit
- polkitd runs via D-Bus activation (no dinit service needed)
- Binary: `/usr/lib/polkit-1/polkitd`
- D-BUS service file: `/usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service`
- If a bad polkit dinit service exists, unload it: `dinitctl --user unload polkit`

## Power Button (elogind)
To make the power button trigger suspend instead of shutdown:
```bash
echo '[Login]
HandlePowerKey=suspend' | sudo tee /etc/elogind/logind.conf.d/power-button.conf
```
Restart elogind (stop logind first due to dependency):
```bash
sudo dinitctl stop logind
sudo dinitctl stop elogind
sudo dinitctl start elogind
sudo dinitctl start logind
```
Other options: `poweroff`, `reboot`, `ignore`
