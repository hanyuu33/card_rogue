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
## R762：空 = 标准局；非空 = 每日挑战的 UTC 日历日。rules 入榜名，改计分口径不混旧榜。
static var daily_date := ""
static var daily_rules := 0
## R767：今日修饰的**效果汇总**（`DailyModifiers.fx_of()` 的产物）。空字典 = 标准局。
## 只被下面那几个取数口读取 —— 想加一条修饰，先找到对应的取数口，别在别处直接改数值。
static var daily_fx: Dictionary = {}
static var deck_ids: Array[int] = []         # 当前卡组（卡 id，可重复）
## R181 商店附魔：与 deck_ids **等长**的修饰列表。每个元素是 {}（无附魔）或
## {"cost":-1} / {"power":+10} / {"affix":"次元","power":+2,"health":+10} / {"affix":"保存"}。
## 只改这一张卡（不改卡库共享实例）：`build_deck` 按 mod 生成独立副本再应用。
## 每张卡只能有一个附魔（enchant_deck_card 会拒绝已附魔的卡）。跨战斗、跨层保留。
static var deck_mods: Array = []
## R393：**本局永久的卡牌成长**。键 = 卡 id 的字符串形式（JSON 存档里键会变字符串，
## 所以内存里也统一用字符串，读写不出现 int/string 两套）。值 = {power, health, damage}。
##   * 赏金猎人 9204 / 秃鹰 9206：每场战斗**首次**击杀 → power / health +N；
##   * 猎杀 9205：每次击杀 → damage +N。
## 这是**整轮 run** 的账，跨战斗、跨层、随存档保留；`card_with_mod()` 生成牌库时把它
## 烤进**独立副本**（绝不改卡库原型）。新开一局 / 本局结束清空。
static var card_growth: Dictionary = {}
## R323：牛奶（6028）这次附了哪两张卡 —— 界面拿它播「把附魔标志贴上去」的动画。
## [{card_id, ench}]，界面读一次就清空；`_apply_milk()` 每次重写。
static var milk_anim: Array = []
## R323：「我正停在一场没打完的战斗里」—— {"node": 房间格, "level": 关卡}。
## 进战斗时写、战斗结束清；随存档走。没有它，「在战斗里返回标题 → 继续游戏」
## 会回到地图，而那一格早在进战斗时就被标成「已走过」→ 这场战斗永远打不到。
static var resume_battle: Dictionary = {}
## 卡组费用**一律以卡面为准**（R112）：早前鸭鸭工匠产物靠 `deck_cost_at_index()` 把卡组里的
## 铁栅栏现算成 2 费、而卡面是 0 费 → 「图鉴 0 费 / 卡组 2 费」两处不一致。用户拍板
## 「只保留 2 费」后，直接把 **9072 的卡面改成 2 费**，那套运行时费用改写已整块删除。
## R374（用户口径）：「一个事件在一局里只能被抽出一次」的**账本** ——
## 键 = `event_kind`（whisper / pear / treasure …），值恒 true。
## **跨层共用同一份**（第一层抽过的「遗忘之泉」，第二层不再抽），换层不清空；
## 新开一局清空；随续档走。生成时传给 `RogueMap.generate(..., event_kinds_used)`，
## 池子用尽后那张图的格子降级成一般战斗（`_make_cells` 里唯一处理点）。
static var event_kinds_used: Dictionary = {}
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
## ⚠️ R357：**第三层不适用**（用户口径「第三层不再使用巧克力机制」）——
##    直道的格子一格都不扣（`advance()` 里 cost = 0），Boss 战只由「走到 Boss 格」触发；
##    连带 `boss_pending` 永不置位、`sync_fatigue()` 在这一层直接清掉疲惫卡。
static var chocolate := 0
## R181 金币：本局货币。初始 100；战斗胜利按难度掉落（普通简单 20 / 普通困难 30 /
## 精英简单 50 / 精英困难 65 / Boss 100）；开普通宝箱 +50、大宝箱 +80；商店消费。
## 跨战斗、跨层保留（同一局）；start_run 重置 100、end_run 清 0。advance_layer 不清。
static var gold := 0
static var boss_pending := false             # 巧克力已耗尽，等当前房间结算完就开 Boss 战
## R339：**本层的 Boss 已经打过了**（一层只开一次 Boss 战）。
## 用户报的问题：打完 Boss 回到地图，再走一格 / 继续游戏之后又进同一场 Boss 战。
## 唯一置位口 = `mark_boss_beaten()`（Boss 战胜利时调用）；`start_run` / `advance_layer` /
## `end_run` 复位。两条消费点：`advance()` 不再因巧克力见底重新置 `boss_pending`；
## `map_scene` 的入夜判据也不再看巧克力（打过的层永远不再入夜）。
static var boss_beaten := false
## R339：`end_run()` 置位 —— 本局已经收尾。地图场景的「兜底开新局」据此收手：
## 通关那一场若因奖励面板转去选卡、再回地图，不该在地图上**诈尸**出一个新局。
static var run_finished := false
## ── R473：延迟发卡的挂单（武术大师「学点真本事 / 要学就学绝技」）──
## 每条 = `{"id": 卡 id, "need": 还要几场, "elite": 是否只认精英 / Boss}`。
## 战斗胜利后由 `bump_delayed_cards()` 推进；need 减到 0 的卡**当场加入卡组**，
## 卡名交回调用方（结算面板要播一行「飞踢已加入卡组」）。
## ⚠️ 必须续档：挂单跨战斗、跨层存活，漏存就会在退出重进时凭空消失（道具白拿）。
static var delayed_cards: Array = []
## R473：圣餐已经在**哪一间**休息处结算过，存的是 `sacrament_stay_key()`（层号 + 节点 id）。
## ⚠️ 必须有它：`_ui_main()` 每次重绘都会走休息分支，没有这个标记就会反复回血，
##    退出重进同一间还能无限刷。`-1` = 这一局还没结算过。
## ⚠️ **不能只存 `current_node_id`**：每层地图的 id 都从 0 重新编号，
##    第二层的 12 号与第一层的 12 号是两间不同的篝火 —— 只比 id 会让第二层的篝火
##    因为「上一层同一编号已经结算过」而整层不回血（R661 修）。
static var sacrament_node: int = -1
## R781「温暖」：**本间火堆**已经用掉的选项份数（默认三选一 → 1 份；修饰下 → 2 份）。
## 与圣餐共用同一个房间键（层号 × 10000 + 节点 id）—— 退出重进同一间不会白刷第二份。
## `rest_pick_node == -1` 表示这一局还没在火堆上记过账。
static var rest_pick_node: int = -1
static var rest_pick_used := 0
## R234 止血绷带（6029）：本层累计的「下次休息额外回血」点数。换层 / 开新局 / 结束局清零。
static var bandage_pending := 0
static var pending_level: Dictionary = {}    # 即将进入的战斗关卡（地图 → 战斗）
static var pending_node: Dictionary = {}     # 即将进入的地图节点（地图 → 休息/事件）
static var reward_context := ""              # 奖励来源："battle" / "event" / ""（演示）
## R757 遥测：本局最终落在哪（"win" / "lose" / ""）。`mark_run_won/lost` 落章时写，
## `end_run()` 读它并交出一条 `run_end` —— 那两处都已经知道结果，不必再传参绕一圈。
static var _tele_outcome := ""
static var reward_type := "normal"           # 奖励类型："normal" / "boss"（概率构成不同）
static var pending_event := ""               # 即将进入的事件子类型："treasure" / "whisper"
static var pending_deck_edit := ""           # 事件「遗忘之泉」的待办卡组操作："" / "delete"（删一张卡）
static var reward_kinds: Array[String] = []  # 本次卡牌奖励的卡类限制（空 = 不限制；如 ["效果","技能"]）
## R305：有「刚入队、还没给玩家看过」的奖励 → 下一次进地图补弹一次奖励悬浮窗。
## 用途 = 卡片商人的「以卡易物」：奖励在 deck_edit 场景里入队，那里没有奖励面板。
## ⚠️ 一次性开关（地图弹过就置回 false）；不参与存档 —— 丢了只是少看一次弹窗，奖励还在队列里。
## R307 雕像（6039）：累计「已使用多少张牌」，满 10 张换 1 点费用。
## **跨回合、跨战斗累计** → 存在局状态里（随存档走）。
static var statue_charge := 0
const RELIC_STATUE_ID := 6039
const RELIC_SACRAMENT_ID := 6038
## R473（用户口径）：圣餐现在按「**到达**篝火处回复 50% 最大生命」结算 —— 见
## `sacrament_arrive()`，不再挂在「休息」按钮上（休息仍按档位百分比回血）。
const SACRAMENT_ARRIVE_PCT := 0.5
const STATUE_EVERY := 10

## R311 不锈钢盆（6041）：剩余计数（0 = 没有 / 已归零）。
## **跨战斗累计**（10 点 = 一整局的总量）→ 存在局状态里、随存档走。
## 消费点 = 战斗内 `GameEngine._damage_player`（代替承伤）与商店 `_pay()`（抵账）。
static var basin_charge := 0
const BASIN_RELIC_ID := 6041
const BASIN_MAX := 10

## R362 风妖精（6042）：一回合打出第 5 张牌 → 对所有敌人 4 伤。
## 玩家得看得见「还差几张」，所以在道具名旁写「已打出 / 需要」。
## ⚠️ 计数本身**不进这里** —— 唯一真源是 `FieldState.self_card_plays`（每回合清零），
##    由战斗界面把它当参数传进来（`relic_display_name(id, plays)`），
##    这里只负责排版。两个常量必须与 `GameEngine.WIND_FAIRY_RELIC_ID / WIND_FAIRY_AT`
##    一致（test_engine R362 段有对账）。
const RELIC_WIND_FAIRY_ID := 6042
const WIND_FAIRY_NEED := 5

## R311 水晶骰子（6040）：持有期间「除起点/大宝箱/右上角商店/篝火外」全是「?」房；
## 在「?」房进战斗时掷骰，前 X 回合每回合 +1 费（X = 点数，见 GameEngine）。
const DICE_RELIC_ID := 6040

## R314：两件**传奇**道具。
##   储物箱（6044）：回合结束不弃手牌（纯战斗内，判定在 `GameEngine.end_turn`）；
##   lucky 7（6045）：每 7 个**我方回合**（跨战斗累计）→ 该回合免疫所有 HP 伤害 + 技能额外 7 伤。
const STORAGE_RELIC_ID := 6044
const LUCKY7_RELIC_ID := 6045
const LUCKY7_EVERY := 7
## lucky 7 的**跨战斗**计数：每开始一个我方回合 +1（`lucky7_tick()`），
## 满 7 的倍数那一回合生效。随存档走（run_save）。
static var lucky7_turns := 0

## R810 新月耳饰（6081，一般档）：每 `CRESCENT_EVERY` 场战斗，在**那场的第一回合** +1 费用。
## 计数只记「拿着这件道具之后开打的战斗」，跨战斗保留、随存档走（run_save）。
## ⚠️ 推进口唯一 = `GameEngine._begin_turn()` 的 `turn_number == 1` 分支里调 `crescent_tick()`
##    —— 那里每场战斗只成立一次。别在战斗开始处再加一次，否则一场数两下。
const CRESCENT_EARING_ID := 6081
const CRESCENT_EVERY := 3
static var crescent_battles := 0

## R314 传奇掉落概率：**5% × 当前层数**；大宝箱翻倍。
## 层数取 `current_layer`（第一层 1 / 第二层 2 …），所以第一层 5%、第二层 10%；
## 大宝箱第一层 10%、第二层 20%。上限 100%（层数继续加也不会溢出）。
const LEGEND_CHANCE_PER_LAYER := 0.05
const BIGCHEST_LEGEND_MULT := 2.0
## R390（用户口径）：**Boss 关卡**掉传说的概率 ×3 —— 第一层 15%、第二层 30%、第三层 45%。
## 与「大宝箱翻倍」正交：Boss 战不算大宝箱，两者不会叠在同一次判定上。
const BOSS_LEGEND_MULT := 3.0

static var reward_popup_pending := false
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
static var battle_wins := 0                   # 本层已胜利的普通战斗数（前 2 场简单）
static var elite_wins := 0                   # 本层已胜利的精英战斗数（R778 起只作统计，不再切强弱档）
# R530 通关结算：上面两个是**本层进度**（换层清零，用来切简单/困难档），
# 结算界面要的是**整局总数** —— 另开三个只增不清的累计量。
static var total_battle_wins := 0             # 本局累计普通战斗胜场（换层不清）
static var total_elite_wins := 0              # 本局累计精英战斗胜场（换层不清）
## 本局玩家造成的**总伤害**（所有来源：单位 / 技能 / 效果 / 直击 HP）。
## 口径 = 实际扣掉的血（护盾、减伤之后），不是账面攻击力 —— 记账口在引擎的三个落地处。
static var total_damage := 0
## 通关结算快照（`battle_scene` 在最后一层 Boss 打完时填，结算场景读）。
## 独立放一份：`end_run()` 之后结算页还得能读（页面自己先复制，别指望局状态还在）。
static var run_summary: Dictionary = {}
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
#       R358：**每层最多发一次**（`fatigue_granted_layer` 记账），删掉 / 洗掉后同层不再补。
#   6 = 敌人更加凶猛（除原本 0 攻工事外，所有敌人攻击 +1）
#   7 = 金钱减少（初始金钱 150 → 100，后续每层也都是 100）
#   8 = 行动力降低（每层初始巧克力 12 → 11）
#   9 = 虚弱（最大生命 ×80%，截断取整）
#   10 = 精英出现增多（R380）：继承 0~9 全部 debuff，另外「?」房不再刷商店（每层商店
#        固定 2 间 + 右上角 1 间）、明房与「?」房两条途径的精英出现概率统一 ×1.3（约 +30%）。
#   11 = 第三层上锁（R543）：要凑齐完美螺钉 / 生命之种 / 屠戮匕首三样信物才开门。
#   12 = 昂贵（R794b）：商店商品售价 +40%，**信物除外**（信物 = 上面那三把钥匙）。
# 档位只在角色选择界面改，不属于 run 状态（end_run / start_run 都不动它）。
static var difficulty: int = 0
const DIFFICULTY_COUNT := 13
const DIFFICULTY_NAMES: Array[String] = ["轻松", "微恙", "严酷", "顽强", "稀缺",
		"疲惫", "凶暴", "贫瘠", "匆忙", "虚弱", "噩梦", "上锁", "昂贵"]
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
	"精英出现增多",
	"第三层上锁，获取三个信物以解锁第三层",
	"商店商品售价 +40%（信物除外）",
]
## R224：全局规则「除到达新的一层外不能回复 HP」→ 战斗胜利回血全档位归零。
## 表保留 12 长度（回归钉死口径；将来若再加「某档回血」类 debuff 改这张表即可）。
const DIFFICULTY_BATTLE_HEAL: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # 战斗胜利回复量
## R237：恢复篝火回血 —— 难度 0 = 40%，1 档起 = 25%（即原始设计；R224 曾按用户要求归零，现加回）。
## ⚠️ 战斗胜利回血（DIFFICULTY_BATTLE_HEAL）**仍为 0**：用户只要求篝火能回血，不恢复被动自动回血。
const DIFFICULTY_REST_PCT: Array[float] = [0.40, 0.25, 0.25, 0.25, 0.25, 0.25,
		0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25]                             # 休息回复百分比

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
## R380（用户口径）：「当前难度 10 还没有新增效果，做成精英出现增多 —— 每层商店数量
## 调整为固定 2 个（不算右上角），各种途径出现精英的概率上调约 30%」。
##   * 「?」房不再刷出商店 → 每层商店恒为「右上角固定 1 间 + 随机 2 间」；
##   * 明房与「?」房两条途径的精英出现概率统一 ×1.3（约 +30%）。
## ⚠️ 唯一消费点 = `RogueMap._weighted_far()`（出现概率）/ `RogueMap._unknown_table()`
##    （「?」房权重表）—— 别在地图生成之外再乘一次，否则会被重复加权。
const DIFF_ELITE_FROM := 10        # 10 档起「精英出现增多」
const DIFF_ELITE_MUL := 1.3        # 精英出现概率乘数（≈ +30%，扣除法见 _weighted_far）
## R778：强弱精英判据 —— 当前巧克力 <= 5 一定进强精英，否则一定进弱精英。
## 三层精英不参与（第三层固定抽第二层精英困难池，见 next_level）。
const ELITE_STRONG_CHOCO_MAX := 5
## R543（用户口径）：难度 11「上锁」—— 第三层需要凑齐三样信物才能进入。
## ⚠️ 只有难度 ≥ 11 才需要信物；难度 0~10 下第三层照常开放（用户明确「任何难度都开放第三层」）。
const DIFF_LOCK_FROM := 11         # 11 档起「第三层上锁」
## 三样信物（解锁第三层所需的信物）：完美螺钉 / 生命之种 / 屠戮匕首。
const SCREW_RELIC_ID := 6061       # 完美螺钉（第二层 Boss 掉落，替代一份普通卡牌奖励）
const SEED_RELIC_ID := 6062        # 生命之种（大宝箱二选一）
const DAGGER_RELIC_ID := 6063      # 屠戮匕首（商店第三排额外售卖）
const KEY_RELIC_IDS: Array[int] = [SCREW_RELIC_ID, SEED_RELIC_ID, DAGGER_RELIC_ID]
## R794b（用户口径）：难度 12「昂贵」—— 商店里卖的东西一律 +40%，**信物除外**。
## ⚠️ 唯一消费点 = `shop_scene._shelf_price()`：价签 / 悬停详情 / 扣款 / 遥测
##    四个口共用一个倍率，谁都不许自己乘 1.4。
##    信物目前只有第三行那条「屠戮匕首」—— 由调用方传 `key_relic = true` 跳过加价。
const DIFF_SHOP_PRICE_FROM := 12   # 12 档起「商店涨价」
const DIFF_SHOP_PRICE_MUL := 1.4   # +40%
## 诅咒卡「疲惫」（9149）：1 费诅咒，打出无效果；**在手里时**所有技能卡费用 +1。
const FATIGUE_CARD_ID := 9149
## R358：疲惫卡的**发放记账** —— 最近一次发放在哪一层（-1 = 本局还没发过）。
## 用户口径「确保每层只会获得一次疲惫」：玩家把疲惫删掉、或巧克力涨回 6 把它洗掉之后，
## 同一层内不再补第二张；`start_run` / `advance_layer` 重置成 -1（新层重新拥有一次机会）。
## ⚠️ 必须进存档（run_save）：否则「删疲惫 → 存档 → 读档」会被 sync_fatigue 立刻补回来。
static var fatigue_granted_layer := -1

# ---- 本局种子：run 层唯一随机源 ----
static var run_seed: int = 0                 # 本局种子（run 层全部随机由它派生；同一种子重跑必然一致）
static var run_rng := RandomNumberGenerator.new()   # 本局随机源（地图/道具/关卡/掉落/五换一）


