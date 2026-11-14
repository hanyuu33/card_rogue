extends SceneTree
## R667 陷阱栏「实机截图」：带一局真实 run、真实关卡 / 地图 / 货架，不是空框示意图。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r667_traps.gd -- \
##     --screenshot --shop --shotframe 9999 --target battle
##
## target：battle / battle_drag / battle_placed / map / shop / shop_full / shop_hover
## R669 追加 battle_fx7001 ~ battle_fx7004（四张触发特效的实机帧）。
## 结果写 res://_shots/r667_<target>.png。
##
## 为什么不是 `--script res://tools/_shot_scenes.gd`：那套只实例化场景、不建 run，
## 战斗 `_draw()` 第一行 `engine == null` 就直接 return，截出来是一张纯背景。
## 这里先 `start_run(RogueMap.generate())` 再实例化，battle._ready 里的
## `_load_entry_level()` 会自己建引擎、发手牌、摆敌人 —— 与玩家进战斗是同一条路径。
## 档案一律切测试档（ProfileData / RunSave.set_test_mode），外部驱动另做逐文件还原。

var _target := "battle"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--target")
	if i >= 0 and i + 1 < args.size():
		_target = args[i + 1]
	_m.call_deferred()


func _setup_run() -> void:
	# R346 / R378：绝不写玩家真实档案或存档。
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r667_%s.png" % name)
	print("[r667] SAVED %s %s" % [name, str(img.get_size())])


