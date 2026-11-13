class_name GameI18n
extends RefCounted
## 运行时 JSON 翻译桥（R668）。
##
## 权威中文与战斗逻辑保持原样；本模块只在显示层按稳定 ID / scope.key 取译文。
## 支持 zh / en / ja / es，目标语言缺条目时回退 en，再回退调用方给的中文。
## `source()` 另供旧场景做原文查找与已格式化模板匹配，不把 %d 已代入的提示漏回中文。

const LANGS := ["zh", "en", "ja", "es"]
static var _domains := {}
static var _source_maps := {}
static var _source_templates := {}
static var _reverse_maps := {}
static var _aliases := {}


static func language() -> String:
	GameSettings.ensure_loaded()
	var code := GameSettings.language.strip_edges().to_lower()
	return code if LANGS.has(code) else "zh"


static func reset_cache() -> void:
	_domains.clear()
	_source_maps.clear()
	_source_templates.clear()
	_reverse_maps.clear()
	_aliases.clear()


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data


static func _domain(domain: String, lang: String) -> Dictionary:
	var ck := domain + "|" + lang
	if _domains.has(ck):
		return _domains[ck]
	var out := {}
	if lang != "zh":
		var data: Variant = _json("res://i18n/%s_%s.json" % [domain, lang])
		if data is Dictionary:
			out = data
	_domains[ck] = out
	return out


static func _lang_chain(lang: String) -> Array[String]:
	var out: Array[String] = []
	if lang == "zh":
		return out
	out.append(lang)
	if lang != "en":
		out.append("en")
	return out


static func ui(scope: String, key: String, fallback: String) -> String:
	for code in _lang_chain(language()):
		var data := _domain("interface", code)
		var scopes: Dictionary = data.get("scopes", {})
		var rows: Dictionary = scopes.get(scope, {})
		if rows.has(key):
			return str(rows[key])
	return fallback


static func skeleton(key: String, fallback := "", requested_lang := "") -> String:
	var lang := language() if requested_lang == "" else requested_lang.strip_edges().to_lower()
	if not LANGS.has(lang):
		lang = "en"
	for code in _lang_chain(lang):
		var data := _domain("l10n", code)
		if data.has(key):
			return str(data[key])
	return fallback


static func _field(domain: String, section: String, id: Variant, field: String,
		fallback: String) -> String:
	for code in _lang_chain(language()):
		var data := _domain(domain, code)
		var rows: Dictionary = data.get(section, {})
		var row: Dictionary = rows.get(str(id), {})
		if row.has(field):
			return str(row[field])
	return fallback


static func card_name(id: int, fallback: String) -> String:
	return _field("cards", "cards", id, "name", fallback)


static func card_effect(id: int, fallback: String) -> String:
	return _field("cards", "cards", id, "effect_text", fallback)


static func relic_name(id: int, fallback: String) -> String:
	return _field("noncard", "relics", id, "name", fallback)


static func relic_desc(id: int, fallback: String) -> String:
	return _field("noncard", "relics", id, "desc", fallback)


static func trap_name(id: int, fallback: String) -> String:
	return _field("traps", "traps", id, "name", fallback)


static func trap_desc(id: int, fallback: String) -> String:
	return _field("traps", "traps", id, "desc", fallback)


static func class_name_of(cid: String) -> String:
	return class_field(cid, "name", cid)


static func class_field(cid: String, field: String, fallback: String) -> String:
	return _field("noncard", "classes", cid, field, fallback)


static func story_value(id: String, field: String, index: int, fallback: String) -> String:
	for code in _lang_chain(language()):
		var data := _domain("narrative", code)
		var rows: Dictionary = data.get("stories", {})
		var row: Dictionary = rows.get(id, {})
		if field == "text":
			var lines: Array = row.get("text", [])
			if index >= 0 and index < lines.size():
				return str(lines[index])
		elif row.has(field):
			return str(row[field])
	return fallback


