# -*- coding: utf-8 -*-
"""R688 引擎补丁：幽深回响（9002 取代迅捷）+ 镜像 9056 改为可叠加。保留 CRLF。"""
import sys

P = "E:/work/card_rogue/scripts/game_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n"), "源文件不是纯 CRLF"
src = raw.replace("\r\n", "\n")
edits = []


def rep(old, new, tag):
    edits.append((old, new, tag))


# ① 常量
rep('const MIRROR_TRAIT:= "镜像"\n',
    'const MIRROR_TRAIT:= "镜像"\n'
    '# 幽深回响（9002，R688 取代迅捷）：使用时复制进抽牌库，回合开始按效果区张数打 X 下。\n'
    'const ECHO_TRAIT:= "幽深回响"\n',
    "const")

# ② 使用时复制
rep('''func _on_effect_card_played(side: String, played: CardData) -> void :
	_assemble_tick(side, "effect_played")
''',
    '''func _on_effect_card_played(side: String, played: CardData) -> void :
	_assemble_tick(side, "effect_played")
	# 幽深回响（9002）：**使用时**把一张同名副本放进抽牌库。
	# ⚠️ 位置必须在 `use_effect()` 的 `state.effects.append()` **之前**（本函数就在那个点被调）：
	#    副本进的是抽牌库、本体随后才入效果区 —— 顺序反了「打一张摸一张」就变成同一张自己。
	if played != null and played.traits.has(ECHO_TRAIT):
		_echo_cast(side, played)
''',
    "on_play")

# ③ 镜像：不可叠加 → 每回合前 X 次
rep('''	# 镜像（9056）：每回合**第一次**使用效果牌时，把该牌的一张同名副本加入本局卡组，**并抽一张卡**。
	# 「不可叠加」→ 效果区里有几张镜像都只触发一次、只加一张、也只抽一张，
	# **不进**下面的「每回合第 X 次」放宽组。
	if _trait_copies(zone, MIRROR_TRAIT) > 0 and plays <= 1:
		_mirror_reflect(side, played)
''',
    '''	# 镜像（9056）：**每回合前 X 次**使用效果牌时，把该牌的一张同名副本加入本局卡组，**并抽一张卡**。
	# R688（店长口径）：由「每回合第一次」放宽为**可叠加** —— X = 效果区里镜像的张数，
	# 与威慑 / 鸭窝 / 飓风咆哮 / 和风守护同一条「每回合前 X 次」口径（单张时 X=1，行为不变）。
	var mir_n:= _trait_copies(zone, MIRROR_TRAIT)
	if mir_n > 0 and plays <= mir_n:
		_mirror_reflect(side, played)
''',
    "mirror")

