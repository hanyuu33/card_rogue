extends Control
## 事件界面（肉鸽版）—— 由地图节点类型 / 事件子类型决定：
##   * rest  休息处：恢复 25% 最大生命（向上取整，不超过上限）；
##            另有「烤肉」选项：获得事件道具「烤肉」（进入 Boss 战时自动消耗
##            并回复 25% 最大生命）。持有烤肉时不能再选，消耗后可再次烤制。
##   * event + treasure 宝箱：支付 5 生命开箱 —— **一半概率**是一组卡牌奖励（选 1 张入卡组）、
##     另一半是一件道具（R142；箱子里装什么在地图生成时就摇定了）；也可以跳过不付生命；
##   * event + whisper  鸭鸭低语：获得事件道具「鸭之低语」，或放弃；
##   * event + struggle 挣扎：失去 21 点生命，将一张「金属龙」加入卡组，或离开；
##   * event + gaze     鸭之凝视：获得事件道具「一袋米抗几楼」，或放弃；
##   * event + pear     鸭梨山大（第二层专属）：获得事件道具「鸭梨」，或放弃；
##   * event + bluefish 蓝色大肥鱼（第二层专属）：把一张「鲸鱼之怒」加入卡组，或放弃；
##   * event + delivery 运送委托（R200，第一层专属）：平铺挑 1~6 张「货物」加入卡组，或离开；
##   * event + delivery_done 委托完成（R200）：持有货物时**第二层第一个事件房**替换而来，
##                     卡组每保有 1 张货物 → 抽奖一次（卡牌奖励 / 80 金币 / 随机道具 / 巧克力 10%）；
##   * event + gaze     鸭之凝视（**第二层**）：获得事件道具「一袋米抗几楼」，或放弃；
##   * event + arcane   奥秘之泉（第一层专属）：获得道具「奥秘护符」（每回合第一张效果牌费用 -1），
##                      或「喝下泉水」从随机 3 张效果 / 技能牌中选 1 张加入卡组（也可什么都不拿）；
##                      ⚠️ R147：一次访问只领一份 —— 取走护符后就不能再喝泉水，反之亦然。
##   * event + oblivion 遗忘之泉（**全层通用**）：从卡组中删一张卡，或直接离开；
##   * chest  宝箱层（第六层）：开启后获得 1 个随机奖励道具（不与已拥有的重复）。
## 生命保存在 RunState（跨战斗保留的最大/当前双值）。
##
## R147 通用规则：**一次访问只能领走一份奖励** —— 任一奖励到手后，本事件里其它奖励
##   选项立刻锁死（天生带两个奖励选项的只有「奥秘之泉」；休息处的「休息 / 烤肉」同理）。
##   落地点是 `_claim_reward(keep)`：每个发放奖励的分支都要调一次。
##
## 插图与背景走 assets/ui/ 的可替换图片（详见 assets/ui/图片命名说明.txt）：
##   event_<事件>.png 插图（标题下方） / bg_<事件>.png 整屏背景；
##   事件 = rest / treasure / whisper / struggle / gaze / pear / bluefish / relic_chest。
## 缺图时回退内置绘制（所有事件共用的篝火动画 / 深灰底色）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const WHISPER_ID := 6010
const RICE_ID := 6012             # 一袋米抗几楼（鸭之凝视事件道具）
const PEAR_ID := 6019             # 鸭梨（鸭梨山大事件道具）
const HERO_CARD_ID := 9023        # 英雄（绝赞五换一的奖励卡）
const HERO_TRADE_NEED := 5        # 绝赞五换一：要交出 5 张**不同名**的卡
const STRUGGLE_CARD_ID := 9018    # 金属龙（事件卡牌，不可奖励获取）
const STRUGGLE_LIFE := 21         # 挣扎代价：失去的生命
const WHALE_CARD_ID := 9050       # 鲸鱼之怒（蓝色大肥鱼事件的奖励卡，不可奖励获取）
const ARCANE_CHARM_ID := 6020     # 奥秘护符（奥秘之泉事件给予；奖励池也能正常获得）
const CARGO_CARD_ID := 8065       # 货物（R200 运送委托；1 费工事 0/6/0/0，被破坏时从卡组删除）
const DELIVERY_MIN := 1           # 运送委托：最少接几张
const DELIVERY_MAX := 6           # 运送委托：最多接几张

const WHISPER_DESC := """深处的鸭鸣在你耳畔回荡，绕梁不散……
获得「鸭之低语」：你将不再能控制自己接下来的前进方向
（每一步都由系统随机决定）；
但每个回合开始时，你会随机获得一种强化——
本回合费用 +1 / 本回合造成的伤害 +1 / 本回合多抽 1 张卡。"""

const WHISPER_TAKEN_DESC := """低语已经住进了你的脑海。
从今往后，前路不再由你选择——命运会替你走完剩下的路。"""

const GAZE_DESC := """一只巨大的鸭眼自虚空中睁开，死死盯着你。
它不说话，只是看着——看得你后背发凉，手里莫名多了一袋米。
获得「一袋米抗几楼」：每回合第一次我方 HP 受到伤害后，抽 1 张卡，
且本回合内你的技能（法术）造成的伤害 +1。
也可以别过头去，假装没看见。"""

const GAZE_TAKEN_DESC := """那只眼睛还在看着你。
米袋沉甸甸地压在肩头——被注视的感觉，从此挥之不去。"""

const PEAR_DESC := """不知从哪儿滚来一堆鸭梨，一颗一颗，把你压得喘不过气。
压力，也是一种力量——只要你还扛得住。
获得「鸭梨」：此后每次你的 HP 受到伤害，最大生命 +1（只提高上限，不回复生命）。
也可以把梨推开，假装自己毫无压力。"""

const PEAR_TAKEN_DESC := """肩上那座鸭梨山，你已经背起来了。
往后每一次受伤，都会让你更「强大」一点——
只是那点强大，补不回已经失去的血。"""

const BLUEFISH_DESC := """一条通体蓝色的大肥鱼搁浅在岸边，肚皮一起一伏，像还在做梦。
它翻了个身，从嘴里吐出一枚亮晶晶的东西——
「鲸鱼之怒」：1 费技能，造成 11 点伤害，
随后可从弃牌堆选 2 张卡回到手牌；用掉之后本场战斗里不再出现。
要不要把它捡起来？"""

const BLUEFISH_TAKEN_DESC := """大肥鱼心满意足地打了个嗝，翻着肚皮漂远了。
「鲸鱼之怒」已经躺进你的卡组——什么时候用它，就看你了。"""

const CHEST_LAYER_DESC := """这一层堆满了落满灰尘的宝箱。
每个宝箱里都躺着一件道具——开启它，带走其中一件。"""

const HERO_DESC := """一块巨大的告示牌立在路中央，上面龙飞凤舞地写着五个大字：绝赞五换一！
交出卡组里 5 张「不同名」的卡（随机挑 5 种，每种各 1 张），
就能换回一位「英雄」——5 费 5 力 25 血，只是它上场时，
你必须额外丢弃 4 张手牌作为代价。
卡组里凑不出 5 种不同的卡时，这笔买卖做不成，只能转身离开。"""

const HERO_TAKEN_DESC := """告示牌上的字迹已经淡去。
被换走的 5 张卡再也要不回来了——但那位英雄，已经站在你的队伍里。"""

const ARCANE_DESC := """泉眼深处浮着一枚古老的护符，水面映出的星空明明不属于这片天空。
选择1 · 获取护符：获得道具「奥秘护符」——
每回合你的第一张效果牌费用 -1（已拥有时不再重复给予）。
选择2 · 喝下泉水：从随机 3 张效果 / 技能牌中选一张加入卡组
（稀有度概率与普通卡牌奖励一致，也可以一张都不选，转身离开）。"""

const ARCANE_CHARM_TAKEN_DESC := """护符已经贴着心口，泉水的星光在指尖回落。
从今往后，每个回合的第一张效果牌都会轻上一分。"""

const OBLIVION_DESC := """泉水不映星光，也不照人脸——你把脸凑近，连卡组的模样都在水里淡去。
选择遗忘：从卡组中挑一张卡，永久删除它（不打算删的话也可以就此离开）。
（这一眼看过之后，泉水便再也不会为你重绘任何东西。）"""

const OBLIVION_DONE_DESC := """什么意思都没有的那张脸，又浮了上来——
卡组里少了些什么，可你再也想不起那是什么了。"""

const SMITH_DESC := """铁匠铺里叮叮当当，有人正把一张牌按进炉子——
「这张，我给你改成一道墙。」
选择锻造：从卡组中挑一张卡，把它变成一张「铁栅栏」（费用按 2 费计）。
（不想改的话，也可以转身离开。）"""

const SMITH_DONE_DESC := """炉火熄了，锻件出炉。
你手里那张牌，已经变成了一道铁栅栏。"""

const STRUGGLE_DESC := """体内的血液在翻涌，某种东西正挣扎着想要破体而出……
若你愿意献出生命，它会听见你——
失去 21 点生命，将一张「金属龙」加入你的卡组；
也可以按住这股躁动，转身离开。"""

