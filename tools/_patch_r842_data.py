# -*- coding: utf-8 -*-
"""R842 补丁 ① 数据层：附魔 brawn（力量 +8）+「稀有价值」6090 + 第一层事件登记。

纪律：逐条 exact-replace + assert count==1；按各文件**自己的行尾**写回
（card_data.gd = CRLF；run_state.gd / game_layers.gd = LF）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def read(p):
    with io.open(ROOT + p, "rb") as f:
        return f.read().decode("utf-8")


def write(p, s):
    with io.open(ROOT + p, "wb") as f:
        f.write(s.encode("utf-8"))


def patch(p, pairs):
    s = read(p)
    nl = "\r\n" if s.count("\r\n") > 0 else "\n"
    for i, (old, new) in enumerate(pairs):
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = s.count(o)
        assert c == 1, "%s 第 %d 条锚点出现 %d 次：%r" % (p, i + 1, c, old[:60])
        s = s.replace(o, n)
    write(p, s)
    print("OK", p)


# ── ① card_data.gd：ENCHANT_DEFS 加 brawn + 随机池排除 ─────────────────────
patch("scripts/card_data.gd", [
    (
        '\t"core": {"label": "契约核心", "icon": "shop_icon_damage", "col": "d06be0",\n'
        '\t\t\t"desc": "这张技能卡的伤害提高，数值等于被献祭的那张技能卡的第一段伤害。"},\n'
        '}',
        '\t"core": {"label": "契约核心", "icon": "shop_icon_damage", "col": "d06be0",\n'
        '\t\t\t"desc": "这张技能卡的伤害提高，数值等于被献祭的那张技能卡的第一段伤害。"},\n'
        '\t# R842（店长口径「新增一层事件 龙石板」选项 1）：**事件独有**附魔 —— 给盟友 / 工事\n'
        '\t# +8 力量。视觉沿用「伤害 +8」那枚标记（同图标、同环色），玩家一眼认得出是「+8」那一类；\n'
        '\t# 但它不进商店（`shop_scene.ENCHANTS` 里没有）、也不进随机池\n'
        '\t# （`ENCHANT_RANDOM_EXCLUDE`）—— 只有龙石板发得出来。\n'
        '\t"brawn": {"label": "力量 +8", "icon": "shop_icon_damage", "col": "f08a5a",\n'
        '\t\t\t"desc": "这张盟友或工事的力量 +8。"},\n'
        '}',
    ),
    (
        '## ⚠️ 契约核心（`core`）**不在**里面：它的数值来自「被献祭的那张技能卡」，\n'
        '##    随机给出来的只会是 +0 —— 那就成了一张空附魔，所以随机池必须把它排除。\n'
        'const ENCHANT_RANDOM_EXCLUDE := ["core"]',
        '## ⚠️ 契约核心（`core`）**不在**里面：它的数值来自「被献祭的那张技能卡」，\n'
        '##    随机给出来的只会是 +0 —— 那就成了一张空附魔，所以随机池必须把它排除。\n'
        '## R842：`brawn`（力量 +8）同理 —— 它是事件「龙石板」专属，商店与牛奶 / 附魔大师\n'
        '##    都不该摇到它（摇到就等于把事件奖励漏进了随机池）。\n'
        'const ENCHANT_RANDOM_EXCLUDE := ["core", "brawn"]',
    ),
])

# ── ② run_state.gd：附魔资格 / 数值 +「稀有价值」整段 ──────────────────────
RARE_BLOCK = '''
# ── R842「稀有价值」（6090，第一层事件「龙石板」选项 2）──────────────────────
## 店长口径（原话）：「获得道具稀有价值。卡组同名卡最多 3 张，超出则随机删除直到只有
## 3 张为止。**每因此效果删除一张卡**受到 5 点伤害。」＋「只管完整卡组」「如果选此选项会
## 立即死亡则不能选」。
##   · **只管获得那一刻**的完整卡组（`deck_ids`）—— 删完即结束，之后的卡组变化不再受它约束；
##   · 只有**本效果删掉的**卡才算账：界面与结算读同一个 `rare_value_targets()`，不会两套数；
##   · 会当场致死 → 按钮置灰 + `rare_value_prune()` 再拒一次
##     （R793 拔剑的教训：只在界面拦 = 没拦）；
##   · 删哪几张由「种子 + 层 + 节点 + 下标」派生，不摇 `run_rng`、不进存档（R819 同口径）。
const RARE_VALUE_ID := 6090
const RARE_VALUE_MAX_COPIES := 3
const RARE_VALUE_LOSS := 5


static func rare_value_targets(repo: CardRepo) -> Array[int]:
	## 这一次**真的会被撕掉**的卡（deck 下标，**从大到小**排好 —— 逐个删不会串位）。
	## 带锁的卡（`remove_block_reason() != ""`：月亮 / 硬币 / 罐子）不进候选 ——
	## 与 `delete_deck_card()` 同一道闸，别在这里另开一条路。
	var by_name: Dictionary = {}
	for i in deck_ids.size():
		var c := repo.get_card(int(deck_ids[i]))
		var key: String = c.card_name if c != null else str(deck_ids[i])
		if not by_name.has(key):
			by_name[key] = []
		(by_name[key] as Array).append(i)
	var pool: Array[int] = []
	for key: String in by_name:
		var idxs: Array = by_name[key]
		if idxs.size() <= RARE_VALUE_MAX_COPIES:
			continue
		var need: int = idxs.size() - RARE_VALUE_MAX_COPIES
		var removable: Array[int] = []
		for raw_i: int in idxs:
			if remove_block_reason(raw_i) == "":
				removable.append(raw_i)
		if removable.is_empty():
			continue
		var picked: Array[int] = _rare_value_order(removable)
		for k in mini(need, picked.size()):
			pool.append(picked[k])
	pool.sort()
	pool.reverse()
	return pool


static func _rare_value_order(pool: Array[int]) -> Array[int]:
	## 稳定洗牌：排序键 = `hash(种子, 层, 节点, deck 下标)`。
	## 同一局同一间房**必然同一结果** —— 退出重进换不了牌（R819 占卜室 / R822 主持人同一口径）。
	## ⚠️ 不用 `run_rng`：那会扰动掉落顺序链，也让「回标题再继续」变成重摇按钮。
	var stay := current_layer * 10000 + current_node_id
	var out: Array[int] = pool.duplicate()
	out.sort_custom(func(a: int, b: int) -> bool:
		var ha := absi(hash("%d:%d:%d:%d" % [run_seed, stay, a]))
		var hb := absi(hash("%d:%d:%d:%d" % [run_seed, stay, b]))
		if ha == hb:
			return a < b
		return ha < hb)
	return out


static func rare_value_damage(repo: CardRepo) -> int:
	## 「每因此效果删除一张卡」= 5 点 —— 只有 `rare_value_targets()` 里的卡才计。
	return rare_value_targets(repo).size() * RARE_VALUE_LOSS


static func rare_value_lethal(repo: CardRepo) -> bool:
	## 选了会当场倒下（伤害把当前生命打到 0 或以下）→ 这个选项不能选。
	var dmg := rare_value_damage(repo)
	return dmg > 0 and hp - dmg <= 0


static func rare_value_prune(repo: CardRepo) -> Dictionary:
	## 结算：撕掉超出上限的同名卡 → 每张失去 `RARE_VALUE_LOSS` 点生命。
	## 返回 {ok, deleted: Array[String], damage, blocked}；`ok = false` = 会致死，**一张都没删**。
	var targets := rare_value_targets(repo)
	var dmg: int = targets.size() * RARE_VALUE_LOSS
	if dmg > 0 and hp - dmg <= 0:
		return {"ok": false, "deleted": [], "damage": 0, "blocked": true}
	var names: Array[String] = []
	for i: int in targets:
		var c := repo.get_card(int(deck_ids[i]))
		var nm: String = c.card_name if c != null else str(deck_ids[i])
		if delete_deck_card(i):
			names.append(nm)
	var lost: int = names.size() * RARE_VALUE_LOSS
	if lost > 0:
		hp = maxi(0, hp - lost)
	return {"ok": true, "deleted": names, "damage": lost, "blocked": false}


'''

patch("scripts/run_state.gd", [
    (
        '\t\t"core":\n'
        '\t\t\t# R458 契约核心：只给**能取到第一段伤害**的伤害技能卡。数值由献祭方给，\n'
        '\t\t\t# 所以资格只看「自己是不是一张拿得出段伤的伤害技能卡」。\n'
        '\t\t\t# ⚠️ 随机池（牛奶 / 附魔大师）不会摇到它，见 `CardData.random_enchant_ids()`。\n'
        '\t\t\treturn c.is_damage_spell() and GameEngine.spell_first_hit(c) > 0\n',
        '\t\t"core":\n'
        '\t\t\t# R458 契约核心：只给**能取到第一段伤害**的伤害技能卡。数值由献祭方给，\n'
        '\t\t\t# 所以资格只看「自己是不是一张拿得出段伤的伤害技能卡」。\n'
        '\t\t\t# ⚠️ 随机池（牛奶 / 附魔大师）不会摇到它，见 `CardData.random_enchant_ids()`。\n'
        '\t\t\treturn c.is_damage_spell() and GameEngine.spell_first_hit(c) > 0\n'
        '\t\t"brawn":\n'
        '\t\t\t# R842 事件「龙石板」选项 1：只给**盟友 / 工事**（与 `dimension` 同一类判据）。\n'
        '\t\t\t# 技能卡的 `power` 不会被任何结算读（伤害写在 `effect_text` 里），给了也是白给。\n'
        '\t\t\t# ⚠️ 不进商店、不进随机池 —— 见 `CardData.ENCHANT_RANDOM_EXCLUDE`。\n'
        '\t\t\treturn (c.kind == "盟友" or c.is_fort()) and not c.is_effect()\n',
    ),
    (
        '\t\t"damage": m = {"power": 8, "note": "伤害 +8"}\n',
        '\t\t"damage": m = {"power": 8, "note": "伤害 +8"}\n'
        '\t\t# R842：事件独有附魔 —— 与「伤害 +8」同样烤进 `power`，只是限定盟友 / 工事。\n'
        '\t\t# 标注写「力量 +8」而不是「伤害 +8」：卡面数值框加的是力量，文案得对得上。\n'
        '\t\t"brawn": m = {"power": 8, "note": "力量 +8"}\n',
    ),
    (
        'static func transform_deck_card(repo: CardRepo, index: int, same_class := false) -> Dictionary:',
        RARE_BLOCK.lstrip("\n")
        + 'static func transform_deck_card(repo: CardRepo, index: int, same_class := false) -> Dictionary:',
    ),
])

# ── ③ game_layers.gd：第一层事件登记 + 名字表 ─────────────────────────────
patch("scripts/game_layers.gd", [
    (
        '\t\t\t"sword": 16,\n',
        '\t\t\t"sword": 16,\n'
        '\t\t\t# R842（店长口径「新增一层事件 龙石板」）：一块刻着盘龙的土黄石板 ——\n'
        '\t\t\t# 把它当「强力的龙」→ 一张盟友 / 工事附魔「力量 +8」（事件独有附魔 brawn）；\n'
        '\t\t\t# 当「尊贵的龙」→ 道具「稀有价值」6090（同名卡削到 3 张，每因此效果删一张失 5 点\n'
        '\t\t\t# 生命；会当场致死时这个选项不可选）。与「林中的剑」同属「石板 / 图腾」那一类。\n'
        '\t\t\t"dragon_slab": 16,\n',
    ),
    (
        '\t"sword": "林中的剑",\n',
        '\t"sword": "林中的剑",\n'
        '\t"dragon_slab": "龙石板",\n',
    ),
])
print("done")
