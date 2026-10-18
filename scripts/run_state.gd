class_name RunState
extends RefCounted
## 肉鸽单次闯关（run）的玩家状态 —— 跨战斗保留。
## 玩家拥有「最大生命」和「当前生命」：战斗中受伤结算在局内，
## 战斗胜利后把剩余生命写回这里，下一场接着用。
## 事件（如「休息」）也作用在这份状态上。
##
## 肉鸽流程：start_run 生成地图与初始卡组 → 战斗/休息/事件节点推进 →
## 胜利领取卡牌奖励（加入卡组）→ 打败 Boss 通关；失败回标题。
## 每场战斗写入战斗记录（卡组内容 / 是否失败 / 最终血量），
## 持久化在 user://battle_records.json，跨 run 保留。

const RECORDS_PATH := "user://battle_records.json"
const RECORDS_KEEP := 200          # 最多保留的记录条数

static var max_hp: int = 50      # 玩家最大生命
static var hp: int = 50          # 玩家当前生命（跨战斗保留）

# ---- run 进度 ----
static var run_active := false               # 是否在肉鸽 run 中（false = 单关/演示模式）
static var deck_ids: Array[int] = []         # 当前卡组（卡 id，可重复）
## R181 商店附魔：与 deck_ids **等长**的修饰列表。每个元素是 {}（无附魔）或
## {"cost":-1} / {"power":+10} / {"affix":"次元","power":+2,"health":+10} / {"affix":"保存"}。
## 只改这一张卡（不改卡库共享实例）：`build_deck` 按 mod 生成独立副本再应用。
## 每张卡只能有一个附魔（enchant_deck_card 会拒绝已附魔的卡）。跨战斗、跨层保留。
static var deck_mods: Array = []
## 卡组费用**一律以卡面为准**（R112）：早前鸭鸭工匠产物靠 `deck_cost_at_index()` 把卡组里的
## 铁栅栏现算成 2 费、而卡面是 0 费 → 「图鉴 0 费 / 卡组 2 费」两处不一致。用户拍板
## 「只保留 2 费」后，直接把 **9072 的卡面改成 2 费**，那套运行时费用改写已整块删除。
static var map_cells: Array = []             # RogueMap.generate 的结果（5×7 = 35 个房间，下标即 id）
static var current_layer := GameLayers.LAYER_DEFAULT  # 本局地图所属的层（第一层）
static var current_node_id := -1             # 玩家所在房间（-1 = 还没出发）
## 已**走过**的房间 id（R128 语义）：既决定回溯是否免费，也决定该房间的门是否可见。
static var cleared_ids: Array = []
## R207：**曾经看清过的房间** id（只增不减）。用户口径「已经揭开的迷雾，不需要再还原」——
## 旧规则把可见性算成「当前房间 + 它的邻居」，于是玩家往前走一格，**原来那批邻居**
## 立刻又被雾盖回去（明明刚才看过）。现在每次判定命中视野就记进这里，永久认得。
## 随续档持久化（run_save）；换层 / 新开一局 / 结束一局时清空。
static var seen_ids: Array = []
## R128 巧克力：每层固定 RogueMap.MAX_STEPS 块。进入**没走过**的房间扣 1 块，
## 原路返回走过的房间不扣。扣到 0 → 本房间内容结算完立刻开 Boss 战（boss_pending）。
static var chocolate := 0
## R181 金币：本局货币。初始 100；战斗胜利按难度掉落（普通简单 20 / 普通困难 30 /
## 精英简单 50 / 精英困难 65 / Boss 100）；开普通宝箱 +50、大宝箱 +80；商店消费。
## 跨战斗、跨层保留（同一局）；start_run 重置 100、end_run 清 0。advance_layer 不清。
static var gold := 0
static var boss_pending := false             # 巧克力已耗尽，等当前房间结算完就开 Boss 战
## R234 止血绷带（6029）：本层累计的「下次休息额外回血」点数。换层 / 开新局 / 结束局清零。
static var bandage_pending := 0
static var pending_level: Dictionary = {}    # 即将进入的战斗关卡（地图 → 战斗）
static var pending_node: Dictionary = {}     # 即将进入的地图节点（地图 → 休息/事件）
static var reward_context := ""              # 奖励来源："battle" / "event" / ""（演示）
static var reward_type := "normal"           # 奖励类型："normal" / "boss"（概率构成不同）
static var pending_event := ""               # 即将进入的事件子类型："treasure" / "whisper"
static var pending_deck_edit := ""           # 事件「遗忘之泉」的待办卡组操作："" / "delete"（删一张卡）
static var reward_kinds: Array[String] = []  # 本次卡牌奖励的卡类限制（空 = 不限制；如 ["效果","技能"]）
static var battle_log: Array = []            # 本局战斗记录（与持久化文件同步追加）
## R177 玩家地图标记（当局内共享）：`map_strokes` = 画图模式折线，每条
## `{"pts": PackedVector2Array, "col": Color}`（一次拖拽一条，坐标 = 地图场景屏幕坐标，
## 地图区 = 227,94 起 826×590）；`map_flags` = 标记模式小旗，每个
## `{"pos": Vector2, "col": Color}`。颜色取绘制时的职业色快照。
## ⚠️ 只清在 start_run / end_run（新开一局 / 本局结束）—— **advance_layer 不清**
##    （用户口径：当局内不论从哪种方式访问地图都能看到，跨层也算同一局）。
static var map_strokes: Array = []
static var map_flags: Array = []
static var player_class: String = "森林精魄"   # 本局所选角色（PlayerClass.ids() 之一）
static var battle_wins := 0                   # 本局已胜利的普通战斗数（前 2 场简单）
static var elite_wins := 0                   # 本局已胜利的精英战斗数（前 2 场简单）
static var used_levels: Array = []           # 本局已进入的关卡名（尽量不重复）
static var boss_pick: Dictionary = {}       # 本局摇定的本层 Boss 关卡（R63：同层可能有多个 Boss；
									# 开局摇一次，地图名牌与实际进入读同一份）
# 彩蛋 Boss（R73）：第一层摇到「恶魔鸭」时按 REVENGE_TRIGGER_CHANCE 置位，
# 下一层（第二层）摇 Boss 时被顶替成「恶魔鸭（复仇）」并复位。
# **一次性**：消费后立刻置回false —— 免得第三层（若以后有）继续顶替。
static var revenge_pending := false
const REVENGE_TRIGGER_CHANCE := 0.5         # 50%
const DEMON_DUCK_BOSS_NAME := "恶魔鸭"       # 第一层触发条件：摇中的 boss 名必须是它

# ---- 难度档位（R47 三档 → R223 重做成 0~10 共 11 档）----
# R223 起：角色选择界面用**左右箭头**调档（0~10），**高难度继承低难度全部 debuff**。
# 用户口径逐档新增内容（数值口径见下方各 const 与取值函数）：
# R224 起新增全局规则：**除到达新的一层外不能回复 HP**（用户口径）——
# 战斗胜利回血、休息处篝火回血两类「自动回复」全部作废（两表归零，见下）。
#   0 = 初始金钱 +50（R224 前还带战斗胜利回 3 血、休息 40%，现已归零）
#   1 = 篝火（休息）回复量降低（R224：休息处不再回血 → 本条暂无数值效果，文本保留待换新 debuff）
#   2 = 战斗胜利不再回复生命值（R224：全档位战斗胜利均不回血，文本保留待换新 debuff）
#   3 = 开场时敌人生命值 +10%（向上取整）
#   4 = 稀有卡牌获取概率降低（稀有权重 ×0.5）
#   5 = 行动力低时疲惫（巧克力 <6 → 一张诅咒「疲惫」9149 加入卡组；≥6 移除）
#   6 = 敌人更加凶猛（除原本 0 攻工事外，所有敌人攻击 +1）
#   7 = 金钱减少（初始金钱 150 → 100，后续每层也都是 100）
#   8 = 行动力降低（每层初始巧克力 12 → 11）
#   9 = 虚弱（最大生命 ×80%，截断取整）
#   10 = 继承 0~9 全部 debuff，**无新增**（给「全都要」的玩家一个终点）
# 档位只在角色选择界面改，不属于 run 状态（end_run / start_run 都不动它）。
static var difficulty: int = 0
const DIFFICULTY_COUNT := 11
const DIFFICULTY_NAMES: Array[String] = ["轻松", "微恙", "严酷", "顽强", "稀缺",
		"疲惫", "凶暴", "贫瘠", "匆忙", "虚弱", "噩梦"]
## 各档位**新增** debuff 的文本（用户口径原话）。0 档 = 「无」；第 10 档无新增（空串）。
## R224：`difficulty_note()` 只返回**当前档**这一条（用户口径「难度文本没有必要写所有，
## 只需要写当前难度新增就行了」）—— 高档继承低档的全部 debuff 由 `difficulty_summary()`
## 的数值摘要承载（那里列的都是「实际生效」的数值）。
const DIFFICULTY_TEXTS: Array[String] = [
	"无",
	"篝火回复生命值降低",
	"战斗胜利不再回复生命值",
	"敌人更加顽强",
	"稀有卡牌获取概率降低",
	"行动力低时疲惫",
	"敌人更加凶猛",
	"金钱减少",
	"行动力降低",
	"虚弱",
	"",
]
## R224：全局规则「除到达新的一层外不能回复 HP」→ 战斗胜利回血全档位归零。
## 表保留 11 长度（回归钉死口径；将来若再加「某档回血」类 debuff 改这张表即可）。
const DIFFICULTY_BATTLE_HEAL: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # 战斗胜利回复量
## R237：恢复篝火回血 —— 难度 0 = 40%，1 档起 = 25%（即原始设计；R224 曾按用户要求归零，现加回）。
## ⚠️ 战斗胜利回血（DIFFICULTY_BATTLE_HEAL）**仍为 0**：用户只要求篝火能回血，不恢复被动自动回血。
const DIFFICULTY_REST_PCT: Array[float] = [0.40, 0.25, 0.25, 0.25, 0.25, 0.25,
		0.25, 0.25, 0.25, 0.25, 0.25]                                   # 休息回复百分比

