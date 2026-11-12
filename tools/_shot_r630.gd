extends SceneTree
## R630 排查用：按需截「需要数据才有内容」的界面。
## 用法：Godot --path . --script res://tools/_shot_r630.gd -- --target summary
## 不要加 --headless（否则渲染不出）。

var _target := "summary"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--target")
	if i >= 0 and i + 1 < args.size():
		_target = args[i + 1]
	_m.call_deferred()


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	if _target == "summary":
		RunState.run_summary = {
			"class": PlayerClass.DRUID, "difficulty": 6,
			"layer": GameLayers.LAYER_THREE,
			"damage": 13847, "seconds": 4823, "battles": 24, "elites": 5,
		}
	var path := "res://scenes/%s.tscn" % _target
	var ps := load(path) as PackedScene
	if ps == null:
		print("[shot] load fail %s" % path)
		quit()
		return
	var inst: Node = ps.instantiate()
	get_root().add_child(inst)
	# 结算页有 1.6s 的滚动动画，多等一会儿让数字落定
	for i in 180:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/%s_full.png" % _target)
	print("[shot] %s %s" % [_target, str(img.get_size())])
	quit()
