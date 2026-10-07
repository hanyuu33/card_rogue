extends SceneTree
## headless 引擎规则测试（肉鸽版）：godot --headless -s scripts/test_engine.gd
## 覆盖：新数值（农民3费3/8、栅栏2费6血、攻击1费4伤）、能量机制、每回合抽 5、
## 回合结束弃全部手牌、牌库空时弃牌洗回、抽空提示、效果卡（迅捷减伤）、
## 击退/智慧/闪电链/火球术、鸭子骑士关卡、放置/移动/攻击/AI/胜负。

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


func _new_engine(deck: Array[CardData] = [], hp_me := 20, hp_foe := 20,
		limit := -1, shuffle := true) -> GameEngine:
	var st := FieldState.new(deck, hp_me, hp_foe, limit, "测试", shuffle)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	return eng


func _check_to_opp_turn(eng: GameEngine) -> void:
	## 步进到**下一个敌方回合开始**（`end_turn()` 是半回合，self ⇄ opp 交替）。
	## R74 新增。⚠️ 关键：**不能因为「当前已经是敌方回合」就提前 return** ——
	## 场地是**敌方在自己这回合里移动时**触发的，此刻的「敌方回合」已经过了大半，
	## 下一个该刷的是**我方**回合；要等的状态（禁足生效、中毒跳第 1 跳）都在**下一个敌方回合**。
	## 探针实测（_r74_probe）：敌方移动踩场地后，end_turn#1 → self、#2 → opponent（此时生效）。
	## 所以这里固定走满到「side 由 self 变成 opponent」为止。
	for _i in 4:
		eng.end_turn()
		if eng.current_side == GameEngine.SIDE_OPPONENT:
			return


func _card(id: int, name: String, kind: String, cost: int, power: int,
		health: int, rng_atk := 1, spd := 1) -> CardData:
	var c := CardData.new()
	c.id = id
	c.card_name = name
	c.kind = kind
	c.cost = cost
	c.power = power
	c.health = health
	c.attack_range = rng_atk
	c.move_speed = spd
	return c


func _find(hand: Array[CardData], id: int) -> int:
	for i in hand.size():
		if hand[i].id == id:
			return i
	return -1


func _level_named(name: String) -> Dictionary:
	## 按关卡名取内置关卡（避免依赖数组下标，新增关卡不会再错位）。
	for lvl in GameLevels.builtin_levels():
		if str(lvl["name"]) == name:
			return lvl
	return {}


## 固定顺序牌组（不洗牌）：FieldState 从 pop_back 抽 → 数组末尾先抽。
## 起手 5 张 = [农民, 农民, 木栅栏, 木栅栏, 木栅栏]。
func _ordered_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in 5:
		deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	for i in 5:
		deck.append(_card(8001, "木栅栏", "工事", 2, 0, 6))
	deck.append(_card(8003, "农民", "盟友", 3, 3, 8))
	deck.append(_card(8003, "农民", "盟友", 3, 3, 8))
	return deck


## 单卡牌组（效果/技能测试用）：开局只抽到这一张。
func _single_deck(card: CardData) -> Array[CardData]:
	var deck: Array[CardData] = [card]
	return deck


func _init() -> void:
	print("== 肉鸽引擎规则测试 ==")
	var repo := CardRepo.load_json()

	# ---- 卡牌数据：新数值 / 鸭子骑士 / 奖励卡 ----
	var fence := repo.get_card(8001)
	check(fence.kind == "工事" and fence.cost == 2 and fence.power == 0
			and fence.health == 6, "木栅栏：2 费 0 力 6 血工事")
	var shot := repo.get_card(8002)
	check(shot.is_spell() and shot.cost == 1 and shot.needs_target(),
			"攻击：1 费技能，需选目标")
	var farmer := repo.get_card(8003)
	check(farmer.kind == "盟友" and farmer.cost == 3 and farmer.power == 3
			and farmer.health == 8 and farmer.attack_range == 1
			and farmer.move_speed == 1, "树人（原农民）：3 费 3/8 程1 速1")
	var duck := repo.get_card(9001)
	check(duck.card_name == "鸭子骑士" and duck.power == 3 and duck.health == 30
			and duck.attack_range == 1 and duck.move_speed == 2 and duck.rarity == 4
			and duck.effect_text == "每击杀一个敌人，攻击力 +2。",
			"鸭子骑士：怪物 3/30 程1 速2（2026-10-01 由 5 攻下调，改为击杀成长）")
	var swift := repo.get_card(9002)
	check(swift.is_effect() and swift.rarity == 1 and swift.cost == 2
			and swift.value == 2 and swift.traits.has("减伤"),
			"迅捷：效果卡 稀有 2 费 value=2（减伤，只护 HP；2026-09-30 由 3 费下调）")
	check(repo.get_card(9006).rarity == 2, "闪电链：史诗")
	check(repo.get_card(9007).rarity == 1, "火球术：稀有")
	var ser := swift.to_dict()
	check(CardData.from_dict(ser).value == 2 and CardData.from_dict(ser).is_effect(),
			"效果卡 value/kind 序列化保留")
	var starter := repo.starter_deck()
	check(starter.size() == 13, "初始卡组 13 张（含角色卡熊×1；实际 %d）" % starter.size())
	var counts := {}
	for c in starter:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	check(int(counts.get(8001, 0)) == 5 and int(counts.get(8002, 0)) == 5
			and int(counts.get(8003, 0)) == 2 and int(counts.get(8004, 0)) == 1,
			"木栅栏×5 + 攻击×5 + 树人×2 + 熊×1（角色追加）")
	check(repo.all_cards().size() == 181,
			"图鉴 = 163 张（+ 幽影 8005 / 终结 9086 / 暗影刺客扩展 R45 / 回响·闪躲 R48 / 收尾 R49 / 爆炸陷阱 R50 / 冰霜·冻结·剧毒陷阱·陷阱精通 R51 / 紧急埋伏·陷阱工坊·暗影狩猎 R52 / 穿刺陷阱·双重陷阱 R53 / 巨物捕获·活体栅栏·警觉 R54 / 地狱猫·鲜血堡垒·活力转移 R55 / 暗影之刃·黑暗领主·暗影锁链 R56 / 黑暗扩散·地狱咏唱者·黑暗祭坛·无尽黑暗 R57 / 使魔之力 9115 R60 / 契约签订者·恶魔鸭·恶魔使魔 R63 / **机械之心 素体·构装体·升级 R82** / **R92 护盾生成器·模仿者** / **R95 加厚装甲·自主升级** / **R96 零件回收者·嵌合暴君·生产订单** / **R97 拆解** / **R98 旧式机兵** / **R99 重组·城墙·超越极限**；实际 %d）"
			% repo.all_cards().size())
	# ---- 图鉴分组（R36）：玩家卡牌图鉴 / 敌人图鉴（含敌方关卡效果）----
	# 分组写在 cards.json 的 group 字段（player / enemy），CardRepo.by_group 读取。
	var grp_all := repo.all_cards()
	var grp_bad: Array = []
	for c: CardData in grp_all:
		if c.group != "player" and c.group != "enemy":
			grp_bad.append(c.id)
	check(grp_bad.is_empty(),
			"图鉴分组：%d 张卡都有合法 group（player/enemy），异常 %s" % [grp_all.size(), str(grp_bad)])
	var grp_player := repo.player_cards()
	var grp_enemy := repo.enemy_cards()
	check(grp_player.size() == 147 and grp_enemy.size() == 34,
			"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 147 / 34）"
			% [grp_player.size(), grp_enemy.size()])
	check(grp_player.size() + grp_enemy.size() == grp_all.size(),
			"图鉴分组：两组之和 = 全部 %d 张（不重不漏）" % grp_all.size())
	var player_mon: Array = []
	for c: CardData in grp_player:
		if c.rarity == 4:
			player_mon.append(c.id)
	check(player_mon.is_empty(), "图鉴分组：玩家图鉴不含怪物 rarity=4（异常 %s）" % str(player_mon))
	var enemy_eff: Array = []
	for c: CardData in grp_enemy:
		if c.is_level_effect():
			enemy_eff.append(c.id)
	check(enemy_eff.size() == 6 and enemy_eff.has(9013) and enemy_eff.has(9015)
			and enemy_eff.has(9024) and enemy_eff.has(9049) and enemy_eff.has(9115)
			and enemy_eff.has(9117),
			"图鉴分组：敌人图鉴含 6 张敌方关卡效果 9013/9015/9024/9049/9115/9117（实际 %s）" % str(enemy_eff))
	check(repo.get_card(9022).group == "player" and repo.get_card(9044).group == "player"
			and repo.get_card(9072).group == "player" and repo.get_card(9018).group == "player"
			and repo.get_card(9023).group == "player" and repo.get_card(9050).group == "player",
			"图鉴分组：鸭蛋 9022 / 冰墙 9044 / 铁栅栏 9072 / 金属龙 9018 / 英雄 9023 / 鲸鱼之怒 9050 属玩家")
	check(repo.get_card(9026).group == "enemy" and repo.get_card(9028).group == "enemy"
			and repo.get_card(9029).group == "enemy" and repo.get_card(9048).group == "enemy",
			"图鉴分组：陶瓷鸭 9026 / 龙裔 9028 / 骷髅 9029 / 发条鸭 9048 属敌人")
	check(repo.get_card(9013).is_level_effect() and repo.get_card(9057).is_level_effect() == false
			and repo.get_card(9013).is_enemy_card() and repo.get_card(9023).is_enemy_card() == false,
			"图鉴分组：is_level_effect / is_enemy_card 判定正确（9013 是敌方关卡效果，9057 不是）")
	var pool := repo.reward_pool()
	check(pool.size() == 128,
			"奖励池 128 张（初始/怪物/事件卡不入池；R83 清泉 / R84 战斗骨骼 / R85 过载 / R86 批量改造·侦察塔 / R87 能量屏障·堡垒·自我修复 / R88 维修间 / R89 无限装甲 / R90 系统升级·批量传输 / R91 充电装置 / **R92 护盾生成器·模仿者** / **R95 加厚装甲·自主升级** / **R96 零件回收者·生产订单**（嵌合暴君 8047 史诗不入池）/ **R97 拆解**（稀有）/ **R98 旧式机兵**（普通）；实际 %d）"
			% pool.size())
	var pool_ids := {}
	for c in pool:
		pool_ids[c.id] = true
	check(pool_ids.has(9002) and pool_ids.has(9007) and pool_ids.has(9016)
			and pool_ids.has(9019)
			and not pool_ids.has(8001) and not pool_ids.has(9001)
			and not pool_ids.has(9018) and not pool_ids.has(9050),
			"初始/怪物/事件卡不可奖励获取；骑兵(9016)/箭塔(9019)在池内")

	check(pool_ids.has(9002) and pool_ids.has(9007) and pool_ids.has(9016)
			and pool_ids.has(9019)
			and not pool_ids.has(8001) and not pool_ids.has(9001)
			and not pool_ids.has(9018) and not pool_ids.has(9050),
			"初始/怪物/事件卡不可奖励获取；骑兵(9016)/箭塔(9019)在池内")

	# ---- 第 37 轮新卡（2026-10-01）：魔法塔 / 魔力核心 / 陨石术 / 复活术 / 魔像术 / 魔法学徒 ----
	var mt := repo.get_card(9075)
	check(mt.kind == "工事" and mt.cost == 2 and mt.power == 0 and mt.health == 11
			and mt.attack_range == 0 and mt.move_speed == 0 and mt.rarity == 0
			and mt.traits.has(GameEngine.MAGIC_TOWER_TRAIT),
			"魔法塔：普通 2 费工事 0/%d 程0 速0" % mt.health)
	var mc := repo.get_card(9076)
	check(mc.is_effect() and mc.cost == 2 and mc.rarity == 1
			and mc.traits.has(GameEngine.MAGIC_CORE_TRAIT), "魔力核心：稀有 2 费效果卡")
	var meteor := repo.get_card(9077)
	check(meteor.is_spell() and meteor.cost == 10 and meteor.rarity == 2
			and meteor.needs_cell() and meteor.traits.has(FieldState.KEEP_HAND_TRAIT),
			"陨石术：史诗 10 费技能，选格施放，带「留手」")
	var revive := repo.get_card(9078)
	check(revive.is_spell() and revive.cost == 0 and revive.rarity == 0
			and not revive.needs_target(), "复活术：普通 0 费技能，无需选目标")
	var golem_spell := repo.get_card(9079)
	check(golem_spell.is_spell() and golem_spell.cost == 4 and golem_spell.rarity == 1
			and golem_spell.needs_cell() and golem_spell.traits.has(GameEngine.GOLEM_TRAIT),
			"魔像术：稀有 4 费技能，选格召唤，带「魔像」")
	var golem := repo.get_card(9080)
	check(golem.kind == "盟友" and golem.cost == 3 and golem.power == 3
			and golem.health == 10 and golem.attack_range == 1 and golem.move_speed == 1
			and golem.rarity == 5 and golem.traits.has(GameEngine.TAUNT_TRAIT)
			and golem.traits.has(FieldState.VANISH_TRAIT),
			"魔像：token 3 费 3/10 程1 速1，嘲讽 + 离场消失")
	var appr := repo.get_card(9081)
	check(appr.kind == "盟友" and appr.cost == 2 and appr.power == 2 and appr.health == 5
			and appr.attack_range == 1 and appr.move_speed == 1 and appr.rarity == 1,
			"魔法学徒：稀有 2 费 2/5 程1 速1")
	check(repo.get_card(9075).group == "player" and repo.get_card(9077).group == "player"
			and repo.get_card(9078).group == "player" and repo.get_card(9080).group == "player"
			and repo.get_card(9081).group == "player",
			"第 37 轮新卡都归玩家图鉴（含 token 魔像 9080）")

	# ---- 流星雨（9083，2026-10-01）：X 费技能 —— 消耗全部能量，对随机敌人打 9 伤 X 次 ----
	var ms_card := repo.get_card(9083)
	check(ms_card != null and ms_card.is_spell() and ms_card.rarity == 0
			and ms_card.group == "player" and ms_card.x_cost and ms_card.cost == 0
			and ms_card.target_mode == "none" and not ms_card.needs_target(),
			"流星雨：普通技能，X 费标记，无需选目标，卡面基础费用 0")
	check(pool_ids.has(9083) and CardData.from_dict(ms_card.to_dict()).x_cost,
			"流星雨在奖励池内；x_cost 随 to_dict/from_dict 保留")
	var ms_e := _new_engine([], 30, 30)
	# 注意：伤害记在 **Placement.health**（不是 CardData.health）→ 必须用 place() 返回的 Placement
	var ms_pa := ms_e.state.place(CardData.from_dict(repo.get_card(1011).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)   # 铁壁卫兵 4/40
	var ms_pb := ms_e.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)   # 亡灵领主 8/55
	var ms_pc := ms_e.state.place(CardData.from_dict(repo.get_card(1013).to_dict()),
			Vector2i(1, 2), GameEngine.SIDE_OPPONENT)   # 灰烬龙 9/45
	var ms_before := ms_pa.health + ms_pb.health + ms_pc.health
	ms_e.state.hand.clear()
	ms_e.state.hand.append(CardData.from_dict(ms_card.to_dict()))
	ms_e.state.energy = 5
	check(ms_e.cost_of(ms_e.state.hand[0]) == 5 and ms_e.can_pay_card(ms_e.state.hand[0]),
			"流星雨：5 点能量时费用 = 5（X 费 = 剩余的全部能量）")
	ms_e.use_spell(0)
	var ms_lost := ms_before - (ms_pa.health + ms_pb.health + ms_pc.health)
	check(ms_lost == 45, "流星雨：X=5 → 5 次 × 9 = 45 点伤害（实际 %d）" % ms_lost)
	check(ms_e.state.energy == 0, "流星雨：一次吃掉全部能量（5 → 0）")
	check(ms_e.state.hp_opponent == 30,
			"流星雨：场上还有敌人时，没有一颗落到敌方 HP")
	ms_e.state.hand.append(CardData.from_dict(ms_card.to_dict()))
	check(ms_e.cost_of(ms_e.state.hand[0]) == 0 and not ms_e.can_pay_card(ms_e.state.hand[0]),
			"流星雨：0 能量时费用 0 且不可使用（免得空放浪费）")
	# 场上没有敌方单位 → 每一颗直击敌方 HP
	var ms_empty := _new_engine([], 30, 30)
	ms_empty.state.hand.clear()
	ms_empty.state.hand.append(CardData.from_dict(ms_card.to_dict()))
	ms_empty.state.energy = 3
	ms_empty.use_spell(0)
	check(ms_empty.state.hp_opponent == 3,
			"流星雨：场上没有敌人 → 每颗直击敌方 HP（3×9 = 27）")
	# 目标带「法术免疫」→ 那一颗被拦下（不掉血，也不会改打 HP）
	var ms_im := _new_engine([], 30, 30)
	var ms_im_p := ms_im.state.place(CardData.from_dict(repo.get_card(1071).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)   # 熔岩巨人（法术免疫）
	var ms_im_hp := ms_im_p.health
	ms_im.state.hand.clear()
	ms_im.state.hand.append(CardData.from_dict(ms_card.to_dict()))
	ms_im.state.energy = 2
	ms_im.use_spell(0)
	check(ms_im_p.health == ms_im_hp and ms_im.state.hp_opponent == 30,
			"流星雨：命中「法术免疫」的单位 → 这一颗被拦下（不掉血、也不改打 HP）")

	# ---- 火焰箭（9003）调费：3 费 → 2 费（2026-10-01）----
	var nc_fa := repo.get_card(9003)
	check(nc_fa.is_spell() and nc_fa.cost == 2 and nc_fa.rarity == 0
			and nc_fa.target_mode == "unit" and nc_fa.group == "player",
			"火焰箭：普通单体技能，费用已改为 2（实际 %d）" % nc_fa.cost)

	# ---- 火墙术（9084，2026-10-01）：3 费普通技能，烧一条横行 ----
	var nc_fw := repo.get_card(9084)
	check(nc_fw.is_spell() and nc_fw.cost == 3 and nc_fw.rarity == 0
			and nc_fw.needs_target() and nc_fw.target_mode == "cell"
			and nc_fw.group == "player",
			"火墙术：3 费普通技能、选格子目标、归玩家图鉴")
	var eng_fw := _new_engine([], 30, 30, -1, false)
	eng_fw.start_game(0)
	eng_fw.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	eng_fw.state.place(CardData.from_dict(repo.get_card(1011).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	var fw_a: Placement = eng_fw.state.unit_at(Vector2i(1, 0))
	var fw_b: Placement = eng_fw.state.unit_at(Vector2i(1, 1))
	var fw_a_hp := fw_a.health
	var fw_b_hp := fw_b.health
	eng_fw.state.hand = [repo.get_card(9084)]
	eng_fw.state.energy = 5
	eng_fw.use_spell(0, Vector2i(1, 2))
	check(fw_a.health == fw_a_hp - GameEngine.FIRE_WALL_DMG
			and fw_b.health == fw_b_hp - GameEngine.FIRE_WALL_DMG,
			"火墙术：一横行的敌人各 -15（%d→%d、%d→%d）" % [
			fw_a_hp, fw_a.health, fw_b_hp, fw_b.health])
	check(eng_fw.fire_wall_rows().has(1),
			"火墙术：第 1 行进入燃烧状态（fire_wall_rows = %s）" % str(eng_fw.fire_wall_rows()))
	# 已吃满 15 的敌人再在火线里挪一步 → 不再受伤（全卡合计上限）
	eng_fw.move(Vector2i(1, 1), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	check(fw_b.health == fw_b_hp - GameEngine.FIRE_WALL_DMG,
			"火墙术：同一单位上限 15 → 已吃满的单位穿过不再受伤（%d）" % fw_b.health)

	# 不分敌我 + 逐次递减到上限 15：我方单位两次穿过同一条火线
	var eng_fw2 := _new_engine([], 30, 30, -1, false)
	eng_fw2.start_game(0)
	eng_fw2.state.hand = [repo.get_card(9084)]
	eng_fw2.state.energy = 5
	var fw2_res := eng_fw2.use_spell(0, Vector2i(1, 1))
	check(fw2_res.contains("0 个敌人"),
			"火墙术：空行也能点燃（只是没打到人：%s）" % fw2_res)
	eng_fw2.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(2, 2), GameEngine.SIDE_SELF)
	var fw_p: Placement = eng_fw2.state.unit_at(Vector2i(2, 2))
	var fw_p_hp := fw_p.health
	eng_fw2.move(Vector2i(2, 2), Vector2i(1, 2), GameEngine.SIDE_SELF)
	check(fw_p.health == fw_p_hp - GameEngine.FIRE_WALL_PASS_DMG,
			"火墙术：不分敌我 —— 我方单位穿过火线 -10（%d→%d）" % [
			fw_p_hp, fw_p.health])
	fw_p.moved = false
	fw_p.tapped = false
	eng_fw2.move(Vector2i(1, 2), Vector2i(2, 2), GameEngine.SIDE_SELF)
	check(fw_p.health == fw_p_hp - GameEngine.FIRE_WALL_PASS_DMG,
			"火墙术：走出火线不再挨烧（%d）" % fw_p.health)
	fw_p.moved = false
	fw_p.tapped = false
	eng_fw2.move(Vector2i(2, 2), Vector2i(1, 2), GameEngine.SIDE_SELF)
	check(fw_p.health == fw_p_hp - GameEngine.FIRE_WALL_CAP,
			"火墙术：第二次穿过只补到上限 15（10+5 → 共 -%d）" % (fw_p_hp - fw_p.health))
	# 下次自己回合开始 → 火线熄灭
	eng_fw2.state.deck = []
	for fw_i in 8:
		eng_fw2.state.deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	eng_fw2._begin_turn(GameEngine.SIDE_SELF)
	check(eng_fw2.fire_wall_rows().is_empty(),
			"火墙术：下次自己回合开始 → 火线熄灭（%s）" % str(eng_fw2.fire_wall_rows()))
	eng_fw2.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(2, 0), GameEngine.SIDE_SELF)
	var fw_q: Placement = eng_fw2.state.unit_at(Vector2i(2, 0))
	var fw_q_hp := fw_q.health
	eng_fw2.move(Vector2i(2, 0), Vector2i(1, 0), GameEngine.SIDE_SELF)
	check(fw_q.health == fw_q_hp,
			"火墙术：熄灭后再穿过不掉血（%d→%d）" % [fw_q_hp, fw_q.health])

	# 法术免疫：火墙点不着它
	var eng_fw3 := _new_engine([], 30, 30, -1, false)
	eng_fw3.start_game(0)
	eng_fw3.state.place(CardData.from_dict(repo.get_card(1071).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	var fw_im: Placement = eng_fw3.state.unit_at(Vector2i(1, 1))
	var fw_im_hp := fw_im.health
	eng_fw3.state.hand = [repo.get_card(9084)]
	eng_fw3.state.energy = 5
	var fw3_res := eng_fw3.use_spell(0, Vector2i(1, 0))
	check(fw_im.health == fw_im_hp and fw3_res.contains("免疫"),
			"火墙术：法术免疫的单位点不着（%s）" % fw3_res)

	# ---- 蓄力（9085，2026-10-01）：2 费史诗技能 —— 本方下一张技能生效 2 次 ----
	var nc_ch := repo.get_card(9085)
	check(nc_ch != null and nc_ch.is_spell() and nc_ch.cost == 2 and nc_ch.rarity == 2
			and nc_ch.rarity_name() == "史诗" and nc_ch.group == "player"
			and nc_ch.target_mode == "none" and not nc_ch.needs_target(),
			"蓄力：2 费史诗技能、无需选目标、归玩家图鉴")
	check(pool_ids.has(9085) and nc_ch.effect_text == "你使用的下一张技能会生效 2 次。",
			"蓄力在奖励池内，卡面文案 =「你使用的下一张技能会生效 2 次。」")
	# 基本用法：蓄力 → 火焰箭（17 伤）打两次 = 34
	var chg_e := _new_engine([], 30, 30)
	var chg_p := chg_e.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)   # 亡灵领主 8/55
	chg_e.state.hand = [CardData.from_dict(repo.get_card(9085).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict())]
	chg_e.state.energy = 5
	check(chg_e.charge_count(GameEngine.SIDE_SELF) == 0, "蓄力：默认没有待用层数")
	chg_e.use_spell(0)
	check(chg_e.charge_count(GameEngine.SIDE_SELF) == 1 and chg_p.health == 55,
			"蓄力：自己不造成伤害，只留一层待用（敌方血量仍 %d）" % chg_p.health)
	var chg_res := chg_e.use_spell(0, Vector2i(1, 1))
	check(chg_p.health == 55 - 17 * 2,
			"蓄力：下一张技能生效 2 次 —— 火焰箭 17 → 共 -34（实际 -%d）" % (55 - chg_p.health))
	check(chg_e.charge_count(GameEngine.SIDE_SELF) == 0,
			"蓄力：用完即清（下一次不再翻倍）")
	check(chg_res.contains("蓄力"), "蓄力：结算文案带「蓄力」标记（%s）" % chg_res)
	# 只有紧接着的那一张翻倍，再下一张恢复单次
	chg_e.state.hand = [CardData.from_dict(repo.get_card(9003).to_dict())]
	chg_e.state.energy = 5
	chg_e.use_spell(0, Vector2i(1, 1))
	check(chg_p.health == 55 - 17 * 3,
			"蓄力：只作用于下一张技能，之后恢复单次（-17 → 共 -%d）" % (55 - chg_p.health))
	# 叠两层 → 生效 3 次
	var chg_e2 := _new_engine([], 30, 30)
	var chg_p2 := chg_e2.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	chg_e2.state.hand = [CardData.from_dict(repo.get_card(9085).to_dict()),
		CardData.from_dict(repo.get_card(9085).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict())]
	chg_e2.state.energy = 10
	chg_e2.use_spell(0)
	chg_e2.use_spell(0)
	check(chg_e2.charge_count(GameEngine.SIDE_SELF) == 2,
			"蓄力：两张叠加 → 待用 2 层（下一张技能生效 3 次）")
	chg_e2.use_spell(0, Vector2i(1, 1))
	check(chg_p2.health == 55 - 17 * 3,
			"蓄力 ×2：火焰箭生效 3 次 → 共 -51（实际 -%d）" % (55 - chg_p2.health))
	# 只对「技能」生效：出盟友不消耗蓄力
	var chg_e3 := _new_engine([], 30, 30)
	chg_e3.state.hand = [CardData.from_dict(repo.get_card(9085).to_dict()),
		_card(8003, "农民", "盟友", 3, 3, 8, 1, 1)]
	chg_e3.state.energy = 5
	chg_e3.use_spell(0)
	chg_e3.play_from_hand(0, Vector2i(4, 1))
	check(chg_e3.charge_count(GameEngine.SIDE_SELF) == 1,
			"蓄力：出盟友不消耗（下一张技能仍然翻倍）")
	# 按阵营记账：敌方侧走 remote_spell 同一条线，不串到我方
	var chg_e4 := _new_engine([], 30, 30)
	chg_e4.remote_spell(CardData.from_dict(repo.get_card(9085).to_dict()),
			null, GameEngine.SIDE_OPPONENT)
	check(chg_e4.charge_count(GameEngine.SIDE_OPPONENT) == 1
			and chg_e4.charge_count(GameEngine.SIDE_SELF) == 0,
			"蓄力：按阵营记账（敌方侧也生效，不串到我方）")
	# 复活术被翻倍 → 可取回 2 张盟友（一层一次，一张一张选）
	var chg_e5 := _new_engine([], 30, 30)
	chg_e5.state.discard = [_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
		_card(8003, "农民", "盟友", 3, 3, 8, 1, 1)]
	chg_e5.state.hand = [CardData.from_dict(repo.get_card(9085).to_dict()),
		CardData.from_dict(repo.get_card(9078).to_dict())]
	chg_e5.state.energy = 5
	chg_e5.use_spell(0)
	chg_e5.use_spell(0)
	check(chg_e5.revive_pending and chg_e5.revive_remaining == 2,
			"蓄力：复活术生效 2 次 → 可取回 2 张盟友（剩余 %d）" % chg_e5.revive_remaining)
	check(chg_e5.revive_recall(0) and chg_e5.revive_remaining == 1
			and chg_e5.revive_pending, "蓄力：取回第 1 张后还要再选 1 张")
	check(chg_e5.revive_recall(0) and not chg_e5.revive_pending
			and chg_e5.revive_remaining == 0, "蓄力：取回第 2 张后选牌结束")
	# 鲸鱼之怒被翻倍 → 取牌数 2 → 4
	var chg_e6 := _new_engine([], 30, 30)
	chg_e6.state.discard = [_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
		_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
		_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
		_card(8003, "农民", "盟友", 3, 3, 8, 1, 1)]
	chg_e6.state.hand = [CardData.from_dict(repo.get_card(9085).to_dict()),
		CardData.from_dict(repo.get_card(9050).to_dict())]
	chg_e6.state.energy = 5
	chg_e6.use_spell(0)
	chg_e6.use_spell(0)
	check(chg_e6.whale_pending and chg_e6.whale_remaining == 4,
			"蓄力：鲸鱼之怒生效 2 次 → 可取 4 张（剩余 %d）" % chg_e6.whale_remaining)

	# 魔法塔：在场时，伤害类技能按**原本费用**加伤（多座叠加；不在场不加）
	var mt_e := _new_engine([], 20, 20)
	mt_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1), Vector2i(3, 0),
			GameEngine.SIDE_SELF)
	check(mt_e._spell_dmg(GameEngine.SIDE_SELF, 4, repo.get_card(8002)) == 4,
			"魔法塔不在场：1 费攻击仍是 4 伤")
	mt_e.state.place(CardData.from_dict(mt.to_dict()), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(mt_e._spell_dmg(GameEngine.SIDE_SELF, 4, repo.get_card(8002)) == 5,
			"魔法塔在场：1 费攻击 4 → 5 伤（按原本费用 +1）")
	check(mt_e._spell_dmg(GameEngine.SIDE_SELF, 40, meteor) == 50,
			"魔法塔在场：10 费陨石术 40 → 50 伤（按原本费用 +10）")
	check(mt_e._spell_dmg(GameEngine.SIDE_SELF, 2, repo.get_card(9078)) == 2,
			"魔法塔：原本 0 费的技能不吃加成（复活术 0 费 → +0）")
	var mt_f := _new_engine([], 20, 20)
	mt_f.state.place(CardData.from_dict(mt.to_dict()), Vector2i(3, 1), GameEngine.SIDE_SELF)
	mt_f.state.hand.clear()
	mt_f.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	mt_f.state.turn_card_discount[mt_f.state.hand[0]] = 1   # 手工把这张攻击减到 0 费
	check(mt_f.cost_of(mt_f.state.hand[0]) == 0
			and mt_f._spell_dmg(GameEngine.SIDE_SELF, 4, mt_f.state.hand[0]) == 5,
			"魔法塔按「原本费用」加成：攻击被减到 0 费，塔仍按 1 费 +1（4 → 5）")
	mt_e.state.place(CardData.from_dict(mt.to_dict()), Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(mt_e._spell_dmg(GameEngine.SIDE_SELF, 4, repo.get_card(8002)) == 6,
			"两座魔法塔叠加：1 费攻击 4 → 6 伤")
	check(mt_e._spell_dmg(GameEngine.SIDE_OPPONENT, 4, repo.get_card(8002)) == 4,
			"魔法塔只加成自己那一方（敌方没有塔 → 不加）")

	# 魔力核心：每回合第一张技能卡费用 -1、伤害 +1；第二张起不再生效；多张不叠加
	var core_e := _new_engine([], 20, 20)
	core_e.state.effects.append(repo.get_card(9076))
	core_e.state.energy = 9
	core_e.state.hand.clear()
	core_e.state.hand.append(repo.get_card(8002))
	check(core_e.cost_of(core_e.state.hand[0]) == 0,
			"魔力核心：本回合第一张技能卡费用 -1（1 费攻击 → 0）")
	check(core_e._spell_dmg(GameEngine.SIDE_SELF, 4, core_e.state.hand[0]) == 5,
			"魔力核心：本回合第一张技能伤害 +1（4 → 5）")
	core_e.use_spell(0, null)
	check(core_e.state.self_skill_plays == 1, "魔力核心：用掉一张技能后本回合技能计数 =1")
	core_e.state.hand.append(repo.get_card(8002))
	check(core_e.cost_of(core_e.state.hand[0]) == 1,
			"魔力核心：本回合第二张技能卡不再减费（仍是 1 费）")
	check(core_e._spell_dmg(GameEngine.SIDE_SELF, 4, core_e.state.hand[0]) == 4,
			"魔力核心：本回合第二张技能伤害不再 +1")
	var core2 := _new_engine([], 20, 20)
	core2.state.effects.append(repo.get_card(9076))
	core2.state.effects.append(repo.get_card(9076))
	core2.state.hand.clear()
	core2.state.hand.append(repo.get_card(8002))
	check(core2.cost_of(core2.state.hand[0]) == 0
			and core2._spell_dmg(GameEngine.SIDE_SELF, 4, core2.state.hand[0]) == 5,
			"魔力核心不叠加：效果区 2 张也只 -1 / +1")

	# 陨石术：十字 40 伤、不分敌我；「留手」回合结束不弃；每用一张技能永久 -1
	var me_e := _new_engine([], 20, 20)
	me_e.state.energy = 30
	me_e.state.hand.clear()
	me_e.state.hand.append(CardData.from_dict(meteor.to_dict()))
	me_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	me_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1), Vector2i(3, 1),
			GameEngine.SIDE_SELF)
	me_e.use_spell(0, Vector2i(2, 1))
	check(me_e.state.unit_at(Vector2i(2, 1)) == null,
			"陨石术：中心格 40 伤直接打掉敌方单位")
	check(me_e.state.unit_at(Vector2i(3, 1)) == null,
			"陨石术：不分敌我 —— 相邻格自己的单位也吃 40 伤")
	check(me_e.state.unit_at(Vector2i(2, 0)) == null
			and me_e.state.unit_at(Vector2i(2, 2)) == null,
			"陨石术：十字四邻都在范围里（空格的落点不产生伤害）")
	check(me_e.state.self_skill_plays == 1, "陨石术：使用后本回合技能计数 =1")
	var keep_e := _new_engine([], 20, 20)
	keep_e.state.energy = 30
	keep_e.state.hand.clear()
	keep_e.state.hand.append(CardData.from_dict(meteor.to_dict()))
	keep_e.state.hand.append(repo.get_card(8002))
	check(keep_e.cost_of(keep_e.state.hand[0]) == 10, "陨石术：手卡起始 10 费")
	keep_e.use_spell(1, null)
	check(keep_e.cost_of(keep_e.state.hand[0]) == 9,
			"陨石术：每使用一张技能卡，手卡的这张永久 -1（10 → %d）"
			% keep_e.cost_of(keep_e.state.hand[0]))
	keep_e.state.hand.append(repo.get_card(8002))
	keep_e.use_spell(1, null)
	check(keep_e.cost_of(keep_e.state.hand[0]) == 8, "陨石术：再用一张技能 → 8 费（永久累加）")
	check(keep_e.state.card_discount.size() == 1
			and int(keep_e.state.card_discount[keep_e.state.hand[0]]) == 2,
			"陨石术：减费记在「永久实例减费」表（累加 2 次）")
	var keep2 := _new_engine([], 20, 20)
	keep2.state.hand.clear()
	keep2.state.hand.append(CardData.from_dict(meteor.to_dict()))
	keep2.state.hand.append(repo.get_card(8001))
	var dn_kept := keep2.state.discard_hand()
	check(dn_kept == 1 and keep2.state.hand.size() == 1
			and keep2.state.hand[0].id == 9077 and keep2.state.discard.size() == 1,
			"陨石术「留手」：回合结束留在手卡，其它手牌照常进弃牌区（实际离开 %d 张）" % dn_kept)

	# 魔像术：召唤魔像（3/10 嘲讽）+ 每用一张技能这张本回合 -1（回合结束清空）
	var go_e := _new_engine([], 20, 20)
	go_e.state.energy = 20
	var gm_msg := go_e._golem_spell(GameEngine.SIDE_SELF, Vector2i(4, 1))
	var gm_p: Placement = go_e.state.unit_at(Vector2i(4, 1))
	check(gm_p != null and gm_p.card.id == 9080 and gm_p.health == 10
			and gm_p.effective_power() == 3 and gm_p.card.traits.has(GameEngine.TAUNT_TRAIT),
			"魔像术：在己方半场召唤魔像 3/10 嘲讽（%s）" % gm_msg)
	check(go_e._golem_spell(GameEngine.SIDE_SELF, Vector2i(1, 1)) == "（只能在自己半场召唤魔像）",
			"魔像术：不能在敌方半场召唤")
	check(go_e._golem_spell(GameEngine.SIDE_SELF, Vector2i(4, 1)) == "（那一格已经有单位）",
			"魔像术：不能在已有单位的格子上召唤")
	var mv_e := _new_engine([], 20, 20)
	mv_e.state.energy = 20
	mv_e.state.hand.clear()
	mv_e.state.hand.append(CardData.from_dict(golem_spell.to_dict()))
	mv_e.state.hand.append(repo.get_card(8002))
	check(mv_e.cost_of(mv_e.state.hand[0]) == 4, "魔像术：手卡起始 4 费")
	mv_e.use_spell(1, null)
	check(mv_e.cost_of(mv_e.state.hand[0]) == 3, "魔像术：本回合用过 1 张技能 → 3 费")
	mv_e.state.hand.append(repo.get_card(8002))
	mv_e.use_spell(1, null)
	check(mv_e.cost_of(mv_e.state.hand[0]) == 2, "魔像术：用过 2 张技能 → 2 费（本回合内累加）")
	check(mv_e.state.turn_card_discount.size() == 1 and mv_e.state.card_discount.is_empty(),
			"魔像术：减费记在「本回合减费」表（不污染永久表）")
	mv_e.state.energy = 20
	mv_e.end_turn()
	check(mv_e.state.turn_card_discount.is_empty(), "魔像术：回合结束后本回合减费清空")

	# 魔像「离场消失」：被击破既不进弃牌区、也不会被洗回牌库
	var gd_e := _new_engine([], 20, 20)
	gd_e.state.energy = 20
	gd_e._golem_spell(GameEngine.SIDE_SELF, Vector2i(4, 1))
	var gd_p: Placement = gd_e.state.unit_at(Vector2i(4, 1))
	gd_e._destroy(Vector2i(4, 1))
	check(not gd_e.state.discard.has(gd_p.card) and gd_e.state.discard.is_empty(),
			"魔像「离场消失」：被击破不进弃牌区")
	check(gd_e.state.unit_at(Vector2i(4, 1)) == null, "魔像：离场后棋盘上不再有它")

	# 复活术：从弃牌区选一张盟友回到手卡
	var rv_e := _new_engine([], 20, 20)
	rv_e.state.energy = 5
	rv_e.state.hand.clear()
	rv_e.state.hand.append(repo.get_card(9078))
	rv_e.state.discard.clear()
	check(rv_e._revive_spell(GameEngine.SIDE_SELF) == "弃牌区里没有盟友",
			"复活术：弃牌区里没有盟友 → 效果落空")
	check(not rv_e.revive_pending, "复活术：没有可选目标时不进入选牌状态")
	rv_e.state.discard.append(repo.get_card(8002))    # 攻击：技能，不算盟友
	rv_e.state.discard.append(repo.get_card(8003))    # 农民：盟友
	rv_e.state.discard.append(repo.get_card(9031))    # 白狼：盟友
	check(rv_e.revive_options() == [1, 2],
			"复活术：候选只列弃牌区里的盟友（实际 %s）" % str(rv_e.revive_options()))
	rv_e.use_spell(0)
	check(rv_e.revive_pending, "复活术：打出后进入选牌状态（等待玩家点一张盟友）")
	var rv_opts := rv_e.revive_options()
	check(rv_opts == [1, 2], "复活术：复活术自己进弃牌区后不算候选（它是技能）")
	check(rv_e.revive_recall(rv_opts[0]) and not rv_e.revive_pending,
			"复活术：选中盟友后从弃牌区回到手卡")
	check(rv_e.state.hand[rv_e.state.hand.size() - 1].id == 8003,
			"复活术：回到手卡的是那张农民")
	check(rv_e.state.discard.size() == 3, "复活术：被取回的那张离开弃牌区（剩 3 张）")
	check(rv_e.revive_recall(1) == false, "复活术：选牌状态已结束，重复点击无效")
	var rv_e2 := _new_engine([], 20, 20)
	rv_e2.state.energy = 5
	rv_e2.state.hand.clear()
	rv_e2.state.hand.append(repo.get_card(9078))
	rv_e2.state.discard.append(repo.get_card(8003))
	rv_e2.use_spell(0)
	check(rv_e2._run_spell_effect(repo.get_card(9078), null, GameEngine.SIDE_OPPONENT)
			== "（复活术：敌方 AI 不使用这张卡）",
			"复活术：敌方侧不会触发选牌")

	# 魔法学徒：从卡组取一张随机技能卡入手；本回合出牌费用 -1
	var ap_e := _new_engine([], 20, 20)
	ap_e.state.energy = 20
	ap_e.state.hand.clear()
	ap_e.state.deck.clear()
	ap_e.state.deck.append(repo.get_card(8002))     # 攻击：技能
	ap_e.state.deck.append(repo.get_card(8001))     # 木栅栏：工事，不该被取
	ap_e.state.hand.append(repo.get_card(9081))
	var ap_p := ap_e.play_from_hand(0, Vector2i(4, 0))
	check(ap_p != null and ap_e.state.unit_at(Vector2i(4, 0)) != null
			and ap_e.state.unit_at(Vector2i(4, 0)).card.id == 9081,
			"魔法学徒：2 费 2/5 照常上场")
	check(ap_e.state.self_cost_reduction == 0,
			"R65 魔法学徒：不设全局出牌减费（只给自己取到的那张技能牌 -1）")
	check(ap_e.state.hand.size() == 1 and ap_e.state.hand[0].id == 8002,
			"魔法学徒：只从卡组取「技能卡」（取到攻击，工事不取）")
	check(ap_e.state.deck.size() == 1 and ap_e.state.deck[0].id == 8001,
			"魔法学徒：被取走的技能卡离开卡组")


	# ---- 第 38 轮新卡（2026-10-01）：虚空主宰 9082 ----
	var vl := repo.get_card(9082)
	check(vl.kind == "盟友" and vl.cost == 10 and vl.power == 7 and vl.health == 20
			and vl.attack_range == 2 and vl.move_speed == 1 and vl.rarity == 2
			and vl.group == "player" and vl.traits.has(GameEngine.VOID_LORD_TRAIT),
			"虚空主宰：史诗 10 费盟友 7/20 程2 速1，归玩家图鉴")

	# ① 这张卡在场时，该方的技能牌费用 -1（多张叠加；只减技能；只按该方场上的张数算）
	var vo_e := _new_engine([], 20, 20)
	vo_e.state.hand.clear()
	vo_e.state.hand.append(CardData.from_dict(repo.get_card(9007).to_dict()))   # 火球术 4 费
	vo_e.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))   # 农民 3 费
	check(vo_e.cost_of(vo_e.state.hand[0]) == 4 and vo_e.cost_of(vo_e.state.hand[1]) == 3,
			"虚空主宰不在场：技能 4 费 / 盟友 3 费 都是原价")
	vo_e.state.place(CardData.from_dict(vl.to_dict()), Vector2i(5, 0), GameEngine.SIDE_SELF)
	check(vo_e.cost_of(vo_e.state.hand[0]) == 3,
			"虚空主宰在场：技能牌费用 -1（火球术 4 → 3）")
	check(vo_e.cost_of(vo_e.state.hand[1]) == 3,
			"虚空主宰在场：盟友（非技能）费用不变（农民仍是 3 费）")
	vo_e.state.place(CardData.from_dict(vl.to_dict()), Vector2i(5, 1), GameEngine.SIDE_SELF)
	check(vo_e.cost_of(vo_e.state.hand[0]) == 2, "虚空主宰两张在场：技能费用 -2（叠加）")
	vo_e.state.place(CardData.from_dict(vl.to_dict()), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	check(vo_e.cost_of(vo_e.state.hand[0]) == 2,
			"虚空主宰：只按该方场上的张数算（敌方场上那张不减我方技能费用）")
	check(vo_e._void_lord_presence(GameEngine.SIDE_SELF) == 2
			and vo_e._void_lord_presence(GameEngine.SIDE_OPPONENT) == 1,
			"虚空主宰：敌我两侧计数各自独立（我方 2 / 敌方 1）")
	check(vo_e._void_lord_discount(vo_e.state.hand[1], GameEngine.SIDE_SELF) == 0,
			"虚空主宰：非技能卡不享受「在场 -1」（盟友 0）")
	check(vo_e._void_lord_discount(vo_e.state.hand[0], GameEngine.SIDE_OPPONENT) == 1,
			"虚空主宰：敌方侧技能同样按敌方场上张数 -1（实际敌方拿不到这张卡，仅保持对称）")

	# 本体上场 / 离场：费用即时变化
	var vp_e := _new_engine([], 20, 20)
	vp_e.state.energy = 30
	vp_e.state.hand.clear()
	vp_e.state.hand.append(CardData.from_dict(vl.to_dict()))
	vp_e.state.hand.append(CardData.from_dict(repo.get_card(9077).to_dict()))   # 陨石术 10 费
	check(vp_e.cost_of(vp_e.state.hand[1]) == 10, "虚空主宰：本体上场前陨石术 10 费")
	var vp_p := vp_e.play_from_hand(0, Vector2i(5, 0))
	check(vp_p != null and vp_e.state.unit_at(Vector2i(5, 0)) != null
			and vp_e.state.unit_at(Vector2i(5, 0)).card.id == 9082,
			"虚空主宰：10 费 7/20 照常上场")
	check(vp_e.cost_of(vp_e.state.hand[0]) == 9,
			"虚空主宰：本体上场后手卡里的陨石术立刻 9 费")
	vp_e._destroy(Vector2i(5, 0))
	check(vp_e.cost_of(vp_e.state.hand[0]) == 10,
			"虚空主宰：本体离场后技能牌恢复原价（10 费）")

	# ② 本次对战中每用技能牌对敌方造成一次伤害 → 手卡里的本卡费用 -2
	var vd_e := _new_engine([], 20, 20)
	vd_e.state.energy = 30
	vd_e.state.hand.clear()
	var vd_lord := CardData.from_dict(vl.to_dict())
	vd_e.state.hand.append(vd_lord)                                             # [0]
	vd_e.state.hand.append(CardData.from_dict(repo.get_card(9007).to_dict()))  # [1] 火球术
	check(vd_e.state.void_dmg_spells == 0 and vd_e.cost_of(vd_lord) == 10,
			"虚空主宰：开局手卡 10 费、伤害计数 0")
	# 只打到自己人（寒冰箭 9011 点我方农民）→ 不算「对敌人造成伤害」
	vd_e.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	vd_e.state.hand.append(CardData.from_dict(repo.get_card(9011).to_dict()))  # [2] 寒冰箭
	vd_e.use_spell(2, Vector2i(4, 0))
	check(vd_e.state.void_dmg_spells == 0 and vd_e.cost_of(vd_lord) == 10,
			"虚空主宰：技能只打到自己人 → 不计数（仍 10 费）")
	# 火球术打到敌方单位 → 记 1 次
	vd_e.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
	vd_e.state.hand.append(CardData.from_dict(repo.get_card(9007).to_dict()))  # [2]
	vd_e.use_spell(2, Vector2i(3, 0))
	check(vd_e.state.void_dmg_spells == 1 and vd_e.cost_of(vd_lord) == 8,
			"虚空主宰：技能对敌造成伤害 → 计数 1，手卡 10 - 2 = 8 费")
	# 一次技能打中 2 个敌人：仍然只记 1 次（按「使用技能牌」计数，不按命中数）
	vd_e.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	vd_e.state.hand.append(CardData.from_dict(repo.get_card(9007).to_dict()))  # [2]
	vd_e.use_spell(2, Vector2i(3, 0))
	check(vd_e.state.void_dmg_spells == 2 and vd_e.cost_of(vd_lord) == 6,
			"虚空主宰：一次技能打中 2 个敌人也只记 1 次（10 - 4 = 6 费）")
	# 不造成伤害的技能（复活术 9078）不计
	vd_e.state.hand.append(CardData.from_dict(repo.get_card(9078).to_dict()))  # [2]
	vd_e.use_spell(2)
	check(vd_e.state.void_dmg_spells == 2 and vd_e.cost_of(vd_lord) == 6,
			"虚空主宰：不造成伤害的技能（复活术）不计数（仍 6 费）")
	# 减费跨回合保留（「本次对战中」= 整个战斗，不是单回合）
	vd_e.state.energy = 30
	vd_e.end_turn()
	check(vd_e.state.void_dmg_spells == 2 and vd_e.cost_of(vd_lord) == 6,
			"虚空主宰：减费跨回合保留（回合结束不清，本次对战中累计）")
	# 新一局：重新从 0 开始
	check(_new_engine([], 20, 20).state.void_dmg_spells == 0,
			"虚空主宰：新一局对战伤害计数从 0 开始")

	# ---- 中立动物奖励卡（9031~9034，2026-09-30 新增） ----
	check(repo.get_card(9031).actions == 2 and repo.get_card(9031).rarity == 2
			and repo.get_card(9031).power == 4 and repo.get_card(9031).health == 8,
			"白狼：史诗 3 费 4/8 程1 速1，每回合行动两次")
	# R82：野兔由「普通 1 费 1/2」改为「**稀有** 1 费 1/2」+ 新增「自我复制」。
	check(repo.get_card(9032).cost == 1 and repo.get_card(9032).power == 1
			and repo.get_card(9032).health == 2 and repo.get_card(9032).rarity == 1,
			"R82 野兔：**稀有** 1 费 1/2（rarity 由 0 提到 1）")
	check(repo.get_card(9032).traits.has("自我复制")
			and repo.get_card(9032).effect_text.contains("复制"),
			"R82 野兔：带 trait「自我复制」且卡面写了复制效果（引擎按 trait 判定）")
	check(repo.get_card(9033).cost == 2 and repo.get_card(9033).power == 2
			and repo.get_card(9033).health == 7 and repo.get_card(9033).rarity == 1,
			"山猫：稀有 2 费 2/7")
	check(repo.get_card(9034).cost == 2 and repo.get_card(9034).power == 2
			and repo.get_card(9034).health == 8 and repo.get_card(9034).rarity == 1,
			"赤狐：稀有 2 费 2/8")
	# 白狼：上场后 acts_left == 2（每回合行动两次）
	var wolf := repo.get_card(9031)
	var eng_wolf := _new_engine(_single_deck(wolf), 20, 20, -1, false)
	eng_wolf.start_game(1)
	eng_wolf.play_from_hand(0, Vector2i(4, 1))
	check(eng_wolf.state.unit_at(Vector2i(4, 1)) != null
			and eng_wolf.state.unit_at(Vector2i(4, 1)).acts_left == 2,
			"白狼上场：acts_left == 2（每回合行动两次）")
	# 山猫：被破坏后返回手牌（变为 1 费），不进弃牌区
	var lynx := repo.get_card(9033)
	var eng_lynx := _new_engine(_single_deck(lynx), 20, 20, -1, false)
	eng_lynx.start_game(1)
	eng_lynx.play_from_hand(0, Vector2i(4, 1))
	eng_lynx.state.unit_at(Vector2i(4, 1)).health = 0
	eng_lynx._destroy_dead()
	check(eng_lynx.state.hand.any(func(c: CardData): return c.id == 9033 and c.cost == 1),
			"山猫被击破：返回手牌且费用变为 1")
	check(not eng_lynx.state.discard.has(lynx),
			"山猫被击破：原卡不进弃牌区（改为回手）")
	# 赤狐（R65 改）：使用后从牌组抽**一张**技能牌，**只有那一张**本回合费用 -1。
	# 说明：start_game 会发「开局手牌 + 回合开始抽牌」，小牌组会被抽空，
	# 因此这里手动把赤狐放到手牌首位、把技能牌留在牌组，隔离测试赤狐机制本身。
	var fox := repo.get_card(9034)
	check(fox.effect_text.contains("该卡本回合费用 -1")
			and not fox.effect_text.contains("本回合出牌费用"),
			"R65 赤狐 9034：卡面写明「该卡本回合费用 -1」（不再是全局出牌减费）")
	var eng_fox := _new_engine([], 20, 20, -1, false)
	eng_fox.start_game(1)
	eng_fox.state.hand = [fox]
	eng_fox.state.deck = [
		_card(8002, "攻击", "技能", 1, 0, 0),
		_card(8002, "攻击", "技能", 1, 0, 0),
		_card(8002, "攻击", "技能", 1, 0, 0),
	]
	eng_fox.state.energy = 5
	eng_fox.play_from_hand(0, Vector2i(4, 1))   # 打赤狐（hand[0] = 赤狐）
	check(eng_fox.state.self_cost_reduction == 0,
			"R65 赤狐：**不再**设全局 self_cost_reduction（原来会让所有牌都便宜）")
	check(eng_fox.state.hand.any(func(c: CardData): return c.kind == "技能"),
			"赤狐：从牌组抽到一张技能牌")
	check(eng_fox.state.hand.size() == 1, "赤狐：抽到技能牌后手牌数不变（赤狐离手 + 抽 1）")
	var fox_got: CardData = null
	for c: CardData in eng_fox.state.hand:
		fox_got = c
	# 抽到的那张本回合 -1（1 费 → 0 费）
	check(eng_fox.cost_of(fox_got) == 0 and eng_fox.can_pay_card(fox_got),
			"R65 赤狐：抽到的那张技能牌本回合 1 费 → %d 费" % eng_fox.cost_of(fox_got))
	# **同名的另一张不受影响**（减费按实例记，且取到的牌是独立副本）
	eng_fox.state.hand.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var others: Array[CardData] = []
	for c2: CardData in eng_fox.state.hand:
		if c2 != fox_got:
			others.append(c2)
	check(others.size() == 1 and eng_fox.cost_of(others[0]) == 1,
			"R65 赤狐：手里**其它**技能牌仍是 1 费（只减自己抽到的那张，实际 %d）"
			% eng_fox.cost_of(others[0]))
	# 回合结束减费失效
	eng_fox.state.energy = 0
	eng_fox.current_side = GameEngine.SIDE_SELF
	eng_fox.end_turn()
	check(eng_fox.state.turn_card_discount.is_empty()
			and eng_fox.cost_of(fox_got) == 1,
			"R65 赤狐：减费不跨回合（清零后那张恢复 %d 费）" % eng_fox.cost_of(fox_got))
	# 魔法学徒 9081：与赤狐同一套机制（一起改）
	var r65_appr := repo.get_card(9081)
	check(r65_appr.effect_text.contains("该卡本回合费用 -1")
			and not r65_appr.effect_text.contains("本回合出牌费用"),
			"R65 魔法学徒 9081：卡面同样改成「该卡本回合费用 -1」")
	var eng_ap := _new_engine([], 20, 20, -1, false)
	eng_ap.start_game(1)
	eng_ap.state.hand = [appr]
	eng_ap.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0),
			_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_ap.state.energy = 5
	eng_ap.play_from_hand(0, Vector2i(4, 1))
	var ap_got: CardData = null
	for c3: CardData in eng_ap.state.hand:
		ap_got = c3
	check(eng_ap.state.self_cost_reduction == 0 and ap_got != null
			and eng_ap.cost_of(ap_got) == 0,
			"R65 魔法学徒：同赤狐 —— 不设全局减费，只给自己取到的那张 -1")

	# ---- 协同攻击 / 野兽之心 / 森林守护（9035~9037，2026-09-30 新增） ----
	var coord := repo.get_card(9035)
	check(coord.is_spell() and coord.cost == 3 and coord.rarity == 0
				and coord.needs_target() and coord.target_mode == "unit",
			"协同攻击：普通 3 费技能，需选目标")
	var beast := repo.get_card(9036)
	check(beast.is_effect() and beast.cost == 1 and beast.rarity == 2
				and beast.traits.has("野性") and beast.value == 2,
			"野兽之心：史诗 1 费效果卡（trait 野性 / value 2）")
	var guard_card := repo.get_card(9037)
	check(guard_card.is_spell() and guard_card.cost == 0 and guard_card.rarity == 1
				and guard_card.needs_target() and guard_card.target_mode == "unit",
			"森林守护：稀有 0 费技能，需选目标")

	# 协同攻击：我方场上每有一个盟友 → 实际费用 -1（实时；最低 0；只数我方）
	var eng_coord := _new_engine([], 20, 20, -1, false)
	eng_coord.start_game(1)
	var coord_foe := _card(9001, "鸭子骑士", "盟友", 6, 5, 30)
	eng_coord.state.place(coord_foe, Vector2i(1, 0), "opponent")
	eng_coord.state.hand = [coord]
	check(eng_coord.cost_of(coord) == 3, "协同攻击：我方场上无盟友 → 费用 3（基础）")
	eng_coord.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	check(eng_coord.cost_of(coord) == 2, "协同攻击：我方 1 个盟友 → 费用 2")
	eng_coord.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1))
	eng_coord.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 2))
	check(eng_coord.cost_of(coord) == 0,
			"协同攻击：我方 3 个盟友 → 费用 0（不为负；敌方盟友不计）")
	eng_coord.state.energy = 0
	check(eng_coord.can_pay_card(coord), "协同攻击：0 费时即使能量为 0 也能打出")
	eng_coord.state.energy = 3
	eng_coord.use_spell(0, Vector2i(1, 0))   # 打敌方鸭子骑士
	check(eng_coord.state.energy == 3, "协同攻击：实际费用 0 → 一点能量都不扣")
	var coord_q: Placement = eng_coord.state.unit_at(Vector2i(1, 0))
	check(coord_q != null and coord_q.health == 16, "协同攻击：造成 14 点伤害（30 → 16）")

	# 野兽之心：① 从手牌使用盟友 +2 生命；② 我方盟友造成的伤害 +1（工事不算）
	var eng_beast := _new_engine([], 20, 20, -1, false)
	eng_beast.start_game(1)
	eng_beast.state.hand = [beast]
	eng_beast.state.energy = 5
	eng_beast.use_effect(0)
	check(eng_beast.state.effects.has(beast), "野兽之心：使用后进入我方效果区")
	eng_beast.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]
	eng_beast.state.energy = 5
	eng_beast.play_from_hand(0, Vector2i(4, 0))
	var beast_p: Placement = eng_beast.state.unit_at(Vector2i(4, 0))
	check(beast_p != null and beast_p.health == 10,
			"野兽之心：从手牌使用盟友 +2 生命（8 → 10）")
	eng_beast.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30), Vector2i(3, 0), "opponent")
	eng_beast.attack(Vector2i(4, 0), Vector2i(3, 0))
	var beast_q: Placement = eng_beast.state.unit_at(Vector2i(3, 0))
	check(beast_q != null and beast_q.health == 26,
			"野兽之心：盟友攻击伤害 +1（3 + 1 = 4，30 → 26）")
	eng_beast.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30), Vector2i(3, 2), "opponent")
	eng_beast.state.place(_card(9019, "箭塔", "工事", 3, 5, 10, 2, 0), Vector2i(4, 2))
	eng_beast.attack(Vector2i(4, 2), Vector2i(3, 2))
	var beast_t: Placement = eng_beast.state.unit_at(Vector2i(3, 2))
	check(beast_t != null and beast_t.health == 25,
			"野兽之心：工事不是盟友，不吃伤害 +1（5 点，30 → 25）")

	# 森林守护：指定盟友 → 我方 HP 受伤时改由它承受（溢出也算它的；同一单位不可重复）
	var eng_guard := _new_engine([], 20, 20, -1, false)
	eng_guard.start_game(1)
	eng_guard.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_guard.state.hand = [guard_card]
	eng_guard.state.energy = 5
	eng_guard.use_spell(0, Vector2i(4, 0))
	var guard_p: Placement = eng_guard.state.unit_at(Vector2i(4, 0))
	check(guard_p != null and guard_p.guarding, "森林守护：指定盟友获得守护")
	check(eng_guard._guard_cell() == Vector2i(4, 0), "森林守护：引擎能查到守护格")
	eng_guard.state.hp_self = 20
	eng_guard._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(eng_guard.state.hp_self == 20 and guard_p.health == 3,
			"森林守护：我方 HP 不减，改由盟友承受 5 点（8 → 3）")
	eng_guard._damage_player(GameEngine.SIDE_SELF, 9, "测试")
	check(eng_guard.state.hp_self == 20, "森林守护：一击打死盟友时溢出不漏回我方 HP")
	check(eng_guard.state.unit_at(Vector2i(4, 0)) == null, "森林守护：扛满伤害后盟友阵亡移出场外")
	eng_guard.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1))
	eng_guard.state.hand = [guard_card]
	var guard_first := eng_guard.use_spell(0, Vector2i(4, 1))
	check(guard_first.contains("获得森林守护"), "森林守护：可为另一个盟友再给一次")
	eng_guard.state.hand = [guard_card]
	var guard_dup := eng_guard.use_spell(0, Vector2i(4, 1))
	check(guard_dup.contains("不可重复获得"), "森林守护：同一单位重复施放被拒绝（%s）" % guard_dup)

	# ---- 狮子（9038，2026-09-30 新增） ----
	var lion := repo.get_card(9038)
	check(lion.kind == "盟友" and lion.cost == 4 and lion.power == 6
				and lion.health == 16 and lion.rarity == 2
				and lion.attack_range == 1 and lion.move_speed == 1,
			"狮子：史诗 4 费 6/16 程1 速1")
	# 自己弃牌区每有一个盟友 → 费用 -1（实时；技能/工事不算；最低 0）
	var eng_lion := _new_engine([], 20, 20, -1, false)
	eng_lion.start_game(1)
	eng_lion.state.hand = [lion]
	check(eng_lion.cost_of(lion) == 4, "狮子：弃牌区无盟友 → 费用 4（基础）")
	eng_lion.state.discard.append(_card(8003, "农民", "盟友", 3, 3, 8))
	check(eng_lion.cost_of(lion) == 3, "狮子：弃牌区 1 个盟友 → 费用 3")
	eng_lion.state.discard.append(_card(8002, "攻击", "技能", 1, 0, 0))
	eng_lion.state.discard.append(_card(8001, "木栅栏", "工事", 2, 0, 6))
	check(eng_lion.cost_of(lion) == 3, "狮子：弃牌区的技能/工事不计入减费")
	for i in 3:
		eng_lion.state.discard.append(_card(8003, "农民", "盟友", 3, 3, 8))
	check(eng_lion.cost_of(lion) == 0, "狮子：弃牌区 4 个盟友 → 费用 4-4=0（不为负）")
	eng_lion.state.energy = 0
	check(eng_lion.can_pay_card(lion), "狮子：实际费用 0 时 0 能量也能打出")
	# 使用时：自己场上「其他」盟友攻击 +2（不含狮子自己；永久保留）
	eng_lion.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_lion.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 2))
	eng_lion.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(3, 0))
	eng_lion.state.place(_card(9399, "敌狼", "盟友", 4, 2, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)   # 敌方盟友：不应吃到狮子的 +2
	eng_lion.state.hand = [lion]
	eng_lion.state.energy = 5
	eng_lion.play_from_hand(0, Vector2i(4, 1))
	var lion_self: Placement = eng_lion.state.unit_at(Vector2i(4, 1))
	check(lion_self != null and lion_self.atk_buff == 0
				and lion_self.effective_power() == 6,
			"狮子：自己不吃 +2（atk_buff 0，保持 6 攻）")
	var lion_a: Placement = eng_lion.state.unit_at(Vector2i(4, 0))
	var lion_b: Placement = eng_lion.state.unit_at(Vector2i(4, 2))
	check(lion_a != null and lion_a.atk_buff == 2 and lion_a.effective_power() == 5
				and lion_b != null and lion_b.atk_buff == 2 and lion_b.effective_power() == 5,
			"狮子：使用时场上 2 个盟友攻击 +2（3 → 5，永久保留）")
	var lion_w: Placement = eng_lion.state.unit_at(Vector2i(3, 0))
	check(lion_w != null and lion_w.atk_buff == 0,
			"狮子：工事不是盟友，不吃 +2（atk_buff 仍 0）")
	var lion_foe: Placement = eng_lion.state.unit_at(Vector2i(1, 0))
	check(lion_foe != null and lion_foe.atk_buff == 0
				and lion_foe.effective_power() == 2,
			"狮子：敌方盟友不吃 +2（保持 2 攻）")
	eng_lion._begin_turn(GameEngine.SIDE_SELF)
	check(lion_a != null and lion_a.atk_buff == 2 and lion_a.effective_power() == 5,
			"狮子：+2 永久保留（下回合开始仍在）")

	# 乌鸦 / 猎犬 / 快速出击（9039~9041，2026-09-30）
	var nc_crow := repo.get_card(9039)
	check(nc_crow.kind == "盟友" and nc_crow.cost == 1 and nc_crow.power == 1
			and nc_crow.health == 1 and nc_crow.rarity == 1
			and nc_crow.attack_range == 1 and nc_crow.move_speed == 1,
			"乌鸦：稀有 1 费 1/1 程1 速1")
	var nc_hound := repo.get_card(9040)
	check(nc_hound.kind == "盟友" and nc_hound.cost == 3 and nc_hound.power == 3
			and nc_hound.health == 12 and nc_hound.rarity == 0,
			"猎犬：普通 3 费 3/12 程1 速1")
	var nc_qs := repo.get_card(9041)
	check(nc_qs.is_spell() and nc_qs.cost == 1 and nc_qs.rarity == 1
			and not nc_qs.needs_target(),
			"快速出击：稀有技能 1 费、无需选目标")

	# 乌鸦：使用后必须从弃牌堆选一张盟友回手（引擎只给选项与结算，选谁由 UI 决定）
	var eng_crow := _new_engine([], 20, 20, -1, false)
	eng_crow.start_game(1)
	eng_crow.state.discard.append(_card(8002, "攻击", "技能", 1, 0, 0))
	eng_crow.state.hand = [repo.get_card(9039)]
	eng_crow.state.energy = 5
	eng_crow.play_from_hand(0, Vector2i(4, 0))
	check(not eng_crow.crow_pending, "乌鸦：弃牌堆只有技能牌 → 不进入待选（效果落空）")
	eng_crow.state.discard.append(_card(8003, "农民", "盟友", 3, 3, 8))
	eng_crow.state.hand = [repo.get_card(9039)]
	eng_crow.state.energy = 5
	eng_crow.play_from_hand(0, Vector2i(4, 2))
	check(eng_crow.crow_pending, "乌鸦：使用后进入「从弃牌堆选盟友」待选状态")
	var crow_opts := eng_crow.crow_options()
	check(crow_opts.size() == 1 and crow_opts[0] == 1,
			"乌鸦：只列弃牌堆里的盟友（技能牌不算）")
	var crow_hand_before := eng_crow.state.hand.size()
	check(eng_crow.crow_recall(1) and eng_crow.state.hand.size() == crow_hand_before + 1
			and eng_crow.state.hand.back().card_name == "农民"
			and not eng_crow.crow_pending,
			"乌鸦：取回选中的盟友 → 进手牌，待选状态清除")
	check(not eng_crow.crow_recall(0), "乌鸦：待选已结算 → 再次取回被拒绝")

	# 乌鸦不能把另一张乌鸦叫回手（2026-10-01）：弃牌堆里的乌鸦不在选项里、也不能被取回
	var eng_crow2 := _new_engine([], 20, 20, -1, false)
	eng_crow2.start_game(1)
	eng_crow2.state.discard.append(repo.get_card(9039))   # 弃牌堆：一张乌鸦
	eng_crow2.state.discard.append(_card(8003, "农民", "盟友", 3, 3, 8))
	eng_crow2.state.hand = [repo.get_card(9039)]
	eng_crow2.state.energy = 5
	eng_crow2.play_from_hand(0, Vector2i(4, 1))
	check(eng_crow2.crow_pending, "乌鸦2：弃牌堆里有盟友 → 进入待选")
	var co2 := eng_crow2.crow_options()
	check(co2.size() == 1 and co2[0] == 1,
			"乌鸦2：弃牌堆里的乌鸦不进回手选项（技能牌、乌鸦都不算）")
	check(not eng_crow2.crow_recall(0), "乌鸦2：直接指名取回乌鸦 → 拒绝")
	check(eng_crow2.crow_recall(1) and eng_crow2.state.hand.back().card_name == "农民",
			"乌鸦2：普通盟友仍可正常取回")

	# 猎犬：使用时按「自己场上其他盟友」数量一次性 +2 力量（快照、不含自己/工事/敌方）
	var eng_hound := _new_engine([], 20, 20, -1, false)
	eng_hound.start_game(1)
	eng_hound.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_hound.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 2))
	eng_hound.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(3, 0))
	eng_hound.state.place(_card(9399, "敌狼", "盟友", 4, 2, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	eng_hound.state.hand = [repo.get_card(9040)]
	eng_hound.state.energy = 5
	eng_hound.play_from_hand(0, Vector2i(4, 1))
	var pl_hound: Placement = eng_hound.state.unit_at(Vector2i(4, 1))
	check(pl_hound != null and pl_hound.atk_buff == 4
			and pl_hound.effective_power() == 7,
			"猎犬：上场时场上 2 个其他盟友 → +4 力量（3 → 7；工事/敌方不算）")
	eng_hound.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 2))
	check(pl_hound.effective_power() == 7, "猎犬：加成是上场快照 → 之后再上盟友不追加")
	eng_hound._destroy(Vector2i(4, 0))
	check(pl_hound.effective_power() == 7, "猎犬：盟友阵亡也不回落（快照）")
	var eng_hound_lone := _new_engine([], 20, 20, -1, false)
	eng_hound_lone.start_game(1)
	eng_hound_lone.state.hand = [repo.get_card(9040)]
	eng_hound_lone.state.energy = 5
	eng_hound_lone.play_from_hand(0, Vector2i(4, 0))
	var pl_hound_lone: Placement = eng_hound_lone.state.unit_at(Vector2i(4, 0))
	check(pl_hound_lone != null and pl_hound_lone.atk_buff == 0
			and pl_hound_lone.effective_power() == 3,
			"猎犬：场上没有其他盟友 → 保持 3 力量（不含自己）")

	# 快速出击：本回合手牌中盟友费用 -1（技能/工事不变；回合开始清零）
	var eng_qs := _new_engine([], 20, 20, -1, false)
	eng_qs.start_game(1)
	var qs_ally := _card(8003, "农民", "盟友", 3, 3, 8)
	var qs_wall := _card(8001, "木栅栏", "工事", 2, 0, 6)
	var qs_spell := _card(8002, "攻击", "技能", 1, 0, 0)
	check(eng_qs.cost_of(qs_ally) == 3 and eng_qs.cost_of(qs_wall) == 2,
			"快速出击：未使用前费用不变")
	eng_qs.state.hand = [repo.get_card(9041)]
	eng_qs.state.energy = 5
	eng_qs.use_spell(0)
	check(eng_qs.state.self_ally_cost_reduction == 1, "快速出击：本回合盟友减费 = 1")
	check(eng_qs.cost_of(qs_ally) == 2, "快速出击：盟友费用 3 → 2")
	check(eng_qs.cost_of(qs_spell) == 1 and eng_qs.cost_of(qs_wall) == 2,
			"快速出击：技能/工事费用不受影响")
	eng_qs.state.energy = 0
	check(not eng_qs.can_pay_card(qs_ally), "快速出击：减后 2 费在 0 能量时仍打不出")
	eng_qs._begin_turn(GameEngine.SIDE_SELF)
	check(eng_qs.state.self_ally_cost_reduction == 0 and eng_qs.cost_of(qs_ally) == 3,
			"快速出击：回合开始清零 → 盟友费用回到 3")

	# 撕咬（9042）：指定己方盟友本回合力量 +8（回合结束清除；可叠加；只认己方盟友）
	var nc_bite := repo.get_card(9042)
	check(nc_bite.is_spell() and nc_bite.cost == 1 and nc_bite.rarity == 0
			and nc_bite.needs_target() and nc_bite.target_mode == "unit",
			"撕咬：普通技能 1 费、需要选单位目标")
	var eng_bite := _new_engine([], 20, 20, -1, false)
	eng_bite.start_game(1)
	eng_bite.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	var bite_ally: Placement = eng_bite.state.unit_at(Vector2i(4, 0))
	check(bite_ally != null and bite_ally.effective_power() == 3, "撕咬：施放前农民 3 力量")
	eng_bite.state.hand = [repo.get_card(9042)]
	eng_bite.state.energy = 5
	eng_bite.use_spell(0, Vector2i(4, 0))
	check(bite_ally.atk_buff_turn == 8 and bite_ally.effective_power() == 11,
			"撕咬：指定己方盟友 → 本回合 +8 力量（3 → 11）")
	eng_bite.state.hand = [repo.get_card(9042)]
	eng_bite.state.energy = 5
	eng_bite.use_spell(0, Vector2i(4, 0))
	check(bite_ally.atk_buff_turn == 16 and bite_ally.effective_power() == 19,
			"撕咬：可叠加（再撕一次 +8 → 19）")
	eng_bite.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 2))
	eng_bite.state.place(_card(9399, "敌狼", "盟友", 4, 2, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	eng_bite.state.hand = [repo.get_card(9042)]
	eng_bite.state.energy = 5
	var bite_fort := eng_bite.use_spell(0, Vector2i(4, 2))
	check(bite_fort.contains("己方盟友"),
			"撕咬：工事不是盟友 → 被拒绝（%s）" % bite_fort)
	eng_bite.state.hand = [repo.get_card(9042)]
	eng_bite.state.energy = 5
	var bite_foe := eng_bite.use_spell(0, Vector2i(1, 0))
	check(bite_foe.contains("己方盟友"),
			"撕咬：敌方盟友 → 被拒绝（%s）" % bite_foe)
	eng_bite.end_turn()
	check(bite_ally.atk_buff_turn == 0 and bite_ally.effective_power() == 3,
			"撕咬：回合结束 → 本回合加成清除（回到 3）")

	# 冰墙术（9043）：在一条横行上生成 3 面冰墙（0/10）；只限自己半场；回合开始融化（不进弃牌区）
	var nc_iw := repo.get_card(9043)
	check(nc_iw.is_spell() and nc_iw.cost == 3 and nc_iw.rarity == 1
			and nc_iw.needs_target() and nc_iw.target_mode == "cell",
			"冰墙术：稀有技能 3 费、需要选格子目标")
	var nc_iw_token := repo.get_card(9044)
	check(nc_iw_token.kind == "工事" and nc_iw_token.power == 0
			and nc_iw_token.health == 10 and nc_iw_token.attack_range == 0
			and nc_iw_token.move_speed == 0 and nc_iw_token.rarity == 5,
			"冰墙：工事 token 0 力 10 血 程0 速0（rarity 5，不进奖励池）")
	var eng_iw := _new_engine([], 20, 20, -1, false)
	eng_iw.start_game(1)
	eng_iw.state.hand = [repo.get_card(9043)]
	eng_iw.state.energy = 5
	eng_iw.use_spell(0, Vector2i(4, 1))
	var iw_n := 0
	for iw_col in FieldState.BOARD_COLS:
		var iw_q: Placement = eng_iw.state.unit_at(Vector2i(4, iw_col))
		if iw_q != null and iw_q.card.id == 9044:
			iw_n += 1
	check(iw_n == 3, "冰墙术：一条横行生成 3 面冰墙（实际 %d）" % iw_n)
	eng_iw.state.hand = [repo.get_card(9043)]
	eng_iw.state.energy = 5
	var iw_foe := eng_iw.use_spell(0, Vector2i(1, 0))
	check(iw_foe.contains("自己半场"), "冰墙术：敌方半场的行被拒绝（%s）" % iw_foe)
	# 先给牌库塞够垫底牌（回合开始抽 5 张，牌库抽空会把弃牌区洗回来，干扰下面的断言）
	eng_iw.state.deck = []
	for iw_i in 8:
		eng_iw.state.deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var iw_disc := eng_iw.state.discard.size()
	eng_iw._begin_turn(GameEngine.SIDE_SELF)
	var iw_left := 0
	for iw_cell: Vector2i in eng_iw.state.board:
		if eng_iw.state.board[iw_cell].card.id == 9044:
			iw_left += 1
	check(iw_left == 0, "冰墙术：我方回合开始 → 冰墙全部融化（剩 %d）" % iw_left)
	var iw_wall_disc := false
	for iw_dc: CardData in eng_iw.state.discard:
		if iw_dc.id == 9044:
			iw_wall_disc = true
	check(not iw_wall_disc and eng_iw.state.discard.size() == iw_disc,
			"冰墙术：融化的冰墙不进弃牌区（弃牌区仍 %d 张）" % eng_iw.state.discard.size())

	# 疾风之力（9045）：每个己方盟友进入战场 → 随机对一个敌人造成 4 点伤害
	var nc_wf := repo.get_card(9045)
	check(nc_wf.is_effect() and nc_wf.cost == 2 and nc_wf.rarity == 2
			and nc_wf.traits.has("疾风") and nc_wf.value == 4,
			"疾风之力：史诗效果卡 2 费、trait 疾风 value=4")
	var eng_wf := _new_engine([], 20, 20, -1, false)
	eng_wf.start_game(1)
	eng_wf.state.place(_card(9398, "敌狼", "盟友", 4, 3, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	var wf_foe: Placement = eng_wf.state.unit_at(Vector2i(1, 0))
	eng_wf.state.hand = [repo.get_card(9045)]
	eng_wf.state.energy = 5
	eng_wf.use_effect(0)
	eng_wf.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]
	eng_wf.state.energy = 5
	eng_wf.play_from_hand(0, Vector2i(4, 0))
	check(wf_foe.health == 5, "疾风之力：盟友登场 → 敌方单位 -4（9 → %d）" % wf_foe.health)
	var eng_wf2 := _new_engine([], 20, 20, -1, false)
	eng_wf2.start_game(1)
	eng_wf2.state.hand = [repo.get_card(9045)]
	eng_wf2.state.energy = 5
	eng_wf2.use_effect(0)
	eng_wf2.state.hand = [_card(8003, "农民", "盟友", 3, 3, 8)]
	eng_wf2.state.energy = 5
	eng_wf2.play_from_hand(0, Vector2i(4, 0))
	check(eng_wf2.state.hp_opponent == 16,
			"疾风之力：场上无敌人 → 直击敌方 HP 4 点（20 → %d）" % eng_wf2.state.hp_opponent)

	# 巨鼠（9046）：使用后从卡组随机抽一张「1 费盟友」加入手卡
	var nc_rat := repo.get_card(9046)
	check(nc_rat.kind == "盟友" and nc_rat.cost == 1 and nc_rat.power == 1
			and nc_rat.health == 1 and nc_rat.attack_range == 1
			and nc_rat.move_speed == 1 and nc_rat.rarity == 0,
			"巨鼠：普通盟友 1 费 1/1 程1 速1")
	var eng_rat := _new_engine([], 20, 20, -1, false)
	eng_rat.start_game(1)
	eng_rat.state.deck = [_card(9099, "野兔", "盟友", 1, 1, 2),
			_card(9100, "大熊", "盟友", 4, 5, 9)]
	eng_rat.state.hand = [repo.get_card(9046)]
	eng_rat.state.energy = 5
	eng_rat.play_from_hand(0, Vector2i(4, 0))
	var rat_ok := false
	for rat_c: CardData in eng_rat.state.hand:
		if rat_c.id == 9099:
			rat_ok = true
	check(rat_ok, "巨鼠：使用后从卡组抽到 1 费盟友（野兔）入手中")
	check(eng_rat.state.deck.size() == 1 and eng_rat.state.deck[0].id == 9100,
			"巨鼠：只抽 1 费盟友（4 费大熊留在卡组）")
	var eng_rat2 := _new_engine([], 20, 20, -1, false)
	eng_rat2.start_game(1)
	eng_rat2.state.deck = [_card(9100, "大熊", "盟友", 4, 5, 9)]
	eng_rat2.state.hand = [repo.get_card(9046)]
	eng_rat2.state.energy = 5
	eng_rat2.play_from_hand(0, Vector2i(4, 0))
	check(eng_rat2.state.hand.is_empty(),
			"巨鼠：卡组没有 1 费盟友 → 落空（手牌不增加）")

	# 机械巨鸭（9047）/ 发条鸭（9048）/ 齿轮升腾（9049）：第二层 Boss 与召唤循环
	var nc_md := repo.get_card(9047)
	check(nc_md.card_name == "机械巨鸭" and nc_md.kind == "盟友" and nc_md.power == 10
			and nc_md.health == 150 and nc_md.attack_range == 3
			and nc_md.move_speed == 1 and nc_md.rarity == 4
			and nc_md.traits.has("发条") and nc_md.value == 2,
			"机械巨鸭：怪物盟友 10/150 程3 速1，trait 发条 value=2")
	var nc_ck := repo.get_card(9048)
	check(nc_ck.card_name == "发条鸭" and nc_ck.power == 4 and nc_ck.health == 5
			and nc_ck.attack_range == 1 and nc_ck.move_speed == 1 and nc_ck.rarity == 5,
			"发条鸭：4 力 5 血 程1 速1（token，不进奖励池）")
	var nc_mg := repo.get_card(9049)
	check(nc_mg.card_name == "齿轮升腾" and nc_mg.kind == "效果"
			and nc_mg.traits.has("机械成长") and nc_mg.value == 2 and nc_mg.rarity == 4,
			"齿轮升腾：效果卡 trait 机械成长 value=2（不进奖励池）")

	# 机械巨鸭：首回合开始即把发条鸭补齐到 2 只，之后只补差额
	var eng_mech := _new_engine([], 20, 60, -1, false)
	eng_mech.state.place(repo.get_card(9047), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	eng_mech.start_game(0)
	var md_have := 0
	for md_c: Vector2i in eng_mech.state.board:
		if eng_mech.state.board[md_c].card.id == 9048:
			md_have += 1
	check(md_have == 2, "机械巨鸭：首回合开始即补齐 2 只发条鸭（实际 %d）" % md_have)
	var md_owned := true
	for md_c2: Vector2i in eng_mech.state.board:
		if eng_mech.state.board[md_c2].card.id == 9048 \
				and eng_mech.state.board[md_c2].owner != GameEngine.SIDE_OPPONENT:
			md_owned = false
	check(md_owned, "机械巨鸭：发条鸭归属巨鸭一方（敌方）")
	eng_mech._begin_turn(GameEngine.SIDE_OPPONENT)
	var md_have2 := 0
	for md_c3: Vector2i in eng_mech.state.board:
		if eng_mech.state.board[md_c3].card.id == 9048:
			md_have2 += 1
	check(md_have2 == 2, "机械巨鸭：已有 2 只时不再多召（实际 %d）" % md_have2)
	for md_c4: Vector2i in eng_mech.state.board.keys().duplicate():
		if eng_mech.state.board[md_c4].card.id == 9048:
			eng_mech._destroy(md_c4)
			break
	eng_mech._begin_turn(GameEngine.SIDE_SELF)
	var md_have3 := 0
	for md_c5: Vector2i in eng_mech.state.board:
		if eng_mech.state.board[md_c5].card.id == 9048:
			md_have3 += 1
	check(md_have3 == 2, "机械巨鸭：少一只 → 下个回合开始补回 2 只（实际 %d）" % md_have3)

	# 齿轮升腾：所属方回合开始所有友方永久 +2（无上限，不影响对方）
	var eng_mgrow := _new_engine([], 20, 60, -1, false)
	eng_mgrow.enable_enemy_effects([repo.get_card(9049)])
	var mg_mech: Placement = eng_mgrow.state.place(
			repo.get_card(9047), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var mg_ally: Placement = eng_mgrow.state.place(
			_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(mg_mech.atk_buff == 0, "齿轮升腾：回合开始前不加成")
	eng_mgrow._begin_turn(GameEngine.SIDE_OPPONENT)
	check(mg_mech.atk_buff == 2 and mg_mech.effective_power() == 12,
			"齿轮升腾：敌方回合开始 → 机械巨鸭 +2（10 → %d）" % mg_mech.effective_power())
	check(mg_ally.atk_buff == 0 and mg_ally.effective_power() == 3,
			"齿轮升腾：只加敌方，我方单位不受影响")
	eng_mgrow._begin_turn(GameEngine.SIDE_OPPONENT)
	eng_mgrow._begin_turn(GameEngine.SIDE_OPPONENT)
	check(mg_mech.atk_buff == 6 and mg_mech.effective_power() == 16,
			"齿轮升腾：永久累加无上限（3 回合后 +6 → %d）" % mg_mech.effective_power())

	# 鲸鱼之怒（9050）：1 费技能，造成 11 伤 → 从弃牌堆取 2 张卡入手（使用后本场消失）
	var nc_wh := repo.get_card(9050)
	check(nc_wh.card_name == "鲸鱼之怒" and nc_wh.is_spell() and nc_wh.cost == 1
			and nc_wh.rarity == 5 and nc_wh.traits.has("事件")
			and nc_wh.needs_target() and nc_wh.target_mode == "unit",
			"鲸鱼之怒：1 费事件技能，需选单位目标（不可奖励获取）")
	var eng_wh := _new_engine([], 20, 20, -1, false)
	eng_wh.start_game(1)
	eng_wh.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]   # 垫底：防回合开始抽牌洗回弃牌区
	eng_wh.state.place(_card(9397, "敌狼", "盟友", 4, 3, 9), Vector2i(1, 1),
			GameEngine.SIDE_OPPONENT)
	var wh_foe: Placement = eng_wh.state.unit_at(Vector2i(1, 1))
	eng_wh.state.discard = [_card(8001, "木栅栏", "工事", 2, 0, 6),
			_card(8003, "农民", "盟友", 3, 3, 8), _card(8002, "攻击", "技能", 1, 0, 0)]
	eng_wh.state.hand = [repo.get_card(9050)]
	eng_wh.state.energy = 5
	eng_wh.use_spell(0, Vector2i(1, 1))
	check(wh_foe.health <= 0, "鲸鱼之怒：对目标造成 11 点伤害（9 血敌狼被击破）")
	check(eng_wh.whale_pending and eng_wh.whale_remaining == 2,
			"鲸鱼之怒：施放后进入取牌待选（还需取 2 张）")
	check(eng_wh.whale_options().size() == 3, "鲸鱼之怒：弃牌堆 3 张都可取（不限种类）")
	var wh_first: CardData = eng_wh.state.discard[1]
	eng_wh.whale_pick(1)
	check(eng_wh.whale_remaining == 1 and eng_wh.state.hand.has(wh_first),
			"鲸鱼之怒：取回第 1 张（%s）入手，还剩 1 张" % wh_first.card_name)
	eng_wh.whale_skip()
	check(not eng_wh.whale_pending and eng_wh.whale_remaining == 0,
			"鲸鱼之怒：可放弃剩余取牌（不强制选满）→ 待选结束")

	var eng_wh2 := _new_engine([], 20, 20, -1, false)
	eng_wh2.start_game(1)
	eng_wh2.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_wh2.state.discard = [_card(8001, "木栅栏", "工事", 2, 0, 6),
			_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_wh2.state.hand = [repo.get_card(9050)]
	eng_wh2.state.energy = 5
	eng_wh2.use_spell(0, Vector2i(1, 1))   # (1,1) 没有单位 → 直击敌方 HP
	check(eng_wh2.state.hp_opponent == 9,
			"鲸鱼之怒：无可指定目标 → 直击敌方 HP 11 点（20 → %d）" % eng_wh2.state.hp_opponent)
	check(eng_wh2.state.discard.size() == 2,
			"鲸鱼之怒：使用后消失，不进弃牌区（弃牌堆仍 2 张）")
	var wh_got := 0
	while eng_wh2.whale_pending and not eng_wh2.state.discard.is_empty():
		if not eng_wh2.whale_pick(0):
			break
		wh_got += 1
	check(wh_got == 2 and not eng_wh2.whale_pending,
			"鲸鱼之怒：取满 2 张后自动结束待选（实际取 %d 张）" % wh_got)
	var wh_self_in_disc := false
	for wh_dc: CardData in eng_wh2.state.discard:
		if wh_dc.id == 9050:
			wh_self_in_disc = true
	check(not wh_self_in_disc, "鲸鱼之怒：本场弃牌区里没有鲸鱼之怒（用后消失）")

	# 自然之力（9051）：1 费技能，回复 1 点费用 + 我方场上每个盟友额外回复 1 点
	var nc_nf := repo.get_card(9051)
	check(nc_nf.card_name == "自然之力" and nc_nf.is_spell() and nc_nf.cost == 1
			and nc_nf.rarity == 1 and not nc_nf.needs_target(),
			"自然之力：稀有 1 费技能，无需目标")
	var eng_nf := _new_engine([], 20, 20, -1, false)
	eng_nf.start_game(1)
	eng_nf.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]   # 垫底：防回合开始抽牌洗回弃牌区
	eng_nf.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_nf.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1))
	eng_nf.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 2))
	eng_nf.state.hand = [repo.get_card(9051)]
	eng_nf.state.energy = 3
	eng_nf.use_spell(0)
	check(eng_nf.state.energy == 5,
			"自然之力：回复 1 + 盟友数（2 个）点费用（3 - 1 + 3 = %d）" % eng_nf.state.energy)
	check(eng_nf.state.discard.has(repo.get_card(9051)),
			"自然之力：使用后进入弃牌区（普通技能结算）")
	var eng_nf2 := _new_engine([], 20, 20, -1, false)
	eng_nf2.start_game(1)
	eng_nf2.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_nf2.state.hand = [repo.get_card(9051)]
	eng_nf2.state.energy = 3
	eng_nf2.use_spell(0)
	check(eng_nf2.state.energy == 3,
			"自然之力：场上没有盟友时只回复 1 点（3 - 1 + 1 = %d）" % eng_nf2.state.energy)

	# 坚韧（9053）：1 费技能，场上所有自己盟友获得 +3 生命（工事/敌方不计入）
	var nc_ten := repo.get_card(9053)
	check(nc_ten.card_name == "坚韧" and nc_ten.is_spell() and nc_ten.cost == 1
			and nc_ten.rarity == 1 and nc_ten.target_mode == "none" and not nc_ten.needs_target(),
			"坚韧：普通 1 费技能，无需目标")
	var eng_ten := _new_engine([], 20, 20, -1, false)
	eng_ten.start_game(1)
	eng_ten.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_ten.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_ten.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1))
	eng_ten.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 2))
	eng_ten.state.place(_card(9399, "敌狼", "盟友", 4, 2, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	var ten_a: Placement = eng_ten.state.unit_at(Vector2i(4, 0))
	var ten_b: Placement = eng_ten.state.unit_at(Vector2i(4, 1))
	var ten_fort: Placement = eng_ten.state.unit_at(Vector2i(4, 2))
	var ten_foe: Placement = eng_ten.state.unit_at(Vector2i(1, 0))
	check(ten_a.health == 8 and ten_b.health == 8 and ten_fort.health == 6
			and ten_foe.health == 9, "坚韧：施放前生命（农民8/农民8/木栅6/敌狼9）")
	eng_ten.state.hand = [repo.get_card(9053)]
	eng_ten.state.energy = 5
	var ten_ret := eng_ten.use_spell(0)
	check(ten_a.health == 11 and ten_b.health == 11,
			"坚韧：两个己方盟友 +3 生命（8 → 11）")
	check(ten_fort.health == 6 and ten_foe.health == 9,
			"坚韧：工事与敌方盟友不受影响（6 / 9）")
	check(ten_ret.contains("2 个己方盟友"), "坚韧：结算文案含数量（%s）" % ten_ret)

	# 龙息（9054）：史诗 3 费技能，对一个敌方单位造成 3 点伤害、重复 6 次
	var lg_c := repo.get_card(9054)
	check(lg_c.card_name == "龙息" and lg_c.is_spell() and lg_c.cost == 3
			and lg_c.rarity == 2 and lg_c.target_mode == "unit" and lg_c.needs_target(),
			"龙息：史诗 3 费技能，需要选单位目标")
	var lg_e := _new_engine([], 20, 20, -1, false)
	lg_e.start_game(1)
	lg_e.state.place(_card(9398, "厚甲敌", "盟友", 5, 4, 40), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	lg_e.state.hand = [repo.get_card(9054)]
	lg_e.state.energy = 9
	var lg_p: Placement = lg_e.state.unit_at(Vector2i(1, 0))
	var lg_r := lg_e.use_spell(0, Vector2i(1, 0))
	check(lg_p.health == 22, "龙息：3 点 × 6 次 = 18 点（40 → 22，实际 %d）" % lg_p.health)
	check(lg_r.contains("6 次"), "龙息：结算文案标注次数（%s）" % lg_r)
	# 目标中途死亡 → 后续次数落空
	var lg_e2 := _new_engine([], 20, 20, -1, false)
	lg_e2.start_game(1)
	lg_e2.state.place(_card(9397, "残血敌", "盟友", 3, 2, 3), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	lg_e2.state.hand = [repo.get_card(9054)]
	lg_e2.state.energy = 9
	var lg_r2 := lg_e2.use_spell(0, Vector2i(1, 0))
	check(lg_e2.state.unit_at(Vector2i(1, 0)) == null and lg_r2.contains("1 次"),
			"龙息：目标中途死亡 → 后续次数落空（只结算 1 次，%s）" % lg_r2)
	# 法术免疫单位完全免疫（熔岩巨人 1071）
	var lg_e3 := _new_engine([], 20, 20, -1, false)
	lg_e3.start_game(1)
	lg_e3.state.place(repo.get_card(1071), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	lg_e3.state.hand = [repo.get_card(9054)]
	lg_e3.state.energy = 9
	var lg_r3 := lg_e3.use_spell(0, Vector2i(1, 0))
	check(lg_e3.state.unit_at(Vector2i(1, 0)).health == 70 and lg_r3.contains("免疫"),
			"龙息：法术免疫单位完全免疫（%s）" % lg_r3)
	# 只打敌方：指定己方单位 / 空目标都被拒绝
	var lg_e4 := _new_engine([], 20, 20, -1, false)
	lg_e4.start_game(1)
	lg_e4.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	lg_e4.state.hand = [repo.get_card(9054)]
	lg_e4.state.energy = 9
	var lg_r4 := lg_e4.use_spell(0, Vector2i(4, 0))
	check(lg_r4.contains("敌方单位"), "龙息：指定己方单位被拒绝（%s）" % lg_r4)
	lg_e4.state.hand = [repo.get_card(9054)]
	lg_e4.state.energy = 9
	var lg_r5 := lg_e4.use_spell(0)
	check(lg_r5.contains("敌方单位"), "龙息：空目标被拒绝（%s）" % lg_r5)

	# 狂暴（9055）：稀有 2 费技能，指定己方盟友本回合可以攻击两次；不可重复；>=3 盟友费用 -1
	var nc_fz := repo.get_card(9055)
	check(nc_fz.card_name == "狂暴" and nc_fz.is_spell() and nc_fz.cost == 2
			and nc_fz.rarity == 1 and nc_fz.target_mode == "unit" and nc_fz.needs_target(),
			"狂暴：稀有 2 费技能，需要选单位目标")
	var eng_fz := _new_engine([], 20, 20, -1, false)
	eng_fz.start_game(1)
	eng_fz.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	var fz_p: Placement = eng_fz.state.unit_at(Vector2i(4, 0))
	check(fz_p.acts_left == 1, "狂暴：施放前农民本回合 1 轮行动")
	eng_fz.state.hand = [repo.get_card(9055)]
	eng_fz.state.energy = 9
	var fz_ret := eng_fz.use_spell(0, Vector2i(4, 0))
	check(fz_p.acts_left == 2 and fz_ret.contains("攻击两次"),
			"狂暴：指定己方盟友 → 本回合可攻击两次（%s）" % fz_ret)
	# 不可重复获得：同一单位再放一次无效
	eng_fz.state.hand = [repo.get_card(9055)]
	eng_fz.state.energy = 9
	var fz_dup := eng_fz.use_spell(0, Vector2i(4, 0))
	check(fz_p.acts_left == 2 and fz_dup.contains("不可重复获得"),
			"狂暴：同一单位重复施放被拒绝、轮数不叠加（%s）" % fz_dup)
	# 工事 / 敌方单位 → 被拒绝
	eng_fz.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 2))
	eng_fz.state.place(_card(9399, "敌狼", "盟友", 4, 2, 9), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	eng_fz.state.hand = [repo.get_card(9055)]
	eng_fz.state.energy = 9
	var fz_fort := eng_fz.use_spell(0, Vector2i(4, 2))
	check(fz_fort.contains("己方盟友"), "狂暴：工事不是盟友 → 被拒绝（%s）" % fz_fort)
	eng_fz.state.hand = [repo.get_card(9055)]
	eng_fz.state.energy = 9
	var fz_foe := eng_fz.use_spell(0, Vector2i(1, 0))
	check(fz_foe.contains("己方盟友"), "狂暴：敌方盟友 → 被拒绝（%s）" % fz_foe)
	# 自带双动的单位（白狼 actions=2）→ 同类效果，无效
	var eng_fz2 := _new_engine([], 20, 20, -1, false)
	eng_fz2.start_game(1)
	eng_fz2.state.place(CardData.from_dict(repo.get_card(9031).to_dict()), Vector2i(4, 0))
	var fz_wolf: Placement = eng_fz2.state.unit_at(Vector2i(4, 0))
	eng_fz2.state.hand = [repo.get_card(9055)]
	eng_fz2.state.energy = 9
	var fz_wr := eng_fz2.use_spell(0, Vector2i(4, 0))
	check(fz_wolf.acts_left == 2 and fz_wr.contains("不可重复获得"),
			"狂暴：自带双动的白狼 → 同类效果无效（%s）" % fz_wr)
	# 费用减免：己方场上盟友 >= 3 时 cost_of 2 → 1（只数「盟友」，工事不计）
	var eng_fzc := _new_engine([], 20, 20, -1, false)
	var fzc := repo.get_card(9055)
	check(eng_fzc.cost_of(fzc) == 2, "狂暴：己方 0 盟友 → 费用 2（未减）")
	eng_fzc.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 0))
	eng_fzc.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1))
	check(eng_fzc.cost_of(fzc) == 2, "狂暴：己方 2 盟友 → 费用仍 2")
	eng_fzc.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 2))
	check(eng_fzc.cost_of(fzc) == 2, "狂暴：2 盟友 + 1 工事 → 工事不计入，费用仍 2")
	eng_fzc.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 0))
	check(eng_fzc.cost_of(fzc) == 1, "狂暴：己方 3 盟友 → 费用 -1（2 → 1）")

	# 镜像（9056）：2 费史诗效果卡；「每回合第一次使用效果牌时」把该牌的**同名副本**加入本局卡组。
	# 不可叠加 → 效果区几张都只触发一次、只加一份；不再抽牌（打出自己那一下不算触发）。
	var nc_mirror := repo.get_card(9056)
	check(nc_mirror.card_name == "镜像" and nc_mirror.is_effect() and nc_mirror.cost == 2
			and nc_mirror.rarity == 2 and nc_mirror.traits.has("镜像") and nc_mirror.value == 1
			and nc_mirror.effect_text.contains("每回合第一次使用效果牌时")
			and nc_mirror.effect_text.contains("不叠加"),
			"镜像：史诗 2 费效果卡，trait 镜像，文案「每回合第一次」+「不叠加」")
	# 打出自身不触发（效果区当时为空 → 无复制）
	var mir_e1 := _new_engine([], 20, 20, -1, false)
	mir_e1.start_game(1)
	mir_e1.state.deck = [repo.get_card(8003)]
	mir_e1.state.hand = [repo.get_card(9056)]
	mir_e1.state.energy = 9
	mir_e1.use_effect(0)
	check(mir_e1.state.effects.size() == 1 and mir_e1.state.deck.size() == 1
			and mir_e1.state.hand.is_empty(),
			"镜像：打出自身那一下不触发（牌组不变）")
	# 镜像已在效果区 → 之后再打效果牌：复制「迅捷」入卡组（不抽牌）
	var mir_e2 := _new_engine([], 20, 20, -1, false)
	mir_e2.start_game(1)
	mir_e2.state.effects.append(repo.get_card(9056))
	mir_e2.state.deck = []
	mir_e2.state.hand = [repo.get_card(9002)]
	mir_e2.state.energy = 9
	mir_e2.use_effect(0)
	check(mir_e2.state.effects.size() == 2 and mir_e2.state.deck.size() == 1
			and mir_e2.state.deck[0].card_name == "迅捷" and mir_e2.state.hand.is_empty(),
			"镜像：本回合第一次使用效果牌 → 一份副本入卡组、不抽牌")
	check(mir_e2.state.deck[0] != mir_e2.state.effects[1],
			"镜像：加入的是同名**副本**（不是同一个对象）")
	var mir_logged := false
	for mir_l in mir_e2.log:
		if str(mir_l).contains("镜像"):
			mir_logged = true
	check(mir_logged, "镜像：触发时有日志记录")
	# 同一回合第二次使用效果牌 → 不再复制
	var mir_e3 := _new_engine([], 20, 20, -1, false)
	mir_e3.start_game(1)
	mir_e3.state.effects.append(repo.get_card(9056))
	mir_e3.state.deck = []
	mir_e3.state.hand = [repo.get_card(9002)]
	mir_e3.state.energy = 9
	mir_e3.use_effect(0)     # 第一次 → 复制 1 份
	check(mir_e3.state.deck.size() == 1 and mir_e3.state.hand.is_empty(),
			"镜像：第一次使用效果牌 → 复制 1 份入卡组")
	mir_e3.state.hand = [repo.get_card(9002)]
	mir_e3.state.energy = 9
	mir_e3.use_effect(0)     # 第二次 → 不再复制
	check(mir_e3.state.deck.size() == 1,
			"镜像：同回合第二次使用效果牌 → 不再复制（仍 1 份）")
	# 不可叠加：效果区 2 张镜像 → 第一次使用仍只加 1 份，第 2 次使用也不触发
	var mir_e4 := _new_engine([], 20, 20, -1, false)
	mir_e4.start_game(1)
	mir_e4.state.effects.append(repo.get_card(9056))
	mir_e4.state.effects.append(repo.get_card(9056))
	mir_e4.state.deck = []
	mir_e4.state.hand = [repo.get_card(9002)]
	mir_e4.state.energy = 9
	mir_e4.use_effect(0)
	check(mir_e4.state.deck.size() == 1,
			"镜像：不可叠加 → 效果区 2 张，第一次使用也只加 1 份")
	mir_e4.state.hand = [repo.get_card(9002)]
	mir_e4.state.energy = 9
	mir_e4.use_effect(0)
	check(mir_e4.state.deck.size() == 1,
			"镜像：不可叠加 → 同回合第 2 次使用不触发（仍 1 份）")
	# 跨回合：新回合第一次使用效果牌 → 再复制 1 份
	mir_e4.end_turn()
	mir_e4.end_turn()
	var mir_deck0 := mir_e4.state.deck.size()
	mir_e4.state.hand = [repo.get_card(9002)]
	mir_e4.state.energy = 9
	mir_e4.use_effect(0)
	check(mir_e4.state.deck.size() == mir_deck0 + 1,
			"镜像：下一回合第一次使用效果牌 → 再复制 1 份")

	# 威慑（9057）：2 费普通效果卡；每回合前 X 次使用效果牌后随机一个敌人力量 -10
	var nc_deter := repo.get_card(9057)
	check(nc_deter.card_name == "威慑" and nc_deter.is_effect() and nc_deter.cost == 2
			and nc_deter.rarity == 0 and nc_deter.traits.has("威慑") and nc_deter.value == 10
			and nc_deter.effect_text.contains("每回合前 X 次"),
			"威慑：普通 2 费效果卡，trait 威慑 value=10，文案为「每回合前 X 次」")
	var det_e1 := _new_engine([], 20, 20, -1, false)
	det_e1.start_game(1)
	det_e1.state.effects.append(repo.get_card(9057))
	det_e1.state.place(_card(9401, "重甲敌", "盟友", 5, 12, 30), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	det_e1.state.place(_card(9402, "自己人", "盟友", 5, 7, 30), Vector2i(4, 0))
	det_e1.state.hand = [repo.get_card(9002)]
	det_e1.state.energy = 9
	det_e1.use_effect(0)
	var det_fp: Placement = det_e1.state.unit_at(Vector2i(1, 0))
	var det_ap: Placement = det_e1.state.unit_at(Vector2i(4, 0))
	check(det_fp.atk_debuff == 10 and det_ap.atk_debuff == 0,
			"威慑：只作用于敌方单位（敌 -10 / 己方 0）")
	check(det_fp.debuff_stage == 1 and det_fp.effective_power() == 2,
			"威慑：**立即生效并显示** → 12 - 10 = 2（实际 %d）" % det_fp.effective_power())
	det_e1.end_turn()   # 我方 → 敌方：敌方回合里削弱仍在
	check(det_fp.atk_debuff == 10 and det_fp.effective_power() == 2,
			"威慑：敌方回合里仍然是 -10（挺过我方回合结束）")
	det_e1.end_turn()   # 敌方 → 我方：下个自己回合开始，削弱解除
	check(det_fp.atk_debuff == 0 and det_fp.debuff_stage == 0
			and det_fp.effective_power() == 12,
			"威慑：下个自己回合开始 → 削弱解除（回到 12）")
	# 「每回合第 X 次」：X = 效果区张数 → 2 张时本回合前 2 次使用效果牌各触发一次
	var det_e3 := _new_engine([], 20, 20, -1, false)
	det_e3.start_game(1)
	det_e3.state.effects.append(repo.get_card(9057))
	det_e3.state.effects.append(repo.get_card(9057))
	det_e3.state.place(_card(9401, "重甲敌", "盟友", 5, 12, 30), Vector2i(1, 0),
			GameEngine.SIDE_OPPONENT)
	for det_i in 2:
		det_e3.state.hand = [repo.get_card(9002)]
		det_e3.state.energy = 9
		det_e3.use_effect(0)
	check(det_e3.state.unit_at(Vector2i(1, 0)).atk_debuff == 20
			and det_e3.state.unit_at(Vector2i(1, 0)).effective_power() == 0,
			"威慑：2 张 → 前 2 次使用效果牌各触发一次（12 - 20 → 0）")
	det_e3.state.hand = [repo.get_card(9002)]
	det_e3.state.energy = 9
	det_e3.use_effect(0)
	check(det_e3.state.unit_at(Vector2i(1, 0)).atk_debuff == 20,
			"威慑：2 张 → 本回合第 3 次使用不再触发（仍是 -20）")
	# 敌方场上没有单位 → 不报错、不生效
	var det_e2 := _new_engine([], 20, 20, -1, false)
	det_e2.start_game(1)
	det_e2.state.effects.append(repo.get_card(9057))
	det_e2.state.hand = [repo.get_card(9002)]
	det_e2.state.energy = 9
	det_e2.use_effect(0)
	var det_none := false
	for det_l in det_e2.log:
		if str(det_l).contains("没有单位"):
			det_none = true
	check(det_none, "威慑：敌方场上没有单位时不报错（仅记日志）")

	# 奥秘精通（9058）：1 费普通效果卡；使用效果牌后回复 1 点费用
	var nc_arcane := repo.get_card(9058)
	check(nc_arcane.card_name == "奥秘精通" and nc_arcane.is_effect()
			and nc_arcane.cost == 1 and nc_arcane.rarity == 0
			and nc_arcane.traits.has("奥秘") and nc_arcane.value == 1,
			"奥秘精通：普通 1 费效果卡，trait 奥秘 value=1")
	# 打出自身不触发（效果区当时为空 → 不回费）
	var arc_e1 := _new_engine([], 20, 20, -1, false)
	arc_e1.start_game(1)
	arc_e1.state.hand = [repo.get_card(9058)]
	arc_e1.state.energy = 5
	arc_e1.use_effect(0)
	check(arc_e1.state.energy == 4, "奥秘精通：打出自身那一下不回费（5 - 1 = 4）")
	# 已在效果区 → 再打效果牌（迅捷 2 费）：扣费后回 1
	var arc_e2 := _new_engine([], 20, 20, -1, false)
	arc_e2.start_game(1)
	arc_e2.state.effects.append(repo.get_card(9058))
	arc_e2.state.hand = [repo.get_card(9002)]
	arc_e2.state.energy = 10
	arc_e2.use_effect(0)
	check(arc_e2.state.energy == 9, "奥秘精通：使用效果牌后回 1 费（10 - 2 + 1 = 9）")
	# 多张叠加
	var arc_e3 := _new_engine([], 20, 20, -1, false)
	arc_e3.start_game(1)
	arc_e3.state.effects.append(repo.get_card(9058))
	arc_e3.state.effects.append(repo.get_card(9058))
	arc_e3.state.hand = [repo.get_card(9002)]
	arc_e3.state.energy = 10
	arc_e3.use_effect(0)
	check(arc_e3.state.energy == 10, "奥秘精通：两张叠加 → 回 2 费（10 - 2 + 2 = 10）")

	# ============================================================
	# 奥秘之泉一批（2026-09-30）：智慧喷涌 9059 / 以太屏障 9060 / 无尽加护 9061 /
	#                            使魔之夜 9062 / 道具「奥秘护符」6020
	# ============================================================

	# ---- 智慧喷涌（9059）：2 费普通效果；回合开始抽 1 张，抽到效果卡 → 那一张费用 -1 ----
	var nc_wis := repo.get_card(9059)
	check(nc_wis.card_name == "智慧喷涌" and nc_wis.is_effect() and nc_wis.cost == 2
			and nc_wis.rarity == 0 and nc_wis.traits.has("智慧") and nc_wis.value == 1,
			"智慧喷涌：普通 2 费效果卡，trait 智慧 value=1")
	var wis_e := _new_engine([], 20, 20, -1, false)
	wis_e.start_game(0)
	# 牌库排布：draw() 从末尾取 → 效果卡放在列表首位，才会被智慧喷涌抽到（其前 5 张是常规抽牌）
	wis_e.state.hand = []
	wis_e.state.deck = [repo.get_card(9002)]
	for _i in 5:
		wis_e.state.deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	wis_e.state.effects.append(repo.get_card(9059))
	wis_e._begin_turn(GameEngine.SIDE_SELF)
	check(wis_e.state.hand.size() == 6,
			"智慧喷涌：回合开始额外抽 1 张（常规 5 + 智慧 1 = %d）" % wis_e.state.hand.size())
	var wis_drawn: CardData = wis_e.state.hand[wis_e.state.hand.size() - 1]
	check(wis_drawn.id == 9002 and wis_drawn.is_effect(),
			"智慧喷涌：抽到的正是那张效果卡「迅捷」")
	check(int(wis_e.state.card_discount.get(wis_drawn, 0)) == 1,
			"智慧喷涌：抽到的效果卡被记为 -1 费")
	check(wis_e.cost_of(wis_drawn) == 1,
			"智慧喷涌：这张迅捷费用 2 → 1（实际 %d）" % wis_e.cost_of(wis_drawn))
	check(wis_e.cost_of(repo.get_card(9002)) == 2,
			"智慧喷涌：卡组里同名的其它实例仍是原价 2（instance 级减费）")
	# 抽到技能卡时没有减费
	var wis_e2 := _new_engine([], 20, 20, -1, false)
	wis_e2.start_game(0)
	wis_e2.state.hand = []
	wis_e2.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	for _j in 5:
		wis_e2.state.deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	wis_e2.state.effects.append(repo.get_card(9059))
	wis_e2._begin_turn(GameEngine.SIDE_SELF)
	var wis_d2: CardData = wis_e2.state.hand[wis_e2.state.hand.size() - 1]
	check(not wis_d2.is_effect() and wis_e2.cost_of(wis_d2) == 1,
			"智慧喷涌：抽到非效果卡 → 不减费（攻击仍 1 费）")

	# ---- 以太屏障（9060）：0 费史诗技能；本回合前 X 次伤害变为 1（X = 本回合已用效果牌数）----
	var nc_bar := repo.get_card(9060)
	check(nc_bar.card_name == "以太屏障" and nc_bar.is_spell() and nc_bar.cost == 0
			and nc_bar.rarity == 2 and nc_bar.traits.has("以太"),
			"以太屏障：史诗 0 费技能卡，trait 以太")
	var bar_e := _new_engine([], 30, 20, -1, false)
	bar_e.start_game(0)
	bar_e.state.hand = [repo.get_card(9060)]
	bar_e.state.energy = 5
	bar_e.state.self_effect_plays = 2        # 假设本回合已用过 2 张效果牌
	var bar_ret := bar_e.use_spell(0)
	check(bar_e._aether_left == 2 and bar_ret.contains("2"),
			"以太屏障：X = 本回合已用效果牌数 2（%s）" % bar_ret)
	check(bar_e.state.energy == 5, "以太屏障：0 费，能量不减")
	var bar_hp0 := bar_e.state.hp_self
	bar_e._damage_player(GameEngine.SIDE_SELF, 9, "测试")
	check(bar_e.state.hp_self == bar_hp0 - 1 and bar_e._aether_left == 1,
			"以太屏障：第一次伤害 9 → 1（HP %d，剩 %d 次）" % [
					bar_e.state.hp_self, bar_e._aether_left])
	bar_e._damage_player(GameEngine.SIDE_SELF, 9, "测试")
	check(bar_e.state.hp_self == bar_hp0 - 2 and bar_e._aether_left == 0,
			"以太屏障：第二次伤害同样变为 1")
	bar_e._damage_player(GameEngine.SIDE_SELF, 9, "测试")
	check(bar_e.state.hp_self == bar_hp0 - 11,
			"以太屏障：次数用完后恢复原伤害（第三次 -9）")
	# 一回合只有第一张生效
	bar_e.state.hand = [repo.get_card(9060)]
	bar_e.state.self_effect_plays = 3
	var bar_ret2 := bar_e.use_spell(0)
	check(bar_ret2.contains("已有一张") and bar_e._aether_left == 0,
			"以太屏障：本回合第二张无效（%s）" % bar_ret2)
	# X = 0（本回合没用过效果牌）→ 屏障不吸收
	var bar_e2 := _new_engine([], 30, 20, -1, false)
	bar_e2.start_game(0)
	bar_e2.state.hand = [repo.get_card(9060)]
	bar_e2.state.energy = 5
	bar_e2.use_spell(0)
	check(bar_e2._aether_left == 0, "以太屏障：本回合没用过效果牌 → X = 0")
	var bar_hp2 := bar_e2.state.hp_self
	bar_e2._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(bar_e2.state.hp_self == bar_hp2 - 5, "以太屏障：X = 0 时伤害照常结算")
	# 新回合 → 屏障窗口重置，可以再次生效
	bar_e2.state.hand = [repo.get_card(9060)]
	bar_e2.state.self_effect_plays = 1
	bar_e2._begin_turn(GameEngine.SIDE_SELF)
	check(not bar_e2._aether_used and bar_e2._aether_left == 0,
			"以太屏障：新回合开始 → 「本回合是否已生效」标记重置")
	bar_e2.state.self_effect_plays = 1
	bar_e2.state.hand = [repo.get_card(9060)]
	bar_e2.use_spell(0)
	check(bar_e2._aether_left == 1, "以太屏障：新回合可以再次发动（X = 1）")

	# ---- 无尽加护（9061）：2 费普通效果；回合开始随机将一张效果卡加入手卡 ----
	var nc_bless := repo.get_card(9061)
	check(nc_bless.card_name == "无尽加护" and nc_bless.is_effect() and nc_bless.cost == 2
			and nc_bless.rarity == 1 and nc_bless.rarity_name() == "稀有"
			and nc_bless.traits.has("加护"),
			"无尽加护：稀有 2 费效果卡，trait 加护")
	var bl_e := _new_engine([], 20, 20, -1, false)
	bl_e.start_game(0)
	bl_e.state.hand = []
	bl_e.state.deck = []
	bl_e.state.effects.append(repo.get_card(9061))
	bl_e._begin_turn(GameEngine.SIDE_SELF)
	check(bl_e.state.hand.size() == 1 and bl_e.state.hand[0].is_effect(),
			"无尽加护：回合开始 → 手卡多一张效果卡（%d 张）" % bl_e.state.hand.size())
	# 手牌已满时不加入（HAND_LIMIT = 10）
	var bl_e2 := _new_engine([], 20, 20, -1, false)
	bl_e2.start_game(0)
	bl_e2.state.effects.append(repo.get_card(9061))
	bl_e2.state.hand = []
	for _k in FieldState.HAND_LIMIT:
		bl_e2.state.hand.append(_card(8002, "攻击", "技能", 1, 0, 0))
	bl_e2._begin_turn(GameEngine.SIDE_SELF)
	check(bl_e2.state.hand.size() == FieldState.HAND_LIMIT,
			"无尽加护：手牌已满时不加入（仍 %d 张）" % bl_e2.state.hand.size())

	# ---- 使魔之夜（9062）：3 费稀有效果；每使用一张效果牌 → 一张乌鸦进手卡（当回合 0 费） ----
	var nc_fam := repo.get_card(9062)
	check(nc_fam.card_name == "使魔之夜" and nc_fam.is_effect() and nc_fam.cost == 3
			and nc_fam.rarity == 1 and nc_fam.traits.has("使魔之夜"),
			"使魔之夜：稀有 3 费效果卡，trait 使魔之夜")
	var fam_e := _new_engine([], 20, 20, -1, false)
	fam_e.start_game(0)
	fam_e.state.hand = [repo.get_card(9062)]
	fam_e.state.energy = 9
	fam_e.use_effect(0)
	check(fam_e.state.hand.is_empty(),
			"使魔之夜：打出自己的那一下不给乌鸦（只对之后生效）")
	fam_e.state.hand = [repo.get_card(9002)]
	fam_e.state.energy = 9
	fam_e.use_effect(0)
	var fam_crow: CardData = fam_e.state.hand[0] if not fam_e.state.hand.is_empty() else null
	check(fam_crow != null and fam_crow.id == 9039 and fam_crow.cost == 1,
			"使魔之夜：使用效果牌后 → 一张乌鸦进手卡（卡本身费用不变）")
	check(fam_e.cost_of(fam_crow) == 0 and fam_e.state.hand.size() == 1,
			"使魔之夜：这只乌鸦本回合实际费用 0")
	fam_e.end_turn()
	check(fam_e.state.turn_free.is_empty() and fam_e.cost_of(fam_crow) == 1,
			"使魔之夜：0 费只限当回合（回合结束清免费名单 → 恢复 1 费）")
	# 使用技能牌不触发
	var fam_e2 := _new_engine([], 20, 20, -1, false)
	fam_e2.start_game(0)
	fam_e2.state.effects.append(repo.get_card(9062))
	fam_e2.state.hand = [repo.get_card(8002)]
	fam_e2.state.energy = 9
	fam_e2.use_spell(0)
	check(fam_e2.state.hand.is_empty(), "使魔之夜：使用技能牌不触发")

	# ---- 道具「奥秘护符」（6020）：每回合第一张效果牌费用 -1 ----
	var charm_repo := RelicRepo.load_json()
	check(charm_repo.get_relic(6020) != null
			and charm_repo.get_relic(6020).relic_name == "奥秘护符",
			"道具「奥秘护符」6020 已登记在 relics.json")
	check(charm_repo.reward_ids().has(6020),
			"奥秘护符属于奖励道具池（可以通过一般方式获得）")
	var ch_e := _new_engine([], 20, 20, -1, false)
	ch_e.start_game(0)
	ch_e.self_relics = [6020]
	check(ch_e.cost_of(repo.get_card(9002)) == 1,
			"奥秘护符：本回合第一张效果牌费用 -1（2 → %d）" % ch_e.cost_of(repo.get_card(9002)))
	check(ch_e.cost_of(repo.get_card(8002)) == 1, "奥秘护符：技能不受影响（攻击仍 1 费）")
	ch_e.state.self_effect_plays = 1
	check(ch_e.cost_of(repo.get_card(9002)) == 2,
			"奥秘护符：本回合用过效果牌后不再减费")
	ch_e.self_relics = []
	check(ch_e.cost_of(repo.get_card(9002)) == 2, "未持有奥秘护符 → 原价 2 费")

	# ============================================================
	# 以太 / 守护一批（2026-09-30）：以太咆哮 9063 / 空间守护 9064 / 自愈 9065 /
	#                              石肤 9066 / 以太守卫 9067 / 以太恶魔 9068 / 鸭窝 9069
	# ============================================================

	# ---- 以太咆哮（9063）：1 费普通效果；每回合前 X 次使用效果/技能牌（X=效果区张数）→ 对所有敌人造成 4 伤 ----
	var nc_roar := repo.get_card(9063)
	check(nc_roar.card_name == "以太咆哮" and nc_roar.is_effect() and nc_roar.cost == 1
			and nc_roar.rarity == 0 and nc_roar.traits.has("以太咆哮") and nc_roar.value == 4,
			"以太咆哮：普通 1 费效果卡，trait 以太咆哮 value=4")
	var roar_e := _new_engine([], 20, 20, -1, false)
	roar_e.start_game(0)
	roar_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 0),
			GameEngine.SIDE_OPPONENT)
	roar_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 2),
			GameEngine.SIDE_OPPONENT)
	roar_e.state.hand = [repo.get_card(9063)]
	roar_e.state.energy = 9
	roar_e.use_effect(0)
	check(roar_e.state.unit_at(Vector2i(0, 0)).health == 8
			and roar_e.state.unit_at(Vector2i(0, 2)).health == 8,
			"以太咆哮：打出自己那一下不触发（不含此卡）")
	roar_e.state.hand = [repo.get_card(9002)]
	roar_e.state.energy = 9
	roar_e.use_effect(0)
	check(roar_e.state.unit_at(Vector2i(0, 0)).health == 4
			and roar_e.state.unit_at(Vector2i(0, 2)).health == 4,
			"以太咆哮：本回合首次使用效果牌 → 两个敌人各 8-4=4")
	roar_e.state.hand = [repo.get_card(9058)]
	roar_e.state.energy = 9
	roar_e.use_effect(0)
	check(roar_e.state.unit_at(Vector2i(0, 0)).health == 4,
			"以太咆哮：同回合第二次使用效果牌不再触发")
	roar_e.end_turn()   # 我方 → 敌方
	roar_e.end_turn()   # 敌方 → 我方（新回合，标记重置）
	roar_e.state.hand = [repo.get_card(9061)]
	roar_e.state.energy = 9
	roar_e.use_effect(0)
	check(roar_e.state.unit_at(Vector2i(0, 0)) == null,
			"以太咆哮：新回合再次触发 → 4 血的敌人被打死离场")
	var roar_e2 := _new_engine([], 20, 20, -1, false)
	roar_e2.start_game(0)
	roar_e2.state.effects.append(repo.get_card(9063))
	roar_e2.state.hand = [repo.get_card(9053)]
	roar_e2.state.energy = 9
	roar_e2.use_spell(0)
	check(roar_e2.state.hp_opponent == 16,
			"以太咆哮：使用技能牌同样触发；场上没有敌人 → 直击敌方 HP -4（20→16）")

	# ---- 空间守护（9064）：1 费普通效果；每回合前 X 次用效果/技能牌（X=张数）→ 最近敌人退后 2 格 ----
	var nc_sg := repo.get_card(9064)
	check(nc_sg.card_name == "空间守护" and nc_sg.is_effect() and nc_sg.cost == 1
			and nc_sg.rarity == 0 and nc_sg.traits.has("空间守护") and nc_sg.value == 2,
			"空间守护：普通 1 费效果卡，trait 空间守护 value=2")
	var sg_e := _new_engine([], 20, 20, -1, false)
	sg_e.start_game(0)
	sg_e.state.effects.append(repo.get_card(9064))
	sg_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	sg_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 0),
			GameEngine.SIDE_OPPONENT)
	sg_e.state.hand = [repo.get_card(9002)]
	sg_e.state.energy = 9
	sg_e.use_effect(0)
	check(sg_e.state.unit_at(Vector2i(2, 1)) == null
			and sg_e.state.unit_at(Vector2i(0, 1)) != null
			and sg_e.state.unit_at(Vector2i(0, 0)) != null,
			"空间守护：离己方 HP 最近的敌人（第 2 行）被推回 2 格到第 0 行")

	# ---- 自愈（9065）：2 费稀有效果；战斗结束后回复 8 点生命 ----
	var nc_sh := repo.get_card(9065)
	check(nc_sh.card_name == "自愈" and nc_sh.is_effect() and nc_sh.cost == 2
			and nc_sh.rarity == 1 and nc_sh.traits.has("自愈") and nc_sh.value == 8,
			"自愈：稀有 2 费效果卡，trait 自愈 value=8")
	var sh_e := _new_engine([], 20, 20, -1, false)
	sh_e.start_game(0)
	sh_e.state.hp_self = 10
	sh_e.state.effects.append(repo.get_card(9065))
	check(sh_e.battle_end_heal() == 8 and sh_e.state.hp_self == 18,
			"自愈：战斗结束后回复 8 点生命（10 → 18）")
	sh_e.state.hp_self = 18
	check(sh_e.battle_end_heal() == 2 and sh_e.state.hp_self == 20,
			"自愈：回复不超过最大生命（18 → 20，只回 2）")
	var sh_e2 := _new_engine([], 20, 20, -1, false)
	sh_e2.start_game(0)
	sh_e2.state.hp_self = 10
	check(sh_e2.battle_end_heal() == 0 and sh_e2.state.hp_self == 10,
			"自愈：效果区没有「自愈」时不回血")
	var sh_e3 := _new_engine([], 20, 20, -1, false)
	sh_e3.start_game(0)
	sh_e3.state.hp_self = 10
	sh_e3.state.effects.append(repo.get_card(9065))
	sh_e3.state.effects.append(repo.get_card(9065))
	check(sh_e3.battle_end_heal() == 8 and sh_e3.state.hp_self == 18,
			"自愈：**不叠加** —— 效果区 2 张也只按一张结算（10 → 18）")

	# ---- 石肤（9066）：3 费普通效果；己方 HP 接下来 2 次伤害变为 1（可叠加、跨回合） ----
	var nc_sk := repo.get_card(9066)
	check(nc_sk.card_name == "石肤" and nc_sk.is_effect() and nc_sk.cost == 3
			and nc_sk.rarity == 0 and nc_sk.traits.has("石肤") and nc_sk.value == 2,
			"石肤：普通 3 费效果卡，trait 石肤 value=2")
	var sk_e := _new_engine([], 20, 20, -1, false)
	sk_e.start_game(0)
	sk_e.state.hand = [repo.get_card(9066), repo.get_card(9066)]
	sk_e.state.energy = 9
	sk_e.use_effect(0)
	sk_e.use_effect(0)
	check(sk_e._stoneskin_left == 4,
			"石肤：两张叠加 → 剩余 4 次（次数可叠加）")
	check(sk_e.effect_counter(repo.get_card(9066)) == 4
			and sk_e.effect_counter(repo.get_card(9002)) == -1,
			"石肤：effect_counter 给出剩余次数（其它卡返回 -1）")
	sk_e.end_turn()
	sk_e.end_turn()
	check(sk_e._stoneskin_left == 4, "石肤：剩余次数跨回合保留")
	sk_e._damage_player(GameEngine.SIDE_SELF, 7, "测试")
	check(sk_e.state.hp_self == 19 and sk_e._stoneskin_left == 3,
			"石肤：跨回合后仍生效 → 7 点伤害变 1（20→19，剩 3 次）")
	sk_e._damage_player(GameEngine.SIDE_SELF, 7, "测试")
	sk_e._damage_player(GameEngine.SIDE_SELF, 7, "测试")
	sk_e._damage_player(GameEngine.SIDE_SELF, 7, "测试")
	check(sk_e.state.hp_self == 16 and sk_e._stoneskin_left == 0,
			"石肤：4 次全部消耗 → HP 20-4=16")
	sk_e._damage_player(GameEngine.SIDE_SELF, 7, "测试")
	check(sk_e.state.hp_self == 9, "石肤：次数用完后照常受伤（16-7=9）")

	# ---- 以太守卫（9067）：1 费稀有盟友 1/1/1/1；替我方 HP 承伤 ----
	var nc_ag := repo.get_card(9067)
	check(nc_ag.card_name == "以太守卫" and nc_ag.kind == "盟友" and nc_ag.cost == 1
			and nc_ag.rarity == 1 and nc_ag.power == 1 and nc_ag.health == 1
			and nc_ag.attack_range == 1 and nc_ag.move_speed == 1
			and nc_ag.traits.has("以太守卫"),
			"以太守卫：稀有 1 费 1/1 程1 速1，trait 以太守卫")
	var ag_e := _new_engine([], 20, 20, -1, false)
	ag_e.start_game(0)
	ag_e.state.effects.append(repo.get_card(9002))
	ag_e.state.effects.append(repo.get_card(9058))
	ag_e.state.effects.append(repo.get_card(9066))
	ag_e.state.hand = [repo.get_card(9067)]
	ag_e.state.energy = 9
	var ag_p := ag_e.play_from_hand(0, Vector2i(4, 1))
	check(ag_p.effective_power() == 4 and ag_p.health == 7,
			"以太守卫：效果区 3 张 → +3 力量 +6 生命（1/1 → 4/7）")
	var ag_e3 := _new_engine([], 20, 20, -1, false)
	ag_e3.start_game(0)
	for _i in 7:
		ag_e3.state.effects.append(repo.get_card(9066))
	ag_e3.state.hand = [repo.get_card(9067)]
	ag_e3.state.energy = 9
	var ag_p3 := ag_e3.play_from_hand(0, Vector2i(4, 1))
	check(ag_p3.effective_power() == 6 and ag_p3.health == 11,
			"以太守卫：效果区 7 张也只结算 5 次（+5 力 +10 血 → 6/11）")
	var ag_e2 := _new_engine([], 20, 20, -1, false)
	ag_e2.start_game(0)
	ag_e2.state.hand = [repo.get_card(9067)]
	ag_e2.state.energy = 9
	ag_e2.play_from_hand(0, Vector2i(4, 1))
	ag_e2._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(ag_e2.state.hp_self == 20, "以太守卫：我方 HP 的伤害由它代受（HP 仍 20）")
	check(ag_e2.state.unit_at(Vector2i(4, 1)) == null,
			"以太守卫：1 血替 HP 承受 5 点后被击破离场")

	# ---- 以太恶魔（9068）：5 费史诗盟友 5/10/1/1 ----
	var nc_dm := repo.get_card(9068)
	check(nc_dm.card_name == "以太恶魔" and nc_dm.kind == "盟友" and nc_dm.cost == 5
			and nc_dm.rarity == 2 and nc_dm.power == 5 and nc_dm.health == 10
			and nc_dm.attack_range == 1 and nc_dm.move_speed == 1
			and nc_dm.traits.has("以太恶魔"),
			"以太恶魔：史诗 5 费 5/10 程1 速1，trait 以太恶魔")
	var dm_e := _new_engine([], 20, 20, -1, false)
	dm_e.start_game(0)
	check(dm_e.cost_of(repo.get_card(9068)) == 5, "以太恶魔：效果区为空 → 原价 5 费")
	dm_e.state.effects.append(repo.get_card(9002))
	dm_e.state.effects.append(repo.get_card(9058))
	check(dm_e.cost_of(repo.get_card(9068)) == 3, "以太恶魔：效果区 2 张 → 费用 5-2=3")
	dm_e.state.deck = [repo.get_card(9062)]      # 使魔之夜：3 费效果卡
	dm_e.state.hand = [repo.get_card(9068)]
	dm_e.state.energy = 9
	dm_e.play_from_hand(0, Vector2i(4, 1))
	check(dm_e.state.deck.is_empty() and dm_e.state.hand.size() == 1
			and dm_e.state.hand[0].id == 9062,
			"以太恶魔：上场时从卡组将一张效果卡加入手卡")
	check(dm_e.cost_of(dm_e.state.hand[0]) == 1,
			"以太恶魔：取到的那张效果卡费用 -2（3 → 1）")

	# ---- 鸭窝（9069）：2 费稀有效果；给鸭蛋；每回合前 X 次用效果牌（X=张数）再给一张 ----
	var nc_dn := repo.get_card(9069)
	check(nc_dn.card_name == "鸭窝" and nc_dn.is_effect() and nc_dn.cost == 2
			and nc_dn.rarity == 1 and nc_dn.traits.has("鸭窝"),
			"鸭窝：稀有 2 费效果卡，trait 鸭窝")
	var dn_e := _new_engine([], 20, 20, -1, false)
	dn_e.start_game(0)
	dn_e.state.hand = [repo.get_card(9069)]
	dn_e.state.energy = 9
	dn_e.use_effect(0)
	check(dn_e.state.hand.size() == 1 and dn_e.state.hand[0].id == 9022
			and dn_e.state.hand[0].traits.has("离场消失"),
			"鸭窝：使用后立刻将一张鸭蛋加入手卡")
	dn_e.end_turn()
	dn_e.end_turn()
	dn_e.state.hand = [repo.get_card(9002)]
	dn_e.state.energy = 9
	dn_e.use_effect(0)
	check(dn_e.state.hand.size() == 1 and dn_e.state.hand[0].id == 9022,
			"鸭窝：本回合首次使用效果卡 → 再给一张鸭蛋")
	dn_e.state.hand = [repo.get_card(9058), dn_e.state.hand[0]]
	dn_e.state.energy = 9
	dn_e.use_effect(0)
	check(dn_e.state.hand.size() == 1 and dn_e.state.hand[0].id == 9022,
			"鸭窝：同回合第二次使用效果卡不再给")

	# ---- 「每回合第 X 次」：X = 效果区张数 → 2 张时本回合前 2 次使用都会触发 ----
	# 镜像（9056）**不在**这组：它「不可叠加」，效果区 2 张也只在本回合第一次触发、只加 1 份
	# （用例见上方「镜像」段落：mir_e4 效果区 2 张 → 只加 1 份，同回合第 2 次不触发）。
	# 鸭窝（9069）：2 张 → 前 2 次使用各给一张鸭蛋
	var nest2 := _new_engine([], 20, 20, -1, false)
	nest2.start_game(0)
	nest2.state.effects.append(repo.get_card(9069))
	nest2.state.effects.append(repo.get_card(9069))
	nest2.state.hand = [repo.get_card(9002)]
	nest2.state.energy = 9
	nest2.use_effect(0)
	check(nest2.state.hand.size() == 1 and nest2.state.hand[0].id == 9022,
			"鸭窝：2 张 → 第 1 次使用就触发（手卡 +1 鸭蛋）")
	nest2.state.hand.append(repo.get_card(9002))
	nest2.state.energy = 9
	nest2.use_effect(nest2.state.hand.size() - 1)
	check(nest2.state.hand.size() == 2,
			"鸭窝：2 张 → 第 2 次使用再触发一次（手上 2 张鸭蛋）")
	nest2.state.hand.append(repo.get_card(9002))
	nest2.state.energy = 9
	nest2.use_effect(nest2.state.hand.size() - 1)
	check(nest2.state.hand.size() == 2,
			"鸭窝：2 张 → 第 3 次使用不再触发（仍 2 张鸭蛋）")
	# 以太咆哮（9063）：2 张 → 前 2 次使用效果/技能牌各轰一次
	var roar2 := _new_engine([], 20, 20, -1, false)
	roar2.start_game(0)
	roar2.state.effects.append(repo.get_card(9063))
	roar2.state.effects.append(repo.get_card(9063))
	roar2.state.place(_card(8003, "农民", "盟友", 3, 3, 20), Vector2i(0, 0),
			GameEngine.SIDE_OPPONENT)
	roar2.state.hand = [repo.get_card(9002)]
	roar2.state.energy = 9
	roar2.use_effect(0)
	check(roar2.state.unit_at(Vector2i(0, 0)).health == 16,
			"以太咆哮：2 张 → 第 1 次使用就触发（20 - 4 = 16）")
	roar2.state.hand = [repo.get_card(9002)]
	roar2.state.energy = 9
	roar2.use_effect(0)
	check(roar2.state.unit_at(Vector2i(0, 0)).health == 12,
			"以太咆哮：2 张 → 第 2 次使用再触发（16 - 4 = 12）")
	roar2.state.hand = [repo.get_card(9002)]
	roar2.state.energy = 9
	roar2.use_effect(0)
	check(roar2.state.unit_at(Vector2i(0, 0)).health == 12,
			"以太咆哮：2 张 → 第 3 次使用不再触发（仍 12）")

	# ---- 鸭蛋（9022）：离场时消失（不进弃牌区） ----
	var ev_e := _new_engine([], 20, 20, -1, false)
	ev_e.start_game(0)
	ev_e.state.hand = [CardData.from_dict(repo.get_card(9022).to_dict()),
			repo.get_card(9002)]
	ev_e.state.discard_hand()
	check(ev_e.state.discard.size() == 1
			and not ev_e.state.discard.any(func(c: CardData): return c.id == 9022),
			"鸭蛋：离场即消失，不进弃牌区（不会被洗回卡组）")

	# ---- 道具「鸡煲」（6003）改版：去掉每场一次 —— 第一回合结束 或 用过效果卡的回合结束 ----
	var cp_e := _new_engine([], 20, 20, -1, false)
	cp_e.start_game(0)
	cp_e.self_relics = [6003]
	cp_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 0),
			GameEngine.SIDE_OPPONENT)
	cp_e.end_turn()
	check(cp_e.state.unit_at(Vector2i(0, 0)) != null
			and cp_e.state.unit_at(Vector2i(0, 0)).health == 5,
			"鸡煲：第 1 回合结束 → 随机敌人 8-3=5")
	var cp_e2 := _new_engine([], 20, 20, -1, false)
	cp_e2.start_game(0)
	cp_e2.self_relics = [6003]
	cp_e2.turn_number = 3
	cp_e2.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 0),
			GameEngine.SIDE_OPPONENT)
	cp_e2.end_turn()   # 第 3 回合、没用过效果卡 → 不触发
	check(cp_e2.state.unit_at(Vector2i(0, 0)) != null
			and cp_e2.state.unit_at(Vector2i(0, 0)).health == 8,
			"鸡煲：不是第一回合、也没用效果卡 → 不触发")
	cp_e2.end_turn()
	cp_e2.state.self_effect_plays = 1
	cp_e2.end_turn()   # 本回合用过效果卡 → 触发
	check(cp_e2.state.unit_at(Vector2i(0, 0)) != null
			and cp_e2.state.unit_at(Vector2i(0, 0)).health == 5,
			"鸡煲：使用过效果卡的回合结束 → 触发（8-3=5）")
	cp_e2.end_turn()
	cp_e2.state.self_effect_plays = 1
	cp_e2.end_turn()   # 已去掉「整场一次」→ 每个满足条件的回合结束都触发
	check(cp_e2.state.unit_at(Vector2i(0, 0)) != null
			and cp_e2.state.unit_at(Vector2i(0, 0)).health == 2,
			"鸡煲：去掉每场一次 → 再次满足条件的回合结束再次触发（5-3=2）")

	# ============================================================
	# 群起攻之 / 在启动了一批（2026-09-30）：群起攻之 9070 / 在启动了 9071 /
	#                                      铁栅栏 9072 / 猫头鹰 9073 / 小精灵 9074
	# ============================================================

	# ---- 群起攻之（9070）：2 费稀有效果；己方盟友算攻击距离时友方格不计入 ----
	var nc_rally := repo.get_card(9070)
	check(nc_rally.card_name == "群起攻之" and nc_rally.is_effect() and nc_rally.cost == 2
			and nc_rally.rarity == 1 and nc_rally.traits.has("群起攻之"),
			"群起攻之：稀有 2 费效果卡，trait 群起攻之")
	var rl_e := _new_engine([], 20, 20, -1, false)
	rl_e.start_game(0)
	var rl_ally := _card(8003, "农民", "盟友", 3, 3, 8, 1, 1)
	rl_e.state.place(rl_ally, Vector2i(5, 1), GameEngine.SIDE_SELF)
	rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	check(not rl_e.attack_targets(Vector2i(5, 1), GameEngine.SIDE_SELF,
			rl_e.state.unit_at(Vector2i(5, 1)).card).has(Vector2i(2, 1)),
			"群起攻之：没这张效果卡时，第 5 行打不到第 2 行的敌人（曼哈顿距离 3）")
	rl_e.state.effects.append(repo.get_card(9070))	# 效果区放入群起攻之
	check(not rl_e.attack_targets(Vector2i(5, 1), GameEngine.SIDE_SELF,
			rl_e.state.unit_at(Vector2i(5, 1)).card).has(Vector2i(2, 1)),
			"群起攻之：中间没有友方能借力时仍然打不到（顺着同列走全是空格）")
	rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	rl_e.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 1),
			GameEngine.SIDE_SELF)
	check(rl_e.attack_targets(Vector2i(5, 1), GameEngine.SIDE_SELF,
			rl_e.state.unit_at(Vector2i(5, 1)).card).has(Vector2i(2, 1)),
			"群起攻之：第 4、3 行站着友方单位 → 这两格不计数 → 距离 1 打得到第 2 行")
	check(rl_e.attack_distance(Vector2i(5, 1), Vector2i(2, 1), GameEngine.SIDE_SELF,
			rl_e.state.unit_at(Vector2i(5, 1)).card) == 1,
			"群起攻之：借力后的攻击距离 = 1")
	var rl_fort := _card(8001, "箭塔", "工事", 2, 3, 10, 1, 0)
	check(rl_e.attack_distance(Vector2i(5, 1), Vector2i(2, 1), GameEngine.SIDE_SELF,
			rl_fort) == 3,
			"群起攻之：只帮「盟友」，工事仍按曼哈顿距离算")
	check(rl_e.attack_distance(Vector2i(2, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT,
			rl_e.state.unit_at(Vector2i(2, 1)).card) == 3,
			"群起攻之：敌方效果区没有这张卡 → 敌人不受影响")

	# ---- 在启动了（9071）：3 费普通技能；召唤铁栅栏 0/12，替我方 HP 承伤 ----
	var nc_lock := repo.get_card(9071)
	check(nc_lock.card_name == "在启动了" and nc_lock.is_spell() and nc_lock.cost == 3
			and nc_lock.rarity == 0 and nc_lock.target_mode == "cell",
			"在启动了：普通 3 费技能卡，需要选一格（target_mode=cell）")
	var nc_fence := repo.get_card(9072)
	check(nc_fence.card_name == "铁栅栏" and nc_fence.kind == "工事"
			and nc_fence.power == 0 and nc_fence.health == 12
			and nc_fence.attack_range == 0 and nc_fence.move_speed == 0
			and nc_fence.rarity == 5 and nc_fence.traits.has("铁栅栏"),
			"铁栅栏 9072：0 攻 12 血的工事 token（rarity 5 → 不进奖励池）")
	var fence_pool := repo.reward_pool()
	var fence_in_pool := false
	for _fc: CardData in fence_pool:
		if _fc.id == 9072:
			fence_in_pool = true
			fence_in_pool = true
	check(not fence_in_pool, "铁栅栏：奖励池里拿不到（token）")
	var if_e := _new_engine([], 20, 20, -1, false)
	if_e.start_game(0)
	check(if_e.cost_of(repo.get_card(9071)) == 3, "在启动了：还没用过效果卡 → 原价 3 费")
	if_e.state.self_effect_plays = 2
	check(if_e.cost_of(repo.get_card(9071)) == 1,
			"在启动了：本回合用过 2 张效果卡 → 费用 3-2=1")
	if_e.state.self_effect_plays = 5
	check(if_e.cost_of(repo.get_card(9071)) == 0, "在启动了：减到 0 就到底了")
	var if_e2 := _new_engine([], 20, 20, -1, false)
	if_e2.start_game(0)
	if_e2.state.hand = [repo.get_card(9071)]
	if_e2.state.energy = 9
	if_e2.use_spell(0, Vector2i(4, 1))
	var fn_p := if_e2.state.unit_at(Vector2i(4, 1))
	check(fn_p != null and fn_p.card.id == 9072 and fn_p.health == 12
			and fn_p.owner == GameEngine.SIDE_SELF,
			"在启动了：在自己半场选定格召唤出一个 12 血的铁栅栏")
	if_e2._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(if_e2.state.hp_self == 20 and if_e2.state.unit_at(Vector2i(4, 1)) != null
			and if_e2.state.unit_at(Vector2i(4, 1)).health == 7,
			"在启动了：铁栅栏替我方 HP 承受伤害（HP 20 不变，栅栏 12→7）")
	var if_e3 := _new_engine([], 20, 20, -1, false)
	if_e3.start_game(0)
	if_e3.state.hand = [repo.get_card(9071), repo.get_card(9071), repo.get_card(9071)]
	if_e3.state.energy = 9
	check(if_e3.use_spell(0, Vector2i(0, 0)).begins_with("（只能在自己半场"),
			"在启动了：指定敌方半场会被拒绝")
	if_e3.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 0),
			GameEngine.SIDE_SELF)
	check(if_e3.use_spell(0, Vector2i(3, 0)).begins_with("（那一格已经有单位"),
			"在启动了：指定已占用的格子会被拒绝")
	var fences := 0
	for _c: Vector2i in if_e3.state.board:
		if if_e3.state.board[_c].card.id == 9072:
			fences += 1
	check(fences == 0, "在启动了：被拒的请求没有生成铁栅栏")

	# ---- 统一「替 HP 承伤」判定（2026-10-01）：森林守护 / 以太守卫 / 铁栅栏同一机制，同一特效 ----
	var gv_e := _new_engine([], 20, 20, -1, false)
	var gv_plain := gv_e.state.place(_card(9201, "测试农民", "盟友", 3, 3, 8),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	var gv_forest := gv_e.state.place(_card(9202, "测试护林人", "盟友", 3, 3, 8),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	gv_forest.guarding = true
	var gv_fence := gv_e.state.place(CardData.from_dict(repo.get_card(9072).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	var gv_aether := gv_e.state.place(CardData.from_dict(repo.get_card(9067).to_dict()),
			Vector2i(5, 0), GameEngine.SIDE_SELF)
	check(not gv_e.absorbs_for_hp(gv_plain),
			"承伤判定：普通盟友不承伤（战场不画绿环）")
	check(gv_e.absorbs_for_hp(gv_forest),
			"承伤判定：森林守护盟友 → 承伤（绿环）")
	check(gv_e.absorbs_for_hp(gv_fence),
			"承伤判定：铁栅栏 → 承伤（与森林守护同一绿环特效）")
	check(gv_e.absorbs_for_hp(gv_aether),
			"承伤判定：以太守卫 → 承伤（同一绿环特效）")
	check(gv_e._guard_cell(GameEngine.SIDE_SELF) != Vector2i(-1, -1),
			"承伤判定：_guard_cell 走同一函数（特效与结算同源，不会两处漂移）")

	# ---- 猫头鹰（9073）：1 费普通盟友 1/1/1/1；使用时从卡组取一张随机效果卡 ----
	var nc_owl := repo.get_card(9073)
	check(nc_owl.card_name == "猫头鹰" and nc_owl.kind == "盟友" and nc_owl.cost == 1
			and nc_owl.rarity == 0 and nc_owl.power == 1 and nc_owl.health == 1
			and nc_owl.attack_range == 1 and nc_owl.move_speed == 1,
			"猫头鹰：普通 1 费 1/1/1/1 盟友")
	var ow_e := _new_engine([], 20, 20, -1, false)
	ow_e.start_game(0)
	ow_e.state.deck = [CardData.from_dict(repo.get_card(9002).to_dict()),
			CardData.from_dict(repo.get_card(9016).to_dict())]
	ow_e.state.hand = [repo.get_card(9073)]
	ow_e.state.energy = 9
	ow_e.play_from_hand(0, Vector2i(4, 1))
	check(ow_e.state.hand.size() == 1 and ow_e.state.hand[0].id == 9002
			and ow_e.state.deck.size() == 1,
			"猫头鹰：使用时从卡组把那张效果卡加入手卡（卡组少一张）")
	var ow_e2 := _new_engine([], 20, 20, -1, false)
	ow_e2.start_game(0)
	ow_e2.state.deck = [CardData.from_dict(repo.get_card(9016).to_dict())]
	ow_e2.state.hand = [repo.get_card(9073)]
	ow_e2.state.energy = 9
	ow_e2.play_from_hand(0, Vector2i(4, 1))
	check(ow_e2.state.hand.is_empty() and ow_e2.state.deck.size() == 1,
			"猫头鹰：卡组里没有效果卡时不给")

	# ---- 小精灵（9074）：1 费稀有盟友 1/1/1/1；下一张效果卡费用 -2 ----
	var nc_spr := repo.get_card(9074)
	check(nc_spr.card_name == "小精灵" and nc_spr.kind == "盟友" and nc_spr.cost == 1
			and nc_spr.rarity == 1 and nc_spr.power == 1 and nc_spr.health == 1
			and nc_spr.attack_range == 1 and nc_spr.move_speed == 1,
			"小精灵：稀有 1 费 1/1/1/1 盟友")
	var sp_e := _new_engine([], 20, 20, -1, false)
	sp_e.start_game(0)
	sp_e.state.hand = [repo.get_card(9074)]
	sp_e.state.energy = 9
	sp_e.play_from_hand(0, Vector2i(4, 1))
	check(sp_e.state.self_next_effect_reduction == 2, "小精灵：上场后挂上 -2 的效果卡减费")
	check(sp_e.cost_of(repo.get_card(9002)) == 0,
			"小精灵：下一张效果卡费用 -2（迅捷 2 → 0）")
	check(sp_e.cost_of(repo.get_card(9016)) == 4, "小精灵：盟友不吃这个减费（骑兵仍 4 费）")
	sp_e.state.hand = [repo.get_card(9002)]
	sp_e.state.energy = 9
	sp_e.use_effect(0)
	check(sp_e.state.self_next_effect_reduction == 0,
			"小精灵：用掉那张效果卡减免即清零")
	check(sp_e.cost_of(repo.get_card(9066)) == 3,
			"小精灵：之后再用的效果卡恢复原价（石肤 3 费）")
	var sp_e2 := _new_engine([], 20, 20, -1, false)
	sp_e2.start_game(0)
	sp_e2.state.hand = [repo.get_card(9074)]
	sp_e2.state.energy = 9
	sp_e2.play_from_hand(0, Vector2i(4, 1))
	sp_e2.end_turn()
	sp_e2.end_turn()
	check(sp_e2.state.self_next_effect_reduction == 2,
			"小精灵：没用掉的减费跨回合保留（2026-10-01 起）")
	check(sp_e2.cost_of(repo.get_card(9002)) == 0,
			"小精灵：跨过回合后第一张效果卡仍然 -2（迅捷 2 → 0）")
	sp_e2.state.hand = [repo.get_card(9002)]
	sp_e2.state.energy = 9
	sp_e2.use_effect(0)
	check(sp_e2.state.self_next_effect_reduction == 0,
			"小精灵：跨回合后终于用掉 → 减免清零")

	# ============================================================
	# 成长性一批（2026-10-01）：鸭子骑士击杀成长 + 二层关卡「低开高走」
	# ============================================================

	# ---- 鸭子骑士（9001）：3 攻起步，每击杀一个敌人 +2 攻击力 ----
	var kk_e := _new_engine([], 20, 20, -1, false)
	kk_e.start_game(0)
	var kk_knight := kk_e.state.place(repo.get_card(9001), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	check(kk_knight.effective_power() == 3, "鸭子骑士：开局 3 攻")
	kk_e.state.place(_card(8003, "农民", "盟友", 3, 3, 1, 1, 1), Vector2i(3, 1),
			GameEngine.SIDE_SELF)
	kk_e.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(kk_e.state.unit_at(Vector2i(3, 1)) == null, "鸭子骑士：击杀了那个 1 血的农民")
	check(kk_knight.atk_buff == 2 and kk_knight.effective_power() == 5,
			"鸭子骑士：击杀后攻击力 +2（3 → 5）")
	kk_e.state.place(_card(8003, "农民", "盟友", 3, 3, 1, 1, 1), Vector2i(3, 1),
			GameEngine.SIDE_SELF)
	kk_knight.tapped = false
	kk_e.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(kk_knight.atk_buff == 4 and kk_knight.effective_power() == 7,
			"鸭子骑士：再击杀一个 → 累计 +4（3 → 7，无上限）")
	# 不是骑士的单位击杀不成长
	var kk_e2 := _new_engine([], 20, 20, -1, false)
	kk_e2.start_game(0)
	var kk_plain := kk_e2.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	kk_e2.state.place(_card(8003, "农民", "盟友", 3, 3, 1, 1, 1), Vector2i(3, 1),
			GameEngine.SIDE_SELF)
	kk_e2.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(kk_plain.atk_buff == 0, "鸭子骑士：没有骑士词条的普通单位击杀不成长")

	# ---- 二层关卡成长曲线（低开高走：开局削攻击力，每 2 回合 +1，最多 +4）----
	var gl_frost := _level_named("寒冰防线")
	check(gl_frost.has("enemy_growth")
			and int((gl_frost["enemy_growth"] as Dictionary).get("cap", 0)) == 4,
			"二层关卡带 enemy_growth 成长配置（cap=4）")
	var gl_boss := _level_named("机械巨鸭")
	check(not gl_boss.has("enemy_growth"),
			"二层 Boss（机械巨鸭）自带齿轮升腾，不叠加关卡成长")
	var gl_l1 := _level_named("鸭子骑士来袭")
	check(not gl_l1.has("enemy_growth"), "一层关卡不带成长曲线")
	var gl_e := _new_engine([], 20, 20, -1, false)
	gl_e.start_game(0)
	gl_e.state.place(repo.get_card(1011), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)   # 铁壁卫兵 4 攻
	gl_e.state.place(repo.get_card(1071), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)   # 熔岩巨人 12 攻
	gl_e.configure_growth(GameLevels.LAYER2_GROWTH)
	check(gl_e.state.unit_at(Vector2i(2, 1)).effective_power() == 3,
			"成长曲线：杂兵（4 攻）开局 -1 → 3")
	check(gl_e.state.unit_at(Vector2i(1, 1)).effective_power() == 9,
			"成长曲线：强力怪（12 攻）开局 -3 → 9")
	gl_e.turn_number = 2
	gl_e._tick_enemy_growth()
	check(gl_e._growth_stacks == 1
			and gl_e.state.unit_at(Vector2i(2, 1)).effective_power() == 4,
			"成长曲线：第 2 回合 +1 → 杂兵 4 攻")
	gl_e.turn_number = 4
	gl_e._tick_enemy_growth()
	check(gl_e._growth_stacks == 2
			and gl_e.state.unit_at(Vector2i(2, 1)).effective_power() == 5,
			"成长曲线：第 4 回合 +2 → 杂兵 5 攻")
	gl_e.turn_number = 8
	gl_e._tick_enemy_growth()
	check(gl_e._growth_stacks == 4
			and gl_e.state.unit_at(Vector2i(1, 1)).effective_power() == 13,
			"成长曲线：第 8 回合累计 +4 封顶 → 强力怪 9+4=13")
	gl_e.turn_number = 20
	gl_e._tick_enemy_growth()
	check(gl_e._growth_stacks == 4, "成长曲线：封顶后不再增长")
	# 后上场的单位（亡语召唤物）也吃到当前层数
	gl_e.state.place(repo.get_card(1011), Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	gl_e._sync_enemy_growth()
	check(gl_e.state.unit_at(Vector2i(2, 0)).effective_power() == 7,
			"成长曲线：新上场的单位也吃到当前层数（3+4=7）")
	# 我方单位不受关卡成长影响
	var gl_e2 := _new_engine([], 20, 20, -1, false)
	gl_e2.start_game(0)
	var gl_mine := gl_e2.state.place(repo.get_card(1011), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	gl_e2.configure_growth(GameLevels.LAYER2_GROWTH)
	check(gl_mine.atk_growth == 0 and gl_mine.effective_power() == 4,
			"成长曲线：只削敌方，我方单位攻击力不变")

	# 斑鸠（9052）：1 费 1/1/1/1；本回合使用下一个盟友费用 -1（用掉即清零）
	var nc_dove := repo.get_card(9052)
	check(nc_dove.card_name == "斑鸠" and nc_dove.kind == "盟友" and nc_dove.cost == 1
			and nc_dove.power == 1 and nc_dove.health == 1 and nc_dove.attack_range == 1
			and nc_dove.move_speed == 1 and nc_dove.rarity == 0,
			"斑鸠：普通 1 费 1/1 程1 速1")
	var eng_dove := _new_engine([], 20, 20, -1, false)
	eng_dove.start_game(1)
	eng_dove.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	eng_dove.state.hand = [repo.get_card(9052), repo.get_card(8003), repo.get_card(8002)]
	eng_dove.state.energy = 5
	check(eng_dove.cost_of(repo.get_card(8003)) == 3 and eng_dove.cost_of(repo.get_card(8002)) == 1,
			"斑鸠：未上场时农民/攻击都是原价（3 / 1）")
	eng_dove.play_from_hand(0, Vector2i(4, 0))   # 打斑鸠（自身 1 费，不吃减免）
	check(eng_dove.state.energy == 4, "斑鸠：自身按原价 1 费上场（5 → %d）" % eng_dove.state.energy)
	check(eng_dove.state.self_next_ally_reduction == 1,
			"斑鸠：上场后本回合下一个盟友费用 -1")
	check(eng_dove.cost_of(repo.get_card(8003)) == 2,
			"斑鸠：农民实际费用 3 → 2（走 cost_of，手牌会显示绿色）")
	check(eng_dove.cost_of(repo.get_card(8002)) == 1,
			"斑鸠：技能不受影响（攻击仍 1 费）")
	var dove_before := eng_dove.state.energy
	# 打完斑鸠后手牌变成 [农民, 攻击] → 下标 0 才是农民
	check(eng_dove.state.hand[0].id == 8003, "斑鸠：打完斑鸠后手牌首位是农民")
	eng_dove.play_from_hand(0, Vector2i(4, 1))   # 打农民 → 实扣 2 费
	check(dove_before - eng_dove.state.energy == 2,
			"斑鸠：农民实扣 2 费（%d → %d）" % [dove_before, eng_dove.state.energy])
	check(eng_dove.state.self_next_ally_reduction == 0,
			"斑鸠：减免用掉即清零（后续盟友恢复原价）")
	eng_dove._begin_turn(GameEngine.SIDE_SELF)
	check(eng_dove.state.self_next_ally_reduction == 0, "斑鸠：回合开始清空减免")

	# 新卡数值：骑兵 / 鸭子弓手 / 金属龙
	var nc_rider := repo.get_card(9016)
	check(nc_rider.card_name == "骑兵" and nc_rider.cost == 4 and nc_rider.power == 6
			and nc_rider.health == 12 and nc_rider.attack_range == 1
			and nc_rider.move_speed == 2 and nc_rider.rarity == 0,
			"骑兵：普通 4 费 6/12 程1 速2")
	var nc_archer := repo.get_card(9017)
	check(nc_archer.card_name == "鸭子弓手" and nc_archer.power == 3
			and nc_archer.health == 18 and nc_archer.attack_range == 2
			and nc_archer.move_speed == 1 and nc_archer.rarity == 4,
			"鸭子弓手：怪物 3/18 程2 速1")
	var nc_metal := repo.get_card(9018)
	check(nc_metal.card_name == "金属龙" and nc_metal.cost == 5 and nc_metal.power == 6
			and nc_metal.health == 21 and nc_metal.attack_range == 1
			and nc_metal.move_speed == 1 and nc_metal.rarity == 5
			and nc_metal.rarity_name() == "事件",
			"金属龙：事件卡 5 费 6/21 程1 速1（不可奖励获取）")
	var nc_tower := repo.get_card(9019)
	check(nc_tower.card_name == "箭塔" and nc_tower.kind == "工事"
			and nc_tower.cost == 3 and nc_tower.power == 5 and nc_tower.health == 10
			and nc_tower.attack_range == 2 and nc_tower.move_speed == 0
			and nc_tower.rarity == 0 and nc_tower.is_fort(),
			"箭塔：普通 3 费 工事 5/10 程2 不能移动")
	# 关卡：鸭子骑士来袭 + 巫师的召唤 + 鸭子队长登场（分级排序）
	check(GameLevels.TIER_NAMES.size() == 5
			and GameLevels.tier_name(0) == "普通敌人-简单"
			and GameLevels.tier_name(1) == "普通敌人-困难"
			and GameLevels.tier_name(2) == "精英敌人-简单"
			and GameLevels.tier_name(3) == "精英敌人-困难"
			and GameLevels.tier_name(4) == "Boss",
			"关卡分级：普通简单/普通困难/精英简单/精英困难/Boss")
	var lvl: Dictionary = GameLevels.builtin_levels()[0]
	check(str(lvl["name"]) == "鸭子骑士来袭"
			and int(lvl["tier"]) == GameLevels.TIER_NORMAL_EASY,
			"鸭子骑士来袭 = 普通敌人-简单")
	check((lvl["enemy_units"] as Array).size() == 2
			and int(lvl["enemy_units"][0][0]) == 9001
			and lvl["enemy_units"][0][6] == Vector2i(1, 0)
			and lvl["enemy_units"][1][6] == Vector2i(1, 2),
			"第一关：敌方中排左右各一只鸭子骑士（2026-10-01 由前排挪到中排）")
	var lvl2: Dictionary = _level_named("巫师的召唤")
	check(str(lvl2["name"]) == "巫师的召唤"
			and int(lvl2["tier"]) == GameLevels.TIER_NORMAL_HARD
			and (lvl2["enemy_units"] as Array).size() == 2
			and int(lvl2["enemy_units"][0][0]) == 9008
			and lvl2["enemy_units"][0][6] == Vector2i(1, 1)
			and int(lvl2["enemy_units"][1][0]) == 9009
			and lvl2["enemy_units"][1][6] == Vector2i(2, 1),
			"第二关：后排中间巫师 + 前排中间使魔")
	# 新关卡：弓手与骑士 —— 后排左右鸭子弓手 + 后排中间鸭子骑士
	var lvl_ak: Dictionary = _level_named("弓手与骑士")
	var eus_ak: Array = lvl_ak.get("enemy_units", [])
	check(str(lvl_ak.get("name", "")) == "弓手与骑士"
			and int(lvl_ak.get("tier", -1)) == GameLevels.TIER_NORMAL_EASY
			and eus_ak.size() == 3
			and int(eus_ak[0][0]) == 9017 and eus_ak[0][6] == Vector2i(0, 0)
			and int(eus_ak[1][0]) == 9001 and eus_ak[1][6] == Vector2i(0, 1)
			and int(eus_ak[2][0]) == 9017 and eus_ak[2][6] == Vector2i(0, 2),
			"弓手与骑士：后排左右弓手 + 中间骑士")
	check((lvl_ak.get("enemy_units", [])[0][2] as int) == 3
			and (lvl_ak.get("enemy_units", [])[0][3] as int) == 18
			and (lvl_ak.get("enemy_units", [])[1][2] as int) == 3
			and (lvl_ak.get("enemy_units", [])[1][3] as int) == 30,
			"弓手与骑士：弓手 3/18、骑士 3/30")

	# 新关卡：夜鸭阵 —— 第二层·普通敌人-简单，中排两只夜鸭 + 前排两只使魔鸭子
	var lvl_nd: Dictionary = _level_named("夜鸭阵")
	var eus_nd: Array = lvl_nd.get("enemy_units", [])
	check(str(lvl_nd.get("name", "")) == "夜鸭阵"
			and int(lvl_nd.get("tier", -1)) == GameLevels.TIER_NORMAL_EASY
			and int(lvl_nd.get("layer", -1)) == GameLayers.LAYER_TWO
			and eus_nd.size() == 4
			and int(eus_nd[0][0]) == 9027 and eus_nd[0][6] == Vector2i(1, 0)
			and int(eus_nd[1][0]) == 9027 and eus_nd[1][6] == Vector2i(1, 2)
			and int(eus_nd[2][0]) == 9009 and eus_nd[2][6] == Vector2i(2, 0)
			and int(eus_nd[3][0]) == 9009 and eus_nd[3][6] == Vector2i(2, 2),
			"夜鸭阵：第二层普通简单，中排2夜鸭(1,0)/(1,2) + 前排2使魔(2,0)/(2,2)")
	check((eus_nd[0][2] as int) == 6 and (eus_nd[0][3] as int) == 35
			and (eus_nd[0][4] as int) == 2 and (eus_nd[0][5] as int) == 2,
			"夜鸭：6 攻 35 血 程2 速2")
	var nd_card := repo.get_card(9027)
	check(nd_card.power == 6 and nd_card.health == 35 and nd_card.value == 1
			and nd_card.traits.has("夜行") and nd_card.effect_text.contains("回合开始时"),
			"夜鸭：6 攻 35 血，trait 夜行（回合开始 +1 攻）")
	# 夜行（9027）：所属方回合开始时力量 +1（永久累计）
	var ng_e := _new_engine([], 20, 20, -1, false)
	ng_e.start_game(0)
	var ng_duck := CardData.from_dict(repo.get_card(9027).to_dict())
	ng_e.state.place(ng_duck, Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	check(ng_e.state.unit_at(Vector2i(1, 0)).effective_power() == 6, "夜行：上场 6 攻")
	ng_e.end_turn()   # 我方 → 敌方（敌方回合开始 → 夜行 +1）
	check(ng_e.state.unit_at(Vector2i(1, 0)).effective_power() == 7,
			"夜行：敌方回合开始 +1 攻（6 → 7）")
	ng_e.end_turn()   # 敌方 → 我方
	ng_e.end_turn()   # 我方 → 敌方（再 +1）
	check(ng_e.state.unit_at(Vector2i(1, 0)).effective_power() == 8,
			"夜行：每个自己的回合开始都 +1（7 → 8）")

	# 精进（9021 白魔法师）：每个自己的回合开始力量 +1（永久累计，无前置条件）
	var sl_e := _new_engine([], 20, 20, -1, false)
	sl_e.start_game(0)
	sl_e.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(sl_e.state.unit_at(Vector2i(4, 1)).effective_power() == 2, "精进：上场 2 攻")
	sl_e.end_turn()   # 我方 → 敌方
	sl_e.end_turn()   # 敌方 → 我方（我方回合开始 → 精进 +1）
	check(sl_e.state.unit_at(Vector2i(4, 1)).effective_power() == 3,
			"精进：回合开始 +1 攻（2 → 3）")
	sl_e.end_turn()
	sl_e.end_turn()
	check(sl_e.state.unit_at(Vector2i(4, 1)).effective_power() == 4,
			"精进：每个自己的回合开始都 +1（3 → 4）")
	# 已去掉前置条件：己方半场另有单位也照常成长
	var sl2 := _new_engine([], 20, 20, -1, false)
	sl2.start_game(0)
	sl2.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	sl2.state.place(repo.get_card(8003), Vector2i(5, 1), GameEngine.SIDE_SELF)
	sl2.end_turn()
	sl2.end_turn()
	check(sl2.state.unit_at(Vector2i(4, 1)).effective_power() == 3,
			"精进：己方半场另有单位也 +1（不再要求「只剩它自己」，2 → 3）")
	# 两只白魔法师同时在场 → 各自都成长
	var sl3 := _new_engine([], 20, 20, -1, false)
	sl3.start_game(0)
	sl3.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	sl3.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(5, 0), GameEngine.SIDE_SELF)
	sl3._mage_growth(GameEngine.SIDE_SELF)
	check(sl3.state.unit_at(Vector2i(4, 0)).effective_power() == 3
			and sl3.state.unit_at(Vector2i(5, 0)).effective_power() == 3,
			"精进：两只白魔法师同时在场 → 各自都 +1（2 → 3）")
	# 敌方侧同样生效（关卡「白魔法师护阵」里它是敌方卡）
	var sl4 := _new_engine([], 20, 20, -1, false)
	sl4.start_game(0)
	sl4.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	sl4.end_turn()   # 我方 → 敌方回合开始 → 敌方精进 +1
	check(sl4.state.unit_at(Vector2i(1, 1)).effective_power() == 3,
			"精进：敌方白魔法师同样 +1（2 → 3）")
	# 精进与治疗并存：回合开始既回 10 血又 +1 攻
	var sl5 := _new_engine([], 20, 20, -1, false)
	sl5.start_game(0)
	sl5.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	sl5.state.unit_at(Vector2i(4, 1)).health = 50
	sl5.end_turn()
	sl5.end_turn()
	var sl5_p := sl5.state.unit_at(Vector2i(4, 1))
	check(sl5_p.health == 60 and sl5_p.effective_power() == 3,
			"精进：与治疗并存——回合开始回 10 血且 +1 攻（50→60，2→3）")

	# ---- 能量与回合流程 ----
	var eng := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng.start_game()
	check(eng.turn_number == 1 and eng.current_side == GameEngine.SIDE_SELF, "开局我方先手第 1 回合")
	check(eng.state.energy == 5, "第 1 回合能量 = 5（实际 %d）" % eng.state.energy)
	check(eng.state.hand.size() == 5, "开局抽 5 张（实际 %d）" % eng.state.hand.size())
	check(eng.can_pay(5) and not eng.can_pay(6), "能量够 5 不够 6")
	var farmer_idx := _find(eng.state.hand, 8003)
	check(farmer_idx >= 0, "起手有农民可上")
	eng.play_from_hand(farmer_idx, Vector2i(4, 1))
	check(eng.state.energy == 2, "上场农民扣 3 能量（剩 %d）" % eng.state.energy)
	check(eng.state.unit_at(Vector2i(4, 1)) != null, "农民在 (4,1)")
	var p := eng.state.unit_at(Vector2i(4, 1))
	check(not p.tapped and not p.moved, "上场单位未横置，可移动/攻击")
	var deck_left := eng.state.deck.size()
	eng.end_turn()
	check(eng.state.hand.is_empty(), "回合结束弃掉全部手牌")
	check(eng.state.discard.size() == 4, "4 张手牌进弃牌区（实际 %d）" % eng.state.discard.size())
	check(eng.current_side == GameEngine.SIDE_OPPONENT and eng.state.opp_energy == 5,
			"对方回合：对方能量 = 5")
	eng.end_turn()
	check(eng.turn_number == 2, "回到我方第 2 回合")
	check(eng.state.energy == 5, "能量不累积：回合结束重置为 5（实际 %d）" % eng.state.energy)
	check(eng.state.hand.size() == 5, "第 2 回合再抽 5 张")
	check(eng.state.deck.size() == deck_left - 5,
			"每回合抽 5 张（牌库 %d → %d）" % [deck_left, eng.state.deck.size()])

	# ---- 抽空提示：牌库与弃牌区都空 → 不抽并提示 ----
	var eng_e := _new_engine([], 20, 20)
	var events: Array = []
	eng_e.action.connect(func(k: String, _d: Dictionary): events.append(k))
	eng_e.start_game()
	check("deck_empty" in events, "抽不到牌时广播 deck_empty")
	check(eng_e.log.any(func(line: String): return line.contains("没有卡牌可以抽了")),
			"日志提示「没有卡牌可以抽了」")
	check(eng_e.state.hand.is_empty(), "没有卡牌时手牌保持为空")

	# ---- 手牌上限 10：达上限后不再抽牌（牌留在牌库，不洗牌、不丢牌） ----
	var lim_deck: Array[CardData] = []
	for i in 20:
		lim_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var eng_lim := _new_engine(lim_deck, 20, 20, -1, false)
	var lim_events: Array = []
	eng_lim.action.connect(func(k: String, d: Dictionary) -> void:
			if k == "hand_full":
				lim_events.append(d))
	eng_lim.start_game()                       # 起手 5 张
	check(eng_lim.state.hand.size() == 5 and not eng_lim.state.hand_full(),
			"手牌上限：起手 5 张，未达上限")
	check(eng_lim._draw_many(3) == 3 and eng_lim.state.hand.size() == 8,
			"手牌上限：8 张时照样能抽满")
	check(eng_lim.state.deck.size() == 12, "手牌上限：抽牌只从牌库扣（20 - 8）")
	var lim_got := eng_lim._draw_many(5)       # 只剩 2 张的位置
	check(lim_got == 2 and eng_lim.state.hand.size() == FieldState.HAND_LIMIT,
			"手牌上限：抽到 %d 张即停（实际得 %d 张）"
			% [FieldState.HAND_LIMIT, lim_got])
	check(eng_lim.state.hand_full(), "手牌上限：满手时 hand_full() 为真")
	check(lim_events.size() == 1,
			"手牌上限：满手时广播 hand_full（实际 %d 次）" % lim_events.size())
	check(eng_lim.state.deck.size() == 10,
			"手牌上限：满手后牌留在牌库（剩 10 张，没被抽走）")
	check(eng_lim.state.discard.is_empty(), "手牌上限：满手抽牌不会误洗弃牌区")
	check(eng_lim.state.draw() == null, "手牌上限：满手时 draw() 直接返回 null")
	check(eng_lim.state.hand.size() == FieldState.HAND_LIMIT, "手牌上限：手牌数永不超上限")
	check(not eng_lim.log.any(func(l: String): return l.contains("没有卡牌可以抽了")),
			"手牌上限：牌库还有牌时不误报「没有卡牌可以抽了」")
	check(eng_lim.log.any(func(l: String): return l.contains("手牌已满")),
			"手牌上限：日志提示「手牌已满」")
	# 上限是常量，改它就必须同步调这里
	check(FieldState.HAND_LIMIT == 10, "手牌上限常量为 10")

	# ---- 牌库空 → 弃牌区洗回 ----
	var small: Array[CardData] = []
	small.append(_card(8003, "农民", "盟友", 3, 3, 8))
	var eng2 := _new_engine(small, 20, 20, -1, false)
	eng2.start_game()          # 抽走唯一 1 张
	check(eng2.state.deck.is_empty(), "牌库抽空")
	eng2.state.discard_hand()  # 手牌进弃牌区
	var got := eng2.state.draw()
	check(got != null and got.id == 8003 and eng2.state.discard.is_empty(),
			"牌库空时弃牌区洗回牌库继续抽")
	var none := eng2.state.draw()
	check(none == null, "弃牌区也空 → 抽不到牌")

	# ---- 技能：攻击（1 费 4 伤） ----
	var eng3 := _new_engine(_single_deck(_card(8002, "攻击", "技能", 1, 0, 0)), 20, 20, -1, false)
	eng3.start_game()
	var skeleton := _card(1053, "骷髅兵", "盟友", 1, 1, 2)
	eng3.state.place(skeleton, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	check(_find(eng3.state.hand, 8002) == 0, "起手是攻击")
	var e0 := eng3.state.energy
	var detail := eng3.use_spell(0, Vector2i(2, 1))
	check(eng3.state.unit_at(Vector2i(2, 1)) == null, "攻击 4 伤击杀 2 血骷髅兵（%s）" % detail)
	check(eng3.state.energy == e0 - 1, "攻击扣 1 能量")
	check(not eng3.state.discard.any(func(c: CardData): return c.id == 1053)
			and eng3.state.discard.any(func(c: CardData): return c.id == 8002),
			"被击杀的敌方卡移出场外；用掉的技能进我方弃牌区")
	# 无目标 → 打对方玩家
	var shot2 := _find(eng3.state.hand, 8002)  # 已用掉 → -1，换一张验证
	if shot2 < 0:
		eng3.state.hand.append(_card(8002, "攻击", "技能", 1, 0, 0))
		shot2 = eng3.state.hand.size() - 1
	var hp0 := eng3.state.hp_opponent
	eng3.use_spell(shot2, null)
	check(eng3.state.hp_opponent == hp0 - 4, "攻击无目标 → 敌方 HP -4")

	# ---- 效果卡：迅捷（3 费，减伤 2 只护自己的 HP，至少 1） ----
	var swift_t := _card(9002, "迅捷", "效果", 2, 0, 0)
	swift_t.traits = ["减伤"]
	swift_t.value = 2
	var eng_f := _new_engine(_single_deck(swift_t), 20, 20, -1, false)
	eng_f.start_game()
	eng_f.use_effect(0)
	check(eng_f.state.effects.size() == 1 and eng_f.state.hand.is_empty(),
			"效果卡进入效果区，离开手牌")
	check(eng_f.state.energy == 3, "效果卡扣 2 能量（5 - 2 = 3）")
	check(not eng_f.state.discard.any(func(c: CardData): return c.id == 9002),
			"效果卡不进弃牌区（持续生效）")
	var my_farmer := _card(8003, "农民", "盟友", 3, 3, 8)
	eng_f.state.place(my_farmer, Vector2i(4, 1), GameEngine.SIDE_SELF)
	var knight := _card(9001, "鸭子骑士", "盟友", 6, 5, 30)
	eng_f.state.place(knight, Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng_f.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	var fp := eng_f.state.unit_at(Vector2i(4, 1))
	check(fp != null and fp.health == 3,
			"迅捷不再为单位挡刀：农民被 5 力打，8-5=3（实际 %d）"
			% (fp.health if fp != null else -1))
	var kp := eng_f.state.unit_at(Vector2i(3, 1))
	check(kp != null and kp.health == 30,
			"主动攻击不受反击：骑士打农民后自身不损血（30，实际 %d）"
			% (kp.health if kp != null else -1))
	check(eng_f.state.hp_self == 20, "打单位不伤 HP：迅捷护 HP，我方仍 20")
	# 迅捷护 HP：直击 5 伤 → 5-2=3（至少 1）；效果伤害同样走 _damage_player
	var hp_tester := _card(1053, "测试兵", "盟友", 1, 5, 10, 2, 1)
	eng_f.state.place(hp_tester, Vector2i(4, 0), GameEngine.SIDE_OPPONENT)
	eng_f.attack_hp(Vector2i(4, 0), Vector2i(5, 0), GameEngine.SIDE_OPPONENT)
	check(eng_f.state.hp_self == 17, "迅捷护 HP：直击 5 伤 → 5-2=3，HP 20→17（实际 %d）"
			% eng_f.state.hp_self)
	eng_f._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(eng_f.state.hp_self == 14, "迅捷护 HP：效果伤害 5 → 3，HP 17→14（实际 %d）"
			% eng_f.state.hp_self)
	eng_f._damage_player(GameEngine.SIDE_SELF, 1, "测试")
	check(eng_f.state.hp_self == 13, "HP 至少受 1：1 点伤害不再减免（实际 %d）"
			% eng_f.state.hp_self)

	# ---- 技能：击退（向后 2 格，阻挡即停） ----
	var eng_k := _new_engine(_single_deck(_card(9004, "击退", "技能", 1, 0, 0)), 20, 20, -1, false)
	eng_k.start_game()
	var k1 := _card(9001, "鸭子骑士", "盟友", 6, 5, 30)
	eng_k.state.place(k1, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_k.use_spell(0, Vector2i(2, 1))
	var k1_at := eng_k.state.unit_at(Vector2i(0, 1))
	check(eng_k.state.unit_at(Vector2i(2, 1)) == null
			and k1_at != null and k1_at.card == k1,
			"击退：骑士从 (2,1) 退到 (0,1)（向后 2 格）")
	var k2 := _card(9001, "鸭子骑士", "盟友", 6, 5, 30)
	var blocker := _card(1053, "骷髅兵", "盟友", 1, 1, 2)
	eng_k.state.place(k2, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_k.state.place(blocker, Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	eng_k.state.hand.append(_card(9004, "击退", "技能", 1, 0, 0))
	var kdetail := eng_k.use_spell(eng_k.state.hand.size() - 1, Vector2i(2, 1))
	var k2_at := eng_k.state.unit_at(Vector2i(2, 1))
	check(k2_at != null and k2_at.card == k2 and kdetail.contains("挡住"),
			"击退被阻挡 → 原地不动")

	# ---- 技能：智慧（抽 2 张） ----
	var wdeck: Array[CardData] = [
		_card(7001, " filler1", "盟友", 1, 1, 1),
		_card(7002, " filler2", "盟友", 1, 1, 1),
		_card(9005, "智慧", "技能", 1, 0, 0),
		_card(7003, " filler3", "盟友", 1, 1, 1),
		_card(7004, " filler4", "盟友", 1, 1, 1),
		_card(7005, " filler5", "盟友", 1, 1, 1),
		_card(7006, " filler6", "盟友", 1, 1, 1),
	]
	var eng_w := _new_engine(wdeck, 20, 20, -1, false)
	eng_w.start_game()
	var widx := _find(eng_w.state.hand, 9005)
	check(widx >= 0, "起手抽到智慧")
	var deck_before := eng_w.state.deck.size()
	eng_w.use_spell(widx)
	check(eng_w.state.hand.size() == 6, "智慧：手牌 4 + 抽 2 = 6（实际 %d）" % eng_w.state.hand.size())
	check(eng_w.state.deck.size() == deck_before - 2, "智慧从牌库抽 2 张")

	# ---- 技能：闪电链（相连单位 11 伤，不分敌我） ----
	var eng_l := _new_engine(_single_deck(_card(9006, "闪电链", "技能", 2, 0, 0)), 20, 20, -1, false)
	eng_l.start_game()
	var la := _card(7001, "A", "盟友", 1, 1, 2)
	var lb := _card(7002, "B", "工事", 1, 0, 2)
	var lc := _card(7003, "C", "盟友", 1, 1, 2)
	var ld := _card(7004, "D", "盟友", 1, 1, 2)
	eng_l.state.place(la, Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng_l.state.place(lb, Vector2i(3, 1), GameEngine.SIDE_SELF)   # 与 A 相连
	eng_l.state.place(lc, Vector2i(0, 2), GameEngine.SIDE_OPPONENT)  # 孤立
	eng_l.state.place(ld, Vector2i(0, 0), GameEngine.SIDE_OPPONENT)  # 孤立（与 C 距离2）
	eng_l.use_spell(0, null)
	check(eng_l.state.unit_at(Vector2i(3, 0)) == null
			and eng_l.state.unit_at(Vector2i(3, 1)) == null,
			"闪电链：相连的 A/B 被击破（11 伤）")
	check(eng_l.state.unit_at(Vector2i(0, 2)) != null
			and eng_l.state.unit_at(Vector2i(0, 0)) != null,
			"孤立单位不在链上，不受伤")

	# ---- 技能：火球术（十字范围 20 伤） ----
	var eng_b := _new_engine(_single_deck(_card(9007, "火球术", "技能", 4, 0, 0)), 20, 20, -1, false)
	eng_b.start_game()
	var bm := _card(7001, "M", "盟友", 1, 1, 2)
	var bn := _card(7002, "N", "盟友", 1, 1, 2)
	var bo := _card(7003, "O", "盟友", 1, 1, 2)
	eng_b.state.place(bm, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)  # 中心
	eng_b.state.place(bn, Vector2i(4, 1), GameEngine.SIDE_SELF)      # 距离1
	eng_b.state.place(bo, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)  # 距离3
	var bdetail := eng_b.use_spell(0, Vector2i(3, 1))
	check(eng_b.state.unit_at(Vector2i(2, 1)) == null
			and eng_b.state.unit_at(Vector2i(4, 1)) == null,
			"火球术：中心与距离 1 的单位被击破（%s）" % bdetail)
	var bo_at := eng_b.state.unit_at(Vector2i(0, 1))
	check(bo_at != null and bo_at.card == bo,
			"距离 2 以外的单位不受伤")
	check(CardRepo.load_json().get_card(9007).needs_target(),
			"火球术：NEEDS_CELL 也算需要选目标（点击/拖拽都会进入选格子模式）")

	# ---- 道具：鸡煲（6003）第一次回合结束随机敌人 -3 ----
	var eng_r := _new_engine(_single_deck(_card(8003, "农民", "盟友", 3, 3, 8)), 20, 20, -1, false)
	eng_r.self_relics = [6003]
	eng_r.start_game()
	var duck_c := _card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2)
	eng_r.state.place(duck_c, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var duck_hp0 := eng_r.state.unit_at(Vector2i(0, 1)).health
	eng_r.end_turn()   # 我方第 1 回合结束 → 鸡煲触发
	var duck_after := eng_r.state.unit_at(Vector2i(0, 1))
	check(duck_after != null and duck_after.health == duck_hp0 - 3,
			"鸡煲：第一次回合结束对随机敌人造成 3 点伤害")
	eng_r.end_turn()   # 对手回合结束（不应触发）
	eng_r.end_turn()   # 我方第 2 回合结束（不应再触发）
	var duck_final := eng_r.state.unit_at(Vector2i(0, 1))
	check(duck_final != null and duck_final.health == duck_hp0 - 3,
			"鸡煲：没用过效果卡的回合结束不触发（第 2 回合结束不掉血）")
	# 无敌人时落空（不崩溃、不掉自己 HP）
	var eng_r2 := _new_engine(_single_deck(_card(8003, "农民", "盟友", 3, 3, 8)), 20, 20, -1, false)
	eng_r2.self_relics = [6003]
	eng_r2.start_game()
	eng_r2.end_turn()
	check(eng_r2.state.hp_self == 20 and not eng_r2.over, "鸡煲：场上没有敌人时效果落空")

	# ---- 道具（奖励池）：鸭蹼 / 鸭嘴 / 鸭翼（6005-6007） ----
	var rrepo := RelicRepo.load_json()
	check(rrepo.get_relic(6005) != null and rrepo.get_relic(6006) != null
			and rrepo.get_relic(6007) != null,
			"奖励道具：鸭蹼/鸭嘴/鸭翼已登记到 relics.json")
	check(not rrepo.initial_ids().has(6005) and rrepo.reward_ids().has(6005)
			and rrepo.reward_ids().has(6006) and rrepo.reward_ids().has(6007),
			"奖励道具：三个鸭系道具在奖励池、不在初始池")
	var eng_web := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng_web.self_relics = [6005]
	eng_web.start_game()
	check(eng_web.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 1,
			"鸭蹼：第 1 回合开始多抽 1 张（实际 %d）" % eng_web.state.hand.size())
	eng_web.end_turn()
	eng_web.end_turn()
	check(eng_web.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 1,
			"鸭蹼：第 2 回合开始仍多抽 1 张（实际 %d）" % eng_web.state.hand.size())
	eng_web.end_turn()
	eng_web.end_turn()
	check(eng_web.state.hand.size() == FieldState.HAND_DRAW_PER_TURN,
			"鸭蹼：第 3 回合起恢复正常抽牌数（实际 %d）" % eng_web.state.hand.size())
	# 鸭翼：第 3 回合额外 3 费（能量回合结束重置为 5：5 / 5 / 8 / 5）—— R81 由 2 加强到 3
	var eng_wing := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng_wing.self_relics = [6007]
	eng_wing.start_game()
	check(eng_wing.state.energy == FieldState.ENERGY_PER_TURN,
			"鸭翼：第 1 回合费用不变（实际 %d）" % eng_wing.state.energy)
	eng_wing.end_turn()
	eng_wing.end_turn()
	check(eng_wing.state.energy == FieldState.ENERGY_PER_TURN,
			"鸭翼：第 2 回合费用不变（重置为 5，实际 %d）" % eng_wing.state.energy)
	eng_wing.end_turn()
	eng_wing.end_turn()
	check(eng_wing.state.energy == FieldState.ENERGY_PER_TURN + 3,
			"鸭翼：第 3 回合费用 +3（5 + 3，实际 %d）" % eng_wing.state.energy)
	eng_wing.end_turn()
	eng_wing.end_turn()
	check(eng_wing.state.energy == FieldState.ENERGY_PER_TURN,
			"鸭翼：第 4 回合不再加费（重置回 5，实际 %d）" % eng_wing.state.energy)
	# R81：鸭翼的数值只有一个来源（引擎常量），relics.json 文案与回归都对着它写
	var wr_repo := RelicRepo.load_json()
	check(GameEngine.DUCK_WING_ENERGY == 3 and GameEngine.DUCK_WING_TURN == 3
			and GameEngine.DUCK_WING_RELIC_ID == 6007,
			"R81 鸭翼：引擎常量 = 6007 / 第 3 回合 / 3 点费用")
	check(wr_repo.get_relic(6007).desc.contains("3 点额外费用")
			and not wr_repo.get_relic(6007).desc.contains("2 点额外费用"),
			"R81 鸭翼：卡面文案已同步为「3 点额外费用」")
	# 鸭嘴：受到 5 以上伤害减 1（结算减伤后）
	var eng_bill := _new_engine(_single_deck(_card(8003, "农民", "盟友", 3, 3, 8)), 20, 20, -1, false)
	eng_bill.self_relics = [6006]
	eng_bill.start_game()
	eng_bill.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var m1 := eng_bill.state.unit_at(Vector2i(3, 1))
	var got5 := eng_bill._hit_unit(m1, 5, "测试")
	check(got5 == 4 and m1.health == 4, "鸭嘴：5 点伤害减 1（实际 %d）" % got5)
	var got4 := eng_bill._hit_unit(m1, 4, "测试")
	check(got4 == 4 and m1.health == 0, "鸭嘴：4 点伤害不减")
	eng_bill.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var m2 := eng_bill.state.unit_at(Vector2i(3, 1))
	var got20 := eng_bill._hit_unit(m2, 20, "测试")
	check(got20 == 19, "鸭嘴：20 点伤害减 1（实际 %d）" % got20)
	var eng_bill2 := _new_engine(_single_deck(_card(8003, "农民", "盟友", 3, 3, 8)), 20, 20, -1, false)
	eng_bill2.self_relics = [6006]
	eng_bill2.start_game()
	eng_bill2._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(eng_bill2.state.hp_self == 16, "鸭嘴：我方 HP 受 5 点伤害减 1（20 → 16，实际 %d）"
			% eng_bill2.state.hp_self)
	# 鸭绒：每回合使用的第一个单位 +2 生命（次回合重新计）
	var deck_velvet: Array[CardData] = []
	for i in 3:
		deck_velvet.append(_card(8001, "木栅栏", "工事", 2, 0, 6))
	var eng_velvet := _new_engine(deck_velvet, 20, 20, -1, false)
	eng_velvet.self_relics = [6008]
	eng_velvet.start_game()
	var v1 := _find(eng_velvet.state.hand, 8001)
	eng_velvet.play_from_hand(v1, Vector2i(3, 1))
	check(eng_velvet.state.unit_at(Vector2i(3, 1)).health == 8,
			"鸭绒：回合内第一个单位 +2 生命（6 → 8）")
	var v2 := _find(eng_velvet.state.hand, 8001)
	eng_velvet.play_from_hand(v2, Vector2i(3, 2))
	check(eng_velvet.state.unit_at(Vector2i(3, 2)).health == 6,
			"鸭绒：同回合第二个单位不再加（6 → 6）")
	eng_velvet.end_turn()
	eng_velvet.end_turn()
	var v3 := _find(eng_velvet.state.hand, 8001)
	eng_velvet.play_from_hand(v3, Vector2i(4, 1))
	check(eng_velvet.state.unit_at(Vector2i(4, 1)).health == 8,
			"鸭绒：次回合第一个单位重新 +2（6 → 8）")
	# 鸭之眼（6009）：技能伤害 +X，X = 该技能卡的原始费用（对单位与玩家 HP）
	var deck_eye: Array[CardData] = []
	for i in 2:
		deck_eye.append(_card(8002, "攻击", "技能", 2, 0, 0))
	var eng_eye := _new_engine(deck_eye, 20, 20, -1, false)
	eng_eye.self_relics = [6009]
	eng_eye.start_game()
	eng_eye.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var s1 := _find(eng_eye.state.hand, 8002)
	eng_eye.use_spell(s1, Vector2i(2, 1))
	var efarmer := eng_eye.state.unit_at(Vector2i(2, 1))
	check(efarmer != null and efarmer.health == 2,
			"鸭之眼：攻击 4+2=6（8 血农民剩 %d）" % (efarmer.health if efarmer != null else -1))
	var s2 := _find(eng_eye.state.hand, 8002)
	var hp_e0 := eng_eye.state.hp_opponent
	eng_eye.use_spell(s2, null)
	check(eng_eye.state.hp_opponent == hp_e0 - 6,
			"鸭之眼：攻击无目标 → 敌方 HP -6（实际 %d）" % (hp_e0 - eng_eye.state.hp_opponent))
	eng_eye.remote_spell(_card(8002, "攻击", "技能", 2, 0, 0), null)
	check(eng_eye.state.hp_self == 16,
			"鸭之眼：敌方施法不受加成（我方 HP 20-4=16，实际 %d）" % eng_eye.state.hp_self)
	# X 取的是 card.cost（原始费用），不是 cost_of()（临时减费不吃掉加成）
	var eye_big := _card(8002, "攻击", "技能", 5, 0, 0)
	check(eng_eye._spell_dmg(GameEngine.SIDE_SELF, 4, eye_big) == 9,
			"鸭之眼：5 费技能 → 4+5=9")
	check(eng_eye._spell_dmg(GameEngine.SIDE_SELF, 4, null) == 4,
			"鸭之眼：没传技能卡时不加成")
	check(eng_eye._spell_dmg(GameEngine.SIDE_OPPONENT, 4, eye_big) == 4,
			"鸭之眼：加成只对己方生效")
	eng_eye.self_relics = []
	check(eng_eye._spell_dmg(GameEngine.SIDE_SELF, 4, eye_big) == 4,
			"没有鸭之眼时技能伤害不加成")
	# 掉落：精英/Boss 胜利掉落随机奖励道具（不重复、可掉空）
	var saved_relics: Array[int] = RunState.relics.duplicate()
	RunState.relics = []
	var d1 := RunState.offer_relic_drop("elite")
	check(d1 > 0 and RunState.pending_relic_drop == d1
			and RelicRepo.load_json().reward_ids().has(d1),
			"精英胜利：掉落一个奖励池道具（待领取）")
	RunState.claim_relic_drop()
	check(RunState.has_relic(d1) and RunState.pending_relic_drop == -1,
			"领取掉落：道具入列、待领清空")
	# ⚠️ R81：奖励池新增了「鸭血」（6024），它获得时会置 `pending_relic`（要玩家选卡）。
	# 这里摇到的 d1 有可能是鸭血 → 领取后 `pending_relic` 会**合法地**留着 6024。
	# 必须清掉，否则后面「某某道具获得后无待选后续」的断言会被这次随机掉落污染。
	RunState.pending_relic = -1
	check(RunState.offer_relic_drop("battle") == -1 and RunState.pending_relic_drop == -1,
			"普通战斗胜利：不掉落道具")
	RunState.relics = RelicRepo.load_json().reward_ids()
	check(RunState.offer_relic_drop("boss") == -1,
			"奖励池掉空（全部拥有）：Boss 也不再掉落")
	RunState.relics = saved_relics

	# ---- 跳过的奖励道具：本局后续不再随机出来 ----
	var saved_skipped: Array[int] = RunState.skipped_relics.duplicate()
	var all_reward: Array[int] = RelicRepo.load_json().reward_ids()
	RunState.relics = []
	RunState.pending_relic_drop = -1
	# skip_relic_drop：登记跳过、清空待领、不入道具栏
	RunState.skipped_relics = []
	RunState.pending_relic_drop = all_reward[0]
	check(RunState.skip_relic_drop() == all_reward[0]
			and RunState.skipped_relics.has(all_reward[0])
			and RunState.pending_relic_drop == -1
			and not RunState.relics.has(all_reward[0]),
			"跳过道具：登记 skipped、清空待领、不入道具栏")
	# 被跳过的一个：连摇 30 次掉落永远不会是它
	var hit_skipped := false
	for _i in 30:
		RunState.pending_relic_drop = -1
		if RunState.offer_relic_drop("elite") == all_reward[0]:
			hit_skipped = true
	check(not hit_skipped, "被跳过的道具不会再随机出来（连摇 30 次都不中）")
	# 宝箱开箱同样避开被跳过的
	var chest_hit := false
	for _i in 30:
		if RunState.roll_reward_relic() == all_reward[0]:
			chest_hit = true
	check(not chest_hit, "被跳过的道具宝箱也开不出来（连摇 30 次都不中）")
	# 全部跳过 → 没有可掉落的
	RunState.skipped_relics = all_reward.duplicate()
	check(RunState.offer_relic_drop("elite") == -1 and RunState.roll_reward_relic() == -1,
			"跳过全部奖励道具：掉落与开箱都摇空")
	RunState.skipped_relics = saved_skipped
	RunState.pending_relic_drop = -1
	RunState.relics = saved_relics

	# ---- 道具来源分类（决定颜色）：初始白 / 奖励黄 / 事件紫 ----
	var srepo := RelicRepo.load_json()
	check(srepo.get_relic(6001) != null and srepo.get_relic(6001).is_initial()
			and srepo.get_relic(6001).source == RelicData.SRC_INITIAL,
			"道具来源：6001 类固醇 = 初始（白）")
	check(srepo.get_relic(6005).source == RelicData.SRC_REWARD,
			"道具来源：6005 鸭蹼 = 奖励（黄）")
	check(srepo.get_relic(6010) != null and srepo.get_relic(6010).source == RelicData.SRC_EVENT,
			"道具来源：6010 鸭之低语 = 事件（紫）")
	var c_ini := srepo.get_relic(6001).source_color()
	var c_rew := srepo.get_relic(6005).source_color()
	var c_evt := srepo.get_relic(6010).source_color()
	check(c_ini != c_rew and c_rew != c_evt and c_ini != c_evt,
			"来源颜色：初始/奖励/事件三色互不相同")
	check(srepo.event_ids().has(6010) and not srepo.initial_ids().has(6010)
			and not srepo.reward_ids().has(6010),
			"事件道具池：6010 只在事件池（不进初始/奖励池）")
	check(srepo.get_relic(6010).kind != "" and srepo.get_relic(6010).source_label() == "事件道具",
			"道具来源标签：source_label() = 事件道具")

	# ---- 道具「鸭梨」（6019）：鸭梨山大事件道具（第二层事件）----
	check(srepo.get_relic(6019) != null and srepo.get_relic(6019).relic_name == "鸭梨",
			"鸭梨：已登记到 relics.json（鸭梨山大事件道具）")
	check(srepo.event_ids().has(6019) and not srepo.initial_ids().has(6019) \
			and not srepo.reward_ids().has(6019) and not srepo.layer2_ids().has(6019),
			"鸭梨：只在事件池（不进初始/奖励/二层起始池）")

	# ---- 道具「烤肉」（6011）：休息处事件道具，进入 Boss 战时消耗回血 ----
	check(srepo.get_relic(6011) != null and srepo.get_relic(6011).relic_name == "烤肉"
			and srepo.get_relic(6011).source == RelicData.SRC_EVENT,
			"烤肉：事件道具已登记到 relics.json（来源=事件/紫）")
	check(srepo.event_ids().has(6011) and not srepo.initial_ids().has(6011)
			and not srepo.reward_ids().has(6011),
			"烤肉：只在事件池（起点三选一与奖励掉落都拿不到）")
	var saved_r3: Array[int] = RunState.relics.duplicate()
	RunState.relics.clear()
	RunState.reset(40)
	RunState.take_damage(20)                      # 40 → 20
	check(RunState.consume_barbecue() == -1, "烤肉：未持有时无法消耗（返回 -1）")
	RunState.gain_relic(6011)
	RunState.gain_relic(6011)                     # 持有时重复获得
	check(RunState.relics.count(6011) == 1, "烤肉：持有时重复获得不会叠加（只登记一次）")
	check(RunState.has_relic(6011), "烤肉：已收进道具栏")
	var bbq_healed := RunState.consume_barbecue()
	check(bbq_healed == 10 and RunState.hp == 30,
			"烤肉：Boss 战消耗回复 25%% 最大生命（40 的 25%% = 10，20 → 30，实际 +%d）" % bbq_healed)
	check(not RunState.has_relic(6011), "烤肉：消耗后离开道具栏（休息处可再次烤制）")
	RunState.gain_relic(6011)
	check(RunState.has_relic(6011), "烤肉：消耗后可再次获得")
	RunState.relics.clear()
	RunState.relics.append(6011)
	RunState.reset(40)                            # 满血 40/40
	check(RunState.consume_barbecue() == 0 and not RunState.has_relic(6011)
			and RunState.hp == 40,
			"烤肉：满血进 Boss 战同样被消耗（回复 0，HP 不变）")
	RunState.relics = saved_r3
	RunState.reset()

	# ---- 事件节点子类型：取自「本层事件池」（见 GameLayers）----
	var kind_ok := true
	var ev_layer_ok := true
	var seen_kinds := {}
	var ev_rng := RandomNumberGenerator.new()
	ev_rng.randomize()
	var ev_pool := GameLayers.event_kinds(GameLayers.LAYER_DEFAULT)
	for i in 40:
		var em: Array = RogueMap.generate(ev_rng, GameLayers.LAYER_DEFAULT)
		for col_nodes in em:
			for node in col_nodes:
				if int(node.get("layer", -1)) != GameLayers.LAYER_DEFAULT:
					ev_layer_ok = false
				if str(node["type"]) != "event":
					continue
				var ek := str(node.get("event_kind", ""))
				seen_kinds[ek] = true
				if not ev_pool.has(ek):
					kind_ok = false
	check(kind_ok, "事件节点：event_kind 全部取自本层事件池（不会串到别的层）")
	check(ev_layer_ok, "地图节点都带着本图所属的层（第一层）")
	check(seen_kinds.has("treasure") and seen_kinds.has("whisper"),
			"多次生成：宝箱与鸭鸭低语两种事件都会出现")
	check(seen_kinds.has("struggle"), "多次生成：挣扎事件会出现")
	check(seen_kinds.has("arcane") or seen_kinds.has("oblivion"),
			"多次生成：第一层新事件（奥秘之泉 / 遗忘之泉）会出现")
	check(not seen_kinds.has("gaze"),
			"鸭之凝视已挪到第二层：第一层地图不再生成 gaze 事件")
	check(seen_kinds.has("monster"), "多次生成：事件节点遭遇怪物（monster）会出现")

	# ---- 事件道具：鸭之低语（6010）获得 / 去重 ----
	var saved_relics2: Array[int] = RunState.relics.duplicate()
	RunState.relics = []
	RunState.gain_relic(6010)
	check(RunState.has_relic(6010) and RunState.pending_relic == -1,
			"鸭之低语：从事件获得后入道具栏（无待选后续）")
	var relic_cnt := RunState.relics.size()
	RunState.gain_relic(6010)
	check(RunState.relics.size() == relic_cnt, "鸭之低语：重复获得被忽略")
	RunState.relics = saved_relics2

	# ---- 鸭之低语：每回合随机强化（费用 +1 / 伤害 +1 / 多抽 1 张） ----
	var eng_wis := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng_wis.self_relics = [6010]
	eng_wis.start_game()
	var seen_buffs := {}
	var wis_ok := true
	for t in 30:
		# 费用在回合结束已重置为基础值：本回合不拔卡 → 手里的数就是「5 + 本回合加费」
		eng_wis.end_turn()   # → 对手回合
		eng_wis.end_turn()   # → 我方下一回合（此处掷强化）
		var e_now := eng_wis.state.energy
		var d_d := eng_wis.turn_dmg_bonus
		var h := eng_wis.state.hand.size()
		var tag := ""
		if e_now == FieldState.ENERGY_PER_TURN + 1 and d_d == 0 \
				and h == FieldState.HAND_DRAW_PER_TURN:
			tag = "费用+1"
		elif e_now == FieldState.ENERGY_PER_TURN and d_d == 1 \
				and h == FieldState.HAND_DRAW_PER_TURN:
			tag = "伤害+1"
		elif e_now == FieldState.ENERGY_PER_TURN and d_d == 0 \
				and h == FieldState.HAND_DRAW_PER_TURN + 1:
			tag = "多抽1张"
		else:
			wis_ok = false
			print("    异常组合：能量%d 伤害+%d 手牌%d" % [e_now, d_d, h])
		if tag != "":
			seen_buffs[tag] = true
	check(wis_ok, "鸭之低语：每回合开始恰好掷出三种强化之一")
	check(seen_buffs.size() == 3,
			"鸭之低语：多次回合后三种强化都出现过（%d/3）" % seen_buffs.size())
	# 伤害加成实际作用：普攻 / 直击 HP / 技能
	var eng_wd := _new_engine([], 20, 20)
	eng_wd.self_relics = [6010]
	eng_wd.turn_dmg_bonus = 1
	eng_wd.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var foe_d := _card(1053, "骷髅兵", "盟友", 1, 1, 9)
	eng_wd.state.place(foe_d, Vector2i(3, 2), GameEngine.SIDE_OPPONENT)
	eng_wd.attack(Vector2i(3, 1), Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(eng_wd.state.unit_at(Vector2i(3, 2)).health == 5,
			"鸭之低语：普攻伤害 +1（力 3 → 4，骷髅兵 9 → %d）"
			% eng_wd.state.unit_at(Vector2i(3, 2)).health)
	check(eng_wd._turn_dmg_bonus(GameEngine.SIDE_OPPONENT) == 0,
			"鸭之低语：对方不享受伤害加成")
	var eng_ws := _new_engine(_single_deck(_card(8002, "攻击", "技能", 1, 0, 0)), 20, 20, -1, false)
	eng_ws.self_relics = [6010]
	eng_ws.start_game()
	eng_ws.turn_dmg_bonus = 1
	var hp_b := eng_ws.state.hp_opponent
	eng_ws.use_spell(_find(eng_ws.state.hand, 8002), null)
	check(eng_ws.state.hp_opponent == hp_b - 5,
			"鸭之低语：技能伤害 +1（攻击 4+1=5 → 敌方 HP -5）")
	# 回合结束 → 下一回合掷骰前，伤害加成清空
	eng_ws.end_turn()
	eng_ws.end_turn()
	check(eng_ws.turn_dmg_bonus in [0, 1], "鸭之低语：新回合的伤害加成重新掷定（0/1）")

	# ---- 新道具：一袋米抗几楼（6012，鸭之凝视）/ 叠加态的鸭（6013）/ 宝箱层开箱 ----
	var rr_repo := RelicRepo.load_json()
	check(rr_repo.event_ids().has(6012) and rr_repo.reward_ids().has(6013),
			"道具库：一袋米抗几楼（事件池）/ 叠加态的鸭（奖励池）登记正确")
	var rice_rel := rr_repo.get_relic(6012)
	check(rice_rel != null and rice_rel.relic_name == "一袋米抗几楼"
			and rice_rel.source == "事件",
			"一袋米抗几楼：事件道具（source=事件）")
	var duck_rel := rr_repo.get_relic(6013)
	check(duck_rel != null and duck_rel.relic_name == "叠加态的鸭"
			and duck_rel.source == "奖励",
			"叠加态的鸭：奖励道具（source=奖励）")
	var saved_relics3: Array[int] = RunState.relics.duplicate()
	RunState.relics = []
	RunState.gain_relic(6012)
	check(RunState.has_relic(6012) and RunState.pending_relic == -1,
			"一袋米抗几楼：从鸭之凝视事件获得后入道具栏（无待选后续）")
	# 宝箱层开箱：随机一个「尚未拥有」的奖励道具
	var chest_a := RunState.roll_reward_relic()
	check(rr_repo.reward_ids().has(chest_a),
			"宝箱层：开出的道具来自奖励池（%d）" % chest_a)
	RunState.relics = [chest_a]
	var chest_b := RunState.roll_reward_relic()
	check(chest_b > 0 and chest_b != chest_a, "宝箱层：不会开出已拥有的道具")
	RunState.relics = rr_repo.reward_ids()
	check(RunState.roll_reward_relic() == -1, "宝箱层：奖励道具全部拥有 → 空箱（-1）")
	RunState.relics = saved_relics3
	# R81：roll_reward_relic 只返回 id、不调 gain_relic，所以这里不会置 pending_relic。
	# 仍然显式清一次 —— 若将来有人改成「开箱即入库」，鸭血会留下待选，污染后续断言。
	RunState.pending_relic = -1

	# ---- 一袋米抗几楼（6012）：每回合首次受伤 → 抽 1 张 + 技能伤害 +1 ----
	var rice_deck: Array[CardData] = []
	for i in 8:
		rice_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var eng_rice := _new_engine(rice_deck, 20, 20, -1, false)
	eng_rice.self_relics = [6012]
	eng_rice.start_game()
	var rice_hand0 := eng_rice.state.hand.size()
	eng_rice._damage_player(GameEngine.SIDE_SELF, 3, "测试")
	check(eng_rice.state.hand.size() == rice_hand0 + 1,
			"一袋米抗几楼：本回合首次受伤 → 抽 1 张卡（%d → %d）"
			% [rice_hand0, eng_rice.state.hand.size()])
	check(eng_rice._spell_dmg(GameEngine.SIDE_SELF, 4) == 5,
			"一袋米抗几楼：本回合技能伤害 +1（攻击 4 → 5）")
	eng_rice._damage_player(GameEngine.SIDE_SELF, 3, "测试")
	check(eng_rice.state.hand.size() == rice_hand0 + 1 and eng_rice.turn_spell_bonus == 1,
			"一袋米抗几楼：同一轮内再次受伤不再触发")
	eng_rice.end_turn()
	check(eng_rice.turn_spell_bonus == 0,
			"一袋米抗几楼：一轮结束（我方回合末）技能加成清零")
	# 我方场上单位中招也算「受到伤害」（与鸭嘴 6006 的判据一致）
	var eng_rice2 := _new_engine(rice_deck, 20, 20, -1, false)
	eng_rice2.self_relics = [6012]
	eng_rice2.start_game()
	var rice_p := eng_rice2.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng_rice2._hit_unit(rice_p, 2, "测试")
	check(eng_rice2.turn_spell_bonus == 1,
			"一袋米抗几楼：我方单位中招同样算首次受伤")
	# 没有道具时不受影响
	var eng_rice3 := _new_engine(rice_deck, 20, 20, -1, false)
	eng_rice3.start_game()
	var rice_hand3 := eng_rice3.state.hand.size()
	eng_rice3._damage_player(GameEngine.SIDE_SELF, 3, "测试")
	check(eng_rice3.turn_spell_bonus == 0
			and eng_rice3.state.hand.size() == rice_hand3,
			"一袋米抗几楼：未持有道具时受伤无任何加成")

	# ---- 叠加态的鸭（6013）：HP 归零 → 复活（回复 1 点），概率每次 -25 ----
	var duck_deck: Array[CardData] = []
	for i in 6:
		duck_deck.append(_card(8003, "农民", "盟友", 3, 3, 8))
	var eng_duck := _new_engine(duck_deck, 10, 20, -1, false)
	eng_duck.self_relics = [6013]
	eng_duck.duck_revive_chance = 100
	eng_duck.start_game()
	var duck_seen: Array[int] = []
	for i in 20:
		if eng_duck.over:
			break
		var chance_before := eng_duck.duck_revive_chance
		eng_duck._damage_player(GameEngine.SIDE_SELF, 999, "测试")
		if not eng_duck.over:
			duck_seen.append(chance_before)
	check(duck_seen.size() >= 1 and duck_seen[0] == 100,
			"叠加态的鸭：100% 概率必定复活（回复 1 点生命）")
	var duck_chain_ok := true
	for i in duck_seen.size():
		if duck_seen[i] != 100 - 25 * i:
			duck_chain_ok = false
	check(duck_chain_ok, "叠加态的鸭：复活概率每次永久 -25（100/75/50/25）")
	check(eng_duck.duck_revive_chance == maxi(0, 100 - 25 * duck_seen.size()),
			"叠加态的鸭：概率降到 0 后不再复活（当前 %d%%）"
			% eng_duck.duck_revive_chance)
	check(eng_duck.over and eng_duck.result == "失败",
			"叠加态的鸭：概率耗尽后 HP 归零 = 正常判负")
	# 未持有道具 → 直接判负，不消耗概率
	var eng_duck2 := _new_engine(duck_deck, 10, 20, -1, false)
	eng_duck2.start_game()
	eng_duck2._damage_player(GameEngine.SIDE_SELF, 999, "测试")
	check(eng_duck2.over and eng_duck2.result == "失败"
			and eng_duck2.duck_revive_chance == 100,
			"叠加态的鸭：未持有时 HP 归零立即判负（概率不变）")
	# run 侧：复活概率跨战斗保留 + 道具状态说明
	var saved_chance := RunState.duck_revive_chance
	RunState.relics = [6013]
	RunState.duck_revive_chance = 75
	check(RunState.relic_state_note(6013).contains("75%"),
			"叠加态的鸭：道具状态说明带当前复活概率（75%）")
	RunState.relics = []
	RunState.duck_revive_chance = saved_chance

	# ---- 放置/移动/攻击 ----
	var eng4 := _new_engine([], 20, 20)
	var f1 := _card(8003, "农民", "盟友", 3, 3, 8)
	eng4.state.place(f1, Vector2i(4, 1), GameEngine.SIDE_SELF)
	var e1 := _card(1053, "骷髅兵", "盟友", 1, 1, 2)
	eng4.state.place(e1, Vector2i(3, 2), GameEngine.SIDE_OPPONENT)
	eng4.move(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(3, 1)) != null, "农民移动 1 格")
	eng4.attack(Vector2i(3, 1), Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(3, 2)) == null, "农民 3 力一击击破 2 血骷髅兵")
	var attacker := eng4.state.unit_at(Vector2i(3, 1))
	check(attacker != null and attacker.health == 8,
			"攻击不受反击：农民保持 8 血（实际 %d）"
			% (attacker.health if attacker != null else -1))
	check(attacker != null and attacker.tapped, "攻击后横置")
	eng4.attack(Vector2i(3, 1), Vector2i(4, 2), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(3, 1)) != null
			and eng4.state.unit_at(Vector2i(3, 1)).tapped, "横置后不能再攻击")
	# 工事不能移动
	var fence2 := _card(8001, "木栅栏", "工事", 2, 0, 6)
	eng4.state.place(fence2, Vector2i(5, 1), GameEngine.SIDE_SELF)
	eng4.move(Vector2i(5, 1), Vector2i(5, 2), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(5, 1)) != null
			and eng4.state.unit_at(Vector2i(5, 2)) == null, "工事不能移动")
	# 工事也能攻击：箭塔（5 力 / 程 2）可远程开火，但仍不能移动
	var aw_tower := _card(9019, "箭塔", "工事", 3, 5, 10, 2, 0)
	eng4.state.place(aw_tower, Vector2i(4, 1), GameEngine.SIDE_SELF)
	var aw_foe := _card(9017, "鸭子弓手", "盟友", 3, 3, 18, 2, 1)
	eng4.state.place(aw_foe, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var aw_targets := eng4.attack_targets(Vector2i(4, 1), GameEngine.SIDE_SELF,
			eng4.state.unit_at(Vector2i(4, 1)).card)
	check(aw_targets.has(Vector2i(2, 1)), "箭塔程2：能打到 2 格外的敌人")
	eng4.attack(Vector2i(4, 1), Vector2i(2, 1), GameEngine.SIDE_SELF)
	var aw_hit := eng4.state.unit_at(Vector2i(2, 1))
	check(aw_hit != null and aw_hit.health == 13,
			"箭塔 5 力远程命中：鸭子弓手 18 → 13 血（实际 %d）"
			% (aw_hit.health if aw_hit != null else -1))
	eng4.move(Vector2i(4, 1), Vector2i(4, 2), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(4, 1)) != null
			and eng4.state.unit_at(Vector2i(4, 2)) == null, "箭塔开火后依旧不能移动")
	eng4.end_turn()
	eng4.end_turn()
	check(eng4.state.unit_at(Vector2i(4, 1)) != null
			and not eng4.state.unit_at(Vector2i(4, 1)).tapped, "箭塔新回合重置（可再次开火）")
	# 对方后排（第 0 行）是移动禁区
	var runner := _card(8003, "农民", "盟友", 3, 3, 8, 1, 3)
	eng4.state.place(runner, Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng4.move(Vector2i(3, 0), Vector2i(1, 0), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(1, 0)) != null, "速度 3 可推进到第 1 行")
	eng4.move(Vector2i(1, 0), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(eng4.state.unit_at(Vector2i(0, 1)) == null, "不能移动进对方后排禁区（第 0 行）")

	# ---- 攻击 HP / 胜负 / 回合上限 ----
	var eng5 := _new_engine([], 20, 20)
	# HP 直击：对方后排整行（无论是否被占）进入攻击范围即可，距离不再 +1
	var archer := _card(8003, "农民", "盟友", 3, 2, 8, 4, 1)
	eng5.state.place(archer, Vector2i(3, 1), GameEngine.SIDE_SELF)
	var ht := eng5.hp_targets(Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(ht.size() == 3, "射程 4 距后排 3 格：正对列及相邻两列可直击 HP")
	eng5.attack_hp(Vector2i(3, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(eng5.state.hp_opponent == 18, "攻击敌方 HP：20 - 2 = 18")
	# 近战（射程 1）：远离后排够不到；与后排相邻即可直击
	var melee_far := _card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2)
	eng5.state.place(melee_far, Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(eng5.hp_targets(Vector2i(4, 0), GameEngine.SIDE_SELF).is_empty(),
			"射程 1 远离敌方后排：够不到 HP")
	var melee_near := _card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2)
	eng5.state.place(melee_near, Vector2i(1, 0), GameEngine.SIDE_SELF)
	check(not eng5.hp_targets(Vector2i(1, 0), GameEngine.SIDE_SELF).is_empty(),
			"射程 1 与敌方后排相邻：可直击 HP")
	eng5.state.hp_self = 1
	eng5._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(eng5.over and eng5.result == "失败", "我方 HP 归零 → 失败")
	var eng6 := _new_engine([], 20, 20, 1)
	eng6.start_game()
	eng6.end_turn()
	eng6.end_turn()
	check(eng6.over and eng6.result == "失败", "超过回合上限 → 失败")

	# ---- 清场胜利：消灭所有敌方场上单位 → 直接胜利（无需打空敌方 HP） ----
	var eng_cw := _new_engine([], 20, 30)
	eng_cw.state.clear_win = true
	eng_cw.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_cw.state.place(_card(8003, "农民", "盟友", 3, 30, 8, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(not eng_cw.over, "清场胜利：敌方还有单位时不触发")
	eng_cw.attack(Vector2i(3, 1), Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(eng_cw.over and eng_cw.result == "胜利",
			"消灭最后一个敌方单位 → 直接胜利（敌方 HP 还剩 30）")
	check(eng_cw.state.discard.is_empty(), "清场胜利后敌方单位不进我方弃牌区")

	# ---- AI ----
	var eng7 := _new_engine([], 20, 20)
	eng7.ai_enabled = true
	eng7.state.place(archer, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng7.current_side = GameEngine.SIDE_OPPONENT
	eng7.run_ai_unit(Vector2i(2, 1))
	check(eng7.state.hp_self < 20 or eng7.state.board.size() > 0, "AI 单位会行动")
	# 没有可攻击单位时：AI 直击我方 HP（需我方后排在其攻击范围内）
	var eng8 := _new_engine([], 20, 20)
	eng8.ai_enabled = true
	eng8.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng8.current_side = GameEngine.SIDE_OPPONENT
	eng8.run_ai_unit(Vector2i(3, 1))
	check(eng8.state.hp_self == 15, "无可攻击单位：AI 直击我方 HP（20 - 5 = 15）")
	# 能直击 HP 时优先打 HP —— 哪怕旁边就有可以打的我方单位
	var eng9 := _new_engine([], 20, 20)
	eng9.ai_enabled = true
	eng9.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng9.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(5, 1), GameEngine.SIDE_SELF)
	eng9.current_side = GameEngine.SIDE_OPPONENT
	eng9.run_ai_unit(Vector2i(4, 1))
	var kept := eng9.state.unit_at(Vector2i(5, 1))
	check(eng9.state.hp_self == 15 and kept != null and kept.health == 8,
			"AI 优先直击 HP：能打到 HP 就不打旁边的单位（我方 20→15，农民满血）")
	# 不拦路的单位一律绕开（哪怕就贴在旁边、随时可以打）
	var eng10 := _new_engine([], 20, 20)
	eng10.ai_enabled = true
	eng10.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng10.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng10.current_side = GameEngine.SIDE_OPPONENT
	eng10.run_ai_unit(Vector2i(3, 1))
	var passed := eng10.state.unit_at(Vector2i(4, 1))
	check(eng10.state.hp_self == 15 and passed != null and passed.health == 8,
			"不拦路的单位被绕开：AI 直击 HP（20→15），农民满血 8 没挨打")
	check(eng10.state.unit_at(Vector2i(4, 2)) != null,
			"绕行落点：AI 从 (3,1) 钻进右侧空档 (4,2)")
	# 可攻击范围内只有拦路的单位 → 才开打：三格封死正前方
	var eng11 := _new_engine([], 20, 20)
	eng11.ai_enabled = true
	eng11.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	for col in 3:
		eng11.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
				Vector2i(4, col), GameEngine.SIDE_SELF)
	eng11.current_side = GameEngine.SIDE_OPPONENT
	eng11.run_ai_unit(Vector2i(3, 1))
	var wall := eng11.state.unit_at(Vector2i(4, 1))
	check(eng11.state.hp_self == 20 and wall != null and wall.health == 1,
			"确认挡路才打：三格封死 → 打正前方工事（6-5=1），我方 HP 不变")
	# 墙上留了空档 → 工事就不算拦路 → 钻空档打 HP
	var eng12 := _new_engine([], 20, 20)
	eng12.ai_enabled = true
	eng12.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng12.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	eng12.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	eng12.current_side = GameEngine.SIDE_OPPONENT
	eng12.run_ai_unit(Vector2i(3, 1))
	var f0 := eng12.state.unit_at(Vector2i(4, 0))
	var f2 := eng12.state.unit_at(Vector2i(4, 2))
	check(eng12.state.hp_self == 15 and f0 != null and f0.health == 6
			and f2 != null and f2.health == 6,
			"空档可钻：AI 钻 (4,1) 直击 HP，两侧工事一根汗毛没掉")
	# 整回合收尾 + 双动单位用满两轮：队列靠「横置」清空，谁不横置就会死循环
	var eng13 := _new_engine([], 30, 30)
	eng13.ai_enabled = true
	var captain := _card(9012, "鸭子队长", "盟友", 3, 10, 50, 1, 1)
	captain.actions = 2
	eng13.state.place(captain, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	eng13.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(0, 0), GameEngine.SIDE_OPPONENT)
	eng13.current_side = GameEngine.SIDE_OPPONENT
	var steps := 0
	while not eng13.over and steps < 40:
		var q := eng13.ai_action_queue()
		if q.is_empty():
			break
		eng13.run_ai_unit(q[0])
		steps += 1
	check(steps < 40 and eng13.ai_action_queue().is_empty(),
			"AI 整回合会自行收尾：全部单位横置、不死循环（步数 %d）" % steps)
	var cap_now := eng13.state.unit_at(Vector2i(2, 1))
	check(cap_now != null and cap_now.tapped,
			"双动单位用满两轮：鸭子队长一轮一格，推进到 (2,1) 后横置")
	# 远程单位隔着自家友军也要打墙：鸭子巫师（程 2）与墙之间夹着一只使魔鸭子
	var eng14 := _new_engine([], 30, 30)
	eng14.ai_enabled = true
	eng14.state.place(_card(9008, "鸭子巫师", "盟友", 6, 8, 50, 2, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	eng14.state.place(_card(9009, "使魔鸭子", "盟友", 1, 4, 15, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	for col in 3:
		eng14.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
				Vector2i(3, col), GameEngine.SIDE_SELF)
		eng14.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
				Vector2i(4, col), GameEngine.SIDE_SELF)
	eng14.current_side = GameEngine.SIDE_OPPONENT
	eng14.run_ai_unit(Vector2i(1, 1))
	check(eng14.state.hp_self == 30 and eng14.state.unit_at(Vector2i(3, 1)) == null,
			"两层墙封死：程 2 的巫师隔着友军照样拆墙（(3,1) 被击破），HP 不掉")
	# 移动后若可攻击则必须攻击：落点够不到 HP、但攻击范围内有单位
	# （不拦路）→ 以前会「绕行放弃攻击」站着不动，现在要主动打出来。
	var eng15c := _new_engine([], 20, 20)
	eng15c.ai_enabled = true
	eng15c.state.place(_card(9100, "测试骑士", "盟友", 1, 5, 30, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)   # 程 1 / 速 1：一步到不了 HP
	eng15c.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(3, 1), GameEngine.SIDE_SELF)        # 紧贴落点 (3,0)，不挡路
	eng15c.current_side = GameEngine.SIDE_OPPONENT
	eng15c.run_ai_unit(Vector2i(2, 0))
	var f15c := eng15c.state.unit_at(Vector2i(3, 1))
	check(eng15c.state.hp_self == 20 and f15c != null and f15c.health == 3,
			"移动后若可攻击必打：骑士 (2,0)→(3,0) 落点打农民（8-5=3），HP 不变")
	check(eng15c.state.unit_at(Vector2i(3, 0)) != null,
			"移动后若可攻击必打：骑士推进到 (3,0) 并已在攻击后横置")

	# ---- 积极破局：正前方被自家人堵死、侧列留有空档时，速 1 单位横挪找空档 ----
	# （旧逻辑的距离不算阻挡，三格得分相同 → 原地待命；现在按真实走位距离绕行）
	var engM := _new_engine([], 20, 20)
	engM.ai_enabled = true
	engM.state.place(_card(9101, "测试骑士", "盟友", 1, 5, 30, 1, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	engM.state.place(_card(9102, "测试栅栏", "工事", 1, 0, 10, 1, 0),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	engM.state.place(_card(9102, "测试栅栏", "工事", 1, 0, 10, 1, 0),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)   # (2,2) 留空档
	engM.current_side = GameEngine.SIDE_OPPONENT
	engM.run_ai_unit(Vector2i(1, 1))
	check(engM.state.unit_at(Vector2i(1, 2)) != null
			and engM.state.unit_at(Vector2i(1, 1)) == null,
			"积极破局：正前方被堵 → 横挪到空档列 (1,2)，不原地待命")
	# ---- 积极破局：够不到任何目标也向前推进（绝不原地踏步）----
	var engM2 := _new_engine([], 20, 20)
	engM2.ai_enabled = true
	engM2.state.place(_card(9101, "测试骑士", "盟友", 1, 5, 30, 1, 1),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	engM2.current_side = GameEngine.SIDE_OPPONENT
	engM2.run_ai_unit(Vector2i(0, 1))
	check(engM2.state.unit_at(Vector2i(1, 1)) != null,
			"积极移动：全场没有可攻击目标 → 照样向前推进 (0,1)→(1,1)")

	# ---- 穿透优先：能打死后排残血（溢出漏 HP）时，不打没有穿透的前排 ----
	var engV := _new_engine([], 20, 20)
	engV.ai_enabled = true
	engV.state.place(_card(9103, "测试巨怪", "盟友", 3, 10, 30, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	engV.state.place(_card(8003, "农民", "盟友", 3, 3, 6),
			Vector2i(5, 1), GameEngine.SIDE_SELF)     # 后排 6 血：打死溢出 4 漏 HP
	engV.state.place(_card(8003, "农民", "盟友", 3, 3, 3),
			Vector2i(4, 0), GameEngine.SIDE_SELF)     # 非后排 3 血：好杀但没有穿透
	engV.current_side = GameEngine.SIDE_OPPONENT
	engV.run_ai_unit(Vector2i(4, 1))
	check(engV.state.hp_self == 16,
			"穿透优先：打死后排残血（10-6 溢出 4 漏 HP：20→16，实际 %d）" % engV.state.hp_self)
	check(engV.state.unit_at(Vector2i(5, 1)) == null
			and engV.state.unit_at(Vector2i(4, 0)) != null
			and engV.state.unit_at(Vector2i(4, 0)).health == 3,
			"穿透优先：目标是后排残血，不是更好杀的前排")
	# ---- 穿透优先于打「不在 HP 上的卡」：拦路的低血单位 vs 能穿透的后排残血 ----
	# 旧逻辑只在「拦路目标」里挑血最少的（打前排 3 血农民）；
	# 现在能穿透（打死后排 6 血农民、溢出 4 漏 HP）时先穿透。
	var engV2 := _new_engine([], 20, 20)
	engV2.ai_enabled = true
	engV2.state.place(_card(9103, "测试巨怪", "盟友", 3, 10, 30, 2, 1),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)   # 程 2：够到后排
	engV2.state.place(_card(8003, "农民", "盟友", 3, 3, 3),
			Vector2i(4, 1), GameEngine.SIDE_SELF)       # 拦路、血最少（旧逻辑会打它）
	engV2.state.place(_card(8003, "农民", "盟友", 3, 3, 6),
			Vector2i(5, 1), GameEngine.SIDE_SELF)       # 后排 6 血：打死溢出 4 漏 HP
	engV2.state.place(_card(8001, "木栅栏", "工事", 2, 0, 20),
			Vector2i(5, 2), GameEngine.SIDE_SELF)       # 占住 HP 格（打不死）
	engV2.state.place(_card(8001, "木栅栏", "工事", 2, 0, 20),
			Vector2i(3, 1), GameEngine.SIDE_SELF)       # 堵绕行路，逼出「拦路」判定
	engV2.current_side = GameEngine.SIDE_OPPONENT
	engV2.run_ai_unit(Vector2i(4, 2))
	var front_v2 := engV2.state.unit_at(Vector2i(4, 1))
	check(engV2.state.hp_self == 16 and engV2.state.unit_at(Vector2i(5, 1)) == null
			and front_v2 != null and front_v2.health == 3,
			"穿透优先：打死后排残血漏 HP（20→16，实际 %d），不打没穿透的前排低血" % engV2.state.hp_self)

	# ---- 需求 B：不能移动也不能推进时，只要身边有敌人就必须攻击（不能原地空过）----
	# B1：工事（移速 0）旁边贴着一个「绕得过去」的玩家单位（不在通往 HP 的最短路上）。
	# 原逻辑会判定 wall_depth<=0 → 不攻击、原地横置；现要求它仍然打出来。
	var engB1 := _new_engine([], 20, 20)
	engB1.ai_enabled = true
	engB1.state.place(_card(9002, "箭塔", "工事", 1, 5, 30, 1, 0),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)   # 工事：移速 0、力量 5
	engB1.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(2, 2), GameEngine.SIDE_SELF)        # 紧贴 (2,2)，但不在最短路上
	engB1.current_side = GameEngine.SIDE_OPPONENT
	engB1.run_ai_unit(Vector2i(2, 1))
	var bp1 := engB1.state.unit_at(Vector2i(2, 2))
	check(engB1.state.hp_self == 20 and bp1 != null and bp1.health == 3,
			"需求B：工事不能移动但旁边有敌人 → 仍攻击（农民 8-5=3），HP 不掉")
	check(engB1.state.unit_at(Vector2i(2, 1)) != null
			and engB1.state.unit_at(Vector2i(2, 1)).tapped,
			"需求B：工事攻击后已横置")

	# B2：移速 0 但非工事的单位，同样不能空过（与工事共用同一分支）。
	var engB2 := _new_engine([], 20, 20)
	engB2.ai_enabled = true
	engB2.state.place(_card(9003, "石像", "盟友", 1, 4, 30, 1, 0),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)   # 移速 0、非工事、力量 4
	engB2.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(2, 2), GameEngine.SIDE_SELF)
	engB2.current_side = GameEngine.SIDE_OPPONENT
	engB2.run_ai_unit(Vector2i(2, 1))
	var bp2 := engB2.state.unit_at(Vector2i(2, 2))
	check(engB2.state.hp_self == 20 and bp2 != null and bp2.health == 4,
			"需求B：移速 0 非工事单位身边有敌人 → 仍攻击（农民 8-4=4）")

	# B3：能走但「任何一步都到不了更好位置」（被玩家后排堵死直击 HP 的路），
	# 即 _ai_best_step 返回 null（dst==null）的分支，只要有可攻击目标也必须打。
	var engB3 := _new_engine([], 20, 20)
	engB3.ai_enabled = true
	engB3.state.place(_card(9004, "前锋", "盟友", 1, 5, 30, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 速 1、力量 5，紧贴我方后排
	engB3.state.place(_card(8003, "农民A", "盟友", 3, 3, 8), Vector2i(5, 0), GameEngine.SIDE_SELF)
	engB3.state.place(_card(8003, "农民B", "盟友", 3, 3, 8), Vector2i(5, 1), GameEngine.SIDE_SELF)
	engB3.state.place(_card(8003, "农民C", "盟友", 3, 3, 8), Vector2i(5, 2), GameEngine.SIDE_SELF)
	engB3.current_side = GameEngine.SIDE_OPPONENT
	engB3.run_ai_unit(Vector2i(4, 1))
	var bp3 := engB3.state.unit_at(Vector2i(5, 1))
	check(engB3.state.hp_self == 20 and bp3 != null and bp3.health == 3,
			"需求B：无路可走（dst==null）但身边有敌人 → 仍攻击（农民B 8-5=3），HP 不掉")

	# ---- R61：移动后「不挡路」的敌人也必须攻击（横向移动 / 穿越半场落空修复）----
	# 敌人 (2,1) 推进到 (3,1)：农民在 (3,0) 贴着、但侧路畅通（wall_depth=0，
	# 不在通往 HP 的最短路上）。旧的挑剔逻辑移动后对它视而不见 → 不攻击也不横置。
	var engR61 := _new_engine([], 20, 20)
	engR61.ai_enabled = true
	engR61.state.place(_card(9004, "前锋", "盟友", 1, 5, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	engR61.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	engR61.current_side = GameEngine.SIDE_OPPONENT
	engR61.run_ai_unit(Vector2i(2, 1))
	var r61_farmer := engR61.state.unit_at(Vector2i(3, 0))
	check(r61_farmer != null and r61_farmer.health == 3,
			"R61：移动后旁边有「不挡路」的敌人 → 仍攻击（农民 8-5=3）")
	var r61_attacker := engR61.state.unit_at(Vector2i(3, 1))
	check(r61_attacker != null and r61_attacker.tapped,
			"R61：移动+攻击后已横置（不再原地空站浪费攻击权）")

	# R61b（R74 已改写）：原用例是「AI 射程内只有陷阱 → 不主动撞上去白吃惩罚」。
	# 场地卡不是单位之后，**这个场景整个不存在了**：场地不在 attack_targets 里，
	# 也就不会被当成「可打的目标」，更不会被攻击。
	# 现在锁这条新事实：射程内**只有场地**时，AI 应当照常推进/待命，场地不参与攻击判定。
	var engR61b := _new_engine([], 20, 20)
	engR61b.ai_enabled = true
	var r61b_unit: Placement = engR61b.state.place(_card(9004, "前锋", "盟友", 1, 5, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	engR61b.state.set_field(CardData.from_dict(repo.get_card(8011).to_dict()),
			Vector2i(3, 0), GameEngine.SIDE_SELF)   # 爆炸场地（不是单位）
	engR61b.current_side = GameEngine.SIDE_OPPONENT
	var r61b_targets := engR61b.attack_targets(Vector2i(2, 1), GameEngine.SIDE_OPPONENT,
			r61b_unit.card)
	check(not r61b_targets.has(Vector2i(3, 0)),
			"R74 场地不是攻击目标：射程内有场地时 attack_targets 不含它（AI 不会去「打」场地）")
	engR61b.run_ai_unit(Vector2i(2, 1))
	check(engR61b.state.field_at(Vector2i(3, 0)) != null and r61b_unit.health == 30,
			"R74 场地不参与战斗：AI 行动后场地完好（没被触发、也没被打掉）")

	# ---- R61：远程开路 —— 射程 ≥ 2 的单位先出手为前排友军清障 ----
	# 巫师 (1,1) 射程2力量8 + 使魔 (2,1)；我方农民 (3,1) 血 8 挡在使魔面前。
	# 默认队首是使魔（靠前）；巫师能一击打死挡路卡 → 提到队首先出手。
	var engR61c := _new_engine([], 20, 20)
	engR61c.ai_enabled = true
	engR61c.state.place(_card(9008, "鸭子巫师", "盟友", 5, 8, 50, 2, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	engR61c.state.place(_card(9009, "使魔鸭子", "盟友", 3, 4, 15, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	engR61c.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	engR61c.current_side = GameEngine.SIDE_OPPONENT
	var q61c := engR61c.ai_action_queue()
	check(q61c.size() == 2 and q61c[0] == Vector2i(1, 1) and q61c[1] == Vector2i(2, 1),
			"R61 开路：巫师能一击清障 → 先出手（队列 %s）" % str(q61c))
	var r61_wiz: Placement = engR61c.state.unit_at(Vector2i(1, 1))
	check(engR61c._clear_shot_target(Vector2i(1, 1), r61_wiz) == Vector2i(3, 1),
			"R61 开路：_clear_shot_target 锁定挡路的农民")
	engR61c.run_ai_unit(Vector2i(1, 1))
	check(engR61c.state.unit_at(Vector2i(3, 1)) == null,
			"R61 开路：巫师优先打掉挡路卡（农民 8 血被 8 攻一击清除）")

	# R61d：挡路卡打不死（9 > 8）→ 维持默认「靠前的先行动」，巫师不抢队首。
	var engR61d := _new_engine([], 20, 20)
	engR61d.ai_enabled = true
	engR61d.state.place(_card(9008, "鸭子巫师", "盟友", 5, 8, 50, 2, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	engR61d.state.place(_card(9009, "使魔鸭子", "盟友", 3, 4, 15, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	engR61d.state.place(_card(8003, "农民", "盟友", 3, 3, 9, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	engR61d.current_side = GameEngine.SIDE_OPPONENT
	var q61d := engR61d.ai_action_queue()
	check(q61d.size() == 2 and q61d[0] == Vector2i(2, 1) and q61d[1] == Vector2i(1, 1),
			"R61 开路：打不死挡路卡（9>8）→ 默认前排先行动")
	# R61e：射程 1 的单位即使能清障也不抢队首（开路判断是射程 ≥ 2 专属）。
	var engR61e := _new_engine([], 20, 20)
	engR61e.ai_enabled = true
	engR61e.state.place(_card(9010, "鸭子突击队", "盟友", 2, 8, 30, 1, 2),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)   # 力量 8 但射程只有 1
	engR61e.state.place(_card(9009, "使魔鸭子", "盟友", 3, 4, 15, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	engR61e.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_SELF)   # 贴着突击队斜前方（射程1打不到）
	engR61e.current_side = GameEngine.SIDE_OPPONENT
	var q61e := engR61e.ai_action_queue()
	check(q61e.size() == 2 and q61e[0] == Vector2i(2, 1),
			"R61 开路：射程 1 的单位不触发开路插队")

	# ---- AI 队列：更前方的敌人先行动 ----
	# 敌人 A 在行 2（靠后），敌人 B 在行 4（更靠近我方）→ 队列应先取 B。
	var eng16f := _new_engine([], 20, 20)
	eng16f.ai_enabled = true
	var back_mon := _card(1053, "后方怪", "盟友", 1, 1, 2, 1, 1)
	var front_mon := _card(1054, "前方怪", "盟友", 1, 1, 2, 1, 1)
	eng16f.state.place(back_mon, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng16f.state.place(front_mon, Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng16f.current_side = GameEngine.SIDE_OPPONENT
	var q16f := eng16f.ai_action_queue()
	check(q16f.size() == 2 and q16f[0] == Vector2i(4, 1) and q16f[1] == Vector2i(2, 1),
			"AI 队列前方优先：先取行 4 的前方怪，再取行 2 的后方怪")
	check(eng16f.state.unit_at(q16f[0]).card == front_mon,
			"AI 队列前方优先：队首确实是更前方的敌人")

	# ---- HP 前的单位挡刀 + 溢出伤害 ----
	# 站在对方后排（HP 前面那一行）的单位挡住了 HP 格：那一格不能再被越过直击。
	var eng15 := _new_engine([], 20, 20)
	eng15.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng15.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
			Vector2i(5, 1), GameEngine.SIDE_SELF)
	var ht15 := eng15.hp_targets(Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(not ht15.has(Vector2i(5, 1)),
			"HP 格被单位占住：不能越过它直击 HP（得先解决挡路的）")
	check(eng15.hp_targets(Vector2i(4, 0), GameEngine.SIDE_OPPONENT).is_empty(),
			"没有单位的格不能作为攻击起点")
	var eng15b := _new_engine([], 20, 20)
	eng15b.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(eng15b.hp_targets(Vector2i(4, 1), GameEngine.SIDE_OPPONENT).has(Vector2i(5, 1)),
			"HP 格空着：照常可以直击 HP")
	# 打穿挡在 HP 前的单位 → 多出来的伤害漏到玩家 HP
	var eng16 := _new_engine([], 20, 20)
	eng16.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng16.state.place(_card(8003, "农民", "盟友", 3, 3, 3, 1, 1),
			Vector2i(5, 1), GameEngine.SIDE_SELF)         # 只有 3 血
	eng16.attack(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(eng16.state.hp_self == 18 and eng16.state.unit_at(Vector2i(5, 1)) == null,
			"溢出伤害：力 5 打死 3 血单位 → 多出的 2 点漏到玩家 HP（20 → 18）")
	# 不在 HP 前的单位：打穿也不溢出
	var eng17 := _new_engine([], 20, 20)
	eng17.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng17.state.place(_card(8003, "农民", "盟友", 3, 3, 3, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng17.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(eng17.state.hp_self == 20 and eng17.state.unit_at(Vector2i(4, 1)) == null,
			"非 HP 前的单位：打穿也不溢出（玩家 HP 保持 20）")

	# ---- 爆炎鸭（9020）：亡语对曼哈顿距离 1 的四格各 10 伤（全部走统一 HP 格规则） ----
	var blaze := repo.get_card(9020)
	check(blaze != null and blaze.card_name == "爆炎鸭" and blaze.power == 5
			and blaze.health == 3 and blaze.attack_range == 1
			and blaze.move_speed == 1 and blaze.rarity == 4,
			"爆炎鸭：怪物 5 力 / 3 血 / 程1 / 速1")
	# 1) 相邻三格都被炸（不分敌我）；距离 2 的毫发无伤；中间行没有 HP 格 → 不掉玩家 HP
	var eng_bz := _new_engine([], 20, 20)
	eng_bz.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_bz.state.place(_card(1053, "骷髅兵", "盟友", 1, 1, 3), Vector2i(2, 0), GameEngine.SIDE_SELF)
	eng_bz.state.place(_card(1053, "骷髅兵", "盟友", 1, 2, 3), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	eng_bz.state.place(_card(1055, "骷髅兵", "盟友", 1, 3, 10), Vector2i(3, 1), GameEngine.SIDE_SELF)
	eng_bz.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2), Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng_bz._destroy(Vector2i(2, 1))   # 死亡触发亡语（任何死因都走这里）
	check(eng_bz.state.unit_at(Vector2i(2, 0)) == null
			and eng_bz.state.unit_at(Vector2i(2, 2)) == null,
			"爆炎鸭亡语：相邻的 3 血单位被炸死（不分敌我）")
	check(eng_bz.state.unit_at(Vector2i(3, 1)) == null,
			"爆炎鸭亡语：相邻的 10 血单位正好被 10 点炸死")
	check(eng_bz.state.unit_at(Vector2i(4, 1)) != null,
			"爆炎鸭亡语：曼哈顿距离 2 的单位不受影响")
	check(eng_bz.state.hp_self == 20 and eng_bz.state.hp_opponent == 20,
			"爆炎鸭亡语：中间行不是 HP 格 → 玩家 HP 都不掉")
	# 2) 紧贴我方后排 → 空着的 HP 格直接被炸 10 点
	var eng_bz2 := _new_engine([], 20, 20)
	eng_bz2.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng_bz2._destroy(Vector2i(4, 1))
	check(eng_bz2.state.hp_self == 10,
			"爆炎鸭亡语：盖到空的我方后排（HP 格）→ 直接打 HP（20 → 10）")
	# 3) 我方单位站在自己后排挡刀 → 先打单位，打穿的部分溢出到 HP
	var eng_bz3 := _new_engine([], 20, 20)
	eng_bz3.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	eng_bz3.state.place(_card(8003, "农民", "盟友", 3, 3, 4, 1, 1),
			Vector2i(5, 1), GameEngine.SIDE_SELF)   # 4 血，站在 HP 格上挡刀
	eng_bz3._destroy(Vector2i(4, 1))
	check(eng_bz3.state.unit_at(Vector2i(5, 1)) == null and eng_bz3.state.hp_self == 14,
			"爆炎鸭亡语：先打挡刀单位，多出的 6 点溢出到 HP（20 → 14）")
	# 4) 连环爆炸：相邻的爆炎鸭被炸死也会继续炸（不卡死、不重复结算）
	var eng_bz4 := _new_engine([], 20, 20)
	eng_bz4.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	eng_bz4.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_bz4.state.place(_card(1053, "骷髅兵", "盟友", 1, 1, 3), Vector2i(2, 2), GameEngine.SIDE_SELF)
	eng_bz4._destroy(Vector2i(2, 0))
	check(eng_bz4.state.unit_at(Vector2i(2, 1)) == null
			and eng_bz4.state.unit_at(Vector2i(2, 2)) == null,
			"连环爆炸：相邻爆炎鸭被炸死会接着炸，骷髅兵一并清掉")
	# 5) 规则统一到按格结算：火球术盖到空的后排 HP 格 → 直接打 HP
	var eng_fb := _new_engine(_single_deck(_card(9007, "火球术", "技能", 4, 0, 0)), 20, 40, -1, false)
	eng_fb.start_game()
	eng_fb.use_spell(0, Vector2i(1, 1))    # 中心 (1,1)：半径 1 覆盖对方后排空位 (0,1)
	check(eng_fb.state.hp_opponent == 20,
			"火球术盖到空着的对方后排（HP 格）→ 20 伤直击 HP（40 → 20）")
	# 6) 火球术打穿站在后排挡刀的单位 → 溢出漏到 HP
	var eng_fb2 := _new_engine(_single_deck(_card(9007, "火球术", "技能", 4, 0, 0)), 20, 40, -1, false)
	eng_fb2.start_game()
	eng_fb2.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 5, 1, 2),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)   # 5 血挡刀
	eng_fb2.use_spell(0, Vector2i(1, 1))
	check(eng_fb2.state.unit_at(Vector2i(0, 1)) == null and eng_fb2.state.hp_opponent == 25,
			"火球术打穿后排挡刀单位：溢出 15 点漏到对方 HP（40 → 25）")
	# 7) 单体型效果伤害同样走统一击杀收尾（火焰箭打死挡刀单位也溢出）
	var eng_ff := _new_engine(_single_deck(_card(9003, "火焰箭", "技能", 3, 0, 0)), 20, 40, -1, false)
	eng_ff.start_game()
	eng_ff.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 5, 1, 2),
			Vector2i(0, 2), GameEngine.SIDE_OPPONENT)
	eng_ff.use_spell(0, Vector2i(0, 2))
	check(eng_ff.state.unit_at(Vector2i(0, 2)) == null and eng_ff.state.hp_opponent == 28,
			"火焰箭（17 伤）打死后排挡刀单位：溢出 12 点漏到对方 HP（40 → 28）")
	# 9) AOE 对同一方的 HP 最多结算一次：火球盖住 3 个空后排格只打 1 次
	var eng_fb3 := _new_engine(_single_deck(_card(9007, "火球术", "技能", 4, 0, 0)), 20, 100, -1, false)
	eng_fb3.start_game()
	eng_fb3.use_spell(0, Vector2i(0, 1))   # 中心在对方后排：覆盖 (0,0)/(0,1)/(0,2) 三个空格
	check(eng_fb3.state.hp_opponent == 80,
			"火球术盖住 3 个空 HP 格：敌方 HP 只掉一次 20（100 → 80，不是 40）")
	# 8) 真实击杀路径（普攻打死）同样触发亡语：连带炸伤攻击者、炸死旁边的我方单位
	var eng_bz5 := _new_engine([], 20, 20)
	var bz_attacker := _card(8003, "农民", "盟友", 3, 5, 30, 1, 1)
	eng_bz5.state.place(bz_attacker, Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng_bz5.state.place(_card(9020, "爆炎鸭", "盟友", 4, 5, 3, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	eng_bz5.state.place(_card(1053, "骷髅兵", "盟友", 1, 1, 3), Vector2i(2, 1), GameEngine.SIDE_SELF)
	eng_bz5.attack(Vector2i(3, 0), Vector2i(2, 0), GameEngine.SIDE_SELF)
	check(eng_bz5.state.unit_at(Vector2i(2, 0)) == null
			and eng_bz5.state.unit_at(Vector2i(2, 1)) == null,
			"普攻打死爆炎鸭：照样触发亡语，炸死旁边的 3 血我方单位")
	check(eng_bz5.state.unit_at(Vector2i(3, 0)) != null
			and eng_bz5.state.unit_at(Vector2i(3, 0)).health == 20,
			"爆炎鸭亡语不分敌我：攻击者（30 血）也被炸掉 10 点")
	# HP 前三格全被占 → AI 拆掉挡路的单位（不是原地发呆）
	var eng18 := _new_engine([], 20, 20)
	eng18.ai_enabled = true
	eng18.state.place(_card(9001, "鸭子骑士", "盟友", 1, 5, 30, 1, 2),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	for col in 3:
		eng18.state.place(_card(8003, "农民", "盟友", 3, 3, 8, 1, 1),
				Vector2i(5, col), GameEngine.SIDE_SELF)
	eng18.current_side = GameEngine.SIDE_OPPONENT
	var hp18 := eng18.state.hp_self
	eng18.run_ai_unit(Vector2i(3, 1))
	var mid18 := eng18.state.unit_at(Vector2i(5, 1))
	check(eng18.state.hp_self == hp18 and mid18 != null and mid18.health == 3,
			"HP 前三格全被占：AI 推进后拆正前方挡路单位（8-5=3），没发呆也没倒退")
	# 多单位互相挡路（使魔鸭群）：几回合内应当挤到 HP 前的第 4 行，绝不倒退
	var eng19 := _new_engine([], 40, 40)
	eng19.ai_enabled = true
	var swarm := [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(1, 0), Vector2i(1, 2)]
	for scell: Vector2i in swarm:
		eng19.state.place(_card(9009, "使魔鸭子", "盟友", 1, 4, 15, 1, 1),
				scell, GameEngine.SIDE_OPPONENT)
	eng19.current_side = GameEngine.SIDE_OPPONENT
	var sum_before := 0
	for scell2: Vector2i in swarm:
		sum_before += scell2.x
	var reached_front := false
	var sum_after := sum_before
	for rnd in 4:
		var guard := 0
		while guard < 30:
			var q19 := eng19.ai_action_queue()
			if q19.is_empty():
				break
			eng19.run_ai_unit(q19[0])
			guard += 1
		sum_after = 0
		for scell3: Vector2i in eng19.state.board.keys():
			var pl3: Placement = eng19.state.board[scell3]
			if pl3.owner != GameEngine.SIDE_OPPONENT:
				continue
			sum_after += scell3.x
			if scell3.x >= 4:
				reached_front = true
		if reached_front or eng19.over:
			break
		# 模拟下一回合：敌方单位重新获得行动权
		for scell4: Vector2i in eng19.state.board.keys():
			var pl4: Placement = eng19.state.board[scell4]
			if pl4.owner == GameEngine.SIDE_OPPONENT:
				pl4.tapped = false
				pl4.moved = false
				pl4.acts_left = 1
	check(sum_after >= sum_before,
			"使魔鸭群：整回合推进不倒退（x 总和 %d → %d）" % [sum_before, sum_after])
	check(reached_front or eng19.over,
			"使魔鸭群：几回合内挤到 HP 前第 4 行（不再卡住绕圈）")

	# ---- RunState：玩家最大/当前生命 + 休息事件（把档位钉在 2「困难」= 25%）----
	RunState.set_difficulty(2)
	RunState.reset(50)
	RunState.take_damage(13)
	check(RunState.hp == 37 and RunState.max_hp == 50, "受伤扣当前生命，不动最大生命（37/50）")
	RunState.heal(100)
	check(RunState.hp == 50, "回复不超过最大生命")
	RunState.take_damage(20)
	var g := RunState.rest()
	check(g == 13, "休息恢复 25% 最大生命（向上取整，50×25%→13）〔2 档〕")
	check(RunState.hp == 43, "休息后 43/50")
	RunState.take_damage(0)
	var g2 := RunState.rest()
	check(g2 == 7 and RunState.hp == 50, "再休息按需回复并封顶（缺 7 回 7 → 50/50）")
	RunState.reset(30)
	check(RunState.hp == 30 and RunState.max_hp == 30, "reset 可指定新最大生命")
	RunState.take_damage(5)
	RunState.reset()
	RunState.set_difficulty(0)   # 复位成默认档（0 宽松）

	# ---- 挣扎事件（数据面）：失去 21 生命 + 金属龙加入卡组 ----
	RunState.reset(50)
	var deck_before_struggle := RunState.deck_ids.size()
	var metal_struggle := repo.get_card(9018)
	check(metal_struggle != null and metal_struggle.rarity == 5
			and metal_struggle.rarity_name() == "事件"
			and metal_struggle.cost == 5 and metal_struggle.power == 6
			and metal_struggle.health == 21,
			"金属龙：事件卡 5 费 6/21（稀有度 5 = 事件）")
	check(not repo.reward_pool().any(func(c: CardData): return c.id == 9018),
			"金属龙不可通过奖励获取（事件卡不进奖励池）")
	RunState.take_damage(21)
	check(RunState.hp == 29, "挣扎：失去 21 点生命（50 → 29）")
	RunState.add_card(9018)
	check(RunState.deck_ids.size() == deck_before_struggle + 1
			and RunState.deck_ids.back() == 9018, "挣扎：金属龙加入卡组")
	RunState.reset()
	# 事件节点遭遇怪物 → next_level 按普通战斗选关
	var ev_lvl := RunState.next_level({"type": "event", "name": "事件"})
	check(not ev_lvl.is_empty() and int(ev_lvl.get("tier", -1)) in [
			GameLevels.TIER_NORMAL_EASY, GameLevels.TIER_NORMAL_HARD],
			"事件节点遭遇怪物：next_level 按普通战斗难度选关")
	RunState.reset()
	check(RunState.hp == 50 and RunState.max_hp == 50, "默认 reset 回满 50/50")

	# ---- 鸭子巫师：回合开始召唤使魔鸭子并横置 ----
	var eng_dw := _new_engine([], 20, 30)
	eng_dw.state.place(_card(9008, "鸭子巫师", "盟友", 6, 8, 50, 2, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	eng_dw.start_game()
	eng_dw.end_turn()   # 进入对手回合 → 巫师触发召唤
	var wiz := eng_dw.state.unit_at(Vector2i(1, 1))
	var fam := eng_dw.state.unit_at(Vector2i(1, 0))
	check(fam != null and fam.card.id == 9009, "回合开始召唤使魔鸭子（相邻空格）")
	check(fam == null or (fam.card.power == 4 and fam.card.health == 15
			and fam.card.attack_range == 1 and fam.card.move_speed == 1),
			"使魔鸭子 4力/15生/程1/速1")
	check(wiz != null and wiz.tapped, "召唤后巫师横置（本回合不再行动）")
	var enemy_cnt := 0
	for q: Placement in eng_dw.state.board.values():
		if q.owner == GameEngine.SIDE_OPPONENT:
			enemy_cnt += 1
	check(enemy_cnt == 2, "召唤后场上共 2 个敌方单位")
	eng_dw.end_turn()   # 回到我方（巫师横置状态被清除在对手下回合开始时）
	eng_dw.end_turn()   # 又到对手回合：场上已有使魔 → 不再召唤
	var fams := 0
	for q: Placement in eng_dw.state.board.values():
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9009:
			fams += 1
	check(fams == 1, "场上已有使魔鸭子 → 不重复召唤")
	var wiz2 := eng_dw.state.unit_at(Vector2i(1, 1))
	check(wiz2 != null and not wiz2.tapped, "未召唤时巫师不横置（可正常行动）")
	# 包围满时召唤失败 → 巫师不横置
	var eng_dw2 := _new_engine([], 20, 30)
	eng_dw2.state.place(_card(9008, "鸭子巫师", "盟友", 6, 8, 50, 2, 1),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	for c: Vector2i in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2),
			Vector2i(0, 0), Vector2i(0, 2), Vector2i(2, 0), Vector2i(2, 2)]:
		eng_dw2.state.place(_card(1053, "骷髅兵", "盟友", 1, 1, 2), c, GameEngine.SIDE_OPPONENT)
	eng_dw2.start_game()
	eng_dw2.end_turn()
	check(eng_dw2.state.board.size() == 9, "周围满员 → 不召唤")
	var wiz3 := eng_dw2.state.unit_at(Vector2i(1, 1))
	check(wiz3 != null and not wiz3.tapped, "召唤失败时巫师不横置")

	# ---- 鸭子队长：8/50 程1 速1，一回合行动两次 ----
	var cap := repo.get_card(9012)
	check(cap != null and cap.card_name == "鸭子队长" and cap.power == 8
			and cap.health == 50 and cap.attack_range == 1 and cap.move_speed == 1
			and cap.actions == 2 and cap.rarity == 4,
			"鸭子队长：怪物 8/50 程1 速1 行动2次")
	var lvl3: Dictionary = _level_named("鸭子队长登场")
	var eus: Array = lvl3["enemy_units"]
	check(str(lvl3["name"]) == "鸭子队长登场"
			and int(lvl3["tier"]) == GameLevels.TIER_ELITE_EASY
			and eus.size() == 3
			and int(eus[0][0]) == 9012 and eus[0][6] == Vector2i(0, 1)
			and int(eus[1][0]) == 9001 and eus[1][6] == Vector2i(1, 0)
			and int(eus[2][0]) == 9001 and eus[2][6] == Vector2i(1, 2),
			"精英简单关：后排中间队长 + 中排左右各一只骑士（2026-10-01 由前排挪到中排）")
	var eng_c := _new_engine([], 20, 40)
	var capc := _card(9012, "鸭子队长", "盟友", 8, 10, 50, 1, 1)
	capc.actions = 2
	eng_c.state.place(capc, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_c.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	eng_c.start_game()
	check(eng_c.state.unit_at(Vector2i(2, 1)).acts_left == 2,
			"队长上场：本回合 2 轮行动")
	eng_c.current_side = GameEngine.SIDE_OPPONENT
	eng_c.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var cap_p := eng_c.state.unit_at(Vector2i(2, 1))
	check(cap_p != null and cap_p.health == 50 and not cap_p.tapped
			and cap_p.acts_left == 1,
			"第一轮攻击（不受反击 50 血）：不横置，立即获得新一轮（剩 1 轮）")
	eng_c.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	eng_c.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var cap_p2 := eng_c.state.unit_at(Vector2i(2, 1))
	check(cap_p2 != null and cap_p2.health == 50 and cap_p2.tapped
			and cap_p2.acts_left == 1,
			"第二轮攻击后横置（本回合行动完毕）")
	# 新回合重置：2 轮行动恢复
	eng_c.end_turn()
	eng_c.end_turn()
	check(eng_c.state.unit_at(Vector2i(2, 1)).acts_left == 2
			and not eng_c.state.unit_at(Vector2i(2, 1)).tapped,
			"新回合：队长恢复 2 轮行动")
	# 普通单位不受影响：行动一次即横置
	var eng_c2 := _new_engine([], 20, 40)
	var norm_k := _card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2)
	eng_c2.state.place(norm_k, Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	eng_c2.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	eng_c2.current_side = GameEngine.SIDE_OPPONENT
	eng_c2.attack(Vector2i(2, 0), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var norm_p := eng_c2.state.unit_at(Vector2i(2, 0))
	check(norm_p != null and norm_p.tapped and norm_p.acts_left == 1,
			"普通单位行动一次即横置（actions=1 不受影响）")

	# ---- 鸭子之力：敌方效果卡，成长光环（每回合 +1，上限 +5） ----
	var might := repo.get_card(9013)
	check(might != null and might.card_name == "鸭子之力" and might.is_effect()
			and might.rarity == 4 and might.value == 1 and might.traits.has("成长"),
			"鸭子之力：敌方效果卡（怪物稀有度，成长 +1/回合）")
	var lvl4: Dictionary = _level_named("骑士军团")
	var eus4: Array = lvl4["enemy_units"]
	check(str(lvl4["name"]) == "骑士军团"
			and int(lvl4["tier"]) == GameLevels.TIER_ELITE_HARD
			and eus4.size() == 6
			and int(eus4[0][6].x) == 0 and int(eus4[3][6].x) == 2
			and (lvl4["enemy_effects"] as Array) == [9013],
			"精英困难关：骑士×6（后排 3 + 前排 3）+ 敌方效果鸭子之力")
	var eng_g := _new_engine([], 20, 40)
	var grow := _card(9013, "鸭子之力", "效果", 0, 0, 0, 0, 0)
	grow.traits = ["成长"]
	grow.value = 1
	eng_g.state.enemy_effects.append(grow)
	eng_g.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_g.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng_g.start_game()
	eng_g.end_turn()   # 对手第 1 回合开始 → 光标 +1
	var gk1 := eng_g.state.unit_at(Vector2i(2, 1))
	check(gk1 != null and gk1.atk_buff == 1 and gk1.effective_power() == 6,
			"鸭子之力第 1 回合：骑士力量 5+1=6（实际 %d）"
			% (gk1.effective_power() if gk1 != null else -1))
	var gf := eng_g.state.unit_at(Vector2i(4, 1))
	check(gf != null and gf.atk_buff == 0 and gf.effective_power() == 3,
			"成长光环只作用于所属阵营（我方农民不受影响）")
	for i in 7:
		eng_g.end_turn()
		eng_g.end_turn()
	var gk2 := eng_g.state.unit_at(Vector2i(2, 1))
	check(gk2 != null and gk2.atk_buff == 5 and gk2.effective_power() == 10,
			"成长上限：累计 +5 后不再增长（力量 5+5=10）")
	check(eng_g.state.enemy_effects.size() == 1
			and eng_g.state.enemy_effects[0].id == 9013,
			"敌方效果区：鸭子之力持续生效中")

	# ---- 远古虚骨龙：Boss 12/100 程2 速2，回合开始吐息 ----
	var dragon := repo.get_card(9014)
	check(dragon != null and dragon.card_name == "远古虚骨龙"
			and dragon.power == 12 and dragon.health == 100
			and dragon.attack_range == 2 and dragon.move_speed == 2
			and dragon.rarity == 4,
			"远古虚骨龙：怪物 12/100 程2 速2")
	var lvl5: Dictionary = _level_named("远古虚骨龙")
	var eus5: Array = lvl5["enemy_units"]
	check(str(lvl5["name"]) == "远古虚骨龙"
			and int(lvl5["tier"]) == GameLevels.TIER_BOSS
			and eus5.size() == 1
			and int(eus5[0][0]) == 9014 and eus5[0][6] == Vector2i(0, 1)
			and (lvl5["enemy_effects"] as Array) == [9015],
			"Boss 关：后排中间虚骨龙 + 敌方效果鸭子号角")
	# 吐息：打随机敌方单位（单一目标 → 结果确定）
	var eng_db := _new_engine([], 20, 40)
	eng_db.state.place(_card(9014, "远古虚骨龙", "盟友", 9, 12, 100, 2, 2),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	eng_db.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng_db.start_game()
	eng_db.end_turn()   # 对手回合开始 → 吐息
	var dtarget := eng_db.state.unit_at(Vector2i(4, 1))
	check(dtarget != null and dtarget.health == 3,
			"龙息：农民 8-5=3（实际 %d）" % (dtarget.health if dtarget != null else -1))
	# 吐息击杀 → 单位进弃牌区；无单位时打玩家 HP
	var eng_db2 := _new_engine([], 25, 40)
	eng_db2.state.place(_card(9014, "远古虚骨龙", "盟友", 9, 12, 100, 2, 2),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	eng_db2.state.place(_card(1053, "骷髅兵", "盟友", 1, 1, 2),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng_db2.start_game()
	eng_db2.end_turn()
	check(eng_db2.state.unit_at(Vector2i(3, 0)) == null
			and eng_db2.state.discard.any(func(c: CardData): return c.id == 1053),
			"龙息击杀 2 血骷髅兵（进弃牌区）")
	eng_db2.end_turn()   # 回到我方（场上无我方单位）
	eng_db2.state.hp_self = 20
	eng_db2.end_turn()   # 又到对手回合：没有我方单位 → 打玩家 HP
	check(eng_db2.state.hp_self == 15,
			"无我方单位时龙息打玩家 HP：20-5=15（实际 %d）" % eng_db2.state.hp_self)

	# ---- 鸭子号角：每 3 个对手回合召唤一只鸭子骑士 ----
	var horn := repo.get_card(9015)
	check(horn != null and horn.card_name == "鸭子号角" and horn.is_effect()
			and horn.rarity == 4 and horn.value == 3 and horn.traits.has("召唤"),
			"鸭子号角：敌方效果卡（召唤，每 3 回合）")
	var eng_h := _new_engine([], 20, 40)
	var horn_c := _card(9015, "鸭子号角", "效果", 0, 0, 0, 0, 0)
	horn_c.traits = ["召唤"]
	horn_c.value = 3
	eng_h.state.enemy_effects.append(horn_c)
	eng_h.start_game()
	var count_knights := func() -> int:
		var n := 0
		for q: Placement in eng_h.state.board.values():
			if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9001:
				n += 1
		return n
	for i in 4:
		eng_h.end_turn()   # 一去一回 = 对手第 1、2 回合：不召唤
	check(count_knights.call() == 0, "前 2 个对手回合：不召唤")
	for i in 2:
		eng_h.end_turn()   # 对手第 3 回合：召唤
	check(count_knights.call() == 1, "第 3 个对手回合：召唤第 1 只鸭子骑士")
	for i in 6:
		eng_h.end_turn()   # 对手第 4、5、6 回合
	check(count_knights.call() == 2, "第 6 个对手回合：召唤第 2 只（每 3 回合一次）")
	var summoned := false
	for q: Placement in eng_h.state.board.values():
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9001:
			var cell_row: int = -1
			for cc: Vector2i in eng_h.state.board:
				if eng_h.state.board[cc] == q:
					cell_row = cc.x
			summoned = summoned or (cell_row >= 0 and cell_row < 3)
	check(summoned, "召唤的骑士落在敌方半场（前 3 行）")

	# ---- 削弱：下回合攻击力 -9，回合结束恢复 ----
	var eng_de := _new_engine([], 20, 30)
	var foe := _card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2)
	eng_de.state.place(foe, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_de.start_game()
	eng_de.state.hand.append(_card(9010, "削弱", "技能", 1, 0, 0))
	eng_de.use_spell(eng_de.state.hand.size() - 1, Vector2i(2, 1))
	var weakened := eng_de.state.unit_at(Vector2i(2, 1))
	check(weakened != null and weakened.atk_debuff == 9 and weakened.debuff_stage == 0,
			"施放削弱：减值已记录，尚未生效（本回合攻击力不变）")
	check(weakened != null and weakened.effective_power() == 5, "当前回合攻击力仍为 5")
	eng_de.end_turn()   # 进入对手回合 → 削弱生效
	check(eng_de.state.unit_at(Vector2i(2, 1)).effective_power() == 0,
			"对手回合：攻击力 5-9 → 0")
	eng_de.end_turn()   # 对手回合结束 → 恢复
	check(eng_de.state.unit_at(Vector2i(2, 1)).effective_power() == 5,
			"对手回合结束：攻击力恢复 5")

	# ---- 寒冰箭：3 伤害 + 下回合开始不重置 ----
	var eng_fr := _new_engine([], 20, 30)
	eng_fr.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_fr.start_game()
	eng_fr.state.hand.append(_card(9011, "寒冰箭", "技能", 2, 0, 0))
	eng_fr.use_spell(eng_fr.state.hand.size() - 1, Vector2i(2, 1))
	var frosted := eng_fr.state.unit_at(Vector2i(2, 1))
	check(frosted != null and frosted.health == 27 and frosted.frozen,
			"寒冰箭：3 伤害（30→27）且被冰封")
	eng_fr.end_turn()   # 对手回合：冰封单位不重置
	var still := eng_fr.state.unit_at(Vector2i(2, 1))
	check(still != null and still.tapped and not still.frozen,
			"对手回合开始：冰封解除但保持横置（不能再行动）")
	eng_fr.end_turn()
	eng_fr.end_turn()   # 再到对手回合：正常恢复
	var thawed := eng_fr.state.unit_at(Vector2i(2, 1))
	check(thawed != null and not thawed.tapped, "再下回合：正常解除横置")

	# ---- R68：冰封的施加特效只有一个入口（_apply_frozen），三处来源同源 ----
	# 之前寒冰箭 / 冰冻术士战吼 / 冻结陷阱各写一遍 `p.frozen = true`，特效与日志容易漂移。
	var r68_fz := _new_engine([], 20, 30)
	r68_fz.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r68_fz.start_game()
	var r68_got := {"frozen": 0}
	r68_fz.action.connect(func(what: String, _d: Variant) -> void:
			if what == "frozen":
				r68_got["frozen"] = int(r68_got["frozen"]) + 1)
	# 来源①：寒冰箭（走 _run_spell_effect → _apply_frozen）
	r68_fz.state.hand.append(_card(9011, "寒冰箭", "技能", 2, 0, 0))
	r68_fz.use_spell(r68_fz.state.hand.size() - 1, Vector2i(2, 1))
	check(int(r68_got["frozen"]) == 1
			and r68_fz.state.unit_at(Vector2i(2, 1)).frozen,
			"R68 寒冰箭：经唯一入口施加冰封，并发出 1 次 frozen 特效事件（实际 %d）"
			% int(r68_got["frozen"]))
	# 来源②：冻结**场地**（8013，R74 已从工事改成场地）——敌人**移动进入**时也走同一个冰封入口
	var r68_ft := _new_engine([], 20, 30)
	var r68_z: CardData = repo.get_card(GameEngine.FREEZE_TRAP_ID)
	var r68_ft_foe := r68_ft.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r68_ft.state.hand.append(CardData.from_dict(r68_z.to_dict()))
	r68_ft.start_game()
	r68_ft.ai_enabled = false
	var r68_ft_got := [0]
	r68_ft.action.connect(func(what: String, _d: Variant) -> void:
			if what == "frozen":
				r68_ft_got[0] = int(r68_ft_got[0]) + 1)
	r68_ft.play_from_hand(0, Vector2i(4, 1))       # 我方把冻结场地放到 (4,1)
	r68_ft.current_side = GameEngine.SIDE_OPPONENT
	r68_ft.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 敌人移动进入
	check(int(r68_ft_got[0]) == 1 and r68_ft_foe.frozen
			and r68_ft_foe.health == 55 - GameEngine.FREEZE_TRAP_DMG,
			"R68/R74 冻结场地：移动进入同样经唯一入口施加冰封并发出 frozen 事件（%d 次，血 %d）"
			% [int(r68_ft_got[0]), r68_ft_foe.health])
	# 目标被打死 → 不施加冰封（也不发特效）：死单位冰封没有意义
	var r68_dead := _new_engine([], 20, 30)
	r68_dead.state.place(_card(9001, "鸭子骑士", "盟友", 6, 5, 3, 1, 2),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r68_dead.start_game()
	r68_dead.state.hand.append(_card(9011, "寒冰箭", "技能", 2, 0, 0))
	r68_dead.use_spell(r68_dead.state.hand.size() - 1, Vector2i(2, 1))
	check(r68_dead.state.unit_at(Vector2i(2, 1)) == null,
			"R68 寒冰箭打死目标：直接冰碎，不留冰封状态")
	# 冰封是**隐藏状态**：卡面看不出来 → 界面必须靠 Placement.frozen 判定。
	# 这里锁「引擎状态字段名」，battle_scene._draw_frozen_aura 读的就是它。
	check(r68_fz.state.unit_at(Vector2i(2, 1)).frozen == true,
			"R68 冰封判据：Placement.frozen（界面特效的唯一数据源）")

	# ---- 新关卡：使魔鸭群 / 骑士冲锋 / 队长与巫师 / 爆炎鸭阵 / 白魔法师护阵 ----
	var lvls := GameLevels.builtin_levels()
	check(lvls.size() == 20, "内置关卡共 20 关（7 普简 + 4 普难 + 3 精英简单 + 3 精英困难 + 3 Boss）")
	var lva: Dictionary = _level_named("使魔鸭群")
	check(str(lva["name"]) == "使魔鸭群"
			and int(lva["tier"]) == GameLevels.TIER_NORMAL_EASY
			and (lva["enemy_units"] as Array).size() == 5,
			"使魔鸭群：普通简单，5 只使魔")
	var lvb: Dictionary = _level_named("骑士冲锋")
	check(str(lvb["name"]) == "骑士冲锋"
			and int(lvb["tier"]) == GameLevels.TIER_NORMAL_HARD
			and (lvb["enemy_units"] as Array).size() == 3,
			"骑士冲锋：普通困难，3 只骑士一字排开")
	var lvc: Dictionary = _level_named("队长与巫师")
	check(str(lvc["name"]) == "队长与巫师"
			and int(lvc["tier"]) == GameLevels.TIER_ELITE_HARD
			and (lvc["enemy_units"] as Array).size() == 3,
			"队长与巫师：精英困难（队长+巫师+使魔）")
	check(GameLevels.normal_pool().size() == 6,
			"第一层普通池 6 关（普简×4 + 普难×2，不含第二层那关）")
	check(GameLevels.elite_pool().size() == 3, "精英池 3 关（精简×1 + 精难×2）")
	check(str(GameLevels.boss_level()["name"]) == "远古虚骨龙",
			"boss_level() 默认返回第一层 Boss 池的第一个（远古虚骨龙；同层多Boss 时实际由 RunState 摇定）")

	# ---- 第二层新关卡「白魔法师护阵」：后排 1 白魔法师 + 前排 3 鸭子骑士 ----
	var lvw: Dictionary = _level_named("白魔法师护阵")
	var wm_units: Array = lvw["enemy_units"]
	var wm_mage := 0
	var wm_knight := 0
	var wm_mage_row := -1
	var wm_knight_rows := {}
	for u in wm_units:
		var ucell: Vector2i = u[6]
		match int(u[0]):
			9021:
				wm_mage += 1
				wm_mage_row = ucell.x
			9001:
				wm_knight += 1
				wm_knight_rows[ucell.x] = true
	check(str(lvw["name"]) == "白魔法师护阵"
			and int(lvw["tier"]) == GameLevels.TIER_NORMAL_EASY
			and GameLevels.layer_of(lvw) == GameLayers.LAYER_TWO
			and wm_units.size() == 4,
			"白魔法师护阵：第二层·普通敌人-简单，4 个单位")
	check(wm_mage == 1 and wm_knight == 3,
			"白魔法师护阵阵容：白魔法师×1 / 鸭子骑士×3")
	check(wm_mage_row == GameEngine.back_row(GameEngine.SIDE_OPPONENT)
			and wm_knight_rows.size() == 1
			and wm_knight_rows.has(GameEngine.back_row(GameEngine.SIDE_OPPONENT) + 2),
			"白魔法师护阵站位：白魔法师在后排（0 行）、3 骑士在前排（2 行）")
	var nc_mage := repo.get_card(9021)
	check(nc_mage != null and nc_mage.card_name == "白魔法师"
			and nc_mage.power == 2 and nc_mage.health == 100
			and nc_mage.attack_range == 1 and nc_mage.move_speed == 1
			and nc_mage.rarity == 4 and nc_mage.traits.has("治疗")
			and nc_mage.value == 10,
			"白魔法师：怪物 2 攻 100 血，trait「治疗」强度 10")
	check(nc_mage.traits.has(GameEngine.MAGE_GROW_TRAIT)
			and GameEngine.MAGE_GROW_BUFF == 1
			and not nc_mage.effect_text.contains("仅有它自己")
			and nc_mage.effect_text.contains("每回合开始时，力量 +1"),
			"白魔法师：trait「精进」——每回合开始力量 +1（无前置条件）")
	var nc_egg := repo.get_card(9022)
	check(nc_egg != null and nc_egg.card_name == "鸭蛋" and nc_egg.kind == "工事"
			and nc_egg.power == 0 and nc_egg.health == 1
			and nc_egg.attack_range == 0 and nc_egg.move_speed == 0
			and not repo.reward_pool().has(nc_egg),
			"鸭蛋：0 攻 1 血工事（生蛋鸭召唤物，不在奖励池）")
	check(lvw not in GameLevels.normal_pool(GameLayers.LAYER_DEFAULT),
			"第二层新关不出现在第一层普通池（不串层）")
	check(lvw in GameLevels.normal_pool(GameLayers.LAYER_TWO),
			"第二层新关出现在第二层普通池（专属池）")

	# ---- 第二层新关卡「哈气骑士团」+ 效果卡「哈气」（所属阵营单位从第 3 个回合起一回合行动两次）----
	var hc := repo.get_card(9024)
	check(hc != null and hc.card_name == "哈气" and hc.kind == "效果"
			and hc.traits.has("哈气") and hc.value == 2 and hc.rarity == 4
			and not repo.reward_pool().has(hc),
			"哈气：效果卡（强度 2 = 第 3 个回合起每回合行动两次，不在奖励池）")
	var lvh: Dictionary = _level_named("哈气骑士团")
	var h_units: Array = lvh["enemy_units"]
	var h_knight := 0
	var h_archer := 0
	var h_knight_rows := {}
	var h_archer_rows := {}
	for u in h_units:
		var hcell: Vector2i = u[6]
		match int(u[0]):
			9001:
				h_knight += 1
				h_knight_rows[hcell.x] = true
			9017:
				h_archer += 1
				h_archer_rows[hcell.x] = true
	check(str(lvh["name"]) == "哈气骑士团"
			and int(lvh["tier"]) == GameLevels.TIER_ELITE_EASY
			and GameLevels.layer_of(lvh) == GameLayers.LAYER_TWO
			and h_units.size() == 5,
			"哈气骑士团：第二层·精英敌人-简单，5 个单位")
	check(h_knight == 3 and h_archer == 2,
			"哈气骑士团阵容：鸭子骑士×3 / 鸭子弓手×2")
	check(h_knight_rows.size() == 1
			and h_knight_rows.has(GameEngine.back_row(GameEngine.SIDE_OPPONENT) + 2)
			and h_archer_rows.size() == 1
			and h_archer_rows.has(GameEngine.back_row(GameEngine.SIDE_OPPONENT)),
			"哈气骑士团站位：3 骑士前排（2 行）、2 弓手后排（0 行）")
	check((lvh["enemy_effects"] as Array) == [9024],
			"哈气骑士团：敌方开局启用效果卡「哈气」")
	check(lvh in GameLevels.elite_pool(GameLayers.LAYER_TWO)
			and lvh not in GameLevels.elite_pool(GameLayers.LAYER_DEFAULT),
			"哈气骑士团只在第二层精英池（第一层精英池不含它，不串层）")

	# 哈气机制：只增益所属阵营 / **第 3 个回合起才生效** / 已在场单位补发 / 与卡自带双动不叠加
	var eng_hs := _new_engine([], 20, 40)
	var hk_p := eng_hs.state.place(repo.get_card(9001), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	var hf_p := eng_hs.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(hk_p.acts_left == 1 and hf_p.acts_left == 1,
			"没有哈气时：敌我单位都是每回合 1 次行动")
	eng_hs.enable_enemy_effects([repo.get_card(9024)])
	check(hk_p.acts_left == 1 and hf_p.acts_left == 1,
			"哈气有前置：开局启用（第 0 回合）不生效，已在场的敌方单位仍是 1 次行动")
	var hk_e := eng_hs.state.place(repo.get_card(9001), Vector2i(2, 0),
			GameEngine.SIDE_OPPONENT)
	check(hk_e.acts_left == 1, "哈气未到生效回合：新上场的敌方单位也是 1 次行动")
	eng_hs.state.opp_turn_no = 2
	eng_hs.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(hk_p.acts_left == 1, "哈气：敌方第 2 回合仍未生效（1 次行动）")
	eng_hs.state.opp_turn_no = 3
	eng_hs.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(hk_p.acts_left == 2 and hk_e.acts_left == 2 and hf_p.acts_left == 1,
			"哈气：敌方第 3 回合起生效 → 已在场敌方单位补到 2 次行动，我方单位不受影响")
	var hk2_p := eng_hs.state.place(repo.get_card(9001), Vector2i(2, 2),
			GameEngine.SIDE_OPPONENT)
	check(hk2_p.acts_left == 2, "哈气生效后新上场的敌方单位也是 2 次行动")
	var hcap_c := _card(9012, "鸭子队长", "盟友", 8, 10, 50, 1, 1)
	hcap_c.actions = 2
	var hcap_p := eng_hs.state.place(hcap_c, Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	check(hcap_p.acts_left == 2, "哈气不叠加：队长仍是 2 次行动（不是 4 次）")
	eng_hs.current_side = GameEngine.SIDE_OPPONENT
	eng_hs.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(hf_p.health == 5 and not hk_p.tapped and hk_p.acts_left == 1,
			"哈气：敌方单位第一轮行动后不横置，还剩 1 轮")
	eng_hs.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(hf_p.health == 2 and hk_p.tapped and hk_p.acts_left == 1,
			"哈气：第二轮行动后才正常横置")

	# 哈气前置的端到端验证：真实回合推进（我方1 → 敌方1 → 我方2 → 敌方2 → 我方3 → 敌方3）
	var eng_ht := _new_engine([], 20, 40)
	var ht_p := eng_ht.state.place(repo.get_card(9001), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	eng_ht.enable_enemy_effects([repo.get_card(9024)])
	eng_ht.start_game(0)
	eng_ht.end_turn()
	check(eng_ht.opp_turns == 1 and ht_p.acts_left == 1,
			"哈气（端到端）：敌方第 1 回合只有 1 次行动")
	eng_ht.end_turn()
	eng_ht.end_turn()
	check(eng_ht.opp_turns == 2 and ht_p.acts_left == 1,
			"哈气（端到端）：敌方第 2 回合仍是 1 次行动")
	eng_ht.end_turn()
	eng_ht.end_turn()
	check(eng_ht.opp_turns == 3 and ht_p.acts_left == 2,
			"哈气（端到端）：敌方第 3 回合起才是 2 次行动")

	# 多动单位：可以连续消耗两次行动移动（横着挪位后仍保留最后一次的攻击权）
	var eng_mv2 := _new_engine([], 20, 40)
	var cap2_c := _card(9012, "鸭子队长", "盟友", 8, 6, 50, 1, 1)
	cap2_c.actions = 2
	var cap2_p := eng_mv2.state.place(cap2_c, Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng_mv2.state.place(_card(8003, "农民甲", "盟友", 3, 3, 40, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_mv2.state.place(_card(8003, "农民乙", "盟友", 3, 3, 40, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	eng_mv2.move(Vector2i(3, 0), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(cap2_p.moved and not cap2_p.tapped and cap2_p.acts_left == 2,
			"多动单位第一次移动后不横置（落点有目标，还剩 2 次行动）")
	eng_mv2.move(Vector2i(3, 1), Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(eng_mv2.state.unit_at(Vector2i(3, 2)) == cap2_p and cap2_p.acts_left == 1,
			"多动单位可以再消耗一次行动继续走一格（走两格 = 像速 2 那样行动）")
	eng_mv2.attack(Vector2i(3, 2), Vector2i(2, 2), GameEngine.SIDE_SELF)
	check(cap2_p.tapped and cap2_p.acts_left == 1,
			"两次行动用完（走两格 + 打一下）后才正常横置")
	# 单动单位：仍然只能走一格（不能被上面的改动放开）
	var eng_mv1 := _new_engine([], 20, 40)
	var solo_p := eng_mv1.state.place(_card(8003, "农民", "盟友", 3, 3, 40, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	eng_mv1.move(Vector2i(3, 0), Vector2i(3, 1), GameEngine.SIDE_SELF)
	eng_mv1.move(Vector2i(3, 1), Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(eng_mv1.state.unit_at(Vector2i(3, 1)) == solo_p,
			"单动单位走完一格就不能再走（多动放开不影响它）")

	# 多动 AI：正前方被自己人堵住时，会先横着挪一格绕行（而不是原地放弃）
	var eng_det := _new_engine([], 20, 40)
	var det_c := _card(9012, "鸭子队长", "盟友", 8, 6, 50, 1, 1)
	det_c.actions = 2
	var det_p := eng_det.state.place(det_c, Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	eng_det.state.place(_card(8003, "友军", "盟友", 3, 0, 40, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 自己人堵住正前方
	eng_det.ai_enabled = true
	eng_det.current_side = GameEngine.SIDE_OPPONENT
	eng_det.run_ai_unit(Vector2i(3, 1))
	var det_at := Vector2i(-1, -1)
	for c: Vector2i in eng_det.state.board:
		if eng_det.state.board[c] == det_p:
			det_at = c
	check(det_at == Vector2i(3, 0) or det_at == Vector2i(3, 2),
			"多动 AI 被自己人挡住时先横着挪一格绕行（实际 %s）" % str(det_at))
	check(det_p.acts_left == 1 and not det_p.tapped,
			"绕行消耗掉一次行动，还剩 1 次（可以接着压上去 + 攻击）")

	# 多动 AI 全自动战斗（哈气 + 推进 + 绕行）：必须在有限步内打完，不许死循环
	var eng_full := _new_engine(_single_deck(_card(8003, "农民", "盟友", 3, 3, 40)), 20, 40)
	eng_full.ai_enabled = true
	eng_full.start_game(1)
	eng_full.enable_enemy_effects([repo.get_card(9024)])   # 哈气：敌方第 3 个回合起行动两次
	eng_full.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	eng_full.state.place(repo.get_card(9001), Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	eng_full.current_side = GameEngine.SIDE_OPPONENT
	var guard := 0
	while not eng_full.over and guard < 4000:
		guard += 1
		var q := eng_full.ai_action_queue()
		if q.is_empty():
			eng_full.end_turn()
			eng_full.end_turn()
			continue
		eng_full.run_ai_unit(q[0])
	check(eng_full.over and guard < 4000,
			"哈气敌方 AI 全自动战斗能正常打完（结束=%s，步数 %d）" % [str(eng_full.over), guard])

	# ---- 新卡「鸭子窑」（9025）/「陶瓷鸭」（9026）+ 孵化机制 ----
	var kiln_c := repo.get_card(9025)
	check(kiln_c != null and kiln_c.card_name == "鸭子窑" and kiln_c.kind == "工事"
			and kiln_c.power == 0 and kiln_c.health == 100
			and kiln_c.attack_range == 0 and kiln_c.move_speed == 0
			and kiln_c.traits.has("孵化") and kiln_c.value == 9026
			and not repo.reward_pool().has(kiln_c),
			"鸭子窑：工事 0 力 100 血 程0 速0，trait 孵化，产物=陶瓷鸭（不进奖励池）")
	var ceramic_c := repo.get_card(9026)
	check(ceramic_c != null and ceramic_c.card_name == "陶瓷鸭"
			and ceramic_c.power == 8 and ceramic_c.health == 1
			and ceramic_c.attack_range == 1 and ceramic_c.move_speed == 2
			and not repo.reward_pool().has(ceramic_c),
			"陶瓷鸭：8 力 1 血 程1 速2（鸭子窑产物，不进奖励池）")

	# 孵化机制：**自己回合开始时**（含首回合）在四邻空格烧出陶瓷鸭；越界/占用跳过
	var eng_kiln := _new_engine([], 20, 40)
	# 对手在 (0,1) 放一座鸭子窑（模拟关卡后排中央）；(0,0) 预先被己方占掉
	eng_kiln.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(0, 0), GameEngine.SIDE_SELF)
	eng_kiln.state.place(kiln_c, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	eng_kiln._kiln_hatch(GameEngine.SIDE_OPPONENT)
	var ceramic_count := 0
	for cell in eng_kiln.state.board:
		var q: Placement = eng_kiln.state.board[cell]
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9026:
			ceramic_count += 1
	check(ceramic_count == 2,
			"孵化：四邻中 (0,0) 被占、(-1,1) 越界 → 只在 (0,2)(1,1) 各烧 1 只")
	# 「自己回合开始时」：窑只在**它主人**的回合孵化 —— 我方回合开始时，对方的窑不动
	var eng_kiln2 := _new_engine([], 20, 40)
	eng_kiln2.state.place(kiln_c, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	eng_kiln2._begin_turn(GameEngine.SIDE_SELF)
	ceramic_count = 0
	for cell in eng_kiln2.state.board:
		var q: Placement = eng_kiln2.state.board[cell]
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9026:
			ceramic_count += 1
	check(ceramic_count == 0, "窑只在自己回合孵化：我方回合开始时敌方窑不动（0 只）")
	eng_kiln2._begin_turn(GameEngine.SIDE_OPPONENT)
	ceramic_count = 0
	for cell in eng_kiln2.state.board:
		var q: Placement = eng_kiln2.state.board[cell]
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9026:
			ceramic_count += 1
	check(ceramic_count == 3, "轮到窑主人（敌方）回合开始 → 3 只陶瓷鸭，归属窑主人")

	# 强化（2026-10-01）：陶瓷鸭的生命值 X = 当前**该方**回合数（窑主人的第几回合）
	var eng_kiln3 := _new_engine([], 20, 40)
	eng_kiln3.opp_turns = 4                      # 模拟「敌方第 4 回合开始」
	eng_kiln3.state.place(kiln_c, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	eng_kiln3._kiln_hatch(GameEngine.SIDE_OPPONENT)
	var kiln_hp: Array[int] = []
	for cell in eng_kiln3.state.board:
		var q: Placement = eng_kiln3.state.board[cell]
		if q.owner == GameEngine.SIDE_OPPONENT and q.card.id == 9026:
			kiln_hp.append(q.health)
	kiln_hp.sort()
	check(kiln_hp == [4, 4, 4],
			"鸭子窑强化：敌方第 4 回合烧出的陶瓷鸭各 4 血（生命 = 当前己方回合数）")
	# 己方回合数（turn_number）同样成立
	var eng_kiln4 := _new_engine([], 20, 40)
	eng_kiln4.turn_number = 3
	eng_kiln4.state.place(kiln_c, Vector2i(5, 1), GameEngine.SIDE_SELF)
	eng_kiln4._kiln_hatch(GameEngine.SIDE_SELF)
	var kiln_hp_self: Array[int] = []
	for cell in eng_kiln4.state.board:
		var q2: Placement = eng_kiln4.state.board[cell]
		if q2.owner == GameEngine.SIDE_SELF and q2.card.id == 9026:
			kiln_hp_self.append(q2.health)
	kiln_hp_self.sort()
	check(kiln_hp_self == [3, 3, 3],
			"鸭子窑强化：我方第 3 回合烧出的陶瓷鸭各 3 血（读的是己方回合数）")
	check(repo.get_card(9026).health == 1,
			"鸭子窑强化：改的是产物副本，库里的陶瓷鸭仍是 1 血（没被就地改写）")

	# 新关卡「鸭子窑」：第二层·普通敌人-困难，后排中央一座鸭子窑
	var lvk: Dictionary = _level_named("鸭子窑")
	check(str(lvk["name"]) == "鸭子窑"
			and int(lvk["tier"]) == GameLevels.TIER_NORMAL_HARD
			and GameLevels.layer_of(lvk) == GameLayers.LAYER_TWO
			and (lvk["enemy_units"] as Array).size() == 1,
			"鸭子窑：第二层·普通敌人-困难，仅 1 个敌方单位（鸭子窑）")
	var ku: Array = lvk["enemy_units"]
	check(int(ku[0][0]) == 9025 and ku[0][6] == Vector2i(0, 1),
			"鸭子窑站位：敌方后排中央 (0,1)")

	# 哈气骑士团开场台词
	check(str(lvh.get("intro", "")) == "我要闹了", "哈气骑士团：开场台词「我要闹了」")

	# ---- 新关卡「爆炎鸭阵」：1 骑士 + 1 使魔 + 2 爆炎鸭 ----
	var lvd: Dictionary = _level_named("爆炎鸭阵")
	var blaze_units: Array = lvd["enemy_units"]
	var blaze_knight := 0
	var blaze_duck := 0
	var blaze_familiar := 0
	var knight_cell := Vector2i(-1, -1)
	var duck_cells: Array[Vector2i] = []
	for u in blaze_units:
		var ucell: Vector2i = u[6]
		match int(u[0]):
			9001:
				blaze_knight += 1
				knight_cell = ucell
			9020:
				blaze_duck += 1
				duck_cells.append(ucell)
			9009:
				blaze_familiar += 1
	check(str(lvd["name"]) == "爆炎鸭阵"
			and int(lvd["tier"]) == GameLevels.TIER_NORMAL_EASY
			and blaze_units.size() == 4,
			"爆炎鸭阵：普通敌人-简单，4 个单位")
	check(blaze_knight == 1 and blaze_familiar == 1 and blaze_duck == 2,
			"爆炎鸭阵阵容：鸭子骑士×1 / 使魔鸭子×1 / 爆炎鸭×2")
	var duck_near := duck_cells.size() == 2
	for dc in duck_cells:
		if absi(dc.x - knight_cell.x) + absi(dc.y - knight_cell.y) != 1:
			duck_near = false
	check(duck_near, "爆炎鸭阵：两只爆炎鸭都与骑士相邻（亡语会炸到骑士）")
	check(GameLevels.normal_pool().has(lvd),
			"爆炎鸭阵进入第一层普通战斗池（会被地图抽到）")

	# ---- 分层：各层内容互不串层（第一层 [1] / 第二层 [2]，各自专属） ----
	check(GameLevels.levels_of_layer(GameLayers.LAYER_DEFAULT).size() == lvls.size() - GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size(),
			"第一层自带关卡 = %d 关（全部关卡里除第二层那 %d 关）" % [lvls.size() - GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size(), GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size()])
	check(GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size() == 9,
			"第二层自带 9 关（白魔法师护阵 / 夜鸭阵 / 鸭子窑 / 哈气骑士团 / 寒冰防线 / 亡灵军团 / 龙族巢穴 / 机甲巨兵 / 机械巨鸭Boss）")
	# 内容池：第一层 = [1]；第二层 = [2]（各层内容互不串层）
	var cl1 := GameLayers.content_layers(GameLayers.LAYER_DEFAULT)
	var cl2 := GameLayers.content_layers(GameLayers.LAYER_TWO)
	check(cl1.size() == 1 and int(cl1[0]) == 1, "第一层内容池 = [1]（只用第一层内容）")
	check(cl2.size() == 1 and int(cl2[0]) == 2,
			"第二层内容池 = [2]（只用第二层内容，不再混用第一层）")
	check(GameLayers.content_layers(9).is_empty(), "未配置的层：内容池为空（拿不到任何内容）")
	check(GameLevels.normal_pool(GameLayers.LAYER_TWO).size() == 5,
			"第二层普通池 5 关（专属：普通简单 3 + 普通困难 2）")
	check(GameLevels.elite_pool(GameLayers.LAYER_TWO).size() == 3,
			"第二层精英池 3 关（专属：精英简单 2 + 精英困难 1）")
	var l2_battle_pool: Array[Dictionary] = []
	l2_battle_pool.append_array(GameLevels.normal_pool(GameLayers.LAYER_TWO))
	l2_battle_pool.append_array(GameLevels.elite_pool(GameLayers.LAYER_TWO))
	var l2_pool_ok := true
	for l2p: Dictionary in l2_battle_pool:
		if GameLevels.layer_of(l2p) != GameLayers.LAYER_TWO:
			l2_pool_ok = false
	check(l2_pool_ok, "第二层战斗池里的关卡全部属于第二层（不串层）")
	check(str(GameLevels.boss_level(GameLayers.LAYER_TWO)["name"]) == "机械巨鸭",
			"第二层 Boss = 本层专属的机械巨鸭（不再回退第一层）")
	check(str(GameLevels.boss_level(GameLayers.LAYER_DEFAULT)["name"]) == "远古虚骨龙"
			and GameLevels.boss_pool(GameLayers.LAYER_DEFAULT).size() == 2,
			"第一层 Boss 池 = 远古虚骨龙 + 恶魔鸭（R63 新增，共2 关）；boss_level() 默认取第一个")
	var lv_mb: Dictionary = _level_named("机械巨鸭")
	var mb_units: Array = lv_mb.get("enemy_units", [])
	var mb_effs: Array = lv_mb.get("enemy_effects", [])
	check(str(lv_mb.get("name", "")) == "机械巨鸭"
			and int(lv_mb.get("tier", -1)) == GameLevels.TIER_BOSS
			and GameLevels.layer_of(lv_mb) == GameLayers.LAYER_TWO
			and mb_units.size() == 1
			and int(mb_units[0][0]) == 9047
			and int(mb_units[0][2]) == 10 and int(mb_units[0][3]) == 150
			and mb_effs.size() == 1 and int(mb_effs[0]) == 9049,
			"机械巨鸭：第二层 Boss 关（1 只机械巨鸭 + 敌方效果卡齿轮升腾）")
	# ============================================================
	# 旧版怪物（1011~1071）复用进第二层：数值 + 嘲讽 / 战吼 / 亡语 / 法术免疫
	# ============================================================
	var om_repo := CardRepo.load_json()
	var om_wall := om_repo.get_card(1011)      # 铁壁卫兵 4/40 嘲讽（2026-09-30 由 45 下调到 40）
	check(om_wall != null and om_wall.power == 4 and om_wall.health == 40,
			"铁壁卫兵 1011 → 4/40（二层坦克，HP 削弱到 40）")
	var om_ash := om_repo.get_card(1013)       # 灰烬龙 9/45（2026-09-30 由 40 增强到 45）
	check(om_ash != null and om_ash.power == 9 and om_ash.health == 45,
			"灰烬龙 1013 → 9/45（HP 增强到 45）")
	check(om_wall != null and om_wall.traits.has("嘲讽"), "铁壁卫兵带「嘲讽」trait")
	var om_giant := om_repo.get_card(1071)     # 熔岩巨人 12/70 法术免疫
	check(om_giant != null and om_giant.power == 12 and om_giant.health == 70,
			"熔岩巨人 1071 → 12/70")
	check(om_giant != null and om_giant.traits.has("法术免疫"), "熔岩巨人带「法术免疫」trait")
	var om_cost_ok := true
	for om_id in [1011, 1013, 1014, 1031, 1050, 1051, 1053, 1054, 1055, 1061, 1071]:
		var om_cd := om_repo.get_card(om_id)
		if om_cd == null or om_cd.cost < 1 or om_cd.cost > 9:
			om_cost_ok = false
	check(om_cost_ok, "旧卡费用已修正到 1~9（原来有个位数到 28 的异常值）")
	check(om_repo.get_card(9028) != null and om_repo.get_card(9028).card_name == "龙裔",
			"新增亡语产物「龙裔」9028（幼龙）")
	check(om_repo.get_card(9029) != null and om_repo.get_card(9029).card_name == "骷髅",
			"新增亡语产物「骷髅」9029（亡灵领主）")

	# ---- 嘲讽：射程内有嘲讽单位时必须打它 ----
	var om_t := _new_engine([], 20, 30, -1, false)
	om_t.state.place(om_wall, Vector2i(3, 1), GameEngine.SIDE_SELF)
	om_t.state.place(om_repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var om_tp := om_t.state.unit_at(Vector2i(2, 1))
	var om_choice = om_t._ai_target_choice(Vector2i(2, 1), om_tp)
	check(om_choice != null and str(om_choice[0]) == "card" \
			and om_choice[1] == Vector2i(3, 1),
			"嘲讽：射程内有嘲讽单位 → AI 必须打它（不能直击 HP）")
	var om_hp_e := _new_engine([], 20, 30, -1, false)
	om_hp_e.state.place(om_wall, Vector2i(4, 0), GameEngine.SIDE_SELF)
	om_hp_e.state.place(om_repo.get_card(9001), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	var om_hp0 := om_hp_e.state.hp_self
	om_hp_e.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(om_hp_e.state.hp_self == om_hp0, "嘲讽：射程内有嘲讽单位 → 不能直击我方 HP")

	# ---- 嘲讽只收窄「普攻」高亮；技能选目标不受影响 ----
	var om_ui := _new_engine([], 20, 30, -1, false)
	om_ui.state.place(om_wall, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)               # 嘲讽
	om_ui.state.place(om_repo.get_card(1053), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)  # 非嘲讽
	om_ui.state.place(om_repo.get_card(1031), Vector2i(3, 1), GameEngine.SIDE_SELF)      # 射程 3
	var om_ui_all := om_ui.attack_targets(Vector2i(3, 1))
	var om_ui_legal := om_ui.legal_attack_targets(Vector2i(3, 1))
	check(om_ui_all.size() == 2, "嘲讽：射程内 2 个敌方单位（原始攻击目标）")
	check(om_ui_legal.size() == 1 and om_ui_legal[0] == Vector2i(2, 1),
			"嘲讽：普攻高亮只保留嘲讽单位（不给其他单位画红框）")
	check(om_ui.taunt_in_range(Vector2i(3, 1), GameEngine.SIDE_SELF),
			"嘲讽：taunt_in_range → true（据此隐藏深红 HP 格）")
	om_ui.state.hand = [om_repo.get_card(9011)]
	om_ui.state.energy = 9
	var om_ui_sp := om_ui.use_spell(0, Vector2i(2, 2))
	var om_ui_sk := om_ui.state.unit_at(Vector2i(2, 2))
	check(om_ui_sk != null and om_ui_sk.frozen,
			"嘲讽不限制技能：寒冰箭照常命中非嘲讽敌人（%s）" % om_ui_sp)

	# ---- 骷髅兵（1054）：亡语改「召唤一只 3/8 的骷髅」（不再是抽 1 张）----
	var om_dr := _new_engine([], 20, 30, -1, false)
	om_dr.state.deck = [_card(8002, "攻击", "技能", 1, 0, 0)]
	om_dr.state.place(om_repo.get_card(1054), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var om_dr_hand0 := om_dr.state.opp_hand_count
	om_dr._destroy(Vector2i(2, 1))
	var om_dr_spawned := 0
	for om_r in FieldState.BOARD_ROWS:
		for om_c in FieldState.BOARD_COLS:
			var om_q := om_dr.state.unit_at(Vector2i(om_r, om_c))
			if om_q != null and om_q.card.id == 9029:
				om_dr_spawned += 1
	check(om_dr_spawned == 1, "骷髅兵亡语：召唤一只骷髅 9029（实际 %d）" % om_dr_spawned)
	check(om_dr.state.opp_hand_count == om_dr_hand0, "骷髅兵亡语：不再抽牌（对方手牌数不变）")

	# ---- 战吼（所属阵营第一个回合开始时触发一次）----
	var om_bc := _new_engine([], 20, 30, -1, false)
	om_bc.state.place(om_repo.get_card(1013), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	om_bc.state.place(om_repo.get_card(1053), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var om_bc_hp := om_bc.state.unit_at(Vector2i(3, 1)).health
	om_bc._begin_turn(GameEngine.SIDE_OPPONENT)
	var om_bc1 := om_bc.state.unit_at(Vector2i(3, 1))
	check(om_bc1 != null and om_bc1.health == om_bc_hp - 4,
			"灰烬龙战吼：对我方单位造成 4 点伤害")
	om_bc._begin_turn(GameEngine.SIDE_OPPONENT)
	var om_bc2 := om_bc.state.unit_at(Vector2i(3, 1))
	check(om_bc2 == null or om_bc2.health == om_bc_hp - 4, "战吼只触发一次")
	var om_fr := _new_engine([], 20, 30, -1, false)
	om_fr.state.place(om_repo.get_card(1031), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	om_fr.state.place(om_repo.get_card(1053), Vector2i(3, 1), GameEngine.SIDE_SELF)
	om_fr._begin_turn(GameEngine.SIDE_OPPONENT)
	check(om_fr.state.unit_at(Vector2i(3, 1)) != null \
			and om_fr.state.unit_at(Vector2i(3, 1)).frozen,
			"冰冻术士战吼：冻结我方单位（下回合不重置、不能行动）")

	# ---- 亡语 ----
	var om_wy := _new_engine([], 20, 30, -1, false)
	om_wy.state.place(om_repo.get_card(1014), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	om_wy._destroy(Vector2i(2, 1))
	var om_wy_born := om_wy.state.unit_at(Vector2i(2, 1))
	check(om_wy_born != null and om_wy_born.card.id == 9028, "幼龙亡语：原地召唤龙裔 9028")
	var om_gh := _new_engine([], 20, 30, -1, false)
	om_gh.state.place(om_repo.get_card(1050), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var om_gh_hp := om_gh.state.hp_self
	om_gh._destroy(Vector2i(2, 1))
	check(om_gh.state.hp_self == om_gh_hp - 5, "腐化尸鬼亡语：对我方 HP 造成 5 点伤害")
	var om_li := _new_engine([], 20, 30, -1, false)
	om_li.state.place(om_repo.get_card(1051), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	om_li._destroy(Vector2i(2, 1))
	var om_sk := 0
	for om_cell: Vector2i in om_li.state.board:
		if om_li.state.board[om_cell].card.id == 9029:
			om_sk += 1
	check(om_sk == 2, "亡灵领主亡语：召唤两个骷髅 9029")
	var om_me := _new_engine([], 20, 30, -1, false)
	om_me.state.place(om_repo.get_card(1061), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	om_me.state.place(om_repo.get_card(1053), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var om_me_hp := om_me.state.unit_at(Vector2i(3, 1)).health
	om_me._destroy(Vector2i(2, 1))
	var om_me_a := om_me.state.unit_at(Vector2i(3, 1))
	check(om_me_a != null and om_me_a.health == om_me_hp - 8,
			"爆裂机甲亡语：对全场单位造成 8 点伤害")

	# ---- 法术免疫 ----
	var om_im := _new_engine([], 20, 30, -1, false)
	om_im.state.place(om_giant, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	om_im.state.place(om_repo.get_card(9001), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var om_im_hp := om_im.state.unit_at(Vector2i(2, 1)).health
	om_im._op_deal_damage(GameEngine.SIDE_SELF, 15, Vector2i(2, 1))
	check(om_im.state.unit_at(Vector2i(2, 1)).health == om_im_hp,
			"熔岩巨人免疫法术伤害（15 点法术打不动）")
	om_im.attack(Vector2i(3, 1), Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(om_im.state.unit_at(Vector2i(2, 1)).health < om_im_hp,
			"熔岩巨人仍会被普通攻击打到（只免疫法术）")

	# ---- 4 个新关卡都属于第二层 ----
	for om_nm in ["寒冰防线", "亡灵军团", "龙族巢穴", "机甲巨兵"]:
		var om_lv := _level_named(om_nm)
		check(not om_lv.is_empty() and int(om_lv["layer"]) == GameLayers.LAYER_TWO,
				"新关卡「%s」属于第二层" % om_nm)

	# ---- 第二层怪物的「移动 / 攻击距离」调整 ----
	# 棋盘 6 行：敌方后排 = 第 0 行，我方前排 = 第 3 行，攻击按曼哈顿距离。
	# 所以第 0 行的单位要有攻程 3 才够得到我方前排，第 1 行要 2，第 2 行只要 1。
	# 原来后排大单位（攻程1 速1）被自家前排堵死、永远够不到人 → 按定位补 1 点距离。
	var om_dist_r := {
		1031: 3,   # 冰冻术士：后排也能覆盖我方前排
		1014: 2,   # 幼龙：中排直接喷到我方前排
		1061: 2,   # 爆裂机甲：中排自爆单位远程起爆
		9027: 2,   # 夜鸭：夜袭，从第 1 行扑前排
		9047: 3,   # 机械巨鸭（第二层 Boss）：本体终于能参战
	}
	for om_id_r: int in om_dist_r:
		check(om_repo.get_card(om_id_r).attack_range == om_dist_r[om_id_r],
				"二层怪物攻程：%d → %d" % [om_id_r, om_dist_r[om_id_r]])
	var om_dist_s := {
		1013: 2,   # 灰烬龙：巨兽绕过嘲讽墙压上
		1071: 2,   # 熔岩巨人：同上
		1051: 2,   # 亡灵领主：后排领主能绕路
		1050: 2,   # 腐化尸鬼：冲脸亡语单位甩开阻挡
		9026: 2,   # 陶瓷鸭：窑的产物一回合压上
	}
	for om_id_s: int in om_dist_s:
		check(om_repo.get_card(om_id_s).move_speed == om_dist_s[om_id_s],
				"二层怪物速：%d → %d" % [om_id_s, om_dist_s[om_id_s]])
	# 关卡 enemy_units 里写的 力/生/程/速 只是「文档」，实际打牌用的是 cards.json。
	# 两边必须同源，否则改了一边会静默失效 —— 这里锁死，漂移即失败。
	var om_drift := ""
	var om_lv_eff := 0
	for om_lvl2: Dictionary in GameLevels.builtin_levels():
		for om_u: Array in (om_lvl2["enemy_units"] as Array):
			var om_ucard := om_repo.get_card(int(om_u[0]))
			if om_ucard == null:
				om_drift += " %s:缺卡%d" % [om_lvl2["name"], int(om_u[0])]
				continue
			if om_ucard.group != "enemy":     # 图鉴分组：关卡单位必须在敌人图鉴里
				om_drift += " %s/%s(分组%s)" % [om_lvl2["name"], om_ucard.card_name, om_ucard.group]
			if om_ucard.power != int(om_u[2]) or om_ucard.health != int(om_u[3]) \
					or om_ucard.attack_range != int(om_u[4]) \
					or om_ucard.move_speed != int(om_u[5]):
				om_drift += " %s/%s" % [om_lvl2["name"], om_ucard.card_name]
		# 图鉴分组：敌方关卡效果同样必须落在敌人图鉴里（且被识别为「关卡效果」）
		for om_e in (om_lvl2.get("enemy_effects", []) as Array):
			om_lv_eff += 1
			var om_ecard := om_repo.get_card(int(om_e))
			if om_ecard == null:
				om_drift += " %s:缺关卡效果%d" % [om_lvl2["name"], int(om_e)]
			elif om_ecard.group != "enemy" or not om_ecard.is_level_effect():
				om_drift += " %s/关卡效果%d" % [om_lvl2["name"], int(om_e)]
	check(om_drift == "", "关卡 enemy_units 的 力/生/程/速 与 cards.json 同源（漂移:%s）" % om_drift)
	check(om_lv_eff == 7, "关卡共挂 7 个敌方关卡效果（4 + 使魔之力 9115 挂 2 个巫师关卡 + 恶魔使魔 9117 挂 1 个 Boss 关卡），且都属敌人图鉴（实际 %d）" % om_lv_eff)

	# ---- 二层强力怪物：一回合行动两次（2026-09-30 新增）----
	# 挑选三只「巨兽 / 领主」级单位赋予双动：后排也能一回合绕开前排再出手。
	var om_dbl := {1051: "亡灵领主", 1013: "灰烬龙", 1071: "熔岩巨人"}
	for om_id_d: int in om_dbl:
		var om_cd_d := om_repo.get_card(om_id_d)
		check(om_cd_d != null and om_cd_d.actions == 2,
				"二层强力怪物 %s(%d)：每回合行动两次（actions=2）" % [om_dbl[om_id_d], om_id_d])
		check(om_cd_d.effect_text.contains("每回合可以行动两次"),
				"二层强力怪物 %s(%d)：卡面标注双动" % [om_dbl[om_id_d], om_id_d])
	# 引擎侧生效：上场即 acts_left == 2；攻击一次后不横置、立即获得新一轮
	var om_act := _new_engine([], 20, 40)
	om_act.state.place(om_repo.get_card(1051), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	om_act.state.place(_card(8003, "农民", "盟友", 3, 3, 8),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	om_act.start_game()
	check(om_act.state.unit_at(Vector2i(2, 1)).acts_left == 2,
			"亡灵领主上场：acts_left == 2（本回合 2 轮行动）")
	om_act.current_side = GameEngine.SIDE_OPPONENT
	om_act.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var om_act_p: Placement = om_act.state.unit_at(Vector2i(2, 1))
	check(om_act_p != null and not om_act_p.tapped and om_act_p.acts_left == 1,
			"亡灵领主第一轮攻击后不横置，立即获得新一轮（剩 1 轮）")
	# 只给指定怪物：铁壁卫兵（坦克）仍单动；白狼 / 鸭子队长维持原有双动
	check(om_repo.get_card(1011).actions == 1,
			"铁壁卫兵仍是单动（actions=1，未误伤坦克）")
	check(om_repo.get_card(9031).actions == 2 and om_repo.get_card(9012).actions == 2,
			"白狼 / 鸭子队长维持原有双动（未被覆盖）")

	# 「凝视 / 一袋米抗几楼」已挪到第二层；第一层换成「奥秘之泉」，
	# 「遗忘之泉」是写进每一层事件表的全层通用事件。
	var ev_kinds_layer := GameLayers.event_kinds(GameLayers.LAYER_DEFAULT)
	check(ev_kinds_layer.size() == 6 and ev_kinds_layer.has("monster") \
			and ev_kinds_layer.has("treasure") and ev_kinds_layer.has("arcane") \
			and not ev_kinds_layer.has("gaze"),
			"第一层事件池：6 种子类型（怪物/低语/挣扎/奥秘之泉/遗忘之泉/卡牌宝箱；无凝视）")
	var l2_ev_kinds := GameLayers.event_kinds(GameLayers.LAYER_TWO)
	check(l2_ev_kinds.size() == 5,
			"第二层事件池：鸭梨山大 / 绝赞五换一 / 蓝色大肥鱼 + 凝视 + 遗忘之泉 = 5 种子类型")
	var pear_ev_kinds := l2_ev_kinds        # 旧用例里沿用的变量名（保持后文读到本地变量）
	check(l2_ev_kinds.has("gaze") and not ev_kinds_layer.has("gaze"),
			"鸭之凝视已改为第二层事件（第一层不再出 gaze）")
	check(GameLayers.event_name("gaze") == "鸭之凝视", "鸭之凝视事件的显示名（仍登记）")
	check(not l2_ev_kinds.has("monster") and not l2_ev_kinds.has("whisper")
			and not l2_ev_kinds.has("struggle") and not l2_ev_kinds.has("treasure"),
			"第二层事件池不含第一层基础事件（怪物/低语/挣扎/卡牌宝箱，不串层）")
	# 全层通用事件「遗忘之泉」：两层都有；「奥秘之泉」只在第一层
	check(ev_kinds_layer.has("oblivion") and l2_ev_kinds.has("oblivion"),
			"遗忘之泉是全层通用事件（第一层与第二层的事件池都有）")
	check(GameLayers.event_name("oblivion") == "遗忘之泉", "遗忘之泉事件的显示名")
	check(ev_kinds_layer.has("arcane") and not l2_ev_kinds.has("arcane"),
			"奥秘之泉只在第一层事件池（第二层不会串到）")
	check(GameLayers.event_name("arcane") == "奥秘之泉", "奥秘之泉事件的显示名")
	check(int(GameLayers.event_weights(GameLayers.LAYER_DEFAULT).get("arcane", 0)) > 0
			and int(GameLayers.event_weights(GameLayers.LAYER_TWO).get("gaze", 0)) > 0
			and int(GameLayers.event_weights(GameLayers.LAYER_TWO).get("oblivion", 0)) > 0,
			"奥秘之泉 / 二层凝视 / 遗忘之泉的权重 > 0（可被抽到）")
	check(pear_ev_kinds.has("pear") and not ev_kinds_layer.has("pear"),
			"鸭梨山大只在第二层事件池（第一层不含 pear，不串层）")
	check(GameLayers.event_name("pear") == "鸭梨山大", "鸭梨山大事件的显示名")
	check(pear_ev_kinds.has("hero") and not ev_kinds_layer.has("hero"),
			"绝赞五换一只在第二层事件池（第一层不含 hero，不串层）")
	check(GameLayers.event_name("hero") == "绝赞五换一", "绝赞五换一事件的显示名")
	check(pear_ev_kinds.has("bluefish") and not ev_kinds_layer.has("bluefish"),
			"蓝色大肥鱼只在第二层事件池（第一层不含 bluefish，不串层）")
	check(GameLayers.event_name("bluefish") == "蓝色大肥鱼", "蓝色大肥鱼事件的显示名")
	var bf_ev_w := GameLayers.event_weights(GameLayers.LAYER_TWO)
	check(int(bf_ev_w.get("bluefish", 0)) > 0,
			"蓝色大肥鱼在第二层事件权重 > 0（可被抽到）")
	var pear_ev_w := GameLayers.event_weights(GameLayers.LAYER_TWO)
	check(int(pear_ev_w.get("pear", 0)) > 0,
			"鸭梨山大在第二层事件权重 > 0（可被抽到）")
	var pear_seen := false
	var pear_rng := RandomNumberGenerator.new()
	for pear_i in 400:
		pear_rng.seed = 90000 + pear_i
		if GameLayers.roll_event_kind(GameLayers.LAYER_TWO, pear_rng) == "pear":
			pear_seen = true
			break
	check(pear_seen, "第二层事件抽取能掷出「鸭梨山大」（权重生效）")
	check(GameLayers.treasure_col(GameLayers.LAYER_DEFAULT) == RogueMap.TREASURE_COL,
			"第一层宝箱层列号与 RogueMap.TREASURE_COL 一致（第 %d 层）" % RogueMap.TREASURE_COL)
	check(GameLayers.treasure_col(GameLayers.LAYER_TWO) == RogueMap.TREASURE_COL,
			"第二层同样设宝箱层（第 %d 层）" % RogueMap.TREASURE_COL)
	check(GameLayers.layer_name(GameLayers.LAYER_DEFAULT) == "第一层",
			"层名显示：第一层")
	check(GameLayers.layer_name(GameLayers.LAYER_TWO) == "第二层", "层名显示：第二层")
	check(GameLayers.next_layer(GameLayers.LAYER_DEFAULT) == GameLayers.LAYER_TWO
			and GameLayers.next_layer(GameLayers.LAYER_TWO) == 0,
			"层推进：第一层 → 第二层 → 无（打完第二层 Boss 即通关）")
	check(GameLayers.treasure_col(9) == -1 and not GameLayers.has_events(9),
			"未配置的层：没有宝箱层、没有事件池（不会顺手拿到第一层的内容）")

	# 地图按层生成：第二层地图带第二层的层号，事件/宝箱层来自第二层专属内容
	var l2_rng := RandomNumberGenerator.new()
	l2_rng.seed = 424242
	var l2 := RogueMap.generate(l2_rng, GameLayers.LAYER_TWO)
	var l2_bad := false
	var l2_ev_bad := false
	var l2_total := 0
	var l2_event := false
	var l2_chest := false
	for l2_col in l2:
		for l2_node in l2_col:
			l2_total += 1
			if int(l2_node.get("layer", -1)) != GameLayers.LAYER_TWO:
				l2_bad = true
			if str(l2_node["type"]) == "event":
				l2_event = true
				# 对照**第二层事件池本身**判，而不是写死几个名字 ——
				# 第二层池里还有 gaze（鸭之凝视）与 oblivion（遗忘之泉，全层通用），
				# 写死白名单会漏掉它们，地图变长后这些事件一出现就误报。
				# 「不串第一层」由下面的 event_kinds(L1) 交集为空来保证。
				if not GameLayers.event_kinds(GameLayers.LAYER_TWO).has(
						str(l2_node.get("event_kind", ""))):
					l2_ev_bad = true
			if str(l2_node["type"]) == "chest":
				l2_chest = true
	check(not l2_bad, "第二层地图：每个节点都标记 layer = 2")
	check(not l2_ev_bad, "第二层地图：事件节点只出第二层事件池里的事件（不串第一层）")
	# 「不串第一层」要单独锁：第二层池里 oblivion 是**两层通用**的，光比对池子
	# 证明不了没串 —— 这里直接断言「只属于第一层的子类型」一个都不出现。
	var l2_only_l1 := ["monster", "whisper", "struggle", "arcane", "treasure"]
	var l2_leak := ""
	for l2_c in l2:
		for l2_n in l2_c:
			if str(l2_n["type"]) == "event" \
					and l2_only_l1.has(str(l2_n.get("event_kind", ""))):
				l2_leak = str(l2_n["event_kind"])
	check(l2_leak == "", "第二层地图：绝不出现第一层专属事件（本次泄漏：%s）"
			% ("无" if l2_leak == "" else l2_leak))
	check(l2_event and l2_chest,
			"第二层地图：会出事件节点（专属事件）与宝箱层")
	check(RogueMap.reachable_ids(l2).size() == l2_total,
			"第二层地图结构照常连通（%d 个节点）" % l2_total)

	# 多次生成第二层地图：事件节点只出第二层专属事件（绝不串到第一层）
	var l2_ev_ok := true
	var l2_ev_seen := {}
	var l2_ev_rng := RandomNumberGenerator.new()
	l2_ev_rng.randomize()
	for l2_i in 40:
		var l2m: Array = RogueMap.generate(l2_ev_rng, GameLayers.LAYER_TWO)
		for l2m_col in l2m:
			for l2m_node in l2m_col:
				if str(l2m_node["type"]) != "event":
					continue
				var l2m_kind := str(l2m_node.get("event_kind", ""))
				l2_ev_seen[l2m_kind] = true
				if not GameLayers.event_kinds(GameLayers.LAYER_TWO).has(l2m_kind):
					l2_ev_ok = false
	check(l2_ev_ok, "第二层地图：event_kind 全部取自第二层事件池（不串到第一层）")
	check(l2_ev_seen.has("pear") or l2_ev_seen.has("hero") or l2_ev_seen.has("bluefish"),
			"第二层地图多次生成：出鸭梨山大/绝赞五换一/蓝色大肥鱼专属事件")

	# ---- R68：同一张地图上事件子类型不重复（全出过一遍后才允许重复）----
	# roll_event_kind 传 used 时按「本轮候选 = 池子 - 已出过」抽；
	# 候选被抽空（全都出过一次）才清空 used 开新一轮。
	var r68_u := {}
	var r68_l1 := GameLayers.event_kinds(GameLayers.LAYER_DEFAULT)
	var r68_round1 := []
	for _i in r68_l1.size():
		r68_round1.append(GameLayers.roll_event_kind(GameLayers.LAYER_DEFAULT, l2_ev_rng, r68_u))
	var r68_uniq := {}
	for k in r68_round1:
		r68_uniq[k] = true
	check(r68_round1.size() == r68_uniq.size()
			and r68_uniq.size() == r68_l1.size(),
			"R68 事件不重复：连抽 %d 次得到 %d 种互不相同的事件（第一层池子正好 %d 种）"
			% [r68_round1.size(), r68_uniq.size(), r68_l1.size()])
	# 池子抽空后再抽 → 允许重复（清空 used 开新一轮），且仍然只出池子里的
	var r68_round2 := []
	for _i2 in r68_l1.size():
		var r68_k := GameLayers.roll_event_kind(GameLayers.LAYER_DEFAULT, l2_ev_rng, r68_u)
		r68_round2.append(r68_k)
		if not r68_l1.has(r68_k):
			r68_uniq["__bad__"] = true
	check(not r68_uniq.has("__bad__")
			and r68_round2.size() == r68_l1.size(),
			"R68 全部事件都出过一次后才允许重复（第二轮 %d 次仍是池内事件）" % r68_round2.size())
	# 不传 used（旧调用方式）→ 仍是纯按权重抽、不报错
	check(GameLayers.event_kinds(GameLayers.LAYER_TWO).has(
			GameLayers.roll_event_kind(GameLayers.LAYER_TWO, l2_ev_rng)),
			"R68 roll_event_kind 不传 used 时行为不变（按权重抽本层事件）")
	# 整张地图级别：**首轮**（事件节点数 ≤ 池子大小时）任何一种事件只出现一次。
	# 池子抽空后允许重复 —— 这正是需求里的「除非全都出现过了」，
	# 所以第二层（池子 5 种）出现 8 个事件节点的地图，第 6 个起重复是正确行为。
	var r68_map_ok := true
	var r68_map_repeat := ""
	var r68_map_rng := RandomNumberGenerator.new()
	var r68_max_first_round := 0
	for r68_m in 60:
		var r68_cols: Array = RogueMap.generate(r68_map_rng, GameLayers.LAYER_DEFAULT)
		var r68_cnt := {}
		var r68_pool_n: int = GameLayers.event_kinds(GameLayers.LAYER_DEFAULT).size()
		var r68_ev_total := 0
		for r68_c in r68_cols:
			for r68_n in r68_c:
				if str(r68_n["type"]) != "event":
					continue
				r68_ev_total += 1
				var r68_kind := str(r68_n.get("event_kind", ""))
				if r68_cnt.has(r68_kind) and r68_ev_total <= r68_pool_n:
					# 首轮内重复 = 违反「一轮不重复」
					r68_map_ok = false
					r68_map_repeat = "%s ×%d" % [r68_kind, int(r68_cnt[r68_kind]) + 1]
				r68_cnt[r68_kind] = int(r68_cnt.get(r68_kind, 0)) + 1
		r68_max_first_round = maxi(r68_max_first_round,
				mini(r68_ev_total, r68_pool_n))
	check(r68_map_ok, "R68 整图：60 张第一层地图上事件子类型均不重复（首个轮次内），违例 %s"
			% ("无" if r68_map_ok else r68_map_repeat))
	# 第二层同规则：首轮（≤5 个事件节点）不重复；超过池子大小时按「全都出过才重复」轮转
	var r68_l2_ok := true
	var r68_l2_bad := ""
	var r68_l2_pool_n: int = GameLayers.event_kinds(GameLayers.LAYER_TWO).size()
	var r68_l2_overflow := false     # 确实见到过「节点数 > 池子」的情况（说明轮转被验证到）
	for r68_m2 in 60:
		var r68_cols2: Array = RogueMap.generate(r68_map_rng, GameLayers.LAYER_TWO)
		var r68_cnt2 := {}
		var r68_seen2 := 0
		for r68_c2 in r68_cols2:
			for r68_n2 in r68_c2:
				if str(r68_n2["type"]) != "event":
					continue
				r68_seen2 += 1
				var r68_k2 := str(r68_n2.get("event_kind", ""))
				if r68_cnt2.has(r68_k2) and r68_seen2 <= r68_l2_pool_n:
					r68_l2_ok = false
					r68_l2_bad = "%s（第 %d 个事件节点）" % [r68_k2, r68_seen2]
				r68_cnt2[r68_k2] = int(r68_cnt2.get(r68_k2, 0)) + 1
		if r68_seen2 > r68_l2_pool_n:
			r68_l2_overflow = true
	check(r68_l2_ok, "R68 第二层地图：首轮 %d 种事件互不重复，违例 %s"
			% [r68_l2_pool_n, ("无" if r68_l2_ok else r68_l2_bad)])
	check(r68_l2_overflow,
			"R68 池子小于事件节点数时进入第二轮（第二层池 %d 种，本次样本里出现过 >%d 个事件节点的地图）"
			% [r68_l2_pool_n, r68_l2_pool_n])

	# ---- 肉鸽地图：14 层、连通、类型合法、宝箱层固定、固定休息层、路线休息/精英上限 ----
	var tcol := GameLayers.treasure_col(GameLayers.LAYER_DEFAULT)
	check(RogueMap.COLS == 14 and RogueMap.REST_COL == 9,
			"R69 地图规格：共 %d 层（起点 + 12 层 + Boss），固定休息层 = 第 %d 层"
			% [RogueMap.COLS, RogueMap.REST_COL])
	check(RogueMap.REST_COL != tcol and GameLayers.treasure_col(GameLayers.LAYER_TWO) \
			!= RogueMap.REST_COL,
			"R69 固定休息层不与任一层的宝箱层撞列（休息 %d / 宝箱 %d）"
			% [RogueMap.REST_COL, tcol])
	var map_layer_ok := true
	for trial in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = trial * 7919 + 13
		var cols := RogueMap.generate(rng, GameLayers.LAYER_DEFAULT)
		check(cols.size() == RogueMap.COLS,
				"地图 %d：共 %d 层（起点 + 12 层（含第 6 层宝箱层 + 第 9 层固定休息层）+ Boss）"
				% [trial, RogueMap.COLS])
		check(cols[0].size() == 1 and str(cols[0][0]["type"]) == "start",
				"地图 %d：起点 1 个起点节点（非战斗）" % trial)
		check(cols[RogueMap.COLS - 1].size() == 1
				and str(cols[RogueMap.COLS - 1][0]["type"]) == "boss",
				"地图 %d：最上层 1 个 Boss 节点" % trial)
		check(int(cols[0][0]["slot"]) == 2 and int(cols[cols.size() - 1][0]["slot"]) == 2,
				"地图 %d：起点与 Boss 横向居中（slot 2）" % trial)
		var col1_has_rest := false
		for n in cols[1]:
			if str(n["type"]) == "rest":
				col1_has_rest = true
		check(not col1_has_rest, "地图 %d：第一层不出现休息点" % trial)
		# 宝箱层：tcol 那一列整层都是 chest，其它层一个都没有；
		# 顺带校验每个节点都带着本图所属的层。
		var chest_ok := true
		for chk_col in cols.size():
			for chk_node in cols[chk_col]:
				if int(chk_node.get("layer", -1)) != GameLayers.LAYER_DEFAULT:
					map_layer_ok = false
				if (str(chk_node["type"]) == "chest") != (chk_col == tcol):
					chest_ok = false
		check(chest_ok, "地图 %d：第 %d 列固定为宝箱层，且该层全是宝箱（别处没有）"
				% [trial, tcol])
		check((cols[tcol] as Array).size() >= RogueMap.MIN_NODES,
				"地图 %d：宝箱层至少 %d 个节点" % [trial, RogueMap.MIN_NODES])
		# **R69 固定休息层**：第 9 层整层必定是休息（所有路线都经过、都能回血），
		# 且它**前后两层（第 8、10）一个休息都不能有** —— 否则连成两连休。
		# 这条是「逐节点看前驱」的原有规则**管不到**的：第 8 层的前驱在第 7 层，
		# 只有显式禁止才拦得住。
		var rc_ok := true
		for rc_node in cols[RogueMap.REST_COL]:
			if str(rc_node["type"]) != "rest":
				rc_ok = false
		var rc_adj_ok := true
		for rc_c in [RogueMap.REST_COL - 1, RogueMap.REST_COL + 1]:
			for rc_node2 in cols[rc_c]:
				if str(rc_node2["type"]) == "rest":
					rc_adj_ok = false
		check(rc_ok and (cols[RogueMap.REST_COL] as Array).size() >= RogueMap.MIN_NODES,
				"地图 %d：第 %d 层整层固定为休息（必定能回血），且不少于 %d 个节点"
				% [trial, RogueMap.REST_COL, RogueMap.MIN_NODES])
		check(rc_adj_ok, "地图 %d：固定休息层前后两层（第 %d、%d 层）不出休息（避免两连休）"
				% [trial, RogueMap.REST_COL - 1, RogueMap.REST_COL + 1])
		var reach := RogueMap.reachable_ids(cols)
		var total := 0
		for col_nodes in cols:
			total += col_nodes.size()
		check(reach.size() == total, "地图 %d：全部 %d 个节点从起点可达" % [trial, total])
		# 每层 2~5 个节点（起点/Boss 除外，不留单节点层）、槽位不重复且在 0~4；
		# 连边严格逐层；直线不交叉
		var size_ok := true
		var slots_ok := true
		var adjacent_only := true
		var no_cross := true
		for col in cols.size():
			var cnt: int = (cols[col] as Array).size()
			if col == 0 or col == cols.size() - 1:
				if cnt != 1:
					size_ok = false
			elif cnt < RogueMap.MIN_NODES or cnt > RogueMap.MAX_NODES:
				size_ok = false
			var seen_slots := {}
			for node in cols[col]:
				var s := int(node.get("slot", -1))
				if s < 0 or s > 4 or seen_slots.has(s):
					slots_ok = false
				seen_slots[s] = true
		check(size_ok, "地图 %d：起点/Boss 各 1 个，中间层 %d~%d 个节点（不存在单节点层）"
				% [trial, RogueMap.MIN_NODES, RogueMap.MAX_NODES])
		check(slots_ok, "地图 %d：每层槽位 0~4 且互不重复（均衡分布）" % trial)
		for col in range(cols.size() - 1):
			var edges: Array = []   # [源 slot 名次(row), 目标 slot 名次(row)]
			for a in cols[col]:
				for nid2 in a["next"]:
					var tgt: Dictionary = {}
					for b in cols[col + 1]:
						if int(b["id"]) == int(nid2):
							tgt = b
					if tgt.is_empty():
						adjacent_only = false
						continue
					edges.append([int(a["row"]), int(tgt["row"])])
			for ea in edges:
				for eb in edges:
					# 源 slot 递增时目标 slot 必须不递减，否则直线相交
					if int(ea[0]) < int(eb[0]) and int(ea[1]) > int(eb[1]):
						no_cross = false
		check(adjacent_only, "地图 %d：连边只指向相邻下一层（不跳跃不返回）" % trial)
		check(no_cross, "地图 %d：连线为直线且互不交叉" % trial)
		var types_ok := true
		var no_preset_level := true
		var caps_ok := true
		for col_nodes in cols:
			for node in col_nodes:
				if not RogueMap.TYPE_LABELS.has(str(node["type"])):
					types_ok = false
				# 关卡不预先写在地图上（进入节点时才动态决定）
				if str(node["type"]) in ["battle", "elite", "boss"] \
						and not (node["level"] as Dictionary).is_empty():
					no_preset_level = false
				# rest_cnt/elite_cnt = 起点到该节点路径的最大累计数
				# 全部 ≤ 3 ⇒ 任意一条完整路线最多 3 休息 / 3 精英
				if int(node.get("rest_cnt", 0)) > RogueMap.REST_CAP \
						or int(node.get("elite_cnt", 0)) > RogueMap.ELITE_CAP:
					caps_ok = false
		check(types_ok, "地图 %d：节点类型全部合法" % trial)
		check(no_preset_level, "地图 %d：地图节点不预写关卡（动态难度）" % trial)
		check(caps_ok, "地图 %d：任意路线休息/精英 ≤ 3" % trial)
		check(map_layer_ok, "地图 %d：每个节点都标记了所属层（第一层）" % trial)
		#休息不连续：任何一条边上都不能两端都是休息
		#（玩家能连着点两层休息就太廉价了；R69 的固定休息层也受这条约束）
		var id_type := {}
		for c in cols:
			for n in c:
				id_type[int(n["id"])] = str(n["type"])
		var rest_adjacent := false
		for c in cols:
			for n in c:
				if str(n["type"]) != "rest":
					continue
				for nid2 in n["next"]:
					if str(id_type.get(int(nid2), "")) == "rest":
						rest_adjacent = true
		check(not rest_adjacent, "地图 %d：休息节点不会连续出现（相邻两层都不是休息）" % trial)
		# **固定休息层必然占用休息额度**：经过第 9 层的路线上，休息计数至少为 1，
		# 且整条路线仍 ≤ REST_CAP（所以 9 之后最多只剩 REST_CAP-1 次随机休息）。
		var fixed_cnt_ok := true
		for fc_node in cols[RogueMap.REST_COL]:
			if int(fc_node.get("rest_cnt", 0)) < 1:
				fixed_cnt_ok = false
		check(fixed_cnt_ok,
				"地图 %d：固定休息层的 rest_cnt ≥ 1（那一格已占用 1 次休息额度）" % trial)
		if fails > 0:
			break

	# ---- run 流程：开局 / 走节点 / 卡组增长 / 战斗记录持久化 ----
	RunState.end_run()
	var run_rng := RandomNumberGenerator.new()
	run_rng.randomize()
	RunState.start_run(RogueMap.generate(run_rng))
	check(RunState.run_active and RunState.hp == 50 and RunState.max_hp == 50,
			"开局：满血 50/50")
	# ---- 道具：起点三选一 / 即时效果 / 卡组编辑 ----
	check(RunState.relic_choice.size() == 3, "开局：初始道具三选一（3 个候选）")
	var relic_uniq := {}
	for rid: int in RunState.relic_choice:
		relic_uniq[rid] = true
	check(relic_uniq.size() == 3, "初始道具候选互不重复")
	var relic_repo := RelicRepo.load_json()
	check(relic_repo.initial_ids().size() == 5 and relic_repo.get_relic(6001) != null
			and relic_repo.get_relic(6004) != null and relic_repo.get_relic(6021) != null,
			"道具库：5 个初始道具全部加载（+ 栅栏修复术 6021）")
	RunState.choose_start_relic(6001)
	check(RunState.has_relic(6001) and RunState.relic_choice.is_empty()
			and RunState.max_hp == 56 and RunState.hp == 56,
			"类固醇：获得即最大生命 +6（50→56）")
	# ---- 动态难度：前 2 场简单、之后困难（普通与精英各自计数）----
	var nb1 := RunState.next_level({"type": "battle"})
	check(int(nb1["tier"]) == GameLevels.TIER_NORMAL_EASY,
			"第 1 场普通战斗：普通敌人-简单")
	RunState.on_battle_won("battle")
	var nb2 := RunState.next_level({"type": "battle"})
	check(int(nb2["tier"]) == GameLevels.TIER_NORMAL_EASY
			and str(nb2["name"]) != str(nb1["name"]),
			"第 2 场普通战斗：仍为简单，且关卡与本局前面不重复")
	RunState.on_battle_won("battle")
	check(int(RunState.next_level({"type": "battle"})["tier"])
			== GameLevels.TIER_NORMAL_HARD, "第 3 场普通战斗：普通敌人-困难")
	var ne1 := RunState.next_level({"type": "elite"})
	check(int(ne1["tier"]) == GameLevels.TIER_ELITE_EASY, "第 1 场精英：精英敌人-简单")
	RunState.on_battle_won("elite")
	check(int(RunState.next_level({"type": "elite"})["tier"])
			== GameLevels.TIER_ELITE_EASY, "第 2 场精英：仍为精英敌人-简单")
	RunState.on_battle_won("elite")
	check(int(RunState.next_level({"type": "elite"})["tier"])
			== GameLevels.TIER_ELITE_HARD, "第 3 场精英：精英敌人-困难")
	check(int(RunState.next_level({"type": "boss"})["tier"]) == GameLevels.TIER_BOSS,
			"Boss 节点：固定 Boss 关")
	# 地图上 Boss 节点上方的名牌（map_scene._boss_name_chip）取自 **RunState.boss_pick**
	#（R63：同层可能有多个 Boss，开局用 run_rng 摇定一个），必须与实际走进去的那只
	# 是同一只，否则地图会「说谎」。这里 start_run 已跑过 → boss_pick 一定有值。
	check(not RunState.boss_pick.is_empty()
			and str(RunState.boss_pick["name"])
			== str(RunState.next_level({"type": "boss"})["name"]),
			"Boss 名牌 = 实际进入的 Boss 关（本层从 boss_pool 摇定的那只）")
	check(RunState.deck_ids.size() == 13, "初始卡组 13 张（含角色卡熊×1）")
	check(RunState.current_node_id == int(RunState.map_columns[0][0]["id"]),
			"起点 = 第 0 列唯一节点")
	var avail := RunState.available_nodes()
	check(not avail.is_empty() and int(avail[0]["col"]) == 1,
			"从起点可选第 1 列节点")
	var first_battle: Dictionary = RunState.map_columns[0][0]
	RunState.advance(int(avail[0]["id"]))
	check(RunState.cleared_ids.has(int(first_battle["id"]))
			and RunState.current_node_id == int(avail[0]["id"]),
			"前进：原节点标记完成，当前位置更新")
	var deck_cnt := RunState.deck_ids.size()
	RunState.add_card(9007)
	var rebuilt := RunState.build_deck(repo)
	check(RunState.deck_ids.size() == deck_cnt + 1 and rebuilt.size() == deck_cnt + 1
			and rebuilt.any(func(c: CardData): return c.id == 9007),
			"奖励卡加入卡组并可重建牌库")
	var summary := RunState.deck_summary(repo)
	check(not summary.is_empty() and int(summary[0]["count"]) == 5,
			"卡组摘要：按名称计数（木栅栏×5）")
	# ---- 道具即时效果：失忆药水（删卡）/ 源数之力（改造为随机奖励卡）----
	var before_del := RunState.deck_ids.size()
	RunState.gain_relic(6004)
	check(RunState.pending_relic == 6004, "失忆药水：获得后进入卡组选择")
	check(RunState.delete_deck_card(0) and RunState.deck_ids.size() == before_del - 1
			and RunState.pending_relic == -1, "失忆药水：删除一张卡后解除待选")
	# 源数之力（6002）：获得时代价 = 失去 5 点最大生命（当前生命同 -5）
	RunState.reset(50)
	var hp_before_sp := RunState.max_hp
	RunState.gain_relic(6002)
	check(RunState.pending_relic == 6002, "源数之力：获得后进入卡组选择")
	check(RunState.max_hp == hp_before_sp - 5 and RunState.hp == hp_before_sp - 5
			and RunState.lose_max_hp(0) == 0,
			"源数之力：获得时失去 5 点最大生命（%d/%d → %d/%d）" % [
				hp_before_sp, hp_before_sp, RunState.max_hp, RunState.hp])
	var before_tr := RunState.deck_ids.size()
	var tr := RunState.transform_deck_card(repo, 0)
	check(bool(tr["ok"]) and RunState.deck_ids.size() == before_tr
			and int(tr["new_id"]) != int(tr["old_id"]) and RunState.pending_relic == -1,
			"源数之力：选中的卡变成随机奖励卡")
	# ---- 失去最大生命：当前生命同步下降 / 不低于 0 / 至少保留 1 点上限 ----
	RunState.reset(50)
	check(RunState.lose_max_hp(5) == 5 and RunState.max_hp == 45 and RunState.hp == 45,
			"失去最大生命：满血 50/50 → 45/45")
	RunState.take_damage(15)                 # 30/45
	check(RunState.lose_max_hp(5) == 5 and RunState.max_hp == 40 and RunState.hp == 25,
			"失去最大生命：残血 30/45 → 25/40（当前生命同步 -5）")
	RunState.reset(5)
	check(RunState.lose_max_hp(5) == 4 and RunState.max_hp == 1 and RunState.hp == 1,
			"失去最大生命：至少保留 1 点最大生命（5/5 → 1/1）")
	check(RunState.lose_max_hp(3) == 0 and RunState.max_hp == 1,
			"失去最大生命：已到下限时不再扣（返回 0）")
	RunState.reset()
	var rec_path := RunState.RECORDS_PATH
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rec_path))
	RunState.record_battle(repo, "测试战斗", 0, true, 17)
	var recs := RunState.load_records()
	check(recs.size() == 1 and bool(recs[0]["win"]) and int(recs[0]["final_hp"]) == 17
			and (recs[0]["deck"] as Array).size() > 0,
			"战斗记录：写入并持久化（胜负/血量/卡组内容）")
	RunState.end_run()
	check(not RunState.run_active and RunState.deck_ids.is_empty(),
			"end_run：清空 run 状态（记录文件保留）")

	# ---- 第二层：起始道具池 / 满血接层 / 层推进 ----
	var l2repo := RelicRepo.load_json()
	var l2ids := l2repo.layer2_ids()
	check(l2ids.size() == 5 and l2ids.has(6014) and l2ids.has(6015)
			and l2ids.has(6016) and l2ids.has(6017) and l2ids.has(6018),
			"第二层起始道具池 5 件（黄桃罐头/鸭语耳环/冰淇淋与汽水/重鸭/生蛋鸭）")
	var l2_overlap := false
	for rid in l2ids:
		if l2repo.initial_ids().has(rid) or l2repo.reward_ids().has(rid) \
				or l2repo.event_ids().has(rid):
			l2_overlap = true
	check(not l2_overlap, "第二层起始道具不进初始池 / 奖励池 / 事件池")
	check(l2repo.get_relic(6016).source == RelicData.SRC_LAYER2
			and l2repo.get_relic(6016).source_label() == "二层道具",
			"第二层道具来源标记 = 二层（徽章色与其它池区分）")
	var run2_rng := RandomNumberGenerator.new()
	run2_rng.seed = 20260930
	RunState.end_run()
	RunState.start_run(RogueMap.generate(run2_rng, GameLayers.LAYER_DEFAULT),
			GameLayers.LAYER_DEFAULT)
	var c1_ok := true
	for rid1 in RunState.relic_choice:
		if not l2repo.initial_ids().has(rid1):
			c1_ok = false
	check(c1_ok and RunState.relic_choice.size() == 3,
			"第一层起始候选全部来自初始道具池（3 个）")
	# 带一些跨层状态，验证推进后是否保留
	RunState.add_card(9007)
	RunState.gain_relic(6005)
	RunState.take_damage(30)              # 残血
	check(RunState.hp < RunState.max_hp,
			"接层前先把自己打残（%d/%d）" % [RunState.hp, RunState.max_hp])
	var deck_before_layer := RunState.deck_ids.size()
	var l2_start := RunState.advance_layer(GameLayers.LAYER_TWO)
	check(RunState.current_layer == GameLayers.LAYER_TWO
			and RunState.hp == RunState.max_hp and RunState.max_hp > 0,
			"进入第二层：恢复所有生命（满血 %d/%d）" % [RunState.hp, RunState.max_hp])
	check(l2_start == int(RunState.map_columns[0][0]["id"])
			and int(RunState.map_columns[0][0].get("layer", -1)) == GameLayers.LAYER_TWO,
			"进入第二层：生成本层地图，起点节点 layer = 2")
	check(RunState.relic_choice.size() == 3, "第二层起始：重新掷出道具三选一")
	var c2_from_pool := 0
	for rid2 in RunState.relic_choice:
		if l2ids.has(rid2):
			c2_from_pool += 1
	check(c2_from_pool == 3, "第二层起始候选全部来自二层起始池（3 件）")
	check(RunState.deck_ids.size() == deck_before_layer and RunState.has_relic(6005),
			"进入第二层：卡组与道具跨层保留")
	RunState.choose_start_relic(RunState.relic_choice[0])
	check(RunState.relic_choice.is_empty(), "第二层起始道具：选定后清空候选")
	RunState.relics = []
	RunState.reset(50)
	RunState.gain_relic(6017)
	check(RunState.max_hp == 56 and RunState.hp == 56, "重鸭：拾起时最大生命 +6（50 → 56）")
	RunState.relics = []
	RunState.end_run()

	# ---- 白魔法师（9021）：回合开始治疗生命值百分比最低的己方单位 ----
	var wm_deck: Array[CardData] = []
	for i in 8:
		wm_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var eng_wm := _new_engine(wm_deck, 20, 20, -1, false)
	eng_wm.start_game()
	var wm_p := eng_wm.state.place(repo.get_card(9021), Vector2i(0, 1),
			GameEngine.SIDE_OPPONENT)
	var wm_k1 := eng_wm.state.place(repo.get_card(9001), Vector2i(2, 0),
			GameEngine.SIDE_OPPONENT)
	var wm_k2 := eng_wm.state.place(repo.get_card(9001), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	wm_k1.health = 10          # 10/30 = 33% ← 百分比最低
	wm_k2.health = 20          # 20/30 = 67%
	eng_wm.end_turn()          # → 对手回合开始 → 治疗
	check(wm_p.card.traits.has("治疗") and wm_p.card.value == 10,
			"白魔法师：带「治疗」trait，强度 10（引擎按 trait 识别，不写死 id）")
	check(wm_k1.health == 20 and wm_k2.health == 20,
			"白魔法师：回合开始治疗生命%最低的己方单位 +10（10 → 20，另一只不动）")
	# 按「百分比」而非「绝对血量」挑目标：75% 的小熊不动，67% 的骑士被治满
	var eng_wm2 := _new_engine(wm_deck, 20, 20, -1, false)
	eng_wm2.start_game()
	eng_wm2.state.place(repo.get_card(9021), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var wm_bear := eng_wm2.state.place(_card(9101, "小熊", "盟友", 1, 0, 4),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var wm_k3 := eng_wm2.state.place(repo.get_card(9001), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	wm_bear.health = 3         # 3/4 = 75%
	wm_k3.health = 20          # 20/30 = 67% ← 百分比最低（绝对值反而更高）
	eng_wm2.end_turn()
	check(wm_bear.health == 3 and wm_k3.health == 30,
			"白魔法师：按生命「百分比」挑目标（75% 小熊不治，67% 骑士治满）")

	# ---- 黄桃罐头（6014）：每次战斗结束回复 4 点生命 ----
	var eng_pc := _new_engine(wm_deck, 20, 20, -1, false)
	eng_pc.self_relics = [6014]
	eng_pc.start_game()
	eng_pc.state.hp_self = 10
	check(eng_pc.battle_end_heal() == 4 and eng_pc.state.hp_self == 14,
			"黄桃罐头：战斗结束回复 4 点生命（10 → %d）" % eng_pc.state.hp_self)
	var eng_pc2 := _new_engine(wm_deck, 20, 20, -1, false)
	eng_pc2.self_relics = [6014]
	eng_pc2.start_game()
	eng_pc2.state.hp_self = 18
	eng_pc2.battle_end_heal()
	check(eng_pc2.state.hp_self == 20, "黄桃罐头：回复不超过上限（18 + 4 → 20）")
	var eng_pc3 := _new_engine(wm_deck, 20, 20, -1, false)
	eng_pc3.start_game()
	eng_pc3.state.hp_self = 10
	check(eng_pc3.battle_end_heal() == 0 and eng_pc3.state.hp_self == 10,
			"黄桃罐头：没有这件道具时战斗结束不回血")
	var eng_pc4 := _new_engine(wm_deck, 20, 20, -1, false)
	eng_pc4.self_relics = [6014]
	eng_pc4.start_game()
	eng_pc4.state.place(_card(9016, "骑兵", "盟友", 4, 6, 12, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	eng_pc4.state.hp_self = 10
	eng_pc4.move(Vector2i(4, 1), Vector2i(2, 1))
	check(eng_pc4.state.hp_self == 10, "黄桃罐头：改版后移动不再回血（只按战斗结算）")

	# ---- 道具「栅栏修复术」（6021）：【栅栏】卡可以打在已有栅栏的格子上 → 合并 ----
	var fp_relics := RelicRepo.load_json()
	var fp_repo := CardRepo.load_json()
	check(fp_relics.get_relic(6021) != null
			and fp_relics.get_relic(6021).relic_name == "栅栏修复术"
			and fp_relics.get_relic(6021).is_initial()
			and fp_relics.initial_ids().has(6021),
			"道具「栅栏修复术」6021：初始道具（起点三选一）")
	check(not fp_relics.reward_ids().has(6021) and not fp_relics.event_ids().has(6021) \
			and not fp_relics.layer2_ids().has(6021),
			"栅栏修复术：只在初始池，不进奖励池 / 事件池 / 二层池")
	check(fp_repo.get_card(8001).traits.has("栅栏")
			and fp_repo.get_card(9072).traits.has("栅栏"),
			"木栅栏 8001 / 铁栅栏 9072 都带「栅栏」trait")
	check(not fp_repo.get_card(8003).traits.has("栅栏")
			and not fp_repo.get_card(9019).traits.has("栅栏"),
			"农民 8003 / 箭塔 9019 不是栅栏卡")

	var fp_e := _new_engine([], 20, 20, -1, false)
	fp_e.self_relics = [6021]
	fp_e.start_game()
	var fp_lib: CardData = fp_repo.get_card(8001)     # 卡库里的共享实例（直接摆上场）
	var fp_pl := fp_e.state.place(fp_lib, Vector2i(4, 1), GameEngine.SIDE_SELF)
	var fp_hand: CardData = CardData.from_dict(fp_repo.get_card(8001).to_dict())
	fp_e.state.hand = [fp_hand]
	fp_e.state.energy = 5
	check(fp_e.is_fence_card(fp_hand) and not fp_e.is_fence_card(fp_repo.get_card(8003)),
			"栅栏判定：木栅栏是栅栏卡、农民不是")
	check(fp_e.fence_merge_allowed(fp_hand), "栅栏修复术：持道具 + 手持栅栏 → 可叠")
	check(fp_e.fence_merge_target(Vector2i(4, 1), fp_hand),
			"栅栏修复术：己方栅栏格 = 合法「叠栅栏」目标")
	check(not fp_e.fence_merge_target(Vector2i(4, 0), fp_hand),
			"栅栏修复术：空格不算叠（走正常放置）")
	check(not fp_e.fence_merge_target(Vector2i(4, 1), fp_repo.get_card(8003)),
			"栅栏修复术：手里不是栅栏卡时不能叠")
	var fp_res := fp_e.play_from_hand(0, Vector2i(4, 1))
	check(fp_res == fp_pl and fp_pl.health == 12 and fp_pl.card.health == 12,
			"叠栅栏：6 + 6 → 同一格合成 12 血（不新建单位）")
	check(fp_e.state.hand.is_empty() and fp_e.state.energy == 3,
			"叠栅栏：手牌消耗 1 张、支付木栅栏的 2 费")
	check(fp_lib.health == 6,
			"叠栅栏：卡库里共享的木栅栏实例未被改（仍 6 血）")

	# 残血加固：当前生命 = 残血 + 新卡满血；上限同步相加
	var fp_e2 := _new_engine([], 20, 20, -1, false)
	fp_e2.self_relics = [6021]
	fp_e2.start_game()
	var fp_pl2 := fp_e2.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	fp_pl2.health = 3
	fp_e2.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_e2.state.energy = 5
	fp_e2.play_from_hand(0, Vector2i(4, 2))
	check(fp_pl2.health == 9 and fp_pl2.card.health == 12,
			"叠栅栏：残血墙 3/6 再叠一张满血 6 → 当前 9、上限 12")

	# 木栅栏 叠 铁栅栏：特性取并集 → 合并后的墙继续「替 HP 承伤」
	var fp_e3 := _new_engine([], 20, 20, -1, false)
	fp_e3.self_relics = [6021]
	fp_e3.start_game()
	var fp_pl3 := fp_e3.state.place(CardData.from_dict(fp_repo.get_card(9072).to_dict()),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	fp_e3.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_e3.state.energy = 5
	fp_e3.play_from_hand(0, Vector2i(4, 0))
	check(fp_pl3.health == 18 and fp_pl3.card.traits.has("铁栅栏") \
			and fp_pl3.card.traits.has("栅栏"),
			"叠栅栏：木栅栏叠到铁栅栏 → 18 血且保留「铁栅栏」特性")
	check(fp_e3.absorbs_for_hp(fp_pl3),
			"叠栅栏：合并后的墙仍替 HP 承伤（与森林守护同一绿环）")
	check(fp_pl3.card.id == 9072,
			"叠栅栏：卡面身份沿用场上那张（铁栅栏），不是新打出的木栅栏")

	# 没有道具 → 不放行（栅栏格不是合法落点）
	var fp_e4 := _new_engine([], 20, 20, -1, false)
	fp_e4.self_relics = []
	fp_e4.start_game()
	fp_e4.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var fp_hand4: CardData = CardData.from_dict(fp_repo.get_card(8001).to_dict())
	check(not fp_e4.fence_merge_allowed(fp_hand4) \
			and not fp_e4.fence_merge_target(Vector2i(4, 1), fp_hand4),
			"没有栅栏修复术：栅栏格不是合法落点（维持原规则）")
	check(fp_e4.is_fence_card(fp_hand4),
			"「栅栏」trait 与道具无关：判定本身不受是否持道具影响")

	# ---- R67：栅栏修复术加的血**只在场上有效**，离场还原 ----
	# 之前 _merge_fence 把加血烤进了 CardData.health，而 _destroy 直接把那张卡丢进弃牌区
	# → 洗回牌组再抽到就是永久加血的「超栅栏」。现在离场走 _card_leaving_field 还原。
	var fp_r := _new_engine([], 20, 20, -1, false)
	fp_r.self_relics = [6021]
	fp_r.start_game()
	var fp_r_pl := fp_r.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_r.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_r.state.energy = 5
	fp_r.play_from_hand(0, Vector2i(4, 1))
	check(fp_r_pl.card.health == 12 and fp_r_pl.fence_bonus_hp == 6,
			"R67 叠栅栏：场上仍是 12 血，记 fence_bonus_hp=%d" % fp_r_pl.fence_bonus_hp)
	fp_r._destroy(Vector2i(4, 1))
	var fp_r_disc: CardData = fp_r.state.discard[fp_r.state.discard.size() - 1]
	check(fp_r_disc != null and fp_r_disc.health == 6,
			"R67 离场还原：进弃牌区的那张恢复原血 6（实际 %d）"
			% (fp_r_disc.health if fp_r_disc != null else -1))
	# 弃牌区洗回牌组再抽到 → 上场仍是 6 血（加血没有跟到卡组里）
	fp_r.state.deck.clear()
	fp_r.state.deck.append(fp_r_disc)
	var fp_r_again: Placement = fp_r.state.place(fp_r.state.deck[0], Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(fp_r_again.health == 6 and fp_r_again.card.health == 6
			and fp_r_again.fence_bonus_hp == 0,
			"R67 还原后重新上场：6/6 血、bonus=0（实际 %d/%d，bonus %d）"
			% [fp_r_again.health, fp_r_again.card.health, fp_r_again.fence_bonus_hp])
	# 卡库共享实例自始至终没被动过
	check(fp_repo.get_card(8001).health == 6,
			"R67 离场还原：卡库里的木栅栏仍是 6 血")
	# 没叠加过的普通栅栏离场 → 行为完全不变（零拷贝交出原卡）
	var fp_r2 := _new_engine([], 20, 20, -1, false)
	fp_r2.start_game()
	var fp_r2_pl := fp_r2.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_r2._destroy(Vector2i(4, 1))
	var fp_r2_disc: CardData = fp_r2.state.discard[fp_r2.state.discard.size() - 1]
	check(fp_r2_disc != null and fp_r2_disc.health == 6 and fp_r2_pl.fence_bonus_hp == 0,
			"R67 未叠加的栅栏：离场后仍是 6 血（行为不变）")
	# 连叠三张：bonus 累计 12，离场后从 18 还原回 6
	var fp_r3 := _new_engine([], 20, 20, -1, false)
	fp_r3.self_relics = [6021]
	fp_r3.start_game()
	var fp_r3_pl := fp_r3.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	for _i in 2:
		fp_r3.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
		fp_r3.state.energy = 5
		fp_r3.play_from_hand(0, Vector2i(4, 1))
	check(fp_r3_pl.card.health == 18 and fp_r3_pl.fence_bonus_hp == 12,
			"R67 连叠两次：18 血、bonus 累计 %d" % fp_r3_pl.fence_bonus_hp)
	fp_r3._destroy(Vector2i(4, 1))
	var fp_r3_disc: CardData = fp_r3.state.discard[fp_r3.state.discard.size() - 1]
	check(fp_r3_disc != null and fp_r3_disc.health == 6,
			"R67 连叠两次后离场：18 → 还原成 6（实际 %d）"
			% (fp_r3_disc.health if fp_r3_disc != null else -1))
	# 敌方单位离场不产生还原卡（走「移出场外」分支，本来就不进弃牌区）
	var fp_r4 := _new_engine([], 20, 20, -1, false)
	fp_r4.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	fp_r4._destroy(Vector2i(1, 1))
	check(fp_r4.state.discard.is_empty(),
			"R67 敌方栅栏离场不进弃牌区（还原逻辑只影响我方）")

	# ---- R67b：叠加时**新加的特性**同样只在场上有效，离场还原 ----
	# 木栅栏 8001 = [工事, 防御, 栅栏]，铁栅栏 9072 = [工事, 铁栅栏, 栅栏]。
	# 之前取并集会把「铁栅栏」永久留在弃牌区那张 id=8001 的木栅栏上 = 替 HP 承伤被白嫖。
	var fp_t := _new_engine([], 20, 20, -1, false)
	fp_t.self_relics = [6021]
	fp_t.start_game()
	var fp_t_pl := fp_t.state.place(CardData.from_dict(fp_repo.get_card(8001).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_t.state.hand = [CardData.from_dict(fp_repo.get_card(9072).to_dict())]
	fp_t.state.energy = 5
	fp_t.play_from_hand(0, Vector2i(4, 1))
	check(fp_t_pl.card.traits.has(GameEngine.IRON_FENCE_TRAIT)
			and fp_t_pl.fence_bonus_traits.has(GameEngine.IRON_FENCE_TRAIT),
			"R67b 叠栅栏：场上那堵墙**当场**拿到「铁栅栏」特性（替 HP 承伤立刻生效）")
	fp_t._destroy(Vector2i(4, 1))
	var fp_t_disc: CardData = fp_t.state.discard[fp_t.state.discard.size() - 1]
	check(fp_t_disc != null and not fp_t_disc.traits.has(GameEngine.IRON_FENCE_TRAIT),
			"R67b 离场还原：弃牌区那张木栅栏不再带「铁栅栏」（实际 %s）"
			% str(fp_t_disc.traits if fp_t_disc != null else null))
	check(fp_t_disc != null and fp_t_disc.traits.has("工事")
			and fp_t_disc.traits.has("防御") and fp_t_disc.traits.has("栅栏"),
			"R67b 还原要精确：木栅栏**原有**的三个特性都还在（实际 %s）"
			% str(fp_t_disc.traits if fp_t_disc != null else null))
	# 洗回牌组重新上场：还是原血 + 没有偷来的特性（不能靠「搁置一张」绕过还原）
	fp_t.state.deck.clear()
	fp_t.state.deck.append(fp_t_disc)
	var fp_t_again: Placement = fp_t.state.place(fp_t.state.deck[0], Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(not fp_t_again.card.traits.has(GameEngine.IRON_FENCE_TRAIT)
			and fp_t_again.fence_bonus_traits.is_empty(),
			"R67b 还原后重新上场：没有「铁栅栏」、bonus 列表为空（实际 %s）"
			% str(fp_t_again.card.traits))
	# 卡库共享实例自始至终没被污染
	check(not fp_repo.get_card(8001).traits.has(GameEngine.IRON_FENCE_TRAIT)
			and not fp_repo.get_card(9072).traits.has("防御"),
			"R67b 卡库的两张栅栏 traits 从未被合并改写（8001=%s / 9072=%s）"
			% [str(fp_repo.get_card(8001).traits), str(fp_repo.get_card(9072).traits)])
	# **共享引用陷阱**：`CardData.from_dict` 的 traits 是同一个 Array 对象，
	# 不切断就会「场上摆的那张」与「卡库那张」互相改写（合并时污染卡库、
	# 离场还原时把场上那堵墙的 traits 也擦掉）。锁死：离场后场上那张不受影响。
	var fp_t5 := _new_engine([], 20, 20, -1, false)
	fp_t5.self_relics = [6021]
	fp_t5.start_game()
	fp_t5.state.place(CardData.from_dict(fp_repo.get_card(9072).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_t5.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_t5.state.energy = 5
	fp_t5.play_from_hand(0, Vector2i(4, 1))
	var fp_t5_out: CardData = fp_t5._card_leaving_field(
			fp_t5.state.board[Vector2i(4, 1)])
	var fp_t5_left: CardData = fp_t5.state.board[Vector2i(4, 1)].card
	check(fp_t5_left.traits.has("防御") and not fp_t5_out.traits.has("防御"),
			"R67b 共享引用已切断：交出还原卡不影响场上那堵墙（场上 %s / 交出 %s）"
			% [str(fp_t5_left.traits), str(fp_t5_out.traits)])
	# 卡面本来就有的同名特性**不能被还原掉**：铁栅栏叠铁栅栏 → 离场后仍是铁栅栏
	var fp_t2 := _new_engine([], 20, 20, -1, false)
	fp_t2.self_relics = [6021]
	fp_t2.start_game()
	fp_t2.state.place(CardData.from_dict(fp_repo.get_card(9072).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_t2.state.hand = [CardData.from_dict(fp_repo.get_card(9072).to_dict())]
	fp_t2.state.energy = 5
	fp_t2.play_from_hand(0, Vector2i(4, 1))
	fp_t2._destroy(Vector2i(4, 1))
	var fp_t2_disc: CardData = fp_t2.state.discard[fp_t2.state.discard.size() - 1]
	check(fp_t2_disc != null and fp_t2_disc.traits.has(GameEngine.IRON_FENCE_TRAIT)
			and fp_t2_disc.health == 12,
			"R67b 同名叠加：离场后仍是 12 血的铁栅栏，「铁栅栏」特性不被误删（实际 %d 血）"
			% (fp_t2_disc.health if fp_t2_disc != null else -1))
	# 反向：铁栅栏叠木栅栏 → 木栅栏的「防御」是新加的，离场要被剥掉
	var fp_t3 := _new_engine([], 20, 20, -1, false)
	fp_t3.self_relics = [6021]
	fp_t3.start_game()
	fp_t3.state.place(CardData.from_dict(fp_repo.get_card(9072).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_t3.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_t3.state.energy = 5
	fp_t3.play_from_hand(0, Vector2i(4, 1))
	check(fp_t3.state.board[Vector2i(4, 1)].card.traits.has("防御"),
			"R67b 反向叠加：铁栅栏当场拿到木栅栏的「防御」")
	fp_t3._destroy(Vector2i(4, 1))
	var fp_t3_disc: CardData = fp_t3.state.discard[fp_t3.state.discard.size() - 1]
	check(fp_t3_disc != null and not fp_t3_disc.traits.has("防御")
			and fp_t3_disc.traits.has(GameEngine.IRON_FENCE_TRAIT)
			and fp_t3_disc.health == 12,
			"R67b 反向还原：只剥掉新加的「防御」，铁栅栏身份与原血 12 保留（实际 %s / %d 血）"
			% [str(fp_t3_disc.traits if fp_t3_disc != null else null),
				fp_t3_disc.health if fp_t3_disc != null else -1])
	# 活体栅栏 8018（[工事, 栅栏]）叠木栅栏 → 双方共有的特性不被记进 bonus（不该被剥）
	var fp_t4 := _new_engine([], 20, 20, -1, false)
	fp_t4.self_relics = [6021]
	fp_t4.start_game()
	fp_t4.state.place(CardData.from_dict(fp_repo.get_card(8018).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	fp_t4.state.hand = [CardData.from_dict(fp_repo.get_card(8001).to_dict())]
	fp_t4.state.energy = 5
	fp_t4.play_from_hand(0, Vector2i(4, 1))
	fp_t4._destroy(Vector2i(4, 1))
	var fp_t4_disc: CardData = fp_t4.state.discard[fp_t4.state.discard.size() - 1]
	check(fp_t4_disc != null and fp_t4_disc.traits.has("工事")
			and fp_t4_disc.traits.has("栅栏") and fp_t4_disc.health == 8,
			"R67b 活体栅栏：离场还原成 8 血的活体栅栏，公共特性完好（实际 %s / %d 血）"
			% [str(fp_t4_disc.traits if fp_t4_disc != null else null),
				fp_t4_disc.health if fp_t4_disc != null else -1])

	# ---- 二层成长脚本 vs 卡面文案：脚本参数一改，这里立刻报警 ----
	var L2G := GameLevels.LAYER2_GROWTH
	check(int(L2G.get("start_turn", 0)) == 2 and int(L2G.get("period", 0)) == 2
			and int(L2G.get("inc", 0)) == 1 and int(L2G.get("cap", 0)) == 4,
			"二层成长脚本：第 2 回合起每 2 回合 +1、上限 +4（卡面文案按这套参数写）")
	var dc_repo := CardRepo.load_json()
	# 这 11 张 = 二层四关（带 enemy_growth）的全部敌方单位
	for gid in [1011, 1013, 1014, 1031, 1050, 1051, 1053, 1054, 1055, 1061, 1071]:
		var gc: CardData = dc_repo.get_card(gid)
		if gc == null:
			check(false, "缺少二层怪物卡 id=%d" % gid)
			continue
		var strong_atk := int(L2G.get("strong_atk", 7))
		var want_mod := int(L2G.get("mod_strong", 0)) if gc.power >= strong_atk\
			else int(L2G.get("mod_weak", 0))
		check(gc.effect_text.contains("攻击力 %d" % want_mod)
				and gc.effect_text.contains("最多累计 +%d" % int(L2G.get("cap", 0))),
				"卡面写明成长参数：%s（基础攻击 %d → 开局 %+d）" % [gc.card_name, gc.power, want_mod])
	# 召唤 token 会被同一条成长脚本改攻击力 → 召唤文案不再写死它的数值
	var fledgling: CardData = dc_repo.get_card(1014)
	check(fledgling.effect_text.contains("龙裔") and not fledgling.effect_text.contains("4/12"),
			"幼龙亡语文案不再写死龙裔数值")
	var lich: CardData = dc_repo.get_card(1051)
	check(lich.effect_text.contains("两只骷髅") and not lich.effect_text.contains("3/8"),
			"亡灵领主亡语文案不再写死骷髅数值")
	var sk_token: CardData = dc_repo.get_card(9029)
	check(sk_token.effect_text.contains("骷髅兵"),
			"骷髅 token 文案补上真实来源（亡灵领主 + 骷髅兵）")
	# 「在启动了的」必须带上它召唤的铁栅栏的信息
	var lock_card: CardData = dc_repo.get_card(9071)
	var lock_fence: CardData = dc_repo.get_card(9072)
	check(lock_card != null and lock_fence != null
			and lock_card.effect_text.contains(lock_fence.card_name)
			and lock_card.effect_text.contains(str(lock_fence.health)),
			"在启动了的文案带上了铁栅栏的信息（%s）" % lock_card.effect_text)

	# ---- 重鸭（6017）：敌方的移动距离 >1 → 按 1 计算 ----
	var eng_hv := _new_engine(wm_deck, 20, 20, -1, false)
	eng_hv.self_relics = [6017]
	eng_hv.start_game()
	eng_hv.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var hv_foe := eng_hv._reachable(Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var eng_hv2 := _new_engine(wm_deck, 20, 20, -1, false)
	eng_hv2.start_game()
	eng_hv2.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var hv_plain := eng_hv2._reachable(Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	check(hv_foe.size() < hv_plain.size(),
			"重鸭：敌方速2 单位可达格 2 → 1（%d < 无道具时 %d）"
			% [hv_foe.size(), hv_plain.size()])
	eng_hv.state.place(_card(9016, "骑兵", "盟友", 4, 6, 12, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(eng_hv._reachable(Vector2i(4, 1), GameEngine.SIDE_SELF).size() > 4,
			"重鸭：只限制敌方 —— 我方速2 单位照样能走 2 格")

	# ---- 冰淇淋与汽水（6016）：开场 -3 生命；第 1 回合 +4 能量 / 多抽 3 张 ----
	var ice_deck: Array[CardData] = []
	for i in 14:
		ice_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var eng_ice := _new_engine(ice_deck, 20, 20, -1, false)
	eng_ice.self_relics = [6016]
	var ice_lines: Array = []
	eng_ice.action.connect(func(k: String, d: Dictionary) -> void:
			if k == "icecream":
				ice_lines.append(str(d.get("text", ""))))
	eng_ice.apply_battle_start_relics(null)
	check(eng_ice.state.hp_self == 17, "冰淇淋与汽水：开场失去 3 点生命（20 → 17）")
	eng_ice.start_game()
	check(ice_lines.size() == 1 and ice_lines[0] == "你跑不过我你信吗",
			"冰淇淋与汽水：第 1 回合加费抽牌时广播台词「你跑不过我你信吗」（实际 %s）"
			% str(ice_lines))
	check(eng_ice.state.energy == FieldState.ENERGY_PER_TURN + 4,
			"冰淇淋与汽水：第 1 回合额外 +4 能量（实际 %d）" % eng_ice.state.energy)
	check(eng_ice.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 3,
			"冰淇淋与汽水：第 1 回合多抽 3 张（实际 %d）" % eng_ice.state.hand.size())
	eng_ice.end_turn()
	eng_ice.end_turn()
	check(eng_ice.state.energy == FieldState.ENERGY_PER_TURN,
			"冰淇淋与汽水：只有第 1 回合有额外能量（第 2 回合重置为 5，实际 %d）"
			% eng_ice.state.energy)
	var eng_ice2 := _new_engine(ice_deck, 2, 20, -1, false)
	eng_ice2.self_relics = [6016]
	eng_ice2.apply_battle_start_relics(null)
	check(eng_ice2.state.hp_self == 1, "冰淇淋与汽水：开场代价不会致死（2 → 1）")

	# ---- 生蛋鸭（6018）：开场在我方前排中央放一个 0 攻 1 血工事「鸭蛋」 ----
	var eng_egg := _new_engine(ice_deck, 20, 20, -1, false)
	eng_egg.self_relics = [6018]
	eng_egg.apply_battle_start_relics(repo)
	var egg_home := Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2)
	var egg_p := eng_egg.state.unit_at(egg_home)
	check(egg_p != null and egg_p.card.id == 9022 and egg_p.card.is_fort()
			and egg_p.card.power == 0 and egg_p.health == 1,
			"生蛋鸭：开场我方前排中央出现 0 攻 1 血工事「鸭蛋」")
	check(eng_egg._reachable(egg_home, GameEngine.SIDE_SELF).is_empty(),
			"鸭蛋：工事不能移动")
	var egg_discard := eng_egg.state.discard.size()
	eng_egg._destroy(egg_home)
	check(eng_egg.state.discard.size() == egg_discard,
			"鸭蛋：被击破不进弃牌区（战斗内召唤物，不会污染牌库）")

	# ---- 鸭语耳环（6015）：每回合 +1 能量；第 1 回合不抽牌改自动出牌 ----
	var ear_deck: Array[CardData] = []
	for i in 10:
		ear_deck.append(_card(8001, "木栅栏", "工事", 2, 0, 6))
	var eng_ear := _new_engine(ear_deck, 20, 20, -1, false)
	eng_ear.self_relics = [6015]
	eng_ear.start_game()
	check(eng_ear.state.board.size() == 3,
			"鸭语耳环：第 1 回合不抽牌 → 自动出牌（6 费打出 3 张 2 费工事，实际 %d）"
			% eng_ear.state.board.size())
	check(eng_ear.state.energy == 0 and eng_ear.state.hand.size() == 1,
			"鸭语耳环：能量不足即停止（付不起的第 4 张留在手里 = 1 张）")
	# 每回合 +1 能量：第 2 回合 = 5（回合结束重置）+ 1（耳环）
	eng_ear.end_turn()
	eng_ear.end_turn()
	check(eng_ear.state.energy == FieldState.ENERGY_PER_TURN + 1,
			"鸭语耳环：每回合获得的能量 +1（第 2 回合 5+1 = %d）" % eng_ear.state.energy)
	# 上限 20 张（防死循环）：30 张 0 费效果卡只打出 20 张
	var ear_free: Array[CardData] = []
	for i in 30:
		ear_free.append(_card(8001, "测试效果", "效果", 0, 0, 0))
	var eng_ear2 := _new_engine(ear_free, 20, 20, -1, false)
	eng_ear2.self_relics = [6015]
	eng_ear2.start_game()
	check(eng_ear2.state.effects.size() == GameEngine.EARRING_AUTOPLAY_MAX,
			"鸭语耳环：自动出牌上限 %d 张（防死循环，实际 %d）"
			% [GameEngine.EARRING_AUTOPLAY_MAX, eng_ear2.state.effects.size()])
	# 牌库抽空即结束
	var ear_few: Array[CardData] = []
	for i in 4:
		ear_few.append(_card(8001, "测试效果", "效果", 0, 0, 0))
	var eng_ear3 := _new_engine(ear_few, 20, 20, -1, false)
	eng_ear3.self_relics = [6015]
	eng_ear3.start_game()
	check(eng_ear3.state.effects.size() == 4 and eng_ear3.state.deck.is_empty(),
			"鸭语耳环：牌库抽空即结束自动出牌（4 张全部打出）")

	# ---- 鸭梨（6019）：每次自己 HP 受伤 → 最大生命 +1（不回复生命）----
	var pear_deck: Array[CardData] = []
	for i in 6:
		pear_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	var eng_pear := _new_engine(pear_deck, 20, 20, -1, false)
	eng_pear.self_relics = [6019]
	eng_pear.start_game()
	check(eng_pear.state.max_hp_self == 20, "鸭梨：开场最大生命不变（20）")
	eng_pear._damage_player(GameEngine.SIDE_SELF, 3, "测试")
	check(eng_pear.state.hp_self == 17 and eng_pear.state.max_hp_self == 21,
			"鸭梨：HP 受伤 → 最大生命 +1（生命 20→17，上限 20→21）")
	eng_pear._damage_player(GameEngine.SIDE_SELF, 2, "测试")
	check(eng_pear.state.hp_self == 15 and eng_pear.state.max_hp_self == 22,
			"鸭梨：多段伤害逐次累加（生命 20→15，上限 20→22）")
	# 敌方「直击我方 HP」是另一条承伤口，同样要触发
	eng_pear.state.place(_card(1053, "测试兵", "盟友", 1, 5, 10, 2, 1),
			Vector2i(4, 0), GameEngine.SIDE_OPPONENT)
	eng_pear.attack_hp(Vector2i(4, 0), Vector2i(5, 0), GameEngine.SIDE_OPPONENT)
	check(eng_pear.state.hp_self == 10 and eng_pear.state.max_hp_self == 23,
			"鸭梨：敌方直击我方 HP 也算（生命 15→10，上限 22→23）")
	# 关键边界：我方「单位」中招不算 —— 那不是我方 HP（区别于「一袋米抗几楼」）
	var pear_before_max: int = eng_pear.state.max_hp_self
	var pear_unit := eng_pear.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6),
			Vector2i(5, 1), GameEngine.SIDE_SELF)
	eng_pear._hit_unit(pear_unit, 3, "测试")
	check(eng_pear.state.max_hp_self == pear_before_max,
			"鸭梨：只有自己 HP 受伤才触发 —— 我方单位中招不算（上限不变）")
	# 未持有时不触发
	var eng_pear_no := _new_engine(pear_deck, 20, 20, -1, false)
	eng_pear_no.start_game()
	eng_pear_no._damage_player(GameEngine.SIDE_SELF, 3, "测试")
	check(eng_pear_no.state.max_hp_self == 20,
			"鸭梨：未持有时 HP 受伤不提升上限（仍 20）")
	check(eng_pear.state.hp_self < eng_pear.state.max_hp_self,
			"鸭梨：只提高上限、不回复生命（当前生命始终低于上限）")

	# ---- 二层事件「绝赞五换一」的奖励卡「英雄」（9023）----
	var hero_card := repo.get_card(9023)
	check(hero_card != null and hero_card.card_name == "英雄" and hero_card.cost == 5
			and hero_card.power == 5 and hero_card.health == 25
			and hero_card.attack_range == 1 and hero_card.move_speed == 1
			and hero_card.rarity == 5 and hero_card.rarity_name() == "事件"
			and hero_card.traits.has("事件"),
			"英雄：事件卡 5 费 5/25 程1 速1（稀有度 5 = 事件）")
	check(not repo.reward_pool().any(func(c: CardData): return c.id == 9023),
			"英雄不可通过奖励获取（事件卡不进奖励池）")
	# 额外代价：英雄要弃 4 张手牌，普通卡没有
	var hero_deck: Array[CardData] = []
	for hero_i in 4:
		hero_deck.append(_card(8002, "攻击", "技能", 1, 0, 0))
	hero_deck.append(hero_card)
	var eng_hero := _new_engine(hero_deck, 20, 20, -1, false)
	eng_hero.start_game()
	eng_hero.state.energy = 10          # 保证付得起 5 费（这里只测「弃牌代价」）
	var hero_idx := _find(eng_hero.state.hand, 9023)
	check(hero_idx >= 0, "英雄：开局抽到手上（牌组只有 5 张）")
	check(eng_hero.discard_cost_of(hero_card) == 4
			and eng_hero.discard_cost_of(_card(8002, "攻击", "技能", 1, 0, 0)) == 0,
			"英雄的额外代价 = 弃 4 张手牌；普通卡为 0（照常上场）")
	check(eng_hero.can_play_from_hand(hero_idx),
			"英雄：除它以外还有 4 张手牌 → 付得起代价")
	# 结算：选 4 张丢掉 → 英雄上场
	var hero_others: Array = []
	for hero_i2 in eng_hero.state.hand.size():
		if hero_i2 != hero_idx:
			hero_others.append(hero_i2)
	var hero_hand_before: int = eng_hero.state.hand.size()
	var hero_disc_before: int = eng_hero.state.discard.size()
	check(hero_others.size() == 4, "英雄：可拿来当代价的手牌正好 4 张（不含英雄自己）")
	var hero_pl := eng_hero.play_hero_from_hand(hero_idx, Vector2i(4, 1), hero_others)
	check(hero_pl != null, "英雄：选满 4 张代价后成功上场")
	check(eng_hero.state.hand.size() == hero_hand_before - 5,
			"英雄上场：手牌 -5（英雄自己 + 4 张代价）")
	check(eng_hero.state.discard.size() == hero_disc_before + 4,
			"英雄代价：4 张手牌进弃牌区")
	var hero_on := eng_hero.state.unit_at(Vector2i(4, 1))
	check(hero_on != null and hero_on.card.id == 9023, "英雄落到指定空格（4,1）")
	# 代价不合法 → 不上场、不扣费、手牌不变
	var eng_bad := _new_engine(hero_deck, 20, 20, -1, false)
	eng_bad.start_game()
	eng_bad.state.energy = 10
	var bad_idx := _find(eng_bad.state.hand, 9023)
	var bad_sel: Array = []
	for bad_i in eng_bad.state.hand.size():
		if bad_i != bad_idx and bad_sel.size() < 3:
			bad_sel.append(bad_i)
	bad_sel.append(bad_idx)                       # 把英雄自己也算进代价
	check(eng_bad.play_hero_from_hand(bad_idx, Vector2i(4, 1), bad_sel) == null,
			"英雄：不能把英雄自己当作代价（返回 null）")
	check(eng_bad.play_hero_from_hand(bad_idx, Vector2i(4, 1), [bad_sel[0], bad_sel[1]]) == null,
			"英雄：代价不足 4 张 → 不上场")
	check(eng_bad.state.unit_at(Vector2i(4, 1)) == null and eng_bad.state.hand.size() == 5,
			"英雄：代价校验失败时棋盘与手牌都不变")
	# 手牌不够付代价 → 打不出去
	var eng_few := _new_engine(hero_deck, 20, 20, -1, false)
	eng_few.start_game()
	eng_few.state.energy = 10
	var few_idx := _find(eng_few.state.hand, 9023)
	var keep_one: int = 0 if few_idx != 0 else 1
	var few_hand: Array[CardData] = [eng_few.state.hand[few_idx], eng_few.state.hand[keep_one]]
	eng_few.state.hand = few_hand
	check(not eng_few.can_play_from_hand(_find(eng_few.state.hand, 9023)),
			"英雄：除它外不足 4 张手牌 → 付不起代价（打不出去）")

	# ---- 二层事件「绝赞五换一」结算（RunState）----
	RunState.reset(50)
	# 注意：deck_ids 是 Array[int]，字面量必须**先转成带类型的变量**再赋
	# （直接 `RunState.deck_ids = [8001, ...]` 会报
	#  Invalid assignment of property 'deck_ids' with value of type 'Array'）
	var tf_ids: Array[int] = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
	RunState.deck_ids = tf_ids.duplicate()
	check(RunState.deck_distinct_names(repo) == 6,
			"卡组 9 张 = 6 种不同名（栅栏/攻击/农民/火焰箭/骑兵/箭塔）")
	check(RunState.can_trade_five(repo), "卡组 ≥5 种不同名 → 这笔交易做得成")
	var tf := RunState.trade_five_for_one(repo)
	check(bool(tf.get("ok", false)) and int(tf.get("new_id", 0)) == 9023,
			"绝赞五换一：结算成功并把「英雄」加入卡组")
	check(RunState.deck_ids.size() == tf_ids.size() - 4,
			"绝赞五换一：删 5 张 + 加 1 张（卡组净 -4）")
	check(RunState.deck_ids.has(9023), "绝赞五换一：卡组里出现「英雄」")
	var tf_removed: Array = tf.get("removed", [])
	var tf_names := {}
	for tf_r: Variant in tf_removed:
		tf_names[str((tf_r as Dictionary).get("name", ""))] = true
	check(tf_removed.size() == 5 and tf_names.size() == 5,
			"绝赞五换一：换走 5 张且**互不重名**")
	# 每种被换走的卡各少 1 张（同名多张只删一张）
	var tf_after := {}
	for tf_id in RunState.deck_ids:
		var tf_c := repo.get_card(tf_id)
		var tf_nm: String = tf_c.card_name if tf_c != null else str(tf_id)
		tf_after[tf_nm] = int(tf_after.get(tf_nm, 0)) + 1
	var tf_ok := true
	for tf_r2: Variant in tf_removed:
		var rn: String = str((tf_r2 as Dictionary).get("name", ""))
		var rn_before := 0
		for tf_id2 in tf_ids:
			var c2 := repo.get_card(tf_id2)
			if c2 != null and c2.card_name == rn:
				rn_before += 1
		if int(tf_after.get(rn, 0)) != rn_before - 1:
			tf_ok = false
	check(tf_ok, "绝赞五换一：被换走的每种卡各少 1 张（同名多张只删一张）")
	# 卡组不足 5 种不同名 → 交易失败、卡组不变（界面上只能退出事件）
	var tf_few: Array[int] = [8001, 8001, 8001, 8002, 8002]
	RunState.deck_ids = tf_few.duplicate()
	check(RunState.deck_distinct_names(repo) == 2 and not RunState.can_trade_five(repo),
			"卡组只有 2 种不同名 → 不能交易")
	var tf_bad := RunState.trade_five_for_one(repo)
	check(not bool(tf_bad.get("ok", true)) and RunState.deck_ids.size() == 5,
			"卡组不足 5 种不同名：交易失败且卡组不变（只能退出事件）")
	# 同名不同 id 只算一种（骷髅兵 1053/1054/1055）
	var tf_same: Array[int] = [1053, 1054, 1055, 8001, 8002, 8003, 9003, 9016]
	RunState.deck_ids = tf_same.duplicate()
	# 骷髅兵×3 同名（1053/1054/1055）+ 木栅栏/攻击/农民/火焰箭/骑兵 → 共 6 种
	check(RunState.deck_distinct_names(repo) == 6,
			"同名不同 id（骷髅兵×3）只算 1 种：8 张 = 6 种")
	var tf_init: Array[int] = [8001, 8001, 8001, 8001, 8001, 8002, 8002, 8002, 8002,
			8002, 8003, 8003]      # 还原成初始卡组，避免影响后面的断言
	RunState.deck_ids = tf_init.duplicate()
	RunState.reset()

	# ---- UI 图片命名约定（assets/ui/ 可替换，文件名即契约）----
	var map_types := ["start", "battle", "elite", "rest", "event", "chest", "boss"]
	var ev_kinds := ["rest", "treasure", "whisper", "struggle", "gaze", "pear", "hero",
			"relic_chest"]
	var names := {}
	for t in map_types:
		names[UiAssets.node_icon_path(t).get_file()] = true
	for k in ev_kinds:
		names[UiAssets.event_pic_path(k).get_file()] = true
		names[UiAssets.event_bg_path(k).get_file()] = true
	check(names.size() == 23,
			"UI 图片共 23 个文件名且互不重复（7 地图图标 + 8 事件插图 + 8 事件背景），实际 %d"
			% names.size())
	check(UiAssets.node_icon_path("boss") == "res://assets/ui/map_boss.png",
			"地图图标命名：map_<类型>.png（map_boss.png）")
	check(UiAssets.event_pic_path("gaze") == "res://assets/ui/event_gaze.png",
			"事件插图命名：event_<事件>.png（event_gaze.png）")
	check(UiAssets.event_bg_path("rest") == "res://assets/ui/bg_rest.png",
			"事件背景命名：bg_<事件>.png（bg_rest.png）")
	check(UiAssets.get_tex("__no_such_image__") == null,
			"UI 图片缺失时返回 null（调用方回退内置程序化绘制）")
	var doc_path := "res://assets/ui/图片命名说明.txt"
	# 导出版按设计排除 *.txt（export_presets.cfg 的 exclude_filter），说明文本不随包发布，
	# 此时文档断言不适用 → 跳过（不算失败）。用「export_presets.cfg 是否存在」判断是否在
	# dev 工程里跑（*.cfg 同样不进 pck，实测已确认）；OS.has_feature("standalone") 在
	# 导出 exe 跑 --script 时仍返回 false，不能用来判断导出版。
	var in_dev := FileAccess.file_exists("res://export_presets.cfg")
	if in_dev:
		check(FileAccess.file_exists(doc_path), "assets/ui/ 下有图片命名说明文本")
	if FileAccess.file_exists(doc_path):
			var doc := FileAccess.get_file_as_string(doc_path)
			var missing: Array[String] = []
			for n in names.keys():
				if not doc.contains(str(n)):
					missing.append(str(n))
			check(missing.is_empty(), "说明文本覆盖全部 %d 个文件名%s" % [names.size(),
					"" if missing.is_empty() else "（缺：%s）" % ", ".join(missing)])


	# ---- 费用机制：回合结束清零，基础费用在「回合开始」补发（2026-09-30 改） ----
	var eng_rst := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng_rst.start_game()
	check(eng_rst.state.energy == FieldState.ENERGY_PER_TURN, "开局即有一回合的费用（%d）"
			% eng_rst.state.energy)
	eng_rst.state.energy = 99        # 模拟没花完攒了一大笔
	eng_rst.end_turn()               # 我方回合结束 → 清零（基础费用留到下次回合开始发）
	check(eng_rst.state.energy == 0,
			"我方回合结束：能量清零（实际 %d）" % eng_rst.state.energy)
	check(eng_rst.state.opp_energy == FieldState.ENERGY_PER_TURN,
			"对方回合开始：先领到本回合基础费用（%d）" % eng_rst.state.opp_energy)
	eng_rst.state.opp_energy = 99
	eng_rst.end_turn()               # 对方回合结束 → 清零
	check(eng_rst.state.opp_energy == 0,
			"对方回合结束：能量清零（实际 %d）" % eng_rst.state.opp_energy)
	check(eng_rst.state.energy == FieldState.ENERGY_PER_TURN,
			"我方回合开始：重新领到本回合基础费用（不累积对方那笔）（实际 %d）"
			% eng_rst.state.energy)

	# 多格移动：move_path 给出逐格路径（会绕开占位的单位，并且不会斜穿）
	var eng_mv := _new_engine(_ordered_deck(), 20, 20, -1, false)
	eng_mv.start_game()
	var fast_card := _card(9027, "夜鸭", "盟友", 8, 10, 35)
	fast_card.move_speed = 2
	eng_mv.state.board.clear()
	eng_mv.state.place(fast_card, Vector2i(3, 0), GameEngine.SIDE_SELF)
	# (4,0) 放个工事挡路：(3,0) → (4,1) 的实际走法只能是先横向再纵向（L 形），
	# 动画若直连首尾就会斜穿格子、还可能从工事上压过去。
	eng_mv.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6), Vector2i(4, 0),
			GameEngine.SIDE_OPPONENT)
	var mv_path := eng_mv.move_path(Vector2i(3, 0), Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(mv_path == [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1)],
			"move_path：(4,0) 被挡 → 只能绕 (3,1) 走 L 形（实际 %s）" % str(mv_path))
	var step_ok := true
	for i in mv_path.size() - 1:
		var a: Vector2i = mv_path[i]
		var b: Vector2i = mv_path[i + 1]
		if absi(a.x - b.x) + absi(a.y - b.y) != 1:
			step_ok = false
	check(step_ok, "move_path：每一段都只走相邻 1 格（不会穿墙 / 斜穿）")
	check(eng_mv.move_path(Vector2i(3, 0), Vector2i(5, 2), GameEngine.SIDE_SELF).is_empty(),
			"move_path：超出移动速度 → 不可达（空数组）")
	check(eng_mv.move_path(Vector2i(3, 0), Vector2i(3, 0), GameEngine.SIDE_SELF).is_empty(),
			"move_path：走到自己所在格 = 不可达（空数组）")
	var mv_seen := {}
	eng_mv.action.connect(func(k: String, d: Dictionary):
		if k == "move":
			mv_seen["path"] = d.get("path", [])
			mv_seen["count"] = int(mv_seen.get("count", 0)) + 1)
	eng_mv.move(Vector2i(3, 0), Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(int(mv_seen.get("count", 0)) == 1, "move 广播一次移动事件")
	check((mv_seen.get("path", []) as Array) == mv_path,
			"move 事件带上逐格路径给动画层（实际 %s）" % str(mv_seen.get("path", [])))

	# ---- 角色系统（2026-10-01）：森林精魄 + 暗影刺客 ----
	# 角色写在 cards.json 的 class 字段（CardData.card_class）；每张卡的 class 必须是可选角色之一。
	var dr_cls_all := repo.all_cards()
	var dr_cls_bad: Array = []
	var dr_cls_count := {}
	for c in dr_cls_all:
		if not PlayerClass.ids().has(c.card_class):
			dr_cls_bad.append(c.id)
		dr_cls_count[c.card_class] = int(dr_cls_count.get(c.card_class, 0)) + 1
	check(dr_cls_bad.is_empty(),
			"角色系统：%d 张卡的 class 都是可选角色之一（异常 %s）"
			% [dr_cls_all.size(), str(dr_cls_bad)])
	check(int(dr_cls_count.get(PlayerClass.DRUID, 0)) == 105
			and int(dr_cls_count.get(PlayerClass.ROGUE, 0)) == 48
		and int(dr_cls_count.get(PlayerClass.MECH, 0)) == 28,
		"角色系统：森林精魄 %d 张 / 暗影刺客 %d 张 / 机械之心 %d 张（期望 105 / 48 / 28）"
			% [int(dr_cls_count.get(PlayerClass.DRUID, 0)),
				int(dr_cls_count.get(PlayerClass.ROGUE, 0)),
				int(dr_cls_count.get(PlayerClass.MECH, 0))])
	check(PlayerClass.ids() == ["森林精魄", "暗影刺客", "机械之心"]
			and PlayerClass.default_id() == "森林精魄",
			"R82 角色系统：可选角色 = 森林精魄 / 暗影刺客 / **机械之心**（默认森林精魄）")
	check(PlayerClass.relic_of("森林精魄") == 6022
			and PlayerClass.bonus_deck_of("森林精魄") == [8004],
			"角色系统：森林精魄 → 赠品道具 6022 / 追加初始卡 8004")
	check(PlayerClass.relic_of("暗影刺客") == 6023
			and PlayerClass.bonus_deck_of("暗影刺客") == [9086],
			"角色系统：暗影刺客 → 赠品道具 6023 / 追加初始卡 9086")
	check(PlayerClass.relic_of("机械之心") == 6025
			and PlayerClass.bonus_deck_of("机械之心") == [8026, 8026, 8027],
			"R82 角色系统：机械之心 → 赠品道具 6025 / 追加初始卡 构装体×2 + 升级×1")

	# 农民 → 树人（8003）
	var dr_treant := repo.get_card(8003)
	check(dr_treant.card_name == "树人" and dr_treant.traits.has("树人"),
			"农民已改名为树人（%s / %s）" % [dr_treant.card_name, str(dr_treant.traits)])

	# 熊（8004）：4 费初始卡组卡 3/12 程1 速1，带「回春」
	var dr_bear_card := repo.get_card(GameEngine.BEAR_ID)
	check(dr_bear_card != null and dr_bear_card.cost == 4 and dr_bear_card.power == 3
			and dr_bear_card.health == 12 and dr_bear_card.attack_range == 1
			and dr_bear_card.move_speed == 1 and dr_bear_card.rarity == 3,
			"熊：4 费 3/12 程1 速1 初始卡组卡")
	check(dr_bear_card.traits.has(GameEngine.BEAR_TRAIT) and dr_bear_card.card_class == "森林精魄",
			"熊：带「回春」词条、角色森林精魄（%s）" % str(dr_bear_card.traits))
	var dr_bear_in_pool := false
	for pc in repo.reward_pool():
		if pc.id == GameEngine.BEAR_ID:
			dr_bear_in_pool = true
	check(not dr_bear_in_pool, "熊是初始卡（rarity 3），不进奖励池")

	# 熊的主动发动：代替行动回复 6 生命 → 横置 → 在场只能发动一次
	var dr_br_e := _new_engine([], 30, 30)
	var dr_br_p := dr_br_e.state.place(
			CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	dr_br_p.health = 4
	check(dr_br_e.can_activate(Vector2i(3, 1)) and dr_br_e.activate(Vector2i(3, 1)),
			"熊：未横置时可主动发动")
	check(dr_br_p.health == 10 and dr_br_p.tapped,
			"熊：发动回复 6 生命（4 → 10）并横置（实际 %d / tapped=%s）"
			% [dr_br_p.health, str(dr_br_p.tapped)])
	check(not dr_br_e.can_activate(Vector2i(3, 1)) and not dr_br_e.activate(Vector2i(3, 1)),
			"熊：在场只能发动一次（用过之后不能再发动）")
	var dr_br_other := dr_br_e.state.place(
			CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	check(not dr_br_e.can_activate(Vector2i(3, 0)), "树人没有主动发动能力（只有熊能发动）")
	var dr_br_e2 := _new_engine([], 30, 30)
	var dr_br_p3 := dr_br_e2.state.place(
			CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	dr_br_p3.health = 11
	dr_br_e2.activate(Vector2i(4, 1))
	check(dr_br_p3.health == 12,
			"熊：回复不超过生命上限（11 + 6 → 12，实际 %d）" % dr_br_p3.health)

	# 荒野形态（6022，R60 重做）：每场战斗中第一次自己的 HP 被敌方**普通攻击**打中 →
	# 这次伤害 -4（最少 1）+ 对攻击者反伤 4。旧的「打熊/打 HP 的敌人受 3 伤」已移除。
	var dr_wf_e := _new_engine([], 30, 30)
	dr_wf_e.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
	# 我方后排是第 5 行→ 敌方单位要站 (4,1) 才够得着 HP（普通攻击 → 走 attack_hp）
	var dr_wf_foe := dr_wf_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	dr_wf_e.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(dr_wf_e.state.hp_self == 26,
			"荒野形态：第一次受击 8 → 减伤后 4（30 → %d）" % dr_wf_e.state.hp_self)
	check(dr_wf_foe.health == 51,
			"荒野形态：反伤 4（55 → %d）" % dr_wf_foe.health)
	check(dr_wf_e.state.wild_form_used,
			"荒野形态：本场已触发标记置位（每场只触发一次）")
	# 第二次受击不再减伤 / 不再反伤（攻击者上一下已横置 → 先解横置再攻）
	dr_wf_foe.tapped = false
	dr_wf_e.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(dr_wf_e.state.hp_self == 18,
			"荒野形态：第二次受击不再减伤（26 - 8 = %d）" % dr_wf_e.state.hp_self)
	check(dr_wf_foe.health == 51,
			"荒野形态：第二次不再反伤（仍 %d，没再掉血）" % dr_wf_foe.health)
	# 伤害下限：3 点伤害减 4 → 1
	var dr_wf_e5 := _new_engine([], 30, 30)
	dr_wf_e5.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
	dr_wf_e5.state.place(_card(1051, "亡灵领主", "盟友", 3, 3, 55, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	dr_wf_e5.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(dr_wf_e5.state.hp_self == 29,
			"荒野形态：3 伤减 4 → 最少 1（30 → %d）" % dr_wf_e5.state.hp_self)
	# 没持有道具 → 完全不生效
	var dr_wf_e3 := _new_engine([], 30, 30)
	dr_wf_e3.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	dr_wf_e3.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	check(dr_wf_e3.state.hp_self == 22 and dr_wf_e3.state.unit_at(Vector2i(4, 1)).health == 55,
			"荒野形态：没持有道具 → 不减伤不反伤（HP 30 → %d，敌人 %d）"
			% [dr_wf_e3.state.hp_self, dr_wf_e3.state.unit_at(Vector2i(4, 1)).health])
	# 只认「普通攻击直击 HP」：打熊（普通攻击打单位）不触发
	var dr_wf_e4 := _new_engine([], 30, 30)
	dr_wf_e4.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
	dr_wf_e4.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	dr_wf_e4.state.place(CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	dr_wf_e4.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(not dr_wf_e4.state.wild_form_used
			and dr_wf_e4.state.unit_at(Vector2i(2, 1)).health == 55,
			"荒野形态：打熊不触发（旧的「打熊反伤 3」已移除，敌人 %d）"
			% dr_wf_e4.state.unit_at(Vector2i(2, 1)).health)

	# RunState：选定森林精魄开局 → 初始卡组含熊、道具栏含荒野形态
	RunState.end_run()
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
	check(RunState.player_class == "森林精魄", "角色系统：start_run 记录所选角色")
	check(RunState.deck_ids.has(GameEngine.BEAR_ID), "角色系统：初始卡组含熊 8004")
	check(RunState.has_relic(GameEngine.WILD_FORM_RELIC_ID),
			"角色系统：开局获得角色赠品「荒野形态」6022")
	check(RunState.relic_choice.size() == 3,
			"角色系统：赠品不占起点三选一的名额（仍有 3 个候选）")
	RunState.end_run()

	# ---- 暗影刺客（R44）：幽影 8005 / 终结 9086 / 幻影斗篷 6023 ----
	var rg_wraith := repo.get_card(8005)
	check(rg_wraith.card_name == "幽影" and rg_wraith.traits.has("幽影")
			and rg_wraith.card_class == PlayerClass.ROGUE,
			"幽影：暗影刺客的基础盟友（%s / %s）"
			% [rg_wraith.card_name, str(rg_wraith.traits)])
	check(rg_wraith.cost == 3 and rg_wraith.power == 3 and rg_wraith.health == 8
			and rg_wraith.attack_range == 1 and rg_wraith.move_speed == 1
			and rg_wraith.rarity == 3,
			"幽影：3 费 3/8 程1 速1 初始卡")
	var rg_tree := repo.get_card(8003)
	check(rg_tree.cost == rg_wraith.cost and rg_tree.power == rg_wraith.power
			and rg_tree.health == rg_wraith.health
			and rg_tree.attack_range == rg_wraith.attack_range
			and rg_tree.move_speed == rg_wraith.move_speed,
			"幽影：费用 / 力量 / 生命 / 攻程 / 移速与树人完全一致")
	var rg_raid := repo.get_card(GameEngine.RAID_SPELL_ID)
	check(rg_raid.card_name == "终结" and rg_raid.is_spell() and rg_raid.cost == 0
			and rg_raid.target_mode == "unit" and rg_raid.rarity == 3
			and rg_raid.card_class == PlayerClass.ROGUE,
			"终结：0 费技能，指定目标，初始卡（不入奖励池）")

	# 终结的 X = 本回合已使用的卡牌数（自身不计入 —— 结算之后才记账）
	var rg_e := _new_engine([], 30, 30)
	rg_e.state.hand.clear()
	rg_e.state.hand.append(CardData.from_dict(rg_raid.to_dict()))
	rg_e.state.energy = 5
	var rg_foe := rg_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 60, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	rg_e.use_spell(0, Vector2i(2, 1))
	check(rg_foe.health == 58,
			"终结：本回合第一张（X=0）→ 2 伤（60→%d）" % rg_foe.health)
	check(rg_e.state.self_card_plays == 1,
			"终结：自己也计入本回合出牌数（结算之后才记账）")
	rg_e.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_e.play_from_hand(0, Vector2i(4, 0))
	rg_e.state.hand.append(CardData.from_dict(rg_raid.to_dict()))
	rg_e.use_spell(0, Vector2i(2, 1))
	check(rg_foe.health == 54,
			"终结：本回合已用 2 张（X=2）→ 2+2=4 伤（58→%d）" % rg_foe.health)
	rg_e.end_turn()
	rg_e.end_turn()
	rg_e.state.hand.clear()
	rg_e.state.hand.append(CardData.from_dict(rg_raid.to_dict()))
	rg_e.use_spell(0, Vector2i(2, 1))
	check(rg_foe.health == 52,
			"终结：进入下一个自己的回合 → 计数清零，又是 2 伤（54→%d）"
			% rg_foe.health)
	var rg_hp := _new_engine([], 30, 30)
	rg_hp.state.hand.clear()
	rg_hp.state.hand.append(CardData.from_dict(rg_raid.to_dict()))
	rg_hp.use_spell(0, Vector2i(-1, -1))
	check(rg_hp.state.hp_opponent == 28,
			"终结：没有敌方单位时 2 伤直击敌方 HP（30→%d）"
			% rg_hp.state.hp_opponent)

	# 幻影斗篷（6023，R60 起每使用**两张**牌 → 随机一个敌方单位力量 -1）
	var rg_ck := _new_engine([], 30, 30)
	rg_ck.self_relics = [GameEngine.PHANTOM_CLOAK_RELIC_ID]
	rg_ck.state.hand.clear()
	rg_ck.state.energy = 5
	var rg_ck_foe := rg_ck.state.place(_card(1099, "稻草人", "盟友", 2, 8, 40, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	rg_ck.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_ck.play_from_hand(0, Vector2i(4, 0))
	check(rg_ck_foe.atk_debuff == 0 and rg_ck_foe.effective_power() == 8,
			"幻影斗篷：出第 1 张牌**不触发**（仍 %d）" % rg_ck_foe.effective_power())
	rg_ck.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_ck.play_from_hand(0, Vector2i(4, 2))
	check(rg_ck_foe.atk_debuff == 1 and rg_ck_foe.effective_power() == 7,
			"幻影斗篷：出第 2 张牌 → 力量 -1（8→%d）" % rg_ck_foe.effective_power())
	# 第 3 张仍不触发，第 4 张再叠一层
	rg_ck.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_ck.play_from_hand(0, Vector2i(4, 1))
	check(rg_ck_foe.atk_debuff == 1 and rg_ck_foe.effective_power() == 7,
			"幻影斗篷：出第 3 张牌仍不触发（仍 %d）" % rg_ck_foe.effective_power())
	rg_ck.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_ck.play_from_hand(0, Vector2i(4, 0))
	check(rg_ck_foe.atk_debuff == 2 and rg_ck_foe.effective_power() == 6,
			"幻影斗篷：出第 4 张牌 → 再叠一层（7→%d）" % rg_ck_foe.effective_power())
	var rg_no := _new_engine([], 30, 30)
	rg_no.state.hand.clear()
	rg_no.state.energy = 5
	var rg_no_foe := rg_no.state.place(_card(1099, "稻草人", "盟友", 2, 8, 40, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	rg_no.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_no.play_from_hand(0, Vector2i(4, 0))
	check(rg_no_foe.effective_power() == 8,
			"幻影斗篷：没持有道具 → 不降力量（仍 %d）"
			% rg_no_foe.effective_power())
	var rg_nobody := _new_engine([], 30, 30)
	rg_nobody.self_relics = [GameEngine.PHANTOM_CLOAK_RELIC_ID]
	rg_nobody.state.hand.clear()
	rg_nobody.state.energy = 5
	rg_nobody.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	rg_nobody.play_from_hand(0, Vector2i(4, 0))
	check(rg_nobody.state.self_card_plays == 1,
			"幻影斗篷：场上没有敌人时不报错（照常记出牌数）")
	rg_ck.end_turn()
	rg_ck.end_turn()
	check(rg_ck_foe.atk_debuff == 0 and rg_ck_foe.effective_power() == 8,
			"幻影斗篷：跨到自己下回合开始 → 力量恢复（%d → %d）"
			% [8, rg_ck_foe.effective_power()])

	# RunState：选定暗影刺客开局 → 用幽影替代树人、追加终结、赠品幻影斗篷
	RunState.end_run()
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.ROGUE)
	check(RunState.player_class == "暗影刺客",
			"角色系统：start_run 记录所选角色（暗影刺客）")
	check(RunState.deck_ids.size() == 13,
			"暗影刺客：开局同样是 13 张（实际 %d）" % RunState.deck_ids.size())
	check(RunState.deck_ids.has(8005) and RunState.deck_ids.has(GameEngine.RAID_SPELL_ID)
			and not RunState.deck_ids.has(8003) and not RunState.deck_ids.has(8004),
			"暗影刺客：卡组用幽影 8005 替换树人、追加终结 9086（不含树人 / 熊）")
	check(RunState.has_relic(GameEngine.PHANTOM_CLOAK_RELIC_ID)
			and not RunState.has_relic(GameEngine.WILD_FORM_RELIC_ID),
			"暗影刺客：开局获得角色赠品「幻影斗篷」6023（不带森林精魄的荒野形态）")
	check(RunState.relic_choice.size() == 3,
			"暗影刺客：赠品不占起点三选一的名额（仍有 3 个候选）")
	var rg_start := repo.starter_deck(PlayerClass.ROGUE)
	var rg_start_ids := {}
	for c in rg_start:
		rg_start_ids[c.id] = int(rg_start_ids.get(c.id, 0)) + 1
	check(rg_start.size() == 13 and int(rg_start_ids.get(8005, 0)) == 2
			and int(rg_start_ids.get(9086, 0)) == 1,
			"暗影刺客：CardRepo.starter_deck 同样跟着换角色（幽影×2 / 终结×1 / 共 %d）"
			% rg_start.size())
	RunState.end_run()


	# ---- 暗影刺客扩展（R45）：终结 / 连刺 / 敲晕 / 回转 / 影子猫 / 影魔 / 偷袭 / 疾风 /
	# 潜伏 / 幽灵 / 连环戏法 / 准备 / 怒涛 / 潜影者 / 回旋斩 / 预判 / 拒绝命运 /
	# 幽光·荧光草 / 潜入 / 不眠 ----
	var r45_pool := repo.reward_pool()
	check(int(r45_pool.size()) == 128, "R45+R50~R57：扩展全部进奖励池（总池 128，实际 %d）" % r45_pool.size())

	# 连刺（9087）：1 费 4 伤 + 卡组随机 0 费技能卡入手
	var r45_gg := _new_engine([], 30, 30)
	var r45_gg_foe := r45_gg.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_gg.state.deck.append(_card(9095, "怒涛", "技能", 2, 0, 0, 0, 0))
	r45_gg.state.deck.append(_card(GameEngine.RAID_SPELL_ID, "终结", "技能", 0, 0, 0, 0, 0))
	var r45_gg_hand := r45_gg.state.hand.size()
	r45_gg.state.hand.append(repo.get_card(GameEngine.GOUGE_ID))
	r45_gg.use_spell(r45_gg.state.hand.size() - 1, Vector2i(2, 1))
	check(r45_gg_foe.health == 51, "连刺：对目标 4 伤（55 → %d）" % r45_gg_foe.health)
	check(r45_gg.state.hand.size() == r45_gg_hand + 1
			and r45_gg.state.hand[r45_gg.state.hand.size() - 1].cost == 0,
			"连刺：卡组随机 0 费技能卡加入手卡（手里多 1 张 0 费技能）")

	# 敲晕（9088）：0 费 3 伤 + 本回合力量 -3
	var r45_st := _new_engine([], 30, 30)
	var r45_st_foe := r45_st.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_st.state.hand.append(repo.get_card(GameEngine.STUN_BLOW_ID))
	r45_st.use_spell(0, Vector2i(2, 1))
	check(r45_st_foe.health == 52 and r45_st_foe.debuff_stage == 1
			and r45_st_foe.effective_power() == 5,
			"敲晕：3 伤 + 力量 -3（55 → %d，8 → %d）"
			% [r45_st_foe.health, r45_st_foe.effective_power()])

	# 回转（9089）：抽 X 张（X = 本回合已用数），本回合结束不弃
	var r45_sp := _new_engine([], 30, 30)
	r45_sp.state.self_card_plays = 2
	r45_sp.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sp.state.deck.append(_card(9097, "预判", "技能", 0, 0, 0, 0, 0))
	r45_sp.state.hand.append(repo.get_card(GameEngine.SPIN_DRAW_ID))
	r45_sp.use_spell(0, null)
	check(r45_sp.state.hand.size() == 2, "回转：X=2 → 抽 2 张（实际 %d）" % r45_sp.state.hand.size())
	var r45_sp_k1: CardData = r45_sp.state.hand[0]
	var r45_sp_k2: CardData = r45_sp.state.hand[1]
	r45_sp.end_turn()
	check(r45_sp.state.hand.has(r45_sp_k1) and r45_sp.state.hand.has(r45_sp_k2),
			"回转：回合结束抽到的 2 张仍留在手里（弃牌区只剩回转自己）")

	# 影子猫（8006）：含此卡本回合第 3 张打出 → 卡组随机技能卡入手
	var r45_sc := _new_engine([], 30, 30)
	r45_sc.state.self_card_plays = 2
	r45_sc.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sc.state.hand.append(repo.get_card(GameEngine.SHADOW_CAT_ID))
	r45_sc.play_from_hand(0, Vector2i(4, 1))
	check(r45_sc.state.hand.size() == 1
			and r45_sc.state.hand[0].kind == "技能",
			"影子猫：含此卡本回合第 3 张 → 卡组随机技能卡入手")
	var r45_sc2 := _new_engine([], 30, 30)
	r45_sc2.state.self_card_plays = 1
	r45_sc2.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_sc2.state.hand.append(repo.get_card(GameEngine.SHADOW_CAT_ID))
	r45_sc2.play_from_hand(0, Vector2i(4, 1))
	check(r45_sc2.state.hand.is_empty() and r45_sc2.state.deck.size() == 1,
			"影子猫：只有第 2 张 → 效果落空，卡组不动")

	# 影魔（8007）：手卡技能牌本回合 -1 费；每张 0 费技能卡 +3 生命
	var r45_sd := _new_engine([], 30, 30)
	r45_sd.state.hand.append(repo.get_card(GameEngine.SHADOW_DEMON_ID))
	r45_sd.state.hand.append(_card(GameEngine.RAID_SPELL_ID, "终结", "技能", 0, 0, 0, 0, 0))
	var r45_sd_spell := _card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0)
	r45_sd.state.hand.append(r45_sd_spell)
	r45_sd.play_from_hand(0, Vector2i(4, 1))
	var r45_sd_p := r45_sd.state.unit_at(Vector2i(4, 1))
	check(r45_sd_p.health == 14,
			"影魔：1 张 0 费技能卡 → 生命 11+3=14（实际 %d）" % r45_sd_p.health)
	check(r45_sd.cost_of(r45_sd_spell) == 1,
			"影魔：手卡 2 费技能牌本回合 1 费（实际 %d）" % r45_sd.cost_of(r45_sd_spell))

	# 偷袭（9090）：满血 12 / 非满血 6
	var r45_sn := _new_engine([], 30, 30)
	var r45_sn_foe := r45_sn.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_sn.state.hand.append(repo.get_card(GameEngine.SNEAK_ID))
	r45_sn.use_spell(0, Vector2i(2, 1))
	check(r45_sn_foe.health == 43, "偷袭：满血目标 12 伤（55 → %d）" % r45_sn_foe.health)
	r45_sn.state.hand.append(repo.get_card(GameEngine.SNEAK_ID))
	r45_sn.use_spell(0, Vector2i(2, 1))
	check(r45_sn_foe.health == 37, "偷袭：非满血目标 6 伤（43 → %d）" % r45_sn_foe.health)

	# 疾风（9091 效果）：每使用一张卡 → 随机敌人 2 伤（自己打出时不触发）
	var r45_ga := _new_engine([], 30, 30)
	var r45_ga_e1 := r45_ga.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var r45_ga_e2 := r45_ga.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	r45_ga.state.energy = 15
	r45_ga.state.hand.append(repo.get_card(GameEngine.GALE_ID))
	r45_ga.use_effect(0)
	check(r45_ga_e1.health == 55 and r45_ga_e2.health == 55,
			"疾风：自己打出时不触发（55/55）")
	r45_ga.state.hand.append(repo.get_card(GameEngine.GOUGE_ID))
	r45_ga.use_spell(0, Vector2i(2, 0))
	check(r45_ga_e1.health + r45_ga_e2.health == 104,
			"疾风：再打一张 → 随机敌人 -2（合计 %d）" % (r45_ga_e1.health + r45_ga_e2.health))

	# 潜伏 + 幽光（9092 / 9099 效果）：回合开始多抽（0 费再抽 1）+ 荧光草塞手
	var r45_lt := _new_engine([], 30, 30)
	r45_lt.state.effects.append(repo.get_card(GameEngine.LATENT_ID))
	r45_lt.state.effects.append(repo.get_card(GameEngine.GLOW_ID))
	r45_lt.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_lt.state.deck.append(_card(9097, "预判", "技能", 0, 0, 0, 0, 0))
	for r45_lt_i in 5:
		r45_lt.state.deck.append(_card(8001, "木栅栏", "工事", 1, 0, 2, 0, 0))
	r45_lt._begin_turn(GameEngine.SIDE_SELF)
	var r45_lt_names := {}
	for c in r45_lt.state.hand:
		r45_lt_names[c.card_name] = true
	check(r45_lt.state.hand.size() == 8
			and r45_lt_names.has("预判") and r45_lt_names.has("火焰箭")
			and r45_lt_names.has("荧光草"),
			"潜伏+幽光：抽 5 + 潜伏 2 张（0 费再抽 1）+ 荧光草 = 8 张（实际 %d）"
			% r45_lt.state.hand.size())

	# 幽灵（8008）：自己回合开始时破坏 + 亡语卡组随机技能卡入手
	var r45_gh := _new_engine([], 30, 30)
	r45_gh.state.place(repo.get_card(GameEngine.GHOST_ID), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	for r45_gh_i in 5:
		r45_gh.state.deck.append(_card(8001, "木栅栏", "工事", 1, 0, 2, 0, 0))
	r45_gh.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_gh._begin_turn(GameEngine.SIDE_SELF)
	var r45_gh_gone := true
	for c in r45_gh.state.board:
		if r45_gh.state.board[c].card.id == GameEngine.GHOST_ID:
			r45_gh_gone = false
	var r45_gh_got := false
	for c in r45_gh.state.hand:
		if c.kind == "技能":
			r45_gh_got = true
	check(r45_gh_gone and r45_gh_got,
			"幽灵：回合开始自行破坏，亡语把卡组技能卡塞进手卡")

	# 连环戏法（9093）：含此卡第 3 张 → 10 伤 + 抽 1 张
	var r45_ct := _new_engine([], 30, 30)
	var r45_ct_foe := r45_ct.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_ct.state.self_card_plays = 2
	r45_ct.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_ct.state.hand.append(repo.get_card(GameEngine.COMBO_TRICK_ID))
	r45_ct.use_spell(0, Vector2i(2, 1))
	check(r45_ct_foe.health == 45 and r45_ct.state.hand.size() == 1,
			"连环戏法：含此卡第 3 张 → 10 伤 + 抽 1（55 → %d，手 %d）"
			% [r45_ct_foe.health, r45_ct.state.hand.size()])
	var r45_ct2 := _new_engine([], 30, 30)
	var r45_ct2_foe := r45_ct2.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_ct2.state.hand.append(repo.get_card(GameEngine.COMBO_TRICK_ID))
	r45_ct2.use_spell(0, Vector2i(2, 1))
	check(r45_ct2_foe.health == 50 and r45_ct2.state.hand.is_empty(),
			"连环戏法：只第 1 张 → 5 伤不抽（55 → %d）" % r45_ct2_foe.health)

	# 准备（9094）：抽 2，其中有 0 费 → 再抽 1（只多这一次）
	var r45_pp := _new_engine([], 30, 30)
	r45_pp.state.deck.append(_card(8001, "木栅栏", "工事", 1, 0, 2, 0, 0))
	r45_pp.state.deck.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_pp.state.deck.append(_card(9097, "预判", "技能", 0, 0, 0, 0, 0))
	r45_pp.state.hand.append(repo.get_card(GameEngine.PREPARE_ID))
	r45_pp.use_spell(0, null)
	check(r45_pp.state.hand.size() == 3,
			"准备：抽 2（含 0 费）→ 再抽 1 = 手里 3 张（实际 %d）" % r45_pp.state.hand.size())

	# 怒涛（9095）：10 伤 + 弃牌区所有 0 费卡回手
	var r45_tr := _new_engine([], 30, 30)
	var r45_tr_foe := r45_tr.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r45_tr_z1 := _card(9097, "预判", "技能", 0, 0, 0, 0, 0)
	var r45_tr_z2 := _card(9086, "终结", "技能", 0, 0, 0, 0, 0)
	r45_tr.state.discard.append(r45_tr_z1)
	r45_tr.state.discard.append(_card(9003, "火焰箭", "技能", 2, 0, 0, 0, 0))
	r45_tr.state.discard.append(r45_tr_z2)
	r45_tr.state.hand.append(repo.get_card(GameEngine.TORRENT_ID))
	r45_tr.use_spell(0, Vector2i(2, 1))
	check(r45_tr_foe.health == 45, "怒涛：10 伤（55 → %d）" % r45_tr_foe.health)
	check(r45_tr.state.hand.has(r45_tr_z1) and r45_tr.state.hand.has(r45_tr_z2)
			and r45_tr.state.discard.size() == 2,
			"怒涛：两张 0 费卡回手（弃牌区只剩非 0 费 + 怒涛自己）")

	# 潜影者（8009）：每用一张牌 +1 力量，攻击后重置
	var r45_lk := _new_engine([], 30, 30)
	r45_lk.state.place(repo.get_card(GameEngine.LURKER_ID), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	r45_lk.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var r45_lk_p := r45_lk.state.unit_at(Vector2i(4, 1))
	r45_lk._note_card_played(GameEngine.SIDE_SELF, null)
	r45_lk._note_card_played(GameEngine.SIDE_SELF, null)
	check(r45_lk_p.effective_power() == 5,
			"潜影者：用过 2 张牌 → 3+2=5（实际 %d）" % r45_lk_p.effective_power())
	r45_lk.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(r45_lk_p.effective_power() == 3,
			"潜影者：攻击后重置（实际 %d）" % r45_lk_p.effective_power())

	# 回旋斩（9096）：门槛（先 4 张其他卡）+ 十字只打敌方单位
	var r45_wb := _new_engine([], 30, 30)
	var r45_wb_e1 := r45_wb.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var r45_wb_e2 := r45_wb.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	r45_wb.state.place(_card(8003, "树人", "盟友", 3, 3, 8, 1, 1),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	r45_wb.state.hand.append(repo.get_card(GameEngine.WHIRL_BLADE_ID))
	var r45_wb_detail := r45_wb.use_spell(0, Vector2i(2, 1))
	check(r45_wb.state.hand.size() == 1 and r45_wb.state.energy == 5,
			"回旋斩：本回合其他卡不足 4 张 → 不能用（卡留在手、能量不动）")
	r45_wb.state.self_card_plays = 4
	r45_wb.use_spell(0, Vector2i(2, 1))
	check(r45_wb_e1.health == 38 and r45_wb_e2.health == 38,
			"回旋斩：十字敌方单位各 17 伤（55 → %d / %d）"
			% [r45_wb_e1.health, r45_wb_e2.health])
	check(r45_wb.state.unit_at(Vector2i(1, 1)).health == 8,
			"回旋斩：己方单位不吃伤害")

	# 预判（9097）②：卡组随机非 0 费技能卡入手（本卡照常进弃牌区）
	var r45_fs := _new_engine([], 30, 30)
	r45_fs.state.hand.append(repo.get_card(GameEngine.FORESIGHT_ID))
	r45_fs.state.deck.append(_card(9095, "怒涛", "技能", 2, 0, 0, 0, 0))
	r45_fs.use_spell(0, null)
	check(r45_fs.foresight_mode, "预判：打出后等待选择")
	r45_fs.foresight_choose(2)
	check(r45_fs.state.hand.size() == 1 and r45_fs.state.hand[0].cost == 2
			and r45_fs.state.discard.size() == 1,
			"预判②：卡组非 0 费技能卡入手，本卡进弃牌区")

	# 预判（9097）①：弃牌区选 0 费技能卡，之后本卡消失
	var r45_fs2 := _new_engine([], 30, 30)
	r45_fs2.state.hand.append(repo.get_card(GameEngine.FORESIGHT_ID))
	r45_fs2.use_spell(0, null)
	r45_fs2.state.discard.append(_card(9086, "终结", "技能", 0, 0, 0, 0, 0))
	r45_fs2.foresight_choose(1)
	var r45_fs2_opts := r45_fs2.foresight_options()
	check(r45_fs2.foresight_pick and r45_fs2_opts.size() == 1,
			"预判①：弃牌区只有 1 张 0 费技能卡可选")
	r45_fs2.foresight_pick_card(r45_fs2_opts[0])
	check(r45_fs2.state.hand.size() == 1 and r45_fs2.state.discard.is_empty(),
			"预判①：选回 0 费技能卡，本卡消失（弃牌区清空）")

	# 拒绝命运（9098）：弃光手卡 → 弃牌区选等量 → 本卡消失
	var r45_ft := _new_engine([], 30, 30)
	var r45_ft_a := _card(8001, "木栅栏", "工事", 1, 0, 2, 0, 0)
	var r45_ft_b := _card(8001, "木栅栏", "工事", 1, 0, 2, 0, 0)
	r45_ft.state.hand.append(r45_ft_a)
	r45_ft.state.hand.append(r45_ft_b)
	r45_ft.state.hand.append(repo.get_card(GameEngine.FATE_REJECT_ID))
	r45_ft.use_spell(2, null)
	check(r45_ft.fate_pending and r45_ft.fate_count == 2
			and r45_ft.state.hand.is_empty(),
			"拒绝命运：丢 2 张手卡，等待选回 2 张")
	r45_ft.fate_pick(0)
	r45_ft.fate_pick(0)
	check(r45_ft.state.hand.has(r45_ft_a) and r45_ft.state.hand.has(r45_ft_b)
			and r45_ft.state.discard.is_empty(),
			"拒绝命运：选回 2 张，本卡消失（弃牌区清空）")

	# 潜入（9100）：0 费 → 盟友移动到任意空格 + 本回合力量 +3
	var r45_if := _new_engine([], 30, 30)
	r45_if.state.place(_card(9001, "鸭子骑士", "盟友", 6, 3, 30, 1, 2),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r45_if.state.hand.append(repo.get_card(GameEngine.INFILTRATE_ID))
	var r45_if_bad := r45_if.cast_infiltrate(0, Vector2i(4, 1), Vector2i(0, 2))
	check(r45_if_bad.begins_with("（目的地") and r45_if.state.energy == 5,
			"潜入：对方后排是禁区（能量不动）")
	r45_if.cast_infiltrate(0, Vector2i(4, 1), Vector2i(3, 2))
	check(r45_if.state.unit_at(Vector2i(3, 2)) != null
			and r45_if.state.unit_at(Vector2i(4, 1)) == null
			and r45_if.state.unit_at(Vector2i(3, 2)).effective_power() == 6,
			"潜入：骑士移到 (3,2)，力量 3+3=6（实际 %d）"
			% r45_if.state.unit_at(Vector2i(3, 2)).effective_power())
	r45_if.end_turn()
	check(r45_if.state.unit_at(Vector2i(3, 2)).effective_power() == 3,
			"潜入：回合结束力量加成清除（实际 %d）"
			% r45_if.state.unit_at(Vector2i(3, 2)).effective_power())

	# 荧光草（8010）：在场时技能伤害 +1（连刺 4 → 5）
	var r45_gg2 := _new_engine([], 30, 30)
	var r45_gg2_foe := r45_gg2.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r45_gg2.state.place(repo.get_card(GameEngine.GLOWGRASS_ID), Vector2i(4, 0),
			GameEngine.SIDE_SELF)
	r45_gg2.state.hand.append(repo.get_card(GameEngine.GOUGE_ID))
	r45_gg2.use_spell(0, Vector2i(2, 1))
	check(r45_gg2_foe.health == 50, "荧光草：连刺 4+1=5 伤（55 → %d）" % r45_gg2_foe.health)

	# 不眠（9101）：结算收尾手里没牌 → 抽 1，抽到的 0 费卡本回合 +1 费
	var r45_sl := _new_engine([], 30, 30)
	r45_sl.state.effects.append(repo.get_card(GameEngine.SLEEPLESS_ID))
	r45_sl.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r45_sl_c := _card(9086, "终结", "技能", 0, 0, 0, 0, 0)
	r45_sl.state.deck.append(r45_sl_c)
	r45_sl.state.hand.append(repo.get_card(GameEngine.RAID_SPELL_ID))
	r45_sl.use_spell(0, Vector2i(2, 1))
	check(r45_sl.state.hand.size() == 1 and r45_sl.state.hand[0] == r45_sl_c,
			"不眠：手里没牌 → 补抽 1 张")
	check(r45_sl.cost_of(r45_sl_c) == 1,
			"不眠：抽到的 0 费卡本回合 1 费（实际 %d）" % r45_sl.cost_of(r45_sl_c))

	# R45 基线：角色归属（森林精魄 99 / 暗影刺客 25 —— R48 +回响·闪躲 2 张、R49 +收尾 1 张、R50 +爆炸陷阱 1 张）
	var r45_cls := repo.all_cards()
	var r45_cls_count := {}
	for c in r45_cls:
		r45_cls_count[c.card_class] = int(r45_cls_count.get(c.card_class, 0)) + 1
	check(int(r45_cls_count.get(PlayerClass.DRUID, 0)) == 105
			and int(r45_cls_count.get(PlayerClass.ROGUE, 0)) == 48,
			"R45：全库角色归属（森林精魄 %d / 暗影刺客 %d）"
			% [int(r45_cls_count.get(PlayerClass.DRUID, 0)),
				int(r45_cls_count.get(PlayerClass.ROGUE, 0))])

	# ---- R47：难度档位 / 事件遭遇战计入难度 / 奖励池角色过滤 / 荒野形态强化 ----

	# 难度档位：0 = 战斗回 3 + 休息 40%；1 = 战斗不回 + 休息 40%；2 = 战斗不回 + 休息 25%（原状）
	RunState.set_difficulty(0)
	RunState.reset(50)
	check(RunState.battle_win_heal() == 3 and RunState.rest_heal_amount() == 20,
			"难度 0：战斗回 3 血、休息 50×40%%→%d" % RunState.rest_heal_amount())
	RunState.take_damage(30)
	check(RunState.rest() == 20 and RunState.hp == 40,
			"难度 0：休息实际回 20（20/50 → %d/50）" % RunState.hp)
	RunState.set_difficulty(1)
	RunState.reset(50)
	RunState.take_damage(30)
	check(RunState.battle_win_heal() == 0 and RunState.rest_heal_amount() == 20,
			"难度 1：战斗结束不回血、休息仍 40%（20）")
	RunState.set_difficulty(2)
	check(RunState.battle_win_heal() == 0 and RunState.rest_heal_amount() == 13,
			"难度 2：战斗结束不回血、休息 50×25%→13（与加入档位前完全一致）")
	check(RunState.rest() == 13 and RunState.hp == 33,
			"难度 2：休息实际回 13（20/50 → %d/50）" % RunState.hp)
	check(RunState.difficulty_name() == "困难" and RunState.difficulty_note() != "",
			"难度档位：名称 / 说明文案齐备（当前 %s）" % RunState.difficulty_name())
	check(RunState.DIFFICULTY_NAMES == ["宽松", "标准", "困难"],
			"R58 难度 2 改名为「困难」（%s）" % str(RunState.DIFFICULTY_NAMES))
	RunState.set_difficulty(9)
	check(RunState.difficulty == 2, "难度档位：越界输入被钳制到 2")
	RunState.set_difficulty(-3)
	check(RunState.difficulty == 0, "难度档位：负数被钳制到 0")
	check(RunState.DIFFICULTY_COUNT == 3 and RunState.DIFFICULTY_BATTLE_HEAL.size() == 3
			and RunState.DIFFICULTY_REST_PCT.size() == 3,
			"难度档位：共 3 档，回复表长度齐平")
	RunState.reset(50)

	# 事件节点遭遇怪物：同样计入「普通战斗胜场」（否则永远停在简单档、可反复刷简单战斗）
	RunState.end_run()
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
	RunState.on_battle_won("event")
	check(RunState.battle_wins == 1, "R47：事件遭遇战计入普通战斗胜场（%d）" % RunState.battle_wins)
	check(int(RunState.next_level({"type": "event"})["tier"]) == GameLevels.TIER_NORMAL_EASY,
			"事件遭遇战：第 1 场仍为简单")
	RunState.on_battle_won("event")
	RunState.on_battle_won("event")
	check(int(RunState.next_level({"type": "event"})["tier"]) == GameLevels.TIER_NORMAL_HARD,
			"事件遭遇战：第 3 场起升为困难（不再能靠怪物事件刷简单）")
	check(RunState.offer_relic_drop("event") == -1,
			"事件遭遇战：不掉落道具（仍按普通战斗处理）")

	# 奖励池角色过滤：互相看不到对方的卡
	check(repo.is_own_class_card(repo.get_card(8004), PlayerClass.DRUID)
			and not repo.is_own_class_card(repo.get_card(8004), PlayerClass.ROGUE)
			and not repo.is_own_class_card(repo.get_card(9082), PlayerClass.ROGUE)
			and repo.is_own_class_card(repo.get_card(9082), PlayerClass.DRUID),
			"角色卡判定：熊 8004 / 虚空主宰 9082 只属于森林精魄")
	var r47_dr := repo.reward_pool_for(PlayerClass.DRUID)
	var r47_rg := repo.reward_pool_for(PlayerClass.ROGUE)
	var r47_dr_ids := {}
	for c in r47_dr:
		r47_dr_ids[c.id] = true
	var r47_rg_ids := {}
	for c in r47_rg:
		r47_rg_ids[c.id] = true
	check(r47_dr_ids.has(9084) and not r47_rg_ids.has(9084),
			"奖励池过滤：火墙术 9084 是森林精魄卡 → 暗影刺客摇不到")
	check(not r47_dr_ids.has(9087) and not r47_dr_ids.has(9099) and not r47_dr_ids.has(9101),
			"奖励池过滤：森林精魄摇不到暗影刺客卡（连刺 / 幽光 / 不眠）")
	check(not r47_rg_ids.has(9082) and not r47_rg_ids.has(9085) and not r47_rg_ids.has(9021),
			"奖励池过滤：暗影刺客摇不到森林精魄卡（虚空主宰 / 蓄力 / 白魔法师）")
	check(r47_dr.size() == 60 and r47_rg.size() == 45
			and r47_dr.size() + r47_rg.size() == repo.reward_pool().size()
			- repo.reward_pool_for(PlayerClass.MECH).size(),
			"奖励池过滤：森林精魄 %d 张 / 暗影刺客 %d 张（两者之和 + 机械之心 %d = 完整池 %d）"
			% [r47_dr.size(), r47_rg.size(), repo.reward_pool_for(PlayerClass.MECH).size(),
				repo.reward_pool().size()])
	# roll 默认按 RunState.player_class 过滤
	RunState.player_class = PlayerClass.ROGUE
	var r47_seen := {}
	var r47_rng := RandomNumberGenerator.new()
	r47_rng.seed = 99
	for i in 300:
		for c in CardReward.roll(repo, "normal", 3, r47_rng):
			r47_seen[c.id] = true
	var r47_bad := 0
	for cid: int in r47_seen:
		if not repo.is_own_class_card(repo.get_card(cid), PlayerClass.ROGUE):
			r47_bad += 1
	check(r47_bad == 0 and r47_seen.size() >= 15,
			"CardReward.roll：暗影刺客 300 次抽取（%d 种卡）全是本角色卡" % r47_seen.size())
	RunState.end_run()

	# 荒野形态 R60 重做后：**熊在场不再提供任何 HP 减伤**（旧 R47 的 -1 已移除）。
	# 新的减伤只认「每场第一次普通攻击直击 HP」，与熊无关。
	var r47_wf := _new_engine([], 30, 30)
	r47_wf.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
	check(r47_wf._hp_damage_taken(5) == 5, "荒野形态：_hp_damage_taken 不再减伤（5）")
	r47_wf.state.place(CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r47_wf._hp_damage_taken(5) == 5,
			"荒野形态：熊在场也不减伤了（R60 移除，5 伤仍是 5）")
	check(r47_wf._hp_damage_taken(2) == 2,
			"荒野形态：熊在场 2 伤仍是 2（旧逻辑会变 1）")
	var r47_wf_bear := r47_wf.state.unit_at(Vector2i(4, 1))
	r47_wf_bear.health = 0
	check(r47_wf._hp_damage_taken(5) == 5, "荒野形态：熊倒下后同样不减伤（5）")
	# 效果减伤仍照常生效（旧逻辑里与荒野形态叠加的那条）
	var r47_wf3 := _new_engine([], 30, 30)
	r47_wf3.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
	var r47_red := _card(9005, "减伤效果", "效果", 1, 0, 0, 0, 0)
	r47_red.traits = ["减伤"]
	r47_red.value = 3
	r47_wf3.state.effects.append(r47_red)
	check(r47_wf3._hp_damage_taken(5) == 2,
			"效果减伤：-3 照常生效（5 → 2），与荒野形态无关")

	# ---- R48：回响（9102）/ 闪躲（9103）----
	var r48_echo_c := repo.get_card(GameEngine.ECHO_ID)
	var r48_dodge_c := repo.get_card(GameEngine.DODGE_ID)
	check(r48_echo_c != null and r48_echo_c.card_name == "回响" and r48_echo_c.cost == 1
			and r48_echo_c.rarity == 2 and r48_echo_c.card_class == PlayerClass.ROGUE
			and r48_echo_c.kind == "技能"
			and r48_echo_c.target_mode == "none" and not r48_echo_c.needs_target(),
			"回响 9102：1 费史诗（R70 由稀有升）暗影刺客技能，不用选目标")
	check(r48_dodge_c != null and r48_dodge_c.card_name == "闪躲" and r48_dodge_c.cost == 0
			and r48_dodge_c.rarity == 0 and r48_dodge_c.card_class == PlayerClass.ROGUE
			and r48_dodge_c.kind == "技能" and r48_dodge_c.target_mode == "none",
			"闪躲 9103：0 费普通暗影刺客技能，不用选目标")

	# 回响：所有敌人各 2 伤 + 力量 -1；使用后返回手卡
	var r48_e := _new_engine([], 30, 30)
	var r48_ee1 := r48_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var r48_ee2 := r48_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	var r48_e_own := r48_e.state.place(_card(8003, "树人", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r48_e.state.hand.append(CardData.from_dict(r48_echo_c.to_dict()))
	r48_e.use_spell(0, null)
	check(r48_ee1.health == 53 and r48_ee2.health == 53 and r48_e_own.health == 8,
			"回响：所有敌人各 2 伤（55 → %d / %d），己方单位不吃（%d）"
			% [r48_ee1.health, r48_ee2.health, r48_e_own.health])
	check(r48_ee1.effective_power() == 7 and r48_ee2.effective_power() == 7,
			"回响：所有敌人力量 -1（8 → %d / %d）"
			% [r48_ee1.effective_power(), r48_ee2.effective_power()])
	check(r48_ee1.debuff_stage == 1 and r48_ee2.debuff_stage == 1,
			"回响：降力量与敲晕/幻影斗篷同源（debuff_stage=1，敌方回合结束时清）")
	check(r48_e.state.energy == 4, "回响：1 费（能量 5 → %d）" % r48_e.state.energy)
	check(r48_e.state.hand.size() == 1 and r48_e.state.hand[0].id == GameEngine.ECHO_ID
			and r48_e.state.discard.is_empty(),
			"回响：使用后返回手卡（不进弃牌区）")
	r48_e.use_spell(0, null)
	check(r48_ee1.health == 51 and r48_ee2.health == 51 and r48_e.state.energy == 3
			and r48_e.state.hand.size() == 1,
			"回响：回手后可再打（55 → %d，能量 %d，仍在手卡）"
			% [r48_ee1.health, r48_e.state.energy])

	# 回响：费用下限 1（任何减费都压不到 0）
	var r48_cf := _new_engine([], 30, 30)
	var r48_cf_card := CardData.from_dict(r48_echo_c.to_dict())
	r48_cf.state.hand.append(r48_cf_card)
	check(r48_cf.cost_of(r48_cf_card) == 1, "回响：无减费时费用 1")
	r48_cf.state.self_cost_reduction = 3
	check(r48_cf.cost_of(r48_cf_card) == 1, "回响：-3 减费后仍是最低 1 费（不会变 0）")
	check(r48_cf.cost_of(_card(8002, "攻击", "技能", 1, 0, 0, 0, 0)) == 0,
			"对照：普通 1 费卡同样减费会被压到 0（只有回响有下限）")
	r48_cf.state.self_cost_reduction = 0
	r48_cf.state.turn_free[r48_cf_card] = true
	check(r48_cf.cost_of(r48_cf_card) == 1, "回响：本回合免费名单也压不到 0（最低 1 费）")
	r48_cf.state.energy = 0
	check(not r48_cf.can_pay_card(r48_cf_card), "回响：0 能量时不能打（费用下限 = 1）")
	r48_cf.state.energy = 1
	check(r48_cf.can_pay_card(r48_cf_card), "回响：1 点能量即可打")

	# 回响：场上没有敌人不直击对方 HP；免疫法术的敌人不受伤也不被削弱
	var r48_e2 := _new_engine([], 30, 30)
	r48_e2.state.hand.append(CardData.from_dict(r48_echo_c.to_dict()))
	r48_e2.use_spell(0, null)
	check(r48_e2.state.hp_opponent == 30 and r48_e2.state.hand.size() == 1,
			"回响：敌方场上没单位 → 不直击对方 HP（仍 %d），卡照回手"
			% r48_e2.state.hp_opponent)
	var r48_e3 := _new_engine([], 30, 30)
	var r48_im := r48_e3.state.place(_card(9026, "免疫怪", "盟友", 5, 5, 20, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r48_im.card.traits = [GameEngine.SPELL_IMMUNE_TRAIT]
	r48_e3.state.hand.append(CardData.from_dict(r48_echo_c.to_dict()))
	r48_e3.use_spell(0, null)
	check(r48_im.health == 20 and r48_im.effective_power() == 5,
			"回响：免疫法术的敌人既不受伤也不被削弱（%d / %d）"
			% [r48_im.health, r48_im.effective_power()])

	# 闪躲：直到下个回合开始，自己受到的伤害由随机盟友代受
	var r48_d := _new_engine([], 30, 30)
	var r48_d_ally := r48_d.state.place(_card(8005, "幽影", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r48_d.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d.use_spell(0, null)
	check(r48_d.dodge_active(GameEngine.SIDE_SELF) and r48_d.state.energy == 5,
			"闪躲：0 费；打出后「盟友代受」窗口开启（能量仍是 %d）" % r48_d.state.energy)
	r48_d._damage_player(GameEngine.SIDE_SELF, 5, "测试")
	check(r48_d_ally.health == 3 and r48_d.state.hp_self == 30,
			"闪躲：5 伤全部由盟友代受（幽影 8 → %d，我方 HP 仍是 %d）"
			% [r48_d_ally.health, r48_d.state.hp_self])
	r48_d._damage_player(GameEngine.SIDE_SELF, 10, "测试")
	check(r48_d.state.hp_self == 23 and r48_d.state.unit_at(Vector2i(4, 1)) == null,
			"闪躲：盟友只剩 3 血 → 吃掉 3 点后倒下，超出 7 点自己承担（HP 30 → %d）"
			% r48_d.state.hp_self)

	# 闪躲：窗口在自己下个回合开始到期（含中间的敌方回合）
	var r48_d2 := _new_engine([], 30, 30)
	r48_d2.state.place(_card(8005, "幽影", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r48_d2.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d2.use_spell(0, null)
	r48_d2._begin_turn(GameEngine.SIDE_SELF)      # 下个回合开始 → 到期
	check(not r48_d2.dodge_active(GameEngine.SIDE_SELF),
			"闪躲：自己下个回合开始时窗口到期")
	r48_d2._damage_player(GameEngine.SIDE_SELF, 4, "测试")
	check(r48_d2.state.hp_self == 26
			and r48_d2.state.unit_at(Vector2i(4, 1)).health == 8,
			"闪躲：窗口过期后伤害回到自己身上（HP 30 → %d，盟友满血 %d）"
			% [r48_d2.state.hp_self, r48_d2.state.unit_at(Vector2i(4, 1)).health])

	# 闪躲：没有盟友 / 只有工事 → 伤害仍归自己；敌方 AI 打出无效
	var r48_d3 := _new_engine([], 30, 30)
	r48_d3.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d3.use_spell(0, null)
	r48_d3._damage_player(GameEngine.SIDE_SELF, 4, "测试")
	check(r48_d3.state.hp_self == 26, "闪躲：场上没有盟友 → 伤害仍由自己承担（HP 30 → %d）"
			% r48_d3.state.hp_self)
	var r48_d4 := _new_engine([], 30, 30)
	var r48_d4_fence := r48_d4.state.place(_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r48_d4.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d4.use_spell(0, null)
	r48_d4._damage_player(GameEngine.SIDE_SELF, 4, "测试")
	check(r48_d4.state.hp_self == 26 and r48_d4_fence.health == 6,
			"闪躲：工事（木栅栏）不算「盟友」→ 不代受（HP 30 → %d，栅栏 %d）"
			% [r48_d4.state.hp_self, r48_d4_fence.health])
	var r48_d5 := _new_engine([], 30, 30)
	r48_d5._run_spell_effect(r48_dodge_c, null, GameEngine.SIDE_OPPONENT)
	check(not r48_d5.dodge_active(GameEngine.SIDE_OPPONENT)
			and not r48_d5.dodge_active(GameEngine.SIDE_SELF),
			"闪躲：敌方 AI 打出无效（只保我方窗口）")

	# 闪躲：有多个盟友时只挑一个代受
	var r48_d6 := _new_engine([], 30, 30)
	var r48_d6_a1 := r48_d6.state.place(_card(8005, "幽影", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	var r48_d6_a2 := r48_d6.state.place(_card(8005, "幽影", "盟友", 3, 3, 8, 1, 1),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r48_d6.state.hand.append(CardData.from_dict(r48_dodge_c.to_dict()))
	r48_d6.use_spell(0, null)
	r48_d6._damage_player(GameEngine.SIDE_SELF, 4, "测试")
	check((r48_d6_a1.health == 4) != (r48_d6_a2.health == 4) and r48_d6.state.hp_self == 30,
			"闪躲：多个盟友时只随机挑一个代受（%d / %d，HP 仍 %d）"
			% [r48_d6_a1.health, r48_d6_a2.health, r48_d6.state.hp_self])

	# ---- R49：收尾（9104）—— 1 费稀有；平时 6 伤，打出时若它是手卡里仅剩的一张 → 22 伤
	# （R71 数值加强：4/15 → 6/22；断言里的血量数字同步换算） ----
	var r49_c := repo.get_card(GameEngine.FINISHER_ID)
	check(r49_c != null and r49_c.card_name == "收尾" and r49_c.cost == 1
			and r49_c.rarity == 1 and r49_c.card_class == PlayerClass.ROGUE
			and r49_c.kind == "技能" and r49_c.target_mode == "unit" and r49_c.needs_target(),
			"收尾 9104：1 费稀有暗影刺客技能，需要选一个目标")
	check(r49_c.effect_text.contains("6 点伤害") and r49_c.effect_text.contains("22 点伤害")
			and r49_c.effect_text.contains("仅剩的一张"),
			"收尾：卡面文案写死 6 / 22 两档（R71 加强后）（%s）" % r49_c.effect_text)
	check(GameEngine.FINISHER_DMG == 6 and GameEngine.FINISHER_LAST_DMG == 22,
			"R71 收尾数值：基础 %d / 触发 %d（写死常量，回归钉住）"
			% [GameEngine.FINISHER_DMG, GameEngine.FINISHER_LAST_DMG])

	# 手卡里还有别的牌 → 4 伤
	var r49_e := _new_engine([], 30, 30)
	var r49_foe := r49_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r49_e.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_e.state.hand.append(_card(8002, "攻击", "技能", 1, 0, 0, 0, 0))
	r49_e.use_spell(0, Vector2i(2, 1))
	check(r49_foe.health == 49 and r49_e.state.energy == 4,
			"收尾：手卡里还有别的牌 → 6 伤（55 → %d，能量 5 → %d）"
			% [r49_foe.health, r49_e.state.energy])

	# 打出时它是手卡里仅剩的一张 → 15 伤；用完进弃牌区（不回手，与回响不同）
	var r49_e2 := _new_engine([], 30, 30)
	var r49_foe2 := r49_e2.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r49_e2.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_e2.use_spell(0, Vector2i(2, 1))
	check(r49_foe2.health == 33,
			"收尾：打出时是手卡里仅剩的一张 → 22 伤（55 → %d）" % r49_foe2.health)
	check(r49_e2.state.hand.is_empty() and r49_e2.state.discard.size() == 1
			and r49_e2.state.discard[0].id == GameEngine.FINISHER_ID,
			"收尾：用完进弃牌区（不回手）")

	# 判定看的是「它自己被拿走之后」的手牌 → 手里还有牌就不算最后一张
	var r49_e3 := _new_engine([], 30, 30)
	var r49_foe3 := r49_e3.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r49_e3.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_e3.state.hand.append(_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0))
	r49_e3.use_spell(0, Vector2i(2, 1))     # 打出后手里还留着一张木栅栏
	check(r49_foe3.health == 49,
			"收尾：手卡 2 张时打出（手里还剩一张）→ 仍是 6 伤（55 → %d）" % r49_foe3.health)

	# 免疫法术 / 场上没有敌方单位
	var r49_e4 := _new_engine([], 30, 30)
	var r49_im := r49_e4.state.place(_card(9026, "免疫怪", "盟友", 5, 5, 20, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r49_im.card.traits = [GameEngine.SPELL_IMMUNE_TRAIT]
	r49_e4.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_e4.use_spell(0, Vector2i(2, 1))
	check(r49_im.health == 20 and r49_e4.state.discard.size() == 1,
			"收尾：免疫法术的目标不受伤（%d），卡照常消耗" % r49_im.health)
	var r49_hp := _new_engine([], 30, 30)
	r49_hp.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_hp.use_spell(0, Vector2i(-1, -1))
	check(r49_hp.state.hp_opponent == 8,
			"收尾：场上没有敌方单位 → 直击对方 HP（最后一张 → 22 伤，30 → %d）"
			% r49_hp.state.hp_opponent)

	# 敌方侧对称：对手手牌只剩这一张时也是 15 伤
	var r49_op := _new_engine([], 30, 30)
	r49_op.state.opp_hand_count = 1
	var r49_op_me := r49_op.state.place(_card(8005, "幽影", "盟友", 3, 3, 40, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r49_op.remote_spell(CardData.from_dict(r49_c.to_dict()), Vector2i(4, 1),
			GameEngine.SIDE_OPPONENT)
	check(r49_op_me.health == 18,
			"收尾：敌方侧对称（对手只剩这一张 → 22 伤，幽影 40 → %d）" % r49_op_me.health)

	# 与蓄力叠加：生效 2 次 → 第一段 22 伤；目标已倒下时第二段按通用规则溢出（见下方断言）
	var r49_ch := _new_engine([], 30, 30)
	var r49_ch_foe := r49_ch.state.place(_card(9999, "木桩", "盟友", 5, 5, 12, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r49_ch.state.hand.append(_card(GameEngine.CHARGE_SPELL_ID, "蓄力", "技能", 2, 0, 0, 0, 0))
	r49_ch.state.hand.append(CardData.from_dict(r49_c.to_dict()))
	r49_ch.use_spell(0, null)                       # 蓄力（此刻手里还剩收尾）
	var r49_ch_layers := r49_ch.charge_count(GameEngine.SIDE_SELF)
	var r49_ch_res := r49_ch.use_spell(0, Vector2i(2, 1))   # 收尾：手卡仅剩它 → 22 伤 ×2
	check(r49_ch_layers == 1 and r49_ch_res.contains("蓄力 ×2"),
			"收尾：蓄力可正常翻倍（层数 %d / 结算 %s）" % [r49_ch_layers, r49_ch_res])
	check(r49_ch_foe.health <= 0 and r49_ch.state.unit_at(Vector2i(2, 1)) == null
			and r49_ch.state.hp_opponent == 8,
			"收尾 + 蓄力：生效 2 次 —— 第一段 22 伤打死 12 血目标；第二段目标已消失 → 溢出到对方 HP（30 → %d）"
			% r49_ch.state.hp_opponent)

	# ================= R74：陷阱 → 全新卡种「场地」=================
	# 5 张 xx陷阱（8011 爆炸 / 8012 冰霜 / 8013 冻结 / 8014 剧毒 / 8016 穿刺）
	# 统一改成 kind = "场地"：**不是单位**，钉在格子上，敌人**移动进入**时触发一次。
	# 旧语义（被普通攻击即死+ 引爆 / 技能击破不触发）已全部作废。
	var r74_cards := {
		GameEngine.TRAP_ID: "爆炸陷阱", GameEngine.FROST_TRAP_ID: "冰霜陷阱",
		GameEngine.FREEZE_TRAP_ID: "冻结陷阱", GameEngine.POISON_TRAP_ID: "剧毒陷阱",
		GameEngine.PIERCE_TRAP_ID: "穿刺陷阱",
	}
	for r74_id: int in r74_cards:
		var r74_c: CardData = repo.get_card(r74_id)
		check(r74_c != null and r74_c.kind == "场地" and r74_c.is_field()
				and r74_c.card_class == PlayerClass.ROGUE and not r74_c.is_fort()
				and r74_c.card_name == str(r74_cards[r74_id]),
			"R74 卡 %d：kind=场地（不再是工事）、%s、仍属暗影刺客" % [r74_id, r74_cards[r74_id]])
		check(r74_c.effect_text.contains("移动经过")
				and r74_c.effect_text.contains("立即停止这次移动")
				and not r74_c.effect_text.contains("被攻击"),
			"R74/R80 卡 %d：卡面写「敌人移动经过此格时触发 + 立即停止移动」（不再是被攻击即死）"
				% r74_id)
		check(repo.reward_pool_for(PlayerClass.ROGUE).any(func(c): return c.id == r74_id)
				and not repo.reward_pool_for(PlayerClass.DRUID).any(func(c): return c.id == r74_id),
			"R74 卡 %d：仍进暗影刺客奖励池，不进森林精魄池" % r74_id)
	# 场地不再有「生命」概念（不是单位）
	check(repo.get_card(GameEngine.TRAP_ID).health == 0
			and repo.get_card(GameEngine.PIERCE_TRAP_ID).health == 0,
		"R74 场地卡：生命 = 0（不是单位、没有 HP、不能被打）")

	# 机关工坊 8015：卡名去掉「陷阱」，但**仍是工事**（不属于场地）
	var r74_wshop: CardData = repo.get_card(GameEngine.WORKSHOP_ID)
	check(r74_wshop != null and r74_wshop.card_name == "机关工坊"
			and r74_wshop.kind == "工事" and r74_wshop.is_fort() and not r74_wshop.is_field()
			and r74_wshop.traits.has(GameEngine.WORKSHOP_TRAIT),
		"R74 机关工坊 8015：卡名改为「机关工坊」，仍是工事（不属于场地卡）")
	# 场地精通 9105：词条改名 + 口径改成「场地」
	var r74_mas: CardData = repo.get_card(GameEngine.TRAP_MASTERY_ID)
	check(r74_mas != null and r74_mas.traits.has("场地精通")
			and not r74_mas.traits.has("陷阱精通")
			and r74_mas.effect_text.contains("场地效果"),
		"R74 场地精通 9105：由「陷阱精通」改名，口径从工事改成场地")
	check(GameEngine.TRAP_MASTERY_TRAIT == "场地精通",
		"R74 引擎常量：TRAP_MASTERY_TRAIT = 场地精通")
	# 双重场地 9108
	var r74_df: CardData = repo.get_card(GameEngine.DOUBLE_TRAP_ID)
	check(r74_df != null and r74_df.card_name == "双重场地"
			and r74_df.effect_text.contains("场地效果的格子"),
		"R74 双重场地 9108：改名 + 口径改成「已有场地效果的格子」")

	# ---- 场地的基础行为：不是单位、每格 1 个、移动进入才触发 ----
	# ① 打出去**不进 board**，而是进 field_effects（完全独立的数据）
	var r74_a := _new_engine([], 30, 30)
	var r74_a_card: CardData = repo.get_card(GameEngine.TRAP_ID)
	r74_a.state.hand.append(CardData.from_dict(r74_a_card.to_dict()))
	r74_a.state.energy = 5
	var r74_a_ret: Placement = r74_a.play_from_hand(0, Vector2i(4, 1))
	check(r74_a.state.field_at(Vector2i(4, 1)) != null
			and r74_a.state.unit_at(Vector2i(4, 1)) == null
			and r74_a_ret == null,
		"R74 场地卡：打出后**不在 board 上**（不是单位）、登记到该格的场地效果")
	check(r74_a.state.energy == 2 and r74_a.state.hand.is_empty(),
		"R74 场地卡：正常扣费 3 点（5 → %d）并离手" % r74_a.state.energy)
	# ② **每格只能有一个效果**：再放一张 → 顶掉旧的
	var r74_old: CardData = r74_a.state.set_field(
			CardData.from_dict(repo.get_card(GameEngine.FROST_TRAP_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r74_old != null and r74_a.state.field_at(Vector2i(4, 1)).card_name == "冰霜陷阱",
		"R74 场地：同一格再放一个 → 旧的被顶掉，现在该格是「%s」"
			% r74_a.state.field_at(Vector2i(4, 1)).card_name)
	check(r74_a.state.field_effects.size() == 1,
		"R74 场地：每格只保留 1 个效果（当前 %d 个格子有场地）"
			% r74_a.state.field_effects.size())
	# ③ 放自己后排行 → 拒绝并**退费**
	var r74_b := _new_engine([], 30, 30)
	r74_b.state.hand.append(CardData.from_dict(r74_a_card.to_dict()))
	r74_b.state.energy = 5
	var r74_ban := GameEngine.back_row(GameEngine.SIDE_SELF)
	var r74_b_ret: Placement = r74_b.play_from_hand(0, Vector2i(r74_ban, 1))
	check(r74_b_ret == null and r74_b.state.field_effects.is_empty()
			and r74_b.state.energy == 5 and not r74_b.state.hand.is_empty(),
		"R74 场地：不能放自己后排行（%s）→ 拒绝出手且退还费用（能量仍 %d）"
			% [r74_ban, r74_b.state.energy])
	check(not GameEngine.field_place_allowed(Vector2i(r74_ban, 1))
			and GameEngine.field_place_allowed(Vector2i(0, 1))
			and GameEngine.field_place_allowed(Vector2i(4, 1)),
		"R74 场地：合法性判定唯一口 field_place_allowed —— 仅排除自己后排行（敌方半场可放）")

	# ---- 核心：敌人「移动到此格」才触发，且触发后消失 ----
	# 爆炸场地：敌人从 (3,1) 移动到 (4,1) → 十字 18 伤，**中心格那个踩雷者也吃**
	var r74_expl: CardData = repo.get_card(GameEngine.TRAP_ID)
	var r74_c := _new_engine([], 30, 30)
	var r74_foe: Placement = r74_c.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var r74_pal: Placement = r74_c.state.place(_card(8003, "树人", "盟友", 2, 2, 10, 1, 1),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	var r74_far: Placement = r74_c.state.place(_card(8003, "树人", "盟友", 2, 2, 30, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	r74_c.state.hand.append(CardData.from_dict(r74_expl.to_dict()))
	r74_c.play_from_hand(0, Vector2i(4, 1))
	# 站在旁边**不动** → 不触发（原本就在此格的情况不触发）
	check(r74_c.state.field_at(Vector2i(4, 1)) != null,
		"R74 爆炸场地：放着不触发（场地还在原格）")
	r74_c.current_side = GameEngine.SIDE_OPPONENT
	r74_c.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_c.state.field_at(Vector2i(4, 1)) == null,
		"R74 爆炸场地：敌人移动进入后**场地消失**（一次性）")
	check(r74_foe.health == 55 - GameEngine.TRAP_DMG,
		"R74 爆炸场地：踩上来的那个敌人自己也吃 %d 伤（55 → %d）"
			% [GameEngine.TRAP_DMG, r74_foe.health])
	check(r74_pal.health <= 0,
		"R74 爆炸场地：不分敌我 —— 旁边的树人被炸死（%d）" % r74_pal.health)
	check(r74_far.health == 30,
		"R74 爆炸场地：对角格（曼哈顿距离 2）不受伤（树人仍 %d）" % r74_far.health)

	# 原本就站在场地上的敌人**不触发**（用户口径）
	var r74_stay := _new_engine([], 30, 30)
	var r74_stayer: Placement = r74_stay.state.place(_card(8003, "树人", "盟友", 2, 2, 20, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r74_stay.state.set_field(CardData.from_dict(r74_expl.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r74_stay.current_side = GameEngine.SIDE_SELF
	r74_stay._begin_turn(GameEngine.SIDE_SELF)
	check(r74_stayer.health == 20 and r74_stay.state.field_at(Vector2i(4, 1)) != null,
		"R74 场地：**原本站在该格**的单位不触发（血 %d、场地仍在）" % r74_stayer.health)

	# ---- 其余四种：效果打给移动进来的那个单位 ----
	# 冰霜场地：4 伤 + 禁足
	var r74_f := _new_engine([], 30, 30)
	var r74_f_foe: Placement = r74_f.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var r74_f_pal: Placement = r74_f.state.place(_card(8003, "树人", "盟友", 2, 2, 30, 1, 1),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	r74_f.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.FROST_TRAP_ID).to_dict()))
	r74_f.play_from_hand(0, Vector2i(4, 1))
	r74_f.end_turn()   # → 敌方回合（下面由敌方移动进入场地）
	r74_f.current_side = GameEngine.SIDE_OPPONENT
	r74_f.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_f_foe.health == 55 - GameEngine.FROST_TRAP_DMG
			and r74_f_foe.rooted == 1 and r74_f.state.field_at(Vector2i(4, 1)) == null,
			"R74 冰霜场地：移动进入 → %d 伤 + 禁足（55 → %d、rooted=%d），场地消失"
			% [GameEngine.FROST_TRAP_DMG, r74_f_foe.health, r74_f_foe.rooted])
	# ⚠️ `end_turn()` 走的是**半回合**（self ⇄ opp 交替）。下面凡是「等某个状态在
	# 敌方回合开始生效」的断言，都统一用这个helper 步进到**敌方回合**再断言 ——
	# 直接 `end_turn()` 一次很可能落到我方回合，reset_units 刷的是另一方，断言必假。
	_check_to_opp_turn(r74_f)
	check(r74_f_foe.rooted == 2 and r74_f_foe.moved,
			"R74 冰霜场地：下个回合开始禁足生效（rooted=%d / moved=%s）"
			% [r74_f_foe.rooted, str(r74_f_foe.moved)])
	# 禁足中仍可攻击（rooted 只锁移动，攻击不受影响）
	r74_f.attack(Vector2i(4, 1), Vector2i(4, 0), GameEngine.SIDE_OPPONENT)
	check(r74_f_pal.health == 22,
			"R74 冰霜场地：禁足中仍可攻击（树人 30 → %d）" % r74_f_pal.health)
	r74_f.end_turn()   # → 我方回合：禁足生效回合结束解除
	check(r74_f_foe.rooted == 0,
			"R74 冰霜场地：生效回合结束解除禁足（rooted=%d）" % r74_f_foe.rooted)

	# 冻结场地：3 伤 + 冰冻
	var r74_z := _new_engine([], 30, 30)
	var r74_z_foe: Placement = r74_z.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_z.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.FREEZE_TRAP_ID).to_dict()))
	r74_z.play_from_hand(0, Vector2i(4, 1))
	r74_z.current_side = GameEngine.SIDE_OPPONENT
	r74_z.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_z_foe.health == 55 - GameEngine.FREEZE_TRAP_DMG and r74_z_foe.frozen,
		"R74 冻结场地：移动进入 → %d 伤 + 冰封（55 → %d、frozen=%s）"
			% [GameEngine.FREEZE_TRAP_DMG, r74_z_foe.health, str(r74_z_foe.frozen)])
	r74_z.end_turn()
	r74_z.end_turn()
	check(r74_z_foe.tapped and not r74_z_foe.frozen,
			"R74 冻结场地：下个回合开始 → 横置不能行动，冰封解除（tapped=%s）"
			% str(r74_z_foe.tapped))

	# 剧毒场地：中毒 —— 每跳 6 伤、持续 3 回合，当场不掉血
	var r74_p := _new_engine([], 30, 30)
	var r74_p_foe: Placement = r74_p.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_p.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.POISON_TRAP_ID).to_dict()))
	r74_p.play_from_hand(0, Vector2i(4, 1))
	r74_p.current_side = GameEngine.SIDE_OPPONENT
	r74_p.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_p_foe.poison_left == GameEngine.POISON_TURNS
			and r74_p_foe.poison_dmg == GameEngine.POISON_DMG
			and r74_p_foe.health == 55,
		"R74 剧毒场地：移动进入 → 中毒 %d 层（每跳 %d，当场不掉血）"
			% [r74_p_foe.poison_left, r74_p_foe.poison_dmg])
	# 毒在**受害者所属方**（敌方）的回合开始跳一格。探针实测：移动后
	# end_turn#1 → 我方、#2 → 敌方（跳第 1 次）、#4 → 敌方（跳第 2 次）。
	_check_to_opp_turn(r74_p)
	check(r74_p_foe.health == 55 - GameEngine.POISON_DMG
			and r74_p_foe.poison_left == GameEngine.POISON_TURNS - 1,
			"R74 剧毒场地：敌方回合开始第1跳 %d 伤（55 → %d，剩 %d 跳）"
			% [GameEngine.POISON_DMG, r74_p_foe.health, r74_p_foe.poison_left])
	_check_to_opp_turn(r74_p)
	check(r74_p_foe.health == 55 - GameEngine.POISON_DMG * 2,
			"R74 剧毒场地：第 2 跳累计 %d 伤（55 → %d）"
			% [GameEngine.POISON_DMG * 2, r74_p_foe.health])
	# 穿刺场地：纯直伤 14
	var r74_pr := _new_engine([], 30, 30)
	var r74_pr_foe: Placement = r74_pr.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_pr.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.PIERCE_TRAP_ID).to_dict()))
	r74_pr.play_from_hand(0, Vector2i(4, 1))
	r74_pr.current_side = GameEngine.SIDE_OPPONENT
	r74_pr.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_pr_foe.health == 55 - GameEngine.PIERCE_TRAP_DMG,
		"R74 穿刺场地：移动进入 → 纯直伤 %d（55 → %d）"
			% [GameEngine.PIERCE_TRAP_DMG, r74_pr_foe.health])

	# ---- 场地**不能被攻击**（新语义的核心之一）----
	var r74_natk := _new_engine([], 30, 30)
	r74_natk.state.hand.append(CardData.from_dict(r74_expl.to_dict()))
	r74_natk.play_from_hand(0, Vector2i(4, 1))
	var r74_atk: Placement = r74_natk.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	# 该格没有任何可攻击目标（场地不是单位 → 不在 attack_targets 里）
	check(not r74_natk.attack_targets(Vector2i(4, 1), GameEngine.SIDE_OPPONENT,
			r74_atk.card).has(Vector2i(4, 1)),
		"R74 场地**不能被攻击**：攻击不到该格（场地不在 attack_targets 里）")
	check(r74_natk.state.field_at(Vector2i(4, 1)) != null and r74_atk.health == 55,
		"R74 场地：站在场地上方的敌人**挨不到打**（场地仍完好、敌人无伤）")

	# ---- 场地精通 9105：加成吃「场地原本费用」 ----
	var r74_m1 := _new_engine([], 30, 30)
	var r74_m1_foe: Placement = r74_m1.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 80, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_m1.state.energy = 9
	r74_m1.state.hand.append(CardData.from_dict(r74_mas.to_dict()))
	r74_m1.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.POISON_TRAP_ID).to_dict()))
	r74_m1.use_effect(0)
	check(r74_m1.state.effects.size() == 1 and r74_m1.state.energy == 7,
		"R74 场地精通：2 费效果卡正常启用（能量 9 → %d）" % r74_m1.state.energy)
	r74_m1.play_from_hand(0, Vector2i(4, 1))
	r74_m1.current_side = GameEngine.SIDE_OPPONENT
	r74_m1.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_m1_foe.poison_dmg == GameEngine.POISON_DMG + 2 * 2,
		"R74 场地精通：剧毒场地每跳 %d+2×2=%d（实际 %d）"
			% [GameEngine.POISON_DMG, GameEngine.POISON_DMG + 4, r74_m1_foe.poison_dmg])
	_check_to_opp_turn(r74_m1)
	check(r74_m1_foe.health == 80 - (GameEngine.POISON_DMG + 4),
			"R74 场地精通：毒跳 %d 伤（80 → %d）"
			% [GameEngine.POISON_DMG + 4, r74_m1_foe.health])
	# 冰霜场地 4+2×1=6
	var r74_m3 := _new_engine([], 30, 30)
	var r74_m3_foe: Placement = r74_m3.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 80, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_m3.state.energy = 9
	r74_m3.state.hand.append(CardData.from_dict(r74_mas.to_dict()))
	r74_m3.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.FROST_TRAP_ID).to_dict()))
	r74_m3.use_effect(0)
	r74_m3.play_from_hand(0, Vector2i(4, 1))
	r74_m3.current_side = GameEngine.SIDE_OPPONENT
	r74_m3.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_m3_foe.health == 80 - (GameEngine.FROST_TRAP_DMG + 2)
			and r74_m3_foe.rooted == 1,
		"R74 场地精通：冰霜场地 %d+2×1=%d 伤 + 禁足（80 → %d）"
			% [GameEngine.FROST_TRAP_DMG, GameEngine.FROST_TRAP_DMG + 2, r74_m3_foe.health])
	# 爆炸场地 18+2×3=24（不分敌我）
	var r74_m2 := _new_engine([], 30, 30)
	var r74_m2_foe: Placement = r74_m2.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 80, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var r74_m2_pal: Placement = r74_m2.state.place(_card(8003, "树人", "盟友", 2, 2, 10, 1, 1),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	r74_m2.state.energy = 9
	r74_m2.state.hand.append(CardData.from_dict(r74_mas.to_dict()))
	r74_m2.state.hand.append(CardData.from_dict(r74_expl.to_dict()))
	r74_m2.use_effect(0)
	r74_m2.play_from_hand(0, Vector2i(4, 1))
	r74_m2.current_side = GameEngine.SIDE_OPPONENT
	r74_m2.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_m2_foe.health == 80 - (GameEngine.TRAP_DMG + 6) and r74_m2_pal.health <= 0,
		"R74 场地精通：爆炸场地十字 %d+2×3=%d（亡灵领主 80 → %d，旁边的树人被炸死）"
			% [GameEngine.TRAP_DMG, GameEngine.TRAP_DMG + 6, r74_m2_foe.health])

	# ---- 技能打场地：**不触发**（场地不是单位，技能打不到；即便打到也不触发）----
	var r74_s := _new_engine([], 30, 30)
	var r74_s_foe: Placement = r74_s.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_s.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.FROST_TRAP_ID).to_dict()))
	r74_s.play_from_hand(0, Vector2i(4, 1))
	r74_s.current_side = GameEngine.SIDE_OPPONENT
	r74_s.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r74_s_foe.health == 55 - GameEngine.FROST_TRAP_DMG,
		"R74 场地：触发只认「移动进入」，与用什么手段打过来无关")

	# ---- 双重场地 9108：标记格子 → 场地触发后同格追加一个随机场地 ----
	# ⚠️ 必须先设 player_class：连锁是按**场地原主人**的角色奖励卡池取候选的，
	# 角色不对（森林精魄）的话池里没有场地卡 → 连锁补不上（实测报"（无）"）。
	RunState.player_class = PlayerClass.ROGUE
	var r74_tw := _new_engine([], 30, 30)
	var r74_tw_foe: Placement = r74_tw.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_tw.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.PIERCE_TRAP_ID).to_dict()))
	r74_tw.play_from_hand(0, Vector2i(4, 1))
	# 给该格挂连锁标记（用引擎真实入口）
	var r74_tw_res: String = r74_tw._double_field_spell(GameEngine.SIDE_SELF,
		Vector2i(4, 1))
	check(r74_tw.state.field_chains.has(Vector2i(4, 1))
			and not r74_tw_res.contains("需要指定"),
		"R74 双重场地：给已有场地的格子挂上连锁标记（%s）" % r74_tw_res)
	# 触发 → 旧场地消失，新场地立刻补上
	r74_tw.current_side = GameEngine.SIDE_OPPONENT
	r74_tw.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	var r74_tw_after: CardData = r74_tw.state.field_at(Vector2i(4, 1))
	check(r74_tw_after != null and r74_tw_after.is_field()
			and not r74_tw.state.field_chains.has(Vector2i(4, 1)),
		"R74 双重场地：原场地触发后同格补上**新的随机场地**（%s），连锁标记只用一次"
			% (r74_tw_after.card_name if r74_tw_after != null else "无"))
	# 没场地效果的格子不能挂连锁
	check(r74_tw._double_field_spell(GameEngine.SIDE_SELF,
			Vector2i(5, 0)).contains("需要指定"),
		"R74 双重场地：对**没有场地效果**的格子使用被拒绝")
	# 场地与单位可同格共存（两套数据互不影响）
	var r74_co := _new_engine([], 30, 30)
	r74_co.state.place(_card(8003, "树人", "盟友", 2, 2, 10, 1, 1), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	r74_co.state.set_field(CardData.from_dict(r74_expl.to_dict()), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(r74_co.state.unit_at(Vector2i(4, 1)) != null
			and r74_co.state.field_at(Vector2i(4, 1)) != null,
		"R74 场地可与单位**同格共存**（board 与 field_effects 是两套独立数据）")

	# ---- 场地专属事件（界面据此演特效）----
	var r74_ev := _new_engine([], 30, 30)
	r74_ev.state.hand.append(CardData.from_dict(r74_expl.to_dict()))
	var r74_got := {"place": 0, "trig": 0}
	r74_ev.action.connect(func(what: String, _d: Variant) -> void:
			if what == "field_place":
				r74_got["place"] = int(r74_got["place"]) + 1
			elif what == "field_trigger":
				r74_got["trig"] = int(r74_got["trig"]) + 1)
	r74_ev.play_from_hand(0, Vector2i(4, 1))     # 监听要接在放置**之前**，否则数不到
	r74_ev.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1), Vector2i(3, 1),
			GameEngine.SIDE_OPPONENT)
	r74_ev.current_side = GameEngine.SIDE_OPPONENT
	r74_ev.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(int(r74_got["place"]) == 1 and int(r74_got["trig"]) == 1,
			"R74 场地事件：field_place ×%d / field_trigger ×%d（各 1 次，界面同源判据）"
			% [int(r74_got["place"]), int(r74_got["trig"])])

	# 场地**不可被技能清除**：火焰箭打在场地所在格 → 打不到任何东西，场地原样还在
	# （R74 新语义：旧版「技能击破陷阱不触发」的场景已不存在 —— 场地不是单位，技能够不到它）
	var r74_skill := _new_engine([], 30, 30)
	var r74_skill_foe := r74_skill.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 55, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r74_skill.state.hand.append(CardData.from_dict(repo.get_card(
			GameEngine.FROST_TRAP_ID).to_dict()))
	r74_skill.play_from_hand(0, Vector2i(4, 1))
	r74_skill.remote_spell(CardData.from_dict(repo.get_card(9003).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 火焰箭 17 伤打场地所在格
	check(r74_skill.state.field_at(Vector2i(4, 1)) != null
			and r74_skill_foe.health == 55 and r74_skill_foe.rooted == 0
			and not r74_skill_foe.frozen and r74_skill_foe.poison_left == 0,
			"R74 场地不可被技能清除：火焰箭打在那格无效（场地仍在、敌人无伤、无任何附加状态）")

	# ---- R52：紧急埋伏（9106）/ 陷阱工坊（8015）/ 暗影狩猎（9107）—— 暗影刺客 2026-10-03 ----
	RunState.player_class = PlayerClass.ROGUE   # 陷阱工坊供牌按角色过滤奖励池
	var r52_ws_c := CardData.from_dict(repo.get_card(8015).to_dict())
	var r52_ht_c := CardData.from_dict(repo.get_card(9107).to_dict())
	for r52_id in [9106, 8015, 9107]:
		var r52_in_rg := false
		var r52_in_dr := false
		for c in repo.reward_pool_for("暗影刺客"):
			if c.id == r52_id:
				r52_in_rg = true
		for c in repo.reward_pool_for("森林精魄"):
			if c.id == r52_id:
				r52_in_dr = true
		check(r52_in_rg and not r52_in_dr,
				"R52 卡 %d：进暗影刺客奖励池，森林精魄池里没有" % r52_id)
	# R74 起口径已是「场地」，R77 把卡面注解也同步过来（原来还写着「工事」，与引擎不符）。
	check("触发过场地" in repo.get_card(9107).effect_text
			and "移动进入某个场地" in repo.get_card(9107).effect_text,
			"R77 暗影狩猎卡面注解已改成场地口径（触发 = 移动进入某场地并发动其效果）")

	# 紧急埋伏：2 个敌人但卡组只有 1 张工事 → 1 张进手；下一张工事 -1 费（显示=判定=实扣）
	var r52_a := _new_engine([], 30, 30)
	r52_a.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 50, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r52_a.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 50, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
	# R74：原来这里用的是 8011 爆炸陷阱（当时是工事）→ 它现在是**场地卡**，
	# R76：8017「巨物捕获」也改成场地卡「巨物陷阱」，这里换用另一张真工事（8023 黑暗祭坛 3 费）验通路。
	r52_a.state.deck.append(CardData.from_dict(repo.get_card(8023).to_dict()))   # 黑暗祭坛 3 费工事
	r52_a.state.deck.append(CardData.from_dict(repo.get_card(8003).to_dict()))   # 非工事 → 取不到
	r52_a.state.deck.append(CardData.from_dict(repo.get_card(8011).to_dict()))   # 场地卡 → 也取不到
	r52_a.state.hand.append(CardData.from_dict(repo.get_card(9106).to_dict()))
	r52_a.state.energy = 9
	r52_a.use_spell(0)
	check(r52_a.state.hand.size() == 1 and r52_a.state.hand[0].is_fort()
			and r52_a.state.hand[0].id == 8023
			and r52_a.state.fort_discount_self == 1,
			"R74 紧急埋伏：只取**工事**（黑暗祭坛进手；场地卡/非工事都取不到），下一张工事 -1 层")
	var r52_a_fort: CardData = r52_a.state.hand[0]
	check(r52_a.cost_of(r52_a_fort) == 2,
			"紧急埋伏：工事费用 3-1=%d（显示 = 判定 = 实扣同走 cost_of）"
			% r52_a.cost_of(r52_a_fort))
	r52_a.play_from_hand(0, Vector2i(4, 1))
	check(r52_a.state.fort_discount_self == 0,
			"紧急埋伏：打出工事 → 消费 -1 层（后续工事恢复原价）")

	# 紧急埋伏：场上没有敌人 → 工事不进手，但「下一张工事 -1」照常生效
	var r52_b := _new_engine([], 30, 30)
	r52_b.state.deck.append(CardData.from_dict(repo.get_card(8011).to_dict()))
	r52_b.state.hand.append(CardData.from_dict(repo.get_card(9106).to_dict()))
	r52_b.use_spell(0)
	check(r52_b.state.hand.is_empty() and r52_b.state.fort_discount_self == 1,
			"紧急埋伏：场上没有敌人 → 工事不进手，但「下一张工事 -1」照常生效")

	# 机关工坊（8015，R76 供给口径由「工事」改为「场地」）：我方回合开始 →
	# 随机一张本角色奖励池的**场地卡**进手。
	var r52_w := _new_engine([], 30, 30)
	r52_w.state.place(r52_ws_c, Vector2i(4, 1), GameEngine.SIDE_SELF)
	r52_w.end_turn()   # → 对方回合
	r52_w.end_turn()   # → 我方回合开始：工坊供牌
	check(r52_w.state.hand.size() == 1 and r52_w.state.hand[0].is_field()
			and r52_w.state.hand[0].card_class == "暗影刺客",
			"R76 机关工坊：回合开始随机一张**场地卡**进手（来自本角色奖励池，实际 %s）"
			% r52_w.state.hand[0].card_name)

	# 陷阱工坊被攻击破坏 → 攻击者反受 8 伤 + 记「触发过工事」；没打死不触发
	# （真实流程：敌人回合攻击工事 → 我方下个回合打暗影狩猎才翻倍）
	var r52_k := _new_engine([], 30, 30)
	r52_k.state.place(CardData.from_dict(repo.get_card(8015).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r52_k_foe := r52_k.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r52_k.end_turn()   # → 对方回合（敌人在自己的回合攻击工事）
	r52_k.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r52_k.state.unit_at(Vector2i(4, 1)).health == 2 and r52_k_foe.health == 60,
			"陷阱工坊：被打但没破坏 → 不触发反伤（10 血 → 2，攻击者仍 60）")
	r52_k_foe.tapped = false
	r52_k.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r52_k.state.unit_at(Vector2i(4, 1)) == null and r52_k_foe.health == 52
			and r52_k_foe.trap_trig_turn == r52_k.turn_total,
			"陷阱工坊：被攻击破坏 → 攻击者反受 8 伤（60 → %d）并记「触发过工事」"
			% r52_k_foe.health)

	# 暗影狩猎：触发当回合 → 12；下个我方回合（触发算「上回合」）→ 24
	r52_k.state.hand.append(r52_ht_c)
	r52_k.state.energy = 9
	r52_k.use_spell(_find(r52_k.state.hand, 9107), Vector2i(3, 1))
	check(r52_k_foe.health == 40,
			"暗影狩猎：触发当回合 → 仍是 12 伤（52 → %d）" % r52_k_foe.health)
	r52_k.end_turn()   # → 我方回合（触发已算「上回合」）
	r52_k.state.hand.append(r52_ht_c)
	r52_k.state.energy = 9
	r52_k.use_spell(_find(r52_k.state.hand, 9107), Vector2i(3, 1))
	check(r52_k_foe.health == 16,
			"暗影狩猎：目标上回合触发过工事 → 24 伤（40 → %d）" % r52_k_foe.health)

	# 暗影狩猎：只能指定敌人
	var r52_t := _new_engine([], 30, 30)
	var r52_t_pal := r52_t.state.place(_card(8003, "树人", "盟友", 2, 2, 30, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r52_t.state.hand.append(CardData.from_dict(repo.get_card(9107).to_dict()))
	var r52_t_res := r52_t.use_spell(0, Vector2i(4, 1))
	check(r52_t_res.contains("只能指定敌人") and r52_t_pal.health == 30,
			"暗影狩猎：只能指定敌人（对友军施放被拒绝）")

	# 技能击破陷阱工坊 → 不触发反伤、不记触发（只认普通攻击）
	var r52_s := _new_engine([], 30, 30)
	r52_s.state.place(CardData.from_dict(repo.get_card(8015).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r52_s_foe := r52_s.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r52_s.remote_spell(CardData.from_dict(repo.get_card(9003).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 火焰箭 17 伤打死工坊
	check(r52_s.state.unit_at(Vector2i(4, 1)) == null and r52_s_foe.health == 60
			and r52_s_foe.trap_trig_turn < 0,
			"陷阱工坊：技能击破不触发 —— 攻击者无伤、未记触发")

	# 陷阱精通：工坊反伤 8+2×3=14（12 攻一击打穿 10 血）
	var r52_m := _new_engine([], 30, 30)
	r52_m.state.energy = 9
	r52_m.state.hand.append(CardData.from_dict(repo.get_card(9105).to_dict()))
	r52_m.use_effect(0)
	r52_m.state.place(CardData.from_dict(repo.get_card(8015).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r52_m_foe := r52_m.state.place(_card(1051, "亡灵领主", "盟友", 8, 12, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r52_m.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r52_m.state.unit_at(Vector2i(4, 1)) == null and r52_m_foe.health == 46,
			"陷阱精通：工坊反伤 8+2×3=14（60 → %d）" % r52_m_foe.health)

	# ---- R53：陷阱系收尾 —— 穿刺陷阱 8016（工事）+ 双重陷阱 9108（技能）----

	# 卡面
	var r53_pierce := repo.get_card(8016)
	var r53_double := repo.get_card(9108)
	check(r53_pierce.card_name == "穿刺陷阱" and r53_pierce.cost == 2
			and r53_pierce.kind == "场地" and r53_pierce.is_field() and not r53_pierce.is_fort()
			and r53_pierce.power == 0 and r53_pierce.health == 0
			and r53_pierce.rarity == 0 and r53_pierce.card_class == "暗影刺客"
			and r53_pierce.traits.has(GameEngine.PIERCE_TRAP_TRAIT),
			"R74 穿刺场地 8016：2 费普通暗影刺客**场地卡**（不再是工事、无 HP）、带「穿刺陷阱」词条")
	check(r53_double.card_name == "双重场地" and r53_double.cost == 2
			and r53_double.kind == "技能" and r53_double.rarity == 0
			and r53_double.card_class == "暗影刺客" and r53_double.target_mode == "unit",
			"R74 双重场地 9108：2 费普通暗影刺客技能，需要指定目标（场地所在格）")
	check(repo.get_card(9105).effect_text.contains("2X") and repo.get_card(9105).target_mode == "none",
			"场地精通 9105：卡面文案补全（含 2X 加成说明）")
	var r53_pool_ids := {}
	for c: CardData in repo.reward_pool_for(PlayerClass.ROGUE):
		r53_pool_ids[c.id] = true
	check(r53_pool_ids.has(8016) and r53_pool_ids.has(9108),
			"R53：穿刺陷阱 / 双重陷阱 都在暗影刺客奖励池")

	# 穿刺场地（R74：8016 已从工事改成场地）：敌人**移动进入** → 吃 14 伤，无附加状态
	var r53_p := _new_engine([], 30, 30)
	r53_p.state.set_field(CardData.from_dict(repo.get_card(8016).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r53_p_foe := r53_p.state.place(_card(1051, "亡灵领主", "盟友", 8, 5, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r53_p.current_side = GameEngine.SIDE_OPPONENT
	r53_p.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r53_p_foe.health == 60 - GameEngine.PIERCE_TRAP_DMG
			and r53_p_foe.rooted == 0 and not r53_p_foe.frozen and r53_p_foe.poison_left == 0
			and r53_p.state.field_at(Vector2i(4, 1)) == null,
			"R74 穿刺场地：移动进入 → 吃 %d 伤且无附加状态（60 → %d），场地消失"
			% [GameEngine.PIERCE_TRAP_DMG, r53_p_foe.health])
	check(r53_p_foe.trap_trig_turn == r53_p.turn_total,
			"R74 穿刺场地：这次触发记全局半回合号（暗影狩猎可判 24 伤）")

	# 穿刺场地 + 场地精通：14 + 2×2 = 18
	var r53_pm := _new_engine([], 30, 30)
	r53_pm.state.energy = 9
	r53_pm.state.hand.append(CardData.from_dict(repo.get_card(9105).to_dict()))
	r53_pm.use_effect(0)
	r53_pm.state.set_field(CardData.from_dict(repo.get_card(8016).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r53_pm_foe := r53_pm.state.place(_card(1051, "亡灵领主", "盟友", 8, 5, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r53_pm.current_side = GameEngine.SIDE_OPPONENT
	r53_pm.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r53_pm_foe.health == 60 - (GameEngine.PIERCE_TRAP_DMG + 4),
			"R74 场地精通：穿刺场地 %d+2×2=%d（60 → %d）"
			% [GameEngine.PIERCE_TRAP_DMG, GameEngine.PIERCE_TRAP_DMG + 4, r53_pm_foe.health])

	# 场地**不能被打**：站在场地上不会被「隔空打到」，只能移动进去才触发
	var r53_p0 := _new_engine([], 30, 30)
	r53_p0.state.set_field(CardData.from_dict(repo.get_card(8016).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r53_p0_foe := r53_p0.state.place(_card(1051, "亡灵领主", "盟友", 8, 0, 60, 1, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	r53_p0.current_side = GameEngine.SIDE_OPPONENT
	check(not r53_p0.attack_targets(Vector2i(3, 1), GameEngine.SIDE_OPPONENT,
			_card(9001, "鸭子骑士", "盟友", 6, 5, 30, 1, 2)).has(Vector2i(4, 1)),
		"R74 场地不是攻击目标：技能/攻击都够不到「场地所在的那一格」")
	check(r53_p0_foe.health == 60 and r53_p0.state.field_at(Vector2i(4, 1)) != null,
		"R74 场地：站在上面既不掉血、场地也不触发（没「移动」这个动作）")

	# ---- 双重场地 9108（R74 由「双重陷阱」改名，标记挂在**格子**上）----
	RunState.player_class = PlayerClass.ROGUE

	# 对**没有场地效果**的格子使用 → 被拒绝
	var r53_d1 := _new_engine([], 30, 30)
	r53_d1.state.energy = 9
	r53_d1.state.hand.append(CardData.from_dict(repo.get_card(9108).to_dict()))
	r53_d1.state.place(_card(8003, "树人", "盟友", 2, 2, 30, 1, 1),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	var r53_d1_res := r53_d1.use_spell(0, Vector2i(4, 2))
	check(r53_d1_res.contains("需要指定") and r53_d1.state.field_chains.is_empty(),
			"R74 双重场地：对没有场地效果的格子施放被拒绝（%s）" % r53_d1_res)

	# 己方场地 → 挂上连锁标记
	var r53_t := _new_engine([], 30, 30)
	r53_t.state.energy = 9
	r53_t.state.hand.append(CardData.from_dict(repo.get_card(9108).to_dict()))
	r53_t.state.set_field(CardData.from_dict(repo.get_card(8012).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)   # 冰霜场地
	var r53_t_res := r53_t.use_spell(0, Vector2i(4, 1))
	check(r53_t.state.field_chains.has(Vector2i(4, 1))
			and not r53_t_res.contains("需要指定"),
		"R74 双重场地：给己方场地挂上连锁标记（%s）" % r53_t_res)

	# 场地触发后 → **同格**补上一个新的随机场地，且连锁标记只用一次
	var r53_t_foe := r53_t.state.place(_card(1051, "亡灵领主", "盟友", 8, 5, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r53_t.current_side = GameEngine.SIDE_OPPONENT
	r53_t.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	var r53_t_new: CardData = r53_t.state.field_at(Vector2i(4, 1))
	check(r53_t_new != null and r53_t_new.is_field()
			and r53_t.state.field_chains.is_empty(),
		"R74 双重场地：原场地触发后同格补上新场地「%s」，连锁标记一次性用掉"
			% (r53_t_new.card_name if r53_t_new != null else "无"))
	check(r53_t.state.field_at(Vector2i(4, 1)) != repo.get_card(r53_t_new.id),
			"R74 双重场地：新场地是卡库实例的副本（改它不污染卡库）")
	# 回归：补上的场地**归属仍是原主人**（我方场地被敌方踩了，不该改姓）
	# （这条盯的是真bug：field_owner 曾被 clear_field 提前擦掉，导致连锁按
	#  「踩上去那个人的阵营」取候选 —— 敌方踩我方场地会替敌方抽场地卡。）
	check(str(r53_t.state.field_owner.get(Vector2i(4, 1), "")) == GameEngine.SIDE_SELF,
			"R74 双重场地：补上的场地归属仍是**原主人**（%s）"
			% str(r53_t.state.field_owner.get(Vector2i(4, 1), "")))
	check(r53_t_foe.health == 60 - GameEngine.FROST_TRAP_DMG,
			"R74 双重场地：被连锁的是冰霜场地 → 踩上去的那个敌人吃 %d 伤（60 → %d）"
			% [GameEngine.FROST_TRAP_DMG, r53_t_foe.health])

	# 连锁补上的新场地**也会被下一个走进来的敌人触发**（连锁不是一次性摆设）
	# 第二个敌人放在新场地**正下方**的 (5,1)；但 (4,1) 上还站着第一个敌人（它踩完没走），
	# 所以先把它挪开，否则路径被挡、`move` 直接失败（`move_path` 返回空）。
	_check_to_opp_turn(r53_t)
	r53_t.current_side = GameEngine.SIDE_OPPONENT
	r53_t.state.reset_units(GameEngine.SIDE_OPPONENT)
	r53_t.state.move_unit(Vector2i(4, 1), Vector2i(1, 1))   # 第一个敌人让位
	r53_t.state.place(_card(1051, "亡灵领主2", "盟友", 8, 5, 60, 1, 1),
			Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
	var r53_t2_foe: Placement = r53_t.state.unit_at(Vector2i(5, 1))
	r53_t.move(Vector2i(5, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	# R76：这里**不能**断言「血 < 60」—— 双重场地补的是**随机**场地卡，
	# 而候选池里有「冻结陷阱」这类**只施加冰封、不掉血**的场地（8013），
	# 摇到它时血量本来就不变（那不是 bug，是这张场地本来的效果）。
	# 所以判据改成「场地一定消失 + 该格归位给踩进来的单位」—— 与摇到哪张无关。
	check(r53_t.state.field_at(Vector2i(4, 1)) == null
			and r53_t.state.unit_at(Vector2i(4, 1)) == r53_t2_foe,
			"R74 双重场地：补上的新场地也会正常触发并消失（第二个敌人踩完，场地已清空；"
			+ "血量 %d 取决于摇到哪张场地 —— 冻结类不掉血属正常）"
			% r53_t2_foe.health)

	# ---- R54：活体栅栏（8018）/ 警觉（9109）----
	# 8017 R54 起是「巨物捕获」工事，**R76 改成场地卡「巨物陷阱」**（见下面的 R76 块）。

	var r54_fence_c := repo.get_card(GameEngine.LIVING_FENCE_ID)
	var r54_alert := repo.get_card(GameEngine.ALERT_ID)
	check(r54_fence_c.is_fort() and r54_fence_c.cost == 2 and r54_fence_c.power == 2
			and r54_fence_c.health == 8 and r54_fence_c.attack_range == 1
			and r54_fence_c.rarity == 1 and r54_fence_c.card_class == PlayerClass.DRUID
			and r54_fence_c.traits.has(GameEngine.FENCE_TRAIT),
			"R54：活体栅栏 2 费稀有工事 2/8/1（森林精魄，属【栅栏】类可叠栅栏）")
	check(r54_alert.is_spell() and r54_alert.cost == 2 and r54_alert.rarity == 1
			and r54_alert.card_class == PlayerClass.ROGUE and not r54_alert.needs_target(),
			"R54：警觉 2 费稀有技能（不指定目标）")
	check(repo.reward_pool_for(PlayerClass.ROGUE).has(r54_alert)
			and repo.reward_pool_for(PlayerClass.DRUID).has(r54_fence_c)
			and not repo.reward_pool_for(PlayerClass.ROGUE).has(r54_fence_c),
			"R54：两张新卡各归本角色奖励池（互不串卡）")

	RunState.player_class = PlayerClass.ROGUE


	# 活体栅栏：射程 1 可攻击（2 攻 / 8 血）
	var r54_f := _new_engine([], 30, 30)
	var r54_f_fence := r54_f.state.place(CardData.from_dict(repo.get_card(8018).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r54_f.state.place(_card(1051, "亡灵领主", "盟友", 8, 3, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	var r54_f_t := r54_f.attack_targets(Vector2i(4, 1), GameEngine.SIDE_SELF, r54_f_fence.card)
	check(not r54_f_t.is_empty() and r54_f_fence.health == 8
			and r54_f.is_fence_card(r54_f_fence.card),
			"活体栅栏：射程 1 可攻击、带【栅栏】词条（未攻击时 8 血）")

	# 警觉：第 1 回合必定抽到
	var r54_g := _new_engine([
		CardData.from_dict(repo.get_card(9109).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict()),
		CardData.from_dict(repo.get_card(9003).to_dict()),
	], 30, 30)
	r54_g.start_game(0)
	check(_find(r54_g.state.hand, 9109) >= 0,
			"警觉：第 1 回合抽的 5 张必定含它（手牌 %d 张）" % r54_g.state.hand.size())

	# 警觉：使用时随机工事进手 + 那张卡**本回合内**费用 -2（R60：不再是永久减费）
	var r54_h := _new_engine([], 30, 30)
	r54_h.state.energy = 9
	r54_h.state.hand.append(CardData.from_dict(repo.get_card(9109).to_dict()))
	var r54_h_res := r54_h.use_spell(0)
	check(r54_h.state.hand.size() == 1 and r54_h_res.contains("警觉"),
			"警觉：随机一张场地卡加入手卡")
	var r54_h_new: CardData = r54_h.state.hand[0]
	# R77：警觉供给口径由「工事」改成「场地」。
	check(r54_h_new.is_field() and r54_h_new.card_class == PlayerClass.ROGUE
			and int(r54_h.state.turn_card_discount.get(r54_h_new, 0)) == 2
			and int(r54_h.state.card_discount.get(r54_h_new, 0)) == 0
			and r54_h.cost_of(r54_h_new) == maxi(0, r54_h_new.cost - 2),
			"R77 警觉：**场地卡**来自本角色奖励池且本回合费用 -2（%s：%d → %d）"
			% [r54_h_new.card_name, r54_h_new.cost, r54_h.cost_of(r54_h_new)])
	# R60：用后警觉自身消失（不进弃牌区）
	var r60_alert_in_discard := false
	for d in r54_h.state.discard:
		if int(d.id) == GameEngine.ALERT_ID:
			r60_alert_in_discard = true
	check(not r60_alert_in_discard,
			"警觉：使用后消失（不进弃牌区）")
	# R60：减费只在本回合有效——回合结束后恢复原价
	var r54_h_after := r54_h_new.cost
	r54_h.end_turn()
	r54_h.end_turn()
	check(int(r54_h.state.turn_card_discount.get(r54_h_new, 0)) == 0
			and r54_h.cost_of(r54_h_new) == r54_h_after,
			"警觉：减费不跨回合（回合结束后 %d → %d）"
			% [r54_h_new.cost, r54_h.cost_of(r54_h_new)])

	# 警觉：手牌已满 → 工事无法加入
	var r54_i := _new_engine([], 30, 30)
	for i in FieldState.HAND_LIMIT:
		r54_i.state.hand.append(_card(7900 + i, "垫手卡%d" % i, "技能", 0, 0, 0))
	var r54_i_res := r54_i._alertness(GameEngine.SIDE_SELF)
	check(r54_i_res.contains("手牌已满") and r54_i.state.hand.size() == FieldState.HAND_LIMIT,
			"警觉：手牌已满 → 不加入工事")


	# ================= R60（2026-10-03）：使魔之力 9115 =================
	# 鸭子巫师（9008）本来就会回合开始召唤使魔鸭子（9009）；新效果卡 9115
	# 让场上带「使魔」trait 的单位**每回合开始力量 +1**（永久，无上限），
	# 挂在**敌方效果区**（关卡 enemy_effects），只给使魔、不给全部友方。
	var r60_fam := repo.get_card(9115)
	check(r60_fam != null and r60_fam.card_name == "使魔之力" and r60_fam.kind == "效果"
			and r60_fam.rarity == 4 and r60_fam.group == "enemy"
			and r60_fam.is_level_effect()
			and r60_fam.traits.has(GameEngine.FAMILIAR_GROW_TRAIT)
			and r60_fam.value == 1,
			"R60 使魔之力 9115：敌方关卡效果卡，每回合开始使魔力量 +1")
	# 使魔鸭子 9009 必须带「使魔」trait，否则成长判定会漏掉它
	var r60_duck := repo.get_card(9009)
	check(r60_duck != null and r60_duck.traits.has(GameEngine.FAMILIAR_TRAIT),
			"R60 使魔鸭子 9009：traits 含「使魔」，供 9115 成长判定")
	# 成长结算：敌方回合开始 → 使魔 +1，其它单位不动
	var r60_e := _new_engine([], 30, 30)
	r60_e.enable_enemy_effects([CardData.from_dict(r60_fam.to_dict())])
	var r60_f1 := r60_e.state.place(CardData.from_dict(r60_duck.to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	var r60_other := r60_e.state.place(
			_card(1051, "亡灵领主", "盟友", 6, 6, 40, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r60_e.end_turn()          # → 敌方回合开始
	r60_e.end_turn()          # → 回合结束（敌方行动）
	r60_e.end_turn()          # → 我方回合结束 → 敌方回合开始（成长结算点）
	check(r60_f1.atk_buff >= 1,
			"R60 使魔之力：敌方回合开始使魔鸭子力量 +1（atk_buff=%d，力量 %d）"
			% [r60_f1.atk_buff, r60_f1.effective_power()])
	check(r60_other.atk_buff == 0,
			"R60 使魔之力：只给「使魔」，非使魔单位不加（atk_buff=%d）" % r60_other.atk_buff)
	# 累计：再过一个敌方回合又+1（永久、无上限）
	var r60_before := r60_f1.atk_buff
	r60_e.end_turn()
	r60_e.end_turn()
	r60_e.end_turn()
	check(r60_f1.atk_buff == r60_before + 1,
			"R60 使魔之力：每回合持续累计（%d → %d）" % [r60_before, r60_f1.atk_buff])
	# 没挂效果卡 → 不成长
	var r60_none := _new_engine([], 30, 30)
	var r60_n1 := r60_none.state.place(CardData.from_dict(r60_duck.to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	r60_none.end_turn()
	r60_none.end_turn()
	r60_none.end_turn()
	check(r60_n1.atk_buff == 0,
			"R60 使魔之力：没挂效果卡 → 不成长（atk_buff=%d）" % r60_n1.atk_buff)
	# 两个巫师关卡都挂了 9115
	var r60_lv := 0
	for lv in GameLevels.builtin_levels():
		for eid in (lv.get("enemy_effects", []) as Array):
			if int(eid) == 9115:
				r60_lv += 1
				# 关卡里必须真的有鸭子巫师（否则这张效果卡没意义）
				var r60_has_wizard := false
				for u in (lv.get("enemy_units", []) as Array):
					if int(u[0]) == GameEngine.WIZARD_DUCK_ID:
						r60_has_wizard = true
				check(r60_has_wizard, "R60 使魔之力 9115 挂在「%s」→ 该关卡确实有鸭子巫师"
						% str(lv.get("name", "?")))
	check(r60_lv == 2, "R60 使魔之力 9115 挂在 2 个巫师关卡（实际 %d）" % r60_lv)

	# ================= R55（2026-10-03）：地狱猫 8019 / 鲜血堡垒 8020 / 活力转移 9110 =================
	# 三张卡共用一个结算入口 _end_turn_surplus()：读**自己回合结束时的剩余费用**。
	# 卡面数据：地狱猫 0 费普通盟友 1/1（+1力+2生/点）；鲜血堡垒 0 费稀有工事 1/1 程1（+1力+3生/点）；
	#          活力转移 2 费史诗效果（剩余费用每 2 点 → 下回合开始 +1 费用，效果区多张不叠加）。
	var r55_cat := repo.get_card(8019)
	var r55_fort := repo.get_card(8020)
	var r55_vit := repo.get_card(9110)
	check(r55_cat != null and r55_cat.card_name == "地狱猫" and r55_cat.kind == "盟友"
			and r55_cat.cost == 0 and r55_cat.power == 1 and r55_cat.health == 1
			and r55_cat.attack_range == 1 and r55_cat.move_speed == 1
			and r55_cat.rarity == 0 and r55_cat.card_class == PlayerClass.ROGUE,
			"R55 地狱猫 8019：0 费普通暗影刺客盟友 1/1 程1 速1")
	check(r55_fort != null and r55_fort.card_name == "鲜血堡垒" and r55_fort.kind == "工事"
			and r55_fort.is_fort() and r55_fort.cost == 0 and r55_fort.power == 0
			and r55_fort.health == 1 and r55_fort.attack_range == 1
			and r55_fort.rarity == 1 and r55_fort.card_class == PlayerClass.ROGUE,
			"R55 鲜血堡垒 8020：0 费稀有暗影刺客工事 0/1 程1（R56 起初始力量 0）")
	check(r55_vit != null and r55_vit.card_name == "活力转移" and r55_vit.kind == "效果"
			and r55_vit.cost == 2 and r55_vit.rarity == 2
			and r55_vit.traits.has(GameEngine.VITALITY_TRAIT)
			and r55_vit.card_class == PlayerClass.ROGUE,
			"R55 活力转移 9110：2 费史诗暗影刺客效果卡")

	# 地狱猫 / 鲜血堡垒：剩余费用 3 → +3 力 +6 生 / +3 力 +9 生（永久，不随回合结束清除）
	var r55_a := _new_engine([], 30, 30)
	var r55_cat_p := r55_a.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	var r55_fort_p := r55_a.state.place(CardData.from_dict(r55_fort.to_dict()),
			Vector2i(5, 1), GameEngine.SIDE_SELF)
	r55_a.state.energy = 3
	r55_a._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_cat_p.end_atk == 3 and r55_cat_p.health == 1 + 3 * 2
			and r55_cat_p.effective_power() == 4,
			"地狱猫：剩余 3 点 → 力量 1→4、生命 1→7（实际 力%d 生%d）"
			% [r55_cat_p.effective_power(), r55_cat_p.health])
	check(r55_fort_p.end_atk == 3 and r55_fort_p.health == 1 + 3 * 3
			and r55_fort_p.effective_power() == 3,
			"鲜血堡垒：剩余 3 点 → 力量 0→3、生命 1→10（实际 力%d 生%d）"
			% [r55_fort_p.effective_power(), r55_fort_p.health])

	# 成长是**永久**的：第二次结算继续累加，回合结束不清零
	r55_a.state.energy = 2
	r55_a._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_cat_p.end_atk == 5 and r55_cat_p.effective_power() == 6
			and r55_cat_p.health == 1 + 5 * 2,
			"地狱猫：成长累加不清零（再 +2 → 力量 6、生命 11）")
	r55_a.state.energy = 0
	r55_a.state.reset_units(GameEngine.SIDE_SELF)
	check(r55_cat_p.end_atk == 5 and r55_cat_p.effective_power() == 6,
			"地狱猫：reset_units 不会清掉回合结束成长（仍为 5）")

	# 剩余费用 0 → 完全不结算
	var r55_b := _new_engine([], 30, 30)
	var r55_bp := r55_b.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r55_b.state.energy = 0
	r55_b._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_bp.end_atk == 0 and r55_bp.health == 1, "剩余费用 0 → 不成长")

	# 敌方单位不受益（只结算自己那一方）
	var r55_c := _new_engine([], 30, 30)
	var r55_foe := r55_c.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	r55_c.state.opp_energy = 4
	r55_c._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_foe.end_atk == 0, "敌方回合结束不结算我方单位（各自只算自己）")

	# 活力转移：剩余 3 点 → 结转 1（3/2 向下取整），下个回合开始时发放
	var r55_d := _new_engine([], 30, 30)
	r55_d.state.effects.append(CardData.from_dict(r55_vit.to_dict()))
	r55_d.state.energy = 3
	r55_d._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_d.state.self_next_energy == 1,
			"活力转移：剩余 3 → 结转 1 点（3/2 向下取整，实际 %d）"
			% r55_d.state.self_next_energy)
	r55_d.current_side = GameEngine.SIDE_SELF
	r55_d.state.energy = 0
	r55_d._begin_turn(GameEngine.SIDE_SELF)
	check(r55_d.state.energy == FieldState.ENERGY_PER_TURN + 1
			and r55_d.state.self_next_energy == 0,
			"活力转移：下回合开始费用 5+1=6 且结转池清零（实际 %d）"
			% r55_d.state.energy)
	r55_d._begin_turn(GameEngine.SIDE_SELF)
	check(r55_d.state.energy == FieldState.ENERGY_PER_TURN,
			"活力转移：只发一次，下回合回到 5（实际 %d）" % r55_d.state.energy)

	# 活力转移：剩余 1 点不足 2 → 不结转
	var r55_e := _new_engine([], 30, 30)
	r55_e.state.effects.append(CardData.from_dict(r55_vit.to_dict()))
	r55_e.state.energy = 1
	r55_e._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_e.state.self_next_energy == 0, "活力转移：剩余 1 点不足 2 → 不结转")

	# 活力转移：效果区多张**不叠加**
	var r55_f := _new_engine([], 30, 30)
	for i in 2:
		r55_f.state.effects.append(CardData.from_dict(r55_vit.to_dict()))
	r55_f.state.energy = 4
	r55_f._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r55_f.state.self_next_energy == 2,
			"活力转移：效果区 2 张仍只结转 1 层（4/2=2，不是 4）")

	# 走真实路径：end_turn() 在能量清零前结算
	var r55_g := _new_engine([], 30, 30)
	var r55_gp := r55_g.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r55_g.state.effects.append(CardData.from_dict(r55_vit.to_dict()))
	r55_g.current_side = GameEngine.SIDE_SELF
	r55_g.state.energy = 4
	r55_g.end_turn()
	check(r55_gp.end_atk == 4 and r55_g.state.self_next_energy == 2,
			"end_turn 真实路径：能量清零前先结算（成长 +4、结转 2）")
	check(r55_g.state.energy == 0 and r55_g.current_side == GameEngine.SIDE_OPPONENT,
			"end_turn 之后：我方能量已清零并切到敌方回合（%d / %s）"
			% [r55_g.state.energy, r55_g.current_side])

	# 角色介绍改为概括性文案（R55）：不再出现具体卡名 / 数值，但保留打法取向
	var r55_dr_desc := PlayerClass.desc_of(PlayerClass.DRUID)
	var r55_rg_desc := PlayerClass.desc_of(PlayerClass.ROGUE)
	check(r55_dr_desc != "" and r55_rg_desc != ""
			and not r55_dr_desc.contains("熊") and not r55_dr_desc.contains("树人")
			and not r55_rg_desc.contains("幽影") and not r55_rg_desc.contains("终结")
			and not r55_dr_desc.contains("4 费") and not r55_rg_desc.contains("3 费"),
			"角色介绍：概括性描述，不再罗列具体卡牌与数值")
	# R94：机械之心介绍原本写着「素体在手里越攒越多」，但实现是**每场战斗固定 2 张**
	# （MECH_CORE_PROTO，由 apply_battle_start_relics 发放）且跨战斗不累积 —— 文案与实现对不上。
	# 这里锁两条不变量：① 文案不许再承诺累积；② 素体只能来自「机械核心」，
	# 不许被塞进初始卡组或奖励池（否则玩家真能攒起来，文案又变成对的了，判定互相打架）。
	var r94_mech_desc := PlayerClass.desc_of(PlayerClass.MECH)
	check(r94_mech_desc != ""
			and not r94_mech_desc.contains("越攒越多")
			and not r94_mech_desc.contains("越来越多")
			and r94_mech_desc.contains("%d 张" % GameEngine.MECH_CORE_PROTO),
			"R94 机械之心介绍：写明每场战斗 %d 张素体，不承诺「越攒越多」（实际不跨战斗累积）"
			% GameEngine.MECH_CORE_PROTO)
	var r94_repo := CardRepo.load_json()
	var r94_proto_in_pool: Array[CardData] = r94_repo.reward_pool_for(PlayerClass.MECH).filter(
			func(c: CardData): return c.id == GameEngine.PROTO_ID)
	check(not PlayerClass.start_deck_ids(PlayerClass.MECH).has(GameEngine.PROTO_ID)
			and r94_proto_in_pool.is_empty()
			and r94_repo.get_card(GameEngine.PROTO_ID).rarity == 3,
			"R94 素体只来自「机械核心」：不在初始卡组、不在奖励池、rarity=3（也抽不到）")
	var r55_relic := RelicRepo.load_json().get_relic(PlayerClass.relic_of(PlayerClass.DRUID))
	check(r55_relic != null and r55_relic.relic_name == "荒野形态"
			and not r55_relic.desc.is_empty(),
			"初始道具：赠品 6022 有可展示的效果文案（供角色卡面显示）")

	# ================= R56（2026-10-03）：暗影之刃 9111 / 黑暗领主 8021 / 暗影锁链 9112 =================
	var r56_blade := repo.get_card(9111)
	var r56_lord := repo.get_card(8021)
	var r56_chain := repo.get_card(9112)
	check(r56_blade != null and r56_blade.card_name == "暗影之刃"
			and r56_blade.kind == "效果" and r56_blade.cost == 2 and r56_blade.rarity == 1
			and r56_blade.traits.has(GameEngine.DARK_BLADE_TRAIT)
			and r56_blade.card_class == PlayerClass.ROGUE,
			"R56 暗影之刃 9111：2 费稀有暗影刺客效果卡")
	check(r56_lord != null and r56_lord.card_name == "黑暗领主"
			and r56_lord.kind == "盟友" and r56_lord.cost == 4 and r56_lord.power == 5
			and r56_lord.health == 10 and r56_lord.attack_range == 1
			and r56_lord.move_speed == 1 and r56_lord.rarity == 2
			and r56_lord.traits.has(GameEngine.DARK_LORD_TRAIT)
			and r56_lord.card_class == PlayerClass.ROGUE,
			"R56 黑暗领主 8021：4 费史诗暗影刺客随从 5/10 程1 速1")
	check(r56_chain != null and r56_chain.card_name == "暗影锁链"
			and r56_chain.kind == "效果" and r56_chain.cost == 1
			and r56_chain.rarity == 1
			and r56_chain.traits.has(GameEngine.DARK_CHAIN_TRAIT)
			and r56_chain.card_class == PlayerClass.ROGUE,
			"R56 暗影锁链 9112：1 费稀有暗影刺客效果卡")
	check(r55_fort.power == 0, "R56 改值：鲜血堡垒 8020 初始面板 1 力 → 0 力")

	# 黑暗领主：回合结束时自己 +5 费用，且**优先结算**（先加，再算剩余费用类效果）
	var r56_a := _new_engine([], 30, 30)
	r56_a.state.place(CardData.from_dict(r56_lord.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r56_a.state.energy = 1
	r56_a._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_a.state.energy == 1 + GameEngine.DARK_LORD_ENERGY,
			"黑暗领主：回合结束费用 +%d（1 → %d）"
			% [GameEngine.DARK_LORD_ENERGY, r56_a.state.energy])

	# 优先结算的含义：黑暗领主给的 5 点会被地狱猫一起读到（剩 1 + 5 = 6 → +6 力 +12 生）
	r56_a.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	var r56_cat_p: Placement = r56_a.state.unit_at(Vector2i(4, 2))
	r56_a.state.energy = 1
	r56_a._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_cat_p.end_atk == 6 and r56_cat_p.effective_power() == 7,
			"黑暗领主优先结算：地狱猫读到 1+5=6 点（力量 1 → %d）"
			% r56_cat_p.effective_power())

	# 场上几个黑暗领主就加几点（可叠加）
	var r56_b := _new_engine([], 30, 30)
	r56_b.state.place(CardData.from_dict(r56_lord.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r56_b.state.place(CardData.from_dict(r56_lord.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r56_b.state.energy = 0
	r56_b._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_b.state.energy == 2 * GameEngine.DARK_LORD_ENERGY,
			"黑暗领主：两个各 +%d（合计 %d）"
			% [GameEngine.DARK_LORD_ENERGY, r56_b.state.energy])

	# 敌方回合不结算我方黑暗领主
	var r56_c := _new_engine([], 30, 30)
	r56_c.state.place(CardData.from_dict(r56_lord.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r56_c.state.energy = 3
	r56_c._end_turn_surplus(GameEngine.SIDE_OPPONENT)
	check(r56_c.state.energy == 3, "敌方回合结束不加我方黑暗领主的费用")

	# 暗影之刃：X = 本回合**已花掉**的费用（不是剩余费用）
	var r56_d := _new_engine([], 30, 30)
	r56_d.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe := r56_d.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_d.state.energy = 5
	r56_d.state.pay_energy(4, GameEngine.SIDE_SELF)   # 花掉 4，剩 1
	r56_d._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe.health == 30 - 4,
			"暗影之刃：已花 4 费 → 随机敌人受 4 伤（30 → %d）" % r56_foe.health)

	# 钱刚好花光（剩余 0）时暗影之刃**仍然结算** —— 这是它最常见的触发场景
	var r56_e := _new_engine([], 30, 30)
	r56_e.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe2 := r56_e.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_e.state.energy = 5
	r56_e.state.pay_energy(5, GameEngine.SIDE_SELF)   # 全部花光
	r56_e._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe2.health == 25,
			"暗影之刃：剩余费用 0 也不被跳过（已花 5 → 30 → %d）" % r56_foe2.health)

	# 没花过费用 → 效果落空，不造成伤害
	var r56_f := _new_engine([], 30, 30)
	r56_f.state.effects.append(CardData.from_dict(r56_blade.to_dict()))
	var r56_foe3 := r56_f.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r56_f.state.energy = 5
	r56_f._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_foe3.health == 30, "暗影之刃：本回合没花钱 → 落空（敌人 30 血不变）")

	# 已花费每回合重新记（_begin_turn 清零）
	var r56_g := _new_engine([], 30, 30)
	r56_g.state.pay_energy(3, GameEngine.SIDE_SELF)
	check(r56_g.state.energy_spent_of(GameEngine.SIDE_SELF) == 3,
			"已花费记账：pay_energy 累加（3）")
	r56_g.current_side = GameEngine.SIDE_SELF
	r56_g._begin_turn(GameEngine.SIDE_SELF)
	check(r56_g.state.energy_spent_of(GameEngine.SIDE_SELF) == 0,
			"已花费记账：回合开始清零")

	# 暗影锁链：剩余 7 点 → 7/3 = 2 次击退，每次 2 格（敌人被往自己后场推）
	var r56_h := _new_engine([], 30, 30)
	r56_h.state.effects.append(CardData.from_dict(r56_chain.to_dict()))
	r56_h.rng.seed = 20261003
	var r56_kb1 := r56_h.state.place(_card(1051, "亡灵领主A", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	r56_h.state.energy = 7
	r56_h._end_turn_surplus(GameEngine.SIDE_SELF)
	var r56_cell := Vector2i(-1, -1)
	for cell: Vector2i in r56_h.state.board:
		if r56_h.state.unit_at(cell) == r56_kb1:
			r56_cell = cell
	# (2,2) 往行 0 方向退：2 次 × 2 格 = 4 格，但边界只到 (0,2) → 至少退了 2 格
	check(r56_cell.x <= 0, "暗影锁链：剩余 7 → 2 次击退，敌人从 (2,2) 退到 (%d,%d)"
			% [r56_cell.x, r56_cell.y])

	# 剩余不足 3 点 → 不触发
	var r56_i := _new_engine([], 30, 30)
	r56_i.state.effects.append(CardData.from_dict(r56_chain.to_dict()))
	var r56_kb2 := r56_i.state.place(_card(1051, "亡灵领主B", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	r56_i.state.energy = 2
	r56_i._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r56_i.state.unit_at(Vector2i(2, 2)) == r56_kb2,
			"暗影锁链：剩余 2 点不足 3 → 不击退（仍在 (2,2)）")

	# 走真实路径 end_turn()：黑暗领主 +5 优先，其余读加完后的剩余费用
	var r56_j := _new_engine([], 30, 30)
	r56_j.state.place(CardData.from_dict(r56_lord.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r56_jcat := r56_j.state.place(CardData.from_dict(r55_cat.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r56_j.state.effects.append(CardData.from_dict(r55_vit.to_dict()))
	r56_j.current_side = GameEngine.SIDE_SELF
	r56_j.state.energy = 1
	r56_j.end_turn()
	check(r56_jcat.end_atk == 6 and r56_j.state.self_next_energy == 3,
			"end_turn 真实路径：黑暗领主 +5 优先 → 地狱猫 +6、活力转移结转 3"
			+ "（实际 +%d / %d）" % [r56_jcat.end_atk, r56_j.state.self_next_energy])
	check(r56_j.state.energy == 0, "end_turn 之后能量仍按规矩清零（%d）" % r56_j.state.energy)

	# ================= R57（2026-10-03）：黑暗扩散 9113 / 地狱咏唱者 8022 / 黑暗祭坛 8023 / 无尽黑暗 9114 =================
	var r57_spread := repo.get_card(9113)
	var r57_chanter := repo.get_card(8022)
	var r57_altar := repo.get_card(8023)
	var r57_endless := repo.get_card(9114)
	check(r57_spread != null and r57_spread.card_name == "黑暗扩散"
			and r57_spread.kind == "效果" and r57_spread.cost == 1 and r57_spread.rarity == 2
			and r57_spread.traits.has(GameEngine.DARK_SPREAD_TRAIT)
			and r57_spread.card_class == PlayerClass.ROGUE,
			"R57 黑暗扩散 9113：1 费史诗暗影刺客效果卡")
	check(r57_chanter != null and r57_chanter.card_name == "地狱咏唱者"
			and r57_chanter.kind == "盟友" and r57_chanter.cost == 3
			and r57_chanter.power == 1 and r57_chanter.health == 11
			and r57_chanter.attack_range == 2 and r57_chanter.move_speed == 1
			and r57_chanter.rarity == 0
			and r57_chanter.traits.has(GameEngine.CHANTER_TRAIT),
			"R57 地狱咏唱者 8022：3 费普通暗影刺客盟友 1/11 程2 速1")
	check(r57_altar != null and r57_altar.card_name == "黑暗祭坛"
			and r57_altar.kind == "工事" and r57_altar.is_fort() and r57_altar.cost == 3
			and r57_altar.power == 1 and r57_altar.health == 15
			and r57_altar.attack_range == 1 and r57_altar.rarity == 0
			and r57_altar.traits.has(GameEngine.ALTAR_TRAIT),
			"R57 黑暗祭坛 8023：3 费普通暗影刺客工事 1/15 程1")
	check(r57_endless != null and r57_endless.card_name == "无尽黑暗"
			and r57_endless.kind == "效果" and r57_endless.cost == 1
			and r57_endless.rarity == 1
			and r57_endless.traits.has(GameEngine.ENDLESS_DARK_TRAIT),
			"R57 无尽黑暗 9114：1 费稀有暗影刺客效果卡")

	# 地狱咏唱者：攻击时 +1 费用（attack() 尾部触发）
	var r57_a := _new_engine([], 30, 30)
	var r57_cp := r57_a.state.place(CardData.from_dict(r57_chanter.to_dict()),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	r57_a.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
	r57_a.state.energy = 2
	r57_a.attack(Vector2i(4, 0), Vector2i(3, 0), GameEngine.SIDE_SELF)
	check(r57_a.state.energy == 2 + GameEngine.ATTACK_GAIN_ENERGY,
			"地狱咏唱者：攻击后费用 2 → %d" % r57_a.state.energy)
	check(r57_cp.tapped, "地狱咏唱者：攻击后横置（本回合已行动）")

	# 黑暗祭坛：工事同样能攻击并 +1 费
	var r57_b := _new_engine([], 30, 30)
	r57_b.state.place(CardData.from_dict(r57_altar.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r57_b.state.place(_card(1051, "亡灵领主", "盟友", 8, 8, 30, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r57_b.state.energy = 1
	r57_b.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(r57_b.state.energy == 1 + GameEngine.ATTACK_GAIN_ENERGY,
			"黑暗祭坛：攻击后费用 1 → %d" % r57_b.state.energy)

	# 直击 HP 也算一次「攻击时」（目标格 = 敌方后牌行，射程要够：程2 → 放 (2,1) 打 (0,1)）
	var r57_c := _new_engine([], 30, 30)
	r57_c.state.place(CardData.from_dict(r57_chanter.to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	r57_c.state.energy = 0
	r57_c.attack_hp(Vector2i(2, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r57_c.state.energy == GameEngine.ATTACK_GAIN_ENERGY
			and r57_c.state.hp_opponent == 29,
			"地狱咏唱者：直击敌方 HP 同样 +%d 费（费用 %d、敌方 HP %d）"
			% [GameEngine.ATTACK_GAIN_ENERGY, r57_c.state.energy, r57_c.state.hp_opponent])

	# 非法攻击（被拒绝）不触发
	var r57_d := _new_engine([], 30, 30)
	r57_d.state.place(CardData.from_dict(r57_chanter.to_dict()),
			Vector2i(4, 0), GameEngine.SIDE_SELF)
	r57_d.state.energy = 3
	r57_d.attack(Vector2i(4, 0), Vector2i(0, 0), GameEngine.SIDE_SELF)   # 够不着
	check(r57_d.state.energy == 3, "地狱咏唱者：攻击被拒绝（距离不够）→ 不加费用")

	# 黑暗扩散：剩余 3 点 → 全体敌人各 6 伤
	var r57_e := _new_engine([], 30, 30)
	r57_e.state.effects.append(CardData.from_dict(r57_spread.to_dict()))
	var r57_f1 := r57_e.state.place(_card(1051, "亡灵领主A", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	var r57_f2 := r57_e.state.place(_card(1051, "亡灵领主B", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r57_e.state.energy = 3
	r57_e._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r57_f1.health == 30 - 3 * GameEngine.DARK_SPREAD_PER_ENERGY
			and r57_f2.health == 30 - 3 * GameEngine.DARK_SPREAD_PER_ENERGY,
			"黑暗扩散：剩余 3 → 全体敌人各 -%d（A %d / B %d）"
			% [3 * GameEngine.DARK_SPREAD_PER_ENERGY, r57_f1.health, r57_f2.health])

	# 剩余 0 → 不结算（每 1 点费用换 2 伤，0 点换 0 伤）
	var r57_f := _new_engine([], 30, 30)
	r57_f.state.effects.append(CardData.from_dict(r57_spread.to_dict()))
	var r57_f3 := r57_f.state.place(_card(1051, "亡灵领主C", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	r57_f.state.energy = 0
	r57_f._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r57_f3.health == 30, "黑暗扩散：剩余 0 → 不造成伤害")

	# 场上没有敌人 → 落空、不误伤
	var r57_g := _new_engine([], 30, 30)
	r57_g.state.effects.append(CardData.from_dict(r57_spread.to_dict()))
	r57_g.state.energy = 4
	r57_g._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r57_g.state.hp_opponent == 30, "黑暗扩散：没有敌人 → 落空（敌方 HP 不变）")

	# 效果区多张不叠加
	var r57_h := _new_engine([], 30, 30)
	for i in 2:
		r57_h.state.effects.append(CardData.from_dict(r57_spread.to_dict()))
	var r57_f4 := r57_h.state.place(_card(1051, "亡灵领主D", "盟友", 8, 8, 30, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
	r57_h.state.energy = 2
	r57_h._end_turn_surplus(GameEngine.SIDE_SELF)
	check(r57_f4.health == 30 - 2 * GameEngine.DARK_SPREAD_PER_ENERGY,
			"黑暗扩散：效果区 2 张仍只算一层（敌人 %d 血）" % r57_f4.health)

	# ---- R70：无尽黑暗改为「玩家强制选 1 张手牌弃掉」（不再是随机弃）----
	# 抽牌之后弹面板 → 玩家点一张 → 才弃掉并给费用。**不能不选**，手牌为空则不弃也不给费。
	var r70_i := _new_engine([], 30, 30)
	r70_i.state.effects.append(CardData.from_dict(r57_endless.to_dict()))
	r70_i.state.deck = [
		_card(7901, "弃牌A", "技能", 0, 0, 0), _card(7902, "弃牌B", "技能", 0, 0, 0),
		_card(7903, "弃牌C", "技能", 0, 0, 0), _card(7904, "弃牌D", "技能", 0, 0, 0),
		_card(7905, "弃牌E", "技能", 0, 0, 0), _card(7906, "弃牌F", "技能", 0, 0, 0)]
	r70_i.current_side = GameEngine.SIDE_SELF
	r70_i.state.energy = 0
	r70_i._begin_turn(GameEngine.SIDE_SELF)
	check(r70_i.endless_pending
			and r70_i.state.hand.size() == FieldState.HAND_DRAW_PER_TURN
			and r70_i.state.discard.is_empty(),
			"R70 无尽黑暗：抽 %d 张后**弹面板等玩家选**，此刻还没弃（手牌 %d、弃牌区 %d）"
			% [FieldState.HAND_DRAW_PER_TURN, r70_i.state.hand.size(),
				r70_i.state.discard.size()])
	check(r70_i.state.energy == FieldState.ENERGY_PER_TURN,
			"R70 无尽黑暗：**选之前不给费用**（当前 %d，应还是 %d）"
			% [r70_i.state.energy, FieldState.ENERGY_PER_TURN])
	check(r70_i.endless_options().size() == FieldState.HAND_DRAW_PER_TURN,
			"R70 无尽黑暗：面板列出全部 %d 张手牌供选（实际 %d 张）"
			% [FieldState.HAND_DRAW_PER_TURN, r70_i.endless_options().size()])
	# 玩家点第 2 张（弃牌B）→ 真的弃掉 + 拿到费用 + 面板关闭
	var r70_pick_name := str(r70_i.state.hand[1].card_name)
	var r70_discard_before := r70_i.state.deck.size()
	check(r70_i.endless_pick(1),
			"R70 无尽黑暗：endless_pick(1) 成功（选中 %s）" % r70_pick_name)
	check(not r70_i.endless_pending
			and r70_i.state.discard.size() == GameEngine.ENDLESS_DARK_DISCARD
			and r70_i.state.discard[0].card_name == r70_pick_name,
			"R70 无尽黑暗：弃掉的正是玩家选的那张（%s），且面板已关闭"
			% r70_pick_name)
	check(r70_i.state.energy == FieldState.ENERGY_PER_TURN + GameEngine.ENDLESS_DARK_ENERGY,
			"R70 无尽黑暗：选完之后费用 5 +%d = %d"
			% [GameEngine.ENDLESS_DARK_ENERGY, r70_i.state.energy])
	check(r70_i.state.deck.size() == r70_discard_before,
			"R70 无尽黑暗：弃的是本回合抽到的（牌库剩 %d 张）" % r70_i.state.deck.size())
	# 不能重复选 / 越界选
	check(not r70_i.endless_pick(0) and not r70_i.endless_pick(99),
			"R70 无尽黑暗：面板关闭后 / 下标越界都选不动（不会重复弃牌或白拿费用）")

	# 手牌为空 → 本回合不弃也不给费用（不白拿 2 费）
	var r70_j := _new_engine([], 30, 30)
	r70_j.state.effects.append(CardData.from_dict(r57_endless.to_dict()))
	r70_j.current_side = GameEngine.SIDE_SELF
	r70_j.state.energy = 0
	r70_j._endless_dark(GameEngine.SIDE_SELF)
	check(not r70_j.endless_pending and r70_j.state.energy == 0
			and r70_j.state.hand.is_empty(),
			"R70 无尽黑暗：手牌为空 → 不弹面板、不弃牌、**也不给费用**（当前 %d）"
			% r70_j.state.energy)

	# 效果区多张不叠加（仍是选 1 张 / +2 不是 +4）
	var r70_k := _new_engine([], 30, 30)
	for _i3 in 2:
		r70_k.state.effects.append(CardData.from_dict(r57_endless.to_dict()))
	r70_k.state.hand = [CardData.from_dict(r57_endless.to_dict())]
	r70_k.state.energy = 0
	r70_k._endless_dark(GameEngine.SIDE_SELF)
	check(r70_k.endless_pending
			and r70_k.endless_options().size() == 1
			and r70_k.endless_pick(0)
			and r70_k.state.energy == GameEngine.ENDLESS_DARK_ENERGY,
			"R70 无尽黑暗：效果区 2 张仍只换 %d 点费用（%d），不叠加"
			% [GameEngine.ENDLESS_DARK_ENERGY, r70_k.state.energy])

	# 走真实路径：start_game 第 1 回合就会弹面板；选完才拿到费用
	var r70_l := _new_engine([], 30, 30)
	r70_l.state.effects.append(CardData.from_dict(r57_endless.to_dict()))
	r70_l.state.deck = [
		_card(7911, "测试牌1", "技能", 0, 0, 0), _card(7912, "测试牌2", "技能", 0, 0, 0),
		_card(7913, "测试牌3", "技能", 0, 0, 0), _card(7914, "测试牌4", "技能", 0, 0, 0),
		_card(7915, "测试牌5", "技能", 0, 0, 0), _card(7916, "测试牌6", "技能", 0, 0, 0)]
	r70_l.start_game(0)
	check(r70_l.endless_pending,
			"R70 start_game 真实路径：首回合抽牌后弹出无尽黑暗弃牌面板")
	r70_l.endless_pick(0)
	check(not r70_l.endless_pending
			and r70_l.state.energy == FieldState.ENERGY_PER_TURN + GameEngine.ENDLESS_DARK_ENERGY
			and r70_l.state.hand.size() == FieldState.HAND_DRAW_PER_TURN
				- GameEngine.ENDLESS_DARK_DISCARD,
			"R70 start_game 真实路径：选完 1 张 → 手牌 %d、费用 %d"
			% [r70_l.state.hand.size(), r70_l.state.energy])

	# ---- R70：回响 9102 稀有 → 史诗 ----
	var r70_echo := repo.get_card(9102)
	check(r70_echo != null and r70_echo.rarity == 2
			and r70_echo.rarity_name() == "史诗",
			"R70 回响 9102：rarity 1→2，卡面显示「%s」（原为稀有）"
			% (r70_echo.rarity_name() if r70_echo != null else "?"))

	# ---- R70：恶魔使魔 9117 召唤改为「每 2 回合」（成长仍每回合）----
	# **关键：这张卡是敌方关卡效果，走 enemy_effects → SIDE_OPPONENT 分支。**
	# 第一版只在 SIDE_SELF 判间隔，结果「每 2 回合」对真正的 Boss 关完全没生效
	#（是被一次性 headless 探针实测出来的，回归当时是绿的）。
	# 复制一份再改 traits —— `from_dict` 的 traits 是**共享引用**，直接改会污染卡库。
	var r70_de := CardData.from_dict(repo.get_card(9117).to_dict())
	r70_de.traits = ["使魔成长", "恶魔召唤"]
	# 逐个**半回合**推进，**只在敌方回合**采样。
	# `end_turn()` 走的是**半回合**（self→opp→self…），所以每采到 1 个敌方样本要 2 次 end_turn；
	# 循环上限给足（10 次 = 5 个敌方回合），并且**先判长度再取下标** ——
	# 断言里越界会抛 SCRIPT ERROR，而 `_init` 里抛异常后 `quit()` 不会被调到，
	# SceneTree 会一直空转（表现为测试「挂住」而不是失败）。
	var r70_seq := ""
	var r70_by_opp: Array[int] = []
	var r70_eng := _new_engine([], 30, 30)
	r70_eng.state.enemy_effects.append(CardData.from_dict(r70_de.to_dict()))
	r70_eng.state.hand.clear()
	r70_eng.state.deck.clear()
	r70_eng.start_game(0)
	for _half in 10:
		r70_eng.end_turn()
		if r70_eng.current_side != GameEngine.SIDE_OPPONENT:
			continue
		var r70_c := 0
		for _cc in r70_eng.state.board:
			if r70_eng.state.board[_cc].card.traits.has(GameEngine.FAMILIAR_TRAIT):
				r70_c += 1
		r70_by_opp.append(r70_c)
	r70_seq = "%d,%d,%d,%d,%d" % [r70_by_opp[0], r70_by_opp[1], r70_by_opp[2],
			r70_by_opp[3], r70_by_opp[4]]
	check(GameEngine.DEMON_SUMMON_EVERY == 2
			and r70_by_opp[0] == 0 and r70_by_opp[1] == 1 and r70_by_opp[2] == 1
			and r70_by_opp[3] == 2 and r70_by_opp[4] == 2,
			"R70 恶魔使魔（**敌方侧**）：每 %d 回合召唤一次 → %s"
			% [GameEngine.DEMON_SUMMON_EVERY, r70_seq])
	# 我方侧对称：同一张卡挂到 state.effects 时按我方回合计数
	# 循环 3 次、每次 2 次 end_turn = 正好走到我方第 1/2/3 回合（与我方侧的采样点对齐）。
	var r70_by_self: Array[int] = []
	var r70_eng2 := _new_engine([], 30, 30)
	r70_eng2.state.effects.append(CardData.from_dict(r70_de.to_dict()))
	r70_eng2.state.hand.clear()
	r70_eng2.state.deck.clear()
	r70_eng2.start_game(0)
	for _half2 in 3:
		var r70_c2 := 0
		for _cc2 in r70_eng2.state.board:
			if r70_eng2.state.board[_cc2].card.traits.has(GameEngine.FAMILIAR_TRAIT):
				r70_c2 += 1
		r70_by_self.append(r70_c2)
		r70_eng2.end_turn()
		r70_eng2.end_turn()   # → 下个我方回合
	check(r70_by_self.size() >= 3
			and r70_by_self[0] == 0 and r70_by_self[1] == 1
			and r70_by_self[2] == 1,
			"R70 恶魔使魔（我方侧对称）：我方回合 1..3 的累计使魔数 %d,%d,%d"
			% [r70_by_self[0], r70_by_self[1], r70_by_self[2]])
	# 使魔成长仍是**每回合** +1（与召唤间隔解耦）
	# 注意：成长跟着**效果卡所在的那一方**走（enemy_effects → 敌方单位），
	# 所以鸭子要摆在敌方半场 —— 真实关卡里召唤物也都在敌方那侧。
	var r70_g := _new_engine([], 30, 30)
	var r70_gz := CardData.from_dict(repo.get_card(9117).to_dict())
	r70_gz.traits = ["使魔成长"]   # 只留成长，不召唤
	r70_g.state.enemy_effects.append(r70_gz)
	r70_g.state.hand.clear()
	r70_g.state.deck.clear()
	r70_g.start_game(0)
	var r70_f1 := r70_g.state.place(
			CardData.from_dict(repo.get_card(GameEngine.FAMILIAR_DUCK_ID).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r70_atk0 := r70_f1.effective_power()
	r70_g.end_turn()   # 敌方回合：成长结算一次
	check(r70_f1.effective_power() == r70_atk0 + 1,
			"R70 恶魔使魔：使魔成长**不受召唤间隔影响**，敌方回合仍 +1（%d → %d）"
			% [r70_atk0, r70_f1.effective_power()])

	# ================= R63（2026-10-04）：契约签订者 8024 =================
	# 3 费普通暗影刺客盟友 2/8程1 速1：登场回复 4 点费用 + 本回合手卡全体费用 +4（**涨价**）。
	var r63_ct := repo.get_card(8024)
	check(r63_ct != null and r63_ct.card_name == "契约签订者" and r63_ct.kind == "盟友"
			and r63_ct.cost == 3 and r63_ct.power == 2 and r63_ct.health == 8
			and r63_ct.attack_range == 1 and r63_ct.move_speed == 1
			and r63_ct.rarity == 0 and r63_ct.card_class == PlayerClass.ROGUE
			and r63_ct.traits.has(GameEngine.CONTRACTOR_TRAIT),
			"R63 契约签订者 8024：3 费普通暗影刺客盟友 2/8 程1 速1")
	check(repo.reward_pool_for(PlayerClass.ROGUE).has(r63_ct)
			and not repo.reward_pool_for(PlayerClass.DRUID).has(r63_ct),
			"R63 契约签订者 8024：暗影刺客奖励池专属")

	# 登场：花 3 费 → 净赚 1 费（5 - 3 + 4 = 6），且**它自己不算涨价**（已离手）
	var r63_a := _new_engine([], 30, 30)
	r63_a.state.hand.append(CardData.from_dict(r63_ct.to_dict()))
	var r63_other := _card(7901, "测试牌A", "技能", 2, 0, 0)
	r63_a.state.hand.append(r63_other)
	r63_a.state.energy = FieldState.ENERGY_PER_TURN
	var r63_before:= r63_a.cost_of(r63_other)
	r63_a.play_from_hand(0, Vector2i(3, 1))
	check(r63_a.state.energy == FieldState.ENERGY_PER_TURN - r63_ct.cost
			+ GameEngine.CONTRACTOR_GAIN,
			"契约签订者：花 %d 回 %d → 费用 %d（净赚 1）"
			% [r63_ct.cost, GameEngine.CONTRACTOR_GAIN, r63_a.state.energy])
	check(r63_a.cost_of(r63_other) == r63_before + GameEngine.CONTRACTOR_RAISE,
			"契约签订者：其余手卡费用 %d → %d（+4 涨价）"
			% [r63_before, r63_a.cost_of(r63_other)])
	check(r63_a.state.turn_card_raise == GameEngine.CONTRACTOR_RAISE,
			"契约签订者：涨价记在 turn_card_raise（本回合全体手卡）")

	# 涨价是**全体手卡统一**生效（记在 state 上，不按实例/不按张数累加）
	var r63_b := _new_engine([], 30, 30)
	r63_b.state.hand.append(CardData.from_dict(r63_ct.to_dict()))
	r63_b.state.hand.append(_card(7904, "测试牌B", "技能", 1, 0, 0))
	r63_b.state.hand.append(_card(7905, "测试牌C", "技能", 4, 0, 0))
	r63_b.state.energy = FieldState.ENERGY_PER_TURN
	r63_b.current_side = GameEngine.SIDE_SELF
	r63_b.play_from_hand(0, Vector2i(3, 1))
	var r63_b_hi:= _card(7905, "测试牌C", "技能", 4, 0, 0)
	check(r63_b.cost_of(r63_b_hi) == 4 + GameEngine.CONTRACTOR_RAISE,
			"契约签订者：涨价对手卡里每一张都生效（4 → %d），不按张数累加"
			% r63_b.cost_of(r63_b_hi))
	r63_b.end_turn()
	check(r63_b.state.turn_card_raise == 0,
			"契约签订者：涨价回合结束即失效（turn_card_raise 清零）")
	# 回合结束后费用恢复原价
	var r63_c := _new_engine([], 30, 30)
	r63_c.state.hand.append(CardData.from_dict(r63_ct.to_dict()))
	r63_c.state.energy = FieldState.ENERGY_PER_TURN
	r63_c.current_side = GameEngine.SIDE_SELF
	r63_c.play_from_hand(0, Vector2i(3, 1))
	var r63_keep:= _card(7903, "留手牌", "技能", 1, 0, 0)
	r63_c.state.hand.append(r63_keep)
	r63_c.end_turn()# → 弃手 → 敌方回合 →我方回合
	r63_c.state.hand.append(r63_keep)
	check(r63_c.cost_of(r63_keep) == 1,
			"契约签订者：涨价不跨回合（下一个我方回合恢复 1 费）")

	# ================= R63：恶魔鸭 9116（沉睡 + 受伤反应）=================
	var r63_dd := repo.get_card(9116)
	check(r63_dd != null and r63_dd.card_name == "恶魔鸭" and r63_dd.kind == "盟友"
			and r63_dd.power == 5 and r63_dd.health == 100
			and r63_dd.attack_range == 2 and r63_dd.move_speed == 1
			and r63_dd.rarity == 4 and r63_dd.group == "enemy"
			and r63_dd.traits.has(FieldState.SLEEP_TRAIT),
			"R63 恶魔鸭 9116：敌方怪物 5/100 程2 速1，带「沉睡」trait")

	# **R76 改口径**：沉睡是「挨打计数」不是「回合计数」—— 上场即沉睡 SLEEP_TURNS，
	# 每挨一下 -1、归零**立刻**能行动；回合结束**不再**递减（见 R76-A 的完整链路）。
	var r63_e := _new_engine([], 30, 30)
	var r63_dd_p := r63_e.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r63_dd_p.sleep_left == FieldState.SLEEP_TURNS,
			"恶魔鸭：上场即沉睡 %d（要挨 %d 下才醒，实际 %d）"
			% [FieldState.SLEEP_TURNS, FieldState.SLEEP_TURNS, r63_dd_p.sleep_left])
	# 敌方第 1 个回合：还睡 → reset_units 横置它
	r63_e.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(r63_dd_p.tapped and r63_dd_p.sleep_left == FieldState.SLEEP_TURNS,
			"恶魔鸭：第 1 个回合仍在沉睡（横置、不能行动，sleep_left=%d）"
			% r63_dd_p.sleep_left)
	# 挨第 1 下 → 2 变 1；挨第 2 下 → 1 变 0，**立刻**不再横置
	r63_e.state.place(_card(1051, "打手A", "盟友", 8, 2, 60, 1, 1),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	r63_e.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r63_dd_p.sleep_left == FieldState.SLEEP_TURNS - 1,
			"R76 恶魔鸭：挨第 1 下 → 沉睡 %d（回合不参与递减）" % r63_dd_p.sleep_left)
	var r63_e_hit := r63_e.state.unit_at(Vector2i(1, 1))
	r63_e_hit.tapped = false
	r63_e.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r63_dd_p.sleep_left == 0,
			"R76 恶魔鸭：挨第 2 下 → 沉睡归零（sleep_left=0）")
	r63_e.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(not r63_dd_p.tapped,
			"R76 恶魔鸭：沉睡归零后**立刻**恢复行动（不再横置、无需等回合结束）")

	# 受伤 → 沉睡 -1；挨够次数**立刻**醒来（R76：不是「提前 1 回合」）
	var r63_f := _new_engine([], 30, 30)
	var r63_f_p := r63_f.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r63_f._hit_unit(r63_f_p, 10, "测试")
	check(r63_f_p.sleep_left == FieldState.SLEEP_TURNS - 1
			and r63_f_p.end_atk == 0,
			"R76 恶魔鸭：沉睡中受伤 → 沉睡 -1（sleep_left=%d，不加攻）"
			% r63_f_p.sleep_left)
	r63_f._hit_unit(r63_f_p, 10, "测试")
	check(r63_f_p.sleep_left == 0,
			"R76 恶魔鸭：再受一次伤 → 沉睡归零、立刻醒来（sleep_left=%d）" % r63_f_p.sleep_left)
	# 已醒后再受伤 → 永久 +1 力量（可叠加，不受 GROW_CAP 封顶）
	var r63_f_atk := r63_f_p.effective_power()
	r63_f._hit_unit(r63_f_p, 10, "测试")
	check(r63_f_p.end_atk == GameEngine.DEMON_DUCK_ATK_GAIN
			and r63_f_p.effective_power() == r63_f_atk + 1,
			"恶魔鸭：醒着受伤 → 力量 %d → %d（永久 +1）"
			% [r63_f_atk, r63_f_p.effective_power()])
	for i in 6:
		r63_f._hit_unit(r63_f_p, 10, "测试")
	check(r63_f_p.end_atk == 7 and r63_f_p.effective_power() == 5 + 7,
			"恶魔鸭：连续受伤 → 力量累加到 %d（不受 GROW_CAP=5 封顶）"
			% r63_f_p.effective_power())
	# 打死就不再触发受伤反应（不该在尸体上加攻）
	var r63_f_hp := r63_f_p.health
	r63_f._hit_unit(r63_f_p, r63_f_hp + 5, "测试")
	var r63_f_atk2:= r63_f_p.end_atk
	r63_f._hit_unit(r63_f_p, 5, "测试")
	check(r63_f_p.end_atk == r63_f_atk2,
			"恶魔鸭：被打死后不再触发受伤反应（end_atk 保持 %d）" % r63_f_atk2)

	# 沉睡单位真的动不了：AI 队列里不出现，且 move / attack 都拒
	var r63_g := _new_engine([], 30, 30)
	var r63_g_p := r63_g.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r63_g.current_side = GameEngine.SIDE_OPPONENT
	r63_g.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(not r63_g.ai_action_queue().has(Vector2i(0, 1)),
			"恶魔鸭：沉睡中不进 AI 行动队列（本回合完全不行动）")
	var r63_g_tap := r63_g_p.tapped
	r63_g.move(Vector2i(0, 1), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	check(r63_g.state.unit_at(Vector2i(0, 1)) == r63_g_p and r63_g_p.tapped == r63_g_tap,
			"恶魔鸭：沉睡中不能移动（原地不动）")

	# ---- R72：沉睡的可见特效所需数据（界面判据的同源字段锁）----
	# 沉睡是「还不能动」的隐藏状态，卡面看不出来 → 界面必须能读出「还差几下」。
	# 这条锁的就是 battle_scene._draw_sleep_aura 读的那几个字段：
	# sleep_left（剩余挨打次数）+ card.traits（是不是沉睡单位）。
	# **R76 改口径**：沉睡不再是「每回合 -1」而是「每次受伤 -1」—— 原来 R72 断言的
	# 「每回合递减」已作废（R76 块里有新断言），这里只锁「字段存在 + 初值 = 2」。
	var r72 := _new_engine([], 30, 30)
	var r72_p := r72.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r72_p.card.traits.has(FieldState.SLEEP_TRAIT)
			and r72_p.sleep_left == FieldState.SLEEP_TURNS,
			"R72 沉睡判据：card.traits「沉睡」+ Placement.sleep_left（界面特效唯一数据源）")
	check(FieldState.SLEEP_TURNS == 2,
			"R76 沉睡初值：初始沉睡 %d（挨 %d 下才醒）"
			% [FieldState.SLEEP_TURNS, FieldState.SLEEP_TURNS])
	# R76：_sleep_tick **不再递减**（只播「仍在沉睡」提示）——回合结束不该偷偷减沉睡。
	r72._sleep_tick(GameEngine.SIDE_OPPONENT)
	r72._sleep_tick(GameEngine.SIDE_OPPONENT)
	check(r72_p.sleep_left == FieldState.SLEEP_TURNS,
			"R76 沉睡只算挨打：连过 2 个回合结束 sleep_left 仍是 %d（没被回合偷偷减掉）"
			% r72_p.sleep_left)
	# 沉睡与冰封**可以同时成立**（冰冻术士战吼打中正在沉睡的恶魔鸭）：
	# 所以三个状态徽标（嘲讽/冰封/沉睡）必须能靠行号错开，不能各画各的重叠。
	var r72_b := _new_engine([], 30, 30)
	var r72_bp := r72_b.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r72_b._apply_frozen(r72_bp, "测试")
	check(r72_bp.sleep_left > 0 and r72_bp.frozen,
			"R72 沉睡 + 冰封可同时成立（sleep_left=%d / frozen=%s）→ 界面按徽标行号依次下移"
			% [r72_bp.sleep_left, str(r72_bp.frozen)])
	# 非沉睡单位不该被算进「沉睡中」（_board_has_sleep 的判据）
	var r72_c := _new_engine([], 30, 30)
	var r72_cp := r72_c.state.place(_card(7907, "普通单位", "盟友", 2, 2, 2),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r72_cp.sleep_left == 0,
			"R72 沉睡判据不误伤：没有「沉睡」trait 的单位 sleep_left=0（不会被画沉睡光环）")

	# ================= R76：四项修复 =================

	# ---- R76-A：恶魔鸭沉睡 = 「挨打计数」，不是「回合计数」----
	# 用户口径：初始沉睡 2，每次受伤沉睡 -1，沉睡归零**立刻**能行动。
	# 原来：受伤只「提前 1 回合」（-1 但要等本方回合结束才真醒）+ 每回合结束还自动 -1
	#→ 沉睡 2 会被回合偷偷减掉，玩家挨一下就直接能动了，完全不是这回事。
	var r76_sleep := _new_engine([], 30, 30)
	var r76_sp := r76_sleep.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r76_hero := r76_sleep.state.place(_card(1051, "测试打手", "盟友", 8, 3, 60, 1, 1),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	check(r76_sp.sleep_left == 2,
			"R76-A 恶魔鸭：初始沉睡 2（sleep_left=%d）" % r76_sp.sleep_left)
	# 挨第1 下：沉睡 2 → 1，还不能动
	r76_sleep.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r76_sp.sleep_left == 1 and r76_sp.health == 97,
			"R76-A 挨第 1 下：沉睡 2→1、掉 3 血（100→%d），仍不能动" % r76_sp.health)
	# 挨第 2 下：沉睡 1 → 0，**立刻**恢复行动（不等回合结束）
	r76_hero.tapped = false
	r76_sleep.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r76_sp.sleep_left == 0 and r76_sp.health == 94,
			"R76-A 挨第 2 下：沉睡 1→0 **立刻**能行动（血 100→%d）" % r76_sp.health)
	# 归零之后再挨：走「已醒」分支 = 力量永久 +1（不再动沉睡）
	var r76_pw_before := r76_sp.end_atk
	r76_hero.tapped = false
	r76_sleep.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	check(r76_sp.sleep_left == 0 and r76_sp.end_atk == r76_pw_before + 1,
			"R76-A 醒后再挨：沉睡仍 0、力量永久 +1（end_atk %d→%d）"
			% [r76_pw_before, r76_sp.end_atk])
	# 中间夹一个敌方回合结束：沉睡**不能**被回合减掉（这是本次修复的核心）
	var r76_sleep2 := _new_engine([], 30, 30)
	var r76_sp2 := r76_sleep2.state.place(CardData.from_dict(r63_dd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r76_hero2 := r76_sleep2.state.place(_card(1051, "测试打手", "盟友", 8, 3, 60, 1, 1),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	r76_sleep2.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)
	var r76_mid := r76_sp2.sleep_left
	r76_sleep2.current_side = GameEngine.SIDE_OPPONENT
	r76_sleep2.end_turn()
	check(r76_mid == 1 and r76_sp2.sleep_left == 1,
			"R76-A 关键：挨 1 下后过完整回合，沉睡仍是 1（回合不再递减，%d→%d）"
			% [r76_mid, r76_sp2.sleep_left])

	# ---- R76-B：潜入 9100 必须是两段式（拖到卡上不能自己挑落点）----
	# 原来拖到盟友身上会一路走到 use_spell 的 INFILTRATE 分支，引擎自己挑
	# 「己方半场第一个空格」= 前排左边 → 表现为「卡片自己跑到前排左边」。
	var r76_inf := _new_engine([], 30, 30)
	var r76_ally := r76_inf.state.place(_card(7903, "潜入靶子", "盟友", 2, 5, 1, 1),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r76_inf.state.hand.append(CardData.from_dict(repo.get_card(9100).to_dict()))
	r76_inf.state.energy = 5
	# 玩家侧的 use_spell 入口必须**拒绝**（单段入口没有「目的格」这个信息）
	var r76_refused := r76_inf.use_spell(0, Vector2i(4, 2))
	check(r76_refused.find("先点一个己方盟友") >= 0
			and r76_inf.state.unit_at(Vector2i(4, 2)) == r76_ally
			and r76_inf.state.hand.size() == 1,
			"R76-B 潜入：玩家侧 use_spell 拒绝单段施放（%s）→ 卡还在手上、单位没动"
			% r76_refused)
	# 正规两段入口：选盟友 + 指定空格 = 真的移动过去并 +3 力量
	var r76_moved := r76_inf.cast_infiltrate(0, Vector2i(4, 2), Vector2i(4, 4))
	check(r76_inf.state.unit_at(Vector2i(4, 4)) != null
			and r76_inf.state.unit_at(Vector2i(4, 2)) == null
			and r76_inf.state.hand.is_empty()
			and r76_inf.state.unit_at(Vector2i(4, 4)).atk_buff_turn == GameEngine.INFILTRATE_ATK,
			"R76-B 潜入两段式：%s（落到指定格 (4,4)，力量 +%d）"
			% [r76_moved, GameEngine.INFILTRATE_ATK])

	# ---- R76-C：巨物陷阱 8017 = 场地卡（不再是「被打才反伤」的工事）----
	var r76_mt := repo.get_card(GameEngine.MASS_TRAP_ID)
	check(r76_mt != null and r76_mt.card_name == "巨物陷阱" and r76_mt.is_field()
			and not r76_mt.is_fort() and r76_mt.cost == 2 and r76_mt.health == 0
			and r76_mt.rarity == 1 and r76_mt.card_class == PlayerClass.ROGUE
			and r76_mt.traits.has(GameEngine.MASS_TRAP_TRAIT),
			"R76-C 巨物陷阱 8017：2 费稀有**场地卡**（不再是工事）、生命 0、暗影刺客")
	var r76_c := _new_engine([], 30, 30)
	r76_c.state.set_field(CardData.from_dict(r76_mt.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r76_c_foe := r76_c.state.place(_card(1051, "踩雷的", "盟友", 8, 2, 60, 2, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(r76_c.state.field_at(Vector2i(4, 1)) != null
			and r76_c.state.unit_at(Vector2i(4, 1)) == null,
			"R76-C 场地卡不进 board：只挂在格子上、该格没有单位")
	# 敌人移动进入 → 吃 MASS_TRAP_DMG、场地消失
	r76_c.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r76_c_foe.health == 60 - GameEngine.MASS_TRAP_DMG
			and r76_c.state.field_at(Vector2i(4, 1)) == null
			and r76_c.state.unit_at(Vector2i(4, 1)) == r76_c_foe,
			"R76-C 敌人移动进入 → 吃 %d 伤（60→%d）、场地一次性消失、单位留在格上"
			% [GameEngine.MASS_TRAP_DMG, r76_c_foe.health])
	# 原本就站在该格 → 不触发（场地语义：只有「移动进入」才炸）
	var r76_d := _new_engine([], 30, 30)
	var r76_d_foe := r76_d.state.place(_card(1051, "站雷的", "盟友", 8, 2, 60, 2, 1),
			Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	r76_d.state.set_field(CardData.from_dict(r76_mt.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r76_d._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r76_d_foe.health == 60 and r76_d.state.field_at(Vector2i(4, 1)) != null,
			"R76-C 场地与单位可同格共存、原本站着的敌人**不触发**（血仍 %d）"
			% r76_d_foe.health)
	# 吃场地精通加成（2× 原费 = +4）
	var r76_e := _new_engine([], 30, 30)
	r76_e.state.set_field(CardData.from_dict(r76_mt.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r76_e.state.effects.append(CardData.from_dict(repo.get_card(9105).to_dict()))
	var r76_e_foe := r76_e.state.place(_card(1051, "踩雷的", "盟友", 8, 2, 60, 2, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	r76_e.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
	check(r76_e_foe.health == 60 - GameEngine.MASS_TRAP_DMG - 2 * r76_mt.cost,
			"R76-C 吃场地精通：%d + 2×%d = %d 伤（60→%d）"
			% [GameEngine.MASS_TRAP_DMG, r76_mt.cost,
				GameEngine.MASS_TRAP_DMG + 2 * r76_mt.cost, r76_e_foe.health])
	# 场地卡不能被攻击（不在 board → 打不到）
	var r76_f := _new_engine([], 30, 30)
	r76_f.state.set_field(CardData.from_dict(r76_mt.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r76_f.state.place(_card(1051, "打雷的", "盟友", 8, 3, 60, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	check(r76_f.state.field_at(Vector2i(4, 1)) != null
			and r76_f.attack_targets(Vector2i(3, 1), GameEngine.SIDE_OPPONENT,
					repo.get_card(1051)).has(Vector2i(4, 1)) == false,
			"R76-C 场地卡不是单位：敌方打不到它（场地仍在）")

	# ---- R76-D：机关工坊 8015 供给「场地卡」而不是「工事」----
	var r76_w := repo.get_card(GameEngine.WORKSHOP_ID)
	check(r76_w != null and r76_w.card_name == "机关工坊" and r76_w.is_fort()
			and r76_w.traits.has(GameEngine.WORKSHOP_TRAIT),
			"R76-D 机关工坊 8015：本身**仍是工事**（只是它造的东西改成场地）")
	var r76_g := _new_engine([], 30, 30)
	RunState.player_class = PlayerClass.ROGUE
	r76_g.state.place(CardData.from_dict(r76_w.to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	r76_g.state.hand.clear()
	var r76_field_count := 0
	var r76_fort_count := 0
	for _k in 12:
		r76_g._workshop_supply(GameEngine.SIDE_SELF)
	for r76_hc: CardData in r76_g.state.hand:
		if r76_hc.is_field():
			r76_field_count += 1
		elif r76_hc.is_fort():
			r76_fort_count += 1
	check(r76_g.state.hand.size() > 0 and r76_field_count == r76_g.state.hand.size()
			and r76_fort_count == 0,
			"R76-D 机关工坊供给场地卡：连抽 12 次共 %d 张，其中场地 %d / 工事 %d"
			% [r76_g.state.hand.size(), r76_field_count, r76_fort_count])

	# ================= R63：恶魔使魔 9117 + 恶魔鸭 Boss 关卡 =================
	var r63_ds := repo.get_card(9117)
	check(r63_ds != null and r63_ds.card_name == "恶魔使魔" and r63_ds.is_effect()
			and r63_ds.kind == "效果" and r63_ds.rarity == 4 and r63_ds.group == "enemy"
			and r63_ds.is_level_effect() and r63_ds.value == 1
			and r63_ds.traits.has(GameEngine.FAMILIAR_GROW_TRAIT)
			and r63_ds.traits.has(GameEngine.DEMON_SUMMON_TRAIT),
			"R63 恶魔使魔 9117：敌方关卡效果卡，带「使魔成长」+「恶魔召唤」")

	# 效果区挂上 → 每个回合开始既成长使魔、又按间隔随机召唤使魔鸭子
	# R70：召唤从「每回合」改成「每 DEMON_SUMMON_EVERY 回合」，所以要**连过两个敌方回合**
	# 才看得到召唤（敌方回合 1 不召唤、回合 2 召唤）。
	var r63_h := _new_engine([], 30, 30)
	r63_h.enable_enemy_effects([CardData.from_dict(r63_ds.to_dict())])
	var r63_h_fam := r63_h.state.place(
			CardData.from_dict(repo.get_card(GameEngine.FAMILIAR_DUCK_ID).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r63_h_before := r63_h.state.board.size()
	r63_h.current_side = GameEngine.SIDE_OPPONENT
	r63_h._begin_turn(GameEngine.SIDE_OPPONENT)   # 敌方回合 1
	check(r63_h_fam.atk_buff >= 1,
			"恶魔使魔：回合开始使魔鸭子力量 +1（atk_buff=%d，**成长不受召唤间隔影响**）"
			% r63_h_fam.atk_buff)
	check(r63_h.state.board.size() == r63_h_before,
			"恶魔使魔：敌方回合 1（奇数）**不召唤**（场上 %d → %d）"
			% [r63_h_before, r63_h.state.board.size()])
	r63_h._begin_turn(GameEngine.SIDE_OPPONENT)   # 敌方回合 2
	check(r63_h.state.board.size() == r63_h_before + 1,
			"恶魔使魔：敌方回合 2（偶数）召唤 1 只使魔鸭子（场上 %d → %d）"
			% [r63_h_before, r63_h.state.board.size()])
	# 召唤物必须是使魔鸭子（9009），且落在空格上
	var r63_h_summoned: Placement = null
	for p2: Placement in r63_h.state.board.values():
		if p2.owner == GameEngine.SIDE_OPPONENT and p2.card.id == GameEngine.FAMILIAR_DUCK_ID \
				and p2 != r63_h_fam:
			r63_h_summoned = p2
	check(r63_h_summoned != null
			and r63_h_summoned.card.traits.has(GameEngine.FAMILIAR_TRAIT),
			"恶魔使魔：召唤出来的是使魔鸭子 9009（带「使魔」trait，可被成长）")

	# **玩家后排排除外**：敌方能压到我方半场（除后排），但绝不落我方后排行
	var r63_i := _new_engine([], 30, 30)
	r63_i.enable_enemy_effects([CardData.from_dict(r63_ds.to_dict())])
	var r63_i_back := GameEngine.back_row(GameEngine.SIDE_SELF)
	var r63_i_ok := true
	var r63_i_samples: Array = []
	for t in 60:
		var spot:= r63_i._random_free_board_cell(GameEngine.SIDE_OPPONENT)
		if spot == Vector2i(-1, -1):
			continue
		r63_i_samples.append(str(spot))
		if spot.x == r63_i_back:
			r63_i_ok = false
		if not r63_i.state.board.has(spot):
			r63_i.state.place(_card(7999, "占位", "盟友", 1, 1, 1), spot, GameEngine.SIDE_SELF)
	check(r63_i_ok and r63_i_samples.size() > 0,
			"恶魔使魔：随机空格召唤 %d 次都不落玩家后排行（样例 %s）"
			% [r63_i_samples.size(), str(r63_i_samples.slice(0, 4))])
	# 只占满到「除玩家后排外全满」→ 返回 (-1,-1)
	for r in FieldState.BOARD_ROWS:
		if r == r63_i_back:
			continue
		for col in FieldState.BOARD_COLS:
			if not r63_i.state.board.has(Vector2i(r, col)):
				r63_i.state.place(_card(7999, "占位", "盟友", 1, 1, 1),
						Vector2i(r, col), GameEngine.SIDE_SELF)
	check(r63_i._random_free_board_cell(GameEngine.SIDE_OPPONENT) == Vector2i(-1, -1),
			"恶魔使魔：可用空格用尽 → 返回空位（本回合不召唤），玩家后排永远不被征用")
	# 我方召唤对称：跳过的是**敌方**后排
	var r63_i_b2:= GameEngine.back_row(GameEngine.SIDE_OPPONENT)
	var r63_i_ok2 := true
	for col in 12:
		var sp2:= r63_i._random_free_board_cell(GameEngine.SIDE_SELF)
		if sp2 == Vector2i(-1, -1):
			break
		if sp2.x == r63_i_b2:
			r63_i_ok2 = false
		r63_i.state.place(_card(7998, "占位", "盟友", 1, 1, 1), sp2, GameEngine.SIDE_SELF)
	check(r63_i_ok2, "恶魔使魔：我方召唤同样跳过敌方后排行（对称保留）")

	# 效果区没挂这张卡 → 既不成长也不召唤
	var r63_j := _new_engine([], 30, 30)
	var r63_j_fam := r63_j.state.place(
			CardData.from_dict(repo.get_card(GameEngine.FAMILIAR_DUCK_ID).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r63_j_n := r63_j.state.board.size()
	r63_j.current_side = GameEngine.SIDE_OPPONENT
	r63_j._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r63_j_fam.atk_buff == 0 and r63_j.state.board.size() == r63_j_n,
			"恶魔使魔：没挂这张效果卡 → 不成长也不召唤")

	# Boss 关卡「恶魔鸭」：第一层、后排 1 只恶魔鸭、挂 9117
	var r63_lv: Dictionary = _level_named("恶魔鸭")
	check(not r63_lv.is_empty()
			and int(r63_lv.get("tier", -1)) == GameLevels.TIER_BOSS
			and GameLevels.layer_of(r63_lv) == GameLayers.LAYER_DEFAULT,
			"R63 恶魔鸭关：第一层 Boss 关卡（tier=Boss、layer=第一层）")
	var r63_lv_units: Array = r63_lv.get("enemy_units", [])
	check(r63_lv_units.size() == 1
			and int(r63_lv_units[0][0]) == GameEngine.DEMON_DUCK_ID
			and r63_lv_units[0][6] == Vector2i(0, 1),
			"R63 恶魔鸭关：敌方后排中央 1 只恶魔鸭（%s）" % str(r63_lv_units))
	check((r63_lv.get("enemy_effects", []) as Array) == [9117],
			"R63 恶魔鸭关：敌方效果卡 = [9117] 恶魔使魔")
	# 关卡数据与 cards.json 同源（力/生/程/速 不漂移）
	var r63_lv_dd:= repo.get_card(GameEngine.DEMON_DUCK_ID)
	check(int(r63_lv_units[0][2]) == r63_lv_dd.power
			and int(r63_lv_units[0][3]) == r63_lv_dd.health
			and int(r63_lv_units[0][4]) == r63_lv_dd.attack_range
			and int(r63_lv_units[0][5]) == r63_lv_dd.move_speed,
			"R63 恶魔鸭关：enemy_units 的 力/生/程/速 与 cards.json 同源（5/100/2/1）")
	# 同一层多个 Boss → 进 boss_pool 供 RunState 摇
	var r63_bp := GameLevels.boss_pool(GameLayers.LAYER_DEFAULT)
	var r63_bp_names: Array = []
	for b: Dictionary in r63_bp:
		r63_bp_names.append(str(b["name"]))
	check(r63_bp_names.has("恶魔鸭") and r63_bp_names.has("远古虚骨龙"),
			"R63 第一层 Boss 池 = 远古虚骨龙 + 恶魔鸭（%s）" % str(r63_bp_names))
	check(GameLevels.boss_pool(GameLayers.LAYER_TWO).size() == 1,
			"R63 第二层 Boss 池仍只有 1 关（机械巨鸭，不受影响）")
	# RunState 开局摇定的 boss_pick 一定落在本层池内，且next_level("boss") 返回它
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
	var r63_roll_ok := false
	for b2: Dictionary in r63_bp:
		if str(b2["name"]) == str(RunState.boss_pick.get("name", "")):
			r63_roll_ok = true
	check(r63_roll_ok and str(RunState.next_level({"type": "boss"})["name"])
			== str(RunState.boss_pick["name"]),
			"R63 RunState：boss_pick 来自本层池，且 next_level(\"boss\") 返回它")

	# ================= R73：彩蛋 Boss「恶魔鸭（复仇）」9118 =================
	var r73_cd := repo.get_card(GameEngine.DEMON_REVENGE_ID)
	check(r73_cd != null and r73_cd.card_name == "恶魔鸭（复仇）"
			and r73_cd.kind == "盟友" and r73_cd.power == 5 and r73_cd.health == 145
			and r73_cd.attack_range == 2 and r73_cd.move_speed == 1
			and r73_cd.rarity == 4 and r73_cd.group == "enemy"
			and r73_cd.traits.has(GameEngine.REVENGE_TRAIT),
			"R77 恶魔鸭（复仇）9118：敌方怪物 5/145 程2 速1（R77 提血），带「复仇」trait")
	check(not r73_cd.traits.has(FieldState.SLEEP_TRAIT),
			"R73 恶魔鸭（复仇）9118：**没有「沉睡」trait**（这一只开局就直接行动）")

	# 上场即行动：place 不置 sleep_left → 回合开始不横置
	var r73_a := _new_engine([], 30, 30)
	var r73_p := r73_a.state.place(CardData.from_dict(r73_cd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r73_p.sleep_left == 0,
			"R73 恶魔鸭（复仇）：上场 sleep_left=0（没有沉睡窗口，实际 %d）" % r73_p.sleep_left)
	r73_a.state.reset_units(GameEngine.SIDE_OPPONENT)
	check(not r73_p.tapped and not r73_p.moved,
			"R73 恶魔鸭（复仇）：第 1 个回合就能行动（既不横置也不视为已移动）")
	# AI 队列：_new_engine 默认关掉了 AI，要测队列必须先打开
	r73_a.ai_enabled = true
	r73_a.current_side = GameEngine.SIDE_OPPONENT
	check(r73_a.ai_action_queue().has(Vector2i(0, 1)),
			"R73 恶魔鸭（复仇）：照常进 AI 行动队列（不会因为「沉睡」被判为不可行动）")

	# 每次受伤 → **本回合**力量 +1（可叠加）
	var r73_b := _new_engine([], 30, 30)
	var r73_bp := r73_b.state.place(CardData.from_dict(r73_cd.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r73_pw0 := r73_bp.effective_power()
	r73_b._hit_unit(r73_bp, 3, "测试")
	# R77：复仇现在**同时**给两条 —— 本回合 +1（可叠加）+ 永久 +1（end_atk）。
	check(r73_bp.atk_buff_turn == GameEngine.REVENGE_ATK_PER_HIT
			and r73_bp.end_atk == GameEngine.REVENGE_END_ATK_PER_HIT
			and r73_bp.effective_power() == r73_pw0
			+ GameEngine.REVENGE_ATK_PER_HIT + GameEngine.REVENGE_END_ATK_PER_HIT,
			"R77 复仇：受伤 1 次 → 本回合 +%d **且** 永久 +%d（力量 %d → %d）"
			% [GameEngine.REVENGE_ATK_PER_HIT, GameEngine.REVENGE_END_ATK_PER_HIT,
				r73_pw0, r73_bp.effective_power()])
	r73_b._hit_unit(r73_bp, 2, "测试")
	r73_b._hit_unit(r73_bp, 2, "测试")
	check(r73_bp.atk_buff_turn == 3 * GameEngine.REVENGE_ATK_PER_HIT
			and r73_bp.end_atk == 3 * GameEngine.REVENGE_END_ATK_PER_HIT
			and r73_bp.effective_power() == r73_pw0
			+ 3 * GameEngine.REVENGE_ATK_PER_HIT + 3 * GameEngine.REVENGE_END_ATK_PER_HIT,
			"R77 复仇：**同一回合两条都可叠加** —— 受伤 3 次 → 本回合 +%d、永久 +%d（力量 %d）"
			% [r73_bp.atk_buff_turn, r73_bp.end_atk, r73_bp.effective_power()])
	# 清除点唯一口= end_turn 里对**当前方**的清零分支。语义 = 「持续到它自己那个回合结束」：
	# 我方回合打它 → +1 力量 → **敌方回合照样生效**（它就是靠这个多打一下更疼）→ 敌方回合结束才清。
	r73_b.current_side = GameEngine.SIDE_OPPONENT
	r73_b._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r73_bp.atk_buff_turn == 3 * GameEngine.REVENGE_ATK_PER_HIT,
			"R73 复仇：`_begin_turn` **不清**本回合加攻（清除点在 end_turn，力量 %d 保留到它行动完）"
			% r73_bp.effective_power())
	# 走真实 end_turn 路径 → 清零
	var r73_tmp := r73_bp.atk_buff_turn
	r73_b.end_turn()
	# R77：本回合那条清零，**永久那条（end_atk）保留** —— 这才是「恶魔鸭越打越强」。
	var r73_perm := r73_bp.end_atk
	check(r73_tmp > 0 and r73_bp.atk_buff_turn == 0
			and r73_bp.end_atk == r73_perm
			and r73_bp.effective_power() == r73_pw0 + r73_perm,
			"R77 复仇：敌方回合结束 → 本回合加攻清零（%d → %d）但**永久 +%d 保留**（力量 %d）"
			% [r73_tmp, r73_bp.atk_buff_turn, r73_bp.end_atk, r73_bp.effective_power()])
	# 再打一下确认「可以反复叠加」而不是一次就用光
	r73_b._hit_unit(r73_bp, 1, "测试")
	check(r73_bp.atk_buff_turn == GameEngine.REVENGE_ATK_PER_HIT,
			"R73 复仇：清零后还能再叠（新一轮受伤 → 本回合 +%d）" % r73_bp.atk_buff_turn)
	# 9116 恶魔鸭那条通路不受影响（还是沉睡 + 永久加攻）
	var r73_c := _new_engine([], 30, 30)
	var r73_cp := r73_c.state.place(CardData.from_dict(repo.get_card(
			GameEngine.DEMON_DUCK_ID).to_dict()), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r73_cp.sleep_left == FieldState.SLEEP_TURNS,
			"R73 9116 恶魔鸭仍沉睡 %d 回合（新增 9118 不影响原卡）" % r73_cp.sleep_left)
	r73_c._hit_unit(r73_cp, 1, "测试")
	check(r73_cp.atk_buff_turn == 0,
			"R73 9116 恶魔鸭受伤不涨本回合加攻（沉睡机制照旧：sleep_left=%d）"
			% r73_cp.sleep_left)

	# ---- 彩蛋关卡本身 ----
	var r73_lv: Dictionary = GameLevels.revenge_boss()
	check(not r73_lv.is_empty()
			and str(r73_lv.get("name", "")) == "恶魔鸭（复仇）"
			and int(r73_lv.get("tier", -1)) == GameLevels.TIER_BOSS,
			"R73 彩蛋关：恶魔鸭（复仇）是 Boss 分级（唯一取用口 GameLevels.revenge_boss）")
	var r73_units: Array = r73_lv.get("enemy_units", [])
	check(r73_units.size() == 1 and int(r73_units[0][0]) == GameEngine.DEMON_REVENGE_ID
			and r73_units[0][6] == Vector2i(0, 1),
			"R73 彩蛋关：敌方后排中央 1 只恶魔鸭（复仇）—— 与第一层关卡同摆位")
	check((r73_lv.get("enemy_effects", []) as Array) == [9117],
			"R73 彩蛋关：敌方效果卡仍是 [9117] 恶魔使魔（与第一层一致）")
	# 关卡数据与 cards.json 同源
	var r73_lu := repo.get_card(GameEngine.DEMON_REVENGE_ID)
	check(int(r73_units[0][2]) == r73_lu.power and int(r73_units[0][3]) == r73_lu.health
			and int(r73_units[0][4]) == r73_lu.attack_range
			and int(r73_units[0][5]) == r73_lu.move_speed,
			"R77 彩蛋关：enemy_units 的 力/生/程/速 与 cards.json 同源（5/145/2/1）")
	# **绝不进 boss_pool** —— 否则第二层会随机抽到它，50% 触发就形同虚设
	var r73_p1: Array = []
	for b3: Dictionary in GameLevels.boss_pool(GameLayers.LAYER_DEFAULT):
		r73_p1.append(str(b3["name"]))
	var r73_p2: Array = []
	for b4: Dictionary in GameLevels.boss_pool(GameLayers.LAYER_TWO):
		r73_p2.append(str(b4["name"]))
	check(not r73_p1.has("恶魔鸭（复仇）") and not r73_p2.has("恶魔鸭（复仇）")
			and r73_p2.size() == 1 and r73_p2[0] == "机械巨鸭",
			"R73 彩蛋关**不进 boss_pool**（第一层 %s / 第二层 %s —— 第二层仍只有机械巨鸭）"
			% [str(r73_p1), str(r73_p2)])
	# 也不该出现在关卡选择菜单里（不在 builtin_levels）
	var r73_in_menu := false
	for r73_l: Dictionary in GameLevels.builtin_levels():
		if str(r73_l.get("name", "")) == "恶魔鸭（复仇）":
			r73_in_menu = true
	check(not r73_in_menu,
			"R73 彩蛋关不在 builtin_levels（不会混进调试关卡菜单 / 关卡总数）")

	# ---- 触发链路：第一层摇中恶魔鸭 → 50% → 第二层 boss 被顶替 ----
	check(RunState.REVENGE_TRIGGER_CHANCE == 0.5,
			"R73 彩蛋触发概率 = 50%%（常量 %f）" % RunState.REVENGE_TRIGGER_CHANCE)
	# 未触发时：第二层 boss 仍是机械巨鸭
	# ⚠️ 不能只在 start_run 前置 false —— start_run 内部会重摇第一层 boss 并**可能重新置位**，
	# 所以要在 start_run **之后**再强制清一次，才真正构造出「未触发」局面。
	RunState.revenge_pending = false
	RunState.run_rng.seed = 20261004
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
	RunState.revenge_pending = false
	var r73_no := RunState._roll_boss(GameLayers.LAYER_TWO)
	check(str(r73_no.get("name", "")) == "机械巨鸭"
			and not RunState.revenge_pending,
			"R73 未触发时第二层 boss 仍是机械巨鸭（实际 %s）" % str(r73_no.get("name", "")))
	# 已触发时：第二层 boss 被顶替成复仇关，且**一次性消费**（复位）
	RunState.revenge_pending = true
	var r73_yes := RunState._roll_boss(GameLayers.LAYER_TWO)
	check(str(r73_yes.get("name", "")) == "恶魔鸭（复仇）"
			and not RunState.revenge_pending,
			"R73 触发后第二层 boss = 恶魔鸭（复仇），且 pending 一次性复位（不会连层顶替）")
	# 顶替后 next_level("boss") 读的也是它（地图名牌与实际进入同一份）
	RunState.boss_pick = GameLevels.revenge_boss()
	check(str(RunState.next_level({"type": "boss"})["name"]) == "恶魔鸭（复仇）"
			and str(RunState.boss_pick["name"]) == "恶魔鸭（复仇）",
			"R73 顶替后地图 Boss 名牌与实际进入的关卡一致（都是恶魔鸭（复仇））")
	# run 结束必须复位 pending（否则下一局莫名触发）
	RunState.revenge_pending = true
	RunState.end_run()
	check(not RunState.revenge_pending and RunState.boss_pick.is_empty(),
			"R73 end_run 复位 revenge_pending 与 boss_pick（不漏进下一局）")
	# 统计触发率：大量开局里，第一层摇中恶魔鸭的那些局约一半触发
	var r73_runs := 120
	var r73_first_is_dd := 0
	var r73_fired := 0
	for t in r73_runs:
		RunState.revenge_pending = false
		RunState.run_rng.seed = 777000 + t * 131
		RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
		if str(RunState.boss_pick.get("name", "")) != RunState.DEMON_DUCK_BOSS_NAME:
			continue
		r73_first_is_dd += 1
		if RunState.revenge_pending:
			r73_fired += 1
	# 第一层约一半概率摇中恶魔鸭；其中约一半触发彩蛋
	var r73_rate := 0.0 if r73_first_is_dd == 0 else float(r73_fired) / float(r73_first_is_dd)
	check(r73_first_is_dd > 0 and r73_rate > 0.25 and r73_rate < 0.75,
			"R73 触发率实测：%d 局里第一层摇中恶魔鸭 %d 次，其中 %d 次触发彩蛋（%.0f%%，期望 50%%）"
			% [r73_runs, r73_first_is_dd, r73_fired, r73_rate * 100.0])
	RunState.end_run()

	# ================= R65（2026-10-04）：手卡「额外效果可触发」金色高亮判定 =================
	# 唯一判定口 = GameEngine.hand_bonus_ready / hand_bonus_text，战斗界面照它画金色高亮。
	# 收尾 9104：手卡仅剩它 → 6 伤变 22 伤（R71）。
	var r65_a := _new_engine([], 30, 30)
	var r65_fin: CardData = CardData.from_dict(repo.get_card(GameEngine.FINISHER_ID).to_dict())
	r65_a.state.hand.append(r65_fin)
	check(r65_a.hand_bonus_ready(r65_fin),
			"R65 高亮：收尾 9104 是手卡最后一张 → 亮（4 伤变 %d 伤）" % GameEngine.FINISHER_LAST_DMG)
	check(r65_a.hand_bonus_text(r65_fin).contains(str(GameEngine.FINISHER_LAST_DMG)),
			"R65 高亮：收尾的提示文案写明 %d 伤" % GameEngine.FINISHER_LAST_DMG)
	r65_a.state.hand.append(_card(7904, "垫手牌", "技能", 1, 0, 0))
	check(not r65_a.hand_bonus_ready(r65_fin),
			"R65 高亮：手里还有别的牌 → 收尾不亮（只能吃到 %d 伤）" % GameEngine.FINISHER_DMG)
	# 影魔 8007：手卡里有 0 费技能牌 → 每张 +3 生命。
	var r65_b := _new_engine([], 30, 30)
	var r65_sd: CardData = CardData.from_dict(repo.get_card(GameEngine.SHADOW_DEMON_ID).to_dict())
	r65_b.state.hand.append(r65_sd)
	check(not r65_b.hand_bonus_ready(r65_sd),
			"R65 高亮：影魔 8007 手里没有 0 费技能牌 → 不亮")
	r65_b.state.hand.append(_card(7910, "0 费技能", "技能", 0, 0, 0))
	r65_b.state.hand.append(_card(7911, "另一个 0 费技能", "技能", 0, 0, 0))
	check(r65_b.hand_bonus_ready(r65_sd)
			and r65_b.hand_bonus_text(r65_sd).contains(
				str(2 * GameEngine.SHADOW_DEMON_HP_PER)),
			"R65 高亮：影魔手卡有 2 张 0 费技能牌 → 亮（生命 +%d）"
			% (2 * GameEngine.SHADOW_DEMON_HP_PER))
	# 以太守卫 9067：效果区非空 → 每张效果卡 +1 力量 +2 生命。
	var r65_c := _new_engine([], 30, 30)
	var r65_ag: CardData = CardData.from_dict(repo.get_card(GameEngine.AETHER_GUARD_ID).to_dict())
	r65_c.state.hand.append(r65_ag)
	check(not r65_c.hand_bonus_ready(r65_ag),
			"R65 高亮：以太守卫 9067 效果区为空 → 不亮")
	r65_c.state.effects.append(CardData.from_dict(repo.get_card(9092).to_dict()))
	check(r65_c.hand_bonus_ready(r65_ag) and r65_c.hand_bonus_text(r65_ag).contains("力量 +1"),
			"R65 高亮：效果区 1 张 → 以太守卫亮（力量 +1 生命 +2）")
	# 无条件效果的普通卡不亮（不能什么牌都亮，否则高亮就没意义了）
	var r65_d := _new_engine([], 30, 30)
	var r65_plain: CardData = _card(8003, "农民", "盟友", 3, 3, 8)
	r65_d.state.hand.append(r65_plain)
	check(not r65_d.hand_bonus_ready(r65_plain) and r65_d.hand_bonus_text(r65_plain) == "",
			"R65 高亮：普通卡（无使用时额外效果）不亮")
	check(not r65_d.hand_bonus_ready(null),
			"R65 高亮：传 null 不崩、返回 false")
	# 判定与实际结算同口径：条件真的成立时，打出去确实吃到那个效果
	var r65_e := _new_engine([], 30, 30)
	var r65_sd2: CardData = CardData.from_dict(repo.get_card(GameEngine.SHADOW_DEMON_ID).to_dict())
	r65_e.state.hand.append(_card(7910, "0 费技能", "技能", 0, 0, 0))
	r65_e.state.hand.append(r65_sd2)
	r65_e.state.energy = 5
	var r65_hp_before := r65_sd2.health
	r65_e.play_from_hand(1, Vector2i(3, 1))     # 打影魔（index 1）
	var r65_sd2_p:= r65_e.state.unit_at(Vector2i(3, 1))
	check(r65_sd2_p != null
			and r65_sd2_p.health == r65_hp_before + GameEngine.SHADOW_DEMON_HP_PER,
			"R65 高亮与结算一致：影魔亮的时候打出去确实 +%d 生命（%d → %d）"
			% [GameEngine.SHADOW_DEMON_HP_PER, r65_hp_before,
				r65_sd2_p.health if r65_sd2_p != null else -1])


	# ================= R77：数值 / 机制 / 图鉴 =================

	# ---- R77-A：两处场地数值上调 ----
	check(GameEngine.PIERCE_TRAP_DMG == 18,
			"R77 穿刺陷阱 8016：伤害 %d（R77 由 14 上调）" % GameEngine.PIERCE_TRAP_DMG)
	check(GameEngine.POISON_TURNS == 4,
			"R77 剧毒陷阱 8014：持续 %d 回合（R77 由 3 上调）" % GameEngine.POISON_TURNS)

	# ---- R77-B：警觉 9109 供给「场地卡」----
	var r77_al := _new_engine([], 30, 30)
	RunState.player_class = PlayerClass.ROGUE
	r77_al.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ALERT_ID).to_dict()))
	r77_al.state.energy = 5
	var r77_al_res := r77_al.use_spell(0)
	var r77_al_pool: int = 0
	for _k in 10:
		var r77_al2 := _new_engine([], 30, 30)
		r77_al2.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ALERT_ID).to_dict()))
		r77_al2.state.energy = 5
		r77_al2.use_spell(0)
		if r77_al2.state.hand.is_empty():
			continue
		var r77_al_c: CardData = r77_al2.state.hand[0]
		if r77_al_c.is_field():
			r77_al_pool += 1
	check(r77_al_res.contains("警觉") and r77_al_pool == 10,
			"R77 警觉 9109：连抽 10 次全部给**场地卡**（%d/10），不再给工事" % r77_al_pool)

	# ---- R77-C：恶魔鸭（复仇）两条挨打变强都在 ----
	var r77_rv := _new_engine([], 30, 30)
	var r77_rvp := r77_rv.state.place(CardData.from_dict(repo.get_card(9118).to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r77_pw := r77_rvp.effective_power()
	r77_rv._hit_unit(r77_rvp, 3, "测试")
	check(r77_rvp.atk_buff_turn == GameEngine.REVENGE_ATK_PER_HIT
			and r77_rvp.end_atk == GameEngine.REVENGE_END_ATK_PER_HIT
			and r77_rvp.effective_power() == r77_pw + 2,
			"R77 复仇 9118：一次受伤同时给 本回合 +%d 与 永久 +%d（力量 %d → %d）"
			% [GameEngine.REVENGE_ATK_PER_HIT, GameEngine.REVENGE_END_ATK_PER_HIT,
				r77_pw, r77_rvp.effective_power()])
	check(r77_rvp.health == 145 - 3 and r77_rvp.card.health == 145,
			"R77 复仇 9118：血量 145（挨一下剩 %d）" % r77_rvp.health)

	# ---- R77-D：鸭语耳环 6015 逐张驱动（原来是一次 while 跑完）----
	# 同步版（回归/录像走这条）：语义不变，仍然一口气出完。
	var r77_ea := _new_engine([], 30, 30)
	r77_ea.self_relics = [GameEngine.EARRING_RELIC_ID]
	r77_ea.autoplay_stepwise = false      # 回归里同步跑，避免依赖帧
	r77_ea._begin_turn(GameEngine.SIDE_SELF)
	var r77_ea_steps: Array[int] = [0]
	var r77_ea_conn: int = r77_ea.action.connect(func(what: String, _d: Variant) -> void:
			if what == "earring_autoplay_step":
				r77_ea_steps.append(int((_d as Dictionary).get("index", -1)) + 1))
	check(not r77_ea.earring_autoplay_active() and r77_ea_steps.size() >= 1,
			"R77 鸭语耳环：同步版（回归/录像）一口气跑完，共 %d 张" % (r77_ea_steps.size() - 1))
	# 逐张版：begin 只启动，pending 为真；每调一步出恰好一张。
	# ⚠️ 必须给一副**真卡组** —— 空牌组时 _autoplay_step 第一步就「牌库抽空」收尾，
	# 后面「推进一步出一张」根本不会发生（这正是上面同步版断言只能写 >=1 的原因）。
	var r77_eb := _new_engine([], 30, 30)
	for _d2 in 6:
		r77_eb.state.deck.append(_card(7801 + _d2, "耳环测试卡%d" % _d2, "盟友", 0, 2, 6, 1, 1))
	r77_eb.state.deck.append(_card(7811, "耳环法术", "技能", 1, 0, 0))
	r77_eb.self_relics = [GameEngine.EARRING_RELIC_ID]
	r77_eb.autoplay_stepwise = true       # 界面实机走这条
	var r77_eb_n := [0]
	r77_eb.action.connect(func(what: String, _d: Variant) -> void:
			if what == "earring_autoplay_step":
				r77_eb_n[0] = int((_d as Dictionary).get("index", -1)) + 1)
	r77_eb._begin_turn(GameEngine.SIDE_SELF)
	check(r77_eb.earring_autoplay_active(),
			"R77 鸭语耳环：第 1 回合只**启动**自动出牌（pending=true），不出任何牌")
	check(r77_eb_n[0] == 0,
			"R77 鸭语耳环：启动时一张都还没出（已播 %d 张）—— 出牌由界面每帧推进" % r77_eb_n[0])
	# 推进一步 → 恰好多一张
	r77_eb._autoplay_step(0)
	check(r77_eb_n[0] == 1,
			"R77 鸭语耳环：推进一步 = 出一张（已播 %d 张），事件逐张发" % r77_eb_n[0])
	# 一路推到自然结束 → pending 关闭
	var r77_eb_guard := 0
	while r77_eb.earring_autoplay_active() and r77_eb_guard < GameEngine.EARRING_AUTOPLAY_MAX + 4:
		r77_eb._autoplay_step(r77_eb_n[0])
		r77_eb_guard += 1
	check(not r77_eb.earring_autoplay_active() and r77_eb_guard <= GameEngine.EARRING_AUTOPLAY_MAX + 4,
			"R77 鸭语耳环：推到结束自动收尾（%d 步后 pending=false，共播 %d 张）"
			% [r77_eb_guard, r77_eb_n[0]])
	# 复位：逐张模式已关（引擎是成员变量，每个用例各自新建 engine，本来就是干净的）

	# ---- R77-E：图鉴口径 —— 场地卡要能被选到 ----
	var r77_gal: Array[CardData] = []
	for c2 in repo.all_cards():
		if c2.kind == "场地":
			r77_gal.append(c2)
	check(r77_gal.size() >= 6,
			"R77 图鉴：卡库里有 %d 张场地卡（图鉴「种类」下拉已加「场地」选项）" % r77_gal.size())

	# ================= R78：场地不该能放在「敌人走不到的行」 =================
	# 场地是「等敌人踩上去」的一次性效果，所以判据是**场地主人的敌对方能否走到该格**。
	# 移动禁区：forbidden_row_for(OPP)=back_row(SELF)=5、forbidden_row_for(SELF)=back_row(OPP)=0
	# → 敌方可达 0..4、我方可达 1..5。所以我方场地不能放 row 5，敌方场地不能放 row 0。

	# ---- 生效对象读自卡面 trait（缺省 = 敌，即陷阱）----
	var r79_self_back := GameEngine.back_row(GameEngine.SIDE_SELF)
	var r79_opp_back := GameEngine.back_row(GameEngine.SIDE_OPPONENT)
	check(r79_self_back == FieldState.BOARD_ROWS - 1 and r79_opp_back == 0,
			"R79 场地：我方后排=row %d、敌方后排=row %d" % [r79_self_back, r79_opp_back])
	check(GameEngine.field_aim(null) == GameEngine.FIELD_AIM_ENEMY
			and GameEngine.field_aim(repo.get_card(8011)) == GameEngine.FIELD_AIM_ENEMY,
			"R79 生效对象：缺省按「敌」（陷阱）——现有场地卡全是等敌人踩的陷阱")
	var r79_fake := CardData.new()
	r79_fake.kind = "场地"
	var r79_aims: Array[String] = []
	for t2: String in ["场地生效·敌", "场地生效·友", "场地生效·双"]:
		r79_fake.traits = [t2]
		r79_aims.append(GameEngine.field_aim(r79_fake))
	check(r79_aims[0] == GameEngine.FIELD_AIM_ENEMY
			and r79_aims[1] == GameEngine.FIELD_AIM_ALLY
			and r79_aims[2] == GameEngine.FIELD_AIM_BOTH
			and r79_aims[0] != r79_aims[1] and r79_aims[1] != r79_aims[2],
			"R79 生效对象：trait「场地生效·敌/友/双」分别读成 %s（三值互不相同）" % str(r79_aims))

	# ---- 判定口（唯一口）：按**生效对象**决定禁哪一行 ----
	# R79 修正 R77/R78：不该「粗暴禁止所有场地放后排」，该禁的是「目标方永远够不着」的行。
	#   陷阱（敌）：敌方移动禁区 = 我方后排 → 我方后排禁放，敌方半场 0..4 全允许。
	check(not GameEngine.field_place_allowed(Vector2i(r79_self_back, 1), GameEngine.FIELD_AIM_ENEMY)
			and GameEngine.field_place_allowed(Vector2i(r79_opp_back, 1), GameEngine.FIELD_AIM_ENEMY)
			and GameEngine.field_place_allowed(Vector2i(2, 1), GameEngine.FIELD_AIM_ENEMY),
			"R79 陷阱（对敌生效）：我方后排 row %d 禁放、**敌方后排 row %d 照常可放**" % [r79_self_back, r79_opp_back])
	#   只对己方生效：我方移动禁区 = 敌方后排 → 敌方后排禁放
	check(not GameEngine.field_place_allowed(Vector2i(r79_opp_back, 1), GameEngine.FIELD_AIM_ALLY)
			and GameEngine.field_place_allowed(Vector2i(r79_self_back, 1), GameEngine.FIELD_AIM_ALLY)
			and GameEngine.field_place_allowed(Vector2i(2, 1), GameEngine.FIELD_AIM_ALLY),
			"R79 只对己方生效：敌方后排 row %d 禁放（我们自己进不去）、其余全允许" % r79_opp_back)
	#   对双方生效：两边都进得去 → **没有任何行限制**
	var r79_both_ok := true
	for x5 in FieldState.BOARD_ROWS:
		if not GameEngine.field_place_allowed(Vector2i(x5, 1), GameEngine.FIELD_AIM_BOTH):
			r79_both_ok = false
	check(r79_both_ok,
			"R79 对双方生效：**全场 %d 行皆可放**（不存在任何行限制）" % FieldState.BOARD_ROWS)
	# 越界照样拒（三种生效对象都一样）
	var r79_oob := true
	for a: String in [GameEngine.FIELD_AIM_ENEMY, GameEngine.FIELD_AIM_ALLY,
			GameEngine.FIELD_AIM_BOTH]:
		if GameEngine.field_place_allowed(Vector2i(-1, 0), a) \
				or GameEngine.field_place_allowed(Vector2i(0, -1), a) \
				or GameEngine.field_place_allowed(Vector2i(FieldState.BOARD_ROWS, 0), a) \
				or GameEngine.field_place_allowed(Vector2i(0, FieldState.BOARD_COLS), a):
			r79_oob = false
	check(r79_oob, "R79 判定口：越界格在三种生效对象下都一律拒绝")

	# ---- 玩家出手路径：判定口 == 实际，且拒放必须退费 ----
	var r79_ids: Array[int] = []
	for c4 in repo.all_cards():
		if c4.kind == "场地":
			r79_ids.append(c4.id)
	var r79_bad: Array[String] = []
	var r79_enemy_cards := 0
	var r79_both_cards := 0
	var r79_ally_cards := 0
	for fid3 in r79_ids:
		var r79_card: CardData = repo.get_card(fid3)
		var r79_a := GameEngine.field_aim(r79_card)
		if r79_a == GameEngine.FIELD_AIM_ENEMY:
			r79_enemy_cards += 1
		elif r79_a == GameEngine.FIELD_AIM_BOTH:
			r79_both_cards += 1
		elif r79_a == GameEngine.FIELD_AIM_ALLY:
			r79_ally_cards += 1
		for x6 in FieldState.BOARD_ROWS:
			var st3 := FieldState.new([], 30, 30, -1, "R79", true)
			var e3 := GameEngine.new(st3)
			e3.ai_enabled = false
			e3.state.energy = 30
			e3.state.hand.append(CardData.from_dict(r79_card.to_dict()))
			var before3 := e3.state.energy
			e3.play_from_hand(0, Vector2i(x6, 1))
			var placed3 := e3.state.field_at(Vector2i(x6, 1)) != null
			var allowed3 := GameEngine.field_place_allowed(Vector2i(x6, 1), r79_a)
			if placed3 != allowed3:
				r79_bad.append("%d@row%d(判定%s实际%s)" % [fid3, x6, str(allowed3), str(placed3)])
			if not allowed3 and e3.state.energy != before3:
				r79_bad.append("%d@row%d 拒放但没退费(%d→%d)" % [fid3, x6, before3, e3.state.energy])
	check(r79_bad.is_empty() and r79_ids.size() == 9
			and r79_enemy_cards == 6 and r79_both_cards == 1 and r79_ally_cards == 2,
			"R79 玩家放场地：%d 张卡（%d 敌生效 / %d 双生效（清泉 8028）/ %d 友生效（维修间 8036 + 改造工厂 8037）），"
			% [r79_ids.size(), r79_enemy_cards, r79_both_cards, r79_ally_cards]
			+ "%d 张 × %d 行「判定 == 实际」且拒放退费（%s）" % [
				r79_ids.size(), FieldState.BOARD_ROWS,
				"无异常" if r79_bad.is_empty() else "、".join(r79_bad)])

	# ---- 敌方出手路径：R78 之前完全没有校验，现在也走同一判定口 ----
	# R88 新增一条维度：写 trait「仅玩家可放置」的场地（维修间 8036 / 改造工厂 8037）
	# **敌方一律摆不出来**（不管哪一行），且费用照扣（remote_play 开头就付了，没有退费机制）。
	var r79_obad: Array[String] = []
	var r79_playeronly := 0
	for fid4 in r79_ids:
		var r79_c4: CardData = repo.get_card(fid4)
		var r79_a4 := GameEngine.field_aim(r79_c4)
		var r79_po4: bool = GameEngine.is_player_only_field(r79_c4)
		if r79_po4:
			r79_playeronly += 1
		for x7 in FieldState.BOARD_ROWS:
			var st4 := FieldState.new([], 30, 30, -1, "R79", true)
			var e4 := GameEngine.new(st4)
			e4.ai_enabled = false
			e4.remote_play(CardData.from_dict(r79_c4.to_dict()), Vector2i(x7, 1))
			var placed4 := e4.state.field_at(Vector2i(x7, 1)) != null
			# 期望：仅玩家可放置 → 一律 false；否则走同一放置判定口
			var allowed4: bool = false if r79_po4 \
				else GameEngine.field_place_allowed(Vector2i(x7, 1), r79_a4)
			if placed4 != allowed4:
				r79_obad.append("%d@row%d(判定%s实际%s)" % [fid4, x7, str(allowed4), str(placed4)])
			if r79_po4 and placed4:
				r79_obad.append("%d@row%d 仅玩家可放置却放出来了" % [fid4, x7])
	check(r79_obad.is_empty() and r79_playeronly == 2,
			"R79+R88 敌方放场地：%d 张卡 × %d 行走同一判定口，其中 %d 张「仅玩家可放置」一律拒放（%s）" % [
				r79_ids.size(), FieldState.BOARD_ROWS, r79_playeronly,
				"无异常" if r79_obad.is_empty() else "、".join(r79_obad)])

	# ---- 语义锁：合法行 == 该生效对象可达的行 ----
	var r79_foe_reach: Array[int] = []
	for x8 in FieldState.BOARD_ROWS:
		if x8 != GameEngine.forbidden_row_for(GameEngine.SIDE_OPPONENT):
			r79_foe_reach.append(x8)
	var r79_trap_ok: Array[int] = []
	for x9 in FieldState.BOARD_ROWS:
		if GameEngine.field_place_allowed(Vector2i(x9, 1), GameEngine.FIELD_AIM_ENEMY):
			r79_trap_ok.append(x9)
	check(r79_trap_ok == r79_foe_reach,
			"R79 语义：陷阱合法行 %s == 敌人可达行 %s（每格都等得到人踩）" % [str(r79_trap_ok), str(r79_foe_reach)])
	var r79_me_reach: Array[int] = []
	for xa in FieldState.BOARD_ROWS:
		if xa != GameEngine.forbidden_row_for(GameEngine.SIDE_SELF):
			r79_me_reach.append(xa)
	var r79_ally_ok: Array[int] = []
	for xb in FieldState.BOARD_ROWS:
		if GameEngine.field_place_allowed(Vector2i(xb, 1), GameEngine.FIELD_AIM_ALLY):
			r79_ally_ok.append(xb)
	check(r79_ally_ok == r79_me_reach,
			"R79 语义（对称）：只对己方生效的合法行 %s == 我方可达行 %s" % [str(r79_ally_ok), str(r79_me_reach)])

	# ================= R80 =================
	# ① 场地「移动经过即触发 + 立即停止移动」——
	#    旧口径是「走到那一格才触发」（终点判定），R80 改成**路径判定**：多格移动
	#    时只要路过中间任何一格就触发，且**落点改成那一格**（不再走完剩下的路）。
	#    这条锁的是唯一口_field_block_index + move() 里的路径截断。
	var r80 := _new_engine([], 30, 30)
	# 敌方速 2 的单位站在 (1,0)，路径 (1,0)→(1,1)→(1,2) 上；(1,1) 放穿刺陷阱
	var r80_foe: Placement = r80.state.place(_card(9031, "白狼", "盟友", 4, 4, 40, 1, 2),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	r80.state.set_field(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	var r80_hp0 := r80_foe.health
	r80.current_side = GameEngine.SIDE_OPPONENT
	r80.move(Vector2i(1, 0), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	check(r80.state.field_at(Vector2i(1, 1)) == null,
		"R80 场地：中途(1,1) 被「经过」→ 场地消失（不需要停在它上面）")
	check(r80.state.unit_at(Vector2i(1, 1)) == r80_foe
			and r80.state.unit_at(Vector2i(1, 2)) == null,
		"R80 场地：触发后**立即停止移动** —— 落在(1,1)，没有继续走到(1,2)")
	check(r80_foe.health == r80_hp0 - GameEngine.PIERCE_TRAP_DMG,
		"R80 场地：伤害打给路过的那个单位（%d → %d，期望 -%d）" % [
			r80_hp0, r80_foe.health, GameEngine.PIERCE_TRAP_DMG])

	# ② 「原本就站在场地上」的单位动一下 → **不触发**（src 不在 path 里）
	var r80b := _new_engine([], 30, 30)
	var r80b_foe: Placement = r80b.state.place(
			_card(9031, "白狼", "盟友", 4, 4, 40, 1, 2),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	r80b.state.set_field(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	var r80b_hp0 := r80b_foe.health
	r80b.current_side = GameEngine.SIDE_OPPONENT
	r80b.move(Vector2i(1, 1), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	check(r80b.state.field_at(Vector2i(1, 1)) != null
			and r80b_foe.health == r80b_hp0,
		"R80 场地：起点就有场地时，移动**不触发**（没「经过」它，只是离开）")

	# ③ 路径上没有场地 → 走完全程，行为与 R74 一致（不回归）
	var r80c := _new_engine([], 30, 30)
	var r80c_foe: Placement = r80c.state.place(
			_card(9031, "白狼", "盟友", 4, 4, 40, 1, 2),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	r80c.state.set_field(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)   # 路径外
	r80c.current_side = GameEngine.SIDE_OPPONENT
	r80c.move(Vector2i(1, 0), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	check(r80c.state.unit_at(Vector2i(1, 2)) == r80c_foe and r80c_foe.health == 40,
		"R80 场地：路径上没有场地 → 正常走完（到达(1,2)、满血）")

	# ④ 唯一口_field_block_index：返回「路径上第一个场地的下标」，没有则 -1
	#    ⚠️ path[0] 是**起点本身**（move_path 的既有约定）→ 起点格必须被跳过。
	var r80d := _new_engine([], 30, 30)
	var r80d_path: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	check(r80d._field_block_index(r80d_path) == -1,
		"R80 _field_block_index：路径上无场地 → -1（不拦停）")
	r80d.state.set_field(CardData.from_dict(repo.get_card(GameEngine.TRAP_ID).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(r80d._field_block_index(r80d_path) == 1,
		"R80 _field_block_index：场地在 path[1] → 返回 1（取**第一个**，不是最后一个）")
	# 起点格有场地 → 必须跳过（动一下不该被自己脚下的场地炸）
	r80d.state.set_field(CardData.from_dict(repo.get_card(GameEngine.TRAP_ID).to_dict()),
			Vector2i(2, 0), GameEngine.SIDE_SELF)
	check(r80d._field_block_index(r80d_path) == 1,
		"R80 _field_block_index：起点 path[0] 有场地也被跳过 → 仍是 1（不原地触发）")

	# ⑤ 六张陷阱场地全部：卡面写「移动经过」+「立即停止这次移动」，且都有场地生效·敌
	var r80_missing: Array[String] = []
	for r80_id in [GameEngine.TRAP_ID, GameEngine.FROST_TRAP_ID,
			GameEngine.FREEZE_TRAP_ID, GameEngine.POISON_TRAP_ID,
			GameEngine.PIERCE_TRAP_ID, GameEngine.MASS_TRAP_ID]:
		var r80_card: CardData = repo.get_card(r80_id)
		if r80_card == null or not r80_card.effect_text.contains("移动经过") \
				or not r80_card.effect_text.contains("立即停止这次移动") \
				or not r80_card.traits.has("场地生效·敌"):
			r80_missing.append(str(r80_id))
	check(r80_missing.is_empty(),
		"R80 六张陷阱场地：卡面全部写明「移动经过即触发 + 立即停止移动」且标注场地生效·敌（%s）"
			% ("全部通过" if r80_missing.is_empty() else "缺 " + "、".join(r80_missing)))

	# ⑥ 「行动两次」文字标记（R80）：判据字段存在且与引擎一致
	#    —— 界面 battle_scene._draw_board_unit 读的就是 Placement.acts_left > 1。
	var r80e := _new_engine([], 30, 30)
	var r80e_wolf: Placement = r80e.state.place(
			CardData.from_dict(repo.get_card(9031).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_SELF)
	var r80e_norm: Placement = r80e.state.place(
			_card(8003, "树人", "盟友", 2, 2, 10, 1, 1),
			Vector2i(3, 2), GameEngine.SIDE_SELF)
	check(r80e_wolf.acts_left > 1 and r80e_norm.acts_left == 1,
		"R80 行动两次标记：双动单位 acts_left=%d > 1、普通单位 =%d（界面按这个判据画文字徽标）"
			% [r80e_wolf.acts_left, r80e_norm.acts_left])
	# 用掉一次行动后 acts_left 归 1 → 标记自动消失（不会一直挂着误导玩家）
	r80e._tap(r80e_wolf, "R80 测试")
	check(r80e_wolf.acts_left == 1 and not r80e_wolf.tapped,
		"R80 行动两次标记：消耗掉一轮后 acts_left 降到 1（本回合还剩 1 次，不再显示双动）")

	# ================================================================
	# R81：奖励道具「鸭血」（6024）—— 获得时从卡组里最多选 2 张各复制一份
	# ================================================================
	var r81_repo := RelicRepo.load_json()
	var r81_card_repo := CardRepo.load_json()
	check(r81_repo.get_relic(RunState.DUCK_BLOOD_RELIC_ID) != null
			and r81_repo.get_relic(RunState.DUCK_BLOOD_RELIC_ID).relic_name == "鸭血",
		"R81 鸭血 6024：已登记到 relics.json")
	var r81_rel: RelicData = r81_repo.get_relic(RunState.DUCK_BLOOD_RELIC_ID)
	check(r81_rel.kind == RelicData.KIND_INSTANT
			and r81_rel.source == RelicData.SRC_REWARD
			and r81_rel.source_color() == Color("e0b23c"),
		"R81 鸭血：即时类 + 奖励来源（黄）—— 走精英/Boss 掉落与宝箱层")
	check(r81_repo.reward_ids().has(RunState.DUCK_BLOOD_RELIC_ID)
			and not r81_repo.initial_ids().has(RunState.DUCK_BLOOD_RELIC_ID)
			and not r81_repo.event_ids().has(RunState.DUCK_BLOOD_RELIC_ID)
			and not r81_repo.layer2_ids().has(RunState.DUCK_BLOOD_RELIC_ID)
			and not r81_repo.class_ids().has(RunState.DUCK_BLOOD_RELIC_ID),
		"R81 鸭血：只在奖励池，不进初始 / 事件 / 二层 / 角色赠品池")
	check(r81_rel.needs_pick(),
		"R81 鸭血：needs_pick() = true（获得后需要玩家再选卡）")
	check(RunState.DUCK_BLOOD_MAX == 2,
		"R81 鸭血：复制张数上限 = 2（RunState.DUCK_BLOOD_MAX，界面按它显示）")

	# 获得 → 进入卡组选择待办（地图 / 起点道具界面据此重定向到卡组编辑场景）
	var r81_saved_relics: Array[int] = RunState.relics.duplicate()
	var r81_saved_deck: Array[int] = RunState.deck_ids.duplicate()
	RunState.relics = []
	RunState.deck_ids = [8001, 8001, 8002, 8003, 8004, 8005]
	var r81_fixture: Array[int] = RunState.deck_ids.duplicate()   # 固定测试卡组（6 张，含同名）
	RunState.gain_relic(RunState.DUCK_BLOOD_RELIC_ID)
	check(RunState.has_relic(RunState.DUCK_BLOOD_RELIC_ID)
			and RunState.pending_relic == RunState.DUCK_BLOOD_RELIC_ID,
		"R81 鸭血：获得后进入卡组选择待办（pending_relic = 6024）")
	check(RunState.deck_ids.size() == 6,
		"R81 鸭血：获得瞬间**不改卡组**（复制发生在玩家选完之后）")

	# 选 2 张 → 各复制一份（原卡保留，卡组 +2）
	var r81_before: Array[int] = RunState.deck_ids.duplicate()
	var r81_res := RunState.duplicate_deck_cards(r81_card_repo, [1, 4])
	var r81_copied: Array = r81_res["copied"]
	check(bool(r81_res["ok"]) and r81_copied.size() == 2
			and RunState.deck_ids.size() == r81_before.size() + 2,
		"R81 鸭血：选 2 张 → 卡组 +2（%d → %d）"
			% [r81_before.size(), RunState.deck_ids.size()])
	check(RunState.deck_ids[1] == r81_before[1] and RunState.deck_ids[4] == r81_before[4],
		"R81 鸭血：原卡**留在原位**（复制是追加，不是移动）")
	check(RunState.deck_ids[6] == r81_before[1] and RunState.deck_ids[7] == r81_before[4],
		"R81 鸭血：副本追加到卡组末尾，顺序与选择顺序一致")
	check(int((r81_copied[0] as Dictionary)["id"]) == r81_before[1]
			and not str((r81_copied[0] as Dictionary)["name"]).is_empty(),
		"R81 鸭血：返回值带卡名（供界面拼结果文案）")
	check(RunState.pending_relic == -1,
		"R81 鸭血：复制完成后解除待选（不会反复触发）")

	# 只选 1 张 / 一张都不选
	RunState.deck_ids = r81_fixture.duplicate()
	var r81_b2: int = RunState.deck_ids.size()
	var r81_r1 := RunState.duplicate_deck_cards(r81_card_repo, [0])
	check(bool(r81_r1["ok"]) and RunState.deck_ids.size() == r81_b2 + 1,
		"R81 鸭血：只选 1 张 → 卡组 +1（%d → %d）" % [r81_b2, RunState.deck_ids.size()])
	var r81_r0 := RunState.duplicate_deck_cards(r81_card_repo, [])
	check(not bool(r81_r0["ok"]) and RunState.deck_ids.size() == r81_b2 + 1
			and RunState.pending_relic == -1,
		"R81 鸭血：一张都不选 → 卡组不变、待选照样解除（合法「不使用」路径）")

	# 边界：越界下标被忽略、重复下标只复制一次、超过 2 张只取前 2
	RunState.deck_ids = r81_fixture.duplicate()
	RunState.pending_relic = RunState.DUCK_BLOOD_RELIC_ID
	var r81_edge := RunState.duplicate_deck_cards(r81_card_repo,
			[0, 0, 99, -3, 1, 2, 3, 4, 5])
	check((r81_edge["copied"] as Array).size() == 2,
		"R81 鸭血 边界：越界下标忽略、同下标去重、超出 3 张也只复制 2 张（实际 %d）"
			% (r81_edge["copied"] as Array).size())
	check(RunState.deck_ids.size() == r81_fixture.size() + 2,
		"R81 鸭血 边界：卡组只 +2（%d → %d）"
			% [r81_fixture.size(), RunState.deck_ids.size()])

	# 重复获得不叠加（沿用所有道具的统一语义）
	var r81_n0: int = RunState.relics.size()
	RunState.gain_relic(RunState.DUCK_BLOOD_RELIC_ID)
	check(RunState.relics.size() == r81_n0 and RunState.pending_relic == -1,
		"R81 鸭血：已持有时重复获得被忽略（不会二次复制）")

	RunState.relics = r81_saved_relics
	RunState.deck_ids = r81_saved_deck
	RunState.pending_relic = -1

	# ================================================================
	# R82：野兔 9032「自我复制」+ 机械之心（素体 / 构装体 / 升级 / 机械核心）
	# ================================================================
	# ---- ① 攻击 → 攻击（R82 全局更名）----
	var r82_attack: CardData = repo.get_card(8002)
	check(r82_attack.card_name == "攻击" and r82_attack.traits.has("攻击")
			and not r82_attack.traits.has("射击"),
		"R82 攻击 8002：卡名与 trait 都由「攻击」改成「攻击」（旧名不再残留）")
	# 引擎不按卡名判定 → 改名的效果一个字都不该变：仍是 1 费 / 4 伤 / 需选目标。
	check(r82_attack.cost == 1 and r82_attack.target_mode == "unit"
			and r82_attack.effect_text == "对一个目标造成 4 点伤害。",
		"R82 攻击 8002：数值与效果文案未变（1 费 / 4 伤 / 选目标）—— 改名不影响规则")
	var r82_atk_e := _new_engine(_single_deck(CardData.from_dict(r82_attack.to_dict())),
			20, 20, -1, false)
	r82_atk_e.start_game()
	# 摆一个**血够厚**的敌人：判据用「血量变化 = 4」，不依赖它死不死
	# （骷髅兵 2 血会被 4 伤打死，死了 unit_at 就返回 null，判据会失效）。
	var r82_foe_card: CardData = _card(1053, "骷髅兵", "怪物", 3, 2, 1, 1, 1)
	r82_foe_card.health = 20
	var r82_target: Placement = r82_atk_e.state.place(
			CardData.from_dict(r82_foe_card.to_dict()), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	r82_atk_e.use_spell(0, Vector2i(2, 1))
	check(r82_target.health == 20 - 4,
		"R82 攻击 8002：改名前后伤害都是 4（20 → %d，引擎按 id 判定，不受改名影响）"
			% r82_target.health)

	# ---- ② 野兔：使用后手牌 +1 复制；两段寿命 ----
	var r82_repo := CardRepo.load_json()
	var r82_rabbit: CardData = CardData.from_dict(r82_repo.get_card(9032).to_dict())
	var r82_re := _new_engine(_single_deck(CardData.from_dict(r82_rabbit.to_dict())),
			20, 20, -1, false)
	r82_re.start_game()
	var r82_hand0: int = r82_re.state.hand.size()
	var r82_disc0: int = r82_re.state.discard.size()
	r82_re.state.energy = 5
	r82_re.play_from_hand(0, Vector2i(4, 1))
	check(r82_re.state.hand.size() == r82_hand0, "R82 野兔：上场本身不把手牌变多（原 %d 张）" % r82_hand0)
	# 打出的那张已离手；复制卡进手牌 → 手牌净数量与打出前**相同**（-1 打出的 +1 复制的）
	var r82_clone: CardData = r82_re.state.hand[0]
	check(r82_clone.id == 9032 and r82_clone.traits.has("自我复制"),
		"R82 野兔：手牌里多出一张带「自我复制」的野兔")
	# 关键：复制卡必须是**独立实例**，不能与打出的那张是同一个 CardData 对象
	var r82_orig: Placement = r82_re.state.unit_at(Vector2i(4, 1))
	check(r82_clone != r82_orig.card,
		"R82 野兔：复制卡是 from_dict 出的**独立实例**（不与场上那张共享对象）")
	# 手牌里的复制卡：回合结束消失，**不进弃牌区**
	r82_re.state.discard_hand()
	check(r82_re.state.hand.is_empty() and r82_re.state.discard.size() == r82_disc0,
		"R82 野兔：复制卡在手牌没打出 → 回合结束消失（弃牌区仍 %d 张，没被洗回牌库）"
			% r82_re.state.discard.size())

	# 场上那张复制卡离场 → 消失，不进弃牌区
	var r82_re2 := _new_engine(_single_deck(CardData.from_dict(r82_rabbit.to_dict())),
			20, 20, -1, false)
	r82_re2.start_game()
	r82_re2.state.energy = 5
	r82_re2.play_from_hand(0, Vector2i(4, 1))
	var r82_re2_clone: CardData = r82_re2.state.hand[0]
	r82_re2.play_from_hand(0, Vector2i(3, 1))     # 打出复制卡 → 又会再复制一张
	check(r82_re2.state.hand.size() == 1
			and r82_re2.state.hand[0].traits.has("自我复制"),
		"R82 野兔：**复制卡还能再复制**（用户口径）→ 打出它手牌里又出现一张")
	check(r82_re2.state.unit_at(Vector2i(3, 1)) != null
			and r82_re2.state.unit_at(Vector2i(4, 1)) != null,
		"R82 野兔：场上同时站着原卡与复制卡（两只）")
	var r82_disc1: int = r82_re2.state.discard.size()
	r82_re2.state.discard_hand()                  # 手牌里那张第二次复制 → 消失
	r82_re2._hit_unit(r82_re2.state.unit_at(Vector2i(3, 1)), 99, "R82 测试")
	r82_re2._destroy_dead()
	check(r82_re2.state.discard.size() == r82_disc1,
		"R82 野兔：场上的复制卡被击破 → 消失，**不进弃牌区**（弃牌区仍 %d 张）"
			% r82_re2.state.discard.size())
	check(r82_re2.state.unit_at(Vector2i(3, 1)) == null
			and r82_re2.state.unit_at(Vector2i(4, 1)) != null,
		"R82 野兔：只有复制卡被清掉，**原来那张还在场上**（消失是逐张的）")

	# 满手时打出野兔：**手牌数守恒**（-1 打出的 +1 复制的 = 0）→ 复制卡撑不爆手牌。
	# 注意别写反：打出后手牌是 9 张、**不满**，所以复制是**成功**的（净效果回到 10）。
	# 这正是想要的行为 —— 玩家不会因为自我复制而爆手。
	var r82_re3 := _new_engine(_single_deck(CardData.from_dict(r82_rabbit.to_dict())),
			20, 20, -1, false)
	r82_re3.start_game()
	while r82_re3.state.hand.size() < FieldState.HAND_LIMIT:
		r82_re3.state.hand.append(_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0))
	r82_re3.state.hand[0] = CardData.from_dict(r82_rabbit.to_dict())
	var r82_full: int = r82_re3.state.hand.size()
	r82_re3.state.energy = 5
	r82_re3.play_from_hand(0, Vector2i(4, 1))
	check(r82_re3.state.hand.size() == r82_full
			and r82_re3.state.hand.back().id == 9032,
		"R82 野兔：满手（%d）时打出 → 手牌数守恒为 %d，且复制**成功**（最后一张是复制卡）"
			% [r82_full, r82_re3.state.hand.size()])

	# ⚠️ 关键区分：**从牌库抽的**野兔被打死**要**进弃牌区（它是牌库实体），
	# 只有复制卡才消失。两条路径别混。
	var r82_re5 := _new_engine(_single_deck(CardData.from_dict(r82_rabbit.to_dict())),
			20, 20, -1, false)
	r82_re5.start_game()
	r82_re5.state.energy = 5
	r82_re5.play_from_hand(0, Vector2i(4, 1))     # 打出的是**牌库那张** → 又生成 1 张复制
	var r82_orig5: Placement = r82_re5.state.unit_at(Vector2i(4, 1))
	r82_re5.state.discard_hand()                    # 手牌里那张复制 → 消失
	var r82_d5: int = r82_re5.state.discard.size()
	r82_re5._hit_unit(r82_orig5, 99, "R82 测试")
	r82_re5._destroy_dead()
	check(r82_re5.state.discard.size() == r82_d5 + 1
			and r82_re5.state.discard.back().id == 9032,
		"R82 野兔：从牌库抽的那张被打死 → **进弃牌区**（只有复制卡才消失，两条路径不混）")

	# 别的卡不该被这个机制影响（守住「按 trait 判定」这条口径）
	var r82_re4 := _new_engine(_single_deck(_card(8003, "树人", "盟友", 3, 3, 8, 1, 1)),
			20, 20, -1, false)
	r82_re4.start_game()
	var r82_h4: int = r82_re4.state.hand.size()
	r82_re4.state.energy = 5
	r82_re4.play_from_hand(0, Vector2i(4, 1))
	check(r82_re4.state.hand.size() == r82_h4 - 1,
		"R82 野兔：普通盟友（树人）不受「自我复制」影响（手牌正常 -1）")

	# ---- ③ 素体 / 构装体 / 升级：卡面数据 ----
	var r82_proto: CardData = r82_repo.get_card(GameEngine.PROTO_ID)
	var r82_con: CardData = r82_repo.get_card(GameEngine.CONSTRUCT_ID)
	var r82_up: CardData = r82_repo.get_card(GameEngine.UPGRADE_ID)
	check(r82_proto.cost == 0 and r82_proto.power == 1 and r82_proto.health == 1
			and r82_proto.attack_range == 1 and r82_proto.move_speed == 1,
		"R82 素体：0 费 1/1/1/1（攻程 1 移速 1）")
	check(r82_proto.traits.has("留手") and r82_proto.traits.has("素体"),
		"R82 素体：带「留手」（回合结束不弃）与「素体」（被改造时额外 +1 血）")
	check(r82_con.cost == 3 and r82_con.power == 3 and r82_con.health == 8
			and r82_con.attack_range == 1 and r82_con.move_speed == 1,
		"R82 构装体：3 费 3/8/1/1")
	check(r82_up.kind == "技能" and r82_up.cost == 2 and r82_up.target_mode == "unit",
		"R82 升级：2 费技能，目标是单位（选一个盟友或工事改造）")
	check(r82_proto.card_class == PlayerClass.MECH
			and r82_con.card_class == PlayerClass.MECH
			and r82_up.card_class == PlayerClass.MECH,
		"R82 三张卡的 class 都是「机械之心」（奖励池按角色过滤时归属正确）")

	# 素体的「留手」：回合结束不弃
	var r82_pe := _new_engine(_single_deck(CardData.from_dict(r82_proto.to_dict())),
			20, 20, -1, false)
	r82_pe.start_game()
	r82_pe.state.hand = [CardData.from_dict(r82_proto.to_dict())]
	var r82_pd0: int = r82_pe.state.discard.size()
	r82_pe.state.discard_hand()
	check(r82_pe.state.hand.size() == 1 and r82_pe.state.discard.size() == r82_pd0,
		"R82 素体：回合结束**不会被丢弃**（仍在手牌，弃牌区没多）")

	# ---- ④ 升级：改造盟友 / 工事 → +2 攻 +8 血；素体额外 +1 ----
	var r82_ue := _new_engine(_single_deck(CardData.from_dict(r82_up.to_dict())),
			20, 20, -1, false)
	r82_ue.start_game()
	var r82_u_farmer: Placement = r82_ue.state.place(
			_card(8003, "树人", "盟友", 3, 3, 8, 1, 1), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r82_ue.state.hand = [CardData.from_dict(r82_up.to_dict())]
	r82_ue.state.energy = 5
	r82_ue.use_spell(0, Vector2i(4, 1))
	check(r82_u_farmer.effective_power() == 3 + GameEngine.UPGRADE_ATK
			and r82_u_farmer.health == 8 + GameEngine.UPGRADE_HP,
		"R82 升级：树人 3/8 → %d/%d（+%d 攻 / +%d 血）"
			% [r82_u_farmer.effective_power(), r82_u_farmer.health,
				GameEngine.UPGRADE_ATK, GameEngine.UPGRADE_HP])
	# 工事也能改造
	var r82_u_fence: Placement = r82_ue.state.place(
			_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0), Vector2i(3, 1), GameEngine.SIDE_SELF)
	r82_ue.state.hand = [CardData.from_dict(r82_up.to_dict())]
	r82_ue.state.energy = 5
	r82_ue.use_spell(0, Vector2i(3, 1))
	check(r82_u_fence.health == 6 + GameEngine.UPGRADE_HP,
		"R82 升级：工事也能被改造（木栅栏 6 → %d 血）" % r82_u_fence.health)
	# 素体被改造 → 额外 +1（+8+1 = 9）
	var r82_u_proto: Placement = r82_ue.state.place(
			CardData.from_dict(r82_proto.to_dict()), Vector2i(2, 1), GameEngine.SIDE_SELF)
	r82_ue.state.hand = [CardData.from_dict(r82_up.to_dict())]
	r82_ue.state.energy = 5
	r82_ue.use_spell(0, Vector2i(2, 1))
	# R84：素体的「改造额外 +1 血」已从引擎硬编码搬到**卡面字段** upgrade_hp_bonus
	check(r82_u_proto.health == 1 + GameEngine.UPGRADE_HP
			+ r82_proto.upgrade_hp_bonus,
		"R82/R84 升级：改造素体额外 +1 血（1 → %d = +%d + 卡面 %d）"
			% [r82_u_proto.health, GameEngine.UPGRADE_HP, r82_proto.upgrade_hp_bonus])
	# 敌方单位不能改造
	var r82_u_foe: Placement = r82_ue.state.place(
			_card(1053, "骷髅兵", "怪物", 3, 2, 1, 1, 1), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	r82_ue.state.hand = [CardData.from_dict(r82_up.to_dict())]
	r82_ue.state.energy = 5
	var r82_foe_hp0: int = r82_u_foe.health
	r82_ue.use_spell(0, Vector2i(1, 1))
	check(r82_u_foe.health == r82_foe_hp0 and r82_u_foe.upgrade_atk == 0,
		"R82 升级：不能改造**敌方**单位（骷髅兵仍是 %d 血 / 0 加攻）" % r82_u_foe.health)

	# 加成可叠加，且**离场还原**（不烤进 CardData）
	r82_ue.state.hand = [CardData.from_dict(r82_up.to_dict())]
	r82_ue.state.energy = 5
	r82_ue.use_spell(0, Vector2i(4, 1))
	check(r82_u_farmer.effective_power() == 3 + GameEngine.UPGRADE_ATK * 2
			and r82_u_farmer.health == 8 + GameEngine.UPGRADE_HP * 2,
		"R82 升级：可重复叠加（第二次后 %d 攻 / %d 血）"
			% [r82_u_farmer.effective_power(), r82_u_farmer.health])
	r82_ue._hit_unit(r82_u_farmer, 999, "R82 测试")
	r82_ue._destroy_dead()
	var r82_left: CardData = null
	for d in r82_ue.state.discard:
		if d.id == 8003:
			r82_left = d
			break
	check(r82_left != null and r82_left.health == 8 and r82_left.power == 3,
		"R82 升级 离场还原：被击破后进弃牌区的那张树人恢复 3/8（实际 %s/%s）"
			% [str(r82_left.power) if r82_left != null else "?",
				str(r82_left.health) if r82_left != null else "?"])
	# 还原必须双向：离场还原后，那张卡再上场不该带着旧的改造加成
	var r82_redo := r82_ue.state.place(CardData.from_dict(r82_left.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r82_redo.effective_power() == 3 and r82_redo.health == 8,
		"R82 升级 离场还原：还原后那张再上场仍是 3/8（实际 %d/%d）"
			% [r82_redo.effective_power(), r82_redo.health])
	# 离场还原不能污染卡库（最关键的一条：from_dict 只复制「壳」）
	var r82_lib_farmer: CardData = r82_repo.get_card(8003)
	check(r82_lib_farmer.power == 3 and r82_lib_farmer.health == 8,
		"R82 升级：**没有污染卡库**里的树人（仍 3/%d，不是 3/%d）"
			% [r82_lib_farmer.health, 8 + GameEngine.UPGRADE_HP])

	# ---- ⑤ 机械之心角色：卡组构成 + 初始道具 ----
	var r82_mech_deck: Array[int] = PlayerClass.start_deck_ids(PlayerClass.MECH)
	var r82_m_count := {}
	for mid in r82_mech_deck:
		r82_m_count[mid] = int(r82_m_count.get(mid, 0)) + 1
	check(r82_mech_deck.size() == 13
			and int(r82_m_count.get(8001, 0)) == 5 and int(r82_m_count.get(8002, 0)) == 5
			and int(r82_m_count.get(8026, 0)) == 2 and int(r82_m_count.get(8027, 0)) == 1,
		"R82 机械之心卡组 = 13 张：攻击×5 + 木栅栏×5 + 构装体×2 + 升级×1（实际 %d 张）"
			% r82_mech_deck.size())
	check(not r82_mech_deck.has(8003) and not r82_mech_deck.has(8005),
		"R82 机械之心卡组**不含**「基础盟友」（树人 / 幽影）—— 位置由构装体占掉")
	check(not PlayerClass.has_base_ally(PlayerClass.MECH)
			and PlayerClass.has_base_ally(PlayerClass.DRUID)
			and PlayerClass.has_base_ally(PlayerClass.ROGUE),
		"R82 has_base_ally：机械之心 = false，另两个角色 = true")
	# 另两个角色的卡组不受影响（回归护栏）
	check(PlayerClass.start_deck_ids(PlayerClass.DRUID).size() == 13
			and PlayerClass.start_deck_ids(PlayerClass.ROGUE).size() == 13,
		"R82 机械之心：不影响另两个角色的卡组（森林精魄 13 / 暗影刺客 13）")

	# 初始道具「机械核心」6025：游戏开始时手牌 +2 张素体
	var r82_rp := RelicRepo.load_json()
	var r82_core: RelicData = r82_rp.get_relic(6025)
	check(r82_core != null and r82_core.relic_name == "机械核心"
			and r82_core.source == RelicData.SRC_CLASS
			and r82_core.source_color() == Color("4caf50"),
		"R82 机械核心 6025：角色赠品道具（绿）—— 与 6022 / 6023 同一池")
	check(r82_rp.class_ids().has(6025)
			and not r82_rp.reward_ids().has(6025)
			and not r82_rp.initial_ids().has(6025),
		"R82 机械核心：只在角色赠品池，不进奖励池 / 初始池")
	check(PlayerClass.relic_of(PlayerClass.MECH) == 6025,
		"R82 机械之心的初始道具 = 6025 机械核心")
	var r82_ce := _new_engine(_single_deck(CardData.from_dict(r82_con.to_dict())),
			20, 20, -1, false)
	r82_ce.self_relics = [6025]
	r82_ce.start_game()
	r82_ce.apply_battle_start_relics(r82_repo)
	var r82_proto_n: int = r82_ce.state.hand.filter(
			func(c: CardData): return c.id == GameEngine.PROTO_ID).size()
	check(r82_proto_n == 2, "R82 机械核心：游戏开始时手牌 +2 张素体（实际 %d）" % r82_proto_n)
	# 没戴这件道具 → 一张也没有
	var r82_ce2 := _new_engine(_single_deck(CardData.from_dict(r82_con.to_dict())),
			20, 20, -1, false)
	r82_ce2.start_game()
	r82_ce2.apply_battle_start_relics(r82_repo)
	check(r82_ce2.state.hand.filter(
			func(c: CardData): return c.id == GameEngine.PROTO_ID).is_empty(),
		"R82 机械核心：没持有时不发素体")
	# 开场发的素体带「留手」→ 回合结束不会被弃掉（否则白给）
	r82_ce.state.hand = r82_ce.state.hand.filter(
			func(c: CardData): return c.id == GameEngine.PROTO_ID)
	r82_ce.state.discard_hand()
	check(r82_ce.state.hand.size() == 2,
		"R82 机械核心：开场的 2 张素体回合结束仍留在手里（实际 %d）" % r82_ce.state.hand.size())

	# ---- ⑥ 角色选择流程：机械之心能正常开局 ----
	var r82_saved_cls: String = RunState.player_class
	var r82_saved_deck2: Array[int] = RunState.deck_ids.duplicate()
	var r82_saved_rel: Array[int] = RunState.relics.duplicate()
	var r82_rng := RandomNumberGenerator.new()
	r82_rng.seed = 20261005
	RunState.start_run(RogueMap.generate(r82_rng, GameLayers.LAYER_DEFAULT),
			GameLayers.LAYER_DEFAULT, PlayerClass.MECH)
	check(RunState.player_class == PlayerClass.MECH
			and RunState.has_relic(6025)
			and RunState.deck_ids == PlayerClass.start_deck_ids(PlayerClass.MECH),
		"R82 开局：选机械之心 → 拿到 6025 + 那 13 张卡组（卡组 %d 张 / 道具 %s）"
			% [RunState.deck_ids.size(), str(RunState.relics)])
	# 机械之心的奖励池只含自己的卡（+ 通用卡）
	var r82_pool: Array[CardData] = r82_repo.reward_pool_for(PlayerClass.MECH)
	var r82_pool_bad: Array = []
	for pc in r82_pool:
		if pc.card_class != "" and pc.card_class != PlayerClass.MECH:
			r82_pool_bad.append(pc.card_name)
	check(r82_pool_bad.is_empty(),
		"R82 机械之心奖励池 %d 张里没有别的角色的卡（异常 %s）"
			% [r82_pool.size(), str(r82_pool_bad)])
	RunState.player_class = r82_saved_cls
	RunState.deck_ids = r82_saved_deck2
	RunState.relics = r82_saved_rel

	# ================================================================
	# R83：场地卡「清泉」（8028）—— 场地的**第二个机制类别：持续型**
	# ================================================================
	var r83_repo := CardRepo.load_json()
	var r83_fp: CardData = r83_repo.get_card(GameEngine.FOUNTAIN_ID)
	# ---- ① 卡面数据 ----
	check(r83_fp != null and r83_fp.card_name == "清泉" and r83_fp.kind == "场地"
			and r83_fp.cost == 1 and r83_fp.rarity == 0
			and r83_fp.card_class == PlayerClass.DRUID,
		"R83 清泉 8028：森林精魄的 1 费普通场地卡")
	check(r83_fp.traits.has("持续场地"),
		"R83 清泉：带 trait「持续场地」—— 引擎**按这个 trait**把它与一次性场地分开")
	check(GameEngine.FOUNTAIN_HEAL == 2,
		"R83 清泉：回血量常量 FOUNTAIN_HEAL = 2（卡面文案与回归都对着它写）")
	# 「敌我双方都生效」→ trait 写「场地生效·双」→ 放置**无任何行限制**
	check(r83_fp.traits.has("场地生效·双")
			and GameEngine.field_aim(r83_fp) == GameEngine.FIELD_AIM_BOTH,
		"R83 清泉：trait「场地生效·双」→ field_aim = 双（敌我双方都回血）")
	var r83_all_rows := true
	for rx in FieldState.BOARD_ROWS:
		if not GameEngine.field_place_allowed(Vector2i(rx, 1), GameEngine.FIELD_AIM_BOTH):
			r83_all_rows = false
	check(r83_all_rows,
		"R83 清泉：「双」生效 → 6 行全部可放（含敌方后排 row 0，不受行限制）")
	# 反面对照：六张陷阱仍是「敌」生效，仍禁我方后排
	check(GameEngine.field_aim(r83_repo.get_card(GameEngine.TRAP_ID)) \
			== GameEngine.FIELD_AIM_ENEMY
			and not GameEngine.field_place_allowed(
					Vector2i(FieldState.BOARD_ROWS - 1, 1), GameEngine.FIELD_AIM_ENEMY),
		"R83 清泉：不影响六张陷阱 —— 仍是「敌」生效、仍禁我方后排 row 5")

	# ---- ② is_persistent_field：持续型 vs 一次性 ----
	check(GameEngine.is_persistent_field(r83_fp)
			and not GameEngine.is_persistent_field(r83_repo.get_card(GameEngine.TRAP_ID))
			and not GameEngine.is_persistent_field(r83_repo.get_card(GameEngine.PIERCE_TRAP_ID))
			and not GameEngine.is_persistent_field(null),
		"R83 is_persistent_field：只有清泉为 true，六张陷阱与 null 全为 false")

	# ---- ③ 放得下，且**能放在已有单位的格子上**（场地不是单位）----
	var r83_e := _new_engine([], 30, 30, -1, false)
	r83_e.start_game()
	var r83_ally: Placement = r83_e.state.place(
			_card(8003, "树人", "盟友", 3, 3, 8, 1, 1), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r83_e._hit_unit(r83_ally, 3, "R83 测试")     # 8 → 5
	r83_e.state.hand = [CardData.from_dict(r83_fp.to_dict())]
	r83_e.state.energy = 5
	r83_e.play_from_hand(0, Vector2i(4, 1))
	check(r83_e.state.field_at(Vector2i(4, 1)) != null
			and r83_e.state.field_owner.get(Vector2i(4, 1)) == GameEngine.SIDE_SELF,
		"R83 清泉：可以直接放在**已有单位**的格子上（场地与单位两套数据互不影响）")

	# ---- ④ 核心：在**自己回合结束**时回复 2 点 ----
	# ⚠️ 步进要小心：`end_turn()` 是**半回合**（self ⇄ opp 交替），
	# 而 `_field_aura_tick(side)` 在 `end_turn()` 里按 `current_side` 结算 ——
	# 所以「我方回合结束」= 从**我方回合**出发调**一次** end_turn（不是两次）。
	# 实测：r83_e.start_game() 后 current_side == self。
	r83_e.end_turn()      # 我方回合结束 → 清泉结算（+2），随后进入敌方回合
	check(r83_ally.health == 7,
		"R83 清泉：我方回合结束时站在上面的单位 +2 血（5 → %d）" % r83_ally.health)
	r83_e.end_turn()      # 敌方回合结束 → 敌我双方都生效，但我方单位不属于该方 → 不回
	check(r83_ally.health == 7,
		"R83 清泉：**敌方**回合结束时己方单位不回复（只在自己的回合结束回，仍 %d）"
			% r83_ally.health)
	r83_e.end_turn()      # 又是��方回合结束 → 再 +2，但**满血上限 8 封顶**（7 → 8）
	check(r83_ally.health == 8 and r83_e.state.field_at(Vector2i(4, 1)) != null,
		"R83 清泉：连续生效且**不超过卡面血量上限**（树人 8 血，7 → %d），场地仍在（不会被消耗掉）"
			% r83_ally.health)
	# 满血时不越界
	r83_e._hit_unit(r83_ally, 99, "R83 测试")
	r83_e._destroy_dead()

	# ---- ⑤ 敌方单位在**敌方回合结束**时同样回血（敌我双方都生效）----
	var r83_e2 := _new_engine([], 30, 30, -1, false)
	r83_e2.start_game()
	# ⚠️ 骷髅兵卡面只有 **1 血**（`_card(1053,…,3,2,1,…)` → cost3/power2/health1），
	# 想测回血必须先把卡面血量抬上去，否则「满血跳过」会正确地把它挡掉（我先踩了这个坑）。
	var r83_foe_card: CardData = _card(1053, "骷髅兵", "怪物", 3, 2, 1, 1, 1)
	r83_foe_card.health = 10
	var r83_foe: Placement = r83_e2.state.place(
			CardData.from_dict(r83_foe_card.to_dict()), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r83_foe.health = 4
	r83_e2.state.set_field(CardData.from_dict(r83_fp.to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	r83_e2.end_turn()      # 我方回合结束 → 敌方单位不属于我方 → 不回
	check(r83_foe.health == 4,
		"R83 清泉：我方回合结束时**敌方**单位不回复（仍 %d）" % r83_foe.health)
	r83_e2.end_turn()      # 敌方回合结束 → 敌方单位 +2
	check(r83_foe.health == 6,
		"R83 清泉：**敌方**单位在敌方回合结束时也回 2 血（4 → %d，敌我双方都生效）"
			% r83_foe.health)

	# ---- ⑥ **最关键**：敌人移动经过清泉时**不触发、不被拦停、不消失** ----
	var r83_e3 := _new_engine([], 30, 30, -1, false)
	r83_e3.start_game()
	# 速 2 的敌人（move_speed 在 **card** 上，不在 Placement 上）
	var r83_runner_card: CardData = _card(1053, "骷髅兵", "怪物", 3, 2, 1, 1, 2)
	r83_runner_card.health = 10
	var r83_passer: Placement = r83_e3.state.place(
			CardData.from_dict(r83_runner_card.to_dict()), Vector2i(2, 0),
			GameEngine.SIDE_OPPONENT)
	var r83_path: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	r83_e3.state.set_field(CardData.from_dict(r83_fp.to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(r83_e3._field_block_index(r83_path) == -1,
		"R83 清泉：_field_block_index 跳过持续型场地（返回 -1，敌人照常走过不被拦停）")
	r83_e3.move(Vector2i(2, 0), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	check(r83_e3.state.unit_at(Vector2i(2, 2)) != null
			and r83_e3.state.field_at(Vector2i(2, 1)) != null,
		"R83 清泉：敌人**移动经过**后仍走到终点 (2,2)（没被拦在 (2,1)），清泉也没被消耗")
	check(r83_passer.health == 10,
		"R83 清泉：经过时不吃任何伤害（它是治疗区不是陷阱，仍 %d 血）" % r83_passer.health)
	# 「暗影狩猎 9107」的「触发过场地」判据：清泉不算触发（trap_trig_turn 不该被写）
	check(r83_passer.trap_trig_turn == -1,
		"R83 清泉：经过**不记**「触发过场地」（暗影狩猎不会因清泉翻倍）")

	# ---- ⑦ 双重场地不能给清泉附魔（附魔永不触发 = 白花一张牌）----
	var r83_e4 := _new_engine([], 30, 30, -1, false)
	r83_e4.start_game()
	r83_e4.state.set_field(CardData.from_dict(r83_fp.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r83_e4.state.set_field(CardData.from_dict(r83_repo.get_card(GameEngine.TRAP_ID).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	var r83_res_fp: String = r83_e4._double_field_spell(GameEngine.SIDE_SELF, Vector2i(4, 1))
	check(r83_res_fp.contains("持续型场地") and not r83_e4.state.field_chains.has(Vector2i(4, 1)),
		"R83 清泉：双重场地拒绝给它附魔（%s）" % r83_res_fp)
	var r83_res_trap: String = r83_e4._double_field_spell(GameEngine.SIDE_SELF, Vector2i(3, 1))
	check(not r83_res_trap.contains("持续型")
			and int(r83_e4.state.field_chains.get(Vector2i(3, 1), 0)) == 1,
		"R83 清泉：一次性场地（爆炸陷阱）**照常**能附魔（回归护栏，chain=%d）"
			% int(r83_e4.state.field_chains.get(Vector2i(3, 1), 0)))

	# ---- ⑧ 格子空着时无事发生，场地不受影响 ----
	var r83_e5 := _new_engine([], 30, 30, -1, false)
	r83_e5.start_game()
	r83_e5.state.set_field(CardData.from_dict(r83_fp.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r83_e5.end_turn()
	r83_e5.end_turn()
	check(r83_e5.state.field_at(Vector2i(4, 1)) != null
			and r83_e5.state.discard.is_empty(),
			"R83 清泉：格子空着时无事发生（场地留着，也没有任何牌被弃）")

	# ---- ⑨ 「有单位才回血」：所以格子空着时**不刷任何日志** ----
	var r83_before_log: int = r83_e5.log.size()
	r83_e5.end_turn()
	r83_e5.end_turn()
	var r83_new_log: Array = r83_e5.log.slice(r83_before_log)
	var r83_fountain_log := 0
	for lg: String in r83_new_log:
		if lg.contains("清泉"):
			r83_fountain_log += 1
	check(r83_fountain_log == 0,
		"R83 清泉：格子空着时**不产生**任何清泉日志（%d 条）—— 结算只对站在上面的单位生效"
			% r83_fountain_log)

	# ================================================================
	# R84：陷阱牌加 `trigger` 字段（纯数据）+ 战斗骨骼 8029（改造 +1 力 +1 血）
	# ================================================================
	var r84_repo := CardRepo.load_json()
	# ---- ① 六张陷阱都有 trigger，且能按类型区分 ----
	var r84_traps: Array[int] = [GameEngine.TRAP_ID, GameEngine.FROST_TRAP_ID,
			GameEngine.FREEZE_TRAP_ID, GameEngine.POISON_TRAP_ID,
			GameEngine.PIERCE_TRAP_ID, GameEngine.MASS_TRAP_ID]
	var r84_no_trig: Array[String] = []
	var r84_trig_seen := {}
	for tid: int in r84_traps:
		var tc: CardData = r84_repo.get_card(tid)
		if tc == null or tc.trigger == "":
			r84_no_trig.append(str(tid))
		else:
			r84_trig_seen[tc.trigger] = true
	check(r84_no_trig.is_empty(),
		"R84 trigger：六张陷阱全部写了触发类型（缺 %s）"
			% ("无" if r84_no_trig.is_empty() else "、".join(r84_no_trig)))
	# 「以便后续区分」→ 至少能分出「范围 / 单体 / 控制 / 持续伤害」几类
	check(r84_trig_seen.size() >= 5 and r84_trig_seen.has("范围伤害")
			and r84_trig_seen.has("单体伤害") and r84_trig_seen.has("中毒"),
		"R84 trigger：能按类型区分（%d 种，含 范围伤害 / 单体伤害 / 中毒）"
			% r84_trig_seen.size())
	check(r84_repo.get_card(GameEngine.TRAP_ID).trigger == "范围伤害"
			and r84_repo.get_card(GameEngine.FROST_TRAP_ID).trigger.contains("禁足")
			and r84_repo.get_card(GameEngine.FREEZE_TRAP_ID).trigger.contains("冰封")
			and r84_repo.get_card(GameEngine.POISON_TRAP_ID).trigger == "中毒",
		"R84 trigger：与实际效果对得上（爆炸=范围伤害 / 冰霜=禁足 / 冻结=冰封 / 剧毒=中毒）")
	# 清泉是持续型、**刻意不写** trigger（它不走「经过触发」这条路）
	check(r84_repo.get_card(GameEngine.FOUNTAIN_ID).trigger == "",
		"R84 trigger：持续型场地「清泉」留空（空串 = 无触发，别误导成会被引爆）")
	# trigger 是**纯数据**：引擎判定仍走 trait，两者互不影响
	check(r84_repo.get_card(GameEngine.TRAP_ID).trigger != ""
			and r84_repo.get_card(GameEngine.TRAP_ID).traits.has(GameEngine.TRAP_TRAIT),
		"R84 trigger：纯数据 —— 引擎仍按 trait「爆炸陷阱」判定，trigger 不驱动规则")
	# to_dict/from_dict 往返保留 trigger（否则复制 / 联机序列化会丢）
	var r84_rt: Dictionary = r84_repo.get_card(GameEngine.POISON_TRAP_ID).to_dict()
	check(str(r84_rt.get("trigger", "")) == "中毒"
			and CardData.from_dict(r84_rt).trigger == "中毒",
		"R84 trigger：to_dict/from_dict 往返保留（复制与联机序列化不会丢）")

	# ---- ② 战斗骨骼 8029：卡面数据 ----
	var r84_bone: CardData = r84_repo.get_card(GameEngine.BATTLE_BONE_ID)
	check(r84_bone != null and r84_bone.card_name == "战斗骨骼"
			and r84_bone.kind == "盟友" and r84_bone.cost == 2
			and r84_bone.power == 2 and r84_bone.health == 7
			and r84_bone.attack_range == 1 and r84_bone.move_speed == 1
			and r84_bone.rarity == 0 and r84_bone.card_class == PlayerClass.MECH,
		"R84 战斗骨骼 8029：机械之心的 2 费普通盟友 2/7/1/1")
	check(r84_bone.upgrade_atk_bonus == 1 and r84_bone.upgrade_hp_bonus == 1,
		"R84 战斗骨骼：卡面写明改造奖励 +1 力 / +1 血（读字段，引擎不按卡名硬编码）")
	check(r84_repo.get_card(GameEngine.PROTO_ID).upgrade_hp_bonus == 1
			and r84_repo.get_card(GameEngine.PROTO_ID).upgrade_atk_bonus == 0,
		"R84 素体：改造奖励搬到卡面 = +1 血 / +0 力（原先是引擎里按 trait 硬编码的）")
	check(r84_repo.get_card(8003).upgrade_atk_bonus == 0
			and r84_repo.get_card(8003).upgrade_hp_bonus == 0,
		"R84 普通盟友（树人）：没有改造奖励字段 → 改造只吃「升级」本体的 +2/+8")

	# ---- ③ 战斗骨骼被改造的实际结算：+2/+8 之外再 +1/+1 ----
	var r84_e := _new_engine([], 30, 30, -1, false)
	r84_e.start_game()
	var r84_bp: Placement = r84_e.state.place(
			CardData.from_dict(r84_bone.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r84_e.state.hand = [CardData.from_dict(
			r84_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r84_e.state.energy = 5
	r84_e.use_spell(0, Vector2i(4, 1))
	check(r84_bp.effective_power() == 2 + GameEngine.UPGRADE_ATK + 1
			and r84_bp.health == 7 + GameEngine.UPGRADE_HP + 1,
		"R84 战斗骨骼：被改造一次 → %d 攻 / %d 血（2/7 + 升级 2/8 + 卡面 1/1）"
			% [r84_bp.effective_power(), r84_bp.health])
	# 可重复叠加，且离场还原（不烤进卡库）
	r84_e.state.hand = [CardData.from_dict(
			r84_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r84_e.state.energy = 5
	r84_e.use_spell(0, Vector2i(4, 1))
	check(r84_bp.effective_power() == 2 + (GameEngine.UPGRADE_ATK + 1) * 2
			and r84_bp.health == 7 + (GameEngine.UPGRADE_HP + 1) * 2,
		"R84 战斗骨骼：可重复叠加（第二次后 %d 攻 / %d 血）"
			% [r84_bp.effective_power(), r84_bp.health])
	r84_e._hit_unit(r84_bp, 999, "R84 测试")
	r84_e._destroy_dead()
	var r84_back: CardData = null
	for d84 in r84_e.state.discard:
		if d84.id == GameEngine.BATTLE_BONE_ID:
			r84_back = d84
	check(r84_back != null and r84_back.power == 2 and r84_back.health == 7,
		"R84 战斗骨骼：离场还原成原卡 2/7（实际 %s/%s）"
			% [str(r84_back.power) if r84_back != null else "?",
				str(r84_back.health) if r84_back != null else "?"])
	var r84_lib: CardData = r84_repo.get_card(GameEngine.BATTLE_BONE_ID)
	check(r84_lib.power == 2 and r84_lib.health == 7,
		"R84 战斗骨骼：**没有污染卡库**（仍 2/%d）" % r84_lib.health)
	# 素体的改造奖励仍生效（回归护栏：改成读字段后别把素体弄坏）
	var r84_pe := _new_engine([], 30, 30, -1, false)
	r84_pe.start_game()
	var r84_pp: Placement = r84_pe.state.place(
			CardData.from_dict(r84_repo.get_card(GameEngine.PROTO_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r84_pe.state.hand = [CardData.from_dict(
			r84_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r84_pe.state.energy = 5
	r84_pe.use_spell(0, Vector2i(4, 1))
	check(r84_pp.health == 1 + GameEngine.UPGRADE_HP + 1
			and r84_pp.effective_power() == 1 + GameEngine.UPGRADE_ATK,
		"R84 素体（回归护栏）：改造后 %d 攻 / %d 血（+1 力只来自升级本体、+1 血来自卡面）"
			% [r84_pp.effective_power(), r84_pp.health])

	# ================================================================
	# R85：「过载」（8030）—— 机械之心史诗技能：给牌库里一张盟友加「一回合行动两次」
	# ================================================================
	var r85_repo := CardRepo.load_json()
	var r85_ov: CardData = r85_repo.get_card(GameEngine.OVERLOAD_ID)
	# ---- ① 卡面数据 ----
	check(r85_ov != null and r85_ov.card_name == "过载" and r85_ov.kind == "技能"
			and r85_ov.cost == 2 and r85_ov.rarity == 2
			and r85_ov.card_class == PlayerClass.MECH
			and r85_ov.target_mode == "none",
		"R85 过载 8030：机械之心的 2 费**史诗**技能，无目标（随机选，不需要玩家指定）")
	# ⚠️ `reward_pool_for` 返回的是 Array[CardData]（卡牌数组），**不是 id 数组** ——
	#    别写 `.has(id)`，那样永远 false。
	var r85_pool: Array[CardData] = r85_repo.reward_pool_for(PlayerClass.MECH)
	var r85_in_pool := false
	for pc: CardData in r85_pool:
		if pc.id == GameEngine.OVERLOAD_ID:
			r85_in_pool = true
	check(r85_in_pool,
		"R85 过载：史诗（rarity 2）→ 进机械之心的奖励池 %d 张里（能摇到）" % r85_pool.size())
	check(GameEngine.DOUBLE_ACTION == 2,
		"R85：「一回合行动两次」的口径常量 DOUBLE_ACTION = 2（判据是 actions 字段，没有 trait）")

	# ---- ② 核心：牌库里一张普通盟友被改成双动 ----
	var r85_e := _new_engine([], 30, 30, -1, false)
	r85_e.start_game()
	# 牌库放三张普通盟友（都还没有双动）
	var r85_far1: CardData = _card(8003, "树人", "盟友", 3, 3, 8, 1, 1)
	var r85_far2: CardData = _card(8004, "熊", "盟友", 4, 3, 12, 1, 1)
	var r85_far3: CardData = _card(8006, "影子猫", "盟友", 2, 2, 4, 1, 1)
	r85_e.state.deck = [CardData.from_dict(r85_far1.to_dict()),
			CardData.from_dict(r85_far2.to_dict()),
			CardData.from_dict(r85_far3.to_dict())]
	r85_e.state.hand = [CardData.from_dict(r85_ov.to_dict())]
	r85_e.state.energy = 5
	r85_e.use_spell(0)
	var r85_up_n := 0
	for d85: CardData in r85_e.state.deck:
		if d85.actions >= GameEngine.DOUBLE_ACTION:
			r85_up_n += 1
	check(r85_up_n == 1,
		"R85 过载：牌库 3 张普通盟友里**恰好 1 张**被加上「一回合行动两次」（实际 %d）"
			% r85_up_n)
	check(r85_e.state.deck.size() == 3,
		"R85 过载：**牌库张数不变**（是「改那张」不是「抽走它」，实际 %d 张）"
			% r85_e.state.deck.size())
	# 原位替换 → 顺序不变（录像回放确定性的前提）
	check(r85_e.state.deck[0].id == 8003 and r85_e.state.deck[1].id == 8004
			and r85_e.state.deck[2].id == 8006,
		"R85 过载：**原位替换**不抽到手上（牌库顺序 8003/8004/8006 不变 → 洗牌序列不受影响）")

	# ---- ③ ⚠️ 最关键：**不能污染卡库**（卡库是共享实例）----
	var r85_lib_far: CardData = r85_repo.get_card(8003)
	check(r85_lib_far.actions == 1,
		"R85 过载：**没有污染卡库**里的树人（actions 仍 = %d，不是 2）" % r85_lib_far.actions)
	var r85_lib_bear: CardData = r85_repo.get_card(8004)
	check(r85_lib_bear.actions == 1,
		"R85 过载：卡库里的熊也没被改（actions = %d）" % r85_lib_bear.actions)
	# 被改的那张必须是**独立实例**（不是卡库那张的同一个对象）
	var r85_changed: CardData = r85_e.state.deck[0]
	var r85_which: int = 0
	for i in r85_e.state.deck.size():
		if r85_e.state.deck[i].actions >= GameEngine.DOUBLE_ACTION:
			r85_changed = r85_e.state.deck[i]
			r85_which = i
	check(r85_changed != r85_repo.get_card(r85_changed.id),
		"R85 过载：被改的那张是 **from_dict 出来的独立实例**（不与卡库共享对象）")

	# ---- ④ 改完的那张**真的能双动**（判据走 actions → acts_left）----
	var r85_board: Placement = r85_e.state.place(
			CardData.from_dict(r85_changed.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r85_board.acts_left >= 2,
		"R85 过载：把改造后的那张放上场 → acts_left = %d（真的每回合行动两次）"
			% r85_board.acts_left)

	# ---- ⑤ 已经是双动的卡**不会被重复挑中** ----
	var r85_e2 := _new_engine([], 30, 30, -1, false)
	r85_e2.start_game()
	var r85_wolf: CardData = CardData.from_dict(r85_repo.get_card(9031).to_dict())  # 自带双动
	check(r85_wolf.actions >= 2, "R85 用例前置：白狼 9031 卡面自带双动（actions=%d）"
		% r85_wolf.actions)
	r85_e2.state.deck = [r85_wolf]     # 牌库里**只有**一张双动卡 → 无候选
	r85_e2.state.hand = [CardData.from_dict(r85_ov.to_dict())]
	r85_e2.state.energy = 5
	var r85_detail: String = r85_e2.use_spell(0)
	check(r85_detail.contains("没有") and r85_e2.state.deck[0].actions >= 2,
		"R85 过载：牌库里全是双动盟友 → **效果落空**并说明原因（%s）" % r85_detail)

	# ---- ⑥ 牌库没有盟友（非盟友卡不算）→ 落空 ----
	var r85_e3 := _new_engine([], 30, 30, -1, false)
	r85_e3.start_game()
	r85_e3.state.deck = [_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0),
			_card(8002, "攻击", "技能", 1, 0, 0, 0, 0)]
	r85_e3.state.hand = [CardData.from_dict(r85_ov.to_dict())]
	r85_e3.state.energy = 5
	var r85_d3: String = r85_e3.use_spell(0)
	check(r85_d3.contains("没有"), "R85 过载：牌库里没有盟友（只有工事/技能）→ 效果落空（%s）" % r85_d3)

	# ---- ⑦ 候选只从**牌库**取：手牌 / 弃牌区里的盟友不参与 ----
	var r85_e4 := _new_engine([], 30, 30, -1, false)
	r85_e4.start_game()
	r85_e4.state.deck = [_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0)]  # 牌库没盟友
	r85_e4.state.discard = [_card(8003, "树人", "盟友", 3, 3, 8, 1, 1)]  # 弃牌区有
	r85_e4.state.hand = [CardData.from_dict(r85_ov.to_dict())]
	r85_e4.state.energy = 5
	var r85_d4: String = r85_e4.use_spell(0)
	check(r85_d4.contains("没有") and r85_e4.state.discard[0].actions == 1,
		"R85 过载：手牌/弃牌区里的盟友**不参与**候选（弃牌区那张仍是 actions=%d）"
			% r85_e4.state.discard[0].actions)

	# ================================================================
	# R86：「批量改造」（8031）+「侦察塔」（8032，0 攻工事 + 改造层数加伤）
	# ================================================================
	var r86_repo := CardRepo.load_json()
	# ---- ① 批量改造：卡面 ----
	var r86_bu: CardData = r86_repo.get_card(GameEngine.BATCH_UPGRADE_ID)
	check(r86_bu != null and r86_bu.card_name == "批量改造" and r86_bu.kind == "技能"
			and r86_bu.cost == 1 and r86_bu.rarity == 0
			and r86_bu.card_class == PlayerClass.MECH
			and r86_bu.target_mode == "none",
		"R86 批量改造 8031：机械之心的 1 费普通技能，无目标（一次改全部手牌）")
	check(GameEngine.BATCH_UPGRADE_HP == 1,
		"R86 批量改造：每张 +1 生命的常量 BATCH_UPGRADE_HP = 1")
	# ---- ② 手牌里所有盟友和工事 +1 血，其它卡不动 ----
	var r86_e := _new_engine([], 30, 30, -1, false)
	r86_e.start_game()
	# 手牌：盟友 / 工事 / 技能 各一张
	r86_e.state.hand = [
		_card(8003, "树人", "盟友", 3, 3, 8, 1, 1),          # 盟友 8 血
		_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0),        # 工事 6 血
		_card(8002, "攻击", "技能", 1, 0, 0, 0, 0),          # 技能：不该被动
		CardData.from_dict(r86_bu.to_dict())]                # 批量改造本身
	r86_e.state.energy = 5
	var r86_d: String = r86_e.use_spell(3)
	check(r86_e.state.hand[0].health == 9,
		"R86 批量改造：手牌里的**盟友** +1 生命（树人 8 → %d）" % r86_e.state.hand[0].health)
	check(r86_e.state.hand[1].health == 7,
		"R86 批量改造：手牌里的**工事**也 +1 生命（木栅栏 6 → %d）"
			% r86_e.state.hand[1].health)
	check(r86_e.state.hand[2].health == 0,
		"R86 批量改造：**技能卡不受影响**（攻击仍是 %d 血）" % r86_e.state.hand[2].health)
	check(r86_d.contains("2"), "R86 批量改造：结果文案写明改了几张（%s）" % r86_d)
	# ⚠️ **不能污染卡库**（build_deck 给的是卡库共享实例）
	check(r86_repo.get_card(8003).health == 8 and r86_repo.get_card(8001).health == 6,
		"R86 批量改造：**没有污染卡库**（树人仍 8 血 / 木栅栏仍 6 血，实际 %d / %d）"
			% [r86_repo.get_card(8003).health, r86_repo.get_card(8001).health])
	check(r86_e.state.hand[0] != r86_repo.get_card(8003),
		"R86 批量改造：被改的是 from_dict 出的**独立实例**（不与卡库共享对象）")
	# 手牌里没有盟友 / 工事 → 落空
	var r86_e2 := _new_engine([], 30, 30, -1, false)
	r86_e2.start_game()
	r86_e2.state.hand = [_card(8002, "攻击", "技能", 1, 0, 0, 0, 0),
			CardData.from_dict(r86_bu.to_dict())]
	r86_e2.state.energy = 5
	var r86_d2: String = r86_e2.use_spell(1)
	check(r86_d2.contains("没有"), "R86 批量改造：手牌里只有技能卡 → 效果落空（%s）" % r86_d2)
	# 「整场战斗内一直有效」：回合结束弃回牌库、再抽到仍然带 +1
	var r86_e3 := _new_engine([], 30, 30, -1, false)
	r86_e3.start_game()
	r86_e3.state.hand = [_card(8003, "树人", "盟友", 3, 3, 8, 1, 1),
			CardData.from_dict(r86_bu.to_dict())]
	r86_e3.state.energy = 5
	r86_e3.use_spell(1)
	r86_e3.state.discard_hand()                     # 树人弃回牌库（带 +1 的那份副本）
	var r86_in_disc := false
	for d86: CardData in r86_e3.state.discard:
		if d86.id == 8003 and d86.health == 9:
			r86_in_disc = true
	check(r86_in_disc,
		"R86 批量改造：回合结束弃回牌库后**仍然带 +1 血**（弃牌区里有张 9 血的树人）")
	# 抽回手上 → 上场后血量上限也是 9
	r86_e3.state.deck = r86_e3.state.discard.duplicate()
	r86_e3.state.discard.clear()
	var r86_drawn: CardData = r86_e3.state.draw()
	check(r86_drawn != null and r86_drawn.health == 9,
		"R86 批量改造：再抽到时仍是 9 血（%s）"
			% (str(r86_drawn.health) if r86_drawn != null else "null"))
	var r86_pl: Placement = r86_e3.state.place(r86_drawn, Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(r86_pl.card.health == 9 and r86_pl.health == 9,
		"R86 批量改造：它上场时血量上限 9（实际 %d / %d）" % [r86_pl.card.health, r86_pl.health])

	# ---- ③ 侦察塔：卡面 ----
	var r86_tw: CardData = r86_repo.get_card(GameEngine.SCOUT_TOWER_ID)
	check(r86_tw != null and r86_tw.card_name == "侦察塔" and r86_tw.kind == "工事"
			and r86_tw.cost == 3 and r86_tw.power == 0 and r86_tw.health == 12
			and r86_tw.attack_range == 2 and r86_tw.rarity == 0
			and r86_tw.card_class == PlayerClass.MECH,
		"R86 侦察塔 8032：机械之心的 3 费普通工事，0 攻 / 12 血 / 攻程 2")
	check(r86_tw.traits.has(GameEngine.STACK_DAMAGE_TRAIT),
		"R86 侦察塔：带 trait「改造层数」—— 每层改造 +1 攻击伤害（引擎按这个 trait 判定）")
	# ---- ④ 0 攻工事**能攻击**（用户口径：只有 0 攻程不能攻击）----
	var r86_e4 := _new_engine([], 30, 30, -1, false)
	r86_e4.start_game()
	var r86_tp: Placement = r86_e4.state.place(
			CardData.from_dict(r86_tw.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	# 敌人在攻程 2 内（曼哈顿 (4,1)→(2,1) = 2）
	var r86_foe: Placement = r86_e4.state.place(
			_card(1053, "骷髅兵", "怪物", 3, 2, 1, 1, 1), Vector2i(2, 1),
			GameEngine.SIDE_OPPONENT)
	r86_foe.card = CardData.from_dict(r86_foe.card.to_dict())
	r86_foe.card.health = 30
	r86_foe.health = 30
	var r86_tg: Array[Vector2i] = r86_e4.legal_attack_targets(Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(r86_tg.has(Vector2i(2, 1)),
		"R86 侦察塔：**0 攻也能攻击**（攻程 2 内的 (2,1) 是合法目标）")
	# 没改造 → 攻击 0 伤
	r86_e4.attack(Vector2i(4, 1), Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(r86_foe.health == 30,
		"R86 侦察塔：0 层改造时攻击造成 0 伤（还是 %d 血）" % r86_foe.health)
	# ---- ⑤ 每层改造 +1 伤（叠在改造的 +2 力量之上）----
	r86_e4.state.hand = [CardData.from_dict(
			r86_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r86_e4.state.energy = 5
	r86_e4.use_spell(0, Vector2i(4, 1))
	check(r86_tp.upgrade_stacks == 1
			and r86_tp.effective_power() == 0 + GameEngine.UPGRADE_ATK + 1,
		"R86 侦察塔：改造 1 次 → %d 层 / 攻 %d（0 + 改造 2 + 层数 1）"
			% [r86_tp.upgrade_stacks, r86_tp.effective_power()])
	# ⚠️ 上一次 attack 已经把侦察塔**横置**了（`attack()` 结尾会 _tap），
	#    不重置行动的话这次 attack 会被 `attacker.tapped` 直接拦下（我先踩了这个坑）。
	r86_e4.state.reset_units(GameEngine.SIDE_SELF)
	r86_e4.attack(Vector2i(4, 1), Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(r86_foe.health == 27,
		"R86 侦察塔：1 层改造后攻击造成 **3** 伤（30 → %d = 改造 2 + 层数 1）"
			% r86_foe.health)
	# 再改一次 → 2 层 / 攻 6（0 + 4 + 2）
	r86_e4.state.hand = [CardData.from_dict(
			r86_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r86_e4.state.energy = 5
	r86_e4.use_spell(0, Vector2i(4, 1))
	check(r86_tp.upgrade_stacks == 2
			and r86_tp.effective_power() == 0 + GameEngine.UPGRADE_ATK * 2 + 2,
		"R86 侦察塔：改造 2 次 → %d 层 / 攻 %d（0 + 改造 4 + 层数 2）"
			% [r86_tp.upgrade_stacks, r86_tp.effective_power()])

	# ---- ⑥ ⚠️ 层数**只对带该 trait 的卡生效**（否则 0 攻工事改造几次就能自己打人）----
	var r86_e5 := _new_engine([], 30, 30, -1, false)
	r86_e5.start_game()
	var r86_fence: Placement = r86_e5.state.place(
			_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r86_farmer: Placement = r86_e5.state.place(
			_card(8003, "树人", "盟友", 3, 3, 8, 1, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
	r86_e5.state.hand = [CardData.from_dict(
			r86_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r86_e5.state.energy = 5
	r86_e5.use_spell(0, Vector2i(4, 1))
	r86_e5.state.hand = [CardData.from_dict(
			r86_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r86_e5.state.energy = 5
	r86_e5.use_spell(0, Vector2i(4, 1))
	check(r86_fence.upgrade_stacks == 2
			and r86_fence.effective_power() == 0 + GameEngine.UPGRADE_ATK * 2,
		"R86 层数只对「改造层数」trait 生效：木栅栏改了 2 次 → 有 %d 层，但攻仍只有 %d（不加层）"
			% [r86_fence.upgrade_stacks, r86_fence.effective_power()])
	r86_e5.state.hand = [CardData.from_dict(
			r86_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r86_e5.state.energy = 5
	r86_e5.use_spell(0, Vector2i(3, 1))
	check(r86_farmer.upgrade_stacks == 1
			and r86_farmer.effective_power() == 3 + GameEngine.UPGRADE_ATK,
		"R86 层数只对「改造层数」trait 生效：树人改了 1 次 → %d 层，攻 %d（不加层）"
			% [r86_farmer.upgrade_stacks, r86_farmer.effective_power()])
	# ---- ⑦ 层数离场还原（不留在卡上）----
	r86_e5._hit_unit(r86_tp, 999, "R86 测试")
	r86_e5._destroy_dead()
	check(r86_tp.upgrade_stacks == 2,
		"R86 层数是「只在场上有效」的（离场不写回卡：Placement 上仍是 %d 层）"
			% r86_tp.upgrade_stacks)
	var r86_tw_lib: CardData = r86_repo.get_card(GameEngine.SCOUT_TOWER_ID)
	check(r86_tw_lib.power == 0 and r86_tw_lib.health == 12,
		"R86 侦察塔：离场后**没有污染卡库**（仍 0 攻 / %d 血）" % r86_tw_lib.health)

	# ================================================================
	# R87：能量屏障 8033 / 堡垒 8034 / 自我修复 8035（都是「机械之心」= 机械师）
	# ================================================================
	var r87_repo := CardRepo.load_json()
	# ---- ① 三张卡的卡面数据 ----
	var r87_bar: CardData = r87_repo.get_card(GameEngine.BARRIER_ID)
	var r87_fort: CardData = r87_repo.get_card(GameEngine.FORT_ID)
	var r87_rep: CardData = r87_repo.get_card(GameEngine.SELF_REPAIR_ID)
	check(r87_bar != null and r87_bar.card_name == "能量屏障" and r87_bar.kind == "技能"
			and r87_bar.cost == 2 and r87_bar.rarity == 1
			and r87_bar.card_class == PlayerClass.MECH,
		"R87 能量屏障 8033：机械之心的 2 费**稀有**技能")
	check(r87_fort != null and r87_fort.card_name == "堡垒" and r87_fort.kind == "工事"
			and r87_fort.cost == 3 and r87_fort.power == 3 and r87_fort.health == 10
			and r87_fort.attack_range == 1 and r87_fort.rarity == 1
			and r87_fort.card_class == PlayerClass.MECH,
		"R87 堡垒 8034：机械之心的 3 费**稀有**工事，3 攻 / 10 血 / 攻程 1")
	check(r87_fort.traits.has(GameEngine.STACK_HP_TRAIT),
		"R87 堡垒：带 trait「改造生命层」（与侦察塔的「改造层数」是两套，别混）")
	check(r87_rep != null and r87_rep.card_name == "自我修复" and r87_rep.kind == "技能"
			and r87_rep.cost == 1 and r87_rep.rarity == 1
			and r87_rep.target_mode == "unit"
			and r87_rep.card_class == PlayerClass.MECH,
		"R87 自我修复 8035：机械之心的 1 费**稀有**技能，目标是单位（改造场上一个盟友）")
	check(GameEngine.SELF_REPAIR_HP == 2 and GameEngine.SELF_REPAIR_REGEN == 4
			and GameEngine.STACK_HP_PER == 3,
		"R87 数值常量：自我修复 +2 血 / 每回合回 4；堡垒每层 +3 血")

	# ---- ② 能量屏障：给抽牌堆一张卡加护盾，上场时首次受伤免掉 ----
	var r87_e := _new_engine([], 30, 30, -1, false)
	r87_e.start_game()
	var r87_farmer_card: CardData = _card(8003, "树人", "盟友", 3, 3, 8, 1, 1)
	r87_e.state.deck = [CardData.from_dict(r87_farmer_card.to_dict())]
	r87_e.state.hand = [CardData.from_dict(r87_bar.to_dict())]
	r87_e.state.energy = 5
	var r87_bd: String = r87_e.use_spell(0)
	check(r87_bd.contains("获得能量屏障") and r87_e.state.deck.size() == 1,
		"R87 能量屏障：抽牌堆里的树人被加上护盾（%s），牌库张数不变" % r87_bd)
	check(r87_e.state.deck[0].traits.has(GameEngine.BARRIER_TRAIT),
		"R87 能量屏障：牌库那张带上 trait「能量屏障」")
	check(r87_e.state.deck[0] != r87_repo.get_card(8003),
		"R87 能量屏障：改的是 from_dict 出的**独立实例**（不与卡库共享对象）")
	# ⚠️ 不污染卡库
	var r87_lib_farmer: CardData = r87_repo.get_card(8003)
	check(not r87_lib_farmer.traits.has(GameEngine.BARRIER_TRAIT),
		"R87 能量屏障：**没有污染卡库**里的树人（不该带能量屏障 trait）")
	# 上场 → 获得护盾；第一次受伤免掉，第二次正常扣
	var r87_pl: Placement = r87_e.state.place(
			CardData.from_dict(r87_e.state.deck[0].to_dict()), Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(r87_pl.first_hit_shield,
		"R87 能量屏障：带该 trait 的单位**上场即获得**护盾（place() 里初始化）")
	var r87_got1: int = r87_e._hit_unit(r87_pl, 3, "R87 测试")
	check(r87_got1 == 0 and r87_pl.health == 8 and not r87_pl.first_hit_shield,
		"R87 能量屏障：**第一次**受伤 3 伤 → 实际扣 0（%d）、血量不变 8、护盾消失"
			% r87_got1)
	r87_e._hit_unit(r87_pl, 3, "R87 测试")
	check(r87_pl.health == 5,
		"R87 能量屏障：护盾用掉后**恢复正常**（8 → %d）" % r87_pl.health)
	# 没有该 trait 的单位上场**不该**有护盾（回归护栏）
	var r87_plain: Placement = r87_e.state.place(
			_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0), Vector2i(3, 1), GameEngine.SIDE_SELF)
	check(not r87_plain.first_hit_shield,
		"R87 能量屏障：普通工事上场**没有**护盾（trait 门控生效）")
	# 无候选 → 落空（抽牌堆里那张**已经**带护盾了，不该被重复挑中）
	var r87_e2 := _new_engine([], 30, 30, -1, false)
	r87_e2.start_game()
	r87_e2.state.deck = [CardData.from_dict(r87_farmer_card.to_dict())]
	r87_e2.state.deck[0].traits = (r87_e2.state.deck[0].traits as Array).duplicate()
	r87_e2.state.deck[0].traits.append(GameEngine.BARRIER_TRAIT)   # 已经有护盾了
	r87_e2.state.hand = [CardData.from_dict(r87_bar.to_dict())]
	r87_e2.state.energy = 5
	var r87_bd2: String = r87_e2.use_spell(0)
	check(r87_bd2.contains("没有"),
		"R87 能量屏障：抽牌堆里已有带护盾的卡 → **不重复挑中**、效果落空（%s）" % r87_bd2)

	# ---- ③ 堡垒：每层改造 +3 生命（叠在改造的 +8 之上），离场还原 ----
	var r87_e3 := _new_engine([], 30, 30, -1, false)
	r87_e3.start_game()
	var r87_fp: Placement = r87_e3.state.place(
			CardData.from_dict(r87_fort.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r87_e3.state.hand = [CardData.from_dict(
			r87_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r87_e3.state.energy = 5
	r87_e3.use_spell(0, Vector2i(4, 1))
	check(r87_fp.upgrade_stacks == 1
			and r87_fp.health == 10 + GameEngine.UPGRADE_HP + GameEngine.STACK_HP_PER,
		"R87 堡垒：改造 1 次 → %d 层 / %d 血（10 + 改造 8 + 每层 3）"
			% [r87_fp.upgrade_stacks, r87_fp.health])
	r87_e3.state.hand = [CardData.from_dict(
			r87_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r87_e3.state.energy = 5
	r87_e3.use_spell(0, Vector2i(4, 1))
	check(r87_fp.upgrade_stacks == 2
			and r87_fp.health == 10 + (GameEngine.UPGRADE_HP + GameEngine.STACK_HP_PER) * 2,
		"R87 堡垒：改造 2 次 → %d 层 / %d 血（可叠加）"
			% [r87_fp.upgrade_stacks, r87_fp.health])
	# ⚠️ 生命层数**不进攻击力**（那是侦察塔的活）—— 堡垒有 3 点基础攻，别按 0 攻算
	check(r87_fp.effective_power() == 3 + GameEngine.UPGRADE_ATK * 2,
		"R87 堡垒：生命层数**不加攻**（攻 %d = 卡面 3 + 改造 2×2，不含层数）"
			% r87_fp.effective_power())
	r87_e3._hit_unit(r87_fp, 999, "R87 测试")
	r87_e3._destroy_dead()
	var r87_fback: CardData = null
	for d87 in r87_e3.state.discard:
		if d87.id == GameEngine.FORT_ID:
			r87_fback = d87
	check(r87_fback != null and r87_fback.health == 10 and r87_fback.power == 3,
		"R87 堡垒：离场还原成原卡 3/10（实际 %s/%s）"
			% [str(r87_fback.power) if r87_fback != null else "?",
				str(r87_fback.health) if r87_fback != null else "?"])
	# 侦察塔那边不受影响（回归护栏：生命层 ≠ 攻层）
	var r87_e4 := _new_engine([], 30, 30, -1, false)
	r87_e4.start_game()
	var r87_tp: Placement = r87_e4.state.place(
			CardData.from_dict(r87_repo.get_card(GameEngine.SCOUT_TOWER_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r87_e4.state.hand = [CardData.from_dict(
			r87_repo.get_card(GameEngine.UPGRADE_ID).to_dict())]
	r87_e4.state.energy = 5
	r87_e4.use_spell(0, Vector2i(4, 1))
	check(r87_tp.health == 12 + GameEngine.UPGRADE_HP,
		"R87 侦察塔（回归护栏）：改造 1 次只 +8 血（%d），**不吃**堡垒的每层 +3"
			% r87_tp.health)

	# ---- ④ 自我修复：+2 最大生命 + 每回合结束回 4（离场还原）----
	var r87_e5 := _new_engine([], 30, 30, -1, false)
	r87_e5.start_game()
	var r87_rp: Placement = r87_e5.state.place(
			CardData.from_dict(r87_farmer_card.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r87_e5.state.hand = [CardData.from_dict(r87_rep.to_dict())]
	r87_e5.state.energy = 5
	var r87_rd: String = r87_e5.use_spell(0, Vector2i(4, 1))
	check(r87_rp.regen == GameEngine.SELF_REPAIR_REGEN
			and r87_rp.card.health == 8 + GameEngine.SELF_REPAIR_HP
			and r87_rp.health == 10,
		"R87 自我修复：树人 → 每回合回 %d、最大生命 %d（当前 %d）"
			% [r87_rp.regen, r87_rp.card.health, r87_rp.health])
	# 每回合结束真的回血
	r87_e5._hit_unit(r87_rp, 5, "R87 测试")   # 10 → 5
	check(r87_rp.health == 5, "R87 自我修复：先打掉 5 血（%d）" % r87_rp.health)
	r87_e5.end_turn()                          # 我方回合结束 → _regen_tick
	check(r87_rp.health == 9,
		"R87 自我修复：我方回合结束回 4 血（5 → %d）" % r87_rp.health)
	# 敌方回合结束**不回**（只结算自己回合）
	r87_e5.end_turn()
	check(r87_rp.health == 9,
		"R87 自我修复：敌方回合结束**不回血**（仍 %d）" % r87_rp.health)
	# 满血时跳过
	r87_e5.end_turn()
	r87_e5.end_turn()
	check(r87_rp.health == 10,
		"R87 自我修复：满血时跳过、不越界（%d / %d）" % [r87_rp.health, r87_rp.card.health])
	# ⚠️ 离场还原（回血状态与 +2 血都不留在卡上）
	r87_e5._hit_unit(r87_rp, 999, "R87 测试")
	r87_e5._destroy_dead()
	var r87_rback: CardData = null
	for d87b in r87_e5.state.discard:
		if d87b.id == 8003:
			r87_rback = d87b
	check(r87_rback != null and r87_rback.health == 8,
		"R87 自我修复：离场后弃牌区那张恢复原血 8（实际 %s）"
			% (str(r87_rback.health) if r87_rback != null else "?"))
	# 只吃盟友，工事不行
	var r87_fence2: Placement = r87_e5.state.place(
			_card(8001, "木栅栏", "工事", 2, 0, 6, 0, 0), Vector2i(3, 1), GameEngine.SIDE_SELF)
	r87_e5.state.hand = [CardData.from_dict(r87_rep.to_dict())]
	r87_e5.state.energy = 5
	var r87_rfence: String = r87_e5.use_spell(0, Vector2i(3, 1))
	check(r87_rfence.contains("不是盟友") and r87_fence2.regen == 0,
		"R87 自我修复：**不能**改造工事（%s，regen 仍为 %d）" % [r87_rfence, r87_fence2.regen])

	# ---- R88：维修间 8036 + 改造工厂 8037（持续型场地的第二族）----
	# 全部用 `_new_engine` 造独立引擎，不动 RunState（避免与其它块的卡组状态互相污染）。
	var r88_repo := CardRepo.load_json()
	var r88_bay: CardData = r88_repo.get_card(GameEngine.REPAIR_BAY_ID)
	var r88_fac: CardData = r88_repo.get_card(GameEngine.UPGRADE_FACTORY_ID)
	var r88_fount: CardData = r88_repo.get_card(GameEngine.FOUNTAIN_ID)

	# ---- ① 卡面数据 ----
	check(r88_bay != null and r88_bay.kind == "场地" and r88_bay.cost == 1
			and r88_bay.rarity == 1 and r88_bay.card_class == PlayerClass.MECH,
		"R88 维修间：场地 / 1 费 / 稀有 / 机械之心")
	check(r88_fac != null and r88_fac.kind == "场地" and r88_fac.cost == 2
			and r88_fac.rarity == 0 and r88_fac.card_class == PlayerClass.MECH,
		"R88 改造工厂：场地 / 2 费 / 普通 / 机械之心")
	check(r88_bay.field_heal == 2 and r88_fount.field_heal == 2,
		"R88 两张持续型场地都填了 field_heal=2（清泉也补上了 —— 之前是引擎里的裸常量）")
	check(r88_fac.field_heal == 0 and r88_fac.traits.has(GameEngine.PERSIST_UPGRADE_TRAIT),
		"R88 改造工厂：field_heal=0（它不治血，只加攻加血）+ 带 trait「持续改造」")
	check(r88_bay.traits.has("场地生效·友") and r88_fac.traits.has("场地生效·友")
			and not r88_fount.traits.has("场地生效·友"),
		"R88 生效对象：维修间 / 改造工厂 =「友」，清泉仍是「双」（清泉口径没被改坏）")
	check(r88_bay.traits.has(GameEngine.PLAYER_ONLY_FIELD_TRAIT)
			and r88_fac.traits.has(GameEngine.PLAYER_ONLY_FIELD_TRAIT)
			and GameEngine.is_player_only_field(r88_bay)
			and GameEngine.is_player_only_field(r88_fac)
			and not GameEngine.is_player_only_field(r88_fount),
		"R88 维修间 / 改造工厂 =「仅玩家可放置」，清泉不受影响（仍可被敌方摆）")
	check(r88_bay.trigger == "" and r88_fac.trigger == "",
		"R88 两张持续型场地 trigger 留空（它们不走「经过触发」，写触发类型会误导）")
	# to_dict 往返：漏了 field_heal 会让持续型场地静默失效（R88 真踩过这个坑）
	check(CardData.from_dict(r88_bay.to_dict()).field_heal == 2
			and CardData.from_dict(r88_fac.to_dict()).field_heal == 0,
		"R88 field_heal 能过 to_dict/from_dict 往返（漏序列化 → 回血静默归 0）")

	# ---- ② 进机械之心奖励池（维修间稀有 / 改造工厂普通，都该能摇到）----
	var r88_pool: Array[CardData] = r88_repo.reward_pool_for(PlayerClass.MECH)
	var r88_has_bay := false
	var r88_has_fac := false
	for pc in r88_pool:
		if pc.id == GameEngine.REPAIR_BAY_ID:
			r88_has_bay = true
		if pc.id == GameEngine.UPGRADE_FACTORY_ID:
			r88_has_fac = true
	check(r88_has_bay and r88_has_fac,
		"R88 维修间（稀有）+ 改造工厂（普通）都进机械之心的奖励池")

	# ---- ③ 维修间：我方单位自己回合结束时回 2 血（连续生效、封顶）----
	var r88_e1 := _new_engine([], 30, 30, -1, false)
	r88_e1.start_game()
	var r88_tree: Placement = r88_e1.state.place(
		CardData.from_dict(r88_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r88_e1.state.set_field(CardData.from_dict(r88_bay.to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r88_tree.health = 3
	r88_e1.end_turn()   # 我方回合结束 → 维修间结算
	check(r88_tree.health == 5,
		"R88 维修间：我方单位在自己回合结束时 +2 血（3 → %d）" % r88_tree.health)
	# 敌方回合结束**不回**（用户口径：只在自己回合结束时回）。
	# `end_turn()` 是**半回合**（self ⇄ opp 交替）：从 self 出发调一次 = 我方回合结束，
	# 再调一次 = 敌方回合结束。
	r88_e1.end_turn()   # 我方回合结束 → 维修间结算
	check(r88_tree.health == 5,
		"R88 维修间：我方单位在自己回合结束时 +2 血（3 → %d）" % r88_tree.health)
	r88_e1._hit_unit(r88_tree, 4, "R88 测试")
	r88_e1._destroy_dead()
	r88_e1.end_turn()   # 敌方回合结束 → 我方单位不在这半回合结算
	r88_e1.end_turn()   # 我方回合结束 → 再回
	check(r88_tree.health == 3,
		"R88 维修间：连跑仍生效（打伤到 1 后 +2 → %d），敌方回合结束那半步不回血" % r88_tree.health)
	check(r88_e1.state.field_at(Vector2i(4, 1)) != null,
		"R88 维修间：场地不会被消耗掉（持续型）")

	# ---- ④ **敌方单位站在维修间上不受益**（「友」生效的核心区分）----
	# 同 ⑤ 的坑：`_card` 第 5 位是 power，`health` 要给够大，否则设成 1 就等于满血。
	var r88_e2 := _new_engine([], 30, 30, -1, false)
	r88_e2.start_game()
	var r88_foe_card2 := _card(1053, "骷髅兵", "怪物", 3, 3, 6, 1, 1)
	var r88_foe: Placement = r88_e2.state.place(
		CardData.from_dict(r88_foe_card2.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_OPPONENT)
	r88_foe.health = 1
	r88_e2.state.set_field(CardData.from_dict(r88_bay.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_SELF)
	check(r88_foe.card.health > 1,
		"R88 前置：敌方单位卡面 %d 血 > 1（否则下面两条会被「满血跳过」伪装成通过）"
			% r88_foe.card.health)
	r88_e2.end_turn()   # 我方回合结束：敌方单位不是「自己人」→ 不回
	check(r88_foe.health == 1,
		"R88 维修间：我方回合结束时**敌方**单位不回复（仍 %d，「友」生效）" % r88_foe.health)
	r88_e2.end_turn()   # 敌方回合结束：仍然是「友」场地 → 依然不回
	check(r88_foe.health == 1,
		"R88 维修间：**敌方**回合结束时敌方单位也不回复（仍 %d）—— 与清泉的「双」不同"
			% r88_foe.health)

	# ---- ⑤ 清泉（双）不受影响：敌方单位在敌方回合结束时照样回血（回归护栏）----
	var r88_e3 := _new_engine([], 30, 30, -1, false)
	r88_e3.start_game()
	# ⚠️ `_card` 的参数序是 (id, name, kind, cost, **power**, health, ar, ms) ——
	# 第 5 位是**力量**不是生命。测回血必须先确认卡面 `health` 够大，
	# 否则 `p.health = 1` 恰好等于满血，会被「满血跳过」**正确地**挡掉，
	# 看起来就像「功能没生效」（R83 踩过一次，这里再踩一次）。
	var r88_foe_card3 := _card(1053, "骷髅兵", "怪物", 3, 3, 6, 1, 1)
	var r88_foe3: Placement = r88_e3.state.place(
		CardData.from_dict(r88_foe_card3.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_OPPONENT)
	r88_foe3.health = 1
	r88_e3.state.set_field(CardData.from_dict(r88_fount.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_SELF)
	r88_e3.end_turn()   # 我方回合结束（敌方单位不受益于我方这半步）
	r88_e3.end_turn()   # 敌方回合结束 → 清泉是「双」→ 回 2
	check(r88_foe3.health == 3,
		"R88 回归护栏：清泉仍是「双」—— 敌方单位在敌方回合结束时 +2 血（1 → %d）"
			% r88_foe3.health)

	# ---- ⑥ 改造工厂：每回合 +1 力 / +1 血，**逐回合累加** ----
	var r88_e4 := _new_engine([], 30, 30, -1, false)
	r88_e4.start_game()
	var r88_unit: Placement = r88_e4.state.place(
		CardData.from_dict(r88_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	var r88_hp0: int = r88_unit.health
	var r88_atk0: int = r88_unit.effective_power()
	r88_e4.state.set_field(CardData.from_dict(r88_fac.to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r88_e4.end_turn()
	check(r88_unit.upgrade_atk == 1
			and r88_unit.effective_power() == r88_atk0 + GameEngine.UPGRADE_FACTORY_ATK
			and r88_unit.health == r88_hp0 + GameEngine.UPGRADE_FACTORY_HP,
		"R88 改造工厂：第 1 回合 +%d 力 / +%d 血（%d 攻 / %d 血）" % [
			GameEngine.UPGRADE_FACTORY_ATK, GameEngine.UPGRADE_FACTORY_HP,
			r88_unit.effective_power(), r88_unit.health])
	r88_e4.end_turn()
	r88_e4.end_turn()   # 第 2 个我方回合结束
	check(r88_unit.upgrade_atk == 2
			and r88_unit.effective_power() == r88_atk0 + 2 * GameEngine.UPGRADE_FACTORY_ATK
			and r88_unit.health == r88_hp0 + 2 * GameEngine.UPGRADE_FACTORY_HP,
		"R88 改造工厂：第 2 回合**继续累加**（攻 %d / 血 %d，无限叠）" % [
			r88_unit.effective_power(), r88_unit.health])
	check(r88_repo.get_card(8003).health == 8,
		"R88 改造工厂：**没有污染卡库**（树人卡面仍是 8 血，实际 %d）"
			% r88_repo.get_card(8003).health)
	# 满血也照加（改造不是回血，不该被「满血跳过」挡掉）
	check(r88_unit.health > r88_unit.card.health - 1,
		"R88 改造工厂：加血抬的是**上限**（当前 %d / 上限 %d），不是单纯把当前血填满"
			% [r88_unit.health, r88_unit.card.health])

	# ---- ⑦ 离场还原（改造加成只在场上有效）----
	var r88_out: CardData = r88_e4._card_leaving_field(r88_unit)
	check(r88_out != null and r88_out.health == 8
			and r88_repo.get_card(8003).health == 8,
		"R88 改造工厂：离场还原成原卡（%d 血 → 8 血），卡库仍是 8 血" % r88_out.health)

	# ---- ⑧ 敌方单位站在改造工厂上不被改造 ----
	var r88_e5 := _new_engine([], 30, 30, -1, false)
	r88_e5.start_game()
	var r88_foe5: Placement = r88_e5.state.place(
		CardData.from_dict(r88_foe_card2.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_OPPONENT)
	var r88_f_atk0: int = r88_foe5.effective_power()
	r88_e5.state.set_field(CardData.from_dict(r88_fac.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_SELF)
	r88_e5.end_turn()
	r88_e5.end_turn()
	check(r88_foe5.upgrade_atk == 0
			and r88_foe5.effective_power() == r88_f_atk0,
		"R88 改造工厂：敌方单位**不被改造**（攻仍 %d，「友」生效）"
			% r88_foe5.effective_power())

	# ---- ⑨ 敌方摆不出这两张（仅玩家可放置），但清泉照旧能摆 ----
	var r88_e6 := _new_engine([], 30, 30, -1, false)
	r88_e6.ai_enabled = false
	var r88_e7 := _new_engine([], 30, 30, -1, false)
	r88_e7.ai_enabled = false
	var r88_e8 := _new_engine([], 30, 30, -1, false)
	r88_e8.ai_enabled = false
	r88_e6.remote_play(CardData.from_dict(r88_bay.to_dict()), Vector2i(2, 1))
	r88_e7.remote_play(CardData.from_dict(r88_fac.to_dict()), Vector2i(2, 1))
	r88_e8.remote_play(CardData.from_dict(r88_fount.to_dict()), Vector2i(2, 1))
	check(r88_e6.state.field_at(Vector2i(2, 1)) == null
			and r88_e7.state.field_at(Vector2i(2, 1)) == null,
		"R88 敌方 remote_play：维修间 / 改造工厂一律拒放（仅玩家可放置）")
	check(r88_e8.state.field_at(Vector2i(2, 1)) != null,
		"R88 回归护栏：清泉**仍可被敌方摆放**（「仅玩家可放置」只影响那两张）")

	# ---- ⑩ 场地放置合法性：友生效 → 敌方后排禁放（引擎自动判定）----
	check(GameEngine.field_place_allowed(Vector2i(0, 1), GameEngine.FIELD_AIM_ALLY) == false
			and GameEngine.field_place_allowed(Vector2i(3, 1), GameEngine.FIELD_AIM_ALLY),
		"R88 维修间 / 改造工厂：敌方后排 row 0 禁放、其余允许（FIELD_AIM_ALLY 口径）")

	# ---- ⑪ 放在持续型场地上不触发 / 不拦停（回归护栏）----
	var r88_e9 := _new_engine([], 30, 30, -1, false)
	r88_e9.start_game()
	var r88_runner_card := _card(1053, "骷髅兵", "怪物", 3, 6, 1, 1, 2)
	var r88_runner: Placement = r88_e9.state.place(
		CardData.from_dict(r88_runner_card.to_dict()), Vector2i(2, 0),
		GameEngine.SIDE_OPPONENT)
	r88_e9.state.set_field(CardData.from_dict(r88_fac.to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_SELF)
	# ⚠️ `move` 要**显式传 side**（它按 owner 过滤，不传就不动 —— 与 R83 那条同款坑）。
	r88_e9.move(Vector2i(2, 0), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	check(r88_e9.state.field_at(Vector2i(2, 1)) != null
			and r88_e9.state.unit_at(Vector2i(2, 2)) == r88_runner,
		"R88 敌人经过改造工厂**不被拦停、场地不被消耗**（持续型不参与陷阱链）")

	# ---- R89：无限装甲 8038（机械之心史诗盟友 4 费 4/18）----
	# ⚠️ 供能牌的候选池按 **RunState.player_class** 过滤，所以这里必须显式设成机械之心
	# —— 否则前面的用例留下的角色会把机械之心的牌全滤掉（表现为「候选池为空 / 供能落空」）。
	var r89_saved_cls: String = RunState.player_class
	RunState.player_class = PlayerClass.MECH
	var r89_repo := CardRepo.load_json()
	var r89_armor: CardData = r89_repo.get_card(GameEngine.INF_ARMOR_ID)

	# ---- ① 卡面数据 ----
	check(r89_armor != null and r89_armor.kind == "盟友" and r89_armor.cost == 4
			and r89_armor.power == 4 and r89_armor.health == 18
			and r89_armor.attack_range == 1 and r89_armor.move_speed == 1,
		"R89 无限装甲：盟友 / 4 费 4 攻 18 血 / 攻程 1 / 移速 1")
	check(r89_armor.rarity == 2 and r89_armor.card_class == PlayerClass.MECH,
		"R89 无限装甲：史诗（rarity 2）+ 机械之心")
	check(r89_armor.traits.has(GameEngine.INF_ARMOR_TRAIT),
		"R89 无限装甲：带 trait「改造供能」（引擎按 trait 判定，走卡面不硬编码卡名）")

	# ---- ② 候选池：奖励卡池里「技能 + effect_text 含『改造』」的卡 ----
	var r89_pool: Array[CardData] = r89_repo.reward_pool_for(PlayerClass.MECH)
	var r89_up_spells: Array[CardData] = []
	var r89_has_armor := false
	for pc in r89_pool:
		if pc.id == GameEngine.INF_ARMOR_ID:
			r89_has_armor = true
		if pc.is_spell() and GameEngine.UPGRADE_KEYWORD in pc.effect_text:
			r89_up_spells.append(pc)
	check(r89_has_armor, "R89 无限装甲：史诗 → 进机械之心的奖励池（能摇到）")
	check(r89_up_spells.size() >= 3,
		"R89 候选池：机械之心奖励池里有 %d 张「效果含改造」的技能牌（%s）" % [
			r89_up_spells.size(),
			"、".join(r89_up_spells.map(func(c: CardData): return c.card_name))])
	# 池里**不能**混进非技能卡 / 不含关键词的技能卡
	var r89_pure := true
	for pc in r89_pool:
		if not pc.is_spell():
			continue
		if not (GameEngine.UPGRADE_KEYWORD in pc.effect_text):
			continue
		if pc.kind != "技能":
			r89_pure = false
	check(r89_pure, "R89 候选池：筛选只认「技能 + effect_text 含改造」")

	# ---- ③ 核心：被改造时供一张 0 费改造牌到手 ----
	var r89_e1 := _new_engine([], 30, 30, -1, false)
	r89_e1.start_game()
	var r89_p: Placement = r89_e1.state.place(
		CardData.from_dict(r89_armor.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	# 手上塞一张「升级」当改造手段（打出会被 remove_at，所以基准要减去它）
	r89_e1.state.hand.append(CardData.from_dict(
		r89_repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
	r89_e1.state.energy = 5
	r89_e1.use_spell(0, Vector2i(4, 1))
	# 打「升级」用掉 1 张、供能牌进 1 张 → 净 +0；**净值为 0 正是应该的**
	# （用掉一张换来一张 0 费改造牌，所以「手牌没变多」不代表没供能）
	check(r89_e1.state.hand.size() == 1,
		"R89 无限装甲：被「升级」改造 → 用掉 1 张「升级」、供进 1 张改造牌（手牌 1 张）")
	var r89_got: CardData = null
	for c: CardData in r89_e1.state.hand:
		if r89_e1.state.hand_free.has(c):
			r89_got = c
			break
	check(r89_got != null and r89_got.is_spell()
			and GameEngine.UPGRADE_KEYWORD in r89_got.effect_text,
		"R89 供能牌确实是一张「效果含改造」的技能牌（%s）"
			% ("?" if r89_got == null else r89_got.card_name))
	check(r89_got != null and r89_e1.cost_of(r89_got) == GameEngine.INF_ARMOR_FEED_COST
			and r89_got.cost > 0,
		"R89 供能牌在手牌里费用为 %d（卡面原费 %d）"
			% [GameEngine.INF_ARMOR_FEED_COST, 0 if r89_got == null else r89_got.cost])
	check(r89_p.upgrade_feed_turn == r89_e1.turn_total,
		"R89 「每回合一次」：供能后记下本回合号（%d）" % r89_e1.turn_total)

	# ---- ④ **离手重置**（最容易错的语义）----
	# ⚠️ 这一段刻意**不依赖「打出」**：候选池里现在有「系统升级」这种**两段式**技能
	# （R90 新增，`use_spell` 会在付费前拦截、要求先选手牌目标），对它调 `use_spell`
	# 只会拿到一句提示，卡还留在手牌里 → 断言变成在测别的东西。
	# 真正要验的是「**此刻不在手牌里** → 恢复原价」，用 `remove_at` 精确模拟离手。
	var r89_cost_before: int = r89_e1.cost_of(r89_got)
	var r89_hi: int = r89_e1.state.hand.find(r89_got)
	r89_e1.state.hand.remove_at(r89_hi)
	check(r89_e1.cost_of(r89_got) == r89_got.cost,
		"R89 供能牌**离开手牌**后恢复原价（%d → %d）—— 判据是「此刻在手牌里」"
			% [r89_cost_before, r89_got.cost])
	# 弃掉 → 同样恢复原价（走正式的弃牌路径）
	r89_e1.state.hand.append(r89_got)
	r89_e1.state.hand_free[r89_got] = true
	check(r89_e1.cost_of(r89_got) == GameEngine.INF_ARMOR_FEED_COST,
		"R89 供能牌回到手牌 → 又是 0 费（标记按实例，跟着牌走）")
	r89_e1.state.discard_hand()
	check(r89_e1.cost_of(r89_got) == r89_got.cost,
		"R89 供能牌被弃掉后**恢复原价**（%d）—— 不靠清标记" % r89_got.cost)

	# ---- ⑤ 每回合一次：同回合内第二次改造不再供能 ----
	var r89_e2 := _new_engine([], 30, 30, -1, false)
	r89_e2.start_game()
	var r89_p2: Placement = r89_e2.state.place(
		CardData.from_dict(r89_armor.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r89_e2.state.hand.append(CardData.from_dict(
		r89_repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
	r89_e2.state.energy = 5
	r89_e2.use_spell(0, Vector2i(4, 1))
	# 同回合第二次改造：**先清空手牌**再放「升级」—— 否则 index 0 是上一轮留下的供能牌，
	# 会被当成「升级」打出去，断言就变成在测别的东西了。
	r89_e2.state.hand.clear()
	r89_e2.state.hand.append(CardData.from_dict(
		r89_repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
	r89_e2.state.energy = 5
	r89_e2.use_spell(0, Vector2i(4, 1))
	check(r89_e2.state.hand.size() == 0,
		"R89 「每回合一次」：同回合第二次改造**不再供能**（清空后打出「升级」→ 仍 0 张）")
	# 下一个回合恢复额度
	r89_e2.end_turn()   # 我方回合结束 → turn_total 推进
	r89_e2.end_turn()   # 回到我方回合
	r89_e2.state.hand.clear()
	r89_e2.state.hand.append(CardData.from_dict(
		r89_repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
	r89_e2.state.energy = 5
	r89_e2.use_spell(0, Vector2i(4, 1))
	check(r89_e2.state.hand.size() == 1,
		"R89 「每回合一次」：**下个回合**再改造又供一张（打出「升级」→ 手上剩供能牌 1 张）")

	# ---- ⑥ 不带该 trait 的单位改造不供能（守住「按 trait 判定」）----
	var r89_e3 := _new_engine([], 30, 30, -1, false)
	r89_e3.start_game()
	var r89_tree: Placement = r89_e3.state.place(
		CardData.from_dict(r89_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	var r89_treecost: int = r89_e3.state.hand.size()
	r89_e3.state.hand.append(CardData.from_dict(
		r89_repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
	r89_e3.state.energy = 5
	r89_e3.use_spell(r89_e3.state.hand.size() - 1, Vector2i(4, 1))
	check(r89_e3.state.hand.size() == r89_treecost,
		"R89 树人被改造**不供能**（%d → %d 张，判据是 trait 不是「被改造」）" % [
			r89_treecost, r89_e3.state.hand.size()])

	# ---- ⑦ 手牌已满时落空，不白给 ----
	var r89_e4 := _new_engine([], 30, 30, -1, false)
	r89_e4.start_game()
	var r89_p4: Placement = r89_e4.state.place(
		CardData.from_dict(r89_armor.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	while r89_e4.state.hand.size() < FieldState.HAND_LIMIT:
		r89_e4.state.hand.append(CardData.from_dict(r89_repo.get_card(8001).to_dict()))
	var r89_full0: int = r89_e4.state.hand.size()
	r89_e4.state.energy = 9
	# 直接调引擎口（手牌满了塞不进「升级」，用 5 费能量硬调）
	r89_e4._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r89_e4.state.hand.size() == r89_full0,
		"R89 手牌已满（%d）时供能落空，不超上限" % r89_full0)

	# ---- ⑧ 不污染卡库（供能牌是独立实例）----
	check(r89_repo.get_card(r89_got.id).effect_text == r89_got.effect_text
			and r89_repo.get_card(r89_got.id) != r89_got,
		"R89 供能牌是**独立实例**（不是卡库那张共享对象）")

	RunState.player_class = r89_saved_cls

	# ---- R90：系统升级 8039 + 批量传输 8040（改造手牌，烤进副本）----
	var r90_saved_cls: String = RunState.player_class
	RunState.player_class = PlayerClass.MECH
	var r90_repo := CardRepo.load_json()
	var r90_su: CardData = r90_repo.get_card(GameEngine.SYS_UPGRADE_ID)
	var r90_bt: CardData = r90_repo.get_card(GameEngine.BATCH_TRANSFER_ID)

	# ---- ① 卡面数据 ----
	check(r90_su != null and r90_su.kind == "技能" and r90_su.cost == 1
			and r90_su.rarity == 1 and r90_su.card_class == PlayerClass.MECH
			and r90_su.target_mode == "hand_unit",
		"R90 系统升级：技能 / 1 费 / 稀有 / 机械之心 / target_mode=hand_unit（目标在**手牌**）")
	check(r90_bt != null and r90_bt.kind == "技能" and r90_bt.cost == 1
			and r90_bt.rarity == 1 and r90_bt.card_class == PlayerClass.MECH
			and r90_bt.target_mode == "none",
		"R90 批量传输：技能 / 1 费 / 稀有 / 机械之心 / 无目标")
	# 两张都进机械之心奖励池
	var r90_pool: Array[CardData] = r90_repo.reward_pool_for(PlayerClass.MECH)
	var r90_has_su := false
	var r90_has_bt := false
	for pc in r90_pool:
		if pc.id == GameEngine.SYS_UPGRADE_ID:
			r90_has_su = true
		if pc.id == GameEngine.BATCH_TRANSFER_ID:
			r90_has_bt = true
	check(r90_has_su and r90_has_bt, "R90 两张都进机械之心的奖励池（稀有，能摇到）")

	# ---- ② 系统升级：改造手牌里一张（费用+1 / 力+3 / 血+6）----
	var r90_e1 := _new_engine([], 30, 30, -1, false)
	r90_e1.start_game()
	r90_e1.state.hand.append(CardData.from_dict(r90_repo.get_card(8003).to_dict()))  # 树人 3费3/8
	r90_e1.state.hand.append(CardData.from_dict(r90_repo.get_card(8001).to_dict()))  # 木栅栏 2费0/6
	r90_e1.state.hand.append(CardData.from_dict(r90_su.to_dict()))
	var r90_before_tree: CardData = r90_e1.state.hand[0]
	var r90_msg := r90_e1.cast_sys_upgrade(2, 0)
	var r90_after_tree: CardData = r90_e1.state.hand[0]
	check(r90_after_tree.cost == r90_before_tree.cost + GameEngine.SYS_UPGRADE_COST_ADD
			and r90_after_tree.power == r90_before_tree.power + GameEngine.SYS_UPGRADE_ATK
			and r90_after_tree.health == r90_before_tree.health + GameEngine.SYS_UPGRADE_HP,
		"R90 系统升级：树人 %d费%d攻%d血 → %d费%d攻%d血（+1费/+3力/+6血）" % [
			r90_before_tree.cost, r90_before_tree.power, r90_before_tree.health,
			r90_after_tree.cost, r90_after_tree.power, r90_after_tree.health])
	check(r90_e1.state.hand.size() == 2,
		"R90 系统升级：只有它自己进弃牌区，**目标那张留在手牌**（%d 张）"
			% r90_e1.state.hand.size())
	# 下标顺移：目标是 0 号、自己是 2 号 → 移除 2 号后 0 号不变（target < source，不顺移）
	check(r90_e1.state.hand[0].card_name == "树人" and r90_e1.state.hand[1].card_name == "木栅栏",
		"R90 系统升级：手牌顺序不受影响（树人仍在 0 号位）")

	# ---- ③ **不污染卡库**（烤进的是副本）----
	check(r90_repo.get_card(8003).cost == 3 and r90_repo.get_card(8003).health == 8,
		"R90 改造**没有污染卡库**（树人卡面仍是 3 费 8 血）")

	# ---- ④ 本场战斗永久：打出 → 进弃牌区仍带加成 → 再抽到仍带 ----
	r90_e1.state.energy = 5
	r90_e1.play_from_hand(0, Vector2i(4, 1))     # 打出加强版树人
	var r90_field: Placement = r90_e1.state.unit_at(Vector2i(4, 1))
	check(r90_field != null and r90_field.card.power == 3 + GameEngine.SYS_UPGRADE_ATK
			and r90_field.health == 8 + GameEngine.SYS_UPGRADE_HP,
		"R90 加强版树人上场：%d 攻 / %d 血（卡面 %d/%d → 场上 %d/%d）" % [
			r90_before_tree.power + GameEngine.SYS_UPGRADE_ATK,
			r90_before_tree.health + GameEngine.SYS_UPGRADE_HP,
			r90_before_tree.power, r90_before_tree.health,
			r90_field.effective_power(), r90_field.health])
	# 弃回牌库 → 再抽到仍带：用「被打死」这条真实路径验证。
	# ⚠️ 不能用 `play_from_hand` —— 那是**上场**，卡进的是棋盘不是弃牌区。
	r90_e1._hit_unit(r90_field, 99, "R90 测试")
	r90_e1._destroy_dead()
	var r90_disc: CardData = null
	for c: CardData in r90_e1.state.discard:
		if c.card_name == "树人":
			r90_disc = c
			break
	check(r90_disc != null and r90_disc.health == 8 + GameEngine.SYS_UPGRADE_HP
			and r90_disc.cost == 4,
		"R90 **本场战斗永久**：被打死后进弃牌区的那张仍是加强版（%d 费 / %d 血）"
			% [r90_disc.cost if r90_disc != null else -1,
				r90_disc.health if r90_disc != null else -1])
	check(r90_repo.get_card(8003).health == 8 and r90_repo.get_card(8003).cost == 3,
		"R90 离场后**卡库仍然是原卡**（3 费 8 血）—— 加成没有烤进卡库")

	# ---- ⑤ 拒绝非法目标 ----
	var r90_e2 := _new_engine([], 30, 30, -1, false)
	r90_e2.start_game()
	r90_e2.state.hand.append(CardData.from_dict(r90_repo.get_card(8002).to_dict()))  # 技能
	r90_e2.state.hand.append(CardData.from_dict(r90_su.to_dict()))
	var r90_skill_cost: int = r90_e2.state.hand[0].cost
	var r90_r1 := r90_e2.cast_sys_upgrade(1, 0)
	check(r90_r1.contains("盟友或工事") and r90_e2.state.hand.size() == 2
			and r90_e2.state.energy == 5,
		"R90 系统升级：目标是技能卡 → 拒绝，**不扣费**（手牌仍 %d 张 / 能量 %d）"
			% [r90_e2.state.hand.size(), r90_e2.state.energy])
	check(r90_e2.state.hand[0].cost == r90_skill_cost,
		"R90 拒绝时目标卡数值不变（仍是 %d 费）" % r90_skill_cost)
	var r90_r2 := r90_e2.cast_sys_upgrade(1, 1)
	check(r90_r2.contains("不能改造自己"),
		"R90 系统升级：不能改造自己（%s）" % r90_r2)
	# 手牌里没有盟友/工事 → 立刻落空，不弹面板
	var r90_e3 := _new_engine([], 30, 30, -1, false)
	r90_e3.start_game()
	r90_e3.state.hand.append(CardData.from_dict(r90_su.to_dict()))
	var r90_r3 := r90_e3.cast_sys_upgrade(0, -1)
	check(r90_r3.contains("盟友或工事"),
		"R90 手牌里只有系统升级自己 → 无可选目标，直接落空（%s）" % r90_r3)

	# ---- ⑥ 单段 use_spell 被拦截（两段式必须有第二段）----
	var r90_e4 := _new_engine([], 30, 30, -1, false)
	r90_e4.start_game()
	r90_e4.state.hand.append(CardData.from_dict(r90_su.to_dict()))
	r90_e4.state.energy = 5
	var r90_single := r90_e4.use_spell(0, null)
	check(r90_single.contains("先点手牌") and r90_e4.state.hand.size() == 1
			and r90_e4.state.energy == 5,
		"R90 系统升级：单段 use_spell 被**付费前拦截**（卡还在手牌、能量仍 %d）"
			% r90_e4.state.energy)

	# ---- ⑦ 批量传输：手牌全体改造 + 抽 1 张 ----
	# ⚠️ **先 start_game 再改手牌/牌库** —— `start_game` 会走 `_begin_turn`（抽牌 + 弃牌），
	# 在它之前设的手牌会被重置掉。前面的用例都是这个顺序，别写反。
	var r90_e5 := _new_engine([], 30, 30, -1, false)
	r90_e5.start_game()
	r90_e5.state.deck = [CardData.from_dict(r90_repo.get_card(8004).to_dict())]  # 熊
	r90_e5.state.hand.clear()
	r90_e5.state.hand.append(CardData.from_dict(r90_repo.get_card(8003).to_dict()))  # 树人 3费3/8
	r90_e5.state.hand.append(CardData.from_dict(r90_repo.get_card(8001).to_dict()))  # 木栅栏 2费0/6
	r90_e5.state.hand.append(CardData.from_dict(r90_repo.get_card(8002).to_dict()))  # 攻击（技能，不改）
	r90_e5.state.hand.append(CardData.from_dict(r90_bt.to_dict()))
	r90_e5.state.energy = 5
	var r90_hand0: int = r90_e5.state.hand.size()
	r90_e5.use_spell(3, null)
	var r90_t2: CardData = r90_e5.state.hand[0]
	var r90_f2: CardData = r90_e5.state.hand[1]
	var r90_s2: CardData = r90_e5.state.hand[2]
	check(r90_t2.power == 3 + GameEngine.SYS_UPGRADE_ATK
			and r90_f2.health == 6 + GameEngine.SYS_UPGRADE_HP
			and r90_f2.cost == 2 + GameEngine.SYS_UPGRADE_COST_ADD,
		"R90 批量传输：树人 %d 攻 / 木栅栏 %d 费 %d 血（技能卡不动）" % [
			r90_t2.power, r90_f2.cost, r90_f2.health])
	# 8002「攻击」是技能卡、**没有 power 字段**（默认 0）→ 判据用「费用没被 +1」
	check(r90_s2.kind == "技能" and r90_s2.cost == 1 and r90_s2.card_name == "攻击",
		"R90 批量传输：**技能卡不被改造**（%s 仍 %d 费）" % [
			r90_s2.card_name, r90_s2.cost])
	# 抽 1 张：-1（用掉自己）+ 1（抽牌）= 净 0
	check(r90_e5.state.hand.size() == r90_hand0,
		"R90 批量传输：抽 1 张牌（用掉 1 张 + 抽进 1 张 → 手牌 %d 张不变）"
			% r90_e5.state.hand.size())
	var r90_bear: CardData = null
	for c: CardData in r90_e5.state.hand:
		if c.card_name == "熊":
			r90_bear = c
			break
	check(r90_bear != null, "R90 批量传输：抽到的正是「熊」（%s）"
		% ("没抽到" if r90_bear == null else "抽到了"))
	check(r90_repo.get_card(8003).power == 3 and r90_repo.get_card(8001).health == 6,
		"R90 批量传输**没有污染卡库**（树人 3 攻 / 木栅栏 6 血不变）")

	# ---- ⑧ 手牌里没有盟友/工事 → 改造落空但仍抽 1 张 ----
	var r90_e6 := _new_engine([], 30, 30, -1, false)
	r90_e6.start_game()
	r90_e6.state.deck = [CardData.from_dict(r90_repo.get_card(8004).to_dict())]
	r90_e6.state.hand.clear()
	r90_e6.state.hand.append(CardData.from_dict(r90_bt.to_dict()))
	r90_e6.state.energy = 5
	var r90_h6: int = r90_e6.state.hand.size()
	r90_e6.use_spell(0, null)
	check(r90_e6.state.hand.size() == r90_h6,
		"R90 无盟友可改造：改造落空但**仍抽 1 张**（手牌 %d → %d）"
			% [r90_h6, r90_e6.state.hand.size()])
	var r90_bear6: CardData = null
	for c: CardData in r90_e6.state.hand:
		if c.card_name == "熊":
			r90_bear6 = c
			break
	check(r90_bear6 != null,
		"R90 无盟友可改造时抽到的仍是「熊」（%s）"
			% ("没抽到" if r90_bear6 == null else "抽到了"))

	RunState.player_class = r90_saved_cls


	# ---- R91：充电装置 8041 + 字段系统（CardData.affixes）----
	var r91_saved_cls: String = RunState.player_class
	RunState.player_class = PlayerClass.MECH
	var r91_repo := CardRepo.load_json()
	var r91_ch: CardData = r91_repo.get_card(GameEngine.CHARGE_STATION_ID)

	# ---- ① 卡面数据 ----
	check(r91_ch != null and r91_ch.kind == "工事" and r91_ch.cost == 1
			and r91_ch.power == 1 and r91_ch.health == 1 and r91_ch.attack_range == 1
			and r91_ch.move_speed == 0 and r91_ch.rarity == 0
			and r91_ch.card_class == PlayerClass.MECH,
		"R91 充电装置：工事 / 1 费 1 攻 1 血 / 攻程 1 / 移速 0 / 普通 / 机械之心")
	check(r91_ch.traits.has(GameEngine.CHARGE_TRAIT),
		"R91 充电装置：带 trait「接通」（与闪电链同一个 trait 族）")

	# ---- ② 字段系统：定义表 / 判定口 / 序列化往返 ----
	check(CardData.AFFIX_DEFS.size() == 7,
		"R91 字段表：7 个字段（疾行 / 嘲讽 / 死亡 / 幻影 / 护盾 / **次元** R93 / **超负荷** R98），实际 %d"
		% CardData.AFFIX_DEFS.size())
	var r91_all: Dictionary = {}
	for c91 in r91_repo.all_cards():
		for a91 in c91.affixes:
			r91_all[a91] = true
	check(r91_all.has("疾行") and r91_all.has("嘲讽") and r91_all.has("死亡")
			and r91_all.has("幻影"),
		"R91 数据层：四类字段都已写进 cards.json（%s）" % ", ".join(r91_all.keys()))
	check(CardData.affix_label("疾行") == "疾行"
			and CardData.affix_desc("疾行").contains("两次")
			and CardData.affix_desc("嘲讽").contains("攻击")
			and CardData.affix_colors("幻影").size() == 2,
		"R91 字段表：label / desc / colors 三个读取口都正常")
	check(CardData.affix_label("不存在") == "不存在"
			and CardData.affix_desc("不存在") == "",
		"R91 未注册字段回退到字段名本身（不会显示空白）")
	# to_dict/from_dict 往返：漏序列化 → 引擎赋的字段静默消失
	var r91_probe := CardData.from_dict(r91_repo.get_card(9031).to_dict())
	check(r91_probe.has_affix("疾行") and r91_probe.affix_line().contains("疾行"),
		"R91 白狼 9031：affixes 过 to_dict/from_dict 往返（字段不丢）")
	# ⚠️ 断言要验「改副本**不影响**原卡」，不能写 `a1.affixes != a2.affixes`
	# —— GDScript 的 Array `!=` 是**内容**比较，两份内容相同就判相等（我踩过）。
	r91_probe.add_affix("测试字段")
	check(not r91_repo.get_card(9031).has_affix("测试字段"),
		"R91 from_dict 的 affixes 是**独立副本**（往副本加字段不影响卡库原卡）")
	# add_affix 不重复写
	var r91_add := CardData.from_dict(r91_repo.get_card(8003).to_dict())
	check(r91_add.add_affix(GameEngine.AFFIX_TAUNT)
			and not r91_add.add_affix(GameEngine.AFFIX_TAUNT)
			and r91_add.affixes.size() == 1,
		"R91 add_affix：首次 true / 重复 false（不会写两遍）")

	# ---- ③ 字段与卡面数值一致（疾行 = actions>=2）----
	var r91_mismatch: Array[String] = []
	for c92 in r91_repo.all_cards():
		var want_swift: bool = c92.actions >= GameEngine.DOUBLE_ACTION
		var has_swift: bool = c92.has_affix(GameEngine.AFFIX_SWIFT)
		if want_swift != has_swift:
			r91_mismatch.append("%d %s" % [c92.id, c92.card_name])
	check(r91_mismatch.is_empty(),
		"R91 一致性：**每一张** actions>=2 的卡都带「疾行」字段（不符：%s）"
			% ("无" if r91_mismatch.is_empty() else ", ".join(r91_mismatch)))

	# ---- ④ active_affixes：按场上实况过滤 ----
	var r91_sw := CardData.from_dict(r91_repo.get_card(9031).to_dict())
	check(r91_sw.active_affixes(2, false).has("疾行"),
		"R91 active_affixes：还剩 2 轮行动 → 显示「疾行」")
	check(not r91_sw.active_affixes(1, false).has("疾行"),
		"R91 active_affixes：用掉一轮后（acts_left=1）→ **不再显示**「疾行」")
	var r91_sh := CardData.from_dict(r91_repo.get_card(8003).to_dict())
	r91_sh.add_affix(GameEngine.FIELD_BARRIER)
	check(r91_sh.active_affixes(1, true).has("护盾")
			and not r91_sh.active_affixes(1, false).has("护盾"),
		"R91 active_affixes：护盾用掉后（shield=false）→ **不再显示**")

	# ---- ⑤ 引擎赋字段：过载给「疾行」、能量屏障给「护盾」----
	var r91_e1 := _new_engine([], 30, 30, -1, false)
	r91_e1.start_game()
	r91_e1.state.deck = [CardData.from_dict(r91_repo.get_card(8003).to_dict())]
	r91_e1.state.hand.append(CardData.from_dict(
			r91_repo.get_card(GameEngine.OVERLOAD_ID).to_dict()))
	r91_e1.state.energy = 5
	r91_e1.use_spell(0, null)
	check(r91_e1.state.deck[0].actions == GameEngine.DOUBLE_ACTION
			and r91_e1.state.deck[0].has_affix(GameEngine.AFFIX_SWIFT),
		"R91 过载：牌库那张树人被改成双动，**并且自动带上「疾行」字段**（卡面/战场可见）")
	check(not r91_repo.get_card(8003).has_affix(GameEngine.AFFIX_SWIFT),
		"R91 过载**没有污染卡库**（树人原卡不带疾行）")
	var r91_e2 := _new_engine([], 30, 30, -1, false)
	r91_e2.start_game()
	r91_e2.state.deck = [CardData.from_dict(r91_repo.get_card(8001).to_dict())]
	r91_e2.state.hand.append(CardData.from_dict(
			r91_repo.get_card(GameEngine.BARRIER_ID).to_dict()))
	r91_e2.state.energy = 5
	r91_e2.use_spell(0, null)
	check(r91_e2.state.deck[0].has_affix(GameEngine.FIELD_BARRIER),
		"R91 能量屏障：被改造的那张自动带上「护盾」字段（后续赋予也能被看到）")

	# ---- ⑥ 充电装置：只给**接通的己方单位**回血 ----
	# 布局：(4,1)=充电装置 (4,0)=己方树人 (4,2)=己方木栅栏 (3,1)=敌方骷髅
	var r91_e3 := _new_engine([], 40, 40, -1, false)
	r91_e3.start_game()
	var r91_skel := _card(1053, "骷髅兵", "怪物", 3, 6, 1, 1, 1)
	var r91_tree: Placement = r91_e3.state.place(
		CardData.from_dict(r91_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r91_fence: Placement = r91_e3.state.place(
		CardData.from_dict(r91_repo.get_card(8001).to_dict()), Vector2i(4, 2),
		GameEngine.SIDE_SELF)
	r91_e3.state.place(CardData.from_dict(r91_skel.to_dict()), Vector2i(3, 1),
		GameEngine.SIDE_OPPONENT)
	var r91_station: Placement = r91_e3.state.place(
		CardData.from_dict(r91_ch.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	r91_tree.health = 1
	r91_fence.health = 1
	r91_station.health = 1
	r91_e3.end_turn()
	check(r91_tree.health == 3 and r91_fence.health == 3,
		"R91 充电装置：接通的**己方**上下两格各 +2 血（树人 %d / 木栅栏 %d）"
			% [r91_tree.health, r91_fence.health])
	# 敌方**不**回血 —— 卡面写的是「**接通的我方**盟友和工事」，
	# 这是它与闪电链（不分敌我）的关键差别。
	var r91_foe: Placement = r91_e3.state.unit_at(Vector2i(3, 1))
	check(r91_foe != null and r91_foe.health == r91_foe.card.health,
		"R91 充电装置「只算我方」：相邻的**敌方**单位**不**回血（仍 %d / 上限 %d）"
			% [r91_foe.health if r91_foe != null else -1,
				r91_foe.card.health if r91_foe != null else -1])
	# 连通分量会**穿过敌方单位传导**（闪电链同款语义）：
	# (2,1) 的树人本身不与装置相邻，但 (3,1) 的敌方骷髅把两边连成了一个分量
	# → 「接通」是按**连通块**算的，不是只看直接邻居。
	var r91_far: Placement = r91_e3.state.place(
		CardData.from_dict(r91_repo.get_card(8003).to_dict()), Vector2i(2, 1),
		GameEngine.SIDE_SELF)
	r91_far.health = 5
	r91_e3.end_turn()
	r91_e3.end_turn()
	check(r91_far.health == 7,
		"R91 充电装置：「接通」按**连通块**算（隔着敌方骷髅 (3,1) 也算接通，5 → %d）"
			% r91_far.health)
	# 真正孤立的一格：完全不与装置所在连通块相邻 → 不回血
	var r91_iso: Placement = r91_e3.state.place(
		CardData.from_dict(r91_repo.get_card(8003).to_dict()), Vector2i(0, 0),
		GameEngine.SIDE_SELF)
	r91_iso.health = 5
	r91_e3.end_turn()
	r91_e3.end_turn()
	check(r91_iso.health == 5,
		"R91 充电装置：孤立的 (0,0) **不接通**，不回复（仍 %d）" % r91_iso.health)

	# ---- ⑦ 「只算我方」：敌方回合结束时敌方单位不因它回血 ----
	var r91_e4 := _new_engine([], 40, 40, -1, false)
	r91_e4.start_game()
	var r91_foe2: Placement = r91_e4.state.place(
		CardData.from_dict(r91_skel.to_dict()), Vector2i(3, 1),
		GameEngine.SIDE_OPPONENT)
	r91_e4.state.place(CardData.from_dict(r91_ch.to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r91_foe2.health = 1
	r91_e4.end_turn()
	check(r91_foe2.health == 1,
		"R91 充电装置「**只算我方**」：我方回合结束时敌方单位不回复（仍 %d）"
			% r91_foe2.health)

	# ---- ⑧ 幻影字段：带字段的卡打出即产生复制（不依赖野兔）----
	var r91_e5 := _new_engine([], 30, 30, -1, false)
	r91_e5.start_game()
	var r91_ghost := CardData.from_dict(r91_repo.get_card(8003).to_dict())
	r91_ghost.add_affix(GameEngine.AFFIX_PHANTOM)   # 给树人加「幻影」
	r91_e5.state.hand.append(r91_ghost)
	r91_e5.state.energy = 5
	var r91_h0: int = r91_e5.state.hand.size()
	r91_e5.play_from_hand(0, Vector2i(4, 1))
	var r91_clone: CardData = null
	for c93 in r91_e5.state.hand:
		if c93.is_ephemeral:
			r91_clone = c93
		check(r91_clone != null and r91_clone.card_name == "树人"
			and r91_clone.has_affix(GameEngine.AFFIX_PHANTOM),
		"R91 幻影字段：给任意卡加上字段 → 打出后手牌里出现它的复制（%d → %d 张）"
			% [r91_h0, r91_e5.state.hand.size()])
	# 幻影回合结束消失
	r91_e5.end_turn()
	r91_e5.end_turn()
	check(r91_e5.state.hand.is_empty(),
		"R91 幻影：回合结束时消失（%d 张手牌）" % r91_e5.state.hand.size())

	# ---- R92：护盾生成器 8042（伤害转移）/ 模仿者 8043（改造传导）----
	var r92_repo := CardRepo.load_json()
	var r92_gen_def: CardData = r92_repo.get_card(GameEngine.SHIELD_GEN_ID)
	var r92_mim_def: CardData = r92_repo.get_card(GameEngine.MIMIC_ID)
	check(r92_gen_def != null and r92_gen_def.kind == "工事" and r92_gen_def.cost == 2
			and r92_gen_def.power == 0 and r92_gen_def.health == 9
			and r92_gen_def.attack_range == 0 and r92_gen_def.move_speed == 0
			and r92_gen_def.rarity == 0 and r92_gen_def.card_class == PlayerClass.MECH,
		"R92 护盾生成器：工事 / 2 费 0 攻 9 血 / 攻程 0 / 移速 0 / **普通** / 机械之心")
	check(r92_gen_def.traits.has(GameEngine.CHARGE_TRAIT)
			and r92_gen_def.traits.has("伤害转移"),
		"R92 护盾生成器：带 trait「接通」与「伤害转移」")
	check(r92_mim_def != null and r92_mim_def.kind == "盟友" and r92_mim_def.cost == 2
			and r92_mim_def.power == 0 and r92_mim_def.health == 10
			and r92_mim_def.attack_range == 1 and r92_mim_def.move_speed == 1
			and r92_mim_def.rarity == 2 and r92_mim_def.card_class == PlayerClass.MECH,
		"R92 模仿者：盟友 / 2 费 0 攻 10 血 / 攻程 1 / 移速 1 / **史诗** / 机械之心")
	check(r92_mim_def.traits.has(GameEngine.CHARGE_TRAIT)
			and r92_mim_def.traits.has("模仿改造"),
		"R92 模仿者：带 trait「接通」与「模仿改造」")

	# ---- ① 护盾生成器：接通的己方单位受伤 → 改由它承受 ----
	var r92_foe_def := _card(9201, "测试骷髅", "怪物", 1, 3, 6, 1, 1)
	var r92_e1 := _new_engine([], 40, 40, -1, false)
	r92_e1.start_game()
	var r92_tree: Placement = r92_e1.state.place(
		CardData.from_dict(r92_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r92_gen: Placement = r92_e1.state.place(
		CardData.from_dict(r92_gen_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r92_tree_hp0: int = r92_tree.health
	var r92_gen_hp0: int = r92_gen.health
	r92_e1._hit_unit(r92_tree, 5, "测试")
	check(r92_tree.health == r92_tree_hp0
			and r92_gen.health == r92_gen_hp0 - 5,
		"R92 护盾生成器：接通的己方单位受伤 → **改由它承受**（树人仍 %d / 生成器 %d→%d）"
			% [r92_tree.health, r92_gen_hp0, r92_gen.health])
	# ⚠️ 溢出部分**不再结算**：不回传给原单位
	r92_e1._hit_unit(r92_tree, 20, "测试")
	check(r92_tree.health == r92_tree_hp0 and r92_gen.health < 0,
		"R92 护盾生成器：**溢出部分不再结算**（叠加 20 点伤害后原单位仍满血 %d，生成器被击穿到 %d）"
			% [r92_tree.health, r92_gen.health])
	# 生成器血量耗尽 → 保护失效
	r92_e1._hit_unit(r92_tree, 3, "测试")
	check(r92_tree.health == r92_tree_hp0 - 3,
		"R92 护盾生成器：血量耗尽后**不再保护**（树人掉到 %d）" % r92_tree.health)

	# ---- ②「**只护我方**」+「**必须在同一连通块**」----
	var r92_e2 := _new_engine([], 40, 40, -1, false)
	r92_e2.start_game()
	var r92_gen2: Placement = r92_e2.state.place(
		CardData.from_dict(r92_gen_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r92_foe2: Placement = r92_e2.state.place(
		CardData.from_dict(r92_foe_def.to_dict()), Vector2i(3, 1),
		GameEngine.SIDE_OPPONENT)
	var r92_iso: Placement = r92_e2.state.place(
		CardData.from_dict(r92_repo.get_card(8003).to_dict()), Vector2i(0, 0),
		GameEngine.SIDE_SELF)
	var r92_foe_hp0: int = r92_foe2.health
	var r92_iso_hp0: int = r92_iso.health
	r92_e2._hit_unit(r92_foe2, 3, "测试")
	check(r92_foe2.health == r92_foe_hp0 - 3 and r92_gen2.health == 9,
		"R92 护盾生成器「**只护我方**」：相邻的敌方单位照常受伤（%d→%d），生成器没掉血（%d）"
			% [r92_foe_hp0, r92_foe2.health, r92_gen2.health])
	r92_e2._hit_unit(r92_iso, 3, "测试")
	check(r92_iso.health == r92_iso_hp0 - 3 and r92_gen2.health == 9,
		"R92 护盾生成器：孤立的 (0,0) **不接通** → 不受保护（%d→%d），生成器仍 %d"
			% [r92_iso_hp0, r92_iso.health, r92_gen2.health])

	# ---- ③ 模仿者：三种改造来源全部传导 ----
	var r92_e3 := _new_engine([], 40, 40, -1, false)
	r92_e3.start_game()
	var r92_src: Placement = r92_e3.state.place(
		CardData.from_dict(r92_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r92_mim: Placement = r92_e3.state.place(
		CardData.from_dict(r92_mim_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r92_mim_atk0: int = r92_mim.effective_power()
	var r92_mim_hp0: int = r92_mim.health
	# ③-a「升级」8027（技能改造）
	r92_e3._upgrade_unit(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r92_mim.upgrade_atk == GameEngine.UPGRADE_ATK
			and r92_mim.upgrade_hp == GameEngine.UPGRADE_HP
			and r92_mim.effective_power() == r92_mim_atk0 + GameEngine.UPGRADE_ATK
			and r92_mim.health == r92_mim_hp0 + GameEngine.UPGRADE_HP,
		"R92 模仿者：接通的盟友被「升级」改造 → 获得**相同改造**（+%d 攻 / +%d 血 → %d 攻 / %d 血）"
			% [GameEngine.UPGRADE_ATK, GameEngine.UPGRADE_HP,
				r92_mim.effective_power(), r92_mim.health])
	# ③-b「自我修复」8035（也算一次改造，只复制最大生命那半，**不复制回血**）
	var r92_mim_hp1: int = r92_mim.health
	var r92_mim_atk1: int = r92_mim.effective_power()
	r92_e3._self_repair(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r92_mim.health == r92_mim_hp1 + GameEngine.SELF_REPAIR_HP
			and r92_mim.effective_power() == r92_mim_atk1
			and r92_mim.regen <= 0,
		"R92 模仿者：模仿「自我修复」→ 只有最大生命 +%d（攻仍 %d），**不复制每回合回血**"
			% [GameEngine.SELF_REPAIR_HP, r92_mim.effective_power()])
	# ③-c「改造工厂」8037（每回合自动改造）
	var r92_mim_atk2: int = r92_mim.effective_power()
	var r92_mim_hp2: int = r92_mim.health
	r92_e3.state.set_field(CardData.from_dict(r92_repo.get_card(8037).to_dict()),
		Vector2i(4, 0), GameEngine.SIDE_SELF)
	r92_e3.end_turn()
	check(r92_mim.effective_power() == r92_mim_atk2 + GameEngine.UPGRADE_FACTORY_ATK
			and r92_mim.health == r92_mim_hp2 + GameEngine.UPGRADE_FACTORY_HP,
		"R92 模仿者：模仿「改造工厂」→ +%d 攻 / +%d 血（%d 攻 / %d 血）"
			% [GameEngine.UPGRADE_FACTORY_ATK, GameEngine.UPGRADE_FACTORY_HP,
				r92_mim.effective_power(), r92_mim.health])
	# ⚠️ 不污染卡库（卡库里那张模仿者仍是 0/10）
	check(r92_repo.get_card(GameEngine.MIMIC_ID).health == 10
			and r92_repo.get_card(GameEngine.MIMIC_ID).power == 0,
		"R92 模仿者：**没有污染卡库**（仍是 0 攻 / %d 血）"
			% r92_repo.get_card(GameEngine.MIMIC_ID).health)
	# 离场还原
	var r92_restored: CardData = r92_e3._card_leaving_field(r92_mim)
	check(r92_restored != null and r92_restored.health == 10,
		"R92 模仿者：离场时**还原成原卡**（%d 血 → 10 血）"
			% (r92_restored.health if r92_restored != null else -1))

	# ---- ④ 模仿者：**不接通不受益** ----
	var r92_e4 := _new_engine([], 40, 40, -1, false)
	r92_e4.start_game()
	var r92_src4: Placement = r92_e4.state.place(
		CardData.from_dict(r92_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r92_far_mim: Placement = r92_e4.state.place(
		CardData.from_dict(r92_mim_def.to_dict()), Vector2i(0, 0), GameEngine.SIDE_SELF)
	r92_e4._upgrade_unit(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r92_far_mim.upgrade_atk == 0 and r92_far_mim.upgrade_hp == 0,
		"R92 模仿者：孤立的 (0,0) **不接通** → 不复制改造（仍 0 攻加成 / 血量 %d）"
			% r92_far_mim.health)

	# ---- ⑤ **不连锁**：X—A—B 链里 B 只拿自己那一份，不会「再 Copy 一次」 ----
	var r92_e5 := _new_engine([], 40, 40, -1, false)
	r92_e5.start_game()
	var r92_x: Placement = r92_e5.state.place(
		CardData.from_dict(r92_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r92_ma: Placement = r92_e5.state.place(
		CardData.from_dict(r92_mim_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r92_mb: Placement = r92_e5.state.place(
		CardData.from_dict(r92_mim_def.to_dict()), Vector2i(4, 2), GameEngine.SIDE_SELF)
	r92_e5._upgrade_unit(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r92_ma.upgrade_atk == GameEngine.UPGRADE_ATK
			and r92_mb.upgrade_atk == GameEngine.UPGRADE_ATK,
		"R92 模仿者「**不连锁**」：A、B 各自**只复制一次**（A +%d / B +%d，不是 B 拿双份 %d）"
			% [r92_ma.upgrade_atk, r92_mb.upgrade_atk, 2 * GameEngine.UPGRADE_ATK])

	# ---- R93：字段「次元」= 使用后 / 离场后消失，不进弃牌区 ----
	var r93_repo := CardRepo.load_json()
	check(CardData.AFFIX_DEFS.has(GameEngine.AFFIX_DIMENSION)
			and CardData.affix_label(GameEngine.AFFIX_DIMENSION) == "次元"
			and CardData.affix_desc(GameEngine.AFFIX_DIMENSION) != ""
			and CardData.affix_colors(GameEngine.AFFIX_DIMENSION).size() == 2,
		"R93「次元」已登记进字段表：label/desc/配色三者齐备（加新字段只改一处）")
	# ① 静态 7 张：全部带上「次元」
	var r93_static: Array[int] = [9022, 9050, 9080, 9097, 9098, 9109, 8010]
	var r93_miss: Array[int] = []
	for r93_id in r93_static:
		if not r93_repo.get_card(r93_id).has_affix(GameEngine.AFFIX_DIMENSION):
			r93_miss.append(r93_id)
	check(r93_miss.is_empty(),
		"R93「次元」覆盖 7 张消失卡（鸭蛋/鲸鱼之怒/魔像/预判/拒绝命运/警觉/荧光草；缺：%s）"
			% str(r93_miss))
	# ② 不变量一：引擎 trait「离场消失」的卡必须都有次元（以后加新 token 也不会漏）
	var r93_vanish_all: Array[int] = []
	var r93_vanish_bad: Array[int] = []
	for r93_c: CardData in r93_repo.all_cards():
		if r93_c.traits.has(FieldState.VANISH_TRAIT):
			r93_vanish_all.append(r93_c.id)
			if not r93_c.has_affix(GameEngine.AFFIX_DIMENSION):
				r93_vanish_bad.append(r93_c.id)
	check(r93_vanish_bad.is_empty() and r93_vanish_all.size() >= 3,
		"R93 不变量：带 trait「离场消失」的卡（%s）**全部**带次元（漏：%s）"
			% [str(r93_vanish_all), str(r93_vanish_bad)])
	# ③ 不变量二：卡面**不再手写**「消失」——全部交给字段解释
	var r93_left: Array[int] = []
	for r93_d: CardData in r93_repo.all_cards():
		if "消失" in r93_d.effect_text:
			r93_left.append(r93_d.id)
	check(r93_left.is_empty(),
		"R93 不变量：全库 effect_text **不再出现「消失」**（残留：%s）" % str(r93_left))
	# ④ 野兔本体：**没有**次元（它自己不会消失，消失的是它产出的复制品）
	check(r93_repo.get_card(9032).has_affix(GameEngine.AFFIX_PHANTOM)
			and not r93_repo.get_card(9032).has_affix(GameEngine.AFFIX_DIMENSION),
		"R93 野兔本体只有「幻影」、**没有**次元（消失的是复制品，不是它自己）")
	# ⑤ to_dict / from_dict 往返保留次元
	var r93_egg: CardData = r93_repo.get_card(9022)
	var r93_egg2 := CardData.from_dict(r93_egg.to_dict())
	check(r93_egg2.has_affix(GameEngine.AFFIX_DIMENSION)
			and (r93_egg2.affixes as Array).size() == (r93_egg.affixes as Array).size(),
		"R93 to_dict/from_dict 保留「次元」（复制/改造/离场还原都走这条通道）")

	# ---- ⑥ 衍生物：手牌里不带次元，**上场那一刻**才挂上 ----
	var r93_e := _new_engine([], 40, 40, -1, false)
	r93_e.start_game()
	r93_e.state.hand.clear()
	var r93_hare: CardData = CardData.from_dict(r93_repo.get_card(9032).to_dict())
	r93_e._spawn_self_clone(r93_hare)
	var r93_clone: CardData = r93_e.state.hand[0]
	check(r93_clone.is_ephemeral and r93_clone.has_affix(GameEngine.AFFIX_PHANTOM)
			and not r93_clone.has_affix(GameEngine.AFFIX_DIMENSION),
		"R93 衍生物在**手牌里**不带次元（那是「幻影」的回合结束消失，两者刻意区分）")
	var r93_clone_p: Placement = r93_e.state.place(r93_clone, Vector2i(4, 1),
			GameEngine.SIDE_SELF)
	check(r93_clone_p.card.has_affix(GameEngine.AFFIX_DIMENSION)
			and r93_clone_p.card.has_affix(GameEngine.AFFIX_PHANTOM),
		"R93 衍生物**上场后**挂上「次元」（离场即消失，不进弃牌区）")
	# 正常单位上场**不会**被误挂（卡库原卡没有 is_ephemeral）
	var r93_tree_p: Placement = r93_e.state.place(
		CardData.from_dict(r93_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	check(not r93_tree_p.card.has_affix(GameEngine.AFFIX_DIMENSION)
			and not r93_repo.get_card(8003).has_affix(GameEngine.AFFIX_DIMENSION),
		"R93 正常单位与**卡库原卡**都不会被挂上「次元」（没污染卡库）")
	# ⑦ 次元始终显示（不像疾行/护盾那样用掉就隐藏）
	check(r93_clone.active_affixes(1, false).has(GameEngine.AFFIX_DIMENSION),
		"R93「次元」在战场上**恒常显示**（不随行动轮数/护盾与否消失）")

	# ─────────── R95：加厚装甲 8044 / 自主升级 8045（机械之心）───────────
	var r95_repo := CardRepo.load_json()
	var r95_plate_def: CardData = r95_repo.get_card(GameEngine.ARMOR_PLATE_ID)
	var r95_auto_def: CardData = r95_repo.get_card(GameEngine.AUTO_UPGRADE_ID)
	check(r95_plate_def != null and r95_plate_def.kind == "技能" and r95_plate_def.cost == 1
			and r95_plate_def.rarity == 0 and r95_plate_def.card_class == PlayerClass.MECH
			and r95_plate_def.target_mode == "unit"
			and r95_plate_def.traits.has(GameEngine.UPGRADE_TRAIT),
		"R95 加厚装甲：技能 / 1 费 / **普通** / 机械之心 / 需选目标 / 带 trait「改造」")
	check(r95_auto_def != null and r95_auto_def.kind == "效果" and r95_auto_def.cost == 2
			and r95_auto_def.rarity == 0 and r95_auto_def.card_class == PlayerClass.MECH
			and r95_auto_def.target_mode == "none"
			and r95_auto_def.traits.has(GameEngine.AUTO_UPGRADE_TRAIT),
		"R95 自主升级：效果卡 / 2 费 / **普通** / 机械之心 / 无需目标 / 带 trait「自主改造」")

	# ---- ① 加厚装甲：己方盟友 +4 生命，且**算一层改造** ----
	var r95_e1 := _new_engine([], 40, 40, -1, false)
	r95_e1.start_game()
	var r95_tree: Placement = r95_e1.state.place(
		CardData.from_dict(r95_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r95_hp0: int = r95_tree.health
	var r95_msg1: String = r95_e1._armor_plate(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r95_tree.health == r95_hp0 + GameEngine.ARMOR_PLATE_HP
			and r95_tree.upgrade_hp == GameEngine.ARMOR_PLATE_HP
			and r95_tree.upgrade_stacks == 1,
		"R95 加厚装甲：己方盟友生命 +%d（%d→%d）、**算一层改造**（层数 %d）"
			% [GameEngine.ARMOR_PLATE_HP, r95_hp0, r95_tree.health, r95_tree.upgrade_stacks])
	# ⚠️ 只在场上有效：卡库原卡不能被改（否则跨 run 泄漏）
	check(r95_repo.get_card(8003).health == r95_hp0,
		"R95 加厚装甲：加成**没烤进卡库**（卡库树人仍 %d 血）" % r95_repo.get_card(8003).health)

	# ---- ② 工事不能选（用户口径「一个我方盟友」）----
	var r95_e2 := _new_engine([], 40, 40, -1, false)
	r95_e2.start_game()
	var r95_fence: Placement = r95_e2.state.place(
		CardData.from_dict(r95_repo.get_card(8001).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r95_fence_hp0: int = r95_fence.health
	var r95_msg2: String = r95_e2._armor_plate(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r95_fence.health == r95_fence_hp0 and r95_msg2.find("不是盟友") >= 0,
		"R95 加厚装甲：**工事不能选**（木栅栏仍 %d 血，提示「%s」）"
			% [r95_fence.health, r95_msg2])

	# ---- ③ 敌方单位不能选 ----
	var r95_e3 := _new_engine([], 40, 40, -1, false)
	r95_e3.start_game()
	var r95_foe: Placement = r95_e3.state.place(
		CardData.from_dict(r95_repo.get_card(8003).to_dict()), Vector2i(1, 0),
		GameEngine.SIDE_OPPONENT)
	var r95_foe_hp0: int = r95_foe.health
	var r95_msg3: String = r95_e3._armor_plate(Vector2i(1, 0), GameEngine.SIDE_SELF)
	check(r95_foe.health == r95_foe_hp0 and r95_msg3.find("只能改造自己") >= 0,
		"R95 加厚装甲：**敌方单位不能选**（仍 %d 血，提示「%s」）"
			% [r95_foe.health, r95_msg3])

	# ---- ④「算一层改造」的连带效果：接通的模仿者照常复制这次改造 ----
	var r95_e4 := _new_engine([], 40, 40, -1, false)
	r95_e4.start_game()
	var r95_t2: Placement = r95_e4.state.place(
		CardData.from_dict(r95_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r95_mim: Placement = r95_e4.state.place(
		CardData.from_dict(r95_repo.get_card(GameEngine.MIMIC_ID).to_dict()),
		Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r95_mim_hp0: int = r95_mim.health
	r95_e4._armor_plate(Vector2i(4, 0), GameEngine.SIDE_SELF)
	check(r95_mim.health == r95_mim_hp0 + GameEngine.ARMOR_PLATE_HP,
		"R95 加厚装甲算「改造」→ 接通的模仿者复制了同量改造（%d→%d）"
			% [r95_mim_hp0, r95_mim.health])

	# ---- ⑤ 自主升级：回合开始随机改造抽牌堆里 1 张（+2 攻 / +1 血）----
	var r95_base_p: int = r95_repo.get_card(8003).power
	var r95_base_h: int = r95_repo.get_card(8003).health
	var r95_e5 := _new_engine([], 40, 40, -1, false)
	r95_e5.start_game()
	r95_e5.state.deck = [
		CardData.from_dict(r95_repo.get_card(8003).to_dict()),
		CardData.from_dict(r95_repo.get_card(8003).to_dict())]
	r95_e5.state.effects.append(CardData.from_dict(r95_auto_def.to_dict()))
	r95_e5._auto_upgrade(GameEngine.SIDE_SELF)
	var r95_hit: int = 0
	for c: CardData in r95_e5.state.deck:
		if c.power == r95_base_p + GameEngine.AUTO_UPGRADE_ATK \
				and c.health == r95_base_h + GameEngine.AUTO_UPGRADE_HP:
			r95_hit += 1
	check(r95_hit == 1 and r95_e5.state.deck.size() == 2,
		"R95 自主升级：每回合只改造抽牌堆里 **1 张**（命中 %d 张，牌库仍 %d 张 —— 原位替换）"
			% [r95_hit, r95_e5.state.deck.size()])
	check(r95_repo.get_card(8003).power == r95_base_p
			and r95_repo.get_card(8003).health == r95_base_h,
		"R95 自主升级：**没污染卡库**（卡库树人仍 %d 攻 / %d 血）"
			% [r95_base_p, r95_base_h])
	# 不叠加：效果区有 2 张仍然只改造 1 张
	r95_e5.state.deck = [
		CardData.from_dict(r95_repo.get_card(8003).to_dict()),
		CardData.from_dict(r95_repo.get_card(8003).to_dict()),
		CardData.from_dict(r95_repo.get_card(8003).to_dict())]
	r95_e5.state.effects.append(CardData.from_dict(r95_auto_def.to_dict()))
	r95_e5._auto_upgrade(GameEngine.SIDE_SELF)
	r95_hit = 0
	for c: CardData in r95_e5.state.deck:
		if c.power == r95_base_p + GameEngine.AUTO_UPGRADE_ATK:
			r95_hit += 1
	check(r95_hit == 1,
		"R95 自主升级：**多张不叠加**（效果区 2 张仍只改造 %d 张）" % r95_hit)
	# 效果区没有这张卡 → 完全不触发
	var r95_e6 := _new_engine([], 40, 40, -1, false)
	r95_e6.start_game()
	r95_e6.state.deck = [CardData.from_dict(r95_repo.get_card(8003).to_dict())]
	r95_e6._auto_upgrade(GameEngine.SIDE_SELF)
	check(r95_e6.state.deck[0].power == r95_base_p,
		"R95 自主升级：效果区没有这张卡时**不触发**（牌库那张仍 %d 攻）"
			% r95_e6.state.deck[0].power)
	# 抽牌堆里没有盟友 / 工事 → 落空且不崩
	var r95_e7 := _new_engine([], 40, 40, -1, false)
	r95_e7.start_game()
	r95_e7.state.deck = [CardData.from_dict(r95_repo.get_card(8002).to_dict())]
	r95_e7.state.effects.append(CardData.from_dict(r95_auto_def.to_dict()))
	r95_e7._auto_upgrade(GameEngine.SIDE_SELF)
	check(r95_e7.state.deck.size() == 1 and r95_e7.state.deck[0].power == 0,
		"R95 自主升级：抽牌堆里没有盟友 / 工事时**落空**（技能卡不会被改造，仍 %d 攻）"
			% r95_e7.state.deck[0].power)

	# ─────────── R96：零件回收者 8046 / 嵌合暴君 8047 / 生产订单 8048（机械之心）───────────
	var r96_repo := CardRepo.load_json()
	var r96_rec_def: CardData = r96_repo.get_card(GameEngine.RECYCLER_ID)
	var r96_chi_def: CardData = r96_repo.get_card(GameEngine.CHIMERA_ID)
	var r96_ord_def: CardData = r96_repo.get_card(GameEngine.PROD_ORDER_ID)
	check(r96_rec_def != null and r96_rec_def.kind == "盟友" and r96_rec_def.cost == 3
			and r96_rec_def.power == 1 and r96_rec_def.health == 14
			and r96_rec_def.attack_range == 1 and r96_rec_def.move_speed == 1
			and r96_rec_def.rarity == 0 and r96_rec_def.card_class == PlayerClass.MECH
			and not r96_rec_def.has_affix("嘲讽"),
		"R96 零件回收者：盟友 / 3 费 1 攻 14 血 / 攻程 1 / 移速 1 / **普通** / 机械之心")
	check(r96_rec_def.traits.has("机械"),
		"R96 零件回收者：带 trait「机械」")
	check(r96_chi_def != null and r96_chi_def.kind == "盟友" and r96_chi_def.cost == 4
			and r96_chi_def.power == 3 and r96_chi_def.health == 20
			and r96_chi_def.attack_range == 1 and r96_chi_def.move_speed == 1
			and r96_chi_def.rarity == 3 and r96_chi_def.card_class == PlayerClass.MECH
			and r96_chi_def.traits.has("嘲讽") and r96_chi_def.has_affix("嘲讽"),
		"R96 嵌合暴君：盟友 / 4 费 3 攻 20 血 / 攻程 1 / 移速 1 / **史诗** / 机械之心 / 带嘲讽")
	check(r96_ord_def != null and r96_ord_def.kind == "技能" and r96_ord_def.cost == 1
			and r96_ord_def.rarity == 0 and r96_ord_def.card_class == PlayerClass.MECH
			and r96_ord_def.target_mode == "none"
			and r96_ord_def.traits.has("改造"),
		"R96 生产订单：技能 / 1 费 / **普通** / 机械之心 / 无需目标 / 带 trait「改造」")

	# ---- ① 零件回收者：接通的己方盟友被销毁 → 力量回收 + 手牌 +1 素体 ----
	var r96_e1 := _new_engine([], 40, 40, -1, false)
	r96_e1.start_game()
	var r96_rec1: Placement = r96_e1.state.place(
		CardData.from_dict(r96_rec_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r96_tree1: Placement = r96_e1.state.place(
		CardData.from_dict(r96_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r96_tree_pow: int = r96_tree1.effective_power()
	var r96_hand0: int = r96_e1.state.hand.size()
	r96_e1._destroy(Vector2i(4, 0))
	check(r96_rec1.upgrade_atk == r96_tree_pow,
		"R96 零件回收者：接通的己方盟友被销毁 → 攻击力 += 那张卡的力量（%d → +%d）"
			% [r96_tree_pow, r96_rec1.upgrade_atk])
	check(r96_e1.state.hand.size() == r96_hand0 + 1
			and r96_e1.state.hand[r96_e1.state.hand.size() - 1].id == GameEngine.PROTO_ID,
		"R96 零件回收者：同步往手牌加 1 张「素体」（手牌 %d→%d，末张 id=%d）"
			% [r96_hand0, r96_e1.state.hand.size(), GameEngine.PROTO_ID])
	check(not r96_e1.state.board.has(Vector2i(4, 0)),
		"R96 零件回收者：被销毁的盟友确实已离场")

	# ---- ② 零件回收者：**不接通不触发** ----
	var r96_e2 := _new_engine([], 40, 40, -1, false)
	r96_e2.start_game()
	var r96_rec2: Placement = r96_e2.state.place(
		CardData.from_dict(r96_rec_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r96_iso2: Placement = r96_e2.state.place(
		CardData.from_dict(r96_repo.get_card(8003).to_dict()), Vector2i(0, 0),
		GameEngine.SIDE_SELF)
	var r96_hand2: int = r96_e2.state.hand.size()
	r96_e2._destroy(Vector2i(0, 0))
	check(r96_rec2.upgrade_atk == 0 and r96_e2.state.hand.size() == r96_hand2,
		"R96 零件回收者：孤立的 (0,0) 不接通 → 不回收、不加素体（仍 %d 攻 / 手牌 %d）"
			% [r96_rec2.upgrade_atk, r96_e2.state.hand.size()])

	# ---- ③ 零件回收者：**只回收己方**销毁（相邻敌方被销毁不触发）----
	var r96_e3 := _new_engine([], 40, 40, -1, false)
	r96_e3.start_game()
	var r96_rec3: Placement = r96_e3.state.place(
		CardData.from_dict(r96_rec_def.to_dict()), Vector2i(3, 1), GameEngine.SIDE_SELF)
	r96_e3.state.place(
		CardData.from_dict(_card(9201, "测试骷髅", "怪物", 1, 3, 6, 1, 1).to_dict()),
		Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r96_hand3: int = r96_e3.state.hand.size()
	r96_e3._destroy(Vector2i(2, 1))
	check(r96_rec3.upgrade_atk == 0 and r96_e3.state.hand.size() == r96_hand3,
		"R96 零件回收者：**只回收己方**——相邻敌方被销毁不触发（仍 %d 攻 / 手牌 %d）"
			% [r96_rec3.upgrade_atk, r96_e3.state.hand.size()])

	# ---- ④ 嵌合暴君：使用时破坏接通的己方卡并吸收攻/血 ----
	var r96_e4 := _new_engine([], 40, 40, -1, false)
	r96_e4.start_game()
	var r96_tree4: Placement = r96_e4.state.place(
		CardData.from_dict(r96_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)
	var r96_tree4_pow: int = r96_tree4.effective_power()
	var r96_tree4_hp: int = r96_tree4.card.health
	var r96_chi4: Placement = r96_e4.state.place(
		CardData.from_dict(r96_chi_def.to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r96_chi4_atk0: int = r96_chi4.effective_power()
	var r96_chi4_hp0: int = r96_chi4.health
	r96_e4._chimera_fuse(r96_chi4)
	check(not r96_e4.state.board.has(Vector2i(4, 0)),
		"R96 嵌合暴君：接通的己方盟友被**破坏**（(4,0) 已离场）")
	check(r96_chi4.upgrade_atk == r96_tree4_pow
			and r96_chi4.upgrade_hp == r96_tree4_hp
			and r96_chi4.effective_power() == r96_chi4_atk0 + r96_tree4_pow
			and r96_chi4.health == r96_chi4_hp0 + r96_tree4_hp,
		"R96 嵌合暴君：吸收力量 %d / 生命 %d（现 %d 攻 / %d 血）"
			% [r96_tree4_pow, r96_tree4_hp, r96_chi4.effective_power(), r96_chi4.health])

	# ---- ⑤ 嵌合暴君：**只吸收己方**（相邻敌方未被破坏也未吸收）----
	var r96_e5 := _new_engine([], 40, 40, -1, false)
	r96_e5.start_game()
	r96_e5.state.place(
		CardData.from_dict(_card(9201, "测试骷髅", "怪物", 1, 3, 6, 1, 1).to_dict()),
		Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r96_chi5: Placement = r96_e5.state.place(
		CardData.from_dict(r96_chi_def.to_dict()), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var r96_chi5_atk0: int = r96_chi5.effective_power()
	var r96_chi5_hp0: int = r96_chi5.health
	r96_e5._chimera_fuse(r96_chi5)
	check(r96_e5.state.board.has(Vector2i(2, 1))
			and r96_chi5.upgrade_atk == 0 and r96_chi5.upgrade_hp == 0
			and r96_chi5.effective_power() == r96_chi5_atk0
			and r96_chi5.health == r96_chi5_hp0,
		"R96 嵌合暴君：**只吸收己方**——相邻敌方卡未被破坏也未吸收（敌 %d 仍在场，暴君仍 %d 攻 / %d 血）"
			% [9201, r96_chi5.effective_power(), r96_chi5.health])

	# ---- ⑥ 嵌合暴君：离场还原成原卡，不污染卡库 ----
	var r96_leave: CardData = r96_e4._card_leaving_field(r96_chi4)
	check(r96_leave != null and r96_leave.health == 20 and r96_leave.power == 3
			and r96_repo.get_card(GameEngine.CHIMERA_ID).health == 20
			and r96_repo.get_card(GameEngine.CHIMERA_ID).power == 3,
		"R96 嵌合暴君：离场还原成原卡（%d 攻 / %d 血），且卡库未被污染"
			% [r96_leave.power if r96_leave != null else -1,
				r96_leave.health if r96_leave != null else -1])

	# ---- ⑦ 生产订单：抽牌堆加 2 张改造素体，不污染卡库 ----
	var r96_e7 := _new_engine([], 40, 40, -1, false)
	r96_e7.start_game()
	r96_e7.state.deck = [CardData.from_dict(r96_repo.get_card(8003).to_dict())]
	var r96_deck0: int = r96_e7.state.deck.size()
	var r96_proto_pow: int = r96_repo.get_card(GameEngine.PROTO_ID).power
	var r96_proto_hp: int = r96_repo.get_card(GameEngine.PROTO_ID).health
	r96_e7._production_order(GameEngine.SIDE_SELF)
	check(r96_e7.state.deck.size() == r96_deck0 + 2,
		"R96 生产订单：抽牌堆 +2 张（%d→%d）" % [r96_deck0, r96_e7.state.deck.size()])
	var r96_added: int = 0
	for c: CardData in r96_e7.state.deck:
		if c.id == GameEngine.PROTO_ID and c.power == r96_proto_pow + GameEngine.PROD_ORDER_ATK \
				and c.health == r96_proto_hp + GameEngine.PROD_ORDER_HP:
			r96_added += 1
	check(r96_added == 2,
		"R96 生产订单：新增的 2 张都是改造素体（力量 %d→%d / 生命 %d→%d，命中 %d 张）"
			% [r96_proto_pow, r96_proto_pow + GameEngine.PROD_ORDER_ATK,
				r96_proto_hp, r96_proto_hp + GameEngine.PROD_ORDER_HP, r96_added])
	check(r96_repo.get_card(GameEngine.PROTO_ID).power == r96_proto_pow
			and r96_repo.get_card(GameEngine.PROTO_ID).health == r96_proto_hp,
		"R96 生产订单：**没污染卡库**（卡库素体仍 %d 攻 / %d 血）"
			% [r96_proto_pow, r96_proto_hp])

	# ─────────── R97：拆解 8049（机械之心 稀有技能）───────────
	var r97_repo := CardRepo.load_json()
	var r97_def: CardData = r97_repo.get_card(GameEngine.DEMOLISH_ID)
	check(r97_def != null and r97_def.kind == "技能" and r97_def.cost == 1
			and r97_def.rarity == 1 and r97_def.card_class == PlayerClass.MECH
			and r97_def.target_mode == "unit"
			and r97_def.traits.has("机械") and r97_def.traits.has("改造"),
		"R97 拆解：技能 / 1 费 / **稀有** / 机械之心 / 需选单位 / trait 机械+改造")

	# ---- ① 拆解未改造己方盟友：破坏 + 回 3 费 + 手牌+素体，无额外升级 ----
	var r97_e1 := _new_engine([], 40, 40, -1, false)
	r97_e1.start_game()
	r97_e1.state.place(
		CardData.from_dict(r97_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	var r97_energy1: int = r97_e1.state.energy
	var r97_hand1: int = r97_e1.state.hand.size()
	r97_e1._demolish(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(not r97_e1.state.board.has(Vector2i(4, 1)),
		"R97 拆解：未改造己方盟友被**破坏**（(4,1) 已离场）")
	check(r97_e1.state.energy == r97_energy1 + GameEngine.DEMOLISH_REFUND,
		"R97 拆解：回复 %d 点费用（%d → %d）"
			% [GameEngine.DEMOLISH_REFUND, r97_energy1, r97_e1.state.energy])
	check(r97_e1.state.hand.size() == r97_hand1 + 1
			and r97_e1.state.hand[r97_e1.state.hand.size() - 1].id == GameEngine.PROTO_ID,
		"R97 拆解：手牌 +1 张「素体」（未改造不额外给升级）")
	check(not r97_e1.state.hand.any(func(c): return c.id == GameEngine.DEMOLISH_UPGRADE_BONUS),
		"R97 拆解：未改造目标**没有**额外获得「升级」")

	# ---- ② 拆解被改造己方盟友：额外手牌+1 升级 ----
	var r97_e2 := _new_engine([], 40, 40, -1, false)
	r97_e2.start_game()
	r97_e2.state.place(
		CardData.from_dict(r97_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r97_e2._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)   # 标记被改造
	check(r97_e2._is_upgraded(r97_e2.state.unit_at(Vector2i(4, 1))),
		"R97 前置：盟友已被改造")
	var r97_hand2: int = r97_e2.state.hand.size()
	r97_e2._demolish(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r97_e2.state.hand.size() == r97_hand2 + 2,
		"R97 拆解：被改造目标 → 手牌 +2（素体 + 升级，手牌 %d→%d）"
			% [r97_hand2, r97_e2.state.hand.size()])
	check(r97_e2.state.hand.any(func(c): return c.id == GameEngine.DEMOLISH_UPGRADE_BONUS),
		"R97 拆解：被改造目标**额外获得**一张「升级」8027")

	# ---- ③ 拆解敌方 / 非己方单位：被拒，不改费用不破坏 ----
	var r97_e3 := _new_engine([], 40, 40, -1, false)
	r97_e3.start_game()
	r97_e3.state.place(
		CardData.from_dict(_card(9201, "测试骷髅", "怪物", 1, 3, 6, 1, 1).to_dict()),
		Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r97_energy3: int = r97_e3.state.energy
	r97_e3._demolish(Vector2i(2, 1), GameEngine.SIDE_SELF)
	check(r97_e3.state.board.has(Vector2i(2, 1)) and r97_e3.state.energy == r97_energy3,
		"R97 拆解：敌方单位被拒（不破坏、不回费，仍在场）")

	# ---- ④ 拆解走唯一破坏口 → 联动零件回收者 8046 ----
	var r97_e4 := _new_engine([], 40, 40, -1, false)
	r97_e4.start_game()
	var r97_rec4: Placement = r97_e4.state.place(
		CardData.from_dict(r97_repo.get_card(GameEngine.RECYCLER_ID).to_dict()),
		Vector2i(3, 1), GameEngine.SIDE_SELF)
	var r97_tree4: Placement = r97_e4.state.place(
		CardData.from_dict(r97_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	var r97_tree4_pow: int = r97_tree4.effective_power()
	r97_e4._demolish(Vector2i(4, 1), GameEngine.SIDE_SELF)   # 回收者与(4,1)相邻 → 被联动
	check(r97_rec4.upgrade_atk == r97_tree4_pow,
		"R97 拆解：经 _destroy 联动零件回收者 → 回收力量 %d" % r97_tree4_pow)

	# ---- ⑤ 自动出牌：优先选「被改造」的己方盟友/工事 ----
	var r97_e5 := _new_engine([], 40, 40, -1, false)
	r97_e5.start_game()
	r97_e5.state.place(
		CardData.from_dict(r97_repo.get_card(8003).to_dict()), Vector2i(4, 0),
		GameEngine.SIDE_SELF)                       # 未改造
	r97_e5.state.place(
		CardData.from_dict(r97_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)                       # 待改造
	r97_e5._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)   # (4,1) 被改造
	var r97_tg: Array[Vector2i] = r97_e5._autoplay_spell_targets(r97_def)
	check(r97_tg.size() == 1 and r97_tg[0] == Vector2i(4, 1),
		"R97 拆解自动出牌：优先选**被改造**的己方单位 (4,1)，而非未改造的 (4,0)（实际 %s）"
			% str(r97_tg))

	# ══════════════════════════════════════════════════════════════
	# R98 测试：新字段「超负荷」（旧式机兵 8050）—— 死亡延迟到己方回合结束
	# ══════════════════════════════════════════════════════════════
	var r98_repo := CardRepo.load_json()
	var r98_def := r98_repo.get_card(8050)
	check(r98_def != null and r98_def.has_affix("超负荷"),
		"R98 旧式机兵 8050：存在且带「超负荷」字段（实际 %s）"
			% ("" if r98_def == null else str(r98_def.affixes)))
	check(r98_def.rarity == 0 and r98_def.card_class == "机械之心"
		and r98_def.kind == "盟友" and r98_def.power == 3 and r98_def.health == 12,
		"R98 旧式机兵：3 费普通盟友 3/12/1/1，机械之心（实际 %s）"
			% [r98_def.rarity, r98_def.card_class, r98_def.kind, r98_def.power, r98_def.health])

	# ---- ① 超负荷单位：负血仍存活，且不触发溢出伤害 ----
	var r98_e := _new_engine([], 40, 40, -1, false)
	r98_e.start_game()
	var r98_mech: Placement = r98_e.state.place(
		CardData.from_dict(r98_repo.get_card(8050).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	var r98_hp0: int = r98_e.state.hp_self
	# 一发造成远超血量的伤害 → 生命应降到负数，但单位不死、不漏血给玩家
	r98_e._hit_unit(r98_mech, 50, "测试")
	check(r98_mech.health < 0,
		"R98 超负荷：生命降到 %d（负数），仍存活（未从 board 移除）" % r98_mech.health)
	check(r98_e.state.unit_at(Vector2i(4, 1)) == r98_mech,
		"R98 超负荷：负血单位仍在场上（_destroy_dead 跳过了它）")
	check(r98_e.state.hp_self == r98_hp0,
		"R98 超负荷：负血不触发「溢出伤害」漏给玩家 HP（仍为 %d）" % r98_e.state.hp_self)

	# ---- ② 普通单位：负血立即死亡 ----
	var r98_e2 := _new_engine([], 40, 40, -1, false)
	r98_e2.start_game()
	var r98_norm: Placement = r98_e2.state.place(
		CardData.from_dict(r98_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r98_e2._hit_unit(r98_norm, 50, "测试")
	r98_e2._destroy_dead()   # 显式触发死亡扫描（_hit_unit 本身不销毁）
	check(r98_e2.state.unit_at(Vector2i(4, 1)) == null,
		"R98 对照：无超负荷的普通单位负血立即死亡（对照正确性）")

	# ---- ③ 己方回合结束：负血超负荷单位真正死亡；回正的不死 ----
	var r98_e3 := _new_engine([], 40, 40, -1, false)
	r98_e3.start_game()
	var r98_die: Placement = r98_e3.state.place(
		CardData.from_dict(r98_repo.get_card(8050).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)
	r98_e3._hit_unit(r98_die, 50, "测试")          # 生命 -38
	var r98_live: Placement = r98_e3.state.place(
		CardData.from_dict(r98_repo.get_card(8050).to_dict()), Vector2i(4, 2),
		GameEngine.SIDE_SELF)
	r98_e3._hit_unit(r98_live, 14, "测试")          # 生命 -2
	r98_e3._op_heal(GameEngine.SIDE_SELF, 20, Vector2i(4, 2))  # 拉回 +18（>0）
	check(r98_live.health > 0, "R98 前置：被治疗的超负荷单位生命已回到 %d" % r98_live.health)
	r98_e3.end_turn()   # 我方回合结束 → _overload_tick(SIDE_SELF)
	check(r98_e3.state.unit_at(Vector2i(4, 1)) == null,
		"R98 超负荷：己方回合结束、生命仍为负 → 死亡（(4,1) 已移除）")
	check(r98_e3.state.unit_at(Vector2i(4, 2)) != null,
		"R98 超负荷：己方回合结束、生命已回正 → 继续存活（(4,2) 仍在）")
	check(r98_e3.state.unit_at(Vector2i(4, 2)).health > 0,
		"R98 超负荷：存活单位生命保持正数 %d" % r98_e3.state.unit_at(Vector2i(4, 2)).health)

	# ══════════════════════════════════════════════════════════════
	# R99 测试：重组 8051 / 城墙 8052 / 超越极限 8053
	# ══════════════════════════════════════════════════════════════
	var r99_repo := CardRepo.load_json()
	# ---- 卡面定义校验 ----
	var r99_reorg := r99_repo.get_card(8051)
	check(r99_reorg != null and r99_reorg.kind == "技能" and r99_reorg.cost == 1
			and r99_reorg.rarity == 3 and r99_reorg.card_class == "机械之心"
			and r99_reorg.target_mode == "unit"
			and r99_reorg.effect_text.contains("满生命"),
		"R99 重组 8051：1 费史诗技能，机械之心，target=unit，回满生命（实际 %s）"
			% [r99_reorg.kind, r99_reorg.cost, r99_reorg.rarity, r99_reorg.target_mode])
	var r99_wall := r99_repo.get_card(8052)
	check(r99_wall != null and r99_wall.kind == "工事" and r99_wall.cost == 2
			and r99_wall.power == 0 and r99_wall.health == 10
			and r99_wall.rarity == 0 and r99_wall.has_affix("超负荷")
			and r99_wall.card_class == "机械之心",
		"R99 城墙 8052：2 费普通工事 0/10/0，带超负荷，机械之心（实际 %s）"
			% [r99_wall.kind, r99_wall.cost, r99_wall.power, r99_wall.health, r99_wall.rarity])
	var r99_trans := r99_repo.get_card(8053)
	check(r99_trans != null and r99_trans.kind == "技能" and r99_trans.cost == 0
			and r99_trans.rarity == 1 and r99_trans.card_class == "机械之心"
			and r99_trans.has_affix("次元") and r99_trans.target_mode == "unit"
			and r99_trans.effect_text.contains("超负荷"),
		"R99 超越极限 8053：0 费稀有技能，次元，机械之心，target=unit，挂超负荷（实际 %s）"
			% [r99_trans.kind, r99_trans.cost, r99_trans.rarity, r99_trans.target_mode])

	# ---- ① 重组：把受伤单位回满（含改造后的上限）----
	var r99_e1 := _new_engine([], 40, 40, -1, false)
	r99_e1.start_game()
	var r99_u1: Placement = r99_e1.state.place(
		CardData.from_dict(r99_repo.get_card(8003).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)   # 树人 3/8
	r99_e1._hit_unit(r99_u1, 5, "测试")   # 8 → 3
	check(r99_u1.health == 3, "R99 前置：树人被打到 %d 血" % r99_u1.health)
	r99_e1._reorganize(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r99_u1.health == 8, "R99 重组：受伤单位被回复至满生命 8（实际 %d）" % r99_u1.health)
	var r99_u2: Placement = r99_e1.state.place(
		CardData.from_dict(r99_repo.get_card(8025).to_dict()), Vector2i(4, 2),
		GameEngine.SIDE_SELF)   # 素体 0/1
	r99_e1._upgrade_unit(Vector2i(4, 2), GameEngine.SIDE_SELF)  # +2 攻 +8 血 → 卡面 0/9
	check(r99_u2.card.health == 10, "R99 前置：素体被改造后卡面生命 %d" % r99_u2.card.health)
	r99_e1._reorganize(Vector2i(4, 2), GameEngine.SIDE_SELF)
	check(r99_u2.health == 10, "R99 重组：已满血单位回满不变（仍为 %d）" % r99_u2.health)

	# ---- ② 超越极限：挂超负荷 + 算一层改造；不污染卡库；重复被拒 ----
	var r99_e2 := _new_engine([], 40, 40, -1, false)
	r99_e2.start_game()
	var r99_t1: Placement = r99_e2.state.place(
		CardData.from_dict(r99_repo.get_card(8025).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)   # 素体 0/1，未改造、无超负荷
	var stacks0: int = r99_t1.upgrade_stacks
	r99_e2._transcend(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r99_t1.card.has_affix("超负荷"),
		"R99 超越极限：目标获得「超负荷」字段（实际 %s）" % str(r99_t1.card.affixes))
	check(r99_t1.upgrade_stacks == stacks0 + 1,
		"R99 超越极限：目标改造层数 +1（%d → %d）" % [stacks0, r99_t1.upgrade_stacks])
	check(not r99_repo.get_card(8025).has_affix("超负荷"),
		"R99 超越极限：卡库里的素体未被污染（仍无超负荷）")
	var dup_res := r99_e2._transcend(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(dup_res.contains("已拥有"), "R99 超越极限：对已超负荷单位重复给被拒（%s）" % dup_res)

	# ---- ③ 超越极限 + 模仿者：接通的己方模仿者同样获得超负荷 + 一层改造；不连锁 ----
	var r99_e3 := _new_engine([], 40, 40, -1, false)
	r99_e3.start_game()
	var r99_mim: Placement = r99_e3.state.place(
		CardData.from_dict(r99_repo.get_card(8043).to_dict()), Vector2i(4, 2),
		GameEngine.SIDE_SELF)   # 模仿者 0/10
	r99_e3.state.place(
		CardData.from_dict(r99_repo.get_card(8025).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)   # 素体 0/1（与模仿者四方向相邻 → 接通）
	var mim_stacks0: int = r99_mim.upgrade_stacks
	r99_e3._transcend(Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r99_mim.card.has_affix("超负荷"),
		"R99 超越极限：接通的模仿者也被传导获得「超负荷」（实际 %s）" % str(r99_mim.card.affixes))
	check(r99_mim.upgrade_stacks == mim_stacks0 + 1,
		"R99 超越极限：模仿者改造层数 +1（%d → %d）" % [mim_stacks0, r99_mim.upgrade_stacks])
	var r99_tgt: Placement = r99_e3.state.unit_at(Vector2i(4, 1))
	check(r99_tgt.upgrade_stacks == 1,
		"R99 超越极限：不连锁 —— 素体只被改一次（层数 %d）" % r99_tgt.upgrade_stacks)

	# ---- ④ 城墙：带超负荷，负血存活、己方回合结束负血则死 ----
	var r99_e4 := _new_engine([], 40, 40, -1, false)
	r99_e4.start_game()
	var r99_wall_u: Placement = r99_e4.state.place(
		CardData.from_dict(r99_repo.get_card(8052).to_dict()), Vector2i(4, 1),
		GameEngine.SIDE_SELF)   # 城墙 0/10
	check(r99_wall_u.card.has_affix("超负荷"), "R99 前置：城墙带超负荷")
	r99_e4._hit_unit(r99_wall_u, 50, "测试")   # 10 → -40
	check(r99_wall_u.health < 0 and r99_e4.state.unit_at(Vector2i(4, 1)) != null,
		"R99 城墙：负血仍存活（生命 %d，仍在场）" % r99_wall_u.health)
	r99_e4.end_turn()   # _overload_tick(SIDE_SELF)
	check(r99_e4.state.unit_at(Vector2i(4, 1)) == null,
		"R99 城墙：己方回合结束、生命仍为负 → 死亡")

	RunState.player_class = r91_saved_cls

	print("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")
	quit(1 if fails > 0 else 0)
