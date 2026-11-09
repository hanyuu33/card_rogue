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
	check(not eng.register_assemble_pool("bad", [{"trigger":"attack"}], lower), "unsupported trigger")
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
	print("Assembly tests failures: ", failures)
	quit(failures)
