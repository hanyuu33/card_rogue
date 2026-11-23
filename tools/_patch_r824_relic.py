# -*- coding: utf-8 -*-
"""R824：鸭子闹钟 6085 + 试玩版也出鸭绅士。

四处代码：
  ① relics.json          新增 6085（kind 战斗 / source 二层 / tier 一般）
  ② relic_repo.gd         layer2_ids 与 duck_host_ids 都加 6085；删掉 R822 的「demo 卷卷池 9 件」例外
  ③ run_state.gd          删掉 layer2_host 的 demo 短路（试玩版现在也派生主持人）
  ④ game_engine.gd       第 2 回合 +1 费 + 抽 1 张；第 5 回合起技能伤害 +1

所有断言 `count == 1`；CRLF 文件先折成 LF 再还原，保证行尾不被整体改写。
"""
import io

ROOT = "E:/work/card_rogue/"


def load(rel):
    raw = io.open(ROOT + rel, encoding="utf-8", newline="").read()
    crlf = raw.count("\r\n")
    lf_only = raw.count("\n") - crlf
    assert lf_only == 0 or crlf == 0, "%s 行尾混杂 crlf=%d lf=%d" % (rel, crlf, lf_only)
    return raw.replace("\r\n", "\n"), (crlf > 0)


def save(rel, text, was_crlf):
    out = text.replace("\n", "\r\n") if was_crlf else text
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(out)
    print("WROTE %-34s %s %d 字节" % (rel, "CRLF" if was_crlf else "LF", len(out)))


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次" % (tag, n)
    print("  OK %s" % tag)
    return text.replace(old, new)


# ─────────────────────────── ① relics.json ───────────────────────────
t, c = load("relics.json")
old = '''      "tier": "传奇",
      "desc": "在每场战斗中打出第 12 张牌时，结束当前回合并变成你新的回合开始（完全不进行敌方回合）。"
    }
  ]
}
'''
new = '''      "tier": "传奇",
      "desc": "在每场战斗中打出第 12 张牌时，结束当前回合并变成你新的回合开始（完全不进行敌方回合）。"
    },
    {
      "id": 6085,
      "name": "鸭子闹钟",
      "kind": "战斗",
      "source": "二层",
      "tier": "一般",
      "desc": "每场战斗的第 2 回合，抽 1 张卡并获得 1 点费用；第 5 回合起，技能伤害 +1。"
    }
  ]
}
'''
t = sub(t, old, new, "relics.json 6085")
save("relics.json", t, c)

# ─────────────────────────── ② relic_repo.gd ───────────────────────────
t, c = load("scripts/relic_repo.gd")

t = sub(t, '''	## R822（店长口径）：这 9 件里 **4 件带鸭的（6010 / 6015 / 6017 / 6018）归属移到鸭绅士**。
	##       本函数仍返回**全量 9 件**（它是二层的权威名单）；实际发放走进
	##       `layer2_ids_for(host)` —— 遇到卷卷只出剩下 5 件，遇到鸭绅士只出那 4 件。
	var out: Array[int] = [6014, 6015, 6016, 6017, 6018, 6033, 6049, 6010, 6067]''',
'''	## R822（店长口径）：这 9 件里 **4 件带鸭的（6010 / 6015 / 6017 / 6018）归属移到鸭绅士**。
	##       本函数仍返回**全量**（它是二层的权威名单）；实际发放走进
	##       `layer2_ids_for(host)` —— 遇到卷卷只出剩下的，遇到鸭绅士只出带鸭的。
	## R824（店长口径）：新增「鸭子闹钟」6085（第 2 回合 +1 费 + 抽 1 张；第 5 回合起技能 +1），
	##       归鸭绅士 → 全量 9→10 件，鸭绅士 4→5 件，卷卷仍是 5 件。
	var out: Array[int] = [6014, 6015, 6016, 6017, 6018, 6033, 6049, 6010, 6067, 6085]''',
        "layer2_ids +6085")