## 各 debuff 的数值口径（**唯一口** —— 界面 / 引擎 / 测试都读这里，别在各处写死数字）
const DIFF_GOLD_LOW := 150         # 0~6 档初始金钱（原 100 + 难度 0 的 +50）
const DIFF_GOLD_HIGH := 100        # 7 档起「金钱减少」
const DIFF_RARE_WEIGHT_MUL := 0.5  # 4 档起「稀有卡牌获取概率降低」：稀有权重 ×0.5
const DIFF_FATIGUE_FROM := 5       # 5 档起「行动力低时疲惫」
const DIFF_FATIGUE_LIMIT := 6      # 巧克力 < 6 → 疲惫入卡组；≥ 6 → 移除
const DIFF_ENEMY_HP_PCT := 0.10    # 3 档起「敌人更加顽强」：敌人生命 +10%（向上取整）
const DIFF_ENEMY_POWER := 1        # 6 档起「敌人更加凶猛」：敌人攻击 +1
const DIFF_CHOCO_HIGH := 11        # 8 档起「行动力降低」：每层初始巧克力 11（原 12）
const DIFF_MAX_HP_MUL := 0.8       # 9 档起「虚弱」：最大生命 ×80%（截断取整）
## 诅咒卡「疲惫」（9149）：1 费诅咒，打出无效果；**在手里时**所有技能卡费用 +1。
const FATIGUE_CARD_ID := 9149

# ---- 本局种子：run 层唯一随机源 ----
static var run_seed: int = 0                 # 本局种子（run 层全部随机由它派生；同一种子重跑必然一致）
static var run_rng := RandomNumberGenerator.new()   # 本局随机源（地图/道具/关卡/掉落/五换一）

# ---- 道具 ----
static var relics: Array[int] = []           # 已拥有的道具 id（跨战斗保留）
static var skipped_relics: Array[int] = []   # 奖励掉落里被「跳过」的道具 id：本局后续不再随机出来
static var relic_choice: Array[int] = []     # 起点三选一的候选（选定后清空）
static var pending_relic := -1               # 等待卡组选择的即时道具 id（-1 = 无）
static var pending_relic_drop := -1          # 精英/Boss 掉落的道具 id（-1 = 无，领取后清空）

# ---- R119：待领奖励队列（奖励悬浮窗的数据源）----
## 「获得奖励」不再当场发放，而是**先入队** → 由 RewardPanel 悬浮窗逐项展示。
## 玩家自行决定查看顺序，看过可以退回列表再看、再领取；领取 / 放弃过的那一条置灰。
## 每项字典（kind 决定字段）：
##   {"kind": "relic", "id": int, "state": String}
##   {"kind": "cards", "type": String, "kinds": Array[String],
##    "candidates": Array[int], "picked": int, "state": String}
## ⚠️ 只在 start_run 清空（**end_run 故意不清**）：通关那一场的奖励是「打完才弹窗看」的，
##    end_run 在结算面板里就跑了，此时清掉会让最后一击的战利品凭空消失。
static var pending_rewards: Array = []
const REWARD_PENDING := "pending"    # 待领（悬浮窗里正常显示）
const REWARD_CLAIMED := "claimed"    # 已领取（置灰）
const REWARD_SKIPPED := "skipped"    # 已放弃（置灰）
static var duck_revive_chance := 100         # 叠加态的鸭（6013）：当前复活概率（每次复活 -25）

# 事件道具 id
const WHISPER_RELIC_ID := 6010   # 鸭之低语（事件节点获得）
## 鹰哨（R128 奖励道具）：地图上**所有房间的门全部可见**（含没走过的房间）。
## 消费方只有 map_scene（决定是否画未访问房间的门），引擎侧不参与。
const EAGLE_WHISTLE_RELIC_ID := 6026
const BARBECUE_RELIC_ID := 6011  # 烤肉（休息处获得，进入 Boss 战时消耗）
const RICE_RELIC_ID := 6012      # 一袋米抗几楼（鸭之凝视事件获得）
const STACK_DUCK_RELIC_ID := 6013  # 叠加态的鸭（复活道具，奖励池）
const PEAR_RELIC_ID := 6019      # 鸭梨（鸭梨山大事件获得；战斗内每次 HP 受伤 → 最大生命 +1）
const ARCANE_CHARM_RELIC_ID := 6020  # 奥秘护符（奥秘之泉事件 / 奖励池；每回合第一张效果牌费用 -1）
const WILD_FORM_RELIC_ID := 6022      # 荒野形态（森林精魄角色赠品；不入任何随机池）
const DUCK_REVIVE_STEP := 25     # 每次复活后降低的百分点

# 鸭血（6024，奖励道具）：获得时从卡组里**最多选 2 张卡各复制一份**加入卡组。
# 「最多 2 张」的上限只有这一处，界面按它显示按钮与提示，别在界面里另写死数字。
const DUCK_BLOOD_RELIC_ID := 6024
const DUCK_BLOOD_MAX := 2

# 二层事件「绝赞五换一」的奖励卡（cards.json）：5 费 5/25 程1 速1，须弃 4 张手牌才能使用
const HERO_CARD_ID := 9023

# 事件「鸭鸭工匠」（R110）：把卡组里选中的那张卡变成一张「铁栅栏」（FENCE_CARD_ID）。
# ⚠️ R112：铁栅栏 9072 的**卡面费用就是 2 费**（早前是 0 费卡 + 运行时按 2 费计）。
# 费用只有一个来源（cards.json），所以这里只记 id，不再有 SMITH_COST / 覆盖表。
const FENCE_CARD_ID := 9072

# 事件「运送委托」（R200）的货物卡（cards.json）：1 费工事 0/6/0/0，
# **被破坏时从卡组中删除**（引擎 `_destroy` 的货物分支是唯一口）。
# rarity 5（事件）→ 不进奖励池，只能从「运送委托」事件获得。
const CARGO_CARD_ID := 8065
## R200：「委托完成」（第二层第一个事件房，持有货物时替换）是否已结算 ——
## **一次性**（每个保有货物抽奖一次，结算后本局不再触发）。
## start_run / end_run 复位；advance_layer 故意不清（第二层只进一次）。
static var delivery_done := false

# 即时道具
const SOURCE_POWER_ID := 6002     # 源数之力（改造卡组中的一张卡）
const SOURCE_POWER_HP_COST := 5   # 源数之力的代价：失去 5 点最大生命

# R224 新道具：苹果（6027，奖励池）—— 获得时**立即 +14 最大生命并回复满生命值**。
# 全局 HP 规则「除到达新的一层外不能回复 HP」下，它是主动道具口径的回血手段
# （与烤肉 / 黄桃罐头 / 自愈同属「道具·卡牌主动回血」，被动自动回血已全部移除）。
const APPLE_RELIC_ID := 6027
const APPLE_MAX_HP := 14
# R224 新道具：牛奶（6028，奖励池）—— 获得时随机摇 **2 种**互不重复的附魔，
# 各附到一张卡组里「能附且尚未附魔」的卡上（资格判定走 `enchant_ok` 唯一口；
# 某种附魔当前没有合规目标就跳过，不强求附满）。
const MILK_RELIC_ID := 6028
const MILK_ENCHANTS := 2
# R234 新道具：止血绷带（6029，奖励池）—— 一场战斗中我方 HP 受到的伤害合计**超过 20** 时，
# 记一层「本层下次休息 +8 生命」的账（同层可累计）。进休息处由 consume_bandage_heal() 结算。
# 换层 / 开新局 / 结束局都清零（「本层」口径）。
const BANDAGE_RELIC_ID := 6029
const BANDAGE_THRESHOLD := 20   # 「超过 20 点」= 严格大于
const BANDAGE_HEAL := 8


static func reset(new_max := 50) -> void:
	## 重置生命（保留 run 进度——单测与旧流程兼容）。
	max_hp = new_max
	hp = new_max


static func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


static func heal(amount: int) -> int:
	## 回复指定生命，上限为最大生命。返回实际回复量。
	var gained: int = mini(max_hp - hp, maxi(0, amount))
	hp += gained
	return gained


# ---- 难度档位（R223 重做成 0~10）----

static func _diff() -> int:
	## 当前档位（越界兜底）。
	return clampi(difficulty, 0, DIFFICULTY_COUNT - 1)


static func set_difficulty(d: int) -> void:
	## 角色选择界面用左右箭头调档（0~10）。越界钳制、**不循环**。
	difficulty = clampi(d, 0, DIFFICULTY_COUNT - 1)


static func difficulty_name() -> String:
	return DIFFICULTY_NAMES[_diff()]


static func difficulty_note() -> String:
	## **当前档新增**的 debuff 文本（R224：只写当前档这一条，不再把 1..当前档全拼上）。
	## 0 档 = 「无」；第 10 档本身无新增文本 → 显示「无新增」。
	var d := _diff()
	var t: String = DIFFICULTY_TEXTS[d] if d < DIFFICULTY_TEXTS.size() else ""
	return t if t != "" else "无新增"


static func difficulty_summary() -> String:
	## 当前档**实际生效的数值**一览（角色选择界面第二行）—— 免得只看到「虚弱」不晓得是 80%。
	## 金钱 / 巧克力恒定显示；其余只在「已生效」时列出（低难度下保持一行）。
	## R224：回血类 debuff 两表归零 → 不再列「篝火」；继承关系由这里的数值替文本说话。
	var d := _diff()
	var bits: Array[String] = ["初始金钱 %d" % start_gold(), "巧克力 %d" % chocolate_per_layer()]
	if d >= 3:
		bits.append("敌血 +%d%%" % int(round(enemy_hp_bonus_pct() * 100.0)))
	if d >= 4:
		bits.append("稀有率 ×%.1f" % rare_weight_mul())
	if d >= 6:
		bits.append("敌攻 +%d" % enemy_power_bonus())
	if d >= 9:
		bits.append("最大生命 %d%%" % int(round(max_hp_mul() * 100.0)))
	return " · ".join(bits)


static func battle_win_heal() -> int:
	## 战斗**胜利**后的自动回复量。R224 全局规则「除到达新的一层外不能回复 HP」
	## → 所有档位均为 0（表留 11 长度供回归与将来调整）。
	return DIFFICULTY_BATTLE_HEAL[_diff()]


static func rest_pct() -> float:
	## 本档位的休息回复百分比。R224：休息处不再回血 → 全档位 0.0。
	return DIFFICULTY_REST_PCT[_diff()]


static func rest_heal_amount() -> int:
	## 休息事件的回复量 = 最大生命 × 本档位百分比（向上取整），再受上限封顶。
	## R224：rest_pct 全 0 → 恒为 0（保留函数是为了「将来要把休息回血加回来」只有一个口）。
	return ceili(max_hp * rest_pct())


static func rest() -> int:
	## 「休息」事件：R224 起休息处不再回复生命（全档位 rest_pct = 0）→ 恒返回 0。
	return heal(rest_heal_amount())


static func bandage_add(n: int) -> void:
	## R234 止血绷带：一场战斗受伤 > 20 → 记一层 +8（同层累计）。
	bandage_pending += maxi(0, n)


