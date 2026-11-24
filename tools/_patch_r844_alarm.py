# -*- coding: utf-8 -*-
"""R844：鸭子闹钟 6085 删除旧双效果，改为第 5 回合全体敌人 33 伤。"""
import io

ROOT = "E:/work/card_rogue/"


def load(rel):
    raw = io.open(ROOT + rel, encoding="utf-8", newline="").read()
    crlf = raw.count("\r\n")
    lf_only = raw.count("\n") - crlf
    assert lf_only == 0 or crlf == 0, "%s 行尾混杂 crlf=%d lf=%d" % (rel, crlf, lf_only)
    return raw.replace("\r\n", "\n"), crlf > 0


def save(rel, text, was_crlf):
    out = text.replace("\n", "\r\n") if was_crlf else text
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(out)
    print("WROTE %-36s %s" % (rel, "CRLF" if was_crlf else "LF"))


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次" % (tag, n)
    print("  OK " + tag)
    return text.replace(old, new)


def section(text, start, end, new, tag):
    assert text.count(start) == 1, "[%s] 起点非唯一" % tag
    assert text.count(end) == 1, "[%s] 终点非唯一" % tag
    i = text.index(start)
    j = text.index(end, i)
    return sub(text, text[i:j], new, tag)


ZH_DESC = "每场战斗的第 5 回合，对所有敌人造成 33 点伤害。"

# ① 中文数据源与四语道具文案。
t, c = load("relics.json")
t = sub(t, '"desc": "每场战斗的第 2 回合，抽 1 张卡并获得 1 点费用；第 5 回合起，技能伤害 +1。"',
        '"desc": "%s"' % ZH_DESC, "relics.json 6085")
save("relics.json", t, c)

translations = {
    "i18n/noncard_zh_canonical.json": (
        '"6085": {"name": "鸭子闹钟", "desc": "每场战斗的第 2 回合，抽 1 张卡并获得 1 点费用；第 5 回合起，技能伤害 +1。"}',
        '"6085": {"name": "鸭子闹钟", "desc": "%s"}' % ZH_DESC),
    "i18n/noncard_en.json": (
        '"6085": {"name": "Duck Alarm Clock", "desc": "On the 2nd turn of every battle, draw 1 card and gain 1 Energy. From the 5th turn onward, skill damage +1."}',
        '"6085": {"name": "Duck Alarm Clock", "desc": "On the 5th turn of every battle, deal 33 damage to all enemies."}'),
    "i18n/noncard_ja.json": (
        '"6085": {"name": "アヒルの目覚まし時計", "desc": "毎戦闘の 2 ターン目にカードを 1 枚引き、コストを 1 得る。5 ターン目以降、スキルのダメージ +1。"}',
        '"6085": {"name": "アヒルの目覚まし時計", "desc": "毎戦闘の 5 ターン目に、すべての敵に 33 ダメージを与える。"}'),
    "i18n/noncard_es.json": (
        '"6085": {"name": "Despertador de pato", "desc": "En el 2.º turno de cada combate, roba 1 carta y obtén 1 de Coste. A partir del 5.º turno, el daño de habilidad +1."}',
        '"6085": {"name": "Despertador de pato", "desc": "En el 5.º turno de cada combate, inflige 33 de daño a todos los enemigos."}'),
}
for rel, (old, new) in translations.items():
    t, c = load(rel)
    t = sub(t, old, new, rel + " 6085")
    save(rel, t, c)

# ② 池子注释同步当前口径；id、来源、归属和试玩基线不动。
t, c = load("scripts/relic_repo.gd")
t = sub(t,
        '\t## R824（店长口径）：新增「鸭子闹钟」6085（第 2 回合 +1 费 + 抽 1 张；第 5 回合起技能 +1），\n'
        '\t##       归鸭绅士 → 全量 9→10 件，鸭绅士 4→5 件，卷卷仍是 5 件。',
        '\t## R824（店长口径）：新增「鸭子闹钟」6085，归鸭绅士 → 全量 9→10 件，鸭绅士 4→5 件。\n'
        '\t## R844：6085 旧双效果全部删除，改为每场战斗第 5 回合对全体敌人各造成 33 点伤害；池子不变。',
        "relic_repo 6085 当前口径")
save("scripts/relic_repo.gd", t, c)

