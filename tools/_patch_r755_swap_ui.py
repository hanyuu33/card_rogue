# -*- coding: utf-8 -*-
"""R755：奖励页「工具栏已满 → 换下一件」重做成一块正式的子面板（换装条）。

店长口径：「在奖励界面领取工具时，如果当前栏位已满，需要提供让用户换掉一个现有工具的
UI（也可以取消）」—— 原来只有三张素色方块、没有取消。现在：
  · 羊皮纸底 + 金边的子面板，标题行带金色交换图标（assets/ui/ui_tool_swap.png）
  · 右上角「取消」= 回列表（条目留在待领队列，不丢）
  · 三张旧工具卡：图标 + 名字 + 「丢掉它」，悬停转红边
"""
import io

ROOT = "E:/work/card_rogue/"
P = ROOT + "scripts/reward_panel.gd"

OLD_CONST = """const TOOL_SWAP_H := 100.0
const TOOL_SWAP_W := 120.0
const TOOL_SWAP_GAP := 16.0
"""

NEW_CONST = """const TOOL_SWAP_H := 116.0
const TOOL_SWAP_W := 132.0
const TOOL_SWAP_GAP := 14.0
## R755：换装条内部三段 —— 标题行（图标 + 文案 + 取消键）/ 工具卡行 / 底部留白。
const TOOL_SWAP_HEAD_H := 40.0
const TOOL_SWAP_CARD_H := 66.0
const TOOL_SWAP_CANCEL_W := 88.0
const TOOL_SWAP_CANCEL_H := 26.0
"""

OLD_BLOCK = """func _tool_swap_rect(i: int) -> Rect2:
	## R695：换工具栏位（只在「工具栏满 + 这条是工具」时存在）。绘制与命中共用。
	var r := _panel_rect()
	var total := float(RunState.TRAP_SLOTS) * TOOL_SWAP_W \\
			+ float(RunState.TRAP_SLOTS - 1) * TOOL_SWAP_GAP
	var x0 := r.position.x + (PANEL_W - total) * 0.5
	var y := r.position.y + PANEL_H - FOOT_H - 8.0 - TOOL_SWAP_H + 24.0
	return Rect2(x0 + float(i) * (TOOL_SWAP_W + TOOL_SWAP_GAP), y,
			TOOL_SWAP_W, TOOL_SWAP_H - 30.0)


func _draw_tool_swap_strip(r: Rect2) -> void:
	## R695（用户口径「我希望满栏掉落」）：3/3 满栏时，新工具**照样掉**、
	## 照样能领 —— 只是要先腾个位置。这里把三个旧槽摊在正文下方，点一个 = 丢掉它、
	## 新工具立刻补进那个槽（`_swap_tool()`）。
	## 为什么不做成「满栏就不掉」：旧版就是那样，10% 的掉率对满栏玩家悄悄变成 0%。
	var top := r.position.y + PANEL_H - FOOT_H - 8.0 - TOOL_SWAP_H
	_root.draw_string(_font_bold, Vector2(r.position.x, top + 16.0),
			GameI18n.ui("reward", "REWARD_TOOL_FULL_SWAP", "工具栏已满：点一个旧工具，把它换下来"),
			HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, UiTheme.FS_CAPTION, Color("8c1a10"))
	for i in RunState.TRAP_SLOTS:
		var sr := _tool_swap_rect(i)
		var old := RunState.trap_at(i)
		if old <= 0:
			continue
		var hot := _mouse_over(sr)
		_root.draw_rect(sr, Color(1.0, 0.98, 0.92, 0.72) if hot else Color(0.99, 0.97, 0.90, 0.55), true)
		_root.draw_rect(sr, Color("b03a2e") if hot else Color(0.42, 0.36, 0.26, 0.40), false, 2.0)
		var tex: Texture2D = UiAssets.trap_icon(old)
		if tex != null:
			_root.draw_texture_rect(tex, Rect2(sr.position + Vector2(6.0, 6.0),
					Vector2(sr.size.y - 12.0, sr.size.y - 12.0)), false)
		var td: TrapData = TrapRepo.load_json().get_trap(old)
		var nm := td.trap_name if td != null else "工具"
		_root.draw_string(_font, Vector2(sr.position.x + sr.size.y - 2.0, sr.position.y + 22.0),
				nm, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - sr.size.y - 2.0,
				UiTheme.FS_CAPTION, Color("6a5a40"))
		_root.draw_string(_font, Vector2(sr.position.x + sr.size.y - 2.0, sr.position.y + 38.0),
				GameI18n.ui("reward", "REWARD_TOOL_SWAP_TAG", "丢掉它"), HORIZONTAL_ALIGNMENT_LEFT,
				sr.size.x - sr.size.y - 2.0, UiTheme.FS_CAPTION,
				Color("b03a2e") if hot else Color(0.55, 0.42, 0.30, 0.75))
"""