const STRUGGLE_TAKEN_DESC := """「这就是为了胜利我的挣扎。」
金属巨兽破体而出，臣服于你——「金属龙」已加入卡组。"""

const DELIVERY_DESC := """驿站门口堆着一批贴了封条的货箱，脚夫收了钱就不见了人影。
选择承运：平铺挑 1~6 张「货物」加入卡组（1 费工事，0 攻 / 6 血，替你承受伤害）；
货物**被破坏时会从卡组中删除**——毁了就真的毁了。
带着货物走进第二层，第一个事件房的货主会按张兑付报酬，接得越多兑得越多；
兑付完成后这些货物会被货主收走（同样从卡组里删掉）。
也可以不接，转身离开。"""

const DELIVERY_TAKEN_DESC := """货箱已经码上车队，封条上写着「第二层兑付」。
你把 %d 张货物收进了卡组——它们会替你挡伤害，但毁了就真的毁了。"""

const DELIVERY_DONE_DESC := """第二层的第一个事件房里，货主早就在原地等着你。
卡组里每保有一张货物，就当场兑付一次报酬：
一次卡牌奖励 / 80 金币 / 一件随机奖励道具，
还有藏得最深的大奖——一块巧克力（概率 10%%）。
交付完成后货物全部收走（从卡组里删除）。"""

func _rest_desc() -> String:
	## 休息处文案：回复百分比按当前难度档位走（0 / 1 档 = 40%，2 档 = 25%）。
	return """前路的战斗还在等着你。
在篝火旁休息，恢复 %d%% 最大生命；
也可以烤一块肉带在身上，留到 Boss 战前享用。
（两样只能挑一样——选完这一处就到头了。）""" % int(round(RunState.rest_pct() * 100.0))

var _font: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var _rested := false          # 是否已休息（休息后按钮变「继续」）
var _gained := 0              # 本次实际回复量
var _whisper_taken := false   # 鸭鸭低语：是否已收下道具
var _gaze_taken := false      # 鸭之凝视：是否已收下道具
var _pear_taken := false      # 鸭梨山大：是否已收下道具
var _bluefish_taken := false  # 蓝色大肥鱼：是否已收下「鲸鱼之怒」
var _chest_opened := false    # 宝箱层：是否已开箱
var _chest_relic := -1        # 宝箱层：开出的道具 id（-1 = 未开 / 已无货）
var _struggled := false       # 挣扎：是否已接受（失去生命换金属龙）
var _hero_traded := false     # 绝赞五换一：是否已交易（删 5 张换英雄）
var _hero_removed: Array = [] # 绝赞五换一：本次被换走的卡（[{id,name}]）
var _bbq_taken := false       # 烤肉：本次是否已在休息处烤好（获得道具）
var _arcane_charm_taken := false  # 奥秘之泉：**本次访问**是否取走了道具「奥秘护符」
                              #   （≠「本来就戴着」—— 后者只是不重复给，不影响喝泉水，见 R71 / R147）
var _arcane_drunk := false    # 奥秘之泉：是否已选择「喝下泉水」（选卡去了卡牌奖励界面）
var _reward_claimed := false  # R147：本次事件访问是否已领过奖励（一次访问只领一份，见 _claim_reward）
var _oblivion_done := false   # 遗忘之泉：是否已经遗忘过一张卡（或已选择去删卡）
var _smith_done := false      # 鸭鸭工匠：是否已经锻造过（或已选择去锻造）
var _treasure_taken := false  # 宝箱（支付生命换卡牌奖励）：是否已开
var _delivery_taken := false  # R200 运送委托：本次是否已接取（选过货物）
var _delivery_count := 0      # R200 运送委托：本次接了几张
var _delivery_settled := false  # R200 委托完成：本次是否已兑付
var _delivery_result := ""     # R200 委托完成：兑付结果汇总文案
var _pick: PickOverlay = null   # R200：运送委托的平铺选卡页（PickOverlay 复用）
var _reward_panel: RewardPanel = null   # R119：奖励悬浮窗（开箱 / 泉水 / 宝箱都在这里看）

# ── R122：事件文案里的「卡名 / 道具名」可以悬浮查看（用户口径）──
#   取巧的一点：**完全不动 Label 的排版**（27 处 `desc.text = …` 一行不改），
#   只在顶层浮层里按同一套几何（居中 + 字体度量）算出名字的命中矩形；
#   命中后画提示 —— 卡牌画**真实卡面**，道具画名称 + 完整说明。
var _font_bold: Font
var _tip_layer: Control = null
var _ref_names: Array = []       # [{token, name, kind, id}] —— 当前文案里可悬浮的名字
var _ref_hits: Array = []        # [{rect(屏幕坐标), ref}] —— 命中表（文本或几何一变就重建）
var _ref_btn_hits: Array = []    # R168：**选项按钮**上的提及（悬浮「获得某道具」也能看详情）
var _ref_key := ""               # 命中表缓存键（文本 + 描述框矩形）
var _hover_ref := {}             # 当前鼠标悬停到的引用（{} = 没悬停）
var _tip_anchor := Vector2.ZERO  # 提示面板的锚点（鼠标位置 / 演示时名字的右端）
var _tip_demo := ""              # 演示参数 --tip <名字>：锁住悬浮供出图核验

@onready var event_name: Label = $Center/EventName
@onready var desc: Label = $Center/Desc
@onready var rest_btn: Button = $Center/RestBtn
@onready var bbq_btn: Button = $Center/BBQBtn
@onready var leave_btn: Button = $Center/LeaveBtn
@onready var result_label: Label = $Center/ResultLabel


func _is_event_node() -> bool:
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "event"


func _is_chest_layer() -> bool:
	## 宝箱层（第六层）：地图节点类型为 chest，整层都是宝箱。
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "chest"


func _pending_kind() -> String:
	## 当前事件房的**子类型**。两个来源，按优先级：
	##   ① `RunState.pending_event`（演示参数 / 冒烟用例显式指定）；
	##   ② **地图节点自带的 `event_kind`**（真实流程：地图把整个 cell 塞进了 pending_node）。
	## ⚠️ R128 重做 5×7 地图时，map_scene 只写了 pending_node、**漏了写 pending_event**，
	##    而 `_is_treasure()` 是「其余子类型都没认领」的**兜底分支** →
	##    于是**所有**事件房都退化成了「卡牌宝箱」，低语 / 挣扎 / 泉水 / 工匠 从没出现过。
	##    R142 把兜底补在这一层：读 pending_node 就够了，map_scene 一行都不用改。
	if RunState.pending_event != "":
		return RunState.pending_event
	return str(RunState.pending_node.get("event_kind", ""))


func _is_treasure_relic() -> bool:
	## R142：这只卡牌宝箱里装的是**道具**而不是卡牌 —— 旗标在地图生成期就摇定
	## （`RogueMap._make_cells`，走本局 run_rng → 同一种子必然同一个结果）。
	return bool(RunState.pending_node.get("treasure_relic", false))


func _is_whisper() -> bool:
	return _is_event_node() and _pending_kind() == "whisper"


func _is_gaze() -> bool:
	return _is_event_node() and _pending_kind() == "gaze"


func _is_pear() -> bool:
	## 鸭梨山大（第二层专属事件）：获得事件道具「鸭梨」。
	return _is_event_node() and _pending_kind() == "pear"


func _is_bluefish() -> bool:
	## 蓝色大肥鱼（第二层专属事件）：可将一张「鲸鱼之怒」（9050）加入卡组。
	return _is_event_node() and _pending_kind() == "bluefish"


func _is_hero() -> bool:
	## 绝赞五换一（第二层专属）：随机删 5 张不同名的卡 → 得一张「英雄」（9023）。
	return _is_event_node() and _pending_kind() == "hero"


func _is_arcane() -> bool:
	## 奥秘之泉（第一层专属）：获得道具「奥秘护符」/ 或者喝泉水抽 3 张效果·技能牌选 1。
	return _is_event_node() and _pending_kind() == "arcane"


func _is_oblivion() -> bool:
	## 遗忘之泉（全层通用事件）：从卡组删一张卡，或离开。
	return _is_event_node() and _pending_kind() == "oblivion"


func _is_smith() -> bool:
	## 鸭鸭工匠（R110，全层通用事件）：从卡组挑一张卡变成 2 费铁栅栏，或离开。
	return _is_event_node() and _pending_kind() == "smith"


func _is_struggle() -> bool:
	return _is_event_node() and _pending_kind() == "struggle"


func _is_delivery() -> bool:
	## 运送委托（R200，第一层专属）：平铺挑 1~6 张「货物」加入卡组，或离开。
	return _is_event_node() and _pending_kind() == "delivery"


func _is_delivery_done() -> bool:
	## 委托完成（R200）：持有货物时，第二层第一个事件房由 map_scene 替换而来。
	return _is_event_node() and _pending_kind() == "delivery_done"


func _is_relic_chest() -> bool:
	## 宝箱层开箱：节点类型 chest，或（演示参数）事件节点 + pending_event。
	return _is_chest_layer() \
			or (_is_event_node() and _pending_kind() == "relic_chest")


