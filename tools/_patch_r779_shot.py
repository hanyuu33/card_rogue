# -*- coding: utf-8 -*-
"""R779 第三段：给 --totemtip 出图参数（核验使用型双按钮 + 长描述折行）。CRLF 二进制处理。"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

OLD = '\t\tif args[i] == "--shotms" and i + 1 < args.size():\n'
NEW = (
    '\t\tif args[i] == "--totemtip":\n'
    '\t\t\t# R779 出图：工具栏塞野性图腾并**直接上膛**，核验「使用 / 丢弃」双按钮\n'
    '\t\t\t# 与槽左侧的完整效果说明面板（图腾描述较长 → 折两行）。\n'
    '\t\t\t# 出图：`battle.tscn -- --screenshot --totemtip --level 0 --shotframe 200`\n'
    '\t\t\t# ⚠️ 不能挂在 `--tooldemo` 下面：那个参数被 `reward_panel` 认领，\n'
    '\t\t\t#    会弹出「获得奖励」面板把工具栏整个盖住（R754 踩过，R779 复现一次）。\n'
    '\t\t\tRunState.traps = [7008, 7005, 7006]\n'
    '\t\t\tRunState.run_active = true\n'
    '\t\t\t_tool_use_arm = 0\n'
    '\t\t\t_tool_use_until = Time.get_ticks_msec() + 600000\n'
    + OLD
)

path = os.path.join(ROOT, "scripts/battle_scene.gd")
raw = open(path, "rb").read().decode("utf-8")
old_r = OLD.replace("\n", "\r\n")
new_r = NEW.replace("\n", "\r\n")
n = raw.count(old_r)
if n != 1:
    print("!! 锚点命中 %d 次" % n)
    sys.exit(1)
open(path, "wb").write(raw.replace(old_r, new_r, 1).encode("utf-8"))
print("ok totemtip")
