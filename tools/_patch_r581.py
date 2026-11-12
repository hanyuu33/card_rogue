# -*- coding: utf-8 -*-
"""R581 标记系口径微调（可重跑 / --check-only 预检）。

四处改动：
  1. 死亡预告 9225：结算顺序改为「先 6 伤、再标记」（这一下不再吃自己新放的标记）。
  2. 致命 9226：无标记时随机标一个格子（非己方 HP 行），括号限定不写入卡面文本。
  3. 死亡预告 / 恐惧投射稀有度 0(普通) → 1(稀有)。
  4. 其余不变 —— 恐惧化身 9230 仍是「随机标一个敌人所在格」，空场不标。

判据：源码/卡表/测试三层同源；所有文件纯 CRLF，补丁用内容锚点（不依赖行号）。
用法：python tools/_patch_r581.py --check-only   # 只预检锚点计数
      python tools/_patch_r581.py                # 落补丁（可重复执行）
"""
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK_ONLY = "--check-only" in sys.argv


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def L(*lines):
    """按行拼 GDScript / JSON 片段，统一转 CRLF。"""
    return crlf("\n".join(lines))


def T(line):
    return crlf(line)


# ---------------------------------------------------------------- cards.json
C_9225_RAR_OLD = L(
    '      "id": 9225,',
    '      "name": "死亡预告",',
    '      "kind": "技能",',
    '      "cost": 1,',
    '      "power": 0,',
    '      "health": 0,',
    '      "attack_range": 0,',
    '      "move_speed": 0,',
    '      "rarity": 0,')
C_9225_RAR_NEW = C_9225_RAR_OLD.replace('      "rarity": 0,', '      "rarity": 1,')

C_9229_RAR_OLD = L(
    '      "id": 9229,',
    '      "name": "恐惧投射",',
    '      "kind": "技能",',
    '      "cost": 2,',
    '      "power": 0,',
    '      "health": 0,',
    '      "attack_range": 0,',
    '      "move_speed": 0,',
    '      "rarity": 0,')
C_9229_RAR_NEW = C_9229_RAR_OLD.replace('      "rarity": 0,', '      "rarity": 1,')

C_9225_TEXT_OLD = T('      "effect_text": "标记目标所在的格子，然后对目标造成 6 点伤害。",')
C_9225_TEXT_NEW = T('      "effect_text": "对目标造成 6 点伤害，然后标记目标所在的格子。",')

C_9226_TEXT_OLD = T('      "effect_text": "被标记的敌人受到的所有伤害提升 50%（替代标记本身的加伤）。打出时若场上没有标记，随机标记一个敌人所在的格子。",')
C_9226_TEXT_NEW = T('      "effect_text": "被标记的敌人受到的所有伤害提升 50%（替代标记本身的加伤）。打出时若场上没有标记，随机标记一个格子。",')

# ------------------------------------------------------------ game_engine.gd
G_OMEN_CONST_OLD = T('const DEATH_OMEN_ID:= 9225    # 死亡预告：1 费普通技能 · 标记目标所在格 + 6 伤')
G_OMEN_CONST_NEW = T('const DEATH_OMEN_ID:= 9225    # 死亡预告：1 费稀有技能 · 先 6 伤再标记目标所在格')

G_PROJ_CONST_OLD = T('const FEAR_PROJECTION_ID:= 9229   # 恐惧投射：2 费普通技能 · 次元')
G_PROJ_CONST_NEW = T('const FEAR_PROJECTION_ID:= 9229   # 恐惧投射：2 费稀有技能 · 次元')

