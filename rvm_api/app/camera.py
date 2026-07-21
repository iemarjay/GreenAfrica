import subprocess
import cv2
from .settings import settings


def open_camera():
    cap = cv2.VideoCapture(settings.CAM_INDEX)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, settings.FRAME_W)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, settings.FRAME_H)
    _apply_camera_controls(settings.CAM_INDEX)
    return cap


def _apply_camera_controls(index: int):
    """Set exposure / white balance / gain via v4l2-ctl.

    OpenCV's CAP_PROP_* exposure mappings are unreliable on UVC cameras, so we
    drive the controls directly. Best-effort: each control is independent and a
    failure (unsupported control, missing v4l2-ctl) is logged, not fatal.
    """
    dev = f"/dev/video{index}"
    for name, val in settings.CAM_V4L2_CONTROLS.items():
        try:
            subprocess.run(
                ["v4l2-ctl", "-d", dev, f"--set-ctrl={name}={val}"],
                check=False, timeout=3,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"[camera] v4l2 set {name}={val} failed: {e}")
