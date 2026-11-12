extends SceneTree
## R589 只读探针：打印候选池与八张素材卡的上下半 / 产物文案。
## 用法：Godot --headless --path . --script res://tools/probe_r589_pool.gd

const Rules = preload("res://scripts/assemble_rules.gd")


func _init() -> void:
	var repo := CardRepo.load_json()
	var pool: Array = []
	for c: CardData in repo.all_cards():
		if (c.kind == "盟友" or c.kind == "工事") and c.group == "player" \
				and not c.upper_effect.is_empty() and not c.lower_effect.is_empty():
			pool.append(c.id)
	print("POOL n=", pool.size(), " -> ", pool)
	var probe := CardData.new()
	probe.card_name = "R589 探针"
	probe.kind = "盟友"
	probe.health = 10
	probe.power = 1
	probe.attack_range = 1
	for cid: int in [8004, 9222, 9074, 9052, 9068, 8007, 9046, 9039]:
		var c: CardData = repo.get_card(cid)
		print("--- ", cid, " ", c.card_name)
		print("    原文 = ", c.effect_text)
		print("    上半 = ", JSON.stringify(c.upper_effect))
		print("    下半 = ", JSON.stringify(c.lower_effect))
		print("    半框 = ", Rules.fragment_text(c.upper_effect), " || ", Rules.body_text(c.lower_effect))
		var built: CardData = Rules.build(probe, c.upper_effect, c.lower_effect)
		print("    产物 = ", built.effect_text if built != null else "BUILD FAIL")
	quit()
