# -*- coding: utf-8 -*-
"""R799：game_engine.gd 接入 9272 连斩 / 9273 炮火就位（CRLF，纯追加）。"""
P = "scripts/game_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
d = raw


def rep(old, new, tag):
    global d
    n = d.count(old)
    assert n == 1, "%s count=%d" % (tag, n)
    d = d.replace(old, new)


def crlf(s):
    return s.replace("\n", "\r\n")


# ── ① 常量（跟在流星雨后面）──
rep("const METEOR_SHOWER_DMG:= 8\r\n",
    "const METEOR_SHOWER_DMG:= 8\r\n" + crlf("""
# ── 连斩（9272 技能，R799，暗影刺客稀有）：X 费；对一个目标 7 伤 × X 次 ──
# X 走 `_x_spell_value`（`use_spell` / `remote_spell` 都在 `_pay` 之前抓取，
# 钻头 6077 的「X ≥ 6 翻倍」也挂在这条口上，卡数与次数天然同源）。
const LINK_SLASH_ID:= 9272
const LINK_SLASH_DMG:= 7

# ── 炮火就位（9273 技能，R799，机械之心史诗）：X 费；X 张聚能炮击进抽牌库 + 全体 3 伤 × X 次 ──
const BARRAGE_ID:= 9273
const BARRAGE_DMG:= 3
"""),
    "consts")

# ── ② 两个结算函数（插在 _meteor_shower 与 _fire_wall_spell 之间）──
FUNCS = crlf("""
func _link_slash(side: String, target, card: CardData) -> String:
	## 连斩（9272，R799，暗影刺客稀有技能）：X 费，对**同一个目标**造成 7 点伤害 × X 次。
	## ⚠️ 目标中途倒下 → 剩余段数**作废**。每段前必须重查 `p.health`：目标格一空，
	##    `_op_deal_damage` 会把伤害**溢成「对玩家造成 N 伤害」**（它最后那条 `_damage_player`
	##    分支就是干这个的）—— 照抄「按旧格继续打」的写法等于凭空给对手送伤害。
	## ⚠️ 每段都过 `_spell_dmg()`：附魔 / 魔法塔 / 荧光草 对每一刀都生效。
	var p:= _target_placement(side, target)
	if p == null:
		return "（连斩：需要指定一个目标）"
	var n:= maxi(0, _x_spell_value)
	if n <= 0:
		_log("连斩：X = 0（没有费用），一刀都没斩出")
		return "连斩：X = 0，一刀都没斩出"
	var total:= 0
	var hits:= 0
	for _i in n:
		if p.health <= 0:
			break
		var c:= _cell_of(p)
		if c == Vector2i(-1, -1):
			break
		var before:= p.health
		_op_deal_damage(side, _spell_dmg(side, LINK_SLASH_DMG, card), c)
		total += maxi(0, before - p.health)
		hits += 1
	if hits < n:
		_log("连斩：目标在第 %d 刀倒下，剩余 %d 刀作废" % [hits, n - hits])
	var msg:= "连斩 %d 刀，共造成 %d 点伤害" % [hits, total]
	_log("连斩：X = %d → %s" % [n, msg])
	return msg


func _barrage(side: String, card: CardData) -> String:
	## 炮火就位（9273，R799，机械之心史诗技能）：X 费。
	##   ① 将 X 张「聚能炮击」(9145) 加入**抽牌库**；
	##   ② 对所有敌人造成 3 点伤害 × X 次。
	## 两处用**同一个 X**（`_x_spell_value`）—— 钻头 6077 让 X 翻倍时，卡数与伤害一起翻，
	## 这正是卡面「X」的语义；只放大一半就是 R796 反复强调过的那种「最难查的 bug」。
	## 逐格走 `_hit_unit`（护盾 / 减伤 / 光环照常），与激光扫射 9172 / 激发 8077 同口径；
	## 格子先排序，回放 / 同种子必须逐帧一致。只打场上单位，不直击敌方 HP。
	var n:= maxi(0, _x_spell_value)
	if n <= 0:
		_log("炮火就位：X = 0（没有费用），一发都没打出去")
		return "炮火就位：X = 0，一发都没打出去"
	var added:= 0
	if side == SIDE_SELF:
		var repo:= CardRepo.load_json()
		var proto: CardData = repo.get_card(ENERGY_CANNON_ID) if repo != null else null
		if proto == null:
			_log("炮火就位：卡库缺少「聚能炮击」(9145)，加卡部分落空")
		else:
			for _i in n:
				var c:= CardData.from_dict(proto.to_dict())
				c.traits = (c.traits as Array).duplicate()
				state.deck.append(c)
				action.emit("deck_added", {"card": c, "side": side})
				added += 1
			_log("炮火就位：抽牌库 +%d 张「聚能炮击」（牌库 %d 张）" % [added, state.deck.size()])
	else:
		# 敌方没有真实牌库 → 只推进计数（与幽深回响 / 镜像同口径）
		state.opp_deck_count += n
	var per:= _spell_dmg(side, BARRAGE_DMG, card)
	var total:= 0
	var rounds:= 0
	for _k in n:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in state.board:
			var u: Placement = state.board[cell]
			if u != null and u.owner != side and u.health > 0:
				cells.append(cell)
		if cells.is_empty():
			break
		cells.sort()
		for c2: Vector2i in cells:
			var q: Placement = state.board.get(c2, null)
			if q == null or q.health <= 0:
				continue
			total += _hit_unit(q, per, "炮火就位")
		_destroy_dead()
		rounds += 1
	var msg:= "炮火就位：%d 轮 × %d 点伤害，共 %d 点" % [rounds, per, total]
	if added > 0:
		msg += "；抽牌库 +%d 张「聚能炮击」" % added
	_log(msg)
	return msg
""")
rep("\treturn msg\r\n\r\n\r\nfunc _fire_wall_spell(side: String, target, card: CardData) -> String:\r\n",
    "\treturn msg\r\n" + FUNCS + "\r\n\r\nfunc _fire_wall_spell(side: String, target, card: CardData) -> String:\r\n",
    "funcs")

