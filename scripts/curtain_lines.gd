class_name CurtainLines
extends RefCounted
## R310「卷卷」—— 每层起点的那位豚鼠吟游诗人（用户口径：把每层起点做成一个特殊事件）。
##
## 原来的起点是「起始道具三选一」面板（relic_pick.tscn）；现在换成一段对话：
##   ① 主持人先招呼一句（第一层通用 / 第二层起按玩家职业分支）；
##   ② 三个选项就是 `RunState.relic_choice` 里那三件起始道具（**道具名**做按钮）；
##   ③ 第二层起，玩家收下道具后**回一句**（第一层不出现，用户口径只点了二层）。
##
## 文案唯一口：场景 `curtain_scene.gd` 只调这里，不再自己拼字符串 ——
## 以后要改语气 / 加层数，只改这一个文件。
##
## 层口径：`layer <= LAYER_DEFAULT` = 第一层那套；第三层（目前没有战斗关卡）
## 沿用「二层起」这一套，等它落地自动就位。

const SPEAKER := "卷卷"
const SPEAKER_SUB := "豚鼠吟游诗人"

## R822（店长口径）：**第二层起点有两位主持人，权重相等** ——
##   HOST_BUNBUN = 卷卷（豚鼠吟游诗人）· HOST_DUCK = 鸭绅士。
## 谁出场由 `RunState.layer2_host()` 按「种子」派生：不摇 `run_rng`、也不进存档
## （R819 占卜室的教训 —— 存在场景变量里的话，退出事件再进就能反复重摇到想要的那位）。
## 两人的流程完全一致（招呼一句 → 三选一 → 玩家回一句），所以场景只多一个 `host`
## 参数，不新增状态机分支；带「鸭」的四件道具只在鸭绅士那边出现。
const HOST_BUNBUN := 0
const HOST_DUCK := 1


static func speaker_of(host: int) -> String:
	## 名称牌上的名字。
	## ⚠️ 返回的**已经是当前语言**的文本 —— 场景里不要再套一层 `GameI18n.source()`，
	##    否则本地化后的字符串会被当成「中文原文」再查一遍（查不到就原样，看着没事，
	##    但一旦某个语言的名字恰好和别的条目撞字就会串味）。
	if host == HOST_DUCK:
		return GameI18n.ui("shell", "CURTAIN_DUCK_SPEAKER", "鸭绅士")
	return GameI18n.ui("shell", "CURTAIN_SPEAKER", "卷卷")


static func greeting(layer: int, cls: String, host := HOST_BUNBUN) -> String:
	## 主持人的开场白。第一层恒为卷卷（鸭绅士只在第二层起点出场）。
	if layer <= GameLayers.LAYER_DEFAULT:
		return GameI18n.ui("shell", "CURTAIN_GREETING_DEFAULT", "看看这里有什么能帮到你的。")
	if host == HOST_DUCK:
		match PlayerClass.legacy_id(cls):
			PlayerClass.DRUID:
				return GameI18n.ui("shell", "CURTAIN_DUCK_GREETING_DRUID", "这次又给你添麻烦了。")
			PlayerClass.ROGUE:
				return GameI18n.ui("shell", "CURTAIN_DUCK_GREETING_ROGUE",
						"能帮我逮住那只该死的猫吗？走私，逃税，偷窃，简直无恶不作。")
			PlayerClass.MECH:
				return GameI18n.ui("shell", "CURTAIN_DUCK_GREETING_MECH", "别急着走，我还要很多合作想和你谈。")
		return GameI18n.ui("shell", "CURTAIN_DUCK_GREETING_DRUID", "这次又给你添麻烦了。")
	match PlayerClass.legacy_id(cls):
		PlayerClass.DRUID:
			return GameI18n.ui("shell", "CURTAIN_GREETING_DRUID", "在这里遇到你真开心。")
		PlayerClass.ROGUE:
			return GameI18n.ui("shell", "CURTAIN_GREETING_ROGUE", "这些就当做定金吧。")
		PlayerClass.MECH:
			return GameI18n.ui("shell", "CURTAIN_GREETING_MECH", "你喜欢音乐吗？")
	return "看看这里有什么能帮到你的。"


static func has_reply(layer: int, _host := HOST_BUNBUN) -> bool:
	## 收下道具后，玩家角色要不要出场回一句（用户口径：**二层**拿取道具之后）。
	## 卷卷与鸭绅士同口径 —— 两人都是「对方一句 + 玩家一句」的两句制。
	return layer > GameLayers.LAYER_DEFAULT


static func reply(layer: int, cls: String, host := HOST_BUNBUN) -> String:
	## 玩家的回答（`has_reply()` 为 false 时返回空串 —— 第一层不出现）。
	if not has_reply(layer, host):
		return ""
	if host == HOST_DUCK:
		match PlayerClass.legacy_id(cls):
			PlayerClass.DRUID:
				return GameI18n.ui("shell", "CURTAIN_DUCK_REPLY_DRUID", "很高兴能帮到大家。")
			PlayerClass.ROGUE:
				return GameI18n.ui("shell", "CURTAIN_DUCK_REPLY_ROGUE", "强吗，那家伙？")
			PlayerClass.MECH:
				return GameI18n.ui("shell", "CURTAIN_DUCK_REPLY_MECH", "下次一定。")
		return ""
	match PlayerClass.legacy_id(cls):
		PlayerClass.DRUID:
			return GameI18n.ui("shell", "CURTAIN_REPLY_DRUID", "我也是。")
		PlayerClass.ROGUE:
			return GameI18n.ui("shell", "CURTAIN_REPLY_ROGUE", "我就喜欢这种有趣的工作。")
		PlayerClass.MECH:
			return GameI18n.ui("shell", "CURTAIN_REPLY_MECH", "是的，这个节奏让我安心。")
	return ""


static func reply_speaker(layer: int, cls: String, _host := HOST_BUNBUN) -> String:
	## 回答那一句的名称牌 = 玩家职业名（换牌即「换人说话」）。
	return PlayerClass.display_name_of(cls)


static func skip_label(layer: int, _host := HOST_BUNBUN) -> String:
	## 「不要道具」那个出口的文案（第一层 / 二层起语气不同）。
	if layer <= GameLayers.LAYER_DEFAULT:
		return GameI18n.ui("shell", "CURTAIN_SKIP_LAYER_ONE", "摇摇头（不拿）")
	return GameI18n.ui("shell", "CURTAIN_SKIP_LAYER_TWO", "摆手拒绝（不拿）")


static func backdrop_name(host: int) -> String:
	## 整屏背景的素材名（`assets/ui/<名字>.png`）。
	## 缺图不空白也不报错：`UiAssets.get_tex()` 返回 null 时场景会退回内置暗底。
	if host == HOST_DUCK:
		return "bg_curtain_duck"
	return "bg_curtain"
