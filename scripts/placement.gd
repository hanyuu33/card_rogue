class_name Placement
extends RefCounted

## 重甲战车（8058）：状态条要按层数显示「受伤 -N」—— 与 `GameEngine.HEAVY_TANK_ID` 同值。
## 写成本地常量而不是引 GameEngine，是因为两边互相 import 会形成循环依赖。
const HEAVY_TANK_CARD_ID := 8058
## 战场某格上的一张卡（对应 Python 版 field.Placement）。

var card: CardData
var tapped: bool = false      # True = 横置（本回合已无行动权）
var moved: bool = false       # 本回合已移动（移动后未攻击仍保留攻击权）
## 陷阱加强（R238）：**本回合是否真的挪过格子**（`move()` 成功才置 true，回合开始复位）。
## 与 `moved` 分开记 —— `moved` 的语义是「移动权已用掉」（禁足 / 冰冻会被置 true，见
## `FieldState.reset_units`），而这里要的是**物理上原地不动**：禁足的敌人一动不动，
## 照样该踩响脚下的陷阱。两者混用会漏掉这一类。
var did_move: bool = false
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
# 「改造生命层」（堡垒 8034，R274）：**已按层数烘进 `health` 的额外生命**。
# 用「目标值 vs 已结算值」的**差量法**重算（`GameEngine._refresh_stack_hp`）——
# 层数不管在哪里获得（手牌 / 牌库 / 场上），都汇到 `upgrade_stacks`，
# 这里只记「已经结算过多少」，保证重算幂等。
var stack_hp_applied: int = 0
var upgrade_range: int = 0   # 改造加攻程累计（R101，榴弹击手）：只在场上有效，离场由 _card_leaving_field 还原
## ⚠️ R275：重甲战车 8058 已移除「改造移速」（改成「每层改造受到的伤害 -1」），
## `upgrade_speed` 与 trait「改造移速」目前**没有卡在用**，机制保留给未来的卡。
var upgrade_speed: int = 0   # 改造加移速累计（原 R101 重甲战车）：只在场上有效，离场还原
## 「加厚装甲」（8044，R275）：**受到的伤害 -1 / 次**（每次施加累计 1 点）。
## 只记 Placement —— 与改造层数不同，它**不随身**（回手再上场就没了，卡面写明「只在场上有效」）。
## 结算在 `GameEngine._unit_damage_taken()`（单位受击减伤唯一口），下限同犀牛：至少仍受 1 点。
var dmg_reduce: int = 0
# 「侦察塔」（8032，trait「改造层数」）：**光环易伤**（R120 用户口径）——
# 它**攻击范围内**的敌人，受到**任何来源**的伤害都 +1 / 层改造。
# 判据 = trait「改造层数」+ `upgrade_stacks`，结算在
# `GameEngine._scout_aura_bonus()`（挂在 `_hit_unit` 开头 = 所有伤害路径的唯一口）。
# ⚠️ **不进 `effective_power()`**：塔自身 0 攻就是 0 攻、改造也不给它加攻
# （见 `GameEngine._upgrade_atk_gain`），它的改造收益全在**敌人身上**。
# 别的卡（树人 / 木栅栏…）改造后 `upgrade_stacks` 也会 +1，但没有这个 trait 就没有光环。
# 「堡垒」（8034，trait「改造生命层」）：**每层 +3 生命**（R87）——
# 加的血并进 `upgrade_hp`，于是离场还原走的是同一条路。
var first_hit_shield: bool = false   # 能量屏障（8033，R87）：**本场战斗中第一次受伤免掉**
## 「护甲」（R162，阿斯克勒庇厄斯 9141）：临时护盾，受到伤害时优先代替生命扣除；只记 Placement。
var armor: int = 0
var regen: int = 0           # 自我修复（8035，R87）：每回合结束回复的生命（离场还原）
## 「无限装甲」（8038，R89，trait「改造供能」）：**本回合是否已经供过能**。
## 记的是 `GameEngine.turn_total`（当初触发时的值），-1 = 还没触发过。
## ⚠️ 记在**这个单位实例**上而不是全局 → 换一张装甲上场就有一份额度，
## 且这张被打死离场后额度随之消失（新的那张重新算，符合「这张卡每回合一次」的字面）。
var upgrade_feed_turn: int = -1
var sleep_left: int = 0       # 沉睡（恶魔鸭 9116）：还要睡几点（>0 = 本回合不行动）；自己的回合结束 -1，受伤也 -1（R122）
## 铸造倒计时（量产型赫卡同克瑞斯 9133，R149）：还剩几个**我方回合**就会「破坏自身、
## 在原地立起一座钢铁要塞」。0 = 不带这个倒计时。
## ⚠️ 递减口只有一处（`GameEngine._fuse_tick`，我方回合结束），且**不是亡语** ——
##    被提前打掉时 `fuse_left` 随单位一起消失，什么都不会留下。
var fuse_left: int = 0
## 「锻造」（赫菲斯托斯 9135，R150，第二层 Boss）：
##   * `forge_period` —— 连续**几个我方回合**没能亲手击杀就会成长（上场时由
##     `place()` 按 trait「锻造」**唯一初始化**，0 = 不带这个机制）；
##   * `forge_idle` —— 已经空转了几个我方回合（亲手击杀即清零）；
##   * `forge_range` —— 已累计的**攻击距离**加成（每满 period 一次 +1）。
## ⚠️ 同 R111 暗影领主 / R149 铸造：只记在 Placement、**绝不烤进 CardData** ——
##    关卡敌方单位用的是卡库共享实例（battle_scene 直接 `repo.get_card`），
##    直接改 `card.attack_range` 会把加成写进卡库、跨局泄漏。
##    力量那一半走 `atk_buff`（与鸭子骑士同口径：永久累计、无上限），所以这里只存射程。
var forge_period: int = 0
var forge_idle: int = 0
var forge_range: int = 0
## 「暗影领主」（鸭之暗面 9124，R111）：每个**存活的鸭子暗杀者**给它 +3 力 +1 速。
## ⚠️ 只记在 Placement 上、**绝不烤进 CardData** —— 敌方关卡单位用的是卡库共享实例，
## 直接改 card 会把加成写进卡库、跨局泄漏（R111 特意不走 R101 那条 `p.card.move_speed +=` 的路）。
## 因此无需 `_card_leaving_field` 还原：单位一离场，这两个字段随之消失。
var dark_lord_atk: int = 0     # +3 × 存活暗杀者数（进 effective_power）
## R271 谟涅摩叙涅 8072：场上**每张**本卡的改造层数之和 → 敌方单位力量 -N。
## 与 dark_lord_atk 同范式：只写 Placement、不碰 card，由 `_refresh_mnemosyne()` 重算。
var mnemo_down: int = 0
var dark_lord_speed: int = 0   # +1 × 存活暗杀者数（进 effective_speed）
## 「赫卡同克瑞斯」（9136，R152）：场上**只有它一个**己方单位时的孤军 buff —— 力量 +2、
## 受到的攻击伤害减半（减伤那一半在引擎 `_unit_damage_taken` 实时判定，不进本类）。
## 力量由 `GameEngine._refresh_hecaton()` 在「开局/召唤/击破/回合开始」五处实时重算写值，
## 与暗影领主同范式（只记 Placement、**绝不烤进 CardData**，敌方单位用的是卡库共享实例）。
var hecaton_atk: int = 0       # 孤军成立时 = HECATON_ATK_BUFF(2)，否则 0（进 effective_power）
	## 「行动力成长」（R161，赫尔墨斯 9140）：每过 ACTION_GROWTH_PERIOD 个回合，
	## 该单位本回合行动次数 +1（只记 Placement，不写回 CardData）。
