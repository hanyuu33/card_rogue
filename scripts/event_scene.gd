extends Control
## 事件界面（肉鸽版）—— 由地图节点类型 / 事件子类型决定：
##   * rest  休息处：恢复 25% 最大生命（向上取整，不超过上限）；
##            另有「烤肉」选项：获得事件道具「烤肉」（进入 Boss 战时自动消耗
##            并回复 25% 最大生命）。持有烤肉时不能再选，消耗后可再次烤制。
##   * event + treasure 小宝箱（R372）：**免费**打开 —— 直接给一组卡牌奖励（选 1 张入卡组）。
##     原来「支付 5 生命开箱 / 一半概率是道具」的口径已作废：不扣生命、内容恒为卡牌；
##   * event + whisper  鸭鸭低语：获得事件道具「鸭之低语」，或放弃；
##   * event + struggle 挣扎：失去 21 点生命，将一张「金属龙」加入卡组，或离开；
##   * event + gaze     鸭之凝视：获得事件道具「一袋米抗几楼」，或放弃；
##   * event + pear     鸭梨山大（第二层专属）：获得事件道具「鸭梨」，或放弃；
##   * event + apple_doctor 苹果与医生（R244，第二层专属）：收下道具「苹果」，或放弃并离开；
##   * R573：蓝色大肥鱼（bluefish）事件已删除，旧存档只剩「已移除」兜底页；
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
##   事件 = rest / treasure / whisper / struggle / gaze / pear / apple_doctor /
##          moon（R351 赏月）/ relic_chest / flyer（R555 飞行器）。
## 缺图时回退内置绘制（所有事件共用的篝火动画 / 深灰底色）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const WHISPER_ID := 6010
const RICE_ID := 6012             # 一袋米抗几楼（鸭之凝视事件道具）
const PEAR_ID := 6019             # 鸭梨（鸭梨山大事件道具）
const APPLE_ID := 6027            # 苹果（R244「苹果与医生」事件道具；原奖励道具）
const PIPE_ID := 6055              # 烟斗（R446「雪豹出现」选项 1：首回合 +1 费 / 多抽 1 / 失去 1 HP）
const ADVENTURER_NOTE_ID := 6056   # 冒险笔记（R447「冒险家的遗物」选项 1：随机未探索房 → 大宝箱）
const ADVENTURER_FLINT_ID := 6057  # 燧石（R447「冒险家的遗物」选项 2；R448 起全图任选一格 → 退成篝火）
const SNOW_LEOPARD_CARD_ID := 8081  # 雪豹（R446「雪豹出现」选项 2 的奖励卡）
const HERO_CARD_ID := 9023        # 英雄（绝赞五换一的奖励卡）
const HERO_TRADE_NEED := 5        # 绝赞五换一：要交出 5 张**不同名**的卡
const STRUGGLE_CARD_ID := 9018    # 金属龙（事件卡牌，不可奖励获取）
const STRUGGLE_LIFE := 21         # 挣扎代价：失去的生命
const WHALE_CARD_ID := 9050       # 鲸鱼之怒（占卜室幻象「鲸鱼」的解读奖励，不可奖励获取）
const ARCANE_CHARM_ID := 6020     # 奥秘护符（奥秘之泉事件给予；奖励池也能正常获得）
const CARGO_CARD_ID := 8065       # 货物（R200 运送委托；3 费工事 0/6/0/0，被破坏时从卡组删除）
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
获得「一袋米抗几楼」：每回合第一次我方生命受到伤害后，抽 1 张卡，
且本回合内你的技能（法术）造成的伤害 +1。
也可以别过头去，假装没看见。"""

const GAZE_TAKEN_DESC := """那只眼睛还在看着你。
米袋沉甸甸地压在肩头——被注视的感觉，从此挥之不去。"""

const PEAR_DESC := """不知从哪儿滚来一堆鸭梨，一颗一颗，把你压得喘不过气。
压力，也是一种力量——只要你还扛得住。
获得「鸭梨」：此后每次你的生命受到伤害，最大生命 +1（只提高上限，不回复生命）。
也可以把梨推开，假装自己毫无压力。"""

const PEAR_TAKEN_DESC := """肩上那座鸭梨山，你已经背起来了。
往后每一次受伤，都会让你更「强大」一点——
只是那点强大，补不回已经失去的血。"""

const APPLE_DESC := """路边坐着一位医生，膝上摊着一本病历，抬头看了你一眼：
「拿个苹果走吧。吃了它，就别再来找我。」
获得「苹果」：最大生命 +7，并回复满生命值。
也可以什么也不接，转身离开——只是路上别再回头。"""

const APPLE_TAKEN_DESC := """医生已经不在那儿了，连椅子都收走了。
手里那颗苹果沉甸甸的，还带着体温。"""

# R446 雪豹出现（第一层专属）：两个选项各给一样东西 —— 道具「烟斗」或卡「雪豹」。
const SNOW_DESC := """雪坡上蹲着一只雪豹，尾巴慢慢地扫着雪面。
它没走，也没让路——只是抬眼看你，像在等你说点什么。
把它劝走：得到道具「烟斗」；或者把芝士丢过去，它会跟你走。"""

const SNOW_CLOSED_DESC := """「闭嘴。」两个字压下去，雪豹喉咙里那声低吼就断了。
它盯了你一会儿，把一样东西丢在雪里，转身窜上了坡。"""

const SNOW_CHEESE_DESC := """芝士在它嘴边化开，雪豹低头吃完，
起身抖了抖身上的雪，跟在了你后面。"""

# R447 冒险家的遗物（第一层专属）：两个选项各给一件「即时」道具，效果都落在地图上。
const ADVENTURER_DESC := """石壁下靠着一具风干的行囊，主人早就离开了。
笔记摊在膝上，页角被雨水粘在一起；燧石和火镰还扣在扣环里，
看着像是刚放下不久。
遗物不挑人，但一次只拿得走一样。"""

const ADVENTURER_NOTE_DESC := """你把笔记从头翻到尾。
最后一页画着一张潦草的图，某处被圈了起来——
那个位置，好像真的多了一间你没去过的屋子。"""

const ADVENTURER_FLINT_DESC := """燧石落进掌心，还带着一点凉。
火镰擦过，火星跳起来，照亮了石壁上被烟熏黑的一片。"""

# R473 武术大师（第一、二层共用）：三个选项分别给三张**事件专属技能卡**（都不会进奖励池）。
#   ① 乱打 9215 —— 当场给：2 费，对随机 2 个敌人各 10 伤
#   ② 飞踢 9216 —— **2 场战斗后**自动到手：2 费，22 伤 + 击杀时溢出沿同列传递（践踏）
#   ③ 冲拳 9217 —— **2 场精英 / Boss 后**自动到手：2 费，16 伤 + 击退 1 格 + 其余各 8 伤
# ②③ 走 `RunState.queue_delayed_card()`（挂单跨战斗存活，进存档），到账时战斗结算弹 Toast。
const MARTIAL_BRAWL_ID := 9215
const MARTIAL_KICK_ID := 9216
const MARTIAL_PUNCH_ID := 9217
const MARTIAL_KICK_BATTLES := 2
const MARTIAL_PUNCH_BATTLES := 2

## ⚠️ 这里最多铺 3 个选项 + 1 个「离开」，描述**必须压到 2 行**
##（与熔炉 R454 同一条教训：描写一长，`_fit_center()` 收紧间距也救不回来，末按钮会被切）。
const MARTIAL_DESC := """树底下坐着一位老人，木棍横在膝上，衣襟落满了叶子。
「学点东西再走吧——简单的现在带走，真本事得拿胜利来换。」"""

const MARTIAL_BRAWL_DESC := """老人把木棍往地上一顿：「乱打不难，难的是不要停下来。」
他替你摆了两下手腕，你就记住了——
「乱打」：2 费，对随机 2 个敌人各造成 10 点伤害。"""

const MARTIAL_KICK_DESC := """「腿比手长，也比你诚实。」
老人示范了一记，鞋跟落地，尘土正正好好地散开——
「去打两场。回来我把后半段教给你。」
「飞踢」（2 场战斗后到手）：2 费，22 伤；击杀时溢出的伤害沿同一列继续。"""

const MARTIAL_PUNCH_DESC := """老人往石头上捶了一下，石头裂了，他的手没有。
「这一拳不难学，难的是你配不配。去打两场硬的——精英，或者守着关底的那种。」
「冲拳」（2 场精英 / Boss 后到手）：2 费，16 伤 + 击退 1 格，其余敌人各 8 伤。"""

# R555 飞行器（第二层专属）：两个选项 —— 使用飞行器（回地图选一格没去过的房间传过去，
# 消耗 1 巧克力）/ 不移动。R574（用户口径）：巧克力不足 2 块时**遇不到**这个事件
# （过滤在进房入口 `RunState.resolve_event_kind`），所以这里不再有「禁用」按钮。
const FLYER_DESC := """空地中央立着一架旧喷气背包，两只喷口还留着一点余温。
背上它，你能直接飞到任何一个还没去过的房间——
代价是 1 块巧克力。"""

# 只服务旧存档 / `--flyer` 演示：正常流程进不来，也不摆一个灰掉的按钮。
const FLYER_NO_FUEL_DESC := """喷口凉着，背包沉沉地立在那里，像是早就算准了你今天带的巧克力不够。
你拍了拍它，转身继续赶路。"""

const FLYER_TAKEN_DESC := """喷口已经热起来了，暖橙色的火苗轻轻跳着。
回到地图后挑一个没去过的房间，它就把你送过去。"""

# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。
const RETIRED_EVENT_DESC := """这里原本有一条蓝色大肥鱼。它已经游走了。"""

# R351 赏月（第二层专属事件）产出的两张效果卡。都带 `no_remove`（不可从卡组删除）。
const MOON_CARD_ID := 9180
const COIN_CARD_ID := 9181

const MOON_DESC := """天色暗下来，月亮低低地挂在山脊上，把水面照成一条银路。
石台上摆着两样东西，都泛着不属于这里的光——
「月亮」：3 费效果。战斗结束后奖励界面多一条「删除一张卡」。
此卡不可以从卡组删除。
「硬币」：2 费效果。战斗结束后额外获得 40 金币。此卡不可以从卡组删除。
月亮的代价是此刻的全部金币；硬币什么都不要。两样必须拿走一样。"""

const MOON_TAKEN_DESC := """月亮落进你的口袋，钱袋却空了。
它凉得很，像刚从水里捞上来。"""

const COIN_TAKEN_DESC := """硬币贴着掌心，凉的。
远处传来一声很轻的、像是叹气的水响。"""

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
选择承运：平铺挑 1~6 张「货物」加入卡组（3 费工事，0 攻 / 6 血，替你承受伤害）；
货物被破坏时会从卡组中删除——毁了就真的毁了。
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

const CAVE_DESC := """山壁上裂着一道口子，风从深处吹出来，带着兽类的臊味。

地上有什么很沉的东西压出的爪印，一直通向黑暗里。"""
const CAVE_TAKEN_DESC := """洞口的爪子印被新的压住了——里面那只醒了。"""
const MERCHANT_DESC := """「旧牌换新牌，五费换宝箱，贱卖也收。」
摊主把三张牌在桌面上翻来翻去，帽檐下只看得见半张笑。

他脚边立着一只落了锁的大箱子，锁孔里透出一点金光。"""

const MERCHANT_DONE_DESC := """摊主把那张牌收进袖子里，冲你抬了抬下巴。

「成交。下回还来。」"""

const DIVINATION_DESC := """屋里只点着一支蜡烛，水晶球里浮着一层不肯散去的雾。

「看得到什么，全看你相信什么。」

占卜师收完钱就不见了，只留下这颗球，和一阵檀香。"""

const DIVINATION_DONE_DESC := """水晶球重新蒙上雾，好像什么都没发生过。"""

const DIV_WHALE_DESC := """雾散开一角，一条鲸鱼在星光里缓缓转身，尾鳍扫过整片海。

你觉得——"""

const DIV_LIQUID_DESC := """球里盛着一杯液体，杯沿结着薄霜，颜色在灯下慢慢变。

你觉得——"""

const DIV_THORN_DESC := """球里长出一片荆棘，尖刺密密麻麻缠成一条路。

你觉得——"""

const DIV_FEAST_DESC := """球里摆开一桌佳肴，热气还在往上飘，却听不见一点人声。

你觉得——"""

const DIVINATION_KINDS := 4

const LAKE_DESC := """雾从水面浮起来，两张卡牌悬在雾的上方——
一张泛着银光，一张泛着金光，慢慢转过来。这是你丢的吗？

「说个谎吧，我替你扔掉一件旧东西。
或者说句实话，我送你一件礼物。」"""

const LAKE_DONE_DESC := """水面合拢，雾气散得干干净净。牌角上那点温度还留着。"""

## R454：熔炉的描述必须**压到 2 行**——它最多铺 3 个选项 + 1 个「离开」，
## 比别的事件多一个按钮；描述一长，`_fit_center()` 收紧间距也救不回来，
## 最后一个按钮会被屏幕下沿切掉（实测 5 行描述就切了）。
const FURNACE_DESC := """炉膛里的火没有颜色，只有形状——东西投进去，会变成别的东西出来。
投一件道具进去，炉子还你一件随机道具；投的是传奇档，就还你两件。"""
const FURNACE_DONE_DESC := """炉火暗下去一瞬，又慢慢亮起来。石台边缘还留着一点余温——这次交易已经做完了。"""

## R458「契约的核心」（第二层专属）：两个选项各给一件**事件道具**，都不当场兑现 ——
##   选项 1 订立契约 → 道具「咒缚」（每场战斗第一张卡 -3 费 / 那张卡本场 +1 费）
##   选项 2 获取核心 → 道具「核心」（战斗中累计失去 15 点生命后成形，
##                          这一场结束的**奖励页**里可以兑换一次：献祭一张伤害技能牌，
##                          把它的第一段伤害变成另一张的附魔；用掉即失效）
## ⚠️ 选项 2 **不在事件里选卡**（用户口径：「忘记给核心添加触发条件了」）——
##    选卡与落账都挪到 `RewardPanel` 的 VIEW_CORE（那次兑换才是它的兑现口）。
## 描述同样压到 2 行：它铺满「选项 1 / 选项 2 / 离开」三个按钮，一长就把最后一个
## 挤出屏幕（与熔炉同一条教训，见 `_fit_center()`）。
const CORE_CURSE_ID := 6058       # 咒缚（选项 1 的事件道具）
const CORE_DESC := """石台正中嵌着一枚还在轻轻跳动的核心，四周绕着几根细链。
左侧摊着一份没落款的契约，纸面干净，笔就压在边上。"""
const CORE_CONTRACT_DESC := """链子松开了一圈。纸面上多了一行字，是你的名字。"""
const CORE_TAKEN_DESC := """石台上只剩一圈浅浅的凹痕，核心已经不在了。"""


func _rest_desc() -> String:
	## 休息处文案（R237：恢复篝火回血 —— 休息与烤肉二选一）。
	## R307 圣餐（6038）：持有它时休息直接回满，文案要跟着改（不然按钮说回 5 实际回满）。
	if RunState.has_relic(RunState.RELIC_SACRAMENT_ID):
		# R473（用户口径）：圣餐改成「到达篝火处回复 50% 最大生命」，进房就结算掉了。
		return """篝火旁摆着一份还没凉透的圣餐。
