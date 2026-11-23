extends SceneTree
## R794 出图验收：二层事件「巧克力工厂」四档连点 + 「林中的剑」圣剑改名。
##
## 用法（不能 --headless，需要真实排版与出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r794_factory.gd
##   （英文版加 `-- --lang=en`，走 GameSettings 的官方出图口）
##
## 判据（打印在 stdout，供人眼核对）：
##   * 四档按钮文案逐档变化，且 width <= 面板可用宽（不靠省略号）；
##   * 第 n 次点击后 max_hp 差额 = 累计代价、巧克力数 = n；
##   * 第 4 次点击后拿到卡 9271 并且进入完成态；
##   * 剑事件的按钮与正文写「圣剑」，不再出现「大师之剑」。
## 出图：res://_shots/r794_*.png

const FACTORY_CARD_ID := 9271


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(tag: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r794_%s.png" % tag)
	print("  >> SAVED _shots/r794_%s.png %s" % [tag, str(img.get_size())])


func _setup(kind: String) -> Node:
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	RunState.start_run(RogueMap.generate(rng))
	RunState.pending_event = kind
	RunState.pending_node = {"type": "event", "event_kind": kind}
	var sc: Variant = load("res://scenes/event.tscn").instantiate()
	get_root().add_child(sc)
	return sc


func _dump(sc: Node, tag: String) -> void:
	var n: Label = sc.get_node_or_null("Center/EventName")
	var d: Label = sc.get_node_or_null("Center/Desc")
	print("==== [r794] %s ====" % tag)
	print("  name: %s" % (n.text if n != null else "?"))
	print("  desc: %s" % (d.text if d != null else "?"))
	for path: String in ["Center/RestBtn", "Center/AltBtn", "Center/LeaveBtn"]:
		var b: Button = sc.get_node_or_null(path)
		if b == null:
			print("  btn %-14s (null)" % path)
			continue
		print("  btn %-14s vis=%s dis=%s w=%.0f min=%.0f  text=%s" % [
				path.get_file(), str(b.visible), str(b.disabled), b.size.x,
				b.get_combined_minimum_size().x, b.text])


func _factory_case() -> void:
	var lang: String = GameI18n.language()
	print("---- factory CASE lang=%s ----" % lang)
	var sc: Node = _setup("factory")
	await _wait(30)
	var hp0: int = RunState.max_hp
	var choco0: int = RunState.chocolate
	_dump(sc, "factory/%s 档 0 初始" % lang)
	_snap("factory_%s_0" % lang)

	var rest: Button = sc.get_node_or_null("Center/RestBtn")
	for i: int in 4:
		rest = sc.get_node_or_null("Center/RestBtn")
		if rest == null or rest.disabled or not rest.visible:
			print("  !! 第 %d 档按钮不可点 —— 停在这里" % (i + 1))
			break
		rest.emit_signal("pressed")
		await _wait(8)
		print("  [第 %d 次点击] max_hp %d -> %d（累计 -%d）  巧克力 %d -> %d  卡组 %d 含 9271=%s" % [
				i + 1, hp0, RunState.max_hp, hp0 - RunState.max_hp,
				choco0, RunState.chocolate, RunState.deck_ids.size(),
				str(FACTORY_CARD_ID in RunState.deck_ids)])
		_dump(sc, "factory/%s 档 %d 之后" % [lang, i + 1])
		if i == 2:
			_snap("factory_%s_3" % lang)   # 点完 3 次 → 按钮已换成第 4 档
	_snap("factory_%s_done" % lang)

	var res: Label = sc.get_node_or_null("Center/ResultLabel")
	print("  >> 结局 result: %s" % (res.text if res != null else "?"))
	print("  >> 总计 max_hp %d->%d  巧克力 +%d  拿到 9271=%s" % [
			hp0, RunState.max_hp, RunState.chocolate - choco0,
			str(FACTORY_CARD_ID in RunState.deck_ids)])
	sc.queue_free()
	await _wait(3)


func _sword_case() -> void:
	print("---- sword CASE lang=%s ----" % GameI18n.language())
	var sc: Node = _setup("sword")
	await _wait(30)
	_dump(sc, "sword/%s" % GameI18n.language())
	var bad := 0
	var texts: Array[String] = []
	var n: Label = sc.get_node_or_null("Center/EventName")
	var d: Label = sc.get_node_or_null("Center/Desc")
	var r: Button = sc.get_node_or_null("Center/RestBtn")
	if n != null:
		texts.append(n.text)
	if d != null:
		texts.append(d.text)
	if r != null:
		texts.append(r.text)
	for t: String in texts:
		if t.contains("大师之剑") or t.contains("Master Sword"):
			bad += 1
	print("  >> 残留旧名 %d 处（应为 0）" % bad)
	_snap("sword_%s" % GameI18n.language())
	sc.queue_free()
	await _wait(3)


func _apply_lang_arg() -> void:
	## 出图口的 `--lang=` 在 `GameSettings.ensure_loaded()` 里解析，但那一支写在校验
	## 「配置文件是否存在」**之后** —— 全新 APPDATA（无 game.cfg）会提前 return 而跳过覆盖。
	## 所以截图脚本自己再解析一次，直接改静态字段（不写盘）。
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			var code: String = a.substr("--lang=".length()).strip_edges().to_lower()
			GameSettings.ensure_loaded()
			GameSettings.language = code
			TranslationServer.set_locale("zh_CN" if code == "zh" else code)
			print("[r794] forced lang=%s -> i18n=%s" % [code, GameI18n.language()])


func _m() -> void:
	_apply_lang_arg()
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	await _factory_case()
	await _sword_case()
	print("[r794] DONE")
	quit()