static func achievement_value(id: String, field: String, fallback: String) -> String:
	for code in _lang_chain(language()):
		var data := _domain("narrative", code)
		var rows: Dictionary = data.get("achievements", {})
		var row: Dictionary = rows.get(id, {})
		if row.has(field):
			return str(row[field])
	return fallback


static func _has_cjk(text: String) -> bool:
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp >= 0x4E00 and cp <= 0x9FFF:
			return true
	return false


static func _collect_pairs(zh: Variant, tr: Variant, out: Dictionary) -> void:
	if zh is Dictionary and tr is Dictionary:
		for key in (zh as Dictionary).keys():
			if (tr as Dictionary).has(key):
				_collect_pairs((zh as Dictionary)[key], (tr as Dictionary)[key], out)
	elif zh is Array and tr is Array:
		var za := zh as Array
		var ta := tr as Array
		for i in mini(za.size(), ta.size()):
			_collect_pairs(za[i], ta[i], out)
	elif zh is String and tr is String:
		var source_text := zh as String
		var target_text := tr as String
		if (source_text != "" and target_text != "" and source_text != target_text
				and _has_cjk(source_text) and not out.has(source_text)):
			out[source_text] = target_text


static func _collect_domain(domain: String, canonical_path: String, lang: String,
		out: Dictionary) -> void:
	var zh: Variant = _json(canonical_path)
	if zh == null:
		return
	for code in _lang_chain(lang):
		var tr := _domain(domain, code)
		if not tr.is_empty():
			_collect_pairs(zh, tr, out)


static func _collect_interface(lang: String, out: Dictionary) -> void:
	var zh: Variant = _json("res://i18n/interface_zh_canonical.json")
	if not (zh is Dictionary):
		return
	var scopes: Dictionary = (zh as Dictionary).get("scopes", {})
	for code in _lang_chain(lang):
		var data := _domain("interface", code)
		var target_scopes: Dictionary = data.get("scopes", {})
		for scope in scopes.keys():
			var source_rows: Dictionary = scopes[scope]
			var target_rows: Dictionary = target_scopes.get(scope, {})
			for key in source_rows.keys():
				if not target_rows.has(key):
					continue
				var source_row: Dictionary = source_rows[key]
				var source_text := str(source_row.get("zh", ""))
				if source_text != "" and not out.has(source_text):
					out[source_text] = str(target_rows[key])


static func _collect_raw_cards(lang: String, out: Dictionary) -> void:
	var raw: Variant = _json("res://cards.json")
	if raw == null:
		return
	var rows: Array = raw if raw is Array else (raw as Dictionary).get("cards", [])
	for code in _lang_chain(lang):
		var data := _domain("cards", code)
		var target: Dictionary = data.get("cards", {})
		for item in rows:
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			var tr: Dictionary = target.get(str(int(row.get("id", 0))), {})
			for pair in [["name", "name"], ["effect_text", "effect_text"]]:
				var source_text := str(row.get(pair[0], ""))
				var target_text := str(tr.get(pair[1], ""))
				if source_text != "" and target_text != "" and not out.has(source_text):
					out[source_text] = target_text


static func _collect_raw_relics(lang: String, out: Dictionary) -> void:
	var raw: Variant = _json("res://relics.json")
	if raw == null:
		return
	var rows: Array = raw if raw is Array else (raw as Dictionary).get("relics", [])
	for code in _lang_chain(lang):
		var data := _domain("noncard", code)
		var target: Dictionary = data.get("relics", {})
		for item in rows:
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			var tr: Dictionary = target.get(str(int(row.get("id", 0))), {})
			for pair in [["name", "name"], ["desc", "desc"]]:
				var source_text := str(row.get(pair[0], ""))
				var target_text := str(tr.get(pair[1], ""))
				if source_text != "" and target_text != "" and not out.has(source_text):
					out[source_text] = target_text