static func seed_of(category: String, index := 0) -> int:
	## **分类种子**的唯一派生口（R312）—— 由「全局 `run_seed` + 分类名 + 序号」纯函数算出。
	##
	## 为什么需要它：`run_rng` 是一条**顺序链**，谁先抽谁后抽会互相影响。
	## 于是「某个子系统多抽了一个随机数」就会把后面所有分类的结果整体推歪
	## （典型：拿了水晶骰子去重摇地图 → 这一局之后的所有掉落/关卡都变了一遍）。
	## 分类种子把这种耦合切断：同一 (run_seed, category, index) **永远**得到同一个值，
	## 且**不消耗** `run_rng` 的状态。
	##
	## 保证（回归里逐条钉住）：
	##   ① **确定性**：同一局同一分类，多次调用结果相同；跨进程重开同一 seed 也相同；
	##   ② **唯一性**：不同 `category` / 不同 `index` 得到不同值（31 位混洗，实际不碰撞）；
	##   ③ **无关性**：与 `run_rng` 当前状态无关（不读不写它）。
	##
	## 实现：FNV-1a 打分类名 → 折进 run_seed → 线性同余 + xorshift 混洗。
	## ⚠️ 全程用 `& 0x7FFFFFFF` 压在 31 位：GDScript 的 int 是 64 位有符号，
	##    不夹住的话乘法会溢出成负数（种子不要求符号，但负数让断言/日志难对）。
	## 消费点：`dice_map_rng()`（水晶骰子的重摇流）；后续新子系统请**一律走这里**，
	##          不要再往 `run_rng` 上加新的抽取点。
	var h := 2166136261 & 0x7FFFFFFF
	h = (h ^ (run_seed & 0x7FFFFFFF)) & 0x7FFFFFFF
	for i in category.length():
		h = (h ^ category.unicode_at(i)) & 0x7FFFFFFF
		h = (h * 131) & 0x7FFFFFFF
	h = (h * 1103515245 + 12345 + index * 2654435761) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	h = (h * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return h
## R261：对玩家展示的种子 = **10 位大写字母 / 数字**（标准 base36：0-9 在前、A-Z 在后，
## 所以补位字符是 0、字母位值是 10~35）。
## 与 `run_seed` 一一对应（`seed_text_of` / `seed_value_of` 互逆）—— 玩家抄这 10 位就能
## 复现同一局；内部仍用 int 播种（存档 / 对战记录 / 测试断言都是 int）。
## 0 仍是「没有种子 / 随机」的哨兵 → 全 0 的码按非法处理（`seed_value_of` 返回 -1）。
const SEED_LEN := 10
const SEED_ALPHABET := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# ---- 道具 ----
static var relics: Array[int] = []           # 已拥有的道具 id（跨战斗保留）
## R543：**信物**（解锁第三层所需的信物）—— 与道具（relics）**分开记账**：
##   * 不进道具栏、不占道具位、不参与任何道具效果；
##   * 三样 = 完美螺钉 6061 / 生命之种 6062 / 屠戮匕首 6063（`KEY_RELIC_IDS`）；
##   * 在地图页（及查看小地图时）持续显示小图标。
static var key_relics: Array[int] = []       # 已获得的信物 id（跨战斗保留）
## R367：**已耗尽的道具**（不锈钢盆计数归零 / 洞窟绳逃跑用掉）——
## 不从 `relics` 里删掉，而是留在道具栏里**画灰**：记录页的「最终道具」才能看出
## 这一局用过它（用户口径：「方便对战记录统计」）。
## ⚠️「还有没有效」的唯一判据是 `has_relic()`（它排除这里）；批量读 `relics`
##    的地方都是**展示**，别拿 `relics.has()` 当生效判定。
static var spent_relics: Array[int] = []
## R367：本局**打过的 Boss**（`{layer, key, name}`，按层去重，顺序 = 击破顺序）。
## 记录页据此写出「第 1 层 · 鸭之暗面」这种每层战果。
static var boss_kills: Array = []
## R352：本局的**禁卡快照**（开局那一刻从 `ProfileData.bans_of(职业)` 复制一份）。
## 用户口径：「禁用可以随时修改，但是当前正在进行的战斗只遵照开始前设置的禁用」——
## 所以局内奖励池只认这一份，局外改禁卡表**不影响**进行中的这一局。
static var run_bans: Array[int] = []
static var skipped_relics: Array[int] = []   # 奖励掉落里被「跳过」的道具 id：本局后续不再随机出来
static var relic_choice: Array[int] = []     # 起点三选一的候选（选定后清空）
static var pending_relic := -1               # 等待卡组选择的即时道具 id（-1 = 无）
static var pending_relic_drop := -1          # 精英/Boss 掉落的道具 id（-1 = 无，领取后清空）
static var pending_fly := false              # R555 飞行器：待在地图上选一格传送（回地图进选格模式）

# ---- R663：陷阱栏（消耗品，杀戮尖塔药水口径）----
## 与道具 `relics` **完全分开**：道具是本局全部、耗尽画灰且无限堆叠；
## 陷阱是定长 3 槽、用了就清空，商店靠「还剩几个空位」判断能不能买。
## ⚠️ 绝不写进 `relics` / `GameEngine.self_relics`：`relic_highlight()` 的闸门是
##    `self_relics.has(id)`，混进去会串高亮（独立 7001+ 段也是为了这个）。
const TRAP_SLOTS := 3
## R754 石头（事件「奇异雕像」的摧毁选项给的那种工具）。放在这里是因为
## `fill_toolbar_with_stones()` 要用它，而 traps.json 的 7012 是同一件东西。
const STONE_TOOL_ID := 7012
static var traps: Array[int] = [-1, -1, -1]   # -1 = 空槽；其余 = traps.json 的 id
## R694（用户口径「任何战斗都有 10% 概率掉落工具」）：**任何**战斗胜利都摇一次这个概率。
## `tool_roll_seq` = 本局第几次战斗结算，只用来派生随机种子 —— 随存档一起走，
## 续档之后接着往下数，同一条种子不会被摇第二遍。
const TOOL_DROP_CHANCE := 0.10
## R796 兔脚（6076，一般档）：战斗胜利金币 +RABBIT_FOOT_GOLD、战斗掉落工具的概率
## **加算** RABBIT_FOOT_TOOL_DROP（用户口径「＋10%（加算）」→ 10% → 20%，不是 ×1.1）。
## 判据走 `RunState.has_relic()`（静态读全局），别用引擎的 `self_relics` 快照。
const RABBIT_FOOT_RELIC_ID := 6076
const RABBIT_FOOT_GOLD := 10
const RABBIT_FOOT_TOOL_DROP := 0.10
static var tool_roll_seq := 0
## R745 工具箱发工具的独立序号 —— 与 `tool_roll_seq` 分开，否则「多拿一个工具」
## 会把战斗掉落的 10% 摇点整体推歪（同 R312 的分类种子口径）。随存档一起走。
static var toolbox_tool_seq := 0
## R752 快送鸭 7010 的独立序号：一次要连抽 3 件，与上面两条都分开（同一条口径：
## 效果里的随机数不许推动地图 / 掉落 / 工具箱的随机流）。
static var tool_deliver_seq := 0
## R754 事件「奇异雕像」的祭拜祝福：**接下来这么多场战斗必定掉工具**（与 10% 概率
## 各自独立 —— pledge > 0 时那一场不看概率、直接掉一件，然后 -1）。
## 只在 `roll_battle_tool_drop()` 里消耗，别在别处改（唯一口）；随存档一起走。
static var tool_drop_pledge := 0

# ---- R119：待领奖励队列（奖励悬浮窗的数据源）----
## 「获得奖励」不再当场发放，而是**先入队** → 由 RewardPanel 悬浮窗逐项展示。
## 玩家自行决定查看顺序，看过可以退回列表再看、再领取；领取 / 放弃过的那一条置灰。
## 每项字典（kind 决定字段）：
##   {"kind": "relic", "id": int, "state": String}
##   {"kind": "tool", "id": int, "state": String}     # R694：战斗掉落的工具（7001~7006）
##   {"kind": "cards", "type": String, "kinds": Array[String],
##    "candidates": Array[int], "picked": int, "state": String}
## ⚠️ 只在 start_run 清空（**end_run 故意不清**）：通关那一场的奖励是「打完才弹窗看」的，
##    end_run 在结算面板里就跑了，此时清掉会让最后一击的战利品凭空消失。
static var pending_rewards: Array = []
# ---- R390：商店会话 —— 离开后**在下一次移动之前**可以重进，店内原样 ----
## 存档键 = **地图格子 id 的字符串**（JSON 的键只能是字符串）。
## 值 = {"row1": [[card_id, sold], ...],
##       "row2": [[ench_id, sold], ...],
##       "row3": [[key, sold], ...]}
## 为什么必须存在局状态里而不是场景自己拿着：一换场景就没了，而重进**不能重摇**
## —— 重摇会花掉 run_rng 的随机数，同一份存档读两次就是两家不同的店（确定性直接破）。
static var shop_states: Dictionary = {}
## 允许重进的商店格（-1 = 没有）。`advance()` 走出这一格就失效。
## 用户口径是「在下一次移动之前能重新进」—— 挪过位置就不该再开门。
static var shop_revisit_id := -1
const REWARD_PENDING := "pending"    # 待领（悬浮窗里正常显示）
const REWARD_CLAIMED := "claimed"    # 已领取（置灰）
const REWARD_SKIPPED := "skipped"    # 已放弃（置灰）
static var duck_revive_chance := 100         # 叠加态的鸭（6013）：当前复活概率（每次复活 -25）

# 事件道具 id
const WHISPER_RELIC_ID := 6010   # 鸭之低语（事件节点获得）
## 鹰哨（R128 奖励道具）：地图上**所有房间的门全部可见**（含没走过的房间）。
## 消费方只有 map_scene（决定是否画未访问房间的门），引擎侧不参与。
const EAGLE_WHISTLE_RELIC_ID := 6026
## R743（用户口径「烤肉从自动使用的道具，改成主动使用的工具（需要有栏位才能获取）」）：
## 烤肉现在是 **traps.json 的 7007**（使用型工具，heal_pct 25），不再是道具 6011。
## 获取口只有一个：休息处烤制（`take_barbecue()`）—— 工具栏是**定长 3 槽**，
## 所以「带一份烤肉在身上」= 占掉一个栏位；满栏就烤不了，得先用掉 / 丢掉别的工具。
const BARBECUE_TOOL_ID := 7007
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

# ================= R305：卡片商人 / 湖中仙女 =================
const MERCHANT_MIN_COST := 5      # 卡片商人「以卡易物」收的卡：**5 费及以上**
const BIGCHEST_GOLD := 80         # 大宝箱里的金币（与地图上的大宝箱房同一个数）
const VENDOR_GOLD := 100          # 卡片商人「随机折价」给的金币
const LAKE_INITIAL_RARITY := 3    # 旧口径「谎言只删初始卡」：R488 起谎言改成删任意非诅咒卡，常量留给旧断言
const LAKE_EPIC_RARITY := 2       # 湖中仙女「诚实」给的卡：稀有度 2 = 史诗
const CURSE_RARITY := 6           # 稀有度 6 = 诅咒（「折价」与「谎言」都不碰这些）
## R488（用户口径）：湖中仙女「谎言」= **卡组里随机一张牌**（排除诅咒），
## 并且**进门就摇定**、把卡名写进按钮 —— 所以摇定结果要记下来。
## 为什么存**卡组下标**而不是卡 id：同名卡在卡组里可能一张带附魔一张没有，
## 按 id 随机等于「删掉随便哪一张同名的」，界面写「失去『铁栅栏』」而实际删的是另一张。
## 存下标 = 锁到**具体那一个实例**（`card_with_mod()` 能把它连附魔一起拿出来展示）。
## 随存档（run_save）：回标题 → 继续 → 重进本房，显示的必须还是同一张。
static var lake_victim := -1

# 事件「运送委托」（R200）的货物卡（cards.json）：3 费工事 0/6/0/0（R280 由 1 费上调），
# **被破坏时从卡组中删除**（引擎 `_destroy` 的货物分支是唯一口）。
# rarity 5（事件）→ 不进奖励池，只能从「运送委托」事件获得。
const CARGO_CARD_ID := 8065
## R200：「委托完成」（第二层第一个事件房，持有货物时替换）是否已结算 ——
## **一次性**（每个保有货物抽奖一次，结算后本局不再触发）。
## start_run / end_run 复位；advance_layer 故意不清（第二层只进一次）。
static var delivery_done := false

# 即时道具
const SOURCE_POWER_ID := 6002     # 源数之力（改造卡组中的一张卡）
const FORGET_POTION_ID := 6004    # 失忆药水（删掉卡组里的一张卡）
const SOURCE_POWER_HP_COST := 5   # 源数之力的代价：失去 5 点最大生命

# R224 新道具：苹果（6027，奖励池）—— 获得时**立即 +7 最大生命，并回复 20% 最大生命值**。
# R445（用户口径）：14 → 7；R756（店长口径）：「回复满」改成**回复 20% 最大生命值**——
# 它不再是一条「免费满血」，而是一口实打实的补给。
# 全局 HP 规则「除到达新的一层外不能回复 HP」下，它是主动道具口径的回血手段
# （R743：烤肉已改成工具，剩下的主动回血手段是黄桃罐头 / 自愈这类道具与卡牌；
#  被动自动回血已全部移除）。
const APPLE_RELIC_ID := 6027
const APPLE_MAX_HP := 7
const APPLE_HEAL_PCT := 0.20   # R756：回复「最大生命」的 20%（原来是一次回满）
# R446 烟斗（6055，事件「雪豹出现」选项 1）—— **一次只给一场战斗**的首回合加成。
# 「点着 / 熄灭」只有一个状态位（`pipe_ready`），跨战斗、随存档：
#   * 拿到道具时点着；战斗首回合结算完就熄灭；每次路过篝火（休息处）重新点着。
# ⚠️ 引擎那边还要求 `self_relics.has(PIPE_RELIC_ID)` —— 状态位只表示「亮着」，
#    没有道具时不生效（道具暂时没有被移除的机制，但别留这个口子）。
const PIPE_RELIC_ID := 6055
static var pipe_ready := false
# R244 新道具：行囊（6030，初始道具池）—— 获得时 **+100 金币**，并把一张
# 「木栅栏」（工事 2 费 0/6，8001）加入卡组。属于「即时」类，`gain_relic` 里当场结算。
const PACK_RELIC_ID := 6030
const PACK_GOLD := 100
const PACK_CARD_ID := 8001        # 木栅栏
# R745 新道具：工具箱（6068，初始池）—— **立即**获得一个随机工具，之后每进入新的一层
# 再获得一个。两个发放点都走 `grant_random_tool()`（池子 = `TrapRepo.random_traps()`，
# 满栏转进待领奖励队列）。
const TOOLBOX_RELIC_ID := 6068
# R245 新道具：勇气徽章（6031，初始池）—— 战斗内生效，判定与数值都在引擎
# （`GameEngine.COURAGE_RELIC_ID` / `COURAGE_TURNS`；R372 起精英 / Boss 都只给首回合）。
const COURAGE_RELIC_ID := 6031
# R245 新道具：陶罐（6032，初始池）—— 获得时随机 2 件奖励道具 + 一张「罐子」诅咒进卡组。
const POT_RELIC_ID := 6032
const POT_RELIC_COUNT := 2
const JAR_CURSE_ID := 9157        # 罐子（诅咒卡；R632 删了工事召唤物 9158）
# R246 二层起始道具：兼修（6033）—— 每回合 +1 费，且奖励/商店不再按职业过滤。
# 判定只看「持有这件道具」（不去存一个 bool），存档 / 换层 / 读档都不用额外照顾。
const VERSATILE_RELIC_ID := 6033
# R246 二层起始道具：附魔大师（6034）—— 每次在篝火处休息，随机附一个合规附魔。
const ENCHANT_MASTER_RELIC_ID := 6034
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
# R341 惊奇盒子（6047，第一层初始池）：获得时把一张「惊奇盒子」（9179，工事 1 费 0/1）
# 加进卡组 —— 与行囊 6030 同一条路（`add_card` 内部会 ensure_deck_mods()）。
# 卡片机制「被攻击时使攻击者下回合眩晕」在引擎（`GameEngine.STUN_BOX_TRAIT`）。
const BOX_RELIC_ID := 6047
const BOX_CARD_ID := 9179
# R341 洞窟绳（6048，第一层初始池）：Boss 以外的战斗可以逃跑，逃跑即失去道具。
# 判据只留一处 `can_use_cave_rope()` —— 战斗界面的按钮显隐与真正的逃跑结算共用它。
const CAVE_ROPE_RELIC_ID := 6048
# R830 新道具：首饰盒（6088，初始池）—— 获得时随机一张**史诗卡**加入卡组。
# 与湖中仙女·诚实共用同一条抽卡口（LAKE_EPIC_RARITY = 2 = 史诗）；随机源走 run_rng。
const JEWELRY_BOX_RELIC_ID := 6088
# R342 采集刀（6050，**传奇**奖励池）：「战斗后额外获得一份卡牌奖励」。
# 唯一消费点 = `queue_battle_card_rewards()` —— 战斗胜利的卡牌奖励只从那里入队。
const HARVEST_KNIFE_RELIC_ID := 6050
const HARVEST_KNIFE_EXTRA := 1
# R342 火柴（6051，一般奖励池）：卡牌奖励界面可以「刷新」重摇一组候选，一共 3 次。
# 计数**跨战斗累计**（一局的总量）→ 存在局状态里、随存档走（与不锈钢盆 6041 同口径）。
# 用完 3 次道具仍留在道具栏（只是不再生效），免得「用完自动消失」把图鉴记录也抹掉。
const MATCH_RELIC_ID := 6051
const MATCH_CHARGES := 3
static var match_charge := 0
# R440 暗动力（6054，**传奇**奖励池）：用户口径 ——「你无法再跳过卡牌奖励（不可放弃，
# 必须拿取一张卡才能关闭奖励界面）或在商店删除卡牌。每回合开始时多抽一张牌。」
# 三个效果的落点，一个判据口各管一条：
#   ① 多抽 1 张 → 引擎 `_begin_turn()` 的 `extra_draw`（与鸭蹼 / 冰淇淋同一套口径）；
#   ② 不能放弃卡牌奖励 → `skip_pending_reward()` 拒绝 kind=="cards"，界面只是照此置灰；
#   ③ 商店不能删卡 → `shop_delete_allowed()`，商店的「删除一张卡」问它。
# ⚠️ 月亮的删卡奖励（kind=="deck_delete"）**不在**管辖范围 —— 那是战斗奖励里的卡组操作，
#    不是商店服务，卡面也没写它。
const DARK_POWER_RELIC_ID := 6054


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
	return difficulty_name_at(_diff())


static func difficulty_name_at(d: int) -> String:
	## 指定档位的名称。`d` 越界（旧版本记录 / 脏数据）→ 钳到合法区间，绝不越界取数组。
	return DIFFICULTY_NAMES[clampi(d, 0, DIFFICULTY_COUNT - 1)]


static func difficulty_label(d: int = -1) -> String:
	## R795：「数字 + 名称」（例 `12 昂贵`）—— 结算副标题 / 对战记录共用的**唯一口**。
	## 数字就是角色选择界面档位框里的那个 0~12，名称紧跟其后，玩家不用再自己对照。
	## `d < 0` = 当前档；越界 / 缺失由 `clampi` 兜住 —— **兼容旧版本记录文件**就靠这一句：
	## 老记录只存了档位数字（`difficulty`），名称一律现推，不落盘也不怕以后改名。
	var i := _diff() if d < 0 else clampi(d, 0, DIFFICULTY_COUNT - 1)
	return "%d %s" % [i, DIFFICULTY_NAMES[i]]


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
	if d >= DIFF_ELITE_FROM:
		bits.append("精英 ×%.1f" % elite_weight_mul())
	if d >= DIFF_SHOP_PRICE_FROM:
		bits.append("商店 ×%.1f" % shop_price_mul())
	return " · ".join(bits)


static func shop_price_mul(is_key_relic := false) -> float:
	## R794b：商店成交价的难度倍率（**唯一判据**）。
	## 信物（`KEY_RELIC_IDS`）恒不打折也不加价 → 跟「+40%」这条 debuff 无关；
	## 其余商品在难度 ≥12 时 ×1.4，低难度恒 1.0。
	## ⚠️ 别在 `shop_scene` 里另写一份 `if difficulty >= 12` —— 档位口径只许有这一处。
	if is_key_relic:
		return 1.0
	return DIFF_SHOP_PRICE_MUL if _diff() >= DIFF_SHOP_PRICE_FROM else 1.0


static func battle_win_heal() -> int:
	## 战斗**胜利**后的自动回复量。R224 全局规则「除到达新的一层外不能回复 HP」
	## → 所有档位均为 0（表留 11 长度供回归与将来调整）。
	return DIFFICULTY_BATTLE_HEAL[_diff()]


static func rest_pct() -> float:
	## 本档位的休息回复百分比。R224：休息处不再回血 → 全档位 0.0。
	## R767：每日修饰的 `rest`（温暖 +15% / 阴冷 −15%）加法叠加 —— 这是唯一能让
	## 「休息回血」重新出现在游戏里的途径，别在事件里另写一套。
	return maxf(0.0, DIFFICULTY_REST_PCT[_diff()] + float(daily_fx.get("rest", 0.0)))


static func energy_per_turn() -> int:
	## R767：我方每回合费用 = `FieldState.ENERGY_PER_TURN` + 每日修饰的 `energy`
	## （灵光 +1 / 滞涩 −1），**下限 1** —— 费用被抹到 0 的话第一回合就什么都出不了。
	## 敌方 `state.opp_energy` 不读它：修饰只针对玩家，敌人不该跟着变强或变弱。
	return maxi(1, FieldState.ENERGY_PER_TURN + int(daily_fx.get("energy", 0)))


static func hand_draw_per_turn() -> int:
	## R781：我方每回合抽卡数 = `FieldState.HAND_DRAW_PER_TURN` + 每日修饰的 `draw`
	## （滞涩 −1），**下限 1** —— 抽卡被抹到 0 的话回合开始一张新牌都摸不到，那不是难度是死局。
	## 敌方回合的抽卡（`_draw_many` 的对侧调用）不读它：修饰只针对玩家。
	return maxi(1, FieldState.HAND_DRAW_PER_TURN + int(daily_fx.get("draw", 0)))


static func rest_extra_pick() -> int:
	## R781「温暖」：火堆本来是「休息 / 烤肉 / 添加柴火」三选一，这里返回**额外**可选的份数
	## （+1 → 总共能选两项）。唯一消费点是 `event_scene` 的火堆记账口。
	return maxi(0, int(daily_fx.get("rest_pick", 0)))


static func rest_pick_quota() -> int:
	## R781：本次进入火堆**总共**能选几份 = 1 + 修饰额度。
	return 1 + rest_extra_pick()


static func rest_pick_used_here() -> int:
	## R781：这一间火堆已经用掉几份（换一间 / 换一层自动视为 0）。
	## 与圣餐同一套房间键，所以「退出重进同一间」不会把配额刷回去。
	return rest_pick_used if rest_pick_node == sacrament_stay_key() else 0


static func rest_pick_mark() -> int:
	## R781：记一份，返回记账后这一间**已经用掉的总份数**。
	## 唯一写入口 —— `event_scene` 用它判「还能不能再选一项」。
	var key := sacrament_stay_key()
	if rest_pick_node != key:
		rest_pick_node = key
		rest_pick_used = 0
	rest_pick_used += 1
	return rest_pick_used


static func rest_to_battle() -> bool:
	## R781「阴冷」：地图生成时把休息格整体换成战斗格。
	## 唯一消费点是 `RogueMap.generate()` 里给 `type` 赋值那一处 —— 别在地图之外的
	## 地方再判一次，否则会出现「图标是火堆、进去是战斗」的两套口径。
	return bool(daily_fx.get("rest_to_battle", false))


static func rest_heal_amount() -> int:
	## 休息事件的回复量 = 最大生命 × 本档位百分比（向上取整），再受上限封顶。
	## R224：rest_pct 全 0 → 恒为 0（保留函数是为了「将来要把休息回血加回来」只有一个口）。
	return ceili(max_hp * rest_pct())


static func rest() -> int:
	## 「休息」事件：回复 `rest_heal_amount()` 点生命（按难度档位的百分比）。
	## R473（用户口径）：圣餐（6038）**不再**在这里回满 —— 它改成「到达篝火处回复
	## 50% 最大生命」，进房当场由 `sacrament_arrive()` 结算；休息本身回到档位口径。
	return heal(rest_heal_amount())


static func sacrament_stay_key() -> int:
	## R661：圣餐（6038）的「哪一间篝火」唯一键 = **层号 + 节点 id**。
	## ⚠️ 每层地图的节点 id 都从 0 重新编号，只用 `current_node_id` 会跨层撞号 ——
	##    第二层编号 12 的篝火会被当成第一层那间「已经结算过」，整层不回血。
	## `× 10000` 是因为单层节点数远小于一万，不会串到下一层。
	return current_layer * 10000 + current_node_id


## R822：第二层起点的主持人 —— 0 = 卷卷 / 1 = 鸭绅士（与 `CurtainLines.HOST_*` 同值）。
const LAYER2_HOST_BUNBUN := 0
const LAYER2_HOST_DUCK := 1


static func layer2_host(p_seed := -1) -> int:
	## R822（店长口径）：第二层起点遇到谁 —— 卷卷 / 鸭绅士，**权重相等**（各 50%）。
	## 由「本局种子」派生，不摇 `run_rng`、也不进存档：
	##   · 不摇 rng → 不扰动地图 / 掉落那条顺序链，同一种子重跑必然一致；
	##   · 不进存档 → 与 R819 占卜室同一口径：退出事件再进、回标题再继续，**换不了人**。
	##     （存在场景变量或存档里能「重摇」的随机结果，都是玩家可以反复试到想要那一边的漏洞。）
	## R824（店长口径「试玩版改为给鸭绅士」）：试玩版**不再短路成卷卷**，
	## 与正式版走同一条派生 —— 玩家在试玩版也该看到两种开场。
	var s: int = run_seed if p_seed < 0 else p_seed
	return absi(hash("%d:layer2host" % s)) % 2


static func divination_roll_for(p_seed: int, p_layer: int, p_node: int,
		p_kinds := 4) -> int:
	## R819 占卜室：**这一次占卜出第几种幻象**（1~p_kinds）—— 由「种子 + 层 + 节点」派生，
	## 不走 `run_rng`、也不进存档。
	## ⚠️ 原来摇在「点下进行占卜」那一刻、且只存在场景变量里：`_div_stage` 一归零
	##    （回标题 → 继续 → 重进本房）就能重摇，玩家可以反复试到想要的那一种
	##    （鲸鱼之怒 / 烈火之剑）再付 5 点。改成派生后，同一局同一层同一间**必然是同一结果**，
	##    退出重进换不了，也不需要往存档里塞字段（不落盘就没有「读档站死在占卜室」的副作用）。
	## 同种子重跑同一种子自然一致，与 run 层其它随机的口径相同。
	var h := absi(hash("%d:%d:%d" % [p_seed, p_layer, p_node]))
	return (h % maxi(1, p_kinds)) + 1


static func sacrament_arrive() -> int:
	## R473 圣餐（6038）：**到达**篝火处回复 50% 最大生命，返回实际回复量。
	## 0 = 没持有 / 这一间已经结算过 / 本来就是满血。
	## ⚠️ 用 `sacrament_node` 记住结算过的那一间（见 `sacrament_stay_key()`）—— 事件页会
	##    反复重绘，退出去重进也能再进同一条分支，没有这个标记就能无限刷血。
	if not has_relic(RELIC_SACRAMENT_ID):
		return 0
	var stay_key := sacrament_stay_key()
	if sacrament_node == stay_key:
		return 0
	sacrament_node = stay_key
	return heal(ceili(max_hp * SACRAMENT_ARRIVE_PCT))


static func relic_display_name(id: int, plays := -1) -> String:
	## 道具的**显示名唯一口**（R307）：名字后面要补动态信息时只改这里。
	## 目前只有雕像（6039）需要写累计张数 —— 如「雕像（3）」。
	## 计数为 0 时只写名字（免得刚拿到手就顶着「（0）」）。
	##
	## R362 风妖精（6042）：写「已打出 / 需要」，如「风妖精（3/5）」。
	## `plays` = 本回合已打出的张数（战斗界面传 `engine.state.self_card_plays`）；
	## 不传（-1）时只写名字 —— 图鉴 / 事件 / 商店那些地方没有「当前回合」可言。
	## ⚠️ 判定用 `>=` 而不是 `==`：风妖精自己那次结算之后计数还会继续涨，
	##    溢出时写「5/5」而不是变成「6/5」（看着像还能再触发）。
	var rel := RelicRepo.load_json().get_relic(id)
	if rel == null:
		return str(id)
	if id == RELIC_STATUE_ID and statue_charge > 0:
		return "%s（%d）" % [rel.relic_name, statue_charge]
	# R311 不锈钢盆：名字后面写**剩余点数**（10 点打完就失去 —— 玩家得看得见进度）
	if id == BASIN_RELIC_ID and basin_charge > 0:
		return "%s（%d）" % [rel.relic_name, basin_charge]
	# R362 风妖精：本回合已打出张数 / 触发所需 —— 玩家一眼看出「还差几张」
	if id == RELIC_WIND_FAIRY_ID and plays >= 0:
		return "%s（%d/%d）" % [rel.relic_name, mini(plays, WIND_FAIRY_NEED), WIND_FAIRY_NEED]
	return rel.relic_name


static func relic_badge_text(id: int) -> String:
	## 道具图标**右下角角标**的唯一取数口（R809）。返回 "" = 不画角标。
	## 为什么要有这一层：图标模式下 `_draw_relic_bar` 只画图、不画名字，
	## 「还剩几次 / 还差几回合」原本只有悬停能看到 —— 触摸端等于看不见。
	## 口径：
	##   * 已耗尽（盆碎 / 绳用掉）→ 不画（图标画灰已经说明，再挂个「1」会骗人）。
	##   * lucky 7（6045）→ 距下次生效还剩几回合；**生效回合不画**
	##     （转动弧已经在说「就是现在」，再写 7 会被读成「还差 7 回合」）。
	##   * 火柴（6051）→ 剩余刷新次数，0 也照画（得让玩家看见已经用光）。
	##   * 洞窟绳（6048）→ 一次性，还在就是 1 次。
	##   * 雕像（6039）/ 不锈钢盆（6041）→ 剩余次数
	##     （`relic_display_name` 那对括号只在「缺图、退回文字」时才看得见）。
	##   * 其余道具 → 没有可数的东西。
	if not relics.has(id) or is_relic_spent(id):
		return ""
	match id:
		LUCKY7_RELIC_ID:
			return "" if lucky7_is_due() else str(lucky7_left())
		MATCH_RELIC_ID:
			return str(maxi(0, match_charge))
		CAVE_ROPE_RELIC_ID:
			return "1"
		CRESCENT_EARING_ID:
			# R810 新月耳饰：还差几场战斗 → 下一点费用（3 / 2 / 1）。
			# 与 lucky 7 不同，这里**没有「正在生效」的回合**要避让，所以永远画。
			return str(crescent_left())
		RELIC_STATUE_ID:
			return str(statue_charge) if statue_charge > 0 else ""
		BASIN_RELIC_ID:
			return str(basin_charge) if basin_charge > 0 else ""
	return ""


static func crescent_tick() -> bool:
	## R810 新月耳饰（6081）：**每场战斗开始时**（引擎侧 = `turn_number == 1`）调一次。
	## 返回「这一场是否该发 1 点费用」—— 场数满 `CRESCENT_EVERY` 的倍数时为 true，
	## 计到倍数就**归零重数**（而不是一直对模），于是角标「还差几场」永远算得清。
	## ⚠️ 无条件累加（只要持有道具）；发不发钱由返回值决定，调用方负责加 `state.energy`。
	crescent_battles += 1
	if crescent_battles >= CRESCENT_EVERY:
		crescent_battles = 0
		return true
	return false


static func crescent_left() -> int:
	## 还差几场战斗才发下一点费用（角标 / 状态注共用）—— 刚发完时是 `CRESCENT_EVERY`。
	return maxi(1, CRESCENT_EVERY - crescent_battles)


static func lucky7_tick() -> bool:
	## R314 lucky 7（6045）：**每开始一个我方回合**调用一次（跨战斗累计，随存档）。
	## 返回「这一回合是否生效」—— 只在 `lucky7_turns` 是 7 的倍数时为 true。
	## ⚠️ 计数**无条件累加**（只要持有道具就一直在走），判定用过不过 7 取模算 ——
	##    于是「第 7、14、21 … 回合」必然生效，不会因为战斗切换而错位。
	lucky7_turns += 1
	return lucky7_turns % LUCKY7_EVERY == 0


static func pipe_claim() -> bool:
	## R446 烟斗（6055）：战斗首回合把「点着」的那一格用掉。
	## 还亮着 → 返回 true 并熄灭；已经熄灭 → false（这一场不再给加成）。
	if not pipe_ready:
		return false
	pipe_ready = false
	return true


static func pipe_relight() -> bool:
	## R446 烟斗（6055）：路过篝火（休息处）→ 重新点着。
	## 返回「这一次是不是真的从灭到亮」：休息界面据此决定要不要加那行提示。
	## 故意不判「有没有这件道具」—— 没道具时置位无副作用（引擎侧还要再验一次），
	## 「先点着、后拿到」与测试两条路都简单。
	if pipe_ready:
		return false
	pipe_ready = true
	return true


# R447 冒险家的遗物（第一层新事件）产出的两件「即时」道具 —— 效果都落在**地图**上：
#   冒险笔记（6056）：拾起时随机把一个**未探索**房间变成大宝箱，并在图上亮一圈金光；
#   燧石（6057）：拾起时由玩家**选一个走过的房间**，退回未探索 + 变成篝火。
# ⚠️ 两件都不进任何随机池（事件直接 `gain_relic`，不需要在 RelicRepo 的池子里登记）。
const NOTE_RELIC_ID := 6056
const FLINT_RELIC_ID := 6057
## 「展示」用：冒险笔记改完的那一格 id。地图场景据此亮金光，亮完自己清掉。
## 只活在当局内存里（不进存档：读档时玩家早就看过那圈光了）。
static var map_flash_id := -1


static func note_reveal_bigchest() -> int:
	## R447 冒险笔记（6056）：随机挑一个**未探索**房间改成大宝箱，返回那一格的 id
	## （没有可改的格子 → -1）。
	## 候选判据：
	##   * 未探索 = 不在 `cleared_ids` 里（走过的房间已经吃过内容，再改成宝箱是白送）；
	##   * 排除当前所在格 / 起点 / 已经是 `bigchest` 的格（改了等于没改）；
	##   * 排除第三层直道之外的空格（`is_void`，那一层也没有事件房，属于双保险）；
	##   * 排除**开局标记的那间商店**（R693）（「每层那间永远在」是地图设计约束，不能被一张笔记改动）。
	## 随机源走 `run_rng` → 同种子必然改同一格（回放 / 测试可复现）。
	var cands: Array = []
	for c: Dictionary in map_cells:
		var cid := int(c["id"])
		if cid == current_node_id or RogueMap.is_void(c) or cleared_ids.has(cid):
			continue
		if RogueMap.is_fixed_shop(cid):
			continue      # R693：开局标记的那间是「每层永远在」的商店，别改成宝箱
		var ty := str(c.get("type", ""))
		if ty == "start" or ty == "bigchest":
			continue
		cands.append(cid)
	if cands.is_empty():
		map_flash_id = -1
		return -1
	var pick: int = int(cands[run_rng.randi() % cands.size()])
	var cell: Dictionary = map_cells[pick]
	cell["type"] = "bigchest"
	cell["hidden"] = false
	cell["revealed"] = true
	cell["event_kind"] = ""
	map_flash_id = pick
	return pick


static func flint_candidates() -> Array:
	## R448 燧石（6057）：能点的格子 = **全地图任意一格**（走过的 / 没走过的都算）。
	## 只排掉这几类「点了没有意义、或者会把地图弄坏」的格子：
	##   * 当前所在格 —— 站在上面把它变成「未探索」，`advance()` 对同格返回 ok=false，
	##     玩家得先走开再走回来，平白多花一块巧克力；
	##   * 起点格（`type == "start"`）—— `start_cell()` 靠它认地图入口；
	##   * 第三层的 Boss 格 —— 烧成篝火就永远打不到 Boss，直接卡死；
	##   * 开局标记的商店（R693）—— 「每层那间永远在」是地图设计约束；
	##   * 已经是篝火的格 —— 再点一次纯属白烧；
	##   * 第三层直道之外的空格（`is_void`）。
	var out: Array = []
	for c: Dictionary in map_cells:
		var cid := int(c["id"])
		if cid == current_node_id or RogueMap.is_void(c):
			continue
		var ty := str(c.get("type", ""))
		if ty == "start" or ty == "boss" or ty == "rest":
			continue
		if RogueMap.is_fixed_shop(cid):
			continue
		out.append(cid)
	return out


static func flint_rebuild_rest(node_id: int) -> bool:
	## R448 燧石（6057）：把地图上**任意一格**改成篝火。返回是否真的改了。
	## 两类的处理不同（这是 R448 放开「走过的」限制之后必须分开的）：
	##   * 原来走过 → **退回未探索**（从 `cleared_ids` 摘掉），并揭晓成看得见的篝火
	##     —— 它就在你已经探过的区域里，藏起来只会让人找不到；
	##   * 原来没走过 → 保持原来的迷雾状态（是「?」房就还是「?」），
	##     走过去那一刻才发现「原来是篝火」。
	## ⚠️ 必须从 `cleared_ids` 里摘掉：只改 type 不改探索状态的话，再走回去时
	##    `advance()` 会判 `is_new = false` → 「什么都不会发生」，篝火永远点不着。
	## ⚠️ 摘掉它之后，这一格不再是「零消耗穿行」的中转格 —— 穿过它的远路会临时断开，
	##    玩家再走一次这格就重新连上（本来就是这个道具的代价）。
	if node_id < 0 or node_id >= map_cells.size():
		return false
	if not flint_candidates().has(node_id):
		return false
	var cell: Dictionary = map_cells[node_id]
	var was_explored := cleared_ids.has(node_id)
	cleared_ids.erase(node_id)
	cell["type"] = "rest"
	if was_explored:
		cell["hidden"] = false
		cell["revealed"] = true
	cell["event_kind"] = ""
	# 这一格若曾经是商店：货架状态与「可再进店」窗口都失效了，一并清掉，
	# 免得窗口指着一个已经不是商店的格子（`shop_revisit_ok` 会拿它去比较）。
	shop_states.erase(str(node_id))
	if shop_revisit_id == node_id:
		shop_revisit_id = -1
	if map_flash_id == node_id:
		map_flash_id = -1
	return true


static func resolve_event_kind(cell: Dictionary) -> Dictionary:
	## R575（用户口径）：**事件格子在生成时只是事件格子，触发（进房）时才确定事件**。
	## 唯一调用点 = `map_scene._dispatch_node()`（正常进房 / 飞行器传送共用这一条）。
	## 按「当下的巧克力」过滤候选（`GameLayers.event_kind_available`），
	## 与 `event_kinds_used` 账本（一局只出一次，跨层共用）一起落地；
	## 池子抽空按 R374 老口径降级成一般战斗（「?」房本来就看不见内容）。
	## ⚠️ 用分类种子派生 rng（seed_of），**不消耗 run_rng**，回放确定性解耦（R312 口径）。
	## ⚠️ 结果写回 `map_cells` 里那一格：事件只决定一次，读档 / 再看时不会重摇。
	## R575 之前的老存档若已带 event_kind，原样沿用（不推翻旧档的决定）。
	if str(cell.get("type", "")) != "event":
		return cell
	if str(cell.get("event_kind", "")) != "":
		return cell
	var out := cell.duplicate()   # 别污染 map_cells 里那份（与 delivery_override 同口径）
	var layer := int(cell.get("layer", current_layer))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of("event_pick", int(cell.get("id", 0)) + layer * 1000)
	var kind := GameLayers.roll_event_kind(layer, rng, event_kinds_used, chocolate)
	if kind == "":
		out["type"] = "battle"
		out["event_kind"] = ""
	else:
		out["event_kind"] = kind
	# 定型：写回地图本体（按 id 找；外部预生成 / 测试图里找不到就只回副本）
	var cid := int(cell.get("id", -1))
	if cid >= 0 and cid < map_cells.size():
		var origin: Dictionary = map_cells[cid]
		if int(origin.get("id", -1)) == cid:
			origin["type"] = str(out["type"])
			origin["event_kind"] = str(out["event_kind"])
	return out


static func flyer_candidates() -> Array:
	## R555 飞行器（第二层事件）：能飞到的格子 = 全图「没走过」的格子。
	## 只排掉：void（不存在）、起点、Boss（不能直接飞上去开战）、固定商店、已经走过的。
	## R575：飞行器不消耗巧克力；目标仍只能是「没走过」的新格子（飞过去 = 一次跳跃）。
	var out: Array = []
	for c: Dictionary in map_cells:
		var cid := int(c["id"])
		if RogueMap.is_void(c):
			continue
		if cleared_ids.has(cid):
			continue
		var ty := str(c.get("type", ""))
		if ty == "start" or ty == "boss":
			continue
		if RogueMap.is_fixed_shop(cid):
			continue
		out.append(cid)
	return out


static func flyer_teleport(node_id: int) -> Dictionary:
	## R555 飞行器：无视相邻关系，直接飞到 node_id（必须是「没走过」的格子）。
	## 返回 {"ok", "cost", "revealed", "chocolate"}。
	## R575（用户口径）：**飞行器不消耗巧克力** —— cost 恒 0，也不触发入夜 / 疲惫同步。
	## 「巧克力见底就遇不到飞行器」由 `resolve_event_kind()` 在触发那一刻保证，
	## 这里不再摆第二道判据（不再有「遇到但不能用」）。
	if node_id < 0 or node_id >= map_cells.size():
		return {"ok": false, "cost": 0, "revealed": false, "chocolate": chocolate}
	if cleared_ids.has(node_id) or not flyer_candidates().has(node_id):
		return {"ok": false, "cost": 0, "revealed": false, "chocolate": chocolate}
	# R695：飞过去也是「踏进一个没探索过的格子」→ 忘拿的奖励同样到期。
	# 位置与 `advance()` 里那条一致：先清账、再改位置（顺序本身不影响正确性，
	# 但两处保持同一顺序，读起来才不会怀疑有坑）。
	var forfeited := forfeit_pending_rewards()
	var c: Dictionary = map_cells[node_id]
	cleared_ids.append(node_id)
	var revealed := false
	if bool(c.get("hidden", false)) and not bool(c.get("revealed", false)):
		c["revealed"] = true
		revealed = true
	current_node_id = node_id
	reveal_known()
	return {"ok": true, "cost": 0, "revealed": revealed, "chocolate": chocolate,
			"forfeited": forfeited}


static func lucky7_left() -> int:
	## 距下一次生效还有几个回合（刚生效过则返回 7；计数为 0 时返回 7）。
	var r := lucky7_turns % LUCKY7_EVERY
	return LUCKY7_EVERY if r == 0 else LUCKY7_EVERY - r


static func lucky7_is_due() -> bool:
	## 当前计数是否正处在「刚满 7」的生效回合计（供界面 / 断言读）。
	return lucky7_turns > 0 and lucky7_turns % LUCKY7_EVERY == 0


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
	## R767：每日修饰的 `gold` 叠在这上面（「贫瘠」−50 也该能开盘，所以夹 0 下限）。
	var base := DIFF_GOLD_HIGH if _diff() >= 7 else DIFF_GOLD_LOW
	return maxi(0, base + int(daily_fx.get("gold", 0)))


static func chocolate_per_layer() -> int:
	## 每层初始巧克力：8 档起「行动力降低」= 11，其余 = RogueMap.MAX_STEPS(12)。
	## R399（用户口径「第三层应该不再提供巧克力」）：第三层是 5 格直道，每格 `cost` 恒为 0，
	## 巧克力在那儿一块也用不掉 —— 直接给 0，不再显示一个永远花不掉的数字。
	## ⚠️ 读的是**当前层**（`advance_layer` 里先赋 `current_layer` 再调本函数）。
	## R767：每日修饰的 `choco`（旅粮 +3 / 饥饿 −3）叠在这里；第三层仍然恒 0。
	if current_layer == GameLayers.LAYER_THREE:
		return 0
	var base := DIFF_CHOCO_HIGH if _diff() >= 8 else RogueMap.MAX_STEPS
	return maxi(0, base + int(daily_fx.get("choco", 0)))


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
	## R767：每日修饰的 `hp_mul`（强健 ×1.15 / 贫血 ×0.88）**相乘**叠在难度系数上。
	return (DIFF_MAX_HP_MUL if _diff() >= 9 else 1.0) * float(daily_fx.get("hp_mul", 1.0))


static func enemy_hp_bonus_pct() -> float:
	## 3 档起「敌人更加顽强」：敌方开场生命 +10%（向上取整）。
	## R767：每日修饰的 `enemy_hp`（敌之孱弱 −15% / 敌之顽强 +20%）加法叠加。
	return (DIFF_ENEMY_HP_PCT if _diff() >= 3 else 0.0) + float(daily_fx.get("enemy_hp", 0.0))


static func enemy_power_bonus() -> int:
	## 6 档起「敌人更加凶猛」：敌方开场攻击 +1（原本 0 攻工事除外，见 scaled_enemy_card）。
	## R767：每日修饰的 `enemy_power` 加法叠加，但**不叠成负数**（敌人攻击不能被抹到 0 以下）。
	return maxi(0, (DIFF_ENEMY_POWER if _diff() >= 6 else 0) + int(daily_fx.get("enemy_power", 0)))


static func rare_weight_mul() -> float:
	## 4 档起「稀有卡牌获取概率降低」：卡牌奖励里稀有权重的乘数（×0.5）。
	## R767：每日修饰的 `rare_mul`（幸运 ×1.6 / 倒霉 ×0.5）相乘。
	return (DIFF_RARE_WEIGHT_MUL if _diff() >= 4 else 1.0) * float(daily_fx.get("rare_mul", 1.0))


static func fatigue_active() -> bool:
	## 5 档起「行动力低时疲惫」是否生效。R767：每日减益也会强制开启它。
	return _diff() >= DIFF_FATIGUE_FROM or bool(daily_fx.get("fatigue", false))


static func elite_weight_mul() -> float:
	## 10 档起「精英出现增多」：地图生成时**精英出现概率**的统一乘数。
	## 注意这是「概率」不是「权重」：`RogueMap._weighted_far()` 会把多出来的权重从
	## 其他类型里扣掉，所以精英占比恰好涨 ×1.3，而不是权重 ×1.3 后只涨两成。
	## 明房（`RogueMap.WEIGHTS`）与「?」房（`RogueMap.WEIGHTS_UNKNOWN`）两条途径都乘它，
	## 而唯一消费点是 `RogueMap._weighted_far()` —— 所以「各种途径」天然只有一个口。
	## R767：每日修饰的 `elite_mul`（冷清 ×0.75 / 拥挤 ×1.5）相乘。
	return ((DIFF_ELITE_MUL if _diff() >= DIFF_ELITE_FROM else 1.0)
			* float(daily_fx.get("elite_mul", 1.0)))


static func unknown_shop_allowed() -> bool:
	## 10 档起「精英出现增多」的配套：**「?」房不再刷出商店**。
	## 于是每层商店 = 右上角那间固定商店 + `RogueMap.SHOP_MIN/MAX` 那 2 间，数量恒定
	## （用户口径「每层商店数量调整为固定 2 个，不算右上角」）。
	## 低档位维持原样（「?」房仍可能刷出商店）。
	return _diff() < DIFF_ELITE_FROM


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
		var hp_add := ceili(card.health * pct)
		c.health += hp_add
		c.diff_health += hp_add       # R325：单独记账 → 卡面染色不把难度加成当「变强」
	if add > 0 and not skip_power:
		c.power += add
		c.diff_power += add
	return c


static func sync_fatigue() -> void:
	## R223 难度 5「行动力低时疲惫」：**从 deck_ids 直接推导**（不加布尔 flag，读档天然正确）。
	## 难度 ≥5 且巧克力 < 6 → 卡组里放一张「疲惫」9149；巧克力 ≥6（或难度不足）→ 移除。
	## 调用点：start_run / advance_layer / advance（扣巧克力后）/ 事件与商店的巧克力加法 /
	## RunSave.load_run（读档后按巧克力纠正）。
	## ⚠️ 战斗内不调用（战斗中巧克力不变；手牌每场从 deck_ids 重抽，删卡组即生效）。
	## ⚠️ R358：**每层最多发一次**（用户口径「确保每层只会获得一次疲惫」）。
	##    `fatigue_granted_layer` 记「最近一次发放在哪一层」：玩家把疲惫删掉、或巧克力
	##    涨回 6 把它洗掉之后，同一层内不再补第二张；换层 / 新开一局重置成 -1。
	##    没有这道闸门时，用户场景「删疲惫 → 买巧克力 → 再走一格」会把它原样补回来
	##    —— 商店的「移除卡」等于对疲惫无效，而且能无限刷。
	# R357：第三层没有巧克力 → 「行动力低时疲惫」在这一层不存在。
	# 从第二层带进来的那张疲惫卡（难度 8 起、进层时巧克力还低过）在这里要拿掉，
	# 否则玩家会带着一张「这一层根本不会自然消除」的废卡打启示者。
	if current_layer == GameLayers.LAYER_THREE:
		if deck_ids.has(FATIGUE_CARD_ID):
			remove_all_cards(FATIGUE_CARD_ID)
		return
	if fatigue_active() and chocolate < DIFF_FATIGUE_LIMIT:
		if not deck_ids.has(FATIGUE_CARD_ID):
			# R358：本层已经发过一次（被删 / 被洗掉）→ 不再补第二张。
			# 用 `>=` 而不是 `==`：万一漏了某条重置路径，也只会「少发」，不会「多发」。
			if fatigue_granted_layer >= current_layer:
				return
			add_card(FATIGUE_CARD_ID)
			fatigue_granted_layer = current_layer
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
	## 失去指定点数的最大生命（「源数之力」的代价）。
	## R727（店长口径）：**不再扣当前生命** —— 源数之力固定是「一层初始」拿到，
	## 那一刻玩家是满血，扣不扣当前血结果完全一样，描述里那句括号只是噪音。
	## 现在只把当前生命钳到新上限以内（满血时自然仍是满血）。
	## 至少保留 1 点最大生命（否则玩家会直接暴毙）。返回实际失去的点数。
	var lost: int = mini(maxi(0, amount), maxi(0, max_hp - 1))
	if lost <= 0:
		return 0
	max_hp -= lost
	hp = mini(hp, max_hp)
	return lost


# ------------------------------------------------------------ run 生命周期

# ------------------------------------------------------------ R757 遥测上下文

static func _tele_ctx() -> Dictionary:
	## 奖励摆到面前那一刻的处境 —— 分析时用来解释「为什么这三张里偏选它」：
	## 血少时倾向回血 / 防御，钱多时才敢买贵的，层深了才敢押上限。
	## ⚠️ 只在发布版拼这个字典（先问 `Telemetry.is_enabled()`）—— 测试版连这点开销都不花。
	if not Telemetry.is_enabled():
		return {}
	return {"layer": current_layer, "node": current_node_id, "hp": hp, "mhp": max_hp,
			"gold": gold, "deck": deck_ids.size()}


static func _tele_src() -> String:
	## 这组奖励从哪来：boss / elite / battle / event / shop / demo。
	## 必须分开统计 —— 「战斗后必给的三选一」和「商店里要花 80 金」的选择压力完全不同，
	## 混在一起算出来的选择率没有意义。
	var t := str(pending_node.get("type", ""))
	if t == "boss":
		return "boss"
	if t == "elite":
		return "elite"
	if reward_context != "":
		return reward_context
	return "demo"


static func start_run(map: Array, layer := GameLayers.LAYER_DEFAULT,
		cid: String = "", seed_override := 0, seed_code := "", daily: Dictionary = {}) -> void:
	## 新 run：满血、初始卡组、载入地图、定位起点（第 0 列唯一节点）。
	## layer = 本局地图所属的层（地图上所有战斗/事件都从这一层的内容池里取）。
	## map 传空数组时用本局种子现生成（真实流程 = 角色选择场景这样进来）。
	## R241 种子：`seed_override != 0` 时**用它**（同一种子必然同一张图、同一串掉落/摇卡）；
	## 0 = 现摇一个。整局只有这一行碰全局随机源，之后所有随机都由 `run_seed` 派生。
	# R762：每日身份与固定难度必须在**生命计算 / 种子选择 / 解锁钳制**之前落定。
	daily_date = str(daily.get("date", ""))
	daily_rules = int(daily.get("rules", 0)) if daily_date != "" else 0
	# R767：每日修饰的数值汇总。**必须在下面 `max_hp_mul()` 被调用之前就位** ——
	# 「强健 / 贫血」改的就是初始最大生命，晚一行赋值就等于这条修饰不存在。
	var dfx: Variant = daily.get("fx", {})
	daily_fx = (dfx as Dictionary).duplicate(true) if daily_date != "" and dfx is Dictionary else {}
	if daily_date != "":
		set_difficulty(int(daily.get("difficulty", difficulty)))
	# 初始生命按职业不同（R182）：基础 50 + 职业加成（森林精魄+20/暗影刺客+10/机械之心+16）。
	# R223 难度 9「虚弱」：初始最大生命 ×80%（截断取整）—— 在 reset 之前算好基数。
	var base_hp: int = PlayerClass.base_hp_of(cid if cid != "" else PlayerClass.default_id())
	if max_hp_mul() < 1.0:
		base_hp = int(base_hp * max_hp_mul())
	reset(base_hp)
	# run 种子（R241 / R261）：**全局唯一随机源**的根 —— 地图 / 掉落 / 摇卡 / 商店库存 / 战斗种子
	# 全部从它派生；同一种子重开、以及「继续游戏」读档（seed + rng.state）都走这条链。
	# R261：优先吃玩家输入的 10 位种子码；其次旧的 int 覆盖（测试与旧调用点）；
	# 都没有 → 现摇一个 10 位码（整局唯一碰全局随机源的地方，见 random_seed_text）。
	# R762：每日配置本身拥有根种子。调用方不必再重复传一次，否则漏传会静默退成随机局。
	if daily_date != "" and seed_code == "" and seed_override == 0:
		seed_override = int(daily.get("seed", 0))
	var code_v := seed_value_of(seed_code) if seed_code != "" else -1
	if code_v > 0:
		run_seed = code_v
	elif seed_override != 0:
		run_seed = seed_override
	else:
		run_seed = seed_value_of(random_seed_text())
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_active = true
	player_class = cid if cid != "" else PlayerClass.default_id()
	# R550（发布版解锁）：防御性钳制 —— 难度不得超过当前职业已解锁的上限。
	# UI（class_pick_scene）里已经拦，这里是纵深防御：任何路径带着超限难度进来都会被压回。
	# R762：每日挑战例外。固定配置对所有人相同，不能被各账号的解锁进度压成不同难度。
	# R814：**试玩版也要钳**。试玩版 `is_release()` 恒 false，只判发布版的话，
	# 一份来自完整版的档案（难度 12）能让试玩版直接 12 开局 —— 档位上限 1 就形同虚设。
	if (GameBuild.is_release() or GameBuild.is_demo()) and daily_date == "":
		difficulty = clampi(difficulty, 0, UnlockSystem.difficulty_cap(player_class))
	# R352：统计「开局次数」—— 故事 1 的解锁条件就是「进行任意一局游戏」。
	# 只记内存 + 置脏，落盘交给 `flush()`（`map_scene` 进地图时会调）。
	ProfileData.bump(ProfileData.K_RUN_START)
	# R580：故事 3「用暗影刺客进行一局游戏」—— 按职业再记一份，不影响故事 1 的无后缀计数。
	ProfileData.bump(ProfileData.K_RUN_START_CLASS + player_class)
	# R757 遥测：一局开始（只有发布版会真写；测试版 `Telemetry.is_enabled()` 恒 false）。
	# `runs` 传「本局**之前**玩过多少局」—— 上面刚 +1，所以这里减一。这个数是分层比较
	# 的前提：新手和老手的同名卡牌胜率不能直接平均。
	Telemetry.begin_run(run_seed, player_class, difficulty,
			maxi(0, ProfileData.stat(ProfileData.K_RUN_START) - 1))
	_tele_outcome = ""
	# R576 Steam 成就：初次启程（幂等，重复开局无害）。
	SteamAchievements.note_first_step()
	# R374：新的一局 → 事件账本清空。R575：事件在**进房时**才决定，生成期不再往账本登记；
	# 外部**预生成**的地图（`map` 非空）里若带着老格式的 event_kind（R575 之前的存档），
	# 仍要补登记，免得换层又撞同一个事件。
	event_kinds_used = {}
	if not map.is_empty():
		for c: Dictionary in map:
			if str(c.get("type", "")) == "event":
				var ek0 := str(c.get("event_kind", ""))
				if ek0 != "":
					event_kinds_used[ek0] = true
		map_cells = map
	else:
		map_cells = RogueMap.generate(run_rng, layer, null, event_kinds_used)
	current_layer = layer
	cleared_ids = []
	seen_ids = []                 # R207：新开一局 → 迷雾记忆清空
	chocolate = chocolate_per_layer()   # R223 难度 8「行动力降低」：8 档起 = 11
	fatigue_granted_layer = -1    # R358：新的一局 → 疲惫还没发过
	gold = start_gold()           # R181 初始 100 金；R223 难度 0 +50、难度 7 起降回 100
	boss_pending = false
	boss_beaten = false       # R339：新的一局 → 本层 Boss 还没打
	run_finished = false       # R339：新的一局 → 上一局的收尾标记作废
	battle_log = []
	pending_level = {}
	pending_node = {}
	reward_context = ""
	pending_deck_edit = ""
	statue_charge = 0          # R307 雕像：新的一局从 0 开始数
	basin_charge = 0           # R311 不锈钢盆：新的一局没有盆（重拿时再灌满）
	match_charge = 0           # R342 火柴：新的一局没有火柴（重拿时再灌满 3 次）
	spent_relics.clear()       # R367：新的一局没有「已耗尽」的道具
	pipe_ready = false          # R446：新的一局 → 烟斗从头（没拿到就是灭的）
	core_lost = 0               # R458：核心的累计受伤 / 触发位在新的一局归零
	core_armed = false
	boss_kills.clear()         # R367：新的一局重新记每层 Boss
	reward_kinds = []
	# 开局卡组 = 公共部分 + 2 张角色基础盟友（森林精魄 → 树人；暗影刺客 → 幽影）
	# + 角色专属卡（森林精魄 → 熊 8004；暗影刺客 → 突袭 9086）。见 PlayerClass.start_deck_ids。
	# R767：每日挑战自带一套**随机卡组**（同一天所有人同一套）。这里**只读配置、不现摇** ——
	# 开局那一刻再抽的话，同一个种子两局会不一样，Steam 榜就失去意义了。
	var ddeck: Variant = daily.get("deck", [])
	if daily_date != "" and ddeck is Array and not (ddeck as Array).is_empty():
		deck_ids.clear()
		for v: Variant in (ddeck as Array):
			deck_ids.append(int(v))
	else:
		deck_ids = PlayerClass.start_deck_ids(player_class)
	deck_mods = []                # R181：新开一局 → 附魔清空
	lake_victim = -1              # R488：新开一局 → 湖中仙女没摇过「要失去的那张」
	card_growth = {}             # R393：新开一局 → 击杀成长清零
	milk_anim = []                # R323：牛奶的演示数据也清掉
	resume_battle = {}            # R323：清掉「正在打的这场」（下面按需重写）
	ensure_deck_mods()            # R204：立刻对齐成等长（否则附魔必越界，见函数注释）
	sync_fatigue()                # R223 难度 5：开局巧克力满 → 先入/出一次（<6 才生效）
	battle_wins = 0
	elite_wins = 0
	reset_run_stats()             # R530：新的一局 → 整局统计归零
	used_levels = []
	map_strokes = []              # R177：新开一局清掉上一局的玩家标记
	map_flags = []
	# 本层 Boss 开局摇定（同层多个 Boss 时随机；走 run_rng → 同一种子必然可复现）
	# 彩蛋 Boss（R73）：开新 run 先清pending，再摇 —— _roll_boss 内部会按
	# 「第一层是否摇中恶魔鸭」置位。顺序不能反，否则会用到上一局残留的 pending。
	revenge_pending = false
	boss_pick = _roll_boss(current_layer)
	# R352：禁卡开局快照 —— 必须在 `player_class` 定下来之后取。
	run_bans = ProfileData.bans_of(player_class)
	relics = []
	key_relics = []   # R543：新的一局没有信物
	traps = [-1, -1, -1]   # R663：新的一局陷阱栏 3 空槽
	tool_roll_seq = 0      # R694：新的一局 → 战斗掉落工具的重摇序号归零
	toolbox_tool_seq = 0   # R745：工具箱发工具的序号同样归零
	# R767：每日修饰 `tools`（工具箱）—— 开局多发 N 件工具。走 R745 的唯一发放口，
	# 满栏时会自动排进「待领奖励」，不会静默吞掉。标准局 `daily_fx` 为空 → 循环 0 次。
	for i: int in int(daily_fx.get("tools", 0)):
		grant_random_tool("daily")
	tool_deliver_seq = 0   # R752：快送鸭的序号同样归零
	tool_drop_pledge = 0   # R754：新的一局没有「必掉」的祝福
	bandage_pending = 0
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	pending_fly = false          # R555：新的一局 → 没有待选的飞行器
	map_flash_id = -1
	pending_rewards = []   # R119：开新 run 清空待领奖励
	reset_shop_session()   # R390：新的一局没有旧货架，也没有可重进的店
	duck_revive_chance = 100
	lucky7_turns = 0            # R314：新开一局 → lucky 7 的跨战斗计数归零
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


## R471：通关（最后一层 Boss 击破、没有下一层）时的**迟到收尾**。
## 旧路径在结算面板一出现就 `end_run()` —— 那一刻整局被清空，而奖励面板往往还没处理完：
## 鸭血 6024 / 源数之力 6002 / 失忆药水 6004 这类「要玩家选卡」的即时道具领到手里时
## `run_active` 已经变假，`waiting_pick_scene()` 一律返回空串 → 选卡界面永远出不来，
## 道具白拿。这是 R470 那条坑的**下游**（上游是 `gain_relic` 的 once_pick）。
## 现在分两步：先只落章「本局不再继续」（`run_finished` + 删续档，地图据此不再兜底开新局），
## 内存里的卡组 / 道具 / `pending_relic` 全部留着；等玩家真的离开（结算按钮关掉结算面板、
## 或选卡页办完出来）再走 `end_run()` 清干净。
static func mark_run_won() -> void:
	if run_finished:
		return
	run_finished = true
	_tele_outcome = "win"     # R757：落章时记结果，等 `end_run()` 交出一条 run_end
	# R640：**先立墓碑，再删档**。两件事都可能失败（墓碑文件写不进 / 档被占用删不掉），
	# 顺序反了就有一半概率让这一局复活；先立墓碑的话，最坏也只是盘上多一份**读不进去**的档。
	# 墓碑 = 「这个 seed 已经打通」的权威记录，读档口认它（见 `RunSave.is_cleared`）。
	RunSave.mark_cleared(run_seed)
	RunSave.clear_save("run_won")


static func mark_run_lost() -> void:
	## R551：失败也要进结算页 —— 与 `mark_run_won` 同形，只落章「本局不再继续」+
	## 删续档，**不**清内存里的卡组 / 统计 / `run_summary`（结算页还要读）。
	## 真正的 `end_run()` 等玩家在结算页点「确定」再跑（见 run_summary_scene._on_confirm）。
	if run_finished:
		return
	run_finished = true
	_tele_outcome = "lose"    # R757：同 `mark_run_won` —— 失败在结算页点「确定」才 end_run
	RunSave.clear_save("run_lost")


static func end_run(clear_save: bool = true) -> void:
	## run 结束（通关 / 失败）：
	##   * clear_save = true（默认）：连**续档**一起清掉 —— 这一局真的结束了；
	##   * clear_save = false：只复位内存里的 run 状态，**保留续档**（R167）——
	##     给「返回标题」这种「先离开一下、回头还能点『继续游戏』」的路径用。
	## 记录与持久化文件照旧保留。
	# R757 遥测：**必须在清空 deck_ids / gold 之前**交出这一局的收尾事件 —— 下面几行
	# 就把它们全抹掉了。只在真的收尾（clear_save）时记：回标题保留续档的那条路不是
	# 「一局结束」，记了会把同一局拆成两半。
	if clear_save and _tele_outcome != "":
		Telemetry.end_run(_tele_outcome == "win",
				{"cls": player_class, "diff": difficulty})
		_tele_outcome = ""
	run_active = false
	daily_date = ""               # R762：续档里另有副本；内存复位不删每日成绩
	daily_rules = 0
	daily_fx = {}                 # R767：修饰汇总必须一起清 —— 否则下一局标准模式还带着今日的减益
	pipe_ready = false          # R446：一局结束 → 烟斗状态位复位
	core_lost = 0               # R458：核心的累计与触发位同样复位
	core_armed = false
	player_class = PlayerClass.default_id()
	deck_ids = []
	deck_mods = []                # R181：本局结束 → 附魔清掉
	card_growth = {}             # R393：本局结束 → 击杀成长随之消失
	milk_anim = []                # R323：牛奶的演示数据也清掉
	resume_battle = {}            # R323：清掉「正在打的这场」（下面按需重写）
	map_cells = []
	current_layer = GameLayers.LAYER_DEFAULT
	current_node_id = -1
	cleared_ids = []
	seen_ids = []                 # R207：本局结束 → 迷雾记忆清掉
	chocolate = 0
	gold = 0                      # R181：本局结束 → 金币清掉
	boss_pending = false
	boss_beaten = false       # R339：一局结束 → 标记回到初值
	# R339：本局已收尾（地图场景据此不再兜底开新局）。
	# R359：**只有真的结束才算收尾** —— 回标题（clear_save=false）是「先离开一下」，
	# 这一局还要接着打，置真的话内存里就自相矛盾（保了档却说自己已结束）。
	# R640：**不许反写成假**。旧写法 `run_finished = clear_save` 在「已经通关、玩家却在
	# 结算前点了返回标题」那条路上会把收尾标记抹掉 —— 内存里于是变成「一局已通关却声称
	# 还在进行」，紧接着任何一次检查点都会把它原样写回盘上，通关成果当场复活。
	# 只允许「由假变真」，不允许「由真变假」。
	if clear_save:
		run_finished = true
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
	reset_run_stats()           # R530：整局统计不跨局
	delayed_cards = []          # R473：延迟发卡的挂单不跨局（一局结束就作废）
	sacrament_node = -1         # R473：圣餐的「已结算房间」跟着一局走
	rest_pick_node = -1         # R781：火堆配额同样不跨局
	rest_pick_used = 0
	used_levels = []
	map_strokes = []              # R177：本局结束 → 标记随之清掉
	map_flags = []
	run_bans = []          # R352：本局结束 → 禁卡快照作废（下一局重新取）
	relics = []
	key_relics = []   # R543：本局结束 → 信物清空
	traps = [-1, -1, -1]   # R663：本局结束 → 陷阱栏清空
	tool_roll_seq = 0      # R694：本局结束 → 掉落工具的序号也归零
	toolbox_tool_seq = 0   # R745：工具箱的序号也归零
	tool_deliver_seq = 0   # R752：快送鸭的序号也归零
	tool_drop_pledge = 0   # R754：祝福不跨局
	spent_relics.clear()       # R367：灰显标记随本局一起清掉
	boss_kills.clear()         # R367：本局 Boss 战果不跨局
	bandage_pending = 0
	relic_choice = []
	skipped_relics = []
	pending_relic = -1
	pending_relic_drop = -1
	pending_fly = false         # R555：本局结束 → 待选飞行器复位
	map_flash_id = -1
	match_charge = 0            # R342：本局结束 → 火柴次数复位
	duck_revive_chance = 100
	lucky7_turns = 0            # R314：本局结束 → lucky 7 计数复位
	delivery_done = false       # R200：本局结束 → 复位
	pending_event = ""


	# 续档：run 结束（通关 / 失败 / 放弃）→ 本地存档随之失效。
	# R377：带来源，方便在 `save_trace.log` 里分清是「真结束」还是「有人误调」。
	if clear_save:
		RunSave.clear_save("end_run")


static func advance_layer(layer: int) -> int:
	## 进入下一层（打败上一层 Boss 后由 battle_scene 调用）：
	##   * **恢复所有生命**（第二层起始节点：满血重新出发）；
	##   * 生成本层地图（RogueMap.generate(rng, layer)，5×7 格子）；
	##   * 掷本层起始道具三选一（第一层 = 初始池，第二层 = 二层起始池）；
	##   * 重置层内进度（战斗计数 / 选关记录 / 已清节点），**卡组与道具跨层保留**。
	## 返回本层起点节点 id（-1 = 地图为空）。
	# R695：换层 = 旧地图整张作废 → 旧地图上忘拿的奖励同样作废（"到下一个未探索的格子"
	# 的那张图已经不在了，留着也回不去）。放在最前面：下面一长串清理都以新层为准。
	forfeit_pending_rewards()
	max_hp = maxi(1, max_hp)
	hp = max_hp                      # 二层起始：恢复所有生命
	bandage_pending = 0             # R234：换层 → 止血绷带待结算清零（本层口径）
	current_layer = layer
	battle_wins = 0
	elite_wins = 0
	# R398（用户口径「三层会重复遇到二层精英，优先避免重复」）：
	# `used_levels` **换层不清空** —— 第三层的精英池沿用第二层（`content_layers = [2, 3]`），
	# 清空就等于把「这一局刚打过谁」忘掉，直道第 2 格必然可能撞回同一只。
	# 池子真被用尽时 `_pick_level()` 自带「允许循环复用」兜底，不会走进死路。
	# 本层 Boss 开局摇定（换层要重摇：第二层只有机械巨鸭）
	boss_pick = _roll_boss(layer)
	reset_shop_session()          # R390：换层 = 新地图 → 上一层的店全部作废
	cleared_ids = []
	seen_ids = []                 # R207：换层 = 新地图 → 上一层记得的格子全部作废
	# R460（用户口径「地图上如果绘制了标记，进入下一层应该全部清除」）：
	# 标记是按**旧地图**的格位存的（笔画记屏幕坐标点、小旗记格 id），新一层格子全换过 ——
	# 留着不只对不上位置，还会让人误以为「这格我已经查过了」。
	# 与 `start_run()` / `end_run()` 两处清空同一口径，换层是第三条路，之前漏了。
	map_strokes = []
	map_flags = []
	map_flash_id = -1             # R460：上一层的「冒险笔记」金光也不要落到新地图上
	pending_level = {}
	pending_node = {}
	pending_event = ""
	reward_context = ""
	pending_deck_edit = ""
	reward_kinds = []
	reward_type = "normal"
	# 本层地图用本局种子续摇（同一 run 的随机链条：start_run → 各次 advance_layer）
	# R312：持有「水晶骰子」→ 本层地图除固定房间外全部是「?」，且**内容按「?」重摇**。
	# 重摇本身走**独立**的分类种子流（`dice_map_rng()`），一个随机数都不花在主链上；
	# 只有「重摇把可达宝箱摇没了 → 触发结构重试」那一步才会动 `run_rng`（确定性，可复现）。
	# R374：`event_kinds_used` 跨层共用 —— 换层**不清空**，这就是「一局只出一次」的落点。
	map_cells = RogueMap.generate(run_rng, layer,
			dice_map_rng() if relics.has(DICE_RELIC_ID) else null,
			event_kinds_used)
	# R372（用户口径）：**第三层的起点只要回血** —— 这一层不再摇起始道具三选一。
	# 直道只有 5 格，进层时弹一段「卷卷开场 + 三选一」既没有空间也不需要；
	# 空候选 = map_scene 的「候选非空 → 去卷卷」重定向不会触发，玩家直接落在地图上，
	# 走到起点格就回满生命（`map_scene._commit_enter` 的起点补给）。
	# ⚠️ 不摇也不消耗任何随机数（`_roll_relic_choice()` 会花 3 次 run_rng）。
	if layer == GameLayers.LAYER_THREE:
		relic_choice = []
	else:
		relic_choice = _roll_relic_choice()
	fatigue_granted_layer = -1    # R358：换层 → 新的一层重新拥有一次「获得疲惫」的机会
	chocolate = chocolate_per_layer()   # 新一层：巧克力重新满上（R223 难度 8 起 = 11）
	sync_fatigue()                # R223 难度 5：新层巧克力满 → 疲惫出卡组
	boss_pending = false
	boss_beaten = false           # R339：新的一层 → 这一层的 Boss 还没打
	current_node_id = -1
	if not map_cells.is_empty():
		var sc2 := RogueMap.start_cell(map_cells)
		if not sc2.is_empty():
			current_node_id = int(sc2["id"])
			cleared_ids.append(current_node_id)   # 起点同样算「初始点」
	# R745 工具箱（6068）：每进入新的一层，再给一个随机工具。
	# 位置放在换层清理之后 —— 此时 traps 栏才是本层的状态；满栏转待领奖励。
	if relics.has(TOOLBOX_RELIC_ID):
		grant_random_tool("layer")
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
	## R822：第二层按「这一局遇到谁」分流 —— 鸭绅士在场时池子里是带鸭道具，
	## 卷卷在场时是剩下的 5 件。R824 起试玩版也出鸭绅士，两边同一条分流。
	var host: int = layer2_host() if current_layer == GameLayers.LAYER_TWO else LAYER2_HOST_BUNBUN
	var pool := RelicRepo.load_json().start_ids_for_layer(current_layer, host)
	var out: Array[int] = []
	var bag: Array[int] = pool.duplicate()
	while out.size() < 3 and not bag.is_empty():
		out.append(bag.pop_at(run_rng.randi() % bag.size()))
	return out


static func choose_start_relic(id: int) -> void:
	## 起点三选一：收下所选道具（relic_pick 场景调用）。
	gain_relic(id)
	relic_choice = []


# ------------------------------------------------------------ R663 陷阱栏

static func trap_at(slot: int) -> int:
	## 读某槽的陷阱 id（-1 = 空 / 越界）。绘制与放置都走这里。
	if slot < 0 or slot >= TRAP_SLOTS or slot >= traps.size():
		return -1
	return traps[slot]


static func trap_free_slots() -> int:
	## 商店购买判据的**唯一口**：满栏（0）时商品置灰、点了只给提示。
	var n := 0
	for v in traps:
		if int(v) < 0:
			n += 1
	return n


static func trap_first_empty() -> int:
	for i in traps.size():
		if int(traps[i]) < 0:
			return i
	return -1


static func gain_trap(id: int) -> bool:
	## 获得一个陷阱 → 填进第一个空槽。满栏返回 false（不吞掉金币）。
	var s := trap_first_empty()
	if s < 0:
		return false
	traps[s] = id
	return true


static func consume_trap(slot: int) -> int:
	## 放置那一刻从栏位移除（R663 口径）；返回被取出的 id，空槽返回 -1。
	## 之后场上的是独立场地实体，触发后「消失」= 本场对战移除。
	var id := trap_at(slot)
	if id < 0:
		return -1
	traps[slot] = -1
	return id


static func discard_trap(slot: int) -> int:
	## R695（用户口径「现有道具可以丢弃」）：把栏位里的工具**主动丢掉**，腾出格子。
	## 返回被丢掉的 id（空槽 / 越界 → -1，调用方据此静默）。
	## ⚠️ 与 `consume_trap()` 的区别：那个是「用掉了」（放置 / 使用，效果已经发生），
	##    这个是「不要了」—— 没有回血、没有退款、不计入本场使用记录。
	## ⚠️ 没有「丢掉还能捡回来」：工具是一次性的栏位资源，丢了就是丢了。
	var id := trap_at(slot)
	if id < 0:
		return -1
	traps[slot] = -1
	return id


static func roll_battle_tool_drop() -> int:
	## R694（用户口径「任何战斗都有 10% 概率掉落工具」）：**每一场**战斗胜利都摇一次 ——
	## 普通 / 精英 / Boss / 事件里的遭遇战一视同仁（不收 node_type，所以不存在漏掉哪一类）。
	## 命中就返回要掉的工具 id，没掉返回 -1；真正的发放交给 `queue_tool_reward()`。
	##
	## 随机流：走 `seed_of("tool_drop", n)` 的**派生流**，不碰 `run_rng`（R312 口径）——
	## 战斗结算里多抽一个 `run_rng` 会把同一种子下后续的道具 / 关卡整体推歪。
	## 序号 `tool_roll_seq` 每场结算 +1（与「摇没摇中」「有没有空位」无关），
	## 所以同一条种子不会被摇第二遍，续档之后也不会。
	##
	## R695（用户口径「我希望满栏掉落」）：**满栏照掉**。旧版在满栏时直接 `return -1`，
	## 于是 3/3 的玩家永远刷不出工具、10% 变成 0% —— 而「装不进去」这件事已经有出路了
	## （工具栏的 × 可以丢弃旧工具；奖励页里满栏时会摊开 3 个旧工具让你换下一个）。
	## ⚠️ 别在这里判空位：判空位的唯一消费口是 `gain_trap()` 自己。
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of("tool_drop", tool_roll_seq)
	tool_roll_seq += 1
	# R754 祭拜祝福（事件「奇异雕像」）：pledge > 0 时这一场**不看概率、必掉一件**，
	# 然后 -1。⚠️ 必须在 `randf()` 之前分流：祝福不是「提高概率」而是「保证掉落」，
	# 先摇一次概率再覆盖会让同一个种子在「祝福 / 不祝福」之间产生不同的随机流。
	# R796 兔脚：概率**加算**（0.10 → 0.20）。放在 `randf()` 之前只算一个数，
	# 不改变随机流的消费次数 —— 拿没拿兔脚，同一个种子摇出的那一颗 randf() 是同一颗。
	var drop_chance := TOOL_DROP_CHANCE
	if has_relic(RABBIT_FOOT_RELIC_ID):
		drop_chance += RABBIT_FOOT_TOOL_DROP
	if tool_drop_pledge > 0:
		tool_drop_pledge -= 1
	elif rng.randf() >= drop_chance:
		return -1
	# R743：`random_traps()` —— 烤肉 7007 是 `rest_only`，只能从休息处烤出来，
	# 不能靠打怪掉落刷出来（否则「篝火专属」的名头与实际不符）。
	var pool: Array[TrapData] = TrapRepo.load_json().random_traps()
	if pool.is_empty():
		return -1
	return int(pool[rng.randi() % pool.size()].id)


static func grant_random_tool(tag: String) -> int:
	## R745：工具箱（6068）**唯一发工具口** —— 「获得即给一个」与「每进新层给一个」共用。
	## 池子走 `TrapRepo.random_traps()`：烤肉 7007 是 `rest_only`，不进随机池。
	## 随机流走 `seed_of("toolbox_tool", n)` 的**派生流** + 独立序号 `toolbox_tool_seq`
	## （不碰 `run_rng`）：多拿一个工具不该把同一种子下的地图 / 掉落整体推歪（R312 口径）。
	## 满栏（3/3）时不硬塞、也不让玩家白拿：转进「待领奖励」队列，由奖励页按 R695 的
	## 「满栏时摊开旧工具换下一个」处理 —— 与战斗掉落工具同一条出路。
	## 返回发放的工具 id（-1 = 池空，正常不会发生）。
	var pool: Array[TrapData] = TrapRepo.load_json().random_traps()
	if pool.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	## `tag` 参与派生流：「起点拿到的」与「换层发的」各自成流，日志里一眼看出是哪个口发的。
	rng.seed = seed_of("toolbox_tool_" + tag, toolbox_tool_seq)
	toolbox_tool_seq += 1
	var id := int(pool[rng.randi() % pool.size()].id)
	if gain_trap(id):
		return id
	queue_tool_reward(id)
	return id


static func fill_toolbar_with_shop_tools() -> int:
	## R752 快送鸭 7010：「用随机商店工具填满你的工具栏」的**唯一口**。
	## 池子 = `TrapRepo.shop_traps()`（= 有售价的、货架上真买得到的那些）——
	## 用户口径「也就是仅商店可以买到的工具」：万能牌 / 快送鸭 / 神秘牌自己不在池里，
	## 否则会出现「快送鸭刷出快送鸭」的自指连锁。
	## 随机流走 `seed_of("tool_deliver", n)` 的**派生流** + 独立序号 `tool_deliver_seq`
	## （不碰 run_rng，同 R694 / R745 口径）；序号随存档走，同一条种子不会被摇第二遍。
	## 返回真正填进去的件数。**满栏时不覆盖已有工具**（只在空槽里填）——
	## 「填满」不是「换一批」，玩家手里的东西不该被这个效果顶掉。
	## ⚠️ 调用方（`GameEngine.use_tool`）必须**先把快送鸭自己那一格腾空**再调这里，
	##    否则「用掉自己 + 填满」两件事差一格（见 `use_tool` 的 fill_toolbar 分支）。
	var pool: Array[TrapData] = TrapRepo.load_json().shop_traps()
	if pool.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	var filled := 0
	for i in traps.size():
		if int(traps[i]) >= 0:
			continue
		rng.seed = seed_of("tool_deliver", tool_deliver_seq)
		tool_deliver_seq += 1
		traps[i] = int(pool[rng.randi() % pool.size()].id)
		filled += 1
	return filled


static func bless_tool_drops(n: int) -> void:
	## R754 事件「奇异雕像」· 祭拜：**接下来 n 场战斗必定掉落工具**。
	## 口径是「倒计时」而不是「累加」：已经挂着 2 场、又祭拜一次 → 取 max(2, 3) = 3，
	## 玩家看到的永远是「接下来三场」，不会因为多拜一次变成六场（那读起来像 bug）。
	## 只由事件页调用；消耗在 `roll_battle_tool_drop()` 里（唯一口）。
	var want := maxi(0, n)
	if want <= 0:
		return
	tool_drop_pledge = maxi(tool_drop_pledge, want)


static func fill_toolbar_with_stones() -> int:
	## R754 事件「奇异雕像」· 摧毁：「用石头填满你的工具栏」。
	## 与快送鸭（R752）同一条口径：**只在空槽里填，不覆盖已有工具** ——
	## 「填满」不是「换一批」，玩家手里的东西不该被这个效果顶掉。
	## 石头（7012）没有 `price`、带 `no_drop`：不会出现在商店与随机掉落里，
	## 唯一的来路就是这里（以及事件本身）。返回真正填进去的块数。
	var filled := 0
	for i in traps.size():
		if int(traps[i]) >= 0:
			continue
		traps[i] = STONE_TOOL_ID
		filled += 1
	return filled


static func queue_tool_reward(id: int) -> bool:
	## R694：掉落的工具入队（与道具掉落**同一套**「先看后领」口径）——
	## 奖励页里带它自己的图标与完整说明（商店里那份 desc），点「领取」才真进工具栏。
	## 返回是否入队成功（id 非法返回 false）。
	if id <= 0:
		return false
	_drop_settled_batch()
	var oid := Telemetry.note_tool_offer([id], _tele_src(), _tele_ctx())
	pending_rewards.append({"kind": "tool", "id": id, "state": REWARD_PENDING, "tel": oid})
	return true


static func gain_relic(id: int) -> void:
	## 获得道具：登记进列表；即时类当场结算。
	if relics.has(id):
		# R367：之前**耗尽**过的（盆碎过 / 绳子用掉过）不算重复持有 —— 拿回来就重新
		# 生效、从灰里复活；只有「还活着的那件」才是真的重复（直接 return）。
		#
		# R470（用户报「鸭血获取后没有可以选择复制卡」）：**一次性选卡类即时道具**
		# （鸭血 6024 / 源数之力 6002 / 失忆药水 6004）的效果活在 `pending_relic` 上，
		# 道具栏里那枚徽章只是「领过」的凭证，用完不会进 `spent_relics` ——
		# 于是第二次拿到时会被上面那条「还活着 = 真重复」拦掉，**既不弹选卡也不提示**，
		# 玩家白拿一次。它们的一次性语义就是「每拿一次生效一次」，不参与重复持有判定。
		# R470 追加：燧石 6057 同构 —— 效果活在 `pending_relic` 上（回地图点一格），
		# 点完只清 pending、徽章永久留在 `relics` 里 → 不放行的话第二块燧石
		# 连选格模式都进不去，和鸭血是完全一样的病。
		var once_pick := id == DUCK_BLOOD_RELIC_ID or id == SOURCE_POWER_ID \
				or id == FORGET_POTION_ID or id == FLINT_RELIC_ID
		if not once_pick and not spent_relics.has(id):
			return
		spent_relics.erase(id)
	else:
		relics.append(id)
		# R346 成就统计：「首次获得道具 XX」这类成就读的就是这条计数（>= 1 即首次）。
		# ⚠️ 放在 `relics.has(id)` 之后 —— 重复获得不再计数（本局同一件只拿一次）。
		ProfileData.bump(ProfileData.K_RELIC_GOT + str(id))
	var relic := RelicRepo.load_json().get_relic(id)
	if relic == null:
		return
	match relic.id:
		6001:   # 类固醇（R340：+6 → +10）：最大生命 +10（当前生命同 +10）
			max_hp += 10
			hp += 10
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
		APPLE_RELIC_ID:   # 苹果（R224/244/445/756）：立即 +7 最大生命，并回复 20% 最大生命值
			gain_max_hp(APPLE_MAX_HP)
			hp = mini(max_hp, hp + int(round(max_hp * APPLE_HEAL_PCT)))
		PACK_RELIC_ID:   # 行囊（R244）：+100 金币 + 一张「木栅栏」进卡组
			gold += PACK_GOLD
			_grant_linked_card(relic, PACK_CARD_ID)   # 内部会 ensure_deck_mods()
		TOOLBOX_RELIC_ID:   # 工具箱（R745）：立即给一个随机工具（换层再给，见 advance_layer）
			grant_random_tool("gain")
		POT_RELIC_ID:   # 陶罐（R245）：随机 2 件奖励道具 + 一张「罐子」诅咒进卡组
			_apply_pot(relic)
		BOX_RELIC_ID:   # 惊奇盒子（R341）：把一张「惊奇盒子」加进卡组
			# R476：**读 relics.json 的 `card` 字段**（6047 → 9179）。之前这条写死
			# `add_card(BOX_CARD_ID)`，而界面完全不知道这件道具对应哪张卡 ——
			# 用户在起点事件里点开「惊奇盒子」只能读到一句中文描述，看不到卡片本身。
			_grant_linked_card(relic, BOX_CARD_ID)
		MILK_RELIC_ID:   # 牛奶（R224）：随机两种附魔，附给能附魔的卡
			_apply_milk()
		BASIN_RELIC_ID:   # 不锈钢盆（R311）：拿到就满 10 点计数
			basin_charge = BASIN_MAX
		MATCH_RELIC_ID:   # 火柴（R342）：拿到就满 3 次刷新
			match_charge = MATCH_CHARGES
		DICE_RELIC_ID:   # 水晶骰子（R312）：**当前这张图**的非固定房间当场变「?」并重摇内容
			reroll_map_as_unknown()
		NOTE_RELIC_ID:   # 冒险笔记（R447）：随机一个未探索房间变成大宝箱 + 图上亮一圈金光
			note_reveal_bigchest()
		FLINT_RELIC_ID:  # 燧石（R447）：要玩家在地图上点一格走过的房间 → 回地图后进选格模式
			pending_relic = relic.id
		JEWELRY_BOX_RELIC_ID:   # 首饰盒（R830）：随机一张史诗卡加入卡组
			_grant_random_epic()


static func _grant_linked_card(rel: RelicData, fallback := -1) -> void:
	## R476：「这件道具往卡组加哪张卡」的唯一发卡口。
	## 以 relics.json 的 `card` 字段为准（`RelicData.granted_card()`）；
	## 数据漏字段时回落 `fallback`（调用方传的老常量），**绝不静默少发一张卡**。
	## ⚠️ 别在这里写 `if id == 6047` 这类分支 —— 数据驱动就是为了让界面和逻辑同源。
	if rel == null:
		if fallback > 0:
			add_card(fallback)
		return
	var cid := rel.granted_card()
	if cid <= 0:
		cid = fallback
	if cid > 0:
		add_card(cid)


static func _grant_random_epic() -> void:
	## 首饰盒（6088，R830）：随机一张**史诗卡**（本职业奖励池里稀有度 2 的卡）加入卡组。
	## 复用湖中仙女·诚实的同一条抽卡口（LAKE_EPIC_RARITY = 2）；随机源走 run_rng → 同种子一致。
	var rolled := CardReward.roll_rarity(CardRepo.load_json(), LAKE_EPIC_RARITY, 1, run_rng)
	if rolled.is_empty():
		return
	var c: CardData = rolled[0]
	add_card(c.id)


static func _apply_pot(rel: RelicData = null) -> void:
	## 陶罐（6032，R245）：随机拿 **2 件奖励道具**（不与已拥有的 / 本局跳过过的重复），
	## 再塞一张「罐子」（9157）诅咒进卡组。
	## 随机源走 `run_rng` → 同一种子必然同样的两件；抽中的即时道具（牛奶等）照常递归结算。
	## ⚠️ 池子空了就少给（奖励池只有 11 件，理论上不会，但别让边界炸掉）。
	# R314：两件各走一次 `roll_reward_relic()`（传奇判定同样生效）；
	# `exclude` 传已抽到的 id，保证两件不重复（原实现靠从池子里 pop 达到同样效果）。
	var got: Array = []
	for _i in POT_RELIC_COUNT:
		var pick := roll_reward_relic(false, got)
		if pick < 0:
			break
		got.append(pick)
		gain_relic(pick)
	# R476：罐子也走 `card` 字段（6032 → 9157），漏字段回落常量。
	_grant_linked_card(rel, JAR_CURSE_ID)


static func all_class_rewards() -> bool:
	## R246 兼修（6033）：卡牌奖励与商店是否放开职业限制（出现所有职业的卡牌）。
	## 消费点 = `CardReward.roll()` 的默认 cid 分支（奖励悬浮窗 / 商店共用那一条）。
	return relics.has(VERSATILE_RELIC_ID)


static func enchant_master_on_rest() -> Dictionary:
	## R246 附魔大师（6034）：每次在篝火处休息 → **随机一张卡** + **随机一个合规附魔**。
	## 合规判据唯一口 = `enchant_ok()`（damage 只给伤害技能 / dimension 只给盟友工事 / …），
	## 所以「罐子」这类诅咒、已附魔的卡都不会被瞎附。
	## 随机一律走 `run_rng`（同种子重放一致）。返回 {ok, idx, card, ench}。
	if not relics.has(ENCHANT_MASTER_RELIC_ID):
		return {"ok": false}
	var pool: Array[String] = []
	for eid: String in CardData.random_enchant_ids():
		if not _milk_targets(eid).is_empty():
			pool.append(eid)
	if pool.is_empty():
		return {"ok": false, "reason": "no_target"}
	var eid2: String = pool[run_rng.randi() % pool.size()]
	var idxs := _milk_targets(eid2)
	if idxs.is_empty():
		return {"ok": false, "reason": "no_target"}
	var idx: int = idxs[run_rng.randi() % idxs.size()]
	if not enchant_deck_card(idx, enchant_mod(eid2)):
		return {"ok": false}
	var c := CardRepo.load_json().get_card(deck_ids[idx])
	return {"ok": true, "idx": idx, "ench": eid2,
			"card": c.card_name if c != null else "?"}


static func is_card_banned(id: int) -> bool:
	## 奖励池禁卡的**唯一判据**（R352）—— `CardRepo.reward_pool()` 读它。
	##   * 局内（`run_active`）→ 只认**开局快照** `run_bans`；
	##   * 局外（标题 / 图鉴 / 演示 / 测试）→ 退回账号表「任意职业禁过都算禁」。
	## ⚠️ 别在别处直接读 `ProfileData.bans_of()` 去过滤奖励池：那会让局外改禁卡表
	##    立刻影响正在进行的这一局，与用户口径冲突。
	if run_active:
		return run_bans.has(id)
	return ProfileData.is_banned_any(id)


static func has_relic(id: int) -> bool:
	## R367：**「还有没有效」的唯一判据** —— 已耗尽（灰掉）的在这里一律 false。
	return relics.has(id) and not spent_relics.has(id)


# ---- R543 信物（解锁第三层所需的信物）----

static func has_key(id: int) -> bool:
	## 是否持有某一样信物（信物与道具分开记账，见 `key_relics`）。
	return key_relics.has(id)


static func gain_key(id: int) -> bool:
	## 获得一样信物（幂等：已有则不再重复记）。返回是否真的新获得。
	if key_relics.has(id):
		return false
	key_relics.append(id)
	return true


static func has_all_keys() -> bool:
	## 是否凑齐三样信物（完美螺钉 / 生命之种 / 屠戮匕首）。
	for k: int in KEY_RELIC_IDS:
		if not key_relics.has(k):
			return false
	return true


static func third_layer_locked() -> bool:
	## 第三层是否被「上锁」约束：难度 ≥ 11 时，需要凑齐三样信物才能进入。
	## ⚠️ 难度 0~10 下第三层照常开放（用户明确「任何难度都开放第三层」）。
	return _diff() >= DIFF_LOCK_FROM


static func can_enter_third_layer() -> bool:
	## 能否进入第三层：难度 < 11 恒可进；难度 ≥ 11 需要凑齐三样信物。
	if not third_layer_locked():
		return true
	return has_all_keys()


static func key_relic_name(id: int) -> String:
	## 信物显示名（唯一口）。
	match id:
		SCREW_RELIC_ID:
			return "完美螺钉"
		SEED_RELIC_ID:
			return "生命之种"
		DAGGER_RELIC_ID:
			return "屠戮匕首"
	return "信物"


static func key_relic_desc(id: int) -> String:
	## 信物描述（用户口径：统一为「解锁第三层所需的信物」）。
	return "解锁第三层所需的信物"


static func key_relic_source(id: int) -> String:
	## R553：信物获取途径（地图左下角悬停「未获得」图标时的提示文案，唯一口）。
	##   * 完美螺钉 6061 —— 第二层 Boss 掉落 → 「BOSS 战斗」
	##   * 生命之种 6062 —— 大宝箱二选一 → 「藏在宝箱中」
	##   * 屠戮匕首 6063 —— 商店第三排售卖 → 「可以买到」
	match id:
		SCREW_RELIC_ID:
			return "BOSS 战斗"
		SEED_RELIC_ID:
			return "藏在宝箱中"
		DAGGER_RELIC_ID:
			return "可以买到"
	return ""


static func is_relic_spent(id: int) -> bool:
	## 还挂在栏里、但已经用尽（画灰 + 状态注）。
	return relics.has(id) and spent_relics.has(id)


static func spend_relic(id: int) -> bool:
	## 消耗型道具**用尽**（R367），返回是否真的用掉：
	##   * 不锈钢盆（6041）计数归零 / 商店抵账 → 灰；
	##   * 洞窟绳（6048）逃跑用掉 → 灰。
	## 与 `lose_relic()` 的区别：**不移出道具栏**，只在 `spent_relics` 里记一笔。
	## R743：烤肉已改成**工具**（7007），根本不在这套「道具」体系里 —— 工具的消耗走
	## `RunState.consume_trap(slot)`，用掉即摘槽，与「灰在栏里」互不相干。
	if not relics.has(id) or spent_relics.has(id):
		return false
	if id == BASIN_RELIC_ID:
		basin_charge = 0
	spent_relics.append(id)
	return true


static func active_relics() -> Array[int]:
	## 引擎侧道具列表（**排除已耗尽**）。`engine.self_relics` 一律挂这一份 ——
	## 否则灰掉的盆 / 绳子在引擎眼里还算「持有」，效果会偷偷继续生效。
	var out: Array[int] = []
	for id: int in relics:
		if not spent_relics.has(id):
			out.append(id)
	return out


static func note_boss_kill(layer: int, key: String, nm: String) -> void:
	## R367：记下「这一层的 Boss 是哪一只」。同一层只留一条（重打 / 续档不重复）。
	for b: Variant in boss_kills:
		if b is Dictionary and int((b as Dictionary).get("layer", 0)) == layer:
			return
	boss_kills.append({"layer": layer, "key": key, "name": nm})


static func can_use_cave_rope(battle_kind: String) -> bool:
	## R341 洞窟绳（6048）：**能不能逃跑的唯一判据口**。
	## 两个条件：① 还带着绳子；② 这场不是 Boss 战（`battle_kind` 由 battle_scene 按关卡
	## tier 写入引擎，与勇气徽章读的是同一个字段）。
	## 按钮显隐与真正的逃跑结算都走这里，免得两处各自写一遍再分叉。
	# R367：走 `has_relic()` —— 绳子用掉后灰在栏里，不能再「逃跑」第二次。
	return has_relic(CAVE_ROPE_RELIC_ID) and battle_kind != "boss"


static func cave_rope_refund() -> void:
	## R772 洞窟绳：逃跑时退还进房扣掉的 1 块巧克力。
	##   * 这一格进房时已经标进 `cleared_ids`（「已探索」），回访不触发战斗，也就不会反复退还；
	##   * 第三层不收步数（每格 cost 恒 0）→ 不返还；
	##   * 走 add_chocolate：巧克力从 0 回到 1 时顺手撤销 boss_pending（最后一格逃了不算入夜）。
	if current_layer == GameLayers.LAYER_THREE:
		return
	add_chocolate(1)


static func lose_relic(id: int) -> bool:
	## 失去道具（R311）：不锈钢盆 6041 / 洞窟绳 6048 这类「用完就走」的统一出口。
	## 返回是否真的失去了（本来就没有 → false）。
	## ⚠️ 不锈钢盆归零要顺手清 `basin_charge`：否则以后再拿到同 id 时，
	##    `gain_relic` 里那条「已持有就 return」会带着旧计数进来（看似给了 0 点）。
	if not relics.has(id):
		return false
	if id == BASIN_RELIC_ID:
		basin_charge = 0
	# R367：真正「从栏里消失」的路径也要把灰显标记清掉，
	# 免得以后再拿到同 id 时带着「已耗尽」进来。
	spent_relics.erase(id)
	relics.erase(id)
	return true


static func has_basin() -> bool:
	## 不锈钢盆还在用吗（持有 **且** 计数 > 0）。**唯一判据口** —— 商店 / 战斗共用，
	## 免得两处各自写一遍「有道具但没有点数」的边界。
	return relics.has(BASIN_RELIC_ID) and basin_charge > 0


static func basin_pay() -> bool:
	## 商店抵账（R311，用户口径）：**不付金币，改为失去不锈钢盆**。
	## 返回是否抵账成功（没有盆 / 已归零 → false，调用方照常收金币）。
	if not has_basin():
		return false
	# R367：抵账也是「用完」—— 盆留在栏里画灰，不再凭空消失。
	return spend_relic(BASIN_RELIC_ID)


static func dice_map_rng() -> RandomNumberGenerator:
	## 水晶骰子（6040）的**重摇流**（R312）：按 (run_seed, 层) 派生，与 `run_rng` 完全隔离。
	## ⚠️ 用「当前层」当序号：同一层不管调几次都是同一条流 → 重摇可复现、
	##    而且「换层生成」与「拿到当刻重摇」用的是同一条流（幂等）。
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of("dice_map", current_layer)
	return rng


static func reroll_map_as_unknown(cells: Array = []) -> int:
	## R312 水晶骰子：把一张地图上「除固定房间外、且还不是 ? 的」格子**重摇内容**。
	## 空数组 = 当前局的 `map_cells`（拿到道具当刻用）；返回重摇格数。
	## 实现在 `RogueMap.reroll_as_unknown()`（判据 / 权重唯一口，生成期与当刻共用一套）。
	## ⚠️ 幂等：已经是「?」的格子不会重摇，所以「换层生成过」之后再调一次是空操作。
	var arr: Array = cells if not cells.is_empty() else map_cells
	if arr.is_empty():
		return 0
	# R374：重摇同样受「一局只出一次」约束，并且**就地写回账本**（全局字典传引用）。
	return RogueMap.reroll_as_unknown(arr, dice_map_rng(), current_layer, event_kinds_used)


static func offer_relic_drop(node_type: String) -> int:
	## 精英 / Boss 战斗胜利：从奖励池随机掉落一个道具（不与已拥有的、
	## 以及本局曾被「跳过」的重复 —— 跳过表示不想要，后续不再随机出来）。
	## 掉落登记到 pending_relic_drop，由奖励界面领取；没有可掉落的返回 -1。
	if node_type != "elite" and node_type != "boss":
		return -1
	# R314：掉落也走同一个抽取口 → 传奇概率（5% × 层数）对精英 / Boss 同样生效。
	# ⚠️ 精英 / Boss **不算**大宝箱，不翻倍。
	# R390（用户口径）：**Boss** 再吃一层 ×3 —— 走 `legendary_chance` 的 boss 参数，
	# 不在这里自己乘一份，概率的唯一口仍在那边。
	pending_relic_drop = roll_reward_relic(false, [], node_type == "boss")
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


static func legendary_chance(bigchest := false, boss := false) -> float:
	## R314（用户口径）：获得道具时「5% × 当前层数」的概率出**传奇**；大宝箱翻倍。
	## R390（用户口径）：**Boss 关卡**再 ×3（`BOSS_LEGEND_MULT`）。
	## ⚠️ `boss` 缺省 false —— 精英 / 宝箱 / 其它调用的语义一个字都不变。
	## 唯一口 —— 抽取（`roll_reward_relic`）与界面提示都读这里，别各算一份。
	var layer := maxi(1, int(current_layer))
	var p := LEGEND_CHANCE_PER_LAYER * float(layer)
	if bigchest:
		p *= BIGCHEST_LEGEND_MULT
	if boss:
		p *= BOSS_LEGEND_MULT
	return clampf(p, 0.0, 1.0)


static func _reward_pool(tier: String, exclude: Array = []) -> Array[int]:
	## 某一档里「尚未拥有、也未被跳过」的奖励道具 id。
	var pool: Array[int] = []
	for id in RelicRepo.load_json().reward_ids(tier):
		if not relics.has(id) and not skipped_relics.has(id) and not exclude.has(id):
			pool.append(id)
	return pool


static func roll_reward_relic(bigchest := false, exclude: Array = [],
		boss := false) -> int:
	## 随机一件奖励道具（没有可给的返回 -1）。
	## R314：**先按「5% × 层数」摇一次传奇判定**（大宝箱翻倍）——
	##   * 命中且传奇池非空 → 从传奇池取；
	##   * 否则从一般池取；一般池空了才回落到传奇池（不让「只差传奇没拿」变成「什么都不给」）。
	## ⚠️ 传奇池为空时**不消耗**那次 randf：池子状态本身就决定了结果，白花一个随机数
	##    只会让「同一 seed 下拿到的道具顺序」凭空错位（可复现但不必要）。
	var leg := _reward_pool(RelicData.TIER_LEGENDARY, exclude)
	if not leg.is_empty() and run_rng.randf() < legendary_chance(bigchest, boss):
		return leg[run_rng.randi() % leg.size()]
	var nor := _reward_pool(RelicData.TIER_NORMAL, exclude)
	if nor.is_empty():
		if leg.is_empty():
			return -1
		return leg[run_rng.randi() % leg.size()]
	return nor[run_rng.randi() % nor.size()]


static func roll_legendary_relic(exclude: Array = []) -> int:
	## R807：**必定传奇**的一件奖励道具（事件「诡异洋房 · 探索」的报酬之一）。
	## 与 `roll_reward_relic()` 的分工：那个按「5% × 层数」摇档位，这个直接锁死传奇池。
	## ⚠️ 传奇池空了返回 **-1**，**不回落一般池** —— 悄悄塞一件一般的进去，
	##    卡面上承诺的「传奇」就成了假话；调用方要自己决定「池子空了怎么办」。
	## ⚠️ 只消耗**一个** randi（不先摇 randf 判档）：档位已经固定，多摇一个随机数
	##    只会让同一 seed 下的道具序列凭空错位。
	var leg := _reward_pool(RelicData.TIER_LEGENDARY, exclude)
	if leg.is_empty():
		return -1
	return leg[run_rng.randi() % leg.size()]


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
	# R757 遥测：道具掉落同样是一组「只有一件的候选」—— 领不领都要进分母，
	# 「这件东西摆在这儿没人要」正是道具强度与出现时机最直接的反馈。
	var oid := Telemetry.note_relic_offer([id], _tele_src(), _tele_ctx())
	pending_rewards.append({"kind": "relic", "id": id, "state": REWARD_PENDING, "tel": oid})


# ------------------------------------------------------------ R454 熔炉（furnace 事件）
## 熔炉：把身上一件道具投进炉子，换回随机道具 —— 投的是**传奇档**就换回两件。
## 判据全部收在这里（可投池 / 投入结算），事件页只负责铺按钮与文案。
const FURNACE_OPTIONS := 3          # 最多铺几个「投入 XXXX」选项
const FURNACE_LEGEND_REWARDS := 2   # 投入传奇档道具 → 换回几件


static func _pick_random_ids(src: Array[int], n: int) -> Array[int]:
	## 从 src 里随机取 n 个**不重复**的（走 run_rng；src 本身不被打乱）。
	var pool: Array[int] = src.duplicate()
	var out: Array[int] = []
	while out.size() < n and not pool.is_empty():
		var i: int = run_rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func furnace_options() -> Array[int]:
	## 熔炉本次铺出来的可投入道具（最多 3 件、互不重复）。
	## **优先「奖励」来源**（用户口径）：先尽量从奖励道具里取，凑不满 3 件再拿其它来源补。
	## 已经耗尽的（灰在栏里）**不算** —— 投一件已经没效的东西换奖励不合道理。
	var reward: Array[int] = []
	var other: Array[int] = []
	var repo := RelicRepo.load_json()
	for id: int in relics:
		if spent_relics.has(id):
			continue
		var r := repo.get_relic(id)
		if r != null and r.source == RelicData.SRC_REWARD:
			reward.append(id)
		else:
			other.append(id)
	var out: Array[int] = _pick_random_ids(reward, FURNACE_OPTIONS)
	if out.size() < FURNACE_OPTIONS:
		for id: int in _pick_random_ids(other, FURNACE_OPTIONS - out.size()):
			out.append(id)
	return out


static func furnace_invest(id: int) -> Dictionary:
	## 投入一件道具 → 失去它，换回随机奖励道具并入**待领队列**。
	## 返回 {"ok": bool, "legendary": bool, "rewards": Array[int]}。
	## ⚠️ 投出去的那件从候选池里排除（用户口径「不会再摇回来」）；
	##    两件奖励之间也要互斥 —— 入队**不等于**已拥有，不显式排除会摇出同一件。
	## ⚠️ 只认 `has_relic()`（已耗尽的不能投），别用 `relics.has()`。
	if not has_relic(id):
		return {"ok": false, "legendary": false, "rewards": []}
	var rel := RelicRepo.load_json().get_relic(id)
	var legendary: bool = rel != null and rel.is_legendary()
	if not lose_relic(id):
		return {"ok": false, "legendary": false, "rewards": []}
	var want: int = FURNACE_LEGEND_REWARDS if legendary else 1
	var exclude: Array = [id]
	var got: Array[int] = []
	for _i in want:
		var rid: int = roll_reward_relic(false, exclude)
		if rid <= 0:
			break
		exclude.append(rid)
		got.append(rid)
		queue_relic_reward(rid)
	return {"ok": true, "legendary": legendary, "rewards": got}


static func queue_card_reward(reward_type: String = "normal",
		kinds: Array[String] = [], src := "") -> int:
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
	# R757 遥测：**候选摆出来的这一刻**就要记账 —— 这是「选择率」的分母。
	# 玩家选不选是下一步的事，但「曾经有这三个选项」只在此刻存在，晚记一位都补不回来。
	var oid := Telemetry.note_card_offer(ids, src if src != "" else _tele_src(), _tele_ctx())
	pending_rewards.append({"kind": "cards", "type": reward_type,
			"kinds": kinds.duplicate(), "candidates": ids, "picked": -1,
			"state": REWARD_PENDING, "tel": oid})
	return pending_rewards.size() - 1


static func queue_fixed_card_reward(card_id: int, legendary := false) -> int:
	## R467：**指定卡**的卡牌奖励（洞穴的传说卡「枭熊」9213）。返回队列下标（-1 = 无效）。
	##
	## 与 `queue_card_reward()` 的分工：那个按稀有度权重摇三张候选，这个把 `card_id`
	## 直接摆成**唯一候选**。相同的地方：
	##   * 只是「入队」—— 玩家仍要在奖励页点「确认选择这张」，`pick_pending_card()` 才真进卡组；
	##   * 走同一条 `pending_rewards` 通道 → R340「一批没处理完不许换场景」照样管得住它。
	## 不同的地方：**不消耗 `run_rng`**（不摇候选），所以回放的种子序列不受这张固定奖励影响。
	## `legendary = true` → 奖励页播一次揭示动画（`RewardPanel` 读这个标记，不动抽卡逻辑）。
	if card_id <= 0:
		return -1
	_drop_settled_batch()
	# R757 遥测：指定卡（洞穴的传说卡）也是「一组候选」，只是只有一张 —— 照样入分母，
	# 否则分析时会看到一个从没被提议过的 id，永远算不出选择率。
	var oid := Telemetry.note_card_offer([card_id], "event", _tele_ctx())
	pending_rewards.append({"kind": "cards", "type": "legendary", "kinds": [],
			"candidates": [card_id], "picked": -1,
			"state": REWARD_PENDING, "legendary": legendary, "tel": oid})
	return pending_rewards.size() - 1


static func queue_battle_card_rewards(reward_type: String = "normal",
		src := "") -> int:
	## 战斗胜利后的卡牌奖励**唯一入队口**（battle_scene 只调这里，别直接调
	## `queue_card_reward`）。持有采集刀 6050（传奇）→ 额外再来一组。
	## 返回实际入队的组数（卡池空、摇不出候选的那一组不算）。
	## ⚠️ 组与组之间是**各自独立的三选一**（各有自己的 candidates），不是把 3 张变 6 张 ——
	##    用户可以各选一张，也可以只选一组、放弃另一组。
	## ⚠️ `queue_card_reward` 内部会试清上一批；第一批入队后待领数 > 0，
	##    第二批就不会再清（`_drop_settled_batch` 只在待领为 0 时动手），同一批里两条并存。
	var groups := 1
	if relics.has(HARVEST_KNIFE_RELIC_ID):
		groups += HARVEST_KNIFE_EXTRA
	var queued := 0
	for _i in groups:
		if queue_card_reward(reward_type, [], src) >= 0:
			queued += 1
	return queued


static func queue_deck_delete_reward(count: int = 1) -> int:
	## R351 月亮（9180）：战斗结束后往奖励队列里多塞一条「从卡组删除一张卡」。
	## 返回队列下标（-1 = 无效）。
	## 走的是**同一条** `pending_rewards` 通道 —— 所以 R340 的「一批奖励没处理完
	## 不许跳场景 / 不许换层」对它同样生效（`pending_reward_count()` 会数到它）。
	if count <= 0:
		return -1
	_drop_settled_batch()
	pending_rewards.append({"kind": "deck_delete", "count": count,
			"state": REWARD_PENDING})
	return pending_rewards.size() - 1


# ---------------------------------------------------------------- R531 精英追加奖励
## 用户口径（R531）：精英战原来**固定**送一次删卡，改成按概率摇一项「追加奖励」。
## 权重合计必须 = 100（`test_engine` 有一条断言守着）；数组顺序即判定顺序，别随手调。
const BONUS_HP := "maxhp"
const BONUS_CARDS := "cards"
const BONUS_DELETE := "delete"
const BONUS_GOLD := "gold"
const BONUS_RELIC := "relic"
const BONUS_HP_GAIN := 7          ## 25%：最大生命 +7（当前生命同时 +7 = 顺便回血）
const BONUS_GOLD_GAIN := 50       ## 20%：额外 50 金币
const BONUS_RULES: Array = [
	{"type": BONUS_HP, "weight": 25},
	{"type": BONUS_CARDS, "weight": 30},
	{"type": BONUS_DELETE, "weight": 15},
	{"type": BONUS_GOLD, "weight": 20},
	{"type": BONUS_RELIC, "weight": 10},
]


static func is_direct_reward(kind: String) -> bool:
	## R535：「直接到账」型奖励（金币 / 最大生命）—— **没有详情页、没有候选**，
	## 点开它就是领（`claim_pending_reward` 当场入账）。
	## ⚠️ 唯一判据口：奖励页 `_open_entry()` 的「点开 = 领取」、领取 / 放弃两支都读这里。
	##    旧版三处各写一遍 `kind == BONUS_GOLD or kind == BONUS_HP`，界面那一处漏了，
	##    于是这两种奖励摊开一个**空的三选一页面**：领不到、只剩「放弃」能点。
	return kind == BONUS_GOLD or kind == BONUS_HP


static func roll_elite_bonus() -> String:
	## 摇一个追加奖励类型（权重见 `BONUS_RULES`）。返回类型常量串。
	## ⚠️ 只消耗**一个**随机数 —— 别在这里顺手多摇一次，同一 seed 下后续的
	##    卡池 / 道具顺序会整体错位（录像复现会跟着坏）。
	var r := run_rng.randi() % 100
	var acc := 0
	for rule: Dictionary in BONUS_RULES:
		acc += int(rule.get("weight", 0))
		if r < acc:
			return str(rule.get("type", ""))
	return str((BONUS_RULES[0] as Dictionary).get("type", ""))


static func queue_elite_bonus(force := "") -> int:
	## 精英胜利后的**追加奖励**入队，返回条目下标（-1 = 没入队）。
	## `force` 非空时跳过摇奖（测试 / 出图用：maxhp / cards / delete / gold / relic）。
	##
	## 实现口径：**不新造奖励种类** —— 一律走原有通道（卡组三选一 / 删卡 / 道具），
	## 只在条目上打 `bonus = true`。奖励页据此画「追加奖励」分隔带，
	## 领取 / 放弃的行为与普通奖励完全一致（不用再教玩家怎么点一遍）。
	## ⚠️ 追加奖励**最后入队** → 天然排在奖励列表末尾（用户口径）。
	var kind := force if force != "" else roll_elite_bonus()
	var idx := -1
	match kind:
		BONUS_HP:
			_drop_settled_batch()
			pending_rewards.append({"kind": BONUS_HP, "hp": BONUS_HP_GAIN,
					"state": REWARD_PENDING})
			idx = pending_rewards.size() - 1
		BONUS_GOLD:
			_drop_settled_batch()
			pending_rewards.append({"kind": BONUS_GOLD, "gold": BONUS_GOLD_GAIN,
					"state": REWARD_PENDING})
			idx = pending_rewards.size() - 1
		BONUS_CARDS:
			idx = queue_card_reward("normal", [], "bonus")
		BONUS_DELETE:
			idx = queue_deck_delete_reward(1)
		BONUS_RELIC:
			# ⚠️ 不能走 `offer_relic_drop()` —— 它写的是**单值** `pending_relic_drop`
			#    （精英本身可能已经掉了一件），会把主掉落挤掉。这里只摇、只入队。
			# ⚠️ 还要**排除队列里已经在等领的那几件**（含主掉落 `pending_relic_drop`）：
			#    那几件只入队、还没 `gain_relic`，奖励池是不知道的 —— 不排除就会
			#    「同一件道具在列表里出现两条」，领第二条时等于白拿。
			var took: Array[int] = []
			for pe: Dictionary in pending_rewards:
				if str(pe.get("kind", "")) == "relic":
					took.append(int(pe.get("id", 0)))
			if pending_relic_drop > 0 and not took.has(pending_relic_drop):
				took.append(pending_relic_drop)
			var rid := roll_reward_relic(false, took, false)
			if rid > 0:
				queue_relic_reward(rid)
				idx = pending_rewards.size() - 1
			else:
				# 道具池已空（全都拥有 / 被跳过）→ 退化成一笔金币，
				# 别让玩家「摇到 10% 却什么都没拿到」。
				_drop_settled_batch()
				pending_rewards.append({"kind": BONUS_GOLD, "gold": BONUS_GOLD_GAIN,
						"state": REWARD_PENDING})
				idx = pending_rewards.size() - 1
	if idx >= 0 and idx < pending_rewards.size():
		(pending_rewards[idx] as Dictionary)["bonus"] = true
	return idx


static func can_reroll_reward() -> bool:
	## 火柴（6051）：「刷新」按钮能不能点的**唯一判据口**（持有 + 还有次数）。
	## 按钮显隐 / 置灰 / 真正刷新都问这里，别在界面里各写一份 `match_charge > 0`。
	return relics.has(MATCH_RELIC_ID) and match_charge > 0


static func reroll_pending_cards(idx: int) -> bool:
	## 火柴（6051）：把第 idx 组卡牌奖励的候选**重摇一遍**，次数 -1。
	## 返回是否真的刷新了（false = 没火柴 / 次数用完 / 这条不是待领的卡牌组 / 摇不出来）。
	##
	## 三条纪律：
	##  ① **排除旧候选**（`exclude_ids`）—— 刷新后不该再看到刚刚那三张，
	##     否则「刷了等于没刷」；池子不够时才允许重复（`CardReward.roll` 内部回退）。
	##  ② 类型 / 卡类限制（`type` / `kinds`）**照旧沿用**：在事件里刷出来的还是那类卡
	##     （例如「奥秘之泉」只在效果/技能里刷），不然火柴能用来绕开事件规则。
	##  ③ `picked` 清回 -1、`rerolls` 记一笔 —— 这条又变回「没选过」的状态。
	## 随机源与 `queue_card_reward` 同口径（run 进行中走 run_rng，演示模式才用全局随机）。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	if not can_reroll_reward():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "cards":
		return false
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	var old_ids: Array[int] = []
	for v: Variant in e.get("candidates", []):
		old_ids.append(int(v))
	var ekinds: Array[String] = []
	for k: Variant in e.get("kinds", []):
		if k is String:
			ekinds.append(str(k))
	var roll_rng: RandomNumberGenerator = run_rng if run_active else null
	var rolled := CardReward.roll(CardRepo.load_json(), str(e.get("type", "normal")),
			CardReward.CHOICES, roll_rng, ekinds, "", old_ids)
	var ids: Array[int] = []
	for c: CardData in rolled:
		ids.append(c.id)
	if ids.is_empty():
		return false       # 摇不出来就别扣次数
	match_charge -= 1
	e["candidates"] = ids
	e["picked"] = -1
	e["rerolls"] = int(e.get("rerolls", 0)) + 1
	return true


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
	# 燧石（6057）**不选卡**：它要的是「在地图上选一格」，由 `map_scene._start_flint_pick()` 收尾。
	# 漏判会原地死循环：地图 `_ready` 判出 deck_edit → 那个场景没有 6057 分支（只剩「自由浏览」）
	# → `leave` 回地图 → 再判一次 → 又送回去。`curtain_scene._leave()` 早就排除了它，这里是「唯一判据口」，口径必须一致。
	if pending_deck_edit != "" or (pending_relic > 0 and pending_relic != FLINT_RELIC_ID):
		return "res://scenes/deck_edit.tscn"
	return ""


static func claim_deck_delete_reward(idx: int, deck_index: int) -> bool:
	## R398（用户报「月亮的效果生效后没有立即进入选卡过程，而是在奖励界面结束后才选卡」）：
	## 月亮的删卡奖励改成**在奖励面板里就地完成** —— 一次调用同时「删掉卡组第 deck_index 张」
	## 和「把这条奖励置为已领」。
	##
	## 旧路是「领下 → `pending_deck_edit = "delete"` → 跳 deck_edit」，但 R340 规定
	## 「本批奖励没处理完**不许跳场景**」（否则会像当年那样把没展示的卡牌奖励甩掉），
	## 于是删卡被一路压到整批结束之后 —— 玩家得先关掉奖励界面才会进选卡。
	##
	## ⚠️ 不能复用 `claim_pending_reward`：那个会把 `pending_deck_edit` 设上，
	##    删完回地图又会跳一次 deck_edit（重复删 / 空待办）。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "deck_delete":
		return false
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	# R414：**带锁的卡（`no_remove`：月亮 9180 / 硬币 / 罐子）一概删不掉**。
	# 以前这里直接调 `delete_deck_card()`，等于给了一条绕过口 —— 谁传个下标进来
	# 就能把月亮删了（界面自己挡了，但数据层没挡，R340「唯一口」的纪律也就破了）。
	if not deck_deletable(deck_index):
		return false
	# `delete_deck_card()` 里有 `pending_relic = -1`（那是失忆药水的待办口径）——
	# 这里不是那条路，别把玩家还没领的即时道具待办顺手清掉。
	var keep_pr := pending_relic
	var ok := delete_deck_card(deck_index)
	pending_relic = keep_pr
	if not ok:
		return false
	e["state"] = REWARD_CLAIMED
	e["deleted"] = deck_index
	return true


static func deck_deletable(index: int) -> bool:
	## R398：卡组第 index 张能不能删 —— 奖励面板的就地删卡与 `deck_edit_scene` 同一判据
	## （只认 `CardData.no_remove`，**不许**在界面里按 id 硬编码）。
	## R472：**只是 `remove_block_reason()` 的布尔外壳** —— 判据只留一处，
	## 别再在这里写第二套规则（商店 / 月亮 / 药水 / 选卡页全都汇到那个函数）。
	return remove_block_reason(index) == ""


static func has_deletable_deck_card() -> bool:
	## R414：卡组里还有没有「能删」的卡（`deck_deletable` 的反向汇总）。
	## 删卡奖励摊开卡组之前先问这一句 —— 一张都删不了时不该把人关进一个点什么都不动的页面。
	for i in deck_ids.size():
		if deck_deletable(i):
			return true
	return false


static func claim_pending_reward(idx: int) -> bool:
	## 领取第 idx 条：道具 → 进道具栏。成功后 state = claimed（悬浮窗里那条置灰）。
	## ⚠️ 卡牌奖励**不走这里**：卡牌必须先在三选一里选一张（pick_pending_card），
	##    没有「空组领取」这回事。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	# R414（用户报「领了删卡奖励没反应、卡组张数一点没变」）：删卡奖励**没有「空手领下」
	# 这回事** —— 它的效果就是删掉一张卡，没挑卡就等于没效果。
	# 旧版在这里把 state 置成 claimed、挂上 `pending_deck_edit = "delete"` 就 `return true`，
	# 于是调用方（AI 桥 / 任何自动化）以为领成功了，实际卡组一张没少；而挂上的那个待办
	# 要么被 R340「本批奖励没处理完不许跳场景」一路压到界面结束之后（就是 R398 用户报的
	# 「效果生效了却迟迟不让选」），要么调用方根本不跳、待办直接烂在存档里。
	# 现在一律**拒绝**：删卡只有一个口 `claim_deck_delete_reward(idx, deck_index)`，
	# 「删掉卡组第 N 张」与「这条置为已领」在同一次调用里完成。界面走
	# `RewardPanel._open_entry()` → 卡组视图（R398 的就地删卡）。
	# R531：追加奖励里两种「直接到账」类型 —— 金币 / 最大生命（上限与当前生命一起涨）。
	# R535：判据收进 `is_direct_reward()` —— 奖励页「点开条目就领」读的是同一句，
	# 别再在每一处单独列 kind（列三遍就一定有一遍会被忘掉，R531 就是这么坏的）。
	if is_direct_reward(str(e.get("kind", ""))):
		if str(e.get("kind", "")) == BONUS_GOLD:
			gain_gold(int(e.get("gold", BONUS_GOLD_GAIN)))
		else:
			gain_max_hp(int(e.get("hp", BONUS_HP_GAIN)))
		e["state"] = REWARD_CLAIMED
		return true
	if str(e.get("kind", "")) == "deck_delete":
		return false
	if str(e.get("kind", "")) == "tool":
		# R694：工具掉落 → 领取时填进工具栏的第一个空槽。
		# 满栏只是**防守分支**（入队那一刻判过有空位，待领期间又进不了战斗 / 商店），
		# 真挤满了就不领、留着 —— 玩家先放弃这条或用掉一个工具再来。
		if not gain_trap(int(e.get("id", 0))):
			return false
		e["state"] = REWARD_CLAIMED
		Telemetry.note_pick(int(e.get("tel", 0)), int(e.get("id", 0)))
		return true
	if str(e.get("kind", "")) != "relic":
		return false
	var rid := int(e.get("id", 0))
	if pending_relic_drop == rid:
		claim_relic_drop()   # 精英 / Boss 掉落走原路径（顺带清掉 pending_relic_drop）
	else:
		gain_relic(rid)      # 宝箱层等：直接进道具栏
	e["state"] = REWARD_CLAIMED
	Telemetry.note_pick(int(e.get("tel", 0)), rid)
	return true


static func skip_pending_reward(idx: int) -> bool:
	## 放弃第 idx 条：道具 → 登记「本局不再随机出来」；卡牌 → 放弃这组候选。
	## 同样置灰（state = skipped）—— 对玩家来说都是「这条已经处理过了」。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	# R440 暗动力（6054）：**卡牌奖励一律不许放弃** —— 这里是「不可放弃」的唯一闸门，
	# 奖励窗的「放弃这组 / 完成」置灰都只是同一判据的显示。
	# 道具奖励与月亮的删卡奖励照旧可放弃（卡面只写了「卡牌奖励」）。
	if str(e.get("kind", "")) == "cards" and relics.has(DARK_POWER_RELIC_ID):
		return false
	# R757 遥测：走到这里就一定会置灰了（唯一的拒绝分支已过）—— 记一次「整组跳过」。
	# 跳过**必须**留在分母里：一组摆出来却没人要，比「没人选」更能说明这张卡有问题。
	Telemetry.note_skip(int(e.get("tel", 0)))
	if str(e.get("kind", "")) == "deck_delete":
		e["state"] = REWARD_SKIPPED
		return true
	# R694：工具掉落可以放弃（放弃不登记任何账本 —— 工具没有「本局不再出」的语义，
	# 下一场战斗照样按 10% 摇）。
	if str(e.get("kind", "")) == "tool":
		e["state"] = REWARD_SKIPPED
		return true
	# R531：金币 / 最大生命也可以放弃（点了就置灰，什么都不发生）。
	# R535：判据走 `is_direct_reward()`（与领取 / 奖励页同一句）。
	if is_direct_reward(str(e.get("kind", ""))):
		e["state"] = REWARD_SKIPPED
		return true
	if str(e.get("kind", "")) == "relic":
		var rid := int(e.get("id", 0))
		if pending_relic_drop == rid:
			skip_relic_drop()
		elif not skipped_relics.has(rid):
			skipped_relics.append(rid)
	# R695：大宝箱二选一走它**自己的**放弃口 —— 那里会把候选奖励道具登记进
	# `skipped_relics`（本局不再随机出来），下面那句「直接置 skipped」会漏掉这笔账。
	if str(e.get("kind", "")) == "relic_or_key":
		return skip_key_choice(idx)
	# 其余（核心兑换 / 任何以后新增的结构性条目）—— 统一置为已处理：
	# 作废窗口（`forfeit_pending_rewards`）必须能把每一条都清掉，
	# 否则一条永远 pending 的条目会跟着整局走、地图入口那个「N」永远不归零。
	e["state"] = REWARD_SKIPPED
	return true


static func forfeit_pending_rewards() -> int:
	## R695（用户口径「允许玩家不拿直接过，但到下一个未探索的格子前都可以回来拿」）：
	## **真正离开这个房间**的那一刻，把还没领的奖励作废 —— 返回作废条数。
	##
	## 为什么需要它：奖励界面上已经没有「放弃这件」了，条目会一直保持 pending
	## （关掉界面不丢，地图左上「✦ 待领奖励 N」随时能回来领）。既然不再是玩家
	## 主动点掉的，就得有个「窗口到期」的落点，否则一条忘了领的奖励会跟着整局走到最后。
	## 窗口的口径只有一句：**走进下一个没探索过的格子之前**（`advance()` 的 is_new 分支、
	## `flyer_teleport()` 的落点、`advance_layer()` 的换层）。
	##
	## ⚠️ 内部走 `skip_pending_reward()` —— 不是另写一套。那里的账（道具要登记
	## `skipped_relics` / `skip_relic_drop()` 清待领掉落、暗动力拒绝放弃卡牌）全都算数，
	## 抄一遍就一定会有一天两边不一致。
	## ⚠️ 暗动力（6054）的卡牌条目这里**不会被作废**（`skip_pending_reward` 拒绝）——
	## 它本来就不许拖到以后，界面上「完成」也一直是灰的，正常玩到不了这一步；
	## 真到了（改档 / 自动化），留着比悄悄吞掉安全。
	var n := 0
	for i in range(pending_rewards.size() - 1, -1, -1):
		if str((pending_rewards[i] as Dictionary).get("state", REWARD_PENDING)) != REWARD_PENDING:
			continue
		if skip_pending_reward(i):
			n += 1
	return n


static func must_take_card_reward() -> bool:
	## R440 暗动力（6054）：手里还有**待领的卡牌奖励**时返回 true ——
	## 奖励窗据此把「放弃这组」置灰、并拦住「完成」（必须拿一张卡才能关掉界面）。
	## 判据只看「有没有 pending 的 cards 条目」，道具 / 删卡奖励不算。
	## R442（用户口径「暗动力应该强制领取卡牌，不应该有可以待领的情况 —— 这是代价」）：
	## 这条判据现在也是**跨场景闸门** —— 结算面板的出口、地图 `_ready` 都读它，
	## 所以持有时不可能靠「关窗 → 走人 → 以后再领」把代价推迟。
	## ⚠️ 本局**真的收尾**（通关 / 失败，`run_finished`）时一律放行：那时 `deck_ids`
	##    已被 `end_run()` 清空，再逼玩家「拿一张卡」只会往空卡组里塞牌。
	if run_finished or not relics.has(DARK_POWER_RELIC_ID):
		return false
	for e: Dictionary in pending_rewards:
		if str(e.get("kind", "")) != "cards":
			continue
		if str(e.get("state", REWARD_PENDING)) == REWARD_PENDING:
			return true
	return false


static func shop_delete_allowed() -> bool:
	## R440 暗动力（6054）：商店的「删除一张卡」还能不能买（唯一判据口）。
	## 商店的绘制 / 点击 / 实际成交都问这一句，别在界面里自己判 id。
	return not relics.has(DARK_POWER_RELIC_ID)


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
	# R757 遥测：把这次「从哪几个里选了谁」配上 —— `oid` 在入队那一刻已经写好。
	Telemetry.note_pick(int(e.get("tel", 0)), card_id)
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
	# R367：已耗尽（灰掉）的优先说清楚 —— 这不是「没有状态」，是**这件已经用完了**。
	if is_relic_spent(id):
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_SPENT", "已耗尽，效果不再生效。")
	if id == STACK_DUCK_RELIC_ID and relics.has(STACK_DUCK_RELIC_ID):
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_REVIVE_CHANCE", "当前复活概率 %d%%。") % duck_revive_chance
	# R314 lucky 7：写清「还差几个回合生效」—— 它的效果是周期性脉冲，不是常亮
	if id == MATCH_RELIC_ID and relics.has(MATCH_RELIC_ID):
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_REROLLS", "剩余刷新次数 %d 次。") % maxi(0, match_charge)
	if id == CRESCENT_EARING_ID and relics.has(CRESCENT_EARING_ID):
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_CRESCENT_WAITING",
				"距获得下一点费用还有 %d 场战斗。") % crescent_left()
	if id == LUCKY7_RELIC_ID and relics.has(LUCKY7_RELIC_ID):
		if lucky7_is_due():
			return GameI18n.ui("reward", "REWARD_RELIC_STATE_LUCKY7_ACTIVE", "本回合生效：免疫所有 HP 伤害 + 技能额外 7 点伤害。")
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_LUCKY7_WAITING", "距下次生效还有 %d 个回合。") % lucky7_left()
	return ""


