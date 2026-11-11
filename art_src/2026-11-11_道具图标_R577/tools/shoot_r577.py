# -*- coding: utf-8 -*-
"""R577b 实机截图验收：五处道具图标展示。

⚠️ 必须带窗口（不能 --headless，dummy 渲染器 get_image() 返回 null）。
一次调用跑完五张，循环关在脚本里；每张各自起一个短命 Godot 进程。
"""
import shutil
import subprocess
import time
from pathlib import Path

G = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "art_src" / "2026-11-11_道具图标_R577" / "_review"
OUT.mkdir(parents=True, exist_ok=True)

SHOTS = [
    # (产物名, 场景, 参数, 该场景写出的截图文件)
    ("ingame_map_relics.png", "res://scenes/map.tscn",
     ["--screenshot", "--relicmany", "--shotwait", "0.8"], "screenshot.png"),
    ("ingame_battle_relics.png", "res://scenes/battle.tscn",
     ["--screenshot", "--relics", "--shotframe", "600"], "screenshot.png"),
    ("ingame_reward_relic.png", "res://scenes/battle.tscn",
     ["--screenshot", "--r119relic", "--shotframe", "600"], "screenshot.png"),
    ("ingame_relic_pick.png", "res://scenes/relic_pick.tscn",
     ["--screenshot"], "screenshot_relic_pick.png"),
    ("ingame_event_mention.png", "res://scenes/event.tscn",
     ["--screenshot", "--apple"], "screenshot_event.png"),
]


def main() -> int:
    for name, scene, args, produced in SHOTS:
        src = ROOT / produced
        if src.exists():
            src.unlink()
        t0 = time.time()
        cmd = [G, "--path", str(ROOT), "--resolution", "1280x720", scene, "--"] + args
        try:
            r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, timeout=180)
        except subprocess.TimeoutExpired:
            print("TIMEOUT", name, flush=True)
            continue
        if src.exists():
            dst = OUT / name
            shutil.move(str(src), str(dst))
            print("OK  %-30s %5.1fs %4dKB" % (name, time.time() - t0,
                                               dst.stat().st_size // 1024), flush=True)
        else:
            print("MISS %-30s rc=%d" % (name, r.returncode), flush=True)
            print((r.stdout or b"").decode("utf-8", "replace")[-500:], flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
