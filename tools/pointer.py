#!/usr/bin/env python3
"""A virtual mouse, for driving the editor in tests by hand (needs write access to /dev/uinput).

    tools/pointer.py move X Y                 absolute position in pixels (screen 1920x1080 unless --size)
    tools/pointer.py drag X1 Y1 X2 Y2         press at 1, glide to 2, release
    tools/pointer.py click X Y
    tools/pointer.py dblclick X Y

Options (before the command): --size WxH (default 1920x1080), --steps N (default 30).
Only for development; nothing in the project needs it.
"""
import fcntl
import os
import struct
import sys
import time

UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045567
UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x401C5504, 0x5501, 0x5502
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN_LEFT, ABS_X, ABS_Y = 0x110, 0, 1
RANGE = 32767


class Pointer:
    def __init__(self, width=1920, height=1080):
        self.w, self.h = width, height
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        for ev in (EV_KEY, EV_ABS, EV_SYN):
            fcntl.ioctl(self.fd, UI_SET_EVBIT, ev)
        fcntl.ioctl(self.fd, UI_SET_KEYBIT, BTN_LEFT)
        for ax in (ABS_X, ABS_Y):
            fcntl.ioctl(self.fd, UI_SET_ABSBIT, ax)
            fcntl.ioctl(self.fd, UI_ABS_SETUP, struct.pack("HHiiiiii", ax, 0, 0, 0, RANGE, 0, 0, 0))
        name = b"dwc-test-pointer".ljust(80, b"\0")
        fcntl.ioctl(self.fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 3, 1, 1, 1, name, 0))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)
        time.sleep(1.0)              # let the compositor notice the new device

    def close(self):
        fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        os.close(self.fd)

    def _emit(self, t, c, v):
        os.write(self.fd, struct.pack("llHHi", 0, 0, t, c, v))

    def move(self, x, y):
        self._emit(EV_ABS, ABS_X, int(x / self.w * RANGE))
        self._emit(EV_ABS, ABS_Y, int(y / self.h * RANGE))
        self._emit(EV_SYN, 0, 0)

    def button(self, down):
        self._emit(EV_KEY, BTN_LEFT, 1 if down else 0)
        self._emit(EV_SYN, 0, 0)

    def glide(self, x1, y1, x2, y2, steps=30, delay=0.012):
        for i in range(1, steps + 1):
            self.move(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
            time.sleep(delay)

    def drag(self, x1, y1, x2, y2, steps=30):
        self.move(x1, y1)
        time.sleep(0.2)
        self.button(True)
        time.sleep(0.15)
        self.glide(x1, y1, x2, y2, steps)
        time.sleep(0.3)
        self.button(False)

    def click(self, x, y, times=1):
        self.move(x, y)
        time.sleep(0.2)
        for _ in range(times):
            self.button(True)
            time.sleep(0.04)
            self.button(False)
            time.sleep(0.08)


def main():
    args = sys.argv[1:]
    w, h, steps = 1920, 1080, 30
    while args and args[0].startswith("--"):
        opt = args.pop(0)
        if opt == "--size":
            w, h = map(int, args.pop(0).split("x"))
        elif opt == "--steps":
            steps = int(args.pop(0))
    if not args:
        sys.exit(__doc__)
    cmd, nums = args[0], [float(a) for a in args[1:]]
    p = Pointer(w, h)
    try:
        if cmd == "move":
            p.move(*nums)
        elif cmd == "drag":
            p.drag(*nums, steps=steps)
        elif cmd == "click":
            p.click(*nums)
        elif cmd == "dblclick":
            p.click(*nums, times=2)
        else:
            sys.exit(__doc__)
        time.sleep(0.3)
    finally:
        p.close()


main()
