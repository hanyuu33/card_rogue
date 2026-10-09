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
var log: Array[String] = []
var rng:= RandomNumberGenerator.new()
var self_relics: Array[int] = []
var _unit_played_this_turn:= false
var turn_dmg_bonus:= 0
var duck_revive_chance:= 100
var turn_spell_bonus:= 0
var _rice_used:= false
var crow_pending:= false
var whale_pending:= false
var revive_pending:= false   # 复活术（9078）：等玩家从弃牌区选盟友
var revive_remaining:= 0     # 还要选几张（蓄力让这张卡生效 2 次 → 2 张，一张一张选）
var shadow_step_pending:= false   # 暗影步（9121）：等玩家从弃牌区选一张（任意 kind）
var shadow_step_remaining:= 0     # 还要选几张（蓄力让这张卡生效 2 次 → 2 张）
var shadow_step_label:= "暗影步" # 面板标题（复用复活术那套面板时区分文案）
var focus_pending:= false      # 专注（9122）：等玩家从**抽牌库**里选 2 张卡移除
var focus_remaining:= 0        # 还要移除几张
var whale_remaining:= 0
var foresight_mode:= false  # 预判（9097）：等玩家选效果①/②
var foresight_pick:= false  # 预判①：等玩家从弃牌区选一张 0 费技能卡
var foresight_vanish:= false  # 预判①选完后：把本卡从弃牌区移除（本卡消失）
var fate_pending:= false    # 拒绝命运（9098）：等玩家从弃牌区选回 fate_count 张
var fate_count:= 0
var endless_pending:= false  # 无尽黑暗 9114（R70）：等玩家从**手牌**里选 1 张弃掉
var _aether_left:= 0
var _aether_used:= false
var _stoneskin_left:= 0
# 「每回合第 X 次」的 X = 效果区张数 → 用计数记录本回合已触发几次（回合开始归零）
var _roar_fires:= 0
var _space_fires:= 0
# 虚空主宰（9082）：技能结算窗口 —— 窗口内只要有伤害落在敌方身上就记一次（见 _mark_spell_enemy_hit）
var _spell_active:= false
var _spell_hit_enemy:= false
# 流星雨（9083）：本次施放消耗的能量（X）—— 在 _pay 之前抓取（见 use_spell / remote_spell）
var _x_spell_value:= 0
# 火墙术（9084）：正在燃烧的横行。每项 {side, row, pass_dmg, dealt}；
# dealt 记录每个单位已从这面火墙吃到的伤害（同一单位累计上限 FIRE_WALL_CAP）。
# 熄灭时机 = 施放方的下次回合开始（_begin_turn → _clear_fire_walls）。
var _fire_walls: Array = []
# 蓄力（9085）：该方「下一张技能多结算几次」的待用层数（按阵营记账，用掉即清）。
# 结算次数 = 1 + 层数（1 层 = 生效 2 次）；见 _charge_add / _charge_take。
var _charge: Dictionary = {}
# 闪躲（9103）：自己直到**下个回合开始**前，HP 伤害改由随机一个己方盟友代受。
# 用法：施放时置 true；_begin_turn(SIDE_SELF) 时清 false（覆盖了中间的敌方回合）。
var _dodge_active:= false
var growth_cfg: Dictionary = {}   # 关卡成长曲线配置（空 = 不启用）；只对敌方单位生效
var _growth_stacks:= 0            # 已累计的成长层数（+1 层 = 每人 +inc 攻击力）

const DUCK_REVIVE_STEP:= 25

const BLAZE_DUCK_ID:= 9020
const BLAZE_DUCK_DAMAGE:= 10

const HEALER_TRAIT:= "治疗"
const KILN_TRAIT:= "孵化"
const KILN_CARD_ID:= 9025
const CERAMIC_CARD_ID:= 9026
const EGG_CARD_ID:= 9022


const TAUNT_TRAIT:= "嘲讽"
const SPELL_IMMUNE_TRAIT:= "法术免疫"
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
const ICECREAM_ENERGY:= 4
const ICECREAM_DRAW:= 3
const ICECREAM_LINE:= "你跑不过我你信吗"
const HEAVY_DUCK_RELIC_ID:= 6017
const EGG_DUCK_RELIC_ID:= 6018
# 鸭翼（6007）：第 3 回合的额外费用。R81 由 2 点加强到 3 点。
# 抽成常量是为了让「数值」只有这一处 —— 卡面文案与回归断言都对着它写。
const DUCK_WING_RELIC_ID:= 6007
const DUCK_WING_TURN:= 3
const DUCK_WING_ENERGY:= 3


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
const DRAGON_BREATH_DMG:= 3
const DRAGON_BREATH_HITS:= 6
const FRENZY_ID:= 9055
const FRENZY_ACTIONS:= 2
const FRENZY_DISCOUNT:= 1
const FRENZY_ALLY_MIN:= 3



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

const AETHER_ROAR_ID:= 9063
const AETHER_ROAR_TRAIT:= "以太咆哮"
const SPACE_GUARD_ID:= 9064
const SPACE_GUARD_TRAIT:= "空间守护"
const SELF_HEAL_ID:= 9065
const SELF_HEAL_TRAIT:= "自愈"
const STONESKIN_ID:= 9066
const STONESKIN_TRAIT:= "石肤"
const AETHER_GUARD_ID:= 9067
const AETHER_GUARD_TRAIT:= "以太守卫"
const AETHER_GUARD_CAP:= 5
const AETHER_DEMON_ID:= 9068
const AETHER_DEMON_TRAIT:= "以太恶魔"
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

# ── 第 37 轮（2026-10-01）新卡 ──
# 魔法塔（9075 工事）：在场时，该方「伤害类技能」原本费用每 1 点 → 额外 1 点伤害。
const MAGIC_TOWER_TRAIT:= "魔法塔"
# 魔力核心（9076 效果）：每回合使用的第一张技能卡费用 -1、伤害 +1（效果区多张不叠加）。
const MAGIC_CORE_TRAIT:= "魔力核心"
const MAGIC_CORE_DISCOUNT:= 1
const MAGIC_CORE_DMG:= 1
# 陨石术（9077 技能）：10 费；十字范围 40 伤、不分敌我；「留手」不弃；每次用技能永久 -1。
const METEOR_ID:= 9077
const METEOR_DMG:= 40
# 复活术（9078 技能）：从弃牌区取一张盟友回到手卡。
const REVIVE_ID:= 9078
# 魔像术（9079 技能）：在己方半场召唤魔像；每用一张技能，手卡里这张本回合 -1。
const GOLEM_SPELL_ID:= 9079
const GOLEM_ID:= 9080
const GOLEM_TRAIT:= "魔像"
# 魔法学徒（9081 盟友）：从卡组取一张随机技能卡入手；本回合出牌费用 -1。
const APPRENTICE_ID:= 9081

# ── 第 38 轮（2026-10-01）新卡 ──
# 虚空主宰（9082 盟友）：10 费 7/20 程2 速1。两条费用机制都挂在 cost_of 链上（显示=判定=实扣）。
# ① 在场时：该方技能牌费用 -1（多张叠加 —— 按该方场上本卡张数算）。
# ② 本次对战中每用技能牌对敌方造成一次伤害：手卡里的本卡费用 -2（本场战斗内累计，不跨战斗）。
const VOID_LORD_ID:= 9082
const VOID_LORD_TRAIT:= "虚空主宰"
const VOID_LORD_PRESENCE_DISCOUNT:= 1
const VOID_LORD_DMG_DISCOUNT:= 2

# ── 流星雨（9083 技能，2026-10-01）──
# X 费卡：施放瞬间 X = 该方剩余的全部能量，一次性全部消耗（类杀戮尖塔）。
# 对随机敌人造成 METEOR_SHOWER_DMG 点伤害、重复 X 次，每次独立随机选目标；
# 费用挂 cost_of（显示=判定=实扣），X 在 use_spell / remote_spell 里**扣费之前**抓取。
const METEOR_SHOWER_ID:= 9083
const METEOR_SHOWER_DMG:= 9

# ── 火墙术（9084 技能，2026-10-01）──
# 3 费普通技能：对一横行的敌人造成 FIRE_WALL_DMG 点伤害；该横行持续燃烧到**施放方**
# 的下次回合开始，期间任何单位（不分敌我）移动经过该行 → 再受 FIRE_WALL_PASS_DMG 点。
# 同一个单位从这张卡身上累计最多吃 FIRE_WALL_CAP 点（全卡合计上限，不是单次上限）。
const FIRE_WALL_SPELL_ID:= 9084
const FIRE_WALL_DMG:= 15
const FIRE_WALL_PASS_DMG:= 10
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
const BEAR_ID:= 8004
const BEAR_TRAIT:= "回春"
const BEAR_HEAL:= 6
const WILD_FORM_RELIC_ID:= 6022
const WILD_FORM_REDUCE:= 4        # 第一次受击减伤
const WILD_FORM_RETALIATE:= 4     # 并对攻击者反伤

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
# 预判（9097 技能）：0 费史诗；二选一：①弃牌区选一张 0 费技能卡（之后本卡消失）
# ②卡组随机非 0 费技能卡入手。面板走 foresight_* 状态机。
const FORESIGHT_ID:= 9097
# 拒绝命运（9098 技能）：2 费史诗；弃掉全部手卡 → 从弃牌区选等量的卡（必须选满）→ 本卡消失。
const FATE_REJECT_ID:= 9098
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
#   任何减费（魔力核心 / 虚空主宰 / 小精灵…）都不能把它降到 0，否则 0 费无限回手。
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
const FROST_TRAP_DMG:= 4
const FREEZE_TRAP_ID:= 8013
const FREEZE_TRAP_TRAIT:= "冻结陷阱"
const FREEZE_TRAP_DMG:= 3
const POISON_TRAP_ID:= 8014
const POISON_TRAP_TRAIT:= "剧毒陷阱"
const POISON_DMG:= 6
const POISON_TURNS:= 4
const TRAP_MASTERY_ID:= 9105
const TRAP_MASTERY_TRAIT:= "场地精通"   # 9105 陷阱精通 R74 改名：口径从「工事」改成「场地」

# 机关工坊（8015 工事，R52 起；R74 改名「陷阱工坊」→「机关工坊」）：
#   **它仍然是「工事」，不属于场地卡**（卡名去掉「陷阱」只是文案去混淆）。
#   回合开始随机把一张本角色奖励池的工事加入手卡；被敌人的普通攻击**破坏**时对攻击者
#   造成 WORKSHOP_DMG 点伤害。注意它吃的是**场地精通**加成（原「陷阱精通」口径）。
const WORKSHOP_ID:= 8015
const WORKSHOP_TRAIT:= "机关工坊"
const WORKSHOP_DMG:= 8
const AMBUSH_ID:= 9106   # 紧急埋伏（9106 技能）：从**卡组**取工事 + 下一张工事 -1 费（工事口径不变）
const HUNT_ID:= 9107     # 暗影狩猎（9107 技能）：目标上回合触发过**场地** → 12 伤改 24 伤
const HUNT_DMG:= 12
const HUNT_BIG_DMG:= 24

const PIERCE_TRAP_ID:= 8016
const PIERCE_TRAP_TRAIT:= "穿刺陷阱"
const PIERCE_TRAP_DMG:= 18

# ── R83：清泉（8028）—— 场地卡的**第二个机制类别：持续型** ──
# 现有 6 张场地（8011~8017）全是「**一次性触发**」：敌人移动经过 → 结算 → 该格消失。
# 清泉反过来：**不因任何经过而触发、不会消失**，只是「站在这格的单位在自己回合结束时 +2 血」。
# 于是它**必须被排除出陷阱那条链**（否则敌人一走过就被白白消耗掉，这张牌等于废）：
#   * `_field_block_index` 跳过它 → 敌人正常走过、不被拦停；
#   * `_field_trigger` 早退 → 不会被摘掉，也不会记「暗影狩猎」的触发标记；
#   * `_twin_field_chain` / 界面双重场地候选也排除 → 不会被附魔（附魔永不触发＝白花一张牌）。
# 判据是 **trait「持续场地」**（R83 新增），走 cards.json —— 加新的持续型场地只要写这个 trait。
const FOUNTAIN_ID:= 8028
const PERSISTENT_FIELD_TRAIT:= "持续场地"
const FOUNTAIN_HEAL:= 2
# ── R88：持续型场地的第二族（「改造工厂」8037）──
# 维修间 8036（1 费稀有，机械之心）：站在上面的**己方**盟友/工事在自己回合结束时回
#   `CardData.field_heal` 点血。**与清泉 8028 是同一族机制、只差生效对象**（清泉「双」）。
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
# ── R89：无限装甲 8038（机械之心史诗盟友 4 费 4/18/1/1）──
# 「**每回合一次**：这张卡被「改造」时，随机一张**效果含「改造」的技能卡**加入手牌，
#  那张牌在手牌里费用为 0，离开手牌后恢复原价。」
#
# 三个实现决定（用户当时已睡，按最合理口径定的，写在这里供日后核对）：
#  ① **候选池 = 本角色奖励卡池**里筛「技能 + effect_text 含『改造』」
#     —— 与「双重场地」`_twin_field_chain` 取场地卡同源口径（不是牌组，是卡池）。
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
const BATCH_TRANSFER_DRAW:= 1    # 批量传输：改造完抽 1 张卡
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
# 「自主升级」（8045，2 费效果卡）：**回合开始时**随机使**抽牌堆**里一张盟友或工事
#   获得改造：+2 攻 / +1 血。
#   * 候选只从 `state.deck`（抽牌堆）挑 —— 与「过载」8030 / 「能量屏障」8033 同口径。
#   * 改造**烤进那张卡**（`from_dict` 复制 + 原位替换）→ 本场战斗永久，且不污染卡库
#     （下一场 `RunState.build_deck()` 重新取卡库实例 = 原卡）。
#   * 效果区有多张时**不叠加**（符合效果区一贯惯例）：每回合只改造 1 张。
const AUTO_UPGRADE_ID:= 8045
const AUTO_UPGRADE_TRAIT:= "自主改造"
const AUTO_UPGRADE_ATK:= 2
const AUTO_UPGRADE_HP:= 1
# ── R96：机械之心 8046 / 8047 / 8048 ──
# 「零件回收者」（8046，3 费**普通**盟友 1/14/1/1）：与这张卡**接通**的己方盟友或工事被
#   **破坏**时，这张卡攻击力 += 被销毁卡的力量，并往手牌加一张「素体」。
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
const AFFIX_SWAP:= "交换"
const UPGRADE_RANGE_TRAIT:= "改造攻程"
const UPGRADE_SPEED_TRAIT:= "改造移速"
const UPGRADE_DRAW_TRAIT:= "改造抽牌"
## 双向传送（8061 技能，R102）：0 费；指定战场上**两个单位**，交换它们的位置。
# 两段操作：UI 先点单位甲、再点单位乙 → engine.cast_swap_units()；
# 敌方 AI / 自动出牌走 use_spell 的自动兜底（见 _run_spell_effect）。
const SWAP_UNITS_ID:= 8061
## 「能量屏障」8033 赋的护盾也登记成字段（R91）—— 否则这张牌被强化后
## 玩家在任何地方都看不到「它有护盾」。
const FIELD_BARRIER:= "护盾"
# 双重陷阱（9108 技能，R53）：2 费普通；只能指定**自己场上的一个工事**，给它附魔：
#   该工事**被破坏后**（任何破坏手段：普通攻击 / 技能 / 效果 / 直击 HP），
#   在**同一个格子**召唤一张随机「名字带『陷阱』的工事」—— 取自本角色的**奖励卡池**
#   （敌方侧退化为完整奖励池），与陷阱工坊供牌同一来源；格子已被占（如亡语先占了）则召唤失败。
#   R74：标记改记在 FieldState.field_chains（挂在**格子**上），触发口唯一 = _twin_field_chain。
const DOUBLE_TRAP_ID:= 9108

# 巨物陷阱（8017，R54 起是「巨物捕获」工事；**R76 改成场地卡并改名**）：2 费稀有。
#   口径跟其它场地卡一致：不是单位、钉在一个格子上、**敌人移动经过此格**时触发一次
#   （R80：路过即中，不必停留）**并立刻停止这次移动**，之后该格场地消失
#   （每格最多 1 个，按场地生效·敌不能放自己后排），吃场地精通加成。
#   原来那套「被打中没破坏就回手 / 破坏就反伤 2×攻击力」是工事专属机制，
#   场地卡不会被攻击（也不在 board 里），所以那两个分支已全部删除。
const MASS_TRAP_ID:= 8017
const MASS_TRAP_TRAIT:= "巨物陷阱"
const MASS_TRAP_DMG:= 12

# ---- R105（2026-10-08）黑暗陷阱 8063 ----
# 黑暗陷阱（8063 场地，暗影刺客·普通）：**0 费**；敌人**移动经过**此格时立刻触发
#   （R80 口径：路过即中，不必停留）并**立即停止这次移动** →
#   **那个敌人本回合攻击时力量 -1**。
# 与冰霜陷阱（8012 禁足）/ 冻结陷阱（8013 冰冻）同族：都不造成伤害，只给**状态**。
# 降力量复用「威慑 / 敲晕 / 幻影斗篷 / 回响」那套 `atk_debuff + debuff_stage = 1`：
#   debuff_stage=1 = **立即生效**，在**该单位所属方的回合结束时**清除 ——
#   陷阱是敌方移动时踩的（= 敌方回合内），所以正好覆盖「它本回合剩下的攻击」。
# ⚠️ 0 费 → 场地精通（9105）加成是 2×0 = 0；这张本来就不造成伤害，加成无意义。
const DARK_TRAP_ID:= 8063
const DARK_TRAP_TRAIT:= "黑暗陷阱"
const DARK_TRAP_DEBUFF:= 1      # 本回合攻击时力量 -1

