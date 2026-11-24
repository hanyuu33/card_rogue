# -*- coding: utf-8 -*-
"""R756 回归补丁（第二批）：公用卡 25→26 + 苹果「回满」→「回 20%」。"""
import io


def load(p):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def save(p, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "%s: count=%d" % (tag, n)
    print("  ok  %s" % tag)
    return s.replace(old, new)


P = "scripts/test_engine.gd"
s, c = load(P)

# --- 公用 25 → 26（代偿 9252 class 留空）
s = rep(s, '\t\t\tand int(dr_cls_count.get("", 0)) == 25,',
        '\t\t\tand int(dr_cls_count.get("", 0)) == 26,', "engine/公用 26 (a)")

s = rep(s, "（期望 76 / 66 / 75 / 75，R689 森林精魄 +2",
        "（期望 78 / 66 / 75 / 75 / 公用 26，R756 公用 +1（代偿 9252）；R689 森林精魄 +2",
        "engine/角色统计文案")

s = rep(s, "\t# R632：删工事罐子 9158（class 留空）→ 公用 26 → 25。\n"
           "	check(int(dr_cls_count.get(\"\", 0)) == 25,",
        "\t# R632：删工事罐子 9158（class 留空）→ 公用 26 → 25；R756 代偿 9252 → 26。\n"
        "	check(int(dr_cls_count.get(\"\", 0)) == 26,", "engine/公用 26 (b)")

s = rep(s, "+ R473 乱打 9215 / 飞踢 9216 / 冲拳 9217（实际 %d）",
        "+ R473 乱打 9215 / 飞踢 9216 / 冲拳 9217 + R756 代偿 9252（实际 %d）",
        "engine/公用清单文案")

s = rep(s, "\t# R632：删工事罐子 9158（class 留空）→ 公用 26 → 25。\n"
           "	check(int(r45_cls_count.get(\"\", 0)) == 25,",
        "\t# R632：删工事罐子 9158（class 留空）→ 公用 26 → 25；R756 代偿 9252 → 26。\n"
        "	check(int(r45_cls_count.get(\"\", 0)) == 26,", "engine/公用 26 (c)")

# --- 苹果：回满 → 回 20%
s = rep(s, "\t# ② 苹果：立即 +7 最大生命并回复满（R445：14 → 7）\n",
        "\t# ② 苹果：立即 +7 最大生命，并回复 20% 最大生命值（R445：14 → 7；R756：不再回满）\n",
        "engine/苹果②注释")

s = rep(s,
        "\tcheck(RunState.max_hp == 57 and RunState.hp == 57,\n"
        "\n"
        "\t\t\t\"苹果：最大生命 50 → 57（+7）并回复满（%d/%d）\" % [RunState.hp, RunState.max_hp])\n",
        "\tcheck(RunState.max_hp == 57 and RunState.hp == 38,\n"
        "\n"
        "\t\t\t\"R756 苹果：最大生命 50 → 57（+7），生命 20 → 38（+7 与 20%% × 57 = 11）（%d/%d）\"\n"
        "\n"
        "\t\t\t% [RunState.hp, RunState.max_hp])\n",
        "engine/苹果②断言")

s = rep(s, "\t# 苹果仍是「主动道具回血」口径：+7 上限并回满（R445 削弱，来源同 R244）\n",
        "\t# 苹果仍是「主动道具回血」口径：+7 上限并回复 20% 最大生命值（R756，来源同 R244）\n",
        "engine/苹果R244注释")

s = rep(s,
        "\tcheck(RunState.hp == RunState.max_hp and r244_hp0 < RunState.hp,\n"
        "\n"
        "\t\t\t\"R444/445 苹果：+7 最大生命并回满（%d → %d/%d）\"\n",
        "\tcheck(RunState.hp == mini(RunState.max_hp,\n"
        "\t\t\tr244_hp0 + RunState.APPLE_MAX_HP + int(round(RunState.max_hp * RunState.APPLE_HEAL_PCT)))\n"
        "\t\t\tand RunState.hp < RunState.max_hp and r244_hp0 < RunState.hp,\n"
        "\n"
        "\t\t\t\"R444/445/756 苹果：+7 最大生命并回复 20%% 最大生命值（%d → %d/%d）\"\n",
        "engine/苹果R244断言")

save(P, s, c)
print("all test patches (2) applied")
