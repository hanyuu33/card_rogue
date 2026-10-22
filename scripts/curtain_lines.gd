class_name CurtainLines
extends RefCounted
## R310「卷卷」—— 每层起点的那位豚鼠吟游诗人（用户口径：把每层起点做成一个特殊事件）。
##
## 原来的起点是「起始道具三选一」面板（relic_pick.tscn）；现在换成一段对话：
##   ① 卷卷先招呼一句（第一层通用 / 第二层起按玩家职业分支）；
##   ② 三个选项就是 `RunState.relic_choice` 里那三件起始道具（**道具名**做按钮）；
##   ③ 第二层起，玩家收下道具后**角色立绘出场回一句**（第一层不出现，用户口径只点了二层）。
##
## 文案唯一口：场景 `curtain_scene.gd` 只调这里，不再自己拼字符串 ——
## 以后要改语气 / 加层数，只改这一个文件。
##
## 层口径：`layer <= LAYER_DEFAULT` = 第一层那套；第三层（目前没有战斗关卡）
## 沿用「二层起」这一套，等它落地自动就位。

const SPEAKER := "卷卷"
const SPEAKER_SUB := "豚鼠吟游诗人"


static func greeting(layer: int, cls: String) -> String:
	## 卷卷的开场白。
	if layer <= GameLayers.LAYER_DEFAULT:
		return "看看这里有什么能帮到你的。"
	match PlayerClass.legacy_id(cls):
		PlayerClass.DRUID:
			return "在这里遇到你真开心。"
		PlayerClass.ROGUE:
			return "这些就当做定金吧。"
		PlayerClass.MECH:
			return "你喜欢音乐吗？"
	return "看看这里有什么能帮到你的。"


static func has_reply(layer: int) -> bool:
	## 收下道具后，玩家角色要不要出场回一句（用户口径：**二层**拿取道具之后）。
	return layer > GameLayers.LAYER_DEFAULT


static func reply(layer: int, cls: String) -> String:
	## 玩家的回答（`has_reply()` 为 false 时返回空串 —— 第一层不出立绘）。
	if not has_reply(layer):
		return ""
	match PlayerClass.legacy_id(cls):
		PlayerClass.DRUID:
			return "我也是。"
		PlayerClass.ROGUE:
			return "……"
		PlayerClass.MECH:
			return "是的，这个节奏让我安心。"
	return ""


static func reply_speaker(layer: int, cls: String) -> String:
	## 回答那一句的名称牌 = 玩家职业名（立绘出场时换牌）。
	return PlayerClass.name_of(PlayerClass.legacy_id(cls))


static func skip_label(layer: int) -> String:
	## 「不要道具」那个出口的文案（第一层 / 二层起语气不同）。
	if layer <= GameLayers.LAYER_DEFAULT:
		return "摇摇头（不拿）"
	return "摆手拒绝（不拿）"