static func has_barbecue_tool() -> bool:
	## R743：工具栏里有没有烤肉 —— 休息处判「已持有」的唯一口（界面别自己数槽位）。
	return traps.has(BARBECUE_TOOL_ID)


static func can_take_barbecue() -> bool:
	## R743（用户口径「需要有栏位才能获取」）：休息处现在能不能烤：
	##   ① 已经有一份烤肉 → 不能烤第二份（原口径「持有时无法再次烤制」保留）；
	##   ② 工具栏 3/3 满 → 不能烤（判空位只走 `trap_free_slots()`，别在这里另数一遍）。
	return not has_barbecue_tool() and trap_free_slots() > 0


static func take_barbecue() -> bool:
	## R743：休息处烤肉的**唯一获取口** —— 填进第一个空槽。满栏 / 已持有 → false。
	## ⚠️ 不写 `relics`：工具与道具是两套账（见 `traps` 上方的注释），混进去会串高亮。
	if not can_take_barbecue():
		return false
	return gain_trap(BARBECUE_TOOL_ID)


static func remove_block_reason(index: int) -> String:
	## R472：这张卡**现在能不能从卡组删掉**？"" = 能删，否则返回一句给玩家看的原因。
	## 唯一判据口 —— 商店「删除一张卡」/ 月亮 9180 / 失忆药水 6004 / 遗忘之泉 /
	## 选卡页全都读它，界面只负责提前告知与灰化。
	## 带锁的卡只有三张：月亮 9180 / 硬币 9181 / 罐子 9157（`no_remove`）。
	if index < 0 or index >= deck_ids.size():
		return GameI18n.ui("shop", "SHOP_REMOVE_CARD_MISSING", "卡组里没有这一张")
	var c := CardRepo.load_json().get_card(int(deck_ids[index]))
	if c != null and c.no_remove:
		return GameI18n.ui("shop", "SHOP_REMOVE_CARD_LOCKED", "「%s」带锁，不能从卡组删除") % c.card_name
	return ""


