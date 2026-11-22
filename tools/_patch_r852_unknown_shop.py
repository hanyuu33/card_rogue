# -*- coding: utf-8 -*-
"""R852：难度 10 起「?」房恢复刷商店；精英加权的代价只从战斗/事件/宝箱里扣。
逐处 exact-replace + assert count==1。
"""
import io, sys, os

ROOT = r"E:\work\card_rogue"

def load(rel):
    p = os.path.join(ROOT, rel)
    with io.open(p, "r", encoding="utf-8", newline="") as f:
        return p, f.read()

def save(p, s):
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)

def rep(s, old, new, tag):
    n = s.count(old)
    assert n == 1, "[%s] 期望 1 处，实得 %d" % (tag, n)
    return s.replace(old, new)

# ============================================================ rogue_map.gd (LF)
p, s = load(r"scripts\rogue_map.gd")

old = (
"## R380（难度 10「精英出现增多」）：10 档起「?」房**不再刷商店**（shop 键被裁掉 →\n"
"## 每层商店固定 2 间 + 右上角 1 间），精英出现概率统一 ×1.3。裁剪后的表见 `_unknown_table()`\n"
"## —— **别再直接读 `WEIGHTS_UNKNOWN`**（那会绕过难度 10 的口径）。\n"
)
new = (
"## R380（难度 10「精英出现增多」）：精英出现概率统一 ×1.3（明房 / 「?」房两条途径同一个口）。\n"
"## R852（用户口径）：「10 难度起，? 依旧需要刷新商店，概率从事件、普通战斗、宝箱里面扣」\n"
"## —— 原先「10 档裁掉 shop」的裁剪**已撤销**，「?」房照旧刷商店；精英 +30% 多出来的权重\n"
"## 只从 **battle / event / chest** 里按比例扣，**shop 一分不扣** → 商店占比与低难度逐位相同。\n"
"## 见 `_weighted_far()` 里的 `pool_w` / `scale`。\n"
)
s = rep(s, old, new, "常量区注释")

# 删除 _unknown_table()，并把两处调用改成直接读 WEIGHTS_UNKNOWN
old = (
"static func _unknown_table() -> Dictionary:\n"
"\t## 当前难度下「?」房该用的权重表。\n"
"\t## R380：难度 10 起去掉 `shop` —— 商店只剩「开局标记 1 间 + `shop_set` 恒定 2 间」，\n"
"\t## 不再由「?」房额外贡献（用户口径「每层商店数量调整为固定 2 个，不算右上角」）。\n"
"\t## ⚠️ 生成期（`_make_cells`）与水晶骰子的重摇（`_unknown_weights`）都必须走这里，\n"
"\t##    否则两条路会给出不同的商店 / 精英分布。\n"
"\tif not RunState.unknown_shop_allowed():\n"
"\t\tvar w: Dictionary = WEIGHTS_UNKNOWN.duplicate()\n"
"\t\tw.erase(\"shop\")\n"
"\t\treturn w\n"
"\treturn WEIGHTS_UNKNOWN\n"
"\n"
"\n"
)
s = rep(s, old, "", "删除 _unknown_table()")

old = "\tvar nb_w: Dictionary = _unknown_table().duplicate()\n"
s = rep(s, old, "\tvar nb_w: Dictionary = WEIGHTS_UNKNOWN.duplicate()\n", "_unknown_weights 内 nb_w")

old = "\treturn _unknown_table()\n"
s = rep(s, old, "\treturn WEIGHTS_UNKNOWN\n", "_unknown_weights 末尾")

old = "\t\t\t\t\tvar nb_w: Dictionary = (_unknown_table() if hidden else WEIGHTS).duplicate()\n"
s = rep(s, old, "\t\t\t\t\tvar nb_w: Dictionary = (WEIGHTS_UNKNOWN if hidden else WEIGHTS).duplicate()\n",
        "_make_cells nb_w")

