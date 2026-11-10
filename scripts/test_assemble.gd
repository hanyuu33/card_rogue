extends SceneTree
## R561：本套件只测「组合」——`assemble` 字段是组合产出的效果记号，结算层（13 时机 / 12 动作）
## 与 `AssembleRules.build` 都在；「拼装」作为独立入口（半句池 + 三步选卡 + 主体卡）已整体下线。
const Rules = preload("res://scripts/assemble_rules.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)
func _init() -> void:
	var base := CardData.new()
	base.card_name = "测试组合体"
	base.kind = "盟友"
	base.health = 10
	base.power = 2
	base.cost = 0
	var upper := [{"trigger":"use", "effects":[{"type":"draw", "value":1}]}, {"trigger":"death", "effects":[{"type":"damage", "value":2}]}, {"trigger":"upgraded", "effects":[{"type":"buff", "value":1}]}]
	var lower := [{"effects":[{"type":"damage", "value":3}]}, {"effects":[{"type":"draw", "value":2}]}, {"effects":[{"type":"taunt"}]}]
	for u in upper:
		for l in lower:
			for reverse in [false, true]:
				var card := Rules.build(base, u, l, reverse)
				check(card != null and card.assemble.effects.size() + card.assemble.lower_effects.size() == 2,
						"18 combinations build")
				check(card.assemble.effects[0] == (l.effects[0] if reverse else u.effects[0]), "order")
				var copy := CardData.from_dict(card.to_dict())
				copy.assemble.effects[0].type = "shield"
				check(card.assemble.effects[0].type != "shield", "deep copy")
	# 组合结果卡 = 属性卡副本 + 上下半效果（卡名 / 卡图 / 身材 / 稀有度全沿用属性卡）
	var built := Rules.build(base, upper[2], lower[2])
	check(built != null and built.assemble.trigger == "upgraded", "build upgraded/taunt")
	check(built.card_name == base.card_name and built.health == base.health
			and built.power == base.power and built.cost == base.cost, "result keeps attr card shell")
	var state := FieldState.new([], 20, 20, -1, "测试", false)
	var eng := GameEngine.new(state)
	eng.ai_enabled = false
	state.hand.append(built)
	var used_card := eng.play_from_hand(0, Vector2i(4, 1))
	check(used_card != null, "unit placed")
	var p: Placement = state.unit_at(Vector2i(4, 1))
	check(p != null, "unit at cell")
	if p != null:
		eng._on_unit_upgraded(p)
		check(p.upgrade_atk == 1 and p.health == 11 and p.card.affixes.has("嘲讽"), "upgrade dispatch")
		check(eng._card_leaving_field(p).health == 10, "temporary buff restored")
		check(not eng._card_leaving_field(p).assemble.is_empty(), "assembly survives bounce")
		for trigger in ["enter", "death", "turn_end", "use"]:
			p.card.assemble = {"trigger":trigger, "effects":[{"type":"shield"}]}
			p.first_hit_shield = false
			match trigger:
				"enter": eng._on_ally_entered(p, "self")
				"death": eng._deathrattle(Vector2i(4, 1), p)
				"turn_end": eng._assemble_tick("self", trigger)
				"use": eng._assemble_execute(p, Vector2i(4, 1), trigger)
			check(p.first_hit_shield, "dispatch " + trigger)
	var foe_card := CardData.from_dict(base.to_dict())
	foe_card.traits.clear()
	foe_card.health = 30
	var foe := state.place(foe_card, Vector2i(2, 1), "opponent")
	p.card.assemble = {"trigger":"use", "effects":[{"type":"damage", "value":3, "target":"nearest"}, {"type":"heal", "value":2}]}
	p.health = 5
	eng._assemble_execute(p, Vector2i(4, 1), "use")
	check(foe.health == 27 and p.health == 7, "damage and heal")
	var second := CardData.from_dict(base.to_dict())
	second.traits.clear()
	second.assemble = {"trigger":"use", "effects":[{"type":"shield"}]}
	state.hand.append(second)
	var used := eng.play_from_hand(state.hand.find(second), Vector2i(5, 0))
	check(used != null and used.first_hit_shield, "actual use hook")
	_test_extended_triggers()
	_test_source_locks()
	_test_new_actions()
	_test_retired_assemble()
	_test_combo()
	_test_r565_fidelity()
	_test_r566_split_text()
	_test_r568_passive()
	_test_r569_purge()
	_test_r569_actions()
	_test_r569_pool_forms()
	_test_r570_actions()
	print("Combination tests failures: ", failures)
	quit(failures)

func _fx_in_text(fx: Dictionary, text: String) -> bool:
	## 单个组合动作是否能在原卡文本里找到出处（R565 保真判据）。
	var n := int(fx.get("value", 0))
	match str(fx.type):
		"heal": return text.contains("%d 点生命" % n)
		"damage": return text.contains("%d 点伤害" % n)
		"energy": return text.contains("%d 点费用" % n)
		"buff": return text.contains("+%d 力量" % n)
		"range": return text.contains("攻击距离+%d" % n) or text.contains("攻击距离 +%d" % n)
		"draw": return text.contains("抽一张")
		"stun": return text.contains("眩晕")
		"knockback": return text.contains("击退 %d 格" % n)
		"purge_curse": return text.contains("所有诅咒") and text.contains("%d 点伤害" % n)
		"add_random_effect": return text.contains("效果卡")
		"hand_discount": return text.contains("本回合费用 -%d" % n)
		"hand_upgrade": return text.contains("生命 +%d" % n)
		# ── R570：六条新动作的保真判据。特征串取自各母卡的 effect_text，
		#    改文案要连这里一起改（否则测试立刻红，正是想要的效果）。
		"buff_per_ally": return text.contains("每有一个其他盟友") and text.contains("获得 +%d 力量" % n)
		"buff_per_energy":
			return text.contains("剩余费用每有 1 点") \
					and text.contains("%d 点生命" % int(fx.get("hp", 0)))
		"heal_per_energy": return text.contains("剩余费用") and text.contains("回复 %d 点生命" % n)
		"draw_random_skill":
			return text.contains("技能牌") and text.contains("本回合费用 -%d" % n)
		"hand_cost_raise": return text.contains("费用 +%d" % n)
		"add_copy": return text.contains("复制")
		"buff_allies_atk": return text.contains("其他盟友攻击 +%d" % n)
	return true


func _test_r565_fidelity() -> void:
	## R565：用户口径「确保上下半拆分的效果是原本的」。
	## R559e 那版是凭印象手编的 —— 黑暗领主本体根本没有「造成 3 点伤害」，榴弹击手也没有
	## （它只有「攻击距离+1」）。这一节把「保真」钉成可回归的规则，并锁住下半独立时机 + 专属印记。
	var repo := CardRepo.load_json()
	var rows := 0
	for c: CardData in repo.all_cards():
		if c.upper_effect.is_empty() and c.lower_effect.is_empty():
			continue
		rows += 1
		var text := c.effect_text.replace("**", "")
		for fx in (c.lower_effect.get("effects", []) as Array):
			check(_fx_in_text(fx, text),
					"R565 保真：%d %s 的下半「%s」在原文里找不到出处（原文：%s）"
					% [c.id, c.card_name, Rules.effect_text(fx), text])
		check(str(c.upper_effect.get("trigger", "")) in Rules.TRIGGERS,
				"R565：%d 上半时机必须在白名单" % c.id)
		check(not c.lower_effect.has("trigger"),
				"R567：%d %s 的下半不许带扳机（扳机只在上半）" % [c.id, c.card_name])
	check(rows >= 8, "R565：可组合候选至少 8 张（实际 %d）" % rows)
	# 用户点名的两张：黑暗领主 = 上半「使用后」空钩子 + 下半「回合结束时 5 费」；
	# 榴弹击手 = 上半「每次获得改造时」空钩子 + 下半「攻击距离+1」。
	var dark: CardData = repo.get_card(8021)
	check(dark.upper_effect.trigger == "use" and (dark.upper_effect.effects as Array).is_empty()
			and not dark.lower_effect.has("trigger")
			and str(dark.lower_effect.get("note", "")) == "在本回合结束时"
			and int(dark.lower_effect.effects[0].value) == 5,
			"R567：黑暗领主 = 上半 use（空）+ 下半 note + 5 费（无扳机）")
	var nade: CardData = repo.get_card(8057)
	check(nade.upper_effect.trigger == "upgraded" and (nade.upper_effect.effects as Array).is_empty()
			and nade.lower_effect.effects[0].type == "range",
			"R565：榴弹击手 = 上半 upgraded（空）+ 下半攻击距离")
	# 下半自带时机：build 后两个时机各自独立
	var base := CardData.new()
	base.card_name = "R565 探针"
	base.kind = "盟友"
	base.health = 10
	base.power = 1
	base.attack_range = 1
	var built := Rules.build(base, dark.upper_effect, dark.lower_effect)
	check(built != null and built.assemble.trigger == "use"
			and not built.assemble.has("lower_trigger")
			and (built.assemble.get("lower_effects", []) as Array).size() == 1,
			"R567：产物只记上半扳机 + 下半效果")
	check(built.effect_text == "使用时：在本回合结束时回复5点费用",
			"R567 产物文本 = 扳机 + note + 效果（实际「%s」）" % built.effect_text)
	var rt := CardData.from_dict(built.to_dict())
	check(str(rt.assemble.get("lower_note", "")) == "在本回合结束时"
			and (rt.assemble.get("lower_effects", []) as Array).size() == 1,
			"R567：下半效果 + note 随 to_dict/from_dict 走（复制一次不丢）")
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	var p := _probe_unit(eng, "")
	p.card.assemble = built.assemble.duplicate(true)
	eng.state.energy = 0
	eng._assemble_execute(p, eng._cell_of(p), "turn_end")
	check(eng.state.energy == 0, "R567：下半自己的原扳机（turn_end）不再生效")
	eng._assemble_execute(p, eng._cell_of(p), "use")
	check(eng.state.energy == 5, "R567：整张产物按**上半**扳机（use）结算一次 +5 费")
	# range 动作：攻击距离 +N
	var eng2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng2.ai_enabled = false
	var p2 := _probe_unit(eng2, "use")
	var r0: int = p2.card.attack_range
	p2.card.assemble = {"trigger": "use", "effects": [],
			"lower_effects": [{"type": "range", "value": 1}]}
	eng2._assemble_execute(p2, eng2._cell_of(p2), "use")
	check(p2.card.attack_range == r0 + 1 and p2.upgrade_range == 1, "R565：range 动作加攻程")
	# 专属印记：随复制通道走，且卡面 draw / draw_pick 都画
	var cm := CardData.new()
	cm.combine_mark = true
	check(CardData.from_dict(cm.to_dict()).combine_mark, "R565：combine_mark 随 to_dict/from_dict 走")
	check(not CardData.AFFIX_DEFS.has("组合"), "R565：「组合」不再是字段（不再渲染成 buff）")
	var cf := FileAccess.get_file_as_string("res://scripts/card_face.gd")
	check(cf.count("_draw_combine_mark(canvas, card, rect)") == 2
			and cf.find("func _draw_combine_mark") >= 0,
			"R565 源码锁：卡面 draw / draw_pick 都画组合印记")
	check(cf.find("combine_badge_center(rect, card.has_enchant())") >= 0,
			"R565 源码锁：印记与附魔标记同竖列、自动让位")
	var gsrc := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gsrc.find("result.combine_mark = true") >= 0 and gsrc.find("add_affix(\"组合\")") < 0,
			"R565 源码锁：产物只打专属印记，不挂「组合」字段")


