extends SceneTree
## 只读行为探针：组合产物上场后，属性槽那张卡的「效果」到底会不会真的执行。
##
## 用法：
##   godot --headless --path . --script res://tools/probe_combo_behavior.gd
##
## 不读写存档、不建场景：直接 new 一个 FieldState + GameEngine，把产物放进 board，
## 调引擎的受击 / 回血唯一口，看数值有没有被「属性槽卡的自带效果」改掉。

const GE = preload("res://scripts/game_engine.gd")
const FS = preload("res://scripts/field_state.gd")
const PL = preload("res://scripts/placement.gd")
const Rules = preload("res://scripts/assemble_rules.gd")
const CardRepo = preload("res://scripts/card_repo.gd")

func _initialize() -> void:
	_run.call_deferred()

func _mk(engine, card, cell: Vector2i, hp: int):
	var p = PL.new()
	p.card = card
	p.owner = "self"
	p.health = hp
	engine.state.board[cell] = p
	return p

func _case(base_id: int, upper_part: Dictionary, lower_part: Dictionary) -> Dictionary:
	var repo := CardRepo.load_json()
	var base = repo.get_card(base_id)
	var prod = Rules.build(base, upper_part, lower_part, false)
	if prod == null:
		return {"id": base_id, "error": "build null"}
	var st = FS.new([], 20, 20, -1, "", false)
	var eng = GE.new(st)
	var cell := Vector2i(4, 1)
	var p = _mk(eng, prod, cell, prod.health)
	var taken: int = eng._unit_damage_taken(p, 5)
	# 回血：先压到半血，再走引擎的回合收尾
	p.health = maxi(1, int(prod.health) / 2)
	var before: int = p.health
	eng._regen_tick("self")
	var healed: int = p.health - before
	return {
		"id": base_id, "name": prod.card_name,
		"prod_traits": prod.traits.duplicate(),
		"prod_id": prod.id, "prod_hp": prod.health,
		"damage_5_in": 5, "damage_taken": taken,
		"heal_after_tick": healed,
		"prod_text": prod.effect_text,
	}

func _run() -> void:
	var repo := CardRepo.load_json()
	var pool: Array = []
	for c: CardData in repo.all_cards():
		if (c.kind == "盟友" or c.kind == "工事") and c.group == "player" \
				and not c.upper_effect.is_empty() and not c.lower_effect.is_empty():
			pool.append(c)
	var up: Dictionary = (pool[1] as CardData).upper_effect
	var lo: Dictionary = (pool[2] as CardData).lower_effect
	var out: Array = []
	# ① 犀牛当属性槽（trait 犀牛 + regen_per_turn=2）
	out.append(_case(9016, up, lo))
	# ② 火元素当属性槽（池内唯一两张「干净」卡之一，对照组）
	out.append(_case(9236, up, lo))
	# ③ 厄运的使者当属性槽（另一张干净卡）
	out.append(_case(9232, up, lo))
	# ④ 野兔当属性槽（自我复制 + 幻影附魔）
	out.append(_case(9032, up, lo))
	print("BEHAVIOR_JSON_BEGIN")
	print(JSON.stringify(out, "  "))
	print("BEHAVIOR_JSON_END")
	quit()