var action_growth_extra: int = 0   # 已累计的额外行动轮数
var action_growth_turns: int = 0   # 距离下次成长还剩几个回合
## 「百眼动员」（量产型阿尔戈斯 9142，R174）：被它召唤出来的量产型俄倪厄移速 +1。
## ⚠️ 同暗影领主：只记在 Placement、**绝不烤进 CardData** —— 敌方关卡单位用的是卡库
## 共享实例，直接改 card.move_speed 会把加成写进卡库、跨局泄漏。单位一离场字段随之消失，
## 因此无需 `_card_leaving_field` 还原。
var summon_haste: int = 0          # 阿尔戈斯召唤加成（进 effective_speed）
## 「惧光」（夜鸭 9027，R270 起，R324 改显示名）：**奇数回合**移速 / 攻击距离各 -1
## 且力量**临时减半**（0 = 不生效，1 = 生效）。
## 与暗影领主同范式：只记 Placement、**绝不烤进 CardData**（敌方关卡单位是卡库共享实例），
## 由 `GameEngine._refresh_night_owl()` 在回合开始时按 `turn_number` 的奇偶重算。
var night_owl_weak: int = 0
## 「生命循环」（9150，R227，森林精魄稀有技能）：
##   * `life_cycle` —— 这个单位被本卡点过（死亡时要「加一张随机盟友卡到手卡」）；
##   * `life_cycle_added` —— 本卡实际**新加**的字段（次元 / 死亡）。离场（重启 / 回收 /
##     返修）时由 `_card_leaving_field` **逐个摘掉**，于是回手的那张卡还是原样 ——
##     否则下次上场会带着一个不会触发的「死亡」标记（效果未生效却写在卡面上）。
## ⚠️ 不用 `has_affix("死亡")` 判效果：「死亡」字段是通用标记，幼龙 / 腐化尸鬼 / 捕兽大师
##    等卡也带它，各有各的亡语（按卡 id 结算）—— 认字段会串戏。
var life_cycle: bool = false
var life_cycle_added: Array[String] = []
## 「辅助刃」（9164，R291，机械之心普通技能）：
##   * `blade_gift` —— 这个单位被辅助刃点过（被破坏时要「把一张辅助刃加入手卡」）；
##   * `blade_added` —— 本卡实际**新加**的字段（「死亡」）。离场（重启 / 回收 / 返修 /
##     被击破进弃牌区）时由 `_card_leaving_field` **逐个摘掉** —— 与生命循环同口径，
##     否则那张卡再上场会带着一个不会触发的「死亡」标记。
## ⚠️ 判据只认这个标记，**不认** `has_affix("死亡")` —— 「死亡」是通用字段，
##    幼龙 / 腐化尸鬼 / 捕兽大师等各有各的亡语（按卡 id 结算），认字段会串戏。
var blade_gift: bool = false
var blade_added: Array[String] = []
## 「隐藏能源」（8078，R331，机械之心 3 费稀有效果）：
##   * `hidden_energy` —— 这个单位被本卡挂过「死亡」（被破坏时要「对距离 1 的随机一个敌人 8 伤」）；
##   * `hidden_energy_added` —— 本卡实际**新加**的字段（「死亡」）。离场（重启 / 回收 / 返修 /
##     被击破进弃牌区）时由 `_card_leaving_field` **逐个摘掉** —— 与生命循环 / 辅助刃同口径，
##     否则那张卡再上场会带着一个不会触发的「死亡」标记。
## ⚠️ 判据只认这两个标记，**不认** `has_affix("死亡")` —— 「死亡」是通用字段，认字段会串戏。
var hidden_energy: bool = false
var hidden_energy_added: Array[String] = []