# ── ③ match 分支 ──
rep("\t\tMETEOR_SHOWER_ID:\r\n\t\t\treturn _meteor_shower(side, card)\r\n",
    "\t\tMETEOR_SHOWER_ID:\r\n\t\t\treturn _meteor_shower(side, card)\r\n"
    "\t\tLINK_SLASH_ID:\r\n\t\t\treturn _link_slash(side, target, card)\r\n"
    "\t\tBARRAGE_ID:\r\n\t\t\treturn _barrage(side, card)\r\n",
    "match")

# ── ④ 伤害表登记 ──
rep("\t9083: 8,     # 流星雨（× 剩余费用）\r\n",
    "\t9083: 8,     # 流星雨（× 剩余费用）\r\n"
    "\t9272: 7,     # 连斩（× X 次，单体）\r\n"
    "\t9273: 3,     # 炮火就位（× X 次，全体）\r\n",
    "table")

# ── ⑤ 动态伤害名单 ──
rep("const SPELL_DYNAMIC_IDS: Array[int] = [9083, 9086, 9090, 9093, 9104, 9162]\r\n",
    "const SPELL_DYNAMIC_IDS: Array[int] = [9083, 9086, 9090, 9093, 9104, 9162, 9272, 9273]\r\n",
    "dynids")

# ── ⑥ spell_now 预览分支（插在「名单里却没有分支」兜底之前）──
PREVIEW = crlf("""		if card.id == LINK_SLASH_ID:
			# 与流星雨同口径：预览按**当前剩余费用**报总量，note 说明是「清空费用」换来的。
			var ls_times: int = maxi(0, state.energy_of(SIDE_SELF)) if side == SIDE_SELF else 0
			var ls_per: int = _spell_dmg(side, LINK_SLASH_DMG, card)
			return {"dmg": ls_per * ls_times, "base": ls_per,
					"expr": "%d × %d" % [ls_per, ls_times], "anchor": str(ls_per),
					"note": "%d × %d 刀（清空费用）" % [LINK_SLASH_DMG, ls_times]}
		if card.id == BARRAGE_ID:
			var bg_times: int = maxi(0, state.energy_of(SIDE_SELF)) if side == SIDE_SELF else 0
			var bg_per: int = _spell_dmg(side, BARRAGE_DMG, card)
			return {"dmg": bg_per * bg_times, "base": bg_per,
					"expr": "%d × %d" % [bg_per, bg_times], "anchor": str(bg_per),
					"note": "%d × %d 轮（全体，清空费用）" % [BARRAGE_DMG, bg_times]}
""")
rep("\t\t# 名单里却没有分支 → 宁可不错报（R348 ② 断言会把这个矛盾立刻拦下来）\r\n",
    PREVIEW + "\t\t# 名单里却没有分支 → 宁可不错报（R348 ② 断言会把这个矛盾立刻拦下来）\r\n",
    "preview")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
for k in ("LINK_SLASH_ID", "BARRAGE_ID", "_link_slash", "_barrage"):
    print(k, b.decode("utf-8").count(k))
