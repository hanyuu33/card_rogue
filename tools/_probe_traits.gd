extends SceneTree
## 列出卡库全部特性（traits）在各语言下仍回落中文的项。
## 只读：不改玩家设置文件、不写存档。

func _initialize() -> void:
	GameSettings.ensure_loaded()
	var uniq := {}
	for c in CardRepo.load_json().all_cards():
		for t in c.traits:
			uniq[str(t)] = true
	print("特性总数=", uniq.size())
	for lang in ["en", "ja", "es"]:
		GameSettings.language = lang
		GameI18n.reset_cache()
		var missing: Array = []
		var same_form := 0
		for t in uniq:
			var loc := GameI18n.source(str(t))
			if lang == "ja":
				# 日文汉字不是中文残留；同形词由显式 ja 字段提供，允许保留。
				# 真正要拦的是 ja 取文被后续 en 回落覆盖。
				var en_loc := GameI18n._exact(str(t), "en")
				if loc != str(t) and en_loc != "" and loc == en_loc:
					missing.append(str(t))
				elif loc == str(t):
					same_form += 1
			elif loc == str(t) or GameI18n._has_cjk(loc):
				missing.append(str(t))
		missing.sort()
		if lang == "ja":
			print("LANG=ja 英文回落=", missing.size(), " 中日同形=", same_form)
		else:
			print("LANG=", lang, " 未译特性=", missing.size())
		for m in missing:
			print("  ", m)
	GameSettings.language = "zh"
	quit()
