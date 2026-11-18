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
		for t in uniq:
			var loc := GameI18n.source(str(t))
			if loc == str(t) or GameI18n._has_cjk(loc):
				missing.append(str(t))
		missing.sort()
		print("LANG=", lang, " 未译特性=", missing.size())
		for m in missing:
			print("  ", m)
	GameSettings.language = "zh"
	quit()