func effective_power() -> int:
	## 实际攻击力：卡面力量 + 生效中的增益 + 关卡成长修正 - 生效中的削弱，最低 0。
	##
	## ⚠️ R120：这里**不再**加「改造层数」。侦察塔（8032，trait「改造层数」）的改造收益
	## 从「加自己的攻击力」纠正为**光环易伤** —— 「攻击范围内的敌人受到的伤害 +1 / 层」，
	## 由 `GameEngine._scout_aura_bonus()` 加在**敌人身上**（用户原话：是敌人**受到**的伤害
	## +1，不是这张卡攻击时 +1）。于是塔自身 0 攻就是 0 攻，定位 = 标记一片区域的增伤辅助。
	var debuff := atk_debuff if debuff_stage == 1 else 0
	var total := maxi(0, card.power + atk_buff + atk_buff_turn + atk_growth + ramp_atk
			+ end_atk + upgrade_atk + dark_lord_atk + hecaton_atk
			- debuff - mnemo_down)
	# R324「惧光」：夜鸭奇数回合**力量临时减半**，只作用在这个出口 ——
	# 上面每一项（atk_buff / atk_growth / ramp_atk / upgrade_atk / dark_lord_atk …）
	# 都是「永久」或「本回合」的真实加成，**一个字段都不改**，所以：
	#   · 偶数回合自动回到原值，夜行（永久 +1/回合）累计的攻不会被吃掉；
	#   · 卡面 / 徽标 / 攻击结算全部读这个口，不会出现「显示减半、打出来是原值」。
	# 去尾口径与 `_spell_dmg_pct` 一致（整数除法向零截断，正数即 floor）：5 → 2。
	if night_owl_weak > 0:
		total = total / 2
	return total


