# -*- coding: utf-8 -*-
"""启动游戏 → 按窗口句柄定位 → 置顶 → 抓一帧 → 关闭。

    python tools/trailer_probe.py

用 ctypes 枚举窗口拿到真实标题与客户区矩形，避免 gdigrab 抓到的桌面被别的
窗口遮挡（抓桌面时游戏窗口往往排在 QQ / 编辑器后面）。
"""
import ctypes
import os
import socket
import subprocess
import sys
import time
import urllib.request
from ctypes import wintypes
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"),
))
FFMPEG = Path(os.environ.get(
    "CARD_ROGUE_FFMPEG",
    r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe",
))
PORT = int(os.environ.get("CARD_ROGUE_AI_PORT", "8770"))
OUT = ROOT / "release" / "trailer" / "probe"

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()

HWND_TOPMOST = -1
SWP_NOMOVE = 0x0002
SWP_NOSIZE = 0x0001


def windows_of(pid):
    """返回该 pid 的所有可见顶层窗口 [(hwnd, title, cls)]。pid 为 None 时返回全部。"""
    out = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _lp):
        wpid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        if pid is not None and wpid.value != pid:
            return True
        if not user32.IsWindowVisible(hwnd):
            return True
        n = user32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(n + 1)
        user32.GetWindowTextW(hwnd, buf, n + 1)
        cbuf = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cbuf, 256)
        out.append((hwnd, buf.value, cbuf.value, wpid.value))
        return True

    user32.EnumWindows(cb, 0)
    return out


def client_rect(hwnd):
    """客户区在屏幕上的 (x, y, w, h)，已排除标题栏与边框。"""
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y, r.right - r.left, r.bottom - r.top


def port_open():
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def get(path, timeout=8.0):
    op = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with op.open("http://127.0.0.1:%d%s" % (PORT, path), timeout=timeout) as r:
        return r.read().decode("utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    log = open(ROOT / ".trailer_game.log", "w", encoding="utf-8")
    args = [str(GODOT), "--path", str(ROOT), "--resolution", "1920x1080",
            "--", "--ai-bridge=%d" % PORT]
    proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, cwd=str(ROOT))
    print("pid", proc.pid, flush=True)
    try:
        ok = False
        for _ in range(150):
            if port_open():
                ok = True
                break
            if proc.poll() is not None:
                print("进程提前退出", proc.returncode, flush=True)
                break
            time.sleep(0.4)
        print("port_ready", ok, flush=True)
        if not ok:
            return 1
        time.sleep(2.5)

        wins = [(h, t, c) for h, t, c, w in windows_of(proc.pid) if c.lower().startswith("godot")]
        print("own windows:", [(t, c) for _, t, c in wins], flush=True)
        if not wins:
            allw = windows_of(None)
            cand = [(h, t, c, w) for h, t, c, w in allw
                    if ("卡牌" in t or "嘎嘎" in t or "godot" in c.lower())]
            print("scan-all candidates:", [(t, c, w) for _, t, c, w in cand], flush=True)
            if not cand:
                titled = [(t, c, w) for _, t, c, w in allw if t]
                print("all titled windows (%d):" % len(titled), titled[:25], flush=True)
                return 1
            wins = [(h, t, c) for h, t, c, _w in cand]

        hwnd = wins[0][0]
        user32.ShowWindow(hwnd, 9)          # SW_RESTORE
        user32.SetWindowPos(wintypes.HWND(hwnd), wintypes.HWND(-1), 0, 0, 0, 0,
                            SWP_NOMOVE | SWP_NOSIZE | 0x0040)   # + SWP_SHOWWINDOW
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
        time.sleep(1.5)
        fore = user32.GetForegroundWindow()
        print("foreground_is_game", fore == hwnd, flush=True)

        x, y, w, h = client_rect(hwnd)
        print("client_rect", x, y, w, h, flush=True)
        Path(OUT / "rect.txt").write_text("%d,%d,%d,%d" % (x, y, w, h), encoding="utf-8")

        txt = get("/state")
        print("===== STATE =====")
        print(txt[:2000])
        print("===== END =====", flush=True)

        shot = OUT / "game.png"
        subprocess.run([str(FFMPEG), "-y", "-f", "gdigrab", "-i", "desktop",
                        "-offset_x", str(x), "-offset_y", str(y),
                        "-video_size", "%dx%d" % (w, h),
                        "-frames:v", "1", str(shot), "-loglevel", "error"], check=False)
        print("shot:", shot.exists(), flush=True)
        return 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except Exception:
            proc.kill()
        print("closed", flush=True)


if __name__ == "__main__":
    sys.exit(main())
