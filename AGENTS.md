# Agent Configuration

Keep this file updated with non-trivial system info

## Operating System
- **Distro**: Artix Linux (Arch-based)
- **Init System**: dinit
- **Desktop Environment/Window Manager**: labwc (Wayland compositor, wlroots-based) or Hyprland
- **Current Setup**: labwc + Noctalia (Quickshell-based desktop shell)
- **Current Session**: tty1 (graphical) + c1 (Wayland compositor)

## Package Management
- Use `pacman` for package management
- Use `yay` or `paru` for AUR packages

## Service Management

### System Services (dinit)
- Use `dinitctl` for managing dinit services (not `systemctl`)
- Example: `dinitctl start <service>`, `dinitctl stop <service>`, `dinitctl status <service>`
- System service files: `/etc/dinit.d/`

### User Services (dinit)
- User services directory: `~/.config/dinit.d/`
- Control user services: `dinitctl --user <command> <service>`
- After editing service files, run `dinitctl --user reload <service>` then start
- Service types:
  - `type = process` — runs in foreground, dinit tracks it directly. Use for daemons that don't create PID files (pipewire, wireplumber)
  - `type = bgprocess` — daemon forks, requires `pid-file`. Only use if the process actually writes a PID file
- Dependencies: `depends-on = <other-service>` — waits for dependency to start first
- Symlink into `~/.config/dinit.d/boot.d/` to start at boot
- Active user services: pipewire, pipewire-pulse, wireplumber

### How User Services Start at Boot (turnstile)
- The user dinit daemon is managed by **turnstile** (`/usr/lib/turnstile/dinit`)
- Turnstile dynamically generates a `boot` service at `/run/turnstiled/1000/srv.NNN/` with:
  ```
  type = internal
  depends-on = system
  waits-for.d = /home/user/.config/dinit.d/boot.d/
  depends-on = login.target
  ```
- `waits-for.d` auto-starts everything symlinked in `~/.config/dinit.d/boot.d/`
- System-wide user services from `/usr/lib/dinit.d/user/boot.d/` are loaded via the `system` service
- Turnstile also generates: `login.target`, `graphical.target` (triggered), `graphical.monitor`
- **Do NOT manually create `boot` or `system` services** — turnstile overwrites them