static func consume_bandage_heal() -> int:
	## R234 止血绷带：进休息处时结算「本层累计」的额外回血，结算后清零。
	## 返回**实际**回复量（受最大生命上限限制；满血时返回 0 但仍清零）。
	if bandage_pending <= 0:
		return 0
	var amt := bandage_pending
	bandage_pending = 0
	return heal(amt)


# ---- R223：0~10 各 debuff 的取值函数（界面 / 引擎 / 测试的唯一口）----

static func start_gold() -> int:
	## 新开一局（与换层）的初始金钱：0~6 档 = 150（含难度 0 的 +50），7 档起 = 100。
	return DIFF_GOLD_HIGH if _diff() >= 7 else DIFF_GOLD_LOW


static func chocolate_per_layer() -> int:
	## 每层初始巧克力：8 档起「行动力降低」= 11，其余 = RogueMap.MAX_STEPS(12)。
	return DIFF_CHOCO_HIGH if _diff() >= 8 else RogueMap.MAX_STEPS


static func add_chocolate(n: int) -> void:
	## 增加巧克力（商店「巧克力 +1」等来源）。
	## R236 修复：最后一格进商店把体力耗到 0 → `boss_pending` 已置位；此时买到巧克力
	## 让体力回到 > 0，必须**撤销**这条「等本房间结算完就开 Boss」的待触发，
	## 否则离店后仍会进 Boss 战（用户报的 bug）。
	## 判据用「体力 > 0」而不是「本次加了几点」—— boss_pending 的唯一成因就是体力耗尽，
	## 体力一旦回到正数，这条待触发就该失效。
	chocolate += maxi(0, n)
	if chocolate > 0 and boss_pending:
		boss_pending = false


static func max_hp_mul() -> float:
	## 初始最大生命系数：9 档起「虚弱」= 0.8，其余 = 1.0。
	return DIFF_MAX_HP_MUL if _diff() >= 9 else 1.0


static func enemy_hp_bonus_pct() -> float:
	## 3 档起「敌人更加顽强」：敌方开场生命 +10%（向上取整）。
	return DIFF_ENEMY_HP_PCT if _diff() >= 3 else 0.0


static func enemy_power_bonus() -> int:
	## 6 档起「敌人更加凶猛」：敌方开场攻击 +1（原本 0 攻工事除外，见 scaled_enemy_card）。
	return DIFF_ENEMY_POWER if _diff() >= 6 else 0


static func rare_weight_mul() -> float:
	## 4 档起「稀有卡牌获取概率降低」：卡牌奖励里稀有权重的乘数（×0.5）。
	return DIFF_RARE_WEIGHT_MUL if _diff() >= 4 else 1.0


static func fatigue_active() -> bool:
	## 5 档起「行动力低时疲惫」是否生效。
	return _diff() >= DIFF_FATIGUE_FROM


static func scaled_enemy_card(card: CardData) -> CardData:
	## 难度 3 / 6 的敌方开场缩放：**返回副本**，绝不改卡库原卡（卡库与关卡编成同源；
	## `place()` 直接引用卡库原卡，改数值必须先复制）。两个 debuff 都关闭时原样返回。
	##   * 难度 ≥3：生命 +10%（向上取整）；
	##   * 难度 ≥6：攻击 +1，**原本 0 攻的工事除外**（用户口径「除原本力0工事外」）。
	## 与 `configure_growth`（atk_growth 独立叠加、与 card.power 解耦）顺序无关。
	if card == null:
		return null
	var pct := enemy_hp_bonus_pct()
	var add := enemy_power_bonus()
	var skip_power: bool = card.is_fort() and card.power == 0
	if pct <= 0.0 and (add <= 0 or skip_power):
		return card
	var c := CardData.from_dict(card.to_dict())
	if pct > 0.0:
		c.health += ceili(card.health * pct)
	if add > 0 and not skip_power:
		c.power += add
	return c


static func sync_fatigue() -> void:
	## R223 难度 5「行动力低时疲惫」：**从 deck_ids 直接推导**（不加布尔 flag，读档天然正确）。
	## 难度 ≥5 且巧克力 < 6 → 卡组里放一张「疲惫」9149；巧克力 ≥6（或难度不足）→ 移除。
	## 调用点：start_run / advance_layer / advance（扣巧克力后）/ 事件与商店的巧克力加法 /
	## RunSave.load_run（读档后按巧克力纠正）。
	## ⚠️ 战斗内不调用（战斗中巧克力不变；手牌每场从 deck_ids 重抽，删卡组即生效）。
	if fatigue_active() and chocolate < DIFF_FATIGUE_LIMIT:
		if not deck_ids.has(FATIGUE_CARD_ID):
			add_card(FATIGUE_CARD_ID)
	elif deck_ids.has(FATIGUE_CARD_ID):
		remove_all_cards(FATIGUE_CARD_ID)


static func gain_max_hp(amount: int) -> int:
	## R181：商店「+5 最大生命（并回血）」—— 最大生命 +amount，当前生命同 +amount
	## （即「上限提升的同时也补上这几点血」）。返回实际增加的最大生命。
	if amount <= 0:
		return 0
	max_hp += amount
	hp = mini(max_hp, hp + amount)
	return amount


static func lose_max_hp(amount: int) -> int:
	## 失去指定点数的最大生命（「源数之力」的代价）：
	## 当前生命同步下降相同的点数，且不超过新的上限、不低于 0；
	## 至少保留 1 点最大生命（否则玩家会直接暴毙）。返回实际失去的点数。
	var lost: int = mini(maxi(0, amount), maxi(0, max_hp - 1))
	if lost <= 0:
		return 0
	max_hp -= lost
	hp = clampi(hp - lost, 0, max_hp)
	return lost


# ------------------------------------------------------------ run 生命周期

static func start_run(map: Array, layer := GameLayers.LAYER_DEFAULT,
		cid: String = "", seed_override := 0) -> void:
	## 新 run：满血、初始卡组、载入地图、定位起点（第 0 列唯一节点）。
	## layer = 本局地图所属的层（地图上所有战斗/事件都从这一层的内容池里取）。
	## map 传空数组时用本局种子现生成（真实流程 = 角色选择场景这样进来）。
	## R241 种子：`seed_override != 0` 时**用它**（同一种子必然同一张图、同一串掉落/摇卡）；
	## 0 = 现摇一个。整局只有这一行碰全局随机源，之后所有随机都由 `run_seed` 派生。
	# 初始生命按职业不同（R182）：基础 50 + 职业加成（森林精魄+20/暗影刺客+10/机械之心+16）。
	# R223 难度 9「虚弱」：初始最大生命 ×80%（截断取整）—— 在 reset 之前算好基数。
	var base_hp: int = PlayerClass.base_hp_of(cid if cid != "" else PlayerClass.default_id())
	if max_hp_mul() < 1.0:
		base_hp = int(base_hp * max_hp_mul())
	reset(base_hp)
	# run 种子（R241）：**全局唯一随机源**的根 —— 地图 / 掉落 / 摇卡 / 商店库存 / 战斗种子
	# 全部从它派生；同一种子重开、以及「继续游戏」读档（seed + rng.state）都走这条链。
	run_seed = seed_override if seed_override != 0 else randi()
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_active = true
	player_class = cid if cid != "" else PlayerClass.default_id()
	map_cells = map if not map.is_empty() else RogueMap.generate(run_rng, layer)
	current_layer = layer
	cleared_ids = []
	seen_ids = []                 # R207：新开一局 → 迷雾记忆清空
	chocolate = chocolate_per_layer()   # R223 难度 8「行动力降低」：8 档起 = 11
	gold = start_gold()           # R181 初始 100 金；R223 难度 0 +50、难度 7 起降回 100
	boss_pending = false
	battle_log = []
	pending_level = {}
	pending_node = {}
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	# 开局卡组 = 公共部分 + 2 张角色基础盟友（森林精魄 → 树人；暗影刺客 → 幽影）
	# + 角色专属卡（森林精魄 → 熊 8004；暗影刺客 → 突袭 9086）。见 PlayerClass.start_deck_ids。
	deck_ids = PlayerClass.start_deck_ids(player_class)
	deck_mods = []                # R181：新开一局 → 附魔清空
	ensure_deck_mods()            # R204：立刻对齐成等长（否则附魔必越界，见函数注释）
	sync_fatigue()                # R223 难度 5：开局巧克力满 → 先入/出一次（<6 才生效）
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	map_strokes = []              # R177：新开一局清掉上一局的玩家标记
	map_flags = []
	# 本层 Boss 开局摇定（同层多个 Boss 时随机；走 run_rng → 同一种子必然可复现）
	# 彩蛋 Boss（R73）：开新 run 先清pending，再摇 —— _roll_boss 内部会按
	# 「第一层是否摇中恶魔鸭」置位。顺序不能反，否则会用到上一局残留的 pending。
	revenge_pending = false
	boss_pick = _roll_boss(current_layer)
	relics = []
	bandage_pending = 0
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	pending_rewards = []   # R119：开新 run 清空待领奖励
	duck_revive_chance = 100
	delivery_done = false       # R200：新开一局 → 「委托完成」未结算
	pending_event = ""
	# 角色赠品道具（森林精魄 → 荒野形态 6022）：不入随机池，也不占起点三选一的名额
	var cls_relic := PlayerClass.relic_of(player_class)
	if cls_relic > 0:
		gain_relic(cls_relic)
	# 起点三选一：从初始道具池随机抽 3 个不重复的
	relic_choice = _roll_relic_choice()
	current_node_id = -1
	if not map_cells.is_empty():
		var sc := RogueMap.start_cell(map_cells)
		if not sc.is_empty():
			current_node_id = int(sc["id"])
			# ⚠️ 起点开局就记「已走过」：规则是「初始点和已经走过的房间除外」，
			# 漏掉这一步的话，玩家从别处**走回起点会被当成新房间误扣一块巧克力**。
			cleared_ids.append(current_node_id)
	reveal_known()                # R207：开局视野（起点 + 邻居 + 地标）立刻记进 seen