func _test_r566_split_text() -> void:
	## R566 + R567：用户连续两轮实测 —— ①「混乱之影下半应该是抽一张牌，现在下半是完整的效果」；
	## ②「惊奇盒子下半应该是眩晕最近的敌人，但现在变成了完整效果」「火元素更是直接变成下半入场时对
	## 随机敌人造成 2 点伤害，跟原本效果不符」「机器鸟、活体栅栏作为下半也不对，给了完整效果」
	## 「下半不应该是完整效果，需要裁掉上半部分 —— 至少大部分卡扳机是在上半的，不应该也分发到下半」。
	##
	## 上一轮（R566）只做到「同时机不重复印扳机」，跨时机就补前缀 —— 那还是把扳机塞进了下半，
	## 而且产物卡面写 A 时机、引擎按 B 时机结算，显示与结算打架。本轮把它钉成**结构规则**：
	##   · 下半**没有扳机**（`lower_effect` 里出现 `trigger` → `valid_pool` 直接判废）；
	##   · 产物只有上半那张卡的扳机，下半效果挂在同一个扳机上一起结算；
	##   · 下半只出「效果」+ 可选 `note`（描述前缀，如黑暗领主「在本回合结束时」，不带冒号）。
	var repo := CardRepo.load_json()
	var rows := 0
	for c: CardData in repo.all_cards():
		if c.upper_effect.is_empty() and c.lower_effect.is_empty():
			continue
		rows += 1
		check(not c.lower_effect.has("trigger"),
				"R567：%d %s 的下半不许带扳机" % [c.id, c.card_name])
		var body := Rules.body_text(c.lower_effect)
		check(body != "", "R567：%d %s 下半文案不许为空" % [c.id, c.card_name])
		# R569：判据从「不许有任何冒号」收紧到**真正要防的那件事** —— 不许出现扳机式冒号。
		# 原写法把「获得改造：生命 +4」也一起判死了（那是效果内部的结构，不是时机），
		# 而用户真正否掉的是「下半重新印一遍时机」。
		var trig_prefix := ""
		for label: String in Rules.LABELS.values():
			if body.contains(label + "："):
				trig_prefix = label
				break
		check(trig_prefix == "",
				"R567：%d %s 下半文案里不许出现扳机式冒号 %s（实际「%s」）"
				% [c.id, c.card_name, trig_prefix, body])
		check(not body.ends_with("：") and not body.contains("时："),
				"R567：%d %s 下半不许以扳机名开头（实际「%s」）" % [c.id, c.card_name, body])
	check(rows >= 8, "R567：可组合候选至少 8 张（实际 %d）" % rows)
	# 用户逐条点名的四张：下半必须只剩效果本身
	var sp: CardData = repo.get_card(8067)
	check(Rules.body_text(sp.lower_effect) == "抽1张牌",
			"R567：分裂之影下半 =「抽1张牌」（实际「%s」）" % Rules.body_text(sp.lower_effect))
	var box: CardData = repo.get_card(9179)
	check(Rules.body_text(box.lower_effect) == "眩晕最近敌人",
			"R567：惊奇盒子下半 =「眩晕最近敌人」（实际「%s」）" % Rules.body_text(box.lower_effect))
	var bird: CardData = repo.get_card(8059)
	check(Rules.body_text(bird.lower_effect) == "抽1张牌",
			"R567：机器鸟下半 =「抽1张牌」（实际「%s」）" % Rules.body_text(bird.lower_effect))
	var fence: CardData = repo.get_card(8018)
	check(Rules.body_text(fence.lower_effect) == "抽1张牌",
			"R567：活体栅栏下半 =「抽1张牌」（实际「%s」）" % Rules.body_text(fence.lower_effect))
	# 火元素：R567 曾按「下半依赖『每清除 1 张』的前提」把它移出候选池；
	# R569 用户口径改判 —— 「如果后半是整体，那就全放到下句」，整条效果本来就是下半的。
	# 真正的判据不是「句子依赖别处」，而是「下半有没有兑现原卡效果」，见 `_test_r569_purge`。
	var fire: CardData = repo.get_card(9236)
	check(not fire.upper_effect.is_empty() and not fire.lower_effect.is_empty(),
			"R569：火元素回到候选池（上半入场钩子 + 下半整条效果）")
	# 黑暗领主：note 是描述前缀，不是扳机
	var dark: CardData = repo.get_card(8021)
	check(Rules.body_text(dark.lower_effect) == "在本回合结束时回复5点费用",
			"R567：黑暗领主下半 = note + 效果、无冒号（实际「%s」）"
			% Rules.body_text(dark.lower_effect))
	# 跨时机组合：产物只用上半扳机，下半的时机被丢弃
	var base := CardData.new()
	base.card_name = "R567 探针"
	base.kind = "工事"
	base.health = 5
	base.power = 0
	base.attack_range = 1
	var prod := Rules.build(base, dark.upper_effect, bird.lower_effect)
	check(prod != null and prod.assemble.trigger == "use"
			and (prod.assemble.get("lower_effects", []) as Array).size() == 1,
			"R567：产物扳机只来自上半（黑暗领主 use + 机器鸟下半）")
	check(prod != null and prod.effect_text == "使用时：抽1张牌",
			"R567：跨时机产物卡面只写上半扳机（实际「%s」）"
			% (prod.effect_text if prod != null else "null"))
	# valid_pool 结构锁：下半带扳机直接判废
	check(not Rules.valid_pool([dark.upper_effect],
			[{"trigger": "turn_end", "effects": [{"type": "draw", "value": 1}]}]),
			"R567：下半带扳机 → valid_pool 判废")
	check(Rules.valid_pool([dark.upper_effect], [bird.lower_effect]),
			"R567：下半无扳机 → valid_pool 通过")
	# 惊奇盒子：它是工事，本体不能移动，「无法移动」属于冗余描述
	check(box.effect_text == "被攻击时，使攻击者下回合眩晕（不能行动）。",
			"R567：惊奇盒子文本去掉「无法移动」（实际「%s」）" % box.effect_text)
	# 源码锁
	var ov := FileAccess.get_file_as_string("res://scripts/assemble_overlay.gd")
	check(ov.find("AssembleRules.body_text(") >= 0 and ov.find("AssembleRules.lower_text(") < 0,
			"R567 源码锁：组合页下半走 body_text，补扳机的 lower_text 已不存在")
	check(ov.count("AssembleRules.fragment_text(") == 1,
			"R567 源码锁：fragment_text 只用于上半（实际引用 %d 处）"
			% ov.count("AssembleRules.fragment_text("))
	var rs := FileAccess.get_file_as_string("res://scripts/assemble_rules.gd")
	check(rs.find("func lower_text") < 0, "R567 源码锁：lower_text 已删除")
	check(rs.find("if part.has(\"trigger\") or part.has(\"extra_affixes\"):") >= 0,
			"R567 源码锁：valid_pool 禁止下半带扳机")
	var gs := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gs.find("lower_trigger") < 0, "R567 源码锁：引擎不再有 lower_trigger 分支")


