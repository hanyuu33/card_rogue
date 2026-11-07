extends SceneTree
## R519 宽屏适配出图：把整套场景在指定窗口尺寸下各截一张，用来对比「右侧空区域」。
## 用法：godot --path . --resolution 1920x720 -s art_src/2026-11-07_职业CG裁切/tools/shoot_wide.gd
## 产物：art_src/2026-11-07_职业CG裁切/_review/<tag>_<scene>.png
const OUT_DIR := "res://art_src/2026-11-07_职业CG裁切/_review"

var _tag := "wide"
var _cls := 1   # 选职业页截哪一位（0 森林精灵 / 1 暗影刺客 / 2 机械之心）


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.substr(6)
		if a.begins_with("--cls="):
			_cls = int(a.substr(6))
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	RunState.relic_choice.clear()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for name in ["title", "settings", "gallery", "class_pick", "map", "battle",
			"shop", "story", "record_list", "event", "deck_edit"]:
		if only != "" and name != only:
			continue
		change_scene_to_file("res://scenes/%s.tscn" % name)
		await process_frame
		await create_timer(0.7).timeout
		if name == "class_pick":
			current_scene._selected = _cls
		if name == "battle":
			current_scene._banner = {}
			current_scene._map_visible = true
		current_scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [OUT_DIR, _tag, name]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("shot ", path)
	print("WIDE CAPTURE DONE")
	quit()
