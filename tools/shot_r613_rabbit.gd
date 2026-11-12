extends SceneTree
## R613 出图：野兔 9032 的「标记」该长在哪。
##
## 店长报障（2026-11-12）：野兔在商店里也带上标记，「这不对，野兔制造的复制野兔才需要标记」。
## 本图钉住改前 / 改后两种状态，四格一眼对比：
##   行① 改前（R319~R612）：本体 `affixes = ["幻影"]` → 商店小卡 / 手牌大卡都顶着徽标；
##   行② 改后（R613）：本体 `affixes = []` → 本体干净，**只有复制品**带「次元」。
##
## 跑法：Godot --path . --script res://tools/shot_r613_rabbit.gd
## ⚠️ 不能加 --headless：dummy 渲染器下 `get_image()` 返回 null。

const UiTheme = preload("res://scripts/ui_theme.gd")

const BIG := Vector2(232.0, 280.0)      # 手牌 / 牌库 / 图鉴大卡
const SMALL := Vector2(150.0, 190.0)    # 商店选卡页 / 奖励三选一的小卡
const GAP_X := 46.0
const PAD_L := 34.0
const ROW_H := 408.0


class Board extends Node2D:
	var items: Array = []      # [{card, rect, label, pick, note}]
	var font: Font
	var font_bold: Font

	func _draw() -> void:
		for it: Dictionary in items:
			var card: CardData = it["card"]
			var rect: Rect2 = it["rect"]
			if bool(it["pick"]):
				CardFace.draw_pick(self, card, rect, font, font_bold, false)
			else:
				CardFace.draw(self, card, rect, card.health, false, false,
						font, font_bold, -1, false)
			var lab: String = it["label"]
			var note: String = it["note"]
			# 卡片绘制会超出 rect（费用 / 数值徽章圆心压在框线上、一半探出），标签必须让开
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

	var hare: CardData = repo.get_card(9032)
	# 改前的样子：本体挂「幻影」（R319~R612 的数据状态，这里手工复现，不动 cards.json）
	var hare_before := CardData.from_dict(hare.to_dict())
	hare_before.add_affix("幻影")
	# 复制品 = 与 `GameEngine._spawn_self_clone` 同口径
	var clone := CardData.from_dict(hare.to_dict())
	clone.is_ephemeral = true
	clone.affixes = ["次元"]

	var items: Array = []
	# 行①：改前
	items.append({"card": hare_before, "pick": false, "rect": Rect2(
			PAD_L, 46.0, BIG.x, BIG.y),
			"label": "改前 · 手牌大卡", "note": "本体挂「幻影」→ 顶着一个徽标"})
	items.append({"card": hare_before, "pick": true, "rect": Rect2(
			PAD_L + BIG.x + GAP_X, 46.0 + (BIG.y - SMALL.y) * 0.5, SMALL.x, SMALL.y),
			"label": "改前 · 商店小卡", "note": "买卡时就带着 → 店长报的那一格"})
	# 行②：改后
	var y2 := 46.0 + ROW_H
	items.append({"card": hare, "pick": false, "rect": Rect2(PAD_L, y2, BIG.x, BIG.y),
			"label": "改后 · 手牌大卡", "note": "本体没有任何字段 → 干净"})
	items.append({"card": hare, "pick": true, "rect": Rect2(
			PAD_L + BIG.x + GAP_X, y2 + (BIG.y - SMALL.y) * 0.5, SMALL.x, SMALL.y),
			"label": "改后 · 商店小卡", "note": "同上一格，标记消失"})
	items.append({"card": clone, "pick": false, "rect": Rect2(
			PAD_L + (BIG.x + GAP_X) * 2.0, y2, BIG.x, BIG.y),
			"label": "改后 · 复制野兔", "note": "只有它带「次元」标记"})
	board.items = items

	root.size = Vector2i(int(PAD_L * 2.0 + (BIG.x + GAP_X) * 3.0 - GAP_X),
			int(y2 + BIG.y + 110.0))
	RenderingServer.set_default_clear_color(Color(0.12, 0.11, 0.10))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var out := "res://art_src/2026-11-12_野兔标记_R613/_review/rabbit_mark.png"
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


func _process(_delta: float) -> bool:
	return false
