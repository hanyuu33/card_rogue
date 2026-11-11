extends SceneTree
## 只读探针：验证「组装的属性槽卡（第①张）会不会把自己的效果带进产物」。
##
## 用法：
##   godot --headless --path . --script res://tools/probe_combo_inherit.gd
##
## 不做任何写操作：只读 cards.json、只调 AssembleRules.build()（纯函数），
## 打印一份 JSON 到 stdout 供外部解析。不碰 RunState / 存档 / 场景。

const AssembleRules = preload("res://scripts/assemble_rules.gd")
const CardRepo = preload("res://scripts/card_repo.gd")

# from_dict 会整份复制这些字段；只要非空就等于「产物多带一条效果」。
const FX_FIELDS: Array[String] = [
	"field_heal", "field_poison_dmg", "field_poison_turns", "field_vortex_dmg",
	"regen_per_turn", "first_kill_power", "first_kill_health", "per_kill_damage",
	"battle_end_gold", "growth_power", "growth_health", "growth_damage",
	"lone_dmg_bonus", "lone_str_bonus", "upgrade_atk_bonus", "upgrade_hp_bonus",
	"upgrade_stacks",
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var repo := CardRepo.load_json()
	var pool: Array = []
	for c: CardData in repo.all_cards():
		if (c.kind == "盟友" or c.kind == "工事") and c.group == "player" \
				and not c.upper_effect.is_empty() and not c.lower_effect.is_empty():
			pool.append(c)
	# 取一对固定的合法上下半（挑池内前两张，避免探针自身依赖某张特定卡）
	if pool.size() < 3:
		print("{\"error\":\"pool too small\"}")
		quit()
		return
	var upper_part: Dictionary = (pool[1] as CardData).upper_effect
	var lower_part: Dictionary = (pool[2] as CardData).lower_effect

	var rows: Array = []
	for base: CardData in pool:
		var prod := AssembleRules.build(base, upper_part, lower_part, false)
		if prod == null:
			rows.append({"id": base.id, "name": base.card_name, "error": "build null"})
			continue
		var keep: Dictionary = {}
		for f in FX_FIELDS:
			var v = prod.get(f)
			if v != null and int(v) != 0:
				keep[f] = int(v)
		if not prod.affixes.is_empty():
			keep["affixes"] = prod.affixes.duplicate()
		if prod.traits.size() > 0:
			# traits 只要非空就记下来 —— 是否有引擎实现由外部按名单判
			keep["traits"] = prod.traits.duplicate()
		rows.append({
			"id": base.id,
			"name": base.card_name,
			"class": base.card_class,
			"traits_shared_ref": is_same(prod.traits, base.traits),
			"combo_trigger": str(prod.combo_trigger),
			"trigger": str(prod.trigger),
			"kept": keep,
			"prod_text": prod.effect_text,
		})
	print("PROBE_JSON_BEGIN")
	print(JSON.stringify({"pool": pool.size(), "upper_from": (pool[1] as CardData).id,
			"lower_from": (pool[2] as CardData).id, "rows": rows}, "  "))
	print("PROBE_JSON_END")
	quit()
