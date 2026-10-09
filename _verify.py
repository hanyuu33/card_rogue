# -*- coding: utf-8 -*-
"""三套回归一键跑（2026-10-01 重建：原文件被早期清理脚本误删）。

用法：python _verify.py
逐套跑 engine / reward / smoke，统计 ✓/✗，任一失败则进程退出码 1。
输出同时落盘 _e.txt / _r.txt / _s.txt 便于事后检查。
"""
import os
import subprocess
import sys

# 引擎定位顺序：环境变量 GODOT_BIN > 同目录 console 版 > 普通版 > PATH 里的 godot。
# 官方只发布普通版（*_win64.exe），console 版（*_console.exe）并非每个版本都有，
# 所以这里做多路回退，换机器 / 换版本都不会因为文件名对不上而直接报错。
_GODOT_DIR = os.path.join(os.path.expanduser("~"), ".workbuddy", "binaries", "godot")
_GODOT_CANDIDATES = [
    os.environ.get("GODOT_BIN", ""),
    os.path.join(_GODOT_DIR, "Godot_v4.3-stable_win64_console.exe"),
    os.path.join(_GODOT_DIR, "Godot_v4.3-stable_win64.exe"),
    "godot",
]


def _find_godot():
    for p in _GODOT_CANDIDATES:
        if not p:
            continue
        if os.path.isabs(p) and os.path.isfile(p):
            return p
        if not os.path.isabs(p):
            from shutil import which
            found = which(p)
            if found:
                return found
    sys.exit("[_verify] 找不到 Godot 4.3：请安装到 %s，"
             "或用环境变量 GODOT_BIN 指定引擎路径" % _GODOT_DIR)


# 以脚本自身位置推导工程根目录，双机（D:\work / E:\work）通用
ROOT = os.path.dirname(os.path.abspath(__file__))
GODOT = _find_godot()
OK = "\u2713"
BAD = "\u2717"

SUITES = [
    ("engine", ["--headless", "--path", ROOT, "--script", "res://scripts/test_engine.gd"], "_e.txt"),
    ("reward", ["--headless", "--path", ROOT, "--script", "res://scripts/test_reward.gd"], "_r.txt"),
    ("replay", ["--headless", "--path", ROOT, "--script", "res://scripts/test_replay.gd"], "_rp.txt"),
    # ⚠️ smoke **必须** 也带 --headless：它原本是唯一一条不带  的套件，
    # 于是每次跑门禁都会**真的弹出一个游戏窗口**，在窗口里依次加载 21 个场景。
    # 后果有二：① 用户屏幕上冒出一个看起来「未响应」的游戏窗口；
    #          ② 那个窗口一旦被关闭/失去响应，smoke 进程就带着一个垃圾退出码死掉，
    #             门禁报  而**看不到任何有用信息**。
    # 已核实 test_smoke.gd **完全不依赖真实渲染**（无 viewport / 截图 / DisplayServer 调用），
    # 所以加 --headless 只是把窗口去掉，断言一条都不会变。
    ("smoke", ["--headless", "--path", ROOT, "--script", "res://scripts/test_smoke.gd"], "_s.txt"),
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
