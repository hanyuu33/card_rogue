extends SceneTree
## R508 商店货架专项门禁：三行「后挡板 + 层板」的几何断言 + 三分辨率实机截图。
##
## 钉住的是这一轮用户报的三件事（顺序同报障）：
##   ① 顶部「神秘商店」标题框被第一行卡牌压住 → 标题框与每一行商品区不得相交；
##   ② 左上角生命条（TopBar 固定 266×52 @ (8,8)）压住卡牌 → 同上；
##   ③ 三行之间要能读出「三层货架」→ 背板包住各自整行、层板在各行商品下方、行间不重叠、
##      第三行层板不能顶到「离开商店」。
## 视觉形态（无护栏 / 有后挡板 / 商品立在层板上）靠截图人工确认，脚本只保证几何不自撞。
##
## 跑法：
##   Godot --path . --script res://tools/verify_shop_shelf.gd
## 出图：art_src/2026-11-05_商店货架/shop{,_1024,_1080}.png

const UiTheme = preload("res://scripts/ui_theme.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	RunState.relic_choice.clear()
	var cases := [
		["", Vector2i(1280, 720)],
		["_1024", Vector2i(1024, 768)],
		["_1080", Vector2i(1920, 1080)],
	]
	for c: Array in cases:
		root.size = c[1]
		change_scene_to_file("res://scenes/shop.tscn")
		await process_frame
		await create_timer(0.7).timeout
		_check(current_scene)
		current_scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
				"res://art_src/2026-11-05_商店货架/shop%s.png" % str(c[0]))
	print("SHOP SHELF PASS")
	quit()


func _check(scene: Variant) -> void:
	## ⚠️ 必须读 `scene.size`（逻辑尺寸），**不能**用上面 `root.size` 的物理窗口尺寸：
	## 工程是 canvas_items + expand 拉伸，1024×768 这种 4:3 窗口的逻辑高度是 960 而不是 768，
	## 拿物理尺寸去算标题框中心会让「压没压到标题」的判断整体偏左（R508 自己踩过）。
	var vs: Vector2 = scene.size
	var rects: Array = scene._row_rects()
	assert(rects.size() == 3)
	# 标题框几何 = `_draw_header()` 里那块 300×48 的信息卡（y 从 10 起）。
	var header := Rect2(vs.x * 0.5 - 150.0, 10.0, 300.0, 48.0)
	# 全局状态条：`top_bar.gd` 的 SIZE (266,52) @ (8,8) —— 商店不在 `_is_menu_scene` 里，
	# 所以这块一定挂在左上角，必须让开。
	var topbar := Rect2(8.0, 8.0, 266.0, 52.0)
	var leave: Rect2 = scene._leave_rect()
	for i in 3:
		var row: Rect2 = rects[i]["row"]
		var shelf: Rect2 = rects[i]["shelf"]
		var back: Rect2 = rects[i]["back"]
		assert(row.size.y > 0.0 and shelf.size.y > 0.0, "第 %d 行高度为 0" % i)
		assert(not row.intersects(header), "第 %d 行压到「神秘商店」标题框" % i)
		assert(not row.intersects(topbar), "第 %d 行压到左上角生命条" % i)
		# 后挡板要把整行商品 + 层板都罩住（层板压在背板前面，背板少一截就会漏背景）。
		assert(back.encloses(row), "第 %d 行后挡板没罩住商品区" % i)
		assert(back.end.y >= shelf.end.y - 0.01, "第 %d 行后挡板没铺到层板下沿" % i)
		assert(shelf.position.y >= row.end.y - 0.01, "第 %d 行层板应在商品区下方" % i)
	# 行与行不重叠：上一行层板底 ≤ 下一行背板顶。
	assert(rects[0]["shelf"].end.y <= rects[1]["back"].position.y + 0.01,
			"第一行层板压到第二行背板")
	assert(rects[1]["shelf"].end.y <= rects[2]["back"].position.y + 0.01,
			"第二行层板压到第三行背板")
	# 第三行层板不能挤到「离开商店」按钮（按钮 y = vs.y - 60）。
	assert(rects[2]["shelf"].end.y <= leave.position.y - 8.0,
			"第三行层板贴到「离开商店」按钮")
	# 商品图标（含 6% 下压）必须留在自己的商品位里，溢出上限 8px。
	for idx: int in [1, 2]:
		var n: int = scene._row2.size() if idx == 1 else scene._row3.size()
		for i in n:
			var rr: Rect2 = scene._row23_item_rect(idx, i)
			var box: Rect2 = scene._goods_icon_box(rr)
			assert(rr.grow(8.0).encloses(box),
					"第 %d 行第 %d 件图标跑出商品位" % [idx, i])
	print("  · 逻辑 %.0fx%.0f 布局 OK（标题底 %.0f / 首行顶 %.0f / 三行底 %.0f）"
			% [vs.x, vs.y, header.end.y, rects[0]["row"].position.y,
					rects[2]["shelf"].end.y])