G_OMEN_BLOCK_OLD = L(
    '\t\tDEATH_OMEN_ID:',
    '\t\t\t# 死亡预告 9225（R503）：1 费普通；**先标记目标所在格、再打 6 伤**。',
    '\t\t\t# 顺序是有意的：这一下本身就吃标记的加伤（新标记 +1 → 落地 7）。',
    '\t\t\tvar dom_p := _target_placement(side, target)',
    '\t\t\tif dom_p == null:',
    '\t\t\t\treturn "（死亡预告：需要指定一个目标）"',
    '\t\t\t_place_mark(_cell_of(dom_p), side, "死亡预告")',
    '\t\t\treturn str(_op_deal_damage(side, _spell_dmg(side, DEATH_OMEN_DMG, card),',
    '\t\t\t\t\t_cell_of(dom_p)))')
G_OMEN_BLOCK_NEW = L(
    '\t\tDEATH_OMEN_ID:',
    '\t\t\t# 死亡预告 9225（R503 → R581）：1 费稀有；**先打 6 伤、再标记目标所在格**。',
    '\t\t\t# 顺序是有意的：这一下不吃自己刚放下的新标记（目标原本已被标记时仍按旧标记结算）。',
    '\t\t\t# ⚠️ 格子要在伤害前缓存：这一下可能把目标打死，之后 `_cell_of()` 就找不到它了。',
    '\t\t\tvar dom_p := _target_placement(side, target)',
    '\t\t\tif dom_p == null:',
    '\t\t\t\treturn "（死亡预告：需要指定一个目标）"',
    '\t\t\tvar dom_cell: Vector2i = _cell_of(dom_p)',
    '\t\t\tvar dom_s: String = str(_op_deal_damage(side, _spell_dmg(side, DEATH_OMEN_DMG, card),',
    '\t\t\t\t\tdom_cell))',
    '\t\t\t_place_mark(dom_cell, side, "死亡预告")',
    '\t\t\treturn dom_s')

G_PROJ_COMMENT_OLD = T('\t\t\t# 恐惧投射 9229（R503）：2 费普通 · 次元；标记目标所在格 + 本回合力量 -11；')
G_PROJ_COMMENT_NEW = T('\t\t\t# 恐惧投射 9229（R503 → R581）：2 费稀有 · 次元；标记目标所在格 + 本回合力量 -11；')

G_DMG_TABLE_OLD = T('\t9225: 6,     # 死亡预告（先标记再打，实际会多吃标记的加伤）')
G_DMG_TABLE_NEW = T('\t9225: 6,     # 死亡预告（R581 先打再标记，这一下不吃自己新放的标记）')

G_CALL_OLD = L(
    '\t# R503 致命 9226 / R504 恐惧化身 9230：打出时若场上没有标记，随机标记一个敌人所在的格子',
    '\tif card.id == FATAL_ID:',
    '\t\t_auto_mark_if_none("致命")')
G_CALL_NEW = L(
    '\t# R581 致命 9226：若无标记，随机标一个格子（引擎排除己方 HP 行，卡面不写这条限定）；',
    '\t# R504 恐惧化身 9230：若无标记，仍随机标一个敌人所在格（口径一字未改）。',
    '\tif card.id == FATAL_ID:',
    '\t\t_auto_mark_if_none("致命", true)')

G_AUTO_OLD = L(
    'func _auto_mark_if_none(why: String) -> void :',
    '\t## 「若场上没有标记，随机标记一个敌人所在的格子」—— 致命 9226 / 恐惧化身 9230 共用',
    '\t## （R504 从 `_fatal_enter()` 下放，判据一字未改）。',
    '\t## 空场（一个敌人都没有）→ 什么都不做：卡面写的是「随机标记一个**敌人**的格子」，',
    '\t## 没敌人就没得标，别偷偷标个空格让玩家白赚回合。',
    '\tif state.has_mark():',
    '\t\t_log("%s：场上已有标记，不再随机标记" % why)',
    '\t\treturn',
    '\tvar cells: Array[Vector2i] = []',
    '\tfor cell: Vector2i in state.board:',
    '\t\tvar q: Placement = state.unit_at(cell)',
    '\t\tif q != null and q.owner == SIDE_OPPONENT and q.health > 0:',
    '\t\t\tcells.append(cell)',
    '\tif cells.is_empty():',
    '\t\t_log("%s：场上没有敌人 → 不标记" % why)',
    '\t\treturn',
    '\tcells.sort()   # 固定顺序：同种子 / 回放一致',
    '\tvar pick: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]',
    '\t_place_mark(pick, SIDE_SELF, why)')