static func _collect_raw_stories(lang: String, out: Dictionary) -> void:
	var raw: Variant = _json("res://stories.json")
	if not (raw is Dictionary):
		return
	for code in _lang_chain(lang):
		var data := _domain("narrative", code)
		var target: Dictionary = data.get("stories", {})
		for section in ["episodes", "profiles"]:
			for item in (raw as Dictionary).get(section, []):
				if not (item is Dictionary):
					continue
				var row: Dictionary = item
				var tr: Dictionary = target.get(str(row.get("id", "")), {})
				for field in ["chapter", "title"]:
					var source_text := str(row.get(field, ""))
					if source_text != "" and tr.has(field) and not out.has(source_text):
						out[source_text] = str(tr[field])
				var source_lines: Array = row.get("text", [])
				var target_lines: Array = tr.get("text", [])
				for i in mini(source_lines.size(), target_lines.size()):
					var source_text := str(source_lines[i])
					if source_text != "" and not out.has(source_text):
						out[source_text] = str(target_lines[i])


static func _collect_raw_traps(lang: String, out: Dictionary) -> void:
	var raw: Variant = _json("res://traps.json")
	if not (raw is Dictionary):
		return
	for code in _lang_chain(lang):
		var data := _domain("traps", code)
		var target: Dictionary = data.get("traps", {})
		for item in (raw as Dictionary).get("traps", []):
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			var tr: Dictionary = target.get(str(int(row.get("id", 0))), {})
			for pair in [["name", "name"], ["desc", "desc"]]:
				var source_text := str(row.get(pair[0], ""))
				var target_text := str(tr.get(pair[1], ""))
				if source_text != "" and target_text != "" and not out.has(source_text):
					out[source_text] = target_text


static func _collect_glossary(lang: String, out: Dictionary) -> void:
	## 特性 / 机制短词不一定是卡名或完整界面句，最后由术语表补齐；
	## 已按稳定 ID / scope.key 翻译的条目优先，不被这里的通用词覆盖。
	var glossary: Variant = _json("res://i18n/glossary.json")
	for code in _lang_chain(lang):
		if code == "es":
			var spanish: Variant = _json("res://i18n/glossary_es.json")
			if spanish is Dictionary:
				for source_text in (spanish as Dictionary).get("terms", {}):
					var target := str((spanish as Dictionary)["terms"][source_text])
					if target != "" and not out.has(source_text):
						out[str(source_text)] = target
		elif glossary is Dictionary:
			for section in (glossary as Dictionary).values():
				if not (section is Dictionary):
					continue
				for source_text in (section as Dictionary).keys():
					var row: Variant = (section as Dictionary)[source_text]
					if row is Dictionary and (row as Dictionary).has(code):
						var target := str((row as Dictionary)[code])
						if target != "" and not out.has(source_text):
							out[str(source_text)] = target


static func _build_source_map(lang: String) -> Dictionary:
	var out := {}
	_collect_domain("cards", "res://i18n/zh_canonical.json", lang, out)
	_collect_domain("noncard", "res://i18n/noncard_zh_canonical.json", lang, out)
	_collect_domain("narrative", "res://i18n/narrative_zh_canonical.json", lang, out)
	_collect_domain("event_ui", "res://i18n/event_ui_zh_canonical.json", lang, out)
	_collect_interface(lang, out)
	_collect_raw_cards(lang, out)
	_collect_raw_relics(lang, out)
	_collect_raw_stories(lang, out)
	_collect_raw_traps(lang, out)
	_collect_glossary(lang, out)
	var aliases: Variant = _json("res://i18n/source_aliases.json")
	if aliases is Dictionary:
		for raw_text in (aliases as Dictionary).keys():
			var canonical := str((aliases as Dictionary)[raw_text])
			if out.has(canonical):
				out[str(raw_text)] = str(out[canonical])
	_source_maps[lang] = out
	return out


static func _map_for(lang: String) -> Dictionary:
	if not _source_maps.has(lang):
		return _build_source_map(lang)
	return _source_maps[lang]


static func _exact(text: String, lang: String) -> String:
	return str(_map_for(lang).get(text, ""))


