class_name GameLayers
extends RefCounted
## 「层」定义 —— 地图的大章节（第一层 / 第二层 ……），内容按层隔离、可显式混用。
##
## 一张地图必定属于某一层（`RogueMap.generate(rng, layer)`）；
## 该地图上出现的战斗关卡（GameLevels 里带 layer 的关卡）与事件
## （LAYERS 里 events 表列出的子类型），都只从「本层的内容池」里取。
##
## 内容池由 content_layers 决定（战斗关卡与事件都取自这些层）：
##   * 第一层 = [1]      —— 只用第一层自己的内容；
##   * 第二层 = [2]      —— 只用第二层自己的内容（专属关卡 + 专属事件）；
##   * 未配置的层 = []    —— 拿不到任何内容（不会顺手继承第一层）。
## 各层内容互不串层：第二层地图不会出现第一层的关卡/事件，反之亦然。
##
## 新增一层：
##   1) 在 LAYERS 里加一条 {name, content_layers, events}；
##   2) 给该层的关卡打上 `"layer": <层号>`，事件写进该层的 events 表。
##
## 层内字段：
##   * name            层名（地图标题栏显示）
##   * content_layers  本层内容池包含哪些层（决定关卡/事件从哪几层取；
##                     第三层 = [2, 3]：关卡借第二层、Boss 是自己的）
##   * events          事件节点子类型的权重（相对权重，本层内归一化；0 = 本层不出现）
##
## 「全层通用」的事件写进**每一层**的 events 表（如遗忘之泉 oblivion）。
## 内容仍按层隔离 —— 没有「继承上一层事件」这种隐式行为，都要显式登记。

const LAYER_DEFAULT := 1      # 第一层
const LAYER_TWO := 2          # 第二层
## R309（用户口径）：第三层**先把事件登记上**，不影响当前游玩 ——
## 它的战斗关卡还没做，所以 `next_layer()` 里加了「下一层必须有战斗关卡才算数」的判据，
## 打完第二层 Boss 仍然是整局通关。等第三层关卡落地时，这一层的事件自动就位。
const LAYER_THREE := 3        # 第三层（R356：5 格直道 + 启示者；关卡借第二层精英）

