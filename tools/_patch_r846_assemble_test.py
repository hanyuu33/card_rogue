# -*- coding: utf-8 -*-
"""R846：test_assemble.gd（LF）—— 组合素材保真判据与影子猫切分断言。

影子猫 8006 的下半句从 `fetch_skill + if_third` 换成 `draw_if_third`（抽 2 张）。
"""
import io

P = "scripts/test_assemble.gd"
EDITS = [
    # ① _fx_in_text：fetch_skill 去掉 if_third，新动作要有自己的判据（否则落到 return true 零校验）
    ("""		"fetch_skill":
			if fx.get("if_third", false):
				return text.contains("达到 3 张") and text.contains("随机技能卡")
			return text.contains("随机技能卡")
""",
     """		"fetch_skill":
			return text.contains("随机技能卡")
		# R846：影子猫 8006 的下半句改成「其他卡满 3 张 → 抽 N 张」。
		"draw_if_third":
			return text.contains("3 张其他卡") and text.contains("抽 %d 张牌" % n)
"""),
    # ② 切分断言
    ("""	# ③ 影子猫：use + fetch_skill(if_third) + 描述改「使用时」
	var cat: CardData = repo.get_card(8006)
	check(cat != null and str(cat.upper_effect.get("trigger", "")) == "use"
			and (cat.lower_effect.effects[0] as Dictionary).get("if_third", false) == true,
			"R775：影子猫切分 = use + fetch_skill(if_third)")
""",
     """	# ③ 影子猫：use + draw_if_third(2)（R846 从 fetch_skill + if_third 改过来）
	var cat: CardData = repo.get_card(8006)
	check(cat != null and str(cat.upper_effect.get("trigger", "")) == "use"
			and str((cat.lower_effect.effects[0] as Dictionary).get("type", "")) == "draw_if_third"
			and int((cat.lower_effect.effects[0] as Dictionary).get("value", 0)) == 2,
			"R775/R846：影子猫切分 = use + draw_if_third(2)")
"""),
    # ③ 白名单
    ("""	for t in ["summon", "bonus_hp_per_upgrade", "fetch_skill", "self_destruct"]:
		check(CardData.ASSEMBLE_EFFECT_TYPES.has(t), "R775：动作 %s 已登记白名单" % t)
""",
     """	for t in ["summon", "bonus_hp_per_upgrade", "fetch_skill", "self_destruct",
			"draw_if_third"]:
		check(CardData.ASSEMBLE_EFFECT_TYPES.has(t), "R775/R846：动作 %s 已登记白名单" % t)
"""),
]


def main():
    raw = io.open(P, "r", encoding="utf-8", newline="").read()
    assert raw.count("\r\n") == 0, "test_assemble.gd 应是 LF"
    for old, new in EDITS:
        assert raw.count(old) == 1, "锚点命中 %d 次：%r" % (raw.count(old), old[:60])
        raw = raw.replace(old, new)
    io.open(P, "w", encoding="utf-8", newline="").write(raw)
    print("TEST_ASSEMBLE_OK")


if __name__ == "__main__":
    main()
