# -*- coding: utf-8 -*-
"""R752 补丁：TrapData / TrapRepo / shop_scene —— 工具表新增「选卡型 / 填满型」与商店池。
每个替换都断言命中次数，避免锚点漂移后静默改错。"""
import io
import sys

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


# ---- trap_data.gd ----
patch("scripts/trap_data.gd", [
    (
        """## R745：使用型工具给**本场战斗**所有己方盟友的力量加成（野性图腾 7008 = 2）。
## >0 → 不放置，点一下直接用。与回血 / 回费不同，这个加成**不会因为工具被用掉而消失** ——
## 它在本场战斗里持续生效（口径与竖琴 6052 的持续 buff 一致，见 `Placement.totem_atk`）。
var ally_atk := 0
""",
        """## R745：使用型工具给**本场战斗**所有己方盟友的力量加成（野性图腾 7008 = 2）。
## >0 → 不放置，点一下直接用。与回血 / 回费不同，这个加成**不会因为工具被用掉而消失** ——
## 它在本场战斗里持续生效（口径与竖琴 6052 的持续 buff 一致，见 `Placement.totem_atk`）。
var ally_atk := 0
## R752：使用型工具里**需要先选卡**的那一类（万能牌 7009 / 神秘牌 7011）。
##   * `"deck_copy"` —— 从抽牌库选一张，幻影复制入手（费用 0，离手即恢复原费用）；
##   * `"random3"`   —— 从随机 3 张本职业奖励卡里选一张入手，本回合费用 0。
## 空串 = 选中即结算（回血 / 回费 / 力量这一类）。
## ⚠️ 它把「使用」拆成两段（点工具 → 选卡页 → 确认才摘槽），
##    所以界面**不许**在 `use_tool` 之后无条件 consume，见 `battle_scene._use_tool_slot`。
var pick_kind := ""
## R752：快送鸭 7010 —— 使用后**用随机商店工具填满工具栏**（不选卡、当场结算）。
## 与 `pick_kind` 并列：一个工具只说明自己「怎么生效」，判据全在数据里。
var fill_toolbar := false
""",
    ),
    (
        """## R690：「工具」分两类 —— 放置型（陷阱，拖到战场空格）与使用型（药水，轻点即用）。
## 判据只看数据：带 heal_pct / energy / ally_atk 的就是使用型，界面与引擎共用这一个口。
func is_usable() -> bool:
	return heal_pct > 0 or energy > 0 or ally_atk > 0
""",
        """## R690：「工具」分两类 —— 放置型（陷阱，拖到战场空格）与使用型（药水，轻点即用）。
## 判据只看数据：带 heal_pct / energy / ally_atk / pick_kind / fill_toolbar 的就是使用型，
## 界面与引擎共用这一个口。
func is_usable() -> bool:
	return heal_pct > 0 or energy > 0 or ally_atk > 0 \\
			or pick_kind != "" or fill_toolbar


## R752（用户口径「以后没有售价的则不计入商店」）：**能不能上商店货架**只看售价。
## `price <= 0` = 没有售价 = 非卖品（烤肉 7007 只能休息处烤，万能牌 / 快送鸭 / 神秘牌
## 只能靠掉落或工具箱拿到）。⚠️ 判据只写这一处 —— 商店取货、快送鸭的池子都走它。
func in_shop() -> bool:
	return price > 0
""",
    ),
    (
        """	t.rest_only = bool(d.get("rest_only", false))
	t.ally_atk = int(d.get("ally_atk", 0))
	return t
""",
        """	t.rest_only = bool(d.get("rest_only", false))
	t.ally_atk = int(d.get("ally_atk", 0))
	t.pick_kind = str(d.get("pick_kind", ""))
	t.fill_toolbar = bool(d.get("fill_toolbar", false))
	return t
""",
    ),
])

# ---- trap_repo.gd ----
patch("scripts/trap_repo.gd", [
    (
        """func random_traps() -> Array[TrapData]:
	## R743：**可随机获得**的工具（战斗 10% 掉落 / 商店货架）。
	## `rest_only` 的那些（烤肉 7007）只能从休息处烤出来 —— 混进随机池，
	## 「篝火专属」就成了「哪儿都能捡」，烤肉的稀缺感连同休息处的选择一起作废。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if not t.rest_only:
			out.append(t)
	return out
""",
        """func random_traps() -> Array[TrapData]:
	## R743：**可随机获得**的工具（战斗 10% 掉落 / 工具箱 6068）。
	## `rest_only` 的那些（烤肉 7007）只能从休息处烤出来 —— 混进随机池，
	## 「篝火专属」就成了「哪儿都能捡」，烤肉的稀缺感连同休息处的选择一起作废。
	## ⚠️ R752：这条口径**只管「拿得到」**，不再代表货架。商店走 `shop_traps()` ——
	##    万能牌 / 快送鸭 / 神秘牌没有售价，能掉落但不能买（用户口径「没有售价的则不计入商店」）。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if not t.rest_only:
			out.append(t)
	return out


func shop_traps() -> Array[TrapData]:
	## R752：**商店货架**的唯一取池口（`shop_scene` 与快送鸭 7010 共用）。
	## 判据收在 `TrapData.in_shop()` 里（`price > 0`），这里只做筛选 —— 别再各写一份。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if t.in_shop():
			out.append(t)
	return out
""",
    ),
])

# ---- shop_scene.gd ----
patch("scripts/shop_scene.gd", [
    (
        """	# R743：`random_traps()` —— 烤肉 7007 是 `rest_only`（只能休息处烤），
	# 用 `all_traps()` 会把它摆上货架，price 0 = 白送一份。
	var tpool: Array = TrapRepo.load_json().random_traps()""",
        """	# R752：货架池走 `shop_traps()`（= `price > 0`）。旧版用 `random_traps()`，
	# 那是「能掉落」的口径 —— 万能牌 7009 / 快送鸭 7010 / 神秘牌 7011 没有售价，
	# 一旦摆上货架就是白送（用户口径「以后没有售价的则不计入商店」）。
	# 烤肉 7007 同样进不来：它 price 0，且 `rest_only` 本来就只在休息处烤。
	var tpool: Array = TrapRepo.load_json().shop_traps()""",
    ),
])

print("OK")
