#!/bin/sh
# Wait for Wayland socket to appear. Handles:
# - inotifywait not installed (falls back to polling)
# - File created but not yet a socket (loop re-checks)
# - Socket deleted+recreated during startup (loop continues)
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
