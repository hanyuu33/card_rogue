# -*- coding: utf-8 -*-
"""R752 补丁：battle_scene 演示入口 —— 上膛罩层 / 选卡页出图。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/battle_scene.gd", [
    (
        """	if _shot_pending and "--r331hidden" in _demo_args \\
			and _demo_frame == _shot_frame - 40 and engine != null:
""",
        """	if _shot_pending and "--toolarm" in _demo_args and _demo_frame == 60:
		# R752 出图：「使用」上膛罩层的实况（双击的第一下之后长什么样）。
		# 出图：`battle.tscn -- --screenshot --tooldemo --newtools --toolarm --level 0 --shotframe 200`
		# 有效期给足（10 分钟），否则跑到截图那一帧时罩层已经自己收起来了。
		_tool_use_arm = 0
		_tool_use_until = Time.get_ticks_msec() + 600000
		queue_redraw()
	if _shot_pending and "--toolpick" in _demo_args and _demo_frame == 60 and engine != null:
		# R752 出图：选卡型工具的选卡页（万能牌 7009 / 神秘牌 7011）—— 核验标题与说明排版。
		# 出图：`battle.tscn -- --screenshot --toolpick 7011 --level 0 --shotframe 220`
		var tp_demo := 7009
		for tp_i in _demo_args.size():
			if _demo_args[tp_i] == "--toolpick" and tp_i + 1 < _demo_args.size():
				tp_demo = int(str(_demo_args[tp_i + 1]))
		if engine.begin_tool_pick(tp_demo):
			RunState.traps = [tp_demo, 7005, 7006]
			RunState.run_active = true
			_tool_pick_slot = 0        # 出图用：让摘槽路径与真实流程一致
			queue_redraw()
	if _shot_pending and "--r331hidden" in _demo_args \\
			and _demo_frame == _shot_frame - 40 and engine != null:
""",
    ),
])

print("OK")
