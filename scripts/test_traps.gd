extends SceneTree
## R663 陷阱消耗品回归：godot --headless --path . --script res://scripts/test_traps.gd
## 覆盖 数据表 / 栏位与存档 / 放置与合法格 / 四种触发效果 / 敌我归属 / 战斗检查点。

var _ok := 0
var _bad := 0
## R669：记录引擎发出的 trap_hit / fx_impact，验「先特效事件、后伤害事件」。
var _trap_events: Array = []


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("✓ ", msg)
	else:
		_bad += 1
		print("✗ ", msg)


func _record_action(kind: String, data: Dictionary) -> void:
	## R669：只收陷阱触发与通用受击，别的事件（日志 / 状态）不进断言。
	if kind == "trap_hit" or kind == "fx_impact":
		_trap_events.append({"kind": kind, "data": data})


func _unit(id: int, hp: int, side: String) -> Placement:
	var c := CardData.new()
	c.id = id
	c.card_name = "陷阱探针"
	c.kind = "盟友"
	c.health = hp
	c.power = 0
	c.attack_range = 1
	c.move_speed = 1
	var p := Placement.new()
	p.card = c
	p.owner = side
	p.health = hp
	return p


func _engine() -> GameEngine:
	var st := FieldState.new([], 20, 20, -1, "陷阱测试", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	# 测试只看陷阱链，把关卡可能预摆的单位 / 场地清干净，合法格才稳定可断言。
	eng.state.board.clear()
	eng.state.field_effects.clear()
	eng.state.field_owner.clear()
	eng.state.trap_fields.clear()
	return eng


func _init() -> void:
	# ---- ① 数据表：四条定义与用户口径逐项对齐 ----
	var repo := TrapRepo.load_json()
	check(repo.size() == 6, "traps.json 恰好 6 件工具（4 放置型 + 2 使用型）")
	var bomb: TrapData = repo.get_trap(7001)
	var frost: TrapData = repo.get_trap(7002)
	var poison: TrapData = repo.get_trap(7003)
	var spike: TrapData = repo.get_trap(7004)
	check(bomb != null and bomb.trap_name == "炼金炸弹" and bomb.price == 30
			and bomb.damage == 18, "炼金炸弹：18 伤 / 30 金")
	check(frost != null and frost.damage == 2 and frost.freeze == 1
			and frost.price == 40, "冰冻陷阱：2 伤 + 冻结 1 回合 / 40 金")
	check(poison != null and poison.damage == 8 and poison.poison_turns == 3
			and poison.price == 30, "毒瓶：8 伤 / 持续 3 回合 / 30 金")
	check(spike != null and spike.damage == 10 and spike.root == 1
			and spike.price == 40, "穿刺陷阱：10 伤 + 禁足 1 回合 / 40 金")
	# R690：两个使用型工具（轻点即用，不放置）
	var hp_pot: TrapData = repo.get_trap(7005)
	var mana_pot: TrapData = repo.get_trap(7006)
	check(hp_pot != null and hp_pot.trap_name == "小血瓶" and hp_pot.price == 50
			and hp_pot.heal_pct == 20 and hp_pot.is_usable(),
			"小血瓶：回复 20% 生命 / 50 金 / 使用型")
	check(mana_pot != null and mana_pot.trap_name == "法力药剂" and mana_pot.price == 35
			and mana_pot.energy == 2 and mana_pot.is_usable(),
			"法力药剂：回复 2 点费用 / 35 金 / 使用型")
	check(not bomb.is_usable() and not frost.is_usable() and not poison.is_usable()
			and not spike.is_usable(), "四个放置型工具都不走使用型分支")

	# ---- ② 栏位：定长 3 槽、满了拒收、取出即空 ----
	RunState.run_active = true
	RunState.traps = [-1, -1, -1]
	check(RunState.TRAP_SLOTS == 3 and RunState.trap_free_slots() == 3,
			"开局 3 个空槽")
	check(RunState.gain_trap(7001) and RunState.gain_trap(7002)
			and RunState.gain_trap(7003), "连买 3 个都能入栏")
	check(RunState.trap_free_slots() == 0 and not RunState.gain_trap(7004),
			"满栏拒绝第 4 个（商店购买判据）")
	check(RunState.consume_trap(1) == 7002 and RunState.trap_at(1) == -1
			and RunState.trap_free_slots() == 1, "放置取出后该槽清空")

	# ---- ③ 存档：snapshot 带键、老档缺键回落、非法 id 回落 ----
	var snap := RunSave.snapshot()
	check(snap.has("traps") and snap["traps"] == RunState.traps,
			"snapshot() 持久化陷阱栏")
	var slots_old: Array[int] = RunSave._trap_slots([])
	check(slots_old.size() == 3 and slots_old[0] == -1 and slots_old[2] == -1,
			"老档缺 traps 键 → 3 空槽")
	var slots_bad: Array[int] = RunSave._trap_slots([7001, -1, 9999])
	check(slots_bad.size() == 3 and slots_bad[0] == 7001 and slots_bad[1] == -1
			and slots_bad[2] == -1, "已下架的陷阱 id 回落空槽，其余槽位保留")

	# ---- ④ 放置 / 合法格 / 战斗检查点 ----
	var e1 := _engine()
	var c31 := Vector2i(3, 1)
	var legal := e1.trap_legal_cells()
	check(legal.has(c31) and not legal.has(Vector2i(5, 1)) and not legal.has(Vector2i(1, 1)),
			"合法格 = 自己半场 row3~4（排除敌方半场与敌人进不去的 row5）")
	check(e1.place_trap(7001, c31) and int(e1.state.trap_fields.get(c31, -1)) == 7001,
			"place_trap 写进独立场地表 trap_fields")
	check(legal.has(c31), "放置前 c31 是合法格")
	var legal2 := e1.trap_legal_cells()
	check(not legal2.has(c31), "已有陷阱的格不再可放（不覆盖）")
	e1.state.board[Vector2i(4, 0)] = _unit(9001, 60, GameEngine.SIDE_OPPONENT)
	check(not e1.trap_legal_cells().has(Vector2i(4, 0)), "有单位的格不可放")
	var ck := e1.state.save_dict()
	check(ck.has("trap_fields") and (ck["trap_fields"] as Array).size() == 1,
			"战斗检查点存 trap_fields")
	var e1b := _engine()
	e1b.state.apply_dict(ck)
	check(int(e1b.state.trap_fields.get(c31, -1)) == 7001,
			"战斗检查点还原陷阱")

	# ---- ⑤ 炼金炸弹：敌方踩 → 18 伤 + 消失；我方踩 → 不触发 ----
	var e2 := _engine()
	e2.action.connect(_record_action)
	_trap_events.clear()
	e2.state.trap_fields[c31] = 7001
	var foe2: Placement = _unit(9002, 60, GameEngine.SIDE_OPPONENT)
	e2.state.board[c31] = foe2
	e2._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe2.health == 42, "炼金炸弹：18 点伤害")
	check(not e2.state.trap_fields.has(c31), "炼金炸弹：触发后「消失」= 本场移除")
	check(_trap_events.size() >= 2 and _trap_events[0]["kind"] == "trap_hit"
			and _trap_events[1]["kind"] == "fx_impact",
			"R669 事件序：trap_hit 先于 fx_impact（先起爆、后掉血）")
	check(_trap_events.size() >= 2 and int(_trap_events[0]["data"]["id"]) == 7001
			and _trap_events[0]["data"]["cell"] == c31
			and _trap_events[0]["data"]["victim"] == c31
			and int(_trap_events[0]["data"]["damage"]) == 18
			and str(_trap_events[0]["data"]["name"]) == "炼金炸弹",
			"R669 trap_hit 载荷：cell / victim / id / name / damage 齐全")
	check(_trap_events.size() >= 2 and str(_trap_events[1]["data"].get("source", "")) == "陷阱"
			and int(_trap_events[1]["data"]["amount"]) == 18,
			"R669：素材演出不挡通用受击，-18 伤害数字照常落")

	var e3 := _engine()
	e3.action.connect(_record_action)
	_trap_events.clear()
	e3.state.trap_fields[c31] = 7001
	var mine3: Placement = _unit(9003, 60, GameEngine.SIDE_SELF)
	e3.state.board[c31] = mine3
	e3._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_SELF)
	check(mine3.health == 60 and e3.state.trap_fields.has(c31),
			"我方踩到自己的陷阱：不触发、不消耗")
	check(_trap_events.is_empty(), "R669：我方踩到不触发 → 不播特效事件")

	# ---- ⑥ 冰冻 / 穿刺 / 毒瓶 ----
	var e4 := _engine()
	e4.state.trap_fields[c31] = 7002
	var foe4: Placement = _unit(9004, 60, GameEngine.SIDE_OPPONENT)
	e4.state.board[c31] = foe4
	e4._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe4.health == 58 and foe4.frozen, "冰冻陷阱：2 伤 + 冻结标记")

	var e5 := _engine()
	e5.state.trap_fields[c31] = 7004
	var foe5: Placement = _unit(9005, 60, GameEngine.SIDE_OPPONENT)
	e5.state.board[c31] = foe5
	e5._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe5.health == 50 and foe5.rooted == 1, "穿刺陷阱：10 伤 + 禁足待下回合生效")

	var e6 := _engine()
	e6.state.trap_fields[c31] = 7003
	var foe6: Placement = _unit(9006, 60, GameEngine.SIDE_OPPONENT)
	e6.state.board[c31] = foe6
	e6._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe6.health == 52 and foe6.poison_left == 2
			and foe6.poison_dmg == 8, "毒瓶：踩到 8 伤 + 统一中毒账本剩 2 跳")
	e6._poison_tick(GameEngine.SIDE_SELF)
	check(foe6.health == 52, "毒瓶：我方回合结束不结算敌方中毒")
	e6._poison_tick(GameEngine.SIDE_OPPONENT)
	check(foe6.health == 44 and foe6.poison_left == 1, "毒瓶：敌人回合结束第 1 跳")
	e6._poison_tick(GameEngine.SIDE_OPPONENT)
	check(foe6.health == 36 and foe6.poison_left == 0
			and foe6.poison_dmg == 0, "毒瓶：第 2 跳后账本归零（共 3 次结算）")
	# 统一口径：与毒沼共用账本 → 弱毒不覆盖强毒、但会刷新持续时间
	var foe6b: Placement = _unit(9006, 60, GameEngine.SIDE_OPPONENT)
	e6._apply_poison(foe6b, 4, 5)
	check(foe6b.poison_dmg == 4 and foe6b.poison_left == 5,
			"毒瓶 / 毒沼共用施加口 _apply_poison")

	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----
	var e7 := _engine()
	e7.state.max_hp_self = 50
	e7.state.hp_self = 20
	e7.state.energy = 1
	check(e7.use_tool(7005), "小血瓶：use_tool 返回 true")
	check(e7.state.hp_self == 30, "小血瓶：20 → 30（最大 50 的 20% = 10）")
	check(e7.use_tool(7006), "法力药剂：use_tool 返回 true")
	check(e7.state.energy == 3, "法力药剂：费用 1 → 3（+2）")
	e7.state.hp_self = e7.state.max_hp_self
	e7.use_tool(7005)
	check(e7.state.hp_self == e7.state.max_hp_self, "小血瓶：满血不溢出上限")
	check(not e7.use_tool(7001), "炼金炸弹不能用 use_tool（它要放置）")

	# ---- ⑦ 源码守卫：三处 UI 与引擎接线不许被后续改动抹掉 ----
	var shop_src := FileAccess.get_file_as_string("res://scripts/shop_scene.gd")
	var battle_src := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	var map_src := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	var ui_src := FileAccess.get_file_as_string("res://scripts/ui_assets.gd")
	var eng_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	var place_src := FileAccess.get_file_as_string("res://scripts/placement.gd")
	var trap_src := FileAccess.get_file_as_string("res://scripts/trap_art.gd")
	check(shop_src.contains("TRAP_GROUP_GUTTER") and shop_src.contains("rr.size.x - 24.0"),
			"商店：中行左右分组 + 图标格宽上限")
	check(shop_src.contains("TRAP_SHOP_COUNT := 2") and shop_src.contains("_buy_trap"),
			"商店：右组 2 个工具商品与购买分支")
	check(battle_src.contains("_trap_drag_slot") and battle_src.contains("_draw_trap_bar"),
			"战斗：独立拖拽状态 + 自绘 3 槽栏")
	check(map_src.contains("_draw_trap_slots"), "地图：左下只读工具栏")
	check(ui_src.contains("trap_slot_frame") and ui_src.contains("trap_bar_bg")
			and ui_src.contains("trap_group_tag"), "UI 素材：4 张贴图槽位已注册")
	check(battle_src.contains("draw_bar_bg") and map_src.contains("draw_slot_frame"),
			"UI 素材：战斗 / 地图栏位已接贴图口")
	check(not eng_src.contains("trap_poison_left")
			and not place_src.contains("trap_poison_left"),
			"统一口径：毒瓶不再单开中毒账本")
	check(eng_src.contains("action.emit(\"trap_hit\"")
			and eng_src.contains("func _trigger_trap"),
			"R669：引擎触发口发出 trap_hit 视觉事件")
	check(ui_src.contains("trap_fx_path") and ui_src.contains("static func trap_fx("),
			"R669：素材图取图口已注册")
	check(battle_src.contains("_draw_trap_fx") and battle_src.contains("TrapArt.draw_trigger_fx")
			and trap_src.contains("draw_trigger_fx"),
			"R669：战场绘制口与 TrapArt 素材绘制口已接线")
	check(eng_src.contains("func use_tool") and battle_src.contains("_use_tool_slot")
			and trap_src.contains("_potion"),
			"R690：使用型工具的引擎 / 界面 / 图标三处接线")
	check(battle_src.contains("is_usable") and battle_src.contains("点一下就能用"),
			"R690：使用型工具拒绝进入拖放（轻点即用）")
	var fx_all := true
	for fx_id in [7001, 7002, 7003, 7004]:
		if not FileAccess.file_exists(UiAssets.trap_fx_path(int(fx_id))):
			fx_all = false
	check(fx_all, "R669：4 张 codex 触发特效贴图已落 assets/fx")

	RunState.traps = [-1, -1, -1]
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
	quit(1 if _bad > 0 else 0)