t = sub(t, '''	## R822（店长口径）：**鸭绅士**的起始道具池 —— 4 件「带鸭」的道具
	## （6010 鸭之低语 / 6015 鸭语耳环 / 6017 重鸭 / 6018 生蛋鸭）。
	## 归属整体移到鸭绅士这边：卷卷在场时这 4 件不再出现；
	## 鸭绅士的三选一从这 4 件里抽 3 件（不重复）。
	## 判据只有「在不在这份名单里」一条 —— 场景 / 存档 / 测试都不许另写一遍。
	var out: Array[int] = [6010, 6015, 6017, 6018]''',
'''	## R822（店长口径）：**鸭绅士**的起始道具池 —— 「带鸭」的道具
	## （6010 鸭之低语 / 6015 鸭语耳环 / 6017 重鸭 / 6018 生蛋鸭 / 6085 鸭子闹钟）。
	## 归属整体移到鸭绅士这边：卷卷在场时这几件不再出现；
	## 鸭绅士的三选一从这份名单里抽 3 件（不重复）。
	## R824：加「鸭子闹钟」6085 → 4 件变 5 件（仍是抽 3，不是必出）。
	## 判据只有「在不在这份名单里」一条 —— 场景 / 存档 / 测试都不许另写一遍。
	var out: Array[int] = [6010, 6015, 6017, 6018, 6085]''',
        "duck_host_ids +6085")

t = sub(t, '''	## R822：按「这一局第二层起点遇到谁」取起始池。
	##   host = 1（鸭绅士）→ 那 4 件带鸭的；
	##   host = 0（卷卷）  → 全量 9 件减去那 4 件 = 5 件；
	##   **试玩版例外**：鸭绅士是 R822 的新增内容，按 R817「新增不跟着走」不进试玩；
	##   但它一走，那 4 件就既没人发放、又不在任何池子里 —— 等于凭空少 4 件内容。
	##   所以试玩版的卷卷池保持全量 9 件（`layer2_ids()` 原样返回）。
	if host != 0:
		return duck_host_ids()
	var all_ids := layer2_ids()
	if GameBuild.is_demo():
		return all_ids
	var duck := duck_host_ids()''',
'''	## R822：按「这一局第二层起点遇到谁」取起始池。
	##   host = 1（鸭绅士）→ 带鸭的那几件（R824 起 5 件）；
	##   host = 0（卷卷）  → 全量减去带鸭的 = 5 件。
	## R824（店长口径：「试玩版改为给鸭绅士」）：**删掉 R822 的试玩版例外** ——
	##   鸭绅士进试玩之后，那 4 件有人发放了，卷卷池不该再兜全量（否则同两件道具
	##   在两位主持人那里都能抽到，归属就白分了）。试玩版与正式版走同一条分流。
	##   ⚠️ 新增的 6085 仍按 R817「新增不跟着走」不进试玩基线 → 试玩版鸭绅士池 4 件。
	if host != 0:
		return duck_host_ids()
	var all_ids := layer2_ids()
	var duck := duck_host_ids()''',
        "layer2_ids_for 去 demo 例外")

save("scripts/relic_repo.gd", t, c)

# ─────────────────────────── ③ run_state.gd ───────────────────────────
t, c = load("scripts/run_state.gd")

t = sub(t, '''	## 试玩版恒为卷卷：鸭绅士是 R822 的新增内容，按 R817「新增不跟着走」不进试玩。
	if GameBuild.is_demo():
		return LAYER2_HOST_BUNBUN
	var s: int = run_seed if p_seed < 0 else p_seed''',
'''	## R824（店长口径「试玩版改为给鸭绅士」）：试玩版**不再短路成卷卷**，
	## 与正式版走同一条派生 —— 玩家在试玩版也该看到两种开场。
	var s: int = run_seed if p_seed < 0 else p_seed''',
        "layer2_host 去 demo 短路")

