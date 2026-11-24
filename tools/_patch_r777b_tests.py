# -*- coding: utf-8 -*-
"""R777b 疾风乐章（9270）：test_engine.gd 回归段 + 计数更新。

插入位置与 R777 相同（R762 那节之前），调用点跟在 _test_r777 后面。
计数：331 张 / 玩家 253 / 吟游诗人 7 / R226 技能数不变（效果卡）。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
s = io.open(TE, "rb").read().decode("utf-8")
assert "_test_r777b" not in s


def sub(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    s = s.replace(old, new)


# ── ① 计数 ────────────────────────────────────────────────────────────────
sub('check(repo.all_cards().size() == 330,',
    'check(repo.all_cards().size() == 331,', "图鉴总数")
sub('"图鉴 = 330 张（R777 +1：',
    '"图鉴 = 331 张（R777b +1：疾风乐章 9270（吟游诗人 · 2 费史诗效果，'
    '职业隐藏 → 不进图鉴 / 随机池）；R777 +1：', "图鉴说明")
sub('grp_player.size() == 252 and grp_enemy.size() == 78,',
    'grp_player.size() == 253 and grp_enemy.size() == 78,', "玩家分组")
sub('（期望 252 / 78（R777 玩家 +1：',
    '（期望 253 / 78（R777b 玩家 +1：疾风乐章 9270；R777 玩家 +1：', "玩家分组说明")
sub('int(dr_cls_count.get(PlayerClass.BARD, 0)) == 6',
    'int(dr_cls_count.get(PlayerClass.BARD, 0)) == 7', "职业分布断言")
sub('吟游诗人 6 / 公用 27（R777 吟游诗人 +1：',
    '吟游诗人 7 / 公用 27（R777b 吟游诗人 +1：疾风乐章 9270；R777 吟游诗人 +1：',
    "职业分布说明")

# ── ② 调用点 ──────────────────────────────────────────────────────────────
sub('\t_test_r777()\r\n', '\t_test_r777()\r\n\t_test_r777b()\r\n', "调用点")

# ── ③ 回归段 ──────────────────────────────────────────────────────────────
FUNC = '''# ================= R777b：吟游诗人「疾风乐章」9270 =================
# 店长口径（原话）：
#   「2费，疾风乐章。所有盟友移动速度+1.若为其他职业盟友，改为一回合行动两次」
# 落地口径：
#   * 「所有盟友」= 己方场上 `kind == "盟友"`（工事 / 场地不算）；
#   * 「移动速度 +1」直接抬场上 `card.move_speed`（与「改造」同一口径，场上实例是独立副本）；
#   * 「其他职业盟友」走 `_other_class_card()` 唯一判据（有归属 + 不是玩家当前职业；
#     公用卡 class 留空 → 不算「其他职业」→ 照常吃移速）；
#   * 「改为一回合行动两次」= **替代**移速，复用哈气的 `Placement.haste_double`
#     （单点永久、离场消失）→ `unit_actions()` 每回合自动给到，不必重算。
func _test_r777b() -> void:
	var r777b_gs = preload("res://scripts/gallery_scene.gd")
	var r777b_repo := CardRepo.load_json()
	var r777b_card: CardData = r777b_repo.get_card(9270)
	var r777b_sv_relics: Array[int] = RunState.relics.duplicate()
	var r777b_sv_spent: Array[int] = RunState.spent_relics.duplicate()
	var r777b_sv_active: bool = RunState.run_active
	var r777b_sv_class: String = RunState.player_class
	RunState.run_active = false
	RunState.player_class = PlayerClass.BARD
	RunState.relics = []
	RunState.spent_relics = []

	# ① 数据
	check(r777b_card != null and r777b_card.card_name == "疾风乐章"
			and r777b_card.kind == "效果" and r777b_card.cost == 2
			and r777b_card.rarity == 2
			and r777b_card.card_class == PlayerClass.BARD
			and r777b_card.traits.has("疾风乐章")
			and r777b_card.target_mode == "none",
			"R777b 数据：疾风乐章 9270 = 吟游诗人 2 费史诗效果卡（rarity 2）")
	if r777b_card == null:
		RunState.relics = r777b_sv_relics
		RunState.spent_relics = r777b_sv_spent
		RunState.run_active = r777b_sv_active
		RunState.player_class = r777b_sv_class
		return
	check(r777b_card.color == "水风"
			and r777b_card.effect_text.contains("移动速度 +1")
			and r777b_card.effect_text.contains("一回合行动两次"),
			"R777b 数据：卡色水风、卡面两条都写了（移速 / 双动）")

	# ② 隐藏职业口径
	check(not r777b_gs.gallery_visible(r777b_card, false)
			and not r777b_gs.gallery_visible(r777b_card, true),
			"R777b 隐藏：吟游诗人卡不进图鉴（判据在职业）")
	var r777b_in_default := false
	for c0: CardData in r777b_repo.obtainable_cards():
		if c0.id == 9270:
			r777b_in_default = true
	check(not r777b_in_default, "R777b 卡池：默认可获得池不含 9270")
	var r777b_bard_has := false
	for c1: CardData in r777b_repo.reward_pool_for(PlayerClass.BARD):
		if c1.id == 9270:
			r777b_bard_has = true
	check(r777b_bard_has, "R777b 卡池：吟游诗人的奖励池含 9270")

	# ③ 打出：本职业盟友 +1 移速；其他职业盟友改双动（不给移速）；工事不沾
	var r777b_deck: Array[CardData] = []
	r777b_deck.append(r777b_card)
	var r777b_e := _new_engine(r777b_deck, 20, 20, -1, false)
	r777b_e.start_game(1)
	r777b_e.state.energy = 5
	var r777b_own: Placement = r777b_e.state.place(
			CardData.from_dict(r777b_repo.get_card(9263).to_dict()),
			Vector2i(0, 4), GameEngine.SIDE_SELF)          # 杜鹃：吟游诗人（本职业）
	var r777b_alien: Placement = r777b_e.state.place(
			CardData.from_dict(r777b_repo.get_card(8003).to_dict()),
			Vector2i(1, 4), GameEngine.SIDE_SELF)          # 树人：森林精魄（其他职业）
	var r777b_fort: Placement = r777b_e.state.place(
			CardData.from_dict(r777b_repo.get_card(8001).to_dict()),
			Vector2i(2, 4), GameEngine.SIDE_SELF)          # 木栅栏：工事
	check(r777b_own != null and r777b_alien != null and r777b_fort != null,
			"R777b 摆放：三个单位都上场了（盟友 ×2 + 工事 ×1）")
	if r777b_own == null or r777b_alien == null or r777b_fort == null:
		RunState.relics = r777b_sv_relics
		RunState.spent_relics = r777b_sv_spent
		RunState.run_active = r777b_sv_active
		RunState.player_class = r777b_sv_class
		return
	var r777b_own_spd0: int = r777b_own.card.move_speed
	var r777b_alien_spd0: int = r777b_alien.card.move_speed
	var r777b_fort_spd0: int = r777b_fort.card.move_speed
	var r777b_effects0: int = r777b_e.state.effects.size()
	r777b_e.use_effect(_find(r777b_e.state.hand, 9270))
	check(r777b_e.state.energy == 3,
			"R777b 打出：2 费照扣（5 → %d）" % r777b_e.state.energy)
	check(r777b_e.state.effects.size() == r777b_effects0 + 1,
			"R777b 打出：进了效果区（%d → %d）"
			% [r777b_effects0, r777b_e.state.effects.size()])
	check(r777b_own.card.move_speed == r777b_own_spd0 + 1,
			"R777b 移速：本职业盟友 %d → %d"
			% [r777b_own_spd0, r777b_own.card.move_speed])
	check(r777b_alien.card.move_speed == r777b_alien_spd0,
			"R777b 替代：其他职业盟友**没有**拿到移速（%d → %d）"
			% [r777b_alien_spd0, r777b_alien.card.move_speed])
	check(r777b_alien.haste_double
			and r777b_e.state.unit_actions(r777b_alien, GameEngine.SIDE_SELF)
					== FieldState.HASTE_ACTIONS,
			"R777b 双动：其他职业盟友改为每回合行动 %d 次"
			% FieldState.HASTE_ACTIONS)
	check(r777b_alien.acts_left >= 2,
			"R777b 双动：打出当回合就补足行动轮数（acts_left=%d）" % r777b_alien.acts_left)
	check(r777b_fort.card.move_speed == r777b_fort_spd0
			and not r777b_fort.haste_double,
			"R777b 工事：不算盟友，移速与双动都不沾")

	# ④ 跨回合仍在（haste_double 是单点永久字段，移速是卡面数值）
	r777b_e.state.reset_units(GameEngine.SIDE_SELF)
	check(r777b_e.state.unit_actions(r777b_alien, GameEngine.SIDE_SELF)
			== FieldState.HASTE_ACTIONS,
			"R777b 本场：新回合仍是每回合两次（reset_units 后不变）")
	check(r777b_own.card.move_speed == r777b_own_spd0 + 1,
			"R777b 本场：新回合移速仍是 +1（%d）" % r777b_own.card.move_speed)

	# ⑤ 叠两张：移速再 +1（双动不会重复叠成 3 次）
	var r777b_deck2: Array[CardData] = []
	r777b_deck2.append(r777b_card)
	r777b_deck2.append(r777b_card)
	var r777b_e2 := _new_engine(r777b_deck2, 20, 20, -1, false)
	r777b_e2.start_game(1)
	r777b_e2.state.energy = 9
	var r777b_own2: Placement = r777b_e2.state.place(
			CardData.from_dict(r777b_repo.get_card(9263).to_dict()),
			Vector2i(0, 4), GameEngine.SIDE_SELF)
	var r777b_alien2: Placement = r777b_e2.state.place(
			CardData.from_dict(r777b_repo.get_card(8003).to_dict()),
			Vector2i(1, 4), GameEngine.SIDE_SELF)
	var r777b_own2_spd0: int = r777b_own2.card.move_speed
	r777b_e2.use_effect(_find(r777b_e2.state.hand, 9270))
	r777b_e2.use_effect(_find(r777b_e2.state.hand, 9270))
	check(r777b_own2.card.move_speed == r777b_own2_spd0 + 2,
			"R777b 叠加：两张 → 移速 +2（%d）" % r777b_own2.card.move_speed)
	check(r777b_e2.state.unit_actions(r777b_alien2, GameEngine.SIDE_SELF)
			== FieldState.HASTE_ACTIONS,
			"R777b 叠加：双动仍是 2 次（不会叠成 3 次）")

	# ⑥ 空场：没有盟友时照常吃掉费用、不崩
	var r777b_deck3: Array[CardData] = []
	r777b_deck3.append(r777b_card)
	var r777b_e3 := _new_engine(r777b_deck3, 20, 20, -1, false)
	r777b_e3.start_game(1)
	r777b_e3.state.energy = 4
	var r777b_msg: String = r777b_e3.use_effect(_find(r777b_e3.state.hand, 9270))
	check(r777b_e3.state.energy == 2 and r777b_msg != "",
			"R777b 空场：照常扣 2 费并生效（%s）" % r777b_msg)

	# ⑦ 三语（`naturalize_card` 只出效果正文；卡名另走 GameI18n.card_name）
	var r777b_lang_bak: String = GameSettings.language
	GameSettings.language = "en"
	GameI18n.reset_cache()
	var r777b_en_name: String = GameI18n.card_name(9270, r777b_card.card_name)
	var r777b_en: String = CardText.naturalize_card(r777b_card)
	GameSettings.language = "ja"
	GameI18n.reset_cache()
	var r777b_ja_name: String = GameI18n.card_name(9270, r777b_card.card_name)
	var r777b_ja: String = CardText.naturalize_card(r777b_card)
	GameSettings.language = r777b_lang_bak
	GameI18n.reset_cache()
	check(r777b_en_name == "Wind Song",
			"R777b 译文：en 卡名走 i18n（%s）" % r777b_en_name)
	check(r777b_en.find("Move Speed") >= 0 and r777b_en.find("twice") >= 0
			and r777b_en.find("移动速度") < 0 and r777b_en.find("盟友") < 0,
			"R777b 译文：en 效果正文是英文（%s）" % r777b_en.replace("\\n", " ").left(40))
	check(r777b_ja_name == "疾風の楽章",
			"R777b 译文：ja 卡名走 i18n（%s）" % r777b_ja_name)
	check(r777b_ja.find("移動速度") >= 0 and r777b_ja.find("味方") >= 0
			and r777b_ja.find("移动速度") < 0 and r777b_ja.find("盟友") < 0,
			"R777b 译文：ja 效果正文是日文（%s）" % r777b_ja.replace("\\n", " ").left(40))

	# 收尾还原
	RunState.relics = r777b_sv_relics
	RunState.spent_relics = r777b_sv_spent
	RunState.run_active = r777b_sv_active
	RunState.player_class = r777b_sv_class


'''

FUNC = FUNC.replace("\n", "\r\n")
sub('# ================= R762：开始游戏', FUNC + '# ================= R762：开始游戏',
    "回归段插入")

assert "\n" not in s.replace("\r\n", "")
io.open(TE, "wb").write(s.encode("utf-8"))
print("[ok] test_engine.gd 已写入 R777b 回归段 + 计数 331 / 253 / 吟游诗人 7")
