extends SceneTree
## 商店描述板几何验收：贴在卡下面 / 翻到卡上方后，整块板子必须始终在屏幕内。
## 直接调用产品代码的唯一几何口 `_desc_plate_rect()`，不复制公式。
## 用法（**必须带窗口**，不能 --headless）：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tools/verify_shop_desc_plate.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	change_scene_to_file("res://scenes/shop.tscn")
	await process_frame
	await create_timer(0.5).timeout
	var shop: Node = current_scene
	if shop == null:
		print("DESC PLATE FAIL: shop scene is null")
		quit(1)
		return
	var sizes: Array[Vector2] = [
		Vector2(1280, 720), Vector2(1024, 768), Vector2(800, 600),
		Vector2(640, 480), Vector2(480, 360), Vector2(1920, 1080),
	]
	var cases := 0
	var fails := 0
	for sz: Vector2 in sizes:
		var saved: Vector2 = shop.size
		shop.size = sz
		var screen := Rect2(Vector2.ZERO, sz)
		# 卡的纵向位置：屏幕顶 / 上中 / 中下 / 贴底 / 离底 200（触发「下方放不下翻上方」）
		for ay in [0.0, sz.y * 0.25, sz.y * 0.6, sz.y - 60.0, sz.y - 200.0]:
			# 卡宽：窄卡 / 基准 150 / 选卡覆盖层里更宽的卡
			for aw in [100.0, 150.0, 320.0]:
				# 横向位置：屏幕外 / 贴左边 / 居中 / 贴右边 / 几乎出右边界
				for ax in [-30.0, 0.0, sz.x * 0.5 - aw * 0.5, sz.x - aw * 0.5, sz.x - 5.0]:
					var anchor := Rect2(ax, ay, aw, 180.0)
					# 描述行数：1 行 / 常规 / 超长 / 极端（验证行数夹取）
					for n in [1, 2, 5, 12, 40, 200]:
						var rr: Rect2 = shop._desc_plate_rect(anchor, n)
						cases += 1
						if not screen.encloses(rr):
							fails += 1
							if fails <= 5:
								print("FAIL sz=%s anchor=%s n=%d rr=%s"
										% [str(sz), str(anchor), n, str(rr)])
		shop.size = saved
		print("[size %s] checked" % str(sz))
	print("DESC PLATE GEOMETRY: cases=%d fails=%d" % [cases, fails])
	if fails == 0:
		print("DESC PLATE PASS: 描述板始终在屏幕内")
	quit(0 if fails == 0 else 1)
