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
		if part.has("trigger") or part.get("effects", []).is_empty() or part.has("extra_affixes"):
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
	return ""


static var _card_name_cache: Dictionary = {}

static func card_label(card_id: int) -> String:
	if not _card_name_cache.has(card_id):
		var repo := CardRepo.load_json()
		var c := repo.get_card(card_id)
		_card_name_cache[card_id] = c.card_name if c != null else "衍生物"
	return str(_card_name_cache[card_id])

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
	var first: Array = lower.get("effects", []) if reverse else upper.get("effects", [])
	var second: Array = upper.get("effects", []) if reverse else lower.get("effects", [])
	var effects := first.duplicate(true)
	effects.append_array(second.duplicate(true))
	result.assemble = {"trigger": upper.trigger, "effects": effects, "extra_affixes": upper.get("extra_affixes", []).duplicate(true)}
	for affix in result.assemble.extra_affixes:
		result.add_affix(str(affix))
	result.effect_text = fragment_text(result.assemble)
	return result
