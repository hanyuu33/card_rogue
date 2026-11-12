# -*- coding: utf-8 -*-
"""R589 第五批：test_assemble 的保真判据 + 素材卡断言。

用法：
    python tools/_patch_r589e.py --check-only
    python tools/_patch_r589e.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
REL = "scripts/test_assemble.gd"

OLD_FX = '''\t\t# R585：入库句的出处必须写「加入抽牌库」，光有卡名不算。
\t\t"add_card_to_deck":
\t\t\treturn text.contains("「" + Rules.card_label(int(fx.get("card_id", 0))) + "」") \\
\t\t\t\t\tand text.contains("加入抽牌库")
\treturn true'''

NEW_FX = '''\t\t# R585：入库句的出处必须写「加入抽牌库」，光有卡名不算。
\t\t"add_card_to_deck":
\t\t\treturn text.contains("「" + Rules.card_label(int(fx.get("card_id", 0))) + "」") \\
\t\t\t\t\tand text.contains("加入抽牌库")
\t\t# ── R589：七条新动作。**每条都要有判据** —— 不写分支就会落到末尾的
\t\t#    `return true`，等于零校验（R583 踩过的坑：五个动作白过保真锁）。
\t\t"next_effect_discount": return text.contains("下一张效果卡费用减少 %d" % n)
\t\t"next_ally_discount": return text.contains("下一个盟友时，费用 -%d" % n)
\t\t"add_effect_from_deck":
\t\t\treturn text.contains("从卡组") and text.contains("效果卡加入手卡") \\
\t\t\t\t\tand text.contains("费用减少 %d" % int(fx.get("discount", 0)))
\t\t"hand_skill_discount": return text.contains("所有技能牌本回合费用 -%d" % n)
\t\t"hp_per_zero_skill":
\t\t\treturn text.contains("费用为 0 的技能卡") and text.contains("+%d 生命" % n)
\t\t"fetch_cheapest_ally":
\t\t\treturn text.contains("费用最低的盟友") and text.contains("加入手卡")
\t\t"recall_ally_from_discard":
\t\t\treturn text.contains("弃牌堆") and text.contains("盟友回到手卡")
\treturn true'''

OLD_RUN = '''\t_test_r572_combo_hooks()
\tprint("Combination tests failures: ", failures)'''

NEW_RUN = '''\t_test_r572_combo_hooks()
\t_test_r589_materials()
\tprint("Combination tests failures: ", failures)'''

NEW_FUNC = '''

func _test_r589_materials() -> void:
	## R589：用户逐张点名的八张素材卡入池 —— 上半只给扳机、效果全放下半。
	##   · 熊 8004「上半主动发动」→ `active` 是**通用扳机**（组合产物只要上半选它就能发动）；
	##   · 忒修斯奇械 9222「上半超负荷 + 每次生命降到 0 或更低」→ `lethal` 跨越判定 + 常驻字段；
	##   · 小精灵 9074 / 斑鸠 9052 / 巨鼠 9046 / 乌鸦 9039：上半「使用后」；
	##   · 水元素 9068 / 影魔 8007：上半「使用时」。
	## 另外两张**明确不入池**：堡垒 8034（纯持续效果，没有扳机）、素体 8025（万用素材）。
	var repo := CardRepo.load_json()
	# ① 三条新扳机在白名单与文案表里
	for tk: String in ["active", "use_after", "lethal"]:
		check(Rules.TRIGGERS.has(tk), "R589：扳机 %s 必须在白名单" % tk)
		check(Rules.LABELS.has(tk), "R589：扳机 %s 必须有卡面文案" % tk)
	# 「之后横置 / 在场只能发动一次」不是装饰句：引擎 activate 就是按它实现的
	check(str(Rules.TRIGGER_RULES.get("active", "")).contains("在场只能发动一次"),
			"R589：主动发动必须自带「在场只能发动一次」规则句")
	# ② 八张卡的上半扳机 / 下半首动作 / 关键数值
	var rows := {
		8004: ["active", "heal", 6],
		9222: ["lethal", "add_card", 9145],
		9074: ["use_after", "next_effect_discount", 2],
		9052: ["use_after", "next_ally_discount", 1],
		9068: ["use", "add_effect_from_deck", 1],
		8007: ["use", "hand_skill_discount", 1],
		9046: ["use_after", "fetch_cheapest_ally", 0],
		9039: ["use_after", "recall_ally_from_discard", 0],
	}
	for cid: int in rows:
		var c: CardData = repo.get_card(cid)
		check(c != null, "R589：卡 %d 存在" % cid)
		if c == null:
			continue
		var want: Array = rows[cid]
		check(str(c.upper_effect.get("trigger", "")) == str(want[0]),
				"R589：%d %s 上半扳机 = %s（实际 %s）"
				% [cid, c.card_name, want[0], c.upper_effect.get("trigger", "")])
		check((c.upper_effect.get("effects", []) as Array).is_empty(),
				"R589：%d %s 上半只给钩子" % [cid, c.card_name])
		var lo: Array = c.lower_effect.get("effects", []) as Array
		check(not lo.is_empty(), "R589：%d %s 下半必须有效果" % [cid, c.card_name])
		if lo.is_empty():
			continue
		var fx0: Dictionary = lo[0]
		check(str(fx0.get("type", "")) == str(want[1]),
				"R589：%d %s 下半首动作 = %s（实际 %s）"
				% [cid, c.card_name, want[1], fx0.get("type", "")])
		if int(want[2]) > 0:
			var got_n: int = int(fx0.get("card_id", fx0.get("value", 0)))
			check(got_n == int(want[2]),
					"R589：%d %s 下半数值 = %d（实际 %d）"
					% [cid, c.card_name, want[2], got_n])
		check(Rules.valid_pool([c.upper_effect], [c.lower_effect]),
				"R589：%d %s 上下半合法" % [cid, c.card_name])
	# 影魔下半是两句：先给手卡技能牌减费、再按 0 费技能卡长血
	var sd: CardData = repo.get_card(8007)
	var sdl: Array = sd.lower_effect.get("effects", []) as Array
	check(sdl.size() == 2 and str((sdl[1] as Dictionary).get("type", "")) == "hp_per_zero_skill" \\
			and int((sdl[1] as Dictionary).get("value", 0)) == 3,
			"R589：影魔下半 = 减 1 费 + 每张 0 费技能卡 +3 生命")
	# ③ 两张明确不入池
	for cid: int in [8034, 8025]:
		var c2: CardData = repo.get_card(cid)
		check(c2 != null and c2.upper_effect.is_empty() and c2.lower_effect.is_empty(),
				"R589：%d 不加入候选池（用户口径）" % cid)
	# ④ 产物文案：主动发动必须把规则句一起印出来（卡面写了才敢这么结算）
	var probe := CardData.new()
	probe.card_name = "R589 探针"
	probe.kind = "盟友"
	probe.health = 10
	probe.power = 1
	probe.attack_range = 1
	var bear_card: CardData = repo.get_card(8004)
	var bear_built: CardData = Rules.build(probe, bear_card.upper_effect, bear_card.lower_effect)
	check(bear_built != null
			and bear_built.effect_text == "主动发动：代替行动回复6点生命，之后横置。在场只能发动一次。",
			"R589：熊产物文案（实际「%s」）"
			% (bear_built.effect_text if bear_built != null else "null"))
	# 忒修斯：上半带「超负荷」「次元」两个常驻字段 → 产物是负血不死的
	var the_card: CardData = repo.get_card(9222)
	var the_built: CardData = Rules.build(probe, the_card.upper_effect, the_card.lower_effect)
	check(the_built != null and the_built.has_affix("超负荷") and the_built.has_affix("次元"),
			"R589：忒修斯产物带超负荷 + 次元")
	check(the_built != null and the_built.effect_text.contains("每次生命降到 0 或更低")
			and the_built.effect_text.contains("聚能炮击"),
			"R589：忒修斯产物文案（实际「%s」）"
			% (the_built.effect_text if the_built != null else "null"))
	# ⑤ 保真判据真的能拦住错卡（不是一路 return true 放行）
	check(not _fx_in_text({"type": "next_effect_discount", "value": 2}, "抽1张牌"),
			"R589 保真：小精灵判据拦得住无关文本")
	check(not _fx_in_text({"type": "add_effect_from_deck", "value": 1, "discount": 2},
			"对最近敌人造成 3 点伤害"), "R589 保真：水元素判据拦得住无关文本")
	check(not _fx_in_text({"type": "fetch_cheapest_ally"}, "抽1张牌"),
			"R589 保真：巨鼠判据拦得住无关文本")
	# ⑥ 池子确实长了：八张全在里面
	var pool := 0
	for c3: CardData in repo.all_cards():
		if (c3.kind == "盟友" or c3.kind == "工事") and c3.group == "player" \\
				and not c3.upper_effect.is_empty() and not c3.lower_effect.is_empty():
			pool += 1
	check(pool >= 36, "R589：候选池至少 36 张（实际 %d）" % pool)
'''


def main():
    with io.open(os.path.join(ROOT, REL), "r", encoding="utf-8", newline="") as f:
        text = f.read()
    ok = True
    for old, new, note in [(OLD_FX, NEW_FX, "七条保真判据"),
                           (OLD_RUN, NEW_RUN, "_run 挂上 R589 用例")]:
        cnt = text.count(old)
        if cnt != 1:
            print("[FAIL] %s（命中 %d 次）" % (note, cnt))
            ok = False
            continue
        text = text.replace(old, new, 1)
        print("[ok] %s" % note)
    if not ok:
        return 1
    if "_test_r589_materials() -> void:" in text:
        print("[FAIL] R589 用例已存在（补丁重复？）")
        return 1
    text = text.rstrip("\n") + "\n" + NEW_FUNC
    print("[ok] 追加 _test_r589_materials()")
    if CHECK:
        print("--check-only：未写文件。")
        return 0
    with io.open(os.path.join(ROOT, REL), "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("[write] %s" % REL)
    return 0


if __name__ == "__main__":
    sys.exit(main())
