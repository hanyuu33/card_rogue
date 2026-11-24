extends SceneTree
## R832 探针（不入库，跑完删）：缺陷时钟触发之后，计数到底还走不走、会不会二次触发。
## 用法：godot --headless --path . --script res://tools/_probe_r832_clock.gd

func _initialize() -> void:
	RunState.end_run()
	RunState.reset()
	RunState.relics = [6084]
	RunState.spent_relics = []
	var st := FieldState.new([], 40, 40, -1, "probe", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.self_relics = RunState.active_relics()
	eng._begin_turn(GameEngine.SIDE_SELF)
	var card: CardData = CardRepo.load_json().get_card(8006)
	print("[probe] 开场 turn=%d opp_turns=%d plays=%d left=%d badge=\"%s\"" % [
			eng.turn_number, eng.opp_turns, eng._clock_plays,
			eng.defect_clock_left(),
			RunState.relic_badge_text(6084, eng.defect_clock_left())])
	var switches := 0
	for i in 25:
		var bt: int = eng.turn_number
		var bo: int = eng.opp_turns
		var bl: int = eng._clock_plays
		eng._note_card_played(GameEngine.SIDE_SELF, CardData.from_dict(card.to_dict()))
		var no_switch_mark := eng.turn_number
		eng._clock_maybe_switch()
		var switched: bool = eng.turn_number != no_switch_mark
		if switched:
			switches += 1
		# 每张都打一行：第 10 张之后是全量，之前抽稀
		if i >= 9 or switched:
			print("[probe] play %2d: plays %2d->%2d  turn %d->%d  opp %d->%d  switched=%s  left=%d  badge=\"%s\"" % [
					i + 1, bl, eng._clock_plays, bt, eng.turn_number, bo, eng.opp_turns,
					str(switched), eng.defect_clock_left(),
					RunState.relic_badge_text(6084, eng.defect_clock_left())])
	print("[probe] 合计跳回合次数 = %d（期望 1）  最终 plays=%d  left=%d  badge=\"%s\"" % [
			switches, eng._clock_plays, eng.defect_clock_left(),
			RunState.relic_badge_text(6084, eng.defect_clock_left())])
	RunState.relics = []
	RunState.end_run()
	RunState.reset()
	quit()
