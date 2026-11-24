# -*- coding: utf-8 -*-
"""R835 引擎层：空故事书 6089 的开场伤害 + 初始池登记。

game_engine.gd（CRLF）：
  常量 STORY_BOOK_RELIC_ID / _story_book_tick() / apply_battle_start_relics 末尾调用
relic_repo.gd（LF）：
  initial_ids() 数组 +6089（11 → 12 件）
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def rep(p, old, new, n=1, crlf=False):
    s = read(p)
    if crlf:
        old = old.replace("\n", "\r\n")
        new = new.replace("\n", "\r\n")
    c = s.count(old)
    if c != n:
        print("!! %s count=%d 期望 %d\n   %r" % (p, c, n, old[:120]))
        sys.exit(1)
    write(p, s.replace(old, new, n))
    print("ok %-30s" % p)


# ── 引擎常量 ─────────────────────────────────────────────────────────────
rep("scripts/game_engine.gd",
    'const MUSIC_BOX_RELIC_ID:= 6086\n'
    'const MUSIC_BOX_DRAW:= 3\n',
    'const MUSIC_BOX_RELIC_ID:= 6086\n'
    'const MUSIC_BOX_DRAW:= 3\n'
    '# R835 空故事书（6089，第一层初始池）：战斗开始时对全体敌人造成 `RunState.story_book_pages`\n'
    '# 点伤害；页数由「经过的事件房 / 打赢的首领」累计（累计口在 RunState，引擎只读）。\n'
    'const STORY_BOOK_RELIC_ID:= 6089\n',
    crlf=True)

# ── 开场调用 ─────────────────────────────────────────────────────────────
rep("scripts/game_engine.gd",
    '\t# R826 音乐盒（6086）：放在记忆药水之后 —— 两者都动 state.deck，追加在末尾不干扰前面。\n'
    '\tif self_relics.has(MUSIC_BOX_RELIC_ID):\n'
    '\t\t_music_box_tick(repo)\n',
    '\t# R826 音乐盒（6086）：放在记忆药水之后 —— 两者都动 state.deck，追加在末尾不干扰前面。\n'
    '\tif self_relics.has(MUSIC_BOX_RELIC_ID):\n'
    '\t\t_music_box_tick(repo)\n'
    '\t# R835 空故事书（6089）：**排在最后** —— 它要把敌人打到掉血甚至死亡，\n'
    '\t# 放在所有「改牌库 / 掷骰 / 发放单位」的开场效果之后，前面各件的随机数序列一字不动。\n'
    '\tif self_relics.has(STORY_BOOK_RELIC_ID):\n'
    '\t\t_story_book_tick()\n',
    crlf=True)

# ── 函数本体：插在 _music_box_tick 之前 ────────────────────────────────────
rep("scripts/game_engine.gd",
    'func _music_box_tick(repo: CardRepo) -> void:\n',
    'func _story_book_tick() -> void:\n'
    '\t## R835 空故事书（6089，第一层初始池）：战斗开始时对**全体敌方单位**各造成\n'
    '\t## `RunState.story_book_pages` 点伤害。页数在 RunState 累计（每经过一个事件房 /\n'
    '\t## 打赢一个首领 +1），引擎这边只读，不自己记账。\n'
    '\t## 0 页 → 什么都不做（卡面写的就是「造成 0 伤害」：这本书还没有故事）。\n'
    '\t## 死亡收口走统一 `_destroy_dead()`（它末尾会 `_check_game_over()`）；开场就清场是\n'
    '\t## 极端情况，`start_game()` 里的那次 `_check_game_over()` 会兜住，不会卡在活着的状态。\n'
    '\tvar dmg := int(RunState.story_book_pages)\n'
    '\tif dmg <= 0:\n'
    '\t\t_log("空故事书：本局还没有故事（0 点伤害）")\n'
    '\t\treturn\n'
    '\tvar hit := 0\n'
    '\tfor cell: Vector2i in state.board.keys():\n'
    '\t\tvar p: Placement = state.unit_at(cell)\n'
    '\t\tif p == null or p.owner != SIDE_OPPONENT:\n'
    '\t\t\tcontinue\n'
    '\t\t_hit_unit(p, dmg, "空故事书")\n'
    '\t\thit += 1\n'
    '\tif hit > 0:\n'
    '\t\t_log("空故事书：开场对 %d 名敌人各造成 %d 点伤害" % [hit, dmg])\n'
    '\t\taction.emit("relic", {"id": STORY_BOOK_RELIC_ID,\n'
    '\t\t\t\t"text": "空故事书：全体敌人 -%d" % dmg})\n'
    '\t_destroy_dead()\n'
    '\n'
    '\n'
    'func _music_box_tick(repo: CardRepo) -> void:\n',
    crlf=True)

# ── 初始池 ───────────────────────────────────────────────────────────────
rep("scripts/relic_repo.gd",
    '\t# R830：新增「首饰盒」6088（获得即随机一张史诗卡加入卡组）。\n'
    '\tvar out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068, 6088]\n',
    '\t# R830：新增「首饰盒」6088（获得即随机一张史诗卡加入卡组）。\n'
    '\t# R835：新增「空故事书」6089（战斗开始时对全体敌人造成「页数」点伤害；\n'
    '\t#       每经过一个事件房 / 打赢一个首领 +1 页，页数进存档、跨战斗累计）→ 11 → 12 件。\n'
    '\tvar out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068, 6088, 6089]\n')

print("\n全部通过")