func _is_treasure() -> bool:
	## 卡牌宝箱（支付 5 生命换一组卡牌奖励）：事件节点中未被其它子类型认领的情况。
	return _is_event_node() and not _is_whisper() and not _is_struggle() \
			and not _is_gaze() and not _is_pear() and not _is_hero() \
			and not _is_bluefish() and not _is_relic_chest() \
			and not _is_arcane() and not _is_oblivion() and not _is_smith() \
			and not _is_delivery() and not _is_delivery_done()


func _kind() -> String:
	## 当前事件对应的图片名后缀（与 assets/ui/ 的 event_/bg_ 文件名一一对应）。
	if _is_relic_chest():
		return "relic_chest"
	if _is_whisper():
		return "whisper"
	if _is_gaze():
		return "gaze"
	if _is_pear():
		return "pear"
	if _is_hero():
		return "hero"
	if _is_arcane():
		return "arcane"
	if _is_oblivion():
		return "oblivion"
	if _is_smith():
		return "smith"
	if _is_bluefish():
		return "bluefish"
	if _is_delivery():
		return "delivery"
	if _is_delivery_done():
		return "delivery_done"
	if _is_struggle():
		return "struggle"
	if _is_treasure():
		return "treasure"
	return "rest"


func _apply_ui_assets() -> void:
	## 插图 / 背景：assets/ui/event_<kind>.png 与 bg_<kind>.png，缺图则回退内置绘制。
	## 内置篝火在所有事件界面都显示（与旧版一致）；有自定义插图时才隐藏。
	var kind := _kind()
	var campfire: Control = $Campfire
	campfire.visible = true
	var pic := UiAssets.event_pic(kind)
	if pic != null:
		campfire.visible = false   # 有自定义插图时不再叠内置篝火
		var tr := TextureRect.new()
		tr.name = "EventPic"
		tr.texture = pic
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.anchor_left = 0.5
		tr.anchor_right = 0.5
		tr.offset_left = -160.0
		tr.offset_right = 160.0
		tr.offset_top = 116.0
		tr.offset_bottom = 356.0
		add_child(tr)
	var bg := UiAssets.event_bg(kind)
	if bg != null:
		var trb := TextureRect.new()
		trb.name = "EventBG"
		trb.texture = bg
		trb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		trb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trb.anchor_left = 0.0
		trb.anchor_top = 0.0
		trb.anchor_right = 1.0
		trb.anchor_bottom = 1.0
		trb.offset_left = 0.0
		trb.offset_top = 0.0
		trb.offset_right = 0.0
		trb.offset_bottom = 0.0
		add_child(trb)
		move_child(trb, 0)                              # 压到最底层
		($BG as ColorRect).color = Color(0, 0, 0, 0)    # 让位给自定义背景


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	# R113：事件底色 #252A34 = 暗底 → on_dark = true。
	# 事件是**选择类界面**：三个选项等价，所以全部是次按钮（「一屏最多一个主按钮」的例外）。
	for _b: Button in [rest_btn, bbq_btn, leave_btn]:
		UiTheme.apply_button(_b, false, true)
	sfx = Sfx.new()
	add_child(sfx)
	# 牌库任何时候都可以查看（无论在哪个界面）
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# R119：奖励悬浮窗 —— 宝箱层开箱 / 宝箱事件 / 奥秘之泉「喝下泉水」都先入队，
	# 由它展示完整介绍（长描述不再塞进下面那一行 Label）。
	_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
	# R122：描述文案的悬浮提示层 —— 挂在最后（画在所有子节点之上）、IGNORE（不吃点击）。
	_tip_layer = Control.new()
	_tip_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_layer.draw.connect(_on_tip_draw)
	add_child(_tip_layer)
	# 演示参数：--dmg N 先扣 N 点生命，方便截图/试玩验证休息效果
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dmg" and i + 1 < args.size():
			RunState.take_damage(maxi(0, int(args[i + 1])))
		if args[i] == "--rested":   # 演示：直接呈现休息后的状态（截图验证）
			_gained = RunState.rest()
			_rested = true
		if args[i] == "--treasure":  # 演示：伪装 run 宝箱节点（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "treasure"
		if args[i] == "--treasureRelic":  # 演示：伪装「箱子里是道具」的卡牌宝箱（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event", "event_kind": "treasure",
					"treasure_relic": true}
			RunState.pending_event = "treasure"
		if args[i] == "--whisper":  # 演示：伪装 run 鸭鸭低语事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "whisper"
		if args[i] == "--struggle":  # 演示：伪装 run 挣扎事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "struggle"
		if args[i] == "--gaze":  # 演示：伪装 run 鸭之凝视事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "gaze"
		if args[i] == "--pear":  # 演示：伪装 run 鸭梨山大事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "pear"
		if args[i] == "--bluefish":  # 演示：伪装 run 蓝色大肥鱼事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "bluefish"
		if args[i] == "--hero":  # 演示：伪装 run 绝赞五换一（卡组 6 种不同名，可交易）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--herolow":  # 演示：卡组只有 2 种不同名 → 只能退出事件
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002]
		if args[i] == "--herodone":  # 演示：交易完成后的状态（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "hero"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
			var hd := RunState.trade_five_for_one(CardRepo.load_json())
			_hero_traded = true
			_hero_removed = hd.get("removed", [])
		if args[i] == "--struggledone":  # 演示：伪装 run 挣扎事件 + 已接受状态（截图验证新文案）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "struggle"
			RunState.hp = 50
			_struggled = true
		if args[i] == "--arcane":  # 演示：伪装 run 奥秘之泉事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "arcane"
		if args[i] == "--oblivion":  # 演示：伪装 run 遗忘之泉事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "oblivion"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--smith":  # 演示：伪装 run 鸭鸭工匠事件（R167 出图核验选项文案）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "smith"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--delivery":  # 演示：伪装 run 运送委托事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "delivery"
			RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003, 9003, 9016, 9019]
		if args[i] == "--deliverydone":  # 演示：委托完成（卡组带 3 张货物，截图验证）
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event", "event_kind": "delivery_done"}
			RunState.pending_event = "delivery_done"
			RunState.deck_ids = [8001, 8001, 8002, 8003, 8065, 8065, 8065]
		if args[i] == "--chest":  # 演示：伪装 run 宝箱层节点（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "chest"}
		if args[i] == "--bbq":  # 演示：已在休息处烤好肉（截图验证取走后的状态）
			RunState.gain_relic(RunState.BARBECUE_RELIC_ID)
			_bbq_taken = true
		if args[i] == "--tip" and i + 1 < args.size():
			_tip_demo = args[i + 1]   # 演示：锁住某个名字的悬浮提示（截图核验用）
	bbq_btn.visible = false   # 「烤肉」只在休息处出现，事件节点隐藏
	if _is_whisper():
		event_name.text = "鸭鸭低语"
		desc.text = WHISPER_DESC
		if RunState.has_relic(WHISPER_ID):
			_whisper_taken = true
			_collapse_to_leave()
			desc.text = WHISPER_TAKEN_DESC
			result_label.text = "你已经听见过低语了——前路仍由命运决定。"
			result_label.add_theme_color_override("font_color", Color("a86ad8"))
		else:
			rest_btn.text = "获得「鸭之低语」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "放弃（不受低语影响）"
			result_label.text = ""
	elif _is_gaze():
		event_name.text = "鸭之凝视"
		desc.text = GAZE_DESC
		if RunState.has_relic(RICE_ID):
			_gaze_taken = true
			_collapse_to_leave()
			desc.text = GAZE_TAKEN_DESC
			result_label.text = "那袋米你已经扛在肩上了——鸭眼仍在注视，却不再给你更多。"
			result_label.add_theme_color_override("font_color", Color("d7a54a"))
		else:
			rest_btn.text = "获得「一袋米抗几楼」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "别过头去（放弃）"
			result_label.text = ""
	elif _is_pear():
		event_name.text = "鸭 梨 山 大"
		desc.text = PEAR_DESC
		if RunState.has_relic(PEAR_ID):
			_pear_taken = true
			_collapse_to_leave()
			desc.text = PEAR_TAKEN_DESC
			result_label.text = "鸭梨已经背在肩上了——往后的每一次受伤，都会让你更「强大」一点。"
			result_label.add_theme_color_override("font_color", Color("8a9a2f"))
		else:
			rest_btn.text = "获得「鸭梨」"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "把梨推开（放弃）"
			result_label.text = ""
	elif _is_bluefish():
		event_name.text = "蓝 色 大 肥 鱼"
		desc.text = BLUEFISH_TAKEN_DESC if _bluefish_taken else BLUEFISH_DESC
		if _bluefish_taken:
			_collapse_to_leave()
			result_label.text = "「鲸鱼之怒」已加入卡组——用掉之后本场战斗里不再出现。"
			result_label.add_theme_color_override("font_color", UiTheme.RARITY_RARE)
		else:
			rest_btn.text = "收下「鲸鱼之怒」（加入卡组）"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "不捡（放弃）"
			result_label.text = ""
	elif _is_hero():
		event_name.text = "绝赞五换一"
		desc.text = HERO_DESC
		if _hero_traded:
			_collapse_to_leave()
			desc.text = HERO_TAKEN_DESC
			result_label.text = "交易完成：「英雄」已加入卡组（换走 %d 张）" % _hero_removed.size()
			result_label.add_theme_color_override("font_color", UiTheme.STAT_POWER)
		else:
			var repo_h := CardRepo.load_json()
			var kinds_h: int = RunState.deck_distinct_names(repo_h)
			if RunState.can_trade_five(repo_h):
				rest_btn.text = "换！交出 5 张不同名的卡，获得「英雄」"
				rest_btn.disabled = false
				$Center/LeaveBtn.text = "不换（退出事件）"
				result_label.text = "卡组现有 %d 种不同的卡——够换。" % kinds_h
				result_label.add_theme_color_override("font_color", UiTheme.SIDE_SELF_TEXT)
			else:
				# 卡组不足 5 种不同名 → 只能退出事件
				rest_btn.text = "凑不出 %d 种不同的卡" % HERO_TRADE_NEED
				rest_btn.disabled = true
				$Center/LeaveBtn.text = "退出事件"
				result_label.text = "卡组只有 %d 种不同的卡，这笔买卖做不成（只能退出）。" % kinds_h
				result_label.add_theme_color_override("font_color", Color("9a968c"))
	elif _is_arcane():
		_setup_arcane()
	elif _is_oblivion():
		event_name.text = "遗 忘 之 泉"
		desc.text = OBLIVION_DONE_DESC if _oblivion_done else OBLIVION_DESC
		if _oblivion_done:
			_collapse_to_leave()
			result_label.text = "你已经在泉里遗忘过一张卡了。"
			result_label.add_theme_color_override("font_color", Color("5a6a8a"))
		else:
			rest_btn.text = "遗忘：从卡组中选择一张卡删除"
			rest_btn.disabled = RunState.deck_ids.is_empty()
			$Center/LeaveBtn.text = "离开（不删卡）"
			result_label.text = ""
	elif _is_smith():
		event_name.text = "鸭 鸭 工 匠"
		desc.text = SMITH_DONE_DESC if _smith_done else SMITH_DESC
		if _smith_done:
			_collapse_to_leave()
			result_label.text = "你已经在工匠那里锻造过一张卡了。"
			result_label.add_theme_color_override("font_color", Color("8a6a3a"))
		else:
			# 「铁栅栏」必须带「」：按钮文字里的**显式标记**就是「这里能悬浮看详情」的判据
			# （`Mention.scan` 只认带标记的名字，避免裸词误命中）。
			rest_btn.text = "锻造：把卡组中的一张卡变成 2 费「铁栅栏」"
			rest_btn.disabled = RunState.deck_ids.is_empty()
			$Center/LeaveBtn.text = "离开（不锻造）"
			result_label.text = ""
	elif _is_delivery():
		event_name.text = "运 送 委 托"
		desc.text = (DELIVERY_TAKEN_DESC % _delivery_count) if _delivery_taken else DELIVERY_DESC
		if _delivery_taken:
			_collapse_to_leave()
			result_label.text = "已接取 %d 张货物——第二层的第一个事件房，货主会按张兑付报酬。" \
					% _delivery_count
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			rest_btn.text = "承运：平铺挑选 1~%d 张「货物」加入卡组" % DELIVERY_MAX
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "不接（转身离开）"
			result_label.text = ""
	elif _is_delivery_done():
		event_name.text = "委 托 完 成"
		desc.text = DELIVERY_DONE_DESC
		if _delivery_settled:
			_collapse_to_leave()
			result_label.text = _delivery_result
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			var n_cargo: int = RunState.cargo_count()
			rest_btn.text = "兑付：卡组 %d 张货物 × 各抽一次" % n_cargo
			rest_btn.disabled = n_cargo <= 0
			$Center/LeaveBtn.text = "不要报酬（离开）"
			result_label.text = ""
	elif _is_relic_chest():
		event_name.text = "宝 箱 层"
		desc.text = CHEST_LAYER_DESC
		rest_btn.text = "开启宝箱（获得 1 个随机奖励道具）"
		rest_btn.disabled = false
		$Center/LeaveBtn.text = "空手离开"
		result_label.text = ""
	elif _is_treasure():
		event_name.text = "宝  箱"
		# R142：箱子里可能是**卡牌**、也可能是**道具**（开箱前不告诉玩家是哪一种）。
		desc.text = "路旁放着一只落满灰尘的宝箱……\n" \
				+ "支付 5 生命打开它——箱子里可能是一组卡牌（选 1 张加入卡组），\n" \
				+ "也可能是一件道具（直接进道具栏）。也可以转身离开，分文不取。"
		rest_btn.text = "支付 5 生命，打开宝箱"
		rest_btn.disabled = RunState.hp <= 5   # 至少保留 1 点生命
		$Center/LeaveBtn.text = "跳过（不支付生命）"
		result_label.text = ""
	elif _is_struggle():
		event_name.text = "挣  扎"
		desc.text = STRUGGLE_TAKEN_DESC if _struggled else STRUGGLE_DESC
		if _struggled:
			_collapse_to_leave()
		else:
			rest_btn.text = "接受挣扎（失去 %d 生命，获得「金属龙」）" % STRUGGLE_LIFE
			rest_btn.disabled = RunState.hp <= STRUGGLE_LIFE   # 至少保留 1 点生命
			$Center/LeaveBtn.text = "转身离开（保持现状）"
		result_label.text = ""
	else:
		# 休息处：休息 与 烤肉 两个选项（烤肉是新增选项）
		bbq_btn.visible = true
		event_name.text = "休息处"
		desc.text = _rest_desc()
	$Center/LeaveBtn.pressed.connect(func(): _ui_leave())
	rest_btn.pressed.connect(func(): _ui_main())
	bbq_btn.pressed.connect(func(): _ui_bbq())
	_apply_ui_assets()
	_refresh()
	_fit_center()   # 布局就位后先校准一次
	_fit_center.call_deferred()   # 字体异步就位后最小尺寸可能再变 → 延迟一帧补一次
	# R147 演示：自动点一次泉水选项，出图核验「已领一份 → 另一个选项锁死」的界面。
	#   选项是在上面的 if/elif 链里铺好的，所以必须放在链**之后**（放进 args 循环会太早）。
	if "--arcanetake" in args:      # 先取护符 → 「喝下泉水」应锁死
		_on_main()
	elif "--arcanebrew" in args:    # 先喝泉水 → 「获取护符」应锁死
		_on_bbq()
		if _reward_panel != null:
			_reward_panel.close()   # 演示：关掉奖励窗，露出「两个选项都锁死」的界面
	# 命令行 -- --screenshot：打开后自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_event.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# R148：Esc 主菜单。事件页是**选择类界面** —— 内容选项（休息 / 烤肉 / 离开）留在
	# 场景自己身上，菜单里只放「画面之外」的操作：返回事件 / 音效 / 返回标题。
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "返回事件",
		"sub": "事件 · 按 Esc 返回",
	})