G_AUTO_NEW = L(
    'func _auto_mark_if_none(why: String, any_cell := false) -> void :',
    '\t## 「若场上没有标记，随机放一个标记」—— 致命 9226 / 恐惧化身 9230 共用唯一写入口。',
    '\t## R581 拆成两种候选口径（**恐惧化身那一路一字未改**）：',
    '\t##   * any_cell = true（致命）：卡面「随机标记一个格子」→ 候选是整块棋盘，',
    '\t##     只排除**己方 HP 行** `back_row(SIDE_SELF)`（= forbidden_row_for(敌方)，',
    '\t##     敌方单位的移动禁区，标在那儿永远没人踩得到）。不要求格上有敌人。',
    '\t##     ⚠️ 这条限定**不写进卡面文本**，只落在引擎判据里。',
    '\t##   * any_cell = false（恐惧化身）：卡面「随机标记一个敌人所在的位置」→ 只收活敌人格，',
    '\t##     空场（一个敌人都没有）什么都不做，别偷偷标个空格让玩家白赚回合。',
    '\tif state.has_mark():',
    '\t\t_log("%s：场上已有标记，不再随机标记" % why)',
    '\t\treturn',
    '\tvar cells: Array[Vector2i] = []',
    '\tif any_cell:',
    '\t\tvar self_hp_row: int = back_row(SIDE_SELF)',
    '\t\t# ⚠️ `state.board` 只存「有单位的格子」，不是整块棋盘 —— 空场时它是空的。',
    '\t\t# 致命要的是「随机一个格子」，所以按 BOARD_ROWS × BOARD_COLS 全盘铺开。',
    '\t\tfor r in FieldState.BOARD_ROWS:',
    '\t\t\tif r == self_hp_row:',
    '\t\t\t\tcontinue',
    '\t\t\tfor c in FieldState.BOARD_COLS:',
    '\t\t\t\tcells.append(Vector2i(r, c))',
    '\telse:',
    '\t\tfor cell: Vector2i in state.board:',
    '\t\t\tvar q: Placement = state.unit_at(cell)',
    '\t\t\tif q != null and q.owner == SIDE_OPPONENT and q.health > 0:',
    '\t\t\t\tcells.append(cell)',
    '\tif cells.is_empty():',
    '\t\tif any_cell:',
    '\t\t\t_log("%s：没有可标记的格子 → 不标记" % why)',
    '\t\telse:',
    '\t\t\t_log("%s：场上没有敌人 → 不标记" % why)',
    '\t\treturn',
    '\tcells.sort()   # 固定顺序：同种子 / 回放一致',
    '\tvar pick: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]',
    '\t_place_mark(pick, SIDE_SELF, why)')

# ------------------------------------------------------------ test_engine.gd
T_FIVE_A_OLD = T('r503_omen.cost == 1 and r503_omen.kind == "技能"')
T_FIVE_A_NEW = T('r503_omen.cost == 1 and r503_omen.rarity == 1 and r503_omen.kind == "技能"')
T_FIVE_B_OLD = T('r503_proj != null and r503_proj.cost == 2')
T_FIVE_B_NEW = T('r503_proj != null and r503_proj.cost == 2 and r503_proj.rarity == 1')
T_FIVE_DESC_OLD = T('"R503 配套五卡：死亡预告 1 费 / 致命 3 费史诗效果 / 死神降临 2 费稀有 / 恐惧之影 3 费 3-14 程1 / 恐惧投射 2 费 · 次元")')
T_FIVE_DESC_NEW = T('"R581 配套五卡：死亡预告 1 费稀有 / 致命 3 费史诗效果 / 死神降临 2 费稀有 / 恐惧之影 3 费 3-14 程1 / 恐惧投射 2 费稀有 · 次元")')

