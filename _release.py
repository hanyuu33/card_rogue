# -*- coding: utf-8 -*-
"""卡牌肉鸽 · 发布独立版。

用法：
    python _release.py                  回归 → 导出 → 覆盖目标 → 用发布产物自检
    python _release.py --no-verify      跳过回归（已经手工跑过时）
    python _release.py --two-file       exe + 旁挂 pck 双文件（旧形态，保留兼容）
    python _release.py --target=目录    写到别的目录（验证用，不碰正式发布目录）

════════════════════════════════════════════════════════════════════
为什么 R386 改成「真导出模板」（这是本轮修的一个真 bug）
════════════════════════════════════════════════════════════════════
旧流程 = 复制 Godot **编辑器主程序**（Godot_v4.3-stable_win64.exe，132.9MB）
改名成 DuckCardsRogue.exe，再旁挂一个 .pck。当时的理由是「不用下载 1GB 模板」。

实测（2026-10-26，三组对照）：
  * 编辑器 exe + 无 pck  → 只打印版本横幅，**静默进入项目管理器**（exit 0）。
    用户看到的就是「双击打开弹 Godot 项目管理器」—— 因为**编辑器的本职就是
    管理项目**，找不到同名 .pck 就退回项目管理器。
  * 导出模板 + 无 pck    → 明确报
    `Error: Couldn't load project data at path ".". Is the .pck file missing?`
  * 导出模板 + 有 pck    → 正常跑，engine 4011✓ / 0✗（与编辑器版逐条一致）

所以「有的电脑弹项目管理器」= 那些机器上 exe 与 pck 被拆散了（只拷了 exe /
解压不全 / 杀软隔离 pck / 改名 / 放进不同文件夹）。有 pck 的机器就正常，于是
看起来「有的电脑」。

顺带三个副作用：
  * 体积虚高 49MB（编辑器 132.9 + pck 89.3 = 222MB；模板 84.2 + pck 89.3 = 173MB）。
  * exe 里带着整个编辑器（调试器 / 资源导入器 / 项目管理 UI），启动还会读
    `%APPDATA%\\Godot\\` 全局配置 —— 在装过 Godot 或别的 Godot 游戏的机器上会串味。
  * `binocular` 之类外部工具会把它当成「Godot 编辑器进程」。

`export_presets.cfg` 里 `binary_format/embed_pck` 本来就是 `true` → 正常
`--export-release` 直接产出**单个 173.55MB exe**（模板 84.2 + 内嵌 pck 89.3），
没有 pck 文件。玩家只有一个文件，**不可能漏拷 pck**，也永远不会弹项目管理器。
实测：单文件单独扔进空目录 → engine 4033✓ / 0✗，四套全绿。

════════════════════════════════════════════════════════════════════
关键坑（别改掉）
════════════════════════════════════════════════════════════════════
  * 附属文件（玩法说明.txt / 自检.bat）来自 release/ 目录，**不进 pck**
    （export_presets.cfg 的 exclude_filter 已排除 *.txt / *.bat / *.py / *.md / *.cfg）。
  * 第 4 步**绝不能只看 exit code**：`test_smoke.gd` 无论失败与否都 exit 0。
    R386 实测旧发布包是「smoke 51 通过 / 4 失败」而 rc=0 —— 历史记录里的
    「包内四套全绿」有一半是假绿。现在改成解析输出文本（✗ / SMOKE FAIL /
    SCRIPT ERROR / 「结束：N 通过 / M 失败」）。
  * 单文件模式下，目标目录里留着的旧 `DuckCardsRogue.pck` **必须删掉** ——
    单文件 exe 不读它，但留着会让玩家以为是必需文件，也会让「pck 缺失」的
    排查线索变乱。
  * exe 被正在运行的游戏锁住会抛 PermissionError，这里给明确提示而不是堆栈。
"""
import os
import re
import shutil
import subprocess
import sys

GODOT_CONSOLE = r"C:\Users\Administrator\.workbuddy\binaries\godot\Godot_v4.3-stable_win64_console.exe"
ROOT = r"D:\work\card_rogue"
TARGET = r"D:\work\卡牌肉鸽_独立版"

PRESET = "Windows Desktop"
EXE_NAME = "DuckCardsRogue.exe"
PCK_NAME = "DuckCardsRogue.pck"
PACK_REL = "dist/" + PCK_NAME
EXTRA = "release"

