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


func obtainable_cards() -> Array[CardData]:
	## 「可获得池」= 奖励池去掉**禁卡**那一层（R346）。
	## 为什么要单独一个口：禁卡界面必须**列出已被禁的卡**，否则玩家一点它就消失、
	## 再也点不回来（取消禁卡都做不到）。所以：
	##   * 本函数：稀有度 0~2 + 过剧情锁（不含禁卡过滤）→ 禁卡界面的列表口径；
	##   * `reward_pool()`：在本函数之上再摘掉禁卡 → 真正的随机池。
	ProfileData.ensure_loaded()
	var out: Array[CardData] = []
	for c: CardData in _cards.values():
		if c.rarity > 2 or c.traits.has("测试"):
			continue
		if c.locked and not ProfileData.is_card_unlocked(c.id):
			continue
		out.append(c)
	out.sort_custom(func(a: CardData, b: CardData): return a.id < b.id)
	return out


func reward_pool() -> Array[CardData]:
	## 肉鸽卡牌奖励的候选池：只有 普通/稀有/史诗（rarity 0~2）能通过奖励获得；
	## 初始（3）、怪物（4）与事件卡（5）排除。
	## R346 起再按玩家的**账号进度**过闸（唯一口 —— 商店 / 事件 / 奖励全都读这里）：
	##   ① 剧情锁定：`locked = true` 且还没在故事界面解锁 → 不进池（在 `obtainable_cards` 里）；
	##   ② 玩家禁卡：走 `RunState.is_card_banned()`（R352：局内 = 开局快照，
##      局外 = 账号表任意职业禁过都算）→ 不进池（就是下面这一段）。
	## 两道闸都默认「空」，所以老存档 / 新玩家看到的池子与以前完全一致。
	var out: Array[CardData] = []
	for c: CardData in obtainable_cards():
		if RunState.is_card_banned(c.id):
			continue
		out.append(c)
	return out


func reward_pool_for(cid: String) -> Array[CardData]:
	## 按角色过滤后的奖励池（R47）：在 reward_pool() 的基础上**排除其他角色的卡**，
	## 避免暗影刺客摇到森林精魄的身份卡（实机曾摇到 9082 风元素）、反之亦然。
	## 结果：森林精魄 62 张 / 暗影刺客 58 张（R263 弹跳飞刀 +1；R50 +爆炸陷阱、R51 +冰霜/冻结/剧毒陷阱·陷阱精通、R52 +紧急埋伏·陷阱工坊·暗影狩猎、R53 +穿刺陷阱·双重陷阱、R54 +巨物捕获·活体栅栏·警觉、R55 +地狱猫·鲜血堡垒·活力转移）。
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