# ③ 引擎：旧常量、第 2 回合发费抽牌、第 5 回合起技能加伤全部移除。
t, c = load("scripts/game_engine.gd")
t = sub(t,
        '# R824 鸭子闹钟（6085，二层起始池 · 鸭绅士）：**第 2 个我方回合** +1 费 + 多抽 1 张；\n'
        '#   **第 5 个我方回合起**技能伤害 +1。\n'
        '# 两条都只读 `turn_number`（本场战斗内计数），**不落存档、不加新字段** ——\n'
        '# 读档续战由引擎快照里已有的 turn_number 还原，与鹿首标本同口径。\n'
        'const DUCK_ALARM_RELIC_ID:= 6085\n'
        'const DUCK_ALARM_TURN:= 2\n'
        'const DUCK_ALARM_ENERGY:= 1\n'
        'const DUCK_ALARM_DRAW:= 1\n'
        'const DUCK_ALARM_SPELL_FROM:= 5\n'
        'const DUCK_ALARM_SPELL:= 1',
        '# R844 鸭子闹钟（6085，二层起始池 · 鸭绅士）：原第 2 回合加费抽牌、\n'
        '# 第 5 回合起技能 +1 全部删除；只在第 5 个我方回合对全体敌方单位各造成 33 点伤害。\n'
        '# 只读本场 `turn_number`，不加存档字段；恰好第 5 回合触发一次，第 6 回合不会续发。\n'
        'const DUCK_ALARM_RELIC_ID:= 6085\n'
        'const DUCK_ALARM_TURN:= 5\n'
        'const DUCK_ALARM_DMG:= 33',
        "6085 常量重写")
t = sub(t,
        '\n\t\t# R824 鸭子闹钟（6085）：**第 2 个我方回合**发一次 —— +1 费、多抽 1 张。\n'
        '\t\t# 费用与鸭翼 / 鸭语耳环同一条 `state.energy` 发放口；抽牌走 `extra_draw`\n'
        '\t\t# （唯一抽牌口 `_draw_many`，所以必须在它之前加）。判据只看 `turn_number`。\n'
        '\t\tif self_relics.has(DUCK_ALARM_RELIC_ID) and turn_number == DUCK_ALARM_TURN:\n'
        '\t\t\tstate.energy += DUCK_ALARM_ENERGY\n'
        '\t\t\textra_draw += DUCK_ALARM_DRAW\n'
        '\t\t\t_log("鸭子闹钟：第 %d 回合，费用 +%d、多抽 %d 张"\n'
        '\t\t\t\t\t% [DUCK_ALARM_TURN, DUCK_ALARM_ENERGY, DUCK_ALARM_DRAW])\n'
        '\t\t\taction.emit("relic", {"id": DUCK_ALARM_RELIC_ID,\n'
        '\t\t\t\t\t"text": "鸭子闹钟：第 %d 回合费用 +%d / 多抽 %d 张"\n'
        '\t\t\t\t\t\t\t% [DUCK_ALARM_TURN, DUCK_ALARM_ENERGY, DUCK_ALARM_DRAW]})\n',
        '\n', "删除第 2 回合加费抽牌")
t = sub(t,
        '\t# R824 鸭子闹钟（6085）：第 5 个我方回合**起**技能伤害 +1（固定值，不是累计层数）。\n'
        '\t# 与鹿首标本 / 骑士剑同属固定加成，会被后面的快速符文百分比一起放大。\n'
        '\tif self_relics.has(DUCK_ALARM_RELIC_ID) and turn_number >= DUCK_ALARM_SPELL_FROM:\n'
        '\t\tout += DUCK_ALARM_SPELL\n',
        '', "删除第 5 回合起技能加伤")
t = sub(t,
        '\t\t_sun_ring_tick()\n\t\tif over:\n\t\t\treturn\n\t\t_log("── 我方第 %d 回合：费用重置为 %d%s%s%s%s%s%s%s%s（共 %d），抽 %d 张" % [',
        '\t\t_sun_ring_tick()\n'
        '\t\tif over:\n'
        '\t\t\treturn\n'
        '\t\t# R844 鸭子闹钟：排在召唤 / 成长 / 战吼之后，这一刻在场的全体敌人都吃。\n'
        '\t\t# 若 33 伤直接清场，和太阳指环一样立刻收尾，不再写一条已结束战斗的回合头。\n'
        '\t\t_duck_alarm_tick()\n'
        '\t\tif over:\n'
        '\t\t\treturn\n'
        '\t\t_log("── 我方第 %d 回合：费用重置为 %d%s%s%s%s%s%s%s%s（共 %d），抽 %d 张" % [',
        "第 5 回合接线")