t = sub(t, '''	## R822：第二层按「这一局遇到谁」分流 —— 鸭绅士在场时池子里是那 4 件带鸭道具，
	## 卷卷在场时是剩下的 5 件（试玩版没有鸭绅士，4 件留在卷卷池，一件都不丢）。''',
'''	## R822：第二层按「这一局遇到谁」分流 —— 鸭绅士在场时池子里是带鸭道具，
	## 卷卷在场时是剩下的 5 件。R824 起试玩版也出鸭绅士，两边同一条分流。''',
        "_roll_relic_choice 注释")

save("scripts/run_state.gd", t, c)

# ─────────────────────────── ④ game_engine.gd ───────────────────────────
t, c = load("scripts/game_engine.gd")

t = sub(t, '''const EARRING_RELIC_ID:= 6015
const EARRING_AUTOPLAY_MAX:= 20''',
'''const EARRING_RELIC_ID:= 6015
const EARRING_AUTOPLAY_MAX:= 20
# R824 鸭子闹钟（6085，二层起始池 · 鸭绅士）：**第 2 个我方回合** +1 费 + 多抽 1 张；
#   **第 5 个我方回合起**技能伤害 +1。
# 两条都只读 `turn_number`（本场战斗内计数），**不落存档、不加新字段** ——
# 读档续战由引擎快照里已有的 turn_number 还原，与鹿首标本同口径。
const DUCK_ALARM_RELIC_ID:= 6085
const DUCK_ALARM_TURN:= 2
const DUCK_ALARM_ENERGY:= 1
const DUCK_ALARM_DRAW:= 1
const DUCK_ALARM_SPELL_FROM:= 5
const DUCK_ALARM_SPELL:= 1''',
        "常量")

t = sub(t, '''		var earring_energy:= 0
		if self_relics.has(EARRING_RELIC_ID):
			earring_energy = 1
			state.energy += earring_energy
			_log("鸭语耳环：本回合费用 +1")
''',
'''		var earring_energy:= 0
		if self_relics.has(EARRING_RELIC_ID):
			earring_energy = 1
			state.energy += earring_energy
			_log("鸭语耳环：本回合费用 +1")

		# R824 鸭子闹钟（6085）：**第 2 个我方回合**发一次 —— +1 费、多抽 1 张。
		# 费用与鸭翼 / 鸭语耳环同一条 `state.energy` 发放口；抽牌走 `extra_draw`
		# （唯一抽牌口 `_draw_many`，所以必须在它之前加）。判据只看 `turn_number`。
		if self_relics.has(DUCK_ALARM_RELIC_ID) and turn_number == DUCK_ALARM_TURN:
			state.energy += DUCK_ALARM_ENERGY
			extra_draw += DUCK_ALARM_DRAW
			_log("鸭子闹钟：第 %d 回合，费用 +%d、多抽 %d 张"
					% [DUCK_ALARM_TURN, DUCK_ALARM_ENERGY, DUCK_ALARM_DRAW])
			action.emit("relic", {"id": DUCK_ALARM_RELIC_ID,
					"text": "鸭子闹钟：第 %d 回合费用 +%d / 多抽 %d 张"
							% [DUCK_ALARM_TURN, DUCK_ALARM_ENERGY, DUCK_ALARM_DRAW]})
''',
        "_begin_turn 第 2 回合")

t = sub(t, '''	out += deer_bonus   # R341 鹿首标本：每回合 +1（本场累计）''',
'''	out += deer_bonus   # R341 鹿首标本：每回合 +1（本场累计）
	# R824 鸭子闹钟（6085）：第 5 个我方回合**起**技能伤害 +1（固定值，不是累计层数）。
	# 与鹿首标本 / 骑士剑同属固定加成，会被后面的快速符文百分比一起放大。
	if self_relics.has(DUCK_ALARM_RELIC_ID) and turn_number >= DUCK_ALARM_SPELL_FROM:
		out += DUCK_ALARM_SPELL''',
        "_spell_dmg 第 5 回合起")

save("scripts/game_engine.gd", t, c)
print("\n全部补丁完成")
