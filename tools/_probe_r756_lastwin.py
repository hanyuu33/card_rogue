# -*- coding: utf-8 -*-
"""R756 临时探针：复现「第二层 Boss 通关但没有信物 → 胜利？」这条 run 结束路径，
确认 _show_over 之后待领奖励还剩多少、奖励窗会不会被自动打开。

用完即删（不提交）。
"""
import io
import sys

P = "scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()
crlf = "\r\n" in s
if crlf:
    s = s.replace("\r\n", "\n")

# ① 在 _show_over 的「整局结束 → 切结算页」出口前打一行探针
old1 = """	if _summary_pending:
		# R551：失败走「闭眼黑屏」转场，通关仍走默认斜切擦除。
		_goto_scene("res://scenes/run_summary.tscn", "eye" if _summary_fail else "wipe")
		return"""
new1 = """	if _summary_pending:
		print("[PROBE] run_end run_finished=%s boss=%s next_layer=%d pending=%d panel_open=%s"
				% [RunState.run_finished, _run_boss_win, _run_next_layer,
				RunState.pending_reward_count(),
				_reward_panel.is_open() if _reward_panel != null else "null"])
		# R551：失败走「闭眼黑屏」转场，通关仍走默认斜切擦除。
		_goto_scene("res://scenes/run_summary.tscn", "eye" if _summary_fail else "wipe")
		return"""
assert s.count(old1) == 1, "anchor1 %d" % s.count(old1)
s = s.replace(old1, new1)

# ② 演示参数：第二层 Boss 通关 + 雕像祝福（必掉工具）+ 工具栏被石头塞满
old2 = """	if "--runclear" in args and engine != null:"""
new2 = """	if "--lastwin2" in args and engine != null:
		# R756 探针：第二层 Boss 通关但信物不齐 → 走「胜利？」分支
		load_level(GameLevels.boss_level(GameLayers.LAYER_TWO))
		RunState.run_active = true
		RunState.current_layer = GameLayers.LAYER_TWO
		RunState.pending_node = {"type": "boss"}
		RunState.tool_drop_pledge = 3
		RunState.traps = [7012, 7012, 7012]
		engine._finish("胜利", "探针：第二层 Boss 未凑齐信物")
		queue_redraw()
	if "--runclear" in args and engine != null:"""
assert s.count(old2) == 1, "anchor2 %d" % s.count(old2)
s = s.replace(old2, new2)

if crlf:
    s = s.replace("\n", "\r\n")
io.open(P, "w", encoding="utf-8", newline="").write(s)
print("patched, crlf=%s" % crlf)
