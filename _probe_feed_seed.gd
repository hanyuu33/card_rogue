extends SceneTree
## 临时探针：为 R89 无限装甲「供能」用例搜一个确定性种子。
## 目标：钉住 engine.rng.seed 后，供能必定抽到**卡面原费 > 0** 的改造技能牌，
## 这样「在手牌里被压成 0 费 / 离手恢复原价」才是一次真实断言（否则摇到 0 费卡就成了 0→0 空转）。


func _init() -> void:
	RunState.player_class = PlayerClass.MECH
	var repo := CardRepo.load_json()
	var armor: CardData = repo.get_card(GameEngine.INF_ARMOR_ID)
	var up: CardData = repo.get_card(GameEngine.UPGRADE_ID)

	# 先看引擎实际会用的池子（**不过滤 cost**，与 _inf_armor_feed 一致）
	var pool: Array[CardData] = []
	for c: CardData in repo.reward_pool_for(PlayerClass.MECH):
		if c.is_spell() and GameEngine.UPGRADE_KEYWORD in c.effect_text:
			pool.append(c)
	print("引擎供能池 size=%d" % pool.size())
	for c: CardData in pool:
		print("    %-10s id=%-5d cost=%d" % [c.card_name, c.id, c.cost])

	var empty: Array[CardData] = []
	var found: Array = []
	for s in range(1, 601):
		var st := FieldState.new(empty, 30, 30, -1, "测试", false)
		var eng := GameEngine.new(st)
		eng.ai_enabled = false
		eng.rng.seed = s
		eng.start_game()
		eng.state.place(CardData.from_dict(armor.to_dict()), Vector2i(4, 1),
				GameEngine.SIDE_SELF)
		eng.state.hand.append(CardData.from_dict(up.to_dict()))
		eng.state.energy = 5
		eng.use_spell(0, Vector2i(4, 1))
		var got: CardData = null
		for c: CardData in eng.state.hand:
			if eng.state.hand_free.has(c):
				got = c
				break
		var nm := "(未供能)" if got == null else got.card_name
		var co := -1 if got == null else got.cost
		if co > 0 and found.size() < 10:
			found.append([s, nm, co])
	print("\ncost>0 的种子（前 10 个）：")
	for f in found:
		print("    seed=%-5d  %-10s cost=%d" % [f[0], f[1], f[2]])
	quit()
