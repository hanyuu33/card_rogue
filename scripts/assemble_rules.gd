extends RefCounted

const BLACKLIST := ["card_played", "kill"]
const DEFERRED := ["random_gained"]
const TRIGGERS := ["use", "enter", "death", "upgraded", "turn_end", "turn_start",
	"attack", "attacked", "damaged", "effect_played", "turn_first_play", "after_draw", "action_end"]
const LABELS := {"use": "使用时", "enter": "入场时", "death": "死亡时", "upgraded": "每次被改造时", "turn_end": "回合结束时", "turn_start": "回合开始时", "attack": "攻击后", "attacked": "被攻击时", "damaged": "受伤后", "effect_played": "使用效果卡后", "turn_first_play": "回合首次使用卡后", "after_draw": "抽牌后", "action_end": "行动结束时"}

static func valid_effect(fx: Variant) -> bool:
	if not fx is Dictionary or fx.get("type", "") not in CardData.ASSEMBLE_EFFECT_TYPES:
		return false
	if fx.type in ["shield", "taunt", "freeze", "stun"]:
		return true
	if fx.type == "summon":
		return (fx.get("value") is int or fx.get("value") is float) and int(fx.get("value")) > 0
	if not fx.get("value") is int and not fx.get("value") is float:
		return false
	if float(fx.value) < 0 or float(fx.value) != int(fx.value):
		return false
	if fx.type == "damage":
		return fx.get("target", "nearest") in ["nearest", "all", "random"]
	return true

static func valid_pool(upper: Array, lower: Array) -> bool:
	if upper.is_empty() or lower.is_empty():
		return false
	for half in [upper, lower]:
		for part in half:
			if not part is Dictionary or not part.get("effects", []) is Array:
				return false
			for fx in part.get("effects", []):
				if not valid_effect(fx):
					return false
			for affix in part.get("extra_affixes", []):
				if not CardData.AFFIX_DEFS.has(str(affix)):
					return false
	for part in upper:
		if part.get("trigger", "") not in TRIGGERS:
			return false
	for part in lower:
		## R565：下半**允许自带时机** —— 「使用后，你在本回合结束时获得 5 费用」这类卡，
		## 效果挂在另一个时机上；下半没写 trigger 时才跟随上半的时机。
		if part.get("effects", []).is_empty() or part.has("extra_affixes"):
			return false
		if part.has("trigger") and str(part.get("trigger", "")) not in TRIGGERS:
			return false
	return true

static func effect_text(fx: Dictionary) -> String:
	var n := int(fx.get("value", 0))
	match str(fx.type):
		"draw": return "抽%d张牌" % n
		"buff": return "获得+%d力量/+%d生命" % [n, n]
		"damage":
			var dmg_label := "全体敌人" if fx.get("target", "nearest") == "all" else ("随机敌人" if fx.get("target", "nearest") == "random" else "最近敌人")
			return "对%s造成%d点伤害" % [dmg_label, n]
		"heal": return "回复%d点生命" % n
		"shield": return "获得护盾"
		"taunt": return "获得嘲讽"
		"summon": return "召唤%d个%s" % [int(fx.get("count", 1)), card_label(int(fx.get("value", 0)))]
		"upgrade": return "获得改造：+%d力量/+%d生命" % [n, n]
		"energy": return "回复%d点费用" % n
		"knockback": return "将最近敌人击退%d格" % n
		"freeze": return "冰封最近敌人"
		"stun": return "眩晕最近敌人"
		"range": return "攻击距离 +%d" % n
	return ""


static var _card_name_cache: Dictionary = {}

static func card_label(card_id: int) -> String:
	if not _card_name_cache.has(card_id):
		var repo := CardRepo.load_json()
		var c := repo.get_card(card_id)
		_card_name_cache[card_id] = c.card_name if c != null else "衍生物"
	return str(_card_name_cache[card_id])