func _redraw() -> void:
	## 文案变化后的统一出口：先重排中间一列，再重绘。
	_fit_center()
	queue_redraw()


func _fit_center() -> void:
	## 中间一列按内容实际高度排布：默认位置不变；放不下时先收紧间距、藏起空的结果行，
	## 再整体上移（上不越过插图下沿约 356），保证「离开 / 继续前进」这类末位选项永远完整可见。
	var c: VBoxContainer = $Center
	var vh: float = get_viewport_rect().size.y
	result_label.visible = result_label.text != ""
	var top_floor := 360.0
	var bottom := vh - 10.0
	var h := 0.0
	for sep in [12, 8, 5]:
		c.add_theme_constant_override("separation", sep)
		h = c.get_combined_minimum_size().y
		if top_floor + h <= bottom:
			break
	var top: float = clampf(bottom - h, top_floor, vh * 0.5 + 60.0)
	c.offset_top = top - vh * 0.5
	c.offset_bottom = c.offset_top + h


func _on_main() -> void:
	## 主按钮：宝箱 → 支付 5 生命后转交卡牌奖励；鸭鸭低语 / 鸭之凝视 → 收下事件道具；
	## 宝箱层 → 开箱获得 1 个随机奖励道具；休息 → 休息（或休息后离开）。
	sfx.play("click")
	if _is_whisper():
		if _whisper_taken:
			_on_leave()
			return
		RunState.gain_relic(WHISPER_ID)
		_whisper_taken = true
		_claim_reward(rest_btn)   # R147：本次访问的奖励只领一份（其它选项若有则锁死）
		var rel := RelicRepo.load_json().get_relic(WHISPER_ID)
		_collapse_to_leave()
		desc.text = WHISPER_TAKEN_DESC
		result_label.text = "「鸭之低语」已加入道具栏：%s" % (rel.desc if rel != null else "")
		result_label.add_theme_color_override("font_color", Color("a86ad8"))
		_redraw()
		return
	if _is_gaze():
		if _gaze_taken:
			_on_leave()
			return
		RunState.gain_relic(RICE_ID)
		_gaze_taken = true
		_claim_reward(rest_btn)   # R147
		var rel_g := RelicRepo.load_json().get_relic(RICE_ID)
		_collapse_to_leave()
		desc.text = GAZE_TAKEN_DESC
		result_label.text = "「一袋米抗几楼」已加入道具栏：%s" \
				% (rel_g.desc if rel_g != null else "")
		result_label.add_theme_color_override("font_color", Color("d7a54a"))
		_redraw()
		return
	if _is_pear():
		if _pear_taken:
			_on_leave()
			return
		RunState.gain_relic(PEAR_ID)
		_pear_taken = true
		_claim_reward(rest_btn)   # R147
		var rel_p := RelicRepo.load_json().get_relic(PEAR_ID)
		_collapse_to_leave()
		desc.text = PEAR_TAKEN_DESC
		result_label.text = "「鸭梨」已加入道具栏：%s" % (rel_p.desc if rel_p != null else "")
		result_label.add_theme_color_override("font_color", Color("8a9a2f"))
		_redraw()
		return
	if _is_bluefish():
		if _bluefish_taken:
			_on_leave()
			return
		RunState.add_card(WHALE_CARD_ID)
		_bluefish_taken = true
		_claim_reward(rest_btn)   # R147
		var wcard := CardRepo.load_json().get_card(WHALE_CARD_ID)
		var wname := wcard.card_name if wcard != null else "鲸鱼之怒"
		_collapse_to_leave()
		desc.text = BLUEFISH_TAKEN_DESC
		result_label.text = "「%s」已加入卡组：%s" % [wname,
				CardText.naturalize(wcard.effect_text) if wcard != null else ""]
		result_label.add_theme_color_override("font_color", UiTheme.RARITY_RARE)
		_redraw()
		return
	if _is_delivery():
		if _delivery_taken:
			_on_leave()
			return
		# R200：平铺选卡页（PickOverlay 复用，R189 口径）—— 6 张货物平铺，
		# 点几张收几张（1~6），确认才入卡组；取消只是收起回事件页。
		var repo_d := CardRepo.load_json()
		var cargo: CardData = repo_d.get_card(CARGO_CARD_ID)
		if cargo == null:
			return
		var picks: Array = []
		for _i in DELIVERY_MAX:
			picks.append(cargo)
		if _pick == null:
			_pick = PickOverlay.new()
			_pick.confirmed.connect(_on_delivery_confirmed)
			_pick.cancelled.connect(_on_delivery_cancelled)
			add_child(_pick)
		_pick.open({
			"kind": "delivery",
			"title": "运送委托 · 挑选货物",
			"note": "点几张收几张（%d~%d 张）；货物被破坏时会从卡组中删除"
					% [DELIVERY_MIN, DELIVERY_MAX],
			"cards": picks,
			"counts": [],
			"max_sel": DELIVERY_MAX,
			"min_sel": DELIVERY_MIN,
			"confirm_label": "接下货物",
			"cancel_label": "不接（收起）",
			"short": "运送委托",
		})
		return
	if _is_delivery_done():
		if _delivery_settled:
			_on_leave()
			return
		_delivery_settle()
		return
	if _is_hero():
		if _hero_traded:
			_on_leave()
			return
		var repo_t := CardRepo.load_json()
		if not RunState.can_trade_five(repo_t):
			return    # 卡组不足 5 种不同名：按钮本就是禁用的，这里再兜一次
		var res: Dictionary = RunState.trade_five_for_one(repo_t)
		if not bool(res.get("ok", false)):
			return
		_hero_traded = true
		_hero_removed = res.get("removed", [])
		_claim_reward(rest_btn)   # R147
		var names_t: Array[String] = []
		for r: Variant in _hero_removed:
			names_t.append(str((r as Dictionary).get("name", "?")))
		var hero_card := repo_t.get_card(HERO_CARD_ID)
		var hname := hero_card.card_name if hero_card != null else "英雄"
		_collapse_to_leave()
		desc.text = HERO_TAKEN_DESC
		result_label.text = "换走 %d 张（%s）——「%s」已加入卡组" % [
				_hero_removed.size(), "、".join(names_t), hname]
		result_label.add_theme_color_override("font_color", UiTheme.STAT_POWER)
		_redraw()
		return
	if _is_arcane():
		# R147：已经领过（护符 / 泉水）→ 这颗按钮只剩「继续」的意思。
		if _arcane_taken():
			_on_leave()
			return
		RunState.gain_relic(ARCANE_CHARM_ID)
		_arcane_charm_taken = true
		var rel_a := RelicRepo.load_json().get_relic(ARCANE_CHARM_ID)
		_collapse_to_leave()
		desc.text = ARCANE_CHARM_TAKEN_DESC
		# R147：一次访问只领一份 —— 取走护符后「喝下泉水」立刻锁死（用户口径）。
		#（R71 那条「拿到护符还能喝泉水」的口径到此为止：那是「本来就戴着老护符」的待遇。）
		bbq_btn.text = "（已获得护符——本次不能再喝泉水）"
		_claim_reward(rest_btn)
		result_label.text = "「奥秘护符」已加入道具栏：%s（本次泉水只给一份奖励）" \
				% (rel_a.desc if rel_a != null else "")
		result_label.add_theme_color_override("font_color", Color("2f7fa8"))
		_redraw()
		return
	if _is_oblivion():
		if _oblivion_done:
			_on_leave()
			return
		if RunState.deck_ids.is_empty():
			return
		# 删卡由卡组编辑场景完成（RunState.pending_deck_edit 是它的待办标记）；
		# 事件节点在这里就算走完 —— 回地图后不会再被送回同一个事件。
		_oblivion_done = true
		_claim_reward(rest_btn)   # R147：删卡也是「本次唯一的一份奖励」
		RunState.complete_current()
		RunState.pending_deck_edit = "delete"
		SceneFx.goto("res://scenes/deck_edit.tscn")
		return
	if _is_smith():
		if _smith_done:
			_on_leave()
			return
		if RunState.deck_ids.is_empty():
			return
		# 锻造同样交给卡组编辑场景（pending_deck_edit = "smith"）——
		# 选牌 UI 与「遗忘之泉」共用，不新造一套。
		_smith_done = true
		_claim_reward(rest_btn)   # R147：锻造也算「本次唯一的一份奖励」
		RunState.complete_current()
		RunState.pending_deck_edit = "smith"
		SceneFx.goto("res://scenes/deck_edit.tscn")
		return
	if _is_relic_chest():
		if _chest_opened:
			_on_leave()
			return
		_chest_opened = true
		_claim_reward(rest_btn)   # R147
		_chest_relic = RunState.roll_reward_relic()
		_collapse_to_leave()
		if _chest_relic < 0:
			desc.text = "箱底只剩一层灰——奖励道具你已经全都拿到了。"
			result_label.text = "宝箱是空的（奖励道具已全部拥有）"
			result_label.add_theme_color_override("font_color", Color("9a968c"))
		else:
			# R119：**不在这里把 desc 塞进一行 Label**（长描述会画出框外）——
			# 奖励先入队，由奖励悬浮窗展示完整介绍，玩家看过再决定收下 / 放弃。
			RunState.queue_relic_reward(_chest_relic)
			var rc := RelicRepo.load_json().get_relic(_chest_relic)
			var rname := rc.relic_name if rc != null else str(_chest_relic)
			desc.text = "箱盖吱呀一声打开——里面躺着一件道具。\n「%s」已放进待领奖励，请在上面弹出的奖励悬浮窗里查看。" % rname
			result_label.text = "开出道具「%s」（待领：见奖励悬浮窗）" % rname
			result_label.add_theme_color_override("font_color",
					rc.source_color() if rc != null else Color("d89a2e"))
			if _reward_panel != null:
				_reward_panel.open()
		_redraw()
		return
	if _is_treasure():
		if _treasure_taken:
			_on_leave()
			return
		if RunState.hp <= 5:
			return
		RunState.take_damage(5)
		_treasure_taken = true
		_claim_reward(rest_btn)   # R147
		_collapse_to_leave()
		result_label.text = "已支付 5 生命（当前 %d/%d）" % [RunState.hp, RunState.max_hp]
		result_label.add_theme_color_override("font_color", Color("9a968c"))
		# R142：箱子内容在**生成地图时**就摇定（`treasure_relic` 旗标）：
		# 一半概率是一件道具，否则是原来的卡牌三选一。
		if _is_treasure_relic():
			var got := RunState.roll_reward_relic()
			if got > 0:
				RunState.queue_relic_reward(got)
				var rc := RelicRepo.load_json().get_relic(got)
				var rname := rc.relic_name if rc != null else str(got)
				desc.text = "箱盖掀开——里面躺着一件道具！\n「%s」已放进待领奖励，请在上面的奖励悬浮窗里查看。" % rname
				result_label.text = "开出道具「%s」（待领：见奖励悬浮窗）" % rname
				result_label.add_theme_color_override("font_color",
						rc.source_color() if rc != null else Color("d89a2e"))
				if _reward_panel != null:
					_reward_panel.open()
				_redraw()
				return
			# 奖励道具已全部拥有 / 全被跳过 → 退回卡牌奖励，绝不让这 5 点生命白花。
			result_label.text = "已支付 5 生命（当前 %d/%d）——箱底没有道具了，改给卡牌" \
					% [RunState.hp, RunState.max_hp]
		# R119：卡牌奖励**先入队** → 奖励悬浮窗里看完三张候选再挑一张。
		RunState.queue_card_reward("normal")
		desc.text = "箱盖掀开，里面是一叠卡牌……\n请在上面的奖励悬浮窗里查看并挑走一张。"
		if _reward_panel != null:
			_reward_panel.open()
		_redraw()
		return
	if _is_struggle():
		if _struggled:
			_on_leave()
			return
		if RunState.hp <= STRUGGLE_LIFE:
			return
		RunState.take_damage(STRUGGLE_LIFE)
		RunState.add_card(STRUGGLE_CARD_ID)
		_struggled = true
		_claim_reward(rest_btn)   # R147
		var card := CardRepo.load_json().get_card(STRUGGLE_CARD_ID)
		var cname := card.card_name if card != null else "金属龙"
		desc.text = STRUGGLE_TAKEN_DESC
		_collapse_to_leave()
		result_label.text = "失去 %d 生命（当前 %d/%d）——「%s」已加入卡组" % [
				STRUGGLE_LIFE, RunState.hp, RunState.max_hp, cname]
		result_label.add_theme_color_override("font_color", Color("a44ad0"))
		_redraw()
		return
	if _rested or _bbq_taken:
		_on_leave()
		return
	_gained = RunState.rest()
	_rested = true
	_claim_reward(rest_btn)   # R147：本次休息处只领一份 → 「烤肉」锁死
	rest_btn.disabled = false
	_refresh()
	_redraw()


