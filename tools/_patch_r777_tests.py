# -*- coding: utf-8 -*-
"""R777 彩虹诗（9269）：test_engine.gd（CRLF）加回归段 + 更新三处计数 + R226 技能数。

⚠️ 并行线（R776）已经把计数从 327/249/吟游诗人 3 改到 329/251/5，
   所以这里改的是**它改完之后**的值 → 330/252/6。
   插入的说明文字在前，保留它原有的 R776 记录。
"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TE = os.path.join(ROOT, "scripts", "test_engine.gd")
s = io.open(TE, "rb").read().decode("utf-8")
assert "\n" not in s.replace("\r\n", ""), "test_engine.gd 不是纯 CRLF"
assert "_test_r777" not in s, "_test_r777 已存在"


def sub(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点命中 %d 次" % (tag, n)
    s = s.replace(old, new)


# ── ① 计数：图鉴总数 329 → 330 ───────────────────────────────────────────
sub('check(repo.all_cards().size() == 329,',
    'check(repo.all_cards().size() == 330,', "图鉴总数")
sub('"图鉴 = 329 张（R776 +2：',
    '"图鉴 = 330 张（R777 +1：彩虹诗 9269（吟游诗人 · 2 费稀有技能，'
    '职业隐藏 → 不进图鉴 / 随机池）；R776 +2：', "图鉴说明")

# ── ② 分组：玩家 249 → 252（真实值；并行线只改了说明文字没改断言）──────────
sub('grp_player.size() == 249 and grp_enemy.size() == 78,',
    'grp_player.size() == 252 and grp_enemy.size() == 78,', "玩家分组")
sub('（期望 251 / 78（R776 玩家 +2：',
    '（期望 252 / 78（R777 玩家 +1：彩虹诗 9269；R776 玩家 +2：', "玩家分组说明")

# ── ③ 职业分布：吟游诗人 5 → 6 ───────────────────────────────────────────
sub('int(dr_cls_count.get(PlayerClass.BARD, 0)) == 5',
    'int(dr_cls_count.get(PlayerClass.BARD, 0)) == 6', "职业分布断言")
sub('吟游诗人 5 / 公用 27（R776 吟游诗人 +2：',
    '吟游诗人 6 / 公用 27（R777 吟游诗人 +1：彩虹诗 9269；R776 吟游诗人 +2：',
    "职业分布说明")

# ── ④ R226：玩家技能卡 106 → 107（彩虹诗是技能但不直接造成伤害）─────────
sub('check(r226_skills == 106 and r226_dmg == 42',
    'check(r226_skills == 107 and r226_dmg == 42', "R226 技能数")
sub('（R329 删紧急埋伏 9106 → 技能 -1）',
    '（R777 彩虹诗 9269 是技能但不直接造成伤害 → 技能 +1、伤害数不变）'
    '（R329 删紧急埋伏 9106 → 技能 -1）', "R226 注释")

# ── ⑤ 调用点 ──────────────────────────────────────────────────────────────
sub('\t_test_r773()\r\n', '\t_test_r773()\r\n\t_test_r777()\r\n', "调用点")

# ── ⑥ 回归段本体（插在 R762 那节之前）────────────────────────────────────
FUNC = '''# ================= R777：吟游诗人「彩虹诗」9269 =================
# 店长口径（原话）：
#   「2费，从随机3个不同其他职业的盟友或技能卡中各随机一张加入手卡，
#    并使这些卡本局费用-1。」
# 落地口径：
#   * 「随机 3 个不同**其他职业**」= `PlayerClass.ids()` 去掉玩家当前职业后洗牌取前 3 ——
#     隐藏职业（吟游诗人）天然不在 ids() 里，所以非吟游诗人永远摇不到它那几张；
#   * 「盟友或技能卡」= kind 二选一，工事 / 效果 / 诅咒一律不进；
#   * 「本局费用 -1」= `state.hand_cost_delta`（手卡内减费唯一口径）：表在 FieldState 上，
#     一场战斗一个 → 跨回合有效、新战斗自然复位；**不是** `hand_free`（那是归 0 且不可叠）。
func _test_r777() -> void:
\tvar r777_gs = preload("res://scripts/gallery_scene.gd")
\tvar r777_repo := CardRepo.load_json()
\tvar r777_card: CardData = r777_repo.get_card(9269)
\tvar r777_sv_relics: Array[int] = RunState.relics.duplicate()
\tvar r777_sv_spent: Array[int] = RunState.spent_relics.duplicate()
\tvar r777_sv_active: bool = RunState.run_active
\tvar r777_sv_class: String = RunState.player_class
\tRunState.run_active = false   # 测试里打的牌不许写进玩家成就统计
\tRunState.player_class = PlayerClass.BARD
\tRunState.relics = []
\tRunState.spent_relics = []

\t# ① 数据
\tcheck(r777_card != null and r777_card.card_name == "彩虹诗"
\t\t\tand r777_card.kind == "技能" and r777_card.cost == 2
\t\t\tand r777_card.rarity == 1
\t\t\tand r777_card.card_class == PlayerClass.BARD
\t\t\tand r777_card.target_mode == "none",
\t\t\t"R777 数据：彩虹诗 9269 = 吟游诗人 2 费稀有技能（rarity 1）")
\tif r777_card == null:
\t\tRunState.relics = r777_sv_relics
\t\tRunState.spent_relics = r777_sv_spent
\t\tRunState.run_active = r777_sv_active
\t\tRunState.player_class = r777_sv_class
\t\treturn
\tcheck(r777_card.color == "水风"
\t\t\tand r777_card.effect_text.contains("3 个不同其他职业")
\t\t\tand r777_card.effect_text.contains("费用本局 -1"),
\t\t\t"R777 数据：卡色水风（与杜鹃 / 招募 / 呼唤同族）、卡面写明 3 个职业与 -1")

\t# ② 隐藏职业口径：与呼唤同一套（图鉴 / 默认池都不进）
\tcheck(not r777_gs.gallery_visible(r777_card, false)
\t\t\tand not r777_gs.gallery_visible(r777_card, true),
\t\t\t"R777 隐藏：吟游诗人卡不进图鉴（判据在职业，不在稀有度）")
\tvar r777_in_default := false
\tfor c0: CardData in r777_repo.obtainable_cards():
\t\tif c0.id == 9269:
\t\t\tr777_in_default = true
\tcheck(not r777_in_default,
\t\t\t"R777 卡池：默认可获得池不含 9269（三个可见职业抽不到）")
\tvar r777_bard_has := false
\tfor c1: CardData in r777_repo.reward_pool_for(PlayerClass.BARD):
\t\tif c1.id == 9269:
\t\t\tr777_bard_has = true
\tcheck(r777_bard_has, "R777 卡池：吟游诗人的奖励池含 9269（进得去才玩得到）")

\t# ③ 随机源：200 抽 —— 每次 ≤3 张、职业互不相同、都不是自己家、只出盟友 / 技能
\tvar r777_probe := _new_engine([], 20, 20, -1, false)
\tvar r777_bad: Array = []
\tvar r777_cls_seen := {}
\tvar r777_kind_seen := {}
\tvar r777_full3 := 0
\tfor _i77 in range(200):
\t\tvar lst := r777_probe._roll_rainbow_cards()
\t\tif lst.size() > 3:
\t\t\tr777_bad.append("超量 %d" % lst.size())
\t\tif lst.size() == 3:
\t\t\tr777_full3 += 1
\t\tvar seen := {}
\t\tfor c2: CardData in lst:
\t\t\tif seen.has(c2.card_class):
\t\t\t\tr777_bad.append("同职业重复 %d" % c2.id)
\t\t\tseen[c2.card_class] = true
\t\t\tr777_cls_seen[c2.card_class] = true
\t\t\tr777_kind_seen[c2.kind] = true
\t\t\tif c2.card_class == PlayerClass.BARD or c2.card_class == "":
\t\t\t\tr777_bad.append("串职业 %d" % c2.id)
\t\t\tif c2.kind != "盟友" and c2.kind != "技能":
\t\t\t\tr777_bad.append("卡种 %s" % c2.kind)
\tcheck(r777_bad.is_empty(),
\t\t\t"R777 随机源：200 抽全是「不同其他职业的盟友 / 技能」（异常 %s）"
\t\t\t% str(r777_bad.slice(0, 5)))
\tcheck(r777_full3 == 200,
\t\t\t"R777 随机源：三个可见职业时每抽都给满 3 张（%d / 200）" % r777_full3)
\tcheck(r777_cls_seen.size() == 3,
\t\t\t"R777 随机源：三个职业都摇得到（本次 %s）" % str(r777_cls_seen.keys()))
\tcheck(r777_kind_seen.has("盟友") and r777_kind_seen.has("技能"),
\t\t\t"R777 随机源：盟友与技能卡都摇得到（本次 %s）" % str(r777_kind_seen.keys()))

\t# ④ 只有两个其他职业时给 2 张（不硬凑第 3 张，也不跨到隐藏职业）
\tRunState.player_class = PlayerClass.DRUID
\tvar r777_two := r777_probe._roll_rainbow_cards()
\tvar r777_two_bad := false
\tfor c3: CardData in r777_two:
\t\tif c3.card_class == PlayerClass.DRUID or c3.card_class == PlayerClass.BARD:
\t\t\tr777_two_bad = true
\tcheck(r777_two.size() == 2 and not r777_two_bad,
\t\t\t"R777 少职业：森林精魄视角只有 2 个其他职业 → 给 2 张（实得 %d）"
\t\t\t% r777_two.size())
\tRunState.player_class = PlayerClass.BARD

\t# ⑤ 打出：2 费照扣、3 张入手、各自费用本局 -1
\tvar r777_deck: Array[CardData] = []
\tr777_deck.append(r777_card)
\tvar r777_e := _new_engine(r777_deck, 20, 20, -1, false)
\tr777_e.start_game(1)
\tr777_e.state.energy = 5
\tvar r777_hand_before: int = r777_e.state.hand.size()
\tr777_e.use_spell(_find(r777_e.state.hand, 9269))
\tcheck(r777_e.state.energy == 3,
\t\t\t"R777 打出：2 费照扣（5 → %d）" % r777_e.state.energy)
\tcheck(r777_e.state.hand.size() == r777_hand_before + 2,
\t\t\t"R777 打出：打出 1 张、入手 3 张（%d → %d）"
\t\t\t% [r777_hand_before, r777_e.state.hand.size()])
\tvar r777_got: Array[CardData] = []
\tfor c4: CardData in r777_e.state.hand:
\t\tif r777_e.state.hand_cost_delta.has(c4):
\t\t\tr777_got.append(c4)
\tcheck(r777_got.size() == 3,
\t\t\t"R777 打出：3 张都记了手卡内减费（实得 %d）" % r777_got.size())
\tvar r777_cost_bad: Array = []
\tvar r777_got_cls := {}
\tfor c5: CardData in r777_got:
\t\tr777_got_cls[c5.card_class] = true
\t\tif r777_e.cost_of(c5) != maxi(0, c5.cost - 1):
\t\t\tr777_cost_bad.append("%s %d→%d" % [c5.card_name, c5.cost, r777_e.cost_of(c5)])
\t\tif c5.card_class == PlayerClass.BARD or c5.card_class == "":
\t\t\tr777_cost_bad.append("串职业 %s" % c5.card_name)
\t\tif c5.kind != "盟友" and c5.kind != "技能":
\t\t\tr777_cost_bad.append("卡种 %s" % c5.kind)
\tcheck(r777_cost_bad.is_empty(),
\t\t\t"R777 打出：3 张都是其他职业的盟友 / 技能，费用各 -1（异常 %s）"
\t\t\t% str(r777_cost_bad))
\tcheck(r777_got_cls.size() == 3,
\t\t\t"R777 打出：3 张来自 3 个不同职业（本次 %s）" % str(r777_got_cls.keys()))

\t# ⑥ 「本局」的成色：换回合仍然 -1（hand_cost_delta 不在 end_turn / _begin_turn 清空）
\tvar r777_probe_card: CardData = null
\tif not r777_got.is_empty():
\t\tr777_probe_card = r777_got[0]
\tvar r777_base_cost := -1
\tvar r777_after := -1
\tif r777_probe_card != null:
\t\tr777_base_cost = r777_probe_card.cost
\t\tr777_e.state.energy = 0
\t\tr777_e._begin_turn(GameEngine.SIDE_SELF)
\t\tr777_after = r777_e.cost_of(r777_probe_card)
\tcheck(r777_probe_card != null and r777_after == maxi(0, r777_base_cost - 1),
\t\t\t"R777 本局：新回合仍是 -1 费（卡面 %d → %d）" % [r777_base_cost, r777_after])

\t# ⑦ 可叠：同一张再吃一张彩虹诗 → 合计 -2（hand_cost_delta 是累加语义）
\tif r777_probe_card != null:
\t\tvar r777_prev := int(r777_e.state.hand_cost_delta.get(r777_probe_card, 0))
\t\tr777_e.state.hand_cost_delta[r777_probe_card] = r777_prev + 1
\t\tcheck(r777_e.cost_of(r777_probe_card) == maxi(0, r777_base_cost - 2),
\t\t\t\t"R777 叠加：同一张 -1 再 -1 → 合计 -2（%d）"
\t\t\t\t% r777_e.cost_of(r777_probe_card))

\t# ⑧ 离手即恢复原价（判据是「此刻还在手牌里」，与隐藏能源 / 小精灵同一条路）
\tif r777_probe_card != null:
\t\tr777_e.state.hand.erase(r777_probe_card)
\t\tcheck(r777_e.cost_of(r777_probe_card) == r777_base_cost,
\t\t\t\t"R777 离手：不在手牌里就恢复卡面费用（%d）"
\t\t\t\t% r777_e.cost_of(r777_probe_card))

\t# ⑨ 手牌满：3 张改投弃牌区（不蒸发、也不按 -1 记账生效）
\tvar r777_deck2: Array[CardData] = []
\tr777_deck2.append(r777_card)
\tvar r777_e2 := _new_engine(r777_deck2, 20, 20, -1, false)
\tr777_e2.start_game(1)
\tr777_e2.state.energy = 5
\tvar r777_fill := _card(19001, "占位", "技能", 1, 0, 0)
\tvar r777_guard := 0
\twhile not r777_e2.state.hand_full() and r777_guard < 24:
\t\tr777_e2.state.hand.append(r777_e2._new_own_card(r777_fill))
\t\tr777_guard += 1
\tvar r777_discard_before: int = r777_e2.state.discard.size()
\tvar r777_hand_full_n: int = r777_e2.state.hand.size()
\tr777_e2.use_spell(_find(r777_e2.state.hand, 9269))
\tcheck(r777_e2.state.hand.size() == r777_hand_full_n - 1
\t\t\tand r777_e2.state.discard.size() == r777_discard_before + 3,
\t\t\t"R777 满手：3 张进弃牌区、手牌只少了打出的那张（%d→%d / 弃 %d→%d）"
\t\t\t% [r777_hand_full_n, r777_e2.state.hand.size(),
\t\t\t\t\tr777_discard_before, r777_e2.state.discard.size()])

\t# ⑩ 三语：en / ja 都要真有译文（R702 / R718 都踩过「改了中文忘同步」）
\tvar r777_lang_bak: String = GameSettings.language
\tGameSettings.language = "en"
\tGameI18n.reset_cache()
\tvar r777_en: String = CardText.naturalize_card(r777_card)
\tGameSettings.language = "ja"
\tGameI18n.reset_cache()
\tvar r777_ja: String = CardText.naturalize_card(r777_card)
\tGameSettings.language = r777_lang_bak
\tGameI18n.reset_cache()
\tcheck(r777_en.find("Rainbow") >= 0 and r777_en.find("Ally") >= 0
\t\t\tand r777_en.find("费用") < 0 and r777_en.find("盟友") < 0,
\t\t\t"R777 译文：en 下卡名与效果都是英文（%s）" % r777_en.replace("\\n", " ").left(40))
\tcheck(r777_ja.find("虹の詩") >= 0 and r777_ja.find("味方") >= 0
\t\t\tand r777_ja.find("费用") < 0 and r777_ja.find("盟友") < 0,
\t\t\t"R777 译文：ja 下卡名与效果都是日文（%s）" % r777_ja.replace("\\n", " ").left(40))

\t# 收尾还原
\tRunState.relics = r777_sv_relics
\tRunState.spent_relics = r777_sv_spent
\tRunState.run_active = r777_sv_active
\tRunState.player_class = r777_sv_class


'''

FUNC = FUNC.replace("\n", "\r\n")
anchor = '# ================= R762：开始游戏'
sub(anchor, FUNC + anchor, "回归段插入")

assert s.count("\r\n") > 0 and "\n" not in s.replace("\r\n", "")
io.open(TE, "wb").write(s.encode("utf-8"))
print("[ok] test_engine.gd 已写入 R777 回归段 + 计数 330 / 252 / 吟游诗人 6 / R226 107")
