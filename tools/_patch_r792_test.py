# -*- coding: utf-8 -*-
"""R792：追加测试段（test_engine.gd 末尾）+ 把道具总数断言 64 → 67。"""
import io
import sys

ROOT = 'E:/work/card_rogue/'
P = ROOT + 'scripts/test_engine.gd'
s = io.open(P, encoding='utf-8', newline='').read()

# ── 1. 道具总数 64 → 67 ─────────────────────────────────────────────
old_cnt = 'all_relics().size() == 64'
new_cnt = 'all_relics().size() == 67'
if s.count(old_cnt) != 1:
    print('FAIL 64 件断言命中 %d 次' % s.count(old_cnt))
    sys.exit(1)
s = s.replace(old_cnt, new_cnt)

old_msg = '"R577b 保真锁：64 件道具的 id 都能在 relics.json 源文本里找到（R761 +诗 6069）"'
new_msg = '"R577b 保真锁：67 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072）"'
if s.count(old_msg) != 1:
    print('FAIL 保真锁文案命中 %d 次' % s.count(old_msg))
    sys.exit(1)
s = s.replace(old_msg, new_msg)

# 注释里的「64 件道具逐件都有图标」也更新
s = s.replace(
    '	# ① 数据层：64 件道具逐件都有图标（R743 烤肉改成工具 → 61 件；R745 加回工具箱 6068；R761 加吟游诗人赠品「诗」6069）。',
    '	# ① 数据层：67 件道具逐件都有图标（R743 烤肉改成工具 → 61 件；R745 加回工具箱 6068；R761 加吟游诗人赠品「诗」6069；R792 加板甲 / 兵 / 墙砖）。',
    1)