func _enemy_cell(sc: Variant) -> Vector2i:
	## R670：挑一个**敌方单位**所在格。特效贴在空地上一眼看不出是打谁的，
	## 六张新图都要落在有卡的位置才有验收价值。
	for cell: Vector2i in sc.engine.state.board:
		var p: Placement = sc.engine.state.unit_at(cell)
		if p != null and p.owner == GameEngine.SIDE_OPPONENT:
			return cell
	return Vector2i(3, 1)


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	_setup_run()
	var t := _target

	if t.begins_with("battle"):
		# 三槽塞满四件里的三件：一眼看全「图标 + 槽框 + 共用竖栏底」。
		RunState.traps = [7001, 7002, 7003]
		RunState.pending_node = {"type": "battle"}
		# 钉死同一关：next_level() 每次摇出的关卡不同，三张摆一起会没法对比。
		RunState.pending_level = GameLevels.builtin_levels()[0]
		var sc: Variant = load("res://scenes/battle.tscn").instantiate()
		get_root().add_child(sc)
		await _wait(48)
		# 与项目既有出图口径一致（battle_scene.gd 里多处 `_banner = {}` /
		# `_grid_intro_t = -1.0`）：收掉开场大字、巡场缩放、敌方效果弹窗与教程高亮，
		# 否则中央横幅会压住棋盘，拖放高亮看不清。
		sc._banner = {}
		sc._grid_intro_t = -1.0
		sc._ee_popup = false
		sc._tutorial = []
		sc._tutorial_finished = true
		sc._show_scroll_hint = false
		sc.status_text = ""
		sc.queue_redraw()
		await _wait(2)
		if t == "battle_drag":
			# 钉住「正在拖」的中间态：合法格高亮 + 跟手幽灵图，不真的走输入事件。
			sc._trap_drag_slot = 1
			sc._trap_drag_cells.clear()   # 泛型数组不能赋普通 []
			for c in sc.engine.trap_legal_cells():
				sc._trap_drag_cells.append(c)
			if not sc._trap_drag_cells.is_empty():
				# 取中间那格，幽灵图落在棋盘正中，不被边角元素挤掉。
				var cell: Vector2i = sc._trap_drag_cells[int(sc._trap_drag_cells.size() / 2)]
				sc._trap_drag_pos = sc._cell_center(cell)
			print("[r667] DRAG legal_cells=%d pos=%s" % [
					sc._trap_drag_cells.size(), str(sc._trap_drag_pos)])
			sc.queue_redraw()
			await _wait(3)
		elif t == "battle_placed":
			# 放置口径：槽 0 当刻清空，格子写入 trap_fields，战场上出现图案标记。
			var cells = sc.engine.trap_legal_cells()
			var placed := false
			if not cells.is_empty():
				placed = sc.engine.place_trap(7001, Vector2i(cells[0]))
				RunState.consume_trap(0)
			print("[r667] PLACED legal=%d ok=%s fields=%d" % [
					cells.size(), str(placed), sc.engine.state.trap_fields.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t.begins_with("battle_fx"):
			# R669：4 张触发特效的实机帧。走界面自己的 engine.action 事件口，
			# 让 _on_engine_action → _trap_fx → _draw_trap_fx 这条链路实跑一遍；
			# 演出时刻钉在「刚起爆」那一帧，截图才不会撞上淡出。
			var fx_id := int(t.substr(9))
			var cells4 = sc.engine.trap_legal_cells()
			var fx_ok := false
			if not cells4.is_empty() and fx_id > 0:
				var tc: Vector2i = cells4[int(cells4.size() / 2)]
				sc.engine.state.trap_fields[tc] = fx_id
				sc.engine.state.trap_fields.erase(tc)   # 触发即消失
				if cells4.size() > 1:
					var keep: Vector2i = cells4[0]
					if keep != tc:
						sc.engine.state.trap_fields[keep] = 7002   # 留一颗未触发的做对照
				sc.engine.action.emit("trap_hit", {"cell": tc, "victim": tc,
						"id": fx_id, "name": "陷阱", "damage": 0})
				for f in sc._trap_fx:
					f["start"] = sc._now() - 130
				sc._shake_until = 0
				sc.status_text = ""
				fx_ok = true
				print("[r667] TRAPFX id=%d cell=%s fx=%d" % [
						fx_id, str(tc), sc._trap_fx.size()])
			sc.queue_redraw()
			await _wait(3)
			if not fx_ok:
				print("[r667] TRAPFX MISS legal_cells empty or bad id")
		elif t.begins_with("battle_skill"):
			# R670 P1：技能卡通用施法图。走**真的** `fx_impact` 事件口 —— 界面自己按
			# 卡面 color 选图，不是手塞队列；截出来就是玩家打出这张牌看到的那一帧。
			var sk_key := t.substr(13)   # battle_skill_<key>
			var sk_colors := {"shadow": "紫", "fire": "红", "ice": "蓝",
					"holy": "金", "nature": "绿"}
			var sk_card := CardData.new()
			sk_card.color = str(sk_colors.get(sk_key, "紫"))
			sk_card.kind = "技能"
			sk_card.card_name = "技能"
			var sk_cell := _enemy_cell(sc)
			sc.engine.action.emit("fx_impact", {"cell": sk_cell, "amount": 12,
					"source": "技能", "card": sk_card})
			for sf in sc._battle_fx:
				sf["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r670] SKILLFX %s cell=%s fx=%d" % [
					sk_key, str(sk_cell), sc._battle_fx.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t == "battle_vortex":
			# R670 P0：漩涡（8012）—— 引擎发 `vortex`、界面在 `_hit_unit` 之前起漩涡。
			var vx_cell := _enemy_cell(sc)
			sc.engine.action.emit("vortex", {"cell": vx_cell, "amount": 9, "stacks": 2,
					"side": GameEngine.SIDE_OPPONENT})
			for vf in sc._battle_fx:
				vf["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r670] VORTEX cell=%s fx=%d" % [str(vx_cell), sc._battle_fx.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t == "battle_airraid":
			# R670 P0：空袭命中 —— 事件带 `cells`（全部标记格）与 `hits`（真砸到的格），
			# 界面只演 hits。这里刻意多标两格，验证「标记多、只炸命中」。
			var ar_cell := _enemy_cell(sc)
			var marks: Array[Vector2i] = [ar_cell]
			var extra := 0
			for c5 in sc.engine.trap_legal_cells():
				if extra >= 2:
					break
				var cc: Vector2i = c5
				if cc != ar_cell:
					marks.append(cc)
					extra += 1
			sc.engine.action.emit("air_raid_hit", {"cells": marks.duplicate(),
					"hits": [ar_cell], "damage": 12, "side": GameEngine.SIDE_OPPONENT})
			for af in sc._battle_fx:
				af["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r670] AIRRAID cell=%s marks=%d fx=%d" % [
					str(ar_cell), marks.size(), sc._battle_fx.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t == "battle_blast":
			# R670 P2：爆裂（B 档「只有文字/爆点」→ 素材图）。
			var bl_card := CardData.new()
			bl_card.kind = "工事"
			bl_card.card_name = "爆炎鸭"
			var bl_cell := _enemy_cell(sc)
			var bl_cells: Array[Vector2i] = [bl_cell]
			sc.engine.action.emit("blast", {"center": bl_cell, "cells": bl_cells,
					"amount": 14, "card": bl_card})
			for bf in sc._battle_fx:
				bf["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r670] BLAST cell=%s fx=%d" % [str(bl_cell), sc._battle_fx.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t.begins_with("battle_mech_"):
			# R675：机制类伤害（没有技能卡的 source）—— 一条一张帧，走**真**
			# `fx_impact` 事件口（不是手塞队列），截出来就是玩家实际看到的那一帧。
			# 六条挤在一帧里互相压着，验收时反而看不出哪张图对应哪条来源。
			var mm_key := t.substr(12)   # battle_mech_<key>
			var mm_src := {"bolt": "闪电", "omen": "噩兆", "gale": "疾风之力",
					"bot": "废弃机器人", "armor": "护甲爆发", "chimera": "黑暗嵌合"}
			var mm_cell := _enemy_cell(sc)
			sc.engine.action.emit("fx_impact", {"cell": mm_cell, "amount": 9,
					"source": str(mm_src.get(mm_key, ""))})
			if mm_key == "armor":
				# 顺带验「护甲积攒」（9141）那条空事件：己方单位身上 +护甲 的白光 + 飘字
				for mg_c in sc.engine.state.board:
					if sc.engine.state.board[mg_c].owner == GameEngine.SIDE_SELF:
						sc.engine.action.emit("armor_gain", {"cell": mg_c, "gained": 16,
								"armor": 16, "side": GameEngine.SIDE_SELF})
						break
			for mf in sc._battle_fx:
				mf["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r674] MECH %s src=%s cell=%s fx=%d" % [mm_key,
					str(mm_src.get(mm_key, "")), str(mm_cell), sc._battle_fx.size()])
			sc.queue_redraw()
			await _wait(3)
		elif t.begins_with("battle_r679_"):
			# R679：特效收尾五项 —— 一条一张帧，全走**真**事件口（不是手塞队列）。
			var rk := t.substr(12)   # battle_r679_<key>
			if rk == "poison":
				# 中毒**每回合**的持续伤害（`_poison_tick` → `_hit_unit(..,"中毒")`）。
				# 验的是「毒绿贴图 + 毒绿数字」，不是施加那一下。
				var pz_c: Vector2i = _enemy_cell(sc)
				sc.engine.action.emit("fx_impact", {"cell": pz_c, "amount": 4,
						"source": "中毒"})
			elif rk == "soul":
				# 灵魂收割者（9233）击杀回满 —— 引擎一直在发，界面原来零臂。
				var sh_c: Vector2i = _enemy_cell(sc)
				var sh_card := CardData.new()
				sh_card.kind = "敌人"
				sh_card.card_name = "灵魂收割者"
				sc.engine.action.emit("soul_harvest", {"cell": sh_c,
						"card": sh_card, "health": 22})
			elif rk == "refract":
				# 折射炮（9211）流弹 —— 只该有爆点图形，不该有两个数字。
				var rf_c: Vector2i = _enemy_cell(sc)
				sc.engine.action.emit("refract_shot", {"cell": rf_c, "amount": 7,
						"name": "灰烬鸭", "main": rf_c})
			elif rk == "hidden":
				# 隐藏能源（8078）死亡爆炸 —— 原来只有一行紫飘字。
				var hd_c: Vector2i = _enemy_cell(sc)
				sc.engine.action.emit("hidden_energy_death", {"amount": 8,
						"target": hd_c})
			elif rk == "blade":
				# 暗影之刃（9111）—— 从纯色紫圈换成 skill_shadow 素材图。
				var bd_c: Vector2i = _enemy_cell(sc)
				sc.engine.action.emit("dark_blade", {"cell": bd_c, "dmg": 11})
			for rf in sc._battle_fx:
				rf["start"] = sc._now() - 150
			sc._shake_until = 0
			sc.status_text = ""
			print("[r679] R679 %s fx=%d" % [rk, sc._battle_fx.size()])
			sc.queue_redraw()
			# R679：`fx_impact` 的伤害数字排在 `fi_at = n + 160` —— 那是**真实毫秒**，
			# 不是帧。截图模式帧率远高于 60fps，`_wait(12)` 实际只过了十几毫秒，
			# 数字根本没到点（中毒那张会变成「只有贴图、没有 -N」，看着像数字丢了）。
			# 按真实时间等 260ms：贴图总时长 620ms，这时 alpha 仍够亮，两者同框。
			var rw_t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - rw_t0 < 260:
				await process_frame
		_snap(t)

	elif t == "map":
		# 两件一空，空槽也画出来（商店判据 free_slots 的视觉依据）。
		RunState.traps = [7001, 7002, -1]
		var sc2: Variant = load("res://scenes/map.tscn").instantiate()
		get_root().add_child(sc2)
		await _wait(32)
		_snap(t)

	elif t.begins_with("shop"):
		# shop_full：栏位满 → 两个陷阱商品置灰 + 「栏位已满」遮罩。
		# shop：只带 1 件，商品可买，看清「附魔 3 / 陷阱 2」分组题签。
		# ⚠️ 不能写三元：RunState.traps 是 Array[int]，三元会把结果退化成普通 Array，
		# 赋值直接 SCRIPT ERROR 并中断 _m()（quit() 走不到 → 进程挂着直到超时）。
		if t == "shop_full":
			RunState.traps = [7001, 7002, 7003]
		else:
			RunState.traps = [7001, -1, -1]
		var sc3: Variant = load("res://scenes/shop.tscn").instantiate()
		get_root().add_child(sc3)
		await _wait(32)
		if t == "shop_hover":
			# 中行 / 第三行的价签不在格子上画，走 `_draw_goods_popup()` 的悬停浮窗
			# （第一行才用 `_draw_price`）。把鼠标钉在右组第一个陷阱商品上，
			# 一次看全「名字 + 描述 + %d 金币」，同时验金圈和浮窗不越界。
			sc3._hover = sc3._row2_base + 3
			sc3.queue_redraw()
			await _wait(2)
		_snap(t)

	else:
		print("[r667] UNKNOWN TARGET %s" % t)
	quit()
