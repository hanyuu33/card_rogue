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
##   1) 在 LAYERS 里加一条 {name, content_layers, events, treasure_col}；
##   2) 给该层的关卡打上 `"layer": <层号>`，事件写进该层的 events 表。
##
## 层内字段：
##   * name            层名（地图标题栏显示）
##   * content_layers  本层内容池包含哪些层（决定关卡/事件从哪几层取）
##   * events          事件节点子类型的权重（相对权重，本层内归一化；0 = 本层不出现）
##   * treasure_col    本层固定的「宝箱层」所在列（-1 = 本层没有宝箱层）
##
## 「全层通用」的事件写进**每一层**的 events 表（如遗忘之泉 oblivion）。
## 内容仍按层隔离 —— 没有「继承上一层事件」这种隐式行为，都要显式登记。

const LAYER_DEFAULT := 1      # 第一层
const LAYER_TWO := 2          # 第二层

const LAYERS := {
	1: {
		"name": "第一层",
		"content_layers": [1],
		# 事件子类型权重（相对权重，本层内归一化；0 = 本层不出现）。
		# 「鸭之凝视 / 一袋米抗几楼」已挪到第二层 —— 本层不再出 gaze。
		"events": {
			"monster": 10,    # 遭遇怪物（按普通战斗处理）
			"whisper": 27,    # 鸭鸭低语（事件道具）
			"struggle": 18,   # 挣扎（失去生命换金属龙）
			"arcane": 18,     # 奥秘之泉（第一层专属）：奥秘护符 / 随机效果或技能牌三选一
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
			"treasure": 31,   # 宝箱（卡牌奖励）
		},
		"treasure_col": 6,    # 第六层固定为宝箱层（整层开箱得奖励道具）
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
			"oblivion": 14,   # 遗忘之泉（全层通用）：可从卡组删一张卡，或离开
		},
		"treasure_col": 6,    # 第二层同样把第 6 层设为宝箱层
	},
}

# 事件子类型 → 显示名（日志 / 界面用）。
# relic_chest 不是随机事件，而是宝箱层（treasure_col）整层的固定内容。
const EVENT_NAMES := {
	"monster": "遭遇怪物",
	"whisper": "鸭鸭低语",
	"struggle": "挣扎",
	"gaze": "鸭之凝视",
	"pear": "鸭梨山大",
	"hero": "绝赞五换一",
	"bluefish": "蓝色大肥鱼",
	"arcane": "奥秘之泉",
	"oblivion": "遗忘之泉",
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
	var nxt := layer + 1
	return nxt if LAYERS.has(nxt) else 0


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


static func treasure_col(layer: int) -> int:
	## 本层固定的宝箱层列号。
	## **未配置的层返回 -1（没有宝箱层）** —— 宝箱层同样是「该层的内容」，
	## 不会自动出现在别的层里。
	var cfg: Variant = LAYERS.get(layer, null)
	if cfg == null:
		return -1
	return int(cfg.get("treasure_col", -1))


static func roll_event_kind(layer: int, rng: RandomNumberGenerator,
		used: Dictionary = {}) -> String:
	## 按本层权重抽一个事件子类型（权重 ≤ 0 的不会被抽到）。
	##
	## **不重复（R68）**：传入 `used`（本层已出过的子类型集合，键 = 子类型名）时，
	## 已经在 `used` 里的子类型本轮不再参与抽取 —— 于是「一轮之内每种事件只出一次」。
	## **本层池子被抽空一轮后自动清空 `used` 开始下一轮**，所以事件节点数多于池子大小时
	## 仍能正常生成（只有这时才会重复出现）。`used` 是**就地修改**的（Dictionary 传引用）。
	## 不传 `used`（默认空表）= 旧行为：纯按权重抽、允许重复。
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
	# 全部子类型都出过一次了 → 清空记录，开始新一轮（此时才允许重复）
	if cand.is_empty():
		used.clear()
		for k in w:
			if int(w[k]) > 0:
				cand[k] = int(w[k])
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
