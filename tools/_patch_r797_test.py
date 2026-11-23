# -*- coding: utf-8 -*-
"""R797 行为测试：河豚回弹（test_traps）+ 龟壳减伤（test_engine）。"""
ROOT = "E:/tmp/wt794/"
fails = []


def patch(path, pairs, nl="\n"):
    raw = open(ROOT + path, "rb").read().decode("utf-8")
    for old, new in pairs:
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = raw.count(o)
        if c != 1:
            fails.append("%s: %d → %r" % (path, c, old[:50]))
            continue
        raw = raw.replace(o, n)
    open(ROOT + path, "wb").write(raw.encode("utf-8"))
    print("patched %-26s CRLF %d / LF %d" % (path, raw.count("\r\n"), raw.count("\n")))


# ---------- test_traps：河豚 7015 回弹 ----------
TRAPS_BLOCK = '''	# ---- ⑥d R797：河豚 7015 —— 踩到回弹一格 + 3 伤 ----
	# 回弹方向 = 来路（`_trap_path_check` 把 path[i-1] 传进 `_trigger_trap`）。
	var e8 := _engine()
	e8.state.trap_fields[c31] = 7015
	var foe8: Placement = _unit(9008, 60, GameEngine.SIDE_OPPONENT)
	e8.state.board[c31] = foe8
	e8._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_OPPONENT)
	check(foe8.health == 57, "河豚：踩到受 3 点伤害")
	check(e8.state.unit_at(Vector2i(2, 1)) == foe8 and not e8.state.board.has(c31),
			"河豚：被弹回来时的格子（3,1 → 2,1）")
	check(not e8.state.trap_fields.has(c31), "河豚：触发后从场上摘掉（一次性的）")

	# 来路不可用（这里直接给 `_bounce_unit` 一个哨兵值 = 效果直达 / 没有路径）→ 朝我方弹一格
	var e9 := _engine()
	var foe9: Placement = _unit(9009, 60, GameEngine.SIDE_OPPONENT)
	e9.state.board[c31] = foe9
	e9._bounce_unit(foe9, Vector2i(-1, -1), TrapRepo.load_json().get_trap(7015))
	check(e9.state.unit_at(Vector2i(4, 1)) == foe9 and not e9.state.board.has(c31),
			"河豚：没有来路 → 朝我方（行号 +1）弹一格")

	# 落点已经在棋盘外 / 被占 → 原地不动，但仍然吃伤害
	var e10 := _engine()
	var far := Vector2i(5, 2)
	e10.state.trap_fields[far] = 7015
	var foe10: Placement = _unit(9010, 60, GameEngine.SIDE_OPPONENT)
	e10.state.board[far] = foe10
	# 来路给一个越界格：既不能回去、朝我方那一格（6,2）也越界 → 留在原地
	e10._trigger_trap(far, foe10, Vector2i(6, 2))
	check(foe10.health == 57 and e10.state.unit_at(far) == foe10,
			"河豚：无处可弹 → 留在原地（伤害照算）")

	# 我方踩自己的河豚：不触发（与其它陷阱同口径）
	var e11 := _engine()
	e11.state.trap_fields[c31] = 7015
	var mine11: Placement = _unit(9011, 60, GameEngine.SIDE_SELF)
	e11.state.board[c31] = mine11
	e11._trap_path_check([Vector2i(2, 1), c31], GameEngine.SIDE_SELF)
	check(mine11.health == 60 and e11.state.trap_fields.has(c31),
			"河豚：我方踩到不触发、不消耗")

'''

patch("scripts/test_traps.gd", [
    ("""	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----""",
     TRAPS_BLOCK + """	# ---- ⑥b R690：使用型工具的结算（小血瓶回 20% 上限、法力药剂回 2 费）----"""),
])

