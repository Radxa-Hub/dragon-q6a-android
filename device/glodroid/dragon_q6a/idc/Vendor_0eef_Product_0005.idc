# Input Device Configuration for the WaveShare WS170120 USB touchscreen
# (Waveshare 7" HDMI LCD (C), USB-HID single-touch, Vendor 0eef Product 0005).
#
# The panel reports ABS_X/ABS_Y + BTN_TOUCH but sets no INPUT_PROP_DIRECT, so
# Android's TouchInputMapper defaults it to POINTER mode (a mouse cursor that
# cannot tap). Forcing the device type makes it a real, absolute touchscreen.
touch.deviceType = touchScreen

# Single-finger panel: report taps/swipes against the display, orientation-aware.
touch.orientationAware = 1