func _on_delivery_confirmed(selected: Array) -> void:
	## R200：运送委托确认 —— 选了几张就入卡组几张（货物 8065）。
	if _pick != null:
		_pick.close()
	var n: int = selected.size()
	if n < DELIVERY_MIN or n > DELIVERY_MAX:
		return
	for _i in n:
		RunState.add_card(CARGO_CARD_ID)
	_delivery_taken = true
	_delivery_count = n
	_collapse_to_leave()
	desc.text = DELIVERY_TAKEN_DESC % n
	result_label.text = "已接取 %d 张货物（1 费工事 0/6/0）——第二层第一个事件房兑付报酬。" % n
	result_label.add_theme_color_override("font_color", Color("c8a86a"))
	_redraw()


func _on_delivery_cancelled() -> void:
	## R200：放弃挑选 → 收起选卡页回事件页（不接货，什么都不扣）。
	if _pick != null:
		_pick.close()


func _delivery_settle() -> void:
	## R200：委托完成兑付 —— 卡组每保有 1 张货物 → 抽奖一次。
	## 概率：卡牌奖励 35% / 80 金币 25% / 随机奖励道具 30% / 隐藏大奖巧克力 10%。
	## ⚠️ 随机一律走 RunState.run_rng（run 层唯一源 → 同一种子结果一致）。
	var n: int = RunState.cargo_count()
	if n <= 0:
		return
	var n_cards := 0
	var n_gold := 0
	var n_relic := 0
	var n_choco := 0
	for _i in n:
		var r: float = RunState.run_rng.randf()
		if r < 0.10:
			n_choco += 1            # 隐藏大奖：巧克力 ×1
		elif r < 0.40:
			n_relic += 1            # 30% → 随机奖励道具
		elif r < 0.65:
			n_gold += 1             # 25% → 80 金币
		else:
			n_cards += 1            # 35% → 一次卡牌奖励
	if n_gold > 0:
		RunState.gain_gold(80 * n_gold)
	if n_choco > 0:
		RunState.chocolate += n_choco
	for _i in n_relic:
		var rid: int = RunState.roll_reward_relic()
		if rid > 0:
			RunState.queue_relic_reward(rid)
	for _i in n_cards:
		RunState.queue_card_reward("normal")
	# R210：**交出去的货物必须真的从卡组里删掉**（用户口径「交付后货物没有从卡组删除」）——
	# R200 只按张数发奖励，`deck_ids` 里那些货物原封不动，交付完还会一路抽到这些废牌。
	# 先兑付、后删（兑付张数就是此刻卡组里的货物数），删完 `cargo_count()` 归 0。
	var cargo_gone: int = RunState.remove_all_cards(CARGO_CARD_ID)
	RunState.delivery_done = true     # 一次性：本局不再触发
	_delivery_settled = true
	var parts: Array[String] = ["%d 张货物全部兑付" % n]
	if n_cards > 0:
		parts.append("卡牌奖励 ×%d" % n_cards)
	if n_gold > 0:
		parts.append("%d 金币" % (80 * n_gold))
	if n_relic > 0:
		parts.append("随机道具 ×%d" % n_relic)
	if n_choco > 0:
		parts.append("隐藏大奖·巧克力 ×%d！" % n_choco)
	if cargo_gone > 0:
		parts.append("%d 张货物已从卡组移除" % cargo_gone)
	_delivery_result = "兑付结果：" + "；".join(parts)
	_collapse_to_leave()
	desc.text = DELIVERY_DONE_DESC
	result_label.text = _delivery_result + "（待领奖励见右上悬浮窗）"
	result_label.add_theme_color_override("font_color", Color("c8a86a"))
	if _reward_panel != null and RunState.pending_reward_count() > 0:
		_reward_panel.open()
	_redraw()


