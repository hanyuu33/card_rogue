class_name Placement
extends RefCounted
## 战场某格上的一张卡（对应 Python 版 field.Placement）。

var card: CardData
var tapped: bool = false      # True = 横置（本回合已无行动权）
var moved: bool = false       # 本回合已移动（移动后未攻击仍保留攻击权）
var health: int = 0           # 当前生命
var owner: String = "self"    # "self" / "opponent"（按卡算，不按行算）
# ---- 回合级状态效果（削弱/寒冰箭）----
var atk_debuff: int = 0       # 攻击力减值（正数 = 减多少）
var debuff_stage: int = 0     # 0 = 未生效（下回合才生效） 1 = 生效中（回合结束清除）
var frozen: bool = false      # 寒冰箭：下回合开始时不重置（横置的不再恢复、不能行动）
var atk_buff: int = 0         # 攻击力增益（鸭子之力等成长光环累计值，有上限）
var atk_growth: int = 0       # 关卡成长曲线修正（二层「低开高走」：可为负，随回合回升）
var acts_left: int = 1        # 本回合剩余行动轮数（鸭子队长 = 2：第一轮结束后立即新一轮）
var battlecry_done: bool = false  # 战吼：是否已在「首个回合开始」结算过（每个单位只触发一次）
var ability_used: bool = false    # 主动发动（熊 8004「回春」）：在场只能发动一次（离场再上场算新单位）
var guarding: bool = false    # 森林守护：我方 HP 受伤时由它代为承受（同一单位不可重复获得）
var last_hit_by: Vector2i = Vector2i(-1, -1)  # 击杀记功：最后一下是谁打的（鸭子骑士靠它 +2 攻击力）
var atk_buff_turn: int = 0    # 本回合攻击力加成（撕咬 9042：回合结束时由 end_turn 清除）
var ramp_atk: int = 0         # 潜影者 8009：每用一张牌 +1 的力量累计值（攻击或离场后清零）
var rooted: int = 0           # 禁足（冰霜陷阱 8012，R51）：0 无 / 1 已挂待生效 / 2 生效中（本回合不能移动，仍可攻击）
var poison_left: int = 0      # 中毒（剧毒陷阱 8014，R51）：剩余结算次数（所属方回合开始各结算一次）
var poison_dmg: int = 0       # 中毒每跳伤害（挂毒瞬间锁定：基础 6 + 陷阱精通 2×陷阱费）
var trap_trig_turn: int = -1  # 暗影狩猎 9107（R52）：该单位最近一次「触发工事」的全局半回合号（-1 = 从未触发）
var end_atk: int = 0          # 回合结束成长（地狱猫 8019 / 鲜血堡垒 8020，R55）：按剩余费用永久累加的力量，无上限、不随回合结束清除
var fence_bonus_hp: int = 0   # 栅栏修复术 6021（R67）叠加累计的**额外生命**：**只在场上有效**，离场时由 _card_leaving_field 还原成原卡
var fence_bonus_traits: Array[String] = []   # 同上，叠加时**新加进**的特性名（卡面原本没有的那些）：离场时从交出的卡上去掉
# ---- 改造（升级 8027，R82）：机械之心的「+2 攻 / +8 血」----
# 同样是**只在场上有效**的加固：离场时由 _card_leaving_field 还原（不烤进 CardData，
# 否则被击破后那张加过血的卡会永久留在弃牌区、再抽到仍是强化版）。
# ⚠️ 加攻**不能**复用 atk_buff —— 那个被 GROW_CAP 封顶 5，且语义是「成长光环」；
# 改造要能无限叠（+2/+2/+2…），所以单开这个字段并直接进 effective_power。
var upgrade_atk: int = 0      # 改造累计加攻（无上限）
var upgrade_hp: int = 0       # 改造累计加血（含「素体被改造时额外 +1」那部分）
var upgrade_stacks: int = 0   # **改造层数**（R86）：被改造过几次
var upgrade_range: int = 0   # 改造加攻程累计（R101，榴弹击手）：只在场上有效，离场由 _card_leaving_field 还原
var upgrade_speed: int = 0   # 改造加移速累计（R101，重甲战车）：只在场上有效，离场由 _card_leaving_field 还原
# 「侦察塔」（8032，trait「改造层数」）：攻击伤害 **+1 / 层**。
# ⚠️ 只对**带该 trait** 的卡生效 —— 别的卡（树人 / 木栅栏…）改造后 `upgrade_stacks`
# 也会 +1，但它们**不该**因此加攻（否则 0 攻工事改造几次就能自己打人）。
# 判据放在 `effective_power()` 里读 `card.traits`，与鸭子之眼那类「按卡面加成」同一套路。
# 「堡垒」（8034，trait「改造生命层」）：**每层 +3 生命**（R87）——
# 加的血并进 `upgrade_hp`，于是离场还原走的是同一条路。
var first_hit_shield: bool = false   # 能量屏障（8033，R87）：**本场战斗中第一次受伤免掉**
var regen: int = 0           # 自我修复（8035，R87）：每回合结束回复的生命（离场还原）
## 「无限装甲」（8038，R89，trait「改造供能」）：**本回合是否已经供过能**。
## 记的是 `GameEngine.turn_total`（当初触发时的值），-1 = 还没触发过。
## ⚠️ 记在**这个单位实例**上而不是全局 → 换一张装甲上场就有一份额度，
## 且这张被打死离场后额度随之消失（新的那张重新算，符合「这张卡每回合一次」的字面）。
var upgrade_feed_turn: int = -1
var sleep_left: int = 0       # 沉睡（恶魔鸭 9116，R63）：还要睡几个己方回合（>0 = 本回合不行动）；受伤时 -1，提前醒来


func effective_power() -> int:
	## 实际攻击力：卡面力量 + 生效中的增益 + 关卡成长修正 - 生效中的削弱，最低 0。
	var debuff := atk_debuff if debuff_stage == 1 else 0
	var stack_bonus := upgrade_stacks if card != null \
			and card.traits.has("改造层数") else 0
	return maxi(0, card.power + atk_buff + atk_buff_turn + atk_growth + ramp_atk
			+ end_atk + upgrade_atk + stack_bonus - debuff)