static func delete_deck_card(index: int) -> bool:
	## 删掉卡组里第 index 张卡 —— **全游戏唯一的删卡口**。
	## R472（用户报「月亮可以在商店被删掉」）：带 `no_remove` 的卡在这里一票否决。
	## 原来只有卡组编辑页的**界面层**挡了它（`deck_edit_scene._has_no_remove_card()`），
	## 商店的「删除一张卡」是直接调本函数的 —— 于是月亮 / 硬币 / 罐子能绕过界面锁被删掉，
	## 同一件事出现了两条路、两套规则。现在判据只留这一处。
	## R750（用户口径「严格删除展示的卡，包括所有的成长和附魔」）：删掉这张卡之后，
	## 若卡组里**一张该 id 都不剩**，`card_growth` 的那笔账也一并擦掉 —— 否则以后
	## 再抽到同名卡会继承旧成长，等于「卡没了、成长还留着」。
	if index < 0 or index >= deck_ids.size():
		return false
	if remove_block_reason(index) != "":
		return false
	var cid := int(deck_ids[index])   # R750：删完后面的下标全部前移，先记住这是哪一张
	deck_ids.remove_at(index)
	_sync_mods_remove(index)     # R181：附魔下标同步前移
	_reap_card_growth(cid)       # R750（用户口径）：卡走了，它的本局成长账也一并收走
	Telemetry.note_deck_change("del", cid, 0)
	pending_relic = -1
	return true


