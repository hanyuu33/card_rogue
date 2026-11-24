# -*- coding: utf-8 -*-
"""R780：赫尔墨斯（9140）新增「每回合最多受到 20 点伤害」。

设计要点（为什么这么落）：
  * 「受到」= **最终实际扣掉的血**，所以封顶点必须在
    `_hit_unit` / `_op_deal_damage` 两处 `p.health -= dmg` 的**前一格**，
    也就是正义背刺倍率乘完之后 —— 放进 `_unit_damage_taken()` 会被倍率突破，
    而且那里护甲还没扣完（护甲吃掉的量不该占额度）。
  * 累计只记**实际扣掉的血**：被护甲吸收、被免疫挡掉的部分不占额度。
  * 回合口径 = `turn_number`（整轮，只在 SIDE_SELF 回合开始 +1）。
    换回合后 `turn_dmg_key` 失配 → 额度自动归零，**不需要在回合开始扫全场清零**
    （漏扫一只就是 `Invalid access` 之外的静默错账）。
  * 预览 `preview_hit_damage()` 必须同步镜像（R384 纪律：预览值 == 实际扣血值）。

⚠️ placement.gd / game_engine.gd 是 CRLF，cards.json 是 CRLF，i18n 四语是 LF。
   全部 newline="" 原样读写，插入行显式用 \\r\\n。
⚠️ 每个替换都 assert count == 1，落盘后**回读校验**（R778b 的教训：apply 报 OK 不代表生效）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"

fails = []


def read(p):
    return io.open(p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag, n=1):
    c = s.count(old)
    if c != n:
        fails.append("%s: 期望 %d 处，实际 %d 处 —— %r" % (tag, n, c, old[:70]))
        return s
    return s.replace(old, new, n)


# ══════════════════════════════════════════════════════════════
# 1) placement.gd：两个新字段 + _SAVE_FIELDS
# ══════════════════════════════════════════════════════════════
p = ROOT + "scripts/placement.gd"
s = read(p)
anchor = "var action_growth_turns: int = 0   # 距离下次成长还剩几个回合"
block = NL.join([
    "",
    "## R780 赫尔墨斯（9140）：「每回合最多受到 20 点伤害」。",
    "## `turn_dmg_taken` = 本回合**已实际扣掉的血**（护甲吸收 / 被免掉的不计）；",
    "## `turn_dmg_key` = 记账时的 `GameEngine.turn_number`（整轮口径：只有我方回合开始才 +1）。",
    "## 换回合后 key 失配 → `GameEngine._cap_turn_damage()` 自动从 0 重算，",
    "## 所以**不需要在回合开始扫全场清零**（漏扫一只就是静默错账）。",
    "## 只记 Placement、**绝不烤进 CardData**：敌方关卡单位用的是卡库共享实例。",
    "var turn_dmg_taken: int = 0",
    "var turn_dmg_key: int = -1",
])
s = rep(s, anchor, anchor + block, "placement 字段插入")
s = rep(s,
        '\t"action_growth_turns", "summon_haste", "night_owl_weak", "boss_phase",',
        '\t"action_growth_turns", "summon_haste", "night_owl_weak", "boss_phase",'
        '\r\n\t"turn_dmg_taken", "turn_dmg_key",',
        "placement _SAVE_FIELDS")
write(p, s)

# ══════════════════════════════════════════════════════════════
# 2) game_engine.gd：常量 + 函数 + 两个落地口 + 预览镜像
# ══════════════════════════════════════════════════════════════
p = ROOT + "scripts/game_engine.gd"
s = read(p)

s = rep(s,
        "const HECATE_ARMOR_GAIN:= 10        # R778：每回合给随机一个**其他**友方单位 +10 护甲",
        "const HECATE_ARMOR_GAIN:= 10        # R778：每回合给随机一个**其他**友方单位 +10 护甲"
        + NL + "const HERMES_ID:= 9140              # R780：赫尔墨斯（第二层精英·赫尔墨斯的试炼）"
        + NL + "const HERMES_DMG_CAP:= 20           # R780：每回合最多受到 20 点伤害",
        "engine 常量")

func_block = NL.join([
    "func _cap_turn_damage(p: Placement, dmg: int) -> int:",
    "\t## R780 赫尔墨斯（9140）：「每回合最多受到 20 点伤害」。",
    "\t## 位置 = **两个扣血落地口的最后一格**（`p.health -= dmg` 的**前一格**，",
    "\t## 正义背刺倍率乘完之后）：卡面说的是「受到」，也就是**最终真正扣掉的血** ——",
    "\t## 倍率 / 减伤 / 护甲全算完才封顶，顺序反了会被 `dmg *= jb_mult` 突破上限。",
    "\t## ⚠️ 不放进 `_unit_damage_taken()`：那里只是减伤链，护甲还没扣；",
    "\t##    而且 `_op_deal_damage()` 是先过那条链、再自己扣血，两条口共用一个函数",
    "\t##    才能保证「单目标技能」和「普攻 / 多格效果」口径一致。",
    "\t## ⚠️ 累计只记**实际扣掉的血**：护甲吸收掉的、被一次性能量屏障免掉的不占额度，",
    "\t##    否则「有护甲反而更快打满上限」。",
    "\t## 回合口径 = `turn_number`（整轮；只有我方回合开始 +1）—— 换回合后 key 失配，",
    "\t## 额度自动归零，不用扫全场重置。",
    "\tif p == null or p.card == null or dmg <= 0 or p.card.id != HERMES_ID:",
    "\t\treturn dmg",
    "\tif p.turn_dmg_key != turn_number:",
    "\t\tp.turn_dmg_key = turn_number",
    "\t\tp.turn_dmg_taken = 0",
    "\tvar left:= HERMES_DMG_CAP - p.turn_dmg_taken",
    "\tif left <= 0:",
    "\t\t_log(\"%s：本回合已受满 %d 点伤害，这一下全免\" % [p.card.card_name, HERMES_DMG_CAP])",
    "\t\treturn 0",
    "\tif dmg > left:",
    "\t\t_log(\"%s：本回合伤害上限 %d 点 —— 这一下 %d 封顶到 %d\" % [",
    "\t\t\tp.card.card_name, HERMES_DMG_CAP, dmg, left])",
    "\t\tdmg = left",
    "\tp.turn_dmg_taken += dmg",
    "\treturn dmg",
    "",
    "",
])
s = rep(s,
        'func _unit_damage_taken(p: Placement, amount: int, kind := "") -> int:',
        func_block + 'func _unit_damage_taken(p: Placement, amount: int, kind := "") -> int:',
        "engine 函数插入")

# 落地口 ①：_hit_unit
s = rep(s,
        "\tdmg *= jb_mult" + NL + "\tp.health -= dmg",
        "\tdmg *= jb_mult"
        + NL + "\tdmg = _cap_turn_damage(p, dmg)   # R780 赫尔墨斯：本回合累计上限（倍率之后才封顶）"
        + NL + "\tp.health -= dmg",
        "engine _hit_unit 封顶")

# 落地口 ②：_op_deal_damage
s = rep(s,
        "\t\tamount2 *= jb_mult2" + NL + "\t\tp.health -= amount2",
        "\t\tamount2 *= jb_mult2"
        + NL + "\t\tamount2 = _cap_turn_damage(p, amount2)   # R780 赫尔墨斯：同 `_hit_unit` 同一条"
        + NL + "\t\tp.health -= amount2",
        "engine _op_deal_damage 封顶")

# 预览镜像
prev_old = ("\t# ⑤ 护甲：**只算吸收掉多少**，绝不真的扣（`_unit_damage_taken` 里是会扣的）"
            + NL + "\tif dmg > 0 and p.armor > 0:"
            + NL + "\t\tdmg = maxi(0, dmg - p.armor)"
            + NL + '\treturn {"dmg": dmg, "tag": ""}')
prev_new = ("\t# ⑤ 护甲：**只算吸收掉多少**，绝不真的扣（`_unit_damage_taken` 里是会扣的）"
            + NL + "\tif dmg > 0 and p.armor > 0:"
            + NL + "\t\tdmg = maxi(0, dmg - p.armor)"
            + NL + "\t# ⑤b R780 赫尔墨斯：「每回合最多受到 20 点伤害」——与 `_cap_turn_damage()`"
            + NL + "\t#    **同一位置**（护甲之后 = 最终落地值）、同一份累计读数。"
            + NL + "\t#    换回合判据同引擎：`turn_dmg_key` 失配就当作 0。"
            + NL + "\tif dmg > 0 and p.card.id == HERMES_ID:"
            + NL + "\t\tvar taken:= p.turn_dmg_taken if p.turn_dmg_key == turn_number else 0"
            + NL + "\t\tdmg = maxi(0, mini(dmg, HERMES_DMG_CAP - taken))"
            + NL + '\treturn {"dmg": dmg, "tag": ""}')
s = rep(s, prev_old, prev_new, "engine 预览镜像")

write(p, s)

# ══════════════════════════════════════════════════════════════
# 3) 文本：cards.json（CRLF）+ 四语（LF）
# ══════════════════════════════════════════════════════════════
ZH_OLD = "每过3回合，行动次数+1。"
ZH_NEW = "每过3回合，行动次数+1。每回合最多受到 20 点伤害。"

s = read(ROOT + "cards.json")
s = rep(s, ZH_OLD, ZH_NEW, "cards.json 9140")
write(ROOT + "cards.json", s)

TEXT = {
    "i18n/zh_canonical.json": (ZH_OLD, ZH_NEW),
    "i18n/cards_en.json": (
        "May act twice per turn. Every 3 turns, its number of actions increases by 1.",
        "May act twice per turn. Every 3 turns, its number of actions increases by 1. "
        "Takes at most 20 damage each turn.",
    ),
    "i18n/cards_ja.json": (
        "毎ターン2回行動可能。3ターンごとに、行動回数+1。",
        "毎ターン2回行動可能。3ターンごとに、行動回数+1。1ターンに受けるダメージは最大20。",
    ),
    "i18n/cards_es.json": (
        "Puede actuar dos veces por turno. Cada 3 turnos, su número de acciones aumenta en 1.",
        "Puede actuar dos veces por turno. Cada 3 turnos, su número de acciones aumenta en 1. "
        "No puede recibir más de 20 de daño por turno.",
    ),
}
for path, (old, new) in TEXT.items():
    s = read(ROOT + path)
    s = rep(s, old, new, path)
    write(ROOT + path, s)

if fails:
    print("补丁未全部命中：")
    print("\n".join(fails))
    sys.exit(1)

# ══════════════════════════════════════════════════════════════
# 4) 回读校验（不看 OK，看文件里到底有没有）
# ══════════════════════════════════════════════════════════════
chk = []
pl = read(ROOT + "scripts/placement.gd")
chk.append(("placement 字段", "var turn_dmg_taken: int = 0" in pl, pl.count("var turn_dmg_taken: int = 0")))
chk.append(("placement 字段2", "var turn_dmg_key: int = -1" in pl, pl.count("var turn_dmg_key: int = -1")))
chk.append(("placement SAVE", '"turn_dmg_taken", "turn_dmg_key",' in pl, pl.count('"turn_dmg_taken"')))
chk.append(("placement 裸LF", pl.count("\n") - pl.count("\r\n") == 0, pl.count("\n") - pl.count("\r\n")))

ge = read(ROOT + "scripts/game_engine.gd")
chk.append(("engine 常量", "const HERMES_DMG_CAP:= 20" in ge, ge.count("const HERMES_DMG_CAP")))
chk.append(("engine 函数", "func _cap_turn_damage(" in ge, ge.count("func _cap_turn_damage(")))
chk.append(("engine 调用", ge.count("_cap_turn_damage(p, dmg)") + ge.count("_cap_turn_damage(p, amount2)"), 0))
chk.append(("engine 预览", "p.card.id == HERMES_ID" in ge, ge.count("p.card.id == HERMES_ID")))
chk.append(("engine 裸LF", ge.count("\n") - ge.count("\r\n") == 0, ge.count("\n") - ge.count("\r\n")))

cj = read(ROOT + "cards.json")
chk.append(("cards.json", ZH_NEW in cj, cj.count(ZH_NEW)))
chk.append(("cards.json 裸LF", cj.count("\n") - cj.count("\r\n") == 0, cj.count("\n") - cj.count("\r\n")))

for path, (old, new) in TEXT.items():
    s = read(ROOT + path)
    chk.append((path + " 新句", new in s, s.count(new)))
    chk.append((path + " 旧句残留", old not in s or path.endswith("zh_canonical.json"),
                s.count(old)))
    chk.append((path + " 裸CRLF", s.count("\r\n") == 0, s.count("\r\n")))

bad = []
print("=== 回读校验 ===")
for tag, ok, n in chk:
    if tag == "engine 调用":
        ok = (n == 2)
    if not ok:
        bad.append((tag, n))
    print(("  OK  " if ok else "  FAIL") + " %-22s %s" % (tag, n))

if bad:
    print("\n回读失败：", bad)
    sys.exit(1)
print("\n[R780] 全部命中并回读通过")
