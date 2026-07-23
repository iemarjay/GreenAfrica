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
- `display-power.sh` — blanks the panel after an idle timeout, wakes on touch.

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

## Panel power saving (blank when idle, wake on touch) — UNVERIFIED

Only the panel sleeps; the Pi stays awake so the detector keeps watching for
drops.

```bash
sudo apt install -y swayidle
chmod +x ~/rvm_api/deploy/display-power.sh
echo '~/rvm_api/deploy/display-power.sh &' >> ~/.config/labwc/autostart
```

`wlopm` is preferred over `wlr-randr --off` (it powers the output down without
disabling it, so kanshi's landscape transform survives), but it is **not
packaged for Debian bookworm** — build it from
<https://sr.ht/~leon_plickat/wlopm/>. The script falls back to `wlr-randr`
automatically and re-asserts `transform 90` on wake.

**Known rough edges on labwc/RPi — test on-device before relying on this:**
- Some labwc/RPi setups never wake the panel after blanking
  ([labwc#3352](https://github.com/labwc/labwc/issues/3352)).
- Touch wake can need several taps rather than one.
- The first touch after wake is consumed by the wake itself — desirable here,
  since it stops the wake-tap from hitting a kiosk button.
- Blanking by *disabling* the output can make kanshi re-apply its profile and
  fight the blank; that is why `wlopm` is preferred.

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
