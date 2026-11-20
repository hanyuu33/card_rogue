extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	# R843g：奖励页验收不播新手教程；否则卷卷会盖住奖励列表与三选一卡面。
	for tutorial_id in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tutorial_id)
	change_scene_to_file("res://scenes/class_pick.tscn")
	await process_frame
	await create_timer(0.6).timeout
	for d in [0, 5, 10]:
		RunState.set_difficulty(d)
		await _shot(current_scene, "difficulty_%d" % d)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(1.0).timeout
	RunState.pending_rewards = [
		{"kind": "cards", "candidates": [8002, 8004, 9010], "type": "normal", "state": "pending"},
		{"kind": "cards", "legendary": true, "candidates": [9033], "state": "pending"},
		{"kind": "relic", "id": 6001, "state": "pending"},
		{"kind": "deck_delete", "state": "pending"},
		{"kind": "core", "state": "pending"}]
	var panel = current_scene._reward_panel
	panel.open()
	await create_timer(0.4).timeout
	await _shot(panel._root, "reward_list")
	panel._scroll = panel._max_scroll()
	await _shot(panel._root, "reward_list_bottom")
	# R843g：走真实列表入口进入三选一，不能只改 _view 或拿列表页冒充验收。
	panel._scroll = 0.0
	panel._open_entry(0)
	await create_timer(0.4).timeout
	if panel._view != RewardPanel.VIEW_CARDS or panel._sel != 0:
		printerr("REWARD ICONS VISUAL FAIL: 卡牌奖励未进入真实三选一视图")
		quit(1)
		return
	await _shot(panel._root, "reward_cards")
	panel._hover_card = 1
	panel._root.queue_redraw()
	await _shot(panel._root, "reward_cards_detail")
	print("REWARD ICONS VISUAL PASS: actual battle reward list / card pick and class selection 0/5/10")
	quit()

func _shot(canvas, name: String) -> void:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_reward_icons/%s.png" % name))
