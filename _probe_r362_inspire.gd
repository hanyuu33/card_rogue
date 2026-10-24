extends SceneTree
## 探针（R362，临时）：打出「激发」8077 时**是否**会顺手打出伤害？
## 用户口径：「激发打出时不应该造成伤害」。这里把三条路分开看：
##   ① 效果区空 → 打出第一张激发
##   ② 效果区已有一张 → 打出第二张（叠到两张）
##   ③ 手牌里另一张效果卡被打出（不该触发激发，因为不是改造动作）

var _fails := 0

func _ck(name: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", name)
	else:
		print("  ok   ", name)


func _mk_engine() -> Dictionary:
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = repo.starter_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := FieldState.new(deck, 20, 20, -1, "探针", true, rng)
	var e := GameEngine.new(state)
	e.start_game(5, 0, true)
	state.hand.clear()
	state.energy = 20
	return {"e": e, "state": state, "repo": repo}


func _init() -> void:
	ProfileData.set_test_mode()

	# ① 效果区空，打出第一张激发
	var a := _mk_engine()
	var e: GameEngine = a["e"]
	var state: FieldState = a["state"]
	var repo: CardRepo = a["repo"]
	var foe: Placement = state.place(CardData.from_dict(repo.get_card(1011).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var foe_hp: int = foe.health
	state.hand.append(CardData.from_dict(repo.get_card(GameEngine.INSPIRE_ID).to_dict()))
	print("[①] 打出前：敌人 %d 血 / 效果区 %d 张" % [foe.health, state.effects.size()])
	var r1: String = e.use_effect(0)
	print("[①] use_effect 返回：%s" % r1)
	print("[①] 打出后：敌人 %d 血 / 效果区 %d 张" % [foe.health, state.effects.size()])
	_ck("R362 探针①：打出第一张激发 → 不造成伤害", foe.health == foe_hp)
	_ck("R362 探针①：激发进了效果区", state.effects.size() == 1)

	# ② 效果区已有一张，再打出第二张
	var b := _mk_engine()
	var e2: GameEngine = b["e"]
	var st2: FieldState = b["state"]
	var rp2: CardRepo = b["repo"]
	var foe2: Placement = st2.place(CardData.from_dict(rp2.get_card(1011).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	st2.effects.append(CardData.from_dict(rp2.get_card(GameEngine.INSPIRE_ID).to_dict()))
	var hp2: int = foe2.health
	st2.hand.append(CardData.from_dict(rp2.get_card(GameEngine.INSPIRE_ID).to_dict()))
	e2.use_effect(0)
	print("[②] 叠第二张后：敌人 %d 血 / 效果区 %d 张" % [foe2.health, st2.effects.size()])
	_ck("R362 探针②：打出第二张激发 → 不造成伤害", foe2.health == hp2)

	# ③ 打出另一张效果卡（加厚装甲 8029 非改造）→ 不该触发激发
	var c := _mk_engine()
	var e3: GameEngine = c["e"]
	var st3: FieldState = c["state"]
	var rp3: CardRepo = c["repo"]
	var foe3: Placement = st3.place(CardData.from_dict(rp3.get_card(1011).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var hp3: int = foe3.health
	st3.effects.append(CardData.from_dict(rp3.get_card(GameEngine.INSPIRE_ID).to_dict()))
	st3.hand.append(CardData.from_dict(rp3.get_card(8029).to_dict()))   # 加厚装甲
	e3.use_effect(0)
	print("[③] 打出加厚装甲后：敌人 %d 血" % foe3.health)
	_ck("R362 探针③：打出非改造效果卡 → 不触发激发", foe3.health == hp3)

	# ④ 真正的改造动作仍然要触发（回归对照）：升级场上单位
	var d := _mk_engine()
	var e4: GameEngine = d["e"]
	var st4: FieldState = d["state"]
	var rp4: CardRepo = d["repo"]
	var foe4: Placement = st4.place(CardData.from_dict(rp4.get_card(1011).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var hp4: int = foe4.health
	st4.effects.append(CardData.from_dict(rp4.get_card(GameEngine.INSPIRE_ID).to_dict()))
	st4.place(CardData.from_dict(rp4.get_card(8003).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	e4._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
	print("[④] 升级后：敌人 %d 血（原 %d）" % [foe4.health, hp4])
	_ck("R362 探针④：改造动作 → 激发照常打 3 点", foe4.health == hp4 - GameEngine.INSPIRE_DMG)

	print("=== 探针结束：%d 项失败 ===" % _fails)
	quit(1 if _fails > 0 else 0)
