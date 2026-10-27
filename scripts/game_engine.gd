class_name GameEngine
extends RefCounted



signal action(kind: String, data: Dictionary)

const SIDE_SELF:= "self"
const SIDE_OPPONENT:= "opponent"

const GROW_CAP:= 5

var state: FieldState
var current_side:= SIDE_SELF
var turn_number:= 0
var turn_total:= 0   # 全局半回合计数（双方回合各 +1；暗影狩猎「上回合触发过工事」的判定基准）
var opp_turns:= 0
var over:= false
var result:= ""
var result_reason:= ""
var ai_enabled:= true
## R360：死亡效果延迟结算（**只影响时机，不改逻辑顺序**）。
## 根因：`_destroy()` 里亡语是同步跑的，而界面要等击破演出（`DESTROY_HOLD_MS` + 幽灵淡出）
## 才把那把卡抹掉 —— 于是「辅助刃」这类回手亡语先出现在手卡、场上那张卡还站着。
## headless（单元测试 / 回放）保持 false → 同步结算，断言不受影响；
## battle_scene 只对**单机战斗**置 true，由击破演出到点调 `flush_death_effects(cell)`。
## ⚠️ 联机镜像模式必须保持 false：两侧靠同一份 action 序列对齐，不能掺本地动画时间。
var defer_death_effects:= false
## R360：待结算的死亡效果 —— `cell -> Array[Callable]`。
## 用格子当键、而不是一条全局队列：同一帧死两个单位时，各自的亡语要等**自己那张卡的**
## 击破演出到点才结算，不会因为先播完的那个把后面的一起跑掉。
var _death_effects:= {}
## R245：本场战斗的节点类型（"battle" / "elite" / "boss"）。
## 由 battle_scene 按**关卡 tier** 写入一次；引擎不自己读 RunState.pending_node ——
## 单关演示 / 单元测试都能显式指定，判据只有一处（`_courage_active()` 的消费方）。
var battle_kind:= "battle"
## R356：本关的胜利条件是否为「击破指定 Boss」（启示者 9200；0 = 不是）。
## 第三层 Boss 关的敌方 HP 是 ∞（`enemy_hp_infinite`），直击永远打不空 ——
## 不留这条，玩家绕开本体一路糊脸就能跳过整场三阶段。battle_scene 按关卡表写入。
var win_on_boss:= 0
## R356：本关敌方 HP 为 ∞。置位后 `_damage_player` 对**敌方 HP** 不再扣血，界面显示「∞」。
var enemy_hp_infinite:= false
## R311 水晶骰子（6040）：本场战斗是否来自「?」房（battle_scene 写）。
## `dice_roll` / `dice_energy_turns` 在 `apply_battle_start_relics()` 里定；
## 没持有道具 / 不是「?」房 → 0，一切照旧。
var dice_battle:= false
var dice_roll:= 0
var dice_energy_turns:= 0
## R311 不锈钢盆（6041）：剩余点数（0 = 没有盆）。
## battle_scene 从 `RunState.basin_charge` 灌入；承伤时递减，`basin` 动作回写界面。
var basin_charge:= 0
## R313：**技能卡结算作用域**（深度计数）。快速符文的百分比只认技能伤害 ——
## 效果卡 / 陷阱 / 反伤打出来的伤害不享受。
## ⚠️ 用深度而不是布尔：回响会嵌套重放同一张技能卡，布尔会在内层退出时提前关掉。
var _spell_scope_depth:= 0
## R314 lucky 7（6045）：当下这一轮是否处在「生效回合」。
## ⚠️ 由**我方回合开始**置位 / 复位，敌方回合**不清** —— 见常量区的口径说明。
var _lucky7_active:= false
## R315 爆米花（6046）：本回合**还没有**以敌人 / 敌人所在格为目标使用技能。
## 每个我方回合开始置 true；一旦有这么一次技能就置 false；回合结束时按它决定下回合多抽。
var _popcorn_quiet:= true
## R315 爆米花：**下个我方回合**的额外抽牌张数（回合结束时累加、下回合开始消费清零）。
## 不复用 `state.self_next_draw`：那条日志写死了「负重减轻」，混用会张冠李戴。
var popcorn_draw:= 0
## R316 极速（9171）：「本回合所有敌人受到伤害 +N」的当前值（0 = 没加成）。
## 由 `极速` 结算时按「抽到的 0 费张数」累加；**回合结束清零**（与本回合其它一次性 buff 同口径）。
var _rapid_enemy_bonus:= 0
## R317 身法（9173）：本回合剩余时间**不能使用盟友 / 工事卡**（回合结束复位）。
var _no_unit_play_this_turn:= false
## R317 淘汰（9174）：等玩家从**卡组**挑一张盟友 / 工事变成「素体」（UI kind = "eliminate"）。
var eliminate_pending:= false
var log: Array[String] = []
var rng:= RandomNumberGenerator.new()
var self_relics: Array[int] = []
var _unit_played_this_turn:= false
var turn_dmg_bonus:= 0
var duck_revive_chance:= 100
var turn_spell_bonus:= 0
## R341 鹿首标本（6049）：本场战斗累计的「技能与陷阱 / 场地伤害 +N」层数。
## 每个我方回合开始 +1（`_begin_turn`）。**只在战斗内累计** —— 引擎一场一个实例，
## 换场自然归零，不需要额外复位（道具本身跨战斗保留，层数不保留）。
var deer_bonus:= 0
var _rice_used:= false
var crow_pending:= false
var whale_pending:= false
var revive_pending:= false   # 复活术（9078）：等玩家从弃牌区选盟友
var revive_remaining:= 0     # 还要选几张（蓄力让这张卡生效 2 次 → 2 张，一张一张选）
var overhaul_pending:= false   # 返修（9127，R188）：等玩家从弃牌区选盟友/工事
var overhaul_remaining:= 0     # 还要选几张（蓄力让这张卡生效 2 次 → 2 张，一张一张选）
var shadow_step_pending:= false   # 暗影步（9121）：等玩家从弃牌区选一张（任意 kind）
var shadow_step_remaining:= 0     # 还要选几张（蓄力让这张卡生效 2 次 → 2 张）
var shadow_step_label:= "暗影步" # 面板标题（复用复活术那套面板时区分文案）
var focus_pending:= false      # 专注（9122）/ 负重减轻（8066，R201）：等玩家从**抽牌库**里选 N 张卡移除
var focus_remaining:= 0        # 还要移除几张
var focus_total:= 0            # 本层面板总共要移除几张（文案用：专注 2 / 负重减轻 1）
var focus_draw_bonus:= false   # 负重减轻（8066，R201）：选完后下个回合开始多抽 1 张（focus_pick 完成时发放）
var focus_label:= "专注"       # 面板文案标签（专注 / 负重减轻）；battle_scene 按它切标题与提示
## R298 合体 9167：场上目标已选、等玩家从**卡组**挑一张「素体」的待办（UI kind = "merge"）。
## `merge_hand_index` / `merge_cell` 在面板期间一直留着 —— 面板确认后由 battle_scene 用它们
## 调 `use_spell()`，付费 / 弃牌 / 出牌计数 / 次元判定全部交回 use_spell 统一收尾。
## R300 激发 8077：重入保护 —— 它自己造成伤害，若某张敌方亡语反过来改造了我方卡，
## 会再次走进 `_inspire_tick()`。这个标记保证「一次结算不会被自己递归放大」。
var _inspire_busy:= false
var merge_pending:= false
var merge_hand_index:= -1
var merge_cell:= Vector2i(-1, -1)
var merge_body_atk:= -1        # 面板选中的素体力量（-1 = 未预取 → 自动取卡组第一张）
var merge_body_hp:= -1         # 面板选中的素体生命（同上）
var merge_body_name:= ""       # 面板选中的素体名（日志 / 目标失效时的提示）
var whale_remaining:= 0
var foresight_mode:= false  # 预判（9097）：等玩家选效果①/②
var wish_pending:= false    # 许愿（9168）：等玩家从**卡组**选一张卡加入手卡
var _steel_stamp_used:= false  # R307 思想钢印：本场战斗是否已经救过一次（每场一次）
var _thorn_ring_turn:= -1      # R307 荆棘指环：上次触发是第几回合（每回合一次）
var _knight_sword_fired:= false  # R383 骑士剑：本场战斗的第一次击杀是否已发生（每场一次）
## R393：本场战斗里，哪些**卡 id** 的「首次击杀」成长已经结算过。
## 每个新 GameEngine = 一场新战斗，`start_game()` 清空 → 「每场战斗首次」自然成立。
## 按 id 而不是按单位实例：同名两张不会在同一场里各刷一次本局永久成长。
var _first_kill_growth_done:= {}
var foresight_pick:= false  # 预判①：等玩家从弃牌区选一张 0 费技能卡
var foresight_vanish:= false  # 预判①选完后：把本卡从弃牌区移除（本卡消失）
## R292：拒绝命运（9098）改成**自动结算**（丢光手卡 → 弃牌区所有 0/1 费卡按顺序回手），
## 原来那套「等玩家从弃牌区选回 N 张」的待办字段（fate_pending / fate_count）已删。
var endless_pending:= false  # 无尽黑暗 9114（R70）：等玩家从**手牌**里选 1 张弃掉
var rebirth_pending:= false  # 新生 9148（R222）：等玩家从**手牌**里选 1 张使其消失
var rebirth_remaining:= 0    # 本层面板还要消失几张（效果区几张新生就几张）
## R271 创意 8070：回合开始「选一张手卡变成随机可改造卡」的待办（UI kind = "creation"）。
var creation_pending:= false
var creation_remaining:= 0
## R271 量产型代达罗斯 8074：入场「选一张手卡变成聚能炮击」的待办（UI kind = "cannonize"）。
var cannonize_pending:= false
var cannonize_remaining:= 0
var cannonize_src:= ""
## R331 惊喜运单 8079：回合开始「选卡组一张卡变成随机卡入手」的待办（UI kind = "surprise"）。
## 与创意 8070 / 新生 9148 同形态：`_surprise_tick()` 开面板，`surprise_pick()` 结算。
## ⚠️ 与 `cannonize_pending` 各用各的字段（混用会在取消 / 连开时清错状态）。
var surprise_pending:= false
var surprise_remaining:= 0
## R404 涂装机器人 8080：入场「选场上其他一个友方单位变成随机机械之心单位」的待办。
## 与上面几个选**手牌 / 卡组**的 pending 不同，这个选的是**棋盘格** → UI 走格子高亮 + 点击。
var paint_pending:= false
var paint_src:= Vector2i(-1, -1)   # 机器人自己那格（候选要排除它 = 卡面的「其他」）
var _aether_left:= 0
var _aether_used:= false
var _stoneskin_left:= 0
# 「每回合第 X 次」的 X = 效果区张数 → 用计数记录本回合已触发几次（回合开始归零）
var _roar_fires:= 0
var _space_fires:= 0
# 风元素（9082）：技能结算窗口 —— 窗口内只要有伤害落在敌方身上就记一次（见 _mark_spell_enemy_hit）
var _spell_active:= false
var _spell_hit_enemy:= false
# 流星雨（9083）：本次施放消耗的费用（X）—— 在 _pay 之前抓取（见 use_spell / remote_spell）
var _x_spell_value:= 0
# 火墙术（9084）：正在燃烧的横行。每项 {side, row, pass_dmg, dealt}；
# dealt 记录每个单位已从这面火墙吃到的伤害；同一单位的累计上限记在 rec["cap"]，
# 由施放时的实际伤害算出（R387）—— 附魔加伤会把上限一起抬高。
# 熄灭时机 = 施放方的下次回合开始（_begin_turn → _clear_fire_walls）。
var _fire_walls: Array = []
# 蓄力（9085）：该方「下一张技能多结算几次」的待用层数（按阵营记账，用掉即清）。
# 结算次数 = 1 + 层数（1 层 = 生效 2 次）；见 _charge_add / _charge_take。
var _charge: Dictionary = {}
# 闪躲（9103）：自己直到**下个回合开始**前，HP 伤害改由随机一个己方盟友代受。
# 用法：施放时置 true；_begin_turn(SIDE_SELF) 时清 false（覆盖了中间的敌方回合）。
var _dodge_active:= false
# R145：**最近一次真正落到玩家 HP 上**的伤害（减伤 / 挡下之后的值）。
# `attack_hp` 与各处「溢出伤害」发出的 `action.emit("hp"/"trample")` 要报
# 「实际掉了几点」，而不是「攻击力是多少」—— 只扣 1 点却飘一个「-12」是错的。
# 0 = 这一笔被完全挡下（森林守护 / 闪躲吸收）。
var _last_hp_damage:= 0
var growth_cfg: Dictionary = {}   # 关卡成长曲线配置（空 = 不启用）；只对敌方单位生效
var _growth_stacks:= 0            # 已累计的成长层数（+1 层 = 每人 +inc 攻击力）

const DUCK_REVIVE_STEP:= 25

const BLAZE_DUCK_ID:= 9020
const BLAZE_DUCK_DAMAGE:= 10

const HEALER_TRAIT:= "治疗"
const KILN_TRAIT:= "孵化"
const KILN_CARD_ID:= 9025
# ---- 「太阳熔炉」关卡（R135，第二层普通困难）----
# 与「哈气」那种**效果卡**不同，这里的双动来源是**场上的工事单位**赫利俄斯：
# 它在场 → 本方的量产型俄倪厄 ① 一回合行动两次 ② 每回合结束回 SUN_FORGE_REGEN 点。
# 两条都以「赫利俄斯还在场」为前提：行动数在 FieldState.unit_actions 里实时判定，
# 回血在 `_regen_tick` 里实时判定 —— 拆掉它两条立刻断，不需要任何收尾钩子。
const SUN_FORGE_HELIOS_ID:= 9130   # 赫利俄斯（太阳装置，工事 0/50 程0 速0）
const SUN_FORGE_FURY_ID:= 9131     # 量产型俄倪厄（盟友 5/45 程1 速1）
const SUN_FORGE_REGEN:= 2          # 赫利俄斯在场时，每只俄倪厄每回合结束的回复量
const SUN_FORGE_ACTIONS:= 2        # 赫利俄斯在场时，俄倪厄每回合的行动次数
const CERAMIC_CARD_ID:= 9026
# R259：场上该方陶瓷鸭达到这个数（>=3）时，鸭子窑不再四邻各刷一只（鸭海滚雪球），
# 改为相邻空格里随机挑一个只召唤 1 只，并给所有陶瓷鸭 +1 血量（见 _kiln_hatch）。
const KILN_CROWDED_COUNT:= 3
const EGG_CARD_ID:= 9022

# R340：生蛋鸭 / 鸭蛋（9022）在**我方回合结束**仍存活 → 原地变成「宠物鸭」（9177）。
# 它 3 攻 15 血、程 1 速 1，并**代替我方 HP 承受伤害** —— 判据接进 `absorbs_for_hp()`，
# 与森林守护 / 铁栅栏 / 大树守卫走同一条通道（战场绿环与伤害结算同源，不会两处漂移）。
const PET_DUCK_ID:= 9177
const PET_DUCK_TRAIT:= "宠物鸭"
# ---- 「钢铁要塞」关卡（R149，第二层精英困难）----
# 量产型赫卡同克瑞斯（9133）上场就带铸造倒计时：**我方回合结束** -1，
# 减到 0 → 破坏自身并在**原地**立起一座钢铁要塞（9134，工事 5/100 程2 嘲讽）。
# ⚠️ **这不是亡语**：只有「倒计时走完」这一条路径会铸出要塞。被玩家提前打掉
#    走的是常规 `_destroy`，什么都不留下（卡面 effect_text 已写明这一条），
#    所以刻意**不进 `_deathrattle`** —— 进那里就变成「怎么死都要塞照出」。
const FUSE_TRAIT:= "铸造"           # 只做标记（与「亡语 / 孵化」同套路），回合数在引擎
const HECATE_ID:= 9133              # 量产型赫卡同克瑞斯（盟友 3/35 程1 速1）
const STEEL_FORTRESS_ID:= 9134      # 钢铁要塞（工事 5/100 程2 速0，嘲讽）
const FUSE_TURNS:= 5                # 铸造倒计时的初始回合数（与卡面 effect_text 同源）
# ---- 「赫菲斯托斯工坊」关卡（R150，第二层 Boss；R225 上调）----
# 赫菲斯托斯（9135，盟友 5/120 程1 速1）带「锻造」trait，两条效果挂在两个**唯一口**上：
#   ① **亲手击杀**敌人 → 在**己方半场随机空格**锻造一只量产型俄倪厄（9131，5/45）
#      —— 挂 `_credit_kill`（击杀记功唯一口），并**清零**空转计数；
#   ② 连续 FORGE_PERIOD 个**我方回合**没能亲手击杀 → 力量 +1、攻击距离 +1（永久累计）
#      —— 挂 `_forge_tick`（`end_turn` 的 SIDE_SELF 分支，与 R149 铸造倒计时同一处）。
# ⚠️ R225 用户口径：周期从 3 改成 **1（每回合）** —— 它每挨过一个没击杀的我方回合
#    就长 1 力 1 程；同时 Boss 获得「践踏」（见下），清不干净前排就一路被穿到脸。
# 于是这关的取舍是：往前顶着送头（它一直在杀 → 一直在生小兵），还是缩着不接触
#   （它杀不到 → 每回合自己长 1 力 1 程，射程越长越难躲）。
# ⚠️ 射程记 `Placement.forge_range`（走 `effective_range`），**不写回 card**。
const HEPHAESTUS_ID:= 9135        # 赫菲斯托斯（第二层 Boss）
const FORGE_TRAIT:= "锻造"         # 只做标记（与「沉睡 / 铸造」同套路），数值放 Placement
const FORGE_PERIOD:= 1            # 连续几个我方回合没击杀 → 成长一次（R225：3 → 1）
const FORGE_ATK:= 1               # 每次成长：力量 +1（走 atk_buff，永久累计无上限）
const FORGE_RANGE:= 1             # 每次成长：攻击距离 +1（走 Placement.forge_range）

# ---- R225：践踏（trample）----
# 带「践踏」trait 的单位**普通攻击**击杀敌对单位时，超出对方剩余生命的伤害**不丢弃**，
# 而是沿**击杀目标所在的那一列继续往深处传**（从攻击者一侧往对方后排方向）：
#   * 逐个结算同列的下一个敌对单位（空网格跳过，先遇到的先吃），
#     打死一个就把剩余伤害继续往下传；
#   * 遇上一个没被打死的单位 → 溢出到此为止（它吃满）；
#   * 整列都打穿了 → 剩下的伤害直击对方 HP（走 `_damage_player`，与既有溢出同口径，
#     石肤 / 护心 / 荒野形态等减伤链照常生效）。
# 只挂**普通攻击**（`attack()`）—— 技能 / 效果 / 直击 HP 不触发（用户口径「攻击击杀」）。
# 非践踏单位保持原规则：只有「被击穿的是对方**后排**单位」时溢出才漏到 HP。
const TRAMPLE_TRAIT:= "践踏"       # 只做标记（与「锻造 / 铸造」同套路），无数值字段

# ---- R228：「废料场」关卡（第二层 · 普通困难）----
# 拾荒者（9151，盟友 4/50 程1 速1）带「拾荒」：**己方回合开始时**，各给一个
#   「拾荒者以外」的**己方**单位一次改造（+SCAVENGER_ATK 攻 / +SCAVENGER_HP 血）。
#   目标走引擎 rng（回放同种子可复现）；除了拾荒者自己没别人时跳过、只打日志。
# 废弃机器人（9152，盟友 5/40 程1 速1）带「废铁」：**每次被改造** → 对**所有敌方单位**
#   （= 机器人这一方的对侧）各造成 WASTE_BOT_DMG 点伤害。
#   ⚠️ 挂点 = `_on_unit_upgraded()`（R101 起就是「所有改造入口的统一后置口」），
#      所以不管改造来自拾荒者、升级、加厚装甲还是批量改造，都会触发；
#      不要另外在某个改造函数里再补一次（会双触发）。
const SCAVENGER_ID:= 9151
const SCAVENGER_TRAIT:= "拾荒"      # 只做标记（与「锻造 / 铸造」同套路）
const SCAVENGER_ATK:= 3            # 每次改造：攻击力 +3
const SCAVENGER_HP:= 5             # 每次改造：生命 +5
const WASTE_BOT_ID:= 9152
const WASTE_BOT_TRAIT:= "废铁"      # 只做标记（与「锻造 / 铸造」同套路）
const WASTE_BOT_DMG:= 1            # 每次被改造：对所有敌方单位 1 点伤害

# ---- R230：清退（9153，暗影刺客 · 稀有效果卡）----
# 效果区里有本卡时：**把陷阱（= 等敌人踩的场地卡，`field_aim == FIELD_AIM_ENEMY`）
# 放在有敌人的格子上** → 把那个敌人朝**敌方后排**方向击退 CLEAR_OUT_STEPS 格
# （被单位或边界挡住就停下，与「击退 9004」同一个口 `_knockback`）。
# ⚠️ 挂点 = `play_from_hand` 的场地分支（玩家侧唯一场地放置口）。
# ⚠️ 只认「陷阱」：清泉 / 维修间 / 改造工厂这类对己方或双向生效的场地不算（不是陷阱）。
const CLEAR_OUT_ID:= 9153
const CLEAR_OUT_TRAIT:= "清退"      # 只做标记（与「锻造 / 废铁」同套路）
const CLEAR_OUT_STEPS:= 1          # 击退格数（R278：2 → 1）

# ---- R231：破绽（俄倪厄 9132 / 量产型俄倪厄 9131）----
# 带「破绽」trait 的单位在**自己这一方的回合开始时**，往**对方卡组**塞一张诅咒
# 「破绽」（9154，2 费，打出无效果）：
#   * 敌方单位（正常情况）→ 「对方」= 玩家 → 真的插进 `state.deck`；
#     插入位置走引擎 rng（同种子同位置、回放一致）。**不插在最上面**：
#     `draw()` 取的是牌库尾，append 到尾部 = 下一抽必定吃诅咒，那样两张俄倪厄
#     就是「每回合两张必抽的废牌」，手牌直接死；随机位才叫「加进卡组」。
#   * 玩家单位（理论上拿不到）→ 「对方」= 敌方，而敌方牌库只有抽象计数
#     （`opp_deck_count`）→ 只 +1 并记日志，与「镜像」同口径。
# ⚠️ 一只单位每回合各塞一张（场上 3 只俄倪厄 = 每回合 3 张）—— 这是这两张卡的
#    核心压力：拖得越久，你的牌库越脏。
const BREACH_TRAIT:= "破绽"        # 单位侧标记（卡面 trait，与「锻造 / 废铁」同套路）
const BREACH_CURSE_ID:= 9154      # 诅咒「破绽」（2 费，打出无效果）
# ---- 「量产铁砧」关卡（R158，第二层普通简单）----
# 量产型赫菲斯托斯（9138，盟友 4/50 程1 速1）带「量产锻造」trait：**只保留** Boss 版
# 那条「亲手击杀 → 锻造量产型俄倪厄」，**没有**「连续空转 N 回合自己变强」那半边。
# 判据用 trait：它的 `forge_period` 恒为 0，而 `_forge_tick` / `_heph_kill_forge`
# 两条都以 `forge_period > 0` 为前提 → 都不会碰它，天然不会串到 Boss 的成长上。
const MASS_FORGE_TRAIT:= "量产锻造"   # 只做标记（与「锻造 / 铸造」同套路），无数值字段
# ---- 敌人效果卡「充能巨炮」（R158，第二层普通困难「双机炮阵」）----
# 效果区里有「巨炮」trait 的卡：**己方每个回合开始时**，随机破坏**一个敌方单位**
# （从持有效果卡那方看 = 对方单位）。破坏走唯一口 `_destroy`（离场记账 / 亡语 /
# 击杀记功与别处完全一致），不是另起一套删除。一次破坏几个由卡面 `value` 决定
# （默认 1）—— 于是 value 有消费方，不是死数据。
const CANNON_TRAIT:= "巨炮"           # 只做标记，破坏次数取卡面 value（默认 1）

# ---- 行动力成长（R161，第二层精英简单「赫尔墨斯」）----
# 带「行动力成长」trait 的单位：每过 ACTION_GROWTH_PERIOD 个回合，本回合行动次数 +1。
# 只记 Placement.action_growth_extra，不走 CardData；回合开始先 tick 再 reset_units。
const ACTION_GROWTH_TRAIT:= "行动力成长"
const ACTION_GROWTH_PERIOD:= 3

# ---- R174：量产型阿尔戈斯「百眼动员」（第二层普通简单「百眼动员」）----
# 阿尔戈斯（9142，盟友 **7/35** 程2 **速2**，R219 攻击 4→7，R220 攻击距离 1→2）带「百眼」trait：**在场时每单位只发动一次**
# （记 `Placement.ability_used`，与潜伏 9092 同口径 —— 离场再上场算新单位，可再发动）。
# 触发条件 = **攻击命中单位**（不要求亲手击杀，与「量产锻造」的区别就在这）：
# 在**己方后排**（row 0）召唤一只量产型俄倪厄（9131，5/45 程1 速1），并使其
# **移动速度 +1**（记 `Placement.summon_haste`，进 `effective_speed`，随单位离场消失）。
# 后排满则退到己方半场随机空格（`_random_free_half_cell`，走引擎 rng → 回放同种子可复现）。
# ⚠️ 挂点 = `attack()`（攻击单位），**不挂** `attack_hp()`（直击 HP 不算「攻击单位」）。
const ARGOS_ID:= 9142             # 量产型阿尔戈斯（盟友 7/35 程2 速2）
const ARGOS_TRAIT:= "百眼"        # 只做标记（与「量产锻造 / 锻造」同套路），次数记 Placement
const ARGOS_SUMMON_HASTE:= 1      # 召唤出的俄倪厄移速加成（Placement.summon_haste）

# ---- R219：量产流水线「流水线装配」（第二层普通简单「量产流水线」）----
# 效果卡 9147（效果 · 敌方 · 金）：**每过 `value`(=3) 回合**，从
# **量产型俄倪厄 9131 / 量产型赫利俄斯 9137** 里**随机挑一个**，召唤到己方半场空格。
# * 回合计数口径与「鸭子号角 9015（召唤）」完全一致：**双方各数自己的回合**
#   （`turn_number` / `opp_turns`），`tick % interval == 0` 时产出 → 第 3、6、9… 回合。
# * 随机走引擎 `rng`（回放同种子可复现）；落点 `_random_free_half_cell`。
# * 召唤物走 `place(summon = true)`：当回合恰好 1 轮行动，与其它召唤同口径。
# * 半场满 → 只打日志、不产出（不补到下一回合，不转伤害）。
const ASSEMBLY_CARD_ID:= 9147     # 流水线装配（效果卡，卡面 value = 间隔回合）
const ASSEMBLY_TRAIT:= "装配"
const ASSEMBLY_POOL:= [9131, 9137]   # 量产型俄倪厄 / 量产型赫利俄斯

# ---- R356：第三层 Boss「启示者」（9200）与它的三张场上效果卡 ----
# 启示者：攻 15 / 血 300 / 程 2 / 速 2，后排中央 (0, 1)。**三个阶段**，剩余生命降到 2/3、1/3 时各进一阶：
#   ① 阶段 1（剩余 > 2/3；300 血时 300~201）：「舰炮 9201」——该方回合开始随机轰击一列，该列**对方**全部单位
#      各受 5 伤；整列没有目标则改打对方 HP。自身：每个回合力量 +1。
#   ② 阶段 2（剩余 1/3~2/3；300 血时 200~101）：「电磁屏障 9202」——攻击启示者的单位受到 5 伤。
#      自身：践踏 + 受到的**技能**伤害减半 + **移速 -1** + **每回合可行动两次**（R371）。
#   ③ 阶段 3（剩余 < 1/3；300 血时 100~0）：「紧急呼叫 9203」——**玩家每个回合开始**召唤一只力量 +10 的量产型
#      （优先出现在启示者身边）。自身：移速 0 + 与它接通的友方单位代它承受一半伤害（去尾）
#      + **登场时破坏场上所有其他单位** + **攻击距离 +2** + **有随从时免疫非攻击伤害**（R371）。
#   R371（用户口径「加强启示者」）：**全阶段免疫位置移动效果** —— 击退 / 换位一律无效，
#      判据收敛在 `_displace_immune()`（`_knockback` / `_swap_two_units` / 双向传送三处共用）。
# 阶段转移（`_revelator_enter_phase`）：退回后排中间（原格有东西就消灭它）→ 换掉场上效果卡 →
#   血量下限钳到 1 → 发 `boss_phase` 事件（界面播横幅 + 重弹敌方效果 + 右栏效果区自动刷新）。
# ⚠️ 阶段只记 `Placement.boss_phase`，**绝不烤进 CardData**（敌方单位用的是卡库共享实例）。
const REVELATOR_ID:= 9200
const REVELATOR_NAVAL_GUN_ID:= 9201
const REVELATOR_SHIELD_ID:= 9202
const REVELATOR_CALL_ID:= 9203
## R402（用户口径「阶段转换逻辑改为 2/3，1/3」）：阶段血线**按最大生命的比例**算，
## **不再写死 200 / 100** —— 难度 3 起「敌人更加顽强」把敌方生命 ×1.1
## （`RunState.scaled_enemy_card`），330 血时写死的 200 / 100 等于「刚过 61% / 30%
## 就转阶」，三段的份量全歪（高难度下第一段被压扁、第二段被拉长）。
## 唯一口 = `revelator_gate_hp()`（引擎 / 测试都读它，别在别处再写数字）。
const REVELATOR_HOME:= Vector2i(0, 1) # 每次转阶段都退回这里（后排中间）
const REVELATOR_ATK_UP:= 1            # 阶段 1：每个（敌方）回合力量 +1
const REVELATOR_SPEED_DOWN:= 1        # R371 阶段 2 起：移动速度 -1（阶段 3 直接 0）
const REVELATOR_ACTIONS:= 2           # R371 阶段 2 起：每回合可行动两次
const REVELATOR_RANGE_UP:= 2          # R371 阶段 3：攻击距离 +2（卡面 2 → 4）
const NAVAL_GUN_TRAIT:= "舰炮"
const NAVAL_GUN_DMG:= 5               # 卡面 value 同值；取效果区**最大**一张，不叠加
const EM_SHIELD_TRAIT:= "电磁屏障"
const EM_SHIELD_REFLECT:= 5           # 阶段 2：攻击启示者的单位受到 5 伤
const EMERGENCY_CALL_TRAIT:= "紧急呼叫"
const EMERGENCY_CALL_ATK:= 10         # 阶段 3：召唤出的量产型力量 +10（只属于那一只）
## 阶段 3「量产型」召唤池：名字带「量产型」的敌方单位
## （俄倪厄 / 赫利俄斯 / 赫菲斯托斯 / 阿尔戈斯 / 赫卡同克瑞斯）。
const EMERGENCY_POOL:= [9131, 9137, 9138, 9142, 9133]

# ---- R162：阿斯克勒庇厄斯「护甲积攒」----
# 每回合开始时获得 ASCLEPIUS_ARMOR 点护甲；若获得前已有护甲，则清零并对随机敌方单位
# 造成等量伤害，然后力量 +1。护甲只记 Placement，受到伤害时优先代替生命扣除。
const ASCLEPIUS_ID:= 9141
const ASCLEPIUS_TRAIT:= "护甲积攒"
const ASCLEPIUS_ARMOR:= 16
const ASCLEPIUS_GROWTH_ATK:= 1

# ---- R159：AI 角色分类（按卡面能力，不走复杂收益计算）----
# 分类只读 card/traits/kind/value，不依赖 Placement 状态；结果用于目标优先级与移动倾向。
const AI_ROLE_TANK:= "tank"               # 嘲讽 / 工事 / 血厚低速：优先抗线，最后才打
const AI_ROLE_SUPPORT:= "support"        # 治疗 / 成长光环 / 召唤引擎：活着就增益队友，优先击杀
const AI_ROLE_SNIPER:= "sniper"          # 射程 ≥2 且有力：后排输出，优先清场
const AI_ROLE_ASSAULT:= "assault"        # 高速 / 多动 / 穿行：积极前压、绕路
const AI_ROLE_SUMMONER:= "summoner"      # 孵化 / 锻造 / 铸造 / 亡语召唤：击杀后可能生东西
const AI_ROLE_VOLATILE:= "volatile"      # 亡语有伤害：能避免就不主动碰，必要时远距离点掉
const AI_ROLE_GROWTH:= "growth"          # 每回合自己变强：越放越大，优先处理
const AI_ROLE_BRUISER:= "bruiser"        # 高力量近战：正面威胁
const AI_ROLE_GENERIC:= "generic"        # 其它

const AI_QUEUE_USE_OPTIMIZED:= true   # R160：false 切回原版行动顺序

const TAUNT_TRAIT:= "嘲讽"
const SPELL_IMMUNE_TRAIT:= "法术免疫"
## R277：「位移免疫」—— 击退 / 推移 / 换位置这类**改变格位**的效果对它一律无效。
## 只认卡面 trait（与「法术免疫」同一套路，无数值字段）；判定口只有
## `_knockback()` 与 `_swap_two_units()` 两处 —— 所有位移效果都必须经过它们。
const DISPLACE_IMMUNE_TRAIT:= "位移免疫"
const ASH_DRAGON_ID:= 1013
const ASH_DRAGON_AOE:= 4
const FROST_MAGE_ID:= 1031
const WYVERN_ID:= 1014
const WYVERN_TOKEN_ID:= 9028
const GHOUL_ID:= 1050
const GHOUL_DMG:= 5
const LICH_ID:= 1051
const SKELETON_TOKEN_ID:= 9029
const SKELETON_SUMMON_ID:= 1054
const MECH_ID:= 1061
const MECH_DMG:= 8


const HERO_CARD_ID:= 9023
const HERO_DISCARD:= 4


const PEACH_RELIC_ID:= 6014
const PEACH_BATTLE_HEAL:= 4     # 黄桃罐头：每次战斗结束回复 4 点生命
const DUCK_EYE_RELIC_ID:= 6009  # 鸭之眼：己方技能伤害 +X（X = 该技能卡的原始费用）
const EARRING_RELIC_ID:= 6015
const EARRING_AUTOPLAY_MAX:= 20
const ICECREAM_RELIC_ID:= 6016
const ICECREAM_HP_COST:= 3
const ICECREAM_ENERGY:= 2    # R340 下调：+4 → +2（抽牌仍是 3 张）
const ICECREAM_DRAW:= 3
const ICECREAM_LINE:= "你跑不过我你信吗"
const HEAVY_DUCK_RELIC_ID:= 6017
const EGG_DUCK_RELIC_ID:= 6018
# 鸭翼（6007）：第 3 回合的额外费用。R81 由 2 点加强到 3 点。
# 抽成常量是为了让「数值」只有这一处 —— 卡面文案与回归断言都对着它写。
const DUCK_WING_RELIC_ID:= 6007
const DUCK_WING_TURN:= 3
const DUCK_WING_ENERGY:= 3
# 鸭嘴（6006，R399 加强）：**每满 5 点伤害减 2 点**，最少受 1 点。
# 旧版是「伤害 ≥5 时固定 -1」—— 在大伤害面前几乎等于没有，改成阶梯式。
#   5→3、9→7、10→6、15→9、20→12；不足 5 点的部分不折算（4 点照掉 4）。
const DUCK_BILL_RELIC_ID:= 6006
const DUCK_BILL_STEP:= 5
const DUCK_BILL_STEP_REDUCE:= 2
# R245 / R372 初始道具「勇气徽章」（6031）：精英战与 Boss 战**都只在首回合**额外 +1 费用。
# ── R311：水晶骰子 6040 / 不锈钢盆 6041 ──
# 水晶骰子（6040）：「?」房里的**任意种**战斗开始时掷一颗骰子（1~6），
#   **前 X 回合每回合额外 +1 费**（X = 点数）。
#   ⚠️ 「是不是 ? 房」由 battle_scene 写在 `dice_battle` 上（引擎不读地图）；
#   ⚠️ 点数在本文件用**战斗种子**（`rng`）掷 —— 回放同一 seed 必然同点数，
#      放到 battle_scene 用 run_rng 掷会让「重放一局」点出不同的数。
# 不锈钢盆（6041）：10 点计数**代替玩家承受等量伤害**，归零即失去道具（跨战斗累计）。
#   部分吸收：伤害 15 / 剩 10 → 盆吃 10、玩家只吃 5（**溢出部分还给玩家**，不吞）。
const DICE_RELIC_ID:= 6040
const DICE_FACES:= 6          # 骰子面数（1~6）
const DICE_ENERGY:= 1         # 「前 X 回合」每回合的额外费用
# ── R313：风妖精 6042 / 快速符文 6043 ──
# 风妖精（6042）：**一回合打出第五张牌时**，对所有敌人造成 4 点伤害。
#   挂 `_note_card_played()`（出牌唯一收尾口），判 `self_card_plays == 5`。
# 快速符文（6043）：每打出一张牌，本回合**技能伤害 +10%**（加算、去尾）；
#   **对「下回合不能行动」的敌人效果加倍**（即 +20%/张）。
#   * 百分比在 `_spell_dmg()` 里按「普通目标」结算一次（保证界面预览值 == 实际扣血值）；
#   * 「加倍」那一半在 `_hit_unit()` 里逐目标补（只有那里知道目标状态）；
#   * 只认**技能卡**：结算期由 `_run_spell_effect()` 打开 `_spell_scope`，
#     效果卡 / 陷阱 / 反伤不在此列。
const WIND_FAIRY_RELIC_ID:= 6042
const WIND_FAIRY_AT:= 5          # 第几张牌触发（每回合清零，故一回合只可能一次）
const WIND_FAIRY_DMG:= 4
const SWIFT_RUNE_RELIC_ID:= 6043
const SWIFT_RUNE_PCT:= 10        # 每张牌的百分比（加倍时 ×2）
# R314 两件**传奇**道具：
#   储物箱（6044）：回合结束时**不弃手牌** —— 判定在 `end_turn` 里那个 `discard_hand` 调用点，
#     实现是 `FieldState.discard_hand(keep_all)`（「消失」类照旧消失，见那里的注释）。
#   lucky 7（6045）：跨战斗计数（`RunState.lucky7_turns`），每 7 个我方回合**整轮生效**：
#     * 免疫所有 HP 伤害 —— `_damage_player` 里在减伤/盆之前直接挡掉；
#     * 技能额外 +7 —— `_spell_dmg` 里当固定加成，放在快速符文百分比**之前**（与鸭之眼同层）；
#     * 「本回合」= 从本次我方回合开始，**一直到下个我方回合开始**（含敌方回合）——
#       否则「免疫 HP 伤害」只在自家回合有效，而敌方回合才真会掉血，等于白给。
const STORAGE_RELIC_ID:= 6044
const LUCKY7_RELIC_ID:= 6045
const LUCKY7_DMG:= 7
# R315 爆米花（6046）：**本回合没有以敌人（或敌人所在格）为目标使用技能** → 下回合多抽 1 张。
#   * 判据是「**目标**」，不是「造成了伤害」—— 与风元素 9082 的 `_spell_hit_enemy`
#     （看窗口内有没有打到敌人）刻意分开：打空地 / 打自己人的技能照样算「指向了敌人」之外，
#     而 AoE 扫到敌人但目标是空格时**不算**（卡面写的是「以…为目标」）。
#   * 只在 `use_spell`（技能卡）里记账；效果卡 / 单位攻击都不算「使用技能」。
const POPCORN_RELIC_ID:= 6046
const POPCORN_DRAW:= 1
# ── R341 三件起始道具 ──
# 惊奇盒子（6047，第一层初始池）：获得时把一张 9179「惊奇盒子」加进卡组（结算在 RunState）；
#   卡片本身是 1 费 0/1 工事，**被攻击时**给攻击者挂「眩晕」—— 见 `attack()` 里的钩子
#   与 `_apply_stun()`（施加眩晕的唯一入口）。
#   盒子只有 1 血：任何攻击都会把它打掉，所以钩子**不判它是否还活着**（判了等于永不触发）。
# 洞窟绳（6048，第一层初始池）：Boss 以外的战斗能「逃跑」，用掉即失去 —— 不含引擎逻辑
#   （按钮与收尾都在 battle_scene，判据口 `RunState.can_use_cave_rope()`）。
# 鹿首标本（6049，第二层起始池）：每个我方回合开始 +1 层，本场战斗**永久累计**；
#   技能伤害在 `_spell_dmg()` 吃，陷阱 / 场地伤害在 `_field_trigger()` 吃 —— 两个口都要加。
const STUN_BOX_ID:= 9179
const STUN_BOX_TRAIT:= "惊奇盒子"
const STUN_TURNS:= 1
const CAVE_ROPE_RELIC_ID:= 6048
const DEER_TROPHY_RELIC_ID:= 6049
# R315 应急电源（9170，机械之心 0 费史诗技能 · 次元）：+1 费 + 抽 1 + 全体友方回 2。
const EMERGENCY_POWER_ID:= 9170
const EMERGENCY_POWER_ENERGY:= 1
const EMERGENCY_POWER_DRAW:= 1
const EMERGENCY_POWER_HEAL:= 2
# R316 极速（9171，暗影刺客 1 费稀有技能）：抽 2 张；抽到的牌里每有一张 0 费 →
#   **本回合所有敌人受到伤害 +1**（任何来源，与侦察塔光环同一个施加口）。
const RAPID_ID:= 9171
const RAPID_DRAW:= 2
const RAPID_PER_ZERO:= 1
# R316 激光扫射（9172，机械之心 2 费稀有技能）：对所有敌人造成 9 点伤害。
const LASER_SWEEP_ID:= 9172
const LASER_SWEEP_DMG:= 9
# R317 身法（9173，暗影刺客 1 费普通技能）：抽 5 张；**这回合结束为止不能使用盟友和工事卡**。
#   锁的判据放在 `can_use_card()`（显示 / UI / 引擎同一口）+ `play_from_hand()` 兜底；
#   只锁**盟友 / 工事**，场地卡与技能 / 效果卡照旧能打。
const REFLEX_ID:= 9173
const REFLEX_DRAW:= 5
# R317 淘汰（9174，机械之心 1 费史诗技能）：从**卡组**选一张盟友或工事 → 变成「素体」，抽 4 张。
#   选牌走 `eliminate_pending` + `eliminate_pick()`（UI kind = "eliminate"），
#   ⚠️ 抽 4 张在**打开面板之前**就结算 —— 取消面板只是放弃「变素体」，
#      不该把整张卡的收益一起吞掉（与合体那种「付费前挂起」的口径不同：这张已付费）。
const ELIMINATE_ID:= 9174
const ELIMINATE_DRAW:= 4
# R370 库存整理（9184，机械之心 1 费史诗技能）：从**卡组**随机挑 2 张，各变成随机一张卡。
#   * 随机池 = `_random_reward_card()`（本职业奖励池、稀有度三等分，与随心组装 9144 同源）
#     → 没解锁的剧情卡 / 被 ban 的卡**不会**冒出来；
#   * 抽哪两张也走引擎 `rng`（洗下标取前 N）→ 同种子回放一致；
#   * 敌方 AI 不用（改玩家牌组属玩家侧决策，与淘汰 9174 / 专注 9122 同口径）。
const INVENTORY_ID:= 9184
const INVENTORY_COUNT:= 2
const INVENTORY_REROLL:= 6          # 「变成**另一张**卡」的同 id 重摇上限（防死循环）
const BASIN_RELIC_ID:= 6041
const COURAGE_RELIC_ID:= 6031
## R372（用户口径「勇气徽章改为统一精英和 boss 第一回合 +1 费」）：
## 原来精英 1 回合、Boss **2** 回合 → 现在两档都只给**首回合**，所以合并成一个常量
## （留两个各 =1 的常量会给以后「又改回两档」留漂移口）。
const COURAGE_TURNS:= 1
# R245 诅咒「罐子」（9157）与它的召唤物（9158）。
# R351 赏月产出的两张效果卡（都在 `battle_end_rewards()` 里结算）。
const MOON_CARD_ID:= 9180
const COIN_CARD_ID:= 9181

const JAR_CURSE_ID:= 9157
# R373 诅咒「麻痹」（9185）：启示者阶段 2 的电磁屏障**每次**受到技能伤害 → 往玩家弃牌库
# 塞一张。无费用、**不能打出**（`CardData.unplayable`）、回合结束仍在手牌就消失。
const PARALYSIS_CARD_ID:= 9185
const JAR_TOKEN_ID:= 9158
# R246 二层起始道具「兼修」（6033）：我方每回合额外 +1 费用（与其它「回合开始加费」并列）。
const VERSATILE_RELIC_ID:= 6033


## R307「占卜室」五件道具
const SPRING_RELIC_ID := 6035        # 泉水：后排单位每回合回 4
const STEEL_STAMP_RELIC_ID := 6036   # 思想钢印：每场战斗第一个被破坏的我方单位回手卡
const THORN_RING_RELIC_ID := 6037    # 荆棘指环：每回合第一次受伤抽 2
const STATUE_RELIC_ID := 6039        # 雕像：每 10 张牌回 1 费用（计数在 RunState）
const SPRING_HEAL := 4
const PEAR_RELIC_ID:= 6019


const WHITE_WOLF_ID:= 9031
const RABBIT_ID:= 9032
const LYNX_ID:= 9033
const FOX_ID:= 9034
## 赤狐 9034 / 魔法学徒 9081（R65 改）：**只有它自己从卡组取到的那张技能牌**本回合费用 -1。
## 原实现挂的是 state.self_cost_reduction（全局「本回合出牌费用 -N」）→ 手里所有牌都便宜，
## 远强于卡面描述。现在改成给那一张牌挂 state.turn_card_discount（本回合减费表，
## 回合结束随表清空；显示 = 判定 = 实扣都走 cost_of），语义与警觉 9109 / 影魔 8007 同源。
const FETCH_SKILL_DISCOUNT:= 1
const COORD_ATTACK_ID:= 9035
const COORD_ATTACK_DMG:= 14
const BEAST_HEART_ID:= 9036
# R352 摇篮曲（9182，全职业公用 5 费史诗技能 · 次元）：所有单位 1 回合不能行动，不分敌我。
const LULLABY_ID:= 9182
# R352 森林的朋友们（9183，全职业公用 0 费稀有技能 · 次元）：
#   一张随机**森林精魄**盟友加入手卡，那张卡本回合费用 -2。
const FOREST_FRIENDS_ID:= 9183
const FOREST_FRIENDS_DISCOUNT:= 2
# R352 竖琴（6052，剧情解锁道具）：所有己方盟友 +2 力量。
const HARP_RELIC_ID:= 6052
const HARP_ATK:= 2
# R383 骑士剑（6053，剧情解锁道具）：本场战斗**第一次击杀敌人**之后 ——
#   己方所有盟友 +2 力量（与竖琴同一套持续 buff 写法），己方技能伤害 +2。
const KNIGHT_SWORD_RELIC_ID:= 6053
const KNIGHT_SWORD_ATK:= 2
const KNIGHT_SWORD_SPELL:= 2
const FOREST_GUARD_ID:= 9037
const LION_ID:= 9038
const LION_ATK_BUFF:= 2
const CROW_ID:= 9039
const CROW_TRAIT:= "鸦"
const HOUND_ID:= 9040
const HOUND_ATK_BUFF:= 2
const QUICK_STRIKE_ID:= 9041
const QUICK_STRIKE_DISCOUNT:= 1
const BITE_ID:= 9042
const BITE_ATK_BUFF:= 8
const TENACITY_ID:= 9053
const TENACITY_HP:= 3
const BEAST_TRAIT:= "野性"
const BEAST_DMG_BONUS:= 1
const BEAST_HP_BONUS:= 2
const ICE_WALL_SPELL_ID:= 9043
const ICE_WALL_ID:= 9044
const ICE_WALL_COUNT:= 3
const WIND_FORCE_TRAIT:= "疾风"
const WIND_FORCE_DMG:= 4
const RAT_ID:= 9046
const MECH_DUCK_ID:= 9047
const CLOCKWORK_DUCK_ID:= 9048
const MECH_DUCK_SUMMON_COUNT:= 2
const CLOCKWORK_TRAIT:= "发条"
const MECH_GROW_TRAIT:= "机械成长"
# 使魔之力（9115 敌方效果卡，R60）：挂在**敌方效果区**，每回合开始使场上
#   带「使魔」trait 的单位（trait 常量见 FAMILIAR_TRAIT）力量 +1（永久，无上限）。
#   加成只给「使魔」，不像机械成长那样给全部友方 —— 让巫师的使魔越滚越快。
const FAMILIAR_GROW_TRAIT:= "使魔成长"
const FAMILIAR_TRAIT:= "使魔"
const FAMILIAR_DUCK_ID:= 9009
const WIZARD_DUCK_ID:= 9008
const WHALE_WRATH_ID:= 9050
const WHALE_WRATH_DMG:= 11
const WHALE_PICK_COUNT:= 2
const NATURE_FORCE_ID:= 9051
const NATURE_FORCE_BASE:= 1
const TURTLE_DOVE_ID:= 9052
const TURTLE_DOVE_DISCOUNT:= 1
const DRAGON_BREATH_ID:= 9054
const DRAGON_BREATH_DMG:= 4      # R227：3 → 4（4 点 × 5 次 = 20，原 3 × 6 = 18）
const DRAGON_BREATH_HITS:= 5     # R227：6 → 5
const FRENZY_ID:= 9055
const FRENZY_ACTIONS:= 2
const FRENZY_DISCOUNT:= 1
const FRENZY_ALLY_MIN:= 3
# ---- R227：生命循环（9150，森林精魄 · 稀有 · 0 费技能）----
# 选一个**己方盟友** → 它获得字段「次元」「死亡」，并在 Placement 上打 `life_cycle`：
#   * 次元 → **离场即消失**：进消耗区（`void_count`），不进弃牌区
#     （`_destroy` 的己方分支认这个字段，与「离场消失」trait 同路）；
#   * 死亡 → 被破坏时把**一张随机盟友卡**加入手卡（`_deathrattle` 的 `life_cycle` 分支）。
# 随机源 = 本角色奖励池里的盟友卡（与「新生」9148 同口径），走引擎 rng → 回放可复现。
# ⚠️ 「死亡」字段是**通用标记**（幼龙 / 腐化尸鬼 / 捕兽大师等各有亡语，按卡 id 结算）→
#    本卡的效果绝不能用 `has_affix("死亡")` 判，只认 `Placement.life_cycle`。
# ⚠️ 本卡自己是普通技能（无次元字段）→ 用完照常进弃牌区。
const LIFE_CYCLE_ID:= 9150
# R229：商店附魔「起手」的 id —— 带这个附魔的卡**第 1 回合必定被抽到**
# （开局把它挪到牌库顶，与警觉 9109 同一套 `_ensure_opening_card` 手法，不动随机源）。
const ENCHANT_OPENING:= "opening"
# R370：商店附魔「抽牌 +1」的 id —— 带这个附魔的卡**打出后抽 1 张**。
# 挂点 = `_note_card_played()`（出牌**唯一**收尾口）→ 单位 / 工事 / 场地 / 技能 / 效果 /
# 两段式技能全部自动吃到，不必去 8 个 `cast_*` 各补一遍。
const ENCHANT_DRAW:= "draw"



const MIRROR_TRAIT:= "镜像"
const DETERRENCE_TRAIT:= "威慑"
const ARCANE_TRAIT:= "奥秘"

const ARCANE_CHARM_RELIC_ID:= 6020
const ARCANE_CHARM_DISCOUNT:= 1
const WISDOM_SURGE_ID:= 9059
const WISDOM_TRAIT:= "智慧"
const AETHER_BARRIER_ID:= 9060
const AETHER_TRAIT:= "以太"
const ENDLESS_BLESSING_ID:= 9061
const BLESSING_TRAIT:= "加护"
const FAMILIAR_NIGHT_ID:= 9062
const FAMILIAR_NIGHT_TRAIT:= "使魔之夜"

# R268：9063 / 9064 的触发条件 = **只认效果卡**（技能卡不再触发）。
const AETHER_ROAR_ID:= 9063
const AETHER_ROAR_TRAIT:= "以太咆哮"
const SPACE_GUARD_ID:= 9064
const SPACE_GUARD_TRAIT:= "空间守护"
const SELF_HEAL_ID:= 9065
const SELF_HEAL_TRAIT:= "自愈"
const STONESKIN_ID:= 9066
const STONESKIN_TRAIT:= "石肤"
# R407 易名：标识符仍叫 AETHER_*（牵一发动全身，改标识符没有收益），
# 但**卡名 / 词条值**是「大树守卫」—— 卡面「词条：」那一行读的是这里。
const AETHER_GUARD_ID:= 9067
const AETHER_GUARD_TRAIT:= "大树守卫"
const AETHER_GUARD_CAP:= 5
# R407 易名：以太恶魔 → **水元素**（标识符保留 AETHER_DEMON_*）。
const AETHER_DEMON_ID:= 9068
const AETHER_DEMON_TRAIT:= "水元素"
const DEMON_FETCH_DISCOUNT:= 2
const DUCK_NEST_ID:= 9069
const DUCK_NEST_TRAIT:= "鸭窝"
const EGG_VANISH_TRAIT:= "离场消失"
const RALLY_ID:= 9070
const RALLY_TRAIT:= "群起攻之"
const IRON_FENCE_SPELL_ID:= 9071
const IRON_FENCE_ID:= 9072
const IRON_FENCE_TRAIT:= "铁栅栏"
const OWL_ID:= 9073
const SPRITE_ID:= 9074
const SPRITE_EFFECT_DISCOUNT:= 2
const NIGHT_GROW_TRAIT:= "夜行"
## 夜鸭（9027，R270）：「惧光」—— **奇数回合**时移速 -1、攻击距离 -1，
## 且力量**临时减半**（R324 追加，实现在 `Placement.effective_power()` 出口，只算不写回）。
## 判据用 **id 而不是 trait** —— 「夜行」是「回合开始力量 +1」的成长族 trait，
## 以后再有夜行单位不该被顺手削弱；这条明确只属于夜鸭。
const NIGHT_DUCK_ID:= 9027
const NIGHT_DUCK_WEAK:= 1

## R340：敌方效果卡「永夜」（9178）—— 夜鸭**不再虚弱**：奇数回合也不吃「惧光」。
## 判据只看**敌方效果区**有没有这个 trait（见 `_refresh_night_owl`），多张不叠加。
const ETERNAL_NIGHT_TRAIT:= "永夜"

# ── 第 37 轮（2026-10-01）新卡 ──
# 魔法塔（9075 工事）：在场时，该方「伤害类技能」原本费用每 1 点 → 额外 1 点伤害。
const MAGIC_TOWER_TRAIT:= "魔法塔"
# 魔力核心（9076 效果）：每回合使用的第一张技能卡费用 -1、伤害 +1（效果区多张不叠加）。
const MAGIC_CORE_TRAIT:= "魔力核心"
const MAGIC_CORE_DISCOUNT:= 1
const MAGIC_CORE_DMG:= 1
# 火球术（9007 技能）：2 费；对目标格**十字（中心 + 四邻）**各 20 伤、不分敌我；
# 空格落在「HP 行」上 → 直击那一方的 HP（见 `_blast` / `damage_cell`）。
# R242：提成常量 —— 战斗场景的「AOE 范围提示」要按同一个 id 判形状，别再各写一遍字面量。
const FIREBALL_ID:= 9007
# 陨石术（9077 技能）：10 费；十字范围 40 伤、不分敌我；「留手」不弃；每次用技能永久 -1。
const METEOR_ID:= 9077
const METEOR_DMG:= 40
# 复活术（9078 技能）：从弃牌区取一张盟友回到手卡。
const REVIVE_ID:= 9078
# 返修（9127 技能，R188，机械之心 1 费稀有）：从弃牌区选一张盟友/工事回手，
# 并获得永久改造：生命 +3（烤进副本、本场战斗永久，口径同系统升级）。
const OVERHAUL_ID:= 9127
const OVERHAUL_HP:= 3
# 魔像术（9079 技能）：在己方半场召唤魔像；每用一张技能，手卡里这张本回合 -1。
const GOLEM_SPELL_ID:= 9079
const GOLEM_ID:= 9080
const GOLEM_TRAIT:= "魔像"
# 魔法学徒（9081 盟友）：从卡组取一张随机技能卡入手；本回合出牌费用 -1。
const APPRENTICE_ID:= 9081

# ── 第 38 轮（2026-10-01）新卡 ──
# 风元素（9082 盟友）：10 费 7/20 程2 速1。两条费用机制都挂在 cost_of 链上（显示=判定=实扣）。
# ① 在场时：该方技能牌费用 -1（多张叠加 —— 按该方场上本卡张数算）。
# ② 本次对战中每用技能牌对敌方造成一次伤害：手卡里的本卡费用 -2（本场战斗内累计，不跨战斗）。
# R407 易名：虚空主宰 → **风元素**（标识符保留 VOID_LORD_*；`void_dmg_spells` 这个名字
# 也是「虚空」来的，一并留着 —— 它记的是机制，不是卡名）。
const VOID_LORD_ID:= 9082
const VOID_LORD_TRAIT:= "风元素"
const VOID_LORD_PRESENCE_DISCOUNT:= 1
const VOID_LORD_DMG_DISCOUNT:= 2

# ── 流星雨（9083 技能，2026-10-01）──
# X 费卡：施放瞬间 X = 该方剩余的全部费用，一次性全部消耗（类杀戮尖塔）。
# 对随机敌人造成 METEOR_SHOWER_DMG 点伤害、重复 X 次，每次独立随机选目标；
# 费用挂 cost_of（显示=判定=实扣），X 在 use_spell / remote_spell 里**扣费之前**抓取。
# R124：**0 费用时也能使用**（此时 X 记 0）—— can_pay_card 对 X 费卡一律放行，
#       不再是「0 费用打不出/不可点」；空放会照常把这张卡消耗掉（离手进弃牌区）。
const METEOR_SHOWER_ID:= 9083
const METEOR_SHOWER_DMG:= 8

# ── 火墙术（9084 技能，2026-10-01）──
# 3 费普通技能：对一横行的**所有单位**（R247 起不分敌我）造成 FIRE_WALL_DMG 点伤害；
# 该横行持续燃烧到**施放方**的下次回合开始，期间任何单位（不分敌我）移动经过该行
# → 再受 FIRE_WALL_PASS_DMG 点。同一个单位从这张卡身上累计最多吃 FIRE_WALL_CAP 点
# （全卡合计上限，不是单次上限；开场即时伤害也算在里面）。
# R264（用户口径「下调火墙术延迟伤害：10-8（15点即时伤害不变）」）：
#   经过灼烧 10 → **8**；即时 15 与单位上限 15 都不动。
#   8 + 7 = 15 → 同一单位最多穿过两次就吃满，第二次只补 CAP 余量（7 点）。
# R387（用户口径「这个限制应该随着火墙术纸面伤害提升而提升」）：15 是**纸面值**，
#   每一面火墙实际用的单位上限 = FIRE_WALL_CAP + 这张卡的即时伤害增量。
#   附魔 +10 → 即时 25 / 经过 18 / 上限 25；没加成时仍是 15，旧行为一位不差。
const FIRE_WALL_SPELL_ID:= 9084
const FIRE_WALL_DMG:= 15
const FIRE_WALL_PASS_DMG:= 8
const FIRE_WALL_CAP:= 15

# ── 蓄力（9085 技能，2026-10-01）──
# 2 费史诗：本方使用的**下一张技能**结算 2 次（再叠一张就多结算一次）。
# 层数按阵营记账（_charge），在技能结算**之前**取走并清空 —— 所以蓄力绝不会把自己翻倍。
const CHARGE_SPELL_ID:= 9085

# ── 角色：森林精魄（2026-10-01）──
# 熊（8004，角色专属初始卡）：主动发动 —— 代替行动回复 BEAR_HEAL 点生命，之后横置；
# 「在场只能发动一次」记在 Placement.ability_used 上（离场再上场算新单位，可再发动）。
# 荒野形态（6022，角色赠品道具）**R60 重做**：每场战斗中**第一次**自己的 HP 被敌方
# 「普通攻击」打中时（直击 HP 的那条路径，技能/效果伤害不算），这次伤害 -4（最少 1），
# 并对攻击者造成 4 点伤害。用 state.wild_form_used 记「本场已触发」。
# 触发点：_hp_damage_taken 走不动（它管所有 HP 伤害），所以单独在 attack_hp 里判。
# R125：熊 生命 12 → 14（用户口径）。数值只写在 cards.json 上，此处不留副本。
const BEAR_ID:= 8004
const BEAR_TRAIT:= "回春"
const BEAR_HEAL:= 6
const WILD_FORM_RELIC_ID:= 6022
const WILD_FORM_REDUCE:= 4        # 第一次受击减伤
const WILD_FORM_RETALIATE:= 4     # 并对攻击者反伤

# 犀牛（9016，R125 由「骑兵」改名）：**受到的伤害 -1，但每次至少仍受 1 点**。
# 口径与「迅捷」9002（减 2 但至少 1）、荒野形态（maxi(1, raw - 4)）一致 ——
# 因此 1 点伤害仍会掉 1 血，不会被减成完全免疫。
# 判定走 `_unit_damage_taken()` 唯一口（见该函数注释：单位扣血有两个落地口，
# 只挂一处就会被绕过）。词条「骑兵」在本卡改名后无任何消费方，已一并移除。
const RHINO_TRAIT:= "犀牛"
const RHINO_DAMAGE_REDUCE:= 1

# 重甲战车（8058，R275 重做：3 费稀有盟友 3/12/2/1，嘲讽）：
#   **每拥有一层改造，受到的伤害 -1（每次至少仍受 1 点）**。层数口径同 R274 ——
#   手牌 / 牌库攒的层数上场也算（`upgrade_stacks` 随身）。判据走 id：
#   这是单卡专属机制，不污染别的「改造」卡。
const HEAVY_TANK_REDUCE_PER_STACK:= 1

# ── 第二层·普通困难「百臂工场」（R152）──
# 赫卡同克瑞斯（9136）：回合开始时若场上没有其他己方单位 → 力量 +2、受到的攻击伤害减半。
# ⚠️ 力量那一半记 `Placement.hecaton_atk`（由 `_refresh_hecaton` 实时重算写值，
#    与暗影领主同范式）；减伤那一半在 `_unit_damage_taken` 里实时判 `hecaton_atk > 0`。
#    两条都**不烤进 CardData** —— 敌方关卡单位用的是卡库共享实例，写 card 会跨局泄漏。
const HECATON_ID:= 9136
const HECATON_ATK_BUFF:= 2
# 量产型赫利俄斯（9137，工事 6/18）：在场时**除自己以外**的己方单位技能伤害减半（向上取整）。
# 开关 = `FieldState.has_mass_helios(side)`；自身除外在 `_unit_damage_taken` 里判 id。
const MASS_HELIOS_ID:= 9137

# ── 角色：暗影刺客（2026-10-01）──
# 终结（9086，角色专属初始卡，0 费技能）：对一个目标造成 RAID_BASE_DMG + X 点伤害，
#   X = 本回合**该方已使用的卡牌**张数；结算时它自己还没记进去 → 首张终结就是 2 伤。
#   计数走 FieldState.self_card_plays / opp_card_plays，回合开始清零。
# 幻影斗篷（6023，角色赠品道具）：持有方**每使用两张牌** → 随机一个敌方单位力量 -1，
#   复用「威慑」那套 atk_debuff / debuff_stage（debuff 在其所属方的回合结束时清除
#   = 持有方的下个回合开始之前恢复）。
const RAID_SPELL_ID:= 9086
const RAID_BASE_DMG:= 2
const PHANTOM_CLOAK_RELIC_ID:= 6023
const PHANTOM_CLOAK_DEBUFF:= 1
const PHANTOM_CLOAK_EVERY:= 2     # R60：每 2 张牌触发一次（原为每 1 张）

# ── 暗影刺客扩展（R45，2026-10-02）──
# 终结（9086，原「突袭」只改名）：4+X 伤，X = 本回合该方已使用的卡牌数（RAID_* 常量沿用）。
# 连刺（9087 技能）：1 费；对目标 4 伤；卡组随机 0 费技能卡入手。
const GOUGE_ID:= 9087
const GOUGE_DMG:= 4
# 敲晕（9088 技能）：0 费；对目标 3 伤 + 本回合力量 -3（atk_debuff / debuff_stage=1，与威慑同源）。
const STUN_BLOW_ID:= 9088
const STUN_BLOW_DMG:= 3
const STUN_BLOW_DEBUFF:= 3
# 独行（9189 技能，R406，暗影刺客 · 2 费）：对一个敌人造成 LONE_WALK_DMG 伤 + 本回合
#   力量 -LONE_WALK_DEBUFF；**随机让手卡一张盟友 / 工事「消失」**（本场对战移除），
#   把那两张卡的生命值 / 力量**永久**并进这张卡的伤害 / 降力（`CardData.lone_*_bonus`）。
#   * 「含本次」（用户口径）：消失**先于**伤害结算 → 这一下就吃到刚消失那张的数值；
#   * 「本次战斗有效」：累积记在**卡实例**上，跨战斗由每场 `build_deck()` 重建天然归零；
#   * 降力与敲晕 / 威慑同源（atk_debuff + debuff_stage=1，它所属方回合结束清除）——
#     用户卡面没写时效，但工程里**不存在跨回合降力机制**，降力本身仍按本回合口径；
#     被永久加成的只有「这张卡**降多少**」，不是「降多久」；
#   * 左栏不报数（随机 → 给不出最终伤害），见 `spell_now()` 的专门分支。
const LONE_WALK_ID:= 9189
const LONE_WALK_DMG:= 7
const LONE_WALK_DEBUFF:= 1
# 回转（9089 技能）：2 费；抽 X 张（X = 本回合已用卡牌数），这些牌本回合结束不弃（state.turn_keep）。
const SPIN_DRAW_ID:= 9089
# 影子猫（8006 盟友）：打出时，含此卡本回合已打出 ≥3 张 → 卡组随机技能卡入手。
const SHADOW_CAT_ID:= 8006
const SHADOW_CAT_NEED:= 3
# 影魔（8007 盟友）：打出时，手卡所有技能牌本回合 -1 费；每张 0 费技能卡 → +3 生命。
const SHADOW_DEMON_ID:= 8007
const SHADOW_DEMON_HP_PER:= 3
# 偷袭（9090 技能）：0 费；6 伤，目标满血 → 12 伤。
const SNEAK_ID:= 9090
const SNEAK_DMG:= 6
const SNEAK_FULL_DMG:= 12
# 疾风（9091 效果）：每使用一张卡 → 随机对一个敌人 2 伤（没有敌方单位 → 直击对方 HP）。
const GALE_ID:= 9091
const GALE_DMG:= 2
# 潜伏（9092 效果）：回合开始多抽 1 张；抽到 0 费 → 再抽 1 张（只多这一次）。
const LATENT_ID:= 9092
# 幽灵（8008 盟友）：自己回合开始时自行破坏；破坏时卡组随机技能卡入手（走 _deathrattle）。
const GHOST_ID:= 8008
# 连环戏法（9093 技能）：0 费；5 伤，含此卡本回合已用 ≥3 张 → 10 伤 + 抽 1 张。
const COMBO_TRICK_ID:= 9093
const COMBO_TRICK_DMG:= 5
const COMBO_TRICK_FULL_DMG:= 10
const COMBO_TRICK_NEED:= 3
# 准备（9094 技能）：1 费；抽 2 张，其中有 0 费 → 再抽 1 张（只多这一次）。
const PREPARE_ID:= 9094
# 怒涛（9095 技能）：2 费；10 伤；弃牌区所有 0 费卡回手。
const TORRENT_ID:= 9095
const TORRENT_DMG:= 10
# 潜影者（8009 盟友）：3 费 3/12；在场时每用一张牌力量 +1（Placement.ramp_atk），攻击后清零。
const LURKER_ID:= 8009
const LURKER_RAMP:= 1
# 回旋斩（9096 技能）：0 费；十字范围（中心 + 四邻）**敌方单位**各 17 伤；
# 使用门槛：本回合先使用 ≥4 张其他卡（can_use_card = 显示 / UI / 引擎同一判定）。
const WHIRL_BLADE_ID:= 9096
const WHIRL_BLADE_DMG:= 17
const WHIRL_BLADE_NEED:= 4
# 夜行（9155 技能，R232，暗影刺客史诗）：2 费；本回合我方所有卡费用为 0；
# 本回合我方出牌上限 NIGHT_WALK_MAX 张（**含本卡**，无论之前还是之后用的）。
## R306「占卜室」两张事件卡
const WISH_ID := 9168            # 许愿：0 费技能，从卡组选一张卡加入手卡（带「次元」字段）
const FLAME_SWORD_ID := 9169     # 烈火之剑：2 费技能，对每一列最靠前的敌人各造成 10 点伤害
const FLAME_SWORD_DMG := 10
const NIGHT_WALK_ID:= 9155
const NIGHT_WALK_MAX:= 5
# 蓄势（9156 技能，R232，暗影刺客普通）：1 费 + 保存；造成 value 点伤害（初始 0）；
# 回合结束时每剩 1 点费用 → 手卡里这张 +CHARGE_UP_PER_ENERGY 伤害（战斗内不重置）。
const CHARGE_UP_ID:= 9156
const CHARGE_UP_PER_ENERGY:= 3
# ── 暗影刺客扩展（R263，2026-10-19）──
# 弹跳飞刀（9160 技能，暗影刺客普通）：1 费；主目标 BOUNCE_KNIFE_DMG 伤，
#   之后从**其它**敌方单位里随机抽最多 BOUNCE_KNIFE_BOUNCES 个，各吃 BOUNCE_KNIFE_SPLASH。
#   文案口径「随机最多两个**其他**敌人」——「其他」= 排除主目标（同一只不会既吃主刀又吃弹跳），
#   「最多」= 场上不够就少弹（只剩主目标 → 一刀 5 伤，不弹）。
const BOUNCE_KNIFE_ID:= 9160
const BOUNCE_KNIFE_DMG:= 5
const BOUNCE_KNIFE_SPLASH:= 3
const BOUNCE_KNIFE_BOUNCES:= 2
# 预判（9097 技能）：0 费史诗；二选一：①弃牌区选一张 0 费技能卡（之后本卡消失）
# ②卡组随机非 0 费技能卡入手。面板走 foresight_* 状态机。
const FORESIGHT_ID:= 9097
# 拒绝命运（9098 技能）：2 费史诗；弃掉**全部**手卡 → 从弃牌区把**所有 0 费 / 1 费卡**
#   按弃牌区顺序加回手卡（不超过手牌上限）→ 本卡消失（带「次元」）。
# R292 改「自动结算」：以前是「从弃牌区选等量、必须选满」的模态面板；玩家口径
#   「直接把 0/1 费的捞回来」→ 面板整套（fate_pending / fate_options / fate_pick）已删。
const FATE_REJECT_ID:= 9098
const FATE_CHEAP_MAX:= 1        # 「0 费卡和 1 费卡」→ 判据 = 卡面费用 <= 1
# 幽光（9099 效果）+ 荧光草（8010 工事 token）：回合开始把荧光草塞进手卡；
# 荧光草在场时该方技能伤害 +1（多株叠加），离场即消失（VANISH trait）。
const GLOW_ID:= 9099
const GLOWGRASS_ID:= 8010
const GLOWGRASS_SPELL_BONUS:= 1
# 潜入（9100 技能）：0 费；选一个己方盟友移动到任意空格（对方后排仍禁入），它本回合力量 +3。
# 两段操作：UI 先点盟友再点目的格 → engine.cast_infiltrate()；敌方 AI / 自动出牌走 use_spell 的自动落点。
const INFILTRATE_ID:= 9100
const INFILTRATE_ATK:= 3
# 不眠（9101 效果）：自己的回合中每次结算收尾时手里没牌 → 抽 1 张；
# 抽到的 0 费卡本回合费用 +1（turn_card_discount 记 -1，回合结束随表清空）。
const SLEEPLESS_ID:= 9101

# ── 暗影刺客扩展（R48，2026-10-02）──
# 回响（9102 技能）：1 费稀有；对所有敌人造成 ECHO_DMG 点伤害，并让它们本回合
#   力量 -ECHO_DEBUFF（与敲晕 / 幻影斗篷同源：atk_debuff + debuff_stage=1）。
#   **使用后返回手卡** —— 唯一的循环代价就是费用，所以设了费用下限 ECHO_MIN_COST：
#   任何减费（魔力核心 / 风元素 / 小精灵…）都不能把它降到 0，否则 0 费无限回手。
const ECHO_ID:= 9102
const ECHO_DMG:= 2
const ECHO_DEBUFF:= 1
const ECHO_MIN_COST:= 1

# 闪躲（9103 技能）：0 费普通；直到自己下个回合开始，自己受到的 HP 伤害改由
#   **随机一个己方盟友**（kind == "盟友"）代受；该盟友生命不足 → 只吃掉它剩余的生命
#   （随即被破坏），超出部分照旧由自己承担。判定挂在 _damage_player（玩家 HP 伤害的唯一入口）。
const DODGE_ID:= 9103

# 收尾（9104 技能）：1 费稀有；对一个目标造成 FINISHER_DMG 点伤害，
#   若打出时它是**手卡里仅剩的一张** → 改为 FINISHER_LAST_DMG 点。
#   「仅剩一张」的判定在结算时读手牌（use_spell 先 remove_at 再结算 → 手牌为空即最后一张）；
#   敌方侧对称：remote_spell 先扣 opp_hand_count 再结算。伤害仍走 _spell_dmg（各路加成照吃）。
# R71 数值加强：基础 4 → 6，触发 15 → 22（手写死数值，回归里有断言钉住）。
const FINISHER_ID:= 9104
const FINISHER_DMG:= 6
const FINISHER_LAST_DMG:= 22

# ================= 场地卡（R74）=================
# 「名字含陷阱」的那 5 张（8011 爆炸 / 8012冰霜 / 8013 冻结 / 8014 剧毒 / 8016 穿刺）
# 从「工事」彻底改成**新卡种「场地」**（CardData.is_field()）：
#   * **不是单位** —— 不占位、不能被攻击、不挡路、不进AI 行动队列、不参与嘲讽/反伤/溢出；
#   * 钉在**一个格子**上（FieldState.field_effects，唯一写入口 set_field，每格最多1 个）；
#   * **敌人「移动经过」此格时触发一次，并立刻停止这次移动**（R80：不再是「走到这里
#     才触发」—— 只要**路径上经过**就炸，落在哪一格就停在哪一格）；
#   * 原本就站在该格上的敌人**不触发**（src 不在 path 里，只有「走进这段路」才触发）。
#触发口唯一 = _field_trigger（挂在 move() 里），不再挂在 attack() 上。
# 「经过就触发 + 立刻停止」的落点计算唯一口 = _field_block_index（只看 path，不看终点）。
const TRAP_ID:= 8011
const TRAP_TRAIT:= "爆炸陷阱"
const TRAP_DMG:= 18

const FROST_TRAP_ID:= 8012
const FROST_TRAP_TRAIT:= "冰霜陷阱"
const FROST_TRAP_DMG:= 9        # R278：4 → 9（用户口径「原本 1 费的冰陷阱 +5 伤害」）
const FREEZE_TRAP_ID:= 8013
const FREEZE_TRAP_TRAIT:= "冻结陷阱"
const FREEZE_TRAP_DMG:= 3
const POISON_TRAP_ID:= 8014
const POISON_TRAP_TRAIT:= "剧毒陷阱"
const POISON_DMG:= 6
const POISON_TURNS:= 4
const TRAP_MASTERY_ID:= 9105
const TRAP_MASTERY_TRAIT:= "场地精通"   # 9105 陷阱精通 R74 改名：口径从「工事」改成「场地」
## R329（用户口径）：加成 2X → 3X（X = 该场地卡的原本费用）。
## ⚠️ 这里是**唯一倍数口** —— 卡面文案（cards.json 的 9105 effect_text）必须与它一致，
##    引擎所有场地伤害都经 `_field_mastery()` 取这个值，别在别处再写死倍数。
const TRAP_MASTERY_MULT:= 3

# 机关工坊（8015 工事，R52 起；R74 改名「陷阱工坊」→「机关工坊」）：
#   **它仍然是「工事」，不属于场地卡**（卡名去掉「陷阱」只是文案去混淆）。
#   回合开始随机把一张本角色奖励池的工事加入手卡；被敌人的普通攻击**破坏**时对攻击者
#   造成 WORKSHOP_DMG 点伤害。注意它吃的是**场地精通**加成（原「陷阱精通」口径）。
const WORKSHOP_ID:= 8015
const WORKSHOP_TRAIT:= "机关工坊"
const WORKSHOP_DMG:= 8
const HUNT_ID:= 9107     # 暗影狩猎（9107 技能）：目标上回合触发过**场地** → 16 伤改 30 伤
const HUNT_DMG:= 16      # R329（用户口径）：12 → 16
const HUNT_BIG_DMG:= 30  # R329（用户口径）：24 → 30

const PIERCE_TRAP_ID:= 8016
const PIERCE_TRAP_TRAIT:= "穿刺陷阱"
const PIERCE_TRAP_DMG:= 18

# ── R83：清泉（8028）—— 场地卡的**第二个机制类别：持续型** ──
# 现有 6 张场地（8011~8017）全是「**一次性触发**」：敌人移动经过 → 结算 → 该格消失。
# 清泉反过来：**不因任何经过而触发、不会消失**，只是「站在这格的单位在自己回合结束时 +2 血」。
# 于是它**必须被排除出陷阱那条链**（否则敌人一走过就被白白消耗掉，这张牌等于废）：
#   * `_field_block_index` 跳过它 → 敌人正常走过、不被拦停；
#   * `_field_trigger` 早退 → 不会被摘掉，也不会记「暗影狩猎」的触发标记；
# 判据是 **trait「持续场地」**（R83 新增），走 cards.json —— 加新的持续型场地只要写这个 trait。
const FOUNTAIN_ID:= 8028
const PERSISTENT_FIELD_TRAIT:= "持续场地"
const FOUNTAIN_HEAL:= 2
# ── R88：持续型场地的第二族（「改造工厂」8037）──
# 维修间 8036（1 费稀有，机械之心）：站在上面的**己方**盟友/工事在自己回合结束时回
#   `CardData.field_heal` 点血（R276：2 → 4）。**与清泉 8028 是同一族机制、只差生效对象**。
# 改造工厂 8037（2 费普通，机械之心）：站在上面的**己方**盟友/工事在自己回合结束时
#   获得一次「改造」+1 力 / +1 血，**每回合都结算、可无限叠加**。
# ⚠️ 这两张都写了 trait「仅玩家可放置」→ 敌方 `remote_play` 直接拒放（用户口径）。
# 结算唯一口仍是 `_field_aura_tick`：它现在**按 trait 分派**而不是按卡 id 白名单，
# 所以加新的持续型场地只要写对 trait +（治疗型还要填 `field_heal`），引擎一行都不用改。
const REPAIR_BAY_ID:= 8036       # 维修间
const UPGRADE_FACTORY_ID:= 8037 # 改造工厂
const PERSIST_UPGRADE_TRAIT:= "持续改造"   # 改造工厂的判据 trait
const PLAYER_ONLY_FIELD_TRAIT:= "仅玩家可放置"
const UPGRADE_FACTORY_ATK:= 1
const UPGRADE_FACTORY_HP:= 1
# ── R381：漩涡 9186 / 鹅 9187（森林精魄剧情卡，暂无解锁渠道）──
# 漩涡（1 费场地）：**第三族持续型场地** —— 前两族（清泉 / 维修间 / 改造工厂）挂在
#   「自己回合结束时」结算（`_field_aura_tick`），它挂的是一个**新时机**：
#   「站在上面的单位**行动结束时**」→ 挂在 `_tap()`（所有行动结束的唯一口），
#   结算口 = `_vortex_push()`。
const PERSIST_VORTEX_TRAIT:= "涡旋"   # 漩涡的判据 trait（持续型场地 · 行动后卷人）
# 鹅（2 费盟友 1/9）：攻击后把目标向后击退 1 格、自己前进 1 格。
# 结算口 = `_goose_lunge()`（挂在 attack 尾部「攻击者还活着」那块里）。
const GOOSE_TRAIT:= "扑击"
# ── R89：无限装甲 8038（机械之心史诗盟友 4 费 4/18/1/1）──
# 「**每回合一次**：这张卡被「改造」时，将一张「升级」加入手牌，
#  那张牌在手牌里费用为 0，离开手牌后恢复原价。」
# ⚠️ R276（用户口径）：**固定给「升级」8027** —— 原先是「奖励池里随机一张效果含
#   『改造』的技能卡」，现在不再随机；其余口径（每回合一次 / 手牌内 0 费 / 只在场上算）全不变。
#
# 三个实现决定（用户当时已睡，按最合理口径定的，写在这里供日后核对）：
#  ① **候选池 = 本角色奖励卡池**里筛「技能 + effect_text 含『改造』」
#     —— 与机关工坊 8015 / 捕兽大师 9126 取场地卡同源口径（不是牌组，是卡池）。
#  ② **免费重置判据 = 「此刻还在不在手牌里」**（`state.hand_free` + `cost_of` 里验
#     `state.hand.has(card)`）—— 离手口有 10 处，逐个挂钩必漏，靠判据一次解决。
#  ③ **「每回合一次」记在 Placement 上**（`upgrade_feed_turn`，比对 `turn_total`），
#     所以它是**该卡自己**的限制：换一张装甲上场就有一份额度（与「场上单位」的语义一致）。
const INF_ARMOR_ID:= 8038
const INF_ARMOR_TRAIT:= "改造供能"     # 判据 trait（写卡面，走 from_dict/to_dict）
const UPGRADE_KEYWORD:= "改造"          # 候选池筛选关键词（卡面 effect_text 含它就算「改造牌」）
const INF_ARMOR_FEED_COST:= 0           # 供能牌在手牌期间的费用
# ── R90：系统升级 8039 + 批量传输 8040（机械之心稀有技能，各 1 费）──
# 两张都是「**改造手牌**」，与已有的「改造场上单位」是**两码事**：
#   * 场上改造（升级 8027 / 自我修复 8035）加在 `Placement` 上 → **离场还原**；
#   * 手牌改造（这两张）**烤进 CardData** → 跟着牌走，本场战斗永久。
# 之所以能烤进卡：改的是**手牌里那个独立副本**（`from_dict` 复制过），不是卡库实例；
# 下一场战斗 `RunState.build_deck()` 重新从卡库取实例 → 自动重置。
# 代价也**永久 +1**（用户口径「打出之后费用还加」）。
const SYS_UPGRADE_ID:= 8039
const BATCH_TRANSFER_ID:= 8040
const SYS_UPGRADE_COST_ADD:= 1   # 费用 +1
const SYS_UPGRADE_ATK:= 3        # 力量 +3
const SYS_UPGRADE_HP:= 6         # 生命 +6
# ── R273：批量传输与「系统升级」拆开口径 ──
# 原来 8040 直接复用 SYS_UPGRADE_*（费用 +1 / 力量 +3 / 生命 +6），
# 现在改成**不涨费用、只 +1 力 +4 血** —— 两个技能从此各有一套数，
# 别再合并（合并就是下一次改动漏改的根源）。
const BATCH_TRANSFER_ATK:= 1     # 力量 +1
const BATCH_TRANSFER_HP:= 4      # 生命 +4
const BATCH_TRANSFER_DRAW:= 1    # 批量传输：改造完抽 1 张卡
# ── R198：回收 8064（机械之心 2 费史诗技能：把手牌里一张卡换成素体）──
# 与「系统升级」同族（都改**手牌**、都烤进副本、都本场战斗永久），但结算是
# **换卡**而不是加数值：目标被**原位替换**成一张干净的「素体」副本（8025），
# 并立刻吃一次改造 = 生命 +RECYCLE_HP。走 `_upgrade_hp_gain` 唯一口 →
# 素体自己的 `upgrade_hp_bonus`(1) 照算 → 实际 +9（0 费 1/10），与「系统升级」同口径。
# 目标**不限盟友/工事**（素体就是盟友，技能/场地卡照样回收）—— 这是它的价值：
# 把用不上的废卡换成一张能留手的 1/10。唯一入口 `cast_recycle(手牌序号, 目标序号)`。
const RECYCLE_ID:= 8064
const RECYCLE_HP:= 8              # 改造基数（素体自身 +1 额外照算 → 实际 +9）
# ── R200：货物 8065（运送委托）—— 3 费工事 0/6/0/0（R280 费用 1 → 3）──
# **被破坏时从卡组中删除**：`_destroy` 己方分支唯一口 —— void（不进弃牌区）
# + `RunState.remove_card` 删卡组那份。货物是「占卡组名额的负债」：
# 带着它进第二层，第一个事件房会变成「委托完成」。
const CARGO_ID:= 8065
# ── R202：机械之心扩展（发明专家 / 随心组装 / 聚能炮击 / 填充）──
# 「发明专家」（9143，2 费稀有效果）：己方每次在战斗内**变化**一张卡 → 回复 2 费。
# 变化事件统一走 `_transform_hand_card` / `_invention_refund`。
const INVENTION_EXPERT_ID:= 9143
const INVENTION_REFUND:= 2
# 「随心组装」（9144，1 费史诗技能）：将手牌里所有卡变成随机奖励卡（按稀有度三等分）。
const ASSEMBLE_ID:= 9144
# 「聚能炮击」（9145，1 费普通技能）：造成 9 点伤害并抽 1 张。
const ENERGY_CANNON_ID:= 9145
const ENERGY_CANNON_DMG:= 9
# 「填充」（9146，0 费普通技能）：将手牌里一张卡变成聚能炮击。两段式入口 `cast_reload`。
const RELOAD_ID:= 9146
# ── R290：机械之心两张伤害技能（集中突破 9162 / 冲击炮 9163）──
# 「集中突破」（9162，2 费**普通**技能）：造成 BREAKTHROUGH_DMG 点伤害，
#   场上**己方**单位每有 1 层改造，伤害 +BREAKTHROUGH_PER_STACK。
#   层数只读**场上**（`Placement.upgrade_stacks`），手牌 / 牌库里的层数不算 ——
#   卡面写的是「场上的己方单位」，与侦察塔 / 堡垒那种「随身层数」口径不同。
const BREAKTHROUGH_ID:= 9162
const BREAKTHROUGH_DMG:= 10
const BREAKTHROUGH_PER_STACK:= 4
# 「冲击炮」（9163，2 费**稀有**技能）：造成 IMPACT_CANNON_DMG 点伤害，
#   并把目标击退 IMPACT_CANNON_STEPS 格（走唯一口 `_knockback`：位移免疫 / 被挡住 /
#   朝目标所属方后排，全部自动生效；先伤害再击退，被打死就不击退）。
const IMPACT_CANNON_ID:= 9163
const IMPACT_CANNON_DMG:= 10        # R369：8 → 10（用户口径）
const IMPACT_CANNON_STEPS:= 1       # R369：2 → 1 格（用户口径）
# ── R291：机械之心两张技能（辅助刃 9164 / 复制术 9165）──
# 「辅助刃」（9164，0 费**普通**技能，目标 = 己方盟友）：
#   * 一次改造 = **+BLADE_ATK 力量**，走 `_field_upgrade_grant()` 唯一口 —— 于是层数
#     （堡垒 / 侦察塔 / 谟涅摩叙涅）、卡面改造奖励（素体 +1 血 / 战斗骨骼 +2 力 +2 血）、
#     「每次被改造」那一整族（榴弹击手 / 机器鸟 / 无限装甲 / 废弃机器人）全部照常反应；
#   * 同时挂「死亡」字段 + `Placement.blade_gift` 标记 → 被破坏时**把一张辅助刃加入手卡**
#     （`_deathrattle` 开头按**标记**分派；判据不认「死亡」字段，见 Placement 的注释）；
#   * 字段是「场上这段」的：离场由 `_card_leaving_field()` 摘掉，回手后仍是原样。
#   ⚠️ 0 费 + 亡语回收一张自己 → 会循环（给 A 打一张、A 死了拿回一张），这是卡面本就
#      写着的口径；强度靠「必须死一个单位」来换，不做上限拦截。
const BLADE_GIFT_ID:= 9164
const BLADE_ATK:= 2
# 「复制术」（9165，5 费**史诗**技能，目标 = 己方盟友或工事）：
#   把这张卡**此刻的样子**复制 DUPLICATE_COUNT 份加进手卡：
#     * **保留 buff** —— 力量把 `Placement.upgrade_atk` 烤进副本 `power`；生命直接取
#       `card.health`（改造加的血早就在里面）、攻程 / 移速同理（`_upgrade_unit` 烤在副本上）；
#     * `upgrade_stacks` **置 0** —— 数值已经全烤进副本，再随身带层数会被
#       `FieldState.place()` 按层数折一次（堡垒 +3 血/层、榴弹击手 +1 程/层）→ 双计；
#     * 每份都挂「次元」字段 → 上场后离场即消失（`_destroy` 认字段），不会变成永久卡；
#     * 本回合在手牌里 0 费：`state.turn_free[copy]`（`cost_of` 的唯一判据，回合结束清空
#       → 没打出去的下回合恢复原价）。
const DUPLICATE_ID:= 9165
const DUPLICATE_COUNT:= 2
# ── R91：充电装置 8041 + 字段系统（CardData.affixes）──
# 充电装置（1 费工事 1/1/1，机械之心普通）：**接通**的**我方**盟友和工事，
#   在自己回合结束时回 CHARGE_HEAL(2) 点生命。
# 「接通」= **闪电链 `_connected_components()` 的四方向相邻连通关系**，
# 但**只算我方单位**（闪电链不分敌我，这里按用户口径收窄）。
# 唯一口 `_charge_tick(side)`，挂在 `end_turn()` 的 `_regen_tick` 旁边（同属回血收尾）。
const CHARGE_STATION_ID:= 8041
const CHARGE_TRAIT:= "接通"
const CHARGE_HEAL:= 2
# ── R92：接通家族第 2、3 张（护盾生成器 8042 / 模仿者 8043）──
# 「接通」判定仍是同一套 `_connected_components()`，但不再各写一份扫描：
# 统一走助手 **`_component_of_cell(cell)`**（在 `_charge_tick` 下面），
# 三张接通类卡共用一条连通判定。
const SHIELD_GEN_ID:= 8042      # 护盾生成器：接通的我方单位受伤 → 改由它承受
const MIMIC_ID:= 8043           # 模仿者：接通的盟友获得改造 → 它获得相同改造
# ── R95：机械之心 8044 / 8045 ──
# 「加厚装甲」（8044，1 费**普通**技能）：使**场上的一个己方盟友**获得改造：生命 +4。
#   口径（已与用户确认）：**算一层改造** → 会照常触发侦察塔（每层 +1 攻）/ 堡垒（每层 +3 血）/
#   无限装甲（每回合供一张 0 费改造牌）/ 模仿者（传导），与「升级」8027 完全同口径。
#   加成记在 Placement 上（`upgrade_hp`），离场由 `_card_leaving_field` 还原 —— 别烤进 CardData。
#   ⚠️ 与「升级」不同：**只吃盟友**（用户原话「一个我方盟友」），工事不能选。
const ARMOR_PLATE_ID:= 8044
const ARMOR_PLATE_HP:= 4
## R275：加厚装甲额外给「受到伤害 -1（每次至少仍受 1 点）」——
## 记在 `Placement.dmg_reduce`（本场累计、只算场上，离场随单位消失），
## 与「改造层数」是两条独立的账（层数随身、减伤只在场上）。
const ARMOR_PLATE_REDUCE:= 1
# 「自主升级」（8045，2 费效果卡）：**回合开始时**随机使**抽牌堆**里一张盟友或工事
#   获得改造：+2 攻 / +1 血。
#   * 候选只从 `state.deck`（抽牌堆）挑 —— 与「过载」8030 / 「能量屏障」8033 同口径。
#   * 改造**烤进那张卡**（`from_dict` 复制 + 原位替换）→ 本场战斗永久，且不污染卡库
#     （下一场 `RunState.build_deck()` 重新取卡库实例 = 原卡）。
#   * 效果区有多张时**不叠加**（符合效果区一贯惯例）：每回合只改造 1 张。
const AUTO_UPGRADE_ID:= 8045
const AUTO_UPGRADE_TRAIT:= "自主改造"
const AUTO_UPGRADE_ATK:= 1
const AUTO_UPGRADE_HP:= 3
# ── R96：机械之心 8046 / 8047 / 8048 ──
# 「零件回收者」（8046，3 费**史诗**盟友 1/14/1/1，R208 由普通升史诗）：与这张卡**接通**的己方
#   **素体以外**的盟友或工事被**破坏**时，这张卡攻击力 += 被销毁卡的力量，并往手牌加一张「素体」。
#   * R221：被销毁的卡是「素体」（8025，PROTO_ID）→ **不触发**（防「拆素体 → 回收 + 补一张素体」
#     的永动刷攻循环）；判据用 card.id 比对 PROTO_ID（卡库仅 8025 带 trait「素体」）。
#   * 触发口唯一 = `_destroy`（全游戏唯一破坏口），在 erase 之前先抓同连通块里的回收者。
#   * 「接通」= `_component_of_cell`（四方向相邻，隔敌也算连通），但此处只认 SIDE_SELF 回收者
#     + 受害者必须是己方盟友/工事（卡面明写「己方」）。
#   * 攻力加成记 `upgrade_atk`（离场还原），不加 `atk_buff`（那个有 GROW_CAP 封顶）。
#   * 加素体 = 独立副本 append 到手牌，与机械核心 6025 同口径（手牌满就停）。
const RECYCLER_ID:= 8046
# 「嵌合暴君」（8047，4 费**史诗**盟友 3/20/1/1，**嘲讽**）：**使用时**（play_from_hand 入场钩子）
#   破坏所有与这张卡**接通的己方**卡，并将那些卡的力量与生命加到自己身上（永久，离场还原）。
#   * 范围按用户口径**只己方**（不含敌方、不含自己）；用 `_component_of_cell` 取连通块过滤。
#   * 吸收的攻/血落 `upgrade_atk`/`upgrade_hp` + 抬 `card.health`/`p.health`（与 `_upgrade_unit` 同口径），
#     故意**不**走 `_upgrade_unit` / 不调 `_mimic_relay` → 不会触发侦察塔层数 / 模仿者传导（这是专属吸收）。
#   * 吸收的「生命」取被吞卡**场上副本的最大生命**（`u.card.health`，含其受到的场上加成）。
const CHIMERA_ID:= 8047
## R326（用户口径）：入场效果**追加** —— 每破坏一个回复 1 点费用。
## ⚠️ 这条**不写入卡面文本**（8047 的 `effect_text` 保持原样），属于隐藏的入场收益。
## 回费口径同「拆解」8049：直接 `state.energy +=`，不污染 `self_energy_spent`，允许当回合超额。
const CHIMERA_REFUND_PER_KILL:= 1
# 「生产订单」（8048，1 费**普通**技能）：将两张「素体」加入**抽牌堆**，各获得改造 +1 攻 +4 血
#   （永久、烤进副本，不污染卡库；与「过载」8030 / 「自主升级」8045 同口径）。
const PROD_ORDER_ID:= 8048
const PROD_ORDER_ATK:= 1
const PROD_ORDER_HP:= 4
# ── R97：机械之心 8049「拆解」──
# 1 费**稀有**技能：指定自己一个己方盟友或工事，**破坏**它，回复 3 点费用，往手牌加一张
# 「素体」；若目标**被改造**（upgrade_stacks>0 或 upgrade_atk!=0 或 upgrade_hp!=0，
# 覆盖「升级」技能 / 「改造工厂」场地 / 「自我修复」三种来源），额外获得一张「升级」8027。
# * 破坏走唯一破坏口 `_destroy` → 自然联动「零件回收者」8046（体系一致）。
# * 回费用 `state.energy += 3`（与「契约签订者」/「奥秘精通」同口径：不污染
#   `self_energy_spent`，且允许当回合超额 —— 回合开始重置为 5）。
# * 「额外获得升级」= 往手牌 append 一张「升级」8027 的独立副本。
# * 拖拽到「被改造」的合法目标上时，界面金色高亮 + 「额外获得升级」文字提示（见 battle_scene）。
const DEMOLISH_ID:= 8049
const DEMOLISH_REFUND:= 3
const DEMOLISH_UPGRADE_BONUS:= 8027   # 「额外获得升级」给的卡
## ── 字段名常量（R91）—— 引擎一律读 `CardData.affixes`，不再按卡名 / 数字硬编码 ──
const AFFIX_SWIFT:= "疾行"          # 一回合行动两次（判据 actions>=2 / acts_left>1）
const AFFIX_TAUNT:= "嘲讽"          # 敌方只能攻击这张卡
const AFFIX_DEATH:= "死亡"          # 被破坏时生效（只做标记，内容看卡面）
const AFFIX_PHANTOM:= "幻影"        # 手牌里给它加一张自身的短暂复制（回合结束消失）
## 「次元」（R93）：使用后 / 离场后消失，不进弃牌区。
## 与「幻影」区分见 `CardData.AFFIX_DEFS` 注释：幻影说的是**手牌里回合结束**消失那种。
const AFFIX_DIMENSION:= "次元"
## 「超负荷」（R98，旧式机兵 8050）：生命降到 0 以下不会立即死亡，以负数血量继续存活；
## 伤害不会溢出（不触发后排「溢出伤害」漏给玩家 HP）；己方回合结束时若仍为负则死亡。
const AFFIX_OVERLOAD:= "超负荷"
# ── R99：机械之心 8051 / 8052 / 8053 ──
# 「重组」（8051，1 费**史诗**技能）：指定一个己方盟友或工事，使其**回复至满生命**
#   （= 当前场上最大生命，即 card.health + upgrade_hp）。
#   * 自动出牌只在有**受伤**的己方盟友/工事时出（否则不浪费这张史诗牌）。
# 「城墙」（8052，2 费**普通**工事 0/10/0）：带「超负荷」字段 —— 纯数据卡，
#   走全局超负荷机制（_destroy_dead 跳过 / _overload_tick 在己方回合结束杀负血单位），引擎无需特判。
# 「超越极限」（8053，0 费**稀有**技能，次元）：指定一个己方盟友或工事，
#   **挂上「超负荷」字段 + 算一层改造** —— 与「升级」8027 同口径：侦察塔/堡垒读 upgrade_stacks
#   自动反应，无限装甲走 _feed_upgrade_card，接通的模仿者走 _mimic_relay(AFFIX_OVERLOAD)。
const REORG_ID:= 8051
const WALL_ID:= 8052
const TRANSCEND_ID:= 8053
const REBOOT_ID:= 8054
const STEEL_GUARD_ID:= 8055
const RESCUE_ID:= 8056
const GRENADIER_ID:= 8057
const HEAVY_TANK_ID:= 8058
const MECH_BIRD_ID:= 8059
const DAEDALUS_ID:= 8060
# ── R269：机械之心 8068 轻量化 / 8069 共享护盾 ──
# 「轻量化」（8068，2 费**普通**技能，手牌目标）：改造**手牌里一个盟友** → 费用 -1、移动速度 +1。
#   与「系统升级」8039 同一套纪律（烤进副本、本场战斗永久、不污染卡库），只是一减一加；
#   费用**下限 0**（0 费盟友不会被减成负费）。只吃盟友：工事移速恒为 0，加了没意义。
const HAND_LIGHTEN_ID:= 8068
const HAND_LIGHTEN_COST_DELTA:= -1
const HAND_LIGHTEN_SPEED_ADD:= 1
# 「共享护盾」（8069，0 费**稀有**技能，场上盟友目标）：给一个己方盟友挂字段「共享护盾」
#   + 算一层改造 → 之后**我方 HP 要掉血时改由它承受**。
#   判据唯一口 = `absorbs_for_hp()`（森林守护 / 大树守卫 / 铁栅栏 / 本字段共用一条通道），
#   于是引擎结算与战场绿环自动同源，battle_scene 一行都不用改。
const SHARED_SHIELD_ID:= 8069
const AFFIX_SWAP:= "交换"
## 「共享护盾」（R269，8069 赋予）：替我方的 HP 承受伤害。
## ⚠️ 与「护盾」（能量屏障的一次性免伤）**不是一回事**：那个免的是**这张卡自己**受的第一次伤害，
##   这个是**玩家 HP** 要掉血时改由这张卡挨打（每次都能顶，顶到死）。
const AFFIX_SHARED_SHIELD:= "共享护盾"
# ── R271：机械之心「聚能」体系（6 张新卡 + 代达罗斯 8060 重做）──
# 这一批共用三条骨架，先讲清楚，下面各卡只写差异：
#   ① **聚能计数** `state.self_cannon_plays` = 本次对战中我方**使用过**几张「聚能炮击」9145。
#      记账口唯一 = `_note_card_played()`（所有出牌路径的统一收尾），不另开计数器；
#   ② **手卡内减费** `state.hand_cost_delta` = 只在卡**此刻还在手牌里**时生效
#      （判据 `hand.has(card)`，与 `hand_free` 同一条路）→ 打出 / 弃掉自动恢复原价，
#      不必在那 15 处离手口逐个清标记；
#   ③ **随机变化标记** `CardData.random_born` = `_transform_hand_card()` 复制出来的卡
#      （= 卡面说的「以随机变化的方式加入手卡」），由 `_apply_random_born()` 一处结算。
# 「创意」8070（2 费**史诗效果**）：回合开始时，选一张手卡变成一张随机
#   「**被改造时有额外效果**」的卡，并获得改造：生命 +2。
#   随机池判据与 `_on_unit_upgraded()` 同源 = `upgrade_atk_bonus` / `upgrade_hp_bonus` > 0，
#   或带「改造攻程 / 改造移速 / 改造抽牌」trait。层数照样 +1（侦察塔 / 堡垒会响应）。
const CREATION_ID:= 8070
const CREATION_HP:= 2
# 「报废」8071（R410 升**史诗**技能）：把手牌里**其他所有卡**变成「聚能炮击」，
#   这些卡**本回合**费用为 0（`turn_card_discount`，回合结束随表清空）。
const SCRAP_ID:= 8071
# 「谟涅摩叙涅」8072（4 费**史诗盟友** 5/16/1/1）：在场时所有敌人力量 -X（X = 本卡改造层数）；
#   若以随机变化方式加入手卡 → 手卡内费用 -2。
#   ⚠️ 光环走 `Placement.mnemo_down`（同 dark_lord_atk 范式），由 `_refresh_mnemosyne()` 重算。
const MNEMOSYNE_ID:= 8072
const MNEMOSYNE_RAND_DISCOUNT:= 2
# 「聚能机兵」8073（2 费**普通盟友** 1/8/1/1）：入场时，本次对战每用过一张聚能炮击 → 力量 +1。
const CANNON_MECH_ID:= 8073
const CANNON_MECH_ATK_PER:= 1
# 「量产型代达罗斯」8074（3 费**普通盟友** 3/12/1/1）：入场时选一张手卡变成聚能炮击；
#   若本卡以随机变化方式加入手卡 → +2 攻 +2 血。
const MASS_DAEDALUS_ID:= 8074
const MASS_DAEDALUS_BORN_ATK:= 2
const MASS_DAEDALUS_BORN_HP:= 2
# 「量产型谟涅摩叙涅」8075（2 费**普通工事** 0/10）：
#   **每回合一次**：你使用「聚能炮击」时，该炮击伤害 +MASS_MNEMOSYNE_DMG，
#   且它因自身效果抽到的那张卡费用 -1（实例级减费 `state.card_discount`，本场有效）。
#   ⚠️ R341 改版（用户口径）：原先只有减费、没有「每回合一次」。现在**伤害加成与减费
#   共用同一个额度** —— 只有拿到 +7 的那一发炮击才给抽到的卡减费。
#   额度记 **`Placement.mass_mnemo_turn`**（比对 `turn_total`，与无限装甲 8038 同范式）——
#   **每座工事各一份**：场上两座 = 一回合两次；工事被打掉 / 回手额度随之消失。
const MASS_MNEMOSYNE_ID:= 8075
const MASS_MNEMOSYNE_DMG:= 7
const MASS_MNEMOSYNE_DISCOUNT:= 1
# 「改装者」8076（R282，3 费**普通**盟友 3/8/1/1，机械之心）：
#   入场时己方**所有盟友**（场上 + 手牌）各获得一次「改造」：生命 +4（不含工事；含它自己）。
const MODDER_ID:= 8076
const MODDER_HP:= 4
# 「失控要塞」9161（R288 实装 / R404 改触发口径，2 费**史诗工事** 0 攻 / 1 血 / 无法移动，机械之心）：
#   入场时，本次对战中你**每变化过一张牌** → **随机释放一张机械之心技能卡**。
#   ⚠️ R404（用户口径）：触发计数从「用过几张聚能炮击」换成「**变化过几张牌**」——
#      计数走 `state.self_card_changes`（唯一记账口 `_note_card_changed()`），
#      「变化」的语义与发明专家 9143「每变化一张卡」完全同源。
#   三条口径，全部落在 `_fort_play()` 这一处：
#     ① 卡是**凭空生成**的（不在手牌 / 牌库 / 弃牌区）→ 复制一份临时插进手牌末尾，再走
#        原有的施放入口。这样「选手牌 / 卡组 / 弃牌区」这些需要**真实位置**的技能
#        （系统升级 8039 / 回收 8064 / 轻量化 8068 / 填充 9146 / 返修 9127 / 双向传送 8061）
#        都能按原有流程结算，不必另写一套「虚空施放」的第二实现；
#     ② **不消耗费用**：卡面写的是「释放」—— 玩家并没有为这张凭空出现的卡付钱
#        （`use_spell(..., free_cast = true)` / `cast_*(..., free_cast = true)`）；
#     ③ 目标与落点**随机且合法**：先枚举合法目标、再让 `rng` 抽一个（回放可复现）；
#        抽到的技能此刻没有合法目标就换一张，最多把池子试一圈（`_fort_cast_one`）。
const OUT_OF_CONTROL_FORT_ID:= 9161
const OUT_OF_CONTROL_MAX_CASTS:= 20
# ── R298：集束炮台 9166 / 合体 9167（机械之心）──
# 「集束炮台」（9166，2 费**普通**盟友 1/6/1/1，机械之心）：两条效果各有一个唯一口 ——
#   ① **入场** → `_cluster_turret_enter()`：往抽牌库塞 CLUSTER_TURRET_CANNON_COUNT 张
#      「聚能炮击」9145（与生产订单 8048 同口径：`from_dict` 复制，绝不塞卡库共享实例）；
#   ② **每次获得改造时** → 挂 `_on_unit_upgraded()`（所有改造入口的统一后置口，与机器鸟
#      「改造抽牌」/ 榴弹击手「改造攻程」同一族）→ `_cluster_turret_reload()`：从卡组里
#      捞一张聚能炮击**加入手卡**（手牌满则留在卡组，不销毁玩家的牌）。
#   ⚠️ 只对**场上**的集束炮台生效 —— `_on_unit_upgraded()` 仅在场上 Placement 上被调，
#      手牌 / 牌库里的改造（系统升级 8039 / 集体改造 8031）走不到这里（它得在场才装填）。
#   ⚠️ 「改造」本身不给它数值：卡面没写 +攻/血 → **不填** `upgrade_*_bonus`
#      （填了会被 `_upgrade_atk_gain` 当成「被改造时 +N」白送）。
const CLUSTER_TURRET_ID:= 9166
const CLUSTER_TURRET_CANNON_COUNT:= 2
const CLUSTER_TURRET_TRAIT:= "集束"   # 只做标记（与「废铁」/「拾荒」同套路），判据只认它
# 「合体」（9167，1 费**史诗**技能，机械之心，目标 = 己方盟友或工事）：
#   两段式，全靠 `cast_merge()` 这一口：
#    ① 先在**场上**指定一张己方盟友或工事（`target_mode = "unit"`，拖拽 / 点选同一条路）；
#    ② 再弹「从卡组选一张素体」面板（`merge_pending`，UI kind = "merge"）；
#    ③ 选中那张素体 → 它**消失**（进消耗区 `void_count` / `void_cards`，不进弃牌区 ——
#       与专注 9122 / 负重减轻 8066 同口径），**然后**才扣费并打出去；
#    ④ 目标获得一次改造：**力 + 那张素体的 power、血 + 那张素体的 health** ——
#       走 `_field_upgrade_grant()`（场上改造唯一口）→ 层数 +1、受体自己的改造奖励
#       （战斗骨骼 +2+2 / 素体 +1 血）照算，模仿者传导 / 侦察塔 / 堡垒全部联动。
#   ⚠️ **付费点故意挪到第 ③ 步之后**：面板打开期间合体仍在手牌、费用未扣 → 取消 = 什么都没
#      发生（与回收 / 填充「取消不扣费」同口径）；否则玩家先在场上点了目标、又在面板里放弃，
#      会白丢 1 费 + 一张史诗牌。
#   ⚠️ 数值取**卡组里那张副本**（可能被生产订单 8048 / 自主升级改过），不取卡库原型。
const MERGE_ID:= 9167
# ── R300：激发 8077（机械之心 2 费**史诗效果卡**）──
# 卡面：「每次你的一张卡被改造时，对随机 2 个敌人造成 3 点伤害。可叠加。」
# R362（用户口径）：**原先打全体，改成打随机两个** —— 场上只剩一只时就有多少打多少。
# 三条口径（用户原话）：
#   ① **无论在哪** —— 手牌 / 牌库 / 场上的己方卡被改造都算（触发点因此要覆盖
#      系统升级 8039（手牌）、自主升级 8045（牌库）、升级 8027（场上）三类入口）；
#   ② **无论一次性改造多少张都算一次** —— 「集体改造 8031」「批量传输 8040」
#      「改装者 8076」这种一次改一整批的，只触发**一次**；
#   ③ **可叠加** —— 效果区每有一张激发，每次触发就各打一轮（2 张 = 每轮 3 点、打 2 轮）。
# ⚠️ 触发口绝不能挂进 `_field_upgrade_grant()` / `_on_unit_upgraded()` 那种**逐张**口，
#    否则批量改造 10 张会打 10 次。必须在**动作级**函数末尾各调一次 `_inspire_tick()`。
# ⚠️ 「改造」= 走 `_upgrade_atk_gain` / `_upgrade_hp_gain` 的**数值改造**（与 `_is_upgraded()`
#    同口径）。只加字段 / 加 trait 的（能量屏障 8033 加「护盾」、过载 8030 加双动）**不算**。
const INSPIRE_ID:= 8077
const INSPIRE_DMG:= 3
## R362：每次触发命中**随机几个**敌人（每轮各自抽，两轮可以打不同两只）。
## ⚠️ 选人走 `rng`（不是当前毫秒）：回放 / 同种子必须复现同一组目标。
const INSPIRE_TARGETS:= 2
# 「涂装机器人」8080（R404，2 费**稀有盟友** 2/9/1/1，机械之心）：
#   入场时，选场上**其他**一个友方单位 → 把它变成一张随机「机械之心」单位
#   （池 = 本职业奖励卡池里的盟友 + 工事，`rarity <= 2`，见 `_paint_pool()`）——
#   玩家据「随机」与「机械之心」两个词都能预期到它是随机池、且不会变出别职业的卡。
#   四条口径：
#     ① **要选人** → `paint_pending` + `paint_src`（自己那格，用来排除「其他」）；
#        UI 高亮可点的己方单位，点一格走 `paint_pick()`、右键 `paint_cancel()`；
#        场上没有别的己方单位 → 直接落空，**不挂 pending**（免得玩家被一个没得点的状态卡住）；
#     ② 「变成」**不是**「被破坏」→ 旧单位直接从棋盘摘掉（`state.board.erase`），
#        亡语 / 击杀记功 / 零件回收者 / 思想钢印一律不触发；
#     ③ 「变成」**也不是**「入场」→ 新单位**不跑**入场效果。否则随机到失控要塞会再开一串技能、
#        随机到量产型代达罗斯会开手牌面板，嵌套 pending 一路打不完；
#     ④ 新单位以 `summon = true` 落地（本回合 1 次行动），并照常吃道具的常驻力量加成
#        （`_relic_on_enter_buffs()`，与手牌打出同一个口）。
const PAINT_BOT_ID:= 8080
# 「代达罗斯」8060（R271 重做；R330 调为 4 费**史诗盟友** 5/16/1/1，嘲讽）：
#   入场时本次对战每用过一张聚能炮击 → 生命 +3；本回合手卡里的聚能炮击费用为 0。
const DAEDALUS_HP_PER_CANNON:= 3

# ── R331：机械之心两张稀有效果卡（隐藏能源 8078 / 惊喜运单 8079）──
# 「隐藏能源」8078（3 费**稀有效果**）：**友方单位入场时**，获得一次改造，
#   并获得「死亡」—— 它被破坏时，对**距离 1** 的随机一个敌人造成 HIDDEN_ENERGY_DMG 点伤害。
#   * 「距离」用**曼哈顿**（与 `attack_distance` / 侦察塔光环同一口径），1 = 上下左右相邻；
#   * 友方 = 出牌那一方（敌方效果区里的本卡只给敌方单位挂，敌我对称）；
#   * 效果区**多张不叠加**：同一单位只挂一次（与送葬 / 巨炮「可叠加才叠加」同口径）；
#   * 判据只认 `Placement.hidden_energy`（「死亡」是通用字段，认字段会串戏）。
const HIDDEN_ENERGY_ID:= 8078
const HIDDEN_ENERGY_DMG:= 8
const HIDDEN_ENERGY_RANGE:= 1
# 「惊喜运单」8079（2 费**稀有效果**）：**回合开始时**，选卡组一张卡 →
#   把它变成一张随机卡（本职业奖励池，`_random_reward_card()` 与随心组装 9144 同池）
#   并加入手卡。效果区几张就结算几次（与创意 / 新生同口径）；敌方不做选牌决策 → 落空。
const SURPRISE_ID:= 8079

# ── R332：暗影刺客稀有技能「本能」9176 ──
# 2 费：**随机打出抽牌库中 3 张费用 ≤1 的技能卡**。
#   * 候选 = `state.deck` 里 `is_spell()` 且 `cost_of(card, side) <= INSTINCT_MAX_COST`；
#     X 费卡（流星雨 9083）**显式排除** —— 0 费用时它也算「可打出」，等于白丢一张；
#     本能自身也排除，防止被减费后自我递归。
#   * 打出走 `use_spell(..., free_cast = true)`：**不向玩家收费**，但保留全部既有守卫
#     （夜行出牌上限 / 两段式技能打不出 / 没有合法目标 / 选牌面板）——
#     打不出的卡**放回牌库原位**，不占「3 张」配额。
#   * 随机源只用引擎 `rng`（RunState.run_seed）：先取下标再删牌 → 回放一致。
const INSTINCT_ID:= 9176
const INSTINCT_COUNT:= 3
const INSTINCT_MAX_COST:= 1
# ── R393：击杀成长（暗影刺客 / 森林精魄新卡）──
# 猎杀 9205：3 费史诗技能 · 次元；基础伤害写在卡面 `value`（25），每击杀 +6 本局永久。
# 赏金猎人 9204 / 秃鹰 9206 的「每场首次击杀」数值走卡面字段
# `first_kill_power / first_kill_health`，引擎按字段判，不为卡名写死分支。
const SLAY_ID:= 9205     # ⚠️ 别并进上面的 HUNT_ID（那是 9107 暗影狩猎），两个 id 语义不同
const UPGRADE_RANGE_TRAIT:= "改造攻程"
## R275：重甲战车 8058 移除本 trait（改为「每层改造受到的伤害 -1」）——
## 当前**没有任何卡**带「改造移速」，分支保留给未来的卡用。
const UPGRADE_SPEED_TRAIT:= "改造移速"
const UPGRADE_DRAW_TRAIT:= "改造抽牌"
## 双向传送（8061 技能，R102）：0 费；指定战场上**两个单位**，交换它们的位置。
# 两段操作：UI 先点单位甲、再点单位乙 → engine.cast_swap_units()；
# 敌方 AI / 自动出牌走 use_spell 的自动兜底（见 _run_spell_effect）。
const SWAP_UNITS_ID:= 8061
## 「能量屏障」8033 赋的护盾也登记成字段（R91）—— 否则这张牌被强化后
## 玩家在任何地方都看不到「它有护盾」。
const FIELD_BARRIER:= "护盾"

# 巨物陷阱（8017，R54 起是「巨物捕获」工事；**R76 改成场地卡并改名**）：1 费稀有（R278 由 2 费下调）。
#   口径跟其它场地卡一致：不是单位、钉在一个格子上、**敌人移动经过此格**时触发一次
#   （R80：路过即中，不必停留）**并立刻停止这次移动**，之后该格场地消失
#   （每格最多 1 个，按场地生效·敌不能放自己后排），吃场地精通加成。
#   原来那套「被打中没破坏就回手 / 破坏就反伤 2×攻击力」是工事专属机制，
#   场地卡不会被攻击（也不在 board 里），所以那两个分支已全部删除。
const MASS_TRAP_ID:= 8017
const MASS_TRAP_TRAIT:= "巨物陷阱"
## R217（2026-10-18）用户口径：伤害 = **10 + 踩上来的那个单位当前攻击力 × 2**。
## 「当前攻击力」读 `Placement.effective_power()`（含增减益 / 成长 / 改造 / 改造加攻），
## **不是卡面 power** —— 卡面 0 攻的单位踩上来就只有 10 点。
const MASS_TRAP_DMG:= 10
const MASS_TRAP_ATK_MUL:= 2

# ---- R217（2026-10-18）分裂之影 8067 ----
# 分裂之影（8067 工事，暗影刺客·**稀有**）：2 费 0/5/0。
#   **自己的回合开始时抽 1 张卡**；场上每多一座就多抽 1 张（多座叠加）。
# * 判据读**场上 Placement 的 trait**（与机关工坊 8015 / 荧光草 8010 同范式），
#   不读效果区 —— 这张是工事，离场就没有这个效果。
# * 抽牌走 `_draw_many`：手牌已满会照常发 hand_full、牌库/弃牌区都空也照常记日志。
# * 敌方侧对称保留（敌方正常拿不到这张卡）：只推进 `opp_hand_count`，不偷我方牌库。
const SHADOW_SPLIT_ID:= 8067
const SHADOW_SPLIT_TRAIT:= "分裂之影"

# ---- R105（2026-10-08）黑暗陷阱 8063 ----
# 黑暗陷阱（8063 场地，暗影刺客·普通）：**0 费**；敌人**移动经过**此格时立刻触发
#   （R80 口径：路过即中，不必停留）并**立即停止这次移动** →
#   **那个敌人本回合攻击时力量 -1**。
# 与冰霜陷阱（8012 禁足）/ 冻结陷阱（8013 冰冻）同族：都不造成伤害，只给**状态**。
# 降力量复用「威慑 / 敲晕 / 幻影斗篷 / 回响」那套 `atk_debuff + debuff_stage = 1`：
#   debuff_stage=1 = **立即生效**，在**该单位所属方的回合结束时**清除 ——
#   陷阱是敌方移动时踩的（= 敌方回合内），所以正好覆盖「它本回合剩下的攻击」。
# ⚠️ 0 费 → 场地精通（9105）加成是 3×0 = 0；这张本来就不造成伤害，加成无意义。
const DARK_TRAP_ID:= 8063
const DARK_TRAP_TRAIT:= "黑暗陷阱"
const DARK_TRAP_DEBUFF:= 1      # 本回合攻击时力量 -1

# ---- R248（2026-10-19）落石陷阱 9159 ----
# 落石陷阱（9159 场地，暗影刺客·**史诗**）：**2 费**（R278 由 3 费下调）；敌人**移动经过**此格时立刻触发
#   （R80 口径：路过即中，不必停留）并**立即停止这次移动** → 对踩上来的那个单位造成
#   ROCKFALL_TRAP_DMG 点伤害；**这一下若将其击杀，溢出的伤害不丢弃**（用户口径「践踏」）。
# * 践踏语义与 R225 攻击践踏（`_trample_chain`）一致：溢出不丢弃、沿**同一列**逐个
#   击穿踩雷者**同侧**的单位，打穿整列后剩余伤害漏到该方 HP。
# * 方向差异：攻击践踏是「远离攻击者、冲向 defender 后排」，陷阱**没有攻击者**，
#   方向固定取「踩雷者所在方的后排」—— 于是「原地不动踩响」（R238 `_trap_still_tick`）
#   同样享受践踏，不需要移动方向信息（`_field_trigger` 两个调用点都覆盖）。
# * 每一段都走 `_hit_unit`（单位扣血唯一口）→ 侦察塔光环 / 石肤 / 护盾转发照常生效；
#   is_attack 保持默认 false —— 这是**效果/陷阱伤害**，不是普通攻击。
# * 特效复用「trample_hit / trample」（R225 攻击践踏同款）—— 同效果必须同特效。
# * 击杀不记功给任何单位（last_hit_by 置 -1）：陷阱格上没有「攻击者」，不置的话
#   会误记给本回合早先打过它的单位（鸭子骑士白拿 buff）。
const ROCKFALL_TRAP_ID:= 9159
const ROCKFALL_TRAP_TRAIT:= "落石陷阱"
const ROCKFALL_TRAP_DMG:= 29

# ---- R116（2026-10-09）捕兽大师 9126 ----
# 捕兽大师（9126 盟友，暗影刺客·**史诗**）：3 费 2/8 程1 速1。
#   **亡语：在原地留下一张随机陷阱。**
# * 「随机陷阱」= 本角色奖励池里的**一次性场地**（唯一口 `_trap_card_pool`）；
#   与机关工坊 8015 / 警觉 9109 同一来源（唯一口 `_field_card_pool`）。判据**不写死卡名 / id** ——
#   往后加新陷阱、或给别的角色加陷阱，这里一行都不用改。
# * 原地已有场地效果时**不覆盖**（那张多半是玩家自己埋的）→ 见 `_deathrattle_place_trap`。
const TRAPPER_ID:= 9126
# 活体栅栏（8018 工事，R54）：2 费稀有；2/8/1。可攻击的【栅栏】类工事（带 FENCE_TRAIT，
#   可参与「叠栅栏」）。
# R319（用户口径）：效果与文案统一成「**入场时抽一张卡**」—— 挂点是 `play_from_hand`
#   里其它 `_xxx_enter(p)` 那一排，走 `_draw_many` 统一口。
const LIVING_FENCE_ID:= 8018
const LIVING_FENCE_DRAW:= 1   # 入场时抽几张
# 警觉（9109 技能，R54）：2 费稀有。**第 1 回合必定抽到**（开局把牌库里那张挪到牌库顶）；
#   使用时把一张随机工事（本角色奖励池）加入手卡，那张卡**本回合内**费用 -ALERT_DISCOUNT
#   （R60 改：用 state.turn_card_discount 本回合减费表，回合结束清空 → 不跨回合；
#   显示 = 判定 = 实扣都走 cost_of）。技能卡本身用完照常进弃牌区。
const ALERT_ID:= 9109
const ALERT_DISCOUNT:= 2

# ---- R55「回合结束 · 剩余费用」系列（2026-10-03）----
# 三张卡共用**一个结算入口** _end_turn_surplus()：自己回合结束、费用清零**之前**调用，
# 读该方**本回合没用完的剩余费用**（state.energy_of(side)），按各自的换算比例结算。
#   * 地狱猫 8019（0 费普通盟友 1/1）：剩余费用每 1 点 → 本卡 +1 力 +2 血；
#   * 鲜血堡垒 8020（0 费稀有工事 1/1/程1）：剩余费用每 1 点 → 本卡 +1 力 +3 血；
#   * 活力转移 9110（2 费史诗效果）：剩余费用每 2 点（向下取整）→ **下个回合开始时**
#     多给 1 点费用（记 state.self_next_energy / opp_next_energy，_begin_turn 发放后清零；
#     效果区多张本卡**不叠加**，只算一层）。
# 力量成长是**永久**的（Placement.end_atk，无上限、不随回合结束清除）；生命同理直接加
# p.health（Placement 没有「生命上限」字段，加多少就是多少）。
const HELL_CAT_ID:= 8019
const HELL_CAT_TRAIT:= "地狱猫"
const HELL_CAT_ATK:= 1
const HELL_CAT_HP:= 2
const BLOOD_FORT_ID:= 8020
const BLOOD_FORT_TRAIT:= "鲜血堡垒"
const BLOOD_FORT_ATK:= 1
const BLOOD_FORT_HP:= 3
const VITALITY_ID:= 9110
const VITALITY_TRAIT:= "活力转移"
const VITALITY_COST:= 2      # 剩余费用每 2 点 → 换 1 点下回合的额外费用

# ---- R56（2026-10-03）三张新卡 + 结算顺序 ----
# 暗影之刃 9111（2 费稀有效果卡）：回合结束时对**随机一个敌人**造成
#   DARK_BLADE_SPENT_MULT(1) × 本回合**已花掉**的费用数 点伤害。
#   X 读 FieldState.self_energy_spent / opp_energy_spent（由 pay_energy 唯一记账，
#   回合开始清零）—— 与「剩余费用」口径相反：这张卡奖励的是**花钱**而不是攒钱。
#   效果区多张不叠加（取一张）。
const DARK_BLADE_ID:= 9111
const DARK_BLADE_TRAIT:= "暗影之刃"
# 黑暗领主 8021（4 费史诗随从 5/10/1/1）：**打出后**在本回合结束时自己的费用 +5，
#   且这一步**优先于其它「剩余费用」类结算**执行（先 +5，再算地狱猫/鲜血堡垒/活力转移
#   /暗影锁链的剩余费用）→ 这 5 点会一起被那些效果读到。多个黑暗领主各自 +5（可叠加）。
const DARK_LORD_ID:= 8021
const DARK_LORD_TRAIT:= "黑暗领主"
const DARK_LORD_ENERGY:= 5
# 暗影锁链 9112（1 费稀有效果卡）：回合结束时，剩余费用每 3 点（向下取整）
#   把**随机一个敌人**击退 2 格；每次独立随机选目标。效果区多张不叠加。
const DARK_CHAIN_ID:= 9112
const DARK_CHAIN_TRAIT:= "暗影锁链"
const DARK_CHAIN_COST:= 3      # 剩余费用每 3 点 → 一次击退
const DARK_CHAIN_STEPS:= 2     # 每次击退格数

# ---- R57（2026-10-03）四张新卡 ----
# 黑暗扩散 9113（1 费史诗效果卡）：自己回合结束时，剩余费用每 1 点 →
#   对**所有**敌人造成 2 点伤害（每点费用都乘一次）。走通用 _hit_unit + _destroy_dead，
#   敌人在后排水位被打破时按**通用后牌溢出**规则漏到玩家 HP（与其他 AoE 一致）。
#   效果区多张不叠加。
const DARK_SPREAD_ID:= 9113
const DARK_SPREAD_TRAIT:= "黑暗扩散"
const DARK_SPREAD_PER_ENERGY:= 2   # 每 1 点剩余费用 → 全体敌人 2 点伤害
# 地狱咏唱者 8022（3 费稀有盟友 1/11/程2/速1）+ 黑暗祭坛 8023（3 费稀有工事 1/15/程1）：R282 两张由普通升为稀有，数值不变
#   **攻击时**回复 1 点费用（trait 咏唱者 / 祭坛）。两卡共用 ATTACK_GAIN_ENERGY，
#   触发点是 attack() 尾部（本次攻击确实打出去才触发；被拒绝的非法攻击不算）。
#   工事也能攻击（1 攻/射程 1），所以祭坛同样成立。
const CHANTER_ID:= 8022              # 地狱咏唱者
const CHANTER_TRAIT:= "咏唱者"          # 地狱咏唱者 8022
const ALTAR_TRAIT:= "祭坛"              # 黑暗祭坛 8023
const ATTACK_GAIN_ENERGY:= 1            # 攻击时回复的费用
# 无尽黑暗 9114（1 费稀有效果卡，R70 改）：**每回合抽牌之后**，
#   玩家**强制从手牌里选 1 张弃掉**（R70 起不再随机弃；**不能不选**），
#   然后获得 2 点费用。挂在 _begin_turn 抽牌之后（选的就是本回合刚抽到的牌）。
#   效果区多张不叠加；手牌为空时无可选 → 本回合不弃也不给费用（见 _endless_dark）。
const ENDLESS_DARK_ID:= 9114
const ENDLESS_DARK_TRAIT:= "无尽黑暗"
const ENDLESS_DARK_DISCARD:= 1     # 每次触发弃几张
const ENDLESS_DARK_ENERGY:= 2      # 每次触发换几点费用

# ---- R222（2026-10-18）新生 9148（森林精魄 · 史诗 · 2 费效果卡）----
# 「回合开始时，选一张手卡消失，随机将一张卡牌加入你的手卡。」
#   * 挂在 `_begin_turn` **抽牌之后**（用户口径：抽卡之后结算 —— 选的就是刚抽完的那手牌）；
#   * 「消失」= 本场对战移除（既不进手牌也不进弃牌区），与专注 9122 / 负重减轻 8066
#     同口径：`void_count += 1` + `void_cards.append`；
#   * 随机卡池 = `reward_pool_for(RunState.player_class)`（**本职业奖励卡牌**，
#     与无尽加护 9061 同一口径，只多一个「不限效果卡」的差别）；
#   * 默认**按效果区张数逐份结算**（使魔之夜 / 无尽加护同款默认语义：卡面没写
#     「不叠加」就逐张来）→ 两张新生 = 选两张消失、拿两张随机卡；
#   * 手牌为空 → 没有可消失的牌 → 整条落空（不触发、也不补随机卡）；
#   * 敌方侧没有真实手牌（只记张数）→ 对称落空，不开面板。
const REBIRTH_ID:= 9148
const REBIRTH_TRAIT:= "新生"

# ---- R103（2026-10-07）夜蚀 8062 ----
# 夜蚀8062（2 费史诗盟友 2/8/程1/速1）：**自己回合结束时**，回复 X 点生命值，
#   X = **自己剩余费用**（state.energy_of(side)，即这张卡读的是「本回合没用完的钱」，
#   与地狱猫 8019 / 鲜血堡垒 8020 / 活力转移 9110 / 暗影锁链 9112 同一口径）。
# 与那几张的**关键区别**：那几张给的是**永久成长**（Placement.end_atk / 直接加 p.health，
#   等于抬上限），夜蚀是**回复**（把已损失的血补回来，**上限仍是卡面 health**），
#   所以走的是 _regen_tick 那一套「不满血才回、mini 夹上限」的口径。
# 结算入口同样挂在 _end_turn_surplus()（费用清零之前），读同一个 left。
# 满血时不结算也不刷飘字（与 _regen_tick / _charge_tick 一致，避免「回复 0」噪声）。
const NIGHT_EROSION_ID:= 8062
const NIGHT_EROSION_TRAIT:= "夜蚀"
const NIGHT_EROSION_PER_ENERGY:= 1    # 每 1 点剩余费用 → 回复 1 点生命

# ---- R104（2026-10-08）起手式 9119 ----
# 起手式（9119 技能，暗影刺客·普通）：1 费；**对目标造成 4 点伤害，然后抽 1 张卡**。
# 定位是「连刺 9087」的平行变体：同为 1 费 4 伤，连刺补的是「卡组随机 0 费技能卡入手」，
# 起手式补的是**确定性的抽 1 张**（不挑费用、不依赖卡组里有没有 0 费技能）。
# 伤害走 _spell_dmg()（吃荧光草 / 魔法塔 / 魔力核心 / 鸭之眼等既有加成，与连刺同口径）；
# 抽牌走 _draw_many()（手牌满则停，与批量传输 8040 同口径）。
# ⚠️ 抽牌是**玩家侧收益**，敌方 AI 用这张卡只结算伤害、不抽牌（与准备 9094 同口径）。
const OPENING_MOVE_ID:= 9119
const OPENING_MOVE_DMG:= 4       # 基础伤害
const OPENING_MOVE_DRAW:= 1      # 结算后抽几张


# ---- R108（2026-10-08）影袭 9120 / 暗影步 9121 ----
# 影袭（9120 技能，暗影刺客·稀有）：1 费；对目标造成 8 点伤害，
#   若**含本卡**本回合已使用 3 张卡，回复 1 点费用。
# 判定读 `state.self_card_plays + 1`（self_card_plays 在 _note_card_played 里已含本卡，
#   但结算伤害发生在记卡之前，所以这里 +1 才是「含本卡」的最终张数）—— 与连环戏法 9093 同源。
# 伤害走 _spell_dmg()（吃荧光草 / 魔法塔 / 魔力核心等既有加成）；回费走 state.energy += 1
#   （与活力转移 9110 / 契约签订者 / 奥秘精通同口径：不污染 self_energy_spent，允许当回合超额）。
const SHADOW_STRIKE_ID:= 9120
const SHADOW_STRIKE_DMG:= 8         # 基础伤害
const SHADOW_STRIKE_NEED:= 3        # 含本卡累计用满几张
const SHADOW_STRIKE_REFUND:= 1      # 达标回费

# 暗影步（9121 技能，暗影刺客·稀有）：2 费；先对目标造成 8 点伤害，
#   再从**弃牌区任选一张**（任意 kind，不限盟友）返回手卡。
# 取牌面板与复活术 9078 同构但用**独立变量**（shadow_step_pending / _remaining）——
# 复活术的候选是「仅盟友」，口径不同，混用同一套变量会互相污染。
# ⚠️ 取牌是**玩家侧收益**：敌方 AI 用这张卡只结算伤害、不取牌（与起手式 9119 同口径）。
const SHADOW_STEP_ID:= 9121
const SHADOW_STEP_DMG:= 8
const SHADOW_STEP_NEED:= 1          # 要从弃牌区取回几张


# ---- R109（2026-10-08）专注 9122 ----
# 专注（9122 技能，暗影刺客·稀有）：0 费；从**抽牌库**里选 2 张卡，这 2 张卡
#   **本次对战中消失**（既不进手牌也不进弃牌区，等于把这 2 张从本场牌组里抹掉）。
# ⚠️ **不抽牌**：这是「减牌库」而非「取牌」。定位是压缩牌组、减少之后的废抽。
# 候选面板复用界面既有的「卡组」浏览面板（按 id 合并 + 按 (费用,id) 排序），
# 所以玩家**推不出抽牌顺序** —— 面板给的是卡组视角，不是牌堆顶视角。
# ⚠️ 敌方 AI 不使用这张卡（改牌组是玩家侧决策，AI 用了会污染玩家牌序；与预判 9097 同口径）。
const FOCUS_ID:= 9122
const FOCUS_NEED:= 2            # 要从抽牌库移除几张
# 负重减轻（8066 技能，暗影刺客·史诗，R201）：0 费；从抽牌库里选 1 张卡，这张卡
# **本次对战中消失**，并且**下个回合开始时多抽一张卡**。
# 面板完全复用专注那套（focus_pending / focus_options / focus_pick / focus_cancel），
# 区别只在：张数是 1、以及选完后给 state.self_next_draw 记 +1（见 focus_pick 末尾）。
# ⚠️ 敌方 AI 不使用这张卡（与专注 9122 同口径：改牌组是玩家侧决策）。
const LIGHTEN_ID:= 8066
const LIGHTEN_NEED:= 1          # 要从抽牌库移除几张
# 白魔法鸭（9021）「精进」：自己的回合开始时，本方带此 trait 的单位力量 +MAGE_GROW_BUFF
# （永久累计，无上限）—— 已去掉「只剩它自己」的前置条件，任何场面都稳定成长。
# 注：本卡 value=10 归「治疗」用（回血量），所以成长量走常量，不读卡面 value。
const MAGE_GROW_TRAIT:= "精进"
const MAGE_GROW_BUFF:= 1


# ── R82：野兔 9032「自我复制」+ 机械之心（8025~8027）──
# 野兔 9032（1 费稀有盟友 1/2/1/1，RABBIT_ID 见上方 9032 那组）：**使用后**手牌增加
# 一张自己的复制。复制卡是「场上/手牌里的临时衍生物」，两段寿命各由一个唯一口管：
#   * 在**手牌**里没被打出 → 回合结束消失（FieldState.discard_hand 认 is_ephemeral）；
#   * 打出后**在场上**离场 → 消失，不进弃牌区（GameEngine._destroy 认 is_ephemeral）。
# ⚠️ 两处都判 `CardData.is_ephemeral`，**不是** CLONE_TRAIT：卡库原卡也带这个 trait，
# 它是牌库实体，被弃 / 被打死时都该照常进弃牌区。
# ⚠️ 复制卡**保留**「自我复制」trait —— 用户口径是「复制卡上场后还能再复制」，
# 于是可以链式增殖：这是这张卡强度爆炸的根源，改口径要同时改这里与卡面文案。
const CLONE_TRAIT:= "自我复制"
# R319（用户口径）：野兔的复制统一成「**短暂复制**」—— 定义是：
#   ① 带**次元**字段（徽标显示次元；离场 / 用后即消失）；② `is_ephemeral` → 手牌回合结束消失。
# 于是复制品生成时**去掉幻影、换上次元**：幻影只描述「手牌里会消失」，看不出离场那条；
# 本体自己**保留**幻影（它才是「打出后多一张短暂复制」的触发标记）。
# 「升级」（8027，2 费技能，机械之心）：改造一个己方盟友或工事 → +2 攻 / +8 血。
# 加成**只在场上有效**、离场由 _card_leaving_field 还原（不烤进 CardData）。
# R84：每张卡**自己的**改造奖励（素体 +1 血 / 战斗骨骼 +2 力 +2 血）**读卡面字段**
# `CardData.upgrade_atk_bonus` / `upgrade_hp_bonus` —— 不再在这里按卡名硬编码，
# 所以以后加新盟友只要填字段，引擎一行都不用动。
const UPGRADE_ID:= 8027
const UPGRADE_TRAIT:= "改造"
const UPGRADE_ATK:= 2
const UPGRADE_HP:= 10
const PROTO_TRAIT:= "素体"       # 仅供界面/图鉴筛「素体」用；判定已改读卡面字段
const PROTO_ID:= 8025
const CONSTRUCT_ID:= 8026       # 构装体（3 费 3/8/1/1，本体无机制，只是厚实的盟友）
const BATTLE_BONE_ID:= 8029     # 战斗骨骼（2 费 2/7/1/1，改造时 +2 力 +2 生命）
# 「过载」（8030，**史诗**技能，机械之心，R85）：从**牌库**里随机一张
# 「还没有一回合行动两次」的盟友，给它加上这个特性（**永久**改牌）。
# 「一回合行动两次」= `CardData.actions >= 2`（**没有**对应 trait，判据就是这个字段）——
# 现有 5 张卡自带：灰烬龙 1013 / 亡灵领主 1051 / 熔岩巨人 1071 / 鸭子队长 9012 / 白狼 9031。
# 口径（已与用户确认）：候选**只从 state.deck（抽牌堆）**里选，与 `_fetch_skill_card` 同口径；
# 选中的卡**原位替换**，不抽到手上、不改变洗牌序列（同一种子重跑必然一致）。
const OVERLOAD_ID:= 8030
const OVERLOAD_TRAIT:= "过载"
const DOUBLE_ACTION:= 2          # 「一回合行动两次」的 actions 值（= 卡面自带双动的口径）
# 「集体改造」（8031，1 费技能，机械之心，R86）：手牌里**所有盟友和工事**生命 +1，
# **整场战斗内有效**（回合结束弃回牌库、再抽到仍带）。改的是**手牌里的副本** ——
# `build_deck` 给的是卡库共享实例，不复制就会跨 run 泄漏。
const BATCH_UPGRADE_ID:= 8031
## R394（用户口径）：改名「集体改造」，范围从「手牌」扩到「手牌 + 卡组」，每张 +1 → **+3**。
const BATCH_UPGRADE_HP:= 3
# 「侦察塔」（8032，工事，机械之心，R86）：R276 起 **2 费 / 0 攻 / 8 血 / 攻程 2**。
#   * **0 攻也能攻击** —— 用户口径「只有 0 攻程不能攻击」；引擎的 `attack_targets`
#     本来就只看 `attack_range` 不看 `power`，所以无需改引擎。
#   * 「每层改造使攻击范围内的敌人受到伤害 +1」→ 伤害 = 改造的 +2 力量 **+ 层数**
#     （`Placement.upgrade_stacks`，由 `_upgrade_unit` 每次 +1）。
#   * 只有**带 trait「改造层数」**的卡才吃到层数加成（见 Placement.effective_power）——
#     否则 0 攻工事改造几次就能自己打人。
## R276：随心组装 9144「变化出的盟友卡本回合费用 -1」。
const ASSEMBLE_ALLY_DISCOUNT:= 1
const SCOUT_TOWER_ID:= 8032
const STACK_DAMAGE_TRAIT:= "改造层数"
# 「堡垒」（8034，3 费工事，机械之心，R87）：3 攻 / 10 血 / 攻程 1，
# **每层改造 +STACK_HP_PER 生命**（trait「改造生命层」，与侦察塔的「改造层数」是两套）。
const FORT_ID:= 8034
const STACK_HP_TRAIT:= "改造生命层"
const STACK_HP_PER:= 3
# 「能量屏障」（8033，2 费技能，机械之心，R87）：从**抽牌堆**随机一张**还没有能量屏障**的
# 盟友 / 工事，给它加上这个 trait → 上场时 `Placement.first_hit_shield = true`，
# **本场战斗中第一次受到的伤害完全免掉**（一次性，用完消失）。
# 「没有此能力」的判据 = 卡上没这个 trait（与「过载」判 actions 同套路）。
const BARRIER_ID:= 8033
const BARRIER_TRAIT:= "能量屏障"
## R276：能量屏障 8033 额外「抽 3 张卡」。
const BARRIER_DRAW:= 3
# 「自我修复」（8035，1 费技能，机械之心，R87）：改造**场上的一个己方盟友** →
# +2 最大生命（并进 upgrade_hp，离场还原）+ 每回合结束回 SELF_REPAIR_REGEN 生命
# （记在 `Placement.regen`，同样只在场上有效）。
const SELF_REPAIR_ID:= 8035
const SELF_REPAIR_HP:= 2
const SELF_REPAIR_REGEN:= 4
const REGEN_TRAIT:= "自愈"
# ⚠️ 命名注意：**别叫 GOLEM_ID** —— 那个名字已被魔像 9080 占用（同文件 9080 那组）。
const MECH_CORE_RELIC_ID:= 6025
const MECH_CORE_PROTO:= 2

# 栅栏修复术（6021）：【栅栏】类卡（木栅栏 8001 / 铁栅栏 9072，带 FENCE_TRAIT）
# 可以打在「已有栅栏的格子」上 → 两张合并成一张，生命值与特性叠加。
const FENCE_TRAIT:= "栅栏"
const FENCE_REPAIR_RELIC_ID:= 6021

# 鸭子骑士（9001）：每击杀一个敌方单位 → 攻击力 +2（永久累计，无上限）
const KNIGHT_TRAIT:= "骑士"
const KNIGHT_KILL_BUFF:= 2
# 关卡成长曲线（二层「低开高走」）：开局削攻击力、之后随回合回升。见 configure_growth()。

# ── R63（2026-10-04）：契约签订者 8024 / 恶魔鸭 9116 / 恶魔使魔 9117 ──
# 契约签订者（8024 盟友 3 费 2/8）：登场时**回复 4 点费用**（state.energy 直接加），
#   同时**本回合**手卡里所有卡费用 +CONTRACTOR_RAISE（涨价，靠 state.turn_card_raise）。
#   注意这是「涨价」不是减费：净效果 = 花 3 费换回 4 费（本回合白赚 1 费），
#   但手里其余牌本回合都贵 4 点 —— 用它换「一张 2/8 白嫖 + 手里牌全变贵」。
const CONTRACTOR_ID:= 8024
const CONTRACTOR_TRAIT:= "契约签订者"
const CONTRACTOR_GAIN:= 4          # 登场回复的费用
const CONTRACTOR_RAISE:= 4         # 本回合手卡涨价
# 恶魔鸭（9116 敌方盟友 5/100 程2 速1）：
#   ① 开场即「沉睡」SLEEP_TURNS(2) —— Placement.sleep_left > 0 时不能行动。
#      递减有**两个口**，减到 0 都**立刻**能行动：
#        · 回合口 = end_turn 里的 _sleep_tick（**自己**的回合结束 -1，R122 用户口径）；
#        · 受伤口 = _hit_unit 里的 _demon_duck_hurt（每次受伤 -1，R76 用户口径）。
#      两个口并存：既保证「没人打它也一定会醒」，又保留「打它 = 帮它提前醒」的决策。
#   ② 已醒之后再受伤 → end_atk +1（永久加攻，进 effective_power）。
const DEMON_DUCK_ID:= 9116
const DEMON_DUCK_ATK_GAIN:= 1      # 醒着受伤时永久 +1 力量
# 恶魔鸭（复仇）（9118 敌方盟友 5/100 程2 速1，R73）：
#   彩蛋 Boss「恶魔鸭（复仇）」= 第一层摇到恶魔鸭时 50% 触发，**第二层的 boss 换成它**。
#   ① **没有「沉睡」trait** → 上场即可行动（FieldState.place 只对带 SLEEP_TRAIT 的卡置 sleep_left）；
#   ② 带「复仇」trait → 每次受到伤害，本回合力量 +1（**可叠加**，走 atk_buff_turn，
#      回合开始由 end_turn 的清零分支自然清掉，不另写清除逻辑）。
#   与 9116 的关键差异：加攻是**本回合临时且可叠加**（越打越疼，但只疼这一回合），
#   而 9116 是**永久 +1**。所以 9118 逼玩家「一回合内打完」，9116 逼玩家「尽早打」。
const DEMON_REVENGE_ID:= 9118
const REVENGE_TRAIT:= "复仇"
const REVENGE_ATK_PER_HIT:= 1      # 每次受伤本回合 +1 力量（可叠加）
const REVENGE_END_ATK_PER_HIT:= 1  # R77：同时保留恶魔鸭（9116）原本的「受伤力量 +1（永久）」
# 恶魔使魔（9117 敌方关卡效果卡）：
#   ① 复用「使魔成长」trait → 所有使魔鸭子力量 +1（永久，与 9115 同一条 _turn_growth 通路）；
#      **成长仍是每回合**。
#   ② 「恶魔召唤」trait → **每 DEMON_SUMMON_EVERY 回合**在**随机空格**召唤一只使魔鸭子；
#      **玩家后排除外**（不能落我方后排）。R70 起由「每回合」改为「每 2 回合」。
const DEMON_SUMMON_TRAIT:= "恶魔召唤"
const DEMON_SUMMON_EVERY:= 2       # 召唤间隔（回合）：turn_number % 2 == 0 时召唤

# ---- R111：鸭子暗杀者 / 鸭之暗面 / 暗影召唤 ----
# 鸭子暗杀者 9123（trait「暗杀」）：只要**己方场上还有「暗杀」以外的单位**，就进入特殊模式 ——
#   ① **不能攻击对方 HP**（`hp_targets` 直接返回空 → UI 与 AI 同时被拦）；
#   ② 可以**改用一次行动闪现**到战场上任意空格（`move(..., blink=true)`，不看移速、不看阻挡）。
#   只剩它自己（或只剩暗杀者）时被动关闭 → 变回普通 6/30 单位，能正常打 HP。
# 鸭之暗面 9124（trait「暗影领主」+「穿行」）：
#   * 穿行 = 移动可**穿过**任何单位（不能停在上面）；
#   * 暗影领主 = **每个存活的鸭子暗杀者**给它 +3 力 +1 速（记在 Placement，见 `_refresh_dark_lord`）。
# 暗影召唤 9125（trait「暗杀召唤」，value = 间隔回合数）：开局 + 每 N 回合召唤一只鸭子暗杀者。
const ASSASSIN_TRAIT:= "暗杀"
const ASSASSIN_ID:= 9123
const SHADOW_LORD_TRAIT:= "暗影领主"
const DARK_LORD_ATK_PER_ASSASSIN:= 3    # 每个存活暗杀者 +3 力
const DARK_LORD_SPEED_PER_ASSASSIN:= 1  # 每个存活暗杀者 +1 速
const PHASE_TRAIT:= "穿行"              # 移动无视单位阻挡
const ASSASSIN_SUMMON_TRAIT:= "暗杀召唤"

# ---- R327：送葬（9175，森林精魄 2 费稀有·效果）----
# 「场上每有一个单位被破坏，抽 1 张卡。」挂在己方效果区，在**全局唯一破坏口**
# `_destroy` 尾部结算（所以亡语、溢出、超负荷真死、思想钢印救回都算）。
#   * 任何一方的单位都算 —— 卡面写的是「场上」，不限定敌我。
#   * 效果区**多张不叠加**（沿用效果区惯例：卡面没写「可叠加」就只算一张）。
#   * 「思想钢印」救回手卡的那张**也算被破坏**（与嵌合暴君回费同口径）。
const FUNERAL_ID:= 9175
const FUNERAL_TRAIT:= "送葬"
const FUNERAL_DRAW:= 1            # 每破坏 1 个单位抽几张


func _init(state_: FieldState) -> void :
	state = state_


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func back_row(side: String) -> int:
	return 0 if side == SIDE_OPPONENT else FieldState.BOARD_ROWS - 1


static func forbidden_row_for(side: String) -> int:

	return back_row(SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF)


static func unit_slot_allowed(cell: Vector2i, side: String) -> bool:
	## **单位能不能存在于这一格**（R285，唯一判据）。
	##
	## 规则只有一条：越界 / **对方后排（HP 行）** 一律不行 —— 那一行是「直击 HP」的
	## 目标行，自己人站上去等于把对方血条当落脚点（用户实测：我方单位被卡牌效果
	## 挪到了敌方后排队列上，且界面高亮 / 引擎判定各说各话，谁也拦不住）。
	##
	## 为什么收敛成唯一口：落点判定原来散在五处（move / blink / 潜入 / 召唤 _can_hold /
	## 手牌放置只在界面拦），每加一张位移卡就要再记一次，漏一处就漏一条路。
	## 战场其余格子（敌方前排 / 中场）**照旧允许** —— 移动、潜入、换位的玩法意义
	## 本来就是越过中线去敌方半场做事，只有后排这一行是硬禁区。
	if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS:
		return false
	if cell.y < 0 or cell.y >= FieldState.BOARD_COLS:
		return false
	return cell.x != forbidden_row_for(side)


static func hand_place_allowed(cell: Vector2i, side: String) -> bool:
	## **手牌单位（盟友/工事）能不能放在这一格**（R286，唯一判据）。
	##
	## 规则：**只能放自己半场**（下 3 行；敌方对称 = 上 3 行）。R285 曾把手牌放置
	## 与界面高亮一起放宽成「除对方后排全图」，木栅栏拖出去连敌方前排都是绿的 ——
	## 「越过中线做事」是**场上位移效果**（移动 / 闪现 / 潜入 / 换位）的玩法，
	## 不是从手里拍牌的玩法；出手放置回归「自己半场」的口径。两条判据并存：
	##   * `hand_place_allowed` —— 从手牌上场（play_from_hand / remote_play / 界面高亮）；
	##   * `unit_slot_allowed` —— 场上单位的落点（move / 闪现 / 潜入 / 召唤 / 换位）。
	if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS:
		return false
	if cell.y < 0 or cell.y >= FieldState.BOARD_COLS:
		return false
	if side == SIDE_OPPONENT:
		return cell.x < FieldState.OPPONENT_ROWS
	return cell.x >= FieldState.OPPONENT_ROWS


static func hp_row_owner(row: int) -> String:


	if row == back_row(SIDE_OPPONENT):
		return SIDE_OPPONENT
	if row == back_row(SIDE_SELF):
		return SIDE_SELF
	return ""


func start_game(starting_hand:= 0, opponent_deck:= 50, i_start:= true) -> void :
	wish_pending = false
	_steel_stamp_used = false   # R307：思想钢印每场战斗一次
	_first_kill_growth_done.clear()   # R393：击杀成长每场战斗各卡一次
	_thorn_ring_turn = -1
	state.starting_hand(starting_hand)
	state.energy = FieldState.ENERGY_PER_TURN
	state.opp_energy = FieldState.ENERGY_PER_TURN
	state.opp_hand_count = starting_hand
	state.opp_deck_count = maxi(0, opponent_deck - starting_hand)
	_check_game_over()
	if not over:
		_begin_turn(SIDE_SELF if i_start else SIDE_OPPONENT)


func _log(text: String) -> void :
	log.append(text)


func _check_game_over() -> bool:
	## R356：`enemy_hp_infinite` → 「敌方 HP 归零」这条胜利条件整条失效（打不空），
	## 胜负改由「击破指定 Boss」（`win_on_boss`）与「我方 HP 归零」两条决定。
	if over:
		return true
	if not enemy_hp_infinite and state.hp_opponent <= 0:
		_finish("胜利", "敌方 HP 归零")
		return true
	if state.hp_self <= 0:
		if _try_revive():
			return false
		_finish("失败", "我方 HP 归零")
		return true
	# R356：击破启示者即通关。**排在「清场」之前** —— 三阶段打完场上还剩一堆量产型，
	# 用清场判等于要求玩家把它们也扫干净，那不是这张关卡的题面。
	if win_on_boss > 0 and _cell_of_unit(win_on_boss) == Vector2i(-1, -1):
		_finish("胜利", "击破启示者")
		return true
	if state.clear_win and _side_cells(SIDE_OPPONENT).is_empty():
		_finish("胜利", "敌方场上单位全灭")
		return true
	return false


func _try_revive() -> bool:



	if not self_relics.has(6013) or duck_revive_chance <= 0:
		return false
	var roll:= rng.randi_range(1, 100)
	if roll > duck_revive_chance:
		_log("叠加态的鸭：复活判定失败（%d%%，掷出 %d）" % [duck_revive_chance, roll])
		return false
	var before:= duck_revive_chance
	duck_revive_chance = maxi(0, before - DUCK_REVIVE_STEP)
	state.hp_self = 1
	_log("叠加态的鸭：复活！回复 1 点生命（%d/%d）；复活概率 %d%% → %d%%" % [
		state.hp_self, state.max_hp_self, before, duck_revive_chance])
	action.emit("revive", {"hp": state.hp_self, "chance": duck_revive_chance, 
		"before": before})
	return true


func _side_cells(side: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		if (state.board[cell] as Placement).owner == side:
			out.append(cell)
	return out


func _side_upgrade_stacks(side: String) -> int:
	## **场上**该方所有单位（盟友 / 工事 / 随从）的改造层数合计。
	## 唯一消费方 = 集中突破 9162（每层 +4 伤害）。
	## ⚠️ 只数 `Placement.upgrade_stacks`：手牌 / 牌库里攒的层数**不算** ——
	##   卡面写的是「场上的己方单位」，与侦察塔 / 堡垒读「随身层数」是两套口径。
	var total := 0
	for c: Vector2i in state.board:
		var p: Placement = state.board[c]
		if p == null or p.owner != side:
			continue
		total += maxi(0, p.upgrade_stacks)
	return total


func _finish(res: String, reason: String) -> void :
	over = true
	result = res
	result_reason = reason
	_log("── 对局结束：%s（%s）" % [res, reason])


func _begin_turn(side: String) -> void :
	if over:
		return
	current_side = side
	turn_total += 1   # 全局半回合计数（双方回合各 +1）
	if side == SIDE_SELF:
		turn_number += 1
		state.self_turn_no = turn_number   # 哈气前置判定用
		_unit_played_this_turn = false
		turn_dmg_bonus = 0
		state.self_cost_reduction = 0
		state.self_ally_cost_reduction = 0
		state.self_next_ally_reduction = 0
		# 小精灵（9074）的「下一张效果卡 -2」**跨回合保留**：只有用掉那张效果卡时才清零，
		# 所以这里不动 state.self_next_effect_reduction。
		state.self_effect_plays = 0
		state.self_skill_plays = 0
		state.self_card_plays = 0
		state.self_energy_spent = 0   # 暗影之刃 9111：X = 本回合已花掉的费用，每回合重新记
		_aether_used = false
		_aether_left = 0
		_dodge_active = false   # 闪躲（9103）：含敌方回合在内的一整个来回结束 → 到期
		_roar_fires = 0
		_space_fires = 0
		_sync_harp()   # R352 竖琴：战斗中拿到的道具 / 读档续战，此处补齐在场上盟友的 +2
		_sync_knight_sword()   # R383 骑士剑：同一处补齐（含中途拿到道具的情况）
		state.energy = FieldState.ENERGY_PER_TURN
		if state.turn_limit >= 0 and turn_number > state.turn_limit:
			turn_number = state.turn_limit
			_finish("失败", "%d 回合内未击破敌方 HP" % state.turn_limit)
			return

		_spring_tick()          # R307 泉水：后排单位每回合回 4
		_tick_enemy_growth()
		# R341 鹿首标本（6049）：**每个我方回合开始** +1 层（本场永久累计）。
		# ⚠️ 第一个我方回合也 +1 —— 卡面写的是「每回合开始时」，开局那一回合同样算。
		if self_relics.has(DEER_TROPHY_RELIC_ID):
			deer_bonus += 1
			_log("鹿首标本：技能与陷阱 / 场地伤害 +%d（本场累计）" % deer_bonus)
		# R314 lucky 7（6045）：**每个我方回合开始**推一格跨战斗计数；满 7 的倍数 → 本轮回生效。
		# ⚠️ 复位放在这里（而不是回合结束）：置位后要覆盖「我方回合 + 紧接着的敌方回合」，
		#    下个我方回合开始时才清 —— 敌方回合才是真正会掉血的时段。
		_lucky7_active = false
		# R315 爆米花（6046）：新回合开始 → 「本回合还没指向敌人」。
		_popcorn_quiet = true
		if self_relics.has(LUCKY7_RELIC_ID) and RunState.lucky7_tick():
			_lucky7_active = true
			_log("lucky 7：第 %d 个回合生效 —— 本回合免疫所有 HP 伤害，技能额外 +%d"
					% [RunState.lucky7_turns, LUCKY7_DMG])
			action.emit("lucky7", {"turns": RunState.lucky7_turns, "dmg": LUCKY7_DMG})
		var extra_draw:= 0
		if self_relics.has(6005) and turn_number <= 2:
			extra_draw = 1
			_log("鸭蹼：第 %d 回合开始，额外抽 1 张" % turn_number)

		var bonus_energy:= 0
		if self_relics.has(DUCK_WING_RELIC_ID) and turn_number == DUCK_WING_TURN:
			bonus_energy = DUCK_WING_ENERGY
			state.energy += bonus_energy
			_log("鸭翼：第 %d 回合获得 %d 点额外费用" % [DUCK_WING_TURN, DUCK_WING_ENERGY])

		var earring_energy:= 0
		if self_relics.has(EARRING_RELIC_ID):
			earring_energy = 1
			state.energy += earring_energy
			_log("鸭语耳环：本回合费用 +1")

		# 活力转移（9110，R55）：上回合剩余费用换来的额外费用，**只在本回合发放一次**。
		var transfer_energy := state.self_next_energy
		if transfer_energy > 0:
			state.energy += transfer_energy
			state.self_next_energy = 0
			_log("活力转移：上回合结转，费用 +%d" % transfer_energy)
			action.emit("vitality", {"energy": transfer_energy, "side": SIDE_SELF})

		var ice_energy:= 0
		if self_relics.has(ICECREAM_RELIC_ID) and turn_number == 1:
			ice_energy = ICECREAM_ENERGY
			state.energy += ice_energy
			extra_draw += ICECREAM_DRAW
			_log("冰淇淋与汽水：第 1 回合额外 +%d 费用、多抽 %d 张"
				%[ICECREAM_ENERGY, ICECREAM_DRAW])
			action.emit("icecream", {"text": ICECREAM_LINE, 
				"energy": ICECREAM_ENERGY, "draw": ICECREAM_DRAW})


		# 勇气徽章（6031，R245 / R372）：精英战与 Boss 战**都只在首回合**额外 +1 费用。
		# 「哪一场算精英 / Boss」由 battle_scene 写入 `battle_kind`，引擎只看这个字段。
		if self_relics.has(COURAGE_RELIC_ID):
			var brave_span:= 0
			if battle_kind == "elite" or battle_kind == "boss":
				brave_span = COURAGE_TURNS
			if brave_span > 0 and turn_number <= brave_span:
				state.energy += 1
				_log("勇气徽章：%s首回合，费用 +1"
						% ("精英战" if battle_kind == "elite" else "Boss 战"))

		# 兼修（6033，R246）：我方每回合额外 +1 费用（不分战斗类型）。
		if self_relics.has(VERSATILE_RELIC_ID):
			state.energy += 1
			_log("兼修：本回合费用 +1")
		# 水晶骰子（6040，R311）：前 X 回合每回合 +1 费（X = 开场掷出的点数）。
		# ⚠️ 判据只看 `dice_energy_turns`（开局已按「持有道具 + ? 房」定好），
		#    这里不再复查道具 —— 中途丢掉道具不该让「已经骰出来的回合数」消失。
		if dice_energy_turns > 0 and turn_number <= dice_energy_turns:
			state.energy += DICE_ENERGY
			_log("水晶骰子：第 %d/%d 回合，费用 +%d"
					% [turn_number, dice_energy_turns, DICE_ENERGY])

		var whisper_txt:= ""
		if self_relics.has(6010):
			match rng.randi_range(0, 2):
				0:
					state.energy += 1
					whisper_txt = "本回合费用 +1"
				1:
					turn_dmg_bonus = 1
					whisper_txt = "本回合造成的伤害 +1"
				_:
					extra_draw += 1
					whisper_txt = "本回合多抽 1 张卡"
			_log("鸭之低语：%s" % whisper_txt)
			action.emit("whisper", {"text": whisper_txt})
		# R315 爆米花：上回合攒下的「没用技能打敌人」奖励 → 本回合多抽（只发一次）。
		if popcorn_draw > 0:
			extra_draw += popcorn_draw
			var pc_draw := popcorn_draw
			popcorn_draw = 0
			_log("爆米花：上回合没用技能指向敌人 → 本回合多抽 %d 张" % pc_draw)
			action.emit("popcorn", {"draw": pc_draw, "side": SIDE_SELF})
		# 负重减轻（8066，R201）：上回合「选卡消失」换来的额外抽牌，**只在本回合发放一次**
		if state.self_next_draw > 0:
			extra_draw += state.self_next_draw
			var lighten_draw := state.self_next_draw
			state.self_next_draw = 0
			_log("负重减轻：本回合多抽 %d 张卡" % lighten_draw)
			action.emit("lighten_draw", {"draw": lighten_draw, "side": SIDE_SELF})
		if turn_number == 1:
			_ensure_opening_card(ALERT_ID)   # 警觉（9109）：第 1 回合必定抽到
			_ensure_opening_enchanted()      # R229「起手」附魔：同样第 1 回合必定抽到
		var drawn := _draw_many(FieldState.HAND_DRAW_PER_TURN + extra_draw)
		var earring_autoplayed := 0
		if self_relics.has(EARRING_RELIC_ID) and turn_number == 1:
			# R285：第 1 回合**正常抽牌之后**，再开始自动出牌。
			# 自动出牌从左到右扫描手牌，跳过无法打出的牌，循环直到打不出或达到上限。
			if autoplay_stepwise:
				begin_earring_autoplay()
			else:
				earring_autoplayed = _autoplay_from_deck()
				_log("鸭语耳环：第 1 回合自动出牌 %d 张" % earring_autoplayed)
		# 无尽黑暗 9114（R70 改）：抽牌之后**开选牌面板**，玩家选 1 张手牌弃掉
		# → 之后才给 2 点费用（费用在 endless_pick 里加，不在这里）。
		# 放在抽牌分支**之后**，这样「鸭语耳环自动出牌」那条分支也会照常触发。
		if _zone_has(state.effects, ENDLESS_DARK_TRAIT):
			_endless_dark(SIDE_SELF)
		_melt_ice_walls(SIDE_SELF)
		_clear_fire_walls(SIDE_SELF)
		_wisdom_surge()
		_endless_blessing()
		_action_growth_tick(SIDE_SELF)   # R161：先推进成长计数，再刷新 acts_left
		state.reset_units(SIDE_SELF)
		_poison_tick(SIDE_SELF)   # 剧毒陷阱：我方回合开始结算中毒
		_arm_debuffs(SIDE_SELF)
		# ── ① 回合开始的**成长**先结算 ──
		_apply_growth(SIDE_SELF)
		_night_growth(SIDE_SELF)
		_mage_growth(SIDE_SELF)
		_familiar_growth(SIDE_SELF)   # 使魔之力 9115：回合开始使魔鸭子 +1
		_apply_mech_growth(SIDE_SELF)
		_asclepius_armor_tick(SIDE_SELF)   # R162：护甲积攒结算
		# ── ② R122：**召唤**排在成长之后 ──
		# 「回合开始成长」算的是**这一刻已在场**的单位；刚召唤出来的单位这一回合才上场，
		# 成长结算时它还不存在 → 它不该吃到本回合的这一口（用户：召唤的使魔
		# 「享受了效果卡的加攻」）。放在成长之后，它从**下一回合**起才加入成长。
		_summon_familiars(SIDE_SELF)
		_effect_summons(SIDE_SELF)
		_assembly_tick(SIDE_SELF)     # 流水线装配 9147（R219，对称保留）
		_emergency_call()             # R356 紧急呼叫 9203：**玩家**回合开始 → 启示者身边召唤量产型
		_demon_summon(SIDE_SELF)      # 恶魔使魔 9117：每 2 回合随机空格召唤使魔鸭子
		_auto_upgrade(SIDE_SELF)          # 自主升级 8045（R95）：回合开始随机改造抽牌堆 1 张
		_breach_tick(SIDE_SELF)           # R231 破绽：己方俄倪厄往对方卡组塞诅咒（对称保留）
		_dragon_breath(SIDE_SELF)
		_heal_aura(SIDE_SELF)
		_kiln_hatch(SIDE_SELF)
		_workshop_supply(SIDE_SELF)   # 机关工坊（R74 改名）：我方回合开始随机工事进手
		_clockwork_summon(SIDE_SELF)
		_latent_turn_draw(SIDE_SELF)
		_shadow_split_draw(SIDE_SELF)   # 分裂之影 8067（R217）
		_glowgrass_supply(SIDE_SELF)
		_rebirth_tick(SIDE_SELF)          # 新生 9148（R222）：抽牌之后，选一张手卡消失
		_creation_tick(SIDE_SELF)         # 创意 8070（R271）：抽牌之后，选一张手卡随机变形
		_surprise_tick(SIDE_SELF)         # 惊喜运单 8079（R331）：抽牌之后，选一张卡组卡变形
		_ghost_self_destruct(SIDE_SELF)
		_assassin_summon(SIDE_SELF)
		_refresh_dark_lord(SIDE_SELF)
		_refresh_hecaton(SIDE_SELF)
		_refresh_mnemosyne()           # R271 谟涅摩叙涅：按改造层数重算敌方力量减益
		_refresh_night_owl()           # R270 夜鸭：按本回合奇偶刷新「惧光」
		_run_battlecries(SIDE_SELF)
		_log("── 我方第 %d 回合：费用重置为 %d%s%s%s%s%s%s%s（共 %d），抽 %d 张" % [
			turn_number, FieldState.ENERGY_PER_TURN,
			"（+%d 鸭翼）" % bonus_energy if bonus_energy > 0 else "",
			"（+%d 鸭语耳环）" % earring_energy if earring_energy > 0 else "",
			"（+%d 冰淇淋）" % ice_energy if ice_energy > 0 else "",
			"（+%d 活力转移）" % transfer_energy if transfer_energy > 0 else "",
			"（无尽黑暗：待选弃牌）" if endless_pending else "",
			"（鸭之低语：%s）" % whisper_txt if whisper_txt != "" else "",
			"，耳环自动出 %d 张" % earring_autoplayed if earring_autoplayed > 0 else "",
			state.energy, drawn])
	else:
		opp_turns += 1
		state.opp_turn_no = opp_turns       # 哈气前置判定用
		state.opp_card_plays = 0
		state.opp_energy_spent = 0   # 暗影之刃 9111：对称保留
		state.opp_energy = FieldState.ENERGY_PER_TURN
		# 活力转移（9110，R55）：对称保留（敌方正常拿不到这张卡）
		var opp_transfer := state.opp_next_energy
		if opp_transfer > 0:
			state.opp_energy += opp_transfer
			state.opp_next_energy = 0
			_log("活力转移（对方）：费用 +%d" % opp_transfer)
			action.emit("vitality", {"energy": opp_transfer, "side": SIDE_OPPONENT})
		state.opp_draw(FieldState.HAND_DRAW_PER_TURN)
		state.opp_deck_count = maxi(0, state.opp_deck_count - FieldState.HAND_DRAW_PER_TURN)
		# 无尽黑暗 9114：对称保留（敌方没有真实手牌 → 只结算费用那半边）
		if _zone_has(state.enemy_effects, ENDLESS_DARK_TRAIT):
			_endless_dark(SIDE_OPPONENT)
		_melt_ice_walls(SIDE_OPPONENT)
		_clear_fire_walls(SIDE_OPPONENT)
		_action_growth_tick(SIDE_OPPONENT)   # R161：先推进成长计数，再刷新 acts_left
		state.reset_units(SIDE_OPPONENT)
		_poison_tick(SIDE_OPPONENT)   # 剧毒陷阱：对方回合开始结算中毒
		_arm_debuffs(SIDE_OPPONENT)
		# ── ① 成长先结算 ──
		_apply_growth(SIDE_OPPONENT)
		_night_growth(SIDE_OPPONENT)
		_mage_growth(SIDE_OPPONENT)
		_familiar_growth(SIDE_OPPONENT)   # 使魔之力 9115：回合开始使魔鸭子 +1
		_apply_mech_growth(SIDE_OPPONENT)
		_asclepius_armor_tick(SIDE_OPPONENT)   # R162：护甲积攒结算
		# ── ② R122：召唤排在成长之后（同我方）──
		_summon_familiars(SIDE_OPPONENT)
		_effect_summons(SIDE_OPPONENT)
		_assembly_tick(SIDE_OPPONENT)   # 流水线装配 9147（R219）
		_demon_summon(SIDE_OPPONENT)   # 恶魔使魔 9117：回合开始随机空格召唤使魔鸭子
		_auto_upgrade(SIDE_OPPONENT)      # 对称保留（敌方正常拿不到这张卡）
		_scavenger_tick(SIDE_OPPONENT)    # R228 拾荒者 9151：回合开始改造一个友方单位
		_breach_tick(SIDE_OPPONENT)        # R231 破绽：俄倪厄 9132 / 量产型 9131 往我方卡组塞诅咒
		_dragon_breath(SIDE_OPPONENT)
		_heal_aura(SIDE_OPPONENT)
		_kiln_hatch(SIDE_OPPONENT)
		_workshop_supply(SIDE_OPPONENT)   # 陷阱工坊（对称保留；敌方正常拿不到该卡）
		_clockwork_summon(SIDE_OPPONENT)
		_latent_turn_draw(SIDE_OPPONENT)
		_shadow_split_draw(SIDE_OPPONENT)   # 分裂之影 8067（R217，对称保留）
		_glowgrass_supply(SIDE_OPPONENT)
		_rebirth_tick(SIDE_OPPONENT)      # 新生 9148（R222，对称保留：敌方无真实手牌）
		_ghost_self_destruct(SIDE_OPPONENT)
		_assassin_summon(SIDE_OPPONENT)
		_cannon_fire(SIDE_OPPONENT)   # R158 充能巨炮 9139：己方回合开始随机破坏一个我方单位
		_naval_gun(SIDE_OPPONENT)     # R356 舰炮 9201：阶段 1，每回合随机轰击一列
		_revelator_phase_tick(SIDE_OPPONENT)   # R356 阶段 1「自身效果」：每个回合力量 +1
		_refresh_dark_lord(SIDE_OPPONENT)
		_refresh_hecaton(SIDE_OPPONENT)
		_refresh_mnemosyne()           # R271 谟涅摩叙涅：对称保留（敌方正常拿不到）
		_refresh_night_owl()           # R270 夜鸭：奇数回合「惧光」（与上一行同回合内一致）
		_run_battlecries(SIDE_OPPONENT)
		_log("── 对手回合开始：费用 %d（上回合结束已清零，本回合重新发放基础费用），手牌 +%d" % [
			FieldState.ENERGY_PER_TURN, FieldState.HAND_DRAW_PER_TURN])


func enable_enemy_effects(cards: Array[CardData]) -> void :
	for c in cards:
		state.enemy_effects.append(c)
	if state.enemy_effects.is_empty():
		return
	var names: Array[String] = []
	for c: CardData in state.enemy_effects:
		names.append(c.card_name)
	_log("对方开局启用效果卡：%s（持续生效中）" % "、".join(names))


	state.apply_extra_actions(SIDE_OPPONENT)
	# R111 暗影召唤：「战斗开始时」那一半的召唤（另一半点在敌方回合开始里）。
	_assassin_summon(SIDE_OPPONENT, true)
	_refresh_dark_lord(SIDE_OPPONENT)
	_refresh_hecaton(SIDE_OPPONENT)
	_refresh_mnemosyne()               # R271 谟涅摩叙涅：开局先算一次
	_refresh_night_owl()               # R270 夜鸭：开局先按当前回合数定一次


func _spring_tick() -> void:
	## 泉水（6035，R307）：我方**后排**（最后一行）的单位每回合开始回复 4 点生命。
	## ⚠️ 上限 = `p.card.health`（与「自我修复 / 回血」同一个口径，含改造加的血）。
	if not self_relics.has(SPRING_RELIC_ID):
		return
	var back_row: int = FieldState.BOARD_ROWS - 1
	for col in FieldState.BOARD_COLS:
		var p: Placement = state.unit_at(Vector2i(back_row, col))
		if p == null or p.owner != SIDE_SELF:
			continue
		if p.health >= p.card.health:
			continue
		var before: int = p.health
		p.health = mini(p.card.health, p.health + SPRING_HEAL)
		_log("泉水：%s 回复 %d 点生命（%d → %d）" % [p.card.card_name,
				p.health - before, before, p.health])
		action.emit("self_heal", {"healed": p.health - before, "hp": state.hp_self})
	_check_game_over()


func _apply_growth(side: String) -> void :


	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var inc:= 0
	for c: CardData in zone:
		if c.traits.has("成长"):
			inc = maxi(inc, c.value)
	if inc <= 0:
		return
	var boosted:= 0
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == side and p.atk_buff < GROW_CAP:
			p.atk_buff = mini(p.atk_buff + inc, GROW_CAP)
			boosted += 1
	if boosted > 0:
		_log("%s光环：%d 个友方力量 +%d（战场最高累计 +%d）" % [
			_zone_label(side), boosted, inc, _max_buff(side)])


func _apply_mech_growth(side: String) -> void :


	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var inc:= 0
	var src:= "机械成长"
	for c: CardData in zone:
		if c.traits.has(MECH_GROW_TRAIT) and c.value > inc:
			inc = c.value
			src = c.card_name
	if inc <= 0:
		return
	var boosted:= 0
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == side:
			p.atk_buff += inc
			boosted += 1
	if boosted > 0:
		_log("%s：%d 个友方力量 +%d（永久，无上限）" % [src, boosted, inc])


func _familiar_growth(side: String) -> void :
	## 使魔之力（9115，R60）：**效果区**里有「使魔成长」时，回合开始使本方
	## 带「使魔」trait 的单位力量 +c.value（永久累计，无上限）。
	## 与 _apply_mech_growth 的差别：只给「使魔」，且走效果区（新卡不叠加，
	## 取value 最大的一张）而不是给全部友方。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var inc:= 0
	var src:= "使魔成长"
	for c: CardData in zone:
		if c.traits.has(FAMILIAR_GROW_TRAIT) and c.value > inc:
			inc = c.value
			src = c.card_name
	if inc <= 0:
		return
	# 复用「回合开始永久成长」唯一入口，按「使魔」trait 过滤
	var boosted:= _turn_growth(side, FAMILIAR_TRAIT, "familiar_grow", inc, false)
	if boosted > 0:
		_log("%s：%d 个使魔力量 +%d（永久，无上限）" % [src, boosted, inc])


func _demon_summon(side: String) -> void :
	## 恶魔使魔（9117，R63 / R70 改）第二条：效果区里有「恶魔召唤」trait 时，
	## **每 DEMON_SUMMON_EVERY 回合**（R70 起 2 回合）在一个**随机空格**上召唤一只使魔鸭子。
	##空格范围 = 整块战场（6 行 × 3 列）里没被占的格子，**排除对方后排行**
	##（=玩家后排除我方后排）—— 与单位移动的禁区同一条规则（forbidden_row_for）。
	## 随机走引擎 rng → 回放同种子可复现；效果区多张不叠加（只召唤一只）。
	## **回合计数口径**：**双方各自数自己的回合**（我方 turn_number / 敌方 opp_turns）——
	## ① 不能用 turn_total（双方各 +1 一起数）：那样「每 2 回合」实际只隔 1 个我方回合；
	## ② **两侧都要判**（别只判 SIDE_SELF）：这张卡是**敌方**关卡效果，走
	##    enemy_effects → `_demon_summon(SIDE_OPPONENT)`，只判我方等于改动完全没生效。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	if not _zone_has(zone, DEMON_SUMMON_TRAIT):
		return
	var side_turn: int = turn_number if side == SIDE_SELF else opp_turns
	if side_turn % DEMON_SUMMON_EVERY != 0:
		return   # 不是召唤回合（成长照常，见 _familiar_growth）
	var spot:= _random_free_board_cell(side)
	if spot == Vector2i(-1, -1):
		_log("恶魔使魔：场上没有可用空格（已排除对方后排），本回合未召唤")
		return
	var repo:= CardRepo.load_json()
	var card: CardData = repo.get_card(FAMILIAR_DUCK_ID)
	if card == null:
		card = _fallback_familiar()
	# 召唤物用独立副本：避免与库内实例共享（后续谁给它挂减费/状态不会串到别处）
	var copy:= CardData.from_dict(card.to_dict())
	var summoned:= state.place(copy, spot, side, true)
	_log("恶魔使魔：召唤了一只使魔鸭子（%s）" % spot)
	action.emit("demon_summon", {"cell": spot, "card": copy, "side": side})
	_on_ally_entered(summoned, side)


func _random_free_board_cell(side: String) -> Vector2i:
	## 整块战场上随机取一个**空格**，但跳过 forbidden_row_for(side) 那一行
	## （敌方召唤 = 跳过玩家后排；我方召唤 = 跳过敌方后排）。
	var banned:= forbidden_row_for(side)
	var free: Array[Vector2i] = []
	for r in FieldState.BOARD_ROWS:
		if r == banned:
			continue
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			if not state.board.has(c):
				free.append(c)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi_range(0, free.size() - 1)]


func _zone_label(side: String) -> String:
	return "鸭子之力" if side == SIDE_OPPONENT else "成长"


func _effect_summons(side: String) -> void :


	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var interval:= 0
	for c: CardData in zone:
		if c.traits.has("召唤"):
			interval = maxi(interval, c.value)
	if interval <= 0:
		return
	var tick:= turn_number if side == SIDE_SELF else opp_turns
	if tick % interval != 0:
		return
	var repo:= CardRepo.load_json()
	var card: CardData = repo.get_card(9001)
	if card == null:
		card = _fallback_knight()
	var spot:= _random_free_half_cell(side)
	if spot == Vector2i(-1, -1):
		_log("效果卡：己方半场已满，无法召唤鸭子骑士")
		return
	var summoned:= state.place(card, spot, side, true)
	_log("效果卡（每 %d 回合）召唤了鸭子骑士（%s）" % [interval, spot])
	action.emit("place", {"cell": spot, "card": card, "side": side})
	_on_ally_entered(summoned, side)


func _assembly_tick(side: String) -> void :
	## 流水线装配（9147，R219「量产流水线」效果卡）：**每过 3 回合**（该方自己的回合计数
	## % 卡面 `value`），从 `ASSEMBLY_POOL`（量产型俄倪厄 9131 / 量产型赫利俄斯 9137）里
	## **随机挑一个**，召唤到己方半场空格。
	## ⚠️ 与「鸭子号角 9015」的 `_effect_summons` 是**两条独立的口**：
	##    那个固定召唤鸭子骑士，这个要二选一；共用同一套计数口径（双方各数自己的回合）。
	## ⚠️ 半场满 → 本回合不产出（只打日志），不补发、不转伤害。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var interval:= 0
	for c: CardData in zone:
		if c.traits.has(ASSEMBLY_TRAIT):
			interval = maxi(interval, maxi(1, c.value))
	if interval <= 0:
		return
	var tick:= turn_number if side == SIDE_SELF else opp_turns
	if tick <= 0 or tick % interval != 0:
		return
	var repo:= CardRepo.load_json()
	var pick: int = int(ASSEMBLY_POOL[rng.randi_range(0, ASSEMBLY_POOL.size() - 1)])
	var proto: CardData = repo.get_card(pick)
	if proto == null:
		_log("流水线装配失败：卡牌库里没有 id=%d" % pick)
		return
	var spot:= _random_free_half_cell(side)
	if spot == Vector2i(-1, -1):
		_log("流水线装配：己方半场已满，本回合不产出")
		return
	var copy:= CardData.from_dict(proto.to_dict())   # 独立副本：不与卡库实例共享
	var spawned:= state.place(copy, spot, side, true)
	_log("流水线装配（每 %d 回合）：产出 %s（%s）" % [interval, copy.card_name, spot])
	action.emit("assembly_summon", {"cell": spot, "card": copy, "side": side})
	if spawned != null:
		_on_ally_entered(spawned, side)


func _random_free_half_cell(side: String) -> Vector2i:
	var rows:= range(FieldState.OPPONENT_ROWS) if side == SIDE_OPPONENT\
	else range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS)
	var free: Array[Vector2i] = []
	for r: int in rows:
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			if not state.board.has(c):
				free.append(c)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi_range(0, free.size() - 1)]


func _fallback_knight() -> CardData:
	var c:= CardData.new()
	c.id = 9001
	c.card_name = "鸭子骑士"
	c.kind = "盟友"
	c.cost = 6
	c.power = 5
	c.health = 30
	c.attack_range = 1
	c.move_speed = 2
	return c


func _dragon_breath(side: String) -> void :


	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var breath:= 5 + _turn_dmg_bonus(side)
	for cell: Vector2i in state.board.keys().duplicate():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.card.id != 9014:
			continue
		var targets: Array[Vector2i] = []
		for c2: Vector2i in state.board:
			if state.board[c2].owner == foe:
				targets.append(c2)
		# R288：先让玩家看见「是这条龙在动」—— 吐息原来只有一行日志 + 数字变化
		_fx_pulse(cell, p.card, "龙息")
		if targets.is_empty():
			_log("远古虚骨龙吐息：敌方玩家 -%d" % breath)
			_damage_player(foe, breath, "龙息")
		else:
			var t: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
			var q: Placement = state.unit_at(t)
			var dealt:= _hit_unit(q, breath, "龙息")
			_log("远古虚骨龙吐息：%s -%d（剩余 %d）" % [
				q.card.card_name, dealt, maxi(0, q.health)])
			if q.health <= 0:
				_destroy_dead()


func _cannon_fire(side: String) -> void :
	## 充能巨炮（9139，R158 敌人效果卡）：**己方每个回合开始时**，随机破坏
	## **一个敌方单位**（从持有效果卡那方看 = 对方单位）。
	##   * 目标池 = 对方场上**所有**单位（含工事），走引擎 `rng` → 回放同种子可复现；
	##   * 破坏走唯一口 `_destroy`（离场记账 / 亡语 / 击杀记功与别处完全一致），
	##     不在这里另起一套删除；
	##   * 没有目标 → 静默跳过（只打一行日志），**不会**转而伤害对方 HP ——
	##     卡面写的是「破坏一个单位」，没有单位就是空响。
	## ⚠️ 一次破坏几个由卡面 `value` 决定（默认 1，取效果区里最大值，不叠加）。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var shots:= 0
	for c: CardData in zone:
		if c.traits.has(CANNON_TRAIT):
			shots = maxi(shots, maxi(1, c.value))
	if shots <= 0:
		return
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	for _shot in range(shots):
		if over:
			return   # 上一炮已经打出胜负，别再往已结束的战场开火
		var targets: Array[Vector2i] = []
		for cell: Vector2i in state.board:
			if state.board[cell].owner == foe:
				targets.append(cell)
		if targets.is_empty():
			_log("充能巨炮：对方场上没有单位，本回合空响")
			return
		var t: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
		var q: Placement = state.unit_at(t)
		_log("充能巨炮：破坏 %s（%s）" % [q.card.card_name, t])
		action.emit("cannon_fire", {"cell": t, "card": q.card, "side": foe})
		_destroy(t)


# ------------------------------------------------------------ R356 启示者（第三层 Boss）

func _cell_of_unit(card_id: int) -> Vector2i:
	## 场上第一只 `card_id` 所在格（找不到返回 (-1, -1)）。
	## 启示者只有一只，所以「第一只」就是「那一只」—— 也用作「它还在不在场」的判据
	## （`_check_game_over` 的 `win_on_boss`）。
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p != null and p.card != null and p.card.id == card_id:
			return cell
	return Vector2i(-1, -1)


func _naval_gun(side: String) -> void:
	## 舰炮（9201，R356 启示者阶段 1）：该方**回合开始**时随机挑一列，对那一列里
	## **对方**的全部单位各造成 5 伤；那一列一个目标都没有 → 改为直击对方 HP。
	##   * 候选列只取「有目标」的列 —— 这就是用户口径的「优先有单位的列」；
	##     三列全空才走 HP（而且只打**一次** 5 点，不是三列各一次）。
	##   * 列号走引擎 `rng` → 回放同种子可复现。
	##   * 伤害走 `_hit_unit`（与技能同口径：光环易伤 / 护盾 / 减伤都吃），
	##     结算完统一 `_destroy_dead()`（击杀记功 / 亡语与别处一致）。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var dmg:= 0
	for c: CardData in zone:
		if c.traits.has(NAVAL_GUN_TRAIT):
			dmg = maxi(dmg, maxi(1, c.value))
	if dmg <= 0:
		return
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var cols: Array[int] = []
	for col in FieldState.BOARD_COLS:
		for cell: Vector2i in state.board:
			if cell.y == col and state.board[cell].owner == foe:
				cols.append(col)
				break
	if cols.is_empty():
		_log("舰炮：整片战场没有目标 → 直击 HP %d" % dmg)
		action.emit("naval_gun", {"col": -1, "damage": dmg, "side": foe})
		_damage_player(foe, dmg, "舰炮")
		return
	var pick: int = cols[rng.randi_range(0, cols.size() - 1)]
	var targets: Array[Vector2i] = []
	for cell2: Vector2i in state.board:
		if cell2.y == pick and state.board[cell2].owner == foe:
			targets.append(cell2)
	targets.sort_custom(func(a: Vector2i, b: Vector2i): return a < b)
	_log("舰炮：轰击第 %d 列（%d 个目标，各 %d）" % [pick + 1, targets.size(), dmg])
	action.emit("naval_gun", {"col": pick, "damage": dmg, "side": foe})
	for t: Vector2i in targets:
		if over or not state.board.has(t):
			continue
		var q: Placement = state.unit_at(t)
		var dealt:= _hit_unit(q, dmg, "舰炮")
		_log("舰炮：%s -%d（剩余 %d）" % [q.card.card_name, dealt, maxi(0, q.health)])
	_destroy_dead()


func _emergency_call() -> void:
	## 紧急呼叫（9203，R356 启示者阶段 3）：**玩家每个回合开始时**，随机召唤一只
	## 「量产型」敌人（`EMERGENCY_POOL`）到敌方半场，**力量 +10**（烤在这份独立副本上）。
	##   * 落点**优先启示者身边**（四方向相邻的空格），身边满了才退到敌方半场随机空格；
	##   * 触发时机是「玩家回合」而卡挂在敌方效果区 → 本函数**不带 side**：固定读
	##     `state.enemy_effects`、固定召唤给 SIDE_OPPONENT（不假装对称，免得读错效果区）；
	##   * 抽卡与落点都走引擎 `rng` → 回放同种子可复现。
	var has:= false
	for c: CardData in state.enemy_effects:
		if c.traits.has(EMERGENCY_CALL_TRAIT):
			has = true
			break
	if not has or over:
		return
	var repo:= CardRepo.load_json()
	var pick: int = int(EMERGENCY_POOL[rng.randi_range(0, EMERGENCY_POOL.size() - 1)])
	var proto: CardData = repo.get_card(pick)
	if proto == null:
		_log("紧急呼叫失败：卡牌库里没有 id=%d" % pick)
		return
	var spot:= _revelator_free_cell()
	if spot == Vector2i(-1, -1):
		_log("紧急呼叫：敌方半场已满，本回合不召唤")
		return
	var copy:= CardData.from_dict(proto.to_dict())   # 独立副本：+10 力只属于这一只
	copy.power += EMERGENCY_CALL_ATK
	var spawned:= state.place(copy, spot, SIDE_OPPONENT, true)
	_log("紧急呼叫：%s 力量 +%d 登场（%s）" % [copy.card_name, EMERGENCY_CALL_ATK, spot])
	action.emit("emergency_call", {"cell": spot, "card": copy, "side": SIDE_OPPONENT})
	if spawned != null:
		_on_ally_entered(spawned, SIDE_OPPONENT)


func _revelator_free_cell() -> Vector2i:
	## 紧急呼叫的落点：启示者四方向相邻的空格优先（用户口径「优先在启示者身边」），
	## 身边全满 / 启示者不在场 → 退到敌方半场随机空格（`_random_free_half_cell`）。
	var boss_cell:= _cell_of_unit(REVELATOR_ID)
	var near: Array[Vector2i] = []
	if boss_cell.x >= 0:
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var c: Vector2i = boss_cell + d
			if c.x < 0 or c.x >= FieldState.OPPONENT_ROWS \
					or c.y < 0 or c.y >= FieldState.BOARD_COLS:
				continue
			if not state.board.has(c):
				near.append(c)
	if not near.is_empty():
		return near[rng.randi_range(0, near.size() - 1)]
	return _random_free_half_cell(SIDE_OPPONENT)


func _revelator_phase_tick(side: String) -> void:
	## 启示者阶段 1 的「自身效果：每个回合力量 +1」（R356）。
	## 只在该方**第 1 阶段**生效 —— 卡面写明「自身效果」随阶段更换，转阶之后这条就没了。
	## 走 `atk_buff`：与鸭子骑士 / 齿轮升腾同一条「永久累计、无上限」通道。
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p == null or p.card.id != REVELATOR_ID or p.owner != side:
			continue
		if p.boss_phase != 1:
			continue
		p.atk_buff += REVELATOR_ATK_UP
		_log("启示者：阶段 1 力量 +%d（现 %d）" % [REVELATOR_ATK_UP, p.effective_power()])
		action.emit("revelator_grow", {"cell": cell, "card": p.card, "side": side})


func revelator_gate_hp(max_hp: int, next_phase: int) -> int:
	## 「剩余生命 ≤ 返回值 → 进入 `next_phase` 阶段」的血线（R402 唯一口）。
	## 口径 = 最大生命的 **2/3 / 1/3**：300 血 = 200 / 100（与旧写死值一致），
	## 难度 3 起 ×1.1 的 330 血 = 220 / 110 —— 血量被整体上调时血线跟着走，比例不变。
	## ⚠️ 必须走**整数除法**：别写 `int(max_hp * 2.0 / 3.0)` —— `300 * 2.0 / 3.0` 在浮点里
	##    是 199.99999999999997，`int()` 截断后血线凭空少 1（变成 199，R402 差点踩到）。
	## ⚠️ 取整方向 = **向下**：取「第一次真正 ≤ 2/3」的那一点，除不尽的零头不计。
	var mx:= maxi(1, max_hp)
	if next_phase >= 3:
		return mx / 3
	return (mx * 2) / 3


func _revelator_check_phase(p: Placement) -> void:
	## 「剩余生命降到 2/3、1/3 时各进入下一个阶段」（R356 起；R402 起按**比例**算）：
	## 300 血 → 200 / 100；难度 3 起敌方生命 ×1.1 → 330 血 → 220 / 110。
	## **一次大伤害可能连跳两阶**（比如 210 血吃了 120）→ 循环处理，每阶各发一次
	## `boss_phase` 事件（界面排队播，不合并成一条）。
	## ⚠️ 只在**扣血之后**调 —— 两个伤害落地口（`_hit_unit` / `_op_deal_damage`）。
	if p == null or p.card == null or p.card.id != REVELATOR_ID:
		return
	if p.boss_phase <= 0:
		return
	while p.boss_phase < 3 and not over:
		var gate: int = revelator_gate_hp(p.card.health, p.boss_phase + 1)
		if p.health > gate:
			return
		_revelator_enter_phase(p, p.boss_phase + 1)


func _revelator_enter_phase(p: Placement, phase: int) -> void:
	## 转阶段（R356）——用户口径「明确的动画提示 + 重新弹出敌方效果」的引擎侧：
	##   ① 退回后排中间 (0, 1)：原格**有东西就消灭它**（走 `_destroy` 唯一口，
	##      亡语 / 击杀记功 / 离场记账与别处完全一致）；
	##   ② 换掉场上效果卡（舰炮 → 电磁屏障 → 紧急呼叫，右栏效果区随之变化）；
	##   ③ 血量钳到至少 1 —— 一次大伤害把血打成负数时，转阶段不该直接判死；
	##   ④ 发 `boss_phase` 事件：界面播阶段横幅 + 重弹敌方效果 + 把镜头带到它身上。
	var from_cell:= _cell_of(p)
	p.boss_phase = phase
	var home:= REVELATOR_HOME
	if state.board.has(home) and state.board[home] != p:
		var squatter: Placement = state.board[home]
		_log("启示者转阶段：%s 占着后排中间 → 消灭它" % squatter.card.card_name)
		action.emit("revelator_clear", {"cell": home, "card": squatter.card,
				"side": squatter.owner})
		_destroy(home)
	if from_cell.x >= 0 and from_cell != home and state.board.has(from_cell):
		state.move_unit(from_cell, home)
	# R371：2 → 3 阶段「破坏场上所有其他单位」（敌我双方全算，只留它自己）。
	# 走 `_destroy` 唯一口（亡语 / 击杀记功 / 离场记账与别处完全一致）。
	# ⚠️ 先把格子抄一份再逐个杀 —— `_destroy` 里的亡语可能往 board 里**放新单位**，
	#    直接遍历 `state.board.keys()` 等于在迭代中改字典（会漏格 / 会重复杀）。
	var purge_cells: Array[Vector2i] = []
	var purge_names: Array[String] = []
	if phase >= 3:
		for pc: Vector2i in state.board.keys():
			var pu: Placement = state.board[pc]
			if pu == null or pu == p:
				continue
			purge_cells.append(pc)
			purge_names.append(pu.card.card_name)
		for pc: Vector2i in purge_cells:
			var pu2: Placement = state.unit_at(pc)
			if pu2 == null or pu2 == p:
				continue
			_log("启示者进入第三阶段：%s 被冲击波撕碎" % pu2.card.card_name)
			_destroy(pc)
		if not purge_cells.is_empty():
			action.emit("revelator_purge", {"cell": home, "card": p.card,
					"cells": purge_cells, "names": purge_names,
					"count": purge_cells.size()})
	var eff_id:= REVELATOR_NAVAL_GUN_ID
	match phase:
		2:
			eff_id = REVELATOR_SHIELD_ID
		3:
			eff_id = REVELATOR_CALL_ID
	_set_revelator_effect(eff_id)
	if p.health < 1:
		p.health = 1
	_log("启示者进入第 %d 阶段（剩余生命 %d）" % [phase, p.health])
	# R357：带上 `from`（退回前的格子）—— 界面要先把它**滑回**后排（`_slides`），
	# 再播阶段特效，最后才换卡图。没有这个字段，界面就只知道「它已经在后排了」。
	action.emit("boss_phase", {"cell": home, "card": p.card, "phase": phase,
			"health": p.health, "effect_id": eff_id, "from": from_cell})


func _set_revelator_effect(card_id: int) -> void:
	## 把启示者那一套场上效果换成 `card_id`（R356）。
	## 只动 9201 / 9202 / 9203 这三张：别的敌方效果（将来关卡表里再挂的）不碰。
	## 挂的是**独立副本** —— 效果区里那份要是卡库实例，任何临时改动都会跨局泄漏。
	var pool:= [REVELATOR_NAVAL_GUN_ID, REVELATOR_SHIELD_ID, REVELATOR_CALL_ID]
	for c: CardData in state.enemy_effects.duplicate():
		if c.id in pool:
			state.enemy_effects.erase(c)
	var repo:= CardRepo.load_json()
	var proto: CardData = repo.get_card(card_id)
	if proto == null:
		_log("启示者阶段效果失败：卡牌库里没有 id=%d" % card_id)
		return
	var copy:= CardData.from_dict(proto.to_dict())
	state.enemy_effects.append(copy)
	_log("启示者阶段效果：%s 启用" % copy.card_name)


func _revelator_has_escort(p: Placement) -> bool:
	## 启示者阶段 3（R371）：「场上有其他单位时免疫攻击以外的伤害」的**唯一判据口**。
	## 「其他单位」只数**启示者自己一方**的 —— 要是敌我双方都数，玩家场上只要还有一只单位
	## 它就永久免疫技能，机制会退化成「技能永远打不动本体」，那不是这条要表达的意思。
	## 实战口径 = **先清掉它的随从（紧急呼叫召来的量产型），技能才打得进本体**；攻击不受限。
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q != null and q != p and q.owner == p.owner:
			return true
	return false


func _revelator_split(p: Placement, amount: int, source: String) -> int:
	## 启示者阶段 3（R356）：「与它接通的友方单位代替它承受一半伤害」。
	##   * 去尾 = 向下取整（10 → 5、5 → 2），剩下那一半仍由启示者自己吃；
	##   * 接通 = `_component_of_cell()` 的四方向相邻连通（与闪电链 / 护盾生成器同一套），
	##     且**只认敌方自己人**（玩家的单位贴在旁边不算「友方」）；
	##   * 代受者挑**当前生命最高**的那一只 —— 确定性选择，不掷骰子，回放与回归都稳；
	##   * 代受走 `_hit_unit(..., allow_redirect = false)`：不再往下转发，避免互相弹。
	## 返回**剩余**伤害（调用方接着结算）。
	if p == null or p.card == null or p.card.id != REVELATOR_ID or p.boss_phase < 3:
		return amount
	if amount < 2:
		return amount
	var cell:= _cell_of(p)
	if cell.x < 0:
		return amount
	var best: Placement = null
	var best_cell:= Vector2i(-1, -1)
	for c: Vector2i in _component_of_cell(cell):
		var q: Placement = state.unit_at(c)
		if q == null or q == p or q.owner != SIDE_OPPONENT:
			continue
		if best == null or q.health > best.health:
			best = q
			best_cell = c
	if best == null:
		return amount
	var half: int = amount / 2
	_log("紧急呼叫：%s 与启示者接通 → 代它承受 %d 点（%s）" % [
			best.card.card_name, half, source])
	action.emit("revelator_cover", {"cell": cell, "to": best_cell, "to_card": best.card,
			"amount": half, "source": source})
	_hit_unit(best, half, "接通代受", false)
	if best.health <= 0:
		_destroy_dead()
	return amount - half


func _asclepius_armor_tick(side: String) -> void:
	## R162：阿斯克勒庇厄斯（9141）的「护甲积攒」。
	## 该方回合开始时：获得 16 护甲；若获得前已有护甲，则清零并对随机敌方单位造成等量伤害，
	## 然后力量 +1。伤害走 `_hit_unit`（与技能同口径，非攻击），击杀记功等联动与别处一致。
	var foe := SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != side or p.card.id != ASCLEPIUS_ID:
			continue
		if p.armor > 0:
			var blast := p.armor
			p.armor = 0
			var targets: Array[Vector2i] = []
			for c: Vector2i in state.board:
				if state.board[c].owner == foe:
					targets.append(c)
			if not targets.is_empty():
				var t: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
				var q: Placement = state.unit_at(t)
				_log("护甲积攒：%s 爆发 %d 点伤害 → %s" % [p.card.card_name, blast, q.card.card_name])
				action.emit("armor_blast", {"cell": cell, "target": t, "card": p.card,
						"damage": blast, "side": side})
				_hit_unit(q, blast, "护甲爆发", false, false)
				_destroy_dead()   # 存爆击杀需要即时清理并结算溢出/击杀记功
			else:
				_log("护甲积攒：%s 准备爆发，但对方场上没有单位" % p.card.card_name)
			p.atk_buff += ASCLEPIUS_GROWTH_ATK
			_log("护甲积攒：%s 力量 +%d（现 %d）" % [p.card.card_name, ASCLEPIUS_GROWTH_ATK, p.effective_power()])
		p.armor += ASCLEPIUS_ARMOR
		_log("护甲积攒：%s 获得 %d 护甲（现 %d）" % [p.card.card_name, ASCLEPIUS_ARMOR, p.armor])
		action.emit("armor_gain", {"cell": cell, "card": p.card, "side": side,
				"armor": p.armor, "gained": ASCLEPIUS_ARMOR})


func _max_buff(side: String) -> int:
	var m:= 0
	for p: Placement in state.board.values():
		if p.owner == side:
			m = maxi(m, p.atk_buff)
	return m


## 把「已记录但还没生效」的力量减益转成生效（debuff_stage 0 → 1）。
##
## ⚠️ R143 起这是**兜底**：所有力量减益的施加口（威慑 / 敲晕 / 幻影斗篷 / 回响 /
## 黑暗陷阱 / 削弱）都**当场**置 1，不再有「下回合才生效」的延迟 —— 正常不会触发。
## 保留它是为了防止将来某张新卡「只加了 atk_debuff、忘了置 stage」时减值永远不生效
## （那种情况下至少会在目标方下个回合开始补上，而不是静默丢失）。
func _arm_debuffs(side: String) -> void :
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.atk_debuff > 0 and p.debuff_stage == 0:
			p.debuff_stage = 1
			_log("%s 的攻击力被削弱 %d（本回合 %d）" % [
				p.card.card_name, p.atk_debuff, p.effective_power()])


func _summon_familiars(side: String) -> void :


	var repo:= CardRepo.load_json()
	var familiar: CardData = repo.get_card(9009)
	for cell: Vector2i in state.board.keys().duplicate():
		var p:= state.unit_at(cell)
		if p == null or p.owner != side or p.card.id != 9008:
			continue

		var has_familiar:= false
		for q: Placement in state.board.values():
			if q.owner == side and q.card.id == 9009:
				has_familiar = true
				break
		if has_familiar:
			continue
		var spot:= _free_cell_near(cell, side)
		if spot == Vector2i(-1, -1):
			continue
		# ⚠️ R122：召唤物 `summon = true` → 当回合恰好 1 轮行动（不吃哈气/双动）；
		# 且本函数已排在 `_familiar_growth` **之后** → 新使魔当回合不吃使魔之力的 +1
		# （它这一回合才上场，本回合的「回合开始成长」结算时它还不存在）。
		var card:= familiar if familiar != null else _fallback_familiar()
		var summoned:= state.place(card, spot, side, true)
		p.tapped = true
		_log("%s 召唤了使魔鸭子（%s），自己横置" % [p.card.card_name, spot])
		action.emit("place", {"cell": spot, "card": card, "side": side})
		_on_ally_entered(summoned, side)


func _free_cell_near(cell: Vector2i, side: String) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var c:= cell + d
		if _valid_own_cell(c, side) and not state.board.has(c):
			return c
	var rows:= range(FieldState.OPPONENT_ROWS) if side == SIDE_OPPONENT\
	else range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS)
	for r: int in rows:
		for col in FieldState.BOARD_COLS:
			var c2:= Vector2i(r, col)
			if not state.board.has(c2):
				return c2
	return Vector2i(-1, -1)


func _valid_own_cell(c: Vector2i, side: String) -> bool:
	if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
		return false
	var own_half:= c.x >= FieldState.OPPONENT_ROWS if side == SIDE_SELF\
	else c.x < FieldState.OPPONENT_ROWS
	return own_half


func _fallback_familiar() -> CardData:
	## 牌库里找不到 9009 时的兜底 handmade 卡（**traits 要补上**，
	## 否则使魔之力 9115 的「带『使魔』trait」判定会漏掉它）。
	var c:= CardData.new()
	c.id = FAMILIAR_DUCK_ID
	c.card_name = "使魔鸭子"
	c.kind = "盟友"
	c.cost = 3
	c.power = 4
	c.health = 15
	c.attack_range = 1
	c.move_speed = 1
	c.traits = ["鸭", FAMILIAR_TRAIT]
	return c


func _draw_many(n: int) -> int:
	## 抽 n 张的**唯一口**（所有「抽卡」都走这里）。返回**真正进手牌**的张数。
	## R299（用户规则）：手牌满时**不再停下不抽** —— 抽到的牌由 `FieldState.draw()` 直接丢进弃牌区，
	## 这里逐张发 `hand_burn`（带序号，界面用来错开动画），最后汇总发一条 `hand_full`。
	## ⚠️ 区分三种「没进手牌」：① 手牌满 → burn（卡进弃牌区）；② 牌库+弃牌区都空 → 抽不到；
	##   ③ 抽到了但…（不存在）。判据只看 `state.last_burn_card`，不要去比较弃牌区张数
	##   （弃牌区可能同时被别的效果改动）。
	var got := 0
	var burned := 0
	var gained: Array = []
	for _i in n:
		var c := state.draw()
		if c != null:
			got += 1
			gained.append(c)
			continue
		var bc: CardData = state.last_burn_card
		if bc != null:
			state.last_burn_card = null
			burned += 1
			action.emit("hand_burn", {"card": bc, "seq": burned - 1,
					"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
			continue
		break   # 牌库与弃牌区都空：后面的也抽不到，直接收工
	if burned > 0:
		_log("手牌已满（%d 张）：%d 张抽到的牌直接进弃牌区" % [FieldState.HAND_LIMIT, burned])
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT,
				"hand": state.hand.size(), "burned": burned})
	if got + burned < n and state.deck.is_empty() and state.discard.is_empty():
		_log("牌库与弃牌区都已空，没有卡牌可以抽了")
		action.emit("deck_empty", {"want": n, "got": got, "burned": burned})
	# R396（用户报「聚能炮击的抽卡动画有可能被吞，如果抽到的是另一张聚能炮击」）：
	# 界面判断「哪张卡是新进手牌的」靠**手牌 id 序列**做 diff（`battle_scene._hand_sync`），
	# 可「打出一张 9145、又抽到另一张 9145」时序列**一个字节都没变**
	# （[9145, 9145] → [9145, 9145]）→ diff 判「没变化」→ 抽卡飞入整个被吞掉。
	# 抽牌这件事只有引擎知道，所以在这里逐张报实例上去，界面别再去猜。
	for gc: CardData in gained:
		action.emit("card_gained", {"card": gc, "how": "draw"})
	return got


func _grant_to_hand(card: CardData, source: String) -> bool:
	## R299（用户规则）：**一切「加入手卡」的唯一口**。
	## * 手牌未满 → 进手牌，返回 true；
	## * 手牌已满 → 直接进**弃牌区**，返回 false —— 并 emit `hand_burn` 让界面播
	##   「卡从来源位置飞向弃牌堆」（与「抽到但手牌满」完全同一条动画 / 日志口径）。
	## ⚠️ 卡**不会凭空消失**：以前各处「满就放弃」等于把这张牌蒸发掉，玩家既没得到、
	##   也看不见它去了哪；现在它至少落在弃牌区，之后还能被洗回牌库（诅咒类也一样）。
	if card == null:
		return false
	if state.hand_full():
		if card.is_ephemeral:
			# ⚠️ 衍生物（野兔 9032 的复制品）**不能进弃牌区** —— 弃牌区会被整堆洗回牌库，
			#    于是这几张「本场战斗内的产物」会被永久抽出来，无限刷（见 discard_hand 的注释）。
			#    它们拐进消耗区：一样是「没进手」，但本场彻底消失。
			state.void_count += 1
			state.void_cards.append(card)
			_log("%s：手牌已满（%d 张）→ 衍生物「%s」本场消失" % [
					source, FieldState.HAND_LIMIT, card.card_name])
			action.emit("hand_burn", {"card": card, "seq": 0, "to": "void",
					"limit": FieldState.HAND_LIMIT, "hand": state.hand.size(), "source": source})
			return false
		state.discard.append(card)
		_log("%s：手牌已满（%d 张）→ 「%s」直接进弃牌区" % [
				source, FieldState.HAND_LIMIT, card.card_name])
		action.emit("hand_burn", {"card": card, "seq": 0, "to": "discard",
				"limit": FieldState.HAND_LIMIT, "hand": state.hand.size(), "source": source})
		return false
	state.hand.append(card)
	# R396：与 `_draw_many` 同一口径 —— 「进手牌」这件事由引擎报，界面不靠 id 序列猜
	action.emit("card_gained", {"card": card, "how": source})
	return true

func apply_battle_start_relics(repo: CardRepo) -> void :



	if over:
		return
	if self_relics.has(ICECREAM_RELIC_ID) and state.hp_self > 0:
		var after:= maxi(1, state.hp_self - ICECREAM_HP_COST)
		var lost:= state.hp_self - after
		state.hp_self = after
		_log("冰淇淋与汽水：战斗开始失去 %d 点生命（剩余 %d）" % [lost, state.hp_self])
		action.emit("relic", {"id": ICECREAM_RELIC_ID, 
			"text": "冰淇淋与汽水：开场 -%d 生命" % lost})
	if self_relics.has(EGG_DUCK_RELIC_ID) and repo != null:
		var egg:= repo.get_card(EGG_CARD_ID)
		var home:= Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2)
		if egg != null and not state.board.has(home):
			state.place(egg, home, SIDE_SELF)
			_log("生蛋鸭：开场在我方前排中央 %s 放置「%s」（%d 攻 / %d 血）"
				%[home, egg.card_name, egg.power, egg.health])
			action.emit("place", {"cell": home, "card": egg, "side": SIDE_SELF})
	# 机械之心角色道具「机械核心」（6025，R82）：开场手牌 +MECH_CORE_PROTO 张「素体」。
	# 放这里（而不是回合开始）是因为它是**游戏开始时**的一次性发牌 ——
	# 早于第 1 回合抽牌，玩家开场就握着一手素体。
	if self_relics.has(MECH_CORE_RELIC_ID) and repo != null:
		var proto: CardData = repo.get_card(PROTO_ID)
		if proto == null:
			_log("机械核心：卡库缺少「素体」(%d)，未加入手牌" % PROTO_ID)
		else:
			var added:= 0
			for _i in MECH_CORE_PROTO:
				# 独立副本：素体带「留手」，若与牌库里的共享实例同对象，
				# 回合结束的不弃判定与「按张记账」的表都会互相串。
				# R299：手牌满 → 素体**直接进弃牌区**（不再「满就停」把这张蒸发掉）。
				if _grant_to_hand(CardData.from_dict(proto.to_dict()), "机械核心"):
					added += 1
			if added > 0:
				_log("机械核心：开场手牌加入 %d 张「素体」（0 费 1/1，回合结束不弃）" % added)
				action.emit("relic", {"id": MECH_CORE_RELIC_ID,
						"text": "机械核心：手牌 +%d 张「素体」" % added})
	# 水晶骰子（6040，R311）：「?」房进战斗 → 掷骰，前 X 回合每回合 +1 费。
	# ⚠️ 放在本函数**最后**：前面那些开场道具一个都不消耗随机数，
	#    追加在末尾不会改动它们已有的抽卡 / 落位表现。
	# ⚠️ 只有「持有道具 + 本场来自 ? 房」两条同时成立才掷 —— 别把普通战斗也算进去。
	if self_relics.has(DICE_RELIC_ID) and dice_battle:
		dice_roll = rng.randi_range(1, DICE_FACES)
		dice_energy_turns = dice_roll
		_log("水晶骰子：掷出 %d 点 → 前 %d 回合每回合额外 %d 点费用"
				% [dice_roll, dice_energy_turns, DICE_ENERGY])
		action.emit("dice_roll", {"roll": dice_roll, "turns": dice_energy_turns,
				"energy": DICE_ENERGY})


func _heal_aura(side: String) -> void :



	var healers: Array[Placement] = []
	for cell: Vector2i in _side_cells(side):
		var h: Placement = state.board[cell]
		if h.card.traits.has(HEALER_TRAIT):
			healers.append(h)
	if healers.is_empty():
		return
	for h2: Placement in healers:
		var target: Placement = null
		var worst_pct:= 2.0
		for cell2: Vector2i in _side_cells(side):
			var q: Placement = state.board[cell2]
			var pct:= float(q.health) / float(maxi(1, q.card.health))
			if pct < worst_pct:
				worst_pct = pct
				target = q
		if target == null:
			continue
		var before:= target.health
		target.health = mini(target.card.health, target.health + h2.card.value)
		var gained:= target.health - before
		if gained <= 0:
			continue
		_log("%s 治疗 %s：+%d（%d/%d）" % [h2.card.card_name, target.card.card_name, 
			gained, target.health, target.card.health])
		action.emit("heal", {"cell": _cell_of(target), "card": target.card, 
			"amount": gained, "health": target.health, "side": target.owner})


func _kiln_hatch(side: String) -> void :




	# 产物生命 X = 随**该方**回合数每过 2 回合 +1（窑主人的第几回合，向上取整）；
	# 首回合起算，至少 1。（R172 下调：原为「生命 = 当前己方回合数」。）
	var t:= turn_number if side == SIDE_SELF else opp_turns
	var x:= maxi(1, (t + 1) / 2)
	var repo:= CardRepo.load_json()
	for cell: Vector2i in state.board.keys().duplicate():
		var p:= state.unit_at(cell)
		if p == null or p.owner != side or not p.card.traits.has(KILN_TRAIT):
			continue
		var spawn: CardData = repo.get_card(p.card.value) if p.card.value > 0\
		else repo.get_card(CERAMIC_CARD_ID)
		if spawn == null:
			spawn = _fallback_ceramic()
		# ── R259：场上该方陶瓷鸭 >= KILN_CROWDED_COUNT 只时，不再四邻各刷一只 ──
		# （鸭海滚雪球：每回合 +3~4 只，几个回合就铺满屏）。改为：
		# ① 相邻空格里**随机挑一个**只召唤 1 只（随机走引擎 rng，回放同种子可复现）；
		# ② 给**所有**陶瓷鸭（含刚出生的）+1 血量 —— 数量收住、单兵变硬。
		# 不足 3 只时保持原样（首回合仍是经典的「四邻各刷一只」）。
		var have:= 0
		for q: Placement in state.board.values():
			if q.owner == side and q.card.id == CERAMIC_CARD_ID:
				have += 1
		if have >= KILN_CROWDED_COUNT:
			var spots: Array[Vector2i] = []
			for d2: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
					Vector2i(-1, 0), Vector2i(1, 0)]:
				var c2:= cell + d2
				if c2.x < 0 or c2.x >= FieldState.BOARD_ROWS\
				or c2.y < 0 or c2.y >= FieldState.BOARD_COLS:
					continue
				if state.board.has(c2):
					continue
				spots.append(c2)
			if spots.is_empty():
				_log("%s：周围没有空格，本回合未烧出陶瓷鸭" % p.card.card_name)
				continue
			var pick: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
			# 每一只都放**副本**并把生命改成 X：库里的对象被同名卡共享，
			# 直接改它会污染全局（第 29 轮实例级减费踩过同类坑）。
			var body: CardData = CardData.from_dict(spawn.to_dict())
			body.health = x
			var hatched:= state.place(body, pick, p.owner, true)
			action.emit("place", {"cell": pick, "card": body, "side": p.owner})
			_on_ally_entered(hatched, p.owner)
			var grown:= 0
			for cell2: Vector2i in state.board.keys().duplicate():
				var q2: Placement = state.unit_at(cell2)
				if q2 == null or q2.owner != side or q2.card.id != CERAMIC_CARD_ID:
					continue
				q2.health += 1
				grown += 1
				action.emit("heal", {"cell": cell2, "card": q2.card, "amount": 1,
						"health": q2.health, "side": q2.owner})
			_log("%s：场上已有 %d 只陶瓷鸭，只烧 1 只（生命 %d）并给所有 %d 只 +1 血" % [
					p.card.card_name, have, x, grown])
			continue
		var born:= 0
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, 0), Vector2i(1, 0)]:
			var c:= cell + d
			if c.x < 0 or c.x >= FieldState.BOARD_ROWS\
			or c.y < 0 or c.y >= FieldState.BOARD_COLS:
				continue
			if state.board.has(c):
				continue
			# 每一只都放**副本**并把生命改成 X：库里的对象被同名卡共享，
			# 直接改它会污染全局（第 29 轮实例级减费踩过同类坑）。
			var body2: CardData = CardData.from_dict(spawn.to_dict())
			body2.health = x
			var hatched2:= state.place(body2, c, p.owner, true)
			born += 1
			action.emit("place", {"cell": c, "card": body2, "side": p.owner})
			_on_ally_entered(hatched2, p.owner)
		if born > 0:
			_log("%s 烧出 %d 只陶瓷鸭（生命 %d：第 %d 回合，每 2 回合 +1）" % [
				p.card.card_name, born, x, t])


func _fallback_ceramic() -> CardData:
	var c:= CardData.new()
	c.id = CERAMIC_CARD_ID
	c.card_name = "陶瓷鸭"
	c.kind = "盟友"
	c.cost = 1
	c.power = 6
	c.health = 1
	c.attack_range = 1
	c.move_speed = 1
	return c


func _clockwork_summon(_side: String) -> void :



	var repo:= CardRepo.load_json()
	for cell: Vector2i in state.board.keys().duplicate():
		var p:= state.unit_at(cell)
		if p == null or not p.card.traits.has(CLOCKWORK_TRAIT):
			continue
		var want:= p.card.value if p.card.value > 0 else MECH_DUCK_SUMMON_COUNT
		var have:= 0
		for q: Placement in state.board.values():
			if q.owner == p.owner and q.card.id == CLOCKWORK_DUCK_ID:
				have += 1
		var need:= want - have
		if need <= 0:
			continue
		var spawn: CardData = repo.get_card(CLOCKWORK_DUCK_ID)
		if spawn == null:
			spawn = _fallback_clockwork()
		var born:= 0
		for i in need:
			var spot:= _token_spot(cell, p.owner)
			if spot == Vector2i(-1, -1):
				break
			var hatched:= state.place(spawn, spot, p.owner, true)
			born += 1
			action.emit("place", {"cell": spot, "card": spawn, "side": p.owner})
			_on_ally_entered(hatched, p.owner)
		if born > 0:
			_log("%s 造出 %d 只发条鸭（场上共 %d 只）" % [p.card.card_name, born, have + born])


func _fallback_clockwork() -> CardData:
	var c:= CardData.new()
	c.id = CLOCKWORK_DUCK_ID
	c.card_name = "发条鸭"
	c.kind = "盟友"
	c.cost = 1
	c.power = 4
	c.health = 5
	c.attack_range = 1
	c.move_speed = 1
	return c




## 鸭语耳环（6015）自动出牌：pending 状态 + **逐张推进**的唯一口。
## R77：原来这里是「一个 while 循环一口气跑完最多 20 张」，全部发生在 _begin_turn 的一次调用里
## → 玩家只看到最终局面，完全不知道中间出了什么牌。现在拆成「每帧出一张」，
## 由 battle_scene 的 _tick_earring_autoplay() 按动画节奏驱动（配合每张之间的停顿）。
## R285：改为「正常抽牌后从左到右扫描手牌」——跳过无法打出的牌，一轮扫完若还有进展，
## 就再扫一轮，直到没有牌能打出或已达 20 张上限。
## R77：true = 逐张驱动（界面实机，能看到动画）；false = 一次性同步跑完（headless 回归）。
## 由 battle_scene 在 _ready 里置 true；回归保持 false 以免依赖帧。
var autoplay_stepwise := false
var earring_pending := false      # 是否处于「自动出牌中」
var earring_played := 0           # 已自动出了几张
## R288 失控要塞 9161：最近一次入场**实际释放**的技能卡名（日志 / UI / 回归断言共用）。
var fort_casts: Array[String] = []
var earring_hand_index := 0       # 当前扫描到手牌第几张（从左到右）
var earring_pass_played := 0      # 本轮扫描已打出几张（用于判断是否需要再扫一轮）


func earring_autoplay_active() -> bool:
	## 界面侧判据：自动出牌是否还在进行中（用于锁住玩家操作）。
	return earring_pending


func _autoplay_from_deck() -> int:
	## **同步**跑完（headless 回归走这条；界面实机走下面的逐张版）。
	begin_earring_autoplay()
	var guard := 0
	while earring_pending and guard < EARRING_AUTOPLAY_MAX * 4:
		_autoplay_step(earring_played)
		guard += 1
	return earring_played


func begin_earring_autoplay() -> void:
	## 开始自动出牌（不立即出牌）。界面侧每帧调 _autoplay_step 推进。
	earring_pending = true
	earring_played = 0
	earring_hand_index = 0
	earring_pass_played = 0
	action.emit("earring_autoplay_begin", {})


func _autoplay_step(step_index: int) -> bool:
	## **推进一步**（处理一张手牌）。返回 false = 该停了。
	## step_index 仅用于事件/日志，不参与判定。
	if earring_played >= EARRING_AUTOPLAY_MAX:
		_finish_earring_autoplay(earring_played, "已达上限 %d 张" % EARRING_AUTOPLAY_MAX)
		return false
	if state.hand.is_empty():
		_finish_earring_autoplay(earring_played, "手牌已空")
		return false
	# 一轮扫描到头：若本轮出过牌，就再从头扫一轮；否则结束。
	if earring_hand_index >= state.hand.size():
		if earring_pass_played == 0:
			_finish_earring_autoplay(earring_played, "没有能出的牌")
			return false
		earring_hand_index = 0
		earring_pass_played = 0
	var card: CardData = state.hand[earring_hand_index]
	if _autoplay_play(earring_hand_index):
		earring_played += 1
		earring_pass_played += 1
		# 出牌后手牌整体左移，保持索引即可处理下一张。
		action.emit("earring_autoplay_step", {"index": step_index, "total": earring_played,
			"card_name": card.card_name, "cost": card.cost})
		return true
	else:
		earring_hand_index += 1
		return true


func _finish_earring_autoplay(played: int, why: String) -> void:
	## 自动出牌收尾（唯一口）：关掉 pending + 发事件让界面停手。
	if not earring_pending:
		return
	earring_pending = false
	_log("鸭语耳环：自动出牌结束（共 %d 张 · %s）" % [played, why])
	action.emit("earring_autoplay_end", {"played": played, "why": why})


func _autoplay_play(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var card: CardData = state.hand[hand_index]
	# 通用出牌上限（夜行等）
	if _play_cap_blocked() != "":
		_log("鸭语耳环：%s 被出牌上限挡下，自动出牌跳过" % card.card_name)
		return false
	if state.energy < cost_of(card):
		_log("鸭语耳环：%s 费用不足（%d < %d），自动出牌跳过"
			% [card.card_name, state.energy, cost_of(card)])
		return false
	if card.is_curse():
		# R223：诅咒卡（「疲惫」9149）—— 唯一打出入口是 use_curse（玩家自己决定
		# 什么时候扔掉这张废牌）。自动出牌**绝不能**碰它：它会掉进下面的
		# `play_from_hand` 被当成单位摆上场（诅咒不是单位）。
		_log("鸭语耳环：%s 是诅咒卡，自动出牌跳过" % card.card_name)
		return false
	if card.x_cost:
		# X 费卡（流星雨）：会一口气吃掉全部费用 → 自动出牌不碰它（留在手里）。
		# ⚠️ R124 起它在 0 费用时也算「可打出」（X 记 0）→ 自动出牌**更**不该碰它，
		#    否则等于白白丢掉一张手牌。
		_log("鸭语耳环：%s 是 X 费卡，自动出牌跳过" % card.card_name)
		return false
	if card.is_spell():
		# R202：需要选手牌目标的技能（系统升级 / 回收 / 填充）没有棋盘目标，自动出牌无法替他选。
		if card.target_mode in ["hand_unit", "hand_any"]:
			_log("鸭语耳环：%s 需要选手牌目标，自动出牌跳过" % card.card_name)
			return false
		# 两段式 / 多目标技能自动出牌无法处理
		if card.id in [INFILTRATE_ID, SWAP_UNITS_ID]:
			_log("鸭语耳环：%s 需要多段目标，自动出牌跳过" % card.card_name)
			return false
		# 回旋斩：本回合用卡数不足时跳过
		if card.id == WHIRL_BLADE_ID and state.self_card_plays < WHIRL_BLADE_NEED:
			_log("鸭语耳环：%s 条件未满足，自动出牌跳过" % card.card_name)
			return false
		var targets := _autoplay_spell_targets(card)
		if card.needs_target() and targets.is_empty():
			_log("鸭语耳环：%s 没有合法目标，无法自动使用" % card.card_name)
			return false
		# 随机目标
		var target = null
		if not targets.is_empty():
			target = targets[rng.randi() % targets.size()]
		var plays_before := state.self_card_plays
		use_spell(hand_index, target)
		return state.self_card_plays > plays_before
	if card.is_effect():
		var plays_before := state.self_card_plays
		use_effect(hand_index)
		return state.self_card_plays > plays_before
	if discard_cost_of(card) > 0:
		_log("鸭语耳环：%s 需要额外丢弃 %d 张手牌，自动出牌跳过"
			% [card.card_name, discard_cost_of(card)])
		return false
	var cell := _autoplay_cell(card)
	if cell == Vector2i(-1, -1):
		_log("鸭语耳环：没有合法位置，无法放置 %s" % card.card_name)
		return false
	var plays_before := state.self_card_plays
	var placed := play_from_hand(hand_index, cell)
	if placed == null or state.self_card_plays <= plays_before:
		return false
	if crow_pending:
		var crow_auto := crow_options()
		if not crow_auto.is_empty():
			crow_recall(crow_auto[0])
	if overhaul_pending:
		var oh_auto := overhaul_options()
		if not oh_auto.is_empty():
			overhaul_recall(oh_auto[0])
	return true


func _autoplay_cell(card: CardData) -> Vector2i:
	## 自动出牌时给单位/场地挑一个**随机合法位置**。
	var candidates: Array[Vector2i] = []
	if card.is_field():
		var aim := field_aim(card)
		for row in FieldState.BOARD_ROWS:
			for col in FieldState.BOARD_COLS:
				var c := Vector2i(row, col)
				if field_place_allowed(c, aim):
					candidates.append(c)
	else:
		for row in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for col in FieldState.BOARD_COLS:
				var c := Vector2i(row, col)
				if not state.board.has(c):
					candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi() % candidates.size()]


func _autoplay_spell_targets(card: CardData) -> Array[Vector2i]:
	## 自动出牌时给技能挑一组**合法目标**；实际使用时会从中随机选一个。
	var out: Array[Vector2i] = []
	if not card.needs_target():
		return out
	if card.id == ICE_WALL_SPELL_ID:
		out.append(Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2))
		return out
	if card.id == FIRE_WALL_SPELL_ID:
		# 火墙术：所有有敌人的横行都是合法目标。
		for r in FieldState.BOARD_ROWS:
			var n := 0
			for cc in FieldState.BOARD_COLS:
				var q: Placement = state.unit_at(Vector2i(r, cc))
				if q != null and q.owner == SIDE_OPPONENT:
					n += 1
			if n > 0:
				out.append(Vector2i(r, FieldState.BOARD_COLS / 2))
		return out
	var heal := card.id in [2002, 7202]
	var pool := _side_cells(SIDE_SELF if heal else SIDE_OPPONENT)
	if card.id == UPGRADE_ID or card.id == ARMOR_PLATE_ID \
			or card.id == SHARED_SHIELD_ID:
		# 升级 8027（R82）/ 加厚装甲 8044（R95，机械之心）/ 共享护盾 8069（R269）：
		# 返回所有合法己方目标，实际由 _autoplay_play 随机挑选。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if card.id in [ARMOR_PLATE_ID, SHARED_SHIELD_ID] and up.card.kind != "盟友":
				continue
			if card.id == SHARED_SHIELD_ID and up.card.has_affix(AFFIX_SHARED_SHIELD):
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			out.append(uc)
		return out
	if card.id == DEMOLISH_ID:
		# 拆解 8049（R97，机械之心）：任意己方盟友/工事都是合法目标。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			out.append(uc)
		return out
	if card.id == REORG_ID:
		# 重组 8051（R99，机械之心）：受伤己方盟友/工事。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if up.card.health - up.health > 0:
				out.append(uc)
		return out
	if card.id == TRANSCEND_ID:
		# 超越极限 8053（R99，机械之心）：还没有超负荷的己方盟友/工事。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if up.card.has_affix(AFFIX_OVERLOAD):
				continue
			out.append(uc)
		return out
	if card.id == REBOOT_ID:
		# 重启 8054（R100，机械之心）：受伤己方盟友/工事。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if up.card.health - up.health > 0:
				out.append(uc)
		return out
	# 默认伤害/治疗：所有有效侧单位格
	for c: Vector2i in pool:
		if state.board.has(c):
			out.append(c)
	return out


func end_turn() -> void :
	if over:
		return


	# 鸡煲（6003）：不再限制「每场战斗一次」→ 第一回合结束、以及每个用过效果卡的回合结束都触发
	if current_side == SIDE_SELF and self_relics.has(6003)\
	and (turn_number == 1 or state.self_effect_plays > 0):
		_chicken_pot()


	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == current_side:
			if p.debuff_stage == 1:
				p.atk_debuff = 0
				p.debuff_stage = 0
			p.atk_buff_turn = 0
			if p.rooted == 2:
				p.rooted = 0   # 禁足（冰霜陷阱）：生效回合结束解除
	# 陷阱加强（R238）：**本回合一步没挪**的敌方单位，回合结束时踩响脚下的陷阱。
	# ⚠️ 必须排在上面那段「清本回合 debuff / 解禁足」**之后**：黑暗陷阱给的是
	#    「本回合攻击 -1」（debuff_stage = 1），排在前面会被紧接着这个循环当场擦掉，
	#    等于白触发。排在后面 → 它生效到对方的下一个回合结束，正是「踩响了」的手感。
	_trap_still_tick(current_side)
	# 沉睡（恶魔鸭 9116）：**回合递减口** —— 本方回合结束时，本方还在睡的单位
	# sleep_left -1；减到 0 就此醒来（下一回合可行动）。
	# R122 用户口径：沉睡**随着回合减少**（与「受伤也 -1」并存，见 _demon_duck_hurt）。
	# 恶魔鸭 SLEEP_TURNS=2 → 没人打它时：第 1、2 个己方回合不行动，第 3 回合起正常。
	_sleep_tick(current_side)
	# 清泉（8028，R83）：持续型场地 —— 本方回合结束时，站在清泉上的本方单位回血。
	# 放在 `_sleep_tick` 之后：两者都是「本方回合结束的收尾」，挨着才好读。
	_field_aura_tick(current_side)
	# 自我修复（8035，R87）：「每回合结束回复 4 点生命」—— 同样只结算本方单位。
	_regen_tick(current_side)
	# 充电装置（8041，R91）：被「接通」的**己方**单位每回合结束回 2 点生命。
	# 放在 `_regen_tick` 之后：两者都是「自己回合结束的回血」，叠在相邻格里会一起回。
	_charge_tick(current_side)
	# 超负荷（旧式机兵 8050，R98）：己方回合结束时，生命仍为负数的超负荷单位死亡。
	_overload_tick(current_side)
	# 铸造倒计时（量产型赫卡同克瑞斯 9133，R149）：**我方回合结束** -1（用户口径）。
	# ⚠️ 由「是谁的回合在结束」驱动，而**不看单位归属** —— 场上只有敌方单位带这个字段，
	#    若按归属判就变成「敌方回合结束才减」，和卡面写的那句话对不上。
	if current_side == SIDE_SELF:
		_fuse_tick()
		_forge_tick()      # R150 赫菲斯托斯：连续空转 → 力量 / 攻程 +1

	if current_side == SIDE_SELF:
		# 罐子（9157，R245；R340 改为直接召唤敌人）：回合结束时**还在手卡**的这张卡 → 本场消失 + 召唤一个敌人。
		# ⚠️ 必须排在 `discard_hand()` **之前**：手牌先被弃掉，这效果就永远触发不了。
		# R315 爆米花（6046）：本回合**一次都没**以敌人 / 敌人所在格为目标用过技能 → 下回合多抽 1。
		# ⚠️ 放在弃牌**之前**：这两个都是「回合结束的收尾」，顺序无关，但挨着 `_jar_tick`
		#    好读，也保证它一定在本方回合的收尾里跑到。
		if self_relics.has(POPCORN_RELIC_ID) and _popcorn_quiet:
			popcorn_draw += POPCORN_DRAW
			_log("爆米花：本回合没用技能指向敌人 → 下回合多抽 %d 张（累计 %d）"
					% [POPCORN_DRAW, popcorn_draw])
		# R340 生蛋鸭：存活到回合结束的鸭蛋 → 原地孵成宠物鸭（与罐子同一段收尾，先于弃手牌）
		_egg_hatch_tick()
		_jar_tick()
		_paralysis_tick()   # R373 麻痹：回合结束仍在手卡 → 消失（排在弃手牌之前）
		# R314 储物箱（6044）：持有 → 回合结束**不弃手牌**（keep_all）。
		# 日志分开写：读者要能一眼看出「这次一张都没弃，是因为道具」。
		var chest_keep:= self_relics.has(STORAGE_RELIC_ID)
		var n:= state.discard_hand(chest_keep)
		if chest_keep:
			_log("储物箱：回合结束不弃手牌（保留 %d 张）" % state.hand.size())
		else:
			_log("回合结束：弃掉 %d 张手牌" % n)
		# 使魔之夜的乌鸦只在给的那一回合免费 → 回合结束清掉免费名单
		if not state.turn_free.is_empty():
			state.turn_free.clear()
		# 魔像术（9079）的本回合手卡减费同样只在当回合有效
		if not state.turn_card_discount.is_empty():
			state.turn_card_discount.clear()
		# R276：随心组装 9144「变化出的盟友卡本回合 -1」同样只在当回合有效
		if not state.hand_cost_turn.is_empty():
			state.hand_cost_turn.clear()
		# 契约签订者（8024）的本回合手卡涨价同样只在当回合有效
		state.turn_card_raise = 0
		# 回转（9089）抽到的牌只在抽到的那个回合免弃
		if not state.turn_keep.is_empty():
			state.turn_keep.clear()
		# 夜行（9155，R232）：本回合免费用 / 出牌上限都只在本回合有效
		state.turn_all_free = false
		state.turn_cannon_free = false   # R271 代达罗斯：本回合手卡炮击 0 费，回合结束失效
		state.card_play_cap = 0


		_rice_used = false
		turn_spell_bonus = 0
		# R316 极速：敌人易伤也是「本回合」限定 —— 与我方其它一次性 buff 一起清。
		_rapid_enemy_bonus = 0
		# R317 身法：出牌限制同样只到本回合结束。
		_no_unit_play_this_turn = false
	else:
		state.opp_hand_count = 0


	# 活力转移 / 地狱猫 / 鲜血堡垒（R55）：**费用清零之前**结算本回合没用完的剩余费用。
	_end_turn_surplus(current_side)

	if current_side == SIDE_SELF:
		state.energy = 0
	else:
		state.opp_energy = 0
	var nxt:= SIDE_OPPONENT if current_side == SIDE_SELF else SIDE_SELF
	_begin_turn(nxt)


func battle_end_rewards() -> Dictionary:
	## R351：战斗结束后由**效果卡**给出的额外收益。
	##   月亮 9180 → 奖励界面多一条「从卡组删除一张卡」；
	##   硬币 9181 → 额外获得 `value` 金币（R390 起卡面写 40，费用 2）。
	## 返回 {"moon": bool, "coin": int}（没打出就是 {"moon": false, "coin": 0}）。
	## ⚠️ 不叠加：效果区里有多张同名也按**一张**算 —— 与自愈（9065）同一口径。
	var m := false
	var coin := 0
	for c: CardData in state.effects:
		if c == null:
			continue
		if c.id == MOON_CARD_ID:
			m = true
		elif c.id == COIN_CARD_ID:
			coin = maxi(coin, maxi(1, c.value))
	return {"moon": m, "coin": coin}


func battle_end_heal() -> int:


	var amount:= 0
	# 自愈（9065）：**不叠加** —— 效果区无论有几张，都只按一张结算。
	var heal_val:= 0
	for c: CardData in state.effects:
		if c.traits.has(SELF_HEAL_TRAIT):
			heal_val = maxi(heal_val, maxi(1, c.value))
	amount += heal_val
	var peach:= PEACH_BATTLE_HEAL if self_relics.has(PEACH_RELIC_ID) else 0
	amount += peach   # 黄桃罐头：每次战斗结束回复 4 点生命
	if amount <= 0:
		return 0
	var before:= state.hp_self
	state.hp_self = mini(state.max_hp_self, state.hp_self + amount)
	var healed:= state.hp_self - before
	_log("战斗结束结算：回复 %d 点生命（%d → %d）" % [healed, before, state.hp_self])
	action.emit("self_heal", {"healed": healed, "hp": state.hp_self, "peach": peach})
	return healed


func effect_counter(c: CardData) -> int:


	if c == null:
		return -1
	if c.traits.has(STONESKIN_TRAIT):
		return _stoneskin_left
	return -1


func can_pay(cost: int, side:= SIDE_SELF) -> bool:


	if side == SIDE_SELF:
		cost = maxi(0, cost - state.self_cost_reduction)
	return state.energy_of(side) >= cost


func cost_of(card: CardData, side:= SIDE_SELF) -> int:



	# 夜行（9155，R232）：本回合我方所有卡费用为 0 —— 放在最前，X 费卡与「最低 N 费」也一并免费。
	if side == SIDE_SELF and state.turn_all_free:
		return 0
	# X 费卡（流星雨 9083）：费用 = 该方当前剩余的**全部费用**（显示=判定=实扣 都读这里）。
	if card != null and card.x_cost:
		return maxi(0, state.energy_of(side))
	# 使魔之夜的乌鸦：只在本回合免费（回合结束 turn_free 清空 → 恢复原价）
	if state.turn_free.has(card):
		return _cost_floor(card, 0)
	# 「在手牌里期间免费」（R89 无限装甲 8038 供能的改造牌）：
	# ⚠️ 判据是**这张卡此刻还在不在手牌里**，不是回合 —— 所以打出 / 弃掉后自动恢复原价，
	# 不需要在那 10 处离手口逐个清标记。放在 X 费判定**之后**：X 费卡费用由剩余费用决定，
	# 已经是 0 了不需要管；但若一张 X 费卡被标记，它仍按 X 费口径（更符合卡面）。
	if card != null and state.hand_free.has(card) and state.hand.has(card):
		return _cost_floor(card, 0)
	var c:= card.cost
	if side == SIDE_SELF:
		c -= state.self_cost_reduction
		c -= _coord_discount(card)
		c -= _lion_discount(card)
		c -= _dove_discount(card)
		c -= _arcane_charm_discount(card)
		c -= _demon_discount(card)
		c -= _iron_fence_discount(card)
		c -= _sprite_effect_discount(card)
	c -= _quick_strike_discount(card)
	c -= _frenzy_discount(card, side)
	c -= _instance_discount(card, side)
	c -= _turn_instance_discount(card, side)
	c -= _magic_core_discount(card, side)
	c -= _void_lord_discount(card, side)
	# R271：**手卡内减费**（谟涅摩叙涅「随机变化入手 -2」）——
	# 判据 = 这张卡此刻还在手牌里，离手即自动恢复原价（与 hand_free 同一条路）。
	if card != null and state.hand_cost_delta.has(card) and state.hand.has(card):
		c -= int(state.hand_cost_delta[card])
	# R276：**本回合**的手卡内减费（随心组装 9144 变出来的盟友卡 -1）——
	# 与上面同一判据（还在手牌里才生效），区别只在这张表会在 end_turn 被清空。
	if card != null and state.hand_cost_turn.has(card) and state.hand.has(card):
		c -= int(state.hand_cost_turn[card])
	# 契约签订者（8024，R63）：本回合手卡全体**涨价** +N —— 放在所有减费之后，
	# 这样它压得住前面的各种 -1 / -X，且显示 = 判定 = 实扣仍统一走这里。
	if side == SIDE_SELF and card != null and state.turn_card_raise > 0:
		c += state.turn_card_raise
	# R223 难度 5「疲惫」诅咒（9149）：**在手牌里期间**所有技能卡费用 +1。
	# 判据 = 手里有没有诅咒卡（按卡种判、不按 id 硬编码，跟次元/字段一个路子）；
	# 放在契约签订者之后 —— 两者都是涨价，顺序不影响最终值。
	if side == SIDE_SELF and card != null and card.is_spell() and _hand_has_curse():
		c += FATIGUE_COST_RAISE
	# R271 代达罗斯 8060：「本回合，你手卡里的「聚能炮击」费用为 0」——
	# 放在**最后**（压得住契约签订者的涨价，因为卡面写的就是「为 0」）；回合结束清空。
	if side == SIDE_SELF and state.turn_cannon_free and card != null \
			and card.id == ENERGY_CANNON_ID and state.hand.has(card):
		c = 0
	return _cost_floor(card, maxi(0, c))


const FATIGUE_COST_RAISE := 1   ## R223：手牌里有诅咒「疲惫」时，所有技能卡费用 +1
## R231：涨价判据的**卡面 trait**。⚠️ 不能按 `is_curse()` 判 —— 诅咒家族多了
## 「破绽」（9154，2 费打出无效果），它若也触发「技能卡 +1」就等于白送了它一条
## 卡面没写的效果（用户口径只有「打出无效果」）。按 trait 判仍不写死 id：
## 将来要是给「疲惫」换皮，只要留着这个 trait 就照样生效。
const FATIGUE_TRAIT := "疲惫"

func _hand_has_curse() -> bool:
	## 当前手牌里是否有「疲惫」（9149）—— R223 难度 5 的涨价判据。
	for c: CardData in state.hand:
		if c != null and c.traits.has(FATIGUE_TRAIT):
			return true
	return false


func _cost_floor(card: CardData, cost: int) -> int:
	## 个别卡的费用下限（显示 = 判定 = 实扣 都走 cost_of，所以只在这里兜一层）：
	## 回响（9102）「此卡最低 1 费」—— 它使用后回手，没有下限就成了 0 费无限回手。
	if card != null and card.id == ECHO_ID:
		return maxi(cost, ECHO_MIN_COST)
	return cost


func _play_cap_blocked() -> String:
	## 夜行（9155，R232）：本回合我方出牌上限（含夜行本身）。"" = 未达上限。
	if state.card_play_cap > 0 and state.self_card_plays >= state.card_play_cap:
		return "夜行：本回合使用卡牌已达 %d 张上限" % state.card_play_cap
	return ""


func _charge_up_text(v: int) -> String:
	## 蓄势（9156，R232）的卡面文案：始终显示当前伤害 v（随剩余费用成长）。
	return "造成 %d 点伤害。回合结束时，每有 1 点未使用的费用，手卡的此卡伤害 +3（战斗内不重置）。" % v


func _charge_up_grow(left: int) -> void:
	## 蓄势（9156，R232）：回合结束、费用清零之前，手卡里每张「蓄势」按剩余费用涨伤害。
	if left <= 0:
		return
	for c: CardData in state.hand:
		if c.id == CHARGE_UP_ID:
			c.value += left * CHARGE_UP_PER_ENERGY
			c.effect_text = _charge_up_text(c.value)
			_log("蓄势：剩余费用 %d → %s 伤害 +%d（现 %d）" % [
				left, c.card_name, left * CHARGE_UP_PER_ENERGY, c.value])
			action.emit("charge_up", {"card": c, "left": left, "value": c.value})


func can_pay_card(card: CardData, side:= SIDE_SELF) -> bool:
	# X 费卡（流星雨 9083）：**任何时候都能打** —— 0 费用时 X 记 0（R124 用户口径：
	# 「费用为 X 的牌即使当前没有费用也能使用，那个场合 X 当作 0 计算」）。
	# ⚠️ 这里**不再**要求 energy >= 1：要不要空放由玩家自己决定，卡照常离手进弃牌区。
	if card != null and card.x_cost:
		return true
	return state.energy_of(side) >= cost_of(card, side)


func _coord_discount(card: CardData, side:= SIDE_SELF) -> int:
	if card.id != COORD_ATTACK_ID:
		return 0
	return _ally_count(side)


func _instance_discount(card: CardData, side:= SIDE_SELF) -> int:


	if side != SIDE_SELF:
		return 0
	return int(state.card_discount.get(card, 0))


func _turn_instance_discount(card: CardData, side:= SIDE_SELF) -> int:


	## 本回合这张**手卡**的减费（魔像术 9079：每用一张技能 -1；我方回合结束清空）。
	if side != SIDE_SELF:
		return 0
	return int(state.turn_card_discount.get(card, 0))


func _magic_core_discount(card: CardData, side:= SIDE_SELF) -> int:


	## 魔力核心（9076）：每回合使用的**第一张技能卡**费用 -1（效果区多张本卡不叠加）。
	if side != SIDE_SELF or not card.is_spell():
		return 0
	if state.self_skill_plays > 0:
		return 0
	if _trait_copies(state.effects, MAGIC_CORE_TRAIT) <= 0:
		return 0
	return MAGIC_CORE_DISCOUNT


func _magic_tower_bonus(side: String, card: CardData) -> int:


	## 魔法塔（9075）：该方场上每有一座塔，伤害类技能的「原本费用每 1 点」就 +1 伤。
	## 按 card.cost（原始费用）加成，和鸭之眼 6009 同理 —— 临时减费不会把加成吃掉。
	if card == null:
		return 0
	var towers:= 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(MAGIC_TOWER_TRAIT):
			towers += 1
	if towers <= 0:
		return 0
	return towers * maxi(0, card.cost)


func _void_lord_presence(side: String) -> int:
	## 风元素（9082）：该方场上有几张本卡。
	var n:= 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(VOID_LORD_TRAIT):
			n += 1
	return n


func _void_lord_owned(side:= SIDE_SELF) -> bool:
	## 该方**拥有**风元素（场上 / 手卡 / 牌库 / 弃牌区任意一处有本卡）。
	## 用于把「对敌伤害计数」限定在真的持有本卡的一方。
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(VOID_LORD_TRAIT):
			return true
	for zone: Array[CardData] in [state.hand, state.deck, state.discard]:
		for c: CardData in zone:
			if c.id == VOID_LORD_ID:
				return true
	return false


func _void_lord_discount(card: CardData, side:= SIDE_SELF) -> int:
	## 风元素（9082）的两条费用机制：
	## ① 只要这张卡在场，该方的技能牌费用 -1（多张叠加：按场上本卡张数算）；
	## ② 本次对战中每用技能牌对敌方造成一次伤害，手卡里的本卡费用 -2（战斗内累计）。
	var d:= 0
	if card.is_spell():
		d += _void_lord_presence(side) * VOID_LORD_PRESENCE_DISCOUNT
	if card.id == VOID_LORD_ID:
		d += state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT
	return d


func _mark_spell_enemy_hit() -> void :
	## 风元素（9082）伤害计数：只有在**技能结算窗口内**、且伤害落在**敌方**身上时才记一笔。
	## 调用点 = 三个伤害下沉处（_hit_unit / _damage_player / _op_deal_damage）。
	if _spell_active:
		_spell_hit_enemy = true


func _arcane_charm_discount(card: CardData, side:= SIDE_SELF) -> int:


	if side != SIDE_SELF or not self_relics.has(ARCANE_CHARM_RELIC_ID):
		return 0
	if not card.is_effect() or state.self_effect_plays > 0:
		return 0
	return ARCANE_CHARM_DISCOUNT


func _demon_discount(card: CardData) -> int:
	if card.id != AETHER_DEMON_ID:
		return 0
	return state.effects.size()


func _iron_fence_discount(card: CardData) -> int:


	if card.id != IRON_FENCE_SPELL_ID:
		return 0
	return state.self_effect_plays


func _sprite_effect_discount(card: CardData) -> int:
	if not card.is_effect():
		return 0
	return state.self_next_effect_reduction


func _ally_count(side: String) -> int:
	var n:= 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.kind == "盟友":
			n += 1
	return n


func _lion_discount(card: CardData) -> int:
	if card.id != LION_ID:
		return 0
	var n:= 0
	for c: CardData in state.discard:
		if c.kind == "盟友":
			n += 1
	return n


func _quick_strike_discount(card: CardData) -> int:
	if card.kind != "盟友":
		return 0
	return state.self_ally_cost_reduction


func _dove_discount(card: CardData) -> int:
	if card.kind != "盟友":
		return 0
	return state.self_next_ally_reduction


func _frenzy_discount(card: CardData, side:= SIDE_SELF) -> int:
	if card.id != FRENZY_ID:
		return 0
	return FRENZY_DISCOUNT if _ally_count(side) >= FRENZY_ALLY_MIN else 0


func _nature_force(side: String) -> String:


	var n:= NATURE_FORCE_BASE + _ally_count(side)
	if side == SIDE_SELF:
		state.energy += n
	else:
		state.opp_energy += n
	_log("自然之力：回复 %d 点费用（1 + %d 盟友）" % [n, n - NATURE_FORCE_BASE])
	return "回复 %d 点费用" % n


func _tenacity(side: String) -> String:



	var n:= 0
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == side and p.card.kind == "盟友":
			p.health += TENACITY_HP
			n += 1
	var who:= "己方" if side == SIDE_SELF else "对方"
	_log("%s坚韧：%d 个盟友生命 +%d" % [who, n, TENACITY_HP])
	return "%d 个己方盟友生命 +%d" % [n, TENACITY_HP]


func _dragon_breath_spell(side: String, target, card: CardData) -> String:


	var p:= _target_placement(side, target)
	if p == null or p.owner == side:
		return "（需要指定一个敌方单位）"
	if p.card.traits.has(SPELL_IMMUNE_TRAIT):
		_log("%s 免疫法术，未受到伤害" % p.card.card_name)
		return "%s 免疫法术" % p.card.card_name
	var hit:= _spell_dmg(side, DRAGON_BREATH_DMG, card)
	var tname:= p.card.card_name
	var total:= 0
	var hits:= 0
	for i in DRAGON_BREATH_HITS:
		if p.health <= 0:
			break
		total += _hit_unit(p, hit, "龙息")
		hits += 1
	if p.health <= 0:
		_destroy_dead()
	_log("龙息：对 %s 造成 %d 点伤害（%d 次 × %d）" % [tname, total, hits, hit])
	return "%s -%d（%d 次）" % [tname, total, hits]


func _meteor_shower(side: String, card: CardData) -> String:


	## 流星雨（9083）：对随机敌人造成 METEOR_SHOWER_DMG 点伤害，重复 X 次
	## （X = 施放时消耗的全部费用，见 use_spell）。每次**独立**随机选目标。
	## 场上没有敌方单位时改为直击敌方 HP（与疾风之力同处理）；
	## 命中带「法术免疫」的单位 → 那一颗被拦下（与龙息同一判据）。
	var times:= maxi(0, _x_spell_value)
	if times <= 0:
		# R124：0 费用施放是**合法**的（X 记 0），不是出错 —— 文案据实描述即可。
		return "流星雨：X = 0（没有费用），一颗流星都没落下"
	var hit:= _spell_dmg(side, METEOR_SHOWER_DMG, card)
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var total:= 0
	var falls:= 0
	var blocked:= 0
	for i in times:
		var pool: Array[Vector2i] = []
		for c: Vector2i in state.board:
			if state.board[c].owner == foe:
				pool.append(c)
		pool.sort()
		if pool.is_empty():
			# 场上没有敌方单位：这一颗改为直击敌方 HP
			_damage_player(foe, hit, "流星雨")
			total += hit
			falls += 1
			var hp_row:= 0 if foe == SIDE_OPPONENT else FieldState.BOARD_ROWS - 1
			action.emit("meteor", {"cell": Vector2i(hp_row, FieldState.BOARD_COLS / 2),
					"dmg": hit, "card": card})
			continue
		var t: Vector2i = pool[rng.randi() % pool.size()]
		var q: Placement = state.unit_at(t)
		if q.card.traits.has(SPELL_IMMUNE_TRAIT):
			blocked += 1
			_log("流星雨第 %d 颗：%s 免疫法术，这一颗被拦下" % [i + 1, q.card.card_name])
			continue
		var dealt:= _hit_unit(q, hit, "流星雨")
		total += dealt
		falls += 1
		_log("流星雨第 %d 颗：命中 %s -%d（剩余 %d）" % [
			i + 1, q.card.card_name, dealt, maxi(0, q.health)])
		action.emit("meteor", {"cell": t, "dmg": dealt, "card": card})
		if q.health <= 0:
			_destroy_dead()
	var msg:= "流星雨落下 %d 颗，共造成 %d 点伤害" % [falls, total]
	if blocked > 0:
		msg += "（%d 颗被法术免疫拦下）" % blocked
	_log(msg)
	return msg


func _fire_wall_spell(side: String, target, card: CardData) -> String:


	## 火墙术（9084，R247 起不分敌我）：对一横行的**所有单位**（含施放方自己人）造成
	## FIRE_WALL_DMG 点伤害，并让该行燃烧到施放方的下次回合开始 —— 期间任何单位
	## （不分敌我）移动经过该行 → 再挨 FIRE_WALL_PASS_DMG 点（见 _fire_wall_pass）。
	## 同一个单位从这面火墙上累计最多 `cap` 点（即时 + 经过合计），
	## cap = FIRE_WALL_CAP + 这张卡的实际即时伤害增量（R387，附魔加伤会一起抬高）。
	if not (target is Vector2i):
		return "（需要指定一条横行）"
	var row: int = (target as Vector2i).x
	if row < 0 or row >= FieldState.BOARD_ROWS:
		return "（横行不存在）"
	var dmg:= _spell_dmg(side, FIRE_WALL_DMG, card)
	var pass_dmg:= _spell_dmg(side, FIRE_WALL_PASS_DMG, card)
	# R387：**同一单位上限跟着纸面伤害走** —— 卡面写「最多受到 15 点」，那个 15 就是
	# 这次即时伤害的纸面值。附魔 / 鸭之眼 / 荧光草 … 每多 1 点伤害上限也 +1，
	# 「即时 + 经过」的总量关系保持不变。上限按**这一面火墙**记账（rec["cap"]），
	# 两面火墙各算各的；经过判定见 `_fire_wall_pass()`。
	var cap: int = FIRE_WALL_CAP + maxi(0, dmg - FIRE_WALL_DMG)
	var rec:= {"side": side, "row": row, "pass_dmg": pass_dmg, "cap": cap,
			"dealt": {}}
	var map: Dictionary = rec["dealt"]
	var hits:= 0
	var total:= 0
	var blocked:= 0
	_begin_hp_once()
	for col in FieldState.BOARD_COLS:
		var c:= Vector2i(row, col)
		var p: Placement = state.unit_at(c)
		if p == null:
			continue   # R247：不分敌我 —— 自己人站着一样烧
		if p.card.traits.has(SPELL_IMMUNE_TRAIT):
			blocked += 1
			_log("火墙术：%s 免疫法术，未被点燃" % p.card.card_name)
			continue
		var dealt:= _hit_unit(p, dmg, "火墙")
		map[p] = dealt
		total += dealt
		hits += 1
		action.emit("fire_wall_hit", {"cell": c, "dmg": dealt, "card": card})
	_fire_walls.append(rec)
	action.emit("fire_wall", {"row": row, "side": side, "card": card,
			"dmg": dmg, "pass_dmg": pass_dmg, "cap": cap})
	if hits > 0:
		_destroy_dead()
	_end_hp_once()
	_log("火墙术：第 %d 行燃起（%d 个单位共 -%d，不分敌我；经过者 -%d，同一单位上限 %d）" % [
			row, hits, total, pass_dmg, cap])
	var msg:= "第 %d 行火墙：%d 个单位 -%d（不分敌我）" % [row, hits, dmg]
	if blocked > 0:
		msg += "，%d 个免疫" % blocked
	return msg


func _fire_wall_pass(path: Array[Vector2i]) -> void :


	## 单位移动结束后的火墙判定（**不分敌我**）：path 是 BFS 路径（含起点与终点），
	## 只要路径上「进入过」某条燃烧的横行（起点不算，那是站着不是经过）→ 挨一次灼烧。
	## 同一个单位从同一面火墙上累计最多 rec["cap"] 点（全卡合计上限，R387 起随纸面伤害提升）。
	if _fire_walls.is_empty() or path.size() < 2:
		return
	var p: Placement = state.unit_at(path[path.size() - 1])
	if p == null:
		return
	if p.card.traits.has(SPELL_IMMUNE_TRAIT):
		return
	for rec in _fire_walls:
		var row: int = int(rec["row"])
		var crossed:= false
		for i in range(1, path.size()):
			if int(path[i].x) == row:
				crossed = true
				break
		if not crossed:
			continue
		var map: Dictionary = rec["dealt"]
		# R387：上限按**这一面火墙**算（rec["cap"]）；旧录像 / 旧数据没有这个键时
		# 退回常量，行为与以前一致。
		var cap: int = int(rec.get("cap", FIRE_WALL_CAP))
		var used: int = int(map.get(p, 0))
		var left: int = cap - used
		if left <= 0:
			_log("火墙：%s 已吃满 %d 点，本次不再受伤" % [p.card.card_name, cap])
			continue
		var dmg: int = mini(int(rec["pass_dmg"]), left)
		var real:= _hit_unit(p, dmg, "火墙")
		map[p] = used + real
		_log("火墙：%s 穿过第 %d 行 → -%d（这面火墙累计 %d/%d）" % [
				p.card.card_name, row, real, used + real, cap])
		action.emit("fire_wall_pass", {"cell": path[path.size() - 1],
				"dmg": real, "card": p.card})
		if p.health <= 0:
			_destroy_dead()
			return


func _clear_fire_walls(side: String) -> void :
	## 火墙只烧到施放方的下次回合开始（_begin_turn 里调用）。
	var keep: Array = []
	for rec in _fire_walls:
		if String(rec["side"]) != side:
			keep.append(rec)
	_fire_walls = keep


func fire_wall_rows() -> Array[int]:
	## 正在燃烧的横行（UI 画火线用）—— 引擎是唯一数据源，回合开始自动清空。
	var out: Array[int] = []
	for rec in _fire_walls:
		out.append(int(rec["row"]))
	return out


func _frenzy(side: String, target) -> String:



	var p:= _target_placement(side, target)
	if p == null or p.owner != side or p.card.kind != "盟友":
		return "（需要指定一个己方盟友）"
	if p.card.actions >= FRENZY_ACTIONS or p.acts_left >= FRENZY_ACTIONS:
		return "%s 已拥有同类效果（不可重复获得）" % p.card.card_name
	p.acts_left = FRENZY_ACTIONS
	_log("狂暴：%s 本回合可以攻击两次" % p.card.card_name)
	return "%s 本回合可以攻击两次" % p.card.card_name


func _aether_barrier(side: String) -> String:




	if side != SIDE_SELF:
		return "（以太屏障：敌方 AI 不使用这张卡）"
	if _aether_used:
		_log("以太屏障：本回合已有屏障生效，这张不产生效果")
		return "本回合已有一张以太屏障生效（这张无效）"
	_aether_used = true
	_aether_left = maxi(0, state.self_effect_plays)
	_log("以太屏障：本回合前 %d 次受到的伤害变为 1" % _aether_left)
	action.emit("aether", {"left": _aether_left, "plays": state.self_effect_plays})
	return "本回合前 %d 次受到的伤害变为 1" % _aether_left


func _wisdom_surge() -> void :


	var draws:= 0
	for c: CardData in state.effects:
		if c.traits.has(WISDOM_TRAIT):
			draws += maxi(1, c.value)
	if draws <= 0:
		return
	var got:= 0
	for i in draws:
		var card:= state.draw()
		if card == null:
			_log("智慧喷涌：没有抽到卡（牌库已空或手牌已满）")
			break


		var inst:= CardData.from_dict(card.to_dict())
		state.hand.pop_back()
		state.hand.append(inst)
		got += 1
		_log("智慧喷涌：抽到「%s」" % inst.card_name)
		if inst.is_effect():
			state.card_discount[inst] = maxi(1, int(state.card_discount.get(inst, 0)))
			_log("智慧喷涌：「%s」是效果卡 → 这一张费用 -%d" % [
				inst.card_name, state.card_discount[inst]])
	if got > 0:
		action.emit("wisdom", {"count": got})


func _endless_blessing() -> void :



	var copies:= 0
	for c: CardData in state.effects:
		if c.traits.has(BLESSING_TRAIT):
			copies += 1
	if copies <= 0:
		return
	var repo:= CardRepo.load_json()
	var pool: Array[CardData] = []
	# 按角色过滤（R47）：无尽加护给的随机效果卡也只从本角色卡里取
	for c: CardData in repo.reward_pool_for(RunState.player_class):
		if c.is_effect():
			pool.append(c)
	if pool.is_empty():
		_log("无尽加护：没有可以给予的效果卡")
		return
	var given:= 0
	for i in copies:
		var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		var copy:= CardData.from_dict(pick.to_dict())
		# R299：手牌满 → 这张效果卡**直接进弃牌区**（照抽照给，只是不进手）。
		if _grant_to_hand(copy, "无尽加护"):
			given += 1
			_log("无尽加护：随机一张「%s」进入手卡" % copy.card_name)
	if given > 0:
		action.emit("blessing", {"count": given})


func _chicken_pot() -> void :
	var enemies:= _side_cells(SIDE_OPPONENT)
	if enemies.is_empty():
		_log("鸡煲：场上没有敌人，效果落空")
		return
	var cell: Vector2i = enemies[rng.randi() % enemies.size()]
	var p: Placement = state.board[cell]
	_hit_unit(p, 3 + _turn_dmg_bonus(SIDE_SELF), "鸡煲")
	if p.health <= 0:
		_destroy_dead()
	else:
		_check_game_over()


func energy_of(side:= SIDE_SELF) -> int:
	return state.energy_of(side)


func _pay(card: CardData) -> int:
	## 支付并**返回实付点数**（R74：出手被拒时要用它退款，见 _pay_refund）。
	var c:= cost_of(card)
	state.pay_energy(c)
	_log("支付 %d 费用使用 %s" % [c, card.card_name])
	return c


func _pay_refund(amount: int) -> void :
	## 出手被拒时把钱退回去（R74：场地放自己后排放会被拒）。
	## 传**当时实付**的点数，而不是卡 —— 中途 cost_of 可能变化，退多了就是白送费用。
	if amount <= 0:
		return
	state.energy += amount
	_log("放置被拒 → 退还 %d 费用" % amount)


## 场地卡的**生效对象**（R78）—— 决定「这张场地需要谁能走到那一格」。
## 这是场地放置规则的**唯一依据**：能放 ≠ 想放，得看这张场地等的是谁。
##   * FIELD_AIM_ENEMY（陷阱类，等敌人踩）：我方后排永远等不到敌人 → 不能放。
##   * FIELD_AIM_ALLY（只对己方生效，如己方增幅阵地）：我方永远进不了敌方后排
##     → 敌方后排不能放（放那儿我方自己人踩不到，等于白给）。
##   * FIELD_AIM_BOTH（对双方都生效，如不分敌我的领域）：任何一侧都进得去
##     → **没有任何行限制**，全场皆可放。
## 未标注生效对象的老场地卡一律按 FIELD_AIM_ENEMY 处理（现有 6 张全是陷阱）。
const FIELD_AIM_ENEMY:= "敌"
const FIELD_AIM_ALLY:= "友"
const FIELD_AIM_BOTH:= "双"


static func field_place_allowed(cell: Vector2i, aim := FIELD_AIM_ENEMY) -> bool:
	## 场地卡能否放在这一格（R74 起的**唯一判定口**，界面高亮也读它；R78 改为按**生效对象**判定）。
	##
	## **判据 = 「这张场地等的那一方，能不能走到这一格」**。理由：场地是钉在格子上的
	## 一次性效果，放下去如果目标方永远到不了，这张牌就白打了 —— 该禁的是「够不着」，
	## 不是「后排」这个位置本身。所以三种生效对象各有各的限制（R78 修正 R77 的粗暴做法）：
	##   * FIELD_AIM_ENEMY（陷阱：等敌人踩）：敌方的移动禁区是我方后排（row 5）
	##     → **我方后排禁放**。敌方半场 0..4 全允许，那正是陷阱最该埋的地方。
	##   * FIELD_AIM_ALLY（只对己方生效）：我方的移动禁区是敌方后排（row 0）
	##     → **敌方后排禁放**（我方自己进不去，铺给谁看？）。
	##   * FIELD_AIM_BOTH（对双方生效）：两边都进得去 → **无任何行限制**。
	##
	## 刻意**允许**放在已有单位 / 已有场地的格子上 —— 场地不是单位，两套数据互不影响；
	## 同格已有场地时由 set_field 顶掉（对应「每个格子只能存在一个效果」）。
	## **static**：纯函数、不依赖任何实例状态，界面（battle_scene）也要读它，
	## 做成 static 就不用为了高亮而造一个引擎实例。
	if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS \
			or cell.y < 0 or cell.y >= FieldState.BOARD_COLS:
		return false
	# 禁区 = 「目标方的移动禁区」那一行：目标方永远进不去，放这儿就是死格。
	var aim_side: String = SIDE_OPPONENT if aim == FIELD_AIM_ENEMY else SIDE_SELF
	if aim == FIELD_AIM_BOTH:
		return true
	return cell.x != forbidden_row_for(aim_side)


static func field_aim(card: CardData) -> String:
	## 这张场地卡的生效对象（R78）：读 trait「场地生效·敌/友/双」，缺省按「敌」（陷阱）。
	## 卡面数据在 cards.json 的 traits 里 —— 加新场地卡时写这个 trait 就能自动获得正确限制，
	## 不用改引擎。
	if card == null:
		return FIELD_AIM_ENEMY
	for t: String in card.traits:
		if t == "场地生效·敌":
			return FIELD_AIM_ENEMY
		if t == "场地生效·友":
			return FIELD_AIM_ALLY
		if t == "场地生效·双":
			return FIELD_AIM_BOTH
	return FIELD_AIM_ENEMY


static func is_persistent_field(card: CardData) -> bool:
	## **持续型场地**判定（R83）—— 读 trait「持续场地」。
	##
	## 场地卡分两族，走**完全不同的链**：
	##   * **一次性**（现有 6 张陷阱）：`_field_block_index` 拦人 → `_field_trigger` 结算 → 消失；
	##   * **持续型**（清泉 8028）：永不触发、永不消失，只在某一方回合结束时结算一次效果。
	## 所以凡是「按场地一次性结算」的地方（拦路 / 触发）都要先问一句这个，
	## 否则持续型场地会被当成一次性用掉 —— **清泉会被敌人走一次就白费**。
	##
	## **static** + 纯函数：界面也要读（场地高亮），同 `field_place_allowed` 的做法。
	return card != null and card.traits.has(PERSISTENT_FIELD_TRAIT)


static func is_player_only_field(card: CardData) -> bool:
	## **敌方能不能摆这张场地**（R88）—— 读 trait「仅玩家可放置」。
	##
	## 维修间 8036 / 改造工厂 8037 都写了这个 trait：它们只对**自己人**生效，
	## 敌方摆出来等于给自己人叠血/叠攻，玩家完全无感 —— 属于「对敌方没牌可打」的地板。
	## 判据走 cards.json（不是引擎里的 id 白名单），加新场地只要写 trait。
	return card != null and card.traits.has(PLAYER_ONLY_FIELD_TRAIT)


func is_fence_card(card: CardData) -> bool:
	## 【栅栏】类卡：木栅栏 8001 / 铁栅栏 9072（带 FENCE_TRAIT）。
	return card != null and card.traits.has(FENCE_TRAIT)


func fence_merge_allowed(card: CardData) -> bool:
	## 道具「栅栏修复术」（6021）：手里这张必须是栅栏卡，才有「叠栅栏」的资格。
	return self_relics.has(FENCE_REPAIR_RELIC_ID) and is_fence_card(card)


func fence_merge_target(cell: Vector2i, card: CardData) -> bool:
	## 该格是否构成「叠栅栏」：持道具 + 手持栅栏卡 + 该格已有**我方**的栅栏。
	if not fence_merge_allowed(card):
		return false
	var p: Placement = state.unit_at(cell)
	return p != null and p.owner == SIDE_SELF and is_fence_card(p.card)


func _merge_fence(p: Placement, card: CardData) -> void:
	## 两张栅栏合并成一张：生命值相加、特性取并集（效果叠加）。
	## 卡面身份沿用**场上那张**（同一堵墙被加固），绝不改卡库里共享的 CardData 实例。
	## R67：加的血与**新加的特性**都只是「战斗内持续生效」的场上加固 ——
	## 分别记在 `fence_bonus_hp` / `fence_bonus_traits`，单位离场时由
	## `_card_leaving_field` 一并还原（否则木栅栏会被永久「升级」成铁栅栏）。
	var merged:= CardData.from_dict(p.card.to_dict())
	# `CardData.from_dict` 的 traits 是**共享引用**（直接接了字典里那个 Array），
	# 这里必须复制一份再改，否则下面的 append/erase 会连带改掉**卡库**里那张卡的
	# traits —— 场上摆着的那堵墙与卡库共享同一个数组，一处改处处改。
	merged.traits = (p.card.traits as Array).duplicate()
	merged.health = p.card.health + card.health
	for t in card.traits:
		if not merged.traits.has(t):
			merged.traits.append(t)
			# 只记**这张卡原本没有**的特性：卡面本来就有的不能被还原掉。
			# 同名特性重复叠加时也只记一次（第二次已 has()，走不到这里）。
			p.fence_bonus_traits.append(t)
	p.card = merged
	p.fence_bonus_hp += card.health
	p.health += card.health


func _card_leaving_field(p: Placement) -> CardData:
	## **单位离场时带走的那张卡**（R67）—— 唯一口。
	## 栅栏修复术的加血与加特性都是「战斗内持续生效」的场上加固，离场就该还原：
	## 合并后的卡 `health` 含 `fence_bonus_hp`、traits 含 `fence_bonus_traits`，
	## 这里逐项减/删再交出去，于是弃牌区/手牌里那张恢复成原本的卡
	## （下次抽到上场仍是原血、也没有偷来的特性）。
	## 没叠加过（两者都空）→ 原卡直接交出，零拷贝、零行为变化。
	##
	## R82：改造（升级 8027）的 +8 血同理还原（`upgrade_hp`）。
	## ⚠️ **加攻不还原**：它记在 `p.upgrade_atk`（进 `effective_power` 的计算），
	## 根本没烤进 `p.card`，所以交出去的卡天生是原力 —— 与 R67 的加血不同，
	## 这里只需要把 health 减回去。写在这里而不是让调用方各自处理，是为了
	## 「离场还原只有唯一口」这条约定不被绕过。
	if p == null:
		return null
	# R227：生命循环给的「次元 / 死亡」是**场上这段**的字段 —— 回手 / 返修时摘掉，
	# 否则那张卡再上场会带着一个不会触发的「死亡」标记（卡面写着效果却不生效）。
	if p.fence_bonus_hp <= 0 and p.fence_bonus_traits.is_empty() and p.upgrade_hp <= 0 \
			and p.upgrade_range <= 0 and p.upgrade_speed <= 0 \
			and p.life_cycle_added.is_empty() and p.blade_added.is_empty() \
			and p.hidden_energy_added.is_empty():
		return p.card
	var out:= CardData.from_dict(p.card.to_dict())
	out.traits = (p.card.traits as Array).duplicate()   # 同上：必须切断与卡库的共享引用
	# R291：生命循环与辅助刃都是「场上这段」的字段 —— 合成一次 duplicate 再逐个摘，
	# 分两段各 duplicate 一次会让后一段把前一段的删除覆盖掉。
	if not p.life_cycle_added.is_empty() or not p.blade_added.is_empty() \
			or not p.hidden_energy_added.is_empty():
		out.affixes = (p.card.affixes as Array).duplicate()
		for lc_a: String in p.life_cycle_added:
			out.affixes.erase(lc_a)
		for bg_a: String in p.blade_added:
			out.affixes.erase(bg_a)
		for he_a: String in p.hidden_energy_added:
			out.affixes.erase(he_a)
	out.health = maxi(1, p.card.health - p.fence_bonus_hp - p.upgrade_hp)
	for t in p.fence_bonus_traits:
		out.traits.erase(t)
	if p.upgrade_range > 0:
		out.attack_range = maxi(1, p.card.attack_range - p.upgrade_range)
	if p.upgrade_speed > 0:
		out.move_speed = maxi(0, p.card.move_speed - p.upgrade_speed)
	return out


func play_from_hand(hand_index: int, cell: Vector2i) -> Placement:
	var card:= state.hand[hand_index]
	# R317 身法（9173）：引擎侧兜底 —— `can_use_card` 管 UI，这里管「绕过去」的路径
	#（联机回放 / 自动出牌 / 以后新加的效果）。放在 `_pay` 之前：拒绝不扣费。
	if card.unplayable:
		# R373：不能打出的诅咒（麻痹 9185）—— 引擎侧兜底，联机 / 回放 / 自动出牌都挡在这里。
		_log("%s：这张卡不能打出" % card.card_name)
		return null
	if _no_unit_play_this_turn and (card.kind == "盟友" or card.is_fort()):
		_log("身法：本回合不能使用盟友和工事卡（%s 未打出）" % card.card_name)
		return null
	var cap_msg:= _play_cap_blocked()
	if cap_msg != "":
		_log(cap_msg)
		return null
	# R285：**单位落点的引擎侧闸门**。界面（拖拽 / 点选）本来就只让自己半场高亮，
	# 但引擎一直没有判 —— 联机回放、自动出牌、以后新加的效果卡都能把单位塞进对方后排。
	# 放在 `_pay` 之前：拒放不扣费，也就不用走退款。
	if (card.kind == "盟友" or card.is_fort()) and not hand_place_allowed(cell, SIDE_SELF):
		_log("%s 只能放在自己半场（下 3 行）" % card.card_name)
		return null
	var paid:= _pay(card)
	# 栅栏修复术（6021）：把栅栏打到已有栅栏的格子上 → 合并（不新建单位）
	var stack_onto: Placement = state.unit_at(cell)
	if stack_onto != null and fence_merge_target(cell, card):
		state.hand.remove_at(hand_index)
		var was:= stack_onto.health
		_merge_fence(stack_onto, card)
		_log("栅栏修复术：%s 叠到 %s 上 → 生命 %d→%d，特性 %s" % [
				card.card_name, stack_onto.card.card_name, was, stack_onto.health,
				"、".join(stack_onto.card.traits)])
		action.emit("fence_merge", {"cell": cell, "card": stack_onto.card,
				"health": stack_onto.health, "gained": stack_onto.health - was})
		_note_card_played(SIDE_SELF, card)
		return stack_onto
	# 场地卡（R74）：**不是单位** —— 不进board、不占位、不能被打。
	# 直接写到「格子 → 场地效果」那张表（唯一写入口 set_field，每格最多 1 个，
	# 已有场地时新场地**顶掉**旧的）。
	if card.is_field():
		var f_aim := field_aim(card)
		if not field_place_allowed(cell, f_aim):
			_pay_refund(paid)
			_log("场地放不了：%s 是「%s」生效，目标方永远进不去 %s"
				% [card.card_name, f_aim, cell])
			return null
		state.hand.remove_at(hand_index)
		var old_field := state.set_field(card, cell, SIDE_SELF)
		if old_field != null:
			_log("场地覆盖：%s 被新的 %s 顶掉" % [old_field.card_name, card.card_name])
		_log("场地生效：%s 放在 %s（敌人移动经过时触发并停止移动）" % [card.card_name, cell])
		action.emit("field_place", {"cell": cell, "card": card,
			"replaced": old_field != null})
		# R230「清退」：陷阱落在**有敌人的格子**上 → 把那个敌人击退 2 格（朝敌方后排）。
		# 只认陷阱（aim = ENEMY）；清泉 / 维修间这类对己方或双向生效的场地不触发。
		if f_aim == FIELD_AIM_ENEMY and _zone_has(state.effects, CLEAR_OUT_TRAIT):
			var co_occ: Placement = state.unit_at(cell)
			if co_occ != null and co_occ.owner == SIDE_OPPONENT:
				_log("清退：陷阱落在敌人 %s 的格子上 → 击退 %d 格" % [
						co_occ.card.card_name, CLEAR_OUT_STEPS])
				_knockback(SIDE_SELF, cell, CLEAR_OUT_STEPS)
		_note_card_played(SIDE_SELF, card)
		return null
	# 交换（R101）：放在已有己方单位的格子上 → 原单位回手，新卡占据该格
	if card.has_affix(AFFIX_SWAP):
		var occ := state.unit_at(cell)
		if occ != null and occ.owner == SIDE_SELF:
			var back := _card_leaving_field(occ)
			back = CardData.from_dict(back.to_dict())
			back.traits = (back.traits as Array).duplicate()
			state.board.erase(cell)
			if state.hand_full():
				state.discard.append(back)
				_log("交换：%s 被顶回手失败（手牌已满）→ 进弃牌区" % occ.card.card_name)
			else:
				state.hand.append(back)
				_log("交换：%s 返回手卡，%s 占据 %s" % [occ.card.card_name, card.card_name, cell])
			action.emit("swap", {"cell": cell, "old": occ.card, "new": card})

	var p:= state.place(card, cell, SIDE_SELF)
	state.hand.remove_at(hand_index)

	if card.id == DAEDALUS_ID:
		_daedalus_enter(p)          # R271 重做：入场 +3×聚能炮击生命 + 本回合炮击 0 费
	if card.id == CANNON_MECH_ID:
		_cannon_mech_enter(p)       # R271 聚能机兵：入场 +1 力 / 用过的一张炮击
	if card.id == MASS_DAEDALUS_ID:
		_mass_daedalus_enter(p)     # R271 量产型代达罗斯：入场选一张手卡变炮击
	if card.id == MODDER_ID:
		_modder_enter(p)          # R282 改装者：入场全体己方盟友（场上+手牌）改造 +4 生命
	if card.id == OUT_OF_CONTROL_FORT_ID:
		_out_of_control_fort_enter(p)   # R288 失控要塞：每变化过一张牌 → 随机释放一张技能卡（R404）
	if card.id == CLUSTER_TURRET_ID:
		_cluster_turret_enter(p)        # R298 集束炮台：入场往抽牌库塞两张聚能炮击
	if card.id == LIVING_FENCE_ID:
		# R319（用户口径）：活体栅栏改成「入场时抽一张卡」。
		# 走 `_draw_many` 统一口：手牌满时会 burn 进弃牌区并播动画，不会悄悄吞掉。
		var lf_drawn := _draw_many(LIVING_FENCE_DRAW)
		_log("活体栅栏：入场抽 %d 张卡" % lf_drawn)
		action.emit("living_fence", {"drawn": lf_drawn})
	if card.id == PAINT_BOT_ID:
		_paint_bot_enter(p)         # R404 涂装机器人：选场上其他一个友方单位 → 随机机械之心单位
	_refresh_mnemosyne()            # R271：刚落地 / 刚被换上场的那只可能是谟涅摩叙涅

	if card.id == FOX_ID:
		_fox_trigger()

	# R372 竖琴 / R383 骑士剑 / 野兽之心：三条道具加成走**唯一口**——
	# 涂装机器人 8080「变成」出来的单位也要吃，否则同一张盟友卡两条来路两种力量。
	_relic_on_enter_buffs(p)

	if card.id == LION_ID:
		_lion_roar(p)

	if card.id == HOUND_ID:
		_hound_snapshot(p)

	if card.id == CROW_ID:
		crow_trigger()

	if card.id == RAT_ID:
		_rat_trigger()

	if card.id == SHADOW_CAT_ID:
		_shadow_cat_trigger()
	if card.id == SHADOW_DEMON_ID:
		_shadow_demon_enter(p)

	if card.id == AETHER_GUARD_ID:
		_aether_guard_enter(p)

	if card.id == AETHER_DEMON_ID:
		_demon_fetch(p)

	if card.id == OWL_ID:
		_owl_fetch()

	if card.id == SPRITE_ID:
		_sprite_trigger()

	if card.id == APPRENTICE_ID:
		_apprentice_fetch()



	if card.kind == "盟友":
		state.self_next_ally_reduction = 0
		if card.id == CONTRACTOR_ID or card.traits.has(CONTRACTOR_TRAIT):
			_contractor_enter(p)
	if card.id == TURTLE_DOVE_ID:
		_dove_trigger()

	if card.id == CHIMERA_ID:
		_chimera_fuse(p)

	if card.traits.has(CLONE_TRAIT) or card.has_affix(AFFIX_PHANTOM):
		# 【字段「幻影」R91】**使用后**手牌增加一张自己的复制。
		# 判据 = 「带幻影字段」或「带自我复制 trait」（旧字段，保留兼容）——
		# 这就是字段系统的意义：**别的卡只要带上这个字段就自动获得复制能力**，
		# 引擎与文案都不用再改（野兔 9032 是卡面自带的「幻影」）。
		#
		# 挂在「已离手、已上场」之后：幻影是「本场战斗内的衍生物」，
		# 不能进牌库 / 弃牌区（否则会被洗回牌库无限刷），
		# 寿命由 `CardData.is_ephemeral` 的两段规则管（手牌回合结束 / 场上离场）。
		# ⚠️ 幻影**保留**幻影字段 → 打出它会再次触发本分支（用户口径：还能再复制）。
		_spawn_self_clone(card)

	if self_relics.has(6008) and not _unit_played_this_turn:
		_unit_played_this_turn = true
		p.health += 2
		_log("鸭绒：本回合第一个单位 %s 生命 +2（%d）" % [card.card_name, p.health])
	_log("%s 上场" % card.card_name)
	action.emit("place", {"cell": cell, "card": card, "side": SIDE_SELF})
	_on_ally_entered(p, SIDE_SELF)
	_note_card_played(SIDE_SELF, card)
	return p


func _daedalus_enter(p: Placement) -> void :
	## 「代达罗斯」8060（**R271 重做**，R330 调为机械之心 4 费史诗盟友 5/16/1/1，嘲讽）：
	##   ① 入场时：本次对战中你**每使用过一张「聚能炮击」** → 这张卡生命 +3；
	##   ② 本回合：你手卡里的「聚能炮击」费用为 0。
	## ⚠️ 加血记 `upgrade_hp`（**不**加 `upgrade_stacks` —— 这是入场成长，不是「改造」）：
	##    `_card_leaving_field()` 靠 `upgrade_hp` 把它减回去，否则这张卡被击破 / 回手后
	##    会带着多出来的血量再打一次，直接滚成雪球。
	var n := state.self_cannon_plays
	var gain := n * DAEDALUS_HP_PER_CANNON
	if gain > 0:
		p.upgrade_hp += gain
		p.card.health += gain
		p.health += gain
	state.turn_cannon_free = true
	_log("代达罗斯入场：本次对战已用聚能炮击 %d 张 → 生命 +%d（%d/%d）；本回合手卡聚能炮击 0 费"
			% [n, gain, p.health, p.card.health])
	action.emit("daedalus_enter", {"cell": _cell_of(p), "card": p.card,
			"cannons": n, "hp": gain})


func _modder_enter(p: Placement) -> void :
	## 「改装者」（8076，R282，机械之心 3 费**普通**盟友 3/8/1/1）：
	##   入场时：**其他**己方盟友（场上 + 手牌）获得一次「改造」：生命 +4（不含工事）。
	##   ⚠️ R405（用户口径「不应该可以改造自己」）：**它自己不吃这一层** —— 改造者改不了改造者。
	##      场上的自己靠 `q != p` 排除（引用比较，`_cell_of()` 万一取不到也不至于失效）。
	##   * **场上**盟友走 `_field_upgrade_grant()` 唯一口（场上改造离场即消失，与「升级」同口径）；
	##     末尾自动 `_on_unit_upgraded()` → 被改的榴弹击手 +1 攻程、机器鸟抽牌照常触发。
	##   * **手牌**盟友烤进副本（`from_dict` 复制 + 原位替换），生命 +4 并记一层 `upgrade_stacks`
	##     （R209：层数随身带，上场由 `FieldState.place()` 折算成 HP；本场战斗内保留）。
	##   * 只认「盟友」（kind == "盟友"），不认工事（用户原话「盟友」）。
	##   * 改造走唯一口 → 素体 / 战斗骨骼等卡面改造奖励照常生效。
	## ⚠️ 场上盟友改的是 `p.card`（from_dict 副本），手牌同理 —— 都污染不到卡库。
	var field_got := 0
	for cell: Vector2i in state.board:
		var q: Placement = state.board[cell]
		if q != null and q != p and q.owner == SIDE_SELF and q.card.kind == "盟友":
			_field_upgrade_grant(q, 0, MODDER_HP, "改装者")
			field_got += 1
	var hand_got := 0
	var hand_names: Array[String] = []
	for i in state.hand.size():
		var c: CardData = state.hand[i]
		if c.kind != "盟友":
			continue
		var up := CardData.from_dict(c.to_dict())
		up.traits = (up.traits as Array).duplicate()
		var mh: int = _upgrade_hp_gain(up, MODDER_HP)
		up.health += mh
		up.upgrade_stacks += 1        # R209：层数随身带（上场由 place() 接到 Placement）
		state.hand[i] = up
		hand_got += 1
		hand_names.append("%s %d血" % [c.card_name, up.health])
	_log("改装者：场上 %d 个盟友 / 手牌 %d 个盟友各获得改造（生命 +%d）" % [field_got, hand_got, MODDER_HP])
	action.emit("modder_enter", {"field": field_got, "hand": hand_got, "hp": MODDER_HP})
	_inspire_tick()   # R300 激发：改装者入场一次改全体 → 只算一次

func _cannon_mech_enter(p: Placement) -> void :
	## 「聚能机兵」8073（R271，2 费普通盟友 1/8/1/1）：入场时，本次对战中你每使用过
	## 一张「聚能炮击」→ 自身力量 +1。
	## 加攻记 `upgrade_atk`（进 `effective_power`、离场不带走）—— 与嵌合暴君的吸收同口径。
	var n := state.self_cannon_plays
	var gain := n * CANNON_MECH_ATK_PER
	if gain <= 0:
		_log("聚能机兵入场：本次对战还没用过聚能炮击 → 力量不变（%d 攻）" % p.effective_power())
		return
	p.upgrade_atk += gain
	_log("聚能机兵入场：本次对战已用聚能炮击 %d 张 → 力量 +%d（→%d 攻）"
			% [n, gain, p.effective_power()])
	action.emit("cannon_mech", {"cell": _cell_of(p), "card": p.card,
			"cannons": n, "atk": gain})


func _out_of_control_fort_enter(p: Placement) -> void :
	## 「失控要塞」9161（R288 实装 / R404 改口径；机械之心 2 费**史诗工事** 0 攻 / 1 血 / 不可移动）
	## 的入场效果：本次对战中你**每变化过一张牌** → **随机释放一张机械之心技能卡**。
	##   * 计数来源 = `state.self_card_changes`，唯一记账口 `_note_card_changed()`
	##     （手牌变化 → `_transform_hand_card()`；卡组变化 → 惊喜运单 8079 / 库存整理 9184）；
	##   * 一张都没变化过 → 什么都不发生（0 攻 1 血、不能动的白板工事）；
	##   * 上限 `OUT_OF_CONTROL_MAX_CASTS` 只是防呆（一局变化 20 张已不现实）。
	##   ⚠️ 不再是「用过几张聚能炮击」—— 那个计数（`self_cannon_plays`）仍归
	##      代达罗斯 8060 / 聚能机兵 8073 用，别混。
	fort_casts.clear()
	var n := mini(state.self_card_changes, OUT_OF_CONTROL_MAX_CASTS)
	if n <= 0:
		_log("失控要塞入场：本次对战还没变化过任何牌 → 没有技能可释放")
		var none_casts: Array[String] = []
		action.emit("out_of_control_fort", {"cell": _cell_of(p), "card": p.card,
				"changes": 0, "casts": none_casts})
		return
	for i in n:
		var nm := _fort_cast_one()
		if nm == "":
			_log("失控要塞：第 %d 张触发找不到可执行的技能（池子试过一圈）→ 提前停止" % (i + 1))
			break
		fort_casts.append(nm)
	var names := ""
	for nm2: String in fort_casts:
		names = nm2 if names == "" else "%s, %s" % [names, nm2]
	_log("失控要塞入场：本次对战已变化 %d 张牌 → 实际释放 %d 张技能（%s）"
			% [state.self_card_changes, fort_casts.size(), names])
	action.emit("out_of_control_fort", {"cell": _cell_of(p), "card": p.card,
			"changes": n, "casts": fort_casts.duplicate()})


func _fort_skill_pool() -> Array[CardData]:
	## 「失控要塞」9161 的随机池 = **本职业技能卡**：kind == "技能" + 当前职业 + rarity <= 2
	## （排除初始 3 / 怪物 4 / 事件 5 / 诅咒 6 —— 与奖励池同口径）。
	## ⚠️ 不写死卡 id：以后机械之心新加的技能卡自动进池。
	var out: Array[CardData] = []
	var repo := CardRepo.load_json()
	if repo == null:
		return out
	for c: CardData in repo.all_cards():
		if c.card_class != PlayerClass.MECH or c.kind != "技能":
			continue
		if c.rarity > 2:
			continue
		out.append(c)
	return out


func _fort_cast_one() -> String:
	## 随机抽一张职业技能卡并**立即释放**（失控要塞的一次触发）。
	## 返回实际释放的卡名；"" = 池里此刻没有能执行的技能了。
	## ⚠️ 抽签必须走引擎 `rng`（**不能**用 `Array.shuffle()`）—— 否则录像回放会漂。
	var pool := _fort_skill_pool()
	if pool.is_empty():
		return ""
	var idxs: Array[int] = []
	for k in pool.size():
		idxs.append(k)
	while not idxs.is_empty():
		var pick := rng.randi() % idxs.size()
		var proto: CardData = pool[idxs[pick]]
		idxs.remove_at(pick)
		var card := CardData.from_dict(proto.to_dict())
		card.traits = (card.traits as Array).duplicate()
		card.affixes = (card.affixes as Array).duplicate()
		if _fort_play(card):
			return card.card_name
	return ""


func _fort_play(card: CardData) -> bool:
	## 把一张**凭空生成**的技能卡真正释放掉（失控要塞 9161 的唯一结算口）。
	## 流程：临时塞进手牌末尾 → 按类型挑**随机合法目标** → 走对应正常入口（免费）。
	## 成功判据 = `state.self_card_plays` 涨了（所有出牌路径的统一收尾都是
	## `_note_card_played`，不另设标志位）。
	## ⚠️ 无论成败都把临时卡清掉：它不属于玩家，也不该留在手牌里。
	if card == null or not card.is_spell():
		return false
	state.hand.append(card)
	var hi := state.hand.size() - 1
	var plays_before := state.self_card_plays
	match card.id:
		SYS_UPGRADE_ID:
			var su_i := _fort_hand_target(card, hi)
			if su_i >= 0:
				cast_sys_upgrade(hi, su_i, true)
		HAND_LIGHTEN_ID:
			var hl_i := _fort_hand_target(card, hi)
			if hl_i >= 0:
				cast_lighten(hi, hl_i, true)
		RECYCLE_ID:
			var rc_i := _fort_hand_target(card, hi)
			if rc_i >= 0:
				cast_recycle(hi, rc_i, true)
		RELOAD_ID:
			var rl_i := _fort_hand_target(card, hi)
			if rl_i >= 0:
				cast_reload(hi, rl_i, true)
		SWAP_UNITS_ID:
			var sp := _fort_swap_pair()
			if not sp.is_empty():
				cast_swap_units(hi, sp[0], sp[1], true)
		OVERHAUL_ID:
			# 返修 9127：单段入口结算时置 pending → 这里立刻替玩家从弃牌区随机选一张。
			if not overhaul_options().is_empty() and not state.hand_full():
				use_spell(hi, null, true)
				var oh_now := overhaul_options()
				if overhaul_pending and not oh_now.is_empty():
					overhaul_recall(oh_now[rng.randi() % oh_now.size()])
		_:
			# 其余技能：`unit` 类走随机棋盘目标，无目标的直接施放。
			# ⚠️ `needs_target()` **不含** hand_unit / hand_any（那几类在上面逐个处理），
			#    这里再兜一次：没有合法目标就不打，避免白掉一张。
			var tg = null
			if card.needs_target():
				var cells := _fort_board_targets(card)
				if not cells.is_empty():
					tg = cells[rng.randi() % cells.size()]
			if not card.needs_target() or tg != null:
				use_spell(hi, tg, true)
	var ok := state.self_card_plays > plays_before
	# 清理：正常路径结算完卡已不在手牌；失败 / 落空时把临时卡直接丢掉（不进弃牌区）。
	while state.hand.has(card):
		state.hand.erase(card)
	# 有些技能会顺手置 pending（返修一族）—— 失控要塞不留交互给玩家，一律就地收掉，
	# 否则 `use_spell` 开头的 pending 闸门会让玩家这一回合再也打不出技能牌。
	if overhaul_pending:
		overhaul_remaining = 0
		overhaul_pending = false
	if ok:
		_log("失控要塞：随机释放「%s」" % card.card_name)
	return ok


func _fort_hand_target(card: CardData, own_index: int) -> int:
	## 给「目标在手牌里」的技能（系统升级 / 轻量化 / 回收 / 填充）挑一张**随机合法**手牌。
	## 排除刚塞进来占位的那张临时卡自己；没有候选 → -1（这个技能此刻打不出去）。
	var cand: Array[int] = []
	for i in state.hand.size():
		if i == own_index:
			continue
		var c: CardData = state.hand[i]
		if card.id == HAND_LIGHTEN_ID and c.kind != "盟友":
			continue
		if card.id == SYS_UPGRADE_ID and c.kind != "盟友" and not c.is_fort():
			continue
		cand.append(i)
	if cand.is_empty():
		return -1
	return cand[rng.randi() % cand.size()]


func _paint_bot_enter(p: Placement) -> void :
	## 「涂装机器人」8080（R404）的入场效果：请玩家选一个**其他**己方单位把它变掉。
	## 场上没有别的己方单位 → 直接落空：**不挂 pending**，否则玩家会卡在一个没得点的状态里
	## （与 `_start_cannonize()` 手牌为空时同样处理）。
	paint_src = _cell_of(p)
	# ⚠️ 先挂 pending 再问候选：`paint_options()` 开头有 `if not paint_pending: return []`
	# 的守卫（它是给界面每帧调用的只读口），顺序反了会永远拿到空数组 → 效果恒落空。
	paint_pending = true
	if paint_src == Vector2i(-1, -1) or paint_options().is_empty():
		paint_pending = false
		paint_src = Vector2i(-1, -1)
		_log("涂装机器人入场：场上没有其他友方单位 → 效果落空")
		action.emit("paint_bot", {"cell": _cell_of(p), "card": p.card,
				"old": null, "new": null, "pending": false})
		return
	_log("涂装机器人入场：待选一个友方单位变成随机机械之心单位")
	action.emit("paint_bot", {"cell": paint_src, "card": p.card, "pending": true})


func paint_options() -> Array[Vector2i] :
	## 候选 = 场上**除自己以外**的己方单位（盟友 / 工事都算）；空数组 = 没有待办。
	## 卡面写的是「其他一个友方单位」→ 自己那格必须排除，否则玩家能把它自己变掉
	## （那只会在原地刷出一张随机卡，效果等于免费重抽）。
	if not paint_pending:
		return []
	var out: Array[Vector2i] = []
	for c: Vector2i in _side_cells(SIDE_SELF):
		if c == paint_src:
			continue
		var u: Placement = state.unit_at(c)
		if u != null and u.owner == SIDE_SELF:
			out.append(c)
	out.sort()
	return out


func paint_cancel() -> void :
	## 取消选择（右键 / Esc）：效果作废，**不**补抽、**不**改选。
	if not paint_pending:
		return
	paint_pending = false
	paint_src = Vector2i(-1, -1)
	_log("涂装机器人：取消选择 → 效果落空")


func paint_pick(cell: Vector2i) -> bool :
	## 确认一格：把它变成随机机械之心单位（池见 `_paint_pool()`）。
	if not paint_pending:
		return false
	if not paint_options().has(cell):
		return false
	paint_pending = false
	paint_src = Vector2i(-1, -1)
	return _paint_morph(cell)


func _paint_pool() -> Array[CardData] :
	## 涂装机器人的随机池 = **本职业奖励池里的单位卡**：kind 盟友 / 工事 + 机械之心 + rarity <= 2
	## （排除初始 3 / 怪物 4 / 事件 5 / 诅咒 6 —— 与奖励池、`_fort_skill_pool()` 同口径）。
	## ⚠️ 不写死卡 id：以后机械之心新加的盟友 / 工事自动进池。
	## ⚠️ 池里**含它自己** 8080：变出另一只涂装机器人是合法的，也不会连锁 ——
	##    "变成"不跑入场效果（见常量处口径 ③）。
	var out: Array[CardData] = []
	var repo := CardRepo.load_json()
	if repo == null:
		return out
	for c: CardData in repo.all_cards():
		if c.card_class != PlayerClass.MECH or c.rarity > 2:
			continue
		if c.kind != "盟友" and not c.is_fort():
			continue
		out.append(c)
	return out


func _paint_morph(cell: Vector2i) -> bool :
	## 把场上 `cell` 那个单位**原地变成**一张随机机械之心单位（涂装机器人的唯一结算口）。
	## 三条要点：①「变成」不是「被破坏」→ 直接 `state.board.erase()`，**不**走 `_destroy()`
	##   （亡语 / 击杀记功 / 零件回收者 / 思想钢印一个都不该触发）；
	## ②「变成」也不是「入场」→ 新单位**不跑**入场效果（避免失控要塞 / 量产型代达罗斯嵌套 pending）；
	## ③ 新单位照样吃道具常驻加成（`_relic_on_enter_buffs()`），与手牌打出同一口径。
	var pool := _paint_pool()
	var old: Placement = state.unit_at(cell)
	if old == null or pool.is_empty():
		_log("涂装机器人：没有可变成的单位 → 效果落空")
		return false
	var proto: CardData = pool[rng.randi() % pool.size()]
	var old_card: CardData = old.card
	state.board.erase(cell)
	var copy := CardData.from_dict(proto.to_dict())
	copy.traits = (copy.traits as Array).duplicate()
	copy.affixes = (copy.affixes as Array).duplicate()
	# `summon = true`：本回合 1 次行动（它是"刚出现"的单位，不该继承旧单位的行动数）。
	var np := state.place(copy, cell, SIDE_SELF, true)
	_relic_on_enter_buffs(np)
	_refresh_mnemosyne()          # 变出来的可能是谟涅摩叙涅（光环要立刻生效）
	_log("涂装机器人：%s → 随机机械之心「%s」" % [old_card.card_name, copy.card_name])
	action.emit("paint_bot", {"cell": cell, "old": old_card, "new": copy,
			"old_name": old_card.card_name, "pending": false})
	return true


func _fort_swap_pair() -> Array[Vector2i]:
	## 双向传送 8061 的两个随机单位：都在场上、不免疫位移、换过去不落进对方后排。
	var units: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var u: Placement = state.unit_at(cell)
		if u == null or u.card.traits.has(DISPLACE_IMMUNE_TRAIT):
			continue
		units.append(cell)
	var pairs: Array = []
	for i in units.size():
		for j in range(i + 1, units.size()):
			if swap_pair_allowed(units[i], units[j]):
				pairs.append([units[i], units[j]])
	var out: Array[Vector2i] = []
	if pairs.is_empty():
		return out
	var pr: Array = pairs[rng.randi() % pairs.size()]
	out.append(pr[0])
	out.append(pr[1])
	return out


func _fort_board_targets(card: CardData) -> Array[Vector2i]:
	## 场上目标枚举：只覆盖机械之心技能池里 `target_mode == "unit"` 的那几张。
	## ⚠️ 与 `_autoplay_spell_targets()` 分开写：那个是给鸭语耳环「打手牌里已有的卡」
	##    用的，口径已冻结（改动会让 R285 的断言漂）；这里按技能池重写一份更严格的判据。
	var out: Array[Vector2i] = []
	if card.id == ENERGY_CANNON_ID:
		# 聚能炮击 9145：任意**敌方**单位
		for c in _side_cells(SIDE_OPPONENT):
			if state.unit_at(c) != null:
				out.append(c)
		return out
	if card.id == BLADE_GIFT_ID:
		# 辅助刃 9164（R291）：只吃**己方盟友**（工事不行）。
		for bc: Vector2i in _side_cells(SIDE_SELF):
			var bu: Placement = state.unit_at(bc)
			if bu != null and bu.owner == SIDE_SELF and bu.card.kind == "盟友":
				out.append(bc)
		return out
	if card.id == DUPLICATE_ID:
		# 复制术 9165（R291）：己方盟友或工事。
		for dc: Vector2i in _side_cells(SIDE_SELF):
			var du: Placement = state.unit_at(dc)
			if du != null and du.owner == SIDE_SELF \
					and (du.card.kind == "盟友" or du.card.is_fort()):
				out.append(dc)
		return out
	if card.id == BREAKTHROUGH_ID or card.id == IMPACT_CANNON_ID:
		# 集中突破 9162 / 冲击炮 9163（R290）：与聚能炮击同口径，只打**敌方**单位。
		# ⚠️ 漏了这一支就会落进下面的 `_:` → 返回空池 → 失控要塞抽到它当场白跳。
		for c in _side_cells(SIDE_OPPONENT):
			if state.unit_at(c) != null:
				out.append(c)
		return out
	for c2 in _side_cells(SIDE_SELF):
		var u: Placement = state.unit_at(c2)
		if u == null or u.owner != SIDE_SELF:
			continue
		var ally_like := u.card.kind == "盟友" or u.card.is_fort()
		match card.id:
			SELF_REPAIR_ID, ARMOR_PLATE_ID, SHARED_SHIELD_ID:
				# 8035 / 8044 / 8069：只吃**盟友**（工事不行）
				if u.card.kind != "盟友":
					continue
				if card.id == SHARED_SHIELD_ID and u.card.has_affix(AFFIX_SHARED_SHIELD):
					continue
				out.append(c2)
			UPGRADE_ID, DEMOLISH_ID, TRANSCEND_ID, REORG_ID, REBOOT_ID:
				if ally_like:
					out.append(c2)
			_:
				pass
	return out


func _mass_daedalus_enter(p: Placement) -> void :
	## 「量产型代达罗斯」8074（R271，3 费普通盟友 3/12/1/1）：入场时**选一张手卡**
	## 变成「聚能炮击」（全屏选卡页 kind = "cannonize"）。
	## 「随机变化入手 +2 攻 +2 血」在 `_apply_random_born()` 里、复制那一刻就烤进数值了，
	## 入场这里不再处理 —— 否则随机出来的那张会重复加一遍。
	_start_cannonize(1, "量产型代达罗斯")


func _refresh_mnemosyne() -> void :
	## 「谟涅摩叙涅」8072（R271）：**这张卡在场时**，所有敌人力量 -X，X = 它的改造层数。
	## 同场多张 → 各算各的再加起来（卡面写的是「这张卡在场时」，不是效果区那种
	## 「多张不叠加」的口径）。
	## 与 `_refresh_dark_lord` 同范式：**只写 Placement 字段**（`mnemo_down`），不碰 card ——
	## 敌方关卡单位用的是卡库共享实例，写 card 会跨局泄漏；不写 card 也就不需要离场还原。
	## 调用点 = 层数 / 在场数会变的六处：双方回合开始、我方单位落地、两个改造口、单位被破坏。
	var total := 0
	for c1: Vector2i in state.board:
		var m: Placement = state.board[c1]
		if m.owner == SIDE_SELF and m.card.id == MNEMOSYNE_ID:
			total += m.upgrade_stacks
	for c2: Vector2i in state.board:
		var u: Placement = state.board[c2]
		u.mnemo_down = total if u.owner == SIDE_OPPONENT else 0


func _apply_random_born(card: CardData) -> void :
	## 「以**随机变化**的方式加入手卡」的**唯一结算口**（R271）：
	##   * 谟涅摩叙涅 8072 → 手卡内费用 -2（`hand_cost_delta`，离手自动失效）；
	##   * 量产型代达罗斯 8074 → +2 攻 +2 血（直接烤进副本的数值）。
	## 其它卡只留 `random_born` 标记 —— 以后再加「随机变化有收益」的卡，只改这里。
	if card == null or not card.random_born:
		return
	if card.id == MNEMOSYNE_ID:
		state.hand_cost_delta[card] = int(state.hand_cost_delta.get(card, 0)) \
				+ MNEMOSYNE_RAND_DISCOUNT
		_log("谟涅摩叙涅：以随机变化的方式入手 → 手卡内费用 -%d" % MNEMOSYNE_RAND_DISCOUNT)
	elif card.id == MASS_DAEDALUS_ID:
		card.power += MASS_DAEDALUS_BORN_ATK
		card.health += MASS_DAEDALUS_BORN_HP
		_log("量产型代达罗斯：以随机变化的方式入手 → +%d 攻 +%d 血"
				% [MASS_DAEDALUS_BORN_ATK, MASS_DAEDALUS_BORN_HP])


# ── R271：手卡变化（「量产型代达罗斯」入场 / 「创意」回合开始）──

func _start_cannonize(n: int, src: String) -> void :
	## 开一组「选一张手卡变成聚能炮击」的待办（UI 侧 `_pick_active_kind` = "cannonize"）。
	## 手牌为空 → 直接落空：不弹面板、不留 pending（否则玩家会被一个没得选的面板卡住）。
	if state.hand.is_empty():
		_log("%s：手牌为空，没有可变化的卡 → 效果落空" % src)
		action.emit("cannonize", {"pending": false, "remaining": 0, "source": src})
		return
	cannonize_pending = true
	cannonize_remaining += n
	cannonize_src = src
	_log("%s：待选 %d 张手卡变成聚能炮击" % [src, cannonize_remaining])
	action.emit("cannonize", {"pending": true, "remaining": cannonize_remaining, "source": src})


func cannonize_options() -> Array[int]:
	## 候选 = **全部**手牌（业务下标 = 手牌下标）；空数组 = 没有待办。
	if not cannonize_pending:
		return []
	var out: Array[int] = []
	for i in state.hand.size():
		out.append(i)
	return out


func cannonize_pick(hand_index: int) -> bool:
	## 确认一张：原位变成「聚能炮击」的独立副本。
	## 这是**确定**变化（不是随机）→ `random_born = false`，不会触发谟涅摩叙涅 / 量产型代达罗斯。
	if not cannonize_pending:
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(ENERGY_CANNON_ID) if repo != null else null
	if proto == null:
		cannonize_pending = false
		cannonize_remaining = 0
		return false
	var res := _transform_hand_card(SIDE_SELF, hand_index, proto, cannonize_src, false)
	var body: CardData = res.get("new", null) as CardData
	cannonize_remaining = maxi(0, cannonize_remaining - 1)
	if cannonize_remaining == 0:
		cannonize_pending = false
	action.emit("cannonize_pick", {"card": body, "index": hand_index,
			"remaining": cannonize_remaining})
	return body != null


func _creation_tick(side: String) -> void :
	## 「创意」8070（R271，2 费史诗效果卡）：**回合开始时**，选一张手卡变成一张随机
	## 「被改造时有额外效果」的卡，并使其获得改造：生命 +2。
	## * 挂在 `_begin_turn` **抽牌之后**（与新生 9148 同位置：刚抽完的那手牌才是候选）；
	## * 效果区几张就逐份结算（`creation_remaining`，与新生 / 专注同口径）；
	## * 敌方侧没有真实手牌（只记张数）→ 对称落空，不开面板。
	var copies := 0
	for c: CardData in (state.effects if side == SIDE_SELF else state.enemy_effects):
		if c.id == CREATION_ID:
			copies += 1
	if copies <= 0:
		return
	if side != SIDE_SELF:
		_log("创意（对方）：敌方没有真实手牌 → 效果落空")
		return
	if state.hand.is_empty():
		_log("创意：手牌为空 → 本回合不触发")
		action.emit("creation", {"pending": false, "copies": copies, "remaining": 0})
		return
	creation_pending = true
	creation_remaining = copies
	_log("创意：效果区 %d 张 → 待变化 %d 张手卡（随机「被改造有额外效果」的卡 + 生命 +2）"
			% [copies, copies])
	action.emit("creation", {"pending": true, "copies": copies, "remaining": copies})


func creation_options() -> Array[int]:
	## 创意的面板候选：**全部**手牌（业务下标 = 手牌下标）；空数组 = 没有待办。
	if not creation_pending:
		return []
	var out: Array[int] = []
	for i in state.hand.size():
		out.append(i)
	return out


func _random_creation_card() -> CardData:
	## 创意的随机池 = **玩家卡里「被改造时有额外效果」的那些**（不按职业过滤 ——
	## 卡面写的是「一张随机「被改造有额外效果」的卡牌」，这一族目前全是机械之心）。
	## 判据与 `_on_unit_upgraded()` 同源（`upgrade_atk_bonus` / `upgrade_hp_bonus` /
	## 「改造攻程·改造移速·改造抽牌」三个 trait），**不写死卡 id** ——
	## 以后新卡只要带这些字段就自动进池，不必回来改这里。
	## 池先按 id 排序再抽：rng 消耗顺序稳定 → 同种子回放可复现。
	var repo := CardRepo.load_json()
	if repo == null:
		return null
	var pool: Array[CardData] = []
	for c: CardData in repo.player_cards():
		# R275：重甲战车 8058 的改造收益是「每层受到的伤害 -1」（没有对应 trait / 字段），
		# 但它确实属于「被改造时有额外效果」—— 按 id 单独收进池，避免漏掉这一张。
		if c.upgrade_atk_bonus > 0 or c.upgrade_hp_bonus > 0 \
				or c.traits.has(UPGRADE_RANGE_TRAIT) or c.traits.has(UPGRADE_SPEED_TRAIT) \
				or c.traits.has(UPGRADE_DRAW_TRAIT) or c.id == HEAVY_TANK_ID:
			pool.append(c)
	if pool.is_empty():
		return null
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.id < b.id)
	return pool[rng.randi() % pool.size()]


func creation_pick(hand_index: int) -> bool:
	## 选一张手卡 → 随机变形成「被改造有额外效果」的卡，并获得改造：生命 +2。
	## 「获得改造」与集体改造 8031 完全同一条口径：奖励走唯一口（素体 +1 血 / 骨骼 +1 攻 +1 血）
	## + 层数随身带（侦察塔 / 堡垒 / 无限装甲都会照常响应）。
	if not creation_pending:
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var pick := _random_creation_card()
	if pick == null:
		creation_pending = false
		creation_remaining = 0
		return false
	var res := _transform_hand_card(SIDE_SELF, hand_index, pick, "创意", true)
	var body: CardData = res.get("new", null) as CardData
	if body != null:
		body.power += _upgrade_atk_gain(body, 0)
		body.health += _upgrade_hp_gain(body, CREATION_HP)
		body.upgrade_stacks += 1
		_log("创意：%s → %s（改造 +生命，%d 攻 / %d 血）"
				% [str(res.get("old", null)), body.card_name, body.power, body.health])
		_inspire_tick()   # R300 激发：创意改造一张手牌 = 一次改造动作
	creation_remaining = maxi(0, creation_remaining - 1)
	if creation_remaining == 0:
		creation_pending = false
	action.emit("creation_pick", {"card": body, "index": hand_index,
			"remaining": creation_remaining})
	return body != null


func _surprise_tick(side: String) -> void :
	## 「惊喜运单」8079（R331，机械之心 2 费稀有效果）：**回合开始时**，
	## 选卡组一张卡 → 把它变成一张随机卡并加入手卡。
	## * 挂在 `_begin_turn` **抽牌之后**（与创意 / 新生同位置：刚抽完的牌库才是候选）；
	## * 效果区几张就逐份结算（`surprise_remaining`，与创意 / 新生同口径）；
	## * 敌方侧不做选牌决策（AI 没有「选卡组一张」这一层）→ 对称落空。
	var copies := 0
	for c: CardData in (state.effects if side == SIDE_SELF else state.enemy_effects):
		if c.id == SURPRISE_ID:
			copies += 1
	if copies <= 0:
		return
	if side != SIDE_SELF:
		_log("惊喜运单（对方）：敌方不做选牌决策 → 效果落空")
		return
	if state.deck.is_empty():
		_log("惊喜运单：卡组为空 → 本回合不触发")
		action.emit("surprise", {"pending": false, "copies": copies, "remaining": 0})
		return
	surprise_pending = true
	surprise_remaining = copies
	_log("惊喜运单：效果区 %d 张 → 待选 %d 张卡组卡" % [copies, copies])
	action.emit("surprise", {"pending": true, "copies": copies, "remaining": copies})


func surprise_options() -> Array[int]:
	## 面板候选 = **全部**卡组下标（业务下标 = 牌库下标）；空数组 = 没有待办。
	## ⚠️ 给下标不给 id：卡组里可能有被生产订单 / 自主升级 / 淘汰改过数值的同 id 副本。
	if not surprise_pending:
		return []
	var out: Array[int] = []
	for i in state.deck.size():
		out.append(i)
	return out


func surprise_pick(deck_index: int) -> bool:
	## 确认一张：卡组第 deck_index 张**离开卡组**，换成一张随机奖励卡**加入手卡**。
	## * 随机池 = `_random_reward_card()`（本职业奖励池按稀有度三等分随机，
	##   与随心组装 9144 同池）—— 「随机卡」不会变成别职业的卡或诅咒；
	## * 这是**随机**变化 → `random_born = true` + `_apply_random_born()`
	##   （谟涅摩叙涅 -2 费 / 量产型代达罗斯 +2+2 照常触发）；
	## * 「变化一张卡」→ 走 `_invention_refund()`（发明专家 9143 照常回费）。
	if not surprise_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var old_card: CardData = state.deck[deck_index]
	state.deck.remove_at(deck_index)
	var out_card: CardData = null
	var landed := false
	var pick: CardData = _random_reward_card(SIDE_SELF)
	if pick != null:
		out_card = CardData.from_dict(pick.to_dict())
		out_card.traits = (pick.traits as Array).duplicate()
		out_card.affixes = (pick.affixes as Array).duplicate()
		out_card.random_born = true
		out_card.own_copy = true
		landed = _grant_to_hand(out_card, "惊喜运单")
		_apply_random_born(out_card)
		_invention_refund(SIDE_SELF, "惊喜运单")
	surprise_remaining = maxi(0, surprise_remaining - 1)
	if surprise_remaining == 0:
		surprise_pending = false
	if out_card == null:
		_log("惊喜运单：卡组里的 %s 已移除，但随机池为空 → 没变出卡" % old_card.card_name)
	else:
		_log("惊喜运单：卡组里的 %s → 随机「%s」（%s）" % [old_card.card_name,
				out_card.card_name, "加入手卡" if landed else "手牌已满 → 进弃牌区"])
	action.emit("surprise_pick", {"old": old_card, "card": out_card,
			"index": deck_index, "remaining": surprise_remaining, "landed": landed})
	return out_card != null


func _scrap_hand(side: String) -> String :
	## 「报废」8071（R271，机械之心 3 费史诗技能；R410 稀有 → 史诗）：把手牌里**其他所有卡**变成
	## 「聚能炮击」（此时报废自己已被 `use_spell` 移出手牌），并让这些卡**本回合**费用为 0。
	## * 走 `_transform_hand_card()` → 「发明专家」照常回费、"transform" 动作照常播；
	## * 「本回合 0 费」记 `turn_card_discount`（回合结束随表清空）——
	##   离开手卡后费用不再有意义，效果自然结束，正好对上卡面的「离开手卡即恢复原价」。
	if side != SIDE_SELF:
		return "报废：敌方没有真实手牌"
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(ENERGY_CANNON_ID) if repo != null else null
	if proto == null:
		_log("报废：卡库缺少「聚能炮击」(9145)，效果落空")
		return "报废：卡库缺少聚能炮击，效果落空"
	var n := 0
	for i in state.hand.size():
		var res := _transform_hand_card(side, i, proto, "报废", false)
		var body: CardData = res.get("new", null) as CardData
		if body == null:
			continue
		state.turn_card_discount[body] = int(state.turn_card_discount.get(body, 0)) \
				+ maxi(0, proto.cost)
		n += 1
	if n == 0:
		_log("报废：手牌里没有其他卡 → 效果落空")
		return "报废：手牌里没有其他卡"
	_log("报废：手牌 %d 张全部变成「聚能炮击」（本回合 0 费）" % n)
	action.emit("scrap", {"count": n})
	return "%d 张手牌变成聚能炮击（本回合 0 费）" % n


func _mass_mnemosyne_cannon_bonus(side: String) -> int:
	## 「量产型谟涅摩叙涅」8075 的**炮击额度入口**（R341 改版 = 「每回合一次」）。
	##
	## 卡面：「每回合一次：你使用「聚能炮击」时，该炮击伤害 +7，
	## 且它因自身效果抽到的那张卡费用 -1。」
	##
	## 返回 `MASS_MNEMOSYNE_DMG` = 这一发给 +7 并把本回合额度用掉；返回 0 = 不给。
	##
	## 三条纪律：
	##  ① **每座工事各一份额度**（用户口径 R341「各触发一次」）：额度记在
	##     `Placement.mass_mnemo_turn`（比对 `turn_total`，与无限装甲 8038 的
	##     `upgrade_feed_turn` 同一范式）→ 场上两座 = 一回合能触发两次；
	##     这座被打掉 / 回手后额度随之消失（新上场的那座重新算）。
	##  ② 判据只看**场上**（`state.board` 里 owner = 我方）。手牌 / 牌库 / 弃牌区里的
	##     8075 不算 —— 卡面写的是工事在场，与谟涅摩叙涅 8072 的光环同口径。
	##  ③ **本函数有副作用**（挑到哪座就把哪座的额度用掉）。所以调用方只能
	##     「打一发调一次」—— 目前唯一调用点是 `ENERGY_CANNON_ID` 分支的开头，
	##     顺序必须是「先判额度 → 再算伤害 → 再抽牌」。
	##
	## 挑哪座：**格位序号最小的那座**（`cell.y * 100 + cell.x`）。挑法必须确定 ——
	## `state.board` 是 Dictionary，单位移动是 erase + insert，遍历顺序会变，
	## 不排序的话回放会出现「两座之间该先烧哪座」的分歧（同卡同伤时看不出来，
	## 但额度消耗与减费落到哪张抽牌上是有差的）。
	##
	## 加成并进 **base** 再走 `_spell_dmg()`：附魔 / 魔法塔 / 荧光草 / 鸭之眼照常叠在
	## 「9+7」之上（与集中突破 9162 的改造加成同一口径，别直接改 `_op_deal_damage` 的入参）。
	if side != SIDE_SELF:
		return 0
	var pick: Placement = null
	var pick_key := 1 << 30
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.board[cell]
		if p == null or p.owner != SIDE_SELF or p.card == null:
			continue
		if p.card.id != MASS_MNEMOSYNE_ID or p.mass_mnemo_turn == turn_total:
			continue
		var k:= cell.y * 100 + cell.x
		if k < pick_key:
			pick_key = k
			pick = p
	if pick == null:
		return 0
	pick.mass_mnemo_turn = turn_total
	_log("量产型谟涅摩叙涅：这一发「聚能炮击」伤害 +%d（本座工事的额度已用）"
			% MASS_MNEMOSYNE_DMG)
	return MASS_MNEMOSYNE_DMG


func _cannon_draw_discount(side: String, drawn: CardData) -> void :
	## 「量产型谟涅摩叙涅」8075（R271，2 费普通工事 0/10）：你使用「聚能炮击」时，
	## **它因自身效果抽到的那张卡**费用 -1。
	## R341：这条减费与「伤害 +7」**共用同一个「每回合一次」额度** —— 调用方只在
	## `_mass_mnemosyne_cannon_bonus()` 给了加成的那一发才调本函数。
	## * 判据 = 场上有没有本卡（多座不叠加 —— 与效果区 / 场地一贯的「有没有」口径一致）；
	## * 减费记 `state.card_discount`（**实例级**、本场有效）：这是「给那张卡打折」，
	##   不是「本回合打折」，所以它洗回牌库再抽到仍然便宜 1 费。
	if side != SIDE_SELF or drawn == null:
		return
	var n := 0
	for p: Placement in state.board.values():
		if p.owner == SIDE_SELF and p.card.id == MASS_MNEMOSYNE_ID:
			n += 1
	if n <= 0:
		return
	# R281 防御：减费按**实例**记账 → 这张必须是手牌里的独立副本（`FieldState.draw()`
	# 已保证；这里再兜一次，防止将来有别的抽牌路径绕开 draw()）。
	var idx := state.hand.size() - 1
	if idx < 0 or state.hand[idx] != drawn:
		return
	if not drawn.own_copy:
		var own := CardData.from_dict(drawn.to_dict())
		own.own_copy = true
		state.hand[idx] = own
		drawn = own
	state.card_discount[drawn] = int(state.card_discount.get(drawn, 0)) \
			+ MASS_MNEMOSYNE_DISCOUNT
	_log("量产型谟涅摩叙涅：聚能炮击抽到的「%s」费用 -%d"
			% [drawn.card_name, MASS_MNEMOSYNE_DISCOUNT])

func _spawn_self_clone(card: CardData) -> void :
	## 野兔 9032（R82）：把**自己**复制一份塞进手牌。
	##
	## 为什么必须 `from_dict` 复制成新实例：卡库里是**共享实例**，直接把手牌里那张
	## 本身再 append 一次会让**同一个 CardData 对象在手牌里出现两次** ——
	## 之后任何按实例记账的表（turn_card_discount / card_discount）或 UI 高亮都会
	## 互相串（点一张两张都亮）。复制品是独立对象，两张互不影响。
	##
	## `is_ephemeral = true` 是**关键**：它把复制品标成「本场战斗内的衍生物」，
	## 于是手牌回合结束 / 场上离场时都直接消失、不进弃牌区。
	## 被打死的**原卡**没有这个标记，照常进弃牌区被洗回牌库 —— 两条路径不能混。
	## 复制卡**保留** CLONE_TRAIT，所以打出它会再次触发本分支（用户要的口径：还能再复制）。
	##
	## 手牌满了就**不生成**（不给白拿的牌，也不洗牌）—— 与 _fetch_skill_card 同一口径。
	## 注：实际流程里**几乎走不到**这个分支 —— 复制发生在「打出的那张已离手」之后，
	## 手牌刚好腾出一格，所以永远是「不满」。留着是防御（例如将来改成从别处触发复制）。
	var clone:= CardData.from_dict(card.to_dict())
	clone.traits = (card.traits as Array).duplicate()   # 切断与卡库的共享引用
	clone.is_ephemeral = true      # 衍生物标记：离场消失、不进弃牌区（卡库原卡没有它）
	# R319（用户口径）：复制品是「短暂复制」= 次元 + 回合结束消失 → 徽标写**次元**，
	# 不再是本体那个「幻影」（幻影只说明「手牌里会消失」，看不出离场也消失）。
	# ⚠️ 必须**换新数组**：直接改 `clone.affixes` 会串到卡库共享实例上。
	clone.affixes = [AFFIX_DIMENSION]
	# R299：手牌满 → 走 `_grant_to_hand`；它认得 `is_ephemeral`，会把衍生物送进**消耗区**
	# 而不是弃牌区（弃牌区会被洗回牌库 → 无限刷）。
	_grant_to_hand(clone, card.card_name)
	_log("%s：手牌增加一张复制（回合结束前可打出）" % card.card_name)
	action.emit("self_clone", {"card": clone, "from": card})


## ── R120：**改造奖励的唯一口**（素体 / 战斗骨骼这类卡面字段）──
##
##   R84 起「被改造时 +N 力 / +M 血」改读**卡面字段**（`CardData.upgrade_atk_bonus` /
##   `upgrade_hp_bonus`），但当时只有「升级」8027 与「加厚装甲」8044 两个入口真的读了它 ——
##   自我修复 8035 / 改造工厂 8037 / 超越极限 8053 / 集体改造 8031 / 系统升级 8039 /
##   批量传输 8040 / 自主升级 8045 / 生产订单 8048 / 代达罗斯 8060 全都漏掉，
##   于是素体（+1 生命）在这些改造下**白挨**（用户 R120 报的缺陷）。
##
##   现在**所有**施加改造的入口都必须调这两个函数取增量，不许再手写 `+ c.upgrade_hp_bonus`。
##   口径（用户确认）：**任何**改造都生效，含手牌与牌库里的改造。
##
##   两张卡定义了这个口的两个特例：
##   * 素体 8025（`upgrade_hp_bonus = 1`）：任何改造额外 +1 生命。
##   * 侦察塔 8032（trait「改造层数」）：改造**不**加自身攻击力（恒为 0）——
##     它的收益是光环易伤（见 `_scout_aura_bonus`），加在敌人身上而不是塔自己身上。
func _upgrade_atk_gain(c: CardData, base_atk: int = 0) -> int:
	## 一次改造给这张卡加的**力量** = 来源给的基数 + 卡面自己的改造奖励；
	## 带 trait「改造层数」（侦察塔）的卡**恒为 0** —— 它 0 攻就是 0 攻。
	if c == null:
		return base_atk
	if c.traits.has(STACK_DAMAGE_TRAIT):
		return 0
	return base_atk + c.upgrade_atk_bonus


func _upgrade_hp_gain(c: CardData, base_hp: int = 0) -> int:
	## 一次改造给这张卡加的**生命** = 来源给的基数 + 卡面自己的改造奖励（素体 +1）。
	if c == null:
		return base_hp
	return base_hp + c.upgrade_hp_bonus


func _stack_hp_bonus(p: Placement) -> int:
	## 「改造生命层」（堡垒 8034，R274）在**当前层数**下应得的额外生命。
	## 层数来源不限 —— 手牌 / 牌库里的改造由 `FieldState.place()` 折进来，
	## 场上改造由 `_add_upgrade_stack()` 逐层补，两边记的都是 `upgrade_stacks`。
	if p == null or p.card == null:
		return 0
	if not p.card.traits.has(STACK_HP_TRAIT):
		return 0
	return p.upgrade_stacks * STACK_HP_PER


func _refresh_stack_hp(p: Placement) -> void:
	## 「改造生命层」的**唯一结算口**（R274）：把 `health` 调到「当前层数应得」的值。
	##
	## 差量法（目标值 - 已结算值）→ 幂等，同一层数调几次都只加一次；
	## 加的血并进 `upgrade_hp`，离场还原仍走 `_card_leaving_field()` 那条老路。
	##
	## 为什么不能像以前那样「改造时 +3 一次就完」：那样只有**当场那次改造**算数，
	## 手牌里攒的层数上场后白吃，而且自我修复 / 超越极限 / 共享护盾 / 改造工厂 /
	## 模仿者传导全都漏（都是自己手写的 +3 复制不到）。
	if p == null or p.card == null:
		return
	var want := _stack_hp_bonus(p)
	var delta := want - p.stack_hp_applied
	if delta == 0:
		return
	p.stack_hp_applied = want
	p.upgrade_hp += delta
	p.card.health += delta
	p.health += delta
	if p.health < 1:
		p.health = 1
	_log("堡垒：%s 改造 %d 层 → 生命 %+d（%d/%d）" % [
			p.card.card_name, p.upgrade_stacks, delta, p.health, p.card.health])


func _add_upgrade_stack(p: Placement) -> void:
	## 场上「改造层数 +1」的**唯一口**（R274）。
	## 除了 +1，还立刻按**新层数**重算「改造生命层」——
	## ⚠️ 新增改造入口一律走这里，别再裸写 `p.upgrade_stacks += 1`（漏一次就少一层收益）。
	if p == null:
		return
	p.upgrade_stacks += 1
	_refresh_stack_hp(p)
	# 谟涅摩叙涅 8072 的「每层 -1 敌力」也是「按层数」的族 —— 层数一变就得重算，
	# 否则超越极限 / 自我修复 / 加厚装甲 / 改造工厂给的层数不反映到光环上（R274 补）。
	_refresh_mnemosyne()


func _scout_aura_bonus(victim: Placement, victim_cell: Vector2i) -> int:
	## 「侦察塔」（8032，trait「改造层数」）的**光环易伤**（R120 用户口径）：
	## 站在它**攻击范围内**的敌人，受到**任何来源**的伤害都 +1 / 层改造。
	##
	##   * 「敌人」= **不同 owner** 的单位 —— 敌方的侦察塔照样罩我方（敌我对称）。
	##   * 多座塔 / 多层改造**可叠加**（每座塔各算各的层）。
	##   * 距离用**曼哈顿**（= `attack_distance` 的常态口径），范围读塔自己的
	##     `attack_range`（塔被改造加过攻程也算数）。
	##   * 塔自己掉血时不计（它是施放者）；`upgrade_stacks == 0` 的塔不贡献。
	##   * 只作用于**单位**：敌方 HP（玩家血条）不在光环范围内（卡面写的是「敌人」）。
	if victim == null or victim.card == null:
		return 0
	var bonus := 0
	for other: Vector2i in state.board:
		var u: Placement = state.board[other]
		if u == victim or u.card == null or u.upgrade_stacks <= 0:
			continue
		if not u.card.traits.has(STACK_DAMAGE_TRAIT):
			continue
		if u.owner == victim.owner:
			continue
		if manhattan(other, victim_cell) <= u.effective_range():
			bonus += u.upgrade_stacks
	return bonus


func _apply_rapid_marks(p: Placement, amount: int) -> int:
	## R316 极速（9171）：「本回合所有敌人受到伤害 +N」的**统一施加口**。
	## 与「侦察塔光环」必须成对出现在**同两个落地口**：`_hit_unit`（普攻 / 多格效果 /
	## 陷阱 / 亡语…）与 `_op_deal_damage`（单目标技能卡）—— 只挂一处会让另一条路被绕过
	## （侦察塔当年就踩过这个坑，见 `_apply_scout_aura` 的注释）。
	## ⚠️ 只作用于**敌方单位**：我方单位被打不该吃自己的易伤；敌方 HP（没有 Placement）
	##    也不在此列 —— 与侦察塔「只加单位」同一口径。
	## ⚠️ 调用方要保证「一次伤害只加一次」（`_hit_unit` 里放在 `allow_redirect` 分支内）。
	if p == null or p.card == null or _rapid_enemy_bonus <= 0:
		return amount
	if p.owner == SIDE_SELF:
		return amount
	_log("极速：%s 受到的伤害 +%d（%d → %d）" % [
			p.card.card_name, _rapid_enemy_bonus, amount, amount + _rapid_enemy_bonus])
	return amount + _rapid_enemy_bonus


func _apply_scout_aura(p: Placement, amount: int) -> int:
	## R138：「侦察塔」光环易伤的**统一施加口** —— 返回加成后的伤害。
	## ⚠️ 单位扣血有**两个落地口**（见 `_unit_damage_taken` 的注释）：`_hit_unit`
	##   （普通攻击 / 多格效果 / 陷阱 / 亡语…）与 `_op_deal_damage`（**单目标技能卡**那条）。
	##   原来光环只挂在 `_hit_unit` → **技能卡打上去时被绕过**（用户实测反馈）。
	##   现在两边都调本函数，口径一致。
	if p == null or p.card == null:
		return amount
	var aura:= _scout_aura_bonus(p, _cell_of(p))
	if aura <= 0:
		return amount
	_log("侦察塔光环：%s 受到的伤害 +%d（%d → %d）" % [
			p.card.card_name, aura, amount, amount + aura])
	action.emit("scout_aura", {"cell": _cell_of(p), "card": p.card,
			"bonus": aura, "base": amount, "amount": amount + aura,
			"side": p.owner})
	return amount + aura


func _on_unit_upgraded(p: Placement) -> void :
	## R101：「每次获得改造时」触发（榴弹击手/重甲战车/机器鸟）。
	## 在**所有**给这张单位施加改造的入口末尾调用（升级/自我修复/加厚装甲/
	## 超越极限/模仿者传导/代达罗斯 群体改造）。
	##
	## R391（用户口径「无限装甲目前只有升级这一张卡触发」）：**无限装甲的供能也在这里**。
	## 以前它在 `_upgrade_unit` / `_transcend` / `_armor_plate` 三个入口各手调一次，
	## 于是凡是不走这三条路的改造 —— 自我修复 8035 / 共享护盾 8069 / 拾荒者 /
	## 合体 / 改装者 / 改造工厂 8037 / 模仿者传导 —— 全都不供能，玩家体感是
	## 「只有『升级』能触发」。现在统一在这个后置口触发，与「榴弹击手加射程」
	## 「机器鸟抽牌」同源：**只要是「被改造」，就一定会走到这里**。
	## ⚠️ 顺序：供能放在**最前面**。原先是 `_feed_upgrade_card()` 紧接
	##    `_on_unit_upgraded()` 调用，供能先于其它 trait 响应；放最前面才与旧行为等价
	##    （机器鸟等会往手里塞牌，先供能才不会被它挤掉手牌位置）。
	## ⚠️ 每回合一次由 `_feed_upgrade_card` 内部 `upgrade_feed_turn` 把守 ——
	##    改造工厂每回合都改造，不会变成白嫖多张。
	if p == null or p.card == null:
		return
	_feed_upgrade_card(p)
	if p.card.traits.has(UPGRADE_RANGE_TRAIT):      # 榴弹击手：攻击距离+1
		p.upgrade_range += 1
		p.card.attack_range += 1
		_log("改造触发：%s 攻击距离+1（→%d）" % [p.card.card_name, p.card.attack_range])
	if p.card.traits.has(UPGRADE_SPEED_TRAIT):      # R275 后无卡使用（重甲战车已改），留给未来
		p.upgrade_speed += 1
		p.card.move_speed += 1
		_log("改造触发：%s 移动速度+1（→%d）" % [p.card.card_name, p.card.move_speed])
	if p.card.traits.has(UPGRADE_DRAW_TRAIT):        # 机器鸟：抽1张
		if p.owner == SIDE_SELF:
			state.draw()
		_log("改造触发：%s 改造时抽1张" % p.card.card_name)
	if p.card.traits.has(WASTE_BOT_TRAIT):          # R228 废弃机器人：每次被改造 → 全体敌方 1 伤
		_waste_bot_ping(p)
	if p.card.traits.has(CLUSTER_TURRET_TRAIT):     # R298 集束炮台：每次被改造 → 从卡组捞一张聚能炮击
		_cluster_turret_reload(p)

# ================= R298：集束炮台 9166 / 合体 9167 =================


func _cluster_turret_enter(p: Placement) -> void :
	## 「集束炮台」9166（R298，机械之心 2 费普通盟友 1/6/1/1）的**入场**效果：
	## 往抽牌库（`state.deck`）末尾塞 CLUSTER_TURRET_CANNON_COUNT 张「聚能炮击」9145。
	## ⚠️ 与生产订单 8048 同口径：`from_dict` 复制成独立实例 —— 卡库是共享实例，
	##    直接塞进去会让「这张炮击被改造 / 被附魔」泄漏到图鉴与下一局。
	if p == null or p.card == null:
		return
	if p.owner != SIDE_SELF:
		# 敌方没有真实牌库（只有抽象计数 opp_deck_count）→ 不入库，免得污染玩家卡组。
		_log("集束炮台：%s 入场（非我方，跳过入库）" % p.card.card_name)
		return
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(ENERGY_CANNON_ID) if repo != null else null
	if proto == null:
		_log("集束炮台：卡库缺少「聚能炮击」(9145)，入场效果落空")
		return
	var added := 0
	for _i in CLUSTER_TURRET_CANNON_COUNT:
		var c := CardData.from_dict(proto.to_dict())
		c.traits = (c.traits as Array).duplicate()
		state.deck.append(c)
		action.emit("deck_added", {"card": c, "side": p.owner})
		added += 1
	_log("集束炮台：%s 入场 → 卡组 +%d 张「聚能炮击」（牌库 %d 张）" % [
			p.card.card_name, added, state.deck.size()])


func _cluster_turret_reload(p: Placement) -> void :
	## 「集束炮台」9166（R298）的**每次获得改造**效果：从卡组把一张「聚能炮击」加入手卡。
	## 挂点是 `_on_unit_upgraded()` —— 所有改造入口的统一后置口，所以「升级 / 加厚装甲 /
	## 超越极限 / 拾荒者 / 模仿者传导 / 改造工厂」全都自动吃到，不必给每个入口补分支。
	## ⚠️ R299（用户规则）：手牌满 → 那张炮击**照样从卡组取出来，直接进弃牌区** ——
	##    以前是「留在卡组」，等于这次改造白改；现在它至少落在弃牌区，之后还能洗回牌库。
	if p == null or p.card == null or p.owner != SIDE_SELF:
		return
	var di := -1
	for i in state.deck.size():
		if state.deck[i].id == ENERGY_CANNON_ID:
			di = i
			break
	if di < 0:
		_log("集束炮台：卡组里已经没有「聚能炮击」了")
		return
	var c: CardData = state.deck[di]
	state.deck.remove_at(di)
	_grant_to_hand(c, "集束炮台")
	_log("集束炮台：%s 获得改造 → 从卡组取「%s」（牌库 %d 张）" % [
			p.card.card_name, c.card_name, state.deck.size()])
	action.emit("cluster_reload", {"cell": _cell_of(p), "card": c, "side": p.owner})


# ================= R300：激发 8077 =================


func _wind_fairy_tick(side: String) -> void:
	## 风妖精（6042，R313）：**一回合打出第五张牌时**，对所有敌人造成 4 点伤害。
	## 挂点是 `_note_card_played()` —— 所有出牌路径（手牌 / 技能 / 效果 / 联机 / 回放）
	## 的唯一收尾口，计数在调用本函数前已经 +1。
	## ⚠️ 判「**恰好**第 5 张」而不是取模：计数每回合清零，一回合只可能触发一次；
	##    写取模会在计数被别的效果改动时冒出「第 10 张又触发一次」的歧义。
	## ⚠️ 伤害走 `_hit_unit()`（护盾 / 减伤 / 侦察塔光环照常生效），致死交 `_destroy_dead()`；
	##    与激发 8077 / 废弃机器人 9152 的「全体 ping」同口径。
	if side != SIDE_SELF or not self_relics.has(WIND_FAIRY_RELIC_ID):
		return
	if state.self_card_plays != WIND_FAIRY_AT:
		return
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.board[cell]
		if q != null and q.owner == SIDE_OPPONENT and q.health > 0:
			cells.append(cell)
	if cells.is_empty():
		_log("风妖精：场上没有敌方单位，效果落空")
		return
	cells.sort()   # 固定顺序：回放 / 同种子必须一致
	var hit:= 0
	var wf_cells: Array[Vector2i] = []   # R362：命中格子（界面绑着单位飘数字）
	for c: Vector2i in cells:
		var q2: Placement = state.board.get(c, null)
		if q2 == null or q2.health <= 0:
			continue
		_hit_unit(q2, WIND_FAIRY_DMG, "风妖精")
		wf_cells.append(c)
		hit += 1
	_destroy_dead()
	_log("风妖精：本回合第 %d 张牌 → 对所有敌人造成 %d 点伤害（%d 个目标）"
			% [WIND_FAIRY_AT, WIND_FAIRY_DMG, hit])
	action.emit("wind_fairy", {"dmg": WIND_FAIRY_DMG, "hits": hit, "cells": wf_cells})


func _inspire_tick() -> int:
	## 「激发」8077（R300，机械之心 2 费**史诗效果卡**）的**唯一结算口**：
	## 对**随机 INSPIRE_TARGETS 个敌人**各造成 INSPIRE_DMG 点伤害 ——
	## 效果区**每有一张**就各打一轮（卡面「可叠加」）。
	## R362（用户口径）：原先是「对所有敌人」，改成「随机两个」——场上不足两只时有多少打多少。
	##
	## 调用点必须全部是 **「改造动作」的末尾**（每个动作只调一次）：
	## 用户口径「无论一次性改造多少张都算一次」—— 批量改造 10 张也只打一轮。
	## 所以它**不**挂在 `_field_upgrade_grant()` / `_on_unit_upgraded()`（那两个是逐张的）。
	##
	## 三条落地细节：
	##   * 伤害走 `_hit_unit`（护盾 / 减伤 / 石肤 / 石肤光环照常生效），致死统一交
	##     `_destroy_dead()` —— 与废弃机器人 9152 的「全体 ping」同口径；
	##   * 只打**场上的敌方单位**，不直击敌方 HP（没有单位时效果落空）；
	##   * 每轮**独立抽取**：两轮可以打到不同两只，也可能重复打同一只（各自 3 点）；
	##     抽取走 `rng`（回放一致），命中顺序按格子排序（日志 / 飘字顺序稳定）；
	##   * ⚠️ 重入保护：本函数自己造成伤害 → 若某张敌方亡语反过来改造了我方卡，
	##     会再走进来。`_inspire_busy` 保证一次结算不被自己递归放大。
	if _inspire_busy:
		return 0
	var n := 0
	for c: CardData in state.effects:
		if c != null and c.id == INSPIRE_ID:
			n += 1
	if n <= 0:
		return 0
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var u: Placement = state.board[cell]
		if u != null and u.owner == SIDE_OPPONENT:
			cells.append(cell)
	if cells.is_empty():
		_log("激发：场上没有敌方单位，效果落空")
		return 0
	cells.sort()   # 固定顺序：回放 / 同种子必须一致
	_inspire_busy = true
	var hits := 0
	# R362：命中的格子一并带出去 —— 界面要**绑在被命中的单位头上**飘数字。
	# 改成「随机两个」之后，原来那行固定在棋盘上沿的「全体 -3」就是假的
	# （而且和风妖精的「全体 -4」长得像，实机被读成「激发打出就造成伤害」）。
	var hit_cells: Array[Vector2i] = []
	for _i in n:
		# R362：本轮**存活**的敌方格子重新收一遍（上一轮可能刚打死两只）。
		var pool: Array[Vector2i] = []
		for c2: Vector2i in cells:
			var q0: Placement = state.board.get(c2, null)
			if q0 != null and q0.health > 0:
				pool.append(c2)
		if pool.is_empty():
			break
		# 无放回抽 min(INSPIRE_TARGETS, 存活数) 个 —— 不足两只时就是「有多少打多少」。
		var picks: Array[Vector2i] = []
		for _k in mini(INSPIRE_TARGETS, pool.size()):
			var j: int = rng.randi_range(0, pool.size() - 1)
			picks.append(pool[j])
			pool.remove_at(j)
		picks.sort()   # 命中顺序与选人无关，只按格子排（日志 / 飘字稳定）
		for c3: Vector2i in picks:
			var q: Placement = state.board.get(c3, null)
			if q == null or q.health <= 0:
				continue
			_hit_unit(q, INSPIRE_DMG, "激发")
			hit_cells.append(c3)
			hits += 1
		_destroy_dead()
	_inspire_busy = false
	_log("激发：一张卡被改造 → 随机 %d 个敌人各受 %d 点伤害（叠加 ×%d，共 %d 次命中）" % [
			INSPIRE_TARGETS, INSPIRE_DMG, n, hits])
	action.emit("inspire", {"count": n, "dmg": INSPIRE_DMG, "hits": hits,
			"targets": INSPIRE_TARGETS, "cells": hit_cells})
	return n

func _first_proto_index() -> int:
	## 卡组里第一张「素体」8025 的下标（-1 = 没有）。
	## 判据用 id 比对 PROTO_ID —— 与 R221「拆素体不触发回收者」同口径（全库仅 8025 是素体）。
	for i in state.deck.size():
		if state.deck[i].id == PROTO_ID:
			return i
	return -1


func eliminate_options() -> Array[int]:
	## R317 淘汰（9174）：卡组里**可作为目标**的下标 —— 盟友 / 工事。
	## ⚠️ 给下标不给 id：卡组里可能有被生产订单 / 自主升级改过数值的同 id 副本，
	##    按 id 找会变成「改错那一张」（与 `merge_deck_options` 同一条纪律）。
	var out: Array[int] = []
	for i in state.deck.size():
		var c: CardData = state.deck[i]
		if c == null:
			continue
		if c.kind == "盟友" or c.is_fort():
			out.append(i)
	return out


func eliminate_pick(deck_index: int) -> bool:
	## R317 淘汰（9174）面板「确认」的唯一结算口：把卡组第 deck_index 张**换成一张新素体**。
	## * 素体是**全新副本**（不是改造过的）：卡面写的是「变成素体」，改造不保留；
	## * 原位替换 → 之后抽到它时就是素体（0 费 1/1 盟友、回合结束不弃牌）；
	## * 抽 4 张**已经在施放时结算过**，这里不再抽（见 `ELIMINATE_ID` 的注释）。
	if not eliminate_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var old_card: CardData = state.deck[deck_index]
	if old_card == null or not (old_card.kind == "盟友" or old_card.is_fort()):
		return false
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(PROTO_ID)
	if proto == null:
		eliminate_pending = false
		return false
	var new_card := CardData.from_dict(proto.to_dict())
	state.deck[deck_index] = new_card
	eliminate_pending = false
	_log("淘汰：卡组里的 %s → 「素体」（0 费 1/1，回合结束不弃牌）" % old_card.card_name)
	action.emit("eliminate_pick", {"old": old_card, "card": new_card,
			"index": deck_index})
	return true


func eliminate_cancel() -> void:
	## 淘汰面板取消：只是放弃「变素体」，**抽到的 4 张不收回**（它们早就进手牌了）。
	if not eliminate_pending:
		return
	eliminate_pending = false
	_log("淘汰：已取消变素体（抽牌照旧保留）")
	action.emit("eliminate_cancel", {"side": SIDE_SELF})


func merge_deck_options() -> Array[int]:
	## 合体面板的候选：卡组里**所有**「素体」（8025）的下标。
	## ⚠️ 给的是**下标**不是 id —— 卡组里的素体可能是被生产订单 8048 / 自主升级改造过的副本
	##    （同 id、不同数值），按 id 找第一张会吃错那一只。
	var out: Array[int] = []
	for i in state.deck.size():
		if state.deck[i].id == PROTO_ID:
			out.append(i)
	out.reverse()   # 与专注面板同口径：反转让第 1 张更接近「牌组开头」
	return out


func _clear_merge_pick() -> String:
	## 清掉合体的全部挂起状态，返回「已经消失掉的那张素体名」（没有则空串）。
	## 目标在面板期间被破坏 / 抬走时，那张素体已经没了 —— 提示里要如实说清楚，
	## 不能假装「什么都没发生」（与本文件一贯的「已移除的不回收」口径一致）。
	var lost := merge_body_name
	merge_pending = false
	merge_hand_index = -1
	merge_cell = Vector2i(-1, -1)
	merge_body_atk = -1
	merge_body_hp = -1
	merge_body_name = ""
	return lost


func cast_merge(hand_index: int, target, free_cast := false) -> String:
	## 「合体」（9167，R298，机械之心 1 费史诗技能）的**两段施放入口**。
	## 第一段（本函数）：场上指定一张己方盟友或工事 → 挂起 `merge_pending`，
	## 由 battle_scene 弹出「从卡组选一张素体」面板（UI kind = "merge"）。
	## 第二段（`merge_pick`）：选中素体 → 它**消失**（进消耗区）→ 由界面接着调 `use_spell()`
	## 真正把合体打出去，结算口是 `_merge_spell()`。
	## ⚠️ **付费点故意在第二段之后**：面板打开期间合体仍在手牌、费用未扣 → 取消就等于
	##    没打出过（与回收 / 填充「取消不扣费」同口径）。否则玩家先在场上点了目标、
	##    又在面板里放弃，会白丢 1 费 + 一张史诗牌。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（合体：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != MERGE_ID:
		return "（这不是合体）"
	var p := _target_placement(SIDE_SELF, target)
	if p == null or p.owner != SIDE_SELF:
		return "合体：只能指定自己的盟友或工事"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "合体：%s 不能被改造" % p.card.card_name
	if merge_pending:
		return "（合体：已经在选素体了）"
	if _first_proto_index() < 0:
		return "合体：卡组里没有「素体」"
	# 失控要塞 9161 这类「凭空释放」没有玩家交互 → 直接按卡组顺序取第一张素体结算。
	if free_cast:
		return _merge_spell(target, SIDE_SELF)
	merge_pending = true
	merge_hand_index = hand_index
	merge_cell = _cell_of(p)
	_log("合体：目标 %s 已指定 → 从卡组挑一张「素体」" % p.card.card_name)
	action.emit("merge_pending", {"cell": merge_cell, "card": p.card,
			"count": merge_deck_options().size()})
	return "选择卡组里的「素体」"


func merge_pick(deck_index: int) -> bool:
	## 合体面板「确认」的唯一结算口：让选中的素体**本场消失**，并把它的数值记在
	## `merge_body_*` 上 —— 真正的改造由随后那次 `use_spell()` → `_merge_spell()` 落地。
	## ⚠️ 这里**不扣费、不弃牌**：那两件事归 `use_spell()` 统一收尾（付费 / 蓄力次数 /
	##    风元素 / 出牌计数 / 次元判定，一个都不漏）。
	if not merge_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var body: CardData = state.deck[deck_index]
	if body == null or body.id != PROTO_ID:
		_log("合体：选中的不是「素体」，已忽略")
		return false
	state.deck.remove_at(deck_index)
	state.void_count += 1
	state.void_cards.append(body)   # R140 消耗区：本次对战中消失
	merge_body_atk = maxi(0, body.power)
	merge_body_hp = maxi(0, body.health)
	merge_body_name = body.card_name
	merge_pending = false
	_log("合体：%s 从卡组消失（本次对战移除，%d 攻 / %d 血）" % [
			body.card_name, merge_body_atk, merge_body_hp])
	action.emit("merge_void", {"card": body, "atk": merge_body_atk, "hp": merge_body_hp})
	return true


func merge_cancel() -> void:
	## 合体面板取消：清挂起状态。此时**什么都没发生** —— 素体没消失、费用没扣、卡还在手牌。
	if not merge_pending:
		return
	_log("合体：已取消选择（合体仍在手牌，未扣费）")
	_clear_merge_pick()


func _merge_spell(target, side: String) -> String:
	## 「合体」的**统一结算口**（`_run_spell_effect` 的 MERGE_ID 分支）：
	## 让一张素体消失 → 场上的目标获得改造（力 +素体的力量、血 +素体的生命）。
	## * 素体来源：优先取 `merge_pick()` 预存的数值（玩家在面板里挑的那一张）；
	##   没有预存（失控要塞 9161 凭空释放 / 蓄力叠了第二次）→ 按卡组顺序取第一张。
	## * 改造走 `_field_upgrade_grant()`（场上改造唯一口）→ 层数 +1、受体自己的改造奖励
	##   （战斗骨骼 +2+2 / 素体 +1 血）照算，模仿者传导 / 侦察塔 / 堡垒全部联动。
	var p := _target_placement(side, target)
	if p == null or p.owner != side or (p.card.kind != "盟友" and not p.card.is_fort()):
		var lost := _clear_merge_pick()
		if lost != "":
			_log("合体：目标已不在场 → 只失去了「%s」" % lost)
			return "合体：目标不合法，「%s」已消失" % lost
		return "（合体：需要指定一个己方盟友或工事）"
	var atk := merge_body_atk
	var hp := merge_body_hp
	var src_name := merge_body_name
	if atk < 0 or hp < 0:
		var di := _first_proto_index()
		if di < 0:
			_clear_merge_pick()
			_log("合体：卡组里没有「素体」，效果落空")
			return "合体：卡组里没有素体"
		var body: CardData = state.deck[di]
		state.deck.remove_at(di)
		state.void_count += 1
		state.void_cards.append(body)
		atk = maxi(0, body.power)
		hp = maxi(0, body.health)
		src_name = body.card_name
	var nm: String = p.card.card_name
	_clear_merge_pick()
	_log("合体：%s 消失 → %s 获得改造（力量 +%d、生命 +%d）" % [src_name, nm, atk, hp])
	_field_upgrade_grant(p, atk, hp, "合体")
	_inspire_tick()   # R300 激发：合体 = 一次改造动作
	action.emit("merge", {"cell": _cell_of(p), "card": p.card, "atk": atk, "hp": hp,
			"side": side})
	return "%s 获得改造（+%d 攻 / +%d 血）" % [nm, atk, hp]

func _scavenger_tick(side: String) -> void :
	## 拾荒者（9151，R228）：**己方回合开始时**，每个拾荒者各挑一个「拾荒者以外」的
	## 己方单位，给它一次改造（+3 攻 / +5 血）。
	## * 目标随机（引擎 rng → 同种子同结果，回放可复现）；候选为空（场上只剩拾荒者）→ 跳过；
	## * 改造走 `_field_upgrade_grant()`（场上改造唯一口）→ 被改的是废弃机器人时会
	##   连带触发它「每次被改造 → 对所有敌方单位 1 伤」。
	## ⚠️ 两只拾荒者各自独立结算（各改一个），同一回合可能改到同一个目标 —— 允许叠加。
	var scavengers: Array[Placement] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p != null and p.owner == side and p.card.traits.has(SCAVENGER_TRAIT):
			scavengers.append(p)
	if scavengers.is_empty():
		return
	for sc: Placement in scavengers:
		var picks: Array[Placement] = []
		for cell2: Vector2i in state.board:
			var q: Placement = state.board[cell2]
			if q != null and q.owner == side and not q.card.traits.has(SCAVENGER_TRAIT):
				picks.append(q)
		if picks.is_empty():
			_log("拾荒者：场上没有「拾荒者」以外的友方单位可改造")
			continue
		var tgt: Placement = picks[rng.randi() % picks.size()]
		_log("拾荒者（%s）：回合开始 → 改造 %s" % [sc.card.card_name, tgt.card.card_name])
		_field_upgrade_grant(tgt, SCAVENGER_ATK, SCAVENGER_HP, "拾荒者")
	_inspire_tick()   # R300 激发：拾荒者改造一次（每只各自算一次）


func _breach_tick(side: String) -> void :
	## 破绽（R231）：`side` 这一方每只带「破绽」trait 的单位，往**对方卡组**塞一张
	## 诅咒「破绽」（9154，2 费，打出无效果）。
	## * 敌方 → 真的插进玩家牌库（`state.deck`），位置随机（引擎 rng，回放一致）；
	## * 我方 → 敌方牌库只是抽象计数（`opp_deck_count`），只 +1（与「镜像」同口径）。
	## ⚠️ 快照格子后排序再结算：同一回合多只单位时，rng 消耗顺序必须稳定（回放）。
	## ⚠️ 诅咒卡一律 `CardData.from_dict()` 复制：卡库实例是共享的，直接塞库实例会让
	##    「这张诅咒被改造 / 被附魔」之类的场上改动泄漏到图鉴里。
	var casters: Array[Placement] = []
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p != null and p.owner == side and p.card.traits.has(BREACH_TRAIT):
			cells.append(cell)
	if cells.is_empty():
		return
	cells.sort()
	for c: Vector2i in cells:
		var p2: Placement = state.unit_at(c)
		if p2 == null:
			continue
		casters.append(p2)
	var base: CardData = CardRepo.load_json().get_card(BREACH_CURSE_ID)
	if base == null:
		_log("破绽：找不到诅咒卡定义（%d）" % BREACH_CURSE_ID)
		return
	for p3: Placement in casters:
		var curse := CardData.from_dict(base.to_dict())
		if side == SIDE_OPPONENT:
			var idx: int = state.deck.size()
			if idx > 0:
				idx = rng.randi_range(0, idx)
			state.deck.insert(idx, curse)
			_log("破绽：%s 回合开始 → 一张诅咒「破绽」（2 费）塞进你的卡组（牌库 %d 张）"
					% [p3.card.card_name, state.deck.size()])
			action.emit("curse_added", {"card": curse, "from": p3.card,
					"cell": _cell_of(p3), "deck": state.deck.size()})
		else:
			state.opp_deck_count += 1
			_log("破绽（我方）：%s 回合开始 → 对方卡组 +1 张「破绽」" % p3.card.card_name)
			action.emit("curse_added", {"card": curse, "from": p3.card,
					"cell": _cell_of(p3), "deck": -1})


func _field_upgrade_grant(p: Placement, atk: int, hp: int, source: String,
		affix: String = "") -> void :
	## **场上单位获得改造的唯一口**（R228）。
	## R272（用户口径）：**任意方式**的改造都要吃卡面改造奖励（战斗骨骼 +2 力 +2 血 /
	## 素体 +1 血）。R228 当初刻意「不带 `upgrade_*_bonus`」，结果「共享护盾」「拾荒者」
	## 给骨骼改造只涨层数、不涨数值 —— 与卡面「被改造时」自相矛盾，用户报了这个缺陷。
	## 现在统一过 `_upgrade_atk_gain` / `_upgrade_hp_gain` 唯一口。
	## 加攻进 `upgrade_atk`（进 effective_power）、加血同时抬场上卡副本与 `p.health`，
	## 离场由 `_card_leaving_field` 统一减回去。
	## ⚠️ 卡换成独立副本再改（卡库实例是共享的，直接改会跨局泄漏）。
	## ⚠️ 末尾必须调 `_on_unit_upgraded(p)`（所有改造入口的统一后置口）。
	if p == null or p.card == null:
		return
	p.card = CardData.from_dict(p.card.to_dict())
	p.card.traits = (p.card.traits as Array).duplicate()
	# R269：可选附带一个**字段**（共享护盾 8069）。必须在 `_on_unit_upgraded()` **之前**挂上 ——
	# 否则「每次被改造」那条链（侦察塔 / 堡垒 / 无限装甲 / 模仿者 / 废弃机器人）读到的
	# 还是没字段的卡，等于这次改造对它们「不算数」。
	if affix != "":
		p.card.add_affix(affix)
	var atk_all: int = _upgrade_atk_gain(p.card, atk)
	var hp_all: int = _upgrade_hp_gain(p.card, hp)
	p.upgrade_atk += atk_all
	p.upgrade_hp += hp_all
	_add_upgrade_stack(p)          # R274：层数唯一口（堡垒按层数补血）
	p.card.health += hp_all
	p.health += hp_all
	if atk_all == 0 and hp_all == 0 and affix != "":
		# 纯挂字段的改造（共享护盾）：不印「力量 +0、生命 +0」这种废话。
		_log("%s：改造 %s → 挂上字段「%s」（第 %d 层）" % [
				source, p.card.card_name, affix, p.upgrade_stacks])
	else:
		_log("%s：改造 %s → 力量 +%d、生命 +%d（%d 攻 / %d 血，第 %d 层）" % [
				source, p.card.card_name, atk_all, hp_all, p.effective_power(), p.health,
				p.upgrade_stacks])
	action.emit("upgrade", {"cell": _cell_of(p), "card": p.card, "placement": p,
			"atk": atk_all, "hp": hp_all, "affix": affix})
	_on_unit_upgraded(p)
	_refresh_mnemosyne()   # R271：被改造的可能正是谟涅摩叙涅（X = 层数要立刻生效）


func _waste_bot_ping(p: Placement) -> void :
	## 废弃机器人（9152，R228）：**每次被改造** → 对它这一方的**所有敌方单位**
	## （= 玩家单位）各造成 WASTE_BOT_DMG 点伤害。
	## 伤害走 `_hit_unit`（与技能同口径：护盾 / 减伤 / 石肤照常生效），
	## 致死统一交给 `_destroy_dead()`（亡语 / 击杀记功与别处一致）。
	## ⚠️ 快照先取格子（`_hit_unit` 不删格，但 `_destroy_dead` 会 → 边遍历边删不安全）。
	var foe_side: String = SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var u: Placement = state.board[cell]
		if u != null and u.owner == foe_side:
			cells.append(cell)
	if cells.is_empty():
		_log("废弃机器人：被改造，但场上没有敌方单位可打")
		return
	cells.sort()
	var hits: int = 0
	for c: Vector2i in cells:
		var u2: Placement = state.board.get(c, null)
		if u2 == null or u2.health <= 0:
			continue
		var dmg: int = _hit_unit(u2, WASTE_BOT_DMG, "废弃机器人")
		hits += 1
		action.emit("waste_ping", {"cell": c, "amount": dmg,
				"name": u2.card.card_name, "side": foe_side})
	_log("废弃机器人：被改造 → 对所有敌方单位造成 %d 点伤害（%d 个目标）" % [
			WASTE_BOT_DMG, hits])
	_destroy_dead()


func _upgrade_unit(target, side:= SIDE_SELF) -> String :
	## 「升级」（8027，R82，机械之心）：改造一个**己方盟友或工事** →
	## +UPGRADE_ATK 攻 / +UPGRADE_HP 血，**再加这张卡自己的「改造奖励」**
	## （`CardData.upgrade_atk_bonus` / `upgrade_hp_bonus`：素体 +1 血、战斗骨骼 +2 力 +2 血）。
	##
	## 加成**记在 Placement 上、绝不烤进 CardData**（与栅栏修复术 R67 同一条纪律）：
	## 加攻进 `upgrade_atk`（直接进 effective_power，**不复用 atk_buff** ——
	## 那个被 GROW_CAP=5 封顶且语义是「成长光环」，改造必须能无限叠）；
	## 加血进 `upgrade_hp` 并同时抬 `p.card.health` 的**场上副本**与 `p.health`，
	## 离场时由 `_card_leaving_field` 统一减回去。
	##
	## R84：改造奖励读**卡面字段**而不是按卡名 / trait 硬编码 —— 加新卡填字段就行，引擎不用动。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能改造自己的单位"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "%s 不能被改造" % p.card.card_name
	# 场上那张卡换成**独立副本**再改数值：卡库里的卡是**共享实例**，
	# 直接改 `p.card.health` 会连卡库那份一起改（下一场、甚至本场后续再抽到就已是加血版）。
	# 无条件复制最省心 —— 哪怕它本来就是独立副本，多一次 from_dict 也不影响正确性。
	p.card = CardData.from_dict(p.card.to_dict())
	p.card.traits = (p.card.traits as Array).duplicate()
	# R120：改造奖励走**唯一口**（素体 +1 血 / 战斗骨骼 +2 力 +2 血 / 侦察塔不加攻）。
	var atk_gain: int = _upgrade_atk_gain(p.card, UPGRADE_ATK)
	var hp_gain: int = _upgrade_hp_gain(p.card, UPGRADE_HP)
	p.upgrade_atk += atk_gain
	p.upgrade_hp += hp_gain
	# 改造**层数**（R86）：被改造一次 +1 层。侦察塔（trait「改造层数」）靠它
	# 每层 +1 攻击伤害（见 Placement.effective_power）。离场不还原到卡上 ——
	# 它只记在 Placement 上，跟 upgrade_atk 一样是「只在场上有效」。
	# R274：「堡垒」的每层 +3 血不再在这里手写 —— 由层数唯一口按**当前层数**重算，
	# 手牌里攒的层数上场也能一次结清（差量记在 `stack_hp_applied`）。
	var stack_hp0: int = p.stack_hp_applied
	_add_upgrade_stack(p)
	var stack_hp_gain: int = p.stack_hp_applied - stack_hp0
	p.card.health += hp_gain
	p.health += hp_gain
	_log("升级：%s 被改造 → 力量 +%d、生命 +%d（%d 攻 / %d 血，第 %d 层）" % [
			p.card.card_name, atk_gain, hp_gain + stack_hp_gain,
			p.effective_power(), p.health, p.upgrade_stacks])
	action.emit("upgrade", {"cell": target, "card": p.card, "placement": p,
			"atk": atk_gain, "hp": hp_gain})
	# 「模仿者」8043（R92）：与它接通的我方模仿者获得**相同改造**。
	# 传的是 `atk_gain` / `hp_gain` —— 含受体自己的改造奖励（upgrade_*_bonus），
	# 但**不含**「堡垒」trait 的额外 +STACK_HP_PER：那是**受体自身**的特性，不该被模仿出去。
	_mimic_relay(p, atk_gain, hp_gain)
	# R391：无限装甲供能已收口到 `_on_unit_upgraded()`（统一后置口）——
	# 这里不再单独调，否则「升级」会触发一次、统一口再触发一次。
	_on_unit_upgraded(p)
	_refresh_mnemosyne()   # R271：谟涅摩叙涅被「升级」改造 → 敌方立刻多降一层
	_inspire_tick()   # R300 激发：升级 = 一次改造动作（一次动作只触发一次）
	return "%s 改造完成（+%d 攻 / +%d 血）" % [p.card.card_name, atk_gain, hp_gain]


func _feed_upgrade_card(p: Placement) -> void :
	## 「无限装甲」（8038，R89，trait「改造供能」）的**唯一入口**。
	##
	## 卡面：「每回合一次：这张卡被「改造」时，随机一张**效果含「改造」的技能卡**加入你的手牌，
	## 那张牌在手牌里**费用为 0**（离开手牌后恢复原价）。」
	##
	## 三个口径（用户当时已睡，按最合理方案定的 —— 见常量区的注释）：
	##  ① **固定给「升级」8027**（R276 用户口径，原先是从奖励池随机摇一张「效果含改造」
	##     的技能牌）。「升级」是初始卡 rarity=3、不入奖励池，所以按 id 直接取。
	##  ② **免费重置靠判据而非清标记**：写 `state.hand_free[card] = true`，
	##     由 `cost_of` 验「此刻是否还在手牌里」决定要不要给 0 费。离手口分散在
	##     play / use_spell / discard_hand / 乌鸦回手 … 共 10 处，逐个挂钩必漏一处。
	##  ③ **每回合一次**记 `p.upgrade_feed_turn`（比对 `turn_total`）——
	##     记在这个单位实例上，换一张装甲上场就有一份额度。
	##
	## 触发源 = `_on_unit_upgraded()`（**所有**改造入口的统一后置口，R391 收口）。
	##   * 技能改造：升级 8027 / 自我修复 8035 / 加厚装甲 8044 / 超越极限 8053 /
	##     共享护盾 8069 / 拾荒者 / 合体 / 辅助刃 / 隐藏能源；
	##   * 场外推动的改造：改装者 / 改造工厂 8037（每回合一次，被 `upgrade_feed_turn` 封顶）/
	##     模仿者 8043 的传导。
	## ⚠️ 「每回合一次」是这一层唯一的闸：没有它，改造工厂会让装甲每回合白吐一张「升级」。
	## ⚠️ R391 之前这里的口径是「只有 `_upgrade_unit` 算」，于是自我修复 / 共享护盾 /
	##    改造工厂改造它时都不供能（用户报「只有升级这一张卡触发」）。改口径时
	##    一并把 `_on_unit_upgraded()` 里所有改造入口都接上，别再逐个入口补。
	if p == null or p.card == null or not p.card.traits.has(INF_ARMOR_TRAIT):
		return
	# R210：**只有「场上的这张卡」被改造才生效**（用户口径）。
	# 桌外（手牌 / 牌库 / 弃牌区）的改造只把数值烤进那张卡：系统升级 8039 / 集体改造 8031 /
	# 批量传输 8040 / 回收 8064 / 返修 9127 / 生产订单 8048 / 自主升级 8045 / 代达罗斯 8060
	# （三区），**一律不供能**。以前这里只判「这个 Placement 带不带 trait」= 等于「谁被当成
	# 改造目标就供能」，一旦以后哪条桌外路径把升级传进来（例如手牌副本也能拿到 Placement），
	# 供能就会凭空触发。把「此刻在场上」写成显式守卫，规则才不依赖调用方的自觉。
	if p.owner != SIDE_SELF:
		return
	if state.unit_at(_cell_of(p)) != p:
		return
	if p.upgrade_feed_turn == turn_total:
		return    # 本回合已供过能
	# R276（用户口径）：**固定给「升级」8027**，不再从奖励池里随机摇一张改造牌。
	# 「升级」是初始卡（rarity 3，不入奖励池），所以必须直接用 id 取。
	var src: CardData = CardRepo.load_json().get_card(UPGRADE_ID)
	if src == null:
		_log("无限装甲：卡库里找不到「升级」8027，本回合供能落空")
		action.emit("inf_armor", {"card": null, "ok": false, "placement": p})
		return
	# ⚠️ **必须 from_dict 复制成独立实例**（卡库是共享实例）：直接 append 卡库那张
	# 会让 `hand_free` 的按实例标记串到别处，且以后改它会污染卡库。
	var got := CardData.from_dict(src.to_dict())
	got.traits = (got.traits as Array).duplicate()
	# R299：手牌满 → 这张「升级」直接进弃牌区（以前是「供能落空」，等于白产出一张）。
	# ⚠️ 仍然算「本回合已供过能」：产出的动作发生了，只是去处不同 —— 否则手牌一空出来，
	#    同一回合再被改造一次就又能白拿一张。
	if not _grant_to_hand(got, "无限装甲"):
		p.upgrade_feed_turn = turn_total
		action.emit("inf_armor", {"card": got, "ok": false, "placement": p})
		return
	state.hand_free[got] = true
	p.upgrade_feed_turn = turn_total
	_log("无限装甲：供能 —— 「%s」加入手牌，在手牌里费用为 %d"
		% [got.card_name, INF_ARMOR_FEED_COST])
	action.emit("inf_armor", {"card": got, "ok": true, "placement": p})


func _reorganize(target, side:= SIDE_SELF) -> String :
	## 「重组」（8051，R99，机械之心）：指定一个己方盟友或工事，回复至满生命。
	## 「满生命」= 当前场上最大生命 `card.health` —— 改造加的血已经烤进 `card.health`
	## （见 `_upgrade_unit`），`upgrade_hp` 只是离场还原用的记账字段，不能再叠加算一次。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能回复自己的单位"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "%s 不能被回复" % p.card.card_name
	var max_hp: int = p.card.health
	var before:= p.health
	p.health = max_hp
	_log("重组：%s 回复至满生命（%d → %d）" % [p.card.card_name, before, p.health])
	action.emit("reorganize", {"cell": target, "card": p.card, "placement": p})
	return "%s 回复至满生命" % p.card.card_name


func _transcend(target, side:= SIDE_SELF) -> String :
	## 「超越极限」（8053，R99，机械之心）：指定一个己方盟友或工事，挂上「超负荷」
	## 字段并算一层改造 —— 与「升级」8027 同口径，让体系把它当一次改造来反应。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能强化自己的单位"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "%s 不能被强化" % p.card.card_name
	if p.card.has_affix(AFFIX_OVERLOAD):
		return "%s 已拥有超负荷" % p.card.card_name
	# 换成独立副本再改（卡库共享实例纪律，与 _upgrade_unit 同）：否则直接改
	# `p.card.affixes` 会连卡库那份一起加字段，下一场/本场再抽到就已是超负荷版。
	p.card = CardData.from_dict(p.card.to_dict())
	p.card.traits = (p.card.traits as Array).duplicate()
	p.card.add_affix(AFFIX_OVERLOAD)
	_add_upgrade_stack(p)   # 算一层改造 → 侦察塔光环 / 堡垒按层数反应
	# R120：改造奖励走**唯一口**。超越极限自己不给攻/血，但**卡面自己**的改造奖励照给
	# （素体 +1 血）—— 以前这里写死 0/0，素体被它改造白挨。
	var atk_gain: int = _upgrade_atk_gain(p.card, 0)
	var hp_gain: int = _upgrade_hp_gain(p.card, 0)
	p.upgrade_atk += atk_gain
	p.upgrade_hp += hp_gain
	p.card.health += hp_gain
	p.health += hp_gain
	_log("超越极限：%s 获得改造·超负荷（第 %d 层改造，+%d 攻 / +%d 血）" % [
			p.card.card_name, p.upgrade_stacks, atk_gain, hp_gain])
	action.emit("transcend", {"cell": target, "card": p.card, "placement": p,
			"atk": atk_gain, "hp": hp_gain})
	# 「模仿者」8043（R92）：接通的我方模仿者获得相同改造（超负荷）。
	# affix 非空 → `_mimic_relay` 的 guard 放行（哪怕攻/血增益都是 0）。
	_mimic_relay(p, atk_gain, hp_gain, AFFIX_OVERLOAD)
	# R391：无限装甲供能走 `_on_unit_upgraded()` 统一口（这里不再单独调）。
	_on_unit_upgraded(p)
	_inspire_tick()   # R300 激发：超越极限 = 一次改造动作
	return "%s 获得超负荷" % p.card.card_name


func _reboot(target, side:= SIDE_SELF) -> String :
	## 「重启」（8054，R100，机械之心）：指定一个己方盟友或工事，返回手卡且费用变 0
	## （费用由 state.hand_free 标记，cost_of 用 hand.has(card) 判据在离手时自动恢复原价）。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能重启自己的单位"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "%s 不能被重启" % p.card.card_name
	# 离场还原（栅栏修复术/加厚装甲等场上加固不带走），拿回手卡的是原本那张卡。
	var back:= _card_leaving_field(p)
	# 切断与卡库共享引用（_card_leaving_field 在「无场上加成」时直接交还原实例）。
	back = CardData.from_dict(back.to_dict())
	back.traits = (back.traits as Array).duplicate()
	state.board.erase(target)
	if state.hand_full():
		_log("重启：%s 返回手卡被手牌上限挡下 → 进弃牌区" % p.card.card_name)
		state.discard.append(back)
		action.emit("reboot", {"cell": target, "card": p.card, "placement": p})
		return "%s 返回手卡被上限挡下，进弃牌区" % p.card.card_name
	state.hand.append(back)
	# ⚠️ 按实例标记「在手里期间免费」：cost_of 验 hand.has(back) → 打出/弃掉后自动原价。
	# 不烤 trait、不另开离手口清标记（与 R89 供能牌同口径）。
	state.hand_free[back] = true
	_log("重启：%s 返回手卡（0 费，离手重置）" % p.card.card_name)
	action.emit("reboot", {"cell": target, "card": p.card, "placement": p})
	return "%s 返回手卡（0 费）" % p.card.card_name


func _batch_upgrade(_side: String) -> String :
	## 「集体改造」（8031，R86 → R394 改名 / 加强）：**手牌 + 卡组（抽牌堆）**里
	## **所有盟友和工事**生命 +3。
	##
	## 口径（已与用户确认）：**整场战斗内一直有效** —— 回合结束弃回牌库、再抽到仍然带着加成。
	## 这自动成立，因为下一场战斗 `RunState.build_deck()` 会重新从**卡库**取实例。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再替换**：`build_deck` 用 `repo.get_card(id)`，
	## 那是**卡库共享实例**。直接 `state.hand[i].health += 1` 会把**卡库**那张一起改 ——
	## 于是本局之后、甚至下一局新 run 抽到那张卡都天生 +1 血（跨 run 泄漏）。
	##
	## **R209 记层**：每改一张就 `upgrade_stacks += 1`（随身带着）—— 旧版记「手牌里的卡
	## 还没上场、记层没意义」，结果这些卡上场后 `Placement.upgrade_stacks` 从 0 开始，
	## 侦察塔的光环（每层 +1 易伤）与卡面「改造 ×N」全看不到改造（用户实测报的缺陷）。
	## 层数**随卡走**（`CardData.upgrade_stacks`），上场由 `FieldState.place()` 接上。
	var touched := 0
	var names: Array[String] = []
	# ① 手牌
	for i in state.hand.size():
		var c: CardData = state.hand[i]
		if c.kind != "盟友" and not c.is_fort():
			continue
		var up := _batch_adapt(c)
		state.hand[i] = up
		touched += 1
		names.append("%s %d血" % [c.card_name, up.health])
	# ② 卡组（抽牌堆）—— R394 新增：用户口径「手牌和卡组所有盟友和工事卡全部生命 +3」。
	# 与手牌同一条改造口径（`_batch_adapt`），顺序不变，只换元素。
	for i in state.deck.size():
		var d: CardData = state.deck[i]
		if d.kind != "盟友" and not d.is_fort():
			continue
		var dup := _batch_adapt(d)
		state.deck[i] = dup
		touched += 1
		names.append("%s %d血" % [d.card_name, dup.health])
	if touched == 0:
		_log("集体改造：手牌和卡组里没有盟友或工事，效果落空")
		action.emit("batch_upgrade", {"count": 0, "cards": []})
		return "手牌和卡组里没有盟友或工事"
	# ⚠️ 必须显式声明成无类型 Array：slice() 返回的是 Array，不是 Array[String]，
	#    用 := 推断时编译器只按第一支的类型走，运行到第二支就会报 SCRIPT ERROR。
	var shown: Array = names if names.size() <= 6 else names.slice(0, 6) + ["等 %d 张" % names.size()]
	_log("集体改造：手牌 + 卡组 %d 张盟友/工事各 +%d 生命（%s）"
			% [touched, BATCH_UPGRADE_HP, "、".join(shown)])
	action.emit("batch_upgrade", {"count": touched, "cards": names})
	_inspire_tick()   # R300 激发：集体改造一次改满手 → 只算一次
	return "%d 张各 +%d 生命" % [touched, BATCH_UPGRADE_HP]


func _batch_adapt(c: CardData) -> CardData:
	## R394：「集体改造」对**单张卡**的改造口径（手牌与卡组共用，别各写一份）。
	## ⚠️ 必须 `from_dict` 复制成新实例：`build_deck` 给的是**卡库共享实例**，
	## 直接 `c.health += 3` 会把卡库那张一起改 —— 跨局泄漏（旧版踩过）。
	var up := CardData.from_dict(c.to_dict())
	# R120：改造奖励走**唯一口** —— 素体 / 战斗骨骼这类「改造即额外加成」的卡也算进来
	up.power += _upgrade_atk_gain(up, 0)
	up.health += _upgrade_hp_gain(up, BATCH_UPGRADE_HP)
	up.upgrade_stacks += 1        # R209：层数随身带（上场时由 place() 接到 Placement）
	return up


# ── R90：改造手牌（烤进 CardData，本场战斗永久）──

func _sys_upgrade_hand_card(hand_index: int) -> String :
	## 「系统升级」（8039，R90，机械之心 1 费稀有）：把**手牌里**选定的一张
	## 盟友 / 工事「改造」成 SYS_UPGRADE_COST_ADD(费用+1) / ATK(+3) / HP(+6)。
	##
	## 口径（已与用户确认）：
	##   * 只作用于**手牌里**的卡 —— 不扫牌库、不扫弃牌区（那是「批量传输」的事，也没有）。
	##   * 数值**烤进这张卡的副本**，**本场战斗永久**：打出后进牌库/弃牌区仍带着，
	##     之后再次抽到上场依然是加强版；下一场战斗 `build_deck()` 重新从卡库取
	##     实例 → 自动重置。**不需要** `_card_leaving_field` 参与（那是场上单位才走的）。
	##   * 费用 +1 **也是永久的**（用户口径「打出之后费用还加」）—— 代价与收益同口径。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再原位替换**：`build_deck` 用 `repo.get_card(id)`，
	## 那是**卡库共享实例**。直接 `state.hand[i].health += 6` 会把卡库那张一起改 ——
	## 于是本局之后、甚至下一局新 run 抽到那张卡都天生是加强版（跨 run 泄漏）。
	## 与「集体改造」8031 是同一套纪律。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（手牌序号无效）"
	var c: CardData = state.hand[hand_index]
	if c.kind != "盟友" and not c.is_fort():
		return "%s 不是盟友或工事，不能改造" % c.card_name
	var up := CardData.from_dict(c.to_dict())
	up.traits = (up.traits as Array).duplicate()   # 切断与卡库的共享引用
	up.cost += SYS_UPGRADE_COST_ADD
	# R120：改造奖励走**唯一口**（素体被「系统升级」也额外 +1 血）。
	var su_atk: int = _upgrade_atk_gain(up, SYS_UPGRADE_ATK)
	var su_hp: int = _upgrade_hp_gain(up, SYS_UPGRADE_HP)
	up.power += su_atk
	up.health += su_hp
	# R209：记一层「改造」随身带 —— 否则它上场后 `upgrade_stacks` 从 0 开始：
	# 侦察塔拿不到光环的 +1 易伤、卡面也看不到「改造 ×1」（用户实测报的缺陷）。
	up.upgrade_stacks += 1
	state.hand[hand_index] = up
	_log("系统升级：%s 改造完成（费用 +%d / 力量 +%d / 生命 +%d → %d 费 %d 攻 %d 血，本场战斗永久）"
		% [c.card_name, SYS_UPGRADE_COST_ADD, SYS_UPGRADE_ATK, SYS_UPGRADE_HP,
			up.cost, up.power, up.health])
	action.emit("sys_upgrade", {"card": up, "hand_index": hand_index,
		"cost_add": SYS_UPGRADE_COST_ADD, "atk": su_atk, "hp": su_hp})
	_inspire_tick()   # R300 激发：系统升级改造一张手牌 = 一次改造动作
	return "%s 改造完成（%d 费 / %d 攻 / %d 血）" % [up.card_name, up.cost, up.power, up.health]


func _lighten_hand_card(hand_index: int) -> String :
	## 「轻量化」（8068，R269，机械之心 2 费普通技能）：把**手牌里**选定的一张**盟友**
	## 「改造」成 费用 -1 / 移动速度 +1。
	##
	## 口径与「系统升级」8039 完全一致（用户口径「战斗内永久」）：
	##   * 只作用于**手牌**；数值**烤进这张卡的副本**，本场战斗永久 ——
	##     打出后进牌库 / 弃牌区仍带着，之后再次抽到上场依然是轻量版；
	##     下一场 `build_deck()` 重新从卡库取实例 → 自动重置。
	##   * 费用**下限 0**：0 费盟友不会被减成负费。
	##   * 算**一层改造**（`upgrade_stacks += 1`）：侦察塔 / 堡垒 / 无限装甲 / 模仿者照常响应。
	##   * 只吃**盟友**（用户原话「一个随从」）；工事移速恒为 0，减费也不是这张牌的本意。
	##
	## ⚠️ 必须 `from_dict` 复制成新实例再原位替换（同 8039 / 8031）：卡库是**共享实例**，
	## 直接改 `state.hand[i].cost` 会连卡库一起改 —— 跨 run 泄漏。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（手牌序号无效）"
	var c: CardData = state.hand[hand_index]
	if c.kind != "盟友":
		return "%s 不是盟友，不能轻量化" % c.card_name
	var up := CardData.from_dict(c.to_dict())
	up.traits = (up.traits as Array).duplicate()   # 切断与卡库的共享引用
	var cost_before: int = up.cost
	var speed_before: int = up.move_speed
	up.cost = maxi(0, up.cost + HAND_LIGHTEN_COST_DELTA)
	up.move_speed += HAND_LIGHTEN_SPEED_ADD
	# R272：轻量化也是「改造」→ 卡面改造奖励照算（战斗骨骼 +2 力 +2 血 / 素体 +1 血）。
	var li_atk: int = _upgrade_atk_gain(up, 0)
	var li_hp: int = _upgrade_hp_gain(up, 0)
	up.power += li_atk
	up.health += li_hp
	up.upgrade_stacks += 1        # 一层改造（同系统升级 8039）
	state.hand[hand_index] = up
	_log("轻量化：%s 改造完成（费用 %d → %d / 移速 %d → %d / 力量 +%d / 生命 +%d，本场战斗永久）" % [
			c.card_name, cost_before, up.cost, speed_before, up.move_speed, li_atk, li_hp])
	action.emit("lighten", {"card": up, "hand_index": hand_index,
			"cost": up.cost, "speed": up.move_speed, "atk": li_atk, "hp": li_hp})
	_inspire_tick()   # R300 激发：轻量化改造一张手牌 = 一次改造动作
	return "%s 改造完成（%d 费 / 移速 %d）" % [up.card_name, up.cost, up.move_speed]


func _batch_transfer(side: String) -> String :
	## 「批量传输」（8040，R90，机械之心 1 费稀有）：**手牌里所有**盟友 / 工事
	## 获得「改造」（力量 +1 / 生命 +4，**不涨费用**），**然后抽 1 张卡**。
	##
	## 与「集体改造」8031 的差别（R90 刻意做的升级版）：
	##   * 8031：只 +1 生命，**不抽牌**；
	##   * 8040：+1 力 / +4 血（**不加费**），**外加抽 1 张**。
	## 两者**都只改手牌**，都**烤进副本**，都**本场战斗永久**。
	##
	## ⚠️ 同 `_sys_upgrade_hand_card`：**必须 `from_dict` 复制 + 原位替换**，否则污染卡库。
	## ⚠️ 抽牌走 `_draw_many(1)`（唯一口，自带手牌满 / 牌库空检查）。
	##
	## 「卡组」口径（已与用户确认）：**卡组 = 抽牌库**；但这张卡**不扫牌库** ——
	## 它改的是**当时手牌里那些**，那些牌被弃回牌库后仍带着加成（因为改的是它自己那张副本）。
	var touched := 0
	var names: Array[String] = []
	for i in state.hand.size():
		var c: CardData = state.hand[i]
		if c.kind != "盟友" and not c.is_fort():
			continue
		var up := CardData.from_dict(c.to_dict())
		up.traits = (up.traits as Array).duplicate()
		# R273：**不再加费用**（用户口径：只 +1 力 +4 血）。
		# R120：改造奖励走**唯一口**（与「系统升级」同口径）。
		up.power += _upgrade_atk_gain(up, BATCH_TRANSFER_ATK)
		up.health += _upgrade_hp_gain(up, BATCH_TRANSFER_HP)
		up.upgrade_stacks += 1        # R209：层数随身带（同系统升级）
		state.hand[i] = up
		touched += 1
		names.append("%s（%d 费 %d 攻 %d 血）" % [c.card_name, up.cost, up.power, up.health])
	# 抽 1 张 —— ⚠️ **无论有没有改造到手都要抽**（卡面写的是「使用时抽 1 张卡」）。
	# 所以这里不能提前 return：原来「touched == 0 就 return」的写法会让
	 # 「手牌里一个盟友都没有」时**连牌都不抽**，与卡面不符（实测抽 0 张）。
	var got := _draw_many(BATCH_TRANSFER_DRAW)
	if touched == 0:
		_log("批量传输：手牌里没有盟友或工事，改造落空（仍抽 %d 张卡）" % got)
		action.emit("batch_transfer", {"count": 0, "cards": [], "draw": got})
		return "手牌里没有盟友或工事（抽 %d 张卡）" % got
	_log("批量传输：手牌 %d 张盟友/工事改造（力量 +%d / 生命 +%d，不加费用）"
		% [touched, BATCH_TRANSFER_ATK, BATCH_TRANSFER_HP])
	_log("批量传输：%s；抽 %d 张卡" % ["、".join(names), got])
	action.emit("batch_transfer", {"count": touched, "cards": names, "draw": got})
	_inspire_tick()   # R300 激发：批量传输一次改满手 → 只算一次
	return "%d 张手牌改造，抽 %d 张卡" % [touched, got]


# ── R209：手牌目标的「选哪张」不再由引擎存 pending ──
# R90 曾有一套 `sys_upgrade_start/pick` + `sys_upgrade_pending`（引擎自己记 pending），
# 但界面后来改走 `cast_sys_upgrade(手牌序号, 目标手牌序号)`（更简单、且回放只需一条 act），
# 那套 pending **一次都没被调用过**，留着只会让「选卡只有一个入口」这条纪律多一个岔口。
# 现在两种手牌目标卡的选卡交互统一走**全屏选卡页**（`battle_scene._pick_active_kind`），
# 引擎侧只保留结算入口：`cast_sys_upgrade` / `cast_recycle`。


func _energy_barrier(side: String) -> String :
	## 「能量屏障」（8033，R87，机械之心）：从**抽牌堆**随机一张**还没有能量屏障**的
	## 盟友 / 工事，给它加上这个 trait → 它**上场时**获得「首次受伤免掉」的一次性护盾。
	##
	## 口径（已与用户确认）：**一次性护盾** —— 本场战斗中第一次受到的伤害完全免掉，
	## 之后恢复正常、护盾消失（拦截点唯一 = `_hit_unit` 开头）。
	##
	## 判据「没有此能力」= 卡上没带 BARRIER_TRAIT（与「过载」判 actions 同一套路）。
	## ⚠️ **必须 `from_dict` 复制再原位替换**：卡库是**共享实例**，直接改会跨 run 泄漏。
	## 原位替换（不抽到手上）让牌库顺序 / 洗牌序列不变 → 同一种子重跑必然一致（同「过载」）。
	var cand: Array[int] = []
	for i in state.deck.size():
		var c: CardData = state.deck[i]
		if c.kind != "盟友" and not c.is_fort():
			continue
		if c.traits.has(BARRIER_TRAIT):
			continue
		cand.append(i)
	if cand.is_empty():
		# R276：即使没有可改造的卡，**抽牌照常结算**（抽牌是这张牌自己的效果，
		# 不该因为改造落空就一起白吃）。
		var missed: int = _draw_many(BARRIER_DRAW)
		_log("能量屏障：抽牌堆里没有「还没有能量屏障」的盟友/工事，效果落空；抽了 %d 张牌" % missed)
		action.emit("barrier_grant", {"card": null, "ok": false, "drawn": missed})
		return "抽牌堆里没有可改造的卡（抽了 %d 张）" % missed
	var pick: int = cand[rng.randi() % cand.size()]
	var before: CardData = state.deck[pick]
	var up := CardData.from_dict(before.to_dict())
	up.traits = (up.traits as Array).duplicate()   # 切断与卡库的共享引用
	up.traits.append(BARRIER_TRAIT)
	# R91 字段系统：护盾也是一个**字段** → 写进 `affixes`，于是卡面 / 战场 / 悬停
	# 三处自动显示「护盾」，**不需要**在这里手写任何文案。
	# 这就是「字段效果由别的卡后续赋予」也能被看到的关键。
	if not up.has_affix(FIELD_BARRIER):
		up.affixes.append(FIELD_BARRIER)
	state.deck[pick] = up
	# R276：改造完**再抽 BARRIER_DRAW 张**（用户口径「新增抽 3 张卡」）。
	# 放在改造之后：抽到的那几张里若有盟友 / 工事，不会在同一张牌里被顺手加盾
	# （卡面写的是「从抽牌堆里随机改造一张」—— 那一刻抽牌堆还没抽）。
	var drawn: int = _draw_many(BARRIER_DRAW)
	_log("能量屏障：「%s」获得能量屏障（下次上场时第一次挨打完全免掉）；抽了 %d 张牌"
		% [before.card_name, drawn])
	action.emit("barrier_grant", {"card": up, "ok": true, "from": before, "side": side,
		"drawn": drawn})
	return "%s 获得能量屏障（抽 %d 张）" % [before.card_name, drawn]


func _self_repair(target, side:= SIDE_SELF) -> String :
	## 「自我修复」（8035，R87，机械之心）：改造**场上的一个己方盟友** →
	## +SELF_REPAIR_HP 最大生命 + 每回合结束回 SELF_REPAIR_REGEN 生命。
	##
	## 两项都**只在场上有效**（用户口径）：+2 血并进 `upgrade_hp`（离场由
	## `_card_leaving_field` 减回去），回血记在 `Placement.regen`（单位离场自然不带）。
	##
	## ⚠️ 只吃**盟友**（用户原话「一个盟友」），工事不能选 —— 与「升级」（可改工事）不同。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能修复自己的单位"
	if p.card.kind != "盟友":
		return "%s 不是盟友" % p.card.card_name
	# 场上那张换成独立副本再改（卡库是共享实例）
	p.card = CardData.from_dict(p.card.to_dict())
	p.card.traits = (p.card.traits as Array).duplicate()
	# R120：改造奖励走**唯一口** —— 以前这里只加 SELF_REPAIR_HP，素体被「自我修复」
	# 改造白挨 +1 血（用户报的缺陷）。
	var atk_gain: int = _upgrade_atk_gain(p.card, 0)
	var hp_gain: int = _upgrade_hp_gain(p.card, SELF_REPAIR_HP)
	p.upgrade_atk += atk_gain
	p.upgrade_hp += hp_gain
	_add_upgrade_stack(p)        # 也算一次改造（用户口径：任何改造手段都记层）
	p.card.health += hp_gain
	p.health += hp_gain
	p.regen += SELF_REPAIR_REGEN
	_log("自我修复：%s → 最大生命 +%d（%d）、每回合结束回 %d（%d/%d）" % [
			p.card.card_name, hp_gain, p.card.health, SELF_REPAIR_REGEN,
			p.health, p.card.health])
	# 「模仿者」8043（R92）：自我修复**也算一次改造**（用户口径：所有此类卡都算）→
	# 接通的模仿者复制**最大生命**那半（+SELF_REPAIR_HP）；
	# **不复制 `regen`** —— 每回合回 4 是这张技能给的治疗，不是「改造」的量。
	_mimic_relay(p, atk_gain, hp_gain)
	action.emit("self_repair", {"cell": target, "card": p.card, "placement": p,
			"hp": hp_gain, "regen": SELF_REPAIR_REGEN, "side": side})
	_on_unit_upgraded(p)
	_inspire_tick()   # R300 激发：自我修复 = 一次改造动作
	return "%s 自我修复完成（+%d 血 / 每回合回 %d）" % [
			p.card.card_name, hp_gain, SELF_REPAIR_REGEN]


func _armor_plate(target, side:= SIDE_SELF) -> String :
	## 「加厚装甲」（8044，R95，机械之心 1 费普通技能）：使**场上的一个己方盟友**
	## 获得改造：生命 +ARMOR_PLATE_HP（**再加它自己的 `upgrade_hp_bonus`** ——
	## 那张卡的「被改造时额外加成」，素体 +1 血那种，读卡面字段不硬编码）。
	##
	## ⚠️ **只吃盟友**（用户原话「一个我方盟友」），工事会被拒 —— 与「升级」8027 不同。
	##
	## 加成**记在 Placement 上、绝不烤进 CardData**（与 `_upgrade_unit` 同一条纪律）：
	## 加血进 `upgrade_hp` 并抬 `p.card.health`（场上副本）与 `p.health`，
	## 离场由 `_card_leaving_field` 统一减回去。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能改造自己的单位"
	if p.card.kind != "盟友":
		return "%s 不是盟友" % p.card.card_name
	# 场上那张换成独立副本再改（卡库是共享实例，直接改会跨 run 泄漏）
	p.card = CardData.from_dict(p.card.to_dict())
	p.card.traits = (p.card.traits as Array).duplicate()
	# R120：走**唯一口**（原来是手写的 `p.card.upgrade_*_bonus`，容易与别的入口分叉）。
	var atk_gain: int = _upgrade_atk_gain(p.card, 0)
	var hp_gain: int = _upgrade_hp_gain(p.card, ARMOR_PLATE_HP)
	p.upgrade_atk += atk_gain
	p.upgrade_hp += hp_gain
	# 算一层改造（用户口径）：侦察塔每层 +1 攻、模仿者传导、无限装甲供牌都靠它。
	# R274：堡垒的「每层 +3 生命」不在这里手写，由层数唯一口按新层数重算。
	_add_upgrade_stack(p)
	p.card.health += hp_gain
	p.health += hp_gain
	# R275：额外给「受到伤害 -1（至少 1）」—— 记 Placement（本场累计、只算场上）。
	p.dmg_reduce += ARMOR_PLATE_REDUCE
	_log("加厚装甲：%s 被改造 → 生命 +%d（%d 血）、受伤 -%d（累计 -%d），第 %d 层" % [
			p.card.card_name, hp_gain, p.health, ARMOR_PLATE_REDUCE,
			p.dmg_reduce, p.upgrade_stacks])
	action.emit("upgrade", {"cell": target, "card": p.card, "placement": p,
			"atk": atk_gain, "hp": hp_gain})
	# 「模仿者」8043（R92）：接通的模仿者获得**相同改造**。
	# 传 atk_gain / hp_gain —— 含受体自己的改造奖励，**不含**「堡垒」的额外 +STACK_HP_PER
	# （那是受体自身的特性，不该被模仿出去）。
	_mimic_relay(p, atk_gain, hp_gain)
	# R391：无限装甲供能走 `_on_unit_upgraded()` 统一口（这里不再单独调）。
	_on_unit_upgraded(p)
	_inspire_tick()   # R300 激发：加厚装甲 = 一次改造动作
	return "%s 加装完成（+%d 血 / 受伤 -%d）" % [
			p.card.card_name, hp_gain, ARMOR_PLATE_REDUCE]


func _shared_shield(target, side:= SIDE_SELF) -> String :
	## 「共享护盾」（8069，R269，机械之心 0 费稀有技能）：使**场上的一个己方盟友**
	## 获得改造：挂上字段「共享护盾」+ 算一层改造。
	##
	## 字段语义（用户口径「代替自己 HP 承受伤害」）：**我方 HP 要掉血时，改由它挨打**。
	## 判据唯一口 = `absorbs_for_hp()`（与森林守护 / 大树守卫 / 铁栅栏同一条通道）→
	## 引擎结算与战场绿环自动同源，这里不写任何显示代码。
	## ⚠️ 只吃**盟友**（用户原话「一个随从」）；工事不是随从。
	## ⚠️ 同一张卡重复给没有意义 → 已有该字段时直接拒绝（不白扣费用、也不刷改造层数）。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能改造自己的单位"
	if p.card.kind != "盟友":
		return "%s 不是盟友" % p.card.card_name
	if p.card.has_affix(AFFIX_SHARED_SHIELD):
		return "%s 已经有共享护盾了" % p.card.card_name
	# 走**场上改造唯一口**（R228）：复制副本 + 一层改造 + `_on_unit_upgraded()`
	# （侦察塔 / 堡垒 / 无限装甲 / 模仿者照常响应）。数值 +0，只挂字段。
	_field_upgrade_grant(p, 0, 0, "共享护盾", AFFIX_SHARED_SHIELD)
	_inspire_tick()   # R300 激发：共享护盾 = 一次改造动作
	_log("共享护盾：%s 获得字段「共享护盾」→ 我方 HP 将受到的伤害改由它承受" % p.card.card_name)
	action.emit("shared_shield", {"cell": target, "card": p.card})
	return "%s 获得共享护盾（替我方 HP 承伤）" % p.card.card_name


func _auto_upgrade(side: String) -> void :
	## 「自主升级」（8045，R95，机械之心 2 费效果卡）的唯一结算口，挂在 `_begin_turn()`。
	##
	## **R275 改口径**：候选从 `state.deck`（抽牌堆）改为 `state.hand`（**手牌**），
	## 数值 +2 攻 / +1 血 → **+1 攻 / +3 血**（用户口径「改为随机手卡而非抽牌库」）。
	## 手牌里的强化**本场有效**（洗回去再抽到仍是强化版），与「系统升级」8039 同口径。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再原位替换**：手牌里的卡可能是卡库共享实例，
	## 直接改 `state.hand[i].power` 会连**卡库**那份一起改（跨 run 泄漏）。
	##
	## 原位替换不改手牌顺序 → 洗牌序列不变，同一种子重跑必然一致。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	if not _zone_has(zone, AUTO_UPGRADE_TRAIT):
		return
	var hand: Array[CardData] = state.hand   # 敌方没有自己的手牌，与旧实现（都读 state.deck）同口径
	var cand: Array[int] = []
	for i in hand.size():
		var c: CardData = hand[i]
		if c.kind == "盟友" or c.is_fort():
			cand.append(i)
	if cand.is_empty():
		_log("自主升级：手牌里没有盟友 / 工事，本回合落空")
		action.emit("auto_upgrade", {"card": null, "ok": false, "side": side})
		return
	var pick: int = cand[rng.randi() % cand.size()]
	var before: CardData = hand[pick]
	var up := CardData.from_dict(before.to_dict())
	# R120：改造奖励走**唯一口**（牌库里的素体被改造也额外 +1 血）。
	var au_atk: int = _upgrade_atk_gain(up, AUTO_UPGRADE_ATK)
	var au_hp: int = _upgrade_hp_gain(up, AUTO_UPGRADE_HP)
	up.power += au_atk
	up.health += au_hp
	up.upgrade_stacks += 1       # R209：手牌里的改造同样记层（上场就有层）
	hand[pick] = up              # 原位替换：手牌顺序不变
	_log("自主升级：「%s」在手牌里被改造 → 力量 +%d（%d）、生命 +%d（%d）" % [
			before.card_name, au_atk, up.power, au_hp, up.health])
	action.emit("auto_upgrade", {"card": up, "ok": true, "from": before, "side": side})
	_inspire_tick()   # R300 激发：自主升级改造一张 = 一次改造动作


func _regen_tick(side: String) -> void :
	## **每回合结束回血**的唯一口（R87）——「自我修复」8035 给的 `Placement.regen`。
	## 口径：只结算 `p.owner == side` 的单位（「自己回合结束」）；
	## 满血 `continue`（不越界、不刷噪声）；回血上限读 `p.card.health`（当前卡面上限）。
	##
	## R135：多了第二个来源 ——「太阳熔炉」的赫利俄斯（9130）在场时，本方的量产型俄倪厄
	## （9131）每回合额外回 `SUN_FORGE_REGEN` 点。两者**相加走同一次收尾**
	## （满血跳过 / `mini` 夹上限），所以「自我修复 + 赫利俄斯」不会互相顶掉，也不会越界。
	## ⚠️ 光环是**实时判定**的（每回合读一次场面），拆掉赫利俄斯下个回合就断 —— 不需要
	## 在离场处回收，因此这条不会重蹈「把场上加成烤进 CardData」的覆辙。
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side:
			continue
		var aura: int = 0
		var origin := "自我修复"
		if p.card.id == SUN_FORGE_FURY_ID and state.has_sun_forge(side):
			aura = SUN_FORGE_REGEN
			origin = "太阳熔炉"
		# R233：卡面自带的「每回合结束回血」（犀牛 9016 = 2）—— 与自我修复 / 太阳熔炉
		# 相加走同一次收尾（满血跳过 / mini 夹上限），三者互不顶掉、也不会越界。
		if p.regen <= 0 and p.card.regen_per_turn > 0 and aura <= 0:
			origin = "自身"
		var amount: int = p.regen + p.card.regen_per_turn + aura
		if amount <= 0:
			continue
		if p.health >= p.card.health:
			continue
		var before: int = p.health
		p.health = mini(p.card.health, p.health + amount)
		var got: int = p.health - before
		_log("%s：%s回复 %d 点生命（%d / %d）" % [
				p.card.card_name, origin, got, p.health, p.card.health])
		action.emit("regen", {"cell": cell, "card": p.card, "amount": got,
			"hp": p.health, "max_hp": p.card.health, "side": side})


func _charge_tick(side: String) -> void :
	## 「充电装置」（8041，R91，机械之心 1 费工事 1/1/1）的唯一结算口，
	## 挂在 `end_turn()` 的 `_regen_tick` 旁边。
	##
	## 「**接通**」= **闪电链 `_connected_components()` 的四方向相邻连通关系**，
	## 但**只算我方单位**（闪电链不分敌我，用户口径收窄为「接通的我方盟友和工事」）。
	## 具体做法：遍历每个连通分量，**只要其中有充电装置**，
	## 该分量里**所有我方单位**都回复 —— 这正是「相邻传染」的语义，
	## 也天然支持「两个充电装置隔一格共享中间那个单位」。
	##
	## 口径与 `_regen_tick` 一致：只结算 `p.owner == side`（自己回合结束）、
	## 满血跳过、上限读 `p.card.health`（被改造过的上限更高 → 能回更多）。
	var healed := 0
	for comp: Array in _connected_components():
		# 这个分量里有没有充电装置？
		var has_charger := false
		for cell: Vector2i in comp:
			var q: Placement = state.unit_at(cell)
			if q != null and q.card.id == CHARGE_STATION_ID:
				has_charger = true
				break
		if not has_charger:
			continue
		for cell2: Vector2i in comp:
			var p: Placement = state.unit_at(cell2)
			# 只算我方（这是「接通」与闪电链的关键差别）
			if p == null or p.owner != side or p.owner != SIDE_SELF:
				continue
			if p.health >= p.card.health:
				continue     # 满血：不做（避免「回复 0」噪声）
			var before: int = p.health
			p.health = mini(p.card.health, p.health + CHARGE_HEAL)
			var got: int = p.health - before
			healed += 1
			_log("%s：被充电装置接通，回复 %d 点生命（%d / %d）" % [
				p.card.card_name, got, p.health, p.card.health])
			action.emit("charge_heal", {"cell": cell2, "card": p.card,
				"amount": got, "hp": p.health, "max_hp": p.card.health, "side": side})
	if healed > 0:
		_log("充电装置：%d 个接通的己方单位回复了生命" % healed)


func _component_of_cell(cell: Vector2i) -> Array[Vector2i]:
	## **「接通」判定的公共助手**（R92）—— 返回 `cell` 所在的那个连通分量（含自身）。
	## 「接通」一律是闪电链 `_connected_components()` 的四方向相邻关系
	## （隔着敌方单位也算连通），三张接通类卡（8041 / 8042 / 8043）共用这一份，别各写扫描。
	## 找不到返回空数组。
	for comp: Array in _connected_components():
		for c: Vector2i in comp:
			if c == cell:
				return comp
	return [] as Array[Vector2i]


func _shield_gen_for(p: Placement) -> Placement:
	## **护盾生成器**（8042，R92，机械之心 2 费普通工事 0/9/0）的选取口。
	## 卡面：「接通的我方单位受到伤害时，改为让这张卡承受（溢出部分不再结算）」。
	## 四个判据：① **只护我方**（用户口径，与充电装置一致）；
	## ② 必须与 p 在**同一连通分量**；③ p 自己是生成器时不参与（否则重复扣自己）；
	## ④ 多张候选取**剩余血量最多**的（最能扛的先上），血相同取离 p 最近、再按格子序 —— 保证确定性。
	## 返回 null = 没人挡。
	if p == null or p.owner != SIDE_SELF:
		return null
	var cell:= _cell_of(p)
	if cell.x < 0:
		return null
	var best: Placement = null
	var best_hp:= -1
	var best_dist:= 1 << 30
	var best_cell:= Vector2i(-1, -1)
	for c: Vector2i in _component_of_cell(cell):
		var q: Placement = state.unit_at(c)
		if q == null or q == p or q.card.id != SHIELD_GEN_ID or q.owner != SIDE_SELF:
			continue
		if q.health <= 0:
			continue
		var dist: int = absi(cell.x - c.x) + absi(cell.y - c.y)
		var better:= false
		if best == null:
			better = true
		elif q.health > best_hp:
			better = true
		elif q.health == best_hp and dist < best_dist:
			better = true
		elif q.health == best_hp and dist == best_dist \
				and (c.y < best_cell.y or (c.y == best_cell.y and c.x < best_cell.x)):
			better = true
		if better:
			best = q
			best_hp = q.health
			best_dist = dist
			best_cell = c
	return best


func _mimic_relay(src: Placement, atk_gain: int, hp_gain: int, affix: String = "") -> void :
	## **模仿者**（8043，R92，机械之心 2 费史诗盟友 0/10/1/1）的唯一结算口。
	## 卡面：「与这张卡接通的盟友获得改造时，这张卡获得相同改造」。
	##
	## ⚠️ 挂在**所有会给场上单位加改造的地方**（用户口径：所有此类卡都算），共三处：
	##   `_upgrade_unit`（升级 8027）/ `_self_repair`（自我修复 8035）/
	##   `_field_aura_tick` 的持续改造分支（改造工厂 8037）。
	##   R99 新增：`_transcend`（超越极限 8053）—— 它给的改造**没有攻/血增益**，
	##   所以额外传 `affix` 参数（如 AFFIX_OVERLOAD）让模仿者也挂上同一字段。
	##
	## ⚠️ **不连锁**（用户口径）：这里给模仿者的加成是**直接落字段**、
	## 不会再调一次 `_mimic_relay`，所以「模仿者 → 另一张模仿者」的传播天然不存在。
	## 两张模仿者同时与受害者接通时，**各自独立**复制一次（不是 A 传给 B）。
	if src == null or src.owner != SIDE_SELF:
		return
	if atk_gain <= 0 and hp_gain <= 0 and affix == "":
		return
	var cell:= _cell_of(src)
	if cell.x < 0:
		return
	for c: Vector2i in _component_of_cell(cell):
		var q: Placement = state.unit_at(c)
		if q == null or q == src or q.card.id != MIMIC_ID or q.owner != SIDE_SELF:
			continue
		# 卡库是共享实例 → 先换成独立副本（与 _upgrade_unit 同一条纪律）
		q.card = CardData.from_dict(q.card.to_dict())
		q.card.traits = (q.card.traits as Array).duplicate()
		if atk_gain > 0:
			q.upgrade_atk += atk_gain
		if hp_gain > 0:
			q.upgrade_hp += hp_gain
			q.card.health += hp_gain
			q.health += hp_gain
		if affix != "":
			q.card.add_affix(affix)
		_add_upgrade_stack(q)   # R274：层数唯一口（模仿者若带堡垒 trait 也照算）
		_on_unit_upgraded(q)
		_log("模仿者模仿 %s 的改造：+%d 攻 / +%d 血（现在是 %d 攻 / %d 血）" % [
				src.card.card_name, atk_gain, hp_gain, q.effective_power(), q.health])
		action.emit("mimic_upgrade", {"cell": c, "card": q.card, "placement": q,
				"from": src.card.card_name, "atk": atk_gain, "hp": hp_gain})


func _aether_guard_enter(p: Placement) -> void :
	var n:= mini(state.effects.size(), AETHER_GUARD_CAP)
	if n <= 0:
		_log("大树守卫：效果区没有效果卡，未获得加成")
		return
	p.atk_buff += n
	p.health += 2 * n
	_log("大树守卫：效果区 %d 张效果卡 → +%d 力量、+%d 生命（%d/%d）" % [
		state.effects.size(), n, 2 * n, p.effective_power(), p.health])
	action.emit("aether_guard", {"n": n, "card": p.card})


func _contractor_enter(p: Placement) -> void :
	## 契约签订者（8024，R63）登场：回复 CONTRACTOR_GAIN 点费用，
	## 同时**本回合**手卡里所有卡费用 +CONTRACTOR_RAISE（涨价）。
	## 涨价记在 FieldState.turn_card_raise（全体手卡，不按实例）→ cost_of 唯一读取口，
	## 回合结束随 end_turn 清零，不跨回合。
	## 挂在 play_from_hand 的「盟友」分支：卡此时已离手，涨价不会算到它自己头上。
	state.energy += CONTRACTOR_GAIN
	state.turn_card_raise = CONTRACTOR_RAISE
	_log("%s 登场：费用 +%d；本回合手卡费用 +%d（回合结束失效）" % [
		p.card.card_name, CONTRACTOR_GAIN, CONTRACTOR_RAISE])
	action.emit("contractor", {"cell": _cell_of(p), "energy": CONTRACTOR_GAIN,
		"raise": CONTRACTOR_RAISE, "name": p.card.card_name})


func _demon_fetch(_p: Placement) -> void :
	var cand: Array[int] = []
	for i in state.deck.size():
		if state.deck[i].is_effect():
			cand.append(i)
	if cand.is_empty():
		_log("水元素：卡组里没有效果卡")
		return
	var pick: int = cand[rng.randi() % cand.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	# R281：这条路径**绕开了 `FieldState.draw()`**，取到的是卡库共享实例 —— 直接给「它」
	# 减费会串到所有同名卡。先换成独立副本再记减费。
	if not chosen.own_copy:
		var own := CardData.from_dict(chosen.to_dict())
		own.own_copy = true
		chosen = own
	# R299：手牌满 → 这张效果卡直接进弃牌区。减费标记**照旧挂在它身上**（本场永久），
	# 之后洗回牌库再抽到仍然便宜 —— 与卡面「它的费用 -N」的口径一致。
	_grant_to_hand(chosen, "水元素")
	state.card_discount[chosen] = int(state.card_discount.get(chosen, 0)) + DEMON_FETCH_DISCOUNT
	_log("水元素：从卡组取到效果卡「%s」，它的费用 -%d" % [
		chosen.card_name, DEMON_FETCH_DISCOUNT])
	action.emit("demon_fetch", {"card": chosen})


func _owl_fetch() -> void :
	var cand: Array[int] = []
	for i in state.deck.size():
		if state.deck[i].is_effect():
			cand.append(i)
	if cand.is_empty():
		_log("猫头鹰：卡组里没有效果卡")
		return
	var pick: int = cand[rng.randi() % cand.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	# R299：手牌满 → 直接进弃牌区（不再「满就落空」，白丢这次取牌）
	_grant_to_hand(chosen, "猫头鹰")
	_log("猫头鹰：从卡组取到效果卡「%s」" % chosen.card_name)
	action.emit("owl_fetch", {"card": chosen})


func _sprite_trigger() -> void :
	state.self_next_effect_reduction = SPRITE_EFFECT_DISCOUNT
	_log("小精灵：本回合下一张效果卡费用 -%d" % SPRITE_EFFECT_DISCOUNT)


func _fox_trigger() -> void :
	## 赤狐（9034）。
	_fetch_skill_card("赤狐")


func _apprentice_fetch() -> void :
	## 魔法学徒（9081）：与赤狐 9034 同一套机制。
	_fetch_skill_card("魔法学徒")


func _fetch_skill_card(source: String) -> void :
	## 「从卡组取一张随机技能牌进手，**且只有这一张**本回合费用 -1」——
	## 赤狐 9034 与魔法学徒 9081 的**唯一入口**（两卡效果相同，别再各写一份）。
	##
	## R65 改：减费记在 state.turn_card_discount（按**实例**的本回合减费表），
	## 不再挂 state.self_cost_reduction（全局「本回合出牌费用 -N」）——
	## 后者会让本回合**所有**出牌都变便宜，与卡面描述不符。
	## 取到的牌先 from_dict 复制成独立实例再挂减费：卡库里是**共享实例**，
	## 直接挂会把同名的另一张（比如牌组里第二张同名牌）一起便宜掉。
	## 显示 = 判定 = 实扣都走 cost_of；回合结束随 turn_card_discount 清空 → 不跨回合。
	var skill_idx: Array[int] = []
	for i in state.deck.size():
		var dc: CardData = state.deck[i]
		if dc.kind == "技能":
			skill_idx.append(i)
	if skill_idx.is_empty():
		_log("%s：牌组里没有技能牌可抽取" % source)
		return
	var pick:= skill_idx[rng.randi() % skill_idx.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	var copy:= CardData.from_dict(chosen.to_dict())
	# R299：手牌满 → 直接进弃牌区；减费标记照旧挂着（本回合有效，回合结束清空）。
	_grant_to_hand(copy, source)
	state.turn_card_discount[copy] = int(state.turn_card_discount.get(copy, 0)) \
			+ FETCH_SKILL_DISCOUNT
	_log("%s：从卡组取到技能牌「%s」（**本回合仅这一张**费用 -%d）"
			% [source, copy.card_name, FETCH_SKILL_DISCOUNT])
	action.emit("fetch_skill", {"card": copy, "discount": FETCH_SKILL_DISCOUNT,
		"source": source})


func _dove_trigger() -> void :
	state.self_next_ally_reduction = TURTLE_DOVE_DISCOUNT
	_log("斑鸠：本回合下一个盟友费用 -%d" % TURTLE_DOVE_DISCOUNT)


func _overload_grant(side: String) -> String :
	## 「过载」（8030，R85，机械之心）：从**牌库**里随机一张「还没有一回合行动两次」的盟友，
	## 给它加上这个特性（**永久**改牌，之后每次抽到它上场都是双动）。
	##
	## 口径（已与用户确认）：
	##   * 候选**只从 `state.deck`（抽牌堆）**里选 —— 与 `_fetch_skill_card`（赤狐 / 魔法学徒）
	##     「从卡组取一张技能牌」同口径。手牌 / 弃牌区里的盟友不参与。
	##   * 选中后**原位替换**：不抽到手上、不改变牌库顺序 → 洗牌序列不变，同种子必然一致。
	##   * 「一回合行动两次」判据 = `CardData.actions >= DOUBLE_ACTION`（**没有**对应 trait）。
	##   * 一个候选都没有（牌库里全是双动盟友 / 没有盟友）→ **效果落空**，不消耗任何额外东西。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再替换**：卡库里是**共享实例**，直接改
	## `state.deck[i].actions` 会连**卡库**那份一起改 —— 于是本场战斗之后、甚至下一场战斗
	## 抽到那张卡就已经是双动了（等于把「过载」变成永久强化，且跨 run 泄漏）。
	var cand: Array[int] = []
	for i in state.deck.size():
		var c: CardData = state.deck[i]
		if c.kind == "盟友" and c.actions < DOUBLE_ACTION:
			cand.append(i)
	if cand.is_empty():
		_log("过载：牌库里没有「没有一回合行动两次」的盟友，效果落空")
		action.emit("overload", {"card": null, "ok": false})
		return "牌库里没有可改造的盟友"
	var pick: int = cand[rng.randi() % cand.size()]
	var before: CardData = state.deck[pick]
	var up := CardData.from_dict(before.to_dict())
	up.actions = DOUBLE_ACTION
	# R91 字段系统：双动 = 字段「疾行」→ 卡面 / 战场 / 悬停自动显示，
	# **不需要**为「被过载改过的牌」单独写一套文案。
	if not up.has_affix(AFFIX_SWIFT):
		up.affixes.append(AFFIX_SWIFT)
	state.deck[pick] = up        # 原位替换：牌库顺序不变
	_log("过载：「%s」获得一回合行动两次（牌库里的那张，之后每次抽到都双动）"
			% before.card_name)
	action.emit("overload", {"card": up, "ok": true, "from": before})
	return "%s 现在一回合行动两次" % before.card_name


func discard_cost_of(card: CardData) -> int:
	return HERO_DISCARD if card.id == HERO_CARD_ID else 0


func can_play_from_hand(hand_index: int) -> bool:


	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var card: CardData = state.hand[hand_index]
	if not can_pay_card(card):
		return false
	if not can_use_card(card):
		return false
	return state.hand.size() - 1 >= discard_cost_of(card)


func play_hero_from_hand(hand_index: int, cell: Vector2i, drop_indexes: Array) -> Placement:




	if hand_index < 0 or hand_index >= state.hand.size():
		return null
	var card: CardData = state.hand[hand_index]
	var need:= discard_cost_of(card)
	if need <= 0:
		return play_from_hand(hand_index, cell)
	if drop_indexes.size() != need or not can_pay_card(card):
		return null
	var idxs: Array[int] = []
	for d in drop_indexes:
		var di:= int(d)
		if di == hand_index or di < 0 or di >= state.hand.size():
			return null
		idxs.append(di)
	idxs.sort()
	idxs.reverse()
	var drops: Array[CardData] = []
	for di: int in idxs:
		drops.append(state.hand[di])
		state.hand.remove_at(di)
	state.discard.append_array(drops)
	var names: Array[String] = []
	for c: CardData in drops:
		names.append(c.card_name)
	_log("英雄的代价：丢弃 %d 张手牌（%s）" % [drops.size(), ", ".join(names)])
	action.emit("hero_cost", {"count": drops.size(), "names": names, "card": card})
	return play_from_hand(state.hand.find(card), cell)


func spell_needs_target(card: CardData) -> bool:
	return card.needs_target()


## ── 蓄力（9085）── 本方「下一张技能多结算几次」的待用层数（按阵营记账）。
## 层数在 _charge_add 里叠、在 _charge_take 里一次取空（用掉即清）。
func _charge_add(side: String) -> void:
	var n: int = int(_charge.get(side, 0)) + 1
	_charge[side] = n
	_log("蓄力（%s）：下一张技能将生效 %d 次" % [
			"我方" if side == SIDE_SELF else "敌方", n + 1])
	action.emit("charge", {"side": side, "count": n})


func charge_count(side:= SIDE_SELF) -> int:
	## 蓄力待用层数（0 = 没有）；该方下一张技能的结算次数 = 1 + 层数。UI 用。
	return int(_charge.get(side, 0))


func dodge_active(side:= SIDE_SELF) -> bool:
	## 闪躲（9103）窗口是否生效。判定唯一来源仍是 _damage_player 里的 _dodge_active。
	return side == SIDE_SELF and _dodge_active


func max_energy() -> int:
	## 我方本回合的**满费**（费用条 X/Y 里的 Y，R391 用户口径）。
	## 只把「**每个回合都会给**」的那部分算进上限：
	##   道具 —— 鸭语耳环 6015 / 兼修 6033（各 +1，`_begin_turn` 里无条件发放）；
	##   效果卡 —— 无尽黑暗 9114（每回合弃 1 张换 2 费）。
	## **只在特定回合 / 特定条件**给的**不算** —— 它们是「这一回合多出来的」，不是
	## 「每回合都有」，写进分母会让 Y 每回合乱跳：
	##   鸭翼（第 3 回合 +3）/ 冰淇淋（第 1 回合 +2）/ 勇气徽章（精英·Boss 首回合 +1）/
	##   水晶骰子（前 X 回合 +1）/ 活力转移（上回合结转）/ 鸭之低语（随机 1/3）/
	##   雕像（每用 10 张牌回 1）/ 契约签订者等「一次性回费」。
	return FieldState.ENERGY_PER_TURN + permanent_energy_bonus()


func permanent_energy_bonus() -> int:
	## 「每个回合都给」的费用加成合计（= 满费上限相对基础值 5 的增量）。
	## ⚠️ 以后再加「每回合 +N 费」的道具 / 效果卡，**必须**在这里登记 ——
	##    否则费用条的分母会少算（显示 5/5，实际却能用 7 点）。
	var n := 0
	if self_relics.has(EARRING_RELIC_ID):
		n += 1
	if self_relics.has(VERSATILE_RELIC_ID):
		n += 1
	if _zone_has(state.effects, ENDLESS_DARK_TRAIT):
		n += ENDLESS_DARK_ENERGY
	return n


func _charge_take(side: String) -> int:
	## 取走并清空该方的蓄力 → 返回这次技能该结算几次（1 = 没蓄力）。
	## 必须在 _run_spell_effect **之前**调用：蓄力是结算时才上层的，不会把自己翻倍。
	var n: int = int(_charge.get(side, 0))
	_charge[side] = 0
	return 1 + n


func _charge_spell(side: String) -> String:
	## 蓄力（9085）本身：只上一层「下一张技能多结算一次」，没有即时效果。
	_charge_add(side)
	return "下一张技能生效 %d 次" % (1 + int(_charge.get(side, 0)))


func _spell_card_gone(card: CardData, log_text := "") -> bool:
	## R211：「次元」技能卡打完之后的**唯一去向口**。
	##   * 带「次元」字段的**技能卡** → **消失**：`void_count += 1` + `void_cards.append`，
	##     **不进弃牌区**（本场对战不再出现）；
	##   * 其余技能卡 → 照常进弃牌区。
	## 以前这条规则是**按卡 id 硬编码**的（鲸鱼之怒 9050 / 拒绝命运 9098 / 警觉 9109 各写一遍），
	## 加一张次元技能卡就得记得再写一遍 —— 填充 9146（R211）加词条时就差点漏掉行为。
	## 现在判据只读字段，`use_spell` / `cast_reload` 等所有入口共用这一个口。
	## 两个**必须在外面**的例外（见 `use_spell` 尾段）：
	##   * 9102 回响 —— 用后**返回手卡**（循环牌，不是次元牌）；
	##   * 9097 预判 —— pending 期间要留在**弃牌区**做候选池标记，玩家选完由
	##     `foresight_pick_card()` 把自己搬进消耗区。
	## R213：8053 超越极限原先「卡面带次元却进弃牌区」（R99 起文档与实现不一致）已并入本口。
	## R239：**判据不再限定卡种** —— 只认「次元」字段。诅咒「破绽」（9154，`use_curse`）
	## 也要「打出后消失」，它走的就是这里；以后任何卡种要「用后消失」，写上次元即生效。
	if card != null and card.has_affix(AFFIX_DIMENSION):
		state.void_count += 1
		state.void_cards.append(card)
		if log_text != "":
			_log(log_text)
		else:
			_log("%s：使用后消失（不进弃牌区，本场不再出现）" % card.card_name)
		return true
	if card != null:
		state.discard.append(card)
	return false


func use_spell(hand_index: int, target = null, free_cast := false) -> String:
	# R373：不能打出的诅咒（麻痹 9185）—— 引擎侧兜底（UI 走 `can_use_card` 置灰）。
	if hand_index >= 0 and hand_index < state.hand.size() \
			and state.hand[hand_index] != null and state.hand[hand_index].unplayable:
		return "%s：这张卡不能打出" % state.hand[hand_index].card_name
	# 选牌 pending 期间**不许再出别的牌** —— 否则玩家可以在选牌过程中把目标那张
	# 顺手打掉，下标就失效了。界面本身会拦点击（选卡页是模态的），这里是给联机 /
	# 回放路径兜底。（R209：`sys_upgrade_pending` 已删，手牌目标改由选卡页驱动。）
	if overhaul_pending:
		return "返修：请先从弃牌区选择一张盟友或工事"
	# R271：手卡变化面板（创意 / 量产型代达罗斯）pending 期间同样不许出别的牌 ——
	# 否则玩家能在选牌过程中把目标那张打掉，业务下标就失效了。
	if creation_pending:
		return "创意：请先选一张手卡让它变成随机可改造卡"
	if cannonize_pending:
		return "量产型代达罗斯：请先选一张手卡让它变成聚能炮击"
	if surprise_pending:
		return "惊喜运单：请先从卡组选一张卡"
	if paint_pending:
		return "涂装机器人：请先在场上选一个友方单位"

	var card:= state.hand[hand_index]
	var cap_msg:= _play_cap_blocked()
	if cap_msg != "":
		return cap_msg
	if card.id == NIGHT_WALK_ID and state.self_card_plays >= NIGHT_WALK_MAX:
		return "夜行：本回合已使用 %d 张卡（含本卡上限 %d 张）" % [state.self_card_plays, NIGHT_WALK_MAX]
	# 潜入（9100）：**两段式**技能，唯一入口是 cast_infiltrate(手牌序号, 盟友格, 目的格)。
	# R76 守卫：单段入口没有「目的格」这个信息，原来会一路走到 _infiltrate_auto_cell()
	# 自己挑落点（= 己方半场第一个空格 = 前排左边）→ 表现为「卡片自己跑到前排左边」。
	# 和回旋斩一样**在付费之前拦截**，否则拒绝时卡已经被扣掉、手牌也少了一张。
	if card.id == INFILTRATE_ID:
		return "潜入：先点一个己方盟友，再点目的格"
	# 系统升级（8039，R90）：**两段式**技能 —— 目标在**手牌**里（不是棋盘），
	# 所以走独立入口 `cast_sys_upgrade(手牌序号, 目标手牌序号)`。
	# 同样在**付费之前**拦截：否则玩家点了牌发现「手牌里没有可选的盟友」时，
	# 费用已经扣了、卡也已经从手牌里拿走了。
	if card.id == SYS_UPGRADE_ID:
		return "系统升级：先点手牌里的一张盟友或工事"
	# 轻量化（8068，R269）：同样是**两段式**、目标在**手牌**里 → 走 `cast_lighten()`。
	if card.id == HAND_LIGHTEN_ID:
		return "轻量化：先点手牌里的一张盟友"
	# 回收（8064，R198）：**两段式**技能 —— 目标在**手牌**里且**不限种类**
	# （换卡式回收，技能/场地卡也能当目标），走独立入口
	# `cast_recycle(手牌序号, 目标手牌序号)`。同样在**付费之前**拦截。
	if card.id == RECYCLE_ID:
		return "回收：先点手牌里的一张卡"
	# 填充（9146，R202）：**两段式**技能 —— 目标在**手牌**里且不限种类。
	# R205：UI 侧改成弹全屏选卡页（`battle_scene._sync_pick` 的 "reload" 档），
	# 这里仍是单段入口的拦截文案（自动出牌 / 联机误用直接打回）。
	if card.id == RELOAD_ID:
		return "填充：在选卡页里点一张手牌"
	# 双向传送（8061，R102）：**两段式**技能 —— 要选**两个**单位，单段入口没有
	# 第二个目标的信息。必须在**付费之前**拦截，否则玩家发现场上不足两个单位时
	# 费用已经扣了、卡也已经从手牌里拿走了。
	if card.id == SWAP_UNITS_ID:
		return "双向传送：先点第一个单位，再点第二个单位（右键取消）"
	# 合体（9167，R298）：UI 走 `cast_merge()` 两段式（先场上目标、再卡组素体面板）。
	# 单段入口没有目标时**绝不能**往里走 —— 否则会先扣费、把卡从手牌吃掉，才回一句
	# 「需要指定目标」，白丢 1 费 + 一张史诗牌（与潜入 / 双向传送同一条纪律）。
	if card.id == MERGE_ID and not (target is Vector2i):
		return "合体：先点一个自己的盟友或工事"
	# 回旋斩（9096）：本回合使用 4 张以上其他卡后才能使用（付费用之前拦截）。
	if card.id == WHIRL_BLADE_ID and state.self_card_plays < WHIRL_BLADE_NEED:
		return "回旋斩：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				WHIRL_BLADE_NEED - state.self_card_plays, state.self_card_plays]
	# 流星雨（9083）：X = 扣费前剩余的**全部费用**（_pay 会把它一次清零）→ 先抓再付。
	_x_spell_value = maxi(0, state.energy_of(SIDE_SELF)) if card.x_cost else 0
	# R288：`free_cast` = 失控要塞 9161 凭空生成的技能卡（卡面写「释放」，不向玩家收费）。
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)
	# 蓄力（9085）：先取走待用层数再结算 —— 蓄力是结算时才上层的，不会把自己翻倍
	var times:= _charge_take(SIDE_SELF)
	# 风元素（9082）：技能结算窗口 —— 窗口内对敌方造成过伤害就记一笔（手卡里本卡 -2 费）
	_spell_active = true
	_spell_hit_enemy = false
	# R315 爆米花（6046）：记「本回合有没有以敌人 / 敌人所在的格子为目标使用技能」。
	# 放在**结算之前**、蓄力循环之外：蓄力重放同一张卡不会改变「目标是不是敌人」这件事。
	# ⚠️ 只认 `use_spell`（我方的技能卡）—— `remote_spell` 是敌方，与这件道具无关。
	if target is Vector2i:
		var pc_t: Placement = state.unit_at(target)
		if pc_t != null and pc_t.owner != SIDE_SELF:
			_popcorn_quiet = false
	var detail:= ""
	for _ch_i in times:
		var _ch_d:= _run_spell_effect(card, target)
		detail = _ch_d if _ch_i == 0 else "%s；%s" % [detail, _ch_d]
	if times > 1:
		detail = "蓄力 ×%d → %s" % [times, detail]
	_spell_active = false
	if _spell_hit_enemy and _void_lord_owned(SIDE_SELF):
		# 修复（实机体验 R46 后）：没有风元素时不再空转计数/打日志/发事件
		# （此前对手牌里没有本卡的玩家也会一直弹「风元素：…」状态栏文本）。
		state.void_dmg_spells += 1
		_log("风元素：本次对战中第 %d 次用技能对敌方造成伤害 → 手卡里的本卡费用 -%d" % [
			state.void_dmg_spells, state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT])
		action.emit("void_lord", {"count": state.void_dmg_spells,
			"discount": state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT})
	# 技能用完才计数：_spell_dmg 里的「每回合第一张技能」判定因此仍是 0 → 当回合首张吃到加成
	state.self_skill_plays += 1
	_spell_play_tick()
	_on_turn_first_play(SIDE_SELF, card)
	_note_card_played(SIDE_SELF, card)
	# R213：技能卡去向**统一按字段**判，不再罗列卡 id —— `_spell_card_gone` 读「次元」，
	# 带它的技能卡打完即消失（进消耗区），其余照常进弃牌区。这样 R211 之后新加的次元卡
	# （填充 9146、超越极限 8053）都不必回来补分支；8053 也因此与卡面一致
	# （用户口径「超越极限也修复为和其他次元一样」，此前它落到下面的 else 进弃牌区）。
	# 只有两个例外必须留在外面：
	#   * 9097 预判：pending 期间还要待在弃牌区（`foresight_pick_card()` 选完才搬进消耗区）；
	#   * 9102 回响：用后返回手卡（循环牌，不是次元牌）。
	if card.id == FORESIGHT_ID:
		state.discard.append(card)
	elif card.id == ECHO_ID:
		# 回响（9102）：使用后**返回手卡**（循环代价只有费用，下限见 ECHO_MIN_COST）。
		if state.hand_full():
			_log("回响：返回手卡被手牌上限挡下 → 进弃牌区")
			state.discard.append(card)
		else:
			state.hand.append(card)
			_log("回响：使用后返回手卡")
	else:
		_spell_card_gone(card)   # 次元 → 进消耗区；其余 → 进弃牌区
	_log("使用技能 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	return detail


func _instinct_panel_open() -> bool:
	## 本能 9176（R332）：结算中间出现「等玩家选」的面板就得收手 ——
	## 继续「随机打出」会把面板依赖的下标/候选弄失效（与 use_spell 开头那四个守卫同源，
	## 这里把弃牌区/卡组/手牌/合并等其余 pending 也一并算上）。
	return overhaul_pending or creation_pending or cannonize_pending or surprise_pending \
		or paint_pending \
		or focus_pending or wish_pending or shadow_step_pending or revive_pending \
		or merge_pending or crow_pending or whale_pending or endless_pending \
		or rebirth_pending or eliminate_pending


func _instinct_cast(side: String) -> String:
	## 本能（9176，R332，暗影刺客 2 费稀有技能）：随机打出抽牌库中 3 张费用 ≤ 1 的技能卡。
	## ⚠️ 这里用 `state.hand.append()` 而**不是** `_grant_to_hand()`：那张卡只是临时借道手牌
	##    去走 `use_spell(hand_index)`（`_grant_to_hand` 在手牌满时会改投弃牌区，语义不对）。
	## ⚠️ 候选池存的是 **CardData 引用**而不是下标：每打出一张，`state.deck` 就会变短，
	##    先前记下的下标会整体错位。真正出牌前才用 `state.deck.find(card)` 取当前下标。
	var names: Array[String] = []
	var pool: Array[CardData] = []
	for c: CardData in state.deck:
		if c == null or not c.is_spell():
			continue
		if c.id == INSTINCT_ID or c.x_cost:
			continue
		if cost_of(c, side) > INSTINCT_MAX_COST:
			continue
		pool.append(c)
	while names.size() < INSTINCT_COUNT and not pool.is_empty():
		if _instinct_panel_open():
			_log("本能：上一张卡留下了选牌面板，停止后续打出")
			break
		var k: int = rng.randi() % pool.size()
		var card: CardData = pool[k]
		pool.remove_at(k)
		var pick: int = state.deck.find(card)
		if pick < 0:
			# 前一张打出的卡带抽牌效果，把这张抽走了 → 当没抽到。
			continue
		var tgt = null
		if card.needs_target():
			var cells := _autoplay_spell_targets(card)
			if cells.is_empty():
				_log("本能：%s 没有合法目标，跳过" % card.card_name)
				continue
			tgt = cells[rng.randi() % cells.size()]
		state.deck.remove_at(pick)
		state.hand.append(card)
		var hi: int = state.hand.size() - 1
		var plays_before: int = state.self_card_plays
		use_spell(hi, tgt, true)
		if state.self_card_plays > plays_before:
			names.append(card.card_name)
			continue
		# 被打回（夜行上限 / 两段式技能 / 目标无效）→ 放回牌库**原位**，不占「3 张」配额。
		var back: int = state.hand.find(card)
		if back >= 0:
			state.hand.remove_at(back)
		state.deck.insert(mini(pick, state.deck.size()), card)
		_log("本能：%s 打出被拒，放回牌库" % card.card_name)
		if _play_cap_blocked() != "":
			break
	if names.is_empty():
		_log("本能：抽牌库里没有费用 %d 或以下的技能卡" % INSTINCT_MAX_COST)
		return "抽牌库里没有费用 %d 或以下的技能卡" % INSTINCT_MAX_COST
	var det := "本能：随机打出 %s" % "、".join(names)
	_log(det)
	action.emit("instinct", {"cards": names})
	return det


func use_effect(hand_index: int) -> String:



	var card:= state.hand[hand_index]
	var cap_msg:= _play_cap_blocked()
	if cap_msg != "":
		return cap_msg
	_pay(card)

	state.self_next_effect_reduction = 0
	state.hand.remove_at(hand_index)
	state.self_effect_plays += 1
	_on_effect_card_played(SIDE_SELF, card)
	_on_turn_first_play(SIDE_SELF, card)
	state.effects.append(card)
	_note_card_played(SIDE_SELF, card)

	if card.traits.has(STONESKIN_TRAIT):
		_stoneskin_left += maxi(1, card.value)
		_log("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
			maxi(1, card.value), _stoneskin_left])
		action.emit("stoneskin", {"left": _stoneskin_left, "add": maxi(1, card.value)})

	if card.traits.has(DUCK_NEST_TRAIT):
		_egg_to_hand("鸭窝")
	_log("启用效果卡 %s（效果区持续生效）" % card.card_name)

	state.apply_extra_actions(SIDE_SELF)
	action.emit("effect", {"card": card})
	return "%s 生效中" % card.card_name


func use_curse(hand_index: int) -> String:
	## R223：打出**诅咒卡**（「疲惫」9149）—— 用户口径「打出无效果」：付费用、离手、
	## 进弃牌区，就这些。
	## R239：去向改走**唯一口 `_spell_card_gone`** —— 带「次元」的诅咒（破绽 9154）
	## 「打出后消失」（进消耗区，本场不再出现），其余诅咒（疲惫 9149）照旧进弃牌区。
	## ⚠️ **不走 use_spell**：不记 `self_skill_plays`（不是技能），也不点亮技能类反应
	##    （风元素记账 / 蓄力 / 回合首张技能加成 / 陨石术的留手折价都不该被一张
	##    无效果诅咒触发）。
	##    「用了一张牌」的通用收尾仍走 `_note_card_played`（终结/回转的 X、幻影斗篷、
	##    疾风、潜影者、不眠……都该把它算成一次出牌）。
	var card := state.hand[hand_index]
	# R373：不能打出的诅咒（麻痹 9185）—— 连「付费用掉它」这条规避手段都不给。
	if card.unplayable:
		return "%s：这张卡不能打出" % card.card_name
	var cap_msg := _play_cap_blocked()
	if cap_msg != "":
		return cap_msg
	_pay(card)
	state.hand.remove_at(hand_index)
	_spell_card_gone(card)   # R239：次元诅咒（破绽）→ 进消耗区；其余 → 进弃牌区
	_note_card_played(SIDE_SELF, card)
	_log("打出诅咒 %s（无效果）" % card.card_name)
	action.emit("curse", {"card": card})
	return "%s：无效果" % card.card_name


func _spell_play_tick() -> void:


	## 用过一张技能卡之后，给手牌里「按张记账」的卡记一笔：
	## 陨石术（留手）永久 -1（本局一直累加）；魔像术（魔像）本回合 -1（回合结束清空）。
	for c: CardData in state.hand:
		if c.traits.has(FieldState.KEEP_HAND_TRAIT):
			state.card_discount[c] = int(state.card_discount.get(c, 0)) + 1
		if c.traits.has(GOLEM_TRAIT):
			state.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + 1


func _note_card_played(side: String, played: CardData = null) -> void:
	## 「使用了一张牌」的统一收尾（play_from_hand / use_spell / use_effect 与
	## remote_play / remote_spell 都在最后调它 —— 新增出牌反应只改这一处）：
	##   1) 累加本回合出牌数（终结 9086 / 回转 9089 / 连环戏法 9093 的 X）；
	##   2) 幻影斗篷（6023）：持有方每用一张牌 → 随机敌方单位力量 -1；
	##   3) 疾风（9091 效果）：每用一张牌 → 随机敌人 2 伤（played 排除本卡自己）；
	##   4) 潜影者（8009）：每用一张牌 → 它力量 +1（攻击 / 离场后重置）；
	##   5) 不眠（9101 效果）：结算收尾时手里没牌 → 抽 1 张（0 费卡本回合 +1 费）。
	if side == SIDE_SELF:
		state.self_card_plays += 1
		# R346 成就统计：累计「用过多少张牌」—— 按卡 id 与卡类各记一份。
		# 记在这里是因为 `_note_card_played` 是**唯一**出牌收尾口（play_from_hand /
		# use_spell / use_effect / remote_* 全都会走到），别在这四处各写一遍。
		# ⚠️ 只在真局里记（`run_active`）—— 演示 / 单关战斗不该往玩家档案里灌统计。
		if played != null and RunState.run_active:
			ProfileData.bump(ProfileData.K_CARD_PLAY + str(played.id))
			ProfileData.bump(ProfileData.K_KIND_PLAY + played.kind)
	else:
		state.opp_card_plays += 1
	# R271：聚能体系计数 —— 本次对战中我方**使用过几张「聚能炮击」**（9145）。
	# 记账口就这一处：play_from_hand / use_spell / use_effect / remote_* 全都会走到这里。
	# 记在 `played` 上（而不是扫描效果区）：聚能炮击是技能卡，用完就进弃牌区了。
	if played != null and played.id == ENERGY_CANNON_ID and side == SIDE_SELF:
		state.self_cannon_plays += 1
		_log("聚能炮击：本次对战累计使用 %d 张" % state.self_cannon_plays)
	_phantom_cloak_tick(side)
	_gale_tick(side, played)
	_lurker_tick(side, played)
	_sleepless_tick(side)
	_wind_fairy_tick(side)
	# R307 雕像（6039）：每使用 10 张牌回复 1 点费用（**跨回合、跨战斗**累计）。
	if side == SIDE_SELF and self_relics.has(STATUE_RELIC_ID):
		RunState.statue_charge += 1
		if RunState.statue_charge >= RunState.STATUE_EVERY:
			RunState.statue_charge -= RunState.STATUE_EVERY
			state.energy += 1
			_log("雕像：累计使用 %d 张牌 → 回复 1 点费用（当前 %d）"
					% [RunState.STATUE_EVERY, state.energy])
	# R370 附魔「抽牌 +1」：带这个附魔的卡**打出后抽 1 张**。
	# 放在收尾口最末：这张卡的所有结算都已完成（手牌早已离手，抽到的卡不会顶掉自己）。
	# ⚠️ 抽牌一律走 `_draw_many()` 唯一口 —— 手牌满时 burn 进弃牌区，不会悄悄吞掉。
	if side == SIDE_SELF and played != null and played.enchant == ENCHANT_DRAW:
		var ed_n := _draw_many(1)
		_log("附魔「抽牌 +1」：打出 %s 后抽 %d 张" % [played.card_name, ed_n])


func _raid_dmg(side: String) -> int:
	## 突袭的伤害基数 = RAID_BASE_DMG + X（X = 本回合该方已使用的卡牌数）。
	## 自身不计入：结算走到这里时它还没经 _note_card_played 记账。
	var plays := state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
	return RAID_BASE_DMG + plays


func _finisher_is_last(side: String) -> bool:
	## 收尾（9104）：「这张卡是你手卡中仅剩的一张」判定。
	## 结算走到这里时本卡**已被移出手牌**（use_spell 先 remove_at 再 _run_spell_effect）
	## → 手牌为空就说明它是最后一张。敌方侧对称：remote_spell 先扣 opp_hand_count。
	if side == SIDE_SELF:
		return state.hand.is_empty()
	return state.opp_hand_count <= 0


func hand_bonus_ready(card: CardData) -> bool:
	## 「这张手牌现在打出去能吃到额外效果吗」——**唯一判定口**（R65）。
	## 战斗界面据此给手卡打**金色高亮**，提醒玩家「这张要现在用」。
	## 只认**卡牌在手上时就能确定**的条件（结算前可知），不给未来抽牌之类的不确定条件亮。
	## 目前覆盖三类（都与各自的结算函数同口径，改机制时两处一起改）：
	##   * 收尾 9104：手卡仅剩它 → 4 伤变FINISHER_LAST_DMG 伤。
	##     注意它结算时本卡已离手，所以这里判「手里只有这一张」。
	##   * 影魔 8007：手卡里有费用为 0 的技能牌 → 每张 +SHADOW_DEMON_HP_PER 生命。
	##   * 大树守卫 9067：效果区非空 → 每张效果卡 +1 力量 +2 生命。
	if card == null:
		return false
	if card.id == FINISHER_ID:
		return state.hand.size() == 1 and state.hand[0] == card
	if card.id == SHADOW_DEMON_ID:
		for c: CardData in state.hand:
			if c.is_spell() and cost_of(c) == 0:
				return true
		return false
	if card.id == AETHER_GUARD_ID:
		return not state.effects.is_empty()
	return false


func hand_bonus_text(card: CardData) -> String:
	## 给金色高亮配一句提示（悬停时显示）；没有额外效果返回 ""。
	## 与 hand_bonus_ready 同源，避免两处判定漂移。
	if not hand_bonus_ready(card):
		return ""
	if card.id == FINISHER_ID:
		return "现在打出：%d 伤" % FINISHER_LAST_DMG
	if card.id == SHADOW_DEMON_ID:
		var zero := 0
		for c: CardData in state.hand:
			if c.is_spell() and cost_of(c) == 0:
				zero += 1
		return "现在打出：生命 +%d" % (zero * SHADOW_DEMON_HP_PER)
	if card.id == AETHER_GUARD_ID:
		var n: int = mini(state.effects.size(), AETHER_GUARD_CAP)
		return "现在打出：力量 +%d 生命 +%d" % [n, 2 * n]
	return ""


# ══════════════════════════════════════════════════════════════════════════
#  「现在打出会造成多少伤害」（R262 立 · R348 重构为统一口）
# ══════════════════════════════════════════════════════════════════════════
# 为什么必须有一张表：技能卡的 `power` **恒为 0**（伤害写死在各结算分支的常量里），
# 运行时拿不到「这张卡的基础伤害」；而 `_spell_dmg()` 的加成（附魔 +10 / 魔法塔 /
# 荧光草 / 鸭之眼 / 魔力核心 / 回合加成 / 鹿首标本 / lucky7 / 快速符文）会让**每一张**
# 伤害技能偏离卡面，卡面却永远只写基础值 —— 玩家只能心算。
#
# ⚠️ 四条纪律：
#   ① 表里每个值 == 该卡 `effect_text` 里**第一个「N 点伤害」的 N**（R348 断言逐条对，
#      改数值忘了同步就红）。**蓄势 9156 除外**：它的卡面由 `_charge_up_text(card.value)`
#      动态生成，表里记初始值 0。
#   ② 新增伤害技能卡**必须**登记，否则 `spell_now()` 当它不是伤害卡、左栏静默不显示
#      （R348 ① 会拦下来 —— 这正是 R348 之前集中突破 9162 / 收尾 9104 / 暗影狩猎 9107 /
#      聚能炮击 9145 漏显示的根因）。
#   ③ 表里只放**基础值**，加成一律现算 —— 别把「9 + 7 = 16」这种烘焙进来。
#   ④ 本表是**只读数据**，不许在 `_spell_dmg()` 之外被谁改写。
const SPELL_BASE_DMG := {
	8002: 4,     # 攻击
	9003: 17,    # 火焰箭
	9006: 11,    # 闪电链（每个被连到的单位）
	9007: 20,    # 火球术
	9011: 3,     # 寒冰箭
	9035: 14,    # 协同攻击
	9050: 11,    # 鲸鱼之怒
	9054: 4,     # 龙息（4 × 5 次）
	9077: 40,    # 陨石术
	9083: 8,     # 流星雨（× 剩余费用）
	9084: 15,    # 火墙术（每格；另有 8 点持续伤害）
	9086: 2,     # 终结（2 + 本回合已用张数）
	9087: 4,     # 连刺
	9088: 3,     # 敲晕
	9090: 6,     # 偷袭（目标满血 12）
	9093: 5,     # 连环戏法（本回合第 3 张 → 10）
	9095: 10,    # 怒涛
	9096: 17,    # 回旋斩
	9102: 2,     # 回响
	9104: 6,     # 收尾（手牌仅剩它 → 22）
	9107: 16,    # 暗影狩猎（目标上回合触发过场地 → 30）
	9119: 4,     # 起手式
	9120: 8,     # 影袭
	9121: 8,     # 暗影步
	9145: 9,     # 聚能炮击（8075 在场 → +7）
	9156: 0,     # 蓄势（吃 card.value，卡面自己会写）
	9160: 5,     # 弹跳飞刀（另有最多 2 个目标各 3）
	9162: 10,    # 集中突破（+4 × 场上改造层数）
	9163: 10,    # 冲击炮（R369：8 → 10）
	9189: 7,     # 独行（7 + 卡内累积；左栏刻意不报数，见 spell_now）
	9169: 10,    # 烈火之剑
	9172: 9,     # 激光扫射
	9205: 25,    # 猎杀（R393，暗影刺客史诗技能；本局永久成长会抬高 value → 预览按 value 取）
}

# 卡面**给不出确数**的伤害技能（数字随局势变）→ 即使一点加成都沒有也要报当前值。
# 这张表就是 `spell_now()` 的**分流口**：名单里的走 ① 动态分支（每张都有自己的分支），
# 名单外的（但在 `SPELL_BASE_DMG` 里）走 ② 固定分支，只在真有加成才报。
#
# ⚠️ 9145 聚能炮击**刻意不在名单里**：它的偏离是**条件性**的（只有 8075 在场才 +7），
#    没 8075 时卡面的 9 就是准确值 → 归「没加成不画」的固定口径。但它的加成不走
#    `_spell_dmg()`（是 8075 的专门每回合额度），所以 `spell_now()` 里给它单列了分支。
# ⚠️ 蓄势 9156 也不在名单里：卡面由 `_charge_up_text(card.value)` 实时写出当前伤害，
#    本来就说清楚了；只有附魔这类额外加成才会让它偏离卡面。
const SPELL_DYNAMIC_IDS: Array[int] = [9083, 9086, 9090, 9093, 9104, 9107, 9162]

# R384：**不给「目标格数字」**的伤害技能 —— `spell_now().dmg` 对它们不是「这一格掉多少」。
#   * 9083 流星雨：随机目标、打 X 颗，dmg 是**总量**；
#   * 9054 龙息：4 点 × 5 次打同一批，每下**分别过减伤链**，总量 ≠ 5 × 单下；
#   * 9160 弹跳飞刀：主目标 5、最多 2 个次目标各 3，同一张卡对不同格数字不同。
# 这些卡仍享受 AOE 覆盖 / 自伤警告预览，只是不报数字（宁可不说，也不许说错）。
const SPELL_NO_CELL_PREVIEW: Array[int] = [DRAGON_BREATH_ID, METEOR_SHOWER_ID, 9160]


func mass_mnemosyne_bonus_ready(side: String = SIDE_SELF) -> bool:
	## 量产型谟涅摩叙涅 8075 的炮击额度**当前还剩不剩** —— R348 新增的**只读预览口**。
	## ⚠️ 千万别改用 `_mass_mnemosyne_cannon_bonus()`：那是有副作用的**消费口**，
	##    拖牌看一眼详情就会把额度提前烧掉，真打出去反而拿不到 +7（R341 的额度按座记账）。
	## 判据与消费口逐条对齐：只看**场上**我方、本座 `mass_mnemo_turn != turn_total`。
	if side != SIDE_SELF or state.board.is_empty():
		return false
	for p: Placement in state.board.values():
		if p == null or p.card == null or p.owner != SIDE_SELF:
			continue
		if p.card.id == MASS_MNEMOSYNE_ID and p.mass_mnemo_turn != turn_total:
			return true
	return false


static func dmg_expr_text(base: int, dmg: int) -> String:
	## R349：加法型算式的**唯一写法**（`10＋8` / `10－2`）。相等返回 "" ——
	## 卡面写的就是这个数，界面不必再啰嗦（R262 定下的口径）。
	## 注意「条件档位型」不走这里（收尾 6→22 是「改为」不是「加」），它们 expr 直接给 ""。
	if dmg == base:
		return ""
	if dmg > base:
		return "%d＋%d" % [base, dmg - base]
	return "%d－%d" % [base, base - dmg]


func spell_now(card: CardData, side: String = SIDE_SELF) -> Dictionary:
	## R262（用户口径）：**「现在打出会造成多少伤害」** —— 战斗左栏详情用。
	## R348 重构：从「手挑 4 张特例」改成**统一口** —— `SPELL_BASE_DMG` 登记全部伤害技能的
	## 基数，`SPELL_DYNAMIC_IDS` 就是分流口：
	##   ① 名单里的（卡面给不出确数）→ 每张一个分支，永远报一个当前值；
	##   ② 名单外的 → 只有 `_spell_dmg()` 真加了东西时才报，没加成返回 {} 让界面不画
	##      （R262 定的口径：界面与卡面一致时不啰嗦）。
	## 两类都统一过 `_spell_dmg()` → **显示值 == 实际扣血值**。
	## 返回 {"dmg": int, "note": String}；note 说明这个数是怎么来的（界面第二行小字）。
	## ⚠️ 本函数**必须只读**：拖牌时每帧都可能调它。
	if card == null or card.kind != "技能":
		return {}
	if not SPELL_BASE_DMG.has(card.id):
		return {}
	var plays: int = state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
	# ---------- ① 动态卡 ----------
	if card.id in SPELL_DYNAMIC_IDS:
		if card.id == METEOR_SHOWER_ID:
			var times: int = maxi(0, state.energy_of(SIDE_SELF)) if side == SIDE_SELF else 0
			var per: int = _spell_dmg(side, METEOR_SHOWER_DMG, card)
			return {"dmg": per * times, "base": per,
					"expr": "%d × %d" % [per, times], "anchor": str(per),
					"note": "%d × %d 颗（清空费用）" % [METEOR_SHOWER_DMG, times]}
		if card.id == RAID_SPELL_ID:
			var rd: int = _spell_dmg(side, _raid_dmg(side), card)
			# anchor 是 `2+X` —— 正文写的就是这四个字符，直接替换成 `4（2＋2）`。
			return {"dmg": rd, "base": RAID_BASE_DMG,
					"expr": dmg_expr_text(RAID_BASE_DMG, rd),
					"anchor": "%d+X" % RAID_BASE_DMG,
					"note": "%d + 本回合已用 %d 张" % [RAID_BASE_DMG, plays]}
		if card.id == COMBO_TRICK_ID:
			var n: int = plays + 1
			if n >= COMBO_TRICK_NEED:
				# 条件档位型：正文「…则改为造成 10 点伤害」已经写清了，只把 10 染色。
				return {"dmg": _spell_dmg(side, COMBO_TRICK_FULL_DMG, card),
						"base": COMBO_TRICK_DMG, "expr": "", "anchor": "",
						"note": "含本卡本回合第 %d 张 → 强化" % n}
			return {"dmg": _spell_dmg(side, COMBO_TRICK_DMG, card),
					"base": COMBO_TRICK_DMG, "expr": "", "anchor": "",
					"note": "本回合第 %d 张（满 %d 张强化）" % [n, COMBO_TRICK_NEED]}
		if card.id == SNEAK_ID:
			# 目标未定时按**未受伤目标**报 6，满血值写进 note（提前知道「这一下能翻倍」）
			# 档位型：正文「若目标处于满血状态则改为造成 12 点伤害」→ 预览时目标未定，
			# dmg 仍等于卡面 6 → `inline_damage` 判定「没偏离」不动正文（既不染色也不加括号）。
			return {"dmg": _spell_dmg(side, SNEAK_DMG, card), "base": SNEAK_DMG,
					"expr": "", "anchor": "",
					"note": "目标满血时 %d" % _spell_dmg(side, SNEAK_FULL_DMG, card)}
		if card.id == FINISHER_ID:
			# ⚠️ 预览时本卡**还在手上**，「仅剩它」= 手牌只有这一张；
			#    结算时本卡已被移出手牌、判据是「手牌为空」（`_finisher_is_last()`）。
			#    照抄那边的判据 → 手里只剩它时也永远报 6，这个预览就白做了。
			var last: bool = (state.hand.size() == 1 and state.hand[0] == card) \
					if side == SIDE_SELF else state.opp_hand_count <= 1
			if last:
				return {"dmg": _spell_dmg(side, FINISHER_LAST_DMG, card),
						"base": FINISHER_DMG, "expr": "", "anchor": "",
						"note": "手牌只剩这一张 → 强化"}
			return {"dmg": _spell_dmg(side, FINISHER_DMG, card),
					"base": FINISHER_DMG, "expr": "", "anchor": "",
					"note": "手牌仅剩它时 %d" % _spell_dmg(side, FINISHER_LAST_DMG, card)}
		if card.id == HUNT_ID:
			return {"dmg": _spell_dmg(side, HUNT_DMG, card), "base": HUNT_DMG,
					"expr": "", "anchor": "",
					"note": "目标上回合触发过场地 → %d" % _spell_dmg(side, HUNT_BIG_DMG, card)}
		if card.id == BREAKTHROUGH_ID:
			var st: int = _side_upgrade_stacks(side)
			# 加成型：正文 `造成**10**点伤害` → 界面显示 `造成 18（10＋8）点伤害`
			# （用户 R349 举的就是这张卡的例子）。anchor 自动取 base 的 "10"。
			var bd: int = _spell_dmg(side, BREAKTHROUGH_DMG + st * BREAKTHROUGH_PER_STACK, card)
			return {"dmg": bd, "base": BREAKTHROUGH_DMG,
					"expr": dmg_expr_text(BREAKTHROUGH_DMG, bd), "anchor": "",
					"note": "场上改造 %d 层 → %d + %d" % [st, BREAKTHROUGH_DMG,
							st * BREAKTHROUGH_PER_STACK]}
		# 名单里却没有分支 → 宁可不错报（R348 ② 断言会把这个矛盾立刻拦下来）
		return {}
	# ---------- 独行 9189：**永远不报数**（R406 用户口径）----------
	# 「随机消失一张手卡 → 它的生命值并进伤害」→ **打出之前不可能知道最终伤害**。
	# 用户口径：「由于有随机性不应该展示最终伤害」→ 左栏干脆不画这一行
	# （卡面 7 是基础值，实际只会更高）。
	# ⚠️ 哪怕附魔 +10 / 荧光草给了确定加成也不报 —— 一旦报数，玩家就会把那个数
	#    当成「这一下总共掉多少」，而那恰恰是最容易说错的地方（宁可不说）。
	if card.id == LONE_WALK_ID:
		return {}
	# ---------- 聚能炮击：**条件性**偏离（只有 8075 在场才 +7）----------
	if card.id == ENERGY_CANNON_ID:
		var eb: int = MASS_MNEMOSYNE_DMG if mass_mnemosyne_bonus_ready(side) else 0
		var ed: int = _spell_dmg(side, ENERGY_CANNON_DMG + eb, card)
		if eb <= 0 and ed == ENERGY_CANNON_DMG:
			return {}   # 卡面写的就是 9，没 8075 也没别的加成 → 不啰嗦
		if eb > 0:
			return {"dmg": ed, "base": ENERGY_CANNON_DMG,
					"expr": dmg_expr_text(ENERGY_CANNON_DMG, ed), "anchor": "",
					"note": "含谟涅摩叙涅 +%d" % eb}
		return {"dmg": ed, "base": ENERGY_CANNON_DMG,
				"expr": dmg_expr_text(ENERGY_CANNON_DMG, ed), "anchor": "",
				"note": "卡面 %d ＋ 加成 %d" % [ENERGY_CANNON_DMG, ed - ENERGY_CANNON_DMG]}
	# ---------- ② 固定卡：卡面已给确数，只有加了成才报 ----------
	# 蓄势 9156 的 base 是实例数据（`_charge_up_grow` 逐回合累加，卡面由
	# `_charge_up_text(card.value)` 同步写出）→ 单独取，不读表。
	# R393：猎杀 9205 的伤害是**实例值**（本局永久成长会一直抬高 `card.value`），
	# 与蓄势同理不能读表里的固定基数，否则左栏会一直报 25、越打越不准。
	var base: int = int(SPELL_BASE_DMG[card.id])
	if card.id == CHARGE_UP_ID or card.id == SLAY_ID:
		base = card.value
	var fin: int = _spell_dmg(side, base, card)
	if fin == base:
		return {}
	return {"dmg": fin, "base": base, "expr": dmg_expr_text(base, fin), "anchor": "",
			"note": "卡面 %d ＋ 加成 %d" % [base, fin - base]}


func _finisher_dmg(side: String) -> int:
	## 收尾的基础伤害：手卡仅剩它 → 15 伤；否则 4 伤（之后统一经 _spell_dmg 加成）。
	return FINISHER_LAST_DMG if _finisher_is_last(side) else FINISHER_DMG


func _phantom_cloak_tick(side: String) -> void:
	## 幻影斗篷（6023，暗影刺客角色道具）：**我方**每使用 PHANTOM_CLOAK_EVERY(2) 张牌，
	## 随机一个敌方单位力量 -PHANTOM_CLOAK_DEBUFF。时效与「威慑」同源 —— debuff_stage=1，
	## 在 debuff 所属方的回合结束时清除（= 我方的下个回合开始之前恢复）。
	## 计数器用 state.self_card_plays（出牌数统一入口 _note_card_played 维护）——
	## 必须整除才触发，所以「这 2 张牌」的判定是：偶数张才触发。
	if side != SIDE_SELF or not self_relics.has(PHANTOM_CLOAK_RELIC_ID):
		return
	if state.self_card_plays % PHANTOM_CLOAK_EVERY != 0:
		return
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.unit_at(cell)
		if q != null and q.owner == SIDE_OPPONENT and q.health > 0:
			cells.append(cell)
	if cells.is_empty():
		_log("幻影斗篷：敌方场上没有单位，未生效")
		return
	var tgt: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var foe: Placement = state.unit_at(tgt)
	foe.atk_debuff += PHANTOM_CLOAK_DEBUFF
	foe.debuff_stage = 1
	_log("幻影斗篷：本回合第 %d 张牌 → %s 力量 -%d（当前 %d），持续到你下个回合开始"
			% [state.self_card_plays, foe.card.card_name, PHANTOM_CLOAK_DEBUFF,
				foe.effective_power()])
	action.emit("phantom_cloak", {"cell": tgt, "card": foe.card,
			"amount": PHANTOM_CLOAK_DEBUFF, "power": foe.effective_power(),
			"name": foe.card.card_name})


func _fetch_skill_from_deck(mode: int) -> CardData:
	## 从卡组随机取一张「技能卡」加入手卡。mode：0=任意 1=费用为0 2=费用不为0。
	## R299：手牌满不再「不动卡组直接落空」—— 照样取出来，由 `_grant_to_hand` 送进弃牌区。
	## 连刺 / 幽灵亡语 / 影子猫 / 预判② 共用本口。
	var cand: Array[int] = []
	for i in state.deck.size():
		var dc: CardData = state.deck[i]
		if dc.kind != "技能":
			continue
		if mode == 1 and dc.cost != 0:
			continue
		if mode == 2 and dc.cost == 0:
			continue
		cand.append(i)
	if cand.is_empty():
		return null
	var pick := cand[rng.randi() % cand.size()]
	var c: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	_grant_to_hand(c, "卡组取技能卡")
	return c


func _shadow_cat_trigger() -> void:
	## 影子猫（8006）打出时：包含这张卡，本回合已打出的卡达到 3 张
	## → 从卡组把一张随机技能卡加入手卡（打出自己也算第 N 张）。
	if state.self_card_plays + 1 >= SHADOW_CAT_NEED:
		var c := _fetch_skill_from_deck(0)
		_log("影子猫：含此卡本回合第 %d 张 → %s" % [state.self_card_plays + 1,
				("卡组随机技能卡「%s」加入手卡" % c.card_name) if c != null else "卡组里没有技能卡"])
		action.emit("shadow_cat", {"card": c})
	else:
		_log("影子猫：含此卡本回合只打了 %d 张（不足 %d）→ 效果落空" % [
				state.self_card_plays + 1, SHADOW_CAT_NEED])
		action.emit("shadow_cat", {"card": null})


func _shadow_demon_enter(p: Placement) -> void:
	## 影魔（8007）打出时：手卡中所有技能牌本回合费用 -1；
	## 手卡每有一张费用为 0 的技能卡 → 这张卡 +3 生命。
	var zero := 0
	for c: CardData in state.hand:
		if c.is_spell():
			state.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + 1
			if c.cost == 0:
				zero += 1
	if zero > 0:
		p.health += SHADOW_DEMON_HP_PER * zero
	_log("影魔：手卡技能牌本回合 -1 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）" % [
			zero, SHADOW_DEMON_HP_PER * zero, p.health])
	action.emit("shadow_demon", {"cell": _cell_of(p), "zero": zero,
			"gained": SHADOW_DEMON_HP_PER * zero, "health": p.health})


func _zone_has_id(side: String, id: int) -> bool:
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.id == id:
			return true
	return false


func _gale_tick(side: String, played: CardData) -> void:
	## 疾风（9091 效果卡）：效果区有本卡时，该方每使用一张卡（不含本卡自己打出）
	## → 随机对一个敌人造成 2 点伤害；没有敌方单位 → 直击对方 HP。
	var gale_found := false
	var gale_zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for gz_c: CardData in gale_zone:
		if gz_c.id == GALE_ID and gz_c != played:
			gale_found = true
			break
	if not gale_found:
		return
	var foe := SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.unit_at(cell)
		if q != null and q.owner == foe:
			cells.append(cell)
	var amount := _spell_dmg(side, GALE_DMG, null)
	if cells.is_empty():
		_damage_player(foe, amount, "疾风")
		_log("疾风：没有敌方单位 → 对方 HP -%d" % amount)
		return
	var t: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var q2: Placement = state.unit_at(t)
	var dealt := _hit_unit(q2, amount, "疾风")
	_log("疾风：每用一张牌 → %s -%d（剩余 %d）" % [q2.card.card_name, dealt, maxi(0, q2.health)])
	action.emit("gale", {"cell": t, "dmg": dealt, "name": q2.card.card_name})
	if q2.health <= 0:
		_destroy_dead()


func _lurker_tick(side: String, played: CardData) -> void:
	## 潜影者（8009）：在场时该方每使用一张卡（不含它自己上场）→ 力量 +1；
	## 攻击（attack / attack_hp）后清零；离场 = Placement 一并销毁，自然重置。
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.card.id != LURKER_ID or p.card == played:
			continue
		p.ramp_atk += LURKER_RAMP
		_log("潜影者：每用一张牌 → 力量 +%d（当前 %d）" % [LURKER_RAMP, p.effective_power()])
		action.emit("lurker", {"cell": cell, "amount": LURKER_RAMP,
				"power": p.effective_power(), "name": p.card.card_name})


func _sleepless_tick(side: String) -> void:
	## 不眠（9101 效果卡）：自己的回合中，结算收尾时手里没牌 → 抽 1 张；
	## 抽到的 0 费卡本回合费用 +1（turn_card_discount 记 -1，回合结束随表清空）。
	## 挂在 _note_card_played 收尾 = 当前效果结算完毕；选牌面板开着时先不抽，
	## 等选完再补结算（R292：拒绝命运已改自动结算，不再有 fate_pending）。
	if side != SIDE_SELF:
		return
	# ⚠️ 选牌面板开着时先不抽 —— 少一个就出 bug：面板期间回合收尾会照常结算，
	# 把「手牌空了 → 抽 1 张」之类的效果打乱玩家正在做的选择。
	# （R209：`sys_upgrade_pending` 已随那套没用的 pending API 一起删除；手牌目标的
	#  选卡改由场景的选卡页驱动，它自己会拦住出牌与回合收尾。）
	if revive_pending or crow_pending or whale_pending or foresight_pick \
			or endless_pending or shadow_step_pending \
			or focus_pending or overhaul_pending:
		return
	if not _zone_has_id(side, SLEEPLESS_ID) or not state.hand.is_empty():
		return
	var c: CardData = state.draw()
	if c == null:
		return
	var extra := ""
	if c.cost == 0:
		state.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) - 1
		extra = "，0 费 → 本回合费用 +1"
	_log("不眠：手里没牌 → 抽 1 张「%s」%s" % [c.card_name, extra])
	action.emit("sleepless", {"card": c})


func _glowgrass_bonus(side: String) -> int:
	## 荧光草（8010 工事 token）：在场时该方技能伤害 +1（多株叠加）。
	var n := 0
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.card.id == GLOWGRASS_ID:
			n += 1
	return n * GLOWGRASS_SPELL_BONUS


func _latent_turn_draw(side: String) -> void:
	## 潜伏（9092 效果卡）：回合开始时多抽 1 张；抽到 0 费卡 → 再抽 1 张（只多这一次）。
	if not _zone_has_id(side, LATENT_ID):
		return
	if side != SIDE_SELF:
		state.opp_draw(1)
		return
	var first: CardData = state.draw()
	if first == null:
		return
	_log("潜伏：回合开始多抽 1 张「%s」" % first.card_name)
	var second: CardData = null
	if first.cost == 0:
		second = state.draw()
		_log("潜伏：0 费 → 再抽 %s" % (("1 张「%s」" % second.card_name) if second != null else "落空"))
	action.emit("latent", {"card": first, "second": second})


func _shadow_split_draw(side: String) -> void:
	## 分裂之影（8067，R217）：本方回合开始时，场上**每座**分裂之影抽 1 张。
	## 场景：两座在场 → 抽 2 张；一座都没有 → 什么都不做（这个函数直接早退）。
	## 敌方侧只推进 `opp_hand_count`（敌方没有真实手牌，与 `_latent_turn_draw` 同口径）。
	var n := 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(SHADOW_SPLIT_TRAIT):
			n += 1
	if n <= 0:
		return
	if side != SIDE_SELF:
		state.opp_draw(n)
		_log("分裂之影（对方）：回合开始多抽 %d 张" % n)
		return
	var got := _draw_many(n)
	_log("分裂之影：回合开始多抽 %d 张（场上 %d 座）" % [got, n])
	action.emit("shadow_split", {"draw": got, "count": n})


func _glowgrass_supply(side: String) -> void:
	## 幽光（9099 效果卡）：回合开始时，把一张荧光草 token 加入手卡（手牌满 → 落空）。
	if not _zone_has_id(side, GLOW_ID):
		return

	var repo := CardRepo.load_json()
	var base: CardData = repo.get_card(GLOWGRASS_ID)
	var grass := CardData.from_dict(base.to_dict()) if base != null else _fallback_glowgrass()
	# R299：手牌满 → 荧光草直接进弃牌区（不再「没有加入」凭空消失）
	_grant_to_hand(grass, "幽光")
	_log("幽光：一张「荧光草」加入手卡")
	action.emit("glowgrass", {"card": grass})


func _fallback_glowgrass() -> CardData:
	var c := CardData.new()
	c.id = GLOWGRASS_ID
	c.card_name = "荧光草"
	c.kind = "工事"
	c.cost = 0
	c.health = 1
	c.traits = [EGG_VANISH_TRAIT]
	return c


func _ghost_self_destruct(side: String) -> void:
	## 幽灵（8008）：自己回合开始时，场上的幽灵破坏（亡语：卡组随机技能卡入手）。
	for cell: Vector2i in state.board.keys().duplicate():
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.card.id == GHOST_ID:
			_log("幽灵：回合开始 → 自行消散")
			_destroy(cell)


func _whirl_blade(side: String, target, card: CardData) -> String:
	## 回旋斩（9096）：十字范围（中心 + 四邻）上的**敌方单位**各受 17 点伤害
	## （空格 / HP 行不吃，与陨石术「不分敌我」刻意区分）。使用门槛在 use_spell / can_use_card。
	if not (target is Vector2i):
		return "（需要选择十字中心格）"
	var center: Vector2i = target
	var cells: Array[Vector2i] = [center]
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Vector2i = center + d
		if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
			continue
		cells.append(c)
	var amount := _spell_dmg(side, WHIRL_BLADE_DMG, card)
	var hits := 0
	_begin_hp_once()
	for c2: Vector2i in cells:
		var q := state.unit_at(c2)
		if q == null or q.owner == side or q.card.traits.has(SPELL_IMMUNE_TRAIT):
			continue
		_hit_unit(q, amount, "回旋斩")
		hits += 1
	_destroy_dead()
	_end_hp_once()
	_log("回旋斩：十字 %d 格命中敌方单位 %d 个（各 %d 伤）" % [cells.size(), hits, amount])
	action.emit("whirl_blade", {"center": center, "hits": hits, "dmg": amount})
	return "命中 %d 个敌方单位（各 %d 伤）" % [hits, amount]


func _echo_spell(side: String, card: CardData) -> String:
	## 回响（9102）：场上所有敌方单位各受 ECHO_DMG 点伤害，并让它们本回合力量 -ECHO_DEBUFF。
	## 倍率与其它技能一致 —— 走 _spell_dmg（魔法塔 / 魔力核心 / 荧光草 都会加成）；
	## 免疫法术的单位不受伤也不被削弱。场上没有敌方单位 → 空放（不直击对方 HP）。
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var dmg:= _spell_dmg(side, ECHO_DMG, card)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		if state.board[cell].owner == foe:
			cells.append(cell)
	cells.sort()
	var hits:= 0
	var debuffed:= 0
	var blocked:= 0
	var total:= 0
	for c: Vector2i in cells:
		var p: Placement = state.unit_at(c)
		if p == null:
			continue
		if p.card.traits.has(SPELL_IMMUNE_TRAIT):
			blocked += 1
			_log("回响：%s 免疫法术（既不受伤也不被削弱）" % p.card.card_name)
			continue
		var dealt:= _hit_unit(p, dmg, "回响")
		total += dealt
		hits += 1
		if p.health > 0:
			# 降力量与敲晕 / 幻影斗篷同源：debuff_stage=1 → 它所属方回合结束时清掉
			p.atk_debuff += ECHO_DEBUFF
			p.debuff_stage = 1
			debuffed += 1
			action.emit("echo", {"cell": c, "card": p.card, "dmg": dealt,
					"amount": ECHO_DEBUFF, "power": p.effective_power()})
	if hits > 0:
		_destroy_dead()
	_log("回响：%d 个敌人共 -%d（各 %d 伤），%d 个力量 -%d" % [
			hits, total, dmg, debuffed, ECHO_DEBUFF])
	var msg:= "命中 %d 个敌人（各 %d 伤）" % [hits, dmg]
	if debuffed > 0:
		msg += "，力量 -%d" % ECHO_DEBUFF
	if blocked > 0:
		msg += "，%d 个免疫" % blocked
	return msg


func _dodge_spell(side: String) -> String:
	## 闪躲（9103）：置起「盟友代受」窗口。窗口一直开到**自己下个回合开始**
	## （_begin_turn(SIDE_SELF) 清掉）—— 覆盖了中间的敌方回合，否则这张卡在自己回合里
	## 几乎不会触发（玩家在自己的回合里很少挨 HP 伤害）。
	if side != SIDE_SELF:
		return "（闪躲：敌方 AI 不使用这张卡）"
	_dodge_active = true
	_log("闪躲：直到你下个回合开始，你受到的伤害改由随机盟友代替承受")
	action.emit("dodge", {"active": true})
	return "本回合你受到的伤害由随机盟友代受"


func can_use_card(card: CardData, side:= SIDE_SELF) -> bool:
	# R373：**不能打出的卡**（诅咒「麻痹」9185）—— 判据只认 `CardData.unplayable`，
	# UI 置灰与引擎三个出牌入口读的是同一个字段。
	if card != null and card.unplayable:
		return false
	# R317 身法（9173）：本回合用了身法 → 盟友 / 工事卡不可使用（UI 置灰同一判据）。
	# ⚠️ 只锁这两类：场地卡（`is_field()`）不是单位，技能 / 效果卡也不受影响。
	if side == SIDE_SELF and _no_unit_play_this_turn and card != null \
			and (card.kind == "盟友" or card.is_fort()):
		return false
	## 费用之外的「使用条件」（显示 / UI / 引擎同一判定）：
	## 回旋斩（9096）：本回合使用 4 张以上其他卡后才能使用。
	if card != null and card.id == WHIRL_BLADE_ID:
		var plays := state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
		return plays >= WHIRL_BLADE_NEED
	# 夜行（9155，R232）：出牌上限已达 / 本卡作为夜行时已用满 5 张 → 不可使用（UI 置灰）。
	if side == SIDE_SELF:
		if state.card_play_cap > 0 and state.self_card_plays >= state.card_play_cap:
			return false
		if card != null and card.id == NIGHT_WALK_ID and state.self_card_plays >= NIGHT_WALK_MAX:
			return false
	return true


func _fate_reject(side: String) -> String:
	## 拒绝命运（9098）：丢弃**所有**手卡，然后把弃牌区里**所有 0 费 / 1 费卡**
	## 按弃牌区顺序加回手卡（不超过手牌上限）。
	## R292 改「自动结算」：原来是「从弃牌区选等量、必须选满」的模态面板，玩家口径是
	## 「直接把 0/1 费的都捞回来」→ 面板整套（fate_pending / fate_options / fate_pick）已删，
	## 一次结算完、不打断出牌节奏。
	## 本卡带「次元」→ 打完就进消耗区（`_spell_card_gone`），所以捞不到它自己。
	if side != SIDE_SELF:
		return "（拒绝命运：敌方 AI 不使用这张卡）"
	var n := state.hand.size()
	if n > 0:
		state.discard.append_array(state.hand)
		state.hand.clear()
		_log("拒绝命运：丢弃 %d 张手卡" % n)
	var picked: Array[String] = []
	var i := 0
	# ⚠️ 取走一张后**不推进 i**（后面的卡顺移上来）；手牌满了就停 —— 「不超过手牌上限」。
	while i < state.discard.size() and not state.hand_full():
		var c: CardData = state.discard[i]
		if c != null and c.cost <= FATE_CHEAP_MAX:
			state.discard.remove_at(i)
			state.hand.append(c)
			picked.append(c.card_name)
			continue
		i += 1
	if picked.is_empty():
		_log("拒绝命运：弃牌区没有 %d 费以内的卡（只丢了 %d 张手卡）" % [FATE_CHEAP_MAX, n])
		action.emit("fate", {"discarded": n, "picked": 0, "names": []})
		return "丢弃 %d 张，弃牌区没有 0/1 费卡" % n
	_log("拒绝命运：%d 张 0/1 费卡回到手卡（%s）" % [picked.size(), ", ".join(picked)])
	action.emit("fate", {"discarded": n, "picked": picked.size(), "names": picked})
	return "丢弃 %d 张，捞回 %d 张 0/1 费卡" % [n, picked.size()]


func foresight_options() -> Array[int]:
	## 预判①的面板候选：弃牌区里费用为 0 的技能卡。
	var out: Array[int] = []
	for i in state.discard.size():
		var c: CardData = state.discard[i]
		if c.id == FORESIGHT_ID:
			continue   # 预判自己也是 0 费技能卡，但不许选回自己（选完就消失）
		if c.kind == "技能" and c.cost == 0:
			out.append(i)
	return out


func foresight_choose(mode: int) -> bool:
	if not foresight_mode:
		return false
	foresight_mode = false
	if mode == 2:
		var c := _fetch_skill_from_deck(2)
		_log("预判②：%s" % (("卡组随机非 0 费技能卡「%s」加入手卡" % c.card_name) if c != null else "卡组里没有非 0 费技能卡"))
		action.emit("foresight", {"mode": 2, "card": c})
		return true
	if foresight_options().is_empty():
		_log("预判①：弃牌区没有 0 费技能卡，效果落空")
		return true
	if state.hand_full():
		_log("预判①：手牌已满（%d 张），效果落空" % FieldState.HAND_LIMIT)
		return true
	foresight_pick = true
	foresight_vanish = true
	_log("预判①：从弃牌区选择一张 0 费技能卡")
	return true


func foresight_pick_card(discard_index: int) -> bool:
	if not foresight_pick:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if c.kind != "技能" or c.cost != 0:
		return false
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	foresight_pick = false
	for v_i in state.discard.size():
		if state.discard[v_i].id == FORESIGHT_ID:
			_log("预判：用后消失（不进弃牌区，本场不再出现）")
			state.void_cards.append(state.discard[v_i])
			state.discard.remove_at(v_i)
			state.void_count += 1   # R140：消耗区计数（预判自身用后消失）
			break
	_log("预判：%s 回到手牌" % c.card_name)
	action.emit("foresight_pick", {"card": c})
	return true


func _infiltrate_cast(side: String, ally_cell: Vector2i, dst: Vector2i, card: CardData) -> String:
	## 潜入（9100）的公共结算：盟友移到 dst（任意空格，对方后排仍禁入）、
	## 本回合力量 +3（atk_buff_turn，回合结束清除）。移动经过火墙照常灼烧。
	var p := state.unit_at(ally_cell)
	if p == null or p.owner != side or p.card.kind != "盟友":
		return "（需要指定一个自己的盟友）"
	if state.board.has(dst) or not unit_slot_allowed(dst, side):
		return "（目的地必须是空格，且不能是对方的后排）"
	var path := move_path(ally_cell, dst, side)
	state.move_unit(ally_cell, dst)
	if path.size() > 1:
		_fire_wall_pass(path)
	p.atk_buff_turn += INFILTRATE_ATK
	_log("潜入：%s 移动到 %s，本回合力量 +%d（当前 %d）" % [
			p.card.card_name, dst, INFILTRATE_ATK, p.effective_power()])
	action.emit("infiltrate", {"src": ally_cell, "dst": dst,
			"amount": INFILTRATE_ATK, "power": p.effective_power(),
			"name": p.card.card_name})
	return "%s 移动到 %s，力量 +%d" % [p.card.card_name, dst, INFILTRATE_ATK]


func _infiltrate_auto_cell(side: String) -> Vector2i:
	## 自动落点（敌方 AI / 自动出牌用）：己方半场最靠前的空格。
	for r in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for cc in FieldState.BOARD_COLS:
			var c := Vector2i(r, cc)
			if not state.board.has(c):
				return c
	return Vector2i(-1, -1)


func cast_infiltrate(hand_index: int, ally_cell: Vector2i, dst: Vector2i) -> String:
	## 潜入的两段施放入口（UI：先点盟友、再点目的格）。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（潜入：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != INFILTRATE_ID:
		return "（这不是潜入）"
	var p := state.unit_at(ally_cell)
	if p == null or p.owner != SIDE_SELF or p.card.kind != "盟友":
		return "（需要指定一个自己的盟友）"
	if state.board.has(dst) or not unit_slot_allowed(dst, SIDE_SELF):
		return "（目的地必须是空格，且不能是对方的后排）"
	_pay(card)
	state.hand.remove_at(hand_index)
	var detail := _infiltrate_cast(SIDE_SELF, ally_cell, dst, card)
	_log("使用技能 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	return detail


func cast_swap_units(hand_index: int, cell_a: Vector2i, cell_b: Vector2i,
		free_cast := false) -> String:
	## 「双向传送」（8061，R102，机械之心 0 费稀有）的两段施放入口：
	## UI 先点单位甲、再点单位乙。
	##
	## 与「潜入」9100 同一套路：`use_spell` 已在**付费之前**拦掉单段入口，
	## 所以 `_pay` 在**这里**扣。两格必须**不同**、都必须有单位
	##（交换是「两个单位换位置」，空格不参与）。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（双向传送：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != SWAP_UNITS_ID:
		return "（这不是双向传送）"
	if cell_a == cell_b:
		return "（请指定两个不同的单位）"
	var pa := state.unit_at(cell_a)
	var pb := state.unit_at(cell_b)
	if pa == null or pb == null:
		return "（需要指定两个都在场上的单位）"
	# R277：位移免疫 —— **付费之前**拦，否则费用白扣、卡也没了。
	# R371：判据换成 `_displace_immune()` → 启示者（9200）全阶段也算免疫。
	if _displace_immune(pa) or _displace_immune(pb):
		var imm_nm: String = pa.card.card_name \
				if _displace_immune(pa) else pb.card.card_name
		_log("双向传送：%s 免疫位移，交换没有生效" % imm_nm)
		return "（%s 免疫位移，无法交换）" % imm_nm
	# R285：换位也是位移 —— 按**交换后的归属**判（pa 去 cell_b、pb 去 cell_a），
	# 只要有一方要落进对方后排就整笔拒绝。必须放在 `_pay` 之前：
	# 否则费用白扣、卡也没了（R277 双向传送踩过的同一个坑）。
	if not swap_pair_allowed(cell_a, cell_b):
		var sw_nm := pa.card.card_name if not unit_slot_allowed(cell_b, pa.owner) \
				else pb.card.card_name
		_log("双向传送：%s 换过去会落到对方后排，交换没有生效" % sw_nm)
		return "（%s 不能换到对方后排，交换没有生效）" % sw_nm
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)
	var detail := _swap_two_units(cell_a, cell_b)
	_log("使用技能 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	return detail


func _swap_two_units(cell_a: Vector2i, cell_b: Vector2i) -> String:
	## 交换两格上的单位（敌我皆可 —— 卡面写的是「战场上两个单位」）。
	## 只换**位置**：Placement 上的全部状态（横置 / 已移动 / 沉睡 / 冰封…）跟着单位走。
	var pa: Placement = state.board[cell_a]
	var pb: Placement = state.board[cell_b]
	# R277：兜底闸门 —— 敌方 AI（`_swap_auto_cells`）与任何直接调用都不会绕过免疫。
	# R371：同上，统一走 `_displace_immune()`。
	if _displace_immune(pa) or _displace_immune(pb):
		return "（有人免疫位移，交换没有生效）"
	# R285：兜底闸门 —— 与免疫同款，任何直接调用（AI / 以后的新入口）都绕不过去。
	if not swap_pair_allowed(cell_a, cell_b):
		return "（交换会把单位送到对方后排，没有生效）"
	state.board[cell_a] = pb
	state.board[cell_b] = pa
	var detail := "%s ⇄ %s 交换了位置" % [pa.card.card_name, pb.card.card_name]
	action.emit("swap_units", {"a": cell_a, "b": cell_b,
			"card_a": pa.card, "card_b": pb.card})
	return detail


func swap_pair_allowed(cell_a: Vector2i, cell_b: Vector2i) -> bool:
	## **这两个单位能不能换位**（R285，换位的唯一判据；界面第二段的高亮也读它）。
	##
	## 换位按「交换后的归属」判：pa 去 cell_b、pb 去 cell_a —— 双方都必须落在
	## 各自的合法行（`unit_slot_allowed`）。于是「把我方单位换进敌方后排」被拒，
	## 但「我方换到敌方前排 / 中场」「敌方换到敌方后排」照旧允许（只有后排是硬禁区）。
	## 空格 / 不存在的单位一律 false（交换的两格都必须站着人）。
	var pa := state.unit_at(cell_a)
	var pb := state.unit_at(cell_b)
	if pa == null or pb == null:
		return false
	if cell_a == cell_b:
		return false
	return unit_slot_allowed(cell_b, pa.owner) and unit_slot_allowed(cell_a, pb.owner)


func _swap_auto_cells(side: String) -> Array:
	## AI / 自动出牌的兜底落点：场上**最靠前的两个单位**（我方优先，跨敌我皆可）。
	## 敌方 AI 拿不到「玩家点了哪两个格」，所以自己挑一对 —— 优先换开前后排，
	## 对玩家才有点意义（把敌方前排甩到后排）。
	var mine: Array = []
	var foes: Array = []
	for c: Vector2i in state.board:
		var p: Placement = state.board[c]
		if p.owner == side:
			mine.append(c)
		else:
			foes.append(c)
	mine.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x > b.x)
	foes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x)
	# R285：AI 拿不到玩家点了哪两格，但**不能挑一对换完会有人落到对方后排的**。
	# 候选按「先自己人、再自己人+敌人、最后纯敌人」的顺序，取第一个合法配对。
	var cands: Array = []
	if mine.size() >= 2:
		cands.append([mine[0], mine[1]])
	if mine.size() >= 1 and foes.size() >= 1:
		cands.append([mine[0], foes[0]])
	if foes.size() >= 2:
		cands.append([foes[0], foes[1]])
	for pair: Array in cands:
		if swap_pair_allowed(pair[0], pair[1]):
			return pair
	return []


func cast_sys_upgrade(hand_index: int, target_hand_index: int, free_cast := false) -> String:
	## 「系统升级」（8039，R90，机械之心 1 费稀有）的两段施放入口：
	## UI 先点「系统升级」→ 再点**手牌里**一张盟友 / 工事。
	##
	## 与「潜入」9100 同一套路（付费前已在 `use_spell` 拦截单段入口）：
	##   * `_pay` 在**这里**扣（不是 `use_spell`）；
	##   * 目标卡**留在手牌里**（就地改造，原位替换）—— 只有「系统升级」自己进弃牌区。
	##   * `_sys_upgrade_hand_card` 走「复制 + 原位替换」，手牌顺序与扇形布局不受影响。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（系统升级：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != SYS_UPGRADE_ID:
		return "（这不是系统升级）"
	if target_hand_index == hand_index:
		return "（不能改造自己）"
	var tgt: CardData = state.hand[target_hand_index] \
			if target_hand_index >= 0 and target_hand_index < state.hand.size() else null
	if tgt == null or (tgt.kind != "盟友" and not tgt.is_fort()):
		return "（只能改造手牌里的盟友或工事）"
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)   # 目标下标若在被移除项之后要顺移
	if target_hand_index > hand_index:
		target_hand_index -= 1
	var detail := _sys_upgrade_hand_card(target_hand_index)
	_log("使用技能 系统升级 → %s" % detail)
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	return detail


func cast_lighten(hand_index: int, target_hand_index: int, free_cast := false) -> String:
	## 「轻量化」（8068，R269，机械之心 2 费普通）的两段施放入口：
	## UI 先点「轻量化」→ 再点**手牌里**一张盟友。
	##
	## 与「系统升级」8039 完全同一套路：
	##   * `_pay` 在**这里**扣（`use_spell` 的单段入口已在付费前拦掉）；
	##   * 目标卡**留在手牌里**（就地改造、原位替换）—— 只有「轻量化」自己进弃牌区。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（轻量化：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != HAND_LIGHTEN_ID:
		return "（这不是轻量化）"
	if target_hand_index == hand_index:
		return "（不能改造自己）"
	var tgt: CardData = state.hand[target_hand_index] \
			if target_hand_index >= 0 and target_hand_index < state.hand.size() else null
	if tgt == null or tgt.kind != "盟友":
		return "（只能改造手牌里的盟友）"
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)   # 目标下标若在被移除项之后要顺移
	if target_hand_index > hand_index:
		target_hand_index -= 1
	var detail := _lighten_hand_card(target_hand_index)
	_log("使用技能 轻量化 → %s" % detail)
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	return detail


func cast_recycle(hand_index: int, target_hand_index: int, free_cast := false) -> String:
	## 「回收」（8064，R198，机械之心 2 费史诗）的两段施放入口：
	## UI 先点「回收」→ 再点**手牌里任意一张卡**（不限盟友/工事 —— 回收就是
	## 把卡换成素体，技能/场地卡同样能回收；不能选自己）。
	##
	## 结算（与「潜入」9100 / 「系统升级」8039 同一套路）：
	##   * `_pay` 在**这里**扣（不是 `use_spell`）—— 单段入口已在付费前拦截；
	##   * 目标那张被**原位替换**成一张独立的「素体」副本（卡库共享实例 →
	##     `from_dict` 复制 + 切断 traits 共享引用，绝不动卡库），手牌顺序与
	##     扇形布局不受影响；
	##   * 替换后立刻施加一次改造：生命 +RECYCLE_HP，走 `_upgrade_hp_gain`
	##     **唯一口**（素体自己的 +1 血照算 → 实际 +9 → 0 费 1/10）；
	##   * 「回收」自己进弃牌区；数值**烤进副本**、**本场战斗永久**
	##     （下一场 `build_deck()` 重新从卡库取实例 → 自动重置）。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（回收：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != RECYCLE_ID:
		return "（这不是回收）"
	if target_hand_index == hand_index:
		return "（不能回收自己）"
	var tgt: CardData = state.hand[target_hand_index] \
			if target_hand_index >= 0 and target_hand_index < state.hand.size() else null
	if tgt == null:
		return "（回收：目标手牌序号无效）"
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)   # 目标下标若在被移除项之后要顺移
	if target_hand_index > hand_index:
		target_hand_index -= 1
	# 换卡：取一张干净的素体副本（卡库共享实例 → from_dict 复制 + 切断共享引用）。
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(PROTO_ID) if repo != null else null
	if proto == null:
		# 卡库不该缺素体；万一缺了也别把目标那张吞掉 → 原样留在手里，只当白花一费。
		_log("回收：卡库缺少「素体」(8025)，目标保持原样")
		# R292：回收统一走 transform 那条口，不再有自己的 action；这里是**防御分支**
		# （卡库不该缺素体），只留日志，不 emit 任何界面事件。
		_note_card_played(SIDE_SELF, card)
		state.discard.append(card)
		return "回收：卡库缺少素体，效果落空"
	var body := CardData.from_dict(proto.to_dict())
	body.traits = (body.traits as Array).duplicate()   # 切断与卡库的共享引用
	# R198：改造走**唯一口**（素体自身被改造时额外 +1 生命 → 实际 +9）。
	var rc_hp: int = _upgrade_hp_gain(body, RECYCLE_HP)
	body.health += rc_hp
	body.upgrade_stacks += 1   # R209：卡面写的就是「使其获得改造」→ 记一层随身带
	var rc_old: String = tgt.card_name
	# R292：用户口径「回收效果属于**变成**类」→ 换卡不再自己手搓，走**变化的唯一口**
	# `_transform_hand_card`：① 发明专家（9143）每变化一张卡回 2 费；② 变幻特效由界面
	# 的 transform 分支统一播（不再是回收专属的一套）；③ 以后任何「变化时」的钩子都会
	# 自动吃到，不必再回来给回收补分支。改造后的数值挂在 extra 上，播报照旧写清 1/10。
	_transform_hand_card(SIDE_SELF, target_hand_index, body, "回收", false,
			{"recycle_hp": rc_hp, "recycled": rc_old})
	_log("回收：%s → 素体（改造：生命 +%d → %d 攻 / %d 血，本场战斗永久）"
		% [rc_old, rc_hp, body.power, body.health])
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	_inspire_tick()   # R300 激发：回收把一张手牌变成改造素体 = 一次改造动作
	return "%s → 素体（%d 攻 / %d 血）" % [rc_old, body.power, body.health]


func cast_reload(hand_index: int, target_hand_index: int, free_cast := false) -> String:
	## 「填充」（9146，R202，机械之心 0 费普通技能）的两段施放入口：
	## UI 先点「填充」→ 再点**手牌里任意一张卡**，目标被原位替换为「聚能炮击」。
	## 与「回收」（8064）同套路：费用在这里扣；目标不限种类；不能选自己。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（填充：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != RELOAD_ID:
		return "（这不是填充）"
	if target_hand_index == hand_index:
		return "（不能填充自己）"
	var tgt: CardData = state.hand[target_hand_index] \
			if target_hand_index >= 0 and target_hand_index < state.hand.size() else null
	if tgt == null:
		return "（填充：目标手牌序号无效）"
	if not free_cast:
		_pay(card)
	state.hand.remove_at(hand_index)   # 目标下标若在被移除项之后要顺移
	if target_hand_index > hand_index:
		target_hand_index -= 1
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(ENERGY_CANNON_ID) if repo != null else null
	if proto == null:
		_log("填充：卡库缺少「聚能炮击」(9145)，目标保持原样")
		action.emit("reload", {"card": null, "ok": false})
		_note_card_played(SIDE_SELF, card)
		_spell_card_gone(card)   # R211：填充带「次元」→ 用后消失（不进弃牌区）
		return "填充：卡库缺少聚能炮击，效果落空"
	var rc_old: String = tgt.card_name
	var res := _transform_hand_card(SIDE_SELF, target_hand_index, proto, "填充")
	var body: CardData = res.get("new", null) as CardData
	_note_card_played(SIDE_SELF, card)
	_spell_card_gone(card)   # R211：填充带「次元」→ 用后消失（不进弃牌区）
	if body != null:
		return "填充：%s → %s" % [rc_old, body.card_name]
	return "填充：%s 没有变化" % rc_old


func _life_cycle(target, side:= SIDE_SELF) -> String:
	## 生命循环（9150，R227）：选一个**己方盟友** → 获得字段「次元」「死亡」。
	## 只认 `kind == "盟友"`（工事不是「盟友」，与森林守护 / 狂暴同口径）；
	## 重复施放同一个目标 → 直接返回提示，不重复挂（0 费，避免玩家白点也没变化）。
	var p:= _target_placement(side, target)
	if p == null or p.owner != side:
		return "（需要指定一个己方盟友）"
	if p.card.kind != "盟友":
		return "生命循环：只能指定己方盟友（%s 不是盟友）" % p.card.card_name
	if p.life_cycle:
		return "「%s」已经获得生命循环" % p.card.card_name
	for lc_a: String in [AFFIX_DIMENSION, AFFIX_DEATH]:
		if p.card.add_affix(lc_a):
			p.life_cycle_added.append(lc_a)
	p.life_cycle = true
	_log("生命循环：%s 获得「次元」与「死亡」（被破坏时加一张随机盟友卡到手卡）"
			% p.card.card_name)
	action.emit("life_cycle_grant", {"cell": _cell_of(p), "card": p.card, "side": side})
	return "%s 获得「次元」+「死亡」" % p.card.card_name


func _life_cycle_death(p: Placement, cell: Vector2i) -> void :
	## 生命循环的「死亡」：被破坏时把**一张随机盟友卡**加入手卡。
	## 随机源 = 本角色奖励池里的盟友卡（与「新生」9148 同口径，走引擎 rng）；
	## 池里一张盟友都没有 → 退到全部玩家盟友卡；仍为空 → 只打日志。
	## 手牌满 → 这张卡不进来（与其它「加入手卡」同口径：不静默丢，写清楚）。
	if p.owner != SIDE_SELF:
		return                     # 只有玩家能施放本卡，敌方分支不需要效果
	var c:= _random_ally_card(p.owner)
	if c == null:
		_log("生命循环：卡池里没有盟友卡可加入手卡")
		return
	var copy:= CardData.from_dict(c.to_dict())
	copy.affixes = (c.affixes as Array).duplicate()
	# R299：手牌满 → 直接进弃牌区（亡语不再因为满手白掉）
	_grant_to_hand(copy, "生命循环")
	_log("生命循环：%s 被破坏 → 手卡加入「%s」" % [p.card.card_name, copy.card_name])
	action.emit("life_cycle", {"card": copy, "from": p.card, "cell": cell})


func _blade_gift(target, side:= SIDE_SELF) -> String:
	## 辅助刃（9164，R291，机械之心）：选一个**己方盟友** → 改造它（力 +BLADE_ATK），
	## 并挂「死亡」：被破坏时把**一张辅助刃**加入手卡。
	##
	## 改造走 `_field_upgrade_grant()`（场上改造唯一口）—— 层数 / 卡面改造奖励 /
	## 「每次被改造」那一族全部自动生效，这里一行都不手写。
	## ⚠️ 只认 `kind == "盟友"`：工事不是「盟友」（与生命循环 9150 / 加厚装甲 8044 同口径）。
	## ⚠️ 允许对同一个目标重复施放（每次各 +BLADE_ATK 力量、各算一层改造）——
	##    卡面没有「只能一次」，而亡语回收的那张就该能再点一次。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能改造自己的单位"
	if p.card.kind != "盟友":
		return "辅助刃：只能指定己方盟友（%s 不是盟友）" % p.card.card_name
	# 「死亡」字段是不是这张卡**原本没有**的 —— 只有新加的才记进 `blade_added`（离场要摘）。
	var new_death_affix := not p.card.has_affix(AFFIX_DEATH)
	_field_upgrade_grant(p, BLADE_ATK, 0, "辅助刃", AFFIX_DEATH)
	_inspire_tick()   # R300 激发：辅助刃 = 一次改造动作
	if new_death_affix and not p.blade_added.has(AFFIX_DEATH):
		p.blade_added.append(AFFIX_DEATH)
	p.blade_gift = true
	_log("辅助刃：%s 改造 → 力量 +%d，并获得「死亡」（%d 攻，第 %d 层）" % [
			p.card.card_name, BLADE_ATK, p.effective_power(), p.upgrade_stacks])
	return "%s 力量 +%d，并获得「死亡」" % [p.card.card_name, BLADE_ATK]


func _blade_gift_death(p: Placement, cell: Vector2i) -> void :
	## 辅助刃的「死亡」：被破坏时把**一张辅助刃**加入手卡。
	## 与生命循环的随机盟友不同 —— 这里是**固定一张本卡**（卡面写的就是「一张辅助刃」）。
	## R299：手牌满 → 这张「辅助刃」直接进弃牌区（不再「不进来」白丢）。
	if p.owner != SIDE_SELF:
		return                     # 只有玩家能施放本卡，敌方分支不需要效果
	var proto: CardData = CardRepo.load_json().get_card(BLADE_GIFT_ID)
	if proto == null:
		_log("辅助刃：卡库缺少「辅助刃」(9164)，亡语落空")
		return
	# ⚠️ 必须 from_dict 复制成独立实例（卡库是共享实例）—— 与其它「加入手卡」同一条纪律。
	var copy:= CardData.from_dict(proto.to_dict())
	copy.traits = (proto.traits as Array).duplicate()
	copy.affixes = (proto.affixes as Array).duplicate()
	copy.own_copy = true
	_grant_to_hand(copy, "辅助刃")
	_log("辅助刃：%s 被破坏 → 「%s」入手/进弃牌" % [p.card.card_name, copy.card_name])
	action.emit("blade_gift_death", {"card": copy, "from": p.card, "cell": cell})


func _duplicate_spell(target, side:= SIDE_SELF) -> String:
	## 复制术（9165，R291，机械之心史诗）：选一个**己方盟友或工事** → 把它的
	## DUPLICATE_COUNT 份复制加入手卡（保留 buff、带「次元」），本回合在手牌里 0 费。
	##
	## 「保留 buff」的具体口径（与卡面一致，也和「重启 8054 回手」相反 —— 那个是**还原**）：
	##   * 力量：`card.power + Placement.upgrade_atk`（场上的改造加攻不在 card 里，必须先并进去，
	##     否则复制品上场后力量会掉回卡面值）；
	##   * 生命：直接取 `card.health`（改造加血 / 栅栏修复术都烤在这个副本上了）；
	##   * 攻程 / 移速：同理已烤在副本上（`_upgrade_unit` / `place()` 干的），原样带走；
	##   * `upgrade_stacks` **置 0**：上面这些数值已经全在副本里了，再随身带层数会被
	##     `FieldState.place()` 按层数再折一次（堡垒 +3 血/层、榴弹击手 +1 程/层）→ 双计。
	##     代价是复制品不带「改造 ×N」徽标 / 侦察塔光环 —— 数值一致优先。
	##   * 「次元」字段：上场后离场即消失（`_destroy` 认字段），不会变成永久卡。
	## 手牌不足 → 能加几张加几张（不静默吞掉，日志与返回值都写清楚）。
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	if p.owner != side:
		return "只能复制自己的单位"
	if p.card.kind != "盟友" and not p.card.is_fort():
		return "%s 不能被复制" % p.card.card_name
	var made := 0
	for _i in DUPLICATE_COUNT:
		var copy:= CardData.from_dict(p.card.to_dict())
		copy.traits = (p.card.traits as Array).duplicate()
		copy.affixes = (p.card.affixes as Array).duplicate()
		# 「死亡」若是辅助刃挂上去的（`blade_added`），复制品**不带走** —— 那条亡语挂在
		# `Placement.blade_gift` 上，复制品上场后没有这个标记，留着字段就是「卡面写着却不触发」
		# （R227 立的口径）。力量那部分照常保留（已烤进 power）。
		for bg_a: String in p.blade_added:
			copy.affixes.erase(bg_a)
		copy.power = p.card.power + p.upgrade_atk   # 保留力量改造（它只在 Placement 上）
		copy.upgrade_stacks = 0                     # 数值已烤进副本 → 不再随身，防 place 双计
		copy.own_copy = true
		copy.add_affix(AFFIX_DIMENSION)
		# R299：手牌满 → 复制品直接进弃牌区（带「次元」，不会被洗回牌库变成永久卡）。
		_grant_to_hand(copy, "复制术")
		state.turn_free[copy] = true   # 本回合 0 费；end_turn 清空 → 没打出去的下回合原价
		made += 1
	if made == 0:
		return "复制术：没有复制生成"
	action.emit("duplicate", {"cell": target, "card": p.card, "count": made,
			"placement": p})
	_log("复制术：%s → %d 张带「次元」的复制加入手卡（本回合 0 费）" % [
			p.card.card_name, made])
	return "%s 复制 %d 张（本回合 0 费）" % [p.card.card_name, made]


func _random_ally_card(side: String) -> CardData:
	## 本角色奖励池里的随机**盟友**卡（生命循环的随机源，R227）。
	## 走引擎 `rng` → 同种子同结果、回放可复现（与新生 9148 / 随心组装同一口径）。
	var cid:= RunState.player_class if side == SIDE_SELF else ""
	var repo:= CardRepo.load_json()
	var pool: Array[CardData] = []
	for c: CardData in repo.reward_pool_for(cid):
		if c.kind == "盟友":
			pool.append(c)
	if pool.is_empty():
		for c: CardData in repo.player_cards():
			if c.kind == "盟友":
				pool.append(c)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


func _sync_harp() -> void:
	## 竖琴（6052，R352 / R372）：「所有盟友 +2 力量」是**持续 buff**，记在
	## `Placement.harp_atk` 上，由 `Placement.effective_power()` 并进攻击力。
	## 这个函数只负责「让场上每个己方盟友的 buff 与当前是否持有竖琴对齐」：
	##   * 持有 → 一律**赋值**成 `HARP_ATK`（不是 +=）→ 调多少次都还是 2；
	##   * 不持有 → 清 0（中途失去道具时不会留下幽灵加成）。
	## 需要它的原因：道具可能在**战斗中途**拿到（宝箱 / 精英掉落），那批盟友上场时
	## 还没有竖琴；读档续战同理。幂等，随便多调。
	var has_harp := RunState.has_relic(HARP_RELIC_ID)
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != SIDE_SELF or p.health <= 0 or p.card == null:
			continue
		if p.card.kind != "盟友":
			continue
		var want := HARP_ATK if has_harp else 0
		if p.harp_atk == want:
			continue
		p.harp_atk = want
		if want > 0:
			_log("竖琴：%s 补吃 +%d 力量（%d）"
					% [p.card.card_name, HARP_ATK, p.effective_power()])


func _knight_sword_active() -> bool:
	## 骑士剑（6053）此刻是否生效 = **本场已经触发过** 且 **现在仍持有道具**。
	## 拆成一个口，是因为有三处要判（place / 同步 / 技能伤害），口径必须一致。
	return _knight_sword_fired and RunState.has_relic(KNIGHT_SWORD_RELIC_ID)


func _knight_sword_on_kill(victim: Placement) -> void:
	## R383 骑士剑（6053）：**本场战斗的第一次击杀** —— 己方所有盟友 +2 力量、
	## 己方技能伤害 +2，持续到本场战斗结束。
	## 只认第一次：`_knight_sword_fired` 一置位就再也不进门（不会叠成 +4）。
	## 没持有道具时杀敌**不置位** —— 中途拿到道具，从拿到那一刻起算第一次。
	if _knight_sword_fired or not RunState.has_relic(KNIGHT_SWORD_RELIC_ID):
		return
	_knight_sword_fired = true
	_sync_knight_sword(true)
	_log("骑士剑：击杀 %s → 本场战斗己方盟友 +%d 力量、技能伤害 +%d"
			% [victim.card.card_name, KNIGHT_SWORD_ATK, KNIGHT_SWORD_SPELL])
	action.emit("knight_sword", {"amount": KNIGHT_SWORD_ATK, "spell": KNIGHT_SWORD_SPELL,
			"card": victim.card})


func _sync_knight_sword(announce := false) -> void:
	## 骑士剑（6053）「持续 buff」的同步口：把场上每个己方盟友的 `sword_atk` 与
	## 「本场是否已触发 + 此刻是否持有」对齐（赋值，不累加 —— 与竖琴 R372 同一口径）。
	## 需要它的原因：触发那一刻场上的人要吃、**之后上场**的人也要吃、中途拿到道具 / 失去
	## 道具都要对齐。幂等，随便多调。`announce` 只给「刚触发」那一下打日志，例行同步不刷屏。
	var active := _knight_sword_active()
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != SIDE_SELF or p.health <= 0 or p.card == null:
			continue
		if p.card.kind != "盟友":
			continue
		var want := KNIGHT_SWORD_ATK if active else 0
		if p.sword_atk == want:
			continue
		p.sword_atk = want
		if want > 0 and announce:
			_log("骑士剑：%s 获得 +%d 力量（%d）"
					% [p.card.card_name, KNIGHT_SWORD_ATK, p.effective_power()])


func _random_forest_ally() -> CardData:
	## 森林精魄奖励池里的随机**盟友**卡（森林的朋友们 9183 的随机源，R352）。
	## 与 `_random_ally_card()` 的区别：那里取「本角色」，这里**写死森林精魄**——
	## 卡面写的就是「森林的朋友们」，暗影 / 机械角色打出它也该来森林的盟友。
	## 池子走 `reward_pool_for()` → 剧情锁定与**本局禁卡**一并生效。
	var repo := CardRepo.load_json()
	var pool: Array[CardData] = []
	for c: CardData in repo.reward_pool_for(PlayerClass.DRUID):
		if c.kind == "盟友":
			pool.append(c)
	if pool.is_empty():
		# 退路：奖励池被禁卡 / 剧情锁清空时，直接翻全部森林盟友卡
		for c2: CardData in repo.player_cards():
			if c2.kind == "盟友" and c2.class == PlayerClass.DRUID:
				pool.append(c2)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


func _random_reward_card(side: String) -> CardData:
	## 从本角色奖励卡池里按「稀有度三等分」随机取一张卡（R202 随心组装）。
	## 稀有度 0/1/2 各取一份，先均匀挑稀有度，再在该稀有度里随机挑卡。
	var cid := RunState.player_class if side == SIDE_SELF else ""
	var pool: Array[CardData] = CardRepo.load_json().reward_pool_for(cid)
	var by_rarity: Dictionary = {0: [] as Array[CardData], 1: [] as Array[CardData], 2: [] as Array[CardData]}
	for c: CardData in pool:
		if c.rarity <= 2:
			by_rarity[c.rarity].append(c)
	var nonempty: Array[int] = []
	for r in [0, 1, 2]:
		if not by_rarity[r].is_empty():
			nonempty.append(r)
	if nonempty.is_empty():
		return null
	var rar: int = nonempty[rng.randi() % nonempty.size()]
	var lst: Array[CardData] = by_rarity[rar] as Array[CardData]
	return lst[rng.randi() % lst.size()]


func _inventory_sort(side: String) -> String:
	## 「库存整理」9184（R370，机械之心 1 费史诗技能）：
	##   从**卡组**随机挑 `INVENTORY_COUNT` 张 → 各**原位**换成一张随机卡。
	## * 池子走 `_random_reward_card()`（本职业奖励池 / 稀有度三等分）—— 与随心组装 9144 同源；
	## * 「变成**另一张**卡」：摇到与旧卡同 id 就重摇，最多 `INVENTORY_REROLL` 次
	##   （池子里同 id 只有一张时允许兜底同卡，不死循环）；
	## * 替换的一定是**新副本**（`from_dict` + 切断 traits 共享引用），不动卡库实例；
	## * 卡组不足 2 张就有几张变几张；一张都没有 → 效果落空（与淘汰 9174 同口径）。
	var total := state.deck.size()
	if total <= 0:
		_log("库存整理：卡组是空的，效果落空")
		return "卡组是空的，效果落空"
	var idxs: Array[int] = []
	for i in total:
		idxs.append(i)
	# 洗下标（Fisher-Yates，走 rng）→ 前 N 个就是「被整理的那几张」，卡组顺序本身不动
	for k in range(idxs.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var t: int = idxs[k]
		idxs[k] = idxs[j]
		idxs[j] = t
	var picked: Array[int] = []
	for k in mini(INVENTORY_COUNT, idxs.size()):
		picked.append(idxs[k])
	picked.sort()   # 升序 → 日志 / 事件顺序稳定，便于测试与回放对账
	var pairs: Array = []
	for di: int in picked:
		var old: CardData = state.deck[di]
		if old == null:
			continue
		var pick: CardData = _random_reward_card(side)
		var guard := 0
		while pick != null and pick.id == old.id and guard < INVENTORY_REROLL:
			pick = _random_reward_card(side)
			guard += 1
		if pick == null:
			continue
		var nc: CardData = CardData.from_dict(pick.to_dict())
		nc.traits = (nc.traits as Array).duplicate()
		state.deck[di] = nc
		pairs.append({"index": di, "old": old, "new": nc})
	# R404：库存整理变的是**卡组**里的卡（不走 `_transform_hand_card` / `_invention_refund`）
	# → 这里按「变了 N 张」单独补记，失控要塞 9161 才能把这几张数进去。
	for _inv_i in pairs.size():
		_note_card_changed(side)
	if pairs.is_empty():
		_log("库存整理：卡库里没有可变的卡，效果落空")
		return "卡组里没有可变的卡"
	var names: Array[String] = []
	for pr: Dictionary in pairs:
		names.append("%s → %s" % [(pr["old"] as CardData).card_name,
				(pr["new"] as CardData).card_name])
	var txt := "、".join(names)
	_log("库存整理：卡组 %d 张变成随机卡（%s）" % [pairs.size(), txt])
	action.emit("deck_transform", {"pairs": pairs, "side": side})
	return "卡组 %d 张变成随机卡（%s）" % [pairs.size(), txt]


func _note_card_changed(side: String) -> void :
	## **变化计数**唯一记账口（R404）—— `state.self_card_changes` 的消费方是失控要塞 9161
	## （入场时每变化过一张牌 → 随机释放一张机械之心技能卡）。
	## 调用点（一共三处，加新来路时照着补，别各写一遍 `+= 1`）：
	##   * `_invention_refund()` 开头 —— 覆盖**所有手牌变化**（`_transform_hand_card()`：
	##     回收 / 填充 / 创意 / 随心组装 / 报废 / 量产型代达罗斯 / 惊喜运单）；
	##   * 库存整理 9184 —— 它变的是**卡组**里的卡，不走 `_transform_hand_card()`；
	##   * 惊喜运单 8079 —— 卡组 → 手卡，已经过 `_invention_refund()`，不重复记。
	## ⚠️ **只记我方**：敌方没有真实手牌，「变化」对它没有可结算的对象。
	if side == SIDE_SELF:
		state.self_card_changes += 1


func _invention_refund(side: String, source_name: String) -> void:
	## 「发明专家」9143 的触发唯一口：每变化一张卡回 2 费，多张发明专家不叠加。
	## R404：开头先记「变化计数」（见 `_note_card_changed()`）—— 发明专家在不在场都记。
	_note_card_changed(side)
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var has_expert := false
	for c: CardData in zone:
		if c.id == INVENTION_EXPERT_ID:
			has_expert = true
			break
	if not has_expert:
		return
	if side == SIDE_SELF:
		state.energy += INVENTION_REFUND
	else:
		state.opp_energy += INVENTION_REFUND
	_log("发明专家：%s 变化一张卡，回复 %d 点费用" % [source_name, INVENTION_REFUND])
	action.emit("invention_refund", {"side": side, "amount": INVENTION_REFUND})


func _transform_hand_card(side: String, hand_index: int, new_card: CardData,
		source_name: String, random_born := false, extra := {}) -> Dictionary:
	## 变化一张手牌：把 state.hand[hand_index] 替换成 new_card 的独立副本，
	## 触发「发明专家」回费，并 emit "transform" 动作给 UI。
	## `extra`：额外塞进 action 负载的字段（R292 回收用它带「改造回血值 / 被换掉的原卡名」，
	##   界面据此仍能报「X → 素体 1/10」，不必为它单开一条 action）。
	## `random_born = true` → 这张新卡标记「以**随机**变化的方式加入手卡」，
	## 并立刻结算 `_apply_random_born()`（谟涅摩叙涅 -2 费 / 量产型代达罗斯 +2+2）。
	## ⚠️ 只有**随机**来源才传 true（随心组装 9144 / 创意 8070）；填充 9146 / 报废 8071 /
	##    量产型代达罗斯的入场效果都是**确定**变化，传 false。
	var out: Dictionary = {"old": null, "new": null}
	if hand_index < 0 or hand_index >= state.hand.size():
		return out
	var old_card: CardData = state.hand[hand_index]
	var copy: CardData = CardData.from_dict(new_card.to_dict())
	copy.traits = (copy.traits as Array).duplicate()   # 切断与卡库的共享引用
	copy.random_born = random_born
	state.hand[hand_index] = copy
	if random_born:
		_apply_random_born(copy)
	_invention_refund(side, source_name)
	_log("%s：%s → %s" % [source_name, old_card.card_name, copy.card_name])
	var payload := {"side": side, "index": hand_index, "old": old_card, "new": copy,
			"source": source_name}
	for k in extra:
		payload[k] = extra[k]
	action.emit("transform", payload)
	out["old"] = old_card
	out["new"] = copy
	return out


func _assemble_at_will(side: String) -> String:
	## 「随心组装」9144：把手牌里所有卡变成随机奖励卡（按稀有度概率相等）。
	## R276 新增：变化出的**盟友卡**本回合费用 -1（`state.hand_cost_turn`，回合结束清空、
	## 离手也自动恢复原价）。注意只算**变出来的结果**是盟友的，工事 / 技能 / 效果不减。
	var count := 0
	var cheap := 0
	for i in state.hand.size():
		var pick: CardData = _random_reward_card(side)
		if pick == null:
			continue
		var res: Dictionary = _transform_hand_card(side, i, pick, "随心组装", true)   # R271：随机变化
		var nc: CardData = res.get("new")
		if nc != null and nc.kind == "盟友":
			state.hand_cost_turn[nc] = int(state.hand_cost_turn.get(nc, 0)) + 1
			cheap += 1
		count += 1
	if cheap > 0:
		_log("随心组装：其中 %d 张盟友卡本回合费用 -%d" % [cheap, ASSEMBLE_ALLY_DISCOUNT])
	return "随心组装：变化了 %d 张手牌（%d 张盟友本回合 -%d 费）" % [
		count, cheap, ASSEMBLE_ALLY_DISCOUNT]


func _trait_copies(zone: Array[CardData], tname: String) -> int:


	## 效果区里带该 trait 的卡有几张 —— 即「每回合第 X 次」的 X。
	var n:= 0
	for c: CardData in zone:
		if c.traits.has(tname):
			n += 1
	return n


func _trait_max_value(zone: Array[CardData], tname: String) -> int:


	## 同类效果卡里最高的 value（叠加时按最高的一张结算数值，不求和）。
	var v:= 1
	for c: CardData in zone:
		if c.traits.has(tname):
			v = maxi(v, maxi(1, c.value))
	return v


func _first_with_trait(zone: Array[CardData], tname: String) -> CardData:
	for c: CardData in zone:
		if c.traits.has(tname):
			return c
	return null


func _turn_growth(side: String, tname: String, evt: String, amount: int, from_value: bool) -> int :
	## 回合开始「永久成长」的唯一结算口（夜行 / 精进 / 使魔之力 共用；改机制只动这里）。
	## 本方带 tname 的单位力量 +amount（永久累计，无上限）；from_value=true 时改读该卡自身 value。
	## 返回成长了的单位数（供调用方打日志）。
	var boosted:= 0
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != side or not p.card.traits.has(tname):
			continue
		var inc:= maxi(1, p.card.value) if from_value else maxi(1, amount)
		p.atk_buff += inc
		boosted += 1
		_log("%s %s：力量 +%d（当前 %d）" % [
			p.card.card_name, tname, inc, p.effective_power()])
		action.emit(evt, {"cell": cell, "card": p.card, "amount": inc,
			"power": p.effective_power()})
	if boosted > 0:
		_log("%s：%d 个单位回合开始成长" % [tname, boosted])
	return boosted


func _night_growth(side: String) -> void :


	## 夜行（夜鸭 9027）：回合开始力量 +卡面 value（永久累计，无上限）。
	_turn_growth(side, NIGHT_GROW_TRAIT, "night_grow", 0, true)


func _mage_growth(side: String) -> void :


	## 精进（白魔法鸭 9021）：回合开始力量 +MAGE_GROW_BUFF（永久累计，无上限，无前置条件）。
	_turn_growth(side, MAGE_GROW_TRAIT, "mage_grow", MAGE_GROW_BUFF, false)


func _on_effect_card_played(side: String, played: CardData) -> void :



	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	if zone.is_empty():
		return
	var plays:= state.self_effect_plays if side == SIDE_SELF else state.opp_effect_plays
	# 每用一张就该触发的（不受「第 X 次」限制）→ 按效果区张数逐张结算。
	for c: CardData in zone:
		if c.traits.has(ARCANE_TRAIT):
			_arcane_refund(side, maxi(1, c.value))
		if c.traits.has(FAMILIAR_NIGHT_TRAIT):
			_crow_to_hand(side)
	# 镜像（9056）：每回合**第一次**使用效果牌时，把该牌的一张同名副本加入本局卡组。
	# 「不可叠加」→ 效果区里有几张镜像都只触发一次、只加一张，**不进**下面的「每回合第 X 次」放宽组。
	if _trait_copies(zone, MIRROR_TRAIT) > 0 and plays <= 1:
		_mirror_reflect(side, played)
	# 「每回合第 X 次」：X = 效果区里该类卡的张数 → 本回合**前 X 次**使用效果牌都会触发，每张各一次。
	# 单张时 X = 1（与原来的「每回合第一次」完全一致）；叠几张就放宽到前几次。
	var det_n:= _trait_copies(zone, DETERRENCE_TRAIT)
	if det_n > 0 and plays <= det_n:
		_deterrence(side, _trait_max_value(zone, DETERRENCE_TRAIT))
	var nest_n:= _trait_copies(zone, DUCK_NEST_TRAIT)
	if nest_n > 0 and plays <= nest_n:
		_egg_to_hand("鸭窝（本回合第 %d 次效果牌）" % plays)


func _on_turn_first_play(side: String, played: CardData) -> void :



	if side != SIDE_SELF or played == null:
		return
	# R268（用户口径「只由效果卡触发」）：触发源 = **只认效果卡**，技能卡不再触发。
	# 与同一族的「威慑 / 镜像 / 鸭窝」对齐——它们的「每回合前 X 次」也都是效果牌驱动。
	# 这两张自身也是效果卡，所以必须先把「打出本卡本身」挡掉（否则落地即自触发）。
	if played.id == AETHER_ROAR_ID or played.id == SPACE_GUARD_ID:
		return
	if not played.is_effect():
		return
	# 「每回合第 X 次」：X = 效果区里该类卡的张数（单张时 X=1 → 就是原来的「每回合首次」）。
	var roar_n:= _trait_copies(state.effects, AETHER_ROAR_TRAIT)
	if roar_n > 0 and _roar_fires < roar_n:
		_roar_fires += 1
		var roar_c:= _first_with_trait(state.effects, AETHER_ROAR_TRAIT)
		if roar_c != null:
			_aether_roar(roar_c)
	var sg_n:= _trait_copies(state.effects, SPACE_GUARD_TRAIT)
	if sg_n > 0 and _space_fires < sg_n:
		_space_fires += 1
		var sg_c:= _first_with_trait(state.effects, SPACE_GUARD_TRAIT)
		if sg_c != null:
			_space_guard(sg_c)


func _aether_roar(c: CardData) -> void :
	var dmg:= maxi(1, c.value)
	var foe:= SIDE_OPPONENT
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		if state.board[cell].owner == foe:
			cells.append(cell)
	cells.sort()
	if cells.is_empty():
		_log("以太咆哮：场上没有敌方单位 → 直击敌方 HP %d 点" % dmg)
		_damage_player(foe, dmg, "以太咆哮")
		action.emit("aether_roar", {"dmg": dmg, "hits": 0, "hp": dmg})
		return
	var n:= 0
	for cell in cells:
		var q: Placement = state.unit_at(cell)
		if q == null:
			continue
		_hit_unit(q, dmg, "以太咆哮")
		n += 1
	_log("以太咆哮：%d 个敌人各受到 %d 点伤害" % [n, dmg])
	_destroy_dead()
	action.emit("aether_roar", {"dmg": dmg, "hits": n})


func _space_guard(c: CardData) -> void :


	var steps:= maxi(1, c.value)
	var best_row:= -1
	var near: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		if state.board[cell].owner != SIDE_OPPONENT:
			continue
		# R277：免疫位移的单位不参与「最靠前」的评选。
		if state.board[cell].card.traits.has(DISPLACE_IMMUNE_TRAIT):
			continue
		if cell.x > best_row:
			best_row = cell.x
			near = [cell]
		elif cell.x == best_row:
			near.append(cell)
	if near.is_empty():
		_log("空间守护：没有可被位移的敌方单位，未生效")
		return
	var t: Vector2i = near[rng.randi() % near.size()]
	var p: Placement = state.unit_at(t)
	var msg:= _knockback(SIDE_SELF, t, steps)
	_log("空间守护：%s" % msg)
	action.emit("space_guard", {"steps": steps, "card": p.card})


func _egg_to_hand(reason: String) -> void :
	var repo:= CardRepo.load_json()
	var base: CardData = repo.get_card(EGG_CARD_ID)
	if base == null:
		_log("%s：找不到鸭蛋（9022）" % reason)
		return
	var egg:= CardData.from_dict(base.to_dict())
	# R299：手牌满 → 鸭蛋直接进弃牌区
	_grant_to_hand(egg, reason)
	_log("%s：一张「%s」加入手卡" % [reason, egg.card_name])
	action.emit("egg_token", {"card": egg})


func _mirror_reflect(side: String, played: CardData) -> void :


	if played == null:
		return
	if side == SIDE_SELF:
		var mr_copy := CardData.from_dict(played.to_dict())
		state.deck.append(mr_copy)
		_log("镜像：将一张「%s」加入本局卡组" % played.card_name)
		action.emit("deck_added", {"card": mr_copy, "side": side})
	else:
		state.opp_deck_count += 1
		_log("镜像（敌方）：本局卡组 +1 张「%s」" % played.card_name)


func _lone_walk_vanish(side: String) -> CardData:
	## 独行（9189，R406）：随机让**手卡**里一张盟友 / 工事**消失**（本场对战移除 ——
	## `void_count` / `void_cards`，与专注 9122 / 负重减轻 8066 / 新生 9148 同口径：
	## 既不回手牌也不进弃牌区），返回被抹掉的那张（调用方读它的生命 / 力量）。
	##
	## 手卡里没有盟友 / 工事 → 返回 null → 整段落空（这一下就只剩本卡的累积值）。
	## ⚠️ 本函数**只负责消失**，不加成也不结算 ——「含本次」的语义由调用方在伤害之前
	##    读返回值再并进卡里；两件事分开，测试才能分别钉住「抹了哪张」与「加了多少」。
	## ⚠️ 随机走引擎 rng（回放可复现）；敌方没有真实手牌 → 对称落空。
	if side != SIDE_SELF:
		return null
	var pool: Array[int] = []
	for i in state.hand.size():
		var c: CardData = state.hand[i]
		if c == null:
			continue
		if c.kind == "盟友" or c.kind == "工事":
			pool.append(i)
	if pool.is_empty():
		return null
	var pick: int = pool[rng.randi_range(0, pool.size() - 1)]
	var gone: CardData = state.hand[pick]
	state.hand.remove_at(pick)
	state.void_count += 1
	state.void_cards.append(gone)
	_log("独行：随机抹掉手卡「%s」（本场对战移除）" % gone.card_name)
	return gone


func _deterrence(side: String, amount: int) -> void :


	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == foe:
			cells.append(cell)
	if cells.is_empty():
		_log("威慑：敌方场上没有单位，未生效")
		return
	var t: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var q: Placement = state.unit_at(t)
	q.atk_debuff += amount
	# 威慑**立即生效**：debuff_stage 直接置 1 → 卡面 / 详情面板马上显示削弱后的力量。
	# 之后持续到该单位所属方的回合结束（= 你下个回合开始之前），由 end_turn 统一清除。
	q.debuff_stage = 1
	_log("威慑：%s 力量 -%d，持续到你下个回合开始（当前 %d）" % [
		q.card.card_name, amount, q.effective_power()])
	action.emit("deterrence", {"cell": t, "card": q.card, "amount": amount,
		"power": q.effective_power()})


func _crow_to_hand(side: String) -> void :


	if side != SIDE_SELF:
		_log("使魔之夜（敌方）：敌方 AI 不使用效果牌")
		return
	var repo:= CardRepo.load_json()
	var base: CardData = repo.get_card(CROW_ID)
	var crow:= CardData.from_dict(base.to_dict()) if base != null else _fallback_crow()
	# 当回合免费：不改卡本身的费用（那会永久变成 0 费），而是记进「本回合免费」名单，
	# 回合结束随 turn_free 一起清空 → 之后再抽到就是原本的 1 费。
	state.turn_free[crow] = true
	# R299：手牌满 → 乌鸦直接进弃牌区
	_grant_to_hand(crow, "使魔之夜")
	_log("使魔之夜：一张「%s」入手/进弃牌（本回合费用 0）" % crow.card_name)
	action.emit("crow_token", {"card": crow})


func _fallback_crow() -> CardData:
	var c:= CardData.new()
	c.id = CROW_ID
	c.card_name = "乌鸦"
	c.kind = "盟友"
	c.cost = 1
	c.power = 1
	c.health = 1
	c.attack_range = 1
	c.move_speed = 1
	return c


func _arcane_refund(side: String, amount: int) -> void :
	if amount <= 0:
		return
	if side == SIDE_SELF:
		state.energy += amount
	else:
		state.opp_energy += amount
	_log("奥秘精通：回复 %d 点费用（当前 %d）" % [amount, state.energy_of(side)])




func remote_play(card: CardData, cell: Vector2i) -> Placement:
	state.pay_energy(card.cost, SIDE_OPPONENT)
	state.opp_hand_count = maxi(0, state.opp_hand_count - 1)
	# 场地卡（R74）：对称 —— 敌方也能放场地（写进同一张表，同样顶掉旧场地），返回 null。
	# R78 补校验：原来这条路径**完全不看合法性**，敌方能往任何一行放。
	# 现在与玩家侧走同一个判定口（按**卡的生效对象**判，不是按谁在放）。
	# 注意 remote_play 没有 _pay_refund 可退（费用在函数开头已付），
	# 所以这里只「拒放 + 记日志 + _note_card_played」，不动别的结算。
	if card.is_field():
		# R88：写 trait「仅玩家可放置」的场地（维修间 8036 / 改造工厂 8037）**敌方摆不出来**。
		# 理由：它们只对**自己人**生效，敌方摆出来等于给自己人叠血 / 无限叠攻，
		# 玩家完全没牌可打 —— 属于纯单边的地板，不该出现在敌方卡组里。
		# 判据在卡面（不是引擎 id 白名单）→ 加新场地只要写 trait。
		if is_player_only_field(card):
			_log("对方放弃放置场地：%s 只能由玩家放置" % card.card_name)
			_note_card_played(SIDE_OPPONENT, card)
			return null
		var f_aim2 := field_aim(card)
		if not field_place_allowed(cell, f_aim2):
			_log("对方放弃放置场地：%s 是「%s」生效，目标方永远进不去 %s"
				% [card.card_name, f_aim2, cell])
			_note_card_played(SIDE_OPPONENT, card)
			return null
		state.set_field(card, cell, SIDE_OPPONENT)
		_log("对方放置场地：%s 于 %s" % [card.card_name, cell])
		action.emit("field_place", {"cell": cell, "card": card, "side": SIDE_OPPONENT,
			"replaced": false})
		_note_card_played(SIDE_OPPONENT, card)
		return null
	# R285：敌方同样不许站进我方后排（对称闸门）。费用在函数开头已付、没有退款，
	# 所以这里与「场地拒放」同口径：只记日志 + 记一次出牌，不做别的结算。
	if (card.kind == "盟友" or card.is_fort()) and not hand_place_allowed(cell, SIDE_OPPONENT):
		_log("对方放弃放置：%s 只能放到对方半场 %s" % [card.card_name, cell])
		_note_card_played(SIDE_OPPONENT, card)
		return null
	var p:= state.place(card, cell, SIDE_OPPONENT)
	_log("对方支付 %d 费用，%s 上场（%s）" % [card.cost, card.card_name, cell])
	action.emit("place", {"cell": cell, "card": card, "side": SIDE_OPPONENT})
	_note_card_played(SIDE_OPPONENT, card)
	return p


func remote_spell(card: CardData, target, side:= SIDE_OPPONENT) -> String:
	if card != null and card.x_cost:
		# R124：敌我同一口径 —— 0 费用也能施放，此时 X = 0（pay_energy(0) 分文不扣）。
		_x_spell_value = maxi(0, state.energy_of(side))
		state.pay_energy(state.energy_of(side), side)
	else:
		state.pay_energy(card.cost, side)
	state.opp_hand_count = maxi(0, state.opp_hand_count - 1)
	var times:= _charge_take(side)
	var detail:= ""
	for _ch_i in times:
		var _ch_d:= _run_spell_effect(card, target, side)
		detail = _ch_d if _ch_i == 0 else "%s；%s" % [detail, _ch_d]
	if times > 1:
		detail = "蓄力 ×%d → %s" % [times, detail]
	_log("对方使用法术 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_OPPONENT, card)
	return detail


func remote_curse(card: CardData, side:= SIDE_OPPONENT) -> void:
	## R223：对方打出诅咒（无效果）—— 镜像侧只做「扣费用 + 手牌数 -1 + 记一次出牌」，
	## 不进弃牌区（镜像侧不维护对方弃牌堆的具体内容，与 remote_spell 同口径）。
	if card == null:
		return
	state.pay_energy(card.cost, side)
	state.opp_hand_count = maxi(0, state.opp_hand_count - 1)
	_log("对方打出诅咒 %s（无效果）" % card.card_name)
	_note_card_played(side, card)


func _run_spell_effect(card: CardData, target, side:= SIDE_SELF) -> String:
	## R313：**技能伤害的作用域**。结算期间打开 `_spell_scope`，让 `_hit_unit()` 知道
	## 「这一笔是技能卡打出来的」（快速符文 6043 只认技能，不认效果 / 陷阱 / 反伤）。
	## ⚠️ GDScript 没有 finally → 把函数体整体挪进 `_body`，由这一层无条件收尾，
	##    否则任何一条 `return` 都会把作用域留在打开状态（后面所有伤害都被误算成技能）。
	_spell_scope_depth += 1
	var out_det:= _run_spell_effect_body(card, target, side)
	_spell_scope_depth -= 1
	return out_det


func _run_spell_effect_body(card: CardData, target, side:= SIDE_SELF) -> String:	match card.id:
		WISH_ID:
			# 许愿（9168，R306）：**从卡组**选一张卡加入手卡 —— 选卡页接管（`wish_pending`），
			# 结算口是 `wish_pick()`。卡组空了就白打（这张卡自己仍按「次元」进消耗区）。
			if state.deck.is_empty():
				_log("许愿：卡组是空的，愿望没有着落")
				return "卡组是空的，什么也没抽到"
			wish_pending = true
			_log("许愿：从卡组选择一张卡加入手卡（卡组 %d 张）" % state.deck.size())
			return "从卡组选一张卡加入手卡"
		FLAME_SWORD_ID:
			# 烈火之剑（9169，R306）：对**每一列最靠前的敌人**各造成 10 点伤害。
			# 「最靠前」= 该列里最靠近我方的那一行（行号最大）；空列跳过。
			# ⚠️ 行 = `cell.x`、列 = `cell.y`（见 battle_scene 的 `_cell_rect`）。
			var fs_dmg: int = _spell_dmg(side, FLAME_SWORD_DMG, card)
			var fs_n := 0
			for fs_col in FieldState.BOARD_COLS:
				var fs_best := Vector2i(-1, -1)
				for fs_row in FieldState.BOARD_ROWS:
					var fs_cell := Vector2i(fs_row, fs_col)
					var fs_u: Placement = state.unit_at(fs_cell)
					if fs_u == null or fs_u.owner == side:
						continue
					if fs_best.x < 0 or fs_row > fs_best.x:
						fs_best = fs_cell
				if fs_best.x >= 0:
					_op_deal_damage(side, fs_dmg, fs_best)
					fs_n += 1
			_log("烈火之剑：%d 列各受到 %d 点伤害" % [fs_n, fs_dmg])
			return "烈火之剑：%d 列各受到 %d 点伤害" % [fs_n, fs_dmg]
		INSTINCT_ID:
			# 本能（9176，R332）：随机打出抽牌库中 3 张费用 ≤1 的技能卡。
			return _instinct_cast(side)
		NIGHT_WALK_ID:
			# 夜行（9155，R232）：本回合我方所有卡免费；本回合出牌上限 NIGHT_WALK_MAX 张（含本卡）。
			state.turn_all_free = true
			state.card_play_cap = NIGHT_WALK_MAX
			var nw_left: int = maxi(0, NIGHT_WALK_MAX - state.self_card_plays - 1)
			_log("夜行：本回合所有卡费用为 0；最多还能再使用 %d 张卡" % nw_left)
			return "本回合全部免费（还能再用 %d 张卡）" % nw_left
		CHARGE_UP_ID:
			# 蓄势（9156，R232）：对目标造成此卡当前伤害（value 随剩余费用成长）。
			return str(_op_deal_damage(side, _spell_dmg(side, card.value, card), target))
		SLAY_ID:
			# 猎杀（9205，R393，暗影刺客史诗技能 · 次元）：
			# 基础伤害 = card.value（卡面 25；本局永久成长会把它抬高）。
			# 击杀判据必须在伤害结算**之前**抓目标格子：目标被破坏后拿不到 cell。
			# 只在「目标原本是敌方单位，且结算后那个格子空了」时算击杀 ——
			# 单纯打到 0 血但被「超负荷」留住的敌人不算。
			var hunt_p: Placement = _target_placement(side, target)
			var hunt_cell := Vector2i(-1, -1)
			var hunt_enemy := false
			if hunt_p != null:
				hunt_cell = _cell_of(hunt_p)
				hunt_enemy = hunt_p.owner != side
			var hunt_out := _op_deal_damage(side, _spell_dmg(side, card.value, card), target)
			if hunt_enemy and hunt_cell.x >= 0 and state.unit_at(hunt_cell) == null:
				_spell_kill_damage_growth(card)
			return hunt_out
		8002:
			return str(_op_deal_damage(side, _spell_dmg(side, 4, card), target))
		LULLABY_ID:
			# 摇篮曲（9182，R352，全职业公用 5 费史诗技能 · 次元）：
			#   **所有单位**（不分敌我）1 回合不能行动。
			# ⚠️ 「1 回合」对两个阵营是**两种不同的挡法**，不能一律 `_apply_stun`：
			#   * 非施放方（敌方）→ `_apply_stun` 正好挡住**即将到来的**那个敌方回合；
			#   * 施放方（我方）再分两种（R352 用户口径）：
			#     ① 本回合**还没动** → 就地横置，当场交出这一回合的行动权；
			#     ② 本回合**已经动过** → 横置没有意义（本来就没行动权了），
			#        所以改成 `_apply_stun` —— **下个我方回合不能动**，
			#        这样每个单位恰好少一回合，不会因为「已经动过」而免费。
			#     判据为何要排除 frozen / stun_left / sleep_left：那三种情况下 `tapped`
			#     是「被状态挡住」而不是「已经动过」，再叠一层眩晕 = 白扣一回合。
			var lull_n := 0
			var lull_self := 0
			var lull_used_n := 0
			for lull_cell: Vector2i in state.board.keys():
				var lull_p: Placement = state.unit_at(lull_cell)
				if lull_p == null or lull_p.health <= 0:
					continue
				if lull_p.owner == side:
					var lull_used: bool = lull_p.tapped and not lull_p.frozen \
							and lull_p.stun_left <= 0 and lull_p.sleep_left <= 0
					if lull_used:
						_apply_stun(lull_p, "摇篮曲")
						lull_used_n += 1
					elif not lull_p.tapped:
						lull_p.tapped = true
						lull_p.moved = true
						action.emit("tap", {"cell": lull_cell, "card": lull_p.card})
						_log("摇篮曲：%s 就地横置（本回合不能再行动）" % lull_p.card.card_name)
					lull_self += 1
				else:
					_apply_stun(lull_p, "摇篮曲")
				lull_n += 1
			if lull_n == 0:
				_log("摇篮曲：场上没有任何单位，效果落空")
				return "场上没有单位，什么也没发生"
			if lull_used_n > 0:
				_log("摇篮曲：我方 %d 个已经行动过的单位 → 下个我方回合不能行动" % lull_used_n)
			_log("摇篮曲：%d 个单位 1 回合不能行动（其中我方 %d 个）" % [lull_n, lull_self])
			return "%d 个单位 1 回合不能行动（不分敌我）" % lull_n
		FOREST_FRIENDS_ID:
			# 森林的朋友们（9183，R352，全职业公用 0 费稀有技能 · 次元）：
			#   把一张随机**森林精魄**盟友加入手卡，那张卡**本回合**费用 -2。
			# * 随机源走引擎 rng → 同种子同结果、回放可复现（与生命循环 9150 同口径）。
			# * 减费走 `state.hand_cost_turn`（本回合专用表，`end_turn` 清空）；
			#   判据是「这张卡此刻还在手牌里」，离手自动恢复原价，不必逐处清标记。
			# * 手牌满 → 走 `_grant_to_hand` 的通用口径（进弃牌区，不蒸发）。
			var ff_c := _random_forest_ally()
			if ff_c == null:
				_log("森林的朋友们：卡池里没有森林精魄盟友卡")
				return "卡池里没有森林精魄盟友，效果落空"
			var ff_copy := CardData.from_dict(ff_c.to_dict())
			ff_copy.affixes = (ff_c.affixes as Array).duplicate()
			if not _grant_to_hand(ff_copy, "森林的朋友们"):
				_log("森林的朋友们：手牌已满 → 「%s」直接进弃牌区" % ff_copy.card_name)
				return "手牌已满，「%s」进了弃牌区" % ff_copy.card_name
			state.hand_cost_turn[ff_copy] = int(state.hand_cost_turn.get(ff_copy, 0)) \
					+ FOREST_FRIENDS_DISCOUNT
			_log("森林的朋友们：手卡加入「%s」，其本回合费用 -%d"
					% [ff_copy.card_name, FOREST_FRIENDS_DISCOUNT])
			return "「%s」加入手卡，其本回合费用 -%d" % [ff_copy.card_name,
					FOREST_FRIENDS_DISCOUNT]
		EMERGENCY_POWER_ID:
			# 应急电源（9170，R315，机械之心 0 费史诗技能 · 次元）：
			#   +1 费 → 抽 1 张 → 场上**所有友方单位**各回复 2 点生命（不超过各自最大生命）。
			# * 加费直接 `state.energy +=`（与拆解 8049 同口径：不污染 self_energy_spent，
			#   当回合可超额）；界面靠费用变化的逐帧差值自动飘字。
			# * 回血逐格发 `heal` 动作 → 战斗场景走既有的治疗表现，不新造一套。
			# * 「友方单位」= 该 side 场上的盟友 / 工事（`_side_cells` 只给有单位的格子）。
			state.energy += EMERGENCY_POWER_ENERGY
			var ep_drawn := _draw_many(EMERGENCY_POWER_DRAW)
			var ep_n := 0
			var ep_total := 0
			for ep_cell: Vector2i in _side_cells(side):
				var ep_p: Placement = state.unit_at(ep_cell)
				if ep_p == null or ep_p.owner != side:
					continue
				var ep_before: int = ep_p.health
				ep_p.health = mini(ep_p.card.health,
						ep_p.health + EMERGENCY_POWER_HEAL)
				var ep_gain: int = ep_p.health - ep_before
				ep_n += 1
				if ep_gain > 0:
					ep_total += ep_gain
					action.emit("heal", {"cell": ep_cell, "card": ep_p.card,
							"amount": ep_gain, "health": ep_p.health, "side": side})
			_log("应急电源：+%d 费，抽 %d 张，%d 个友方单位各回复 %d（共 %d）"
					% [EMERGENCY_POWER_ENERGY, ep_drawn, ep_n,
							EMERGENCY_POWER_HEAL, ep_total])
			return "获得 %d 点费用，抽 %d 张卡，%d 个友方单位各回复 %d 点生命" \
					% [EMERGENCY_POWER_ENERGY, ep_drawn, ep_n, EMERGENCY_POWER_HEAL]
		RAPID_ID:
			# 极速（9171，R316，暗影刺客 1 费稀有技能）：
			#   抽 2 张 → 抽到的牌里每有一张「0 费」，本回合所有敌人受到伤害 +1。
			# ⚠️ 「0 费」按**当前费用**算（`cost_of`）：本回合减费 / 免费把它压到 0 也算 ——
			#    玩家看的是手牌上那个数字，不是卡库里的原始费用。
			# ⚠️ 只数**真进手牌**的：手牌满时抽到的牌会直接进弃牌区（`hand_burn`），
			#    那张不算「抽到手里」，与 `_draw_many` 的返回口径一致。
			var rp_before: int = state.hand.size()
			var rp_got := _draw_many(RAPID_DRAW)
			var rp_zero := 0
			for rp_i in range(rp_before, state.hand.size()):
				if cost_of(state.hand[rp_i]) <= 0:
					rp_zero += 1
			if rp_zero > 0:
				_rapid_enemy_bonus += rp_zero * RAPID_PER_ZERO
				_log("极速：抽 %d 张，其中 %d 张 0 费 → 本回合所有敌人受到伤害 +%d（累计 +%d）"
						% [rp_got, rp_zero, rp_zero * RAPID_PER_ZERO, _rapid_enemy_bonus])
			else:
				_log("极速：抽 %d 张，没有 0 费卡 → 敌人易伤不增加（当前 +%d）"
						% [rp_got, _rapid_enemy_bonus])
			action.emit("rapid", {"drawn": rp_got, "zero": rp_zero,
					"bonus": _rapid_enemy_bonus, "side": side})
			return "抽 %d 张（0 费 %d 张），本回合敌人受到伤害 +%d" \
					% [rp_got, rp_zero, _rapid_enemy_bonus]
		LASER_SWEEP_ID:
			# 激光扫射（9172，R316，机械之心 2 费稀有技能）：对所有敌人造成 9 点伤害。
			# 与激发 8077 / 风妖精 6042 同口径：逐格走 `_hit_unit`（护盾 / 减伤 / 光环照常），
			# 致死统一交 `_destroy_dead()`；格子先排序，回放 / 同种子必须逐帧一致。
			# 只打**场上的敌方单位**，不直击敌方 HP（没有单位时效果落空）。
			var ls_dmg: int = _spell_dmg(side, LASER_SWEEP_DMG, card)
			var ls_cells: Array[Vector2i] = []
			for ls_cell: Vector2i in state.board:
				var ls_u: Placement = state.board[ls_cell]
				if ls_u != null and ls_u.owner != side:
					ls_cells.append(ls_cell)
			if ls_cells.is_empty():
				_log("激光扫射：场上没有敌方单位，效果落空")
				return "场上没有敌人"
			ls_cells.sort()
			var ls_hits := 0
			for ls_c2: Vector2i in ls_cells:
				var ls_q: Placement = state.board.get(ls_c2, null)
				if ls_q == null or ls_q.health <= 0:
					continue
				_hit_unit(ls_q, ls_dmg, "激光扫射")
				ls_hits += 1
			_destroy_dead()
			_log("激光扫射：对所有敌人造成 %d 点伤害（%d 个目标）" % [ls_dmg, ls_hits])
			return "对所有敌人造成 %d 点伤害（%d 个目标）" % [ls_dmg, ls_hits]
		REFLEX_ID:
			# 身法（9173，R317，暗影刺客 1 费普通技能）：
			#   抽 5 张 → **这回合结束为止不能使用盟友和工事卡**。
			# ⚠️ 锁只到本回合：`end_turn` 清（与本回合其它一次性 buff 同组）。
			# ⚠️ 已经打出的单位不受影响，也不能再被打出 —— 只拦「继续铺场」。
			var rf_drawn := _draw_many(REFLEX_DRAW)
			_no_unit_play_this_turn = true
			_log("身法：抽 %d 张；本回合不能再使用盟友和工事卡" % rf_drawn)
			action.emit("reflex", {"drawn": rf_drawn, "side": side})
			return "抽 %d 张；本回合不能使用盟友和工事卡" % rf_drawn
		ELIMINATE_ID:
			# 淘汰（9174，R317，机械之心 1 费史诗技能）：
			#   抽 4 张 → 从卡组选一张盟友 / 工事变成「素体」（面板接管）。
			# ⚠️ 敌方 AI 不用这张（改玩家牌组是玩家侧决策，与专注 9122 / 负重减轻同口径）：
			#    它只结算抽牌，不开面板。
			var el_drawn := _draw_many(ELIMINATE_DRAW)
			if side != SIDE_SELF:
				return "抽 %d 张" % el_drawn
			var el_opts := eliminate_options()
			if el_opts.is_empty():
				_log("淘汰：卡组里没有盟友或工事，效果落空")
				return "抽 %d 张；卡组里没有盟友或工事" % el_drawn
			eliminate_pending = true
			_log("淘汰：抽 %d 张 → 从卡组选一张盟友或工事（共 %d 张可选）"
					% [el_drawn, el_opts.size()])
			action.emit("eliminate_pending", {"count": el_opts.size(), "drawn": el_drawn})
			return "抽 %d 张；从卡组选一张盟友或工事变成素体" % el_drawn
		INVENTORY_ID:
			# 库存整理（9184，R370，机械之心 1 费史诗技能）：
			#   从卡组随机两张 → 各原位换成一张随机卡，直接结算、不开任何面板。
			return _inventory_sort(side)
		UPGRADE_ID:
			# 升级 8027（R82，机械之心）：改造一个己方盟友或工事。
			# 走 _run_spell_effect 而不是 use_spell 的分支 → 蓄力（9085）叠它会叠多次，
			# 与「连刺 / 火焰箭」等普通技能同一口径。
			return _upgrade_unit(target, side)
		ARMOR_PLATE_ID:
			# 加厚装甲 8044（R95，机械之心）：改造一个己方**盟友** → +4 生命（算一层改造）。
			return _armor_plate(target, side)
		SHARED_SHIELD_ID:
			# 共享护盾 8069（R269，机械之心）：己方盟友挂字段「共享护盾」+ 一层改造。
			return _shared_shield(target, side)
		OVERLOAD_ID:
			# 过载 8030（R85，机械之心）：从牌库随机一张盟友改成双动。无目标、不可选。
			return _overload_grant(side)
		PROD_ORDER_ID:
			# 生产订单 8048（R96，机械之心）：往抽牌堆加两张改造过的「素体」。无目标、不可选。
			return _production_order(side)
		DEMOLISH_ID:
			# 拆解 8049（R97，机械之心）：破坏自己一个己方盟友/工事，回 3 费，手牌+素体；
			# 被改造则额外手牌+升级。需要 target（棋盘单位格）。
			return _demolish(target, side)
		REORG_ID:
			# 重组 8051（R99，机械之心）：回复一个己方盟友/工事至满生命。
			return _reorganize(target, side)
		TRANSCEND_ID:
			# 超越极限 8053（R99，机械之心）：给一个己方盟友/工事挂超负荷 + 算一层改造。
			return _transcend(target, side)
		REBOOT_ID:
			# 重启 8054（R100，机械之心）：将己方一个盟友/工事返回手卡（0 费，离手重置）。
			return _reboot(target, side)
		ENERGY_CANNON_ID:
			# 聚能炮击 9145（R202，机械之心）：造成 ENERGY_CANNON_DMG 点伤害并抽 1 张。
			# R341 量产型谟涅摩叙涅 8075：**每回合一次** → 这一发伤害 +MASS_MNEMOSYNE_DMG。
			# 顺序：**先判额度（顺带把额度用掉）→ 再算伤害 → 再抽牌**。额度只在这里扣一次。
			var ec_bonus:= _mass_mnemosyne_cannon_bonus(side)
			var ec_dmg:= _op_deal_damage(side, _spell_dmg(side, ENERGY_CANNON_DMG + ec_bonus, card), target)
			# R271 量产型谟涅摩叙涅 8075：**因这张卡自身效果抽到的那张卡**费用 -1。
			# 抽牌后手牌末尾就是刚抽到的那张（手牌满时 _draw_many 不抽，长度不变 → 不结算）。
			# R341：减费与伤害加成共用额度 → 只认 `ec_bonus > 0` 的那一发。
			var ec_before:= state.hand.size()
			var ec_draw:= _draw_many(1)
			if ec_bonus > 0 and state.hand.size() > ec_before:
				_cannon_draw_discount(side, state.hand[state.hand.size() - 1])
			return "%s；抽 %d 张" % [ec_dmg, ec_draw]
		BREAKTHROUGH_ID:
			# 集中突破 9162（R290，机械之心）：造成 BREAKTHROUGH_DMG 点伤害，
			# 场上己方单位每有 1 层改造，伤害 +BREAKTHROUGH_PER_STACK。
			# 加成并进 **base** 再走 `_spell_dmg()` —— 附魔 / 魔法塔 / 荧光草 / 鸭之眼
			# 照常作用在「含改造加成」的总伤害上（与蓄势读 card.value 同一口径）。
			var bt_stacks:= _side_upgrade_stacks(side)
			var bt_base:= BREAKTHROUGH_DMG + bt_stacks * BREAKTHROUGH_PER_STACK
			if bt_stacks > 0:
				_log("集中突破：场上己方改造 ×%d → 伤害 %d + %d = %d" % [
					bt_stacks, BREAKTHROUGH_DMG,
					bt_stacks * BREAKTHROUGH_PER_STACK, bt_base])
			return str(_op_deal_damage(side, _spell_dmg(side, bt_base, card), target))
		IMPACT_CANNON_ID:
			# 冲击炮 9163（R290，机械之心）：造成 IMPACT_CANNON_DMG 点伤害，
			# 并把目标击退 IMPACT_CANNON_STEPS 格。
			# 顺序 = 先伤害再击退：目标被这一发打死后 `_target_placement()` 已经是 null，
			# 自然跳过击退（不会对着空格推）。
			# 击退走唯一口 `_knockback()`：位移免疫（赫菲斯托斯）/ 被己方单位挡住 /
			# 朝目标所属方后排 —— 三条规则与清退陷阱 / 暗影锁链完全同源。
			var ic_msg:= _op_deal_damage(side, _spell_dmg(side, IMPACT_CANNON_DMG, card), target)
			if _target_placement(side, target) == null:
				return "%s；目标被击破" % ic_msg
			_log("冲击炮：%s，随后击退 %d 格" % [ic_msg, IMPACT_CANNON_STEPS])
			return "%s；%s" % [ic_msg, _knockback(side, target, IMPACT_CANNON_STEPS)]
		BLADE_GIFT_ID:
			# 辅助刃 9164（R291，机械之心）：己方盟友获得改造（力 +2）+「死亡」亡语回收自己。
			return _blade_gift(target, side)
		DUPLICATE_ID:
			# 复制术 9165（R291，机械之心）：复制己方一个盟友 / 工事两份到手卡（带「次元」，本回合 0 费）。
			return _duplicate_spell(target, side)
		MERGE_ID:
			# 合体 9167（R298，机械之心）：素体消失 → 目标获得改造（+素体的力量 / 生命）。
			# 面板路径的素体已由 `merge_pick()` 抹掉并记在 merge_body_* 上；
			# 失控要塞 9161 凭空释放 / 蓄力叠第二次时没有预取 → 按卡组顺序自动再取一张。
			return _merge_spell(target, side)
		SCRAP_ID:
			# 报废 8071（R271，机械之心）：手牌里其他所有卡变成聚能炮击（本回合 0 费）。
			return _scrap_hand(side)
		ASSEMBLE_ID:
			# 随心组装 9144（R202，机械之心）：手牌里所有卡变成随机奖励卡。
			return _assemble_at_will(side)
		LIFE_CYCLE_ID:
			# 生命循环 9150（R227，森林精魄）：己方盟友获得「次元」+「死亡」。
			return _life_cycle(target, side)
		BATCH_UPGRADE_ID:
			# 集体改造 8031（R86 → R394）：手牌 + 卡组里所有盟友 / 工事 +3 生命。
			return _batch_upgrade(side)
		BATCH_TRANSFER_ID:
			# 批量传输 8040（R90，机械之心）：手牌里所有盟友 / 工事 +1 费 / +3 力 / +6 血
			# （烤进副本、本场战斗永久），**然后抽 1 张**。无目标、不可选。
			# ⚠️ 走 `_run_spell_effect` → 蓄力（9085）叠它会叠多次（抽多张牌），
			# 与「集体改造」等普通技能同一口径。
			return _batch_transfer(side)
		BARRIER_ID:
			# 能量屏障 8033（R87）：从抽牌堆随机改造一张还没护盾的盟友 / 工事。无目标。
			return _energy_barrier(side)
		SELF_REPAIR_ID:
			# 自我修复 8035（R87）：改造场上一个己方盟友 → +2 最大生命 + 每回合回 4。
			return _self_repair(target, side)
		9003:
			return str(_op_deal_damage(side, _spell_dmg(side, 17, card), target))
		9004:
			return _knockback(side, target, 2)
		9005:
			if side == SIDE_SELF:
				return "抽了 %d 张牌" % _draw_many(2)
			var m:= 0
			for i in 2:
				if state.opp_deck_count > 0:
					state.opp_draw(1)
					state.opp_deck_count -= 1
					m += 1
			return "对方抽了 %d 张牌" % m
		9006:
			return _chain_lightning(_spell_dmg(side, 11, card))
		FIREBALL_ID:
			return _blast(_spell_dmg(side, 20, card), target, 1)
		9010:
			var wp:= _target_placement(side, target)
			if wp == null:
				return "（没有目标）"
			wp.atk_debuff += 9
			# R143：与威慑 / 敲晕 / 幻影斗篷 / 回响 / 黑暗陷阱同源 —— **当场生效**（stage=1）。
			# 卡面 / 详情面板立刻显示削弱后的力量，持续到该单位所属方的回合结束
			# （= 我下个回合开始之前恢复）。此前这里留空 debuff_stage、交给
			# `_arm_debuffs` 在**对方回合开始**才置 1 → 玩家「这回合用了当场看不见」。
			wp.debuff_stage = 1
			_log("%s 被削弱：力量 -9（持续到你下个回合开始）" % wp.card.card_name)
			return "%s 攻击力 -9" % wp.card.card_name
		9011:
			var fp:= _target_placement(side, target)
			if fp == null:
				return "（没有目标）"
			if fp.card.traits.has(SPELL_IMMUNE_TRAIT):
				return "%s 免疫法术" % fp.card.card_name
			var dealt:= _hit_unit(fp, _spell_dmg(side, 3, card), "寒冰箭")
			if fp.health <= 0:
				_destroy_dead()
				return "%s 冰碎（-%d）" % [fp.card.card_name, dealt]
			_apply_frozen(fp, "寒冰箭")
			return "%s -%d 且被冰封" % [fp.card.card_name, dealt]
		2001, 7201, 7501:
			return str(_op_deal_damage(side, _spell_dmg(side, 3, card), target))
		2002, 7202:
			return str(_op_heal(side, 4, target))
		2003:
			if side == SIDE_SELF:
				return "抽了 %d 张牌" % _draw_many(2)
			var m2:= 0
			for i in 2:
				if state.opp_deck_count > 0:
					state.opp_draw(1)
					state.opp_deck_count -= 1
					m2 += 1
			return "对方抽了 %d 张牌" % m2
		2004:
			return str(_op_deal_damage(side, _spell_dmg(side, 2, card), null))
		9035:
			return str(_op_deal_damage(side, _spell_dmg(side, COORD_ATTACK_DMG, card), target))
		9037:
			return _forest_guard(side, target)
		9041:
			return _quick_strike(side)
		9042:
			return _bite(side, target)
		9043:
			return _ice_wall(side, target)
		9050:
			return _whale_wrath(side, target, card)
		9051:
			return _nature_force(side)
		9053:
			return _tenacity(side)
		9054:
			return _dragon_breath_spell(side, target, card)
		9055:
			return _frenzy(side, target)
		9060:
			return _aether_barrier(side)
		9071:
			return _iron_fence(side, target)
		CHARGE_SPELL_ID:
			return _charge_spell(side)
		METEOR_SHOWER_ID:
			return _meteor_shower(side, card)
		RAID_SPELL_ID:
			return str(_op_deal_damage(side, _spell_dmg(side, _raid_dmg(side), card),
					target))
		FIRE_WALL_SPELL_ID:
			return _fire_wall_spell(side, target, card)
		METEOR_ID:
			return _meteor(side, target, card)
		REVIVE_ID:
			return _revive_spell(side)
		OVERHAUL_ID:
			return _overhaul_spell(side)
		GOLEM_SPELL_ID:
			return _golem_spell(side, target)
		GOUGE_ID:
			var gg_s := str(_op_deal_damage(side, _spell_dmg(side, GOUGE_DMG, card), target))
			if side == SIDE_SELF:
				var gg_c := _fetch_skill_from_deck(1)
				gg_s += "；连刺：%s" % (("卡组 0 费技能卡「%s」加入手卡" % gg_c.card_name) if gg_c != null else "卡组里没有 0 费技能卡")
			return gg_s
		BOUNCE_KNIFE_ID:
			return _bounce_knife(side, target, card)
		STUN_BLOW_ID:
			var st_p := _target_placement(side, target)
			if st_p == null:
				return "（没有目标）"
			if st_p.card.traits.has(SPELL_IMMUNE_TRAIT):
				return "%s 免疫法术" % st_p.card.card_name
			var st_d := _hit_unit(st_p, _spell_dmg(side, STUN_BLOW_DMG, card), "敲晕")
			var st_s := "%s -%d" % [st_p.card.card_name, st_d]
			if st_p.health > 0:
				st_p.atk_debuff += STUN_BLOW_DEBUFF
				st_p.debuff_stage = 1
				st_s += "，力量 -%d" % STUN_BLOW_DEBUFF
				_log("敲晕：%s 力量 -%d（当前 %d），持续到它的回合结束" % [
						st_p.card.card_name, STUN_BLOW_DEBUFF, st_p.effective_power()])
				action.emit("stun_blow", {"cell": _cell_of(st_p), "card": st_p.card,
						"amount": STUN_BLOW_DEBUFF, "power": st_p.effective_power()})
			_destroy_dead()
			return st_s
		LONE_WALK_ID:
			# 独行（9189，R406）：7 伤 + 本回合力量 -1，并把「随机消失的手卡」永久并进来。
			# ⚠️ 顺序是硬约束：**先消失、再打伤害** —— 用户口径「含本次」= 这一下就要
			#    吃到刚消失那张卡的生命 / 力量，否则第一次永远是白板 7 伤。
			var lw_p: Placement = _target_placement(side, target)
			if lw_p == null:
				return "（没有目标）"
			if lw_p.card.traits.has(SPELL_IMMUNE_TRAIT):
				return "%s 免疫法术" % lw_p.card.card_name
			var lw_gone: CardData = _lone_walk_vanish(side)
			if lw_gone != null:
				# 生命 / 力量读的是**卡面当前值**（含改造 / 附魔烤进去的数值）——
				# 与卡面显示一致，不做任何减免换算。
				card.lone_dmg_bonus += maxi(0, lw_gone.health)
				card.lone_str_bonus += maxi(0, lw_gone.power)
				_log("独行：手卡「%s」并入本卡 → 伤害 +%d、降力 +%d（累计 %d / %d）" % [
						lw_gone.card_name, lw_gone.health, lw_gone.power,
						card.lone_dmg_bonus, card.lone_str_bonus])
			else:
				_log("独行：手卡里没有盟友或工事 → 本次不消失任何卡（只按累积值结算）")
			var lw_dmg: int = _hit_unit(lw_p, _spell_dmg(side,
					LONE_WALK_DMG + card.lone_dmg_bonus, card), "独行")
			var lw_s := "%s -%d" % [lw_p.card.card_name, lw_dmg]
			if lw_p.health > 0:
				# 降力与敲晕 / 威慑同源：atk_debuff + debuff_stage=1（立即生效，
				# 该单位所属方回合结束时清除）。「永久」只针对**这张卡降多少**。
				var lw_n: int = LONE_WALK_DEBUFF + card.lone_str_bonus
				lw_p.atk_debuff += lw_n
				lw_p.debuff_stage = 1
				lw_s += "，力量 -%d" % lw_n
				_log("独行：%s 力量 -%d（当前 %d），持续到它的回合结束" % [
						lw_p.card.card_name, lw_n, lw_p.effective_power()])
				action.emit("stun_blow", {"cell": _cell_of(lw_p), "card": lw_p.card,
						"amount": lw_n, "power": lw_p.effective_power()})
			_destroy_dead()
			if lw_gone != null:
				lw_s += "；手卡「%s」消失" % lw_gone.card_name
			return lw_s
		SPIN_DRAW_ID:
			if side != SIDE_SELF:
				return "（回转：敌方 AI 不使用这张卡）"
			var sp_n := state.self_card_plays
			var sp_got := 0
			for sp_i in sp_n:
				var sp_c: CardData = state.draw()
				if sp_c == null:
					break
				if not state.turn_keep.has(sp_c):
					state.turn_keep.append(sp_c)
				sp_got += 1
			_log("回转：本回合已用 %d 张 → 抽 %d 张（本回合结束不丢弃）" % [sp_n, sp_got])
			return "抽了 %d 张牌（本回合不丢弃）" % sp_got
		SNEAK_ID:
			var sn_p := _target_placement(side, target)
			if sn_p == null:
				return str(_op_deal_damage(side, _spell_dmg(side, SNEAK_DMG, card), null))
			var sn_base := SNEAK_FULL_DMG if sn_p.health >= sn_p.card.health else SNEAK_DMG
			if sn_base == SNEAK_FULL_DMG:
				_log("偷袭：%s 处于满血 → 改为 %d 点伤害" % [sn_p.card.card_name, SNEAK_FULL_DMG])
			return str(_op_deal_damage(side, _spell_dmg(side, sn_base, card), target))
		COMBO_TRICK_ID:
			var ct_plays := state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
			var ct_full := ct_plays + 1 >= COMBO_TRICK_NEED
			var ct_base := COMBO_TRICK_FULL_DMG if ct_full else COMBO_TRICK_DMG
			var ct_s := str(_op_deal_damage(side, _spell_dmg(side, ct_base, card), target))
			if ct_full:
				_log("连环戏法：含此卡本回合第 %d 张 → 改为 %d 点伤害" % [ct_plays + 1, COMBO_TRICK_FULL_DMG])
				if side == SIDE_SELF and state.draw() != null:
					ct_s += "；抽 1 张"
			return ct_s
		OPENING_MOVE_ID:
			# 起手式 9119（R104）：1 费，对目标 4 伤 → **抽 1 张**（玩家侧才抽）。
			var om_s := str(_op_deal_damage(side, _spell_dmg(side, OPENING_MOVE_DMG, card),
					target))
			if side != SIDE_SELF:
				return om_s
			var om_got := _draw_many(OPENING_MOVE_DRAW)
			_log("起手式：结算后抽 %d 张卡" % om_got)
			return om_s + ("；抽 %d 张" % om_got)

		SHADOW_STRIKE_ID:
			# 影袭 9120（R108）：1 费稀有；对目标 8 伤 → 若**含本卡**本回合已用满 3 张，回 1 费。
			# self_card_plays 在 _note_card_played 里累加，但**结算发生在记卡之前**，
			# 所以这里 +1 才是「含本卡」的最终张数（与连环戏法 9093 同源口径）。
			var ss_plays := state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
			var ss_cards := ss_plays + 1
			var ss_s := str(_op_deal_damage(side, _spell_dmg(side, SHADOW_STRIKE_DMG, card), target))
			if ss_cards >= SHADOW_STRIKE_NEED:
				if side == SIDE_SELF:
					state.energy += SHADOW_STRIKE_REFUND
					_log("影袭：含本卡本回合第 %d 张 → 回复 %d 点费用（当前 %d）" % [
							ss_cards, SHADOW_STRIKE_REFUND, state.energy_of(side)])
					ss_s += "；回复 %d 点费用" % SHADOW_STRIKE_REFUND
				else:
					state.opp_energy += SHADOW_STRIKE_REFUND
					ss_s += "；回复 %d 点费用" % SHADOW_STRIKE_REFUND
			else:
				_log("影袭：含本卡本回合第 %d 张（未满 %d 张）→ 不回费" % [
						ss_cards, SHADOW_STRIKE_NEED])
			return ss_s
		SHADOW_STEP_ID:
			# 暗影步 9121（R108）：2 费稀有；先对目标 8 伤 → 再从弃牌区任选一张回手卡。
			# 取牌是**玩家侧收益** → 敌方 AI 只结算伤害（与起手式 9119 同口径）。
			var sh_s := str(_op_deal_damage(side, _spell_dmg(side, SHADOW_STEP_DMG, card), target))
			if side != SIDE_SELF:
				return sh_s
			return sh_s + "；" + _shadow_step_spell(side)

		FOCUS_ID:
			# 专注 9122（R109）：0 费稀有；从抽牌库移除 2 张卡（本场消失，不抽牌）。
			return _focus_spell(side)
		LIGHTEN_ID:
			# 负重减轻 8066（R201）：0 费史诗；从抽牌库移除 1 张卡（本场消失），
			# 并且下个回合开始时多抽 1 张卡。
			return _lighten_spell(side)
		PREPARE_ID:
			if side != SIDE_SELF:
				var pp_m := 0
				for pp_i in 2:
					if state.opp_deck_count > 0:
						state.opp_draw(1)
						state.opp_deck_count -= 1
						pp_m += 1
				return "对方抽了 %d 张牌" % pp_m
			var pp_cards: Array[CardData] = []
			for pp_i2 in 2:
				var pp_c: CardData = state.draw()
				if pp_c != null:
					pp_cards.append(pp_c)
			var pp_extra := false
			var pp_zero := 0
			for pp_c2 in pp_cards:
				if pp_c2.cost == 0:
					pp_zero += 1
					pp_extra = true
			var pp_n := pp_cards.size()
			if pp_extra and state.draw() != null:
				pp_n += 1
			_log("准备：抽 %d 张（0 费 %d 张）%s" % [pp_n, pp_zero,
					"→ 再抽 1 张" if pp_extra else ""])
			return "抽了 %d 张牌" % pp_n
		TORRENT_ID:
			var tr_s := str(_op_deal_damage(side, _spell_dmg(side, TORRENT_DMG, card), target))
			if side == SIDE_SELF:
				var tr_moved := 0
				for tr_i in range(state.discard.size() - 1, -1, -1):
					if state.hand_full():
						break
					var tr_c: CardData = state.discard[tr_i]
					if tr_c.cost == 0:
						state.discard.remove_at(tr_i)
						state.hand.append(tr_c)
						tr_moved += 1
				_log("怒涛：%d 张 0 费卡从弃牌区回到手卡" % tr_moved)
				tr_s += "；回收 %d 张 0 费卡" % tr_moved
			return tr_s
		WHIRL_BLADE_ID:
			return _whirl_blade(side, target, card)
		FORESIGHT_ID:
			if side != SIDE_SELF:
				return "（预判：敌方 AI 不使用这张卡）"
			foresight_mode = true
			_log("预判：选择一个效果（面板二选一）")
			return "选择一个效果"
		FATE_REJECT_ID:
			return _fate_reject(side)
		INFILTRATE_ID:
			# 玩家侧已在 use_spell 入口拦掉（付费之前）；走到这里的只可能是敌方 AI，
			# 它没有「选目的格」的概念，用自动落点（己方半场第一个空格）。
			var if_p := _target_placement(side, target)
			if if_p == null:
				return "（潜入：需要指定一个自己的盟友）"
			return _infiltrate_cast(side, _cell_of(if_p), _infiltrate_auto_cell(side), card)
		SWAP_UNITS_ID:
			# 玩家侧已在 use_spell 入口拦掉（付费之前）；走到这里的只可能是敌方 AI / 自动出牌，
			# 没有「玩家点了哪两个格」的概念 → 自己挑一对（见 _swap_auto_cells）。
			var sw := _swap_auto_cells(side)
			if sw.size() < 2:
				return "（双向传送：场上不足两个单位）"
			return _swap_two_units(sw[0], sw[1])
		ECHO_ID:
			return _echo_spell(side, card)
		DODGE_ID:
			return _dodge_spell(side)
		ALERT_ID:
			return _alertness(side)
		HUNT_ID:
			# 暗影狩猎（9107；R74 口径改为「场地」）：16 伤；目标「上回合触发过场地」→ 30 伤。
			# 判据仍是 trap_trig_turn 与当前全局半回合号差 1（隔回合失效）；
			# 场地触发与机关工坊被破坏都会记这个号，所以两者都吃这 30 伤。
			var hu_p := _target_placement(side, target)
			if hu_p == null:
				return "（暗影狩猎：需要指定一个目标）"
			if hu_p.owner == side:
				return "（暗影狩猎：只能指定敌人）"
			var hunt_big := hu_p.trap_trig_turn >= 0 and turn_total - hu_p.trap_trig_turn == 1
			var hu_dmg := _spell_dmg(side, HUNT_BIG_DMG if hunt_big else HUNT_DMG, card)
			var hu_s := str(_op_deal_damage(side, hu_dmg, target))
			if hunt_big:
				_log("暗影狩猎：%s 上回合触发过场地 → 伤害 16 → %d" % [hu_p.card.card_name, hu_dmg])
			action.emit("hunt", {"cell": _cell_of(hu_p), "dmg": hu_dmg, "big": hunt_big,
					"name": hu_p.card.card_name})
			return hu_s
		FINISHER_ID:
			# 收尾：基础伤害按「是不是手卡里最后一张」在结算时定死，再吃 _spell_dmg 加成。
			var fi_last := _finisher_is_last(side)
			var fi_dmg := _spell_dmg(side, _finisher_dmg(side), card)
			var fi_s := str(_op_deal_damage(side, fi_dmg, target))
			if fi_last:
				_log("收尾：这一张是手卡里仅剩的 → %d 点伤害（平时只有 %d 点）"
						% [fi_dmg, FINISHER_DMG])
			action.emit("finisher", {"last": fi_last, "dmg": fi_dmg,
					"cell": target if target is Vector2i else Vector2i(-1, -1)})
			return fi_s
		_:
			return "（无效果）"


func _bounce_knife(side: String, target, card: CardData) -> String:
	## 弹跳飞刀（9160，R263）：主目标吃 BOUNCE_KNIFE_DMG —— 走 `_op_deal_damage`，
	## 与连刺 / 终结同一口径（免疫法术照常免疫；没点到单位就直击对方 HP）。
	## 弹跳再从「其它敌方单位」里随机抽，最多 BOUNCE_KNIFE_BOUNCES 个，各吃 BOUNCE_KNIFE_SPLASH。
	## 三条判据（漏一条就变成别的卡）：
	##   ① **其他** = 排除主目标所在格 → 同一只不会既吃主刀又吃弹跳；
	##   ② 抽走即从池里删 → 两个弹跳一定落在**不同**单位上（不会对同一只重复）；
	##   ③ 池子先按格坐标 sort 再抽 → 与 `state.board` 的遍历顺序无关，随机只由 `rng` 决定
	##      （回放 / 联机重放的确定性靠这一条）。
	## 两段伤害都过 `_spell_dmg()` —— 荧光草 / 魔法塔 / 附魔「伤害 +10」对主刀与弹跳**都**生效。
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var main_cell: Vector2i = target if target is Vector2i else Vector2i(-1, -1)
	var msg:= str(_op_deal_damage(side, _spell_dmg(side, BOUNCE_KNIFE_DMG, card), target))
	var pool: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		if state.board[cell].owner != foe:
			continue
		if cell == main_cell:
			continue
		pool.append(cell)
	pool.sort()
	var spl:= _spell_dmg(side, BOUNCE_KNIFE_SPLASH, card)
	var bounces:= mini(BOUNCE_KNIFE_BOUNCES, pool.size())
	var hits:= 0
	var total:= 0
	var blocked:= 0
	for i in bounces:
		var pick: int = rng.randi_range(0, pool.size() - 1)
		var c: Vector2i = pool[pick]
		pool.remove_at(pick)
		var p: Placement = state.unit_at(c)
		if p == null:
			continue
		if p.card.traits.has(SPELL_IMMUNE_TRAIT):
			blocked += 1
			_log("弹跳飞刀第 %d 跳：%s 免疫法术，这一跳被拦下" % [i + 1, p.card.card_name])
			continue
		var dealt:= _hit_unit(p, spl, "弹跳飞刀")
		total += dealt
		hits += 1
		_log("弹跳飞刀第 %d 跳：命中 %s -%d（剩余 %d）" % [
			i + 1, p.card.card_name, dealt, maxi(0, p.health)])
		# 复用流星雨的落点特效通道（紫色爆点 + 「-N」飘字，不新增 action 类型）
		action.emit("meteor", {"cell": c, "dmg": dealt, "card": card})
	if hits > 0:
		_destroy_dead()
	# 文案：全部被免疫时不要写成「弹跳 0 跳共 -0」，直接只报被拦下几跳
	if hits > 0:
		msg += "；弹跳 %d 跳共 -%d" % [hits, total]
	if blocked > 0:
		msg += "（%d 跳被法术免疫拦下）" % blocked
	return msg


func _ice_wall(side: String, target) -> String:


	if not (target is Vector2i):
		return "（需要指定一条横行）"
	var cell: Vector2i = target
	if not _own_rows(side).has(cell.x):
		return "（只能在自己半场的横行上铺冰墙）"
	var repo:= CardRepo.load_json()
	var wall: CardData = repo.get_card(ICE_WALL_ID)
	if wall == null:
		wall = _fallback_ice_wall()
	var made:= 0
	for col in FieldState.BOARD_COLS:
		if made >= ICE_WALL_COUNT:
			break
		var c:= Vector2i(cell.x, col)
		if state.board.has(c):
			continue
		state.place(wall, c, side)
		made += 1
		_log("冰墙术：在 %s 生成一面冰墙" % c)
		action.emit("place", {"cell": c, "card": wall, "side": side})
	_log("冰墙术：本次生成 %d 面冰墙（该方回合开始时融化）" % made)
	return "生成 %d 面冰墙" % made


func _iron_fence(side: String, target) -> String:


	if not (target is Vector2i):
		return "（需要指定一格）"
	var cell: Vector2i = target
	if not _own_rows(side).has(cell.x):
		return "（只能在自己半场召唤铁栅栏）"
	if state.board.has(cell):
		return "（那一格已经有单位）"
	var repo:= CardRepo.load_json()
	var fence: CardData = repo.get_card(IRON_FENCE_ID)
	if fence == null:
		fence = _fallback_iron_fence()
	state.place(fence, cell, side)
	_log("坚固围栏：在 %s 召唤一个铁栅栏（0/%d）" % [cell, fence.health])
	action.emit("place", {"cell": cell, "card": fence, "side": side})
	action.emit("iron_fence", {"cell": cell, "card": fence, "side": side})
	return "在 %s 召唤一个铁栅栏" % cell


func _fallback_iron_fence() -> CardData:
	var c:= CardData.new()
	c.id = IRON_FENCE_ID
	c.card_name = "铁栅栏"
	c.kind = "工事"
	c.cost = 0
	c.power = 0
	c.health = 12
	c.attack_range = 0
	c.move_speed = 0
	c.traits = [IRON_FENCE_TRAIT, FENCE_TRAIT]
	return c


func _own_rows(side: String) -> Array:
	return range(FieldState.OPPONENT_ROWS) if side == SIDE_OPPONENT\
	else range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS)


func _meteor(side: String, target, card: CardData) -> String:


	## 陨石术（9077）：十字范围（中心 + 四邻）各受 40 点伤害，**不分敌我**。
	## 空格落在 HP 行上 → 溢出伤害直击那一方的 HP（与火球术/爆炎同一条 damage_cell 规则）。
	## R123：同一方 HP 在这一次结算里只吃一次（含溢出）。
	if not (target is Vector2i):
		return "（需要一个目标格子）"
	var center: Vector2i = target
	var cells: Array[Vector2i] = [center]
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Vector2i = center + d
		if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
			continue
		cells.append(c)
	var amount:= _spell_dmg(side, METEOR_DMG, card)
	var hits:= 0
	# R123：HP 去重上收到统一窗口（空格直击 + 后排溢出，同一方只算一次）。
	_begin_hp_once()
	for c2: Vector2i in cells:
		var q:= state.unit_at(c2)
		if q != null and q.card.traits.has(SPELL_IMMUNE_TRAIT):
			continue
		if damage_cell(c2, amount, "陨石") > 0:
			hits += 1
	_destroy_dead()
	_end_hp_once()
	_log("陨石术：十字 %d 格各受 %d 点伤害（不分敌我），命中 %d 个目标" % [
		cells.size(), amount, hits])
	return "十字 %d 格各 %d 伤（命中 %d）" % [cells.size(), amount, hits]


func _revive_spell(side: String) -> String:


	## 复活术（9078）：从弃牌区选一张盟友回到手卡。
	if side != SIDE_SELF:
		return "（复活术：敌方 AI 不使用这张卡）"
	if revive_options().is_empty():
		_log("复活术：弃牌区里没有盟友，效果落空")
		revive_pending = false
		revive_remaining = 0
		return "弃牌区里没有盟友"
	if state.hand_full():
		_log("复活术：手牌已满（%d 张），无法取回盟友" % FieldState.HAND_LIMIT)
		revive_pending = false
		revive_remaining = 0
		return "手牌已满，无法取回盟友"
	# 叠加记账：蓄力让这张卡生效 2 次 → 可以取回 2 张（一张一张选，选完才结束）
	revive_remaining += 1
	revive_pending = true
	_log("复活术：从弃牌区选择 %d 张盟友回到手牌" % revive_remaining)
	return "从弃牌区选择 %d 张盟友回到手牌" % revive_remaining


func revive_options() -> Array[int]:


	## 复活术的面板候选：弃牌区里的全部「盟友」。
	var out: Array[int] = []
	for i in state.discard.size():
		if (state.discard[i] as CardData).kind == "盟友":
			out.append(i)
	return out


func revive_recall(discard_index: int) -> bool:
	if not revive_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if c.kind != "盟友":
		return false
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	revive_remaining -= 1
	if revive_remaining <= 0:
		revive_pending = false
		revive_remaining = 0
	_log("复活术：%s 从弃牌区回到手牌（还要选 %d 张）" % [c.card_name, revive_remaining])
	action.emit("revive_recall", {"card": c})
	return true


func _overhaul_spell(side: String) -> String:
	## 返修（9127，R188，机械之心 1 费稀有）：从弃牌区选一张盟友 / 工事回手，
	## 并获得永久改造：生命 +3。
	## 口径（与复活术同构，候选多一类「工事」）：
	##   * 只在**弃牌区**里选，**必须选一张**（没有「不选了」按钮）；
	##   * 手牌已满 → 直接落空（不回手就没有改造的意义）；
	##   * 叠加记账：蓄力让这张卡生效 2 次 → 可以取回 2 张（一张一张选）。
	if side != SIDE_SELF:
		return "（返修：敌方 AI 不使用这张卡）"
	if overhaul_options().is_empty():
		_log("返修：弃牌区里没有盟友或工事，效果落空")
		overhaul_pending = false
		overhaul_remaining = 0
		return "弃牌区里没有盟友或工事"
	if state.hand_full():
		_log("返修：手牌已满（%d 张），无法取回" % FieldState.HAND_LIMIT)
		overhaul_pending = false
		overhaul_remaining = 0
		return "手牌已满，无法取回"
	overhaul_remaining += 1
	overhaul_pending = true
	_log("返修：从弃牌区选择 %d 张盟友或工事回到手牌（生命 +%d）"
			% [overhaul_remaining, OVERHAUL_HP])
	return "从弃牌区选择 %d 张盟友或工事回到手牌（生命 +%d）" % [overhaul_remaining, OVERHAUL_HP]


func overhaul_options() -> Array[int]:
	## 返修的面板候选：弃牌区里的「盟友」与「工事」（技能 / 场地 / 效果卡不可选）。
	var out: Array[int] = []
	for i in state.discard.size():
		var oc: CardData = state.discard[i]
		if oc.kind == "盟友" or oc.is_fort():
			out.append(i)
	return out


func overhaul_recall(discard_index: int) -> bool:
	## 结算返修的选择：目标卡**复制改造后**回手牌（原实例从弃牌区移除）。
	## ⚠️ 必须 from_dict 复制再改：弃牌区里的卡同样可能是卡库共享实例的传递，
	##    直接 +3 会污染卡库、跨 run 泄漏（同系统升级 / 批量改造纪律）。
	if not overhaul_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if c.kind != "盟友" and not c.is_fort():
		return false
	if state.hand_full():
		_log("返修：手牌已满，无法取回 %s" % c.card_name)
		return false
	var up := CardData.from_dict(c.to_dict())
	up.traits = (up.traits as Array).duplicate()   # 切断与卡库的共享引用
	# R120：改造奖励走**唯一口**（素体被返修也额外 +1 血）。
	var oh_hp: int = _upgrade_hp_gain(up, OVERHAUL_HP)
	up.health += oh_hp
	up.upgrade_stacks += 1   # R209：卡面写的是「获得永久改造」→ 记一层随身带
	state.discard.remove_at(discard_index)
	state.hand.append(up)
	overhaul_remaining -= 1
	if overhaul_remaining <= 0:
		overhaul_pending = false
		overhaul_remaining = 0
	_log("返修：%s 从弃牌区回到手牌，生命 +%d → %d（本场战斗永久；还要选 %d 张）"
			% [c.card_name, oh_hp, up.health, overhaul_remaining])
	_inspire_tick()   # R300 激发：返修改造一张 = 一次改造动作
	action.emit("overhaul_recall", {"card": up, "hp": oh_hp})
	return true


func _shadow_step_spell(side: String) -> String:
	## 暗影步（9121，R108）：伤害结算**之后**打开弃牌区取牌面板。
	## 候选 = 弃牌区**任意 kind**（与复活术「仅盟友」口径不同，故用独立变量）。
	if shadow_step_options().is_empty():
		_log("暗影步：弃牌区是空的，效果落空")
		shadow_step_pending = false
		shadow_step_remaining = 0
		return "弃牌区是空的"
	if state.hand_full():
		_log("暗影步：手牌已满（%d 张），无法取回" % FieldState.HAND_LIMIT)
		shadow_step_pending = false
		shadow_step_remaining = 0
		return "手牌已满，无法取回"
	# 叠加记账：蓄力让这张卡生效 2 次 → 可以取回 2 张（一张一张选）
	shadow_step_remaining += 1
	shadow_step_pending = true
	shadow_step_label = "暗影步"
	_log("暗影步：从弃牌区选择 %d 张卡回到手牌" % shadow_step_remaining)
	return "从弃牌区选择 %d 张卡回到手牌" % shadow_step_remaining


func shadow_step_options() -> Array[int]:
	## 暗影步的面板候选：弃牌区里的**全部卡**（任意 kind）。
	var out: Array[int] = []
	for i in state.discard.size():
		out.append(i)
	return out


func shadow_step_recall(discard_index: int) -> bool:
	if not shadow_step_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if state.hand_full():
		_log("暗影步：手牌已满，无法取回 %s" % c.card_name)
		return false
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	shadow_step_remaining -= 1
	if shadow_step_remaining <= 0:
		shadow_step_pending = false
		shadow_step_remaining = 0
	_log("暗影步：%s 从弃牌区回到手牌（还要选 %d 张）" % [c.card_name, shadow_step_remaining])
	action.emit("shadow_step_recall", {"card": c})
	return true


func _focus_spell(side: String) -> String:
	## 专注（9122，R109）：打开「从抽牌库移除 N 张卡」面板。
	## ⚠️ **不抽牌**：被选中的卡直接销毁（不进手牌 / 不进弃牌区）。
	if side != SIDE_SELF:
		return "（专注：敌方 AI 不使用这张卡）"
	if focus_options().is_empty():
		_log("专注：抽牌库是空的，效果落空")
		return "抽牌库是空的"
	# 牌组不足 N 张：按实际能选的张数开面板（选完即结束，不会卡住）
	var can := mini(FOCUS_NEED, state.deck.size())
	focus_remaining = can
	focus_total = can
	focus_pending = true
	focus_label = "专注"
	_log("专注：从抽牌库移除 %d 张卡（本次对战中消失）" % can)
	return "从抽牌库移除 %d 张卡" % can


func _lighten_spell(side: String) -> String:
	## 负重减轻（8066，R201）：打开「从抽牌库移除 1 张卡」面板，并在选完后
	## 给下个回合记 1 次额外抽牌（state.self_next_draw += 1，见 focus_pick 末尾）。
	## 面板 / 候选 / 取消全部复用专注那套，只差张数与「多抽一张」的记账。
	if side != SIDE_SELF:
		return "（负重减轻：敌方 AI 不使用这张卡）"
	if focus_options().is_empty():
		_log("负重减轻：抽牌库是空的，效果落空")
		focus_label = "专注"
		return "抽牌库是空的"
	# 牌组不足 N 张：按实际能选的张数开面板（选完即结束，不会卡住）
	var can := mini(LIGHTEN_NEED, state.deck.size())
	focus_remaining = can
	focus_total = can
	focus_pending = true
	focus_draw_bonus = true
	focus_label = "负重减轻"
	_log("负重减轻：从抽牌库移除 %d 张卡（本次对战中消失），下个回合多抽 1 张" % can)
	return "从抽牌库移除 %d 张卡" % can


func focus_options() -> Array[int]:
	## 专注的面板候选：**全部**卡（按卡组视角给，见 battle_scene 的「卡组」面板：
	## 按 id 合并、按 (费用,id) 排序 —— 不泄露抽牌顺序）。
	var out: Array[int] = []
	for i in state.deck.size():
		out.append(i)
	out.reverse()   # pop_back() 是抽牌顶 → 反转让面板第 1 张更接近「牌组开头」
	return out


func focus_pick(deck_index: int) -> bool:
	## 移除抽牌库里第 deck_index 张卡 —— 它**本次对战中消失**（不进手牌也不进弃牌区）。

	if not focus_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var c: CardData = state.deck[deck_index]
	state.deck.remove_at(deck_index)
	state.void_count += 1   # R140：消耗区计数（专注从牌库抹除）
	state.void_cards.append(c)
	focus_remaining -= 1
	_log("专注：%s 从抽牌库移除（本次对战中消失，还要移除 %d 张）"
			% [c.card_name, maxi(0, focus_remaining)])
	action.emit("focus_pick", {"card": c})
	if focus_remaining <= 0:
		focus_pending = false
		focus_remaining = 0
		if focus_draw_bonus:
			# 负重减轻（8066，R201）：这张消失的卡换来的收益 —— 下个回合开始时多抽 1 张
			focus_draw_bonus = false
			focus_label = "专注"
			state.self_next_draw += 1
			_log("负重减轻：下个回合开始时多抽 %d 张卡" % state.self_next_draw)
			action.emit("lighten_set", {"draw": 1, "side": SIDE_SELF})
	return true


func focus_cancel() -> void:
	## 专注面板取消（清挂起状态；已移除的卡**不回收** —— 它已经消失了）。
	if not focus_pending:
		return
	_log("%s：已取消剩余的移除" % focus_label)
	focus_pending = false
	focus_remaining = 0
	focus_draw_bonus = false
	focus_label = "专注"


func _golem_spell(side: String, target) -> String:


	## 魔像术（9079）：在自己半场选一格召唤魔像。
	if not (target is Vector2i):
		return "（需要指定一格）"
	var cell: Vector2i = target
	if not _own_rows(side).has(cell.x):
		return "（只能在自己半场召唤魔像）"
	if state.board.has(cell):
		return "（那一格已经有单位）"
	var repo:= CardRepo.load_json()
	var golem: CardData = repo.get_card(GOLEM_ID)
	if golem == null:
		golem = _fallback_golem()
	var p:= state.place(golem, cell, side)
	_log("魔像术：在 %s 召唤一个 %s（%d/%d，嘲讽）" % [
		cell, golem.card_name, golem.power, golem.health])
	action.emit("place", {"cell": cell, "card": golem, "side": side})
	action.emit("golem", {"cell": cell, "card": golem, "side": side})
	_on_ally_entered(p, side)
	return "在 %s 召唤一个魔像" % cell


func _fallback_golem() -> CardData:
	var c:= CardData.new()
	c.id = GOLEM_ID
	c.card_name = "魔像"
	c.kind = "盟友"
	c.cost = 3
	c.power = 3
	c.health = 10
	c.attack_range = 1
	c.move_speed = 1
	c.traits = [TAUNT_TRAIT, EGG_VANISH_TRAIT]
	return c


func _fallback_ice_wall() -> CardData:
	var c:= CardData.new()
	c.id = ICE_WALL_ID
	c.card_name = "冰墙"
	c.kind = "工事"
	c.cost = 0
	c.power = 0
	c.health = 10
	c.attack_range = 0
	c.move_speed = 0
	return c


func _melt_ice_walls(side: String) -> void :
	var melted:= 0
	for cell: Vector2i in state.board.keys().duplicate():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.card.id != ICE_WALL_ID:
			continue
		state.board.erase(cell)
		state.void_count += 1   # R140：消耗区计数（冰墙融化消失）
		state.void_cards.append(p.card)
		melted += 1
		action.emit("destroy", {"cell": cell, "card": p.card, "placement": p})
	if melted > 0:
		_log("冰墙术：%d 面冰墙融化消失（不进弃牌区）" % melted)


func _wind_force_dmg(side: String) -> int:
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(WIND_FORCE_TRAIT):
			return maxi(WIND_FORCE_DMG, c.value)
	return 0


func _on_ally_entered(p: Placement, side: String) -> void :



	if p == null or p.card == null:
		return
	_hidden_energy_tick(p, side)   # R331：友方**单位**（含工事）入场 → 改造 +「死亡」
	if p.card.kind != "盟友":
		return
	var dmg:= _wind_force_dmg(side)
	if dmg <= 0:
		return
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var targets: Array[Vector2i] = []
	for c: Vector2i in state.board:
		if state.board[c].owner == foe:
			targets.append(c)
	targets.sort()
	if targets.is_empty():
		_log("疾风之力：%s 登场 → 场上没有敌方单位，直击敌方 HP %d 点" % [p.card.card_name, dmg])
		_damage_player(foe, dmg, "疾风之力")
		return
	var t: Vector2i = targets[rng.randi() % targets.size()]
	var q: Placement = state.unit_at(t)
	var dealt:= _hit_unit(q, dmg, "疾风之力")
	_log("疾风之力：%s 登场 → %s -%d（剩余 %d）" % [
		p.card.card_name, q.card.card_name, dealt, maxi(0, q.health)])
	if q.health <= 0:
		_destroy_dead()


func _hidden_energy_tick(p: Placement, side: String) -> void :
	## 「隐藏能源」8078（R331，机械之心 3 费稀有效果）。
	## * 改造走 `_field_upgrade_grant()`（场上改造唯一口）—— 层数 / 卡面改造奖励 /
	##   「每次被改造」那一族（侦察塔 / 堡垒 / 无限装甲 / 废弃机器人 / 激发）全部自动生效。
	##   atk / hp 都传 0：本卡的改造**不带数值**，只挂亡语（与共享护盾 8069 同形态）。
	## * ⚠️ 判据只认 `Placement.hidden_energy` 标记，**不认** `has_affix("死亡")`。
	## * ⚠️ 走到这里时 p 还没被别的效果改过，`has_affix` 读到的是卡面原值 ——
	##   「死亡」只有本卡**新挂**上去时才记进 `hidden_energy_added`（离场要摘）。
	if not _zone_has_id(side, HIDDEN_ENERGY_ID):
		return
	if p.hidden_energy:
		return
	var new_death: bool = not p.card.has_affix(AFFIX_DEATH)
	_field_upgrade_grant(p, 0, 0, "隐藏能源", AFFIX_DEATH)
	if new_death and not p.hidden_energy_added.has(AFFIX_DEATH):
		p.hidden_energy_added.append(AFFIX_DEATH)
	p.hidden_energy = true
	_log("隐藏能源：%s 入场 → 改造 +1 层（第 %d 层），并获得「死亡」（距离 %d 内随机一个敌人 %d 伤）" % [
			p.card.card_name, p.upgrade_stacks, HIDDEN_ENERGY_RANGE, HIDDEN_ENERGY_DMG])
	action.emit("hidden_energy", {"cell": _cell_of(p), "card": p.card,
			"dmg": HIDDEN_ENERGY_DMG, "stacks": p.upgrade_stacks})


func _hidden_energy_death(p: Placement, cell: Vector2i) -> void :
	## 「隐藏能源」的死亡：对**距离 1 内**的随机一个敌人造成 8 点伤害。
	## * 「距离」= 曼哈顿（与 `attack_distance` / 侦察塔光环同一口径）；
	## * 只在**有敌方单位**时结算 —— 卡面写的是「随机一个敌人」，不溢出到对方 HP；
	## * 候选先 `sort()` 再抽：rng 消耗顺序稳定 → 同种子回放可复现；
	## * 伤害走 `_hit_unit`（护盾 / 减伤 / 石肤照常生效），致死交给 `_destroy_dead()`。
	var foe := SIDE_OPPONENT if p.owner == SIDE_SELF else SIDE_SELF
	var cand: Array[Vector2i] = []
	for c: Vector2i in state.board:
		if state.board[c].owner != foe:
			continue
		if manhattan(c, cell) <= HIDDEN_ENERGY_RANGE:
			cand.append(c)
	cand.sort()
	if cand.is_empty():
		_log("隐藏能源：%s 被破坏，但距离 %d 内没有敌人 → 落空"
				% [p.card.card_name, HIDDEN_ENERGY_RANGE])
		return
	var t: Vector2i = cand[rng.randi() % cand.size()]
	var q: Placement = state.unit_at(t)
	if q == null:
		return
	var dealt: int = _hit_unit(q, HIDDEN_ENERGY_DMG, "隐藏能源")
	_log("隐藏能源：%s 被破坏 → 距离 %d 内的 %s 受到 %d 点伤害（剩余 %d）" % [
			p.card.card_name, HIDDEN_ENERGY_RANGE, q.card.card_name, dealt, maxi(0, q.health)])
	action.emit("hidden_energy_death", {"cell": cell, "target": t, "card": q.card,
			"amount": dealt})
	if q.health <= 0:
		_destroy_dead()


func _rat_trigger() -> void :


	var cand: Array[int] = []
	for i in state.deck.size():
		var dc: CardData = state.deck[i]
		if dc.kind == "盟友" and dc.cost == 1:
			cand.append(i)
	if cand.is_empty():
		_log("巨鼠：卡组里没有 1 费盟友")
		return
	var pick:= cand[rng.randi() % cand.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	# R299：手牌满 → 那只 1 费盟友直接进弃牌区
	_grant_to_hand(chosen, "巨鼠")
	_log("巨鼠：从卡组取到 1 费盟友 %s" % chosen.card_name)


func _forest_guard(side: String, target) -> String:


	var p:= _target_placement(side, target)
	if p == null or p.owner != side or p.card.kind != "盟友":
		return "（需要指定一个盟友）"
	if p.guarding:
		return "%s 已拥有森林守护（同一单位不可重复获得）" % p.card.card_name
	p.guarding = true
	_log("%s 获得「森林守护」：我方 HP 受伤时由它代为承受" % p.card.card_name)
	return "%s 获得森林守护" % p.card.card_name


func _quick_strike(side: String) -> String:
	if side != SIDE_SELF:
		return "（对手使用）"
	state.self_ally_cost_reduction = QUICK_STRIKE_DISCOUNT
	_log("快速出击：本回合手牌中的盟友费用 -%d" % QUICK_STRIKE_DISCOUNT)
	return "本回合盟友费用 -%d" % QUICK_STRIKE_DISCOUNT


func _bite(side: String, target) -> String:


	var p:= _target_placement(side, target)
	if p == null or p.owner != side or p.card.kind != "盟友":
		return "（需要指定一个己方盟友）"
	p.atk_buff_turn += BITE_ATK_BUFF
	_log("%s 被撕咬：本回合力量 +%d（%d）" % [p.card.card_name, BITE_ATK_BUFF, p.effective_power()])
	return "%s 本回合力量 +%d" % [p.card.card_name, BITE_ATK_BUFF]


func absorbs_for_hp(p: Placement) -> bool:
	## 「谁替己方 HP 承受伤害」的**唯一判定**：森林守护（guarding）/ 大树守卫 / 铁栅栏
	## 三种卡走的是同一套机制，所以战场表现也必须一致（同色绿环）。
	## 以后再加同类机制，只改这里 —— 引擎与 battle_scene 读同一函数，不会两处漂移。
	if p == null:
		return false
	return p.guarding or p.card.traits.has(AETHER_GUARD_TRAIT)\
	or p.card.traits.has(IRON_FENCE_TRAIT)\
	# R340：宠物鸭也替我方 HP 承受伤害（与森林守护 / 铁栅栏 / 大树守卫同一条通道）
	or p.card.traits.has(PET_DUCK_TRAIT)\
	or p.card.has_affix(AFFIX_SHARED_SHIELD)


func _guard_cell(side:= SIDE_SELF) -> Vector2i:
	## 多个「替我 HP 承伤」候选时的**唯一优先级**（R269）：
	##   ① 挂着「共享护盾」字段的单位优先 —— 那是玩家**花一张牌指定**的坦克，
	##      若被森林守护 / 铁栅栏抢了先，这张牌就等于什么都没做；
	##   ② 其余候选一律按格位序号最小（原语义，保证同种子回放一致）。
	var best_affix:= Vector2i(-1, -1)
	var best:= Vector2i(-1, -1)
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != side or not absorbs_for_hp(p):
			continue
		if p.card.has_affix(AFFIX_SHARED_SHIELD):
			if best_affix == Vector2i(-1, -1) or cell < best_affix:
				best_affix = cell
			continue
		if best == Vector2i(-1, -1) or cell < best:
			best = cell
	if best_affix != Vector2i(-1, -1):
		return best_affix
	return best


func _absorb_by_guard(amount: int) -> bool:



	if amount <= 0:
		return false
	var cell:= _guard_cell(SIDE_SELF)
	if cell == Vector2i(-1, -1):
		return false
	var g: Placement = state.board[cell]
	var gname:= g.card.card_name
	var how:= "共享护盾" if g.card.has_affix(AFFIX_SHARED_SHIELD)\
	else ("大树守卫" if g.card.traits.has(AETHER_GUARD_TRAIT)\
	else ("铁栅栏" if g.card.traits.has(IRON_FENCE_TRAIT)\
	else ("宠物鸭" if g.card.traits.has(PET_DUCK_TRAIT) else "森林守护")))
	var dealt:= _hit_unit(g, amount, how)
	_log("%s：%s 替我方 HP 承受 %d 点伤害（剩余 %d）" % [how, gname, dealt, g.health])
	# R393：带上**格子**——演出要等攻击撞到那一帧才播（用户报「代受的受伤动画快过
	# 攻击动画」），没有格子的话场景只能干看着，不知道怎么冻结那个单位的血条数字。
	action.emit("guard_absorb", {"card": g.card, "how": how, "amount": dealt,
			"cell": cell})
	if g.health <= 0:

		_destroy(cell)
	return true


func _dodge_absorb(amount: int) -> int:
	## 闪躲（9103）：随机一个己方**盟友**（kind == "盟友"，工事不参战）代替本方 HP 承受伤害。
	## R403：**溢出也全部吃下** —— 用户口径「全按铁栅栏来做」：与森林守护 / 大树守卫 /
	## 铁栅栏 / 护盾生成器同一条口径，代受单位吃满全额伤害，超出其生命的部分**不再回传**，
	## 它随即被破坏。改之前这里只吃 `min(伤害, 剩余生命)`，是三条代受路径里唯一会漏的。
	## 返回「仍需自己承担」的伤害量（0 = 全被盟友吃下）。
	if amount <= 0:
		return 0
	var allies: Array[Placement] = []
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == SIDE_SELF and p.card.kind == "盟友":
			allies.append(p)
			cells.append(cell)
	if allies.is_empty():
		_log("闪躲：场上没有盟友 → 伤害仍由自己承担")
		return amount
	var i:= rng.randi_range(0, allies.size() - 1)   # 走引擎 rng：回放同种子可复现
	var g: Placement = allies[i]
	var cell2: Vector2i = cells[i]
	var absorbed:= amount
	_hit_unit(g, absorbed, "闪躲代受")
	_log("闪躲：%s 替我方 HP 承受 %d 点伤害（溢出全吃，不再结算）" % [
			g.card.card_name, absorbed])
	action.emit("dodge_absorb", {"card": g.card, "cell": cell2,
			"absorbed": absorbed, "rest": 0})
	if g.health <= 0:
		_destroy(cell2)   # R403：直接销毁、不经 `_destroy_dead` → 站后排也不会漏溢出
	return 0


func _ally_dmg_bonus(card: CardData, side: String) -> int:
	if card == null or card.kind != "盟友":
		return 0
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(BEAST_TRAIT):
			return BEAST_DMG_BONUS
	return 0


func _relic_on_enter_buffs(p: Placement) -> void :
	## **单位落地那一刻**由道具提供的常驻加成 —— 竖琴 6052 / 骑士剑 6053 / 野兽之心。
	## 唯一口（R404 抽出）：手牌打出（`play_from_hand`）与涂装机器人 8080「变成」出来的
	## 单位共用，否则同一张盟友卡两条来路两种力量，玩家一眼就看出不对。
	## ⚠️ 三处都只写 `Placement` 字段（`harp_atk` / `sword_atk` / `health`），**不烤进**
	##    `p.card` —— `place()` 接管的是卡库共享实例，烤进去同一张卡再上场会叠成 +4。
	if p == null:
		return
	var card: CardData = p.card
	# R372 竖琴（6052）：所有己方盟友 +2 力量 —— **持续 buff**（用户口径「不论如何都只 +2」）。
	if RunState.has_relic(HARP_RELIC_ID) and p.owner == SIDE_SELF and card.kind == "盟友":
		p.harp_atk = HARP_ATK
		_log("竖琴：%s 获得 +%d 力量（%d）"
				% [card.card_name, HARP_ATK, p.effective_power()])
	# R383 骑士剑（6053）：本场第一次击杀之后**才上场**的己方盟友同样 +2 力量。
	# 与竖琴逐字同构（字段 + effective_power 出口，不烤进共享 CardData）。
	if _knight_sword_active() and p.owner == SIDE_SELF and card.kind == "盟友":
		p.sword_atk = KNIGHT_SWORD_ATK
		_log("骑士剑：%s 获得 +%d 力量（%d）"
				% [card.card_name, KNIGHT_SWORD_ATK, p.effective_power()])
	var beast_hp:= _beast_hp_bonus(card)
	if beast_hp > 0:
		p.health += beast_hp
		_log("野兽之心：%s 获得 +%d 生命（%d）" % [card.card_name, beast_hp, p.health])


func _beast_hp_bonus(card: CardData) -> int:
	if card.kind != "盟友":
		return 0
	for c: CardData in state.effects:
		if c.traits.has(BEAST_TRAIT):
			return maxi(BEAST_HP_BONUS, c.value)
	return 0


func _lion_roar(lion: Placement) -> void :
	var n:= 0
	for p: Placement in state.board.values():
		if p.owner == SIDE_SELF and p.card.kind == "盟友" and p != lion:
			p.atk_buff += LION_ATK_BUFF
			n += 1
	_log("狮子：%d 个盟友攻击 +%d（不含狮子自己）" % [n, LION_ATK_BUFF])


func _hound_snapshot(hound: Placement) -> void :


	var n:= 0
	for p: Placement in state.board.values():
		if p.owner == SIDE_SELF and p.card.kind == "盟友" and p != hound:
			n += 1
	if n <= 0:
		_log("猎犬：场上没有其他盟友，未获得力量加成")
		return
	hound.atk_buff += n * HOUND_ATK_BUFF
	_log("猎犬：获得 +%d 力量（上场时场上 %d 个其他盟友）" % [n * HOUND_ATK_BUFF, n])


func crow_options() -> Array[int]:
	## 只列弃牌堆里的「盟友」；**乌鸦自己不算**（不能乌鸦套乌鸦无限回手）。
	var out: Array[int] = []
	for i in state.discard.size():
		var c: CardData = state.discard[i]
		if c.kind == "盟友" and not _is_crow(c):
			out.append(i)
	return out


func _is_crow(c: CardData) -> bool:
	return c != null and (c.id == CROW_ID or c.traits.has(CROW_TRAIT))


func wish_options() -> Array[int]:
	## 许愿（9168）：可选目标 = 卡组**全部**卡的下标（顺序即卡组顺序）。
	var out: Array[int] = []
	for i in state.deck.size():
		out.append(i)
	return out


func wish_pick(deck_index: int) -> bool:
	## 许愿的结算口：把卡组第 deck_index 张**取出来**放进手牌（卡组里就没有了）。
	## ⚠️ 只做下界与状态校验：手牌上限由这张卡自己让出的位置保证（打出时已经离手）。
	if not wish_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var c: CardData = state.deck[deck_index]
	state.deck.remove_at(deck_index)
	state.hand.append(c)
	wish_pending = false
	_log("许愿：%s 从卡组加入手卡" % c.card_name)
	return true


func crow_trigger() -> void :


	crow_pending = false
	if state.hand_full():
		_log("乌鸦：手牌已满（%d 张），无法取回盟友" % FieldState.HAND_LIMIT)
		return
	if crow_options().is_empty():
		_log("乌鸦：弃牌堆里没有盟友，效果落空")
		return
	crow_pending = true
	_log("乌鸦：从弃牌堆选择一张盟友回到手牌")


func crow_recall(discard_index: int) -> bool:
	if not crow_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if c.kind != "盟友" or _is_crow(c):
		return false   # 乌鸦不能把另一张乌鸦叫回手里
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	crow_pending = false
	_log("乌鸦：%s 从弃牌堆回到手牌" % c.card_name)
	action.emit("crow_recall", {"card": c})
	return true


func _whale_wrath(side: String, target, card: CardData) -> String:



	var detail:= str(_op_deal_damage(side, _spell_dmg(side, WHALE_WRATH_DMG, card), target))
	if side != SIDE_SELF or over:
		return detail
	if state.hand_full():
		_log("鲸鱼之怒：手牌已满（%d 张），无法从弃牌堆取牌" % FieldState.HAND_LIMIT)
		return detail
	if state.discard.is_empty():
		_log("鲸鱼之怒：弃牌堆没有卡可取，效果落空")
		return detail
	whale_pending = true
	# 叠加记账：蓄力让这张卡生效 2 次 → 可取 4 张（不是把 2 覆盖成 2）
	whale_remaining += WHALE_PICK_COUNT
	_log("鲸鱼之怒：从弃牌堆选择 %d 张卡加入手卡（可少选 / 跳过）" % whale_remaining)
	return "%s；从弃牌堆取 %d 张" % [detail, whale_remaining]


func whale_options() -> Array[int]:
	var out: Array[int] = []
	for i in state.discard.size():
		out.append(i)
	return out


func whale_pick(discard_index: int) -> bool:


	if not whale_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	if state.hand_full():
		_log("鲸鱼之怒：手牌已满，结束取牌")
		whale_pending = false
		whale_remaining = 0
		return false
	var c: CardData = state.discard[discard_index]
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	whale_remaining -= 1
	_log("鲸鱼之怒：%s 从弃牌堆回到手牌" % c.card_name)
	action.emit("whale_pick", {"card": c})
	if whale_remaining <= 0:
		whale_pending = false
		whale_remaining = 0
	return true


func whale_skip() -> void :
	if not whale_pending:
		return
	_log("鲸鱼之怒：放弃剩余 %d 张的取牌" % whale_remaining)
	whale_pending = false
	whale_remaining = 0




func _effect_damage_reduction() -> int:



	var total:= 0
	for c: CardData in state.effects:
		if c.traits.has("减伤"):
			total += c.value
	return total


func _unit_damage_taken(p: Placement, amount: int, kind := "") -> int:
	## `kind`（R152）：""（未分类）/ "attack"（单位普通攻击）/ "spell"（技能卡与效果）。
	## 「百臂工场」两条减伤要按来源分流 —— 赫卡同克瑞斯只减**攻击**，
	## 量产型赫利俄斯只减**技能**（+ 效果，与玩家口径的二分：非攻击即技能）。
	## 单位**受击前的减伤唯一口** —— 普通攻击 / 单目标技能 / 多格效果 / 陷阱 / 亡语 /
	## 反伤，全都要经过这里，否则减伤会被绕过。
	## ⚠️ 引擎里单位扣血有**两个落地口**：`_hit_unit`（普通攻击、多格、陷阱、亡语…）与
	##   `_op_deal_damage`（**单目标技能**那条）。两边都必须调本函数 —— 此前
	##   道具「护心」的 `_relic_damage_taken` 就是在这两处各写了一遍，正是收口的原因。
	## 判定顺序：① 自身减伤（犀牛 9016，R125）→ ② 赫卡同克瑞斯孤军（仅攻击，R152）
	##   → ③ 量产型赫利俄斯光环（仅技能，R152）→ ④ 道具减伤（护心 6006，仅己方）。
	## ⚠️ 只有 `amount > 0` 才减：否则 `maxi(1, 0 - 1)` 会把「0 伤害」**加成 1 点**。
	var dmg:= amount
	if p != null and p.card != null and dmg > 0 and p.card.traits.has(RHINO_TRAIT):
		var before:= dmg
		dmg = maxi(1, dmg - RHINO_DAMAGE_REDUCE)
		if dmg != before:
			_log("犀牛：受到的伤害 %d → %d" % [before, dmg])
	# ①b 重甲战车（8058，R275）：**每拥有一层改造，受到的伤害 -1，至少仍受 1 点**。
	#    层数随身（手牌 / 牌库攒的也算），所以只读 `upgrade_stacks`、不另存字段。
	if p != null and p.card != null and dmg > 0 and p.card.id == HEAVY_TANK_ID \
			and p.upgrade_stacks > 0:
		var tb:= dmg
		dmg = maxi(1, dmg - p.upgrade_stacks * HEAVY_TANK_REDUCE_PER_STACK)
		if dmg != tb:
			_log("重甲战车：改造 ×%d → 受到的伤害 %d → %d" % [p.upgrade_stacks, tb, dmg])
	# ①c 加厚装甲（8044，R275）：每次施加累计 `dmg_reduce`，同样「至少 1 点」。
	#    只记 Placement：离场时随单位一起消失（卡面写明「只在场上有效」）。
	if p != null and dmg > 0 and p.dmg_reduce > 0:
		var ab:= dmg
		dmg = maxi(1, dmg - p.dmg_reduce)
		if dmg != ab:
			_log("%s：加厚装甲减伤 %d → 受到的伤害 %d → %d" % [p.card.card_name, p.dmg_reduce, ab, dmg])
	# ② 赫卡同克瑞斯（9136，R152）：孤军成立（hecaton_atk > 0）时受到的**攻击**伤害减半。
	#    向下取整（int 除法）但至少 1 点 —— 与犀牛口径一致，1 点攻击不会被减成 0。
	if p != null and p.card != null and dmg > 0 and kind == "attack" and p.hecaton_atk > 0:
		var hb:= dmg
		dmg = maxi(1, dmg / 2)
		if dmg != hb:
			_log("%s 孤军：攻击伤害 %d → %d（减半）" % [p.card.card_name, hb, dmg])
	# ③ 量产型赫利俄斯（9137，R152）光环：除自己以外的己方单位，**技能**伤害减半
	#    （向上取整 —— 用户口径）。实时扫场面：塔被打掉 → 光环立刻失效。
	if p != null and p.card != null and dmg > 0 and kind != "attack" \
			and p.card.id != MASS_HELIOS_ID and state.has_mass_helios(p.owner):
		var mb:= dmg
		dmg = maxi(1, (dmg + 1) / 2)
		if dmg != mb:
			_log("%s：技能伤害 %d → %d（量产型赫利俄斯光环，向上取整）" % [p.card.card_name, mb, dmg])
	# ③b 启示者阶段 2（R356）：「自身受到技能伤害减半」—— 与量产型赫利俄斯同一条通道
	#     （非攻击即技能），但**只对启示者自己**生效，且去尾（向下取整、至少 1）。
	if p != null and p.card != null and dmg > 0 and kind != "attack" \
			and p.boss_phase == 2:
		var rvb:= dmg
		dmg = maxi(1, dmg / 2)
		if dmg != rvb:
			_log("启示者（电磁屏障）：技能伤害 %d → %d（减半）" % [rvb, dmg])
		# R373（用户口径「每次启示者受到技能伤害，向对方弃牌库中添加一张麻痹」）：
		# **每一次**技能伤害都塞 —— 多段技能就是多张（这是这一阶段的压力来源）。
		# ⚠️ 判据与上面这条减半完全同源（非攻击 + boss_phase == 2），所以「能吃减半的
		#    那一下」与「会塞麻痹的那一下」永远是同一批，不会出现只给其中一边。
		_add_paralysis(p)
	# ③c 启示者阶段 3（R371）：「场上有其他单位时免疫攻击以外的伤害」。
	#     排在 ③b **之后**：阶段 3 已经不吃电磁屏障那条（`boss_phase == 2` 才减半），
	#     这里是**完全免疫**，所以直接返回 0。
	#     判据收敛在 `_revelator_has_escort()`（只数它自己一方的随从，理由写在那儿）。
	if p != null and p.card != null and dmg > 0 and kind != "attack" \
			and p.boss_phase >= 3 and _revelator_has_escort(p):
		_log("启示者（阶段 3）：场上还有随从 → 免疫这次非攻击伤害")
		return 0
	if p != null and p.owner == SIDE_SELF:
		dmg = _relic_damage_taken(dmg)
	# R162：护甲优先吸收伤害（只扣护甲、不扣生命；吸收不完的才扣 HP）。
	if p != null and p.armor > 0 and dmg > 0:
		var absorbed := mini(dmg, p.armor)
		p.armor -= absorbed
		dmg -= absorbed
		_log("%s 的护甲吸收 %d 点伤害（剩余护甲 %d）" % [p.card.card_name, absorbed, p.armor])
		action.emit("armor_absorb", {"cell": _cell_of(p), "card": p.card, "side": p.owner,
				"absorbed": absorbed, "remaining": p.armor})
		if dmg <= 0:
			return 0
	return dmg


# ══════════════════════════════════════════════════════════════════════════
#  R384：伤害预览（**只读**）—— 目标格上那个「-N」的唯一来源
# ══════════════════════════════════════════════════════════════════════════
# 为什么不直接 `_hit_unit()` 试打一下：它会真扣血、真扣护甲、真发 `action`、真写日志，
#   还会触发护盾转发 / 启示者代受 / 死亡结算 —— 拖牌时每帧调一次等于把整场打穿。
# 为什么不用「深拷贝 state 再试打」：技能结算里还夹着 RunState 道具、rng、手牌流失，
#   拷一个 FieldState 盖不住，算出来的数也不可信。
# 所以这里是 `_hit_unit()` / `_op_deal_damage()` 减伤链的**逐条只读镜像**。
# ⚠️ 纪律：改 `_unit_damage_taken()` 的减伤链，**必须同步改这里**；
#    `test_engine.gd` 的 R384 断言块锁住「预览值 == 实际扣血值」（改漏了就红）。
# ⚠️ 拿不准就给 -1（界面干脆不画数字）—— 报错一次比不报的伤害大得多。
const PREVIEW_NO_DMG := -1

func _revelator_cover_amount(p: Placement, amount: int) -> int:
	## `_revelator_split()` 的**只读**版：只算「会被接通友军分走多少」，不结算。
	## 分走的永远是 `amount / 2`，与挑哪一只友军无关 → 不必复刻「挑血最高」那段。
	if p == null or p.card == null or p.card.id != REVELATOR_ID or p.boss_phase < 3:
		return 0
	if amount < 2:
		return 0
	var cell:= _cell_of(p)
	if cell.x < 0:
		return 0
	for c: Vector2i in _component_of_cell(cell):
		var q: Placement = state.unit_at(c)
		if q != null and q != p and q.owner == SIDE_OPPONENT:
			return amount / 2
	return 0


func preview_hit_damage(p: Placement, amount: int, is_attack := false,
		in_spell := false) -> Dictionary:
	## 这一个单位**最终会掉多少血**（只读）。返回 `{"dmg": int, "tag": String}`：
	##   `dmg == -1` = 给不出确数（界面不画数字）；`tag` = 为什么 / 被谁挡了。
	## `is_attack` = 单位普通攻击（减伤链按「攻击」分流）；`in_spell` = 处在技能卡结算里
	## （快速符文「对不能行动的敌人加倍」只认技能，也只在这一路补差额）。
	if p == null or p.card == null:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	# ① 易伤（对应 `_hit_unit` 开头那两条，顺序不能反：先加伤、再减伤）
	var amount2:= amount
	var aura:= _scout_aura_bonus(p, _cell_of(p))
	if aura > 0:
		amount2 += aura
	if p.owner != SIDE_SELF and _rapid_enemy_bonus > 0:
		amount2 += _rapid_enemy_bonus
	if in_spell and not is_attack and p.owner == SIDE_OPPONENT and p.cannot_act_next_turn():
		amount2 += _swift_rune_extra(amount2)
	if amount2 <= 0:
		return {"dmg": 0, "tag": ""}
	# ② 一次性防御：`_hit_unit` 与 `_op_deal_damage` 对它们处理不同（单目标技能卡**不**消耗
	#    能量屏障、**不**被护盾生成器转发）→ 预览不去猜走的是哪条路，一律不报数字。
	if p.first_hit_shield:
		return {"dmg": PREVIEW_NO_DMG, "tag": "免疫下一次伤害"}
	if _shield_gen_for(p) != null:
		return {"dmg": PREVIEW_NO_DMG, "tag": "改由护盾生成器承受"}
	# ③ 启示者阶段 3：有随从 → 完全免疫；有接通友军 → 只吃一半（去尾）
	if not is_attack and p.boss_phase >= 3:
		if _revelator_has_escort(p):
			return {"dmg": 0, "tag": "阶段 3：免疫"}
		var cover:= _revelator_cover_amount(p, amount2)
		if cover > 0:
			amount2 = maxi(0, amount2 - cover)
			if amount2 <= 0:
				return {"dmg": 0, "tag": "阶段 3：接通友军代受"}
	# ④ 减伤链（顺序逐条对齐 `_unit_damage_taken`）
	var dmg:= amount2
	if dmg > 0 and p.card.traits.has(RHINO_TRAIT):
		dmg = maxi(1, dmg - RHINO_DAMAGE_REDUCE)
	if dmg > 0 and p.card.id == HEAVY_TANK_ID and p.upgrade_stacks > 0:
		dmg = maxi(1, dmg - p.upgrade_stacks * HEAVY_TANK_REDUCE_PER_STACK)
	if dmg > 0 and p.dmg_reduce > 0:
		dmg = maxi(1, dmg - p.dmg_reduce)
	if dmg > 0 and is_attack and p.hecaton_atk > 0:
		dmg = maxi(1, dmg / 2)
	if dmg > 0 and not is_attack and p.card.id != MASS_HELIOS_ID \
			and state.has_mass_helios(p.owner):
		dmg = maxi(1, (dmg + 1) / 2)
	if dmg > 0 and not is_attack and p.boss_phase == 2:
		dmg = maxi(1, dmg / 2)
	if dmg > 0 and p.owner == SIDE_SELF:
		dmg = _relic_damage_taken(dmg)
	# ⑤ 护甲：**只算吸收掉多少**，绝不真的扣（`_unit_damage_taken` 里是会扣的）
	if dmg > 0 and p.armor > 0:
		dmg = maxi(0, dmg - p.armor)
	return {"dmg": dmg, "tag": ""}


func preview_attack_damage(src: Vector2i, dst: Vector2i, side:= SIDE_SELF) -> Dictionary:
	## 单位普攻打这一个目标 → 最终掉多少血（只读）。攻击力口径逐条照抄 `attack()`。
	var attacker:= state.unit_at(src)
	var defender:= state.unit_at(dst)
	if attacker == null or defender == null or defender.owner == side:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	var power:= attacker.effective_power() + _turn_dmg_bonus(side) \
			+ _ally_dmg_bonus(attacker.card, side)
	return preview_hit_damage(defender, power, true, false)


func preview_attack_hp(src: Vector2i, side:= SIDE_SELF) -> Dictionary:
	## 单位直击对方 HP 会打掉多少。我方打敌方 = **纯粹扣 `power`**
	## （`attack_hp` 的我方分支没有任何减伤）。敌方打我方的减伤取决于「谁替它挡」
	## （森林守护 / 荒野形态 / 石肤），预览不猜 → 不报数字。
	if side != SIDE_SELF:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	var attacker:= state.unit_at(src)
	if attacker == null:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	var power:= attacker.effective_power() + _turn_dmg_bonus(side) \
			+ _ally_dmg_bonus(attacker.card, side)
	return {"dmg": maxi(0, power), "tag": ""}


func preview_spell_damage(card: CardData, dst: Vector2i, side:= SIDE_SELF) -> Dictionary:
	## 技能卡落在这一格 → 这个单位最终掉多少血（只读）。
	## 基础值走 `spell_now()`（唯一口，全部加成都在里面），再过一遍减伤链。
	## ⚠️ **只对「格子上有单位」给数字**：空格是「打 HP」还是「这卡本来就不打人」，
	##    每张卡都不一样，硬猜必然报错 —— 那时只画 AOE 覆盖，不画数字。
	if card == null or card.kind != "技能":
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	if card.id in SPELL_NO_CELL_PREVIEW:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	var p:= state.unit_at(dst)
	if p == null:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	if p.card != null and p.card.traits.has(SPELL_IMMUNE_TRAIT):
		return {"dmg": 0, "tag": "免疫法术"}
	# ⚠️ `spell_now()` 对「卡面值就是实际值」的固定卡**返回空**（R262 定的口径：不啰嗦）。
	#    但目标格上的数字本来就是要给玩家看的 —— 没加成的火焰箭也该显示 17。
	#    所以空结果回退到 `SPELL_BASE_DMG`（这张卡的基础值），而不是当成「不报」。
	var base:= 0
	var now:= spell_now(card, side)
	if not now.is_empty():
		base = int(now.get("dmg", 0))
	elif card.id == CHARGE_UP_ID or card.id == SLAY_ID:   # R393：猎杀同蓄势，卡面值 = 实例 value
		base = card.value       # 蓄势的「卡面值」是实例数据，不在表里
	elif SPELL_BASE_DMG.has(card.id):
		base = int(SPELL_BASE_DMG[card.id])
	else:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	if base <= 0:
		return {"dmg": PREVIEW_NO_DMG, "tag": ""}
	return preview_hit_damage(p, base, false, true)


func _fx_pulse(cell: Vector2i, card: CardData, label := "") -> void:
	## **「这张卡发动了效果」的通用表现事件**（R288 唯一口）。
	##
	## 为什么需要它：引擎里大量被动 / 回合开始效果只 `_log()` 一句就结算完了，
	## 玩家看到的只有「对面数字变了」，根本不知道是谁干的。这里只报
	## **发动者所在格 + 卡 + 一句短标签**，界面负责把它演成
	## 「卡身脉冲 → 光带指向受影者 → 镜头依次把两边都带进画面」。
	## 不在这里判「有没有目标 / 目标是谁」—— 那是具体效果的事，
	## 界面拿不到目标时只演脉冲，不会画错线。
	if card == null:
		return
	if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS \
			or cell.y < 0 or cell.y >= FieldState.BOARD_COLS:
		return
	action.emit("card_pulse", {"cell": cell, "card": card,
			"label": card.card_name if label == "" else label})


func _hit_unit(p: Placement, amount: int, source:= "效果", allow_redirect:= true,
		is_attack:= false, seq:= -1) -> int:
	## R152：`is_attack` = 这一笔是不是**单位普通攻击**（只有 8466 行「战斗」那处传 true）。
	## 「百臂工场」两条减伤按来源分流：赫卡同克瑞斯只减攻击、量产型赫利俄斯只减技能。
	## 默认 false（技能/效果/陷阱/反伤…）—— 新增伤害路径时不用改这里。
	## R363：`seq` = **一次效果打多个目标**时的受击序号（0 起）。只影响界面演出节奏
	## （逐格错开落地），引擎数值 / 日志 / 回放一字不动。默认 -1 = 不参与错峰。
	# 「侦察塔」（8032）光环易伤（R120）：攻击范围内的敌人，受到**任何来源**的伤害 +1/层。
	# ⚠️ 必须放在 `amount <= 0` **之前**：0 攻的侦察塔自己攻击时基础伤害是 0，
	#    而卡面口径是「自己打也算」—— 光环得先加进去，否则那一下会被直接吞掉。
	# 挂在这里 = 与能量屏障同一个「所有伤害路径的唯一口」，漏在这里的路径会被光环绕过。
	# ⚠️ 只在**最外层**调用加（`allow_redirect`）—— 护盾生成器转发时传的是同一笔伤害，
	#    在那儿再加一次会**双算**。
	if allow_redirect:
		amount = _apply_scout_aura(p, amount)
		amount = _apply_rapid_marks(p, amount)   # R316 极速：敌人易伤（任何来源）
	# 快速符文（6043，R313）：「**对下回合不能行动的敌人效果加倍**」的那一半。
	# `_spell_dmg()` 已经按普通目标加过一次（保证预览值 == 实际值），这里补差额：
	#   amount = B × (100+p)/100  ⇒  B ≈ amount×100/(100+p)  ⇒  再补 B×p/100。
	# ⚠️ 三个前提：① 在**技能卡**结算里（`_in_spell_scope()`，效果/陷阱不算）；
	#    ② 不是单位普攻（`is_attack`）；③ 目标是敌人 —— 我方单位被打不该吃这件道具；
	#    另加 `allow_redirect` 防「护盾生成器转发」时重复补。
	if allow_redirect and not is_attack and _in_spell_scope() \
			and p.owner == SIDE_OPPONENT and p.cannot_act_next_turn():
		amount += _swift_rune_extra(amount)


	# R356：启示者阶段 3「与它接通的友方单位代它承受一半伤害（去尾）」——
	# 位置放在**所有易伤加成之后、减伤之前**：代受的是「这一刻真正要落下来的伤害」。
	amount = _revelator_split(p, amount, source)
	if amount <= 0:
		return 0
	# 能量屏障（8033，R87）：**本场战斗中第一次受到的伤害完全免掉**（一次性护盾）。
	# 挂在 `_hit_unit` 开头 = 所有伤害路径（普通攻击 / 技能 / 效果 / 直击）的唯一口，
	# 漏在这里的路径会让护盾被「绕过」（那就是 bug）。**免掉后立刻清除** —— 只用一次。
	if p.first_hit_shield:
		p.first_hit_shield = false
		_log("%s 的能量屏障挡住了这次伤害（护盾消失）" % p.card.card_name)
		action.emit("barrier", {"cell": _cell_of(p), "card": p.card,
				"blocked": amount, "side": p.owner})
		return 0
	# 护盾生成器（8042，R92）：**接通的我方单位**受伤 → **改由它承受**，
	# 溢出部分**不再结算**（不回传给原单位）。挂在能量屏障**之后** ——
	# 目标自带的一次性护盾先消耗，才轮到外部的墙，符合「自己的防御先挡」的直觉。
	# ⚠️ 转过去那一下必须 `allow_redirect = false`，否则两个生成器互相转发会无限递归。
	if allow_redirect:
		var gen:= _shield_gen_for(p)
		if gen != null:
			_log("%s：伤害被接通的护盾生成器接下（原本 %d 点%s伤害）" % [
					p.card.card_name, amount, source])
			action.emit("shield_redirect", {"cell": _cell_of(p), "card": p.card,
					"to": _cell_of(gen), "to_card": gen.card, "amount": amount,
					"source": source, "side": p.owner})
			var gen_cell:= _cell_of(gen)
			_hit_unit(gen, amount, source, false)
			# R403：生成器被打死 → **立刻就地销毁**，不要留给 `_destroy_dead()`。
			# 它站后排（x=5）时 `_destroy_dead` 会把 `-health` 当「后排溢出」漏给玩家 HP，
			# 站前排却不会 —— 同一张卡两种结果。走 `_destroy()` 与森林守护 / 铁栅栏完全
			# 同形（亡语、击杀记功照常，只是不吃那条溢出）。
			if gen_cell != Vector2i(-1, -1) and gen.health <= 0:
				_destroy(gen_cell)
			return 0
	var dmg:= _unit_damage_taken(p, amount, "attack" if is_attack else "spell")
	p.health -= dmg
	# R356：扣血之后立刻判阶段 —— 启示者掉到 200 / 100 就在**这一下**里转阶段，
	# 不等回合计。别的单位 boss_phase == 0，这里只是一个布尔判断。
	if p.boss_phase > 0:
		_revelator_check_phase(p)
	_log("%s 受到 %d 点%s伤害（剩余 %d）" % [p.card.card_name, dmg, source, p.health])
	# 恶魔鸭 9116（R63）：受击反应挂在这里 = 所有伤害路径（普通攻击 / 技能 / 效果）的唯一口。
	# 死了就不再触发（沉睡了也没意义），所以只在活着的分支调。
	if p.health > 0:
		_demon_duck_hurt(p, _cell_of(p))
	if p.owner != SIDE_SELF:
		_mark_spell_enemy_hit()
	# R123：己方**单位**受伤不再触发「一袋米抗几楼」—— 它只认我方 HP 受伤
	#（_damage_player 的两条路径 + attack_hp 直击，与鸭梨 6019 同一口径）。
	# R288：**通用受击表现事件**（唯一口）。任何来源的伤害（技能 / 被动 / 陷阱 /
	# 反伤 / 护盾转发…）都会走到这里，而界面原来只认得 `attack` / `trample_hit`
	# 两条专属路径 —— 于是虚骨龙吐息、回合结束侵蚀这类「隐形伤害」只改数字、
	# 屏幕上一动不动。事件只报**受击点 + 数值 + 来源名**：发动者由各卡自己的
	# `_fx_pulse()` 补，引擎不必在这里知道「谁打的」。
	if dmg > 0:
		var fi:= {"cell": _cell_of(p), "amount": dmg,
				"source": source, "side": p.owner}
		if seq >= 0:
			fi["seq"] = seq     # R363：多目标效果 → 界面按序号逐格错开落地
		action.emit("fx_impact", fi)
	return dmg


func _apply_frozen(p: Placement, source: String) -> void:
	## **施加冰封的唯一入口**（R68）—— 寒冰箭 9011 / 冰冻术郎战吼 / 冻结陷阱 8013
	## 都走这里，避免三处各写一遍而特效 / 表现漂移。
	## 机制本身不变：`Placement.frozen` → 下回合 `reset_units` 不重置（横置保持 = 不能行动）。
	## `source` 只进日志；界面特效由 `action.emit("frozen", …)` 驱动（战场表现唯一来源）。
	if p == null or p.health <= 0:
		return
	p.frozen = true
	_log("%s 被冰封（%s）：下回合不能行动" % [p.card.card_name, source])
	action.emit("frozen", {"cell": _cell_of(p), "name": p.card.card_name,
			"source": source})


func _apply_stun(p: Placement, source: String) -> void:
	## **施加眩晕的唯一入口**（R341，惊奇盒子 9179 被攻击时）。
	## `stun_left > 0` → 下个自己回合开始 `reset_units` 不重置（横置保持 = 不能行动），
	## 同时把 `stun_left` 减 1，所以只挡一个回合，之后自动恢复。
	## 与冰封 / 沉睡共用同一条横置通道，`cannot_act_next_turn()` 也认它。
	if p == null or p.health <= 0:
		return
	p.stun_left = maxi(p.stun_left, STUN_TURNS)
	_log("%s 被眩晕（%s）：下回合不能行动" % [p.card.card_name, source])
	action.emit("stun", {"cell": _cell_of(p), "name": p.card.card_name,
			"source": source})


func damage_cell(cell: Vector2i, amount: int, source:= "效果") -> int:






	if amount <= 0:
		return 0
	var p:= state.unit_at(cell)
	if p != null:
		return _hit_unit(p, amount, source)
	var owner:= hp_row_owner(cell.x)
	if owner == "":
		return 0
	_damage_player(owner, amount, source)
	return amount


func _relic_damage_taken(dmg: int) -> int:
	## 鸭嘴（6006）：**每满 5 点伤害减 2 点**，最少受 1 点（R399 用户口径加强）。
	##   5 → 3、9 → 7、10 → 6、15 → 9、20 → 12；不足 5 点的部分不折算（4 点照掉 4）。
	## 我方**单位**受击（10685）与**玩家 HP**（11024）共用这一个口 —— 改这里两边一起变，
	## 所以别在某一侧另写一份（旧注释里「护心」就是这个道具的旧名）。
	if self_relics.has(DUCK_BILL_RELIC_ID):
		var steps := dmg / DUCK_BILL_STEP
		if steps > 0:
			return maxi(1, dmg - steps * DUCK_BILL_STEP_REDUCE)
	return dmg


func _hp_damage_taken(amount: int) -> int:
	## 玩家 HP 伤害的**统一入口**：以太屏障 / 石肤（都把这次伤害压成 1）→
	## 效果牌减伤（_effect_damage_reduction）→ 道具减伤（_relic_damage_taken）。
	## 注意：荒野形态 6022 的「第一次受击 -4」不在这里判（它只认普通攻击直击 HP，
	## 挂在 attack_hp 里单独判），否则法术 / 效果伤害也会被算进去。
	## ⚠️ R144 顺序：荒野形态**先结算** —— `_wild_form_first_hit` 先把这次伤害减到
	## max(1, raw - 4)，**再交给这里**，所以石肤看到的是减完之后的数值
	## （12 → 荒野形态 8 → 石肤 1）。荒野形态不再「短路」掉后面整条减伤链。
	if amount <= 0:
		return 0
	if _aether_left > 0:
		_aether_left -= 1
		_log("以太屏障：这次伤害变为 1（原本 %d，本回合还剩 %d 次）" % [amount, _aether_left])
		action.emit("aether_hit", {"left": _aether_left, "amount": amount})
		return 1

	# 石肤（R144）：只在**这笔伤害 >= 2** 时触发 —— 1 点伤害本来就只掉 1 点，
	# 再「压成 1」毫无意义，白扣一次次数（玩家会觉得被吞了一次）。
	if _stoneskin_left > 0 and amount >= 2:
		_stoneskin_left -= 1
		_log("石肤：这次伤害变为 1（原本 %d，还剩 %d 次）" % [amount, _stoneskin_left])
		action.emit("stoneskin_hit", {"left": _stoneskin_left, "amount": amount})
		return 1
	var dmg:= amount
	var red:= _effect_damage_reduction()
	if red > 0:
		dmg = maxi(1, amount - red)
	return _relic_damage_taken(dmg)


func _wild_form_first_hit(attacker: Placement, raw: int) -> int:
	## 荒野形态 6022（R60 重做）：每场战斗中**第一次**自己的 HP 被敌方普通攻击打中 →
	## 这次伤害 -WILD_FORM_REDUCE（最少 1），并对攻击者造成 WILD_FORM_RETALIATE 点伤害。
	## 纯减伤 + 反伤，不再有「打熊 / 打 HP 的敌人受 3 伤」那套。
	## 返回实际 HP 伤害（调用方拿去扣血）；反伤在内部结算完毕。
	## state.wild_form_used 保证每场只触发一次（战斗重置时随 state 一起清零）。
	## ⚠️ R144：减完 4 点**继续交给 `_hp_damage_taken`**（石肤 / 以太屏障 / 效果减伤 /
	## 道具减伤照常生效）。旧写法直接 `return _relic_damage_taken(dmg)` 等于**短路**掉
	## 整条链 —— 持有荒野形态时第一次受击反而绕过石肤，与 R138 的「光环只挂一个扣血口」
	## 同源：减伤 / 触发类机制必须挂在同一条链上。
	if not self_relics.has(WILD_FORM_RELIC_ID) or state.wild_form_used:
		return _hp_damage_taken(raw)
	if attacker == null or attacker.owner != SIDE_OPPONENT or attacker.health <= 0:
		return _hp_damage_taken(raw)
	state.wild_form_used = true
	var dmg: int = maxi(1, raw - WILD_FORM_REDUCE)
	_log("荒野形态（每场第一次）：我方 HP 伤害 %d → %d" % [raw, dmg])
	action.emit("wild_form_guard", {"cell": _cell_of(attacker),
			"amount": WILD_FORM_RETALIATE, "reduced": raw - dmg,
			"name": attacker.card.card_name})
	var back:= _hit_unit(attacker, WILD_FORM_RETALIATE, "荒野形态反伤")
	_log("荒野形态：%s 受到 %d 点反伤（当前 %d）" % [
			attacker.card.card_name, back, attacker.effective_power()])
	if attacker.health <= 0:
		_destroy_dead()
	return _hp_damage_taken(dmg)


func _bear_on_field(side:= SIDE_SELF) -> bool:
	## 该方场上是否有存活的「熊」（trait 回春，8004）—— 供「熊在场」类效果查询。
	for p: Placement in state.board.values():
		if p != null and p.owner == side and p.health > 0 and p.card != null \
				and p.card.traits.has(BEAR_TRAIT):
			return true
	return false


func _spell_dmg(side: String, base: int, card: CardData = null) -> int:
	## 技能的最终伤害 = base + 各路加成。
	## card 传正在结算的技能卡：鸭之眼（6009）与魔法塔（9075）都按这张卡的**原始费用**加成
	## （刻意用 card.cost 而不是 cost_of()，各类临时减费不会把加成一起吃掉）。
	var out:= base
	# R210：商店附魔「伤害 +10」的**唯一消费点** —— 技能卡的 `power` 在卡面上**恒为 0**
	# （每张技能的具体伤害写死在下面的结算分支里），附魔把 +10 烤进 `power`，在这里并进
	# 每一段伤害。非技能卡（盟友 / 工事 / 场地 / 效果）的 `power` 是它自己的攻击力，
	# 绝不能并进技能伤害 —— 所以判据必须带 `kind == "技能"`，不能只看 `power > 0`。
	if card != null and card.kind == "技能":
		out += maxi(0, card.power)
	out += _magic_tower_bonus(side, card)   # 魔法塔：敌我通用（谁的场上塔就加谁的伤）
	out += _glowgrass_bonus(side)           # 荧光草（8010）：该方场上每株 +1
	if side != SIDE_SELF:
		return out
	if self_relics.has(DUCK_EYE_RELIC_ID) and card != null:
		out += maxi(0, card.cost)   # 加成的 X = 这张技能卡的原始费用
	if card != null and state.self_skill_plays <= 0\
	and _trait_copies(state.effects, MAGIC_CORE_TRAIT) > 0:
		out += MAGIC_CORE_DMG        # 魔力核心：每回合第一张技能伤害 +1
	out += turn_spell_bonus
	out += turn_dmg_bonus
	out += deer_bonus   # R341 鹿首标本：每回合 +1（本场累计）
	# R383 骑士剑（6053）：本场第一次击杀之后，己方技能伤害 +2（固定值，只加一次）。
	if _knight_sword_active():
		out += KNIGHT_SWORD_SPELL
	# lucky 7（6045，R314）：生效回合技能额外 +7。
	# ⚠️ 放在快速符文百分比**之前**：与鸭之眼 / 荧光草同属「固定加成」，一起被百分比放大。
	if _lucky7_active:
		out += LUCKY7_DMG
	# 快速符文（6043，R313）：本回合技能伤害 +10% × 已出牌数（加算、去尾）。
	# ⚠️ 放在**所有加法之后**再按百分比放大：固定加成（荧光草 +1 / 魔力核心 +1…）
	#    也一起吃百分比，与「先算总量再乘」的直觉一致。
	# ⚠️ 「对不能行动的敌人加倍」不在这里做 —— 那要逐目标判，在 `_hit_unit()` 补。
	out += _swift_rune_bonus(out)
	return out


func _in_spell_scope() -> bool:
	## 当前是否处在**技能卡结算**里（快速符文只认技能伤害）。见 `_spell_scope_depth`。
	return _spell_scope_depth > 0


func _swift_rune_pct() -> int:
	## 快速符文（6043）本回合的**百分比基数**（未加倍）：10 × 本回合已打出的牌数。
	## ⚠️ 口径 = **不含正在结算的这张**：`_note_card_played()` 在出牌收尾才 +1，
	##    与「终结 9086 的 X = 本回合已用张数」同一套计数，玩家看到的就是这个数。
	##    于是「先垫 3 张，再打一发大招」= +30%，与直觉一致。
	if not self_relics.has(SWIFT_RUNE_RELIC_ID):
		return 0
	return SWIFT_RUNE_PCT * maxi(0, state.self_card_plays)


func _swift_rune_bonus(amount: int) -> int:
	## 把「技能伤害 +N%」折成**整数增量**（去尾统一在这里做）。
	## ⚠️ `amount * pct / 100` 用整数除法 = 向零截断；amount 为正时等价于 floor（去尾）。
	var pct := _swift_rune_pct()
	if pct <= 0 or amount <= 0:
		return 0
	return (amount * pct) / 100


func _swift_rune_extra(amount: int) -> int:
	## 「加倍」的那**差额**：入参是**已经含过一次加成**的 amount。
	## 推导：amount = floor(B×(100+p)/100) ⇒ B ≈ amount×100/(100+p) ⇒ 差额 = B×p/100。
	## 结果就是让总量从「+p%」变成「+2p%」—— 卡面写的「效果加倍」指加成部分，不是总量翻倍。
	var pct := _swift_rune_pct()
	if pct <= 0 or amount <= 0:
		return 0
	var base:= (amount * 100) / (100 + pct)
	return (base * pct) / 100


func _turn_dmg_bonus(side: String) -> int:
	return turn_dmg_bonus if side == SIDE_SELF else 0


func _on_self_damaged() -> void :
	## R123：只在我方 **HP** 受伤时调用（_damage_player / attack_hp 两条路径）；
	## 己方场上单位受伤不再走这里（_hit_unit 已摘掉这个调用）。

	if not self_relics.has(6012) or _rice_used:
		return
	_rice_used = true
	turn_spell_bonus += 1
	var drawn:= _draw_many(1)
	_log("一袋米抗几楼：我方 HP 首次受伤 → 抽 %d 张卡，本回合技能伤害 +1" % drawn)
	action.emit("rice", {"drawn": drawn, "spell_bonus": turn_spell_bonus})


func _on_self_hp_damaged() -> void :

	# R307 荆棘指环（6037）：每回合**第一次**受到伤害 → 抽 2 张卡。
	if self_relics.has(THORN_RING_RELIC_ID) and _thorn_ring_turn != turn_number:
		_thorn_ring_turn = turn_number
		_log("荆棘指环：本回合第一次受伤 → 抽 2 张卡")
		_draw_many(2)

	if not self_relics.has(PEAR_RELIC_ID):
		return
	state.max_hp_self += 1
	_log("鸭梨：我方 HP 受伤 → 最大生命 +1（当前 %d/%d）" % [
		state.hp_self, state.max_hp_self])
	action.emit("pear", {"hp": state.hp_self, "max_hp": state.max_hp_self})


func _displace_immune(p: Placement) -> bool:
	## 「位置移动效果对它无效」的**唯一判据口**（R277 起，R371 纳入启示者）。
	##   * R277：赫菲斯托斯 9135 带「位移免疫」trait；
	##   * R371：启示者 9200 **全阶段**免疫 —— 用户口径「加强启示者：全阶段免疫位置移动效果」。
	## ⚠️ 只认这**一个**口：`_knockback`（击退 / 清退 / 空间守护 / 暗影锁链）与
	##    `_swap_two_units`（双向传送，含付费前预判）都必须调它，别再各处直接判 trait ——
	##    那样每加一个免疫来源就要改三遍，漏一处就是「某张卡能把 Boss 推走」。
	if p == null or p.card == null:
		return false
	if p.card.traits.has(DISPLACE_IMMUNE_TRAIT):
		return true
	if p.card.id == REVELATOR_ID:
		return true
	return false


func _knockback(side: String, target, steps: int) -> String:
	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
	# R277：位移免疫（赫菲斯托斯 9135）—— 判据放在这个**唯一口**，
	# 清退陷阱 / 击退 9004 / 空间守护 9064 / 暗影锁链 9112 就全都自动生效。
	# R371：启示者（9200）同样走这里 → 全阶段免疫位置移动效果。
	if _displace_immune(p):
		_log("%s 免疫位移：没有被击退" % p.card.card_name)
		return "%s 免疫位移" % p.card.card_name
	var cell:= _cell_of(p)
	if cell == Vector2i(-1, -1):
		return "（目标已不在场上）"
	var dir:= -1 if p.owner == SIDE_OPPONENT else 1
	var moved:= 0
	for i in steps:
		var nxt:= cell + Vector2i(dir, 0)
		if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS or state.board.has(nxt):
			break
		cell = nxt
		moved += 1
	if moved == 0:
		return "%s 被挡住，没有移动" % p.card.card_name
	var src:= _cell_of(p)
	var kb_path: Array[Vector2i] = []
	for i in moved + 1:
		kb_path.append(src + Vector2i(dir * i, 0))
	state.move_unit(src, cell)
	_log("%s 被击退 %d 格（%s → %s）" % [p.card.card_name, moved, src, cell])
	action.emit("move", {"src": src, "dst": cell, "card": p.card, 
		"side": p.owner, "path": kb_path})
	return "%s 后退 %d 格" % [p.card.card_name, moved]


func _vortex_push(p: Placement) -> void :
	## **漩涡（9186，R381）的唯一结算口**：「处于此格的单位**行动结束后**，随机向一个方向
	## 移动 1 格」。挂在 `_tap()`（所有行动结束的唯一口，见那里的注释）。
	##
	## 口径与边界（每条都别省）：
	##   * 「处于此格」读的是**行动结束时脚下的格子** —— 它自己走出去就不再被卷
	##     （漩涡管的是「还站在上面的人」，不是「从上面出发的人」）；
	##   * 方向在**能落脚的方向**里随机（上下左右 4 选 1）；四面被挡 / 出界 → 不动；
	##   * 随机数走引擎 `rng` → 回放同种子可复现；
	##   * 这是**位移效果** → 照走 `_displace_immune()`（赫菲斯托斯 9135 / 启示者 9200）；
	##   * 不判 `field_aim`：卡面写「场地生效·双」，敌我站上去都会被卷；
	##   * 直接 `state.move_unit`（不消耗移动权、不触发沿途陷阱），与 `_knockback` 同口径 ——
	##     所以被卷进**另一个**漩涡不会连锁（只有 `_tap` 触发，不递归）。
	if p == null or p.card == null or over:
		return
	if p.health <= 0:
		return
	var cell: Vector2i = _cell_of(p)
	if cell == Vector2i(-1, -1):
		return
	var f: CardData = state.field_at(cell)
	if f == null or not f.traits.has(PERSIST_VORTEX_TRAIT):
		return
	if _displace_immune(p):
		_log("%s 免疫位移：%s 没能把它卷走" % [p.card.card_name, f.card_name])
		return
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, -1), Vector2i(0, 1)]
	var spots: Array[Vector2i] = []
	for d: Vector2i in dirs:
		var nxt: Vector2i = cell + d
		if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS:
			continue
		if nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
			continue
		if state.board.has(nxt):
			continue
		spots.append(nxt)
	if spots.is_empty():
		_log("%s 站在 %s 上，四面都被挡住：没有移动" % [p.card.card_name, f.card_name])
		return
	var dst: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
	state.move_unit(cell, dst)
	_log("%s 被 %s 卷走 1 格（%s → %s）" % [p.card.card_name, f.card_name, cell, dst])
	var v_path: Array[Vector2i] = [cell, dst]
	action.emit("move", {"src": cell, "dst": dst, "card": p.card,
		"side": p.owner, "path": v_path})


func _goose_lunge(attacker: Placement, tgt: Vector2i) -> void :
	## **鹅（9187，R381）的唯一结算口**：「攻击敌人后，将其向后击退 1 格，自己前进 1 格
	## （被挡住则不动）」。挂在 `attack()` 尾部「攻击者还活着」那块里（`_tap` 之前）。
	##
	## 两件事各自独立判：
	##   ① 击退走**唯一口** `_knockback()` → 位移免疫 / 被己方单位挡住 / 边界全部自动生效；
	##      目标已被打死（不在 board 里了）就没有「击退」这回事；
	##   ② 前进 = 自己朝**对方后排**方向挪 1 格，只判「界内 + 那格空」—— 射程 1 时
	##      正好落进目标腾出来的格子；目标没退开（被挡 / 免疫位移）自己也就跟不上去。
	## ⚠️ 前进**不走 `move()`**：那不是一次「移动行动」，不该消耗移动权、也不该触发
	##    沿途陷阱 —— 与 `_knockback` 同口径（`state.move_unit` + 补一条 move 动画）。
	if attacker == null or attacker.card == null:
		return
	if not attacker.card.traits.has(GOOSE_TRAIT):
		return
	if state.board.has(tgt):
		var d: Placement = state.board[tgt]
		if d.health > 0 and d.owner != attacker.owner:
			_knockback(attacker.owner, tgt, 1)
	var src: Vector2i = _cell_of(attacker)
	if src == Vector2i(-1, -1):
		return
	var dir: int = 1 if attacker.owner == SIDE_OPPONENT else -1
	var nxt: Vector2i = src + Vector2i(dir, 0)
	if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS:
		return
	if state.board.has(nxt):
		return
	state.move_unit(src, nxt)
	_log("%s 前进 1 格（%s → %s）" % [attacker.card.card_name, src, nxt])
	var g_path: Array[Vector2i] = [src, nxt]
	action.emit("move", {"src": src, "dst": nxt, "card": attacker.card,
		"side": attacker.owner, "path": g_path})


func _connected_components() -> Array:
	var cells: Array[Vector2i] = []
	for c: Vector2i in state.board:
		cells.append(c)
	var seen:= {}
	var comps: Array = []
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var comp: Array[Vector2i] = [start]
		seen[start] = true
		var queue: Array = [start]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nxt: Vector2i = cur + d
				if not seen.has(nxt) and state.board.has(nxt):
					seen[nxt] = true
					comp.append(nxt)
					queue.append(nxt)
		comps.append(comp)
	return comps


func _chain_lightning(amount: int) -> String:
	var hits:= 0
	_begin_hp_once()
	for comp: Array in _connected_components():
		if comp.size() < 2:
			continue
		for cell: Vector2i in comp:
			var p:= state.unit_at(cell)
			if p == null:
				continue
			if p.card.traits.has(SPELL_IMMUNE_TRAIT):
				continue
			_hit_unit(p, amount, "闪电")
			hits += 1
	_destroy_dead()
	_end_hp_once()
	return "闪电击中 %d 个相连单位" % hits


func _blast(amount: int, target, radius: int) -> String:



	if not (target is Vector2i):
		return "（需要一个目标格子）"
	var center: Vector2i = target
	var hits:= 0
	_begin_hp_once()
	for cell: Vector2i in state.board.keys():
		if manhattan(cell, center) <= radius:
			if state.unit_at(cell) == null:
				continue
			if state.unit_at(cell).card.traits.has(SPELL_IMMUNE_TRAIT):
				continue
			if damage_cell(cell, amount, "火球") > 0:
				hits += 1


	for row: int in [back_row(SIDE_OPPONENT), back_row(SIDE_SELF)]:
		var best_c:= Vector2i(-1, -1)
		var best_d:= 999
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(row, col)
			if state.board.has(c):
				continue
			var dc:= manhattan(c, center)
			if dc <= radius and dc < best_d:
				best_d = dc
				best_c = c
		if best_c != Vector2i(-1, -1) and damage_cell(best_c, amount, "火球") > 0:
			hits += 1
	_destroy_dead()
	_end_hp_once()
	return "火球命中 %d 个目标" % hits




func _run_battlecries(side: String) -> void :



	for cell: Vector2i in state.board.keys().duplicate():
		var p:= state.unit_at(cell)
		if p == null or p.owner != side or p.battlecry_done:
			continue
		p.battlecry_done = true
		_battlecry(cell, p)


func _battlecry(cell: Vector2i, p: Placement) -> void :
	match p.card.id:
		ASH_DRAGON_ID:
			_battlecry_ash(cell, p)
		FROST_MAGE_ID:
			_battlecry_frost(cell, p)
		_:
			pass


func _battlecry_ash(cell: Vector2i, p: Placement) -> void :
	## 灰烬龙（1013）战吼：对**对方所有单位**（含工事）各 4 点，己方 / HP 都不吃这笔。
	## R363：原来这里只有一行 `_log`，界面侧连 `battlecry` 事件都没接线 ——
	## 玩家看到的是「自己整排单位同时少了 4 血，谁干的不知道」（用户口径：
	## 「伤害效果触发时没有动画特效，看起来很诡异」）。现在：
	##   ① `_fx_pulse()` 先报「这张卡发动了」（卡身脉冲 + 卡名 + 镜头）；
	##   ② `battlecry` 事件**先于**伤害发出 → 播报写清「N 个单位各 -4」；
	##   ③ 每一下带 `seq` → 界面逐格错开 90ms 落地（一排数字同帧炸 = 看不出因果）。
	var foe:= SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
	var cells: Array[Vector2i] = []
	for c: Vector2i in state.board.keys().duplicate():
		var q:= state.unit_at(c)
		if q != null and q.owner == foe:
			cells.append(c)
	# 选人顺序排序：日志 / 演出顺序可复现（不依赖字典迭代顺序）。
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	_fx_pulse(cell, p.card, "灰烬")
	action.emit("battlecry", {"cell": cell, "card": p.card, "kind": "ash",
		"amount": ASH_DRAGON_AOE, "hits": cells.size()})
	var hits:= 0
	_begin_hp_once()
	for c2: Vector2i in cells:
		var q2:= state.unit_at(c2)
		if q2 == null or q2.owner != foe:
			continue      # 前面的击杀可能已经把它带走（护盾转发 / 启示者接通代受）
		_hit_unit(q2, ASH_DRAGON_AOE, "灰烬龙", true, false, hits)
		hits += 1
	if hits > 0:
		_destroy_dead()
	_end_hp_once()
	_log("%s 战吼：对 %d 个敌方单位造成 %d 点伤害" % [p.card.card_name, hits, ASH_DRAGON_AOE])


func _battlecry_frost(cell: Vector2i, p: Placement) -> void :
	var foe:= SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
	var best:= Vector2i(-1, -1)
	var best_hp:= 999999
	for c: Vector2i in state.board:
		var q:= state.unit_at(c)
		if q == null or q.owner != foe:
			continue
		if q.health < best_hp:
			best_hp = q.health
			best = c
	if best == Vector2i(-1, -1):
		_log("%s 战吼：场上没有敌方单位可冻结" % p.card.card_name)
		return
	var q: Placement = state.board[best]
	_apply_frozen(q, "%s 战吼" % p.card.card_name)
	action.emit("battlecry", {"cell": cell, "card": p.card, "kind": "frost", "target": best})


func _deathrattle(cell: Vector2i, p: Placement) -> void :
	# R227 生命循环：被本卡点过的单位被破坏 → 加一张随机盟友卡到手卡。
	# ⚠️ 只认 Placement 标记（不认「死亡」字段 —— 那是通用标记，别的卡也带）。
	if p.life_cycle:
		_life_cycle_death(p, cell)
	# R291 辅助刃：被本卡点过的单位被破坏 → 把一张辅助刃加回手卡。
	# 同样只认 Placement 标记（不认「死亡」字段）。
	if p.blade_gift:
		_blade_gift_death(p, cell)
	# R331 隐藏能源：被本卡挂过「死亡」的单位被破坏 → 距离 1 内随机一个敌人 8 伤。
	if p.hidden_energy:
		_hidden_energy_death(p, cell)
	match p.card.id:
		WYVERN_ID:
			_summon_token(WYVERN_TOKEN_ID, cell, p.owner, 1)
		GHOUL_ID:
			var foe:= SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
			_damage_player(foe, GHOUL_DMG, "%s 亡语" % p.card.card_name)
			_log("%s 亡语：对%s HP 造成 %d 点伤害" % [
				p.card.card_name, "我方" if foe == SIDE_SELF else "敌方", GHOUL_DMG])
			action.emit("deathrattle", {"cell": cell, "card": p.card, 
				"kind": "ghoul", "amount": GHOUL_DMG})
		LICH_ID:
			_summon_token(SKELETON_TOKEN_ID, cell, p.owner, 2)
		GHOST_ID:
			if p.owner == SIDE_SELF:
				var gh_c := _fetch_skill_from_deck(0)
				_log("幽灵亡语：%s" % (("卡组随机技能卡「%s」加入手卡" % gh_c.card_name) if gh_c != null else "卡组里没有技能卡"))
				action.emit("ghost_fetch", {"card": gh_c})
			else:
				state.opp_draw(1)
		SKELETON_SUMMON_ID:

			_summon_token(SKELETON_TOKEN_ID, cell, p.owner, 1)
			action.emit("deathrattle", {"cell": cell, "card": p.card, "kind": "summon"})
		MECH_ID:
			_death_wipe(cell, MECH_DMG, p.card)
		TRAPPER_ID:
			# R116 捕兽大师：在原地留下一张随机陷阱（唯一口见该函数）
			_deathrattle_place_trap(cell, p)
		JAR_TOKEN_ID:
			# R245 罐子（工事 0/1/0）：死亡 → 召唤一个本层非 Boss 的随机敌人
			_summon_jar_enemy("罐子亡语")
		_:
			pass


func _summon_token(card_id: int, near: Vector2i, side: String, count: int) -> void :
	## R363：亡语 / 效果召唤的**唯一口**。
	## ⚠️ 落点规则没变：先原地（`near`），原地被占才退到四邻 —— 但**绝不覆盖**已有单位
	##    （`_can_hold` 挡住），退位时写一行日志，方便查「怎么出现在这格」。
	## `place` 事件带 `summon: true`：界面据此演成「召唤」（名字 + 落点光环），
	## 而不是「一张卡凭空出现」—— 幼龙死后原地变龙裔那条曾被玩家读成
	## 「旁边那只幼龙也被换了」，就是因为召唤没有任何身份提示。
	var repo:= CardRepo.load_json()
	var spawn: CardData = repo.get_card(card_id)
	if spawn == null:
		_log("召唤失败：卡牌库里没有 id=%d" % card_id)
		return
	for i in count:
		var spot:= _token_spot(near, side)
		if spot == Vector2i(-1, -1):
			_log("召唤失败：%s 周围没有空位（原地 %s）" % [spawn.card_name, str(near)])
			break
		if spot != near:
			_log("召唤：原地 %s 已被占，%s 落在 %s" % [str(near), spawn.card_name, str(spot)])
		if state.board.has(spot):
			_log("召唤被拦下：%s 已经有单位" % str(spot))
			break
		var summoned:= state.place(spawn, spot, side)
		_log("亡语：召唤了 %s（%s）" % [spawn.card_name, spot])
		action.emit("place", {"cell": spot, "card": spawn, "side": side,
				"summon": true, "from": near})
		_on_ally_entered(summoned, side)


func _token_spot(near: Vector2i, side: String) -> Vector2i:


	if _can_hold(near, side):
		return near
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var c:= near + d
		if _can_hold(c, side):
			return c
	return Vector2i(-1, -1)


func _can_hold(cell: Vector2i, side: String) -> bool:
	if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS\
	or cell.y < 0 or cell.y >= FieldState.BOARD_COLS:
		return false
	if state.board.has(cell):
		return false
	# R285：行归属走唯一口（越界 + 对方后排都不行）
	return unit_slot_allowed(cell, side)


func _add_paralysis(p: Placement) -> void:
	## 诅咒「麻痹」（9185）进**玩家弃牌库**的唯一口（R373）。
	## 触发源：启示者阶段 2「电磁屏障」每次受到技能伤害（见 `_unit_damage_taken` 的 ③b）。
	## * 目标是**弃牌库**（`state.discard`），不是牌库 —— 用户口径原话「向对方弃牌库中添加」；
	##   它会随下一次「牌库抽空 → 洗回」进牌库，不会立刻改变本回合的抽牌顺序。
	## * 副本必须 `from_dict`：卡库实例是共享的，直接塞库实例会让场上改动泄漏到图鉴。
	## * 不排队播卡面（`curse_added` 那套会卡住出牌节奏）—— 一次技能可能连塞 3~5 张，
	##   界面只播报 + 弃牌区闪一下（`paralysis_added`）。
	var base: CardData = CardRepo.load_json().get_card(PARALYSIS_CARD_ID)
	if base == null:
		_log("麻痹：找不到诅咒卡定义（%d）" % PARALYSIS_CARD_ID)
		return
	var card := CardData.from_dict(base.to_dict())
	state.discard.append(card)
	_log("麻痹：%s 受到技能伤害 → 一张「麻痹」进入你的弃牌库（弃牌区 %d 张）"
			% [p.card.card_name, state.discard.size()])
	action.emit("paralysis_added", {"card": card, "discard": state.discard.size(),
			"cell": _cell_of(p), "from": p.card})


func _paralysis_tick() -> void :
	## 诅咒「麻痹」（9185）的「留手惩罚」：**我方回合结束时**，还留在手卡里的这张卡
	## → 本场消失（进消耗区 `void_cards`，与罐子 / 次元同一口径：不会洗回牌库再抽到）。
	## 与罐子（`_jar_tick`）的区别：罐子留手要**付代价**（召唤敌人），麻痹留手只是
	## 「白占一个手牌位」—— 它的代价在**抽牌那一刻**就已经付掉了（那张牌本来该是别的）。
	## ⚠️ 必须排在 `discard_hand()` **之前**（和罐子同一个位置）。
	var count:= 0
	var rest: Array[CardData] = []
	for c: CardData in state.hand:
		if c != null and c.id == PARALYSIS_CARD_ID:
			count += 1
			state.void_count += 1
			state.void_cards.append(c)
		else:
			rest.append(c)
	if count == 0:
		return
	state.hand = rest
	_log("麻痹：回合结束仍在手卡 %d 张 → 消失" % count)
	action.emit("paralysis_gone", {"count": count})


func _jar_tick() -> void :
	## 罐子（9157，诅咒 · 1 费）的「留手惩罚」：**我方回合结束时**，还留在手卡里的这张卡
	## → 本场消失（进消耗区，与「次元」/「离场消失」同一口径）+ **直接召唤一个敌人**。
	## R340（用户口径「改为回合结束如果这张卡在手直接召唤敌人而不是罐子」）：
	## 原来「召唤一个友方 0/1 工事罐子、它死了再召敌人」的两步并成一步 ——
	## 留手的代价当场兑现，不再有「先送一个 1 血工事垫背」的缓冲。
	## 一次把手里所有罐子都结算（同名多张各算一次）；随机源走引擎 rng → 回放可复现。
	## 注：**打出**这张卡不会有这个效果（`use_curse` 付 1 费进弃牌区）—— 那是唯一的规避手段。
	var count:= 0
	var rest: Array[CardData] = []
	for c: CardData in state.hand:
		if c != null and c.id == JAR_CURSE_ID:
			count += 1
			state.void_count += 1
			state.void_cards.append(c)
		else:
			rest.append(c)
	if count == 0:
		return
	state.hand = rest
	_log("罐子：回合结束仍在手卡 %d 张 → 消失，召唤 %d 个敌人" % [count, count])
	action.emit("jar", {"count": count})
	for _i in count:
		_summon_jar_enemy("罐子")


func _egg_hatch_tick() -> void :
	## 生蛋鸭（6018）/ 鸭蛋（9022，R340）：**我方回合结束时**仍存活的鸭蛋
	## → **原地**变成「宠物鸭」（9177，盟友 3/15/程 1 /速 1），替我方 HP 承受伤害。
	## ⚠️ 用 `state.place()` **覆盖同一格**，不走进 `_destroy`：这是「孵化」不是「死亡」，
	##    不该触发亡语 / 击杀记功 / 后排溢出伤害；鸭蛋本身也没有亡语，语义上更接近「变幻」。
	## ⚠️ 副本必须 `from_dict` + `traits.duplicate()`：卡库实例共享，场上被改造会跨局泄漏。
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == SIDE_SELF and p.card.id == EGG_CARD_ID:
			cells.append(cell)
	if cells.is_empty():
		return
	var base: CardData = CardRepo.load_json().get_card(PET_DUCK_ID)
	if base == null:
		_log("生蛋鸭：卡牌库里没有「宠物鸭」（%d）" % PET_DUCK_ID)
		return
	for cell: Vector2i in cells:
		if not state.board.has(cell):
			continue
		var copy: CardData = CardData.from_dict(base.to_dict())
		copy.traits = (copy.traits as Array).duplicate()
		var born:= state.place(copy, cell, SIDE_SELF)
		_log("鸭蛋孵化：%s 的鸭蛋 → 「宠物鸭」（%d 攻 / %d 血，代替我方 HP 承受伤害）" % [
				str(cell), born.effective_power(), born.health])
		action.emit("place", {"cell": cell, "card": copy, "side": SIDE_SELF, "hatch": true})


func _jar_spot(side: String) -> Vector2i:
	## 「随机位置，优先后排」：先看**自家后排**（SELF = 第 5 行 / 敌方 = 第 0 行）有没有空格，
	## 满了再退回自家半场随机（与 `_random_free_half_cell` 同口径）。
	var row:= back_row(side)
	var free: Array[Vector2i] = []
	for col in FieldState.BOARD_COLS:
		var c:= Vector2i(row, col)
		if not state.board.has(c):
			free.append(c)
	if not free.is_empty():
		return free[rng.randi_range(0, free.size() - 1)]
	return _random_free_half_cell(side)


func _summon_jar_enemy(reason: String) -> void :
	## 罐子（9157 留手 / 9158 亡语，R245 起；R340 起留手也走这里）的唯一召唤口：
	## 召唤一个**本层非 Boss** 的随机敌人 —— 优先敌方后排（第 0 行），满了再退敌方半场随机；
	## 敌方半场全满则召唤失败（不炸场、不卡死）。
	## ⚠️ `reason` 只用于日志（「罐子」/「罐子亡语」），不再依赖被破坏单位的 Placement ——
	##    R340 的留手惩罚没有「被破坏的东西」，硬传会为 null。
	var layer:= RunState.current_layer if RunState.run_active else GameLayers.LAYER_DEFAULT
	var card:= _jar_enemy_card(layer)
	if card == null:
		_log("%s：本层没有可召唤的敌人" % reason)
		return
	var spot:= _jar_spot(SIDE_OPPONENT)
	if spot == Vector2i(-1, -1):
		_log("%s：敌方半场已满，召唤失败" % reason)
		return
	var copy:= CardData.from_dict(card.to_dict())
	state.place(copy, spot, SIDE_OPPONENT, true)
	_log("%s：召唤敌人「%s」（%s）" % [reason, card.card_name, spot])
	action.emit("place", {"cell": spot, "card": copy, "side": SIDE_OPPONENT})
	# 场上多了一个敌方单位 → 暗影领主 / 赫卡同克瑞斯 的光环立刻重算（与其它召唤同口径）
	_refresh_dark_lord(SIDE_OPPONENT)
	_refresh_hecaton(SIDE_OPPONENT)


func _jar_enemy_card(layer: int) -> CardData:
	## 敌人卡池 = 本层**非 Boss** 关卡的 `enemy_units`（按卡 id 去重）。
	## 不另立名单：关卡编成改了这里自动跟着改，也保证不会召唤到 Boss。
	var ids: Array[int] = []
	var tiers: Array = [GameLevels.TIER_NORMAL_EASY, GameLevels.TIER_NORMAL_HARD,
			GameLevels.TIER_ELITE_EASY, GameLevels.TIER_ELITE_HARD]
	for lvl: Dictionary in GameLevels.levels_of_tier(tiers, layer):
		for e: Array in lvl.get("enemy_units", []):
			var cid:= int(e[0])
			if not ids.has(cid):
				ids.append(cid)
	if ids.is_empty():
		return null
	return CardRepo.load_json().get_card(ids[rng.randi_range(0, ids.size() - 1)])


func _deathrattle_place_trap(cell: Vector2i, p: Placement) -> void :
	## 捕兽大师（9126，R116）亡语：**在原地**留下一张随机陷阱。
	## 来源与机关工坊 8015 / 警觉 9109 同一个池（唯一口 `_trap_card_pool`）；
	## 随机走引擎 rng → 回放同种子可复现。
	## ⚠️ 原地**已有场地效果就不覆盖** —— 那张很可能是玩家自己精心埋的陷阱，
	##    覆盖掉等于把「亡语」打成了负收益。卡面已写明这一条。
	## ⚠️ 刻意**不查 `field_place_allowed`**：口径是「**在原地**」，哪怕它死在我方后排
	##    （row 5 —— 敌人永远走不到，这张陷阱够不着）也照放。挪一格会让玩家困惑
	##    「我的陷阱怎么跑那边去了」；而「把捕兽大师停在后排」是玩家自己的选择。
	if state.field_at(cell) != null:
		_log("捕兽大师亡语：原地已有场地「%s」，不再覆盖"
				% str(state.field_at(cell).card_name))
		return
	var pool := _trap_card_pool(p.owner)
	if pool.is_empty():
		_log("捕兽大师亡语：奖励池里没有陷阱可放")
		return
	var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
	state.set_field(pick, cell, p.owner)
	_log("捕兽大师亡语：在原地留下陷阱「%s」（%s）" % [pick.card_name, cell])
	action.emit("field_place", {"cell": cell, "card": pick, "side": p.owner,
			"replaced": false, "deathrattle": true})


func _death_wipe(center: Vector2i, amount: int, card: CardData) -> void :
	var cells: Array[Vector2i] = []
	for c: Vector2i in state.board.keys().duplicate():
		if c == center:
			continue
		cells.append(c)
	_log("%s 死亡爆炸：全场 %d 个单位各受到 %d 点伤害" % [card.card_name, cells.size(), amount])
	_begin_hp_once()
	for c2: Vector2i in cells:
		var q:= state.unit_at(c2)
		if q == null:
			continue
		_hit_unit(q, amount, "爆裂")
	_destroy_dead()
	_end_hp_once()
	action.emit("blast", {"center": center, "cells": cells, "amount": amount, "card": card})


func _death_blast(center: Vector2i, amount: int, card: CardData) -> void :



	var cells: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c:= center + d
		if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
			continue
		cells.append(c)
	_log("%s 死亡爆炸：周围 %d 格各受到 %d 点伤害" % [card.card_name, cells.size(), amount])

	_begin_hp_once()
	for c2: Vector2i in cells:
		damage_cell(c2, amount, "爆炎")
	_destroy_dead()
	_end_hp_once()
	action.emit("blast", {"center": center, "cells": cells, "amount": amount, "card": card})


func _overload_tick(side: String) -> void :
	## 「超负荷」（旧式机兵 8050，R98）：**己方回合结束时**，
	## 带「超负荷」且生命为负的单位**真正死亡**（直接 _destroy，不触发后排「溢出伤害」）。
	## 生命已回到 1 或以上（本回合被治疗拉回）的单位则继续存活。
	## ⚠️ R281：判据是 `<= 0`（卡面「0 或以下」）—— 旧版写 `< 0`，于是**恰好 0 血**的
	##    超负荷单位既不被 `_destroy_dead` 杀（<=0 跳过）、也不被这里杀 → 永久不死。
	var dead_cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.card.has_affix(AFFIX_OVERLOAD) \
				and p.health <= 0:
			dead_cells.append(cell)
	for cell: Vector2i in dead_cells:
		var p: Placement = state.unit_at(cell)
		if p == null:
			continue
		_log("超负荷：%s 生命仍是 %d，己方回合结束死亡" % [p.card.card_name, p.health])
		action.emit("overload_die", {"cell": cell, "card": p.card,
			"health": p.health, "side": side})
		_destroy(cell)


func _forge_tick() -> void :
	## 赫菲斯托斯（9135，R150）的「锻造」：**我方回合结束**时清点 —— 这一个回合它还是
	## 没亲手击杀过敌人 → 空转 +1；满 FORGE_PERIOD → 力量 +1、攻击距离 +1，计数清零。
	## ⚠️ 挂在 `end_turn()` 的 `current_side == SIDE_SELF` 分支里（与 R149 铸造倒计时
	##    同一处），所以「N 个回合」= **玩家的** N 个回合，与卡面那句话对得上。
	##    R225：`FORGE_PERIOD` 3 → 1 = 每个我方回合都成长（用户口径）。
	## ⚠️ 射程记 `Placement.forge_range`（走 `effective_range`）、力量记 `atk_buff`，
	##    **都不写回 card** —— 关卡敌方单位是卡库共享实例，改卡面会跨局泄漏。
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.forge_period <= 0:
			continue
		p.forge_idle += 1
		if p.forge_idle < p.forge_period:
			_log("%s 空转 %d/%d 个我方回合（还没亲手击杀敌人）" % [
					p.card.card_name, p.forge_idle, p.forge_period])
			continue
		p.forge_idle = 0
		p.atk_buff += FORGE_ATK
		p.forge_range += FORGE_RANGE
		_log("%s 连续 %d 个回合没能击杀 → 锻造：力量 +%d（当前 %d）、攻击距离 +%d（当前 %d）" % [
				p.card.card_name, p.forge_period, FORGE_ATK, p.effective_power(),
				FORGE_RANGE, p.effective_range()])
		action.emit("heph_grow", {"cell": cell, "card": p.card,
				"power": p.effective_power(), "range": p.effective_range(),
				"period": p.forge_period})


func _mass_heph_kill_forge(killer: Placement) -> void :
	## 量产型赫菲斯托斯（9138，R158）「量产锻造」：**亲手击杀**敌方单位 →
	## 在**己方半场随机空格**锻造一只量产型俄倪厄（9131，5/45 程1 速1）。
	## 与 Boss 版赫菲斯托斯（9135）的差别：**没有「空转成长」那半边** ——
	## 它的 `forge_period` 恒为 0，而 `_forge_tick` / `_heph_kill_forge` 两条都以
	## `forge_period > 0` 为前提 → 都不会碰它。于是这只不会自己越长越疼，
	## 纯粹是「你送一个头它就多一只兵」。
	## ⚠️ 挂 `_credit_kill`（击杀记功唯一口），且排在骑士那条 return **之前**。
	## ⚠️ 落点走 `_random_free_half_cell`（引擎 rng → 回放同种子可复现）；
	## 召唤物走 `place(summon = true)` = 当回合恰好 1 轮行动，与恶魔召唤同口径。
	if over or killer == null or killer.card == null:
		return
	if not killer.card.traits.has(MASS_FORGE_TRAIT):
		return
	var proto: CardData = CardRepo.load_json().get_card(SUN_FORGE_FURY_ID)
	if proto == null:
		_log("量产锻造失败：卡牌库里没有 id=%d" % SUN_FORGE_FURY_ID)
		return
	var spot:= _random_free_half_cell(killer.owner)
	if spot == Vector2i(-1, -1):
		_log("%s 亲手击杀 → 想锻造量产型俄倪厄，但己方半场没有空格"
				% killer.card.card_name)
		return
	var copy:= CardData.from_dict(proto.to_dict())   # 独立副本：不与卡库实例共享
	var spawned:= state.place(copy, spot, killer.owner, true)
	_log("%s 亲手击杀 → 量产锻造出一只量产型俄倪厄（%s）" % [killer.card.card_name, spot])
	action.emit("mass_forge", {"cell": spot, "card": copy, "side": killer.owner})
	if spawned != null:
		_on_ally_entered(spawned, killer.owner)


func _argos_summon(attacker: Placement) -> void:
	## 百眼动员（量产型阿尔戈斯 9142，R174）：**在场时每单位只发动一次**
	## （`ability_used`，离场再上场算新单位）—— **攻击命中单位**时，在**己方后排**
	## （`back_row`，敌方 = row 0）召唤一只量产型俄倪厄（9131，5/45 程1 速1），
	## 并使其**移动速度 +1**（`Placement.summon_haste`，随单位离场消失，不烤进 CardData）。
	## ⚠️ 与「量产锻造」（9138）的差别：**不要求亲手击杀**，攻击命中任何单位都算；
	##    发动一次后本单位在场期间不再触发（打防御塔 / 打残血都算发动）。
	## ⚠️ 找不到格子时**不消耗次数**（保留 ability_used），下一拍攻击还能发动；
	##    落点走引擎 rng（`_random_free_half_cell`）→ 回放同种子可复现。
	## ⚠️ 召唤物走 `place(summon = true)` = 当回合恰好 1 轮行动（与恶魔召唤同口径）。
	if over or attacker == null or attacker.card == null:
		return
	if not attacker.card.traits.has(ARGOS_TRAIT):
		return
	if attacker.ability_used:
		return
	var proto: CardData = CardRepo.load_json().get_card(SUN_FORGE_FURY_ID)
	if proto == null:
		_log("百眼动员失败：卡牌库里没有 id=%d" % SUN_FORGE_FURY_ID)
		return
	var spot:= _argos_summon_spot(attacker.owner)
	if spot == Vector2i(-1, -1):
		_log("%s 想发动百眼动员，但己方半场已满（保留发动次数）" % attacker.card.card_name)
		return
	var copy:= CardData.from_dict(proto.to_dict())   # 独立副本：不与卡库实例共享
	var spawned:= state.place(copy, spot, attacker.owner, true)
	spawned.summon_haste = ARGOS_SUMMON_HASTE
	attacker.ability_used = true
	_log("%s 发动百眼动员：后排召唤一只量产型俄倪厄（%s），其移动速度 +1"
			% [attacker.card.card_name, spot])
	action.emit("argos_summon", {"cell": spot, "card": copy, "side": attacker.owner})
	if spawned != null:
		_on_ally_entered(spawned, attacker.owner)


func _argos_summon_spot(side: String) -> Vector2i:
	## 百眼动员的落点：**先找己方后排**（`back_row`）的空格（按列从左到右），
	## 后排满了再退到己方半场随机空格（`_random_free_half_cell`）。
	var br:= back_row(side)
	for col: int in FieldState.BOARD_COLS:
		var c:= Vector2i(br, col)
		if not state.board.has(c):
			return c
	return _random_free_half_cell(side)


func _heph_kill_forge(killer: Placement) -> void :
	## 赫菲斯托斯（9135，R150）**亲手击杀**敌人 → 在**己方半场随机空格**锻造一只
	## 量产型俄倪厄（9131，5/45 程1 速1），并**清零**空转计数 —— 它一直在杀人，
	## 就一直不变强（「杀一只抵三回合」这种钻空子的路因此被堵死）。
	## 落点走 `_random_free_half_cell`（引擎 rng → 回放同种子可复现），召唤物走
	## `place(summon = true)`：当回合恰好 1 轮行动，与恶魔召唤 / 暗杀召唤同口径。
	if over or killer == null or killer.card == null:
		return
	if killer.forge_period <= 0:
		return
	killer.forge_idle = 0
	var proto: CardData = CardRepo.load_json().get_card(SUN_FORGE_FURY_ID)
	if proto == null:
		_log("锻造失败：卡牌库里没有 id=%d" % SUN_FORGE_FURY_ID)
		return
	var spot:= _random_free_half_cell(killer.owner)
	if spot == Vector2i(-1, -1):
		_log("%s 亲手击杀 → 想锻造量产型俄倪厄，但己方半场没有空格"
				% killer.card.card_name)
		return
	var copy:= CardData.from_dict(proto.to_dict())   # 独立副本：不与卡库实例共享
	var spawned:= state.place(copy, spot, killer.owner, true)
	_log("%s 亲手击杀 → 锻造出一只量产型俄倪厄（%s）" % [killer.card.card_name, spot])
	action.emit("heph_forge", {"cell": spot, "card": copy, "side": killer.owner})
	if spawned != null:
		_on_ally_entered(spawned, killer.owner)


func _fuse_tick() -> void :
	## 铸造倒计时（量产型赫卡同克瑞斯 9133，R149）：**我方回合结束** -1；
	## 减到 0 → 破坏自身，并**在原地**立起一座「钢铁要塞」（9134，工事 5/100 程2 嘲讽）。
	## ⚠️ **不是亡语**（不进 `_deathrattle`）：只有倒计时走完才铸出要塞；
	##    被玩家提前打掉走的是常规 `_destroy`，什么都不留。
	## ⚠️ 破坏与落地都走唯一口 `_destroy` + `state.place`，离场记账 / 击杀记功 /
	##    战场事件与别处完全一致，不在这里另起一套。
	var ready: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.fuse_left > 0:
			p.fuse_left -= 1
			if p.fuse_left > 0:
				_log("%s 铸造倒计时：还剩 %d 个我方回合" % [p.card.card_name, p.fuse_left])
			else:
				ready.append(cell)
	for cell: Vector2i in ready:
		var q: Placement = state.unit_at(cell)
		if q == null:
			continue
		var side := q.owner
		_log("%s 铸造完成：破坏自身，在原地立起一座钢铁要塞" % q.card.card_name)
		action.emit("fuse", {"cell": cell, "card": q.card, "side": side})
		_destroy(cell)
		if over:
			# 它是场上最后一个敌人 → 那一下破坏已经判出胜负，别再往已结束的战场落子
			return
		if state.board.has(cell):
			continue
		var fort: CardData = CardRepo.load_json().get_card(STEEL_FORTRESS_ID)
		if fort == null:
			_log("铸造失败：卡牌库里没有 id=%d" % STEEL_FORTRESS_ID)
			continue
		var built := state.place(fort, cell, side)
		_log("钢铁要塞落成（%s）：5/100，攻程 2，嘲讽" % cell)
		action.emit("place", {"cell": cell, "card": fort, "side": side, "fuse": true})
		if built != null:
			_on_ally_entered(built, side)


func _destroy_dead() -> void :



	var dead: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var _pu: Placement = state.unit_at(cell)
		if _pu != null and _pu.health <= 0:
			if _pu.card.has_affix(AFFIX_OVERLOAD):
				# 超负荷（旧式机兵 8050，R98）：死亡推迟到己方回合结束，
				# 现在以负数血量继续存活，且不触发「溢出伤害」漏给玩家 HP。
				action.emit("overload_neg", {"cell": cell, "card": _pu.card,
					"health": _pu.health, "side": _pu.owner})
				_log("超负荷：%s 生命降至 %d，暂不死亡（己方回合结束若仍为 0 或更低则死亡）"
					% [_pu.card.card_name, _pu.health])
				continue
			dead.append(cell)
	for cell: Vector2i in dead:
		var p:= state.unit_at(cell)
		if p == null or p.health > 0:
			continue
		var over:= 0
		if cell.x == back_row(p.owner):
			over = maxi(0, - p.health)
		var pname:= p.card.card_name
		var pside:= p.owner
		_destroy(cell)
		if over > 0:
			_log("溢出伤害：%d 点越过 %s 漏到 %s HP" % [
				over, pname, "我方" if pside == SIDE_SELF else "敌方"])
			# R145：同上 —— 先结算再播，报实际掉血。
			_damage_player(pside, over, "溢出")
			action.emit("trample", {"side": pside, "amount": _last_hp_damage,
				"def_name": pname})
	_sync_enemy_growth()
	_check_game_over()


func _target_placement(side: String, target) -> Placement:
	if target is Vector2i:
		return state.unit_at(target)
	return null


func _op_heal(side: String, amount: int, target) -> String:
	var p:= _target_placement(side, target)
	if p != null:
		var before:= p.health
		p.health = mini(p.card.health, p.health + amount)
		_log("%s 回复 %d 点生命（当前 %d）" % [p.card.card_name, p.health - before, p.health])
		return "%s 回复 %d" % [p.card.card_name, p.health - before]

	if side == SIDE_SELF:
		var gained: int = mini(state.max_hp_self, state.hp_self + amount) - state.hp_self
		state.hp_self += gained
		_log("我方 HP 回复 %d（剩余 %d）" % [gained, state.hp_self])
		_check_game_over()
		return "我方 HP +%d" % gained
	var gained2: int = mini(state.max_hp_opponent, state.hp_opponent + amount) - state.hp_opponent
	state.hp_opponent += gained2
	_log("对方 HP 回复 %d（剩余 %d）" % [gained2, state.hp_opponent])
	_check_game_over()
	return "对方 HP +%d" % gained2


func _op_deal_damage(side: String, amount: int, target) -> String:
	var p:= _target_placement(side, target)
	if p != null:
		if p.card.traits.has(SPELL_IMMUNE_TRAIT):
			_log("%s 免疫法术，未受到伤害" % p.card.card_name)
			return "%s 免疫法术" % p.card.card_name
		# R138：技能卡伤害也要吃「侦察塔」光环易伤 —— 与 `_hit_unit` 同一条口径
		# （原先只挂在 `_hit_unit`，单目标技能走这里 → 光环被绕过）。
		# R316 极速与侦察塔光环走同一处：单目标技能卡也必须吃到敌人易伤。
		# R356：启示者阶段 3 的「接通代受」对**单目标技能**同样成立 ——
		# 这条伤害不走 `_hit_unit`（自己扣血），所以要在减伤之前单独调一次。
		amount = _revelator_split(p, amount, "技能")
		var amount2:= _unit_damage_taken(p, _apply_rapid_marks(p,
				_apply_scout_aura(p, amount)), "spell")
		p.health -= amount2
		if p.boss_phase > 0:
			_revelator_check_phase(p)
		if p.owner == SIDE_OPPONENT and amount2 > 0:
			_mark_spell_enemy_hit()
		if amount2 > 0:
			# R288b：单目标技能伤害**不走 `_hit_unit`**（自己扣血），于是界面上
			# 「血条数字变了、画面一动不动」—— 弹跳飞刀的主刀就是这么静悄悄的。
			# 与 `_hit_unit` 尾部同口径补一条通用受击事件；必须在 `_destroy_dead()` 之前发，
			# 否则单位已离场，`_cell_of()` 拿不到格子。
			action.emit("fx_impact", {"cell": _cell_of(p), "amount": amount2,
					"source": "技能", "side": p.owner})
		_log("%s 受到 %d 点效果伤害（剩余 %d）" % [p.card.card_name, amount2, p.health])
		if p.health <= 0:
			_destroy_dead()
		return "%s -%d" % [p.card.card_name, amount2]

	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var left:= _damage_player(foe, amount, "效果")
	return "对玩家造成 %d 伤害" % amount


## ── R123：一次「多格结算」里，对同一方 HP 的伤害**只结算一次** ──
## 多格效果（陨石术 / 爆炎 / 火球 / 灰烬龙战吼 / 火墙 / 回旋斩 / 闪电 / 黑暗扩散）
## 在窗口内，两条 HP 路径都汇入 _damage_player，在这里按方去重：**先到先结算，后面全跳过**：
##   * 空格落在 HP 行 → 直击那一方 HP（原先陨石 / 爆炎各自去重，现在统一到这一处）；
##   * 打破**后排**单位 → 溢出漏到那一方 HP（_destroy_dead 的通用溢出）。
## 窗口可嵌套（亡语在窗口里再炸一轮）：嵌套层共用同一份记录，不重复给机会。
var _hp_once_depth := 0
var _hp_once_sides := {}

func _begin_hp_once() -> void :
	_hp_once_depth += 1
	if _hp_once_depth == 1:
		_hp_once_sides.clear()

func _end_hp_once() -> void :
	_hp_once_depth = maxi(0, _hp_once_depth - 1)
	if _hp_once_depth == 0:
		_hp_once_sides.clear()

func _damage_player(side: String, amount: int, source:= "") -> int:
	## R123：多格窗口内，同一方 HP 已经在这次结算里吃过一次 → 这笔直接跳过。
	if _hp_once_depth > 0 and _hp_once_sides.has(side):
		_last_hp_damage = 0        # 这笔没落地（同一次结算里已经吃过）
		if side == SIDE_SELF:
			_log("（同一次多格结算：我方 HP 已吃过一次，这笔 %d 点不再重复）" % amount)
			return state.hp_self
		_log("（同一次多格结算：敌方 HP 已吃过一次，这笔 %d 点不再重复）" % amount)
		return state.hp_opponent
	if _hp_once_depth > 0:
		_hp_once_sides[side] = true
	if side == SIDE_SELF:
		# 闪躲（9103）：窗口期内先让随机盟友代受（不足的部分才落到自己的 HP 上）。
		if _dodge_active and amount > 0:
			amount = _dodge_absorb(amount)
			if amount <= 0:
				_last_hp_damage = 0     # 全被盟友代受 → 玩家 HP 一点没掉
				_check_game_over()
				return state.hp_self

		if _absorb_by_guard(amount):
			_last_hp_damage = 0         # 替己方 HP 承伤的单位全挡下了
			return state.hp_self

		# lucky 7（6045，R314）：生效回合 → **免疫所有 HP 伤害**。
		# 位置在减伤 / 不锈钢盆**之前**：伤害整个不落地，所以不该消耗盆的点数，
		# 也不该触发「减伤把 15 变 14」这种日志（那会让人以为只是少掉一点）。
		if _lucky7_active and amount > 0:
			_log("lucky 7：本回合免疫 HP 伤害（挡下 %d 点）" % amount)
			action.emit("lucky7_immune", {"amount": amount})
			_last_hp_damage = 0
			_check_game_over()
			return state.hp_self

		var dmg:= _hp_damage_taken(amount)
		# 不锈钢盆（6041，R311）：**代替玩家承受等量伤害**，计数归零即失去道具。
		# 位置在减伤**之后**：卡面写的是「等量」—— 等的是「本来会掉到你身上的血」，
		# 放在减伤之前会替玩家白挡掉鸭嘴 / 迅捷那一层，等于把减伤也吃了。
		# 部分吸收（伤害 15 / 剩 10）→ 盆吃 10、玩家吃 5：溢出部分**还给玩家**，不吞掉。
		var basin_take:= _basin_absorb(dmg)
		if basin_take > 0:
			dmg -= basin_take
		_last_hp_damage = dmg           # R145：减伤之后**真正**掉的血
		state.hp_self = maxi(0, state.hp_self - dmg)
		# R234：累计本场我方 HP 实际受到的伤害（止血绷带 6029 的判定依据）。
		if dmg > 0:
			state.self_hp_damage_taken += dmg
		# R311：差值可能是**不锈钢盆**吃掉的那部分 —— 别把盆说成「减伤」，两种来源分开写。
		if basin_take > 0:
			_log("不锈钢盆挡下 %d 点 → 实际掉血 %d" % [basin_take, dmg])
		elif dmg != amount:
			_log("减伤（迅捷/鸭嘴）：伤害 %d → %d" % [amount, dmg])
		_log("我方 HP -%d（%s），剩余 %d" % [dmg, source, state.hp_self])
		if dmg > 0:
			_on_self_damaged()
			_on_self_hp_damaged()
		_check_game_over()
		return state.hp_self
	if amount > 0:
		_mark_spell_enemy_hit()
	# R356：敌方 HP 为 ∞ 的关卡（启示者）—— 伤害不落地，只报一句。
	if enemy_hp_infinite:
		_last_hp_damage = 0
		_log("敌方 HP 为 ∞：%d 点伤害未计（%s）" % [amount, source])
		return state.hp_opponent
	state.hp_opponent = maxi(0, state.hp_opponent - amount)
	_last_hp_damage = amount      # R145：敌方 HP 没有减伤链，实际 = 账面
	var left2:= state.hp_opponent
	_log("敌方 HP -%d（%s），剩余 %d" % [amount, source, left2])
	_check_game_over()
	return left2


func relic_highlight(id: int) -> bool:
	## R314（用户口径）：道具栏**高亮**的唯一判定口 —— 「这一刻会不会真的落到触发点上」。
	## 界面（`battle_scene._draw_relic_bar`）只负责画亮边，判据全在这里，好在回归里逐条钉。
	##
	## 口径：
	##   * **临近触发 / 正在生效** → 亮（风妖精差一张牌、鸭翼/勇气徽章在生效回合、lucky 7 生效轮）；
	##   * **一直被动生效**的 → **不亮**（鸭嘴/鸭之眼/快速符文/水晶骰子/不锈钢盆 …）。
	##     它们没有「这一刻」可言，常亮等于没有信息量（用户明确排除这类）。
	##   * 未持有 → 不亮。
	if not self_relics.has(id):
		return false
	match id:
		WIND_FAIRY_RELIC_ID:
			# 下一张牌就是第 5 张（`_note_card_played` 在出牌**之后**才 +1）
			return state.self_card_plays == WIND_FAIRY_AT - 1
		LUCKY7_RELIC_ID:
			return _lucky7_active
		POPCORN_RELIC_ID:
			# 本回合到现在还没指向敌人 → 只要这么保持到回合结束就会拿到那 1 张抽牌
			return _popcorn_quiet
		DUCK_WING_RELIC_ID:
			return turn_number == DUCK_WING_TURN
		6005:   # 鸭蹼：前两回合开局多抽一张 → 该回合一开始就亮
			return turn_number <= 2
		6003:   # 鸡煲：第 1 回合、以及用过效果卡的回合（回合结束才结算）
			return current_side == SIDE_SELF \
					and (turn_number == 1 or state.self_effect_plays > 0)
		6020:   # 奥秘护符：本回合第一张效果牌 -1 → 还没打过效果牌时亮
			return state.self_effect_plays == 0
		6008:   # 鸭绒：每回合**第一个**单位 +2 血 → 还没打过单位时亮
			return not _unit_played_this_turn
		6023:   # 幻影斗篷：每两张牌触发 → 已经打了一张（下一张就触发）
			return state.self_card_plays > 0 and state.self_card_plays % 2 == 1
		COURAGE_RELIC_ID:
			# R372：精英 / Boss 两档统一成「只在首回合」，高亮判据与发费判据同源。
			var span:= 0
			if battle_kind == "elite" or battle_kind == "boss":
				span = COURAGE_TURNS
			return span > 0 and turn_number <= span
		STATUE_RELIC_ID:
			# 雕像：每 10 张牌回 1 费用 → 差 1 张就满的时候亮
			return RunState.statue_charge % 10 == 9
	return false


func _basin_absorb(dmg: int) -> int:
	## 不锈钢盆（6041，R311）的唯一结算口：返回它**实际吃下**的点数（0 = 没吃 / 没有盆）。
	## * 计数不足时只吃剩下的那部分（`mini`）—— 溢出部分留给调用方落回玩家 HP；
	## * 吃完归零 → 再发一条 `basin_break`，界面据此把道具从栏里拿走；
	## * ⚠️ 不判 `self_relics`：`basin_charge` 本身就是「还在不在」的唯一状态
	##   （界面在 `basin_break` 之后会把它清 0 并移除道具，两条路不会各行其是）。
	if dmg <= 0 or basin_charge <= 0:
		return 0
	var take:= mini(dmg, basin_charge)
	basin_charge -= take
	_log("不锈钢盆：承受 %d 点伤害（剩余 %d）" % [take, basin_charge])
	action.emit("basin_absorb", {"take": take, "left": basin_charge,
			"hp_dmg": dmg - take})
	if basin_charge <= 0:
		_log("不锈钢盆：计数归零 → 失去此道具")
		action.emit("basin_break", {"id": BASIN_RELIC_ID})
	return take


func _cell_of(p: Placement) -> Vector2i:
	for cell: Vector2i in state.board:
		if state.board[cell] == p:
			return cell
	return Vector2i(-1, -1)


func _tap(p: Placement, reason:= "") -> void :


	# R381 漩涡 9186：「处于此格的单位**行动结束后**随机移动 1 格」。
	# 挂这里而不是 move / attack / activate 各写一遍 —— `_tap` 是**行动结束的唯一口**
	# （攻击完毕 / 移动后放弃攻击 / 主动发动 / AI 待命·推进失败·按兵不动 全都经过它）。
	_vortex_push(p)
	if p.acts_left > 1:
		p.acts_left -= 1
		p.tapped = false
		p.moved = false
		_log("%s 结束一轮行动，立即开始新的一轮（还剩 %d 轮）" % [
			p.card.card_name, p.acts_left])
		return
	p.tapped = true
	p.moved = false
	_log("%s 横置（%s）" % [p.card.card_name, reason] if reason != "" else "%s 横置 →" % p.card.card_name)
	var cell:= _cell_of(p)
	action.emit("tap", {"cell": cell, "card": p.card})


func _card_first_kill_growth(killer: Placement) -> void:
	## R393：这张卡「每场战斗首次击杀」的本局永久成长（赏金猎人 / 秃鹰）。
	## 数据驱动：卡面 `first_kill_power / first_kill_health`，不为卡名写分支。
	##   * 同一场战斗里同一卡 id 只结算一次（`_first_kill_growth_done`）；
	##   * 当前站场的那一张**立刻**跟着变强（复制副本再改，绝不污染卡库）；
	##   * 数值同时记进 `RunState.card_growth`，下一场 `build_deck()` 会烤进新副本，
	##     所以离场、阵亡、换层都保留。
	if killer == null or killer.card == null:
		return
	var c: CardData = killer.card
	var gain_power := maxi(0, c.first_kill_power)
	var gain_health := maxi(0, c.first_kill_health)
	if gain_power <= 0 and gain_health <= 0:
		return
	var key := str(c.id)
	if _first_kill_growth_done.has(key):
		return
	_first_kill_growth_done[key] = true
	if RunState.run_active:
		RunState.grow_card(c.id, gain_power, gain_health, 0)
	# 当前这张：换独立副本后抬基础数值（不写 atk_buff → 离场不会被还原掉）。
	var grown := CardData.from_dict(c.to_dict())
	grown.power += gain_power
	grown.health += gain_health
	killer.card = grown
	killer.health += gain_health
	_log("%s 本场首次击杀 → 本局永久 +%d 力量 / +%d 生命（现 %d/%d）" % [
		grown.card_name, gain_power, gain_health, grown.power, killer.health])
	action.emit("card_growth", {"cell": _cell_of(killer), "card": grown,
		"power": gain_power, "health": gain_health, "permanent": true})


func _spell_kill_damage_growth(card: CardData) -> void:
	## R393：猎杀（9205）每次击杀 → 本局永久伤害 +`per_kill_damage`。
	## 当前这张的 `value` 也立刻抬高（本场若被回收 / 复制，仍带新伤害）；
	## 账本写进 RunState，下一场生成牌库时自动接上。
	if card == null:
		return
	var inc := maxi(0, card.per_kill_damage)
	if inc <= 0:
		return
	card.value += inc
	if RunState.run_active:
		RunState.grow_card(card.id, 0, 0, inc)
	_log("%s 击杀敌人 → 本局永久伤害 +%d（现 %d）" % [card.card_name, inc, card.value])
	action.emit("card_growth", {"card": card, "damage": inc, "permanent": true})


func _credit_kill(victim: Placement) -> void :
	## 击杀记功：把这次击杀算给「最后一下是谁打的」（last_hit_by）。
	## 鸭子骑士（9001）：每击杀一个敌方单位，攻击力 +KNIGHT_KILL_BUFF（永久累计）。
	if victim.last_hit_by == Vector2i(-1, -1):
		return
	var killer:= state.unit_at(victim.last_hit_by)
	if killer == null or killer.owner == victim.owner:
		return
	# R393：赏金猎人 / 秃鹰 —— 每场**首次**亲手击杀 → 本局永久成长。
	# 必须排在下面两条「击杀锻造」之前：那两条之后有骑士 trait 的 return，会漏掉新卡。
	_card_first_kill_growth(killer)
	# R150 赫菲斯托斯「亲手击杀 → 锻造量产型俄倪厄」；
	# R158 量产型赫菲斯托斯「量产锻造」走同一条通路（两个函数各自按 trait 判，
	# 互不干扰：Boss 看 forge_period > 0，量产型看「量产锻造」trait）。
	# ⚠️ 两条都必须排在骑士那条 `if not ... has(KNIGHT_TRAIT): return` **之前** ——
	#    那条一 return，击杀类效果就永远走不到。
	_mass_heph_kill_forge(killer)
	_heph_kill_forge(killer)
	if not killer.card.traits.has(KNIGHT_TRAIT):
		return
	killer.atk_buff += KNIGHT_KILL_BUFF
	_log("鸭子骑士击杀 %s → 攻击力 +%d（当前 %d）" % [
		victim.card.card_name, KNIGHT_KILL_BUFF, killer.effective_power()])
	action.emit("knight_grow", {"cell": victim.last_hit_by, "card": killer.card,
		"amount": KNIGHT_KILL_BUFF, "power": killer.effective_power()})


func configure_growth(cfg: Dictionary) -> void :
	## 关卡成长曲线（二层「低开高走」）：开局 0 层，之后每 period 个回合 +inc，最多 cap。
	## R123：**不再有「开局削减攻击力」的 debuff** —— 起始力量直接写在卡牌数据里。
	## cfg 为空 = 不启用。摆好敌方单位后调用；只对 SIDE_OPPONENT 生效。
	## cfg 字段：start_turn / period / inc / cap
	growth_cfg = cfg
	_growth_stacks = 0
	_sync_enemy_growth()


func _sync_enemy_growth() -> void :
	## 把「开局修正 + 已累计成长」写进每个敌方单位的 atk_growth。
	## 新上场的单位（亡语召唤等）也会拿到当前层数，保持同一条曲线。
	if growth_cfg.is_empty():
		return
	var inc:= int(growth_cfg.get("inc", 1))
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != SIDE_OPPONENT:
			continue
		p.atk_growth = _growth_stacks * inc


func _tick_enemy_growth() -> void :
	## 我方回合开始（turn_number 已 +1）时推进一层成长：
	## 从 start_turn 起，每 period 个回合 +inc，累计不超过 cap。层数变了才广播。
	if growth_cfg.is_empty():
		return
	var start_turn:= int(growth_cfg.get("start_turn", 1))
	var period:= maxi(1, int(growth_cfg.get("period", 1)))
	var inc:= int(growth_cfg.get("inc", 1))
	var cap:= int(growth_cfg.get("cap", 99))
	if turn_number < start_turn:
		return
	var want:= mini(((turn_number - start_turn) / period + 1) * inc, cap)
	if want == _growth_stacks:
		return
	_growth_stacks = want
	_sync_enemy_growth()
	var n:= 0
	for cell: Vector2i in state.board:
		if state.board[cell].owner == SIDE_OPPONENT:
			n += 1
	if n > 0:
		_log("关卡成长：第 %d 回合，敌方 %d 个单位攻击力 %+d" % [turn_number, n, want])
		action.emit("enemy_growth", {"stacks": want, "count": n})


func _action_growth_tick(side: String) -> void:
	## R161：行动力成长——每过 ACTION_GROWTH_PERIOD 个回合，行动次数 +1。
	## 只在「该方回合开始」调用一次；先 tick，再由 reset_units 把新行动数刷到 acts_left。
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != side or not p.card.traits.has(ACTION_GROWTH_TRAIT):
			continue
		p.action_growth_turns += 1
		if p.action_growth_turns >= ACTION_GROWTH_PERIOD:
			p.action_growth_turns = 0
			p.action_growth_extra += 1
			_log("行动力成长：%s 的「%s」行动次数 +1（现每回合 %d 次）" % [
					_zone_label(side), p.card.card_name, p.card.actions + p.action_growth_extra])
			action.emit("action_growth", {"cell": cell, "side": side, "extra": p.action_growth_extra})


func _recycler_trigger(r: Placement, victim_power: int) -> void :
	## 「零件回收者」（8046，R96）的唯一结算口，由 `_destroy` 在 erase 之后调用。
	## R221：被销毁的卡必须是「素体以外」（`_destroy` 里已按 PROTO_ID 过滤），本口不再复核。
	if r == null or r.owner != SIDE_SELF or r.card.id != RECYCLER_ID:
		return
	r.upgrade_atk += victim_power
	if victim_power > 0:
		_log("零件回收者：回收 %d 力量（现 +%d 攻）" % [victim_power, r.upgrade_atk])
	else:
		# R208：被破坏的卡力量是 0（工事 / 被削到 0）→ 攻击力一点没变，
		# 别在战报里写「回收 0 力量」（用户口径：不该弹「+0 攻」）。
		_log("零件回收者：被破坏的卡没有力量，攻击力不变（现 +%d 攻）" % r.upgrade_atk)
	# 往手牌加一张「素体」（独立副本，与机械核心 6025 同口径）。
	# R299：手牌满 → 这张素体直接进弃牌区（不再「未加入」白丢）。
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(PROTO_ID)
	if proto != null:
		if _grant_to_hand(CardData.from_dict(proto.to_dict()), "零件回收者"):
			_log("零件回收者：手牌 +1 张「素体」")
	action.emit("recycler", {"cell": _cell_of(r), "power": victim_power, "side": SIDE_SELF})


func _chimera_fuse(tyrant: Placement) -> void :
	## 「嵌合暴君」（8047，R96）的入场效果，由 `play_from_hand` 在 place 之后调用。
	## 破坏所有与这张卡**接通的己方**卡，并将其力量与生命吸收到自身（永久，离场还原）。
	if tyrant == null or tyrant.owner != SIDE_SELF or tyrant.card.id != CHIMERA_ID:
		return
	var comp:= _component_of_cell(_cell_of(tyrant))
	var targets: Array[Vector2i] = []
	for c: Vector2i in comp:
		if c == _cell_of(tyrant):
			continue
		var u: Placement = state.unit_at(c)
		if u == null or u.owner != SIDE_SELF:
			continue
		targets.append(c)
	if targets.is_empty():
		_log("嵌合暴君：周围没有己方卡可融合，未获得加成")
		action.emit("chimera", {"cell": _cell_of(tyrant), "absorbed": 0, "side": SIDE_SELF})
		return
	var got_atk:= 0
	var got_hp:= 0
	var got_refund:= 0
	for c: Vector2i in targets:
		var u: Placement = state.unit_at(c)
		if u == null:
			continue
		got_atk += u.effective_power()
		got_hp += u.card.health
		_destroy(c)
		# R326：每破坏一个回复 1 费。破坏张数 = 真正走完 `_destroy` 的次数，
		# 所以「思想钢印回手卡」的那一张**也算破坏**（它确实被破坏了），照给。
		state.energy += CHIMERA_REFUND_PER_KILL
		got_refund += CHIMERA_REFUND_PER_KILL
	# 吸收到的攻/血落到嵌合暴君（与 _upgrade_unit 同口径，离场由 _card_leaving_field 还原）。
	tyrant.upgrade_atk += got_atk
	tyrant.upgrade_hp += got_hp
	tyrant.card.health += got_hp
	tyrant.health += got_hp
	_log("嵌合暴君：融合 %d 张卡 → 力量 +%d、生命 +%d、回复 %d 费（现 %d 攻 / %d 血）" % [
		targets.size(), got_atk, got_hp, got_refund,
		tyrant.effective_power(), tyrant.health])
	action.emit("chimera", {"cell": _cell_of(tyrant), "absorbed": targets.size(),
		"atk": got_atk, "hp": got_hp, "refund": got_refund, "side": SIDE_SELF})


func _production_order(side: String) -> String :
	## 「生产订单」（8048，R96，机械之心 1 费普通技能）：往抽牌堆加两张改造过的「素体」。
	var repo := CardRepo.load_json()
	if repo == null:
		return "（没有卡库，无法生产）"
	var proto: CardData = repo.get_card(PROTO_ID)
	if proto == null:
		return "卡库缺少「素体」"
	var added:= 0
	for _i in 2:
		# ⚠️ 必须 from_dict 复制成新实例再烤改造：卡库里是共享实例，直接改会污染卡库。
		var up:= CardData.from_dict(proto.to_dict())
		# R120：改造奖励走**唯一口** —— 素体自己的 +1 生命也算上（1 攻 / 4+1=5 血）。
		up.power += _upgrade_atk_gain(up, PROD_ORDER_ATK)
		up.health += _upgrade_hp_gain(up, PROD_ORDER_HP)
		up.upgrade_stacks += 1       # R209：产出的素体天生 1 层改造（抽到上场就带着）
		state.deck.append(up)        # 加进抽牌堆（末尾），本场之后抽到即改造版素体
		if side == SIDE_SELF:
			action.emit("deck_added", {"card": up, "side": side})
		added += 1
	_log("生产订单：卡组 +%d 张改造「素体」（各 +%d 攻 / +%d 血，永久）"
		% [added, PROD_ORDER_ATK, PROD_ORDER_HP])
	action.emit("prod_order", {"count": added, "atk": PROD_ORDER_ATK,
		"hp": PROD_ORDER_HP, "side": side})
	if added > 0:
		_inspire_tick()   # R300 激发：一次产出多张改造素体 → 只算一次
	return "卡组 +%d 张改造素体" % added


func _is_upgraded(p: Placement) -> bool :
	## 「被改造」统一判定（R97「拆解」用）：覆盖三种来源 ——
	## 「升级」技能（升级层数 upgrade_stacks + 攻/血）、「改造工厂」场地（只攻/血）、
	## 「自我修复」（加成 upgrade_hp）。只要任意一项非零即视为已改造。
	if p == null:
		return false
	return p.upgrade_stacks > 0 or p.upgrade_atk != 0 or p.upgrade_hp != 0


func _demolish(target: Vector2i, side: String) -> String :
	## 「拆解」（8049，R97，机械之心 1 费稀有技能）：破坏自己一个己方盟友/工事，
	## 回复 3 费，手牌 +1「素体」；若目标被改造，额外手牌 +1「升级」8027。
	## 破坏走唯一破坏口 `_destroy` → 自然联动「零件回收者」8046。
	var p: Placement = state.unit_at(target)
	if p == null:
		return "拆解：目标格子上没有单位"
	if p.owner != SIDE_SELF or (p.card.kind != "盟友" and not p.card.is_fort()):
		return "拆解：只能拆解自己的盟友或工事"
	var was_upgraded:= _is_upgraded(p)
	# 先记力量用于日志（_destroy 后单位已离场）。
	var victim_name:= p.card.card_name
	_destroy(target)        # 唯一破坏口：联动回收者 / 离场即消失 / 进弃牌区 等全部一致
	# 回复费用（与契约签订者 / 奥秘精通同口径：不污染 self_energy_spent，允许当回合超额）。
	state.energy += DEMOLISH_REFUND
	# 手牌 +1「素体」（独立副本，与机械核心 6025 / 零件回收者同口径）。
	var got_proto:= 0
	var repo := CardRepo.load_json()
	var proto: CardData = repo.get_card(PROTO_ID) if repo != null else null
	# R299：手牌满 → 素体 / 升级直接进弃牌区；产出张数照算（日志说清给了什么）。
	if proto != null:
		_grant_to_hand(CardData.from_dict(proto.to_dict()), "拆解")
		got_proto += 1
	var got_upg:= 0
	if was_upgraded:
		var up_repo := CardRepo.load_json()
		var up_proto: CardData = up_repo.get_card(DEMOLISH_UPGRADE_BONUS) if up_repo != null else null
		if up_proto != null:
			_grant_to_hand(CardData.from_dict(up_proto.to_dict()), "拆解")
			got_upg += 1
	_log("拆解：破坏了%s（%s），回复 %d 费，产出 %d 素体%s"
		% [victim_name, "已改造" if was_upgraded else "未改造", DEMOLISH_REFUND,
			got_proto, ("，额外 +%d 升级" % got_upg) if was_upgraded else ""])
	action.emit("demolish", {"cell": target, "upgraded": was_upgraded,
		"refund": DEMOLISH_REFUND, "got_proto": got_proto, "got_upg": got_upg,
		"side": side})
	return "拆解：破坏%s，回复 %d 费%s" % [victim_name, DEMOLISH_REFUND,
		("，额外获得升级" if was_upgraded else "")]


func has_pending_death_effects() -> bool:
	## R360：还有死亡效果没结算 —— 界面据此锁操作 / 让 AI 等一拍。
	return not _death_effects.is_empty()


func _queue_death_effect(cell: Vector2i, fn: Callable) -> void:
	## R360：死亡效果入队。`defer_death_effects == false` 时等同于「立刻执行」——
	## 单元测试与回放走的都是这条，断言时序一点没变。
	if not defer_death_effects:
		fn.call()
		return
	if not _death_effects.has(cell):
		_death_effects[cell] = []
	(_death_effects[cell] as Array).append(fn)


func flush_death_effects(cell: Vector2i) -> void :
	## R360：这一格的击破演出到点了 → 把攒着的死亡效果按入队顺序结算。
	## 只取本格：同帧多处死亡，各等各的演出。
	if not _death_effects.has(cell):
		return
	var queue: Array = _death_effects[cell]
	_death_effects.erase(cell)
	for fn: Callable in queue:
		fn.call()


func flush_all_death_effects() -> void :
	## R360：兜底口 —— 界面上的闹钟丢了（动画被打断 / 定时器被清空）就一次跑完，
	## 绝不让「待结算」把玩家操作永久锁死。带次数上限：亡语互相引爆时不会在这里打转。
	var guard:= 0
	while not _death_effects.is_empty() and guard < 128:
		flush_death_effects(_death_effects.keys()[0] as Vector2i)
		guard += 1


func _destroy(cell: Vector2i) -> void :
	if not state.board.has(cell):
		return
	var p: Placement = state.board[cell]
	# R96：零件回收者触发预判 —— 在 erase 之前抓同连通块的回收者与被销毁卡的力量。
	# R221：被销毁的是「素体」（8025）→ 不触发（卡面「素体以外」）。
	var _rec_power:= p.effective_power() if (p != null) else 0
	var _rec_victim_ok:= false
	var _rec_list: Array[Placement] = []
	if p != null and p.owner == SIDE_SELF \
			and (p.card.kind == "盟友" or p.card.is_fort()) \
			and p.card.id != PROTO_ID:
		_rec_victim_ok = true
		for rc in _component_of_cell(cell):
			var ru: Placement = state.unit_at(rc)
			if ru != null and ru != p and ru.card.id == RECYCLER_ID \
					and ru.owner == SIDE_SELF:
				_rec_list.append(ru)
	state.board.erase(cell)
	_credit_kill(p)
	# R383 骑士剑（6053）：「战斗内第一次击杀一个敌人」→ 己方全体 +2 力量 / 技能 +2。
	# ⚠️ 判据只能是「被破坏的是敌方单位」—— 技能 / 陷阱 / 效果击杀都**不写
	#    `last_hit_by`**（只有单位普攻写），拿 `_credit_kill` 那套判会漏掉大半击杀。
	if p.owner != SIDE_SELF:
		_knight_sword_on_kill(p)
	# R307 思想钢印（6036）：每场战斗**第一个**被破坏的我方单位不会死 —— 回手卡。
	# ⚠️ 带「次元」/ 衍生物 / 离场消失的单位**不救**：它们本来就该消失（救回来会破坏语义）。
	if p.owner == SIDE_SELF and self_relics.has(STEEL_STAMP_RELIC_ID) \
			and not _steel_stamp_used \
			and not p.card.has_affix(AFFIX_DIMENSION) \
			and not p.card.traits.has(EGG_VANISH_TRAIT) \
			and not p.card.is_ephemeral:
		_steel_stamp_used = true
		state.hand.append(p.card)
		_log("思想钢印：%s 被破坏 → 回到手卡（本场第一次）" % p.card.card_name)
		action.emit("self_heal", {"healed": 0, "hp": state.hp_self})
		_funeral_tick(p.card.card_name)   # R327：救回手卡也算「被破坏」
		return
	if p.owner == SIDE_SELF:
		# R227：带「次元」字段的**单位**同样离场即消失（此前只有「离场消失」trait 会走这条；
		# 现在字段本身也算数 —— 卡面写的是「离开战场后消失，不会进入弃牌区」）。
		if p.card.traits.has(EGG_VANISH_TRAIT) or p.card.has_affix(AFFIX_DIMENSION):
			state.void_count += 1   # R140：消耗区计数（场上次元单位被击破）
			state.void_cards.append(p.card)
			_log("%s 被击破，移出场外（离场即消失，不进弃牌区）" % p.card.card_name)
		elif p.card.is_ephemeral:
			# 野兔 9032 的**复制**（R82）：**场上这段也消失**，不进弃牌区、不洗回牌库。
			# 判据是 `is_ephemeral`（衍生物标记）而**不是** trait「自我复制」——
			# 卡库里的原卡也带那个 trait，它被打死时应该照常进弃牌区。
			state.void_count += 1   # R140：消耗区计数（场上衍生物被击破）
			state.void_cards.append(p.card)
			_log("%s（复制）被击破，移出场外（消失，不进弃牌区）" % p.card.card_name)
		elif p.card.id == ICE_WALL_ID:
			state.void_count += 1   # R140：消耗区计数（冰墙不进弃牌区）
			state.void_cards.append(p.card)
			_log("%s 被击破，移出场外（冰墙不进弃牌区）" % p.card.card_name)
		elif p.card.id == CARGO_ID:
			# R200：货物被破坏 → **从卡组中删除**（场上这份 void 不进弃牌区）。
			state.void_count += 1
			state.void_cards.append(p.card)
			if RunState.remove_card(CARGO_ID):
				_log("货物被破坏，从卡组中删除（卡组内货物剩余 %d）"
						% RunState.cargo_count())
			else:
				_log("货物被破坏（卡组内已无货物可删）")
		elif p.card.id == LYNX_ID:

			var back:= CardData.from_dict(p.card.to_dict())
			back.cost = 1
			if state.hand_full():
				_log("%s 被击破，返回手牌被手牌上限挡下 → 进弃牌区（1 费）"
					%p.card.card_name)
				state.discard.append(back)
			else:
				_log("%s 被击破，返回手牌（变为 1 费）" % p.card.card_name)
				state.hand.append(back)
		else:
			# 进弃牌区的是「离场还原后」那张卡：栅栏修复术的加血只在场上有效（R67）。
			# action.emit 里的 card 仍用场上那张（玩家看到的就是它），只有交出去的卡被还原。
			_log("%s 被击破，进弃牌区" % p.card.card_name)
			state.discard.append(_card_leaving_field(p))
	else:

		_log("%s 被击破，移出场外" % p.card.card_name)
	action.emit("destroy", {"cell": cell, "card": p.card, "placement": p})

	# R360：亡语这一批**不在这一帧结算** —— 界面此刻还停在击破演出上（卡要留
	# `DESTROY_HOLD_MS` 才抹掉，幽灵淡出还要 800ms）。同步跑就会出现
	# 「辅助刃先回手 / 送葬先抽牌，而场上那张卡还站着」的时序倒错。
	# 现在统一入队，由 battle_scene 在那张卡的击破演出到点时调 `flush_death_effects(cell)`。
	# ⚠️ 入队顺序 = 原来的执行顺序；`defer_death_effects == false`（测试 / 回放）立即执行。
	_queue_death_effect(cell,
			_settle_death.bind(cell, p, _rec_victim_ok, _rec_power, _rec_list))


func _settle_death(cell: Vector2i, p: Placement, rec_ok: bool, rec_power: int,
		rec_list: Array) -> void :
	## R360：一个单位被破坏之后的**全部**触发 —— 爆炎鸭爆炸 / 亡语 / 胜负判定 /
	## 零件回收者 / 三个光环重算 / 送葬抽牌。顺序与 R327 时完全一致，
	## 只是从 `_destroy()` 尾部搬到这里，好让界面决定「什么时候才跑」。
	## ⚠️ 别把「进弃牌区 / 离场摘字段」搬进来：那部分仍在 `_destroy()` 里同步做
	##    （它们在 emit 之前，玩家看不到，也不该等动画）。
	if p.card.id == BLAZE_DUCK_ID:
		_death_blast(cell, BLAZE_DUCK_DAMAGE, p.card)
	_deathrattle(cell, p)
	_check_game_over()
	# R96：零件回收者 —— 被销毁的是己方「素体以外」盟友/工事时，连通块内的回收者回收其力量 + 手牌加素体。
	if rec_ok:
		for _r: Placement in rec_list:
			_recycler_trigger(_r, rec_power)
	# R111 暗影领主：场上少了一个单位 → 重算（死的是暗杀者时鸭之暗面立刻掉 3 力 1 速）。
	_refresh_dark_lord(p.owner)
	# R152 赫卡同克瑞斯：场上单位数变了 → 孤军判定重算（塔被拆 → 立刻狂暴）。
	_refresh_hecaton(p.owner)
	# R271 谟涅摩叙涅：场上少了一张（可能是它自己）→ 光环立刻重算。
	_refresh_mnemosyne()
	# R327 送葬：放在**所有**离场结算之后 —— 先炸（亡语/回收/光环重算）再抽牌，
	# 抽到的牌不会插进亡语动画中间。判据只看「己方效果区有没有这张」。
	_funeral_tick(p.card.card_name)


func _funeral_tick(source_name: String) -> void :
	## R327 送葬（9175）：场上每有一个单位被破坏 → **抽 1 张卡**。
	## ⚠️ 只认己方效果区（`state.effects`），敌方效果区即使有同名卡也不给玩家抽。
	## ⚠️ 多张不叠加 → 用 `_zone_has`（有没有）而不是 `_trait_copies`（有几张）。
	## 抽卡一律走 `_draw_many` 唯一口：手牌满时会 burn 进弃牌区并播动画，不会静静吞掉。
	if not _zone_has(state.effects, FUNERAL_TRAIT):
		return
	var got:= _draw_many(FUNERAL_DRAW)
	if got > 0:
		_log("送葬：%s 被破坏 → 抽 %d 张卡" % [source_name, got])
	else:
		_log("送葬：%s 被破坏 → 牌库与弃牌区都空，抽不到牌" % source_name)
	action.emit("funeral", {"name": source_name, "drawn": got})




func _move_bfs(start: Vector2i, side: String, freed:= Vector2i(-1, -1), 
		speed_override:= -1, phasing_override:= -1) -> Dictionary:



	var p_self:= state.unit_at(start)
	# 穿行（R111 鸭之暗面）：移动可以**经过**被占用的格子，但不允许停在上面（落点由 move_path 拦）。
	# 自动判定读起点上的单位；两次行动绕行时起点是空格，所以由调用方显式传 phasing_override。
	var phasing:= phasing_override
	if phasing < 0:
		phasing = 1 if (p_self != null and p_self.card.traits.has(PHASE_TRAIT)) else 0
	var speed:= speed_override
	if speed < 0:
		if p_self == null or p_self.card.is_fort():
			return {}
		speed = p_self.effective_speed()
		if self_relics.has(HEAVY_DUCK_RELIC_ID) and p_self.owner != SIDE_SELF and speed > 1:
			speed = 1
	var banned_row:= forbidden_row_for(side)
	var parent:= {}
	var dist:= {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if dist[cur] >= speed:
			continue
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS\
			or nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
				continue
			if phasing == 1:
				# 穿行：被占格可**路过**（照样记 dist/parent 让 BFS 继续），落点合法性另判
				if dist.has(nxt):
					continue
			elif dist.has(nxt) or (state.board.has(nxt) and nxt != freed):
				continue
			dist[nxt] = dist[cur] + 1
			if nxt.x == banned_row:
				continue
			parent[nxt] = cur
			queue.append(nxt)
	return parent


func move_path(src: Vector2i, dst: Vector2i, side: String) -> Array[Vector2i]:


	var par:= _move_bfs(src, side)
	# R111 穿行：BFS 允许「穿过」被占格（于是它们也在 parent 里）——
	# 但**落点**必须是空格，统一在这里拦。
	if state.board.has(dst) and dst != src:
		return []
	if not par.has(dst):
		return []
	var path: Array[Vector2i] = [dst]
	var cur: Vector2i = dst
	while cur != src:
		cur = par[cur]
		path.push_front(cur)
	return path


func _reachable(cell: Vector2i, side: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c: Vector2i in _move_bfs(cell, side).keys():
		# 穿行会把「路过的被占格」也记进来 —— 那不是合法落点，要剔除。
		if state.board.has(c) and c != cell:
			continue
		result.append(c)
	return result


func _reachable_with(start: Vector2i, freed: Vector2i, side: String, 
		speed_override:= -1, phasing:= -1) -> Array[Vector2i]:


	var result: Array[Vector2i] = []
	for c: Vector2i in _move_bfs(start, side, freed, speed_override, phasing).keys():
		if state.board.has(c) and c != start:
			continue
		result.append(c)
	return result


func _rally_active(side: String) -> bool:
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(RALLY_TRAIT):
			return true
	return false


func attack_distance(from: Vector2i, to: Vector2i, side: String, card: CardData) -> int:


	if card == null or not _rally_active(side):
		return manhattan(from, to)
	# 群起攻之（新效果）：接通单位攻击不计算距离 → 全场可达
	if card.traits.has(CHARGE_TRAIT):
		if card.attack_range > 0:
			return 0
		return manhattan(from, to)
	return manhattan(from, to)


func eff_range(cell: Vector2i, c: CardData) -> int:
	## 攻击距离（R150）：卡面射程 + **只在场上有效**的加成（赫菲斯托斯的锻造成长）。
	## ⚠️ 统一走这个口 —— 直接读 `card.attack_range` 会漏掉场上加成，于是
	##    「AI 以为够得着、UI 说够不着」（或反过来）就有了温床。
	var p:= state.unit_at(cell)
	if p != null and p.card == c:
		return p.effective_range()
	return 0 if c == null else c.attack_range


func attack_targets(cell: Vector2i, side:= "", card: CardData = null) -> Array[Vector2i]:
	var s:= side
	var c:= card
	if s == "" or c == null:
		var p:= state.unit_at(cell)
		if p == null:
			return []
		if s == "":
			s = p.owner
		if c == null:
			c = p.card
	var result: Array[Vector2i] = []
	for other: Vector2i in state.board:
		var q: Placement = state.board[other]
		if q.owner != s and attack_distance(cell, other, s, c) <= eff_range(cell, c):
			result.append(other)
	return result


func hp_targets(cell: Vector2i, side:= SIDE_SELF, card: CardData = null) -> Array[Vector2i]:
	# R111 鸭子暗杀者：被动生效期间**不能攻击对方 HP** → 候选恒为空。
	# 放在这个唯一口上 = UI 的候选高亮与 AI 的目标选择**同时**被拦，不会各漏一处。
	var _hp_guard:= state.unit_at(cell)
	if _hp_guard != null and _assassin_passive(_hp_guard):
		return []




	var c:= card
	if c == null:
		var p:= state.unit_at(cell)
		if p == null:
			return []
		c = p.card
	var row:= back_row(SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF)
	var result: Array[Vector2i] = []
	for col in FieldState.BOARD_COLS:
		var t:= Vector2i(row, col)
		if state.board.has(t):
			continue
		if attack_distance(cell, t, side, c) <= eff_range(cell, c):
			result.append(t)
	return result


func move(src: Vector2i, dst: Vector2i, side:= SIDE_SELF, blink:= false) -> void :
	var p:= state.unit_at(src)
	if p == null or p.owner != side:
		_log("%s 上没有我方卡" % src)
		return
	if p.tapped:
		_log("%s 已横置，本回合不能移动" % p.card.card_name)
		return
	if p.rooted > 0:
		_log("%s 被禁足，本回合不能移动" % p.card.card_name)
		return
	if p.moved:



		if p.acts_left > 1 and not p.card.is_fort() and p.effective_speed() > 0:
			p.acts_left -= 1
			p.tapped = false
			p.moved = false
			_log("%s 消耗一次行动继续移动（还剩 %d 次行动）" % [
				p.card.card_name, p.acts_left])
		else:
			_log("%s 本回合已移动过，不能再移动" % p.card.card_name)
			return
	if p.card.is_fort():
		_log("工事不能移动")
		return
	var path: Array[Vector2i] = []
	if blink:
		# R111 鸭子暗杀者：消耗一次行动**闪现**到任意空格 ——
		# 不看移动速度、不看路径阻挡，只要求「落点是空格 + 不在对方后排行」。
		if dst == src:
			return
		if state.board.has(dst):
			_log("闪现落点 %s 已有单位" % dst)
			return
		if not unit_slot_allowed(dst, side):
			_log("不能移动到对方后排")
			return
		path.append(src)
		path.append(dst)
	else:
		if not unit_slot_allowed(dst, side):
			_log("不能移动到对方后排")
			return
		path = move_path(src, dst, side)
		if path.is_empty():
			_log("不能移动到 %s（超出移动速度或被阻挡）" % dst)
			return
	# 场地卡（R80）：**移动经过**路径上任何一格就触发，并**立刻停在这一格**。
	# 落点计算唯一口 = _field_block_index：只看「走过的这几格」，不看终点 ——
	# 于是「路过」和「停在上面」是同一个口径，玩家不需要区分。
	# ⚠️ move_path 的 path[0] 是**起点本身**，所以「本来就站在场地上的单位」不会被
	# 自己脚下的场地炸到（跳过起点的判断在 _field_block_index 里）。
	var stop_i:= _field_block_index(path)
	if stop_i >= 0:
		var stop_cell: Vector2i = path[stop_i]
		# 截断路径：动画 / 火墙都只演到被拦停的那一格，不许「先停后瞬移」。
		# 手动重建而不是 path.slice()：slice 返回无类型 Array，塞不回 Array[Vector2i]。
		var cut: Array[Vector2i] = []
		for k in stop_i + 1:
			cut.append(path[k])
		path = cut
		dst = stop_cell
	state.move_unit(src, dst)
	p.moved = true
	p.did_move = true   # 陷阱加强（R238）：物理上挪过格子 → 回合结束不再补踩脚下的陷阱
	if stop_i >= 0:
		_log("%s 移动 %s → %s（路上触发场地，移动停止）" % [
			p.card.card_name, src, dst])
	else:
		_log("%s 移动 %s → %s" % [p.card.card_name, src, dst])
	action.emit("move", {"src": src, "dst": dst, "card": p.card,
		"side": side, "path": path})
	# 场地卡（R74）：**移动进入**某格 → 该格场地效果立刻触发一次并消失。
	# 唯一触发点。挂在这里（移动成功之后）而不是 attack：场地不是单位、不能被打，
	# 也不该因为「有人在旁边打它」而触发。原本就在此格的敌人不触发（没移动就不会走到这里）。
	_field_trigger(dst, p)
	if p.health <= 0:
		return
	# 火墙术（9084）：移动路径上「进入过」燃烧的横行 → 被灼烧（不分敌我）
	_fire_wall_pass(path)
	if p.health <= 0:
		return

	if attack_targets(dst, side, p.card).is_empty()\
	and hp_targets(dst, side, p.card).is_empty():
		_tap(p, "移动后无攻击目标，放弃攻击")


func can_activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
	## 主动发动（熊 8004「回春」）：该单位尚未行动完（未横置）、带 BEAR_TRAIT，
	## 且这次在场还没发动过 → 可发动。
	var p:= state.unit_at(cell)
	if p == null or p.owner != side or p.tapped:
		return false
	if not p.card.traits.has(BEAR_TRAIT):
		return false
	return not p.ability_used


func activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
	## 主动发动：代替行动回复 BEAR_HEAL 点生命（不超过生命上限），之后横置。
	var p:= state.unit_at(cell)
	if not can_activate(cell, side):
		return false
	p.ability_used = true
	var before:= p.health
	p.health = mini(p.card.health, p.health + BEAR_HEAL)
	var gained:= p.health - before
	_log("%s 发动回春：回复 %d 点生命（当前 %d）" % [p.card.card_name, gained, p.health])
	action.emit("bear_heal", {"cell": cell, "amount": gained, "side": side,
			"name": p.card.card_name})
	_tap(p, "发动回春")
	return true


func _field_kind(c: CardData) -> String:
	## 场地词条识别（R74）：返回 "" 表示不是场地效果。
	## 判据是 **kind == 场地**（新卡种）而不是具体词条 —— 「是不是场地卡」是
	## 一次性判定的数据属性，不该靠"有几个词条要挨个试"。
	if not c.is_field():
		return ""
	for t: String in [TRAP_TRAIT, FROST_TRAP_TRAIT, FREEZE_TRAP_TRAIT, POISON_TRAP_TRAIT,
			PIERCE_TRAP_TRAIT, MASS_TRAP_TRAIT, DARK_TRAP_TRAIT, ROCKFALL_TRAP_TRAIT]:
		if c.traits.has(t):
			return t
	return ""


func _field_mastery(field_side: String, field_card: CardData) -> int:
	## 场地精通（9105，R74 由「陷阱精通」改名）：持有方效果区有它 →
	## 该方**场地**效果造成的伤害 +`TRAP_MASTERY_MULT`× 该场地卡的**原本费用**（R329：2× → 3×）。
	## 多张不叠加（与哈气同取一张）；按卡面原费算，不吃任何减费。
	var zone: Array[CardData] = state.effects if field_side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(TRAP_MASTERY_TRAIT):
			return TRAP_MASTERY_MULT * field_card.cost
	return 0


func _field_card_pool(side: String) -> Array[CardData]:
	## **「本角色奖励池里的场地卡」的唯一口**（R116 抽出）。
	## 原先有多处各抄了一份同样的三行（机关工坊 8015 供牌 / 警觉 9109 取场地 /
	## 捕兽大师 9126 亡语）—— 加新角色或改池子口径时极易漏改。
	## `side == SIDE_SELF` 取**当前角色**；敌方侧退化为**完整奖励池**
	## （敌方正常拿不到这些卡，这是既有口径）。
	## ⚠️ 返回的是**卡库共享实例** —— 进手前必须 `CardData.from_dict(...)` 复制；
	##    落格子那条路安全（`FieldState.set_field` 内部已复制）。
	var pool: Array[CardData] = []
	var cid := RunState.player_class if side == SIDE_SELF else ""
	for c: CardData in CardRepo.load_json().reward_pool_for(cid):
		if c.is_field():
			pool.append(c)
	return pool


func _trap_card_pool(side: String) -> Array[CardData]:
	## `_field_card_pool` 里**只留一次性触发的陷阱**（R116，捕兽大师 9126 用）。
	## 判据 = `_field_kind(c) != ""` —— 「是不是陷阱」这件事**只有 `_field_kind` 说了算**
	## （它列出的那 8 个 trait 就是引擎认的 8 张陷阱），持续型场地（清泉 / 维修间 /
	## 改造工厂）自然落空。**别再按卡名 / kind 自己判一遍**（两处判据迟早会分叉）。
	var out: Array[CardData] = []
	for c: CardData in _field_card_pool(side):
		if _field_kind(c) != "":
			out.append(c)
	return out


func _field_block_index(path: Array[Vector2i]) -> int:
	## **场地「经过即触发 + 立刻停止」的落点计算唯一口**（R80）。
	## 沿移动路径逐格找**第一个**挂着场地效果的格子，返回它在 path 里的下标；
	## 一路都没有场地则返回 -1（= 走完全程）。
	## 为什么按「路径」而不是按「终点」：用户口径是「敌人移动**经过**此格时触发」——
	## 只要路过就得算，所以 3 格移动撞上第 2 格的陷阱时，那一格才是真正的落点。
	## ⚠️ **path[0] 是起点本身**（`move_path` 的既有约定：返回「起点→终点」全链，
	## 动画与 `_fire_wall_pass` 都靠这个约定，见其 `range(1, path.size())`）。
	## 所以这里**从 1 开始扫**：站在场地上不代表「经过」它，动一下不该被自己脚下的
	## 场地炸到 —— 起点格必须跳过。
	## ⚠️ **持续型场地（清泉 8028）必须跳过**（R83）：它没有「踩上去就炸」的效果，
	## 敌人经过只该照常走过去。若不跳过，清泉会被白白触发掉 —— 这张牌等于废。
	for i in range(1, path.size()):
		var f: CardData = state.field_at(path[i])
		if f != null and not is_persistent_field(f):
			return i
	return -1


func _trap_still_tick(side: String) -> void :
	## **陷阱加强的唯一口（R238）：「原地不动」也会踩响脚下的陷阱。**
	## 用户口径：「如果敌人本回合原地不动，则会触发当前格子上的陷阱」。
	##
	## 与既有「移动经过即触发」互补 —— 那条挂在 `move()` 里（`_field_block_index`
	## 截断 + `_field_trigger` 结算），只管**动过**的单位：
	##   * 动过 → 走老路（走过哪格就炸哪格）；
	##   * 一步没挪 → 本方回合结束时，**脚下这一格**的陷阱立刻结算。
	##
	## 判据与边界（三条都不许省）：
	##   1. **只认陷阱** —— `_field_kind(card) != ""`（与 `_trap_card_pool` 同一判据）。
	##      清泉 / 维修间 / 改造工厂是持续型场地，有自己的 `_field_aura_tick`，
	##      在这里触发等于把它们白白消耗掉（等于废牌）。
	##   2. **只炸「别人埋的」** —— `field_owner` 与本方不同才算踩雷；自己埋的陷阱
	##      自己人站着不动不会自爆（陷阱是对敌的，用户口径也是「敌人」）。
	##   3. 「原地不动」看 `Placement.did_move`（**物理上没挪过格子**），**不看 `moved`**
	##      —— 后者是「移动权已用掉」，禁足 / 冰封的单位也会是 true，用它会漏掉
	##      「被禁足原地罚站的敌人」这一类最该踩雷的。
	##
	## 结算一律走**唯一口 `_field_trigger`**：伤害数值 / 控制 / 摘牌 / 场地精通 /
	## 暗影狩猎记号全部复用，这里只负责回答「**谁来踩、什么时候踩**」。
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.did_move:
			continue
		var f: CardData = state.field_at(cell)
		if f == null or _field_kind(f) == "":
			continue
		if str(state.field_owner.get(cell, p.owner)) == side:
			continue   # 自己埋的陷阱不炸自己人
		cells.append(cell)
	cells.sort()   # 结算顺序稳定（回放 / 测试可复现）；与 _breach_tick 同一手法
	for c2: Vector2i in cells:
		if over:
			return
		var q: Placement = state.unit_at(c2)
		if q == null or q.owner != side or q.did_move:
			continue
		var f2: CardData = state.field_at(c2)
		if f2 == null:
			continue   # 前面的格子结算时把它顶掉 / 摘掉了（同一回合多格时才会遇到）
		_log("%s 本回合原地不动 → 踩响脚下的 %s" % [q.card.card_name, f2.card_name])
		_field_trigger(c2, q)


func _field_trigger(cell: Vector2i, mover: Placement) -> void :
	## **场地卡触发的唯一口**（R74；R80 扩为「经过即触发」）：挂在 `move()` 里
	## 「移动成功之后」，而落点已由 `_field_block_index` 截断到被触发的那一格。
	## 语义（用户口径）：
	##   * **移动路径上经过**此格即触发（不再要求「终点停在这里」，见 R80）；
	##     原本就站在该格上的敌人**不触发**（不在这段 path 里）；
	##   * 触发一次后**该格场地消失**（一次性）。**先摘牌再结算** ——
	##     场地效果里若再触发别的场地效果，也不会重复触发同一格；
	##   * 场地不是单位 → 伤害/控制**打给移动进来的那个单位**（敌方踩自己的场地= 自己吃）；
	##   * 场地精通加成照旧吃。
	if mover == null or state.field_at(cell) == null:
		return
	# 持续型场地（清泉 8028，R83）**永不触发**：它在「自己回合结束时」结算，不在这里。
	# 这道防御是必需的 —— 落点截断已经跳过它了，但 `_field_trigger` 还会被 `remote_move`
	# 等旁路调用到，漏一道就等于给清泉开了个「随时被消耗」的口子。
	if is_persistent_field(state.field_at(cell)):
		return
	# 场地精通看的是**场地主人的**效果区（敌人踩了我方场地，加成按我方的算）——
	# 所以**先读 owner 再 clear_field**（clear 会把 field_owner 一起擦掉）。
	var owner_side := str(state.field_owner.get(cell, mover.owner))
	var card := state.clear_field(cell)
	# 暗影狩猎（R74 口径）：踩场地 = 「触发场地」→ 记全局半回合号供上回合判定
	mover.trap_trig_turn = turn_total
	# R341 鹿首标本（6049）：**我方**的陷阱 / 场地伤害同样按层 +N。
	# 判据看场地主人（`owner_side`）—— 敌人踩响我方的场地，加成按我方的算（与场地精通同口径）。
	var bonus:= _field_mastery(owner_side, card)\
			+ (deer_bonus if owner_side == SIDE_SELF else 0)
	action.emit("field_trigger", {"cell": cell, "card": card,
		"name": mover.card.card_name, "side": mover.owner})
	if card.traits.has(TRAP_TRAIT):
		_field_explode(cell, card, bonus)
	elif mover.health > 0:
		# 其余几种都是「打给踩上来的那一个单位」；他若已被别的东西打死就不追伤
		if card.traits.has(MASS_TRAP_TRAIT):
			# 巨物陷阱（8017，R217 改数值）：10 + 踩上来的那个单位**当前攻击力×2**，
			# 打给那一个（不分敌我）。读 effective_power() → 增减益/成长/改造一起算进去。
			var g_atk:= mover.effective_power()
			var g_dmg:= _hit_unit(mover, MASS_TRAP_DMG + g_atk * MASS_TRAP_ATK_MUL + bonus,
					"巨物陷阱")
			action.emit("trap_hit", {"cell": _cell_of(mover), "amount": g_dmg,
					"kind": "巨物", "name": mover.card.card_name, "atk": g_atk})
			_log("%s 踩到巨物陷阱：受到 %d 点伤害（%d + %d×%d%s，剩余 %d）" % [
				mover.card.card_name, g_dmg, MASS_TRAP_DMG, g_atk, MASS_TRAP_ATK_MUL,
				"（+场地精通 %d）" % bonus if bonus > 0 else "", mover.health])
		elif card.traits.has(FROST_TRAP_TRAIT):
			var f_dmg:= _hit_unit(mover, FROST_TRAP_DMG + bonus, "冰霜陷阱")
			action.emit("trap_hit", {"cell": _cell_of(mover), "amount": f_dmg,
					"kind": "冰霜", "name": mover.card.card_name})
			if mover.health > 0:
				mover.rooted = 1   # 下回合生效（reset_units 1→2），生效回合结束解除
				_log("%s 踩到冰霜场地：下回合不能移动（仍可攻击）" % mover.card.card_name)
		elif card.traits.has(FREEZE_TRAP_TRAIT):
			var z_dmg:= _hit_unit(mover, FREEZE_TRAP_DMG + bonus, "冻结陷阱")
			action.emit("trap_hit", {"cell": _cell_of(mover), "amount": z_dmg,
				"kind": "冻结", "name": mover.card.card_name})
			if mover.health > 0:
				# 复用寒冰箭既有机制：下回合开始横置不重置（不能行动）
				_apply_frozen(mover, "冻结场地")
		elif card.traits.has(POISON_TRAP_TRAIT):
			mover.poison_left = POISON_TURNS
			mover.poison_dmg = POISON_DMG + bonus
			_log("%s 踩到剧毒场地：每回合 %d 点伤害，持续 %d 回合" % [
				mover.card.card_name, mover.poison_dmg, POISON_TURNS])
			action.emit("poison", {"cell": _cell_of(mover), "amount": 0,
				"dmg": mover.poison_dmg, "name": mover.card.card_name,
				"left": POISON_TURNS, "apply": true})
		elif card.traits.has(PIERCE_TRAP_TRAIT):
			var pr_dmg:= _hit_unit(mover, PIERCE_TRAP_DMG + bonus, "穿刺陷阱")
			_log("穿刺场地：%s 受到 %d 点伤害" % [mover.card.card_name, pr_dmg])
			action.emit("trap_hit", {"cell": _cell_of(mover), "amount": pr_dmg,
				"kind": "穿刺", "name": mover.card.card_name})
		elif card.traits.has(ROCKFALL_TRAP_TRAIT):
			# 落石陷阱（9159，R248）：29 伤 + 击杀后溢出不丢弃（「践踏」）
			_rockfall_trap(cell, mover, bonus)
		elif card.traits.has(DARK_TRAP_TRAIT):
			# 黑暗陷阱（8063，R105）：**不造成伤害**，只让踩上来的那个敌人
			# **本回合攻击时力量 -1**（atk_debuff + debuff_stage=1，与敲晕同源）。
			mover.atk_debuff += DARK_TRAP_DEBUFF
			mover.debuff_stage = 1
			_log("黑暗场地：%s 力量 -%d（当前 %d），本回合内有效" % [
					mover.card.card_name, DARK_TRAP_DEBUFF, mover.effective_power()])
			action.emit("dark_trap", {"cell": _cell_of(mover),
				"amount": DARK_TRAP_DEBUFF, "power": mover.effective_power(),
				"name": mover.card.card_name})
	_destroy_dead()


func _field_explode(center: Vector2i, card: CardData, bonus: int) -> void :
	## 爆炸场地（8011）：十字范围造成 TRAP_DMG(+bonus) 点伤害，**不分敌我**。
	## **中心格也算** —— 场地不是单位、没有占位，所以「踩上来的那个人」就站在中心，
	## 他必然吃自己踩的那一下（这正是「移动到该格才触发」这个新语义的核心）。
	## 只炸场上的单位，空格不直击 HP；非技能结算 → 不吃魔法塔加成 / 法术免疫
	## （与爆炎鸭亡语 _death_blast 同一规则），被炸死单位的后排溢出走 _destroy_dead 通用规则。
	## 特效复用「blast」（爆炎鸭亡语同款）—— 同效果必须同特效。
	var cells: Array[Vector2i] = [center]      # 中心格 = 刚踩上来的那个
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Vector2i = center + d
		if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
			continue
		cells.append(c)
	var hits:= 0
	for c2: Vector2i in cells:
		var q:= state.unit_at(c2)
		if q == null:
			continue
		_hit_unit(q, TRAP_DMG + bonus, "爆炸场地")
		hits += 1
	_destroy_dead()
	_log("爆炸场地：十字 %d 格各 %d 点伤害，命中 %d 个单位（不分敌我）"
		% [cells.size(), TRAP_DMG + bonus, hits])
	action.emit("blast", {"center": center, "cells": cells, "amount": TRAP_DMG + bonus,
			"card": card})


func _rockfall_trap(cell: Vector2i, mover: Placement, bonus: int) -> void :
		## 落石陷阱（9159，R248）：对踩上来的那个单位造成 ROCKFALL_TRAP_DMG(+bonus) 点伤害；
		## **这一下若将其击杀，溢出的伤害不丢弃**（用户口径「践踏」）—— 沿同列继续碾压
		## 踩雷者**同侧**的单位，打穿整列后剩余伤害漏到该方 HP。
		## 方向 = 踩雷者所在方的**后排**（与 R225 攻击践踏「冲向 defender 后排」同口径），
		## 两个 `_field_trigger` 调用点（移动经过 / 原地不动）都走这里，语义一致。
		var dmg:= ROCKFALL_TRAP_DMG + bonus
		var hp_before:= mover.health
		var dealt:= _hit_unit(mover, dmg, "落石陷阱")
		action.emit("trap_hit", {"cell": cell, "amount": dealt,
				"kind": "落石", "name": mover.card.card_name})
		if mover.health > 0:
			_log("落石陷阱：%s 受到 %d 点伤害（剩余 %d）" % [
				mover.card.card_name, dealt, mover.health])
			return
		_log("落石陷阱：%s 被落石砸毙（%d 点伤害，生命 %d）" % [
				mover.card.card_name, dealt, hp_before])
		# 击杀不记功：陷阱格上没有「攻击者」→ 置 -1（否则可能误记给本回合早先打过它的单位）
		mover.last_hit_by = Vector2i(-1, -1)
		_destroy(cell)
		var overflow:= dealt - maxi(hp_before, 0)
		if overflow <= 0:
			return
		var res: Array = _rockfall_overflow(cell, mover.owner, overflow)
		overflow = int(res[0])
		if overflow > 0:
			var pierced_name: String = str(res[1])
			if pierced_name == "":
				pierced_name = mover.card.card_name
			_log("落石践踏：%d 点打穿整列 → 漏到 %s HP" % [
				overflow, "敌方" if mover.owner == SIDE_OPPONENT else "我方"])
			# R145 口径：先结算、再播出（amount 报实际掉血）
			_damage_player(mover.owner, overflow, "落石践踏")
			action.emit("trample", {"side": mover.owner, "amount": _last_hp_damage,
				"dst": cell, "atk_name": "落石陷阱", "def_name": pierced_name})

func _rockfall_overflow(from_cell: Vector2i, side: String, remaining: int) -> Array:
		## 落石陷阱的践踏链（R248）—— `_trample_chain` 的**陷阱版**：同列、同侧、逐个击穿。
		## 与攻击践踏只有两处差异：方向取「踩雷者所在方的**后排**」（不是远离攻击者），
		## 伤害来源记「落石陷阱」（is_attack = false，效果伤害而非普通攻击）。
		## 返回 [剩余伤害, 最后被击穿的单位名]：没穿到人 → 名字空串；打穿整列 → 调用方漏 HP。
		## ⚠️ 坐标是 `Vector2i(行, 列)` —— 同列 = 同一个 `y`，行号朝 `back_row(side)` 推；
		##    踩雷者已在本方后排（没有更深的同侧格）时公式自然给出反方向（朝对方半场推）。
		## ⚠️ 只认 `side` 的单位（同列的对方单位不会被误伤），与 `_trample_chain` 同一判据。
		if remaining <= 0:
			return [0, ""]
		var step: int = -1 if back_row(side) < from_cell.x else 1
		var pierced: String = ""
		var cell: Vector2i = from_cell
		while remaining > 0:
			cell = Vector2i(cell.x + step, cell.y)
			if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS:
				break                  # 这一列走到底了 → 剩下的直击 HP
			var next: Placement = state.unit_at(cell)
			if next == null or next.owner != side:
				continue               # 空格 / 同列的对方单位 → 继续往深处找
			var hp_before: int = next.health
			next.last_hit_by = Vector2i(-1, -1)   # 同上：落石击杀不记功给单位
			var dmg: int = _hit_unit(next, remaining, "落石陷阱")
			_log("落石践踏：%d 点沿同列传给 %s（造成 %d 点伤害）" % [
				remaining, next.card.card_name, dmg])
			action.emit("trample_hit", {"cell": cell, "side": next.owner, "amount": dmg,
				"name": next.card.card_name, "from": from_cell, "atk_name": "落石陷阱"})
			pierced = next.card.card_name
			if next.health > 0:
				return [0, pierced]    # 没打死 → 溢出到此为止（它吃满）
			var carry: int = dmg - maxi(hp_before, 0)
			_destroy(cell)
			remaining = carry
		return [maxi(remaining, 0), pierced]

func _poison_tick(side: String) -> void :
	## 中毒（剧毒陷阱，R51）：在受害者所属方的回合开始结算一次 —— 每跳 poison_dmg
	## （挂毒瞬间锁定，含陷阱精通加成），次数扣到 0 为止。
	## 毒死的单位走 _destroy_dead 通用收尸（后排溢出同样生效）；无随机 → 不影响回放复现。
	var ticked:= 0
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.poison_left <= 0:
			continue
		p.poison_left -= 1
		var dmg:= _hit_unit(p, p.poison_dmg, "中毒")
		ticked += 1
		_log("%s 中毒结算：-%d（还剩 %d 次）" % [p.card.card_name, dmg, p.poison_left])
		action.emit("poison", {"cell": cell, "amount": dmg,
				"name": p.card.card_name, "left": p.poison_left, "apply": false})
	if ticked > 0:
		_destroy_dead()


func _field_aura_tick(side: String) -> void :
	## **持续型场地**的回合结束结算（R83 清泉 8028 / R88 维修间 8036 + 改造工厂 8037）
	## —— 唯一口，挂在 `end_turn()`。
	##
	## 口径（用户原话「在此格的单位自己回合结束时回复 2 点生命」）：
	##   * 只结算**属于 side 这一方的**单位 —— 「自己回合」= 它自己阵营的回合；
	##   * **清泉是「双」**（trait「场地生效·双」）：敌方单位在敌方回合结束时同样回血；
	##   * **维修间 / 改造工厂是「友」**（trait「场地生效·友」）：只有**我方**单位受益，
	##     敌方单位站上去既不回血也不被改造（敌方回合结束时它们只是「不是自己人」）；
	##   * 站在上面的是哪个单位都行（盟友 / 工事），不看种类；
	##   * 格子空着、或站着的不是单位（场地本身不是单位）→ 无事发生，**场地不受影响**。
	##
	## ⚠️ **R88：这里从「`f.id == FOUNTAIN_ID` 白名单」改成按 trait 分派**。
	## 原来只有清泉一张，白名单够用；加了维修间（同一族，只是 aim 不同）之后，
	## 白名单会让第二张持续型场地**直接被忽略**（静默失效，很难查）。
	## 现在：**持续型 → 读 `field_heal`（>0 就回血）+ 读 trait「持续改造」（有就加攻加血）**，
	## 加新的持续型场地只要写对 trait / 填 `field_heal`，引擎一行都不用改。
	##
	## 回血上限读 `p.card.health`（**当前**的卡面上限）—— 这样被「升级」改造过的单位
	## 血量上限更高，清泉自然能帮它回更多；上限被改造抬高这件事离场会还原。
	## 满血单位跳过回血（避免每回合刷无意义的飘字）—— 但**改造不跳过**（它不是回血）。
	var healed := 0
	var upgraded := 0
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side:
			continue
		var f: CardData = state.field_at(cell)
		if f == null or not is_persistent_field(f):
			continue
		# 「友」生效的持续场地（维修间 / 改造工厂）只对**我方**单位生效。
		# 清泉是「双」→ 不受这条限制（它的 trait 是 场地生效·双）。
		if field_aim(f) == FIELD_AIM_ALLY and side != SIDE_SELF:
			continue
		# ① 治疗：读卡面 field_heal（清泉 2 / 维修间 4 / 其它 0 = 不回血）
		var heal: int = f.field_heal
		if heal > 0 and p.health < p.card.health:
			var before: int = p.health
			p.health = mini(p.card.health, p.health + heal)
			var got: int = p.health - before
			healed += 1
			_log("%s：%s 回复 %d 点生命（%d / %d）" % [
				p.card.card_name, f.card_name, got, p.health, p.card.health])
			action.emit("fountain", {"cell": cell, "card": p.card, "amount": got,
				"hp": p.health, "max_hp": p.card.health, "side": side,
				"field": f.card_name})
		# ② 持续改造（改造工厂 8037）：每回合一次「改造」+1 力 / +1 血，**无限叠加**。
		# 走 `upgrade_atk` / `upgrade_hp` —— 于是**离场自动还原**（`_card_leaving_field`
		# 已经在还原这两个字段），不需要额外收尾。
		# ⚠️ 卡库是**共享实例**：直接改 `p.card.health` 会连卡库那份一起改（跨 run 泄漏），
		# 所以动手前先换成**独立副本** —— 与 `_upgrade_unit` 同一套纪律（那里也是无条件复制：
		# 哪怕本来就是副本，多一次 from_dict 也不影响正确性，比判断「是不是共享实例」省心）。
		var fac_atk: int = 0
		var fac_hp: int = 0
		if f.traits.has(PERSIST_UPGRADE_TRAIT):
			p.card = CardData.from_dict(p.card.to_dict())
			p.card.traits = (p.card.traits as Array).duplicate()
			# R120：① 改造奖励走**唯一口**（素体 +1 血 / 侦察塔不加攻）；
			#       ② **补记一层 `upgrade_stacks`** —— 以前这里不加层，于是「改造工厂」
			#          写着「每回合一次改造」却不给侦察塔光环层（用户报的缺陷之一）。
			fac_atk = _upgrade_atk_gain(p.card, UPGRADE_FACTORY_ATK)
			fac_hp = _upgrade_hp_gain(p.card, UPGRADE_FACTORY_HP)
			p.upgrade_atk += fac_atk
			p.upgrade_hp += fac_hp
			_add_upgrade_stack(p)   # R274：层数唯一口
			p.card.health += fac_hp
			p.health += fac_hp
			upgraded += 1
			_log("%s：%s 改造 +%d 力 / +%d 血（第 %d 层，%d 攻 / %d 血）" % [
				p.card.card_name, f.card_name, fac_atk, fac_hp, p.upgrade_stacks,
				p.effective_power(), p.health])
			action.emit("upgrade", {"cell": cell, "card": p.card, "placement": p,
				"atk": fac_atk, "hp": fac_hp, "stacks": p.upgrade_stacks,
				"field": f.card_name})
		# 「模仿者」8043（R92）：改造工厂给的 +1/+1 也是一次改造（用户口径）→
		# 接通的模仿者同步获得 +1 力 / +1 血。每回合触发一次，**可无限叠加**。
		_mimic_relay(p, fac_atk, fac_hp)
		# R279：工厂给的也是**改造** → 必须过统一后置口。以前这里只 `_add_upgrade_stack`，
		# 于是「每次被改造时」那一族（改造攻程 榴弹击手 / 改造抽牌 机器鸟 /
		# 废弃机器人）站在改造工厂上完全不响应 —— 用户报的就是榴弹击手加不了射程。
		if f.traits.has(PERSIST_UPGRADE_TRAIT):
			_on_unit_upgraded(p)
	if healed > 0:
		_log("持续型场地：%d 个单位在自己回合结束时回复了生命" % healed)
	if upgraded > 0:
		_inspire_tick()   # R300 激发：改造工厂一次结算改多个单位 → 只算一次
		_log("改造工厂：%d 个单位获得改造（每回合 +%d 力 / +%d 血，可无限叠）" % [
			upgraded, UPGRADE_FACTORY_ATK, UPGRADE_FACTORY_HP])


func _sleep_tick(side: String) -> void :
	## 沉睡（恶魔鸭 9116）：**回合递减口**（R122 用户口径「沉睡应该随着回合减少」）。
	## 本方回合结束时，本方还在睡的单位 sleep_left -1；减到 0 就此醒来（下一回合可行动）。
	## ⚠️ 与 R76 的「受伤递减口」`_demon_duck_hurt` **并存**，各减各的：
	##   · 只挨打不过回合 → 挨够 SLEEP_TURNS 下就醒（R76 保留的决策：打它 = 帮它提前醒）；
	##   · 只过回合不挨打 → 过满 SLEEP_TURNS 个自己的回合也一定会醒
	##     （这是 R122 修掉的边界：原来没人打它就永远站着不动）。
	## 两个口减到 0 都走同一句话术（「醒来」），所以不会出现「减到 -1 还睡着」。
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.sleep_left <= 0:
			continue
		p.sleep_left -= 1
		if p.sleep_left <= 0:
			_log("%s 睡满了本轮，从沉睡中醒来（下一回合可以行动）" % p.card.card_name)
			action.emit("wake", {"cell": cell, "card": p.card, "side": side,
					"hurt": false, "awake": true})
		else:
			_log("%s 仍在沉睡（还剩 %d 点：回合结束 -1，挨打也 -1）" % [
					p.card.card_name, p.sleep_left])


func _demon_duck_hurt(p: Placement, cell: Vector2i) -> void :
	## 恶魔鸭家族的受伤反应：**受击判定的唯一口**（挂在 _hit_unit 里，
	## 所以普通攻击 / 技能 / 效果 / 直伤全都算，不只是普通攻击）。
	## 按 trait 分派两种互斥的「挨打变强」：
	##   沉睡（9116 恶魔鸭）→ 还在睡：sleep_left -1（受伤口；与回合口 _sleep_tick 并存）；
	##                              已醒：end_atk +1（**永久**，不受 GROW_CAP 封顶）。
	##   复仇（9118 恶魔鸭（复仇））→ **本回合** atk_buff_turn +1（可叠加，回合开始清零）。
	## 两者都只认 trait，所以任何带该 trait 的单位都吃这套。
	if p.card.traits.has(REVENGE_TRAIT):
		_revenge_hurt(p, cell)
		return
	if not p.card.traits.has(FieldState.SLEEP_TRAIT):
		return
	if p.sleep_left > 0:
		p.sleep_left -= 1
		# 受伤口：每次受伤 -1，减到 0 **立刻**恢复行动（R76 口径保留）。
		# R122 补上「回合口」（_sleep_tick 也会 -1）—— 两个口并存，谁先减到 0 谁让它醒。
		if p.sleep_left <= 0:
			_log("%s 被打够次数，从沉睡中醒来（立即可以行动）" % p.card.card_name)
			action.emit("wake", {"cell": cell, "card": p.card, "side": p.owner,
				"hurt": true, "awake": true})
		else:
			_log("%s 被击中：沉睡 -1（还剩 %d 次挨打）" % [p.card.card_name, p.sleep_left])
			action.emit("wake", {"cell": cell, "card": p.card, "side": p.owner,
				"hurt": true, "awake": false})
	else:
		p.end_atk += DEMON_DUCK_ATK_GAIN
		_log("%s 暴怒：力量永久 +%d（当前 %d）" % [
			p.card.card_name, DEMON_DUCK_ATK_GAIN, p.effective_power()])
		action.emit("demon_rage", {"cell": cell, "card": p.card,
			"amount": DEMON_DUCK_ATK_GAIN, "power": p.effective_power()})


func _revenge_hurt(p: Placement, cell: Vector2i) -> void :
	## 恶魔鸭（复仇）9118：每次受伤**同时**吃两条挨打变强（R77 补回被丢掉的那条）：
	##   ① `atk_buff_turn` +1 —— **本回合**力量，可叠加（用 end_turn 的清零天然实现「本回合」）；
	##   ② `end_atk` +1 —— **永久**力量，与恶魔鸭 9116 的 DEMON_DUCK_ATK_GAIN 同一条通路。
	## R76 只给了 ①，把恶魔鸭「越打越强、越打越疼」的手感整个丢了 —— 现在两条都在。
	p.atk_buff_turn += REVENGE_ATK_PER_HIT
	p.end_atk += REVENGE_END_ATK_PER_HIT
	var total := p.effective_power()
	_log("%s 复仇：每次受伤本回合 +%d、永久 +%d（累计本回合 +%d，力量 %d）" % [
		p.card.card_name, REVENGE_ATK_PER_HIT, REVENGE_END_ATK_PER_HIT,
		p.atk_buff_turn, total])
	action.emit("demon_revenge", {"cell": cell, "card": p.card,
		"amount": REVENGE_ATK_PER_HIT, "end_amount": REVENGE_END_ATK_PER_HIT,
		"stacked": p.atk_buff_turn, "power": total})


func _workshop_supply(side: String) -> void :
	## 机关工坊（8015，R52 起是「陷阱工坊」；R76 供给口径由工事改为**场地**）：
	## 回合开始时，每座本方的机关工坊随机把一张
	## **本角色奖励池**（敌方侧退化为完整奖励池）里的**场地卡**加入手卡；手满则不加入。
	## 随机走引擎 rng；库内共享实例 → 必须复制后再进手。
	var workshops:= 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(WORKSHOP_TRAIT):
			workshops += 1
	if workshops <= 0:
		return
	# R76：供给口径从「工事」改成「场地」（机关工坊本身仍是工事，只是它造的是场地）。
	# R116：池子构造抽成唯一口 `_field_card_pool`（原先 4 处各抄一份）。
	var pool := _field_card_pool(side)
	if pool.is_empty():
		_log("机关工坊：奖励池中没有场地卡")
		return
	for i in workshops:
		var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		var copy:= CardData.from_dict(pick.to_dict())
		# R299：手牌满 → 直接进弃牌区（不再「本次不加入」白丢）
		_grant_to_hand(copy, "陷阱工坊")
		_log("机关工坊：随机一张场地「%s」进入手卡" % copy.card_name)
		action.emit("blessing", {"count": 1})


func _end_turn_surplus(side: String) -> void :
	## 「回合结束 · 剩余费用 / 已花费用」系列六张卡的**唯一结算入口**
	## （end_turn 里在费用清零之前调用）。结算顺序是**规则的一部分**，按序：
	##   0) 黑暗领主 8021：在场每一个 → 本方费用 +5（**优先结算**，见下）；
	##   1) 重读剩余费用 left（已含黑暗领主加的 5 点）；
	##   2) 地狱猫 8019 / 鲜血堡垒 8020：场上本方每一个 → 力量 +left×N、生命 +left×M（永久）；
	##   3) 活力转移 9110：left/2（向下取整）结转到**下个回合开始**发放
	##      （state.self_next_energy / opp_next_energy，_begin_turn 发放后清零；多张不叠加）；
	##   4) 暗影之刃 9111：X = **已花掉**的费用（state.*_energy_spent）→ 随机敌人受 X 伤
	##      （与上面几张口径相反：这张卡奖励的是花钱）；
	##   5) 暗影锁链 9112：left/3（向下取整）次，每次把随机一个敌人击退 2 格。
	## 「优先结算」= 第 0 步先跑：黑暗领主给的 5 点会被第 1~5 步一起读到。
	_dark_lord_energy(side)
	var left := state.energy_of(side)
	# 蓄势（9156，R232）：回合结束、费用清零之前 —— 手卡里每张「蓄势」按 left 涨伤害。
	if side == SIDE_SELF:
		_charge_up_grow(left)
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	# 暗影之刃读的是**已花掉**的费用，与 left 无关 —— 必须放在 left<=0 的早退**之前**，
	# 否则「钱刚好花光」这种最常见的情况会把它一并跳过。
	if _zone_has(zone, DARK_BLADE_TRAIT):
		var spent := state.energy_spent_of(side)
		if spent <= 0:
			_log("暗影之刃：本回合没有花掉费用 → 效果落空")
		else:
			_blade_strike(side, spent)
	if left <= 0:
		if _zone_has(zone, DARK_CHAIN_TRAIT):
			_log("暗影锁链：剩余费用 0，不足 %d 点 → 本次不触发" % DARK_CHAIN_COST)
		return
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side:
			continue
		# 夜蚀8062（R103）：**回复**剩余费用那么多点生命 —— 与上面几张的「永久加血」不同，
		# 这里只是把已损失的血补回来，上限仍读卡面 health（不满血才结算，满血跳过不刷噪声）。
		if p.card.traits.has(NIGHT_EROSION_TRAIT):
			_night_erosion_heal(p, left, side)
			continue
		var atk_gain := 0
		var hp_gain := 0
		if p.card.traits.has(HELL_CAT_TRAIT):
			atk_gain = left * HELL_CAT_ATK
			hp_gain = left * HELL_CAT_HP
		elif p.card.traits.has(BLOOD_FORT_TRAIT):
			atk_gain = left * BLOOD_FORT_ATK
			hp_gain = left * BLOOD_FORT_HP
		if atk_gain <= 0 and hp_gain <= 0:
			continue
		p.end_atk += atk_gain
		p.health += hp_gain
		_log("%s：剩余费用 %d → 力量 +%d、生命 +%d（现 %d/%d）" % [
			p.card.card_name, left, atk_gain, hp_gain,
			p.effective_power(), p.health])
		action.emit("surplus", {"cell": cell, "card": p.card, "left": left,
				"atk": atk_gain, "hp": hp_gain, "side": side})

	# 活力转移：效果区里有就算（多张不叠加 —— 与自愈/ 魔力核心同一口径）。
	if _zone_has(zone, VITALITY_TRAIT):
		var moved := left / VITALITY_COST
		if moved <= 0:
			_log("活力转移：剩余费用 %d，不足 %d 点 → 本次不结转" % [left, VITALITY_COST])
		else:
			if side == SIDE_SELF:
				state.self_next_energy += moved
			else:
				state.opp_next_energy += moved
			_log("活力转移：剩余费用 %d → 下回合开始时费用 +%d" % [left, moved])

	# 暗影锁链：剩余费用每 3 点 → 把随机一个敌人击退 2 格（**只有效果区有这张卡才触发**）。
	if _zone_has(zone, DARK_CHAIN_TRAIT):
		_dark_chain_pulls(side, left / DARK_CHAIN_COST)

	# 黑暗扩散 9113：剩余费用每 1 点 → 对所有敌人造成 2 点伤害。
	# 放在成长/结转**之后**（同一个 left，不受前面影响），击退之后。
	if _zone_has(zone, DARK_SPREAD_TRAIT):
		_dark_spread_strike(side, left)


func _attack_gain_energy(side: String, attacker: Placement) -> void :
	## 地狱咏唱者 8022 / 黑暗祭坛 8023（trait 咏唱者 / 祭坛）：**攻击时**回复
	## ATTACK_GAIN_ENERGY 点费用。挂在 attack() 与 attack_hp() 尾部 —— 只有真正打出去
	## （通过距离 / 嘲讽校验）才会走到这里，被拒绝的非法攻击不算「攻击时」。
	var gain := 0
	if attacker.card.traits.has(CHANTER_TRAIT) or attacker.card.traits.has(ALTAR_TRAIT):
		gain = ATTACK_GAIN_ENERGY
	if gain <= 0:
		return
	if side == SIDE_SELF:
		state.energy += gain
	else:
		state.opp_energy += gain
	_log("%s 攻击时：费用 +%d（当前 %d）" % [
		attacker.card.card_name, gain, state.energy_of(side)])
	action.emit("attack_energy", {"name": attacker.card.card_name,
			"amount": gain, "side": side})


func _dark_spread_strike(side: String, left: int) -> void :
	## 黑暗扩散 9113（R57）：剩余费用每 1 点 → 对**所有**敌人造成 2 点伤害。
	## 走通用 _hit_unit（不套 _spell_dmg：这是效果卡不是技能）+ _destroy_dead；
	## 后排单位被打破时按通用溢出规则漏到玩家 HP（与其他 AoE 同一口径）。
	if left <= 0:
		_log("黑暗扩散：没有剩余费用 → 本次不结算")
		return
	var dmg := left * DARK_SPREAD_PER_ENERGY
	var foes: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.unit_at(cell)
		if q != null and q.owner != side and q.health > 0:
			foes.append(cell)
	if foes.is_empty():
		_log("黑暗扩散：场上没有敌人，效果落空（剩余费用 %d）" % left)
		return
	var total := 0
	_begin_hp_once()
	for cell: Vector2i in foes:
		var q: Placement = state.unit_at(cell)
		if q == null or q.health <= 0:
			continue
		_hit_unit(q, dmg, "黑暗扩散")
		total += 1
	_destroy_dead()
	_end_hp_once()
	_log("黑暗扩散：剩余费用 %d → 对 %d 个敌人各造成 %d 点伤害"
			% [left, total, dmg])
	action.emit("dark_spread", {"dmg": dmg, "left": left, "hits": total, "side": side})


func _night_erosion_heal(p: Placement, left: int, side: String) -> void :
	## 夜蚀 8062（R103，2 费史诗盟友 2/8/程1/速1）：自己回合结束时，
	## 回复 X = **剩余费用** 点生命值。
	##
	## 口径与 _regen_tick / _charge_tick 严格一致：
	##   * 剩余费用为 0 → 不结算（不刷「回复 0」的噪声日志）；
	##   * **满血跳过** —— 回复不是成长，满血时不该有任何表现；
	##   * 上限读 p.card.health（当前卡面上限，被改造过的上限更高 → 能回更多），
	##     用 mini 夹住，绝不越界。
	## 注意这里**不改 p.card.health 也不加 end_atk**：回复只动当前血量 p.health，
	## 所以这张卡不会像地狱猫那样永久堆血上限。
	if left <= 0:
		_log("%s：剩余费用 0 → 本次不回复" % p.card.card_name)
		return
	if p.health >= p.card.health:
		return     # 满血：静默跳过
	var amount: int = mini(left * NIGHT_EROSION_PER_ENERGY,
			p.card.health - p.health)
	if amount <= 0:
		return
	p.health += amount
	_log("%s：剩余费用 %d → 回复 %d 点生命（%d / %d）" % [
			p.card.card_name, left, amount, p.health, p.card.health])
	action.emit("night_erosion", {"cell": _cell_of(p), "card": p.card,
			"amount": amount, "hp": p.health, "max_hp": p.card.health,
			"left": left, "side": side})


func _endless_dark(side: String) -> void :
	## 无尽黑暗 9114（R70 改）：**每回合抽牌之后**，玩家**强制从手牌里选 1 张弃掉**
	##（**不能不选**），然后获得 2 点费用。挂在 _begin_turn 抽牌分支之后
	##（选的就是本回合刚抽到的牌）。
	## R70 变化：原来这里是「**随机**弃 1 张」；现在改成开选牌面板，由玩家点一张。
	##   - 手牌为空 → 没有可选的牌 → **本回合不弃也不给费用**（不给白拿的 2 费）。
	##   - 敌方侧没有真实手牌（只记张数）→ 对称保留：只结算费用那半边，不开面板。
	##   - 效果区多张不叠加（只触发一次）。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	if not _zone_has(zone, ENDLESS_DARK_TRAIT):
		return
	if side != SIDE_SELF:
		# 敌方侧对称：没有真实手牌可「选」，只给费用那半边。
		state.opp_energy += ENDLESS_DARK_ENERGY
		_log("无尽黑暗：敌方回合，费用 +%d（当前 %d）" % [
				ENDLESS_DARK_ENERGY, state.energy_of(side)])
		action.emit("endless_dark", {"dropped": 0, "names": [],
				"energy": ENDLESS_DARK_ENERGY, "side": side, "pending": false})
		return
	if state.hand.is_empty():
		_log("无尽黑暗：手牌为空，没有可弃的牌 → 本回合不弃也不给费用")
		action.emit("endless_dark", {"dropped": 0, "names": [],
				"energy": 0, "side": side, "pending": false})
		return
	# 开选牌面板：费用**等选完再给**（选牌面板期间不给费用，避免「先拿钱再选」）。
	endless_pending = true
	_log("无尽黑暗：从手牌中选择 1 张弃掉（不能不选）→ 之后费用 +%d"
			% ENDLESS_DARK_ENERGY)
	action.emit("endless_dark", {"dropped": 0, "names": [],
			"energy": ENDLESS_DARK_ENERGY, "side": side, "pending": true})


func endless_abort() -> void:
	## R376：**兜底落空** —— 待选状态下已经没有可弃的牌了（手牌被别的东西抽干 /
	## 被事件吃掉），就把待选收掉：不弃、不给费。
	## 没有这一条的话，「pending 挂着 + 手牌空 + 面板是个空网格」三件事凑在一起，
	## 就是「面板点不动、回合也结束不了」的死锁（用户报的现象）。
	if not endless_pending:
		return
	endless_pending = false
	_log("无尽黑暗：没有可弃的牌 → 本回合不弃也不给费用")
	action.emit("endless_dark", {"dropped": 0, "names": [], "energy": 0,
			"side": SIDE_SELF, "pending": false})


func endless_options() -> Array[int]:
	## 无尽黑暗：可弃的手牌下标（面板用；空数组 = 本回合没有待弃的牌）。
	if not endless_pending:
		return []
	var out: Array[int] = []
	for i in state.hand.size():
		out.append(i)
	return out


func endless_pick(hand_index: int) -> bool:
	## 无尽黑暗：玩家点掉一张手牌 → 真的弃掉 + 拿到费用，面板关闭。


	if not endless_pending:
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var c: CardData = state.hand[hand_index]
	state.hand.remove_at(hand_index)
	state.discard.append(c)
	endless_pending = false
	state.energy += ENDLESS_DARK_ENERGY
	_log("无尽黑暗：弃掉 %s → 费用 +%d（当前 %d）" % [
			c.card_name, ENDLESS_DARK_ENERGY, state.energy])
	action.emit("endless_pick", {"card": c, "energy": ENDLESS_DARK_ENERGY})
	return true


func _rebirth_tick(side: String) -> void:
	## 新生（9148，R222，森林精魄·史诗）：**抽牌之后**，按效果区张数逐份结算 ——
	## 每份「从手牌选 1 张**消失**（本场对战移除：不进手牌也不进弃牌区）→ 随机一张
	## **本职业奖励卡牌**加入手牌」。手牌为空 → 没有可消失的牌 → 整条落空。
	## 敌方侧没有真实手牌（只记张数）→ 对称落空，不开面板。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var copies:= _trait_copies(zone, REBIRTH_TRAIT)
	if copies <= 0:
		return
	if side != SIDE_SELF:
		# 敌方侧对称：没有真实手牌可「选」→ 整条效果落空。
		_log("新生：敌方回合没有真实手牌 → 效果落空")
		return
	if state.hand.is_empty():
		_log("新生：手牌为空，没有可消失的牌 → 本回合不触发")
		action.emit("rebirth", {"pending": false, "copies": copies,
				"remaining": 0, "names": []})
		return
	# 开选牌面板：**不能不选**（与无尽黑暗 / 复活术同款），随机卡等选完再给。
	rebirth_remaining = copies
	rebirth_pending = true
	_log("新生：效果区 %d 张 → 待消失 %d 张手牌，每张换一张随机本职业奖励卡"
			% [copies, copies])
	action.emit("rebirth", {"pending": true, "copies": copies,
			"remaining": copies, "names": []})


func rebirth_options() -> Array[int]:
	## 新生的面板候选：**全部**手牌（业务下标 = 手牌下标；空数组 = 没有待办）。
	if not rebirth_pending:
		return []
	var out: Array[int] = []
	for i in state.hand.size():
		out.append(i)
	return out


func rebirth_pick(hand_index: int) -> bool:
	## 新生：玩家点掉一张手牌 → 它**本场对战消失**（void_count/void_cards，
	## 与专注 9122 / 负重减轻 8066 同口径），然后随机一张**本职业奖励卡牌**加入手牌
	##（无尽加护 9061 同口径：`reward_pool_for(player_class)`，走引擎 rng → 回放可复现）。
	## 效果区几张新生就逐张来（rebirth_remaining 计数，与专注 / 拒绝命运同口径）。
	if not rebirth_pending:
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		return false
	var c: CardData = state.hand[hand_index]
	state.hand.remove_at(hand_index)
	state.void_count += 1   # R140：消耗区计数（新生从手牌抹除）
	state.void_cards.append(c)
	rebirth_remaining -= 1
	var given_name:= ""
	var repo:= CardRepo.load_json()
	if repo == null:
		_log("新生：%s 消失（卡库读取失败，未加入随机卡）" % c.card_name)
	else:
		var pool: Array[CardData] = repo.reward_pool_for(RunState.player_class)
		if pool.is_empty():
			_log("新生：%s 消失（本职业奖励池为空，没有可加入的牌）" % c.card_name)
		else:
			var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
			var copy:= CardData.from_dict(pick.to_dict())
			# R299：手牌满 → 直接进弃牌区（不再「本次不加入」白丢）
			_grant_to_hand(copy, "新生")
			given_name = copy.card_name
			_log("新生：%s 消失 → 随机一张「%s」加入手牌" % [c.card_name, given_name])
	action.emit("rebirth_pick", {"card": c, "given": given_name})
	if rebirth_remaining <= 0:
		rebirth_pending = false
		rebirth_remaining = 0
	elif state.hand.is_empty():
		# 手牌被选空了 → 剩余份额作废（面板不能空转着让玩家干等）。
		_log("新生：手牌已空，剩余 %d 份额作废" % rebirth_remaining)
		rebirth_remaining = 0
		rebirth_pending = false
	return true


func _zone_has(zone: Array[CardData], tname: String) -> bool :
	## 效果区里是否有该词条的效果卡（**多张不叠加** —— 语义是「有没有」，不是「有几张」）。
	for c: CardData in zone:
		if c.traits.has(tname):
			return true
	return false


func _dark_lord_energy(side: String) -> void :
	## 黑暗领主（8021，R56）：本回合结束时，场上本方每一个黑暗领主给自己 +5 费用。
	## 这是整个「回合结束」结算的**第一步**（优先结算）—— 加上的 5 点会被随后
	## 地狱猫/鲜血堡垒/活力转移/暗影锁链一起读到（它们读的是加完之后的剩余费用）。
	var gained := 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(DARK_LORD_TRAIT):
			gained += DARK_LORD_ENERGY
	if gained <= 0:
		return
	if side == SIDE_SELF:
		state.energy += gained
	else:
		state.opp_energy += gained
	_log("黑暗领主：本回合结束，费用 +%d（优先结算，当前 %d）"
			% [gained, state.energy_of(side)])
	action.emit("dark_lord", {"amount": gained, "side": side})


func _blade_strike(side: String, dmg: int) -> void :
	## 暗影之刃（9111，R56）：对**随机一个敌人**造成 dmg 点伤害（dmg = 本回合已花掉的费用）。
	var foes: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.unit_at(cell)
		if q != null and q.owner != side and q.health > 0:
			foes.append(cell)
	if foes.is_empty():
		_log("暗影之刃：场上没有敌人，效果落空")
		return
	var tgt: Vector2i = foes[rng.randi_range(0, foes.size() - 1)]
	var foe: Placement = state.unit_at(tgt)
	var src := foe.card.card_name
	var real := _hit_unit(foe, dmg, "暗影之刃")
	_destroy_dead()
	_log("暗影之刃：本回合已花 %d 费用 → 随机一个敌人（%s）受到 %d 点伤害"
			% [dmg, src, real])
	action.emit("dark_blade", {"cell": tgt, "dmg": real, "side": side})


func _dark_chain_pulls(side: String, times: int) -> void :
	## 暗影锁链（9112，R56）：剩余费用每 3 点一次，把**随机一个敌人**击退 2 格；
	## 每次独立随机选目标（可能多次打同一个）。走通用 _knockback（会被己方单位挡下）。
	if times <= 0:
		_log("暗影锁链：不足 %d 点剩余费用 → 本次不触发" % DARK_CHAIN_COST)
		return
	var pulled := 0
	for i in times:
		var foes: Array[Vector2i] = []
		for cell: Vector2i in state.board:
			var q: Placement = state.unit_at(cell)
			# R277：免疫位移的单位不进候补 —— 否则随机抽中它等于白耗一次击退。
			if q != null and q.owner != side and q.health > 0 \
					and not q.card.traits.has(DISPLACE_IMMUNE_TRAIT):
				foes.append(cell)
		if foes.is_empty():
			_log("暗影锁链：场上没有敌人，第 %d/%d 次落空" % [i + 1, times])
			break
		var tgt: Vector2i = foes[rng.randi_range(0, foes.size() - 1)]
		var res := _knockback(side, tgt, DARK_CHAIN_STEPS)
		if not res.contains("被挡住"):
			pulled += 1
	_log("暗影锁链：剩余费用换算 %d 次击退（每次 %d 格），实际移动 %d 次"
			% [times, DARK_CHAIN_STEPS, pulled])
	action.emit("dark_chain", {"times": times, "moved": pulled, "side": side})


func _ensure_opening_card(card_id: int) -> void :
	## 警觉（9109，R54）「第一个回合必定抽到」：抽牌前把牌库里那张挪到**牌库顶**
	## （draw() 从尾部取）→ 本回合抽的 5 张必定含它。不动随机源 → 回放复现不受影响。
	for i in state.deck.size():
		if state.deck[i].id == card_id:
			var c: CardData = state.deck[i]
			state.deck.remove_at(i)
			state.deck.append(c)
			_log("警觉：置于牌库顶（第 1 回合必定抽到）")
			return


func _ensure_opening_enchanted() -> void :
	## R229「起手」附魔：把牌库里带这个附魔的卡全部挪到**牌库顶**
	##（draw() 从尾部取 → 本回合抽的牌必定含它们），与警觉 9109 同口径、不动随机源。
	## ⚠️ 多张都带 → 逐张挪（倒序遍历，保持相对顺序）；起手只抽
	##    `FieldState.HAND_DRAW_PER_TURN` 张，带附魔的卡多于这个数时只有前几张必定到手。
	var moved: int = 0
	for i in range(state.deck.size() - 1, -1, -1):
		var c: CardData = state.deck[i]
		if c != null and c.enchant == ENCHANT_OPENING:
			state.deck.remove_at(i)
			state.deck.append(c)
			moved += 1
	if moved > 0:
		_log("起手附魔：%d 张卡置于牌库顶（第 1 回合必定抽到）" % moved)


func _alertness(side: String) -> String:
	## 警觉（9109，R54；R60 改；**R77 供给口径由「工事」改为「场地**」）：
	## 把一张随机**场地卡**（本角色奖励池，敌方侧退化为完整奖励池）加入手卡，
	## 那张卡**本回合内**费用 -ALERT_DISCOUNT（turn_card_discount = 本回合减费，
	## 回合结束随表清空 → 不跨回合；显示 = 判定 = 实扣都走 cost_of）。**用后警觉自身消失。**
	## 随机走引擎 rng（回放同种子可复现）；库内共享实例 → 复制后再进手。

	# R77：取「场地」而不是「工事」；R116：池子构造走唯一口 `_field_card_pool`
	var pool := _field_card_pool(side)
	if pool.is_empty():
		return "（警觉：奖励池中没有场地卡）"
	var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
	var copy:= CardData.from_dict(pick.to_dict())
	# R299：手牌满 → 直接进弃牌区（减费标记照旧挂着，本回合有效）
	_grant_to_hand(copy, "警觉")
	if side == SIDE_SELF:
		# 本回合减费（不是 card_discount 那个永久实例减费）——回合结束自动失效
		state.turn_card_discount[copy] = int(state.turn_card_discount.get(copy, 0)) \
				+ ALERT_DISCOUNT
		_log("警觉：随机一张场地「%s」进入手卡（本回合费用 -%d）"
				% [copy.card_name, ALERT_DISCOUNT])
		action.emit("alert", {"card": copy, "discount": ALERT_DISCOUNT, "side": side})
		return "警觉：%s 进入手卡（本回合费用 -%d）" % [copy.card_name, ALERT_DISCOUNT]
	return "警觉：%s 进入手卡" % copy.card_name


func pass_attack(cell: Vector2i, side:= SIDE_SELF) -> void :
	var p:= state.unit_at(cell)
	if p == null or p.owner != side or p.tapped or not p.moved:
		return
	_tap(p, "放弃攻击")


func _trample_chain(attacker: Placement, foe_side: String, from_cell: Vector2i,
		remaining: int, src: Vector2i) -> Array:
	## R225 践踏：击杀后的溢出伤害沿**同一列**继续往深处传 —— 逐个结算同列的下一个
	## 敌对单位（空格跳过），打死一个就把剩余伤害继续往下传；遇见没打死的 → 停；
	## 整列打穿 → 返回 [剩下的伤害, 最后一个被击穿的单位名]
	##（调用方拿它直击对方 HP；名字用于播报「打穿的是谁」，没穿到人就返回空串）。
	## 「深处」= 从被击杀的格子继续**远离攻击者**的方向（行号差的正负）。
	## ⚠️ 坐标是 `Vector2i(行, 列)` —— 同列 = 同一个 `y`，行号往对方半场推。
	## ⚠️ 只认 `foe_side` 的单位（同列的己方单位不会被误伤）。
	## ⚠️ 每段都走 `_hit_unit(..., is_attack = true)` = 与那一下普通攻击同口径
	##    （侦察塔光环 / 百臂工场「只减攻击」/ 石肤等都照常生效）。
	if attacker == null or remaining <= 0:
		return [remaining, ""]
	var step: int = 0
	if from_cell.x > src.x:
		step = 1
	elif from_cell.x < src.x:
		step = -1
	else:
		return [remaining, ""]    # 同一行（理论上不会发生）：不再往下传
	var pierced: String = ""
	var cell: Vector2i = from_cell
	while remaining > 0:
		cell = Vector2i(cell.x + step, cell.y)
		if cell.x < 0 or cell.x >= FieldState.BOARD_ROWS:
			break                  # 这一列走到底了 → 剩下的直击 HP
		var next: Placement = state.unit_at(cell)
		if next == null or next.owner != foe_side:
			continue               # 空格 / 同列的自己人 → 继续往深处找
		var hp_before: int = next.health
		next.last_hit_by = src      # 击杀记功：践踏打死的也算攻击者的（锻造会触发）
		var dmg: int = _hit_unit(next, remaining, "战斗", true, true)
		_log("践踏：%d 点溢出沿同列传给 %s（造成 %d 点伤害）" % [
				remaining, next.card.card_name, dmg])
		action.emit("trample_hit", {"cell": cell, "side": next.owner, "amount": dmg,
				"name": next.card.card_name, "src": src,
				"atk_name": attacker.card.card_name, "from": from_cell})
		pierced = next.card.card_name
		if next.health > 0:
			return [0, pierced]    # 没打死 → 溢出到此为止（它吃满）
		var over: int = dmg - maxi(hp_before, 0)
		_destroy(cell)
		remaining = over
	return [remaining if remaining > 0 else 0, pierced]


func attack(src: Vector2i, dst: Vector2i, side:= SIDE_SELF) -> void :



	var attacker:= state.unit_at(src)
	var defender:= state.unit_at(dst)
	if attacker == null or attacker.owner != side or attacker.tapped:
		return
	if defender == null or defender.owner == side:
		return
	if not attack_targets(src, side, attacker.card).has(dst):
		_log("%s 打不到 %s（不在攻击距离内）" % [attacker.card.card_name, dst])
		return
	if not _taunt_ok(src, side, attacker.card, dst):
		var tn:= _taunt_targets(src, side, attacker.card)
		_log("射程内有嘲讽单位（%s），必须先攻击它" % state.unit_at(tn[0]).card.card_name)
		return
	var atk_power:= attacker.effective_power() + _turn_dmg_bonus(side)\
	+ _ally_dmg_bonus(attacker.card, side)
	var hp_before:= defender.health
	defender.last_hit_by = src          # 击杀记功：鸭子骑士靠它结算「每击杀一个敌人 +2 攻击力」
	var def_dmg:= _hit_unit(defender, atk_power, "战斗", true, true)
	# R341 惊奇盒子（9179）：**被攻击时**给攻击者挂「眩晕」（下个自己回合不能行动）。
	# ⚠️ 不判「盒子还活着」：它只有 1 血，任何攻击都会把它打掉 —— 判存活等于这条效果永不触发。
	# ⚠️ 放在 `_destroy` 之前：盒子被打死后就没有「被攻击时」这个时机了。
	if defender.card.traits.has(STUN_BOX_TRAIT):
		_apply_stun(attacker, "惊奇盒子")
	# R74：场地卡**不是单位**（不在 board 里），所以打不到、也不会被「攻击即死」——
	# 它的触发点唯一在 _field_trigger（挂在 move 上）。这里不再有任何陷阱即死分支。
	# R225：践踏 → 击杀的溢出伤害不丢（沿击杀目标那一列继续传下去）；
	# 非践踏保持原规则：只有被击穿的是对方**后排**单位，溢出才漏到 HP。
	# R356：启示者阶段 2 起自带「践踏」（阶段效果，不烤进 CardData → 这里补一条判据）。
	var trample: bool = attacker.card.traits.has(TRAMPLE_TRAIT) or attacker.boss_phase >= 2
	var overflow:= 0
	if def_dmg > hp_before and (trample or dst.x == back_row(defender.owner)):
		overflow = def_dmg - maxi(hp_before, 0)
	_log("%s 攻击 %s：对方 -%d 生命" % [
		attacker.card.card_name, defender.card.card_name, def_dmg])
	action.emit("attack", {"src": src, "dst": dst, "damage": def_dmg, 
		"side": side, "overflow": overflow, 
		"atk_name": attacker.card.card_name, "def_name": defender.card.card_name})
	if defender.health <= 0:
		_destroy(dst)
		# R225：践踏 —— 先把溢出伤沿同列逐个击穿，打穿整列后剩下的才轮到 HP。
		var pierced_name: String = defender.card.card_name
		if overflow > 0 and trample:
			var tr_res: Array = _trample_chain(attacker, defender.owner, dst, overflow, src)
			overflow = int(tr_res[0])
			if str(tr_res[1]) != "":
				pierced_name = str(tr_res[1])   # 播报「打穿的是同列最后一个」
		if overflow > 0:
			var foe:= defender.owner
			_log("溢出伤害：%d 点越过 %s 漏到玩家 HP" % [overflow, pierced_name])
			# R145：先结算、再播出 —— `amount` 报实际掉血（溢出也可能被石肤 / 护心压掉）。
			_damage_player(foe, overflow, "溢出")
			action.emit("trample", {"side": foe, "amount": _last_hp_damage, "src": src,
				"dst": dst, "atk_name": attacker.card.card_name,
				"def_name": pierced_name})
	if defender.health <= 0 and defender.card.traits.has(WORKSHOP_TRAIT) and state.board.has(src):
		# 机关工坊（8015；R74 由「陷阱工坊」改名，仍是工事）：被敌人的攻击**破坏** → 对破坏它的敌人造成 8 伤。
		# 攻击者若已先倒下（如踩了别的反伤）则不再追伤；同样记「触发过工事」供暗影狩猎判定。
		var w_dmg:= _hit_unit(attacker, WORKSHOP_DMG + _field_mastery(defender.owner, defender.card),
				"机关工坊")
		attacker.trap_trig_turn = turn_total
		_log("机关工坊被破坏：%s 反受 %d 点伤害" % [attacker.card.card_name, w_dmg])
		action.emit("trap_hit", {"cell": src, "amount": w_dmg, "kind": "工坊",
				"name": attacker.card.card_name})
		_destroy_dead()
	# 启示者阶段 2「电磁屏障」（R356）：**攻击它的单位受到 5 伤**。
	# 位置在「防守方结算完」之后、`_tap` 之前：攻击者若被电死，下面 `board.has(src)` 为假，
	# 自然会跳过「行动完毕」的横置（它已经不在了）。
	# 反伤走 `_hit_unit`（与技能同一口径：吃光环 / 护盾 / 减伤），击杀走 `_destroy_dead`。
	if state.board.has(src) and defender.card.id == REVELATOR_ID and defender.boss_phase >= 2:
		var eb:= _hit_unit(attacker, EM_SHIELD_REFLECT, "电磁屏障", false)
		_log("电磁屏障：%s 攻击启示者 → 反受 %d 点伤害" % [attacker.card.card_name, eb])
		action.emit("revelator_shield", {"cell": dst, "src": src, "amount": eb,
				"atk_name": attacker.card.card_name})
		if attacker.health <= 0:
			_destroy_dead()
	if state.board.has(src):
		if attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:
			attacker.ramp_atk = 0
			_log("潜影者：攻击后力量重置（当前 %d）" % attacker.effective_power())
		_argos_summon(attacker)   # 百眼动员（9142，R174）：攻击单位 → 后排召唤俄倪厄
		# R381 鹅 9187：攻击后「目标后退 1 格 + 自己前进 1 格」（各自判「能不能」）。
		# 放在 `_tap` 之前 —— 前进完再结束行动，落点才是最终位置。
		_goose_lunge(attacker, dst)
		_attack_gain_energy(side, attacker)   # 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时 +1 费
		_tap(attacker, "行动完毕")
	_check_game_over()


func attack_hp(src: Vector2i, dst: Vector2i, side:= SIDE_SELF) -> void :
	var attacker:= state.unit_at(src)
	if attacker == null or attacker.owner != side or attacker.tapped:
		return
	var targets:= hp_targets(src, side)
	if targets.is_empty():
		return
	if not targets.has(dst):
		dst = targets[0]
	if not _taunt_ok(src, side, attacker.card, Vector2i(-1, -1)):
		var tn:= _taunt_targets(src, side, attacker.card)
		_log("射程内有嘲讽单位（%s），不能直击 HP" % state.unit_at(tn[0]).card.card_name)
		return
	var power:= attacker.effective_power() + _turn_dmg_bonus(side)\
	+ _ally_dmg_bonus(attacker.card, side)
	# R145：`dealt` = 真正落到 HP 上的伤害（减伤 / 挡下之后）。0 = 被完全挡下。
	var dealt:= power
	if side == SIDE_SELF:
		state.hp_opponent = maxi(0, state.hp_opponent - power)
		_log("%s 攻击敌方 HP（从后排 %s）：敌方 -%d，剩余 %d" % [
			attacker.card.card_name, dst, power, state.hp_opponent])
	else:
		if _absorb_by_guard(power):
			dealt = 0
			_log("森林守护盟友替我方挡下 %s 的攻击" % attacker.card.card_name)
		else:
			# 荒野形态 6022：每场第一次「普通攻击直击我方 HP」→ 减伤 + 反伤。
			# 只挂在普通攻击这条路径上：技能 / 效果 / 溢出的 HP 伤害都走
			# _damage_player → _hp_damage_taken，不会触发它。
			var self_dmg:= _wild_form_first_hit(attacker, power)
			dealt = self_dmg
			state.hp_self = maxi(0, state.hp_self - self_dmg)
			_log("%s 攻击我方 HP：我方 -%d，剩余 %d" % [
				attacker.card.card_name, self_dmg, state.hp_self])
			if self_dmg > 0:
				_on_self_damaged()
				_on_self_hp_damaged()
	# R145：飘字 / 战斗记录 / 横幅冻结一律用**实际掉的血**（`dealt`）——
	# 石肤 / 荒野形态 / 护心 / 挡下之后只掉 1 点却飘「-12」是错的。
	# `raw` 另存原始攻击力，留给「本该多少」这类显示（目前无人读）。
	action.emit("hp", {"src": src, "dst": dst, "damage": dealt, "raw": power,
		"side": side, "atk_name": attacker.card.card_name})
	if attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:
		attacker.ramp_atk = 0
		_log("潜影者：攻击 HP 后力量重置（当前 %d）" % attacker.effective_power())
	_attack_gain_energy(side, attacker)   # 地狱咏唱者 / 黑暗祭坛：直击 HP 也算一次攻击
	_tap(attacker, "攻击 HP，行动完毕")
	_check_game_over()




func ai_action_queue() -> Array[Vector2i]:
	## R160：行动顺序开关。true 走优化版（角色/让位/多动/开路），false 回滚到原版。
	if AI_QUEUE_USE_OPTIMIZED:
		return _ai_action_queue_optimized()
	return _ai_action_queue_classic()


func _ai_action_queue_classic() -> Array[Vector2i]:
	## 原版行动顺序（R61 及以前）：按位置排序 + 开路射击优先。
	var cells: Array[Vector2i] = []
	if over or current_side != SIDE_OPPONENT:
		return cells
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == SIDE_OPPONENT and not p.tapped:
			cells.append(cell)

	cells.sort_custom( func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x > b.x
		return a.y < b.y)
	# 开路射击优先（R61）：攻击距离 ≥ 2 且能一击清除「挡在前排友军路上」的卡 →
	# 提到队首先出手，被挡的友军本回合就能推进。默认仍是「靠前的先行动」。
	var promoted: Array[Vector2i] = []
	for cell in cells:
		var p: Placement = state.board[cell]
		if p.effective_range() >= 2 and _clear_shot_target(cell, p) != null:
			promoted.append(cell)
	if promoted.is_empty():
		return cells
	var rest: Array[Vector2i] = []
	for cell in cells:
		if not promoted.has(cell):
			rest.append(cell)
	return promoted + rest


func _ai_role_priority(card: CardData) -> int:
	## R160：行动顺序角色优先级（越小越先动）。
	## 只按卡面归类，不计算实际场面收益。
	var role := _ai_role(card)
	match role:
		AI_ROLE_ASSAULT:  return 0   # 高速/穿行先占位
		AI_ROLE_SNIPER:   return 1   # 后排输出
		AI_ROLE_GENERIC:  return 2
		AI_ROLE_BRUISER:  return 3   # 高力量近战
		AI_ROLE_SUMMONER: return 4   # 召唤/锻造
		AI_ROLE_GROWTH:   return 5   # 每回合成长
		AI_ROLE_SUPPORT:  return 6   # 治疗/光环
		AI_ROLE_VOLATILE: return 7   # 亡语伤害
		AI_ROLE_TANK:     return 8   # 坦克/工事最后动
	return 9


func _ai_unblocks_ally_now(cell: Vector2i, p: Placement) -> bool:
	## R160：当前位置是否挡在后方未行动友军正前方，且本回合能向前移动让开。
	var behind := Vector2i(cell.x - 1, cell.y)
	if behind.x < 0:
		return false
	var q := state.unit_at(behind)
	if q == null or q.owner != p.owner or q.tapped or q.card.is_fort() or q.effective_speed() == 0:
		return false
	if p.effective_speed() == 0 or p.card.is_fort():
		return false
	var front := Vector2i(cell.x + 1, cell.y)
	if front.x >= FieldState.BOARD_ROWS:
		return false
	if state.board.has(front):
		return false
	return true


func _ai_action_queue_optimized() -> Array[Vector2i]:
	## R160：优化版行动顺序。
	## 优先级：开路射击 > 角色（突进/输出优先，坦克/辅助殿后） > 能让位者先 > 多动优先 > 靠前优先 > 两翼优先。
	var cells: Array[Vector2i] = []
	if over or current_side != SIDE_OPPONENT:
		return cells
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner == SIDE_OPPONENT and not p.tapped:
			cells.append(cell)

	cells.sort_custom( func(a: Vector2i, b: Vector2i) -> bool:
		var pa: Placement = state.board[a]
		var pb: Placement = state.board[b]
		# 1) 开路射击绝对优先（保持 R61 逻辑）
		var a_clear := _clear_shot_target(a, pa) != null
		var b_clear := _clear_shot_target(b, pb) != null
		if a_clear != b_clear:
			return a_clear
		# 2) 位置：越靠前越先动（R61 大原则不变）
		if a.x != b.x:
			return a.x > b.x
		# 3) 同位置/同行：角色优先级（突进/输出优先，坦克/辅助殿后）
		var a_pri := _ai_role_priority(pa.card)
		var b_pri := _ai_role_priority(pb.card)
		if a_pri != b_pri:
			return a_pri < b_pri
		# 4) 同角色：能让位者先动，避免挡队友路
		var a_unblock := _ai_unblocks_ally_now(a, pa)
		var b_unblock := _ai_unblocks_ally_now(b, pb)
		if a_unblock != b_unblock:
			return a_unblock
		# 5) 同角色同位置：多动单位优先，保证行动轮数用完
		if pa.acts_left != pb.acts_left:
			return pa.acts_left > pb.acts_left
		# 6) 同行：两翼（y=0,2）先于中间（y=1），减少互相阻挡
		var ay := 0 if a.y != 1 else 2
		var by := 0 if b.y != 1 else 2
		return ay < by)
	return cells


func run_ai_unit(cell: Vector2i) -> void :
	if over or not ai_enabled or current_side != SIDE_OPPONENT:
		return
	var p:= state.unit_at(cell)
	if p == null or p.owner != SIDE_OPPONENT or p.tapped:
		return
	_ai_act(cell, p)


func ai_force_tap(cell: Vector2i) -> bool:
	## R400：**AI 卡死兜底口**。某个敌方单位连着好几拍都还排在队首（既没横置、
	## 也没把自己挪出队列），界面侧就调这里强行结束它的本回合行动。
	## 正常路径永远走不到 —— 走到就说明 `_ai_act` / `_assassin_act` 有漏 `_tap` 的分支。
	## ⚠️ 必须先把 `acts_left` 压到 1：`_tap()` 见 `acts_left > 1` 会「再开一轮」
	## （tapped 仍为 false），那样兜底等于没兜。
	var p:= state.unit_at(cell)
	if p == null or p.owner != SIDE_OPPONENT or p.tapped:
		return false
	_log("AI 停滞兜底：%s 连续多拍无动作，强制结束本回合行动" % p.card.card_name)
	p.acts_left = 1
	_tap(p, "AI：停滞兜底")
	return true


func _ai_role(card: CardData) -> String:
	## R159：按卡面能力给单位贴一个 AI 角色（只读 card，不读 Placement）。
	## 分类不精确计算收益，只按 traits / kind / 数值 / 文本做快速归类。
	if card == null:
		return AI_ROLE_GENERIC
	var txt:= card.effect_text.to_lower()
	var traits = card.traits
	if traits.has(ASSASSIN_TRAIT):
		return AI_ROLE_ASSAULT   # 暗杀者有专属 AI，这里只给它一个兜底标记
	if traits.has(TAUNT_TRAIT) or card.is_fort() or (card.health >= 80 and card.move_speed == 0):
		return AI_ROLE_TANK
	if traits.has("孵化") or traits.has("锻造") or traits.has("量产锻造") or traits.has("铸造") or traits.has("暗杀召唤") or traits.has("召唤"):
		return AI_ROLE_SUMMONER
	if traits.has("爆炎") or (traits.has("亡语") and ("伤害" in txt or "造成" in txt)):
		return AI_ROLE_VOLATILE
	if traits.has("治疗") or traits.has("成长") or traits.has("哈气") or traits.has("使魔成长") or traits.has("机械成长") or (card.power == 0 and not card.is_fort()):
		return AI_ROLE_SUPPORT
	if card.attack_range >= 2 and card.power >= 4:
		return AI_ROLE_SNIPER
	if (card.move_speed >= 2 or traits.has("队长") or traits.has("穿行")) and card.power >= 3:
		return AI_ROLE_ASSAULT
	if traits.has("亡语") or "每回合开始时，力量" in card.effect_text or "每过一个自己的回合" in card.effect_text:
		return AI_ROLE_GROWTH
	if traits.has(ACTION_GROWTH_TRAIT):   # R161：赫尔墨斯——越拖行动次数越多
		return AI_ROLE_GROWTH
	if traits.has(ASCLEPIUS_TRAIT):   # R162：阿斯克勒庇厄斯——越拖越强且存爆
		return AI_ROLE_GROWTH
	if card.power >= 7:
		return AI_ROLE_BRUISER
	return AI_ROLE_GENERIC


func _ai_role_threat(role: String) -> int:
	## 敌方 AI 视角：目标越"讨厌"，威胁分越低（优先击杀）。
	match role:
		AI_ROLE_SUPPORT: return 0
		AI_ROLE_VOLATILE: return 1
		AI_ROLE_GROWTH:   return 2
		AI_ROLE_SNIPER:   return 3
		AI_ROLE_ASSAULT:  return 4
		AI_ROLE_SUMMONER: return 5
		AI_ROLE_BRUISER:  return 6
		AI_ROLE_GENERIC:  return 7
		AI_ROLE_TANK:     return 8
	return 9


func _ai_pick_card_target(targets: Array[Vector2i], p: Placement = null) -> Vector2i:
	## 通用选目标：
	##   1) 能穿透（打死敌方后排、溢出漏到 HP）的目标最优先 —— 那相当于在打 HP；
	##   2) 能一击击杀的目标优先（不浪费行动）；
	##   3) 按角色威胁分优先击杀 support/growth/sniper 等；
	##   4) 同分则挑血少 / 力高 / 更靠前的目标。
	if p != null:
		var ov = _overflow_pick(targets, p)
		if ov != null:
			return ov
	var best: Vector2i = targets[0]
	var atk:= 0
	if p != null:
		atk = p.effective_power() + _turn_dmg_bonus(SIDE_OPPONENT) + _ally_dmg_bonus(p.card, SIDE_OPPONENT)
	var best_key:= [1, 99, 999, 0, 99, 99]
	for t in targets:
		var q:= state.unit_at(t)
		if q == null:
			continue
		var can_kill:= 0 if atk > 0 and q.health <= atk else 1
		var threat:= _ai_role_threat(_ai_role(q.card))
		var key:= [can_kill, threat,
				q.health if q.health > 0 else 999,
				- (q.effective_power()),
				- t.x, t.y]
		if [key[0], key[1], key[2], key[3], key[4], key[5]] < [best_key[0], best_key[1], best_key[2], best_key[3], best_key[4], best_key[5]]:
			best = t
			best_key = key
	return best


func _overflow_pick(targets: Array[Vector2i], p: Placement) -> Variant:
	## 穿透（溢出伤害）：攻击**敌方后排**单位时，打死它多出来的伤害会漏到玩家 HP。
	## 在 targets 里找「这一击能打死、且溢出最多」的后排目标；没有返回 null。
	var atk:= p.effective_power() + _turn_dmg_bonus(SIDE_OPPONENT)\
	+ _ally_dmg_bonus(p.card, SIDE_OPPONENT)
	var best = null
	var best_over:= 0
	for t in targets:
		var q:= state.unit_at(t)
		if q == null or t.x != back_row(q.owner):
			continue
		var over:= atk - maxi(q.health, 0)
		if over > best_over:
			best_over = over
			best = t
	return best


func _taunt_targets(cell: Vector2i, side: String, card: CardData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in attack_targets(cell, side, card):
		var q:= state.unit_at(t)
		if q != null and q.card.traits.has(TAUNT_TRAIT):
			out.append(t)
	return out


func _taunt_ok(cell: Vector2i, side: String, card: CardData, dst: Vector2i) -> bool:


	var taunts:= _taunt_targets(cell, side, card)
	if taunts.is_empty():
		return true
	return taunts.has(dst)


func taunt_in_range(cell: Vector2i, side:= "", card: CardData = null) -> bool:


	var s:= side
	var c:= card
	if s == "" or c == null:
		var p:= state.unit_at(cell)
		if p == null:
			return false
		if s == "":
			s = p.owner
		if c == null:
			c = p.card
	return not _taunt_targets(cell, s, c).is_empty()


func legal_attack_targets(cell: Vector2i, side:= "", card: CardData = null) -> Array[Vector2i]:




	var raw:= attack_targets(cell, side, card)
	var s:= side
	var c:= card
	if s == "" or c == null:
		var p:= state.unit_at(cell)
		if p == null:
			return raw
		if s == "":
			s = p.owner
		if c == null:
			c = p.card
	var taunts:= _taunt_targets(cell, s, c)
	return taunts if not taunts.is_empty() else raw


func _ai_target_choice(cell: Vector2i, p: Placement) -> Variant:










	var taunts:= _taunt_targets(cell, SIDE_OPPONENT, p.card)
	if not taunts.is_empty():
		return ["card", _ai_pick_card_target(taunts, p)]
	# 开路射击（R61）：攻击距离 ≥ 2 → 优先一击清除挡在前排友军路上的卡，
	# 被挡的友军本回合就能推进（与 ai_action_queue 的先出手排序配套）。
	var clear_t: Variant = _clear_shot_target(cell, p)
	if clear_t != null:
		return ["card", clear_t]
	var hp_cells:= hp_targets(cell, SIDE_OPPONENT)
	if not hp_cells.is_empty():
		return ["hp", _pick_nearest(cell, hp_cells)]
	var card_targets:= attack_targets(cell, SIDE_OPPONENT, p.card)
	if card_targets.is_empty():
		return null
	# 穿透：能打死我方后排、把溢出伤害漏到 HP 的目标，优先于其他卡目标
	var ov = _overflow_pick(card_targets, p)
	if ov != null:
		return ["card", ov]
	# R265：被一个前顶单位顶住时，远程单位先侧移（`_ai_ranged_step`）——
	# 返回 null 交给 `_ai_best_step` 走位，**不要**在这里原地打那个杂兵。
	# 近战 / 已经能打 HP / 侧移也缩短不了距离的单位，都不受影响。
	if _ai_ranged_step(cell, p) != null:
		return null
	if _wall_depth(cell, p) <= 0:
		return null
	var blockers:= _blocking_targets(cell, p, card_targets)
	if not blockers.is_empty():
		return ["card", _ai_pick_card_target(blockers, p)]
	# R159：即便目标不是"挡路卡"，能一击击杀也比空过强（优先击杀 support / growth 等）。
	if not card_targets.is_empty():
		var pick:= _ai_pick_card_target(card_targets, p)
		var q:= state.unit_at(pick)
		if q != null:
			var atk:= p.effective_power() + _turn_dmg_bonus(SIDE_OPPONENT) + _ally_dmg_bonus(p.card, SIDE_OPPONENT)
			if atk > 0 and q.health <= atk:
				return ["card", pick]
	return null


func _pick_nearest(cell: Vector2i, targets: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = targets[0]
	for t in targets:
		if manhattan(cell, t) < manhattan(cell, best)\
		or (manhattan(cell, t) == manhattan(cell, best) and t.y < best.y):
			best = t
	return best


const AI_NO_ROUTE:= 99
# R265：射程 ≥ 这个值的单位，被挡路者贴脸时**优先侧移去开火线**，不跟杂兵换血。
const AI_RANGED_REPOSITION_RANGE:= 2


func _walk_search(cell: Vector2i, p: Placement, want_hp: bool, 
		cleared: Array = []) -> Variant:




	if _goal_ok(cell, p, want_hp):
		return [0, cell]
	var blocked:= {}
	for c: Vector2i in state.board:
		if state.board[c] == p:
			continue
		blocked[c] = true
	for c in cleared:
		blocked.erase(c)
	var seen:= {cell: true}
	var queue: Array = [[cell, 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var cur: Vector2i = item[0]
		var dist: int = item[1]
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS\
			or nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
				continue
			if nxt.x == forbidden_row_for(SIDE_OPPONENT):
				continue
			if seen.has(nxt) or blocked.has(nxt):
				continue
			if _goal_ok(nxt, p, want_hp):
				return [dist + 1, nxt]
			seen[nxt] = true
			queue.append([nxt, dist + 1])
	return null


func _hp_cells_open(cell: Vector2i, p: Placement, cleared: Array = []) -> Array[Vector2i]:



	var c:= p.card
	var row:= back_row(SIDE_SELF)
	var out: Array[Vector2i] = []
	for col in FieldState.BOARD_COLS:
		var t:= Vector2i(row, col)
		if state.board.has(t) and not cleared.has(t):
			continue
		if attack_distance(cell, t, p.owner, c) <= eff_range(cell, c):
			out.append(t)
	return out


func _goal_ok(cell: Vector2i, p: Placement, want_hp: bool, cleared: Array = []) -> bool:
	if want_hp:
		return not _hp_cells_open(cell, p, cleared).is_empty()
	return not attack_targets(cell, SIDE_OPPONENT, p.card).is_empty()


func _hp_search(cell: Vector2i, p: Placement, cleared: Array = []) -> Variant:
	return _walk_search(cell, p, true, cleared)


func _front_search(cell: Vector2i, p: Placement, cleared: Array = []) -> Variant:
	return _walk_search(cell, p, false, cleared)


func _wall_depth(cell: Vector2i, p: Placement, cleared: Array = []) -> int:




	var dist:= {cell: 0}
	var dq: Array = [cell]
	while not dq.is_empty():
		var cur: Vector2i = dq.pop_front()
		var d: int = dist[cur]
		if _goal_ok(cur, p, true, cleared):
			return d
		for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + dir
			if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS\
			or nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
				continue
			if nxt.x == forbidden_row_for(SIDE_OPPONENT):
				continue
			var cost:= 0
			var occ: Placement = state.board.get(nxt)
			if occ != null and occ != p and not cleared.has(nxt)\
			and occ.owner == SIDE_SELF:
				cost = 1
			var nd:= d + cost
			if dist.has(nxt) and int(dist[nxt]) <= nd:
				continue
			dist[nxt] = nd
			if cost == 0:
				dq.push_front(nxt)
			else:
				dq.push_back(nxt)
	return AI_NO_ROUTE


func _hp_route_exists(cell: Vector2i, p: Placement, cleared: Array = []) -> bool:
	return _hp_search(cell, p, cleared) != null


func _blocking_targets(cell: Vector2i, p: Placement,
		targets: Array[Vector2i]) -> Array[Vector2i]:


	var base:= _wall_depth(cell, p)
	var out: Array[Vector2i] = []
	if base == 0:
		return out
	for t in targets:
		if _wall_depth(cell, p, [t]) < base:
			out.append(t)
	return out


func _blocks_front_ally(t: Vector2i, sniper_cell: Vector2i) -> bool:
	## 开路判断（R61）：t（我方单位）是否挡在任一「比狙击手更前排」的友军路上 ——
	## ① 它就在那友军的攻击距离内（友军本回合多半会把攻击浪费在它身上）；
	## ② 移除它之后那友军打 HP 的开路深度（_wall_depth）变小 = 它是路线上的墙。
	## 只看还没行动、且比狙击手更靠近我方半场的友军（工事不算，反正不会推进）。
	for fcell: Vector2i in state.board:
		var f: Placement = state.board[fcell]
		if f.owner != SIDE_OPPONENT or f.tapped or f.card.is_fort():
			continue
		if fcell.x <= sniper_cell.x:
			continue
		if manhattan(fcell, t) <= f.effective_range():
			return true
		if f.effective_speed() > 0:
			var base:= _wall_depth(fcell, f)
			if base > 0 and _wall_depth(fcell, f, [t]) < base:
				return true
	return false


func _clear_shot_target(cell: Vector2i, p: Placement) -> Variant:
	## 开路射击（R61）：攻击距离 ≥ 2 的单位专属判断 —— 射程（含嘲讽规则）内有没有
	## 「能一击打死、且挡在前排友军路上」的我方卡。有则返回该目标格；没有返回 null。
	## ai_action_queue（先出手排序）与 _ai_target_choice（目标优先级）共用这个判断，
	## 保证「先出手」的单位确实去打那张挡路卡。
	if p.effective_range() < 2:
		return null
	var targets:= legal_attack_targets(cell, SIDE_OPPONENT, p.card)
	if targets.is_empty():
		return null
	var atk:= p.effective_power() + _turn_dmg_bonus(SIDE_OPPONENT) \
			+ _ally_dmg_bonus(p.card, SIDE_OPPONENT)
	var killable: Array[Vector2i] = []
	for t in targets:
		var q:= state.unit_at(t)
		if q == null or q.health > atk:
			continue
		if _blocks_front_ally(t, cell):
			killable.append(t)
	if killable.is_empty():
		return null
	return _ai_pick_card_target(killable, p)


func _ai_ranged_step(cell: Vector2i, p: Placement) -> Variant:
	## R265（用户口径：**「恶魔鸭前进两格后被前顶单位单防」**）：
	## **远程单位不该站在挡路者面前换血** —— 射程 2 的单位根本不需要跨过那个单位，
	## 它只要侧移一格、把「到开火线的走位距离」缩短一步，就能继续压 HP。
	## 三条判据（同时成立才让位，任何一条不成立就照旧打）：
	##   ① 射程 ≥ `AI_RANGED_REPOSITION_RANGE`（近战没有绕行余地，啃掉挡路者才是正解）；
	##   ② **现在打不到 HP**（打得到就直接开枪，`_ai_target_choice` 会先处理 HP，这里不该抢）；
	##   ③ 存在可达格使 `_hp_pos_distance` **严格变小**（等距侧移 = 空走，不算优化）。
	## 返回要挪过去的格子；不需要 / 无处可让 → null。
	## ⚠️ 只读 `_hp_pos_distance`（把被占格当墙的真实走位距离）—— 与 `_step_score` 里
	##    那个被 `_engage_distance` 拉平的 `near` 不同，它在远程单位身上不会一落地就归零。
	if p == null or p.card == null or p.card.is_fort() or p.effective_speed() == 0:
		return null
	if p.effective_range() < AI_RANGED_REPOSITION_RANGE:
		return null
	if not hp_targets(cell, SIDE_OPPONENT, p.card).is_empty():
		return null
	var here:= _hp_pos_distance(cell, p)
	if here <= 0 or here >= AI_NO_ROUTE:
		return null
	var best:= Vector2i(-1, -1)
	var best_d:= here
	for dst: Vector2i in _reachable(cell, SIDE_OPPONENT):
		if dst == cell:
			continue
		var d:= _hp_pos_distance(dst, p)
		if d >= here:
			continue   # 没变好（或更差）→ 空走
		# 同样能缩短时偏好继续向前（敌方 +x 方向），避免在两翼来回摆
		if d < best_d or (d == best_d and dst.x > best.x):
			best = dst
			best_d = d
	return best if best != Vector2i(-1, -1) else null


func _ai_best_step(cell: Vector2i, p: Placement) -> Variant:



	var reachable:= _reachable(cell, SIDE_OPPONENT)
	if reachable.is_empty():
		return null
	var best: Vector2i = cell
	var best_score:= _step_score(cell, cell, p)
	for dst in reachable:
		var s:= _step_score(cell, dst, p)
		if s < best_score:
			best = dst
			best_score = s
	if best != cell:
		return best
	# R265：分数打平（远程单位的距离项被 `_engage_distance` 拉平是常态）时，
	# 仍然要肯为「缩短开火距离」侧移一格 —— 否则就是站在挡路者面前原地换血。
	var reposition: Variant = _ai_ranged_step(cell, p)
	if reposition != null:
		return reposition
	if p.acts_left < 2 or p.card.is_fort() or p.effective_speed() == 0:
		return null
	var spd:= p.effective_speed()
	if self_relics.has(HEAVY_DUCK_RELIC_ID) and p.owner != SIDE_SELF and spd > 1:
		spd = 1



	var best2:= Vector2i(-1, -1)
	var best2_score:= best_score
	var via:= Vector2i(-1, -1)
	for mid in reachable:
		for dst2 in _reachable_with(mid, cell, SIDE_OPPONENT, spd,
				1 if p.card.traits.has(PHASE_TRAIT) else 0):
			if dst2 == cell or reachable.has(dst2):
				continue
			var s2:= _step_score(cell, dst2, p)
			if s2 < best2_score:
				best2_score = s2
				best2 = dst2
				via = mid
	if via == Vector2i(-1, -1):
		return null
	_log("%s 用两次行动绕行：先挪到 %s 再去 %s" % [p.card.card_name, via, best2])
	return via


func _engage_distance(cell: Vector2i, p: Placement) -> int:
	## 接战距离：从 cell 出发走到「能攻击到某个我方单位」的位置要几步。
	## BFS 把被占用的格子当墙（真实走位）—— 打不到 HP 时也会绕过障碍贴向敌人破局。
	var atk_range:= p.effective_range()
	var foes: Array[Vector2i] = []
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q != p and q.owner == SIDE_SELF:
			foes.append(c)
	if foes.is_empty():
		return AI_NO_ROUTE
	var seen:= {cell: true}
	var queue: Array = [[cell, 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var cur: Vector2i = item[0]
		var dist: int = item[1]
		for f in foes:
			if manhattan(cur, f) <= atk_range:
				return dist
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS\
			or nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
				continue
			if nxt.x == forbidden_row_for(SIDE_OPPONENT) or seen.has(nxt):
				continue
			if state.board.has(nxt):
				continue
			seen[nxt] = true
			queue.append([nxt, dist + 1])
	return AI_NO_ROUTE


func _hp_pos_distance(cell: Vector2i, p: Placement) -> int:



	var row:= back_row(SIDE_SELF)
	var atk_range:= p.effective_range()
	var seen:= {cell: true}
	var queue: Array = [[cell, 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var cur: Vector2i = item[0]
		var dist: int = item[1]
		for col in FieldState.BOARD_COLS:
			if manhattan(cur, Vector2i(row, col)) <= atk_range:
				return dist
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= FieldState.BOARD_ROWS\
			or nxt.y < 0 or nxt.y >= FieldState.BOARD_COLS:
				continue
			if nxt.x == forbidden_row_for(SIDE_OPPONENT) or seen.has(nxt):
				continue
			# 被占用的格子当墙（真实走位距离）：单位才会绕开挡路者找空档推进
			if state.board.has(nxt):
				continue
			seen[nxt] = true
			queue.append([nxt, dist + 1])
	return AI_NO_ROUTE


func _ai_blocks_ally_path(dst: Vector2i, p: Placement) -> int:
	## R159：判断 dst 是否挡在还没行动的友军正前方。若友军就在 dst 后一格同列且能移动，
	## 则 dst 会让它下回合（或本回合后续行动）少一条直路；给 step_score 加惩罚。
	if p == null:
		return 0
	var behind:= Vector2i(dst.x - 1, dst.y)
	if behind.x < 0:
		return 0
	var q:= state.unit_at(behind)
	if q == null or q == p or q.owner != p.owner or q.tapped:
		return 0
	if q.card.is_fort() or q.effective_speed() == 0:
		return 0
	return 12   # 相当于 1 格多一点的距离惩罚，足够让 AI 选择绕开


func _step_score(src: Vector2i, dst: Vector2i, p: Placement) -> Array:








	var can_hit:= 0 if not hp_targets(dst, SIDE_OPPONENT, p.card).is_empty() else 1
	var wall:= _wall_depth(dst, p, [dst])
	# 目标距离 = 打到 HP 的距离 与 贴到最近敌人的距离 取小 —— 打不到 HP 就朝敌人推进破局
	var near:= mini(_hp_pos_distance(dst, p), _engage_distance(dst, p))
	# 同级距离里偏好向前（敌方 +x 方向），避免原地踏步：距离差 1 档 = 10 分，
	# 棋盘只有 6 行，前进 1 格最多 -5，永远压不过距离档，但同档内必然击败原地不动。
	var advance:= - dst.x
	# R159：移动后不要挡在队友正前方；侧翼 / 空列更优。
	var block_penalty:= _ai_blocks_ally_path(dst, p)
	return [can_hit, wall, near * 10 + advance + block_penalty, manhattan(src, dst), - dst.y]


func _ai_attack_if_any(cell: Vector2i, p: Placement) -> bool:
	# R74：场地卡不是单位 → 永远不会出现在 attack_targets 里，所以原来那个
	# 「skip_traps（避开陷阱目标）」的过滤分支连同参数一起删掉了（已无调用方传入）。
	var targets:= attack_targets(cell, SIDE_OPPONENT, p.card)
	if targets.is_empty():
		return false
	attack(cell, _ai_pick_card_target(targets, p), SIDE_OPPONENT)
	return true


func _ai_act(cell: Vector2i, p: Placement) -> void :
	# R111 鸭子暗杀者：被动生效时走**专属 AI**（闪现游走 + 只打单位、不打 HP）。
	if _assassin_passive(p):
		_assassin_act(cell, p)
		return




	var choice = _ai_target_choice(cell, p)
	if choice != null:
		if choice[0] == "hp":
			attack_hp(cell, choice[1], SIDE_OPPONENT)
		else:
			attack(cell, choice[1], SIDE_OPPONENT)
		return
	if p.moved:

		if _ai_attack_if_any(cell, p):
			return
		_tap(p, "AI：本轮已推进")
		return
	if p.card.is_fort() or p.effective_speed() == 0:

		if _ai_attack_if_any(cell, p):
			return
		_tap(p, "AI：不能移动且没有目标")
		return
	var dst = _ai_best_step(cell, p)
	if dst == null:

		if _ai_attack_if_any(cell, p):
			return
		_tap(p, "AI：原地待命")
		return
	move(cell, dst, SIDE_OPPONENT)
	if over:
		return
	var moved:= state.unit_at(dst)
	if moved == null:
		_tap(p, "AI：推进失败")
		return
	if moved.tapped:
		return
	var choice2 = _ai_target_choice(dst, moved)
	if choice2 != null:
		if choice2[0] == "hp":
			attack_hp(dst, choice2[1], SIDE_OPPONENT)
		else:
			attack(dst, choice2[1], SIDE_OPPONENT)
		return
	# R61 修复：移动后「挑剔」逻辑落空时的兜底 —— 射程内有非陷阱敌人就打。
	# 根因：_ai_target_choice 只打嘲讽/穿透/挡路目标，路已通（wall_depth<=0）时
	# 对旁边的敌人视而不见返回 null → 单位移动后既不攻击也不横置，白白放弃攻击权
	# （横向移动 / 穿越双方场地后空站）。原地未动的单位早有 _ai_attack_if_any 兜底，
	# 唯独移动后这条分支漏了。只剩陷阱可打 → 放弃（撞陷阱吃惩罚不值）。
	# 注意只在「刚移动、待攻击」状态（moved 仍为 true）才兜底：若引擎在 move() 里
	# 已按「无目标」消耗掉一次行动（多动单位的 moved 会被 _tap 重置成 false），
	# 说明它进入新一轮行动、还有后续轮次可走，这里不能抢。
	if not moved.moved:
		return
	if _ai_attack_if_any(dst, moved):
		return
	_tap(moved, "AI：移动后无合适目标，放弃攻击")




	var atk_targets:= attack_targets(dst, SIDE_OPPONENT, moved.card)
	if not atk_targets.is_empty():

		attack(dst, _ai_pick_card_target(atk_targets, moved), SIDE_OPPONENT)
	return

# ================= R111：鸭子暗杀者专属 AI =================

func _assassin_other_ally(p: Placement) -> bool:
	## 被动条件：**己方场上还有「暗杀」以外的单位**（含鸭之暗面这种非暗杀怪物）。
	## 只剩暗杀者（或只剩它自己）→ 条件不成立，被动关闭。
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q != p and q.owner == p.owner and not q.card.traits.has(ASSASSIN_TRAIT):
			return true
	return false


func _assassin_passive(p: Placement) -> bool:
	## 带「暗杀」trait 且被动条件成立 → 「不能打 HP + 可闪现」模式。
	## **引擎里唯一的判定口**：hp_targets 门禁、move 的 blink、AI 分派都读它。
	if p == null or not p.card.traits.has(ASSASSIN_TRAIT):
		return false
	return _assassin_other_ally(p)


func _assassin_cells(src: Vector2i) -> Array[Vector2i]:
	## 闪现候选：全场空格（排除对方后排行）+ 起点自身（原地也是一种选择）。
	var out: Array[Vector2i] = [src]
	var banned:= forbidden_row_for(SIDE_OPPONENT)
	for r in FieldState.BOARD_ROWS:
		if r == banned:
			continue
		for col in FieldState.BOARD_COLS:
			var c:= Vector2i(r, col)
			if not state.board.has(c):
				out.append(c)
	return out


func _assassin_cell_key(src: Vector2i, dst: Vector2i, p: Placement) -> Array:
	## 闪现候选排序键（字典序，越小越好）：
	##   ① **能打到我方单位才算有效落点**（0 优于 1）；
	##   ② 能打时：目标血量越低越好（易击杀）、力量越高越好（威胁大）；
	##   ③ 平手时**原地优先**（manhattan 0）→ 不会无意义乱跳；末位按格位定序（确定性可复现）。
	##
	## ⚠️ R379（用户口径「必须确保自己能攻击到敌方单位才移动」）：
	##   **这里不再有「打不到就往前靠」那一档**。闪现是全场任意空格、不受距离与阻挡影响 ——
	##   「离得近」不积累任何优势（下回合照样能从任何一格闪到最优位），单纯挪位置只是
	##   白烧一次行动，玩家看到的就是「AI 抽风乱跳」。
	##   于是「一个落点都打不到」时所有候选在 ①②上完全平手 → ③ 原地胜出 →
	##   `_assassin_step` 返回 null → 这回合按兵不动，把局面交给能打到的同伴
	##   （鸭子骑士 / 鸭之暗面）处理。
	var targets:= attack_targets(dst, SIDE_OPPONENT, p.card)
	var can_hit:= 1 if targets.is_empty() else 0
	var t_hp:= 999
	var t_pow:= 0
	if not targets.is_empty():
		var q:= state.unit_at(_ai_pick_card_target(targets, p))
		if q != null:
			t_hp = q.health if q.health > 0 else 999
			t_pow = q.effective_power()
	return [can_hit, t_hp, - t_pow, manhattan(src, dst), dst.x, dst.y]


func _assassin_step(src: Vector2i, p: Placement) -> Variant:
	## 选出要闪现到的格子；null = 原地更好（不动）。
	var best: Vector2i = src
	var best_key:= _assassin_cell_key(src, src, p)
	for dst in _assassin_cells(src):
		if dst == src:
			continue
		var k:= _assassin_cell_key(src, dst, p)
		if k < best_key:
			best_key = k
			best = dst
	if best == src:
		return null
	return best


func _assassin_act(cell: Vector2i, p: Placement) -> void :
	## 鸭子暗杀者专属 AI（R111）：行动时先闪现到最优空格，再打射程内的我方单位。
	## 它打不到对方 HP（hp_targets 已门禁），所以只要「找最好落点 → 打得到就打」。
	## R379：**打不到就不闪**（`_assassin_cell_key` 里已去掉「逼近」档）——
	## 闪现全场可达，挪位置换不来任何下回合优势，只会白烧一次行动。
	var dst = _assassin_step(cell, p)
	if dst != null:
		move(cell, dst, SIDE_OPPONENT, true)
		if over:
			return
		var moved:= state.unit_at(dst)
		if moved == null:
			# R400（用户报「敌人 AI 卡死」）：闪现**没落地**也必须横置。
			# 不 tap 的话 `ai_action_queue()` 下一拍又把它排回队首 → 敌方回合永远不结束。
			# 已知三种起因：被禁足（`rooted > 0`，冰霜陷阱）、本回合已移动过
			# （`moved` 且 `acts_left <= 1`）、落点被占。
			# ⚠️ 普通 AI 那条早有 `_tap(p, "AI：推进失败")` 兜底，暗杀者这条 R111 漏了。
			# ⚠️ 还要先确认它仍在场上：闪现途中被陷阱当场打死时 `_cell_of()` 是 (-1,-1)，
			#    对一个已离场的对象调 `_tap()` 会 emit 一个不存在的格子。
			if _cell_of(p) != Vector2i(-1, -1):
				_tap(p, "AI：暗杀者闪现未落地（禁足 / 已移动 / 落点被占）")
			return
		cell = dst
		p = moved
	if _ai_attack_if_any(cell, p):
		return
	_tap(p, "AI：暗杀者按兵不动（这一格怎么闪都打不着，交给同伴）")


# ================= R111：暗影领主成长 / 暗杀召唤 =================

func _refresh_dark_lord(side: String) -> void :
	## 鸭之暗面（9124）：「暗影领主」单位按**己方存活暗杀者数**获得 +3 力 / +1 速。
	## ⚠️ 只改 Placement 字段（`dark_lord_atk` / `dark_lord_speed`），**不碰 card** ——
	## 敌方关卡单位用的是卡库共享实例，写 card 会跨局泄漏；不写 card 也就无需离场还原。
	## 调用点 = 数量会变的三处：开局/召唤、单位被击破、每个回合开始。
	var n:= 0
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q.owner == side and q.card.traits.has(ASSASSIN_TRAIT):
			n += 1
	for c2: Vector2i in state.board:
		var p: Placement = state.board[c2]
		if p.owner != side or not p.card.traits.has(SHADOW_LORD_TRAIT):
			continue
		p.dark_lord_atk = n * DARK_LORD_ATK_PER_ASSASSIN
		p.dark_lord_speed = n * DARK_LORD_SPEED_PER_ASSASSIN


# ================= R152：赫卡同克瑞斯孤军 =================

func _refresh_hecaton(side: String) -> void:
	## 赫卡同克瑞斯（9136）：场上**只有它一个**己方单位时，孤军 buff 成立
	## → `hecaton_atk = HECATON_ATK_BUFF`（+2 力），否则归 0。
	## 与 `_refresh_dark_lord` 完全同范式：只写 Placement 字段、不碰 card，
	## 调用点 = 数量会变的五处：双方回合开始、开局（enable_enemy_effects）、
	## 单位被击破、召唤落地。
	var n:= 0
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q.owner == side and q.health > 0:
			n += 1
	for c2: Vector2i in state.board:
		var p: Placement = state.board[c2]
		if p.owner != side or p.card.id != HECATON_ID:
			continue
		var before:= p.hecaton_atk
		p.hecaton_atk = HECATON_ATK_BUFF if n == 1 else 0
		if p.hecaton_atk != before:
			_log("赫卡同克瑞斯孤军：%s（场上己方单位数 %d）" % [
					"力 +%d、攻击伤害减半" % HECATON_ATK_BUFF if p.hecaton_atk > 0 else "失效",
					n])


# ================= R270：夜鸭「惧光」 =================

func _refresh_night_owl() -> void:
	## 夜鸭（9027）：**奇数回合**（`turn_number % 2 == 1`，即玩家看到的第 1/3/5… 回合）
	## 移动速度 -1、攻击距离 -1，偶数回合恢复 —— 用户口径「削弱夜鸭：奇数回合时，
	## 移动速度攻击距离-1」。
	## R324 追加：同一回合内力量**临时减半**（用户口径「攻击力也临时减半，仅临时，
	## 不要和原本永久加攻冲突」）—— 减半不在这里做，只在 `Placement.effective_power()`
	## 的出口按本字段折半，于是永久加攻（夜行 / 各类 atk_buff）的字段分文不动。
	## 与 `_refresh_dark_lord` 同范式：**只写 Placement 字段、不碰 card**
	## （敌方关卡单位用的是卡库共享实例，写 card 会跨局泄漏；不写 card 也就无需离场还原）。
	## 调用点 = 双方回合开始各一次（`_begin_turn` 两个分支）+ 开局
	## —— 同一个「回合」内两侧看到的状态一致，夜鸭不会因为换边而忽强忽弱。
	## ⚠️ 一律用 `turn_number`（我方回合数）判奇偶，**不要用 `turn_total`**：
	##    后者双方各 +1，敌方回合永远是偶数 → 夜鸭等于没被削。
	var weak:= NIGHT_DUCK_WEAK if turn_number % 2 == 1 else 0
	# R340：敌方效果区有「永夜」（9178）→ 夜鸭永不虚弱（奇数回合也按 0 结算）。
	# 只影响**敌方**夜鸭：`state.enemy_effects` 是对方的常量区，玩家侧的夜鸭不吃这条。
	if weak > 0 and _zone_has(state.enemy_effects, ETERNAL_NIGHT_TRAIT):
		weak = 0
	for c: Vector2i in state.board:
		var p: Placement = state.board[c]
		if p.card != null and p.card.id == NIGHT_DUCK_ID:
			p.night_owl_weak = weak


func _assassin_summon(side: String, initial:= false) -> void :
	## 暗影召唤（9125，R111）：效果区有「暗杀召唤」时，**战斗开始时**（initial=true）
	## 以及**每 value 个回合**召唤一只鸭子暗杀者 —— 落在**己方半场**的空格
	## （不空手压到对面半场）；半场满则跳过。召唤后立刻重算暗影领主加成。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var interval:= 0
	var src:= "暗杀召唤"
	for c: CardData in zone:
		if c.traits.has(ASSASSIN_SUMMON_TRAIT) and c.value > interval:
			interval = c.value
			src = c.card_name
	if interval <= 0:
		return
	if not initial:
		var tick:= turn_number if side == SIDE_SELF else opp_turns
		if tick % interval != 0:
			return
	var repo:= CardRepo.load_json()
	var card: CardData = repo.get_card(ASSASSIN_ID)
	if card == null:
		return
	var spot:= _random_free_half_cell(side)
	if spot == Vector2i(-1, -1):
		_log("%s：己方半场已满，无法召唤鸭子暗杀者" % src)
		return
	var copy:= CardData.from_dict(card.to_dict())
	var summoned:= state.place(copy, spot, side, true)
	_log("%s%s：召唤了一只鸭子暗杀者（%s）" % [
			src, "（开局）" if initial else "（每 %d 回合）" % interval, spot])
	action.emit("place", {"cell": spot, "card": copy, "side": side})
	_on_ally_entered(summoned, side)
	_refresh_dark_lord(side)
	_refresh_hecaton(side)
