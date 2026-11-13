extends SceneTree
## R655 出图探针：在**战斗里**开出「设置」浮层，拍一张看层叠 / 返回文案 / 排版。
## 用法：godot --path . --script res://tools/_shot_r651_settings.gd -- --level 0
##
## 为什么不复用 `battle.tscn -- --screenshot --settings`：那条路要靠战斗自己的
## `_process` 数到 `--shotframe` 才存图，而浮层是真暂停（场景树 paused）——帧数永远
## 数不到，进程就一直挂着。本探针用 SceneTree 的 `process_frame`（暂停照发）自己数。

const OUT := "res://_shot_r651_overlay.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/battle.tscn")
	for i in 20:
		await process_frame
	var sc: Node = current_scene
	if sc == null:
		print("[R655shot] 战斗场景没起来")
		quit(1)
		return
	sc.call("_show_settings_overlay")
	for i in 20:
		await process_frame
	var ov: Variant = sc.get("_settings_overlay")
	print("[R655shot] overlay=%s paused=%s scene=%s" % [str(ov != null), str(paused), sc.name])
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("[R655shot] saved %s" % OUT)
	quit(0)
