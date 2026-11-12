# -*- coding: utf-8 -*-
"""R589 第六批：test_engine 的行为判据（主动发动 / lethal / use_after / 七个动作）。

用法：
    python tools/_patch_r589f.py --check-only
    python tools/_patch_r589f.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
REL = "scripts/test_engine.gd"

OLD_CALL = '''\tProfileData.set_test_mode()
\tSteamAchievements.reset_for_test()
\tprint("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")'''

NEW_CALL = '''\tProfileData.set_test_mode()
\tSteamAchievements.reset_for_test()
\t_test_r589()
\tprint("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")'''

NEW_FUNC = '''

# ══════════════════════════════════════════════════════════════════════════
#  R589：组装素材扩展 —— 三条新扳机 + 七个新动作的行为判据
# ══════════════════════════════════════════════════════════════════════════
func _test_r589() -> void:
	## 数据形状（哪张卡上半是什么扳机、下半是什么动作）在 `test_assemble` 里锁；
	## 这里只测**跑起来对不对**。
	##   ① 主动发动从「熊专属」变成通用扳机：产物上半选 `active` 就能发动，
	##      效果走上/下半的动作表；「之后横置 / 在场只能发动一次」按卡面规则实现。
	##   ② `lethal` 是**跨越**判定（扣血前 > 0 且扣血后 <= 0）—— 负血再挨打不重复触发。
	##   ③ `use_after` 与 `use` 在同一处结算（打出即兑现，没有第二套时序）。
	##   ④ 七个动作各自复用母卡的唯一实现口。
	var e := _new_engine([], 40, 40, -1, false)
	e.start_game()
	# ── ① 主动发动 ────────────────────────────────────────────────────────
	var act := _card(90001, "R589 主动产物", "盟友", 1, 1, 10)
	act.assemble = {"trigger": "active", "effects": [],
			"lower_effects": [{"type": "heal", "value": 6}]}
	e.state.hand.append(act)
	e.play_from_hand(e.state.hand.find(act), Vector2i(4, 1))
	var aplt: Placement = e.state.unit_at(Vector2i(4, 1))
	check(aplt != null, "R589：主动发动产物成功上场")
	if aplt != null:
		check(e.can_activate(Vector2i(4, 1)),
				"R589：产物上半选 active → 可主动发动（不要求已掉血）")
		aplt.health = 3
		check(e.activate(Vector2i(4, 1)) and aplt.health == 9,
				"R589：主动发动按下半的 heal 6 结算（3 → 9）")
		check(aplt.tapped and aplt.ability_used,
				"R589：主动发动后横置 + 记「已发动」")
		aplt.tapped = false
		check(not e.can_activate(Vector2i(4, 1)),
				"R589：横置恢复后仍不能再发动（在场只能发动一次）")
	# 上半不是 active 的产物不该有这条能力
	var pas := _card(90002, "R589 被动产物", "盟友", 1, 1, 10)
	pas.assemble = {"trigger": "use", "effects": [], "lower_effects": [{"type": "shield"}]}
	e.state.place(pas, Vector2i(5, 1), GameEngine.SIDE_SELF)
	check(not e.can_activate(Vector2i(5, 1)),
			"R589：上半不是 active 的产物不能主动发动")
	# 熊本体回归：卡库原生卡没有 assemble 段，仍按 trait「回春」认
	var bear := _card(8004, "熊", "盟友", 4, 3, 14)
	bear.traits.append("回春")
	e.state.place(bear, Vector2i(6, 1), GameEngine.SIDE_SELF)
	check(e.can_activate(Vector2i(6, 1)), "R589：熊本体（trait 回春）仍能主动发动")
	# R588 继承坑的局部缓解：属性槽是熊时「回春」会被克隆，产物不该凭空多一次发动
	var inh := _card(90003, "R589 继承产物", "盟友", 1, 1, 10)
	inh.traits.append("回春")
	inh.assemble = {"trigger": "use", "effects": [], "lower_effects": [{"type": "shield"}]}
	e.state.place(inh, Vector2i(7, 1), GameEngine.SIDE_SELF)
	check(not e.can_activate(Vector2i(7, 1)),
			"R589：产物即使被克隆了「回春」trait，也不凭空获得主动发动")
	# ── ② lethal：跨越判定 ────────────────────────────────────────────────
	var lt := _card(90004, "R589 归零产物", "盟友", 1, 1, 8)
	lt.add_affix("超负荷")   # 负血留场，才能验证「不重复触发」
	lt.assemble = {"trigger": "lethal", "effects": [],
			"lower_effects": [{"type": "add_card", "card_id": 9145, "value": 1}]}
	var lp: Placement = e.state.place(lt, Vector2i(2, 1), GameEngine.SIDE_SELF)
	var h0 := e.state.hand.size()
	e._hit_unit(lp, 5, "R589 测试")
	check(lp.health == 3 and e.state.hand.size() == h0,
			"R589：生命没归零不触发 lethal（8 → 3）")
	e._hit_unit(lp, 5, "R589 测试")
	check(lp.health == -2 and e.state.hand.size() == h0 + 1,
			"R589：生命跨越 0（3 → -2）触发一次，加一张「聚能炮击」")
	e._hit_unit(lp, 5, "R589 测试")
	check(e.state.hand.size() == h0 + 1,
			"R589：已在负血再挨打不重复触发（跨越判定，不是「处于」）")
	# ── ③ use_after：打出即结算 ───────────────────────────────────────────
	var ua := _card(90005, "R589 使用后产物", "盟友", 1, 1, 8)
	ua.assemble = {"trigger": "use_after", "effects": [],
			"lower_effects": [{"type": "next_effect_discount", "value": 2}]}
	e.state.hand.append(ua)
	e.state.self_next_effect_reduction = 0
	e.play_from_hand(e.state.hand.find(ua), Vector2i(8, 1))
	check(e.state.self_next_effect_reduction == 2,
			"R589：use_after 在打出时结算（下一张效果卡费用 -2）")
	# ── ④ 七个动作 ────────────────────────────────────────────────────────
	var actp: Placement = e.state.place(_card(90006, "R589 动作探针", "盟友", 1, 1, 30),
			Vector2i(9, 1), GameEngine.SIDE_SELF)
	# next_ally_discount
	actp.card.assemble = {"trigger": "use", "effects": [
			{"type": "next_ally_discount", "value": 1}]}
	e.state.self_next_ally_reduction = 0
	e._assemble_execute(actp, Vector2i(9, 1), "use")
	check(e.state.self_next_ally_reduction == 1,
			"R589：next_ally_discount → 本回合下一个盟友 -1 费")
	# add_effect_from_deck
	e.state.deck.clear()
	e.state.deck.append(_card(90007, "R589 效果卡", "效果", 3, 0, 0))
	e.state.hand.clear()
	actp.card.assemble = {"trigger": "use", "effects": [
			{"type": "add_effect_from_deck", "value": 1, "discount": 2}]}
	e._assemble_execute(actp, Vector2i(9, 1), "use")
	var got_eff: CardData = e.state.hand[0] if not e.state.hand.is_empty() else null
	check(got_eff != null and got_eff.id == 90007 and e.state.deck.is_empty(),
			"R589：add_effect_from_deck 从卡组取到那张效果卡")
	check(got_eff != null and int(e.state.card_discount.get(got_eff, 0)) == 2,
			"R589：取到的效果卡费用 -2（走 card_discount，不是全局减费）")
	# hand_skill_discount + hp_per_zero_skill
	e.state.hand.clear()
	var sk := _card(90008, "R589 技能", "技能", 0, 0, 0)
	e.state.hand.append(sk)
	var hp0 := actp.health
	actp.card.assemble = {"trigger": "use", "effects": [
			{"type": "hand_skill_discount", "value": 1},
			{"type": "hp_per_zero_skill", "value": 3}]}
	e._assemble_execute(actp, Vector2i(9, 1), "use")
	check(int(e.state.turn_card_discount.get(sk, 0)) == 1,
			"R589：hand_skill_discount → 手卡技能牌本回合 -1 费")
	check(actp.health == hp0 + 3,
			"R589：hp_per_zero_skill → 每张 0 费技能卡 +3 生命")
	# fetch_cheapest_ally
	e.state.deck.clear()
	e.state.deck.append(_card(90009, "R589 三费盟友", "盟友", 3, 1, 3))
	e.state.deck.append(_card(90010, "R589 一费盟友", "盟友", 1, 1, 3))
	e.state.hand.clear()
	actp.card.assemble = {"trigger": "use", "effects": [{"type": "fetch_cheapest_ally"}]}
	e._assemble_execute(actp, Vector2i(9, 1), "use")
	check(e.state.hand.size() == 1 and e.state.hand[0].id == 90010,
			"R589：fetch_cheapest_ally 取到费用最低的那张盟友")
	# recall_ally_from_discard
	e.state.discard.clear()
	e.state.discard.append(_card(90011, "R589 弃牌区盟友", "盟友", 2, 1, 3))
	e.state.hand.clear()
	actp.card.assemble = {"trigger": "use", "effects": [{"type": "recall_ally_from_discard"}]}
	e._assemble_execute(actp, Vector2i(9, 1), "use")
	check(e.crow_pending, "R589：recall_ally_from_discard 打开弃牌区选择面板")
	check(e.crow_recall(0) and e.state.hand.size() == 1,
			"R589：选中的盟友回到手卡")
	# 收尾：别把测试状态漏给后面的用例
	e.state.self_next_effect_reduction = 0
	e.state.self_next_ally_reduction = 0
'''


def main():
    with io.open(os.path.join(ROOT, REL), "r", encoding="utf-8", newline="") as f:
        text = f.read()
    old, new = OLD_CALL, NEW_CALL
    cnt = text.count(old)
    if cnt == 0:
        crlf_old = old.replace("\n", "\r\n")
        if text.count(crlf_old) == 1:
            old, new = crlf_old, new.replace("\n", "\r\n")
            cnt = 1
    if cnt != 1:
        print("[FAIL] 调用点锚点命中 %d 次" % cnt)
        return 1
    text = text.replace(old, new, 1)
    print("[ok] _init 挂上 _test_r589()")
    if "_test_r589() -> void:" in text:
        print("[FAIL] R589 用例已存在（补丁重复？）")
        return 1
    func = NEW_FUNC.replace("\n", "\r\n") if "\r\n" in text else NEW_FUNC
    text = text.rstrip("\r\n") + func
    print("[ok] 追加 _test_r589()")
    if CHECK:
        print("--check-only：未写文件。")
        return 0
    with io.open(os.path.join(ROOT, REL), "w", encoding="utf-8", newline="") as f:
        f.write(text)
    b = open(os.path.join(ROOT, REL), "rb").read()
    print("[write] %s（CRLF %d / bareLF %d）" % (REL, b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