func _claim_reward(keep: Button) -> void:
	## R147：**一次事件访问只能领走一份奖励**。
	## 用户口径：「任意获得一个奖励之后，应该不再能获取其他奖励。（任何事件都应该做成这样）」
	## 任一奖励到手后，本事件里**其它**奖励按钮立刻锁死（`keep` = 刚发过奖励的那个按钮，
	## 它会变成「继续」，保留可用）。单奖励事件里另一个按钮本来就不可见 → 这里是空操作，
	## 所以「所有事件共用同一条规则」不需要每个事件各写一遍。
	_reward_claimed = true
	for b: Button in [rest_btn, bbq_btn]:
		if b == null or b == keep or not b.visible:
			continue
		b.disabled = true


func _collapse_to_leave() -> void:
	## R178：事件选项办完 → 全场只留一个「离开」。
	## 旧版是「主按钮变『继续』+ 放弃 / 退出 / 已完成按钮原样留着（多数还 disabled）」
	## —— 一次访问里出现两个语义重叠的按钮（用户报：选完选项后放弃/退出还在）。
	## 现在：主按钮（rest_btn）与第二选项（bbq_btn）收起，LeaveBtn 成为唯一出口。
	## ⚠️ 与 R147「一次访问只领一份」天然兼容：奖励按钮都收起了，不存在第二个奖励入口；
	##    幂等（铺排 / _on_main / _refresh 三处都会调，重复调无副作用）。
	rest_btn.visible = false
	if bbq_btn != null:
		bbq_btn.visible = false
	leave_btn.visible = true
	leave_btn.text = "离开"
	leave_btn.disabled = false
	_reward_claimed = true
	_redraw()


func _arcane_taken() -> bool:
	## R147：本次访问是否已从泉里领走奖励（护符 / 泉水任一份）。
	## ⚠️ 只看「本次」的两个旗标，**不能**用 `RunState.has_relic(ARCANE_CHARM_ID)` ——
	##    后者会把上一处泉水给的 / 奖励池抽到的「老护符」也算成「本次已领」，
	##    于是已戴护符的玩家连泉水都喝不到（R71 修过的那个 bug 会原地复发）。
	return _arcane_charm_taken or _arcane_drunk


func _setup_arcane() -> void:
	## 奥秘之泉的选项铺排（从 _ready 的分支里抽出来，好让回归能单独重跑）。
	## R71：**已经戴过奥秘护符也照样能「喝下泉水」** ——
	## 原来「已有护符」那条分支把 bbq_btn 一起 `visible = false` 了 → 玩家只能点「继续」，
	## 第二个选项形同虚设。护符不重复给，但「从 3 张效果/技能牌里选 1 张加入卡组」永远可用。
	## R147：`_arcane_charm_taken` 只表示「**本次**取走了护符」，所以**不再**在铺选项时置位
	##（那是「本来就戴着」，拿它当闸门就退回 R71 的 bug 了）。
	event_name.text = "奥 秘 之 泉"
	# R178：重铺时把两个按钮都恢复可见 —— 上一次「办完收起」（_collapse_to_leave）
	# 之后可能残留 visible=false；这个函数是「重铺选项」的唯一口，回归也靠它重跑。
	rest_btn.visible = true
	bbq_btn.visible = true
	bbq_btn.text = "喝下泉水：随机 3 张效果 / 技能牌中选 1 张加入卡组"
	bbq_btn.disabled = false
	if RunState.has_relic(ARCANE_CHARM_ID):
		desc.text = ARCANE_CHARM_TAKEN_DESC
		rest_btn.text = "继续（已戴护符）"
		rest_btn.disabled = true
		leave_btn.text = "离开（不要新的牌）"
		leave_btn.disabled = false
		result_label.text = "「奥秘护符」你已经戴在身上了——不过泉水还是可以喝（本次只给一份）。"
		result_label.add_theme_color_override("font_color", Color("2f7fa8"))
	else:
		desc.text = ARCANE_DESC
		rest_btn.text = "获取护符：获得道具「奥秘护符」"
		rest_btn.disabled = false
		leave_btn.text = "离开（两个都不要）"
		leave_btn.disabled = false
		result_label.text = ""