# ---- R116（2026-10-09）捕兽大师 9126 ----
# 捕兽大师（9126 盟友，暗影刺客·**史诗**）：3 费 2/8 程1 速1。
#   **亡语：在原地留下一张随机陷阱。**
# * 「随机陷阱」= 本角色奖励池里的**一次性场地**（唯一口 `_trap_card_pool`）；
#   与「双重场地」9108 / 机关工坊 8015 同一来源。判据**不写死卡名 / id** ——
#   往后加新陷阱、或给别的角色加陷阱，这里一行都不用改。
# * 原地已有场地效果时**不覆盖**（那张多半是玩家自己埋的）→ 见 `_deathrattle_place_trap`。
const TRAPPER_ID:= 9126
# 活体栅栏（8018 工事，R54）：2 费稀有；2/8/1。可攻击的【栅栏】类工事（带 FENCE_TRAIT，
#   可参与「叠栅栏」）；本身无其它特殊机制。
const LIVING_FENCE_ID:= 8018
# 警觉（9109 技能，R54）：2 费稀有。**第 1 回合必定抽到**（开局把牌库里那张挪到牌库顶）；
#   使用时把一张随机工事（本角色奖励池）加入手卡，那张卡**本回合内**费用 -ALERT_DISCOUNT
#   （R60 改：用 state.turn_card_discount 本回合减费表，回合结束清空 → 不跨回合；
#   显示 = 判定 = 实扣都走 cost_of）。技能卡本身用完照常进弃牌区。
const ALERT_ID:= 9109
const ALERT_DISCOUNT:= 2

# ---- R55「回合结束 · 剩余费用」系列（2026-10-03）----
# 三张卡共用**一个结算入口** _end_turn_surplus()：自己回合结束、能量清零**之前**调用，
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
# 地狱咏唱者 8022（3 费普通盟友 1/11/程2/速1）+ 黑暗祭坛 8023（3 费普通工事 1/15/程1）：
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

# ---- R103（2026-10-07）夜蚀 8062 ----
# 夜蚀8062（2 费史诗盟友 2/8/程1/速1）：**自己回合结束时**，回复 X 点生命值，
#   X = **自己剩余费用**（state.energy_of(side)，即这张卡读的是「本回合没用完的钱」，
#   与地狱猫 8019 / 鲜血堡垒 8020 / 活力转移 9110 / 暗影锁链 9112 同一口径）。
# 与那几张的**关键区别**：那几张给的是**永久成长**（Placement.end_atk / 直接加 p.health，
#   等于抬上限），夜蚀是**回复**（把已损失的血补回来，**上限仍是卡面 health**），
#   所以走的是 _regen_tick 那一套「不满血才回、mini 夹上限」的口径。
# 结算入口同样挂在 _end_turn_surplus()（能量清零之前），读同一个 left。
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
const FOCUS_NEED:= 2            # 要从抽牌库移除几张# 白魔法师（9021）「精进」：自己的回合开始时，本方带此 trait 的单位力量 +MAGE_GROW_BUFF
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
# 「升级」（8027，2 费技能，机械之心）：改造一个己方盟友或工事 → +2 攻 / +8 血。
# 加成**只在场上有效**、离场由 _card_leaving_field 还原（不烤进 CardData）。
# R84：每张卡**自己的**改造奖励（素体 +1 血 / 战斗骨骼 +1 力 +1 血）**读卡面字段**
# `CardData.upgrade_atk_bonus` / `upgrade_hp_bonus` —— 不再在这里按卡名硬编码，
# 所以以后加新盟友只要填字段，引擎一行都不用动。
const UPGRADE_ID:= 8027
const UPGRADE_TRAIT:= "改造"
const UPGRADE_ATK:= 2
const UPGRADE_HP:= 8
const PROTO_TRAIT:= "素体"       # 仅供界面/图鉴筛「素体」用；判定已改读卡面字段
const PROTO_ID:= 8025
const CONSTRUCT_ID:= 8026       # 构装体（3 费 3/8/1/1，本体无机制，只是厚实的盟友）
const BATTLE_BONE_ID:= 8029     # 战斗骨骼（2 费 2/7/1/1，改造时 +1 力 +1 生命）
# 「过载」（8030，**史诗**技能，机械之心，R85）：从**牌库**里随机一张
# 「还没有一回合行动两次」的盟友，给它加上这个特性（**永久**改牌）。
# 「一回合行动两次」= `CardData.actions >= 2`（**没有**对应 trait，判据就是这个字段）——
# 现有 5 张卡自带：灰烬龙 1013 / 亡灵领主 1051 / 熔岩巨人 1071 / 鸭子队长 9012 / 白狼 9031。
# 口径（已与用户确认）：候选**只从 state.deck（抽牌堆）**里选，与 `_fetch_skill_card` 同口径；
# 选中的卡**原位替换**，不抽到手上、不改变洗牌序列（录像回放因此天然一致）。
const OVERLOAD_ID:= 8030
const OVERLOAD_TRAIT:= "过载"
const DOUBLE_ACTION:= 2          # 「一回合行动两次」的 actions 值（= 卡面自带双动的口径）
# 「批量改造」（8031，1 费技能，机械之心，R86）：手牌里**所有盟友和工事**生命 +1，
# **整场战斗内有效**（回合结束弃回牌库、再抽到仍带）。改的是**手牌里的副本** ——
# `build_deck` 给的是卡库共享实例，不复制就会跨 run 泄漏。
const BATCH_UPGRADE_ID:= 8031
const BATCH_UPGRADE_HP:= 1
# 「侦察塔」（8032，3 费工事，机械之心，R86）：0 攻 / 12 血 / **攻程 2**。
#   * **0 攻也能攻击** —— 用户口径「只有 0 攻程不能攻击」；引擎的 `attack_targets`
#     本来就只看 `attack_range` 不看 `power`，所以无需改引擎。
#   * 「每层改造使攻击范围内的敌人受到伤害 +1」→ 伤害 = 改造的 +2 力量 **+ 层数**
#     （`Placement.upgrade_stacks`，由 `_upgrade_unit` 每次 +1）。
#   * 只有**带 trait「改造层数」**的卡才吃到层数加成（见 Placement.effective_power）——
#     否则 0 攻工事改造几次就能自己打人。
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
const GROWTH_STRONG_ATK:= 7       # 基础攻击力 >= 这个数 → 算「强力怪」，吃 mod_strong

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
#   ① 开场即「沉睡」SLEEP_TURNS(2) —— Placement.sleep_left > 0 时不能行动；
#      睡满后自己在回合开始醒来（唯一递减口 = end_turn 里的 _sleep_tick）。
#   ② 受到伤害时（唯一判定口 = _hit_unit）：还在睡 → sleep_left -1，**减到 0 立刻能行动**
#      （R76 用户口径：不是「提前 1 回合」，而是每次挨打 -1、打空即醒）；
#      已醒 → end_atk +1（永久加攻，进 effective_power）。
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


func _init(state_: FieldState) -> void :
	state = state_


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func back_row(side: String) -> int:
	return 0 if side == SIDE_OPPONENT else FieldState.BOARD_ROWS - 1


static func forbidden_row_for(side: String) -> int:

	return back_row(SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF)


static func hp_row_owner(row: int) -> String:


	if row == back_row(SIDE_OPPONENT):
		return SIDE_OPPONENT
	if row == back_row(SIDE_SELF):
		return SIDE_SELF
	return ""


