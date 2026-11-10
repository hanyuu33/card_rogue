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
	# R569：「加卡 / 减费 / 改造」三个动作的数值必须 ≥1 —— 0 张 / 减 0 费 / 改造 +0
	# 等于一个空动作，卡面却会写出来，玩家会以为自己拿到了东西。
	if fx.type in ["add_random_effect", "hand_discount", "hand_upgrade"]:
		return int(fx.value) >= 1
	return true

static func valid_passive(pv: Variant) -> bool:
	## R568：上半可带**永续段**（`passive`）—— 犀牛「受到伤害减少 1 点，但至少仍要受到 1 点」。
	## 它**没有扳机、永远生效**，所以不能塞进 `effects`（那是跟着扳机结算的）。
	##   · `text`     ：逐字取自原卡 `effect_text` 的描述（测试里有保真锁，编不出来）
	##   · `reduce`   ：可结算的数值部分（减伤点数），缺省 = 0 = 纯描述
	##   · `source_trait`：这条永续来自原卡的哪个 trait（犀牛 9016 = "犀牛"）。
	##     承载体本身就是那张卡时，它的常驻能力已经由 trait 生效，build 会据此把 `reduce`
	##     清零只留文本 —— 否则同一机制被算两次（减 2 而不是 1）。
	if not pv is Dictionary:
		return false
	if not pv.get("text", "") is String:
		return false
	if str(pv.get("text", "")).strip_edges() == "":
		return false
	if not pv.get("source_trait", "") is String:
		return false
	if pv.has("reduce"):
		var rd: Variant = pv.get("reduce")
		if not rd is int and not rd is float:
			return false
		if float(rd) < 0 or float(rd) != int(rd):
			return false
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
		# R568：上半的永续段（可选）。下半**不允许**带 —— 下半只承载跟着扳机走的效果。
		if part.has("passive") and not valid_passive(part.get("passive", {})):
			return false
	for part in lower:
		## R567（用户口径）：「下半不应该是完整效果，需要裁掉上半部分 —— 扳机是在上半的，
		## 不应该也分发到下半」。所以下半**结构上不允许有 trigger**：有就是数据写错了，直接判废。
		## 下半只承载「效果」+ 可选的 `note`（纯描述，如「在本回合结束时」，不是扳机）。
		if part.has("trigger") or part.has("extra_affixes"):
			return false
		if part.get("effects", []).is_empty():
			return false
		if not part.get("note", "") is String:
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
		"purge_curse":
			return "清除你的抽牌堆、手卡、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 %d 点伤害" % n
		"add_random_effect":
			var ae_src := "从卡组" if str(fx.get("from", "")) == "deck" else ""
			return "%s随机将%d张效果卡加入你的手卡" % [ae_src, maxi(1, n)]
		"hand_upgrade":
			return "手卡中的盟友获得改造：生命 +%d" % n
		"hand_discount":
			return "随机一张手牌本回合费用 -%d" % n
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
	## 只出「效果本身」，**永远不带扳机**（下半槽位用它 —— 扳机由上半那张卡提供）。
	## R567：用户口径「下半不应该是完整效果，需要裁掉上半部分」。这里不再有任何
	## 「跨时机就补扳机前缀」的分支 —— 那种补法会让下半重新变成整句，
	## 而且产物卡面写 A 时机、实际按 B 时机结算，显示与结算必然打架。
	## `note` 是**描述性前缀**（如黑暗领主的「在本回合结束时」），不是扳机，不带冒号。
	var body := effects_text(part.get("effects", []))
	return str(part.get("note", "")) + body


static func assembled_text(asm: Dictionary) -> String:
	## 组合卡的效果文本 = **一个扳机**（来自上半那张卡）+ 上半效果 + 下半效果。
	## 上半可以是**空钩子**（只提供扳机、没有效果，用户口径「上半只有钩子也无所谓」）。
	## 下半的 `lower_note` 是描述性前缀，紧贴在下半效果前面（黑暗领主 =「在本回合结束时获得5点费用」）。
	var t := str(asm.get("trigger", ""))
	var s1 := effects_text(asm.get("effects", []))
	var s2 := str(asm.get("lower_note", "")) + effects_text(asm.get("lower_effects", []))
	var out := ""
	if s1 != "":
		out = s1
	if s2 != "":
		out = s2 if out == "" else (out + "。" + s2)
	var pv := str((asm.get("passive", {}) as Dictionary).get("text", ""))
	# R568：只有永续段、没有扳机效果时，产物文本就是那半句（不必硬凑一个空冒号）。
	if out == "":
		return pv
	var one := str(LABELS.get(t, "")) + "：" + out
	return pv + one if pv != "" else one


static func passive_text(part: Dictionary) -> String:
	## 上半永续段的描述文本（没有就是空串）。
	var pv: Dictionary = part.get("passive", {}) if part.get("passive", {}) is Dictionary else {}
	return str(pv.get("text", ""))


static func fragment_text(part: Dictionary) -> String:
	## 上半槽的文案 = 永续段 + 扳机 + 效果。
	## R568：犀牛的「受到伤害减少 1 点，但至少仍要受到 1 点」没有扳机、永远生效，
	## 印在扳机**前面**（原卡也是这个语序）。永续句自带句号，不再补分隔符。
	var texts: Array[String] = []
	for fx in part.get("effects", []):
		texts.append(effect_text(fx))
	var prefix := str(LABELS.get(part.get("trigger", ""), ""))
	var body := (prefix + "：" if prefix != "" else "") + "，".join(texts)
	var pv := passive_text(part)
	if pv != "":
		return pv + body
	return body

static func build(base: CardData, upper: Dictionary, lower: Dictionary, reverse: bool = false) -> CardData:
	if not valid_pool([upper], [lower]):
		return null
	var result := CardData.from_dict(base.to_dict())
	var first: Dictionary = lower if reverse else upper
	var second: Dictionary = upper if reverse else lower
	# R567：产物只有**一个扳机** —— 就是上半那张卡的（valid_pool 保证上半一定有）。下半的
	# 效果挂在同一个扳机上一起结算，`note` 只影响文案，不改变触发时机。
	var pv: Dictionary = {}
	if upper.get("passive", {}) is Dictionary:
		pv = (upper.get("passive", {}) as Dictionary).duplicate(true)
	# R568：承载体本身就是那张卡（犀牛做第①张）时，它的常驻减伤**已经由 traits 生效**，
	# 这里把 `reduce` 清零、只留文本 —— 否则同一机制被算两次（减 2 而不是 1）。
	var src_trait := str(pv.get("source_trait", ""))
	if src_trait != "" and base != null and base.traits.has(src_trait):
		pv.erase("reduce")
	result.assemble = {
		"trigger": str(upper.get("trigger", "")),
		"effects": (first.get("effects", []) as Array).duplicate(true),
		"lower_effects": (second.get("effects", []) as Array).duplicate(true),
		"lower_note": str(second.get("note", "")),
		"passive": pv,
		"extra_affixes": (first.get("extra_affixes", []) as Array).duplicate(true),
	}
	for affix in result.assemble.extra_affixes:
		result.add_affix(str(affix))
	result.effect_text = assembled_text(result.assemble)
	return result
