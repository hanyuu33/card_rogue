# -*- coding: utf-8 -*-
"""R634：骑士剑 6053 从 +2 改为 +1（全部）。

店长口径：「骑士剑从＋2改为＋1（全部）」

数值本身只住在两个常量里（`KNIGHT_SWORD_ATK` / `KNIGHT_SWORD_SPELL`），
三处调用点（`_sync_knight_sword` / `_relic_on_enter_buffs` / `_spell_dmg`）全读常量，
所以改常量即改全部逻辑；这里同时把注释与 relics.json 的说明文案清零到 +1，
免得代码是 +1、界面还写 +2。

⚠️ 不动 `test_engine.gd`：R383 段的断言全部引用 `GameEngine.KNIGHT_SWORD_ATK/SPELL`
   常量，自动跟随；而该文件此刻有并行线（R633）未提交改动，整文件 add 会把别人的
   活一起带走。它那两行「+2」注释属于历史描述，不影响判据。
"""
CRLF = chr(13) + chr(10)


def patch(path, pairs, nl="\r\n"):
    b = open(path, "rb").read()
    t = b.decode("utf-8")
    for old, new, tag in pairs:
        assert t.count(old) == 1, (path, tag, t.count(old))
        t = t.replace(old, new, 1)
    open(path, "wb").write(t.encode("utf-8"))
    b2 = open(path, "rb").read()
    print("%-30s CRLF %d  bareLF %d" % (path, b2.count(b"\r\n"),
                                        b2.count(b"\n") - b2.count(b"\r\n")))


# ① game_engine.gd：常量（唯一数值口）+ 四处说明
patch("scripts/game_engine.gd", [
    (
        "# R383 骑士剑（6053，剧情解锁道具）：本场战斗**第一次击杀敌人**之后 ——" + CRLF
        + "#   己方所有盟友 +2 力量（与竖琴同一套持续 buff 写法），己方技能伤害 +2。" + CRLF
        + "const KNIGHT_SWORD_RELIC_ID:= 6053" + CRLF
        + "const KNIGHT_SWORD_ATK:= 2" + CRLF
        + "const KNIGHT_SWORD_SPELL:= 2" + CRLF,
        "# R383 骑士剑（6053，剧情解锁道具）：本场战斗**第一次击杀敌人**之后 ——" + CRLF
        + "#   己方所有盟友 +1 力量（与竖琴同一套持续 buff 写法），己方技能伤害 +1。" + CRLF
        + "# ⚠️ R634（店长口径「骑士剑从＋2改为＋1（全部）」）：数值**只住在这两个常量里**。" + CRLF
        + "#    三处调用（`_sync_knight_sword` / `_relic_on_enter_buffs` / `_spell_dmg`）全读它，" + CRLF
        + "#    以后调数值只改这里；判据里别再写死数字（写死就会「代码 +1、某处 +2」）。" + CRLF
        + "const KNIGHT_SWORD_RELIC_ID:= 6053" + CRLF
        + "const KNIGHT_SWORD_ATK:= 1" + CRLF
        + "const KNIGHT_SWORD_SPELL:= 1" + CRLF,
        "const",
    ),
    (
        "\t## R383 骑士剑（6053）：**本场战斗的第一次击杀** —— 己方所有盟友 +2 力量、" + CRLF
        + "\t## 己方技能伤害 +2，持续到本场战斗结束。" + CRLF,
        "\t## R383 骑士剑（6053）：**本场战斗的第一次击杀** —— 己方所有盟友 +1 力量、" + CRLF
        + "\t## 己方技能伤害 +1，持续到本场战斗结束（R634 起两个常量统一为 1）。" + CRLF,
        "onkill",
    ),
    (
        "\t# R383 骑士剑（6053）：本场第一次击杀之后**才上场**的己方盟友同样 +2 力量。" + CRLF,
        "\t# R383 骑士剑（6053）：本场第一次击杀之后**才上场**的己方盟友同样 +1 力量。" + CRLF,
        "enter",
    ),
    (
        "\t# R383 骑士剑（6053）：本场第一次击杀之后，己方技能伤害 +2（固定值，只加一次）。" + CRLF,
        "\t# R383 骑士剑（6053）：本场第一次击杀之后，己方技能伤害 +1（固定值，只加一次）。" + CRLF,
        "spell",
    ),
    (
        "\t# R383 骑士剑（6053）：「战斗内第一次击杀一个敌人」→ 己方全体 +2 力量 / 技能 +2。" + CRLF,
        "\t# R383 骑士剑（6053）：「战斗内第一次击杀一个敌人」→ 己方全体 +1 力量 / 技能 +1。" + CRLF,
        "kill",
    ),
])

# ② battle_scene.gd：事件分支注释（文案本身读事件的 amount/spell，不写死）
patch("scripts/battle_scene.gd", [
    (
        "\t\t\t# 骑士剑（6053，R383）：本场第一次击杀 → 己方盟友 +2 力量、技能伤害 +2。" + CRLF,
        "\t\t\t# 骑士剑（6053，R383）：本场第一次击杀 → 己方盟友 +1 力量、技能伤害 +1"
        + "（R634 起）。" + CRLF
        + "\t\t\t# 数值取事件里的 `amount` / `spell`（引擎常量），界面不写死。" + CRLF,
        "bs",
    ),
])

# ③ placement.gd：buff 字段来源注释
patch("scripts/placement.gd", [
    (
        "## R383 骑士剑（6053）：「己方所有盟友 +2 力量」与竖琴是**同一套持续 buff 写法** ——" + CRLF,
        "## R383 骑士剑（6053）：「己方所有盟友 +1 力量」（R634 起）与竖琴是"
        "**同一套持续 buff 写法** ——" + CRLF,
        "plc",
    ),
])

# ④ relics.json：道具说明（界面读的就是它）
patch("relics.json", [
    (
        '"desc": "战斗中第一次击杀敌人后，己方所有盟友 +2 力量，己方技能伤害 +2'
        '（本场战斗内持续）。",',
        '"desc": "战斗中第一次击杀敌人后，己方所有盟友 +1 力量，己方技能伤害 +1'
        '（本场战斗内持续）。",',
        "json",
    ),
], nl="\n")
print("done")