static func end_run(clear_save: bool = true) -> void:
	## run 结束（通关 / 失败）：
	##   * clear_save = true（默认）：连**续档**一起清掉 —— 这一局真的结束了；
	##   * clear_save = false：只复位内存里的 run 状态，**保留续档**（R167）——
	##     给「返回标题」这种「先离开一下、回头还能点『继续游戏』」的路径用。
	## 记录与持久化文件照旧保留。
	run_active = false
	player_class = PlayerClass.default_id()
	deck_ids = []
	deck_mods = []                # R181：本局结束 → 附魔清掉
	map_cells = []
	current_layer = GameLayers.LAYER_DEFAULT
	current_node_id = -1
	cleared_ids = []
	seen_ids = []                 # R207：本局结束 → 迷雾记忆清掉
	chocolate = 0
	gold = 0                      # R181：本局结束 → 金币清掉
	boss_pending = false
	pending_level = {}
	pending_node = {}
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	# 彩蛋 Boss（R73）：run 结束必须复位，否则上一局触发的 pending 会漏进下一局，
	# 让新玩家莫名其妙在第二层撞见恶魔鸭（复仇）。
	revenge_pending = false
	boss_pick = {}
	reward_type = "normal"
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	map_strokes = []              # R177：本局结束 → 标记随之清掉
	map_flags = []
	relics = []
	bandage_pending = 0
	relic_choice = []
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	duck_revive_chance = 100
	delivery_done = false       # R200：本局结束 → 复位
	pending_event = ""


	# 续档：run 结束（通关 / 失败 / 放弃）→ 本地存档随之失效。
	if clear_save:
		RunSave.clear_save()


static func advance_layer(layer: int) -> int:
	## 进入下一层（打败上一层 Boss 后由 battle_scene 调用）：
	##   * **恢复所有生命**（第二层起始节点：满血重新出发）；
	##   * 生成本层地图（RogueMap.generate(rng, layer)，5×7 格子）；
	##   * 掷本层起始道具三选一（第一层 = 初始池，第二层 = 二层起始池）；
	##   * 重置层内进度（战斗计数 / 选关记录 / 已清节点），**卡组与道具跨层保留**。
	## 返回本层起点节点 id（-1 = 地图为空）。
	max_hp = maxi(1, max_hp)
	hp = max_hp                      # 二层起始：恢复所有生命
	bandage_pending = 0             # R234：换层 → 止血绷带待结算清零（本层口径）
	current_layer = layer
	battle_wins = 0
	elite_wins = 0
	used_levels = []
	# 本层 Boss 开局摇定（换层要重摇：第二层只有机械巨鸭）
	boss_pick = _roll_boss(layer)
	cleared_ids = []
	seen_ids = []                 # R207：换层 = 新地图 → 上一层记得的格子全部作废
	pending_level = {}
	pending_node = {}
	pending_event = ""
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	reward_type = "normal"
	# 本层地图用本局种子续摇（同一 run 的随机链条：start_run → 各次 advance_layer）
	map_cells = RogueMap.generate(run_rng, layer)
	relic_choice = _roll_relic_choice()
	chocolate = chocolate_per_layer()   # 新一层：巧克力重新满上（R223 难度 8 起 = 11）
	sync_fatigue()                # R223 难度 5：新层巧克力满 → 疲惫出卡组
	boss_pending = false
	current_node_id = -1
	if not map_cells.is_empty():
		var sc2 := RogueMap.start_cell(map_cells)
		if not sc2.is_empty():
			current_node_id = int(sc2["id"])
			cleared_ids.append(current_node_id)   # 起点同样算「初始点」
	reveal_known()                # R207：本层开局视野立刻记进 seen
	return current_node_id


# ---- 道具 ----


static func _roll_boss(layer: int) -> Dictionary:
	## 从「本层 Boss 池」摇一个。走 run_rng → 同一种子必然可复现。
	## 池里只有一个（第二层）时直接返回它，不消耗随机源。
	##
	## **彩蛋 Boss（R73）**：摇第一层的Boss 时，若摇中「恶魔鸭」→ 50% 概率
	## 置 `revenge_pending`；之后**第二层的 boss 被顶替成「恶魔鸭（复仇）」**。
	## 判定写在这一处（而不是 boss 分支的调用点），是为了让
	## ① `boss_pick`（地图 Boss 名牌的数据源）② `next_level("boss")` 实际进入的关卡
	## 读的是同一份结果 —— 否则地图上写机械巨鸭、进去却是恶魔鸭（复仇）。
	## 走 run_rng → 同一种子必然可复现。
	if layer == GameLayers.LAYER_DEFAULT:
		var first := _pick_from_boss_pool(layer)
		if str(first.get("name", "")) == DEMON_DUCK_BOSS_NAME \
				and run_rng.randf() < REVENGE_TRIGGER_CHANCE:
			revenge_pending = true
		return first
	# 第二层：彩蛋顶替优先（顶替后不再消耗随机源 —— 池里本来也只有机械巨鸭一只）。
	if revenge_pending:
		revenge_pending = false
		return GameLevels.revenge_boss()
	return _pick_from_boss_pool(layer)


static func _pick_from_boss_pool(layer: int) -> Dictionary:
	## 纯「从本层 Boss 池随机抽一只」，不含彩蛋逻辑（供 _roll_boss 分派）。
	var pool := GameLevels.boss_pool(layer)
	if pool.is_empty():
		return GameLevels.boss_level(layer)
	if pool.size() == 1:
		return pool[0]
	return pool[run_rng.randi() % pool.size()]


static func _roll_relic_choice() -> Array[int]:
	## 从「本层起始道具池」随机抽 3 个不重复的（池小于 3 时全给）：
	## 第一层 = 初始道具池（6001~6004）；第二层 = 二层专属起始道具池（6014~6018）。
	var pool := RelicRepo.load_json().start_ids_for_layer(current_layer)
	var out: Array[int] = []
	var bag: Array[int] = pool.duplicate()
	while out.size() < 3 and not bag.is_empty():
		out.append(bag.pop_at(run_rng.randi() % bag.size()))
	return out


static func choose_start_relic(id: int) -> void:
	## 起点三选一：收下所选道具（relic_pick 场景调用）。
	gain_relic(id)
	relic_choice = []


static func gain_relic(id: int) -> void:
	## 获得道具：登记进列表；即时类当场结算。
	if relics.has(id):
		return
	relics.append(id)
	var relic := RelicRepo.load_json().get_relic(id)
	if relic == null:
		return
	match relic.id:
		6001:   # 类固醇：最大生命 +6（当前生命同 +6）
			max_hp += 6
			hp += 6
		6002:   # 源数之力（SOURCE_POWER_ID）：先失去 5 点最大生命，再进入卡组选择
			lose_max_hp(SOURCE_POWER_HP_COST)
			pending_relic = relic.id
		6004:   # 失忆药水：需要玩家再选一张卡
			pending_relic = relic.id
		DUCK_BLOOD_RELIC_ID:   # 鸭血：从卡组里最多选 2 张各复制一份（进卡组编辑场景）
			pending_relic = relic.id
		6017:   # 重鸭（二层起始）：拾起时最大生命 +6（当前生命同 +6）
			max_hp += 6
			hp += 6
		APPLE_RELIC_ID:   # 苹果（R224）：立即 +14 最大生命，并**回复满**生命值
			gain_max_hp(APPLE_MAX_HP)
			hp = max_hp
		MILK_RELIC_ID:   # 牛奶（R224）：随机两种附魔，附给能附魔的卡
			_apply_milk()


static func has_relic(id: int) -> bool:
	return relics.has(id)


static func offer_relic_drop(node_type: String) -> int:
	## 精英 / Boss 战斗胜利：从奖励池随机掉落一个道具（不与已拥有的、
	## 以及本局曾被「跳过」的重复 —— 跳过表示不想要，后续不再随机出来）。
	## 掉落登记到 pending_relic_drop，由奖励界面领取；没有可掉落的返回 -1。
	if node_type != "elite" and node_type != "boss":
		return -1
	var pool: Array[int] = []
	for id in RelicRepo.load_json().reward_ids():
		if not relics.has(id) and not skipped_relics.has(id):
			pool.append(id)
	if pool.is_empty():
		return -1
	pending_relic_drop = pool[run_rng.randi() % pool.size()]
	return pending_relic_drop


static func claim_relic_drop() -> int:
	## 领取掉落的道具（奖励界面调用）。返回道具 id（无掉落返回 -1）。
	if pending_relic_drop < 0:
		return -1
	var id := pending_relic_drop
	pending_relic_drop = -1
	gain_relic(id)
	return id


static func skip_relic_drop() -> int:
	## 跳过掉落的道具（奖励界面调用）：放弃本次掉落并登记 ——
	## 本局后续的随机掉落 / 开箱都不会再摇出它。返回道具 id（无掉落返回 -1）。
	if pending_relic_drop < 0:
		return -1
	var id := pending_relic_drop
	pending_relic_drop = -1
	if not skipped_relics.has(id):
		skipped_relics.append(id)
	return id


static func roll_reward_relic() -> int:
	## 宝箱层开箱：随机一个「尚未拥有、也未被跳过」的奖励道具 id（没有时返回 -1）。
	var pool: Array[int] = []
	for id in RelicRepo.load_json().reward_ids():
		if not relics.has(id) and not skipped_relics.has(id):
			pool.append(id)
	if pool.is_empty():
		return -1
	return pool[run_rng.randi() % pool.size()]


static func _drop_settled_batch() -> void:
	## R138：开始**新一批**奖励之前，把上一批已经处理过的条目扔掉 ——
	## 悬浮窗列表只显示「当前这一批」（用户反馈：过去的奖励还留在列表里）。
	## ⚠️ 只在**待领为 0**（上一批全部处理完）时才清：同一批内「领了一个 → 另一个置灰」
	##   是 R119 的设计（置灰反馈），那一批没处理完就不许动。
	if pending_reward_count() > 0:
		return
	pending_rewards.clear()


static func queue_relic_reward(id: int) -> void:
	## 一件道具奖励入队（精英 / Boss 掉落、宝箱层开箱）。
	## **入队不等于发放** —— 玩家在奖励悬浮窗里看过、点「领取」才真进道具栏。
	if id <= 0:
		return
	_drop_settled_batch()
	pending_rewards.append({"kind": "relic", "id": id, "state": REWARD_PENDING})


static func queue_card_reward(reward_type: String = "normal",
		kinds: Array[String] = []) -> int:
	## 一组卡牌奖励（三选一）入队。**候选在这一刻**用 run_rng 摇定 ——
	## 候选早就定了，玩家只是稍后才看、才选，所以同一种子逐步一致。
	## 返回队列下标（-1 = 卡池空，没有可给的卡）。
	var roll_rng: RandomNumberGenerator = run_rng if run_active else null
	var rolled := CardReward.roll(CardRepo.load_json(), reward_type,
			CardReward.CHOICES, roll_rng, kinds)
	var ids: Array[int] = []
	for c: CardData in rolled:
		ids.append(c.id)
	if ids.is_empty():
		return -1
	_drop_settled_batch()
	pending_rewards.append({"kind": "cards", "type": reward_type,
			"kinds": kinds.duplicate(), "candidates": ids, "picked": -1,
			"state": REWARD_PENDING})
	return pending_rewards.size() - 1


