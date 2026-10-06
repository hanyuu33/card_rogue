# -*- coding: utf-8 -*-
"""三套回归一键跑（2026-10-01 重建：原文件被早期清理脚本误删）。

用法：python _verify.py
逐套跑 engine / reward / smoke，统计 ✓/✗，任一失败则进程退出码 1。
输出同时落盘 _e.txt / _r.txt / _s.txt 便于事后检查。
"""
import os
import subprocess
import sys

GODOT = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = r"D:\work\card_rogue"
OK = "\u2713"
BAD = "\u2717"

SUITES = [
    ("engine", ["--headless", "--path", ROOT, "--script", "res://scripts/test_engine.gd"], "_e.txt"),
    ("reward", ["--headless", "--path", ROOT, "--script", "res://scripts/test_reward.gd"], "_r.txt"),
    ("replay", ["--headless", "--path", ROOT, "--script", "res://scripts/test_replay.gd"], "_rp.txt"),
    ("smoke", ["--path", ROOT, "--script", "res://scripts/test_smoke.gd"], "_s.txt"),
]


def main():
    fail = False
    for name, args, out_name in SUITES:
        out = os.path.join(ROOT, out_name)
        with open(out, "wb") as f:
            rc = subprocess.call([GODOT] + args, cwd=ROOT, stdout=f,
                                 stderr=subprocess.STDOUT)
        d = open(out, "rb").read().decode("utf-8", "replace")
        good, bad = d.count(OK), d.count(BAD)
        lines = d.strip().splitlines()
        tail = lines[-1].strip()[:120] if lines else "(no output)"
        # ⚠️ **Parse Error 必须显眼**：GDScript 缩进错会让某个脚本整个加载失败，
        # 而 smoke 的「N 通过 / 0 失败」里**照样全绿**（失败发生在用例跑完之后，
        # 例如 battle 场景已跑完才发现 battle_scene.gd 解析不了）。
        # 所以这里把解析错误单独抽出来打在最后一行，判绿时先看它。
        broken = "Parse Error" in d or "SCRIPT ERROR" in d
        parse_lines = [l.strip() for l in lines
                       if "Parse Error" in l or "SCRIPT ERROR" in l]
        smoke_ok = name != "smoke" or "0 失败" in d
        print("%-7s exit=%d  %d%s / %d%s" % (name, rc, good, OK, bad, BAD))
        print("        " + tail)
        if broken:
            for pl in parse_lines[:5]:
                print("        !! " + pl[:120])
        if rc != 0 or bad > 0 or broken or not smoke_ok:
            fail = True
    print("== _verify：%s ==" % ("有失败" if fail else "全部通过"))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