func _refresh() -> void:
	# R178：本次访问的奖励已领完 → 任何刷新都保持「只有一个离开」的收尾态
	#（_on_main 的休息分支等地方会再调 _refresh，不收住会把按钮文案改回去）。
	if _reward_claimed:
		_collapse_to_leave()
		return
	if _is_treasure() or _is_whisper() or _is_struggle() \
			or _is_gaze() or _is_pear() or _is_hero() or _is_bluefish() \
			or _is_relic_chest() or _is_arcane() or _is_oblivion() \
			or _is_smith() or _is_delivery() or _is_delivery_done():
		# ⚠️ R167：工匠（smith）**必须**在这张白名单里 —— 否则 _refresh() 会把它当成休息处，
		#   把上面刚设好的「锻造：…」按钮文案覆盖成「在这里休息（回复 N 生命）」，
		#   于是「选项文本与实际不符」（点了其实不回复生命）。
		return
	_refresh_bbq()
	# R178：休息处办完（休息 / 烤肉任意一个）→ 也只留一个「离开」，
	# 治愈 / 烤肉文案照写（结果行在按钮下方，收起按钮不影响它）。
	if _rested or _bbq_taken:
		bbq_btn.visible = false
		rest_btn.visible = false
		leave_btn.visible = true
		leave_btn.text = "离开"
		leave_btn.disabled = false
		_reward_claimed = true
		if _rested:
			result_label.text = "篝火的温暖涌上心头……生命回复 +%d（当前 %d/%d）" % [
					_gained, RunState.hp, RunState.max_hp]
			result_label.add_theme_color_override("font_color", UiTheme.SIDE_SELF_TEXT)
		elif _bbq_taken:
			result_label.text = "「烤肉」已收进道具栏——进入 Boss 战时自动享用，回复 25% 最大生命。"
			result_label.add_theme_color_override("font_color", Color("d89a2e"))
		_redraw()
		return
	leave_btn.text = "离开（不休息）"
	var gain: int = RunState.rest_heal_amount()   # 按难度档位（0/1 档 40%、2 档 25%）
	rest_btn.text = "在这里休息（回复 %d 生命）" % mini(gain, RunState.max_hp - RunState.hp)
	result_label.text = ""


func _refresh_bbq() -> void:
	## 烤肉选项状态：持有「烤肉」时不可再选；被 Boss 战消耗掉后即可再次烤制。
	if RunState.has_relic(RunState.BARBECUE_RELIC_ID):
		bbq_btn.text = "已持有「烤肉」（Boss 战时自动消耗）"
		bbq_btn.disabled = true
	else:
		bbq_btn.text = "烤肉（获得「烤肉」，留到 Boss 战）"
		bbq_btn.disabled = false


func _on_bbq() -> void:
	## 休息处「烤肉」：获得事件道具「烤肉」（进入 Boss 战时自动消耗 → 回复 25% 生命）。
	## 奥秘之泉：这一路是「选择2 · 喝下泉水」→ 去卡牌奖励界面（限定效果 / 技能）。
	sfx.play("click")
	if _is_arcane():
		# R71：判断「能不能喝泉水」只看 `_arcane_drunk`（喝过）与 `_arcane_charm_taken`
		#（**本次**取走过护符）—— **不能**用 `RunState.has_relic()`：那会把上一处泉水 /
		# 奖励池给的老护符也当成「本次已领」，已戴护符的玩家就再也喝不到泉水。
		# R147：一次访问只领一份 —— 本次取走过护符就不能再喝。
		if _arcane_taken():
			return
		_arcane_drunk = true
		# R119：泉水给的卡牌奖励同样**先入队**（限定 效果 / 技能），由奖励悬浮窗处理。
		var arcane_kinds: Array[String] = ["效果", "技能"]
		RunState.queue_card_reward("normal", arcane_kinds)
		_collapse_to_leave()
		# R147：喝过之后「获取护符」立刻锁死。
		_claim_reward(bbq_btn)
		result_label.text = "「喝下泉水」：请在奖励悬浮窗里从 3 张效果 / 技能牌中挑一张（本次只给一份）。"
		result_label.add_theme_color_override("font_color", Color("2f7fa8"))
		if _reward_panel != null:
			_reward_panel.open()
		_redraw()
		return
	if _rested:   # R147：本次休息处只领一份（先休息过 → 不能再烤肉）
		return
	if RunState.has_relic(RunState.BARBECUE_RELIC_ID):
		return
	RunState.gain_relic(RunState.BARBECUE_RELIC_ID)
	_bbq_taken = true
	_claim_reward(bbq_btn)
	_refresh()
	_redraw()


func _ui_main() -> void:
	_on_main()


func _ui_bbq() -> void:
	_on_bbq()


func _ui_leave() -> void:
	_on_leave()


func _on_leave() -> void:
	if RunState.run_active:
		RunState.complete_current()   # 事件/休息完成 → 节点标记完成
		SceneFx.goto("res://scenes/map.tscn")
	else:
		SceneFx.goto("res://scenes/title.tscn")


# ──────────────────────────────────────────────────────────────────────
# R122：描述文本里的「卡名 / 道具名」可悬浮查看
# ──────────────────────────────────────────────────────────────────────
# 用户口径：「事件中提到道具或卡片时，应该可以在悬浮到卡名的时候显示那个道具 /
# 那张卡片」。实现上刻意**不动 Label 的排版**：不换 RichTextLabel、不加 BBCode，
# 27 处 `desc.text = …` 一处不改 —— 只按同一套几何复算命中矩形，再在顶层浮层里画。

