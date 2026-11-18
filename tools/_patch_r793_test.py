# -*- coding: utf-8 -*-
"""R793 测试：新增 _test_r793() + 更新总数 / 奖励池断言。"""
import io
import sys

P = 'E:/work/card_rogue/scripts/test_engine.gd'
s = io.open(P, encoding='utf-8', newline='').read()
CR = '\r\n'


def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        print('FAIL %s 锚点命中 %d 次' % (tag, s.count(old)))
        sys.exit(1)
    s = s.replace(old, new)


# ── ① 注册 ─────────────────────────────────────────────────────────
rep('\t_test_r792()' + CR, '\t_test_r792()' + CR + '\t_test_r793()' + CR, 'register')

# ── ② 奖励池分档断言 25/19 → 27/21 ─────────────────────────────────
rep(
    'check(r289_all.size() == 25 and r289_nor.size() == 19 and r289_leg.size() == 6,'
    + CR + CR + '\t\t\t"奖励分档：奖励池 25 件 = 一般 19 + 传奇 6（实际 %d / %d / %d）"',
    'check(r289_all.size() == 27 and r289_nor.size() == 21 and r289_leg.size() == 6,'
    + CR + CR + '\t\t\t"奖励分档：奖励池 27 件 = 一般 21 + 传奇 6（实际 %d / %d / %d）"',
    'tiers')

# ── ③ 道具总数 67 → 69 ─────────────────────────────────────────────
rep(
    'check(icon577_src_ok and icon577_repo.all_relics().size() == 67,'
    + CR + CR + '\t\t\t"R577b 保真锁：67 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072）")',
    'check(icon577_src_ok and icon577_repo.all_relics().size() == 69,'
    + CR + CR + '\t\t\t"R577b 保真锁：69 件道具的 id 都能在 relics.json 源文本里找到（R793 +刺墙 6073 / 应急装甲 6074）")',
    'total')