func _test_r568_passive() -> void:
	## R568：用户第五轮实测「本次测试很顺利。但是永续效果似乎被吞了。犀牛既然有受到伤害 -1 的
	## 持续效果，应该加入上半：受到伤害减少 1 点，但至少仍要受到 1 点。每回合结束时」。
	##
	## 根因：犀牛的减伤挂在 `traits: ["犀牛"]` 上，上半段只印了一个空钩子「回合结束时：」——
	## 那半句在 `effect_text` 里有、却没进上半。而且上半那张犀牛**不当承载体**时，trait 不会
	## 跟到产物上，只补文本就会变成「写着减伤、一点没减」。本轮把永续段做成上半的正式组成：
	##   · 显示：`fragment_text` 把永续句印在扳机**前面**（原卡语序）
	##   · 结算：`assemble.passive.reduce` 进 `_unit_damage_taken`，下限同犀牛「至少仍受 1 点」
	var repo := CardRepo.load_json()
	var rhino: CardData = repo.get_card(9016)
	# ① 保真锁：永续段文本必须逐字出现在原卡 effect_text 里（和上下半同一条纪律）
	var rows := 0
	for c: CardData in repo.all_cards():
		var pv0: Dictionary = c.upper_effect.get("passive", {})
		if pv0.is_empty():
			continue
		rows += 1
		var full := c.effect_text.replace("**", "")
		check(str(pv0.get("text", "")) != "" and full.contains(str(pv0.get("text", ""))),
			"R568 保真：%d %s 的永续段「%s」在原卡文本里找不到出处（原文：%s）"
			% [c.id, c.card_name, str(pv0.get("text", "")), full])
		check(str(pv0.get("source_trait", "")) == "" or c.traits.has(str(pv0.get("source_trait", ""))),
			"R568：%d 永续段的 source_trait 必须是本卡自带的 trait" % c.id)
	check(rows >= 1, "R568：至少 1 张卡带永续段（实际 %d）" % rows)
	# ② 犀牛：上半 = 永续句 + 扳机
	check(rhino.upper_effect.trigger == "turn_end", "R568：犀牛上半扳机仍是回合结束")
	check(Rules.fragment_text(rhino.upper_effect)
			== "受到伤害减少 1 点，但至少仍要受到 1 点。回合结束时：",
			"R568：犀牛上半框 = 永续句 + 扳机（实际「%s」）" % Rules.fragment_text(rhino.upper_effect))
	# ③ 产物文本：永续句在最前面（承载体是别的卡）
	var base := CardData.new()
	base.card_name = "R568 探针"
	base.kind = "盟友"
	base.health = 20
	base.power = 1
	base.attack_range = 1
	var bird: CardData = repo.get_card(8059)
	var prod := Rules.build(base, rhino.upper_effect, bird.lower_effect)
	check(prod != null and prod.effect_text
			== "受到伤害减少 1 点，但至少仍要受到 1 点。回合结束时：抽1张牌",
			"R568：产物文本 = 永续句 + 扳机 + 下半（实际「%s」）"
			% (prod.effect_text if prod != null else "null"))
	check(prod != null and int((prod.assemble.get("passive", {}) as Dictionary).get("reduce", 0)) == 1,
			"R568：承载体不是犀牛 → 永续减伤记进 assemble（要真减）")
	# ④ 结算：真的减 1，且「至少仍要受到 1 点」
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	var p := _probe_unit(eng, "turn_end", Vector2i(4, 0))
	p.card.assemble = prod.assemble.duplicate(true)
	check(eng._unit_damage_taken(p, 5) == 4, "R568：组合永续减伤 5 → 4")
	check(eng._unit_damage_taken(p, 1) == 1, "R568：永续减伤的底仍是至少 1 点")
	check(eng._unit_damage_taken(p, 0) == 0, "R568：0 伤害不会被减成负数")
	# ⑤ 承载体本身就是犀牛 → 不许叠成双减
	var prod2 := Rules.build(rhino, rhino.upper_effect, bird.lower_effect)
	check(prod2 != null and not (prod2.assemble.get("passive", {}) as Dictionary).has("reduce"),
			"R568：承载体已是犀牛 → passive.reduce 清零（trait 那条已经减过）")
	check(prod2 != null and str((prod2.assemble.get("passive", {}) as Dictionary).get("text", "")) != "",
			"R568：清零后永续文本仍保留（卡面照写）")
	var eng2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng2.ai_enabled = false
	var p2 := _probe_unit(eng2, "turn_end", Vector2i(5, 0))
	var tr: Array[String] = ["犀牛"]
	p2.card.traits = tr
	p2.card.assemble = prod2.assemble.duplicate(true)
	check(eng2._unit_damage_taken(p2, 5) == 4, "R568：犀牛载体 + 上半犀牛 → 只减 1（5 → 4，不是 3）")
	# ⑥ 复制通道：永续段不能一复制就丢
	var rt := CardData.from_dict(prod.to_dict())
	check(int((rt.assemble.get("passive", {}) as Dictionary).get("reduce", 0)) == 1,
			"R568：永续段随 to_dict/from_dict 走")
	# ⑦ 结构校验
	check(Rules.valid_pool([rhino.upper_effect], [bird.lower_effect]), "R568：合法永续段通过 valid_pool")
	check(not Rules.valid_pool([{"trigger": "turn_end", "passive": {"text": ""}, "effects": []}],
			[bird.lower_effect]), "R568：空文本永续段判废")
	check(not Rules.valid_pool([{"trigger": "turn_end",
			"passive": {"text": "x", "reduce": -1}, "effects": []}],
			[bird.lower_effect]), "R568：负减伤判废")
	check(not Rules.valid_pool([{"trigger": "turn_end", "passive": "文字", "effects": []}],
			[bird.lower_effect]), "R568：非字典永续段判废")
	# ⑧ 源码锁
	var gs := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gs.find("组合永续减伤") >= 0, "R568 源码锁：受击结算读 assemble 的永续减伤")
	var rs := FileAccess.get_file_as_string("res://scripts/assemble_rules.gd")
	check(rs.find("func valid_passive") >= 0 and rs.find("func passive_text") >= 0,
			"R568 源码锁：永续段的校验与取文本都在 AssembleRules")


func _probe_unit(eng: GameEngine, trigger: String, cell := Vector2i(3, 0), side := "self") -> Placement:
	var card := CardData.new()
	card.kind = "盟友"
	card.card_name = "时机探针"
	card.health = 100
	card.power = 1
	card.attack_range = 2
	card.assemble = {"trigger": trigger, "effects": [{"type":"buff", "value":1}]}
	return eng.state.place(card, cell, side)

