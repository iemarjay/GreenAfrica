from pydantic import BaseModel

class Settings(BaseModel):
    # Camera
    CAM_INDEX: int = 0
    FRAME_W: int = 640
    FRAME_H: int = 480

    # Camera image controls, applied via v4l2-ctl on open (OpenCV's CAP_PROP_*
    # exposure/WB mappings are unreliable on UVC). Without these the A4Tech cam
    # boots to a ~50us exposure with white balance off — near-black, blue-cast
    # frames. Auto exposure gives a sharp, full-colour frame.
    CAM_V4L2_CONTROLS: dict = {
        "auto_exposure": 3,             # 3 = auto (aperture priority)
        "white_balance_automatic": 1,   # auto WB (kills the blue cast)
        "gain": 32,
        "brightness": 0,
        "power_line_frequency": 1,      # 50 Hz — match mains to avoid flicker
    }

    # ROI (entry hole)
    ROI_CX: int = 310
    ROI_CY: int = 190
    ROI_R: int = 55

    # Detection thresholds
    USE_MOG2: bool = True
    MOTION_PIXELS_THRESHOLD: int = 1500
    CONSEC_FRAMES_REQUIRED: int = 5
    DETECT_COOLDOWN_S: float = 2.5

    # Absdiff background path
    DIFF_THRESH: int = 15
    BG_LEARN_RATE: float = 0.005
    IDLE_RESET_SECONDS: float = 10.0

    # JPEG quality for tooling images
    JPEG_QUALITY: int = 80

settings = Settings()