T_OMEN_COMMENT_OLD = T('\t# ① 死亡预告：**先标记、再打 6 伤** —— 这一下自己就吃新标记的 +1（6 → 7）')
T_OMEN_COMMENT_NEW = T('\t# ① R581 死亡预告：**先打 6 伤、再标记** —— 这一下不吃自己刚放下的标记（6 → 54）')
T_OMEN_CHECK_OLD = L(
    '\tcheck(r503_f1.health == 60 - (GameEngine.DEATH_OMEN_DMG + 1),',
    '\t\t"R503 死亡预告：6 伤 + 新标记的 +1 = 7（60 → %d）" % r503_f1.health)')
T_OMEN_CHECK_NEW = L(
    '\tcheck(r503_f1.health == 60 - GameEngine.DEATH_OMEN_DMG,',
    '\t\t"R581 死亡预告：先 6 伤再标记 → 这一下不吃新标记（60 → %d）" % r503_f1.health)')

T_FATAL_HEAD_OLD = T('\t# ⑥ 致命：被标记的敌人改为「额外 50%」（替代 +N）；空场打出时随机标一个敌人格')
T_FATAL_HEAD_NEW = T('\t# ⑥ 致命：被标记的敌人改为「额外 50%」（替代 +N）；空场打出时随机标一个格子')
T_FATAL_CASE_OLD = T('\t# 空场（没有标记）打出 → 随机标住一个敌人所在格')
T_FATAL_CASE_NEW = T('\t# R581 空场（没有标记）打出 → 随机标一个非己方 HP 行的格子（不再限定敌人格）')

T_FATAL_CHECK_OLD = L(
    '\tcheck(r503_e.state.mark_cell() == Vector2i(2, 2),',
    '\t\t"R503 致命：打出时场上没有标记 → 自动标记唯一的敌人所在格")')
T_FATAL_CHECK_NEW = L(
    '\tvar r581_mark: Vector2i = r503_e.state.mark_cell()',
    '\tcheck(r503_e.state.has_mark()',
    '\t\t\tand r581_mark.x >= 0 and r581_mark.x < FieldState.BOARD_ROWS',
    '\t\t\tand r581_mark.y >= 0 and r581_mark.y < FieldState.BOARD_COLS',
    '\t\t\tand r581_mark.x != GameEngine.back_row(GameEngine.SIDE_SELF),',
    '\t\t"R581 致命：无标记 → 随机标一个非己方 HP 行的棋盘格（实际 %s）" % str(r581_mark))',
    '\t# R581：卡面改成「随机标记一个格子」→ 场上一个敌人也没有也照样标',
    '\tvar r581_e0 := _new_engine([], 30, 30, -1, false)',
    '\tr581_e0.start_game(1)',
    '\tr581_e0.state.energy = 9',
    '\tr581_e0.state.hand.append(CardData.from_dict(r503_fatal.to_dict()))',
    '\tr581_e0.use_effect(0)',
    '\tcheck(r581_e0.state.has_mark()',
    '\t\t\tand r581_e0.state.mark_cell().x != GameEngine.back_row(GameEngine.SIDE_SELF),',
    '\t\t"R581 致命：空场无敌人 → 仍随机标一个非 HP 行的格子")',
    '\t# R581：恐惧化身 9230 口径不变 —— 空场无敌人时不标记',
    '\tvar r581_inc: CardData = r503_repo.get_card(GameEngine.FEAR_INCARNATE_ID)',
    '\tvar r581_e1 := _new_engine([], 30, 30, -1, false)',
    '\tr581_e1.start_game(1)',
    '\tr581_e1.state.energy = 9',
    '\tr581_e1.state.hand.append(CardData.from_dict(r581_inc.to_dict()))',
    '\tr581_e1.use_effect(0)',
    '\tcheck(not r581_e1.state.has_mark(),',
    '\t\t"R581 恐惧化身：口径不变，空场无敌人 → 不标记")',
    '\t# R581 卡面保真锁：文本回到卡表源头，括号限定没混进文本',
    '\tcheck(r503_omen.effect_text == "对目标造成 6 点伤害，然后标记目标所在的格子。"',
    '\t\t\tand r503_fatal.effect_text.find("随机标记一个格子。") >= 0',
    '\t\t\tand r503_fatal.effect_text.find("敌人所在的格子") < 0',
    '\t\t\tand r503_fatal.effect_text.find("HP") < 0',
    '\t\t\tand r503_fatal.effect_text.find("己方") < 0,',
    '\t\t"R581 卡面保真：死亡预告先伤后标 / 致命只写「随机标记一个格子」")',
    '\t# R581 源码锁：两种随机口径与先伤后标都收在引擎唯一口',
    '\tvar r581_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")',
    "\tcheck_src(r581_src.contains('_auto_mark_if_none(\"致命\", true)')",
    '\t\t\tand r581_src.contains("any_cell := false")',
    '\t\t\tand r581_src.contains("var self_hp_row: int = back_row(SIDE_SELF)")',
    '\t\t\tand r581_src.contains("for r in FieldState.BOARD_ROWS")',
    '\t\t\tand r581_src.contains("var dom_s: String = str(_op_deal_damage("),',
    '\t\t"R581 源码锁：致命走任意格 / 死亡预告先伤后标")')