func _test_extended_triggers() -> void:
	var lower := [{"effects":[{"type":"shield"}]}]
	for trigger in Rules.TRIGGERS:
		check(Rules.valid_pool([{"trigger":trigger,"effects":[]}], lower), "pure timing " + trigger)
	for trigger in ["card_played", "kill", "random_gained"]:
		check(not Rules.valid_pool([{"trigger":trigger}], lower), "excluded " + trigger)
		var blocked := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
		var p := _probe_unit(blocked, trigger)
		blocked._assemble_execute(p, Vector2i(3, 0), trigger)
		check(p.upgrade_atk == 0, "serialized forbidden trigger inert")
	for trigger in ["turn_start", "attack", "attacked", "damaged", "effect_played", "turn_first_play", "action_end", "after_draw"]:
		var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
		eng.ai_enabled = false
		var p := _probe_unit(eng, trigger)
		var foe := _probe_unit(eng, "", Vector2i(2, 0), "opponent")
		match trigger:
			"turn_start": eng._begin_turn("self")
			"attack": eng.attack(Vector2i(3, 0), Vector2i(2, 0))
			"attacked": eng.attack(Vector2i(2, 0), Vector2i(3, 0), "opponent")
			"damaged":
				p.first_hit_shield = true
				eng._hit_unit(p, 3)
				check(p.upgrade_atk == 0, "shield does not count as damage")
				eng._hit_unit(p, 3)
			"effect_played": eng._on_effect_card_played("self", CardData.new())
			"turn_first_play":
				eng._note_card_played("self", CardData.new())
				eng._note_card_played("self", CardData.new())
			"action_end": eng._tap(p)
			"after_draw":
				eng.state.deck.append(CardData.new())
				eng._draw_many(1)
		check(p.upgrade_atk == 1, "exactly once: " + trigger)
		check(foe.upgrade_atk == 0, "owner scope: " + trigger)
	var loop := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	var drawer := _probe_unit(loop, "after_draw")
	drawer.card.assemble.effects = [{"type":"draw", "value":1}]
	for i in 5:
		loop.state.deck.append(CardData.new())
	loop._draw_many(1)
	check(loop.state.hand.size() == 2, "draw loop bounded")
	loop._draw_many(1)
	check(loop.state.hand.size() == 4, "independent draw triggers again")

func _test_source_locks() -> void:
	# 源码锁：13 个时机都要挂在引擎的对应统一口上，防后续重构漏挂。
	# 第 3 项 = 最少出现次数（attack / damaged / after_draw 覆盖多条路径，故 ≥2）。
	var eng := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	var rules := FileAccess.get_file_as_string("res://scripts/assemble_rules.gd")
	var hooks: Array = [
		["use", "_assemble_execute(p, cell, \"use\")", 1],
		["enter", "_assemble_execute(p, _cell_of(p), \"enter\")", 1],
		["death", "_assemble_execute(p, cell, \"death\")", 1],
		["upgraded", "_assemble_execute(p, _cell_of(p), \"upgraded\")", 1],
		["turn_end", "_assemble_tick(current_side, \"turn_end\")", 1],
		["turn_start", "_assemble_tick(side, \"turn_start\")", 1],
		["attack", "_assemble_execute(attacker, _cell_of(attacker), \"attack\")", 2],
		["attacked", "_assemble_execute(defender, dst, \"attacked\")", 1],
		["damaged", "_assemble_execute(p, _cell_of(p), \"damaged\")", 2],
		["effect_played", "_assemble_tick(side, \"effect_played\")", 1],
		["turn_first_play", "_assemble_tick(side, \"turn_first_play\")", 1],
		["after_draw", "_assemble_tick(SIDE_SELF, \"after_draw\")", 2],
		["action_end", "_assemble_execute(p, _cell_of(p), \"action_end\")", 1],
	]
	for h in hooks:
		check(eng.count(str(h[1])) >= int(h[2]), "源码锁：挂接点 " + str(h[0]))
	# 黑名单（card_played/kill）/ 暂缓（random_gained）常量声明存在；
	# 执行层由 TRIGGERS 排除（三者不在 TRIGGERS），行为测试已覆盖 inert。
	check(rules.count("BLACKLIST") >= 1 and rules.count("DEFERRED") >= 1, "源码锁：黑名单/暂缓常量")
	check(rules.count("\"card_played\"") >= 1 and rules.count("\"kill\"") >= 1
			and rules.count("\"random_gained\"") >= 1, "源码锁：黑名单三时机声明")
	# 防重入标记 + 抽牌双口（after_draw 经 _draw_many / _assemble_draw_one / _assemble_opponent_draw 覆盖）
	check(eng.count("_assemble_active") >= 3, "源码锁：防重入标记")
	check(eng.count("_assemble_opponent_draw") >= 3 and eng.count("_assemble_draw_one") >= 3,
			"源码锁：抽牌双口覆盖")

func _test_new_actions() -> void:
	# energy：回复费用
	var e1 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e1.ai_enabled = false
	var p1 := _probe_unit(e1, "use")
	e1.state.energy = 0
	p1.card.assemble = {"trigger":"use", "effects":[{"type":"energy","value":3}]}
	e1._assemble_execute(p1, Vector2i(3, 0), "use")
	check(e1.state.energy == 3, "energy gain")
	# upgrade：永久改造 +N力+N生，记层
	var e2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e2.ai_enabled = false
	var p2 := _probe_unit(e2, "use")
	p2.upgrade_stacks = 0
	var hp0: int = p2.health
	p2.card.assemble = {"trigger":"use", "effects":[{"type":"upgrade","value":2}]}
	e2._assemble_execute(p2, Vector2i(3, 0), "use")
	check(p2.upgrade_atk == 2 and p2.upgrade_hp == 2 and p2.upgrade_stacks == 1, "upgrade permanent +stack")
	check(p2.health == hp0 + 2, "upgrade hp")
	# summon：召唤 2 个骷髅（9029）
	var e3 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e3.ai_enabled = false
	var p3 := _probe_unit(e3, "use")
	p3.card.assemble = {"trigger":"use", "effects":[{"type":"summon","value":9029,"count":2}]}
	e3._assemble_execute(p3, Vector2i(3, 0), "use")
	var tokens := 0
	for c: Vector2i in e3.state.board:
		if e3.state.board[c].card.id == 9029:
			tokens += 1
	check(tokens == 2, "summon two tokens")
	# damage random：随机打一个敌人
	var e4 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e4.ai_enabled = false
	var p4 := _probe_unit(e4, "use")
	var foe := _probe_unit(e4, "", Vector2i(2, 0), "opponent")
	var foe2 := _probe_unit(e4, "", Vector2i(2, 1), "opponent")
	foe.health = 50
	foe2.health = 50
	p4.card.assemble = {"trigger":"use", "effects":[{"type":"damage","value":5,"target":"random"}]}
	e4._assemble_execute(p4, Vector2i(3, 0), "use")
	check(foe.health + foe2.health == 95, "damage random hits exactly one")
	# knockback：击退最近敌人 2 格
	var e5 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e5.ai_enabled = false
	var p5 := _probe_unit(e5, "use")
	var kb_foe := _probe_unit(e5, "", Vector2i(2, 0), "opponent")
	p5.card.assemble = {"trigger":"use", "effects":[{"type":"knockback","value":2}]}
	e5._assemble_execute(p5, Vector2i(3, 0), "use")
	check(e5.state.unit_at(Vector2i(0, 0)) == kb_foe, "knockback pushed 2")
	# freeze：冰封最近敌人
	var e6 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e6.ai_enabled = false
	var p6 := _probe_unit(e6, "use")
	var fr_foe := _probe_unit(e6, "", Vector2i(2, 0), "opponent")
	p6.card.assemble = {"trigger":"use", "effects":[{"type":"freeze"}]}
	e6._assemble_execute(p6, Vector2i(3, 0), "use")
	check(fr_foe.frozen, "freeze nearest")
	# stun：眩晕最近敌人
	var e7 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	e7.ai_enabled = false
	var p7 := _probe_unit(e7, "use")
	var st_foe := _probe_unit(e7, "", Vector2i(2, 0), "opponent")
	p7.card.assemble = {"trigger":"use", "effects":[{"type":"stun"}]}
	e7._assemble_execute(p7, Vector2i(3, 0), "use")
	check(st_foe.stun_left > 0, "stun nearest")

func _test_retired_assemble() -> void:
	# R561：用户口径「拼装是炉石术语，本游戏叫组合」——拼装作为独立入口整套下线：
	# 三张主体卡（8083 拼装原型 / 8087 树灵雏形 / 8088 影偶）+ 半句池 + 三步选卡 API 全删，
	# 只留组合（真卡三选）+ 结算层。这里锁死「不许复活」。
	var repo := CardRepo.load_json()
	for id in [8083, 8087, 8088]:
		check(repo.get_card(id) == null, "R561：拼装主体卡 %d 已移除" % id)
	var raw := FileAccess.get_file_as_string("res://cards.json")
	check(not raw.contains("拼装"), "R561：cards.json 不含「拼装」字样")
	check(not raw.contains("assemble_pool"), "R561：cards.json 不含 assemble_pool 字段")
	check(not FileAccess.file_exists("res://assemble_pools.json"), "R561：半句池文件已删除")
	var src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	for api in ["func assemble_begin", "func assemble_choose", "func assemble_choices",
			"func assemble_cancel", "func load_assemble_pools", "func register_assemble_pool"]:
		check(not src.contains(api), "R561：引擎已无 " + api)
	check(not src.contains("assemble_pending") and not src.contains("assemble_pools"),
			"R561：引擎已无拼装 pending / 池状态")
	check(src.contains("assemble_combo_commit") and src.contains("_assemble_execute"),
			"R561：组合入口与结算层保留")
	check(not CardData.AFFIX_DEFS.has("组合"), "R565：「组合」字段已下线（改专属印记）")

