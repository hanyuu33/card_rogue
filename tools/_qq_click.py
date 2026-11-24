# -*- coding: utf-8 -*-
"""点屏幕坐标（物理像素）。用法：python tools/_qq_click.py <x> <y> [--move]
只用 SetCursorPos + mouse_event，避免键盘输入法问题。
"""
import ctypes
import sys
import time

user32 = ctypes.windll.user32

MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004


def click(x: int, y: int, move_only: bool = False) -> None:
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.35)
    if move_only:
        return
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.09)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.45)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: _qq_click.py <x> <y> [--move]")
        raise SystemExit(2)
    click(int(sys.argv[1]), int(sys.argv[2]), "--move" in sys.argv)
    print("clicked", sys.argv[1], sys.argv[2])
