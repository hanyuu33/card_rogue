extends SceneTree
## R613b 出图（卡面版）：战场单位卡面的字段 = 右上角 glyph，不再有文字条。
##
## 直接走 `CardFace.draw(on_board=true)` —— 这正是 `_draw_card_face` 给战场单位画卡面的
## 唯一入口（battle_scene._draw_board_unit → _draw_card_face → CardFace.draw）。
## 所以卡面上的字段表现与战场单位**完全一致**：次元 = portal glyph，嘲讽 = 盾牌 glyph，
## 没有任何「次元 / 嘲讽」文字条（那些文字条是 battle_scene 早年重复画的那版，已删）。
##
## 跑法：Godot --path . --script res://tools/shot_r613b_card.gd
## ⚠️ 不能 --headless。

const UiTheme = preload("res://scripts/ui_theme.gd")

const BIG := Vector2(248.0, 300.0)
const GAP_X := 46.0
const PAD_L := 34.0
const ROW_H := 380.0


class Board extends Node2D:
	var items: Array = []
	var font: Font
	var font_bold: Font

	func _draw() -> void:
		for it: Dictionary in items:
			var card: CardData = it["card"]
			var rect: Rect2 = it["rect"]
			CardFace.draw(self, card, rect, card.health, false, false,
					font, font_bold, -1, true)   # on_board = true
			var lab: String = it["label"]
			var note: String = it["note"]
			draw_string(font_bold, Vector2(rect.position.x, rect.end.y + 44.0),
					lab, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 16,
					Color(0.96, 0.92, 0.84))
			draw_string(font, Vector2(rect.position.x, rect.end.y + 66.0),
					note, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 14,
					Color(0.72, 0.70, 0.66))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var repo := CardRepo.load_json()
	var font := UiTheme.font()
	var font_bold := UiTheme.font_bold()

	var board := Board.new()
	board.font = font
	board.font_bold = font_bold
	root.add_child(board)

	# 复制野兔：带「次元」（is_ephemeral 模拟复制体）
	var hare: CardData = repo.get_card(9032)
	var dim := CardData.from_dict(hare.to_dict())
	dim.affixes = ["次元"]
	dim.is_ephemeral = true

	# 铁壁卫兵：自带「嘲讽」（标记类，保留）
	var taunt: CardData = repo.get_card(1011)

	# 普通友军：无字段（对照）
	var plain: CardData = repo.get_card(9002)

	var items: Array = []
	items.append({"card": dim, "rect": Rect2(PAD_L, 46.0, BIG.x, BIG.y),
			"label": "复制野兔 · 次元", "note": "次元 = 右上角 portal glyph，无文字条"})
	items.append({"card": taunt, "rect": Rect2(PAD_L + BIG.x + GAP_X, 46.0, BIG.x, BIG.y),
			"label": "铁壁卫兵 · 嘲讽", "note": "嘲讽 = 右上角盾牌 glyph（标记保留）"})
	items.append({"card": plain, "rect": Rect2(PAD_L + (BIG.x + GAP_X) * 2.0, 46.0, BIG.x, BIG.y),
			"label": "普通友军 · 无字段", "note": "对照：卡面干净"})
	board.items = items

	root.size = Vector2i(int(PAD_L * 2.0 + (BIG.x + GAP_X) * 3.0 - GAP_X),
			int(46.0 + BIG.y + 110.0))
	RenderingServer.set_default_clear_color(Color(0.12, 0.11, 0.10))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var out := "res://art_src/2026-11-12_野兔标记_R613/_review/board_card_face.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://art_src/2026-11-12_野兔标记_R613/_review"))
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE（是不是加了 --headless？）")
		quit(1)
		return
	img.save_png(out)
	print("SHOT OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()