helper = '''func _duck_alarm_tick() -> void:
\t## R844 鸭子闹钟（6085）：只在第 5 个我方回合触发一次，对全体敌方单位各 33 点伤害。
\t## 不走 `_spell_dmg()`：它不是技能，不吃技能加伤 / 快速符文；护盾、减伤与光环照常。
\t## 格子先排序，命中与死亡结算同太阳指环 / 风妖精；只打单位，不直击敌方 HP。
\tif not self_relics.has(DUCK_ALARM_RELIC_ID) or turn_number != DUCK_ALARM_TURN:
\t\treturn
\tvar cells: Array[Vector2i] = []
\tfor cell: Vector2i in state.board:
\t\tvar q: Placement = state.board[cell]
\t\tif q != null and q.owner == SIDE_OPPONENT and q.health > 0:
\t\t\tcells.append(cell)
\tif cells.is_empty():
\t\t_log("鸭子闹钟：第 5 回合，场上没有敌方单位，效果落空")
\t\treturn
\tcells.sort()
\tvar hits: Array[Vector2i] = []
\tfor c: Vector2i in cells:
\t\tvar q2: Placement = state.board.get(c, null)
\t\tif q2 == null or q2.health <= 0:
\t\t\tcontinue
\t\t_hit_unit(q2, DUCK_ALARM_DMG, "鸭子闹钟")
\t\thits.append(c)
\t_destroy_dead()
\t_log("鸭子闹钟：第 5 回合，对 %d 名敌人各造成 %d 点伤害"
\t\t\t% [hits.size(), DUCK_ALARM_DMG])
\taction.emit("relic", {"id": DUCK_ALARM_RELIC_ID,
\t\t\t"text": "鸭子闹钟：全体敌人 -%d" % DUCK_ALARM_DMG})


func _sun_ring_tick() -> int:'''
t = sub(t, 'func _sun_ring_tick() -> int:', helper, "新增第 5 回合全体伤害口")
save("scripts/game_engine.gd", t, c)

# ④ 测试：保留 R824 的数据 / 池子 / 试玩回归，旧机制用例由 R844 整段替换。
t, c = load("scripts/test_engine.gd")
t = sub(t, '\t_test_r842()\n', '\t_test_r842()\n\t_test_r844()\n', "登记 _test_r844")
t = sub(t,
        '\t## R824（店长口径）：① 试玩版**改为也出鸭绅士**；② 新增二层鸭绅士道具「鸭子闹钟」6085 ——\n'
        '\t## 每场战斗的第 2 回合抽 1 张卡并获得 1 点费用；第 5 回合起技能伤害 +1。\n'
        '\t##\n'
        '\t## 两条最容易写漏的：\n'
        '\t##   · 6085 归鸭绅士之后，卷卷池必须**不含**它 —— 否则归属白分，两边都抽得到；\n'
        '\t##   · 「第 5 回合起」是**从第 5 回合开始一直有效**，不是「只在第 5 回合」。',
        '\t## R824：试玩版也出鸭绅士；新增二层鸭绅士道具「鸭子闹钟」6085。\n'
        '\t## R844：6085 的旧双效果全部删除，改为第 5 回合对全体敌人各造成 33 点伤害。\n'
        '\t## 这里继续守数据 / 池子 / 试玩可达性；新机制的完整时序由 `_test_r844()` 守。',
        "R824 测试头更新")
