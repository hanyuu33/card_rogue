# -*- coding: utf-8 -*-
"""R846：追加 `_test_r846()` 并在运行器里登记（test_engine.gd / CRLF）。"""
import io

P = "scripts/test_engine.gd"

FUNC = '''
func _test_r846() -> void:
	## R846：暗影刺客七张卡（影子猫 / 地狱猫 / 噩兆 / 回转 / 闪躲 / 猫鼠游戏 / 暗影之刃）。
	## 行为细节分散在 R45 / R48 / R55 / R56 各自的块里；这里钉**数据口径 + 素材类型 + 源码锁**。
	var repo := CardRepo.load_json()

	# ① 影子猫 8006：移速 2 + 下半句改成 draw_if_third(2)
	var cat := repo.get_card(8006)
	check(cat != null and cat.kind == "盟友" and cat.cost == 1 and cat.move_speed == 2
			and cat.power == 1 and cat.health == 1,
			"R846 影子猫：1 费盟友 1/1，移速 5 → 2")
	check(cat.effect_text.contains("3 张其他卡") and cat.effect_text.contains("抽 2 张牌"),
			"R846 影子猫文案：本回合已用过 3 张其他卡 → 抽 2 张（%s）" % cat.effect_text)
	var cat_fx: Dictionary = cat.lower_effect.effects[0]
	check(str(cat_fx.get("type", "")) == "draw_if_third" and int(cat_fx.get("value", 0)) == 2,
			"R846 影子猫素材：draw_if_third(2)（不再是 fetch_skill + if_third）")
	check(CardData.ASSEMBLE_EFFECT_TYPES.has("draw_if_third"),
			"R846 影子猫素材类型已进组合动作白名单")

	# ② 地狱猫 8019：初始力量 0
	var hell := repo.get_card(8019)
	check(hell != null and hell.power == 0 and hell.health == 1 and hell.cost == 0,
			"R846 地狱猫：0 费 0/1（初始力量 1 → 0，成长规则不变）")
	check(hell.effect_text.contains("剩余费用每有 1 点"),
			"R846 地狱猫文案不变（仍按剩余费用 +1 力 +2 血）")

	# ③ 噩兆 9231：使用时若无标记 → 随机标一个格子（已有标记则不动）
	var omen := repo.get_card(9231)
	check(omen != null and omen.effect_text.begins_with("使用时，若场上没有标记"),
			"R846 噩兆文案：新增「使用时若场上没有标记 → 随机标记一个格子」")
	var oe := _new_engine([], 30, 30, -1, false)
	oe.start_game(1)
	check(not oe.state.has_mark(), "R846 噩兆：开局场上本来没有标记")
	oe.state.energy = 9
	oe.state.hand.append(CardData.from_dict(omen.to_dict()))
	oe.use_effect(0)
	check(oe.state.has_mark(), "R846 噩兆：使用时场上没有标记 → 随机标出一个")
	var oe_cell := oe.state.mark_cell()
	check(oe_cell.x >= 0 and oe_cell.x < FieldState.BOARD_ROWS and oe_cell.y >= 0
			and oe_cell.y < FieldState.BOARD_COLS
			and oe_cell.x != oe.back_row(GameEngine.SIDE_SELF),
			"R846 噩兆：标记落在棋盘内且不占己方 HP 行（%s）" % str(oe_cell))
	oe.state.energy = 9
	oe.state.hand.append(CardData.from_dict(omen.to_dict()))
	oe.use_effect(0)
	check(oe.state.mark_cell() == oe_cell, "R846 噩兆：已有标记时不再随机标记（不挪走原格）")

	# ④ 回转 9089：要选目标；没给目标就只回提示
	var rot := repo.get_card(9089)
	check(rot != null and rot.target_mode == "unit" and rot.cost == 2,
			"R846 回转：2 费技能，改成一个目标")
	var re := _new_engine([], 30, 30)
	re.state.self_card_plays = 2
	re.state.hand.append(CardData.from_dict(rot.to_dict()))
	var re_msg := str(re.use_spell(0, null))
	check(re_msg.contains("指定"),
			"R846 回转：没给目标 → 只回一句提示，不结算（%s）" % re_msg)

	# ⑤ 闪躲 9103：稀有 + 敌方降力
	var dod := repo.get_card(9103)
	check(dod != null and dod.rarity == 1 and dod.cost == 0 and dod.target_mode == "unit",
			"R846 闪躲：0 费**稀有**技能，要选一个敌方单位")
	check(not dod.effect_text.contains("嘲讽"), "R846 闪躲：卡面不再提嘲讽")

	# ⑥ 猫鼠游戏 9190：4 费
	var cm := repo.get_card(9190)
	check(cm != null and cm.cost == 4 and cm.locked, "R846 猫鼠游戏：5 费 → 4 费（仍 locked）")

	# ⑦ 暗影之刃 9111：X = 已使用卡牌张数
	var blade := repo.get_card(9111)
	check(blade != null and blade.effect_text.contains("已使用的卡牌张数"),
			"R846 暗影之刃：X = 本回合已使用的卡牌张数（%s）" % blade.effect_text)

	# ⑧ 源码锁：新常量 / 素材分支在、旧机制不在
	var src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(src.contains("const SHADOW_CAT_NEED:= 3")
			and src.contains("const SHADOW_CAT_DRAW:= 2"),
			"R846 源码：影子猫走 SHADOW_CAT_NEED / SHADOW_CAT_DRAW 两个常量")
	check_src(src.contains("\\"draw_if_third\\":") and src.contains("_auto_mark_if_none(\\"噩兆\\", true)"),
			"R846 源码：组合分支 draw_if_third + 噩兆自动标记都落在实现口")
	check_src(src.contains("var blade_n: int = state.self_card_plays if side == SIDE_SELF")
			and not src.contains("state.energy_spent_of(side)\\n\\t\\tif spent"),
			"R846 源码：暗影之刃改读卡牌张数，旧的「已花费用」取值已删")
	check_src(src.find("var _taunt_all_active") < 0 and src.find("func taunt_all_active") < 0,
			"R846 源码：闪躲的全员嘲讽机制整条删除")

	# ⑨ 三语文本：五张改了文案的卡都要有对应译文
	var i18n_want := {
		"8006": "3 other cards",
		"9231": "randomly Mark a tile",
		"9089": "Deal X damage to a target",
		"9103": "Reduce an enemy unit",
		"9111": "number of cards you have used this turn",
	}
	var raw_en: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://i18n/cards_en.json"))
	var en_cards: Dictionary = (raw_en as Dictionary).get("cards", {}) if raw_en is Dictionary else {}
	for cid: String in i18n_want.keys():
		var row: Variant = en_cards.get(cid, {})
		var txt := "" if not row is Dictionary else str((row as Dictionary).get("effect_text", ""))
		check(txt.find(str(i18n_want[cid])) >= 0,
				"R846 英文文案（%s）已同步：%s" % [cid, txt])
	var i18n_ok := true
	for lang: String in ["ja", "es", "zh_canonical"]:
		var raw_l: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://i18n/%s.json" % (
						"cards_" + lang if lang != "zh_canonical" else lang)))
		if not raw_l is Dictionary:
			i18n_ok = false
			continue
		var rows: Dictionary = (raw_l as Dictionary).get("cards", {})
		for cid: String in i18n_want.keys():
			if not rows.has(cid):
				i18n_ok = false
	check(i18n_ok, "R846 文本：ja / es / zh_canonical 七张卡都还在（缺 key 会立刻红）")

	# ⑩ 图鉴口径没被顺手改动：344 张、暗影刺客 67 张
	var rogue := 0
	for c: CardData in repo.all_cards():
		if c.card_class == PlayerClass.ROGUE:
			rogue += 1
	check(repo.all_cards().size() == 344 and rogue == 67,
			"R846：卡总数 344 / 暗影刺客 67 不变（只改数值与文案，没增删卡）")
'''

REGISTER_OLD = "\t_test_r845()\n"
REGISTER_NEW = "\t_test_r845()\n\t_test_r846()\n"


def main():
    raw = io.open(P, "r", encoding="utf-8", newline="").read()
    assert raw.count("\r\n") == raw.count("\n"), "不是纯 CRLF"
    txt = raw.replace("\r\n", "\n")

    assert "_test_r846()" not in txt, "已经追加过"
    if not txt.endswith("\n"):
        txt += "\n"
    txt += FUNC

    assert txt.count(REGISTER_OLD) == 1, "运行器登记点命中 %d 次" % txt.count(REGISTER_OLD)
    txt = txt.replace(REGISTER_OLD, REGISTER_NEW)

    io.open(P, "w", encoding="utf-8", newline="").write(txt.replace("\n", "\r\n"))
    print("APPEND_OK")


if __name__ == "__main__":
    main()
