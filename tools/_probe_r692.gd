extends SceneTree
## R692 快速探针：只跑「鸭妈妈 9250 / 小鸭 9251」「飓风咆哮 9063」「幽深回响 9002」三块的判据，
## 不走 6000 条全量。用法：godot --headless --path . --script res://tools/_probe_r692.gd

var fail := 0
var npass := 0


func ck(cond: bool, msg: String) -> void:
	if cond:
		npass += 1
		print("  ✓ ", msg)
	else:
		fail += 1
		print("  ✗ ", msg)


func _new_engine(deck: Array[CardData] = [], hp_me := 20, hp_foe := 20,
		limit := -1, do_shuffle := true) -> GameEngine:
	var st := FieldState.new(deck, hp_me, hp_foe, limit, "测试", do_shuffle)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	return eng


func _init() -> void:
	var repo := CardRepo.load_json()
	print("== 数据层 ==")
	var mom: CardData = repo.get_card(9250)
	var duck: CardData = repo.get_card(9251)
	ck(mom != null and mom.kind == "盟友" and mom.cost == 4 and mom.power == 3
			and mom.health == 15 and mom.attack_range == 1 and mom.move_speed == 1
			and mom.rarity == 1 and mom.card_class == "森林精魄",
			"鸭妈妈：4 费 3/15/程1/速1 稀有 森林精魄")
	ck(mom.effect_text.contains("「小鸭」"), "鸭妈妈正文用「小鸭」引用：" + mom.effect_text)
	ck(duck != null and duck.power == 1 and duck.health == 1 and duck.rarity == 5
			and duck.has_affix("次元"), "小鸭：1/1 rarity5 带次元")

	var ref := Mention.resolve("小鸭")
	ck(not ref.is_empty() and str(ref.get("kind", "")) == "card" and int(ref.get("id", -1)) == 9251,
			"名字表「小鸭」→ 9251")
	var hits := 0
	for seg in CardText.parse(mom.effect_text):
		var m: Dictionary = seg.get("mention", {})
		if str(m.get("name", "")) == "小鸭" and int(m.get("id", -1)) == 9251:
			hits += 1
	ck(hits == 1, "鸭妈妈正文生成 1 个指向 9251 的提及片段（实际 %d）" % hits)

	print("== 召唤 ==")
	var e := _new_engine([], 20, 20, -1, false)
	e.start_game(0)
	var fx1: CardData = repo.get_card(9065)
	var fx2: CardData = repo.get_card(9058)
	e.state.hand = [CardData.from_dict(mom.to_dict()),
			CardData.from_dict(fx1.to_dict()), CardData.from_dict(fx2.to_dict())]
	e.state.energy = 9
	e.play_from_hand(0, Vector2i(3, 1))
	var l := e.state.unit_at(Vector2i(3, 0))
	var r := e.state.unit_at(Vector2i(3, 2))
	ck(l != null and l.card.id == 9251 and r != null and r.card.id == 9251,
			"两侧各一只小鸭（左 %s / 右 %s）" % [l != null, r != null])
	var cut := 0
	for hc: CardData in e.state.hand:
		cut += int(e.state.hand_cost_delta.get(hc, 0))
	ck(cut == 2, "两只小鸭各 -1 费（合计 %d）" % cut)

	print("== 越界 ==")
	var e2 := _new_engine([], 20, 20, -1, false)
	e2.start_game(0)
	e2.state.hand = [CardData.from_dict(mom.to_dict())]
	e2.state.energy = 9
	e2.play_from_hand(0, Vector2i(3, 0))
	var r2 := e2.state.unit_at(Vector2i(3, 1))
	var oob := e2.state.unit_at(Vector2i(3, -1))
	ck(r2 != null and r2.card.id == 9251 and oob == null, "最左列：只召唤右边一只，越界侧不替补")

	print("== 占位 ==")
	var e3 := _new_engine([], 20, 20, -1, false)
	e3.start_game(0)
	var bear: CardData = repo.get_card(9001)
	e3.state.place(CardData.from_dict(bear.to_dict()), Vector2i(3, 0), "self")
	e3.state.hand = [CardData.from_dict(mom.to_dict())]
	e3.state.energy = 9
	e3.play_from_hand(0, Vector2i(3, 1))
	var l3 := e3.state.unit_at(Vector2i(3, 0))
	var r3 := e3.state.unit_at(Vector2i(3, 2))
	ck(l3 != null and l3.card.id == 9001 and r3 != null and r3.card.id == 9251,
			"左侧被占：保留原单位 + 只补右边")

	print("== 无效果卡 ==")
	var e4 := _new_engine([], 20, 20, -1, false)
	e4.start_game(0)
	e4.state.hand = [CardData.from_dict(mom.to_dict()), CardData.from_dict(bear.to_dict())]
	e4.state.energy = 9
	e4.play_from_hand(0, Vector2i(3, 1))
	ck(e4.state.unit_at(Vector2i(3, 0)) != null and e4.state.hand.size() == 1,
			"手卡无效果卡：小鸭照常入场，减费落空不报错")

	print("== 飓风咆哮 9063（每次使用效果卡 × X 次）==")
	var e5 := _new_engine([], 20, 20, -1, false)
	e5.start_game(0)
	var foe: CardData = repo.get_card(1051)
	e5.state.place(CardData.from_dict(foe.to_dict()), Vector2i(1, 0), "opponent")
	e5.state.effects.append(repo.get_card(9063))
	e5.state.effects.append(repo.get_card(9063))
	e5.state.hand = [CardData.from_dict(fx1.to_dict()), CardData.from_dict(fx1.to_dict())]
	e5.state.energy = 9
	var hp0: int = e5.state.unit_at(Vector2i(1, 0)).health
	e5.use_effect(0)
	var hp1: int = e5.state.unit_at(Vector2i(1, 0)).health
	e5.use_effect(0)
	var hp2: int = e5.state.unit_at(Vector2i(1, 0)).health
	ck(hp0 - hp1 == 8, "第 1 次使用效果卡 → 2 张咆哮各轰 1 下 = 8（实际 %d）" % (hp0 - hp1))
	ck(hp1 - hp2 == 8, "第 2 次使用效果卡 → 还是 8（不是「前 X 次」额度用完）（实际 %d）" % (hp1 - hp2))

	print("== 幽深回响 9002（8 点）==")
	var ec: CardData = repo.get_card(9002)
	ck(ec.value == 8 and ec.effect_text.contains("8 点"), "9002 value=8 且文案写 8 点")

	print("\n结果：%d 通过 / %d 失败" % [npass, fail])
	quit(1 if fail > 0 else 0)
