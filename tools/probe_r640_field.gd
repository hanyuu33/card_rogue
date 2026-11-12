extends SceneTree
## R640 现场核对：**只读**玩家真实档，回答「标题页该不该亮『继续游戏』」。
## 用法：godot --headless --path . --script res://tools/probe_r640_field.gd
## ⚠️ 故意不调 load_run()：那一步会把作废档删掉，现场就没了。要看删档效果请手动备份后跑。

const RunSave = preload("res://scripts/run_save.gd")
const RunState = preload("res://scripts/run_state.gd")


func _init() -> void:
	print("存档文件存在 = %s" % str(FileAccess.file_exists(RunSave.SAVE_PATH)))
	if FileAccess.file_exists(RunSave.SAVE_PATH):
		var root: Variant = str_to_var(FileAccess.get_file_as_string(RunSave.SAVE_PATH))
		var d: Dictionary = (root as Dictionary).get("d", {})
		var sd := int(d.get("run_seed", 0))
		print("  run_seed=%d  layer=%d  node=%d  run_finished=%s"
				% [sd, int(d.get("current_layer", -1)), int(d.get("current_node_id", -9)),
				str(d.get("run_finished"))])
		print("  在通关墓碑里 = %s" % str(RunSave.is_cleared(sd)))
	print("墓碑名单 = %s" % str(RunSave.cleared_seeds()))
	print("has_save()（决定「继续游戏」亮不亮）= %s" % str(RunSave.has_save()))
	quit()
