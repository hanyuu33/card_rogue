# -*- coding: utf-8 -*-
"""R779 第四段：① 进左栏要收起工具说明（否则面板一直挂着）；② 安卓用例改走真实触摸序列。"""
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


BAR_OLD = """	if _info_panel_rect().has_point(pos):
		_hover_mention = {}
"""
BAR_NEW = """	if _info_panel_rect().has_point(pos):
		_hover_mention = {}
		_tool_tip_slot = -1   # R779：进左栏 = 离开工具槽，说明面板跟着收（这里没走 _clear_hover_state）
"""

TOUCH_OLD = """	# 安卓：没有 MouseMotion，点一下（上膛）也必须看得到。
	_feed(_mb(s0, true))
	_feed(_mb(s0, false))
"""
TOUCH_NEW = """	# 安卓：没有 MouseMotion，点一下（上膛）也必须看得到。
	# 真机顺序与 ⑧ 用例一致：原生 ScreenTouch 先到，模拟出来的左键随后到。
	_feed(_touch(s0, true))
	_feed(_mb(s0, true))
	_feed(_touch(s0, false))
	_feed(_mb(s0, false))
"""

# 触摸松手后 _say 会写状态栏，但说明面板只看上膛态 → 这里额外断言「没有 hover 也显示」
TOUCH_OLD2 = """	check(_sc._tool_tip_anchor_slot() == 0, "工具说明：安卓点一下也能看到（上膛即显示）")
"""
TOUCH_NEW2 = """	check(_sc._tool_tip_slot == -1 and _sc._tool_tip_anchor_slot() == 0,
			"工具说明：安卓点一下也能看到（上膛即显示，不靠 hover）")
"""

if __name__ == "__main__":
    run("scripts/battle_scene.gd", [("infobar", BAR_OLD, BAR_NEW)], crlf=True)
    run("scripts/test_trap_input.gd", [("touch", TOUCH_OLD, TOUCH_NEW),
                                      ("assert", TOUCH_OLD2, TOUCH_NEW2)], crlf=False)
    print("R779 patch4 done")