# ── ④ 新测试函数（追加到文件末尾）──────────────────────────────────
BODY = '''

func _test_r793() -> void:
	## R793（用户口径）：刺墙 6073（己方工事被攻击 → 攻击者受 5 伤）/
	## 应急装甲 6074（玩家 HP 每回合最多受 20 伤）。
	var r793_cards := CardRepo.load_json()
	var r793_sv_relics: Array[int] = RunState.relics.duplicate()
	var r793_repo := RelicRepo.load_json()

	# ① 数据层：两件在库、都进奖励池、都是一般档
	check(r793_repo.get_relic(6073) != null and r793_repo.get_relic(6074) != null,
			"R793 数据层：刺墙 6073 / 应急装甲 6074 都在库")
	check(r793_repo.reward_ids().has(6073) and r793_repo.reward_ids().has(6074),
			"R793 两件新道具都进奖励池")
	check(r793_repo.normal_reward_ids().has(6073) and r793_repo.normal_reward_ids().has(6074),
			"R793 两件都在「一般」档（normal_reward_ids 含）")

	# ② 刺墙：敌方普攻打我方工事 → 攻击者 -5
	# 木栅栏 8001 是 2 费 6 血工事；铁壁卫兵 1011 是 4 攻近战 —— 各打一下都活得下来，
	# 所以这里量的是「反伤有没有落地」，不是「谁先死」。
	var r793_sw_relics: Array[int] = [6073]
	RunState.relics = r793_sw_relics
	var r793_sw := _new_engine([], 40, 40)
	r793_sw.state.energy = 30
	r793_sw.state.hand.clear()
	r793_sw.state.hand.append(CardData.from_dict(r793_cards.get_card(8001).to_dict()))
	var r793_wall := r793_sw.play_from_hand(0, Vector2i(5, 2))
	var r793_foe := r793_sw.state.place(
			CardData.from_dict(r793_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	check(r793_wall != null and r793_wall.card.kind == "工事" and r793_foe != null,
			"R793 刺墙：工事与攻击者都就位")
	var r793_foe_hp0: int = r793_foe.health
	r793_sw.attack(Vector2i(4, 2), Vector2i(5, 2), GameEngine.SIDE_OPPONENT)
	check(r793_foe.health == r793_foe_hp0 - 5,
			"R793 刺墙：攻击工事 → 攻击者 -5（%d → %d）" % [r793_foe_hp0, r793_foe.health])

	# ③ 刺墙只认工事：同样的位置换成盟友，攻击者不掉血
	RunState.relics = r793_sw_relics
	var r793_sw2 := _new_engine([], 40, 40)
	r793_sw2.state.energy = 30
	r793_sw2.state.hand.clear()
	r793_sw2.state.hand.append(CardData.from_dict(r793_cards.get_card(9028).to_dict()))   # 龙裔 1 费 12 血
	var r793_ally := r793_sw2.play_from_hand(0, Vector2i(5, 2))
	var r793_foe2 := r793_sw2.state.place(
			CardData.from_dict(r793_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	var r793_foe2_hp0: int = r793_foe2.health
	r793_sw2.attack(Vector2i(4, 2), Vector2i(5, 2), GameEngine.SIDE_OPPONENT)
	check(r793_ally != null and r793_foe2.health == r793_foe2_hp0,
			"R793 刺墙：打的是盟友 → 不反伤（攻击者仍 %d）" % r793_foe2.health)

	# ④ 不持道具时工事被打也不反伤
	RunState.relics = []
	var r793_sw3 := _new_engine([], 40, 40)
	r793_sw3.state.energy = 30
	r793_sw3.state.hand.clear()
	r793_sw3.state.hand.append(CardData.from_dict(r793_cards.get_card(8001).to_dict()))
	r793_sw3.play_from_hand(0, Vector2i(5, 2))
	var r793_foe3 := r793_sw3.state.place(
			CardData.from_dict(r793_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	var r793_foe3_hp0: int = r793_foe3.health
	r793_sw3.attack(Vector2i(4, 2), Vector2i(5, 2), GameEngine.SIDE_OPPONENT)
	check(r793_foe3.health == r793_foe3_hp0,
			"R793 刺墙：没持道具 → 工事被打不反伤")

	# ⑤ 应急装甲：一回合 30 伤只落地 20，额度用满后全免，换回合恢复
	var r793_ar_relics: Array[int] = [6074]
	RunState.relics = r793_ar_relics
	var r793_ar := _new_engine([], 40, 40)
	r793_ar.turn_number = 7
	var r793_hp0: int = r793_ar.state.hp_self
	r793_ar._damage_player(GameEngine.SIDE_SELF, 30, "测试")
	check(r793_hp0 - r793_ar.state.hp_self == 20,
			"R793 应急装甲：一回合 30 伤封顶到 20（实掉 %d）" % (r793_hp0 - r793_ar.state.hp_self))
	var r793_hp1: int = r793_ar.state.hp_self
	r793_ar._damage_player(GameEngine.SIDE_SELF, 15, "测试")
	check(r793_ar.state.hp_self == r793_hp1,
			"R793 应急装甲：额度用满后这一下全免（HP 仍 %d）" % r793_ar.state.hp_self)
	var r793_hp2: int = r793_ar.state.hp_self
	r793_ar.turn_number = 8
	r793_ar._damage_player(GameEngine.SIDE_SELF, 15, "测试")
	check(r793_hp2 - r793_ar.state.hp_self == 15,
			"R793 应急装甲：换回合额度自动恢复（掉 %d）" % (r793_hp2 - r793_ar.state.hp_self))

	# ⑥ 不持道具时 30 伤全额落地（确认封顶没顺手改掉通用口径）
	RunState.relics = []
	var r793_plain := _new_engine([], 40, 40)
	r793_plain.turn_number = 3
	var r793_plain_hp0: int = r793_plain.state.hp_self
	r793_plain._damage_player(GameEngine.SIDE_SELF, 30, "测试")
	check(r793_plain_hp0 - r793_plain.state.hp_self == 30,
			"R793 应急装甲：没持道具时 30 伤全额（实掉 %d）" % (r793_plain_hp0 - r793_plain.state.hp_self))

	# ⑦ 源码守卫：封顶挂在 `_hp_damage_taken()`（玩家 HP 两条落地路的**共同上游**），
	#    不能挂 `_damage_player()` —— 那会漏掉 `attack_hp()` 的普攻直击。
	var r793_ge_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r793_ge_src.contains("_emergency_armor_cap(_relic_damage_taken(dmg))")
			and r793_ge_src.contains("_armor_turn_key = -1")
			and r793_ge_src.contains("RunState.has_relic(SPIKE_WALL_RELIC_ID)"),
			"R793 源码守卫：封顶挂在 _hp_damage_taken、额度在 start_game 重置、刺墙走道具判据")

	RunState.relics = r793_sv_relics
'''

if not s.endswith(CR):
    s += CR
s += BODY.replace('\n', CR)

io.open(P, 'w', encoding='utf-8', newline='').write(s)
b = open(P, 'rb').read()
print('test_engine.gd CRLF', b.count(b'\r\n'), 'LF-only', b.count(b'\n') - b.count(b'\r\n'))
print('OK')
