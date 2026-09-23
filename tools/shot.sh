#!/bin/bash
# Captura uma cena renderizada FORA da tela (Xvfb + renderizador de compatibilidade).
# Nunca usa o display real. Ex.: tools/shot.sh /tmp/a.png --scene=res://scenes/levels/ch01.tscn --wait=4
out="$1"; shift
cd "$(dirname "$0")/.." || exit 1
unset WAYLAND_DISPLAY DISPLAY
xvfb-run -a -s "-screen 0 1920x1080x24" env -u WAYLAND_DISPLAY \
  godot --display-driver x11 --rendering-method gl_compatibility --rendering-driver opengl3 \
  --path . --resolution 1920x1080 res://tests/shot.tscn -- --out="$out" "$@" 2>&1 \
  | grep -E "SHOT|ERROR|SCRIPT|at: |Wayland|wayland" | grep -v "at: _gdvirtual" | head -30
