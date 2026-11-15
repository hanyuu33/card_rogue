class_name TutorialScript
extends RefCounted
## R744：新手教程的**文案与步骤定义（唯一口）**。
##
## 为什么单独一个文件：教程文案会被反复改（尤其新增工具那两条），写在场景里
## 迟早散成两三处对不上。这里只放「说什么 / 指哪儿」，怎么画由
## `tutorial_overlay.gd` 负责，什么时候弹由 `tutorial_director.gd` 负责。
##
## `cue` 是**语义名**，不是坐标：宿主场景（地图页 / 战斗页）自己把名字翻译成矩形
## —— 所以同一句「这是手牌」在第几次生成的战场上都能指对地方。

const ID_MAP_WALK := "map_walk"
const ID_MAP_CHOCO := "map_choco"
const ID_BATTLE_BASIC := "battle_basic"
const ID_BATTLE_ALLY := "battle_ally"
const ID_TOOL_PLACE := "tool_place"
const ID_TOOL_USE := "tool_use"


static func pages(id: String) -> Array:
	## 返回该教程的页数组。空数组 = 没有这个 id（调用方据此跳过）。
	match id:
		ID_MAP_WALK:
			return [
				{"cue": "", "text": "地图每一局都是新画的，所以我没法提前告诉你路长什么样——只能教你怎么读。"},
				{"cue": "map_player", "text": "这圈金框里的，就是你此刻站着的房间。人在哪儿，这张图就从哪儿开始读。"},
				{"cue": "map_reachable",
					"text": "带绿框的房间，是下一步就能进去的。点一下，你就走过去了。"},
				{"cue": "map_reachable",
					"text": "有些框淡一些——那说明要穿过一间走过的空房才到得了。只要框还在，就都走得通。"},
			]
		ID_MAP_CHOCO:
			return [
				{"cue": "map_choco",
					"text": "右上角这块巧克力，是这一层的行动力（别问我为什么是巧克力，我猜是老板饿了）。"},
				{"cue": "map_choco", "text": "每走一格，吃掉一块。数目就摆在那儿，走之前先看一眼。"},
				{"cue": "", "text": "巧克力见底，天就黑了——本层的 Boss 会挡在你面前。所以省着走，别把路走成回头路。"},
			]
		ID_BATTLE_BASIC:
			return [
				{"cue": "hand", "text": "开打了。底下这一排是你的手牌——每回合开始抽 5 张。"},
				{"cue": "hand",
					"text": "回合一结束，手里剩下的全部丢掉。所以别攒着，能打就打出去。"},
				{"cue": "cost", "text": "左边这枚数字是费用，每回合都重置。出牌要花它，花光了就等到下一回合。"},
				{"cue": "hp", "text": "顶上这条血是你的命。归零，这一局就到此为止。"},
				{"cue": "enemies",
					"text": "把场上所有敌人清干净，或者把对面的血打空——你就赢了。"},
			]
		ID_BATTLE_ALLY:
			return [
				{"cue": "hand_ally",
					"text": "这张不是法术，是能留在场上的伙伴（盟友或工事）。打出去，它就替你打。"},
				{"cue": "board_own", "text": "盟友打出去会落在你自己的半场。轮到你时点它一下，就能动、能打。"},
				{"cue": "board_own",
					"text": "工事不会走，但它会一直守在那儿；盟友能走能打，也会替你挨打。位置摆对了，一条线就守住了。"},
			]
		ID_TOOL_PLACE:
			return [
				{"cue": "tool_bar", "text": "你拿到了一个工具。它是消耗品——用一次就没了，不会回到卡组里。"},
				{"cue": "tool_bar", "text": "这一种是「放置型」：把它拖到战场的空格上，它就埋伏在那儿等。"},
				{"cue": "board_own",
					"text": "敌人踩上去才会触发。所以放它之前，先想想对面下一步会往哪走。"},
			]
		ID_TOOL_USE:
			return [
				{"cue": "tool_bar", "text": "你也拿到了「使用型」工具——这种不用放，点一下就直接结算。"},
				{"cue": "tool_bar", "text": "小血瓶回血、法力药剂回费用。留着救命，比省着划算。"},
			]
	return []


static func title(id: String) -> String:
	match id:
		ID_MAP_WALK:
			return "在地图上行走"
		ID_MAP_CHOCO:
			return "巧克力与入夜"
		ID_BATTLE_BASIC:
			return "这是一场卡牌战"
		ID_BATTLE_ALLY:
			return "盟友与工事"
		ID_TOOL_PLACE:
			return "放置型工具"
		ID_TOOL_USE:
			return "使用型工具"
	return ""


static func unseen(id: String) -> bool:
	return not ProfileData.is_tutorial_seen(id) and not pages(id).is_empty()
