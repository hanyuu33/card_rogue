extends RefCounted

const BLACKLIST := ["card_played", "kill"]
const DEFERRED := ["random_gained"]
## R589：三条新扳机 ——
##   · `use_after`「使用后」：母卡原文写「使用后」的那批（小精灵 9074 / 巨鼠 9046 /
##     乌鸦 9039 / 斑鸠 9052）。结算时机与 `use` 同处（打出结算完立刻），区别只在卡面文案 ——
##     所以引擎里两者走**同一个分发点**，不另开一条时序（另开会变成「说使用后、实际使用时」）。
##   · `active`「主动发动」：玩家点单位、花掉这次行动（之后横置），每单位在场只能发动一次。
##     规则句见 `TRIGGER_RULES`，与 `can_activate` / `activate` 的实现在同一条口径上。
##   · `lethal`「每次生命降到 0 或更低」：**跨越**判定（扣血前 > 0 且扣血后 <= 0）。
##     超负荷让单位负血留在场上，按「处于」判会每挨一下都再触发一次（忒修斯 9222 的老坑）。
const TRIGGERS := ["use", "use_after", "enter", "death", "upgraded", "turn_end", "turn_start",
	"attack", "attacked", "damaged", "effect_played", "turn_first_play", "after_draw", "action_end",
	"active", "lethal"]
const LABELS := {"use": "使用时", "enter": "入场时", "death": "死亡时", "upgraded": "每次被改造时", "turn_end": "回合结束时", "turn_start": "回合开始时", "attack": "攻击后", "attacked": "被攻击时", "damaged": "受伤后", "effect_played": "使用效果卡后", "turn_first_play": "回合首次使用卡后", "after_draw": "抽牌后", "action_end": "行动结束时",
	"use_after": "使用后", "active": "主动发动", "lethal": "每次生命降到 0 或更低"}
## R589：带**固有规则**的扳机 —— 规则句印在效果后面，且和结算同源：
## `active` 的「之后横置 / 在场只能发动一次」就是 `can_activate` + `activate` 的实现口径。
## 别在卡面另写一份（写了就会和引擎漂移：卡面说只能一次、实际能按两次）。
const TRIGGER_RULES := {"active": "，之后横置。在场只能发动一次。"}

static func valid_effect(fx: Variant) -> bool:
	if not fx is Dictionary or fx.get("type", "") not in CardData.ASSEMBLE_EFFECT_TYPES:
		return false
	# R583：absorb_linked 是「破坏一批卡并把属性加到自身」，没有数值字段。
	if fx.type in ["shield", "taunt", "freeze", "stun", "absorb_linked",
			"fetch_cheapest_ally", "recall_ally_from_discard"]:
		return true
	if fx.type == "summon":
		return (fx.get("value") is int or fx.get("value") is float) and int(fx.get("value")) > 0
	# R570：`buff_per_energy` 没有 `value` —— 它的数值是「每点剩余费用换多少」，两个分量。
	# 两个都是 0 就等于一个空动作（卡面会印出一句不打折扣的话），判废。
	if fx.type == "buff_per_energy":
		for key: String in ["atk", "hp"]:
			var rv: Variant = fx.get(key, 0)
			if not rv is int and not rv is float:
				return false
			if float(rv) < 0 or float(rv) != int(rv):
				return false
		return int(fx.get("atk", 0)) > 0 or int(fx.get("hp", 0)) > 0
	if not fx.get("value") is int and not fx.get("value") is float:
		return false
	if float(fx.value) < 0 or float(fx.value) != int(fx.value):
		return false
	if fx.type == "damage":
		return fx.get("target", "nearest") in ["nearest", "all", "random"]
	# R584：add_card 带 card_id（目标卡）+ value（数量），两者都必须有效，
	# 否则产物会印出「将0张衍生物加入你的手卡」这种空动作。
	if fx.type == "add_card":
		var ac_id: Variant = fx.get("card_id", 0)
		if not ac_id is int and not ac_id is float:
			return false
		# R585：from 只能是 "deck"（从卡组捞）；别的来源一律判废，避免编出不存在的口径。
		if fx.has("from") and str(fx.get("from", "")) != "deck":
			return false
		return int(ac_id) > 0 and int(fx.value) >= 1
	# R585：往抽牌库加指定卡（集束炮台入场句）。card_id + value 都必须有效。
	if fx.type == "add_card_to_deck":
		var ad_id: Variant = fx.get("card_id", 0)
		if not ad_id is int and not ad_id is float:
			return false
		return int(ad_id) > 0 and int(fx.value) >= 1
	# R589：水元素 9068「从卡组将一张效果卡加入手卡，费用减少 N」。
	# 两个分量都要查：0 张 = 空动作；discount 缺省 0 是合法的（只取牌不减费）。
	if fx.type == "add_effect_from_deck":
		if not fx.get("value") is int and not fx.get("value") is float:
			return false
		var aed_d: Variant = fx.get("discount", 0)
		if not aed_d is int and not aed_d is float:
			return false
		return int(fx.value) >= 1 and int(aed_d) >= 0
	# R569：「加卡 / 减费 / 改造」三个动作的数值必须 ≥1 —— 0 张 / 减 0 费 / 改造 +0
	# 等于一个空动作，卡面却会写出来，玩家会以为自己拿到了东西。
	if fx.type in ["add_random_effect", "hand_discount", "hand_upgrade",
			"buff_per_ally", "heal_per_energy", "draw_random_skill",
			"hand_cost_raise", "add_copy", "buff_allies_atk",
			# R589：减 0 费 / 每张 +0 生命同样是空动作。
			"next_effect_discount", "next_ally_discount",
			"hand_skill_discount", "hp_per_zero_skill"]:
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


