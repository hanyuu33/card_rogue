extends SceneTree
const MapVisual = preload("res://scripts/map_visual.gd")
const MapBridge = preload("res://scripts/map_bridge.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	RunState.relic_choice.clear()
	change_scene_to_file("res://scenes/map.tscn")
	await process_frame
	await create_timer(0.8).timeout
	var scene = current_scene
	var all := RelicRepo.load_json().all_relics().filter(func(r): return r.id != RunState.EAGLE_WHISTLE_RELIC_ID)
	for count in [0, 1, 21, 22, 42, 55]:
		RunState.relics.clear()
		for i in count:
			RunState.relics.append(all[i % all.size()].id)
		for scroll in [-100, 100]:
			scene._relic_scroll_row = scroll
			var boundary_slots: Array[Rect2] = scene._relic_slot_list()
			assert(scene._relic_scroll_row >= 0)
			var visible: Array[Rect2] = []
			for i in count:
				var rect := boundary_slots[i]
				assert(scene._relic_rect(i) == rect)
				if not rect.has_area():
					continue
				assert(Rect2(Vector2.ZERO, scene.size).encloses(rect))
				for reserved in scene._relic_reserved():
					assert(not rect.intersects(reserved))
				for previous in visible:
					assert(not rect.intersects(previous))
				visible.append(rect)
			var rows := maxi(21, ceili(count / 2.0))
			var expected := mini(count, 42) - (1 if count > 42 and count % 2 == 1 and scene._relic_scroll_row == rows - 21 else 0)
			assert(visible.size() == expected)
	scene._relic_scroll_row = 0
	RunState.relics.clear()
	for i in 28:
		RunState.relics.append(all[i].id)
	var slots: Array[Rect2] = scene._relic_slot_list()
	assert(slots[0].position.y == 56)
	assert(slots[1].position.x == slots[0].position.x and slots[1].position.y > slots[0].position.y)
	assert(slots[21].position.x < slots[0].position.x and slots[21].position.y == slots[0].position.y)
	var board := Rect2(scene.MAP_X0, scene.MAP_Y0, scene.MAP_W, scene.MAP_H)
	for i in 28:
		assert(not board.intersects(slots[i]))
		assert(not slots[i].intersects(scene._deck_btn_rect()))
		assert(not slots[i].intersects(scene._choco_panel_rect()))
	for cell: Dictionary in RunState.map_cells:
		var r: Rect2 = scene._cell_rect(cell)
		var fog := MapVisual.fog_rect(r)
		for nid in cell["doors"]:
			var bridge := MapBridge.box_of(r.get_center(), scene._cell_rect(RunState.map_cells[nid]).get_center(), MapBridge.UNSEEN, scene.CELL)
			assert(not fog.grow(-0.01).intersects(bridge), "Fog must leave the bridge corridor clear")
	await _shot(scene, "map")
	for i in range(28, mini(55, all.size())):
		RunState.relics.append(all[i].id)
	var e := InputEventMouseButton.new()
	e.position = slots[0].get_center()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	scene._gui_input(e)
	assert(scene._relic_scroll_row == 1)
	await _shot(scene, "relic_scroll")
	# Scroll through actual input to both limits, then click a visible badge.
	for direction in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		e.button_index = direction
		for step in 100:
			scene._gui_input(e)
		var before: int = scene._relic_scroll_row
		scene._gui_input(e)
		assert(scene._relic_scroll_row == before)
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = scene._relic_rect(0).get_center()
	scene._gui_input(e)
	assert(scene._relics_visible)
	scene._relics_visible = false
	for layer in [1, 2]:
		RunState.start_run(RogueMap.generate(rng, layer), layer)
		RunState.relic_choice.clear()
		await _shot(scene, "layer%d" % layer)

	RunState.start_run(RogueMap.generate(rng, 3), 3)
	RunState.relic_choice.clear()
	scene._relic_scroll_row = 0
	RunState.seen_ids.clear()
	for cell: Dictionary in RunState.map_cells:
		if not RogueMap.is_void(cell):
			assert(RunState.known_node(cell["id"]), "Third-layer rooms must all be revealed without memory or relics")
	await _shot(scene, "layer3")
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(0.8).timeout
	current_scene._map_visible = true
	await _shot(current_scene, "battle_layer3")
	print("MAP UI PASS: column-major inventory, no board/header overlap, fog/bridge clearance, wheel overflow, third layer")
	quit()

func _shot(scene, name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_map_ui/%s.png" % name))
