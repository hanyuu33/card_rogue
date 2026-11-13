class_name NetSession
extends RefCounted
## 联机会话状态：大厅握手成功后填写，battle 场景读取；对局结束清除。
## 用 static 变量在 change_scene 之间传递（同 DeckLibrary.battle_deck_ids 的做法）。

static var active := false
static var link = null                 # Net.NetLink（无类型引用避免循环依赖问题）
static var my_name := GameI18n.ui("shared", "NET_SESSION_DEFAULT_MY_NAME", "玩家")
static var opp_name := GameI18n.ui("shared", "NET_SESSION_DEFAULT_OPPONENT_NAME", "对手")
static var opp_deck_size := 30
static var i_start := true             # 房主先手
static var my_deck_ids: Array[int] = []   # 空 = 内置新手卡组
static var opp_left := false           # 对方已离开（bye / 断线）


static func clear() -> void:
	active = false
	if link != null:
		link.close()
	link = null
	my_deck_ids = []
	opp_left = false
