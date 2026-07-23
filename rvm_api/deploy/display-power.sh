#!/usr/bin/env bash
# GreenAfrica RVM — panel power saving for the Pi kiosk (labwc / Wayland).
#
# Blanks the 4" panel after an idle timeout; touching the screen wakes it.
# Only the DISPLAY sleeps — the Pi stays awake because the detector must keep
# watching the camera for drops.
#
# Launch from the labwc session (see deploy/README.md):
#     ~/rvm_api/deploy/display-power.sh &
set -euo pipefail

TIMEOUT="${RVM_DISPLAY_TIMEOUT:-300}"          # idle seconds before blanking
OUTPUT="${RVM_KIOSK_OUTPUT:-HDMI-A-1}"

if ! command -v swayidle >/dev/null 2>&1; then
  echo "[display-power] swayidle not installed (sudo apt install swayidle)" >&2
  exit 1
fi

# Two ways to blank an output on wlroots:
#
#   wlopm  — uses wlr-output-power-management (DPMS-style). PREFERRED: it only
#            cuts output power and leaves the output ENABLED, so kanshi's
#            profile — and our landscape `transform 90` — survive the sleep/wake
#            cycle untouched. Not packaged for Debian bookworm; build from
#            source (https://sr.ht/~leon_plickat/wlopm/).
#
#   wlr-randr --off — DISABLES the output entirely. Works, but kanshi holds a
#            profile for this output and may re-apply it and fight the blank,
#            and the transform can be lost on wake — so we re-assert it in the
#            resume command below. Fallback only.
if command -v wlopm >/dev/null 2>&1; then
  OFF_CMD="wlopm --off $OUTPUT"
  ON_CMD="wlopm --on $OUTPUT"
else
  OFF_CMD="wlr-randr --output $OUTPUT --off"
  ON_CMD="wlr-randr --output $OUTPUT --on --transform 90"
fi

# -w waits for each command to finish before continuing, so an off/on pair can
# never interleave and leave the panel in a half-woken state.
exec swayidle -w \
  timeout "$TIMEOUT" "$OFF_CMD" \
  resume               "$ON_CMD"
