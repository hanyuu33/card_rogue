extends SceneTree
## R842 龙石板事件页实机截图（**不能加 --headless**，否则渲染不出）。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r842_event.gd -- --mode normal
## 结果写 res://_shots/r842_dragon_slab_<mode>.png
##
## mode：
##   normal —— 卡组里 5 张树人 + 4 张火焰箭（稀有价值会撕 3 张），血量够 → 两个选项都可点
##   lethal —— 同上但只剩 10 点血（15 点伤害会当场倒下）→ 「尊贵的龙」应置灰
##   noally —— 卡组全是技能 / 效果卡 → 「强力的龙」应置灰

var _mode := "normal"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--mode")
	if i >= 0 and i + 1 < args.size():
		_mode = args[i + 1]
	_m.call_deferred()


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	RunState.run_active = true
	RunState.pending_node = {"type": "event", "id": 3}
	RunState.pending_event = "dragon_slab"
	RunState.relics = []
	RunState.spent_relics = []
	RunState.max_hp = 60
	RunState.hp = 60
	if _mode == "noally":
		RunState.deck_ids = [9003, 9003, 9003, 9003, 9003, 9180]
	else:
		# 树人 8003 = 盟友；火焰箭 9003 = 技能。5 同名 + 4 同名 → 撕 3 张 = 15 点。
		RunState.deck_ids = [8003, 8003, 8003, 8003, 8003, 9003, 9003, 9003, 9003]
	if _mode == "lethal":
		RunState.max_hp = 20
		RunState.hp = 10
	RunState.deck_mods = []
	RunState.ensure_deck_mods()

	var ps := load("res://scenes/event.tscn") as PackedScene
	if ps == null:
		print("[shot] load fail")
		quit()
		return
	var inst: Node = ps.instantiate()
	get_root().add_child(inst)
	for i in 90:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r842_dragon_slab_%s.png" % _mode)
	print("[shot] r842 %s %s" % [_mode, str(img.get_size())])
	quit()