static func pending_reward_count() -> int:
	## 还没处理的奖励条数（state = pending）—— 就是常驻入口上那个「N」。
	var n := 0
	for e: Dictionary in pending_rewards:
		if str(e.get("state", REWARD_PENDING)) == REWARD_PENDING:
			n += 1
	return n


static func has_pending_rewards() -> bool:
	return not pending_rewards.is_empty()


static func waiting_pick_scene() -> String:
	## R216：「必须先选卡才能结算」的待办 → 返回要去的场景（"" = 没有待办）。
	## 唯一判据口 —— 即时道具（鸭血 6024 / 源数之力 6002 / 失忆药水 6004）与事件卡组操作
	## （`pending_deck_edit`：遗忘之泉 / 鸭鸭工匠）都汇到这里。
	## ⚠️ 只有 run 进行中才算：局已经结束（`end_run`）之后道具仍可能被领，但那时不该再跳。
	if not run_active:
		return ""
	if pending_relic > 0 or pending_deck_edit != "":
		return "res://scenes/deck_edit.tscn"
	return ""


static func claim_pending_reward(idx: int) -> bool:
	## 领取第 idx 条：道具 → 进道具栏。成功后 state = claimed（悬浮窗里那条置灰）。
	## ⚠️ 卡牌奖励**不走这里**：卡牌必须先在三选一里选一张（pick_pending_card），
	##    没有「空组领取」这回事。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	if str(e.get("kind", "")) != "relic":
		return false
	var rid := int(e.get("id", 0))
	if pending_relic_drop == rid:
		claim_relic_drop()   # 精英 / Boss 掉落走原路径（顺带清掉 pending_relic_drop）
	else:
		gain_relic(rid)      # 宝箱层等：直接进道具栏
	e["state"] = REWARD_CLAIMED
	return true


static func skip_pending_reward(idx: int) -> bool:
	## 放弃第 idx 条：道具 → 登记「本局不再随机出来」；卡牌 → 放弃这组候选。
	## 同样置灰（state = skipped）—— 对玩家来说都是「这条已经处理过了」。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	if str(e.get("kind", "")) == "relic":
		var rid := int(e.get("id", 0))
		if pending_relic_drop == rid:
			skip_relic_drop()
		elif not skipped_relics.has(rid):
			skipped_relics.append(rid)
	e["state"] = REWARD_SKIPPED
	return true


static func pick_pending_card(idx: int, card_id: int) -> bool:
	## 卡牌奖励：在三选一里选下 card_id —— 既记下选择、也当场入卡组
	## （卡牌没有「先存着」的说法），该条随即置灰。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "cards":
		return false
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	var cands: Array = e.get("candidates", [])
	if not cands.has(card_id):
		return false
	e["picked"] = card_id
	e["state"] = REWARD_CLAIMED
	add_card(card_id)
	return true


static func claim_all_relic_rewards() -> int:
	## 一键领取**所有待领的道具**（卡牌组各有各的选择，不参与一键领取）。
	## 返回实际领取条数。
	var n := 0
	for i in pending_rewards.size():
		var e: Dictionary = pending_rewards[i]
		if str(e.get("kind", "")) != "relic":
			continue
		if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
			continue
		if claim_pending_reward(i):
			n += 1
	return n


static func clear_pending_rewards() -> void:
	## 清空待领队列（只在 start_run 调 —— 见 pending_rewards 声明的说明）。
	pending_rewards = []


static func relic_state_note(id: int) -> String:
	## 道具的动态状态说明（叠加态的鸭：当前复活概率）；无动态状态时返回 ""。
	if id == STACK_DUCK_RELIC_ID and relics.has(STACK_DUCK_RELIC_ID):
		return "当前复活概率 %d%%。" % duck_revive_chance
	return ""


static func consume_barbecue() -> int:
	## 道具「烤肉」（6011）：进入 Boss 战时自动消耗 → 回复 25% 最大生命
	## （向上取整，不超过上限）。返回实际回复量；未持有返回 -1。
	## 消耗后道具离开道具栏，因此休息处可以再次烤制。
	if not relics.has(BARBECUE_RELIC_ID):
		return -1
	relics.erase(BARBECUE_RELIC_ID)
	return heal(ceili(max_hp * 0.25))


static func delete_deck_card(index: int) -> bool:
	## 失忆药水：删除卡组中第 index 张卡。成功返回 true。
	if index < 0 or index >= deck_ids.size():
		return false
	deck_ids.remove_at(index)
	_sync_mods_remove(index)     # R181：附魔下标同步前移
	pending_relic = -1
	return true


static func transform_deck_card(repo: CardRepo, index: int) -> Dictionary:
	## 源数之力：把卡组中第 index 张卡变成一张随机奖励卡。
	## 返回 {ok, old_id, new_id}（供界面/日志展示）。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false, "old_id": 0, "new_id": 0}
	var old_id: int = deck_ids[index]
	# 修复（实机体验）：必须用本局 run_rng —— 否则走全局随机，破坏「同一种子必然一致」的确定性
	var rolled := CardReward.roll(repo, "normal", 1, run_rng)
	var new_id: int = rolled[0].id if not rolled.is_empty() else old_id
	deck_ids[index] = new_id
	if index < deck_mods.size():
		deck_mods[index] = {}       # R181：变形后附魔失效
	pending_relic = -1
	return {"ok": true, "old_id": old_id, "new_id": new_id}

static func smith_deck_card(index: int) -> Dictionary:
	## 事件「鸭鸭工匠」：把卡组中第 index 张卡**变成一张铁栅栏**。
	##
	## 费用口径：产物是「**2 费**铁栅栏」—— R112 起 9072 的**卡面本身就是 2 费**，
	## 所以这里只换 id，费用天然正确，不需要任何覆盖 / 平行表（单一数据源 = cards.json）。
	##
	## ⚠️ 为什么不直接改卡库：卡库是**共享实例**，改它会连本局之外都污染。
	## 纯确定性操作，不走随机源 → 同一种子必然一致。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false, "old_id": 0, "new_id": 0}
	var old_id: int = deck_ids[index]
	deck_ids[index] = FENCE_CARD_ID
	if index < deck_mods.size():
		deck_mods[index] = {}       # R181：变铁栅栏后附魔失效
	pending_deck_edit = ""
	var fc := CardRepo.load_json().get_card(FENCE_CARD_ID)
	return {"ok": true, "old_id": old_id, "new_id": FENCE_CARD_ID,
			"cost": fc.cost if fc != null else 0}

static func duplicate_deck_cards(repo: CardRepo, indices: Array) -> Dictionary:
	## 鸭血（DUCK_BLOOD_RELIC_ID）：把选中的每张卡**各复制一份**加入卡组（原卡保留）。
	## 最多 DUCK_BLOOD_MAX 张 —— 上限在这里强制，界面只是照它显示，超出的 silently 丢弃。
	## 返回 {ok, copied: [{id, name}, ...]}：ok = 至少复制了一张（一张都不选也算正常完成）。
	##
	## ⚠️ **下标必须在复制前全部校验完**：复制是 append，不改已有下标，所以边校验边 append
	## 是安全的；但仍先做一遍去重 + 越界过滤，避免同一个下标被选中两次而复制出两张同样的。
	## 用 `run_rng` ？不需要 —— 纯确定性操作，同一种子必然一致。
	var picked: Array[int] = []
	for v: Variant in indices:
		var i := int(v)
		if i >= 0 and i < deck_ids.size() and not picked.has(i):
			picked.append(i)
	var copied: Array = []
	for i2: int in picked:
		if copied.size() >= DUCK_BLOOD_MAX:
			break
		var id: int = deck_ids[i2]
		var c := repo.get_card(id)
		copied.append({"id": id, "name": c.card_name if c != null else str(id)})
		deck_ids.append(id)     # 副本追加到卡组末尾（原卡位置不动）
		deck_mods.append({})    # R181：复制品无附魔
	pending_relic = -1
	return {"ok": not copied.is_empty(), "copied": copied}


static func deck_distinct_names(repo: CardRepo) -> int:
	## 卡组中**不同卡名**的数量（同名不同 id 只算一种，如骷髅兵 1053/1054/1055）。
	var names := {}
	for id in deck_ids:
		var c := repo.get_card(id)
		names[c.card_name if c != null else str(id)] = true
	return names.size()


static func can_trade_five(repo: CardRepo) -> bool:
	## 二层事件「绝赞五换一」的前提：卡组里至少有 5 种不同名的卡。
	return deck_distinct_names(repo) >= 5


static func trade_five_for_one(repo: CardRepo) -> Dictionary:
	## 二层事件「绝赞五换一」：删除卡组中 **5 张不同名**的卡（每种名各删 1 张），
	## 再把一张「英雄」（9023）加入卡组。
	## ⚠️ 抽样是**按同名张数加权**的：某个名字在卡组里有 k 张，它被选中的概率就是 k 倍
	##（R110；原为等概率）。理由：卡组里堆同名的废牌本就是最大的负担，该让它有机会被换掉。
	## 返回 {ok, removed: [{id, name}, ...], new_id}；不同名的卡不足 5 种 → ok=false 且卡组不变。
	var by_name := {}     # 卡名 -> 该名在 deck_ids 里的所有下标
	for i in deck_ids.size():
		var c := repo.get_card(deck_ids[i])
		var nm: String = c.card_name if c != null else str(deck_ids[i])
		if not by_name.has(nm):
			by_name[nm] = []
		var arr: Array = by_name[nm]
		arr.append(i)
		by_name[nm] = arr
	if by_name.size() < 5:
		return {"ok": false, "removed": [], "new_id": 0}
	# 2026-10-08（R110）：**同名张数越多越容易被选中** ——
	# 原实现是 `run_rng.randi() % bag.size()` 的等概率抽样；改成按「该名在卡组里的张数」加权。
	# 为什么这么设计：卡组里堆了 5 张同名的废牌，本来就是这局最大的负担，
	# 让人家有机会把它换掉才合理；等概率等于让「最该被处理的那张」和「只抽到一张的」一样难被选中。
	# 权重 = **该名张数的平方根**（isqrt(k*1000)），不是线性 k。
	# 为什么不直接用 k：这里抽的是「6 种里选 5 种」，线性权重下只要某名权重够大就**必被选中**
	# （实测权重 4/11 时命中率 0.97）—— 概率弹性消失，玩家感受到的是"锁定"而不是"概率变高"。
	# 平方根把 4 张压成 2 倍于 1 张：重复卡确实更容易被换掉，但不会被抽 5/6 的结构锁死。
	# 用自写的整数平方根 _isqrt(k*1000)（GDScript 没有内置 isqrt，也不是为了跨平台确定性）。
	# ⚠️ 必须走 run_rng（不能全局随机），否则破坏「同一种子必然一致」的确定性。
	var pool_names: Array = by_name.keys()
	var weights: Array[int] = []
	for nm_w in pool_names:
		weights.append(_isqrt(int((by_name[nm_w] as Array).size()) * 1000))
	var picked: Array = []
	for _k in 5:
		var total_w := 0
		for w in weights:
			total_w += w
		# 加权抽一个：落在 weights 的累积区间里 → 命中对应名字 → 从候选池删掉它并同步权重
		var roll := run_rng.randi_range(0, total_w - 1)
		var acc := 0
		var chosen := 0
		for wi in weights.size():
			acc += int(weights[wi])
			if roll < acc:
				chosen = wi
				break
		picked.append(pool_names[chosen])
		pool_names.remove_at(chosen)
		weights.remove_at(chosen)
	var drop_idx: Array[int] = []
	for nm2 in picked:
		var arr2: Array = by_name[nm2]
		drop_idx.append(int(arr2[0]))     # 同名多张时只删其中一张
	drop_idx.sort()
	drop_idx.reverse()                    # 从大到小删，避免下标位移
	var removed: Array = []
	for i2: int in drop_idx:
		var c2 := repo.get_card(deck_ids[i2])
		removed.append({"id": deck_ids[i2],
				"name": c2.card_name if c2 != null else str(deck_ids[i2])})
		deck_ids.remove_at(i2)
		_sync_mods_remove(i2)    # R181：删卡同步附魔下标
	deck_ids.append(HERO_CARD_ID)
	deck_mods.append({})        # R181：新英雄无附魔
	return {"ok": true, "removed": removed, "new_id": HERO_CARD_ID}


