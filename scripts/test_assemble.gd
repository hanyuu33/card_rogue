extends SceneTree
const Rules = preload("res://scripts/assemble_rules.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)
func _init() -> void:
	var base := CardData.new()
	base.card_name = "测试拼装体"
	base.kind = "盟友"
	base.health = 10
	base.power = 2
	base.cost = 0
	base.traits.append("拼装")
	base.assemble_pool = "test"
	var upper := [{"trigger":"use", "effects":[{"type":"draw", "value":1}]}, {"trigger":"death", "effects":[{"type":"damage", "value":2}]}, {"trigger":"upgraded", "effects":[{"type":"buff", "value":1}]}]
	var lower := [{"effects":[{"type":"damage", "value":3}]}, {"effects":[{"type":"draw", "value":2}]}, {"effects":[{"type":"taunt"}]}]
	for u in upper:
		for l in lower:
			for reverse in [false, true]:
				var card := Rules.build(base, u, l, reverse)
				check(card != null and card.assemble.effects.size() == 2, "18 combinations build")
				check(card.assemble.effects[0] == (l.effects[0] if reverse else u.effects[0]), "order")
				var copy := CardData.from_dict(card.to_dict())
				copy.assemble.effects[0].type = "shield"
				check(card.assemble.effects[0].type != "shield", "deep copy")
	var state := FieldState.new([], 20, 20, -1, "测试", false)
	var eng := GameEngine.new(state)
	eng.ai_enabled = false
	check(eng.register_assemble_pool("test", upper, lower), "register")
	check(not eng.register_assemble_pool("bad", [{"trigger":"kill"}], lower), "unsupported trigger")
	state.hand.append(base)
	check(eng.assemble_begin(0, Vector2i(4, 1)), "begin")
	check(state.hand[0] == base, "no mutation while picking")
	check(eng.assemble_choose(2) and eng.assemble_choose(2), "pick fragments")
	check(eng.assemble_choices().size() == 2, "two order previews")
	check(eng.assemble_choose(0), "commit")
	var p: Placement = state.unit_at(Vector2i(4, 1))
	check(p != null, "unit placed")
	if p != null:
		eng._on_unit_upgraded(p)
		check(p.upgrade_atk == 1 and p.health == 11 and p.card.affixes.has("嘲讽"), "upgrade dispatch")
		check(eng._card_leaving_field(p).health == 10, "temporary buff restored")
		check(not eng._card_leaving_field(p).assemble.is_empty(), "assembly survives bounce")
		for trigger in ["enter", "death", "turn_end", "use"]:
			p.card.assemble = {"trigger":trigger, "effects":[{"type":"shield"}]}
			p.first_hit_shield = false
			match trigger:
				"enter": eng._on_ally_entered(p, "self")
				"death": eng._deathrattle(Vector2i(4, 1), p)
				"turn_end": eng._assemble_tick("self", trigger)
				"use": eng._assemble_execute(p, Vector2i(4, 1), trigger)
			check(p.first_hit_shield, "dispatch " + trigger)
	var foe_card := CardData.from_dict(base.to_dict())
	foe_card.traits.clear()
	foe_card.health = 30
	var foe := state.place(foe_card, Vector2i(2, 1), "opponent")
	p.card.assemble = {"trigger":"use", "effects":[{"type":"damage", "value":3, "target":"nearest"}, {"type":"heal", "value":2}]}
	p.health = 5
	eng._assemble_execute(p, Vector2i(4, 1), "use")
	check(foe.health == 27 and p.health == 7, "damage and heal")
	var second := CardData.from_dict(base.to_dict())
	second.traits.clear()
	second.assemble = {"trigger":"use", "effects":[{"type":"shield"}]}
	state.hand.append(second)
	var used := eng.play_from_hand(state.hand.find(second), Vector2i(5, 0))
	check(used != null and used.first_hit_shield, "actual use hook")
	state.hand.append(base)
	check(eng.assemble_begin(state.hand.find(base), Vector2i(5, 2)), "begin second selection")
	var turn := eng.current_side
	eng.end_turn()
	check(eng.current_side == turn, "pending blocks turn")
	eng.assemble_cancel()
	check(state.hand.has(base) and base.assemble.is_empty(), "cancel preserves source")
	_test_extended_triggers()
	_test_source_locks()
	_test_new_actions()
	_test_formal_pool()
	print("Assembly tests failures: ", failures)
	quit(failures)

func _probe_unit(eng: GameEngine, trigger: String, cell := Vector2i(3, 0), side := "self") -> Placement:
	var card := CardData.new()
	card.kind = "盟友"
	card.card_name = "时机探针"
	card.health = 100
	card.power = 1
	card.attack_range = 2
	card.assemble = {"trigger": trigger, "effects": [{"type":"buff", "value":1}]}
	return eng.state.place(card, cell, side)

func _test_extended_triggers() -> void:
	var lower := [{"effects":[{"type":"shield"}]}]
	for trigger in Rules.TRIGGERS:
		check(Rules.valid_pool([{"trigger":trigger,"effects":[]}], lower), "pure timing " + trigger)
	for trigger in ["card_played", "kill", "random_gained"]:
		check(not Rules.valid_pool([{"trigger":trigger}], lower), "excluded " + trigger)
		var blocked := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
		var p := _probe_unit(blocked, trigger)
		blocked._assemble_execute(p, Vector2i(3, 0), trigger)
		check(p.upgrade_atk == 0, "serialized forbidden trigger inert")
	for trigger in ["turn_start", "attack", "attacked", "damaged", "effect_played", "turn_first_play", "action_end", "after_draw"]:
		var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
		eng.ai_enabled = false
		var p := _probe_unit(eng, trigger)
		var foe := _probe_unit(eng, "", Vector2i(2, 0), "opponent")
		match trigger:
			"turn_start": eng._begin_turn("self")
			"attack": eng.attack(Vector2i(3, 0), Vector2i(2, 0))
			"attacked": eng.attack(Vector2i(2, 0), Vector2i(3, 0), "opponent")
			"damaged":
				p.first_hit_shield = true
				eng._hit_unit(p, 3)
				check(p.upgrade_atk == 0, "shield does not count as damage")
				eng._hit_unit(p, 3)
			"effect_played": eng._on_effect_card_played("self", CardData.new())
			"turn_first_play":
				eng._note_card_played("self", CardData.new())
				eng._note_card_played("self", CardData.new())
			"action_end": eng._tap(p)
			"after_draw":
				eng.state.deck.append(CardData.new())
				eng._draw_many(1)
		check(p.upgrade_atk == 1, "exactly once: " + trigger)
		check(foe.upgrade_atk == 0, "owner scope: " + trigger)
	var loop := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	var drawer := _probe_unit(loop, "after_draw")
	drawer.card.assemble.effects = [{"type":"draw", "value":1}]
	for i in 5:
		loop.state.deck.append(CardData.new())
	loop._draw_many(1)
	check(loop.state.hand.size() == 2, "draw loop bounded")
	loop._draw_many(1)
	check(loop.state.hand.size() == 4, "independent draw triggers again")

func _test_source_locks() -> void:
	# 源码锁：13 个时机都要挂在引擎的对应统一口上，防后续重构漏挂。
	# 第 3 项 = 最少出现次数（attack / damaged / after_draw 覆盖多条路径，故 ≥2）。
	var eng := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	var rules := FileAccess.get_file_as_string("res://scripts/assemble_rules.gd")
	var hooks: Array = [
		["use", "_assemble_execute(p, cell, \"use\")", 1],
		["enter", "_assemble_execute(p, _cell_of(p), \"enter\")", 1],
		["death", "_assemble_execute(p, cell, \"death\")", 1],
		["upgraded", "_assemble_execute(p, _cell_of(p), \"upgraded\")", 1],
		["turn_end", "_assemble_tick(current_side, \"turn_end\")", 1],
		["turn_start", "_assemble_tick(side, \"turn_start\")", 1],
		["attack", "_assemble_execute(attacker, _cell_of(attacker), \"attack\")", 2],
		["attacked", "_assemble_execute(defender, dst, \"attacked\")", 1],
		["damaged", "_assemble_execute(p, _cell_of(p), \"damaged\")", 2],
		["effect_played", "_assemble_tick(side, \"effect_played\")", 1],
		["turn_first_play", "_assemble_tick(side, \"turn_first_play\")", 1],
		["after_draw", "_assemble_tick(SIDE_SELF, \"after_draw\")", 2],
		["action_end", "_assemble_execute(p, _cell_of(p), \"action_end\")", 1],
	]
	for h in hooks:
		check(eng.count(str(h[1])) >= int(h[2]), "源码锁：挂接点 " + str(h[0]))
	# 黑名单（card_played/kill）/ 暂缓（random_gained）常量声明存在；
	# 执行层由 TRIGGERS 排除（三者不在 TRIGGERS），行为测试已覆盖 inert。
	check(rules.count("BLACKLIST") >= 1 and rules.count("DEFERRED") >= 1, "源码锁：黑名单/暂缓常量")
	check(rules.count("\"card_played\"") >= 1 and rules.count("\"kill\"") >= 1
			and rules.count("\"random_gained\"") >= 1, "源码锁：黑名单三时机声明")
	# 防重入标记 + 抽牌双口（after_draw 经 _draw_many / _assemble_draw_one / _assemble_opponent_draw 覆盖）
	check(eng.count("_assemble_active") >= 3, "源码锁：防重入标记")
	check(eng.count("_assemble_opponent_draw") >= 3 and eng.count("_assemble_draw_one") >= 3,
			"源码锁：抽牌双口覆盖")

func _test_new_actions() -> void:
	# energy：回复费用
	var e1 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e1.ai_enabled = false
	var p1 := _probe_unit(e1, "use")
	e1.state.energy = 0
	p1.card.assemble = {"trigger":"use", "effects":[{"type":"energy","value":3}]}
	e1._assemble_execute(p1, Vector2i(3, 0), "use")
	check(e1.state.energy == 3, "energy gain")
	# upgrade：永久改造 +N力+N生，记层
	var e2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e2.ai_enabled = false
	var p2 := _probe_unit(e2, "use")
	p2.upgrade_stacks = 0
	var hp0: int = p2.health
	p2.card.assemble = {"trigger":"use", "effects":[{"type":"upgrade","value":2}]}
	e2._assemble_execute(p2, Vector2i(3, 0), "use")
	check(p2.upgrade_atk == 2 and p2.upgrade_hp == 2 and p2.upgrade_stacks == 1, "upgrade permanent +stack")
	check(p2.health == hp0 + 2, "upgrade hp")
	# summon：召唤 2 个骷髅（9029）
	var e3 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e3.ai_enabled = false
	var p3 := _probe_unit(e3, "use")
	p3.card.assemble = {"trigger":"use", "effects":[{"type":"summon","value":9029,"count":2}]}
	e3._assemble_execute(p3, Vector2i(3, 0), "use")
	var tokens := 0
	for c: Vector2i in e3.state.board:
		if e3.state.board[c].card.id == 9029:
			tokens += 1
	check(tokens == 2, "summon two tokens")
	# damage random：随机打一个敌人
	var e4 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e4.ai_enabled = false
	var p4 := _probe_unit(e4, "use")
	var foe := _probe_unit(e4, "", Vector2i(2, 0), "opponent")
	var foe2 := _probe_unit(e4, "", Vector2i(2, 1), "opponent")
	foe.health = 50
	foe2.health = 50
	p4.card.assemble = {"trigger":"use", "effects":[{"type":"damage","value":5,"target":"random"}]}
	e4._assemble_execute(p4, Vector2i(3, 0), "use")
	check(foe.health + foe2.health == 95, "damage random hits exactly one")
	# knockback：击退最近敌人 2 格
	var e5 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e5.ai_enabled = false
	var p5 := _probe_unit(e5, "use")
	var kb_foe := _probe_unit(e5, "", Vector2i(2, 0), "opponent")
	p5.card.assemble = {"trigger":"use", "effects":[{"type":"knockback","value":2}]}
	e5._assemble_execute(p5, Vector2i(3, 0), "use")
	check(e5.state.unit_at(Vector2i(0, 0)) == kb_foe, "knockback pushed 2")
	# freeze：冰封最近敌人
	var e6 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e6.ai_enabled = false
	var p6 := _probe_unit(e6, "use")
	var fr_foe := _probe_unit(e6, "", Vector2i(2, 0), "opponent")
	p6.card.assemble = {"trigger":"use", "effects":[{"type":"freeze"}]}
	e6._assemble_execute(p6, Vector2i(3, 0), "use")
	check(fr_foe.frozen, "freeze nearest")
	# stun：眩晕最近敌人
	var e7 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e7.ai_enabled = false
	var p7 := _probe_unit(e7, "use")
	var st_foe := _probe_unit(e7, "", Vector2i(2, 0), "opponent")
	p7.card.assemble = {"trigger":"use", "effects":[{"type":"stun"}]}
	e7._assemble_execute(p7, Vector2i(3, 0), "use")
	check(st_foe.stun_left > 0, "stun nearest")

func _test_formal_pool() -> void:
	# 正式池 assemble_pools.json 能被引擎加载，主体卡 8083 端到端走通拼装
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	check(eng.load_assemble_pools("res://assemble_pools.json"), "formal pool loads")
	check(eng.assemble_pools.has("default"), "default pool registered")
	var repo := CardRepo.load_json()
	var base := repo.get_card(8083)
	check(base != null and base.traits.has("拼装") and base.assemble_pool == "default", "formal card 8083")
	if base == null:
		return
	var card := CardData.from_dict(base.to_dict())
	eng.state.hand.append(card)
	eng.state.energy = 10
	check(eng.assemble_begin(0, Vector2i(4, 1)), "formal begin")
	check(eng.assemble_choose(0) and eng.assemble_choose(0), "formal pick upper+lower")
	check(eng.assemble_choices().size() == 2, "formal order previews")
	check(eng.assemble_choose(0), "formal commit")
	var placed: Placement = eng.state.unit_at(Vector2i(4, 1))
	check(placed != null and not placed.card.assemble.is_empty(), "formal placed with assembly")