t = sub(t,
        '\tcheck(r824_rel.desc.contains("第 2 回合") and r824_rel.desc.contains("第 5 回合")\n\n'
        '\t\t\tand r824_rel.desc.contains("技能伤害 +1"),\n\n'
        '\t\t\t"R824 文案：写着第 2 回合 / 第 5 回合起技能 +1（%s）" % r824_rel.desc)\n\n'
        '\t# 常量为唯一数值来源：文案里的 2 / 5 / +1 与引擎常量必须一致\n\n'
        '\tcheck(GameEngine.DUCK_ALARM_RELIC_ID == 6085 and GameEngine.DUCK_ALARM_TURN == 2\n\n'
        '\t\t\tand GameEngine.DUCK_ALARM_ENERGY == 1 and GameEngine.DUCK_ALARM_DRAW == 1\n\n'
        '\t\t\tand GameEngine.DUCK_ALARM_SPELL_FROM == 5 and GameEngine.DUCK_ALARM_SPELL == 1,\n\n'
        '\t\t\t"R824 常量：6085 / 第 2 回合 / +1 费 / 抽 1 / 第 5 回合起技能 +1")',
        '\tcheck(r824_rel.desc == "%s",\n\n'
        '\t\t\t"R844 文案：第 5 回合 / 全体敌人 / 33 伤（%%s）" %% r824_rel.desc)\n\n'
        '\t# 常量为唯一数值来源：5 / 33 与卡面一致，旧的 ENERGY / DRAW / SPELL 常量均删除。\n\n'
        '\tcheck(GameEngine.DUCK_ALARM_RELIC_ID == 6085 and GameEngine.DUCK_ALARM_TURN == 5\n\n'
        '\t\t\tand GameEngine.DUCK_ALARM_DMG == 33,\n\n'
        '\t\t\t"R844 常量：6085 / 第 5 回合 / 全体 33 伤")' % ZH_DESC,
        "R824 数据断言更新")
t = section(t, '\t# ── ③ 引擎：第 1 回合不发，第 2 回合 +1 费 + 多抽 1 张，第 3 回合恢复 ──',
            'func _test_r825() -> void:',
            '\t# ── ③ 机制：R844 已删除旧双效果，完整时序 / 多目标 / 对照组见 `_test_r844()` ──\n\n',
            "移除 R824 旧机制断言")

