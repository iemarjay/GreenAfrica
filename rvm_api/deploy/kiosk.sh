#!/usr/bin/env bash
# GreenAfrica RVM — Chromium kiosk launcher for the Pi (labwc / Wayland).
# Waits for rvm.service, then opens the kiosk UI full-screen.
set -euo pipefail

URL="${RVM_KIOSK_URL:-http://localhost:5000/kiosk}"
PROFILE="${RVM_KIOSK_PROFILE:-$HOME/.config/rvm-kiosk}"

# Pick whichever Chromium binary exists on this image.
CHROME="$(command -v chromium-browser || command -v chromium || true)"
if [[ -z "$CHROME" ]]; then
  echo "[kiosk] no chromium binary found (tried chromium-browser, chromium)" >&2
  exit 1
fi

# Block until the API is actually serving — avoids a "can't reach page" flash
# and the known camera-enumeration race at boot.
echo "[kiosk] waiting for $URL ..."
until curl -fsS -o /dev/null "http://localhost:5000/status"; do
  sleep 1
done
echo "[kiosk] API is up, launching Chromium"

# Clear the crash flag so we never get the "restore pages?" bar after a hard power-off.
if [[ -f "$PROFILE/Default/Preferences" ]]; then
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/; s/"exited_cleanly":false/"exited_cleanly":true/' \
    "$PROFILE/Default/Preferences" || true
fi

exec "$CHROME" \
  --kiosk "$URL" \
  --ozone-platform=wayland \
  --user-data-dir="$PROFILE" \
  --autoplay-policy=no-user-gesture-required \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=Translate,TranslateUI \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --check-for-update-interval=31536000 \
  --start-fullscreen
