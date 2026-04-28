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
| Utilities | wlsunset, swayidle |
| Desktop Shell | quickshell, noctalia |
| D-Bus | dbus |
| Bluetooth | bluez, bluez-utils, bluez-dinit |
| Keyring | gnome-keyring |

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

**User-defined env vars for dinit services**: `~/.config/dinit.d/environment` (use `env-file` parameter)
**Session vars** (XDG, cursor, keyboard, etc.): `~/.config/labwc/environment`

### User Dinit Environment (Critical for Wayland/X11 apps)

User services started by dinit (via turnstile) do NOT inherit the full user environment. Use `env-file` parameter to pass variables.

All user-defined environment variables should ONLY be defined in `~/.config/dinit.d/environment`.

**Critical**: `DBUS_SESSION_BUS_ADDRESS` is required for Flatpak apps to access D-Bus portals.
**Important**: Always set `HOME=/home/user` in dinit environment to ensure terminals start at home directory.

The `wayland-ready` service waits for the Wayland socket using `inotifywait` (with polling fallback).

`~/.config/dinit.d/environment` and `~/.config/labwc/environment` must be kept in sync.

## Service Management
- Use `dinitctl` (system) or `dinitctl --user` (user services)
- User services: `~/.config/dinit.d/`, socket: `/run/user/1000/dinitctl`
- Service types: `process` (foreground), `scripted`, `bgprocess` (PID file)
- **DO NOT** `kill -HUP` user dinit — it loses track of processes
- Enable `log-type = buffer` in all services to allow `dinitctl catlog` for debugging

## User Dinit Services
Labwc is started by `ly` (display manager), not by dinit.

Service dependency order:
```
dbus → gnome-keyring, pipewire → wireplumber + pipewire-pulse
dbus + wayland-ready → voxtype
wayland-ready → quickshell → swayidle, wlr-randr
```

Current services:
- `wayland-ready` — waits for Wayland socket using `inotifywait` with polling fallback (one-shot)
- `quickshell` — desktop shell (waits-for wayland-ready, smooth-recovery, restart=on-failure)
- `swayidle` — idle management (waits-for wayland-ready, smooth-recovery, wrapper script)
- `wlr-randr` — display configuration (waits-for wayland-ready, one-shot)
- `gnome-keyring` — password storage (depends-on dbus)
- `voxtype` — typing daemon (depends-on dbus, waits-for wayland-ready)
- `dbus`, `pipewire`, `wireplumber`, `pipewire-pulse` — system services

### Service Configuration Notes
- Use absolute paths for binaries
- Use `env-file` to pass environment variables to user services (NOT inline in command)
- Use `type = process` for long-running services, `type = scripted` for one-shot commands
- Use `waits-for` (not `depends-on`) for one-shot dependencies like wayland-ready
- Use `smooth-recovery = true` for services that should restart without stopping dependents
- Use `restart = on-failure` instead of `restart = true` to avoid restart loops on clean exits
- Dinit has no native file/socket watching; `wayland-ready` uses `inotifywait` with polling fallback
- Enable services at boot by symlinking to `~/.config/dinit.d/boot.d/`

### Waiting for Wayland Socket
Labwc is started by ly (display manager), not by dinit. Services that need the Wayland socket use `wayland-ready` service:

```sh
#!/bin/sh
# ~/.config/dinit.d/wayland-ready.sh
# Handles: inotifywait missing (polling fallback), file created but not a socket, race conditions
[ -S "$XDG_RUNTIME_DIR/wayland-0" ] && exit 0
[ -d "$XDG_RUNTIME_DIR" ] || exit 1
if ! command -v inotifywait >/dev/null 2>&1; then
  echo "WARNING: inotifywait not found, falling back to polling" >&2
  for i in $(seq 1 60); do
    [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && exit 0
    sleep 1
  done
  exit 1
fi
while true; do
  inotifywait -q -t 60 -e CREATE "$XDG_RUNTIME_DIR" || exit 1
  [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && exit 0
done
```

Services use `waits-for = wayland-ready` to wait for socket creation. Avoid `depends-on` for one-shot services (use `waits-for`).

## Turnstile + PAM (Critical)
Add `pam_turnstile.so` and `pam_elogind.so` to PAM session in `/etc/pam.d/ly` and `/etc/pam.d/ly-autologin`. Without it, user dinit won't start at boot.

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

## Idle Management (swayidle)
Lock screen after 5min, lock+suspend after 10min via quickshell IPC. See `~/.config/dinit.d/swayidle`.

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
| quickshell/display "failed to connect to display" | Quickshell depends on wayland-ready; check `dinitctl --user status wayland-ready` |
| wlr-randr / swayidle "failed to connect to display" | These services waits-for wayland-ready; check `dinitctl --user status wayland-ready` |
| Super+Space / IPC not working | Use `--any-display` flag: `qs -c noctalia-shell ipc --any-display call launcher toggle` |
| Flatpak "Settings portal not found" / "dbus-launch" error | Add `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` to `~/.config/dinit.d/environment` |
| Nautilus not remembering network passwords | Ensure gnome-keyring dinit service is running: `dinitctl --user start gnome-keyring` |
| Terminal opens to wrong directory (e.g., ~/.config/dinit.d) | Add `HOME=/home/user` to `~/.config/dinit.d/environment`, then restart user services |