func _test_combo() -> void:
	# R559/R561 组合：从全角色盟友·工事卡池抽 6 张，拖 3 张分别定属性/上半/下半，结果带「组合」印记。
	var repo := CardRepo.load_json()
	var teach: CardData = repo.get_card(8084)
	check(teach != null and teach.kind == "技能" and teach.card_class == "森林精魄"
			and teach.cost == 1 and teach.rarity == 1,
			"R559 传授：8084 是森林精魄 1 费稀有技能")
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	# 数据层：可组合候选 = 同时带 upper/lower 的玩家盟友/工事卡
	var cand: Array = eng._combo_candidate_cards()
	check(cand.size() >= 16, "R569 组合：可组合盟友/工事候选 %d 张（期望 ≥16）" % cand.size())
	# 候选必须覆盖三职业盟友 + 工事，且全是盟友/工事（不允许其他 kind 混入）
	var has_fort := false
	var has_rogue := false
	var has_mech := false
	var kinds_ok := true
	for c: CardData in cand:
		if c.card_class == "暗影刺客":
			has_rogue = true
		elif c.card_class == "机械之心":
			has_mech = true
		if c.kind == "工事":
			has_fort = true
		if c.kind != "盟友" and c.kind != "工事":
			kinds_ok = false
	check(has_fort and has_rogue and has_mech and kinds_ok,
			"R559 组合：候选覆盖暗影/机械盟友 + 工事，且全为盟友/工事")
	# 触发传授
	eng.state.energy = 10
	var ret := eng._teach_spell(GameEngine.SIDE_SELF)
	check(eng.assemble_combo_pending and ret == "进入组合", "R559 传授：进入组合 pending")
	var six: Array = eng.assemble_combo_cards()
	check(six.size() == 6, "R559 传授：抽 6 张待选（实际 %d）" % six.size())
	# R561：组合 pending 期间推进回合被挡（守卫 _assemble_busy）
	var turn := eng.current_side
	eng.end_turn()
	check(eng.current_side == turn, "R561 组合：pending 期间结束回合被挡")
	# 三槽未满时无预览
	check(eng.assemble_combo_preview() == null, "R559 组合：三槽未满无预览")
	# 填三槽
	eng.assemble_combo_set_slot("attr", 0)
	eng.assemble_combo_set_slot("upper", 1)
	eng.assemble_combo_set_slot("lower", 2)
	var result: CardData = eng.assemble_combo_preview()
	check(result != null, "R559 组合：三槽填满有预览")
	if result != null:
		check(result.combine_mark and not result.has_affix("组合"),
				"R565 组合：结果带专属印记，且不再挂「组合」字段")
		var attr_card: CardData = six[0]
		check(result.power == attr_card.power and result.health == attr_card.health
				and result.cost == attr_card.cost,
				"R559 组合：属性值取自属性卡（%d/%d/%d 费）" % [result.power, result.health, result.cost])
		# R561 口径：第一张卡就是承载体 —— 卡名 / 卡图（按 id 取图）/ 稀有度全沿用，只加「组合」印记
		check(result.id == attr_card.id and result.card_name == attr_card.card_name
				and result.rarity == attr_card.rarity,
				"R561 组合：卡名/卡图（同 id）/稀有度沿用属性卡")
		check(not result.assemble.is_empty(), "R559 组合：结果带 assemble 效果")
	# commit
	var before: int = eng.state.hand.size()
	check(eng.assemble_combo_commit(), "R559 组合：commit 成功")
	check(eng.state.hand.size() == before + 1 and not eng.assemble_combo_pending,
			"R559 组合：commit 后手牌 +1 且 pending 清空")
	# 再触发一次 → cancel
	eng._teach_spell(GameEngine.SIDE_SELF)
	check(eng.assemble_combo_pending, "R559 组合：再次进入组合")
	eng.assemble_combo_cancel()
	check(not eng.assemble_combo_pending, "R559 组合：cancel 清空 pending")
	# R560：传授卡 8085 影缚（暗影刺客）/ 8086 重构（机械之心），走 TEACH_IDS 集合触发
	var teach2: CardData = repo.get_card(8085)
	var teach3: CardData = repo.get_card(8086)
	check(teach2 != null and teach2.card_class == "暗影刺客" and teach2.kind == "技能" and teach2.cost == 1,
			"R560 传授：8085 影缚是暗影刺客 1 费技能")
	check(teach3 != null and teach3.card_class == "机械之心" and teach3.kind == "技能" and teach3.cost == 1,
			"R560 传授：8086 重构是机械之心 1 费技能")
	check(GameEngine.TEACH_IDS.has(8084) and GameEngine.TEACH_IDS.has(8085) and GameEngine.TEACH_IDS.has(8086),
			"R560 传授：TEACH_IDS 集合含 8084/8085/8086")
	# 源码锁：传授入口 / 组合结算 / 守卫挂接
	var src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(src.count("TEACH_IDS") >= 1 and src.count("_teach_spell") >= 2
			and src.count("assemble_combo_commit") >= 1 and src.count("_assemble_busy") >= 4,
			"R559 源码锁：传授入口 / 组合结算 / 守卫挂接")
	# ── R562 交互回归锁（用户实测报的两个 bug，都是「看起来卡死」级别）──────────
	var ov := FileAccess.get_file_as_string("res://scripts/assemble_overlay.gd")
	var bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	# ① 右键不许再直接取消：在 `_gui_input` 里把自己 hide 掉，会让鼠标 over 状态悬在
	#    一个已隐藏控件上，之后所有点击全部落空（玩家感知＝卡死）。右键只提示，
	#    「取消组合」按钮才是唯一出口。
	var rb := ov.find("MOUSE_BUTTON_RIGHT and mb.pressed:")
	var rb_seg := ov.substr(rb, 420) if rb >= 0 else ""
	check(rb >= 0 and rb_seg.find("_show_tip(") >= 0 and rb_seg.find("cancelled.emit()") < 0,
			"R562 源码锁：右键只提示，不许直接取消")
	# ② 关页一律 `close.call_deferred()`（同一次输入回调里 hide 会卡住鼠标派发）。
	#    `_sync_pick` 那处是 `_process` 里关的，允许同步。
	var f1 := bs.find("func _on_assemble_combo_confirmed")
	var f2 := bs.find("func _on_assemble_combo_cancelled")
	var f3 := bs.find("func _abort_empty_pick")
	var seg1 := bs.substr(f1, f2 - f1) if f1 >= 0 and f2 > f1 else ""
	var seg2 := bs.substr(f2, f3 - f2) if f2 >= 0 and f3 > f2 else ""
	check(seg1.find("close.call_deferred()") >= 0 and seg1.find("_assemble_overlay.close()") < 0,
			"R562 源码锁：确认组合后关页要延迟到帧末")
	check(seg2.find("close.call_deferred()") >= 0 and seg2.find("_assemble_overlay.close()") < 0,
			"R562 源码锁：取消组合后关页要延迟到帧末")
	# ③ 上/下半效果框各自独立判断，不许再套一层 `_all_filled()`
	#    （原来拖进上半后框里空空，玩家以为没吃进去）
	check(ov.count("if i == 0 and _slot_upper >= 0:") == 1
			and ov.count("elif i == 1 and _slot_lower >= 0:") == 1,
			"R562 源码锁：上/下半效果框各自独立显示")
	# ④ 全屏模态页要压在所有战斗 UI 之上（tscn 里的 hp_strip 会盖掉底部提示行）
	check(ov.count("z_index = 100") == 1, "R562：组合页 z_index 顶层化")

	# ── R564 撤回与详情（用户口径：放进去的卡要能拿下来 / 左边不该还留着 / 要看得到详情）──
	# ① 引擎：`set_slot(x, -1)` = 清空该槽（原来负数一律被拒 → 卡放进去就再也拿不出来）
	eng._teach_spell(GameEngine.SIDE_SELF)
	check(eng.assemble_combo_pending, "R564：进入组合")
	eng.assemble_combo_set_slot("attr", 0)
	eng.assemble_combo_set_slot("upper", 1)
	eng.assemble_combo_set_slot("lower", 2)
	check(eng.assemble_combo_preview() != null, "R564：三槽填满可预览")
	eng.assemble_combo_set_slot("upper", -1)
	check(eng.assemble_combo_preview() == null, "R564：清空上半槽后预览消失（可撤回）")
	eng.assemble_combo_set_slot("upper", 99)
	check(eng.assemble_combo_preview() == null, "R564：越界下标不会写进槽位")
	eng.assemble_combo_set_slot("upper", 1)
	check(eng.assemble_combo_preview() != null, "R564：重新拖回上半槽后预览恢复")
	eng.assemble_combo_cancel()
	# ② 源码锁：组合页可撤回 + 左栏去重 + 详情入口
	check(ov.count("_slot_of_index") >= 3, "R564 源码锁：同一张卡只占一个槽（_slot_of_index）")
	check(ov.count("_draw_left_gap") >= 2, "R564 源码锁：已放入的卡在左栏只留空位（_draw_left_gap）")
	check(ov.count("_slot_close_rect") >= 3, "R564 源码锁：槽内卡有 ✕ 撤回角标")
	check(ov.find("_left_zone().has_point(pos)") >= 0, "R564 源码锁：拖回左栏 = 撤回")
	check(ov.find("_set_slot(_drag_slot, -1)") >= 0, "R564 源码锁：撤回走 set_slot(-1)")
	check(ov.find("_open_detail_card") >= 0 and ov.find("CardDetailOverlay.new()") >= 0,
			"R564 源码锁：组合页接了卡牌详情")
	# ③ 源码锁：选卡页 / 弃牌区浏览也能看详情（同一组件）
	var pov := FileAccess.get_file_as_string("res://scripts/pick_overlay.gd")
	check(pov.find("CardDetailOverlay.new()") >= 0 and pov.find("_desc_detail_rect") >= 0
			and pov.find("_desc_card()") >= 0,
			"R564 源码锁：选卡页描述条带「详情」入口")
	# ④ 源码锁：详情层自己关的时候也必须帧末 hide（R562 的坑，别在新组件里重犯）
	var dov := FileAccess.get_file_as_string("res://scripts/card_detail_overlay.gd")
	check(dov != "" and dov.find("close.call_deferred()") >= 0 and dov.find("z_index = 200") >= 0,
			"R564 源码锁：详情层帧末关闭 + 压在组合页之上")