static func transform_deck_card(repo: CardRepo, index: int, same_class := false) -> Dictionary:
	## 源数之力 / 卡片商人「旧换新」：把卡组中第 index 张卡变成一张随机奖励卡。
	## `same_class = true` 时**只出本职业（或本局职业）的奖励卡**（R305 卡片商人的口径）。
	## 返回 {ok, old_id, new_id}（供界面/日志展示）。
	## ⚠️ R455：这是**战斗外**的卡组变化 → **不是**「随机变化」：不写 `random_born`、
	## 不计入引擎的「变化 N 张」，也不触发发明专家 9143 回费。卡面写的「以随机变化的
	## 方式加入手卡」只认**战斗内**（随心组装 9144 / 创意 8070 / 惊喜运单 8079）。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false, "old_id": 0, "new_id": 0}
	var old_id: int = deck_ids[index]
	# 修复（实机体验）：必须用本局 run_rng —— 否则走全局随机，破坏「同一种子必然一致」的确定性
	var want_cid := ("" if all_class_rewards() else player_class) if same_class else ""
	var rolled := CardReward.roll(repo, "normal", 1, run_rng, [], want_cid)
	var new_id: int = rolled[0].id if not rolled.is_empty() else old_id
	deck_ids[index] = new_id
	if index < deck_mods.size():
		deck_mods[index] = {}       # R181：变形后附魔失效
	_reap_card_growth(old_id)       # R750：旧 id 若已彻底离开卡组，成长账一起走
	Telemetry.note_deck_change("transform", old_id, new_id)
	pending_relic = -1
	return {"ok": true, "old_id": old_id, "new_id": new_id}