static func original(text: String) -> String:
	## 提及悬浮等交互可拿译文反查权威中文，再按原 ID 解析。
	var lang := language()
	if lang == "zh" or text == "":
		return text
	if not _reverse_maps.has(lang):
		var reverse := {}
		for source_text in _map_for(lang):
			var target := str(_map_for(lang)[source_text])
			if target != "" and not reverse.has(target):
				reverse[target] = str(source_text)
		_reverse_maps[lang] = reverse
	return str((_reverse_maps[lang] as Dictionary).get(text, text))


static func _template_parts(template: String) -> Array:
	var parts: Array = []
	var buf := ""
	var i := 0
	while i < template.length():
		if template[i] == "%" and i + 1 < template.length():
			var marker := template.substr(i, 2)
			if marker == "%%":
				buf += "%"
				i += 2
				continue
			if marker == "%s" or marker == "%d":
				parts.append({"kind": "literal", "text": buf})
				parts.append({"kind": marker})
				buf = ""
				i += 2
				continue
		buf += template[i]
		i += 1
	parts.append({"kind": "literal", "text": buf})
	return parts


static func _match_template(value: String, template: String) -> Array:
	var parts := _template_parts(template)
	var captures: Array = []
	var pos := 0
	var pending := -1
	for i in parts.size():
		var part: Variant = parts[i]
		if part is Dictionary and str(part.get("kind", "")) != "literal":
			pending = i
			continue
		var literal := str(part.get("text", "")) if part is Dictionary else ""
		var found := value.find(literal, pos)
		if found < 0:
			return []
		if i == 0 and found != 0:
			return []
		if pending >= 0:
			var capture := value.substr(pos, found - pos)
			var kind := str(parts[pending].get("kind", ""))
			if kind == "%d" and not capture.is_valid_int():
				return []
			captures.append(capture)
			pending = -1
		pos = found + literal.length()
	if pending >= 0:
		var capture := value.substr(pos)
		var kind := str(parts[pending].get("kind", ""))
		if kind == "%d" and not capture.is_valid_int():
			return []
		captures.append(capture)
	elif pos != value.length():
		return []
	return captures


static func _format_template(template: String, captures: Array, lang: String) -> String:
	var out := ""
	var index := 0
	var i := 0
	while i < template.length():
		if template[i] == "%" and i + 1 < template.length():
			var marker := template.substr(i, 2)
			if marker == "%%":
				out += "%"
				i += 2
				continue
			if (marker == "%s" or marker == "%d") and index < captures.size():
				var value := str(captures[index])
				if marker == "%s":
					var translated := _exact(value, lang)
					if translated != "":
						value = translated
				out += value
				index += 1
				i += 2
				continue
		out += template[i]
		i += 1
	return out


static func _build_templates(lang: String) -> Array:
	var rows: Array = []
	for source_text in _map_for(lang).keys():
		var template := str(source_text)
		if template.contains("%s") or template.contains("%d"):
			rows.append({"source": template, "target": str(_map_for(lang)[source_text])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["source"]).length() > str(b["source"]).length())
	_source_templates[lang] = rows
	return rows


static func _from_template(text: String, lang: String) -> String:
	if not _source_templates.has(lang):
		_build_templates(lang)
	for row in (_source_templates[lang] as Array):
		var captures := _match_template(text, str(row["source"]))
		if not captures.is_empty():
			return _format_template(str(row["target"]), captures, lang)
	return ""


static func source(text: String) -> String:
	## 旧 Label / 自绘文本的兜底桥：先全串，再逐行，最后匹配已格式化模板。
	var lang := language()
	if lang == "zh" or text == "":
		return text
	var hit := _exact(text, lang)
	if hit != "":
		return hit
	if text.contains("\n"):
		var lines := text.split("\n")
		var changed := false
		for i in lines.size():
			var line := str(lines[i])
			var translated := _exact(line, lang)
			if translated == "":
				translated = _from_template(line, lang)
			if translated != "":
				lines[i] = translated
				changed = true
		if changed:
			return "\n".join(lines)
	var templated := _from_template(text, lang)
	return templated if templated != "" else text
