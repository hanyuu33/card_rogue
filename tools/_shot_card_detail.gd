extends SceneTree
## R602 出图核验：单独拉起 `CardDetailOverlay`，塞一张**最长卡名**的卡，截图。
## 用法（不能 headless，否则渲染不出）：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tools/_shot_card_detail.gd

const CardRepo = preload("res://scripts/card_repo.gd")


func _initialize() -> void:
	_m.call_deferred()


func _m() -> void:
	# R631：支持 `-- --card <id>` 指定卡（默认仍是 R602 用的 9207 最长卡名），
	# 方便逐张核对效果文是否越框。
	var want := 9207
	var args := OS.get_cmdline_user_args()
	var ai := args.find("--card")
	if ai >= 0 and ai + 1 < args.size():
		want = int(args[ai + 1])
	var repo = CardRepo.load_json()
	var card = null
	for c in repo.all_cards():
		if c.id == want:
			card = c
			break
	if card == null:
		print("[shot] card %d not found" % want)
		quit()
		return
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)
	var ov = load("res://scripts/card_detail_overlay.gd").new()
	root.add_child(ov)
	ov.open(card, "组合结果预览，尚未生成")
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shot_card_detail.png")
	print("[shot] saved _shot_card_detail.png %s card=%d" % [str(img.get_size()), want])
	quit()
