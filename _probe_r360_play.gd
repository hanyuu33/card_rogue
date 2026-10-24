extends SceneTree
## 探针（R360，临时）：辅助刃**从手牌经 use_spell 打出**这条路是否真把「死亡」挂上去。
## 背景：R360 时序探针里曾用 `play_from_hand()` —— 那个口只做「放置」（单位/工事/场地），
## 技能卡走 `use_spell`。这里确认正常出牌路径没问题，不是真 bug。

var _fails := 0

func _ck(name: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", name)
	else:
		print("  ok   ", name)


func _init() -> void:
	ProfileData.set_test_mode()
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = repo.starter_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := FieldState.new(deck, 20, 20, -1, "探针", true, rng)
	var e := GameEngine.new(state)
	e.start_game(5, 0, true)
	state.hand.clear()
	state.energy = 9
	state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	state.hand.append(CardData.from_dict(repo.get_card(9164).to_dict()))

	var tree: Placement = state.unit_at(Vector2i(4, 1))
	print("打之前：力量 %d / blade_gift=%s" % [tree.effective_power(), str(tree.blade_gift)])
	var ret: String = e.use_spell(0, Vector2i(4, 1))
	print("use_spell 返回：%s" % ret)
	tree = state.unit_at(Vector2i(4, 1))
	print("打之后：力量 %d / blade_gift=%s / hand=%d / 费用 %d" % [
			tree.effective_power(), str(tree.blade_gift), state.hand.size(),
			state.energy])
	_ck("R360 探针：手牌打出辅助刃 → 目标挂上 blade_gift", tree.blade_gift)
	_ck("R360 探针：手牌打出辅助刃 → 目标力量 3→5", tree.effective_power() == 5)

	# 再打一次（同一目标可叠），然后打死它 → 两张辅助刃回手？
	state.hand.append(CardData.from_dict(repo.get_card(9164).to_dict()))
	state.energy = 9
	e.use_spell(0, Vector2i(4, 1))
	tree = state.unit_at(Vector2i(4, 1))
	print("第二次之后：力量 %d / 层数 %d" % [tree.effective_power(), tree.upgrade_stacks])
	state.hand.clear()
	e._destroy(Vector2i(4, 1))
	print("打死之后 hand=%d（第一张：%s）" % [state.hand.size(),
			state.hand[0].card_name if state.hand.size() > 0 else "-"])
	_ck("R360 探针：打死之后回手 1 张辅助刃（不叠加）",
			state.hand.size() == 1 and state.hand[0].id == GameEngine.BLADE_GIFT_ID)

	print("=== 探针结束：%d 项失败 ===" % _fails)
	quit(1 if _fails > 0 else 0)