## 整数平方根（floor(sqrt(n)))——GDScript **没有**内置 isqrt()，这里自己实现。
## 纯整数运算（不用 sqrtf），保证同一输入永远得同一结果 —— 回归测试依赖这个确定性。
## 算法：从 0 开始每次加 1 直到 x*x > n；n 很小（权重 = 张数×1000 ≤ 几十千），够快。
static func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := 0
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x


static func cell_of(node_id: int) -> Dictionary:
	## 地图房间（按 id 取；id 就是 map_cells 的下标 —— 见 RogueMap.idx）。
	if node_id < 0 or node_id >= map_cells.size():
		return {}
	return map_cells[node_id]


static func current_node() -> Dictionary:
	## 玩家当前所在房间。
	return cell_of(current_node_id)


static func available_nodes() -> Array:
	## 当前房间**有门**的相邻房间 —— 包含已经走过的（可以零消耗原路返回）。
	## 门是双向的，所以「有门」用 doors_between 校验（两边都认），防单向 bug。
	if current_node_id < 0:
		return []
	var out: Array = []
	for nid in RogueMap.neighbor_ids(current_node()):
		out.append(map_cells[int(nid)])
	return out


static func whisper_pick() -> Dictionary:
	## 「鸭之低语」（6010）随机走路的**唯一挑路口** —— 地图场景只负责把它画出来（紫圈）
	## 并走过去，挑选规则本身放这里，纯逻辑即可单测（见 test_engine 的 R194 用例）。
	##
	## ⚠️ 修「新地图上随机走路只走一格就停」（用户 2026-10-16 上报，卡死级）：
	##    `available_nodes()` 里**既有没走过的、也有走过的**邻居（走过的可零消耗原路返回）。
	##    旧实现由地图场景直接从**整池**里随机抽一间 → 抽中「走过的」时 `advance()` 只弹一句
	##    「什么都不会发生」、**不换场景** → 地图场景不会重跑 `_ready`，再没人挑下一步，
	##    而 `_whisper_auto` 又挡着玩家点击 → 队伍就地卡死、流程推不下去（= 只走一格就停）。
	##
	##    现在分三档挑，「随机走路」= 一路穿过走过的旧房间，直到踏进没走过的那间为止
	##    （用户口径「应走到一格没走过的格子为止」）：
	##      ① 隔壁就有没走过的 → 随机挑一间（走进就推进剧情）；
	##      ② 隔壁全是走过的 → 朝**最近的没走过的房间**走一步（BFS 步数表 → 目标 -
	##         1 步的邻居），于是每一步都在**缩短**到未探索区域的距离，不会瞎逛；
	##      ③ 全图都走过了 → 任选一间邻居兜底 —— 不做事，但也绝不把队伍钉死在原地。
	##    只在「当前房间一个门都没有」时返回 {}（生成约束下不会发生）。
	var opts: Array = available_nodes()
	if opts.is_empty():
		return {}
	# ---- ① 隔壁就有没走过的 ----
	var fresh: Array = []
	for c: Dictionary in opts:
		if not cleared_ids.has(int(c["id"])):
			fresh.append(c)
	if not fresh.is_empty():
		return fresh[run_rng.randi() % fresh.size()]
	# ---- ② 隔壁全是走过的：朝最近的没走过的房间走一步 ----
	var ds: Dictionary = RogueMap.steps_from(map_cells, current_node_id)
	var far := 1 << 30
	for c2: Dictionary in map_cells:
		if not cleared_ids.has(int(c2["id"])):
			far = mini(far, int(ds.get(int(c2["id"]), 1 << 30)))
	if far < (1 << 30):
		var ties: Array = []
		for c3: Dictionary in map_cells:
			if not cleared_ids.has(int(c3["id"])) \
					and int(ds.get(int(c3["id"]), 1 << 30)) == far:
				ties.append(int(c3["id"]))
		if not ties.is_empty():
			var target: int = int(ties[run_rng.randi() % ties.size()])
			var dt: Dictionary = RogueMap.steps_from(map_cells, target)
			var near := 1 << 30
			for c4: Dictionary in opts:
				near = mini(near, int(dt.get(int(c4["id"]), 1 << 30)))
			var cand: Array = []
			for c5: Dictionary in opts:
				if int(dt.get(int(c5["id"]), 1 << 30)) == near:
					cand.append(c5)
			if not cand.is_empty():
				return cand[run_rng.randi() % cand.size()]
	# ---- ③ 兜底：全图都走过了（或步数表异常）→ 任选一间邻居 ----
	return opts[run_rng.randi() % opts.size()]


static func known_node(id: int) -> bool:
	## R145 迷雾规则的**唯一判定口**：玩家「看得见这一格里是什么」吗？
	##   * 持有「鹰哨」（6026）→ 全图都看得见（**不写进记忆**：道具拿走就该回到迷雾）；
	##   * **记忆**（`seen_ids`）：只要看清过一次就永久记得（R207，见下）；
	##   * **地标**（`is_landmark_node`）：起点与两个大宝箱 —— 它们不是随机内容，
	##     位置固定、开局就该知道；全图的通路又是可见的，玩家才有办法「朝大宝箱走」；
	##   * 走过的房间（`cleared_ids`）—— 去过就记得；
	##   * 当前房间；
	##   * **当前房间有门的邻居** = 「下一步」能选的这几间。
	## 其余格子在界面上盖一层迷雾（**内容**不可见，但通路（小桥）仍然可见）。
	## ⚠️ 地图页与战斗内总览**必须**都读这个函数 —— 两处各写一份必然走形。
	## ⚠️ **R207 起本函数带副作用**：命中「会留下记忆」的视野时把 id 记进 `seen_ids`。
	##    这是故意的 —— 「揭开过就不还原」只能有一个判定口，而「绘制时问了一句」
	##    本身就是玩家看见了这件事。放进这里，任何新增的可见性来源都不必再去登记一遍；
	##    只想问「按老规则此刻看不看得见」用它下面的 `_memory_visible()`。
	if id < 0 or id >= map_cells.size():
		return false
	if has_relic(EAGLE_WHISTLE_RELIC_ID):
		return true
	if seen_ids.has(id):
		return true
	if not _memory_visible(id):
		return false
	seen_ids.append(id)      # R207：看清过 → 永久记得（只增不减）
	return true


static func _memory_visible(id: int) -> bool:
	## 「看了会记住」的视野来源 —— **不含鹰哨**（那是道具给的瞬时透视，
	## 摘掉鹰哨远处的格子就该重新被雾盖住，test_engine 的 R145 块钉着这一条）。
	## 判定顺序与老的 `known_node` 完全一致，改这里等于改「迷雾规则」。
	if is_landmark_node(id):
		return true
	if current_node_id < 0:
		return false
	if id == current_node_id or cleared_ids.has(id):
		return true
	return RogueMap.neighbor_ids(current_node()).has(id)


static func seed_text() -> String:
	## 种子的展示文本（设置页 / 对战记录共用；开局前 = 「—」）。
	## 玩家拿这串数字就能让别人（或自己）用「下一局种子」复现同一局。
	return "—" if run_seed == 0 else str(run_seed)


static func shuffle_rng(arr: Array) -> void:
	## **按本局随机链洗牌的唯一口（R241）**。
	## `Array.shuffle()` 走的是**全局随机源** —— 同一种子重开 / 续档会洗出不同顺序，
	## 商店库存、附魔三选三这类「进场景时洗一下」的地方最容易被它坑。
	## 算法与 `RogueMap._shuffle` / `FieldState._shuffle_deck` 相同（Fisher-Yates）。
	for i in range(arr.size() - 1, 0, -1):
		var j := run_rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func reveal_known() -> void:
	## 视野记忆的**刷新口**：把此刻所有「看了会记住」的格子记进 `seen_ids`（去重、只增）。
	## 走一步 / 换层 / 读档 / 演示摆位之后调一次，之后无论谁先查询，视野都是最新的。
	## （正常绘制也会通过 `known_node()` 逐个登记，这里只是把「立刻生效」做成显式一步。）
	if map_cells.is_empty():
		return
	for i in map_cells.size():
		if not seen_ids.has(i) and _memory_visible(i):
			seen_ids.append(i)


static func is_landmark_node(id: int) -> bool:
	## 迷雾永远盖不住的地标格：起点 + 两个大宝箱。
	## 「找不到通往大宝箱的路」是 R145 要解决的问题 —— 通路可见 + 目标可见，
	## 玩家才规划得了路线；剩下「路上会遇到什么」才是迷雾要藏的东西。
	if id < 0 or id >= map_cells.size():
		return false
	if RogueMap.is_bigchest(id):
		return true
	return str(map_cells[id].get("type", "")) == "start"


static func can_move_to(node_id: int) -> bool:
	## 从当前房间能否走到目标（必须真的有门 —— 与地图场景的点击判定同源）。
	if node_id < 0 or node_id >= map_cells.size():
		return false
	if current_node_id < 0:
		return true          # 还没出发：允许站上起点
	return RogueMap.doors_between(map_cells, current_node_id, node_id)