static func effects_text(fx_list: Array) -> String:
	var texts: Array[String] = []
	for fx in fx_list:
		texts.append(effect_text(fx))
	return "，".join(texts)


static func body_text(part: Dictionary) -> String:
	## 只出效果本身、**不带时机**（下半槽位用它 —— 时机已经由上半那张卡提供了）。
	return effects_text(part.get("effects", []))


static func lower_text(lower: Dictionary, upper_trigger: String) -> String:
	## R566：下半框的文案（用户实测反馈：「混乱之影下半应该是抽一张牌」）。
	##
	## 原先这里错用 `fragment_text`，它会把下半的时机一并印出来 → 13 张**全部**显示成
	## 「攻击时：回复 1 点费用」这种完整句子，看着像上下半各抄了一遍整卡。
	## 现在的口径：下半**只写效果**；只有当下半的时机与上半不同（黑暗领主 = 上半 use、
	## 下半 turn_end）才补上时机，否则玩家读不出它挂在另一个时机上。
	## 上半槽还空着（upper_trigger == ""）时也带时机 —— 那时玩家手上没有任何上下文。
	var body := body_text(lower)
	if body == "":
		return ""
	var t := str(lower.get("trigger", ""))
	if t == "" or t == upper_trigger:
		return body
	return str(LABELS.get(t, "")) + "：" + body


static func assembled_text(asm: Dictionary) -> String:
	## R565：组合卡的效果文本 = 上半（时机：效果）+ 下半（时机：效果）。
	## 上半可以是**空钩子**（只提供时机、没有效果，用户口径「上半只有钩子也无所谓」）——
	## 那时只写下半，不写「（无）」这种占位。
	var t1 := str(asm.get("trigger", ""))
	var t2 := str(asm.get("lower_trigger", ""))
	var s1 := effects_text(asm.get("effects", []))
	var s2 := effects_text(asm.get("lower_effects", []))
	var out := ""
	if s1 != "":
		out = str(LABELS.get(t1, "")) + "：" + s1
	if s2 != "":
		if out != "":
			out += "。"
			# 上半已有内容：下半时机与上半相同就不重复写
			if t2 != "" and t2 != t1:
				out += str(LABELS.get(t2, "")) + "："
		else:
			# R566：上半是空钩子时，产物卡面上**必须**写出时机 ——
			# 产物是一张独立卡，卡面没别的地方能看出它挂在哪个时机。
			out += str(LABELS.get(t2, "")) + "："
		out += s2
	return out


static func fragment_text(part: Dictionary) -> String:
	var texts: Array[String] = []
	for fx in part.get("effects", []):
		texts.append(effect_text(fx))
	var prefix := str(LABELS.get(part.get("trigger", ""), ""))
	return (prefix + "：" if prefix != "" else "") + "，".join(texts)

static func build(base: CardData, upper: Dictionary, lower: Dictionary, reverse: bool = false) -> CardData:
	if not valid_pool([upper], [lower]):
		return null
	var result := CardData.from_dict(base.to_dict())
	var first: Dictionary = lower if reverse else upper
	var second: Dictionary = upper if reverse else lower
	# R565：上下半各自带时机（下半没写就跟上半），两边都空是不可能的 —— valid_pool 保证上半有时机。
	var t1 := str(first.get("trigger", ""))
	var t2 := str(second.get("trigger", ""))
	if t1 == "":
		t1 = t2
	if t2 == "":
		t2 = t1
	result.assemble = {
		"trigger": t1,
		"effects": (first.get("effects", []) as Array).duplicate(true),
		"lower_trigger": t2,
		"lower_effects": (second.get("effects", []) as Array).duplicate(true),
		"extra_affixes": (first.get("extra_affixes", []) as Array).duplicate(true),
	}
	for affix in result.assemble.extra_affixes:
		result.add_affix(str(affix))
	result.effect_text = assembled_text(result.assemble)
	return result