# ------------------------------------------------------------ R305：两个新事件的候选 / 动作

static func deck_indices_with_cost(min_cost: int) -> Array[int]:
	## 卡组里**卡面费用 ≥ min_cost** 的卡的下标（卡片商人 · 以卡易物：5 费及以上）。
	## ⚠️ 判据用 `CardData.cost`（卡面费用），**不看附魔减费** —— 「这是不是一张 5 费卡」
	## 是玩家看得见的卡面事实，被减费附魔改一下就不收反而奇怪。
	var out: Array[int] = []
	var repo := CardRepo.load_json()
	for i in deck_ids.size():
		var c := repo.get_card(int(deck_ids[i]))
		# R521：X 费不比任何数大 → 不满足「≥ N 费」
		if c != null and not c.x_cost and c.cost >= min_cost:
			out.append(i)
	return out


static func deck_indices_of_rarity(rarity: int) -> Array[int]:
	## 卡组里指定稀有度的卡下标（湖中仙女 · 谎言：稀有度 3 = 初始卡）。
	var out: Array[int] = []
	var repo := CardRepo.load_json()
	for i in deck_ids.size():
		var c := repo.get_card(int(deck_ids[i]))
		if c != null and c.rarity == rarity:
			out.append(i)
	return out


static func deck_indices_not_curse() -> Array[int]:
	## 卡组里**非诅咒**卡的下标（卡片商人 · 随机折价）。诅咒稀有度 = 6。
	var out: Array[int] = []
	var repo := CardRepo.load_json()
	for i in deck_ids.size():
		var c := repo.get_card(int(deck_ids[i]))
		if c != null and c.rarity != CURSE_RARITY:
			out.append(i)
	return out


