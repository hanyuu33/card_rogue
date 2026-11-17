# -*- coding: utf-8 -*-
"""R787 收尾②：火墙术 / 黑暗嵌合 / 鸭血三条用例里跟着真源走的期望值。

火墙术这条尤其要看清：`pass_dmg = _spell_dmg(side, FIRE_WALL_PASS_DMG=7, card)` ——
**经过灼烧也吃附魔**，所以 +8 时是 7+8=15（不是固定的 17）；
`cap = 14 + (dmg - 14) = 22`，于是第二次穿只补 22-15=7，「只补 7」这句恰好不变。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
CRLF = "\r\n"


def rep(s, old, new, tag):
    n = s.count(old)
    if n == 0 and s.count(new) >= 1:
        return s
    if n != 1:
        print("FAIL [%s] 命中 %d 次：%r" % (tag, n, old[:70]))
        sys.exit(1)
    return s.replace(old, new, 1)


P = "scripts/test_engine.gd"
s = io.open(ROOT + P, encoding="utf-8", newline="").read()

# ── R387 火墙术 ──
s = rep(s,
        "\t# ---- ③ 火墙术：单位上限跟着纸面伤害走（R510 后附魔 +10 → 即时 24 / 经过 17 / 上限 24）----",
        "\t# ---- ③ 火墙术：单位上限跟着纸面伤害走（R787 后附魔 +8 → 即时 22 / 经过 15 / 上限 22）----",
        "r387-head")
s = rep(s,
        "check(r387_walk.health == r387_walk_hp - 17,",
        "check(r387_walk.health == r387_walk_hp - 15,", "r387-pass")
s = rep(s,
        "\"R387 火墙术：附魔 +10 → 经过灼烧 17（%d→%d）\"",
        "\"R387 火墙术：附魔 +8 → 经过灼烧 15（%d→%d）\"", "r387-pass-msg")
s = rep(s,
        "check(r387_walk.health == r387_walk_hp - 24,",
        "check(r387_walk.health == r387_walk_hp - 22,", "r387-cap")
s = rep(s,
        "\"R387 火墙术：上限 24（14+10）→ 第二次只补 7，合计 -%d（旧版会卡在 14）\"",
        "\"R387 火墙术：上限 22（14+8）→ 第二次只补 7，合计 -%d（旧版会卡在 14）\"",
        "r387-cap-msg")

# ── R580 黑暗嵌合：附魔增量按 r580_fb.power 算（现在是 8）──
s = rep(s,
        "\t\tcheck(r580_foe.health == r580_hp0 - r580_prev.power - 10,",
        "\t\tcheck(r580_foe.health == r580_hp0 - r580_prev.power - 8,", "r580-assert")
s = rep(s,
        "\"R580 黑暗嵌合：对所有敌人造成产物力量值 %d + 附魔 10 点伤害\" % r580_prev.power)",
        "\"R580 黑暗嵌合：对所有敌人造成产物力量值 %d + 附魔 8 点伤害\" % r580_prev.power)",
        "r580-msg")

# ── R636 鸭血：副本继承的附魔数值 ──
s = rep(s,
        "and int((RunState.deck_mods[3] as Dictionary).get(\"power\", 0)) == 10,",
        "and int((RunState.deck_mods[3] as Dictionary).get(\"power\", 0)) == 8,",
        "r636-a")
s = rep(s,
        "\"R636 鸭血：复制品完整继承附魔（damage → 副本也 +10 攻）\"",
        "\"R636 鸭血：复制品完整继承附魔（damage → 副本也 +8 攻）\"", "r636-a-msg")
s = rep(s,
        "\tcheck(int((RunState.deck_mods[0] as Dictionary).get(\"power\", 0)) == 10,",
        "\tcheck(int((RunState.deck_mods[0] as Dictionary).get(\"power\", 0)) == 8,",
        "r636-b")
s = rep(s,
        "\t(RunState.deck_mods[3] as Dictionary)[\"power\"] = 10",
        "\t(RunState.deck_mods[3] as Dictionary)[\"power\"] = 8", "r636-c")

bad = s.count("\n") - s.count(CRLF)
if bad != 0:
    print("FAIL EOL 裸 LF %d" % bad)
    sys.exit(1)
io.open(ROOT + P, "w", encoding="utf-8", newline="").write(s)
print("OK", P)
