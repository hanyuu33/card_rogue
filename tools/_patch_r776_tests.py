# -*- coding: utf-8 -*-
"""R776 测试补丁：激励乐章 9267 / 管风琴 9268 的断言 + 计数同步。

test_engine.gd 是 CRLF。
"""
import io

P = "scripts/test_engine.gd"
s = io.open(P, "rb").read().decode("utf-8")


def rep(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s 命中 %d 次" % (tag, n)
    s = s.replace(old, new)
    print("OK", tag)


# ── ① 计数同步 ───────────────────────────────────────────
rep(
    "check(repo.all_cards().size() == 327,",
    "check(repo.all_cards().size() == 329,",
    "图鉴总数 327→329",
)
rep(
    '"图鉴 = 327 张（R773 +1：呼唤 9266',
    '"图鉴 = 329 张（R776 +2：激励乐章 9267 / 管风琴 9268（吟游诗人 · 1 费普通技能 / 4 费史诗工事）；'
    "R773 +1：呼唤 9266",
    "图鉴说明文案",
)
rep(
    "check(grp_player.size() == 249 and grp_enemy.size() == 78,",
    "check(grp_player.size() == 251 and grp_enemy.size() == 78,",
    "玩家卡数 249→251",
)
rep(
    "（期望 249 / 78（R773 玩家 +1：呼唤 9266",
    "（期望 251 / 78（R776 玩家 +2：激励乐章 9267 / 管风琴 9268；R773 玩家 +1：呼唤 9266",
    "玩家卡文案 249→251",
)
rep(
    "and int(dr_cls_count.get(PlayerClass.BARD, 0)) == 3",
    "and int(dr_cls_count.get(PlayerClass.BARD, 0)) == 5",
    "吟游诗人 3→5",
)
rep(
    "吟游诗人 3 / 公用 27（R773 吟游诗人 +1：呼唤 9266",
    "吟游诗人 5 / 公用 27（R776 吟游诗人 +2：激励乐章 9267 / 管风琴 9268；R773 吟游诗人 +1：呼唤 9266",
    "角色系统说明文案",
)
rep(
    "check(r226_skills == 105 and r226_dmg == 42",
    "check(r226_skills == 106 and r226_dmg == 42",
    "R226 技能 105→106",
)

# ── ② 注册 ──────────────────────────────────────────────
rep(
    "\t_test_r773()\r\n",
    "\t_test_r773()\r\n\t_test_r776()\r\n",
    "注册 _test_r776",
)

# ── ③ 追加函数体 ─────────────────────────────────────────
BODY = '''\r
\r
# ================= R776：吟游诗人「激励乐章」9267 / 「管风琴」9268 =================\r
func _test_r776() -> void:\r
\tvar r776_repo := CardRepo.load_json()\r
\tvar r776_sv_class: String = RunState.player_class\r
\tvar r776_sv_active: bool = RunState.run_active\r
\tvar r776_sv_relics: Array[int] = RunState.relics.duplicate()\r
\tvar r776_sv_spent: Array[int] = RunState.spent_relics.duplicate()\r
\tRunState.run_active = false   # 测试里打的牌不许写进玩家成就统计\r
\t# 两张都是吟游诗人卡，「其他职业」判据读 `RunState.player_class` → 整段钉在这个身份上。\r
\tRunState.player_class = PlayerClass.BARD\r
\tRunState.relics = []\r
\tRunState.spent_relics = []\r
\r
\tvar r776_anthem: CardData = r776_repo.get_card(9267)\r
\tvar r776_organ: CardData = r776_repo.get_card(9268)\r
\t# ① 数据\r
\tcheck(r776_anthem != null and r776_anthem.card_name == "激励乐章"\r
\t\t\tand r776_anthem.kind == "技能" and r776_anthem.cost == 1\r
\t\t\tand r776_anthem.rarity == 0 and r776_anthem.card_class == PlayerClass.BARD\r
\t\t\tand r776_anthem.target_mode == "none",\r
\t\t\t"R776 数据：激励乐章 9267 = 吟游诗人 1 费普通技能（无目标）")\r
\tcheck(r776_organ != null and r776_organ.card_name == "管风琴"\r
\t\t\tand r776_organ.kind == "工事" and r776_organ.cost == 4\r
\t\t\tand r776_organ.power == 0 and r776_organ.attack_range == 7\r
\t\t\tand r776_organ.health == 19 and r776_organ.rarity == 2\r
\t\t\tand r776_organ.card_class == PlayerClass.BARD\r
\t\t\tand r776_organ.traits.has("工事") and r776_organ.traits.has("管风琴"),\r
\t\t\t"R776 数据：管风琴 9268 = 吟游诗人 4 费史诗工事（0 力量 / 射程 7 / 19 生命）")\r
\tif r776_anthem == null or r776_organ == null:\r
\t\tRunState.player_class = r776_sv_class\r
\t\tRunState.relics = r776_sv_relics\r
\t\tRunState.spent_relics = r776_sv_spent\r
\t\tRunState.run_active = r776_sv_active\r
\t\treturn\r
\tcheck(r776_anthem.color == "水风" and r776_organ.color == "水风",\r
\t\t\t"R776 数据：两张都是水风（与杜鹃 / 招募 / 呼唤同族）")\r
\t# 射程 7 是「0 攻也能攻击」的前提：0 攻程才不能攻击，所以它必须真有射程。\r
\tcheck(r776_organ.attack_range > 0 and r776_organ.power == 0,\r
\t\t\t"R776 数据：0 力量但有射程 —— 「攻击时」才触发得了（0 攻程不能攻击）")\r
\r
\t# ② 隐藏职业口径不因稀有度松动\r
\tvar r776_gs = preload("res://scripts/gallery_scene.gd")\r
\tcheck(not r776_gs.gallery_visible(r776_anthem, false)\r
\t\t\tand not r776_gs.gallery_visible(r776_anthem, true)\r
\t\t\tand not r776_gs.gallery_visible(r776_organ, false)\r
\t\t\tand not r776_gs.gallery_visible(r776_organ, true),\r
\t\t\t"R776 隐藏：两张都不进图鉴（判据在职业，不在稀有度）")\r
\tvar r776_pool_hit: Array = []\r
\tfor c0: CardData in r776_repo.reward_pool_for(PlayerClass.BARD):\r
\t\tif c0.id == 9267 or c0.id == 9268:\r
\t\t\tr776_pool_hit.append(c0.id)\r
\tcheck(r776_pool_hit.size() == 2,\r
\t\t\t"R776 卡池：吟游诗人的奖励池里两张都在（进得去才玩得到，实际 %s）"\r
\t\t\t% str(r776_pool_hit))\r
\r
\t# ③ 激励乐章：本回合力量分层\r
\tvar r776_d1: Array[CardData] = []\r
\tr776_d1.append(CardData.from_dict(r776_anthem.to_dict()))\r
\tvar r776_e1 := _new_engine(r776_d1, 20, 20, -1, false)\r
\tr776_e1.start_game(1)\r
\tr776_e1.state.energy = 5\r
\tvar r776_own := _card(1101, "自家盟友", "盟友", 1, 2, 10)\r
\tr776_own.card_class = PlayerClass.BARD\r
\tvar r776_other := _card(1102, "他家盟友", "盟友", 1, 3, 10)   # 默认 card_class = 森林精魄\r
\tvar r776_fort := _card(1103, "自家工事", "工事", 1, 0, 5)\r
\tvar r776_p_own := r776_e1.state.place(r776_own, Vector2i(4, 0))\r
\tvar r776_p_other := r776_e1.state.place(r776_other, Vector2i(4, 1))\r
\tvar r776_p_fort := r776_e1.state.place(r776_fort, Vector2i(4, 2))\r
\tvar r776_pow_own: int = r776_p_own.effective_power()\r
\tvar r776_pow_other: int = r776_p_other.effective_power()\r
\tvar r776_pow_fort: int = r776_p_fort.effective_power()\r
\tcheck(r776_e1._other_class_card(r776_other)\r
\t\t\tand not r776_e1._other_class_card(r776_own),\r
\t\t\t"R776 判据：默认职业盟友算「其他职业」，钉成吟游诗人的那张不算")\r
\tr776_e1.use_spell(_find(r776_e1.state.hand, 9267))\r
\tcheck(r776_p_own.effective_power() == r776_pow_own + 4,\r
\t\t\t"R776 激励乐章：同职业盟友本回合力量 +4（%d → %d）"\r
\t\t\t% [r776_pow_own, r776_p_own.effective_power()])\r
\tcheck(r776_p_other.effective_power() == r776_pow_other + 6,\r
\t\t\t"R776 激励乐章：原本职业非自己的盟友改为 +6（%d → %d）"\r
\t\t\t% [r776_pow_other, r776_p_other.effective_power()])\r
\tcheck(r776_p_fort.effective_power() == r776_pow_fort,\r
\t\t\t"R776 激励乐章：工事不是盟友，不吃这份力量")\r
\tcheck(r776_p_own.atk_buff_turn == 4 and r776_p_other.atk_buff_turn == 6,\r
\t\t\t"R776 激励乐章：记在 atk_buff_turn（本回合那一层），不是持续 buff")\r
\r
\t# ④ 回合结束 → 清零（「本回合」不是「本局」）\r
\tr776_e1.end_turn()\r
\tcheck(r776_p_own.effective_power() == r776_pow_own\r
\t\t\tand r776_p_other.effective_power() == r776_pow_other,\r
\t\t\t"R776 激励乐章：回合结束清零（%d / %d）"\r
\t\t\t% [r776_p_own.effective_power(), r776_p_other.effective_power()])\r
\r
\t# ⑤ 空场：照常吃费，不炸、不开空面板\r
\tvar r776_d2: Array[CardData] = []\r
\tr776_d2.append(CardData.from_dict(r776_anthem.to_dict()))\r
\tvar r776_e2 := _new_engine(r776_d2, 20, 20, -1, false)\r
\tr776_e2.start_game(1)\r
\tr776_e2.state.energy = 3\r
\tvar r776_res: String = r776_e2.use_spell(_find(r776_e2.state.hand, 9267))\r
\tcheck(r776_e2.state.energy == 2 and r776_res.contains("没有盟友"),\r
\t\t\t"R776 激励乐章：场上没盟友 → 照常扣 1 费并明说（%s）" % r776_res)\r
\r
\t# ⑥ 管风琴：攻击时取一张技能卡入手，且只有它本回合 -1 费\r
\tvar r776_d3: Array[CardData] = []\r
\tfor i3 in 10:\r
\t\tr776_d3.append(_card(1200 + i3, "测试技能%d" % i3, "技能", 1, 0, 0))\r
\tvar r776_e3 := _new_engine(r776_d3, 20, 20, -1, false)\r
\tr776_e3.start_game(1)\r
\tr776_e3.state.energy = 5\r
\tvar r776_org_card := CardData.from_dict(r776_organ.to_dict())\r
\tvar r776_org_p := r776_e3.state.place(r776_org_card, Vector2i(4, 1))\r
\tvar r776_foe_p := r776_e3.state.place(_card(1301, "木桩", "盟友", 1, 0, 60),\r
\t\t\tVector2i(1, 1), GameEngine.SIDE_OPPONENT)\r
\tcheck(r776_org_p != null and r776_foe_p != null and r776_foe_p.health == 60,\r
\t\t\t"R776 布场：管风琴在 (4,1)，木桩在 (1,1)（3 格，射程 7 够得着）")\r
\tvar r776_hand_before: int = r776_e3.state.hand.size()\r
\tr776_e3.attack(Vector2i(4, 1), Vector2i(1, 1))\r
\tcheck(r776_e3.state.hand.size() == r776_hand_before + 1,\r
\t\t\t"R776 管风琴：攻击时从卡组取一张技能卡入手（%d → %d）"\r
\t\t\t% [r776_hand_before, r776_e3.state.hand.size()])\r
\tvar r776_fetched: CardData = null\r
\tfor c1: CardData in r776_e3.state.hand:\r
\t\tif r776_e3.state.turn_card_discount.has(c1):\r
\t\t\tr776_fetched = c1\r
\tcheck(r776_fetched != null and r776_fetched.kind == "技能",\r
\t\t\t"R776 管风琴：取到的是一张技能卡（%s）"\r
\t\t\t% (r776_fetched.card_name if r776_fetched != null else "无"))\r
\tif r776_fetched != null:\r
\t\tcheck(r776_e3.cost_of(r776_fetched) == maxi(0, r776_fetched.cost - 1),\r
\t\t\t\t"R776 管风琴：该卡本回合费用 -1（%d → %d）"\r
\t\t\t\t% [r776_fetched.cost, r776_e3.cost_of(r776_fetched)])\r
\r
\t# ⑦ 每用一张技能卡 → 所有敌人 3 伤\r
\tvar r776_hp1: int = r776_foe_p.health\r
\tr776_e3.state.energy = 9\r
\tvar r776_sk1: int = -1\r
\tfor i4 in r776_e3.state.hand.size():\r
\t\tif r776_e3.state.hand[i4].kind == "技能" and r776_e3.state.hand[i4] != r776_fetched:\r
\t\t\tr776_sk1 = i4\r
\t\t\tbreak\r
\tr776_e3.use_spell(r776_sk1)\r
\tcheck(r776_foe_p.health == r776_hp1 - 3,\r
\t\t\t"R776 管风琴：用一张技能卡 → 敌人 -3（%d → %d）"\r
\t\t\t% [r776_hp1, r776_foe_p.health])\r
\r
\t# ⑧ 打盟友卡不触发（只认技能卡）\r
\tvar r776_hp2: int = r776_foe_p.health\r
\tr776_e3.state.energy = 9\r
\tr776_e3.state.hand.append(_card(1302, "手卡盟友", "盟友", 1, 1, 8))\r
\tr776_e3.play_from_hand(r776_e3.state.hand.size() - 1, Vector2i(4, 0))\r
\tcheck(r776_foe_p.health == r776_hp2,\r
\t\t\t"R776 管风琴：打出盟友卡不触发（%d 不变）" % r776_hp2)\r
\r
\t# ⑨ 场上两台 → 每张技能各结算一份（3 × 2）\r
\tr776_e3.state.place(CardData.from_dict(r776_organ.to_dict()), Vector2i(4, 2))\r
\tvar r776_hp3: int = r776_foe_p.health\r
\tr776_e3.state.energy = 9\r
\tvar r776_sk2: int = -1\r
\tfor i5 in r776_e3.state.hand.size():\r
\t\tif r776_e3.state.hand[i5].kind == "技能":\r
\t\t\tr776_sk2 = i5\r
\t\t\tbreak\r
\tr776_e3.use_spell(r776_sk2)\r
\tcheck(r776_foe_p.health == r776_hp3 - 6,\r
\t\t\t"R776 管风琴：两台各结算一份（%d → %d，3×2）"\r
\t\t\t% [r776_hp3, r776_foe_p.health])\r
\r
\t# ⑩ 离场即失效（结构体被打掉就没有这个被动）\r
\tvar r776_hp4: int = r776_foe_p.health\r
\tr776_e3.state.board.erase(Vector2i(4, 1))\r
\tr776_e3.state.board.erase(Vector2i(4, 2))\r
\tr776_e3.state.energy = 9\r
\tvar r776_sk3: int = -1\r
\tfor i6 in r776_e3.state.hand.size():\r
\t\tif r776_e3.state.hand[i6].kind == "技能":\r
\t\t\tr776_sk3 = i6\r
\t\t\tbreak\r
\tif r776_sk3 >= 0:\r
\t\tr776_e3.use_spell(r776_sk3)\r
\tcheck(r776_foe_p.health == r776_hp4,\r
\t\t\t"R776 管风琴：离场后不再触发（%d 不变）" % r776_hp4)\r
\r
\t# ⑪ 三语：en / ja 都要真有译文（判据读显示层，不查 json 有没有键）\r
\tvar r776_lang_bak: String = GameSettings.language\r
\tGameSettings.language = "en"\r
\tGameI18n.reset_cache()\r
\tvar r776_en_a: String = CardText.naturalize_card(r776_anthem)\r
\tvar r776_en_o: String = CardText.naturalize_card(r776_organ)\r
\tGameSettings.language = "ja"\r
\tGameI18n.reset_cache()\r
\tvar r776_ja_a: String = CardText.naturalize_card(r776_anthem)\r
\tvar r776_ja_o: String = CardText.naturalize_card(r776_organ)\r
\tGameSettings.language = r776_lang_bak\r
\tGameI18n.reset_cache()\r
\tcheck(r776_en_a.find("Power") >= 0 and r776_en_a.find("力量") < 0,\r
\t\t\t"R776 译文：激励乐章 en（%s）" % r776_en_a.replace("\\n", " ").left(40))\r
\tcheck(r776_en_o.find("Skill") >= 0 and r776_en_o.find("攻击时") < 0,\r
\t\t\t"R776 译文：管风琴 en（%s）" % r776_en_o.replace("\\n", " ").left(40))\r
\tcheck(r776_ja_a.find("ターン") >= 0 and r776_ja_a.find("力量") < 0,\r
\t\t\t"R776 译文：激励乐章 ja（%s）" % r776_ja_a.replace("\\n", " ").left(40))\r
\tcheck(r776_ja_o.find("スキル") >= 0 and r776_ja_o.find("技能") < 0,\r
\t\t\t"R776 译文：管风琴 ja（%s）" % r776_ja_o.replace("\\n", " ").left(40))\r
\r
\t# 收尾还原\r
\tRunState.relics = r776_sv_relics\r
\tRunState.spent_relics = r776_sv_spent\r
\tRunState.run_active = r776_sv_active\r
\tRunState.player_class = r776_sv_class\r
'''
# 只把行尾的 \r 换成 \r\n（BODY 里用单独 \r 标记换行，避免与真正内容混淆）
BODY = BODY.replace("\r\n", "\r").replace("\r", "\r\n")

assert s.endswith("\r\n") or s.endswith("\n")
if s.endswith("\r\n"):
    s = s + BODY
else:
    s = s + BODY

io.open(P, "wb").write(s.encode("utf-8"))
print("测试写入完成")
