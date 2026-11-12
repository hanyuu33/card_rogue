extends SceneTree
## R613b 出图：战场单位卡顶部的「文字标签」删改验证。
##
## 店长口径（2026-11-12）：次元 / 速+N / 距离+N 还是文字标签 → 删掉，只留可发动。
## 本图用**真实战斗场景**渲染（change_scene_to_file + 注入 Placement），
## 直接走 `_draw_board_unit` → `CardFace.draw(on_board=true)` 的真链路，不重画。
##
## 注入三格：
##   (2,1) 带「次元」的复制野兔 + 护盾 + 改造 2 → 以前顶部会叠「次元 / 护盾 / 改造 ×2」文字条，
##         现在只应剩卡面右上角「次元」glyph（其余文字条已删）。
##   (1,1) 普通友军（对照，无任何标记）。
##   (3,1) 铁壁卫兵（嘲讽 → 带环标记，确认「标记」类保留）。
##
## 跑法：Godot --path . --script res://tools/shot_r613b_board.gd
## ⚠️ 不能 --headless（dummy 渲染器下 get_image() 返回 null）。

const CardRepo = preload("res://scripts/card_repo.gd")
const CardData = preload("res://scripts/card_data.gd")
const Placement = preload("res://scripts/placement.gd")
const GameEngine = preload("res://scripts/game_engine.gd")


func _initialize() -> void:
	_run.call_deferred()


func _mk(repo: CardRepo, id: int, affixes: Array, owner: String) -> Placement:
	var c: CardData = repo.get_card(id)
	var cd: Dictionary = c.to_dict()
	cd["affixes"] = affixes
	var card: CardData = CardData.from_dict(cd)
	var p: Placement = Placement.new()
	p.card = card
	p.owner = owner
	p.health = card.health
	p.acts_left = 1
	p.acts_total = 1
	p.tapped = false
	p.entry_seq = 1
	return p


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(1.2).timeout
	var scene = current_scene
	var eng = scene.engine
	var repo: CardRepo = CardRepo.load_json()

	# 跳过开场动画 / 横幅，避免遮挡
	scene._grid_intro_t = -1.0
	scene._banner = {}
	scene._grid_scroll = 0

	# —— 注入单位 ——
	var dim := _mk(repo, 9032, ["次元"], GameEngine.SIDE_SELF)   # 复制野兔：次元
	dim.is_ephemeral = true
	dim.first_hit_shield = true      # 以前 → 顶部「护盾」文字条
	dim.upgrade_stacks = 2           # 以前 → 顶部「改造 ×2」文字条
	eng.state.board[Vector2i(2, 1)] = dim
	eng.state.field_owner[Vector2i(2, 1)] = GameEngine.SIDE_SELF

	var plain := _mk(repo, 1001, [], GameEngine.SIDE_SELF)        # 对照：普通友军
	eng.state.board[Vector2i(1, 1)] = plain
	eng.state.field_owner[Vector2i(1, 1)] = GameEngine.SIDE_SELF

	var taunt := _mk(repo, 1011, [], GameEngine.SIDE_SELF)        # 嘲讽：带环标记（保留）
	eng.state.board[Vector2i(3, 1)] = taunt
	eng.state.field_owner[Vector2i(3, 1)] = GameEngine.SIDE_SELF

	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.3).timeout
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

	var out := "res://art_src/2026-11-12_野兔标记_R613/_review/board_labels.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://art_src/2026-11-12_野兔标记_R613/_review"))
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE（是不是加了 --headless？）")
		quit(1)
		return
	img.save_png(out)
	print("SHOT OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()