new_test = '''func _test_r844() -> void:
\t## R844（店长口径）：鸭子闹钟 6085 原效果全部删除，改为每场战斗第 5 回合
\t## 对所有敌人造成 33 点伤害。这里锁：第 2 回合不再加费抽牌、第 5 回合只发一次、
\t## 第 6 回合不续发、技能不再 +1、多目标与己方不误伤、无道具对照不触发、致死清场。
\tvar repo := CardRepo.load_json()
\tvar eng := _new_engine(_ordered_deck(), 100, 100, -1, false)
\teng.self_relics = [GameEngine.DUCK_ALARM_RELIC_ID]
\teng.start_game()

\t# 两个敌方靶子 + 一个己方靶子； traits 清空，排除嘲讽 / 亡语 / 减伤干扰。
\tvar pa := repo.get_card(1013).to_dict()
\tpa["traits"] = []
\tvar pb := repo.get_card(1051).to_dict()
\tpb["traits"] = []
\tvar pc := repo.get_card(8003).to_dict()
\tpc["traits"] = []
\tvar foe_a: Placement = eng.state.place(CardData.from_dict(pa),
\t\t\tVector2i(1, 0), GameEngine.SIDE_OPPONENT)
\tvar foe_b: Placement = eng.state.place(CardData.from_dict(pb),
\t\t\tVector2i(1, 1), GameEngine.SIDE_OPPONENT)
\tvar friend: Placement = eng.state.place(CardData.from_dict(pc),
\t\t\tVector2i(5, 0), GameEngine.SIDE_SELF)
\tcheck(foe_a != null and foe_b != null and friend != null,
\t\t\t"R844 布场：两个敌人与一个己方单位都上场")
\tfoe_a.health = 100
\tfoe_b.health = 100
\tfriend.health = 100

\t# 第 2 回合：旧的 +1 费 / 多抽 1 张必须彻底消失，也不能提前造成伤害。
\teng.end_turn()
\teng.end_turn()
\tcheck(eng.turn_number == 2 and eng.state.energy == RunState.energy_per_turn(),
\t\t\t"R844 旧效果：第 2 回合不再加费（实际 %d）" % eng.state.energy)
\tcheck(eng.state.hand.size() == RunState.hand_draw_per_turn(),
\t\t\t"R844 旧效果：第 2 回合不再多抽（实际 %d 张）" % eng.state.hand.size())
\tcheck(foe_a.health == 100 and foe_b.health == 100 and friend.health == 100,
\t\t\t"R844 时序：第 2 回合没有提前敲响")

\t# 第 4 回合仍无伤害、无技能加成。
\tfor _r844_i in 2:
\t\teng.end_turn()
\t\teng.end_turn()
\tcheck(eng.turn_number == 4 and foe_a.health == 100 and foe_b.health == 100,
\t\t\t"R844 时序：第 4 回合敌人仍未掉血")
\tcheck(eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,
\t\t\t"R844 旧效果：第 4 回合技能仍为 10")

\t# 第 5 回合：两个敌人各 -33，己方不动，技能也不再加 1。
\teng.end_turn()
\teng.end_turn()
\tcheck(eng.turn_number == 5 and foe_a.health == 67 and foe_b.health == 67,
\t\t\t"R844 主效果：第 5 回合全体敌人各 33 伤（%d / %d）"
\t\t\t% [foe_a.health, foe_b.health])
\tcheck(friend.health == 100, "R844 主效果：己方单位不误伤")
\tcheck(eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,
\t\t\t"R844 旧效果：第 5 回合技能不再 +1（实际 %d）"
\t\t\t% eng._spell_dmg(GameEngine.SIDE_SELF, 10))
\tcheck(eng.state.energy == RunState.energy_per_turn()
\t\t\tand eng.state.hand.size() == RunState.hand_draw_per_turn(),
\t\t\t"R844 主效果：第 5 回合只造成伤害，不附带费用或抽牌")

\t# 第 6 回合不续发，更不是「第 5 回合起每回合」。
\teng.end_turn()
\teng.end_turn()
\tcheck(eng.turn_number == 6 and foe_a.health == 67 and foe_b.health == 67,
\t\t\t"R844 次数：第 6 回合不再造成 33 伤（%d / %d）"
\t\t\t% [foe_a.health, foe_b.health])
\tcheck(eng._spell_dmg(GameEngine.SIDE_SELF, 10) == 10,
\t\t\t"R844 旧效果：第 6 回合也没有技能 +1")

\t# 无道具对照：同样推进到第 5 回合，靶子必须满血。
\tvar ctrl := _new_engine([], 100, 100, -1, false)
\tctrl.start_game()
\tvar cp := repo.get_card(1013).to_dict()
\tcp["traits"] = []
\tvar ctrl_foe: Placement = ctrl.state.place(CardData.from_dict(cp),
\t\t\tVector2i(1, 0), GameEngine.SIDE_OPPONENT)
\tctrl_foe.health = 100
\tfor _r844_j in 4:
\t\tctrl.end_turn()
\t\tctrl.end_turn()
\tcheck(ctrl.turn_number == 5 and ctrl_foe.health == 100,
\t\t\t"R844 对照：没有闹钟时第 5 回合不掉血")

\t# 33 血靶子会被打到 0，并由统一死亡收口移除；不会留一具 0 血单位在场上。
\tvar lethal := _new_engine([], 100, 100, -1, false)
\tlethal.self_relics = [GameEngine.DUCK_ALARM_RELIC_ID]
\tlethal.start_game()
\tvar lp := repo.get_card(1013).to_dict()
\tlp["traits"] = []
\tvar lethal_foe: Placement = lethal.state.place(CardData.from_dict(lp),
\t\t\tVector2i(1, 0), GameEngine.SIDE_OPPONENT)
\tlethal_foe.health = 33
\tfor _r844_k in 4:
\t\tlethal.end_turn()
\t\tlethal.end_turn()
\tcheck(lethal.turn_number == 5 and lethal_foe.health <= 0
\t\t\tand lethal.state.unit_at(Vector2i(1, 0)) == null,
\t\t\t"R844 死亡：33 伤致死会走统一清场")

\t# 源码锁：旧常量与旧日志不能留在引擎里，避免只改卡面而机制仍暗跑。
\tvar src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
\tcheck_src(not src.contains("DUCK_ALARM_ENERGY") and not src.contains("DUCK_ALARM_DRAW")
\t\t\tand not src.contains("DUCK_ALARM_SPELL") and not src.contains("DUCK_ALARM_SPELL_FROM"),
\t\t\t"R844 源码锁：加费 / 抽牌 / 技能加伤的旧常量全部删除")
'''
t = sub(t, '\tRunState.boss_beaten = r835_saved_boss\n',
        '\tRunState.boss_beaten = r835_saved_boss\n\n\n' + new_test, "追加 _test_r844")
save("scripts/test_engine.gd", t, c)
print("R844 PATCH OK")