static func advance(node_id: int) -> Dictionary:
	## 走进一个房间。返回本次移动的结果：
	##   {"ok", "is_new", "cost", "revealed", "chocolate"}
	## * **没走过**的房间：扣 1 块巧克力 + 标记已走过 +（若是「?」房）揭晓真实类型；
	## * **走过**的房间：零消耗、不结算 —— 按设计「什么都不会发生」。
	## ⚠️ 扣到 0 只置 `boss_pending`，**不立刻开战**：当前房间的内容（可能是一场战斗）
	##    要先结算完，回到地图时才由 map_scene 触发 Boss 战。
	if not can_move_to(node_id):
		return {"ok": false, "is_new": false, "cost": 0, "revealed": false,
				"chocolate": chocolate}
	var is_new: bool = not cleared_ids.has(node_id)
	var cost := 0
	var revealed := false
	if is_new:
		cost = 1
		cleared_ids.append(node_id)
		var c: Dictionary = map_cells[node_id]
		if bool(c.get("hidden", false)) and not bool(c.get("revealed", false)):
			c["revealed"] = true
			revealed = true
		chocolate = maxi(0, chocolate - cost)
		if chocolate <= 0:
			boss_pending = true
		# R223 难度 5「行动力低时疲惫」：巧克力跨过 6 的临界 → 疲惫入 / 出卡组
		# （唯一推导口 sync_fatigue，从 deck_ids 直接判，不加布尔 flag）
		sync_fatigue()
	current_node_id = node_id
	reveal_known()   # R207：走进来之后立刻把新视野记进 seen —— 旧邻居不会因为
	                 #      「已经不是邻居」而重新被雾盖回去（用户口径）
	return {"ok": true, "is_new": is_new, "cost": cost, "revealed": revealed,
			"chocolate": chocolate}


static func complete_current() -> void:
	## 当前房间内容结算完成（战斗胜利 / 休息 / 事件 / 大宝箱）。
	## 进房时已经标过「已走过」，这里是幂等的兜底口。
	if current_node_id >= 0 and not cleared_ids.has(current_node_id):
		cleared_ids.append(current_node_id)
	reveal_known()                # R207：幂等刷新（房间结算完的视野也记进 seen）


static func gold_for_tier(tier: int) -> int:
	## R181：战斗胜利的金币掉落（按关卡分级）。普通简单 20 / 普通困难 30 /
	## 精英简单 50 / 精英困难 65 / Boss 100。未知分级回退 0。
	match tier:
		GameLevels.TIER_NORMAL_EASY: return 20
		GameLevels.TIER_NORMAL_HARD: return 30
		GameLevels.TIER_ELITE_EASY: return 50
		GameLevels.TIER_ELITE_HARD: return 65
		GameLevels.TIER_BOSS: return 100
	return 0


static func gain_gold(amount: int) -> int:
	## 加金币（战斗掉落 / 宝箱）。返回本次实际增加量。
	var before := gold
	gold = maxi(0, gold + maxi(0, amount))
	return gold - before


static func spend_gold(amount: int) -> bool:
	## 花金币（商店购买）。金额不足返回 false，不扣。
	if gold < amount:
		return false
	gold -= amount
	return true


static func boss_level() -> Dictionary:
	## 巧克力耗尽触发 Boss 战时取的关卡。开局已用 run_rng 摇定（boss_pick），
	## 与玩家在地图上看到的 Boss 名牌读**同一份** —— 看到谁就打谁。
	if not boss_pick.is_empty():
		return boss_pick
	return GameLevels.boss_level(current_layer)


# ---- 动态难度（战斗节点不预写关卡，进入时按进度决定） ----

static func on_battle_won(node_type: String) -> void:
	## 战斗胜利后累计同类胜场：决定后续难度（前 2 场简单、之后困难）。
	## 「事件节点遭遇怪物」（node_type = "event"）**同样按普通战斗计数**（R47 修复）：
	## 否则这类战斗永远停在「简单」档，也不消耗「前 2 场简单」的额度 →
	## 玩家可以靠怪物事件反复刷简单战斗。
	if node_type == "battle" or node_type == "event":
		battle_wins += 1
	elif node_type == "elite":
		elite_wins += 1


static func node_layer(node: Dictionary) -> int:
	## 节点所属的层（节点自带 layer；缺省时按本局地图的层处理）。
	return int(node.get("layer", current_layer))


static func next_level(node: Dictionary) -> Dictionary:
	## 进入战斗节点时决定具体关卡 —— 只从「该节点所属层」的关卡池里抽
	## （第一层的关卡不会跑到别的层，别的层的关卡也不会出现在第一层）：
	## 前 2 场普通战斗 = 普通敌人-简单，之后 = 普通敌人-困难；
	## 前 2 场精英 = 精英敌人-简单，之后 = 精英敌人-困难；Boss 固定。
	## 同一分级池内尽量不重复（本局用完一轮后允许循环复用）。
	var layer := node_layer(node)
	match str(node["type"]):
		"battle", "event":
			# event 只在地图事件节点遭遇怪物（event_kind=monster）时走到这里，
			# 按普通战斗处理。
			var tier: int = GameLevels.TIER_NORMAL_EASY if battle_wins < 2 \
					else GameLevels.TIER_NORMAL_HARD
			return _pick_level(_layer_tier_pool([tier], layer))
		"elite":
			var tier2: int = GameLevels.TIER_ELITE_EASY if elite_wins < 2 \
					else GameLevels.TIER_ELITE_HARD
			return _pick_level(_layer_tier_pool([tier2], layer))
		"boss":
			# Boss 可能同层有多个（如第一层：远古虚骨龙 / 恶魔鸭）。
			# 开局（start_run / advance_layer）已用run_rng 摇好并存在 boss_pick，
			# 这里直接用它 —— 地图名牌读的是同一份，**地图上写的就是真会遇到的那只**。
			if not boss_pick.is_empty():
				return boss_pick
			return GameLevels.boss_level(layer)
	return {}


static func _layer_tier_pool(tiers: Array, layer: int) -> Array[Dictionary]:
	## 取该层该分级的关卡池；该层暂时没有这类关卡时退回默认层，
	## 避免地图走进死路（新增层尚未补齐关卡时的兜底）。
	var pool := GameLevels.levels_of_tier(tiers, layer)
	if pool.is_empty() and layer != GameLayers.LAYER_DEFAULT:
		pool = GameLevels.levels_of_tier(tiers)
	return pool


static func _pick_level(pool: Array[Dictionary]) -> Dictionary:
	if pool.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for lvl in pool:
		if not used_levels.has(str(lvl["name"])):
			candidates.append(lvl)
	if candidates.is_empty():
		candidates = pool          # 本局全用过：允许循环复用
	var pick: Dictionary = candidates[run_rng.randi() % candidates.size()]
	used_levels.append(str(pick["name"]))
	return pick


# ---- 卡组 ----

static func add_card(id: int) -> void:
	## 卡牌奖励收下的卡加入卡组。
	deck_ids.append(id)
	ensure_deck_mods()            # R204：附魔列表对齐（原来只 append，槽位不等长时会错位）


static func remove_card(id: int) -> bool:
	## 从卡组里删掉**一张**指定 id 的卡（R200：货物被破坏时用；附魔列表同步）。
	## 返回是否真删到了（卡组里没有该 id 时返回 false）。
	for i in deck_ids.size():
		if deck_ids[i] == id:
			deck_ids.remove_at(i)
			if i < deck_mods.size():
				deck_mods.remove_at(i)
			return true
	return false


static func remove_all_cards(id: int) -> int:
	## R210：从卡组里删掉**所有**指定 id 的卡，返回删掉的张数（附魔列表同步前移）。
	## 「委托完成」兑付后要用它把货物清干净 —— R200 只按张数发了奖励、货物却原封不动
	## 留在 `deck_ids` 里，于是交付完还得一直抽这些 1 费 0 攻的废牌（用户实测报的缺陷）。
	## ⚠️ **必须从后往前删**：正序删会让后面的下标前移，`deck_mods` 的附魔跟着错位
	##    （`remove_card` 只删一张无所谓，这里要批量删，只能倒着走）。
	## ⚠️ 先 `ensure_deck_mods()` 对齐：删一个 key 就少一项，两个列表本来不等长时
	##    会越删越错（smoke 实测 10 vs 4）。
	ensure_deck_mods()
	var removed := 0
	for i in range(deck_ids.size() - 1, -1, -1):
		if deck_ids[i] != id:
			continue
		deck_ids.remove_at(i)
		if i < deck_mods.size():
			deck_mods.remove_at(i)
		removed += 1
	return removed


static func cargo_count() -> int:
	## 卡组里保有的「货物」张数（运送委托 / 委托完成的唯一口径）。
	var n := 0
	for id in deck_ids:
		if id == CARGO_CARD_ID:
			n += 1
	return n


static func delivery_override_kind() -> String:
	## R200：**第二层的第一个事件房**，持有货物时替换成「委托完成」。
	## 返回 "" = 不替换。一次性：delivery_done 结算后置位，本局不再触发。
	if current_layer != GameLayers.LAYER_TWO or delivery_done:
		return ""
	return "delivery_done" if cargo_count() > 0 else ""


static func build_deck(repo: CardRepo) -> Array[CardData]:
	## 按 deck_ids 构建实际牌库（缺定义的 id 跳过）。
	## 一律用卡库**共享实例**，**除非**这一张带商店附魔（R181）—— 附魔要烤进卡
	## （费用 -1 / 伤害 +10 / 次元 +2力+10血 / 保存），不能污染卡库共享实例，
	## 于是对带附魔的那张用 `from_dict(to_dict())` 生成**独立副本**再应用。
	## R214：单卡口径统一收进 `card_with_mod()`（展示层也调它，别再各写一遍复制逻辑）。
	var cards: Array[CardData] = []
	for i in deck_ids.size():
		var cc := card_with_mod(repo, i)
		if cc == null:
			continue
		cards.append(cc)
	return cards


static func card_with_mod(repo: CardRepo, index: int) -> CardData:
	## 卡组第 index 张的**实际卡实例**（带附魔的独立副本 / 没附魔就是卡库共享实例）。
	## R214：牌库面板、地图卡组、商店选卡覆盖层、战斗卡组全部走这一口 ——
	## 否则展示层拿到的是 `repo.get_card()` 的**原卡**，附魔数值与附魔标记一起丢掉
	## （地图卡组 R207 已经这么做了，但牌库面板与商店选卡还是原卡）。
	## 越界 / 卡库缺定义 → null。
	if index < 0 or index >= deck_ids.size():
		return null
	var c := repo.get_card(deck_ids[index])
	if c == null:
		return null
	var mod: Dictionary = _mod_at(index)
	if mod.is_empty():
		return c
	var cc := CardData.from_dict(c.to_dict())   # 独立副本（affixes 等数组也独立）
	_apply_mod(cc, mod)
	return cc


