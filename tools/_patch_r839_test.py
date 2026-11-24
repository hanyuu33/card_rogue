## R839：大蒜 7017 —— 回归（test_traps 计数与功能用例 / test_engine 随机池条数）
## 用法：python tools/_patch_r839_test.py
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(path, old, new, tag, count=1):
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    o, n = old.replace("\r\n", "\n"), new.replace("\r\n", "\n")
    cnt = norm.count(o)
    if cnt == 0 and n in norm:
        print("skip %-42s（已应用）" % tag)
        return
    assert cnt == count, "%s 锚点命中 %d 次（要求 %d）" % (tag, cnt, count)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-44s (%s)" % (tag, "CRLF" if crlf else "LF"))


# ===================== test_traps.gd =====================
TT = "scripts/test_traps.gd"

rep(TT, '''	# R801：新增爆炸蘑菇 7016（**放置型**：踩到炸一圈 15 伤，不分敌我）→ 16 件
	check(repo.size() == 16, "traps.json 恰好 16 件工具（6 放置 + 1 直接伤害 + 9 使用型）")''',
    '''	# R801：新增爆炸蘑菇 7016（**放置型**：踩到炸一圈 15 伤，不分敌我）→ 16 件
	# R839：新增大蒜 7017（**放置型**：把一格封住 3 个我方回合）→ 17 件
	check(repo.size() == 17, "traps.json 恰好 17 件工具（7 放置 + 1 直接伤害 + 9 使用型）")''',
    "test_traps: 条数 17")

rep(TT, '''	check(repo.random_traps().size() == 14 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（14 件可随机），全量仍是 16 件")''',
    '''	check(repo.random_traps().size() == 15 and repo.get_trap(7007) != null,
			"烤肉：`random_traps()` 把它排除（15 件可随机），全量仍是 17 件")''',
    "test_traps: 随机池 15")

rep(TT, '''	check(shop_pool.size() == 11 and not shop_ids.has(7007)''',
    '''	check(shop_pool.size() == 12 and not shop_ids.has(7007)''',
    "test_traps: 商店池 12")

rep(TT, '''			"`shop_traps()` = 11 件有售价的（烤肉与三件非卖品都被排除；R796/R797/R801 新工具都有售价）")''',
    '''			"`shop_traps()` = 12 件有售价的（烤肉与三件非卖品都被排除；R796/R797/R801/R839 新工具都有售价）")''',
    "test_traps: 商店池文案")

rep(TT, '''		for tid in ["7001", "7002", "7003", "7004", "7015", "7016"]:''',
    '''		for tid in ["7001", "7002", "7003", "7004", "7015", "7016", "7017"]:''',
    "test_traps: desc 拖放说明")