static func deck_indices_removable() -> Array[int]:
	## R750：**真能删掉**的卡组下标 —— 非诅咒，且不带 `no_remove` 锁
	## （月亮 9180 / 硬币 9181 / 罐子 9157）。
	##
	## 为什么必须有这个口：只按稀有度过滤诅咒的话，会摇到带锁的卡 —— 按钮上写着
	## 「谎言：失去『月亮』」，点下去 `delete_deck_card()` 被 `remove_block_reason()`
	## 一票否决、卡还在，奖励却照样发出去。**「展示的卡」必须就是「真会被删的卡」**，
	## 否则展示本身就是假的。判据不在各处重写，唯一口 = `remove_block_reason()`。
	var out: Array[int] = []
	for i in deck_indices_not_curse():
		if remove_block_reason(i) == "":
			out.append(i)
	return out


static func random_deck_index(pool: Array[int]) -> int:
	## 从候选下标里随机取一个（只走本局 `run_rng`，同种子必然一致）。空池 → -1。
	## ⚠️ **不许用裸随机调用**：R241/R261 有源码锁（`run_state` 里裸随机只允许 1 处 =
	## 摇新种子），多一处就会破坏「同一种子必然一致」。
	if pool.is_empty():
		return -1
	return int(pool[run_rng.randi_range(0, pool.size() - 1)])


static func grant_bigchest() -> Dictionary:
	## **「大宝箱」的唯一口**（R305 从 map_scene 抽出来）：
	## 1 件随机奖励道具 + 1 组卡牌奖励（三选一）+ 80 金币。
	## 地图上大宝箱房与卡片商人「以卡易物」都走这里 —— 数值只在这里写一次。
	## 返回 {relic_id, gold, reward_idx}（relic_id = -1 表示奖励道具已全拿完）。
	## R543（用户口径）：开启大宝箱时，若玩家**不持有生命之种**，则道具那格改成
	## 「奖励道具 / 生命之种」二选一（新增的二选一领取方式）。
	## ⚠️ 用户口径「所有信物改动只在难度 ≥ 11 生效」→ 低难度下仍走普通道具掉落。
	gain_gold(BIGCHEST_GOLD)
	# R314：**大宝箱**的传奇概率翻倍（5% × 层数 → 10% × 层数），所以这里必须传 `true`。
	var rid := roll_reward_relic(true)
	if third_layer_locked() and not has_key(SEED_RELIC_ID):
		queue_key_choice(rid)
	else:
		queue_relic_reward(rid)
	var idx := queue_card_reward("normal")
	return {"relic_id": rid, "gold": BIGCHEST_GOLD, "reward_idx": idx}


static func queue_key_choice(relic_id: int) -> void:
	## R543：大宝箱「奖励道具 / 生命之种」二选一入队。
	## 条目 kind = "relic_or_key"，带两个候选 id；玩家在奖励页二选一视图里挑一个。
	## `relic_id = -1`（奖励道具已全拿完）→ 仍入队，二选一里只剩「生命之种」可选。
	if relic_id > 0:
		_drop_settled_batch()
	pending_rewards.append({"kind": "relic_or_key", "relic_id": relic_id,
			"key_id": SEED_RELIC_ID, "state": REWARD_PENDING})


static func claim_key_choice(idx: int, take_key: bool) -> bool:
	## R543：二选一领取 —— `take_key = true` 拿「生命之种」信物，否则拿「奖励道具」。
	## 成功后该条置为 claimed。奖励道具走 gain_relic、信物走 gain_key。
	## R798（用户口径「道具如果在大宝箱二选一没有拿，也算出现过，后续不会再重复出现」）：
	## **摆上二选一就算出现过** —— 不论玩家最后拿了哪一边，候选道具都登记进
	## `skipped_relics`（本局后续不再随机出来）。原来只有「放弃」那条路登记
	## （`skip_key_choice`），选了种子时落选的那件会留在池子里、过几层又摇出来一次。
	## ⚠️ 选道具那条分支同样登记：`gain_relic` 之后它已在 `relics` 里、池子本来就摇不到，
	##    两边都记是为了「失去道具」类效果之后也不会复活（口径只有一句：出现过就不再出现）。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "relic_or_key":
		return false
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	var rid := int(e.get("relic_id", -1))
	if rid > 0 and not skipped_relics.has(rid):
		skipped_relics.append(rid)
	if take_key:
		gain_key(int(e.get("key_id", SEED_RELIC_ID)))
	elif rid > 0:
		gain_relic(rid)
	e["state"] = REWARD_CLAIMED
	return true


static func skip_key_choice(idx: int) -> bool:
	## R543：二选一放弃 —— 什么都不拿，奖励道具登记进 skipped（本局不再随机出来）。
	## R798：登记口径与 `claim_key_choice` **完全一致** —— 三条出口（拿道具 / 拿种子 /
	## 作废放弃）都会把那件候选道具记成「出现过」，本局不再摇到它。
	if idx < 0 or idx >= pending_rewards.size():
		return false
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "relic_or_key":
		return false
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return false
	var rid := int(e.get("relic_id", -1))
	if rid > 0 and not skipped_relics.has(rid):
		skipped_relics.append(rid)
	e["state"] = REWARD_SKIPPED
	return true


static func vendor_deck_card(repo: CardRepo, index: int) -> Dictionary:
	## 卡片商人 · 以卡易物：交出一张 **5 费及以上**的卡，换一个大宝箱（见 `grant_bigchest()`）。
	## 返回 {ok, old_id, old_name, relic_id, gold, reward_idx}。
	## ⚠️ 奖励在 deck_edit 场景里入队 —— 那里没有奖励面板，所以置 `reward_popup_pending`，
	##    回到地图时补弹一次。
	if index < 0 or index >= deck_ids.size():
		return {"ok": false}
	var old_id := int(deck_ids[index])
	var c := repo.get_card(old_id)
	if c == null or c.x_cost or c.cost < MERCHANT_MIN_COST:
		return {"ok": false}
	var old_name := c.card_name
	if not delete_deck_card(index):
		return {"ok": false}
	pending_deck_edit = ""
	var chest := grant_bigchest()
	reward_popup_pending = true
	return {"ok": true, "old_id": old_id, "old_name": old_name,
			"relic_id": int(chest["relic_id"]), "gold": int(chest["gold"]),
			"reward_idx": int(chest["reward_idx"])}


static func vendor_discard_random() -> Dictionary:
	## 卡片商人 · 随机折价：随机失去一张**非诅咒**卡，获得 100 金币。
	## 返回 {ok, lost_id, lost_name, gold}。
	var pool := deck_indices_removable()   # R750：删不掉的卡不进候选
	var idx := random_deck_index(pool)
	if idx < 0:
		return {"ok": false}
	var lost_id := int(deck_ids[idx])
	var c := CardRepo.load_json().get_card(lost_id)
	var nm := c.card_name if c != null else str(lost_id)
	if not delete_deck_card(idx):    # R750：没真删掉就不给钱
		return {"ok": false}
	gain_gold(VENDOR_GOLD)
	return {"ok": true, "lost_id": lost_id, "lost_name": nm, "gold": VENDOR_GOLD}


static func lake_lady_peek() -> Dictionary:
	## 湖中仙女 · 谎言（R488）：**进门就摇定**要失去的那一张，按钮上才能写死卡名。
	## 候选 = 卡组里所有**非诅咒卡**（用户口径：别让「谎言」顺手帮玩家清掉诅咒）。
	## R750（用户口径「严格删除展示的卡」）：再叠一层 `deck_indices_removable()` ——
	## 带锁的卡（月亮 9180 / 硬币 9181）不许被「展示」，展示了却删不掉就是骗玩家。
	## 幂等：已摇定且下标仍在候选池里 → 直接复用，**别每帧重摇**（否则按钮卡名会跳）。
	## 返回 {ok, index, card_id, name, enchanted}；池空 → ok = false（按钮该禁用）。
	var repo := CardRepo.load_json()
	var pool := deck_indices_removable()   # R750：展示的卡必须真删得掉
	if pool.is_empty():
		lake_victim = -1
		return {"ok": false}
	if lake_victim < 0 or not pool.has(lake_victim):
		lake_victim = random_deck_index(pool)   # 只走 run_rng：同种子必然同一张
	var c := card_with_mod(repo, lake_victim)   # 带附魔 / 本局成长的那一张
	var nm := c.card_name if c != null else str(deck_ids[lake_victim])
	return {"ok": true, "index": lake_victim, "card_id": int(deck_ids[lake_victim]),
			"name": nm, "enchanted": c != null and c.has_enchant()}


static func lake_lady_lie() -> Dictionary:
	## 湖中仙女 · 谎言（R488）：删掉**摇定的那一个下标** —— 界面上写的是哪张就删哪张。
	## 返回 {ok, index, lost_id, lost_name}（卡组里只剩诅咒卡 → ok = false）。
	var peek := lake_lady_peek()
	if not bool(peek.get("ok", false)):
		return {"ok": false}
	var idx := int(peek["index"])
	if idx < 0 or idx >= deck_ids.size():
		return {"ok": false}
	var lost_id := int(deck_ids[idx])
	var nm := str(peek.get("name", str(lost_id)))
	# ⚠️ 删完后面的下标全部前移 → 摇定立刻作废（别留着骗下一次 peek）
	# R750（用户口径）：**展示哪张就严格删哪张**，成长与附魔都随卡一起消失，不留账。
	# 删不掉（被 `no_remove` 挡住 / peek 之后卡组被改短）→ 整件事**没有发生**：
	# 返回 ok = false，事件不置完成、奖励也不发，玩家可以再点一次。
	if not delete_deck_card(idx):
		lake_victim = -1
		return {"ok": false}
	lake_victim = -1
	return {"ok": true, "index": idx, "lost_id": lost_id, "lost_name": nm}


static func lake_lady_truth() -> Dictionary:
	## 湖中仙女 · 诚实：获得一张**随机史诗卡**（本职业奖励池里稀有度 2 的卡）。
	## 返回 {ok, card_id, name}。
	var rolled := CardReward.roll_rarity(CardRepo.load_json(), LAKE_EPIC_RARITY, 1, run_rng)
	if rolled.is_empty():
		return {"ok": false}
	var c: CardData = rolled[0]
	add_card(c.id)
	return {"ok": true, "card_id": c.id, "name": c.card_name}


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
	_reap_card_growth(old_id)       # R750：原卡被锻成铁栅栏 → 旧 id 的成长账一起走
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
	ensure_deck_mods()          # R636：取附魔前先对齐（读档 / 演示路径可能留下不等长）
	for i2: int in picked:
		if copied.size() >= DUCK_BLOOD_MAX:
			break
		var id: int = deck_ids[i2]
		var c := repo.get_card(id)
		copied.append({"id": id, "name": c.card_name if c != null else str(id)})
		# ⚠️ 必须**先取附魔再 append**：`_mod_at()` 里有 `ensure_deck_mods()`，
		# 若先 append 了 deck_ids 再取，它会把 mods 补一个空槽对齐到**新长度**，
		# 随后再 append 一次副本附魔 → 两个列表就错位了（R636 首版实测）。
		var src_mod: Dictionary = _mod_at(i2).duplicate(true)
		deck_ids.append(id)     # 副本追加到卡组末尾（原卡位置不动）
		# R636（用户口径「需要能完整复制卡片，携带同种附魔」）：副本 = 原卡的**完整拷贝**，
		# 附魔（`deck_mods`）一起带过去，并且必须 **deep 拷贝** —— 共享同一个 dict 的话，
		# 之后给副本贴新附魔会把原卡一并改掉。
		# 本局永久成长（`card_growth`）按卡 id 记账，副本天然继承，不需要另外搬。
		# ⚠️ 这里与 R181 的旧口径（复制品无附魔）相反 —— R181 是为了防「复制刷附魔」，
		#    用户在 R636 明确要求「完整复制」，所以改回带附魔；R638 又把野兔 9032 的
		#    短暂复制也改成完整复制（`_spawn_self_clone` 不再剥）。**唯一**仍剥附魔的是
		#    复制术 9165 —— 它复制的是场上单位，数值里还叠着改造。
		deck_mods.append(src_mod)
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
	# Third-layer straight route is fully revealed, independently of exploration memory.
	if current_layer == GameLayers.LAYER_THREE:
		return not RogueMap.is_void(map_cells[id])
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
	## 本局种子的展示文本（ESC 菜单 / 设置页 / 对战记录共用；没有进行中的局 = 「—」）。
	## R261：一律是 **10 位大写字母 / 数字**，玩家抄下来就能复现同一局。
	if not run_active or run_seed == 0:
		return "—"
	return seed_text_of(run_seed)


static func seed_text_of(v: int) -> String:
	## int 种子 → **10 位 base36 大写文本**（不足左补 0）。与 `seed_value_of` 互逆 ——
	## 对战记录里的老记录（只存了 int）也靠它显示成同一套种子码。
	if v <= 0:
		return "0".repeat(SEED_LEN)
	var out := ""
	var n := v
	while n > 0:
		out = SEED_ALPHABET[n % 36] + out
		n = n / 36
	while out.length() < SEED_LEN:
		out = "0" + out
	return out


static func seed_value_of(code: String) -> int:
	## 10 位种子码 → int 种子。小写自动转大写、首尾空格忽略；
	## **非法一律返回 -1**（长度不对 / 有 A-Z0-9 以外的字符 / 全 0）。
	## 全 0 视为非法：0 在本工程里是「没有种子」的哨兵，不能被当成一个可复现的种子。
	var s := code.strip_edges().to_upper()
	if s.length() != SEED_LEN:
		return -1
	var v := 0
	for i in SEED_LEN:
		var idx := SEED_ALPHABET.find(s[i])
		if idx < 0:
			return -1
		v = v * 36 + idx
	return -1 if v == 0 else v


static func random_seed_text() -> String:
	## 新开一局时**现摇**一个 10 位种子码（A-Z + 0-9）。
	## ⚠️ 这是整局唯一碰全局随机源的地方（R241 起就只在开局摇这一次）：
	##    之后所有随机都由 `run_rng` 派生 → 同一种子必然一致，续档也不会变。
	## 全 0 的码重摇（概率 1/36^10）—— 保证「0 = 没有种子」这个哨兵不被撞上。
	var s := ""
	while s == "":
		s = ""
		for i in SEED_LEN:
			s += SEED_ALPHABET[randi() % 36]
		if seed_value_of(s) < 0:
			s = ""
	return s


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
	## 迷雾永远盖不住的地标格：起点 + 两个大宝箱 + **开局随机标记的那间商店**（R693）。
	## 「找不到通往大宝箱的路」是 R145 要解决的问题 —— 通路可见 + 目标可见，
	## 玩家才规划得了路线；剩下「路上会遇到什么」才是迷雾要藏的东西。
	## R693：商店从「右上角固定」改成「随机标记一格」之后，它的**位置本身就是随机信息**，
	## 藏进迷雾等于让玩家没法规划「这一趟顺路能不能买到」—— 所以照旧是地标。
	if id < 0 or id >= map_cells.size():
		return false
	if RogueMap.is_bigchest(id) or RogueMap.is_fixed_shop(id):
		return true
	return str(map_cells[id].get("type", "")) == "start"


static func ensure_shop_mark() -> int:
	## R693：给 **R693 之前生成的存档**补上 `shop_mark` 字段。返回补标记的格 id（-1 = 没补）。
	##
	## 为什么必须有这一步：R243~R692 的地图把商店**钉死在右上角 (6,0)**，cell 里没有
	## `shop_mark`；直接读到这种图，`is_fixed_shop()` 会全部返回 false → 那间老商店
	## 当场从地标滑进迷雾（`is_landmark_node` 认不出它），还能被「笔记」改成宝箱。
	## 口径：
	##   1) 图里已经有任何 `shop_mark` → 一律不动（新档本来就对，重复调用也无害）；
	##   2) 否则优先认右上角 (6,0)（那就是老口径的位置），那里不是商店就看第一间
	##      `type == "shop"` 的格；
	##   3) 两种情况都凑不出来 → **不凭空造商店**（旧图可能本来就没有，补一间等于改设计）。
	## ⚠️ 必须在 `reveal_known()` **之前**调用：它会拿 `is_landmark_node()` 补视野，
	##    标记晚一步，那间商店这一帧就已经被算成迷雾里了。
	if map_cells.is_empty():
		return -1
	for c: Variant in map_cells:
		if c is Dictionary and bool((c as Dictionary).get("shop_mark", false)):
			return -1
	var corner := RogueMap.idx(RogueMap.COLS - 1, 0)
	if corner >= 0 and corner < map_cells.size():
		var cc: Variant = map_cells[corner]
		if cc is Dictionary and str((cc as Dictionary).get("type", "")) == "shop":
			(cc as Dictionary)["shop_mark"] = true
			return corner
	for c2: Variant in map_cells:
		if not (c2 is Dictionary):
			continue
		var d: Dictionary = c2
		if str(d.get("type", "")) == "shop":
			d["shop_mark"] = true
			return int(d.get("id", -1))
	return -1


static func can_move_to(node_id: int) -> bool:
	## 从当前房间能否走到目标（必须真的有门 —— 与地图场景的点击判定同源）。
	if node_id < 0 or node_id >= map_cells.size():
		return false
	if current_node_id < 0:
		return true          # 还没出发：允许站上起点
	return RogueMap.doors_between(map_cells, current_node_id, node_id)


static func can_reach(node_id: int) -> bool:
	## R322（用户口径）：**能去的不只是当前房的相邻格** ——
	## 走过的房间可以自由穿行（零消耗、什么都不会发生），所以
	## 「走过的房间」以及「它们的所有相邻格」都算可达。
	## 判据唯一口：地图点击 / 绿框高亮 / 悬停提示全部读这里。
	if node_id < 0 or node_id >= map_cells.size():
		return false
	if current_node_id < 0:
		return true          # 还没出发：允许站上起点（与 can_move_to 同口径）
	if node_id == current_node_id:
		return false
	return not path_to(node_id).is_empty()


static func path_to(node_id: int) -> Array:
	## 走到 node_id 的逐格路线（不含当前房间，末位 = 目标）；不可达返回 []。
	## 中途只穿**走过的**房间 —— 那是唯一「零消耗、无事件」的一段。
	if node_id < 0 or node_id >= map_cells.size() or current_node_id < 0:
		return []
	var allowed := {}
	for cid in cleared_ids:
		allowed[int(cid)] = true
	allowed[current_node_id] = true     # 当前房一定允许（起点本身可能还没记进 cleared）
	return RogueMap.path_through(map_cells, current_node_id, node_id, allowed)


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
	# R390：**真的挪了位置** → 上一间商店的「重进」窗口就此关闭
	# （用户口径：只在下一次移动之前能重新进）。同格重复进入不算移动，窗口保持。
	# ⚠️ 放在 `can_move_to` 之后：那条路压根没动，不该关窗。
	if node_id != current_node_id:
		shop_revisit_id = -1
	var is_new: bool = not cleared_ids.has(node_id)
	var cost := 0
	var revealed := false
	var forfeited := 0
	if is_new:
		# R695：**踏进一个没探索过的格子 = 忘拿的奖励到期**（用户口径「到下一个未探索的
		# 格子前都可以回来拿」）。只认 is_new —— 原路走回走过的房间不扣任何东西，
		# 待领奖励照旧留在原地，随时能回来领。
		forfeited = forfeit_pending_rewards()
		var c: Dictionary = map_cells[node_id]
		# R357（用户口径「第三层不再使用巧克力机制」）：第三层的格子**不收步数**。
		# 这一层的终局是「走到 Boss 格就开打」（map_scene._commit_enter 的 "boss" 分支），
		# 与「巧克力耗尽 → 入夜 → Boss 战」那条旧链路彻底解耦 —— 所以三个后续动作
		# （扣块数 / 置 boss_pending / 按块数同步疲惫）在第三层**一个都不做**。
		var free_layer: bool = int(c.get("layer", current_layer)) == GameLayers.LAYER_THREE
		cost = 0 if free_layer else 1
		cleared_ids.append(node_id)
		if bool(c.get("hidden", false)) and not bool(c.get("revealed", false)):
			c["revealed"] = true
			revealed = true
		if cost > 0:
			chocolate = maxi(0, chocolate - cost)
			# R339：本层 Boss 已经打过 → 巧克力见底也不再入夜（否则打完 Boss 再走一格，
			#       map_scene 会立刻又开同一场 Boss 战 —— 用户报的「回地图再次进 Boss」）。
			if chocolate <= 0 and not boss_beaten:
				boss_pending = true
			# R223 难度 5「行动力低时疲惫」：巧克力跨过 6 的临界 → 疲惫入 / 出卡组
			# （唯一推导口 sync_fatigue，从 deck_ids 直接判，不加布尔 flag）
			sync_fatigue()
	current_node_id = node_id
	reveal_known()   # R207：走进来之后立刻把新视野记进 seen —— 旧邻居不会因为
	                 #      「已经不是邻居」而重新被雾盖回去（用户口径）
	return {"ok": true, "is_new": is_new, "cost": cost, "revealed": revealed,
			"chocolate": chocolate, "forfeited": forfeited}


static func complete_current() -> void:
	## 当前房间内容结算完成（战斗胜利 / 休息 / 事件 / 大宝箱）。
	## 进房时已经标过「已走过」，这里是幂等的兜底口。
	if current_node_id >= 0 and not cleared_ids.has(current_node_id):
		cleared_ids.append(current_node_id)
	reveal_known()                # R207：幂等刷新（房间结算完的视野也记进 seen）


# ------------------------------------------------------------ 商店会话（R390）

static func shop_state_of(node_id: int) -> Dictionary:
	## 取某间商店已经存下的货架状态（没有则空字典）。
	if node_id < 0:
		return {}
	var v: Variant = shop_states.get(str(node_id), null)
	return v if v is Dictionary else {}


static func store_shop_state(node_id: int, st: Dictionary) -> void:
	## 存货架状态 —— shop_scene 每次商品状态变化（售罄 / 附魔 / 删卡）后调用。
	## 深拷贝：那边传进来的 `_row1/_row2/_row3` 还在被场景继续改，不能共用引用。
	if node_id < 0:
		return
	shop_states[str(node_id)] = st.duplicate(true)


static func shop_revisit_ok(node_id: int) -> bool:
	## 这一格现在能不能「重新进店」：必须**正是上次离开的那间**，且货架状态还在。
	## ⚠️ 只看 `shop_revisit_id` 就够了 —— 走出这一格时它已被 `advance()` 清空；
	##    再加一次 `current_node_id` 判断反而会在「刚进店又出来」时误判。
	return (node_id >= 0 and node_id == shop_revisit_id
			and not shop_state_of(node_id).is_empty())


static func shop_mark_revisit(node_id: int) -> void:
	## 离开商店时登记重进窗口（`shop_scene._leave()` 的唯一口）。
	shop_revisit_id = node_id


static func reset_shop_session() -> void:
	## 新局 / 换层：货架与重进窗口一起作废。
	shop_states = {}
	shop_revisit_id = -1


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


static func rabbit_foot_gold() -> int:
	## R796 兔脚（6076）：战斗胜利额外给的金币（没有这件道具 → 0）。
	## ⚠️ 只加在**战斗胜利**这一条上（`battle_scene` 的结算口），不进 `gold_for_tier()` ——
	##    那个函数是「按难度分级的基础掉落」的唯一口径，测试也按它断言，掺进道具会把它污染成
	##    「看背包的函数」。宝箱 / 事件 / 商店都不吃兔脚（用户口径写的是「战斗掉落金币」）。
	if has_relic(RABBIT_FOOT_RELIC_ID):
		return RABBIT_FOOT_GOLD
	return 0


static func gain_gold(amount: int) -> int:
	## 加金币（战斗掉落 / 宝箱）。返回本次实际增加量。
	var before := gold
	gold = maxi(0, gold + maxi(0, amount))
	return gold - before


