extends SceneTree
## R596 只读探针：把 `UiAssets` 的**每个取图口**按数据表枚举一遍，逐个报 null。
##
## 与 `probe_all_art.gd`（只验卡图）互补：这里覆盖遗物、职业、地图、事件、徽章、
## 附魔、卡框、缎带、单例底图等所有类目 —— 「文件存在」不等于「导出包里能加载」，
## 必须真的过一遍 `ResourceLoader`。
##
## 用法：Godot --headless --path . --script res://tools/probe_all_assets.gd

const UI = preload("res://scripts/ui_assets.gd")
const CardDataScript = preload("res://scripts/card_data.gd")

var _miss: Array = []
var _n := 0


func _chk(family: String, key: String, tex: Texture2D) -> void:
	_n += 1
	if tex == null:
		_miss.append(family + ":" + key)


func _init() -> void:
	# ── 稀有度缎带（0..6）──────────────────────────────────────────────
	# `card_frame()` 是死代码（只有定义、全库无调用；边框改由 art_frame + ribbon 承担），
	# 它的 `frame_%d` 素材从来没进过库 —— 不列入缺口。
	for r in range(0, 7):
		_chk("ribbon", str(r), UI.rarity_ribbon(r))

	# ── 卡面艺术框（按卡类别）────────────────────────────────────────
	for k in ["common", "enemy", "forest", "mech", "shadow"]:
		_chk("art_frame", k, UI.art_frame(k))

	# ── 遗物图标 + 边缘光（relics.json 全量）─────────────────────────
	var rd: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://relics.json"))
	if rd is Dictionary:
		for it in rd.get("relics", []):
			var rid := int(it.get("id", 0))
			_chk("relic_icon", str(rid), UI.relic_icon(rid))
			_chk("relic_rim", str(rid), UI.relic_rim(rid))

	# ── 职业四件套 ────────────────────────────────────────────────────
	# ⚠️ 这组吃**职业中文 id**（class_key 是唯一映射口），不是素材键
	for k in ["森林精魄", "暗影刺客", "机械之心"]:
		_chk("class_cg", k, UI.class_cg(k))
		_chk("class_avatar", k, UI.class_avatar(k))
		_chk("class_avatar_locked", k, UI.class_avatar_locked(k))
		_chk("class_badge", k, UI.class_badge(k))

	# ── 地图节点（含 boss —— 审计脚本的 NODE_TYPES 漏了它）──────────
	for k in ["battle", "bigchest", "chest", "elite", "event", "rest", "shop", "start", "unknown", "boss"]:
		_chk("node_icon", k, UI.node_icon(k))
	for layer in range(1, 4):
		_chk("map_bg", str(layer), UI.map_bg(layer))
	_chk("map_fog", "-", UI.map_fog())
	_chk("bridge_icon", "-", UI.bridge_icon())

	# ── 事件三类（26 个 kind）────────────────────────────────────────
	var kinds := ["adventurer", "apple_doctor", "arcane", "bluefish", "card_merchant", "cave",
			"core_contract", "delivery", "delivery_done", "divination", "flyer", "furnace",
			"gaze", "hero", "lake_lady", "martial", "moon", "oblivion", "pear", "relic_chest",
			"rest", "smith", "snow_leopard", "struggle", "treasure", "whisper"]
	for k in kinds:
		_chk("event_pic", k, UI.event_pic(k))
		_chk("event_side", k, UI.event_side_pic(k))
		_chk("event_bg", k, UI.event_bg(k))
	for i in range(1, 5):
		_chk("div_vision", str(i), UI.div_vision(i))

	# ── 字段标志（10 枚）────────────────────────────────────────────
	# ⚠️ 吃的是 `CardData.affix_glyph(字段名)` 的英文 glyph，不是字段中文名
	for n in ["疾行", "嘲讽", "死亡", "幻影", "护盾", "次元", "超负荷", "交换", "保存", "共享护盾"]:
		var g: String = CardDataScript.affix_glyph(n)
		_chk("affix_badge", n, UI.affix_badge(g) if g != "" else null)

	# ── 数值徽章 ────────────────────────────────────────────────────
	for k in ["cost", "power", "range", "health", "speed"]:
		_chk("badge_icon", k, UI.badge_icon(k))

	# ── 附魔图标（ENCHANT_DEFS 全量）────────────────────────────────
	var ench: Dictionary = CardDataScript.ENCHANT_DEFS
	for id in ench.keys():
		_chk("enchant_icon", str(id), UI.enchant_icon(str(id)))

	# ── 单例底图 / 控件 ─────────────────────────────────────────────
	_chk("card_paper", "-", UI.card_paper())
	_chk("card_back", "-", UI.card_back())
	_chk("scroll_parchment", "-", UI.scroll_parchment())
	_chk("panel_parchment", "-", UI.panel_parchment())
	_chk("div_orb_glass", "-", UI.div_orb_glass())
	_chk("void_portal", "-", UI.void_portal())
	_chk("title_bg", "-", UI.title_bg())
	_chk("chocolate", "-", UI.chocolate())
	_chk("btn_primary", "-", UI.btn_primary())
	_chk("btn_plain", "-", UI.btn_plain())
	_chk("core_relic_icon", "-", UI.core_relic_icon())

	# ── 商店 / 奖励图标 ─────────────────────────────────────────────
	for k in ["shop_icon_remove", "shop_icon_card", "shop_icon_draw", "shop_icon_costdown",
			"shop_icon_damage", "shop_icon_dimension", "shop_icon_save", "shop_icon_opening",
			"shop_icon_maxhp", "shop_icon_dagger"]:
		_chk("shop_icon", k, UI.shop_icon(k))
	for k in ["cards", "core", "deck_delete", "gold", "legendary", "maxhp", "relic"]:
		_chk("reward_icon", k, UI.small_icon("reward_icons/" + k))

	print("ASSET_TOTAL n=", _n, " missing=", _miss.size())
	if not _miss.is_empty():
		print("ASSET_MISSING ", _miss)
	quit()