static func ensure_deck_mods() -> void:
	## **附魔列表对齐唯一口（R204）**：`deck_mods` 必须与 `deck_ids` **等长**，
	## 下标一一对应（`build_deck` 按 `_mod_at(i)` 给 `deck_ids[i]` 烤附魔）。
	## ⚠️ 之前 `start_run` 只写 `deck_mods = []`（注释写着「与 deck_ids 等长」却没做），
	##    于是 `enchant_deck_card` 里 `deck_mods[index] = mod` **越界报错** →
	##    「附魔必定失败、钱还照扣」。所有直接改 deck_ids 的地方（演示旗标 / 读档）
	##    都必须过这一口，别只靠 `add_card` 的 append。
	if deck_mods.size() == deck_ids.size():
		return
	if deck_mods.size() > deck_ids.size():
		deck_mods.resize(deck_ids.size())
		return
	while deck_mods.size() < deck_ids.size():
		deck_mods.append({})


static func _mod_at(index: int) -> Dictionary:
	## 取第 index 张卡的附魔（越界 / 未附魔 → {}）。懒对齐，绝不越界崩溃。
	ensure_deck_mods()          # R204：先对齐（演示旗标 / 读档可能留下不等长）
	if index < 0 or index >= deck_mods.size():
		return {}
	var m: Variant = deck_mods[index]
	return m if m is Dictionary else {}


static func enchant_ok(ench_id: String, c: CardData, deck_idx: int) -> bool:
	## 这张卡能否吃这个附魔（R224 从 `shop_scene._enchant_ok` 上移为**唯一口**：
	## 商店选卡页 / 牛奶随机附魔 / 回归测试都走这里，别处再写第二份资格规则）。
	## 每张卡只能有一个附魔 → 已附魔的直接排除。
	if not _mod_at(deck_idx).is_empty():
		return false
	match ench_id:
		"costdown":
			return c.cost > 1 and not c.x_cost
		"damage":
			# R210：**只给技能卡**（用户口径「伤害 +10 限制只能附魔给技能卡」）。
			# R226：再收紧 —— 只给**能直接造成伤害**的技能卡（用户口径「要限制能直接造成
			# 伤害的技能卡」）：治疗 / 抽牌 / 加 buff / 防御类技能本来就不吃这个 +10，
			# 附了也是白花 60 金。判据唯一口 = `CardData.is_damage_spell()`。
			# 技能卡的 `power` 在卡面上**恒为 0**（伤害写死在引擎结算里），附魔把 +10 烤进
			# `power`，由 `GameEngine._spell_dmg()` 消费 → 这张技能卡造成的伤害 +10。
			# 以前判 `power > 0`（= 只给盟友 / 工事），技能卡永远选不中、单位却能白拿 10 攻。
			return c.is_damage_spell()
		"dimension":
			return (c.kind == "盟友" or c.is_fort()) and not c.has_affix("次元") \
					and not c.is_effect()
		"save":
			return true          # 任何卡都能保存
		"opening":
			# R229「起手」：任何卡都能附（第 1 回合必定抽到，单位 / 技能 / 效果都一样）。
			# 「一张卡只能一个附魔」在上面统一拦（`_mod_at()` 非空即拒），这里不重复判。
			return true
	return false


static func enchant_mod(ench_id: String) -> Dictionary:
	## **商店附魔的数值定义唯一口**（R214，原在 `shop_scene._ench_mod`）。
	## 返回的字典就是 `deck_mods` 里存的那一份，`_apply_mod` 按它烤数值。
	## `"id"` 是 R214 新增的：烤完之后卡与「原生就长这样的卡」无法区分，
	## 卡面的附魔标记只能靠它（见 `CardData.ENCHANT_DEFS`）。
	## ⚠️ 加新附魔：这里加一条 + `CardData.ENCHANT_DEFS` 加一条 + `shop_scene.ENCHANTS`
	## 加一条（价格/文案），三处同名 —— smoke 有守卫。
	var m: Dictionary = {}
	match ench_id:
		"costdown": m = {"cost": -1}
		"damage": m = {"power": 10, "note": "伤害 +10"}
		"dimension": m = {"affix": "次元", "power": 2, "health": 10}
		"save": m = {"affix": "保存"}
		# R229「起手」：**不改任何数值**，只记 id —— 抽牌时引擎按 `card.enchant` 认它。
		"opening": m = {}
		_: return {}
	m["id"] = ench_id
	return m


static func enchant_id_of(mod: Dictionary) -> String:
	## 一份 mod 是哪种附魔（`enchant_mod()` 写的 `"id"` 优先）。
	## R181~R213 的老存档 / 老 mod **没有 id** → 按内容反推（附魔效果互不重叠，能反推）：
	## 费用 -1 / 次元(+2力+10血) / 保存 / 伤害 +10（带 note）。
	## 反推不出来（未知形态）→ ""（卡面不画标记，但数值照旧生效）。
	if mod.is_empty():
		return ""
	var eid: String = str(mod.get("id", ""))
	if eid != "":
		return eid
	if int(mod.get("cost", 0)) < 0:
		return "costdown"
	var affix: String = str(mod.get("affix", ""))
	if affix == "次元":
		return "dimension"
	if affix == "保存":
		return "save"
	if int(mod.get("power", 0)) != 0 or str(mod.get("note", "")) != "":
		return "damage"
	return ""


static func _apply_mod(c: CardData, mod: Dictionary) -> void:
	## 把附魔烤进这张（已经是独立副本的）卡。
	if int(mod.get("cost", 0)) != 0:
		c.cost = maxi(0, c.cost + int(mod.get("cost", 0)))
	if int(mod.get("power", 0)) != 0:
		c.power = maxi(0, c.power + int(mod.get("power", 0)))
	if int(mod.get("health", 0)) != 0:
		c.health = maxi(0, c.health + int(mod.get("health", 0)))
	var affix: String = str(mod.get("affix", ""))
	if affix != "" and not c.has_affix(affix):
		c.add_affix(affix)
	# R214：记下附魔种类（烤完数值就看不出来了 —— 卡面标记 / 左栏 / 商店全靠它）
	c.enchant = enchant_id_of(mod)
	# R210：技能卡的具体伤害是写在 `effect_text` 里的死文字（「造成 17 点伤害」），
	# 「伤害 +10」附魔改的是**结算值** → 卡面文字会跟实际伤害对不上。补一行标注，
	# 详情条 / 图鉴 / 牌库都读 `effect_text`，玩家一眼能看到这张卡被附魔过。
	var note: String = str(mod.get("note", ""))
	if note != "" and c.effect_text.find(note) < 0:
		c.effect_text += "\n【附魔】" + note


static func _sync_mods_remove(index: int) -> void:
	## 删卡后同步附魔下标（前移）。越界安全。
	if index < 0 or index >= deck_mods.size():
		return
	deck_mods.remove_at(index)


static func enchant_deck_card(index: int, mod: Dictionary) -> bool:
	## R181：给卡组第 index 张卡附魔（商店）。每张卡只能有一个附魔。
	## 返回是否成功；已附魔 / 越界 / 空 mod 都返回 false。
	if index < 0 or index >= deck_ids.size() or mod.is_empty():
		return false
	ensure_deck_mods()        # R204：先对齐再写（越界就是「附魔必失败 + 白扣钱」的根因）
	if not _mod_at(index).is_empty():
		return false          # 已有附魔 → 拒绝（每张卡只能一个）
	deck_mods[index] = mod
	return true


static func _milk_targets(ench_id: String) -> Array[int]:
	## 卡组里「能吃这个附魔、且尚未附魔」的卡下标（牛奶随机附魔用）。
	var repo := CardRepo.load_json()
	var out: Array[int] = []
	for i in deck_ids.size():
		var c := repo.get_card(deck_ids[i])
		if c == null:
			continue
		if enchant_ok(ench_id, c, i):
			out.append(i)
	return out


static func _apply_milk() -> void:
	## 牛奶（R224）：随机摇 2 种**互不重复**的附魔，各落到一张合规且未附魔的卡上。
	## ⚠️ 随机一律走 `run_rng`（run 层唯一源 → 同一种子重放一致）。
	## 某种附魔此刻没有合规目标（或两种摇重复后池子空了）就跳过 ——
	## 绝不为「附满 2 种」而附到不合规 / 已附魔的卡上。
	var pool: Array[String] = []
	for eid: String in CardData.ENCHANT_DEFS.keys():
		if not _milk_targets(eid).is_empty():
			pool.append(eid)
	if pool.is_empty():
		return
	for _i in MILK_ENCHANTS:
		if pool.is_empty():
			return
		var eid: String = pool.pop_at(run_rng.randi() % pool.size())
		var targets: Array[int] = _milk_targets(eid)
		if targets.is_empty():
			continue
		var idx: int = targets[run_rng.randi() % targets.size()]
		enchant_deck_card(idx, enchant_mod(eid))


static func deck_summary(repo: CardRepo) -> Array:
	## 卡组内容摘要：[{id, name, count}, ...]（按首次出现顺序）。
	var order: Array = []
	var counts := {}
	for id in deck_ids:
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	var out: Array = []
	for id in order:
		var c := repo.get_card(id)
		out.append({"id": id, "name": c.card_name if c != null else str(id),
				"count": counts[id]})
	return out


# ------------------------------------------------------------ 战斗记录

static func record_battle(repo: CardRepo, level_name: String, tier: int,
		win: bool, final_hp: int) -> void:
	## 每场战斗结束调用：记录卡组内容 / 是否失败 / 最终血量，并持久化。
	var entry := {
		"time": Time.get_datetime_string_from_system().replace("T", " "),
		"level": level_name,
		"tier": tier,
		"win": win,
		"final_hp": final_hp,
		"max_hp": max_hp,
		"deck": deck_summary(repo),
	}
	battle_log.append(entry)
	_append_persisted(entry)


static func load_records() -> Array:
	## 读取持久化的全部战斗记录（新在前）。
	if not FileAccess.file_exists(RECORDS_PATH):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	return data if data is Array else []


static func _append_persisted(entry: Dictionary) -> void:
	var all := load_records()
	all.append(entry)
	while all.size() > RECORDS_KEEP:
		all.pop_front()
	var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all, "  "))
