# -*- coding: utf-8 -*-
"""R780 顺手修：R777 彩虹诗「费用各 -1」断言抽到特例卡就必红（CRLF 原样）。

根因（与 R780 的赫尔墨斯改动无关，是既有测试的脆弱点）：
  * 回响 9102 卡面写死「费用最低为 1」→ `_cost_floor()` 压住彩虹诗的 -1，1 减完仍是 1；
  * 魔像术 9079「每回合第一次用技能时，手卡的这张卡本回合费用 -1」→ 叠加彩虹诗 = -2（4 → 2）。
所以随机抽到这两张时，`cost_of == cost - 1` 必然不成立，两条都报「异常」。

修法：卡面下限高于期望值时跳过精确比较（下限优先于彩虹诗）；
其余情况用「不高于期望」判 —— 自带减费的卡只会更便宜，不该算坏。
"""
import io
import sys

p = "E:/work/card_rogue/scripts/test_engine.gd"
NL = "\r\n"
s = io.open(p, encoding="utf-8", newline="").read()

old = NL.join([
    "\t\tr777_got_cls[c5.card_class] = true",
    "\t\tif r777_e.cost_of(c5) != maxi(0, c5.cost - 1):",
    '\t\t\tr777_cost_bad.append("%s %d→%d" % [c5.card_name, c5.cost, r777_e.cost_of(c5)])',
])

new = NL.join([
    "\t\tr777_got_cls[c5.card_class] = true",
    "\t\t# R780 顺手修：原来写死 `cost_of == cost - 1`，随机抽到两张特例就必红 ——",
    "\t\t#   * 回响 9102 卡面「费用最低为 1」→ `_cost_floor()` 压住彩虹诗的 -1（1 → 仍是 1）；",
    "\t\t#   * 魔像术 9079「每回合第一次用技能时，手卡这张本回合 -1」→ 叠加彩虹诗 = -2（4 → 2）。",
    "\t\t#   前者是卡面写死的下限（优先于彩虹诗）→ 跳过精确比较；",
    "\t\t#   后者只会更便宜 → 用「不高于期望」判，不该算坏。",
    "\t\tvar r777_expect: int = maxi(0, c5.cost - 1)",
    "\t\tif r777_e._cost_floor(c5, 0) > r777_expect:",
    "\t\t\tcontinue",
    "\t\tif r777_e.cost_of(c5) > r777_expect:",
    '\t\t\tr777_cost_bad.append("%s %d→%d" % [c5.card_name, c5.cost, r777_e.cost_of(c5)])',
])

n = s.count(old)
if n != 1:
    sys.exit("锚点命中 %d 次（应为 1）" % n)

s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8", newline="").write(s)

s2 = io.open(p, encoding="utf-8", newline="").read()
print("新判据存在 =", "var r777_expect: int = maxi(0, c5.cost - 1)" in s2)
print("旧判据残留 =", "if r777_e.cost_of(c5) != maxi(0, c5.cost - 1):" in s2)
print("CRLF =", s2.count("\r\n"), "裸LF =", s2.count("\n") - s2.count("\r\n"))