func effective_speed() -> int:
	## 实际移动速度（R111）：卡面移速 + 场上加成（鸭之暗面的暗影领主）- 惧光（夜鸭奇数回合）。最低 0。
	## 与 effective_power 对称：**不写回 card**，所以 `_move_bfs` / AI 都要读这个口。
	if card == null:
		return 0
	return maxi(0, card.move_speed + dark_lord_speed + summon_haste - night_owl_weak)


func effective_range() -> int:
	## 实际攻击距离（R150）：卡面射程 + **只在场上有效**的加成（赫菲斯托斯的锻造成长）
	## - 惧光（夜鸭 9027 奇数回合 -1）。
	## R279：「改造攻程」（榴弹击手）的 +N **已经烤在这张卡的副本上**（`card.attack_range`），
	## 所以这里不再加 `upgrade_range`（加了会双计）。`upgrade_range` 只负责两件事：
	## ① 徽标显示 / ② 离场时 `_card_leaving_field` 按它减回去。
	## 与 `effective_power` / `effective_speed` 对称：**不写回 card**。
	## ⚠️ 引擎里凡是判断「够不够得着」的地方都要走这个口（或 `GameEngine.eff_range`），
	##    别再直接读 `card.attack_range` —— 那个不含场上加成。
	if card == null:
		return 0
	return maxi(0, card.attack_range + forge_range - night_owl_weak)


## 【R106】这张卡**此刻已获得**的增益 / 减益，逐条列出（一条一个 Dictionary）。
##
## 键：`label`（正文）、`col`（颜色）、`kind`（"buff" / "debuff" / "info"）。
## 左侧信息栏按行显示、战场卡面顶部徽标另取 `status_badges()` —— 两处读的是同一份
## 字段，保证「栏里写了什么，卡面就有什么」，不会两边各算各的。
##
## 只列**此刻真的成立**的项：`atk_debuff` 未到生效回合（debuff_stage==0）不算，
## 满血（regen 等）该显示的还是显示 —— 它是「拥有」这个状态，不是「正在生效的数值」。
func cannot_act_next_turn() -> bool:
	## R313（快速符文 6043）：「下回合不能行动」状态的**唯一判据口**。
	## 目前两只：
	##   * 冰封 `frozen`（寒冰箭 / 冰霜新星）—— 下回合开始时不重置，横置着动不了；
	##   * 沉睡 `sleep_left > 0`（恶魔鸭 9116）—— 还要睡几点，期间不行动。
	## ⚠️ **禁足 `rooted` 不算**：它只拦移动，照样能攻击 —— 卡面口径是「不能行动」。
	## 引擎（伤害加成加倍）与界面（提示文案）共用这一处，别再各写各的。
	return frozen or sleep_left > 0


