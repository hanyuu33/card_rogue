# -*- coding: utf-8 -*-
"""R793 patch 5/5 —— test_engine：林中的剑 + 大师之剑的回归。

行为断言沿用 R761/R792 的写法：`_new_engine` + `play_from_hand`，
只看 `master_sword_atk` / `effective_power()` 这两个出口 —— 不碰 `card.power`。
"""
import io, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def patch(path, pairs):
    p = ROOT.rstrip("/") + "/" + path
    raw = io.open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            o = old.replace("\n", "\r\n")
            n = new.replace("\n", "\r\n")
        else:
            o, n = old, new
        c = txt.count(o)
        assert c == 1, "%s: count=%d for %r" % (path, c, old[:70])
        txt = txt.replace(o, n)
    io.open(p, "wb").write(txt.encode("utf-8"))
    print("OK %-34s %d -> %d  (%s)" % (path, len(raw), len(txt.encode("utf-8")),
                                       "CRLF" if crlf else "LF"))


TEST_FN = '''

func _test_r793() -> void:
	## R793 林中的剑（第一层事件）+ 道具「大师之剑」6075：
	##   拔剑 = 失去 13 点最大生命 → 每场战斗使用的第一个盟友 +10 力量。
	var r793_cards := CardRepo.load_json()
	var r793_repo := RelicRepo.load_json()
	var r793_sv_relics: Array[int] = RunState.relics.duplicate()
	var r793_sv_spent: Array[int] = RunState.spent_relics.duplicate()
	var r793_sv_mhp := RunState.max_hp
	var r793_sv_hp := RunState.hp

	# ① 数据层
	var r793_relic := r793_repo.get_relic(6075)
	check(r793_relic != null, "R793 数据：大师之剑 6075 在库")
	if r793_relic != null:
		check(r793_relic.relic_name == "大师之剑" and r793_relic.source == "事件"
				and r793_relic.kind == "战斗" and r793_relic.tier == "一般",
				"R793 数据：6075 = 大师之剑 / 事件 / 战斗 / 一般（实得 %s / %s / %s / %s）" % [
						r793_relic.relic_name, r793_relic.source,
						r793_relic.kind, r793_relic.tier])
	check(not r793_repo.reward_ids().has(6075),
			"R793 数据：事件专属 → 不进奖励池（只有林中的剑给得出）")

	# ② 事件注册：第一层专属，第二层不登记
	var r793_w1 := GameLayers.event_weights(GameLayers.LAYER_DEFAULT)
	var r793_w2 := GameLayers.event_weights(GameLayers.LAYER_TWO)
	check(r793_w1.has("sword") and int(r793_w1["sword"]) > 0,
			"R793 事件：第一层事件池含林中的剑（权重 %d）" % int(r793_w1.get("sword", 0)))
	check(not r793_w2.has("sword"),
			"R793 事件：第二层不登记（第一层专属，别顺手抄过去）")
	check(str(GameLayers.EVENT_NAMES.get("sword", "")) == "林中的剑",
			"R793 事件：EVENT_NAMES 有中文名（日志 / 界面读它）")

	# ③ 四语文案
	for r793_code in ["zh_canonical", "en", "ja", "es"]:
		var r793_nc := FileAccess.get_file_as_string("res://i18n/noncard_%s.json" % r793_code)
		check_src(r793_nc.contains('"6075"'), "R793 文案：noncard_%s 有 6075" % r793_code)
	for r793_code2 in ["zh_canonical", "en", "ja", "es"]:
		var r793_nar := FileAccess.get_file_as_string("res://i18n/narrative_%s.json" % r793_code2)
		check_src(r793_nar.contains("SWORD_DESC") and r793_nar.contains("SWORD_TAKEN_DESC")
				and r793_nar.contains('"sword"'),
				"R793 文案：narrative_%s 有事件长文" % r793_code2)
	var r793_ui_en := FileAccess.get_file_as_string("res://i18n/event_ui_en.json")
	check_src(r793_ui_en.contains("TAKE_SWORD") and r793_ui_en.contains("SWORD_GAINED"),
			"R793 文案：event_ui 有选项与结果 key")

	# ④ 源码口径（导出包里 .gd 是 binary tokens → 必须走 check_src）
	var r793_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	check_src(r793_es.contains("const SWORD_MASTER_ID := 6075")
			and r793_es.contains("const SWORD_LIFE_COST := 13"),
			"R793 事件：道具 6075 / 代价 13 点最大生命 的常量对")
	check_src(r793_es.contains("and not _is_sword()"),
			"R793 事件：_is_treasure() 兜底排除 sword（漏了整场事件都会退化成小宝箱）")
	check_src(r793_es.contains('if _is_sword():\\n\\t\\treturn "sword"'),
			"R793 事件：_kind() 认 sword（漏了会点亮休息处的篝火背景）")
	check_src(r793_es.contains("or _is_statue() or _is_sword():"),
			"R793 事件：_refresh() 白名单含 sword（漏了按钮文案会被刷成「在这里休息」）")
	check_src(r793_es.contains("RunState.lose_max_hp(SWORD_LIFE_COST)")
			and r793_es.contains("RunState.has_relic(SWORD_MASTER_ID)"),
			"R793 事件：结算走 lose_max_hp 唯一口，且已持有 / 上限不足都拦在结算里")

	# ⑤ 行为：第一个盟友 +10 力量，第二个完全不受影响
	var r793_on: Array[int] = [6075]
	RunState.relics = r793_on
	var r793_eng := _new_engine([], 40, 40)
	r793_eng.state.energy = 30
	r793_eng.state.hand.clear()
	r793_eng.state.hand.append(CardData.from_dict(r793_cards.get_card(8003).to_dict()))
	r793_eng.state.hand.append(CardData.from_dict(r793_cards.get_card(8003).to_dict()))
	var r793_a := r793_eng.play_from_hand(0, Vector2i(5, 1))
	var r793_b := r793_eng.play_from_hand(0, Vector2i(4, 1))
	check(r793_a != null and r793_a.master_sword_atk == 10
			and r793_a.effective_power() == r793_a.card.power + 10,
			"R793 大师之剑：第一个盟友 +10 力量（字段 %d / 实际 %d）" % [
					r793_a.master_sword_atk if r793_a != null else -1,
					(r793_a.effective_power() - r793_a.card.power) if r793_a != null else -999])
	check(r793_a != null and r793_a.card.power == r793_cards.get_card(8003).power,
			"R793 大师之剑：没有烤进共享 CardData（卡库实例仍是原值 %d）" % [
					r793_cards.get_card(8003).power])
	check(r793_b != null and r793_b.master_sword_atk == 0
			and r793_b.effective_power() == r793_b.card.power,
			"R793 大师之剑：第二个盟友不受影响")
	check(r793_a != null and r793_a.to_save().has("master_sword_atk"),
			"R793 存档：to_save 带 master_sword_atk")
	check(Placement._SAVE_FIELDS.has("master_sword_atk"),
			"R793 存档：master_sword_atk 在 _SAVE_FIELDS 里（漏了战斗续档归零）")

	# ⑥ 每场战斗重新发一份额度
	r793_eng.start_game(0, 50, true)
	check(not r793_eng._master_sword_first_ally_done,
			"R793 大师之剑：start_game 重置「第一个盟友」额度")
	r793_eng.state.energy = 30
	r793_eng.state.hand.clear()
	r793_eng.state.hand.append(CardData.from_dict(r793_cards.get_card(8003).to_dict()))
	var r793_c := r793_eng.play_from_hand(0, Vector2i(5, 1))
	check(r793_c != null and r793_c.master_sword_atk == 10,
			"R793 大师之剑：第二场战斗的第一个盟友照样 +10")

	# ⑦ 没这件道具 → 一点都不加
	var r793_off: Array[int] = []
	RunState.relics = r793_off
	var r793_eng2 := _new_engine([], 40, 40)
	r793_eng2.state.energy = 30
	r793_eng2.state.hand.clear()
	r793_eng2.state.hand.append(CardData.from_dict(r793_cards.get_card(8003).to_dict()))
	var r793_d := r793_eng2.play_from_hand(0, Vector2i(5, 1))
	check(r793_d != null and r793_d.master_sword_atk == 0
			and r793_d.effective_power() == r793_d.card.power,
			"R793 大师之剑：不持有道具时第一个盟友不加力量")

	# ⑧ 代价口径：至少保留 1 点最大生命（与占卜室 / 源数之力同一条 lose_max_hp）
	RunState.max_hp = 14
	RunState.hp = 14
	var r793_lost := RunState.lose_max_hp(13)
	check(r793_lost == 13 and RunState.max_hp == 1,
			"R793 代价：14 → 失去 13 点最大生命，剩 1 点（实得 %d）" % r793_lost)
	RunState.max_hp = 10
	RunState.hp = 10
	var r793_lost2 := RunState.lose_max_hp(13)
	check(r793_lost2 == 9 and RunState.max_hp == 1,
			"R793 代价：最大生命不足 13 → 只扣到 1 点为止（实失 %d）" % r793_lost2)

	# 收尾还原（本函数动过道具表与最大 / 当前生命）
	RunState.relics = r793_sv_relics
	RunState.spent_relics = r793_sv_spent
	RunState.max_hp = r793_sv_mhp
	RunState.hp = r793_sv_hp
'''

patch("scripts/test_engine.gd", [
    ('\t_test_r792()\n\n\tprint("== 结果：', '\t_test_r792()\n\t_test_r793()\n\n\tprint("== 结果：'),
])

# 函数体追加到文件末尾（HEAD 版末尾就是 _test_r781 的两个空行）
p = ROOT.rstrip("/") + "/scripts/test_engine.gd"
raw = io.open(p, "rb").read()
txt = raw.decode("utf-8")
body = TEST_FN.replace("\n", "\r\n")
assert txt.endswith("\r\n\r\n")
txt = txt + body
io.open(p, "wb").write(txt.encode("utf-8"))
print("appended _test_r793 -> %d bytes" % len(txt.encode("utf-8")))

print("patch 5/5 done")