static func valid_upper(part: Variant) -> bool:
	## R571：上半半边的合法性 —— 从 `valid_pool` 抽出来的**唯一口**。
	## 组合页去掉「取消组合」之后没有退路，填槽时必须当场判断「这张卡能不能当②」，
	## 判据不许在 UI 里另写一份（另写就会跟 build 判废的口径漂移，玩家被锁死在页面上）。
	## 上半：必须有合法扳机；效果**可以为空**（空钩子，用户口径「上半只有钩子也无所谓」）；
	## `passive` 永续段可选（R568，下半不允许带）。
	if not part is Dictionary:
		return false
	if not part.get("effects", []) is Array:
		return false
	if part.get("trigger", "") not in TRIGGERS:
		return false
	for fx in part.get("effects", []):
		if not valid_effect(fx):
			return false
	# R585：独立入场段不挂主扳机，但每条动作仍要过同一份白名单校验。
	if not part.get("enter_effects", []) is Array:
		return false
	for fx in part.get("enter_effects", []):
		if not valid_effect(fx):
			return false
	for affix in part.get("extra_affixes", []):
		if not CardData.AFFIX_DEFS.has(str(affix)):
			return false
	if part.has("passive") and not valid_passive(part.get("passive", {})):
		return false
	return true


static func valid_lower(part: Variant) -> bool:
	## R571：下半半边的合法性（与 `valid_upper` 同源共用，理由同上）。
	## R567（用户口径）：「下半不应该是完整效果，需要裁掉上半部分 —— 扳机是在上半的，
	## 不应该也分发到下半」。所以下半**结构上不允许有 trigger**：有就是数据写错了，直接判废。
	## 下半只承载「效果」+ 可选的 `note`（纯描述，如「在本回合结束时」，不是扳机），
	## 且至少要有一条效果 —— 一句效果都没有的下半等于什么都没兑现。
	if not part is Dictionary:
		return false
	if not part.get("effects", []) is Array:
		return false
	if part.has("trigger") or part.has("extra_affixes"):
		return false
	if part.get("effects", []).is_empty():
		return false
	for fx in part.get("effects", []):
		if not valid_effect(fx):
			return false
	if not part.get("note", "") is String:
		return false
	return true