func status_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var COL_B := Color("2f8f4f")   # 增益：绿
	var COL_D := Color("c0392b")   # 减益：红
	var COL_I := Color("6a5a8a")   # 中性提示：紫灰
	var debuff := atk_debuff if debuff_stage == 1 else 0

	# ---------------- 增益 ----------------
	if upgrade_stacks > 0:
		var extra := ""
		if upgrade_atk != 0:
			extra += " 力 +%d" % upgrade_atk
		if upgrade_hp != 0:
			extra += " 生 +%d" % upgrade_hp
		if upgrade_range != 0:
			extra += " 程 +%d" % upgrade_range
		if upgrade_speed != 0:
			extra += " 速 +%d" % upgrade_speed
		out.append({"label": "改造 ×%d%s" % [upgrade_stacks, extra],
				"col": COL_B, "kind": "buff"})
	# R120：侦察塔的光环要说清楚「加成去哪里了」——它自己不加攻，是**范围内的敌人**受伤 +N。
	# 只写「改造 ×N」会让玩家以为塔的攻击力涨了（那正是改掉的那个误解）。
	if upgrade_stacks > 0 and card != null and card.traits.has("改造层数"):
		out.append({"label": "光环：范围内敌人受伤 +%d" % upgrade_stacks,
				"col": COL_B, "kind": "buff"})
	if dark_lord_atk > 0 or dark_lord_speed > 0:
		out.append({"label": "暗影领主：力 +%d 速 +%d" % [dark_lord_atk, dark_lord_speed],
				"col": COL_B, "kind": "buff"})
	if hecaton_atk > 0:
		out.append({"label": "孤军：力 +%d，攻击伤害减半（场上无其他己方单位）" % hecaton_atk,
				"col": COL_B, "kind": "buff"})
	if mnemo_down > 0:
		out.append({"label": "谟涅摩叙涅：力 -%d" % mnemo_down,
				"col": COL_D, "kind": "debuff"})
	if atk_buff > 0:
		out.append({"label": "力量 +%d（成长光环）" % atk_buff, "col": COL_B, "kind": "buff"})
	if atk_buff_turn > 0:
		out.append({"label": "本回合力量 +%d" % atk_buff_turn, "col": COL_B, "kind": "buff"})
	if atk_growth != 0:
		out.append({"label": "关卡成长 %+d" % atk_growth,
				"col": COL_B if atk_growth > 0 else COL_D,
				"kind": "buff" if atk_growth > 0 else "debuff"})
	if ramp_atk > 0:
		out.append({"label": "潜影累计 +%d" % ramp_atk, "col": COL_B, "kind": "buff"})
	if end_atk > 0:
		out.append({"label": "回合结束成长 +%d" % end_atk, "col": COL_B, "kind": "buff"})
	if summon_haste > 0:
		out.append({"label": "动员：速 +%d（阿尔戈斯召唤）" % summon_haste,
				"col": COL_B, "kind": "buff"})
	if regen > 0:
		out.append({"label": "自我修复：每回合回复 %d" % regen, "col": COL_B, "kind": "buff"})
	if first_hit_shield:
		out.append({"label": "护盾：免疫下一次伤害", "col": COL_B, "kind": "buff"})
	if armor > 0:
		out.append({"label": "护甲：%d" % armor, "col": Color("2a9d8f"), "kind": "buff"})
	# R275：重甲战车（8058）每层改造 -1 受伤；加厚装甲（8044）每次施加累计 -1 受伤。
	if card != null and card.id == HEAVY_TANK_CARD_ID and upgrade_stacks > 0:
		out.append({"label": "重甲战车：受伤 -%d" % upgrade_stacks,
				"col": COL_B, "kind": "buff"})
	if dmg_reduce > 0:
		out.append({"label": "加厚装甲：受伤 -%d" % dmg_reduce, "col": COL_B, "kind": "buff"})
	if guarding:
		out.append({"label": "守护：代我方承受伤害", "col": COL_B, "kind": "buff"})
	if acts_left > 1:
		out.append({"label": "额外行动 ×%d" % acts_left, "col": COL_B, "kind": "buff"})
	if fence_bonus_hp > 0:
		out.append({"label": "栅栏加固：额外生命 +%d" % fence_bonus_hp, "col": COL_B, "kind": "buff"})
	if upgrade_feed_turn >= 0:
		out.append({"label": "本回合已供过能", "col": COL_I, "kind": "info"})
	if fuse_left > 0:
		out.append({"label": "铸造：还剩 %d 个我方回合 → 原地变钢铁要塞" % fuse_left,
				"col": COL_I, "kind": "info"})
	if forge_period > 0:
		out.append({"label": "锻造：空转 %d/%d 个我方回合 → 已 +%d 力、+%d 程（亲手击杀则清零）"
				% [forge_idle, forge_period, forge_range, forge_range],
				"col": COL_I, "kind": "info"})

	# ---------------- 减益 ----------------
	if debuff > 0:
		out.append({"label": "力量 -%d（本回合）" % debuff, "col": COL_D, "kind": "debuff"})
	if frozen:
		out.append({"label": "冰封：下回合不能行动", "col": COL_D, "kind": "debuff"})
	if sleep_left > 0:
		out.append({"label": "沉睡：还剩 %d（回合/受伤各 -1）" % sleep_left,
				"col": COL_D, "kind": "debuff"})
	if rooted > 0:
		# R143：区分「已挂待生效」（rooted=1，本次只是挂上，**下个**自己回合才拦移动）
		# 与「生效中」（rooted=2）—— 两种都写「本回合不能移动」会让玩家以为现在就走不动。
		out.append({"label": "禁足：下回合不能移动" if rooted == 1 else "禁足：本回合不能移动",
				"col": COL_D, "kind": "debuff"})
	if poison_left > 0:
		out.append({"label": "中毒：剩 %d 跳，每跳 %d 伤" % [poison_left, poison_dmg],
				"col": COL_D, "kind": "debuff"})
	if night_owl_weak > 0:
		# R324：显示名统一为「惧光」（旧名「夜衰 / 畏光」），并把力量减半写进同一行。
		out.append({"label": "惧光（奇数回合）：移速 -%d、攻程 -%d、力量减半"
				% [night_owl_weak, night_owl_weak],
				"col": COL_D, "kind": "debuff"})
	return out


