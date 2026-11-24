# -*- coding: utf-8 -*-
"""R841 界面 + 回归：锤子（直击眩晕）与润滑油（选手卡减费）。

操作对象 = 隔离工作树 E:/tmp/wt841（主仓有并行线未提交的 test_engine.gd，不碰它）。
battle_scene.gd 是 CRLF，其余 LF —— 写入统一走「编码 + 行尾回读校验」。
"""
import io

ROOT = "E:/tmp/wt841/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    raw = s.encode("utf-8")
    raw.decode("utf-8")            # 坏字节当场炸（R841 主仓踩过 0x89 吞字）
    with open(ROOT + p, "wb") as f:
        f.write(raw)
    back = open(ROOT + p, "rb").read()
    assert back == raw, "%s 回读不一致" % p


def rep(p, old, new, tag, count=1):
    s = read(p)
    crlf = "\r\n" in s
    norm = s.replace("\r\n", "\n")
    cnt = norm.count(old)
    assert cnt == count, "%s：锚点命中 %d 次（要求 %d）" % (tag, cnt, count)
    out = norm.replace(old, new)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(p, out)
    print("ok  %s" % tag)


B = "scripts/battle_scene.gd"

# ---------- ① 拖放提示：锤子与石头同一句 ----------
rep(B, '''		if t0 != null and t0.direct_damage > 0:
			_say("场上没有可以砸的敌人")''',
    '''		if t0 != null and (t0.direct_damage > 0 or t0.direct_stun > 0):
			_say("场上没有可以砸的敌人")''',
    "ui: 无目标提示")

rep(B, '''	elif t0 != null and t0.direct_damage > 0:
		status_text = "「%s」：拖到高亮的敌方单位身上砸出去" % t0.trap_name''',
    '''	elif t0 != null and (t0.direct_damage > 0 or t0.direct_stun > 0):
		status_text = "「%s」：拖到高亮的敌方单位身上砸出去" % t0.trap_name''',
    "ui: 拖放提示文案")

# ---------- ② 松手结算 ----------
rep(B, '''	# R754 石头（7012）：落点是**敌方单位**，砸下去当场结算，不埋进格子。
	# 伤害与致死收尾都在 `use_tool_on_unit()`（唯一口）；这里只负责摘槽与提示。
	if td != null and td.direct_damage > 0:
		if not engine.use_tool_on_unit(id, c2):
			_say("这一下没砸到人（要有敌方单位才砸得下去）")
			return
		RunState.consume_trap(slot)
		_say("「%s」砸中目标：%d 点伤害" % [td.trap_name, td.direct_damage])
		queue_redraw()
		return''',
    '''	# R754 石头（7012）/ R841 锤子（7018）：落点是**敌方单位**，砸下去当场结算，不埋进格子。
	# 效果与致死收尾都在 `use_tool_on_unit()`（唯一口）；这里只负责摘槽与提示。
	if td != null and (td.direct_damage > 0 or td.direct_stun > 0):
		if not engine.use_tool_on_unit(id, c2):
			_say("这一下没砸到人（要有敌方单位才砸得下去）")
			return
		RunState.consume_trap(slot)
		if td.direct_stun > 0:
			_say("「%s」砸中目标：眩晕 %d 回合" % [td.trap_name, td.direct_stun])
		else:
			_say("「%s」砸中目标：%d 点伤害" % [td.trap_name, td.direct_damage])
		queue_redraw()
		return''',
    "ui: 松手结算")

# ---------- ③ 选卡页：hand_down 文案 ----------
rep(B, '''			return {"kind": k, "short": tp_name, "opts": tp_opts,
					"title": "%s：从这 3 张里选一张加入手卡" % tp_name,
					"note": "点卡选中，再点确认 —— 本回合它的费用为 0",
					"cards": tp_cards, "max_sel": 1, "confirm_label": "确认",
					"cancel_label": "不使用"}''',
    '''			# R841 润滑油 7019：候选是**手牌本身**（不是抽牌库），改的是这张卡的当场所价。
			if engine.tool_pick_kind == "hand_down":
				var tp_down := 3
				if tp_data != null:
					tp_down = maxi(1, tp_data.cost_down)
				return {"kind": k, "short": tp_name, "opts": tp_opts,
						"title": "%s：选择一张手牌，它的费用本场 -%d（手牌 %d 张）"
								% [tp_name, tp_down, tp_cards.size()],
						"note": "点卡选中，再点确认 —— 确认后工具才会从工具栏移除",
						"cards": tp_cards, "max_sel": 1, "confirm_label": "确认上油",
						"cancel_label": "不使用"}
			return {"kind": k, "short": tp_name, "opts": tp_opts,
					"title": "%s：从这 3 张里选一张加入手卡" % tp_name,
					"note": "点卡选中，再点确认 —— 本回合它的费用为 0",
					"cards": tp_cards, "max_sel": 1, "confirm_label": "确认",
					"cancel_label": "不使用"}''',
    "ui: 选卡页 hand_down")

# ---------- ④ test_traps：件数与池子 ----------
T = "scripts/test_traps.gd"
rep(T, '''	# R839：新增大蒜 7017（**放置型**：把一格封住 3 个我方回合）→ 17 件
	check(repo.size() == 17, "traps.json 恰好 17 件工具（7 放置 + 1 直接伤害 + 9 使用型）")''',
    '''	# R839：新增大蒜 7017（**放置型**：把一格封住 3 个我方回合）→ 17 件
	# R841：新增锤子 7018（**直击型**：砸一个敌方单位眩晕 1 回合）/ 润滑油 7019（使用型，选手卡 -3 费）→ 19 件
	check(repo.size() == 19, "traps.json 恰好 19 件工具（7 放置 + 2 直击 + 10 使用型）")''',
    "test: 件数 19")

