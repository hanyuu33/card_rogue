# -*- coding: utf-8 -*-
"""R846 收尾：R226 伤害判据计数 +1（回转 9089 现在直接造成伤害）。"""
import io

EDITS = [
    ("scripts/test_engine.gd",
     """	# R845：本能 9176 由技能改效果卡 → 技能 118 → 117，伤害判据不变。
""",
     """	# R845：本能 9176 由技能改效果卡 → 技能 118 → 117，伤害判据不变。
	# R846：回转 9089 从「只抽牌」改成「对一个目标造成 X 伤 + 抽 X 张」→ 伤害判据 +1（48 → 49）；
	#       闪躲 9103 从「全员嘲讽」改成「对敌方降力」，仍然不含「造成」二字 → 技能数不变。
"""),
    ("scripts/test_engine.gd",
     "	check(r226_skills == 117 and r226_dmg == 48 and r226_leak.is_empty(),",
     "	check(r226_skills == 117 and r226_dmg == 49 and r226_leak.is_empty(),"),
    ("scripts/card_data.gd",
     """	##   （森林守护 9037 / 风暴屏障 9060 / 坚固围栏 9071 / 能量屏障 8033）与闪躲 9103
	##   （R542 起改为全员嘲讽）都不含「造成」二字 → 天然排除（R226 已逐张核对，零误判）。
""",
     """	##   （森林守护 9037 / 风暴屏障 9060 / 坚固围栏 9071 / 能量屏障 8033）与闪躲 9103
	##   （R846 起改为「对一个敌方单位降力」）都不含「造成」二字 → 天然排除（R226 逐张核对）。
	##   反过来：R846 回转 9089 加了「对一个目标造成 X 点伤害」→ 自动进判据（伤害数 48 → 49）。
"""),
]


def main():
    for path, old, new in EDITS:
        raw = io.open(path, "r", encoding="utf-8", newline="").read()
        crlf = raw.count("\r\n") == raw.count("\n")
        txt = raw.replace("\r\n", "\n") if crlf else raw
        assert txt.count(old) == 1, "%s 锚点命中 %d 次" % (path, txt.count(old))
        txt = txt.replace(old, new)
        io.open(path, "w", encoding="utf-8", newline="").write(
            txt.replace("\n", "\r\n") if crlf else txt)
        print("%s OK" % path)


if __name__ == "__main__":
    main()
