# RVM kiosk deployment (Pi)

The recycler UI is now a static page served by `rvm_api` itself at
`http://localhost:5000/kiosk` (same-origin, so no CORS and no hard-coded Pi IP).
This replaces the Expo tablet app in `../../rvm`.

## Files

- `../web/kiosk.html` — the kiosk page (stream + points + ding + QR modal + reset).
- `../web/ding.mp3` — reward sound (copied from the old Expo app's assets).
- `kiosk.sh` — waits for `rvm.service`, then launches Chromium in kiosk mode.
- `kanshi.config` — display orientation (landscape) for the 4" panel, applied by
  kanshi (labwc's display-config daemon) at the display level, not the kiosk.

## One-time setup on the Pi

```bash
# on 192.168.101.10
chmod +x ~/rvm_api/deploy/kiosk.sh

# labwc runs ~/.config/labwc/autostart on session start
mkdir -p ~/.config/labwc
echo '~/rvm_api/deploy/kiosk.sh &' >> ~/.config/labwc/autostart

# Landscape orientation. The panel is a 480x800 portrait output; kanshi (already
# started from /etc/xdg/labwc/autostart) rotates it to 800x480 landscape. Without
# this a live `wlr-randr --transform` reverts on every reboot.
mkdir -p ~/.config/kanshi
cp ~/rvm_api/deploy/kanshi.config ~/.config/kanshi/config
```

Reboot (or `labwc --reconfigure` / re-login) and the kiosk comes up full-screen
once the API answers `/status`.

## Notes

- `--autoplay-policy=no-user-gesture-required` lets the reward *ding* play without
  a tap. The page also unlocks audio on the first touch as a fallback.
- Chromium renders raw MJPEG blank as a top-level page; the kiosk avoids this by
  putting `/stream` inside an `<img>`.
- The launcher waits on `/status` to dodge the boot-time camera-enumeration race
  (blank stream if the USB cam enumerates after `rvm.service` starts).
- To point at a remote API instead of localhost: `RVM_KIOSK_URL=http://<host>:5000/kiosk ~/rvm_api/deploy/kiosk.sh`.

## systemd alternative

If you'd rather not use labwc autostart, run it as a Wayland user service that
starts after the desktop — but autostart is simplest for a single-purpose kiosk.