static func clear_gold() -> int:
	## R351 赏月：「失去所有金币」的唯一口。返回实际失去的数量。
	## ⚠️ 不要在图里写 `gold = 0` —— 需要走这里才能在日志/统计里留下一条。
	var lost := gold
	gold = 0
	return lost


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

static func note_damage(amount: int) -> void:
	## R530：**玩家造成的伤害记账**（结算界面的「造成伤害」行）。
	## 引擎在三个落地口调（单位扣血 / 效果直击敌方 HP / 普攻直击敌方 HP）——
	## 三处覆盖了所有伤害来源，加新路径时别绕开它们。
	## 口径是**实际扣掉的血**：护盾挡掉、减伤削掉的部分不算，「打 20 只掉 8」记 8。
	if amount > 0:
		total_damage += amount


static func reset_run_stats() -> void:
	## R530：开新局 / 结束一局 → 整局统计归零（含结算快照）。
	reset_total_stats()


static func reset_total_stats() -> void:
	total_damage = 0
	total_battle_wins = 0
	total_elite_wins = 0
	run_summary = {}


static func on_battle_won(node_type: String) -> void:
	## 战斗胜利后累计同类胜场：决定后续难度（前 2 场简单、之后困难）。
	## 「事件节点遭遇怪物」（node_type = "event"）**同样按普通战斗计数**（R47 修复）：
	## 否则这类战斗永远停在「简单」档，也不消耗「前 2 场简单」的额度 →
	## 玩家可以靠怪物事件反复刷简单战斗。
	if node_type == "battle" or node_type == "event":
		battle_wins += 1
		total_battle_wins += 1      # R530：整局累计（结算用，不随换层清）
		ProfileData.bump(ProfileData.K_BATTLE_WIN)   # R346：成就统计（累计胜场）
	elif node_type == "elite":
		elite_wins += 1
		total_elite_wins += 1       # R530
		ProfileData.bump(ProfileData.K_ELITE_WIN)    # R346
	elif node_type == "boss":
		mark_boss_beaten()      # R339：本层 Boss 记成「已打」→ 这一层不再入夜
		ProfileData.bump(ProfileData.K_BOSS_WIN)     # R346
		# 击败的是**哪一只** Boss 由 battle_scene 另记（那里才有关卡名）——
		# 这里只记「打赢了一次 Boss」，别把两套口径混成一个键。


static func mark_boss_beaten() -> void:
	## R339：本层 Boss 已击破 —— 唯一置位口。
	## 顺带清掉 `boss_pending`：Boss 战打完时这条「等房间结算完就入夜」的待触发必须失效，
	## 否则回地图就可能再开一次（原先只靠 `map_scene._start_boss_battle` 提前清，是个单点依赖）。
	boss_beaten = true
	boss_pending = false


static func elite_tier_for_chocolate(choco: int) -> int:
	## R778：强弱精英的**唯一判据**（纯函数，测试直接传数）——
	## 当前巧克力 <= ELITE_STRONG_CHOCO_MAX（5）→ 强精英（精英敌人-困难）；
	## 否则 → 弱精英（精英敌人-简单）。第三层不适用（next_level 里提前固定池）。
	return GameLevels.TIER_ELITE_HARD if choco <= ELITE_STRONG_CHOCO_MAX \
			else GameLevels.TIER_ELITE_EASY


static func node_layer(node: Dictionary) -> int:
	## 节点所属的层（节点自带 layer；缺省时按本局地图的层处理）。
	return int(node.get("layer", current_layer))


static func next_level(node: Dictionary) -> Dictionary:
	## 进入战斗节点时决定具体关卡 —— 只从「该节点所属层」的关卡池里抽
	## （第一层的关卡不会跑到别的层，别的层的关卡也不会出现在第一层）：
	## 前 2 场普通战斗 = 普通敌人-简单，之后 = 普通敌人-困难；
	## 精英强弱只看**当前巧克力**：<= 5 强精英，> 5 弱精英（R778 替换原「按 elite_wins 场次」）；
	## Boss 固定。
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
			# R506b：第三层固定抽第二层「精英困难」池（3 关）—— 直道那一格是 Boss 前的
			# 最后一战，不参与强弱精英判定（R778 口径不变）。
			if layer == GameLayers.LAYER_THREE:
				return _pick_level(GameLevels.third_elite_pool())
			# R778：强弱精英改由**当前巧克力**判定（原「按 elite_wins 场次切换」废弃）。
			var tier2: int = elite_tier_for_chocolate(chocolate)
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

## ── R473：延迟发卡（武术大师）──
static func queue_delayed_card(id: int, battles: int, elite_only := false) -> void:
	## 挂一张「再打 N 场就给」的卡。
	## `elite_only = true` → 只有**精英 / Boss** 胜利才推进（普通战斗不计数）。
	## battles <= 0 时当场给 —— 事件表以后想改成「立刻给」不用再动这里。
	if battles <= 0:
		add_card(id)
		return
	delayed_cards.append({"id": id, "need": battles, "elite": elite_only})


static func bump_delayed_cards(is_elite := false) -> Array:
	## 一场战斗胜利后推进所有挂单，返回**这一场到账的卡**：`[{"id":..,"name":..}]`。
	## * 普通战斗（is_elite = false）**不推进**只认精英的挂单 —— 它们原地等着；
	## * need 减到 0 → 当场 `add_card()` 进卡组，并从挂单里摘掉；
	## * 顺序按挂单顺序结算（同一场同时到账两张时，日志 / 提示的顺序是稳定的）。
	var gained: Array = []
	if delayed_cards.is_empty():
		return gained
	var keep: Array = []
	for e: Dictionary in delayed_cards:
		var elite_only := bool(e.get("elite", false))
		if elite_only and not is_elite:
			keep.append(e)
			continue
		var need := int(e.get("need", 1)) - 1
		var cid := int(e.get("id", -1))
		if need > 0:
			keep.append({"id": cid, "need": need, "elite": elite_only})
			continue
		if cid <= 0:
			continue
		add_card(cid)
		var c := CardRepo.load_json().get_card(cid)
		gained.append({"id": cid, "name": c.card_name if c != null else str(cid)})
	delayed_cards = keep
	return gained


static func delayed_cards_text() -> String:
	## 挂单的可读描述（「飞踢（1 场战斗）」，空串 = 没有挂单）。
	## 事件收尾提示 / 地图道具栏 / 测试都读这一个口。
	var parts: Array[String] = []
	for e: Dictionary in delayed_cards:
		var cid := int(e.get("id", -1))
		var c := CardRepo.load_json().get_card(cid)
		var nm: String = c.card_name if c != null else str(cid)
		var cond := "场精英 / Boss" if bool(e.get("elite", false)) else "场战斗"
		parts.append("%s（还差 %d %s）" % [nm, int(e.get("need", 0)), cond])
	return "、".join(parts)


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
			_reap_card_growth(id)    # R750：最后一张也用掉了 → 成长账收走
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
	if removed > 0:
		_reap_card_growth(id)    # R750：整批删光 → 这个 id 的成长账不再有任何归属
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
	## （费用 -1 / 伤害 +8 / 次元 +2力+10血 / 保存），不能污染卡库共享实例，
	## 于是对带附魔的那张用 `from_dict(to_dict())` 生成**独立副本**再应用。
	## R214：单卡口径统一收进 `card_with_mod()`（展示层也调它，别再各写一遍复制逻辑）。
	var cards: Array[CardData] = []
	for i in deck_ids.size():
		var cc := card_with_mod(repo, i)
		if cc == null:
			continue
		# R455：「随机变化」是**战斗内**的一次性事实（8072 / 8074 的入手收益），
		# 卡组这一层永远不携带它 —— 战斗外的随机换卡（源数之力 6002 / 卡片商人·旧换新 /
		# 鸭鸭工匠…）只换 id，不打标记、也不进引擎的「变化 N 张」（`self_card_changes`）。
		# 这里兜最后一道：万一脏数据带了标记，进战斗即清零。
		# ⚠️ **先复制再清零**：没附魔的卡是卡库共享实例，直接改就等于污染整局卡库。
		if cc.random_born:
			cc = CardData.from_dict(cc.to_dict())
			cc.random_born = false
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
	var growth := card_growth_of(deck_ids[index])
	# R393：没有附魔、但有本局永久成长时**也必须复制** —— 否则会把成长写进卡库共享实例。
	if mod.is_empty() and growth.is_empty():
		return c
	var cc := CardData.from_dict(c.to_dict())   # 独立副本（affixes 等数组也独立）
	if not mod.is_empty():
		_apply_mod(cc, mod)
	_apply_card_growth(cc, growth)
	return cc


static func card_growth_of(card_id: int) -> Dictionary:
	## 这张卡当前累计的本局永久成长（没有 = {}）。
	## 返回**副本**，调用方拿去临时算就行，不会误改账本。
	var raw: Variant = card_growth.get(str(card_id), {})
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var out := {}
	for key in ["power", "health", "damage"]:
		var n := int(d.get(key, 0))
		if n != 0:
			out[key] = n
	return out


static func grow_card(card_id: int, power := 0, health := 0, damage := 0) -> Dictionary:
	## 给卡 id 记一笔**本局永久**成长，返回累计后的账。
	## 负值按 0 收口（成长只增不减；要削弱请另开负修正字段，别混进这里）。
	var key := str(card_id)
	var cur: Variant = card_growth.get(key, {})
	var d: Dictionary = cur if cur is Dictionary else {}
	d["power"] = maxi(0, int(d.get("power", 0)) + maxi(0, power))
	d["health"] = maxi(0, int(d.get("health", 0)) + maxi(0, health))
	d["damage"] = maxi(0, int(d.get("damage", 0)) + maxi(0, damage))
	card_growth[key] = d
	return d.duplicate()


static func _reap_card_growth(card_id: int) -> void:
	## R750（用户口径「严格删除展示的卡，包括所有的成长和附魔」）：
	## 卡**离开卡组**时，把这个 id 的本局成长账一并收走。
	##
	## 为什么必须做：`card_growth` 按 **id** 记账、不按实例 —— 卡组里一张都不剩之后，
	## 这条账就是孤儿：以后再抽到 / 买到同名卡，`card_with_mod()` 会把旧成长重新烤
	## 进去，玩家看到的就是「卡被谎言抹掉了，成长却还留着」。
	##
	## ⚠️ 同 id 还有别的卡时**必须保留**：那是几张同名卡共用的一份账，
	##    擦掉等于连累没被删的那一张 —— 它不是玩家选择要失去的。
	if deck_ids.has(card_id):
		return
	card_growth.erase(str(card_id))


static func _apply_card_growth(c: CardData, growth: Dictionary) -> void:
	## 把本局永久成长烤进一张**副本**。调用方负责保证 c 不是卡库共享实例。
	if c == null or growth.is_empty():
		return
	var gp := int(growth.get("power", 0))
	var gh := int(growth.get("health", 0))
	var gd := int(growth.get("damage", 0))
	c.power += gp
	c.health += gh
	c.value += gd
	# R393b：把「哪部分数字是长出来的」也记在卡上 —— 卡面角标与卡组详情读它，
	# 才不会把附魔抬高的数值误报成本局成长。
	c.growth_power += gp
	c.growth_health += gh
	c.growth_damage += gd


static func battle_end_card_gold(repo: CardRepo) -> int:
	## R393：卡组中带 `battle_end_gold` 的卡，在战斗胜利后给的金币。
	## 同名多张**不叠加**（取最大值，与月亮 / 硬币同口径）—— 避免复制卡无限刷金币。
	var best := 0
	for id in deck_ids:
		var c := repo.get_card(int(id))
		if c != null:
			best = maxi(best, c.battle_end_gold)
	return best


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
			# R210：**只给技能卡**（用户口径「伤害附魔只能给技能卡」—— 引述原话，不写具体数值）。
			# R226：再收紧 —— 只给**能直接造成伤害**的技能卡（用户口径「要限制能直接造成
			# 伤害的技能卡」）：治疗 / 抽牌 / 加 buff / 防御类技能本来就不吃这个 +10，
			# 附了也是白花 60 金。判据唯一口 = `CardData.is_damage_spell()`。
			# 技能卡的 `power` 在卡面上**恒为 0**（伤害写死在引擎结算里），附魔把 +10 烤进
			# `power`，由 `GameEngine._spell_dmg()` 消费 → 这张技能卡造成的伤害 +8。
			# 以前判 `power > 0`（= 只给盟友 / 工事），技能卡永远选不中、单位却能白拿 10 攻。
			return c.is_damage_spell()
		"core":
			# R458 契约核心：只给**能取到第一段伤害**的伤害技能卡。数值由献祭方给，
			# 所以资格只看「自己是不是一张拿得出段伤的伤害技能卡」。
			# ⚠️ 随机池（牛奶 / 附魔大师）不会摇到它，见 `CardData.random_enchant_ids()`。
			return c.is_damage_spell() and GameEngine.spell_first_hit(c) > 0
		"dimension":
			return (c.kind == "盟友" or c.is_fort()) and not c.has_affix("次元") \
					and not c.is_effect()
		"save":
			return true          # 任何卡都能保存
		"draw":
			# R370「抽牌 +1」：任何卡都能附 —— 盟友 / 工事 / 场地 / 技能 / 效果都算「打出」，
			# 挂点统一在 `GameEngine._note_card_played()`，所以没有种类限制。
			return true
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
		"damage": m = {"power": 8, "note": "伤害 +8"}
		"dimension": m = {"affix": "次元", "power": 2, "health": 10}
		"save": m = {"affix": "保存"}
		# R229「起手」：**不改任何数值**，只记 id —— 抽牌时引擎按 `card.enchant` 认它。
		"opening": m = {}
		# R370「抽牌 +1」：同样不改数值，只记 id —— 引擎在出牌收尾口按 `card.enchant` 认它。
		# ⚠️ **不要**写成 `{"draw": 1}`：`_apply_mod()` 只认 cost/power/health/affix/note，
		#    多出来的键会被静默忽略，将来有人误读成「已经烤进数值了」。
		"draw": m = {}
		_: return {}
	m["id"] = ench_id
	return m


static func enchant_id_of(mod: Dictionary) -> String:
	## 一份 mod 是哪种附魔（`enchant_mod()` 写的 `"id"` 优先）。
	## R181~R213 的老存档 / 老 mod **没有 id** → 按内容反推（附魔效果互不重叠，能反推）：
	## 费用 -1 / 次元(+2力+10血) / 保存 / 伤害 +N（带 note）。
	## ⚠️ 数值本身**不**参与反推（R787 把 +10 下调成 +8 之后，老存档里那批
	##    `{"power": 10, "note": "伤害 +10"}` 仍然要认成 damage）—— 只认「有没有增量」。
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
	# R458：可变数值附魔（契约核心「伤害 +N」）的**逐卡显示名** —— 空串 = 用固定名。
	c.enchant_label = str(mod.get("label", ""))
	# R210：技能卡的具体伤害是写在 `effect_text` 里的死文字（「造成 17 点伤害」），
	# 「伤害 +8」附魔改的是**结算值** → 卡面文字会跟实际伤害对不上。补一行标注，
	# 详情条 / 图鉴 / 牌库都读 `effect_text`，玩家一眼能看到这张卡被附魔过。
	var note: String = str(mod.get("note", ""))
	if note != "" and c.effect_text.find(note) < 0:
		c.effect_text += "\n【附魔】" + note


static func strip_enchant(c: CardData) -> bool:
	## R624：把**商店附魔**从一张已经烤过数值的卡上撤掉（战斗内复制专用）。
	##
	## 为什么需要它：`_apply_mod()` 把附魔烤进 cost / power / health / affix，烤完之后与
	## 「原生就长这样」的卡无法区分 —— 只有 `enchant`（附魔种类 id）还记得来源。
	## 唯一调用点：复制术 9165（`_duplicate_spell`）的复制品**不继承附魔**（店长口径）。
	## ⚠️ R638 起野兔 9032 **不再走这里** —— 它改成完整复制（附魔、字段、标注一起带走），
	##    与鸭血 6024 同一口径；别再把这条调用加回 `_spawn_self_clone`。
	##
	## ⚠️ 只认 `enchant`：空串 = 没吃过附魔（含老存档没记的情况）→ 原样返回，**一个字节都不动**。
	##    绝不能靠「猜数值」去减，那会把卡面原生的数值一起削掉。
	## ⚠️ 本局永久成长（`growth_power/health/damage`）**不是附魔**，这里不碰 —— 成长跟着卡种走，
	##    复制品照旧继承（与 R393 同口径）。
	## 返回 True = 真的剥掉了附魔。
	if c == null or c.enchant == "":
		return false
	var m := enchant_mod(c.enchant)
	if m.is_empty():
		return false
	c.cost = maxi(0, c.cost - int(m.get("cost", 0)))
	c.power = maxi(0, c.power - int(m.get("power", 0)))
	c.health = maxi(0, c.health - int(m.get("health", 0)))
	var affix := str(m.get("affix", ""))
	if affix != "":
		c.affixes.erase(affix)
	var note := str(m.get("note", ""))
	if note != "":
		var tag := "\n【附魔】" + note
		var at := c.effect_text.find(tag)
		if at >= 0:
			c.effect_text = c.effect_text.substr(0, at) + c.effect_text.substr(at + tag.length())
	c.enchant = ""
	c.enchant_label = ""
	return true


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


# ── R458「契约的核心」（第二层事件）：可变的伤害附魔 ──────────────────
## 契约核心 = +N 伤害，N 取自被献祭那张技能卡的**第一段伤害**
## （`GameEngine.spell_first_hit()` 唯一口）。消费点与商店的「伤害 +8」完全同源
## （`_spell_dmg()` 把 `card.power` 并进每一段），区别只在这个数不固定 ——
## 所以名字也逐卡携带（`CardData.enchant_title()`），不能用固定标签。
const CORE_ENCHANT_ID := "core"
## 核心（6059，「契约的核心」选项 2）：**不是当场兑现**——
## 战斗中累计失去 `CORE_LOSS_NEED` 点生命值后，这一场战斗结束时的奖励页里
## 才会多出一条「核心」；在那里献祭一张伤害技能牌、把它的第一段伤害变成附魔。
## 用掉即失效（`spend_relic` → 道具栏里变灰），累计与「已触发」一起清零。
const CORE_RELIC_ID := 6059
const CORE_LOSS_NEED := 15
## 持有「核心」以来累计失去的生命（**只算战斗内 HP 伤害**，战斗结束结算）。
static var core_lost := 0
## 已经够 15 点了（这一场开始每场胜利都给一次机会，直到用掉为止）。
static var core_armed := false


static func core_enchant_mod(value: int) -> Dictionary:
	## 契约核心附魔的数值定义（`_apply_mod` 按它烤进目标卡）。
	## `label` 是**可变**显示名（「伤害 +17」）：卡面 / 左栏 / 提及浮窗读它；
	## 只认 id 的地方（记录页等）退回 `ENCHANT_DEFS["core"]` 的固定名「契约核心」。
	var v: int = maxi(0, value)
	return {"power": v, "note": "伤害 +%d" % v,
			"label": "伤害 +%d" % v, "id": CORE_ENCHANT_ID}


static func core_contract_sources(repo: CardRepo) -> Array[int]:
	## 契约的核心 · 选项 2 第一段：**可以献祭**的卡（= **卡组下标**，同名卡各占一项）。
	## 判据：伤害技能卡 + 第一段伤害取得到 + 不是不可删除的卡（月亮 9180 / 硬币 9181 /
	## 罐子 9157 这些 `no_remove`）。
	## ⚠️ 祭品**不需要**「没附过魔」—— 它整张都会离开卡组，附魔跟着一起走。
	ensure_deck_mods()
	var out: Array[int] = []
	for i in deck_ids.size():
		var c := repo.get_card(int(deck_ids[i]))
		if c == null or c.no_remove:
			continue
		if not c.is_damage_spell():
			continue
		if GameEngine.spell_first_hit(c) <= 0:
			continue
		out.append(i)
	return out


static func core_contract_targets(repo: CardRepo, src_idx: int) -> Array[int]:
	## 契约的核心 · 选项 2 第二段：**可以接收**附魔的卡（= 卡组下标）。
	## 判据 = 伤害技能卡 + 还没附魔（每张卡只能一个附魔）+ 不是刚挑中的祭品自己。
	## 资格口径与商店附魔同源（`enchant_ok()` 的 `core` 分支），不另写一套。
	ensure_deck_mods()
	var out: Array[int] = []
	for i in deck_ids.size():
		if i == src_idx:
			continue
		var c := repo.get_card(int(deck_ids[i]))
		if c == null:
			continue
		if not enchant_ok(CORE_ENCHANT_ID, c, i):
			continue
		out.append(i)
	return out


static func core_contract_apply(repo: CardRepo, src_idx: int, dst_idx: int) -> Dictionary:
	## 契约的核心 · 选项 2 结算：献祭 `src_idx`（**从卡组永久删除**），把它的第一段伤害
	## 作为附魔烤到 `dst_idx` 上。返回 {ok, dmg, src_name, dst_name, reason}。
	## ⚠️ 顺序：**先附魔、再删卡** —— 删卡会让后面的下标前移（`delete_deck_card` 会同步
	##    `deck_mods`），先附魔就不必算偏移。两步的资格都已在候选里过滤过；万一删卡那步
	##    失败，后果只是「附魔生效、祭品还在」—— 不会留下坏数据。
	if src_idx < 0 or src_idx >= deck_ids.size() \
			or dst_idx < 0 or dst_idx >= deck_ids.size():
		return {"ok": false, "reason": "no_card"}
	if src_idx == dst_idx:
		return {"ok": false, "reason": "same_card"}
	var src := repo.get_card(int(deck_ids[src_idx]))
	var dst := repo.get_card(int(deck_ids[dst_idx]))
	if src == null or dst == null:
		return {"ok": false, "reason": "no_card"}
	var dmg: int = GameEngine.spell_first_hit(src)
	if dmg <= 0:
		return {"ok": false, "reason": "no_damage"}
	if not enchant_ok(CORE_ENCHANT_ID, dst, dst_idx):
		return {"ok": false, "reason": "bad_target"}
	if not enchant_deck_card(dst_idx, core_enchant_mod(dmg)):
		return {"ok": false, "reason": "enchant_failed"}
	if not delete_deck_card(src_idx):
		return {"ok": false, "reason": "delete_failed"}
	return {"ok": true, "dmg": dmg,
			"src_name": src.card_name, "dst_name": dst.card_name}


static func core_note_battle_loss(lost: int) -> void:
	## R458：战斗**胜利**时把这一场我方 HP 受伤合计交给这里（`self_hp_damage_taken`）。
	## ⚠️ 只给**持有核心且还没失效**的局记账：没这件道具时连数都不存
	##    （免得中途拿到核心时被「以前的伤」白送一次机会）。
	## ⚠️ 已触发后**继续累加也没意义**（阈值只判一次），直接留着 `core_armed`。
	if not has_relic(CORE_RELIC_ID) or core_armed:
		return
	core_lost += maxi(0, lost)
	if core_lost >= CORE_LOSS_NEED:
		core_armed = true


static func core_ready_to_use() -> bool:
	## 「核心」此刻能不能真的用：已触发 + 卡组里至少一対「祭品 → 接收者」。
	## 凑不出一对时**不入队** —— 否则奖励页里会冒出一条点开是空的条目。
	if not core_armed or not has_relic(CORE_RELIC_ID):
		return false
	var repo := CardRepo.load_json()
	for i: int in core_contract_sources(repo):
		if not core_contract_targets(repo, i).is_empty():
			return true
	return false


static func queue_core_reward() -> int:
	## 把「核心」摆进待领奖励队列（战斗结束时的奖励页）。返回队列下标（-1 = 没入队）。
	## 走的是**同一条** `pending_rewards` 通道 —— R340「一批没处理完不许换场景」
	## 对它同样生效；`_drop_settled_batch()` 保证它只活在当前这一批里。
	if not core_ready_to_use():
		return -1
	for e: Dictionary in pending_rewards:
		if str(e.get("kind", "")) == "core" \
				and str(e.get("state", REWARD_PENDING)) == REWARD_PENDING:
			return -1        # 同一批里已经有一条了（重进结算面板 / 读档续战不重复塞）
	_drop_settled_batch()
	pending_rewards.append({"kind": "core", "state": REWARD_PENDING})
	return pending_rewards.size() - 1


static func claim_core_reward(idx: int, src_idx: int, dst_idx: int) -> Dictionary:
	## R458：奖励页**就地**结算「核心」—— 献祭 `src_idx`（永久删除）、把它的第一段伤害
	## 附到 `dst_idx` 上，并把这条奖励置为已领。返回 `core_contract_apply()` 的结果。
	## 用掉之后：累计清零、`core_armed` 归位、道具变灰（`spend_relic`）。
	if idx < 0 or idx >= pending_rewards.size():
		return {"ok": false, "reason": "no_entry"}
	var e: Dictionary = pending_rewards[idx]
	if str(e.get("kind", "")) != "core":
		return {"ok": false, "reason": "not_core"}
	if str(e.get("state", REWARD_PENDING)) != REWARD_PENDING:
		return {"ok": false, "reason": "settled"}
	var res := core_contract_apply(CardRepo.load_json(), src_idx, dst_idx)
	if not bool(res.get("ok", false)):
		return res
	e["state"] = REWARD_CLAIMED
	e["dmg"] = int(res.get("dmg", 0))
	# 结果留在这条奖励上（置灰之后列表仍要能读出「献祭了谁、附到什么上」）
	e["src_name"] = str(res.get("src_name", ""))
	e["dst_name"] = str(res.get("dst_name", ""))
	core_lost = 0
	core_armed = false
	spend_relic(CORE_RELIC_ID)
	return res


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
	# R323：每次结算重写演示数据（界面读走即清，不会串到下一次）
	milk_anim = []
	var pool: Array[String] = []
	for eid: String in CardData.random_enchant_ids():
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
		if enchant_deck_card(idx, enchant_mod(eid)):
			# R323：记下来给界面演「这张卡被贴了哪种附魔」
			milk_anim.append({"card_id": deck_ids[idx], "ench": eid})


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
