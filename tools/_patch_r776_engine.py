# -*- coding: utf-8 -*-
"""R776 引擎补丁：激励乐章 9267 / 管风琴 9268。

game_engine.gd 是 CRLF，锚点一律带 \\r\\n。
"""
import io

P = "scripts/game_engine.gd"
s = io.open(P, "rb").read().decode("utf-8")


def rep(old, new, tag):
    global s
    n = s.count(old)
    assert n == 1, "%s 锚点命中 %d 次" % (tag, n)
    s = s.replace(old, new)
    print("OK", tag)


# ── ① 常量区 ─────────────────────────────────────────────
rep(
    'const CALL_COST_GAP:= 1   # 找的盟友 = 本卡费用 +1\r\n',
    'const CALL_COST_GAP:= 1   # 找的盟友 = 本卡费用 +1\r\n'
    '# R776 激励乐章（9267，吟游诗人 1 费普通技能）：**本回合**场上所有己方盟友 +N 力量；\r\n'
    '# 「原本职业不属于自己」的盟友（`_other_class_card()` 同一判据）改为 +M。\r\n'
    '# ⚠️ 力量记在 `Placement.atk_buff_turn`（本回合力量，回合结束自然清零）——\r\n'
    '#    卡面写的是「本回合」，**不是** `totem_atk` 那层要挂到战斗结束的持续 buff。\r\n'
    'const ANTHEM_ID:= 9267\r\n'
    'const ANTHEM_POWER:= 4         # 同职业盟友 +4\r\n'
    'const ANTHEM_POWER_OTHER:= 6   # 原本职业非自己的盟友 +6\r\n'
    '# R776 管风琴（9268，吟游诗人 4 费史诗工事 · 0 力量 / 射程 7 / 19 生命）：\r\n'
    '#   ① **攻击时**从卡组取一张随机技能卡入手，该卡本回合费用 -1 —— 直接复用\r\n'
    '#      `_fetch_skill_card()`（赤狐 9034 的唯一口），不另写一份取牌逻辑；\r\n'
    '#   ② 在场时**每使用一张技能卡** → 对所有敌人 3 点伤害（场上每有一台各结算一份）。\r\n'
    '# ② 的挂点在 `_note_card_played()`（出牌唯一收尾口），与疾风 / 潜影者同一排。\r\n'
    'const ORGAN_ID:= 9268\r\n'
    'const ORGAN_TRAIT:= "管风琴"\r\n'
    'const ORGAN_SKILL_DMG:= 3       # 每用一张技能卡，对所有敌人 3 伤\r\n',
    "常量区",
)

