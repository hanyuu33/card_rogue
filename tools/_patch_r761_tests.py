# -*- coding: utf-8 -*-
"""R761 补丁 9/9：test_engine.gd —— ① 修正被新卡顶掉的三处数量断言；② 新增 _test_r761()。

口径来源（店长原话）：
  「这个职业目前不可见，不可选，卡牌不可在图鉴查到，不能被随机到，总之就是玩家不能感知到，
    只能我自己用指令打开能玩吟游诗人的特殊版本」
  「吟游诗人头像放到森林精魄头像正上方」

本补丁只改 test_engine.gd（CRLF）。全部 exact-replace + assert count==1。
"""
import io
import sys

P = "scripts/test_engine.gd"


def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)


raw = open(P, "rb").read()
# 行尾复核：整篇必须是纯 CRLF（否则说明文件被人改过行尾，先停下来看）
n_lf = raw.count(b"\n")
n_crlf = raw.count(b"\r\n")
if n_lf != n_crlf:
    fail("test_engine.gd 行尾不纯 CRLF（LF=%d CRLF=%d）" % (n_lf, n_crlf))

t = raw.decode("utf-8").replace("\r\n", "\n")


def rep(old, new, tag):
    global t
    n = t.count(old)
    if n != 1:
        fail("%s：锚点命中 %d 次（应为 1）\n锚点=%r" % (tag, n, old[:160]))
    t = t.replace(old, new, 1)
    print("  ok", tag)


# ── ① 图鉴总数 323 → 325 ───────────────────────────────────────────────
rep("check(repo.all_cards().size() == 323,",
    "check(repo.all_cards().size() == 325,", "all_cards 325")

rep('"图鉴 = 323 张（R758 +3：',
    '"图鉴 = 325 张（R761 +2：杜鹃 9263 / 招募 9264（吟游诗人 · 隐藏职业的初始卡，'
    'rarity 3 不进随机池）；R758 +3：',
    "图鉴总数文案")

# ── ② 玩家卡牌 245 → 247（敌人 78 不变）───────────────────────────────
rep("check(grp_player.size() == 245 and grp_enemy.size() == 78,",
    "check(grp_player.size() == 247 and grp_enemy.size() == 78,", "grp_player 247")

rep('"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 245 / 78（',
    '"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 247 / 78（R761 玩家 +2：'
    '杜鹃 9263 / 招募 9264（吟游诗人）；',
    "分组文案")

# ── ③ 角色分布：追加吟游诗人 2 张，并把「可选角色」判据放宽到全集 ──────
rep('\t\t\tif c.card_class != "" and not PlayerClass.ids().has(c.card_class):',
    '\t\t\t# R761：隐藏职业（吟游诗人）**不在** `ids()` 里 —— 这里要的是「全部有归属的卡\n'
    '\t\t\t# 都写了一个真职业」，所以走 `all_ids()`。用 `ids()` 会让 9263/9264 在这里假红，\n'
    '\t\t\t# 也会诱导后来的人「把它塞进 ids()」——那正好破了隐藏职业的第一条约束。\n'
    '\t\t\tif c.card_class != "" and not PlayerClass.all_ids().has(c.card_class):',
    "dr_cls 判据 all_ids")

rep('"角色系统：非敌方卡 class 都在可选角色内（或留空 = 通用卡）',
    '"角色系统：非敌方卡 class 都在角色全集内（可见三职业 + 隐藏职业；留空 = 通用卡）',
    "dr_cls 文案")

rep('\t\tand int(dr_cls_count.get(PlayerClass.MECH, 0)) == 75\n',
    '\t\tand int(dr_cls_count.get(PlayerClass.MECH, 0)) == 75\n'
    '\n'
    '\t\t\tand int(dr_cls_count.get(PlayerClass.BARD, 0)) == 2\n',
    "dr_cls BARD 2")

rep('（期望 78 / 66 / 75 / 78 / 公用 26，R758 敌人 +3',
    '（期望 78 / 66 / 75 / 78 / 吟游诗人 2 / 公用 26（R761 吟游诗人 +2：杜鹃 9263 / 招募 9264）；'
    'R758 敌人 +3',
    "dr_cls 文案 2")

