extends SceneTree
## R633：读玩家真实存档，检查「待领奖励候选 / 商店货架 / 本局禁卡快照」三者是否自洽。
## 只读（不写盘）。用法：godot --headless --path . --script res://tools/probe_r633_save.gd

const CardRepo = preload("res://scripts/card_repo.gd")
const ProfileData = preload("res://scripts/profile_data.gd")


func _init() -> void:
	var repo = CardRepo.load_json()
	ProfileData.ensure_loaded()
	var path := "user://run_save.sav"
	if not FileAccess.file_exists(path):
		print("没有存档")
		quit()
		return
	var root: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if not (root is Dictionary):
		print("存档解析失败")
		quit()
		return
	var d: Dictionary = (root as Dictionary).get("d", {})
	var bans: Array = d.get("run_bans", [])
	print("存档 player_class=%s  run_bans=%s" % [str(d.get("player_class", "")), str(bans)])
	var profile_bans: Array = ProfileData.bans_of(str(d.get("player_class", "")))
	print("当前档案同职业禁用=%s" % str(profile_bans))

	print("=== pending_rewards ===")
	for i: int in (d.get("pending_rewards", []) as Array).size():
		var e: Dictionary = (d.get("pending_rewards", []) as Array)[i]
		var cands: Array = e.get("candidates", [])
		var bad: Array = []
		for cid: Variant in cands:
			if bans.has(int(cid)) or profile_bans.has(int(cid)):
				bad.append(int(cid))
		print("  [%d] kind=%s type=%s picked=%s state=%s candidates=%s%s"
				% [i, str(e.get("kind")), str(e.get("type")), str(e.get("picked")),
				str(e.get("state")), str(cands),
				"   ← 含禁卡 %s" % str(bad) if not bad.is_empty() else ""])

	print("=== shop_states（货架里有没有禁卡） ===")
	for k: Variant in (d.get("shop_states", {}) as Dictionary).keys():
		var st: Variant = (d.get("shop_states", {}) as Dictionary)[k]
		if not (st is Dictionary):
			continue
		var row1: Array = (st as Dictionary).get("row1", [])
		var ids: Array = []
		for e: Variant in row1:
			if e is Dictionary:
				ids.append(int((e as Dictionary).get("id", -1)))
		var bad2: Array = []
		for cid: int in ids:
			if bans.has(cid) or profile_bans.has(cid):
				bad2.append(cid)
		print("  node=%s row1=%s%s" % [str(k), str(ids),
				"   ← 含禁卡 %s" % str(bad2) if not bad2.is_empty() else ""])

	print("=== delayed_cards ===")
	for e2: Variant in d.get("delayed_cards", []):
		if e2 is Dictionary:
			print("  id=%s need=%s" % [str((e2 as Dictionary).get("id")), str((e2 as Dictionary).get("need"))])
	quit()