const LAYERS := {
	1: {
		"name": "第一层",
		"content_layers": [1],
		# 事件子类型权重（相对权重，本层内归一化；0 = 本层不出现）。
		# 「鸭之凝视 / 一袋米抗几楼」已挪到第二层 —— 本层不再出 gaze。
		# R128：**事件房间不再遭遇战斗** —— 原先的 "monster"（遭遇怪物）条目已移除。
		"events": {
			"whisper": 27,    # 鸭鸭低语（事件道具）
			"struggle": 18,   # 挣扎（失去生命换金属龙）
			"arcane": 18,     # 奥秘之泉（第一层专属）：奥秘护符 / 随机效果或技能牌三选一
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
			"smith": 12,       # 鸭鸭工匠（R110，全层通用）：把卡组里一张卡变成「2 费铁栅栏」
			"treasure": 31,   # 宝箱（卡牌奖励）
			"delivery": 20,  # 运送委托（R200，第一层专属）：选 1~6 张「货物」入卡组
			"lake_lady": 16,  # 湖中仙女（R305，第一层专属）：谎言删一张初始卡 / 诚实得随机史诗卡
			"divination": 14,  # 占卜室（R308）：占卜后随机 4 种幻象，每种两个解读（卡 / 道具）
		},
	},
	2: {
		"name": "第二层",
		# 专属内容：只用第二层自己的关卡与事件（不再混用第一层）
		# 本层专属事件：鸭梨山大（pear，获得道具「鸭梨」）
		#               绝赞五换一（hero，随机删 5 张不同名的卡 → 得「英雄」）
		#               蓝色大肥鱼（bluefish，可将一张「鲸鱼之怒」加入卡组）
		# 从第一层挪来的：鸭之凝视（gaze，获得道具「一袋米抗几楼」）
		"content_layers": [2],
		"events": {
			"pear": 20,       # 鸭梨山大（第二层专属事件）
			"hero": 20,       # 绝赞五换一（第二层专属）：随机删 5 张不同名的卡 → 得「英雄」
			"bluefish": 20,   # 蓝色大肥鱼（第二层专属）：可将一张「鲸鱼之怒」加入卡组
			"gaze": 18,       # 鸭之凝视（原第一层事件，现归第二层）：获得「一袋米抗几楼」
			"apple_doctor": 18,  # 苹果与医生（R244，第二层专属）：收下苹果（+7 最大生命并回满）或放弃
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
			"smith": 12,       # 鸭鸭工匠（R110，全层通用）：把卡组里一张卡变成「2 费铁栅栏」
			# R305：卡片商人（第二层）。R309 起第三层也登记了（见 LAYERS[3]）。
			"card_merchant": 16,
			# R308：占卜室（R309 起第三层也登记了，见 LAYERS[3]）。
			"divination": 12,
			# R351 赏月（第二层专属）：失去全部金币换「月亮」，或直接拿「硬币」。
			"moon": 20,
		},
	},
	3: {
		"name": "第三层",
		# R356：本层的战斗关卡=**启示者**（唯一一个，layer 3），精英节点按用户口径
		# **沿用第二层**（直道第 2 格固定是精英战斗）→ `content_layers` 写 [2, 3]：
		#   关卡池 = 第二层的普通 / 精英 + 本层的 Boss；
		#   `boss_pool(3)` 仍只认「本层专属 Boss」，所以摇到的必然是启示者。
		# 事件表保留在这里（第三层地图只有 5 个固定格、没有事件节点，实际抽不到）。
		"content_layers": [2, 3],
		"events": {
			# 「全层通用」的两个（约定：每层都写一份，不继承）
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
			"smith": 12,      # 鸭鸭工匠（全层通用）：把卡组里一张卡变成「2 费铁栅栏」
			# 用户口径要「2、3 层都有」/「1、2、3 层都有」的两个
			"card_merchant": 16,  # 卡片商人：换卡 / 5 费卡换大宝箱 / 随机折价
			"divination": 12,     # 占卜室：占卜 → 随机 4 种幻象 → 两种解读
		},
	},
}

# 事件子类型 → 显示名（日志 / 界面用）。
# relic_chest 不是随机事件，而是 event_scene 里「开箱得道具」的固定分支。
# R128：5×7 格子地图里它由「大宝箱房」（固定两角）触发，不再有「整层宝箱」的概念。
const EVENT_NAMES := {
	"whisper": "鸭鸭低语",
	"struggle": "挣扎",
	"gaze": "鸭之凝视",
	"pear": "鸭梨山大",
	"hero": "绝赞五换一",
	"bluefish": "蓝色大肥鱼",
	"apple_doctor": "苹果与医生",
	"arcane": "奥秘之泉",
	"oblivion": "遗忘之泉",
	"smith": "鸭鸭工匠",
	"card_merchant": "卡片商人",
	"lake_lady": "湖中仙女",
	"divination": "占卜室",
	"moon": "赏月",
	"delivery": "运送委托",
	"delivery_done": "委托完成",
	"treasure": "卡牌宝箱",
	"relic_chest": "宝箱层",
}


static func exists(layer: int) -> bool:
	## 该层是否已实现（有配置）。
	return LAYERS.has(layer)


static func layer_name(layer: int) -> String:
	## 层名（未配置时退回「第 N 层」）。
	var cfg: Variant = LAYERS.get(layer, null)
	return str(cfg["name"]) if cfg != null else "第 %d 层" % layer


static func content_layers(layer: int) -> Array[int]:
	## 本层「内容池」包含的层号：地图上的关卡/事件从这些层里取。
	## 未配置的层返回空数组 —— 内容按层隔离，别的层不会顺手拿到第一层的内容。
	var cfg: Variant = LAYERS.get(layer, null)
	if cfg == null:
		return []
	var out: Array[int] = []
	for x in cfg.get("content_layers", [layer]):
		out.append(int(x))
	return out


