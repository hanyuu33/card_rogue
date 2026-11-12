extends SceneTree
## R613 只读探针：野兔 9032 的「标记」到底是谁挂上去的。
##
## 用户报障（2026-11-12）：野兔在**商店里**也带上标记，只有它造出来的复制野兔才该带。
## 本探针只回答三件事，不改任何数据：
##   ① 卡库原卡的 affixes 是什么（= 商店 / 图鉴 / 牌库看到的那份）；
##   ② 复制品的 affixes 是什么（= 应该带标记的那份）；
##   ③ 造一次复制之后，卡库原卡有没有被污染（共享 Array 引用）。
##
## 跑法：Godot --headless --path . --script res://tools/probe_r613_rabbit.gd

const HARE_ID := 9032


func _init() -> void:
	var repo := CardRepo.load_json()
	var src: CardData = repo.get_card(HARE_ID)
	if src == null:
		printerr("NO_CARD ", HARE_ID)
		quit(1)
		return
	print("库内原卡 affixes=", src.affixes, " traits=", src.traits,
			" ephemeral=", src.is_ephemeral)
	print("库内原卡 effect_text=", src.effect_text)

	# ① 商店拿到的是不是同一个实例（RunState 进货走 repo 还是 from_dict）
	var shop_like: CardData = repo.get_card(HARE_ID)
	print("二次取卡同一实例=", shop_like == src,
			" affixes=", shop_like.affixes,
			" 同数组=", shop_like.affixes == src.affixes)

	# ② 复制品（与 GameEngine._spawn_self_clone 同口径，逐句对齐）
	var clone: CardData = CardData.from_dict(src.to_dict())
	clone.traits = (src.traits as Array).duplicate()
	clone.is_ephemeral = true
	clone.affixes = ["次元"]
	print("复制品 affixes=", clone.affixes, " ephemeral=", clone.is_ephemeral)

	# ③ 污染检查：造完复制再回读卡库原卡
	var after: CardData = repo.get_card(HARE_ID)
	print("造完复制后 库内原卡 affixes=", after.affixes,
			" 干净(=空)=", (after.affixes as Array).is_empty())

	# ④ 卡面标记队列（商店 / 手牌读这个；战场另有过滤）
	print("卡面标记队列(非战场)=", CardFace.affix_badge_queue(src, false))
	print("卡面标记队列(战场)=", CardFace.affix_badge_queue(src, true))
	print("复制品标记队列(非战场)=", CardFace.affix_badge_queue(clone, false))
	print("复制品标记队列(战场)=", CardFace.affix_badge_queue(clone, true))
	quit()