old = "\t\t\t\ttype = _weighted_far(_unknown_table() if hidden else WEIGHTS, rng,\n"
s = rep(s, old, "\t\t\t\ttype = _weighted_far(WEIGHTS_UNKNOWN if hidden else WEIGHTS, rng,\n",
        "_make_cells _weighted_far")

# _weighted_far：扣减池排除 shop
old = (
"\t## R380（难度 10「精英出现增多」）：精英权重乘 `RunState.elite_weight_mul()`，并且把\n"
"\t## **多出来的那部分按比例从其他类型里扣掉**（总权重不变）—— 于是涨的是**出现概率**\n"
"\t## （恰好 ×1.3），而不是「权重 ×1.3、占比只涨两成」。明房 / 「?」房共用这一个口。\n"
"\t## ⚠️ 低难度 `mul = 1.0` → `drop = 0` → `f = 1`，这条分支是**恒等**的：\n"
"\t##    同一个种子出图与改动前逐格一致（R380 回归里钉住这一点）。\n"
"\tvar ww := {}\n"
"\tvar total := 0\n"
"\tvar base_w := int(w.get(\"elite\", 0))\n"
"\tvar mul := RunState.elite_weight_mul()\n"
"\tvar others := 0\n"
"\tfor k in w:\n"
"\t\tif str(k) == \"elite\":\n"
"\t\t\tcontinue\n"
"\t\tothers += int(w[k]) * 100\n"
"\tvar f := 1.0\n"
"\tif base_w > 0:\n"
"\t\tvar e := 100.0 * elite_weight_scaled(base_w, col, row, norm)\n"
"\t\tvar e_new := e * mul\n"
"\t\tvar drop := e_new - e\n"
"\t\tif others > 0 and drop > 0.0:\n"
"\t\t\tf = maxf(0.0, (float(others) - drop) / float(others))\n"
"\t\tww[\"elite\"] = maxi(1, roundi(e_new))\n"
"\tfor k in w:\n"
"\t\tif str(k) == \"elite\":\n"
"\t\t\tcontinue\n"
"\t\tww[k] = maxi(1, roundi(float(int(w[k]) * 100) * f))\n"
"\t\ttotal += int(ww[k])\n"
)
new = (
"\t## R380（难度 10「精英出现增多」）：精英权重乘 `RunState.elite_weight_mul()`，并且把\n"
"\t## **多出来的那部分按比例从其他类型里扣掉**（总权重不变）—— 于是涨的是**出现概率**\n"
"\t## （恰好 ×1.3），而不是「权重 ×1.3、占比只涨两成」。明房 / 「?」房共用这一个口。\n"
"\t## R852（用户口径）：「10 难度起，? 依旧需要刷新商店，概率从事件、普通战斗、宝箱里面扣」\n"
"\t##   * 扣减池 `pool_w` = 除 **elite / shop** 之外的类型 → 明房是 battle + event，\n"
"\t##     「?」房是 battle + event + chest，**商店一分不扣**；\n"
"\t##   * 于是商店占比与低难度**逐位相同**，精英占比仍精确 ×1.3（总权重守恒）。\n"
"\t## ⚠️ 低难度 `mul = 1.0` → `drop = 0` → `f = 1`，这条分支是**恒等**的：\n"
"\t##    同一个种子出图与改动前逐格一致（R380 回归里钉住这一点）。\n"
"\tvar ww := {}\n"
"\tvar total := 0\n"
"\tvar base_w := int(w.get(\"elite\", 0))\n"
"\tvar mul := RunState.elite_weight_mul()\n"
"\tvar pool_w := 0\n"
"\tfor k in w:\n"
"\t\tif str(k) == \"elite\" or str(k) == \"shop\":\n"
"\t\t\tcontinue\n"
"\t\tpool_w += int(w[k]) * 100\n"
"\tvar f := 1.0\n"
"\tif base_w > 0:\n"
"\t\tvar e := 100.0 * elite_weight_scaled(base_w, col, row, norm)\n"
"\t\tvar e_new := e * mul\n"
"\t\tvar drop := e_new - e\n"
"\t\tif pool_w > 0 and drop > 0.0:\n"
"\t\t\tf = maxf(0.0, (float(pool_w) - drop) / float(pool_w))\n"
"\t\tww[\"elite\"] = maxi(1, roundi(e_new))\n"
"\tfor k in w:\n"
"\t\tif str(k) == \"elite\":\n"
"\t\t\tcontinue\n"
"\t\tvar scale := f\n"
"\t\tif str(k) == \"shop\":\n"
"\t\t\tscale = 1.0              # R852：商店不承担精英加权的代价\n"
"\t\tww[k] = maxi(1, roundi(float(int(w[k]) * 100) * scale))\n"
"\t\ttotal += int(ww[k])\n"
)
s = rep(s, old, new, "_weighted_far 扣减池")