TEMPLATE_NAME = "windows_release_x86_64.exe"

OK = "✓"
BAD = "✗"

SUITES = [
    ("engine", "res://scripts/test_engine.gd"),
    ("reward", "res://scripts/test_reward.gd"),
    ("bgm", "res://scripts/test_bgm.gd"),
    ("smoke", "res://scripts/test_smoke.gd"),
]

# 输出里出现这些字样 = 该套件没全过（不能只信 exit code）
BAD_MARKS = (BAD, "SMOKE FAIL", "SCRIPT ERROR")


def die(msg):
    print("[中止] " + msg)
    sys.exit(1)


def step(n, s):
    print("")
    print("=" * 62)
    print("  %d) %s" % (n, s))
    print("=" * 62)


def mb(path):
    return os.path.getsize(path) / 1048576.0


def find_template():
    """找 Windows 导出模板（真导出用的那个，不是编辑器）。"""
    base = os.path.join(os.environ.get("APPDATA", ""), "Godot", "export_templates")
    if not os.path.isdir(base):
        return None
    found = []
    for root, _dirs, files in os.walk(base):
        if TEMPLATE_NAME in files:
            found.append(os.path.join(root, TEMPLATE_NAME))
    if not found:
        return None
    found.sort(key=os.path.getmtime, reverse=True)
    return found[0]


def run_suites(exe_path, cwd):
    """用给定 exe 跑四套测试。

    ⚠️ 判红靠**解析输出**，不看 exit code —— test_smoke.gd 失败也 exit 0。
    返回 (全通过?, 统计串, 失败明细列表)。
    """
    all_ok = True
    parts = []
    reasons = []
    for name, script in SUITES:
        try:
            r = subprocess.run([exe_path, "--headless", "--script", script],
                               cwd=cwd, capture_output=True, timeout=1800)
        except subprocess.TimeoutExpired:
            all_ok = False
            parts.append("%s:TIMEOUT" % name)
            reasons.append("%s 超时（>30 分钟）" % name)
            continue

        out = ((r.stdout or b"") + (r.stderr or b"")).decode("utf-8", "replace")
        hits = []
        for mark in BAD_MARKS:
            if mark in out:
                hits.append(mark)
        # smoke 的收尾是「结束：N 通过 / M 失败」
        m = re.search(r"结束：(\d+) 通过 / (\d+) 失败", out)
        if m and int(m.group(2)) != 0:
            hits.append("结束行 M=%s" % m.group(2))

        passed = (r.returncode == 0) and not hits
        n_ok = out.count(OK)
        if passed:
            if n_ok:
                parts.append("%s:%d%s" % (name, n_ok, OK))
            elif m:
                # smoke 不用 ✓ 号，条数在「结束：N 通过 / M 失败」里
                parts.append("%s:%s通过" % (name, m.group(1)))
            else:
                parts.append("%s:OK" % name)
            continue

        all_ok = False
        parts.append("%s:FAIL" % name)
        reasons.append("%s —— %s" % (name, ", ".join(hits) if hits else "exit=%d" % r.returncode))
        for line in out.splitlines():
            if any(mk in line for mk in BAD_MARKS):
                reasons.append("      " + line.strip()[:170])
    return all_ok, "  ".join(parts), reasons


def copy_file(src, dst, label):
    """复制并给出友好错误（游戏开着会锁 exe）。"""
    try:
        shutil.copy2(src, dst)
    except PermissionError:
        die("%s 正被占用 —— 先把正在运行的游戏关掉，再重新发布。" % label)
    print("  写入 %-22s %7.2f MB" % (label, mb(dst)))