# ⑥f：大蒜的功能用例（接在爆炸蘑菇之后、使用型工具之前）
rep(TT, '''	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----''',
    '''	# ---- ⑥f R839：大蒜 7017 —— 指定空格 3 个我方回合不可使用 ----
	var gal: TrapData = repo.get_trap(7017)
	check(gal != null and gal.trap_name == "大蒜" and gal.block_turns == 3
			and gal.price == 20 and not gal.is_usable() and not gal.no_drop,
			"大蒜 7017：封锁 3 个我方回合 / 放置型 / 20 金")
	check(shop_ids.has(7017) and drop_ids.has(7017),
			"大蒜 7017：既进商店货架、也进随机掉落池")
	var e16 := _engine()
	var seal_cell := Vector2i(2, 1)
	check(e16.place_trap(7017, seal_cell), "大蒜：place_trap 放置成功")
	check(not e16.state.trap_fields.has(seal_cell),
			"大蒜**不写** trap_fields（它是「进不去」而不是「踩到触发」）")
	check(e16.state.is_cell_sealed(seal_cell), "大蒜：该格进入「不可使用」表")
	check(not e16.trap_legal_cells().has(seal_cell), "封锁格不能再放工具 / 陷阱")
	# 移动：不能停在封锁格，也**不能穿过**它（移速 2 的单位从 (1,1) 走不到 (3,1)）
	var foe16: Placement = _unit(9030, 60, GameEngine.SIDE_OPPONENT)
	foe16.card.move_speed = 2
	e16.state.board[Vector2i(1, 1)] = foe16
	check(not e16._reachable(Vector2i(1, 1), GameEngine.SIDE_OPPONENT).has(seal_cell),
			"大蒜：移动可达格不含封锁格")
	check(e16.move_path(Vector2i(1, 1), Vector2i(3, 1),
			GameEngine.SIDE_OPPONENT).is_empty(),
			"大蒜：穿过封锁格的路径不存在（移速 2 也绕不过去）")
	# 跳跃 / 闪现同样进不去
	check(not e16.leap_cells(Vector2i(3, 1), GameEngine.SIDE_SELF).has(seal_cell),
			"大蒜：跳跃落点排除封锁格")
	# 河豚也不能把人弹进封锁格（回弹落点判据同一口径）
	check(not e16._bounce_cell_ok(seal_cell, Vector2i(3, 1), foe16),
			"大蒜：河豚回弹落点排除封锁格")
	# 我方踩自己的也不是「触发」——它是**进不去**，所以表里根本没有触发器
	check(not e16.state.trap_fields.has(seal_cell)
			and e16.state.is_cell_sealed(seal_cell),
			"大蒜：我方单位回合开始时不会被自己封住（封锁只挡进入，不伤害）")
	# 倒计时：3 → 2 → 1 → 到期解开
	e16._seal_tick()
	check(int(e16.state.sealed_cells.get(seal_cell, 0)) == 2, "大蒜：第 1 个我方回合后剩 2")
	e16._seal_tick()
	check(int(e16.state.sealed_cells.get(seal_cell, 0)) == 1, "大蒜：第 2 个我方回合后剩 1")
	e16._seal_tick()
	check(not e16.state.is_cell_sealed(seal_cell)
			and e16.trap_legal_cells().has(seal_cell),
			"大蒜：第 3 个我方回合后解开，该格恢复可用")
	# 存档：封锁格进战斗检查点，读档后剩余回合不丢
	var e17 := _engine()
	e17.place_trap(7017, Vector2i(4, 2))
	e17._seal_tick()
	var ck17 := e17.state.save_dict()
	check(ck17.has("sealed_cells") and (ck17["sealed_cells"] as Array).size() == 1,
			"大蒜：战斗检查点存 sealed_cells")
	var e18 := _engine()
	e18.state.apply_dict(ck17)
	check(int(e18.state.sealed_cells.get(Vector2i(4, 2), 0)) == 2,
			"大蒜：读档后剩余回合原样恢复（3 → 2）")
	check(e18.state.is_cell_sealed(Vector2i(4, 2)), "大蒜：读档后该格仍然不可使用")

	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----''',
    "test_traps: 大蒜用例")

# 源码守卫：回合推进接线不许被抹掉
rep(TT, '''	check(eng_src.contains("action.emit(\\"trap_hit\\"")''',
    '''	check(eng_src.contains("_seal_tick()") and eng_src.contains("func _seal_tick")
			and eng_src.contains("state.tick_seals()"),
			"R839 大蒜：回合推进只走 `_seal_tick()` → `state.tick_seals()` 一条链")
	check(eng_src.contains("state.seal_cell(cell, t.block_turns)")
			and battle_src.contains("_draw_seal_markers")
			and trap_src.contains("_garlic"),
			"R839 大蒜：数据判据 / 战场绘制 / 图标兜底三处接线")
	check(eng_src.contains("action.emit(\\"trap_hit\\"")''',
    "test_traps: 源码守卫")

# ===================== test_engine.gd =====================
rep("scripts/test_engine.gd",
    '''	check(r744_trepo.random_traps().size() == 14,''',
    '''	check(r744_trepo.random_traps().size() == 15,''',
    "test_engine: 随机池 15")
