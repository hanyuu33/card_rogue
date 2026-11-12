extends SceneTree

## R623 探针 2：战斗内复制（野兔 9032）是否把「已烤进数值的附魔」一起复制。

func _init() -> void:
	var repo := CardRepo.load_json()
	var rabbit_proto := repo.get_card(9032)
	print("原卡 id=%d name=%s base cost=%d" % [rabbit_proto.id, rabbit_proto.card_name, rabbit_proto.cost])

	# 模拟「卡组里这张卡被附了 costdown」→ build_deck 烤过：cost -1、enchant 记着
	var baked := CardData.from_dict(rabbit_proto.to_dict())
	baked.cost = maxi(0, baked.cost - 1)
	baked.enchant = "costdown"
	print("烤过附魔后：cost=%d enchant=%s" % [baked.cost, baked.enchant])

	var deck: Array[CardData] = [CardData.from_dict(baked.to_dict())]
	var st := FieldState.new(deck, 20, 20, -1, "测试", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.start_game()
	st.energy = 9
	var hand_idx := -1
	for i in st.hand.size():
		if st.hand[i].id == 9032:
			hand_idx = i
			break
	print("手牌张数=%d 野兔在手牌第 %d 张" % [st.hand.size(), hand_idx])
	if hand_idx < 0:
		quit()
		return
	eng.play_from_hand(hand_idx, Vector2i(4, 1))
	print("打出后手牌=%d" % st.hand.size())
	for c: CardData in st.hand:
		if c.id == 9032:
			print("复制品：id=%d cost=%d enchant=%s affixes=%s is_ephemeral=%s" % [
					c.id, c.cost, c.enchant, str(c.affixes), str(c.is_ephemeral)])
			print("复制品 cost_of=%d" % eng.cost_of(c))
	quit()
