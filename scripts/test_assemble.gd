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
