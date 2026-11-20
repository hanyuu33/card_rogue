# -*- coding: utf-8 -*-
"""R835 RunState：空故事书 6089 的页数累计。

改动点（全部 LF，锚点 count==1）：
  1) 常量 + 字段 + 计数方法（首饰盒 6088 常量之后）
  2) complete_current()：事件房首次结算 → +1 页
  3) mark_boss_beaten()：首领击破 → +1 页（按 boss_beaten 做同层幂等）
  4) start_run / end_run 复位
  5) RunSave 写入 + 读取
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def rep(p, old, new, n=1):
    s = read(p)
    c = s.count(old)
    if c != n:
        print("!! %s count=%d 期望 %d\n   %r" % (p, c, n, old[:100]))
        sys.exit(1)
    write(p, s.replace(old, new, n))
    print("ok %-28s" % p)


P = "scripts/run_state.gd"

# ── 1) 常量 + 字段 + 方法 ─────────────────────────────────────────────────
rep(P,
    'const JEWELRY_BOX_RELIC_ID := 6088\n',
    'const JEWELRY_BOX_RELIC_ID := 6088\n'
    '# R835 空故事书（6089，第一层初始池）：战斗开始时对**全体敌人**造成 story_book_pages 点伤害；\n'
    '# 每经过一个事件房 / 打赢一个首领 → +1 页（页数就是伤害值）。\n'
    '# ⚠️ 只累计「**持有期间**的经历」—— 没这道具时走过的事件 / 首领不补记，否则捡到就是一大叠页数。\n'
    '# ⚠️ 页数跨战斗、跨换层、跨读档都要接着算 → 进 RunSave。\n'
    'const STORY_BOOK_RELIC_ID := 6089\n'
    'static var story_book_pages := 0\n'
    '## 已记过页的事件节点 id —— `complete_current()` 会被事件场景多处重复调用，靠它做幂等\n'
    '## （不看 `cleared_ids`：战斗 / 地图场景会各自 append，顺序不可依赖）。\n'
    'static var story_book_nodes: Array = []\n'
    '\n'
    '\n'
    'static func story_book_add_page() -> int:\n'
    '\t## R835 空故事书：一条「经历」= 一个事件房 / 一个首领战 → 页数 +1。\n'
    '\t## 幂等不在这一步做（事件按节点 id、首领按 `boss_beaten` 每层一次）。\n'
    '\t## 没这道具 → 原样返回，不累计（捡到之前的经历不算）。\n'
    '\tif not relics.has(STORY_BOOK_RELIC_ID):\n'
    '\t\treturn story_book_pages\n'
    '\tstory_book_pages += 1\n'
    '\treturn story_book_pages\n'
    '\n'
    '\n'
    'static func _note_story_book_event(node_id: int) -> void:\n'
    '\t## R835：事件房结算完成 → 记一页。判据只有「这一格的 type 是 event」一条 ——\n'
    '\t## 宝箱 / 商店 / 休息 / 战斗都不算（卡面写的是「事件」）。\n'
    '\tif node_id < 0 or node_id >= map_cells.size():\n'
    '\t\treturn\n'
    '\tif story_book_nodes.has(node_id):\n'
    '\t\treturn\n'
    '\tvar cell: Dictionary = map_cells[node_id]\n'
    '\tif str(cell.get("type", "")) != "event":\n'
    '\t\treturn\n'
    '\tstory_book_nodes.append(node_id)\n'
    '\tstory_book_add_page()\n')

# ── 2) complete_current ───────────────────────────────────────────────────
rep(P,
    'static func complete_current() -> void:\n'
    '\t## 当前房间内容结算完成（战斗胜利 / 休息 / 事件 / 大宝箱）。\n'
    '\t## 进房时已经标过「已走过」，这里是幂等的兜底口。\n'
    '\tif current_node_id >= 0 and not cleared_ids.has(current_node_id):\n'
    '\t\tcleared_ids.append(current_node_id)\n',
    'static func complete_current() -> void:\n'
    '\t## 当前房间内容结算完成（战斗胜利 / 休息 / 事件 / 大宝箱）。\n'
    '\t## 进房时已经标过「已走过」，这里是幂等的兜底口。\n'
    '\t## ⚠️ R835 空故事书的「事件 +1 页」挂在**这里**：事件完成的调用点散在 event_scene\n'
    '\t##    十余处，唯一共同收口就是本函数。它自己按 `story_book_nodes` 去重，\n'
    '\t##    因此不受 `cleared_ids` 是否已被别的场景 append 影响。\n'
    '\t_note_story_book_event(current_node_id)\n'
    '\tif current_node_id >= 0 and not cleared_ids.has(current_node_id):\n'
    '\t\tcleared_ids.append(current_node_id)\n')

# ── 3) mark_boss_beaten ───────────────────────────────────────────────────
rep(P,
    'static func mark_boss_beaten() -> void:\n'
    '\t## R339：本层 Boss 已击破 —— 唯一置位口。\n'
    '\t## 顺带清掉 `boss_pending`：Boss 战打完时这条「等房间结算完就入夜」的待触发必须失效，\n'
    '\t## 否则回地图就可能再开一次（原先只靠 `map_scene._start_boss_battle` 提前清，是个单点依赖）。\n'
    '\tboss_beaten = true\n'
    '\tboss_pending = false\n',
    'static func mark_boss_beaten() -> void:\n'
    '\t## R339：本层 Boss 已击破 —— 唯一置位口。\n'
    '\t## 顺带清掉 `boss_pending`：Boss 战打完时这条「等房间结算完就入夜」的待触发必须失效，\n'
    '\t## 否则回地图就可能再开一次（原先只靠 `map_scene._start_boss_battle` 提前清，是个单点依赖）。\n'
    '\t## R835 空故事书：每个首领 +1 页。`boss_beaten` 是**按层**标志（换层复位），\n'
    '\t## 天然做到「同一层的同一只首领只记一次、下一层的新首领再记一次」。\n'
    '\tif boss_beaten:\n'
    '\t\tboss_pending = false\n'
    '\t\treturn\n'
    '\tboss_beaten = true\n'
    '\tboss_pending = false\n'
    '\tstory_book_add_page()\n')

# ── 4) 新局 / 收尾复位 ────────────────────────────────────────────────────
rep(P,
    '\tstatue_charge = 0          # R307 雕像：新的一局从 0 开始数\n'
    '\tbasin_charge = 0           # R311 不锈钢盆：新的一局没有盆（重拿时再灌满）\n',
    '\tstatue_charge = 0          # R307 雕像：新的一局从 0 开始数\n'
    '\tbasin_charge = 0           # R311 不锈钢盆：新的一局没有盆（重拿时再灌满）\n'
    '\tstory_book_pages = 0       # R835 空故事书：新的一局是一本空书\n'
    '\tstory_book_nodes = []\n')

rep(P,
    '\tchocolate = 0\n'
    '\tgold = 0                      # R181：本局结束 → 金币清掉\n',
    '\tchocolate = 0\n'
    '\tgold = 0                      # R181：本局结束 → 金币清掉\n'
    '\tstory_book_pages = 0          # R835：本局结束 → 故事书合上\n'
    '\tstory_book_nodes = []\n')

# ── 5) RunSave ───────────────────────────────────────────────────────────
S = "scripts/run_save.gd"
rep(S,
    '\t\t"basin_charge": RunState.basin_charge,   # R311 不锈钢盆：剩余点数（跨战斗累计）\n',
    '\t\t"basin_charge": RunState.basin_charge,   # R311 不锈钢盆：剩余点数（跨战斗累计）\n'
    '\t\t"story_book_pages": RunState.story_book_pages,   # R835 空故事书：累计页数（= 开场伤害）\n'
    '\t\t"story_book_nodes": RunState.story_book_nodes,   # R835：已记过页的事件节点（幂等）\n')

rep(S,
    '\t# R314 lucky 7：老存档没有这个字段 → 按 0（下次开始我方回合起重新累计）\n'
    '\tRunState.lucky7_turns = int(d.get("lucky7_turns", 0))\n',
    '\t# R314 lucky 7：老存档没有这个字段 → 按 0（下次开始我方回合起重新累计）\n'
    '\tRunState.lucky7_turns = int(d.get("lucky7_turns", 0))\n'
    '\t# R835 空故事书：老存档没有这两个键 → 页数按 0（等于一本空书），节点表按空。\n'
    '\tRunState.story_book_pages = int(d.get("story_book_pages", 0))\n'
    '\tRunState.story_book_nodes = _int_array(d.get("story_book_nodes", []))\n')

print("\n全部通过")