# ── 2. 末尾追加 R792 段 ────────────────────────────────────────────
BLOCK = r'''
	# ================= R792：板甲 / 兵 / 墙砖 + 猴爪进池 + 第三层事件 ==============
	# ① 数据层：三件在库、都进奖励池；猴爪 6066 不再是「标着奖励却摇不到」的孤儿道具。

	var r792_sv_relics := RunState.relics.duplicate()

	var r792_repo := RelicRepo.load_json()

	check(r792_repo.get_relic(6070) != null and r792_repo.get_relic(6071) != null and r792_repo.get_relic(6072) != null,
			"R792 数据层：板甲 6070 / 兵 6071 / 墙砖 6072 三件都在库")

	check(r792_repo.get_relic(6070).tier == "一般" and r792_repo.get_relic(6071).tier == "一般" and r792_repo.get_relic(6072).tier == "一般",
			"R792 数据层：三件新道具都是一般档")

	check(r792_repo.reward_ids().has(6066),
			"R792 猴爪 6066 已进奖励池（此前标「奖励」却永远摇不到）")

	check(r792_repo.reward_ids().has(6070) and r792_repo.reward_ids().has(6071) and r792_repo.reward_ids().has(6072),
			"R792 三件新道具都进奖励池")

	check(not GameLayers.has_events(GameLayers.LAYER_THREE) and GameLayers.event_weights(GameLayers.LAYER_THREE).is_empty(),
			"R792 第三层不再注册事件（事件池只剩第一 / 第二层）")

	var r792_en := FileAccess.get_file_as_string("res://i18n/noncard_en.json")

	var r792_ja := FileAccess.get_file_as_string("res://i18n/noncard_ja.json")

	var r792_es := FileAccess.get_file_as_string("res://i18n/noncard_es.json")

	check(r792_en.contains('"6070"') and r792_ja.contains('"6070"') and r792_es.contains('"6070"') and r792_en.contains('"6071"') and r792_ja.contains('"6071"') and r792_es.contains('"6072"'),
			"R792 三语条目齐（6070 / 6071 / 6072）")

	# ② 板甲：第一个盟友 +6 生命、移速 5 → 1；第二个盟友完全不受影响
	var r792_plate_relics: Array[int] = [6070]

	RunState.relics = r792_plate_relics

	var r792_plate := _new_engine([], 40, 40)

	r792_plate.state.energy = 30

	r792_plate.state.hand.clear()

	r792_plate.state.hand.append(CardData.from_dict(repo.get_card(8006).to_dict()))   # 影子猫 1 费 1 血 速 5

	r792_plate.state.hand.append(CardData.from_dict(repo.get_card(9028).to_dict()))   # 龙裔 1 费 12 血 速 1

	var r792_p1 := r792_plate.play_from_hand(0, Vector2i(5, 1))

	var r792_p2 := r792_plate.play_from_hand(0, Vector2i(6, 1))

	check(r792_p1 != null and r792_p1.health == 7 and r792_p1.card.health == 7,
			"R792 板甲：第一个盟友 1+6=7 生命（实得 %d）" % (r792_p1.health if r792_p1 != null else -1))

	check(r792_p1 != null and r792_p1.effective_speed() == 1 and r792_p1.speed_cap == 1,
			"R792 板甲：第一个盟友移速 5 → 1（实得 %d）" % (r792_p1.effective_speed() if r792_p1 != null else -1))

	check(r792_p2 != null and r792_p2.health == 12 and r792_p2.speed_cap == 0 and r792_p2.relic_bonus_hp == 0,
			"R792 板甲：第二个盟友不受影响（生命 %d、无移速上限）" % (r792_p2.health if r792_p2 != null else -1))

	# ③ 兵：第一个盟友当回合就有 2 轮行动；第二个只 1 轮
	var r792_pawn_relics: Array[int] = [6071]

	RunState.relics = r792_pawn_relics

	var r792_pawn := _new_engine([], 40, 40)

	r792_pawn.state.energy = 30

	r792_pawn.state.hand.clear()

	r792_pawn.state.hand.append(CardData.from_dict(repo.get_card(9028).to_dict()))

	r792_pawn.state.hand.append(CardData.from_dict(repo.get_card(9028).to_dict()))

	var r792_n1 := r792_pawn.play_from_hand(0, Vector2i(5, 1))

	var r792_n2 := r792_pawn.play_from_hand(0, Vector2i(6, 1))

	check(r792_n1 != null and r792_n1.acts_left == 2 and r792_pawn.state.unit_actions(r792_n1, "self") == 2,
			"R792 兵：第一个盟友本回合就有 2 轮行动（acts_left=%d）" % (r792_n1.acts_left if r792_n1 != null else -1))

	check(r792_n2 != null and r792_n2.acts_left == 1 and not r792_n2.first_ally_twice,
			"R792 兵：第二个盟友只行动一次")

	# ④ 墙砖：工事 6+4=10；离场还原成 6（同一张回手再上场不会叠成 +8）
	var r792_brick_relics: Array[int] = [6072]

	RunState.relics = r792_brick_relics

	var r792_brick := _new_engine([], 40, 40)

	r792_brick.state.energy = 30

	r792_brick.state.hand.clear()

	r792_brick.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))   # 木栅栏 2 费 6 血

	var r792_w := r792_brick.play_from_hand(0, Vector2i(5, 1))

	check(r792_w != null and r792_w.health == 10 and r792_w.card.health == 10 and r792_w.relic_bonus_hp == 4,
			"R792 墙砖：木栅栏 6+4=10 生命（实得 %d）" % (r792_w.health if r792_w != null else -1))

	var r792_back := r792_brick._card_leaving_field(r792_w)

	check(r792_back != null and r792_back.health == 6,
			"R792 墙砖：离场还原成 6 血（实得 %d）" % (r792_back.health if r792_back != null else -1))

	# ⑤ 源码守卫：「第一个盟友」两个额度各只发一次，重置点在 start_game
	var r792_ge_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")

	check_src(r792_ge_src.contains("_plate_first_ally_done = false") and r792_ge_src.contains("_pawn_first_ally_done = false") and r792_ge_src.contains("state.grant_actions(p, state.unit_actions(p, SIDE_SELF))"),
			"R792 源码守卫：兵的双动走 grant_actions 补发，两个额度在 start_game 重置")

	RunState.relics = r792_sv_relics

'''

s = s.rstrip('\r\n') + '\r\n' + BLOCK.replace('\n', '\r\n')
io.open(P, 'w', encoding='utf-8', newline='').write(s)
print('OK 测试段已追加')
