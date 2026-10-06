# -*- coding: utf-8 -*-
"""卡牌肉鸽 · 发布独立版（老方式：Godot 主程序副本 + 旁挂 .pck）。

用法：
    python _release.py               跑回归 → 导出 pck → 替换 → 用发布产物自检
    python _release.py --no-verify   跳过回归（已经手工跑过时）

为什么是「老方式」：
    历史发布的 DuckCardsRogue.exe 就是 Godot 编辑器主程序
    (Godot_v4.3-stable_win64.exe) 的逐字节副本（MD5 一致），
    游戏数据放在同目录同名的 DuckCardsRogue.pck 里，由 Godot 启动时自动加载。
    **这种方式不需要官方导出模板**（--export-pack 只打包项目资源，不产出 exe），
    也不需要 1GB 的模板下载，是这台机器上一直采用的发布路径。

流程（顺序不能变）：
    1) 回归：调用 _verify.py，四套全绿才继续（任一失败立即中止，不动目标文件夹）。
    2) 导出：Godot --export-pack "Windows Desktop" dist/DuckCardsRogue.pck
    3) 替换：目标文件夹里写入 Godot 主程序副本(改名 DuckCardsRogue.exe) + 新 pck + release/ 附属文件。
    4) 校验：用「发布产物」真跑一遍四套测试，确认跑起来的是新内容。

关键坑（别改掉）：
  * exe 与 pck **必须同名**（DuckCardsRogue.exe / DuckCardsRogue.pck），
    Godot 启动时按 exe 名去同目录找同名 .pck；名字对不上就会退回空工程。
  * exe **不要重新导出**，直接复制 Godot 主程序。重新导出会需要导出模板，
    且产物体积与历史发布不一致（历史上就是 126MB 的编辑器主程序）。
  * 附属文件（玩法说明.txt / 自检.bat）来自 release/ 目录，不进 pck
    （export_presets.cfg 的 exclude_filter 已排除 *.txt / *.bat / *.py / *.md / *.cfg）。
"""
import os
import shutil
import subprocess
import sys

GODOT_EXE = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64.exe"
GODOT_CONSOLE = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = r"D:\work\card_rogue"
TARGET = r"D:\work\卡牌肉鸽_独立版"

PRESET = "Windows Desktop"
PACK_REL = "dist/DuckCardsRogue.pck"
EXE_NAME = "DuckCardsRogue.exe"
PCK_NAME = "DuckCardsRogue.pck"
EXTRA = "release"

OK = "✓"
BAD = "✗"

SUITES = [
    ("engine", "res://scripts/test_engine.gd"),
    ("reward", "res://scripts/test_reward.gd"),
    ("replay", "res://scripts/test_replay.gd"),
    ("smoke", "res://scripts/test_smoke.gd"),
]


def die(msg):
    print("[中止] " + msg)
    sys.exit(1)


def step(n, s):
    print("\n" + "=" * 60)
    print("  %d) %s" % (n, s))
    print("=" * 60)


def mb(path):
    return os.path.getsize(path) / 1048576.0


def run_suites(exe_path, cwd):
    """用给定 exe 跑四套测试，返回 (全通过?, 统计串)。"""
    base = [exe_path, "--headless"]
    all_ok = True
    summary = []
    for name, script in SUITES:
        rc = subprocess.call(base + ["--script", script], cwd=cwd,
                             stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        summary.append("%s:%s" % (name, "OK" if rc == 0 else "FAIL"))
        if rc != 0:
            all_ok = False
    return all_ok, " ".join(summary)


def main():
    do_verify = "--no-verify" not in sys.argv
    os.chdir(ROOT)

    # ---------- 1) 回归 ----------
    step(1, "回归测试（全绿才允许发布）")
    if do_verify:
        rc = subprocess.call([sys.executable, "_verify.py"], cwd=ROOT)
        if rc != 0:
            die("回归没通过 —— 目标文件夹原封不动。")
    else:
        print("  （--no-verify：已跳过）")

    # ---------- 2) 导出 pck ----------
    step(2, "导出数据包 pck（--export-pack，不需要导出模板）")
    if not os.path.exists(GODOT_CONSOLE):
        die("找不到 Godot：%s" % GODOT_CONSOLE)
    dist = os.path.join(ROOT, "dist")
    if os.path.isdir(dist):
        shutil.rmtree(dist)
    os.makedirs(dist, exist_ok=True)
    rc = subprocess.call([GODOT_CONSOLE, "--headless", "--path", ROOT,
                          "--export-pack", PRESET, PACK_REL], cwd=ROOT)
    if rc != 0:
        die("导出失败（Godot exit=%d）" % rc)
    pck_src = os.path.join(ROOT, "dist", PCK_NAME)
    if not os.path.exists(pck_src):
        die("导出后没找到 %s" % pck_src)
    print("  %s  %.2f MB" % (PCK_NAME, mb(pck_src)))

    # ---------- 3) 替换目标文件夹 ----------
    step(3, "替换目标文件夹  %s" % TARGET)
    os.makedirs(TARGET, exist_ok=True)
    exe_dst = os.path.join(TARGET, EXE_NAME)
    pck_dst = os.path.join(TARGET, PCK_NAME)

    # exe：Godot 主程序副本（老方式，exe 不重新导出）
    if not os.path.exists(GODOT_EXE):
        die("找不到 Godot 主程序：%s" % GODOT_EXE)
    shutil.copy2(GODOT_EXE, exe_dst)
    print("  写入 %s  %.1f MB（Godot 主程序副本）" % (EXE_NAME, mb(exe_dst)))

    # pck：先删旧的再拷，避免拷到一半失败留下不一致状态
    if os.path.exists(pck_dst):
        os.remove(pck_dst)
        print("  删除旧的 %s" % PCK_NAME)
    shutil.copy2(pck_src, pck_dst)
    print("  写入 %s  %.2f MB" % (PCK_NAME, mb(pck_dst)))

    src_extra = os.path.join(ROOT, EXTRA)
    if os.path.isdir(src_extra):
        for f in sorted(os.listdir(src_extra)):
            shutil.copy2(os.path.join(src_extra, f), os.path.join(TARGET, f))
            print("  写入 %s" % f)

    # ---------- 4) 用发布产物自检 ----------
    step(4, "用发布产物复跑一遍四套测试")
    ok, summary = run_suites(exe_dst, TARGET)
    print("  " + summary)
    if not ok:
        die("发布包自检失败 —— 上面标注 FAIL 的套件要查。")

    print("\n" + "=" * 60)
    print("  发布完成 -> %s" % TARGET)
    for f in sorted(os.listdir(TARGET)):
        p = os.path.join(TARGET, f)
        if os.path.isfile(p):
            print("    %-28s %8.2f MB" % (f, mb(p)))
    print("=" * 60)


if __name__ == "__main__":
    main()