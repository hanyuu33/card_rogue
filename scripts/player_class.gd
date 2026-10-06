class_name PlayerClass
extends RefCounted
## 角色系统 —— 开局选定一个角色，角色决定两件事：
##   * 初始卡组追加的专属卡（森林精魄 → 熊 8004 ×1）；
##   * 进入战斗时自动获得的角色赠品道具（森林精魄 → 荒野形态 6022）。
##
## 卡牌自身的归属角色写在 cards.json 的 class 字段（CardData.card_class），
## 现有角色：森林精魄 / 暗影刺客 / 机械之心（R82 新增）。加新角色时：
##   1. 在 ids() 里加新角色 id；
##   2. 在 relic_of / bonus_deck_of 里登记它的赠品道具与专属初始卡；
##   3. 若新角色要换掉初始卡组里那两张「基础盟友」，在 starter_substitute() 里登记
##      （返回 -1 = 这张卡组**不含**基础盟友，见机械之心）；
##   4. 新角色的卡在 cards.json 里写对应的 class 字段（按它过滤奖励池 / 图鉴）。

const DRUID := "森林精魄"
const ROGUE := "暗影刺客"
const MECH := "机械之心"          # R82：0 费素体滚雪球 + 「升级」改造场面
## 奖励池按角色过滤（R47）：cards.json 的 `class` 字段 = 该卡的**归属角色**，
## 只有本角色能摇到本角色卡（见 CardRepo.reward_pool_for）。
## `class` 留空 = 通用卡（两边都能摇到；当前库内暂无通用卡）。
# 开局卡组的**公共部分**（每个角色都一样）：木栅栏 8001 ×5 + 攻击 8002 ×5
const BASE_COMMON: Array[int] = [8001, 8001, 8001, 8001, 8001,
		8002, 8002, 8002, 8002, 8002]

## 可选角色（顺序 = 角色选择界面的展示顺序）。
static func ids() -> Array[String]:
	return [DRUID, ROGUE, MECH]


static func default_id() -> String:
	return DRUID


static func legacy_id(cid: String) -> String:
	## 旧版角色名的兼容映射（2026-10-03 改名：德鲁伊 → 森林精魄 / 游荡者 → 暗影刺客）。
	## 只给**回放旧录像**用 —— 旧录像 meta 里存的是老名字；现行 id 原样返回。
	match cid:
		"德鲁伊":
			return DRUID
		"游荡者":
			return ROGUE
	return cid


static func name_of(cid: String) -> String:
	return cid


static func subtitle_of(cid: String) -> String:
	match cid:
		DRUID:
			return "自然之力 · 与熊、树人同行"
		ROGUE:
			return "疾影出手 · 幽影与快刀同行"
		MECH:
			return "拆解重组 · 用「升级」把单位越堆越强"
	return ""


## 角色选择界面上的**概括性介绍**（R55，2026-10-03 由详细数值改为一段话概括）：
## 只讲这个角色的打法取向与优劣势，**不列具体卡牌 / 数值** —— 初始卡组与赠品道具的实际
## 效果由界面底部的「初始道具」块单独展示（读 relics.json 的 desc，class_pick_scene 负责）。
static func desc_of(cid: String) -> String:
	match cid:
		DRUID:
			return "稳扎稳打。用工事与厚血盟友换取优势，靠成长与恢复把战斗拖进自己的节奏。\n不擅长速攻，但很难被一次打垮。"
		ROGUE:
			return "抢先压制。用低费技能与持续削弱压低对手的血线，靠爆发在对方站稳之前结束战斗。\n节奏快、容错低，讲究先手与卡序。"
		MECH:
			return "积少成多。靠 0 费的素体在手里越攒越多，再逐个「升级」把它们养成难以击破的硬块。\n起手偏慢，一旦成型就很难被单个点破。"
	return ""


static func relic_of(cid: String) -> int:
	## 角色赠品道具 id（-1 = 没有）。这一件**不入任何随机池**，只随角色发放。
	match cid:
		DRUID:
			return 6022
		ROGUE:
			return 6023
		MECH:
			return 6025
	return -1


static func bonus_deck_of(cid: String) -> Array[int]:
	## 追加到初始卡组的角色专属卡（同一 id 出现几次就给几张）。
	match cid:
		DRUID:
			return [8004]   # 熊 ×1
		ROGUE:
			return [9086]   # 终结 ×1
		MECH:
			return [8026, 8026, 8027]   # 构装体 ×2 + 升级 ×1
	return []


static func starter_substitute(cid: String) -> int:
	## 各角色的「基础盟友」替换卡 —— 初始卡组里有 2 张：森林精魄给树人 8003，暗影刺客给幽影 8005。
	## 两者费用 / 力量 / 生命 / 攻程 / 移速完全相同，只有名字与 traits 不同（见 cards.json）。
	## 机械之心**不用基础盟友**（它的两张厚单位是构装体，见 has_base_ally），返回 -1。
	match cid:
		ROGUE:
			return 8005
		MECH:
			return -1
	return 8003


static func has_base_ally(cid: String) -> bool:
	## 该角色的初始卡组里是否含那两张「基础盟友」。
	## 机械之心 = false：它的 13 张是 5 攻击 + 5 木栅栏 + 2 构装体 + 1 升级，
	## 位置由两张构装体（3 费 3/8）占掉 —— 塞两个 3 费基础盟友会让开局费用曲线爆掉。
	return starter_substitute(cid) > 0


static func start_deck_ids(cid: String) -> Array[int]:
	## 开局卡组的**全部** id（含重复）：公共部分 + 2 张角色基础盟友 + 角色专属卡。
	## CardRepo.starter_deck() 与 RunState.start_run() 都走这里 —— 单一入口，两边不会跑偏。
	var out: Array[int] = []
	out.append_array(BASE_COMMON)
	if has_base_ally(cid):
		var ally := starter_substitute(cid)
		for i in 2:
			out.append(ally)
	out.append_array(bonus_deck_of(cid))
	return out
