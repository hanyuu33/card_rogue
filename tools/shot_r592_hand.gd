extends SceneTree
## R592d 手牌真实尺寸验收（**不能加 --headless**：dummy 渲染器 `get_image()` 返回 null）。
##
## 为什么单独出一张：`shot_r592_badges.gd` 用 232×280 的大卡看细节，
## 但店长口径是「交换 / 短暂(幻影) / 次元 都需要**手卡上**显示」——
## 手牌实卡只有 `HAND_CARD_W × HAND_CARD_H` = 98.6 × 119.0（battle_scene 常量），
## 标志直径在那个尺寸下只有 ~34px，得按真实比例验一次可读性。
##
## 跑法：Godot --path . --script res://tools/shot_r592_hand.gd
## 输出：art_src/2026-11-11_字段标志_R592/_review/hand.png

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_W := 98.6          # = battle_scene.HAND_CARD_W
const CARD_H := 119.0         # = battle_scene.HAND_CARD_H
const GAP := 18.0
const LEFT := 26.0
const TOP := 46.0


class Board extends Node2D:
	var items: Array = []
	var font: Font
	var font_bold: Font

	func _draw() -> void:
		for it: Dictionary in items:
			var card: CardData = it["card"]
			CardFace.draw(self, card, it["rect"], card.health, false, false,
					font, font_bold, -1, false, false, true)
			CardFace._draw_affix_badges(self, card, it["rect"],
					CARD_H / 70.0, false, int(it["now_ms"]))
			draw_string(font, Vector2(it["rect"].position.x, TOP - 12.0),
					it["label"], HORIZONTAL_ALIGNMENT_LEFT, CARD_W, 12,
					Color(0.92, 0.90, 0.86))


func _initialize() -> void:
	_run.call_deferred()


func _mk(repo: CardRepo, id: int, affixes: Array) -> CardData:
	var c := CardData.from_dict(repo.get_card(id).to_dict())
	for a: String in affixes:
		c.add_affix(a)
	return c


func _run() -> void:
	var repo := CardRepo.load_json()
	var font: Font = UiTheme.font()
	var font_bold: Font = UiTheme.font_bold()

	var board := Board.new()
	board.font = font
	board.font_bold = font_bold
	root.add_child(board)

	var row := [
		[_mk(repo, 8003, ["交换"]), "交换"],
		[_mk(repo, 8003, ["幻影"]), "短暂(幻影)"],
		[_mk(repo, 8003, ["次元"]), "次元"],
		[_mk(repo, 8003, ["交换", "次元"]), "交换+次元 轮播"],
		[_mk(repo, 8003, []), "无字段（对照）"],
	]
	var items: Array = []
	for i in row.size():
		var it: Array = row[i]
		items.append({
			"card": it[0],
			"label": it[1],
			"now_ms": 0,
			"rect": Rect2(LEFT + float(i) * (CARD_W + GAP), TOP, CARD_W, CARD_H),
		})
	board.items = items

	root.size = Vector2i(int(LEFT * 2 + 5 * CARD_W + 4 * GAP), int(TOP + CARD_H + 26))
	# ⚠️ project.godot 是 `stretch/mode="canvas_items"`（基准 1280×720）——
	#    不关掉它，617 宽的窗口会把内容按 0.48 缩下去，手牌卡截出来只有 47px 宽，
	#    「真实尺寸验收」就白做了。这里要的是**像素 1:1**。
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color(0.13, 0.12, 0.11))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var out := "res://art_src/2026-11-11_字段标志_R592/_review/hand.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://art_src/2026-11-11_字段标志_R592/_review"))
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE（是不是加了 --headless？）")
		quit(1)
		return
	img.save_png(out)
	print("SHOT OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()


func _process(_delta: float) -> bool:
	return false
