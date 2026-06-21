# Agent Configuration

## Quick Reference
- **Distro**: Artix Linux | **Init**: dinit | **DM**: ly
- **Compositor**: labwc | **Desktop Shell**: Noctalia v5 (native C++ binary)
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
| Desktop Shell | noctalia-git (v5 native binary), noctalia-qs (Quickshell library) |
| D-Bus | dbus |
| Bluetooth | bluez, bluez-utils, bluez-dinit |
| Keyring | gnome-keyring |

## Key Configurations
| Path | Purpose |
|------|---------|
| `~/.config/dinit.d/` | User services |
| `~/.config/labwc/rc.xml` | labwc config, keybinds |
| `~/.config/labwc/environment` | Session environment variables |
| `~/.config/noctalia/config.toml` | Noctalia v5 main config (user edits) |
| `~/.local/state/noctalia/settings.toml` | Noctalia v5 settings/app-managed overrides |
| `/etc/pam.d/ly`, `/etc/pam.d/ly-autologin` | PAM for turnstile |
| `/etc/dinit.d/elogind`, `/etc/dinit.d/turnstiled` | System seat management services |

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
wayland-ready → noctalia → wlr-randr
```

Current services:
- `wayland-ready` — waits for Wayland socket using `inotifywait` with polling fallback (one-shot)
- `noctalia` — desktop shell (/usr/bin/noctalia, waits-for wayland-ready, smooth-recovery, restart=on-failure)
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

### User Dinit Not Starting
If user dinit doesn't start (`dinitctl --user list` fails), manually start it:
```sh
# Create boot service if missing
echo -e "type = process\ncommand = sleep infinity" > ~/.config/dinit.d/boot

# Create placeholder for system dbus
echo -e "type = scripted\ncommand = true\nlog-type = buffer" > ~/.config/dinit.d/dbus

# Start user dinit
nohup dinit -u -d ~/.config/dinit.d -p /run/user/1000/dinitctl > /tmp/dinit.log 2>&1 &
sleep 2

# Start services
dinitctl --user start dbus wayland-ready noctalia gnome-keyring voxtype wlr-randr
```

### Waiting for Wayland Socket
Labwc is started by ly (display manager), not by dinit. Services that need the Wayland socket use `wayland-ready` service:

```sh
#!/bin/sh
# ~/.config/dinit.d/wayland-ready.sh
# Handles: inotifywait missing (polling fallback), file created but not yet a socket, race conditions
[ -S "$XDG_RUNTIME_DIR/wayland-0" ] && exit 0
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || exit 1
fi
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
Add `pam_turnstile.so` to PAM session in `/etc/pam.d/ly` and `/etc/pam.d/ly-autologin`. Without it, user dinit won't start at boot.

### Turnstile Configuration
In `/etc/turnstile/turnstiled.conf`, set `manage_rundir = yes` to create `/run/user/1000` at login. Without this, user dinit fails with "unable to open wayland socket: Invalid argument". Restart turnstiled after changing:
```bash
sudo dinitctl restart turnstiled
```

## Seat Group (Required for elogind)
elogind socket is owned by `root:seat`. Add your user to the seat group:
```bash
sudo gpasswd -a user seat
```
Log out and back in for group membership to take effect.