func start_game(starting_hand:= 0, opponent_deck:= 50, i_start:= true) -> void :
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
	if over:
		return true
	if state.hp_opponent <= 0:
		_finish("胜利", "敌方 HP 归零")
		return true
	if state.hp_self <= 0:
		if _try_revive():
			return false
		_finish("失败", "我方 HP 归零")
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
		state.energy = FieldState.ENERGY_PER_TURN
		if state.turn_limit >= 0 and turn_number > state.turn_limit:
			turn_number = state.turn_limit
			_finish("失败", "%d 回合内未击破敌方 HP" % state.turn_limit)
			return

		_tick_enemy_growth()
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
			_log("鸭语耳环：本回合能量 +1")

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
			_log("冰淇淋与汽水：第 1 回合额外 +%d 能量、多抽 %d 张"
				%[ICECREAM_ENERGY, ICECREAM_DRAW])
			action.emit("icecream", {"text": ICECREAM_LINE, 
				"energy": ICECREAM_ENERGY, "draw": ICECREAM_DRAW})


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
		if turn_number == 1:
			_ensure_opening_card(ALERT_ID)   # 警觉（9109）：第 1 回合必定抽到
		var drawn:= 0
		if self_relics.has(EARRING_RELIC_ID) and turn_number == 1:
			# R77：第 1 回合不抽牌，改为**逐张自动出牌**。这里只「启动」，
			# 真正的出牌由界面每帧推进一步（_autoplay_step）——
			# 原来在这里 while 一次跑完，玩家什么都看不见。
			# headless / 录像回放没有界面驱动，所以那种情况走同步版。
			if autoplay_stepwise:
				begin_earring_autoplay()
			else:
				drawn = _autoplay_from_deck()
				_log("鸭语耳环：第 1 回合不抽牌 → 自动出牌 %d 张" % drawn)
		else:
			drawn = _draw_many(FieldState.HAND_DRAW_PER_TURN + extra_draw)
		# 无尽黑暗 9114（R70 改）：抽牌之后**开选牌面板**，玩家选 1 张手牌弃掉
		# → 之后才给 2 点费用（费用在 endless_pick 里加，不在这里）。
		# 放在抽牌分支**之后**，这样「鸭语耳环自动出牌」那条分支也会照常触发。
		if _zone_has(state.effects, ENDLESS_DARK_TRAIT):
			_endless_dark(SIDE_SELF)
		_melt_ice_walls(SIDE_SELF)
		_clear_fire_walls(SIDE_SELF)
		_wisdom_surge()
		_endless_blessing()
		state.reset_units(SIDE_SELF)
		_poison_tick(SIDE_SELF)   # 剧毒陷阱：我方回合开始结算中毒
		_arm_debuffs(SIDE_SELF)
		_summon_familiars(SIDE_SELF)
		_effect_summons(SIDE_SELF)
		_apply_growth(SIDE_SELF)
		_night_growth(SIDE_SELF)
		_mage_growth(SIDE_SELF)
		_familiar_growth(SIDE_SELF)   # 使魔之力 9115：回合开始使魔鸭子 +1
		_demon_summon(SIDE_SELF)      # 恶魔使魔 9117：每 2 回合随机空格召唤使魔鸭子
		_apply_mech_growth(SIDE_SELF)
		_auto_upgrade(SIDE_SELF)          # 自主升级 8045（R95）：回合开始随机改造抽牌堆 1 张
		_dragon_breath(SIDE_SELF)
		_heal_aura(SIDE_SELF)
		_kiln_hatch(SIDE_SELF)
		_workshop_supply(SIDE_SELF)   # 机关工坊（R74 改名）：我方回合开始随机工事进手
		_clockwork_summon(SIDE_SELF)
		_latent_turn_draw(SIDE_SELF)
		_glowgrass_supply(SIDE_SELF)
		_ghost_self_destruct(SIDE_SELF)
		_assassin_summon(SIDE_SELF)
		_refresh_dark_lord(SIDE_SELF)
		_run_battlecries(SIDE_SELF)
		_log("── 我方第 %d 回合：能量重置为 %d%s%s%s%s%s%s（共 %d），抽 %d 张" % [
			turn_number, FieldState.ENERGY_PER_TURN,
			"（+%d 鸭翼）" % bonus_energy if bonus_energy > 0 else "",
			"（+%d 鸭语耳环）" % earring_energy if earring_energy > 0 else "",
			"（+%d 冰淇淋）" % ice_energy if ice_energy > 0 else "",
			"（+%d 活力转移）" % transfer_energy if transfer_energy > 0 else "",
			"（无尽黑暗：待选弃牌）" if endless_pending else "",
			"（鸭之低语：%s）" % whisper_txt if whisper_txt != "" else "",
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
		state.reset_units(SIDE_OPPONENT)
		_poison_tick(SIDE_OPPONENT)   # 剧毒陷阱：对方回合开始结算中毒
		_arm_debuffs(SIDE_OPPONENT)
		_summon_familiars(SIDE_OPPONENT)
		_effect_summons(SIDE_OPPONENT)
		_apply_growth(SIDE_OPPONENT)
		_night_growth(SIDE_OPPONENT)
		_mage_growth(SIDE_OPPONENT)
		_familiar_growth(SIDE_OPPONENT)   # 使魔之力 9115：回合开始使魔鸭子 +1
		_demon_summon(SIDE_OPPONENT)   # 恶魔使魔 9117：回合开始随机空格召唤使魔鸭子
		_apply_mech_growth(SIDE_OPPONENT)
		_auto_upgrade(SIDE_OPPONENT)      # 对称保留（敌方正常拿不到这张卡）
		_dragon_breath(SIDE_OPPONENT)
		_heal_aura(SIDE_OPPONENT)
		_kiln_hatch(SIDE_OPPONENT)
		_workshop_supply(SIDE_OPPONENT)   # 陷阱工坊（对称保留；敌方正常拿不到该卡）
		_clockwork_summon(SIDE_OPPONENT)
		_latent_turn_draw(SIDE_OPPONENT)
		_glowgrass_supply(SIDE_OPPONENT)
		_ghost_self_destruct(SIDE_OPPONENT)
		_assassin_summon(SIDE_OPPONENT)
		_refresh_dark_lord(SIDE_OPPONENT)
		_run_battlecries(SIDE_OPPONENT)
		_log("── 对手回合开始：能量 %d（上回合结束已清零，本回合重新发放基础费用），手牌 +%d" % [
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
	var summoned:= state.place(copy, spot, side)
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
	var summoned:= state.place(card, spot, side)
	_log("效果卡（每 %d 回合）召唤了鸭子骑士（%s）" % [interval, spot])
	action.emit("place", {"cell": spot, "card": card, "side": side})
	_on_ally_entered(summoned, side)


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


func _max_buff(side: String) -> int:
	var m:= 0
	for p: Placement in state.board.values():
		if p.owner == side:
			m = maxi(m, p.atk_buff)
	return m


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
		var card:= familiar if familiar != null else _fallback_familiar()
		var summoned:= state.place(card, spot, side)
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



	var got:= 0
	for i in n:
		if state.hand_full():
			_log("手牌已满（%d 张），不再抽牌" % FieldState.HAND_LIMIT)
			action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, 
				"hand": state.hand.size()})
			break
		if state.draw() != null:
			got += 1
	if got < n and state.deck.is_empty() and state.discard.is_empty():
		_log("没有卡牌可以抽了")
		action.emit("deck_empty", {})
	return got




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
				# 手牌满了就停 —— 不洗牌、不丢牌（与 _fetch_skill_card 同一口径）。
				if state.hand_full():
					_log("机械核心：手牌已满（%d 张），只加入 %d 张「素体」"
						% [FieldState.HAND_LIMIT, added])
					break
				# 独立副本：素体带「留手」，若与牌库里的共享实例同对象，
				# 回合结束的不弃判定与「按张记账」的表都会互相串。
				state.hand.append(CardData.from_dict(proto.to_dict()))
				added += 1
			if added > 0:
				_log("机械核心：开场手牌加入 %d 张「素体」（0 费 1/1，回合结束不弃）" % added)
				action.emit("relic", {"id": MECH_CORE_RELIC_ID,
						"text": "机械核心：手牌 +%d 张「素体」" % added})


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





	# 产物生命 X = 当前**该方**回合数（窑主人的第几回合）；首回合起算，至少 1。
	var x:= maxi(1, turn_number if side == SIDE_SELF else opp_turns)
	var repo:= CardRepo.load_json()
	for cell: Vector2i in state.board.keys().duplicate():
		var p:= state.unit_at(cell)
		if p == null or p.owner != side or not p.card.traits.has(KILN_TRAIT):
			continue
		var spawn: CardData = repo.get_card(p.card.value) if p.card.value > 0\
		else repo.get_card(CERAMIC_CARD_ID)
		if spawn == null:
			spawn = _fallback_ceramic()
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
			var body: CardData = CardData.from_dict(spawn.to_dict())
			body.health = x
			var hatched:= state.place(body, c, p.owner)
			born += 1
			action.emit("place", {"cell": c, "card": body, "side": p.owner})
			_on_ally_entered(hatched, p.owner)
		if born > 0:
			_log("%s 烧出 %d 只陶瓷鸭（生命 %d = 第 %d 回合）" % [
				p.card.card_name, born, x, x])


func _fallback_ceramic() -> CardData:
	var c:= CardData.new()
	c.id = CERAMIC_CARD_ID
	c.card_name = "陶瓷鸭"
	c.kind = "盟友"
	c.cost = 1
	c.power = 8
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
			var hatched:= state.place(spawn, spot, p.owner)
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
## 语义不变：能量不足 / 牌库抽空 / 手满 / X 费卡 / 无合法目标 → 停。
## R77：true = 逐张驱动（界面实机，能看到动画）；false = 一次性同步跑完（headless 回归 / 录像）。
## 由 battle_scene 在 _ready 里置 true；回归 / 录像保持 false 以免依赖帧。
var autoplay_stepwise := false
var earring_pending := false      # 是否处于「自动出牌中」
var earring_played := 0           # 已自动出了几张


func earring_autoplay_active() -> bool:
	## 界面侧判据：自动出牌是否还在进行中（用于锁住玩家操作）。
	return earring_pending


func _autoplay_from_deck() -> int:
	## **同步**跑完（headless 回归 / 录像回放走这条；界面实机走下面的逐张版）。
	var played := 0
	while played < EARRING_AUTOPLAY_MAX:
		if not _autoplay_step(played):
			break
		played += 1
		earring_played = played
	return played


func begin_earring_autoplay() -> void:
	## 开始自动出牌（不立即出牌）。界面侧每帧调 _autoplay_step 推进。
	earring_pending = true
	earring_played = 0
	action.emit("earring_autoplay_begin", {})


func _autoplay_step(played: int) -> bool:
	## **推进一步**（出一张牌）。返回 false = 该停了。
	## played = 已出的张数（只用于日志措辞，不参与判定）。
	if played >= EARRING_AUTOPLAY_MAX:
		_finish_earring_autoplay(played, "已达上限 %d 张" % EARRING_AUTOPLAY_MAX)
		return false
	if state.deck.is_empty() and state.discard.is_empty():
		_finish_earring_autoplay(played, "牌库已抽空")
		return false
	if state.hand_full():
		_finish_earring_autoplay(played, "手牌已满（%d 张）" % FieldState.HAND_LIMIT)
		return false
	var card := state.draw()
	if card == null:
		_finish_earring_autoplay(played, "抽牌失败")
		return false
	if state.energy < card.cost:
		_log("鸭语耳环：能量不足（%d < %d），停止自动出牌（%s 留在手里）"
			%[state.energy, card.cost, card.card_name])
		_finish_earring_autoplay(played, "能量不足")
		return false
	if not _autoplay_play(state.hand.size() - 1):
		_finish_earring_autoplay(played, "下一张无法使用")
		return false
	earring_played = played + 1
	# R77：每出一张都发一次事件 —— 界面据此播「抽牌 → 出牌 → 落位」三段动画。
	action.emit("earring_autoplay_step", {"index": played, "total": earring_played,
		"card_name": card.card_name, "cost": card.cost})
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
	if card.x_cost:
		# X 费卡（流星雨）：会一口气吃掉全部能量 → 自动出牌不碰它（留在手里）
		_log("鸭语耳环：%s 是 X 费卡，自动出牌跳过" % card.card_name)
		return false
	if card.is_spell():
		var targets:= _autoplay_spell_targets(card)
		if card.needs_target() and targets.is_empty():
			_log("鸭语耳环：%s 没有合法目标，无法自动使用" % card.card_name)
			return false
		use_spell(hand_index, targets[0] if not targets.is_empty() else null)
		return true
	if card.is_effect():
		use_effect(hand_index)
		return true
	if discard_cost_of(card) > 0:

		_log("鸭语耳环：%s 需要额外丢弃 %d 张手牌，自动出牌跳过"
			%[card.card_name, discard_cost_of(card)])
		return false

	var cell:= _autoplay_cell()
	if cell == Vector2i(-1, -1):
		_log("鸭语耳环：自己半场没有空格，无法放置 %s" % card.card_name)
		return false
	play_from_hand(hand_index, cell)

	if crow_pending:
		var crow_auto:= crow_options()
		if not crow_auto.is_empty():
			crow_recall(crow_auto[0])
	return true


func _autoplay_cell() -> Vector2i:

	var rows: Array[int] = [FieldState.OPPONENT_ROWS, FieldState.OPPONENT_ROWS + 1, 
		FieldState.BOARD_ROWS - 1]
	var cols: Array[int] = [FieldState.BOARD_COLS / 2, 0, FieldState.BOARD_COLS - 1]
	for row: int in rows:
		for col: int in cols:
			var c:= Vector2i(row, col)
			if not state.board.has(c):
				return c
	return Vector2i(-1, -1)


func _autoplay_spell_targets(card: CardData) -> Array[Vector2i]:


	var out: Array[Vector2i] = []
	if not card.needs_target():
		return out
	if card.id == ICE_WALL_SPELL_ID:

		out.append(Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2))
		return out
	if card.id == FIRE_WALL_SPELL_ID:
		# 火墙术：烧敌人最多的那条横行
		var fw_row:= -1
		var fw_best:= 0
		for r in FieldState.BOARD_ROWS:
			var n:= 0
			for cc in FieldState.BOARD_COLS:
				var q: Placement = state.unit_at(Vector2i(r, cc))
				if q != null and q.owner == SIDE_OPPONENT:
					n += 1
			if n > fw_best:
				fw_best = n
				fw_row = r
		if fw_row >= 0:
			out.append(Vector2i(fw_row, FieldState.BOARD_COLS / 2))
		return out
	var heal:= card.id in [2002, 7202]
	var pool:= _side_cells(SIDE_SELF if heal else SIDE_OPPONENT)
	if card.id == UPGRADE_ID or card.id == ARMOR_PLATE_ID:
		# 升级 8027（R82）/ 加厚装甲 8044（R95，机械之心）：自动出牌时选
		# **己方最值得改造的那一个** —— 优先级 = 力量。默认分支会选敌方单位，
		# 那样 `_upgrade_unit` / `_armor_plate` 会拒掉 → 这张牌等于白拿了一张。
		# ⚠️ 加厚装甲**只吃盟友**（工事会被引擎拒绝），所以这里按卡把候选收窄。
		var best_up := Vector2i(-1, -1)
		var best_pow := -1
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if card.id == ARMOR_PLATE_ID and up.card.kind != "盟友":
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if up.effective_power() > best_pow:
				best_pow = up.effective_power()
				best_up = uc
		if best_up.x >= 0:
			out.append(best_up)
		return out
	if card.id == DEMOLISH_ID:
		# 拆解 8049（R97，机械之心）：自动出牌时优先拆**己方被改造**的盟友/工事
		# （能拿到额外「升级」），没有则退而拆任意己方盟友/工事。
		var best_up := Vector2i(-1, -1)
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if best_up.x < 0 or (not _is_upgraded(state.unit_at(best_up)) and _is_upgraded(up)):
				best_up = uc
		if best_up.x >= 0:
			out.append(best_up)
		return out
	if card.id == REORG_ID:
		# 重组 8051（R99，机械之心）：自动出牌时只选**受伤**的己方盟友/工事
		# （生命未满），没有受伤单位就不自动出，免得浪费这张史诗牌。
		var best_r := Vector2i(-1, -1)
		var worst := 1 << 30
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			var missing := up.card.health - up.health
			if missing > 0 and missing < worst:
				worst = missing
				best_r = uc
		if best_r.x >= 0:
			out.append(best_r)
		return out
	if card.id == TRANSCEND_ID:
		# 超越极限 8053（R99，机械之心）：自动出牌时选一个**还没有超负荷**的
		# 己方盟友/工事（有了就跳过，避免重复给；全部都有则不出）。
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			if up.card.has_affix(AFFIX_OVERLOAD):
				continue
			out.append(uc)
		out.sort()
		return out
	if card.id == REBOOT_ID:
		# 重启 8054（R100，机械之心）：自动出牌时只选**受伤**的己方盟友/工事
		# （返回手卡能救回它并 0 费重铺，没受伤就不必浪费这张牌）。
		var best_r := Vector2i(-1, -1)
		var worst := 1 << 30
		for uc in _side_cells(SIDE_SELF):
			var up: Placement = state.unit_at(uc)
			if up == null:
				continue
			if up.card.kind != "盟友" and not up.card.is_fort():
				continue
			var missing := up.card.health - up.health
			if missing > 0 and missing < worst:
				worst = missing
				best_r = uc
		if best_r.x >= 0:
			out.append(best_r)
		return out
	var best:= Vector2i(-1, -1)
	var best_key:= 1 << 30
	for c: Vector2i in pool:
		var q: Placement = state.board[c]
		var key:= (maxi(1, q.card.health) - q.health) if heal else q.health
		if key < best_key:
			best_key = key
			best = c
	if best != Vector2i(-1, -1):
		out.append(best)
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
	# 沉睡（恶魔鸭 9116，R63）：**沉睡递减的唯一口** —— 本方回合结束时，
	# 本方还在睡的单位 sleep_left -1；减到 0 就此醒来（下一回合可行动）。
	# 恶魔鸭 SLEEP_TURNS=2 → 第 1、2 个己方回合不行动，第 3 回合起正常。
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

	if current_side == SIDE_SELF:
		var n:= state.discard_hand()
		_log("回合结束：弃掉 %d 张手牌" % n)
		# 使魔之夜的乌鸦只在给的那一回合免费 → 回合结束清掉免费名单
		if not state.turn_free.is_empty():
			state.turn_free.clear()
		# 魔像术（9079）的本回合手卡减费同样只在当回合有效
		if not state.turn_card_discount.is_empty():
			state.turn_card_discount.clear()
		# 契约签订者（8024）的本回合手卡涨价同样只在当回合有效
		state.turn_card_raise = 0
		# 回转（9089）抽到的牌只在抽到的那个回合免弃
		if not state.turn_keep.is_empty():
			state.turn_keep.clear()


		_rice_used = false
		turn_spell_bonus = 0
	else:
		state.opp_hand_count = 0


	# 活力转移 / 地狱猫 / 鲜血堡垒（R55）：**能量清零之前**结算本回合没用完的剩余费用。
	_end_turn_surplus(current_side)

	if current_side == SIDE_SELF:
		state.energy = 0
	else:
		state.opp_energy = 0
	var nxt:= SIDE_OPPONENT if current_side == SIDE_SELF else SIDE_SELF
	_begin_turn(nxt)


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



	# X 费卡（流星雨 9083）：费用 = 该方当前剩余的**全部能量**（显示=判定=实扣 都读这里）。
	if card != null and card.x_cost:
		return maxi(0, state.energy_of(side))
	# 使魔之夜的乌鸦：只在本回合免费（回合结束 turn_free 清空 → 恢复原价）
	if state.turn_free.has(card):
		return _cost_floor(card, 0)
	# 「在手牌里期间免费」（R89 无限装甲 8038 供能的改造牌）：
	# ⚠️ 判据是**这张卡此刻还在不在手牌里**，不是回合 —— 所以打出 / 弃掉后自动恢复原价，
	# 不需要在那 10 处离手口逐个清标记。放在 X 费判定**之后**：X 费卡费用由剩余能量决定，
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
		c -= _fort_discount(card, side)
	c -= _quick_strike_discount(card)
	c -= _frenzy_discount(card, side)
	c -= _instance_discount(card, side)
	c -= _turn_instance_discount(card, side)
	c -= _magic_core_discount(card, side)
	c -= _void_lord_discount(card, side)
	# 契约签订者（8024，R63）：本回合手卡全体**涨价** +N —— 放在所有减费之后，
	# 这样它压得住前面的各种 -1 / -X，且显示 = 判定 = 实扣仍统一走这里。
	if side == SIDE_SELF and card != null and state.turn_card_raise > 0:
		c += state.turn_card_raise
	return _cost_floor(card, maxi(0, c))


func _cost_floor(card: CardData, cost: int) -> int:
	## 个别卡的费用下限（显示 = 判定 = 实扣 都走 cost_of，所以只在这里兜一层）：
	## 回响（9102）「此卡最低 1 费」—— 它使用后回手，没有下限就成了 0 费无限回手。
	if card != null and card.id == ECHO_ID:
		return maxi(cost, ECHO_MIN_COST)
	return cost


func _fort_discount(card: CardData, side: String) -> int:
	## 紧急埋伏（9106，R52）：「你使用的下一张工事卡费用 -1」——只对 kind=工事 生效，
	## 计数挂在 FieldState（跨回合保留，直到真正打出一张工事才消费；可叠加）。
	if card == null or not card.is_fort():
		return 0
	return state.fort_discount_self if side == SIDE_SELF else state.fort_discount_opp


func can_pay_card(card: CardData, side:= SIDE_SELF) -> bool:

	# X 费卡：只要有 >=1 点能量就能打（X = 剩下的全部能量）；0 能量时不允许，免得空放浪费。
	if card != null and card.x_cost:
		return state.energy_of(side) >= 1
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
	## 虚空主宰（9082）：该方场上有几张本卡。
	var n:= 0
	for p: Placement in state.board.values():
		if p.owner == side and p.card.traits.has(VOID_LORD_TRAIT):
			n += 1
	return n


func _void_lord_owned(side:= SIDE_SELF) -> bool:
	## 该方**拥有**虚空主宰（场上 / 手卡 / 牌库 / 弃牌区任意一处有本卡）。
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
	## 虚空主宰（9082）的两条费用机制：
	## ① 只要这张卡在场，该方的技能牌费用 -1（多张叠加：按场上本卡张数算）；
	## ② 本次对战中每用技能牌对敌方造成一次伤害，手卡里的本卡费用 -2（战斗内累计）。
	var d:= 0
	if card.is_spell():
		d += _void_lord_presence(side) * VOID_LORD_PRESENCE_DISCOUNT
	if card.id == VOID_LORD_ID:
		d += state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT
	return d


func _mark_spell_enemy_hit() -> void :
	## 虚空主宰（9082）伤害计数：只有在**技能结算窗口内**、且伤害落在**敌方**身上时才记一笔。
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
	## （X = 施放时消耗的全部能量，见 use_spell）。每次**独立**随机选目标。
	## 场上没有敌方单位时改为直击敌方 HP（与疾风之力同处理）；
	## 命中带「法术免疫」的单位 → 那一颗被拦下（与龙息同一判据）。
	var times:= maxi(0, _x_spell_value)
	if times <= 0:
		return "流星雨：没有能量，坠落 0 颗"
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


	## 火墙术（9084）：对一横行的敌人造成 FIRE_WALL_DMG 点伤害，并让该行燃烧到施放方的
	## 下次回合开始 —— 期间任何单位（不分敌我）移动经过该行 → 再挨 FIRE_WALL_PASS_DMG 点
	## （见 _fire_wall_pass）。同一个单位从这面火墙上累计最多 FIRE_WALL_CAP 点。
	if not (target is Vector2i):
		return "（需要指定一条横行）"
	var row: int = (target as Vector2i).x
	if row < 0 or row >= FieldState.BOARD_ROWS:
		return "（横行不存在）"
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var dmg:= _spell_dmg(side, FIRE_WALL_DMG, card)
	var pass_dmg:= _spell_dmg(side, FIRE_WALL_PASS_DMG, card)
	var rec:= {"side": side, "row": row, "pass_dmg": pass_dmg, "dealt": {}}
	var map: Dictionary = rec["dealt"]
	var hits:= 0
	var total:= 0
	var blocked:= 0
	for col in FieldState.BOARD_COLS:
		var c:= Vector2i(row, col)
		var p: Placement = state.unit_at(c)
		if p == null or p.owner != foe:
			continue
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
	action.emit("fire_wall", {"row": row, "side": side, "card": card})
	if hits > 0:
		_destroy_dead()
	_log("火墙术：第 %d 行燃起（%d 个敌人共 -%d；经过者 -%d，同一单位上限 %d）" % [
			row, hits, total, pass_dmg, FIRE_WALL_CAP])
	var msg:= "第 %d 行火墙：%d 个敌人 -%d" % [row, hits, dmg]
	if blocked > 0:
		msg += "，%d 个免疫" % blocked
	return msg


func _fire_wall_pass(path: Array[Vector2i]) -> void :


	## 单位移动结束后的火墙判定（**不分敌我**）：path 是 BFS 路径（含起点与终点），
	## 只要路径上「进入过」某条燃烧的横行（起点不算，那是站着不是经过）→ 挨一次灼烧。
	## 同一个单位从同一面火墙上累计最多 FIRE_WALL_CAP 点（全卡合计上限）。
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
		var used: int = int(map.get(p, 0))
		var left: int = FIRE_WALL_CAP - used
		if left <= 0:
			_log("火墙：%s 已吃满 %d 点，本次不再受伤" % [p.card.card_name, FIRE_WALL_CAP])
			continue
		var dmg: int = mini(int(rec["pass_dmg"]), left)
		var real:= _hit_unit(p, dmg, "火墙")
		map[p] = used + real
		_log("火墙：%s 穿过第 %d 行 → -%d（这面火墙累计 %d/%d）" % [
				p.card.card_name, row, real, used + real, FIRE_WALL_CAP])
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
		if state.hand_full():
			_log("无尽加护：手牌已满（%d 张），本次不加入" % FieldState.HAND_LIMIT)
			action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
			break
		var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		var copy:= CardData.from_dict(pick.to_dict())
		state.hand.append(copy)
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
	_log("支付 %d 能量使用 %s" % [c, card.card_name])
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
	## 所以凡是「按场地一次性结算」的地方（拦路 / 触发 / 双重场地附魔）都要先问一句这个，
	## 否则持续型场地会被当成一次性用掉 —— **清泉会被敌人走一次就白费**。
	##
	## **static** + 纯函数：界面也要读（双重场地候选高亮），同 `field_place_allowed` 的做法。
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
	if p.fence_bonus_hp <= 0 and p.fence_bonus_traits.is_empty() and p.upgrade_hp <= 0 \
			and p.upgrade_range <= 0 and p.upgrade_speed <= 0:
		return p.card
	var out:= CardData.from_dict(p.card.to_dict())
	out.traits = (p.card.traits as Array).duplicate()   # 同上：必须切断与卡库的共享引用
	out.health = maxi(1, p.card.health - p.fence_bonus_hp - p.upgrade_hp)
	for t in p.fence_bonus_traits:
		out.traits.erase(t)
	if p.upgrade_range > 0:
		out.attack_range = maxi(1, p.card.attack_range - p.upgrade_range)
	if p.upgrade_speed > 0:
		out.move_speed = maxi(0, p.card.move_speed - p.upgrade_speed)
	return out


func play_from_hand(hand_index: int, cell: Vector2i) -> Placement:
	if ReplayLog.recording:
		ReplayLog.act("play_from_hand", [hand_index, cell])

	var card:= state.hand[hand_index]
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
		_daedalus_upgrade(p)

	if card.id == FOX_ID:
		_fox_trigger()

	var beast_hp:= _beast_hp_bonus(card)
	if beast_hp > 0:
		p.health += beast_hp
		_log("野兽之心：%s 获得 +%d 生命（%d）" % [card.card_name, beast_hp, p.health])

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


func _daedalus_upgrade(self_p: Placement) -> void :
	## 代达罗斯 8060（R101，史诗，机械之心）：使用时，手卡/抽牌库/弃牌区/
	## 场上其他所有友方盟友和工事获得改造：力量+1。
	# 手牌/牌库/弃牌区：烤进副本（与 系统升级/批量改造 同口径，本场永久、不污染卡库）
	for zone in [state.hand, state.deck, state.discard]:
		for i in zone.size():
			var c: CardData = zone[i]
			if c.kind == "盟友" or c.is_fort():
				var up := CardData.from_dict(c.to_dict())
				up.traits = (up.traits as Array).duplicate()
				# R120：改造奖励走**唯一口**（手/库/弃里的素体也 +1 血）。
				up.power += _upgrade_atk_gain(up, 1)
				up.health += _upgrade_hp_gain(up, 0)
				zone[i] = up
	# 场上其他友方盟友/工事：走改造路径（力量+1，触发其改造反应），不连锁镜像/供牌
	for cell in state.board.keys():
		var q: Placement = state.board[cell]
		if q == self_p:
			continue
		if q.owner != SIDE_SELF:
			continue
		if q.card.kind == "盟友" or q.card.is_fort():
			q.card = CardData.from_dict(q.card.to_dict())
			q.card.traits = (q.card.traits as Array).duplicate()
			# R120：改造奖励走**唯一口**（场上的素体也 +1 血；侦察塔不加攻）。
			var da_atk: int = _upgrade_atk_gain(q.card, 1)
			var da_hp: int = _upgrade_hp_gain(q.card, 0)
			q.upgrade_atk += da_atk
			if da_hp > 0:
				q.upgrade_hp += da_hp
				q.card.health += da_hp
				q.health += da_hp
			q.upgrade_stacks += 1
			_on_unit_upgraded(q)
			_log("代达罗斯：%s 获得改造（力量+1）" % q.card.card_name)
	_log("代达罗斯：群体改造完成")
	action.emit("daedalus", {"self": self_p.card})

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
	if state.hand_full():
		_log("%s：手牌已满（%d 张），复制失败" % [card.card_name, FieldState.HAND_LIMIT])
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT,
				"hand": state.hand.size()})
		return
	var clone:= CardData.from_dict(card.to_dict())
	clone.traits = (card.traits as Array).duplicate()   # 切断与卡库的共享引用
	clone.is_ephemeral = true      # 衍生物标记：离场消失、不进弃牌区（卡库原卡没有它）
	state.hand.append(clone)
	_log("%s：手牌增加一张复制（回合结束前可打出）" % card.card_name)
	action.emit("self_clone", {"card": clone, "from": card})


