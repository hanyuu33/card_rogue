extends SceneTree
## 一次性探针（headless，不弹窗）：把 R117 之后的战场版式**全部算成数字**核对，
## 不靠目测（出图只能看出「大概」，重叠 2px 与不重叠在图上是同一张）。
## 用法：godot --headless --path . --script res://_probe_r117_layout.gd

const B = preload("res://scripts/battle_scene.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")


func _rect(tag: String, r: Rect2) -> String:
	return "  %-18s x[%7.1f..%7.1f]  y[%7.1f..%7.1f]  %.1f × %.1f" % [
		tag, r.position.x, r.end.x, r.position.y, r.end.y, r.size.x, r.size.y]


func _init() -> void:
	var s: Control = B.new()
	s.size = Vector2(1280, 720)

	print("== 常量 ==")
	print("  窗口 %s × %s" % [s.WINDOW_W, s.WINDOW_H])
	print("  卡 %.0f×%.0f  横置 %.0f×%.0f  格 %.0f(W)×%.0f(H)  棋盘 %.0f×%.0f @ (%.0f,%.0f)" % [
		s.CARD_W, s.CARD_H, s.TAP_W, s.TAP_H, s.CELL_W, s.CELL, s.GRID_W, s.GRID_H,
		s.GRID_X, s.GRID_Y])
	print("  手牌 %.1f×%.1f  卡顶 %.1f  悬停抬手 %.0f" % [
		s.HAND_CARD_W, s.HAND_CARD_H, s.OWN_HAND_Y, s.HAND_FAN_HOVER_LIFT])
	print("  顶栏 %.0f  教程条上限 %.0f" % [36.0, s.TUT_BAR_MAX_H])

	print()
	print("== 关键区域（与 R116 对照）==")
	print(_rect("棋盘 GRID", Rect2(s.GRID_X, s.GRID_Y, s.GRID_W, s.GRID_H)))
	print(_rect("信息栏", Rect2(s.INFO_X, s.GRID_Y, s.INFO_W, s.GRID_H)))
	print(_rect("能量面板", Rect2(s.COST_X, s.COST_Y, s.TAP_W + 12, s.ENERGY_H)))
	print(_rect("效果区", s._own_effect_zone_rect()))
	print(_rect("敌方效果区", s._enemy_zone_rect()))
	print(_rect("道具栏", s._relic_zone_rect()))
	print(_rect("牌库", Rect2(s.DECK_X, s.DECK_Y, s.CARD_W, s.CARD_H)))
	print(_rect("弃牌堆", Rect2(s.DISCARD_X, s.DISCARD_Y, s.CARD_W, s.CARD_H)))
	print(_rect("手牌(中间那张)", s._hand_rect(0) if s.engine == null else Rect2(0, 0, 0, 0)))

	print()
	print("== 不变量核对 ==")
	var ok := true
	# ① 手牌抬手后卡顶不能盖住棋盘下沿（test_smoke 的同一条）
	var hand_top: float = s.OWN_HAND_Y - s.HAND_FAN_HOVER_LIFT
	var grid_bottom: float = s.GRID_Y + s.GRID_H
	print("  ① 抬手卡顶 %.1f ≥ 棋盘下沿 %.1f - 2 → %s" % [
		hand_top, grid_bottom, "OK" if hand_top >= grid_bottom - 2.0 else "FAIL"])
	ok = ok and hand_top >= grid_bottom - 2.0
	# ② 横置卡（含两侧徽章）要装进格子横边
	var k_tap: float = minf(s.TAP_H / 70.0, UiTheme.CARD_BADGE_SCALE_CAP)
	var tap_extent: float = s.TAP_W + 2.0 * UiTheme.CARD_BADGE_R * k_tap
	print("  ② 横置卡总宽 %.2f ≤ 格宽 %.0f → %s（余 %.2f）" % [
		tap_extent, s.CELL_W, "OK" if tap_extent <= s.CELL_W else "FAIL",
		s.CELL_W - tap_extent])
	ok = ok and tap_extent <= s.CELL_W
	# ③ 正立卡（含徽章）两个方向都要装进格子
	var k: float = minf(s.CARD_H / 70.0, UiTheme.CARD_BADGE_SCALE_CAP)
	var w_extent: float = s.CARD_W + 2.0 * UiTheme.CARD_BADGE_R * k
	var h_extent: float = s.CARD_H + 2.0 * UiTheme.CARD_BADGE_R * k
	print("  ③ 正立卡总宽 %.2f ≤ %.0f → %s ／ 总高 %.2f ≤ %.0f → %s（上/下相邻行余 %.2f）" % [
		w_extent, s.CELL_W, "OK" if w_extent <= s.CELL_W else "FAIL",
		h_extent, s.CELL, "OK" if h_extent <= s.CELL else "重叠 %.2f" % (h_extent - s.CELL),
		s.CELL - h_extent])
	# ④ 棋盘与各栏不重叠
	var grid := Rect2(s.GRID_X, s.GRID_Y, s.GRID_W, s.GRID_H)
	for pair: Array in [["信息栏", Rect2(s.INFO_X, s.GRID_Y, s.INFO_W, s.GRID_H)],
			["效果区", s._own_effect_zone_rect()],
			["敌方效果区", s._enemy_zone_rect()],
			["道具栏", s._relic_zone_rect()],
			["牌库", Rect2(s.DECK_X, s.DECK_Y, s.CARD_W, s.CARD_H)],
			["弃牌堆", Rect2(s.DISCARD_X, s.DISCARD_Y, s.CARD_W, s.CARD_H)]]:
		var hit: bool = grid.intersects(pair[1])
		print("  ④ 棋盘 × %-6s → %s" % [pair[0], "重叠 !!" if hit else "不重叠"])
		ok = ok and not hit
	# ⑤ 棋盘上沿要给顶栏留白
	print("  ⑤ 棋盘上沿 %.0f > 顶栏 36 → %s" % [
		s.GRID_Y, "OK" if s.GRID_Y > 36.0 else "FAIL"])
	ok = ok and s.GRID_Y > 36.0
	# ⑥ 槽位容量
	print("  ⑥ 效果区 %d 槽 / 敌方效果区 %d 槽 / 道具栏 %d 槽" % [
		s._effect_zone_max_slots(), s._enemy_effect_zone_max_slots(), s._relic_max_slots()])
	var cap: int = s._effect_zone_max_slots()
	var last: Rect2 = s._effect_rect(cap - 1)
	print("     效果区末位底部 %.1f ≤ %.1f → %s" % [
		last.end.y, grid_bottom, "OK" if last.end.y <= grid_bottom + 0.5 else "FAIL"])
	ok = ok and last.end.y <= grid_bottom + 0.5

	print()
	print("== 卡面数值（战场 k=%.3f）==" % k)
	print("  徽章半径 %.2f（直径 %.1f）  字号 %d  两位数字量宽 %.1f ／ 阈值 %.1f" % [
		UiTheme.CARD_BADGE_R * k, 2.0 * UiTheme.CARD_BADGE_R * k,
		maxi(7, roundi(UiTheme.CARD_FS_BADGE * k)),
		UiTheme.font_bold().get_string_size("30", HORIZONTAL_ALIGNMENT_LEFT, -1,
			maxi(7, roundi(UiTheme.CARD_FS_BADGE * k))).x,
		UiTheme.CARD_BADGE_R * k * 1.75])
	print()
	print("总判定：%s" % ("全部通过" if ok else "有 FAIL，见上"))
	s.free()
	quit()
