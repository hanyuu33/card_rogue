# -*- coding: utf-8 -*-
"""卡牌肉鸽 · 发布独立版。

用法：
    python _release.py                  回归 → 导出 → 覆盖目标 → 用发布产物自检（测试版）
    python _release.py --release        构建**发布版**（职业·难度渐进解锁，见 unlock_system.gd）
    python _release.py --demo           构建**试玩版**（只开森林精魄/暗影刺客、各 60 张、难度≤1、
                                        剧情不解锁、二层 Boss 即「胜利？」—— 见 game_build.gd）
    python _release.py --no-verify      跳过回归（已经手工跑过时）
    python _release.py --with-content   测试版也带 content/（专门验证覆盖层时用）
    python _release.py --two-file       测试版强制双文件（调试用，一般不传）
    python _release.py --target=目录    写到别的目录（验证用，不碰正式发布目录）

════════════════════════════════════════════════════════════════════
两种形态（R791 定稿，别再混用）
════════════════════════════════════════════════════════════════════
测试版（默认，`python _release.py`）
    → 卡牌肉鸽_测试版/
    → **单文件 exe**（pck 内嵌，preset.0 `embed_pck=true`），**不带 content/**
    一个文件丢给测试者就能跑，不需要旁挂 pck，也不会因为覆盖层而出现
    「他改了 JSON 我没改」的口径分歧。这是给内部与试玩用的完整包。

发布版（`--release`）
    → 卡牌肉鸽_独立版/
    → **exe + pck + content/**（`--export-release` + 预设 `embed_pck=false` 自动分离）
    Steam 的更新粒度是文件：改一句文案只动 content/ 里那个 JSON，
    换一张图只动 content/assets 里那张 PNG，引擎与基线 pck 不动。
    见 release/steam_roadmap.md §2.1。

两种形态**必须分目录**：同名目录里同时躺着 Quackill.exe（单文件）与
Quackill_release.exe + pck，会让人误点、也会让「缺 pck」的排查线索变乱。

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
  * 单文件模式下，目标目录里留着的旧 `Quackill.pck`（以及改名前的
    `DuckCardsRogue.pck`）**必须删掉** ——
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
# 双机通用：以脚本自身位置推导工程根目录（D:\work 或 E:\work 都一样），别再写死盘符。
ROOT = os.path.dirname(os.path.abspath(__file__))
# R791：两种形态分目录 —— 发布版进 Steam depot，测试版单独一份完整包。
TARGET_RELEASE = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_独立版")
TARGET_TEST = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_测试版")
# R817：试玩版单独一份目录 —— 它和发布版**同名文件不同内容**（卡池裁过），
# 混在一个目录里会被 Steam depot / 手动拷贝弄反，所以物理隔开。
TARGET_DEMO = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_试玩版")
TARGET = TARGET_RELEASE   # 兼容旧引用；main() 会按形态重选

PRESET = "Windows Desktop"
PRESET_RELEASE = "Windows Desktop Release"   # R550：发布版（custom_features=cardrogue_release）
PRESET_DEMO = "Windows Desktop Demo"         # R817：试玩版（custom_features=cardrogue_demo）
EXE_NAME = "Quackill.exe"
PCK_NAME = "Quackill.pck"
EXTRA = "release"

# R789：热更内容 —— 这些 JSON 以**松散文件**随包放在 content/ 下，
# 运行时优先于 pck 内基线（见 scripts/data_paths.gd）。
# Steam 的更新粒度是**文件**：改一句文案 / 调一张卡，玩家只重下几十 KB，
# 而不是整个 277MB 的 exe。基线仍留在 pck 里，content/ 缺失或被删就自动回落。
CONTENT_FILES = ["cards.json", "relics.json", "stories.json", "traps.json"]
CONTENT_DIRS = ["i18n"]
CONTENT_DST = "content"

# R791 分离形态判据：模板 exe 约 84MB，内嵌 pck 后 277MB。体积比魔数好判。
EMBEDDED_MAX_MB = 120.0
PCK_MIN_MB = 100.0

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


def dir_size(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            total += os.path.getsize(os.path.join(root, f))
    return total / 1048576.0


def sync_content(target):
    """把热更 JSON 平铺到 content/（整份文件，不是增量补丁）。

    `i18n/` 只带 JSON：验证脚本与文档不进包。
    """
    dst_root = os.path.join(target, CONTENT_DST)
    if os.path.isdir(dst_root):
        shutil.rmtree(dst_root)
    os.makedirs(dst_root, exist_ok=True)
    count = 0
    for name in CONTENT_FILES:
        src = os.path.join(ROOT, name)
        if not os.path.isfile(src):
            die("热更内容缺失：%s" % name)
        shutil.copy2(src, os.path.join(dst_root, name))
        count += 1
    for name in CONTENT_DIRS:
        src_dir = os.path.join(ROOT, name)
        dst_dir = os.path.join(dst_root, name)
        if not os.path.isdir(src_dir):
            die("热更目录缺失：%s" % name)
        os.makedirs(dst_dir, exist_ok=True)
        for f in sorted(os.listdir(src_dir)):
            if not f.endswith(".json"):
                continue
            shutil.copy2(os.path.join(src_dir, f), os.path.join(dst_dir, f))
            count += 1
    print("  热更内容 %-20s %7.2f MB（%d 个 JSON，更新时只下变化的文件）"
          % (CONTENT_DST + "/", dir_size(dst_root), count))


def assert_split(exe_path, pck_path):
    """发布版必须是分离形态，否则热更等于没做。

    判据用体积而不是在 277MB 里扫 GDPC 魔数：
    模板 exe 约 84MB，一旦 pck 内嵌就变成 277MB，差一个数量级，够判。
    """
    exe_mb = mb(exe_path)
    pck_mb = mb(pck_path)
    if exe_mb > EMBEDDED_MAX_MB:
        die("%s 有 %.1f MB —— pck 还嵌在 exe 里。发布版必须分离；"
            "确认走的是 --export-release，且预设 embed_pck=false。"
            % (os.path.basename(exe_path), exe_mb))
    if pck_mb < PCK_MIN_MB:
        die("%s 只有 %.1f MB —— 内容明显不完整，导出可能中途失败了。"
            % (os.path.basename(pck_path), pck_mb))
    print("  分离校验：exe %.2f MB + pck %.2f MB（内嵌形态会是 %.0f MB 的单文件）"
          % (exe_mb, pck_mb, exe_mb + pck_mb))


def gdext_dlls():
    """从 addons/*/*.gdextension 取 Windows x86_64 release 需要的 dll。

    实测（R791）：Godot 导出时把 GDExtension 的库和 dependency **平铺**到 exe
    同目录（`libgodotsteam.windows.template_release.x86_64.dll`、`steam_api64.dll`），
    不是放进 addons/ 子目录 —— 所以这里也平铺复制。
    缺了不会崩，但 Steam 初始化直接失败、所有成就静默跳过，属于「看不见的坏」。
    """
    names = []
    addons = os.path.join(ROOT, "addons")
    if not os.path.isdir(addons):
        return names
    pat = re.compile(r"^\s*windows\.(?:release\.x86_64|x86_64)\s*=\s*(.+)$", re.M)
    for root, _dirs, files in os.walk(addons):
        for f in files:
            if not f.endswith(".gdextension"):
                continue
            with open(os.path.join(root, f), encoding="utf-8") as fh:
                txt = fh.read()
            for m in pat.finditer(txt):
                for p in re.findall(r'res://[^"}\s,]+', m.group(1)):
                    name = p.rsplit("/", 1)[-1]
                    if name not in names:
                        names.append(name)
    return names


def run_suites(exe_path, cwd, require_steam=False):
    """用给定 exe 跑四套测试。

    ⚠️ 判红靠**解析输出**，不看 exit code —— test_smoke.gd 失败也 exit 0。
    require_steam：发布版专用。缺 GDExtension 时游戏只会打一行 warning 然后
    跳过所有成就，套件本身仍是绿的 —— 这种「静默失效」必须在这里判死。
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
        if require_steam and "GDExtension dynamic library not found" in out:
            hits.append("GDExtension dll 缺失")
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
    # R550：`--release` 构建**发布版**（职业·难度渐进解锁），默认构建**测试版**（全解锁）。
    # 通过 global 改模块级 PRESET / EXE_NAME / PCK_NAME，其余代码照旧。
    global PRESET, EXE_NAME, PCK_NAME
    release = "--release" in args
    # R817：试玩版与发布版互斥 —— 两个都传是笔误，别猜，直接停。
    demo = "--demo" in args
    if release and demo:
        die("--release 与 --demo 不能同时用：它们要覆盖同一个目标目录。")
    if release:
        PRESET = PRESET_RELEASE
        sfx = "_release"
        EXE_NAME = "Quackill" + sfx + ".exe"
        PCK_NAME = "Quackill" + sfx + ".pck"
    elif demo:
        PRESET = PRESET_DEMO
        sfx = "_demo"
        EXE_NAME = "Quackill" + sfx + ".exe"
        PCK_NAME = "Quackill" + sfx + ".pck"

    # R791：形态由构建类型决定，不再靠人记得加参数。
    #   发布版 = 必须分离（exe + pck + content/），否则 Steam 每次更新都近似全量；
    #   测试版 = 旧的完整单文件包，一个 exe 丢出去就能跑。
    # R817：试玩版跟发布版同规格 —— 双文件 + 随包 content/。
    # 这不是为了 Steam 增量（试玩包不上 depot），而是为了**试玩版的修复能热更**：
    # 「后续修复要同步到试玩」这条口径落到技术上，就是改 content/ 里的几张 json，
    # 而不是每次让玩家重下 240MB。
    two_file = True if (release or demo) else ("--two-file" in args)
    with_content = release or demo or ("--with-content" in args)

    target = TARGET_RELEASE if release else (TARGET_DEMO if demo else TARGET_TEST)
    for a in args:
        if a.startswith("--target="):
            target = a.split("=", 1)[1].strip().strip('"')
    os.chdir(ROOT)

    mode = "双文件（exe + 旁挂 pck）" if two_file else "单文件（pck 内嵌）"
    if release:
        print("发布模式：%s  |  构建：发布版（Steam 分发）" % mode)
        print("热更层：随包 content/ —— 改文案 / 换图只下变化的小文件")
    elif demo:
        print("发布模式：%s  |  构建：试玩版（Steam 试玩 / 展会）" % mode)
        print("内容口径：森林精魄 + 暗影刺客各 60 张 / 难度 ≤ 1 / 二层 Boss 即结算")
        print("热更层：随包 content/ —— 后续**修复**走这里同步到试玩版")
    else:
        print("发布模式：%s  |  构建：测试版（内部 / 试玩）" % mode)
        print("热更层：%s" % ("随包 content/（显式指定）" if with_content
                            else "不带 —— 完整包，单文件即可运行"))
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
        # R791：不再用「--export-pack + 裸模板」——那条路只产数据包，
        # GDExtension 的 dll（godotsteam / steam_api64）不会被复制，
        # 装机后成就直接失效（实测报 "GDExtension dynamic library not found"）。
        # 预设已是 embed_pck=false，直接 --export-release 就能拿到
        # exe + pck + 平铺 dll，让引擎自己处理附属文件。
        step(2, "导出分离包 exe + pck（--export-release，preset embed_pck=false）")
        exe_src = os.path.join(dist, EXE_NAME)
        pck_src = os.path.join(dist, PCK_NAME)
        for f in (exe_src, pck_src):
            if os.path.exists(f):
                os.remove(f)
        rc = subprocess.call([GODOT_CONSOLE, "--headless", "--path", ROOT,
                              "--export-release", PRESET, "dist/" + EXE_NAME], cwd=ROOT)
        if rc != 0:
            die("导出失败（Godot exit=%d）" % rc)
        for f in (exe_src, pck_src):
            if not os.path.exists(f):
                die("导出后没找到 %s —— 检查 preset 的 embed_pck 是否为 false" % f)
        print("  %s  %.2f MB" % (EXE_NAME, mb(exe_src)))
        print("  %s  %.2f MB" % (PCK_NAME, mb(pck_src)))
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

    # 热更内容：content/ 必须与 exe 同级，运行时优先于 pck 基线。
    # 发布版必带；测试版是完整包，默认不带（留着会悄悄覆盖 pck 基线，让
    # 「我这儿明明改了」变成排查陷阱）。
    if with_content:
        sync_content(target)
    else:
        stale = os.path.join(target, CONTENT_DST)
        if os.path.isdir(stale):
            shutil.rmtree(stale)
            print("  删除旧 content/（本形态不带热更层）")

    if two_file:
        assert_split(exe_dst, pck_dst)
        dlls = gdext_dlls()
        if not dlls:
            die("addons/*.gdextension 里没有 Windows x86_64 的 dll 声明 —— "
                "发布版必须带 Steam 扩展，否则成就全失效。")
        for name in dlls:
            src = os.path.join(dist, name)
            if not os.path.isfile(src):
                die("导出后没找到 GDExtension dll：%s（Steam 成就依赖它）" % name)
            copy_file(src, os.path.join(target, name), name)

    # ---------- 4) 用发布产物自检 ----------
    step(4, "用发布产物复跑四套（解析输出，不看 exit code）")
    ok, summary, reasons = run_suites(exe_dst, target, require_steam=two_file)
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
        elif os.path.isdir(p) and f == CONTENT_DST:
            sz = dir_size(p)
            total += sz
            print("    %-28s %8.2f MB  (热更层)" % (f + "/", sz))
    print("    %-28s %8.2f MB" % ("合计", total))
    print("=" * 62)

    allowed = {EXE_NAME, PCK_NAME, "玩法说明.txt", "自检.bat"}
    if two_file:
        expect = allowed | set(gdext_dlls())
    else:
        expect = allowed - {PCK_NAME}
    extra = [f for f in sorted(os.listdir(target))
             if os.path.isfile(os.path.join(target, f)) and f not in expect]
    if extra:
        print("  ⚠️ 目标目录有多余文件（历史遗留的另一种形态 / 改名前的包，手工删掉）：")
        for f in extra:
            print("      " + f)
        if release and "Quackill.exe" in extra:
            print("      ↑ 这是测试版单文件包，不该留在发布版目录里 —— 玩家会点错。")


if __name__ == "__main__":
    main()
