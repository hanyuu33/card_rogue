# -*- coding: utf-8 -*-
"""R813：水晶骰子 6040 由「传奇」降为「一般」。

四处：
  ① relics.json 的 tier 字段（运行时唯一取数口）
  ② relic_data.gd 的档位注释（传奇清单里剔掉骰子）
  ③ relic_repo.gd 的历史注释补一行 R813 + legendary_reward_ids 的件数说明
  ④ test_engine.gd 三条硬编码断言（36/29/7 → 36/30/6；R314 骰子改判一般）

幂等：每处断言 count==1（或已是新值则跳过）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def sub(s, old, new, tag, crlf=False):
    if crlf:
        old = old.replace("\n", "\r\n")
        new = new.replace("\n", "\r\n")
    n = s.count(old)
    if n == 0 and s.count(new) >= 1:
        print("  [skip] %s (已是新值)" % tag)
        return s
    assert n == 1, "[%s] count=%d" % (tag, n)
    print("  [ok]   %s" % tag)
    return s.replace(old, new)


# ── ① relics.json：只动 6040 那一块的 tier ──
p = "relics.json"
s = read(p)
anchor = '      "id": 6040,\n      "name": "水晶骰子",\n      "kind": "持续",\n      "source": "奖励",\n      "tier": "传奇",\n'
new_anchor = '      "id": 6040,\n      "name": "水晶骰子",\n      "kind": "持续",\n      "source": "奖励",\n      "tier": "一般",\n'
if s.count(anchor) == 1:
    s = s.replace(anchor, new_anchor)
    print("  [ok]   relics.json 6040 tier 传奇→一般")
elif s.count(new_anchor) == 1:
    print("  [skip] relics.json 6040 已是「一般」")
else:
    sys.exit("relics.json 6040 锚点未命中")
write(p, s)

# ── ② relic_data.gd 档位注释 ──
p = "scripts/relic_data.gd"
s = read(p)
s = sub(
    s,
    "##   一般  默认档（R391 起 15 件；剧情锁定的竖琴 / 骑士剑未解锁时各少一件）；\n"
    "##   传奇  稀有档（R391 起 5 件：水晶骰子 6040 / 储物箱 6044 / lucky 7 6045 /\n"
    "##         采集刀 6050 / 鸭嘴 6006），**只靠 legendary_chance 判定命中才出**。\n",
    "##   一般  默认档（R391 起 15 件；剧情锁定的竖琴 / 骑士剑未解锁时各少一件）；\n"
    "##   传奇  稀有档（R813 起 4 件：储物箱 6044 / lucky 7 6045 / 采集刀 6050 /\n"
    "##         鸭嘴 6006），**只靠 legendary_chance 判定命中才出**。\n"
    "##         R813：**水晶骰子 6040 由传奇降为一般**（店长口径「骰子降为普通道具」）。\n"
    "##         它是「改地图 + 加费」的功能型道具，强度靠玩法而不是数值，放在传奇档太贵。\n",
    "relic_data 档位注释",
)
write(p, s)

# ── ③ relic_repo.gd 注释 ──
p = "scripts/relic_repo.gd"
s = read(p)
s = sub(
    s,
    "\t## R314：**水晶骰子 6040 升为「传奇」档**；新增传奇「储物箱」6044（回合结束不弃手牌）\n"
    "\t##       与「lucky 7」6045（每 7 个回合免伤 + 技能 +7）。传奇档不再空置。\n",
    "\t## R314：**水晶骰子 6040 升为「传奇」档**；新增传奇「储物箱」6044（回合结束不弃手牌）\n"
    "\t##       与「lucky 7」6045（每 7 个回合免伤 + 技能 +7）。传奇档不再空置。\n"
    "\t## R813：**水晶骰子 6040 降回「一般」档**（店长口径）—— 它仍在奖励池内，\n"
    "\t##       只是不再受 legendary_chance 那道闸限制，改为跟普通道具一起摇。\n",
    "relic_repo 历史注释",
)
s = sub(
    s,
    "func legendary_reward_ids() -> Array[int]:\n"
    "\t## 奖励池里的「传奇道具」（R342 起 4 件：6040 水晶骰子 / 6044 储物箱 / 6045 lucky 7 /\n"
    "\t## 6050 采集刀；R391 起 5 件：**鸭嘴 6006 由一般升为传奇**。\n"
    "\t## R440 起 6 件：**暗动力 6054**（多抽一张的代价型道具）。\n"
    "\t## R352 的竖琴 6052 是**一般档**，不在这里）。\n",
    "func legendary_reward_ids() -> Array[int]:\n"
    "\t## 奖励池里的「传奇道具」（R342 起 4 件：6040 水晶骰子 / 6044 储物箱 / 6045 lucky 7 /\n"
    "\t## 6050 采集刀；R391 起 5 件：**鸭嘴 6006 由一般升为传奇**。\n"
    "\t## R440 起 6 件：**暗动力 6054**（多抽一张的代价型道具）。\n"
    "\t## R810 起 7 件：**缺陷时钟 6084**（第 12 张牌结束回合、跳过敌方回合）。\n"
    "\t## R813 起 6 件：**水晶骰子 6040 降为一般档**（移出本池）。\n"
    "\t## R352 的竖琴 6052 是**一般档**，不在这里）。\n",
    "legendary_reward_ids 注释",
)
write(p, s)

# ── ④ test_engine.gd 三条断言 ──
p = "scripts/test_engine.gd"
s = read(p)
s = sub(
    s,
    "check(r289_all.size() == 36 and r289_nor.size() == 29 and r289_leg.size() == 7,",
    "check(r289_all.size() == 36 and r289_nor.size() == 30 and r289_leg.size() == 6,",
    "r289 数量断言",
    crlf=True,
)
s = sub(
    s,
    '"奖励分档：奖励池 36 件 = 一般 29 + 传奇 7（实际 %d / %d / %d）"',
    '"奖励分档：奖励池 36 件 = 一般 30 + 传奇 6（实际 %d / %d / %d）"',
    "r289 文案",
    crlf=True,
)
s = sub(
    s,
    "\tcheck(r314_repo.get_relic(6040).tier == RelicData.TIER_LEGENDARY\n"
    "\n"
    "\t\t\tand r314_repo.get_relic(6044).tier == RelicData.TIER_LEGENDARY\n"
    "\n"
    "\t\t\tand r314_repo.get_relic(6045).tier == RelicData.TIER_LEGENDARY,\n"
    "\n"
    "\t\t\t\"R314 水晶骰子 / 储物箱 / lucky 7 三件都是「传奇」档\")\n",
    "\tcheck(r314_repo.get_relic(6044).tier == RelicData.TIER_LEGENDARY\n"
    "\n"
    "\t\t\tand r314_repo.get_relic(6045).tier == RelicData.TIER_LEGENDARY\n"
    "\n"
    "\t\t\tand r314_repo.get_relic(6040).tier == RelicData.TIER_NORMAL,\n"
    "\n"
    "\t\t\t\"R314/R813 储物箱 / lucky 7 是「传奇」档；水晶骰子 R813 起降为「一般」\")\n",
    "r314 档位断言",
    crlf=True,
)
s = sub(
    s,
    "\tcheck(r810_repo.normal_reward_ids().size() == 29\n"
    "\t\t\tand r810_repo.legendary_reward_ids().size() == 7,\n"
    "\t\t\t\"R810 数据层：奖励池 29 一般 + 7 传奇 = 36\")\n",
    "\tcheck(r810_repo.normal_reward_ids().size() == 30\n"
    "\t\t\tand r810_repo.legendary_reward_ids().size() == 6,\n"
    "\t\t\t\"R810/R813 数据层：奖励池 30 一般 + 6 传奇 = 36\")\n",
    "r810 数量断言",
    crlf=True,
)
write(p, s)

# ── 行尾体检 ──
print("--- eol ---")
for f in ("relics.json", "scripts/relic_data.gd", "scripts/relic_repo.gd",
          "scripts/test_engine.gd"):
    b = io.open(ROOT + f, "rb").read()
    cr, lf = b.count(b"\r\n"), b.count(b"\n")
    print("  %-26s CRLF=%-6d LF=%-6d %s" % (f, cr, lf,
          "OK" if (cr == 0 or cr == lf) else "!!! 混行"))
print("done")
