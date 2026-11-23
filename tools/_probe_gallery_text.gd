extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	GameBuild.set_test_release(0)
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/gallery.tscn")
	await process_frame
	await create_timer(0.4).timeout
	var g = current_scene
	var copy = null
	var longest = null
	for lang in ["zh", "en", "ja", "es", "zh"]:
		GameSettings.language = lang
		var issues := 0
		for c in g._all:
			if c.group != "player":
				continue
			ProfileData.mark_card_seen(c.id)
			if c.id == 9165:
				copy = c
			if c.id == 8082:
				longest = c
			g._selected = c
			g._refresh_detail()
			await process_frame
			var labels := [g.detail_name, g.detail_kind, g.detail_stats, g.detail_traits, g.detail_text]
			var limits := [Vector2(236, 30), Vector2(236, 24), Vector2(236, 24), Vector2(236, 24), Vector2(236, 230)]
			for i in labels.size():
				var lb: Label = labels[i]
				var lim: Vector2 = limits[i]
				if lb == g.detail_text and lb.get_visible_line_count() < lb.get_line_count():
					issues += 1
					print("CLIPPED lang=", lang, " id=", c.id, " lines=", lb.get_line_count(),
							" visible=", lb.get_visible_line_count(), " fs=", lb.get_theme_font_size("font_size"))
				if lb.size.x > lim.x + 1.5 or lb.size.y > lim.y + 1.5:
					issues += 1
					if issues <= 40:
						print("ISSUE lang=", lang, " id=", c.id, " label=", lb.name, " size=", lb.size,
								" limit=", lim, " min=", lb.get_minimum_size(), " clip=", lb.clip_text,
								" fs=", lb.get_theme_font_size("font_size"), " text=", lb.text)
			if c.id == 9165:
				var lb: Label = g.detail_text
				print("COPY lang=", lang, " size=", lb.size, " min=", lb.get_minimum_size(),
						" lines=", lb.get_line_count(), " visible=", lb.get_visible_line_count(),
						" clip=", lb.clip_text, " fs=", lb.get_theme_font_size("font_size"),
						" text=", lb.text)
		print("LANG=", lang, " ISSUES=", issues)
	GameSettings.language = "zh"
	g._selected = copy
	g._refresh_detail()
	await process_frame
	await process_frame
	# headless 用 dummy rendering，`root.get_texture()` 拿不到图 → 排版结论已打印完，直接收尾。
	if DisplayServer.get_name() == "headless":
		print("[probe] headless：跳过两张截图，排版结果以上方 LANG/ISSUES 为准")
		quit()
		return
	var img := root.get_texture().get_image()
	img.save_png("res://_review/gallery_copy_after.png")
	GameSettings.language = "en"
	g._selected = longest
	g._refresh_detail()
	await process_frame
	await process_frame
	img = root.get_texture().get_image()
	img.save_png("res://_review/gallery_long_en_after.png")
	quit()
