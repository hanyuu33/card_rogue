extends SceneTree
## 探针：把 40 关战斗的完整编成导出成 JSON（供 HTML 报告生成用）。
## 口径：
##   * 关卡字段原样取自 `GameLevels.builtin_levels()`；事件专属关（洞穴）另放 `extra_levels`；
##   * 敌方总血条走 `GameLevels.enemy_hp_of()`（已含精英 +10 / Boss +20 与 ×2）；
##   * 单位 / 效果 / 奖励卡的卡面数据一律取自卡库（`CardRepo.get_card()`），
##     编成元组前六项只作缺卡兜底。

func _card_info(repo: CardRepo, id: int) -> Dictionary:
	var c := repo.get_card(id)
	if c == null:
		return {"id": id, "missing": true}
	var d: Dictionary = c.to_dict()
	d["id"] = id
	d["missing"] = false
	d["rarity_name"] = CardData.RARITY_NAMES[clampi(int(c.rarity), 0, CardData.RARITY_NAMES.size() - 1)]
	return d


func _level_row(lvl: Dictionary, repo: CardRepo) -> Dictionary:
	var units: Array = []
	for e in lvl.get("enemy_units", []):
		if not (e is Array) or (e as Array).size() < 7:
			continue
		var pos: Vector2i = e[6]
		units.append({
			"id": int(e[0]),
			"name": str(e[1]),
			"atk": int(e[2]),
			"hp": int(e[3]),
			"range": int(e[4]),
			"speed": int(e[5]),
			"pos": [pos.x, pos.y],
			"card": _card_info(repo, int(e[0])),
		})
	var fx: Array = []
	for id in lvl.get("enemy_effects", []):
		fx.append(_card_info(repo, int(id)))
	var rew: Array = []
	for id in lvl.get("reward_cards", []):
		rew.append(_card_info(repo, int(id)))
	return {
		"name": str(lvl.get("name", "")),
		"key": str(lvl.get("key", "")),
		"tier": int(lvl.get("tier", -1)),
		"tier_name": GameLevels.tier_name(int(lvl.get("tier", -1))),
		"layer": GameLevels.layer_of(lvl),
		"enemy_hp": GameLevels.enemy_hp_of(lvl),
		"enemy_hp_base": int(lvl.get("enemy_hp", 30)),
		"player_hp": int(lvl.get("player_hp", 20)),
		"turn_limit": int(lvl.get("turn_limit", -1)),
		"shuffle": bool(lvl.get("shuffle", false)),
		"enemy_ai": bool(lvl.get("enemy_ai", false)),
		"starting_hand": int(lvl.get("starting_hand", 0)),
		"event_only": bool(lvl.get("event_only", false)),
		"units": units,
		"effects": fx,
		"rewards": rew,
	}


func _initialize() -> void:
	GameSettings.ensure_loaded()
	var repo := CardRepo.load_json()
	var out: Array = []
	for lvl in GameLevels.builtin_levels():
		out.append(_level_row(lvl, repo))
	var payload := {
		"generated_at": Time.get_datetime_string_from_system(),
		"level_count": out.size(),
		"levels": out,
		"extra_levels": [_level_row(GameLevels.cave_level(), repo)],
	}
	var path := "res://tools/_levels_report.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("wrote %s (%d levels + %d extra)" % [path, out.size(), 1])
	quit(0)
