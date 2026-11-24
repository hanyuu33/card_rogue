extends SceneTree

## R778：导出所有关卡里的怪物配置（一次性 dump 工具，不进包）。

func _init() -> void:
	var all: Array = GameLevels.builtin_levels()
	all.append(GameLevels.cave_level())
	print("LEVEL_COUNT=", all.size())
	print("### PER_LEVEL")
	for lvl in all:
		var units: Array = lvl.get("enemy_units", [])
		var parts: Array[String] = []
		for u in units:
			if not (u is Array) or (u as Array).size() < 7:
				continue
			var cell: Vector2i = u[6]
			parts.append("%d:%s@%d,%d" % [int(u[0]), str(u[1]), cell.x, cell.y])
		print("LVL\t%s\t%s\t%s\tL%d\t%s" % [
			str(lvl.get("key", "")), str(lvl.get("name", "")),
			GameLevels.tier_name(int(lvl.get("tier", -1))),
			GameLevels.layer_of(lvl), " | ".join(parts)])
	print("### PER_UNIT")
	var order: Array = []
	var seen := {}
	for lvl in all:
		for u in lvl.get("enemy_units", []):
			if not (u is Array) or (u as Array).size() < 7:
				continue
			var id := int(u[0])
			var sig := "%s|%d|%d|%d|%d" % [str(u[1]), int(u[2]), int(u[3]), int(u[4]), int(u[5])]
			if not seen.has(id):
				seen[id] = {"sig": sig, "lvls": [], "sigs": {}}
				order.append(id)
			var rec: Dictionary = seen[id]
			rec["sigs"][sig] = int(rec["sigs"].get(sig, 0)) + 1
			var lk := "%s(%s)" % [str(lvl.get("key", "")), GameLevels.tier_name(int(lvl.get("tier", -1)))]
			if not rec["lvls"].has(lk):
				rec["lvls"].append(lk)
	for id in order:
		var rec: Dictionary = seen[id]
		print("UNIT\t%d\t%s\t%s" % [int(id), str(rec["sig"]), ", ".join(rec["lvls"])])
	print("### SIG_VARIANTS")
	for id in order:
		var rec: Dictionary = seen[id]
		if (rec["sigs"] as Dictionary).size() > 1:
			print("VAR\t%d\t%s" % [int(id), str(rec["sigs"])])
	print("UNIT_TOTAL=", order.size())
	quit()
