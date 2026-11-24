# -*- coding: utf-8 -*-
## R778：精英强弱判定改成「按当前巧克力」——巧克力 <= 5 一定强精英，否则一定弱精英。
## 本补丁是确定性的：只做 exact-replace，每处 assert count == 1。
import io
import sys

ROOT = "E:/work/card_rogue/"


def load(rel):
    with io.open(ROOT + rel, "r", encoding="utf-8", newline="") as f:
        return f.read()


def save(rel, text):
    with io.open(ROOT + rel, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def rep(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("FAIL[%s] count=%d" % (tag, n))
        sys.exit(1)
    print("OK[%s]" % tag)
    return s.replace(old, new, 1)


# ============ run_state.gd（LF） ============
p = "scripts/run_state.gd"
s = load(p)
crlf = "\r\n" in s
assert not crlf, "run_state.gd 应当是 LF"

# 1) 常量
old = 'const DIFF_ELITE_MUL := 1.3        # 精英出现概率乘数（≈ +30%，扣除法见 _weighted_far）\n'
new = (old
       + '## R778：强弱精英判据 —— 当前巧克力 <= 5 一定进强精英，否则一定进弱精英。\n'
       + '## 三层精英不参与（第三层固定抽第二层精英困难池，见 next_level）。\n'
       + 'const ELITE_STRONG_CHOCO_MAX := 5\n')
s = rep(s, old, new, "const")

# 2) elite_wins 注释
old = 'static var elite_wins := 0                   # 本层已胜利的精英战斗数（第 1 场简单，第 2 场起困难）\n'
new = 'static var elite_wins := 0                   # 本层已胜利的精英战斗数（R778 起只作统计，不再切强弱档）\n'
s = rep(s, old, new, "elite_wins 注释")

# 3) next_level 文档注释
old = ('\t## 前 2 场普通战斗 = 普通敌人-简单，之后 = 普通敌人-困难；\n'
       '\t## 第 1 场精英 = 精英敌人-简单，之后 = 精英敌人-困难（R506：从「前 2 场」提前到第 2 场起重）；\n'
       '\t## Boss 固定。\n')
new = ('\t## 前 2 场普通战斗 = 普通敌人-简单，之后 = 普通敌人-困难；\n'
       '\t## 精英强弱只看**当前巧克力**：<= 5 强精英，> 5 弱精英（R778 替换原「按 elite_wins 场次」）；\n'
       '\t## Boss 固定。\n')
s = rep(s, old, new, "next_level 注释")

# 4) 判据抽成纯函数，插在 node_layer 之前
old = 'static func node_layer(node: Dictionary) -> int:\n'
new = ('static func elite_tier_for_chocolate(choco: int) -> int:\n'
       '\t## R778：强弱精英的**唯一判据**（纯函数，测试直接传数）——\n'
       '\t## 当前巧克力 <= ELITE_STRONG_CHOCO_MAX（5）→ 强精英（精英敌人-困难）；\n'
       '\t## 否则 → 弱精英（精英敌人-简单）。第三层不适用（next_level 里提前固定池）。\n'
       '\treturn GameLevels.TIER_ELITE_HARD if choco <= ELITE_STRONG_CHOCO_MAX \\\n'
       '\t\t\telse GameLevels.TIER_ELITE_EASY\n'
       '\n'
       '\n'
       + old)
s = rep(s, old, new, "纯函数")

# 5) next_level 精英分支
old = ('\t\t\t# R506b：第三层固定抽第二层「精英困难」池（3 关）—— 直道那一格是 Boss 前的\n'
       '\t\t\t# 最后一战，不参与 elite_wins 的简单/困难切换。\n'
       '\t\t\tif layer == GameLayers.LAYER_THREE:\n'
       '\t\t\t\treturn _pick_level(GameLevels.third_elite_pool())\n'
       '\t\t\t# R506：第 1 场精英 = 简单，第 2 场起困难（原来是前 2 场简单）。\n'
       '\t\t\tvar tier2: int = GameLevels.TIER_ELITE_EASY if elite_wins < 1 \\\n'
       '\t\t\t\t\telse GameLevels.TIER_ELITE_HARD\n')
new = ('\t\t\t# R506b：第三层固定抽第二层「精英困难」池（3 关）—— 直道那一格是 Boss 前的\n'
       '\t\t\t# 最后一战，不参与强弱精英判定（R778 口径不变）。\n'
       '\t\t\tif layer == GameLayers.LAYER_THREE:\n'
       '\t\t\t\treturn _pick_level(GameLevels.third_elite_pool())\n'
       '\t\t\t# R778：强弱精英改由**当前巧克力**判定（原「按 elite_wins 场次切换」废弃）。\n'
       '\t\t\tvar tier2: int = elite_tier_for_chocolate(chocolate)\n')
s = rep(s, old, new, "next_level 精英分支")

save(p, s)

# ============ test_engine.gd（CRLF） ============
p = "scripts/test_engine.gd"
s = load(p)
assert "\r\n" in s, "test_engine.gd 应当是 CRLF"


def rep_crlf(s, old, new, tag):
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    cnt = s.count(o)
    if cnt != 1:
        print("FAIL[%s] count=%d" % (tag, cnt))
        sys.exit(1)
    print("OK[%s]" % tag)
    return s.replace(o, n, 1)


old = '''\tvar ne1 := RunState.next_level({"type": "elite"})

\tcheck(int(ne1["tier"]) == GameLevels.TIER_ELITE_EASY, "第 1 场精英：精英敌人-简单")

\tRunState.on_battle_won("elite")

\tcheck(int(RunState.next_level({"type": "elite"})["tier"])

\t\t\t== GameLevels.TIER_ELITE_HARD,

\t\t\t"第 2 场精英：精英敌人-困难（R506 起困难提早在第 2 场登场）")

\tRunState.on_battle_won("elite")

\tcheck(int(RunState.next_level({"type": "elite"})["tier"])

\t\t\t== GameLevels.TIER_ELITE_HARD, "第 3 场精英：仍为精英敌人-困难")
'''

new = '''\t# ---- R778：精英强弱按**当前巧克力**（<= 5 强精英 / > 5 弱精英）----

\tvar r778_choco_backup: int = RunState.chocolate

\tRunState.chocolate = 12

\tcheck(int(RunState.next_level({"type": "elite"})["tier"]) == GameLevels.TIER_ELITE_EASY,

\t\t\t"R778 巧克力 12：弱精英（精英敌人-简单）")

\tRunState.chocolate = 6

\tcheck(int(RunState.next_level({"type": "elite"})["tier"]) == GameLevels.TIER_ELITE_EASY,

\t\t\t"R778 巧克力 6（边界外）：仍为弱精英")

\tRunState.chocolate = 5

\tcheck(int(RunState.next_level({"type": "elite"})["tier"]) == GameLevels.TIER_ELITE_HARD,

\t\t\t"R778 巧克力 5（边界内）：强精英（精英敌人-困难）")

\tRunState.chocolate = 0

\tcheck(int(RunState.next_level({"type": "elite"})["tier"]) == GameLevels.TIER_ELITE_HARD,

\t\t\t"R778 巧克力 0：仍为强精英")

\tcheck(RunState.elite_tier_for_chocolate(5) == GameLevels.TIER_ELITE_HARD

\t\t\tand RunState.elite_tier_for_chocolate(6) == GameLevels.TIER_ELITE_EASY,

\t\t\t"R778 判据纯函数：<= 5 → 精英困难，> 5 → 精英简单")

\tRunState.chocolate = 12

\tcheck(int(RunState.next_level(

\t\t\t{"type": "elite", "layer": GameLayers.LAYER_THREE})["tier"])

\t\t\t== GameLevels.TIER_ELITE_HARD,

\t\t\t"R778 第三层不变：巧克力 12 也仍走第二层精英困难池")

\tRunState.chocolate = r778_choco_backup
'''
s = rep_crlf(s, old, new, "测试段")

save(p, s)
print("PATCH DONE")