static func next_layer(layer: int) -> int:
	## 本层的下一层；0 = 没有下一层（打完本层 Boss 即整局通关）。
	## ⚠️ R309：还要**真的有战斗关卡**才算「有下一层」——
	##    第三层目前只登记了事件表（没有关卡），若只判 `LAYERS.has()`，
	##    打完第二层 Boss 会把玩家送进一张没有任何战斗的地图。
	var nxt := layer + 1
	if not LAYERS.has(nxt):
		return 0
	if GameLevels.levels_of_layer(nxt).is_empty():
		return 0
	return nxt


static func event_weights(layer: int) -> Dictionary:
	## 本层事件子类型的权重表 = 本层「内容池」里所有层的 events 表相加
	## （内容已按层隔离：第二层只用 [2]，所以只出第二层的专属事件）。
	## **未配置的层返回空表** —— 内容按层隔离：别的层不会顺手拿到第一层的事件。
	var out := {}
	for cl in content_layers(layer):
		var cfg: Variant = LAYERS.get(cl, null)
		if cfg == null or not cfg.has("events"):
			continue
		var ev: Dictionary = cfg["events"]
		for k in ev:
			out[k] = int(out.get(k, 0)) + int(ev[k])
	return out


static func has_events(layer: int) -> bool:
	## 本层是否有事件内容（没有则地图不生成事件节点）。
	var w := event_weights(layer)
	var total := 0
	for k in w:
		total += int(w[k])
	return total > 0


static func event_kinds(layer: int) -> Array[String]:
	## 本层会出现的事件子类型（不含宝箱层 relic_chest）。
	var out: Array[String] = []
	for k in event_weights(layer):
		out.append(str(k))
	return out


static func event_name(kind: String) -> String:
	return str(EVENT_NAMES.get(kind, kind))


static func roll_event_kind(layer: int, rng: RandomNumberGenerator,
		used: Dictionary = {}) -> String:
	## 按本层权重抽一个事件子类型（权重 ≤ 0 的不会被抽到）。
	##
	## **一局只出一次（R374，R445 复核保留）**：`used` = **本局**已经出过的子类型集合
	## （`RunState.event_kinds_used`，跨层共用同一份）。在 `used` 里的子类型不再参与抽取；
	## **池子抽空了不会清空重来** —— 直接返回 `""`，由调用方把那格降级成一般战斗
	## （唯一处理点 = `RogueMap._make_cells`）。
	## R445（用户口径「这一局不会再出现占卜事件，除非事件用尽」）：占卜室跟其它事件走
	## **同一本账**，所以第一轮里只会撞见一次；用尽之后那格变成一般战斗，不会重开。
	## `used` 是**就地修改**的（Dictionary 传引用）。
	## ⚠️ 每层各建一份 `used` = 回到「层内不重复、换层又撞」的老毛病 —— 必须跨层共用。
	## 不传 `used`（默认空表）= 纯按权重抽、允许重复（测试 / 工具用）。
	var w := event_weights(layer)
	if w.is_empty():
		return "treasure"
	# 本轮候选 = 池子里权重 > 0 且还没被 used 占掉的
	var cand := {}
	for k in w:
		if int(w[k]) > 0:
			cand[k] = int(w[k])
	for k in used.keys():
		cand.erase(str(k))
	# R374：本局的池子已经空了 → **不重开**，交回空串让调用方降级（一局只出一次）
	# R445 复核（用户口径「这一局不会再出现占卜事件」）：**确认不清空账本**。
	# ⚠️ 试过「用尽时 `used.clear()` 重开一轮」—— 当场被 engine 断言打回：
	#    清账本 = 第一轮的记录作废 → 同一张图后半段 / 换层后又会抽到第一层出过的
	#    事件（实测「账本 3 种 / 图上 15 种」）。「跨层不重复」比「用尽后重开」重要，
	#    所以这里仍旧返回空串，由 `RogueMap._make_cells` 把那格降级成一般战斗 ——
	#    占卜室因此在一局里绝不会出现第二次。
	if cand.is_empty():
		return ""
	var total := 0
	for k in cand:
		total += int(cand[k])
	if total <= 0:
		return "treasure"
	var roll := rng.randi_range(1, total)
	for k in cand:
		roll -= int(cand[k])
		if roll <= 0:
			used[str(k)] = true
			return str(k)
	return "treasure"
