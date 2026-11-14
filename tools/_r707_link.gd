extends SceneTree
## R707 校验：「接通」是否真的接上了关键词说明（奖励页 / 商店 / 左栏共用同一条链）。
##
## 用法（headless）：
##   Godot_v4.3-stable_win64_x.exe --headless --path . --script res://tools/_r707_link.gd
##
## 链路：卡面 traits 里写「接通」→ CardData.word_def() 有定义 →
##   CardFace.affix_index_items() 才会把它放进浮窗（无定义 = 弹不出解释）。
## 同时把「关键字行会列出、但查不到说明」的差异打出来，方便下轮继续补。

var _fails := 0


func _initialize() -> void:
	ProfileData.set_test_mode()
	RunState.end_run()
	_run()
	print("== R707 结果：%s ==" % ("全部通过" if _fails == 0 else "%d 项失败" % _fails))
	quit(1 if _fails > 0 else 0)


func _ck(ok: bool, msg: String) -> void:
	if ok:
		print("  ✓ ", msg)
	else:
		_fails += 1
		print("  ✗ ", msg)


func _run() -> void:
	var repo := CardRepo.load_json()
	var font := ThemeDB.fallback_font

	print("[1] 词条定义")
	var d := CardData.word_def("接通")
	_ck(not d.is_empty(), "word_def(\"接通\") 非空")
	_ck(str(d.get("label", "")) == "接通", "label = 接通（实际「%s」）" % str(d.get("label", "")))
	_ck(str(d.get("desc", "")).length() > 10, "desc 有内容（%d 字）" % str(d.get("desc", "")).length())
	_ck(str(d.get("glyph", "")) == "link", "glyph = link（实际「%s」）" % str(d.get("glyph", "")))
	var cols := CardData.affix_colors("接通")
	_ck(cols.size() == 2, "affix_colors 返回两组色")

	print("[2] 奖励页关键字行 + 浮窗（四张带「接通」trait 的卡）")
	for id in [8041, 8042, 8043, 9070]:
		var card: CardData = repo.get_card(id)
		_ck(card != null, "卡 %d 取到" % id)
		if card == null:
			continue
		var names := CardFace.keyword_names(card)
		_ck(names.has("接通"), "%s（%d）关键字行含「接通」" % [card.card_name, id])
		var items := CardFace.affix_index_items(card, font)
		var hit := false
		for it: Dictionary in items:
			if str(it.get("affix", "")) == "接通":
				hit = true
				_ck(int(it.get("h", 0)) > 30, "  浮窗条目高度 = %d（> 30 才容得下标题+正文）"
						% int(it.get("h", 0)))
				_ck((it.get("lines", []) as Array).size() >= 1,
						"  正文折出 %d 行" % (it.get("lines", []) as Array).size())
		_ck(hit, "%s 的浮窗里有「接通」条目" % card.card_name)

	print("[3] 反向：没有「接通」的卡不该凭空多一条")
	var plain: CardData = repo.get_card(8002)   # 攻击
	var plain_items := CardFace.affix_index_items(plain, font)
	var leak := false
	for it: Dictionary in plain_items:
		if str(it.get("affix", "")) == "接通":
			leak = true
	_ck(not leak, "攻击 8002 的浮窗没有「接通」")

	print("[4] 全部机制词条自检（label / desc / glyph 齐全，且 glyph 有绘制分支）")
	var boxes_src := FileAccess.get_file_as_string("res://scripts/card_info_boxes.gd")
	for w: String in CardData.MECH_KEYWORDS.keys():
		var wd: Dictionary = CardData.word_def(w)
		_ck(not wd.is_empty() and str(wd.get("label", "")) != "",
				"「%s」有 label" % w)
		_ck(str(wd.get("desc", "")).length() >= 8, "「%s」desc %d 字"
				% [w, str(wd.get("desc", "")).length()])
		var g := str(wd.get("glyph", ""))
		if g != "":
			_ck(boxes_src.find('"%s"' % g) >= 0, "「%s」glyph「%s」有绘制分支" % [w, g])
	print("[5] 探照灯：关键字行列出、但 word_def 查不到的词（信息用，不计失败）")
	var seen := {}
	for row in _all_cards(repo):
		for w: String in CardFace.keyword_names(row):
			if CardData.word_def(w).is_empty():
				seen[w] = int(seen.get(w, 0)) + 1
	print("      共 %d 种没有说明的关键字；出现 ≥2 张的：" % seen.size())
	var multi: Array = []
	for w: String in seen:
		if int(seen[w]) >= 2:
			multi.append("%s(%d)" % [w, int(seen[w])])
	multi.sort()
	print("      " + " · ".join(multi))


func _all_cards(repo: CardRepo) -> Array[CardData]:
	var out: Array[CardData] = []
	var data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://cards.json"))
	if not (data is Dictionary):
		return out
	_collect(data as Dictionary, repo, out)
	return out


func _collect(o: Variant, repo: CardRepo, out: Array[CardData]) -> void:
	if o is Dictionary:
		var dic := o as Dictionary
		if dic.has("effect_text") and dic.has("id"):
			var c: CardData = CardData.from_dict(dic)
			if c != null:
				out.append(c)
		for v: Variant in dic.values():
			_collect(v, repo, out)
	elif o is Array:
		for v: Variant in (o as Array):
			_collect(v, repo, out)
