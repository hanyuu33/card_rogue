extends SceneTree
## 探针（R363，临时）：灰烬龙 1013 的**真实效果**逐项打印 —— 描述要照着这个写。
## 用户口径：「灰烬龙的描述似乎和实际效果对不上」。

func _init() -> void:
	ProfileData.set_test_mode()
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = repo.starter_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var st := FieldState.new(deck, 20, 20, -1, "探针", true, rng)
	var e := GameEngine.new(st)
	e.start_game(5, 0, true)
	st.board.clear()
	st.place(CardData.from_dict(repo.get_card(1013).to_dict()), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	st.place(CardData.from_dict(repo.get_card(1014).to_dict()), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	# 我方 3 个单位（含一个工事）+ 敌方自己的 1 个盟友：看谁挨打、谁不挨打
	var a: Placement = st.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(3, 0), GameEngine.SIDE_SELF)
	var b: Placement = st.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(3, 2), GameEngine.SIDE_SELF)
	var f: Placement = st.place(CardData.from_dict(repo.get_card(8001).to_dict()), Vector2i(4, 1), GameEngine.SIDE_SELF)
	var ally: Placement = st.place(CardData.from_dict(repo.get_card(1014).to_dict()), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var hp0 := st.hp_self
	var d := st.unit_at(Vector2i(0, 1))
	print("灰烬龙：力量 %d / 生命 %d / 程 %d / 速 %d / actions %d / acts_left %d" % [
			d.effective_power(), d.health, d.effective_range(), d.effective_speed(),
			d.card.actions, d.acts_left])
	print("挨打前：a=%d b=%d 栅栏=%d 敌方盟友=%d 我方HP=%d" % [
			a.health, b.health, f.health, ally.health, st.hp_self])

	e._begin_turn(GameEngine.SIDE_OPPONENT)
	print("战吼后：a=%d b=%d 栅栏=%d 敌方盟友=%d 我方HP=%d" % [
			st.unit_at(Vector2i(3, 0)).health if st.unit_at(Vector2i(3, 0)) != null else -1,
			st.unit_at(Vector2i(3, 2)).health if st.unit_at(Vector2i(3, 2)) != null else -1,
			st.unit_at(Vector2i(4, 1)).health if st.unit_at(Vector2i(4, 1)) != null else -1,
			st.unit_at(Vector2i(2, 1)).health if st.unit_at(Vector2i(2, 1)) != null else -1,
			st.hp_self])
	print("  （a/b 是 8 血树人，扣 4 → 4；栅栏 0/10 → 6；敌方自己的幼龙不动；我方 HP 不动）")
	print("  acts_left 战吼后 = %d（%s）" % [d.acts_left,
			"两次行动" if d.card.actions >= 2 else "一次行动"])
	# 再跑一次：确认只触发一次
	e._begin_turn(GameEngine.SIDE_OPPONENT)
	print("第二次回合开始：a=%d（%s）" % [
			st.unit_at(Vector2i(3, 0)).health if st.unit_at(Vector2i(3, 0)) != null else -1,
			"只触发一次" if st.unit_at(Vector2i(3, 0)) == null or st.unit_at(Vector2i(3, 0)).health == 4 else "重复触发!"])
	# 我方回合开始：敌方战吼会补吗？
	e._begin_turn(GameEngine.SIDE_SELF)
	print("我方回合开始后 a=%d（敌方战吼不会在我方回合触发）" % [
			st.unit_at(Vector2i(3, 0)).health if st.unit_at(Vector2i(3, 0)) != null else -1])
	quit(0)
