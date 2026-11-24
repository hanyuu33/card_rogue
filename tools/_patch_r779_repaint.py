# -*- coding: utf-8 -*-
"""R779 第五段：工具说明面板的重绘时机（静止画面也要立刻出/收）。"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(path, edits, crlf):
    full = os.path.join(ROOT, path)
    text = open(full, "rb").read().decode("utf-8")
    nl = "\r\n" if crlf else "\n"
    for name, old, new in edits:
        o, n = old.replace("\n", nl), new.replace("\n", nl)
        c = text.count(o)
        if c != 1:
            print("!! %s [%s] 命中 %d" % (path, name, c))
            sys.exit(1)
        text = text.replace(o, n, 1)
        print("ok %s [%s]" % (path, name))
    open(full, "wb").write(text.encode("utf-8"))


CLEAR_OLD = """	_tool_tip_slot = -1          # R779：工具说明跟着一起收（否则会挂在屏幕上）
"""
CLEAR_NEW = """	# R779：工具说明跟着一起收；只在「本来挂着」时重绘一次 ——
	# 本函数每次鼠标移动都会走，无条件 queue_redraw 会把安卓的节流重绘打回每帧。
	var had_tool_tip: bool = _tool_tip_slot >= 0
	_tool_tip_slot = -1
	if had_tool_tip:
		queue_redraw()
"""

HOVER_OLD = """	if _hover_card == null:
		for ti in RunState.TRAP_SLOTS:
			if RunState.trap_at(ti) > 0 and _trap_slot_rect(ti).has_point(pos):
				_tool_tip_slot = ti
				break
"""
HOVER_NEW = """	if _hover_card == null:
		var want_tool_tip := -1
		for ti in RunState.TRAP_SLOTS:
			if RunState.trap_at(ti) > 0 and _trap_slot_rect(ti).has_point(pos):
				want_tool_tip = ti
				break
		if want_tool_tip != _tool_tip_slot:
			_tool_tip_slot = want_tool_tip
			# 进/出槽这一下立刻重绘：敌方回合画面是静止的，脉冲节流不一定在跑，
			# 只改状态不重绘会出现「鼠标压上去半天才弹」。
			queue_redraw()
"""

if __name__ == "__main__":
    run("scripts/battle_scene.gd", [("clear", CLEAR_OLD, CLEAR_NEW),
                                   ("hover", HOVER_OLD, HOVER_NEW)], crlf=True)
    print("R779 patch5 done")