save(p, s)
print("rogue_map.gd OK")

# ============================================================ run_state.gd (LF)
p, s = load(r"scripts\run_state.gd")

old = (
"#   10 = 精英出现增多（R380）：继承 0~9 全部 debuff，另外「?」房不再刷商店（每层商店\n"
"#        固定 2 间 + 右上角 1 间）、明房与「?」房两条途径的精英出现概率统一 ×1.3（约 +30%）。\n"
)
new = (
"#   10 = 精英出现增多（R380 / R852）：继承 0~9 全部 debuff，明房与「?」房两条途径的\n"
"#        精英出现概率统一 ×1.3（约 +30%）。R852：「?」房**照旧刷商店**（原「10 档裁掉\n"
"#        shop」已撤销），加权代价只从战斗 / 事件 / 宝箱里扣，商店占比与低难度一致。\n"
)
s = rep(s, old, new, "run_state 难度表注释")

old = (
"## R380（用户口径）：「当前难度 10 还没有新增效果，做成精英出现增多 —— 每层商店数量\n"
"## 调整为固定 2 个（不算右上角），各种途径出现精英的概率上调约 30%」。\n"
"##   * 「?」房不再刷出商店 → 每层商店恒为「右上角固定 1 间 + 随机 2 间」；\n"
"##   * 明房与「?」房两条途径的精英出现概率统一 ×1.3（约 +30%）。\n"
"## ⚠️ 唯一消费点 = `RogueMap._weighted_far()`（出现概率）/ `RogueMap._unknown_table()`\n"
"##    （「?」房权重表）—— 别在地图生成之外再乘一次，否则会被重复加权。\n"
)
new = (
"## R380（用户口径）：「当前难度 10 还没有新增效果，做成精英出现增多 —— 各种途径出现\n"
"## 精英的概率上调约 30%」。\n"
"## R852（用户口径）：「10 难度起，? 依旧需要刷新商店，概率从事件、普通战斗、宝箱里面扣」\n"
"##   * 原「10 档「?」房裁掉 shop」的裁剪**撤销** —— 「?」房照旧能刷商店；\n"
"##   * 精英 +30% 多出来的权重只从 **battle / event / chest** 里按比例扣，**shop 不扣**\n"
"##     → 商店占比与低难度逐位相同（见 `RogueMap._weighted_far()` 的 `pool_w`）。\n"
"## ⚠️ 唯一消费点 = `RogueMap._weighted_far()` —— 别在地图生成之外再乘一次。\n"
)
s = rep(s, old, new, "run_state R380 注释")

old = (
"static func unknown_shop_allowed() -> bool:\n"
"\t## 10 档起「精英出现增多」的配套：**「?」房不再刷出商店**。\n"
"\t## 于是每层商店 = 右上角那间固定商店 + `RogueMap.SHOP_MIN/MAX` 那 2 间，数量恒定\n"
"\t## （用户口径「每层商店数量调整为固定 2 个，不算右上角」）。\n"
"\t## 低档位维持原样（「?」房仍可能刷出商店）。\n"
"\treturn _diff() < DIFF_ELITE_FROM\n"
"\n"
"\n"
)
s = rep(s, old, "", "删除 unknown_shop_allowed()")

save(p, s)
print("run_state.gd OK")