# ---------- test_engine：龟壳 6078 ----------
ENGINE_BLOCK = '''func _test_r797() -> void:
	## R797（用户口径）：龟壳 6078 —— **上回合没有攻击过的己方单位**受到的伤害 -2（至少 1）。
	## 判据 `Placement.attacked_prev_turn`：attack / attack_hp 置位、reset_units 复位。
	var r797_cards := CardRepo.load_json()
	var r797_repo := RelicRepo.load_json()
	var r797_sv: Array[int] = RunState.relics.duplicate()

	# ① 数据层
	check(r797_repo.get_relic(6078) != null, "R797 数据层：龟壳 6078 在库")
	check(r797_repo.reward_ids().has(6078) and r797_repo.normal_reward_ids().has(6078),
			"R797 龟壳进奖励池（一般档）")

	# ② 上回合没攻击过 → 10 点伤害只吃 8
	RunState.relics = [6078]
	var r797_e1 := _new_engine([], 40, 40)
	var r797_a1 := r797_e1.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	check(r797_a1 != null, "R797 龟壳：己方单位就位")
	var r797_hp0: int = r797_a1.health
	r797_e1._hit_unit(r797_a1, 10, "测试")
	check(r797_a1.health == r797_hp0 - 8,
			"R797 龟壳：上回合没攻击过 → 10 点只受 8（%d → %d）" % [r797_hp0, r797_a1.health])
	check(not r797_a1.attacked_prev_turn, "R797 龟壳：挨打不算「攻击过」")

	# ③ 普攻落地 → 置位，之后再挨打就不减了
	var r797_e2 := _new_engine([], 40, 40)
	var r797_a2 := r797_e2.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r797_f2 := r797_e2.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	check(r797_a2 != null and r797_f2 != null, "R797 龟壳：攻守双方就位")
	r797_e2.attack(Vector2i(4, 1), Vector2i(4, 2), GameEngine.SIDE_SELF)
	check(r797_a2.attacked_prev_turn, "R797 龟壳：普攻落地 → 记下「这回合打过」")
	var r797_hp2: int = r797_a2.health
	r797_e2._hit_unit(r797_a2, 10, "测试")
	check(r797_a2.health == r797_hp2 - 10,
			"R797 龟壳：打过就吃满伤害（%d → %d）" % [r797_hp2, r797_a2.health])

	# ④ 新回合开始复位
	r797_e2.state.reset_units(GameEngine.SIDE_SELF)
	check(not r797_a2.attacked_prev_turn, "R797 龟壳：自己的回合开始 → 标记复位")

	# ⑤ 至少仍受 1 点 / 敌人不减 / 没道具不减
	var r797_e3 := _new_engine([], 40, 40)
	var r797_a3 := r797_e3.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r797_f3 := r797_e3.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	var r797_hp3: int = r797_a3.health
	r797_e3._hit_unit(r797_a3, 1, "测试")
	check(r797_a3.health == r797_hp3 - 1, "R797 龟壳：1 点伤害仍受 1 点（不会减成 0）")
	var r797_hp4: int = r797_f3.health
	r797_e3._hit_unit(r797_f3, 10, "测试")
	check(r797_f3.health == r797_hp4 - 10, "R797 龟壳：只保护己方，敌人照吃满伤害")
	RunState.relics = []
	var r797_e4 := _new_engine([], 40, 40)
	var r797_a4 := r797_e4.state.place(
			CardData.from_dict(r797_cards.get_card(1011).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r797_hp5: int = r797_a4.health
	r797_e4._hit_unit(r797_a4, 10, "测试")
	check(r797_a4.health == r797_hp5 - 10, "R797 龟壳：没持道具 → 不减伤")

	# ⑥ 源码锁：减伤必须挂在 `_unit_damage_taken()`（两个扣血落地口共用）
	var r797_ge := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r797_ge.contains("and not p.attacked_prev_turn")
			and r797_ge.contains("SHELL_RELIC_ID"),
			"R797 龟壳：减伤在减伤唯一口里，两条扣血落地口都吃得到")

	RunState.relics = r797_sv
	print("  · R797：龟壳 6078（受伤 -2，上回合未攻击）")


'''
patch("scripts/test_engine.gd", [
    ("func _test_r793() -> void:", ENGINE_BLOCK + "func _test_r793() -> void:"),
    ("\t_test_r793()\n\t_test_r796()", "\t_test_r793()\n\t_test_r796()\n\t_test_r797()"),
], nl="\r\n")

if fails:
    print("失败：")
    for f in fails:
        print("  " + f)
else:
    print("OK 全部命中")