func _test_r569_purge() -> void:
	## R569：用户口径「火元素也没道理退出，如果后半是整体，那就全放到下句。
	## 上半：入场时，下半：清除你的抽牌堆、手卡、弃牌区中的所有诅咒；每清除 1 张，
	## 对随机一个敌人造成 2 点伤害」。
	##
	## 火元素在 R567 被我误判成「下半依赖前置条件」而移出池子 —— 其实是**整条效果**都该放下半，
	## 上半只留钩子。这一节锁三件事：① 它回到池子且形态正确；② 新动作 `purge_curse` 的文本
	## 逐字等于原卡效果；③ 结算真的清三个区域、每张打 2 点。
	var repo := CardRepo.load_json()
	var fire: CardData = repo.get_card(9236)
	check(fire != null and not fire.upper_effect.is_empty() and not fire.lower_effect.is_empty(),
			"R569：火元素 9236 必须回到候选池（上半钩子 + 下半整条效果）")
	if fire == null:
		return
	check(str(fire.upper_effect.get("trigger", "")) == "enter"
			and (fire.upper_effect.get("effects", []) as Array).is_empty(),
			"R569：火元素上半 = 纯钩子「入场时」")
	check(Rules.body_text(fire.lower_effect)
			== "清除你的抽牌堆、手卡、弃牌区中的所有诅咒；每清除 1 张，对随机一个敌人造成 2 点伤害",
			"R569：火元素下半逐字 = 原卡效果（实际「%s」）" % Rules.body_text(fire.lower_effect))
	# 产物文本：扳机只印一次，整条效果跟在后面
	var base := CardData.new()
	base.card_name = "R569 探针"
	base.kind = "盟友"
	base.health = 20
	base.power = 1
	base.attack_range = 1
	var prod := Rules.build(base, fire.upper_effect, fire.lower_effect)
	check(prod != null and prod.effect_text.count("入场时") == 1
			and prod.effect_text.begins_with("入场时：清除你的抽牌堆"),
			"R569：产物 = 一个「入场时：」+ 整条效果（实际「%s」）"
			% (prod.effect_text if prod != null else "null"))
	# 结算：三个区域的诅咒全清，每清 1 张 → 随机敌人 2 伤
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	var curse_proto: CardData = null
	for c: CardData in repo.all_cards():
		if c.is_curse():
			curse_proto = c
			break
	check(curse_proto != null, "R569：卡池里要有至少一张诅咒卡做探针")
	if curse_proto != null:
		for _i in 3:
			eng.state.deck.append(CardData.from_dict(curse_proto.to_dict()))
		eng.state.hand.append(CardData.from_dict(curse_proto.to_dict()))
		eng.state.discard.append(CardData.from_dict(curse_proto.to_dict()))
	var foe_card := CardData.new()
	foe_card.kind = "盟友"
	foe_card.card_name = "R569 靶子"
	foe_card.health = 40
	foe_card.power = 0
	var foe := eng.state.place(foe_card, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var p := _probe_unit(eng, "enter", Vector2i(4, 0))
	p.card.assemble = prod.assemble.duplicate(true)
	eng._assemble_execute(p, Vector2i(4, 0), "enter")
	check(eng.state.deck.is_empty() and eng.state.discard.is_empty(),
			"R569：抽牌堆 / 弃牌区的诅咒全清（deck %d / discard %d）"
			% [eng.state.deck.size(), eng.state.discard.size()])
	check(foe != null and foe.health == 30,
			"R569：清 5 张诅咒 → 5 次 2 伤（40 → 30，实际 %d）"
			% (foe.health if foe != null else -1))
	# 源码锁：两处走同一个实现口
	var gs := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gs.find("func _purge_self_curses") >= 0 and gs.find("_fire_primal_enter") >= 0
			and gs.count("_purge_self_curses(") >= 3,
			"R569 源码锁：诅咒清算只有 `_purge_self_curses` 一个实现口（火元素入场 + 组合动作共用）")


func _test_r569_actions() -> void:
	## R569：用户口径「继续找所有能做的填入，上半需要至少有一个钩子，下半需要至少有一个可执行效果」。
	## 本轮新增三个**已有引擎实现**的动作（各自都有唯一实现口，与母卡共用）：
	##   · `add_random_effect`（猫头鹰 9073，`from = "deck"` 时从牌库取）
	##   · `hand_discount`（雪豹 8081）
	##   · `hand_upgrade`（改装者 8076）
	var repo := CardRepo.load_json()
	# ① 从牌库取随机效果卡
	var owl: CardData = repo.get_card(9073)
	check(owl != null and not owl.lower_effect.is_empty(), "R569：猫头鹰 9073 必须进候选池")
	var effect_proto: CardData = null
	for c: CardData in repo.all_cards():
		if c.is_effect() and c.group == "player":
			effect_proto = c
			break
	check(effect_proto != null, "R569：卡池里要有至少一张效果卡做探针")
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	if effect_proto != null:
		eng.state.deck.append(CardData.from_dict(effect_proto.to_dict()))
	var p := _probe_unit(eng, "use", Vector2i(3, 0))
	p.card.assemble = {"trigger": "use", "effects": owl.lower_effect.get("effects", []).duplicate(true)}
	eng._assemble_execute(p, Vector2i(3, 0), "use")
	check(eng.state.deck.is_empty() and eng.state.hand.size() == 1,
			"R569：`from = deck` → 牌库 -1、手牌 +1（deck %d / hand %d）"
			% [eng.state.deck.size(), eng.state.hand.size()])
	# ② 随机手牌本回合费用 -1
	var eng2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng2.ai_enabled = false
	var cheap := CardData.new()
	cheap.kind = "盟友"
	cheap.card_name = "减费靶"
	cheap.cost = 3
	cheap.health = 5
	eng2.state.hand.append(cheap)
	var p2 := _probe_unit(eng2, "attack", Vector2i(3, 0))
	p2.card.assemble = {"trigger": "attack", "effects": [{"type": "hand_discount", "value": 1}]}
	eng2._assemble_execute(p2, Vector2i(3, 0), "attack")
	check(int(eng2.state.hand_cost_turn.get(cheap, 0)) == 1,
			"R569：手牌本回合费用 -1（实际 %d）" % int(eng2.state.hand_cost_turn.get(cheap, 0)))
	# ③ 手牌盟友改造：生命 +4 + 一层改造
	var eng3 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng3.ai_enabled = false
	var ally := CardData.new()
	ally.kind = "盟友"
	ally.card_name = "改造靶"
	ally.cost = 1
	ally.health = 5
	ally.power = 1
	eng3.state.hand.append(ally)
	var p3 := _probe_unit(eng3, "enter", Vector2i(3, 0))
	p3.card.assemble = {"trigger": "enter", "effects": [{"type": "hand_upgrade", "value": 4}]}
	eng3._assemble_execute(p3, Vector2i(3, 0), "enter")
	check(eng3.state.hand[0].health == 9 and eng3.state.hand[0].upgrade_stacks == 1,
			"R569：手牌盟友改造 +4 生命 / +1 层（实际 %d 血 / %d 层）"
			% [eng3.state.hand[0].health, eng3.state.hand[0].upgrade_stacks])
	# ④ 数值校验：0 张 / 减 0 费 / 改造 +0 都是空动作，判废
	check(Rules.valid_effect({"type": "purge_curse", "value": 2}), "R569：purge_curse 合法")
	check(not Rules.valid_effect({"type": "add_random_effect", "value": 0}),
			"R569：加 0 张效果卡判废")
	check(not Rules.valid_effect({"type": "hand_discount", "value": 0}), "R569：减 0 费判废")
	check(not Rules.valid_effect({"type": "hand_upgrade", "value": 0}), "R569：改造 +0 判废")
	# ⑤ 源码锁：三个动作各有唯一实现口，母卡与组合共用
	var gs := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gs.find("func _discount_random_hand") >= 0 and gs.count("_discount_random_hand(") >= 3,
			"R569 源码锁：手牌减费只有 `_discount_random_hand` 一个实现口（雪豹 + 组合）")
	check(gs.find("func _upgrade_hand_allies") >= 0 and gs.count("_upgrade_hand_allies(") >= 3,
			"R569 源码锁：手牌改造只有 `_upgrade_hand_allies` 一个实现口（改装者 + 组合）")