## 【R106】战场卡面顶部**徽标**用的紧凑摘要（信息栏里是逐条列出的，这里只挑最要紧的）。
## 顺序即重要性：力量净变化 → 改造层数 → 护盾 → 中毒 → 禁足 → 守护。
## 调用方负责截断（徽标多了会盖住上一行的卡）。
func status_badges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var net: int = effective_power() - card.power if card != null else 0
	if net != 0:
		out.append({"text": "力 %+d" % net,
				"col": Color("2f8f4f") if net > 0 else Color("c0392b")})
	if upgrade_stacks > 0:
		out.append({"text": "改造 ×%d" % upgrade_stacks, "col": Color("1d6fb8")})
	if first_hit_shield:
		out.append({"text": "护盾", "col": Color("2f8f4f")})
	if armor > 0:
		out.append({"text": "护甲 %d" % armor, "col": Color("2a9d8f")})
	if poison_left > 0:
		out.append({"text": "中毒 %d" % poison_left, "col": Color("5a9e2f")})
	if rooted > 0:
		out.append({"text": "禁足", "col": Color("8a6d1f")})
	if guarding:
		out.append({"text": "守护", "col": Color("2f8f4f")})
	if summon_haste > 0:
		out.append({"text": "速 +%d" % summon_haste, "col": Color("2f8f4f")})
	if forge_period > 0:
		out.append({"text": "锻 %d/%d" % [forge_idle, forge_period], "col": Color("ff7043")})
	if night_owl_weak > 0:
		out.append({"text": "惧光", "col": Color("8a6d1f")})
	return out
