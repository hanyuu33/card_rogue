# -*- coding: utf-8 -*-
"""R779 第二段：只补 test_trap_input.gd（battle_scene 已在第一段落好）。"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tabs(s):
    out = []
    for line in s.split("\n"):
        stripped = line.lstrip(" ")
        n = len(line) - len(stripped)
        out.append("\t" * (n // 4) + stripped)
    return "\n".join(out)


RESET_OLD = (
    "\t# R752：使用上膛 / 选卡型工具的残留也一并清掉（否则上一例的上膛会漏到下一例）\n"
    "\t_sc._tool_use_arm = -1\n"
    "\t_sc._tool_use_until = 0\n"
    "\t_sc._tool_pick_slot = -1\n"
)
RESET_NEW = RESET_OLD + "\t_sc._tool_tip_slot = -1     # R779：工具说明面板的悬停态\n"

ANCHOR_OLD = "\t# ---- ⑧e R754：石头（7012）要拖到**敌方单位**身上才砸得下去 ----\n"

BLOCK = tabs("""    # ---- ⑧f R779：工具栏能**看到效果描述**（电脑悬浮 / 安卓点一下上膛） ----
    # 用户口径：「工具栏看不到工具的效果描述」→ 电脑端悬浮、安卓端点击都要能看到。
    RunState.traps = [-1, -1, -1]
    RunState.gain_trap(7008)          # 野性图腾：使用型（ally_atk）
    _sc._tool_use_arm = -1
    _sc._tool_use_until = 0
    _sc._tool_tip_slot = -1
    _sc._on_hover(s0)
    check(_sc._tool_tip_slot == 0, "工具说明：鼠标悬停在槽上就认得这个槽（野性图腾）")
    check(_sc._tool_tip_anchor_slot() == 0, "工具说明：电脑端悬浮即可显示（不必先点）")
    var tip_td: TrapData = TrapRepo.load_json().get_trap(7008)
    check(tip_td != null and tip_td.trap_name != "" and tip_td.desc != "",
            "工具说明：图腾有可显示的名字与效果描述")
    _sc._on_hover(Vector2(640.0, 40.0))
    check(_sc._tool_tip_slot == -1 and _sc._tool_tip_anchor_slot() == -1,
            "工具说明：鼠标移开就收起")
    # 安卓：没有 MouseMotion，点一下（上膛）也必须看得到。
    _feed(_mb(s0, true))
    _feed(_mb(s0, false))
    check(_sc._tool_use_arm == 0, "工具说明：点一下照样上膛（安卓路径）")
    check(_sc._tool_tip_anchor_slot() == 0, "工具说明：安卓点一下也能看到（上膛即显示）")
    # 上膛过期 → 面板跟着收起，不留残影。
    _sc._tool_use_until = Time.get_ticks_msec() - 1
    check(_sc._tool_tip_anchor_slot() == -1, "工具说明：上膛过期后面板收起")
    _sc._tool_use_arm = -1
    _sc._tool_use_until = 0
    _sc._tool_tip_slot = -1

""") + ANCHOR_OLD

path = os.path.join(ROOT, "scripts/test_trap_input.gd")
text = open(path, "rb").read().decode("utf-8")
for name, old, new in [("reset", RESET_OLD, RESET_NEW), ("case", ANCHOR_OLD, BLOCK)]:
    n = text.count(old)
    if n != 1:
        print("!! [%s] 命中 %d 次" % (name, n))
        sys.exit(1)
    text = text.replace(old, new, 1)
    print("ok [%s]" % name)
open(path, "wb").write(text.encode("utf-8"))
print("R779 test patch done")
