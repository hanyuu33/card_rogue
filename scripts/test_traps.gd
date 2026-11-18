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
	# R745：新增野性图腾 7008（使用型）→ 8 件（4 放置型 + 4 使用型）
	# R752：新增万能牌 7009 / 快送鸭 7010 / 神秘牌 7011（都是使用型、都没有售价）→ 11 件
	# R754：新增石头 7012（**直接伤害型**：拖到敌方单位身上砸 15；no_drop）→ 12 件
	# R797：新增河豚 7015（**放置型**：踩到回弹一格 + 3 伤）→ 15 件
	check(repo.size() == 15, "traps.json 恰好 15 件工具（5 放置 + 1 直接伤害 + 9 使用型）")
	var bomb: TrapData = repo.get_trap(7001)
	var frost: TrapData = repo.get_trap(7002)
	var poison: TrapData = repo.get_trap(7003)
	var spike: TrapData = repo.get_trap(7004)
	# R797：全部带售价的工具各 -5（炼金炸弹 30 → 25 起），往下逐条同改。
	check(bomb != null and bomb.trap_name == "炼金炸弹" and bomb.price == 25
			and bomb.damage == 18, "炼金炸弹：18 伤 / 25 金")
	check(frost != null and frost.damage == 2 and frost.freeze == 1
			and frost.price == 35, "冰冻陷阱：2 伤 + 冻结 1 回合 / 35 金")
	check(poison != null and poison.damage == 8 and poison.poison_turns == 3
			and poison.price == 25, "毒瓶：8 伤 / 持续 3 回合 / 25 金")
	check(spike != null and spike.damage == 10 and spike.root == 1
			and spike.price == 35, "穿刺陷阱：10 伤 + 禁足 1 回合 / 35 金")
	# R690：两个使用型工具（轻点即用，不放置）
	var hp_pot: TrapData = repo.get_trap(7005)
	var mana_pot: TrapData = repo.get_trap(7006)
	check(hp_pot != null and hp_pot.trap_name == "小血瓶" and hp_pot.price == 45
			and hp_pot.heal_pct == 20 and hp_pot.is_usable(),
			"小血瓶：回复 20% 生命 / 50 金 / 使用型")
	check(mana_pot != null and mana_pot.trap_name == "法力药剂" and mana_pot.price == 30
			and mana_pot.energy == 2 and mana_pot.is_usable(),
			"法力药剂：回复 2 点费用 / 35 金 / 使用型")
	check(not bomb.is_usable() and not frost.is_usable() and not poison.is_usable()
			and not spike.is_usable(), "四个放置型工具都不走使用型分支")
	# R743：烤肉（7007）—— 休息处专属的使用型工具（原道具 6011 改造而来）
	var bbq: TrapData = repo.get_trap(7007)
	check(bbq != null and bbq.trap_name == "烤肉" and bbq.heal_pct == 25
			and bbq.is_usable() and bbq.rest_only and bbq.price == 0,
			"烤肉：回复 25% 最大生命 / 使用型 / rest_only（非卖品）")
	check(repo.random_traps().size() == 13 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（13 件可随机），全量仍是 15 件")
	# R752：野性图腾售价按店长口径 45 → 30；R797 全体 -5 → 25
	check(repo.get_trap(7008).price == 25, "野性图腾：商店售价 25")
	# R752：三件新工具 —— 都是使用型、都没有售价（= 不进商店）
	var wild: TrapData = repo.get_trap(7009)
	var duck_tool: TrapData = repo.get_trap(7010)
	var mystic: TrapData = repo.get_trap(7011)
	check(wild != null and wild.trap_name == "万能牌" and wild.pick_kind == "deck_copy"
			and wild.is_usable() and wild.price == 0 and not wild.in_shop(),
			"万能牌 7009：pick_kind=deck_copy / 使用型 / 没有售价（不进商店）")
	check(duck_tool != null and duck_tool.trap_name == "快送鸭" and duck_tool.fill_toolbar
			and duck_tool.is_usable() and duck_tool.price == 0 and not duck_tool.in_shop(),
			"快送鸭 7010：fill_toolbar / 使用型 / 没有售价（不进商店）")
	check(mystic != null and mystic.trap_name == "神秘牌" and mystic.pick_kind == "random3"
			and mystic.is_usable() and mystic.price == 0 and not mystic.in_shop(),
			"神秘牌 7011：pick_kind=random3 / 使用型 / 没有售价（不进商店）")
	# 商店池（R752 新增的判据口）：有售价的 7 件；三件新工具与烤肉都不在里面
	var shop_pool: Array[TrapData] = repo.shop_traps()
	var shop_ids: Array[int] = []
	for sp: TrapData in shop_pool:
		shop_ids.append(int(sp.id))
	check(shop_pool.size() == 10 and not shop_ids.has(7007)
			and not shop_ids.has(7009) and not shop_ids.has(7010) and not shop_ids.has(7011),
			"`shop_traps()` = 10 件有售价的（烤肉与三件非卖品都被排除；R796/R797 新工具都有售价）")
	check(shop_ids.has(7008), "野性图腾售价 25 → 仍在商店货架上")
	# R754 石头 7012：事件「奇异雕像」的摧毁选项给的，**直接伤害型**
	var stone: TrapData = repo.get_trap(7012)
	check(stone != null and stone.trap_name == "石头" and stone.direct_damage == 15
			and stone.price == 0 and stone.no_drop and not stone.is_usable(),
			"石头 7012：15 点直接伤害 / 非卖品 / no_drop / 不算使用型（要落点）")
	check(not shop_ids.has(7012), "石头不进商店货架（没有售价）")
	var drop_ids: Array[int] = []
	for dt: TrapData in repo.random_traps():
		drop_ids.append(int(dt.id))
	check(not drop_ids.has(7012), "石头不进随机掉落 / 工具箱池（no_drop）")
	# R796：卡牌包 7013（随机卡填满手牌）/ 智慧药剂 7014（抽 3 张）——
	# 都是使用型、都有售价（能掉落也能买），进商店也进随机池。
	var cardpack: TrapData = repo.get_trap(7013)
	var wisdom: TrapData = repo.get_trap(7014)
	check(cardpack != null and cardpack.trap_name == "卡牌包" and cardpack.fill_hand
			and cardpack.price == 50 and cardpack.is_usable(),
			"卡牌包 7013：fill_hand / 使用型 / 50 金")
	check(wisdom != null and wisdom.trap_name == "智慧药剂" and wisdom.draw_cards == 3
			and wisdom.price == 35 and wisdom.is_usable(),
			"智慧药剂 7014：抽 3 张 / 使用型 / 35 金")
	check(shop_ids.has(7013) and shop_ids.has(7014)
			and drop_ids.has(7013) and drop_ids.has(7014),
			"R796 两件新工具：既进商店货架、也进随机掉落池")
	# R797：河豚 7015 —— **放置型**（bounce，不是使用型），踩到回弹一格 + 3 伤，25 金
	var puffer: TrapData = repo.get_trap(7015)
	check(puffer != null and puffer.trap_name == "河豚" and puffer.bounce == 1
			and puffer.damage == 3 and puffer.price == 25
			and not puffer.is_usable() and not puffer.no_drop,
			"河豚 7015：回弹 1 格 + 3 伤 / 放置型 / 25 金")
	check(shop_ids.has(7015) and drop_ids.has(7015),
			"河豚 7015：既进商店货架、也进随机掉落池")

	# ---- ①b R690：描述必须写清「怎么发动」—— 放置型拖到格子、使用型轻点 ----
	# 玩家唯一能读到操作方式的地方就是这条 desc（商店悬浮、战斗里轻点工具栏）。
	# 断言读原始底本 traps.json：TrapData.desc 会按当前语言翻译，不能用来验中文口径。
	var raw_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://traps.json"))
	var op_bad := ""
	if not (raw_doc is Dictionary):
		op_bad = "traps.json 读不出来"
	else:
		var raw_rows: Dictionary = {}
		for row in raw_doc.get("traps", []):
			raw_rows[str(int(row.get("id", 0)))] = str(row.get("desc", ""))
		for tid in ["7001", "7002", "7003", "7004", "7015"]:
			if not str(raw_rows.get(tid, "")).contains("拖到战场空格上放置"):
				op_bad += "%s 缺拖放说明 " % tid
		# R752：交互改成「点两下」（第一下弹出「使用」，第二下才结算），
		# 所以使用型工具的说明也统一写成「轻点两下即可使用」。
		for tid in ["7005", "7006", "7007", "7008", "7009", "7010", "7011",
				"7013", "7014"]:
			var d := str(raw_rows.get(tid, ""))
			if not d.contains("轻点两下即可使用") or not d.contains("无需拖到战场格子上"):
				op_bad += "%s 缺轻点说明 " % tid
		for tid in raw_rows:
			if str(raw_rows[tid]).contains("陷阱消失"):
				op_bad += "%s 残留旧机制名 " % tid
	check(op_bad == "", "每件工具都写明发动方式（拖到格子 / 轻点两下）%s"
			% ("" if op_bad == "" else " —— " + op_bad.strip_edges()))

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
	# R763c（用户口径「陷阱类工具，需要可以放到对方场地上」）：
	# 敌方半场 row0~2 也合法，只剩「敌人永远踩不到的我方 row5」被排除。
	check(legal.has(c31) and not legal.has(Vector2i(5, 1)) and legal.has(Vector2i(1, 1)),
			"R763c 合法格 = 全盘（含敌方半场 row0~2），只排除敌人进不去的 row5")
	check(legal.has(Vector2i(0, 2)) and legal.has(Vector2i(1, 0))
			and legal.has(Vector2i(2, 1)),
			"R763c 敌方半场三行（后排/中排/前排）都可放")
	check(legal.size() == 15, "R763c 6×3 = 18 格减我方后排 3 格 = 15 个合法格（%d）" % legal.size())
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

	# ---- ④b R763c：敌方半场埋得下，敌人经过照常触发 ----
	var e1c := _engine()
	var foe_cell := Vector2i(1, 2)
	check(e1c.trap_legal_cells().has(foe_cell), "R763c 敌方半场 (1,2) 是合法落点")
	check(e1c.place_trap(7001, foe_cell), "R763c place_trap 接受敌方半场")
	check(int(e1c.state.trap_fields.get(foe_cell, -1)) == 7001,
			"R763c 敌方半场格写进了 trap_fields")
	var foe_in_half: Placement = _unit(9003, 60, GameEngine.SIDE_OPPONENT)
	e1c.state.board[foe_cell] = foe_in_half
	e1c._trap_path_check([Vector2i(1, 0), foe_cell], GameEngine.SIDE_OPPONENT)
	check(foe_in_half.health == 42, "R763c 敌人踩到敌方半场的陷阱：18 点伤害")
	check(not e1c.state.trap_fields.has(foe_cell), "R763c 敌方半场陷阱触发后消失")

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

	# ---- ⑥d R797：河豚 7015 —— 踩到回弹一格 + 3 伤 ----
	# 回弹方向 = 来路（`_trap_path_check` 把 path[i-1] 传进 `_trigger_trap`）。
	var e8 := _engine()
	e8.state.trap_fields[c31] = 7015
	var foe8: Placement = _unit(9008, 60, GameEngine.SIDE_OPPONENT)
	e8.state.board[c31] = foe8
	e8._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe8.health == 57, "河豚：踩到受 3 点伤害")
	check(e8.state.unit_at(Vector2i(2, 1)) == foe8 and not e8.state.board.has(c31),
			"河豚：被弹回来时的格子（3,1 → 2,1）")
	check(not e8.state.trap_fields.has(c31), "河豚：触发后从场上摘掉（一次性的）")

	# 来路不可用（这里直接给 `_bounce_unit` 一个哨兵值 = 效果直达 / 没有路径）→ 朝我方弹一格
	var e9 := _engine()
	var foe9: Placement = _unit(9009, 60, GameEngine.SIDE_OPPONENT)
	e9.state.board[c31] = foe9
	e9._bounce_unit(foe9, Vector2i(-1, -1), TrapRepo.load_json().get_trap(7015))
	check(e9.state.unit_at(Vector2i(4, 1)) == foe9 and not e9.state.board.has(c31),
			"河豚：没有来路 → 朝我方（行号 +1）弹一格")

	# 落点已经在棋盘外 / 被占 → 原地不动，但仍然吃伤害
	var e10 := _engine()
	var far := Vector2i(5, 2)
	e10.state.trap_fields[far] = 7015
	var foe10: Placement = _unit(9010, 60, GameEngine.SIDE_OPPONENT)
	e10.state.board[far] = foe10
	# 来路给一个越界格：既不能回去、朝我方那一格（6,2）也越界 → 留在原地
	e10._trigger_trap(far, foe10, Vector2i(6, 2))
	check(foe10.health == 57 and e10.state.unit_at(far) == foe10,
			"河豚：无处可弹 → 留在原地（伤害照算）")

	# 我方踩自己的河豚：不触发（与其它陷阱同口径）
	var e11 := _engine()
	e11.state.trap_fields[c31] = 7015
	var mine11: Placement = _unit(9011, 60, GameEngine.SIDE_SELF)
	e11.state.board[c31] = mine11
	e11._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_SELF)
	check(mine11.health == 60 and e11.state.trap_fields.has(c31),
			"河豚：我方踩到不触发、不消耗")

	# 河豚被弹回之后，`move()` 里「移动后有没有攻击目标」必须按**实际落点**判 ——
	# 否则单位站在 2 排还能打到 3 排旁边的盟友（幽灵攻击），AI 白转一圈还留着行动权。
	var e12 := _engine()
	e12.state.trap_fields[Vector2i(3, 1)] = 7015
	var foe12: Placement = _unit(9012, 60, GameEngine.SIDE_OPPONENT)
	e12.state.board[Vector2i(2, 1)] = foe12
	var ally12: Placement = _unit(9013, 30, GameEngine.SIDE_SELF)
	e12.state.board[Vector2i(4, 1)] = ally12
	e12.move(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(e12.state.unit_at(Vector2i(2, 1)) == foe12,
			"河豚：move() 走完被弹回 (2,1)")
	check(foe12.tapped,
			"河豚：弹回后身边没有目标 → 按新位置判「放弃攻击」（不出现幽灵攻击）")
	check(ally12.health == 30, "河豚：盟友没被隔空打到")

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

	# ---- ⑥c R694：任何战斗 10% 概率掉落工具 ----
	# 概率 / 满栏 / 入队 / 领取 / 放弃 五件事都钉在这里；「哪一类战斗」由
	# `battle_scene` 的调用点决定（它不收 node_type，所以普通、精英、Boss、事件遭遇战
	# 走的是同一条路）。
	check(is_equal_approx(RunState.TOOL_DROP_CHANCE, 0.10), "掉落概率常量就是 10%")
	var saved_seed := RunState.run_seed
	RunState.run_seed = 20261114
	RunState.tool_roll_seq = 0
	# 1000 场：每场先清空栏位，只测「摇不摇得中」。二项分布 n=1000 p=0.1 的 ±3σ ≈ ±9.5，
	# 所以放宽到 70~130 —— 掉率真漂成 5% 或 15% 一定被抓到，又不会因为个别取样变随机红。
	var hits := 0
	for i in 1000:
		RunState.traps = [-1, -1, -1]
		if RunState.roll_battle_tool_drop() > 0:
			hits += 1
	check(hits >= 70 and hits <= 130, "1000 场战斗的掉率落在 70~130 次（实测 %d）" % hits)
	# R695（用户口径「我希望满栏掉落」）：满栏（3/3）**照样按 10% 掉** ——
	# 旧版在这里 `return -1`，于是满栏玩家永远刷不出工具（10% 悄悄变成 0%）。
	# 装不进去已有两条出路：工具栏的 ×（丢弃）+ 奖励页的「换一个」。
	RunState.traps = [7001, 7002, 7003]
	var full_hits := 0
	for i in 200:
		if RunState.roll_battle_tool_drop() > 0:
			full_hits += 1
	check(full_hits >= 8 and full_hits <= 32,
			"工具栏满（3/3）时照样按 10%% 掉（200 场实测 %d）" % full_hits)
	# 满栏掉出来的工具也能一路走到「领进来」：丢弃一个旧槽就行（数据层口）。
	var full_id := 7004
	RunState.traps = [7001, 7002, 7003]
	check(RunState.queue_tool_reward(full_id), "满栏时工具照样能入奖励队列")
	var full_idx := RunState.pending_rewards.size() - 1
	check(not RunState.claim_pending_reward(full_idx),
			"满栏直接领 → 拒绝（不是静默吞掉，界面据此摊开「换一个」栏位）")
	check(RunState.discard_trap(1) == 7002, "丢弃第 2 个栏位：返回被丢的 id")
	check(RunState.trap_at(1) == -1, "丢弃后该栏位空出来")
	check(RunState.claim_pending_reward(full_idx)
			and RunState.trap_at(1) == full_id,
			"腾出位置后同一条奖励立刻能领进来（补的就是刚空出来的槽）")
	RunState.pending_rewards.remove_at(full_idx)
	# 丢弃不产生任何退款 / 记录：`discard_trap` 只搬栏位（与 `consume_trap` 同形不同义）。
	RunState.traps = [7001, -1, -1]
	check(RunState.discard_trap(0) == 7001 and RunState.trap_at(0) == -1,
			"丢弃 = 从栏位移除，不改成别的什么")
	check(RunState.discard_trap(0) == -1, "空槽丢弃返回 -1（界面静默）")
	# 入队 → 领取：工具进空槽、条目置为已领取
	RunState.traps = [-1, -1, -1]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	var idx := RunState.pending_rewards.size() - 1
	check(idx == 0 and str(RunState.pending_rewards[idx].get("kind", "")) == "tool",
			"掉落的工具以 kind=tool 入奖励队列")
	check(RunState.claim_pending_reward(idx), "工具奖励能领取")
	check(RunState.traps.has(7005), "领取后填进工具栏")
	check(str(RunState.pending_rewards[idx].get("state", "")) == RunState.REWARD_CLAIMED,
			"领取后条目置为已领取")
	# 放弃：不占栏位、条目置灰（不登记「本局不再出」—— 工具没有这个语义）
	RunState.traps = [-1, -1, -1]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7006)
	var idx2 := RunState.pending_rewards.size() - 1
	check(RunState.skip_pending_reward(idx2), "工具奖励能放弃")
	check(not RunState.traps.has(7006)
			and str(RunState.pending_rewards[idx2].get("state", "")) == RunState.REWARD_SKIPPED,
			"放弃后既不进栏位、条目也置为已放弃")
	RunState.pending_rewards = []
	RunState.traps = [-1, -1, -1]
	RunState.tool_roll_seq = 0
	RunState.run_seed = saved_seed

	# ---- R695 奖励窗口：不领也能过，进新格子才作废 ----
	# 用户口径：「不需要专门点放弃，允许玩家不拿直接过（到下一个未探索的格子前都能回来拿）」。
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7001)
	RunState.queue_tool_reward(7002)
	check(RunState.pending_reward_count() == 2, "R695：两条待领奖励就位")
	check(RunState.forfeit_pending_rewards() == 2,
			"R695：离开房间 → 待领奖励全部作废（返回条数）")
	check(RunState.pending_reward_count() == 0, "R695：作废之后待领归零")
	var all_skipped := true
	for fr_e: Dictionary in RunState.pending_rewards:
		if str(fr_e.get("state", "")) != RunState.REWARD_SKIPPED:
			all_skipped = false
	check(all_skipped, "R695：作废 = 数据层走 skip（账本一致，不另开一套）")
	check(RunState.forfeit_pending_rewards() == 0, "R695：没有待领时作废返回 0（幂等）")
	# 暗动力（6054）：卡牌奖励不许被「作废」这条后门绕过 —— 它本来就该当场拿。
	RunState.relics.append(RunState.DARK_POWER_RELIC_ID)
	RunState.pending_rewards = []
	RunState.queue_card_reward("normal")
	check(RunState.forfeit_pending_rewards() == 0
			and RunState.pending_reward_count() == 1,
			"R695：持暗动力时卡牌奖励不被作废（必须当场拿的代价不变）")
	RunState.relics.erase(RunState.DARK_POWER_RELIC_ID)
	# 二选一 / 核心这类「结构性」条目也必须能被作废 —— 漏一种，「✦ 待领奖励 N」就永远不归零。
	RunState.pending_rewards = []
	RunState.queue_key_choice(6001)
	RunState.pending_rewards.append({"kind": "core", "state": RunState.REWARD_PENDING})
	check(RunState.forfeit_pending_rewards() == 2 and RunState.pending_reward_count() == 0,
			"R695：大宝箱二选一 / 核心兑换同样会被作废（入口计数能归零）")
	check(RunState.skipped_relics.has(6001),
			"R695：二选一里的候选道具仍然登记「本局不再出」（走的是它自己的放弃口）")
	RunState.skipped_relics.erase(6001)
	RunState.pending_rewards = []
	# 自动离开判据：R389 的「必须领完」已撤，只剩「暗动力扣着卡牌」这一条拦。
	check(RewardPanel.can_auto_leave_after_reward(true, false),
			"R695：关掉奖励窗就走（不再要求先领完）")
	check(not RewardPanel.can_auto_leave_after_reward(false, false),
			"R695：结算面板没出来时仍然不自动走")
	check(not RewardPanel.can_auto_leave_after_reward(true, true),
			"R695：暗动力扣着卡牌 → 不自动走")
	# 界面上不再有「放弃」按钮 —— 这是本轮的核心改动，源码级锁死。
	var rp695 := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	# 只看**代码形态**：注释里会写「这里原来是『放弃这件』」，字面量搜索会误判。
	check(rp695.find('GameI18n.ui("reward", "REWARD_SKIP') < 0
			and rp695.find('GameI18n.ui("reward", "REWARD_CANNOT_SKIP') < 0
			and rp695.find("_btn_skip_rect()") < 0,
			"R695：奖励面板里再无「放弃这件 / 放弃这组」这类按钮（键与命中口都不存在了）")
	# ⚠️ R755 起标题文案换成 "REWARD_TOOL_SWAP_HEAD"（原 "REWARD_TOOL_FULL_SWAP" 那句话太长，
	#    和右上角「取消」挤在一行会溢出）—— 这条守卫改判**换装条还在不在**，别锁死文案键。
	check(rp695.find("_tool_swap_active") >= 0 and rp695.find("_swap_tool") >= 0
			and rp695.find("REWARD_TOOL_SWAP_HEAD") >= 0,
			"R695：满栏时道具详情页摊开「换一个」栏位（R755 换成正式的换装子面板）")
	var bs_src695 := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check(bs_src695.find("_trap_discard_rect") >= 0 and bs_src695.find("_try_discard_tool") >= 0,
			"R695：战斗工具栏带丢弃口（× + 两段式确认）")
	check(bs_src695.find("_trap_discard_rect(ts).has_point(event.position)") >= 0
			and bs_src695.find("_try_discard_tool(ts)") >= 0,
			"R695：× 的命中排在「按下槽」之前（否则永远点不到 —— 槽会先把按下吃掉）")
	check(bs_src695.find("同一个小 × 点两次") >= 0 or bs_src695.find("两段式") >= 0,
			"R695：丢弃是两段式（不可逆操作，不做成单击即丢）")
	var rs_src695 := FileAccess.get_file_as_string("res://scripts/run_state.gd")
	check(rs_src695.find("forfeit_pending_rewards") >= 0
			and rs_src695.find('"forfeited"') >= 0,
			"R695：advance / 传送把「作废了几条」交回调用方（地图据此提示）")

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
	check(shop_src.contains("TrapRepo.load_json().shop_traps()")
			and not shop_src.contains("TrapRepo.load_json().random_traps()"),
			"R752：商店货架只从 `shop_traps()`（有售价）取货 —— 非卖品不会白送")
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
	check(battle_src.contains("is_usable") and battle_src.contains("点「使用」就能用"),
			"R690：使用型工具拒绝进入拖放（R754 起提示「点『使用』就能用」）")
	var rp_src := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	check(battle_src.contains("RunState.roll_battle_tool_drop()")
			and battle_src.contains("RunState.queue_tool_reward("),
			"R694：战斗结算摇工具 → 入奖励队列（任何战斗走同一条）")
	check(not battle_src.contains("roll_battle_tool_drop(node_type)"),
			"R694：掉率不看 node_type —— 不存在只给某一类战斗的情况")
	check(rp_src.contains("UiAssets.trap_icon") and rp_src.contains("REWARD_TOOL_NAME")
			and rp_src.contains("REWARD_TOOL_TAG_USE"),
			"R694：奖励面板用工具自己的图标与分类标签显示掉落")
	var fx_all := true
	for fx_id in [7001, 7002, 7003, 7004]:
		if not FileAccess.file_exists(UiAssets.trap_fx_path(int(fx_id))):
			fx_all = false
	check(fx_all, "R669：4 张 codex 触发特效贴图已落 assets/fx")

	# ---- ⑧ R696：入牌库飞行起点 / 落库脉冲 / 「+1」飘字 ----
	# 这三条都是 `battle_scene` 的绘制接线，和上面 R695 的 `bs_src695` 是同一类守卫；
	# 放在这个套件里是因为它已经是 battle_scene 视觉断言的收纳处。
	var bs696 := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check(bs696.find("DECK_FLY_FROM") >= 0 and bs696.find("DECK_Y - 130.0") < 0,
			"R696：入牌库起点改用 DECK_FLY_FROM（旧值落在弃牌槽里，已删）")
	# 几何直接读脚本常量：不实例化场景也能验「起点在哪个槽里」。
	var dcf_script: Script = load("res://scripts/battle_scene.gd")
	var dcf: Dictionary = dcf_script.get_script_constant_map()
	var fly_from: Vector2 = dcf.get("DECK_FLY_FROM", Vector2.ZERO)
	var disc_y := float(dcf.get("DISCARD_Y", 0.0))
	var zone_h := float(dcf.get("ZONE_H", 0.0))
	var deck_x := float(dcf.get("DECK_X", 0.0))
	check(fly_from != Vector2.ZERO,
			"R696：DECK_FLY_FROM 可取到（%.0f, %.0f）" % [fly_from.x, fly_from.y])
	check(fly_from.y < disc_y or fly_from.y > disc_y + zone_h,
			"R696：起点不落在弃牌槽 %.0f..%.0f（实际 y=%.0f）—— 这是旧版「看不见」的根因"
			% [disc_y, disc_y + zone_h, fly_from.y])
	check(fly_from.x < deck_x,
			"R696：起点在牌堆左侧空地（x=%.0f < 牌堆 %0.f）" % [fly_from.x, deck_x])
	check(bs696.find("var _deck_pulse") >= 0 and bs696.find("func _draw_deck_pulse") >= 0
			and bs696.find("_draw_deck_pulse(drect)") >= 0,
			"R696：落库脉冲有队列 / 有绘制口 / 牌堆绘制处已接")
	check(bs696.find("_deck_pulse = _deck_pulse.filter") >= 0
			and bs696.find("or not _deck_pulse.is_empty()") >= 0,
			"R696：脉冲自己收掉且计入 busy（不收会钉死 busy，不计会卡在中间一格）")
	check(bs696.find('"text": "+1"') >= 0 and bs696.find('Color("ffd76a")') >= 0,
			"R696：落库那一刻有金色「+1」飘字")
	check(bs696.find("--deckfly") >= 0,
			"R696：带 --deckfly 出图入口（验同类动画不必再打临时补丁）")

	# ---- ⑨ R697：入库演出唯一口 / 批量错开 / 弃牌区回手起点 ----
	check(bs696.find("func _on_deck_added") >= 0
			and bs696.find("_on_deck_added(data, n)") >= 0,
			"R697：deck_added 的演出收进 `_on_deck_added` 唯一口")
	check(bs696.find('if str(data.get("side", GameEngine.SIDE_SELF)) != GameEngine.SIDE_SELF:') >= 0,
			"R697：deck_added 只对我方播（敌方牌库只是抽象计数，不该往玩家牌堆飞）")
	check(bs696.find("const DECK_FLY_GAP_MS") >= 0
			and bs696.find("at = maxi(at, fs + DECK_FLY_GAP_MS)") >= 0,
			"R697：同一次效果塞多张时逐张错开（否则卡背 / 金环 /「+1」完全重合 = 只看到 1 张）")
	# 金环只认「入库」：全文件只剩 `_on_deck_added` 里一处 append
	#（屏障 8033 / 过载走的是「改了一张」，借金环会让玩家以为加了 1 张）。
	var pulse_n := 0
	var pulse_at := 0
	while true:
		pulse_at = bs696.find("_deck_pulse.append", pulse_at)
		if pulse_at < 0:
			break
		pulse_n += 1
		pulse_at += 1
	check(pulse_n == 1,
			"R697：金环只在真正入库时出现（实际 %d 处 append；屏障/过载不该冒充「+1」）" % pulse_n)
	check(bs696.find("func _play_hand_flyin(added: Array, from_discard := false)") >= 0
			and bs696.find("origin = Vector2(DISCARD_X + ZONE_W / 2.0") >= 0,
			"R697：从弃牌区捞回的卡从弃牌堆起飞（原来一律从抽牌堆，观感=又抽了一张）")
	check(bs696.find("var _discard_known") >= 0
			and bs696.find("var dd: int = engine.state.discard.size() - _discard_known") >= 0
			and bs696.find("var from_discard := dd < 0 or _gained_from_discard") >= 0,
			"R697：弃牌区张数快照 → 净减少即判「有卡从弃牌区回手」")
	check(bs696.find('if str(data.get("from", "")) == "discard":') >= 0,
			"R697：card_gained 带 from=discard 时点名来源（拒绝命运那种净值为正的）")
	var eng697 := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(eng697.find('"how": "拒绝命运", "from": "discard"') >= 0,
			"R697：拒绝命运捞回时在引擎侧点名来源")
	# 五个入库发射点必须都带 side（界面按 side 过滤）
	var emit_all := true
	for eid in ["{\"card\": c, \"side\": p.owner}",
			"{\"card\": copy, \"side\": side}",
			"{\"card\": mr_copy, \"side\": side}",
			"{\"card\": up, \"side\": side}",
			"{\"card\": ad_inst, \"side\": p.owner}"]:
		if eng697.find(str(eid)) < 0:
			emit_all = false
	check(emit_all, "R697：5 个 deck_added 发射点都带 side（幽深回响/镜像/生产订单/集束炮台×2）")

	# ---- ⑩ R752：三件新工具的结算 ----
	# ① 快送鸭 7010：**先腾空自己那一格再填满** —— 用完之后工具栏必须是 3/3。
	#    顺序反了（先填后摘）就是 2/3，玩家会以为「填满」这条效果打了折扣。
	var saved_seed752 := RunState.run_seed
	var saved_seq752 := RunState.tool_deliver_seq
	RunState.run_seed = 20261115
	RunState.tool_deliver_seq = 0
	# 起始只放一件且放在槽 1：用掉它之后三格都空，才验得出「填满 = 3/3」。
	RunState.traps = [7010, -1, -1]
	var duck_eng := _engine()
	check(duck_eng.use_tool(7010, 0), "快送鸭：use_tool 带槽号结算成功")
	check(RunState.trap_free_slots() == 0, "快送鸭：用完之后工具栏 3/3（自己那格也算填上）")
	var fill_all_shop := true
	for du_i in RunState.TRAP_SLOTS:
		var du_t: TrapData = repo.get_trap(RunState.trap_at(du_i))
		if du_t == null or not du_t.in_shop() or du_t.rest_only:
			fill_all_shop = false
	check(fill_all_shop, "快送鸭：填进去的都是**有售价的商店工具**（非卖品 / 烤肉不会冒出来）")
	# 满栏时不顶掉已有工具：只在空槽里填，玩家手里的东西不该被这个效果换掉。
	RunState.traps = [7001, 7001, 7001]
	RunState.tool_deliver_seq = 1
	check(RunState.fill_toolbar_with_shop_tools() == 0
			and RunState.traps == [7001, 7001, 7001], "快送鸭：满栏时一件不换（不覆盖已有工具）")
	# 派生流：同一 (seed, 序号) 必得同一结果，且不碰 run_rng。
	RunState.traps = [-1, -1, -1]
	RunState.tool_deliver_seq = 7
	var d_first: Array[int] = []
	RunState.fill_toolbar_with_shop_tools()
	for du_i in RunState.TRAP_SLOTS:
		d_first.append(RunState.trap_at(du_i))
	RunState.traps = [-1, -1, -1]
	RunState.tool_deliver_seq = 7
	RunState.fill_toolbar_with_shop_tools()
	var d_again: Array[int] = []
	for du_i in RunState.TRAP_SLOTS:
		d_again.append(RunState.trap_at(du_i))
	check(d_first == d_again, "快送鸭：同一条派生种子出同一批工具（读档重进不会换货）")
	RunState.run_seed = saved_seed752
	RunState.tool_deliver_seq = saved_seq752

	# ② 万能牌 7009：抽牌库**空** → 用不了（不能白开一个空面板）。
	RunState.traps = [7009, -1, -1]
	var wc_eng := _engine()
	check(not wc_eng.begin_tool_pick(7009) and wc_eng.tool_pick_kind == "",
			"万能牌：抽牌库是空的 → 直接拒绝（不开空面板）")
	# 抽牌库有卡 → 候选 = 全部；确认后得到**幻影复制**（原卡留在牌库里）。
	var wc_proto: CardData = CardRepo.load_json().get_card(8001)
	wc_eng.state.deck.clear()
	wc_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	wc_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	check(wc_eng.begin_tool_pick(7009) and wc_eng.tool_pick_kind == "deck_copy",
			"万能牌：抽牌库有货 → 进入选卡（deck_copy）")
	check(wc_eng.tool_pick_cards().size() == 2, "万能牌：候选 = 抽牌库全部张数（2 张）")
	var wc_hand_before := wc_eng.state.hand.size()
	check(wc_eng.tool_pick_confirm(0), "万能牌：确认第 1 张 → 结算成功")
	check(wc_eng.state.hand.size() == wc_hand_before + 1, "万能牌：手牌 +1")
	check(wc_eng.state.deck.size() == 2, "万能牌：原卡**留在**抽牌库里（这是复制，不是取走）")
	var wc_copy: CardData = wc_eng.state.hand[wc_eng.state.hand.size() - 1]
	check(wc_copy != wc_eng.state.deck[0] and wc_copy.own_copy,
			"万能牌：拿到的是独立副本（不是牌库那个共享实例）")
	check(wc_copy.is_ephemeral and wc_copy.affixes.has(GameEngine.AFFIX_DIMENSION)
			and not wc_copy.affixes.has(GameEngine.AFFIX_PHANTOM),
			"万能牌：幻影复制 = 回合结束消失 + 次元（用后消失）、不带「幻影」字段（不会无限链）")
	check(wc_eng.cost_of(wc_copy) == 0, "万能牌：复制品在手时费用为 0")
	# 离手即恢复原价：`hand_free` 的判据是「此刻还在手牌里」，打出 / 弃掉自动失效。
	wc_eng.state.hand.erase(wc_copy)
	wc_eng.state.discard.append(wc_copy)
	check(wc_eng.cost_of(wc_copy) == wc_copy.cost,
			"万能牌：离手后恢复原费用（%d）" % wc_copy.cost)
	# 取消：什么都没发生（工具留在工具栏里，由界面决定不摘槽）。
	wc_eng.state.hand.erase(wc_copy)
	check(wc_eng.begin_tool_pick(7009), "万能牌：再开一次选卡")
	wc_eng.tool_pick_cancel()
	check(wc_eng.tool_pick_kind == "" and wc_eng.state.hand.size() == wc_hand_before,
			"万能牌：取消 → 状态清空、手牌不变")

	# ③ 神秘牌 7011：候选 = 随机 3 张**本职业奖励卡**；确认后入手且本回合 0 费。
	var my_eng := _engine()
	check(my_eng.begin_tool_pick(7011) and my_eng.tool_pick_kind == "random3",
			"神秘牌：进入选卡（random3）")
	var my_cards: Array = my_eng.tool_pick_cards()
	check(my_cards.size() == 3, "神秘牌：候选正好 3 张")
	var my_ids: Array[int] = []
	var my_in_pool := true
	var my_pool: Array[CardData] = CardRepo.load_json().reward_pool_for(RunState.player_class)
	for pc: CardData in my_pool:
		my_ids.append(int(pc.id))
	var my_distinct := true
	for mc: CardData in my_cards:
		if not my_ids.has(int(mc.id)):
			my_in_pool = false
	if my_cards.size() == 3 and int((my_cards[0] as CardData).id) == int((my_cards[1] as CardData).id):
		my_distinct = false
	if my_cards.size() == 3 and int((my_cards[0] as CardData).id) == int((my_cards[2] as CardData).id):
		my_distinct = false
	if my_cards.size() == 3 and int((my_cards[1] as CardData).id) == int((my_cards[2] as CardData).id):
		my_distinct = false
	check(my_in_pool, "神秘牌：3 张候选都来自本职业奖励卡池")
	check(my_distinct, "神秘牌：3 张候选互不相同")
	var my_hand_before := my_eng.state.hand.size()
	check(my_eng.tool_pick_confirm(1), "神秘牌：确认第 2 张 → 结算成功")
	check(my_eng.state.hand.size() == my_hand_before + 1, "神秘牌：手牌 +1")
	var my_got: CardData = my_eng.state.hand[my_eng.state.hand.size() - 1]
	check(my_eng.state.turn_free.has(my_got), "神秘牌：入手的那张记了「本回合费用 0」")
	check(my_eng.cost_of(my_got) == 0, "神秘牌：本回合费用为 0")
	check(my_eng.tool_pick_kind == "", "神秘牌：结算后待选状态清空（面板会自己关）")

	# ④ 手牌满 → 两种选卡型工具都不许用（否则复制品会被 `_grant_to_hand` 丢进弃牌/消耗区）。
	var hf_eng := _engine()
	hf_eng.state.deck.append(CardData.from_dict(wc_proto.to_dict()))
	while not hf_eng.state.hand_full():
		hf_eng.state.hand.append(CardData.new())
	check(not hf_eng.begin_tool_pick(7009) and not hf_eng.begin_tool_pick(7011),
			"手牌满（10 张）时万能牌 / 神秘牌都拒绝使用")
	check(not hf_eng.use_tool(7009) and not hf_eng.use_tool(7011),
			"选卡型工具**不走** use_tool（避免界面误当「已结算」而摘槽）")

	# ---- ⑪ R754：石头（直接伤害型）+ 祭拜祝福（三场必掉）+ 摧毁（石头填栏）----
	# ① 落点：石头要**敌方单位格**，普通陷阱要**空格** —— 两条判据在同一个口里分。
	var s_eng := _engine()
	var s_foe := _unit(9001, 40, GameEngine.SIDE_OPPONENT)
	var s_self := _unit(9002, 40, GameEngine.SIDE_SELF)
	s_eng.state.board[Vector2i(4, 0)] = s_foe
	s_eng.state.board[Vector2i(3, 0)] = s_self
	var st_targets: Array[Vector2i] = s_eng.trap_drop_cells(7012)
	check(st_targets.size() == 1 and st_targets.has(Vector2i(4, 0)),
			"石头：可砸目标只有敌方单位那一格（自己人不算）")
	var bomb_cells: Array[Vector2i] = s_eng.trap_drop_cells(7001)
	check(bomb_cells.size() > 0 and not bomb_cells.has(Vector2i(4, 0))
			and not bomb_cells.has(Vector2i(3, 0)),
			"普通陷阱：落点仍是空格（两个有单位的格子都不在候选里）")
	# ② 砸下去：15 点伤害；砸自己人 / 砸空格 / 用错工具一律拒绝。
	RunState.traps = [7012, -1, -1]
	check(s_eng.use_tool_on_unit(7012, Vector2i(4, 0)), "石头：砸敌方单位结算成功")
	check(s_foe.health == 25, "石头：目标扣 15 点（40 → 25）")
	check(not s_eng.use_tool_on_unit(7012, Vector2i(3, 0)), "石头：砸自己人一律拒绝")
	check(not s_eng.use_tool_on_unit(7012, Vector2i(9, 0)), "石头：砸空格一律拒绝")
	check(not s_eng.use_tool_on_unit(7001, Vector2i(4, 0)),
			"石头口只认直接伤害型（炸弹仍是 place_trap 那条路）")
	# 致死要自己收尾（R733 铁律：`_hit_unit` 只扣血不删卡，新路径必须自己 `_destroy_dead`）
	var s_weak := _unit(9003, 10, GameEngine.SIDE_OPPONENT)
	s_eng.state.board[Vector2i(5, 0)] = s_weak
	check(s_eng.use_tool_on_unit(7012, Vector2i(5, 0))
			and s_eng.state.unit_at(Vector2i(5, 0)) == null,
			"石头打死人：单位当场从盘面清掉（不留负血占格）")
	# ③ 祭拜祝福：接下来三场**必掉**（不看 10% 概率），三场之后自动用尽。
	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	RunState.tool_roll_seq = 0
	RunState.bless_tool_drops(3)
	check(RunState.tool_drop_pledge == 3, "祭拜：挂上「接下来 3 场必定掉工具」")
	var p1 := RunState.roll_battle_tool_drop()
	var p2 := RunState.roll_battle_tool_drop()
	var p3 := RunState.roll_battle_tool_drop()
	check(p1 > 0 and p2 > 0 and p3 > 0, "祭拜：前三场每场都掉（不看 10% 概率）")
	check(RunState.tool_drop_pledge == 0, "祭拜：三场之后祝福用尽（不会一直掉）")
	# 叠拜取 max：读者看到的永远是「接下来三场」，不会变成六场
	RunState.bless_tool_drops(2)
	RunState.bless_tool_drops(3)
	check(RunState.tool_drop_pledge == 3, "祭拜：重复祭拜取 max(2,3)=3，不累加成 5 场")
	RunState.tool_drop_pledge = 0
	# ④ 摧毁：石头只填空槽，不覆盖手里已有的工具。
	RunState.traps = [7005, -1, -1]
	var stones := RunState.fill_toolbar_with_stones()
	check(stones == 2 and RunState.trap_at(0) == 7005
			and RunState.trap_at(1) == 7012 and RunState.trap_at(2) == 7012,
			"摧毁：空槽填满石头（7012），已有的小血瓶原样不动")
	check(RunState.fill_toolbar_with_stones() == 0, "摧毁：满栏时一块也塞不进去")

	# ---- ⑫ R755：满栏领工具 → 「换下一件」子面板（换下 / 取消）----
	# ① 判据唯一口 `_tool_swap_active()`：只有「待领 + 工具 + 满栏」才走换装条。
	#    只调纯逻辑判据，不把面板挂进树（会弹窗）。
	var swp := RewardPanel.new()
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	var swp_e: Dictionary = RunState.pending_rewards[0]
	check(swp._tool_swap_active(swp_e), "R755：满栏 + 待领工具 → 走换装条")
	check(not swp._tool_swap_active({"kind": "relic", "id": 6001,
			"state": RunState.REWARD_PENDING}),
			"R755：道具条目不走换装条（它不是工具）")
	check(not swp._tool_swap_active({"kind": "tool", "id": 7005,
			"state": RunState.REWARD_CLAIMED}),
			"R755：已经领过的条目不再换")
	RunState.traps = [7001, -1, -1]
	check(not swp._tool_swap_active(swp_e), "R755：还有空位时不走换装条（直接领）")
	swp.free()
	# ② 换下：先丢旧槽再领 —— 顺序反了会白丢一件（满栏时 `gain_trap()` 直接失败）。
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	check(RunState.discard_trap(0) == 7001, "R755：换下 = 丢掉点中的那一格（返回被丢的 id）")
	check(RunState.claim_pending_reward(0), "R755：换下后新工具当场领进来")
	check(RunState.trap_at(0) == 7005 and RunState.trap_free_slots() == 0,
			"R755：新工具补进空出的那一格，栏位仍然 3/3")
	# ③ 取消：只回列表 —— 工具栏与待领队列一字不动。
	RunState.traps = [7001, 7002, 7004]
	RunState.pending_rewards = []
	RunState.queue_tool_reward(7005)
	check(RunState.trap_at(0) == 7001 and RunState.trap_at(2) == 7004
			and RunState.pending_rewards.size() == 1
			and str(RunState.pending_rewards[0].get("state", "")) == RunState.REWARD_PENDING,
			"R755：取消只回列表，工具栏与待领队列都不变（条目还在）")
	# ④ 源码守卫：界面接线不许被后续改动抹掉。
	var rp755 := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	check(rp755.find("_tool_swap_cancel_rect()") >= 0
			and rp755.find('GameI18n.ui("reward", "REWARD_TOOL_SWAP_CANCEL"') >= 0,
			"R755：换装条带「取消」按钮（几何口 + 文案键）")
	var ci755 := rp755.find("_tool_swap_cancel_rect().has_point(pos)")
	check(ci755 >= 0 and rp755.substr(ci755, 200).find("_back_to_list()") >= 0,
			"R755：点「取消」= 回列表（不丢条目）")
	check(rp755.find("if not tool_full:") >= 0,
			"R755：满栏时不再画右下角「领取 / 工具栏已满」按钮（改由换装条说明）")
	check(rp755.find('UiAssets.small_icon("ui_tool_swap"') >= 0,
			"R755：换装条标题用金色交换图标（assets/ui/ui_tool_swap.png）")
	check(FileAccess.file_exists("res://assets/ui/ui_tool_swap.png")
			and FileAccess.file_exists("res://assets/ui/trap_icon_7012.png"),
			"R755：两张新素材入库（交换图标 + 石头图标）")

	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	RunState.pending_rewards = []
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
	quit(1 if _bad > 0 else 0)
