extends SceneTree
## R647 出图：镜像 9056 加上「，抽一张卡。」之后的卡面排版验收。
##
## 直接走 `CardFace.draw()`（卡组 / 详情两个真实尺寸，on_board=false 才画效果文）。
## `record_seen = false`：出图探针**不许**把卡记进玩家「已见过」。
##
## 跑法：Godot --path . --script res://tools/shot_r646_mirror.gd
## ⚠️ 不能 --headless（拿不到 viewport 纹理）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const GAP := 40.0
const PAD := 30.0


class Board extends Node2D:
	var items: Array = []
	var font: Font
	var font_bold: Font

	func _draw() -> void:
		for it: Dictionary in items:
			var card: CardData = it["card"]
			var rect: Rect2 = it["rect"]
			CardFace.draw(self, card, rect, card.health, false, false,
					font, font_bold, -1, false, false, false, 0, -1, -1, false, false)
			draw_string(font_bold, Vector2(rect.position.x, rect.end.y + 28.0),
					str(it["label"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 16,
					Color(0.96, 0.92, 0.84))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var repo := CardRepo.load_json()
	var font := UiTheme.font()
	var font_bold := UiTheme.font_bold()
	var card: CardData = repo.get_card(9056)

	var board := Board.new()
	board.font = font
	board.font_bold = font_bold
	root.add_child(board)

	var r_deck := Rect2(PAD, 30.0, 336.0, 410.0)
	var r_detail := Rect2(PAD + 336.0 + GAP, 30.0, 431.0, 520.0)
	for r: Rect2 in [r_deck, r_detail]:
		var pad2: float = UiTheme.CARD_PAD * (r.size.y / CardFace.CARD_H_DESIGN)
		var L: Dictionary = CardFace.text_zone_layout(card, r, font, font_bold, pad2)
		print("LAYOUT ", r.size, " ok=", L["ok"], " eff_n=", L["eff_n"],
				"/", (L["eff_lines"] as Array).size(),
				" eff_sz=", L["eff_sz"], " avail=", float(L["bottom"]) - float(L["eff_base0"]),
				" maxw=", L["maxw"], " txt=", L["eff_text"])
		print("    top=", L["top"], " bottom=", L["bottom"], " tzb=",
				CardFace.text_zone_bottom(r), " name_sz=", L["name_sz"],
				" base_name=", L["base_name"], " base_meta=", L["base_meta"],
				" eff_base0=", L["eff_base0"], " line_h=", L["line_h"],
				" badge_r=", CardFace.badge_radius(r), " k=", r.size.y / CardFace.CARD_H_DESIGN,
				" designH=", CardFace.CARD_H_DESIGN, " pad=", pad2)
	board.items = [
		{"card": card, "rect": r_deck, "label": "卡组 336x410"},
		{"card": card, "rect": r_detail, "label": "详情 431x520"},
	]

	root.size = Vector2i(int(PAD * 2.0 + 336.0 + GAP + 431.0),
			int(30.0 + 520.0 + 70.0))
	RenderingServer.set_default_clear_color(Color(0.12, 0.11, 0.10))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var dir := "res://art_src/2026-11-13_镜像抽卡_R647/_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := dir + "/mirror_card.png"
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE（是不是加了 --headless？）")
		quit(1)
		return
	img.save_png(out)
	print("SHOT OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()