func _test_r569_pool_forms() -> void:
	## R569：用户口径「上半需要至少有一个钩子，下半需要至少有一个可执行效果」。
	## 这是**候选池的形状规则**，不是某一两张卡的事 —— 全池逐张锁，以后加卡自动受约束。
	## 同时锁「无法移动」已从全卡池清除（用户口径「无法移动全部删除，空白文本也无所谓」）。
	var repo := CardRepo.load_json()
	var pool: Array[CardData] = []
	for c: CardData in repo.all_cards():
		if (c.kind == "盟友" or c.kind == "工事") and c.group == "player" \
				and not c.upper_effect.is_empty() and not c.lower_effect.is_empty():
			pool.append(c)
	check(pool.size() >= 24, "R570：候选池至少 24 张（实际 %d）" % pool.size())
	for c: CardData in pool:
		check(Rules.TRIGGERS.has(str(c.upper_effect.get("trigger", ""))),
				"R569：%d %s 上半必须有合法钩子" % [c.id, c.card_name])
		check((c.upper_effect.get("effects", []) as Array).is_empty(),
				"R569：%d %s 上半不承载效果（整条效果放下半）" % [c.id, c.card_name])
		check(not c.lower_effect.has("trigger"),
				"R569：%d %s 下半不许带扳机" % [c.id, c.card_name])
		var lf: Array = c.lower_effect.get("effects", [])
		check(lf.size() >= 1, "R569：%d %s 下半至少一个可执行效果" % [c.id, c.card_name])
		for fx: Variant in lf:
			check(Rules.valid_effect(fx), "R569：%d %s 的动作 %s 不可执行"
					% [c.id, c.card_name, str(fx)])
			if fx is Dictionary:
				check(_fx_in_text(fx, c.effect_text.replace("**", "")),
						"R569 保真：%d %s 的动作 %s 在原卡文本里找不到出处（原文：%s）"
						% [c.id, c.card_name, str(fx), c.effect_text])
	# 全卡池：「无法移动」清零（用户口径「空白文本也无所谓，没有效果就应该是空白」）
	for c: CardData in repo.all_cards():
		check(not c.effect_text.contains("无法移动"),
				"R569：「无法移动」应全部删除，但 %d %s 还有：%s"
				% [c.id, c.card_name, c.effect_text])
	# 空文本是真空白（木栅栏 / 箭塔 改成没有效果就该是空串，不是只剩一个句号）
	for cid: int in [8001, 9019]:
		var c: CardData = repo.get_card(cid)
		check(c != null and c.effect_text.strip_edges() == "",
				"R569：%d 没有效果 → 文本必须为空（实际「%s」）"
				% [cid, c.effect_text if c != null else "null"])
	# 源码锁：超框缩字号（用户口径「文字应该增加自适应大小，超框需要缩小」）
	var cf := FileAccess.get_file_as_string("res://scripts/card_face.gd")
	check(cf.find("func fit_text_lines") >= 0, "R569 源码锁：卡面有「超框缩字号」公共口")
	check(cf.find("fit_text_lines(font, eff") >= 0, "R569 源码锁：卡面效果文字走自适应")
	var ao := FileAccess.get_file_as_string("res://scripts/assemble_overlay.gd")
	check(ao.find("CardFace.fit_text_lines") >= 0,
			"R569 源码锁：组合页上/下效果框也走自适应（犀牛那三行不再顶出框底）")

