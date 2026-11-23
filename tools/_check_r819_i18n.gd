extends SceneTree
## R819 探针：占卜代价结果行在三语下是否真的走模板（而不是回落中文）。

func _initialize() -> void:
	var zh := "（占卜的代价：失去 %d 点最大生命 → %d / %d）" % [5, 55, 55]
	var want := {
		"en": "(Divination cost: -5 Max Health -> 55 / 55)",
		"ja": "（占いの代価：最大HPを5失う → 55 / 55）",
		"es": "(Coste de la adivinación: -5 de Vida máxima -> 55 / 55)",
	}
	var bad := 0
	GameSettings.ensure_loaded()      # 先加载，否则第一次 language() 会把刚设的值覆盖回去
	var old := GameSettings.language
	for lang: String in want.keys():
		GameSettings.language = lang
		GameI18n.reset_cache()
		var got := GameI18n.source(zh)
		var ok: bool = got == str(want[lang])
		print("%s [%s] %s" % ["✓" if ok else "✗", lang, got])
		if not ok:
			print("        期望 %s" % str(want[lang]))
			bad += 1
	# 反查：译文能回中文原文（提及悬浮要用）
	GameSettings.language = "en"
	GameI18n.reset_cache()
	var back := GameI18n.original("(Divination cost: -5 Max Health -> 55 / 55)")
	print("反查(en) -> %s" % back)
	GameSettings.language = old
	GameI18n.reset_cache()
	print("==== %s ====" % ("OK" if bad == 0 else "%d 条不符" % bad))
	quit(0 if bad == 0 else 1)
