extends SceneTree

## R623 探针：核对「复制卡是否复制附魔」与「同一张卡本回合减费是否重复生效」。
## 只读不写盘（不改 cards.json / 不落存档）。

func _init() -> void:
	var repo := CardRepo.load_json()
	_probe_duplicate(repo)
	quit()


func _probe_duplicate(repo: CardRepo) -> void:
	print("==== 鸭血复制：附魔是否被带走 ====")
	RunState.deck_ids = [8001, 8002, 8003]
	RunState.deck_mods = [RunState.enchant_mod("costdown"), {}, {}]
	RunState.ensure_deck_mods()
	var orig := RunState.card_with_mod(repo, 0)
	print("原卡 id=%d name=%s cost=%d enchant=%s affixes=%s" % [
			orig.id, orig.card_name, orig.cost, orig.enchant, str(orig.affixes)])
	var res := RunState.duplicate_deck_cards(repo, [0])
	print("复制返回 ok=%s copied=%s" % [str(res.get("ok")), str(res.get("copied"))])
	print("deck_ids=%s" % str(RunState.deck_ids))
	print("deck_mods=%s" % str(RunState.deck_mods))
	var idx: int = RunState.deck_ids.size() - 1
	var copyc := RunState.card_with_mod(repo, idx)
	print("复制品 id=%d name=%s cost=%d enchant=%s affixes=%s" % [
			copyc.id, copyc.card_name, copyc.cost, copyc.enchant, str(copyc.affixes)])
	# 再核对：战斗牌库构建后，复制品是否带附魔
	var deck := RunState.build_deck(repo)
	var last := deck[deck.size() - 1]
	print("build_deck 末尾 id=%d cost=%d enchant=%s growth(dmg)=%d" % [
			last.id, last.cost, last.enchant, last.growth_damage])
	RunState.deck_ids = []
	RunState.deck_mods = []