func _test_r570_actions() -> void:
	## R570：用户口径「排查一下还有其他可以做的卡吗」。
	## 判据（R569 定下的池形状 + R565 的保真锁）：
	##   · 上半只有钩子；下半至少一条可执行效果；每条动作的文字特征能在原卡 effect_text 找到。
	##   · **整条效果**必须能完整表达 —— 只做半句就算走形（所以老虎「弃牌区每盟友 -1 费」那句
	##     表达不了 → 整张先不进池；影魔后半句是动态计数 → 同理）。
	## 本轮进池 7 张，六个新动作各抽唯一实现口与母卡共用。
	var repo := CardRepo.load_json()
	# ① buff_per_ally（猎犬 9040）：场上 2 个**其他**盟友 → +2×2 力量；自己不算、工事不算
	var eng := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng.ai_enabled = false
	for i in 2:
		var ally := CardData.new()
		ally.kind = "盟友"
		ally.card_name = "陪衬%d" % i
		ally.health = 5
		ally.power = 1
		eng.state.place(ally, Vector2i(i + 1, 0), GameEngine.SIDE_SELF)
	var fort := CardData.new()
	fort.kind = "工事"
	fort.card_name = "陪衬工事"
	fort.health = 5
	eng.state.place(fort, Vector2i(3, 0), GameEngine.SIDE_SELF)
	var p := _probe_unit(eng, "use", Vector2i(3, 0))
	p.card.assemble = {"trigger": "use", "effects": [{"type": "buff_per_ally", "value": 2}]}
	var before := p.effective_power()
	eng._assemble_execute(p, Vector2i(3, 0), "use")
	check(p.effective_power() == before + 4,
			"R570：场上 2 个其他盟友 → +4 力量（自己/工事不算；实际 %d → %d）"
			% [before, p.effective_power()])

	# ② buff_per_energy（地狱猫 8019 / 鲜血堡垒 8020）：剩余 3 费 → +3 力 +6 血
	var eng2 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng2.ai_enabled = false
	var p2 := _probe_unit(eng2, "turn_end", Vector2i(3, 0))
	p2.card.assemble = {"trigger": "turn_end",
			"effects": [{"type": "buff_per_energy", "atk": 1, "hp": 2}]}
	eng2.state.energy = 3
	var hp2 := p2.health
	var atk2 := p2.end_atk
	eng2._assemble_execute(p2, Vector2i(3, 0), "turn_end")
	check(p2.end_atk == atk2 + 3 and p2.health == hp2 + 6,
			"R570：剩余 3 费 → +3 力 / +6 血（实际 +%d 力 / +%d 血）"
			% [p2.end_atk - atk2, p2.health - hp2])
	# 剩余费用 0 → 不结算（不刷 +0）
	var eng2b := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng2b.ai_enabled = false
	var p2b := _probe_unit(eng2b, "turn_end", Vector2i(3, 0))
	p2b.card.assemble = {"trigger": "turn_end",
			"effects": [{"type": "buff_per_energy", "atk": 1, "hp": 2}]}
	eng2b.state.energy = 0
	var hp2b := p2b.health
	eng2b._assemble_execute(p2b, Vector2i(3, 0), "turn_end")
	check(p2b.health == hp2b and p2b.end_atk == 0, "R570：剩余费用 0 时 `buff_per_energy` 不结算")

	# ③ heal_per_energy（夜蚀 8062）：剩余 5 费、只差 2 血 → 回 2（不超过上限）
	var eng3 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng3.ai_enabled = false
	var p3 := _probe_unit(eng3, "turn_end", Vector2i(3, 0))
	p3.card.assemble = {"trigger": "turn_end", "effects": [{"type": "heal_per_energy", "value": 1}]}
	p3.health = p3.card.health - 2
	eng3.state.energy = 5
	eng3._assemble_execute(p3, Vector2i(3, 0), "turn_end")
	check(p3.health == p3.card.health,
			"R570：剩余 5 费、只差 2 血 → 回满且不越界（实际 %d / %d）" % [p3.health, p3.card.health])

	# ④ draw_random_skill（赤狐 9034）：牌库 -1、手牌 +1，且只有那张本回合 -1 费
	var skill: CardData = null
	for c: CardData in repo.all_cards():
		if c.kind == "技能" and c.group == "player":
			skill = c
			break
	check(skill != null, "R570：卡池里要有至少一张玩家技能牌做探针")
	var eng4 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng4.ai_enabled = false
	if skill != null:
		eng4.state.deck.append(CardData.from_dict(skill.to_dict()))
	var p4 := _probe_unit(eng4, "use", Vector2i(3, 0))
	p4.card.assemble = {"trigger": "use", "effects": [{"type": "draw_random_skill", "value": 1}]}
	eng4._assemble_execute(p4, Vector2i(3, 0), "use")
	check(eng4.state.deck.is_empty() and eng4.state.hand.size() == 1,
			"R570：从卡组取技能牌 → 牌库 -1 / 手牌 +1（deck %d / hand %d）"
			% [eng4.state.deck.size(), eng4.state.hand.size()])
	if eng4.state.hand.size() == 1:
		var got: CardData = eng4.state.hand[0]
		check(int(eng4.state.turn_card_discount.get(got, 0)) == 1,
				"R570：取到的那张本回合 -1 费（实际 %d）"
				% int(eng4.state.turn_card_discount.get(got, 0)))

	# ⑤ hand_cost_raise（契约签订者 8024）：回复 4 费 + 手卡全体涨价 4
	var eng5 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng5.ai_enabled = false
	var p5 := _probe_unit(eng5, "enter", Vector2i(3, 0))
	p5.card.assemble = {"trigger": "enter", "effects": [
			{"type": "energy", "value": 4}, {"type": "hand_cost_raise", "value": 4}]}
	eng5.state.energy = 0
	eng5._assemble_execute(p5, Vector2i(3, 0), "enter")
	check(eng5.state.energy == 4 and eng5.state.turn_card_raise == 4,
			"R570：契约 → 费用 +4 / 手卡涨价 +4（实际 %d / %d）"
			% [eng5.state.energy, eng5.state.turn_card_raise])
	# 涨价是「赋同一个值」不累加：再来一次仍是 4，不是 8
	eng5._assemble_execute(p5, Vector2i(3, 0), "enter")
	check(eng5.state.turn_card_raise == 4,
			"R570：涨价不叠加（仍应为 4，实际 %d）" % eng5.state.turn_card_raise)

	# ⑤b buff_allies_atk（老虎 9038）：其他 2 个盟友各 +2 攻，自己不加
	var eng5b := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng5b.ai_enabled = false
	var mate: Array[Placement] = []
	for i in 2:
		var a2 := CardData.new()
		a2.kind = "盟友"
		a2.card_name = "虎伴%d" % i
		a2.health = 5
		a2.power = 1
		mate.append(eng5b.state.place(a2, Vector2i(i + 1, 0), GameEngine.SIDE_SELF))
	var p5b := _probe_unit(eng5b, "use", Vector2i(4, 0))
	p5b.card.assemble = {"trigger": "use", "effects": [{"type": "buff_allies_atk", "value": 2}]}
	var own_before := p5b.effective_power()
	eng5b._assemble_execute(p5b, Vector2i(4, 0), "use")
	check(mate[0] != null and mate[1] != null
			and mate[0].effective_power() == 3 and mate[1].effective_power() == 3,
			"R570b：老虎 → 其他盟友各 +2 攻（实际 %d / %d）"
			% [mate[0].effective_power() if mate[0] != null else -1,
			mate[1].effective_power() if mate[1] != null else -1])
	check(p5b.effective_power() == own_before, "R570b：老虎的「其他盟友」不含自己")

	# ⑥ add_copy（野兔 9032）：手牌 +1，且复制品是**衍生物**（离场/回合结束消失）
	var eng6 := GameEngine.new(FieldState.new([], 20, 20, -1, "测试", false))
	eng6.ai_enabled = false
	var p6 := _probe_unit(eng6, "use", Vector2i(3, 0))
	p6.card.card_name = "R570 复制探针"
	p6.card.assemble = {"trigger": "use", "effects": [{"type": "add_copy", "value": 1}]}
	eng6._assemble_execute(p6, Vector2i(3, 0), "use")
	check(eng6.state.hand.size() == 1 and eng6.state.hand[0].is_ephemeral,
			"R570：手牌 +1 且带衍生物标记（hand %d / ephemeral %s）"
			% [eng6.state.hand.size(),
			str(eng6.state.hand[0].is_ephemeral) if eng6.state.hand.size() == 1 else "n/a"])

	# ⑦ 数值校验：空动作判废
	check(Rules.valid_effect({"type": "buff_per_energy", "atk": 1, "hp": 2}),
			"R570：buff_per_energy(1/2) 合法")
	check(not Rules.valid_effect({"type": "buff_per_energy", "atk": 0, "hp": 0}),
			"R570：buff_per_energy(0/0) 是空动作 → 判废")
	check(not Rules.valid_effect({"type": "buff_per_ally", "value": 0}), "R570：+0 力量判废")
	check(not Rules.valid_effect({"type": "add_copy", "value": 0}), "R570：复制 0 张判废")

	# ⑧ 有出处的数量：本轮 7 张各自的下半文本要能逐字对上原卡
	var want := {9040: "每有一个其他盟友", 8019: "剩余费用每有 1 点", 8020: "剩余费用每有 1 点",
			8062: "剩余费用", 9034: "技能牌", 8024: "费用 +4", 9032: "复制", 9038: "其他盟友攻击 +2"}
	for cid: int in want.keys():
		var c: CardData = repo.get_card(cid)
		check(c != null and not c.lower_effect.is_empty(),
				"R570：%d 必须进候选池" % cid)
		if c != null:
			var body := Rules.body_text(c.lower_effect)
			check(body.contains(str(want[cid])),
					"R570：%d %s 的下半文案缺特征「%s」（实际「%s」）"
					% [cid, c.card_name, str(want[cid]), body])

	# ⑨ 源码锁：六条动作各有唯一实现口，母卡与组合共用同一段
	var gs := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check(gs.find("func _buff_per_other_ally") >= 0 and gs.count("_buff_per_other_ally(") >= 3,
			"R570 源码锁：每盟友成长只有 `_buff_per_other_ally` 一个实现口（猎犬 + 组合）")
	check(gs.find("func _buff_by_surplus_energy") >= 0 and gs.count("_buff_by_surplus_energy(") >= 4,
			"R570 源码锁：剩余费用成长只有 `_buff_by_surplus_energy` 一个实现口（地狱猫/鲜血堡垒 + 组合）")
	check(gs.find("func _raise_hand_cost") >= 0 and gs.count("_raise_hand_cost(") >= 3,
			"R570 源码锁：手卡涨价只有 `_raise_hand_cost` 一个实现口（契约 + 组合）")
	check(gs.count("_fetch_skill_card(") >= 3,
			"R570 源码锁：从卡组取技能牌只有 `_fetch_skill_card` 一个实现口（赤狐 + 组合）")
	check(gs.count("_spawn_self_clone(") >= 3,
			"R570 源码锁：自我复制只有 `_spawn_self_clone` 一个实现口（野兔 + 组合）")
	check(gs.find("func _buff_other_allies_atk") >= 0 and gs.count("_buff_other_allies_atk(") >= 3,
			"R570b 源码锁：其他盟友加攻只有 `_buff_other_allies_atk` 一个实现口（老虎 + 组合）")
	check(gs.count("_night_erosion_heal(") >= 3,
			"R570 源码锁：按剩余费用回血只有 `_night_erosion_heal` 一个实现口（夜蚀 + 组合）")