NEW_BLOCK = """func _tool_swap_block_rect() -> Rect2:
	## R755：换装条整块（羊皮纸子面板）。只在「工具栏满 + 这条是工具」时存在。
	## 高度由 TOOL_SWAP_H 决定，正文 / 底部说明都按同一个值让位（见 `_draw_relic`）。
	var r := _panel_rect()
	return Rect2(r.position.x + PAD, r.position.y + PANEL_H - FOOT_H - 8.0 - TOOL_SWAP_H,
			PANEL_W - PAD * 2.0, TOOL_SWAP_H)


func _tool_swap_rect(i: int) -> Rect2:
	## R755：换装卡位。绘制与命中共用（点它 = 丢掉这件旧工具）。
	var b := _tool_swap_block_rect()
	var total := float(RunState.TRAP_SLOTS) * TOOL_SWAP_W \\
			+ float(RunState.TRAP_SLOTS - 1) * TOOL_SWAP_GAP
	var x0 := b.position.x + (b.size.x - total) * 0.5
	var y := b.position.y + TOOL_SWAP_HEAD_H
	return Rect2(x0 + float(i) * (TOOL_SWAP_W + TOOL_SWAP_GAP), y,
			TOOL_SWAP_W, TOOL_SWAP_CARD_H)


func _tool_swap_cancel_rect() -> Rect2:
	## R755（店长口径「也可以取消」）：取消 = 回列表，条目**留在待领队列**，不丢东西。
	var b := _tool_swap_block_rect()
	return Rect2(b.end.x - 14.0 - TOOL_SWAP_CANCEL_W, b.position.y + 8.0,
			TOOL_SWAP_CANCEL_W, TOOL_SWAP_CANCEL_H)


func _draw_tool_swap_strip(r: Rect2) -> void:
	## R695（用户口径「我希望满栏掉落」）：3/3 满栏时，新工具**照样掉**、照样能领 ——
	## 只是要先腾个位置。点一张旧工具卡 = 丢掉它、新工具立刻补进那个槽（`_swap_tool()`）。
	## 为什么不做成「满栏就不掉」：旧版就是那样，10% 的掉率对满栏玩家悄悄变成 0%。
	## R755：从「三块素色方块 + 一行红字」重做成一块正式子面板 —— 金色交换图标做标题、
	## 右上角给「取消」，卡片带图标 + 名字 + 动作词，悬停才转红（红线只标记「你正要丢的是它」）。
	var b := _tool_swap_block_rect()
	_round_box(b, 12.0, Color(0.99, 0.97, 0.90, 0.90), Color("c9a558"), true)
	var icon := UiAssets.small_icon("ui_tool_swap", 26)
	var tx := b.position.x + 16.0
	if icon != null:
		_root.draw_texture_rect(icon, Rect2(tx, b.position.y + 9.0, 26.0, 26.0), false)
		tx += 34.0
	_root.draw_string(_font_bold, Vector2(tx, b.position.y + 27.0),
			GameI18n.ui("reward", "REWARD_TOOL_SWAP_HEAD", "工具栏已满 · 选一件换下"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_BODY, Color("8c1a10"))
	# 取消键：与面板其它胶囊按钮同一套画法，只是更小
	var cr := _tool_swap_cancel_rect()
	_capsule_btn(cr, GameI18n.ui("reward", "REWARD_TOOL_SWAP_CANCEL", "取消"), false, false)
	for i in RunState.TRAP_SLOTS:
		var sr := _tool_swap_rect(i)
		var old := RunState.trap_at(i)
		if old <= 0:
			continue
		var hot := _mouse_over(sr)
		_round_box(sr, 10.0, Color(1.0, 0.99, 0.95, 0.96) if hot else Color(0.98, 0.96, 0.89, 0.80),
				Color("b03a2e") if hot else Color("d4cbb8"), hot)
		var icon_box := sr.size.y - 12.0
		var tex: Texture2D = UiAssets.trap_icon(old)
		if tex != null:
			_root.draw_texture_rect(tex, Rect2(sr.position + Vector2(6.0, 6.0),
					Vector2(icon_box, icon_box)), false)
		var td: TrapData = TrapRepo.load_json().get_trap(old)
		var nm := td.trap_name if td != null else "工具"
		var nx := sr.position.x + icon_box + 4.0
		var nw := sr.end.x - nx - 8.0
		_root.draw_string(_font_bold, Vector2(nx, sr.position.y + 28.0), nm,
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION, Color("4a3f2e"))
		_root.draw_string(_font, Vector2(nx, sr.position.y + 50.0),
				GameI18n.ui("reward", "REWARD_TOOL_SWAP_TAG", "丢掉它"),
				HORIZONTAL_ALIGNMENT_LEFT, nw, UiTheme.FS_CAPTION,
				Color("b03a2e") if hot else Color(0.55, 0.42, 0.30, 0.80))
"""


def main():
    raw = io.open(P, "r", encoding="utf-8", newline="").read()
    for old, new in [(OLD_CONST, NEW_CONST), (OLD_BLOCK, NEW_BLOCK)]:
        n = raw.count(old)
        assert n == 1, "expected 1, got %d for %r" % (n, old[:60])
        raw = raw.replace(old, new)
    io.open(P, "w", encoding="utf-8", newline="").write(raw)
    print("patched layout+draw")


main()