# ④ 两个新函数（摆在 _mirror_reflect 前面，同族放一起）
rep('''func _mirror_reflect(side: String, played: CardData) -> void :
''',
    '''func _echo_cast(side: String, played: CardData) -> void :
	## 幽深回响（9002，R688 店长口径）：**使用时**，把一张同名副本放进抽牌库。
	## * 本体照常留在效果区 —— X 数的就是效果区张数，所以这张副本是「下一张」；
	## * 与镜像 9056 的区别：镜像抄的是别人打的牌、还附带抽一张；这里只复制自己、不抽卡，
	##   于是它唯一的滚雪球方式就是「打一张、下回合摸到下一张」；
	## * 敌方没有真实牌库 → 只推进 `opp_deck_count`（与镜像 / 潜袭 `_shadow_split_draw` 同口径）。
	if played == null:
		return
	if side == SIDE_SELF:
		var copy := CardData.from_dict(played.to_dict())
		state.deck.append(copy)
		_log("幽深回响：一张「%s」加入抽牌库（抽牌库 %d 张）" % [copy.card_name, state.deck.size()])
		action.emit("deck_added", {"card": copy, "side": side})
	else:
		state.opp_deck_count += 1
		_log("幽深回响（敌方）：本局卡组 +1 张「%s」" % played.card_name)


func _echo_tick(side: String) -> void :
	## 幽深回响（9002）：**回合开始时**，对随机敌人造成 `value`（现为 6）点伤害，重复 X 次。
	## * X = 效果区里本卡的张数（`_trait_copies()`，与威慑 / 恐惧化身同一口径）；
	## * 每一下**重新挑目标**：这一下把敌人打死了，下一不会继续砸尸体；
	## * 没有敌方单位 → 这一下直击对方 HP（与飓风咆哮同口径，不吞伤害）；
	## * 伤害走 `_hit_unit()`：护盾 / 减伤 / 标记加伤 / 光环照常生效，致死交 `_destroy_dead()`；
	## * 候选格先 `sort()` 再按引擎 rng 取 → 同种子回放可复现（不依赖字典迭代顺序）。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var n:= _trait_copies(zone, ECHO_TRAIT)
	if n <= 0:
		return
	var dmg:= 6
	for c: CardData in zone:
		if c.traits.has(ECHO_TRAIT):
			dmg = maxi(1, c.value)
			break
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var hits:= 0
	for i in n:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in state.board:
			if state.board[cell].owner == foe:
				cells.append(cell)
		cells.sort()
		if cells.is_empty():
			_damage_player(foe, dmg, "幽深回响")
			_log("幽深回响：没有敌方单位 → 第 %d 下直击对方 HP %d 点" % [i + 1, dmg])
			hits += 1
			continue
		var t: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var p: Placement = state.unit_at(t)
		if p == null:
			continue
		_hit_unit(p, dmg, "幽深回响")
		_log("幽深回响：第 %d/%d 下 → %s 受 %d 点伤害" % [i + 1, n, p.card.card_name, dmg])
		hits += 1
		_destroy_dead()
	if hits > 0:
		action.emit("echo", {"times": hits, "dmg": dmg, "side": side})


func _mirror_reflect(side: String, played: CardData) -> void :
''',
    "funcs")

# ⑤ 回合开始挂接（我方 / 敌方各一条）
rep('''		_wisdom_surge()
		_endless_blessing()
''',
    '''		_wisdom_surge()
		_endless_blessing()
		_echo_tick(SIDE_SELF)            # 幽深回响 9002（R688）：效果区几张就打几下
''',
    "turn_self")

rep('''		_melt_ice_walls(SIDE_OPPONENT)
		_clear_fire_walls(SIDE_OPPONENT)
''',
    '''		_melt_ice_walls(SIDE_OPPONENT)
		_clear_fire_walls(SIDE_OPPONENT)
		_echo_tick(SIDE_OPPONENT)        # 幽深回响 9002（R688，对称保留）
''',
    "turn_opp")

# ⑥ 旧文案/注释：迅捷已不存在
rep('	# 放在减伤之前会替玩家白挡掉鸭嘴 / 迅捷那一层，等于把减伤也吃了。',
    '	# 放在减伤之前会替玩家白挡掉鸭嘴 / 效果牌减伤那一层，等于把减伤也吃了。',
    "cmt_swift1")
rep('_log("减伤（迅捷/鸭嘴）：伤害 %d → %d" % [amount, dmg])',
    '_log("减伤（效果牌/鸭嘴）：伤害 %d → %d" % [amount, dmg])',
    "log_swift")
rep('''func _effect_damage_reduction() -> int:
''',
    '''func _effect_damage_reduction() -> int:
	## 效果区里带「减伤」trait 的牌，按 `value` 逐张累加（唯一口，`_hp_damage_taken` 调）。
	## ⚠️ R688：迅捷 9002 已改成幽深回响，卡库里目前**没有**「减伤」效果牌。
	##    通道保留 —— 组合产物 / 后续新卡仍可挂这个 trait，别当成死代码删掉。
''',
    "func_cmt")

out = src
for old, new, tag in edits:
    c = out.count(old)
    if c != 1:
        raise SystemExit("[%s] 锚点命中 %d 次，拒绝写入" % (tag, c))
    out = out.replace(old, new)

if "--write" in sys.argv:
    open(P, "wb").write(out.replace("\n", "\r\n").encode("utf-8"))
    b = open(P, "rb").read()
    print("已写入，CRLF %d / LF %d" % (b.count(b"\r\n"), b.count(b"\n")))
else:
    print("dry-run：%d 处替换全部命中一次" % len(edits))
