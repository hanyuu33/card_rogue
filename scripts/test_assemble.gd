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
		check(not body.contains("："),
				"R567：%d %s 下半文案里不许出现扳机式冒号（实际「%s」）"
				% [c.id, c.card_name, body])
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
	# 火元素：「每清除 1 张，对随机一个敌人造成 2 点伤害」依赖前置的清除数量，
	# 下半单独拿出来就不是原效果（用户口径「甚至跟原本效果不符」）→ 已移出候选池。
	var fire: CardData = repo.get_card(9236)
	check(fire.upper_effect.is_empty() and fire.lower_effect.is_empty(),
			"R567：火元素已移出候选池（下半依赖「每清除 1 张」的前提）")
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
	check(cand.size() == 12, "R567 组合：可组合盟友/工事候选 %d 张（期望 12）" % cand.size())
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