T_KEEP_MARK_OLD = L(
    '\tcheck(r503_e.state.mark_cell() == Vector2i(2, 2),',
    '\t\t"R503 致命：已有标记 → 保持原标记，不重摇")',
)
T_KEEP_MARK_NEW = L(
    '\tcheck(r503_e.state.mark_cell() == r581_mark,',
    '\t\t"R581 致命：已有标记 → 保持原标记，不重摇（落点 %s）" % str(r581_mark))',
)
T_FATAL_SETUP_OLD = L(
    '\tr504_c_foe.health = 60',
    '\tr504_c.state.energy = 9',
)
T_FATAL_SETUP_NEW = L(
    '\tr504_c_foe.health = 60',
    '\t# R581：致命改为随机落格 → 这里显式铺标记，让「不可叠加」判据不依赖随机结果',
    '\tr504_c._place_mark(Vector2i(3, 1), GameEngine.SIDE_SELF, "R581 测试")',
    '\tr504_c.state.energy = 9',
)

EDITS = {
    'cards.json': [
        ('9225 rarity 0→1', C_9225_RAR_OLD, C_9225_RAR_NEW),
        ('9225 effect_text 先伤后标', C_9225_TEXT_OLD, C_9225_TEXT_NEW),
        ('9226 effect_text 随机一个格子', C_9226_TEXT_OLD, C_9226_TEXT_NEW),
        ('9229 rarity 0→1', C_9229_RAR_OLD, C_9229_RAR_NEW),
    ],
    'scripts/game_engine.gd': [
        ('9225 常量注释', G_OMEN_CONST_OLD, G_OMEN_CONST_NEW),
        ('9229 常量注释', G_PROJ_CONST_OLD, G_PROJ_CONST_NEW),
        ('9225 结算顺序块', G_OMEN_BLOCK_OLD, G_OMEN_BLOCK_NEW),
        ('9229 结算注释', G_PROJ_COMMENT_OLD, G_PROJ_COMMENT_NEW),
        ('伤害表注释', G_DMG_TABLE_OLD, G_DMG_TABLE_NEW),
        ('致命调用点', G_CALL_OLD, G_CALL_NEW),
        ('_auto_mark_if_none 双口径', G_AUTO_OLD, G_AUTO_NEW),
    ],
    'scripts/test_engine.gd': [
        ('五卡断言 9225 稀有', T_FIVE_A_OLD, T_FIVE_A_NEW),
        ('五卡断言 9229 稀有', T_FIVE_B_OLD, T_FIVE_B_NEW),
        ('五卡断言 描述', T_FIVE_DESC_OLD, T_FIVE_DESC_NEW),
        ('死亡预告 用例注释', T_OMEN_COMMENT_OLD, T_OMEN_COMMENT_NEW),
        ('死亡预告 伤害断言', T_OMEN_CHECK_OLD, T_OMEN_CHECK_NEW),
        ('致命 段头注释', T_FATAL_HEAD_OLD, T_FATAL_HEAD_NEW),
        ('致命 用例注释', T_FATAL_CASE_OLD, T_FATAL_CASE_NEW),
        ('致命 自动标断言 + 新判据 + 锁', T_FATAL_CHECK_OLD, T_FATAL_CHECK_NEW),
        ('致命 已有标记断言 去坐标硬编码', T_KEEP_MARK_OLD, T_KEEP_MARK_NEW),
        ('R504 致命 setup 显式铺标记', T_FATAL_SETUP_OLD, T_FATAL_SETUP_NEW),
    ],
}