# ── ④ 注册 _test_r761() ────────────────────────────────────────────────
rep("\t_test_r679()\n",
    "\t_test_r679()\n"
    "\n"
    "\t_test_r761()\n",
    "注册 _test_r761")

# ── ⑤ 追加 _test_r761() 到文件末尾 ────────────────────────────────────
TEST = r'''

# ================= R761：隐藏职业「吟游诗人」 =================
# 店长口径（原话）：
#   「这个职业目前不可见，不可选，卡牌不可在图鉴查到，不能被随机到，总之就是玩家不能感知到，
#    只能我自己用指令打开能玩吟游诗人的特殊版本」
#   「吟游诗人头像放到森林精魄头像正上方」
# 落地口径：三条约束各**只有一个判据口**，默认全部不含它 ——
#   界面：`PlayerClass.ids()`（可见三职业）/ `playable_ids()`（+开关）
#   卡池：`CardRepo.obtainable_cards()`（随机奖励 / 商店 / 事件 / 禁卡表全读它）
#   图鉴：`gallery_scene.gallery_visible()`（与版本无关，永远 false）
# 所以这组断言不是在测「某个界面藏了它」，而是测那三个口本身。
func _test_r761() -> void:
	var r761_gs = preload("res://scripts/gallery_scene.gd")
	var r761_repo := CardRepo.load_json()
	var r761_relics := RelicRepo.load_json()
	var r761_duck: CardData = r761_repo.get_card(9263)
	var r761_rec: CardData = r761_repo.get_card(9264)
	# 收尾要还原的两处全局（本函数会改道具表与「这局真在跑」标记）
	var r761_sv_relics: Array[int] = RunState.relics.duplicate()
	var r761_sv_spent: Array[int] = RunState.spent_relics.duplicate()
	var r761_sv_active: bool = RunState.run_active
	RunState.run_active = false   # 别把测试里打的牌写进玩家成就统计

	# ① 数据真在库（后面几条才谈得上）
	check(r761_duck != null and r761_rec != null
			and r761_duck.card_class == PlayerClass.BARD
			and r761_rec.card_class == PlayerClass.BARD,
			"R761 数据：杜鹃 9263 / 招募 9264 在库，归属吟游诗人")
	if r761_duck != null and r761_rec != null:
		check(r761_duck.kind == "盟友" and r761_duck.cost == 3 and r761_duck.power == 3
				and r761_duck.health == 8 and r761_duck.attack_range == 1
				and r761_duck.move_speed == 1,
				"R761 数据：杜鹃 = 3 费 3 力 8 血 · 程 1 速 1（与树人 8003 同规格）")
		check(r761_rec.kind == "技能" and r761_rec.cost == 0,
				"R761 数据：招募 = 0 费技能")
		check(r761_duck.rarity == 3 and r761_rec.rarity == 3,
				"R761 数据：两张都是 rarity 3（初始卡 → 天然不进奖励池）")

	# ② 默认关：不可见、不可选
	PlayerClass.set_bard_enabled(false)
	check(not PlayerClass.bard_enabled(),
			"R761 开关：默认关（没带 `-- --bard` 时玩家感知不到）")
	check(PlayerClass.ids() == ["森林精魄", "暗影刺客", "机械之心"]
			and not PlayerClass.ids().has(PlayerClass.BARD),
			"R761 隐藏：可见三职业不含吟游诗人（选人界面 / 图鉴下拉 / 随机摇人都读它）")
	check(not PlayerClass.playable_ids().has(PlayerClass.BARD),
			"R761 隐藏：连「此刻真能开局选到」也不含它")
	check(PlayerClass.hidden_ids() == [PlayerClass.BARD]
			and PlayerClass.all_ids().has(PlayerClass.BARD)
			and PlayerClass.is_hidden_class(PlayerClass.BARD)
			and not PlayerClass.is_hidden_class(PlayerClass.DRUID),
			"R761 隐藏：全集 / 隐藏集 / 判据口自洽（隐藏集里只有它）")

	# ③ 打开「特殊版本」：只多出「可玩」这一层，ids() 纹丝不动
	PlayerClass.set_bard_enabled(true)
	check(PlayerClass.bard_enabled()
			and PlayerClass.playable_ids().has(PlayerClass.BARD)
			and PlayerClass.ids().size() == 3,
			"R761 开关：打开后 playable_ids 多一个吟游诗人，ids() 仍只有三个")
	PlayerClass.set_bard_enabled(false)
	check(not PlayerClass.bard_enabled()
			and not PlayerClass.playable_ids().has(PlayerClass.BARD),
			"R761 开关：关回去立刻消失（同一份状态，没有第二个开关）")

	# ④ 不能被随机到：卡池两个口径都不含隐藏职业卡
	var r761_pool_bad: Array = []
	for c: CardData in r761_repo.obtainable_cards():
		if PlayerClass.is_hidden_class(c.card_class):
			r761_pool_bad.append(c.id)
	check(r761_pool_bad.is_empty(),
			"R761 卡池：可获得池默认筛掉隐藏职业卡（异常 %s）" % str(r761_pool_bad))
	var r761_reward_bad: Array = []
	for c2: CardData in r761_repo.reward_pool():
		if PlayerClass.is_hidden_class(c2.card_class):
			r761_reward_bad.append(c2.id)
	check(r761_reward_bad.is_empty(),
			"R761 卡池：奖励池同样不含（异常 %s）" % str(r761_reward_bad))
	var r761_hidden_in_all: Array = []
	for c3: CardData in r761_repo.obtainable_cards(true):
		if PlayerClass.is_hidden_class(c3.card_class):
			r761_hidden_in_all.append(c3.id)
	check(r761_hidden_in_all.is_empty(),
			"R761 卡池：连 include_hidden 也进不去 —— 初始卡 rarity 3 是第二道闸")

	# ⑤ 图鉴查不到（发布 / 测试两种模式都 false，与「见过没见过」无关）
	check(not r761_gs.gallery_visible(r761_duck, false)
			and not r761_gs.gallery_visible(r761_duck, true)
			and not r761_gs.gallery_visible(r761_rec, false)
			and not r761_gs.gallery_visible(r761_rec, true),
			"R761 图鉴：两张卡在发布版 / 测试版都不可见（连占位都不给）")
	check(r761_gs.gallery_visible(r761_repo.get_card(8003), false),
			"R761 图鉴：判据本身没写死 false（树人 8003 照常可见）")

	# ⑥ 初始卡组（13 张）与随角色发放的「诗」6069
	var r761_deck := r761_repo.starter_deck(PlayerClass.BARD)
	var r761_cnt := {}
	for c4: CardData in r761_deck:
		r761_cnt[c4.id] = int(r761_cnt.get(c4.id, 0)) + 1
	check(r761_deck.size() == 13
			and int(r761_cnt.get(8001, 0)) == 5 and int(r761_cnt.get(8002, 0)) == 5
			and int(r761_cnt.get(9263, 0)) == 2 and int(r761_cnt.get(9264, 0)) == 1,
			"R761 卡组：13 张 = 木栅栏×5 + 攻击×5 + 杜鹃×2 + 招募×1（实际 %d 张）"
			% r761_deck.size())
	check(PlayerClass.relic_of(PlayerClass.BARD) == GameEngine.POEM_RELIC_ID
			and r761_relics.get_relic(6069) != null
			and str(r761_relics.get_relic(6069).relic_name) == "诗"
			and r761_relics.get_relic(6069).source == RelicData.SRC_CLASS,
			"R761 道具：「诗」6069 是角色赠品（source = 角色），随吟游诗人发放")
	check(not r761_relics.reward_ids().has(6069),
			"R761 道具：6069 不在奖励池（角色赠品走显式 id，不摇）")
	check(PlayerClass.base_hp_of(PlayerClass.BARD) == PlayerClass.BASE_HP + 14,
			"R761 数值：初始最大生命 = 50 + 14 = 64（比刺客厚、比森林精魄薄）")

	# ⑦ 诗 ②：别职业盟友力量 +2（杜鹃不吃；赋值不累加）
	var r761_ally_other := _card(19801, "借来的狼", "盟友", 0, 1, 5)
	r761_ally_other.card_class = PlayerClass.DRUID
	var r761_ally_own := _card(19802, "杜鹃", "盟友", 0, 1, 5)
	r761_ally_own.card_class = PlayerClass.BARD
	RunState.relics = [GameEngine.POEM_RELIC_ID]
	RunState.spent_relics = []
	var r761_d1: Array[CardData] = []
	r761_d1.append(r761_ally_other)
	r761_d1.append(r761_ally_own)
	var r761_atk_e := _new_engine(r761_d1, 20, 20, -1, false)
	r761_atk_e.start_game(1)
	r761_atk_e.state.energy = 9
	var r761_p_other := r761_atk_e.play_from_hand(_find(r761_atk_e.state.hand, 19801),
			Vector2i(4, 1))
	var r761_p_own := r761_atk_e.play_from_hand(_find(r761_atk_e.state.hand, 19802),
			Vector2i(3, 1))
	check(r761_p_other != null and r761_p_other.poem_atk == GameEngine.POEM_ATK
			and r761_p_other.effective_power() == 1 + GameEngine.POEM_ATK,
			"R761 诗：别职业盟友落地即 +2 力量（1 → %d）"
			% (1 + GameEngine.POEM_ATK))
	check(r761_p_own != null and r761_p_own.poem_atk == 0,
			"R761 诗：杜鹃不吃自己道具的 +2（判据 = 不是吟游诗人自己的盟友）")
	if r761_p_other != null:
		r761_atk_e._sync_poem()
		r761_atk_e._sync_poem()
		check(r761_p_other.poem_atk == GameEngine.POEM_ATK,
				"R761 诗：重复对齐仍是 +2（赋值，不叠加）")
	RunState.relics = []
	r761_atk_e._sync_poem()
	check(r761_p_other.poem_atk == 0,
			"R761 诗：丢了道具立刻归零（同一处对齐，不留残值）")

	# ⑧ 诗 ①：每回合第一次用「别职业盟友」回 1 费（同回合第二次不回）
	RunState.relics = [GameEngine.POEM_RELIC_ID]
	RunState.spent_relics = []
	var r761_ally_other2 := _card(19803, "借来的豹", "盟友", 0, 1, 5)
	r761_ally_other2.card_class = PlayerClass.ROGUE
	var r761_own2 := _card(19804, "杜鹃二", "盟友", 0, 1, 5)
	r761_own2.card_class = PlayerClass.BARD
	var r761_d2: Array[CardData] = []
	r761_d2.append(r761_own2)
	r761_d2.append(r761_ally_other)
	r761_d2.append(r761_ally_other2)
	var r761_fee_e := _new_engine(r761_d2, 20, 20, -1, false)
	r761_fee_e.start_game(1)
	r761_fee_e.state.energy = 5
	r761_fee_e.play_from_hand(_find(r761_fee_e.state.hand, 19804), Vector2i(3, 1))
	check(r761_fee_e.state.energy == 5 and not r761_fee_e._poem_used,
			"R761 诗：先打自己的杜鹃 → 不回费，但「本回合第一次」的额度还在")
	r761_fee_e.play_from_hand(_find(r761_fee_e.state.hand, 19801), Vector2i(4, 1))
	check(r761_fee_e.state.energy == 6 and r761_fee_e._poem_used,
			"R761 诗：本回合第一张别职业盟友 → 回复 1 费（5 → 6）")
	r761_fee_e.play_from_hand(_find(r761_fee_e.state.hand, 19803), Vector2i(5, 1))
	check(r761_fee_e.state.energy == 6,
			"R761 诗：同回合第二张不再回费（每回合只给一次）")

	# ⑨ 招募：三选一，森林精魄 / 暗影刺客 / 机械之心各一张盟友
	RunState.relics = []
	var r761_d3: Array[CardData] = []
	r761_d3.append(r761_rec)
	var r761_re := _new_engine(r761_d3, 20, 20, -1, false)
	r761_re.start_game(1)
	r761_re.state.energy = 3
	var r761_cast := r761_re.use_spell(_find(r761_re.state.hand, 9264))
	check(r761_re.recruit_pending and r761_re.recruit_cards().size() == 3,
			"R761 招募：打出 9264 → 开面板，候选 3 张（引擎返回：%s）" % str(r761_cast))
	var r761_rc: Array = r761_re.recruit_cards()
	var r761_cls: Array = []
	for rc: CardData in r761_rc:
		if rc.kind == "盟友" and not r761_cls.has(rc.card_class):
			r761_cls.append(rc.card_class)
	check(r761_cls.size() == 3 and r761_cls.has(PlayerClass.DRUID)
			and r761_cls.has(PlayerClass.ROGUE) and r761_cls.has(PlayerClass.MECH),
			"R761 招募：三个候选正好是三个职业各一张盟友（%s）"
			% "、".join(r761_rc.map(func(rc2: CardData) -> String: return rc2.card_name)))
	var r761_pick_name: String = ""
	if r761_rc.size() > 0:
		r761_pick_name = (r761_rc[0] as CardData).card_name
	check(r761_re.recruit_pick(0) and not r761_re.recruit_pending
			and r761_re.recruit_cards().is_empty(),
			"R761 招募：选第一张 → 收口（面板关、候选清空）")
	var r761_got := false
	for c5: CardData in r761_re.state.hand:
		if c5.card_name == r761_pick_name:
			r761_got = true
	check(r761_got, "R761 招募：「%s」真的进了手卡" % r761_pick_name)
	# 放弃分支：候选摇出来了但玩家不选 → 什么都不发生（技能已付过费）
	var r761_d4: Array[CardData] = []
	r761_d4.append(r761_rec)
	var r761_re2 := _new_engine(r761_d4, 20, 20, -1, false)
	r761_re2.start_game(1)
	r761_re2.state.energy = 3
	r761_re2.use_spell(_find(r761_re2.state.hand, 9264))
	var r761_hand_before: int = r761_re2.state.hand.size()
	r761_re2.recruit_cancel()
	check(not r761_re2.recruit_pending and r761_re2.recruit_cards().is_empty()
			and r761_re2.state.hand.size() == r761_hand_before,
			"R761 招募：放弃 → 面板关、手牌不变（技能费不退还）")

	# ⑩ 界面接线（源码守卫：这几处删掉 = 面板永远不弹，功能测试看不出来）
	var r761_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check_src(r761_bs.contains("if engine.recruit_pending:")
			and r761_bs.contains("return \"recruit\"")
			and r761_bs.contains("\t\t\"recruit\":")
			and r761_bs.contains("_ensure_pick_visible(\"recruit\")"),
			"R761 接线：战斗场景认领 recruit（弹面板 / 建配置 / 结算 / 结束回合前拦一下）")
	var r761_cps := FileAccess.get_file_as_string("res://scripts/class_pick_scene.gd")
	check_src(r761_cps.contains("func _bard_rect() -> Rect2:")
			and r761_cps.contains("var r := _av_rect(0)")
			and r761_cps.contains("return Rect2(r.position.x, r.position.y - AV - 56.0, AV, AV)"),
			"R761 界面：吟游诗人槽位 = 森林精魄头像正上方（同 x、同尺寸）")
	check_src(r761_cps.contains("func _draw_bard_slot() -> void:")
			and r761_cps.contains("if not PlayerClass.bard_enabled():"),
			"R761 界面：槽位受开关控制（默认版本一个像素都不画）")

	# 收尾还原
	PlayerClass.set_bard_enabled(false)
	RunState.relics = r761_sv_relics
	RunState.spent_relics = r761_sv_spent
	RunState.run_active = r761_sv_active
'''

t = t.rstrip("\n") + "\n" + TEST.lstrip("\n")
if not t.endswith("\n"):
    t += "\n"

out = t.replace("\n", "\r\n").encode("utf-8")
open(P, "wb").write(out)
print("test_engine.gd OK  (%d bytes)" % len(out))
