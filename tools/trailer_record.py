# -*- coding: utf-8 -*-
"""用 Godot Movie Maker 模式录制实机片段（不经过屏幕，逐帧无损）。

    python tools/trailer_record.py --out seg01.avi --frames 450 --cls 暗影刺客

为什么不用 gdigrab 抓屏：后台进程抢不到前台焦点，窗口一直被别的程序盖住；
Movie Maker 由引擎自己把每一帧写进文件，窗口在哪、有没有被遮挡都不影响。
副作用是顺带把游戏音轨也录进去了（pcm_s32le / 48kHz / stereo）。
"""
import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"),
))
PORT = int(os.environ.get("CARD_ROGUE_AI_PORT", "8771"))
OUTDIR = ROOT / "release" / "trailer" / "raw"


def port_open():
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def _opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def get(path, timeout=10.0):
    with _opener().open("http://127.0.0.1:%d%s" % (PORT, path), timeout=timeout) as r:
        return r.read().decode("utf-8")


def post(path, payload, timeout=40.0):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        "http://127.0.0.1:%d%s" % (PORT, path), data=data, method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"})
    with _opener().open(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="seg_test.avi")
    ap.add_argument("--frames", type=int, default=450)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--cls", default="")
    ap.add_argument("--wait-new", type=float, default=4.0,
                    help="真实秒数，等工作室 logo / 标题过完再开局")
    ap.add_argument("--tail", type=float, default=0.0,
                    help="开局后再等多久（真实秒数）让引擎跑完剩余帧")
    args = ap.parse_args()

    OUTDIR.mkdir(parents=True, exist_ok=True)
    out = OUTDIR / args.out
    if out.exists():
        out.unlink()

    log = open(ROOT / ".trailer_game.log", "w", encoding="utf-8")
    cmd = [str(GODOT), "--path", str(ROOT),
           "--write-movie", str(out),
           "--fixed-fps", str(args.fps),
           "--quit-after", str(args.frames),
           "--", "--ai-bridge=%d" % PORT]
    print("run:", " ".join(cmd), flush=True)
    t0 = time.time()
    proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, cwd=str(ROOT))
    try:
        ok = False
        for _ in range(200):
            if port_open():
                ok = True
                break
            if proc.poll() is not None:
                break
            time.sleep(0.2)
        print("port_ready %s (+%.1fs)" % (ok, time.time() - t0), flush=True)
        if not ok:
            print("接口没起来，看 .trailer_game.log", flush=True)
            return 1

        if args.cls:
            time.sleep(args.wait_new)
            rep = post("/new", {"class": args.cls, "seed": ""})
            print("new_run ok=%s msg=%s (+%.1fs)"
                  % (rep.get("ok"), (rep.get("msg") or "")[:60], time.time() - t0), flush=True)
            st = rep.get("state") or get("/state")
            print("===== STATE AFTER NEW =====")
            print(st[:2500])
            print("===== END =====", flush=True)
            if args.tail:
                time.sleep(args.tail)
        proc.wait(timeout=180)
        print("done rc=%s  %.1fs  exists=%s  size=%s"
              % (proc.returncode, time.time() - t0, out.exists(),
                 out.stat().st_size if out.exists() else 0), flush=True)
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except Exception:
                proc.kill()
        log.close()


if __name__ == "__main__":
    sys.exit(main())