def main():
    docs = {}
    for rel in EDITS:
        with open(os.path.join(ROOT, rel), 'rb') as f:
            docs[rel] = f.read().decode('utf-8')

    report = []
    for rel, edits in EDITS.items():
        for name, old, new in edits:
            co = docs[rel].count(old)
            cn = docs[rel].count(new)
            report.append((rel, name, co, cn))

    for rel, name, co, cn in report:
        print('%-28s %-34s old=%d new=%d' % (rel.split('/')[-1], name, co, cn))
    bad = [r for r in report if not (r[2] == 1 or (r[2] == 0 and r[3] >= 1))]
    if bad:
        print('\n[FAIL] 锚点异常（old 必须恰好 1 处，或已应用时 0 处且 new 存在）：')
        for rel, name, co, cn in bad:
            print('  ', rel, name, 'old=', co, 'new=', cn)
        return 1
    if CHECK_ONLY:
        print('\nCHECK_ONLY OK：所有锚点可定位')
        return 0

    changed = 0
    for rel, edits in EDITS.items():
        s = docs[rel]
        for name, old, new in edits:
            if s.count(old) == 1:
                s = s.replace(old, new, 1)
                changed += 1
        docs[rel] = s

    # 写回前统一校验：纯 CRLF + cards.json 合法
    for rel, s in docs.items():
        b = s.encode('utf-8')
        assert b.count(b'\n') == b.count(b'\r\n'), '%s 出现 bare LF' % rel
    cards = json.loads(docs['cards.json'])
    by_id = {c['id']: c for c in cards['cards']}
    assert by_id[9225]['rarity'] == 1 and by_id[9229]['rarity'] == 1
    assert by_id[9225]['effect_text'] == '对目标造成 6 点伤害，然后标记目标所在的格子。'
    assert '随机标记一个格子。' in by_id[9226]['effect_text']
    assert '敌人所在的格子' not in by_id[9226]['effect_text']
    assert 'HP' not in by_id[9226]['effect_text'] and '己方' not in by_id[9226]['effect_text']
    g = docs['scripts/game_engine.gd']
    assert '_auto_mark_if_none("致命", true)' in g
    assert 'var dom_s: String = str(_op_deal_damage(' in g
    assert '_auto_mark_if_none("恐惧化身")' in g

    for rel, s in docs.items():
        with open(os.path.join(ROOT, rel), 'wb') as f:
            f.write(s.encode('utf-8'))
    print('\n%s：%d 处替换，3 个文件写回（CRLF / json 校验通过）'
          % ('PATCH_OK' if changed else 'REPLAY_OK', changed))
    return 0


if __name__ == '__main__':
    sys.exit(main())
