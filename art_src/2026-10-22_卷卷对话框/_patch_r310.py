# -*- coding: utf-8 -*-
"""R310 接入：起点三选一改走「卷卷」对话场景（curtain.tscn）。
纪律：exact replace + assert count==1 + 保留原行尾（CRLF/LF）。"""
import io
import os
import sys

ROOT = r"E:/work/card_rogue"


def patch(rel, pairs):
    p = os.path.join(ROOT, rel)
    with open(p, "rb") as f:
        raw = f.read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8").replace("\r\n", "\n")
    for old, new in pairs:
        n = txt.count(old)
        assert n == 1, "%s: count=%d for %r" % (rel, n, old[:60])
        txt = txt.replace(old, new)
    out = txt.replace("\n", "\r\n") if crlf else txt
    with open(p, "wb") as f:
        f.write(out.encode("utf-8"))
    print("%-28s %s ok (crlf=%s)" % (rel, len(pairs), crlf))


patch("scripts/map_scene.gd", [(
    '''	# 起点三选一 / 待办卡组操作：先走它们，别停在地图上。
	# ⚠️ **截图核验模式要跳过**：否则刚开的一局带着「起点道具三选一」，
	# 会立刻把场景切走 → 截图截到的是别的界面（甚至什么都截不到）。
	if "--screenshot" not in OS.get_cmdline_user_args():
		if RunState.run_active and not RunState.relic_choice.is_empty():
			SceneFx.goto("res://scenes/relic_pick.tscn", true)
			return''',
    '''	# 起点事件 / 待办卡组操作：先走它们，别停在地图上。
	# R310：起点那「三件起始道具」不再用面板三选一（relic_pick），改由**卷卷**
	# 这位豚鼠吟游诗人开场对话（curtain.tscn）—— 三个选项就是这三件道具的名字。
	# ⚠️ **截图核验模式要跳过**：否则刚开的一局带着「起点事件」，
	# 会立刻把场景切走 → 截图截到的是别的界面（甚至什么都截不到）。
	if "--screenshot" not in OS.get_cmdline_user_args():
		if RunState.run_active and not RunState.relic_choice.is_empty():
			SceneFx.goto("res://scenes/curtain.tscn", true)
			return''',
)])

patch("scripts/battle_scene.gd", [(
    '''	if RunState.run_active and _run_next_layer > 0:
		RunState.advance_layer(_run_next_layer)
		SceneFx.goto("res://scenes/relic_pick.tscn")''',
    '''	if RunState.run_active and _run_next_layer > 0:
		RunState.advance_layer(_run_next_layer)
		# R310：进新层的起点 = 卷卷的对话事件（原「起始道具三选一」面板）
		SceneFx.goto("res://scenes/curtain.tscn")''',
)])
print("ALL DONE")
