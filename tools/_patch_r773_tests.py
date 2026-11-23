# -*- coding: utf-8 -*-
"""R773 呼唤（9266）：test_engine.gd / test_reward.gd 同步。

test_engine.gd 是 CRLF，test_reward.gd 是 LF —— 锚点分开处理。
四处计数 + 一处 R761 断言放宽 + 新增 `_test_r773()` 段 + 注册。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
TR = os.path.join(ROOT, "scripts", "test_reward.gd")


def read(p):
    return io.open(p, "rb").read().decode("utf-8")


def write(p, s):
    io.open(p, "wb").write(s.encode("utf-8"))


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    return text.replace(old, new)


te = read(TE)
assert "\n" not in te.replace("\r\n", "")

# ── ① 图鉴总数 326 → 327 ──────────────────────────────────────────────────
te = sub(te,
         'check(repo.all_cards().size() == 326,\r\n\r\n'
         '\t\t\t"图鉴 = 326 张（R766 +1：懊悔 9265',
         'check(repo.all_cards().size() == 327,\r\n\r\n'
         '\t\t\t"图鉴 = 327 张（R773 +1：呼唤 9266（吟游诗人 · 0 费普通技能 · rarity 0，'
         '但职业隐藏 → 默认不进图鉴 / 随机池）；R766 +1：懊悔 9265',
         "图鉴总数")

# ── ② 玩家卡 248 → 249 ────────────────────────────────────────────────────
te = sub(te,
         'check(grp_player.size() == 248 and grp_enemy.size() == 78,',
         'check(grp_player.size() == 249 and grp_enemy.size() == 78,',
         "玩家卡数")
te = sub(te,
         '"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 248 / 78（R766 玩家 +1：懊悔 9265',
         '"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 249 / 78（R773 玩家 +1：呼唤 9266；'
         'R766 玩家 +1：懊悔 9265',
         "玩家卡数说明")

# ── ③ 吟游诗人卡数 2 → 3 ─────────────────────────────────────────────────
te = sub(te,
         'and int(dr_cls_count.get(PlayerClass.BARD, 0)) == 2',
         'and int(dr_cls_count.get(PlayerClass.BARD, 0)) == 3',
         "吟游诗人卡数")
te = sub(te,
         '（期望 78 / 66 / 75 / 78 / 吟游诗人 2 / 公用 27（R766 公用 +1：懊悔 9265；'
         'R761 吟游诗人 +2：杜鹃 9263 / 招募 9264）',
         '（期望 78 / 66 / 75 / 78 / 吟游诗人 3 / 公用 27（R773 吟游诗人 +1：呼唤 9266；'
         'R766 公用 +1：懊悔 9265；R761 吟游诗人 +2：杜鹃 9263 / 招募 9264）',
         "吟游诗人卡数说明")

# ── ④ R761：include_hidden 断言放宽（rarity 0 的隐藏卡本来就该在）──────────
old = (
    '\tvar r761_hidden_in_all: Array = []\r\n'
    '\tfor c3: CardData in r761_repo.obtainable_cards(true):\r\n'
    '\t\tif PlayerClass.is_hidden_class(c3.card_class):\r\n'
    '\t\t\tr761_hidden_in_all.append(c3.id)\r\n'
    '\tcheck(r761_hidden_in_all.is_empty(),\r\n'
    '\t\t\t"R761 卡池：连 include_hidden 也进不去 —— 初始卡 rarity 3 是第二道闸")\r\n'
)
new = (
    '\t# R773：呼唤 9266 是 rarity 0 的**普通卡** → 它本来就该在 include_hidden 里\r\n'
    '\t#（吟游诗人本人开局要抽得到自己的新卡）。所以这道闸改成「不许 rarity>2 的隐藏卡」。\r\n'
    '\tvar r761_hidden_in_all: Array = []\r\n'
    '\tfor c3: CardData in r761_repo.obtainable_cards(true):\r\n'
    '\t\tif PlayerClass.is_hidden_class(c3.card_class) and c3.rarity > 2:\r\n'
    '\t\t\tr761_hidden_in_all.append(c3.id)\r\n'
    '\tcheck(r761_hidden_in_all.is_empty(),\r\n'
    '\t\t\t"R761 卡池：include_hidden 里也不许混进 rarity>2 的隐藏职业卡（初始卡是第二道闸）")\r\n'
)
te = sub(te, old, new, "R761 include_hidden")

# ── ⑤ 注册 ────────────────────────────────────────────────────────────────
te = sub(te, "\t_test_r769()\r\n", "\t_test_r769()\r\n\r\n\t_test_r773()\r\n", "注册")

# ── ⑥ 插入测试段 ──────────────────────────────────────────────────────────
TESTS = r'''
# ================= R773：吟游诗人「呼唤」9266 =================
# 店长口径（原话）：
#   「0费。这张卡使用后，本局费用＋1。将一张随机比这张卡费用高1的其他职业盟友加入手卡，
#    其费用本局变成0。」
# 落地口径：
#   * 「本局」按项目术语 = **本场战斗内**（跨回合、跨层不成立）→ 费用上限记在
#     `_battle_energy_bonus`（引擎实例字段，一场一个引擎 → 自然复位），
#     `_begin_turn` 发费与 `max_energy()` 分母同一口径；
#   * 「比这张卡费用高 1」读**卡面费用**（`card.cost`，不是 `cost_of()`）—— 减费 / 免费
#     不该改变这条判据；本卡 0 费 → 找 1 费；
#   * 「其他职业盟友」唯一判据 `_other_class_card()`（有归属 + 不是自己；公用卡不算）；
#   * 「其费用本局变成 0」复用 `state.hand_free`（判据带 `state.hand.has`）→ 离手自动恢复原价。
func _test_r773() -> void:
	var r773_gs = preload("res://scripts/gallery_scene.gd")
	var r773_repo := CardRepo.load_json()
	var r773_call: CardData = r773_repo.get_card(9266)
	var r773_sv_relics: Array[int] = RunState.relics.duplicate()
	var r773_sv_spent: Array[int] = RunState.spent_relics.duplicate()
	var r773_sv_active: bool = RunState.run_active
	RunState.run_active = false   # 测试里打的牌不许写进玩家成就统计
	RunState.relics = []
	RunState.spent_relics = []

	# ① 数据
	check(r773_call != null and r773_call.card_name == "呼唤"
			and r773_call.kind == "技能" and r773_call.cost == 0
			and r773_call.rarity == 0 and r773_call.card_class == PlayerClass.BARD
			and r773_call.target_mode == "none",
			"R773 数据：呼唤 9266 = 吟游诗人 0 费普通技能（rarity 0）")
	if r773_call == null:
		RunState.relics = r773_sv_relics
		RunState.spent_relics = r773_sv_spent
		RunState.run_active = r773_sv_active
		return
	check(r773_call.color == "水风"
			and r773_call.effect_text.contains("费用本局 +1")
			and r773_call.effect_text.contains("其他职业盟友"),
			"R773 数据：卡色水风（与杜鹃 / 招募同族）、卡面两条效果都写了")

	# ② 隐藏职业口径不因「普通稀有度」而破
	check(not r773_gs.gallery_visible(r773_call, false)
			and not r773_gs.gallery_visible(r773_call, true),
			"R773 隐藏：普通稀有度也不进图鉴（判据在职业，不在稀有度）")
	var r773_in_default := false
	for c0: CardData in r773_repo.obtainable_cards():
		if c0.id == 9266:
			r773_in_default = true
	check(not r773_in_default,
			"R773 卡池：默认可获得池不含 9266（三个可见职业抽不到）")
	var r773_in_hidden := false
	for c1: CardData in r773_repo.obtainable_cards(true):
		if c1.id == 9266:
			r773_in_hidden = true
	check(r773_in_hidden,
			"R773 卡池：include_hidden 含 9266 —— 吟游诗人本人开局抽得到")
	var r773_bard_has := false
	for c2: CardData in r773_repo.reward_pool_for(PlayerClass.BARD):
		if c2.id == 9266:
			r773_bard_has = true
	check(r773_bard_has,
			"R773 卡池：吟游诗人的奖励池含 9266（进得去才玩得到）")

	# ③ 随机源：只出「1 费 + 其他职业 + 盟友」
	var r773_probe := _new_engine([], 20, 20, -1, false)
	var r773_bad: Array = []
	var r773_cls_seen := {}
	for _i in range(200):
		var pick := r773_probe._random_call_ally(r773_call)
		if pick == null:
			r773_bad.append("null")
			continue
		r773_cls_seen[pick.card_class] = true
		if pick.kind != "盟友" or pick.cost != 1 \
				or pick.card_class == PlayerClass.BARD or pick.card_class == "":
			r773_bad.append(pick.id)
	check(r773_bad.is_empty(),
			"R773 随机源：200 抽全是 1 费其他职业盟友（异常 %s）" % str(r773_bad))
	check(r773_cls_seen.size() >= 2,
			"R773 随机源：三个职业都摇得到（本次出现 %s）" % str(r773_cls_seen.keys()))
	check(not r773_probe._other_class_card(r773_call),
			"R773 判据：呼唤自己不算「其他职业卡」（有归属 + 不是自己）")

	# ④ 打出第一张：当回合费用 +1、上限 +1、入手那张费用归 0
	var r773_d1: Array[CardData] = []
	r773_d1.append(r773_call)
	r773_d1.append(r773_call)
	var r773_e := _new_engine(r773_d1, 20, 20, -1, false)
	r773_e.start_game(1)
	r773_e.state.energy = 3
	var r773_base_cap := r773_e.max_energy()
	var r773_hand_before: int = r773_e.state.hand.size()
	r773_e.use_spell(_find(r773_e.state.hand, 9266))
	check(r773_e.state.energy == 4 and r773_e._battle_energy_bonus == 1,
			"R773 打出：0 费技能不扣费、本局费用 +1（3 → %d，累计 %d）"
			% [r773_e.state.energy, r773_e._battle_energy_bonus])
	check(r773_e.max_energy() == r773_base_cap + 1,
			"R773 打出：费用上限同步 +1（%d → %d）"
			% [r773_base_cap, r773_e.max_energy()])
	check(r773_e.state.hand.size() == r773_hand_before,
			"R773 打出：手牌数不变（打出 1 张、入手 1 张）")
	var r773_got: CardData = null
	for c3: CardData in r773_e.state.hand:
		if r773_e.state.hand_free.has(c3):
			r773_got = c3
	check(r773_got != null and r773_got.kind == "盟友" and r773_got.cost == 1
			and r773_got.card_class != PlayerClass.BARD and r773_got.card_class != "",
			"R773 打出：入手的盟友是 1 费其他职业（%s）"
			% (r773_got.card_name if r773_got != null else "无"))
	if r773_got != null:
		check(r773_e.cost_of(r773_got) == 0,
				"R773 打出：那张盟友本局费用为 0（卡面 %d 费）" % r773_got.cost)
		check(r773_e.state.hand.has(r773_got),
				"R773 打出：它真在手牌里（归零判据靠 hand.has）")

	# ⑤ 叠层：第二张再 +1
	r773_e.use_spell(_find(r773_e.state.hand, 9266))
	check(r773_e.state.energy == 5 and r773_e._battle_energy_bonus == 2,
			"R773 叠加：第二张呼唤 → 本局费用再 +1（累计 %d）" % r773_e._battle_energy_bonus)
	check(r773_e.max_energy() == r773_base_cap + 2,
			"R773 叠加：上限跟着累计走（%d）" % r773_e.max_energy())

	# ⑥ 「本局」的成色：新回合发费带加成、hand_free 不清（与 turn_free 的回合制相反）
	var r773_next_expected: int = RunState.energy_per_turn() + 2
	r773_e.state.energy = 0
	r773_e._begin_turn(GameEngine.SIDE_SELF)
	check(r773_e.state.energy == r773_next_expected,
			"R773 本局：新回合发费 = 基础 %d + 累计 2（实际 %d）"
			% [RunState.energy_per_turn(), r773_e.state.energy])
	check(r773_e.max_energy() == r773_next_expected,
			"R773 本局：上限与实发同一口径（%d）" % r773_e.max_energy())
	if r773_got != null:
		check(r773_e.state.hand_free.has(r773_got) and r773_e.cost_of(r773_got) == 0,
				"R773 本局：跨回合仍是 0 费（hand_free 不在回合结束清空）")

	# ⑦ 离手即恢复原价（归零只认「此刻还在手牌里」）
	if r773_got != null:
		r773_e.state.hand.erase(r773_got)
		check(r773_e.cost_of(r773_got) == r773_got.cost,
				"R773 离手：不在手牌里就恢复卡面费用（%d）" % r773_e.cost_of(r773_got))

	# ⑧ 空池自愈：卡池里没有 1 费其他职业盟友时，费用照给、效果落空（不炸）
	var r773_d2: Array[CardData] = []
	r773_d2.append(r773_call)
	var r773_e2 := _new_engine(r773_d2, 20, 20, -1, false)
	r773_e2.start_game(1)
	r773_e2.state.energy = 2
	var r773_none := r773_e2._random_call_ally(_card(19999, "零费探针", "技能", 89, 0, 0))
	check(r773_none == null,
			"R773 空池：费用 +89 找不到对应盟友 → 返回 null（不是随便塞一张）")
	r773_e2.use_spell(_find(r773_e2.state.hand, 9266))
	check(r773_e2.state.energy == 3 and r773_e2._battle_energy_bonus == 1,
			"R773 空池：效果落空但费用照给（2 → %d）" % r773_e2.state.energy)

	# 收尾还原
	RunState.relics = r773_sv_relics
	RunState.spent_relics = r773_sv_spent
	RunState.run_active = r773_sv_active


'''
anchor = "# ================= R762：开始游戏 → 标准 / 每日挑战 ================="
te = sub(te, anchor, TESTS.lstrip("\n") + anchor, "测试段插入")
write(TE, te)
print("[ok] test_engine.gd 已写入")

# ── test_reward.gd（LF）────────────────────────────────────────────────────
tr = read(TR)
assert "\r\n" not in tr
tr = sub(tr,
         'check(all.size() == 326, "卡牌库 326 张（R766 +1：懊悔 9265',
         'check(all.size() == 327, "卡牌库 327 张（R773 +1：呼唤 9266（吟游诗人 · 0 费普通技能 · '
         'rarity 0，职业隐藏 → 默认不进奖励池）；R766 +1：懊悔 9265',
         "test_reward 计数")
write(TR, tr)
print("[ok] test_reward.gd 已写入")