## Audio Stack
- **PipeWire** with **WirePlumber** and **pipewire-pulse** for audio/screencast
- Managed via dinit user services: `~/.config/dinit.d/`
- Service files use `type = process` (pipewire doesn't create a PID file)
- Required services: `pipewire`, `pipewire-pulse` (provides Pulse compatibility), `wireplumber`
- WirePlumber must `depends-on = pipewire` (needs PipeWire socket ready)
- Use `wpctl` for volume control (e.g., `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+`)

## XDG Desktop Portal (Wayland)
- Portal implementations: `xdg-desktop-portal-wlr` (screen share), `xdg-desktop-portal-gtk` (file dialogs)
- Config: `~/.config/xdg-desktop-portal/labwc-portals.conf`
- Portals are **D-Bus activated**, NOT dinit services — they start on demand
- Must set activation environment in `~/.config/labwc/autostart`:
  ```
  [ ! -S "/run/user/1000/bus" ] && /usr/bin/dbus-daemon --session --fork --nopidfile --address=unix:path=/run/user/1000/bus
  dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=labwc
  ```
- D-Bus session bus: `unix:path=/run/user/1000/bus`
- Binary locations: `/usr/lib/xdg-desktop-portal`, `/usr/lib/xdg-desktop-portal-wlr` (not in `$PATH`)

## User Autostart Consolidation
Multiple autostart locations are used. Cleanest approach:
1. **Dinit user services** (`~/.config/dinit.d/`): System daemons (pipewire, wireplumber, etc.)
2. **labwc autostart** (`~/.config/labwc/autostart`): labwc-specific things (swayidle, kanshi, polkit-agent)
3. **Hyprland autostart** (`~/.config/hypr/startup` or autostart option): Hyprland-specific things
4. **XDG autostart** (`~/.config/autostart/`): Keep disabled (Hidden=true) unless needed

## Screenshot Tools (labwc)
- `grim` - capture screenshots (part of wlroots)
- `slurp` - select region with mouse
- Screenshot command: `grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png`
- Keybinding configured in `~/.config/labwc/rc.xml`

## GTK Applications (Nautilus, etc.)
- Sidebar bookmarks: `~/.config/gtk-3.0/bookmarks` and `~/.config/gtk-4.0/bookmarks`
- Format: `file:///home/user/Directory Display Name`
- Run `xdg-user-dirs-update` to regenerate XDG directory config

## XDG User Dirs
- Config: `~/.config/user-dirs.dirs`
- Default dirs: Desktop, Downloads, Documents, Pictures, Music, Videos, Templates, Public
- Create missing dirs and run `xdg-user-dirs-update`

## labwc Configuration
- Main config: `~/.config/labwc/rc.xml`
- Autostart: `~/.config/labwc/autostart` (runs commands at session start)
- Theme: `~/.config/labwc/themerc-override` (override theme settings)
- Menu: `~/.config/labwc/menu.xml`
- Volume keys: Use `wpctl` commands in keybinds (XF86AudioRaiseVolume, XF86AudioLowerVolume, XF86AudioMute)

## Night Light (wlsunset)
- wlsunset provides color temperature adjustment for Wayland
- Configured in labwc autostart with manual sunrise/sunset times: `wlsunset -S 07:30 -s 18:30 -t 3500 -T 6500 &`
- Options: `-S` sunrise time, `-s` sunset time, `-t` day temp (6500K = normal), `-T` night temp (3500K = warm/red)
- labwc 0.9.3 supports wlr-color-management protocol

## Hyprland Configuration (when using Hyprland)
- Config: `~/.config/hypr/`
- Autostart: Use `exec-once = <command>` in `~/.config/hypr/hyprland.conf` or `~/.config/hypr/startup`
- Idle management: Replace swayidle with `hypridle`
- Output management: Replace kanshi with Hyprland native `monitor=` directives
- Wallpaper: `swaybg` can still be used or use `hyprpaper`
- Keybinds: Configure in `~/.config/hypr/hyprland.conf`

## Important Notes
- Do NOT suggest systemd commands (e.g., `systemctl`)
- Do NOT suggest openrc or runit commands
- labwc/Hyprland are Wayland compositors - use Wayland-native commands
- Service files for dinit system are in `/etc/dinit.d/`
- elogind is running — use `loginctl suspend`, `loginctl poweroff`, etc. (not `systemctl suspend`)
- **Do NOT `kill -HUP` the user dinit daemon** — it kills all tracked process-type services and dinit loses track of them
- If dinit loses track of a running process, kill the orphaned process manually, then `dinitctl --user start <service>`
- Cached service entries (e.g. from deleted files) persist in dinit memory until dinit daemon restarts

## Useful Paths
- User environment: `~/.config/environment.d/`
- User autostart: `~/.config/autostart/`
- User dinit services: `~/.config/dinit.d/`
- Shell profile: `~/.bash_profile` (sets DBUS_SESSION_BUS_ADDRESS)
- Display manager: ly (configured in `/etc/dinit.d/`)
- GTK bookmarks: `~/.config/gtk-3.0/bookmarks`, `~/.config/gtk-4.0/bookmarks`
- labwc autostart: `~/.config/labwc/autostart`
- User dinit boot links: `~/.config/dinit.d/boot.d/`

## Noctalia (Quickshell-based desktop shell)
- Config: `~/.config/noctalia/settings.json`
- Quickshell config (system): `/etc/xdg/quickshell/noctalia-shell/`
- Quickshell config (user): `~/.config/quickshell/noctalia-shell/`
- User config overrides go in `~/.config/quickshell/noctalia-shell/settings.json`
- Wallpaper directory: `~/Pictures/Wallpapers`

### Setting Wallpaper
1. Copy image to `~/Pictures/Wallpapers/`
2. Edit `~/.config/noctalia/settings.json`:
   - Set `"enableMultiMonitorDirectories": true`
   - Add entries in `"monitorDirectories"` for each monitor:
     ```json
     "monitorDirectories": [
       {
         "directory": "/home/user/Pictures/Wallpapers",
         "name": "eDP-1",
         "wallpaper": "/home/user/Pictures/Wallpapers/image.jpg"
       },
       {
         "directory": "/home/user/Pictures/Wallpapers",
         "name": "DP-1",
         "wallpaper": "/home/user/Pictures/Wallpapers/image.jpg"
       }
     ]
     ```
3. Restart quickshell: `pkill -f "qs -c"; qs -c noctalia-shell &`

### Noctalia Bug Workaround
The `getWallpaper()` function in `/home/user/.config/quickshell/noctalia-shell/Services/UI/WallpaperService.qml` doesn't read monitor-specific wallpaper paths from settings when `enableMultiMonitorDirectories` is enabled. The patched version checks for `monitor.wallpaper` in `getMonitorConfig()` and returns it if set.