static func valid_pool(upper: Array, lower: Array) -> bool:
	if upper.is_empty() or lower.is_empty():
		return false
	for part in upper:
		if not valid_upper(part):
			return false
	for part in lower:
		if not valid_lower(part):
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
		# R583：逐字取自嵌合暴君 8047 的 effect_text（保真锁查两个特征串）。
		"absorb_linked": return "破坏所有与这张卡接通的己方卡，并将那些卡的力量与生命加到这张卡上"
		# R584：逐字对应「将一张「升级」加入你的手牌」/「把一张「聚能炮击」加入手卡」。
		"add_card":
			if str(fx.get("from", "")) == "deck":
				return "从卡组把%d张「%s」加入手卡" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]
			return "将%d张「%s」加入你的手卡" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]
		"add_card_to_deck": return "将%d张「%s」加入抽牌库" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]
		# ── R589：七条「母卡已有实现」的动作。文案逐字对着原卡 effect_text 写，
		#    `test_assemble._fx_in_text()` 有保真锁 —— 改这里必须连判据一起改。
		#    小精灵 9074：「使用后，你使用的下一张效果卡费用减少 2」
		"next_effect_discount": return "你使用的下一张效果卡费用减少 %d" % n
		# 斑鸠 9052：「使用后，本回合使用下一个盟友时，费用 -1」
		"next_ally_discount": return "本回合使用下一个盟友时，费用 -%d" % n
		# 水元素 9068：「使用时，从卡组将一张效果卡加入手卡，费用减少 2」
		"add_effect_from_deck": return "从卡组将%d张效果卡加入手卡，费用减少 %d" % [
				maxi(1, n), int(fx.get("discount", 0))]
		# 影魔 8007 前半：「手卡中所有技能牌本回合费用 -1」
		"hand_skill_discount": return "手卡中所有技能牌本回合费用 -%d" % n
		# 影魔 8007 后半：「手卡每有一张费用为 0 的技能卡，这张卡获得 +3 生命」
		"hp_per_zero_skill": return "手卡每有一张费用为 0 的技能卡，这张卡获得 +%d 生命" % n
		# 巨鼠 9046：「使用后从抽牌库将一张费用最低的盟友加入手卡」
		"fetch_cheapest_ally": return "从抽牌库将一张费用最低的盟友加入手卡"
		# 乌鸦 9039：「使用后选择弃牌堆中一张盟友回到手卡」
		"recall_ally_from_discard": return "选择弃牌堆中一张盟友回到手卡"
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
		# ── R570：六条「母卡已有实现」的动作。文案全部逐字对着原卡写，
		#    改这里之前先回去看那张卡的 effect_text（测试有保真锁，编不出来）。
		"buff_per_ally":
			return "自己场上每有一个其他盟友，获得 +%d 力量" % n
		"buff_per_energy":
			return "剩余费用每有 1 点，这张卡获得 %d 点力量和 %d 点生命" % [
					int(fx.get("atk", 0)), int(fx.get("hp", 0))]
		"heal_per_energy":
			return "回复 X 点生命值，X 为自己剩余费用（每 1 点剩余费用回复 %d 点生命，不超过生命上限）" % n
		"draw_random_skill":
			return "从卡组随机抽取一张技能牌，该卡本回合费用 -%d" % n
		"hand_cost_raise":
			return "本回合手卡中所有卡费用 +%d" % n
		"add_copy":
			return "手牌增加一张此卡的「短暂复制」"
		"buff_allies_atk":
			return "自己场上其他盟友攻击 +%d" % n
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
	## 组合卡的效果文本 = 独立段（入场 / 永续，不跟扳机）+ **一个扳机** + 上半效果 + 下半效果。
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
	# R585：上半的独立入场段 —— 不挂主扳机，印在最前面（原卡语序：入场句 → 钩子句）。
	var es := effects_text(asm.get("enter_effects", []))
	if es != "":
		es = "入场时，" + es + "。"
	var head := pv + es
	# R568 / R585：只有永续段、入场段而没有扳机效果时，产物文本就是那半句（不硬凑空冒号）。
	if out == "":
		return head
	# R589：扳机的固有规则句（目前只有 `active`）跟着产物一起印 —— 卡面写了才敢这么结算。
	var one := str(LABELS.get(t, "")) + "：" + out + str(TRIGGER_RULES.get(t, ""))
	return head + one if head != "" else one


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
	# R585：独立入场段印在扳机前面（原卡语序），不跟着扳机结算。
	var es := effects_text(part.get("enter_effects", []))
	if es != "":
		body = "入场时，" + es + "。" + body
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
		# R585：独立入场段只来自上半（reverse 时也不跟着换），不挂主扳机。
		"enter_effects": (upper.get("enter_effects", []) as Array).duplicate(true),
	}
	for affix in result.assemble.extra_affixes:
		result.add_affix(str(affix))
	result.effect_text = assembled_text(result.assemble)
	return result
