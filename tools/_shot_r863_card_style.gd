extends SceneTree
## R863 卡面改版视觉验收：新职业框（title18 卡名框版）+ 卡名框染稀有度 + 卡面无数值。
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r863_card_style.gd
## 输出：art_src/2026-11-23_frames/r863_card_style.png / r863_rarity.png
##
## 与 R843 的验收工具同构，只换了要验的东西：
##   ① 六类归属 × 三档尺寸（手牌 99×119 / 战场 66×80 / 详情 198×238）
##   ② 七档稀有度并列 —— 验「卡名框颜色 = 稀有度」这一条通道
## 全部走真实 `CardFace.draw()`，1:1 像素，不污染玩家图鉴。

const UiTheme = preload("res://scripts/ui_theme.gd")
const OUT := "res://art_src/2026-11-23_frames/r863_card_style.png"
const OUT_RARITY := "res://art_src/2026-11-23_frames/r863_rarity.png"


class Sheet extends Node2D:
	var items: Array[Dictionary] = []
	var labels: Array[Dictionary] = []
	var face: Font
	var bold: Font

	func _draw() -> void:
		for item: Dictionary in labels:
			draw_string(bold, item["at"], item["text"], HORIZONTAL_ALIGNMENT_LEFT,
					-1, 16, Color("e8dfc8"))
		for item: Dictionary in items:
			var card: CardData = item["card"]
			var rect: Rect2 = item["rect"]
			CardFace.draw(self, card, rect, int(item.get("hp", card.health)),
					false, false, face, bold, -1, bool(item.get("board", false)),
					false, bool(item.get("name_only", false)), 0, -1, -1,
					bool(item.get("adventure", false)), false)


func _initialize() -> void:
	_run.call_deferred()


func _clone(repo: CardRepo, id: int) -> CardData:
	var source: CardData = repo.get_card(id)
	return CardData.from_dict(source.to_dict())


func _shot(node: Node, path: String) -> int:
	## ⚠️ 先把画面抓下来再释放节点：反过来写会抓到一张纯背景（R863 首版就这么黑过一次）。
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE: 截图工具不能加 --headless")
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path), " ", img.get_size(), " err=", err)
	node.queue_free()
	await process_frame
	return 0 if err == OK else 1


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("191821"))
	var repo := CardRepo.load_json()

	# ① 六类归属 × 三档尺寸
	var sheet := Sheet.new()
	sheet.face = UiTheme.font()
	sheet.bold = UiTheme.font_bold()
	root.add_child(sheet)
	# id → 归属：森林 9040 / 暗影 8005 / 机械 8060 / 吟游 9263 / 公用 8001 / 敌人 1011
	var kinds: Array = [[9040, "森林精魄"], [8005, "暗影刺客"], [8060, "机械之心"],
			[9263, "吟游诗人"], [8001, "公用"], [1011, "敌人"]]
	sheet.labels.append({"at": Vector2(28, 26), "text": "手牌 99×119"})
	sheet.labels.append({"at": Vector2(28, 176), "text": "战场 66×80（格底 12px 是数值条的位置）"})
	sheet.labels.append({"at": Vector2(28, 292), "text": "详情 198×238"})
	for i in kinds.size():
		var card := _clone(repo, int(kinds[i][0]))
		var x := 28 + i * 208
		sheet.items.append({"card": card, "rect": Rect2(x, 36, 99, 119),
				"name_only": true, "adventure": true})
		sheet.items.append({"card": card, "rect": Rect2(x + 16, 186, 66, 80), "board": true})
		sheet.items.append({"card": card, "rect": Rect2(x, 300, 198, 238)})
	if await _shot(sheet, OUT) != 0:
		quit(1)
		return

	# ② 七档稀有度（同一张卡，只改 rarity）—— 验卡名框染色
	var rs := Sheet.new()
	rs.face = UiTheme.font()
	rs.bold = UiTheme.font_bold()
	root.add_child(rs)
	rs.labels.append({"at": Vector2(28, 26), "text": "稀有度 0..6 = 卡名框颜色（普通/稀有/史诗/初始/怪物/事件/诅咒）"})
	var names: Array[String] = ["普通", "稀有", "史诗", "初始", "怪物", "事件", "诅咒"]
	for i in 7:
		var card := _clone(repo, 9040)
		card.rarity = i
		rs.items.append({"card": card, "rect": Rect2(28 + i * 176, 44, 99, 119),
				"name_only": true, "adventure": true})
		rs.items.append({"card": card, "rect": Rect2(44 + i * 176, 196, 66, 80), "board": true})
		rs.items.append({"card": card, "rect": Rect2(28 + i * 176, 300, 150, 180)})
		rs.labels.append({"at": Vector2(30 + i * 176, 500), "text": names[i]})
	# 长卡名压测：一张长译名 + 一张英文长名
	var long_card := _clone(repo, 8074)
	long_card.rarity = 2
	rs.items.append({"card": long_card, "rect": Rect2(28, 530, 99, 119),
			"name_only": true, "adventure": true})
	rs.items.append({"card": long_card, "rect": Rect2(160, 530, 198, 238)})
	rs.labels.append({"at": Vector2(28, 660), "text": "长卡名：手牌 99×119 / 详情 198×238"})
	if await _shot(rs, OUT_RARITY) != 0:
		quit(1)
		return
	quit(0)
