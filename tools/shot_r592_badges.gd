extends SceneTree
## R592 字段标志卡面验收出图（**不能加 --headless**：dummy 渲染器 `get_image()` 返回 null）。
##
## 画 8 张卡：0/1/2/3 字段各一张 + 同一张 3 字段卡在三个时刻（验证轮播）+ 战场模式一张。
## 输出：art_src/2026-11-11_字段标志_R592/_review/cards.png
##
## 跑法：Godot --path . --script res://tools/shot_r592_badges.gd

const UiTheme = preload("res://scripts/ui_theme.gd")
const CARD_W := 232.0
const CARD_H := 280.0
const GAP := 42.0


class Board extends Node2D:
	var items: Array = []       # [{card, rect, label, on_board, now_ms}]
	var font: Font
	var font_bold: Font

	func _draw() -> void:
		for it: Dictionary in items:
			var card: CardData = it["card"]
			CardFace.draw(self, card, it["rect"], card.health, false, false,
					font, font_bold, -1, bool(it["on_board"]))
			# 强制指定时刻重画一遍标志（覆盖 draw() 里读系统时钟的那次）
			CardFace._draw_affix_badges(self, card, it["rect"], CARD_H / 70.0,
					bool(it["on_board"]), int(it["now_ms"]))
			var lab: String = it["label"]
			draw_string(font, Vector2(it["rect"].position.x, it["rect"].end.y + 22.0),
					lab, HORIZONTAL_ALIGNMENT_LEFT, CARD_W, 15, Color(0.92, 0.90, 0.86))


func _initialize() -> void:
	_run.call_deferred()


func _mk(repo: CardRepo, id: int, affixes: Array, growth_p := 0, growth_h := 0) -> CardData:
	var c := CardData.from_dict(repo.get_card(id).to_dict())
	for a: String in affixes:
		c.add_affix(a)
	c.growth_power = growth_p
	c.growth_health = growth_h
	return c


func _run() -> void:
	var repo := CardRepo.load_json()
	var font := UiTheme.font()
	var font_bold := UiTheme.font_bold()

	var board := Board.new()
	board.font = font
	board.font_bold = font_bold
	root.add_child(board)

	var row1 := [
		[_mk(repo, 8003, ["交换"]), "只有交换（R592d：手卡出图标）", false, 0],
		[_mk(repo, 8003, ["次元"]), "1 个字段：次元（漩涡）", false, 0],
		[_mk(repo, 8003, ["疾行", "嘲讽"]), "2 个字段：疾行 · 嘲讽", false, 0],
		[_mk(repo, 8003, ["嘲讽", "护盾", "次元"]), "3 个字段（t=0s）", false, 0],
	]
	var row2 := [
		[_mk(repo, 8003, ["嘲讽", "护盾", "次元"]), "同上 · t=1.8s", false, 1800],
		[_mk(repo, 8003, ["嘲讽", "护盾", "次元"]), "同上 · t=3.6s", false, 3600],
		[_mk(repo, 8003, ["疾行", "嘲讽", "死亡", "超负荷"]), "4 个字段（环形回到第 0 张）", false, 7200],
		[_mk(repo, 8003, ["交换", "嘲讽"]), "战场模式：交换被过滤，只剩嘲讽", true, 0],
	]
	var all_rows := [row1, row2]
	var items: Array = []
	for r in all_rows.size():
		var row: Array = all_rows[r]
		for i in row.size():
			var it: Array = row[i]
			items.append({
				"card": it[0],
				"label": it[1],
				"on_board": it[2],
				"now_ms": it[3],
				"rect": Rect2(40.0 + float(i) * (CARD_W + GAP),
						70.0 + float(r) * (CARD_H + GAP + 34.0), CARD_W, CARD_H),
			})
	board.items = items

	root.size = Vector2i(int(40.0 * 2 + 4 * CARD_W + 3 * GAP),
			int(70.0 + 2 * (CARD_H + GAP + 34.0) + 30.0))
	RenderingServer.set_default_clear_color(Color(0.13, 0.12, 0.11))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var out := "res://art_src/2026-11-11_字段标志_R592/_review/cards.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://art_src/2026-11-11_字段标志_R592/_review"))
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE（是不是加了 --headless？）")
		quit(1)
		return
	img.save_png(out)
	# 尺寸自查：R592e —— 圆心压在卡框右上角，探出量必须 ≤ 一个半径（与费用同款）
	var probe: CardData = items[2]["card"]
	var cr: Rect2 = items[2]["rect"]
	var box := CardFace.affix_badge_rect(probe, cr, false)
	var r: float = CardFace.badge_radius(cr)
	var too_far: bool = (box.end.x - cr.end.x > r + 0.01
			or cr.position.y - box.position.y > r + 0.01
			or box.position.x < cr.end.x - r - 0.01)
	if too_far:
		printerr("BADGE_SLOT 探出过多: ", box)
	print("BADGE_SLOT ", box)
	print("SHOT OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()


func _process(_delta: float) -> bool:
	return false
