extends SceneTree

## R778：导出「关卡 → 怪物配置」全量明细（一次性 dump 工具，不进包）。

func _init() -> void:
	var all: Array = GameLevels.builtin_levels()
	all.append(GameLevels.cave_level())
	print("LEVEL_COUNT=", all.size())
	print("### PER_LEVEL")
	for lvl in all:
		var parts: Array[String] = []
		for u in lvl.get("enemy_units", []):
			if not (u is Array) or (u as Array).size() < 7:
				continue
			var cell: Vector2i = u[6]
			parts.append("%d\t%s\t%d\t%d\t%d\t%d\t%d,%d" % [
				int(u[0]), str(u[1]), int(u[2]), int(u[3]), int(u[4]), int(u[5]),
				cell.x, cell.y])
		print("LVL\t%s\t%s\t%s\tL%d\tpp=%d\tehp=%d(base %d)\tturn=%d\tshuffle=%s\tai=%s\thand=%d\teffects=%s\treward=%s" % [
			str(lvl.get("key", "")), str(lvl.get("name", "")),
			GameLevels.tier_name(int(lvl.get("tier", -1))),
			GameLevels.layer_of(lvl),
			int(lvl.get("player_hp", 20)), GameLevels.enemy_hp_of(lvl),
			int(lvl.get("enemy_hp", 30)),
			int(lvl.get("turn_limit", -1)),
			str(lvl.get("shuffle", true)), str(lvl.get("enemy_ai", false)),
			int(lvl.get("starting_hand", 0)),
			str(lvl.get("enemy_effects", [])), str(lvl.get("reward_cards", []))])
		for p in parts:
			print("  UNIT\t%s" % p)
	print("### PER_UNIT")
	var order: Array = []
	var seen := {}
	for lvl in all:
		for u in lvl.get("enemy_units", []):
			if not (u is Array) or (u as Array).size() < 7:
				continue
			var id := int(u[0])
			if not seen.has(id):
				seen[id] = {"name": str(u[1]), "atk": int(u[2]), "hp": int(u[3]),
					"rng": int(u[4]), "mv": int(u[5]), "lvls": []}
				order.append(id)
			var rec: Dictionary = seen[id]
			var lk := "%s" % str(lvl.get("key", ""))
			if not rec["lvls"].has(lk):
				rec["lvls"].append(lk)
	for id in order:
		var r: Dictionary = seen[id]
		print("UNIT\t%d\t%s\t%d\t%d\t%d\t%d\t%s" % [int(id), str(r["name"]),
			int(r["atk"]), int(r["hp"]), int(r["rng"]), int(r["mv"]),
			",".join(r["lvls"])])
	print("UNIT_TOTAL=", order.size())
	quit()
