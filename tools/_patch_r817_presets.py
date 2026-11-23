# -*- coding: utf-8 -*-
"""R817：补上试玩版导出预设（Windows / Android）+ 打包脚本的 demo 入口。

三个文件都是 LF，可直接按文本处理：
  - export_presets.cfg : 追加 preset.4 / preset.5（custom_features=cardrogue_demo）
  - _release.py        : --demo → PRESET_DEMO / 目标目录 卡牌肉鸽_试玩版 / 强制双文件 + content
  - release/build_apk.sh : 第二参数 demo → Android Demo 预设
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rep(txt, old, new, path, tag):
    n = txt.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次（应为 1）：%r" % (tag, n, old[:70])
    return txt.replace(old, new)


# ── ① export_presets.cfg ────────────────────────────────────────────────────
p = os.path.join(ROOT, "export_presets.cfg")
txt = io.open(p, encoding="utf-8", newline="").read()
assert "[preset.4]" not in txt, "preset.4 已存在，重复执行？"

i2 = txt.index("[preset.2]\n")
i3 = txt.index("[preset.3]\n")
blk_win = txt[i2:i3]          # Windows Desktop Release
blk_apk = txt[i3:]            # Android Release（文件最后一个块）

demo_win = (blk_win
            .replace("[preset.2.options]", "[preset.4.options]")
            .replace("[preset.2]", "[preset.4]")
            .replace('name="Windows Desktop Release"', 'name="Windows Desktop Demo"')
            .replace('custom_features="cardrogue_release"', 'custom_features="cardrogue_demo"')
            .replace('export_path="dist/Quackill_release.exe"', 'export_path="dist/Quackill_demo.exe"'))

demo_apk = (blk_apk
            .replace("[preset.3.options]", "[preset.5.options]")
            .replace("[preset.3]", "[preset.5]")
            .replace('name="Android Release"', 'name="Android Demo"')
            .replace('custom_features="cardrogue_release"', 'custom_features="cardrogue_demo"')
            .replace('export_path="dist/Quackill_release.apk"', 'export_path="dist/Quackill_demo.apk"'))

# 两个块都确认替换到位（防止 name / 路径串味）
for blk, head, path_ in ((demo_win, "Windows Desktop Demo", "dist/Quackill_demo.exe"),
                         (demo_apk, "Android Demo", "dist/Quackill_demo.apk")):
    assert 'name="%s"' % head in blk, "预设名没替换成功：%s" % head
    assert 'custom_features="cardrogue_demo"' in blk, "features 没替换成功：%s" % head
    assert 'export_path="%s"' % path_ in blk, "导出路径没替换成功：%s" % head
    assert "cardrogue_release" not in blk, "残留 release 特征：%s" % head

new = (txt.rstrip("\n") + "\n\n"
       + demo_win.strip("\n") + "\n\n"
       + demo_apk.strip("\n") + "\n")
assert new.count('custom_features="cardrogue_demo"') == 2
assert new.count("[preset.4]") == 1 and new.count("[preset.5]") == 1
io.open(p, "w", encoding="utf-8", newline="").write(new)
print("export_presets.cfg: +preset.4(win demo) +preset.5(apk demo)")

# ── ② _release.py ───────────────────────────────────────────────────────────
p = os.path.join(ROOT, "_release.py")
txt = io.open(p, encoding="utf-8", newline="").read()
assert "TARGET_DEMO" not in txt, "_release.py 已打过补丁，重复执行？"

txt = rep(txt,
          '    python _release.py --release        构建**发布版**（职业·难度渐进解锁，见 unlock_system.gd）\n',
          '    python _release.py --release        构建**发布版**（职业·难度渐进解锁，见 unlock_system.gd）\n'
          '    python _release.py --demo           构建**试玩版**（只开森林精魄/暗影刺客、各 60 张、难度≤1、\n'
          '                                        剧情不解锁、二层 Boss 即「胜利？」—— 见 game_build.gd）\n',
          p, "docstring")

txt = rep(txt,
          'TARGET_TEST = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_测试版")\n',
          'TARGET_TEST = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_测试版")\n'
          '# R817：试玩版单独一份目录 —— 它和发布版**同名文件不同内容**（卡池裁过），\n'
          '# 混在一个目录里会被 Steam depot / 手动拷贝弄反，所以物理隔开。\n'
          'TARGET_DEMO = os.path.join(os.path.dirname(ROOT), "卡牌肉鸽_试玩版")\n',
          p, "TARGET_DEMO")

txt = rep(txt,
          'PRESET_RELEASE = "Windows Desktop Release"   # R550：发布版（custom_features=cardrogue_release）\n',
          'PRESET_RELEASE = "Windows Desktop Release"   # R550：发布版（custom_features=cardrogue_release）\n'
          'PRESET_DEMO = "Windows Desktop Demo"         # R817：试玩版（custom_features=cardrogue_demo）\n',
          p, "PRESET_DEMO")

txt = rep(txt,
          '    global PRESET, EXE_NAME, PCK_NAME\n'
          '    release = "--release" in args\n'
          '    if release:\n'
          '        PRESET = PRESET_RELEASE\n'
          '        sfx = "_release"\n'
          '        EXE_NAME = "Quackill" + sfx + ".exe"\n'
          '        PCK_NAME = "Quackill" + sfx + ".pck"\n',
          '    global PRESET, EXE_NAME, PCK_NAME\n'
          '    release = "--release" in args\n'
          '    # R817：试玩版与发布版互斥 —— 两个都传是笔误，别猜，直接停。\n'
          '    demo = "--demo" in args\n'
          '    if release and demo:\n'
          '        die("--release 与 --demo 不能同时用：它们要覆盖同一个目标目录。")\n'
          '    if release:\n'
          '        PRESET = PRESET_RELEASE\n'
          '        sfx = "_release"\n'
          '        EXE_NAME = "Quackill" + sfx + ".exe"\n'
          '        PCK_NAME = "Quackill" + sfx + ".pck"\n'
          '    elif demo:\n'
          '        PRESET = PRESET_DEMO\n'
          '        sfx = "_demo"\n'
          '        EXE_NAME = "Quackill" + sfx + ".exe"\n'
          '        PCK_NAME = "Quackill" + sfx + ".pck"\n',
          p, "main preset")

txt = rep(txt,
          '    two_file = True if release else ("--two-file" in args)\n'
          '    with_content = release or ("--with-content" in args)\n'
          '\n'
          '    target = TARGET_RELEASE if release else TARGET_TEST\n',
          '    # R817：试玩版跟发布版同规格 —— 双文件 + 随包 content/。\n'
          '    # 这不是为了 Steam 增量（试玩包不上 depot），而是为了**试玩版的修复能热更**：\n'
          '    # 「后续修复要同步到试玩」这条口径落到技术上，就是改 content/ 里的几张 json，\n'
          '    # 而不是每次让玩家重下 240MB。\n'
          '    two_file = True if (release or demo) else ("--two-file" in args)\n'
          '    with_content = release or demo or ("--with-content" in args)\n'
          '\n'
          '    target = TARGET_RELEASE if release else (TARGET_DEMO if demo else TARGET_TEST)\n',
          p, "two_file/target")

txt = rep(txt,
          '    if release:\n'
          '        print("发布模式：%s  |  构建：发布版（Steam 分发）" % mode)\n'
          '        print("热更层：随包 content/ —— 改文案 / 换图只下变化的小文件")\n'
          '    else:\n',
          '    if release:\n'
          '        print("发布模式：%s  |  构建：发布版（Steam 分发）" % mode)\n'
          '        print("热更层：随包 content/ —— 改文案 / 换图只下变化的小文件")\n'
          '    elif demo:\n'
          '        print("发布模式：%s  |  构建：试玩版（Steam 试玩 / 展会）" % mode)\n'
          '        print("内容口径：森林精魄 + 暗影刺客各 60 张 / 难度 ≤ 1 / 二层 Boss 即结算")\n'
          '        print("热更层：随包 content/ —— 后续**修复**走这里同步到试玩版")\n'
          '    else:\n',
          p, "print branch")

io.open(p, "w", encoding="utf-8", newline="").write(txt)
print("_release.py: --demo 入口已加")

# ── ③ release/build_apk.sh ─────────────────────────────────────────────────
p = os.path.join(ROOT, "release", "build_apk.sh")
txt = io.open(p, encoding="utf-8", newline="").read()
assert 'MODE=demo' not in txt, "build_apk.sh 已打过补丁，重复执行？"

txt = rep(txt,
          'case "$MODE" in\n'
          '  release|Release) MODE=release ;;\n'
          '  *) MODE=test ;;\n'
          'esac\n'
          'PRESET="Android"\n'
          '[ "$MODE" = "release" ] && PRESET="Android Release"\n'
          'SFX=""\n'
          '[ "$MODE" = "release" ] && SFX="_release"\n',
          'case "$MODE" in\n'
          '  release|Release) MODE=release ;;\n'
          '  demo|Demo) MODE=demo ;;          # R817：试玩版（只开两职业、各 60 张、难度≤1）\n'
          '  *) MODE=test ;;\n'
          'esac\n'
          'PRESET="Android"\n'
          '[ "$MODE" = "release" ] && PRESET="Android Release"\n'
          '[ "$MODE" = "demo" ] && PRESET="Android Demo"\n'
          'SFX=""\n'
          '[ "$MODE" = "release" ] && SFX="_release"\n'
          '[ "$MODE" = "demo" ] && SFX="_demo"\n',
          p, "apk preset")

io.open(p, "w", encoding="utf-8", newline="").write(txt)
print("release/build_apk.sh: demo 模式已加")
print("OK")