## ── R120：**改造奖励的唯一口**（素体 / 战斗骨骼这类卡面字段）──
##
##   R84 起「被改造时 +N 力 / +M 血」改读**卡面字段**（`CardData.upgrade_atk_bonus` /
##   `upgrade_hp_bonus`），但当时只有「升级」8027 与「加厚装甲」8044 两个入口真的读了它 ——
##   自我修复 8035 / 改造工厂 8037 / 超越极限 8053 / 批量改造 8031 / 系统升级 8039 /
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
		if manhattan(other, victim_cell) <= u.card.attack_range:
			bonus += u.upgrade_stacks
	return bonus


func _on_unit_upgraded(p: Placement) -> void :
	## R101：「每次获得改造时」触发（榴弹击手/重甲战车/机器鸟）。
	## 在**所有**给这张单位施加改造的入口末尾调用（升级/自我修复/加厚装甲/
	## 超越极限/模仿者传导/代达罗斯 群体改造）。
	if p == null or p.card == null:
		return
	if p.card.traits.has(UPGRADE_RANGE_TRAIT):      # 榴弹击手：攻击距离+1
		p.upgrade_range += 1
		p.card.attack_range += 1
		_log("改造触发：%s 攻击距离+1（→%d）" % [p.card.card_name, p.card.attack_range])
	if p.card.traits.has(UPGRADE_SPEED_TRAIT):      # 重甲战车：移动速度+1
		p.upgrade_speed += 1
		p.card.move_speed += 1
		_log("改造触发：%s 移动速度+1（→%d）" % [p.card.card_name, p.card.move_speed])
	if p.card.traits.has(UPGRADE_DRAW_TRAIT):        # 机器鸟：抽1张
		if p.owner == SIDE_SELF:
			state.draw()
		_log("改造触发：%s 改造时抽1张" % p.card.card_name)

func _upgrade_unit(target, side:= SIDE_SELF) -> String :
	## 「升级」（8027，R82，机械之心）：改造一个**己方盟友或工事** →
	## +UPGRADE_ATK 攻 / +UPGRADE_HP 血，**再加这张卡自己的「改造奖励」**
	## （`CardData.upgrade_atk_bonus` / `upgrade_hp_bonus`：素体 +1 血、战斗骨骼 +1 力 +1 血）。
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
	# R120：改造奖励走**唯一口**（素体 +1 血 / 战斗骨骼 +1 力 +1 血 / 侦察塔不加攻）。
	var atk_gain: int = _upgrade_atk_gain(p.card, UPGRADE_ATK)
	var hp_gain: int = _upgrade_hp_gain(p.card, UPGRADE_HP)
	p.upgrade_atk += atk_gain
	p.upgrade_hp += hp_gain
	# 改造**层数**（R86）：被改造一次 +1 层。侦察塔（trait「改造层数」）靠它
	# 每层 +1 攻击伤害（见 Placement.effective_power）。离场不还原到卡上 ——
	# 它只记在 Placement 上，跟 upgrade_atk 一样是「只在场上有效」。
	p.upgrade_stacks += 1
	# 「堡垒」（8034，R87，trait「改造生命层」）：**每层 +STACK_HP_PER 生命**。
	# 并进 `upgrade_hp` → 离场还原走 `_card_leaving_field` 的同一条路，不用额外处理。
	# 与侦察塔的「改造层数」是两套 trait，别混：那个加攻、这个加血。
	if p.card.traits.has(STACK_HP_TRAIT):
		p.upgrade_hp += STACK_HP_PER
		p.card.health += STACK_HP_PER
		p.health += STACK_HP_PER
	p.card.health += hp_gain
	p.health += hp_gain
	_log("升级：%s 被改造 → 力量 +%d、生命 +%d（%d 攻 / %d 血，第 %d 层）" % [
			p.card.card_name, atk_gain, hp_gain + (STACK_HP_PER \
					if p.card.traits.has(STACK_HP_TRAIT) else 0),
			p.effective_power(), p.health, p.upgrade_stacks])
	action.emit("upgrade", {"cell": target, "card": p.card, "placement": p,
			"atk": atk_gain, "hp": hp_gain})
	# 「模仿者」8043（R92）：与它接通的我方模仿者获得**相同改造**。
	# 传的是 `atk_gain` / `hp_gain` —— 含受体自己的改造奖励（upgrade_*_bonus），
	# 但**不含**「堡垒」trait 的额外 +STACK_HP_PER：那是**受体自身**的特性，不该被模仿出去。
	_mimic_relay(p, atk_gain, hp_gain)
	# 「无限装甲」8038（R89）：被改造时**每回合一次**供一张 0 费改造牌到手。
	# 挂在**改造结算之后**（卡面写的是「被改造时」，那是改造完成的那一刻）。
	_feed_upgrade_card(p)
	_on_unit_upgraded(p)
	return "%s 改造完成（+%d 攻 / +%d 血）" % [p.card.card_name, atk_gain, hp_gain]