## Audio
- Services: pipewire → wireplumber (depends-on), pipewire-pulse
- Control: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`
- OSD: Noctalia v5 has built-in OSD. Use `noctalia msg` IPC:
  - Volume up: `noctalia msg volume-up [step]`
  - Volume down: `noctalia msg volume-down [step]`
  - Toggle mute: `noctalia msg volume-mute`
  - Mic mute: `noctalia msg mic-mute`
- Keybinds are in `~/.config/labwc/rc.xml`

## Noctalia IPC Reference
Noctalia v5 uses Unix socket IPC at `$XDG_RUNTIME_DIR/noctalia-$WAYLAND_DISPLAY.sock`. Usage: `noctalia msg <command> [args]`

### Volume
| Command | Description |
|---------|-------------|
| `volume-up [step]` | Increase volume (default 5%) |
| `volume-down [step]` | Decrease volume |
| `volume-mute` | Toggle speaker mute |
| `volume-set <value>` | Set volume (percent or normalized) |
| `mic-mute` | Toggle microphone mute |
| `mic-volume-up [step]` | Increase mic volume |
| `mic-volume-down [step]` | Decrease mic volume |
| `mic-volume-set <value>` | Set mic volume |

### Session & Power
| Command | Description |
|---------|-------------|
| `session lock` | Lock screen |
| `session suspend` | Suspend |
| `session lock-and-suspend` | Lock then suspend |
| `session logout` | Log out |
| `session reboot` | Reboot |
| `session shutdown` | Shutdown |

### Panels
| Command | Description |
|---------|-------------|
| `panel-toggle launcher` | Toggle app launcher |
| `panel-toggle session` | Toggle session menu |
| `panel-toggle control-center` | Toggle control center |
| `panel-toggle clipboard` | Toggle clipboard |
| `panel-open <id>` | Open a panel |
| `panel-close [id]` | Close active or named panel |
| `settings-open` / `settings-close` / `settings-toggle` | Settings window |

### Wallpaper
| Command | Description |
|---------|-------------|
| `wallpaper-random [connector]` | Random wallpaper |
| `wallpaper-get [connector]` | Print current wallpaper path |
| `wallpaper-set [connector] <path>` | Set wallpaper (persisted) |

### Other
| Command | Description |
|---------|-------------|
| `brightness-up [target] [step]` | Increase brightness |
| `brightness-down [target] [step]` | Decrease brightness |
| `nightlight-toggle` | Toggle night light |
| `nightlight-force-toggle` | Toggle forced night light |
| `caffeine-toggle` | Toggle idle inhibitor |
| `theme-mode-toggle` | Toggle dark/light mode |
| `screenshot-region` | Interactive region screenshot |
| `screenshot-fullscreen [pick\|monitor\|all]` | Fullscreen screenshot |
| `media <next\|previous\|toggle\|stop>` | MPRIS media control |
| `dpms-on` / `dpms-off` | Monitor power |
| `config-reload` | Reload config |
| `status` | Print state as JSON |
| `wifi-toggle` | Toggle Wi-Fi |
| `bluetooth-toggle` | Toggle Bluetooth |
| `power-set <profile>` / `power-cycle` | Power profiles |
| `dock-show` / `dock-hide` / `dock-toggle` | Dock visibility |
| `window-switcher [close]` | Open/close window switcher |

## Screenshot
```bash
grim -g "$(slurp)" ~/Pictures/screenshot-$(Y%m%d-%H%M%S).png
```

Noctalia v5 also has built-in screenshot commands: `noctalia msg screenshot-region` and `noctalia msg screenshot-fullscreen`.

## Night Light
```bash
wlsunset -S 07:30 -s 18:30 -t 3500 -T 6500 &
```

Noctalia v5 has built-in night light (gamma control): `noctalia msg nightlight-toggle`, configured in settings GUI or `~/.local/state/noctalia/settings.toml` under `[nightlight]`. If using Noctalia's night light, don't run wlsunset (they conflict).

## Troubleshooting
| Error | Fix |
|-------|-----|
| Wayland socket not created / labwc "unable to create backend" | Set `WLR_RENDERER=pixman` in `~/.config/labwc/environment` to force software rendering. Labwc uses libseat (elogind/turnstile) and falls back to headless backend if DRM is unavailable, not creating a wayland socket. |
| Socket missing | `pgrep turnstiled`, check `/run/elogind/` |
| Missing boot dir | `sudo mkdir -p /usr/lib/dinit.d/user/boot.d` |
| Service restarting quickly | `dinitctl catlog <service>` |
| Orphaned process | Kill manually, then `dinitctl --user start <service>` |
| Bluetooth pairing | Install `bluez-utils` for `bluetoothctl`, start service with `dinitctl start bluetoothd` |
| polkit failing | Unload bad service: `dinitctl --user unload polkit`; polkit runs via D-Bus activation (no dinit service needed) |
| wlr-randr "failed to connect to display" | These services waits-for wayland-ready; check `dinitctl --user status wayland-ready` |
| Noctalia won't start | Check `dinitctl --user status noctalia` and `dinitctl --user catlog noctalia`. Ensure `/usr/bin/noctalia` exists. |
| Flatpak "Settings portal not found" / "dbus-launch" error | Add `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` to `~/.config/dinit.d/environment` |
| Nautilus not remembering network passwords | Ensure gnome-keyring dinit service is running: `dinitctl --user start gnome-keyring` |
| Terminal opens to wrong directory (e.g., ~/.config/dinit.d) | Add `HOME=/home/user` to `~/.config/dinit.d/environment`, then restart user services |
| "unable to open wayland socket: Invalid argument" | Set `manage_rundir = yes` in `/etc/turnstile/turnstiled.conf` and restart turnstiled |
| Noctalia IPC command not working | Ensure noctalia is running: `dinitctl --user status noctalia`. Verify socket: `ls $XDG_RUNTIME_DIR/noctalia-*` |

## Useful Commands
```bash
xdg-user-dirs-update
dinitctl --user reload <service>
```

## dinitctl list
- `dinitctl list` shows user services when user dinit is running
- Socket: `/run/user/1000/dinitctl`
- If it fails with "No such file or directory", user dinit isn't running — start it manually:
  ```bash
  nohup dinit -u -d ~/.config/dinit.d -p /run/user/1000/dinitctl > /tmp/dinit.log 2>&1 &
  sleep 2
  ```
- Turnstile sets `DBUS_SESSION_BUS_ADDRESS` but does NOT start dbus-daemon — `~/.config/dinit.d/dbus` is still required

## Chromium/Brave (Flatpak on Wayland)
Set `--ozone-platform=wayland` in the desktop file so launching via menu/app launcher uses Wayland:

1. Copy the system desktop file to local: `cp /var/lib/flatpak/exports/share/applications/<app>.desktop ~/.local/share/applications/`
2. Edit `~/.local/share/applications/<app>.desktop`, adding `--ozone-platform=wayland` to all `Exec=` lines
3. Run `update-desktop-database ~/.local/share/applications/`
4. Set as default: `xdg-settings set default-web-browser <app>.desktop`

For Brave: `<app>` = `com.brave.Browser.desktop`
For Chromium: `<app>` = `org.chromium.Chromium.desktop`

## Noctalia Wallpaper

### Setting via IPC
```bash
noctalia msg wallpaper-set <path>
noctalia msg wallpaper-random [connector]
```

### Config File
Edit `~/.config/noctalia/config.toml` (TOML format, not JSON):
```toml
[wallpaper]
directory = "/home/user/Pictures/Wallpapers"
# Per-monitor paths are stored in ~/.local/state/noctalia/settings.toml
```

App-managed wallpaper state is in `~/.local/state/noctalia/settings.toml` under `[wallpaper.monitors.<connector>]`.

### Restart Noctalia after config changes
```bash
dinitctl --user stop wlr-randr && dinitctl --user stop noctalia && dinitctl --user start noctalia && dinitctl --user start wlr-randr
```

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
Lock+suspend is handled via labwc keybind in `rc.xml`:
- Keybind `XF86PowerOff` → `/home/user/.local/bin/lock-suspend`
- Script uses Noctalia v5 IPC:
  ```sh
  noctalia msg volume-mute
  noctalia msg session lock-and-suspend
  ```
- Also mutes audio before suspending

## Logout (Noctalia v5)
Noctalia v5 handles logout gracefully via `noctalia msg session logout`. Internally it tries:
1. `labwc --exit` (graceful compositor exit)
2. `labwc -e`
3. `kill $LABWC_PID SIGTERM`
4. `loginctl terminate-session $XDG_SESSION_ID`
5. `systemctl --user stop graphical-session.target`
6. `loginctl terminate-user $USER`

No more `pkill -9 labwc` — v5 uses graceful shutdown.

### Restart Noctalia (required after config.toml changes)
```bash
dinitctl --user stop wlr-randr && dinitctl --user stop noctalia && dinitctl --user start noctalia && dinitctl --user start wlr-randr
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
```

**`/etc/pam.d/ly`** — Manual login (requires pam_turnstile.so for user dinit):
```
#%PAM-1.0
auth       requisite    pam_nologin.so
auth       requisite    pam_unix.so
account    required     pam_unix.so
session    required     pam_unix.so
password   required     pam_unix.so
session    optional     pam_turnstile.so
```

**Important**: Both `/etc/pam.d/ly` AND `/etc/pam.d/ly-autologin` must have `pam_turnstile.so` in session. Without it in `ly`, user dinit won't start.

**Key rules**:
- `session required pam_unix.so` is REQUIRED in `ly-autologin` — without it, turnstile can't set up the session and user dinit won't start (`/run/user/1000/dinitctl` missing)
- `pam_turnstile.so` must be `optional`, NOT `required` — if it fails for any reason, `required` causes PAM to reject the session and ly loops endlessly
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
