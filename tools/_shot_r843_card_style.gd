extends SceneTree
## R843 卡面改版视觉验收：真实 CardFace 绘制，1:1 像素，不污染玩家图鉴。
## 用法：Godot --path . --script res://tools/_shot_r843_card_style.gd
## 输出：art_src/2026-11-20_card_face_redesign/card_style.png

const UiTheme = preload("res://scripts/ui_theme.gd")
const OUT := "res://art_src/2026-11-20_card_face_redesign/card_style.png"
const OUT_I18N := "res://art_src/2026-11-20_card_face_redesign/card_style_i18n.png"
const OUT_CLASSES := "res://art_src/2026-11-20_card_face_redesign/card_style_classes.png"


class Sheet extends Node2D:
	var items: Array[Dictionary] = []
	var labels: Array[Dictionary] = []
	var face: Font
	var bold: Font

	func _draw() -> void:
		for item: Dictionary in labels:
			draw_string(bold, item["at"], item["text"], HORIZONTAL_ALIGNMENT_LEFT,
					-1, 18, Color("e8dfc8"))
		var previous_language := GameSettings.language
		for item: Dictionary in items:
			GameSettings.language = String(item.get("lang", previous_language))
			var card: CardData = item["card"]
			var rect: Rect2 = item["rect"]
			CardFace.draw(self, card, rect, int(item.get("hp", card.health)),
					false, false, face, bold, -1, bool(item.get("board", false)),
					false, bool(item.get("name_only", false)), 0, -1, -1,
					bool(item.get("adventure", false)), false)
			if item.has("fixed_badges"):
				CardFace._draw_affix_badges(self, card, rect,
						rect.size.y / CardFace.CARD_H_DESIGN,
						bool(item.get("board", false)), 0)
		GameSettings.language = previous_language


func _initialize() -> void:
	_run.call_deferred()


func _clone(repo: CardRepo, id: int, affixes: Array = []) -> CardData:
	var source: CardData = repo.get_card(id)
	var card := CardData.from_dict(source.to_dict())
	for affix: String in affixes:
		card.add_affix(affix)
	return card


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("191821"))
	var repo := CardRepo.load_json()
	var sheet := Sheet.new()
	sheet.face = UiTheme.font()
	sheet.bold = UiTheme.font_bold()
	root.add_child(sheet)
	var samples: Array[CardData] = [
		_clone(repo, 9040),
		_clone(repo, 9016, ["嘲讽"]),
		_clone(repo, 9038, ["次元"]),
		_clone(repo, 8005),
		_clone(repo, 8074),
		_clone(repo, 9056),
	]
	sheet.labels.append({"at": Vector2(30, 32), "text": "手牌 99×119 · 战斗材质 · 只显示卡名"})
	for i in samples.size():
		var r := Rect2(40 + i * 150, 58, 99, 119)
		sheet.items.append({"card": samples[i], "rect": r,
				"name_only": true, "adventure": true, "fixed_badges": true})
	sheet.labels.append({"at": Vector2(30, 230), "text": "战场 / 图鉴网格 77×92 · 四属性与稀有度"})
	for i in samples.size():
		var r := Rect2(50 + i * 150, 260, 77, 92)
		sheet.items.append({"card": samples[i], "rect": r,
				"board": true, "fixed_badges": true})
	sheet.labels.append({"at": Vector2(30, 420), "text": "详情 198×238 · 名称 / 卡种 / 效果正文"})
	for i in 4:
		var r := Rect2(60 + i * 275, 450, 198, 238)
		sheet.items.append({"card": samples[i], "rect": r})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE: 截图工具不能加 --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := img.save_png(OUT)
	print("SHOT OK ", ProjectSettings.globalize_path(OUT), " ", img.get_size(), " err=", err)
	if err != OK:
		quit(1)
		return

	# R843c：同一张工具再出四语 × 七档稀有度，验证标签定高、随译文伸缩。
	sheet.queue_free()
	var lang_sheet := Sheet.new()
	lang_sheet.face = UiTheme.font()
	lang_sheet.bold = UiTheme.font_bold()
	root.add_child(lang_sheet)
	var langs: Array[String] = ["en", "ja", "es", "zh"]
	var titles: Array[String] = ["EN · 7 rarities", "JA · 7 rarities", "ES · 7 rarities", "ZH · 7 rarities"]
	for row in langs.size():
		lang_sheet.labels.append({"at": Vector2(30, 42 + row * 165), "text": titles[row]})
		for rarity in 7:
			var card := _clone(repo, 9040)
			card.rarity = rarity
			lang_sheet.items.append({"card": card,
					"rect": Rect2(40 + rarity * 170, 58 + row * 165, 99, 119),
					"name_only": true, "adventure": true, "lang": langs[row]})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var lang_img := root.get_texture().get_image()
	var lang_err := lang_img.save_png(OUT_I18N)
	print("I18N SHOT OK ", ProjectSettings.globalize_path(OUT_I18N), " err=", lang_err)
	if lang_err != OK:
		quit(1)
		return

	# R843e：六种归属各出紧凑 / 详情两档，检查一体框比例、透明窗与文字安全区。
	lang_sheet.queue_free()
	var class_sheet := Sheet.new()
	class_sheet.face = UiTheme.font()
	class_sheet.bold = UiTheme.font_bold()
	root.add_child(class_sheet)
	var classes: Array[String] = ["森林精魄", "暗影刺客", "机械之心", "吟游诗人", "", "敌人"]
	for i in classes.size():
		var card := _clone(repo, 9040)
		card.card_class = classes[i]
		if classes[i] == "敌人":
			card.group = "enemy"
		var label: String = "公用" if classes[i].is_empty() else classes[i]
		class_sheet.labels.append({"at": Vector2(45 + i * 200, 50), "text": label})
		class_sheet.items.append({"card": card, "rect": Rect2(45 + i * 200, 75, 99, 119),
				"name_only": true, "adventure": true})
		class_sheet.items.append({"card": card, "rect": Rect2(25 + i * 200, 260, 160, 193)})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var class_img := root.get_texture().get_image()
	var class_err := class_img.save_png(OUT_CLASSES)
	print("CLASS SHOT OK ", ProjectSettings.globalize_path(OUT_CLASSES), " err=", class_err)
	quit(0 if class_err == OK else 1)