rep(T, '''	check(repo.random_traps().size() == 15 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（15 件可随机），全量仍是 17 件")''',
    '''	check(repo.random_traps().size() == 17 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（17 件可随机），全量仍是 19 件")''',
    "test: 随机池 17")

rep(T, '''	check(shop_pool.size() == 12 and not shop_ids.has(7007)''',
    '''	check(shop_pool.size() == 14 and not shop_ids.has(7007)''',
    "test: 商店池 14")

rep(T, '''			"`shop_traps()` = 12 件有售价的（烤肉与三件非卖品都被排除；R796/R797/R801/R839 新工具都有售价）")''',
    '''			"`shop_traps()` = 14 件有售价的（烤肉与三件非卖品都被排除；R796/R797/R801/R839/R841 新工具都有售价）")''',
    "test: 商店池文案")

rep(T, '''		for tid in ["7001", "7002", "7003", "7004", "7015", "7016", "7017"]:''',
    '''		for tid in ["7001", "7002", "7003", "7004", "7015", "7016", "7017", "7018", "7019"]:''',
    "test: 多语言条数遍历")

# ---------- ⑤ test_traps：R841 新断言块 ----------
rep(T, '''	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----''',
    '''	# ---- ⑥g R841：锤子 7018（直击眩晕）/ 润滑油 7019（选手卡减费）----
	var ham: TrapData = repo.get_trap(7018)
	check(ham != null and ham.trap_name == "锤子" and ham.direct_stun == 1
			and ham.price == 40 and not ham.is_usable() and not ham.no_drop,
			"锤子 7018：直击眩晕 1 回合 / 40 金 / 不是使用型（要选目标，走拖放）")
	check(shop_ids.has(7018) and drop_ids.has(7018),
			"锤子 7018：既进商店货架、也进随机掉落池")
	var e19 := _engine()
	var foe19: Placement = _unit(1011, 40, GameEngine.SIDE_OPPONENT)
	e19.state.board[Vector2i(3, 1)] = foe19
	var hp19 := foe19.health
	check(e19.trap_drop_cells(7018).has(Vector2i(3, 1)),
			"锤子：落点 = 敌方单位格（与石头 7012 同一个口）")
	check(not e19.trap_drop_cells(7018).has(Vector2i(0, 0)),
			"锤子：空格不是落点（照抄放置型的话会高亮一片空格）")
	check(e19.use_tool_on_unit(7018, Vector2i(3, 1)), "锤子：砸中目标返回 true")
	check(foe19.health == hp19, "锤子：只眩晕、不掉血（仍是 %d）" % foe19.health)
	check(foe19.stun_left == 1 and foe19.cannot_act_next_turn(),
			"锤子：目标眩晕（stun_left=1 → 下回合不能行动）")
	check(not e19.use_tool_on_unit(7018, Vector2i(0, 0)),
			"锤子：砸空格无效（不该消耗一个消耗品）")
	check(e19.state.unit_at(Vector2i(3, 1)) == foe19,
			"锤子：把敌方单位眩晕后它仍在场上（不像石头那样扣血致死）")

	var oil: TrapData = repo.get_trap(7019)
	check(oil != null and oil.trap_name == "润滑油" and oil.pick_kind == "hand_down"
			and oil.cost_down == 3 and oil.price == 30 and oil.is_usable(),
			"润滑油 7019：pick_kind=hand_down / 本场 -3 费 / 30 金 / 使用型")
	check(shop_ids.has(7019) and drop_ids.has(7019),
			"润滑油 7019：既进商店货架、也进随机掉落池")
	var e20 := _engine()
	var oil_card := CardData.new()
	oil_card.id = 9006
	oil_card.card_name = "上油测试卡"
	oil_card.cost = 5
	e20.state.hand = [oil_card]
	var cost20 := e20.cost_of(oil_card)
	check(cost20 == 5, "润滑油：起手 5 费（%d）" % cost20)
	check(e20.begin_tool_pick(7019), "润滑油：begin_tool_pick 进入选卡")
	check(e20.tool_pick_cards().size() == 1 and e20.tool_pick_cards()[0] == oil_card,
			"润滑油：候选就是手牌里的那一张（不是抽牌库）")
	check(e20.tool_pick_confirm(0), "润滑油：确认返回 true")
	check(e20.cost_of(oil_card) == 2, "润滑油：费用 -3（5 → 2，实际 %d）" % e20.cost_of(oil_card))
	check(int(e20.state.hand_cost_delta.get(oil_card, 0)) == 3,
			"润滑油：落地走 hand_cost_delta（手卡内减费唯一口径）")
	e20.state.hand = []
	check(e20.cost_of(oil_card) == 5, "润滑油：卡离手后恢复原价（5）")
	e20.state.hand = [oil_card]
	check(e20.cost_of(oil_card) == 2, "润滑油：卡回到手里减费继续生效（2）")

	# 手牌满时的闸门：润滑油不改手牌张数 → 照样能用；万能牌要往手里加卡 → 不让用
	var e21 := _engine()
	var full_hand: Array = []
	for fi in FieldState.HAND_LIMIT:
		var fc := CardData.new()
		fc.id = 9006
		fc.card_name = "填手卡%d" % fi
		fc.cost = 4
		full_hand.append(fc)
	e21.state.hand = full_hand
	check(e21.state.hand_full(), "润滑油：测例前提 —— 手牌确实是满的")
	check(e21.begin_tool_pick(7019), "润滑油：手牌满也能用（不改张数）")
	e21.tool_pick_cancel()
	check(not e21.begin_tool_pick(7009), "万能牌：手牌满时不让用（要往手里加卡）")

	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----''',
    "test: R841 断言块")

print("ui + test_traps 全部应用")
