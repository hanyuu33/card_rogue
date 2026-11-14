extends SceneTree

const L10n = preload("res://scripts/l10n.gd")
## R668：运行时 JSON 翻译桥回归；只读资源，不写玩家设置或存档。

var _ok := 0
var _bad := 0


func _check(label: String, condition: bool, detail := "") -> void:
	if condition:
		_ok += 1
		print("✓ ", label)
	else:
		_bad += 1
		print("✗ ", label, " — ", detail)


func _initialize() -> void:
	GameSettings.ensure_loaded()
	GameSettings.language = "es"
	GameI18n.reset_cache()
	_check("注册西班牙语", L10n.has_language("es"))
	_check("语言桥读取 es", GameI18n.language() == "es")
	_check("标题骨架", L10n.t("title.start") == "Iniciar partida", L10n.t("title.start"))
	_check("显式语言不受当前西语影响", L10n.t("title.start", "en") == "Start Run"
			and L10n.t("title.start", "ja") == "冒険を始める"
			and L10n.t("title.start", "es") == "Iniciar partida")
	_check("界面 scope.key", GameI18n.ui("shop", "SHOP_TITLE", "神秘商店") == "Tienda misteriosa",
			GameI18n.ui("shop", "SHOP_TITLE", "神秘商店"))

	var cards: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/cards_es.json"))
	var card: Dictionary = cards["cards"]["8002"]
	_check("卡牌名按 ID", GameI18n.card_name(8002, "攻击") == card["name"],
			GameI18n.card_name(8002, "攻击"))
	_check("卡牌效果按 ID", GameI18n.card_effect(8002, "造成 6 点伤害。") == card["effect_text"],
			GameI18n.card_effect(8002, "造成 6 点伤害。"))

	var noncard: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/noncard_es.json"))
	_check("道具按 ID", GameI18n.relic_name(6001, "类固醇") == noncard["relics"]["6001"]["name"])
	_check("角色名与数据同源", GameI18n.class_name_of("暗影刺客") == noncard["classes"]["暗影刺客"]["name"],
			GameI18n.class_name_of("暗影刺客"))
	_check("角色说明按 ID", GameI18n.class_field("森林精魄", "subtitle", "")
			== noncard["classes"]["森林精魄"]["subtitle"])

	var traps: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/traps_es.json"))
	_check("工具按 ID", GameI18n.trap_name(7001, "") == traps["traps"]["7001"]["name"])

	# R690：工具三语（en / ja / es 各自成文件，缺条目就回退中文 —— 这正是要拦的）
	var tool_langs: Array[String] = ["en", "ja", "es"]
	var tool_ids: Array[String] = ["7001", "7002", "7003", "7004", "7005", "7006"]
	var place_ids: Array[String] = ["7001", "7002", "7003", "7004"]
	var use_ids: Array[String] = ["7005", "7006"]
	var tool_missing := ""
	var tool_op_bad := ""
	var tool_cjk := ""
	var tool_packs := {}
	for code in tool_langs:
		var pack: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://i18n/traps_%s.json" % code))
		if not (pack is Dictionary) or not pack.has("traps"):
			tool_missing = "%s 文件缺失或结构不对" % code
			continue
		tool_packs[code] = pack["traps"]
		var rows: Dictionary = pack["traps"]
		for tid in tool_ids:
			var row: Variant = rows.get(tid, null)
			if not (row is Dictionary) or str(row.get("name", "")).strip_edges() == "" \
					or str(row.get("desc", "")).strip_edges() == "":
				tool_missing = "%s / %s 条目缺失" % [code, tid]
				continue
			# 中文底本 vs 译文：拉丁语种不能残留汉字；日文本就用汉字，改查「有没有假名」——
			# 一条日文说明里连一个假名都没有，基本就是整条回退成了中文。
			var body := str(row["name"]) + str(row["desc"])
			if code == "ja":
				var has_kana := false
				for ci in body.length():
					var u := body.unicode_at(ci)
					if u >= 0x3040 and u <= 0x30FF:
						has_kana = true
						break
				if not has_kana:
					tool_cjk = "ja / %s 无假名，疑似中文回退" % tid
			elif GameI18n._has_cjk(body):
				tool_cjk = "%s / %s 残留中文：%s" % [code, tid, body.substr(0, 24)]
	_check("工具三语条目齐全（en·ja·es × 6 件）", tool_missing == "", tool_missing)
	_check("工具三语无中文残留（日文查假名）", tool_cjk == "", tool_cjk)
	# 操作口径：放置型必须写「拖到格子」，使用型必须写「轻点 / 不要拖」
	for code in tool_langs:
		if not tool_packs.has(code):
			continue
		var rows2: Dictionary = tool_packs[code]
		for tid in place_ids:
			if not rows2.has(tid):
				continue
			var dsc := str(rows2[tid].get("desc", "")).to_lower()
			var drag_ok := dsc.contains("arrástrala") or dsc.contains("ドラッグ") \
					or dsc.contains("drag ")
			if not drag_ok:
				tool_op_bad += "%s/%s 缺拖放说明 " % [code, tid]
		for tid in use_ids:
			if not rows2.has(tid):
				continue
			var dsc2 := str(rows2[tid].get("desc", "")).to_lower()
			var tap_ok := dsc2.contains("tócala") or dsc2.contains("タップ") \
					or dsc2.contains("tap it")
			if not tap_ok:
				tool_op_bad += "%s/%s 缺轻点说明 " % [code, tid]
	_check("工具操作口径三语齐全（放置＝拖到格子 / 使用＝轻点）", tool_op_bad == "",
			tool_op_bad.strip_edges())
	# 桥路：切到 en / ja 时取到的必须是文件里的值，而不是中文回退
	var bridge_bad := ""
	for code in tool_langs:
		GameSettings.language = code
		GameI18n.reset_cache()
		if not tool_packs.has(code):
			continue
		var bp: Dictionary = tool_packs[code]
		for tid in tool_ids:
			if not bp.has(tid):
				continue
			var want := str(bp[tid]["name"])
			var got := GameI18n.trap_name(int(tid), "")
			if got != want:
				bridge_bad += "%s/%s 取到 %s " % [code, tid, got]
	_check("工具译名经 GameI18n 逐语言取到（非中文回退）", bridge_bad == "",
			bridge_bad.strip_edges())
	GameSettings.language = "es"
	GameI18n.reset_cache()

	var narrative: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/narrative_es.json"))
	var story: Dictionary = narrative["stories"]["episode1"]
	_check("剧情标题按 ID", GameI18n.story_value("episode1", "title", 0, "") == story["title"])
	_check("剧情正文按行", GameI18n.story_value("episode1", "text", 0, "") == story["text"][0])

	var dynamic := GameI18n.source("在这里休息（回复 12 生命）")
	_check("已格式化模板", dynamic.contains("12") and not dynamic.contains("回复"), dynamic)
	var aliased := GameI18n.source("肩上那座鸭梨山，你已经背起来了。\n往后每一次受伤，都会让你更「强大」一点——\n只是那点强大，补不回已经失去的血。")
	_check("事件原文别名", aliased == narrative["events"]["pear"]["texts"]["PEAR_TAKEN_DESC"], aliased)
	_check("缺 ID 回退调用方原文", GameI18n.card_name(-1, "回退") == "回退")
	_check("缺界面键回退调用方原文", GameI18n.ui("shared", "__MISSING__", "回退") == "回退")

	GameSettings.language = "zh"
	var zh_segments := CardText.parse("对一个目标造成 4 点伤害。")
	var zh_text := CardText.segments_plain(zh_segments)
	GameSettings.language = "es"
	var es_segments := CardText.parse("对一个目标造成 4 点伤害。")
	var es_text := CardText.segments_plain(es_segments)
	_check("卡面缓存按语言隔离", zh_text != es_text and not es_text.contains("伤害"),
			zh_text + " -> " + es_text)
	GameSettings.language = "zh"
	_check("切回中文恢复原卡面", CardText.segments_plain(CardText.parse("对一个目标造成 4 点伤害。")) == zh_text)
	_check("中文界面与道具不落英文回退", GameI18n.ui("reward", "REWARD_TYPE_BOSS", "Boss过关奖励")
			== "Boss过关奖励" and GameI18n.relic_name(6001, "类固醇") == "类固醇",
			GameI18n.ui("reward", "REWARD_TYPE_BOSS", "Boss过关奖励"))

	GameSettings.language = "es"
	_check("西语卡名可反查提及 ID", int(Mention.resolve("Golpe").get("id", -1)) == 8002)
	_check("西文书名号保留提及扫描", Mention.scan("Obtén «Golpe»").size() == 1)
	var interface: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/interface_es.json"))
	_check("地图类型访问函数", RogueMap.type_label("battle") == interface["scopes"]["map"]["ROGUE_MAP_TYPE_BATTLE"])
	_check("奖励类型访问函数", CardReward.type_label("normal") == interface["scopes"]["reward"]["REWARD_TYPE_NORMAL"])
	_check("层名访问函数", GameLayers.layer_name(1) == interface["scopes"]["shared"]["LAYER_ONE_NAME"])
	var duck_level: Dictionary = {}
	for lvl in GameLevels.builtin_levels():
		if GameLevels.bg_key(lvl) == "duck_knight":
			duck_level = lvl
			break
	_check("关卡名按稳定 key", not duck_level.is_empty()
			and GameLevels.display_name(duck_level) == interface["scopes"]["battle"]["LEVEL_DUCK_KNIGHT"])
	_check("洞穴事件关也有显示名", GameLevels.display_name(GameLevels.cave_level())
			== interface["scopes"]["battle"]["LEVEL_CAVE_OWLBEAR"])
	_check("战斗分级与 HUD 访问函数", GameLevels.tier_name(GameLevels.TIER_ELITE_EASY)
			== interface["scopes"]["battle"]["TIER_ELITE_EASY"]
			and GameI18n.ui("battle", "BATTLE_EFFECTS", "效果区 %d") % 2
			== interface["scopes"]["battle"]["BATTLE_EFFECTS"] % 2)
	var traits_ok := true
	var trait_failure := ""
	for trait_card in CardRepo.load_json().all_cards():
		for trait_name in trait_card.traits:
			var localized := GameI18n.source(str(trait_name))
			if localized == str(trait_name) or GameI18n._has_cjk(localized):
				traits_ok = false
				trait_failure = "%d %s -> %s" % [trait_card.id, str(trait_name), localized]
				break
		if not traits_ok:
			break
	_check("卡库全部特性无中文残留", traits_ok, trait_failure)
	_check("术语表与种类译名一致", GameI18n.source("防御") == "Defensa"
			and GameI18n.source("工事") == interface["scopes"]["map"]["GALLERY_KIND_STRUCTURE"])
	var skill_card := CardRepo.load_json().get_card(8002)
	_check("卡面数值行访问函数", CardFace.stats_line(skill_card) == interface["scopes"]["shared"]["CARD_FACE_SKILL_STATS"])

	print("I18N === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
	quit(0 if _bad == 0 else 1)
