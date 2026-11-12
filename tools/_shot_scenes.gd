extends SceneTree
## R602 批量出图：逐个拉起界面场景，等布局结算后截图，存到 res://_shots/。
## 用法（**不能** headless，否则渲染不出）：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tools/_shot_scenes.gd
## 只读：不写存档、不跑存档流程；场景 _ready 若依赖 RunState 可能空白，图仍可看框体。

const SCENES := [
	"res://scenes/title.tscn",
	"res://scenes/class_pick.tscn",
	"res://scenes/relic_pick.tscn",
	"res://scenes/settings.tscn",
	"res://scenes/record_list.tscn",
	"res://scenes/run_summary.tscn",
	"res://scenes/deck_edit.tscn",
	"res://scenes/shop.tscn",
	"res://scenes/event.tscn",
	"res://scenes/map.tscn",
	"res://scenes/codex.tscn",
	"res://scenes/story.tscn",
	"res://scenes/credits.tscn",
]


func _initialize() -> void:
	_m.call_deferred()


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	for p: String in SCENES:
		var ps := load(p) as PackedScene
		if ps == null:
			print("[shot] load fail %s" % p)
			continue
		var inst: Node = ps.instantiate()
		get_root().add_child(inst)
		for i in 6:
			await process_frame
		var img := get_root().get_texture().get_image()
		var name := p.get_file().get_basename()
		img.save_png("res://_shots/%s.png" % name)
		print("[shot] %s %s" % [name, str(img.get_size())])
		inst.queue_free()
		await process_frame
	quit()
