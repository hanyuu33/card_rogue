# -*- coding: utf-8 -*-
"""R753：test_traps.gd 增补石头 / 祭拜祝福 / 摧毁填石头（LF 文件）。"""
p = 'scripts/test_traps.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') == 0


def rep(old, new):
    global txt
    c = txt.count(old)
    assert c == 1, (c, old[:70])
    txt = txt.replace(old, new, 1)


# ① 件数 11 → 12
rep('''	# R752：新增万能牌 7009 / 快送鸭 7010 / 神秘牌 7011（都是使用型、都没有售价）→ 11 件
	check(repo.size() == 11, "traps.json 恰好 11 件工具（4 放置型 + 7 使用型）")
''', '''	# R752：新增万能牌 7009 / 快送鸭 7010 / 神秘牌 7011（都是使用型、都没有售价）→ 11 件
	# R753：新增石头 7012（**直接伤害型**：拖到敌方单位身上砸 15；no_drop）→ 12 件
	check(repo.size() == 12, "traps.json 恰好 12 件工具（4 放置 + 1 直接伤害 + 7 使用型）")
''')

rep('''	check(repo.random_traps().size() == 10 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（10 件可随机），全量仍是 11 件")
''', '''	check(repo.random_traps().size() == 10 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（10 件可随机），全量仍是 12 件")
''')

# ② 石头数据断言（放在商店池断言之后，那里已有 shop_ids）
rep('''	check(shop_ids.has(7008), "野性图腾售价 30 → 仍在商店货架上")
''', '''	check(shop_ids.has(7008), "野性图腾售价 30 → 仍在商店货架上")
	# R753 石头 7012：事件「奇异雕像」的摧毁选项给的，**直接伤害型**
	var stone: TrapData = repo.get_trap(7012)
	check(stone != null and stone.trap_name == "石头" and stone.direct_damage == 15
			and stone.price == 0 and stone.no_drop and not stone.is_usable(),
			"石头 7012：15 点直接伤害 / 非卖品 / no_drop / 不算使用型（要落点）")
	check(not shop_ids.has(7012), "石头不进商店货架（没有售价）")
	var drop_ids: Array[int] = []
	for dt: TrapData in repo.random_traps():
		drop_ids.append(int(dt.id))
	check(not drop_ids.has(7012), "石头不进随机掉落 / 工具箱池（no_drop）")
''')

# ③ 新增 ⑪ 段
rep('''	RunState.traps = [-1, -1, -1]
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
''', '''	# ---- ⑪ R753：石头（直接伤害型）+ 祭拜祝福（三场必掉）+ 摧毁（石头填栏）----
	# ① 落点：石头要**敌方单位格**，普通陷阱要**空格** —— 两条判据在同一个口里分。
	var s_eng := _engine()
	var s_foe := _unit(9001, 40, GameEngine.SIDE_OPPONENT)
	var s_self := _unit(9002, 40, GameEngine.SIDE_SELF)
	s_eng.state.board[Vector2i(4, 0)] = s_foe
	s_eng.state.board[Vector2i(3, 0)] = s_self
	var st_targets: Array[Vector2i] = s_eng.trap_drop_cells(7012)
	check(st_targets.size() == 1 and st_targets.has(Vector2i(4, 0)),
			"石头：可砸目标只有敌方单位那一格（自己人不算）")
	var bomb_cells: Array[Vector2i] = s_eng.trap_drop_cells(7001)
	check(bomb_cells.size() > 0 and not bomb_cells.has(Vector2i(4, 0))
			and not bomb_cells.has(Vector2i(3, 0)),
			"普通陷阱：落点仍是空格（两个有单位的格子都不在候选里）")
	# ② 砸下去：15 点伤害；砸自己人 / 砸空格 / 用错工具一律拒绝。
	RunState.traps = [7012, -1, -1]
	check(s_eng.use_tool_on_unit(7012, Vector2i(4, 0)), "石头：砸敌方单位结算成功")
	check(s_foe.health == 25, "石头：目标扣 15 点（40 → 25）")
	check(not s_eng.use_tool_on_unit(7012, Vector2i(3, 0)), "石头：砸自己人一律拒绝")
	check(not s_eng.use_tool_on_unit(7012, Vector2i(9, 0)), "石头：砸空格一律拒绝")
	check(not s_eng.use_tool_on_unit(7001, Vector2i(4, 0)),
			"石头口只认直接伤害型（炸弹仍是 place_trap 那条路）")
	# 致死要自己收尾（R733 铁律：`_hit_unit` 只扣血不删卡，新路径必须自己 `_destroy_dead`）
	var s_weak := _unit(9003, 10, GameEngine.SIDE_OPPONENT)
	s_eng.state.board[Vector2i(5, 0)] = s_weak
	check(s_eng.use_tool_on_unit(7012, Vector2i(5, 0))
			and s_eng.state.unit_at(Vector2i(5, 0)) == null,
			"石头打死人：单位当场从盘面清掉（不留负血占格）")
	# ③ 祭拜祝福：接下来三场**必掉**（不看 10% 概率），三场之后自动用尽。
	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	RunState.tool_roll_seq = 0
	RunState.bless_tool_drops(3)
	check(RunState.tool_drop_pledge == 3, "祭拜：挂上「接下来 3 场必定掉工具」")
	var p1 := RunState.roll_battle_tool_drop()
	var p2 := RunState.roll_battle_tool_drop()
	var p3 := RunState.roll_battle_tool_drop()
	check(p1 > 0 and p2 > 0 and p3 > 0, "祭拜：前三场每场都掉（不看 10% 概率）")
	check(RunState.tool_drop_pledge == 0, "祭拜：三场之后祝福用尽（不会一直掉）")
	# 叠拜取 max：读者看到的永远是「接下来三场」，不会变成六场
	RunState.bless_tool_drops(2)
	RunState.bless_tool_drops(3)
	check(RunState.tool_drop_pledge == 3, "祭拜：重复祭拜取 max(2,3)=3，不累加成 5 场")
	RunState.tool_drop_pledge = 0
	# ④ 摧毁：石头只填空槽，不覆盖手里已有的工具。
	RunState.traps = [7005, -1, -1]
	var stones := RunState.fill_toolbar_with_stones()
	check(stones == 2 and RunState.trap_at(0) == 7005
			and RunState.trap_at(1) == 7012 and RunState.trap_at(2) == 7012,
			"摧毁：空槽填满石头（7012），已有的小血瓶原样不动")
	check(RunState.fill_toolbar_with_stones() == 0, "摧毁：满栏时一块也塞不进去")

	RunState.traps = [-1, -1, -1]
	RunState.tool_drop_pledge = 0
	print("TRAPS === 结束：%d 通过 / %d 失败 ===" % [_ok, _bad])
''')

open(p, 'wb').write(txt.encode('utf-8'))
print('lf', txt.count('\n'), 'crlf', txt.count('\r\n'))
