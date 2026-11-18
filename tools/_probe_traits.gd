extends SceneTree
## 卡库特性三语检查。日文直接构建 ja-only 映射，再与运行时结果逐项比对：
## 既不接受英文回落，也不把合法的中日同形词误判成中文残留。
## 只读：不改玩家设置文件、不写存档。

func _direct_domain(domain: String, canonical_path: String, out: Dictionary) -> void:
	var zh: Variant = GameI18n._json(canonical_path)
	var tr := GameI18n._domain(domain, "ja")
	if zh != null and not tr.is_empty():
		GameI18n._collect_pairs(zh, tr, out, true)


func _direct_interface(out: Dictionary) -> void:
	var zh: Variant = GameI18n._json("res://i18n/interface_zh_canonical.json")
	if not (zh is Dictionary):
		return
	var data := GameI18n._domain("interface", "ja")
	var scopes: Dictionary = (zh as Dictionary).get("scopes", {})
	var target_scopes: Dictionary = data.get("scopes", {})
	for scope in scopes:
		var source_rows: Dictionary = scopes[scope]
		var target_rows: Dictionary = target_scopes.get(scope, {})
		for key in source_rows:
			if not target_rows.has(key):
				continue
			var source_text := str(source_rows[key].get("zh", ""))
			var target_text := str(target_rows[key])
			if source_text != "" and target_text != "" and not out.has(source_text):
				out[source_text] = target_text


func _direct_raw(domain: String, raw_path: String, section: String,
		fields: Array, out: Dictionary) -> void:
	var raw: Variant = GameI18n._json(raw_path)
	if raw == null:
		return
	var rows: Array = raw if raw is Array else (raw as Dictionary).get(section, [])
	var target: Dictionary = GameI18n._domain(domain, "ja").get(section, {})
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var tr: Dictionary = target.get(str(int(row.get("id", 0))), {})
		for field in fields:
			var source_text := str(row.get(field, ""))
			var target_text := str(tr.get(field, ""))
			if source_text != "" and target_text != "" and not out.has(source_text):
				out[source_text] = target_text


func _build_direct_ja() -> Dictionary:
	# 与 GameI18n._build_source_map 同序，但只读 ja，绝不混入 en。
	var out := {}
	_direct_domain("cards", "res://i18n/zh_canonical.json", out)
	_direct_domain("noncard", "res://i18n/noncard_zh_canonical.json", out)
	_direct_domain("narrative", "res://i18n/narrative_zh_canonical.json", out)
	_direct_domain("event_ui", "res://i18n/event_ui_zh_canonical.json", out)
	_direct_interface(out)
	_direct_raw("cards", "res://cards.json", "cards", ["name", "effect_text"], out)
	_direct_raw("noncard", "res://relics.json", "relics", ["name", "desc"], out)
	_direct_raw("traps", "res://traps.json", "traps", ["name", "desc"], out)
	var glossary: Variant = GameI18n._json("res://i18n/glossary.json")
	if glossary is Dictionary:
		for section in (glossary as Dictionary).values():
			if not (section is Dictionary):
				continue
			for source_text in (section as Dictionary):
				var row: Variant = (section as Dictionary)[source_text]
				if row is Dictionary and (row as Dictionary).has("ja"):
					var target := str((row as Dictionary)["ja"])
					if target != "" and not out.has(source_text):
						out[str(source_text)] = target
	return out


func _initialize() -> void:
	GameSettings.ensure_loaded()
	var uniq := {}
	for c in CardRepo.load_json().all_cards():
		for t in c.traits:
			uniq[str(t)] = true
	var direct_ja := _build_direct_ja()
	var failed := false
	print("特性总数=", uniq.size(), " ja 直接映射=", direct_ja.size())
	for lang in ["en", "ja", "es"]:
		GameSettings.language = lang
		GameI18n.reset_cache()
		var missing: Array = []
		var mismatch: Array = []
		var same_form := 0
		for t in uniq:
			var loc := GameI18n.source(str(t))
			if lang == "ja":
				var expected := str(direct_ja.get(str(t), ""))
				if expected == "":
					missing.append(str(t))
				elif loc != expected:
					mismatch.append("%s：ja=%s / runtime=%s" % [str(t), expected, loc])
				elif loc == str(t):
					same_form += 1
			elif loc == str(t) or GameI18n._has_cjk(loc):
				missing.append(str(t))
		missing.sort()
		mismatch.sort()
		if lang == "ja":
			print("LANG=ja 直接译文缺失=", missing.size(), " 运行时偏离=", mismatch.size(),
					" 中日同形=", same_form)
		else:
			print("LANG=", lang, " 未译特性=", missing.size())
		for m in missing:
			print("  缺 ", m)
		for m in mismatch:
			print("  偏 ", m)
		if not missing.is_empty() or not mismatch.is_empty():
			failed = true
	GameSettings.language = "zh"
	quit(1 if failed else 0)