## Useful Commands
```bash
loginctl suspend
xdg-user-dirs-update
dinitctl --user reload <service>
```

## Chromium/Brave (Flatpak on Wayland)
Set `--ozone-platform=wayland` in the desktop file so launching via menu/app launcher uses Wayland:

1. Copy the system desktop file to local: `cp /var/lib/flatpak/exports/share/applications/<app>.desktop ~/.local/share/applications/`
2. Edit `~/.local/share/applications/<app>.desktop`, adding `--ozone-platform=wayland` to all `Exec=` lines
3. Run `update-desktop-database ~/.local/share/applications/`
4. Set as default: `xdg-settings set default-web-browser <app>.desktop`

For Brave: `<app>` = `com.brave.Browser.desktop`
For Chromium: `<app>` = `org.chromium.Chromium.desktop`

## Noctalia Wallpaper
Edit `~/.config/noctalia/settings.json`, then restart: `pkill -f "qs -c"; qs -c noctalia-shell &`

## Autostart Locations
Use `~/.config/dinit.d/` for user services (NOT `~/.config/labwc/autostart` or `~/.config/autostart/`).

## Bluetooth
- Service: `sudo dinitctl start bluetoothd` (system) or `dinitctl --user start bluetoothd`
- Status: `sudo dinitctl status bluetoothd`
- Pairing: Install `bluez-utils` for `bluetoothctl`, or use `blueman` (GUI)
- Config: `/etc/bluetooth/main.conf`

## Zram (Compressed RAM Swap)
- Service: `sudo dinitctl start zramen` (system) — runs as swap
- Status: `zramctl`
- Devices: `/sys/block/zram*`

## Time Sync
- Use **chrony** instead of ntpd — it's faster, more accurate, and handles intermittent connections better.

## Polkit
- polkitd runs via D-Bus activation (no dinit service needed)
- Binary: `/usr/lib/polkit-1/polkitd`
- D-BUS service file: `/usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service`
- If a bad polkit dinit service exists, unload it: `dinitctl --user unload polkit`

## Power Button
Elogind is set to `HandlePowerKey=ignore` to prevent automatic suspend. Lock+suspend is handled via labwc keybind in `rc.xml`:
- Keybind `XF86PowerOff` → `/home/user/.local/bin/lock-suspend`
- Script uses quickshell IPC: `qs -c noctalia-shell ipc --any-display call sessionMenu lockAndSuspend`
- Also mutes audio before suspending

## Logout (Labwc)
Logout is handled via `~/.config/quickshell/noctalia-shell/Services/Compositor/LabwcService.qml`. Due to ly + turnstiled session management, loginctl doesn't properly terminate sessions. The logout function directly kills labwc: `Quickshell.execDetached(["pkill", "-9", "labwc"])`.

### Restart quickshell (required after config changes)
```bash
dinitctl --user stop swayidle wlr-randr && dinitctl --user stop quickshell && dinitctl --user start quickshell && dinitctl --user start wlr-randr swayidle
```

## ly DM Performance Tuning
The `ly` display manager can be slow due to PAM overhead and redundant service spawning in `~/.bash_profile`.

### PAM Configuration
**`/etc/pam.d/ly-autologin`** — Minimal config (no auth checks, no gnome-keyring):
```
#%PAM-1.0
auth       required     pam_permit.so
account    required     pam_permit.so
password   required     pam_permit.so
session    required     pam_unix.so
session    optional     pam_turnstile.so
session    optional     pam_elogind.so
```

**`/etc/pam.d/ly`** — Manual login (no gnome-keyring, it's already a dinit service):
```
#%PAM-1.0
auth       requisite    pam_nologin.so
auth       requisite    pam_unix.so
account    required     pam_unix.so
session    required     pam_unix.so
password   required     pam_unix.so
session    optional     pam_turnstile.so
session    optional     pam_elogind.so
```

**Key rules**:
- `session required pam_unix.so` is REQUIRED in `ly-autologin` — without it, turnstile can't set up the session and user dinit won't start (`/run/user/1000/dinitctl` missing)
- `pam_turnstile.so` and `pam_elogind.so` must be `optional`, NOT `required` — if they fail for any reason, `required` causes PAM to reject the session and ly loops endlessly
- `pam_turnstile.so` must come before `pam_elogind.so` in session order
- Remove `pam_gnome_keyring.so` from both files — gnome-keyring is managed by dinit, not PAM
- `ly-autologin` should use `pam_permit.so` for auth/account/password (no `system-auth` include which pulls in `pam_faillock`)

### ~/.bash_profile Cleanup
Remove redundant service spawning — dbus and audio are managed by dinit:
```bash
# ~/.bash_profile — keep it minimal
[[ -f ~/.bashrc ]] && . ~/.bashrc
```

**Remove these lines** (they add delay on every login):
- `export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` — set by dinit `env-file`
- Manual `dbus-daemon --session --fork` — dbus is a dinit service
- `pkill -9 pulseaudio` — irrelevant with PipeWire via dinit

### Troubleshooting Slow ly
- Check `/var/log/ly.log` for repeated `attempting autologin` loops
- If autologin keeps retrying, verify `ly-autologin` PAM uses `pam_permit.so` (not `include login`)
- Profile sourcing (`/etc/profile` + `/etc/profile.d/*.sh`) is unavoidable but should be fast