# ── ② 两个新函数（挂在 _fetch_skill_card 之后，正好同族）────────
rep(
    '\taction.emit("fetch_skill", {"card": copy, "discount": discount,\r\n'
    '\t\t"source": source})\r\n',
    '\taction.emit("fetch_skill", {"card": copy, "discount": discount,\r\n'
    '\t\t"source": source})\r\n'
    '\r\n'
    '\r\n'
    'func _inspire_anthem(side: String) -> String :\r\n'
    '\t## 激励乐章（9267）：**本回合**场上所有己方盟友力量 +4；\r\n'
    '\t## 「原本职业不属于自己」的盟友（`_other_class_card()` 唯一判据）改为 +6。\r\n'
    '\t## ⚠️ 只认 `kind == "盟友"` —— 卡面写的是「所有盟友」，工事 / 场地不算。\r\n'
    '\t## 力量记在 `atk_buff_turn`：回合结束由 `end_turn()` 统一清零 →「本回合」名副其实。\r\n'
    '\tvar n:= 0\r\n'
    '\tvar other:= 0\r\n'
    '\tfor cell: Vector2i in state.board:\r\n'
    '\t\tvar p: Placement = state.unit_at(cell)\r\n'
    '\t\tif p == null or p.owner != side or p.card.kind != "盟友":\r\n'
    '\t\t\tcontinue\r\n'
    '\t\tvar gain:= ANTHEM_POWER_OTHER if _other_class_card(p.card) else ANTHEM_POWER\r\n'
    '\t\tp.atk_buff_turn += gain\r\n'
    '\t\tn += 1\r\n'
    '\t\tif gain == ANTHEM_POWER_OTHER:\r\n'
    '\t\t\tother += 1\r\n'
    '\t\t_log("激励乐章：%s 本回合力量 +%d（现 %d）"\r\n'
    '\t\t\t\t% [p.card.card_name, gain, p.effective_power()])\r\n'
    '\tif n <= 0:\r\n'
    '\t\treturn "场上没有盟友"\r\n'
    '\taction.emit("inspire", {"count": n, "other": other, "side": side})\r\n'
    '\treturn "场上 %d 个盟友本回合力量 +%d（其中 %d 个其他职业盟友 +%d）" \\\r\n'
    '\t\t\t% [n, ANTHEM_POWER, other, ANTHEM_POWER_OTHER]\r\n'
    '\r\n'
    '\r\n'
    'func _organ_attack_fetch(p: Placement) -> void :\r\n'
    '\t## 管风琴（9268）**攻击时**：从卡组取一张随机技能卡入手，该卡本回合费用 -1。\r\n'
    '\t## 取牌本体走 `_fetch_skill_card()`（赤狐 9034 的唯一口）—— 减费口径 / 手牌满进弃牌区 /\r\n'
    '\t## `turn_card_discount` 按实例记账全部沿用，不在这里重写一份。\r\n'
    '\tif p == null or p.owner != SIDE_SELF or not p.card.traits.has(ORGAN_TRAIT):\r\n'
    '\t\treturn\r\n'
    '\t_fetch_skill_card("管风琴")\r\n'
    '\r\n'
    '\r\n'
    'func _organ_tick(side: String, played: CardData) -> void :\r\n'
    '\t## 管风琴（9268）**在场时**：该方每使用一张**技能卡** → 对所有敌人各 3 点伤害。\r\n'
    '\t## 场上几台就打几份（与魔法塔 / 飓风咆哮「每张各结算一次」同一口径）。\r\n'
    '\t## ⚠️ 只认 `played.kind == "技能"`：盟友 / 工事 / 效果卡都触发不了它。\r\n'
    '\t## 伤害是**定值 3**，不套 `_spell_dmg()` —— 卡面写死「3 点」，被荧光草 / 魔法塔\r\n'
    '\t## 抬成 4 点就不是这张卡了（与疾风「不叠符文」同一条纪律的更强版本）。\r\n'
    '\tif played == null or played.kind != "技能":\r\n'
    '\t\treturn\r\n'
    '\tvar organs:= 0\r\n'
    '\tfor cell: Vector2i in state.board:\r\n'
    '\t\tvar p: Placement = state.unit_at(cell)\r\n'
    '\t\tif p != null and p.owner == side and p.card.traits.has(ORGAN_TRAIT):\r\n'
    '\t\t\torgans += 1\r\n'
    '\tif organs <= 0:\r\n'
    '\t\treturn\r\n'
    '\tvar foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF\r\n'
    '\tvar cells: Array[Vector2i] = []\r\n'
    '\tfor cell2: Vector2i in state.board:\r\n'
    '\t\tvar q: Placement = state.unit_at(cell2)\r\n'
    '\t\tif q != null and q.owner == foe:\r\n'
    '\t\t\tcells.append(cell2)\r\n'
    '\tcells.sort()\r\n'
    '\tvar total:= ORGAN_SKILL_DMG * organs\r\n'
    '\tif cells.is_empty():\r\n'
    '\t\t_damage_player(foe, total, "管风琴")\r\n'
    '\t\t_log("管风琴：%d 台 × %d 伤 → 场上没有敌人，直击对方 HP %d 点"\r\n'
    '\t\t\t\t% [organs, ORGAN_SKILL_DMG, total])\r\n'
    '\t\taction.emit("organ", {"hits": 0, "dmg": total, "hp": total, "organs": organs})\r\n'
    '\t\treturn\r\n'
    '\tvar hit:= 0\r\n'
    '\tfor cell3 in cells:\r\n'
    '\t\tvar q2: Placement = state.unit_at(cell3)\r\n'
    '\t\tif q2 == null:\r\n'
    '\t\t\tcontinue\r\n'
    '\t\t_hit_unit(q2, total, "管风琴")\r\n'
    '\t\thit += 1\r\n'
    '\t_log("管风琴：使用「%s」→ %d 个敌人各受 %d 点伤害（%d 台）"\r\n'
    '\t\t\t% [played.card_name, hit, total, organs])\r\n'
    '\t_destroy_dead()\r\n'
    '\taction.emit("organ", {"hits": hit, "dmg": total, "organs": organs})\r\n',
    "两个新函数",
)

# ── ③ 技能分支 ──────────────────────────────────────────
rep(
    '\t\tCALL_ID:\r\n',
    '\t\tANTHEM_ID:\r\n'
    '\t\t\t# 激励乐章（9267，R776，吟游诗人 1 费普通技能）：\r\n'
    '\t\t\t#   **本回合**场上所有己方盟友 +4 力量；原本职业不属于自己的盟友改为 +6。\r\n'
    '\t\t\t# * 无目标（`target_mode` = none）：全场一次性结算，不读 `target`；\r\n'
    '\t\t\t# * 「其他职业」判据复用 `_other_class_card()`（有归属 + 不是当前职业，公用卡不算）；\r\n'
    '\t\t\t# * 场上没有盟友 → 照常吃掉这 1 费并回报「场上没有盟友」，不开空面板。\r\n'
    '\t\t\treturn _inspire_anthem(side)\r\n'
    '\t\tCALL_ID:\r\n',
    "技能分支",
)

# ── ④ 出牌收尾钩子 ───────────────────────────────────────
rep(
    '\t_gale_tick(side, played)\r\n'
    '\t_lurker_tick(side, played)\r\n',
    '\t_gale_tick(side, played)\r\n'
    '\t_organ_tick(side, played)\r\n'
    '\t_lurker_tick(side, played)\r\n',
    "出牌收尾钩子",
)

# ── ⑤ 攻击钩子（attack / attack_hp 两处）───────────────────
rep(
    '\t\t_attack_gain_energy(side, attacker)   # 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时 +1 费\r\n',
    '\t\t_attack_gain_energy(side, attacker)   # 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时 +1 费\r\n'
    '\t\t_organ_attack_fetch(attacker)   # 管风琴（9268，R776）：攻击时从卡组取一张技能卡入手\r\n',
    "attack 钩子",
)
rep(
    '\t_attack_gain_energy(side, attacker)   # 地狱咏唱者 / 黑暗祭坛：直击 HP 也算一次攻击\r\n',
    '\t_attack_gain_energy(side, attacker)   # 地狱咏唱者 / 黑暗祭坛：直击 HP 也算一次攻击\r\n'
    '\t_organ_attack_fetch(attacker)   # 管风琴（9268，R776）：直击 HP 也算一次攻击\r\n',
    "attack_hp 钩子",
)

io.open(P, "wb").write(s.encode("utf-8"))
print("game_engine.gd 写回完成")