你在坐下之前就把它分掉了——到达篝火处回复 50% 最大生命（已结算）；
也可以烤一块肉带在身上，留到 Boss 战前享用；
还可以往火里添一根柴，让火替你烧掉卡组里的一张牌。
（剩下两样只能挑一样——选完这一处就到头了。）"""
	return """前路的战斗还在等着你。
在篝火旁休息，恢复 %d%% 最大生命；
也可以烤一块肉带在身上，留到 Boss 战前享用；
还可以往火里添一根柴，让火替你烧掉卡组里的一张牌。
（三样只能挑一样——选完这一处就到头了。）""" % int(round(RunState.rest_pct() * 100.0))

var _font: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var _whisper_taken := false   # 鸭鸭低语：是否已收下道具
var _gaze_taken := false      # 鸭之凝视：是否已收下道具
var _pear_taken := false      # 鸭梨山大：是否已收下道具
var _apple_taken := false     # 苹果与医生（R244）：本次是否已收下「苹果」
var _snow_pick := ""           # 雪豹出现（R446）：本次拿走的是 "pipe" / "cat" / 空
var _adv_pick := ""            # 冒险家的遗物（R447）：本次拿走的是 "note" / "flint" / 空
var _adv_result := ""          # 冒险家的遗物（R447）：收尾态那行结果（读档重绘要能复现）
var _martial_pick := ""         # 武术大师（R473）：本次选的是 "brawl" / "kick" / "punch" / ""
var _martial_result := ""       # 武术大师（R473）：收尾态那行结果（重绘要能复现）
var _fly_done := false          # R555 飞行器：本次是否已选了「使用飞行器」（等回地图选格）
var _fly_result := ""           # R555 飞行器：收尾态那行结果（重绘要能复现）
var _furnace_opts: Array[int] = []   # 熔炉（R454）：本次铺出来的可投入道具（_ready 里摇一次）
var _furnace_invested := -1          # 熔炉（R454）：本次投进去的那件（-1 = 还没投）
var _furnace_result := ""            # 熔炉（R454）：收尾态那行结果（重绘要能复现）
var _core_pick := ""                 # 契约的核心（R458）：拿走的是 "contract" / "core" / ""
var _core_result := ""               # 契约的核心（R458）：收尾态那行结果（重绘要能复现）
## R351 赏月：本次拿走的是 "moon"（花光金币换月亮）/ "coin"（直接拿硬币）/ ""（还没拿）。
## 两个选项**互斥**，拿了一个另一个就收起 —— 走 `_claim_reward()` 那条统一规则。
var _moon_pick := ""
var _chest_opened := false    # 宝箱层：是否已开箱
var _chest_relic := -1        # 宝箱层：开出的道具 id（-1 = 未开 / 已无货）
var _struggled := false       # 挣扎：是否已接受（失去生命换金属龙）
var _hero_traded := false     # 绝赞五换一：是否已交易（删 5 张换英雄）
var _hero_removed: Array = [] # 绝赞五换一：本次被换走的卡（[{id,name}]）
var _bbq_taken := false       # 烤肉：本次是否已在休息处烤好（获得道具）
var _sacrament_note := -1    # R473 圣餐：本次进休息处回了多少（-1 = 还没试过）
var _arcane_charm_taken := false  # 奥秘之泉：**本次访问**是否取走了道具「奥秘护符」
                              #   （≠「本来就戴着」—— 后者只是不重复给，不影响喝泉水，见 R71 / R147）
var _arcane_drunk := false    # 奥秘之泉：是否已选择「喝下泉水」（选卡去了卡牌奖励界面）
var _reward_claimed := false  # R147：本次事件访问是否已领过奖励（一次访问只领一份，见 _claim_reward）
var _oblivion_done := false   # 遗忘之泉：是否已经遗忘过一张卡（或已选择去删卡）
var _smith_done := false      # 鸭鸭工匠：是否已经锻造过（或已选择去锻造）
var _div_stage := 0           # R308 占卜室：0 = 还没占卜 / 1 = 已占卜待解读 / 2 = 已解读完
var _div_rolled := 0          # R308 占卜室：本次占卜出的是第几种幻象（1~4）
var _div_result := ""         # R308 占卜室：解读后的结果行（收尾态复用）
var _orb_vision: TextureRect = null   # R511 占卜室：球内幻象层
var _orb_glass: TextureRect = null    # R511 占卜室：球壳高光层（ADD 混合）
var _merchant_done := false   # R305 卡片商人：是否已经做过一笔交易
var _lake_done := false       # R305 湖中仙女：是否已经许过愿
## R488：湖中仙女 · 谎言**进门就摇定**的那一张（`RunState.lake_lady_peek()` 的结果）。
## 存在场景变量里只是为了按钮铺排与悬浮绑实例；真身是 `RunState.lake_victim`（随存档）。
var _lake_pick := {}
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
## R305：**第三选项**按钮（卡片商人）。原来只有「主选项 / 第二选项 / 离开」三个位置，
## 三选一事件需要第四个按钮。默认 hidden，只有卡片商人在 `_ready` 里打开。
@onready var alt_btn: Button = $Center/AltBtn
@onready var leave_btn: Button = $Center/LeaveBtn
@onready var result_label: Label = $Center/ResultLabel


func _is_event_node() -> bool:
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "event"


func _is_chest_layer() -> bool:
	## 宝箱层（第六层）：地图节点类型为 chest，整层都是宝箱。
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "chest"


func _is_rest() -> bool:
	## 休息处（篝火）：地图节点 type == "rest"（不是 event 房）。
	return RunState.run_active and str(RunState.pending_node.get("type", "")) == "rest"


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


func _is_whisper() -> bool:
	return _is_event_node() and _pending_kind() == "whisper"


func _is_gaze() -> bool:
	return _is_event_node() and _pending_kind() == "gaze"


func _is_pear() -> bool:
	## 鸭梨山大（第二层专属事件）：获得事件道具「鸭梨」。
	return _is_event_node() and _pending_kind() == "pear"


func _is_apple() -> bool:
	## 苹果与医生（R244，第二层专属事件）：收下事件道具「苹果」（+14 最大生命并回满）。
	return _is_event_node() and _pending_kind() == "apple_doctor"


func _is_snow_leopard() -> bool:
	## 雪豹出现（R446，第一层专属）：两个选项 —— 道具「烟斗」或卡「雪豹」。
	## 两样都拿得到东西，所以没有「什么都不拿」（第三选项当「投喂芝士」用）。
	return _is_event_node() and _pending_kind() == "snow_leopard"


func _is_adventurer() -> bool:
	## 冒险家的遗物（R447，第一层专属）：两个选项 —— 道具「冒险笔记」或「燧石」。
	## 两样都拿得到东西，所以没有「什么都不拿」（同「雪豹出现」的收法）。
	return _is_event_node() and _pending_kind() == "adventurer"


func _is_martial() -> bool:
	## 武术大师（R473，第一 / 二层共用）：三选一 —— 乱打（当场）/ 飞踢（2 场战斗后）/
	## 冲拳（2 场精英或者 Boss 后）。后两张是**挂单**，不占道具栏，到账时自动进卡组。
	return _is_event_node() and _pending_kind() == "martial"


func _is_flyer() -> bool:
	## R555 飞行器（第二层专属）：使用飞行器（回地图选一格没去过的房间传送过去）
	## / 不移动。R574：巧克力不足 2 块时进房前就被替换掉，这里遇不到。
	return _is_event_node() and _pending_kind() == "flyer"


func _is_cave() -> bool:
	## R467 洞穴（第二层专属）：两个选项 —— 探索（打一场，赢了拿传说卡）／离开。
	## ⚠️ 这是**唯一一个会进战斗的事件房**（R128 之后事件房本来不再遭遇战斗）：
	##    选项 1 直接把本页换成「洞穴」这一关（`GameLevels.cave_level()`）。
	return _is_event_node() and _pending_kind() == "cave"


func _is_bluefish() -> bool:
	## R573 已下线：只用来认出旧存档 / 脏数据里的 bluefish，
	## 让它走「已移除」兜底页，而不是落进 _is_treasure() 误开宝箱发奖励。
	return _is_event_node() and _pending_kind() == "bluefish"


func _is_moon() -> bool:
	## R351 赏月（第二层专属）：失去全部金币换「月亮」，或直接拿「硬币」。
	return _is_event_node() and _pending_kind() == "moon"


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


func _is_card_merchant() -> bool:
	## R305 卡片商人（第二层专属）：换卡 / 5 费卡换大宝箱 / 随机折价。
	return _is_event_node() and _pending_kind() == "card_merchant"


func _is_lake_lady() -> bool:
	## R305 湖中仙女（第一层专属）：谎言删一张初始卡 / 诚实得随机史诗卡。
	return _is_event_node() and _pending_kind() == "lake_lady"


func _is_divination() -> bool:
	## R308 占卜室（第一 / 第二层）：占卜 → 随机幻象 → 两个解读，各给一张卡或一件道具。
	return _is_event_node() and _pending_kind() == "divination"


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


func _is_furnace() -> bool:
	## R454 熔炉（第二层专属）：投一件身上的道具 → 换回随机道具（传奇档换两件）。
	## 选项是**动态数量**（0~3 个），不像别的事件那样固定两个。
	return _is_event_node() and _pending_kind() == "furnace"


func _is_core_contract() -> bool:
	## R458 契约的核心（第二层专属）：签契约换道具「咒缚」/ 取核心献祭一张伤害技能牌。
	return _is_event_node() and _pending_kind() == "core_contract"


func _is_treasure() -> bool:
	## 小宝箱（R372：**免费**开箱，内容恒为一组卡牌奖励）：事件节点中未被其它子类型认领的情况。
	return _is_event_node() and not _is_whisper() and not _is_struggle() \
			and not _is_gaze() and not _is_pear() and not _is_hero() \
			and not _is_bluefish() and not _is_apple() and not _is_relic_chest() \
			and not _is_arcane() and not _is_oblivion() and not _is_smith() \
			and not _is_delivery() and not _is_delivery_done() \
			and not _is_card_merchant() and not _is_lake_lady() \
			and not _is_divination() and not _is_moon() and not _is_snow_leopard() \
			and not _is_adventurer() and not _is_furnace() and not _is_core_contract() \
			and not _is_flyer()


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
	if _is_apple():
		return "apple_doctor"
	if _is_snow_leopard():
		return "snow_leopard"
	if _is_adventurer():
		return "adventurer"
	if _is_cave():
		return "cave"
	if _is_furnace():
		return "furnace"
	if _is_core_contract():
		return "core_contract"
	if _is_hero():
		return "hero"
	if _is_arcane():
		return "arcane"
	if _is_oblivion():
		return "oblivion"
	if _is_smith():
		return "smith"
	if _is_card_merchant():
		return "card_merchant"
	if _is_lake_lady():
		return "lake_lady"
	if _is_divination():
		return "divination"
	if _is_bluefish():
		return "bluefish"
	if _is_moon():
		return "moon"
	if _is_delivery():
		return "delivery"
	if _is_delivery_done():
		return "delivery_done"
	if _is_struggle():
		return "struggle"
	# R512 修 bug：R473 加「武术大师」时漏了这里 —— 落进末尾 return "rest"，
	# 于是武术大师的房间会点亮休息处的篝火、铺休息处的空地背景。
	if _is_martial():
		return "martial"
	if _is_flyer():
		return "flyer"
	if _is_treasure():
		return "treasure"
	return "rest"


## ---- R516/R518：左右布局 -----------------------------------------------------
## 图片占满整个左侧（全高），文字与按钮落在右侧、**不套信息卡框**。
## 图片右缘不做硬切：用内联 shader 按 UV.x 把颜色推向页面底色、再收 alpha，
## 所以**渐变不依赖图片本身** —— 换一张同尺寸的图不用重做边、也不用把渐变烘进 PNG。
##
## R518：**接缝位置不再写死**。R516 的 `SIDE_SPLIT = 0.58` 是个常数，文案一变长
## 就只能靠缩字号硬塞。现在反过来算：先量文案实际需要的宽度（标题 / 正文最长行 /
## 每个按钮的文字＋内距），右栏取这个宽度的 clamp 值，剩下的全给图片。
## 文字再长也不会挤掉图 —— 撞到上限时 `desc` 自动折行（本布局里开了 autowrap）。
## R519g：`martial` 加入 —— 它的主体（盘坐的老人）只能在地面中段，
## 而居中卡片正好压在那里，无论怎么调背景都会被盖住。改成左右布局后
## 老人独占左栏、完整可见，文案走右栏。
## R519j：`apple_doctor` 加入 —— 木桌上的苹果独占左栏，事件描述与选项走右栏。
const SIDE_LAYOUT_KINDS := ["lake_lady", "martial", "rest", "apple_doctor"]
const SIDE_SPLIT_MIN := 0.40      ## 图片最窄占比（文案再长也给图留这么多）
const SIDE_SPLIT_MAX := 0.62      ## 图片最宽占比（文案很短时图也别宽到没边）
const SIDE_TEXT_MIN_W := 300.0    ## 右栏最小宽度
const SIDE_TEXT_MAX_RATIO := 0.46 ## 右栏最多占屏宽
const SIDE_GAP := 44.0            ## 接缝到文字的间距
const SIDE_PAD_R := 52.0          ## 文字块右侧留白
const SIDE_FADE_RGB := 0.62       ## 从这一列开始把**颜色**推向背景色（压掉亮块）
const SIDE_FADE_ALPHA := 0.74     ## 从这一列开始收 alpha（颜色已一致，只求边界绝对无缝）

## ---- R518：居中布局的宽度 ----------------------------------------------------
## 原来 `Center` 的宽度是写死的 ±230（460）。它只够放中等长度的文案，长一点就
## 只剩「缩字号」一条路（奥秘之泉那行 25 字就是这么被压小的）。现在同侧栏一样
## 先量后定：`CENTER_MIN_W` 保底不改变现有观感，超了才加宽，顶到 `CENTER_MAX_W`
## 才让按钮回到缩字号逻辑。
const CENTER_MIN_W := 460.0
const CENTER_MAX_W := 760.0
const CENTER_EDGE := 120.0        ## 居中布局左右至少留出的空白
const CENTER_CARD_PAD := 24.0     ## 文字两侧在卡片内的呼吸位（每边）

var _side_layout := false
var _side_pic: TextureRect = null
var _side_split := -1.0           ## 当前接缝（比例）；用于「算出来没变就别动」的回环刹车
var _center_w := -1.0             ## 当前中间一列的宽度（同上）
var _relayout_queued := false


func _line_width(text: String, f: Font, fs: int) -> float:
	## 一段可能含 \n 的文字里最长那一行的像素宽（不含自动折行 —— 折行是结果，不是需求）。
	if f == null or fs <= 0:
		return 0.0
	var w := 0.0
	for line in text.split("\n"):
		if line.strip_edges().is_empty():
			continue
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w


func _label_natural_width(lbl: Label) -> float:
	if lbl == null:
		return 0.0
	var f := lbl.get_theme_font("font")
	if f == null:
		f = _font
	return _line_width(lbl.text, f, lbl.get_theme_font_size("font_size"))


func _button_natural_width(b: Button) -> float:
	## 按钮要的宽度 ＝ 文案宽 + 左右内距（从它自己的 stylebox 里读，不写死 68）。
	##
	## ⚠️ 字号**必须按基础档 FS_SUBHEAD 量**，不能读按钮当前字号：
	## 当前字号本身就是「按宽度缩过」的产物，拿它当输入会形成
	## 宽度 → 字号 → 宽度 的追逐（越量越窄、字越缩越小）。
	var sb := b.get_theme_stylebox("normal")
	var pad := 68.0
	if sb != null:
		pad = sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)
	var f := b.get_theme_font("font")
	if f == null:
		f = _font
	return _line_width(b.text, f, UiTheme.FS_SUBHEAD) + pad + 8.0


func _content_natural_width() -> float:
	## 整块内容（标题 / 正文 / 结果行 / 可见的按钮）里最宽的那一条 —— 窄于它就只能缩字。
	var w := _label_natural_width(event_name)
	w = maxf(w, _label_natural_width(desc))
	# 结果行常比正文长（「冒险笔记…回到地图时会看见那格亮着金光。」这类），
	# 原来不参与测宽，长的时候会直接顶出卡片；现在一起算，超上限还有 autowrap 兜底。
	if not result_label.text.is_empty():
		w = maxf(w, _label_natural_width(result_label))
	for b: Button in [rest_btn, bbq_btn, alt_btn, leave_btn]:
		if b.visible and not b.text.is_empty():
			w = maxf(w, _button_natural_width(b))
	return w


func _apply_side_metrics() -> void:
	## 按文案反推接缝：右栏宽度 = clamp(文案自然宽, MIN, min(屏宽×0.46, 屏宽×(1-图最窄)))。
	var w := size.x
	if w <= 1.0:
		return
	var need := _content_natural_width()
	var max_col := minf(w * SIDE_TEXT_MAX_RATIO, w * (1.0 - SIDE_SPLIT_MIN))
	var col := clampf(need, SIDE_TEXT_MIN_W, maxf(SIDE_TEXT_MIN_W, max_col))
	var split := clampf(1.0 - (col + SIDE_GAP + SIDE_PAD_R) / w, SIDE_SPLIT_MIN, SIDE_SPLIT_MAX)
	if absf(split - _side_split) < 0.002:
		return   # 没变化就别再动 —— 顺手掐断「布局 → 信号 → 布局」的回环
	_side_split = split
	if _side_pic != null:
		_side_pic.anchor_right = split
	var c := $Center as VBoxContainer
	c.anchor_left = split
	c.offset_left = SIDE_GAP
	c.offset_right = -SIDE_PAD_R


func _apply_center_width() -> void:
	## 居中布局的宽度同理：保底 `CENTER_MIN_W`（现有观感不变），长了才加宽。
	var w := size.x
	if w <= 1.0:
		return
	var need := _content_natural_width() + CENTER_CARD_PAD * 2.0
	var max_w := maxf(CENTER_MIN_W, minf(CENTER_MAX_W, w - CENTER_EDGE))
	var col := clampf(need, CENTER_MIN_W, max_w)
	if absf(col - _center_w) < 0.5:
		return
	_center_w = col
	var c := $Center as VBoxContainer
	# ⚠️ 锚点在 0.5（屏幕中心），offset 是**相对这个锚点**的，不是相对左边。
	# 所以左右各取 ±col/2 —— R518 第一版把左边算成 `屏宽×0.5 - col/2`，
	# 卡片被整体推到屏幕右半之外（奥秘之泉直接右半张飞出去）。
	c.offset_left = -col * 0.5
	c.offset_right = col * 0.5


func _queue_relayout() -> void:
	## 文案/字号/窗口尺寸变了都要重算一次宽度。合并成一帧一次，避免连环重排。
	if _relayout_queued or not is_inside_tree():
		return
	_relayout_queued = true
	call_deferred("_flush_relayout")


func _flush_relayout() -> void:
	_relayout_queued = false
	if not is_inside_tree():
		return
	if _side_layout:
		_apply_side_metrics()
		call_deferred("_recenter_side_text")
	else:
		_apply_center_width()
		_fit_center()


func _side_fade_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

// R517：右缘过渡 = **颜色**先向背景色收敛，最后才收 alpha。
//
// R516 只淡 alpha、不动 RGB，结果图里那块亮色（AI 出图时顺手加的白柔光）
// 一路亮到边界才突然消失 —— 看上去就是「强行糊了一层白」。
// 先把 RGB 拉向页面底色（上冷下暖的那两道暗紫），亮块在中途就被吃掉；
// alpha 只在最后四分之一收尾，保证接缝绝对无缝。
// 底气色按 UV.y 与页面纵向渐变对齐 —— 所以渐变依旧不依赖图片本身，
// 换一张同尺寸的图进来，边会重新按这条曲线羽化。
uniform float fade_rgb_from : hint_range(0.0, 1.0) = 0.62;
uniform float fade_alpha_from : hint_range(0.0, 1.0) = 0.74;
uniform vec4 bg_top : source_color = vec4(0.078, 0.063, 0.125, 1.0);
uniform vec4 bg_bot : source_color = vec4(0.114, 0.086, 0.157, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float tr = smoothstep(fade_rgb_from, 1.0, UV.x);
	float ta = smoothstep(fade_alpha_from, 1.0, UV.x);
	vec3 bg = mix(bg_top.rgb, bg_bot.rgb, UV.y);
	COLOR = vec4(mix(c.rgb, bg, tr), c.a * (1.0 - ta));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("fade_rgb_from", SIDE_FADE_RGB)
	mat.set_shader_parameter("fade_alpha_from", SIDE_FADE_ALPHA)
	mat.set_shader_parameter("bg_top", UiTheme.NIGHT_BG_TOP)
	mat.set_shader_parameter("bg_bot", UiTheme.NIGHT_BG_BOT)
	return mat


func _apply_side_layout(kind: String) -> void:
	## 左右布局：左图右文。背景走暗紫渐变（没有整屏 CG —— 左图本身就是"背景"）。
	($Campfire as Control).visible = false
	_add_fallback_bg(kind)
	($BG as ColorRect).color = Color(0, 0, 0, 0)
	var pic := UiAssets.event_side_pic(kind)
	if pic != null:
		var tr := TextureRect.new()
		tr.name = "EventSidePic"
		tr.texture = pic
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # R512 的坑：不改会把 320×240 顶回原生尺寸
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.anchor_left = 0.0
		tr.anchor_top = 0.0
		tr.anchor_right = SIDE_SPLIT_MAX   # 先给个占位，真实位置由 `_apply_side_metrics()` 按文案算
		tr.anchor_bottom = 1.0
		tr.offset_left = 0.0
		tr.offset_top = 0.0
		tr.offset_right = 0.0
		tr.offset_bottom = 0.0
		tr.material = _side_fade_material()
		add_child(tr)
		# ⚠️ Control 的绘制顺序＝子节点顺序，**后面的画在上面**。
		# `_add_fallback_bg()` 把渐变层放在 index 1，所以图片必须紧贴它之上（index 2），
		# 否则那张暗紫渐变会整块盖住图（R516 踩过一次：图加载成功却一点都看不见）。
		var idx := 1
		if _fb_layer != null:
			idx = _fb_layer.get_index() + 1
		move_child(tr, idx)
		_side_pic = tr
	# 文字区搬到右侧：整块从接缝到右边缘，垂直居中
	var c := $Center as VBoxContainer
	c.anchor_left = SIDE_SPLIT_MAX   # 同上，占位；`_apply_side_metrics()` 会改
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	# ⚠️ 垂直锚点必须留 0：anchor_bottom=1.0 时 offset_bottom 是「相对底边的偏移」，
	# 下面按内容高度算出来的绝对 y 会被再加一个屏高（R516 踩过：容器被撑到 1038 高）。
	c.anchor_bottom = 0.0
	c.offset_left = SIDE_GAP
	c.offset_top = 0.0
	c.offset_right = -SIDE_PAD_R
	c.offset_bottom = 0.0
	c.alignment = BoxContainer.ALIGNMENT_CENTER   # 内容在右侧块里垂直居中
	# 不套框 → 标题与正文都左对齐，靠字号与颜色分层
	(event_name as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	(desc as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_side_metrics()
	# ⚠️ VBoxContainer.alignment 在这里不稳（内容高度由文案行数决定，容器先被撑满），
	# 改成布局结束后按**内容实际高度**把整块摆正中间。
	call_deferred("_recenter_side_text")


func _recenter_side_text() -> void:
	## 把右侧文字块按**实际渲染出来的子节点范围**摆到垂直正中。
	## 不能用 `get_combined_minimum_size()` —— 那个值在容器里偏大（R516 实测 664 vs 实际 ~250），
	## 算出来的 top 会被 `maxf` 下限吃掉，整块贴到顶栏底下。
	if not _side_layout:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var c := $Center as VBoxContainer
	if c == null:
		return
	var lo := INF
	var hi := -INF
	for n in c.get_children():
		var ctl := n as Control
		if ctl == null or not ctl.visible:
			continue
		var r := ctl.get_rect()
		if r.size.y <= 0.0:
			continue
		lo = minf(lo, r.position.y)
		hi = maxf(hi, r.end.y)
	if hi <= lo:
		return
	var block := hi - lo
	var delta := (size.y - block) * 0.5 - (c.position.y + lo)
	c.offset_top += delta
	c.offset_bottom += delta


func _apply_ui_assets() -> void:
	## 插图 / 背景：assets/ui/event_<kind>.png 与 bg_<kind>.png，缺图则回退内置绘制。
	##
	## R478 口径变更：
	##   1. 缺图不再只是「深灰底 + 篝火」——缺图时铺一层统一默认底（`_draw_fallback_bg`）。
	##   2. **篝火只留给休息处**。原来 24 种事件全都烧一堆篝火，「卡牌商人」「占卜」
	##      「遗忘之泉」里都有篝火，玩家一眼就看出是占位。篝火的本义是「可以休息」。
	var kind := _kind()
	_dark_page = _is_dark_page(kind)
	_apply_page_ink()
	# R516：左右布局自己管图与排版，不再走「居中插图 / 整屏背景」这套。
	_side_layout = SIDE_LAYOUT_KINDS.has(kind)
	if _side_layout:
		_apply_side_layout(kind)
		return
	var campfire: Control = $Campfire
	campfire.visible = (kind == "rest")
	var pic := UiAssets.event_pic(kind)
	if pic != null:
		campfire.visible = false   # 有自定义插图时不再叠内置篝火
		var tr := TextureRect.new()
		tr.name = "EventPic"
		tr.texture = pic
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# R512 修：默认 EXPAND_KEEP_SIZE 会把 size 改回贴图原生尺寸（素材是 2×，
		# 于是 320×240 的框被 640×480 顶掉 → 图位移且溢出），必须 IGNORE_SIZE。
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.anchor_left = 0.5
		tr.anchor_right = 0.5
		tr.offset_left = -160.0
		tr.offset_right = 160.0
		tr.offset_top = 116.0
		tr.offset_bottom = 356.0
		add_child(tr)
		# R512 修：add_child 是「加到最上层」—— 插图会盖住文案与选项按钮。
		# 和缺图兜底同一层（$BG 之上、篝火与正文之下）。
		move_child(tr, 1)
	var bg := UiAssets.event_bg(kind)
	if kind == "rest" and bg != null:
		campfire.visible = false
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
		_event_bg = trb
		_fit_event_bg()
		if not resized.is_connected(_fit_event_bg):
			resized.connect(_fit_event_bg)
		($BG as ColorRect).color = Color(0, 0, 0, 0)    # 让位给自定义背景
		# R511：占卜室 —— 球内景象单独一层（只换球里的内容，不换整张底图）
		if kind == "divination":
			_make_orb_layers(trb)
		# R512：契约的核心 —— 底图只画了石台与刻文，中央凹槽空着，核心另行叠
		if kind == "core_contract":
			_make_core_icon(trb)
	else:
		_add_fallback_bg(kind)


## ---- R511 占卜室：球内幻象 --------------------------------------------------
## 底图 `bg_divination.png` 在 1280×720 基准下，水晶球的球心 (639,188)、可见半径 89
## （由原图亮度剖面拟合，圆外发光不算在内）。玩法上球里要换四种画面
## （鲸鱼 / 液体 / 荆棘 / 宴席），但**不重画整张底图**：
##   · `div_vision_<1..4>.png`  球内景象，256×256 圆形羽化；
##   · `div_orb_glass.png`      球壳高光（从底图剥离），**ADD 混合**盖在幻象之上。
## 两层都套用 EventBG 的「等比铺满 + 居中裁切」同一套变换 → 换窗口尺寸不会错位。
## 未占卜（stage 0）与解读完（stage 2）都不叠 —— 球里回到原图的星云 / 雾。
const ORB_CX := 639.0
const ORB_CY := 188.0
const ORB_R := 89.0
const ORB_BASE_W := 1280.0
const ORB_BASE_H := 720.0
## R519d：整屏背景的基准比例（720/1280 = 0.5625）。EventBG 的框高按它算，见 `_fit_event_bg`。
const EVENT_BG_ASPECT := 0.5625


func _fit_event_bg() -> void:
	## R519d：把 EventBG 从「居中裁」改成「按宽度铺满、顶部对齐」。
	##
	## `STRETCH_KEEP_ASPECT_COVERED` 永远是**居中**裁 —— 屏比 16:9 宽时，纵向要切掉
	## 「图高 − 屏高」那么多，上下各分一半。1280×720 下切 0，所以平时看不出来；
	## 1920×720 下纵向切 360px（原图的 1/3），**人物类背景直接切到头顶**
	## （武术大师的老人在宽屏下只剩胡子）。
	##
	## 做法不给 TextureRect 换 stretch 模式（那会影响占卜球 / 核心图层的换算），
	## 只把它的**框**撑到与背景图同比例：「框 = 屏宽 × 0.5625」。
	## 框与图同比 → cover 不再裁切；多出来的高度落在屏幕下方之外，观感就是「顶部对齐」。
	## 1280×720 时 offset_bottom 恰好为 0 → 16:9 下与改前逐像素一致。
	if _event_bg == null:
		return
	# 用**自身尺寸**算（trb 的锚点是相对本节点的 0..1）；`_ready` 里第一次进来时
	# 布局还没跑完、size 可能还是 0，这时才退回视口尺寸。
	var vs := size if size.x > 1.0 else get_viewport_rect().size
	_event_bg.offset_bottom = maxf(0.0, vs.x * EVENT_BG_ASPECT - vs.y)


func _make_orb_layers(bg_rect: TextureRect) -> void:
	## 插在 EventBG 之后、其余 UI 之前：既压在底图上，又不会盖住中间一列按钮。
	var zi := bg_rect.get_index() + 1
	_orb_vision = TextureRect.new()
	_orb_vision.name = "OrbVision"
	_orb_vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_vision.stretch_mode = TextureRect.STRETCH_SCALE
	_orb_vision.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 否则 size 被贴图原生 256 顶掉
	_orb_vision.visible = false
	add_child(_orb_vision)
	move_child(_orb_vision, zi)

	_orb_glass = TextureRect.new()
	_orb_glass.name = "OrbGlass"
	_orb_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_glass.stretch_mode = TextureRect.STRETCH_SCALE
	_orb_glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_orb_glass.material = mat
	_orb_glass.texture = UiAssets.div_orb_glass()
	_orb_glass.visible = false
	add_child(_orb_glass)
	move_child(_orb_glass, zi + 1)

	if not resized.is_connected(_layout_orb_layers):
		resized.connect(_layout_orb_layers)
	_layout_orb_layers()
	_update_orb_vision()


func _layout_orb_layers() -> void:
	## 复现 `STRETCH_KEEP_ASPECT_COVERED`：scale = max(w/1280, h/720)，居中后裁切。
	## 底图若是被换成别的尺寸，这里也要跟着改 —— 两个常量就是那份契约。
	if _orb_vision == null:
		return
	var vs := get_viewport_rect().size
	var s := maxf(vs.x / ORB_BASE_W, vs.y / ORB_BASE_H)
	# R519d：EventBG 已改成「顶部对齐」，图层换算也要跟着 —— 纵向不再对半分。
	var off := Vector2((vs.x - ORB_BASE_W * s) * 0.5, 0.0)
	var c := off + Vector2(ORB_CX, ORB_CY) * s
	var d := ORB_R * 2.0 * s
	_orb_vision.position = c - Vector2(d, d) * 0.5
	_orb_vision.size = Vector2(d, d)
	if _orb_glass != null:
		_orb_glass.position = _orb_vision.position
		_orb_glass.size = _orb_vision.size


## ---- R512 契约的核心：石台凹槽里的核心 -----------------------------------
## 底图 `bg_core_contract.png`（1280×720 基准）的石台中央是**空凹槽**：
## 圆心 (648, 406)、外沿半径约 181×59（透视压扁的椭圆）。契约文刻在石台面上，
## 核心本体不画进底图 —— 取走核心后要能收掉（文案：只剩一圈浅浅的凹痕）。
## 叠的是道具同一张图 `reward_icons/core.png`，所以标志永远和道具栏里一致。
const CORE_ICON_CX := 648.0
const CORE_ICON_CY := 350.0
const CORE_ICON_SIZE := 200.0

var _core_icon: TextureRect = null
var _event_bg: TextureRect = null   # R519d：整屏背景（要随窗口比例改框高，见 `_fit_event_bg`）


func _make_core_icon(bg_rect: TextureRect) -> void:
	var tex := UiAssets.core_relic_icon()
	if tex == null:
		return
	var zi := bg_rect.get_index() + 1
	_core_icon = TextureRect.new()
	_core_icon.name = "CoreIcon"
	_core_icon.texture = tex
	_core_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_core_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_core_icon)
	move_child(_core_icon, zi)
	if not resized.is_connected(_layout_core_icon):
		resized.connect(_layout_core_icon)
	_layout_core_icon()
	_update_core_icon()


func _layout_core_icon() -> void:
	## 与占卜球同一套变换（复现 EventBG 的铺法：横向居中、**纵向顶部对齐**），换窗口不会错位。
	if _core_icon == null:
		return
	var vs := get_viewport_rect().size
	var s := maxf(vs.x / ORB_BASE_W, vs.y / ORB_BASE_H)
	# R519d：EventBG 已改成「顶部对齐」，图层换算也要跟着 —— 纵向不再对半分。
	var off := Vector2((vs.x - ORB_BASE_W * s) * 0.5, 0.0)
	var c := off + Vector2(CORE_ICON_CX, CORE_ICON_CY) * s
	var d := CORE_ICON_SIZE * s
	_core_icon.position = c - Vector2(d, d) * 0.5
	_core_icon.size = Vector2(d, d)


func _update_core_icon() -> void:
	## 已经取走核心（本页选过「获取核心」，或道具栏里已经有「核心」）→ 石台上没有它。
	if _core_icon == null:
		return
	_core_icon.visible = _core_pick != "core" \
			and not RunState.has_relic(RunState.CORE_RELIC_ID)


func _update_orb_vision() -> void:
	## 幻象只在「已占卜、还没解读」这一态出现；解读完球里重新蒙雾（文案也是这么写的）。
	if _orb_vision == null:
		return
	var tex: Texture2D = null
	if _div_stage == 1 and _div_rolled >= 1:
		tex = UiAssets.div_vision(_div_rolled)
	_orb_vision.texture = tex
	_orb_vision.visible = tex != null
	if _orb_glass != null:
		_orb_glass.visible = tex != null


## R478：缺图时的统一默认底。目标不是「给每种事件画一张图」，而是让「没有图」
## 本身看起来像一套设计：墨蓝夜色渐变 + 按类别着色的光晕 + 金线纹章水印 + 四周暗角。
## 想退回旧的「纯深灰底」观感：把这里改成 false（篝火可见性仍按 _apply_ui_assets 走）。
const EVENT_FALLBACK_BG := true

var _fb_layer: Control = null
var _fb_tint := Color("c8951c")

## R513：暗页事件 —— 整页按「黑暗」呈现：背景近黑、信息卡深墨、文字浅色。
## R516（用户口径）：**全部事件统一暗紫肤** —— 浅纸底 + 白色信息卡观感不好。
## 于是这个判据不再按 kind 分支：所有事件都走暗色方案（保留函数与常量是为了
## 以后要恢复「个别事件亮底」时有落点，别把 `DARK_PAGE_KINDS` 当死代码删掉）。
const DARK_PAGE_KINDS := ["gaze"]   # R513 的原始名单，仅作历史记录

var _dark_page := false
var _fb_dark := false


func _is_dark_page(_kind: String) -> bool:
	## R516：全事件暗紫肤。
	return true


func _apply_page_ink() -> void:
	## R516：暗紫肤 —— 标题柠檬金，正文米色（`NIGHT_INK`），次要信息暗一档。
	if _dark_page:
		event_name.add_theme_color_override("font_color", UiTheme.ACCENT_LIT)
		desc.add_theme_color_override("font_color", UiTheme.NIGHT_INK)
		result_label.add_theme_color_override("font_color", UiTheme.NIGHT_INK_DIM)
	else:
		event_name.add_theme_color_override("font_color", UiTheme.PAGE_INK)
		desc.add_theme_color_override("font_color", UiTheme.PAGE_INK)


func _result_color_on_dark() -> void:
	## 结果行有几十处分支各自写死「浅底墨色」（#8a6a3a / #2f7fa8 / #c0504d…），
	## 放进暗页会糊进黑里。这里按亮度兜底提亮，只在真暗时动一次
	## （提亮后线性亮度已越过阈值，重复调用不会继续叠亮）。
	if not _dark_page:
		return
	var c := result_label.get_theme_color("font_color")
	if c.get_luminance() < 0.22:
		result_label.add_theme_color_override("font_color", c.lightened(0.55))


func _add_fallback_bg(kind: String) -> void:
	if not EVENT_FALLBACK_BG:
		return
	if _fb_layer != null:
		_fb_tint = _kind_tint(kind)
		_fb_dark = _dark_page
		_fb_layer.queue_redraw()
		return
	_fb_tint = _kind_tint(kind)
	_fb_dark = _dark_page
	_fb_layer = Control.new()
	_fb_layer.name = "EventFallbackBG"
	_fb_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fb_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb_layer.draw.connect(_on_fallback_draw)
	_fb_layer.resized.connect(_fb_layer.queue_redraw)
	add_child(_fb_layer)
	move_child(_fb_layer, 1)   # $BG 之上、篝火与内容之下


func _kind_tint(kind: String) -> Color:
	## 六类事件的主题色：危险 / 交易 / 神秘 / 自然 / 收获 / 休息。
	## 只改光晕和纹章的颜色，暗底不变 —— 保证 24 种事件「同一套里各有区别」。
	match kind:
		"struggle", "gaze", "oblivion", "furnace", "core_contract":
			return Color("b5484a")   # 危险：暗红
		"smith", "card_merchant", "lake_lady", "apple_doctor", "delivery", "delivery_done", "martial":
			return Color("c8951c")   # 交易 / 匠人：金
		"whisper", "divination", "moon", "arcane", "hero":
			return Color("8a7fd4")   # 神秘 / 预兆：紫
		"pear", "snow_leopard", "adventurer", "cave", "flyer":
			return Color("6faa62")   # 自然 / 探索：绿
		"treasure", "relic_chest":
			return Color("d99b3f")   # 收获：橙金
	return Color("ff9a3c")           # rest / 兜底：暖橙（与篝火同调）


func _on_fallback_draw() -> void:
	var sz := _fb_layer.size
	if sz.x < 2.0 or sz.y < 2.0:
		return
	var tint := _fb_tint
	var gold := UiTheme.ACCENT_GOLD
	# R513：暗页 —— 底压到近黑，只在眼睛那一行铺一层极淡的暗红雾。
	# 插图自带椭圆暗场，底够黑时那块暗场才真正化进背景，不留一块贴纸黑斑。
	# 也不画纹章水印与四周暗角：黑底上它们不是「不空」，而是「脏」。
	if _fb_dark:
		var bands_d := 56
		var bh_d := sz.y / float(bands_d)
		# R516：底色由「近黑」抬成**暗紫**（上冷下暖一点点），雾仍极淡。
		var dtop := UiTheme.NIGHT_BG_TOP
		var dbot := UiTheme.NIGHT_BG_BOT
		for i in bands_d:
			var cd := dtop.lerp(dbot, float(i) / float(bands_d - 1))
			_fb_layer.draw_rect(Rect2(0.0, bh_d * float(i), sz.x, bh_d + 1.5), cd)
		# 雾要「铺得开、几乎看不见」：半径接近全屏、层数少、单层极低 alpha。
		# 半径小 + 层数多会叠成一个能看出边界的圆形光斑，那就成了探照灯。
		var ctr_d := Vector2(sz.x * 0.5, 176.0)
		var rmax_d := maxf(sz.x, sz.y) * 0.95
		for i in 14:
			var td := float(i + 1) / 14.0
			_fb_layer.draw_circle(ctr_d, rmax_d * (1.02 - td * 0.90),
					Color(tint.r, tint.g, tint.b, 0.0055))
		_fb_layer.draw_line(Vector2(0.0, 45.0), Vector2(sz.x, 45.0),
				Color(gold.r, gold.g, gold.b, 0.20), 1.0)
		return
	# 1) 纵向渐变：上方偏暖（像有光），下方沉下去
	var top := Color("dce3cf")
	var bot := Color("f0e6d4")
	var bands := 48
	var bh := sz.y / float(bands)
	for i in bands:
		var c := top.lerp(bot, float(i) / float(bands - 1))
		_fb_layer.draw_rect(Rect2(0.0, bh * float(i), sz.x, bh + 1.5), c)
	# 2) 类别光晕：以篝火位置（y=168）为中心向内叠加，中心最亮
	var ctr := Vector2(sz.x * 0.5, 168.0)
	var rmax := maxf(sz.x, sz.y) * 0.55
	for i in 24:
		var t := float(i + 1) / 24.0
		_fb_layer.draw_circle(ctr, rmax * (1.0 - t * 0.72), Color(tint.r, tint.g, tint.b, 0.011))
	# 3) 中心纹章水印：同心环 + 菱形，很淡 —— 只负责「不空」，不抢文字
	var rr := 135.0
	_fb_layer.draw_arc(ctr, rr, 0.0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.15), 1.5, true)
	_fb_layer.draw_arc(ctr, rr * 0.90, 0.0, TAU, 96, Color(gold.r, gold.g, gold.b, 0.07), 1.0, true)
	var d := rr * 0.66
	_fb_layer.draw_polyline(PackedVector2Array([
			ctr + Vector2(0, -d), ctr + Vector2(d, 0), ctr + Vector2(0, d),
			ctr + Vector2(-d, 0), ctr + Vector2(0, -d)]),
			Color(gold.r, gold.g, gold.b, 0.11), 1.2, true)
	# 4) 四周暗角：越靠边越黑，把视线压回中间
	var vig := 190.0
	var steps := 20
	var step_h := vig / float(steps)
	for i in steps:
		var t := float(i) / float(steps)
		var a := 0.10 * pow(1.0 - t, 1.7)
		var off := step_h * float(i)
		_fb_layer.draw_rect(Rect2(0.0, off, sz.x, step_h + 1.0), Color(0, 0, 0, a))
		_fb_layer.draw_rect(Rect2(0.0, sz.y - off - step_h - 1.0, sz.x, step_h + 1.0), Color(0, 0, 0, a * 0.80))
		_fb_layer.draw_rect(Rect2(off, 0.0, step_h + 1.0, sz.y), Color(0, 0, 0, a * 0.75))
		_fb_layer.draw_rect(Rect2(sz.x - off - step_h - 1.0, 0.0, step_h + 1.0, sz.y), Color(0, 0, 0, a * 0.75))
	# 5) 顶部金线：只在标题栏下沿做分隔。底部不再画线 —— 720 高下按钮会压到它。
	_fb_layer.draw_line(Vector2(0.0, 45.0), Vector2(sz.x, 45.0), Color(gold.r, gold.g, gold.b, 0.22), 1.0)


func _ready() -> void:
	## ⚠️ R519：事件页**不接** `UiTheme.attach_stage()` —— 它的排版从 R518 起就按
	## `get_viewport_rect()` 自适应，背景 `EventBG` 又是整屏 cover 铺满；套上 1280 舞台
	## 反而会把底图裁成中间一块、两侧露底色。保持现有全窗口布局。
	# R513：信息卡底色分「浅纸 / 深墨」两档；此回调在 _apply_ui_assets 之后才绘制，读 _dark_page 安全。
	# R516：左右布局（`lake_lady`）**不要框** —— 文字直接压在背景上，只靠排版与字色区分。
	$Center.draw.connect(func():
		if _side_layout:
			return
		UiTheme.draw_info_card($Center, Rect2(Vector2(-22, -16), $Center.size + Vector2(44, 32)), false, _dark_page))
	# 字色不在这里定死 —— 见 `_apply_page_ink()`（暗页要浅字，且此刻 _kind() 可能还没就位）
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	# R518：正文与标题一律允许折行 —— 宽度自适应会顶到上限（长文案不再无限加宽），
	# 撞上限时折行而不是溢出卡片。文案本身没超宽时折行不会生效，观感不变。
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# R518：文案 / 字号 / 窗口尺寸一变就重算宽度（合并成每帧一次）。
	# ⚠️ 用 `minimum_size_changed` 而不是 `item_rect_changed`：后者连**位置**变化都发，
	# 而重排本身就会挪动子节点 → 自己把自己唤醒，成了逐帧空转。
	for _b: Button in [rest_btn, bbq_btn, alt_btn, leave_btn]:
		if not _b.minimum_size_changed.is_connected(_queue_relayout):
			_b.minimum_size_changed.connect(_queue_relayout)
	if not desc.minimum_size_changed.is_connected(_queue_relayout):
		desc.minimum_size_changed.connect(_queue_relayout)
	if not event_name.minimum_size_changed.is_connected(_queue_relayout):
		event_name.minimum_size_changed.connect(_queue_relayout)
	if not result_label.minimum_size_changed.is_connected(_queue_relayout):
		result_label.minimum_size_changed.connect(_queue_relayout)
	if not resized.is_connected(_queue_relayout):
		resized.connect(_queue_relayout)
	# R516：全部事件改暗紫肤 —— 选项是**深色胶囊 + 米色字**（造型沿用原来的圆角与黄铜细边）。
	for _b: Button in [rest_btn, bbq_btn, alt_btn, leave_btn]:
		UiTheme.apply_night_button(_b, false)
	sfx = Sfx.new()
	add_child(sfx)
	# 牌库任何时候都可以查看（无论在哪个界面）
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# R119：奖励悬浮窗 —— 宝箱层开箱 / 宝箱事件 / 奥秘之泉「喝下泉水」都先入队，
	# 由它展示完整介绍（长描述不再塞进下面那一行 Label）。
	_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
	# R216：领到「要立刻选卡」的即时道具 → 奖励界面当场转去卡组选择页。
	# 本页的收尾就是「房间标记完成」（`complete_current` 幂等），先做掉再跳。
	_reward_panel.on_before_pick = _settle_before_pick
	# R122：描述文案的悬浮提示层 —— 挂在最后（画在所有子节点之上）、IGNORE（不吃点击）。
	_tip_layer = Control.new()
	_tip_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_layer.draw.connect(_on_tip_draw)
	add_child(_tip_layer)
	# 演示参数：--dmg N 先扣 N 点生命，方便截图/试玩验证各事件的残血态
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dmg" and i + 1 < args.size():
			RunState.take_damage(maxi(0, int(args[i + 1])))
		if args[i] == "--treasure":  # 演示：伪装 run 宝箱节点（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
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
		if args[i] == "--flyer":  # 演示：伪装 run 飞行器事件（R573 背景截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "flyer"
			# R574：演示不经过进房入口，巧克力默认 0 → 会误落进「没油」兜底页。
			# 按真实进房时该有的量补上，才截得到「可用按钮」的正常态。
			RunState.chocolate = RunState.chocolate_per_layer()
		if args[i] == "--flyerlow":  # 演示：旧存档 / 巧克力不足的兜底页（R574 截图验证）
			# 正常流程走不到这里（进房入口已按巧克力过滤），只验「不摆灰按钮」。
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "flyer"
			RunState.chocolate = 1
		if args[i] == "--apple":  # 演示：伪装 run 苹果与医生事件（R244 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "apple_doctor"
		if args[i] == "--snowleopard":  # 演示：伪装 run 雪豹出现事件（R446 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "snow_leopard"
		if args[i] == "--adventurer":  # 演示：伪装 run 冒险家的遗物事件（R447 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "adventurer"
		if args[i] == "--martial":  # 演示：伪装 run 武术大师事件（R473 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "martial"
		if args[i] == "--rest":  # 演示：伪装 run 休息节点（R519h 篝火背景截图验证）
			# ⚠️ 休息处不是 event 房：地图节点 type == "rest"，pending_event 为空。
			# 写成 {"type":"event"} + pending_event="rest" 会被 `_is_treasure()`
			# （其余 event 子类型的兜底分支）认领 → 截出来是宝箱，不是篝火。
			RunState.run_active = true
			RunState.pending_node = {"type": "rest"}
			RunState.pending_event = ""
		# ⚠️ 湖中仙女用已有的 `--lakelady`（无下划线，见下）：它还带 deck_ids 与
		# `lake_victim = 4`，悬浮提示才有牌可锁。R519h 曾误加一个 `--lake_lady`，已撤。
		if args[i] == "--cave":  # 演示：伪装 run 洞穴事件（R467 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "cave"
		# R573：该事件已下线，旧演示参数入口一并移除（旧存档只走兜底页）。
		if args[i] == "--moon":  # 演示：伪装 run 赏月事件（第二层专属，带 120 金币）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "moon"
			RunState.gold = 120
		if args[i] == "--moonpoor":  # 演示：赏月 + 身上没钱（验「月亮」那项置灰）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "moon"
			RunState.gold = 0
		if args[i] == "--furnace":  # 演示：熔炉（R454 第二层专属）——身上 3 件奖励道具（含传奇）
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "furnace"
			RunState.relics = [6006, 6050, 6029]
		if args[i] == "--furnacelow":  # 演示：熔炉 —— 只有 1 件可投（选项只剩一个）
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "furnace"
			RunState.relics = [6029]
		if args[i] == "--furnaceleg":  # 演示：熔炉 —— 只带 1 件传奇档（鸭嘴 6006），验「换回 2 件」
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "furnace"
			RunState.relics = [6006]
		if args[i] == "--furnaceempty":  # 演示：熔炉 —— 道具栏全空（只剩「离开」）
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "furnace"
			RunState.relics = []
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
		if args[i] == "--cardmerchant":  # 演示：卡片商人（R305 出图核验三项选项）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "card_merchant"
			RunState.deck_ids = [8001, 8002, 8003, 9018, 8060, 8001, 9154, 9083]
		if args[i] == "--divination":  # 演示：占卜室（初始态）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "divination"
		for _di in 4:
			if args[i] == "--div%d" % (_di + 1):  # 演示：占卜室的第 1~4 种幻象（解读态）
				RunState.run_active = true
				RunState.pending_node = {"type": "event"}
				RunState.pending_event = "divination"
				_div_stage = 1
				_div_rolled = _di + 1
		if args[i] == "--lakelady":  # 演示：湖中仙女（R305 出图核验两项选项）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "lake_lady"
			RunState.deck_ids = [8001, 8002, 8003, 8004, 9018]
			RunState.ensure_deck_mods()
			# R488：固定摇定第 4 张（9018 金属龙）并给它挂一条「费用 -1」附魔 ——
			# 截图可复现，而且能验证悬浮里画的是**这一张实例**（4 费 + 附魔标记），
			# 不是卡库原卡（5 费、无附魔）。配合 `--tip 金属龙` 出图。
			RunState.deck_mods[4] = RunState.enchant_mod("costdown")
			RunState.lake_victim = 4
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
		if args[i] == "--corecontract":  # 演示：契约的核心（R458 第二层专属）
			RunState.run_active = true
			RunState.current_layer = GameLayers.LAYER_TWO
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "core_contract"
			# 卡组里放三张伤害技能牌（火焰箭 17 / 闪电链 11 / 寒冰箭 3）+ 两张普通牌，
			# 两段选卡都有货：祭品三选一、接收者二选一（祭品自己不在候选里）。
			RunState.deck_ids = [8001, 8002, 8003, 9003, 9006, 9011, 9011]
		if args[i] == "--tip" and i + 1 < args.size():
			_tip_demo = args[i + 1]   # 演示：锁住某个名字的悬浮提示（截图核验用）
	bbq_btn.visible = false   # 「烤肉」只在休息处出现，事件节点隐藏
	alt_btn.visible = false   # R305：第三选项只有卡片商人用
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
	elif _is_apple():
		event_name.text = "苹 果 与 医 生"
		desc.text = APPLE_DESC
		if RunState.has_relic(APPLE_ID):
			_apple_taken = true
			_collapse_to_leave()
			desc.text = APPLE_TAKEN_DESC
			result_label.text = "苹果你已经收下过了——医生不再理你。"
			result_label.add_theme_color_override("font_color", Color("a44ad0"))
		else:
			rest_btn.text = "收下苹果（远离医生）"
			rest_btn.disabled = false
			$Center/LeaveBtn.text = "放弃并离开"
			result_label.text = ""
	elif _is_bluefish():
		# R573 已下线：只留「离开」，不给卡、不发奖励（旧存档 / 脏数据兜底）。
		event_name.text = "蓝 色 大 肥 鱼"
		desc.text = RETIRED_EVENT_DESC
		_collapse_to_leave()
		result_label.text = "这个事件已经从游戏里移除了。"
	elif _is_moon():
		event_name.text = "赏 月"
		desc.text = MOON_TAKEN_DESC if _moon_pick == "moon" \
				else (COIN_TAKEN_DESC if _moon_pick == "coin" else MOON_DESC)
		if _moon_pick != "":
			_collapse_to_leave()
			result_label.text = "石台上已经空了——两样东西只剩一样，而你只拿得走一样。"
			result_label.add_theme_color_override("font_color", Color("b9c8e8"))
		else:
			# 月亮那一项要「失掉全部金币」——身上一分钱没有就构不成交换，置灰。
			var g := RunState.gold
			if g > 0:
				rest_btn.text = "失去 %d 金币，拿走「月亮」" % g
				rest_btn.disabled = false
			else:
				rest_btn.text = "身上没有金币，换不到「月亮」"
				rest_btn.disabled = true
			alt_btn.visible = true
			alt_btn.text = "拿走「硬币」"
			alt_btn.disabled = false
			# R365（用户口径）：赏月**没有「什么都不拿」这一项** —— 两样东西摆在石台上，
			# 走到这儿就得拿走一样。不会卡死：月亮够不着（没钱）时硬币一定够得着，
			# 而领走任一样之后 `_collapse_to_leave()` 会把唯一的「离开」还回来。
			leave_btn.visible = false
			result_label.text = ""
	elif _is_furnace():
		event_name.text = "熔  炉"
		_furnace_opts = RunState.furnace_options()
		_setup_furnace()
	elif _is_core_contract():
		_setup_core_contract()
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
	elif _is_divination():
		event_name.text = "占 卜 室"
		if _div_stage >= 2:
			desc.text = DIVINATION_DONE_DESC
			_collapse_to_leave()
			result_label.text = _div_result
			result_label.add_theme_color_override("font_color", Color("8a9ad8"))
		elif _div_stage == 1:
			# 演示 / 回档：已经占卜过 → 直接铺解读选项
			_apply_divination_text()
		else:
			desc.text = DIVINATION_DESC
			rest_btn.text = "进行占卜"
			rest_btn.disabled = false
			bbq_btn.visible = false
			leave_btn.text = "离开（不占卜）"
			result_label.text = ""
	elif _is_card_merchant():
		event_name.text = "卡 片 商 人"
		desc.text = MERCHANT_DONE_DESC if _merchant_done else MERCHANT_DESC
		if _merchant_done:
			_collapse_to_leave()
			result_label.text = "这一处你已经做过一笔交易了。"
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			var has_five := not RunState.deck_indices_with_cost(
					RunState.MERCHANT_MIN_COST).is_empty()
			rest_btn.text = "换卡：选一张卡变成随机本职业奖励卡"
			rest_btn.disabled = RunState.deck_ids.is_empty()
			bbq_btn.visible = true
			bbq_btn.text = "易物：交出 5 费卡换一个大宝箱" if has_five \
					else "易物：（卡组里没有 5 费及以上的卡）"
			bbq_btn.disabled = not has_five
			alt_btn.visible = true
			var has_sell := not RunState.deck_indices_not_curse().is_empty()
			alt_btn.text = ("折价：随机失去一张非诅咒卡换 %d 金币"
					% RunState.VENDOR_GOLD) if has_sell else "折价：（卡组里只剩诅咒卡）"
			alt_btn.disabled = not has_sell
			leave_btn.text = "离开（什么都不换）"
			result_label.text = ""
	elif _is_lake_lady():
		event_name.text = "湖 中 仙 女"
		desc.text = LAKE_DONE_DESC if _lake_done else LAKE_DESC
		if _lake_done:
			_collapse_to_leave()
			result_label.text = "水面已经平静了。"
			result_label.add_theme_color_override("font_color", Color("8a9ad8"))
		else:
			# R488（用户口径）：进门就摇定「要失去的那一张」，按钮直接把卡名写死 ——
			# 悬浮这个名字看到的是**卡组里那一张实例**（连附魔 / 本局成长一起），
			# 不是卡库原卡。候选 = 全部非诅咒卡。
			_lake_pick = RunState.lake_lady_peek()
			var has_pick := bool(_lake_pick.get("ok", false))
			rest_btn.text = ("谎言：失去「%s」" % str(_lake_pick.get("name", ""))) \
					if has_pick else "谎言：（卡组里没有能失去的卡）"
			rest_btn.disabled = not has_pick
			bbq_btn.visible = true
			bbq_btn.text = "诚实：获得一张随机史诗卡"
			bbq_btn.disabled = false
			leave_btn.text = "离开（什么也不说）"
			result_label.text = ""
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
	elif _is_snow_leopard():
		event_name.text = "雪 豹 出 现"
		desc.text = SNOW_CLOSED_DESC if _snow_pick == "pipe" \
				else (SNOW_CHEESE_DESC if _snow_pick == "cat" else SNOW_DESC)
		if _snow_pick != "":
			_collapse_to_leave()
			if _snow_pick == "pipe":
				result_label.text = "「烟斗」已收进道具栏——下一场战斗的第一回合生效；" \
						+ "之后每次路过篝火都会重新点着。"
			else:
				result_label.text = "「雪豹」已加入卡组——它攻击时会把一张手牌的费用压低一个回合。"
			result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		else:
			rest_btn.text = "雪豹闭嘴（获得道具「烟斗」）"
			rest_btn.disabled = false
			alt_btn.visible = true
			alt_btn.text = "投喂芝士（获得卡片「雪豹」）"
			alt_btn.disabled = false
			# 两样都拿得到东西 → 没有「什么都不拿」这一项（同「赏月」的收法）。
			leave_btn.visible = false
			result_label.text = ""
	elif _is_adventurer():
		event_name.text = "冒 险 家 的 遗 物"
		desc.text = ADVENTURER_NOTE_DESC if _adv_pick == "note" \
				else (ADVENTURER_FLINT_DESC if _adv_pick == "flint" else ADVENTURER_DESC)
		if _adv_pick != "":
			_collapse_to_leave()
			result_label.text = _adv_result
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			rest_btn.text = "查看笔记（获得道具「冒险笔记」）"
			rest_btn.disabled = false
			alt_btn.visible = true
			alt_btn.text = "拿取工具（获得道具「燧石」）"
			alt_btn.disabled = false
			# 两样都拿得到东西 → 没有「什么都不拿」这一项（同「雪豹出现」/「赏月」）。
			leave_btn.visible = false
			result_label.text = ""
	elif _is_martial():
		event_name.text = "武 术 大 师"
		desc.text = MARTIAL_BRAWL_DESC if _martial_pick == "brawl" \
				else (MARTIAL_KICK_DESC if _martial_pick == "kick" \
				else (MARTIAL_PUNCH_DESC if _martial_pick == "punch" else MARTIAL_DESC))
		if _martial_pick != "":
			_collapse_to_leave()
			result_label.text = _martial_result
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			# 三个选项都要显式恢复可见 —— `_ui_main()` 是全量重绘，别的分支可能留过 false。
			rest_btn.visible = true
			rest_btn.text = "学点简单的（获得「乱打」）"
			rest_btn.disabled = false
			bbq_btn.visible = true
			bbq_btn.text = "学点真本事（2 场战斗后获得「飞踢」）"
			bbq_btn.disabled = false
			alt_btn.visible = true
			alt_btn.text = "要学就学绝技（2 场精英 / Boss 后获得「冲拳」）"
			alt_btn.disabled = false
			leave_btn.visible = true
			leave_btn.text = "离开（什么都不学）"
			leave_btn.disabled = false
			result_label.text = ""
	elif _is_flyer():
		event_name.text = "飞 行 器"
		desc.text = FLYER_TAKEN_DESC if _fly_done else FLYER_DESC
		if _fly_done:
			_collapse_to_leave()
			result_label.text = _fly_result
			result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		elif not GameLayers.event_kind_available("flyer", RunState.chocolate):
			# R574：旧存档 / 演示参数才可能走到这儿 —— 不摆灰按钮，直接给一个收尾页。
			desc.text = FLYER_NO_FUEL_DESC
			_fly_done = true
			_collapse_to_leave()
			result_label.text = "巧克力不够，飞行器没能起飞。你没有在这里停留。"
			result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		else:
			rest_btn.visible = true
			rest_btn.text = "使用飞行器（飞到一个没去过的房间，消耗 1 块巧克力）"
			rest_btn.disabled = false
			bbq_btn.visible = false
			alt_btn.visible = false
			leave_btn.visible = true
			leave_btn.text = "不移动（离开）"
			leave_btn.disabled = false
			result_label.text = ""
	elif _is_cave():
		event_name.text = "洞 穴"
		desc.text = CAVE_DESC
		# 只有两个选项：探索（战斗 + 传说卡）／离开。没有第二选项按钮。
		rest_btn.visible = true
		rest_btn.text = "探索（与枭熊交手，胜利后获得传说卡「枭熊」）"
		rest_btn.disabled = false
		bbq_btn.visible = false
		alt_btn.visible = false
		leave_btn.visible = true
		leave_btn.text = "离开"
		leave_btn.disabled = false
		result_label.text = ""
	elif _is_treasure():
		event_name.text = "宝  箱"
		# R372：统一免费开、内容恒为卡牌（不再扣生命、不再随机成道具）。
		desc.text = "路旁放着一只落满灰尘的宝箱……\n" \
				+ "掀开箱盖，里面躺着一叠卡牌（挑 1 张加入卡组）。\n" \
				+ "不需要付出任何代价。也可以转身离开，分文不取。"
		rest_btn.text = "打开宝箱（获得卡牌奖励）"
		rest_btn.disabled = false
		$Center/LeaveBtn.text = "不打开（转身离开）"
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
		# 休息处（R237：恢复篝火回血 —— 「在这里休息」与「烤肉」二选一）
		bbq_btn.visible = true
		rest_btn.visible = true
		event_name.text = "休息处"
		desc.text = _rest_desc()
		# R473（用户口径）：圣餐（6038）= **到达篝火处**回复 50% 最大生命，进房当场结算一次。
		# `_sacrament_note` 记住本次回了多少（-1 = 还没试过）—— `_ui_main()` 会反复重绘，
		# 真正的防重复在 `RunState.sacrament_arrive()` 里按房间记账。
		if _sacrament_note < 0:
			_sacrament_note = RunState.sacrament_arrive()
		if _sacrament_note > 0:
			desc.text += "\n\n【圣餐】回复了 %d 点生命（现 %d / %d）。" % [
					_sacrament_note, RunState.hp, RunState.max_hp]
		var rest_gain := mini(RunState.rest_heal_amount(), RunState.max_hp - RunState.hp)
		# R473：圣餐的回复已经挪到「到达时」，休息本身回到档位口径，不再给它开特例。
		rest_btn.text = "在这里休息（回复 %d 生命）" % rest_gain
		rest_btn.disabled = rest_gain <= 0   # 满血 → 休息没意义，置灰
		# R390（用户口径）：第三个收益选项「添加柴火」（删一张卡）—— 挂在这条链上唯一
		# 空着的 AltBtn。与「休息 / 烤肉」构成三选一：任一选项结算后
		# `_collapse_to_leave()` 会把另外两个收起，选完这一处就到头了
		#（与 R147「一次访问只领一份」同一套规则，不另造闸门）。
		alt_btn.visible = true
		alt_btn.text = "添加柴火（从卡组删除一张卡）"
		alt_btn.disabled = RunState.deck_ids.is_empty()
		# R234 止血绷带（6029）：进休息处时结算本层累计的额外回血（结算后清零）。
		var bandage_heal := RunState.consume_bandage_heal()
		if bandage_heal > 0:
			desc.text += "\n\n【止血绷带】回复了 %d 点生命（现 %d / %d）。" % [
					bandage_heal, RunState.hp, RunState.max_hp]
			result_label.text = "止血绷带：回复 %d 点生命" % bandage_heal
			result_label.add_theme_color_override("font_color", Color("c0504d"))
		# R446 烟斗：**路过篝火**就重新点着 —— 不必「休息 / 烤肉」，进这间房就算路过。
		# 只在「之前是灭的」时加那行提示，免得每次进休息处都多一段废话。
		if RunState.pipe_relight():
			desc.text += "\n\n【烟斗】火光一明一暗——烟斗重新点着了，下一场战斗的第一回合效果恢复。"
	$Center/LeaveBtn.pressed.connect(func(): _ui_leave())
	rest_btn.pressed.connect(func(): _ui_main())
	bbq_btn.pressed.connect(func(): _ui_bbq())
	# R365：**第三选项（AltBtn）从来没接过信号** —— R305 卡片商人的「折价」、
	# R351 赏月的「拿走硬币」都挂在这个按钮上，`_on_alt()` 从 R305 起就没有任何调用者，
	# 于是点下去毫无反应（用户实测：赏月点「拿走硬币」＝硬币拿不到）。
	# 三个选项必须走同一条路进来；`_ui_alt` 与 `_ui_main` / `_ui_bbq` 同构。
	alt_btn.pressed.connect(func(): _ui_alt())
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
	elif "--mooncoin" in args:      # R365：赏月「已拿走硬币」的收尾态（配 --moon 用）
		_ui_alt()
	elif "--furnacetake" in args:   # R454：熔炉「已投入」的收尾态（配 --furnace 用）
		_on_main()
	elif "--lakeladylie" in args:   # R488：湖中仙女「谎言已应验」的收尾态（配 --lakelady 用）
		_on_main()
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
		"sub": "事件",
	})


func _redraw() -> void:
	## 文案变化后的统一出口：先重排中间一列，再重绘。
	_result_color_on_dark()
	_fit_center()
	queue_redraw()


func _fit_center() -> void:
	## 中间一列按内容实际高度排布：默认位置不变；放不下时先收紧间距、藏起空的结果行，
	## 再整体上移（上不越过插图下沿约 356），保证「离开 / 继续前进」这类末位选项永远完整可见。
	##
	## R478：`top_floor` 原来写死 360（守插图下沿）。但**缺图时插图根本不存在**，
	## 守这 360 会让 720 高度下的长文案事件（休息处 435px）底边冲到 795，
	## 末位按钮被切在屏幕外。缺图时放开到 150，让 _fit_center 能真正把它抬上来。
	var c: VBoxContainer = $Center
	var vh: float = get_viewport_rect().size.y
	result_label.visible = result_label.text != ""
	# R518：左右布局的垂直位置由 `_recenter_side_text()` 管（按内容居中），
	# 这里只负责居中布局 —— 两条链各管一半，别再互相覆盖。
	if _side_layout:
		_apply_side_metrics()
		call_deferred("_recenter_side_text")
		return
	_apply_center_width()
	var top_floor := 360.0 if UiAssets.event_pic(_kind()) != null else 150.0
	var bottom := vh - 30.0
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
	## 主按钮：小宝箱 → 免费转交卡牌奖励（R372）；鸭鸭低语 / 鸭之凝视 → 收下事件道具；
	## 宝箱层 → 开箱获得 1 个随机奖励道具。
	## R224：休息处的「休息」已移除（只剩 bbq_btn 的「烤肉」），不再有休息分支。
	sfx.play("click")
	if _is_cave():
		_cave_explore()
		return
	if _is_core_contract():
		_core_take_contract()
		return
	if _is_furnace():
		_furnace_take(0, rest_btn)
		return
	if _is_martial():
		if _martial_pick != "":
			return
		RunState.add_card(MARTIAL_BRAWL_ID)
		_martial_pick = "brawl"
		_claim_reward(rest_btn)
		_collapse_to_leave()
		desc.text = MARTIAL_BRAWL_DESC
		_martial_result = "「乱打」已加入卡组：2 费，对随机 2 个敌人各造成 10 点伤害。"
		result_label.text = _martial_result
		result_label.add_theme_color_override("font_color", Color("c86a5a"))
		_redraw()
		return
	if _is_flyer():
		if _fly_done:
			_on_leave()
			return
		# R574：进房入口已过滤，事件页也不再置灰；这里只留一道防死局的兜底。
		if not GameLayers.event_kind_available("flyer", RunState.chocolate):
			return
		_fly_done = true
		RunState.pending_fly = true   # 回地图后由 map_scene 进「飞行器选格」收尾
		_claim_reward(rest_btn)
		_collapse_to_leave()
		desc.text = FLYER_TAKEN_DESC
		_fly_result = "飞行器已就绪——回到地图后，挑一个没去过的房间，它就把你送过去。"
		result_label.text = _fly_result
		result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		_redraw()
		return
	if _is_adventurer():
		if _adv_pick != "":
			_on_leave()
			return
		# gain_relic 内部当场随机改一格（`RunState.note_reveal_bigchest()`），
		# 改完把格 id 留在 `map_flash_id` 上 —— 地图场景据此亮那一圈金光。
		RunState.gain_relic(ADVENTURER_NOTE_ID)
		var note_id := RunState.map_flash_id
		_adv_pick = "note"
		_claim_reward(rest_btn)
		_collapse_to_leave()
		desc.text = ADVENTURER_NOTE_DESC
		if note_id >= 0:
			_adv_result = "「冒险笔记」已收进道具栏：地图上一间还没去过的房间变成了大宝箱" \
					+ "——回到地图时会看见那格亮着金光。"
		else:
			_adv_result = "「冒险笔记」已收进道具栏——只是地图上已经没有没去过的房间了，" \
					+ "纸上什么也没写。"
		result_label.text = _adv_result
		result_label.add_theme_color_override("font_color", Color("d7a54a"))
		_redraw()
		return
	if _is_snow_leopard():
		if _snow_pick != "":
			_on_leave()
			return
		RunState.gain_relic(PIPE_ID)
		RunState.pipe_relight()   # 刚拿到手就是点着的：下一场战斗首回合立刻生效
		_snow_pick = "pipe"
		_claim_reward(rest_btn)   # R147：一次访问只领一份
		var rel_s := RelicRepo.load_json().get_relic(PIPE_ID)
		_collapse_to_leave()
		desc.text = SNOW_CLOSED_DESC
		result_label.text = "「烟斗」已收进道具栏：%s" % (rel_s.desc if rel_s != null else "")
		result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		_redraw()
		return
	sfx.play("click")
	if _is_divination():
		if _div_stage == 0:
			# 进行占卜：1~4 随机（**走本局 run_rng**，同种子一致）
			_div_rolled = RunState.run_rng.randi_range(1, DIVINATION_KINDS)
			_div_stage = 1
			_apply_divination_text()
			_update_orb_vision()
			sfx.play("click")
			_redraw()
			return
		if _div_stage == 1:
			_resolve_divination(true)
			return
		_on_leave()
		return
	if _is_lake_lady():
		if _lake_done:
			_on_leave()
			return
		var lie := RunState.lake_lady_lie()
		if not bool(lie.get("ok", false)):
			return
		_lake_done = true
		_lake_pick = {}          # R488：那张卡已经没了，悬浮绑定必须立刻失效
		_claim_reward(rest_btn)
		# R488：删卡是**不可逆消耗** —— 结算当刻就标完成。否则「回标题 → 继续 → 重进本房」
		# 会重新摇一张再删一次（R454 熔炉同一条纪律）。
		RunState.complete_current()
		_collapse_to_leave()
		desc.text = LAKE_DONE_DESC
		result_label.text = "谎言应验：「%s」从卡组里消失了。" % str(lie.get("lost_name", ""))
		result_label.add_theme_color_override("font_color", Color("8a9ad8"))
		_redraw()
		return
	if _is_card_merchant():
		if _merchant_done:
			_on_leave()
			return
		if RunState.deck_ids.is_empty():
			return
		# 换卡交给卡组编辑场景（与遗忘之泉 / 鸭鸭工匠共用同一套选牌 UI）
		_merchant_done = true
		_claim_reward(rest_btn)
		RunState.complete_current()
		RunState.pending_deck_edit = "transform_class"
		SceneFx.goto("res://scenes/deck_edit.tscn")
		return
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
	if _is_apple():
		if _apple_taken:
			_on_leave()
			return
		RunState.gain_relic(APPLE_ID)
		_apple_taken = true
		_claim_reward(rest_btn)   # R147：一次访问只领一份
		var rel_a := RelicRepo.load_json().get_relic(APPLE_ID)
		_collapse_to_leave()
		desc.text = APPLE_TAKEN_DESC
		result_label.text = "「苹果」已收进道具栏：%s" % (rel_a.desc if rel_a != null else "")
		result_label.add_theme_color_override("font_color", Color("a44ad0"))
		_redraw()
		return
	if _is_bluefish():
		# R573 兜底：任何残留点击都只关页，绝不发「鲸鱼之怒」。
		_on_leave()
		return
	if _is_moon():
		if _moon_pick != "":
			_on_leave()
			return
		# 月亮：把金币清空（走唯一口，别在图里写 gold = 0），换一张效果卡进卡组。
		var lost := RunState.clear_gold()
		RunState.add_card(MOON_CARD_ID)
		_moon_pick = "moon"
		_claim_reward(rest_btn)
		var mcard := CardRepo.load_json().get_card(MOON_CARD_ID)
		_collapse_to_leave()
		desc.text = MOON_TAKEN_DESC
		result_label.text = "「%s」已加入卡组，%d 金币留在了石台上。" % [
				mcard.card_name if mcard != null else "月亮", lost]
		result_label.add_theme_color_override("font_color", Color("b9c8e8"))
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
					rc.badge_color() if rc != null else Color("d89a2e"))
			if _reward_panel != null:
				_reward_panel.open()
		_redraw()
		return
	if _is_treasure():
		if _treasure_taken:
			_on_leave()
			return
		_treasure_taken = true
		_claim_reward(rest_btn)   # R147
		_collapse_to_leave()
		# R372（用户口径）：**免费**开箱、内容统一是卡牌 —— 不再扣 5 生命，
		# 也不再按 `treasure_relic` 旗标随机成道具（道具那一半整条分支已删）。
		# R119：卡牌奖励**先入队** → 奖励悬浮窗里看完三张候选再挑一张。
		RunState.queue_card_reward("normal")
		desc.text = "箱盖掀开，里面是一叠卡牌……\n请在上面的奖励悬浮窗里查看并挑走一张。"
		result_label.text = "开出卡牌奖励（待领：见奖励悬浮窗）"
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
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
	# R237：休息处「在这里休息」→ 回复 rest_heal_amount() 点生命（与「烤肉」二选一）。
	# 只有真正的休息节点才走这里（_is_rest 精确判 pending_node.type == "rest"）；
	# 未识别的事件类型仍然安全不动。
	if _is_rest():
		if _bbq_taken:
			return
		var gain := RunState.rest()
		# R246 附魔大师（6034）：休息的同一次里随机给一张卡附一个合规附魔。
		# 结算排在回血之后（回血先落，再谈附魔），结果写进同一行提示。
		var em := RunState.enchant_master_on_rest()
		_collapse_to_leave()
		var em_txt := ""
		if bool(em.get("ok", false)):
			em_txt = "；附魔大师给「%s」附上了「%s」" % [
					str(em.get("card", "")), CardData.enchant_name(str(em.get("ench", "")))]
		result_label.text = "篝火的温暖涌上心头……回复 %d 点生命（当前 %d / %d）%s" % [
				gain, RunState.hp, RunState.max_hp, em_txt]
		result_label.add_theme_color_override("font_color", UiTheme.SIDE_SELF_TEXT)
		_redraw()
		return
	return


func _setup_furnace() -> void:
	## R454 熔炉：按「本次可投入的道具」铺 0~3 个「投入 XXXX」选项。
	## 3 件 → 主 / 次 / 第三；2 件 → 主 / 次；1 件 → 只用主按钮；
	## **0 件 → 三个全收起来，只剩「离开」**（别留一个点不动的死按钮）。
	var repo := RelicRepo.load_json()
	if _furnace_invested >= 0:
		desc.text = FURNACE_DONE_DESC
		_collapse_to_leave()
		result_label.text = _furnace_result
		result_label.add_theme_color_override("font_color", Color("e8933a"))
		return
	desc.text = FURNACE_DESC
	if _furnace_opts.is_empty():
		rest_btn.visible = false
		leave_btn.text = "离开（道具栏里没有可投入的东西）"
		result_label.text = "炉子盯着你空空的双手，什么也没说。"
		result_label.add_theme_color_override("font_color", Color("9a968c"))
		return
	var btns: Array[Button] = [rest_btn, bbq_btn, alt_btn]
	for i in _furnace_opts.size():
		var b: Button = btns[i]
		var rel := repo.get_relic(_furnace_opts[i])
		var rname: String = rel.relic_name if rel != null else str(_furnace_opts[i])
		b.visible = true
		b.disabled = false
		# 「」标记 = 这个名字可以悬浮看详情（Mention 只认带标记的名字）
		b.text = "投入「%s」" % rname
		if rel != null and rel.is_legendary():
			b.text += "（传奇 · 换回 2 件）"
	leave_btn.text = "离开（不投入）"
	result_label.text = ""


func _furnace_take(slot: int, btn: Button) -> void:
	## R454 熔炉：把第 `slot` 个选项对应的道具投进炉子。
	## 结算全在 `RunState.furnace_invest()`（判据唯一口），这里只做文案与奖励悬浮窗。
	if _furnace_invested >= 0 or slot < 0 or slot >= _furnace_opts.size():
		return
	var rid: int = _furnace_opts[slot]
	var rel := RelicRepo.load_json().get_relic(rid)
	var rname: String = rel.relic_name if rel != null else str(rid)
	var res := RunState.furnace_invest(rid)
	if not bool(res.get("ok", false)):
		# 极端情况：选项是进房时摇的，期间道具被别的路径消耗掉了 → 只报一句，不崩
		result_label.text = "「%s」已经不在道具栏里了。" % rname
		result_label.add_theme_color_override("font_color", Color("c86a5a"))
		_redraw()
		return
	_furnace_invested = rid
	_claim_reward(btn)
	# 结算当刻就把节点标记完成：否则回标题 → 继续游戏会重进这间房，
	# 拿剩下的道具再投一轮（投入消耗的是道具，光靠道具栏拦不住重复刷）。
	if RunState.run_active:
		RunState.complete_current()
	_collapse_to_leave()
	desc.text = FURNACE_DONE_DESC
	var got: Array[int] = res.get("rewards", [])
	var names: Array[String] = []
	for gid: int in got:
		names.append("「%s」" % RunState.relic_display_name(gid))
	if names.is_empty():
		_furnace_result = "「%s」投进炉里，炉子只吐出一口热气——没有能给你的道具了。" % rname
	else:
		_furnace_result = "「%s」投进炉里，炉子吐出 %d 件道具：%s。请在奖励悬浮窗里收下。" % [
				rname, names.size(), "、".join(names)]
	result_label.text = _furnace_result
	result_label.add_theme_color_override("font_color",
			Color("e8933a") if bool(res.get("legendary", false)) else Color("c8a86a"))
	if _reward_panel != null and RunState.pending_reward_count() > 0:
		_reward_panel.open()
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
	result_label.text = "已接取 %d 张货物（3 费工事 0/6/0）——第二层第一个事件房兑付报酬。" % n
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
		RunState.sync_fatigue()   # R223 难度 5：巧克力回到 6 以上 → 疲惫出卡组
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
	for b: Button in [rest_btn, bbq_btn, alt_btn]:
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
	if alt_btn != null:
		alt_btn.visible = false
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


func _core_pair_available(repo: CardRepo) -> bool:
	## 「获取核心」能不能做：至少存在一对「祭品 → 接收者」，且接收者**还没附魔**。
	## 判据全在 RunState 的两个候选口里，场景不自己筛（口径唯一）。
	for i: int in RunState.core_contract_sources(repo):
		if not RunState.core_contract_targets(repo, i).is_empty():
			return true
	return false


func _setup_core_contract() -> void:
	## R458「契约的核心」（第二层专属）的选项铺排。
	##   · 选项 1 订立契约 → 道具「咒缚」；
	##   · 选项 2 获取核心 → **两段选卡**（先挑祭品、再挑接收者）；
	##   · 离开（什么都不做）。
	## ⚠️ 两段都在本场景用 `PickOverlay` 完成（不跳卡组编辑场景）：第一段只**记下**祭品
	##    下标（`_core_src`），真正落账发生在第二段确认时 —— 中途反悔一张都不扣。
	## ⚠️ 收尾态走 `_core_pick` 的两个分支直接收起：`_refresh()` 会重铺这三种事件，
	##    不这么写会把已经写完的结果行清掉。
	_update_core_icon()
	event_name.text = "契 约 的 核 心"
	rest_btn.visible = true
	alt_btn.visible = true
	leave_btn.visible = true
	leave_btn.disabled = false
	leave_btn.text = "什么都不碰（离开）"
	if _core_pick == "contract":
		desc.text = CORE_CONTRACT_DESC
		_collapse_to_leave()
		result_label.text = _core_result
		result_label.add_theme_color_override("font_color", Color("b06be0"))
		return
	if _core_pick == "core":
		desc.text = CORE_TAKEN_DESC
		_collapse_to_leave()
		result_label.text = _core_result
		result_label.add_theme_color_override("font_color", Color("b06be0"))
		return
	desc.text = CORE_DESC
	result_label.text = ""
	if RunState.has_relic(CORE_CURSE_ID):
		rest_btn.text = "契约已经签过了"
		rest_btn.disabled = true
	else:
		rest_btn.text = "订立契约（获得道具「咒缚」）"
		rest_btn.disabled = false
	# R458 修正：选项 2 只**收下道具**，兑现挪到「战斗中累计失去 15 点生命 →
	# 战斗结束的奖励页」。所以这里没有「当场选卡」，只按三态给文案：
	#   未持有 → 可拿；持有未成形 → 显示进度；已成形 → 提示去奖励页兑换。
	if RunState.has_relic(RunState.CORE_RELIC_ID):
		alt_btn.disabled = true
		if RunState.core_armed:
			alt_btn.text = "核心已经成形（战斗结束时在奖励页兑换）"
		else:
			alt_btn.text = "核心还在酝酿（累计失去 %d / %d 点生命）" % [
					RunState.core_lost, RunState.CORE_LOSS_NEED]
	elif _core_pair_available(CardRepo.load_json()):
		alt_btn.text = "获取核心（收下道具「核心」）"
		alt_btn.disabled = false
	else:
		alt_btn.text = "卡组里凑不出两张伤害技能牌"
		alt_btn.disabled = true
	_redraw()


func _core_take_contract() -> void:
	## 选项 1：收下道具「咒缚」（与「雪豹出现」拿烟斗同一条路：
	## `gain_relic` → 收起按钮 → 写结果行）。
	if _core_pick != "":
		_on_leave()
		return
	RunState.gain_relic(CORE_CURSE_ID)
	var rel := RelicRepo.load_json().get_relic(CORE_CURSE_ID)
	_core_pick = "contract"
	_claim_reward(rest_btn)
	desc.text = CORE_CONTRACT_DESC
	_core_result = "「咒缚」已收进道具栏：%s" % (rel.desc if rel != null else "")
	_collapse_to_leave()
	result_label.text = _core_result
	result_label.add_theme_color_override("font_color", Color("b06be0"))
	_redraw()


func _core_take_core() -> void:
	## 选项 2：收下道具「核心」（6059）。
	## ⚠️ 它**不是当场兑现**：战斗中累计失去 `RunState.CORE_LOSS_NEED` 点生命才成形，
	##    成形后由**这一场战斗结束时的奖励页**提供一次兑换（`RunState.queue_core_reward()`）。
	##    这里只把道具收进栏里，并把「怎么触发」写进结果行 —— 不写的话玩家会以为它没反应。
	if _core_pick != "":
		_on_leave()
		return
	if RunState.has_relic(RunState.CORE_RELIC_ID):
		alt_btn.disabled = true
		return
	RunState.gain_relic(RunState.CORE_RELIC_ID)
	_core_pick = "core"
	_claim_reward(alt_btn)
	desc.text = CORE_TAKEN_DESC
	_update_core_icon()
	_core_result = "「核心」收进了道具栏：战斗中累计失去 %d 点生命后成形，这一场结束时的奖励页里会多出一次兑换 —— 献祭一张伤害技能牌，把它第一段伤害附到另一张技能牌上。用掉之后失效。" % RunState.CORE_LOSS_NEED
	_collapse_to_leave()
	result_label.text = _core_result
	result_label.add_theme_color_override("font_color", Color("b06be0"))
	_redraw()


func _refresh() -> void:
	# R178：本次访问的奖励已领完 → 任何刷新都保持「只有一个离开」的收尾态
	#（_on_main 的休息分支等地方会再调 _refresh，不收住会把按钮文案改回去）。
	if _reward_claimed:
		_collapse_to_leave()
		return
	if _is_treasure() or _is_whisper() or _is_struggle() \
			or _is_gaze() or _is_pear() or _is_apple() or _is_hero() or _is_bluefish() \
			or _is_relic_chest() or _is_arcane() or _is_oblivion() \
			or _is_smith() or _is_delivery() or _is_delivery_done() \
			or _is_card_merchant() or _is_lake_lady() or _is_divination() \
			or _is_moon() or _is_snow_leopard() or _is_furnace() \
			or _is_core_contract():
		# ⚠️ R167：工匠（smith）**必须**在这张白名单里 —— 否则 _refresh() 会把它当成休息处，
		#   把上面刚设好的「锻造：…」按钮文案覆盖成「在这里休息（回复 N 生命）」，
		#   于是「选项文本与实际不符」（点了其实不回复生命）。
		return
	_refresh_bbq()
	# R178：休息处办完（烤肉）→ 也只留一个「离开」，结果行照写（收起按钮不影响它）。
	if _bbq_taken:
		bbq_btn.visible = false
		rest_btn.visible = false
		leave_btn.visible = true
		leave_btn.text = "离开"
		leave_btn.disabled = false
		_reward_claimed = true
		result_label.text = "「烤肉」已收进道具栏——进入 Boss 战时自动享用，回复 25% 最大生命。"
		result_label.add_theme_color_override("font_color", Color("d89a2e"))
		_redraw()
		return
	leave_btn.text = "离开（不烤肉）"
	result_label.text = ""


func _refresh_bbq() -> void:
	## 烤肉选项状态：持有「烤肉」时不可再选；被 Boss 战消耗掉后即可再次烤制。
	if RunState.has_relic(RunState.BARBECUE_RELIC_ID):
		bbq_btn.text = "已持有「烤肉」（Boss 战时自动消耗）"
		bbq_btn.disabled = true
	else:
		bbq_btn.text = "烤肉（获得「烤肉」，留到 Boss 战）"
		bbq_btn.disabled = false


func _apply_divination_text() -> void:
	## R308 占卜室的「已占卜」态：换成幻象文案 + 两个解读选项（阶段①）。
	bbq_btn.visible = true
	leave_btn.text = "离开（不去解读）"
	result_label.text = ""
	match _div_rolled:
		1:
			desc.text = DIV_WHALE_DESC
			rest_btn.text = "我会为它而战（获得「鲸鱼之怒」）"
			bbq_btn.text = "它将听我差遣（获得「许愿」）"
		2:
			desc.text = DIV_LIQUID_DESC
			rest_btn.text = "你会需要它（获得道具「泉水」）"
			bbq_btn.text = "它很危险（获得道具「思想钢印」）"
		3:
			desc.text = DIV_THORN_DESC
			rest_btn.text = "在充满困难的道路上前行（获得「烈火之剑」）"
			bbq_btn.text = "拥抱伤痛（获得道具「荆棘指环」）"
		_:
			desc.text = DIV_FEAST_DESC
			rest_btn.text = "是慷慨的赐予（获得道具「圣餐」）"
			bbq_btn.text = "是最后的怜悯（获得道具「雕像」）"
	rest_btn.visible = true
	rest_btn.disabled = false
	bbq_btn.disabled = false


func _resolve_divination(first: bool) -> void:
	## R308 占卜室 · 解读：按「第几种幻象 + 选了哪一项」发对应的卡 / 道具。
	## 全部走既有入口（`RunState.add_card` / `gain_relic`），不新造发放路径。
	var card_id := 0
	var relic_id := 0
	match _div_rolled:
		1:
			card_id = WHALE_CARD_ID if first else GameEngine.WISH_ID
		2:
			relic_id = GameEngine.SPRING_RELIC_ID if first else GameEngine.STEEL_STAMP_RELIC_ID
		3:
			card_id = GameEngine.FLAME_SWORD_ID if first else 0
			relic_id = 0 if first else GameEngine.THORN_RING_RELIC_ID
		_:
			relic_id = RunState.RELIC_SACRAMENT_ID if first else RunState.RELIC_STATUE_ID
	if card_id > 0:
		RunState.add_card(card_id)
		var c := CardRepo.load_json().get_card(card_id)
		_div_result = "「%s」已加入卡组。" % (c.card_name if c != null else str(card_id))
	elif relic_id > 0:
		RunState.gain_relic(relic_id)
		_div_result = "「%s」已收进道具栏。" % RunState.relic_display_name(relic_id)
	else:
		return
	_div_stage = 2
	_update_orb_vision()   # R511：解读完球里重新蒙雾
	_claim_reward(rest_btn if first else bbq_btn)
	_collapse_to_leave()
	desc.text = DIVINATION_DONE_DESC
	result_label.text = _div_result
	result_label.add_theme_color_override("font_color", Color("8a9ad8"))
	_redraw()


func _claim_rest_firewood() -> void:
	## R390 休息处 ·「添加柴火」：从卡组删除一张卡（三选一里的一支）。
	## 选卡 UI 与遗忘之泉共用 `deck_edit.tscn`（`pending_deck_edit = "delete"`），
	## 不新造一套；节点在这里就算走完 —— 回地图后不会再被送回同一个休息处。
	## ⚠️ 不在这里调 `_collapse_to_leave()`：马上跳场景了，它只会白闪一帧。
	if _reward_claimed or RunState.deck_ids.is_empty():
		return
	_claim_reward(alt_btn)
	RunState.complete_current()
	RunState.pending_deck_edit = "delete"
	SceneFx.goto("res://scenes/deck_edit.tscn")


func _claim_moon_coin() -> void:
	## R351 赏月 · 第三选项：「硬币」直接进卡组（不花钱，也没有别的代价）。
	if _moon_pick != "":
		_on_leave()
		return
	RunState.add_card(COIN_CARD_ID)
	_moon_pick = "coin"
	_claim_reward(alt_btn)
	var ccard := CardRepo.load_json().get_card(COIN_CARD_ID)
	_collapse_to_leave()
	desc.text = COIN_TAKEN_DESC
	result_label.text = "「%s」已加入卡组。" % (ccard.card_name if ccard != null else "硬币")
	result_label.add_theme_color_override("font_color", Color("d7c48a"))
	_redraw()


func _on_alt() -> void:
	## R305 卡片商人 · **随机折价**（第三选项）：随机失去一张非诅咒卡，换 100 金币。
	## R351 赏月也用它当「拿硬币」的按钮。
	sfx.play("click")
	if _is_core_contract():
		_core_take_core()
		return
	if _is_furnace():
		_furnace_take(2, alt_btn)
		return
	if _is_rest():
		_claim_rest_firewood()
		return
	if _is_moon():
		_claim_moon_coin()
		return
	if _is_martial():
		if _martial_pick != "":
			return
		# 挂单：只认**精英 / Boss** 的胜利（普通战斗原地不动）。
		RunState.queue_delayed_card(MARTIAL_PUNCH_ID, MARTIAL_PUNCH_BATTLES, true)
		_martial_pick = "punch"
		_claim_reward(alt_btn)
		_collapse_to_leave()
		desc.text = MARTIAL_PUNCH_DESC
		_martial_result = "「冲拳」已经挂在单上：再打赢 %d 场精英 / Boss 战斗就自动加入卡组。" \
				% MARTIAL_PUNCH_BATTLES
		result_label.text = _martial_result
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
		_redraw()
		return
	if _is_snow_leopard():
		if _snow_pick != "":
			return
		RunState.add_card(SNOW_LEOPARD_CARD_ID)
		_snow_pick = "cat"
		_claim_reward(alt_btn)
		var s_card := CardRepo.load_json().get_card(SNOW_LEOPARD_CARD_ID)
		_collapse_to_leave()
		desc.text = SNOW_CHEESE_DESC
		result_label.text = "「%s」已加入卡组：%s" % [
				s_card.card_name if s_card != null else "雪豹",
				CardText.naturalize(s_card.effect_text) if s_card != null else ""]
		result_label.add_theme_color_override("font_color", UiTheme.RARITY_RARE)
		_redraw()
		return
	if _is_adventurer():
		if _adv_pick != "":
			return
		# 燧石要玩家**在地图上选一格**：`gain_relic` 只把 `pending_relic` 置上，
		# 等这张事件页离开、回到地图时由 `map_scene` 进「选格模式」收尾。
		RunState.gain_relic(ADVENTURER_FLINT_ID)
		_adv_pick = "flint"
		_claim_reward(alt_btn)
		_collapse_to_leave()
		desc.text = ADVENTURER_FLINT_DESC
		_adv_result = "「燧石」已收进道具栏——回到地图后任选一格，" \
				+ "把那盏火点起来。"
		result_label.text = _adv_result
		result_label.add_theme_color_override("font_color", Color("d7a54a"))
		_redraw()
		return
	if not _is_card_merchant() or _merchant_done:
		return
	var res := RunState.vendor_discard_random()
	if not bool(res.get("ok", false)):
		result_label.text = "卡组里没有可以折价的卡（诅咒不算）。"
		result_label.add_theme_color_override("font_color", Color("c86a5a"))
		_redraw()
		return
	_merchant_done = true
	_claim_reward(alt_btn)
	_collapse_to_leave()
	desc.text = MERCHANT_DONE_DESC
	result_label.text = "「%s」被折价收走，换来 %d 金币。" % [
			str(res.get("lost_name", "")), int(res.get("gold", 0))]
	result_label.add_theme_color_override("font_color", Color("d7a54a"))
	_redraw()


func _on_bbq() -> void:
	## 休息处「烤肉」：获得事件道具「烤肉」（进入 Boss 战时自动消耗 → 回复 25% 生命）。
	## 奥秘之泉：这一路是「选择2 · 喝下泉水」→ 去卡牌奖励界面（限定效果 / 技能）。
	sfx.play("click")
	if _is_martial():
		if _martial_pick != "":
			return
		# 挂单：2 场战斗（普通 / 精英 / Boss 都算）后自动进卡组。
		RunState.queue_delayed_card(MARTIAL_KICK_ID, MARTIAL_KICK_BATTLES, false)
		_martial_pick = "kick"
		_claim_reward(bbq_btn)
		_collapse_to_leave()
		desc.text = MARTIAL_KICK_DESC
		_martial_result = "「飞踢」已经挂在单上：再打赢 %d 场战斗就自动加入卡组。" \
				% MARTIAL_KICK_BATTLES
		result_label.text = _martial_result
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
		_redraw()
		return
	if _is_furnace():
		_furnace_take(1, bbq_btn)
		return
	if _is_divination():
		if _div_stage == 1:
			_resolve_divination(false)
		return
	if _is_lake_lady():
		if _lake_done:
			return
		var truth := RunState.lake_lady_truth()
		if not bool(truth.get("ok", false)):
			return
		_lake_done = true
		_claim_reward(bbq_btn)
		# R488：拿到卡同样是**一次访问一次性**（重进本房不该再领一次史诗卡）。
		RunState.complete_current()
		_collapse_to_leave()
		desc.text = LAKE_DONE_DESC
		result_label.text = "实话换来的礼物：「%s」已加入卡组。" % str(truth.get("name", ""))
		result_label.add_theme_color_override("font_color", Color("8a9ad8"))
		_redraw()
		return
	if _is_card_merchant():
		if _merchant_done:
			return
		if RunState.deck_indices_with_cost(RunState.MERCHANT_MIN_COST).is_empty():
			return
		_merchant_done = true
		_claim_reward(bbq_btn)
		RunState.complete_current()
		RunState.pending_deck_edit = "vendor"
		SceneFx.goto("res://scenes/deck_edit.tscn")
		return
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
	# R224：休息处只剩这一个选项（篝火回血已移除），不再有「先休息过就不能再烤肉」的闸门。
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


func _ui_alt() -> void:
	## R365：第三选项（AltBtn）的入口 —— 卡片商人「折价」/ 赏月「拿走硬币」共用。
	_on_alt()


func _settle_before_pick() -> void:
	## R216：奖励界面要跳去选卡页之前，先把本次事件节点标记完成 —— 否则回地图还能再进一次。
	if RunState.run_active:
		RunState.complete_current()


func _cave_explore() -> void:
	## R467 洞穴 · 选项 1「探索」：本页直接换成洞穴战斗。
	## `pending_node` **保持事件房那一份**（type = "event"）—— 战斗结算就会按事件房处理
	## （不按精英发删卡 / 不掉精英道具），而关卡本身由 `pending_level` 指定。
	## 房间标记先做掉（`complete_current` 幂等，战斗胜利时 battle_scene 会再调一次）。
	RunState.pending_level = GameLevels.cave_level()
	RunState.complete_current()
	SceneFx.goto("res://scenes/battle.tscn")


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
		# R488：选项按钮里的提及也要能锁 ——「谎言：失去『X』」的卡名只出现在按钮文本里
		# （不锁住的话 headless 出图永远看不到那张实例卡的悬浮件）。
		if ref.is_empty():
			for hb: Dictionary in _ref_btn_hits:
				if str(hb["ref"].get("name", "")) == _tip_demo:
					ref = hb["ref"]
					_tip_anchor = (hb["rect"] as Rect2).position + Vector2(0, 24)
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
	return str(a["kind"]) == str(b["kind"]) and int(a["id"]) == int(b["id"]) \
			and int(a.get("deck_index", -1)) == int(b.get("deck_index", -1))


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


func _desc_visual_lines(font: Font, fs: int, width: float) -> Array[String]:
	## R519k：Label 的实际可见行。左右布局既左对齐又会自动折行，
	## 不能再拿 `desc.text.split("\n")` 的逻辑行冒充渲染行。
	## 用 TextParagraph 复算同一套自动折行，再从 TextServer 取每个可见行的原文区间。
	var out: Array[String] = []
	var logical_lines := desc.text.split("\n")
	if desc.autowrap_mode == TextServer.AUTOWRAP_OFF or width <= 1.0:
		for line: String in logical_lines:
			out.append(line)
		return out
	var ts := TextServerManager.get_primary_interface()
	for logical: String in logical_lines:
		if logical.is_empty():
			out.append("")
			continue
		var p := TextParagraph.new()
		p.width = width
		p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
				| TextServer.BREAK_GRAPHEME_BOUND | TextServer.BREAK_ADAPTIVE
		p.add_string(logical, font, fs)
		if p.get_line_count() == 0:
			out.append(logical)
			continue
		for li in p.get_line_count():
			var char_range: Vector2i = ts.shaped_text_get_range(p.get_line_rid(li))
			out.append(logical.substr(char_range.x, char_range.y - char_range.x))
	return out


func _ref_layout() -> void:
	## 命中表（**屏幕坐标**）：按 Label 的实际对齐与可见折行复算；
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
	var lines := _desc_visual_lines(font, fs, box.size.x)
	var y := box.position.y
	for line: String in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := box.position.x
		if desc.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x0 += (box.size.x - lw) * 0.5
		elif desc.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			x0 += box.size.x - lw
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
			var bref := {"name": m["name"], "kind": m["kind"], "id": m["id"]}
			# R488：湖中仙女的谎言按钮绑的是**卡组里那一个实例**（含附魔 / 本局成长），
			# 不是卡库原卡 —— 悬浮要看到「真会被删掉的那张」，同名卡才分得清。
			if b == rest_btn and _is_lake_lady() and not _lake_done \
					and bool(_lake_pick.get("ok", false)) \
					and int(m["id"]) == int(_lake_pick.get("card_id", -1)):
				bref["deck_index"] = int(_lake_pick.get("index", -1))
			_ref_btn_hits.append({"rect": b.get_global_rect(), "ring": ring,
					"corner": cr, "ref": bref})


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
	## R488：取卡走 `Mention.card_for()` —— 引用里绑了 `deck_index` 时给的是**卡组里那张实例**
	## （附魔 / 本局成长都在），否则退回卡库原卡。下面算摘要高度与画浮窗必须用同一张。
	var card: CardData = Mention.card_for(_hover_ref)
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
