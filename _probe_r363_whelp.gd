extends SceneTree
## 探针（R363，临时）：幼龙 1014 的亡语「召唤龙裔 9028」是否会把**另一只幼龙**也变成龙裔。
## 用户口径：「一个幼龙死亡后，存在另一个幼龙也变成龙裔的情况」。

var _fails := 0

func _ck(name: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", name)
	else:
		print("  ok   ", name)


func _snapshot(st: FieldState) -> String:
	var out: Array[String] = []
	var keys: Array[Vector2i] = []
	for c: Vector2i in st.board.keys():
		keys.append(c)
	keys.sort()
	for c: Vector2i in keys:
		var p: Placement = st.unit_at(c)
		if p == null:
			continue
		out.append("%s=%s(%d)" % [str(c), p.card.card_name, p.card.id])
	return " | ".join(out)


func _mk(repo: CardRepo, id: int) -> CardData:
	return CardData.from_dict(repo.get_card(id).to_dict())


func _init() -> void:
	ProfileData.set_test_mode()
	var repo := CardRepo.load_json()

	# ── 场景 A：同帧延迟结算（battle_scene 的真实路径 defer = true）──
	var deck: Array[CardData] = repo.starter_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := FieldState.new(deck, 20, 20, -1, "探针", true, rng)
	var e := GameEngine.new(st)
	e.start_game(5, 0, true)
	e.defer_death_effects = true
	st.board.clear()
	st.place(_mk(repo, 1014), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	st.place(_mk(repo, 1014), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	st.place(_mk(repo, 1013), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	print("初始：", _snapshot(st))

	var a: Placement = st.unit_at(Vector2i(1, 0))
	a.health = 0
	e._destroy_dead()
	print("杀掉 (1,0) 之后（未 flush）：", _snapshot(st))
	e.flush_all_death_effects()
	print("flush 之后：", _snapshot(st))
	_ck("R363 探针：(1,0) 原地变龙裔 9028",
			st.unit_at(Vector2i(1, 0)) != null
			and st.unit_at(Vector2i(1, 0)).card.id == 9028)
	_ck("R363 探针：另一只幼龙 (1,2) 仍是幼龙 1014",
			st.unit_at(Vector2i(1, 2)) != null
			and st.unit_at(Vector2i(1, 2)).card.id == 1014)

	# ── 场景 B：两只幼龙同帧死亡 ──
	var deck2: Array[CardData] = repo.starter_deck()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4242
	var st2 := FieldState.new(deck2, 20, 20, -1, "探针", true, rng2)
	var e2 := GameEngine.new(st2)
	e2.start_game(5, 0, true)
	e2.defer_death_effects = true
	st2.board.clear()
	st2.place(_mk(repo, 1014), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	st2.place(_mk(repo, 1014), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
	var b1: Placement = st2.unit_at(Vector2i(1, 0))
	var b2: Placement = st2.unit_at(Vector2i(1, 2))
	b1.health = 0
	b2.health = 0
	e2._destroy_dead()
	print("两只同帧死后 flush：")
	e2.flush_all_death_effects()
	print("  ", _snapshot(st2))
	_ck("R363 探针：两只幼龙同帧死 → 两个格子都是龙裔",
			st2.unit_at(Vector2i(1, 0)) != null and st2.unit_at(Vector2i(1, 0)).card.id == 9028
			and st2.unit_at(Vector2i(1, 2)) != null and st2.unit_at(Vector2i(1, 2)).card.id == 9028)

	# ── 场景 C：卡库实例共享？看两处龙裔的 card 是不是同一个对象 ──
	if st2.unit_at(Vector2i(1, 0)) != null and st2.unit_at(Vector2i(1, 2)) != null:
		var t1: Placement = st2.unit_at(Vector2i(1, 0))
		var t2: Placement = st2.unit_at(Vector2i(1, 2))
		print("两张龙裔 card 是同一实例？ %s" % str(t1.card == t2.card))
		print("  库实例？ %s / %s" % [str(t1.card == repo.get_card(9028)),
				str(t2.card == repo.get_card(9028))])
		_ck("R363 探针：两处龙裔各自独立副本（不能共享卡库实例）",
				t1.card != t2.card and t1.card != repo.get_card(9028))

	print("=== 探针结束：%d 项失败 ===" % _fails)
	quit(1 if _fails > 0 else 0)
