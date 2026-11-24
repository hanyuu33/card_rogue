# -*- coding: utf-8 -*-
"""R752 补丁：RunState —— 快送鸭「用随机商店工具填满工具栏」的唯一口 + 独立随机序号。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:120])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/run_state.gd", [
    (
        """## R745 工具箱发工具的独立序号 —— 与 `tool_roll_seq` 分开，否则「多拿一个工具」
## 会把战斗掉落的 10% 摇点整体推歪（同 R312 的分类种子口径）。随存档一起走。
static var toolbox_tool_seq := 0
""",
        """## R745 工具箱发工具的独立序号 —— 与 `tool_roll_seq` 分开，否则「多拿一个工具」
## 会把战斗掉落的 10% 摇点整体推歪（同 R312 的分类种子口径）。随存档一起走。
static var toolbox_tool_seq := 0
## R752 快送鸭 7010 的独立序号：一次要连抽 3 件，与上面两条都分开（同一条口径：
## 效果里的随机数不许推动地图 / 掉落 / 工具箱的随机流）。
static var tool_deliver_seq := 0
""",
    ),
    (
        """	tool_roll_seq = 0      # R694：新的一局 → 战斗掉落工具的重摇序号归零
	toolbox_tool_seq = 0   # R745：工具箱发工具的序号同样归零
	bandage_pending = 0
""",
        """	tool_roll_seq = 0      # R694：新的一局 → 战斗掉落工具的重摇序号归零
	toolbox_tool_seq = 0   # R745：工具箱发工具的序号同样归零
	tool_deliver_seq = 0   # R752：快送鸭的序号同样归零
	bandage_pending = 0
""",
    ),
    (
        """	tool_roll_seq = 0      # R694：本局结束 → 掉落工具的序号也归零
	toolbox_tool_seq = 0   # R745：工具箱的序号也归零
""",
        """	tool_roll_seq = 0      # R694：本局结束 → 掉落工具的序号也归零
	toolbox_tool_seq = 0   # R745：工具箱的序号也归零
	tool_deliver_seq = 0   # R752：快送鸭的序号也归零
""",
    ),
    (
        """static func queue_tool_reward(id: int) -> bool:
""",
        """static func fill_toolbar_with_shop_tools() -> int:
	## R752 快送鸭 7010：「用随机商店工具填满你的工具栏」的**唯一口**。
	## 池子 = `TrapRepo.shop_traps()`（= 有售价的、货架上真买得到的那些）——
	## 用户口径「也就是仅商店可以买到的工具」：万能牌 / 快送鸭 / 神秘牌自己不在池里，
	## 否则会出现「快送鸭刷出快送鸭」的自指连锁。
	## 随机流走 `seed_of("tool_deliver", n)` 的**派生流** + 独立序号 `tool_deliver_seq`
	## （不碰 run_rng，同 R694 / R745 口径）；序号随存档走，同一条种子不会被摇第二遍。
	## 返回真正填进去的件数。**满栏时不覆盖已有工具**（只在空槽里填）——
	## 「填满」不是「换一批」，玩家手里的东西不该被这个效果顶掉。
	## ⚠️ 调用方（`GameEngine.use_tool`）必须**先把快送鸭自己那一格腾空**再调这里，
	##    否则「用掉自己 + 填满」两件事差一格（见 `use_tool` 的 fill_toolbar 分支）。
	var pool: Array[TrapData] = TrapRepo.load_json().shop_traps()
	if pool.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	var filled := 0
	for i in traps.size():
		if int(traps[i]) >= 0:
			continue
		rng.seed = seed_of("tool_deliver", tool_deliver_seq)
		tool_deliver_seq += 1
		traps[i] = int(pool[rng.randi() % pool.size()].id)
		filled += 1
	return filled


static func queue_tool_reward(id: int) -> bool:
""",
    ),
])

print("OK")