func _feed_upgrade_card(p: Placement) -> void :
	## 「无限装甲」（8038，R89，trait「改造供能」）的**唯一入口**。
	##
	## 卡面：「每回合一次：这张卡被「改造」时，随机一张**效果含「改造」的技能卡**加入你的手牌，
	## 那张牌在手牌里**费用为 0**（离开手牌后恢复原价）。」
	##
	## 三个口径（用户当时已睡，按最合理方案定的 —— 见常量区的注释）：
	##  ① **候选 = 本角色奖励卡池**里「技能 + effect_text 含『改造』」的卡
	##     （与「双重场地」`_twin_field_chain` 从卡池取场地卡同源）。奖励池里现在有
	##     批量改造 8031 / 能量屏障 8033 / 自我修复 8035（「升级」8027 是初始卡 rarity=3，不入池）。
	##  ② **免费重置靠判据而非清标记**：写 `state.hand_free[card] = true`，
	##     由 `cost_of` 验「此刻是否还在手牌里」决定要不要给 0 费。离手口分散在
	##     play / use_spell / discard_hand / 乌鸦回手 … 共 10 处，逐个挂钩必漏一处。
	##  ③ **每回合一次**记 `p.upgrade_feed_turn`（比对 `turn_total`）——
	##     记在这个单位实例上，换一张装甲上场就有一份额度。
	##
	## 触发源**只有 `_upgrade_unit`**（「升级」技能 / 「自我修复」/ 「批量改造」共用它）。
	## 「改造工厂」（8037，R88）在 `_field_aura_tick` 里自己加攻加血、**不走这里** ——
	## 它是场地效果不是「改造技能」，否则每回合自动触发一次，装甲会变成印钞机。
	if p == null or p.card == null or not p.card.traits.has(INF_ARMOR_TRAIT):
		return
	if p.upgrade_feed_turn == turn_total:
		return    # 本回合已供过能
	var pool: Array[CardData] = []
	for c: CardData in CardRepo.load_json().reward_pool_for(RunState.player_class):
		if c.is_spell() and UPGRADE_KEYWORD in c.effect_text:
			pool.append(c)
	if pool.is_empty():
		_log("无限装甲：奖励卡池里没有效果含「改造」的技能牌，本回合供能落空")
		action.emit("inf_armor", {"card": null, "ok": false, "placement": p})
		return
	if state.hand_full():
		_log("无限装甲：手牌已满（%d 张），供能落空"
			% FieldState.HAND_LIMIT)
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT,
			"hand": state.hand.size()})
		action.emit("inf_armor", {"card": null, "ok": false, "placement": p})
		return
	var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
	# ⚠️ **必须 from_dict 复制成独立实例**（卡库是共享实例）：直接 append 卡库那张
	# 会让 `hand_free` 的按实例标记串到别处，且以后改它会污染卡库。
	var got := CardData.from_dict(pick.to_dict())
	got.traits = (got.traits as Array).duplicate()
	state.hand.append(got)
	state.hand_free[got] = true
	p.upgrade_feed_turn = turn_total
	_log("无限装甲：供能 —— 技能牌「%s」加入手牌，在手牌里费用为 %d"
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
	p.upgrade_stacks += 1   # 算一层改造 → 侦察塔光环 / 堡垒按层数反应
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
	# 「无限装甲」8038（R89）：被改造时每回合供一张 0 费改造牌（与 _upgrade_unit 同）。
	_feed_upgrade_card(p)
	_on_unit_upgraded(p)
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
	## 「批量改造」（8031，R86，机械之心）：手卡里**所有盟友和工事**生命 +1。
	##
	## 口径（已与用户确认）：**整场战斗内一直有效** —— 回合结束弃回牌库、再抽到仍然带 +1。
	## 这自动成立，因为下一场战斗 `RunState.build_deck()` 会重新从**卡库**取实例。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再替换**：`build_deck` 用 `repo.get_card(id)`，
	## 那是**卡库共享实例**。直接 `state.hand[i].health += 1` 会把**卡库**那张一起改 ——
	## 于是本局之后、甚至下一局新 run 抽到那张卡都天生 +1 血（跨 run 泄漏）。
	##
	## 顺带：`upgrade_stacks` **不**在这里加 —— 侦察塔那类「层数加伤」的效果是
	## 「攻击时伤害 +1」，而手牌里的卡还没上场，给它记层没有意义（用户口径的
	## 「被任何改造手段 +1 层」指的是**已上场的**单位被改造时）。
	var touched := 0
	var names: Array[String] = []
	for i in state.hand.size():
		var c: CardData = state.hand[i]
		if c.kind != "盟友" and not c.is_fort():
			continue
		var up := CardData.from_dict(c.to_dict())
		# R120：改造奖励走**唯一口** —— 素体在手牌里被「批量改造」也额外 +1 血
		#（用户口径：任何改造都生效，含手牌与牌库）；战斗骨骼同理 +1 力 +1 血。
		up.power += _upgrade_atk_gain(up, 0)
		up.health += _upgrade_hp_gain(up, BATCH_UPGRADE_HP)
		state.hand[i] = up
		touched += 1
		names.append("%s %d血" % [c.card_name, up.health])
	if touched == 0:
		_log("批量改造：手牌里没有盟友或工事，效果落空")
		action.emit("batch_upgrade", {"count": 0, "cards": []})
		return "手牌里没有盟友或工事"
	_log("批量改造：手牌 %d 张盟友/工事各 +1 生命（%s）" % [touched, "、".join(names)])
	action.emit("batch_upgrade", {"count": touched, "cards": names})
	return "%d 张手牌各 +1 生命" % touched


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
	## 与「批量改造」8031 是同一套纪律。
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
	state.hand[hand_index] = up
	_log("系统升级：%s 改造完成（费用 +%d / 力量 +%d / 生命 +%d → %d 费 %d 攻 %d 血，本场战斗永久）"
		% [c.card_name, SYS_UPGRADE_COST_ADD, SYS_UPGRADE_ATK, SYS_UPGRADE_HP,
			up.cost, up.power, up.health])
	action.emit("sys_upgrade", {"card": up, "hand_index": hand_index,
		"cost_add": SYS_UPGRADE_COST_ADD, "atk": su_atk, "hp": su_hp})
	return "%s 改造完成（%d 费 / %d 攻 / %d 血）" % [up.card_name, up.cost, up.power, up.health]


func _batch_transfer(side: String) -> String :
	## 「批量传输」（8040，R90，机械之心 1 费稀有）：**手牌里所有**盟友 / 工事
	## 获得「改造」（费用 +1 / 力量 +3 / 生命 +6），**然后抽 1 张卡**。
	##
	## 与「批量改造」8031 的差别（R90 刻意做的升级版）：
	##   * 8031：只 +1 生命，**不抽牌**；
	##   * 8040：+1 费 / +3 力 / +6 血，**外加抽 1 张**。
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
		up.cost += SYS_UPGRADE_COST_ADD
		# R120：改造奖励走**唯一口**（与「系统升级」同口径）。
		up.power += _upgrade_atk_gain(up, SYS_UPGRADE_ATK)
		up.health += _upgrade_hp_gain(up, SYS_UPGRADE_HP)
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
	_log("批量传输：手牌 %d 张盟友/工事改造（费用 +%d / 力量 +%d / 生命 +%d）"
		% [touched, SYS_UPGRADE_COST_ADD, SYS_UPGRADE_ATK, SYS_UPGRADE_HP])
	_log("批量传输：%s；抽 %d 张卡" % ["、".join(names), got])
	action.emit("batch_transfer", {"count": touched, "cards": names, "draw": got})
	return "%d 张手牌改造，抽 %d 张卡" % [touched, got]


# ── R90「系统升级」的选牌 pending（目标在**手牌**，不在棋盘）──
# 面板期间引擎不结算的挂点见 `_end_turn_surplus` 一带（`revive_pending or crow_pending …`）。
var sys_upgrade_pending := false
var sys_upgrade_source := -1        # 手牌里那张「系统升级」自己的下标（结算时从这里取出）


func sys_upgrade_options() -> Array[int]:
	## 「系统升级」可选的手牌下标：**只列盟友 / 工事**（技能 / 场地 / 效果卡不可选）。
	## 返回下标而不是 CardData —— 与 `crow_options` 同一惯例，界面按 `state.hand[i]` 取卡面。
	var out: Array[int] = []
	if not sys_upgrade_pending:
		return out
	for i in state.hand.size():
		if i == sys_upgrade_source:
			continue
		var c: CardData = state.hand[i]
		if c.kind == "盟友" or c.is_fort():
			out.append(i)
	return out


func sys_upgrade_start(source_hand_index: int) -> void :
	## 打出「系统升级」→ 置 pending，等玩家点一张手牌。
	## 手牌里没有可选的盟友 / 工事 → **立刻落空**（不弹空面板），费用照付。
	sys_upgrade_pending = false
	sys_upgrade_source = source_hand_index
	if sys_upgrade_options().is_empty():
		_log("系统升级：手牌里没有可选的盟友或工事，效果落空")
		action.emit("sys_upgrade", {"card": null, "ok": false})
		return
	sys_upgrade_pending = true
	_log("系统升级：选择手牌里的一张盟友或工事进行改造")


func sys_upgrade_pick(hand_index: int) -> bool:
	## 结算玩家选中的那张手牌。**改造在手牌上就地完成**（不 remove/re-append ——
	## `_sys_upgrade_hand_card` 走的是「复制 + 原位替换」，手牌顺序与扇形布局不受影响）。
	if ReplayLog.recording:
		ReplayLog.act("sys_upgrade_pick", [hand_index])
	if not sys_upgrade_pending:
		return false
	if not sys_upgrade_options().has(hand_index):
		return false
	var detail := _sys_upgrade_hand_card(hand_index)
	sys_upgrade_pending = false
	sys_upgrade_source = -1
	return detail != ""


func _energy_barrier(side: String) -> String :
	## 「能量屏障」（8033，R87，机械之心）：从**抽牌堆**随机一张**还没有能量屏障**的
	## 盟友 / 工事，给它加上这个 trait → 它**上场时**获得「首次受伤免掉」的一次性护盾。
	##
	## 口径（已与用户确认）：**一次性护盾** —— 本场战斗中第一次受到的伤害完全免掉，
	## 之后恢复正常、护盾消失（拦截点唯一 = `_hit_unit` 开头）。
	##
	## 判据「没有此能力」= 卡上没带 BARRIER_TRAIT（与「过载」判 actions 同一套路）。
	## ⚠️ **必须 `from_dict` 复制再原位替换**：卡库是**共享实例**，直接改会跨 run 泄漏。
	## 原位替换（不抽到手上）让牌库顺序 / 洗牌序列不变 → 录像回放一致（同「过载」）。
	var cand: Array[int] = []
	for i in state.deck.size():
		var c: CardData = state.deck[i]
		if c.kind != "盟友" and not c.is_fort():
			continue
		if c.traits.has(BARRIER_TRAIT):
			continue
		cand.append(i)
	if cand.is_empty():
		_log("能量屏障：抽牌堆里没有「还没有能量屏障」的盟友/工事，效果落空")
		action.emit("barrier_grant", {"card": null, "ok": false})
		return "抽牌堆里没有可改造的卡"
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
	_log("能量屏障：「%s」获得能量屏障（下次上场时第一次挨打完全免掉）" % before.card_name)
	action.emit("barrier_grant", {"card": up, "ok": true, "from": before, "side": side})
	return "%s 获得能量屏障" % before.card_name


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
	p.upgrade_stacks += 1        # 也算一次改造（用户口径：任何改造手段都记层）
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
	p.upgrade_stacks += 1
	# 「堡垒」（8034）：每层改造 +STACK_HP_PER 生命（与侦察塔是两套 trait，别混）。
	if p.card.traits.has(STACK_HP_TRAIT):
		p.upgrade_hp += STACK_HP_PER
		p.card.health += STACK_HP_PER
		p.health += STACK_HP_PER
	p.card.health += hp_gain
	p.health += hp_gain
	_log("加厚装甲：%s 被改造 → 生命 +%d（%d 血，第 %d 层）" % [
			p.card.card_name, hp_gain, p.health, p.upgrade_stacks])
	action.emit("upgrade", {"cell": target, "card": p.card, "placement": p,
			"atk": atk_gain, "hp": hp_gain})
	# 「模仿者」8043（R92）：接通的模仿者获得**相同改造**。
	# 传 atk_gain / hp_gain —— 含受体自己的改造奖励，**不含**「堡垒」的额外 +STACK_HP_PER
	# （那是受体自身的特性，不该被模仿出去）。
	_mimic_relay(p, atk_gain, hp_gain)
	# 「无限装甲」8038（R89）：被改造时**每回合一次**供一张 0 费改造牌到手。
	_feed_upgrade_card(p)
	_on_unit_upgraded(p)
	return "%s 加装完成（+%d 血）" % [p.card.card_name, hp_gain]


func _auto_upgrade(side: String) -> void :
	## 「自主升级」（8045，R95，机械之心 2 费效果卡）的唯一结算口，挂在 `_begin_turn()`。
	##
	## ⚠️ **必须 `from_dict` 复制成新实例再原位替换**：卡库里是**共享实例**，直接改
	## `state.deck[i].power` 会连**卡库**那份一起改 —— 本场之后、甚至下一场抽到就已经是
	## 强化版（等于把「自主升级」变成永久强化，且跨 run 泄漏）。
	##
	## 原位替换不改牌库顺序 → 洗牌序列不变，录像回放天然一致。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	if not _zone_has(zone, AUTO_UPGRADE_TRAIT):
		return
	var cand: Array[int] = []
	for i in state.deck.size():
		var c: CardData = state.deck[i]
		if c.kind == "盟友" or c.is_fort():
			cand.append(i)
	if cand.is_empty():
		_log("自主升级：抽牌堆里没有盟友 / 工事，本回合落空")
		action.emit("auto_upgrade", {"card": null, "ok": false, "side": side})
		return
	var pick: int = cand[rng.randi() % cand.size()]
	var before: CardData = state.deck[pick]
	var up := CardData.from_dict(before.to_dict())
	# R120：改造奖励走**唯一口**（牌库里的素体被改造也额外 +1 血）。
	var au_atk: int = _upgrade_atk_gain(up, AUTO_UPGRADE_ATK)
	var au_hp: int = _upgrade_hp_gain(up, AUTO_UPGRADE_HP)
	up.power += au_atk
	up.health += au_hp
	state.deck[pick] = up        # 原位替换：牌库顺序不变
	_log("自主升级：「%s」在牌库里被改造 → 力量 +%d（%d）、生命 +%d（%d）" % [
			before.card_name, au_atk, up.power, au_hp, up.health])
	action.emit("auto_upgrade", {"card": up, "ok": true, "from": before, "side": side})


func _regen_tick(side: String) -> void :
	## **每回合结束回血**的唯一口（R87）——「自我修复」8035 给的 `Placement.regen`。
	## 口径：只结算 `p.owner == side` 的单位（「自己回合结束」）；
	## 满血 `continue`（不越界、不刷噪声）；回血上限读 `p.card.health`（当前卡面上限）。
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.regen <= 0:
			continue
		if p.health >= p.card.health:
			continue
		var before: int = p.health
		p.health = mini(p.card.health, p.health + p.regen)
		var got: int = p.health - before
		_log("%s：自我修复回复 %d 点生命（%d / %d）" % [
				p.card.card_name, got, p.health, p.card.health])
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
		q.upgrade_stacks += 1
		_on_unit_upgraded(q)
		_log("模仿者模仿 %s 的改造：+%d 攻 / +%d 血（现在是 %d 攻 / %d 血）" % [
				src.card.card_name, atk_gain, hp_gain, q.effective_power(), q.health])
		action.emit("mimic_upgrade", {"cell": c, "card": q.card, "placement": q,
				"from": src.card.card_name, "atk": atk_gain, "hp": hp_gain})


func _aether_guard_enter(p: Placement) -> void :

	var n:= mini(state.effects.size(), AETHER_GUARD_CAP)
	if n <= 0:
		_log("以太守卫：效果区没有效果卡，未获得加成")
		return
	p.atk_buff += n
	p.health += 2 * n
	_log("以太守卫：效果区 %d 张效果卡 → +%d 力量、+%d 生命（%d/%d）" % [
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

	if state.hand_full():
		_log("以太恶魔：手牌已满（%d 张），没有取效果卡" % FieldState.HAND_LIMIT)
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return
	var cand: Array[int] = []
	for i in state.deck.size():
		if state.deck[i].is_effect():
			cand.append(i)
	if cand.is_empty():
		_log("以太恶魔：卡组里没有效果卡")
		return
	var pick: int = cand[rng.randi() % cand.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	state.hand.append(chosen)
	state.card_discount[chosen] = int(state.card_discount.get(chosen, 0)) + DEMON_FETCH_DISCOUNT
	_log("以太恶魔：从卡组取到效果卡「%s」，它的费用 -%d" % [
		chosen.card_name, DEMON_FETCH_DISCOUNT])
	action.emit("demon_fetch", {"card": chosen})


func _owl_fetch() -> void :

	if state.hand_full():
		_log("猫头鹰：手牌已满（%d 张），没有取效果卡" % FieldState.HAND_LIMIT)
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return
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
	state.hand.append(chosen)
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
	if state.hand_full():
		_log("%s：手牌已满（%d 张），无法抽取技能牌" % [source, FieldState.HAND_LIMIT])
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return
	var pick:= skill_idx[rng.randi() % skill_idx.size()]
	var chosen: CardData = state.deck[pick]
	state.deck.remove_at(pick)
	var copy:= CardData.from_dict(chosen.to_dict())
	state.hand.append(copy)
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
	##   * 选中后**原位替换**：不抽到手上、不改变牌库顺序 → 洗牌序列不变，录像回放天然一致。
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
	if ReplayLog.recording:
		ReplayLog.act("play_hero", [hand_index, cell, drop_indexes])




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


func use_spell(hand_index: int, target = null) -> String:
	if ReplayLog.recording:
		ReplayLog.act("use_spell", [hand_index, target])

	# R90：「系统升级」的选牌面板开着时**不许再出别的牌** —— 否则玩家可以在
	# 选牌过程中把「系统升级」的目标那张顺手打掉，下标就失效了。
	# 界面本身会拦点击（面板是模态的），这里是给联机 / 回放路径兜底。
	if sys_upgrade_pending:
		return "系统升级：请先选择手牌里的一张盟友或工事"

	var card:= state.hand[hand_index]
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
	# 双向传送（8061，R102）：**两段式**技能 —— 要选**两个**单位，单段入口没有
	# 第二个目标的信息。必须在**付费之前**拦截，否则玩家发现场上不足两个单位时
	# 费用已经扣了、卡也已经从手牌里拿走了。
	if card.id == SWAP_UNITS_ID:
		return "双向传送：先点第一个单位，再点第二个单位（右键取消）"
	# 回旋斩（9096）：本回合使用 4 张以上其他卡后才能使用（付费用之前拦截）。
	if card.id == WHIRL_BLADE_ID and state.self_card_plays < WHIRL_BLADE_NEED:
		return "回旋斩：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				WHIRL_BLADE_NEED - state.self_card_plays, state.self_card_plays]
	# 流星雨（9083）：X = 扣费前剩余的**全部能量**（_pay 会把它一次清零）→ 先抓再付。
	_x_spell_value = maxi(0, state.energy_of(SIDE_SELF)) if card.x_cost else 0
	_pay(card)
	state.hand.remove_at(hand_index)
	# 蓄力（9085）：先取走待用层数再结算 —— 蓄力是结算时才上层的，不会把自己翻倍
	var times:= _charge_take(SIDE_SELF)
	# 虚空主宰（9082）：技能结算窗口 —— 窗口内对敌方造成过伤害就记一笔（手卡里本卡 -2 费）
	_spell_active = true
	_spell_hit_enemy = false
	var detail:= ""
	for _ch_i in times:
		var _ch_d:= _run_spell_effect(card, target)
		detail = _ch_d if _ch_i == 0 else "%s；%s" % [detail, _ch_d]
	if times > 1:
		detail = "蓄力 ×%d → %s" % [times, detail]
	_spell_active = false
	if _spell_hit_enemy and _void_lord_owned(SIDE_SELF):
		# 修复（实机体验 R46 后）：没有虚空主宰时不再空转计数/打日志/发事件
		# （此前对手牌里没有本卡的玩家也会一直弹「虚空主宰：…」状态栏文本）。
		state.void_dmg_spells += 1
		_log("虚空主宰：本次对战中第 %d 次用技能对敌方造成伤害 → 手卡里的本卡费用 -%d" % [
			state.void_dmg_spells, state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT])
		action.emit("void_lord", {"count": state.void_dmg_spells,
			"discount": state.void_dmg_spells * VOID_LORD_DMG_DISCOUNT})
	# 技能用完才计数：_spell_dmg 里的「每回合第一张技能」判定因此仍是 0 → 当回合首张吃到加成
	state.self_skill_plays += 1
	_spell_play_tick()
	_on_turn_first_play(SIDE_SELF, card)
	_note_card_played(SIDE_SELF, card)
	if card.id == WHALE_WRATH_ID:
		_log("鲸鱼之怒：使用后消失（不进弃牌区，本场不再出现）")
	elif card.id == FATE_REJECT_ID:
		_log("拒绝命运：使用后消失（不进弃牌区，本场不再出现）")
	elif card.id == ALERT_ID:
		# 警觉（9109，R60）：使用后消失（不进弃牌区，本场不再出现）
		# —— 警觉是「第 1 回合必定抽到」的一次性启动牌，不该在弃牌区里再滚回来。
		_log("警觉：使用后消失（不进弃牌区，本场不再出现）")
	elif card.id == ECHO_ID:
		# 回响（9102）：使用后**返回手卡**（循环代价只有费用，下限见 ECHO_MIN_COST）。
		if state.hand_full():
			_log("回响：返回手卡被手牌上限挡下 → 进弃牌区")
			state.discard.append(card)
		else:
			state.hand.append(card)
			_log("回响：使用后返回手卡")
	else:
		state.discard.append(card)
	_log("使用技能 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	return detail


func use_effect(hand_index: int) -> String:
	if ReplayLog.recording:
		ReplayLog.act("use_effect", [hand_index])



	var card:= state.hand[hand_index]
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
	else:
		state.opp_card_plays += 1
	# 紧急埋伏（9106，R52）：使用了一张工事卡 → 消费一层「下一张工事费用 -1」。
	if played != null and played.is_fort():
		if side == SIDE_SELF and state.fort_discount_self > 0:
			state.fort_discount_self -= 1
			_log("紧急埋伏：本张工事卡费用 -1（剩余 %d 层）" % state.fort_discount_self)
		elif side == SIDE_OPPONENT and state.fort_discount_opp > 0:
			state.fort_discount_opp -= 1
	_phantom_cloak_tick(side)
	_gale_tick(side, played)
	_lurker_tick(side, played)
	_sleepless_tick(side)


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
	##   * 以太守卫 9067：效果区非空 → 每张效果卡 +1 力量 +2 生命。
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
	## 手牌已满 → 不动卡组直接落空（连刺 / 幽灵亡语 / 影子猫 / 预判② 共用）。
	if state.hand_full():
		_log("手牌已满（%d 张）→ 技能卡留在卡组" % FieldState.HAND_LIMIT)
		return null
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
	state.hand.append(c)
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
	## 等选完（fate_pick 收尾）再补结算。
	if side != SIDE_SELF:
		return
	# ⚠️ R90 新增 `sys_upgrade_pending`（「系统升级」的选牌面板开着）——
	# 少一个就出 bug：面板期间回合收尾会照常结算，把「手牌空了 → 抽 1 张」之类
	# 的效果打乱玩家正在做的选择。
	if revive_pending or crow_pending or whale_pending or foresight_pick or fate_pending \
			or endless_pending or sys_upgrade_pending or shadow_step_pending \
			or focus_pending:
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


func _glowgrass_supply(side: String) -> void:
	## 幽光（9099 效果卡）：回合开始时，把一张荧光草 token 加入手卡（手牌满 → 落空）。
	if not _zone_has_id(side, GLOW_ID):
		return
	if state.hand_full():
		_log("幽光：手牌已满，荧光草没有加入")
		return
	var repo := CardRepo.load_json()
	var base: CardData = repo.get_card(GLOWGRASS_ID)
	var grass := CardData.from_dict(base.to_dict()) if base != null else _fallback_glowgrass()
	state.hand.append(grass)
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
	for c2: Vector2i in cells:
		var q := state.unit_at(c2)
		if q == null or q.owner == side or q.card.traits.has(SPELL_IMMUNE_TRAIT):
			continue
		_hit_unit(q, amount, "回旋斩")
		hits += 1
	_destroy_dead()
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
	## 能量之外的「使用条件」（显示 / UI / 引擎同一判定）：
	## 回旋斩（9096）：本回合使用 4 张以上其他卡后才能使用。
	if card != null and card.id == WHIRL_BLADE_ID:
		var plays := state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
		return plays >= WHIRL_BLADE_NEED
	return true


func _fate_reject(side: String) -> String:
	## 拒绝命运（9098）：丢弃所有手卡 → 从弃牌区选等量的卡（面板必须选满）。
	## 本卡随后消失（use_spell 里不进弃牌区），所以面板里选不到它自己。
	if side != SIDE_SELF:
		return "（拒绝命运：敌方 AI 不使用这张卡）"
	var n := state.hand.size()
	if n > 0:
		state.discard.append_array(state.hand)
		state.hand.clear()
		_log("拒绝命运：丢弃 %d 张手卡" % n)
	fate_count = n
	if n > 0:
		fate_pending = true
		_log("拒绝命运：从弃牌区选择 %d 张卡加入手卡" % n)
	else:
		_log("拒绝命运：手牌本来就是空的，效果落空")
	return "丢弃 %d 张，选回 %d 张" % [n, n]


func fate_options() -> Array[int]:
	var out: Array[int] = []
	for i in state.discard.size():
		out.append(i)
	return out


func fate_pick(discard_index: int) -> bool:
	if ReplayLog.recording:
		ReplayLog.act("fate_pick", [discard_index])
	if not fate_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	if state.hand_full():
		_log("拒绝命运：手牌已满，剩余取牌作废")
		fate_pending = false
		fate_count = 0
		return false
	var c: CardData = state.discard[discard_index]
	state.discard.remove_at(discard_index)
	state.hand.append(c)
	fate_count -= 1
	_log("拒绝命运：%s 回到手牌（还要选 %d 张）" % [c.card_name, maxi(0, fate_count)])
	action.emit("fate_pick", {"card": c})
	if fate_count <= 0:
		fate_pending = false
		_sleepless_tick(SIDE_SELF)   # 选完了才补「没有手卡」的判定
	return true


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
	if ReplayLog.recording:
		ReplayLog.act("foresight_choose", [mode])
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
	if ReplayLog.recording:
		ReplayLog.act("foresight_pick_card", [discard_index])
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
			state.discard.remove_at(v_i)
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
	if state.board.has(dst) or dst.x == forbidden_row_for(side):
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
	if ReplayLog.recording:
		ReplayLog.act("cast_infiltrate", [hand_index, ally_cell, dst])
	## 潜入的两段施放入口（UI：先点盟友、再点目的格）。
	if hand_index < 0 or hand_index >= state.hand.size():
		return "（潜入：手牌序号无效）"
	var card: CardData = state.hand[hand_index]
	if card == null or card.id != INFILTRATE_ID:
		return "（这不是潜入）"
	var p := state.unit_at(ally_cell)
	if p == null or p.owner != SIDE_SELF or p.card.kind != "盟友":
		return "（需要指定一个自己的盟友）"
	if state.board.has(dst) or dst.x == forbidden_row_for(SIDE_SELF):
		return "（目的地必须是空格，且不能是对方的后排）"
	_pay(card)
	state.hand.remove_at(hand_index)
	var detail := _infiltrate_cast(SIDE_SELF, ally_cell, dst, card)
	_log("使用技能 %s → %s" % [card.card_name, detail])
	action.emit("spell", {"card": card, "detail": detail})
	_note_card_played(SIDE_SELF, card)
	state.discard.append(card)
	return detail


func cast_swap_units(hand_index: int, cell_a: Vector2i, cell_b: Vector2i) -> String:
	## 「双向传送」（8061，R102，机械之心 0 费稀有）的两段施放入口：
	## UI 先点单位甲、再点单位乙。
	##
	## 与「潜入」9100 同一套路：`use_spell` 已在**付费之前**拦掉单段入口，
	## 所以 `_pay` 在**这里**扣。两格必须**不同**、都必须有单位
	##（交换是「两个单位换位置」，空格不参与）。
	if ReplayLog.recording:
		ReplayLog.act("cast_swap_units", [hand_index, cell_a, cell_b])
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
	state.board[cell_a] = pb
	state.board[cell_b] = pa
	var detail := "%s ⇄ %s 交换了位置" % [pa.card.card_name, pb.card.card_name]
	action.emit("swap_units", {"a": cell_a, "b": cell_b,
			"card_a": pa.card, "card_b": pb.card})
	return detail


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
	var out: Array = []
	if mine.size() >= 2:
		out = [mine[0], mine[1]]
	elif mine.size() == 1 and foes.size() >= 1:
		out = [mine[0], foes[0]]
	elif foes.size() >= 2:
		out = [foes[0], foes[1]]
	return out


func cast_sys_upgrade(hand_index: int, target_hand_index: int) -> String:
	## 「系统升级」（8039，R90，机械之心 1 费稀有）的两段施放入口：
	## UI 先点「系统升级」→ 再点**手牌里**一张盟友 / 工事。
	##
	## 与「潜入」9100 同一套路（付费前已在 `use_spell` 拦截单段入口）：
	##   * `_pay` 在**这里**扣（不是 `use_spell`）；
	##   * 目标卡**留在手牌里**（就地改造，原位替换）—— 只有「系统升级」自己进弃牌区。
	##   * `_sys_upgrade_hand_card` 走「复制 + 原位替换」，手牌顺序与扇形布局不受影响。
	if ReplayLog.recording:
		ReplayLog.act("cast_sys_upgrade", [hand_index, target_hand_index])
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


	## 精进（白魔法师 9021）：回合开始力量 +MAGE_GROW_BUFF（永久累计，无上限，无前置条件）。
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
	if played.id == AETHER_ROAR_ID or played.id == SPACE_GUARD_ID:
		return
	if not (played.is_effect() or played.is_spell()):
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
		if cell.x > best_row:
			best_row = cell.x
			near = [cell]
		elif cell.x == best_row:
			near.append(cell)
	if near.is_empty():
		_log("空间守护：场上没有敌方单位，未生效")
		return
	var t: Vector2i = near[rng.randi() % near.size()]
	var p: Placement = state.unit_at(t)
	var msg:= _knockback(SIDE_SELF, t, steps)
	_log("空间守护：%s" % msg)
	action.emit("space_guard", {"steps": steps, "card": p.card})


func _egg_to_hand(reason: String) -> void :

	if state.hand_full():
		_log("%s：手牌已满（%d 张），没有加入鸭蛋" % [reason, FieldState.HAND_LIMIT])
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return
	var repo:= CardRepo.load_json()
	var base: CardData = repo.get_card(EGG_CARD_ID)
	if base == null:
		_log("%s：找不到鸭蛋（9022）" % reason)
		return
	var egg:= CardData.from_dict(base.to_dict())
	state.hand.append(egg)
	_log("%s：一张「%s」加入手卡" % [reason, egg.card_name])
	action.emit("egg_token", {"card": egg})


func _mirror_reflect(side: String, played: CardData) -> void :


	if played == null:
		return
	if side == SIDE_SELF:
		state.deck.append(CardData.from_dict(played.to_dict()))
		_log("镜像：将一张「%s」加入本局卡组" % played.card_name)
	else:
		state.opp_deck_count += 1
		_log("镜像（敌方）：本局卡组 +1 张「%s」" % played.card_name)


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
	if state.hand_full():
		_log("使魔之夜：手牌已满（%d 张），没有加入乌鸦" % FieldState.HAND_LIMIT)
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return
	var repo:= CardRepo.load_json()
	var base: CardData = repo.get_card(CROW_ID)
	var crow:= CardData.from_dict(base.to_dict()) if base != null else _fallback_crow()
	# 当回合免费：不改卡本身的费用（那会永久变成 0 费），而是记进「本回合免费」名单，
	# 回合结束随 turn_free 一起清空 → 之后再抽到就是原本的 1 费。
	state.turn_free[crow] = true
	state.hand.append(crow)
	_log("使魔之夜：一张「%s」加入手卡（本回合费用 0）" % crow.card_name)
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
	var p:= state.place(card, cell, SIDE_OPPONENT)
	_log("对方支付 %d 能量，%s 上场（%s）" % [card.cost, card.card_name, cell])
	action.emit("place", {"cell": cell, "card": card, "side": SIDE_OPPONENT})
	_note_card_played(SIDE_OPPONENT, card)
	return p


func remote_spell(card: CardData, target, side:= SIDE_OPPONENT) -> String:

	if card != null and card.x_cost:
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


func _run_spell_effect(card: CardData, target, side:= SIDE_SELF) -> String:

	match card.id:
		8002:
			return str(_op_deal_damage(side, _spell_dmg(side, 4, card), target))
		UPGRADE_ID:
			# 升级 8027（R82，机械之心）：改造一个己方盟友或工事。
			# 走 _run_spell_effect 而不是 use_spell 的分支 → 蓄力（9085）叠它会叠多次，
			# 与「连刺 / 火焰箭」等普通技能同一口径。
			return _upgrade_unit(target, side)
		ARMOR_PLATE_ID:
			# 加厚装甲 8044（R95，机械之心）：改造一个己方**盟友** → +4 生命（算一层改造）。
			return _armor_plate(target, side)
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
		BATCH_UPGRADE_ID:
			# 批量改造 8031（R86，机械之心）：手牌里所有盟友 / 工事 +1 生命。
			return _batch_upgrade(side)
		BATCH_TRANSFER_ID:
			# 批量传输 8040（R90，机械之心）：手牌里所有盟友 / 工事 +1 费 / +3 力 / +6 血
			# （烤进副本、本场战斗永久），**然后抽 1 张**。无目标、不可选。
			# ⚠️ 走 `_run_spell_effect` → 蓄力（9085）叠它会叠多次（抽多张牌），
			# 与「批量改造」等普通技能同一口径。
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
		9007:
			return _blast(_spell_dmg(side, 20, card), target, 1)
		9010:
			var wp:= _target_placement(side, target)
			if wp == null:
				return "（没有目标）"
			wp.atk_debuff += 9
			_log("%s 被削弱：下回合攻击力 -9" % wp.card.card_name)
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
		GOLEM_SPELL_ID:
			return _golem_spell(side, target)
		GOUGE_ID:
			var gg_s := str(_op_deal_damage(side, _spell_dmg(side, GOUGE_DMG, card), target))
			if side == SIDE_SELF:
				var gg_c := _fetch_skill_from_deck(1)
				gg_s += "；连刺：%s" % (("卡组 0 费技能卡「%s」加入手卡" % gg_c.card_name) if gg_c != null else "卡组里没有 0 费技能卡")
			return gg_s
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
		AMBUSH_ID:
			return _emergency_ambush(side)
		DOUBLE_TRAP_ID:
			return _double_field_spell(side, target)
		ALERT_ID:
			return _alertness(side)
		HUNT_ID:
			# 暗影狩猎（9107；R74 口径改为「场地」）：12 伤；目标「上回合触发过场地」→ 24 伤。
			# 判据仍是 trap_trig_turn 与当前全局半回合号差 1（隔回合失效）；
			# 场地触发与机关工坊被破坏都会记这个号，所以两者都吃这 24 伤。
			var hu_p := _target_placement(side, target)
			if hu_p == null:
				return "（暗影狩猎：需要指定一个目标）"
			if hu_p.owner == side:
				return "（暗影狩猎：只能指定敌人）"
			var hunt_big := hu_p.trap_trig_turn >= 0 and turn_total - hu_p.trap_trig_turn == 1
			var hu_dmg := _spell_dmg(side, HUNT_BIG_DMG if hunt_big else HUNT_DMG, card)
			var hu_s := str(_op_deal_damage(side, hu_dmg, target))
			if hunt_big:
				_log("暗影狩猎：%s 上回合触发过场地 → 伤害 12 → %d" % [hu_p.card.card_name, hu_dmg])
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
	_log("在启动了：在 %s 召唤一个铁栅栏（0/%d）" % [cell, fence.health])
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
	var hp_hit:= {}
	for c2: Vector2i in cells:
		var q:= state.unit_at(c2)
		if q != null and q.card.traits.has(SPELL_IMMUNE_TRAIT):
			continue
		if q == null:
			var ow:= hp_row_owner(c2.x)
			if ow != "":
				if hp_hit.has(ow):
					continue
				hp_hit[ow] = true
		if damage_cell(c2, amount, "陨石") > 0:
			hits += 1
	_destroy_dead()
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
	if ReplayLog.recording:
		ReplayLog.act("revive_recall", [discard_index])

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
	if ReplayLog.recording:
		ReplayLog.act("shadow_step_recall", [discard_index])

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
	focus_pending = true
	_log("专注：从抽牌库移除 %d 张卡（本次对战中消失）" % can)
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
	if ReplayLog.recording:
		ReplayLog.act("focus_pick", [deck_index])

	if not focus_pending:
		return false
	if deck_index < 0 or deck_index >= state.deck.size():
		return false
	var c: CardData = state.deck[deck_index]
	state.deck.remove_at(deck_index)
	focus_remaining -= 1
	_log("专注：%s 从抽牌库移除（本次对战中消失，还要移除 %d 张）"
			% [c.card_name, maxi(0, focus_remaining)])
	action.emit("focus_pick", {"card": c})
	if focus_remaining <= 0:
		focus_pending = false
		focus_remaining = 0
	return true


func focus_cancel() -> void:
	## 专注面板取消（清挂起状态；已移除的卡**不回收** —— 它已经消失了）。
	if not focus_pending:
		return
	_log("专注：已取消剩余的移除")
	focus_pending = false
	focus_remaining = 0


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



	if p == null or p.card.kind != "盟友":
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


func _rat_trigger() -> void :


	if state.hand_full():
		_log("巨鼠：手牌已满，无法抽取")
		return
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
	state.hand.append(chosen)
	_log("巨鼠：从卡组抽到 1 费盟友 %s" % chosen.card_name)


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
	## 「谁替己方 HP 承受伤害」的**唯一判定**：森林守护（guarding）/ 以太守卫 / 铁栅栏
	## 三种卡走的是同一套机制，所以战场表现也必须一致（同色绿环）。
	## 以后再加同类机制，只改这里 —— 引擎与 battle_scene 读同一函数，不会两处漂移。
	if p == null:
		return false
	return p.guarding or p.card.traits.has(AETHER_GUARD_TRAIT)\
	or p.card.traits.has(IRON_FENCE_TRAIT)


func _guard_cell(side:= SIDE_SELF) -> Vector2i:


	var best:= Vector2i(-1, -1)
	for cell: Vector2i in state.board:
		var p: Placement = state.board[cell]
		if p.owner != side or not absorbs_for_hp(p):
			continue
		if best == Vector2i(-1, -1) or cell < best:
			best = cell
	return best


func _absorb_by_guard(amount: int) -> bool:



	if amount <= 0:
		return false
	var cell:= _guard_cell(SIDE_SELF)
	if cell == Vector2i(-1, -1):
		return false
	var g: Placement = state.board[cell]
	var gname:= g.card.card_name
	var how:= "以太守卫" if g.card.traits.has(AETHER_GUARD_TRAIT)\
	else ("铁栅栏" if g.card.traits.has(IRON_FENCE_TRAIT) else "森林守护")
	var dealt:= _hit_unit(g, amount, how)
	_log("%s：%s 替我方 HP 承受 %d 点伤害（剩余 %d）" % [how, gname, dealt, g.health])
	action.emit("guard_absorb", {"card": g.card, "how": how, "amount": dealt})
	if g.health <= 0:

		_destroy(cell)
	return true


func _dodge_absorb(amount: int) -> int:
	## 闪躲（9103）：随机一个己方**盟友**（kind == "盟友"，工事不参战）代替本方 HP 承受伤害。
	## 它生命不足 → 只吃掉剩余的生命（随即被破坏），剩下的照旧由自己承担。
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
	var absorbed:= mini(amount, maxi(0, g.health))
	_hit_unit(g, absorbed, "闪躲代受")
	_log("闪躲：%s 替我方 HP 承受 %d 点伤害（超出 %d 仍由自己承担）" % [
			g.card.card_name, absorbed, amount - absorbed])
	action.emit("dodge_absorb", {"card": g.card, "cell": cell2,
			"absorbed": absorbed, "rest": amount - absorbed})
	if g.health <= 0:
		_destroy(cell2)
	return amount - absorbed


func _ally_dmg_bonus(card: CardData, side: String) -> int:

	if card == null or card.kind != "盟友":
		return 0
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(BEAST_TRAIT):
			return BEAST_DMG_BONUS
	return 0


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
	if ReplayLog.recording:
		ReplayLog.act("crow_recall", [discard_index])

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
	if ReplayLog.recording:
		ReplayLog.act("whale_pick", [discard_index])


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
	if ReplayLog.recording:
		ReplayLog.act("whale_skip", [])

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


func _hit_unit(p: Placement, amount: int, source:= "效果", allow_redirect:= true) -> int:
	# 「侦察塔」（8032）光环易伤（R120）：攻击范围内的敌人，受到**任何来源**的伤害 +1/层。
	# ⚠️ 必须放在 `amount <= 0` **之前**：0 攻的侦察塔自己攻击时基础伤害是 0，
	#    而卡面口径是「自己打也算」—— 光环得先加进去，否则那一下会被直接吞掉。
	# 挂在这里 = 与能量屏障同一个「所有伤害路径的唯一口」，漏在这里的路径会被光环绕过。
	# ⚠️ 只在**最外层**调用加（`allow_redirect`）—— 护盾生成器转发时传的是同一笔伤害，
	#    在那儿再加一次会**双算**。
	if allow_redirect:
		var aura:= _scout_aura_bonus(p, _cell_of(p))
		if aura > 0:
			_log("侦察塔光环：%s 受到的伤害 +%d（%d → %d）" % [
					p.card.card_name, aura, amount, amount + aura])
			action.emit("scout_aura", {"cell": _cell_of(p), "card": p.card,
					"bonus": aura, "base": amount, "amount": amount + aura,
					"side": p.owner})
			amount += aura


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
			_hit_unit(gen, amount, source, false)
			return 0
	var dmg:= amount
	if p.owner == SIDE_SELF:
		dmg = _relic_damage_taken(dmg)
	p.health -= dmg
	_log("%s 受到 %d 点%s伤害（剩余 %d）" % [p.card.card_name, dmg, source, p.health])
	# 恶魔鸭 9116（R63）：受击反应挂在这里 = 所有伤害路径（普通攻击 / 技能 / 效果）的唯一口。
	# 死了就不再触发（沉睡了也没意义），所以只在活着的分支调。
	if p.health > 0:
		_demon_duck_hurt(p, _cell_of(p))
	if p.owner == SIDE_SELF:
		_on_self_damaged()
	else:
		_mark_spell_enemy_hit()
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
	## 道具「护心」（6006）：伤害 ≥ 5 时 -1（最少 1）。所有 HP 伤害的最后一道统一减伤。
	if self_relics.has(6006) and dmg >= 5:
		return maxi(1, dmg - 1)
	return dmg


func _hp_damage_taken(amount: int) -> int:
	## 玩家 HP 伤害的**统一入口**：以太屏障 / 石肤（都把这次伤害压成 1）→
	## 效果牌减伤（_effect_damage_reduction）→ 道具减伤（_relic_damage_taken）。
	## 注意：荒野形态 6022 的「第一次受击 -4」**不走这里**（它只认普通攻击直击 HP，
	## 挂在 attack_hp 里单独判），否则法术 / 效果伤害也会被算进去。
	if amount <= 0:
		return 0
	if _aether_left > 0:
		_aether_left -= 1
		_log("以太屏障：这次伤害变为 1（原本 %d，本回合还剩 %d 次）" % [amount, _aether_left])
		action.emit("aether_hit", {"left": _aether_left, "amount": amount})
		return 1

	if _stoneskin_left > 0:
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
	return _relic_damage_taken(dmg)


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
	return out + turn_dmg_bonus


func _turn_dmg_bonus(side: String) -> int:

	return turn_dmg_bonus if side == SIDE_SELF else 0


func _on_self_damaged() -> void :



	if not self_relics.has(6012) or _rice_used:
		return
	_rice_used = true
	turn_spell_bonus += 1
	var drawn:= _draw_many(1)
	_log("一袋米抗几楼：本轮首次受伤 → 抽 %d 张卡，本回合技能伤害 +1" % drawn)
	action.emit("rice", {"drawn": drawn, "spell_bonus": turn_spell_bonus})


func _on_self_hp_damaged() -> void :



	if not self_relics.has(PEAR_RELIC_ID):
		return
	state.max_hp_self += 1
	_log("鸭梨：我方 HP 受伤 → 最大生命 +1（当前 %d/%d）" % [
		state.hp_self, state.max_hp_self])
	action.emit("pear", {"hp": state.hp_self, "max_hp": state.max_hp_self})


func _knockback(side: String, target, steps: int) -> String:

	var p:= _target_placement(side, target)
	if p == null:
		return "（没有目标）"
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
	return "闪电击中 %d 个相连单位" % hits


func _blast(amount: int, target, radius: int) -> String:



	if not (target is Vector2i):
		return "（需要一个目标格子）"
	var center: Vector2i = target
	var hits:= 0
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

	var foe:= SIDE_SELF if p.owner == SIDE_OPPONENT else SIDE_OPPONENT
	var hits:= 0
	for c: Vector2i in state.board.keys().duplicate():
		var q:= state.unit_at(c)
		if q == null or q.owner != foe:
			continue
		_hit_unit(q, ASH_DRAGON_AOE, "灰烬龙")
		hits += 1
	if hits > 0:
		_destroy_dead()
	_log("%s 战吼：对 %d 个敌方单位造成 %d 点伤害" % [p.card.card_name, hits, ASH_DRAGON_AOE])
	action.emit("battlecry", {"cell": cell, "card": p.card, "kind": "ash", 
		"amount": ASH_DRAGON_AOE, "hits": hits})


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
		_:
			pass


func _summon_token(card_id: int, near: Vector2i, side: String, count: int) -> void :

	var repo:= CardRepo.load_json()
	var spawn: CardData = repo.get_card(card_id)
	if spawn == null:
		_log("召唤失败：卡牌库里没有 id=%d" % card_id)
		return
	for i in count:
		var spot:= _token_spot(near, side)
		if spot == Vector2i(-1, -1):
			break
		var summoned:= state.place(spawn, spot, side)
		_log("亡语：召唤了 %s（%s）" % [spawn.card_name, spot])
		action.emit("place", {"cell": spot, "card": spawn, "side": side})
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
	return cell.x != forbidden_row_for(side)


func _deathrattle_place_trap(cell: Vector2i, p: Placement) -> void :
	## 捕兽大师（9126，R116）亡语：**在原地**留下一张随机陷阱。
	## 来源与「双重场地」9108 / 机关工坊 8015 同一个池（唯一口 `_trap_card_pool`）；
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
	for c2: Vector2i in cells:
		var q:= state.unit_at(c2)
		if q == null:
			continue
		_hit_unit(q, amount, "爆裂")
	_destroy_dead()
	action.emit("blast", {"center": center, "cells": cells, "amount": amount, "card": card})


func _death_blast(center: Vector2i, amount: int, card: CardData) -> void :



	var cells: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c:= center + d
		if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
			continue
		cells.append(c)
	_log("%s 死亡爆炸：周围 %d 格各受到 %d 点伤害" % [card.card_name, cells.size(), amount])

	var blasted_hp:= {}
	for c2: Vector2i in cells:
		if state.unit_at(c2) == null:
			var ow:= hp_row_owner(c2.x)
			if ow != "":
				if blasted_hp.has(ow):
					continue
				blasted_hp[ow] = true
		damage_cell(c2, amount, "爆炎")
	_destroy_dead()
	action.emit("blast", {"center": center, "cells": cells, "amount": amount, "card": card})


func _overload_tick(side: String) -> void :
	## 「超负荷」（旧式机兵 8050，R98）：**己方回合结束时**，
	## 带「超负荷」且生命为负的单位**真正死亡**（直接 _destroy，不触发后排「溢出伤害」）。
	## 生命已回到 0 或以上（本回合被治疗拉回）的单位则继续存活。
	var dead_cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.card.has_affix(AFFIX_OVERLOAD) \
				and p.health < 0:
			dead_cells.append(cell)
	for cell: Vector2i in dead_cells:
		var p: Placement = state.unit_at(cell)
		if p == null:
			continue
		_log("超负荷：%s 生命仍是 %d，己方回合结束死亡" % [p.card.card_name, p.health])
		action.emit("overload_die", {"cell": cell, "card": p.card,
			"health": p.health, "side": side})
		_destroy(cell)


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
				_log("超负荷：%s 生命降至 %d，暂不死亡（己方回合结束若仍为负则死亡）"
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
			action.emit("trample", {"side": pside, "amount": over, "def_name": pname})
			_damage_player(pside, over, "溢出")
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
		var amount2:= amount
		if p.owner == SIDE_SELF:
			amount2 = _relic_damage_taken(amount)
		p.health -= amount2
		if p.owner == SIDE_OPPONENT and amount2 > 0:
			_mark_spell_enemy_hit()
		_log("%s 受到 %d 点效果伤害（剩余 %d）" % [p.card.card_name, amount2, p.health])
		if p.health <= 0:
			_destroy_dead()
		return "%s -%d" % [p.card.card_name, amount2]

	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var left:= _damage_player(foe, amount, "效果")
	return "对玩家造成 %d 伤害" % amount


func _damage_player(side: String, amount: int, source:= "") -> int:
	if side == SIDE_SELF:
		# 闪躲（9103）：窗口期内先让随机盟友代受（不足的部分才落到自己的 HP 上）。
		if _dodge_active and amount > 0:
			amount = _dodge_absorb(amount)
			if amount <= 0:
				_check_game_over()
				return state.hp_self

		if _absorb_by_guard(amount):
			return state.hp_self

		var dmg:= _hp_damage_taken(amount)
		state.hp_self = maxi(0, state.hp_self - dmg)
		if dmg != amount:
			_log("减伤（迅捷/鸭嘴）：伤害 %d → %d" % [amount, dmg])
		_log("我方 HP -%d（%s），剩余 %d" % [dmg, source, state.hp_self])
		if dmg > 0:
			_on_self_damaged()
			_on_self_hp_damaged()
		_check_game_over()
		return state.hp_self
	if amount > 0:
		_mark_spell_enemy_hit()
	state.hp_opponent = maxi(0, state.hp_opponent - amount)
	var left2:= state.hp_opponent
	_log("敌方 HP -%d（%s），剩余 %d" % [amount, source, left2])
	_check_game_over()
	return left2


func _cell_of(p: Placement) -> Vector2i:
	for cell: Vector2i in state.board:
		if state.board[cell] == p:
			return cell
	return Vector2i(-1, -1)


func _tap(p: Placement, reason:= "") -> void :


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


func _credit_kill(victim: Placement) -> void :
	## 击杀记功：把这次击杀算给「最后一下是谁打的」（last_hit_by）。
	## 鸭子骑士（9001）：每击杀一个敌方单位，攻击力 +KNIGHT_KILL_BUFF（永久累计）。
	if victim.last_hit_by == Vector2i(-1, -1):
		return
	var killer:= state.unit_at(victim.last_hit_by)
	if killer == null or killer.owner == victim.owner:
		return
	if not killer.card.traits.has(KNIGHT_TRAIT):
		return
	killer.atk_buff += KNIGHT_KILL_BUFF
	_log("鸭子骑士击杀 %s → 攻击力 +%d（当前 %d）" % [
		victim.card.card_name, KNIGHT_KILL_BUFF, killer.effective_power()])
	action.emit("knight_grow", {"cell": victim.last_hit_by, "card": killer.card,
		"amount": KNIGHT_KILL_BUFF, "power": killer.effective_power()})


func configure_growth(cfg: Dictionary) -> void :
	## 关卡成长曲线（二层「低开高走」）：开局按体型削攻击力，之后每 period 个回合 +inc，最多 cap。
	## cfg 为空 = 不启用。摆好敌方单位后调用；只对 SIDE_OPPONENT 生效。
	## cfg 字段：mod_strong / mod_weak / strong_atk / start_turn / period / inc / cap
	growth_cfg = cfg
	_growth_stacks = 0
	_sync_enemy_growth()


func _growth_mod(card: CardData) -> int:
	## 开局攻击力修正：强力怪（基础攻击力 >= strong_atk）mod_strong，其余 mod_weak（可为负）。
	if growth_cfg.is_empty():
		return 0
	var strong_atk:= int(growth_cfg.get("strong_atk", GROWTH_STRONG_ATK))
	if card.power >= strong_atk:
		return int(growth_cfg.get("mod_strong", 0))
	return int(growth_cfg.get("mod_weak", 0))


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
		p.atk_growth = _growth_mod(p.card) + _growth_stacks * inc


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


func _recycler_trigger(r: Placement, victim_power: int) -> void :
	## 「零件回收者」（8046，R96）的唯一结算口，由 `_destroy` 在 erase 之后调用。
	if r == null or r.owner != SIDE_SELF or r.card.id != RECYCLER_ID:
		return
	r.upgrade_atk += victim_power
	_log("零件回收者：回收 %d 力量（现 +%d 攻）" % [victim_power, r.upgrade_atk])
	# 往手牌加一张「素体」（独立副本，与机械核心 6025 同口径；手牌满就停）。
	if state.hand_full():
		_log("零件回收者：手牌已满，未加入「素体」")
	else:
		var repo := CardRepo.load_json()
		var proto: CardData = repo.get_card(PROTO_ID)
		if proto != null:
			state.hand.append(CardData.from_dict(proto.to_dict()))
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
	for c: Vector2i in targets:
		var u: Placement = state.unit_at(c)
		if u == null:
			continue
		got_atk += u.effective_power()
		got_hp += u.card.health
		_destroy(c)
	# 吸收到的攻/血落到嵌合暴君（与 _upgrade_unit 同口径，离场由 _card_leaving_field 还原）。
	tyrant.upgrade_atk += got_atk
	tyrant.upgrade_hp += got_hp
	tyrant.card.health += got_hp
	tyrant.health += got_hp
	_log("嵌合暴君：融合 %d 张卡 → 力量 +%d、生命 +%d（现 %d 攻 / %d 血）" % [
		targets.size(), got_atk, got_hp, tyrant.effective_power(), tyrant.health])
	action.emit("chimera", {"cell": _cell_of(tyrant), "absorbed": targets.size(),
		"atk": got_atk, "hp": got_hp, "side": SIDE_SELF})


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
		state.deck.append(up)        # 加进抽牌堆（末尾），本场之后抽到即改造版素体
		added += 1
	_log("生产订单：卡组 +%d 张改造「素体」（各 +%d 攻 / +%d 血，永久）"
		% [added, PROD_ORDER_ATK, PROD_ORDER_HP])
	action.emit("prod_order", {"count": added, "atk": PROD_ORDER_ATK,
		"hp": PROD_ORDER_HP, "side": side})
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
	if proto != null and not state.hand_full():
		state.hand.append(CardData.from_dict(proto.to_dict()))
		got_proto += 1
	var got_upg:= 0
	if was_upgraded and not state.hand_full():
		var up_repo := CardRepo.load_json()
		var up_proto: CardData = up_repo.get_card(DEMOLISH_UPGRADE_BONUS) if up_repo != null else null
		if up_proto != null:
			state.hand.append(CardData.from_dict(up_proto.to_dict()))
			got_upg += 1
	_log("拆解：破坏了%s（%s），回复 %d 费，手牌 +%d 素体%s"
		% [victim_name, "已改造" if was_upgraded else "未改造", DEMOLISH_REFUND,
			got_proto, ("，额外 +%d 升级" % got_upg) if was_upgraded else ""])
	action.emit("demolish", {"cell": target, "upgraded": was_upgraded,
		"refund": DEMOLISH_REFUND, "got_proto": got_proto, "got_upg": got_upg,
		"side": side})
	return "拆解：破坏%s，回复 %d 费%s" % [victim_name, DEMOLISH_REFUND,
		("，额外获得升级" if was_upgraded else "")]


func _destroy(cell: Vector2i) -> void :
	if not state.board.has(cell):
		return
	var p: Placement = state.board[cell]
	# R96：零件回收者触发预判 —— 在 erase 之前抓同连通块的回收者与被销毁卡的力量。
	var _rec_power:= p.effective_power() if (p != null) else 0
	var _rec_victim_ok:= false
	var _rec_list: Array[Placement] = []
	if p != null and p.owner == SIDE_SELF \
			and (p.card.kind == "盟友" or p.card.is_fort()):
		_rec_victim_ok = true
		for rc in _component_of_cell(cell):
			var ru: Placement = state.unit_at(rc)
			if ru != null and ru != p and ru.card.id == RECYCLER_ID \
					and ru.owner == SIDE_SELF:
				_rec_list.append(ru)
	state.board.erase(cell)
	_credit_kill(p)
	if p.owner == SIDE_SELF:
		if p.card.traits.has(EGG_VANISH_TRAIT):

			_log("%s 被击破，移出场外（离场即消失，不进弃牌区）" % p.card.card_name)
		elif p.card.is_ephemeral:
			# 野兔 9032 的**复制**（R82）：**场上这段也消失**，不进弃牌区、不洗回牌库。
			# 判据是 `is_ephemeral`（衍生物标记）而**不是** trait「自我复制」——
			# 卡库里的原卡也带那个 trait，它被打死时应该照常进弃牌区。
			_log("%s（复制）被击破，移出场外（消失，不进弃牌区）" % p.card.card_name)
		elif p.card.id == ICE_WALL_ID:

			_log("%s 被击破，移出场外（冰墙不进弃牌区）" % p.card.card_name)
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

	if p.card.id == BLAZE_DUCK_ID:
		_death_blast(cell, BLAZE_DUCK_DAMAGE, p.card)
	_deathrattle(cell, p)
	# R74：双重陷阱的「单位被破坏 → 召唤」已改写成「场地触发 → 追加场地」，
	# 标记挂在格子上（state.field_chains），触发口唯一 = _field_trigger 末尾的
	# _twin_field_chain。所以这里**不再**有任何 twin_trap 分支。
	_check_game_over()
	# R96：零件回收者 —— 被销毁的是己方盟友/工事时，连通块内的回收者回收其力量 + 手牌加素体。
	if _rec_victim_ok:
		for _r in _rec_list:
			_recycler_trigger(_r, _rec_power)
	# R111 暗影领主：场上少了一个单位 → 重算（死的是暗杀者时鸭之暗面立刻掉 3 力 1 速）。
	_refresh_dark_lord(p.owner)




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
		if q.owner != s and attack_distance(cell, other, s, c) <= c.attack_range:
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
		if attack_distance(cell, t, side, c) <= c.attack_range:
			result.append(t)
	return result


func move(src: Vector2i, dst: Vector2i, side:= SIDE_SELF, blink:= false) -> void :
	if ReplayLog.recording and side == SIDE_SELF:
		ReplayLog.act("move", [src, dst])
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
		if dst.x == forbidden_row_for(side):
			_log("不能移动到对方后排")
			return
		path.append(src)
		path.append(dst)
	else:
		if dst.x == forbidden_row_for(side):
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
	if ReplayLog.recording and side == SIDE_SELF:
		ReplayLog.act("activate", [cell])
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
			PIERCE_TRAP_TRAIT, MASS_TRAP_TRAIT, DARK_TRAP_TRAIT]:
		if c.traits.has(t):
			return t
	return ""


func _field_mastery(field_side: String, field_card: CardData) -> int:
	## 场地精通（9105，R74 由「陷阱精通」改名）：持有方效果区有它 →
	## 该方**场地**效果造成的伤害 +2× 该场地卡的**原本费用**。
	## 多张不叠加（与哈气同取一张）；按卡面原费算，不吃任何减费。
	var zone: Array[CardData] = state.effects if field_side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(TRAP_MASTERY_TRAIT):
			return 2 * field_card.cost
	return 0


func _field_card_pool(side: String) -> Array[CardData]:
	## **「本角色奖励池里的场地卡」的唯一口**（R116 抽出）。
	## 原先有 4 处各抄了一份同样的三行：机关工坊 8015 供牌 / 警觉 9109 取场地 /
	## 双重场地 9108 连锁 / 捕兽大师 9126 亡语 —— 加新角色或改池子口径时极易漏改。
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
	## （它列出的那 7 个 trait 就是引擎认的 7 张陷阱），持续型场地（清泉 / 维修间 /
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


func _field_trigger(cell: Vector2i, mover: Placement) -> void :
	## **场地卡触发的唯一口**（R74；R80 扩为「经过即触发」）：挂在 `move()` 里
	## 「移动成功之后」，而落点已由 `_field_block_index` 截断到被触发的那一格。
	## 语义（用户口径）：
	##   * **移动路径上经过**此格即触发（不再要求「终点停在这里」，见 R80）；
	##     原本就站在该格上的敌人**不触发**（不在这段 path 里）；
	##   * 触发一次后**该格场地消失**（一次性）。**先摘牌再结算** ——
	##     场地效果里若再触发别的场地（双重场地），也不会重复触发同一格；
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
	var bonus:= _field_mastery(owner_side, card)
	action.emit("field_trigger", {"cell": cell, "card": card,
		"name": mover.card.card_name, "side": mover.owner})
	if card.traits.has(TRAP_TRAIT):
		_field_explode(cell, card, bonus)
	elif mover.health > 0:
		# 其余几种都是「打给踩上来的那一个单位」；他若已被别的东西打死就不追伤
		if card.traits.has(MASS_TRAP_TRAIT):
			# 巨物陷阱（8017）：单点高伤，打给踩上来的那一个（不分敌我）
			var g_dmg:= _hit_unit(mover, MASS_TRAP_DMG + bonus, "巨物陷阱")
			action.emit("trap_hit", {"cell": _cell_of(mover), "amount": g_dmg,
					"kind": "巨物", "name": mover.card.card_name})
			_log("%s 踩到巨物陷阱：受到 %d 点伤害（剩余 %d）" % [
				mover.card.card_name, g_dmg, mover.health])
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
	# 双重场地（9108，R74）：这个场地触发后 → 同一格随机追加一个随机场地效果。
	# owner_side 显式传进去：field_owner 已被上面的 clear_field 擦掉，这里读不到。
	_twin_field_chain(cell, owner_side)
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
		# ① 治疗：读卡面 field_heal（清泉 2 / 维修间 2 / 其它 0 = 不回血）
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
			p.upgrade_stacks += 1
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
	if healed > 0:
		_log("持续型场地：%d 个单位在自己回合结束时回复了生命" % healed)
	if upgraded > 0:
		_log("改造工厂：%d 个单位获得改造（每回合 +%d 力 / +%d 血，可无限叠）" % [
			upgraded, UPGRADE_FACTORY_ATK, UPGRADE_FACTORY_HP])


func _sleep_tick(side: String) -> void :
	## 沉睡（恶魔鸭 9116，R76 改口径）：**只播「仍在沉睡」的提示，不再递减**。
	## 沉睡现在是「挨打计数」而不是「回合计数」：初始 SLEEP_TURNS(2)，
	## 每挨一下 -1（唯一递减口 = _demon_duck_hurt），**减到 0 立刻恢复行动**。
	## 原来这里每回合结束 -1，等于沉睡 2 会被回合偷偷减掉 2 次、挨一下打就能动 ——
	## 与用户要的「初始 2、每次受伤 -1、归零直接行动」完全不符。
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.sleep_left <= 0:
			continue
		_log("%s 仍在沉睡（还需挨 %d 下才会醒）" % [p.card.card_name, p.sleep_left])


func _demon_duck_hurt(p: Placement, cell: Vector2i) -> void :
	## 恶魔鸭家族的受伤反应：**受击判定的唯一口**（挂在 _hit_unit 里，
	## 所以普通攻击 / 技能 / 效果 / 直伤全都算，不只是普通攻击）。
	## 按 trait 分派两种互斥的「挨打变强」：
	##   沉睡（9116 恶魔鸭）→ 还在睡：sleep_left -1（提前 1 回合醒来，绝不会从 2 直接跳到能行动）；
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
		# R76：沉睡是「挨打计数」而不是「回合计数」—— 每次受伤 -1，减到 0 **立刻**恢复行动。
		# 原来这里只发 hurt 事件，由 _sleep_tick 在本方回合结束时才真醒，
		# 于是「沉睡 2」实际会睡满 2 个回合外加回合结束才醒，和用户要的完全不是一回事。
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


func _emergency_ambush(side: String) -> String:
	## 紧急埋伏（9106，R52）：场上每有一个敌人 → 从**卡组**随机取一张工事进手
	## （卡组没有工事则该次落空；手满则留在卡组）。之后「你使用的下一张工事卡费用 -1」
	## 无条件生效（FieldState.fort_discount_self/opp，消费点唯一在 _note_card_played）。
	## 随机走引擎 rng → 回放同种子可复现。
	var foes:= 0
	for p: Placement in state.board.values():
		if p.owner != side:
			foes += 1
	var forts: Array[CardData] = []
	for c: CardData in state.deck:
		if c.is_fort():
			forts.append(c)
	var taken:= 0
	for i in foes:
		if forts.is_empty():
			_log("紧急埋伏：卡组里已经没有工事卡")
			break
		if state.hand_full():
			_log("紧急埋伏：手牌已满（%d 张），工事留在卡组" % FieldState.HAND_LIMIT)
			action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
			break
		var pick: CardData = forts[rng.randi() % forts.size()]
		forts.erase(pick)
		state.deck.erase(pick)
		state.hand.append(pick)
		taken += 1
		_log("紧急埋伏：卡组里的「%s」进入手卡" % pick.card_name)
	if side == SIDE_SELF:
		state.fort_discount_self += 1
	else:
		state.fort_discount_opp += 1
	_log("紧急埋伏：你使用的下一张工事卡费用 -1")
	if taken > 0:
		action.emit("blessing", {"count": taken})
	return "紧急埋伏：%d 张工事进手，下一张工事 -1 费" % taken


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
		if state.hand_full():
			_log("陷阱工坊：手牌已满（%d 张），本次不加入" % FieldState.HAND_LIMIT)
			action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
			return
		var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		var copy:= CardData.from_dict(pick.to_dict())
		state.hand.append(copy)
		_log("机关工坊：随机一张场地「%s」进入手卡" % copy.card_name)
		action.emit("blessing", {"count": 1})


func _end_turn_surplus(side: String) -> void :
	## 「回合结束 · 剩余费用 / 已花费用」系列六张卡的**唯一结算入口**
	## （end_turn 里在能量清零之前调用）。结算顺序是**规则的一部分**，按序：
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
	for cell: Vector2i in foes:
		var q: Placement = state.unit_at(cell)
		if q == null or q.health <= 0:
			continue
		_hit_unit(q, dmg, "黑暗扩散")
		total += 1
	_destroy_dead()
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
	# 开选牌面板：费用**等选完再给**（选牌面板期间不给能量，避免「先拿钱再选」）。
	endless_pending = true
	_log("无尽黑暗：从手牌中选择 1 张弃掉（不能不选）→ 之后费用 +%d"
			% ENDLESS_DARK_ENERGY)
	action.emit("endless_dark", {"dropped": 0, "names": [],
			"energy": ENDLESS_DARK_ENERGY, "side": side, "pending": true})


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
	if ReplayLog.recording:
		ReplayLog.act("endless_pick", [hand_index])


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
			if q != null and q.owner != side and q.health > 0:
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


func _alertness(side: String) -> String:
	## 警觉（9109，R54；R60 改；**R77 供给口径由「工事」改为「场地**」）：
	## 把一张随机**场地卡**（本角色奖励池，敌方侧退化为完整奖励池）加入手卡，
	## 那张卡**本回合内**费用 -ALERT_DISCOUNT（turn_card_discount = 本回合减费，
	## 回合结束随表清空 → 不跨回合；显示 = 判定 = 实扣都走 cost_of）。**用后警觉自身消失。**
	## 随机走引擎 rng（回放同种子可复现）；库内共享实例 → 复制后再进手。
	if side == SIDE_SELF and state.hand_full():
		_log("警觉：手牌已满（%d 张），场地卡无法加入" % FieldState.HAND_LIMIT)
		action.emit("hand_full", {"limit": FieldState.HAND_LIMIT, "hand": state.hand.size()})
		return "（警觉：手牌已满）"
	# R77：取「场地」而不是「工事」；R116：池子构造走唯一口 `_field_card_pool`
	var pool := _field_card_pool(side)
	if pool.is_empty():
		return "（警觉：奖励池中没有场地卡）"
	var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
	var copy:= CardData.from_dict(pick.to_dict())
	state.hand.append(copy)
	if side == SIDE_SELF:
		# 本回合减费（不是 card_discount 那个永久实例减费）——回合结束自动失效
		state.turn_card_discount[copy] = int(state.turn_card_discount.get(copy, 0)) \
				+ ALERT_DISCOUNT
		_log("警觉：随机一张场地「%s」进入手卡（本回合费用 -%d）"
				% [copy.card_name, ALERT_DISCOUNT])
		action.emit("alert", {"card": copy, "discount": ALERT_DISCOUNT, "side": side})
		return "警觉：%s 进入手卡（本回合费用 -%d）" % [copy.card_name, ALERT_DISCOUNT]
	return "警觉：%s 进入手卡" % copy.card_name


func _double_field_spell(side: String, target) -> String:
	## 双重场地（9108，R74 由「双重陷阱」改名）：给**一个已有场地效果的格子**附魔——
	## 该场地的效果触发并结束之后，在**同一格**对场上一个随机敌人使用一个**随机场地效果**。
	## 与旧版的区别：旧版挂 Placement.twin_trap（单位被破坏时触发）；场地不是单位，
	## 所以标记改记在 `state.field_chains`（格子 → 待触发次数），触发口唯一在
	## `_field_trigger` 末尾的 `_twin_field_chain`。
	## 只认**自己放的场地**（敌方放的场地不给你挂连锁）。
	# 目标既可能是「格子坐标」也可能是「该格上的单位」（技能是 unit 目标模式，
	# 界面上玩家点的是某个单位）——两种都要归一成格子。
	var cell := _field_target_cell(target)
	if not state.field_effects.has(cell):
		return "（双重场地：需要指定一个**已有场地效果**的格子）"
	# 持续型场地（清泉 8028，R83）**不给附魔**：它永不触发，连锁也就永远不会发生 ——
	# 让玩家花一张牌换来「什么都不会发生」是最差的体验。
	if is_persistent_field(state.field_at(cell)):
		return "（双重场地：%s 是持续型场地，不会触发，不能附魔）" % str(state.field_at(cell).card_name)
	if str(state.field_owner.get(cell, side)) != side:
		return "（双重场地：只能给自己的场地追加）"
	state.field_chains[cell] = int(state.field_chains.get(cell, 0)) + 1
	_log("双重场地：%s 的场地触发后将追加一个随机场地效果" % cell)
	action.emit("twin_field", {"cell": cell})
	return "%s 获得双重场地效果" % cell


func _field_target_cell(target) -> Vector2i:
	## 把「双重场地」的目标归一成格子（R74）。
	## 技能是 unit 目标模式 → 界面上玩家点的是**某个单位**；但场地不是单位，
	## 所以这里两种都收：直接给坐标就给坐标，给单位就换算成它所在的格子。
	## 返回 (-1,-1) = 无法归一（调用方据此拒绝）。
	if target is Vector2i:
		return target
	if target is Array and (target as Array).size() >= 2:
		return target[0]
	var pl := _target_placement(SIDE_SELF, target)
	if pl != null:
		return _cell_of(pl)
	return Vector2i(-1, -1)


func _twin_field_chain(cell: Vector2i, owner_side: String) -> void :
	## 双重场地（9108，R74）的连锁落地：本格的场地**刚触发完** → 在同一格
	## 追加一个**随机场地效果**（取自**场地原主人**的角色奖励卡池；敌方侧退化为完整奖励池）。
	## 连锁只吃标记**一次**（用完即清）→ 不会无限套娃。
	# ⚠️ `owner_side` 必须由调用方 `_field_trigger` **显式传进来**：它在那里已经读过一次
	# field_owner（为了算场地精通），而 `clear_field` 会把 field_owner 一起擦掉 ——
	# 若这里再从 state 读，只会拿到 fallback（踩上去那个人的阵营），
	# 于是「敌方踩我方场地」会替**敌方**抽场地卡（实测踩到过）。
	var marked: int = int(state.field_chains.get(cell, 0))
	if marked <= 0:
		return
	state.field_chains.erase(cell)
	var pool := _field_card_pool(owner_side)
	if pool.is_empty():
		_log("双重场地：奖励卡池里没有场地卡")
		return
	# 用户口径「场地效果结束后随机对本格使用场地效果」：直接落在本格，
	# 于是**下一个走进来的敌人**会吃到 —— 场上没人时这格就静静等着。
	var pick: CardData = pool[rng.randi_range(0, pool.size() - 1)]
	state.set_field(pick, cell, owner_side)
	_log("双重场地：%s 追加了场地「%s」（%s方）" % [cell, pick.card_name, owner_side])
	action.emit("field_place", {"cell": cell, "card": pick, "side": owner_side,
		"replaced": false, "chain": true})


func pass_attack(cell: Vector2i, side:= SIDE_SELF) -> void :
	if ReplayLog.recording and side == SIDE_SELF:
		ReplayLog.act("pass", [cell])

	var p:= state.unit_at(cell)
	if p == null or p.owner != side or p.tapped or not p.moved:
		return
	_tap(p, "放弃攻击")


func attack(src: Vector2i, dst: Vector2i, side:= SIDE_SELF) -> void :
	if ReplayLog.recording and side == SIDE_SELF:
		ReplayLog.act("attack", [src, dst])



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
	var def_dmg:= _hit_unit(defender, atk_power, "战斗")
	# R74：场地卡**不是单位**（不在 board 里），所以打不到、也不会被「攻击即死」——
	# 它的触发点唯一在 _field_trigger（挂在 move 上）。这里不再有任何陷阱即死分支。
	var overflow:= 0
	if dst.x == back_row(defender.owner) and def_dmg > hp_before:
		overflow = def_dmg - maxi(hp_before, 0)
	_log("%s 攻击 %s：对方 -%d 生命" % [
		attacker.card.card_name, defender.card.card_name, def_dmg])
	action.emit("attack", {"src": src, "dst": dst, "damage": def_dmg, 
		"side": side, "overflow": overflow, 
		"atk_name": attacker.card.card_name, "def_name": defender.card.card_name})
	if defender.health <= 0:
		_destroy(dst)
		if overflow > 0:
			var foe:= defender.owner
			_log("溢出伤害：%d 点越过 %s 漏到玩家 HP" % [overflow, defender.card.card_name])
			action.emit("trample", {"side": foe, "amount": overflow, "src": src, "dst": dst, 
				"atk_name": attacker.card.card_name, 
				"def_name": defender.card.card_name})
			_damage_player(foe, overflow, "溢出")
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
	if state.board.has(src):
		if attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:
			attacker.ramp_atk = 0
			_log("潜影者：攻击后力量重置（当前 %d）" % attacker.effective_power())
		_attack_gain_energy(side, attacker)   # 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时 +1 费
		_tap(attacker, "行动完毕")
	_check_game_over()


func attack_hp(src: Vector2i, dst: Vector2i, side:= SIDE_SELF) -> void :
	if ReplayLog.recording and side == SIDE_SELF:
		ReplayLog.act("attack_hp", [src, dst])

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
	if side == SIDE_SELF:
		state.hp_opponent = maxi(0, state.hp_opponent - power)
		_log("%s 攻击敌方 HP（从后排 %s）：敌方 -%d，剩余 %d" % [
			attacker.card.card_name, dst, power, state.hp_opponent])
	else:
		if _absorb_by_guard(power):

			_log("森林守护盟友替我方挡下 %s 的攻击" % attacker.card.card_name)
		else:
			# 荒野形态 6022：每场第一次「普通攻击直击我方 HP」→ 减伤 + 反伤。
			# 只挂在普通攻击这条路径上：技能 / 效果 / 溢出的 HP 伤害都走
			# _damage_player → _hp_damage_taken，不会触发它。
			var self_dmg:= _wild_form_first_hit(attacker, power)
			state.hp_self = maxi(0, state.hp_self - self_dmg)
			_log("%s 攻击我方 HP：我方 -%d，剩余 %d" % [
				attacker.card.card_name, self_dmg, state.hp_self])
			if self_dmg > 0:
				_on_self_damaged()
				_on_self_hp_damaged()
	action.emit("hp", {"src": src, "dst": dst, "damage": power, "side": side,
		"atk_name": attacker.card.card_name})
	if attacker.card.id == LURKER_ID and attacker.ramp_atk > 0:
		attacker.ramp_atk = 0
		_log("潜影者：攻击 HP 后力量重置（当前 %d）" % attacker.effective_power())
	_attack_gain_energy(side, attacker)   # 地狱咏唱者 / 黑暗祭坛：直击 HP 也算一次攻击
	_tap(attacker, "攻击 HP，行动完毕")
	_check_game_over()




func ai_action_queue() -> Array[Vector2i]:
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
		if p.card.attack_range >= 2 and _clear_shot_target(cell, p) != null:
			promoted.append(cell)
	if promoted.is_empty():
		return cells
	var rest: Array[Vector2i] = []
	for cell in cells:
		if not promoted.has(cell):
			rest.append(cell)
	return promoted + rest


func run_ai_unit(cell: Vector2i) -> void :
	if over or not ai_enabled or current_side != SIDE_OPPONENT:
		return
	var p:= state.unit_at(cell)
	if p == null or p.owner != SIDE_OPPONENT or p.tapped:
		return
	_ai_act(cell, p)


func _ai_pick_card_target(targets: Array[Vector2i], p: Placement = null) -> Vector2i:
	## 通用选目标：能穿透（打死敌方后排、溢出漏到 HP）的目标最优先 —— 那相当于在打 HP。
	if p != null:
		var ov = _overflow_pick(targets, p)
		if ov != null:
			return ov
	var best: Vector2i = targets[0]
	var best_key:= [999, 0, 999]
	for t in targets:
		var q:= state.unit_at(t)
		var key:= [q.health if q.health > 0 else 99, - (q.effective_power()), t.x * 10 + t.y]
		if [key[0], key[1], key[2]] < [best_key[0], best_key[1], best_key[2]]:
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
	if _wall_depth(cell, p) <= 0:
		return null
	var blockers:= _blocking_targets(cell, p, card_targets)
	if not blockers.is_empty():
		return ["card", _ai_pick_card_target(blockers, p)]
	return null


func _pick_nearest(cell: Vector2i, targets: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = targets[0]
	for t in targets:
		if manhattan(cell, t) < manhattan(cell, best)\
		or (manhattan(cell, t) == manhattan(cell, best) and t.y < best.y):
			best = t
	return best


const AI_NO_ROUTE:= 99


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
		if attack_distance(cell, t, p.owner, c) <= c.attack_range:
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
		if manhattan(fcell, t) <= f.card.attack_range:
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
	if p.card.attack_range < 2:
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
	var atk_range:= p.card.attack_range
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
	var atk_range:= p.card.attack_range
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


func _step_score(src: Vector2i, dst: Vector2i, p: Placement) -> Array:








	var can_hit:= 0 if not hp_targets(dst, SIDE_OPPONENT, p.card).is_empty() else 1
	var wall:= _wall_depth(dst, p, [dst])
	# 目标距离 = 打到 HP 的距离 与 贴到最近敌人的距离 取小 —— 打不到 HP 就朝敌人推进破局
	var near:= mini(_hp_pos_distance(dst, p), _engage_distance(dst, p))
	# 同级距离里偏好向前（敌方 +x 方向），避免原地踏步：距离差 1 档 = 10 分，
	# 棋盘只有 6 行，前进 1 格最多 -5，永远压不过距离档，但同档内必然击败原地不动。
	var advance:= - dst.x
	return [can_hit, wall, near * 10 + advance, manhattan(src, dst), - dst.y]


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


func _nearest_foe_dist(dst: Vector2i) -> int:
	## 到最近我方单位的曼哈顿距离；场上没有我方单位时退回「到我方后排最近格」的距离。
	## 用曼哈顿（不是走位 BFS）—— 这里是**闪现**，不走路、不受阻挡影响。
	var best:= AI_NO_ROUTE
	for c: Vector2i in state.board:
		var q: Placement = state.board[c]
		if q.owner == SIDE_SELF:
			best = mini(best, manhattan(dst, c))
	if best != AI_NO_ROUTE:
		return best
	var row:= back_row(SIDE_SELF)
	for col in FieldState.BOARD_COLS:
		best = mini(best, manhattan(dst, Vector2i(row, col)))
	return best


func _assassin_cell_key(src: Vector2i, dst: Vector2i, p: Placement) -> Array:
	## 闪现候选排序键（字典序，越小越好）：
	##   ① 能打到我方单位优先（0 优于 1）；
	##   ② 能打时：目标血量越低越好（易击杀）、力量越高越好（威胁大）；
	##   ③ 打不到时：离最近我方单位越近越好（逼近施压，下回合就能咬上）；
	##   ④ 平手时**原地优先**（manhattan 0）→ 不会无意义乱跳；末位按格位定序（确定性可复现）。
	var targets:= attack_targets(dst, SIDE_OPPONENT, p.card)
	var can_hit:= 1 if targets.is_empty() else 0
	var t_hp:= 999
	var t_pow:= 0
	if not targets.is_empty():
		var q:= state.unit_at(_ai_pick_card_target(targets, p))
		if q != null:
			t_hp = q.health if q.health > 0 else 999
			t_pow = q.effective_power()
	return [can_hit, t_hp, - t_pow, _nearest_foe_dist(dst) * 10,
			manhattan(src, dst), dst.x, dst.y]


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
	var dst = _assassin_step(cell, p)
	if dst != null:
		move(cell, dst, SIDE_OPPONENT, true)
		if over:
			return
		var moved:= state.unit_at(dst)
		if moved == null:
			return
		cell = dst
		p = moved
	if _ai_attack_if_any(cell, p):
		return
	_tap(p, "AI：暗杀者游走（本轮无可攻击目标）")


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
	var summoned:= state.place(copy, spot, side)
	_log("%s%s：召唤了一只鸭子暗杀者（%s）" % [
			src, "（开局）" if initial else "（每 %d 回合）" % interval, spot])
	action.emit("place", {"cell": spot, "card": copy, "side": side})
	_on_ally_entered(summoned, side)
	_refresh_dark_lord(side)
