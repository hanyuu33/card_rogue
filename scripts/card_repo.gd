class_name CardRepo
extends RefCounted
## 卡牌库（肉鸽版）：从 cards.json 加载全部卡。
## 初始卡组由代码引用 json 里的 8001~8003（rarity=初始），怪物卡留在 json 里（rarity=怪物）。

var _cards := {}  # id -> CardData


static func load_json(path: String = "res://cards.json") -> CardRepo:
	var repo := CardRepo.new()
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("cards.json 解析失败")
		return repo
	var list: Array = data if data is Array else data.get("cards", [])
	for d: Dictionary in list:
		var card := CardData.from_dict(d)
		repo._cards[card.id] = card
	return repo


func get_card(id: int) -> CardData:
	return _cards.get(id)


func all_cards() -> Array[CardData]:
	## 图鉴用：cards.json 全部卡（按 id 升序）。
	var out: Array[CardData] = []
	for id: int in _cards.keys():
		out.append(_cards[id])
	out.sort_custom(func(a: CardData, b: CardData): return a.id < b.id)
	return out


func by_group(g: String) -> Array[CardData]:
	## 图鉴分组：player = 玩家卡牌图鉴 / enemy = 敌人图鉴（含敌方关卡效果）。
	var out: Array[CardData] = []
	for c: CardData in _cards.values():
		if c.group == g:
			out.append(c)
	out.sort_custom(func(a: CardData, b: CardData): return a.id < b.id)
	return out


func player_cards() -> Array[CardData]:
	return by_group("player")


func enemy_cards() -> Array[CardData]:
	return by_group("enemy")


func reward_pool() -> Array[CardData]:
	## 肉鸽卡牌奖励的候选池：只有 普通/稀有/史诗（rarity 0~2）能通过奖励获得；
	## 初始（3）、怪物（4）与事件卡（5）排除。当前卡池尚未加入奖励卡时返回空数组。
	var out: Array[CardData] = []
	for c: CardData in _cards.values():
		if c.rarity <= 2 and not c.traits.has("测试"):
			out.append(c)
	out.sort_custom(func(a: CardData, b: CardData): return a.id < b.id)
	return out


func reward_pool_for(cid: String) -> Array[CardData]:
	## 按角色过滤后的奖励池（R47）：在 reward_pool() 的基础上**排除其他角色的卡**，
	## 避免暗影刺客摇到森林精魄的身份卡（实机曾摇到 9082 虚空主宰）、反之亦然。
	## 结果：森林精魄 59 张 / 暗影刺客 37 张（合计池 96；R50 +爆炸陷阱、R51 +冰霜/冻结/剧毒陷阱·陷阱精通、R52 +紧急埋伏·陷阱工坊·暗影狩猎、R53 +穿刺陷阱·双重陷阱、R54 +巨物捕获·活体栅栏·警觉、R55 +地狱猫·鲜血堡垒·活力转移）。
	## cid 留空 → 不过滤（返回完整奖励池，演示 / 测试用）。
	if cid == "":
		return reward_pool()
	var out: Array[CardData] = []
	for c: CardData in reward_pool():
		if is_own_class_card(c, cid):
			out.append(c)
	return out


func is_own_class_card(c: CardData, cid: String) -> bool:
	## 该卡是否属于 cid 角色的奖励可选卡 = 本角色卡 ∪ 通用卡。
	## 通用卡 = class 字段留空（卡库现状：每张卡都有明确角色归属，暂无通用卡；
	## 将来要加通用卡，把 class 留空即可 —— 两边都能摇到）。
	return c.card_class == "" or c.card_class == cid


## 肉鸽初始卡组（13 张）：木栅栏×5 + 攻击×5 + 两张「基础盟友」+ 1 张角色专属卡。
## 基础盟友与专属卡都按角色走 PlayerClass.start_deck_ids()
## （森林精魄：树人 / 熊；暗影刺客：幽影 / 突袭）。
func starter_deck(cid := "") -> Array[CardData]:
	## cid 留空时用当前 run 的角色（RunState.player_class）。
	var cards: Array[CardData] = []
	var cls := cid if cid != "" else RunState.player_class
	for i in PlayerClass.start_deck_ids(cls):
		cards.append(_card_by_id(i))
	return cards


func _card_by_id(id: int) -> CardData:
	var c := get_card(id)
	if c == null:
		push_error("初始卡缺定义：%d" % id)
		c = CardData.new()
	return c