def main():
    args = sys.argv[1:]
    do_verify = "--no-verify" not in args
    two_file = "--two-file" in args
    target = TARGET
    for a in args:
        if a.startswith("--target="):
            target = a.split("=", 1)[1].strip().strip('"')
    os.chdir(ROOT)

    mode = "双文件（exe + 旁挂 pck）" if two_file else "单文件（pck 内嵌）"
    print("发布模式：%s" % mode)
    print("目标目录：%s" % target)

    # ---------- 1) 回归 ----------
    step(1, "回归测试（四套全绿才允许发布）")
    if do_verify:
        rc = subprocess.call([sys.executable, "_verify.py"], cwd=ROOT)
        if rc != 0:
            die("回归没通过 —— 目标文件夹原封不动。")
    else:
        print("  （--no-verify：已跳过）")

    # ---------- 2) 导出 ----------
    if not os.path.exists(GODOT_CONSOLE):
        die("找不到 Godot：%s" % GODOT_CONSOLE)
    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)

    pck_src = None
    exe_src = None

    if two_file:
        step(2, "导出数据包 pck（--export-pack）+ 用真导出模板当 exe")
        pck_src = os.path.join(dist, PCK_NAME)
        if os.path.exists(pck_src):
            os.remove(pck_src)
        rc = subprocess.call([GODOT_CONSOLE, "--headless", "--path", ROOT,
                              "--export-pack", PRESET, PACK_REL], cwd=ROOT)
        if rc != 0:
            die("导出 pck 失败（Godot exit=%d）" % rc)
        if not os.path.exists(pck_src):
            die("导出后没找到 %s" % pck_src)
        print("  %s  %.2f MB" % (PCK_NAME, mb(pck_src)))

        exe_src = find_template()
        if exe_src is None:
            die("找不到 Windows 导出模板 %s（在 %%APPDATA%%\\Godot\\export_templates 下）"
                % TEMPLATE_NAME)
        print("  模板 %s  %.2f MB" % (exe_src, mb(exe_src)))
    else:
        step(2, "导出单文件 exe（--export-release，pck 内嵌）")
        exe_src = os.path.join(dist, EXE_NAME)
        if os.path.exists(exe_src):
            os.remove(exe_src)
        rc = subprocess.call([GODOT_CONSOLE, "--headless", "--path", ROOT,
                              "--export-release", PRESET, "dist/" + EXE_NAME], cwd=ROOT)
        if rc != 0:
            die("导出失败（Godot exit=%d）" % rc)
        if not os.path.exists(exe_src):
            die("导出后没找到 %s" % exe_src)
        print("  %s  %.2f MB（含内嵌 pck）" % (EXE_NAME, mb(exe_src)))

    # ---------- 3) 覆盖目标文件夹 ----------
    step(3, "替换目标文件夹  %s" % target)
    os.makedirs(target, exist_ok=True)
    exe_dst = os.path.join(target, EXE_NAME)
    pck_dst = os.path.join(target, PCK_NAME)

    copy_file(exe_src, exe_dst, EXE_NAME)

    if two_file:
        if os.path.exists(pck_dst):
            os.remove(pck_dst)
        copy_file(pck_src, pck_dst, PCK_NAME)
    elif os.path.exists(pck_dst):
        # 单文件模式：旧 pck 必须删掉，留着会让玩家以为缺文件、也会搅乱排查
        os.remove(pck_dst)
        print("  删除旧 %s（单文件模式不需要）" % PCK_NAME)

    src_extra = os.path.join(ROOT, EXTRA)
    if os.path.isdir(src_extra):
        for f in sorted(os.listdir(src_extra)):
            # 只复制玩家向附属文件（说明与自检脚本），开发文档留在仓库
            if f.endswith(".txt") or f.endswith(".bat"):
                copy_file(os.path.join(src_extra, f), os.path.join(target, f), f)

    # ---------- 4) 用发布产物自检 ----------
    step(4, "用发布产物复跑四套（解析输出，不看 exit code）")
    ok, summary, reasons = run_suites(exe_dst, target)
    print("  " + summary)
    if not ok:
        for r in reasons:
            print("  ! " + r)
        die("发布包自检失败 —— 上面列出的失败项要查。")

    print("")
    print("=" * 62)
    print("  发布完成 -> %s" % target)
    total = 0.0
    for f in sorted(os.listdir(target)):
        p = os.path.join(target, f)
        if os.path.isfile(p):
            total += mb(p)
            print("    %-28s %8.2f MB" % (f, mb(p)))
    print("    %-28s %8.2f MB" % ("合计", total))
    print("=" * 62)

    allowed = {EXE_NAME, PCK_NAME, "玩法说明.txt", "自检.bat"}
    if two_file:
        expect = allowed
    else:
        expect = allowed - {PCK_NAME}
    extra = [f for f in sorted(os.listdir(target))
             if os.path.isfile(os.path.join(target, f)) and f not in expect]
    if extra:
        print("  ⚠️ 目标目录有多余文件（历史遗留，考虑手工删掉）：")
        for f in extra:
            print("      " + f)


if __name__ == "__main__":
    main()
