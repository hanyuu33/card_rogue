# -*- coding: utf-8 -*-
"""R810：Placement 加海妖鱼叉的计数（单位级、按回合钥匙复位）。"""
import io

P = "E:/work/card_rogue/scripts/placement.gd"
s = io.open(P, encoding="utf-8", newline="").read()


def blk(text):
    return text.replace("\n", "\r\n")


def sub(old, new):
    global s
    old, new = blk(old), blk(new)
    assert s.count(old) == 1, (old[:40], s.count(old))
    s = s.replace(old, new)


sub("""var haste_double: bool = false
""", """var haste_double: bool = false
## R810 海妖鱼叉（6083）：**本回合**这个敌人已经挨了几次伤害（道具的 3 次 → 6 点就看它）。
## `harpoon_turn` = 记账那次的 `GameEngine.turn_number`（整轮口径：只有我方回合开始才 +1）。
## 换回合后钥匙失配 → `GameEngine._harpoon_tick()` 自动从 0 重算，所以**不需要**在回合开始
## 扫全场清零（漏扫一只就是静默错账，与赫尔墨斯 `turn_dmg_key` 同一范式）。
## 只记 Placement、**绝不烤进 CardData**：敌方关卡单位用的是卡库共享实例。
var harpoon_hits: int = 0
var harpoon_turn: int = -1
""")

sub("""	"haste_double", "defector_range", "defector_speed", "defector_hunt",
""", """	"haste_double", "defector_range", "defector_speed", "defector_hunt",
	"harpoon_hits", "harpoon_turn",
""")

# 状态栏可见来源：本回合已命中几次（玩家要能看见「还差一次」）
sub("""	if acts_left > 1:
		out.append({"label": "额外行动 ×%d" % acts_left, "col": COL_B, "kind": "buff"})
""", """	if acts_left > 1:
		out.append({"label": "额外行动 ×%d" % acts_left, "col": COL_B, "kind": "buff"})
	# R810 海妖鱼叉（6083）：这个单位本回合挨了几次 —— 「还差一次」得看得见，
	# 否则玩家没法判断下一张牌该不该打它。
	if harpoon_hits > 0 and harpoon_hits % GameEngine.HARPOON_HITS != 0:
		out.append({"label": "海妖鱼叉：本回合已命中 %d/%d"
				% [harpoon_hits % GameEngine.HARPOON_HITS, GameEngine.HARPOON_HITS],
				"col": COL_I, "kind": "info"})
""")

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("PLACEMENT OK, CRLF:", "\r\n" in s)