func _menu_items() -> Array:
	## 事件页的菜单项（R148）。⚠️ 每次打开菜单都重新调用 → 音效文案是当下值。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## R167：回标题 = **保留本局**（只复位内存状态，续档留着）——
	## 标题页「继续游戏」可以从上一次地图检查点接着来。
	if RunState.run_active:
		RunState.end_run(false)
	SceneFx.goto("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return


func _process(_delta: float) -> void:
	if _tip_layer == null:
		return
	var key := "%s@%s" % [desc.text, str(desc.get_global_rect())]
	if key != _ref_key:
		_ref_key = key
		_ref_scan()
		_ref_layout()
	var ref := {}
	if _tip_demo != "":
		# 演示：锁住某个名字（合成鼠标在 headless 下永远是 (0,0)，没法真悬停）
		for e: Dictionary in _ref_names:
			if e["name"] == _tip_demo:
				ref = e
				break
		for h: Dictionary in _ref_hits:
			if h["ref"]["name"] == _tip_demo:
				_tip_anchor = h["rect"].end + Vector2(0, 6)
				break
	elif not UiGate.blocked():
		# UiGate：奖励悬浮窗 / 牌库面板盖着时一律让位（R121 的既有约定）
		var mp := get_viewport().get_mouse_position()
		for h: Dictionary in _ref_hits:
			if h["rect"].has_point(mp):
				ref = h["ref"]
				break
		if ref.is_empty():
			# R168：选项按钮上的提及（按钮整块都算命中区，好点）
			for hb: Dictionary in _ref_btn_hits:
				if hb["rect"].has_point(mp):
					ref = hb["ref"]
					break
		_tip_anchor = mp
	if not _same_ref(ref, _hover_ref):
		_hover_ref = ref
	_tip_layer.queue_redraw()


static func _same_ref(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() != b.is_empty():
		return false
	if a.is_empty():
		return true
	return str(a["kind"]) == str(b["kind"]) and int(a["id"]) == int(b["id"])


static func _ref_index() -> Dictionary:
	## 名字 → 引用。R168 起**委托 `Mention.index()`** —— 事件 / 卡面 / 奖励 / 图鉴
	## 全工程共用同一张名字表（唯一口径，卡牌优先，卡 200+ / 道具 40+ 只建一次）。
	return Mention.index()


static func _markers(txt: String) -> Array:
	## 摘出 `「…」` 与 `**…**` 里的内容（返回 [{token(含标记), name}]）。
	## ⚠️ R167：`desc` 是普通 Label，**不会**把 `**` 渲染成加粗 —— 星号会原样显示。
	##   所以**玩家可见文案一律用「」**；`**` 只在历史文案 / 断言里作兼容保留。
	var out: Array = []
	var i := 0
	while i < txt.length():
		if txt[i] == "「":
			var j := txt.find("」", i + 1)
			if j < 0:
				break
			out.append({"token": txt.substr(i, j - i + 1),
					"name": txt.substr(i + 1, j - i - 1)})
			i = j + 1
			continue
		if txt[i] == "*" and i + 1 < txt.length() and txt[i + 1] == "*":
			var k := txt.find("**", i + 2)
			if k < 0:
				break
			var nm := txt.substr(i + 2, k - i - 2)
			if nm != "":
				out.append({"token": txt.substr(i, k - i + 2), "name": nm})
			i = k + 2
			continue
		i += 1
	return out


func _ref_scan() -> void:
	## 登记「能对上卡名 / 道具名」的片段；对不上的一律忽略
	## （所以「这就是为了胜利我的挣扎。」这种纯引用不会被误标）。
	_ref_names = []
	var idx := _ref_index()
	var seen := {}
	for mk: Dictionary in _markers(desc.text):
		var nm: String = mk["name"]
		if nm == "" or seen.has(nm) or not idx.has(nm):
			continue
		seen[nm] = true
		var e: Dictionary = (idx[nm] as Dictionary).duplicate()
		e["token"] = mk["token"]
		e["name"] = nm
		_ref_names.append(e)


func _ref_layout() -> void:
	## 命中表（**屏幕坐标**）：把 Label 的排版复算一遍 —— 每行水平居中、
	## 行高 = `get_line_height()`、行距 = `line_spacing` 主题常量。
	_ref_hits = []
	if _ref_names.is_empty():
		_ref_button_hits()
		return
	var box := desc.get_global_rect()
	var font: Font = desc.get_theme_font("font")
	if font == null:
		return
	var fs: int = desc.get_theme_font_size("font_size")
	var lh: float = float(desc.get_line_height())
	var gap: float = float(desc.get_theme_constant("line_spacing"))
	var lines := desc.text.split("\n")
	var y := box.position.y
	for li in lines.size():
		var line: String = lines[li]
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := box.position.x + (box.size.x - lw) * 0.5
		for e: Dictionary in _ref_names:
			var tok: String = e["token"]
			var from := 0
			while true:
				var at := line.find(tok, from)
				if at < 0:
					break
				var ax := x0 + font.get_string_size(line.substr(0, at),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var bx := ax + font.get_string_size(tok,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				_ref_hits.append({"rect": Rect2(ax, y, bx - ax, lh), "ref": e})
				from = at + tok.length()
		y += lh + gap
	_ref_button_hits()


func _btn_bg_lum(b: Button) -> float:
	## 按钮底色的亮度（取不到样式盒时给 0.5 = 中性，走「按底色挑色」的默认分支）。
	var sb := b.get_theme_stylebox("normal")
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color.get_luminance()
	return 0.5


func _ref_button_hits() -> void:
	## R168（用户口径）：**悬浮「获得某个道具 / 某张卡」的选项**也要能直接看详情。
	## 按钮文字由 Godot 自己画（不能只给名字上色），所以这里只登记命中矩形 +
	## 在提示层给按钮描一圈淡金（悬停点亮）—— 明确「这个选项还有东西可看」。
	_ref_btn_hits = []
	for b: Button in [rest_btn, bbq_btn, leave_btn]:
		if b == null or not b.visible or b.text.strip_edges() == "":
			continue
		# 环色按**按钮底色**取（不是字色）：事件页选项是浅色胶囊，金色环在上面等于没画。
		var ring: Color = UiTheme.MENTION_ON_LIGHT if _btn_bg_lum(b) > 0.32 \
				else UiTheme.MENTION_ON_DARK
		# 圆角：事件页选项是 `btn_plain` 贴图（奶油胶囊）→ 样式盒是 StyleBoxTexture，
		# 取不到 corner_radius，所以**默认按高度取胶囊圆角**（h/2）；
		# 只有真给 StyleBoxFlat 时才用它自己的圆角。
		var cr := int(b.size.y / 2.0)
		var nsb := b.get_theme_stylebox("normal")
		if nsb is StyleBoxFlat:
			cr = maxi((nsb as StyleBoxFlat).corner_radius_top_left,
					(nsb as StyleBoxFlat).corner_radius_bottom_left)
		for m: Dictionary in Mention.scan(b.text):
			_ref_btn_hits.append({"rect": b.get_global_rect(), "ring": ring,
					"corner": cr,
					"ref": {"name": m["name"], "kind": m["kind"], "id": m["id"]}})


func _on_tip_draw() -> void:
	# ① 每个可悬浮的名字画一条淡金细线 —— 这是「这里能悬浮」的唯一提示
	#    （不悬停 34% 不透明，不喧宾夺主；悬停时点亮）。
	var dfont: Font = desc.get_theme_font("font")
	var dfs: int = desc.get_theme_font_size("font_size")
	var mcol := Mention.text_color(Color("cfcabb"))
	for h: Dictionary in _ref_hits:
		var rr: Rect2 = h["rect"]
		var hot := _same_ref(h["ref"], _hover_ref)
		# R168（用户口径）：提到的名字**本身要有颜色** —— Label 已经画过正文，
		# 这里在**同一位置**盖一层淡底 + 用强调色重画名字（几何取自命中表，像素级对齐）。
		_tip_layer.draw_rect(Rect2(rr.position.x, rr.position.y + 1.0,
				rr.size.x, rr.size.y - 2.0),
				Color(mcol.r, mcol.g, mcol.b, 0.34 if hot else 0.18), true)
		if dfont != null:
			_tip_layer.draw_string(dfont,
					Vector2(rr.position.x, rr.position.y + dfont.get_ascent(dfs)),
					str(h["ref"]["token"]), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, mcol)
		var col := UiTheme.ACCENT_GOLD
		col.a = 0.9 if hot else 0.5
		_tip_layer.draw_line(Vector2(rr.position.x, rr.end.y - 1.0),
				Vector2(rr.end.x, rr.end.y - 1.0), col, 1.0)
	for hb: Dictionary in _ref_btn_hits:
		# 环色**按按钮底色取**（事件页的选项是浅色胶囊，金色环在上面根本看不出来）；
		# 形状跟着按钮的圆角走 —— 矩形环套在胶囊上很毛糙（实测出图看得出来）。
		var g: Color = hb.get("ring", UiTheme.ACCENT_GOLD)
		g.a = 0.95 if _same_ref(hb["ref"], _hover_ref) else 0.45
		var ob := StyleBoxFlat.new()
		ob.draw_center = false
		ob.border_color = g
		ob.set_border_width_all(2)
		ob.set_corner_radius_all(int(hb.get("corner", 0)))
		_tip_layer.draw_style_box(ob, (hb["rect"] as Rect2).grow(2.0))
	# ② 悬停提示面板
	if _hover_ref.is_empty():
		return
	if _hover_ref["kind"] == "relic":
		_draw_relic_tip()
	else:
		_draw_card_tip()


func _tip_place(pw: float, ph: float) -> Rect2:
	## 面板贴**描述框的两侧**，不跟着鼠标走 ——
	## 要悬浮的名字本身就在描述文字里，贴着鼠标画会正好压住玩家正在读的那一段。
	## 优先右侧；右边放不下换左边；两边都放不下才贴窗口右缘（宁可轻微压字，
	## 也不能让面板跑出屏幕）。纵向跟随名字所在行，并夹进窗口。
	## ⚠️ 参考矩形必须是 `desc` 的**实际**矩形，不能假设它只有 460 宽 ——
	##    文案长于中间那一列时 Label 会溢出（「绝赞五换一」第一行就有 750 宽）。
	var vp := get_viewport_rect().size
	var box := desc.get_global_rect()
	var x: float = box.end.x + 10.0
	if x + pw > vp.x - 8.0:
		x = box.position.x - pw - 10.0
	if x < 8.0:
		x = vp.x - pw - 12.0
	x = clampf(x, 8.0, maxf(8.0, vp.x - pw - 8.0))
	var y := clampf(_tip_anchor.y - ph * 0.5, 60.0, maxf(60.0, vp.y - ph - 10.0))
	return Rect2(Vector2(x, y), Vector2(pw, ph))


func _tip_frame(r: Rect2) -> void:
	_tip_layer.draw_rect(r, Color(0.10, 0.11, 0.15, 0.96), true)
	_tip_layer.draw_rect(r, UiTheme.ACCENT_GOLD, false, 1.4)


func _draw_card_tip() -> void:
	## 卡牌 → **真实卡面**（与图鉴 / 战场同一套 CardFace，所见即所得）。
	## R168：改用共享的 `Mention.draw_tip()`（全工程同一套悬浮件），并把这**张卡的文案里
	## 提到的其它卡 / 道具**的摘要一并附在卡面下方 —— 看一张卡就能顺带看到它提到的卡。
	var card: CardData = CardRepo.load_json().get_card(int(_hover_ref["id"]))
	if card == null:
		return
	var sz := Mention.tip_size(_font, _hover_ref)
	var bh := Mention.block_height(_font, _font_bold, card.effect_text, sz.x - Mention.PAD * 2.0)
	var frame := _tip_place(sz.x, sz.y + bh)
	Mention.draw_tip(_tip_layer, _font, _font_bold, _hover_ref, frame.position, bh,
			card.effect_text)


func _draw_relic_tip() -> void:
	## 道具 → 名称 + 「类型 · 来源」+ 完整说明。R168：改用共享的 `Mention.draw_tip()`，
	## 并把说明里提到的卡 / 道具摘要附在下方（一个边框框住）。
	var rel: RelicData = RelicRepo.load_json().get_relic(int(_hover_ref["id"]))
	if rel == null:
		return
	var sz := Mention.tip_size(_font, _hover_ref)
	var bh := Mention.block_height(_font, _font_bold, rel.desc, sz.x - Mention.PAD * 2.0)
	var frame := _tip_place(sz.x, sz.y + bh)
	Mention.draw_tip(_tip_layer, _font, _font_bold, _hover_ref, frame.position, bh,
			rel.desc)
