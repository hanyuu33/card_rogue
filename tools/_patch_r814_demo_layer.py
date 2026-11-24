# -*- coding: utf-8 -*-
"""R814 试玩版：二层 Boss 后不进第三层（CRLF 文件，走 python 保行尾）。"""
import io

P = "E:/work/card_rogue/scripts/battle_scene.gd"
s = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in s

anchor = (
    "\t\t\t\tif _run_next_layer == GameLayers.LAYER_THREE \\\r\n"
    "\t\t\t\t\t\tand not RunState.can_enter_third_layer():\r\n"
    "\t\t\t\t\t_run_next_layer = 0\r\n"
)
assert s.count(anchor) == 1, s.count(anchor)

block = (
    "\t\t\t\t# R814 试玩版：内容只到第二层 —— 打完二层 Boss 直接收尾，不进第三层。\r\n"
    "\t\t\t\t# 结算标题不用另写：`run_summary_scene._draw_head()` 的判据是「该局没停在\r\n"
    "\t\t\t\t# 第三层」→ 自动显示「胜利？」，与「信物不齐」那条路共用一个口径。\r\n"
    "\t\t\t\t# ⚠️ 必须放在算 `_run_next_layer` 之后、清 `pending_rewards` 之前：\r\n"
    "\t\t\t\t#    下面那段 R756 的判据读的就是它（进结算页不该还挂着「待领 N 件」）。\r\n"
    "\t\t\t\tif GameBuild.is_demo() and _run_next_layer == GameLayers.LAYER_THREE:\r\n"
    "\t\t\t\t\t_run_next_layer = 0\r\n"
)

s = s.replace(anchor, anchor + block)
io.open(P, "w", encoding="utf-8", newline="").write(s)
print("battle_scene patched, CRLF =", s.count("\r\n"), "LF-only =", s.count("\n") - s.count("\r\n"))
