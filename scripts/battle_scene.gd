extends Control
## 对战主界面（Godot 副本）—— 布局与 Python/tkinter 版 1280x720 设计一致。
##
## 交互与 tkinter 版保持一致：
##   * 点手牌选中 → 点自己半场空格上场；双击/再点法术直接使用
##   * 点自己单位 → 绿色可移动 / 红色可攻击 / 深红打 HP 高亮
##   * 寒冰护盾需要选目标：紫色高亮所有战场单位，点一个结算
##   * 右键 / 点空白取消；「回合结束」后敌方 AI 逐单位行动
##
## 窗口缩放由 Godot 的 canvas_items 拉伸模式天然支持，无需手工适配。

# ------------------------------------------------------------ 布局常量（设计坐标 1280x720）

const UiTheme = preload("res://scripts/ui_theme.gd")
const ScrollHint = preload("res://scripts/ui_scroll_hint.gd")
const MapBridge = preload("res://scripts/map_bridge.gd")
const UiRoll = preload("res://scripts/ui_roll.gd")
const UiPop = preload("res://scripts/ui_pop.gd")
const CardInfoBoxes = preload("res://scripts/card_info_boxes.gd")

const WINDOW_W := 1280.0
const WINDOW_H := 720.0
const CARD_W := 63.0
const CARD_H := 76.0
## R117：格子**不再是正方形**。
##   · 横边 `CELL_W` 的约束是「横置卡牌 + 左右各一个数值徽章半径」——
##     卡横置时盒宽 = CARD_H、徽章又一左一右骑在框上，横边不够就会让**相邻两列的
##     横置卡数字互相压住**（用户实测反馈）。102 对 76 + 2×8.3 = 92.6 留 9px 余量。
##   · 纵边就是历史名 `CELL`，受「6 行要塞进工具栏(36)与手牌(619)之间」的硬约束，
##     只能到 90（GRID_H = 540，棋盘下沿仍是 592，手牌不变量因此完全不动）。
## R123：格子整体放大 —— 棋盘格子区改成**可上下滚动**（滚轮 / 空格左键拖动），
## 6 行内容不再受「必须塞进 540px」的约束：
##   · 横向占满「效果区(398) → 右栏(776)」：左沿 404（效果区右沿 398 + 6px 间隙），
##     右沿 404 + 372 = 776 —— 右栏（敌方效果区 / 敌方 HP / 道具栏 / 牌库）一像素不动；
##   · 格子 102×90 → 124×110，战场卡随格子等比放大（BOARD_SCALE ≈ 1.216）；
##   · 内容总高 6×110 = 660 超出可视窗 540 → 需要滚动；R139 起边框贴着战场本体、
##     跟着一起滚，所以滚动范围把上下边框带也算进去（见 _grid_scroll_min/_max）。
const CELL_W := 124.0
const CELL := 110.0
const TAP_W := CARD_H
const TAP_H := CARD_W
const GRID_X := 404.0
const GRID_Y := 52.0
const GRID_W := 3.0 * CELL_W
const GRID_H := 540.0               # **可视窗**高度（下沿 592 不变；内容总高见下）
const GRID_CONTENT_H := 6.0 * CELL  # 6 行内容的总高（超出可视窗 → 需要滚动）
## 战场卡随格子等比放大（102 → 124 的比例）。
const BOARD_SCALE := CELL_W / 102.0
const BOARD_CARD_W := CARD_W * BOARD_SCALE
const BOARD_CARD_H := CARD_H * BOARD_SCALE
const BOARD_TAP_W := TAP_W * BOARD_SCALE
const BOARD_TAP_H := TAP_H * BOARD_SCALE
const GRID_SCROLL_STEP := 56.0      # 滚轮一步
## R137：棋盘边框（日漫西幻风）。四只角花来自 AI 生成素材 assets/ui/grid_frame.png
## （2x 分辨率）；四条直边用程序画的「暗石底 + 双金线」衔接 —— AI 原框接近方形，
## 直边要拉长 2 倍以上才能包住 3:4.6 的战场，花纹会拉成色斑，角块是局部采样
## （压 3~4 倍）仍在可读范围。
## ⚠️ R139：边框**锚在 3×6 战场本体（GRID_CONTENT_H）上**，不再是围可视窗的固定框 ——
## 拖动 / 滚轮滚动时边框跟着内容一起上下走。纵向溢出由后画的 _draw_grid_mask()
## 用不透明背景纹理裁掉，所以 _draw() 里**边框必须排在遮罩前面**。
## 每边厚度由现场空间逐边定（相对内容区外侧）：
##   左 12（392 起，效果卡右沿 390）/ 上 16（工具栏高 36）/ 右 16（右栏 794 起）/
##   下 10（滚到底时下沿 592 = 可视窗下沿）。角花向内容区伸 PROTRUDE(14px)，
## 只盖角格的空白边距（战场卡距格沿 23.7/8.8px，四个角都碰不到卡面）。
const GRID_FRAME_BAND_L := 12.0
const GRID_FRAME_BAND_T := 16.0
const GRID_FRAME_BAND_R := 16.0
const GRID_FRAME_BAND_B := 10.0
const GRID_FRAME_PROTRUDE := 14.0
## R146：遮罩（`_draw_grid_mask`）横向范围的**额外余量**。边框的金色描边（1.5px 线宽）与
## 外圈投影（`outer.grow(2.0)` + 3px 线宽）还会再往外探出几个像素 —— 开场放大时棋盘外溢，
## 余量不够就会在侧栏上漏出一条**通高竖金线**（实测 z=1.15 在 x≈822 处一条到底的金线）。
## ⚠️ 别调小于 4：漏出来的是 1px 级线条，肉眼在整图上极难发现，靠像素比对才抓得到。
const GRID_MASK_PAD := 6.0
## R136/R146：开场巡场 —— 镜头按**四段**走一遍战场，让玩家第一眼就知道它是 3×6：
##   ① 停在自己这半场（HOLD0）；② 平移到对方那半场、**同时放大到 ZOOM**；
##   ③ 停在对方那半场（HOLD1）；④ **拖回我方这边、同时还原到原大小**（BACK）。
## R137 把 HOLD0 从 0.30 提到 0.70（用户要求「至少停 0.5 秒」，太短还没看清自己半场就滑走）。
## R146 按用户口径补上 ② 的放大与 ④ 的「拖回来 + 还原」——
##   时间轴由 `intro_pose(t)` **唯一**给出（回归直接钉死它），这里只放各段时长。
const GRID_INTRO_DUR := 3.0
const GRID_INTRO_HOLD0 := 0.70
const GRID_INTRO_HOLD1 := 0.50
const GRID_INTRO_BACK := 0.90
## 推到对方那半场时的放大倍率（1.0 = 原大小）。⚠️ 别随手调大：棋盘左右几乎没有余量
## （左沿 404 距效果区右沿 398 只有 6px），放大后棋盘/边框的外溢全靠 `_draw_grid_mask`
## 把遮罩范围按同一比例摊开来裁 —— 调大要先看那张遮罩还盖不盖得住。
const GRID_INTRO_ZOOM := 1.15
# R127：双箭头相对棋盘可视窗上下沿的内缩量（ScrollHint.GAP + 6）。
#   ⚠️ 必须**小于** 128（棋盘下沿到手牌顶的距离），否则下箭头会被手牌盖掉。
const GRID_HINT_INSET := 22.0
const COST_X := 310.0
const COST_Y := GRID_Y
const ENERGY_H := 96.0         # 左栏顶部能量面板高度（下面是效果区）
const DECK_X := WINDOW_W - CARD_W - 60.0
const DECK_Y := WINDOW_H - CARD_H - 44.0
const DISCARD_X := DECK_X
const DISCARD_Y := DECK_Y - CARD_H - 52.0
## R140：这三块连成右列一竖 —— 「消耗区」在上、「弃牌区」居中（**位置不变**，用户口径）、
## 「卡组」在下。弃牌区不再显示顶牌卡面，改成 图标 + 张数徽章；卡组张数改成骑在卡背顶边上。
const VOID_X := DECK_X
const VOID_Y := DISCARD_Y - CARD_H - 26.0
const ZONE_ICON := 50.0     # 区域内图标的绘制边长（正方形素材等比缩进这个方框）
const ZONE_NAME_H := 14.0   # 区域名压条的厚度（压在方块下沿）
# ---- 手牌：比战场小卡大一号，卡身一路长到窗口下沿之外 ----
# 空间账：手牌区只有 592~720 这 128px。既然「底部不必完全显示」，
# 就把卡底往屏幕外沉 HAND_CROP_BOTTOM 像素，省下的位置全换成卡面尺寸：
# 卡顶下移 → 卡看着更贴底、也更大；沉出去的那截只有底部留白（内容按可见高度重锚）。
const COL_FRAME_STONE := Color("221a10")       # 边框直边的暗石底（与角花素材的深色石头同系）
const COL_FRAME_GOLD := Color("b9924a")        # 边框外沿金线
const COL_FRAME_GOLD_DIM := Color("6b5426")    # 边框外沿内侧的暗金细线
const COL_FRAME_GOLD_IN := Color("e6c87e")     # 边框内沿亮金收边（压住可视窗边界）
const COL_COST_LOW_BG := Color("1d7a3f")        # 减费后的费用圆（深绿底）
const COL_COST_LOW_FG := Color("b9f6ca")        # 减费后的费用数字（浅绿字，绿色系）
const COL_GUARD := Color("1d9e4f")              # 替 HP 承伤（森林守护/以太守卫/铁栅栏）：绿环标记
## R142：**可主动发动**（熊 8004「回春」）—— 亮黄绿脉动环 + 四向内箭头 + 「可发动 F」徽标。
## 用「黄绿」而不是普通绿：我方单位框本身就是深绿（SIDE_SELF），同色环会被读成「框变粗了」。
const COL_ACTIVATABLE := Color(0.78, 1.0, 0.35)
const COL_READY := Color(0.50, 0.90, 1.0)      ## R165「可行动」就绪光环（亮青，区别于黄绿「可发动」）
## R180：脉冲动画（呼吸/脉动光环）的重绘节流间隔。22fps 采样对 0.5s 周期的呼吸动画足够平滑，
## 同时把安卓 GL Compatibility 上「每帧全量 _draw」降到约 1/3 的调用频率。仅驱动持续型脉冲动画，
## 短时爆发特效（攻击/击破/飘字）不受影响、仍走正常帧率。
const PULSE_FRAME_MS := 45
const LP_MS := 500              # R186：触屏长按判定时长（毫秒）—— 长按 = 右键等价
const LP_SLOP := 18.0           # R186：长按允许的最大位移（px，超过视为拖拽）
const COL_TAUNT := UiTheme.STATE_TAUNT              # 嘲讽：战场单位的橙色脉冲光环（必须优先打它）
const COL_FROZEN := UiTheme.STATE_FROZEN             # 冰封（寒冰箭/冻结陷阱/冰冻战吼）：冷蓝脉冲环 + 寒霜（这回合动不了）
const COL_SLEEP := UiTheme.STATE_SLEEP              # 沉睡（恶魔鸭 9116）：紫脉冲环 + Zzz（还差 N 下挨打就醒）
const COL_FUSE := UiTheme.STATE_FUSE                # 铸造倒计时（R149）：橙红脉冲环 +「倒数 N」徽标
const COL_FIELD_SELF := Color("ffb03a")         # 场地效果（R74）：我方放的 —— 琥珀色斜纹 + 名字角标
const COL_FIELD_FOE := Color("ff5d5d")          # 敌方放的场地 —— 红斜纹（一眼分清敌我）
const COL_FIELD_PERSIST := Color("5ad0e6")      # 持续型场地（R83：清泉）—— 冷青，静止描边（不是陷阱）
## ⚠️ R117：这个倍数**由不变量反推**，不能随手取。手牌卡高被「抬手后卡顶
## 不盖战场下沿」卡死在 ≈119（见下面 OWN_HAND_Y 的推导）；战场卡从 70 长到 76
## 之后，倍数必须同步降下来（1.70 → 1.565），否则手牌会顶穿棋盘下沿。
## 手牌卡尺寸因此与 R116 完全一致（98.6 × 119）——手牌扇形布局一行都不用改。
const HAND_CARD_SCALE := 1.565                  # ≈ 119 / 76
const HAND_CARD_W := CARD_W * HAND_CARD_SCALE   # ≈ 98.6
const HAND_CARD_H := CARD_H * HAND_CARD_SCALE   # ≈ 119.0（整张，含沉出屏幕的部分）
const HAND_CROP_BOTTOM := 18.0                  # 卡底沉到窗口下沿之外多少像素
const OWN_HAND_Y := WINDOW_H - HAND_CARD_H + HAND_CROP_BOTTOM   # = 619（卡顶）
# ---- 手牌扇形布局 ----
# 手牌整体可用宽度：卡变宽（98.6）后要留神右边 x=900 起的道具栏 —— 最右那张会绕底部中心
# 转出去（sin12° × 露出高度 ≈ 21px），356 是「满手也不越界」的上限（见 test_smoke 的越界断言）。
const HAND_FAN_WIDTH := 356.0     # 手牌整体可用宽度（装不下就靠重叠压缩）
# R154：手牌羊皮纸底板的几何（扇形居中于 WINDOW_W/2；底板略宽于扇形活动范围）
const HAND_BASE_W := 420.0
const HAND_BASE_X := (WINDOW_W - HAND_BASE_W) / 2.0
const HAND_BASE_Y := 600.0        # 扇形卡顶 619、抬手最高 ~590 —— 板顶压在两者之间
const HAND_BASE_H := WINDOW_H - HAND_BASE_Y
const HAND_FAN_MIN_STEP := 0.40   # 最小步进 = 卡宽 × 此比例（即最多 60% 重叠）
const HAND_FAN_MAX_DEG := 12.0    # 两端最大倾角（度）
const HAND_FAN_DEG_PER := 4.0     # 相邻两张的倾角差（度）
const HAND_FAN_DROP := 4.0        # 扇弧两端相对扇心的下沉像素（正好把底边框沉掉）
# R114：数值徽章改成**骑在卡框上**（圆心在框线、一半露在框外）之后，
# 沉在窗口下沿之外的那截从「底部留白」变成了「四个数值徽章」——
# 抬手高度必须补上徽章外露的一个半径（手牌 k=1.7 → 约 12px）才看得见。
# ⚠️ 上限被一条**既有不变量**卡住（见 test_smoke `_check_hand_fan`）：
#     OWN_HAND_Y - HAND_FAN_HOVER_LIFT >= GRID_Y + GRID_H - 2   （= 590）
#   即「抬手后的卡顶不能盖住战场下沿」。619 - 28 = 591 ≥ 590 ✓ —— 28 就是安全上限，
#   不要为了露出更多徽章而调大它（会盖住棋盘单位）。徽章此时约 92% 可见，数字读得全。
const HAND_FAN_HOVER_LIFT := 28.0 # 悬停时抬手高度（纯显示，不影响命中判定）
const HAND_SELECT_RAISE := 28.0   # 选中手牌时抬起的高度
const INFO_X := 8.0
const INFO_W := 272.0   # 左栏（详细效果 / 对局记录）：宽一点，效果正文少折几行

# ------------------------------------------------------------ 颜色

const COL_BG := UiTheme.BOARD_BG
## R133：战斗背景改成「当层的地图底图」后，画面比原来那张平涂米黄**亮得多、也花得多**
## （实测平均亮度 165→180、标准差 14→33）→ 压一层暗罩，棋盘格线与右栏白字才读得清。
## 与地图页同一手法，只是**更淡**（战斗界面密得多，罩太厚会把底图闷死）。
const COL_BG_SCRIM := Color(0.03, 0.04, 0.07, 0.34)
const COL_CELL_LINE := UiTheme.BOARD_GRID_LINE
const COL_OWN_FRAME := UiTheme.SIDE_SELF
const COL_ENEMY_FRAME := UiTheme.SIDE_FOE
const COL_MOVE := Color(0.184, 0.682, 0.306, 0.55)
const COL_ATTACK := Color(0.831, 0.227, 0.184, 0.55)
const COL_HP := Color(0.545, 0.102, 0.102, 0.75)
const COL_SPELL := Color(0.416, 0.290, 0.839, 0.55)
const COL_FENCE_MERGE := Color(0.851, 0.545, 0.098, 0.60)   # 叠栅栏（栅栏修复术）：目标格 = 已有栅栏
## R102：两段式技能「已选中第一个单位」的标记 —— 金黄粗描边 + 角标「已选」。
## 与 COL_SPELL（候选目标）刻意区分开：那个是"还能点"，这个是"已经点过了"。
const COL_PICKED := Color(1.0, 0.784, 0.0, 0.95)
const COL_OPP_BACKROW := Color(0.541, 0.353, 0.165, 0.5)
const COL_OWN_BACKROW := Color(0.165, 0.353, 0.541, 0.5)
const COL_WIN := UiTheme.STAT_HEALTH
const COL_LOSE := Color("1d3557")
## 手卡「现在打出能吃到额外效果」的金色高亮（R65）：与「减费绿」区分开，一眼看出是收益提醒。
const COL_HAND_BONUS := UiTheme.ACCENT_LIT
## R117：拖拽时「松手即生效」的**区域**外框色。与目标格填充（绿=移动 / 紫=技能 /
## 橙=叠栅栏）和选中态（金黄）都不撞色 —— 它表达的是「一整块区域」，不是某一格。
const COL_DROP_ZONE := Color(0.13, 0.55, 0.86, 0.85)
## 拖拽「将要命中的那一格」的光圈色（原来直接写在 _draw_drag 里，R117 收成令牌）。
const COL_SPELL_RING := Color(0.55, 0.90, 1.00, 0.90)
# R242：AOE 释放范围（橙=波及格）· 自伤警告（红，脉冲）· 条件额外效果（金）
const COL_AOE := Color(0.95, 0.55, 0.20, 0.26)
const COL_AOE_EDGE := Color(0.98, 0.62, 0.24, 0.92)
const COL_AOE_DANGER := Color(0.95, 0.26, 0.26, 0.95)
const COL_BONUS := Color(1.00, 0.82, 0.29, 0.95)
## R118：左键误点空位后的「再点一次就取消」上膛色 —— 偏橙，与两段式技能的「已选」
## 金黄（COL_PICKED 1.0/0.784/0.0）明确分开，也压得住 `_draw_grid()` 已经画在
## 同一格上的绿 / 暗红**敌我框**（0.7 透明度的琥珀压上去会混成说不清的黄绿）。
const COL_CANCEL_ARMED := Color(1.00, 0.55, 0.10, 1.0)

# 战斗内地图总览（R128）：房间配色统一走 `UiTheme.MAP_NODE_COLORS`，
# 短标记 / 类型名统一走 `RogueMap.type_mark` / `type_label` —— 不再各存一份表。

# 攻击投射演出时间轴（比例 × ATK_DUR_MS）
const ATK_DUR_MS := 1500        # 总时长
const ATK_WINDUP_T := 0.10      # 开始后仰蓄力
const ATK_LAUNCH_T := 0.30      # 弹体发射
const ATK_IMPACT_T := 0.62      # 弹体命中目标
const DESTROY_HOLD_MS := 140    # 命中后卡牌「留一帧」再消失：先看得见伤害，再击破
const MOVE_SLIDE_BASE_MS := 160     # 移动滑行：起步耗时（1 格 = 420ms，与旧版一致）
const MOVE_SLIDE_PER_STEP_MS := 260 # 移动滑行：每多走 1 格再加这么久

# R288：通用效果演出（cue）的时间轴 —— 一段演出 = 一个镜头段，够玩家看清「谁对谁做了什么」。
const CUE_MS := 760              # 单个镜头段的长度（占时间让玩家反应，不是一帧闪过）
const CUE_CAM_MS := 300          # 镜头滑到目标格
const CUE_SHOT_U := 0.34         # 出图时钉住的演出进度（脉冲中段，环/线都还亮着）
const CUE_MERGE_MS := 900        # 同一笔结算里「发动 → 命中」的间隔内并成一条演出

# ------------------------------------------------------------ 状态

var repo: CardRepo
var engine: GameEngine
var selection = null            # ["hand", idx] / ["board", Vector2i] / null
var move_targets: Array[Vector2i] = []
var attack_targets_arr: Array[Vector2i] = []
var hp_targets_arr: Array[Vector2i] = []
var spell_pending: int = -1     # 手牌序号（-1 = 不在选目标模式）
var spell_targets: Array[Vector2i] = []
var _infiltrate_src := Vector2i(-1, -1)   # 潜入（9100）第一段选中的己方盟友格
## 「双向传送」（8061，R102）的**两段式**第一段：已选中的**第一个单位**所在格
## （敌我皆可，所以不像 `_infiltrate_src` 那样限己方）。第二段点另一个单位即交换。
var _swap_src := Vector2i(-1, -1)
## ── R209：手牌目标卡的三位「自己」下标（-1 = 不在选卡）──
## 「系统升级」8039 / 「回收」8064 / 「填充」9146 的目标都在**手牌里**（不是棋盘），
## 所以不能走 `spell_targets`（那套是棋盘格）。三者**统一**：点第二下只记下标，
## `_sync_pick()` 下一帧弹**全屏选卡页**，确认时才调 `cast_*` 结算。
## ⚠️ 旧版是「再点一张手牌」的两段式：手牌是扇形叠着画的，目标常被压住点不准，
##    用户实测报「除了填充，还有一些选手卡的没有弹出选卡界面」。别再写回点击式。
var _sys_upgrade_idx := -1
var _recycle_idx := -1
var _reload_idx := -1
var status_text := ""
## R123：棋盘滚动偏移（0 .. _grid_scroll_max()）；滚轮 / 空格左键拖动改变它。
var _grid_scroll := 0.0
## 左键在棋盘**可视窗内**按下 → 可能是想拖动棋盘：拖过阈值才算滚动（不再结算点击）；
## 松手时没拖过阈值就照常补发这次点击（保留原有点击语义）。
## ⚠️ 别再要求「点在空格」：可视窗里几乎每一点都落在某一格上（_cell_at 恒不为 null），
## 那条件恒不成立 —— 左键拖动会整个失效（R136 修的就是这个）。
var _grid_drag_arm := false
var _grid_dragging := false
var _grid_drag_pos := Vector2.ZERO
## R136：开场巡场已播时长（秒）；< 0 = 没在播（播完 / 被玩家打断 / 回放模式）。
var _grid_intro_t := -1.0
## R146：开场巡场当前的**棋盘缩放倍率**（1.0 = 原大小）。只由 `intro_pose()` 驱动；
## 玩家一打断就立刻归 1.0 —— 命中判定 `_cell_at` 不认识缩放，留在半路会整体错位。
var _grid_zoom := 1.0
## R197：敌方效果开场弹窗开着（入场巡场**完整播完**后弹一次；点任意处/Esc/右键关）。
## R215：**不点也会自己关** —— 5 秒后自动收起（倒计时画在底部提示行上）。
var _ee_popup := false
var _ee_popup_t0 := 0            # 弹窗开启时刻（msec）—— 自动关闭的计时起点
var _status_hold_until := 0     # 操作反馈的保护期：期间悬停文本不覆盖
## R118：左键点「空位」**不再一步取消**。为 true = 本轮的第一次空位点击已经发生 ——
## 选区、绿色移动格、红色攻击格、深红 HP 格**全部原样保留**（于是这时点目标照样能打），
## **再点一次空位**才真取消（含「已移动未攻击 → 放弃攻击并就地横置」）。
## 为什么：取消是不可逆的 —— 误点一下草地就永久废掉这一击，是玩家最常踩的坑。
## 右键 / Esc 仍是一步取消（想快速撤销的人并没有被拿走快路）。
## 归位口：`_clear_selection()` / `_select_board()`（选区一变就重新计）
var _cancel_armed := false
var _whisper_txt := ""          # 道具「鸭之低语」：本回合随机到的强化（常驻显示）
var _hover_relic_tip := ""      # 道具悬停：完整说明走浮动折行面板（工具栏一行放不下）
## R302：效果文本里「提到的卡 / 道具」的**命中矩形**（每帧由左栏绘制重建）。
## 以前这些摘要是**固定列在详情底部**的（用户口径：不要固定显示，只要悬停时弹窗）。
var _mention_hits: Array = []
var _hover_mention: Dictionary = {}   # 鼠标压在提及上 → 画真实卡面 / 道具说明
var _mention_pin: Dictionary = {}     # 触屏（安卓）：点一下钉住，再点别处撤掉
var _demo_tip_text := ""       # --relictip 演示：每帧重设悬停提示（warp 的合成移动会清掉一次性设置）
var _demo_hover_idx := -1      # --xtext 演示：每帧重设悬停手牌卡（合成鼠标移动会清掉一次性设置）
var _demo_pick_sel := -1       # --reloadpick 演示：选卡页展开后预选第 N 张（一次性，出图看选中态）

# 拖拽释放：按住技能/效果卡拖到目标格（或棋盘）上松手即生效
const DRAG_THRESHOLD := 14.0    # 超过此位移判定为拖拽（否则视为点击）
var _press_idx := -1            # 按下的手牌下标（-1 = 按下点不在手牌）
var _press_pos := Vector2.ZERO
var _drag_idx := -1             # 正在拖拽的手牌下标（-1 = 无）
var _drag_pos := Vector2.ZERO
## R186：触屏长按 = 右键（只认 InputEventScreenTouch；PC 鼠标永不进这条路径）。
var _lp_active := false
var _lp_fired := false
var _lp_pos := Vector2.ZERO
var _lp_t0 := 0
var _drag_spell_cells: Array[Vector2i] = []   # 拖拽中技能的有效目标格
var _drag_anywhere := false     # 拖到棋盘任意处即可释放（无目标技能/效果卡）
var _drag_place := false        # 拖拽的是随从/工事：落到自己半场空格放置
var _drag_place_cells: Array[Vector2i] = []   # 随从/工事的合法放置格（自己半场空格）
var _drag_to_effects := false   # R106：拖的是效果卡 → 可**直接拖到左侧效果区**启用
## R106：战场单位顶部徽标里**状态类**（增益/减益）最多画几条 —— 徽标是往上叠的，
## 条数多了会盖住上面一行的卡；完整逐条列表在左侧信息栏（悬停/选中可见）。
const MAX_STATUS_BADGES := 3


func _say(text: String) -> void:
	## 操作反馈消息：2.5 秒内不被悬停信息覆盖。
	status_text = text
	_status_hold_until = Time.get_ticks_msec() + 2500
var _ai_timer: Timer
var _bg_tex: Texture2D
var _back_tex: Texture2D
var _frame_tex: Texture2D      # R137：棋盘边框角花素材（assets/ui/grid_frame.png）
var _discard_tex: Texture2D    # R140：弃牌区图标（assets/ui/discard_icon.png）
var _void_tex: Texture2D       # R140：消耗（消失）区次元图标（assets/ui/void_icon.png）
var _hp_icon: Texture2D        # R156：双方血量图标（icon_health.png，与生命徽章同款血滴）
var _energy_icon: Texture2D    # R156：能量图标（icon_cost.png，与费用徽章同款水晶）
var _font: FontFile
var _font_bold: FontFile

# 关卡与教程：
var _cur_level: Dictionary = {}
var _tutorial: Array = []       # 教程步骤（Dictionary 数组，空 = 非教程关）
var tutorial_step := 0
var _tutorial_finished := true
var _level_menu: PopupMenu
const TUT_BAR_TOP := 36.0       # 工具栏高度之下
## R117：棋盘第一行从 y=136 上移到 52，引导条只剩 36..52 这 16px —— 装不下正文。
## 当前各级关卡的 `tutorial` 数组**全为空**（引导条是休眠代码），所以这里只把上限
## 收到 46（仍会盖住棋盘第一行上沿 30px）。⚠️ 将来若要真正启用教程，
## **必须先改版引导条**（改成侧栏或收窄成单行），否则会挡住敌方后排教学卡。
const TUT_BAR_MAX_H := 46.0

# 教程引导条控件（_ready 里构建）
var _tut_bar: Panel
var _tut_title: Label
var _tut_prog: Label
var _tut_body: Label
var _tut_task: Label
var _tut_check: Label
var _tut_next_btn: Button
var _tut_close_btn: Button

# 动画状态（tkinter 版做不到的部分）：
var _slides := {}               # Placement -> {from,to: 像素中心, start, dur[, pts]} 上场/移动
                                # pts = 逐格路径的中心点数组；给了就按它分段滑行（多格移动走真实轨迹）
var _attacks := {}              # Placement -> {dir, src, dst, start, dur}     分阶段攻击动画
var _delayed: Array = []        # {at, kind, data}                             命中/击破定时特效
var _ghosts: Array = []         # {center, name, start, dur}                  击破淡出
var _dying: Array = []          # {cell, card, p, hide_at}                    已归零但仍要显示到命中时刻的卡
var _floaters: Array = []       # {pos, text, col, start, dur}                伤害/治疗飘字
var _flashes := {}              # Placement -> {col, start, dur}              受击闪色覆盖
## R180：脉冲动画重绘节流。呼吸/脉动类光环（就绪/嘲讽/冰封/沉睡/铸造/屏障/可发动/
## 场地标记/取消环/地图绿环/棋盘双箭头）不再**每帧** queue_redraw，而是统一降到
## 每 `PULSE_FRAME_MS` 一次 —— 呼吸动画周期约 0.5s，22fps 采样视觉上依然平滑，
## 但把安卓 GL Compatibility 上的全量 _draw 调用从 60fps 砍到 22fps，CPU 负载降约 2/3。
## ⚠️ 短时爆发动画（攻击/击破/飘字/手牌飞/数字滚动）**不**走这里，仍保正常帧率。
var _pulse_redraw_at := 0
var _pulse_ms := 0              # R187：实际节流窗口（懒初始化；安卓 = PULSE_FRAME_MS×2，PC 不变）
# R151 批 1（动效设计 §三）：手牌因果动画 —— 抽牌飞入（P0-1）/ 弃牌·消耗飞出（P0-2）
var _hand_fly: Array = []       # {mode:"in"|"out_d"|"out_v"|"fade", card?, from/from_rect, slot?, start, dur}
var _hand_known: Array = []     # 手牌 id 快照（保序双指针 diff，见 _hand_sync）
var _hand_known_init := false   # 首次 sync 只建快照不播（开场发牌不飞，留给巡场）
var _flyout_skip: Array = []    # 本帧「是打出不是消失」的卡 id（place/spell/effect 事件喂入，sync 消费并清空）
var _flyout_skip_all := false   # batch_transfer（手牌洗回牌库）：整批移除不播飞出
var _flyin_skip: Array = []     # 本帧「来源不是抽牌堆」的入手卡 id（swap 顶回手）
var _deck_fly: Array = []       # R283：卡入牌库飞行动画 {card, from, start, dur, curse}
var _transform_fx: Array = []   # R284：变幻特效 {zone, slot, start, dur}（zone: hand/deck/discard）
var _earring_missed := 0        # 耳环连出期间压下的飞出数（>3 → 收尾合并一次整体淡出）
var _void_known := 0            # void_count 快照：增量 = 这段时间被「消耗」的张数（飞出改上飞）
# R151 批 1 · P0-4：出牌落位 —— 「place」事件用它把 _slides 的 from 换成真实松手/手牌位置
var _place_from := {}           # {pos, card_id, at}；_finish_play 武装，"place" 事件消费
# R151 批 1 · P0-3：能量变化量飘字（HP 掉血已有飘字体系，能量原来什么都没有）
var _energy_known := -1
# R151 批 2（动效设计 §四/§五）：回合归属 / 手牌下沉 / 冲击帧 / 力量跳动 / 治疗粒子 / 非法抖动
var _hand_turn_dy := 0.0     # P1-6/7：手牌区纵向偏移（敌方回合 +6 下沉；我方回合 −3 上浮）
var _turn_dim := 0.0         # P1-7：手牌区暗罩 alpha（敌方回合 0.22 —— 自绘卡面的「降饱和」等效）
var _impacts: Array = []     # {pos, start, dur}  P1-18：击破冲击白闪（60ms，锐利高光）
var _screen_flash := {}      # {start, dur}       P1-18：全屏黑白闪（仅 Boss 击破与胜利，≤40ms）
var _pow_fx: Array = []      # {cell, start, dur} P2-13：力量成长跳动 + 扩散环
var _heal_fx: Array = []     # {pos, start, dur, seed} P2-14：治疗上升光点
var _shake_card := {}        # {idx, start, dur}  P2-15：被拒的手牌回弹抖动
var _reject_flash := {}      # {"energy"?/"cell"?: {cell?, start, dur}} P2-15：目标红闪
var _hp_pending: Dictionary = {} # 尚未在「命中演出」中体现的待扣生命：
								 #   单位卡面 / HP 横幅 把显示数字冻结在「实际值 + 未演出伤害之和」，
								 #   等对应的 hit / hp_hit 定时特效触发时才移除这一笔，数字才往下掉。
var _bursts: Array = []         # {pos, start, dur, col, big}                 打击爆点（扩散环+火花）
# R288：通用效果演出队列 + 镜头跟随（唯一口）。一场演出 = 若干**镜头段**：
# 发动者与受影者能同屏就一段演完；不能同屏就一段一个目标，**轮流**滚过去。
var _cues: Array = []           # 待播 [{cells, rows, label, col, at}]
var _cue_cur: Dictionary = {}   # 正在播的那条
var _cue_t0 := 0                # 当前 cue 的起点（0 = 空闲）
var _cue_cells: Array = []      # 本条涉及的格（cells[0] = 发动者，其余 = 受影者）
var _cue_shots: Array = []      # 镜头段 [{rows, scroll}]
var _cue_home := 0.0            # 本条开始时的滚动位置（播完回到这里）
## R321：本条的**发动者**格（-1 = 没有发动者，只有「某格受了伤」）。
## 只有它存在时才画脉冲 / 光带 / 拉镜头 —— 见 `_draw_cues()` 的注释。
var _cue_src := Vector2i(-1, -1)
var _cam_from := 0.0
var _cam_to := 0.0
var _cam_t0 := 0
var _cam_ms := 0                # >0 = 镜头正在补间（玩家一操作就取消）
var _fx_claimed: Dictionary = {}   # Vector2i -> ms：这一格已有专属命中表现，通用演出让路
var _wake_rings: Array = []     # {pos, start, dur, col}                       恶魔鸭苏醒的挣脱环（R72）
var _shake_until := 0           # 屏幕震动截止时刻
var _shake_mag := 0.0           # 屏幕震动幅度（像素）

# 打磨：音效 / 回合横幅 / 胜利彩带 / 对局记录 / 结算覆盖层
var sfx: Sfx
var _banner := {}               # {text, col, start, dur}  回合切换大字横幅
var _confetti: Array = []       # {pos, vel, rot, vr, size, col}  胜利彩带
var _log_visible := false       # 对局记录面板开关
var _menu: UiMenu = null         # Esc 主菜单（R148）—— 顶栏「记录/音效/标题/选关/地图」的收容所
var _map_visible := false       # 冒险地图总览面板开关（R64：战斗内查看地图，只读）
# R127：滚动容器的「上下还能滚」提示开关 —— **只在**新玩家第一局为真（判据见 ScrollHint.is_new_player）。
# 地图总览 / 棋盘格子区都**不再画滚动条**，改画半透明双箭头（画法见 ScrollHint，规范 §4.12）。
# ⚠️ R141：**棋盘**已改成常显（不再看这个开关）—— 战场 3×6 上下有空间就画；
#        这一支现在只剩「地图总览」那类进新手的容器在用。
var _show_scroll_hint := false
var _effects_visible := false   # 效果区浏览面板开关（点左侧效果区查看）
var _enemy_effects_visible := false  # 敌方效果区浏览面板开关
var _deck_visible := false      # 卡组（抽牌堆）浏览面板开关（点卡组牌堆查看，不显示顺序）
## R207：**完整卡组**面板开关（顶栏「卡组」按钮）。用户口径：「战斗内上方应该查看
## 完整卡组，右下角才是查看现有卡组」—— 上方 = `RunState.deck_ids`（本局构筑，跨战斗、
## 含附魔）；右下牌堆 = `engine.state.deck`（本场还没抽到的牌）。两者**互斥**打开。
var _run_deck_visible := false
## 完整卡组面板的卡实例缓存（见 `_run_deck_cards()`；开 / 关面板时清空）
var _run_deck_cache: Array = []
var _void_visible := false      # 消耗区浏览面板开关（R155：点消耗区图标回看本局消失的卡）
var _zone_page := 0             # 区域浏览面板页码（R155 分页：滚轮 / ‹ › 翻页）
var _relics_visible := false    # 道具浏览面板开关（道具栏装不下时点它查看全部）
var _relic_scroll := 0.0        # 道具浏览面板滚动量（道具太多时滚轮翻动）
# 「英雄」（9023）的弃牌代价：上场前让玩家自己挑 4 张手牌丢掉
# _hero_pick_idx = 待上场的英雄手牌下标（-1 = 没有待付代价的卡）
var _hero_pick_idx := -1
var _hero_pick_cell := Vector2i(-1, -1)   # 英雄要落到的空格
var _pick: PickOverlay = null            # R189：全屏选卡页（8 套旧小面板的统一替换）
var _hover_card: CardData = null  # 鼠标悬停的卡（左侧信息栏优先显示）
var _hover_pl: Placement = null   # 悬停的战场单位（可显示当前生命）
var _hover_hand := -1             # 悬停的手牌下标（-1 = 无）：仅用于绘制时抬手
var _over_shown := false        # 结算覆盖层是否已弹出（边沿检测）
var _over_panel: PanelContainer
var _over_title: Label
var _over_hint: Label            # 结算面板副标题（难度档位信息等）
var _over_btn_restart: Button
var _over_btn_level: Button
var _over_btn_title: Button
var _run_boss_win := false      # run 结算：本场是否为 Boss 通关（决定按钮路由）
var _run_next_layer := 0        # Boss 通关后要进入的下一层（0 = 没有下一层 → 结束 run）
## R339：**进战斗之前**的一份局状态快照（战斗检查点写它，而不是写当下状态）。
## 为什么：`_load_entry_level()` → `start_game()` 会跑第 1 个我方回合，
## 而 lucky 7 的跨战斗计数就在那一步 +1。检查点若在这之后写盘，
## 「继续游戏」重打这一场就等于从「已 +1」的计数起步 → 每续一次多算一格（用户报的计数错乱）。
## 顺带把开场就改动的其它局状态（烤肉消耗 / 回血 / 随机源步进）一起回滚成开打前的样子。
var _pre_battle_snap: Dictionary = {}
var _reward_panel: RewardPanel = null   # R119：奖励悬浮窗（掉落道具 / 卡牌奖励都在这里处理）

# 联机模式（NetSession.active 时启用）：镜像引擎 + 动作收发回放
var _net_mode := false
var _net_queue: Array = []      # 收到的对方消息（待回放）
var _net_replaying := false     # 回放间隔锁（看清对方做了什么）
var _net_wait := 0.0

@onready var toolbar: Panel = $Toolbar
@onready var turn_label: Label = $Toolbar/TurnLabel
@onready var hp_strip: Control = $Toolbar/HpStrip
@onready var status_label: Label = $Toolbar/StatusLabel
@onready var log_btn: Button = $Toolbar/LogBtn
@onready var deck_btn: Button = $Toolbar/DeckBtn
@onready var map_btn: Button = $Toolbar/MapBtn
@onready var end_turn_btn: Button = $Toolbar/EndTurnBtn
@onready var menu_btn: Button = $Toolbar/MenuBtn
# R341 洞窟绳（6048）：Boss 以外的战斗、且还带着绳子时才显示（见 `_refresh_flee_btn`）。
@onready var flee_btn: Button = $Toolbar/FleeBtn


func _ready() -> void:
	# 顶栏的 HpLabel / StatusLabel 在 battle.tscn 里声明了溢出策略：
	# clip_text + text_overrun_behavior=3（省略号）。状态行会串进战斗日志，长度不可控，
	# 固定 310px 会把后半句静默切掉（R113 修的）。⚠️ .tscn 里不能写 # 注释，说明只能挂在这里。
	# 战斗背景（R133）：默认按**当层**取（关卡专属图在 load_level 里换）。
	_bg_tex = UiAssets.battle_bg("", RunState.current_layer)
	# R154：卡背换新素材（assets/ui/card_back.png，清单 §2.4）—— 右下「卡组」牌堆
	# 与抽牌动画共用 `_draw_card_back` / `_draw_card_back_fade`，换这里一处全跟着变。
	_back_tex = UiAssets.card_back()
	if _back_tex == null:
		_back_tex = load("res://assets/cardback.png")
	_frame_tex = load("res://assets/ui/grid_frame.png")
	_discard_tex = load("res://assets/ui/discard_icon.png")
	_void_tex = load("res://assets/ui/void_icon.png")
	_hp_icon = load("res://assets/ui/icon_health.png")
	_energy_icon = load("res://assets/ui/icon_cost.png")
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	end_turn_btn.pressed.connect(_on_end_turn)
	menu_btn.pressed.connect(_open_menu)
	flee_btn.pressed.connect(_on_flee)
	# R155：顶栏操作按钮 —— 记录（偏左）/ 卡组·地图（右侧）。不再只藏在 Esc 菜单里。
	log_btn.pressed.connect(_toggle_log)
	deck_btn.pressed.connect(_toggle_deck_panel)
	map_btn.pressed.connect(_toggle_map)
	hp_strip.draw.connect(_draw_hp_strip)
	# 齿轮图标**自绘**（字体里的 ⚙ 不保证有，缺字会变成一个方框）—— 见 UiTheme.draw_gear
	menu_btn.draw.connect(_draw_menu_gear)
	for b: Button in [log_btn, deck_btn, map_btn, end_turn_btn, menu_btn, flee_btn]:
		b.pressed.connect(func(): sfx.play("click"))
	_ai_timer = Timer.new()
	_ai_timer.wait_time = 1.6
	_ai_timer.timeout.connect(_ai_step)
	add_child(_ai_timer)
	_build_tut_bar()
	_build_level_menu()
	_build_over_panel()
	# R339：**必须在 `_load_entry_level()` 之前**抓 —— 那一句会跑开局第 1 个我方回合，
	#       跨战斗计数（lucky 7）当场 +1。检查点要的是「这一场开打之前」的局状态。
	if RunState.run_active:
		_pre_battle_snap = RunSave.snapshot()
	_load_entry_level()
	_mark_battle_checkpoint()
	# R113：顶栏按钮统一走 chip（实心 + compact —— 顶栏按钮只有 28px 高，标准内距会撑出格子）
	for _tb: Button in [log_btn, deck_btn, map_btn, end_turn_btn, menu_btn, flee_btn]:
		UiTheme.apply_chip(_tb, true, true)
	# R119：奖励悬浮窗 —— 战斗胜利后的掉落道具 / 卡牌奖励都先入队，由它逐项展示
	_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
	# R216：领到「要立刻选卡」的即时道具时，奖励界面会当场转去卡组选择页 ——
	# 跳走之前先让本场把尾收掉（房间标记完成 / Boss 推进层），否则结算会被甩掉。
	_reward_panel.on_before_pick = _settle_before_pick
	# R189：全屏选卡页 —— 乌鸦/鲸鱼/无尽/取牌/预判/命运/专注/英雄代价的统一入口。
	# 作为最后一个子节点挂上（盖住按钮栏，展开时吃掉全部点击）。
	_pick = PickOverlay.new()
	_pick.confirmed.connect(_on_pick_confirmed)
	_pick.cancelled.connect(_on_pick_cancelled)
	add_child(_pick)
	# 命令行 -- --screenshot / -- --demo：自动化演示与截图（验证视觉效果用）
	var args := OS.get_cmdline_user_args()
	_demo_args = args
	_shot_pending = "--screenshot" in args or "--demo" in args
	_show_scroll_hint = ScrollHint.is_new_player()   # ⚠️ 会读盘 → 只在 _ready 调一次
	_demo_pending = "--demo" in args
	if _shot_pending:
		_demo_frame = 0
		_shot_frame = 45 if "--spellshot" in args else 150  # 45 = 法术飘字进行中
	if "--customdeck" in args:
		pass  # 卡组构筑已移除（肉鸽版固定初始卡组），参数保留兼容旧命令
	# R325：`--diff N` = 难度档位（出图核验「难度加成仍是白字」用）。
	# ⚠️ 必须**先于** `--level` 生效 —— 敌方攻 / 血是在 load_level 里按难度缩放的。
	for i in args.size():
		if args[i] == "--diff" and i + 1 < args.size():
			RunState.set_difficulty(clampi(int(args[i + 1]), 0,
					RunState.DIFFICULTY_COUNT - 1))
	for i in args.size():
		if args[i] == "--level" and i + 1 < args.size():
			var li := int(args[i + 1])
			var levels := GameLevels.builtin_levels()
			if li >= 0 and li < levels.size():
				load_level(levels[li])  # 截图验证用：--level 0
		if args[i] == "--shotframe" and i + 1 < args.size():
			_shot_frame = maxi(int(args[i + 1]), 10)  # 截图时机（帧），捕弹体/爆点用
		if args[i] == "--shotms" and i + 1 < args.size():
			_shot_ms = maxi(int(args[i + 1]), 10)  # 截图时机（距演示动作的毫秒数）
		if args[i] == "--gridscroll" and i + 1 < args.size():
			# R139 演示：直接把棋盘滚动量钉在指定值（出图核验「边框跟着 3×6 战场本体滚」）。
			# 免等 3 秒巡场动画 —— 900 帧出图在本机要跑好几分钟（实测 ~5fps）。
			# ⚠️ 要写在 --level **之后**；load_level 会把 _grid_scroll 重置成 max。
			_grid_intro_t = -1.0
			_grid_scroll = clampf(float(int(args[i + 1])),
					_grid_scroll_min(), _grid_scroll_max())
		if args[i] == "--cuepin" and i + 1 < args.size():
			# R288 出图：跨屏演出有多个镜头段时，钉在第几段（0 = 发动者，1 = 第二个受影者…）
			_cue_pin = maxi(int(args[i + 1]), 0)
		if args[i] == "--gridzoom" and i + 1 < args.size():
			# R146 演示：把开场巡场的**缩放**钉在指定值（配 --gridscroll 出图核验
			# 「拖向敌方那半场时放大 / 拖回我方时还原大小」）。
			_grid_intro_t = -1.0
			_grid_zoom = clampf(float(args[i + 1]), 1.0, 2.0)
	if "--r328common" in args and engine != null:
		## R328 出图：**公用初始卡**（木栅栏 8001 / 攻击 8002）的卡面颜色 + 卡图跟着当前职业走。
		## 三张对拍（其余条件完全相同，只有职业不同）：
		##   `battle.tscn -- --screenshot --level 0 --r328common forest --shotframe 600`
		##   `... --r328common shadow` / `... --r328common mech`
		## 期望：森林=绿纸+爪击图 / 暗影=紫纸+匕首图 / 机械=黄铜纸+浮游炮图；
		##      木栅栏三张暂时都用同一张 8001.png（职业变体图还没做），但**纸色各自不同**。
		var rc_key := "forest"
		for i in args.size():
			if args[i] == "--r328common" and i + 1 < args.size():
				rc_key = args[i + 1]
		var rc_map := {"forest": PlayerClass.DRUID, "shadow": PlayerClass.ROGUE,
				"mech": PlayerClass.MECH}
		RunState.player_class = String(rc_map.get(rc_key, PlayerClass.DRUID))
		_grid_intro_t = -1.0            # 关掉开场巡场，钉死构图
		engine.ai_enabled = false
		engine.state.board.clear()
		engine.state.hand.clear()
		var rc_repo := CardRepo.load_json()
		engine.state.hand.append(CardData.from_dict(rc_repo.get_card(8001).to_dict()))
		engine.state.hand.append(CardData.from_dict(rc_repo.get_card(8002).to_dict()))
		engine.state.energy = 10
		status_text = "公用初始卡 · " + RunState.player_class
		_clear_hover_state()
		selection = null
		queue_redraw()
	if "--r288pulse" in args and engine != null:
		# R288 出图：通用效果演出 —— 虚骨龙吐息（我方 4,1 → 敌方 2,1，两格同屏一段演完）。
		# 期望画面：龙身两圈扩散脉冲 + 上方卡名标签「龙息」+ 指向受影者的光带。
		# 出图：`battle.tscn -- --screenshot --level 0 --r288pulse --shotframe 600`
		_cue_demo = true
		_grid_intro_t = -1.0            # 关掉开场巡场（它会抢镜头，出图必须钉死构图）
		engine.ai_enabled = false
		engine.state.board.clear()
		var rp_repo := CardRepo.load_json()
		engine.state.place(CardData.from_dict(rp_repo.get_card(9014).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(rp_repo.get_card(9001).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.state.hand.clear()
		status_text = "远古虚骨龙 · 龙息"
		queue_redraw()
	if "--r288span" in args and engine != null:
		# R288 出图：**跨屏轮流**取证 —— 发动者 (5,1) 与受影者 (0,1) 相隔 6 行，
		# 一屏塞不下（6*110=660 > GRID_H=540），演出必须切成两段轮流看。
		# 出图：`battle.tscn -- --screenshot --level 0 --r288span --shotframe 600`
		#       `battle.tscn -- --screenshot --level 0 --r288span --cuepin 1 --shotframe 600`
		_cue_demo = true
		_grid_intro_t = -1.0            # 关掉开场巡场（它会抢镜头，出图必须钉死构图）
		engine.ai_enabled = false
		engine.state.board.clear()
		var sp_repo := CardRepo.load_json()
		engine.state.place(CardData.from_dict(sp_repo.get_card(9014).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(sp_repo.get_card(9001).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		engine.state.hand.clear()
		status_text = "跨屏轮流：先看发动者，再看受影者"
		queue_redraw()
	if "--r288knife" in args and engine != null:
		# R288b 出图：弹跳飞刀（9160）—— 主刀 + 两跳合成**一条**演出。
		# R321 起：技能卡在手里、棋盘上没有「发动者」→ **只画三格落点环**，不连线、
		# 不挪镜头（用户口径：普通伤害不需要激光）。要看光带请用 --r288pulse（虚骨龙）。
		# 出图：`battle.tscn -- --screenshot --level 0 --r288knife --shotframe 600`
		_cue_demo = true
		_grid_intro_t = -1.0            # 关掉开场巡场（它会抢镜头）
		engine.ai_enabled = false
		engine.state.board.clear()
		var rk_repo := CardRepo.load_json()
		for rk_c: Vector2i in [Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 2)]:
			engine.state.place(CardData.from_dict(rk_repo.get_card(8003).to_dict()),
					rk_c, GameEngine.SIDE_OPPONENT)
		engine.state.hand.clear()
		status_text = "弹跳飞刀：1 费 · 主刀 5 伤 + 两跳各 3 伤"
		queue_redraw()
	if "--r285swap" in args and engine != null:
		# R285 出图：双向传送选中我方单位后，第二段候选**不能包含敌方后排**。
		# 布景：(4,1) 我方、(0,1) 敌方（敌方后排 = HP 行）、(2,2) 敌方中场。
		# 期望：只有 (2,2) 亮 —— (0,1) 换过去会把我方送进对方后排，候选里没有它。
		# 出图：`battle.tscn -- --screenshot --level 0 --r285swap --shotframe 600`
		engine.ai_enabled = false
		engine.state.board.clear()
		var rs_repo := CardRepo.load_json()
		var rs_ally: CardData = rs_repo.get_card(8003)
		var rs_foe: CardData = rs_repo.get_card(9001)
		engine.state.place(CardData.from_dict(rs_ally.to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(rs_foe.to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(rs_foe.to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(
				rs_repo.get_card(GameEngine.SWAP_UNITS_ID).to_dict()))
		_swap_src = Vector2i(4, 1)
		spell_pending = 0
		spell_targets = []
		for c: Vector2i in engine.state.board:
			if c != _swap_src and engine.swap_pair_allowed(_swap_src, c):
				spell_targets.append(c)
		spell_targets.sort()
		_demo_hover_idx = 0
		status_text = "双向传送：只能换中场，后排不给换"
		queue_redraw()

	if "--enchmark" in args and engine != null:
		# R214 演示：**真实的附魔数据**出图 —— 给卡组前 4 张各塞一种商店附魔
		# （走 `RunState.enchant_mod()` 唯一口，与商店买到的完全同源），再用本关重载一次。
		# 出图核验三处：① 手牌 / 战场卡面「费用正下方的附魔标记」；
		#   ② 左栏「附魔：」行（`_demo_hover_idx = 0` 常驻悬停第 1 张）；
		#   ③ 右上「牌库」面板（deck_viewer 走 build_deck，同 id 的附魔卡不再被并进原卡）。
		# 出图：`battle.tscn -- --screenshot --level 0 --enchmark --shotframe 20`
		if not RunState.run_active:
			seed(0x214)
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.ensure_deck_mods()
		# ⚠️ 按**商店的合法条件**挑卡（不然出图里会出现「工事带伤害 +10」这种玩家
		#    永远做不到的状态，图就没法用来验收）：费用 -1 要 cost>1 且非 X 费 /
		#    伤害 +10 只给技能卡 / 次元之力只给盟友·工事 / 保存任意。一张卡只吃一个附魔。
		var em_ids := ["costdown", "damage", "dimension", "save"]
		var em_used := {}
		var em_repo := CardRepo.load_json()
		for em_id in em_ids:
			for i in RunState.deck_ids.size():
				if em_used.has(i):
					continue
				var ec: CardData = em_repo.get_card(RunState.deck_ids[i])
				if ec == null:
					continue
				var em_ok := false
				match em_id:
					"costdown": em_ok = ec.cost > 1 and not ec.x_cost
					"damage": em_ok = ec.kind == "技能"
					"dimension": em_ok = (ec.kind == "盟友" or ec.is_fort()) \
							and not ec.has_affix("次元")
					"save": em_ok = true
				if em_ok:
					RunState.deck_mods[i] = RunState.enchant_mod(em_id)
					em_used[i] = true
					break
		var em_lvl: Dictionary = RunState.pending_level
		RunState.pending_level = {}
		load_level(em_lvl if not em_lvl.is_empty() else GameLevels.builtin_levels()[0])
		# 场上也摆一张带附魔的单位 —— 战场卡面（`on_board=true`）同样要画标记
		# （`Placement` 持有的是卡副本，附魔 id 随 to_dict 走过来，smoke 里也钉着这条）。
		for em_hi2 in engine.state.hand.size():
			var hc2: CardData = engine.state.hand[em_hi2]
			if hc2.has_enchant() and (hc2.kind == "盟友" or hc2.is_fort()) \
					and engine.state.unit_at(Vector2i(4, 1)) == null:
				engine.state.place(CardData.from_dict(hc2.to_dict()), Vector2i(4, 1),
						GameEngine.SIDE_SELF)
				break
		# 左栏「附魔：」行要看出图 → 悬停**第一张带附魔的手牌**（手牌是随机抽的，
		# 不能写死下标 0 —— 那张经常正好没附魔）。
		_demo_hover_idx = -1
		for em_hi in engine.state.hand.size():
			if (engine.state.hand[em_hi] as CardData).has_enchant():
				_demo_hover_idx = em_hi
				break
		status_text = "R214 演示：卡组前 4 张带附魔（费用正下方标记 / 左栏「附魔：」行 / 牌库面板）"
		queue_redraw()
	if "--over" in args:
		# 演示：直接进入结算（验证结算覆盖层 / 彩带 / 胜利音效）
		engine._finish("胜利", "演示：结算界面")
	if "--bosswin" in args and engine != null:
		# R179 演示：**Boss 通关结算**（核验短按钮文案 + Boss 档卡牌三选一）。
		# 必须配 `--level <Boss 关下标>` 用（`_run_boss_win` 由关卡 tier 决定）。
		# 出图：`-- --screenshot --level 26 --bosswin --shotframe 30`
		if not RunState.run_active:
			seed(0x179)
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.pending_node = {"type": "boss"}
		engine._finish("胜利", "演示：Boss 关卡结算")
	if "--relics" in args and engine != null:
		# 演示：右栏道具栏（截图验证用；放在 args 循环后，避免被 --level 重建覆盖）
		engine.self_relics = [6001, 6005, 6010]   # 初始白 / 奖励黄 / 事件紫
		_whisper_txt = "本回合造成的伤害 +1"
	if "--r343names" in args and engine != null:
		# R343 出图：道具栏 / 道具面板里「传奇 vs 普通」的名字色对比。
		# 出图命令：`-- --screenshot --r343names --shotframe 600`
		#           加 `--relicpanel` 看放大的道具面板（名字与标签是分开画的）。
		engine.self_relics = [RunState.MATCH_RELIC_ID, RunState.HARVEST_KNIFE_RELIC_ID]
		if "--relicpanel" in args:
			_relics_visible = true
		status_text = "传奇「采集刀」名字金橙，普通「火柴」仍是深棕"
		queue_redraw()
	if "--layer2" in args and engine != null:
		# 演示：第二层起始道具（截图验证用）—— 生蛋鸭开场鸭蛋 + 冰淇淋与汽水开场 -3 生命
		engine.self_relics = [6016, 6018]
		engine.apply_battle_start_relics(repo)
		status_text = "第二层起始道具：生蛋鸭（开场鸭蛋）+ 冰淇淋与汽水（开场 -3 生命）"
		queue_redraw()
	if "--p1fx" in args and engine != null:
		# R151 批 2 演示：把 P1/P2 新动画全部钉在中段（dur 拉长 → 慢帧截图也截得到）。
		# 出图命令：`-- --screenshot --level 0 --p1fx --shotframe 20`
		var pf_n := _now()
		# ① 摆一个我方单位 + 一个敌方单位（冲击白闪 / 力量跳动 / 治疗粒子 / 敌方红边的载体）
		engine.state.place(repo.get_card(8003), Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(1053), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		# ② P1-18 冲击白闪（钉在 t=0.5）
		_impacts.append({"pos": _cell_center(Vector2i(2, 1)), "sc": _grid_scroll, "start": pf_n - 30000, "dur": 60000})
		# ③ P2-13 力量跳动（钉在 t=0.5，弹跳峰值 1.35 + 扩散环中段）
		_pow_fx.append({"cell": Vector2i(4, 1), "start": pf_n - 30000, "dur": 60000})
		# ④ P2-14 治疗上升光点（钉在上升中段）
		for pf_i in 4:
			_heal_fx.append({"pos": _cell_center(Vector2i(4, 1)), "sc": _grid_scroll,
					"start": pf_n - 30000 - pf_i * 2000, "dur": 60000, "seed": pf_i})
		# ⑤ P1-6/7 敌方回合态（直接钉死缓动终值：红边呼吸 + 手牌下沉 + 暗罩 + 敌方能量框）
		engine.current_side = GameEngine.SIDE_OPPONENT
		_hand_turn_dy = 6.0
		_turn_dim = 0.22
		# ⑥ P2-15 拒绝抖动 + 能量面板红闪（钉在 t=0.5）
		if not engine.state.hand.is_empty():
			_shake_card = {"idx": 0, "start": pf_n - 30000, "dur": 60000}
		_reject_flash["energy"] = {"start": pf_n - 30000, "dur": 60000}
		status_text = "演示：P1/P2 新动画钉帧（敌方回合态 / 冲击闪 / 力量跳动 / 治疗粒子 / 拒绝抖动）"
		queue_redraw()
	if "--moveslide" in args and engine != null:
		# R171 演示：钉一段「移动滑行」中段（dur 拉长），配合 --gridscroll 验证滚动补正 ——
		# 修正前单位按「创建时滚动量」渲染、脱离棋盘点；修正后贴着格间轨道走。
		# ⚠️ sc 钉 max：本旗标在参数循环**之后**执行，此时 --gridscroll 已生效，
		#    要模拟「创建时滚动=max、之后玩家滚到 -16」必须显式写死。
		# 出图命令：`-- --screenshot --level 0 --moveslide --gridscroll -16 --shotframe 40`
		var ms_pl: Placement = null
		var ms_cell := Vector2i(-1, -1)
		for ms_pair in engine.state.iter_board():
			ms_cell = ms_pair[0]
			ms_pl = ms_pair[1]
		if ms_pl != null:
			# 取**最后**一个单位（通常在我方底排），从上一格滑入 —— 位移量看得见
			var ms_from := Vector2i(maxi(ms_cell.x - 1, 0), ms_cell.y)
			if ms_from == ms_cell:
				ms_from = Vector2i(ms_cell.x + 1, ms_cell.y)
			_slides[ms_pl] = {"from": _cell_center(ms_from), "to": _cell_center(ms_cell),
					"sc": _grid_scroll_max(), "from_grid": true,
					"start": _now() - 150, "dur": 180000}
		status_text = "演示：移动滑行钉帧（--gridscroll 验证滚动补正）"
		queue_redraw()
	if "--handfly" in args and engine != null:
		# R151 演示：P0 手牌因果动画钉在飞行中段（dur 拉长 → 慢帧截图也截得到）。
		# 出图命令：`-- --screenshot --level 0 --handfly --shotframe 20`
		var hf_n := _now()
		# ① P0-4 落位：走真实武装 + 出牌路径，再把 slide 拉长钉住（from_scale 视觉）
		var play_idx := -1
		for hi in engine.state.hand.size():
			var hc: CardData = engine.state.hand[hi]
			if (hc.kind == "盟友" or hc.is_fort()) and engine.cost_of(hc) <= engine.state.energy:
				play_idx = hi
				break
		if play_idx >= 0 and engine.state.unit_at(Vector2i(4, 1)) == null:
			_place_from = {"pos": Vector2(WINDOW_W / 2.0, OWN_HAND_Y - 60),
					"card_id": (engine.state.hand[play_idx] as CardData).id, "at": hf_n}
			engine.play_from_hand(play_idx, Vector2i(4, 1))
			var placed: Placement = engine.state.unit_at(Vector2i(4, 1))
			if placed != null and _slides.has(placed):
				_slides[placed]["start"] = hf_n - 60
				_slides[placed]["dur"] = 180000
		# ② P0-1/2：飞入卡背 ×2 + 弃牌飞出 + 消耗上飞（t 钉在 ~0.35）
		_hand_known = []
		for c in engine.state.hand:
			_hand_known.append(c.id)
		_hand_known_init = true
		var hn: int = engine.state.hand.size()
		if hn >= 1:
			_hand_fly.append({"mode": "in", "card": engine.state.hand[0],
					"from": Vector2(DECK_X + CARD_W / 2.0, DECK_Y + CARD_H / 2.0),
					"slot": 0, "start": hf_n - 21000, "dur": 60000})
		if hn >= 2:
			_hand_fly.append({"mode": "out_d", "card": engine.state.hand[1],
					"from_rect": _hand_old_rect(maxi(hn, 4), 2),
					"start": hf_n - 21000, "dur": 60000})
		if hn >= 3:
			_hand_fly.append({"mode": "out_v", "card": engine.state.hand[2],
					"from_rect": _hand_old_rect(maxi(hn, 4), 1),
					"start": hf_n - 21000, "dur": 60000})
		status_text = "演示：手牌飞行动画钉帧（飞入 ×1 / 弃牌 ×1 / 消耗 ×1 / 落位缩放 ×1）"
		queue_redraw()
	if "--icecream" in args and engine != null:
		# 演示：冰淇淋与汽水（6016）—— 第 1 回合 +4 能量 / 多抽 3 张 → 台词飘字。
		# 必须重跑 load_level：第 1 回合结算发生在 start_game 内部，
		# 而 load_level 会用 RunState.relics 覆盖 engine.self_relics。
		RunState.relics = [6016]
		load_level(GameLevels.builtin_levels()[0])
		status_text = "冰淇淋与汽水：第 1 回合 +4 能量 / 多抽 3 张 ——「你跑不过我你信吗」"
		_shot_t0 = _now()
		queue_redraw()
	if "--fan" in args and engine != null:
		# 演示：扇形手牌 + 手牌上限 —— 继续抽到满手 10 张（第 3 次会广播 hand_full），
		# 并把中间一张伪装成「悬停抬起」（截图验证用）
		engine._draw_many(4)
		_hover_hand = engine.state.hand.size() / 2
		# 悬停 = 抬手 + 左侧详细效果面板（真机上是同一件事，截图要一起验证）
		_hover_card = engine.state.hand[_hover_hand]
		status_text = "扇形手牌：%d/%d 张（重叠 + 弧线），悬停抬起" % [
				engine.state.hand.size(), FieldState.HAND_LIMIT]
		_shot_t0 = _now()
		queue_redraw()

	if "--hero" in args and engine != null:
		# 演示：二层事件「绝赞五换一」的奖励卡「英雄」（9023）——
		# 上场必须额外丢弃 4 张手牌 → 直接打开「选择 4 张丢弃」面板（截图验证用）。
		var hero_card := repo.get_card(GameEngine.HERO_CARD_ID)
		if hero_card != null:
			while engine.state.hand.size() < 6:   # 英雄 + 至少 5 张可弃的
				if engine.state.draw() == null:
					break
			engine.state.hand.append(hero_card)
			_hero_pick_idx = engine.state.hand.size() - 1
			_hero_pick_cell = Vector2i(4, 1)
			status_text = "英雄的代价：选择 4 张手牌丢弃"
			_shot_t0 = _now()
			queue_redraw()
	if "--wmheal" in args and engine != null:
		# 演示：白魔法师回合开始的治疗（白魔法师压到 30%、骑士压到 40% →
		# 百分比最低的是白魔法师 → 结束回合后它给自己 +10）
		for c: Vector2i in engine.state.board.keys():
			var pp: Placement = engine.state.board[c]
			if pp.card.id == 9001:
				pp.health = 12          # 12/30 = 40%
			elif pp.card.id == 9021:
				pp.health = 30          # 30/100 = 30% ← 百分比最低
		_on_end_turn()
		_shot_t0 = _now()
	if "--pear" in args and engine != null:
		# 演示：鸭梨（6019）——我方 HP 受伤 → 最大生命 +1（只提高上限，不回复生命）
		engine.self_relics = [6019]
		var pear_before: int = engine.state.max_hp_self
		engine._damage_player(GameEngine.SIDE_SELF, 5, "演示：鸭梨")
		status_text = "鸭梨：受到 5 点伤害 → 最大生命 %d → %d（当前生命不回复）" % [
				pear_before, engine.state.max_hp_self]
		_shot_t0 = _now()
		queue_redraw()
	if "--bossnext" in args and engine != null:
		# 演示：第一层 Boss 通关 → 结算面板出现「进入第二层」按钮（截图验证用；
		# 配合 --level <Boss 关下标>）
		RunState.run_active = true
		RunState.current_layer = GameLayers.LAYER_DEFAULT
		RunState.hp = 30
		RunState.pending_node = {"type": "boss"}
		engine._finish("胜利", "演示：第一层 Boss 通关")
		queue_redraw()
	if "--newcards" in args and engine != null:
		# 演示：三张新卡（2026-09-30）的视觉验证 ——
		#   协同攻击 9035：我方场上 2 个盟友 → 实际费用 3-2=1，手牌费用圆显绿
		#   森林守护 9037：给一个盟友加「守护」→ 战场单位画绿环
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.COORD_ATTACK_ID))
		engine.state.hand.append(repo.get_card(GameEngine.BEAST_HEART_ID))
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)  # 农民（盟友）
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)  # 农民（盟友）
		engine._forest_guard(GameEngine.SIDE_SELF, Vector2i(4, 0))   # 4,0 的农民获得森林守护（绿环）
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "三张新卡：协同攻击（2 盟友 → 费用 3→1，绿色）+ 森林守护（绿环）"
		_shot_t0 = _now()
		queue_redraw()
	if "--reloadpick" in args and engine != null:
		# 演示（R205）：填充（9146）现在**弹全屏选卡页**选目标 —— 出图核验候选、描述条与底栏按钮
		# （`_sync_pick()` 在 `_process` 里自动 open）。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(8002))                  # 攻击（候选）
		engine.state.hand.append(repo.get_card(GameEngine.RELOAD_ID))  # 填充（自己，不入候选）
		engine.state.hand.append(repo.get_card(8004))                  # 熊（候选）
		engine.state.energy = 3
		_reload_idx = 1
		# 选卡页由 `_sync_pick()` 在 `_process` 里自动开（`_ready` 阶段 anchors 还没结算，
		# 这里 open 会告警「size overridden after _ready」）→ 只记下「展开后预选第 1 张」。
		_demo_pick_sel = 0
		status_text = "R205：填充 → 弹出选卡页，点一张手牌变形成聚能炮击"
		_shot_t0 = _now()
		queue_redraw()
	if "--transcendvoid" in args and engine != null:
		# 演示（R213）：超越极限（8053）带「次元」→ 打出后进**消耗区**（右列 VOID），
		# 不再进弃牌区。出图核验：`battle.tscn -- --screenshot --transcendvoid --shotframe 20`
		RunState.player_class = PlayerClass.MECH
		engine.state.board.clear()
		engine.state.discard.clear()
		engine.state.void_cards.clear()
		engine.state.void_count = 0
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.TRANSCEND_ID).to_dict()))
		engine.state.energy = 5
		engine.use_spell(0, Vector2i(4, 1))
		status_text = "R213：超越极限带「次元」→ 打出后进消耗区（VOID %d / 弃牌区 %d）" % [
				engine.state.void_count, engine.state.discard.size()]
		_shot_t0 = _now()
		queue_redraw()
	if "--reloaddrag" in args and engine != null:
		# 演示（R213）：填充**拖拽也能发动** —— 拖到棋盘任意处松手 = 弹选卡页。
		# 出图核验三件事：① 棋盘整片「可释放区域」外框；② 标签写「松手 → 弹出选卡页」
		# （不是含糊的「可释放区域」，免得玩家以为拖上去就直接打出去了）；
		# ③ 卡跟着光标走。出图：`battle.tscn -- --screenshot --reloaddrag --shotframe 20`
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.RELOAD_ID))
		engine.state.hand.append(repo.get_card(8002))
		engine.state.hand.append(repo.get_card(8004))
		engine.state.energy = 3
		_start_drag(0, _hand_rect(0).get_center())
		_drag_pos = _cell_center(Vector2i(4, 1))
		status_text = "R213：填充拖到棋盘任意处松手 → 弹出选卡页（拖拽也能发动）"
		_shot_t0 = _now()
		queue_redraw()
	if "--sysuppick" in args and engine != null:
		# 演示（R209）：系统升级（8039）也弹全屏选卡页 —— 候选**只列盟友 / 工事**，
		# 技能卡（攻击 8002）不进候选（旧点击式会让人点了才被拒）。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(8004))                  # 熊（候选）
		engine.state.hand.append(repo.get_card(GameEngine.SYS_UPGRADE_ID))
		engine.state.hand.append(repo.get_card(8002))                  # 攻击（技能，不入候选）
		engine.state.energy = 3
		_sys_upgrade_idx = 1
		_demo_pick_sel = 0
		status_text = "R209：系统升级 → 选卡页只列盟友 / 工事（技能卡不在候选里）"
		_shot_t0 = _now()
		queue_redraw()
	if "--recyclepick" in args and engine != null:
		# 演示（R209）：回收（8064）—— 候选 = 手里**任意**一张卡（技能卡也能回收）。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(8002))                  # 攻击（技能，候选）
		engine.state.hand.append(repo.get_card(GameEngine.RECYCLE_ID))
		engine.state.hand.append(repo.get_card(8004))                  # 熊（候选）
		engine.state.energy = 3
		_recycle_idx = 1
		_demo_pick_sel = 0
		status_text = "R209：回收 → 选卡页列出全部手牌（除回收自己）"
		_shot_t0 = _now()
		queue_redraw()
	if "--lightenpick" in args and engine != null:
		# 演示（R269）：轻量化（8068）也有全屏选卡页 —— 候选**只列盟友**
		# （工事不进候选：移速对工事恒为 0，用户口径是「一个随从」；技能卡同理）。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(8004))                  # 熊（候选）
		engine.state.hand.append(repo.get_card(GameEngine.HAND_LIGHTEN_ID))
		engine.state.hand.append(repo.get_card(8001))                  # 木栅栏（工事，不入候选）
		engine.state.hand.append(repo.get_card(8002))                  # 攻击（技能，不入候选）
		engine.state.energy = 9
		_sys_upgrade_idx = 1
		_demo_pick_sel = 0
		status_text = "R269：轻量化 → 选卡页只列盟友（工事 / 技能卡不在候选里）"
		_shot_t0 = _now()
		queue_redraw()
	if "--sharedshield" in args and engine != null:
		# 演示（R269）：共享护盾（8069）→ 己方盟友挂字段「共享护盾」+ 算一层改造；
		# 之后**我方 HP 要掉血时改由它承受**（战场绿环与结算都读 `absorbs_for_hp()`）。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.SHARED_SHIELD_ID).to_dict()))
		engine.use_spell(0, Vector2i(4, 1))
		var r269_demo_tp: Placement = engine.state.unit_at(Vector2i(4, 1))
		engine._damage_player(GameEngine.SIDE_SELF, 5, "演示：共享护盾")
		_hover_card = r269_demo_tp.card
		_hover_pl = r269_demo_tp
		_hover_hand = -1
		status_text = "R269：共享护盾 → 树人 %d 层改造；我方 HP 吃 5 点全由它承受（HP %d / 树人 %d）" % [
				r269_demo_tp.upgrade_stacks, engine.state.hp_self, r269_demo_tp.health]
		_shot_t0 = _now()
		queue_redraw()
	if "--nightduck" in args and engine != null:
		# 演示（R270）：夜鸭 9027 的「惧光」—— **奇数回合**移速 -1、攻击距离 -1、力量减半。
		# 配 `--level 11`（夜鸭阵：中排两只夜鸭）出图；再加 `--nightduckeven` 看偶数回合对照。
		engine.turn_number = 2 if "--nightduckeven" in args else 1
		engine._refresh_night_owl()
		var r270_p: Placement = null
		for cc: Vector2i in engine.state.board:
			var q: Placement = engine.state.board[cc]
			if q.card != null and q.card.id == GameEngine.NIGHT_DUCK_ID:
				r270_p = q
				break
		if r270_p != null:
			_hover_pl = r270_p
			_hover_card = r270_p.card
			_hover_hand = -1
			_banner = {}   # 出图清横幅：否则「我方回合 · 第 N 回合」会压住卡顶的惧光徽标
			status_text = "R324：夜鸭 第 %d 回合 → 场上 速 %d / 攻程 %d / 攻 %d（卡面 %d / %d / %d）" % [
					engine.turn_number, r270_p.effective_speed(), r270_p.effective_range(),
					r270_p.effective_power(),
					r270_p.card.move_speed, r270_p.card.attack_range, r270_p.card.power]
		_shot_t0 = _now()
		queue_redraw()
	if "--r271" in args and engine != null:
		# 演示（R271）：创意（8070）—— 效果区一张 → **回合开始**选一张手卡变形成一张
		# 随机「被改造时有额外效果」的卡，并使其获得改造：生命 +2。
		# 出图看的是**选卡页**（`_sync_pick()` 每帧驱动，pending 一置上就弹出）。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		for r271_nid: int in [8003, 8019, 8055]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(r271_nid).to_dict()))
		engine.state.effects.clear()
		engine.state.effects.append(
				CardData.from_dict(repo.get_card(GameEngine.CREATION_ID).to_dict()))
		engine.state.energy = 7
		engine._creation_tick(GameEngine.SIDE_SELF)
		status_text = "R271：创意（8070）→ 回合开始，选 1 张手牌变成随机「被改造有额外效果」的卡，并获改造：生命 +2"
		_shot_t0 = _now()
		queue_redraw()
	if "--r271cannon" in args and engine != null:
		# 演示（R271）：报废（8071）—— 手牌里**其他所有卡**变成「聚能炮击」，
		# 且这些卡**本回合**费用为 0（左栏「费用 0」；离开手卡即恢复原价 1）。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.SCRAP_ID).to_dict()))
		for r271_nid2: int in [8003, 8019, 8055]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(r271_nid2).to_dict()))
		engine.state.energy = 9
		engine.use_spell(0)
		if not engine.state.hand.is_empty():
			_hover_card = engine.state.hand[0]
			_hover_hand = 0
			_hover_pl = null
		status_text = "R271：报废（8071）→ 手牌其余 %d 张全变「聚能炮击」，本回合费用 %d（原价 1）" % [
				engine.state.hand.size(), engine.cost_of(engine.state.hand[0]) if not engine.state.hand.is_empty() else -1]
		_shot_t0 = _now()
		queue_redraw()
	if "--r271mnemo" in args and engine != null:
		# 演示（R271）：谟涅摩叙涅（8072）—— 在场时**所有敌人力量 -X**（X = 本卡改造层数）。
		# 这里给 2 层改造 → 每个敌人 -2 力；悬停一个敌人看左栏力量被压后的数值。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 7
		var r271_mn: CardData = CardData.from_dict(
				repo.get_card(GameEngine.MNEMOSYNE_ID).to_dict())
		r271_mn.upgrade_stacks = 2
		engine.state.place(r271_mn, Vector2i(4, 1), GameEngine.SIDE_SELF)
		var r271_mn_p: Placement = engine.state.unit_at(Vector2i(4, 1))
		if r271_mn_p != null:
			r271_mn_p.upgrade_stacks = 2
		engine._refresh_mnemosyne()
		var r271_enemy: Placement = null
		for r271_c: Vector2i in engine.state.board:
			var r271_q: Placement = engine.state.board[r271_c]
			if r271_q != null and r271_q.owner == GameEngine.SIDE_OPPONENT:
				r271_enemy = r271_q
				break
		if r271_enemy != null:
			_hover_pl = r271_enemy
			_hover_card = r271_enemy.card
			_hover_hand = -1
			status_text = "R271：谟涅摩叙涅 %d 层改造 → %s 力量 %d（卡面 %d）" % [
					r271_mn_p.upgrade_stacks if r271_mn_p != null else 0,
					r271_enemy.card.card_name, r271_enemy.effective_power(),
					r271_enemy.card.power]
		_shot_t0 = _now()
		queue_redraw()
	if "--r271daedalus" in args and engine != null:
		# 演示（R271）：代达罗斯（8060）重做 —— 入场时**本次对战中每用过一张聚能炮击 → 生命 +3**，
		# 且本回合手卡里的「聚能炮击」费用为 0。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.self_cannon_plays = 3
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.ENERGY_CANNON_ID).to_dict()))
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.ENERGY_CANNON_ID).to_dict()))
		var r271_dd: CardData = CardData.from_dict(repo.get_card(GameEngine.DAEDALUS_ID).to_dict())
		engine.state.place(r271_dd, Vector2i(4, 0), GameEngine.SIDE_SELF)
		var r271_dp: Placement = engine.state.unit_at(Vector2i(4, 0))
		if r271_dp != null:
			engine._daedalus_enter(r271_dp)
			_hover_pl = r271_dp
			_hover_card = r271_dp.card
			_hover_hand = -1
			status_text = "代达罗斯 16+3×%d=%d 血 / 手卡炮击 %d 费" % [
					engine.state.self_cannon_plays, r271_dp.health,
					engine.cost_of(engine.state.hand[0]) if not engine.state.hand.is_empty() else -1]
		_shot_t0 = _now()
		queue_redraw()
	if "--r288fort" in args and engine != null:
		# 演示（R288）：失控要塞（9161）—— 本次对战中每用过一张「聚能炮击」
		# → 随机释放一张机械之心技能卡（随机目标 / 落点，不消耗费用）。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 6
		engine.state.self_cannon_plays = 3
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.OUT_OF_CONTROL_FORT_ID).to_dict()))
		# 手牌里留一张盟友，给「系统升级 / 轻量化」这类需要**选手牌**的技能当目标。
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(8029).to_dict()))
		engine.play_from_hand(0, Vector2i(5, 0))
		var r288_names := ""
		for r288_n: String in engine.fort_casts:
			r288_names = r288_n if r288_names == "" else "%s, %s" % [r288_names, r288_n]
		status_text = "R288：失控要塞 入场（已用聚能炮击 %d 张）→ 随机释放 %d 张技能：%s" % [
				engine.state.self_cannon_plays, engine.fort_casts.size(), r288_names]
		_shot_t0 = _now()
		queue_redraw()
	if "--trapper" in args and engine != null:
		# 演示（R116）：捕兽大师 9126 的**亡语** —— 先上场、再当场打死它 →
		# 它倒下的那一格变成一张**随机陷阱**（斜纹格 + 角标）。
		# ⚠️ 必须先把角色设成暗影刺客：陷阱池按 `RunState.player_class` 取
		#    （捕兽大师本身就是暗影刺客卡，实战里天然成立；裸跑战斗演示时要显式设）。
		RunState.player_class = "暗影刺客"
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.TRAPPER_ID))
		engine.state.energy = 5
		engine.state.place(repo.get_card(GameEngine.TRAPPER_ID), Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine._destroy(Vector2i(4, 1))
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "R116：捕兽大师亡语 → 在原地留下一张随机陷阱（斜纹格；原地已有场地则不覆盖）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r118" in args and engine != null:
		# 演示（R118）—— 一屏同时看两件事：
		#   ① 救援构装体 8056 同时放**手牌**与**战场**：手牌卡面写「盟友 · 交换」，
		#      战场卡面**不再写**（上场之后这个字段已经不起作用）。两处可直接对照。
		#   ② 一个「已移动、还没攻击」的单位 + 一次**误点空位**之后的状态：
		#      选区 / 绿色移动格 / 红色攻击格全部留着，选中格挂琥珀「取消?」角标
		#      —— 再点一次空位才真取消（放弃攻击并横置）。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(8056))
		engine.state.hand.append(repo.get_card(8001))
		engine.state.energy = 9
		engine.state.place(repo.get_card(8056), Vector2i(4, 1), GameEngine.SIDE_SELF)
		var r118_u := engine.state.unit_at(Vector2i(4, 1))
		if r118_u != null:
			r118_u.moved = true
			r118_u.tapped = false
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		_on_board_click(Vector2i(4, 1))        # 选中它（已移动 → 只剩攻击权）
		var r118_far := Vector2i(-1, -1)
		for r118_r in FieldState.BOARD_ROWS:
			for r118_c in FieldState.BOARD_COLS:
				var r118_cl := Vector2i(r118_r, r118_c)
				if engine.state.unit_at(r118_cl) != null:
					continue
				if (r118_cl - Vector2i(4, 1)).length() < 3.0:
					continue
				r118_far = r118_cl
				break
			if r118_far.x >= 0:
				break
		if r118_far.x >= 0:
			_on_board_click(r118_far)          # 误点一个空位 → 只「上膛」
		status_text = "R118：① 战场卡面不再标「交换」（手牌上仍写）"
		status_text += "② 误点空位只上膛 —— 琥珀「取消?」= 再点一次才取消"
		_shot_t0 = _now()
		queue_redraw()
	if "--r307statue" in args and engine != null:
		# R307 演示：道具栏里「雕像（3）」—— 名字旁显示累计使用张数（出图核验）。
		RunState.relics = [6039, 6035]
		engine.self_relics = [6039, 6035]
		RunState.statue_charge = 3
		status_text = "R307：雕像（3）= 道具名旁显示累计张数（每 10 张回 1 能量）"
		queue_redraw()
	if "--r303tip" in args and engine != null:
		# R303 演示：提及浮窗**完整版**（卡面 + 效果正文 + 字段解释）——
		# 用一张自带字段的卡（救援构装体 8056 带「交换」），钉住浮窗不看鼠标。
		# 出图：`battle.tscn -- --screenshot --level 0 --r303tip --shotframe 600`
		var rt_c: CardData = repo.get_card(8056)
		_mention_pin = {"kind": "card", "id": rt_c.id, "name": rt_c.card_name,
				"rect": Rect2(INFO_X + 24.0, 250.0, 70.0, 16.0)}
		_hover_mention = {}
		_hover_card = null
		_hover_hand = -1
		selection = null
		status_text = "R303：提及浮窗 = 卡面 + 效果正文 + 字段解释（不只是卡面）"
		queue_redraw()
	if ("--r297hand" in args or "--r302mention" in args) and engine != null:
		# R297 演示②：**手牌技能卡**（没有力量 / 生命框）—— 效果框 + 字段框 + 附魔框。
		# 出图：`battle.tscn -- --screenshot --level 0 --r297hand --shotframe 600`
		engine.state.hand.clear()
		engine.state.energy = 9
		var rh_card: CardData = null
		for rh_c: CardData in repo.all_cards():
			if rh_c.kind == "技能" and rh_c.group == "player" \
					and rh_c.effect_text.length() > 28:
				rh_card = CardData.from_dict(rh_c.to_dict())
				break
		if rh_card != null:
			rh_card.add_affix("次元")
			rh_card.enchant = "damage"
			engine.state.hand.append(rh_card)
			_demo_hover_idx = engine.state.hand.size() - 1
			_hover_pl = null
			selection = null
		status_text = ("R302：悬停「素体」才弹卡面 —— 详情底部不再固定列提及"
				if "--r302mention" in args
				else "R297：手牌技能卡 —— 只有效果框 / 字段框 / 附魔框（没有数值框）")
		queue_redraw()
	if "--r297boxes" in args and engine != null:
		# R297 演示：左栏「框体流」验收 —— 一个单位同时带「字段 ×3 / buff ×5 / 附魔 ×1」，
		# 效果文案也够长（效果框因此比别人高，正好验「框高随文字量变」）。
		# 出图：`battle.tscn -- --screenshot --level 0 --r297boxes --shotframe 600`
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		var rb_card: CardData = CardData.from_dict(repo.get_card(8056).to_dict())
		rb_card.add_affix("嘲讽")
		rb_card.add_affix("疾行")
		rb_card.enchant = "save"      # 附魔选「保存」：不改数值，出图不会自相矛盾
		rb_card.add_affix("保存")      # 附魔本身就会赋这个字段
		var rb_u: Placement = engine.state.place(rb_card, Vector2i(4, 1), GameEngine.SIDE_SELF)
		if rb_u != null:
			rb_u.upgrade_stacks = 2
			rb_u.upgrade_atk = 2
			rb_u.upgrade_hp = 5
			rb_u.atk_buff = 2
			rb_u.armor = 3
			rb_u.first_hit_shield = true
			rb_u.moved = true
			rb_u.tapped = false
		_hover_card = null
		_hover_hand = -1
		_hover_pl = null
		selection = ["board", Vector2i(4, 1)]
		status_text = "R297：左栏框体流（数值两框 / 效果自适应框 / 字段框 / buff 框）"
		queue_redraw()
	if "--r120" in args and engine != null:
		# 演示（R120）—— 侦察塔 8032 的**光环易伤**：
		#   * 塔落 (4,1)，攻程 2；改造**两次** —— 改造**不给它加攻**（塔面仍是 0 攻 / 血厚了 16）。
		#   * (3,1) 与 (4,2) 两个敌人**在范围内**，(0,0) 那个**在范围外**（曼哈顿 5）。
		#     （放 (0,0) 而不是 (1,x)：中部「我方回合」横幅会盖住第 1 行，截图上看不见。）
		#   * 打一下范围内的敌人 → 飘字「光环 +2」；范围外那个只吃基础伤害（没有飘字）。
		#   左栏信息面板里应能看到一条「光环：范围内敌人受伤 +2」。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.place(CardData.from_dict(
				repo.get_card(GameEngine.SCOUT_TOWER_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(0, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(0, 2), GameEngine.SIDE_OPPONENT)   # 范围外对照（曼哈顿 4）
		engine._hit_unit(engine.state.unit_at(Vector2i(3, 1)), 6, "演示")
		engine._hit_unit(engine.state.unit_at(Vector2i(0, 0)), 6, "演示：范围外")
		var r120_tp2 := engine.state.unit_at(Vector2i(4, 1))
		status_text = "R120：塔 %d攻/%d血/%d层（改造不给塔加攻）→ 范围内(3,1) 6伤变8；范围外(0,0) 只吃6" % [
				r120_tp2.effective_power(), r120_tp2.health, r120_tp2.upgrade_stacks]
		_shot_t0 = _now()
		queue_redraw()
	if "--sysupfield" in args and engine != null:
		# 演示（R209）：**系统升级改的侦察塔上场自带 1 层**（用户报的那条）——
		# 走真实路径（cast_sys_upgrade → play_from_hand），不手工摆层数；
		# 出图核验：卡面徽标「改造 ×1」+ 左栏「光环：范围内敌人受伤 +1」+ 飘字。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.SCOUT_TOWER_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.SYS_UPGRADE_ID).to_dict()))
		engine.cast_sys_upgrade(1, 0)
		engine.play_from_hand(0, Vector2i(4, 1))
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		engine._hit_unit(engine.state.unit_at(Vector2i(3, 1)), 6, "演示：系统升级过的塔")
		var r209_demo_tp: Placement = engine.state.unit_at(Vector2i(4, 1))
		# 左栏信息面板只在 `_hover_card != null`（或选中）时才画 —— 只设 `_hover_pl` 不够。
		_hover_card = r209_demo_tp.card
		_hover_pl = r209_demo_tp
		_hover_hand = -1
		status_text = "R209：系统升级改的侦察塔上场 → %d 层 / %d 攻 / %d 血；范围内 6 伤变 %d" % [
				r209_demo_tp.upgrade_stacks, r209_demo_tp.effective_power(),
				r209_demo_tp.health,
				6 + engine._scout_aura_bonus(engine.state.unit_at(Vector2i(3, 1)),
						Vector2i(3, 1))]
		_shot_t0 = _now()
		queue_redraw()
	if "--reloadhover" in args and engine != null:
		# 演示（R211）：填充 9146 挂了「次元」字段 —— 手牌塞一张并悬停，左栏应出现「字段：次元」
		# （R211 起左栏补列 affix；以前只有 traits 的「词条：」行）。
		# 出图：`battle.tscn -- --screenshot --reloadhover --shotframe 20`
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.RELOAD_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.ENERGY_CANNON_ID).to_dict()))
		_hover_card = engine.state.hand[0]
		_hover_pl = null
		_hover_hand = 0
		status_text = "R211：填充带「次元」→ 左栏「字段：次元」；用后进消耗区（不进弃牌区）"
		_shot_t0 = _now()
		queue_redraw()
	if "--xtext" in args and engine != null:
		# 演示（2026-10-01）：长描述效果卡。
		# 悬停最长的那张（空间守护 9064）→ 左栏信息面板用于像素级核验「长描述不溢出」。
		# 镜像 9056 自 R35 起不再是「每回合第 X 次」组，但仍是长描述卡 → 留在演示里。
		engine.state.hand.clear()
		for _tid in [9057, 9056, 9063, 9064, 9069]:
			engine.state.hand.append(repo.get_card(_tid))
		engine.state.energy = 9
		_demo_hover_idx = 3
		status_text = "长描述改版：威慑 / 镜像 / 以太咆哮 / 空间守护 / 鸭窝"
		_shot_t0 = _now()
		queue_redraw()
	if "--r333card" in args and engine != null:
		# 演示（R333）：卡图批次 F —— 报废 8071 / 聚能炮击 9145 / 填充 9146。
		# 三张并排：缩到 99×119 也能靠色块分开（暖金光柱 / 青白激光 / 蓝白电弧）。
		engine.state.hand.clear()
		engine.state.energy = 9
		for _cid in [8071, 9145, 9146]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(_cid).to_dict()))
		_demo_hover_idx = 1
		_hover_hand = 1
		_hover_card = engine.state.hand[1]
		status_text = "批次 F：报废 / 聚能炮击 / 填充"
		_shot_t0 = _now()
		queue_redraw()
	if "--r330card" in args and engine != null:
		# 演示（R330）：以太恶魔 9068 费用 5 → 6 / 代达罗斯 8060 5 费 8/18 → 4 费 5/16。
		#   效果区摆 2 张效果卡 → 以太恶魔实际 6-2=4 费（手卡绿圈），左栏详情仍是原价 6 费。
		engine.state.hand.clear()
		engine.state.effects.clear()
		engine.state.energy = 9
		engine.state.effects.append(repo.get_card(9002))
		engine.state.effects.append(repo.get_card(9058))
		engine.state.hand.append(CardData.from_dict(repo.get_card(9068).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8060).to_dict()))
		_demo_hover_idx = 1
		_hover_hand = 1
		_hover_card = engine.state.hand[1]
		status_text = "以太恶魔 6-2=4 费 / 代达罗斯 4 费 5/16"
		_shot_t0 = _now()
		queue_redraw()
	if "--mage" in args and engine != null:
		# 演示（2026-10-01）：白魔法师「精进」——每个自己的回合开始力量 +1（永久累计，无前置条件）。
		# 场上再摆一个农民 → 证明「不再要求只剩它自己」也成长：力量 2 → 3，飘字「精进 +1 攻」。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(9021))
		engine.state.energy = 7
		engine.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine._mage_growth(GameEngine.SIDE_SELF)
		_demo_hover_idx = 0
		status_text = "「精进」：每回合开始 +1 攻（已去掉「只剩它自己」）"
		_shot_t0 = _now()
		queue_redraw()
	if "--meteor" in args and engine != null:
		# 演示（2026-10-01；R124 改）：流星雨（9083）—— X 费：消耗全部能量，打 9 伤 X 次。
		# 先用 5 能量打一次（5 颗、每次随机选目标）→ 看陨石爆点/飘字；
		# 再把能量清零、补一张进手牌并悬停。R124 的核验点有两个：
		#   ① 0 能量时这张卡**仍然可点**（不再提示「能量不足」）；
		#   ② 左栏写「费用 X（消耗全部能量）」、卡面费用圆是「X」。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.METEOR_SHOWER_ID))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(9001).to_dict()),
				Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1053).to_dict()),
				Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0)
		engine.state.energy = 0
		engine.state.hand.append(repo.get_card(GameEngine.METEOR_SHOWER_ID))
		_demo_hover_idx = 0
		status_text = "R124：流星雨 0 能量也能用（X 记 0）—— 点它只会空放，不砸任何流星"
		_shot_t0 = _now()
		queue_redraw()
	if "--fire" in args and engine != null:
		# 演示（2026-10-01，R247 起不分敌我）：火墙术（9084）—— 3 费，对一横行的所有单位造成 15 点伤害；
		# 该行燃烧到下次自己回合开始，期间任何单位（不分敌我）经过 → 再受 10 点。
		# 沿用默认关卡的两只鸭子骑士（1,0)/(1,2)，烧中间那条行；再让白魔法师穿过 → 100→90。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.FIRE_WALL_SPELL_ID))
		engine.state.energy = 5
		engine.use_spell(0, Vector2i(1, 1))
		engine.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_SELF)
		engine.move(Vector2i(2, 1), Vector2i(1, 1))
		engine.state.hand.append(repo.get_card(GameEngine.FIRE_WALL_SPELL_ID))
		_demo_hover_idx = 0
		status_text = "火墙术：第 1 行所有单位 -15（不分敌我），穿过的单位再 -10"
		_shot_t0 = _now()
		queue_redraw()
	if "--charge" in args and engine != null:
		# 演示（2026-10-01）：蓄力（9085）—— 2 费史诗，本方使用的下一张技能生效 2 次。
		# 亡灵领主 8/55 摆在 (1,1)，先蓄力再火焰箭（17 伤）→ 17×2 = 34 → 55→21。
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.CHARGE_SPELL_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(9003).to_dict()))
		engine.state.energy = 5
		engine.use_spell(0)   # 蓄力（2 费）
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, Vector2i(1, 1))   # 火焰箭 → 生效 2 次
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.CHARGE_SPELL_ID).to_dict()))
		_demo_hover_idx = 0
		_hover_hand = 0   # 让左栏信息面板走 cost_of
		status_text = "蓄力：下一张技能生效 2 次 —— 火焰箭 17 伤 ×2 = 34（亡灵领主 55→21）"
		_shot_t0 = _now()
		queue_redraw()
	if "--druid" in args and engine != null:
		# 演示（2026-10-01）：角色「森林精魄」—— 熊（8004）上场 / 发动回春 / 荒野形态反伤。
		# 亡灵领主（8/55）贴脸打熊 → 自己吃到「荒野形态」3 点（55→52）；
		# 熊被压到 9 血后发动回春 → 9+6 被**生命上限**截到 **14**（R125 上限 12 → 14），横置。
		RunState.player_class = PlayerClass.DRUID   # 左栏「角色：」也要跟着演示走
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
		engine.state.hand.clear()
		var dr_bear := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		dr_bear.health = 9
		engine.activate(Vector2i(3, 1))
		engine.state.hand.append(repo.get_card(GameEngine.BEAR_ID))
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "森林精魄：熊发动回春 9+6 被上限截到 14 并横置；打它的敌人吃「荒野形态」3 点反伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--activate" in args and engine != null:
		# 演示（R142）：场上「可主动发动」的**常驻**提示。两只熊并排 ——
		# 左边那只**已经发动过**（横置 → 环与徽标都消失），右边那只**现在能发动**
		# （亮黄绿脉动环 + 四向指向卡面的内箭头 + 顶部「可发动 F」徽标）。
		# ⚠️ 判据是引擎的 `can_activate()` —— 所以左边那只连徽标都不该有。
		RunState.player_class = PlayerClass.DRUID   # 左栏「角色：」也跟着演示走
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
		engine.state.hand.clear()
		var ab_left := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		ab_left.health = 9
		engine.activate(Vector2i(3, 1))             # 左：发动 → 横置 + ability_used
		var ab_right := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		ab_right.health = 9
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		status_text = "R142：左熊已发动（环消失）；右熊可发动（黄绿环 + 内箭头 +「可发动 F」）"
		_shot_t0 = _now()
		queue_redraw()
	if "--rhino" in args and engine != null:
		# 演示（R125）：犀牛（9016，原「骑兵」）—— **受到的伤害 -1，最低 1 点**。
		#   亡灵领主（程 1）贴脸打它：5 点伤害 → 只掉 4；同时把熊（生命 14）摆在场上，
		#   一眼能看出新的生命上限。开着战斗记录，日志里能读到减伤那一行。
		_log_visible = true
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(9016).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(9016).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "R125：犀牛（原「骑兵」）受到伤害 -1（亡灵领主 5 攻 → 只掉 4）；右侧熊生命 14"
		_shot_t0 = _now()
		queue_redraw()
	if "--rogue" in args and engine != null:
		# 演示（2026-10-01）：角色「暗影刺客」—— 终结（9086）的 4+X 与「幻影斗篷」6023。
		#   先出 2 张牌（本回合已用 2 张）→ 突袭 X=2 → 4+2=6 伤（亡灵领主 55→49）；
		#   三张牌各触发一次斗篷 → 亡灵领主共 -3 力量（8 → 5）。
		RunState.player_class = PlayerClass.ROGUE   # 左栏「角色：」也要跟着演示走
		engine.self_relics = [GameEngine.PHANTOM_CLOAK_RELIC_ID]
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8005).to_dict()))
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.RAID_SPELL_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.play_from_hand(0, Vector2i(4, 0))   # 木栅栏 → 本回合第 1 张
		engine.play_from_hand(0, Vector2i(4, 2))   # 幽影   → 本回合第 2 张
		engine.use_spell(0, Vector2i(2, 1))        # 突袭 → 4 + 2 = 6
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "暗影刺客：本回合已用 2 张牌 → 终结 4+2=6 伤；幻影斗篷三张牌共 -3 力量"
		_shot_t0 = _now()
		queue_redraw()
	if "--nowdmg" in args and engine != null:
		# R262 出图核验：左栏「现在打出：N 点伤害」。
		#   手牌只放一张终结（9086），本回合已用 2 张 → 面板应写「现在打出：4 点伤害」+
		#   小字「2 + 本回合已用 2 张」。（`battle.tscn -- --screenshot --nowdmg --shotframe 20`）
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.RAID_SPELL_ID).to_dict()))
		engine.state.self_card_plays = 2
		engine.state.energy = 3
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "R262：左栏「现在打出：4 点伤害」= 2 + 本回合已用 2 张"
		_shot_t0 = _now()
		queue_redraw()
	if "--bounce" in args and engine != null:
		# R263 出图核验：新卡「弹跳飞刀」（9160）—— 手牌一张 + 场上三个敌人。
		#   左栏应写「#9160 弹跳飞刀 / 技能 · 费用 1 · 普通」，
		#   卡面文案「对一个敌人造成 5 点伤害，再对随机最多两个其他敌人各造成 3 点伤害。」
		#   （`battle.tscn -- --screenshot --bounce --shotframe 20`）
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.BOUNCE_KNIFE_ID).to_dict()))
		engine.state.energy = 3
		for _bn_i in 3:
			engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
					Vector2i(_bn_i + 1, 1), GameEngine.SIDE_OPPONENT)
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "R263 弹跳飞刀：1 费 · 主目标 5 伤 + 随机最多两个其他敌人各 3 伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--rogue2" in args and engine != null:
		# 演示（2026-10-02）：暗影刺客 R45 —— 终结 / 连刺 / 偷袭 / 潜影者 / 影魔 / 幽光。
		#   终结(X=0)→连刺(带卡组 0 费技能卡)→偷袭(满血 12 伤)→潜影者上场→
		#   影魔（手里两张 0 费终结 → 生命 11→17）→幽光进效果区→再用终结（潜影者 +1 力量）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		for rid in [GameEngine.RAID_SPELL_ID, GameEngine.GOUGE_ID, GameEngine.SNEAK_ID,
				GameEngine.LURKER_ID, GameEngine.SHADOW_DEMON_ID, GameEngine.GLOW_ID,
				GameEngine.RAID_SPELL_ID]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(rid).to_dict()))
		engine.state.deck.append(CardData.from_dict(repo.get_card(GameEngine.RAID_SPELL_ID).to_dict()))
		engine.state.energy = 15
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, Vector2i(2, 0))        # 终结（X=0）→ 4 伤
		engine.use_spell(0, Vector2i(2, 0))        # 连刺 → 4 伤 + 卡组 0 费技能卡入手
		engine.use_spell(0, Vector2i(2, 2))        # 偷袭：满血 → 12 伤
		engine.play_from_hand(0, Vector2i(4, 1))   # 潜影者（本回合已用 3 张）
		engine.play_from_hand(0, Vector2i(4, 2))   # 影魔：手卡 0 费技能卡 ×2 → 生命 11→17
		engine.use_effect(0)                       # 幽光 → 效果区（下回合开始给荧光草）
		engine.use_spell(0, Vector2i(2, 0))        # 终结（X=6）→ 10 伤；潜影者 +1 力量
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "暗影刺客 R45：潜影者每用一张牌 +1 力量；影魔吃 0 费技能卡 +3 生命/张；幽光待发"
		_shot_t0 = _now()
		queue_redraw()
	if "--echo" in args and engine != null:
		# 演示（2026-10-02，R48）：回响（9102）—— 1 费稀有，所有敌人各 2 伤 + 力量 -1，
		#   使用后**返回手卡**（手卡里还在，费用最低 1）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ECHO_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ECHO_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, null)                  # 回响：两个敌人各 -2、力量 -1，卡回手
		engine.use_spell(0, null)                  # 再用一次（能量 5 → 4 → 3）
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "回响：所有敌人各 2 伤 + 力量 -1；使用后返回手卡（费用最低 1，能量 5→3）"
		_shot_t0 = _now()
		queue_redraw()
	if "--dodge" in args and engine != null:
		# 演示（2026-10-02，R48）：闪躲（9103）—— 0 费普通；直到下个回合开始，
		#   自己受到的伤害由随机盟友代受（盟友生命不足时超出部分仍由自己承担）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.DODGE_ID).to_dict()))
		engine.state.energy = 5
		var dg_ally := engine.state.place(CardData.from_dict(repo.get_card(8005).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, null)                  # 闪躲：开窗口
		engine._damage_player(GameEngine.SIDE_SELF, 5, "演示")   # 5 伤 → 幽影（3/8）代受
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "闪躲：伤害由随机盟友代受（幽影 8 → %d，我方 HP 未掉）" % dg_ally.health
		_shot_t0 = _now()
		queue_redraw()
	if "--finisher" in args and engine != null:
		# 演示（2026-10-02，R49）：收尾（9104）—— 1 费普通（R329 由稀有降）；平时 6 伤，
		#   **打出时它是手卡里仅剩的一张** → 22 伤。这里连着打两张：第一张（手卡还剩一张）
		#   打左敌 6 伤，第二张（只剩它）打右敌 22 伤 —— 两张飘字并排，一眼看出差别。
		#   实际出牌延到第 80 帧（_demo_tick），避开开局「我方回合」横幅压住飘字。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		for i in 2:
			engine.state.hand.append(CardData.from_dict(
					repo.get_card(GameEngine.FINISHER_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	if "--trap" in args and engine != null:
		# 演示（R80 更新口径）：爆炸陷阱（8011）—— **敌人移动经过即触发**（不必停留），
		#   十字（含中心）各 18 伤，不分敌我。亡灵领主速 2，(3,0) → (3,1) → (3,2)
		#   的路上撞上 (3,1) 的陷阱 → 触发 + **立刻停在 (3,1)**，走不到 (3,2)。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.TRAP_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.play_from_hand(0, Vector2i(3, 1))   # 爆炸陷阱落在 (3,1) —— 敌人**路过**的那一格
		engine.move(Vector2i(3, 0), Vector2i(3, 2), GameEngine.SIDE_OPPONENT)   # 经过 → 触发 + 停在 (3,1)
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "爆炸陷阱：敌人**移动经过** (3,1) 就触发（不必停留）并**立刻停止移动** —— 停在 (3,1)、走不到 (3,2)，十字各 18 伤不分敌我"
		_shot_t0 = _now()
		queue_redraw()
	if "--traps" in args and engine != null:
		# 演示（2026-10-03，R51）：陷阱精通（9105）+ 冻结 / 剧毒陷阱。
		#   先拍陷阱精通（R329：加成 2X → 3X；这三张场地都是 1 费 → 各 +3）→ 亡灵领主分别踩
		#   冻结陷阱（3+3=6 伤 + 冰冻）和剧毒陷阱（每跳 6+3=9）。冰霜陷阱（9+3=12 伤 + 禁足）见回归测试。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.TRAP_MASTERY_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.FREEZE_TRAP_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.POISON_TRAP_ID).to_dict()))
		engine.state.energy = 9
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		engine.use_effect(0)                       # 陷阱精通进效果区
		engine.play_from_hand(0, Vector2i(4, 1))   # 冻结陷阱 (4,1)
		engine.play_from_hand(0, Vector2i(4, 0))   # 剧毒陷阱 (4,0)
		engine.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 经过冻结陷阱
		engine.move(Vector2i(3, 0), Vector2i(4, 0), GameEngine.SIDE_OPPONENT)   # 经过剧毒陷阱
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "陷阱精通 3×原费：冻结 6 伤 / 剧毒 9"
		_shot_t0 = _now()
		queue_redraw()
	if "--hunt" in args and engine != null:
		# 演示（2026-10-03 R52 起 / R329 更新）：陷阱工坊 + 暗影狩猎。
		#   （R329 删除 9106 紧急埋伏后，这里不再演示「工事进手 + 费用 -1」那一步。）
		#   ① 亡灵领主两击打死陷阱工坊（10 血）→ 工坊被破坏：攻击者反受 8 伤并记「触发过场地」；
		#   ② 暗影狩猎打它 —— 本回合刚触发还不翻倍（16 伤）；「上回合触发 → 30」由回归测试验证。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.HUNT_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r52_foe := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r52_foe.health = 60
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.WORKSHOP_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 8 伤 → 工坊剩 2
		r52_foe.tapped = false
		engine.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 破坏 → 反受 8
		r52_foe.tapped = false
		engine.use_spell(0, Vector2i(3, 1))       # 暗影狩猎：16（触发记在本回合，下回合才翻倍）
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "工坊被破坏 → 反伤 8；暗影狩猎 16"
		_shot_t0 = _now()
		queue_redraw()
	if "--pierce" in args and engine != null:
		# 演示（R164 由 --double 改名收窄）：穿刺陷阱（8016，场地卡）。
		#   亡灵领主踩上去 → 吃 14 伤（纯直伤、无附加状态），场地当场消失。
		#   （原来的「给场地附魔 → 触发后同格补随机场地」随 9108 一起下线。）
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		var r53_foe2 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		r53_foe2.health = 60
		engine.attack(Vector2i(3, 0), Vector2i(4, 0), GameEngine.SIDE_OPPONENT)   # 踩穿刺陷阱 → 14 伤
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "穿刺陷阱：敌人移动进入吃 14 伤（并立刻停止移动），场地消失"
		_shot_t0 = _now()
		queue_redraw()
	if "--capture" in args and engine != null:
		# 演示（R54 起是「巨物捕获」工事；**R76 改成场地卡「巨物陷阱」**）+ 活体栅栏 + 警觉。
		#   ① 巨物陷阱（场地）落在 (4,1)，敌人移动进入 → 吃 **10 + 攻击力×2 = 14** 伤（不分敌我）、场地消失；
		#   ② 活体栅栏（8018 工事）正常在场 —— 证明「工事」与「场地」是两套独立数据；
		#   ③ 警觉：随机一张工事进手（费用 -2，绿色圆标注）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 20
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.MASS_TRAP_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.LIVING_FENCE_ID).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		var r54_weak := CardData.from_dict(repo.get_card(1051).to_dict())
		r54_weak.power = 2
		var r54_foe := engine.state.place(r54_weak, Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r54_foe.health = 60
		engine.play_from_hand(0, Vector2i(4, 1))                 # 巨物陷阱落到 (4,1)
		engine.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 踩上去 → 10+2×2=14 伤 + 场地消失
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ALERT_ID).to_dict()))
		engine.use_spell(0)                                      # 警觉：随机工事 -2 费进手
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                       # 警觉摇到的工事 → 绿色费用圆
		status_text = "巨物陷阱（场地）：敌人**移动经过**即吃 10+攻击力×2 伤（示例 14）并停止移动、场地消失；活体栅栏仍是工事；警觉：随机工事进手（-2 费）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r80" in args and engine != null:
		# 演示（R80）：① 场地「移动经过即触发 + 立刻停止移动」——
		#   敌方速 2 的白狼从 (2,0) 出发，(2,1) 上有穿刺陷阱：它**路过**就吃 18 伤，
		#   并且**停在 (2,1)**，走不到原定的 (2,2)；
		#   ② 「行动两次」文字徽标 —— 白狼（卡面自带双动）与被哈气覆盖的树人各挂一个绿标。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()))
		# 白狼（actions=2，自带双动）+ 一只速 2 的普通敌人 + 两只我方树人
		engine.state.place(CardData.from_dict(repo.get_card(9031).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r80_foe2 := CardData.from_dict(repo.get_card(8003).to_dict())
		r80_foe2.move_speed = 2
		engine.state.place(r80_foe2, Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(0, 2), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_SELF)
		engine.play_from_hand(0, Vector2i(2, 1))            # 穿刺陷阱落在 (2,1) —— 路过的那一格
		engine.move(Vector2i(2, 0), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)   # 经过 → 触发 + 停在 (2,1)
		engine.current_side = GameEngine.SIDE_SELF
		engine.state.reset_units(GameEngine.SIDE_SELF)       # 让我方树人进入可行动状态
		_demo_hover_idx = -1
		status_text = "R80：白狼从 (2,0) 走向 (2,2)，**路过 (2,1) 的穿刺陷阱** → 吃 18 伤并**立刻停在 (2,1)**（绿色「行动两次」徽标 = 本回合还剩 2 轮行动）"
		_shot_t0 = _now()
		queue_redraw()
	if "--fountain" in args and engine != null:
		# 演示（R83）：持续型场地「清泉」——
		#   ① 清泉落在 (4,1)，一只受伤的树人站在上面 → 我方回合结束 +2 血；
		#   ② 敌方速 2 的单位**经过** (2,1) 上另一格清泉 → **不被拦停、不被消耗**。
		#   与 --r80 的穿刺陷阱对照：脉冲描边 vs 冷青静止描边。
		RunState.player_class = PlayerClass.DRUID
		engine.state.hand.clear()
		engine.state.energy = 5
		# 我方树人（先打伤，让清泉有东西可治）
		var r83_tree := CardData.from_dict(repo.get_card(8003).to_dict())
		engine.state.place(r83_tree, Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.FOUNTAIN_ID).to_dict()))
		engine.play_from_hand(0, Vector2i(4, 1))          # 清泉放在树人脚下
		engine._hit_unit(engine.state.unit_at(Vector2i(4, 1)), 3, "演示")
		# 敌方半场也放一格清泉 + 一只速 2 的敌人，稍后让它路过
		var r83_far_card: CardData = CardData.from_dict(repo.get_card(8003).to_dict())
		r83_far_card.move_speed = 2
		engine.state.place(r83_far_card, Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.set_field(CardData.from_dict(repo.get_card(GameEngine.FOUNTAIN_ID).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_SELF)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "R83：清泉（冷青静止描边）= **持续型场地**，不因经过而触发；" + \
				"站在上面的单位在**自己回合结束**时 +2 血（树人已受伤）"
		_shot_t0 = _now()
		queue_redraw()
	if "--charge" in args and engine != null:
		# 演示（R91）：① 充电装置 8041（接通己方上下两格）② 战场字段徽标轮流显示
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		# 装置在 (4,1)，己方树人 (4,0) / 木栅栏 (4,2) 与它四方向相邻 → 接通
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8001).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		var r91_st: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.CHARGE_STATION_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		# 一只带「幻影 + 死亡」字段的树人，用来展示战场字段徽标
		var r91_ghost := CardData.from_dict(repo.get_card(8003).to_dict())
		r91_ghost.add_affix(GameEngine.AFFIX_PHANTOM)
		r91_ghost.add_affix(GameEngine.AFFIX_DEATH)
		var r91_gp: Placement = engine.state.place(r91_ghost, Vector2i(5, 1),
				GameEngine.SIDE_SELF)
		engine.state.unit_at(Vector2i(4, 0)).health = 2
		engine.state.unit_at(Vector2i(4, 2)).health = 2
		r91_st.health = 1
		r91_gp.health = 4
		engine.state.reset_units(GameEngine.SIDE_SELF)
		engine.end_turn()      # 我方回合结束 → 接通的己方单位各 +2 血
		_demo_hover_idx = -1
		status_text = "R91 充电装置（1费工事）：**接通**=闪电链的四方向相连，" + \
			"但**只算我方** —— (4,0)/(4,2) 各回 2 血；右侧树人头顶**轮流显示**" + \
			"「幻影 / 死亡」字段徽标"
		_shot_t0 = _now()
		queue_redraw()
	if "--sysup" in args and engine != null:
		# 演示（R90 / R209）：两张「改造手牌」的技能——
		#   ① 系统升级：弹**全屏选卡页**（候选只列盟友 / 工事；R209 前是手牌上点第二下）；
		#   ② 批量传输：手牌 3 张一起改造 + 抽 1 张。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck = [CardData.from_dict(repo.get_card(8004).to_dict())]
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))  # 树人
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))  # 木栅栏
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))  # 攻击
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.SYS_UPGRADE_ID).to_dict()))
		engine.state.energy = 5
		engine.state.reset_units(GameEngine.SIDE_SELF)
		_clear_selection()
		selection = ["hand", 3]
		_use_hand_card(3)          # 记下「系统升级」自己 → `_sync_pick()` 弹选卡页
		status_text = "R90/R209 系统升级：选卡页只列盟友 / 工事（技能卡不在候选）；" + \
			"选树人 → 4 费 6 攻 14 血（本场战斗永久，+1费/+3力/+6血）"
		_shot_t0 = _now()
		queue_redraw()
	if "--batcht" in args and engine != null:
		# 演示（R90）：批量传输 —— 手牌全体改造 + 抽 1 张。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck = [CardData.from_dict(repo.get_card(8004).to_dict())]
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.BATCH_TRANSFER_ID).to_dict()))
		engine.state.energy = 5
		engine.state.reset_units(GameEngine.SIDE_SELF)
		engine.use_spell(3, null)
		status_text = "R90 批量传输：手牌各 +1 攻 / +4 血（费用不变）+ 抽 1 张"
		_demo_hover_idx = 0
		_hover_hand = 0     # 让左栏把改完的树人数值显示出来
		_shot_t0 = _now()
		queue_redraw()
	if "--r273up" in args and engine != null:
		# 演示（R273）：升级 8027 基数改为 +2 攻 / +10 血 —— 树人 3/8 → 5/18。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		var r273_demo_up: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
		engine.use_spell(0, Vector2i(4, 1))
		engine.state.place(CardData.from_dict(repo.get_card(8004).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		_hover_card = r273_demo_up.card
		_hover_pl = r273_demo_up
		_hover_hand = -1
		status_text = "R273 升级：树人 3/8 → %d 攻 / %d 血（+2 攻 / +10 血）" % [
				r273_demo_up.effective_power(), r273_demo_up.health]
		_shot_t0 = _now()
		queue_redraw()
	if "--r273ov" in args and engine != null:
		# 演示（R273）：过载 8030 改成 0 费 —— 能量 0 也能打出，牌库里随机一张盟友永久双动。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck = [CardData.from_dict(repo.get_card(8004).to_dict())]
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.OVERLOAD_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))
		engine.state.energy = 0
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "R273 过载：0 费（能量 0 也能打）→ 牌库一张盟友永久双动"
		_shot_t0 = _now()
		queue_redraw()
	if "--r274fort" in args and engine != null:
		# 演示（R274）：堡垒「每拥有一层改造 +3 生命」——层数在**手牌**里攒的也照算。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand = [CardData.from_dict(repo.get_card(GameEngine.FORT_ID).to_dict())]
		for _n274 in 2:
			engine.state.hand.append(CardData.from_dict(
					repo.get_card(GameEngine.SYS_UPGRADE_ID).to_dict()))
			engine.cast_sys_upgrade(engine.state.hand.size() - 1, 0)
		engine.play_from_hand(0, Vector2i(4, 1))
		var r274_demo_fort: Placement = engine.state.unit_at(Vector2i(4, 1))
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		_hover_card = r274_demo_fort.card
		_hover_pl = r274_demo_fort
		_hover_hand = -1
		status_text = "R274 堡垒：手牌改造 2 层 → 上场 %d 血（10 + 6×2 + 3×2）" % [
				r274_demo_fort.health]
		_shot_t0 = _now()
		queue_redraw()
	if "--r327funeral" in args and engine != null:
		# 演示（R327）：效果区挂一张「送葬」，再当场打掉己方一个树人 → 抽 1 张。
		# 手牌不清空（留几张才看得出「多了一张」）；能量给 6，效果区那张是白送的。
		RunState.player_class = PlayerClass.DRUID
		engine.state.energy = 6
		engine.state.effects.append(CardData.from_dict(repo.get_card(9175).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		# ⚠️ 击杀动作**不在这里**：放在截图前 40 帧（见 `_demo_tick`），
		#    否则 `--shotframe 600` 时 1600ms 的「送葬 +N 张」飘字早就消失了。
		_hover_hand = -1
		_shot_t0 = _now()
		queue_redraw()
	if "--r331hidden" in args and engine != null:
		# 演示（R331）：隐藏能源 8078 —— 效果区挂它 → 友方单位入场获得改造 +「死亡」。
		# 敌方单位摆在 (3,1)，与出牌的 (4,1) 曼哈顿距离正好 1（亡语必中它）。
		# ⚠️ 「打掉那个单位」不在这里：放在截图前 40 帧（见 `_demo_tick`），
		#    否则 `--shotframe 600` 时 1600ms 的「隐藏能源 -8」飘字早就消失了。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 8
		engine.state.effects.append(CardData.from_dict(repo.get_card(8078).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))
		engine.play_from_hand(0, Vector2i(4, 1))   # 农民上场 → 触发隐藏能源
		_hover_hand = -1
		_shot_t0 = _now()
		queue_redraw()
	if "--r331surprise" in args and engine != null:
		# 演示（R331）：惊喜运单 8079 —— 回合开始「从卡组选一张」的面板。
		# 牌库清空后只塞 4 张，截图里候选列表才看得清。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck.clear()
		engine.state.energy = 8
		engine.state.effects.append(CardData.from_dict(repo.get_card(8079).to_dict()))
		for _sid in [8025, 8044, 9145, 8070]:
			engine.state.deck.append(CardData.from_dict(repo.get_card(_sid).to_dict()))
		engine._surprise_tick(GameEngine.SIDE_SELF)   # 弹面板由 `_sync_pick` 接管
		_hover_hand = -1
		_shot_t0 = _now()
		queue_redraw()
	if "--r332instinct" in args and engine != null:
		# 演示（R332）：本能 9176 —— 牌库里只放 3 张 ≤1 费技能 + 4 张高费干扰，
		# 截图上能直接看出「1 费的被打出去、2 费的还留在牌库」。
		# ⚠️ 出牌动作**不在这里**：放在截图前 40 帧（见 `_demo_tick`），
		#    否则 `--shotframe 600` 时状态栏播报与「本能 · …」飘字早就过去了。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.deck.clear()
		engine.state.energy = 6
		for _sid in [9094, 9103, 9087, 9095, 9098, 9095, 9098]:
			engine.state.deck.append(CardData.from_dict(repo.get_card(_sid).to_dict()))
		for _cell in [Vector2i(2, 1), Vector2i(2, 3)]:
			var _foe: Placement = engine.state.place(
					CardData.from_dict(repo.get_card(8003).to_dict()),
					_cell, GameEngine.SIDE_OPPONENT)
			_foe.health = 30
		engine.state.hand.append(CardData.from_dict(repo.get_card(9176).to_dict()))
		_hover_hand = -1
		_shot_t0 = _now()
		queue_redraw()
	if "--r326chimera" in args and engine != null:
		# 演示（R326）：嵌合暴君入场「融合」→ **每破坏 1 张回复 1 费**（这条不写进卡面文本）。
		# 摆两张己方树人接通、手上放暴君：4 费打出 → 破坏 2 张、回 2 费（能量 6 → 4）。
		# ⚠️ 不设 `_hover_card`：让 `_say()` 那句留在状态栏，截出来就是战斗内的真实提示。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 6
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.state.hand = [CardData.from_dict(
				repo.get_card(GameEngine.CHIMERA_ID).to_dict())]
		engine.play_from_hand(0, Vector2i(4, 1))
		_hover_hand = -1
		_shot_t0 = _now()
		queue_redraw()
	if "--r275tank" in args and engine != null:
		# 演示（R275）：重甲战车「每拥有一层改造，受到的伤害 -1（至少 1）」——
		# 层数在**手牌**里攒的也算（与 R274 同口径），所以先改造 2 次再上场。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 99
		engine.state.place(CardData.from_dict(
				repo.get_card(GameEngine.HEAVY_TANK_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		for _n275 in 2:
			engine._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
		var r275_demo_tank: Placement = engine.state.unit_at(Vector2i(4, 1))
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		_hover_card = r275_demo_tank.card
		_hover_pl = r275_demo_tank
		_hover_hand = -1
		status_text = "重甲战车：改造 ×%d → 受伤 -%d（最低 1）" % [
				r275_demo_tank.upgrade_stacks, r275_demo_tank.upgrade_stacks]
		_shot_t0 = _now()
		queue_redraw()
	if "--r275plate" in args and engine != null:
		# 演示（R275）：加厚装甲「+4 生命 + 受到伤害 -1」—— 施加两次 → 累计受伤 -2。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 99
		var r275_demo_tree: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		for _n275b in 2:
			engine._armor_plate(Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		_hover_card = r275_demo_tree.card
		_hover_pl = r275_demo_tree
		_hover_hand = -1
		status_text = "加厚装甲 ×2 → 生+8 / 受伤 -%d" % [
				r275_demo_tree.dmg_reduce]
		_shot_t0 = _now()
		queue_redraw()
	if "--r276asm" in args and engine != null:
		# 演示（R276）：随心组装 9144 —— 手牌全变随机奖励卡，其中**变出来的盟友卡
		# 本回合费用 -1**（工事 / 技能 / 效果不减），离手即恢复原价、回合结束清空。
		# 演示要稳定看到一张盟友卡：反复重变，直到手里出现盟友。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		for _n276a in 6:
			engine.state.hand.append(CardData.from_dict(
					repo.get_card(8003).to_dict()))
		var r276_demo_ally: CardData = null
		for _try276 in 8:
			engine._assemble_at_will(GameEngine.SIDE_SELF)
			for c: CardData in engine.state.hand:
				if c.kind == "盟友":
					r276_demo_ally = c
					break
			if r276_demo_ally != null:
				break
		_hover_card = null
		_hover_pl = null
		_demo_hover_idx = -1
		if r276_demo_ally != null:
			var r276_idx: int = engine.state.hand.find(r276_demo_ally)
			# 手牌悬停要走 `_demo_hover_idx`（每帧重设），`_hover_hand` 只管绘制时抬手。
			_demo_hover_idx = r276_idx
			status_text = "随心组装：「%s」%d 费 → %d 费" % [
					r276_demo_ally.card_name, r276_demo_ally.cost,
					engine.cost_of(r276_demo_ally)]
		else:
			status_text = "随心组装：本轮没变出盟友卡"
		_shot_t0 = _now()
		queue_redraw()
	if "--r276bar" in args and engine != null:
		# 演示（R276）：能量屏障 8033 —— 从抽牌堆挑一张加护盾，**然后抽 3 张**。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.deck = []
		for _n276b in 12:
			engine.state.deck.append(CardData.from_dict(
					repo.get_card(8003).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.BARRIER_ID).to_dict()))
		engine.use_spell(0)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		_hover_card = null
		_hover_pl = null
		_demo_hover_idx = 0
		status_text = "能量屏障：1 张获护盾 + 抽 %d 张" % GameEngine.BARRIER_DRAW
		_shot_t0 = _now()
		queue_redraw()
	if "--r277hep" in args and engine != null:
		# 演示（R277）：赫菲斯托斯（9135）**位移免疫** —— 击退 / 换位一概无效。
		# 场上摆两只：赫菲斯托斯（敌方）与我方一只树人，然后对它放一发击退，
		# 让状态栏把「免疫位移」当场播出来（截图核验用）。
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.board.clear()
		engine.state.place(CardData.from_dict(repo.get_card(9135).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		var r277_kb: String = engine._knockback(GameEngine.SIDE_SELF, Vector2i(1, 1), 2)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		_hover_card = null
		_hover_pl = engine.state.unit_at(Vector2i(1, 1))
		_demo_hover_idx = -1
		status_text = "击退 2 格 → %s" % r277_kb
		_shot_t0 = _now()
		queue_redraw()
	if "--armor" in args and engine != null:
		# 演示（R89）：无限装甲（8038）——
		#   ① 场上放装甲 + 手牌塞一张「升级」→ 打出去改造它
		#   ② 立刻多一张**手牌里 0 费**的改造牌（卡面原费 1~2）
		#   ③ 再打一次「升级」→ **本回合不再供能**（每回合一次）
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		var r89_armor: Placement = engine.state.place(
			CardData.from_dict(repo.get_card(GameEngine.INF_ARMOR_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
			repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
			repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
		engine.use_spell(0, Vector2i(4, 1))      # 第 1 次改造 → 供一张 0 费牌
		var r89_fed: CardData = null
		for c: CardData in engine.state.hand:
			if engine.state.hand_free.has(c) and engine.state.hand.has(c):
				r89_fed = c
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "无限装甲：供「%s」入手 · 0 费" % \
			("?" if r89_fed == null else r89_fed.card_name)
		_shot_t0 = _now()
		queue_redraw()
	if "--factory" in args and engine != null:
		# 演示（R88）：持续型场地的第二族（机械之心）——
		#   ① 维修间 8036（冷青）落在 (4,1)，受伤的树人站上面；
		#   ② 改造工厂 8037 落在 (5,1)，一只战斗骨骼站上面 → 每回合 +1 力 / +1 血；
		#   ③ 敌方后排也放一格维修间 —— **敌方单位站上去不受益**（「友」生效）。
		#   与 --fountain 对照：清泉是「双」（敌我双方都回血），这两张只治自己人。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		# 我方：受伤的树人站维修间
		var r88_tree := CardData.from_dict(repo.get_card(8003).to_dict())
		var r88_tree_p: Placement = engine.state.place(r88_tree, Vector2i(4, 1),
				GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.REPAIR_BAY_ID).to_dict()))
		engine.play_from_hand(0, Vector2i(4, 1))
		engine._hit_unit(r88_tree_p, 4, "演示")
		# 我方：战斗骨骼站改造工厂
		var r88_bone: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BATTLE_BONE_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.set_field(CardData.from_dict(
				repo.get_card(GameEngine.UPGRADE_FACTORY_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		# 敌方：一只受伤的敌人站在**我方放的维修间**上（敌方后排 row 0）→ 不受益
		var r88_foe: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(1011).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		r88_foe.health = maxi(1, r88_foe.health - 3)
		engine.state.set_field(CardData.from_dict(
				repo.get_card(GameEngine.REPAIR_BAY_ID).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_SELF)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "维修间回 %d / 改造工厂 +1+1（只自己人）" \
			% repo.get_card(GameEngine.REPAIR_BAY_ID).field_heal
		_shot_t0 = _now()
		queue_redraw()
	if "--surplus" in args and engine != null:
		# 演示（2026-10-03，R55）：活力转移（9110）+ 地狱猫（8019）+ 鲜血堡垒（8020）。
		#   三张都读「自己回合结束时的剩余费用」：本回合留 3 点费用 →
		#   地狱猫 +3 力 +6 生、鲜血堡垒 +3 力 +9 生；活力转移 3/2 = 结转 1 点费用，
		#   结束本回合后进入下个我方回合，能量栏可见 5+1=6（飘字提示）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.VITALITY_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.HELL_CAT_ID).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.BLOOD_FORT_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.energy = 3          # 故意留 3 点不花
		engine.end_turn()               # 我方回合结束 → 结算剩余费用（成长 + 结转）
		engine.end_turn()               # 敌方空回合结束 → 回到我方回合，发放结转的费用
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "剩余费用 3 → 地狱猫 +3力+6生、鲜血堡垒 +3力+9生；活力转移结转 1（%d/2）→ 下回合费用 5+1" \
				% GameEngine.VITALITY_COST
		_shot_t0 = _now()
		queue_redraw()
	if "--blade" in args and engine != null:
		# 演示（2026-10-03，R56）：黑暗领主 8021 + 暗影之刃 9111 + 暗影锁链 9112。
		#   ① 打出黑暗领主（4 费）→ 本回合只剩 1 点；回合结束时它**优先结算** +5 → 6 点，
		#      这 6 点被剩余费用类效果一起读到（地狱猫 +6力+12生、活力转移结转 3）；
		#   ② 暗影之刃：X = 本回合**已花掉**的 4 点 → 随机敌人受 4 伤；
		#   ③ 暗影锁链：6/3 = 2 次击退，每次把随机敌人往后推 2 格。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_BLADE_ID).to_dict()))
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_CHAIN_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(8019).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)   # 地狱猫：看它吃到 +6
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_LORD_ID).to_dict()))
		var r56_foe := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		r56_foe.health = 40
		engine.play_from_hand(0, Vector2i(4, 1))   # 黑暗领主上场（花掉 4 费 → 剩 1）
		engine.end_turn()                        # 结算：+5 优先 → 1+5=6，其余读 6 点
		engine.end_turn()                        # 敌方空过 → 回我方回合，看结转与飘字
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "黑暗领主回合结束 +5（优先结算）→ 剩余费用 6：地狱猫 +6力+12生、活力转移结转 3、暗影锁链 2 次击退；暗影之刃按已花 4 费打 4 伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--abyss" in args and engine != null:
		# 演示（2026-10-03，R57）：地狱咏唱者 8022 + 黑暗祭坛 8023 + 黑暗扩散 9113 + 无尽黑暗 9114。
		#   ① 地狱咏唱者（1/11 程2）与黑暗祭坛（1/15 程1）各攻击一次 → 每次攻击 +1 费用；
		#   ② 留 3 点费用结束回合 → 黑暗扩散：3 × 2 = 对两个敌人各 6 伤；
		#   ③ 进入下个回合：无尽黑暗**弹面板让玩家选 1 张手牌弃掉**（R70），
		#      选完才给费用 +2 —— 所以这帧看到的是弃牌面板（费用还是 5）。
		#      要看费用到账的样子，演示里再点面板上的一张即可。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_SPREAD_ID).to_dict()))
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.ENDLESS_DARK_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.CHANTER_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(8023).to_dict()))
		var r57_f1 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r57_f2 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r57_f1.health = 40
		r57_f2.health = 40
		engine.play_from_hand(0, Vector2i(4, 0))     # 地狱咏唱者 (4,0)
		engine.play_from_hand(0, Vector2i(4, 1))     # 黑暗祭坛 (4,1)
		# 两者各攻击一次（程2 / 程1 都够得着 (3,0)）→ 各 +1 费用
		engine.attack(Vector2i(4, 0), Vector2i(3, 0), GameEngine.SIDE_SELF)
		engine.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.energy = 3                      # 留 3 点不花
		engine.end_turn()                            # 黑暗扩散：3×2=6，敌人各挨 6
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "咏唱者/祭坛攻击各 +1 费；黑暗扩散 3×2=6 伤打到两个敌人（40→34）；无尽黑暗弹出弃牌面板"
		_shot_t0 = _now()
		queue_redraw()
	if "--demon" in args and engine != null:
		# 演示（2026-10-04，R63）：契约签订者 8024 + 恶魔鸭 9116 + 恶魔使魔 9117。
		#   ① 打出契约签订者（3 费）→ 回 4 费（本回合共 6 点）+ 本回合手卡全体涨价 4；
		#   ② 打出第二张契约签订者 → 看涨价**叠加**在费用之外（费用已回满再打一次）；
		#   ③ 我方 8 攻单位打恶魔鸭一下 → 沉睡 -1（100 → 92，还差 1 下才醒）；
		#   ④ 再打一下 → 完全醒来；此后再打 → 每挨一下力量永久 +1（5 → 6 → 7）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.effects.clear()
		engine.state.board.clear()
		engine.state.energy = 5
		engine.enable_enemy_effects([CardData.from_dict(repo.get_card(9117).to_dict())])
		var dm_demo := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.DEMON_DUCK_ID).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)   # 恶魔鸭：敌方后排中央
		var dm_fam := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.FAMILIAR_DUCK_ID).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)   # 使魔鸭子：吃恶魔使魔的成长
		var dm_hero := engine.state.place(CardData.from_dict(repo.get_card(8007).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_SELF)          # 影魔 5 攻：够得着后排恶魔鸭
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.CONTRACTOR_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
		engine.play_from_hand(0, Vector2i(3, 1))            # 契约签订者上场
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                  # 悬停手牌看涨价后的费用
		engine.attack(Vector2i(3, 0), Vector2i(0, 1), GameEngine.SIDE_SELF)
		status_text = "契约签订者：花 3 回 4（费用 %d）+ 本回合手卡涨价 4；影魔打恶魔鸭 → 提前醒来（%d/%d）" \
				% [engine.state.energy, maxi(0, dm_demo.health), dm_demo.card.health]
		_shot_t0 = _now()
		queue_redraw()
	if "--mapview" in args and engine != null:
		# 演示（R64）：战斗内地图总览面板。
		# R128：演示模式默认没有 run（run_active=false → 面板打不开）→ 先开一局假 run。
		if not RunState.run_active:
			seed(0x128)   # 固定演示种子 → 截图可复现
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		# R177：总览里也演示玩家标记（与 map_scene --marks 同数据，截图核验用）
		if RunState.map_strokes.is_empty() and RunState.map_flags.is_empty():
			var mv_col := UiTheme.class_color(RunState.player_class)
			if mv_col.a <= 0.0:
				mv_col = UiTheme.ACCENT_GOLD
			RunState.map_strokes = [{"pts": PackedVector2Array([Vector2(300, 300),
					Vector2(380, 260), Vector2(460, 320), Vector2(540, 250)]), "col": mv_col}]
			RunState.map_flags = [{"pos": Vector2(520, 400), "col": mv_col}]
		_toggle_map()
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "战斗内地图总览：金框＝当前房间，绿框＝可以走过去，迷雾＝看不清里面"
		_shot_t0 = _now()
		queue_redraw()
	if "--mapwalk" in args and _map_visible:
		# R128/R145 核验用：伪造「从起点向上走过 3 格」→ 看清
		# 「通路全图可见 + 内容迷雾（走过的 / 下一步看得见）」。
		_mapview_demo_walk()
		queue_redraw()
	if "--guard" in args and engine != null:
		# 演示（2026-10-01）：「替己方 HP 承伤」的三种卡必须**同一特效** ——
		#   森林守护盟友（9037）/ 铁栅栏（9072）/ 以太守卫（9067）各画一圈绿环，
		#   普通盟友（8003 农民）不画。判定走 engine.absorbs_for_hp()，与结算同源。
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine._forest_guard(GameEngine.SIDE_SELF, Vector2i(4, 2))
		engine.state.place(CardData.from_dict(repo.get_card(9072).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(9067).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(5, 0), GameEngine.SIDE_SELF)
		status_text = "替 HP 承伤统一特效：森林守护 / 铁栅栏 / 以太守卫 都画绿环，普通农民不画"
		_shot_t0 = _now()
		queue_redraw()
	if "--lion" in args and engine != null:
		# 演示：狮子（9038，2026-09-30）—— ① 自己弃牌区每有一个盟友费用 -1（手牌费用圆显绿）
		#   ② 使用时自己场上其他盟友攻击 +2（不含狮子自己）
		for i in 3:
			engine.state.discard.append(repo.get_card(8003))   # 弃牌区 3 个盟友 → 费用 4-3 = 1
		engine.state.discard.append(repo.get_card(8002))       # 技能牌不计入减费
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)  # 农民（盟友）3 攻
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)  # 农民（盟友）3 攻
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.LION_ID))
		engine.state.hand.append(repo.get_card(GameEngine.LION_ID))
		engine.play_from_hand(0, Vector2i(3, 1))   # 打出一只：场上两个盟友 3 → 5 攻
		_hover_hand = 0
		_hover_card = engine.state.hand[0]         # 手里另一只 → 绿色费用「1」（原 4）
		status_text = "狮子：弃牌区 3 盟友 → 费用 4→1（绿色）；使用时场上盟友攻击 +2（3→5），自己保持 6"
		_shot_t0 = _now()
		queue_redraw()
	if "--crow" in args and engine != null:
		# 演示：乌鸦（9039，2026-09-30）—— 使用后必须从弃牌堆选一张盟友回到手牌（弹出选择面板）
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)
		for cid in [8003, 9031, 9032, 9033]:
			engine.state.discard.append(repo.get_card(cid))   # 4 个盟友 → 都会出现在面板里
		engine.state.discard.append(repo.get_card(8002))       # 攻击（技能）→ 不应出现在面板里
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.CROW_ID))
		engine.play_from_hand(0, Vector2i(4, 1))               # 打乌鸦 → 进入待选，弹面板
		_hover_card = null
		status_text = "乌鸦：使用后从弃牌堆选一张盟友回到手牌（面板只列盟友，必须选一张）"
		_shot_t0 = _now()
		queue_redraw()
	if "--hound" in args and engine != null:
		# 演示：猎犬（9040）+ 快速出击（9041）——
		#   ① 猎犬上场快照：场上 2 个其他盟友 → +4 力量（3 → 7）
		#   ② 快速出击：本回合手牌中的盟友费用 -1（手牌费用圆显绿）
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.QUICK_STRIKE_ID))
		engine.state.hand.append(repo.get_card(GameEngine.HOUND_ID))
		engine.state.hand.append(repo.get_card(8003))
		engine.use_spell(0)                                    # 快速出击：本回合盟友 -1
		engine.play_from_hand(0, Vector2i(4, 1))               # 打猎犬：3 → 7 力量（+4 快照）
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                     # 手里的农民 → 绿色费用「2」（原 3）
		status_text = "猎犬：上场时 2 个其他盟友 → +4 力量（3→7）；快速出击：手牌盟友费用 -1（绿色）"
		_shot_t0 = _now()
		queue_redraw()
	if "--overflows" in args and engine != null:
		# 演示（2026-09-30）：效果/道具「过多」时的显示兜底 ——
		#   我方效果 7 张（同名合并后 6 种，可见 4）→ 末位改画「+N」摘要；
		#   敌方效果 5 张（合并后 4 种，可见 3）；道具 8 个（可见 6）。
		#   同名卡合并显示、左下角 ×N 张数角标（2026-10-01 用户要求）。
		#   配合 --relicpanel / --effectpanel 打开浏览面板（装不下时的查看入口）。
		engine.state.effects.clear()
		for eo_id in [9056, 9057, 9057, 9002, 9045, 9036, 9024]:
			var eo_c := repo.get_card(eo_id)
			if eo_c != null:
				engine.state.effects.append(eo_c)
		engine.state.enemy_effects.clear()
		for eo_eid in [9013, 9015, 9024, 9049, 9013]:
			var eo_e := repo.get_card(eo_eid)
			if eo_e != null:
				engine.state.enemy_effects.append(eo_e)
		engine.self_relics = [6001, 6002, 6003, 6005, 6006, 6007, 6008, 6010]
		if "--relicpanel" in args:
			_relics_visible = true
		if "--effectpanel" in args:
			_effects_visible = true
			# 顺带验证面板悬停链路：模拟鼠标悬停在面板第 2 张卡上 → 左侧信息栏显示明细
			var zl := _zone_panel_layout(_zone_panel_cards().size())
			_on_hover(_zone_card_rect(1, zl).get_center())
		status_text = "效果 %d 张（合并 %d 种）/ 敌方效果 %d 张（合并 %d 种）/ 道具 %d 个——点区域查看全部" % [
				engine.state.effects.size(), _merged_effects(engine.state.effects).size(),
				engine.state.enemy_effects.size(), _merged_effects(engine.state.enemy_effects).size(),
				engine.self_relics.size()]
		_shot_t0 = _now()
		queue_redraw()
	if "--stoneskin" in args and engine != null:
		# 演示（2026-09-30）：效果区卡面的「剩余次数」角标（石肤 9066 还剩几次挡刀）
		engine.state.effects.clear()
		for sk_id in [9066, 9002, 9063, 9064]:
			var sk_c := repo.get_card(sk_id)
			if sk_c != null:
				engine.state.effects.append(sk_c)
		engine._stoneskin_left = 3
		status_text = "石肤：效果区卡面右下角显示剩余次数（当前剩 3 次，可叠加、跨回合保留）"
		_shot_t0 = _now()
		queue_redraw()
	if "--taunt" in args and engine != null:
		# 演示（2026-10-01）：嘲讽单位的橙色脉冲光环 + 顶部「嘲讽」徽标
		var taunt_cells := [Vector2i(2, 0), Vector2i(2, 2)]
		var taunt_ids := [1011, 1055]
		for ti in taunt_ids.size():
			var tc := repo.get_card(taunt_ids[ti])
			if tc != null:
				engine.state.place(tc, taunt_cells[ti], GameEngine.SIDE_OPPONENT)
		status_text = "嘲讽：带嘲讽的单位有橙色脉冲光环 + 嘲讽徽标（敌方必须先打它）"
		_shot_t0 = _now()
		queue_redraw()
	if "--weaken" in args and engine != null:
		# 演示（R143）：削弱（9010）**打出当场生效并显示** —— 敌方那个单位的力量立刻变小、
		# 左侧信息栏当场列出「力量 -9」，不必等结束回合、轮到对手才显示。
		# 出图：--screenshot --level 0 --gridscroll 0 --weaken --shotframe 20
		engine.state.energy = 5
		var wk_cell := Vector2i(1, 1)
		engine.state.place(repo.get_card(9014), wk_cell, GameEngine.SIDE_OPPONENT)
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(9010))
		engine.use_spell(0, wk_cell)
		var wk_pl: Placement = engine.state.unit_at(wk_cell)
		_hover_card = wk_pl.card
		_hover_pl = wk_pl
		status_text = "削弱：打出**当场**生效并显示 —— 力量 -%d（当前 %d），信息栏已列出" \
				% [wk_pl.atk_debuff, wk_pl.effective_power()]
		_shot_t0 = _now()
		queue_redraw()
	if "--zoneview" in args and engine != null:
		# 演示（R155）：区域浏览面板 facelift —— 羊皮纸 + 标题栏 + × + 分页。
		#   --zoneview deck：卡组面板；--zoneview void：消耗区面板（塞 6 张演示消失卡）。
		# 出图：--screenshot --level 0 --zoneview deck --shotframe 20
		_close_zone_panels()
		var zv_i := args.find("--zoneview")
		if zv_i >= 0 and zv_i + 1 < args.size() and args[zv_i + 1] == "void":
			engine.state.hand.clear()
			for vid: int in [9010, 9010, 9102, 9078, 8001, 9032]:
				var vc: CardData = repo.get_card(vid)
				if vc != null:
					engine.state.void_cards.append(vc)
					engine.state.void_count += 1
			_void_visible = true
		else:
			_deck_visible = true
		_shot_t0 = _now()
		queue_redraw()
	if "--logview" in args and engine != null:
		# 演示（R155）：对局记录面板（顶栏「记录」按钮同一个）。
		# 出图：--screenshot --level 0 --logview --shotframe 20
		_log_visible = true
		_shot_t0 = _now()
		queue_redraw()
	if "--stonelimit" in args and engine != null:
		# 演示（R144）：**荒野形态先结算 + 石肤只在 >= 2 点伤害时才挡**。
		# 出图：--screenshot --level 0 --gridscroll 0 --stonelimit --shotframe 20
		#   ① 12 攻敌人直击 HP：荒野形态 12 → 8，再交给石肤（8 >= 2）→ 1（石肤 2 → 1 次）
		#   ② 1 攻敌人直击 HP：1 点本来就只掉 1，石肤**不触发**（次数仍 1）
		RunState.player_class = PlayerClass.DRUID
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
		engine.state.effects.append(repo.get_card(GameEngine.STONESKIN_ID))
		engine._stoneskin_left = 2
		engine.state.hand.clear()
		engine.state.place(repo.get_card(9014), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)
		engine.attack_hp(Vector2i(4, 1), Vector2i(5, 1), GameEngine.SIDE_OPPONENT)
		var sk_weak: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
		sk_weak.card.power = 1
		engine.attack_hp(Vector2i(4, 2), Vector2i(5, 2), GameEngine.SIDE_OPPONENT)
		var sk_badge: CardData = engine.state.effects[0] if engine.state.effects.size() > 0 else null
		if sk_badge != null:
			_hover_card = sk_badge
		status_text = "石肤只在 >=2 点伤害时触发：荒野形态先结算（12→8），石肤再压成 1（剩 %d 次）；1 点伤害不扣次数" % engine._stoneskin_left
		# 演示是「瞬间打完两下」，不等撞击演出 —— 清掉 HP 横幅的待扣冻结数，
		# 否则截图会停在「扣血前」的中间态（2026-10-11 实测过 48 显示成 61）。
		_hp_pending.clear()
		_shot_t0 = _now()
		queue_redraw()
	if "--whale" in args and engine != null:
		# 演示：鲸鱼之怒（9050）—— 打出后弹出「从弃牌堆取 2 张」面板（可选、可跳过）
		engine.state.energy = 5
		engine.state.place(repo.get_card(9001), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		for cid in [8003, 9031, 9032, 9033, 8002]:
			engine.state.discard.append(repo.get_card(cid))   # 弃牌堆 5 张：面板里任意卡都能取
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.WHALE_WRATH_ID))
		engine.use_spell(0, Vector2i(0, 1))                    # 打鲸鱼之怒 → 进入取牌待选
		_hover_card = null
		status_text = "鲸鱼之怒：造成 11 伤 → 从弃牌堆取 2 张卡加入手卡（可选、可跳过）"
		_shot_t0 = _now()
		queue_redraw()
	if "--deckpanel" in args and engine != null:
		# 演示（2026-10-01）：卡组（抽牌堆）浏览面板 —— 相同卡合并、不显示抽牌顺序
		_deck_visible = true
		_banner = {}    # 只截图：别让「我方回合」横幅压在面板标题上
		status_text = "剩余牌堆：点开浏览（相同卡合并 ×N，按费用排序，不显示抽牌顺序）"
		_shot_t0 = _now()
		queue_redraw()
	if "--rundeckpanel" in args and engine != null:
		# 演示（R207）：顶栏「卡组」= **完整卡组**（本局构筑，含奖励卡与商店附魔），
		# 与右下「剩余牌堆」（本场还没抽到的牌）是两个口径。
		# 出图：--screenshot --level 0 --rundeckpanel --shotframe 20
		if not RunState.run_active:
			# 单关演示没有 run → 临时造一份「本局构筑」：现有牌堆 + 3 张奖励卡，
			# 其中一张「攻击」带附魔（验证同 id 的附魔副本按卡面签名单列，不被并掉）。
			RunState.run_active = true
			var demo_ids: Array[int] = []
			for dc: CardData in engine.state.deck:
				demo_ids.append(dc.id)
			for extra: int in [8004, 9032, 9010]:
				if repo.get_card(extra) != null:
					demo_ids.append(extra)
			RunState.deck_ids = demo_ids
			RunState.deck_mods = []
			RunState.ensure_deck_mods()
			for di in RunState.deck_ids.size():
				if RunState.deck_ids[di] == 8002:
					RunState.enchant_deck_card(di, {"power": 10})
					break
		_close_zone_panels()
		_run_deck_visible = true
		_banner = {}    # 只截图：别让「我方回合」横幅压在面板标题上
		status_text = "完整卡组：本局构筑 %d 张（含附魔副本）—— 右下角牌堆才是本场剩余" \
				% _run_deck_cards().size()
		_shot_t0 = _now()
		queue_redraw()
	if "--fence" in args and engine != null:
		# 演示（2026-10-01）：道具「栅栏修复术」（6021）——栅栏可以打在已有栅栏的格子上。
		# 橙色「叠」格 = 与已有栅栏合并（生命 + 特性叠加）；绿色格 = 普通放置。
		RunState.relics = [6021]
		load_level(GameLevels.builtin_levels()[0])
		engine.self_relics = [6021]
		engine.state.hand.clear()
		for _k in 3:
			engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.energy = 5
		var f_whole := CardData.from_dict(repo.get_card(8001).to_dict())
		var f_hurt := CardData.from_dict(repo.get_card(8001).to_dict())
		engine.state.place(f_whole, Vector2i(4, 0), GameEngine.SIDE_SELF)
		var f_pl := engine.state.place(f_hurt, Vector2i(4, 1), GameEngine.SIDE_SELF)
		f_pl.health = 4        # 半血（4/6）→ 叠一张后是 10/12
		selection = ["hand", 0]
		_hover_card = engine.state.hand[0]
		status_text = "栅栏修复术：橙格「叠」= 与已有栅栏合并（生命+特性叠加）；绿格 = 普通放置"
		_shot_t0 = _now()
		queue_redraw()
	if "--relictip" in args and engine != null:
		# 演示（2026-10-01）：道具悬停浮动说明面板 —— 长描述折行，不再溢出工具栏
		RunState.relics = [6013]
		load_level(GameLevels.builtin_levels()[0])
		engine.self_relics = [6013]
		var rel := RelicRepo.load_json().get_relic(6013)
		_demo_tip_text = "「%s」（%s）%s\n当前复活概率 100%%。" % [rel.relic_name,
				rel.tag_line(), rel.desc]
		_hover_relic_tip = _demo_tip_text
		Input.warp_mouse(_relic_rect(0).get_center())  # 真窗口下把鼠标挪到徽章上，走真实悬停路径
		_shot_t0 = _now()
		queue_redraw()
	if "--newspells" in args and engine != null:
		# 演示（2026-10-01，第 37 轮）：6 张新卡一起上手 ——
		# 魔法塔 9075 / 魔力核心 9076 / 陨石术 9077 / 复活术 9078 / 魔像术 9079 / 魔法学徒 9081。
		# 悬停最长的陨石术 → 左栏信息面板核验长文案折行；场上摆一座魔法塔 + 一个召唤出的魔像。
		engine.state.hand.clear()
		for _nid in [9075, 9076, 9077, 9078, 9079, 9081]:
			engine.state.hand.append(repo.get_card(_nid))
		engine.state.energy = 9
		engine.state.place(repo.get_card(9075), Vector2i(5, 0), GameEngine.SIDE_SELF)
		engine._golem_spell(GameEngine.SIDE_SELF, Vector2i(4, 1))
		_demo_hover_idx = 2
		status_text = "第 37 轮新卡：魔法塔 / 魔力核心 / 陨石术 / 复活术 / 魔像术 / 魔法学徒"
		_shot_t0 = _now()
		queue_redraw()
	if "--voidlord" in args and engine != null:
		# 演示（2026-10-01，第 38 轮）：虚空主宰（9082）——
		# 手卡里的本卡：本次对战已用技能对敌造成 3 次伤害 → 10 - 6 = 4 费；
		# 场上已有一座 → 手卡里的技能牌费用 -1（陨石术 10 → 9、魔像术 4 → 3）。
		engine.state.hand.clear()
		engine.state.energy = 30
		engine.state.void_dmg_spells = 3
		engine.state.hand.append(CardData.from_dict(repo.get_card(9082).to_dict()))
		for _vid in [9077, 9007, 9079]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(_vid).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(9082).to_dict()),
				Vector2i(5, 0), GameEngine.SIDE_SELF)
		_hover_card = engine.state.hand[0]
		_hover_hand = 0   # 让左栏信息面板走 cost_of（显示当前实际费用，低于卡面标绿）
		status_text = "虚空主宰：场上 1 张 → 技能牌 -1 费；已对敌伤害 3 次 → 本卡 10-6 = 4 费"
		_shot_t0 = _now()
		queue_redraw()
	if "--revive" in args and engine != null:
		# 演示（2026-10-01，第 37 轮）：复活术（9078）——打出后弹出「从弃牌区取一张盟友」面板。
		engine.state.energy = 5
		for _rid in [8003, 9031, 9032, 9033, 8002]:
			engine.state.discard.append(repo.get_card(_rid))
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(9078))
		engine.use_spell(0)
		_hover_card = null
		status_text = "复活术：从弃牌区选择一张盟友回到手卡（必须选一张）"
		_shot_t0 = _now()
		queue_redraw()
	if NetSession.active:
		_setup_net()   # 联机已停用：NetSession.active 恒为 false（大厅已移除）
	# R148：Esc 主菜单（齿轮按钮 / Esc 键都走它）—— 顶栏原来那排按钮全收进这里。
	# ⚠️ items 传的是**函数引用**：每次打开菜单重新求值，文案 / 禁用态因此总是最新的
	#    （比如「查看地图」要看本局有没有地图）。
	# （`--menu` 演示由 UiMenu 自己识别：它开着菜单出图时会强制不暂停）
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "返回战斗",
		"sub": "战斗中 · 按 Esc 返回",
	})


# R77：鸭语耳环（6015）逐张自动出牌的播放状态。
# 原来自动出牌在引擎的 _begin_turn 里一次跑完，玩家完全看不到过程。
var _earring_at := 0            # 上一次出牌的时刻（_now）
var _earring_i := 0             # 已播到第几张
var _earring_gap := 620         # 每张之间的停顿（ms）—— 严格按动画节奏走，不赶
var _earring_done := false      # 播完了（用来撤掉提示 / 解锁操作）
var _shot_pending := false
var _demo_pending := false
var _demo_args: Array = []      # -- 后的用户参数（demo 分支判断用）
var _demo_frame := 0
var _shot_frame := 150
var _shot_ms := 0               # --shotms：距演示动作的毫秒数（比帧号稳定）
var _shot_t0 := 0               # 演示动作起始时刻（_now）
var _cue_demo := false          # R288：--r288pulse 出图时允许演出队列照常推进
var _cue_pin := 0               # R288：出图时钉在第几个镜头段（跨屏轮流取证用）


func _demo_tick() -> void:
	_demo_frame += 1
	if "--r302mention" in _demo_args and engine != null and not _mention_hits.is_empty():
		# R302 演示：鼠标压在第一个「提及」命中矩形上 → 左栏底部没有固定摘要块，
		# 而是弹出真实卡面（触屏路径是「点一下钉住」，走 `_on_left_click`）。
		var rm: Dictionary = _mention_hits[0]
		_on_hover((rm["rect"] as Rect2).get_center())
	if _shot_pending and "--r327funeral" in _demo_args \
			and _demo_frame == _shot_frame - 40 and engine != null:
		# R327 出图：截图前 40 帧（≈0.67s）再打掉那个树人 —— 既躲过开局横幅
		# （`--shotframe 600`），又让「送葬 +1 张」飘字还在屏上（1600ms 生命周期）。
		engine.damage_cell(Vector2i(4, 1), 99, "演示")
		engine._destroy_dead()
		# 窗口开局时系统鼠标会投一次 MouseMotion（正好压在树人身上）→ 左栏详情
		# 会盖住「效果区」。出图前把悬停 + 选中一起清掉（左栏也认 `selection` 兜底）。
		_clear_hover_state()
		selection = null
	if _shot_pending and "--r332instinct" in _demo_args \
			and _demo_frame == _shot_frame - 40 and engine != null:
		# R332 出图：截图前 40 帧才打本能 —— 躲过开局横幅，又让状态栏播报 +
		# 「本能 · 卡名列表」飘字还在屏上（1700ms 生命周期）。
		engine.use_spell(0, null)
		_clear_hover_state()
		selection = null
	if _shot_pending and "--r331hidden" in _demo_args \
			and _demo_frame == _shot_frame - 40 and engine != null:
		# R331 出图：截图前 40 帧打掉那个带「死亡」的单位 —— 躲过开局横幅，
		# 又让「隐藏能源 -8」飘字还在屏上（1600ms 生命周期）。
		engine.damage_cell(Vector2i(4, 1), 99, "演示")
		engine._destroy_dead()
		_clear_hover_state()
		selection = null
	if _shot_pending and "--r288knife" in _demo_args \
			and _demo_frame == _shot_frame - 12 and engine != null:
		# 真走引擎结算：主刀 `_op_deal_damage` + 两跳 `_hit_unit`，
		# 三条 fx_impact 会被界面合并成一条演出（光带才连得起来）。
		var rk_card := CardRepo.load_json().get_card(9160)
		engine._bounce_knife(GameEngine.SIDE_SELF, Vector2i(2, 1), rk_card)
	if _shot_pending and "--r288span" in _demo_args \
			and _demo_frame == _shot_frame - 12 and engine != null:
		# 跨屏：发动者 (5,1) 与受影者 (0,1) 一起入队 → _begin_cue 自动切成两段
		_push_cue([Vector2i(5, 1), Vector2i(0, 1)], "龙息", Color("8f5ad0"),
				Vector2i(5, 1))   # R321：带上发动者，出图才还有光带
	if _shot_pending and "--r288pulse" in _demo_args \
			and _demo_frame == _shot_frame - 12 and engine != null:
		# R288：只播表现、不真扣血（出图要可重复，不能被伤害次数带偏）
		var rp_card := CardRepo.load_json().get_card(9014)
		engine._fx_pulse(Vector2i(4, 1), rp_card, "龙息")
		_push_cue([Vector2i(2, 1)], "", Color("8f5ad0"))
	if "--griddrag" in _demo_args:
		# ⚠️ 这里**不能 return** —— 截图与退出在 _demo_tick 末尾，提前返回游戏永远不退出。
		_demo_grid_drag()      # R136：左键拖棋盘的出图演示（只服务截图）
	if _shot_pending and "--fan" in _demo_args and not engine.state.hand.is_empty():
		# 截图窗口打开时系统鼠标会触发一次真实 _on_hover，把 _ready 里设置的
		# 悬停清掉 → 截图期间每帧重新钉住（验证「抬手 + 左栏详情面板」用）
		_hover_hand = engine.state.hand.size() / 2
		_hover_card = engine.state.hand[_hover_hand]
	if _shot_pending and ("--newcards" in _demo_args or "--lion" in _demo_args or "--hound" in _demo_args) and not engine.state.hand.is_empty():
		# 同上：钉住 0 号手牌的悬停，让左栏详情显示「费用 N（原 M）」标绿
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
	if "--r299burn" in _demo_args and _demo_frame == 40 and engine != null:
		# R299 出图演示①（`--screenshot --r299burn --shotms 120`）：手牌满 → 再抽 3 张，
		# 3 张都不进手、各发一条 hand_burn → 界面播「牌堆 → 弃牌堆」的飞行 + 提示。
		for _i in 20:
			if engine.state.hand_full():
				break
			if engine.state.draw() == null:
				break
		engine._draw_many(3)
		status_text = "R299：手牌满 → 抽到的 3 张没进手，改飞弃牌堆"
		_shot_t0 = _now()
		queue_redraw()
	if "--r299dry" in _demo_args and _demo_frame == 40 and engine != null:
		# R299 出图演示②（`--screenshot --r299dry --shotms 200`）：牌库与弃牌区都抽干
		# → deck_empty 横幅（醒目但不拦操作）。
		engine.state.deck.clear()
		engine.state.discard.clear()
		engine._draw_many(2)
		status_text = "R299：牌库与弃牌区都已空 → 抽不到卡（不拦操作）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r300inspire" in _demo_args and _demo_frame == 40 and engine != null:
		# R300 出图演示（`--screenshot --r300inspire --shotms 150`）：效果区两张「激发」，
		# 场上一个己方单位被「升级」改造 → 全体敌人各 -6（3 × 2 轮）。
		var insp := CardRepo.load_json().get_card(GameEngine.INSPIRE_ID)
		if insp != null:
			engine.state.effects.append(CardData.from_dict(insp.to_dict()))
			engine.state.effects.append(CardData.from_dict(insp.to_dict()))
		var demo_repo := CardRepo.load_json()
		if not engine.state.board.has(Vector2i(1, 0)):
			engine.state.place(demo_repo.get_card(1011), Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
		if not engine.state.board.has(Vector2i(1, 2)):
			engine.state.place(demo_repo.get_card(1011), Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
		if not engine.state.board.has(Vector2i(4, 1)):
			engine.state.place(demo_repo.get_card(8003), Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine._upgrade_unit(Vector2i(4, 1), GameEngine.SIDE_SELF)
		status_text = "R300 激发 ×2：一次改造 → 全体敌人各 -6（3 点 × 2 轮）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r301color" in _demo_args and _demo_frame == 40 and engine != null:
		# R301 出图演示①（`--screenshot --r301color --shotms 200`）：四项数值相对**卡库原型**
		# 的涨跌染色 —— 力/程/速 高绿低红；生命四态（受伤红 / 高于原本绿 / 等于白 / 低于黄）。
		# 手卡：白（原样）· 绿（改造过）· 黄+红（削过，满血上限低 → 黄，力量低 → 红）
		_banner = {}          # 出图：先收掉「我方回合」大字横幅，别挡住棋盘徽章
		var rr := CardRepo.load_json()
		var base_hand: CardData = rr.get_card(8003)   # 树人 3/8/1/1
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(base_hand.to_dict()))
		var c_up := CardData.from_dict(base_hand.to_dict())
		c_up.power += 2
		c_up.health += 6
		engine.state.hand.append(c_up)
		var c_dn := CardData.from_dict(base_hand.to_dict())
		c_dn.power -= 2
		c_dn.health -= 3
		engine.state.hand.append(c_dn)
		# 场上：一个**受过伤**的己方单位（生命 = 红），一个**改造过且满血**的（生命 = 绿）
		var up1: Placement = engine.state.unit_at(Vector2i(2, 2))
		if up1 == null:
			up1 = engine.state.place(rr.get_card(8003), Vector2i(2, 2), GameEngine.SIDE_SELF)
		if up1 != null:
			up1.health = maxi(1, up1.card.health - 3)   # 受伤 → 红
		var up2: Placement = engine.state.unit_at(Vector2i(3, 2))
		if up2 == null:
			up2 = engine.state.place(CardData.from_dict(base_hand.to_dict()),
					Vector2i(3, 2), GameEngine.SIDE_SELF)
		if up2 != null:
			up2.card.power += 2
			up2.card.health += 6
			up2.health = up2.card.health            # 满血 → 绿
		status_text = "R301：力/程/速 高=绿 低=红；生命 受伤=红 · 高于原本且满血=绿 · 持平=白 · 低于原本且满血=黄"
		_shot_t0 = _now()
		queue_redraw()
	if "--r314relic" in _demo_args and _demo_frame == 40 and engine != null:
		# R314 出图演示（`--screenshot --r314relic --shotms 900`）：道具栏**高亮**。
		# 亮 = 这一刻真的会 / 正在触发：
		#   风妖精（下一张就是第 5 张）· 鸭翼（第 3 回合）· lucky 7（生效回合）
		# 不亮 = 一直在被动生效：鸭嘴 · 储物箱（用户口径：这类不做）
		_banner = {}
		var r314_ids: Array[int] = [6042, 6045, 6007, 6006, 6044]
		engine.self_relics = r314_ids
		engine.turn_number = 3            # 鸭翼：第 3 回合
		engine.state.self_turn_no = 3
		engine.state.self_card_plays = 4  # 风妖精：下一张就是第 5 张
		engine._lucky7_active = true      # lucky 7：本回合生效
		status_text = "R314：亮 = 这一刻会触发（风妖精/鸭翼/lucky 7）；常亮失效的不亮（鸭嘴/储物箱）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r301view" in _demo_args and _demo_frame == 40 and engine != null:
		# R301 出图演示②（`--screenshot --r301view --shotms 260`）：弃牌区 = 全屏浏览窗
		# （复用选卡页排版：每行 5 张放大卡 + 滚动 + 底部描述条）。
		var rv := CardRepo.load_json()
		engine.state.discard.clear()
		for sid: int in [8003, 8001, 8002, 8004, 9007, 8003, 1011, 1053, 8003, 8001, 8002, 9001]:
			engine.state.discard.append(CardData.from_dict(rv.get_card(sid).to_dict()))
		_open_discard_view()
		status_text = "R301：弃牌区改成选卡页那种全屏窗口（每行 5 张 · 滚动 · 底部描述）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r311dice" in _demo_args and _demo_frame == 40 and engine != null:
		# R311 出图（`--screenshot --r311dice --shotms 700`）：水晶骰子掷骰 → 飘字 + 状态栏。
		# ⚠️ 走真实入口 `apply_battle_start_relics()`（用**战斗种子**掷），只是开局已经
		#    过了，第 1 回合那份加费在 `_begin_turn` 里发不出来 —— 这里按同一条规则补一次，
		#    好让出图能看到「能量 6」而不是「能量 5」。真实路径由回归断言钉住。
		_banner = {}          # 出图：收掉「我方回合」大字横幅，别挡住飘字
		engine.self_relics = [GameEngine.DICE_RELIC_ID]
		engine.dice_battle = true
		engine.apply_battle_start_relics(repo)
		if engine.dice_energy_turns > 0:
			engine.state.energy += GameEngine.DICE_ENERGY
		status_text = "R311 水晶骰子：骰出 %d 点 → 前 %d 回合每回合 +1 费" % [
				engine.dice_roll, engine.dice_energy_turns]
		_shot_t0 = _now()
		queue_redraw()
	if _demo_pending and _demo_frame == 20 and _tutorial.is_empty():
		# 演示确定性：手牌里没有寒冰护盾就换进一张（仅新手试炼演示用）
		var has_shield := false
		for c in engine.state.hand:
			if c.id == 7202:
				has_shield = true
				break
		if not has_shield:
			var shields := repo.starter_deck().filter(func(c): return c.id == 7202)
			if not shields.is_empty():
				engine.state.hand[engine.state.hand.size() - 1] = shields[0]
	if _demo_pending and _demo_frame == 30:
		# 演示①：寒冰护盾完整走一遍「选中 → 进入选目标 → 点击目标结算」
		# （第 1 回合费用恰好 2，先放护盾，剑士让给后面的回合）
		for i in engine.state.hand.size():
			if engine.state.hand[i].id == 7202 and engine.can_pay(2) \
					and not engine.state.board.is_empty():
				_clear_selection()
				selection = ["hand", i]
				_use_hand_card(i)
				if spell_pending >= 0 and not spell_targets.is_empty():
					var target: Vector2i = spell_targets[0]
					_on_board_click(target)
					status_text = "演示：寒冰护盾选目标 %s 结算 ✓" % target
				break
		queue_redraw()
	if _demo_pending and _demo_frame == 60 and not engine.state.board.has(Vector2i(4, 1)):
		# 演示②：费用够就上场一名见习剑士，选中它展示高亮
		var idx := -1
		for i in engine.state.hand.size():
			if engine.state.hand[i].id == 7001:
				idx = i
				break
		if idx >= 0 and engine.can_pay_card(engine.state.hand[idx]):
			engine.play_from_hand(idx, Vector2i(4, 1))
			_select_board(Vector2i(4, 1))
			status_text = "演示：见习剑士上场，绿色=移动 红色=攻击 深红=打HP"
		queue_redraw()
	if _demo_frame == 90 and _demo_pending and engine.current_side == GameEngine.SIDE_SELF:
		_on_end_turn()  # 演示：结束回合，让 AI 推进
	if _demo_pending and "--projshot" in _demo_args and _demo_frame == 80:
		# 演示：构造一次攻击捕捉弹体投射（配合 --shotframe 125 截飞行中段）
		engine.state.place(repo.get_card(7001), Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(7001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.attack(Vector2i(3, 1), Vector2i(2, 1))
		status_text = "演示：弹体投射特效"
		_hover_card = repo.get_card(8002)  # 模拟悬停：验证信息栏渲染
		queue_redraw()
	if "--killshot" in _demo_args and _demo_frame == 80:
		# 演示：构造一次「击杀」，用于验证「先掉血 → 卡牌才消失」的时序
		var atk_card := repo.get_card(8003)   # 农民 力3
		var weak := repo.get_card(1053)       # 骷髅兵 生2
		if atk_card != null and weak != null:
			engine.state.place(atk_card, Vector2i(3, 1), GameEngine.SIDE_SELF)
			engine.state.place(weak, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
			engine.attack(Vector2i(3, 1), Vector2i(2, 1))
			_shot_t0 = _now()
			status_text = "演示：击杀时序（先掉血，再击破）"
			queue_redraw()
	if "--aiattack" in _demo_args and _demo_frame == 70:
		# 演示：敌方「移动 + 攻击」连击 —— 验证动画排队（先滑行到位、再蓄力出手），
		# 而不是像以前那样攻击段被滑行盖住、动作一闪而过。
		for c: Vector2i in engine.state.board.keys():
			engine.state.board.erase(c)
		engine.state.place(repo.get_card(1053), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(repo.get_card(8003), Vector2i(3, 1), GameEngine.SIDE_SELF)
		status_text = "演示：敌方移动+攻击（滑行完再出手）"
		queue_redraw()
	if "--aiattack" in _demo_args and _demo_frame == 90:
		_on_end_turn()          # 交给 AI：它会先推进、再攻击挡路的农民
		_shot_t0 = _now()
	if "--finisher" in _demo_args and _demo_frame == 80 and engine != null:
		# 收尾演示的实际出牌（延到第 80 帧，避开开局「我方回合」横幅盖住飘字）。
		engine.use_spell(0, Vector2i(2, 0))        # 手卡还剩一张 → 6 伤
		engine.use_spell(0, Vector2i(2, 2))        # 只剩它自己 → 22 伤
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "收尾 6 伤 / 手卡仅剩它 22 伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--bypassshot" in _demo_args and _demo_frame == 60:
		# 演示：摆两格「不拦路」的工事（中路 + 我方后排），
		# 看 AI 是绕过去直击 HP（而不是像以前那样见工事就拆）。
		_log_visible = true
		engine.state.place(repo.get_card(8001), Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8001), Vector2i(5, 0), GameEngine.SIDE_SELF)
		status_text = "演示：工事不拦路 → AI 应当绕行直击 HP"
		queue_redraw()
	if "--bypassshot" in _demo_args and _demo_frame == 80:
		_on_end_turn()          # 交给 AI 行动，让它自己选路线
		_shot_t0 = _now()
	if _shot_pending and "--dragshot" in _demo_args:
		_demo_dragshot()          # R117 临时演示：钉住一次拖拽（见函数注释）
	if _shot_pending and "--aoe" in _demo_args:
		_demo_aoe_drag()          # R242 演示：AOE 范围 / 自伤警告 / 条件额外加成
	var shot_due := _shot_pending and _demo_frame == _shot_frame
	if _shot_pending and _shot_t0 > 0 and _now() - _shot_t0 >= _shot_ms \
			and "--shotms" in _demo_args:
		shot_due = true   # 按「距击杀动作的毫秒数」触发，比帧号稳定
	if shot_due:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://screenshot.png"))
		get_tree().quit()


func _demo_dragshot() -> void:
	## R117 演示（配合 `--screenshot --dragshot --shotframe N`）：把一次拖拽**钉住**在
	## 屏幕上若干帧，让截图能拍到「拖拽进行中」的画面。与 `--fan` / `--projshot` /
	## `--killshot` / `--bypassshot` / `--trapper` 同族。可核两件事 ——
	##   ① 「松手即生效」的区域外框（`_drag_zone_rect`）画得对不对；
	##   ② 光标被推到区域**之外**（松手 = 取消）时，目标光圈**不再**画出
	##      （`_drag_hit_cell` 返回 null）。
	## 参数：`--dragpos x,y` 指定光标（不给 = 钉在第一个合法目标格的中心，即区域内）；
	##       `--dragkind effect` 改拖效果卡 9002（投放区 = `_effect_drop_rect()`）。
	## ⚠️ 只服务出图，不进任何正式流程。
	if engine == null:
		return
	if _drag_idx < 0:
		# 摆三个靶子：一个敌方（前排）、两个己方（后排左右）—— 目标格连成一大片，
		# 「可释放区域」的外框才有意义（只有一个目标格时外框 = 那一格，看不出效果）。
		if not engine.state.board.has(Vector2i(1, 1)):
			engine.state.place(repo.get_card(1053), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
			engine.state.place(repo.get_card(8003), Vector2i(3, 0), GameEngine.SIDE_SELF)
			engine.state.place(repo.get_card(8003), Vector2i(3, 2), GameEngine.SIDE_SELF)
			# 再补一个**正下方**的单位（row2,col1 在 row1,col1 骷髅兵的正下方）——
			# 用来目视核对「上下相邻行的数值徽章会不会互相压住」。
			engine.state.place(repo.get_card(8003), Vector2i(2, 1), GameEngine.SIDE_SELF)
		# 手牌里找一张**目标型技能**来拖（攻击 8002，初始卡组 ×5，稳在手里）。
		var idx := -1
		if "--dragkind" in _demo_args and "effect" in _demo_args:
			# 效果卡（`is_effect()`）：投放区是**左栏整条**，不是效果区那一小块。
			var eff := repo.get_card(9002)   # 迅捷，2 费效果卡
			if eff == null:
				return
			engine.state.hand[0] = eff
			idx = 0
		elif "--dragkind" in _demo_args and "place" in _demo_args:
			# R286 出图：拖**工事**（木栅栏 8001）→ 放置高亮应只有自己半场（下 3 行），
			# R285 曾放宽成「除对方后排全图」。`--dragkind place`。
			var pl := repo.get_card(8001)
			if pl == null:
				return
			engine.state.hand[0] = pl
			idx = 0
		else:
			for i in engine.state.hand.size():
				if engine.state.hand[i].id == 8002:   # 攻击：target_mode=unit，初始卡组 ×5
					idx = i
					break
		if idx < 0:
			return
		_start_drag(idx, _cell_center(Vector2i(3, 0)))
		queue_redraw()
		return
	# 已经在拖了 → 每帧把光标钉回目标点（截图窗口打开时系统鼠标会往别处跑）。
	var p := _demo_drag_pos()
	if p != Vector2.ZERO:
		_drag_pos = p
	queue_redraw()


func _demo_aoe_drag() -> void:
	## R242 演示（**只服务出图**，不进任何正式流程）：把一张 AOE / 条件加成技能拖住并钉在指定格。
	## 用法：`battle.tscn -- --screenshot --aoe 9007 --aoepos x,y --shotframe 90`
	##   `--aoe <id>`   拖哪张卡（9007 火球 / 9084 火墙 / 9090 偷袭）
	##   `--aoepos x,y` / `--aoecell 行,列` 光标钉在哪（不给 = 第一个合法目标格）
	## 摆位只做一次：我方两个树人（4,0 / 4,2）+ 敌方一个满血骷髅（2,1），于是
	##   * 火球砸 (4,1) → 同时演「波及自己人 ×2」与「会伤到自己 HP」；
	##   * 火墙选第 4 行 → 演「我方单位在这行，走过去会被烧」；
	##   * 偷袭打 (2,1) 的满血敌人 → 演金色双环「满血：6 → 12」。
	if engine == null:
		return
	if _drag_idx < 0:
		var want := GameEngine.FIREBALL_ID
		for i in _demo_args.size():
			if _demo_args[i] == "--aoe" and i + 1 < _demo_args.size():
				want = int(_demo_args[i + 1])
		var c := repo.get_card(want)
		if c == null:
			return
		if not engine.state.board.has(Vector2i(4, 0)):
			engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)
		if not engine.state.board.has(Vector2i(4, 2)):
			engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)
		if not engine.state.board.has(Vector2i(2, 1)):
			engine.state.place(repo.get_card(1053), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		# 手牌此刻可能还没抽上来（开局前几帧是空数组）→ 空了就先 append。
		# 走 from_dict 复制：`get_card()` 的静态类型是 RefCounted，直接塞进
		# `Array[CardData]` 会被运行时拒（实见 Invalid assignment）。
		var hc := CardData.from_dict(c.to_dict())
		if engine.state.hand.is_empty():
			engine.state.hand.append(hc)
		else:
			engine.state.hand[0] = hc
		_banner = {}    # 只截图：回合横幅会压在 AOE 范围顶部
		engine.state.energy = 99        # 出图不该卡在「能量不足」
		_start_drag(0, _cell_center(Vector2i(4, 0)))
		queue_redraw()
		return
	var p := _demo_aoe_pos()
	if p != Vector2.ZERO:
		_drag_pos = p
	queue_redraw()


func _demo_aoe_pos() -> Vector2:
	## `--aoepos x,y`（像素）或 `--aoecell 行,列`（格子）指定的光标；
	## 都不给 = 第一个合法目标格的中心。出图用手算像素容易偏，优先用 --aoecell。
	for i in _demo_args.size():
		if _demo_args[i] == "--aoecell" and i + 1 < _demo_args.size():
			var rc := str(_demo_args[i + 1]).split(",")
			if rc.size() == 2:
				return _cell_center(Vector2i(int(rc[0]), int(rc[1])))
	for i in _demo_args.size():
		if _demo_args[i] == "--aoepos" and i + 1 < _demo_args.size():
			var parts := str(_demo_args[i + 1]).split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0]), float(parts[1]))
	if not _drag_spell_cells.is_empty():
		return _cell_center(_drag_spell_cells[0])
	return Vector2.ZERO


func _demo_drag_pos() -> Vector2:
	## `--dragpos x,y` 指定的光标；不给则取「第一个合法目标格的中心」（落在区域内）。
	for i in _demo_args.size():
		if _demo_args[i] == "--dragpos" and i + 1 < _demo_args.size():
			var parts := str(_demo_args[i + 1]).split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0]), float(parts[1]))
	if _drag_to_effects:
		var ez := _effect_drop_rect()
		return ez.position + ez.size / 2.0
	if not _drag_spell_cells.is_empty():
		return _cell_center(_drag_spell_cells[0])
	return Vector2.ZERO


func _demo_grid_drag() -> void:
	## R136 演示：合成一串「按住棋盘 → 往下拖 60px → 松手」的输入事件，
	## **直接喂给 `_gui_input`** 走完整的上膛 / 阈值 / 滚动 / 松手流程，
	## 用来验证左键拖动真的在滚棋盘。配合 `-- --screenshot --shotframe 80`：
	## 巡场动画会在按下那一刻被打断（或已播完，终点 = 我方半场 = max），随后拖动把它
	## 推到别处 —— 巡场自己只会停在两端（max 我方 / min 敌方），中间值只能是拖出来的。
	## ⚠️ 只服务出图，不进任何正式流程。
	if _demo_frame == 40:
		_feed_mouse_btn(MOUSE_BUTTON_LEFT, true, Vector2(GRID_X + 60, GRID_Y + 300))
	elif _demo_frame > 40 and _demo_frame <= 50:
		_feed_mouse_motion(Vector2(GRID_X + 60, GRID_Y + 300 + (_demo_frame - 40) * 6.0))
	elif _demo_frame == 51:
		_feed_mouse_btn(MOUSE_BUTTON_LEFT, false, Vector2(GRID_X + 60, GRID_Y + 360))
		_say("演示：左键在棋盘上拖动 60px → 滚动了 %d px" % int(_grid_scroll))


func _feed_mouse_btn(btn: MouseButton, pressed: bool, pos: Vector2) -> void:
	## 合成鼠标按键事件（局部坐标 = 设计坐标）直接喂给 _gui_input（出图演示用）。
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.position = pos
	_gui_input(ev)
	queue_redraw()


func _feed_mouse_motion(pos: Vector2) -> void:
	## 合成鼠标移动事件（同上）。
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	_gui_input(ev)
	queue_redraw()


func _load_entry_level() -> void:
	## 进入战斗场景时的**首次开局**（原来叫 _restart，是「重开一局」按钮的处理函数；
	## R64 那个按钮没做用已删除，这里只保留开局装载的职责，名字改成不含「重开」）。
	if RunState.run_active:
		# 地图流程：进战斗前由 map_scene 设置 pending_level
		if not RunState.pending_level.is_empty():
			var lvl := RunState.pending_level
			RunState.pending_level = {}
			load_level(lvl)
		else:
			load_level(GameLevels.builtin_levels()[0])
		return
	load_level(GameLevels.builtin_levels()[0])  # 默认：怪物遭遇战


# ------------------------------------------------------------ 联机模式

func _setup_net() -> void:
	## 联机开局（对应 Python 版 NetFieldWindow）：双方各跑一份镜像引擎，
	## 我方动作发出去、对方动作收进来按 450ms 间隔回放。
	_net_mode = true
	var deck: Array[CardData] = repo.starter_deck()
	# R312（种子审计）：**洗牌种子必须可复现**。这里原来不传 rng → `FieldState` 退回
	# 「全局随机洗牌」，两台机器会各自洗出不同顺序，镜像引擎从第一回合就对不上。
	# 现在用**卡组内容哈希**当种子：双方用同一套卡组时必然同一顺序（默认新手卡组即如此）。
	var net_rng := RandomNumberGenerator.new()
	var net_h := 2166136261
	for nc: CardData in deck:
		net_h = ((net_h ^ nc.id) * 16777619) & 0x7FFFFFFF
	net_rng.seed = net_h
	var state := FieldState.new(deck, 20, 20, -1, "联机对战", true, net_rng)
	engine = GameEngine.new(state)
	engine.ai_enabled = false
	engine.action.connect(_on_engine_action)
	engine.start_game(5, NetSession.opp_deck_size, NetSession.i_start)
	_clear_selection()
	_slides.clear()
	_attacks.clear()
	_delayed.clear()
	_ghosts.clear()
	_dying.clear()
	_floaters.clear()
	_flashes.clear()
	_bursts.clear()
	_hp_pending.clear()
	_shake_until = 0
	_hover_card = null
	_hover_pl = null
	_cur_level = {}
	_tutorial = []
	tutorial_step = 0
	_tutorial_finished = true
	_tut_update_bar()
	_over_panel.visible = false
	_over_shown = false
	_confetti.clear()
	status_text = "联机对局 vs %s —— %s" % [NetSession.opp_name,
			"你先手，请行动" if NetSession.i_start else "等待对方行动…"]
	if NetSession.i_start:
		_show_banner("我方回合 · 第 1 回合")
	else:
		_show_banner("%s 行动中" % NetSession.opp_name, Color("8a2b2b"))
	queue_redraw()


func _net_locked() -> bool:
	## 联机时锁操作：对方回合 / 回放中。
	return _net_mode and (engine.current_side != GameEngine.SIDE_SELF or _net_replaying)


func _net_send(msg: Dictionary) -> void:
	## 发消息给对方（非联机模式是空操作）；失败按断线处理。
	if not _net_mode:
		return
	var link = NetSession.link
	if link == null or not link.send(msg):
		_net_disconnect()


func _net_poll(delta: float) -> void:
	## 每帧：收信 → 回放队列逐条出（间隔 NET_GAP）。
	var link = NetSession.link
	if link != null:
		link.poll()
		if link.drain_into(_net_queue):
			_net_disconnect()
			return
	if _net_replaying:
		_net_wait -= delta
		if _net_wait <= 0.0:
			_net_replaying = false
	if engine.over or _net_replaying or _net_queue.is_empty():
		return
	var msg: Dictionary = _net_queue.pop_front()
	_clear_selection()
	_apply_net_msg(msg)
	_net_replaying = true
	_net_wait = Net.NET_GAP_MS / 1000.0
	queue_redraw()


func _apply_net_msg(msg: Dictionary) -> void:
	## 对方一条消息在本机引擎上重放（镜像引擎，动作信号自动带动画/音效）。
	var t := str(msg.get("type"))
	if t == "bye":
		NetSession.opp_left = true
		return
	if engine.over or t != "action":
		return
	var args: Array = msg.get("args", []) if msg.has("args") else []
	match str(msg.get("act")):
		"play":
			engine.remote_play(CardData.from_dict(msg["card"]), _net_vec(msg["cell"]))
		"spell":
			engine.remote_spell(CardData.from_dict(msg["card"]),
					_net_cell_or_null(msg.get("target")))
		"move":
			engine.move(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"attack":
			engine.attack(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"hp":
			engine.attack_hp(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"pass":
			# 对方移动后放弃攻击 → 镜像横置
			engine.pass_attack(_net_vec(args[0]), GameEngine.SIDE_OPPONENT)
		"activate":
			# 对方主动发动（熊 8004「回春」）
			engine.activate(_net_vec(args[0]), GameEngine.SIDE_OPPONENT)
		"curse":
			# R223：对方打出诅咒（无效果）—— 镜像侧扣能量、手牌数 -1、记一次出牌
			engine.remote_curse(CardData.from_dict(msg["card"]))


func _net_vec(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _net_cell_or_null(v) -> Variant:
	if v is Array and v.size() == 2:
		return _net_vec(v)
	return null


func _net_disconnect() -> void:
	## 对方断线 / 离开：提示后 2 秒回标题。
	if NetSession.opp_left:
		return
	status_text = "对方已离开对局或连接断开"
	NetSession.opp_left = true
	NetSession.clear()   # 关闭连接
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 2.0
	t.one_shot = true
	t.timeout.connect(func(): SceneFx.goto("res://scenes/title.tscn"))
	add_child(t)
	t.start()


func _refresh_flee_btn() -> void:
	## R341 洞窟绳（6048）：按钮显隐 = `RunState.can_use_cave_rope()` 那一处判据。
	## ⚠️ `engine` 可能还没建（`load_level` 之前）→ 直接藏起来，别访问 null。
	if engine == null:
		flee_btn.visible = false
		return
	flee_btn.visible = RunState.run_active \
			and RunState.can_use_cave_rope(engine.battle_kind)

func _on_flee() -> void:
	## R341 洞窟绳：**逃跑 = 放弃本场**。
	##   * 不拿任何奖励（金币 / 道具 / 卡牌全不发），也不记胜场；
	##   * 体力在**进房间时**已经照常扣掉了，这里不再补扣；
	##   * 当前生命原样带回（逃跑不是「重置」）；
	##   * 道具用掉即消失（一次性），并且清掉续档检查点 —— 逃跑的这场不该还能「继续游戏」。
	if engine == null or not RunState.run_active or _over_shown:
		return
	if not RunState.can_use_cave_rope(engine.battle_kind):
		return
	if not RunState.lose_relic(RunState.CAVE_ROPE_RELIC_ID):
		return
	_ai_timer.stop()
	_clear_battle_checkpoint()
	RunState.hp = maxi(0, engine.state.hp_self)
	RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
	RunState.complete_current()
	SceneFx.goto("res://scenes/map.tscn")


func _on_back_to_title() -> void:
	_ai_timer.stop()
	if RunState.run_active:
		# R167：回标题**不再放弃本局** —— 只复位内存状态，续档保留，
		# 标题页「继续游戏」可以从上一次地图检查点接着打。
		RunState.end_run(false)
	if _net_mode:
		_net_send({"type": "bye"})
	NetSession.clear()
	SceneFx.goto("res://scenes/title.tscn")


func _refresh_bg_texture() -> void:
	## 战斗背景（R133）：**每关独立可替换** —— 三级取图见 `UiAssets.battle_bg_name()`。
	## 关卡换一次就重取一次，所以「同一场景里换关」也会跟着换背景。
	## ⚠️ 必须在 `_cur_level = lvl` **之后**调：先知道是哪一关，才知道取哪张图。
	_bg_tex = UiAssets.battle_bg(GameLevels.bg_key(_cur_level),
			GameLevels.layer_of(_cur_level))


func load_level(lvl: Dictionary) -> void:
	## 按关卡配置开局（对应 Python 版 Level.build_engine）。
	repo = CardRepo.load_json()
	# 肉鸽 run：用当前卡组（初始 + 奖励卡）；单关/演示模式用关卡默认卡组
	var deck: Array[CardData] = RunState.build_deck(repo) \
			if RunState.run_active and not RunState.deck_ids.is_empty() \
			else GameLevels.deck_for(str(lvl["deck_key"]), repo)
	# 玩家生命来自肉鸽 run 状态（最大/当前，跨战斗保留）；关卡里的 player_hp 仅作兜底
	var p_hp: int = RunState.hp if RunState.hp > 0 else int(lvl["player_hp"])
	# 道具「烤肉」（6011）：进入 Boss 战时自动消耗 → 回复 25% 最大生命。
	# 必须在创建战斗状态之前结算，这样开局血量就是回复后的值。
	# -1 = 本次未消耗（非 Boss 战 / 没带烤肉）；>= 0 = 已消耗，值为实际回复量。
	var bbq_heal := -1
	if int(lvl.get("tier", -1)) == GameLevels.TIER_BOSS:
		bbq_heal = RunState.consume_barbecue()
		if bbq_heal >= 0:
			p_hp = RunState.hp
	# 战斗种子 = 本局随机链（run_rng）的下一环 —— 战斗内全部随机（含 AI）由它复现。
	var battle_seed: int = RunState.run_rng.randi() if RunState.run_active else 0
	var brng := RandomNumberGenerator.new()
	brng.seed = battle_seed
	var state := FieldState.new(
			deck, p_hp, GameLevels.enemy_hp_of(lvl),
			int(lvl["turn_limit"]), str(lvl["name"]), bool(lvl["shuffle"]), brng)
	state.max_hp_self = RunState.max_hp   # 上限独立于当前值（休息事件可回复）
	engine = GameEngine.new(state)
	if RunState.run_active:
		engine.rng.seed = battle_seed   # 战斗内全部随机（含 AI）可复现
	engine.ai_enabled = bool(lvl["enemy_ai"])
	engine.self_relics = RunState.relics   # 道具（鸡煲等战斗内效果由引擎结算）
	# R245：战斗类型只在这里判一次（勇气徽章等「按战斗类型生效」的道具读引擎这个字段）。
	# 用**关卡 tier** 而不是 pending_node 的 type：演示参数 / 单关入口也走同一条路，
	# 不会出现「地图说是精英、结算按普通」这种两处判据分叉。
	var _tier_for_kind := int(lvl.get("tier", -1))
	engine.battle_kind = "boss" if _tier_for_kind == GameLevels.TIER_BOSS \
			else ("elite" if _tier_for_kind >= GameLevels.TIER_ELITE_EASY else "battle")
	# R311 水晶骰子：本场是不是从「?」房进来的？判据用地图节点的 `hidden` ——
	# 那是**房间生来就有的性质**（揭晓后 `revealed` 变 true，`hidden` 不变），
	# 所以「走进 ? 房、看到是精英、开打」这一路仍然算「? 房的战斗」。
	# ⚠️ 不用 `display_type()`：它按 revealed 判，开打那一刻已经揭晓了。
	engine.dice_battle = RunState.run_active \
			and bool(RunState.pending_node.get("hidden", false))
	# R311 不锈钢盆：剩余点数跨战斗累计（存在局状态里），由引擎在承伤时递减。
	engine.basin_charge = RunState.basin_charge
	# R77：鸭语耳环（6015）改成**逐张**自动出牌 —— 由 _tick_earring_autoplay 每帧推进一步，
	# 这样每张牌的抽牌 / 出牌 / 落位动画都能看清。
	engine.autoplay_stepwise = true
	engine.duck_revive_chance = RunState.duck_revive_chance   # 叠加态的鸭：复活概率跨战斗保留
	engine.action.connect(_on_engine_action)
	for e: Array in lvl["enemy_units"]:
		var card := CardData.new()
		var from_repo := repo.get_card(int(e[0]))
		if from_repo != null:
			card = from_repo  # 卡牌库里有定义（如鸭子骑士）：直接用，保证数据同源
		else:
			card.id = int(e[0])
			card.card_name = str(e[1])
			card.kind = "盟友"
			card.cost = 1
			card.power = int(e[2])
			card.health = int(e[3])
			card.attack_range = int(e[4])
			card.move_speed = int(e[5])
		# R223 难度 3 / 6：敌方开场缩放（生命 +10% / 攻击 +1）。scaled_enemy_card
		# 内部按需返回**副本**、否则原样返回 —— 绝不改卡库原卡（卡库与关卡编成同源）。
		# 与下面的 configure_growth（atk_growth 独立叠加）互不相干。
		card = RunState.scaled_enemy_card(card)
		engine.state.place(card, e[6], GameEngine.SIDE_OPPONENT)
	# 太阳熔炉（R135）：双动光环的来源是**场上的单位**（赫利俄斯），而 `enemy_units`
	# 的摆放顺序不保证「光环源先上场」→ 摆完统一补一次（与 `enable_enemy_effects`
	# 里那句同理，只是那次是因为效果卡在单位之后才启用）。
	engine.state.apply_extra_actions(GameEngine.SIDE_OPPONENT)
	# 关卡成长曲线（二层「低开高走」）：开局削攻击力、之后随回合回升。
	# 必须在敌方单位摆好之后调用（它要按每张卡的基础攻击力算开局修正）。
	engine.configure_growth(lvl.get("enemy_growth", {}))
	# 关卡有敌方单位 → 消灭所有敌方场上单位即获胜（不依赖打空敌方 HP）
	engine.state.clear_win = not (lvl["enemy_units"] as Array).is_empty()
	# 敌方效果卡：开局即启用（进入敌方效果区，持续生效）
	var enemy_effect_cards: Array[CardData] = []
	for eid in lvl.get("enemy_effects", []):
		var ecard := repo.get_card(int(eid))
		if ecard != null:
			enemy_effect_cards.append(ecard)
	engine.enable_enemy_effects(enemy_effect_cards)
	# 先清掉上一局的显示残留（start_game 会掷出第 1 回合的鸭之低语，
	# 它的飘字/状态必须在 clear 之前进入 —— 否则会被下面这批 clear 抹掉）
	_whisper_txt = ""
	_floaters.clear()
	# 烤肉已消耗：开场飘字（血量在创建战斗状态之前就已回复完毕）
	if bbq_heal >= 0:
		sfx.play("heal")
		_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 14),
				"text": "烤肉 +%d HP" % bbq_heal, "col": Color("e08a2e"),
				"start": _now(), "dur": 2400})
	# 第二层起始道具的开场结算（冰淇淋与汽水 -3 生命 / 生蛋鸭放鸭蛋）：
	# 必须在 start_game 之前 —— 这样开局血量与场上单位的初始状态就是结算后的。
	engine.apply_battle_start_relics(repo)
	engine.start_game(int(lvl["starting_hand"]))
	_clear_selection()
	_slides.clear()
	_attacks.clear()
	_delayed.clear()
	_ghosts.clear()
	_dying.clear()
	# 注意：_floaters 不在这里 clear —— start_game 掷出的第 1 回合
	# 鸭之低语飘字需要在开场后正常展示（clear 已提前到 start_game 之前）。
	_flashes.clear()
	_bursts.clear()
	_hp_pending.clear()
	_shake_until = 0
	_hero_pick_idx = -1          # 换关/重开：待付代价的面板一并收掉
	if _pick != null:
		_pick.close()
	_hover_card = null
	_hover_pl = null
	_cur_level = lvl
	_refresh_flee_btn()   # R341 洞窟绳：换关（含重开）后重新判一次能不能逃跑
	# R176：战斗 BGM 按关卡分级取（一般 Dramatic / 精英 EpicBattle / Boss Raid_FolkMetal）。
	# 挂在这里而不是 _ready —— load_level 是「换关」的唯一入口，选关 / 换层都走到。
	Bgm.play_battle(int(lvl.get("tier", -1)))
	_refresh_bg_texture()
	_tutorial = lvl["tutorial"]
	tutorial_step = 0
	_tutorial_finished = _tutorial.is_empty()
	_tut_update_bar()
	_over_panel.visible = false
	_over_shown = false
	_confetti.clear()
	var limit: int = int(lvl["turn_limit"])
	if limit > 0:
		status_text = "%s：%d 回合内把敌方 HP（%d）打到 0！" % [
				lvl["name"], limit, GameLevels.enemy_hp_of(lvl)]
	elif not _tutorial.is_empty():
		status_text = "%s：跟着顶部引导条一步步做。" % lvl["name"]
	else:
		var tier_prefix := ""
		if lvl.has("tier"):
			tier_prefix = "【%s】" % GameLevels.tier_name(int(lvl["tier"]))
		status_text = "%s%s 开始！" % [tier_prefix, lvl["name"]]
	if bbq_heal >= 0:
		# 状态栏很窄（310px），只放简短标记；详细提示见开场飘字。
		status_text += "　｜　烤肉 +%d HP" % bbq_heal
	var intro := str(lvl.get("intro", ""))
	if intro != "":
		# 关卡开场台词（如「哈气骑士团」的「我要闹了」）：盖过回合横幅，停留更久
		_show_banner(intro, UiTheme.STAT_POWER, 2400)
	else:
		_show_banner("我方回合 · 第 1 回合")
	# R136/R146：开场巡场 —— 停自己半场 → 推进到对方半场（放大）→ **拖回我方 + 还原大小**。
	_ee_popup = false   # R197：新一场战斗，开场弹窗重新计一次
	if _grid_scrollable():
		_grid_scroll = _grid_scroll_max()
		_grid_zoom = 1.0
		_grid_intro_t = 0.0
	else:
		_grid_intro_t = -1.0
		_grid_zoom = 1.0
	queue_redraw()


# ------------------------------------------------------------ 选中 / 高亮

func _clear_selection() -> void:
	# R118：选区被清掉 = 这一轮结束，上膛状态一并归位（否则下一次选中的单位会带着
	# 「再点一次就取消」的旧账）。
	_cancel_armed = false
	selection = null
	move_targets = []
	attack_targets_arr = []
	hp_targets_arr = []
	spell_pending = -1
	spell_targets = []
	_infiltrate_src = Vector2i(-1, -1)
	# R102：「双向传送」的两段式状态同样在这里收掉 —— 右键取消 / 换牌 / 敌方回合都走它。
	_swap_src = Vector2i(-1, -1)
	# R90：「系统升级」的两段式状态也在这里收掉 —— 它不在棋盘选中体系里，
	# 但换关 / 敌方回合 / 选别的牌时都该自动取消（否则面板会一直挂着）。
	_sys_upgrade_idx = -1
	# R198：「回收」的两段式状态同理（右键取消 / 换牌 / 敌方回合都走这里）。
	_recycle_idx = -1
	# R202：「填充」的两段式状态也在这里收掉。
	_reload_idx = -1


func _select_board(cell: Vector2i) -> void:
	_cancel_armed = false   # R118：换了个选中目标 → 上膛重新计
	selection = ["board", cell]
	var p := engine.state.unit_at(cell)
	if p != null and p.moved and not p.tapped:
		if p.acts_left > 1:
			# 多动单位：还能再消耗一次行动接着走（横着挪位后再压上去）
			move_targets = engine._reachable(cell, GameEngine.SIDE_SELF)
			status_text = ("%s：已移动。红色=攻击；点绿色再走一格 = 消耗一次行动（放弃这次攻击）"
					% p.card.card_name)
		else:
			move_targets = []  # 已移动过：不能再走，只能攻击或放弃（横置）
			status_text = ("%s：已移动。点红色/深红目标攻击，点其他地方 = 放弃攻击（横置）"
					% p.card.card_name)
	else:
		move_targets = engine._reachable(cell, GameEngine.SIDE_SELF)
	attack_targets_arr = engine.legal_attack_targets(cell)
	# 主动发动（熊 8004「回春」）：可发动时把发动方式写进提示
	if p != null and engine.can_activate(cell, GameEngine.SIDE_SELF):
		status_text = ("%s：绿色=移动 红色=攻击 深红=打HP；再点它一次或按 F = 主动发动（回复 %d 生命，之后横置）"
				% [p.card.card_name, GameEngine.BEAR_HEAL])
	# 嘲讽：射程内有对方嘲讽单位 → 只能打它，不能直击 HP（隐藏深红 HP 格）
	if engine.taunt_in_range(cell, GameEngine.SIDE_SELF):
		hp_targets_arr = []
	else:
		hp_targets_arr = engine.hp_targets(cell)


func _pass_moved_pending() -> void:
	## 选中的单位若已移动未攻击：任何非攻击操作 = 放弃攻击（横置）。
	if selection != null and selection[0] == "board":
		var src: Vector2i = selection[1]
		var p := engine.state.unit_at(src)
		if p != null and p.owner == GameEngine.SIDE_SELF and p.moved and not p.tapped:
			engine.pass_attack(src, GameEngine.SIDE_SELF)
			if _net_mode:
				_net_send({"type": "action", "act": "pass",
						"args": [[src.x, src.y]]})


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if engine == null or engine.over or _net_locked():
		return
	# R136：巡场动画播放中，玩家一按鼠标就停（动画只是提示，绝不吞操作）。
	if event is InputEventMouseButton and event.pressed and _grid_intro_t >= 0.0:
		_grid_intro_stop()
	# R186：触屏长按 = 右键。emulate_mouse_from_touch 会把同一次触摸再发一遍左键事件，
	# 那条路径照旧走（点选 / 拖牌）；这里只额外计时，到时在 _process 里转成右键。
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_lp_active = true
			_lp_fired = false
			_lp_pos = st.position
			_lp_t0 = _now()
		else:
			_lp_active = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _lp_active and sd.position.distance_to(_lp_pos) > LP_SLOP:
			_lp_active = false   # 位移超阈值 = 拖拽，不是长按
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 手牌按下：先不触发点击逻辑，等松手判定是点击还是拖拽
			_press_idx = _hand_index_at(event.position)
			_press_pos = event.position
			# R136：按下点落在棋盘**可视窗内**（且不是在手牌上）→ 先不立即结算点击，
			# 可能是想上下拖动棋盘；松手时没拖过阈值再补发这次点击。
			# ⚠️ R123 这里还要求「点在空格 / 无选中 / 未上膛」，而可视窗内几乎每一处
			# 都落在某一格上（_cell_at 恒不为 null）→ 左键拖动实际从未接上。
			_grid_drag_arm = _press_idx < 0 and _grid_scrollable() \
					and _cell_in_view(event.position)
			_grid_dragging = false
			_grid_drag_pos = event.position
			if _press_idx < 0 and not _grid_drag_arm:
				_on_left_click(event.position)
		else:
			# 松手：拖拽中 → 落点结算；否则按点击处理
			if _drag_idx >= 0:
				_finish_drag(event.position)
			elif _press_idx >= 0:
				_on_left_click(event.position)
			elif _grid_drag_arm and not _grid_dragging:
				_on_left_click(event.position)   # 没拖动 → 还是原来那下点击
			_grid_drag_arm = false
			_grid_dragging = false
			_press_idx = -1
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		# R123：中键按下 = 直接进入棋盘拖动（不用管点在空格还是单位上）
		_grid_drag_arm = event.pressed and _cell_in_view(event.position)
		_grid_dragging = false
		_grid_drag_pos = event.position
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP
					or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		# 地图总览（R128）：5×7 格子整屏装得下 → 不再滚动，滚轮在此吞掉
		if _map_visible:
			return
		# R155：区域浏览面板（卡组/消耗/效果区）开着 → 滚轮翻页
		# （弃牌区 R301 起走全屏浏览窗，滚轮由 PickOverlay 自己处理）
		if _effects_visible or _enemy_effects_visible \
				or _deck_visible or _run_deck_visible or _void_visible:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zone_page = maxi(0, _zone_page - 1)
			else:
				_zone_page += 1   # 上限在绘制处钳
			queue_redraw()
			return
		# 道具浏览面板：内容放不下时用滚轮翻动
		if _relics_visible:
			_relic_scroll += -34.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 34.0
			queue_redraw()
			return
		# R123：棋盘可视窗内容超高 → 滚轮上下滚动
		if _grid_scrollable() and _cell_in_view(event.position):
			_cam_cancel()   # R288：玩家要自己滚 → 交还镜头
			_grid_scroll = clampf(_grid_scroll
					+ (-GRID_SCROLL_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP
							else GRID_SCROLL_STEP), _grid_scroll_min(), _grid_scroll_max())
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click()
		queue_redraw()
	elif event is InputEventMouseMotion:
		# R123：棋盘拖动滚动（空格左键 / 中键，拖过阈值生效；向上拖 = 内容上移）
		if _grid_drag_arm and _drag_idx < 0:
			if not _grid_dragging and event.position.distance_to(_grid_drag_pos) > DRAG_THRESHOLD:
				_grid_dragging = true
			if _grid_dragging:
				_cam_cancel()   # R288：玩家拖棋盘 → 交还镜头
				_grid_scroll = clampf(
						_grid_scroll - (event.position.y - _grid_drag_pos.y),
						_grid_scroll_min(), _grid_scroll_max())
				_grid_drag_pos = event.position
				queue_redraw()
				return
		if _press_idx >= 0 and _drag_idx < 0 \
				and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_start_drag(_press_idx, event.position)
		if _drag_idx >= 0:
			_drag_pos = event.position
			queue_redraw()
		_on_hover(event.position)


func _hand_index_at(pos: Vector2) -> int:
	## 手牌会互相重叠 → 从**最上层**（画得最晚的那张）往前找。
	for i in range(engine.state.hand.size() - 1, -1, -1):
		if _hand_hit(i, pos):
			return i
	return -1


func _unhandled_key_input(event: InputEvent) -> void:
	## 键盘快捷键：Esc 主菜单（R148 改，原来是「取消选中」）/ E 结束回合 / M 地图 /
	## L 记录面板 / F 主动发动。
	if engine == null or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	# 菜单开着时屏蔽其余快捷键。正常路径上 `paused` 已经替我们挡住了（菜单打开会暂停
	# 场景树，PAUSABLE 的节点收不到输入），这里是**演示模式（不暂停）**的双保险。
	if _menu != null and _menu.is_open() and k.keycode != KEY_ESCAPE:
		return
	match k.keycode:
		KEY_ESCAPE:
			# R301：全屏选卡页 / 弃牌浏览窗开着 → Esc 先关它。
			# 正常情况下 PickOverlay 自己的 `_unhandled_key_input` 已经吃掉这个键；
			# 这里只是**兜底**：万一节点顺序让战斗场景先收到，也不能在窗上直接弹主菜单。
			if _pick != null and _pick.is_picking():
				if _pick.visible:
					_pick.collapse()
				return
			# R148：Esc = 主菜单。层级仍是「先关更上层的浮层」：菜单自己 → 地图总览 →
			# 才轮到开菜单。⚠️ 原来这里做的是「取消选中」，那一支交给右键
			# （`_on_right_click` / 再点一次，两个口子都还在）。
			if _menu != null and _menu.is_open():
				_menu.close()
				return
			if _map_visible:
				_map_visible = false
				queue_redraw()
				return
			# R197：敌方效果开场弹窗也是一层浮层 → Esc 先关它再轮到区域面板
			if _ee_popup:
				_ee_popup = false
				queue_redraw()
				return
			# R155：区域浏览面板（卡组/消耗/效果/道具）也是一层浮层 → 先关它再轮到自己开菜单
			if _effects_visible or _enemy_effects_visible or _relics_visible \
					or _deck_visible or _run_deck_visible or _void_visible:
				_close_zone_panels()
				queue_redraw()
				return
			if _menu != null:
				_menu.open()
			return
		KEY_E:
			_on_end_turn()
			queue_redraw()
		KEY_M:
			_toggle_map()
		KEY_L:
			_toggle_log()
		KEY_F:
			# 主动发动（熊 8004「回春」）：选中它之后按 F
			if selection != null and selection[0] == "board":
				var fc: Vector2i = selection[1]
				if engine.can_activate(fc, GameEngine.SIDE_SELF):
					engine.activate(fc, GameEngine.SIDE_SELF)
					_clear_selection()
			queue_redraw()


func _hand_cue_rect(i: int) -> Rect2:
	## 引导框用的手牌矩形：卡底沉出窗口时只圈**看得见的部分**（否则框线被裁掉一半）。
	var r := _hand_rect(i)
	return Rect2(r.position, Vector2(r.size.x, minf(r.size.y, WINDOW_H - r.position.y)))


func _hand_step(count: int) -> float:
	## 相邻手牌的横向步进：手牌少时不重叠，多了逐步压到最小步进（重叠最多 55%）。
	if count <= 1:
		return HAND_CARD_W
	return clampf(HAND_FAN_WIDTH / float(count - 1),
			HAND_CARD_W * HAND_FAN_MIN_STEP, HAND_CARD_W)


func _hand_fan_k(i: int) -> float:
	## 第 i 张相对扇心的偏移：-1 = 最左，0 = 中间，+1 = 最右。
	var n := engine.state.hand.size()
	if n <= 1:
		return 0.0
	return (float(i) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)


func _hand_angle(i: int) -> float:
	## 第 i 张的旋转弧度（绕卡牌底部中心）：左负右正，两端不超过 ±HAND_FAN_MAX_DEG。
	var n := engine.state.hand.size()
	if n <= 1:
		return 0.0
	var span := minf(HAND_FAN_MAX_DEG * 2.0, HAND_FAN_DEG_PER * float(n - 1))
	return deg_to_rad(span / 2.0 * _hand_fan_k(i))


func _hand_drop(i: int) -> float:
	## 扇弧：越靠两边越往下沉（两端相对扇心下沉 HAND_FAN_DROP，一起沉进窗口下沿）。
	return HAND_FAN_DROP * _hand_fan_k(i) * _hand_fan_k(i)


func _hand_vis_h(i: int) -> float:
	## 第 i 张**露在屏幕内**的高度（**不含**悬停/选中的视觉抬手）——仅测试断言用，
	## 用来确认「卡沉下去之后还剩多少是看得见的」。卡面绘制**不用**它（整张排版后由视口裁）。
	return WINDOW_H - (OWN_HAND_Y + _hand_drop(i))


func _hand_rect(i: int) -> Rect2:
	## 手牌第 i 张的**未旋转**矩形；命中判定 / 拖拽起点 / 引导框都基于它。
	## 卡底会落在窗口下沿之外（HAND_CROP_BOTTOM）：卡面照整张排版画，多出的那截由视口裁掉。
	var n := engine.state.hand.size()
	var step := _hand_step(n)
	var total: float = step * (n - 1) + HAND_CARD_W
	var x: float = (WINDOW_W - total) / 2 + step * i
	var raised := HAND_SELECT_RAISE \
			if selection != null and selection[0] == "hand" and selection[1] == i else 0.0
	return Rect2(x, OWN_HAND_Y - raised + _hand_drop(i), HAND_CARD_W, HAND_CARD_H)


func _hand_pivot(i: int) -> Vector2:
	## 旋转轴心 = 卡牌底部中心（扇形就是绕这里张开的）。
	## 手牌卡底正好落在窗口下沿，所以轴心几乎贴着屏幕边缘 → 扇形的圆心也在那里。
	var r := _hand_rect(i)
	return Vector2(r.position.x + HAND_CARD_W / 2, r.position.y + HAND_CARD_H)


func _hand_hit(i: int, pos: Vector2) -> bool:
	## 精确命中：把鼠标点**反向旋转**回卡牌本地坐标再判矩形。
	## （卡是转着画的，直接拿轴对齐矩形判会在两端错位；这里用同一条 _hand_angle。）
	## 注意：悬停抬手只影响绘制、不进 _hand_rect，所以不会出现「抬起→不再命中→闪」。
	var pivot := _hand_pivot(i)
	var local := pivot + (pos - pivot).rotated(-_hand_angle(i))
	return Rect2(_hand_rect(i).position, Vector2(HAND_CARD_W, HAND_CARD_H)).has_point(local)


## ⚠️ R146：这两个是 **static** —— `intro_pose()` 要当纯函数被回归直接调用
##   （static 也能从实例方法里照常 `_grid_scroll_min()` 调用）。
static func _grid_scroll_min() -> float:
	## R139：边框贴着 3×6 战场本体之后，滚动范围要把**上边框带**也算进来 ——
	## 滚到最上时外框上沿正好落在可视窗上沿（顶带 + 上面两只角花能看全）。
	return -GRID_FRAME_BAND_T


static func _grid_scroll_max() -> float:
	## R123：可滚动的最大距离（内容总高 - 可视窗高）。
	## ⚠️ R139：左端要多留一个**下边框带**，滚到底时外框下沿正好落在可视窗下沿。
	return maxf(_grid_scroll_min(), GRID_CONTENT_H + GRID_FRAME_BAND_B - GRID_H)


func _grid_scrollable() -> bool:
	## R139：内容 + 边框超出可视窗 → 有得滚（原先到处都是 `_grid_scroll_max() > 0.0`）。
	return _grid_scroll_max() - _grid_scroll_min() > 0.5


static func intro_pose(t: float) -> Dictionary:
	## R146：开场巡场在 t 秒时的**位置 + 缩放** —— 时间轴的唯一来源（纯函数，回归直接钉它）。
	## 四段：停自己半场 → 推到对方半场（同时放大）→ 停对方半场 → **拖回我方 + 还原大小**。
	## 返回 {"scroll": float, "zoom": float}。
	## ⚠️ 终点（t = GRID_INTRO_DUR）必须落在 `_grid_scroll_max()` + 缩放 1.0：
	##    巡场结束后玩家就在自己这半场出牌，镜头绝不能停在对方那边、更不能停在放大态。
	var pan := GRID_INTRO_DUR - GRID_INTRO_HOLD0 - GRID_INTRO_HOLD1 - GRID_INTRO_BACK
	if t < GRID_INTRO_HOLD0:
		return {"scroll": _grid_scroll_max(), "zoom": 1.0}
	if t < GRID_INTRO_HOLD0 + pan:
		var e := _intro_ease((t - GRID_INTRO_HOLD0) / pan)
		return {"scroll": lerpf(_grid_scroll_max(), _grid_scroll_min(), e),
				"zoom": lerpf(1.0, GRID_INTRO_ZOOM, e)}
	if t < GRID_INTRO_HOLD0 + pan + GRID_INTRO_HOLD1:
		return {"scroll": _grid_scroll_min(), "zoom": GRID_INTRO_ZOOM}
	var e2 := _intro_ease((t - GRID_INTRO_HOLD0 - pan - GRID_INTRO_HOLD1) / GRID_INTRO_BACK)
	return {"scroll": lerpf(_grid_scroll_min(), _grid_scroll_max(), e2),
			"zoom": lerpf(GRID_INTRO_ZOOM, 1.0, e2)}


static func _intro_ease(u: float) -> float:
	## smoothstep：两头慢、中间快（两段平移共用同一条缓动，别各写一份）。
	var p := clampf(u, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)


func _grid_intro_tick(delta: float) -> void:
	## R136/R146：开场巡场的推进 —— 只把 `intro_pose()` 的结果写进
	## `_grid_scroll` / `_grid_zoom`，自己不掺任何时间逻辑。
	## 目的：让玩家第一眼就知道战场是 3×6，再回到自己半场准备出牌。玩家一动就停。
	if _grid_intro_t < 0.0:
		return
	_grid_intro_t += delta
	if _grid_intro_t >= GRID_INTRO_DUR:
		_grid_intro_t = -1.0
		var end := intro_pose(GRID_INTRO_DUR)
		_grid_scroll = end["scroll"]
		_grid_zoom = end["zoom"]
		_maybe_open_enemy_effect_popup()   # R197：巡场完整播完 → 弹敌方效果
		queue_redraw()
		return
	var pose := intro_pose(_grid_intro_t)
	_grid_scroll = pose["scroll"]
	_grid_zoom = pose["zoom"]
	queue_redraw()


static func _board_zoom_center() -> Vector2:
	## R146：放大**绕棋盘可视窗中心**（窗在屏幕上不动，只有内容放大）——
	## 于是 transform 的偏移 = 中心 × (1 - 缩放)。
	return Vector2(GRID_X + GRID_W / 2.0, GRID_Y + GRID_H / 2.0)


func _begin_board_transform(shake: Vector2) -> void:
	## R146：棋盘区（含边框）**唯一的绘制入口变换** —— 震动 + 开场缩放叠在一条 transform 上。
	## ⚠️ `draw_set_transform` 是 CanvasItem 的共享状态：画完棋盘区必须复位。
	var z := _grid_zoom
	var c := _board_zoom_center()
	draw_set_transform(shake + c * (1.0 - z), 0.0, Vector2(z, z))


func _grid_intro_stop() -> void:
	## R136：巡场只是提示 —— 玩家一按鼠标（点击 / 滚轮 / 拖动）就立刻停在当前位置，
	## 既不吞掉这次操作，也不会让棋盘继续在指针底下滑走。
	## ⚠️ R146：缩放必须**当场归位**（不能停在半路）—— 命中判定不认识缩放，
	##    留着 1.15 会让「看到的那一格」和「点中的那一格」整体错开。
	if _grid_intro_t >= 0.0:
		_grid_intro_t = -1.0
		_grid_scroll = clampf(_grid_scroll, _grid_scroll_min(), _grid_scroll_max())
		_grid_zoom = 1.0


func _cell_in_view(pos: Vector2) -> bool:
	## 这一点是否落在棋盘**可视窗**里（滚动手势与格子命中只认窗内）。
	return Rect2(GRID_X, GRID_Y, GRID_W, GRID_H).has_point(pos)


func _cell_at(pos: Vector2) -> Variant:
	var c := int(floor((pos.x - GRID_X) / CELL_W))
	var r := int(floor((pos.y - GRID_Y + _grid_scroll) / CELL))
	if r >= 0 and r < FieldState.BOARD_ROWS and c >= 0 and c < FieldState.BOARD_COLS \
			and _cell_in_view(pos):
		return Vector2i(r, c)
	return null


func _on_left_click(pos: Vector2) -> void:
	# R288：玩家一动手就交还镜头（滚轮 / 拖棋盘已有，点击这条别漏 ——
	# 否则演到一半点张牌，棋盘还停在敌方半场，自己出的牌在哪都看不见）。
	_cam_cancel()
	# R302：触屏没有 hover —— 点「提及」那两个字 = 钉住说明（再点别处收起）。
	for h: Dictionary in _mention_hits:
		if (h["rect"] as Rect2).has_point(pos):
			_mention_pin = h
			_hover_mention = {}
			queue_redraw()
			return
	if not _mention_pin.is_empty():
		_mention_pin = {}
		queue_redraw()
	# R294：**点击 = 「指针确实在这里」**，顺手按落点把悬停状态刷一次。
	# 悬停只在 MouseMotion 里更新，却是左栏描述的**最高优先级**来源 →
	# 出牌后手牌左移、或触屏（根本没有 motion 事件）时，缓存会停在旧卡上，
	# 玩家点了别的卡，左栏描述却一动不动（用户报告）。放在最前面：
	# 后面各分支自己的 `_say()` / status_text 仍会覆盖掉悬停写的那句提示。
	_on_hover(pos)
	# R197：敌方效果开场弹窗开着 → 本次点击只关弹窗，不落进战场
	if _ee_popup:
		_ee_popup = false
		queue_redraw()
		return
	# R189：全屏选卡页接管 8 套旧面板。展开时点击被子节点吃掉、根本到不了这里；
	# 收起态（返回看战场）点「继续选择」浮条回来，点其他地方只提示 —— pending
	# 还在引擎里，不能让玩家绕过选择直接打牌。
	if _pick != null and _pick.is_picking():
		if not _pick.visible and _pick_banner_rect().has_point(pos):
			_pick.reopen()
			queue_redraw()
		elif not _pick.visible:
			_say("选择进行中：点顶部「继续选择」回到选卡页")
		return
	# 预判（9097）：二选一面板（选的是模式不是卡，不进选卡页）
	if engine.foresight_mode:
		_on_foresight_mode_click(pos)
		return
	# 浏览面板：开着时点任意处关闭
	if _map_visible:
		# 地图总览：纯只读，点任意处关闭（不能在这里改路线）
		_map_visible = false
		queue_redraw()
		return
	if _effects_visible or _enemy_effects_visible or _relics_visible\
			or _deck_visible or _run_deck_visible or _void_visible:
		# R155：‹ › 翻页 / 右上「×」/ 点面板**外**才关闭 —— 旧版「点任意处关闭」
		# 让面板内的点击（想看另一页、想细看）都变成了关面板，太毛躁。
		if _zone_prev_page_rect().has_point(pos):
			_zone_page = maxi(0, _zone_page - 1)
			queue_redraw()
			return
		if _zone_next_page_rect().has_point(pos):
			_zone_page += 1   # 上限在绘制处钳（页数随卡数变）
			queue_redraw()
			return
		if _zone_close_rect().has_point(pos) or not _zone_panel_rect().has_point(pos):
			_close_zone_panels()
			queue_redraw()
		return
	# 效果区：点击查看全部效果卡（持续生效中）
	var effects_rect := _own_effect_zone_rect()
	if effects_rect.has_point(pos) and not engine.state.effects.is_empty():
		_pass_moved_pending()
		_effects_visible = true
		queue_redraw()
		return
	# 敌方效果区：点击查看敌方效果卡（开局启用，持续生效中）
	if _enemy_zone_rect().has_point(pos) and not engine.state.enemy_effects.is_empty():
		_pass_moved_pending()
		_enemy_effects_visible = true
		queue_redraw()
		return
	# 道具栏：悬浮已能逐个看描述；**只有装不下（栏里出现「+N」摘要）时**才允许点开浏览面板
	if _relic_zone_rect().has_point(pos) and _relic_bar_overflowed():
		_pass_moved_pending()
		_relics_visible = true
		_relic_scroll = 0.0
		queue_redraw()
		return
	var discard_rect := Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H)
	if discard_rect.has_point(pos) and not engine.state.discard.is_empty():
		_pass_moved_pending()
		_open_discard_view()   # R301：全屏浏览窗（与选卡页同一套排版）
		return
	# R155 消耗（消失）区：点开浏览面板 —— 本局消失的卡逐张可回看（相同卡合并 ×N）
	if Rect2(VOID_X, VOID_Y, CARD_W, CARD_H).has_point(pos) and engine.state.void_count > 0:
		_pass_moved_pending()
		_close_zone_panels()
		_void_visible = true
		queue_redraw()
		return
	# 卡组（抽牌堆）：点开浏览 —— 相同卡合并显示张数，不泄露抽牌顺序
	# R207：这里 = **现有卡组**（本场还没抽到的牌），顶栏按钮才是完整卡组 → 先关干净再开
	var deck_rect := Rect2(DECK_X, DECK_Y, CARD_W, CARD_H)
	if deck_rect.has_point(pos) and not engine.state.deck.is_empty():
		_pass_moved_pending()
		_close_zone_panels()
		_deck_visible = true
		queue_redraw()
		return
	# 手牌：必须和悬停/拖拽用同一套判定（卡是转着画的、还会互相重叠），
	# 否则会出现「悬停显示 A、点下去选中 B」。
	var hi := _hand_index_at(pos)
	if hi >= 0:
		# R71：同样只允许我方回合出牌（与 _on_board_click 的门禁成对；否则玩家能在敌方
		# 回合抢先出牌 → `_ai_step` 随后驱动的 AI 队列与实际战场状态对不上）。
		if engine.current_side != GameEngine.SIDE_SELF:
			_say("现在是敌方回合，等对手行动完再出牌")
			return
		_pass_moved_pending()  # 切去选手牌 = 放弃已移动单位的攻击
		# R209：手牌点击**不再**承担「再点一张 = 选目标」的第二段 —— 系统升级 / 回收 /
		# 填充三种手牌目标卡都在弹出选卡页后就由 `_pick` 接管，这里只剩「再点一次 = 使用」。
		if selection != null and selection[0] == "hand" and selection[1] == hi:
			_use_hand_card(hi)  # 再点一次 = 使用
		else:
			_clear_selection()
			selection = ["hand", hi]
			var card := engine.state.hand[hi]
			if card.is_curse():
				# R239：带「次元」的诅咒（破绽 9154）打出后消失，提示里说清楚
				var curse_gone: String = "，打出后消失" \
						if card.has_affix(GameEngine.AFFIX_DIMENSION) else ""
				status_text = "%s（诅咒）：再点一次打出（无效果%s）" % [card.card_name, curse_gone]
			elif card.is_effect():
				status_text = "%s（效果卡）：再点一次启用，放入左侧效果区持续生效" % card.card_name
			elif card.is_spell() and card.needs_target():
				status_text = "%s（技能）：再点一次使用，需点击一个目标" % card.card_name
			elif card.is_spell() and card.x_cost:
				# R124：0 能量也能用（X 记 0）—— 这时别再说「消耗 0 点」，
				# 直接讲清「这一下砸不出流星」，玩家自己决定要不要空放。
				if engine.energy_of() > 0:
					status_text = "%s（技能）：再点一次使用 —— 消耗当前全部能量 %d 点，随机砸 %d 次" % [
							card.card_name, engine.energy_of(), engine.energy_of()]
				else:
					status_text = "%s（技能）：再点一次使用 —— 当前没有能量，X 记 0（砸不出流星）" % card.card_name
			elif card.is_spell():
				status_text = "%s（技能）：再点一次使用" % card.card_name
			elif engine.discard_cost_of(card) > 0:
				status_text = "%s：点击自己半场（下 3 行）空格放置 —— 上场需额外丢弃 %d 张手牌" \
						% [card.card_name, engine.discard_cost_of(card)]
			elif not card.is_spell() and not engine.can_pay_card(card):
				_energy_fail(card, hi)   # R151 P2-15：提示 + 抖动 + 能量框红闪
			elif engine.fence_merge_allowed(card):
				status_text = "%s：点绿格放置；点橙色「叠」格 = 与已有栅栏合并；再点一次 = 使用" % card.card_name
			else:
				status_text = "%s：点击自己半场（下 3 行）空格放置；再点一次 = 使用" % card.card_name
		return
	# 棋盘格
	var cell = _cell_at(pos)
	if cell != null:
		_on_board_click(cell)


func _use_hand_card(i: int) -> void:
	var card := engine.state.hand[i]
	if card.is_curse():
		# R223：诅咒卡（「疲惫」9149）—— 唯一打出入口 use_curse（付能量、无效果；
		# 打完之后去哪由引擎 `_spell_card_gone` 定：带「次元」的破绽 9154 消失，其余进弃牌区）。
		# 必须拦在随从 / 技能分支**之前**：诅咒既不是单位也不是技能，掉进任一条都会被拒。
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
		else:
			engine.use_curse(i)
			_net_send({"type": "action", "act": "curse", "card": card.to_dict()})
		_clear_selection()
		queue_redraw()
		return
	if card.is_effect():
		# 效果卡：支付能量 → 进入左侧效果区持续生效
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
		else:
			engine.use_effect(i)
			_net_send({"type": "action", "act": "effect", "card": card.to_dict()})
		_clear_selection()
		queue_redraw()
		return
	if not card.is_spell():
		return  # 随从/工事：等待点击棋盘格放置
	if not engine.can_pay_card(card):
		_energy_fail(card, i)   # R151 P2-15
		_clear_selection()
		return
	if not engine.can_use_card(card):
		_say("%s：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				card.card_name, GameEngine.WHIRL_BLADE_NEED, engine.state.self_card_plays])
		_clear_selection()
		return
	# 「系统升级」（8039，R209）：目标在**手牌**里，所以**不进 spell_targets**
	# （那套是棋盘格）。与「填充」统一 —— 只记下标，`_sync_pick()` 下一帧弹**全屏选卡页**。
	# R269：轻量化（8068）与系统升级（8039）共用这一条「手牌目标」流，
	# 文案与候选范围按**是哪张卡**区分（`_sysup_word` / `_sysup_options`）。
	if card.id == GameEngine.SYS_UPGRADE_ID or card.id == GameEngine.HAND_LIGHTEN_ID:
		var su_word := _sysup_word(card)
		if _sysup_options(i).is_empty():
			_say("%s：手牌里没有可改造的%s（%s 仍在手牌）" % [
					card.card_name, su_word, card.card_name])
			_clear_selection()
			return
		_sys_upgrade_idx = i
		status_text = "%s：在弹出的选卡页里点一张%s" % [card.card_name, su_word]
		return
	# 「回收」（8064，R209）：目标在手牌里且**不限种类**，同样走选卡页。
	if card.id == GameEngine.RECYCLE_ID:
		if _recycle_options(i).is_empty():
			_say("回收：手牌里没有可回收的卡（回收仍在手牌）")
			_clear_selection()
			return
		_recycle_idx = i
		status_text = "回收：在弹出的选卡页里点一张手牌"
		return
	# 「填充」（9146，R202 / R205）：目标在**手牌**里且不限种类。
	# 最早就是选卡页（R205 从点击式改过来），R209 让系统升级 / 回收照同一套路走。
	#   `_reload_idx` 一置，`_sync_pick()` 下一帧自动 open；选完点「确认填充」才结算。
	if card.id == GameEngine.RELOAD_ID:
		if _reload_options(i).is_empty():
			_say("填充：手牌里没有可改变的卡（填充仍在手牌）")
			_clear_selection()
			return
		_reload_idx = i
		status_text = "填充：在弹出的选卡页里点一张手牌"
		return
	if card.needs_target():
		# 需要选目标的技能：进入选目标模式（技能还在手牌，能量未付）
		var targets := _spell_target_cells(card)
		if targets.is_empty():
			if card.id in [8002, 9003]:
				engine.use_spell(i)  # 没有单位可打：伤害直接结算给对方玩家
				_net_send({"type": "action", "act": "spell",
						"card": card.to_dict(), "target": null})
			else:
				_say("没有可指定的目标")
			_clear_selection()
		else:
			spell_pending = i
			spell_targets = targets
			var target_hint := "一个格子" if card.id == GameEngine.FIREBALL_ID else "一个目标"
			if card.id == GameEngine.FIRE_WALL_SPELL_ID:
				target_hint = "一条横行（不分敌我；点该行任意一格）"
			elif card.id == GameEngine.INFILTRATE_ID:
				target_hint = "一个自己的盟友（之后再点目的格）"
			elif card.id == GameEngine.SWAP_UNITS_ID:
				target_hint = "第一个单位（之后再点第二个单位）"
			elif card.id == GameEngine.SHADOW_STRIKE_ID:
				target_hint = "**一个目标**（8 伤；本回合含这张卡已用 3 张 → 回 1 费）"
			elif card.id == GameEngine.SHADOW_STEP_ID:
				target_hint = "**一个目标**（8 伤；之后从弃牌区任选一张卡回手）"
			elif card.id == GameEngine.UPGRADE_ID:
				target_hint = "**自己的一个盟友或工事**（+2 攻 / +8 血）"
			elif card.id == GameEngine.MERGE_ID:
				target_hint = "**自己的一个盟友或工事**（之后从卡组选一张素体）"
			elif card.id == GameEngine.ARMOR_PLATE_ID:
				target_hint = "**自己的一个盟友**（生命 +4，算一层改造）"
			elif card.id == GameEngine.DEMOLISH_ID:
				target_hint = "**自己的一个盟友或工事**：破坏它、回 3 费、手牌+素体；被改造则额外+升级"
			elif card.id == GameEngine.REORG_ID:
				target_hint = "**自己的一个盟友或工事**：回复至满生命"
			elif card.id == GameEngine.TRANSCEND_ID:
				target_hint = "**自己的一个盟友或工事**（还没超负荷）：挂上超负荷 + 算一层改造"
			elif card.id == GameEngine.REBOOT_ID:
				target_hint = "**自己的一个盟友或工事**：返回手卡（0 费，离手重置）"
			elif card.id == GameEngine.BLADE_GIFT_ID:
				target_hint = "**自己的一个盟友**（改造：力 +%d，并获得「死亡」）" \
						% GameEngine.BLADE_ATK
			elif card.id == GameEngine.DUPLICATE_ID:
				target_hint = "**自己的一个盟友或工事**：复制 %d 张带「次元」的副本到手卡（本回合 0 费）" \
						% GameEngine.DUPLICATE_COUNT
			elif card.id == GameEngine.BREAKTHROUGH_ID:
				target_hint = "**一个敌人**（%d 伤；场上己方每层改造再 +%d）" % [
						GameEngine.BREAKTHROUGH_DMG, GameEngine.BREAKTHROUGH_PER_STACK]
			elif card.id == GameEngine.IMPACT_CANNON_ID:
				target_hint = "**一个敌人**（%d 伤，并击退 %d 格）" % [
						GameEngine.IMPACT_CANNON_DMG, GameEngine.IMPACT_CANNON_STEPS]
			elif card.id == GameEngine.WHIRL_BLADE_ID:
				target_hint = "十字中心格"
			status_text = "%s：点击%s（右键取消）" % [card.card_name, target_hint]
	else:
		engine.use_spell(i)
		_net_send({"type": "action", "act": "spell",
				"card": card.to_dict(), "target": null})
		_clear_selection()
	queue_redraw()


# ------------------------------------------------------------ 拖拽释放

func _start_drag(i: int, pos: Vector2) -> void:
	## 开始拖拽一张手牌：诅咒/技能/效果卡拖到棋盘释放；随从/工事拖到自己半场空格放置。
	var card := engine.state.hand[i]
	_pass_moved_pending()   # 拖拽 = 放弃已移动单位的攻击
	_clear_selection()
	_drag_idx = i
	_drag_pos = pos
	_drag_place = false
	_drag_place_cells = []
	_drag_to_effects = false
	if card.is_curse():
		# R223：诅咒卡（「疲惫」9149）—— 拖到棋盘任意处松手即打出（无效果）。
		# 必须拦在随从分支**之前**：诅咒不是单位，掉进去会被当随从摆上场。
		_drag_spell_cells = []
		_drag_anywhere = true
		if not engine.can_pay_card(card):
			status_text = "%s：能量不足（需要 %d，当前 %d）——松手不会生效" % [
					card.card_name, engine.cost_of(card), engine.energy_of()]
		else:
			status_text = "%s：拖到棋盘任意处打出（无效果）" % card.card_name
		queue_redraw()
		return
	if not card.is_spell() and not card.is_effect():
		# 随从 / 工事：拖到自己半场（下 3 行）的空格放置；
		# 持「栅栏修复术」且手里是栅栏 → 已有栅栏的格子也可落（叠栅栏，橙色）
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = true
		_drag_place_cells = _own_place_cells(card)
		if not engine.can_pay_card(card):
			status_text = "%s：能量不足（需要 %d，当前 %d）——松手不会生效" % [
					card.card_name, engine.cost_of(card), engine.energy_of()]
		elif card.is_field():
			status_text = "%s：拖到高亮格放置（可落在已有单位上）" % card.card_name
		elif engine.fence_merge_allowed(card):
			status_text = "%s：拖到绿色格子放置；拖到橙色「叠」格 = 与已有栅栏合并" % card.card_name
		elif card.has_affix(GameEngine.AFFIX_SWAP):
			status_text = "%s：拖到绿色空格放置；也可拖到己方单位上 → 把它顶回手" % card.card_name
		else:
			status_text = "%s：拖到绿色格子放置（自己半场空格）" % card.card_name
		queue_redraw()
		return
	if card.id == GameEngine.INFILTRATE_ID:
		# R76：潜入是**两段式**技能，拖拽也必须走两段（原来拖拽直接落到 use_spell 的
		# 单段分支，引擎自己挑「第一个空格」= 前排左边，看起来就是卡片自己跑掉了）。
		# 第一段：拖到己方盟友上 → 只记下它，高亮所有可去的空格，等第二次点/拖。
		_drag_spell_cells = _spell_target_cells(card)
		_drag_anywhere = false
		if _drag_spell_cells.is_empty():
			status_text = "潜入：场上没有可移动的己方盟友（已取消）"
			_drag_spell_cells = []
		else:
			status_text = "潜入：拖到一个己方盟友上（第二段再拖到目的格）"
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID:
		# R102：双向传送同样是**两段式**，拖拽也必须走两段（否则会掉进 use_spell
		# 的单段分支被引擎拒绝，或者自动挑一对自动交换掉）。
		_drag_spell_cells = _spell_target_cells(card)
		_drag_anywhere = false
		if _drag_spell_cells.size() < 2:
			status_text = "双向传送：场上不足两个单位（已取消）"
			_drag_spell_cells = []
		else:
			status_text = "双向传送：拖到第一个单位上（第二段再拖到另一个单位）"
		queue_redraw()
		return
	if _hand_target_pick_kind(card) != "":
		# R213：目标在**手牌**里的技能（系统升级 8039 / 回收 8064 / 填充 9146）—— 拖拽也能发动。
		# 用户口径「填充当前不能拖拽使用，检查此类卡片是否可以拖拽到战场中发动」：
		# R198 / R202 当年把这几张的拖拽显式关掉（`_drag_anywhere = false`），理由是怕松手
		# 落进 `use_spell` 分支被引擎拒、联机还会白发一条 spell。现在改成「拖到棋盘任意处
		# 松手 → 与点击**同一个入口** `_use_hand_card()`」：只记下标、下一帧弹选卡页，
		# **不调 use_spell、不发联机消息、不扣费**（扣费发生在选卡页确认时）。
		# `_drag_anywhere` 在这里只表示「这块区域能松手」，分流在 `_finish_drag` 里按 kind 做。
		_drag_spell_cells = []
		_drag_anywhere = true
		status_text = "%s：拖到棋盘任意处松手 → 弹出选卡页" % card.card_name
		queue_redraw()
		return
	if card.is_spell() and card.needs_target():
		_drag_spell_cells = _spell_target_cells(card)
		# 目标格为空但可直击对方玩家的技能（攻击/火焰箭）：拖到棋盘任意处释放
		_drag_anywhere = _drag_spell_cells.is_empty() and card.id in [8002, 9003]
	else:
		_drag_spell_cells = []
		_drag_anywhere = true   # 无目标技能 / 效果卡：拖到棋盘任意处生效
	# R106：效果卡除了拖到棋盘，还能**直接拖到左侧效果区**上松手启用（那是它的「家」）。
	_drag_to_effects = card.is_effect()
	if card.is_effect():
		status_text = "%s：拖到左侧效果区（或棋盘任意处）启用" % card.card_name
	elif not _drag_spell_cells.is_empty():
		status_text = "%s：拖到高亮目标上释放" % card.card_name
	else:
		status_text = "%s：拖到棋盘上释放" % card.card_name
	queue_redraw()


func _own_place_cells(card: CardData) -> Array[Vector2i]:
	## 合法放置格。
	## 场地卡（R74）：**不要求格子空着** —— 已有场地会被顶掉、已有单位也允许
	## （场地不是单位，两套数据互不影响）。
	## 能放哪些格由**这张场地的生效对象**决定（R78）：
	##   * 陷阱（等敌人踩）→ 我方后排禁放（敌人永远进不去）；敌方半场 0..4 全允许。
	##   * 只对己方生效 → 敌方后排禁放（我们自己进不去）。
	##   * 对双方生效 → 全场无限制。
	## 判据是「目标方能不能走到这一格」，不是「后排」这个位置本身。
	if card.is_field():
		return _field_place_cells(card)
	## 普通随从/工事：自己半场（下 3 行）的空格 + 可合并的己方栅栏格
	## （持「栅栏修复术」且手里是栅栏卡时，栅栏可以打在已有栅栏上）。
	## 带「交换」字段的卡（R101，救援构装体）：还能打在**已有己方单位**的格子上
	## （原单位被顶回手、新卡占据该格；引擎 play_from_hand 里的交换分支负责顶回手）。
	var out: Array[Vector2i] = []
	# R286：手牌放置读引擎唯一口 `hand_place_allowed`（自己半场）—— 界面上
	# 「能放哪」与引擎「实际放不放」同一个真相；R285 曾误放宽成只禁对方后排。
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not GameEngine.hand_place_allowed(c, GameEngine.SIDE_SELF):
				continue
			if not engine.state.board.has(c):
				out.append(c)
			elif engine.fence_merge_target(c, card):
				out.append(c)
			elif card.has_affix(GameEngine.AFFIX_SWAP) \
					and engine.state.board[c].owner == GameEngine.SIDE_SELF:
				out.append(c)
	return out


func _field_place_cells(card: CardData) -> Array[Vector2i]:
	## 场地卡的合法格：按**这张卡的生效对象**逐格问引擎（field_place_allowed）。
	## 刻意**不**自己算禁行 —— R78 之前界面算一遍 ban 行、引擎也算一遍，
	## 两边万一不同步极难查。委托唯一口就只有一个真相。
	## card 传 null 时引擎按「敌」处理（陷阱默认口径）。
	var aim := GameEngine.field_aim(card)
	var out: Array[Vector2i] = []
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if GameEngine.field_place_allowed(c, aim):
				out.append(c)
	return out


func _fence_merge_cells(card: CardData) -> Array[Vector2i]:
	## 可「叠栅栏」的己方栅栏格（仅用于高亮提示）。
	var out: Array[Vector2i] = []
	if not engine.fence_merge_allowed(card):
		return out
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if engine.fence_merge_target(c, card):
				out.append(c)
	return out


func _finish_drag(pos: Vector2) -> void:
	## 松手：按落点结算拖拽（有效 → 释放/放置；否则取消，卡留在手牌）。
	## R71：拖拽是**独立于 `_on_board_click` 的另一条出手路径**，所以回合门禁要单独写一份
	## （只加在 `_on_board_click` 的话，敌方回合照样能拖牌上场）。
	# R77：鸭语耳环自动出牌播送中 → 拖拽也锁住（与 _on_left_click 同一条理由）。
	if engine != null and engine.earring_autoplay_active():
		_drag_idx = -1
		_press_idx = -1
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = false
		_drag_place_cells = []
		_drag_to_effects = false
		_say("鸭语耳环正在自动出牌，等它出完（%d 张）" % engine.earring_played)
		return
	if engine == null or engine.over or engine.current_side != GameEngine.SIDE_SELF:
		_drag_idx = -1
		_press_idx = -1
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = false
		_drag_place_cells = []
		_drag_to_effects = false
		_say("现在是敌方回合，等对手行动完再出牌")
		return
	var i := _drag_idx
	_drag_idx = -1
	var cells := _drag_spell_cells
	var anywhere := _drag_anywhere
	var place := _drag_place
	var place_cells := _drag_place_cells
	var to_effects := _drag_to_effects
	_drag_spell_cells = []
	_drag_anywhere = false
	_drag_place = false
	_drag_place_cells = []
	_drag_to_effects = false
	var card := engine.state.hand[i]
	# R223：诅咒卡拖到棋盘上 = 打出（无效果）。必须拦在最前面：诅咒不是单位 /
	# 技能 / 效果，掉进后面任一条分支都会被当成别的东西结算。
	if card.is_curse():
		var curse_cell: Variant = _cell_at(pos)   # _cell_at 返回 Variant（空格返回 null）
		if curse_cell == null:
			_say("%s：拖到棋盘上打出（已取消）" % card.card_name)
			return
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
			return
		engine.use_curse(i)
		_net_send({"type": "action", "act": "curse", "card": card.to_dict()})
		var curse_done: String = "，本场消失" \
				if card.has_affix(GameEngine.AFFIX_DIMENSION) else ""
		status_text = "%s：已打出（无效果%s）" % [card.card_name, curse_done]
		queue_redraw()
		return
	# R106：效果卡拖到**左侧效果区**上松手 = 直接启用（与「拖到棋盘任意处」等效，
	# 但落点就是它以后待着的地方，手感更自然）。必须放在 `_cell_at(pos)` 之前 ——
	# 效果区不在棋盘格上，走那条路会被判成「无效落点」而取消。
	# R117：可用投放区从「效果区那 88px」放大到**左栏整条**（见 _effect_drop_rect）。
	if to_effects and _effect_drop_rect().has_point(pos):
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
			return
		engine.use_effect(i)
		_net_send({"type": "action", "act": "effect", "card": card.to_dict()})
		status_text = "%s：已放入效果区，持续生效" % card.card_name
		queue_redraw()
		return
	# R117：技能落点走 `_drop_cell()` —— 光标没正压在目标格上时，只要**卡牌本身**
	# 盖住了那个格就算命中（可用区域从「一个点」放大到「整张卡」）。
	var infil_drop = _drop_cell(pos, cells)
	if card.id == GameEngine.INFILTRATE_ID and cells.has(infil_drop):
		# R76 潜入第一段：拖到己方盟友 = 选定它，然后高亮所有可去的空格。
		# 这里**不结算**（卡还在手上、也没扣费），等第二段点/拖目的格才真正施放。
		_infiltrate_src = infil_drop
		_drag_spell_cells = _infiltrate_dst_cells()
		if _drag_spell_cells.is_empty():
			_clear_selection()
			_drag_idx = -1
			_say("潜入：没有可去的空格，技能仍在手牌")
			return
		spell_pending = i
		spell_targets = _drag_spell_cells
		_drag_idx = -1
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x >= 0 \
			and infil_drop != null and cells.has(infil_drop) \
			and infil_drop != _swap_src:
		# R102 双向传送第二段：拖到另一个单位 = 真正交换（清选中 → 引擎两段结算）。
		var sw_a := _swap_src
		_clear_selection()
		spell_pending = -1
		spell_targets = []
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
			return
		status_text = "双向传送 → %s" % engine.cast_swap_units(i, sw_a, infil_drop)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID and cells.has(infil_drop):
		# R102 双向传送第一段：拖到任意单位 = 选定它，然后高亮其余单位。
		_swap_src = infil_drop
		_drag_spell_cells = []
		for c: Vector2i in engine.state.board:
			# R285：与点击路径同一判据 —— 非法配对不进高亮
			if c != infil_drop and engine.swap_pair_allowed(infil_drop, c):
				_drag_spell_cells.append(c)
		_drag_spell_cells.sort()
		if _drag_spell_cells.is_empty():
			_clear_selection()
			_drag_idx = -1
			_say("双向传送：没有能换的单位")
			return
		spell_pending = i
		spell_targets = _drag_spell_cells
		_drag_idx = -1
		queue_redraw()
		return
	if place:
		# 随从/工事：落到自己半场空格 = 上场
		var drop = _cell_at(pos)
		if drop != null and place_cells.has(drop):
			if not engine.can_pay_card(card):
				_energy_fail(card, i)   # R151 P2-15
				return
			_try_play_hand_card(i, drop, pos)   # 英雄要先付「弃 4 张」的代价；pos = 松手点（P0-4 落位起点）
		elif engine.fence_merge_allowed(card):
			_say("%s：拖到绿色空格；或拖到橙色「叠」格与已有栅栏合并（已取消）" % card.card_name)
			_reject_fx(i, "", drop)   # R151 P2-15：落点非法 → 卡回弹抖动
		else:
			_say("%s：拖到自己半场（下 3 行）的空格放置（已取消）" % card.card_name)
			_reject_fx(i, "", drop)   # R151 P2-15
		return
	var cell = _cell_at(pos)
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x >= 0 \
			and cell != null and _infiltrate_dst_cells().has(cell):
		# R76 潜入第二段：拖到空格 = 真正施放（清选中 → cast_infiltrate 两段结算）。
		var src := _infiltrate_src
		_infiltrate_src = Vector2i(-1, -1)
		spell_pending = -1
		spell_targets = []
		if not engine.can_pay_card(card):
			_clear_selection()
			_energy_fail(card, i)   # R151 P2-15
			return
		_clear_selection()
		status_text = "潜入 → %s" % engine.cast_infiltrate(i, src, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if card.is_spell():
		if not cells.is_empty():
			# 需要目标：必须落在有效目标格（目标单位/格子）上。
			# R117：这里同样走吸附（`_drop_cell`）——判定口径与 `_draw_drag` 的光圈完全同源。
			var spell_drop = _drop_cell(pos, cells)
			if spell_drop != null:
				if not engine.can_pay_card(card):
					_energy_fail(card, i)   # R151 P2-15
					return
				_cast_spell(i, spell_drop, card)
			else:
				_say("%s：拖到高亮目标上释放（已取消）" % card.card_name)
			return
		if anywhere and cell != null:
			# R213：目标在**手牌**里（系统升级 / 回收 / 填充）→ 与点击同一入口：只记下标、
			# 下一帧弹选卡页。⚠️ **绝不能**掉进下面的 use_spell —— `use_spell` 对这三张
			# 只有一句「先点手牌里的…」的拒绝文案，联机时还会白发一条 spell 给对手。
			if _hand_target_pick_kind(card) != "":
				_use_hand_card(i)
				return
			if not engine.can_pay_card(card):
				_energy_fail(card, i)   # R151 P2-15
				return
			engine.use_spell(i)
			_net_send({"type": "action", "act": "spell",
					"card": card.to_dict(), "target": null})
			return
		_say("%s：拖到棋盘上释放（已取消）" % card.card_name)
		return
	# 效果卡：拖到棋盘 = 启用
	if cell != null:
		if not engine.can_pay_card(card):
			_energy_fail(card, i)   # R151 P2-15
			return
		engine.use_effect(i)
		_net_send({"type": "action", "act": "effect", "card": card.to_dict()})
		return
	_say("%s：拖到棋盘上启用（已取消）" % card.card_name)


func _cast_spell(i: int, cell: Vector2i, card: CardData) -> void:
	## 释放指定目标的技能（点击选目标与拖拽共用）。
	# R76：潜入的两段判定都收在 _infiltrate_src 上 —— 它是「已选盟友」的**唯一标记**。
	# 为 -1 说明这是第一段（还没选盟友），此时**不能**施放，否则会掉进 use_spell 的
	# 单段分支、由引擎自己挑落点（表现为卡片自己跑到前排左边）。
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x < 0:
		_clear_selection()
		_say("潜入：先点一个己方盟友，再点目的格")
		return
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x >= 0:
		# 潜入第二段：盟友已选，这里点的是目的格
		var src := _infiltrate_src
		_clear_selection()
		status_text = "潜入 → %s" % engine.cast_infiltrate(i, src, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	# R102：双向传送的两段判定同样收在 _swap_src 上（与潜入同套路）。
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x < 0:
		_clear_selection()
		_say("双向传送：先点第一个单位，再点第二个单位")
		return
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x >= 0:
		var sw_a := _swap_src
		_clear_selection()
		status_text = "双向传送 → %s" % engine.cast_swap_units(i, sw_a, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if not engine.can_use_card(card):
		_say("%s：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				card.card_name, GameEngine.WHIRL_BLADE_NEED, engine.state.self_card_plays])
		_clear_selection()
		return
	# R298 合体（9167）：先在场上点了目标 → 只**挂起**并弹出「从卡组选素体」面板。
	# ⚠️ 这里不扣费、不吃手牌：真正的付费在面板确认之后（引擎 cast_merge / merge_pick
	#    的注释）。面板里放弃 = 什么都没发生，不会白丢 1 费 + 一张史诗牌。
	if card.id == GameEngine.MERGE_ID:
		_clear_selection()
		status_text = "合体 → %s" % engine.cast_merge(i, cell)
		queue_redraw()
		return
	_clear_selection()
	engine.use_spell(i, cell)
	_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
			"target": [cell.x, cell.y]})


# ------------------------------------------------------------ 英雄（9023）的弃牌代价

func _try_play_hand_card(i: int, cell: Vector2i, from_pos := Vector2.ZERO) -> void:
	## 手牌落到自己半场空格：普通卡直接上场；
	## 「英雄」这类有额外代价的卡 → 先弹「选择 N 张手牌丢弃」面板，由玩家自己挑。
	var card := engine.state.hand[i]
	var need := engine.discard_cost_of(card)
	if need <= 0:
		_finish_play(i, cell, from_pos)
		return
	var others: int = engine.state.hand.size() - 1
	if others < need:
		_say("%s 需要额外丢弃 %d 张手牌，手牌不足（除它以外只有 %d 张）"
				% [card.card_name, need, others])
		return
	_hero_pick_idx = i
	_hero_pick_cell = cell
	status_text = "英雄的代价：选择 %d 张手牌丢弃" % need
	queue_redraw()   # _sync_pick 会打开全屏选卡页


func _finish_play(i: int, cell: Vector2i, from_pos := Vector2.ZERO) -> void:
	## 手牌上场（无额外代价的普通卡）：清选中 → 放置 → 联机同步。
	_clear_selection()
	var card := engine.state.hand[i]
	# R151 P0-4：武装落位动画的起点 —— 拖拽路径 = 松手时光标；点击路径 = 手牌槽位中心
	if from_pos == Vector2.ZERO:
		from_pos = _hand_rect(i).get_center()
	_place_from = {"pos": from_pos, "card_id": card.id, "at": _now()}
	engine.play_from_hand(i, cell)
	_net_send({"type": "action", "act": "play", "card": card.to_dict(),
			"cell": [cell.x, cell.y]})
	queue_redraw()   # 乌鸦上场会立刻弹出「从弃牌堆选盟友」面板


func _hero_pick_options() -> Array[int]:
	## 可以拿来当代价的手牌下标（不含英雄自己）。
	var out: Array[int] = []
	if _hero_pick_idx < 0:
		return out
	for i in engine.state.hand.size():
		if i != _hero_pick_idx:
			out.append(i)
	return out
func _infiltrate_dst_cells() -> Array[Vector2i]:
	## 潜入（9100）第二段的目的格：全棋盘任意空格，对方后排（移动禁区）除外。
	var out: Array[Vector2i] = []
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not engine.state.board.has(c)\
					and GameEngine.unit_slot_allowed(c, GameEngine.SIDE_SELF):
				out.append(c)
	out.sort()
	return out


func _foresight_mode_rects() -> Array:
	var bw := 460.0
	var bh := 40.0
	var x := WINDOW_W / 2.0 - bw / 2.0
	var y0 := WINDOW_H / 2.0 - 58.0
	return [Rect2(x, y0, bw, bh), Rect2(x, y0 + bh + 14.0, bw, bh)]


func _draw_foresight_mode() -> void:
	## 预判（9097）二选一面板。
	var rs: Array = _foresight_mode_rects()
	var box := Rect2(rs[0].position.x - 26.0, rs[0].position.y - 54.0,
			rs[0].size.x + 52.0, 168.0)
	UiTheme.draw_panel_bg(self, box)
	draw_rect(box, UiTheme.INK_600, false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_LABEL, "预判：选择一个效果",
			Vector2(WINDOW_W / 2, rs[0].position.y - 28), UiTheme.INK_800)
	var labels := [
		"① 从弃牌区选一张费用为 0 的技能卡加入手卡（之后本卡消失）",
		"② 从卡组将一张随机费用不为 0 的技能卡加入手卡",
	]
	for k in 2:
		draw_rect(rs[k], Color("e8e2f4") if k == 0 else Color("e2ecf4"))
		draw_rect(rs[k], Color("7a5ea8") if k == 0 else Color("4a7ea8"), false, 1.5)
		_draw_string_center(_font, UiTheme.FS_CAPTION, labels[k],
				rs[k].position + rs[k].size / 2.0, Color("222222"))


func _on_foresight_mode_click(pos: Vector2) -> void:
	var rs: Array = _foresight_mode_rects()
	for k in 2:
		if (rs[k] as Rect2).has_point(pos):
			engine.foresight_choose(k + 1)
			_clear_selection()
			queue_redraw()
			return
func _recall_mode() -> String:
	## 当前开着的是哪个「从弃牌区取牌」面板：""（无）/ "复活术" / "暗影步"。
	## R108：两套面板同构，只是候选口径不同（复活术仅盟友、暗影步任意卡），
	## 所以共用绘制/点击代码，由本函数分流，**不去改复活术的既有行为**。
	if engine.shadow_step_pending:
		return "暗影步"
	if engine.overhaul_pending:
		return "返修"
	if engine.revive_pending:
		return "复活术"
	return ""


func _recall_pending() -> bool:
	## 任一取牌面板开着（点棋盘/手牌时的模态拦截）。
	return engine.revive_pending or engine.shadow_step_pending or engine.overhaul_pending


func _recall_options() -> Array[int]:
	if engine.shadow_step_pending:
		return engine.shadow_step_options()
	if engine.overhaul_pending:
		return engine.overhaul_options()
	return engine.revive_options()


func _recall_remaining() -> int:
	if engine.shadow_step_pending:
		return engine.shadow_step_remaining
	if engine.overhaul_pending:
		return engine.overhaul_remaining
	return engine.revive_remaining


func _recall_discard_index(idx: int) -> bool:
	if engine.shadow_step_pending:
		return engine.shadow_step_recall(idx)
	if engine.overhaul_pending:
		return engine.overhaul_recall(idx)
	return engine.revive_recall(idx)



# ── R189 全屏选卡页（PickOverlay）─────────────────────────────

func _pick_active_kind() -> String:
	## 当前活跃的选卡场景（"" = 无）。优先级同原小面板的拦截顺序。
	if _hero_pick_idx >= 0:
		return "hero"
	# R205：「填充」（9146）也用全屏选卡页 —— 用户口径「使用后应该弹出选择卡界面，
	# 选一张卡变化」。原来靠「再点一张手牌」两段式，手牌被扇形压住时很难点中。
	if _reload_idx >= 0:
		return "reload"
	# R209：系统升级 / 回收也走选卡页（与填充同一套，见 `_build_pick_cfg`）
	if _sys_upgrade_idx >= 0:
		return "sysup"
	if _recycle_idx >= 0:
		return "recycle"
	if engine.wish_pending:
		return "wish"
	if engine.crow_pending:
		return "crow"
	if engine.whale_pending:
		return "whale"
	if engine.endless_pending:
		return "endless"
	if engine.rebirth_pending:
		return "rebirth"
	# R271：创意（8070）回合开始 / 量产型代达罗斯（8074）入场 —— 都是「选一张手卡变化」。
	if engine.creation_pending:
		return "creation"
	if engine.cannonize_pending:
		return "cannonize"
	# R331：惊喜运单（8079）回合开始 —— 候选是**卡组**（与淘汰 9174 同形态）。
	if engine.surprise_pending:
		return "surprise"
	if _recall_pending():
		return "recall"
	if engine.foresight_pick:
		return "foresight"
	# R292：拒绝命运（9098）改自动结算 → 不再有 "fate" 选卡场景。
	# R298 合体（9167）：场上目标已选 → 弹「从卡组选素体」面板。
	# 放在 focus 之前：合体有自己的待办字段（merge_pending），与专注互斥但不共用面板。
	# R317 淘汰（9174）：从卡组选一张盟友 / 工事变成素体。
	# 与合体互斥但**不共用字段**（各有 pending）：混用会在取消时清错状态。
	if engine.eliminate_pending:
		return "eliminate"
	if engine.merge_pending:
		return "merge"
	if engine.focus_pending:
		return "focus"
	return ""


func _hand_target_pick_kind(card: CardData) -> String:
	## R213：「目标在**手牌**里、靠全屏选卡页挑」的技能 → 选卡页 kind（"" = 不是这类卡）。
	## 这是**唯一判据口**：`_start_drag`（能不能拖）、`_finish_drag`（松手走哪条路）、
	## `_drag_zone_label`（画什么文案）三处共用它，加新卡只改这里。
	## 全量排查（R213）：按 `target_mode in [hand_unit, hand_any]` 筛，只有这三张。
	## 其余选卡页技能（预判 9097 / 拒绝命运 9098 / 警觉 9109 / 返修 9127 / 回响 9102）
	## 都是 `target_mode=none` → 拖到棋盘任意处就走 `use_spell`，本来就能拖，不在此列。
	if card == null:
		return ""
	# R269：轻量化（8068）与系统升级共用 "sysup" 这条手牌改造流（文案按卡名区分）。
	if card.id == GameEngine.SYS_UPGRADE_ID or card.id == GameEngine.HAND_LIGHTEN_ID:
		return "sysup"
	if card.id == GameEngine.RECYCLE_ID:
		return "recycle"
	if card.id == GameEngine.RELOAD_ID:
		return "reload"
	return ""


func _reload_options(skip: int) -> Array:
	## 「填充」的候选 = 手牌里**除它自己以外**的所有卡（业务下标 = 手牌下标）。
	## `skip` = 填充自己那张的手牌下标（调用方传 `_reload_idx` 或刚点的那张）。
	var out: Array = []
	for i in engine.state.hand.size():
		if i != skip:
			out.append(i)
	return out


func _sysup_word(card) -> String:
	## R269：手牌改造类技能的**目标范围文案**（唯一口）。
	## 系统升级 8039 吃「盟友或工事」，轻量化 8068 只吃「盟友」（工事移速恒为 0）。
	if card is CardData and (card as CardData).id == GameEngine.SYS_UPGRADE_ID:
		return "盟友或工事"
	return "盟友"


func _sysup_options(skip: int) -> Array:
	## 「系统升级」（8039）/**「轻量化」**（8068，R269）的候选 =
	## 手牌里**除它自己以外**可改造的卡（业务下标 = 手牌下标）。
	## 与引擎 `_sys_upgrade_hand_card` / `_lighten_hand_card` 的判定同口径 ——
	## 提前把技能 / 场地 / 效果卡滤掉，玩家不会「选了才被拒」（旧点击式常有这个白试）。
	## ⚠️ 两者的差别只在「要不要工事」：轻量化只吃盟友。
	var out: Array = []
	var ally_only := skip >= 0 and skip < engine.state.hand.size() \
			and engine.state.hand[skip].id == GameEngine.HAND_LIGHTEN_ID
	for i in engine.state.hand.size():
		if i == skip:
			continue
		var c: CardData = engine.state.hand[i]
		if ally_only:
			if c.kind == "盟友":
				out.append(i)
			continue
		if c.kind == "盟友" or c.is_fort():
			out.append(i)
	return out


func _recycle_options(skip: int) -> Array:
	## 「回收」（8064）的候选 = 手牌里**除它自己以外**的任意一张卡（不限种类 ——
	## 回收就是把卡换成素体，技能 / 场地卡同样能当目标）。
	var out: Array = []
	for i in engine.state.hand.size():
		if i != skip:
			out.append(i)
	return out


func _build_pick_cfg(k: String) -> Dictionary:
	## 各场景的选卡页配置：cards 与 opts 平行（opts[i] = 网格第 i 张卡的业务下标；
	## focus 例外：opts 存代表卡的 id，确认时按 id 在卡组找第一张）。
	var disc_cards := func(i: int) -> CardData: return engine.state.discard[i]
	match k:
		"hero":
			var hopts := _hero_pick_options()
			return {"kind": k, "short": "英雄的代价", "opts": hopts,
					"title": "英雄的代价：选择 %d 张手牌丢弃" % GameEngine.HERO_DISCARD,
					"note": "点卡选中 / 再点取消；选满后点确认 —— 英雄随即上场",
					"cards": hopts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": GameEngine.HERO_DISCARD,
					"confirm_label": "确认丢弃", "cancel_label": "取消上场"}
		"wish":
			# R306 许愿（9168）：从**卡组**选一张卡加入手卡。
			var wopts: Array = engine.wish_options()
			return {"kind": k, "short": "许愿", "opts": wopts,
					"title": "许愿：从卡组选择一张卡加入手卡（卡组 %d 张）"
							% engine.state.deck.size(),
					"note": "点卡选中，再点确认 —— 它立即进入你的手牌（从卡组取走）",
					"cards": wopts.map(func(i: int) -> CardData:
						return engine.state.deck[i]),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": "放弃许愿"}
		"crow":
			var copts: Array = engine.crow_options()
			return {"kind": k, "short": "乌鸦", "opts": copts,
					"title": "乌鸦：选择弃牌堆一张盟友回到手卡（必须选一张）",
					"note": "点卡选中，再点确认 —— 它立即回到你的手牌",
					"cards": copts.map(disc_cards),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}
		"whale":
			var wopts: Array = engine.whale_options()
			return {"kind": k, "short": "鲸鱼之怒", "opts": wopts,
					"title": "鲸鱼之怒：从弃牌堆取卡加入手卡（还可取 %d 张）" % engine.whale_remaining,
					"note": "点卡选中，再点确认 —— 它立即回到你的手牌；也可以放弃剩余取牌",
					"cards": wopts.map(disc_cards),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": "不选了（结束取牌）"}
		"endless":
			var eopts: Array = engine.endless_options()
			return {"kind": k, "short": "无尽黑暗", "opts": eopts,
					"title": "无尽黑暗：选择 1 张手牌弃掉（不能不选）→ 之后费用 +%d"
							% GameEngine.ENDLESS_DARK_ENERGY,
					"note": "点卡选中，再点确认 —— 它被弃掉",
					"cards": eopts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}
		"rebirth":
			# R222：新生（9148）—— 候选是全部手牌；确认后目标本场对战消失，
			# 并随机拿一张本职业奖励卡（界面文案由 action 处理器播报）。
			var bopts: Array = engine.rebirth_options()
			return {"kind": k, "short": "新生", "opts": bopts,
					"title": "新生：选择 1 张手牌使其消失（不能不选）→ 之后随机一张本职业奖励卡加入手牌",
					"note": "点卡选中，再点确认 —— 它本场对战消失（不进弃牌区）",
					"cards": bopts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}
		"creation":
			# R271 创意（8070）：候选 = 全部手牌；确认后随机变形成「被改造有额外效果」的卡，
			# 并获得改造：生命 +2。**不能不选**（效果区几张就选几次）。
			var cr_opts: Array = engine.creation_options()
			return {"kind": k, "short": "创意", "opts": cr_opts,
					"title": "创意：选择 1 张手牌，让它变成随机的「被改造有额外效果」卡牌",
					"note": "点卡选中，再点确认 —— 它随机变形，并获得改造：生命 +2",
					"cards": cr_opts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认变化", "cancel_label": ""}
		"cannonize":
			# R271 量产型代达罗斯（8074）：候选 = 全部手牌；确认后原位变成「聚能炮击」。
			var ca_opts: Array = engine.cannonize_options()
			return {"kind": k, "short": engine.cannonize_src, "opts": ca_opts,
					"title": "%s：选择 1 张手牌，把它变成「聚能炮击」" % engine.cannonize_src,
					"note": "点卡选中，再点确认 —— 它原位变成「聚能炮击」",
					"cards": ca_opts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认变化", "cancel_label": ""}
		"recall":
			var ropts: Array = _recall_options()
			var rtitle := "复活术：选择弃牌区一张盟友回到手卡（必须选一张）"
			if _recall_mode() == "暗影步":
				rtitle = "暗影步：选择弃牌区一张卡回到手卡（必须选一张）"
			elif _recall_mode() == "返修":
				rtitle = "返修：选择弃牌区一张盟友或工事回到手卡（生命+3）"
			return {"kind": k, "short": _recall_mode(), "opts": ropts,
					"title": rtitle,
					"note": "点卡选中，再点确认 —— 它立即回到你的手牌（还要选 %d 张）"
							% _recall_remaining(),
					"cards": ropts.map(disc_cards),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}
		"foresight":
			var fopts: Array = engine.foresight_options()
			return {"kind": k, "short": "预判", "opts": fopts,
					"title": "预判①：选择弃牌区一张费用为 0 的技能卡（必须选一张，之后本卡消失）",
					"note": "点卡选中，再点确认 —— 它立即回到你的手牌",
					"cards": fopts.map(disc_cards),
					"max_sel": 1, "confirm_label": "确认", "cancel_label": ""}
		"reload":
			# R205：填充（9146）—— 候选是手牌（除它自己），确认后目标原位变成「聚能炮击」。
			var lopts: Array = _reload_options(_reload_idx)
			return {"kind": k, "short": "填充", "opts": lopts,
					"title": "填充：选择一张手牌，把它变成「聚能炮击」",
					"note": "点卡选中，再点确认 —— 它原位变成「聚能炮击」；填充本身 0 费",
					"cards": lopts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认填充",
					"cancel_label": "取消（不扣费）"}
		"sysup":
			# R209：系统升级（8039）/ R269：轻量化（8068）—— 候选只列可改造的手牌；
			# 确认后就地改造（**本场战斗永久**）。文案按是哪张卡区分。
			var uopts: Array = _sysup_options(_sys_upgrade_idx)
			var ucard = engine.state.hand[_sys_upgrade_idx] \
					if _sys_upgrade_idx >= 0 and _sys_upgrade_idx < engine.state.hand.size() \
					else null
			var u_title := "改造"
			var u_note := "费用 +1 / 力量 +3 / 生命 +6（本场战斗永久），并记一层改造"
			if ucard is CardData:
				u_title = (ucard as CardData).card_name
			if ucard is CardData and (ucard as CardData).id == GameEngine.HAND_LIGHTEN_ID:
				u_note = "费用 -1 / 移动速度 +1（本场战斗永久），并记一层改造"
			return {"kind": k, "short": u_title, "opts": uopts,
					"title": "%s：选择一张手牌（%s）施加「改造」" % [u_title, _sysup_word(ucard)],
					"note": u_note,
					"cards": uopts.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认改造",
					"cancel_label": "取消（不扣费）"}
		"recycle":
			# R209：回收（8064）—— 候选 = 手里任意一张卡（除它自己），目标被换成素体。
			var copts2: Array = _recycle_options(_recycle_idx)
			return {"kind": k, "short": "回收", "opts": copts2,
					"title": "回收：选择一张手牌，把它换成「素体」",
					"note": "目标不限种类；素体带一层改造（0 费 1 攻 / 10 血，回合结束不弃牌）",
					"cards": copts2.map(func(i: int) -> CardData: return engine.state.hand[i]),
					"max_sel": 1, "confirm_label": "确认回收",
					"cancel_label": "取消（不扣费）"}
		"focus":
			# 专注 / 负重减轻（8066，R201）共用本场景：文案按 engine.focus_label 切换。
			# 沿用「卡组合并视图」：同名合并 + ×N 张数角标（整副卡组铺开没法看）。
			var fl := engine.focus_label
			var merged := _merged_deck(engine.state.deck)
			return {"kind": k, "short": fl,
					"opts": merged.map(func(m: Dictionary) -> int: return (m["card"] as CardData).id),
					"title": "%s：从卡组中移除 %d 张卡（本次对战中消失）" % [fl, engine.focus_remaining],
					"note": "点卡选中，再点确认 —— 它从卡组移除（本场对战消失）；已移除的不回收",
					"cards": merged.map(func(m: Dictionary) -> CardData: return m["card"]),
					"counts": merged.map(func(m: Dictionary) -> int: return m["count"]),
					"max_sel": 1, "confirm_label": "确认移除", "cancel_label": "取消%s" % fl}
		"eliminate":
			# R317 淘汰（9174）：候选 = 卡组里的**盟友 / 工事**（下标，不按 id ——
			# 同名卡可能有被改造过的副本，按 id 会改错那一张）。
			var elopts := engine.eliminate_options()
			return {"kind": k, "short": "淘汰",
					"opts": elopts,
					"title": "淘汰：从卡组选一张盟友或工事，把它变成「素体」",
					"note": "变成 0 费 1/1 的「素体」（回合结束不弃牌）；原来的改造不保留",
					"cards": elopts.map(func(i: int) -> CardData: return engine.state.deck[i]),
					"max_sel": 1, "confirm_label": "确认淘汰", "cancel_label": "取消（不改卡组）"}
		"surprise":
			# R331 惊喜运单（8079）：候选 = 卡组**全部**卡（下标，不按 id —— 卡组里可能
			# 有被生产订单 / 自主升级 / 淘汰改过数值的同 id 副本）。
			var sp_opts := engine.surprise_options()
			return {"kind": k, "short": "惊喜运单",
					"opts": sp_opts,
					"title": "惊喜运单：从卡组选一张卡，把它变成一张随机卡并加入手卡",
					"note": "点卡选中，再点确认 —— 它离开卡组，随机卡进手牌（还要选 %d 张）"
							% engine.surprise_remaining,
					"cards": sp_opts.map(func(i: int) -> CardData: return engine.state.deck[i]),
					"max_sel": 1, "confirm_label": "确认变化", "cancel_label": ""}
		"merge":
			# R298 合体（9167）：候选 = 卡组里**所有素体**（8025）。
			# ⚠️ opts 存的是**卡组下标**（不是 id）：卡组里可能同时有未经改造的原版素体
			#    和被生产订单 8048 / 自主升级改过数值的副本 —— 按 id 取第一张会吃错那一只。
			var mopts := engine.merge_deck_options()
			return {"kind": k, "short": "合体",
					"opts": mopts,
					"title": "合体：从卡组选一张「素体」，让它消失",
					"note": "它的力量与生命加到场上的目标身上（本场对战消失，不进弃牌区）",
					"cards": mopts.map(func(i: int) -> CardData: return engine.state.deck[i]),
					"max_sel": 1, "confirm_label": "确认合体", "cancel_label": "取消合体"}
	return {}


func _open_discard_view() -> void:
	## R301（用户口径）：弃牌区点开后**不再是那个居中的窄面板**，改成「选卡页那种全屏窗口」。
	## 实现上直接复用 `PickOverlay` 的排版（整屏半透明罩 + 每行 5 张放大卡 + 垂直滚动 +
	## 底部描述条），只把 cfg 标成 `view_only` —— 于是点卡不选中、「关闭」= 关窗，
	## 与选卡流程的行为差异全部收在 `PickOverlay.is_view()` 里。
	##
	## ⚠️ 顺序 = **先弃的在前**（`state.discard` 原序，不排序不打乱）—— 玩家看得见「哪几张
	##    是被挤掉进弃牌堆的」，与旧面板标题的「从左到右：先弃的在前」同一口径。
	## ⚠️ 不做同名合并：弃牌区每一张都是**独立实例**（可能被生产订单 / 自主升级改过数值），
	##    按 id 合并会把「+N 的那张」并进原卡（与 `_merged_deck` 的理由相同）。
	if _pick == null:
		return
	var n := engine.state.discard.size()
	if n == 0:
		return
	var opts: Array = []
	var cards: Array = []
	for i in n:
		opts.append(i)
		cards.append(engine.state.discard[i])
	_pick.open({
		"kind": "view_discard",
		"short": "弃牌区",
		"view_only": true,
		"title": "弃牌区 %d 张（从左到右：先弃的在前）" % n,
		"note": "滚轮 / 拖动翻页；悬停或点卡在下方看描述 —— 点「关闭」或右键返回战斗",
		"opts": opts,
		"cards": cards,
		"max_sel": 0,
		"confirm_label": "关闭",
		"cancel_label": "",
	})
	status_text = "弃牌区：%d 张（先弃的在前）" % n
	queue_redraw()


func _sync_pick() -> void:
	## 全屏选卡页的驱动器（每帧一次，开销极小）：pending 出现 → 打开；消失 → 关闭；
	## 场景切换 → 重开。回放模式不弹（回放 act 直接结算）。
	if _pick == null or engine == null:
		return
	# R301：全屏**浏览**窗（弃牌区）没有引擎待办 —— 它自己开、自己关。
	# ⚠️ 必须先放行：否则下一步 `_pick_active_kind()` 返回 "" 就会把它每帧关掉。
	if _pick.is_view():
		return
	var k := _pick_active_kind()
	if k == "":
		if _pick.is_picking():
			_pick.close()
			queue_redraw()
		return
	if not _pick.is_picking() or _pick.kind() != k:
		if k == "focus":
			_close_zone_panels()   # 专注走选卡页，不再复用卡组浏览面板
		_pick.open(_build_pick_cfg(k))
		queue_redraw()


func _on_pick_confirmed(sel: Array) -> void:
	## 选卡页「确认」的唯一结算口：网格下标 → 业务下标 → 引擎。
	if _pick == null or sel.is_empty():
		return
	var k := _pick.kind()
	var opts: Array = _pick.opts()
	match k:
		"hero":
			var drop: Array = sel.map(func(g: int) -> int: return int(opts[g]))
			var i := _hero_pick_idx
			var cell := _hero_pick_cell
			_hero_pick_idx = -1
			var card := engine.state.hand[i]
			if engine.play_hero_from_hand(i, cell, drop) == null:
				_say("%s：代价结算失败，卡仍在手牌" % card.card_name)
			else:
				_clear_selection()
				_net_send({"type": "action", "act": "play", "card": card.to_dict(),
						"cell": [cell.x, cell.y]})
				status_text = "%s 上场：付出代价（丢弃 %d 张手牌）" % [card.card_name, drop.size()]
		"wish":
			# R306 许愿：确认 → 卡组那张进手牌。
			var wi := int(opts[sel[0]])
			var wnm := "?"
			if wi >= 0 and wi < engine.state.deck.size():
				wnm = engine.state.deck[wi].card_name
			if engine.wish_pick(wi):
				status_text = "许愿：%s 从卡组加入手卡" % wnm
			_clear_selection()
		"crow":
			var ci := int(opts[sel[0]])
			var cnm := "?"
			if ci >= 0 and ci < engine.state.discard.size():
				cnm = engine.state.discard[ci].card_name
			if engine.crow_recall(ci):
				status_text = "乌鸦：%s 从弃牌堆回到手牌" % cnm
			_clear_selection()
		"whale":
			var wi := int(opts[sel[0]])
			var wnm := "?"
			if wi >= 0 and wi < engine.state.discard.size():
				wnm = engine.state.discard[wi].card_name
			if engine.whale_pick(wi):
				status_text = "鲸鱼之怒：%s 从弃牌堆回到手牌" % wnm
			_clear_selection()
		"endless":
			var ei := int(opts[sel[0]])
			var enm := "?"
			if ei >= 0 and ei < engine.state.hand.size():
				enm = engine.state.hand[ei].card_name
			if engine.endless_pick(ei):
				status_text = "无尽黑暗：弃掉 %s → 费用 +%d" % [enm, GameEngine.ENDLESS_DARK_ENERGY]
			_clear_selection()
		"rebirth":
			# R222：新生（9148）—— 确认 → 目标手牌消失 + 随机一张本职业奖励卡进手牌。
			var bi := int(opts[sel[0]])
			var bnm := "?"
			if bi >= 0 and bi < engine.state.hand.size():
				bnm = engine.state.hand[bi].card_name
			if engine.rebirth_pick(bi):
				status_text = "新生：%s 消失" % bnm
			_clear_selection()
		"creation":
			# R271 创意（8070）：确认 → 随机变形 + 改造（生命 +2）。
			var cri := int(opts[sel[0]])
			var crnm := "?"
			if cri >= 0 and cri < engine.state.hand.size():
				crnm = engine.state.hand[cri].card_name
			if engine.creation_pick(cri):
				status_text = "创意：%s 随机变形并获得改造：生命 +2" % crnm
			_clear_selection()
		"cannonize":
			# R271 量产型代达罗斯（8074）：确认 → 目标原位变成「聚能炮击」。
			# ⚠️ source 要在 pick 之前抓（pick 成功后 `cannonize_src` 可能已被下一组覆盖）。
			var ca_src: String = engine.cannonize_src
			var cai := int(opts[sel[0]])
			var canm := "?"
			if cai >= 0 and cai < engine.state.hand.size():
				canm = engine.state.hand[cai].card_name
			if engine.cannonize_pick(cai):
				status_text = "%s：%s 变成「聚能炮击」" % [ca_src, canm]
			_clear_selection()
		"recall":
			var ri := int(opts[sel[0]])
			var rnm := "?"
			if ri >= 0 and ri < engine.state.discard.size():
				rnm = engine.state.discard[ri].card_name
			if _recall_discard_index(ri):
				status_text = "%s：%s 从弃牌区回到手牌" % [_recall_mode(), rnm]
			_clear_selection()
		"foresight":
			var fi := int(opts[sel[0]])
			var fnm := "?"
			if fi >= 0 and fi < engine.state.discard.size():
				fnm = engine.state.discard[fi].card_name
			if engine.foresight_pick_card(fi):
				status_text = "预判：%s 回到手卡（本卡已消失）" % fnm
			_clear_selection()
		"reload":
			# R205：确认 → 结算 `cast_reload(填充手牌下标, 目标手牌下标)`。
			# 先抓卡对象（cast 会把填充从手牌拿走），再结算、再补联机消息 —— 与旧两段式同口径。
			var ridx := int(opts[sel[0]])
			var rsrc := _reload_idx
			_reload_idx = -1
			var rl_card: CardData = engine.state.hand[rsrc] \
					if rsrc >= 0 and rsrc < engine.state.hand.size() else null
			if rl_card == null:
				_say("填充：手牌已变化，请重新使用")
			else:
				status_text = "填充 → %s" % engine.cast_reload(rsrc, ridx)
				_net_send({"type": "action", "act": "spell",
						"card": rl_card.to_dict(), "target": null})
			_clear_selection()
		"sysup":
			# R209：确认 → `cast_sys_upgrade(系统升级下标, 目标手牌下标)`。
			# 先抓卡对象（cast 会把它从手牌拿走），再结算、再补联机消息（与填充同口径）。
			var uidx := int(opts[sel[0]])
			var usrc := _sys_upgrade_idx
			_sys_upgrade_idx = -1
			var su_card: CardData = engine.state.hand[usrc] \
					if usrc >= 0 and usrc < engine.state.hand.size() else null
			if su_card == null or (su_card.id != GameEngine.SYS_UPGRADE_ID \
					and su_card.id != GameEngine.HAND_LIGHTEN_ID):
				_say("改造：手牌已变化，请重新使用")
			elif su_card.id == GameEngine.HAND_LIGHTEN_ID:
				# R269：轻量化 → `cast_lighten(轻量化下标, 目标手牌下标)`
				status_text = "轻量化 → %s" % engine.cast_lighten(usrc, uidx)
				_net_send({"type": "action", "act": "spell",
						"card": su_card.to_dict(), "target": null})
			else:
				status_text = "系统升级 → %s" % engine.cast_sys_upgrade(usrc, uidx)
				_net_send({"type": "action", "act": "spell",
						"card": su_card.to_dict(), "target": null})
			_clear_selection()
		"recycle":
			# R209：确认 → `cast_recycle(回收下标, 目标手牌下标)`。
			var ridx2 := int(opts[sel[0]])
			var rsrc2 := _recycle_idx
			_recycle_idx = -1
			var rc_card: CardData = engine.state.hand[rsrc2] \
					if rsrc2 >= 0 and rsrc2 < engine.state.hand.size() else null
			if rc_card == null or rc_card.id != GameEngine.RECYCLE_ID:
				_say("回收：手牌已变化，请重新使用")
			else:
				status_text = "回收 → %s" % engine.cast_recycle(rsrc2, ridx2)
				_net_send({"type": "action", "act": "spell",
						"card": rc_card.to_dict(), "target": null})
			_clear_selection()
		"focus":
			# opts 存的是代表卡 id：按 id 找卡组里第一张（与合并视图口径一致）。
			var cid := int(opts[sel[0]])
			var di := -1
			for q in engine.state.deck.size():
				if engine.state.deck[q].id == cid:
					di = q
					break
			if di < 0:
				_say("%s：牌堆里已经没有这张卡了" % engine.focus_label)
			else:
				var qnm := engine.state.deck[di].card_name
				engine.focus_pick(di)
				if engine.focus_pending:
					status_text = "%s：已移除 %s，还要移除 %d 张" % [
						engine.focus_label, qnm, engine.focus_remaining]
				else:
					status_text = "%s：已移除 %d 张卡，它们本次对战中消失" % [
						engine.focus_label, engine.focus_total]
		"eliminate":
			# R317 淘汰（9174）：确认 → 卡组那张原位变成新素体（抽牌早在施放时结算过）。
			var eli := int(opts[sel[0]])
			var elnm := "?"
			if eli >= 0 and eli < engine.state.deck.size():
				elnm = engine.state.deck[eli].card_name
			if engine.eliminate_pick(eli):
				status_text = "淘汰：卡组里的 %s → 「素体」" % elnm
			else:
				_say("淘汰：没能选中这张卡（它仍在卡组里）")
			_clear_selection()
		"surprise":
			# R331 惊喜运单（8079）：确认 → 卡组那张离开卡组，随机奖励卡加入手卡。
			var spi := int(opts[sel[0]])
			var spnm := "?"
			if spi >= 0 and spi < engine.state.deck.size():
				spnm = engine.state.deck[spi].card_name
			if engine.surprise_pick(spi):
				status_text = "惊喜运单：卡组里的 %s → 一张随机卡入手" % spnm
			else:
				_say("惊喜运单：没能选中这张卡（它仍在卡组里）")
			_clear_selection()
		"merge":
			# R298 合体（9167）：确认 → 素体**本场消失**（进消耗区）→ 再调 use_spell 真正打出。
			# 付费 / 弃牌 / 出牌计数 / 次元判定全部由 use_spell 统一收尾，这里不重复一遍。
			var mgi := int(opts[sel[0]])
			var mhi := engine.merge_hand_index
			var mcell := engine.merge_cell
			var mnm := "素体"
			if mgi >= 0 and mgi < engine.state.deck.size():
				mnm = engine.state.deck[mgi].card_name
			if engine.merge_pick(mgi):
				var mdet := engine.use_spell(mhi, mcell)
				status_text = "合体：「%s」消失 → %s" % [mnm, mdet]
			else:
				_say("合体：没能选中这张素体（它仍在卡组里）")
			_clear_selection()
	# 累计型（鲸鱼 / 命运 / 取牌 / 专注）确认一张后 pending 可能还在：
	# 候选变了 → 用新 cfg 刷新（标题里的剩余数同步更新）；pending 没了由 _sync_pick 关。
	if _pick.is_picking() and _pick_active_kind() == k:
		_pick.update_cfg(_build_pick_cfg(k))
	queue_redraw()


func _on_pick_cancelled() -> void:
	## 底栏「放弃」按钮（仅 whale / hero / focus 有）。
	## R301：全屏浏览窗的「关闭 / 返回 / Esc / 右键」也走这里 —— 纯查看，不动引擎状态。
	if _pick == null:
		return
	if _pick.kind() == "view_discard":
		_pick.close()
		queue_redraw()
		return
	match _pick.kind():
		"whale":
			var left := engine.whale_remaining
			engine.whale_skip()
			status_text = "鲸鱼之怒：放弃剩余 %d 张的取牌" % left
			_clear_selection()
		"focus":
			var fc_label := engine.focus_label
			engine.focus_cancel()
			status_text = "%s：已取消剩余的移除" % fc_label
		"eliminate":
			engine.eliminate_cancel()
			status_text = "已取消：卡组不变（抽到的 4 张保留）"
		"merge":
			engine.merge_cancel()
			status_text = "已取消：合体仍在手牌（未扣费）"
			_clear_selection()
		"reload":
			_reload_idx = -1
			status_text = "已取消：填充仍在手牌（未扣费）"
			_clear_selection()
		"sysup":
			_sys_upgrade_idx = -1
			status_text = "已取消：系统升级仍在手牌（未扣费）"
			_clear_selection()
		"recycle":
			_recycle_idx = -1
			status_text = "已取消：回收仍在手牌（未扣费）"
			_clear_selection()
		"hero":
			var hnm := engine.state.hand[_hero_pick_idx].card_name
			_hero_pick_idx = -1
			status_text = "已取消：%s 仍在手牌（未付代价）" % hnm
	# pending 已清 → _sync_pick 下一帧关掉 overlay
	queue_redraw()


func _pick_banner_rect() -> Rect2:
	## 选卡页收起态的「继续选择」浮条（顶部中央；绘制与点击判定共用）。
	return Rect2(WINDOW_W / 2.0 - 240.0, 74.0, 480.0, 40.0)


func _draw_pick_banner() -> void:
	## 收起态浮条：pending 与选中都还在，点击回到选卡页。
	var r := _pick_banner_rect()
	draw_rect(r, Color(0.14, 0.12, 0.20, 0.95))
	draw_rect(r, Color("ffd27d"), false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_LABEL,
			"选择进行中：%s —— 点击继续" % String(_pick.cfg_short()),
			r.get_center(), Color("ffd27d"))
func _close_zone_panels() -> void:
	## 关掉所有区域浏览面板（专注选完 / 取消后收干净）。
	_effects_visible = false
	_enemy_effects_visible = false
	_relics_visible = false
	_deck_visible = false
	_run_deck_visible = false
	_run_deck_cache = []
	_void_visible = false
	_ee_popup = false   # R197：一并收掉敌方效果开场弹窗
	_zone_page = 0
	_relic_scroll = 0.0
# ── R242：AOE 释放范围预览（纯函数，便于回归）────────────────────

static func spell_aoe_kind(card: CardData) -> String:
	## 这张技能的 AOE 形状（"" = 不是 AOE）。**唯一判据口** —— 与引擎实现逐条对齐：
	##   * "cross" 十字（中心 + 四邻，越界裁剪）：
	##       火球 9007（`_blast(..., radius=1)`，manhattan ≤ 1）/
	##       陨石 9077（`_meteor`）/ 回旋斩 9096（`_whirl_blade`）；
	##   * "row" 一整横行：火墙术 9084（`_fire_wall_spell` 取 target.x）；
	##   加新的 AOE 技能只改这里，绘制与提示都跟着走。
	if card == null:
		return ""
	match card.id:
		GameEngine.FIREBALL_ID, GameEngine.METEOR_ID, GameEngine.WHIRL_BLADE_ID:
			return "cross"
		GameEngine.FIRE_WALL_SPELL_ID:
			return "row"
	return ""


static func spell_aoe_hits_ally(card: CardData) -> bool:
	## 这一发的 AOE **会不会打到自己人**（与引擎一致）：
	##   火球 9007 / 陨石 9077 / 火墙 9084（R247 起不分敌我）= true；
	##   回旋斩 9096 只打敌方 → false（火墙该行还会燃烧，另行 burn 提示）。
	if card == null:
		return false
	return card.id in [GameEngine.FIREBALL_ID, GameEngine.METEOR_ID,
			GameEngine.FIRE_WALL_SPELL_ID]


static func aoe_cells(kind: String, center: Vector2i) -> Array[Vector2i]:
	## AOE 形状 → 具体格集合（棋盘外的不收）。"" / 未知形状按「只有中心格」处理。
	var out: Array[Vector2i] = []
	match kind:
		"row":
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(center.x, y))
		"cross":
			out.append(center)
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var c: Vector2i = center + d
				if c.x < 0 or c.x >= FieldState.BOARD_ROWS or c.y < 0 or c.y >= FieldState.BOARD_COLS:
					continue
				out.append(c)
		_:
			out.append(center)
	return out


static func aoe_danger(state: FieldState, card: CardData, center: Vector2i) -> Dictionary:
	## 「这一发会不会伤到自己」的**唯一判定口**（绘制与测试共用）。返回：
	##   cells  —— 会被波及的格（浅橙）
	##   own    —— 其中的**己方单位**个数
	##   hp     —— 会不会**伤到我方 HP**（后排被覆盖：空格直接打 HP / 单位死了溢出）
	##   burn   —— 我方单位站在火墙那一行（施放不受伤，但该行燃烧，经过会被灼烧）
	var kind := spell_aoe_kind(card)
	var cells: Array[Vector2i] = aoe_cells(kind, center)
	var info := {"kind": kind, "cells": cells, "own": 0, "hp": false, "burn": false}
	if kind == "" or state == null:
		return info
	var my_back: int = GameEngine.back_row(GameEngine.SIDE_SELF)
	# ⚠️ 回旋斩（9096）也是十字，但**只打敌方** —— 十字里有自己人并不算「波及」，
	# 不能报红（否则玩家会以为这一刀会砍到自己人）。只有「不分敌我」的 AOE 才数自己人。
	if kind != "row" and not spell_aoe_hits_ally(card):
		return info
	for c: Vector2i in cells:
		var p: Placement = state.unit_at(c)
		if p == null or p.owner != GameEngine.SIDE_SELF:
			continue
		info["own"] = int(info["own"]) + 1
	if kind == "row":
		# 火墙（R247 起不分敌我）：站在该行的己方单位**立刻**吃 FIRE_WALL_DMG；
		# 该行同时燃烧，之后移动经过另受灼烧（同一单位合计上限 FIRE_WALL_CAP）。
		# 火墙只打**单位**、不打空格 → 恒不直接掉我方 HP（hp 保持 false）。
		info["burn"] = int(info["own"]) > 0
		return info
	# 不分敌我的真 AOE：覆盖到我方后排行 → 掉的是自己的 HP
	# （火球 `_blast` 会挑最近的**空格**直击 HP；后排单位被击破同样溢出漏 HP）
	for c2: Vector2i in cells:
		if c2.x == my_back:
			info["hp"] = true
			break
	return info


static func shared_shield_target_ok(p: Placement) -> bool:
	## 共享护盾 8069（R269）的**可点目标**判据 —— 与引擎 `_shared_shield()` 的三条拒因
	## 一一对应：只认**己方盟友**，且**还没有这个字段**（敌方 / 工事 / 重复给都会被拒）。
	## 单独抽成 static 是为了让回归能直接钉死它。R287 修复：8069 加卡时漏了下面
	## `_spell_target_cells()` 的分支 → 落进 else = 敌我全列，敌方格子也能点。
	if p == null or p.card == null:
		return false
	return p.owner == GameEngine.SIDE_SELF \
			and p.card.kind == "盟友" \
			and not p.card.has_affix(GameEngine.AFFIX_SHARED_SHIELD)


func _spell_target_cells(card: CardData) -> Array[Vector2i]:
	## 技能的可点目标格：火球术=任意格；击退/龙息=敌方单位；狂暴=己方盟友；其余=战场上所有单位。
	var out: Array[Vector2i] = []
	if card.id == GameEngine.FIREBALL_ID:
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == 9004 or card.id == GameEngine.DRAGON_BREATH_ID:
		for c: Vector2i in engine.state.board:
			if engine.state.board[c].owner == GameEngine.SIDE_OPPONENT:
				out.append(c)
		out.sort()
	elif card.id == GameEngine.FRENZY_ID:
		# 狂暴：只认己方「盟友」（工事/随从以外的单位不可选，敌方单位也不可选）
		for c: Vector2i in engine.state.board:
			var fp: Placement = engine.state.board[c]
			if fp.owner == GameEngine.SIDE_SELF and fp.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.FOREST_GUARD_ID:
		# 森林守护（9037，R180）：只认己方「盟友」。原走 else 分支会把**工事**也列为
		# 可选目标（高亮可点），但引擎 `_forest_guard` 只认 `kind == "盟友"`、点工事会被拒
		# （用户实测报「森林守护可以以工事为对象使用」）。这里与狂暴 / 加厚装甲同口径，
		# 提前把工事从可选集合里滤掉，别等玩家付了费、点了格子才被拒。
		for c: Vector2i in engine.state.board:
			var gp: Placement = engine.state.board[c]
			if gp.owner == GameEngine.SIDE_SELF and gp.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.LIFE_CYCLE_ID:
		# 生命循环（9150，R227）：只列**己方盟友**（工事不是盟友 → 不列，
		# 免得玩家点了才被引擎拒；与森林守护 / 狂暴同口径）。已获得的也不再列出。
		for c: Vector2i in engine.state.board:
			var lcp: Placement = engine.state.board[c]
			if lcp.owner == GameEngine.SIDE_SELF and lcp.card.kind == "盟友" \
					and not lcp.life_cycle:
				out.append(c)
		out.sort()
	elif card.id == GameEngine.UPGRADE_ID or card.id == GameEngine.MERGE_ID:
		# 升级 8027（R82）/ 合体 9167（R298）：只列**己方盟友或工事**（合体的目标同样是
		# 「场上一张卡」，而工事也能被改造 —— 与 `_upgrade_unit` / `_field_upgrade_grant`
		# 的受理口径一致）。
		# 必须在这里过滤掉敌方 —— 引擎侧 `_upgrade_unit` 也会拒敌方单位，
		# 但那时玩家已经付了费用、点了格子，提示「只能改造自己的单位」太晚。
		for c: Vector2i in engine.state.board:
			var up: Placement = engine.state.board[c]
			if up.owner == GameEngine.SIDE_SELF \
					and (up.card.kind == "盟友" or up.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.ARMOR_PLATE_ID:
		# 加厚装甲 8044（R95，机械之心）：只列**己方盟友**（工事不能选，
		# 与「升级」不同）。同样必须在这里过滤，别等玩家付了费才被拒。
		for c: Vector2i in engine.state.board:
			var ap: Placement = engine.state.board[c]
			if ap.owner == GameEngine.SIDE_SELF and ap.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.SHARED_SHIELD_ID:
		# 共享护盾 8069（R269，机械之心）：只列**己方盟友**、且**还没有这个字段**的
		# （工事不是随从、敌方不可改造、重复给没意义 —— 三条都与引擎 `_shared_shield()`
		# 的拒因一一对应）。R180 森林守护 9037 踩过同一个坑：落进 else = 敌方单位也
		# 高亮可点，点下去 `use_spell` 先把卡从手牌吃掉，才回一句「只能改造自己的单位」
		# —— 牌白丢。判据见上方的 shared_shield_target_ok()（static，回归直接调）。
		for c: Vector2i in engine.state.board:
			if shared_shield_target_ok(engine.state.board[c]):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.DEMOLISH_ID:
		# 拆解 8049（R97，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		# ⚠️ 必须在这里过滤掉敌方 —— 引擎侧 `_demolish` 也会拒，但那时已付费。
		for c: Vector2i in engine.state.board:
			var dp: Placement = engine.state.board[c]
			if dp.owner == GameEngine.SIDE_SELF \
					and (dp.card.kind == "盟友" or dp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.REORG_ID:
		# 重组 8051（R99，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		for c: Vector2i in engine.state.board:
			var rp: Placement = engine.state.board[c]
			if rp.owner == GameEngine.SIDE_SELF \
					and (rp.card.kind == "盟友" or rp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.TRANSCEND_ID:
		# 超越极限 8053（R99，机械之心）：只列**己方盟友或工事**，且**还没有超负荷**
		# （有了就别列，避免点上去被引擎拒「已拥有超负荷」）。
		for c: Vector2i in engine.state.board:
			var tp: Placement = engine.state.board[c]
			if tp.owner == GameEngine.SIDE_SELF \
					and (tp.card.kind == "盟友" or tp.card.is_fort()) \
					and not tp.card.has_affix(GameEngine.AFFIX_OVERLOAD):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.REBOOT_ID:
		# 重启 8054（R100，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		for c: Vector2i in engine.state.board:
			var rp: Placement = engine.state.board[c]
			if rp.owner == GameEngine.SIDE_SELF \
					and (rp.card.kind == "盟友" or rp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.BLADE_GIFT_ID:
		# 辅助刃 9164（R291，机械之心）：只列**己方盟友**（工事不是「盟友」）。
		for bgc: Vector2i in engine.state.board:
			var bgp: Placement = engine.state.board[bgc]
			if bgp.owner == GameEngine.SIDE_SELF and bgp.card.kind == "盟友":
				out.append(bgc)
		out.sort()
	elif card.id == GameEngine.DUPLICATE_ID:
		# 复制术 9165（R291，机械之心）：己方盟友或工事。
		# ⚠️ 落进下面的 else 会敌我全列 —— 玩家能点敌人，付费后才发现「不能被复制」。
		for dpc: Vector2i in engine.state.board:
			var dpp: Placement = engine.state.board[dpc]
			if dpp.owner == GameEngine.SIDE_SELF \
					and (dpp.card.kind == "盟友" or dpp.card.is_fort()):
				out.append(dpc)
		out.sort()
	elif card.id == GameEngine.BREAKTHROUGH_ID \
			or card.id == GameEngine.IMPACT_CANNON_ID:
		# 集中突破 9162 / 冲击炮 9163（R290，机械之心）：只列**敌方**单位。
		# ⚠️ 两张都是「对一个敌人造成伤害」，落进下面的 else 会把己方单位也高亮 ——
		#    玩家能点自己人、付费后才挨一发（R287 共享护盾 8069 踩过同一个坑）。
		for c: Vector2i in engine.state.board:
			var bp: Placement = engine.state.board[c]
			if bp.owner == GameEngine.SIDE_OPPONENT:
				out.append(c)
		out.sort()
	elif card.id == GameEngine.FIRE_WALL_SPELL_ID:
		# 火墙术：任意一条横行都能烧 → 全棋盘任意格都可点（点该行任一格即选中整行）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.ICE_WALL_SPELL_ID:
		# 冰墙术：目标是自己半场的一条横行 → 自己半场（下 3 行）的任一格都可点
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.IRON_FENCE_SPELL_ID:
		# 坚固围栏（原「在启动了」，R217 改名）：在自己半场选一格召唤铁栅栏 → 只列出自己半场的空格
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				var c := Vector2i(x, y)
				if not engine.state.board.has(c):
					out.append(c)
	elif card.id == GameEngine.SWAP_UNITS_ID:
		# 双向传送（8061，R102）：第一段 = 场上**任意单位**（敌我皆可）；
		# 第二段的可选集合在 _on_board_click 里按「除已选那个」现算。
		for c: Vector2i in engine.state.board:
			out.append(c)
		out.sort()
	elif card.id == GameEngine.INFILTRATE_ID:
		# 潜入：第一段只认己方「盟友」（工事不能动）；第二段目的格另给
		for c: Vector2i in engine.state.board:
			var ip: Placement = engine.state.board[c]
			if ip.owner == GameEngine.SIDE_SELF and ip.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.WHIRL_BLADE_ID:
		# 回旋斩：十字中心格 = 全棋盘任意格（只有敌方单位吃伤害）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.METEOR_ID:
		# 陨石术：十字范围不分敌我 → 全棋盘任意格都能砸（含空格：打后排放 HP）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.GOLEM_SPELL_ID:
		# 魔像术：在自己半场选一格召唤魔像 → 只列出自己半场的空格
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				var gc := Vector2i(x, y)
				if not engine.state.board.has(gc):
					out.append(gc)
	else:
		for c: Vector2i in engine.state.board.keys():
			out.append(c)
	return out


func _on_board_click(cell: Vector2i) -> void:
	# **R71：只能在「我方回合」操作我方单位。**
	# 原来这里没有任何回合门禁 → 敌方 AI 正在行动时，玩家仍能点选/移动/攻击自己的单位，
	# 于是「AI 动到一半被我抢走操作权」，看起来就像 AI 在错误地操作我方没行动过的单位。
	# 放在函数最前面：技能选目标、点手牌上场等后续分支都一并被挡住（它们也全是玩家操作）。
	if engine == null or engine.over:
		return
	# R77：鸭语耳环自动出牌播送中 —— 玩家不能插手，否则会跟自动出牌抢手牌/格子。
	if engine.earring_autoplay_active():
		_say("鸭语耳环正在自动出牌，等它出完（%d 张）" % engine.earring_played)
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		_say("现在是敌方回合，等对手行动完再操作自己的单位")
		return
	# 技能选目标模式
	if spell_pending >= 0:
		var sp_card: CardData = engine.state.hand[spell_pending]
		if spell_targets.has(cell):
			var idx := spell_pending
			# 潜入（9100）两段操作：第一段点己方盟友 → 第二段点目的格空格
			if sp_card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x < 0:
				_infiltrate_src = cell
				spell_targets = _infiltrate_dst_cells()
				if spell_targets.is_empty():
					_clear_selection()
					status_text = "潜入：没有可去的空格，技能仍在手牌"
				else:
					status_text = "潜入：再点一个空格作为目的地（右键取消）"
				queue_redraw()
				return
			# 双向传送（8061，R102）两段操作：第一段点单位甲 → 第二段点单位乙
			if sp_card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x < 0:
				_swap_src = cell
				# 第二段的可选集合 = 场上**除它以外**的所有单位（敌我皆可），但
				# R285：换完会有人落进对方后排的配对**不给点**（唯一判据 swap_pair_allowed）
				spell_targets = []
				for c: Vector2i in engine.state.board:
					if c != cell and engine.swap_pair_allowed(cell, c):
						spell_targets.append(c)
				spell_targets.sort()
				var picked: Placement = engine.state.unit_at(_swap_src)
				if spell_targets.is_empty():
					_clear_selection()
					status_text = "双向传送：没有能换的单位"
				else:
					status_text = "双向传送：已选 %s，再点另一个单位交换位置（右键取消）" % \
							picked.card.card_name
				queue_redraw()
				return
			_cast_spell(idx, cell, sp_card)
		else:
			_clear_selection()
			status_text = "已取消目标选择，技能仍在手牌"
		return
	# 已选中我方单位：执行移动 / 攻击 / 打 HP
	if selection != null and selection[0] == "board":
		var src: Vector2i = selection[1]
		# 再点自己一次 = 主动发动（熊 8004「回春」）
		if cell == src and engine.can_activate(src, GameEngine.SIDE_SELF):
			engine.activate(src, GameEngine.SIDE_SELF)
			_clear_selection()
			_net_send({"type": "action", "act": "activate", "args": [[src.x, src.y]]})
			return
		if hp_targets_arr.has(cell):
			_clear_selection()
			engine.attack_hp(src, cell)
			_net_send({"type": "action", "act": "hp",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			return
		if attack_targets_arr.has(cell):
			_clear_selection()
			engine.attack(src, cell)
			_net_send({"type": "action", "act": "attack",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			return
		if move_targets.has(cell):
			engine.move(src, cell)
			_net_send({"type": "action", "act": "move",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			var moved := engine.state.unit_at(cell)
			if moved != null and not moved.tapped:
				_select_board(cell)  # 已移动：只剩攻击或放弃
			else:
				_clear_selection()
			return
		# 落到这里 = 没点中任何有效目标（空格 / 打不到的敌人）——
		# 说明可做的事，然后按「切换选中 / 上膛 / 取消」处理。
		var sel_p := engine.state.unit_at(src)
		var reachable: bool = hp_targets_arr.size() + attack_targets_arr.size() + move_targets.size() > 0
		# ── R118：点到的若是**另一个还能被选中的己方单位** → 这是「切换选中」，
		#    不是误点空位 —— 保持老语义一步到位（并放弃已移动单位的攻击）。──
		var nxt := engine.state.unit_at(cell)
		if nxt != null and nxt.owner == GameEngine.SIDE_SELF and not nxt.tapped:
			_pass_moved_pending()
			_select_board(cell)
			status_text = "%s：绿色=移动 红色=攻击 深红=打HP" % nxt.card.card_name
			return
		# ── R118：其余（空格 / 打不到的敌人）都算「空位」，**第一次点只上膛** ──
		# 已移动未攻击的单位，「取消」= 就地横置、这一击**永久作废**且不可逆。
		# 用户口径：「不应该直接取消攻击，而是在第二次点击才取消，这个状态点击目标
		# 卡片依然可以攻击」。所以第一次只把选区标记成「待取消」：选区、绿色移动格、
		# 红色攻击格、深红 HP 格**一个都不动** → 这时点红/深红目标照样打出去；
		# 再点一次空位才真的取消。右键 / Esc 仍是一步取消。
		if _cancel_armed:
			_cancel_armed = false
			_pass_moved_pending()
			_clear_selection()
			status_text = "已取消选择"
			return
		_cancel_armed = true
		# ⚠️ 消息长度受顶栏 StatusLabel 限制（310px，超了会省略尾部）：
		#    只写到「取消」为止，「点红/深红仍可攻击」由**留着的红格**自己说明。
		if sel_p != null and reachable:
			_say("%s 到不了那里 · 再点空位=取消" % sel_p.card.card_name)
		else:
			_say("再点空位=取消选择")
		return
	# 已移动未攻击的单位：非攻击操作 = 放弃攻击（横置）
	_pass_moved_pending()
	# 点自己半场空格 + 手牌选中 → 上场（分步给失败原因）
	var p := engine.state.unit_at(cell)
	if selection != null and selection[0] == "hand":
		var i: int = selection[1]
		var card := engine.state.hand[i]
		if card.is_field():
			# R277（安卓触屏）：场地卡**允许落在已有单位 / 已有场地的格子**上 ——
			# 场地不是单位，两套数据互不影响（引擎 set_field 顶掉同格旧场地）。
			# 原来这里直接掉进下面「占用格拒绝」的随从分支 → 手机上「点卡 → 点格子」
			# 在有己方单位的格子上永远提示「那格已有 X，换一格放置」；
			# 而拖拽路径（_own_place_cells → _field_place_cells）本来就是对的。
			# 现在两条路径**同源**：合法格一律问 `_field_place_cells`（内部再问引擎）。
			if not _field_place_cells(card).has(cell):
				# R321（用户口径）：点了不正确的对象 → **取消选中手里的牌**
				# （原来是「只提示、卡还举着」，玩家会以为点了没反应）。
				_say("%s：这一格放不了场地（已取消选中）" % card.card_name)
				_clear_selection()
			elif not engine.can_pay_card(card):
				_energy_fail(card, i)   # R151 P2-15
			else:
				_try_play_hand_card(i, cell)
			return
		if not card.is_spell():
			# 带「交换」字段的卡（R101）可以落在己方已有单位上 → 顶回手；其余占用格拒绝
			if p != null and not engine.fence_merge_target(cell, card) \
					and not (card.has_affix(GameEngine.AFFIX_SWAP) \
					and p.owner == GameEngine.SIDE_SELF):
				_say("那格已有 %s（已取消选中）" % p.card.card_name)
				_clear_selection()
			elif FieldState.cell_owner(cell.x) != "self":
				_say("%s 只能放到自己半场（下 3 行）（已取消选中）" % card.card_name)
				_clear_selection()
			elif not engine.can_pay_card(card):
				_energy_fail(card, i)   # R151 P2-15
			else:
				_try_play_hand_card(i, cell)   # 英雄要先付「弃 4 张」的代价
				return
		else:
			# 技能卡：选中它只是「准备」，真正施放要**再点一次手牌上的它**。
			# 点棋盘格不算目标确认 → 取消选中（R321 用户口径）。
			_say("%s 是技能：再点一次手牌上的它才能选目标（已取消选中）" % card.card_name)
			_clear_selection()
		return
	# 选中战场单位
	if p != null and p.owner == GameEngine.SIDE_SELF and not p.tapped:
		_select_board(cell)
		status_text = "%s：绿色=移动 红色=攻击 深红=打HP" % p.card.card_name
		return
	_clear_selection()
	status_text = ""


func _on_right_click() -> void:
	_cam_cancel()                  # R288：右键取消 = 玩家要自己看，演出让位
	# R197：敌方效果开场弹窗开着 → 右键只关弹窗
	if _ee_popup:
		_ee_popup = false
		queue_redraw()
		return
	# 乌鸦的回手面板：必须选一张（不接受取消）
	if engine.crow_pending:
		_say("乌鸦：必须从弃牌堆选择一张盟友回到手牌")
		return
	# 鲸鱼之怒的取牌面板：右键 = 放弃剩余的取牌（本效果可选）
	if engine.whale_pending:
		engine.whale_skip()
		status_text = "鲸鱼之怒：放弃剩余取牌"
		queue_redraw()
		return
	# 无尽黑暗 9114（R70）：**不能不选** → 右键/Esc 只提示，不取消（与乌鸦同款）
	if engine.endless_pending:
		_say("无尽黑暗：必须从手牌里选一张弃掉（不能不选）")
		return
	# 新生 9148（R222）：**不能不选** → 右键/Esc 只提示，不取消（与无尽黑暗同款）
	if engine.rebirth_pending:
		_say("新生：必须从手牌里选一张使其消失（不能不选）")
		return
	# 取牌面板：必须选一张（不接受取消）
	if _recall_pending():
		_say("%s：必须从弃牌区选择一张卡回到手牌" % _recall_mode())
		return
	# 专注（9122）/ 负重减轻（8066，R201）：右键 = 取消剩余的移除（已移除的**不回收**，它们已经消失了）
	if engine.focus_pending:
		var rc_label := engine.focus_label
		engine.focus_cancel()
		_close_zone_panels()
		status_text = "%s：已取消剩余的移除" % rc_label
		queue_redraw()
		return
	if engine.foresight_mode:
		_say("预判：必须选择一个效果")
		return
	if engine.foresight_pick:
		_say("预判：必须从弃牌区选择一张费用为 0 的技能卡")
		return
	# 英雄的弃牌代价面板：右键 = 取消支付（卡留在手牌）
	if _hero_pick_idx >= 0:
		var hero_nm := engine.state.hand[_hero_pick_idx].card_name
		_hero_pick_idx = -1
		status_text = "已取消：%s 仍在手牌（未付代价）" % hero_nm
		queue_redraw()
		return
	_pass_moved_pending()  # 右键取消 = 已移动单位放弃攻击（横置）
	var pick_src := _picked_src()   # R102：两段式技能「已选的第一个单位」（潜伏/双向传送共用）
	_clear_selection()
	if pick_src.x >= 0 and engine.state.board.has(pick_src):
		# 明确告诉玩家"取消的是哪一个" —— 否则金黄标记消失后不知道刚才点的是谁。
		status_text = "已取消：%s 的选择已撤销，技能仍在手牌（右键取消）" % \
				engine.state.board[pick_src].card.card_name
	else:
		status_text = "已取消"


func _clear_hover_state() -> void:
	## 清空全部悬停态（左侧信息栏 + 状态栏提示 + 道具浮动说明）。
	_hover_card = null
	_hover_pl = null
	_hover_hand = -1
	_hover_relic_tip = ""
	_hover_mention = {}          # R302：提及浮窗跟着一起收


func _hover_purge_stale() -> void:
	## R294：悬停缓存可能已经**过期** —— 手牌出掉 / 弃掉 / 洗回之后，
	## `_hover_hand` 指的那个位置上已经不是原来那张卡了。
	## 不清掉的话左栏会一直停在「刚刚打出去的那张」，点别的卡也不换描述。
	## ⚠️ 只清**手牌**那一份（`_hover_hand >= 0` 才判）：战场单位 / 场地 / 区域面板的
	##    悬停不带下标，别误伤（那几类由 `_on_hover` 每次重算）。
	if engine == null or _hover_card == null or _hover_hand < 0:
		return
	if _hover_hand >= engine.state.hand.size() \
			or engine.state.hand[_hover_hand] != _hover_card:
		_hover_card = null
		_hover_hand = -1


func _hover_covered() -> bool:
	## R121：当前有没有「满屏覆盖层」压住了道具栏 / 棋盘。
	##   * `UiGate` 登记的外部覆盖层（奖励悬浮窗等跨场景面板）；
	##   * 战斗内自带的全屏面板：地图总览 / 道具浏览 / 对局记录。
	## 它们的共同点：鼠标坐标仍落在下层元素上，但玩家看不见 —— 此时再按鼠标位置
	## 弹说明，就会出现「看不见道具栏却在它上面弹出悬浮效果」（R121 用户报告）。
	## ⚠️ **不含** `_effects_visible` / `_enemy_effects_visible` / `_deck_visible` /
	##    `_run_deck_visible` —— 那些区域面板里的卡是**要**悬停查看的，
	##    由 `_on_hover` 的 ⓪ 分支单独处理，别在这里误杀。
	##    （弃牌区 R301 起改成 PickOverlay 全屏窗 —— 它自己是 Control、直接吃掉鼠标事件，
	##      `_on_hover` 根本收不到，因此也不需要在这里列。）
	if UiGate.blocked():
		return true
	if _reward_panel != null and _reward_panel.is_open():
		return true
	return _map_visible or _relics_visible or _log_visible


func _on_hover(pos: Vector2) -> void:
	## 悬停任何有信息的卡（战场/手牌/费用区/弃牌区）→ 左侧信息栏 + 状态栏。
	## 操作反馈保护期只保护状态栏文字；信息栏始终跟随悬停。
	## 英雄的弃牌代价面板、以及 R121 的各类满屏覆盖层：都不跟手牌/棋盘
	## （面板挡在上面，避免信息栏乱跳、避免在看不见的道具栏上弹说明）。
	if _hero_pick_idx >= 0 or _hover_covered():
		_clear_hover_state()
		return
	# R302：左栏本身是「可停留区」—— 鼠标从手牌滑进左栏时**不清卡**，否则要悬停
	# 「提及」那两个字的一瞬间左栏已经空了，根本没东西可悬停。提及判定排在最前。
	if _info_panel_rect().has_point(pos):
		_hover_mention = {}
		for h: Dictionary in _mention_hits:
			if (h["rect"] as Rect2).has_point(pos):
				_hover_mention = h
				break
		return
	_hover_mention = {}
	_clear_hover_state()
	var tip := ""
	# ⓪ 区域浏览面板（效果区 / 敌方效果区 / 弃牌区）开着时：面板盖住了棋盘与手牌，
	#    只认面板里的卡 → 悬停哪张就在左侧信息栏看哪张，面板空白处什么都不显示。
	var zp := _zone_panel_cards()
	if not zp.is_empty():
		var zl := _zone_panel_layout(zp.size())
		for i in zp.size():
			# R155 分页：非当前页的卡（矩形落在面板外）不响应悬停
			var zr := _zone_card_rect(i, zl)
			if zr.position.y < float(zl["py"]) + 30.0 or zr.end.y > float(zl["py"]) + float(zl["ph"]) - 30.0:
				continue
			if zr.has_point(pos):
				var zc: CardData = zp[i]
				_hover_card = zc
				if Time.get_ticks_msec() >= _status_hold_until:
					status_text = "%s 费用%d（效果见左侧）" % [zc.card_name,
							engine.cost_of(zc)]
				return
		return
	# ① 战场单位（双方都可查看）
	for cell: Vector2i in engine.state.board:
		var rect := _cell_rect(cell)
		if rect.has_point(pos):
			var p: Placement = engine.state.board[cell]
			_hover_card = p.card
			_hover_pl = p
			tip = "%s 力%d 生%d 程%d 速%d" % [p.card.card_name,
					p.effective_power(), p.health, p.effective_range(), p.effective_speed()]
			# R68：冰封 / 禁足是看不见的状态，悬停时直接说明「为什么它动不了」
			if p.frozen:
				tip += "　❄ 冰封（本回合不能行动）"
			elif p.rooted > 0:
				tip += "　⊥ 禁足（不能移动，仍可攻击）"
			# R122：沉睡有**两个**递减口 —— 自己的回合结束 -1（回合口）、每次受伤 -1
			#（受伤口）。写清「还剩几点」，玩家才知道该不该现在就打。
			if p.sleep_left > 0:
				tip += "　💤 沉睡（还剩 %d：自己的回合结束 -1，挨打也 -1）" % p.sleep_left
			# R87：护盾 / 自我修复都是隐藏状态，悬停必须写明「为什么它没掉血」。
			if p.first_hit_shield:
				tip += "　🛡 能量屏障（**第一次受到的伤害为 0**，用完消失）"
			# R162：护甲是临时护盾，悬停必须写明剩余量。
			if p.armor > 0:
				tip += "　🛡 护甲 %d（受到伤害时优先代替生命扣除）" % p.armor
			if p.regen > 0:
				tip += "　✚ 自我修复（每回合结束回 %d 血）" % p.regen
			if p.upgrade_stacks > 0:
				tip += "　改造 %d 层" % p.upgrade_stacks
			# R89：无限装甲（trait「改造供能」）——「本回合已用过 / 本回合还没用」是
			# 玩家必须能看到的信息（每回合一次的额度），否则会以为机制没生效。
			if p.card != null and p.card.traits.has(GameEngine.INF_ARMOR_TRAIT):
				if p.upgrade_feed_turn == engine.turn_total:
					tip += "　⟳ 本回合已供能（下回合再用改造刷新）"
				else:
					tip += "　⟳ 被改造时供一张 0 费改造牌"
			# 【字段系统 R91】列出这张卡**此刻生效**的字段（自动，不用为每个字段写一行）。
			# 读 `active_affixes`：疾行用掉一轮后、护盾用掉后都会自动从列表里消失。
			if p.card != null and not p.card.affixes.is_empty():
				for a in p.card.active_affixes(p.acts_left, p.first_hit_shield):
					tip += "　【%s】%s" % [CardData.affix_label(a),
						CardData.affix_desc(a)]
			break
	# ①b 场地（R84）：场地**不是单位**，上面那条循环查不到它 —— 挂在有场地、
	#   即使没单位的格子上，把 `trigger`（触发类型）显式写出来。
	#   这是 trigger 字段的**第一个消费者**：玩家在战场上就能看到「这格踩上去会发生什么」。
	if _hover_card == null and tip == "":
		for cell2: Vector2i in engine.state.field_effects:
			var frect := _cell_rect(cell2)
			if not frect.has_point(pos):
				continue
			var fc: CardData = engine.state.field_at(cell2)
			if fc == null:
				continue
			_hover_card = fc
			var fc_aim := GameEngine.field_aim(fc)
			if GameEngine.is_persistent_field(fc):
				# 持续型：没有「触发类型」可言，它的口径就是持续生效。
				# ⚠️ **必须按生效对象分文案**（R88）：清泉是「双」→ 敌我双方都受益；
				# 维修间 / 改造工厂是「友」→ 只有自己人受益。写成统一的「敌我双方都算」
				# 会让玩家以为敌方也能占便宜，白往敌方半场放。
				var fc_who := "敌我双方都算"
				if fc_aim == GameEngine.FIELD_AIM_ALLY:
					fc_who = "只对自己的单位生效"
				tip = "场地「%s」（持续生效，%s）" % [fc.card_name, fc_who]
				if fc.traits.has(GameEngine.PERSIST_UPGRADE_TRAIT):
					tip += "　每回合获得改造 +1 力 / +1 血（可无限叠）"
			else:
				tip = "场地「%s」（敌人移动经过时触发并停止移动）" % fc.card_name
			if fc.trigger != "":
				tip += "　触发：%s" % fc.trigger
			break
	# ② 己方手牌（会重叠 → 从最上层往前找）
	if _hover_card == null:
		for i in range(engine.state.hand.size() - 1, -1, -1):
			if _hand_hit(i, pos):
				_hover_hand = i
				_hover_card = engine.state.hand[i]
				# 效果详情显示在左侧信息栏（自动换行），顶部状态栏只留简短提示
				tip = "%s 费用%d（效果见左侧）" % [_hover_card.card_name,
						_hover_card.cost]
				# R65：这张现在打出去能吃到额外效果 → 状态栏补一句金色高亮的理由
				var bonus_txt := engine.hand_bonus_text(_hover_card)
				if bonus_txt != "":
					tip += "　★ " + bonus_txt
				break
	# ③ 左栏：能量面板 / 效果区（正面朝上，可逐张悬停查看）
	if _hover_card == null:
		var energy_rect := Rect2(COST_X, COST_Y, TAP_W + 12, ENERGY_H)
		if energy_rect.has_point(pos):
			tip = "能量 %d：每回合 5 点，回合结束重置（不累积），出牌消耗" % engine.state.energy
	if _hover_card == null:
		var merged_eff := _merged_effects(engine.state.effects)
		for i in merged_eff.size():
			if _effect_rect(i).has_point(pos):
				var m: Dictionary = merged_eff[i]
				_hover_card = m["card"]
				var cnt: int = m["count"]
				tip = "效果区 %d/%d 种：%s%s（效果见左侧，点击查看全部）" % [i + 1,
						merged_eff.size(), _hover_card.card_name,
						" ×%d" % cnt if cnt > 1 else ""]
				break
	if _hover_card == null:
		var zone_rect := Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, GRID_H - ENERGY_H)
		if zone_rect.has_point(pos):
			if engine.state.effects.is_empty():
				tip = "效果区（空）：效果卡使用后放在这里，持续生效"
			else:
				tip = "效果区 %d 张，持续生效中（点击查看全部）" % engine.state.effects.size()
	# ③' 右栏：敌方效果区（开局启用，正面朝上，可逐张悬停查看）
	if _hover_card == null:
		var merged_ee := _merged_effects(engine.state.enemy_effects)
		for i in merged_ee.size():
			if _enemy_effect_rect(i).has_point(pos):
				var m: Dictionary = merged_ee[i]
				_hover_card = m["card"]
				var cnt: int = m["count"]
				tip = "敌方效果 %d/%d 种：%s%s（效果见左侧，点击查看全部）" % [i + 1,
						merged_ee.size(), _hover_card.card_name,
						" ×%d" % cnt if cnt > 1 else ""]
				break
	if _hover_card == null and _enemy_zone_rect().has_point(pos):
		if engine.state.enemy_effects.is_empty():
			tip = "敌方效果区（空）"
		else:
			tip = "敌方效果 %d 张，持续生效中（点击查看全部）" % engine.state.enemy_effects.size()
	# ③'' 右栏道具栏：悬停看道具描述（装不下时悬停「+N」摘要 → 提示点开看全部）
	if _hover_card == null:
		var rel_hit := false
		# R171b：只检测**看得见的**徽章 —— 道具溢出时，不可见徽章的矩形会一路排到
		# 道具栏外（下面）；长说明悬浮窗翻到栏下时正好压在这些「幽灵矩形」上 →
		# 鼠标明明悬在悬浮窗 / 空白处也弹说明（用户实测）。可见数与 _draw_relic_bar 同源。
		var rel_shown: int = engine.self_relics.size() \
				if engine.self_relics.size() <= _relic_max_slots() \
				else _relic_max_slots() - 1
		for i in rel_shown:
			if _relic_rect(i).has_point(pos):
				rel_hit = true
				var rel := RelicRepo.load_json().get_relic(engine.self_relics[i])
				if rel != null:
					# 道具描述可能很长（叠加态的鸭等）：完整说明走浮动折行面板，
					# 不再塞进工具栏一行（会横向溢出窗口）
					var note := RunState.relic_state_note(engine.self_relics[i])
					_hover_relic_tip = "「%s」（%s）%s%s" % [
							RunState.relic_display_name(engine.self_relics[i]),
							rel.tag_line(), rel.desc,
							("\n" + note) if note != "" else ""]
				break
		if not rel_hit and tip == "" and _relic_zone_rect().has_point(pos):
			# 悬浮就能逐个看描述；装不下时才有「点开看全部」这条路
			tip = "道具 %d 个（悬浮看说明%s）" % [engine.self_relics.size(),
					"，点击查看全部" if _relic_bar_overflowed() else "，已全部列出"]
	# ④ 弃牌区（R140 改图标后不再显示顶牌 → 悬停只报张数，详情进点击面板）
	if _hover_card == null:
		var discard_rect := Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H)
		if discard_rect.has_point(pos):
			var dis := engine.state.discard
			if dis.is_empty():
				tip = "弃牌区（空）：被击破/用掉/弃掉的卡会进这里"
			else:
				tip = "弃牌区 %d 张（点击浏览全部）" % dis.size()
	# ⑤ 卡组：点击查看（相同卡合并，不泄露抽牌顺序）
	if _hover_card == null:
		var deck_rect := Rect2(DECK_X, DECK_Y, CARD_W, CARD_H)
		if deck_rect.has_point(pos):
			if engine.state.deck.is_empty():
				tip = "剩余牌堆（空）：抽牌堆用完了会把弃牌洗回来"
			else:
				tip = "剩余牌堆 %d 张（本场还没抽到；点开查看，不显示抽牌顺序）" \
						% engine.state.deck.size()
	# ⑥ R140 消耗（消失）区：本局消失的卡
	if _hover_card == null:
		if Rect2(VOID_X, VOID_Y, CARD_W, CARD_H).has_point(pos):
			tip = "消耗区 %d 张：本局「消失」的卡（离场消失 / 用后消失 / 从牌库抹除，不进弃牌区）" \
					% engine.state.void_count
	if tip != "" and Time.get_ticks_msec() >= _status_hold_until:
		status_text = tip


# ------------------------------------------------------------ 教程引导条

func _build_tut_bar() -> void:
	## 教程关卡的引导条：叠放在棋盘上方那条空档里
	## （R117 起顶部**已没有**对手手牌区，见 `TUT_BAR_MAX_H` 的说明）。
	_tut_bar = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff3d6")
	sb.border_color = Color("c8a03c")
	sb.set_border_width_all(2)
	_tut_bar.add_theme_stylebox_override("panel", sb)
	_tut_bar.position = Vector2(0, TUT_BAR_TOP)
	_tut_bar.size = Vector2(WINDOW_W, TUT_BAR_MAX_H)
	_tut_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_tut_bar.visible = false
	add_child(_tut_bar)

	_tut_title = Label.new()
	_tut_title.position = Vector2(12, 2)
	_tut_title.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_tut_title.add_theme_color_override("font_color", Color("7a5200"))
	_tut_bar.add_child(_tut_title)

	_tut_prog = Label.new()
	_tut_prog.position = Vector2(WINDOW_W - 330, 2)
	_tut_prog.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	_tut_prog.add_theme_color_override("font_color", Color("c08a1a"))
	_tut_bar.add_child(_tut_prog)

	_tut_check = Label.new()
	_tut_check.position = Vector2(WINDOW_W - 190, 2)
	_tut_check.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	_tut_check.add_theme_color_override("font_color", UiTheme.SIDE_SELF)
	_tut_bar.add_child(_tut_check)

	_tut_body = Label.new()
	_tut_body.position = Vector2(12, 20)
	_tut_body.size = Vector2(WINDOW_W - 170, 56)
	_tut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_body.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	_tut_body.add_theme_color_override("font_color", Color("3d3325"))
	_tut_bar.add_child(_tut_body)

	_tut_task = Label.new()
	_tut_task.position = Vector2(12, TUT_BAR_MAX_H - 22)
	_tut_task.size = Vector2(WINDOW_W - 170, 20)
	_tut_task.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	_tut_task.add_theme_color_override("font_color", Color("a05a00"))
	_tut_bar.add_child(_tut_task)

	_tut_next_btn = Button.new()
	_tut_next_btn.text = "下一步 ▸"
	_tut_next_btn.position = Vector2(WINDOW_W - 148, 30)
	_tut_next_btn.size = Vector2(136, 28)
	_tut_next_btn.pressed.connect(_tut_advance)
	_tut_bar.add_child(_tut_next_btn)

	_tut_close_btn = Button.new()
	_tut_close_btn.text = "✓ 关闭引导条"
	_tut_close_btn.position = Vector2(WINDOW_W - 148, 64)
	_tut_close_btn.size = Vector2(136, 28)
	_tut_close_btn.pressed.connect(_tut_close)
	_tut_bar.add_child(_tut_close_btn)
	for _tbtn: Button in [_tut_next_btn, _tut_close_btn]:
		UiTheme.apply_chip(_tbtn, true, true)


func _build_level_menu() -> void:
	_level_menu = PopupMenu.new()
	for i in GameLevels.level_names().size():
		_level_menu.add_item(GameLevels.level_names()[i], i)
	_level_menu.id_pressed.connect(func(idx: int):
		load_level(GameLevels.builtin_levels()[idx]))
	add_child(_level_menu)


# ------------------------------------------------------------ 结算覆盖层 / 横幅 / 彩带 / 记录面板

func _build_over_panel() -> void:
	## 胜负结算覆盖层：弹出「再来一局 / 选关 / 回到标题」。
	_over_panel = PanelContainer.new()
	# R154：白底红框 → 羊皮纸底（清单 §2.4）。边框色照旧在 _show_over 按胜负染
	# （胜 = 金 COL_WIN / 败 = 墨 COL_LOSE）；ribbon 飘带是 P2 素材待办，暂不做。
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.945, 0.914, 0.835, 0.97)   # 羊皮纸奶油底
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20.0)
	_over_panel.add_theme_stylebox_override("panel", sb)
	_over_panel.position = Vector2(GRID_X + GRID_W / 2 - 140, GRID_Y + GRID_H / 2 - 150)
	_over_panel.custom_minimum_size = Vector2(280, 0)
	_over_panel.visible = false
	add_child(_over_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_over_panel.add_child(box)
	_over_title = Label.new()
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_title.add_theme_font_size_override("font_size", UiTheme.FS_TITLE)
	box.add_child(_over_title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	hint.add_theme_color_override("font_color", UiTheme.INK_600)
	box.add_child(hint)
	_over_hint = hint
	_over_btn_restart = Button.new()
	_over_btn_restart.text = "再来一局"
	_over_btn_restart.custom_minimum_size = Vector2(220, 40)
	_over_btn_restart.pressed.connect(_on_over_restart)
	box.add_child(_over_btn_restart)
	_over_btn_level = Button.new()
	_over_btn_level.text = "选关"
	_over_btn_level.custom_minimum_size = Vector2(220, 40)
	_over_btn_level.pressed.connect(func():
		_level_menu.position = _over_panel.get_screen_position() + Vector2(30, 60)
		_level_menu.popup())
	box.add_child(_over_btn_level)
	_over_btn_title = Button.new()
	_over_btn_title.text = "回到标题"
	_over_btn_title.custom_minimum_size = Vector2(220, 40)
	_over_btn_title.pressed.connect(_on_back_to_title)
	box.add_child(_over_btn_title)
	UiTheme.apply_button(_over_btn_restart, true)     # 结算面板的**唯一主按钮**
	UiTheme.apply_button(_over_btn_level, false)
	UiTheme.apply_button(_over_btn_title, false)
	for b: Button in [_over_btn_restart, _over_btn_level, _over_btn_title]:
		b.custom_minimum_size = Vector2(220, 46)      # 24px 字 + 内距需要的高度
		b.pressed.connect(func(): sfx.play("click"))


func _mark_battle_checkpoint() -> void:
	## R323：**进战斗时写一份存档**，记下「我正停在这一场」——
	## 玩家在战斗里点「返回标题」，标题页的「继续游戏」才能回到这一场。
	## 原来存档只在地图检查点写，于是回到地图时那一格早被标成「已走过」
	## （`advance()` 在点格子那一刻就标了），这场战斗再也打不到。
	## ⚠️ 只在真实游玩时写：出图 / headless 探针不落盘。
	if not RunState.run_active or _shot_pending or _net_mode:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _cur_level.is_empty():
		return
	RunState.resume_battle = {"node": RunState.pending_node, "level": _cur_level}
	# R339：写「进战斗之前」那份快照（不是当前状态）—— 见 `_pre_battle_snap` 的说明。
	# 快照为空（例如老路径 / 非 run）时退回写当下状态，行为与 R323 一致。
	if _pre_battle_snap.is_empty():
		RunSave.save_run()
		return
	var d: Dictionary = _pre_battle_snap.duplicate(true)
	d["resume_battle"] = RunState.resume_battle
	RunSave.save_snapshot(d)


func _clear_battle_checkpoint() -> void:
	## R323：这一场打完了（胜 / 负）→ 立刻清掉「正在打的这场」并落盘，
	## 否则继续游戏会把你送回一场已经打完的战斗。
	if RunState.resume_battle.is_empty():
		return
	RunState.resume_battle = {}
	if RunState.run_active and DisplayServer.get_name() != "headless":
		RunSave.save_run()


func _settle_before_pick() -> void:
	## R216：奖励界面为了「即时道具立刻结算」要跳走时，先把本场的收尾做完。
	## 口径与 `_on_over_restart` 一致：Boss 通关有下一层 → 推进层；普通胜利 → 房间完成。
	if not RunState.run_active:
		return
	if _run_next_layer > 0:
		RunState.advance_layer(_run_next_layer)
		_run_next_layer = 0        # 防重入：结算按钮再点也不会推两次
	elif not _run_boss_win:
		RunState.complete_current()


func _on_over_restart() -> void:
	## 结算面板主按钮：
	##   * Boss 通关且有下一层 → 推进到下一层（满血 + 新地图）→ 起始道具三选一；
	##   * run 中（非 Boss 通关）→ 回冒险地图（奖励已由结算悬浮窗处理，R137 文案同步）；
	##   * 其余（通关无下一层 / 失败 / 单关）→ 回标题。
	if RunState.run_active and _run_next_layer > 0:
		RunState.advance_layer(_run_next_layer)
		# R310：进新层的起点 = 卷卷的对话事件（原「起始道具三选一」面板）
		SceneFx.goto("res://scenes/curtain.tscn")
	elif RunState.run_active and not _run_boss_win:
		# R119：卡牌奖励已由奖励悬浮窗处理（没收的会留在「待领奖励」入口里），
		# 这里只把节点标记完成、回地图 —— 不再切到独立的卡牌奖励场景。
		RunState.complete_current()
		SceneFx.goto("res://scenes/map.tscn")
	else:
		SceneFx.goto("res://scenes/title.tscn")


func _show_over(win: bool) -> void:
	_over_shown = true
	flee_btn.visible = false   # R341：打完了就不该再挂着一个「逃跑」
	_clear_battle_checkpoint()   # R323：这场结束了 → 续档不再指向它
	_run_next_layer = 0
	_over_hint.text = ""
	_over_hint.add_theme_color_override("font_color", UiTheme.INK_600)
	# 叠加态的鸭（6013）：本场消耗掉的复活概率写回 run（跨战斗永久保留）
	RunState.duck_revive_chance = engine.duck_revive_chance
	# 自愈（9065）：战斗结束后回复生命（写回 run 血量之前结算，才不会白回）
	if win:
		engine.battle_end_heal()
	var lvl: Dictionary = _cur_level if not _cur_level.is_empty() else {}
	var tier: int = int(lvl.get("tier", -1))
	if RunState.run_active:
		# 肉鸽 run 结算：写战斗记录（卡组内容 / 是否失败 / 最终血量）
		if win:
			RunState.hp = maxi(0, engine.state.hp_self)
			# 鸭梨（6019）：战斗内每次 HP 受伤累计的最大生命提升，写回 run（跨战斗保留）
			RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
			# R234 止血绷带（6029）：本场受伤合计 > 20 → 本层下次休息额外 +8（同层累计）。
			if RunState.has_relic(RunState.BANDAGE_RELIC_ID) \
					and engine.state.self_hp_damage_taken > RunState.BANDAGE_THRESHOLD:
				RunState.bandage_add(RunState.BANDAGE_HEAL)
			var node_type := str(RunState.pending_node.get("type", ""))
			RunState.on_battle_won(node_type)
			RunState.record_battle(repo, str(lvl.get("name", "?")), tier,
					true, RunState.hp)
			_run_boss_win = tier == GameLevels.TIER_BOSS
			# R181：战斗胜利掉金币（按关卡分级：普通简单 20 / 普通困难 30 / 精英 50/65 / Boss 100）
			var gold_gain := RunState.gold_for_tier(tier)
			if gold_gain > 0:
				RunState.gain_gold(gold_gain)
			# R151 P1-18：Boss 击破与胜利 → 全屏黑白闪（≤40ms，绝不滥用 —— 只有这一处）
			if win and _run_boss_win and not _shot_pending:
				_screen_flash = {"start": _now(), "dur": 40}
			RunState.reward_type = "boss" if _run_boss_win else "normal"
			# R119：奖励**先入队**，交给结算面板上的奖励悬浮窗 ——
			#   * 精英 / Boss 掉落道具（不与已拥有的重复；奖励池掉空则不掉）；
			#   * 卡牌三选一：普通 / 精英 / **Boss** 都给（R179 起）。
			#     Boss 走 `reward_type = "boss"` 的**好概率档**（普通 35% / 稀有 45% /
			#     史诗 20%，明显优于普通过的 70/27/3）——在此之前 Boss 不发卡牌奖励，
			#     `reward_type = "boss"` 实际是**死数据**（没有任何消费方）。
			# 「入队」不等于「发放」：玩家在悬浮窗里看过介绍、点过「领取」才真进袋子。
			var dropped := RunState.offer_relic_drop(node_type)
			if dropped > 0:
				RunState.queue_relic_reward(dropped)
			# R342：战斗胜利的卡牌奖励**只走这一个口** —— 持有「采集刀」6050 时
			# 它内部会多入队一组（各自独立三选一）。别在这里直接调 queue_card_reward。
			RunState.queue_battle_card_rewards(RunState.reward_type)
			if _run_boss_win:
				# R339：Boss 已击破 → 记账（`boss_beaten` + 清 `boss_pending`）。
				# ⚠️ 放在算 `_run_next_layer` **之前**：advance_layer 会清这个标记，
				#    顺序反了就等于白记；而这里记的是「刚刚这一层」。`on_battle_won` 里也调了一次
				#    （pending_node 不是 boss 的极端路径），幂等。
				RunState.mark_boss_beaten()
				# Boss 通关：本层打完了 —— 有下一层就推进（满血 + 新地图 + 起始道具
				# 三选一），没有下一层才结束整局 run。
				_run_next_layer = GameLayers.next_layer(RunState.current_layer)
			# R179：按钮文案只留几个字（用户报「字太多」）——掉落道具、回血 / 恢复生命
			# 这些细节都在奖励悬浮窗与结算提示行里，不必塞进按钮。
			if _run_boss_win:
				if _run_next_layer > 0:
					_over_btn_restart.text = "进入%s" % GameLayers.layer_name(_run_next_layer)
				else:
					_over_btn_restart.text = "返回标题"
			else:
					# R137：奖励在结算悬浮窗里就已经领过了，这里只是「回去」——
				# 再写「领取奖励」会让人以为按钮才是领取入口。
				_over_btn_restart.text = "返回冒险地图 →"
			_over_btn_restart.visible = true
			_over_btn_restart.disabled = false
			_over_btn_level.visible = false
			_over_btn_title.visible = false
			if _run_boss_win and _run_next_layer <= 0:
				RunRecord.finish("win")   # 通关：整局结果记一行
				RunState.end_run()
		else:
			RunState.record_battle(repo, str(lvl.get("name", "?")), tier,
					false, maxi(0, engine.state.hp_self))
			RunRecord.finish("lose")   # 失败：整局结果记一行
			RunState.end_run()
			_run_boss_win = false
			_over_btn_restart.visible = false
			_over_btn_level.visible = false
			_over_btn_title.text = "返回标题"
			_over_btn_title.visible = true
	else:
		# 单关/演示模式：胜利 → 剩余生命带回 run（下一场接着用）；失败 → 重置满血再来
		_run_boss_win = false
		if win:
			RunState.hp = maxi(0, engine.state.hp_self)
			RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
		else:
			RunState.reset(RunState.max_hp)
		_over_btn_restart.text = "再来一局"
		_over_btn_restart.visible = true
		_over_btn_level.visible = true
		_over_btn_title.text = "回到标题"
		_over_btn_title.visible = true
	if _net_mode:
		_net_send({"type": "bye"})
		_over_btn_restart.disabled = true   # 联机不能重开（同 Python 版）
	var sb := _over_panel.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = COL_WIN if win else COL_LOSE
	_over_title.text = "胜  利" if win else "失  败"
	_over_title.add_theme_color_override("font_color", COL_WIN if win else COL_LOSE)
	_over_panel.visible = true
	UiPop.play(_over_panel)   # R151 P1-9：结算面板入场 scale 0.92→1.0 + 淡入 160ms
	sfx.play("win" if win else "lose")
	if win:
		_spawn_confetti()
	# R119：有奖励入队 → 弹出奖励悬浮窗（压在结算面板之上；先看清战利品再决定去向）。
	# 关掉它不会丢奖励 —— 左上角常驻「✦ 待领奖励 N」可以随时回来。
	if win and _reward_panel != null and RunState.pending_reward_count() > 0:
		_reward_panel.open()


func _spawn_confetti() -> void:
	## 胜利彩带：从棋盘上方撒下 70 条彩色纸屑。
	var palette := [Color("e63946"), Color("f4a261"), Color("2a9d8f"),
			Color("457b9d"), Color("ffb703"), Color("9b5de5")]
	for i in 70:
		_confetti.append({
			"pos": Vector2(randf_range(GRID_X - 30, GRID_X + GRID_W + 30),
					randf_range(-160, -8)),
			"vel": Vector2(randf_range(-24, 24), randf_range(90, 190)),
			"rot": randf_range(0, TAU),
			"vr": randf_range(-4.0, 4.0),
			"size": Vector2(randf_range(5, 9), randf_range(9, 16)),
			"col": palette[randi() % palette.size()],
		})


func _tick_confetti(delta: float) -> bool:
	var alive := false
	for c: Dictionary in _confetti:
		c.pos += c.vel * delta
		c.rot += c.vr * delta
		c.vel.y = minf(c.vel.y + 60.0 * delta, 260.0)
		if c.pos.y < WINDOW_H + 40:
			alive = true
	return alive


func _show_banner(text: String, col := Color("1d3557"), dur := 1100) -> void:
	_banner = {"text": text, "col": col, "start": _now(), "dur": dur}


func _whisper_suffix() -> String:
	## 状态栏后缀：本回合鸭之低语随机到的强化。
	return "（鸭之低语：%s）" % _whisper_txt if _whisper_txt != "" else ""


func _menu_items() -> Array:
	## 战斗中的主菜单项 —— R155 起**只放设置类**（音效 / 返回标题）：
	## 地图 / 战斗记录 / 卡组都有顶栏专属按钮（用户口径：不该只藏在设置里），
	## 「选择关卡」从菜单下线（用户口径）。
	##
	## ⚠️ 本函数**每次打开菜单都会重新调用**（attach 传的是函数引用），音效文案总是当下值。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _open_menu() -> void:
	## 顶栏齿轮按钮。
	if _menu != null:
		_menu.open()


func _open_level_menu() -> void:
	## 菜单项「选择关卡」：按下时场景树还在暂停态 → **延后一帧**再弹，
	## 那时菜单已经关闭、暂停也恢复了（否则 PopupMenu 会卡在一个暂停的帧里）。
	_pop_level_menu.call_deferred()


func _pop_level_menu() -> void:
	_level_menu.position = Vector2i(int(GRID_X + GRID_W * 0.5 - 60.0),
			int(GRID_Y + 60.0))
	_level_menu.popup()


func _draw_menu_gear() -> void:
	## 顶栏齿轮图标（自绘）：hover 时提亮，轴孔的底色跟着按钮底板走
	## —— 孔用死色的话，hover 换底会在中心留一个突兀的深点。
	var hot := menu_btn.is_hovered()
	var col: Color = UiTheme.CHIP_SOLID_TEXT_HOVER if hot else UiTheme.CHIP_SOLID_TEXT
	var bg: Color = UiTheme.CHIP_SOLID_BG_HOVER if hot else UiTheme.CHIP_SOLID_BG
	UiTheme.draw_gear(menu_btn, menu_btn.size * 0.5, 8.2, col, bg)


func _toggle_log() -> void:
	_log_visible = not _log_visible
	queue_redraw()


func _toggle_deck_panel() -> void:
	## 顶栏「卡组」按钮（R155 上线 / R207 改口径）：打开的是**完整卡组** ——
	## 本局构筑的整副牌（`RunState.deck_ids`，跨战斗累积、含商店附魔）。
	## ⚠️ 旧版这里和点右下牌堆打开的是**同一个**面板（都读 `engine.state.deck`），
	##    于是玩家点上方按钮只看到「本场还剩几张」，整副牌根本看不到（用户反馈）。
	##    现在的分工见 `_run_deck_cards()` 与 `_deck_visible` 的注释。
	var cards := _run_deck_cards()
	if cards.is_empty() and not _run_deck_visible:
		return
	var was := _run_deck_visible
	_close_zone_panels()
	if not was:
		_run_deck_cache = []      # 每次打开重建（关闭期间卡组可能变过）
		_run_deck_visible = true
	queue_redraw()


func _run_deck_cards() -> Array:
	## 「完整卡组」的卡列表（R207）：
	##   * run 中 → `RunState.deck_ids` 经 `build_deck()` 展开（附魔卡是独立副本，
	##     卡面直接带附魔后的数值）；
	##   * 单关 / 演示（没有 run）→ 退回本场抽牌堆，至少不是空面板。
	## 与右下「剩余牌堆」的区别：那份是 `engine.state.deck`，会随出牌越抽越少；
	## 这份是本局**拥有的全部牌**，整场不变（除非胜利后加了新卡）。
	## ⚠️ 结果**缓存到面板关闭**：`build_deck()` 会为每张附魔卡复制一份 CardData，
	##    而 `_draw()` 每帧要问 `_zone_panel_cards()` 五六次（布局 / 分页 / 关闭按钮）——
	##    不缓存就是每帧复制整副牌。缓存作废点只放在开 / 关面板（战斗内改不了卡组）。
	if not _run_deck_cache.is_empty():
		return _run_deck_cache
	var out: Array = []
	if RunState.run_active and not RunState.deck_ids.is_empty() and repo != null:
		out.assign(RunState.build_deck(repo))
	elif engine != null:
		out.assign(engine.state.deck)
	_run_deck_cache = out
	return out


func _draw_hp_strip() -> void:
	## 顶栏血量条（R156）：双方 HP 图标化 —— 血滴素材 + 滚动数字（取代纯文字 HpLabel）。
	## 颜色沿用战场语言：我方绿 / 敌方红；画在 HpStrip 自己的画布上（顶栏子节点）。
	if engine == null:
		return
	var cy := hp_strip.size.y / 2.0
	var icon := 20.0
	var x := 2.0
	if _hp_icon != null:
		hp_strip.draw_texture_rect(_hp_icon, Rect2(x, cy - icon / 2.0, icon, icon), false)
	x += icon + 4.0
	var self_txt := "%d/%d" % [_roll("hp_self_bar", engine.state.hp_self), engine.state.max_hp_self]
	hp_strip.draw_string(_font_bold, Vector2(x, cy + 5), self_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9e6a0"))
	x += _font_bold.get_string_size(self_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
	if _hp_icon != null:
		hp_strip.draw_texture_rect(_hp_icon, Rect2(x, cy - icon / 2.0, icon, icon), false, Color("ffb0a8"))
	x += icon + 4.0
	hp_strip.draw_string(_font_bold, Vector2(x, cy + 5),
			"%d/%d" % [_roll("hp_opp_bar", engine.state.hp_opponent), engine.state.max_hp_opponent],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0a89e"))


# ------------------------------------------------------------ 战斗内地图总览（R64）
#
# 布局约定（**唯一来源就是这几个常量 + _mapview_view_rect**）：
#   面板 = 标题区(MAPVIEW_TOP) + 地图区 + 底部图例区(MAPVIEW_BOT)。
#   R128：地图是固定的 5×7 网格，7×74 = 518 宽、5×74 = 370 高 —— 面板装得下，
#   所以旧的「纵向滚动 + 双箭头提示」整块移除（滑块/箭头都不再需要）。
const MAPVIEW_CELL := 74.0           # 总览里的格子边长（正方形，彼此相接）
const MAPVIEW_TOP := 92.0            # 面板内标题区高度
const MAPVIEW_BOT := 70.0            # 面板内底部图例区高度


func _mapview_available() -> bool:
	## 能不能看地图：必须在 run 中且本局确实有地图。
	return RunState.run_active and not RunState.map_cells.is_empty()


func _toggle_map() -> void:
	## 「地图」按钮 / M 键：开关战斗内的地图总览面板。
	if not _mapview_available():
		return
	_map_visible = not _map_visible
	if _map_visible:
		_effects_visible = false
		_enemy_effects_visible = false
		_deck_visible = false
		_run_deck_visible = false
		_relics_visible = false
		_log_visible = false
	queue_redraw()


func _mapview_demo_walk() -> void:
	## 核验用：伪造「从起点一路向上走过 3 格」的状态。
	var cells := RunState.map_cells
	if cells.size() != RogueMap.CELLS:
		return
	RunState.cleared_ids = []
	var cur := int(RogueMap.start_cell(cells)["id"])
	RunState.cleared_ids.append(cur)
	for step in 3:
		var nxt := -1
		for nid in RogueMap.neighbor_ids(cells[cur]):
			var c: Dictionary = cells[int(nid)]
			if int(c["row"]) < int(cells[cur]["row"]) \
					and not RunState.cleared_ids.has(int(nid)):
				nxt = int(nid)
				break
		if nxt < 0:
			break
		RunState.cleared_ids.append(nxt)
		cur = nxt
	RunState.current_node_id = cur
	RunState.chocolate = RogueMap.MAX_STEPS - (RunState.cleared_ids.size() - 1)


func _mapview_panel_rect() -> Rect2:
	## 总览面板矩形（居中；整体比窗口小一圈，四边都留出背景）。
	var pw := minf(WINDOW_W - 220.0, 640.0)
	var ph := minf(WINDOW_H - 80.0, 660.0)
	return Rect2((WINDOW_W - pw) * 0.5, (WINDOW_H - ph) * 0.5, pw, ph)


func _mapview_view_rect() -> Rect2:
	## 地图**可视区**（标题区与图例区之间的那块）。
	var pr := _mapview_panel_rect()
	return Rect2(pr.position.x, pr.position.y + MAPVIEW_TOP,
			pr.size.x, maxf(40.0, pr.size.y - MAPVIEW_TOP - MAPVIEW_BOT))


func _mapview_cell_rect(cell: Dictionary) -> Rect2:
	## 某一格在窗口里的矩形 —— **唯一入口**（格子位置与命中都以它为准）。
	var view := _mapview_view_rect()
	var w := RogueMap.COLS * MAPVIEW_CELL
	var h := RogueMap.ROWS * MAPVIEW_CELL
	var x0 := view.position.x + (view.size.x - w) * 0.5
	var y0 := view.position.y + (view.size.y - h) * 0.5
	return Rect2(x0 + int(cell["col"]) * MAPVIEW_CELL,
			y0 + int(cell["row"]) * MAPVIEW_CELL, MAPVIEW_CELL, MAPVIEW_CELL)


func _mapview_is_current(node: Dictionary) -> bool:
	return int(node["id"]) == RunState.current_node_id


func _mapview_is_next(node: Dictionary) -> bool:
	## 「可以走过去」：RunState.available_nodes 是唯一判定口（与地图场景点击判定同源）。
	for n in RunState.available_nodes():
		if int(n["id"]) == int(node["id"]):
			return true
	return false


func _draw_map_panel() -> void:
	## 战斗内地图总览：**只读**的全局地图 —— 看清走过哪些房间、还剩几块巧克力、
	## 本层 Boss 是谁。战斗进行中不能在这里改路线，所以不可点房间。
	var pr := _mapview_panel_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_rect(pr, Color("1b1c22"))
	draw_rect(pr, Color("6a6f7d"), false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_BODY, "冒 险 地 图（战斗中查看）",
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 26.0), UiTheme.SAND)
	_draw_string_center(_font, UiTheme.FS_CAPTION,
			"%s    已探索 %d / %d 间    巧克力 ×%d    生命 %d/%d    卡组 %d 张" % [
				GameLayers.layer_name(RunState.current_layer),
				RunState.cleared_ids.size(), RunState.map_cells.size(),
				RunState.chocolate, RunState.hp, RunState.max_hp,
				RunState.deck_ids.size()],
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 48.0), UiTheme.INK_300)
	_draw_string_center(_font, UiTheme.FS_CAPTION,
			"本层 Boss：%s　·　M / 地图 按钮 或 点击任意处关闭（战斗中不能改路线）"
			% str(RunState.boss_level().get("name", "")),
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 68.0), Color("8f8b80"))
	# ⚠️ 顺序不可换：格子底 → 通路（小桥） → 图标（与冒险地图同一套）。
	_draw_map_tiles()
	_draw_map_bridges()
	_draw_map_fog()          # R145：内容看不见的格子盖迷雾（桥不盖）
	_draw_map_nodes()
	_draw_mapview_marks()    # R177：玩家标记（与冒险地图同一份数据，只读）
	_draw_map_legend(pr)


func _mapview_bridge_kind(cell: Dictionary, nb: Dictionary) -> int:
	## 通路语义：与冒险地图 `map_scene._bridge_kind` **同一口径**
	## （判定口 = MapBridge.kind_for，这里只负责把三个 bool 算出来）。
	var lit := (_mapview_is_current(cell) and _mapview_is_next(nb)) \
			or (_mapview_is_current(nb) and _mapview_is_next(cell))
	return MapBridge.kind_for(RunState.cleared_ids.has(int(cell["id"])),
			RunState.cleared_ids.has(int(nb["id"])), lit)


func _draw_map_bridges() -> void:
	## 通路（R130）：与冒险地图**同一套视觉**（都走 MapBridge 唯一绘制口）、
	## **同一套视野规则**（R145：通路全图可见 —— 路线要看得见，玩家才规划得了）。
	## 画在格子底之上、图标之下（调用顺序 tiles → bridges → fog → nodes）。
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
	var drawn := {}          # 去重：两格之间只盖一座桥
	for cell: Dictionary in RunState.map_cells:
		var ctr := _mapview_cell_rect(cell).get_center()
		for nid in cell["doors"]:
			var nb: Dictionary = RunState.map_cells[int(nid)]
			var key := mini(int(cell["id"]), int(nid)) * RogueMap.CELLS \
					+ maxi(int(cell["id"]), int(nid))
			if drawn.has(key):
				continue
			drawn[key] = true
			var kind := _mapview_bridge_kind(cell, nb)
			MapBridge.draw_bridge(self, ctr, _mapview_cell_rect(nb).get_center(), kind,
					MAPVIEW_CELL, pulse if kind == MapBridge.LIT else 0.0)


func _draw_mapview_marks() -> void:
	## R177：战斗内地图总览显示玩家标记（`RunState.map_strokes` / `map_flags`，
	## 与冒险地图同一份数据，这里只读）。用户口径：「当局内不论从哪种方式访问
	## 地图都能看到」。
	## 坐标系映射：冒险地图区 = (227, 94) 起 826×590（118/格），总览格子阵列
	## = (x0, y0) 起 7×74 / 5×74（74/格）—— 两边都是 7×5 等比 → 线性缩放即可。
	var view := _mapview_view_rect()
	var w := RogueMap.COLS * MAPVIEW_CELL
	var h := RogueMap.ROWS * MAPVIEW_CELL
	var x0 := view.position.x + (view.size.x - w) * 0.5
	var y0 := view.position.y + (view.size.y - h) * 0.5
	var s := MAPVIEW_CELL / 118.0
	var base := Vector2(227.0, 94.0)
	var off := Vector2(x0, y0)
	for st: Dictionary in RunState.map_strokes:
		var pts: PackedVector2Array = st["pts"]
		if pts.size() < 2:
			continue
		var mv := PackedVector2Array()
		for p: Vector2 in pts:
			mv.append(off + (p - base) * s)
		draw_polyline(mv, Color(0, 0, 0, 0.45), 3.5 * s + 1.6)
		draw_polyline(mv, Color(st["col"]), 3.5 * s)
	for f: Dictionary in RunState.map_flags:
		var fp: Vector2 = off + (Vector2(f["pos"]) - base) * s
		var pole := Vector2(fp.x, fp.y - 26.0 * s)
		draw_line(fp, pole, UiTheme.SAND, 2.2 * s)
		var tri := PackedVector2Array([pole, pole + Vector2(16, 5) * s, pole + Vector2(0, 10) * s])
		draw_colored_polygon(tri, Color(f["col"]))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
				Color(0, 0, 0, 0.55), 1.2 * s)
		draw_circle(fp, 2.6 * s, Color(0, 0, 0, 0.55))


func _draw_map_fog() -> void:
	## 总览里的迷雾：与冒险地图**同一口径**（判定口 = RunState.known_node），
	## 只是格子小一圈 → 云团也按比例缩小（半径都取 `r.size.x` 的百分比）。
	## ⚠️ 只在总览面板内部画，绝不越出面板。
	for cell: Dictionary in RunState.map_cells:
		var id := int(cell["id"])
		if RunState.known_node(id):
			continue
		_draw_map_fog_cell(_mapview_cell_rect(cell), id)


func _draw_map_fog_cell(r: Rect2, id: int) -> void:
	var inner := r.grow(-1.5)
	var phase := float(id) * 2.399
	draw_rect(inner, Color(0.11, 0.13, 0.19, 0.90), true)
	# R154：与冒险地图同一张云雾素材（清单 §2.3）；缺图回退下面的程序云团。
	var fog_tex := UiAssets.map_fog()
	if fog_tex != null:
		var jx := sin(phase) * 0.06
		var jy := cos(phase * 1.3) * 0.06
		var sz: Vector2 = inner.size * 1.05
		var ctr := inner.get_center() + Vector2(inner.size.x * jx, inner.size.y * jy)
		if sin(phase * 2.7) > 0.0:
			draw_set_transform(ctr, 0.0, Vector2(-1, 1))
			draw_texture_rect(fog_tex, Rect2(-sz * 0.5, sz), false,
					Color(0.92, 0.96, 1.0, 0.92))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(fog_tex, Rect2(ctr - sz * 0.5, sz), false,
					Color(0.92, 0.96, 1.0, 0.92))
		draw_rect(inner, Color(1, 1, 1, 0.05), false, 1.0)
		return
	for i in 5:
		var fx := 0.28 + 0.44 * float((id * 7 + i * 3) % 5) / 4.0
		var fy := 0.26 + 0.48 * float((id * 5 + i * 2) % 4) / 3.0
		var ctr := Vector2(inner.position.x + inner.size.x * fx,
				inner.position.y + inner.size.y * fy)
		var rad := inner.size.x * (0.20 + 0.05 * sin(phase + float(i) * 0.9))
		draw_circle(ctr, rad, Color(0.34, 0.40, 0.52, 0.22))
		draw_circle(ctr + Vector2(0.0, rad * 0.42), rad * 0.7, Color(0.03, 0.04, 0.07, 0.30))
	draw_rect(inner, Color(1, 1, 1, 0.05), false, 1.0)


func _draw_map_tiles() -> void:
	## 格子底 + 类型色描边（与冒险地图同一套）。与图标分两趟画 —— 中间夹一层通路。
	## R145：看不见内容的格子走**中性底**（按类型染色等于把内容漏出去）。
	for cell: Dictionary in RunState.map_cells:
		var r := _mapview_cell_rect(cell)
		if not RunState.known_node(int(cell["id"])):
			draw_rect(r, Color(0.10, 0.12, 0.17, 0.62), true)
			draw_rect(r, Color(1, 1, 1, 0.10), false, 1.2)
			continue
		var dtype := RogueMap.display_type(cell)
		var done: bool = RunState.cleared_ids.has(int(cell["id"]))
		var base: Color = UiTheme.MAP_NODE_COLORS.get(dtype, UiTheme.INK_500)
		draw_rect(r, Color(base.r, base.g, base.b, 0.22 if done else 0.13), true)
		draw_rect(r, Color(base.r, base.g, base.b, 0.85), false, 1.4)


func _draw_map_nodes() -> void:
	var t := float(Time.get_ticks_msec()) * 0.004
	for cell: Dictionary in RunState.map_cells:
		var r := _mapview_cell_rect(cell)
		var id := int(cell["id"])
		var known := RunState.known_node(id)
		# R145：看得见的才画内容（迷雾格的图标一个像素都不画）。
		var dtype := RogueMap.display_type(cell) if known else ""
		var done: bool = RunState.cleared_ids.has(id)
		# 内容：与冒险地图同一套 —— **只用图标**，缺图才回退汉字。
		var icon := UiAssets.node_icon(dtype) if known else null
		if icon != null:
			var ib := MAPVIEW_CELL * 0.62
			var box := Rect2(r.position.x + (r.size.x - ib) * 0.5,
					r.position.y + (r.size.y - ib) * 0.5, ib, ib)
			draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(), box), false,
					Color(1, 1, 1, 0.55) if done else Color.WHITE)
		elif known:
			draw_string(_font_bold, Vector2(r.position.x, r.position.y + 44.0),
					RogueMap.type_mark(dtype), HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
					UiTheme.FS_SUBHEAD, Color(1, 1, 1, 0.45) if done else UiTheme.PAPER)
		if _mapview_is_current(cell):
			draw_rect(r.grow(2.5), UiTheme.ACCENT_LIT, false, 2.2)
		elif _mapview_is_next(cell):
			var pulse := 0.5 + 0.5 * sin(t * 3.0)
			draw_rect(r.grow(2.0), Color(0.45, 0.9, 0.5, 0.45 + 0.30 * pulse), false, 2.0)


func _draw_map_legend(pr: Rect2) -> void:
	## 底部图例：八种房间类型各一格 + 两条状态说明。
	var y := pr.position.y + pr.size.y - MAPVIEW_BOT + 20.0
	var x := pr.position.x + 12.0
	for type in ["start", "battle", "elite", "rest", "event", "chest", "bigchest", "unknown"]:
		var base: Color = UiTheme.MAP_NODE_COLORS.get(type, UiTheme.INK_500)
		draw_rect(Rect2(x, y - 10.0, 12.0, 12.0), base, true)
		draw_string(_font, Vector2(x + 16.0, y), RogueMap.type_label(type),
				HORIZONTAL_ALIGNMENT_LEFT, 58, UiTheme.FS_CAPTION, Color("cfd3da"))
		x += 73.0
	draw_string(_font, Vector2(pr.position.x + 12.0, y + 24.0),
			"金框＝当前房间　绿框＝可以走过去　小桥＝通路（全图可见）　迷雾＝还看不清里面是什么",
			HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24.0, UiTheme.FS_CAPTION, Color("9aa0aa"))


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _tut_step() -> Dictionary:
	if _tutorial_finished or tutorial_step >= _tutorial.size():
		return {}
	return _tutorial[tutorial_step]


func _tut_update_bar() -> void:
	var step := _tut_step()
	if step.is_empty():
		_tut_bar.visible = false
		return
	_tut_bar.visible = true
	_tut_title.text = "%s · %s" % [_cur_level["name"], step["title"]]
	# 进度点：◆ 当前 ● 已走完 ○ 还没到
	var dots := ""
	for i in _tutorial.size():
		dots += "◆" if i == tutorial_step else ("●" if i < tutorial_step else "○")
	_tut_prog.text = "%s  步骤 %d/%d" % [dots, tutorial_step + 1, _tutorial.size()]
	_tut_body.text = str(step["text"])
	_tut_task.text = "▶ %s" % step["task"]
	_tut_check.text = ""
	# 高度按正文行数自适应。⚠️ 上限 TUT_BAR_MAX_H(46) **就是**实际高度：
	# 棋盘上沿已上移到 52，36..52 只有 16px，正文行数再多也装不下（引导条现为休眠代码）。
	var lines: int = str(step["text"]).split("\n").size()
	var h: float = clampf(24.0 + lines * 14.0 + 26.0, 40.0, TUT_BAR_MAX_H)
	_tut_bar.size = Vector2(WINDOW_W, h)
	_tut_task.position.y = h - 22.0
	_tut_next_btn.position.y = h - 68.0
	_tut_close_btn.position.y = h - 34.0


func _tut_advance() -> void:
	if _tutorial_finished:
		return
	if tutorial_step < _tutorial.size() - 1:
		tutorial_step += 1
		_tut_update_bar()
	else:
		_tut_close()


func _tut_close() -> void:
	_tutorial_finished = true
	_tut_bar.visible = false
	status_text = "教程完成，自由对局！"
	queue_redraw()


func _tutorial_check(key: String) -> bool:
	## 教程步骤完成判定（对应 Python 版 levels.py 的 _check_* 函数）。
	var own: Array[Placement] = []
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		if p.owner == GameEngine.SIDE_SELF:
			own.append(p)
	if key == "played":
		return not own.is_empty()
	if key == "moved":
		return own.any(func(p): return p.moved or p.tapped)
	if key == "tapped":
		return own.any(func(p): return p.tapped)
	if key == "dummy_hit":
		# 训练木桩受伤或已离场 = 发生过攻击
		for cell2: Vector2i in engine.state.board:
			var q: Placement = engine.state.board[cell2]
			if q.owner != GameEngine.SIDE_SELF and q.card.id == GameLevels._DUMMY_ID:
				return q.health < GameLevels._DUMMY_HEALTH
		return true  # 木桩不在场 = 已被摧毁
	if key == "fort_played":
		return own.any(func(p): return p.card.kind == "工事")
	if key == "spell_used":
		return engine.log.any(func(line): return str(line).begins_with("使用技能"))
	if key == "turn2":
		return engine.turn_number >= 2
	if key == "practiced":
		return not own.is_empty() or _tutorial_check("spell_used")
	if key == "attack_mode":
		return selection != null and selection[0] == "board" \
				and not attack_targets_arr.is_empty()
	if key.begins_with("card:"):
		var cid := int(key.substr(5))
		return own.any(func(p): return p.card.id == cid)
	if key.begins_with("moved_card:"):
		var nm := key.substr(11)
		return engine.log.any(func(line): return str(line).begins_with("%s 移动" % nm))
	return false


func _tut_poll() -> void:
	## 每帧轮询：当前步骤的完成条件满足 → 显示 ✓（不自动跳步）。
	var step := _tut_step()
	if step.is_empty():
		return
	var key := str(step["check"])
	_tut_check.text = "✓ 本步已完成" if key != "" and _tutorial_check(key) else ""


func _tut_pick_hand(cue_card: String) -> int:
	## 教程提示挑手牌：指定卡名优先；否则付得起 → 费用低 → 靠前。
	var hand := engine.state.hand
	if cue_card != "":
		for i in hand.size():
			if hand[i].card_name == cue_card:
				return i
	var best := -1
	for i in hand.size():
		if best < 0:
			best = i
			continue
		var pa := engine.can_pay_card(hand[i])
		var pb := engine.can_pay_card(hand[best])
		if pa != pb:
			if pa:
				best = i
		elif hand[i].cost < hand[best].cost:
			best = i
	return best


func _tut_play_cell() -> Vector2i:
	## 教程提示的目标空格：指定格优先；否则我方半场最前排第一个空格。
	var step := _tut_step()
	if step["cue_cell"] != null:
		return step["cue_cell"]
	for row in [3, 4, 5]:
		for col in FieldState.BOARD_COLS:
			var t := Vector2i(row, col)
			if not engine.state.board.has(t):
				return t
	return Vector2i(5, 0)


func _tut_unit_cell() -> Variant:
	## 教程提示操作的单位格：指定格优先；否则第一个未横置的我方单位。
	var step := _tut_step()
	if step["cue_cell"] != null:
		return step["cue_cell"]
	var fallback = null
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		if p.owner == GameEngine.SIDE_SELF:
			if fallback == null:
				fallback = cell
			if not p.tapped:
				return cell
	return fallback


func _tutorial_cue_rects() -> Array:
	## 当前步骤的操作提示 → 一组琥珀色闪烁矩形（对应 Python 版 TutorialCue）。
	var step := _tut_step()
	if step.is_empty() or _tutorial_finished:
		return []
	var cue := str(step["cue"])
	var rects: Array = []
	match cue:
		GameLevels.CUE_OWN_HALF:
			rects.append(Rect2(GRID_X, GRID_Y + 3 * CELL - _grid_scroll, GRID_W,
					3 * CELL).intersection(Rect2(GRID_X, GRID_Y, GRID_W, GRID_H)))
		GameLevels.CUE_HAND:
			var n := engine.state.hand.size()
			if n > 0:
				var r0 := _hand_rect(0)
				var r1 := _hand_rect(n - 1)
				# 卡底沉出窗口，框只圈看得见的那一截
				rects.append(Rect2(r0.position,
						Vector2(r1.end.x - r0.position.x, WINDOW_H - r0.position.y)))
		GameLevels.CUE_COST:
			rects.append(Rect2(COST_X, COST_Y, TAP_W + 12, GRID_H))
		GameLevels.CUE_PLAY:
			var ci := _tut_pick_hand(str(step["cue_card"]))
			if ci >= 0:
				rects.append(_hand_cue_rect(ci))
			rects.append(_cell_rect(_tut_play_cell()))
		GameLevels.CUE_UNIT:
			var uc = _tut_unit_cell()
			if uc != null:
				rects.append(_cell_rect(uc))
		GameLevels.CUE_TAPPED:
			for cell: Vector2i in engine.state.board:
				var p: Placement = engine.state.board[cell]
				if p.owner == GameEngine.SIDE_SELF and p.tapped:
					rects.append(_cell_rect(cell))
					break
		GameLevels.CUE_FORT:
			for cell: Vector2i in engine.state.board:
				var p: Placement = engine.state.board[cell]
				if p.owner == GameEngine.SIDE_SELF and p.card.kind == "工事":
					rects.append(_cell_rect(cell))
					break
		GameLevels.CUE_SPELL:
			for i in engine.state.hand.size():
				if engine.state.hand[i].is_spell():
					rects.append(_hand_rect(i))
					break
		GameLevels.CUE_NEXT:
			rects.append(_control_rect(_tut_next_btn))
		GameLevels.CUE_END:
			rects.append(_control_rect(end_turn_btn))
	return rects


func _cell_rect(cell: Vector2i) -> Rect2:
	## R123：格子矩形容器 = 屏幕位置（y 带滚动偏移）。
	return Rect2(GRID_X + cell.y * CELL_W, GRID_Y + cell.x * CELL - _grid_scroll,
			CELL_W, CELL)


func _control_rect(c: Control) -> Rect2:
	## 控件在画布（本节点）坐标系里的矩形：父容器位置 + 控件位置。
	var parent := c.get_parent() as Control
	return Rect2(parent.position + c.position, c.size)


func _draw_tutorial_cue() -> void:
	var rects := _tutorial_cue_rects()
	if rects.is_empty():
		return
	var step := _tut_step()
	var label := str(step["cue_label"])
	var t := Time.get_ticks_msec() / 1000.0
	var alpha := 0.55 + 0.35 * sin(t * 5.0)
	var col := Color(1.0, 0.62, 0.0, alpha)
	for r: Rect2 in rects:
		draw_rect(r, col, false, 3.0)
	_draw_string_nw(_font_bold, UiTheme.FS_CAPTION, label,
			rects[0].position + Vector2(4, -2), Color("a05a00"))
	# 动态鼠标图标：按键侧压下 + 点击波纹（对应 Python 版 guide.draw_mouse_icon）
	var right_click: bool = label.contains("右键")
	var arrow: bool = str(step["cue"]) == GameLevels.CUE_NEXT \
			or str(step["cue"]) == GameLevels.CUE_END
	var focus: Rect2 = rects[0]
	var mouse_pos := Vector2(focus.get_center().x,
			focus.position.y + focus.size.y - 24.0)
	if focus.size.y > CELL * 2:  # 大区域（整片半场/整排手牌）放中上，别挡住目标
		mouse_pos.y = focus.position.y + 40
	_draw_mouse_icon(mouse_pos, right_click, t, arrow)


func _draw_mouse_icon(pos: Vector2, right_click: bool, t: float, arrow: bool) -> void:
	## 简化版鼠标图标：22×32 白色鼠标，按下的那半键高亮 + 两道扩散波纹。
	var w := 22.0
	var h := 32.0
	var body := Rect2(pos - Vector2(w / 2, h / 2), Vector2(w, h))
	var cycle := fmod(t, 1.2) / 1.2          # 1.2 秒一个点击周期
	var pressed := cycle < 0.45
	var phase := cycle * 2.2                 # 波纹相位 0..1
	var col := Color("f77f00")
	# 波纹（从按键半边中心扩散，ease_out 收敛）
	var cx := body.position.x + (w * 0.72 if right_click else w * 0.28)
	var cy := body.position.y + 8
	for k in 2:
		var p: float = fposmod(phase + k * 0.5, 1.0)
		var r := 7.0 + 20.0 * (1.0 - pow(1.0 - p, 2.0))
		draw_arc(Vector2(cx, cy), r, 0, TAU, 24,
				Color(col.r, col.g, col.b, clampf(1.0 - p, 0.05, 1.0)), 2.0)
	# 指工具栏按钮的向上箭头
	if arrow:
		var tip := Vector2(body.get_center().x, body.position.y - 6)
		draw_line(tip, tip + Vector2(0, -16), Color("a05a00"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tip.x, tip.y - 24),
				Vector2(tip.x - 6, tip.y - 14), Vector2(tip.x + 6, tip.y - 14)]),
				Color("a05a00"))
	# 鼠标本体 + 左右键 + 滚轮
	draw_rect(body, Color.WHITE)
	draw_rect(body, Color("37474f"), false, 2.0)
	var split := body.position.y + h * 0.42
	var hit_dy := 2.0 if pressed else 0.0
	var active := col if pressed else Color("f2f2f2")
	# 左键半边
	var lrect := Rect2(body.position.x, body.position.y, w / 2 - 1, split - body.position.y + hit_dy)
	draw_rect(lrect, active if not right_click else Color("f2f2f2"))
	draw_rect(lrect, Color("37474f"), false, 1.0)
	# 右键半边
	var rrect := Rect2(body.position.x + w / 2 + 1, body.position.y, w / 2 - 1, split - body.position.y + hit_dy)
	draw_rect(rrect, active if right_click else Color("f2f2f2"))
	draw_rect(rrect, Color("37474f"), false, 1.0)
	# 滚轮
	draw_rect(Rect2(body.get_center().x - 2, body.position.y + 3, 4, 8), Color("cfd8dc"))


# ------------------------------------------------------------ 回合流程

func _on_end_turn() -> void:
	if engine == null or engine.over:
		return
	if engine.crow_pending:
		_say("乌鸦：请先选择一张要回到手牌的盟友")
		return
	if engine.whale_pending:
		_say("鲸鱼之怒：请先点一张卡取回，或点「不选了」结束取牌")
		return
	if engine.endless_pending:
		_say("无尽黑暗：请先从手牌里选一张弃掉（不能不选）")
		return
	if engine.rebirth_pending:
		_say("新生：请先从手牌里选一张使其消失（不能不选）")
		return
	if _recall_pending():
		_say("%s：请先选择一张要回到手牌的卡" % _recall_mode())
		return
	if engine.foresight_mode or engine.foresight_pick:
		_say("预判：请先完成选择")
		return
	if _net_mode:
		# 联机：发给对方 → 本机进入对方回合 → 等待回放
		if engine.current_side != GameEngine.SIDE_SELF or _net_replaying:
			status_text = "等待 %s 行动…" % NetSession.opp_name
			return
		_pass_moved_pending()
		_net_send({"type": "end_turn"})
		_clear_selection()
		engine.end_turn()
		if not engine.over:
			status_text = "等待 %s 行动…" % NetSession.opp_name
		queue_redraw()
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		return
	_pass_moved_pending()
	_clear_selection()
	engine.end_turn()
	if engine.over:
		queue_redraw()
		return
	if not engine.ai_enabled:
		# 教程关：对手不行动，直接轮回我方
		engine.end_turn()
		status_text = "第 %d 回合：能量重置为 5，抽 5 张%s" % [engine.turn_number, _whisper_suffix()]
		_show_banner("我方回合 · 第 %d 回合" % engine.turn_number, UiTheme.SIDE_SELF_TEXT)
		sfx.play("turn")
		queue_redraw()
		return
	status_text = "对手回合…"
	_show_banner("对手回合", Color("8a2b2b"))
	sfx.play("turn")
	queue_redraw()
	_ai_timer.start()


func _ai_step() -> void:
	if engine.over:
		_ai_timer.stop()
		status_text = "对局结束：%s（%s）" % [engine.result, engine.result_reason]
		queue_redraw()
		return
	var queue := engine.ai_action_queue()
	if queue.is_empty():
		_ai_timer.stop()
		engine.end_turn()
		if not engine.over:
			status_text = "第 %d 回合：能量重置为 5，抽 5 张%s" % [engine.turn_number, _whisper_suffix()]
			_show_banner("我方回合 · 第 %d 回合" % engine.turn_number, UiTheme.SIDE_SELF_TEXT)
			sfx.play("turn")
		queue_redraw()
		return
	engine.run_ai_unit(queue[0])
	queue_redraw()


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	if engine == null:
		return
	# 背景：铺满整个控件（R133 起是**当层的地图底图**，见 _refresh_bg_texture）
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
		draw_rect(Rect2(Vector2.ZERO, size), COL_BG_SCRIM, true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	# 屏幕震动：棋盘相关绘制整体偏移（面板/结算不受影响）
	var shake := Vector2.ZERO
	if _now() < _shake_until:
		shake = _shake_offset()
	# ---- R146：棋盘区（唯一受开场缩放影响的段落）----
	# 震动与缩放叠在**同一条 transform** 上。`draw_set_transform` 是 CanvasItem 的共享
	# 状态 → 棋盘区画完必须复位，下面的遮罩 / 面板 / 手牌全在屏幕空间。
	_begin_board_transform(shake)
	_draw_grid()
	_draw_attack_fx()
	_draw_board_cards()
	_draw_dying()
	_draw_flashes()
	_draw_ghosts()
	_draw_highlights()
	_draw_bursts()
	_draw_cues()          # R288：通用效果演出（脉冲 / 光带 / 卡名）—— 压在卡牌之上才看得见
	_draw_wake_rings()
	# R139：边框跟着战场本体滚动 → 顶带 / 底带会越过可视窗上下沿，必须**先画边框、
	# 再画遮罩**把溢出裁掉；顺序反了边框就会糊在工具栏与手牌上。
	# R146：放大后边框的**左右边带**也会外推 → 遮罩范围要四周一起按比例摊开（见该函数）。
	_draw_grid_frame()
	draw_set_transform(shake, 0.0, Vector2.ONE)   # 复位缩放，回到屏幕空间（只留震动）
	_draw_grid_mask()
	_draw_grid_caption()
	_draw_floaters()
	# ---- 面板区：一律画在遮罩**之后** ----
	# R146 起遮罩会横向加宽（棋盘放大时把外溢的石色裁掉）→ 两侧栏位若先画就会被裁掉。
	_draw_cost_zone()
	_draw_deck_and_discard()
	_draw_deck_fly()
	_draw_hp_banner()
	_draw_enemy_effects()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # 结束震动，后续 UI 不抖
	_draw_level_plate()
	_draw_hand_base()
	_draw_hand()
	_draw_hand_fly()
	_draw_transform_fx()
	_draw_turn_owner_fx()
	_draw_pow_fx()
	_draw_heal_fx()
	_draw_impacts()
	_draw_reject_fx()
	_draw_screen_flash()
	_draw_drag()
	_draw_info_panel()
	_draw_mention_tip()
	if _log_visible:
		_draw_log_panel()
	if _map_visible:
		_draw_map_panel()

	if _deck_visible:
		# R207：右下牌堆 = **现有卡组**（本场还没抽到的牌，会越抽越少）
		var deck_title := "剩余牌堆 %d 张（本场未抽到 · 同名合并）" % engine.state.deck.size()
		_draw_zone_panel(deck_title,
				_zone_panel_cards(), _zone_panel_counts())
	if _run_deck_visible:
		# R207：顶栏「卡组」= **完整卡组**（本局构筑的整副牌）
		var run_title := "完整卡组 %d 张（本局构筑 · 同名合并）" % _run_deck_cards().size()
		_draw_zone_panel(run_title, _zone_panel_cards(), _zone_panel_counts())
	if _void_visible:
		_draw_zone_panel("消耗区 %d 张（相同卡合并；消失的卡本场对战不再出现）" % engine.state.void_count,
				_zone_panel_cards(), _zone_panel_counts())
	if _effects_visible:
		_draw_zone_panel("效果区 %d 张（同名合并，正面朝上，持续生效中）" % engine.state.effects.size(),
				_zone_panel_cards(), _zone_panel_counts())
	if _enemy_effects_visible:
		_draw_zone_panel("敌方效果 %d 张（同名合并，开局启用，持续生效中）" % engine.state.enemy_effects.size(),
				_zone_panel_cards(), _zone_panel_counts())
	if _relics_visible:
		_draw_relic_panel()
	_draw_relic_tip_panel()
	_draw_tutorial_cue()
	_draw_confetti()
	_draw_banner()
	# R189：选卡面板已统一为 PickOverlay 子节点（自己画自己）；
	# 这里只画「收起态」的继续选择浮条（画在横幅之后，不能被盖住）。
	if _pick != null and _pick.is_picking() and not _pick.visible:
		_draw_pick_banner()
	if engine.foresight_mode:
		_draw_foresight_mode()
	if _ee_popup:
		_draw_enemy_effect_popup()   # R197：开场敌方效果弹窗（画在最上层）
	if engine.over:
		_draw_game_over()


func _art(card: CardData, rect: Rect2) -> void:
	var tex := CardFace.art_for(card.id)
	if tex == null:
		return
	# 保持比例放进插图区
	var tr := CardFace.fit_rect(tex.get_size(), rect)
	draw_texture_rect(tex, tr, false)


func _draw_card_face(card: CardData, rect: Rect2, hp: int, selected: bool, is_tapped: bool,
		cost_override := -1, power_override := -1, on_board := false, sleeping := false) -> void:
	## 卡面一律按 rect 完整排版（含手牌）—— 卡底沉出窗口下沿的那截由视口裁掉，
	## 卡面内容**不做**任何偏移补偿：卡片是一个整体，被挡住就挡住。
	## cost_override >= 0 且不等于卡面费用 → 在费用圆上重画**绿色**数字，
	## 让玩家一眼看出「这张卡现在更便宜」（协同攻击等动态减费）。
	## power_override >= 0 → 用实际力量重画左下角标（战场单位传 effective_power()）。
	## on_board = true → 卡面的「种类 · 字段」行只写**上场之后仍然有用**的字段
	##   （R118：交换 / 幻影 是打出那一刻的规则，落在格子上之后再标就是噪音）。
	## name_only = true（战斗内一律）→ 卡面**只画卡名**，不画种类·字段与效果文 ——
	##   效果详情由悬停/点选的描述面板提供（左侧信息栏「悬停优先，其次选中的卡」）。
	CardFace.draw(self, card, rect, hp, selected, is_tapped, _font, _font_bold, power_override,
			on_board, sleeping, true)
	if not card.x_cost and cost_override >= 0 and cost_override != card.cost:
		# ⚠️ R122：**必须走 CardFace.draw_badge()**（同一个槽位的唯一绘制口）。
		# 这里原来自己 `draw_circle` 盖一个纯色圆盘 —— R115 把费用徽章换成
		# 「水晶图标 + 数字」之后，那一圈圆盘会把图标整个盖掉，于是「降费后
		# 宝石图标不再能正确显示」（用户实测反馈）。改调公开口之后，
		# 图标照旧、只有**数字**变绿，减费的信号一点没丢。
		CardFace.draw_badge(self, _font_bold, CardFace.cost_badge_center(rect),
				CardFace.badge_radius(rect), CardFace.badge_font(rect), "cost",
				str(cost_override), COL_COST_LOW_BG, COL_COST_LOW_FG)


func _draw_card_back(rect: Rect2, tags := "") -> void:
	if _back_tex != null:
		draw_texture_rect(_back_tex, rect, false)
	else:
		draw_rect(rect, Color.BLACK)
		var inset: float = minf(rect.size.x, rect.size.y) * 0.18
		draw_line(rect.position + Vector2(inset, inset),
				rect.end - Vector2(inset, inset), Color.WHITE, 2.0)
		draw_line(Vector2(rect.end.x - inset, rect.position.y + inset),
				Vector2(rect.position.x + inset, rect.end.y - inset), Color.WHITE, 2.0)
	draw_rect(rect, Color("20283f"), false, 1.5)


## R138：背景换成**当层地图底图**（R133）之后，直接画在图上的文字必须自带描边才看得清。
## 两个文字助手在**没有显式指定**描边时（`outline <= 0`）自动补一圈近黑的暖色描边，
## 宽度随字号自适应（`_auto_outline`）—— 亮底（信息栏 / 各类面板）上几乎看不出，
## 底图上却能压住杂色。徽标那套**显式**白描边（传 `outline > 0`）完全不受影响。
const TEXT_OUTLINE_COL := Color(0.05, 0.04, 0.03, 0.85)


# ------------------------------------------------------------ R140：图底文字「带背景条」
## 描边压不住花哨的当层地图底图（用户实测「即使描边还是看不清」）→ 统一改成
## **深色半透明底条 + 细亮边 + 亮字**。只给**画在地图上**的文字用；
## 卡面 / 面板 / 徽章 / 铭牌内部本来就有底，保持原样不动。
## ⚠️ 用了底条之后字必须换成**亮色** —— 原来的 INK_600(#555) / STAT_POWER(#8a5f00) /
## SIDE_SELF_TEXT(#1b5e20) 都是给**浅底**挑的深色，压在深底条上等于看不见。
const TEXT_BG := Color(0.05, 0.043, 0.035, 0.76)
const TEXT_BG_EDGE := Color(1.0, 0.95, 0.80, 0.16)
const TEXT_BG_PAD_X := 6.0
const TEXT_BG_PAD_Y := 3.0
const TXT_LIGHT := Color("f2ecdd")    # 一般文字（亮米白）
const TXT_SELF := Color("9fe0a6")     # 我方（绿）
const TXT_FOE := Color("ffb3b3")      # 敌方（红）
const TXT_POWER := Color("ffd27a")    # 能量 / 力量（金）
const TXT_WARN := Color("ff9a76")     # 警示（手牌满 / 闪躲）
const FX_ENERGY_SPEND := Color("8fb4d8")  # 能量支出飘字（收入复用 TXT_POWER 金）


func _auto_outline(px: int) -> int:
	return clampi(int(round(px / 4.0)), 2, 5)


func _draw_string_box_center(font: Font, px: int, text: String, center: Vector2,
		col: Color, bg := TEXT_BG) -> void:
	## R140：居中 + 背景条。先量文本尺寸铺底，再走 _draw_string_center 写字。
	if px < 7:
		px = 7
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var block_h := font.get_height(px) * float(text.split("\n").size())
	var rect := Rect2(center.x - sz.x * 0.5 - TEXT_BG_PAD_X,
			center.y - block_h * 0.5 - TEXT_BG_PAD_Y,
			sz.x + TEXT_BG_PAD_X * 2.0, block_h + TEXT_BG_PAD_Y * 2.0)
	_text_bg_plate(rect, bg)
	_draw_string_center(font, px, text, center, col)


func _draw_string_box_nw(font: Font, px: int, text: String, pos: Vector2,
		col: Color, bg := TEXT_BG) -> void:
	## R140：左上锚（pos = 首行**基线**，与 _draw_string_nw 同语义）+ 背景条。
	if px < 7:
		px = 7
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var block_h := font.get_height(px) * float(text.split("\n").size())
	var rect := Rect2(pos.x - TEXT_BG_PAD_X, pos.y - font.get_ascent(px) - TEXT_BG_PAD_Y,
			sz.x + TEXT_BG_PAD_X * 2.0, block_h + TEXT_BG_PAD_Y * 2.0)
	_text_bg_plate(rect, bg)
	_draw_string_nw(font, px, text, pos, col)


func _text_bg_plate(rect: Rect2, bg: Color) -> void:
	## 文字底条本体：深色半透明块 + 一圈细亮边（把字从地图底图上托出来）。
	draw_rect(rect, bg, true)
	draw_rect(rect.grow(0.5), Color(TEXT_BG_EDGE.r, TEXT_BG_EDGE.g, TEXT_BG_EDGE.b,
			TEXT_BG_EDGE.a * (bg.a / maxf(0.001, TEXT_BG.a))), false, 1.0)


func _draw_string_center(font: Font, px: int, text: String, center: Vector2, col: Color,
		outline := 0, outline_col := UiTheme.SURFACE) -> void:
	if px < 7:
		px = 7
	# Godot 4 在 width=-1（不换行）时会忽略对齐参数，文字会从 pos 点向右延伸（即左对齐）。
	# 因此这里手动按文本宽度计算偏移，使文字真正以 center 为中心居中。
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := Vector2(center.x - w * 0.5, center.y + px * 0.36)
	# R309（用户口径）：outline 传**负数** = 明确不描边。小字号上 `_auto_outline()` 给 2px，
	# 笔画本来就细，描一圈反而糊成一片（道具栏的「雕像（3）」就是这样看不清的）。
	if outline < 0:
		outline = 0
	elif outline == 0:
		outline = _auto_outline(px)
		outline_col = TEXT_OUTLINE_COL
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
				outline, outline_col)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_string_nw(font: Font, px: int, text: String, pos: Vector2, col: Color,
		outline := 0, outline_col := UiTheme.SURFACE) -> void:
	if px < 7:
		px = 7
	if outline < 0:
		outline = 0            # R309：负数 = 明确不描边
	elif outline == 0:
		outline = _auto_outline(px)
		outline_col = TEXT_OUTLINE_COL
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
				outline, outline_col)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_grid() -> void:
	# R137：「战场」标题挪到 _draw_grid_frame 里画 —— 顶带（36~52）会盖住原位置。
	for row in FieldState.BOARD_ROWS:
		for col in FieldState.BOARD_COLS:
			var rect := _cell_rect(Vector2i(row, col))
			draw_rect(rect, Color(1, 1, 1, 0.02))
			draw_rect(rect, COL_CELL_LINE, false, 1.0)
	# 场地效果（R74）：画在格子底纹之上、单位之下 —— 它不是单位，只是格子上的标记。
	_draw_field_markers()
	# 后排色罩 + 半场分界线
	draw_rect(Rect2(GRID_X, GRID_Y - _grid_scroll, GRID_W, CELL), COL_OPP_BACKROW)
	draw_rect(Rect2(GRID_X, GRID_Y + 5 * CELL - _grid_scroll, GRID_W, CELL), COL_OWN_BACKROW)
	var mid_y := GRID_Y + 3 * CELL - _grid_scroll
	draw_line(Vector2(GRID_X, mid_y), Vector2(GRID_X + GRID_W, mid_y), UiTheme.INK_600, 2.0)
	# 火墙术（9084）：正在燃烧的横行（引擎是唯一数据源，施放方下次回合开始自动熄灭）
	for fw_row in engine.fire_wall_rows():
		var fw_rect := Rect2(GRID_X, GRID_Y + fw_row * CELL - _grid_scroll, GRID_W, CELL)
		draw_rect(fw_rect, Color(1.0, 0.42, 0.10, 0.20))
		draw_rect(fw_rect, Color("ff6a00"), false, 2.0)
		_draw_string_box_center(_font_bold, UiTheme.FS_MICRO, "火墙",
				Vector2(GRID_X + GRID_W - 18, GRID_Y + fw_row * CELL + 11 - _grid_scroll),
				Color("ff9a3c"))
	# 敌我框 + 单位标记
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		var rect := _cell_rect(cell)
		draw_rect(rect, COL_OWN_FRAME if p.owner == GameEngine.SIDE_SELF else COL_ENEMY_FRAME, false, 3.0)
		if p.tapped:
			_draw_string_box_nw(_font_bold, UiTheme.FS_MICRO, "→", rect.position + Vector2(CELL_W - 14, 14), TXT_LIGHT)


func _board_has_pulsing_field() -> bool:
	## 场上**有没有会脉动的场地**（一次性场地）。R83：持续型场地（清泉）是静止的，
	## 只有一个清泉在场上时不需要逐帧重绘 —— 这是 `_process` 里的重绘判据。
	if engine == null or engine.state.field_effects.is_empty():
		return false
	for c: Vector2i in engine.state.field_effects:
		if not GameEngine.is_persistent_field(engine.state.field_at(c)):
			return true
	return false


func _draw_field_markers() -> void:
	## 场地效果标记（R74）：画在格子上的**角标 + 斜纹底**，不是一张卡。
	## 为什么这么画：场地**不是单位**（不能被攻击、不占位），所以不能画成卡面 ——
	## 画成卡面会让玩家以为那是个能被点掉的东西。用「斜纹底 + 右下角小标签」表达
	## 「这格挂着个一次性效果」，斜纹是「陷阱/机关」的通用视觉语汇。
	## 判据直接读 engine.state.field_effects（引擎是唯一数据源）。
	var t := float(_now()) / 1000.0
	for cell: Vector2i in engine.state.field_effects:
		var card: CardData = engine.state.field_at(cell)
		if card == null:
			continue
		var rect := _cell_rect(cell)
		var mine: bool = str(engine.state.field_owner.get(cell, "")) == GameEngine.SIDE_SELF
		# 持续型场地（清泉 8028，R83）用**冷色**（青蓝）+ 静止描边 ——
		# 一次性场地是琥珀/红 + 呼吸描边（=「活的、会被踩爆」）。两族必须一眼能分开：
		# 玩家看到脉动的就知道那是陷阱，看到静止的就知道那是长期挂着的效果区。
		var persistent := GameEngine.is_persistent_field(card)
		var col := (COL_FIELD_PERSIST if persistent
				else (COL_FIELD_SELF if mine else COL_FIELD_FOE))
		# 斜纹底（4 条45° 短线）
		for k in 4:
			var off := float(k) * CELL / 4.0
			draw_line(rect.position + Vector2(off, 0),
					rect.position + Vector2(0, off), Color(col.r, col.g, col.b, 0.30), 2.0)
		draw_rect(rect, col, false, 2.0)
		# 右下角小标签（场地名，缩到能塞进角里）
		var tag := card.card_name
		var px := 10
		while px > 7 and _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > CELL_W - 10.0:
			px -= 1
		_draw_string_box_nw(_font_bold, px, tag, rect.position + Vector2(5, CELL - 6), col)
		# R84：触发类型角标（一次性场地）。「范围伤害」这类标签太长塞不进 6 字宽的角，
		#   缩字号 + 靠左排；清泉是持续型、**没有** trigger，不画这个（别误导成「会被触发」）。
		if not persistent and card.trigger != "":
			var tpx := 9
			while tpx > 6 and _font.get_string_size(card.trigger,
					HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > CELL_W - 8.0:
				tpx -= 1
			_draw_string_box_nw(_font_bold, tpx, card.trigger,
					rect.position + Vector2(4, 13), col)
	# 缓慢呼吸的高亮描边（提示「这是活的、会被触发」）—— 有场地时才需逐帧重绘。
	# ⚠️ **持续型场地不画这个**（R83）：清泉是长期挂着、不会因经过而触发的效果区，
	# 画脉动描边等于骗玩家「走过去它会炸」→ 误导走位。
	if not engine.state.field_effects.is_empty():
		var pulse := (sin(t * 2.2) + 1.0) * 0.5
		for cell2: Vector2i in engine.state.field_effects:
			if GameEngine.is_persistent_field(engine.state.field_at(cell2)):
				continue
			var r2 := _cell_rect(cell2)
			draw_rect(r2, Color(1.0, 0.85, 0.35, 0.10 + pulse * 0.14), false, 2.0)


func _draw_board_cards() -> void:
	# 动画中的单位最后画（浮在其他卡之上）
	var animating: Array = []
	for pair: Array in engine.state.iter_board():
		var cell: Vector2i = pair[0]
		var p: Placement = pair[1]
		if _slides.has(p) or _attacks.has(p):
			animating.append(pair)
			continue
		_draw_board_unit(cell, p)
	for pair2: Array in animating:
		_draw_board_unit(pair2[0], pair2[1])


func _draw_board_unit(cell: Vector2i, p: Placement) -> void:
	var center := _display_center(p, cell)
	var selected: bool = selection != null and selection[0] == "board" and selection[1] == cell
	var w := BOARD_CARD_W
	var h := BOARD_CARD_H
	# R151 P0-4：从手牌飞来的落位动画带缩放回稳（from_scale → 1，与位移同一条 ease-out）
	if _slides.has(p):
		var sl: Dictionary = _slides[p]
		var fs := float(sl.get("from_scale", 1.0))
		if not is_equal_approx(fs, 1.0):
			var n2 := _now()
			if n2 >= int(sl.start):
				var t2 := clampf(float(n2 - int(sl.start)) / int(sl.dur), 0.0, 1.0)
				var sc2 := lerpf(fs, 1.0, 1.0 - pow(1.0 - t2, 3.0))
				w *= sc2
				h *= sc2
	# 顶部状态徽标的行号：嘲讽 → 冰封 → 沉睡，按出现顺序往下排（共用底座 _draw_state_badge）
	var _badge_row := 0
	# R118：`on_board = true` —— 战场卡面的「种类 · 字段」行**不再标出**上场后已无作用的
	# 字段（交换 / 幻影）。判据在 `CardData.affix_on_board()`，这里只负责声明「我在战场上」。
	# 沉睡（恶魔鸭 9116，sleep_left>0）→ 换沉睡专用卡图；其余状态用普通卡图。
	_draw_card_face(p.card, Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			_show_hp(p, p.health), selected, false, -1, p.effective_power(), true,
			p.sleep_left > 0)
	# R165：移除「横置」视觉——不再把卡转横。改用青色**就绪光环**标明「可行动」：
	# 凡本回合还有行动权（未横置）的单位都亮脉动环（敌我同标），以此区分不能动的卡。
	if not p.tapped:
		_draw_ready_aura(center, w, h)
	if engine.absorbs_for_hp(p):
		# 替己方 HP 承伤的统一表现（森林守护 9037 / 以太守卫 9067 / 铁栅栏 9072）：
		# 判定直接问引擎 absorbs_for_hp()，保证「同一机制 = 同一特效」，不再各写各的。
		draw_arc(center, Vector2(w, h).length() * 0.5, 0, TAU, 30, COL_GUARD, 2.5)
	if p.card.traits.has(GameEngine.TAUNT_TRAIT):
		# 嘲讽（铁壁卫兵 1011 / 骷髅兵 1055）：脉冲橙环 + 「嘲讽」徽标，
		# 让「射程内有它就必须打它」这件事在战场上一眼可见。
		_draw_taunt_aura(center, w, h, 0)
		_badge_row = 1
	if p.frozen:
		# 冰封（R68：寒冰箭 9011 / 冰冻术士战吼 / 冻结陷阱 8013）：
		# 「下回合不能行动」是**看卡面看不出来**的隐藏状态 → 必须常驻可见。
		_draw_frozen_aura(center, w, h, _badge_row)
		_badge_row += 1
	if p.sleep_left > 0:
		# 沉睡（R63/R72 补特效；R76 改口径）：恶魔鸭 9116 初始沉睡 2，
		# 每挨一下 -1、**归零立刻恢复行动**。徽标写出「还差几下」而不是「几回合」。
		_draw_sleep_aura(center, w, h, p.sleep_left, _badge_row)
		_badge_row += 1
	if p.fuse_left > 0:
		# 铸造倒计时（量产型赫卡同克瑞斯 9133，R149）：**还剩几个我方回合就会变成钢铁要塞**
		# 是看卡面看不出来的隐藏状态 → 必须常驻可见，而且要写出**数字**：光写「铸造」
		# 等于把「还能拖几回合 / 要不要现在就拆」这个决策藏起来（与「沉睡 N」同一套路）。
		_draw_fuse_aura(center, w, h, p.fuse_left, _badge_row)
		_badge_row += 1
	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。
		# 徽标同样交给字段系统（字段「护盾」），这里只留**呼吸青环**提示「还剩一次」——
		# 护盾是**隐藏状态**（卡面不写、图标上看不出来），必须有常驻可见提示。
		var sh_t := float(_now()) / 1000.0
		var sh_pulse := (sin(sh_t * 3.0) + 1.0) * 0.5
		var sh_r := Vector2(w, h).length() * 0.5 + 2.0 + sh_pulse * 2.5
		draw_arc(center, sh_r, 0.0, TAU, 40,
				Color(0.50, 0.84, 0.94, 0.40 + sh_pulse * 0.30), 2.0)
	# R142：**可以主动发动**的我方单位（熊 8004「回春」）—— 原来的提示只有
	# 「选中它之后状态栏写一句」，没选中就等于看不见。这里加一层**常驻**的
	# 亮黄绿脉动环 + 四向指向卡面的内箭头 + 顶部「可发动 F」徽标。
	# ⚠️ 判据走引擎的 `can_activate`（与「再点一次」/ 按 F 完全同源），不在这里重判 traits；
	#    **只标我方**：敌人也可能能发动，但玩家点不动它，标成「按 F」是误导。
	if p.owner == GameEngine.SIDE_SELF and engine.can_activate(cell, GameEngine.SIDE_SELF):
		_draw_activatable_aura(center, w, h, _badge_row)
		_badge_row += 1
	# 【字段系统 R91】把这张卡**此刻生效**的字段逐个画在卡上方（轮流显示 = 依次往下排）。
	# ⚠️ **不硬编码任何字段**：判据是 `CardData.active_affixes()`，它读 `card.affixes`
	# 并按场上实况过滤（疾行用掉一轮就不显示、护盾用掉就不显示）。
	# 于是「过载给这张牌加了疾行」「能量屏障给了护盾」这类**后续赋予**的字段
	# 也会自动出现在战场上 —— 不需要在这里为每个字段写一段。
	_badge_row = _draw_affix_badges(center, w, h, p, _badge_row)
	# 【R106】最上面再叠「已获得的增益 / 减益」摘要（限量）：完整逐条列表在左侧信息栏。
	_draw_status_badges(center, w, h, p, _badge_row)


## 字段徽标（R91）：把 `p.card` 此刻生效的字段逐个画成顶部徽标。
## **「轮流显示」= 按顺序用 `_badge_row` 往下错开**，与冰封 / 沉睡 共用同一个底座
## （`_draw_state_badge`）—— 徽标多了不会互相盖住。
## 返回**下一个可用的 row**（调用方接着往下排）。
func _draw_affix_badges(center: Vector2, w: float, h: float, p: Placement,
		start_row: int) -> int:
	var row := start_row
	if p.card == null:
		return row
	for a in p.card.active_affixes(p.acts_left, p.first_hit_shield):
		# 嘲讽已经有脉冲橙环 + 徽标（`_draw_taunt_aura`），不重复画文字徽标。
		if a == GameEngine.AFFIX_TAUNT:
			continue
		var cols: Array = CardData.affix_colors(a)
		_draw_state_badge(center, w, h, row, CardData.affix_label(a),
				cols[0], cols[1], cols[1], Color(0.02, 0.02, 0.02, 0.75))
		row += 1
	return row


func _draw_status_badges(center: Vector2, w: float, h: float, p: Placement,
		start_row: int) -> void:
	## 【R106】把这张卡**已获得**的增益 / 减益摘要画成顶部徽标。
	## 数据来自 `Placement.status_badges()`（与信息栏的逐条列表同源），只挑最要紧的几项，
	## 并且**限量** MAX_STATUS_BADGES 条 —— 徽标是往上叠的，多了会盖住上面一行的卡。
	if p == null or p.card == null:
		return
	var row := start_row
	var shown := 0
	for b in p.status_badges():
		if shown >= MAX_STATUS_BADGES:
			break
		var col: Color = b["col"]
		_draw_state_badge(center, w, h, row, str(b["text"]),
				Color(col.r * 0.20, col.g * 0.20, col.b * 0.20, 0.90), col,
				Color(1, 1, 1, 0.96), Color(0.04, 0.04, 0.04, 0.72))
		row += 1
		shown += 1


func _draw_frozen_aura(center: Vector2, w: float, h: float, badge_row: int) -> void:
	## 冰封特效（`Placement.frozen` 的唯一表现口）：冷蓝双环脉冲 + 顶部「冰封」徽标
	## + 卡面覆一层寒霜。判据直接读 `p.frozen`，保证「同一状态 = 同一特效」。
	## 与「禁足 rooted」（只是不能移动、仍可攻击）刻意做出形状差异，避免玩家看混。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 2.6) + 1.0) * 0.5                 # 0..1 呼吸（比嘲讽慢）
	var base := Vector2(w, h).length() * 0.5
	# 卡面寒霜：半透明白蓝薄纱（tapped 时更明显，因为那时它真的动不了）
	draw_rect(Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			Color(0.62, 0.84, 1.0, 0.16 + pulse * 0.10), true)
	# 双环：内环贴卡、外环外扩，冷蓝 → 近白
	var r1 := base + 1.0 + pulse * 2.0
	draw_arc(center, r1, 0.0, TAU, 44,
			Color(COL_FROZEN.r, COL_FROZEN.g, COL_FROZEN.b, 0.55 + pulse * 0.35), 2.5)
	draw_arc(center, r1 + 4.0, 0.0, TAU, 44,
			Color(0.85, 0.95, 1.0, 0.22 + pulse * 0.22), 1.5)
	# 四角冰晶：短斜线，随呼吸伸缩
	var arm := 5.0 + pulse * 3.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := center + Vector2(w / 2.0 * sx, h / 2.0 * sy)
			var dir := Vector2(-sx, 0.0)
			var dir2 := Vector2(0.0, -sy)
			draw_line(corner, corner + dir * arm, Color(0.88, 0.97, 1.0, 0.75), 2.0)
			draw_line(corner, corner + dir2 * arm, Color(0.88, 0.97, 1.0, 0.75), 2.0)
	_draw_state_badge(center, w, h, badge_row, "冰封",
			Color(0.04, 0.16, 0.30, 0.92), COL_FROZEN,
			Color(0.90, 0.98, 1.0), Color(0.02, 0.09, 0.18))


func _draw_sleep_aura(center: Vector2, w: float, h: float, left: int, badge_row: int) -> void:
	## 沉睡特效（`Placement.sleep_left` 的唯一表现口）：**紫色**脉冲环（与冰封的冷蓝
	## 明显区分）+ 卡面暗紫薄纱 + 右上角飘「Zzz」+ 顶部「沉睡 N」徽标。
	## 徽标**写出还剩几点**是刻意的：沉睡的代价是「白站几回合」，R122 起
	## 「自己回合结束 -1」和「每次受伤 -1」两条都会减它，
	## 玩家得能一眼判断「现在打它值不值」（R76：每挨一下沉睡 -1、打空立刻能行动），
	## 光写「沉睡」等于把这个决策藏起来。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 1.7) + 1.0) * 0.5                # 0..1 呼吸（比冰封更慢 = 睡得更沉）
	var base := Vector2(w, h).length() * 0.5
	draw_rect(Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			Color(0.42, 0.24, 0.70, 0.18 + pulse * 0.10), true)
	var r1 := base + 2.0 + pulse * 2.5
	draw_arc(center, r1, 0.0, TAU, 44,
			Color(COL_SLEEP.r, COL_SLEEP.g, COL_SLEEP.b, 0.50 + pulse * 0.35), 2.5)
	draw_arc(center, r1 + 5.0, 0.0, TAU, 44,
			Color(0.86, 0.76, 1.0, 0.20 + pulse * 0.20), 1.5)
	# 「Zzz」：三个字母依次向上飘并淡出（相位错开），卡在右上角内侧。
	for i in 3:
		var ph := fposmod(t * 0.55 - float(i) * 0.33, 1.0)
		var zpos := center + Vector2(w / 2.0 - 12.0 - float(i) * 3.0,
				-h / 2.0 + 14.0 - ph * 22.0)
		var za := (1.0 - ph) * 0.9
		var zs := 13 - i * 2
		_draw_string_center(_font_bold, zs, "Z", zpos,
				Color(0.90, 0.82, 1.0, za), 2, Color(0.20, 0.10, 0.34, za * 0.8))
	_draw_state_badge(center, w, h, badge_row, "沉睡 %d" % left,
			Color(0.13, 0.07, 0.24, 0.92), COL_SLEEP,
			Color(0.93, 0.86, 1.0), Color(0.08, 0.04, 0.16))


func _draw_fuse_aura(center: Vector2, w: float, h: float, left: int, badge_row: int) -> void :
	## 铸造倒计时（`Placement.fuse_left` 的唯一表现口）：橙红脉冲环 + 顶部「倒数 N」徽标。
	## 徽标**写出还剩几回合**是刻意的：玩家要靠它判断「先拆它还是先处理别的」。
	## ⚠️ 颜色刻意与嘲讽（STATE_TAUNT 橙 ff8f00）拉开：钢铁要塞身上两个状态会同时出现。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 4.0) + 1.0) * 0.5                # 0..1（比沉睡快 = 更「催」）
	var base := Vector2(w, h).length() * 0.5
	draw_arc(center, base + 2.0 + pulse * 2.5, 0.0, TAU, 40,
			Color(COL_FUSE.r, COL_FUSE.g, COL_FUSE.b, 0.45 + pulse * 0.40), 2.5)
	_draw_state_badge(center, w, h, badge_row, "倒数 %d" % left,
			Color(0.28, 0.09, 0.03, 0.92), COL_FUSE,
			Color(1.0, 0.93, 0.86), Color(0.16, 0.05, 0.02))


func _draw_state_badge(center: Vector2, w: float, h: float, row: int, text: String,
		bg: Color, border: Color, fg: Color, shadow: Color) -> void:
	## 战场单位顶部**状态徽标**的共用底座：嘲讽 / 冰封 / 沉睡三者位置完全相同，
	## 靠 `row`（第几个状态）往下错开 —— 各自算偏移早晚会在「三状态同时成立」时重叠，
	## 重叠 = 既有信息被盖掉，等于没显示。row 0 压在卡上沿（半内半外），
	## 之后每个往下挪一个徽标高。
	var bw := maxf(40.0, 14.0 + float(text.length()) * 11.0)
	var bh := 19.0
	var badge := Rect2(center + Vector2(-bw / 2.0,
			-h / 2.0 - bh * 0.45 + float(row) * (bh + 2.0)), Vector2(bw, bh))
	draw_rect(badge, bg, true)
	draw_rect(badge, border, false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_CAPTION, text, badge.position + badge.size / 2.0, fg, 3, shadow)


func _draw_taunt_aura(center: Vector2, w: float, h: float, badge_row: int) -> void:
	## 嘲讽特效：外圈脉冲光环 + 顶部「嘲讽」徽标 —— 敌方单位射程内有它就必须打它。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 3.4) + 1.0) * 0.5                  # 0..1 呼吸
	var base := Vector2(w, h).length() * 0.5
	var r := base + 3.0 + pulse * 5.0
	var a := 0.50 + pulse * 0.45
	draw_arc(center, r, 0.0, TAU, 48, Color(COL_TAUNT.r, COL_TAUNT.g, COL_TAUNT.b, a), 3.5)
	draw_arc(center, r + 5.0, 0.0, TAU, 48,
			Color(1.0, 0.78, 0.35, a * 0.40), 1.5)
	# 顶部徽标
	_draw_state_badge(center, w, h, badge_row, "嘲讽",
			Color(0.20, 0.11, 0.02, 0.92), Color(1.0, 0.62, 0.12, 0.95),
			Color(1.0, 0.84, 0.40), Color(0.12, 0.06, 0.01))


func _draw_activatable_aura(center: Vector2, w: float, h: float, badge_row: int) -> void:
	## 可主动发动特效（R142）：**黄绿双环脉动 + 四向指向卡面的内箭头 + 「可发动 F」徽标**。
	## 为什么不用又一个纯色圆环：嘲讽（橙）/ 冰封（冷蓝）/ 沉睡（紫）/ 屏障（青）已经把
	## 圆环用满了，再来一个只能靠颜色区分；箭头是**动作**语义（「点它 / 按 F」），
	## 形状上就和那四种「状态」分开 —— 瞄一眼就知道这张卡现在还能操作。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 5.0) + 1.0) * 0.5                # 0..1（比嘲讽 3.4 更快 = 更「催」）
	var base := Vector2(w, h).length() * 0.5
	var r1 := base + 1.0 + pulse * 3.0
	draw_arc(center, r1, 0.0, TAU, 48,
			Color(COL_ACTIVATABLE.r, COL_ACTIVATABLE.g, COL_ACTIVATABLE.b, 0.55 + pulse * 0.40), 3.0)
	# 外环：四段短弧随时间绕着转（相位错开 = 「在等你操作」的转动感，不引入新素材）
	var spin := fposmod(t * 0.9, 1.0) * TAU
	for i in 4:
		var a0 := spin + float(i) * TAU / 4.0
		draw_arc(center, r1 + 5.0, a0, a0 + 0.55, 8,
				Color(0.96, 1.0, 0.72, 0.30 + pulse * 0.35), 2.0)
	# 四向内箭头：箭头指向卡面中心 = 「对它做点什么」
	var arm := 4.0 + pulse * 3.5
	var rr := base + 7.0
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d: Vector2 in dirs:
		var tip := center + d * rr
		var back := tip - d * arm
		var side := Vector2(-d.y, d.x) * (arm * 0.45)
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
				Color(COL_ACTIVATABLE.r, COL_ACTIVATABLE.g, COL_ACTIVATABLE.b, 0.55 + pulse * 0.40))
	_draw_state_badge(center, w, h, badge_row, "可发动 F",
			Color(0.08, 0.20, 0.06, 0.94), COL_ACTIVATABLE,
			Color(0.94, 1.0, 0.82), Color(0.02, 0.10, 0.02))


func _draw_ready_aura(center: Vector2, w: float, h: float) -> void:
	## R165：「可行动」就绪光环（敌我同标）—— 取代被移除的「横置」表现。
	## 亮青脉动双环 + 光晕，和黄绿「可发动 F」主动技环区分开（「还能动」≠「能发动技能」）。
	## 画在其它状态环之前 → 在最底层。要**明显**（用户口径）：亮、粗、带光晕，
	## 在绿色战场底上也一眼能认出「这张还能动」。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 3.2) + 1.0) * 0.5
	var base := Vector2(w, h).length() * 0.5
	var r1 := base + 3.0 + pulse * 3.0
	draw_arc(center, r1, 0.0, TAU, 48,
			Color(COL_READY.r, COL_READY.g, COL_READY.b, 0.46 + pulse * 0.44), 4.0)
	var r2 := r1 + 5.5 + pulse * 2.5
	draw_arc(center, r2, 0.0, TAU, 48,
			Color(COL_READY.r, COL_READY.g, COL_READY.b, 0.16 + pulse * 0.20), 2.5)
	draw_arc(center, base + 1.5, 0.0, TAU, 48,
			Color(0.85, 0.97, 1.0, 0.20 + pulse * 0.30), 1.5)


func _board_has_activatable() -> bool:
	## 棋盘上是否有「我方现在就能主动发动」的单位 —— 那层环与内箭头是脉冲动画，
	## 需要逐帧重绘（R142）。判据与绘制同源（都走 `engine.can_activate`）。
	if engine == null:
		return false
	for c: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[c]
		if p != null and p.owner == GameEngine.SIDE_SELF \
				and engine.can_activate(c, GameEngine.SIDE_SELF):
			return true
	return false


func _board_has_actable() -> bool:
	## R165：棋盘上是否有「本回合还能行动」的单位（未横置）—— 就绪光环是脉冲动画，
	## 需要逐帧重绘。判据与绘制同源（都看 `p.tapped`）。
	if engine == null:
		return false
	for c: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[c]
		if p != null and not p.tapped:
			return true
	return false


func _board_has_taunt() -> bool:
	## 棋盘上是否有带「嘲讽」的单位（有 → _process 需要逐帧重绘来驱动脉冲）。
	for cell: Vector2i in engine.state.board:
		if engine.state.board[cell].card.traits.has(GameEngine.TAUNT_TRAIT):
			return true
	return false


func _board_has_shield() -> bool:
	## 棋盘上是否有带「能量屏障」（首次受伤免掉）护盾的单位 —— 护盾环是脉冲动画，
	## 需要逐帧重绘（R87）。判据读 `Placement.first_hit_shield`。
	if engine == null:
		return false
	for _c: Vector2i in engine.state.board:
		if engine.state.board[_c].first_hit_shield:
			return true
	return false


func _board_has_frozen() -> bool:
	## 棋盘上是否有被冰封的单位（冰封环是脉冲动画 → 需要逐帧重绘）。
	for _cell: Vector2i in engine.state.board:
		if engine.state.board[_cell].frozen:
			return true
	return false


func _board_has_sleep() -> bool:
	## 棋盘上是否有沉睡中的单位（沉睡环 + 飘 Zzz 是动画 → 需要逐帧重绘）。
	for _cell: Vector2i in engine.state.board:
		if engine.state.board[_cell].sleep_left > 0:
			return true
	return false


func _board_has_fuse() -> bool:
	## 棋盘上是否有「铸造倒计时」中的单位（脉冲环是动画 → 需要逐帧重绘）。
	## 判据读 `Placement.fuse_left`，与绘制同源（R149）。
	if engine == null:
		return false
	for _cell: Vector2i in engine.state.board:
		if engine.state.board[_cell].fuse_left > 0:
			return true
	return false


func _draw_dying() -> void:
	## 垂死卡：引擎已把它移出场，但为了让「先受伤害 → 再消失」的次序看得见，
	## 在命中演出结束前仍在原位把它画出来（叠一层淡红表示已归零）。
	for d: Dictionary in _dying:
		var cell: Vector2i = d.cell
		var center := _cell_center(cell)
		var rect := Rect2(center - Vector2(BOARD_CARD_W, BOARD_CARD_H) / 2.0,
				Vector2(BOARD_CARD_W, BOARD_CARD_H))
		_draw_card_face(d.card as CardData, rect, 0, false, false)
		draw_rect(rect, Color(0.85, 0.12, 0.1, 0.30))


# ------------------------------------------------------------ 动画


func _now() -> int:
	return Time.get_ticks_msec()


func _pulse_redraw() -> void:
	## R180：脉冲动画节流重绘。呼吸/脉动类光环不逐帧 queue_redraw，而是按
	## `PULSE_FRAME_MS` 降频 —— 这些动画的相位都基于 `_now()`（重绘时自动取当前相位），
	## 降频只是降采样、不会「卡住」，22fps 对 0.5s 周期的呼吸动画视觉上依然平滑。
	## 安卓 GL Compatibility 上这是「越打越卡」的关键缓解：己方回合 `_board_has_actable()`
	## 恒真、棋盘 `_grid_scrollable()` 恒真，原来每帧触发全量 `_draw`（80+ 子绘制）。
	if _pulse_ms <= 0:
		# R187：安卓再把脉冲窗口 ×2（45→90ms，11fps 采样呼吸动画仍连续）——
		# 稳态下全量 _draw 再砍一半。⚠️ OS 门控：PC 端保持 45ms 原样，行为零变化。
		_pulse_ms = PULSE_FRAME_MS * (2 if OS.get_name() == "Android" else 1)
	var n := _now()
	if n < _pulse_redraw_at:
		return
	_pulse_redraw_at = n + _pulse_ms
	queue_redraw()


func _anim_end_for(p: Placement, cap_ms := 900) -> int:
	## 该单位身上「已排队动画」的结束时刻 —— 新动作排到它后面，避免后一个动作
	## 把前一段演出整段吞掉（AI 一步内连做移动+攻击时最明显）。
	## 上限 cap_ms：多动单位连续行动时不让队列越积越长，最多推迟这么久。
	var n0 := _now()
	var until := n0
	if _slides.has(p):
		var s: Dictionary = _slides[p]
		until = maxi(until, int(s.start) + int(s.dur))
	if _attacks.has(p):
		var a0: Dictionary = _attacks[p]
		until = maxi(until, int(a0.start) + int(a0.dur))
	return mini(until, n0 + cap_ms)


func _freeze_hp(key: Variant, dmg: int) -> void:
	## 记录一笔「尚未在命中演出中体现」的伤害：卡面 / HP 横幅数字冻结在扣血前，
	## 等对应的 hit / hp_hit 定时特效触发才移除这一笔，数字才往下掉。
	if dmg <= 0:
		return
	if not _hp_pending.has(key):
		_hp_pending[key] = []
	(_hp_pending[key] as Array).append(dmg)


func _show_hp(key: Variant, actual: int) -> int:
	## 取某把「卡面 / HP 横幅」的显示数字：实际值 + 尚未演出的伤害之和（即扣血前的值）。
	if not _hp_pending.has(key):
		return actual
	var s := 0
	for x in (_hp_pending[key] as Array):
		s += int(x)
	return actual + s


func _drop_hp(key: Variant) -> void:
	## 命中演出到点：移除最早一笔待扣伤害（数字自此开始往下掉）。
	if not _hp_pending.has(key):
		return
	var arr: Array = _hp_pending[key] as Array
	if not arr.is_empty():
		arr.pop_front()
	if arr.is_empty():
		_hp_pending.erase(key)


func _display_center(p: Placement, cell: Vector2i) -> Vector2:
	## 单位当前显示位置：静态格心 / 滑动插值 / 攻击突进。
	## 只认「已开始」的那一段：排队中的动画（start 未到）不参与，
	## 否则它会盖住正在播的动作，看起来就是「一闪而过」。
	var base := _cell_center(cell)
	var n := _now()
	if _slides.has(p):
		var a: Dictionary = _slides[p]
		if n >= int(a.start):
			var t := clampf(float(n - int(a.start)) / int(a.dur), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - t, 3.0)  # ease-out
			# R171：创建后棋盘又滚过 → from/to/pts 里的像素位置已过期，按滚动差补回。
			# from_grid=false 时 from 是手牌屏位（不随棋盘滚）→ 只补「到格端」，
			# 补正量随插值权重 e 渐进生效（t=1 时正好落在当前格心，无瞬移）。
			var dy := _scroll_dy(float(a.get("sc", _grid_scroll)))
			var pts: Array[Vector2] = []
			if a.has("pts"):
				pts = a.get("pts", [])
			if pts.size() < 2:
				if bool(a.get("from_grid", true)):
					return (a.from as Vector2).lerp(a.to as Vector2, e) + dy
				return (a.from as Vector2).lerp((a.to as Vector2) + dy, e)
			# 逐格路径：整段按格数均分，每格内部单独 ease-out（看起来是一格一格走过去）
			var segs := pts.size() - 1
			var f := t * segs
			var si := mini(int(floor(f)), segs - 1)
			var e2 := 1.0 - pow(1.0 - clampf(f - si, 0.0, 1.0), 3.0)
			return pts[si].lerp(pts[si + 1], e2) + dy
	if _attacks.has(p):
		var l: Dictionary = _attacks[p]
		if n >= int(l.start):
			var t2 := clampf(float(n - int(l.start)) / int(l.dur), 0.0, 1.0)
			var adir := l.dir as Vector2
			var asrc := l.src as Vector2
			var is_hp := str(l.get("kind", "unit")) == "hp"
			# 攻击者原地演出：后仰蓄力 → 发射时前倾后坐 → 缓缓回正（弹体负责飞行）
			# 直击 HP 是「冲锋撞击」：没有弹体，前冲幅度更大、撞击感更强。
			var back := -24.0 if is_hp else -22.0
			var push := 30.0 if is_hp else 10.0
			var off := 0.0
			if t2 < ATK_LAUNCH_T:
				var k := clampf((t2 - ATK_WINDUP_T) / (ATK_LAUNCH_T - ATK_WINDUP_T), 0.0, 1.0)
				off = back * sin(k * PI * 0.5)           # 后仰蓄力
			elif t2 < ATK_IMPACT_T:
				var k2 := (t2 - ATK_LAUNCH_T) / (ATK_IMPACT_T - ATK_LAUNCH_T)
				off = lerpf(back, push, minf(k2 * 2.2, 1.0))   # 冲上去撞击
			else:
				var k3 := (t2 - ATK_IMPACT_T) / (1.0 - ATK_IMPACT_T)
				off = push * (1.0 - (1.0 - pow(1.0 - k3, 2.0)))  # 缓缓回正
			return asrc + adir * off + _scroll_dy(float(l.get("sc", _grid_scroll)))
	return base


func _tick_earring_autoplay() -> bool:
	## 鸭语耳环自动出牌的**逐张播放**驱动（R77 唯一口）：每 `_earring_gap` 毫秒推进一步。
	## 返回 true = 还在播（界面要继续逐帧重绘、且玩家操作应被锁住）。
	if engine == null or not engine.earring_autoplay_active():
		return false
	var n := _now()
	if n - _earring_at < _earring_gap:
		return true
	_earring_at = n
	# 推进一步（引擎在 _autoplay_step 里真的出牌，并发 earring_autoplay_step 事件）
	engine._autoplay_step(_earring_i)
	_earring_i += 1
	return true


static func _hand_diff(old: Array, cur: Array) -> Dictionary:
	## 手牌差异（R157）：LCS 最长公共子序列 —— **同 id 重复卡也各归各位**。
	## 旧的保序双指针在重复 id 时必然错配：[A,B,A] 打出首张 A → B 被误判「新增」
	## （播抽卡飞入）、尾张 A 被判移除 —— 「用一张卡，其它卡播放抽卡动画」的病灶。
	## LCS 取**最长**匹配 → 增删条目最少且唯一确定。手牌 ≤ 12 张，O(n·m) 可忽略。
	## 返回 {"removed": [{id, idx}], "added": [{id, idx}]}（idx 各属旧/新数组）。
	var n := old.size()
	var m := cur.size()
	var dp: Array = []
	dp.resize(n + 1)
	for i in n + 1:
		var row: Array = []
		row.resize(m + 1)
		row.fill(0)
		dp[i] = row
	for i in range(n - 1, -1, -1):
		for j in range(m - 1, -1, -1):
			if old[i] == cur[j]:
				dp[i][j] = int(dp[i + 1][j + 1]) + 1
			else:
				dp[i][j] = maxi(int(dp[i + 1][j]), int(dp[i][j + 1]))
	var removed: Array = []
	var added: Array = []
	var i2 := 0
	var j2 := 0
	while i2 < n and j2 < m:
		if old[i2] == cur[j2]:
			i2 += 1
			j2 += 1
		elif int(dp[i2 + 1][j2]) >= int(dp[i2][j2 + 1]):
			removed.append({"id": old[i2], "idx": i2})
			i2 += 1
		else:
			added.append({"id": cur[j2], "idx": j2})
			j2 += 1
	while i2 < n:
		removed.append({"id": old[i2], "idx": i2})
		i2 += 1
	while j2 < m:
		added.append({"id": cur[j2], "idx": j2})
		j2 += 1
	return {"removed": removed, "added": added}


func _hand_sync() -> void:
	## R151 P0-1/2：手牌差异 → 抽牌飞入 / 弃牌·消耗飞出（每帧调用）。
	## R157：diff 改走 `_hand_diff`（LCS）—— 重复 id 卡不再错配（旧双指针 [A,B,A] 打 A → B 误播抽卡）。
	if engine == null:
		return
	var cur: Array = []
	for c in engine.state.hand:
		cur.append(c.id)
	if not _hand_known_init:
		_hand_known = cur
		_hand_known_init = true
		_void_known = engine.state.void_count
		# R151 P0-3：新一场战斗的滚动从「当前实际值」起锚（UiRoll 是 static 跨场景共享，
		# 不起锚会从上一场的残值滚过来 —— 观感 = 血条空降 / 能量乱跳）
		UiRoll.snap("hp_self", engine.state.hp_self)
		UiRoll.snap("hp_opp", engine.state.hp_opponent)
		UiRoll.snap("hp_self_bar", engine.state.hp_self)
		UiRoll.snap("hp_opp_bar", engine.state.hp_opponent)
		UiRoll.snap("energy", engine.state.energy)
		UiRoll.snap("opp_energy", engine.state.opp_energy)
		_energy_known = engine.state.energy
		return
	if cur == _hand_known:
		_flyout_skip.clear()
		_flyin_skip.clear()
		_flyout_skip_all = false
		_void_known = engine.state.void_count
		return
	var old_n := _hand_known.size()
	# R157：diff 走 LCS 纯函数（重复 id 不错配；回归可直接调 _hand_diff 验证）
	var d: Dictionary = _hand_diff(_hand_known, cur)
	var removed: Array = d["removed"]   # {id, idx}（旧数组下标）
	var added: Array = []               # {card, idx}（新数组下标）
	for a: Dictionary in d["added"]:
		added.append({"card": engine.state.hand[int(a["idx"])], "idx": int(a["idx"])})
	_hand_known = cur
	var vd: int = engine.state.void_count - _void_known   # 这段时间被「消耗」的张数
	_void_known = engine.state.void_count
	if _shot_pending:
		# 探针 / 演示钉帧：只维护快照、不播（否则 --shotframe 会截到飞行中的卡）
		_flyout_skip.clear()
		_flyin_skip.clear()
		_flyout_skip_all = false
		_earring_missed = 0
		return
	var n := _now()
	# 新增 → 卡背从抽牌堆飞入手牌位（逐张错开 60ms）
	var seq := 0
	for a in added:
		var card: CardData = a["card"]
		if _flyin_skip.has(card.id):
			_flyin_skip.erase(card.id)
			continue
		_hand_fly.append({"mode": "in", "card": card,
				"from": Vector2(DECK_X + CARD_W / 2.0, DECK_Y + CARD_H / 2.0),
				"slot": int(a["idx"]), "start": n + 60 * seq, "dur": 260})
		seq += 1
	# 移除 → 默认飞弃牌区；消耗的份额（void 增量）改上飞；skip 名单 / 耳环连出不播
	var earring := engine.earring_autoplay_active()
	for r0 in removed:
		var rid := int(r0["id"])
		if _flyout_skip_all:
			continue
		if _flyout_skip.has(rid):
			_flyout_skip.erase(rid)
			if earring:
				_earring_missed += 1
			continue
		if earring:
			_earring_missed += 1
			continue
		var card: CardData = repo.get_card(rid) if repo != null else null
		if card == null:
			continue
		var mode := "out_d"
		if vd > 0:
			mode = "out_v"
			vd -= 1
		_hand_fly.append({"mode": mode, "card": card,
				"from_rect": _hand_old_rect(old_n, int(r0["idx"])),
				"start": n, "dur": 220})
	_flyout_skip.clear()
	_flyin_skip.clear()
	_flyout_skip_all = false


func _hand_old_rect(n: int, idx: int) -> Rect2:
	## 移除发生前、手牌还是 n 张时第 idx 张的未旋转矩形（飞出动画起点；与 _hand_rect 同一套扇形数学）。
	var step := _hand_step(n)
	var total: float = step * (n - 1) + HAND_CARD_W
	var x: float = (WINDOW_W - total) / 2 + step * idx
	var kk := 0.0
	if n > 1:
		kk = (float(idx) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)
	return Rect2(x, OWN_HAND_Y + HAND_FAN_DROP * kk * kk, HAND_CARD_W, HAND_CARD_H)


func _hand_fly_in_slot(i: int) -> bool:
	## 第 i 张手牌是否还在飞入中（在 → 静态卡不画，由 _draw_hand_fly 画卡背）。
	var n := _now()
	for f in _hand_fly:
		if str(f["mode"]) == "in" and int(f["slot"]) == i and n - int(f["start"]) < int(f["dur"]):
			return true
	return false


func _energy_tick() -> void:
	## R151 P0-3：能量变化量飘字（打出 −N / 回合重置 +N）；滚动数字本身走 _roll（UiRoll）。
	if engine == null:
		return
	if _shot_pending:
		_energy_known = engine.state.energy
		return
	var e := engine.state.energy
	if _energy_known >= 0 and e != _energy_known:
		var d := e - _energy_known
		var sign := "+" if d > 0 else ""
		_floaters.append({"pos": Vector2(COST_X + (TAP_W + 12) / 2.0, COST_Y + 30),
				"text": "%s%d 能量" % [sign, d],
				"col": TXT_POWER if d > 0 else FX_ENERGY_SPEND, "size": 15,
				"start": _now(), "dur": 900})
	_energy_known = e


func _roll(key: String, target: float) -> int:
	## P0-3：探针钉帧（--screenshot/--demo）直接钉死、不出中间值；否则走滚动唯一口。
	if _shot_pending:
		UiRoll.snap(key, target)
		return roundi(target)
	return roundi(UiRoll.value(key, target))


# ── R288：通用效果演出（cue）＋ 镜头跟随 ─────────────────────────────
# 目标：让「一张卡发动了效果」这件事本身可见 —— 卡身脉冲 → 卡名标签 →
# 光带指向受影者；发动者与受影者不在同一屏时，镜头**依次**滚到它们身上
# （每个镜头段 CUE_MS，不共用同一个短窗口，所以两边都来得及看清）。

static func row_in_view(row: int, scroll: float) -> bool:
	## 这一行在给定滚动量下是否**完整落在棋盘可视窗**内（R288，纯函数）。
	var top := float(row) * CELL - scroll
	return top >= -1.0 and top + CELL <= GRID_H + 1.0


static func cue_scroll_for(rows: Array) -> float:
	## 让这些行**同时可见**所需的滚动量；放不下（跨度 > 可视窗）时只保证第一行居中。
	## 纯函数（只读棋盘常量）→ 回归可以直接钉，不需要造一个战场实例。
	var lo := 99
	var hi := -1
	for r in rows:
		lo = mini(lo, int(r))
		hi = maxi(hi, int(r))
	if hi < 0:
		return -1.0
	var span := float(hi - lo + 1) * CELL
	if span <= GRID_H:
		return clampf(float(lo) * CELL - (GRID_H - span) * 0.5,
				_grid_scroll_min(), _grid_scroll_max())
	return clampf(float(lo) * CELL + CELL * 0.5 - GRID_H * 0.5,
			_grid_scroll_min(), _grid_scroll_max())


func _cue_dur() -> int:
	## 当前这条演出的总时长：每个镜头段各占 CUE_MS，不共用一个短窗口。
	return CUE_MS * maxi(1, _cue_shots.size())


func _push_cue(cells: Array, label: String, col: Color,
		src := Vector2i(-1, -1)) -> void:
	## 收一条通用演出（R288 唯一入口）。出图模式不排队（否则 --shotframe 时序全乱）；
	## 积压时只留最近 8 条，避免一次大结算把队列撑成十几秒。
	##
	## R321（用户口径）：`src` = **发动者**格。
	##   * 给了（`card_pulse` 那条路，典型是「远古虚骨龙」原地吐息）→ 脉冲 + 光带 + 拉镜头；
	##   * 没给（`fx_impact` 通用受击 / 陷阱 / 反伤 / 各种被动）→ 只在受影者那格画落点环。
	##     这些伤害要么本来就有专属动作（普通攻击的卡牌位移），要么根本不知道该算谁打的，
	##     再补一条激光 + 挪镜头就是纯干扰。
	if _shot_pending and not _cue_demo:
		return
	var uniq: Array = []
	for c in cells:
		if c is Vector2i and (c as Vector2i).x >= 0 and not uniq.has(c):
			uniq.append(c)
	if uniq.is_empty():
		return
	var rows: Array = []
	for c: Vector2i in uniq:
		if not rows.has(c.x):
			rows.append(c.x)
	# 同一次结算里接连到达的事件（发动 → 命中）**并成一条**：分成两条就画不出
	# 「指向受影者」的光带，玩家也看不出谁打的谁。
	var tail: Dictionary = {}
	var tail_live := false
	if _cue_t0 != 0 and not _cue_cur.is_empty():
		tail = _cue_cur
		tail_live = true
	elif not _cues.is_empty():
		tail = _cues[_cues.size() - 1]
	if not tail.is_empty() and _now() - int(tail.get("at", 0)) <= CUE_MERGE_MS:
		_cue_absorb(tail, uniq, label, tail_live, src)
		queue_redraw()
		return
	_cues.append({"cells": uniq, "rows": rows, "label": label,
			"col": col, "at": _now(), "src": src})
	if _cues.size() > 8:
		_cues = _cues.slice(_cues.size() - 8)
	queue_redraw()


func _fx_claim(cell: Vector2i) -> void:
	## 这一格已经有**专属命中表现**（普通攻击 / 践踏 / 直击）→ 通用受击演出让路，
	## 免得同一个伤口炸两次。
	#
	# ⚠️ R325：认领的同时**必须撤掉这一格已经排着的通用受击**（`fx_hit`）。
	# 引擎 `_hit_unit()` 是**先发 `fx_impact`、后发 `attack`** 的：battle_scene 收到
	# `fx_impact` 那一刻这一格还没被认领 → 通用受击（紫爆点 + `-N`）先排队了，
	# 等 `attack` 到了再认领已经来不及 —— 同一次攻击于是飘出**两个**伤害数字
	# （用户报「攻击会弹出两次伤害显示」，就是这条时序）。
	# 认领处顺手撤销是唯一可靠的时机：谁声明「这一下我有专属演出」，谁负责清场。
	_fx_claimed[cell] = _now()
	_fx_unqueue_hit(cell)


func _fx_unqueue_hit(cell: Vector2i) -> void:
	## 专属落点表现（meteor 这类）到了 → 撤掉**同一格**还排着的通用 `fx_hit`，
	## 否则那一格会「紫色爆点 + -N」连演两遍。cue 的脉冲 / 光带**不撤**
	## —— 那是「谁打谁」的因果连线，跟爆点是两件事。
	for i in range(_delayed.size() - 1, -1, -1):
		var ev: Dictionary = _delayed[i]
		if str(ev.get("kind", "")) != "fx_hit":
			continue
		var d: Dictionary = ev.get("data", {})
		if d.get("cell") == cell:
			_delayed.remove_at(i)


func _cam_to_scroll(target: float, ms: int) -> void:
	_cam_from = _grid_scroll
	_cam_to = clampf(target, _grid_scroll_min(), _grid_scroll_max())
	_cam_t0 = _now()
	_cam_ms = maxi(1, ms)


func _cam_cancel() -> void:
	## 玩家一动（滚轮 / 拖棋盘 / 点格子）就交还镜头控制权，并清空排队演出。
	_cam_ms = 0
	_cues.clear()
	_cue_t0 = 0
	_cue_cur = {}
	_cue_cells = []
	_cue_src = Vector2i(-1, -1)
	_cue_shots = []


static func cue_shot_rows(rows: Array) -> Array:
	## 把「要展示的行」切成镜头段（唯一口）：塞得进一屏就一段；
	## 塞不进就一行一段 —— 发动者和受影者轮流进画面，总比两边都看不见强。
	var lo := 99
	var hi := -1
	for r in rows:
		lo = mini(lo, int(r))
		hi = maxi(hi, int(r))
	if hi < 0:
		return []
	if float(hi - lo + 1) * CELL <= GRID_H:
		return [rows]
	var out: Array = []
	for r in rows:
		out.append([r])
	return out


func _cue_shots_of(rows: Array) -> Array:
	## 镜头段 = 行分组 + 该组的落位滚动量（滚动量只算一次，纯函数）。
	var shots: Array = []
	for grp: Array in cue_shot_rows(rows):
		shots.append({"rows": grp, "scroll": cue_scroll_for(grp)})
	return shots


func _cue_absorb(cue: Dictionary, cells: Array, label: String,
		live: bool, src := Vector2i(-1, -1)) -> void:
	## 把后来的格子并进已有演出（发动者 + 受影者 = 一条完整的因果）。
	## R321：后到的这条若带来了**发动者**（先入队的恰是受影者），要把它补进 cue ——
	## 否则光带会以「第一个受害者」为起点，画成两个受害者之间的激光。
	var had_src: bool = int((cue.get("src", Vector2i(-1, -1)) as Vector2i).x) >= 0
	if not had_src and int(src.x) >= 0:
		cue["src"] = src
		if live:
			_cue_src = src
	var dst: Array = cue["cells"]
	var rows: Array = cue["rows"]
	var grew := false
	for c: Vector2i in cells:
		if not dst.has(c):
			dst.append(c)
			grew = true
		if not rows.has(c.x):
			rows.append(c.x)
	if label != "" and str(cue.get("label", "")) == "":
		cue["label"] = label
	cue["at"] = _now()
	if not live:
		return
	_cue_cells = dst
	var shots := _cue_shots_of(rows)
	if not shots.is_empty():
		_cue_shots = shots
		# 只并进格子、段数没变时不要重排镜头（否则正在滑的补间会被打断）
		if grew and _cam_ms == 0:
			_cue_pan_to(shots, 0)


static func cue_rows_visible(rows: Array, scroll: float) -> bool:
	## R321：这些行**整段**是不是已经在可视窗里（纯函数 → 回归直接钉）。
	## 原来只要「落位滚动量 != 当前滚动量」就滑一下，于是**同屏内的伤害也会把画面扯一下**
	## （用户口径：「其他原因造成伤害，也不要拉动屏幕了」）。
	var lo := 99
	var hi := -1
	for r in rows:
		lo = mini(lo, int(r))
		hi = maxi(hi, int(r))
	if hi < 0:
		return true
	var top := float(lo) * CELL
	var bottom := float(hi + 1) * CELL
	return top >= scroll - 0.5 and bottom <= scroll + GRID_H + 0.5


static func cue_should_pan(has_src: bool, rows: Array, scroll: float) -> bool:
	## R321：cue 要不要挪镜头 —— **唯一判据**（纯函数，回归直接钉）。
	##   ① 没有发动者 → 不挪：只有「谁发动 → 谁受伤」这种因果才值得把画面带走，
	##      只是「某格掉了血」（陷阱 / 反伤 / 各类被动）不该让人头晕；
	##   ② 要展示的行已经在画面里 → 不挪：落位只是「居中」，居中不是目的。
	return has_src and not cue_rows_visible(rows, scroll)


func _cue_pan_to(shots: Array, i: int) -> void:
	## R321：cue 的唯一镜头口 —— 判据全在 `cue_should_pan()`（纯函数，回归可钉）。
	if i < 0 or i >= shots.size():
		return
	var has_src: bool = _cue_src.x >= 0 and _cue_cells.has(_cue_src)
	if not cue_should_pan(has_src, shots[i]["rows"], _grid_scroll):
		return
	var want := float(shots[i]["scroll"])
	if absf(want - _grid_scroll) > 1.0:
		_cam_to_scroll(want, CUE_CAM_MS)


func _begin_cue(cue: Dictionary) -> void:
	var n := _now()
	_cue_cur = cue
	_cue_t0 = n
	_cue_home = _grid_scroll
	_cue_src = cue.get("src", Vector2i(-1, -1))
	_cue_cells = cue["cells"]
	var shots := _cue_shots_of(cue["rows"])
	_cue_shots = shots
	_cue_pan_to(shots, 0)
	queue_redraw()


func _end_cue() -> void:
	_cue_t0 = 0
	_cue_cur = {}
	_cue_cells = []
	_cue_src = Vector2i(-1, -1)
	_cue_shots = []
	if _cues.is_empty():
		# 演完回到玩家原本的位置 —— 别把人留在敌方半场
		if absf(_grid_scroll - _cue_home) > 1.0:
			_cam_to_scroll(_cue_home, CUE_CAM_MS)
	else:
		_begin_cue(_cues.pop_front())


func _tick_cues(_delta: float) -> bool:
	## 推进镜头补间 + 演出队列。返回 true = 还在演（界面要逐帧重绘）。
	if _shot_pending and not _cue_demo:
		return false
	if _cue_demo and _shot_pending:
		# 出图：队列照常开播，但**进度与镜头都钉住** —— 截图要的是稳定构图，
		# 不能让补间把画面带着跑，更不能因为进度没走完就永远不入场。
		if _cue_t0 == 0:
			if _cues.is_empty():
				return false
			_begin_cue(_cues.pop_front())
			_cam_ms = 0                     # 掐掉 _begin_cue 里排的补间
		# ⚠️ 每帧都要钉一次：开场巡场（_grid_intro_tick）会写 _grid_scroll，
		# 只钉第一帧等于没钉 —— 镜头会被巡场拖走，跨屏两段就变成一模一样的图。
		if not _cue_shots.is_empty():
			var pin := clampi(_cue_pin, 0, _cue_shots.size() - 1)
			_grid_scroll = clampf(float(_cue_shots[pin]["scroll"]),
					_grid_scroll_min(), _grid_scroll_max())
		return true
	var n := _now()
	var busy := false
	if _cam_ms > 0:
		var t := clampf(float(n - _cam_t0) / float(_cam_ms), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)       # ease-out cubic：起步快、落位稳
		_grid_scroll = lerpf(_cam_from, _cam_to, e)
		busy = true
		if t >= 1.0:
			_cam_ms = 0
	# 认领表只留最近 3 秒（别让字典无限长）
	if not _fx_claimed.is_empty():
		for k in _fx_claimed.keys():
			if n - int(_fx_claimed[k]) > 3000:
				_fx_claimed.erase(k)
	if _cue_t0 == 0:
		if _cues.is_empty():
			return busy
		_begin_cue(_cues.pop_front())
		return true
	var el := n - _cue_t0
	var shots: Array = _cue_shots
	for i in shots.size():
		var t0 := CUE_MS * i
		if el >= t0 and el < t0 + CUE_MS:
			if _cam_ms == 0:
				_cue_pan_to(shots, i)
			break
	if el >= _cue_dur():
		if _cue_demo and _shot_pending:
			_cue_t0 = n          # 出图：原地重来，画面永远停在演出态
		else:
			_end_cue()
	return true


func _draw_cues() -> void:
	## 通用演出本体（唯一口）：发动脉冲 ＋ 指向受影者的光带 ＋ 受影者落点环 ＋ 卡名。
	## 画在棋盘 transform 内（跟着开场缩放 / 震动一起动），并压在卡牌之上。
	##
	## ⚠️ R321（用户口径）：**只有「有发动者」的演出才画脉冲 / 光带 / 卡名**。
	##   * 有发动者 = 引擎 `_fx_pulse()`（`card_pulse`）报过来的那一格。典型就是
	##     「远古虚骨龙」吐息：它**原地不动**、伤害来自效果，没有位移动作可看，
	##     不画那条光带，玩家根本不知道是谁打的。
	##   * 没有发动者 = 只是「某格受了伤」（`fx_impact` 通用受击 / 陷阱 / 反伤 / 被动）。
	##     这些**只画落点环**（原地指示）：普通攻击本来就有卡牌位移 + 爆点，
	##     再补一条激光纯属重复；连起来了还会把「两个受害者」画成因果关系，纯误导。
	var n := _now()
	if _cue_t0 == 0 or _cue_cur.is_empty() or _cue_cells.is_empty():
		return
	var total := maxi(1, _cue_dur())
	var u := clampf(float(n - _cue_t0) / float(total), 0.0, 1.0)
	if _cue_demo and _shot_pending:
		u = CUE_SHOT_U   # 出图：钉住进度，免得抓到的永远是尾声（alpha 已衰减到看不见）
	var has_src: bool = _cue_src.x >= 0 and _cue_cells.has(_cue_src)
	var src_cell: Vector2i = _cue_src if has_src else (_cue_cells[0] as Vector2i)
	var src: Vector2 = _cell_center(src_cell)
	var col: Color = _cue_cur.get("col", UiTheme.KIND_SKILL)
	# ① 发动脉冲：两圈错相位向外扩散（单圈一闪太容易被当成卡面自带光环）
	#    只在**有发动者**时画 —— 没有发动者时「源头」只是第一个受害者，画了就是撒谎。
	if has_src:
		for i in 2:
			var k := fmod(u * 2.2 + float(i) * 0.5, 1.0)
			var rr := 22.0 + 46.0 * k
			draw_arc(src, rr, 0.0, TAU, 28,
					Color(col.r, col.g, col.b, 0.85 * (1.0 - k)), 3.5)
	# ② 受影者落点环（每格一个）；光带只在有发动者时画 ——
	#    那条线表达的是「谁打谁」，没有发动者就无从谈起。
	var a := clampf(1.0 - u * 0.7, 0.15, 1.0)
	for j in _cue_cells.size():
		var c: Vector2i = _cue_cells[j]
		if has_src and c == _cue_src:
			continue                 # 发动者自己那格有脉冲，不再套环
		var dst: Vector2 = _cell_center(c)
		if has_src:
			draw_line(src, dst, Color(col.r, col.g, col.b, a * 0.20), 18.0)
			draw_line(src, dst, Color(col.r, col.g, col.b, a * 0.70), 7.0)
			draw_line(src, dst, Color(1, 1, 1, a * 0.85), 2.5)
		draw_arc(dst, 34.0 + 10.0 * u, 0.0, TAU, 26,
				Color(col.r, col.g, col.b, a * 0.90), 3.5)
		draw_arc(dst, 34.0 + 10.0 * u, 0.0, TAU, 26,
				Color(1, 1, 1, a * 0.50), 1.5)
	var label := str(_cue_cur.get("label", ""))
	if label != "" and has_src:
		_draw_string_box_center(UiTheme.font_bold(), 15, label,
				src + Vector2(0, -BOARD_CARD_H * 0.5 - 18), Color.WHITE,
				Color(0.10, 0.09, 0.13, 0.88))


func _tick_anims() -> bool:
	## 清理过期动画，返回是否仍有活动动画。
	var n := _now()
	var any := false
	for key in _slides.keys():
		var a: Dictionary = _slides[key]
		if n - int(a.start) >= int(a.dur):
			_slides.erase(key)
		else:
			any = true
	for key2 in _attacks.keys():
		var l: Dictionary = _attacks[key2]
		if n - int(l.start) >= int(l.dur):
			_attacks.erase(key2)
		else:
			any = true
	# 延时特效：到点触发（命中 / 击破）
	while true:
		var due := -1
		for i in _delayed.size():
			if int(_delayed[i].at) <= n:
				due = i
				break
		if due < 0:
			break
		var ev: Dictionary = _delayed.pop_at(due)
		_apply_delayed(str(ev.kind), ev.data as Dictionary)
		any = true
	for key3 in _flashes.keys():
		var fl: Dictionary = _flashes[key3]
		if n - int(fl.start) >= int(fl.dur):
			_flashes.erase(key3)
		else:
			any = true
	_ghosts = _ghosts.filter(func(g): return n - int(g.start) < int(g.dur))
	_dying = _dying.filter(func(x): return int(x.hide_at) > n)
	_floaters = _floaters.filter(func(f): return n - int(f.start) < int(f.dur))
	_bursts = _bursts.filter(func(b): return n - int(b.start) < int(b.dur))
	_wake_rings = _wake_rings.filter(func(r): return n - int(r.start) < int(r.dur))
	_impacts = _impacts.filter(func(f): return n - int(f.start) < int(f.dur))
	_pow_fx = _pow_fx.filter(func(f): return n - int(f.start) < int(f.dur))
	_heal_fx = _heal_fx.filter(func(f): return n - int(f.start) < int(f.dur))
	_deck_fly = _deck_fly.filter(func(f): return n - int(f.start) < int(f.dur))
	_transform_fx = _transform_fx.filter(func(x): return n - int(x.start) < int(x.dur))
	if not _screen_flash.is_empty() and n - int(_screen_flash.start) >= int(_screen_flash.dur):
		_screen_flash = {}
	return any or not _ghosts.is_empty() or not _floaters.is_empty() \
			or not _bursts.is_empty() or not _dying.is_empty() \
			or not _wake_rings.is_empty() \
			or not _delayed.is_empty() or n < _shake_until \
			or not _impacts.is_empty() or not _pow_fx.is_empty() \
			or not _heal_fx.is_empty() or not _screen_flash.is_empty() \
			or not _deck_fly.is_empty() or not _transform_fx.is_empty()


func _energy_fail(card: CardData, idx: int) -> void:
	## 能量不足统一口（R151 P2-15）：提示 + 卡面回弹抖动 + 能量面板红闪。
	_say("能量不足：%s 需要 %d，当前能量 %d" % [
			card.card_name, engine.cost_of(card), engine.energy_of()])
	_reject_fx(idx, "energy")


func _reject_fx(idx: int, reason := "", target = null) -> void:
	## R151 P2-15：打出被拒（能量不足 / 落点非法）→ 卡回弹抖动 + 目标红闪。
	if _shot_pending:
		return
	_shake_card = {"idx": idx, "start": _now(), "dur": 150}
	if reason == "energy":
		_reject_flash["energy"] = {"start": _now(), "dur": 220}
	if target is Vector2i and (target as Vector2i).x >= 0:
		_reject_flash["cell"] = {"cell": target, "start": _now(), "dur": 220}


func _on_engine_action(kind: String, data: Dictionary) -> void:
	## 引擎动作 → 动画 + 音效。
	var n := _now()
	# R151 P0-2：「打出 / 转移」不是「消失」—— 这些事件对应的移除不播飞出
	# （单位有 P0-4 落位、效果卡进效果区、技能当场结算，都已经看得见去向）。
	if kind == "spell" or kind == "effect" \
			or (kind == "place" and str(data.get("side", "")) == GameEngine.SIDE_SELF):
		if data.get("card") is CardData:
			_flyout_skip.append((data["card"] as CardData).id)
	elif kind == "batch_transfer":
		_flyout_skip_all = true     # 手牌洗回牌库（不是弃牌）→ 整批移除不播
	elif kind == "swap" and data.get("old") is CardData:
		# 交换：原单位从场上顶回手牌（不是抽的）→ 不播「从抽牌堆飞入」
		_flyin_skip.append((data["old"] as CardData).id)
	# R151 P2-13：力量成长事件族（升级 / 骑士 / 锻造 / 夜行 / 精进 / 使魔）→ 卡面数字跳动 + 扩散环
	if kind in ["upgrade", "knight_grow", "heph_grow", "night_grow", "mage_grow", "familiar_grow"]:
		var pg_cell = data.get("cell")
		if pg_cell is Vector2i and (pg_cell as Vector2i).x >= 0 and not _shot_pending:
			_pow_fx.append({"cell": pg_cell, "start": n, "dur": 300})
	# R151 P2-14：格上治疗事件族 → 上升光点（与伤害的扩散爆点对称）
	if kind in ["heal", "regen", "charge_heal", "self_repair", "night_erosion"]:
		var hl_cell = data.get("cell")
		if hl_cell is Vector2i and (hl_cell as Vector2i).x >= 0 and not _shot_pending:
			for hf_i in 4:
				_heal_fx.append({"pos": _cell_center(hl_cell), "sc": _grid_scroll, "start": n + hf_i * 70,
						"dur": 480, "seed": hf_i})
	elif kind == "self_heal" and not _shot_pending:
		for hf_j in 4:
			_heal_fx.append({"pos": Vector2(GRID_X + GRID_W + 46, GRID_Y + GRID_H - 20),
					"start": n + hf_j * 70, "dur": 480, "seed": hf_j})
	match kind:
		"out_of_control_fort":
			# R288 失控要塞：入场随机释放职业技能 —— 这里只报总结果；每张技能自己
			# 已经走过上面的 "spell" 分支（音效 / 飘字都在那儿）。
			var ocf_names := ""
			for ocf_n in (data.get("casts", []) as Array):
				ocf_names = str(ocf_n) if ocf_names == "" \
						else "%s, %s" % [ocf_names, str(ocf_n)]
			if int(data.get("cannons", 0)) <= 0:
				status_text = "R288：失控要塞 入场 —— 本次对战还没用过「聚能炮击」，没有技能可释放"
			else:
				status_text = "R288：失控要塞 入场（已用聚能炮击 %d 张）→ 随机释放 %d 张技能：%s" % [
						int(data.get("cannons", 0)), (data.get("casts", []) as Array).size(), ocf_names]
			sfx.play("spell")
		"place":
			sfx.play("place")
			var cell: Vector2i = data["cell"]
			var pl := engine.state.unit_at(cell)
			if pl != null:
				# R151 P0-4：玩家亲手放置 → 从松手/手牌真实位置飞来（缩放回稳），
				# 不再统一从 −110px 天上掉下来（AI / 效果召唤仍走默认）。
				var pl_from := _cell_center(cell) + Vector2(0, -110)
				var pl_dur := 450
				var pl_sc := 1.0
				var pl_from_grid := true
				if not _place_from.is_empty() and data.get("card") is CardData \
						and str(data.get("side", "")) == GameEngine.SIDE_SELF \
						and (data["card"] as CardData).id == int(_place_from.get("card_id", -1)) \
						and n - int(_place_from.get("at", 0)) < 2000:
					pl_from = _place_from["pos"]
					pl_dur = 180
					pl_sc = HAND_CARD_H / BOARD_CARD_H
					pl_from_grid = false   # 手牌屏位：不随棋盘滚动
					_place_from = {}
				_slides[pl] = {"from": pl_from, "to": _cell_center(cell),
						"start": n, "dur": pl_dur, "sc": _grid_scroll,
						"from_grid": pl_from_grid}
				if pl_sc != 1.0:
					_slides[pl]["from_scale"] = pl_sc
		"fence_merge":
			# 栅栏修复术（6021）：两张栅栏合并 → 加固爆点 + 「生+N」飘字
			sfx.play("place")
			var fm_cell: Vector2i = data["cell"]
			var fm_name := "栅栏"
			if data.get("card") is CardData:
				fm_name = (data["card"] as CardData).card_name
			_bursts.append({"pos": _cell_center(fm_cell), "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("e08a2e"), "big": false})
			_floaters.append({"pos": _cell_center(fm_cell) + Vector2(0, -20), "sc": _grid_scroll,
					"text": "叠栅栏 生+%d" % int(data.get("gained", 0)),
					"col": Color("e08a2e"), "start": n, "dur": 1500, "size": 18})
			_say("▣ 栅栏修复术：两张栅栏合并 → %s 生命 %d" % [fm_name,
					int(data.get("health", 0))])
		"void_lord":
			# 虚空主宰（9082）：本次对战中每用技能牌对敌方造成一次伤害 → 手卡里的本卡费用 -2
			_say("◈ 虚空主宰：第 %d 次技能对敌造成伤害 → 本卡费用 -%d（现 %d 费）" % [
					int(data.get("count", 0)), int(data.get("discount", 0)),
					10 - int(data.get("discount", 0))])
		"move":
			var pl2 := engine.state.unit_at(data["dst"])
			if pl2 != null:
				# 多格移动：沿引擎给的逐格路径滑（不能从起点直连终点，那会穿墙/走捷径）
				var mv_pts: Array[Vector2] = []
				for mv_c in (data.get("path", []) as Array):
					mv_pts.append(_cell_center(mv_c as Vector2i))
				if mv_pts.size() < 2:
					mv_pts = [_cell_center(data["src"]),
							_cell_center(data["dst"])]
				var mv_steps := mv_pts.size() - 1
				_slides[pl2] = {"from": mv_pts[0], "to": mv_pts[mv_steps],
						"pts": mv_pts, "sc": _grid_scroll,
						"start": maxi(n, _anim_end_for(pl2)),
						"dur": MOVE_SLIDE_BASE_MS + MOVE_SLIDE_PER_STEP_MS * mv_steps}
		"attack":
			var src_c := _cell_center(data["src"])
			var dst_c := _cell_center(data["dst"])
			var adir: Vector2 = (dst_c - src_c).normalized()
			var atk_pl := engine.state.unit_at(data["src"])
			var def_pl := engine.state.unit_at(data["dst"])
			# 卡面生命冻结：伤害已在引擎里扣掉，但数字等到「命中」演出才往下掉
			if def_pl != null:
				_freeze_hp(def_pl, int(data["damage"]))
			# R288：这一格已经有「弹体命中」专属演出 → 通用受击让路
			if data.get("dst") is Vector2i:
				_fx_claim(data["dst"])
			# 攻击演出排在「该单位已排队的动作」之后：AI 一步内常连做「移动 + 攻击」，
			# 若两段同时起播，滑行会盖住蓄力/后坐，看起来就是「怪物一闪就打完了」。
			var a_start := n
			if atk_pl != null:
				a_start = maxi(n, _anim_end_for(atk_pl))
				_attacks[atk_pl] = {"kind": "unit", "dir": adir, "src": src_c, "dst": dst_c,
						"sc": _grid_scroll,
						"start": a_start, "dur": ATK_DUR_MS, "dmg": int(data["damage"])}
			# 弹体命中时刻 = ATK_IMPACT_T × 总时长：爆点/闪红/伤害数字那时才出现
			_delayed.append({"at": a_start + int(ATK_IMPACT_T * ATK_DUR_MS), "kind": "hit",
					"data": {"pos": dst_c, "sc": _grid_scroll,
							"dmg": int(data["damage"]), "def": def_pl}})
			_say("⚔ %s 攻击 %s！" % [data.get("atk_name", "?"), data.get("def_name", "?")])
		"hp":
			# 攻击方 side；被打的是对面 → 飘字/爆点落在对应 HP 横幅。
			# 直击 HP 也让单位「冲锋撞上去」——否则 AI 单位只闪一行数字、毫无动作。
			var hp_side := str(data.get("side", ""))
			var banner_y := GRID_Y + 22.0 if hp_side == GameEngine.SIDE_SELF \
					else GRID_Y + GRID_H - 20.0
			# 哪一方 HP 在掉：self 方攻击 → 敌方 HP 掉；opponent 方攻击 → 我方 HP 掉
			var hp_key: String = "hp_opp" if hp_side == GameEngine.SIDE_SELF \
					else "hp_self"
			# R145：`damage` 现在是**实际掉的血**（石肤 / 荒野形态 / 护心 / 挡下之后）。
			# 被完全挡下（0）时不冻结横幅、不飘字、不震屏 —— 引擎日志已经写了原因。
			var hp_dmg := int(data.get("damage", 0))
			if hp_dmg > 0:
				_freeze_hp(hp_key, hp_dmg)   # 横幅数字冻结到撞击演出才掉
			var hp_atk := engine.state.unit_at(data["src"])
			var h_start := n
			if hp_atk != null:
				h_start = maxi(n, _anim_end_for(hp_atk))
				var hs := _cell_center(data["src"])
				var hd := _cell_center(data["dst"])
				var hdir: Vector2 = (hd - hs).normalized()
				_attacks[hp_atk] = {"kind": "hp", "dir": hdir, "src": hs, "dst": hd,
						"sc": _grid_scroll,
						"start": h_start, "dur": ATK_DUR_MS, "dmg": hp_dmg}
			if hp_dmg > 0:
				# 撞击时刻才出爆点/飘字/震屏，与单位动作对齐
				_delayed.append({"at": h_start + int(ATK_IMPACT_T * ATK_DUR_MS),
						"kind": "hp_hit",
						"data": {"pos": Vector2(GRID_X + GRID_W + 46, banner_y),
						"dmg": hp_dmg, "hpkey": hp_key}})
				if hp_side == GameEngine.SIDE_SELF:
					_say("⚔ %s 直击敌方 HP！-%d" % [data.get("atk_name", "?"), hp_dmg])
				else:
					_say("⚔ %s 直击我方 HP！-%d" % [data.get("atk_name", "?"), hp_dmg])
		"curse_added":
			# R231 破绽：俄倪厄往卡组塞诅咒 —— 牌库张数会自己跳，玩家不一定看得出来，
			# 这里补一句播报（不播动画：诅咒是凭空进牌库，没有「从哪儿飞」（0,0））。
			var ca_from := ""
			if data.get("from") is CardData:
				ca_from = (data["from"] as CardData).card_name
			if data.get("card") is CardData:
				var ca_card := data["card"] as CardData
				if not _shot_pending:
					_deck_fly.append({"card": ca_card,
						"from": Vector2(GRID_X + GRID_W + 46, GRID_Y + GRID_H - 20),
						"start": n, "dur": 360, "curse": true})
				if not _shot_pending:
					_transform_fx.append({"zone": "deck", "start": n, "dur": 460})
				_say("⚡ 破绽：%s 把「%s」（%d 费诅咒）塞进了卡组" % [
						ca_from, ca_card.card_name, ca_card.cost])
		"transform":
			# R283：随机变化卡进手卡 -> 不再走「从抽牌堆飞入」的抽牌动画；
			#   改为「变幻」特效（光环 + 火花），并跳过该卡的抽 / 弃飞行动画。
			var tr_new: CardData = data.get("new")
			var tr_old: CardData = data.get("old")
			if tr_old is CardData:
				_flyout_skip.append(tr_old.id)
			if tr_new is CardData:
				_flyin_skip.append(tr_new.id)
				if str(data.get("side", "")) == GameEngine.SIDE_SELF and not _shot_pending:
					_transform_fx.append({"zone": str(data.get("zone", "hand")),
						"slot": int(data.get("index", -1)),
						"id": tr_new.id, "start": n, "dur": 460})
			if data.has("recycle_hp"):
				# R292：回收 = 「变成」类（走同一条变化口）→ 播报仍写清改造后的数值，
				# 落点同系统升级 = 整排手牌的中点（目标在手牌里，不在棋盘上）。
				if tr_new is CardData:
					var rc_n: CardData = tr_new as CardData
					_say("◆ 回收：%s → 素体 %d 攻 / %d 血（改造 +%d，本场战斗永久）" % [
							str(data.get("recycled", "?")), rc_n.power, rc_n.health,
							int(data.get("recycle_hp", 0))])
					_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
						"text": "%s → 素体 %d/%d" % [str(data.get("recycled", "?")),
							rc_n.power, rc_n.health],
						"col": Color("8ad4f0"), "start": n, "dur": 2000})
			else:
				_say("✶ %s：%s -> %s" % [str(data.get("source", "")),
					(tr_old.card_name if tr_old is CardData else "?"),
					(tr_new.card_name if tr_new is CardData else "?")])
		"deck_added":
			# R283：卡入牌库（镜面反射 / 生产订单）-> 卡背飞入卡组区（普通调，无紫）。
			var da_card: CardData = data.get("card")
			var da_from := Vector2(DECK_X + CARD_W / 2.0, DECK_Y - 130.0)
			if data.get("from") is Vector2:
				da_from = data["from"]
			if not _shot_pending:
				_deck_fly.append({"card": da_card, "from": da_from,
					"start": n, "dur": 320, "curse": false})
				_transform_fx.append({"zone": "deck", "start": n, "dur": 460})
		"trample_hit":
			# R225 践踏：击杀的溢出伤害沿**同一列**击穿下一个单位 —— 在**那个格子**
			# 补一次命中演出（不重播攻击者的攻击动作），排在这次攻击「命中」之后再播，
			# 视觉上就是「伤害穿过了前一具尸体」。
			var th_cell: Vector2i = data["cell"]
			# R325：践踏这一格同样要认领 —— 它的 `_hit_unit` 也先发过 `fx_impact`，
			# 不认领就会和上面那条一样「紫爆点 + 橙爆点」各飘一次。
			_fx_claim(th_cell)
			var th_pl := engine.state.unit_at(th_cell)
			var th_dmg := int(data.get("amount", 0))
			var th_at := n
			var th_src = data.get("src")
			var th_atk = engine.state.unit_at(th_src) if th_src is Vector2i else null
			if th_atk != null and _attacks.has(th_atk):
				var tha: Dictionary = _attacks[th_atk]
				th_at = int(tha.start) + int(ATK_IMPACT_T * int(tha.dur)) + 140
			if th_pl != null and th_dmg > 0:
				_freeze_hp(th_pl, th_dmg)   # 卡面生命也等命中演出到点才掉
			_delayed.append({"at": maxi(th_at, n), "kind": "hit",
					"data": {"pos": _cell_center(th_cell), "sc": _grid_scroll,
							"dmg": th_dmg, "def": th_pl}})
			_say("⚡ 践踏！溢出伤害沿同列传给 %s（-%d）" % [
					data.get("name", "?"), th_dmg])
		"trample":
			# 打穿挡在 HP 前面的单位 → 多出来的伤害漏到玩家 HP。
			# 排在这次攻击「命中」之后再播：弹体命中 → 击破 → 漏伤。
			var tr_side := str(data.get("side", ""))
			var tr_y := GRID_Y + 22.0 if tr_side == GameEngine.SIDE_SELF \
					else GRID_Y + GRID_H - 20.0
			var tr_key: String = "hp_self" if tr_side == GameEngine.SIDE_SELF \
					else "hp_opp"
			# R145：`amount` 现在是**实际掉的血**（溢出也可能被石肤 / 护心压掉、或被全挡）。
			var tr_amt := int(data.get("amount", 0))
			if tr_amt > 0:
				_freeze_hp(tr_key, tr_amt)   # 溢出也冻结到溢出演出才掉
			var tr_at := n
			# 溢出可能来自攻击（带 src，等弹体命中后再漏），也可能来自爆炎鸭炸击 /
			# 范围伤害的批量击杀收尾（没有 src）→ 那种就当场播。
			var tr_src = data.get("src")
			var tr_atk = engine.state.unit_at(tr_src) if tr_src is Vector2i else null
			if tr_atk != null and _attacks.has(tr_atk):
				var la: Dictionary = _attacks[tr_atk]
				tr_at = int(la.start) + int(ATK_IMPACT_T * int(la.dur)) + 140
			if tr_amt > 0:
				_delayed.append({"at": maxi(tr_at, n), "kind": "hp_hit",
						"data": {"pos": Vector2(GRID_X + GRID_W + 46, tr_y),
						"dmg": tr_amt,
						"label": "溢出 -%d" % tr_amt,
						"hpkey": tr_key}})
				var tr_side_cn := "我方" if tr_side == GameEngine.SIDE_SELF else "敌方"
				if data.has("atk_name"):
					_say("⚔ %s 打穿 %s，溢出 %d 点直击%s HP！" % [data["atk_name"],
							data.get("def_name", "?"), tr_amt, tr_side_cn])
				else:
					_say("💥 溢出伤害：%d 点越过 %s 直击%s HP！" % [tr_amt,
							data.get("def_name", "?"), tr_side_cn])
		"card_pulse":
			# R288：卡效果发动（引擎 `_fx_pulse` 唯一口）→ 通用演出：脉冲 + 卡名 + 镜头。
			# 目标不在这里给：随后的 `fx_impact` 会再推一条「受影者」cue，
			# 于是「谁发动 → 谁中招」被**依次**演出来，两边不同屏也不会漏看。
			var cp_cell = data.get("cell")
			if cp_cell is Vector2i:
				var cp_col := UiTheme.KIND_SKILL
				if data.get("card") is CardData:
					var cp_card: CardData = data["card"]
					if cp_card.is_effect():
						cp_col = UiTheme.KIND_EFFECT
					elif cp_card.is_fort():
						cp_col = UiTheme.KIND_FORT
					elif cp_card.kind == "盟友":
						cp_col = UiTheme.KIND_ALLY
				# R321：这是**唯一**有发动者的来路 → 只有它会画脉冲 / 光带 / 拉镜头。
				_push_cue([cp_cell], str(data.get("label", "")), cp_col, cp_cell)
		"fx_impact":
			# R288：通用受击（引擎 `_hit_unit` 唯一口发出）。只有**没有专属表现**的
			# 伤害才演（普通攻击 / 践踏已经在同帧认领了那一格）。
			var fi_cell = data.get("cell")
			if fi_cell is Vector2i:
				var fc: Vector2i = fi_cell
				var fi_owned := _fx_claimed.has(fc) and n - int(_fx_claimed[fc]) < 700
				if not fi_owned:
					_fx_claim(fc)
					_delayed.append({"at": n + 160, "kind": "fx_hit",
							"data": {"cell": fc, "dmg": int(data.get("amount", 0)),
							"source": str(data.get("source", ""))}})
					_push_cue([fc], "", Color("8f5ad0"))
		"spell":
			sfx.play("heal" if int(data["card"].id) in [2002, 7202] else "spell")
			var detail := str(data.get("detail", ""))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 36),
					"text": detail, "col": UiTheme.KIND_SKILL,
					"start": n, "dur": 1600})
		"effect":
			sfx.play("place")
			var ecard: CardData = data["card"]
			_say("✦ 效果卡「%s」启用，持续生效中" % ecard.card_name)
			_floaters.append({"pos": Vector2(COST_X + (TAP_W + 12) / 2, COST_Y + ENERGY_H + 70),
					"text": "%s 生效" % ecard.card_name, "col": UiTheme.KIND_EFFECT,
					"start": n, "dur": 1500})
		"hand_burn":
			# R299：手牌满时抽到 / 获得的牌 → **直接进弃牌区**。
			# 复用「飞向弃牌堆」那条动画（mode out_d：缩小 + 末段盖板 = 滑进牌堆），
			# 只把起点从手牌位换成**牌堆位** —— 玩家看到的是「牌堆里抽出一张，没进手，
			# 拐去弃牌堆了」，这正是规则本身。
			# ⚠️ 手牌阵列没变化 → `_hand_sync()` 的 diff 播不到任何东西，本条是唯一来路。
			sfx.play("click")
			var bcard: CardData = data.get("card")
			if bcard != null:
				var bdelay := 45 * int(data.get("seq", 0))
				_hand_fly.append({"mode": "out_d", "card": bcard,
						"from_rect": Rect2(DECK_X, DECK_Y, CARD_W, CARD_H),
						"start": n + bdelay, "dur": 300})
				_floaters.append({"pos": Vector2(DISCARD_X + CARD_W / 2.0, DISCARD_Y - 24),
						"text": "手牌已满 · 进弃牌", "col": Color("b26a00"), "size": 14,
						"start": n + bdelay, "dur": 1300})
		"hand_full":
			# 手牌达上限（FieldState.HAND_LIMIT）。R299：口径从「不再抽牌」改成
			# 「照抽，但抽到的牌进弃牌区」—— 文案要跟着改，否则界面在骗人。
			sfx.play("click")
			var hlim := int(data.get("limit", 0))
			var hburn := int(data.get("burned", 0))
			if hburn > 0:
				_say("手牌已满（%d 张）：%d 张抽到的牌已进弃牌区" % [hlim, hburn])
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
						"text": "手牌已满 %d/%d · %d 张进弃牌" % [
								int(data.get("hand", 0)), hlim, hburn],
						"col": Color("b26a00"), "size": 17,
						"start": n, "dur": 2200})
			else:
				_say("手牌已满（%d 张）" % hlim)
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
						"text": "手牌已满 %d/%d" % [int(data.get("hand", 0)), hlim],
						"col": Color("b26a00"), "size": 17,
						"start": n, "dur": 2200})
		"deck_empty":
			# R299：牌库与弃牌区**都空** → 一张也抽不到。
			# 用户口径「明显但不影响操作」：居中大号横幅 + 状态栏，不弹窗、不吃输入、
			# 不暂停回合 —— 玩家照常出牌，只是知道「别指望再抽牌了」。
			sfx.play("click")
			var dn_want := int(data.get("want", 0))
			var dn_got := int(data.get("got", 0))
			_say("牌库与弃牌区都已空，抽不到卡了")
			_floaters.append({"pos": Vector2(WINDOW_W / 2.0, WINDOW_H / 2.0 - 120.0),
					"text": "牌库与弃牌区都已空 · 抽不到卡（要 %d / 抽到 %d）" % [dn_want, dn_got],
					"col": Color("c0392b"), "size": 19, "start": n, "dur": 3000})
		"whisper":
			# 道具「鸭之低语」：每回合开始随机到的强化（费用/伤害/抽牌）
			_whisper_txt = str(data.get("text", ""))
			sfx.play("heal")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 12),
					"text": "鸭之低语 · %s" % _whisper_txt, "col": Color("7b34b8"),
					"start": n, "dur": 2100})
		"wisdom":
			# 智慧喷涌（9059）：回合开始抽 1 张（效果卡还会被减费）
			sfx.play("draw")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "智慧喷涌 · 额外抽 %d 张" % int(data.get("count", 0)),
					"col": Color("3f8fbf"), "start": n, "dur": 2100})
		"blessing":
			# 无尽加护（9061）：回合开始随机一张效果卡进手卡
			sfx.play("draw")
			_say("✦ 无尽加护：随机一张效果卡加入手卡（%d 张）" % int(data.get("count", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "无尽加护 · 效果卡 +%d" % int(data.get("count", 0)),
					"col": Color("4a9a5a"), "start": n, "dur": 2100})
		"crow_token":
			# 使魔之夜（9062）：使用效果牌 → 一张乌鸦进手卡（本回合 0 费）
			sfx.play("draw")
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "使魔之夜 · 乌鸦 +1（本回合 0 费）", "col": Color("6a6a9a"), "size": 17,
					"start": n, "dur": 2100})
		"aether":
			# 以太屏障（9060）：本回合前 X 次受到的伤害变为 1
			sfx.play("heal")
			_say("✦ 以太屏障：本回合前 %d 次受到的伤害变为 1" % int(data.get("left", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "以太屏障 · 前 %d 次伤害→1" % int(data.get("left", 0)),
					"col": Color("4a7fd8"), "start": n, "dur": 2100})
		"aether_hit":
			# 以太屏障吸收了一次伤害
			sfx.play("heal")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": "以太屏障 · 伤害 %d → 1（还剩 %d 次）" % [
							int(data.get("amount", 0)), int(data.get("left", 0))],
					"col": Color("4a7fd8"), "size": 15, "start": n, "dur": 2000})
		"rice":
			# 道具「一袋米抗几楼」（R123）：我方 HP 首次受伤 → 抽 1 张卡 + 技能伤害 +1
			sfx.play("heal")
			_say("✦ 一袋米抗几楼：我方 HP 受伤 → 抽 1 张卡，本回合技能伤害 +1")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "一袋米抗几楼 · 抽 1 张 / 技能 +1", "col": Color("d7a54a"),
					"start": n, "dur": 2100})
		"revive":
			# 道具「叠加态的鸭」：HP 归零 → 复活（回复 1 点生命，概率永久 -25%）
			sfx.play("heal")
			_say("✚ 叠加态的鸭：复活！回复 1 点生命（下次复活概率 %d%%）"
					% int(data.get("chance", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 26),
					"text": "叠加态的鸭 · 复活（回复 1 点生命）", "col": Color("c0392b"),
					"start": n, "dur": 2400})
		"heal":
			# 白魔法师（9021）：自己回合开始时治疗生命百分比最低的己方单位
			sfx.play("heal")
			var hcell: Variant = data.get("cell")
			var hpos := Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30)
			if hcell is Vector2i:
				hpos = _cell_center(hcell)
			var hname := str((data.get("card") as CardData).card_name) \
					if data.get("card") is CardData else "?"
			# R171：hpos 两个分支都活着（格治疗 / HP 横幅）→ 只给格分支打标
			var h_flo := {"pos": hpos + Vector2(0, -12),
					"text": "治疗 +%d" % int(data.get("amount", 0)),
					"col": Color("2fa36b"), "start": n, "dur": 1500}
			if hcell is Vector2i:
				h_flo["sc"] = _grid_scroll
			_floaters.append(h_flo)
			if str(data.get("side", "")) == GameEngine.SIDE_OPPONENT:
				_say("✚ 白魔法师治疗了 %s（+%d）" % [hname, int(data.get("amount", 0))])
		"icecream":
			# 道具「冰淇淋与汽水」（6016）：第 1 回合 +4 能量 / 多抽 3 张 → 飘出台词
			# （刻意比开场 -3 生命的 relic 飘字高 66px，两条同时出现也不会叠在一起；
			#   用深一号的蓝 + 18px 字号，浅色棋盘上才读得清）
			sfx.play("heal")
			var ice_line := str(data.get("text", ""))
			_say("✦ 冰淇淋与汽水：+%d 能量 / 多抽 %d 张 ——「%s」"
					% [int(data.get("energy", 0)), int(data.get("draw", 0)), ice_line])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 96),
					"text": ice_line, "col": Color("1f7fc4"), "size": 18, "outline": 6,
					"start": n, "dur": 2600})
		"relic":
			# 第二层起始道具的持续/开场提示（黄桃罐头 / 冰淇淋与汽水 等）
			sfx.play("heal")
			var rtext := str(data.get("text", ""))
			_say("✦ %s" % rtext)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": rtext, "col": Color("3fc7d4"),
					"start": n, "dur": 1800})
		"dice_roll":
			# R311 水晶骰子：「?」房开战掷骰 → 前 X 回合每回合 +1 费。
			# 落点在棋盘上沿（作用对象是**整场战斗**，不绑某一格）。
			sfx.play("click")
			var dr_n := int(data.get("roll", 0))
			var dr_t := int(data.get("turns", 0))
			_say("✦ 水晶骰子：掷出 %d 点 —— 前 %d 回合每回合额外 %d 点费用"
					% [dr_n, dr_t, int(data.get("energy", 1))])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
					"text": "骰子 %d 点 · 前 %d 回合 +%d 费"
							% [dr_n, dr_t, int(data.get("energy", 1))],
					"col": Color("7fd2f0"), "size": 18, "start": n, "dur": 2600})
		"basin_absorb":
			# R311 不锈钢盆：代替玩家承受伤害 → 棋盘上沿飘「-N（剩 M）」并同步局状态。
			# ⚠️ 点数**必须**回写 `RunState`：跨战斗累计，丢一次就等于白送一件消耗品。
			sfx.play("heal")
			var ba_take := int(data.get("take", 0))
			var ba_left := int(data.get("left", 0))
			RunState.basin_charge = ba_left
			if engine != null:
				engine.basin_charge = ba_left
			_say("✧ 不锈钢盆承受 %d 点伤害（剩余 %d 点）" % [ba_take, ba_left])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 60.0),
					"text": "不锈钢盆 -%d（剩 %d）" % [ba_take, ba_left],
					"col": Color("b8c4cc"), "size": 16, "start": n, "dur": 1800})
		"basin_break":
			# R311 不锈钢盆：计数归零 → **失去此道具**（局状态与引擎两侧都得清）。
			# `engine.self_relics` 与 `RunState.relics` 是同一个数组，但这里仍显式重挂一次 ——
			# 将来若改成各持一份副本，这条也不会悄悄失效。
			sfx.play("click")
			RunState.lose_relic(RunState.BASIN_RELIC_ID)
			if engine != null:
				engine.basin_charge = 0
				engine.self_relics = RunState.relics
			_say("✧ 不锈钢盆计数归零 —— 失去此道具")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 60.0),
					"text": "不锈钢盆 碎了", "col": Color("8a949c"),
					"size": 17, "start": n, "dur": 2200})
		"pear":			# 道具「鸭梨」：我方 HP 受伤 → 最大生命 +1（只提高上限，不回复生命）
			sfx.play("heal")
			_say("✦ 鸭梨：受到伤害 → 最大生命 +1（当前 %d/%d）"
					% [int(data.get("hp", 0)), int(data.get("max_hp", 0))])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "鸭梨 · 最大生命 +1", "col": Color("a9b83c"),
					"start": n, "dur": 2100})
		"hero_cost":
			# 「英雄」（9023）上场的代价：玩家选中的 4 张手牌已弃掉 → 飘一行提示
			sfx.play("place")
			var hc_names: Array = data.get("names", [])
			var hc_txt: String = "英雄的代价：弃 %d 张（%s）" % [
					int(data.get("count", 0)), "、".join(hc_names)]
			_say("◆ %s" % hc_txt)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": hc_txt, "col": Color("8a5a1a"), "size": 15,
					"start": n, "dur": 2200})
		"self_clone":
			# 野兔 9032（R82）：使用后手牌增加一张自己的复制 → 飘字告诉玩家多了一张。
			# 没有提示的话玩家会以为手牌凭空少了一张（打出 -1、复制 +1 净值为 0）。
			# 音效用现成的 "draw"→ 没有该音色，这里用 click（短促）+ place（落地感）。
			sfx.play("click")
			var sc_name := "?"
			if data.get("card") is CardData:
				sc_name = (data["card"] as CardData).card_name
			_say("✦ %s：手牌增加一张复制（回合结束前可以打出）" % sc_name)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "%s · 复制入手" % sc_name, "col": Color("7fd6a0"),
					"start": n, "dur": 2000})
		"barrier_grant":
			# 能量屏障 8033（R87）：给抽牌堆里一张卡加上「首次受伤免掉」。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var bg_card: CardData = data["card"]
				var bg_drw: int = int(data.get("drawn", 0))
				sfx.play("place")
				_say("✦ 能量屏障：%s 获得能量屏障（下次上场时第一次挨打完全免掉），抽 %d 张"
						% [bg_card.card_name, bg_drw])
				_floaters.append({"pos": Vector2(DECK_X + CARD_W / 2, DECK_Y - 14),
						"text": "%s · 获得护盾" % bg_card.card_name,
						"col": Color("7fd6f0"), "start": n, "dur": 2200, "size": 14})
			else:
				_say("能量屏障：抽牌堆里没有「还没有能量屏障」的盟友 / 工事，效果落空（仍抽 %d 张）"
						% int(data.get("drawn", 0)))
			if bool(data.get("ok", false)) and data.get("card") is CardData and not _shot_pending:
				_transform_fx.append({"zone": "deck", "start": n, "dur": 460})
		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。
			sfx.play("heal")
			var ba_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var ba_name := "?"
			if data.get("card") is CardData:
				ba_name = (data["card"] as CardData).card_name
			_say("🛡 %s 的能量屏障挡住了 %d 点伤害（护盾消失）"
					% [ba_name, int(data.get("blocked", 0))])
			if ba_cell.x >= 0:
				_bursts.append({"pos": _cell_center(ba_cell), "sc": _grid_scroll, "start": n,
						"dur": 520, "col": Color("7fd6f0"), "big": true})
				_floaters.append({"pos": _cell_center(ba_cell) + Vector2(0, -14), "sc": _grid_scroll,
						"text": "护盾 · 0 伤", "col": Color("7fd6f0"),
						"start": n, "dur": 1600, "size": 17})
		"self_repair":
			# 自我修复 8035（R87）：改造一个己方盟友 → +2 最大生命 + 每回合回 4。
			sfx.play("heal")
			var sr_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_say("✚ 自我修复：%s 最大生命 +%d、每回合结束回 %d"
					% [str((data.get("card", null) as CardData).card_name),
						int(data.get("hp", 0)), int(data.get("regen", 0))])
			if (data.get("cell", Vector2i(-1, -1)) as Vector2i).x >= 0:
				# R301：血量增量交给卡面染色；「每回合回 N」是机制值不是数值增减 → 保留
				_floaters.append({"pos": sr_pos, "sc": _grid_scroll, "text": "自我修复 · 回 %d"
						% int(data.get("regen", 0)),
						"col": Color("8ce09a"), "start": n, "dur": 2000, "size": 14})
		"charge_heal":
			# 充电装置（8041，R91）：被「接通」的己方单位每回合结束回血 → 该格飘字。
			# 与「清泉 / 维修间 / 自我修复」共用冷青色系（都是 friendly 回血）。
			sfx.play("heal")
			var ch_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ch_pos, "sc": _grid_scroll, "text": "+%d" % int(data.get("amount", 0)),
				"col": COL_FIELD_PERSIST, "start": n, "dur": 1400, "size": 18})
		"shield_redirect":
			# 护盾生成器（8042，R92）：接通的我方单位受伤 → 伤害**改由它承受**，溢出不再结算。
			# 演出分两头：受害格「接下 N」+ 生成器格爆点「-N」，让玩家看清伤害到底去了哪里。
			sfx.play("heal")
			var sr_src := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var sr_dst := data.get("to", Vector2i(-1, -1)) as Vector2i
			var sr_n: int = int(data.get("amount", 0))
			_say("◈ %s 受到的 %d 点伤害被护盾生成器接下（溢出不再结算）"
					% [str((data.get("card", null) as CardData).card_name), sr_n])
			if sr_src.x >= 0:
				_floaters.append({"pos": _cell_center(sr_src) + Vector2(0, -14), "sc": _grid_scroll,
						"text": "接下 %d" % sr_n, "col": COL_FIELD_PERSIST,
						"start": n, "dur": 1600, "size": 16})
			if sr_dst.x >= 0:
				_bursts.append({"pos": _cell_center(sr_dst), "sc": _grid_scroll, "start": n,
						"dur": 520, "col": COL_FIELD_PERSIST, "big": true})
				_floaters.append({"pos": _cell_center(sr_dst) + Vector2(0, -14), "sc": _grid_scroll,
						"text": "-%d" % sr_n, "col": Color("f0a0a0"),
						"start": n, "dur": 1600, "size": 17})
		"mimic_upgrade":
			# 模仿者（8043，R92）：接通的我方盟友获得改造 → 它获得**相同改造**。
			var mu_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var mu_atk: int = int(data.get("atk", 0))
			var mu_hp: int = int(data.get("hp", 0))
			sfx.play("heal")
			_say("✧ 模仿者模仿 %s 的改造：+%d 攻 / +%d 血"
					% [str(data.get("from", "")), mu_atk, mu_hp])
			if mu_cell.x >= 0:
				# R301：数值交给卡面染色，飘字只写「模仿了改造」
				_floaters.append({"pos": _cell_center(mu_cell), "sc": _grid_scroll,
					"text": "模仿改造",
					"col": Color("8ce09a"), "start": n, "dur": 1800, "size": 15})
		"chimera":
			# 嵌合暴君（8047，R96）：使用时破坏接通的己方卡并吸收其攻/血。
			var ch_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var ch_abs: int = int(data.get("absorbed", 0))
			var ch_atk: int = int(data.get("atk", 0))
			var ch_hp: int = int(data.get("hp", 0))
			var ch_refund: int = int(data.get("refund", 0))   # R326：每破坏一个回复 1 费
			if ch_abs <= 0:
				_say("嵌合暴君：周围没有己方卡可融合")
			else:
				sfx.play("attack")
				# ⚠️ 状态栏**不写回费**：`StatusLabel` 只有 264px（≈19 全角字），
				# 加上「、回复 N 费」会被裁成省略号（R326 出图验证过）。回费改用卡上飘字。
				_say("嵌合暴君融合 %d 张卡：+%d 攻 / +%d 血" % [ch_abs, ch_atk, ch_hp])
				if ch_cell.x >= 0:
					_bursts.append({"pos": _cell_center(ch_cell), "sc": _grid_scroll, "start": n,
							"dur": 420, "col": COL_SPELL, "big": false})
					# R301：数值交给卡面染色，飘字只写「融合了几张」
					_floaters.append({"pos": _cell_center(ch_cell), "sc": _grid_scroll,
							"text": "融合 %d 张" % ch_abs,
							"col": Color("caa6ff"), "start": n, "dur": 1900, "size": 16})
					if ch_refund > 0:
						# R326：每破坏一个回复 1 费 —— 飘在卡下方（与「融合 N 张」错开一行）。
						_floaters.append({"pos": _cell_center(ch_cell) + Vector2(0, 30),
								"sc": _grid_scroll, "text": "+%d 费" % ch_refund,
								"col": TXT_POWER, "start": n + 120, "dur": 1600, "size": 15})
		"recycler":
			# 零件回收者（8046，R96）：接通的己方「素体以外」卡被销毁 → 回收其力量 + 手牌加素体。
			# ⚠️ R221：被销毁的是「素体」→ 引擎根本不发这条 action（不触发即无动画）。
			# ⚠️ R208：被销毁的卡力量为 0（工事 / 被削到 0 的单位）时**不飘「+0 攻」** ——
			# 攻击力一点没变，飘字只会让玩家以为出了 bug（用户实测反馈）。素体照给。
			var rc_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var rc_pow: int = int(data.get("power", 0))
			sfx.play("spell")
			if rc_pow > 0:
				_say("零件回收者回收 %d 力量，手牌 +1 张「素体」" % rc_pow)
				if rc_cell.x >= 0:
					# R301：数值交给卡面染色，飘字只写「回收了什么」
					_floaters.append({"pos": _cell_center(rc_cell), "sc": _grid_scroll,
							"text": "回收力量",
							"col": Color("ffa41f"), "start": n, "dur": 1700, "size": 16})
			else:
				_say("零件回收者：被破坏的卡没有力量（攻击力不变），手牌 +1 张「素体」")
		"prod_order":
			# 生产订单（8048，R96）：往抽牌堆加两张改造「素体」。
			var po_cnt: int = int(data.get("count", 0))
			var po_atk: int = int(data.get("atk", 0))
			var po_hp: int = int(data.get("hp", 0))
			sfx.play("place")
			_say("生产订单：卡组 +%d 张改造「素体」（各 +%d 攻 / +%d 血）" % [po_cnt, po_atk, po_hp])
		"demolish":
			# 拆解 8049（R97，机械之心）：破坏己方单位、回 3 费、手牌+素体；被改造则额外+升级。
			var dm_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var dm_up := bool(data.get("upgraded", false))
			var dm_refund: int = int(data.get("refund", 0))
			var dm_proto: int = int(data.get("got_proto", 0))
			var dm_upg: int = int(data.get("got_upg", 0))
			sfx.play("attack")
			if dm_up:
				_say("拆解：破坏被改造单位，回复 %d 费，手牌 +%d 素体 +%d 升级" % [dm_refund, dm_proto, dm_upg])
			else:
				_say("拆解：破坏单位，回复 %d 费，手牌 +%d 素体" % [dm_refund, dm_proto])
			if dm_cell.x >= 0:
				_floaters.append({"pos": _cell_center(dm_cell), "sc": _grid_scroll,
					"text": "+%d 费" % dm_refund,
					"col": UiTheme.STATE_FROZEN, "start": n, "dur": 1500, "size": 16})
		"overload_die":
			# 超负荷（旧式机兵 8050，R98）：己方回合结束、生命仍为负 → 真正死亡。
			var od_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var od_card = data.get("card", null)
			var od_name: String = od_card.card_name if od_card != null else "单位"
			sfx.play("death")
			_say("超负荷：%s 生命仍为负（%d），回合结束死亡" % [od_name, int(data.get("health", 0))])
			if od_cell.x >= 0:
				_floaters.append({"pos": _cell_center(od_cell), "sc": _grid_scroll,
					"text": "超负荷死亡", "col": Color("ff7a3c"),
					"start": n, "dur": 1500, "size": 15})
		"overload_neg":
			# 超负荷（旧式机兵 8050，R98）：受到伤害后仍以负数血量存活 → 一格提示。
			var on_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			if on_cell.x >= 0:
				_floaters.append({"pos": _cell_center(on_cell), "sc": _grid_scroll,
					"text": "负血存活 %d" % int(data.get("health", 0)),
					"col": Color("ff7a3c"), "start": n, "dur": 1400, "size": 14})
		"regen":
			# 自我修复的每回合回血（R87）：在该单位格上飘字。
			var rg_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": rg_pos, "sc": _grid_scroll, "text": "+%d" % int(data.get("amount", 0)),
					"col": Color("8ce09a"), "start": n, "dur": 1400, "size": 16})
		"night_erosion":
			# 夜蚀 8062（R103）：回合结束按剩余费用回复生命 —— 绿色回血飘字（同自我修复口径）。
			var ne_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ne_pos, "sc": _grid_scroll, "text": "+%d" % int(data.get("amount", 0)),
					"col": Color("8ce09a"), "start": n, "dur": 1400, "size": 16})
			sfx.play("heal")
		"batch_upgrade":
			# 批量改造 8031（R86）：手牌里所有盟友/工事各 +1 生命。
			var bu_n: int = int(data.get("count", 0))
			if bu_n <= 0:
				_say("批量改造：手牌里没有盟友或工事，效果落空")
			else:
				sfx.play("heal")
				_say("✦ 批量改造：手牌里 %d 张盟友/工事各 +1 生命（本场战斗内一直有效）"
						% bu_n)
				_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
						"text": "批量改造 · %d 张" % bu_n,
						"col": Color("8ad4f0"), "start": n, "dur": 2000})
		"overload":
			# 过载 8030（R85，机械之心）：给牌库里一张盟友加上「一回合行动两次」。
			# 目标是**牌库**里的牌（不在场上），所以飘字落在抽牌堆旁边而不是某个格子。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var ov_card: CardData = data["card"]
				sfx.play("place")
				_say("✦ 过载：%s 现在一回合行动两次（之后每次抽到它都是双动）"
						% ov_card.card_name)
				_floaters.append({"pos": Vector2(DECK_X + CARD_W / 2, DECK_Y - 14),
						"text": "%s · 行动两次" % ov_card.card_name,
						"col": Color("b98cf0"), "start": n, "dur": 2200, "size": 14})
			else:
				# 落空要说清原因，否则玩家以为白花了 2 费
				_say("过载：牌库里没有「没有一回合行动两次」的盟友，效果落空")
			if bool(data.get("ok", false)) and data.get("card") is CardData and not _shot_pending:
				_transform_fx.append({"zone": "deck", "start": n, "dur": 460})
		"auto_upgrade":
			# 自主升级 8045（R95，机械之心；R275 改口径）：回合开始随机改造**手牌**里一张
			# 盟友 / 工事。飘字落在手牌区上方 —— 与「过载」（牌库）分开。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var au_card: CardData = data["card"]
				sfx.play("spell")
				_say("✦ 自主升级：手牌里的「%s」被改造（+%d 攻 / +%d 血，本场有效）" % [
						au_card.card_name,
						GameEngine.AUTO_UPGRADE_ATK, GameEngine.AUTO_UPGRADE_HP])
				# R301：卡面染色已表达涨跌 → 飘字只报卡名与被改造，不再写「+N 攻 +N 血」
				_floaters.append({"pos": Vector2(HAND_BASE_X + HAND_BASE_W / 2, HAND_BASE_Y - 10),
						"text": "%s 改造" % au_card.card_name,
						"col": Color("ffc94d"), "start": n, "dur": 2200, "size": 14})
			else:
				_say("自主升级：手牌里没有盟友 / 工事，本回合落空")
		"scout_aura":
			# 「侦察塔」8032 光环易伤（R120）：攻击范围内的敌人受到**任何来源**的伤害 +N。
			# ⚠️ 飘字落在**受害者那一格** —— 加的是「敌人受到的伤害」，不是塔自己的攻击力
			# （「改造给塔加攻」的旧口径已废，见 GameEngine._upgrade_atk_gain）。
			var sa_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var sa_bonus := int(data.get("bonus", 0))
			if sa_cell.x >= 0 and sa_bonus > 0:
				_floaters.append({"pos": _cell_center(sa_cell) + Vector2(0, -18), "sc": _grid_scroll,
						"text": "光环 +%d" % sa_bonus, "col": Color("e08a2e"),
						"start": n, "dur": 1100})
		"upgrade":
			# 「升级」8027（R82）/ 改造工厂 8037（R88）：改造一个盟友 / 工事 → 在**那一格**上飘字。
			# ⚠️ 「升级」技能与改造工厂**共用这个事件**，所以提示要按 `field` 字段分文案 ——
			# 不然改造工厂的每回合结算会显示成「◆ 升级：…」，玩家以为自己在打「升级」那张牌。
			sfx.play("spell")
			var ug_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var ug_name := "?"
			if data.get("card") is CardData:
				ug_name = (data["card"] as CardData).card_name
			var ug_atk := int(data.get("atk", 0))
			var ug_hp := int(data.get("hp", 0))
			var ug_affix := str(data.get("affix", ""))
			# R269：纯挂字段的改造（共享护盾）不该飘「+0攻 +0血」—— 数值没动，飘了等于骗人。
			var ug_txt := "%s 获得「%s」" % [ug_name, ug_affix] if ug_atk == 0 and ug_hp == 0 \
					and ug_affix != "" else "%s +%d攻 +%d血" % [ug_name, ug_atk, ug_hp]
			var ug_from := str(data.get("field", ""))
			if ug_from != "":
				_say("◆ %s：%s（每回合结算，可叠加）" % [ug_from, ug_txt])
			else:
				_say("◆ 升级：%s" % ug_txt)
			if ug_cell.x >= 0:
				# R301（用户口径）：**卡面不再写「+2攻 +10血」这种字** —— 四项数值的涨跌
				# 已由徽章**颜色**表达（高 = 绿 / 低 = 红），完整数值在详情栏（左栏 / 悬停面板）
				# 里。飘字只留「发生了什么」，不重复数字。
				var ug_float: String = ug_txt
				if ug_atk != 0 or ug_hp != 0:
					ug_float = "%s 改造" % ug_name
				_floaters.append({"pos": _cell_center(ug_cell), "sc": _grid_scroll,
						"text": ug_float, "col": Color("8ad4f0"),
						"start": n, "dur": 2200})
		"sys_upgrade":
			# 系统升级 8039（R90）：手牌里一张牌被改造（+1费/+3力/+6血）→ 手牌区飘字。
			# 目标在**手牌**里（不是棋盘），所以落点用整排手牌的中点。
			var su_c = data.get("card", null)
			if su_c is CardData:
				var su_d: CardData = su_c as CardData
				sfx.play("spell")
				_say("◆ 系统升级：%s → %d 费 / %d 攻 / %d 血（本场战斗永久）" % [
					su_d.card_name, su_d.cost, su_d.power, su_d.health])
				# R301：同上 —— 费用与四项数值都由卡面染色 / 数字表达，飘字不重复
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s 改造" % su_d.card_name,
					"col": Color("8ad4f0"), "start": n, "dur": 2000})
			else:
				_say("系统升级：手牌里没有可选的盟友或工事")
			if su_c is CardData and not _shot_pending:
				_transform_fx.append({"slot": int(data.get("hand_index", -1)),
					"zone": "hand", "start": n, "dur": 460})
		"lighten":
			# R269 轻量化（8068）：手牌里一张盟友被改造（-1 费 / +1 移速）→ 手牌区飘字。
			# 目标在**手牌**里（不是棋盘），落点同系统升级 = 整排手牌的中点。
			var li_c = data.get("card", null)
			if li_c is CardData:
				var li_d: CardData = li_c as CardData
				sfx.play("spell")
				_say("◆ 轻量化：%s → %d 费 / 移速 %d（本场战斗永久）" % [
					li_d.card_name, li_d.cost, li_d.move_speed])
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s -1费 +1移速" % li_d.card_name,
					"col": Color("8ad4f0"), "start": n, "dur": 2000})
			else:
				_say("轻量化：手牌里没有可改造的盟友")
			if li_c is CardData and not _shot_pending:
				_transform_fx.append({"slot": int(data.get("hand_index", -1)),
					"zone": "hand", "start": n, "dur": 460})
		"batch_transfer":
			# 批量传输 8040（R90）：手牌全体改造 + 抽 1 张。
			var bt_n := int(data.get("count", 0))
			var bt_drw := int(data.get("draw", 0))
			sfx.play("spell")
			if bt_n > 0:
				_say("◆ 批量传输：%d 张手牌 +1 攻 / +4 血（不加费），抽 %d 张卡" % [bt_n, bt_drw])
			else:
				_say("批量传输：手牌里没有盟友或工事（未改造），仍抽 %d 张卡" % bt_drw)
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
				"text": "批量改造 %d 张 · 抽 %d" % [bt_n, bt_drw],
				"col": Color("8ad4f0"), "start": n, "dur": 2000})
		"inf_armor":
			# 无限装甲（8038，R89）：被改造时供一张 0 费改造牌到手 —— 飘字落在**手牌区上方**，
			# 因为目标在手里、不在场上（与 `fetch_skill` 同一落点）。
			# ⚠️ 这是引擎内部结算（改造 → 供能），不经过任何「玩家动作」入口 ——
			# 界面只管飘字，别在这里再记一次动作。
			var ia_card = data.get("card", null)
			if ia_card is CardData:
				var ia_name: String = (ia_card as CardData).card_name
				sfx.play("draw")
				_say("◆ 无限装甲供能：「%s」入手（在手牌里 %d 费，离开手牌恢复原价）"
					% [ia_name, GameEngine.INF_ARMOR_FEED_COST])
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s · 0 费入手" % ia_name, "col": Color("8ad4f0"),
					"start": n, "dur": 2000})
			else:
				_say("◆ 无限装甲：本次供能落空（手牌已满）")
		"crow_recall":
			sfx.play("place")
			var cr_name := "?"
			if data.get("card") is CardData:
				cr_name = (data["card"] as CardData).card_name
			_say("乌鸦：%s 从弃牌堆回到手牌" % cr_name)
		"whale_pick":
			sfx.play("place")
			var wp_name := "?"
			if data.get("card") is CardData:
				wp_name = (data["card"] as CardData).card_name
			_say("鲸鱼之怒：%s 从弃牌堆回到手牌" % wp_name)
		"endless_pick":
			# 无尽黑暗 9114（R70）：玩家选定弃牌 → 弃牌飘字 + 拿到费用的提示
			sfx.play("destroy")
			var en_name := "?"
			if data.get("card") is CardData:
				en_name = (data["card"] as CardData).card_name
			var en_gain: int = int(data.get("energy", GameEngine.ENDLESS_DARK_ENERGY))
			_say("无尽黑暗：弃掉 %s → 费用 +%d" % [en_name, en_gain])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": "弃 %s　费用 +%d" % [en_name, en_gain],
					"col": Color("6a4a9a"), "size": 15, "start": n, "dur": 2000})
		"rebirth_pick":
			# 新生 9148（R222）：玩家选定消失 → 消失飘字 + 随机卡入手的播报
			sfx.play("destroy")
			var rb_name := "?"
			if data.get("card") is CardData:
				rb_name = (data["card"] as CardData).card_name
			var rb_given := String(data.get("given", ""))
			if rb_given != "":
				_say("新生：%s 消失 → 随机一张「%s」加入手牌" % [rb_name, rb_given])
			else:
				_say("新生：%s 消失" % rb_name)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": "%s 消失" % rb_name,
					"col": Color("3f8f5f"), "size": 15, "start": n, "dur": 2000})
		"revive_recall":
			sfx.play("place")
			var rv_name := "?"
			if data.get("card") is CardData:
				rv_name = (data["card"] as CardData).card_name
			_say("复活术：%s 从弃牌区回到手牌" % rv_name)
		"overhaul_recall":
			sfx.play("place")
			var oh_name := "?"
			if data.get("card") is CardData:
				oh_name = (data["card"] as CardData).card_name
			var oh_hp := int(data.get("hp", 0))
			_say("返修：%s 从弃牌区回到手牌（生命 +%d，本场战斗永久）" % [oh_name, oh_hp])
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s 生命 +%d" % [oh_name, oh_hp],
					"col": Color("8ad4f0"), "start": n, "dur": 2000})
		"shadow_step_recall":
			sfx.play("place")
			var ss_name := "?"
			if data.get("card") is CardData:
				ss_name = (data["card"] as CardData).card_name
			_say("暗影步：%s 从弃牌区回到手牌" % ss_name)
		"golem":
			sfx.play("place")
			_say("魔像术：在己方半场召唤一个魔像")
		"apprentice":
			var ap_name := "?"
			if data.get("card") is CardData:
				ap_name = (data["card"] as CardData).card_name
			_say("魔法学徒：本回合出牌费用 -1；从卡组取到「%s」" % ap_name)
		"aether_roar":
			# 以太咆哮（9063）：全体敌方 -N
			sfx.play("spell")
			var ar_dmg := int(data.get("dmg", 0))
			var ar_hits := int(data.get("hits", 0))
			_shake(6.0, 300)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "以太咆哮 -%d" % ar_dmg,
					"col": Color("7a3fd0"), "start": n, "dur": 1600, "size": 20})
			_say("以太咆哮：%d 个敌人各 -%d" % [ar_hits, ar_dmg] if ar_hits > 0
					else "以太咆哮：场上没有敌人 → 直击敌方 HP -%d" % ar_dmg)
		"space_guard":
			# 空间守护（9064）：离己方 HP 最近的敌人被推回去
			sfx.play("spell")
			var sg_name := "?"
			if data.get("card") is CardData:
				sg_name = (data["card"] as CardData).card_name
			_say("空间守护：%s 后退 %d 格" % [sg_name, int(data.get("steps", 2))])
		"stoneskin":
			_say("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
					int(data.get("add", 0)), int(data.get("left", 0))])
		"stoneskin_hit":
			var sk_left := int(data.get("left", 0))
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "石肤 → 1", "col": Color("6a6a6a"),
					"start": n, "dur": 1600, "size": 18})
			_say("石肤：这次伤害变为 1（原本 %d，还剩 %d 次）" % [
					int(data.get("amount", 0)), sk_left])
		"guard_absorb":
			var ga_name := "?"
			if data.get("card") is CardData:
				ga_name = (data["card"] as CardData).card_name
			_say("%s：%s 替我方 HP 承受 %d 点伤害" % [
					str(data.get("how", "守护")), ga_name, int(data.get("amount", 0))])
		"echo":
			# 回响（9102）：每个敌人各吃 2 伤 + 力量 -1（紫色飘字压在卡上）
			sfx.play("spell")
			var ec_name := "?"
			if data.get("card") is CardData:
				ec_name = (data["card"] as CardData).card_name
			var ec_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": ec_pos, "sc": _grid_scroll, "start": n, "dur": 420,
					"col": Color("8e6cc8"), "big": false})
			_floaters.append({"pos": ec_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "回响 -%d / 力量 -%d" % [int(data.get("dmg", 0)),
							int(data.get("amount", 0))],
					"col": Color("6a4aa0"), "start": n, "dur": 1500, "size": 15})
			_say("回响：%s -%d，力量 -%d" % [ec_name, int(data.get("dmg", 0)),
					int(data.get("amount", 0))])
		"dodge":
			sfx.play("spell")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 62),
					"text": "闪躲：伤害由随机盟友代受",
					"col": UiTheme.KIND_EFFECT, "size": 16, "outline": 6,
					"start": n, "dur": 2200})
			_say("闪躲：本回合你受到的伤害由随机盟友代替承受")
		"dodge_absorb":
			var da_name := "?"
			if data.get("card") is CardData:
				da_name = (data["card"] as CardData).card_name
			var da_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": da_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "闪躲 → %s -%d" % [da_name, int(data.get("absorbed", 0))],
					"col": UiTheme.KIND_EFFECT, "start": n, "dur": 1500, "size": 15})
			_say("闪躲：%s 替我方 HP 承受 %d 点伤害%s" % [
					da_name, int(data.get("absorbed", 0)),
					("（超出 %d 由自己承担）" % int(data.get("rest", 0)))
					if int(data.get("rest", 0)) > 0 else ""])
		"finisher":
			# 收尾（9104）：手卡里仅剩它 → 22 伤（金色大飘字）；平时 6 伤（普通飘字）。
			var fn_last := bool(data.get("last", false))
			var fn_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var fn_pos := _cell_center(fn_cell) if fn_cell.x >= 0 \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H / 2)
			_floaters.append({"pos": fn_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "收尾 -%d" % int(data.get("dmg", 0)),
					"col": UiTheme.STAT_POWER if fn_last else Color("6a4aa0"),
					"outline": 6 if fn_last else 0,
					"start": n, "dur": 1800 if fn_last else 1400,
					"size": 21 if fn_last else 15})
			if fn_last:
				sfx.play("spell")
				_say("收尾：这是你手卡里仅剩的一张 → %d 点伤害（平时只有 4 点）"
						% int(data.get("dmg", 0)))
		"egg_token":
			sfx.play("place")
			var eg_name := "?"
			if data.get("card") is CardData:
				eg_name = (data["card"] as CardData).card_name
			_say("鸭窝：一张「%s」加入手卡" % eg_name)
		"aether_guard":
			_say("以太守卫：效果区 %d 张效果卡 → +%d 力量、+%d 生命" % [
					int(data.get("n", 0)), int(data.get("n", 0)), 2 * int(data.get("n", 0))])
		"demon_fetch":
			var df_name := "?"
			if data.get("card") is CardData:
				df_name = (data["card"] as CardData).card_name
			_say("以太恶魔：从卡组取到「%s」，它的费用 -%d" % [df_name, 2])
		"owl_fetch":
			var ow_name := "?"
			if data.get("card") is CardData:
				ow_name = (data["card"] as CardData).card_name
			_say("猫头鹰：从卡组取到效果卡「%s」" % ow_name)
		"iron_fence":
			var if_name := "铁栅栏"
			if data.get("card") is CardData:
				if_name = (data["card"] as CardData).card_name
			_say("坚固围栏：召唤%s，它替你的 HP 承受伤害" % if_name)
		"knight_grow":
			var kg_name := "鸭子骑士"
			if data.get("card") is CardData:
				kg_name = (data["card"] as CardData).card_name
			var kg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, OWN_HAND_Y - 30)
			_floaters.append({"pos": kg_center + Vector2(0, -24), "sc": _grid_scroll,
					"text": "+%d 攻" % int(data.get("amount", 0)),
					"col": UiTheme.STATE_TAUNT, "start": _now(), "dur": 1500, "size": 20})
			_say("%s 击杀敌人 → 攻击力 +%d（当前 %d）" % [
					kg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"deterrence":
			# 威慑（9057）：立即生效 —— 飘字 + 卡面力量当场变化（持续到下个自己回合开始）
			var dt_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var dt_name := "敌人"
			if data.get("card") is CardData:
				dt_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": dt_center + Vector2(0, -24), "sc": _grid_scroll,
					"text": "威慑 -%d 攻" % int(data.get("amount", 0)),
					"col": Color("b0392f"), "start": n, "dur": 1600, "size": 20})
			_say("威慑：%s 力量 -%d，持续到你下个回合开始（当前 %d）" % [
					dt_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"heph_grow":
			# 锻造（9135，R150）：连续 3 个我方回合没击杀 → 力 +1 / 程 +1。
			# 此前触发瞬间只有引擎日志与「锻 N/3」徽标 —— 画面是哑的；P2-13 统一进跳动。
			var hg_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var hg_name := "赫菲斯托斯"
			if data.get("card") is CardData:
				hg_name = (data["card"] as CardData).card_name
			if hg_cell.x >= 0:
				_floaters.append({"pos": _cell_center(hg_cell) + Vector2(0, -24), "sc": _grid_scroll,
						"text": "锻造 +1 攻 +1 程", "col": UiTheme.STATE_TAUNT,
						"start": n, "dur": 1600, "size": 18})
			_say("%s 锻造：空转 %d 回合 → 力量 +1 / 射程 +1（现 %d 攻 %d 程）" % [
					hg_name, int(data.get("period", 1)),
					int(data.get("power", 0)), int(data.get("range", 0))])
		"night_grow":
			var ng_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var ng_name := "夜鸭"
			if data.get("card") is CardData:
				ng_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": ng_center + Vector2(0, -24), "sc": _grid_scroll,
					"text": "夜行 +%d 攻" % int(data.get("amount", 0)),
					"col": UiTheme.STATE_TAUNT, "start": n, "dur": 1500, "size": 18})
			_say("%s 夜行：回合开始力量 +%d（当前 %d）" % [
					ng_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"mage_grow":
			# 精进（白魔法师 9021）：每个自己的回合开始力量 +1（永久累计，无前置条件）
			var mg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var mg_name := "白魔法师"
			if data.get("card") is CardData:
				mg_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": mg_center + Vector2(0, -24), "sc": _grid_scroll,
					"text": "精进 +%d 攻" % int(data.get("amount", 0)),
					"col": UiTheme.STATE_TAUNT, "start": n, "dur": 1500, "size": 18})
			_say("%s 精进：回合开始力量 +%d（当前 %d）" % [
				mg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"familiar_grow":
			# 使魔之力（9115，R60）：回合开始带「使魔」trait 的单位力量 +1（永久）
			var fg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var fg_name := "使魔鸭子"
			if data.get("card") is CardData:
				fg_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": fg_center + Vector2(0, -24), "sc": _grid_scroll,
					"text": "使魔 +%d 攻" % int(data.get("amount", 0)),
					"col": Color("b06ad6"), "start": n, "dur": 1500, "size": 18})
			_say("%s 使魔之力：回合开始力量 +%d（当前 %d）" % [
				fg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"enemy_growth":
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y - 16),
					"text": "敌方攻击力 %+d" % int(data.get("stacks", 0)),
					"col": UiTheme.SIDE_FOE, "start": _now(), "dur": 1800, "size": 20})
			_say("关卡成长：敌方 %d 个单位攻击力 %+d" % [
					int(data.get("count", 0)), int(data.get("stacks", 0))])
		"self_heal":
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "+%d" % int(data.get("healed", 0)),
					"col": Color("2a9d55"), "start": n, "dur": 1800, "size": 22})
			var _sh := int(data.get("healed", 0))
			var _ph := int(data.get("peach", 0))
			var _src := "自愈 + 黄桃罐头" if _ph > 0 and _sh > _ph\
				else ("黄桃罐头" if _ph > 0 else "自愈")
			_say("%s：战斗结束回复 %d 点生命（剩余 %d）" % [
					_src, _sh, int(data.get("hp", 0))])
		"destroy":
			var center := _cell_center(data["cell"])
			# 若这是一次攻击动画的目标：等弹体命中后再演出击破，
			# 否则会出现「卡牌先消失、伤害数字后出现」的时序倒错。
			var delay_ms := 0
			for a: Dictionary in _attacks.values():
				if (a["dst"] as Vector2) == center:
					delay_ms = maxi(delay_ms,
							int(a["start"]) + int(ATK_IMPACT_T * int(a["dur"])) - n)
			var cell: Vector2i = data["cell"]
			# 无论哪种死法，都让这张卡在原位多留一小会儿：
			# 命中瞬间先闪红/掉血，稍后卡片才真正消失并播击破。
			var hide_at := n + delay_ms + DESTROY_HOLD_MS
			_dying.append({"cell": cell, "card": data["card"],
					"p": data.get("placement"), "hide_at": hide_at})
			_delayed.append({"at": hide_at, "kind": "destroy_fx",
					"data": {"center": center, "sc": _grid_scroll,
							"card": data["card"], "cell": cell}})
		"funeral":
			# R327 送葬（9175）：**任意一方**单位被破坏 → 抽 1 张卡。抽牌本身有手牌动画，
			# 这里只在手牌上方飘一句「送葬 +N 张」，让玩家知道这张牌是**效果卡**给的。
			var fn_drawn := int(data.get("drawn", 0))
			if fn_drawn > 0:
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 62),
						"text": "送葬 +%d 张" % fn_drawn,
						"col": UiTheme.KIND_EFFECT, "start": n, "dur": 1600, "size": 20})
		"blast":
			# 爆炎鸭亡语 / 爆炸陷阱（R50）：尸体周围四格炸出的火焰（不分敌我）—— 同特效同源。
			# 起播稍微延后一点，读起来就是「先倒下 → 再爆开」。
			sfx.play("destroy")
			var bwhen := n + 120
			for c2 in data.get("cells", []):
				_bursts.append({"pos": _cell_center(c2 as Vector2i), "sc": _grid_scroll, "start": bwhen,
						"dur": 620, "col": Color("ff8a3d"), "big": true})
			var blast_center := _cell_center(data["center"])
			_floaters.append({"pos": blast_center + Vector2(0, -18), "sc": _grid_scroll,
					"text": "%s -%d" % [str(data["card"].card_name), int(data.get("amount", 0))],
					"col": Color("d84a12"), "start": bwhen, "dur": 1400, "size": 20})
			_shake(8.0, 360)
			_say("💥 %s 死亡爆炸：周围四格各 -%d" % [
					str(data["card"].card_name), int(data.get("amount", 0))])
		"trap_hit":
			# 冰霜 / 冻结陷阱（R51）：攻击者踩陷阱吃直伤 —— 蓝白火花 + 飘字（同源同特效）
			sfx.play("destroy")
			var th_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": th_pos, "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("7ec8ff"), "big": false})
			_floaters.append({"pos": th_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "%s -%d" % [str(data.get("kind", "陷阱")), int(data.get("amount", 0))],
					"col": Color("2b6fb3"), "start": n, "dur": 1400, "size": 18})
		"frozen":
			# 冰封（R68）：寒冰箭 9011 / 冰冻术士战吼 / 冻结陷阱 8013 的**唯一**施加特效。
			# 判据与常驻光环同源（引擎的 Placement.frozen），这里只演「施加的那一下」。
			var fz_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fz_pos, "sc": _grid_scroll, "start": n, "dur": 620,
					"col": Color("9ad8ff"), "big": false})
			_bursts.append({"pos": fz_pos, "sc": _grid_scroll, "start": n + 90, "dur": 520,
					"col": Color("e8f6ff"), "big": false})
			_floaters.append({"pos": fz_pos + Vector2(0, -14), "sc": _grid_scroll, "text": "冰封",
					"col": Color("2b6fb3"), "start": n, "dur": 1500, "size": 20})
			_say("❄ %s 被冰封：下回合不能行动" % str(data.get("name", "")))
		"stun":
			# R341 惊奇盒子（9179）：攻击者被眩晕 —— 金黄爆点 + 「眩晕」飘字。
			# 常驻状态本身由 Placement.stun_left 画（状态栏 / 徽标），这里只演「施加的那一下」。
			var st_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": st_pos, "sc": _grid_scroll, "start": n, "dur": 560,
					"col": Color("f0c040"), "big": false})
			_floaters.append({"pos": st_pos + Vector2(0, -14), "sc": _grid_scroll,
					"text": "眩晕", "col": Color("8a6d1f"), "start": n, "dur": 1500, "size": 20})
			_say("💫 %s 被眩晕：下回合不能行动" % str(data.get("name", "")))
		"poison":
			# 剧毒陷阱（R51）：挂毒（apply）与回合开始的毒跳 —— 绿泡 + 飘字
			var po_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": po_pos, "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("79c26a"), "big": false})
			if bool(data.get("apply", false)):
				_floaters.append({"pos": po_pos + Vector2(0, -12), "sc": _grid_scroll, "text": "中毒",
						"col": Color("3e8a2f"), "start": n, "dur": 1400, "size": 18})
				_say("☠ %s 中毒：每回合 %d 点伤害，持续 %d 回合" % [
						str(data.get("name", "")), int(data.get("dmg", 0)),
						int(data.get("left", 0))])
			else:
				_floaters.append({"pos": po_pos + Vector2(0, -12), "sc": _grid_scroll,
						"text": "中毒 -%d" % int(data.get("amount", 0)),
						"col": Color("3e8a2f"), "start": n, "dur": 1400, "size": 18})
		"hunt":
			# 暗影狩猎（9107，R52）：紫色爆点 —— 基础 16 伤；目标上回合触发过场地 → 30（金紫大字）
			sfx.play("spell")
			var hu_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			var hu_big := bool(data.get("big", false))
			_bursts.append({"pos": hu_pos, "sc": _grid_scroll, "start": n, "dur": 560,
					"col": UiTheme.RARITY_EPIC, "big": hu_big})
			_floaters.append({"pos": hu_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": ("狩猎翻倍！-%d" if hu_big else "暗影狩猎 -%d")
							% int(data.get("dmg", 0)),
					"col": UiTheme.RARITY_EPIC, "start": n, "dur": 1400,
					"size": 22 if hu_big else 18})
		"field_place":
			# 场地卡（R74）放置：斜纹格亮一下 + 提示挂在哪一格
			var fp_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var fp_pos := _cell_center(fp_cell)
			var fp_persist := GameEngine.is_persistent_field(data.get("card", null) as CardData)
			# 持续型场地（R83）用冷色 + 「持续生效」字样，别用一次性场地的「场地就位」。
			var fp_col := COL_FIELD_PERSIST if fp_persist else (
					COL_FIELD_SELF if str(data.get("side", GameEngine.SIDE_SELF)) == GameEngine.SIDE_SELF
					else COL_FIELD_FOE)
			# R116：亡语落下的陷阱（捕兽大师 9126）飘字区分一下 —— 否则玩家会以为
			# 是自己什么时候放的。同一个 `field_place` 事件，靠 `deathrattle` 标记分流。
			var fp_text := "持续生效" if fp_persist else "场地就位"
			if bool(data.get("deathrattle", false)):
				fp_text = "亡语 · 陷阱就位"
			_floaters.append({"pos": fp_pos + Vector2(0, -6), "sc": _grid_scroll,
					"text": fp_text,
					"col": fp_col, "start": n, "dur": 1200, "size": 15})
			_bursts.append({"pos": fp_pos, "sc": _grid_scroll, "start": n, "dur": 420,
				"col": fp_col, "big": false})
			if fp_persist:
				# 持续型场地（R83 清泉 / R88 维修间·改造工厂）：不会因经过而触发 →
				# 别说「移动经过时触发」，否则玩家会以为敌人走过去就把它引爆了。
				# 同样要**按生效对象分文案**：「友」的话明说只治自己人。
				var fpc := data.get("card", null) as CardData
				var fp_who := "只对自己的单位生效"
				if GameEngine.field_aim(fpc) == GameEngine.FIELD_AIM_ALLY:
					fp_who = "只对自己的单位生效"
				else:
					fp_who = "敌我双方都算"
				var fp_what := "站在这里的单位在自己回合结束时回血"
				if fpc.traits.has(GameEngine.PERSIST_UPGRADE_TRAIT):
					fp_what = "每回合获得改造 +1 力 / +1 血（可无限叠）"
				_say("%s → %s（持续生效：%s，%s）" % [
					fpc.card_name, fp_cell, fp_what, fp_who])
			else:
				_say("%s → %s（敌人移动经过时触发并停止移动）" % [
					str((data.get("card", null) as CardData).card_name), fp_cell])
		"fountain":
			# 持续型场地回血（清泉 8028 / 维修间 8036，R88）：自己回合结束时给站着的单位回血
			# → 该格飘字。`field` 带场地名（维修间与清泉共用这个事件）。
			sfx.play("heal")
			var fo_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": fo_pos, "sc": _grid_scroll, "text": "+%d" % int(data.get("amount", 0)),
					"col": COL_FIELD_PERSIST, "start": n, "dur": 1400, "size": 18})
		"field_trigger":
			# 场地触发（R74；R80 扩为「经过即触发」）：敌人移动路上撞到 → 一次性结算
			_say("⚡ 场地触发：%s 踩到了 %s（移动已停止）" % [str(data.get("name", "")),
				str((data.get("card", null) as CardData).card_name)])
			sfx.play("destroy")
		"charge":
			# 蓄力（9085）：攒一层 —— 下一张技能生效 N+1 次（金色提示，压在技能结算飘字上方）
			sfx.play("spell")
			var ch_n: int = int(data.get("count", 0))
			_say("⚡ 蓄力 ×%d：下一张技能生效 %d 次" % [ch_n, ch_n + 1])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 62),
					"text": "蓄力 ×%d → 下一张技能生效 %d 次" % [ch_n, ch_n + 1],
					"col": UiTheme.STAT_POWER, "size": 16, "outline": 6,
					"start": n, "dur": 2200})
		"bear_heal":
			# 熊（8004）发动回春：绿色爆点 + 「+N」飘字
			sfx.play("place")
			var bh_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": bh_pos, "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("4caf50"), "big": false})
			_floaters.append({"pos": bh_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "回春 +%d" % int(data.get("amount", 0)),
					"col": UiTheme.KIND_EFFECT, "start": n, "dur": 1400, "size": 18})
			_say("❦ %s 发动回春：回复 %d 点生命，之后横置" % [
					str(data.get("name", "熊")), int(data.get("amount", 0))])
		"wild_form_guard":
			# 荒野形态（6022，R60 重做）：每场第一次我方 HP 被普通攻击打中 →
			# 这次伤害 -4（最少 1）+ 对攻击者反伤 4。
			var wg_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": wg_pos, "sc": _grid_scroll, "start": n, "dur": 560,
					"col": Color("4caf50"), "big": true})
			_floaters.append({"pos": wg_pos + Vector2(0, -30), "sc": _grid_scroll,
					"text": "荒野形态 减伤 %d" % int(data.get("reduced", 0)),
					"col": Color("7fd18a"), "start": n, "dur": 1500, "size": 17})
			_floaters.append({"pos": wg_pos + Vector2(0, -8), "sc": _grid_scroll,
					"text": "反伤 %d" % int(data.get("amount", 0)),
					"col": Color("e07a6a"), "start": n, "dur": 1500, "size": 19})
			_say("❦ 荒野形态（每场第一次）：我方伤害 -%d，并对 %s 造成 %d 点伤害" % [
					int(data.get("reduced", 0)), str(data.get("name", "敌人")),
					int(data.get("amount", 0))])
		"phantom_cloak":
			# 幻影斗篷（6023，暗影刺客角色道具）：R60 起每使用**两张**牌 → 随机敌方单位力量 -1
			var pc_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": pc_pos, "sc": _grid_scroll, "start": n, "dur": 420,
					"col": Color("7e57c2"), "big": false})
			_floaters.append({"pos": pc_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "幻影斗篷 力量 -%d" % int(data.get("amount", 0)),
					"col": Color("5e35b1"), "start": n, "dur": 1400, "size": 17})
			_say("❧ 幻影斗篷：本回合每用一张牌 → %s 力量 -%d（当前 %d）" % [
					str(data.get("name", "敌人")), int(data.get("amount", 0)),
					int(data.get("power", 0))])
		"meteor":
			# 流星雨（9083）：每一颗的落点（引擎给 cell）—— 紫色爆点 + 伤害飘字
			var m_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_fx_unqueue_hit(m_cell)   # R288b：本格已有专属落点爆点 → 撤掉通用那一次
			var m_pos := _cell_center(m_cell) if m_cell.x >= 0 \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y - 36)
			_bursts.append({"pos": m_pos, "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("9b59d0"), "big": false})
			_floaters.append({"pos": m_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "-%d" % int(data.get("dmg", 0)),
					"col": UiTheme.KIND_SKILL, "start": n, "dur": 1200})
		"fire_wall":
			# 火墙术（9084）：整行燃起 —— 三格同时起火 + 一行提示
			sfx.play("spell")
			var fw_row2: int = int(data.get("row", -1))
			for fw_col in FieldState.BOARD_COLS:
				_bursts.append({"pos": _cell_center(Vector2i(fw_row2, fw_col)), "sc": _grid_scroll,
						"start": n, "dur": 620, "col": Color("ff8a3d"), "big": false})
			_shake(6.0, 300)
			var fw_name := "火墙术"
			if data.get("card") is CardData:
				fw_name = (data["card"] as CardData).card_name
			_say("🔥 %s：第 %d 行燃起火墙（经过者 -%d，同一单位上限 %d）" % [
					fw_name, fw_row2, GameEngine.FIRE_WALL_PASS_DMG,
					GameEngine.FIRE_WALL_CAP])
		"fire_wall_hit":
			# 火墙开场那一炸：橙色爆点 + 伤害飘字
			var fh_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fh_pos, "sc": _grid_scroll, "start": n, "dur": 560,
					"col": Color("ff6a00"), "big": false})
			_floaters.append({"pos": fh_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "-%d" % int(data.get("dmg", 0)),
					"col": Color("d84a12"), "start": n, "dur": 1200})
		"fire_wall_pass":
			# 穿过燃烧横行的单位被灼烧（不分敌我）
			var fp_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fp_pos, "sc": _grid_scroll, "start": n, "dur": 560,
					"col": Color("ff8a3d"), "big": false})
			_floaters.append({"pos": fp_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "火墙 -%d" % int(data.get("dmg", 0)),
					"col": Color("d84a12"), "start": n, "dur": 1300, "size": 18})
		"stun_blow":
			# 敲晕（9088）：目标力量 -3（金色爆点 + 飘字）
			var sb_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": sb_pos, "sc": _grid_scroll, "start": n, "dur": 480,
					"col": Color("ffd54f"), "big": false})
			_floaters.append({"pos": sb_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "敲晕 力量 -%d" % int(data.get("amount", 0)),
					"col": UiTheme.STAT_POWER, "start": n, "dur": 1300, "size": 16})
		"dark_trap":
			# 黑暗陷阱（8063，R105）：踩中者本回合攻击时力量 -1（暗紫爆点 + 飘字）
			var dt_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": dt_pos, "sc": _grid_scroll, "start": n, "dur": 480,
					"col": Color("9b6bd6"), "big": false})
			_floaters.append({"pos": dt_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "黑暗 力量 -%d" % int(data.get("amount", 0)),
					"col": Color("6a3fa0"), "start": n, "dur": 1300, "size": 16})
		"gale":
			# 疾风（9091）：随机敌人吃 2 伤
			var ga_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": ga_pos, "sc": _grid_scroll, "start": n, "dur": 420,
					"col": Color("9bdcff"), "big": false})
			_floaters.append({"pos": ga_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "疾风 -%d" % int(data.get("dmg", 0)),
					"col": Color("2a7ab8"), "start": n, "dur": 1200})
		"lurker":
			# 潜影者（8009）：每用一张牌 +1 力量
			var lk_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": lk_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "潜影者 +1 力量",
					"col": Color("6a4fb8"), "start": n, "dur": 1100, "size": 15})
		"attack_energy":
			# 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时回复费用
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 12),
					"text": "%s · 攻击时费用 +%d" % [str(data.get("name", "")),
						int(data.get("amount", 0))],
					"col": Color("2f9e5e"), "start": n, "dur": 1500})
			sfx.play("heal")
		"dark_spread":
			# 黑暗扩散 9113：剩余费用换算的全体敌人伤害
			var ds_dmg := int(data.get("dmg", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 24),
					"text": "黑暗扩散 · 剩余 %d 费用 → 全体敌人 -%d"
						% [int(data.get("left", 0)), ds_dmg],
					"col": Color("5a2a8a"), "start": n, "dur": 2000})
			sfx.play("attack")
		"endless_dark":
			# 无尽黑暗 9114（R70）：不再随机弃牌，改为**开面板让玩家选**。
			# pending=true → 只提示「请选一张」；pending=false 且能量 0 → 手牌为空、本回合落空。
			if bool(data.get("pending", false)):
				_say("∞ 无尽黑暗：请从手牌里选 1 张弃掉（不能不选）→ 之后费用 +%d"
						% int(data.get("energy", 0)))
			elif int(data.get("energy", 0)) > 0:
				_say("∞ 无尽黑暗：费用 +%d" % int(data.get("energy", 0)))
			else:
				_say("∞ 无尽黑暗：手牌为空，没有可弃的牌 → 本回合不弃也不给费用")
		"rebirth":
			# 新生 9148（R222）：抽牌之后开面板让玩家选一张手牌消失（不能不选）。
			# pending=true → 只提示「请选一张」；pending=false → 手牌为空，本回合落空。
			if bool(data.get("pending", false)):
				var rb_copies := int(data.get("copies", 1))
				if rb_copies > 1:
					_say("∞ 新生（%d 张）：请从手牌里选 1 张使其消失（不能不选）→ 之后随机一张本职业奖励卡加入手牌"
							% rb_copies)
				else:
					_say("∞ 新生：请从手牌里选 1 张使其消失（不能不选）→ 之后随机一张本职业奖励卡加入手牌")
			else:
				_say("∞ 新生：手牌为空，没有可消失的牌 → 本回合不触发")
		"dark_lord":
			# 黑暗领主（8021）：回合结束优先结算 → 费用 +5
			var dl_energy := int(data.get("amount", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "黑暗领主 · 回合结束费用 +%d" % dl_energy,
					"col": Color("8a2be2"), "start": n, "dur": 2000})
			sfx.play("heal")
		"dark_blade":
			# 暗影之刃（9111）：按本回合已花费用对随机敌人造成伤害
			var db_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_floaters.append({"pos": _cell_center(db_cell) + Vector2(0, -12), "sc": _grid_scroll,
					"text": "暗影之刃 -%d" % int(data.get("dmg", 0)),
					"col": Color("6a4aa0"), "start": n, "dur": 1600, "size": 17})
			_bursts.append({"pos": _cell_center(db_cell), "sc": _grid_scroll, "start": n, "dur": 460,
					"col": Color("6a4aa0"), "big": false})
			sfx.play("attack")
		"dark_chain":
			# 暗影锁链（9112）：击退提示（_knockback 自己会 emit "move" 播移动动画）
			var dc_times := int(data.get("times", 0))
			var dc_moved := int(data.get("moved", 0))
			if dc_times > 0:
				_say("⛓ 暗影锁链：剩余费用换算 %d 次击退（每次 2 格），实际移动 %d 次"
						% [dc_times, dc_moved])
		"surplus":
			# 回合结束 · 剩余费用（R55）：地狱猫 8019 / 鲜血堡垒 8020 永久成长
			var sp_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var sp_pos := _cell_center(sp_cell)
			_floaters.append({"pos": sp_pos + Vector2(0, -12), "sc": _grid_scroll,
					"text": "+%d 力 +%d 生" % [int(data.get("atk", 0)), int(data.get("hp", 0))],
					"col": Color("c0392b"), "start": n, "dur": 1500, "size": 16})
			sfx.play("heal")
		"vitality":
			# 活力转移（9110）：上回合结转的额外费用在本回合开始发放
			var vt_side := str(data.get("side", GameEngine.SIDE_SELF))
			var vt_pos := Vector2(GRID_X + GRID_W / 2, GRID_Y - 12) \
					if vt_side == GameEngine.SIDE_SELF \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 24)
			_floaters.append({"pos": vt_pos,
					"text": "活力转移 · 本回合费用 +%d" % int(data.get("energy", 0)),
					"col": Color("2f9e5e"), "start": n, "dur": 2100})
			sfx.play("heal")
		"lighten_set":
			# 负重减轻（8066，R201）：选卡消失完成 → 提示「下个回合多抽一张」
			var ls_side := str(data.get("side", GameEngine.SIDE_SELF))
			var ls_pos := Vector2(GRID_X + GRID_W / 2, GRID_Y - 12) \
					if ls_side == GameEngine.SIDE_SELF \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 24)
			_floaters.append({"pos": ls_pos,
					"text": "👻 负重减轻 · 下回合多抽 %d 张" % int(data.get("draw", 0)),
					"col": Color("6a4aa0"), "start": n, "dur": 2100})
		"lighten_draw":
			# 负重减轻（8066，R201）：回合开始正式发放额外抽牌
			var ld_pos := Vector2(GRID_X + GRID_W / 2, GRID_Y - 12)
			_floaters.append({"pos": ld_pos,
					"text": "👻 负重减轻 · 多抽 %d 张" % int(data.get("draw", 0)),
					"col": Color("6a4aa0"), "start": n, "dur": 2100})
			sfx.play("heal")
		"contractor":
			# 契约签订者（8024，R63）：登场回 4 费 + 本回合手卡全体涨价 4
			var ct_pos:= _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ct_pos + Vector2(0, -18), "sc": _grid_scroll,
				"text": "契约签订者 +%d 费" % int(data.get("energy", 0)),
				"col": Color("8a2be2"), "start": n, "dur": 1800, "size": 17})
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 60),
				"text": "本回合手卡费用 +%d" % int(data.get("raise", 0)),
				"col": UiTheme.STAT_POWER, "start": n, "dur": 2200, "size": 16})
			sfx.play("heal")
		"earring_autoplay_begin":
			# 鸭语耳环自动出牌开始（R77）：横幅提示 + 复位播放状态。
			_earring_at = _now()
			_earring_i = 0
			_earring_done = false
			_banner = {"text": "鸭语耳环 · 自动出牌", "col": UiTheme.STATE_SLEEP,
					"start": _now(), "dur": 1600}
			status_text = "鸭语耳环：第 1 回合抽牌后开始自动出牌（会一张一张出）"
			_say("鸭语耳环：自动出牌开始（逐张播放）")
		"earring_autoplay_step":
			# 每出一张：飘出「第 N 张 · 卡名」，玩家能看清到底出了什么。
			var es_name: String = str(data.get("card_name", "?"))
			var es_i: int = int(data.get("total", 0))
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y + 26),
					"text": "自动出牌 %d · %s" % [es_i, es_name],
					"col": Color("c9a0f0"), "start": n, "dur": 1100, "size": 20})
		"earring_autoplay_end":
			# 收尾：横幅换成完成提示，解锁玩家操作。
			_earring_done = true
			var ee_why: String = str(data.get("why", ""))
			var ee_played: int = int(data.get("played", 0))
			_banner = {"text": "鸭语耳环 · 自动出牌 %d 张" % ee_played,
					"col": UiTheme.STATE_SLEEP, "start": _now(), "dur": 1500}
			status_text = "鸭语耳环：自动出牌结束（%d 张 · %s），可以行动了" % [ee_played, ee_why]
			_say("♬ 鸭语耳环：自动出牌 %d 张结束（%s）" % [ee_played, ee_why])
			# R151 P0-2：连出期间压下的飞出 —— 超过 3 张时合并成一次整体淡出（别一张一张等）
			if _earring_missed > 3 and not _shot_pending:
				_hand_fly.append({"mode": "fade", "start": n, "dur": 300})
			_earring_missed = 0
		"wake":
			# 恶魔鸭（9116，R63 / R72 补特效）：沉睡结束 / 被击中提前醒来。
			# R72：原来只有一圈爆点 + 飘字，「挣脱束缚」的观感不足；补一圈向外扩散的
			# 紫色冲击环（从卡面中心扩散出去），和常驻的沉睡环在颜色上呼应 ——
			# 玩家扫一眼就知道「刚才那圈紫的就是这个状态，现在它没了」。
			var wk_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var wk_pos:= _cell_center(wk_cell)
			var wk_txt := "恶魔鸭 苏醒"
			var wk_col := Color("9b6bff")
			if bool(data.get("hurt", false)):
				wk_txt = "恶魔鸭 提前醒来"
				wk_col = Color("d84a12")
			# 挣脱环：2 圈错峰扩散的描边圆（不是实心块，保留卡面可读性）
			for _wi in 2:
				_wake_rings.append({"pos": wk_pos, "sc": _grid_scroll, "start": n + _wi * 130,
					"dur": 620, "col": wk_col})
			_floaters.append({"pos": wk_pos + Vector2(0, -18), "sc": _grid_scroll, "text": wk_txt,
				"col": wk_col, "start": n, "dur": 1600, "size": 17})
			_bursts.append({"pos": wk_pos, "sc": _grid_scroll, "start": n, "dur": 520,
				"col": wk_col, "big": false})
			sfx.play("attack")
		"demon_rage":
			# 恶魔鸭（9116）：醒着受伤 → 永久 +1 力量
			var dr_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_floaters.append({"pos": _cell_center(dr_cell) + Vector2(0, -18), "sc": _grid_scroll,
				"text": "恶魔鸭 力量 +%d（%d）" % [int(data.get("amount", 0)),
					int(data.get("power", 0))],
				"col": Color("c0392b"), "start": n, "dur": 1600, "size": 16})
			sfx.play("attack")
		"demon_revenge":
			# 恶魔鸭（复仇）9118：每次受伤 → **本回合**力量 +1（可叠加）。
			# 与 9116 的 `demon_rage`（永久 +1）刻意区分：这里飘的是**累计值**
			#（"本回合 +3"），让玩家一眼看到"我打得多，它就疼得多"，
			# 从而意识到「这一回合得收手了」——这是这只 Boss 的核心决策点。
			var rv_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var rv_pos := _cell_center(rv_cell)
			_floaters.append({"pos": rv_pos + Vector2(0, -18), "sc": _grid_scroll,
				"text": "复仇 本回合 +%d（力量 %d）" % [int(data.get("stacked", 0)),
					int(data.get("power", 0))],
				"col": Color("ff5722"), "start": n, "dur": 1500, "size": 16})
			_bursts.append({"pos": rv_pos, "sc": _grid_scroll, "start": n, "dur": 460,
				"col": Color("ff8a3d"), "big": false})
			sfx.play("attack")
		"demon_summon":
			# 恶魔使魔（9117）：每回合开始随机空格召唤使魔鸭子
			var dm_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_bursts.append({"pos": _cell_center(dm_cell), "sc": _grid_scroll, "start": n, "dur": 560,
				"col": Color("9b6bff"), "big": true})
			_floaters.append({"pos": _cell_center(dm_cell) + Vector2(0, -22), "sc": _grid_scroll,
				"text": "恶魔使魔 召唤", "col": Color("6a3fb5"),
				"start": n, "dur": 1700, "size": 16})
			sfx.play("spell")
		"whirl_blade":
			# 回旋斩（9096）：十字命中提示
			_say("🌀 回旋斩：命中 %d 个敌方单位（各 %d 伤）" % [
					int(data.get("hits", 0)), int(data.get("dmg", 0))])
		"infiltrate":
			# 潜入（9100）：移动 + 本回合力量 +3
			_say("❧ 潜入：%s 移动 → 本回合力量 +%d（当前 %d）" % [
					str(data.get("name", "盟友")), int(data.get("amount", 0)),
					int(data.get("power", 0))])
		"latent":
			# 潜伏（9092）：回合开始多抽
			_say("🌙 潜伏：回合开始多抽 1 张「%s」" % str(data["card"].card_name))
		"glowgrass":
			# 幽光（9099）：荧光草塞进手卡
			_say("🌿 幽光：一张「荧光草」加入手卡")
		"ghost_fetch":
			var ghf_c = data.get("card")
			_say("👻 幽灵消散：%s" % (("「%s」加入手卡" % ghf_c.card_name) if ghf_c != null else "卡组里没有技能卡"))
		"sleepless":
			# 不眠（9101）：没手牌时补抽
			_say("🌙 不眠：手里没牌 → 抽 1 张「%s」" % str(data["card"].card_name))
		"shadow_cat":
			var sc_c = data.get("card")
			_say("🐈 影子猫：%s" % (("「%s」加入手卡" % sc_c.card_name) if sc_c != null else "卡组里没有技能卡"))
		"shadow_demon":
			# 影魔（8007）：技能牌 -1 费 + 0 费技能卡加生命
			_say("😈 影魔：手卡技能牌本回合 -1 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）" % [
					int(data.get("zero", 0)), int(data.get("gained", 0)),
					int(data.get("health", 0))])
		"foresight":
			var fs_c = data.get("card")
			_say("🔮 预判②：%s" % (("「%s」加入手卡" % fs_c.card_name) if fs_c != null else "卡组里没有非 0 费技能卡"))
		"foresight_pick":
			_say("🔮 预判：%s 回到手卡（本卡已消失）" % str(data["card"].card_name))
		"fate":
			# 拒绝命运 9098（R292）：丢光手卡 → 弃牌区所有 0/1 费卡按顺序回手（自动结算）。
			var ft_n := int(data.get("picked", 0))
			sfx.play("draw")
			if ft_n > 0:
				_say("🃏 拒绝命运：丢 %d 张，捞回 %d 张 0/1 费卡" % [
						int(data.get("discarded", 0)), ft_n])
			else:
				_say("🃏 拒绝命运：丢 %d 张，弃牌区没有 0/1 费卡" % int(data.get("discarded", 0)))
		"alert":
			# 警觉（9109，R54）：随机工事进手，那张卡费用 -2
			var al_c = data.get("card")
			var al_name: String = al_c.card_name if al_c != null else "?"
			var al_disc := int(data.get("discount", 0))
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y + GRID_H - 60),
					"text": "警觉 · %s -%d 费" % [al_name, al_disc],
					"col": UiTheme.KIND_SKILL, "start": n, "dur": 1800, "size": 18})
			_say("🃏 警觉：随机工事「%s」进入手卡（费用 -%d）" % [al_name, al_disc])
		"inspire":
			# R300 激发 8077：一张卡被改造 → 对所有敌人造成 3 点伤害（可叠加）。
			# 它是效果卡、作用对象是**全体**，所以飘字放在棋盘上沿中线，不绑某一格。
			sfx.play("click")
			var in_n := int(data.get("count", 0))
			var in_d := int(data.get("dmg", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
					"text": "激发 · 全体 -%d%s" % [in_d, (" ×%d" % in_n) if in_n > 1 else ""],
					"col": Color("a05ad0"), "size": 17, "start": n, "dur": 1600})
		"reflex":
			# R317 身法 9173：抽 5 张，但本回合不能再用盟友 / 工事卡。
			_say("◇ 身法：抽 %d 张 —— 本回合不能再使用盟友和工事卡"
					% int(data.get("drawn", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
					"text": "身法 · 本回合禁用盟友/工事",
					"col": Color("b9a6ff"), "size": 15, "start": n, "dur": 1700})
		"eliminate_pending":
			# R317 淘汰 9174：面板由 `_sync_pick` 自动弹（engine.eliminate_pending）。
			_say("◆ 淘汰：抽 %d 张 —— 从卡组选一张盟友或工事变成素体"
					% int(data.get("drawn", 0)))
		"hidden_energy":
			# R331 隐藏能源 8078：单位入场 → 改造 +1 层，并获得「死亡」。
			var he_c: CardData = data.get("card", null)
			var he_st := int(data.get("stacks", 0))
			_say("◈ 隐藏能源：%s 改造 +%d 层 +「死亡」" % [
					he_c.card_name if he_c != null else "单位", he_st])
		"hidden_energy_death":
			# R331 隐藏能源 8078：被挂过「死亡」的单位被破坏 → 距离 1 随机一个敌人 8 伤。
			var hd_a := int(data.get("amount", 0))
			var hd_c: CardData = data.get("card", null)
			var hd_t: Vector2i = data.get("target", Vector2i(0, 0))
			_say("◈ 隐藏能源：距离 1 的敌人 -%d" % hd_a)
			_floaters.append({"pos": _cell_center(hd_t), "text": "隐藏能源 -%d" % hd_a,
					"col": Color("c07ad0"), "size": 16, "start": n, "dur": 1600})
		"surprise":
			# R331 惊喜运单 8079：回合开始开面板（由 `_sync_pick` 自动弹）。
			_say("◈ 惊喜运单：从卡组选一张卡 → 变成随机卡并加入手卡")
		"instinct":
			# R332 本能 9176：随机打出抽牌库中 3 张 ≤1 费技能卡（免费打出）。
			# 状态栏只写张数（264px ≈ 19 全角字），卡名列表走飘字。
			var in_cards: Array = data.get("cards", [])
			_say("◈ 本能：随机打出 %d 张技能卡" % in_cards.size())
			if not in_cards.is_empty():
				var in_names: Array[String] = []
				for _in in in_cards:
					in_names.append(str(_in))
				_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
						"text": "本能 · " + "、".join(in_names),
						"col": Color("b9a6ff"), "size": 15, "start": n, "dur": 1700})
		"surprise_pick":
			# R331 惊喜运单 8079：选完一张。
			var sp_c: CardData = data.get("card", null)
			if sp_c != null:
				_say("◈ 惊喜运单：变出「%s」%s" % [sp_c.card_name,
						"入手" if bool(data.get("landed", false)) else "（手牌已满 → 进弃牌区）"])
		"rapid":
			# R316 极速 9171：抽到的 0 费张数 → 本回合所有敌人受到伤害 +N。
			var rp_zero := int(data.get("zero", 0))
			var rp_bonus := int(data.get("bonus", 0))
			_say("◆ 极速：抽 %d 张（0 费 %d 张）→ 本回合敌人受到伤害 +%d"
					% [int(data.get("drawn", 0)), rp_zero, rp_bonus])
			if rp_zero > 0:
				_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
						"text": "极速 · 敌人受伤 +%d" % rp_bonus,
						"col": Color("8fd8ff"), "size": 16, "start": n, "dur": 1700})
		"popcorn":
			# R315 爆米花 6046：本回合没用技能指向敌人 → 下回合多抽 1 张。
			# 飘字只写「拿到了什么」，有时间维度（start + dur → 位移 + 淡出）。
			var pc_d := int(data.get("draw", 1))
			_say("◇ 爆米花：没用技能指向敌人 → 下回合多抽 %d 张" % pc_d)
			_floaters.append({"pos": Vector2(WINDOW_W / 2.0, OWN_HAND_Y - 30.0),
					"text": "爆米花 · 下回合 +%d 抽" % pc_d,
					"col": Color("f0d68a"), "size": 15, "start": n, "dur": 1700})
		"lucky7":
			# R314 lucky 7 6045：满 7 回合 → 本轮回免疫 HP 伤害 + 技能 +7。
			# 只演「生效了」这一下：飘字有时长（start + dur → 位移 + 淡出），不是静态贴图。
			sfx.play("click")
			var l7_d := int(data.get("dmg", 7))
			_say("✦ lucky 7：第 %d 个回合生效 —— 本回合免疫所有 HP 伤害，技能额外 +%d"
					% [int(data.get("turns", 0)), l7_d])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 60.0),
					"text": "lucky 7 · 免疫 HP 伤害 / 技能 +%d" % l7_d,
					"col": Color("ffd25a"), "size": 17, "start": n, "dur": 2100})
		"lucky7_immune":
			# 免疫挡下了一笔 HP 伤害：飘在顶栏血量条下方，和掉血飘字区分开
			var imm := int(data.get("amount", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 24.0),
					"text": "lucky 7 · 免疫 %d" % imm,
					"col": Color("ffe08a"), "size": 15, "start": n, "dur": 1500})
		"wind_fairy":
			# R313 风妖精 6042：一回合打出第五张牌 → 对所有敌人 4 点伤害。
			# 作用对象是**全体敌人**，落点放棋盘上沿中线（不绑某一格），与激发 8077 同口径。
			sfx.play("click")
			var wf_d := int(data.get("dmg", 0))
			var wf_n := int(data.get("hits", 0))
			_say("✦ 风妖精：本回合第 5 张牌 → 对所有敌人造成 %d 点伤害（%d 个目标）"
					% [wf_d, wf_n])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2.0, GRID_Y + 34.0),
					"text": "风妖精 · 全体 -%d" % wf_d,
					"col": Color("7fd2a0"), "size": 17, "start": n, "dur": 1900})
		_:
			# R288：兜底 —— 任何**还没有专属表现**的事件，只要带格子，就至少演一次
			# 「脉冲 + 镜头」。以后新加的事件不会再静悄悄发生（这是这套演出的兜底价值）。
			var g_cell = data.get("cell")
			if g_cell is Vector2i and int((g_cell as Vector2i).x) >= 0:
				_push_cue([g_cell], "", Color("8a8f9a"))


func _shake(mag: float, ms: int) -> void:
	## 触发屏幕震动（取更大幅度、更晚截止）。
	_shake_mag = maxf(_shake_mag if _now() < _shake_until else 0.0, mag)
	_shake_until = maxi(_shake_until, _now() + ms)


func _shake_offset() -> Vector2:
	var remain := _shake_until - _now()
	if remain <= 0:
		return Vector2.ZERO
	var t := float(remain) / 380.0  # 相对启动时长的衰减因子（近似）
	var m := _shake_mag * clampf(t, 0.15, 1.0)
	return Vector2(randf_range(-m, m), randf_range(-m, m))


func _draw_flashes() -> void:
	## 受击闪色：在卡片位置叠一层半透明色块（淡出）。
	## 也包括「垂死卡」——它们已离开棋盘，但仍在屏幕上显示到命中演出结束。
	var n := _now()
	var items: Array = []
	for pair: Array in engine.state.iter_board():
		var pl: Placement = pair[1]
		items.append([pl, pair[0], BOARD_CARD_W,
				BOARD_CARD_H])
	for d: Dictionary in _dying:
		if d.get("p") != null:
			items.append([d.p, d.cell, BOARD_CARD_W, BOARD_CARD_H])
	for it: Array in items:
		var p: Placement = it[0]
		if not _flashes.has(p):
			continue
		var fl: Dictionary = _flashes[p]
		var raw := float(n - int(fl.start)) / int(fl.dur)
		if raw <= 0.0:
			continue  # 延迟启动的闪色
		var t := clampf(raw, 0.0, 1.0)
		var cell: Vector2i = it[1]
		var w: float = it[2]
		var h: float = it[3]
		var rect := Rect2(_display_center(p, cell) - Vector2(w, h) / 2.0, Vector2(w, h))
		var col: Color = fl.col
		col.a = 0.62 * (1.0 - t)
		draw_rect(rect, col)
		draw_rect(rect, Color(col.r, col.g, col.b, 0.9 * (1.0 - t)), false, 2.5)


func _draw_bursts() -> void:
	## 打击爆点：扩散环 + 放射火花线。
	var n := _now()
	for b: Dictionary in _bursts:
		var t := clampf(float(n - int(b.start)) / int(b.dur), 0.0, 1.0)
		if t <= 0.0:
			continue
		var pos: Vector2 = _fx_pos(b)
		# ⚠️ 用 `get` 兜底：`_bursts` 是「谁 push 谁负责带键」的松散结构，漏了 `big`
		# 以前会每帧 SCRIPT ERROR（R326 发现嵌合暴君那处一直漏），画错也不要炸画面。
		var big: bool = bool(b.get("big", false))
		var r_max := 52.0 if big else 34.0
		var col: Color = b.col
		# 扩散环（外圈）
		var ring_r := r_max * (0.3 + 0.7 * t)
		col.a = 0.85 * (1.0 - t)
		draw_arc(pos, ring_r, 0.0, TAU, 28, col, 3.0 if big else 2.2)
		# 内圈亮环（前半段）
		if t < 0.5:
			var col2 := Color(1, 1, 1, 0.7 * (1.0 - t * 2.0))
			draw_arc(pos, ring_r * 0.55, 0.0, TAU, 20, col2, 2.0)
		# 放射火花（8 条短线，随时间飞出变短）
		var lines := 10 if big else 7
		var rot0 := (b.pos as Vector2).x * 0.7 + (b.pos as Vector2).y * 1.3  # 固定相位（用烘焙原值：滚动补正不改相位）
		for i in lines:
			var ang := rot0 + TAU * i / lines
			var far := ring_r + 10.0
			var near := far * (0.55 - 0.35 * t)
			var dir := Vector2(cos(ang), sin(ang))
			var lcol := Color(col.r, col.g, col.b, 0.9 * (1.0 - t))
			draw_line(pos + dir * near, pos + dir * far, lcol, 2.0 if big else 1.5)


func _draw_wake_rings() -> void:
	## 恶魔鸭苏醒（R72）：一圈圈向外扩散并淡出的**空心**挣脱环。
	## 为什么不用 _bursts：那个是打击爆点（带放射火花、收缩的内圈），观感是「被打」。
	## 苏醒是「挣脱束缚」，用**只扩张、不收缩、无线条**的环，且比爆点晚画（压在上层）——
	## 常驻的紫色沉睡环正在同一位置消失，这一圈紫色扩散正好接上，状态变化的因果一眼可见。
	var n := _now()
	for r: Dictionary in _wake_rings:
		var t := clampf(float(n - int(r.start)) / int(r.dur), 0.0, 1.0)
		if t <= 0.0:
			continue
		var pos: Vector2 = _fx_pos(r)
		var col: Color = r.col
		# 半径：卡面外扩到 ~1.6 倍卡宽；ease-out 让它「冲出去」再消失
		var ease := 1.0 - pow(1.0 - t, 2.0)
		var rad := 18.0 + ease * 52.0
		col.a = 0.9 * (1.0 - t)
		draw_arc(pos, rad, 0.0, TAU, 40, col, 3.0)
		if t < 0.55:
			# 内侧留一道更亮的细环，强化「冲破」的感觉
			var c2 := Color(1.0, 0.96, 1.0, 0.55 * (1.0 - t / 0.55))
			draw_arc(pos, rad * 0.86, 0.0, TAU, 32, c2, 1.5)


func _apply_delayed(kind: String, d: Dictionary) -> void:
	## 定时特效到点：攻击在冲刺结束那一刻才"命中"。
	var n := _now()
	match kind:
		"destroy_fx":
			if d.has("cell"):
				var c: Vector2i = d["cell"]
				_dying = _dying.filter(func(x): return x.cell != c)
			# R171：center 烘焙于 destroy 事件时 → 先补正到当前滚动再演
			# （_play_destroy_fx 内部的特效以当前滚动重新打标）。
			_play_destroy_fx((d.center as Vector2) + _scroll_dy(float(d.get("sc", _grid_scroll))),
					d.card as CardData)
		"hit":
			sfx.play("attack")
			var def = d.get("def")
			if def != null:
				_flashes[def] = {"col": Color(0.9, 0.15, 0.1), "start": n, "dur": 420}
				_drop_hp(def)   # 命中演出到点：卡面生命数字才开始往下掉
			# R171：pos 烘焙于攻击创建时 → 先补正到当前滚动，爆点 / 飘字再重新打标
			var hit_pos := (d.pos as Vector2) + _scroll_dy(float(d.get("sc", _grid_scroll)))
			_bursts.append({"pos": hit_pos, "sc": _grid_scroll, "start": n, "dur": 520,
					"col": Color("ffb300"), "big": false})
			_floaters.append({"pos": hit_pos + Vector2(0, -10), "sc": _grid_scroll,
					"text": "-%d" % int(d.dmg), "col": UiTheme.SIDE_FOE,
					"start": n, "dur": 1150})
			_shake(5.0, 260)
		"fx_hit":
			# R288：通用受击到点 —— 爆点 + 伤害数字（不分来源，谁打的都看得见）
			sfx.play("attack")
			var fc2: Vector2i = d.get("cell", Vector2i(-1, -1))
			if fc2.x >= 0:
				var fpos: Vector2 = _cell_center(fc2)
				_bursts.append({"pos": fpos, "sc": _grid_scroll, "start": n, "dur": 520,
						"col": Color("8f5ad0"), "big": false})
				_floaters.append({"pos": fpos + Vector2(0, -10), "sc": _grid_scroll,
						"text": "-%d" % int(d.get("dmg", 0)), "col": UiTheme.SIDE_FOE,
						"start": n, "dur": 1150})
				_shake(3.0, 180)
		"hp_hit":
			var hk = d.get("hpkey")
			if hk != null:
				_drop_hp(hk)   # 撞击演出到点：HP 横幅数字才开始往下掉
			# 直击 HP 撞上横幅：爆点 + 掉血飘字 + 震屏（与冲锋动作对齐）；
			# 「溢出」用 label 字段区分，好认是哪一下漏过去的。
			sfx.play("attack")
			_bursts.append({"pos": d.pos as Vector2, "start": n, "dur": 600,
					"col": Color("ff7043"), "big": true})
			_floaters.append({"pos": (d.pos as Vector2) + Vector2(0, -6),
					"text": str(d.get("label", "-%d" % int(d.dmg))),
					"col": UiTheme.SIDE_FOE, "start": n, "dur": 1250, "size": 20})
			_shake(6.5, 320)


func _play_destroy_fx(center: Vector2, card: CardData) -> void:
	## 击破演出：音效 + 卡牌幽灵淡出 + 大爆点 + 「击破」飘字 + 震屏。
	## R151 P1-18：先插一帧冲击白闪（60ms，日漫「锐利高光」），幽灵 / 爆点顺延 60ms。
	sfx.play("destroy")
	if not _shot_pending:
		_impacts.append({"pos": center, "sc": _grid_scroll, "start": _now(), "dur": 60})
	_ghosts.append({"center": center, "sc": _grid_scroll,
			"name": str(card.card_name), "start": _now() + 60, "dur": 800})
	_bursts.append({"pos": center, "sc": _grid_scroll, "start": _now() + 60, "dur": 640,
			"col": Color("e53935"), "big": true})
	_floaters.append({"pos": center + Vector2(0, -14), "sc": _grid_scroll, "text": "击破",
			"col": UiTheme.INK_600, "start": _now(), "dur": 1000})
	_shake(9.0, 380)


func _draw_attack_fx() -> void:
	## 「谁攻击了谁」投射演出：锁定环 → 攻击者蓄力 → 弹体沿轨迹飞向目标 → 命中。
	var n := _now()
	for pair: Array in engine.state.iter_board():
		var p: Placement = pair[1]
		if not _attacks.has(p):
			continue
		var a: Dictionary = _attacks[p]
		if n < int(a.start):
			continue   # 排队中：等前一段（如滑行）演完再开始，避免两段互相吞
		var t := clampf(float(n - int(a.start)) / int(a.dur), 0.0, 1.0)
		# R171：src/dst 是攻击创建时烘焙的像素 → 按滚动差补正
		# （adir 是两者差值方向，滚动对差值天然免疫，不用动）。
		var ady := _scroll_dy(float(a.get("sc", _grid_scroll)))
		var src := (a.src as Vector2) + ady
		var dst := (a.dst as Vector2) + ady
		var adir := a.dir as Vector2
		var dmg := int(a.get("dmg", 2))
		var is_hp := str(a.get("kind", "unit")) == "hp"
		if not is_hp:
			# ① 目标锁定环：脉动双圈，命中前钉在目标头上，命中后淡出
			var ring_a := 0.9 * (0.75 + 0.25 * sin(n / 90.0)) * minf(t * 6.0, 1.0)
			if t > ATK_IMPACT_T:
				ring_a *= 1.0 - (t - ATK_IMPACT_T) / (1.0 - ATK_IMPACT_T)
			draw_arc(dst, 30.0, 0.0, TAU, 28, Color(0.85, 0.12, 0.1, ring_a), 3.0)
			draw_arc(dst, 38.0, 0.0, TAU, 28, Color(0.85, 0.12, 0.1, ring_a * 0.4), 1.6)
			# ② 预告轨迹线：虚线感的淡色引导线（发射前显示）
			if t < ATK_LAUNCH_T + 0.08:
				var guide := Color(1.0, 0.55, 0.15, 0.28)
				draw_dashed_line(src + adir * 30.0, dst, guide, 2.0, 10.0)
		# ③ 攻击者蓄力光环（发射前脉动变亮）
		if t < ATK_LAUNCH_T:
			var charge := t / ATK_LAUNCH_T
			draw_arc(src, 34.0 + 4.0 * sin(n / 70.0), 0.0, TAU, 24,
					Color(1.0, 0.6, 0.1, 0.25 + 0.45 * charge), 2.0 + charge * 2.0)
		if is_hp:
			# ④' 直击 HP：没有弹体，撞上去那一刻在身前炸开一道冲击弧
			if t >= ATK_IMPACT_T and t <= ATK_IMPACT_T + 0.28:
				var kh := (t - ATK_IMPACT_T) / 0.28
				draw_line(src + adir * 12.0, src + adir * (36.0 + 30.0 * kh),
						Color(1.0, 0.68, 0.28, 0.75 * (1.0 - kh)), 4.0)
				draw_arc(src + adir * 34.0, 34.0 + 66.0 * kh, 0.0, TAU, 26,
						Color(1.0, 0.45, 0.15, 0.85 * (1.0 - kh)), 3.5)
		elif t >= ATK_LAUNCH_T and t <= ATK_IMPACT_T + 0.06:
			# ④ 弹体：从攻击者飞向目标（加速），带拖尾与光晕
			var fk := clampf((t - ATK_LAUNCH_T) / (ATK_IMPACT_T - ATK_LAUNCH_T), 0.0, 1.0)
			var ke := fk * fk * 0.4 + fk * 0.6  # 轻微加速
			var pos := src.lerp(dst, ke)
			var r := 5.0 + minf(dmg, 6.0)       # 弹体大小随攻击力
			# 拖尾：沿飞行反方向渐隐
			var tail := pos - adir * (34.0 + 26.0 * (1.0 - fk))
			var trail := Color(1.0, 0.5, 0.1, 0.55 * (1.0 - fk * 0.5))
			draw_line(tail, pos, trail, r * 0.9)
			draw_line(tail - adir * 22.0, tail, Color(1.0, 0.5, 0.1, 0.22), r * 0.5)
			# 光晕 + 亮核
			draw_circle(pos, r + 6.0, Color(1.0, 0.55, 0.1, 0.35))
			draw_circle(pos, r, Color(1.0, 0.62, 0.12, 0.95))
			draw_circle(pos, r * 0.45, Color(1.0, 0.95, 0.75, 1.0))


func _draw_ghosts() -> void:
	var n := _now()
	for g: Dictionary in _ghosts:
		var t := clampf(float(n - int(g.start)) / int(g.dur), 0.0, 1.0)
		var alpha := 1.0 - t
		var center: Vector2 = (g.center as Vector2) + _scroll_dy(float(g.get("sc", _grid_scroll)))
		var rect := Rect2(center - Vector2(BOARD_CARD_W, BOARD_CARD_H) / 2.0,
				Vector2(BOARD_CARD_W, BOARD_CARD_H))
		draw_rect(rect, Color(1, 1, 1, 0.85 * alpha))
		draw_rect(rect, Color(0.6, 0.6, 0.6, alpha), false, 1.5)
		_draw_string_center(_font, UiTheme.FS_MICRO, str(g.name), center + Vector2(0, 4),
				Color(0.3, 0.3, 0.3, alpha))


func _draw_floaters() -> void:
	var n := _now()
	for f: Dictionary in _floaters:
		var t := clampf(float(n - int(f.start)) / int(f.dur), 0.0, 1.0)
		if t <= 0.0:
			continue  # 延迟启动的飘字
		var alpha := 1.0 - t * t
		var pos: Vector2 = _fx_pos(f) + Vector2(0, -30.0 * t)  # R171：格锚飘字随棋盘滚动补正
		# R117：棋盘上沿从 136 移到 52，`GRID_Y - 36 / -62` 这类飘字起点会钻到顶栏
		# 底下（顶栏 36px，且是子节点、画在本层之上）→ 统一压在顶栏之下。
		pos.y = maxf(pos.y, 44.0)
		var col: Color = f.col
		# 伤害数字更大更醒目；文字类（法术/击破）保持原字号
		var size := int(f.get("size", 20 if str(f.text).begins_with("-") else 15))
		# R140：飘字也改成**带背景条**（R138 的暗描边在地图底图上仍不够清晰，用户实测）。
		col.a = alpha
		_draw_string_box_center(_font_bold, size, str(f.text), pos, col,
				Color(TEXT_BG.r, TEXT_BG.g, TEXT_BG.b, TEXT_BG.a * alpha))


func _draw_highlights() -> void:
	for cell in move_targets:
		_hl(cell, COL_MOVE)
	for cell in attack_targets_arr:
		_hl(cell, COL_ATTACK)
	for cell in hp_targets_arr:
		_hl(cell, COL_HP)
		_draw_string_box_center(_font_bold, UiTheme.FS_LABEL, "HP", _cell_center(cell), Color.WHITE)
	for cell in spell_targets:
		_hl(cell, COL_SPELL)
	# R242：「点手卡 → 点目标」这条路上，鼠标停在某一格时同样给 AOE 范围 / 自伤警告。
	# 与拖拽共用 `_draw_spell_preview`，两条路的画法不会分叉。
	if spell_pending >= 0 and engine != null and spell_pending < engine.state.hand.size():
		var hov: Variant = _cell_at(get_local_mouse_position())
		if hov != null and spell_targets.has(hov):
			_draw_spell_preview(engine.state.hand[spell_pending], hov)
	# R102：两段式技能**已选中第一个单位**的标记（金黄粗描边 + 角标「已选」）。
	# 潜伏 9100 与双向传送 8061 共用这一套 —— 满足「选中哪个要看得见、右键能取消」。
	_draw_picked_marker()
	# R118：误点空位之后进入「再点一次才取消」的过渡态 —— 同样必须看得见。
	_draw_cancel_armed_marker()
	# 叠栅栏（栅栏修复术 6021）：选中的手牌是栅栏时，把可合并的己方栅栏格标成橙色「叠」
	if selection != null and selection[0] == "hand" \
			and selection[1] >= 0 and selection[1] < engine.state.hand.size():
		var sel_card: CardData = engine.state.hand[selection[1]]
		for mcell in _fence_merge_cells(sel_card):
			_hl(mcell, COL_FENCE_MERGE)
			_draw_string_box_center(_font_bold, UiTheme.FS_LABEL, "叠", _cell_center(mcell), Color.WHITE)


func _picked_src() -> Vector2i:
	## 当前「两段式技能已选中的第一个单位」格 —— 潜入与双向传送共用一个入口。
	if _infiltrate_src.x >= 0:
		return _infiltrate_src
	if _swap_src.x >= 0:
		return _swap_src
	return Vector2i(-1, -1)


func _draw_picked_marker() -> void:
	## 在**已选中**的那个单位格上画金黄粗描边 + 角标「已选」。
	## 用描边而不是 `_hl` 的整格填充：填充会把单位本体盖住，正好违背"标明选中了哪个"。
	var src := _picked_src()
	if src.x < 0 or not engine.state.board.has(src):
		return
	var r := _cell_rect(src).grow(-1.0)
	draw_rect(r, COL_PICKED, false, 4.0)
	# 角标：右上角小方块 + 「已选」两字
	var tag := Rect2(r.position.x + r.size.x - 34.0, r.position.y + 1.0, 33.0, 14.0)
	draw_rect(tag, COL_PICKED)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "已选",
			tag.position + tag.size / 2.0, Color.BLACK)


func _draw_cancel_armed_marker() -> void:
	## R118：`_cancel_armed` 为真时，在**选中的那个单位格**上挂脉冲橙环 + 角标「取消?」。
	## 为什么非要画：状态栏只有 310px、而且 2.5 秒后就被悬停信息接管 ——
	## 这时玩家手上还捏着一次「已移动、未攻击」的行动，必须一眼看得见
	## 「还差一次点击才会丢掉它」，否则会以为点一下就已经取消了。
	## ⚠️ 环必须**画粗 + 近乎不透明**（与 `_draw_picked_marker` 同为 4px 量级）：
	##    `_draw_grid()` 早在每张单位卡所在格上画了一圈 3px 的**敌我框**
	##    （`COL_OWN_FRAME` 绿 / `COL_ENEMY_FRAME` 暗红），同一位置上压一层半透明的
	##    琥珀会混成说不清的黄绿（R118 出图实测：0.7 透明度的琥珀 + 绿框 = 黄绿，读不出
	##    「这是额外的状态」）。所以这里用**近乎不透明的橙**明确盖住那一圈几帧：
	##    这是个瞬时状态，拿归属色换「一眼看出还差一次点击」是划算的。
	## 用描边 + 角标而不是整格填充：填充会盖住单位本体（与 `_draw_picked_marker` 同款理由）。
	if not _cancel_armed or selection == null or selection[0] != "board":
		return
	var cell: Vector2i = selection[1]
	if not engine.state.board.has(cell):
		return
	var r := _cell_rect(cell).grow(-1.0)
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 4.2) + 1.0) * 0.5          # 0..1 呼吸
	var col := Color(COL_CANCEL_ARMED.r, COL_CANCEL_ARMED.g, COL_CANCEL_ARMED.b,
			0.90 + 0.10 * pulse)
	draw_rect(r, col, false, 3.0 + 2.0 * pulse)
	var tag := Rect2(r.position.x + r.size.x - 45.0, r.position.y + 2.0, 44.0, 15.0)
	draw_rect(tag, COL_CANCEL_ARMED)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "取消?",
			tag.position + tag.size / 2.0, Color(0.10, 0.07, 0.02))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(GRID_X + cell.y * CELL_W + CELL_W / 2,
			GRID_Y + cell.x * CELL + CELL / 2 - _grid_scroll)


func _scroll_dy(sc: float) -> Vector2:
	## R171：动画 / 特效创建时把当时的 _grid_scroll 烘进了像素位置；之后棋盘再滚动，
	## 这些位置就过期了 —— 单位卡看着「不跟板、慢半拍」，动画结束才瞬移回格位。
	## 按「创建时滚动量 − 当前滚动量」补回 y 差（x 不随滚动变）。
	return Vector2(0, sc - _grid_scroll)


func _fx_pos(f: Dictionary) -> Vector2:
	## 特效字典的当前绘制位置（R171 唯一取值口）：带 "sc" 标签（创建时的
	## _grid_scroll）的是格锚特效 → 做滚动补正；没标签的是 UI 锚点
	## （能量面板 / HP 横幅 / 手牌区 / 卡组列），本来就不随棋盘滚。
	var p: Vector2 = f["pos"]
	if f.has("sc"):
		p += _scroll_dy(float(f["sc"]))
	return p


func _hl(cell: Vector2i, col: Color) -> void:
	# ⚠️ R118 订正：R117 把格子拆成双轴（`CELL_W 102` × `CELL 90`）时**漏了这一处** ——
	# 横边仍按 `CELL` 算，于是移动 / 攻击 / HP / 法术格的高亮框整体**左移且变窄**
	# （最右一列偏 24px、宽 86 而非 98），与格子线、与卡牌位置都对不上。
	# 高亮是「这一格能做什么」的唯一通道，错位会直接读成「旁边那格能做什么」。
	draw_rect(_cell_rect(cell).grow(-2.0), col)


func _draw_grid_mask() -> void:
	## R123：把滚出棋盘可视窗的内容盖掉 —— 上面是工具栏、下面是手牌。
	## 有背景纹理时按同一比例采样对应区域补上，棋盘上下沿看起来就是「被窗口裁掉」；
	## 顺带画「上下还能滚」的双箭头（R127 起不再画右沿滚动条；只在第一局给新玩家）。
	if not _grid_scrollable():
		return
	# 下沿一直盖到窗口底部：手牌画在遮罩**之后**，有牌时自然会盖回来；
	# 没牌（空手牌区）也不能让棋盘内容漏到 619 以下。
	# ⚠️ R139：横向必须盖到**边框外沿**（GRID_X - BAND_L .. GRID_X + GRID_W + BAND_R）——
	#    边框跟着内容滚动后，它的顶带 / 底带会越过可视窗上下沿；只按 GRID_W 盖，
	#    左右两条竖直边带就会漏出石色（背景纹理不透明，盖住才是干净的裁断）。
	# R146：开场放大时整块棋盘（含边框）绕**可视窗中心**放大 → 边框的左右边带会推到
	#   原位之外。遮罩范围必须按同一比例摊开，否则石色边带会漏到左右两栏上。
	#   ⚠️ 可视窗本身在屏幕上不动（缩放中心就是它）→ 上下两条仍按 GRID_Y / GRID_Y+GRID_H 切；
	#      横向两条带的宽度 = 边带外推的那一段（不放大时正好 0 宽，被下面的守卫跳过）。
	var z := _grid_zoom
	var zc := GRID_X + GRID_W * 0.5
	# ⚠️ 余量只加在遮罩**范围**上（不是把带子变宽去盖别的东西）：带内取的是背景纹理 →
	#    z=1 时多出来的那几像素本来就是背景，看不出差别；左右两条新带也因此照旧无害。
	var pad := GRID_MASK_PAD
	var fx := zc + (GRID_X - GRID_FRAME_BAND_L - zc) * z - pad
	var fx2 := zc + (GRID_X + GRID_W + GRID_FRAME_BAND_R - zc) * z + pad
	var fl := GRID_X - GRID_FRAME_BAND_L
	var fr := GRID_X + GRID_W + GRID_FRAME_BAND_R
	var bands: Array[Rect2] = [
		Rect2(fx, 0, fx2 - fx, GRID_Y),
		Rect2(fx, GRID_Y + GRID_H, fx2 - fx, WINDOW_H - (GRID_Y + GRID_H)),
		Rect2(fx, GRID_Y, fl - fx, GRID_H),
		Rect2(fr, GRID_Y, fx2 - fr, GRID_H),
	]
	for r: Rect2 in bands:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if _bg_tex != null:
			var ts := _bg_tex.get_size()
			draw_texture_rect_region(_bg_tex, r,
					Rect2(Vector2(r.position.x / WINDOW_W, r.position.y / WINDOW_H) * ts,
							Vector2(r.size.x / WINDOW_W, r.size.y / WINDOW_H) * ts))
			# ⚠️ 与主背景**同一个暗罩**：漏了这一条，棋盘上下沿补出来的那两条
			#    会比别处亮一截，看着像两块补丁。
			draw_rect(r, COL_BG_SCRIM, true)
		else:
			draw_rect(r, COL_BG)
	# R127：**不再画滚动条** → 改用半透明双箭头。棋盘只有 120px 滚动余量，
	#   滑块短得几乎读不出比例，箭头反而更直接。
	# ⚠️ 方向与地图两处**相反**：这里的内容偏移是 `- _grid_scroll` →
	#   越大看得越靠**下**（第 5、6 行），所以「还能往下」对应**未到顶**。
	# R141：**不再只给新玩家第一局** —— 战场 3×6 上下两个方向还有空间就画箭头
	#   （上方有内容 → 上箭头；下方有内容 → 下箭头），两端都到底才整组消失。
	var sm := _grid_scroll_max()
	ScrollHint.draw(self, GRID_X + GRID_W * 0.5,
			GRID_Y + GRID_HINT_INSET,
			GRID_Y + GRID_H - GRID_HINT_INSET,
			_grid_scroll > _grid_scroll_min() + 0.5,   # 还能往上（回到第 1 行）
			_grid_scroll < sm - 0.5,   # 还能往下（看第 5、6 行）
			ScrollHint.breath())


func _draw_level_plate() -> void:
	## R138：关卡名从「棋盘下沿 10px 灰字」挪到**右上角**的独立铭牌 ——
	## 深底 + 金边 + 更大字号，压在当层地图底图上也一眼可见。
	## ⚠️ 新手指引条（`_tut_bar`，横跨 y 36~82）会盖住这里 → 它开着时不画，少一层重复文字。
	if engine == null or engine.state == null or engine.state.level_name == "":
		return
	if _tut_bar != null and _tut_bar.visible:
		return
	var txt := "关卡：%s" % engine.state.level_name
	var px := UiTheme.FS_LABEL
	var tw := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad_x := 18.0
	var ph := 30.0
	var rect := Rect2(WINDOW_W - 18.0 - (tw + pad_x * 2.0), 40.0, tw + pad_x * 2.0, ph)
	draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.22), true)          # 投影：把铭牌从底图上托出来
	draw_rect(rect, Color(0.09, 0.075, 0.05, 0.78), true)          # 深色铭牌底
	draw_rect(rect, UiTheme.ACCENT_GOLD, false, 1.5)               # 金边
	var dm := rect.position + Vector2(pad_x * 0.42, ph * 0.5)       # 左侧小菱形（与角花呼应）
	draw_colored_polygon(PackedVector2Array([dm + Vector2(0, -5), dm + Vector2(5, 0),
			dm + Vector2(0, 5), dm + Vector2(-5, 0)]), UiTheme.ACCENT_GOLD)
	_draw_string_center(_font_bold, px, txt,
			rect.position + Vector2(rect.size.x / 2.0 + 6.0, ph * 0.5),
			Color("f6e6bc"), 3, Color(0.04, 0.03, 0.02, 0.92))


func _draw_grid_frame() -> void:
	## R139：棋盘边框 —— 锚在 **3×6 战场本体**上（R137 那版围的是可视窗，固定不动）。
	## 现在它跟着 `_grid_scroll` 一起上下走：拖动 / 滚轮滚棋盘时边框跟着动，
	## 滚到两头能看全顶带与底带、以及四只角花。
	## ⚠️ 纵向溢出靠**后画的** `_draw_grid_mask()`（不透明背景纹理）裁掉 ——
	##    所以 _draw() 里这个函数必须排在遮罩**前面**，顺序反了边框会糊到工具栏上。
	var top := GRID_Y - _grid_scroll          # 内容区上沿（屏幕坐标）
	var outer := Rect2(GRID_X - GRID_FRAME_BAND_L, top - GRID_FRAME_BAND_T,
			GRID_W + GRID_FRAME_BAND_L + GRID_FRAME_BAND_R,
			GRID_CONTENT_H + GRID_FRAME_BAND_T + GRID_FRAME_BAND_B)
	# 外圈柔和投影：把边框从地图底图上托出来
	draw_rect(outer.grow(2.0), Color(0, 0, 0, 0.30), false, 3.0)
	# 暗石底带（四条，全部落在内容区之外）
	draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, GRID_FRAME_BAND_T),
			COL_FRAME_STONE)
	draw_rect(Rect2(outer.position.x, outer.end.y - GRID_FRAME_BAND_B, outer.size.x,
			GRID_FRAME_BAND_B), COL_FRAME_STONE)
	draw_rect(Rect2(outer.position.x, top, GRID_FRAME_BAND_L, GRID_CONTENT_H), COL_FRAME_STONE)
	draw_rect(Rect2(GRID_X + GRID_W, top, GRID_FRAME_BAND_R, GRID_CONTENT_H), COL_FRAME_STONE)
	# 双金线：外沿金线 + 外沿内侧暗金细线；内沿亮金收边压住内容区边界
	draw_rect(outer, COL_FRAME_GOLD, false, 1.5)
	draw_rect(outer.grow(-3.0), COL_FRAME_GOLD_DIM, false, 1.0)
	draw_rect(Rect2(GRID_X, top, GRID_W, GRID_CONTENT_H).grow(1.0), COL_FRAME_GOLD_IN, false, 1.5)
	# 四只角花（素材角块与这里的逻辑块一一对应）
	if _frame_tex != null:
		var pr := GRID_FRAME_PROTRUDE
		var tw := float(_frame_tex.get_width())
		var th := float(_frame_tex.get_height())
		_draw_frame_corner(Rect2(0, 0,
				(GRID_FRAME_BAND_L + pr) * 2.0, (GRID_FRAME_BAND_T + pr) * 2.0),
				Vector2(outer.position.x, outer.position.y),
				Vector2(GRID_FRAME_BAND_L + pr, GRID_FRAME_BAND_T + pr))
		_draw_frame_corner(Rect2(tw - (GRID_FRAME_BAND_R + pr) * 2.0, 0,
				(GRID_FRAME_BAND_R + pr) * 2.0, (GRID_FRAME_BAND_T + pr) * 2.0),
				Vector2(outer.end.x - GRID_FRAME_BAND_R - pr, outer.position.y),
				Vector2(GRID_FRAME_BAND_R + pr, GRID_FRAME_BAND_T + pr))
		_draw_frame_corner(Rect2(0, th - (GRID_FRAME_BAND_B + pr) * 2.0,
				(GRID_FRAME_BAND_L + pr) * 2.0, (GRID_FRAME_BAND_B + pr) * 2.0),
				Vector2(outer.position.x, outer.end.y - GRID_FRAME_BAND_B - pr),
				Vector2(GRID_FRAME_BAND_L + pr, GRID_FRAME_BAND_B + pr))
		_draw_frame_corner(Rect2(tw - (GRID_FRAME_BAND_R + pr) * 2.0,
				th - (GRID_FRAME_BAND_B + pr) * 2.0,
				(GRID_FRAME_BAND_R + pr) * 2.0, (GRID_FRAME_BAND_B + pr) * 2.0),
				Vector2(outer.end.x - GRID_FRAME_BAND_R - pr, outer.end.y - GRID_FRAME_BAND_B - pr),
				Vector2(GRID_FRAME_BAND_R + pr, GRID_FRAME_BAND_B + pr))
func _draw_grid_caption() -> void:
	## R139：边框会滚了，「战场」标题就**不能再挂在边框上**（否则跟着飘走）——
	## 改成固定在可视窗正上方的栏目标题（深棕字 + 浅金描边，压得住金饰带）。
	_draw_string_box_center(_font_bold, UiTheme.FS_MICRO, "战场",
			Vector2(GRID_X + GRID_W / 2, GRID_Y - 12), TXT_LIGHT)


func _draw_frame_corner(src: Rect2, at: Vector2, sz: Vector2) -> void:
	## R137：画一只角花（_frame_tex 的 2x 角块区域 -> 同尺寸逻辑块）。
	draw_texture_rect_region(_frame_tex, Rect2(at, sz), src)


func _draw_hp_banner() -> void:
	## R156：双方血量图标化 —— 血滴素材（与生命徽章同款）+ 滚动数字（底条亮字保留）。
	## 能量不再出现在这里：我方能量只有**左上能量面板**一处；敌方能量数值不再显示
	##（两条都是用户口径）。
	var mid_x := GRID_X + GRID_W + 18
	# R151 P0-3：HP 数字滚动 —— 目标值仍走 _show_hp（命中演出前冻结），滚动接在冻结解除后。
	if _hp_icon != null:
		draw_texture_rect(_hp_icon, Rect2(mid_x - 3, GRID_Y + 4, 24, 24), false)
	_draw_string_box_nw(_font_bold, UiTheme.FS_CAPTION, "敌方 HP %d" % _roll("hp_opp", _show_hp("hp_opp", engine.state.hp_opponent)),
			Vector2(mid_x + 26, GRID_Y + 8 + UiTheme.FS_CAPTION), TXT_FOE)
	if _hp_icon != null:
		draw_texture_rect(_hp_icon, Rect2(mid_x - 3, GRID_Y + GRID_H - 34, 24, 24), false)
	_draw_string_box_nw(_font_bold, UiTheme.FS_CAPTION, "我方 HP %d/%d" % [_roll("hp_self", _show_hp("hp_self", engine.state.hp_self)),
			engine.state.max_hp_self],
			Vector2(mid_x + 26, GRID_Y + GRID_H - 30 + UiTheme.FS_CAPTION), TXT_SELF)


func _enemy_zone_rect() -> Rect2:
	## 右栏敌方效果区外框（敌方 HP/能量文本下方）。
	return Rect2(GRID_X + GRID_W + 18, GRID_Y + 88, TAP_W + 12, 3 * (TAP_H + 10) + 44)


func _enemy_effect_rect(i: int) -> Rect2:
	## 敌方效果区第 i 张卡的屏幕矩形（与绘制顺序一致）。
	var z := _enemy_zone_rect()
	return Rect2(z.position.x + 4, z.position.y + 32.0 + i * (TAP_H + 10.0),
			TAP_W, TAP_H)


# ---- R197：敌方效果开场弹窗（虚空洞口底） ----
const EE_POP_W := 768.0
const EE_POP_H := 540.0
## 素材几何契约：void_portal.png 为 768×540，中心 r=225 纯黑圆盘（见
## art_src/2026-10-17_虚空洞口弹窗底/README.md）；文字区 = 同圆心的 336×252
## （角距 √(168²+126²) ≈ 210 < 225，四角都落在纯黑内）。重画素材两边要一起改。
const EE_TEXT_HW := 168.0
const EE_TEXT_HH := 126.0
## R215：开场弹窗的自动关闭时长（秒）。原来必须点一下才关 —— 玩家在等，
## 界面在等，实际上什么也没等。5 秒足够读完 3 条效果。
const EE_POPUP_SEC := 5.0


func _enemy_effect_popup_rect() -> Rect2:
	return Rect2((WINDOW_W - EE_POP_W) / 2.0, (WINDOW_H - EE_POP_H) / 2.0,
			EE_POP_W, EE_POP_H)


func _maybe_open_enemy_effect_popup() -> void:
	## R197：开场巡场**完整播完**（_grid_intro_tick 走满 GRID_INTRO_DUR）后，
	## 若敌方带效果卡则弹窗展示。玩家点击打断巡场不算「播完」——效果明细
	## 仍可随时点右侧「敌方效果」区查看；回放不弹；每场至多一次。
	if _ee_popup:
		return
	if engine == null or engine.state.enemy_effects.is_empty():
		return
	_ee_popup = true
	_ee_popup_t0 = _now()
	queue_redraw()


static func ee_popup_left_sec(t0: int, now_ms: int) -> float:
	## 开场弹窗还剩多少秒（<= 0 = 该关了）。**纯函数**：headless 测试直接调它。
	return EE_POPUP_SEC - float(now_ms - t0) / 1000.0


func ee_popup_expired() -> bool:
	## 该不该自动收起 —— `_process` 每帧问一次（唯一判据口）。
	return _ee_popup and ee_popup_left_sec(_ee_popup_t0, _now()) <= 0.0


func _draw_void_portal_fallback(r: Rect2) -> void:
	## 缺图回退：深紫黑底 + 紫色洞口环 + 纯黑内圆（与素材同一形态，不空白不报错）。
	draw_rect(r, Color(0.055, 0.045, 0.085), true)
	var c := r.get_center()
	draw_circle(c, 236.0, Color(0.0, 0.0, 0.0))
	draw_arc(c, 240.0, 0.0, TAU, 72, Color(0.62, 0.36, 0.88), 5.0)
	draw_arc(c, 248.0, 0.0, TAU, 72, Color(0.30, 0.55, 0.78), 2.0)


func _draw_enemy_effect_popup() -> void:
	## R197：虚空洞口底 + 中心纯黑区白色文字。素材与弹窗 1:1（不缩放），
	## 纯黑圆盘圆心 = 弹窗中心；文字全部画在该圆盘内，白字黑底对比拉满。
	var r := _enemy_effect_popup_rect()
	var c := r.get_center()
	var tex := UiAssets.void_portal()
	if tex != null:
		draw_texture_rect(tex, r, false)
	else:
		_draw_void_portal_fallback(r)
	var merged := _merged_effects(engine.state.enemy_effects)
	var max_w := EE_TEXT_HW * 2.0 - 28.0
	_draw_string_center(_font_bold, UiTheme.FS_SUBHEAD, "敌方效果",
			c + Vector2(0.0, -EE_TEXT_HH + 26.0), Color.WHITE)
	var y := c.y - EE_TEXT_HH + 62.0
	var bottom := c.y + EE_TEXT_HH - 30.0
	for m in merged:
		if y > bottom - 24.0:
			_draw_string_center(_font, UiTheme.FS_CAPTION,
					"……共 %d 张，点右侧「敌方效果」区查看全部" % merged.size(),
					Vector2(c.x, bottom), Color(0.72, 0.72, 0.78))
			break
		var card: CardData = m["card"]
		var nm: String = card.card_name
		if int(m["count"]) > 1:
			nm += " ×%d" % int(m["count"])
		_draw_string_center(_font_bold, UiTheme.FS_BODY, nm,
				Vector2(c.x, y), Color.WHITE)
		y += 24.0
		var desc := CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
		for ln in _wrap_lines(_font, UiTheme.FS_CAPTION, desc, max_w):
			_draw_string_center(_font, UiTheme.FS_CAPTION, ln,
					Vector2(c.x, y), Color(0.93, 0.93, 0.97))
			y += 17.0
		y += 12.0
	var left := maxi(0, int(ceil(ee_popup_left_sec(_ee_popup_t0, _now()))))
	_draw_string_center(_font, UiTheme.FS_CAPTION,
			"点击任意处继续 · %d 秒后自动关闭" % left,
			c + Vector2(0.0, EE_TEXT_HH - 22.0), Color(0.66, 0.66, 0.74))


func _draw_enemy_effects() -> void:
	## 右栏：敌方效果区（红色调，开局启用的效果卡正面朝上持续生效）。
	var state := engine.state
	var z := _enemy_zone_rect()
	draw_rect(z, Color(0.88, 0.72, 0.72, 0.30), true)
	draw_rect(z, Color("a87a7a"), false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "敌方效果 %d" % state.enemy_effects.size(),
			Vector2(z.position.x + z.size.x / 2, z.position.y + 22.0), Color("7a3a3a"))
	# 同名合并显示（左下角 ×N 角标）
	var merged_e := _merged_effects(state.enemy_effects)
	var n_ee := merged_e.size()
	var cap_e := _enemy_effect_zone_max_slots()
	if n_ee <= cap_e:
		for i in n_ee:
			var m: Dictionary = merged_e[i]
			_draw_card_face(m["card"], _enemy_effect_rect(i),
					(m["card"] as CardData).health, false, false)
			_draw_count_badge(_enemy_effect_rect(i), m["count"])
	else:
		for i in cap_e - 1:
			var m2: Dictionary = merged_e[i]
			_draw_card_face(m2["card"], _enemy_effect_rect(i),
					(m2["card"] as CardData).health, false, false)
			_draw_count_badge(_enemy_effect_rect(i), m2["count"])
		_draw_more_tile(_enemy_effect_rect(cap_e - 1), "+%d" % (n_ee - (cap_e - 1)),
				"点击查看全部")
	_draw_relic_bar()


func _enemy_effect_zone_max_slots() -> int:
	## 右栏敌方效果区在不越界的前提下能放几张卡（与 _enemy_zone_rect 的高度一致）。
	var z := _enemy_zone_rect()
	var top := z.position.y + 32.0
	return maxi(1, int((z.position.y + z.size.y - top) / (TAP_H + 10.0)))


## 道具浏览面板（R75：只有道具栏装不下时才可点开，字号全面大于悬浮提示）
const RELIC_PANEL_W := 860.0
const RELIC_P_NAME := 16          # 名称字号
const RELIC_P_DESC := 13          # 说明字号（悬浮提示是 12）
const RELIC_P_ROWH := 24.0        # 名称行高
const RELIC_P_LINE := 17.0        # 说明行高


func _relic_zone_rect() -> Rect2:
	## 右侧道具栏外框（棋盘右侧、卡组列左侧的空白带，避开我方 HP 文字）。
	return Rect2(900.0, GRID_Y + 350.0, 240.0, 172.0)


func _relic_rect(i: int) -> Rect2:
	## 道具栏第 i 个徽章矩形（与 _draw_relic_bar 一致）。
	var z := _relic_zone_rect()
	return Rect2(z.position.x + 4, z.position.y + 24.0 + i * 24.0, z.size.x - 8, 22.0)


func _relic_max_slots() -> int:
	## 道具栏在不越界的前提下能放几个徽章（每个高 22、步进 24，从 +24 起）。
	var z := _relic_zone_rect()
	var top := z.position.y + 24.0
	return maxi(1, int((z.position.y + z.size.y - top) / 24.0))


func _relic_bar_overflowed() -> bool:
	## 道具栏装不下全部道具（会出现「+N」摘要）—— 点开浏览面板的**唯一**判定口。
	## 装得下时悬浮已能看全，不给点击入口（用户要求）。
	return engine.self_relics.size() > _relic_max_slots()


func _relic_bar_lit() -> bool:
	## R314：道具栏里**有没有亮着的徽章**（有 → 需要逐帧呼吸重绘，见 `_process`）。
	## 判据全部在 `GameEngine.relic_highlight()`；这里只做「是否至少有一个」。
	if engine == null:
		return false
	for rid: int in engine.self_relics:
		if engine.relic_highlight(rid):
			return true
	return false


func _draw_relic_bar() -> void:
	## 右栏道具栏：本局获得的道具（来源色块 = 初始白 / 奖励黄 / 事件紫）。
	var ids := engine.self_relics
	var z := _relic_zone_rect()
	draw_rect(z, Color(1.0, 0.96, 0.82, 0.30), true)
	draw_rect(z, Color("b09a5a"), false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "道具 %d" % ids.size(),
			Vector2(z.position.x + z.size.x / 2, z.position.y + 16.0), Color("7a6230"))
	var repo := RelicRepo.load_json()
	var n_rel := ids.size()
	var cap_r := _relic_max_slots()
	var shown_r := n_rel if n_rel <= cap_r else cap_r - 1
	for i in shown_r:
		var rel := repo.get_relic(ids[i])
		if rel == null:
			continue
		var rect := _relic_rect(i)
		var scol := rel.badge_color()
		# R309（用户口径「道具名不太清晰」）：去掉描边 + 底衬改成**浅实色** ——
		# 来源色向白混 62%，深棕字压在浅底上才有对比度；原来 28% 半透明会透出草地，
		# 深棕字和背景糊成一片（加 2px 描边只会更糊）。
		draw_rect(rect, scol.lerp(Color.WHITE, 0.62), true)
		draw_rect(rect, scol, false, 1.2)
		# R314（用户口径）：**这一刻会不会真的触发**的道具要亮起 ——
		# 呼吸外框（金） + 更亮的底。判据见 `GameEngine.relic_highlight()`：
		# 「一直被动生效」的那些（鸭嘴 / 鸭之眼 / 快速符文 / 水晶骰子…）不在其中，
		# 因为常亮等于没有信息量。
		if engine.relic_highlight(ids[i]):
			var lit_ph := 0.5 + 0.5 * sin(float(_now()) / 220.0)   # 约 1.4 秒一个来回
			var glow := Rect2(rect.position - Vector2(2.0, 2.0),
					rect.size + Vector2(4.0, 4.0))
			# ⚠️ 高亮色**不能用金色**：奖励 / 传奇徽章本来就是黄橙（#e0b23c / #e8933a），
			#    金边压上去几乎看不出来（实测出图分辨不出哪一行亮着）。改用**青白**（补色），
			#    在黄橙底上一眼就能分出来。
			var lit_col := Color(0.56, 0.92, 1.0)
			draw_rect(glow, Color(lit_col.r, lit_col.g, lit_col.b, 0.30 + 0.34 * lit_ph), true)
			draw_rect(glow, Color(lit_col.r, lit_col.g, lit_col.b, 0.80 + 0.20 * lit_ph), false, 1.8)
			draw_rect(rect, scol.lerp(Color.WHITE, 0.86), true)   # 底再提亮一档
			# 右端一颗呼吸亮点：即使缩到最小尺寸 / 灰度打印也读得出「这行在亮」
			var dot := Vector2(rect.position.x + rect.size.x - 9.0,
					rect.position.y + rect.size.y / 2.0)
			draw_circle(dot, 3.0 + 1.4 * lit_ph, lit_col)
		# 来源色块（白色描述边在浅底上不醒目，配实心块 + 深描边）
		var chip := Rect2(rect.position + Vector2(4, 4), Vector2(6, rect.size.y - 8))
		draw_rect(chip, scol, true)
		draw_rect(chip, Color(0, 0, 0, 0.5), false, 1.0)
		# R309：**不描边**（outline = -1）—— 8~10 号字上 2px 描边会把笔画糊掉，
		# 「雕像（3）」这种带括号的名字尤其看不清。
		# R343：传奇道具名走**暗金**（底是来源色向白混 62% 的浅实色 → 亮金会糊），
		# 普通道具仍是原来的深棕。判据在 `RelicData.name_color()`，这里不写特例。
		_draw_string_center(_font_bold, UiTheme.FS_MICRO,
				RunState.relic_display_name(ids[i]),
				Vector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,
						rect.position.y + 14.0),
				rel.name_color(Color("4a3c14")), -1)
	# 道具太多装不下 → 末位换成「+N 点击查看全部」摘要行（点道具栏打开浏览面板）
	if n_rel > shown_r:
		_draw_more_tile(_relic_rect(shown_r), "+%d" % (n_rel - shown_r), "点击查看全部")
	# 鸭之低语：本回合随机得到的强化，常驻显示在道具栏下方
	if engine.self_relics.has(6010):
		_draw_string_box_nw(_font_bold, UiTheme.FS_CAPTION,
				"鸭之低语：%s" % (_whisper_txt if _whisper_txt != "" else "…"),
				Vector2(z.position.x + 6.0, z.position.y + z.size.y + 20.0), Color("d9a8ff"))


## R117：这里原本是 `_draw_opponent_hand()`（顶部一排**卡背** + 「（对手手牌区）」占位字）。
## 用户口径「敌人手牌实际不需要」→ 整段显示删掉，腾出的纵向空间全部给战场。
## ⚠️ 删的只是**显示**：`engine.state.opp_hand_count` 仍是敌方 AI 的施法依据
## （remote_spell 先扣它再结算），引擎侧一行都没动。
func _draw_cost_zone() -> void:
	## 左栏：顶部能量面板 + 下方效果区（效果卡正面朝上，持续生效）。
	var state := engine.state
	var mid_x := COST_X + (TAP_W + 12) / 2
	var bottom := GRID_Y + GRID_H
	_draw_string_box_center(_font_bold, UiTheme.FS_MICRO, "能量",
			Vector2(mid_x, COST_Y - 12), TXT_POWER)
	var epanel := Rect2(COST_X, COST_Y, TAP_W + 12, ENERGY_H)
	draw_rect(epanel, Color(1, 1, 1, 0.55), true)
	draw_rect(epanel, UiTheme.INK_300, false, 1.0)
	# R156：能量数值配水晶图标（与费用徽章同款素材），图标 + 数字作为一对整体居中
	var e_txt := str(_roll("energy", state.energy))
	var e_w := _font_bold.get_string_size(e_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_HEADING).x
	var gem := 26.0
	var pair_x := mid_x - (gem + 4.0 + e_w) / 2.0
	if _energy_icon != null:
		draw_texture_rect(_energy_icon, Rect2(pair_x, COST_Y + 46 - gem / 2.0, gem, gem), false)
	_draw_string_center(_font_bold, UiTheme.FS_HEADING, e_txt,
			Vector2(pair_x + gem + 4.0 + e_w / 2.0, COST_Y + 46), UiTheme.STAT_POWER)
	_draw_string_center(_font, UiTheme.FS_MICRO, "每回合重置为 5",
			Vector2(mid_x, COST_Y + 70), UiTheme.INK_500)
	# 蓄力（9085）：待用层数（0 层不画）—— 下一张技能的结算次数 = 1 + 层数
	var chg := engine.charge_count(GameEngine.SIDE_SELF)
	if chg > 0:
		_draw_string_center(_font_bold, UiTheme.FS_MICRO, "蓄力 ×%d（下一张技能 ×%d）" % [chg, chg + 1],
				Vector2(mid_x, COST_Y + 84), UiTheme.STAT_POWER)
	# 闪躲（9103）：盟友代受窗口（未开启不画）
	if engine.dodge_active(GameEngine.SIDE_SELF):
		_draw_string_box_center(_font_bold, UiTheme.FS_MICRO, "闪躲：伤害由盟友代受",
				Vector2(mid_x, COST_Y + 108), TXT_WARN)
	# 角色（左栏常驻）：本局选定的角色
	# R117：棋盘上移到 y=52 之后，原来的 `COST_Y - 26`（=26）会落进顶栏（36px 高，
	# 且顶栏是子节点、画在本层之上）→ 被整条吃掉。收进能量面板上方的空档：
	# 面板是 56..148，大数字在 +46、副标题在 +70，这一带原本就是空的。
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "角色：%s" % RunState.player_class,
			Vector2(mid_x, COST_Y + 14), UiTheme.KIND_EFFECT)
	# 效果区
	var zone := Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, bottom - COST_Y - ENERGY_H)
	draw_rect(zone, Color(0.72, 0.86, 0.72, 0.30), true)
	draw_rect(zone, Color("7aa87a"), false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "效果区 %d" % state.effects.size(),
			Vector2(mid_x, COST_Y + ENERGY_H + 22.0), Color("4a6a4a"))
	# 效果卡：同名合并显示（左下角 ×N 角标），栏高固定、最多画满可见槽位；
	# 装不下的用一张「+N」摘要卡兜底（点区域看全部）
	var merged := _merged_effects(state.effects)
	var n_eff := merged.size()
	var cap := _effect_zone_max_slots()
	if n_eff <= cap:
		for i in n_eff:
			var m: Dictionary = merged[i]
			_draw_card_face(m["card"], _effect_rect(i),
					(m["card"] as CardData).health, false, false)
			_draw_counter_badge(m["card"], _effect_rect(i))
			_draw_count_badge(_effect_rect(i), m["count"])
	else:
		for i in cap - 1:
			var m2: Dictionary = merged[i]
			_draw_card_face(m2["card"], _effect_rect(i),
					(m2["card"] as CardData).health, false, false)
			_draw_counter_badge(m2["card"], _effect_rect(i))
			_draw_count_badge(_effect_rect(i), m2["count"])
		_draw_more_tile(_effect_rect(cap - 1), "+%d" % (n_eff - (cap - 1)), "点击查看全部")


func _merged_effects(cards: Array) -> Array:
	## 同名效果卡合并显示：[{card, count}]（按首次出现顺序；card 为该名第一张，作代表）。
	var order: Array = []
	var by_name := {}
	for c: CardData in cards:
		if not by_name.has(c.card_name):
			var e := {"card": c, "count": 0}
			by_name[c.card_name] = e
			order.append(e)
		by_name[c.card_name]["count"] += 1
	return order


func _draw_count_badge(rect: Rect2, count: int) -> void:
	## 同名合并的张数角标（「×N」）：只有合并了 2 张以上才画。
	## ⚠️ R114 起改画在**右上角** —— 卡片底部现在是数值徽章的地盘
	## （左下力/程、右下生/速），原来在左下会被「力」徽章整个盖住。
	if count < 2:
		return
	var bw := 26.0
	var badge := Rect2(rect.end.x - bw - 2.0,
			rect.position.y + 2.0, bw, 16.0)
	draw_rect(badge, Color(0.15, 0.18, 0.15, 0.88), true)
	draw_rect(badge, Color("a8d8a8"), false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "×%d" % count,
			Vector2(badge.position.x + bw / 2, badge.position.y + 12.0), Color("d8f0d8"))


func _draw_counter_badge(c: CardData, rect: Rect2) -> void:
	## 效果卡的「剩余次数」角标（石肤 9066：己方 HP 还能把几次伤害变成 1）。
	## 没有计数概念的卡（engine.effect_counter < 0）不画。
	if engine == null or c == null:
		return
	var left := engine.effect_counter(c)
	if left < 0:
		return
	var bw := 30.0
	## R114：同样让开底部数值条，堆在「×N」角标之下（两者可以同时出现）。
	var badge := Rect2(rect.end.x - bw - 2.0,
			rect.position.y + 20.0, bw, 16.0)
	draw_rect(badge, Color(0.15, 0.15, 0.18, 0.88), true)
	draw_rect(badge, Color("d8cfa8"), false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, "剩 %d" % left,
			Vector2(badge.position.x + bw / 2, badge.position.y + 12.0), Color("f0e6c8"))


func _effect_zone_max_slots() -> int:
	## 左栏效果区在不越界的前提下能放几张卡（卡高 TAP_H，步进 TAP_H+10）。
	var top := COST_Y + ENERGY_H + 32.0
	var bottom := GRID_Y + GRID_H
	return maxi(1, int((bottom - top) / (TAP_H + 10.0)))


func _draw_more_tile(rect: Rect2, label: String, sub: String) -> void:
	## 溢出摘要卡：某个区域装不下全部卡时，用这一张替代放不下的那些，
	## 标出还有多少张、并提示该区域可点开查看全部。
	var cx := rect.position.x + rect.size.x / 2
	draw_rect(rect, Color(0.96, 0.95, 0.88, 0.95), true)
	draw_rect(rect, Color("9a8f70"), false, 1.0)
	if rect.size.y >= 40.0:
		_draw_string_center(_font_bold, UiTheme.FS_LABEL, label,
				Vector2(cx, rect.position.y + rect.size.y * 0.40), Color("6a6040"))
		_draw_string_center(_font, UiTheme.FS_MICRO, sub,
				Vector2(cx, rect.position.y + rect.size.y * 0.72), Color("7a7050"))
	else:
		_draw_string_center(_font_bold, UiTheme.FS_MICRO, "%s %s" % [label, sub],
				Vector2(cx, rect.position.y + rect.size.y * 0.5 + 3.0), Color("6a6040"))


func _effect_rect(i: int) -> Rect2:
	## 效果区第 i 张卡的屏幕矩形（与 _draw_cost_zone 的绘制顺序一致）。
	return Rect2(COST_X + 4, COST_Y + ENERGY_H + 32.0 + i * (TAP_H + 10.0),
			TAP_W, TAP_H)


func _own_effect_zone_rect() -> Rect2:
	## 【R106】我方「效果区」的外框（左栏能量面板下方那一整块）。
	## 点它 = 打开浏览面板；把手里的一张**效果卡**拖到它上面松手 = 直接启用。
	## 两处共用这一个矩形 —— 免得点得到的范围和拖得到的范围对不上。
	return Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, GRID_H - ENERGY_H)


func _effect_drop_rect() -> Rect2:
	## R117：效果卡的「可用投放区」= **左半边整片**（信息栏 + 能量面板 + 效果区 + 棋盘）。
	## 此前只认效果区那 88px 宽的一小块（用户口径「拖拽使用的区域加大」）。
	## ⚠️ 为什么连**棋盘**也算：`_finish_drag` 里效果卡落到棋盘格上同样调 `use_effect()`
	##    （R106 起就是两条等效路径）。区域只画左栏、棋盘不画的话，玩家把卡拖到棋盘上时
	##    外框会显示「不在区域内」—— 而松手其实**会**生效，正是本次要消灭的那种
	##    「画的和做的不一致」。所以一次覆盖到棋盘右沿，让**外框 = 真判定域**。
	## 右栏（敌方效果区 / 道具栏 / 牌库 / 弃牌堆）不在内：松手会被拒。
	## ⚠️ 它**包含** `_own_effect_zone_rect()`（卡片真正待着的地方），所以两者不冲突：
	##    外框 = 可以松手的范围，内层高亮 = 它将会落在哪里。
	return Rect2(INFO_X, GRID_Y, (GRID_X + GRID_W) - INFO_X, GRID_H)


func _drag_footprint(pos: Vector2) -> Rect2:
	## 拖拽中那张卡在屏幕上的矩形。**吸附判定与绘制共用它**（`_draw_drag` 也调它），
	## 否则「看起来盖住了」和「算起来盖住了」会各算一份，迟早对不上。
	return Rect2(pos - Vector2(HAND_CARD_W, HAND_CARD_H) / 2.0,
			Vector2(HAND_CARD_W, HAND_CARD_H))


func _drop_cell(pos: Vector2, cells: Array) -> Variant:
	## R117 拖拽落点解析（**唯一口**：`_finish_drag` 与 `_draw_drag` 共用）。
	##   ① 光标所在格若就是合法格 → 直接命中；
	##   ② 否则**吸附**：取「拖拽卡牌所占矩形」覆盖到的合法格里、离光标最近的那个；
	##   ③ 都不沾边 → null（松手 = 取消）。
	## 这就是用户口径「技能牌的拖拽可用区域加大」：从「光标那一个点」放大到整张卡的 footprint
	## （手牌卡 98.6×119 ≈ 1.3×1.6 个格子）。
	if cells.is_empty():
		return null
	var direct: Variant = _cell_at(pos)
	if direct != null and cells.has(direct):
		return direct
	var sweep := _drag_footprint(pos)
	var best = null
	var best_d := INF
	for c: Vector2i in cells:
		if _cell_rect(c).intersects(sweep):
			var d: float = _cell_center(c).distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = c
	return best


func _drag_hit_cell() -> Variant:
	## 拖拽落点**实际会命中的那一格**（松手会取消则 null）。
	## ⚠️ 与 `_finish_drag` 必须同源：放置类**不吸附**（与那里一致，避免误放），
	## 技能类走 `_drop_cell`（按卡牌 footprint 吸附）。
	var cells: Array = _drag_place_cells if _drag_place else _drag_spell_cells
	if cells.is_empty():
		return null
	if _drag_place:
		var direct: Variant = _cell_at(_drag_pos)
		return direct if direct != null and cells.has(direct) else null
	return _drop_cell(_drag_pos, cells)


func _cells_bbox(cells: Array) -> Rect2:
	## 一组格子的外接矩形（画「可释放区域」外框用）。空集合返回零矩形。
	if cells.is_empty():
		return Rect2()
	var r: Rect2 = _cell_rect(cells[0])
	for c: Vector2i in cells:
		r = r.merge(_cell_rect(c))
	return r


func _drag_zone_rect() -> Rect2:
	## 本次拖拽「松手即生效」的区域（R117 用户口径「标明拖拽后可以使用的区域」）。
	## 没在拖拽、或这一类拖拽没有区域概念时返回零矩形。
	if _drag_idx < 0 or engine == null or _drag_idx >= engine.state.hand.size():
		return Rect2()
	if _drag_to_effects:
		return _effect_drop_rect()
	if _drag_place:
		return _cells_bbox(_drag_place_cells)
	if not _drag_spell_cells.is_empty():
		return _cells_bbox(_drag_spell_cells)
	if _drag_anywhere:
		return Rect2(GRID_X, GRID_Y, GRID_W, GRID_H)
	return Rect2()


func _drag_zone_label() -> String:
	## 区域外框上的短标签（第一屏里玩家只需要知道「这里能不能松手」）。
	# R213：目标在手牌里的技能 —— 松手不结算、只弹选卡页，标签要说清（否则玩家会以为
	# 拖到棋盘就直接打出去了）。
	if _drag_idx >= 0 and engine != null and _drag_idx < engine.state.hand.size() \
			and _hand_target_pick_kind(engine.state.hand[_drag_idx]) != "":
		return "松手 → 弹出选卡页"
	if _drag_to_effects:
		return "可释放区域"
	if _drag_place:
		return "可放置区域"
	if not _drag_spell_cells.is_empty() or _drag_anywhere:
		return "可释放区域"
	return ""


func _draw_deck_and_discard() -> void:
	## R140：右列一竖三块 —— **消耗区**（最上）· **弃牌区**（中，位置不变）· **卡组**（最下）。
	## 用户口径：① 弃牌区只把「顶牌卡面」换成 图标 + 张数；② 卡组张数骑在卡背顶边上；
	##          ③ 消耗区（本局消失的卡）摆在弃牌区**正上方**。
	var state := engine.state
	# ---- 卡组（抽牌堆）：卡背 + 顶边张数徽章 ----
	var drect := Rect2(DECK_X, DECK_Y, CARD_W, CARD_H)
	if state.deck.is_empty():
		draw_rect(drect, Color(0, 0, 0, 0.28), true)
		draw_rect(drect, UiTheme.INK_300, false, 1.0)
	else:
		_draw_card_back(drect)
	_draw_zone_name(drect, "卡组")
	_draw_zone_count(drect, state.deck.size())
	# ---- 弃牌区：图标 + 张数（不再显示卡面）----
	var crect := Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H)
	_draw_zone_icon(_discard_tex, crect, Color("a08a52"))
	_draw_zone_name(crect, "弃牌")
	_draw_zone_count(crect, state.discard.size())
	# ---- 消耗区：次元图标 + 本局消失张数 ----
	var vrect := Rect2(VOID_X, VOID_Y, CARD_W, CARD_H)
	_draw_zone_icon(_void_tex, vrect, Color("b06ae0"))
	_draw_zone_name(vrect, "消耗")
	_draw_zone_count(vrect, state.void_count)


func _draw_zone_icon(tex: Texture2D, rect: Rect2, frame_col: Color) -> void:
	## R140：区域图标底板 —— 深色方块 + 主题色边 + 居中图标（无素材时退化成带边框的空方块）。
	var plate := rect.grow(-3.0)
	draw_rect(rect.grow(1.5), Color(0, 0, 0, 0.35), true)
	draw_rect(plate, Color(0.07, 0.06, 0.05, 0.74), true)
	draw_rect(plate, frame_col, false, 1.6)
	if tex != null:
		# 图标略微上移：给方块下沿的区域名压条让位
		var ic := Rect2(plate.get_center() + Vector2(0, -ZONE_NAME_H * 0.5)
				- Vector2(ZONE_ICON, ZONE_ICON) * 0.5, Vector2(ZONE_ICON, ZONE_ICON))
		draw_texture_rect(tex, ic, false)


func _draw_zone_name(rect: Rect2, label: String) -> void:
	## R140：区域名（小字）—— 压在方块**下沿**上，让「图标 + 数字」一眼知道是哪个区。
	var plate := rect.grow(-3.0)
	var strip := Rect2(plate.position.x, plate.end.y - ZONE_NAME_H, plate.size.x, ZONE_NAME_H)
	draw_rect(strip, Color(0.04, 0.035, 0.03, 0.82), true)
	_draw_string_center(_font_bold, UiTheme.FS_MICRO, label,
			strip.get_center(), Color("e8dcc0"))


func _draw_zone_count(rect: Rect2, count: int) -> void:
	## R140：区域张数徽章 —— **骑在方块顶边**上的小金牌（张数直接贴在区域上方）。
	## 卡组、弃牌区、消耗区三块共用这一个口，样式一致。
	var txt := str(count)
	var px := UiTheme.FS_CAPTION
	var tw := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var bw := maxf(30.0, tw + 18.0)
	var bh := 20.0
	var r := Rect2(rect.position.x + rect.size.x * 0.5 - bw * 0.5,
			rect.position.y - bh * 0.6, bw, bh)
	draw_rect(r.grow(1.5), Color(0, 0, 0, 0.45), true)
	draw_rect(r, Color(0.12, 0.10, 0.07, 0.94), true)
	draw_rect(r, UiTheme.ACCENT_GOLD, false, 1.5)
	_draw_string_center(_font_bold, px, txt, r.get_center(), Color("f6e6bc"))


func _draw_hand_base() -> void:
	## R154：手牌区垫一条**半透明羊皮纸**圆角条（清单 §2.4）—— 手牌直接浮在
	## 当层地图底图上时，森林/钢铁花纹会咬卡面下缘；垫一层暖纸色把扇形「托」住。
	## 程序画（素材 panel_paper 是 P2 待办，先用程序色），只铺在手牌活动范围内。
	if engine.state.hand.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.89, 0.78, 0.34)
	sb.border_color = Color(0.82, 0.72, 0.48, 0.42)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	draw_style_box(sb, Rect2(HAND_BASE_X, HAND_BASE_Y, HAND_BASE_W, HAND_BASE_H))


func _draw_hand() -> void:
	var n := engine.state.hand.size()
	var full: bool = engine.state.hand_full()
	# 标签放在手牌左侧、竖直居中于**可见**卡面（卡底沉在窗口外，别贴着屏幕底）
	var label_y: float = OWN_HAND_Y + minf(HAND_CARD_H, WINDOW_H - OWN_HAND_Y) / 2
	var left: float = _hand_rect(0).position.x if n > 0 else WINDOW_W / 2
	_draw_string_box_center(_font_bold, UiTheme.FS_MICRO, "手牌 %d/%d" % [n, FieldState.HAND_LIMIT],
			Vector2(minf(WINDOW_W / 2 - 330, left - 56), label_y),
			TXT_WARN if full else TXT_LIGHT)
	# 悬停的那张抬起来、并压在最上层（重叠时才看得清）
	var order: Array[int] = []
	for i in n:
		if i != _hover_hand:
			order.append(i)
	if _hover_hand >= 0 and _hover_hand < n:
		order.append(_hover_hand)
	for i in order:
		if _hand_fly_in_slot(i):
			continue  # R151 P0-1：这张还在从抽牌堆飞过来，由 _draw_hand_fly 画卡背
		var card := engine.state.hand[i]
		var sel: bool = selection != null and selection[0] == "hand" and selection[1] == i
		_draw_hand_card(i, card, sel, HAND_FAN_HOVER_LIFT if i == _hover_hand else 0.0)


func _draw_hand_card(i: int, card: CardData, selected: bool, lift: float) -> void:
	## 按扇形角度画一张手牌：绕卡牌**底部中心**旋转。
	## lift 只是视觉抬手（不改 _hand_rect，所以命中判定不会因为抬手而抖）。
	## 卡底沉出窗口下沿：卡面照常整张排版，多出来的那截由视口裁掉（不补偿、不挪数值）。
	var r := _hand_rect(i)
	r.position.y -= lift
	# R151 P1-6/7：回合归属 —— 敌方回合手牌整体下沉 +6；我方回合上浮 −3（纯显示，不动命中）
	r.position.y += _hand_turn_dy
	# R151 P2-15：这张卡打出被拒 → 回弹抖动（±4px 衰减，150ms）
	if not _shake_card.is_empty() and int(_shake_card.idx) == i:
		var st := clampf(float(_now() - int(_shake_card.start)) / int(_shake_card.dur), 0.0, 1.0)
		if st < 1.0:
			r.position.x += sin(st * PI * 3.0) * 4.0 * (1.0 - st)
	var pivot := Vector2(r.position.x + HAND_CARD_W / 2, r.position.y + HAND_CARD_H)
	draw_set_transform(pivot, _hand_angle(i), Vector2.ONE)
	# 「现在打出能吃到额外效果」→ 金色高亮框 + 顶部金星标（R65）。
	# 判定走 engine.hand_bonus_ready（唯一口），条件不满足就不画。
	var bonus := engine.hand_bonus_ready(card)
	_draw_card_face(card, Rect2(r.position - pivot, r.size), card.health, selected, false,
			engine.cost_of(card))
	# R151 P1-7：敌方回合的暗罩（自绘卡面没法整体降饱和，罩子是唯一便宜的等效）
	if _turn_dim > 0.01:
		draw_rect(Rect2(r.position - pivot, r.size), Color(0.102, 0.110, 0.133, _turn_dim), true)
	if bonus:
		_draw_hand_bonus_mark(Rect2(r.position - pivot, r.size))
	# R209：原来这里给「可改造 / 可回收」的手牌描青边 —— 系统升级 / 回收改走**全屏
	# 选卡页**后，选卡期间手牌根本点不到（`_on_left_click` 被 `_pick` 拦下），
	# 那两块高亮成了死代码，一并删掉（选卡页里每张候选都是可选的，不需要再标）。
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_turn_owner_fx() -> void:
	## R151 P1-6：回合归属的持续指示 —— 敌方回合：敌方单位极淡红边呼吸（硬边，不是辉光）
	## + 敌方能量框提亮；我方回合：手牌区轻微上浮（位移与暗罩在 _draw_hand_card）。
	if engine.over:
		return
	# R165：敌方「可行动」提示不再用红色呼吸边——统一改由 `_draw_ready_aura`
	# 的青色就绪环（敌我同标）表达，避免两种环叠在同一张敌卡上显得杂乱。


func _draw_pow_fx() -> void:
	## R151 P2-13：力量成长 —— 力量徽章跳动（1→1.35→1）+ 一圈扩散环（金，力量语义）。
	var n := _now()
	for f in _pow_fx:
		var t := clampf(float(n - int(f.start)) / int(f.dur), 0.0, 1.0)
		var p: Placement = engine.state.unit_at(f["cell"])
		if p == null:
			continue
		var ctr := _display_center(p, f["cell"])
		var w := BOARD_CARD_W
		var h := BOARD_CARD_H
		var bc := Vector2(ctr.x - w / 2.0, ctr.y + h / 2.0)   # 力量徽章圆心（左下，压左框线）
		var br := UiTheme.CARD_BADGE_R * BOARD_SCALE
		var bfs: int = maxi(7, roundi(UiTheme.CARD_FS_BADGE * BOARD_SCALE))
		var sc := 1.0 + 0.35 * sin(t * PI)
		CardFace.draw_badge(self, _font_bold, bc, br * sc, bfs, "power",
				str(p.effective_power()), UiTheme.BADGE_POWER)
		draw_arc(bc, br * (1.0 + t * 2.6), 0.0, TAU, 24,
				Color(1.0, 0.83, 0.48, 0.75 * (1.0 - t)), 2.0)


func _draw_heal_fx() -> void:
	## R151 P2-14：治疗上升光点 —— 硬边小圆 / 四角星交替（日漫 sparkle），生命语义绿。
	var n := _now()
	for f in _heal_fx:
		var t := float(n - int(f.start)) / int(f.dur)
		if t < 0.0:
			continue   # 错峰未到的粒子
		t = clampf(t, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 2.0)
		var seed := int(f.get("seed", 0))
		var base: Vector2 = _fx_pos(f)
		var off := Vector2(sin(seed * 2.1) * 14.0 + cos(seed * 1.3) * 6.0,
				cos(seed * 2.7) * 8.0 - 46.0 * e)
		var a := 1.0 - t
		if seed % 2 == 0:
			draw_circle(base + off, 2.6, Color(0.55, 0.88, 0.60, a))
		else:
			_draw_spark(base + off, 4.6, Color(0.55, 0.88, 0.60, a))


func _draw_spark(pos: Vector2, r: float, col: Color) -> void:
	## 硬边四角星（日漫 sparkle）：治疗光点 / 冲击帧共用。
	var q := r * 0.36
	draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -r), pos + Vector2(q, -q), pos + Vector2(r, 0),
			pos + Vector2(q, q), pos + Vector2(0, r), pos + Vector2(-q, q),
			pos + Vector2(-r, 0), pos + Vector2(-q, -q)]), col)


func _draw_impacts() -> void:
	## R151 P1-18：击破冲击白闪 —— 60ms 的白卡形 + 白四角星（锐利高光，不是辉光）。
	var n := _now()
	for f in _impacts:
		var t := clampf(float(n - int(f.start)) / int(f.dur), 0.0, 1.0)
		var a := 1.0 - t
		var pos: Vector2 = _fx_pos(f)
		draw_rect(Rect2(pos - Vector2(BOARD_CARD_W, BOARD_CARD_H) / 2.0,
				Vector2(BOARD_CARD_W, BOARD_CARD_H)), Color(1, 1, 1, 0.92 * a), true)
		_draw_spark(pos, 34.0 + 10.0 * t, Color(1, 1, 1, 0.85 * a))


func _draw_reject_fx() -> void:
	## R151 P2-15：打出被拒 —— 能量面板红闪 / 目标格红闪（卡的抖动在 _draw_hand_card）。
	var n := _now()
	var ef = _reject_flash.get("energy")
	if ef != null:
		var t := clampf(float(n - int(ef.start)) / int(ef.dur), 0.0, 1.0)
		if t < 1.0:
			draw_rect(Rect2(COST_X, COST_Y, TAP_W + 12, ENERGY_H),
					Color(0.90, 0.18, 0.12, 0.75 * (1.0 - t)), false, 2.2)
	var cf = _reject_flash.get("cell")
	if cf != null:
		var t2 := clampf(float(n - int(cf.start)) / int(cf.dur), 0.0, 1.0)
		if t2 < 1.0:
			draw_rect(_cell_rect(cf["cell"]).grow(-1.0),
					Color(0.90, 0.18, 0.12, 0.75 * (1.0 - t2)), false, 2.2)


func _draw_screen_flash() -> void:
	## R151 P1-18：全屏黑白闪（仅 Boss 击破与胜利，≤40ms）—— 前半白、后半黑，硬切。
	if _screen_flash.is_empty():
		return
	var n := _now()
	var t := clampf(float(n - int(_screen_flash.start)) / int(_screen_flash.dur), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size),
			Color(1, 1, 1, 0.92) if t < 0.5 else Color(0, 0, 0, 0.92), true)


func _draw_hand_fly() -> void:
	## R151 P0-1/2：抽牌飞入（卡背，错开 60ms）/ 弃牌·消耗飞出（缩小移动）/ 耳环合并淡出。
	## ⚠️ 飞出的卡面不做整体 alpha：卡面是自绘的、没有统一调制口（CardFace.draw 签名无 alpha）。
	##    「淡出」用等价手段 —— 弃牌 = 缩小进牌堆（终段被弃牌区板盖回，「滑进牌堆」）；
	##    消耗 = 边升边缩（缩到 0.55 自然读成消散）；只有合并淡出用真 alpha（卡背有 modulate 口）。
	var n := _now()
	for f in _hand_fly:
		var t := float(n - int(f["start"])) / int(f["dur"])
		if t < 0.0:
			continue                      # 还在等错开（逐张 60ms）
		t = clampf(t, 0.0, 1.0)
		var mode := str(f["mode"])
		if mode == "in":
			var e := 1.0 - pow(1.0 - t, 3.0)          # ease-out
			var slot: Rect2 = _hand_rect(int(f["slot"]))
			var pos: Vector2 = (f["from"] as Vector2).lerp(slot.get_center(), e)
			var sc := lerpf(0.62, 1.0, e)
			# 落位回弹：最后 80ms 从 1.06 收到 1.0（设计稿口径）
			var tail := 80.0 / int(f["dur"])
			if t > 1.0 - tail:
				sc *= lerpf(1.06, 1.0, (t - (1.0 - tail)) / tail)
			_draw_card_back(Rect2(pos - slot.size * sc / 2.0, slot.size * sc))
		elif mode == "fade":
			# 耳环合并淡出：手牌区中央一张卡背整体淡掉
			var r3 := Rect2(Vector2(WINDOW_W / 2.0, OWN_HAND_Y + 40) - Vector2(CARD_W, CARD_H) / 2.0,
					Vector2(CARD_W, CARD_H))
			_draw_card_back_fade(r3, 1.0 - t)
		else:
			var e2 := 1.0 - pow(1.0 - t, 2.0)
			var fr: Rect2 = f["from_rect"]
			var pos2 := fr.get_center()
			var sc2 := 1.0
			if mode == "out_d":
				pos2 = fr.get_center().lerp(
						Vector2(DISCARD_X + CARD_W / 2.0, DISCARD_Y + CARD_H / 2.0), e2)
				sc2 = lerpf(1.0, 0.6, e2)
			else:  # out_v：消耗 → 向上飞 + 缩小消散（与弃牌区分）
				pos2 = fr.get_center() + Vector2(0, -140.0 * e2)
				sc2 = lerpf(1.0, 0.55, e2)
			var card: CardData = f["card"]
			_draw_card_face(card, Rect2(pos2 - fr.size * sc2 / 2.0, fr.size * sc2),
					card.health, false, false, engine.cost_of(card))
			if mode == "out_d" and t > 0.8:
				# 终段：把弃牌区板盖回飞来卡的上面 →「滑进牌堆」而不是「停在牌堆上」
				_draw_zone_icon(_discard_tex, Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H),
						Color("a08a52"))



func _draw_deck_fly() -> void:
	## R283：卡入牌库（诅咒 / 镜面反射 / 生产订单）-> 卡背（诅咒紫调）飞入卡组区。
	var n := _now()
	for f in _deck_fly:
		var t := float(n - int(f["start"])) / int(f["dur"])
		if t < 0.0:
			continue
		t = clampf(t, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		var target := Vector2(DECK_X + CARD_W / 2.0, DECK_Y + CARD_H / 2.0)
		var pos := (f["from"] as Vector2).lerp(target, e)
		var sc := lerpf(0.55, 1.0, e)
		var r := Rect2(pos - Vector2(CARD_W, CARD_H) * sc / 2.0, Vector2(CARD_W, CARD_H) * sc)
		var curse := bool(f.get("curse", false))
		if curse:
			draw_rect(r.grow(5.0), Color(0.55, 0.20, 0.80, 0.45 * (1.0 - t)), true)
		_draw_card_back(r)
		if curse:
			draw_rect(r, Color(0.55, 0.18, 0.78, 0.40 * (1.0 - t * 0.5)), true)
			draw_rect(r, Color(0.78, 0.40, 0.95, 0.85 * (1.0 - t)), false, 2.5)

func _draw_transform_fx() -> void:
	## R283/R284：变幻特效 —— 扩散光环 + 火花 + 「变幻」字样，标记「这张卡被变化了」。
	## 按 zone 落点：hand=手牌位（slot）、deck=卡组堆、discard=弃牌堆 —— 同一套视觉跨区复用。
	var n := _now()
	for f in _transform_fx:
		var t := float(n - int(f["start"])) / int(f["dur"])
		if t < 0.0:
			continue
		t = clampf(t, 0.0, 1.0)
		var zone: String = str(f.get("zone", "hand"))
		var ctr: Vector2
		if zone == "hand":
			var slot: int = int(f.get("slot", -1))
			if slot < 0 or slot >= engine.state.hand.size():
				continue
			ctr = _hand_rect(slot).get_center()
		elif zone == "deck":
			ctr = Vector2(DECK_X + CARD_W / 2.0, DECK_Y + CARD_H / 2.0)
		else:  # discard
			ctr = Vector2(DISCARD_X + CARD_W / 2.0, DISCARD_Y + CARD_H / 2.0)
		var a := 1.0 - t
		var rad := lerpf(CARD_W * 0.30, CARD_W * 1.10, t)
		draw_arc(ctr, rad, 0.0, TAU, 30, Color(0.78, 0.40, 0.95, a * 0.9), 3.0)
		draw_arc(ctr, rad * 0.6, 0.0, TAU, 26, Color(0.95, 0.72, 1.0, a * 0.7), 2.0)
		for k in 6:
			var ang := TAU * float(k) / 6.0 + float(n) * 0.004
			var p0 := ctr + Vector2(cos(ang), sin(ang)) * rad * 0.5
			var p1 := ctr + Vector2(cos(ang), sin(ang)) * rad * 1.05
			draw_line(p0, p1, Color(0.90, 0.62, 1.0, a * 0.8), 2.0)
		_draw_string_center(_font_bold, UiTheme.FS_LABEL, "变幻",
			ctr + Vector2(0.0, -CARD_H * 0.5 - 8.0), Color(0.85, 0.50, 1.0, a))

func _draw_card_back_fade(rect: Rect2, alpha: float) -> void:
	## 带透明度的卡背（耳环合并淡出用）：有素材走 modulate，兜底图形用 alpha 色。
	if _back_tex != null:
		draw_texture_rect(_back_tex, rect, false, Color(1, 1, 1, alpha))
	else:
		draw_rect(rect, Color(0, 0, 0, alpha))
		var inset: float = minf(rect.size.x, rect.size.y) * 0.18
		draw_line(rect.position + Vector2(inset, inset),
				rect.end - Vector2(inset, inset), Color(1, 1, 1, alpha), 2.0)
		draw_line(Vector2(rect.end.x - inset, rect.position.y + inset),
				Vector2(rect.position.x + inset, rect.end.y - inset), Color(1, 1, 1, alpha), 2.0)
	var edge := Color("20283f")
	edge.a = alpha
	draw_rect(rect, edge, false, 1.5)


func _draw_hand_bonus_mark(r: Rect2) -> void:
	## 手卡「额外效果可触发」的金色标记：外框 + 右上角一颗金星。
	## 只做视觉，判定在 engine.hand_bonus_ready。
	var k := r.size.y / CardFace.CARD_H_DESIGN
	var col := COL_HAND_BONUS
	draw_rect(r.grow(2.0 * k), Color(col.r, col.g, col.b, 0.20), true)
	draw_rect(r.grow(2.0 * k), col, false, 2.2 * k)
	var star := r.position + Vector2(r.size.x - 9.0 * k, 11.0 * k)
	draw_circle(star, 7.0 * k, Color(0.10, 0.09, 0.12, 0.92))
	draw_arc(star, 7.0 * k, 0, TAU, 20, col, 1.6 * k, true)
	_draw_string_center(_font_bold, int(10 * k), "★", star, col)


func _draw_drag() -> void:
	## 拖拽释放演出：目标格高亮 + 半透明卡牌跟随光标。
	if _drag_idx < 0 or _drag_idx >= engine.state.hand.size():
		return
	# R242：AOE 技能（火球 / 陨石 / 回旋斩 / 火墙）**不逐格刷紫** —— 它们的可选格往往是
	# 「全盘」或「整行」，紫色填充会把下面那层橙色范围盖得看不见；范围由
	# `_draw_spell_preview` 统一画（还能带上自伤警告）。单体技能照旧刷紫。
	var _dragging: CardData = engine.state.hand[_drag_idx]
	var _aoe_kind := spell_aoe_kind(_dragging)
	if _aoe_kind == "":
		for cell in _drag_spell_cells:
			_hl(cell, COL_SPELL)
	if _drag_place:
		for cell in _drag_place_cells:
			# 已有栅栏的格子（叠栅栏）用橙色 + 「叠」标记，与绿色空格区分
			if engine.state.board.has(cell):
				_hl(cell, COL_FENCE_MERGE)
				_draw_string_center(_font_bold, UiTheme.FS_LABEL, "叠", _cell_center(cell), Color.WHITE)
			else:
				_hl(cell, COL_MOVE)
	var card := engine.state.hand[_drag_idx]
	# R242：拆解（8049）的「额外获得升级」金色提示已并入 `_draw_spell_preview` ——
	# 它和偷袭的「满血双倍」是同一类「条件额外效果」，不该各画一套。
	# R106：拖的是效果卡 → 高亮左侧效果区（**落点**就是它以后待着的地方）。
	# R117 订正文案：原来写「松手启用 / 拖到这里启用」，但 R117 把「松手生效的范围」
	# 扩到了**左半边整片**（见 `_effect_drop_rect`，外框由 `_drag_zone_rect` 统一画）。
	# 于是这块绿框只剩一个含义 —— **它会落在哪** —— 文案就直说这一件事，
	# 免得同一屏里出现两句都在说「松手点这里」的话（玩家要在两块高亮之间做选择）。
	if _drag_to_effects:
		var ez := _own_effect_zone_rect()
		var over := _drag_zone_rect().has_point(_drag_pos)
		draw_rect(ez, Color(0.30, 0.75, 0.55, 0.22 if over else 0.10), true)
		draw_rect(ez, Color(0.28, 0.82, 0.58, 0.95 if over else 0.45), false,
				3.0 if over else 1.5)
		_draw_string_center(_font_bold, UiTheme.FS_MICRO, "效果卡放这里",
				ez.position + Vector2(ez.size.x / 2.0, ez.size.y - 12.0),
				Color(0.12, 0.42, 0.30))
	# ── R117：标出「松手即生效」的**区域**（用户口径「标明拖拽后可以使用的区域」）──
	# 目标格一个个高亮只说了「这些格可以」，说不出「这块地方整体都能松手」；
	# 外框把可用范围一次讲清，光标进入时加粗 —— 松手前就知道会不会生效。
	var zone := _drag_zone_rect()
	if zone.size.x > 0.0:
		var in_zone := zone.has_point(_drag_pos)
		# ⚠️ 填充要**很淡**：R117 的区域最大能到「左半边整片 / 整个棋盘」，
		# 0.14 会把卡面一起罩成蓝紫（出图实见）。区域越大，边框越是主角。
		draw_rect(zone, Color(COL_DROP_ZONE.r, COL_DROP_ZONE.g, COL_DROP_ZONE.b,
				0.09 if in_zone else 0.04), true)
		draw_rect(zone, COL_DROP_ZONE, false, 2.5 if in_zone else 1.5)
		_draw_string_center(_font_bold, UiTheme.FS_CAPTION, _drag_zone_label(),
				Vector2(zone.position.x + zone.size.x / 2.0, zone.position.y - 8.0),
				COL_DROP_ZONE)
	# 跟着光标走的卡与手牌同尺寸（从手牌里"拿起来"不会突然变小）；
	var rect := _drag_footprint(_drag_pos)
	_draw_card_face(card, rect, card.health, true, false, engine.cost_of(card))
	# 目标光圈：**只在松手真的会生效时画，并且画在真的会命中的那一格上**。
	# 旧版无条件画「离光标最近的候选格」—— 光标已经在可释放区域之外（松手会取消）时，
	# 光圈还挂在一个目标上，玩家会以为已经打出去了（用户口径「有误导性」）。
	var hit = _drag_hit_cell()
	if hit != null:
		# R242：AOE 范围 / 自伤警告 / 条件额外效果（放置类不是施法，跳过）
		if not _drag_place:
			_draw_spell_preview(card, hit)
		var cc := _cell_center(hit)
		var rc := COL_SPELL_RING
		if _drag_place:
			rc = COL_FENCE_MERGE if engine.state.board.has(hit) else COL_MOVE
		draw_arc(cc, minf(CELL, CELL_W) * 0.62, 0, TAU, 32, rc, 3.0)


static func spell_bonus_note(card: CardData, p: Placement) -> String:
	## 这一发打在**这个单位**上，有没有「条件额外效果」（有 → 返回提示文案，"" = 没有）。
	## **纯函数**（绘制与回归共用），判据与引擎逐条对齐，加新的「条件加成」卡只改这里：
	##   * 偷袭 9090：目标**满血** → 6 改 12（引擎：`p.health >= p.card.health`）
	##   * 拆解 8049（R97）：目标被改造过 → 额外获得升级
	if card == null or p == null:
		return ""
	if card.id == GameEngine.SNEAK_ID and p.health >= p.card.health:
		return "满血：%d → %d" % [GameEngine.SNEAK_DMG, GameEngine.SNEAK_FULL_DMG]
	if card.id == GameEngine.DEMOLISH_ID \
			and (p.upgrade_stacks > 0 or p.upgrade_atk != 0 or p.upgrade_hp != 0):
		return "额外获得升级"
	return ""


func _spell_bonus_label(card: CardData, cell: Vector2i) -> String:
	## 屏幕坐标那一格 → 单位 → 交给纯函数判有没有额外效果。
	if card == null or engine == null:
		return ""
	return spell_bonus_note(card, engine.state.unit_at(cell))


func _draw_spell_preview(card: CardData, center: Vector2i) -> void:
	## R242：**释放预览的唯一绘制口** —— 拖拽释放与「点选目标后再悬停」两条路都调它。
	## 三层，从下到上：
	##   ① AOE 覆盖格（浅橙填充 + 橙框）：告诉玩家「这一发会打到哪几格」；
	##   ② 自伤警告（红色脉冲框 + 文字）：覆盖到己方单位 / 我方后排时才亮；
	##   ③ 条件额外效果（金色双环 + 文案）：偷袭满血、拆解打已改造目标。
	if card == null or engine == null:
		return
	var info := aoe_danger(engine.state, card, center)
	var cells: Array[Vector2i] = info["cells"]
	if String(info["kind"]) != "":
		for c: Vector2i in cells:
			var r := _cell_rect(c).grow(-2.0)
			draw_rect(r, COL_AOE, true)
			draw_rect(r, COL_AOE_EDGE, false, 1.6)
	# ② 自伤警告：红框按时间做呼吸（相位取 _now()，不额外开 Timer）
	var own := int(info["own"])
	if own > 0 or bool(info["hp"]):
		var pulse := 0.55 + 0.45 * absf(sin(float(_now()) * 0.004))
		var dcol := Color(COL_AOE_DANGER.r, COL_AOE_DANGER.g, COL_AOE_DANGER.b, pulse)
		var bb := _cells_bbox(cells).grow(2.0)
		draw_rect(bb, dcol, false, 3.0)
		var txt := ""
		if bool(info["hp"]):
			txt = "⚠ 会伤到自己 HP"
		elif bool(info["burn"]):
			txt = "⚠ 不分敌我：我行单位立刻 -%d，走过去还会被烧" % GameEngine.FIRE_WALL_DMG
		else:
			txt = "⚠ 会波及自己人 ×%d" % own
		_draw_string_box_center(_font_bold, UiTheme.FS_LABEL, txt,
				Vector2(bb.get_center().x, bb.position.y - 13.0), Color("ffe2e2"),
				Color(0.22, 0.05, 0.05, 0.88))
	# ③ 条件额外效果：金色双环 + 文案（在格子下方，不挡飘字）
	var bonus := _spell_bonus_label(card, center)
	if bonus != "":
		var cc := _cell_center(center)
		var kw := minf(CELL, CELL_W)
		draw_arc(cc, kw * 0.60, 0, TAU, 32, COL_BONUS, 2.5)
		draw_arc(cc, kw * 0.72, 0, TAU, 32, COL_BONUS, 1.4)
		_draw_string_box_center(_font_bold, UiTheme.FS_CAPTION, bonus,
				cc + Vector2(0, kw * 1.06), COL_BONUS, Color(0.14, 0.11, 0.03, 0.86))


static func _info_blocks(card: CardData, pl: Placement) -> Array:
	## 左栏框体流的**唯一组装口**（R297）。顺序就是用户口径：
	##   数值两框 → 「效果」小标题 + 效果文本框 → 字段解释框（每个字段一个）
	##   → buff 框（每种一个；**附魔也算 buff**，排在最前面 —— 花钱买的，最该被看见）。
	## ⚠️ 字段 / buff 的**文案与图标一律从数据层读**（`CardData.AFFIX_DEFS` /
	##    `ENCHANT_DEFS` / `Placement.status_entries()`）：这里不许为某张卡写特例，
	##    否则新卡加进来又得回来补一段。
	## ⚠️ 数值不拆行：「力量 + 生命」一个框、「攻击距离 + 移动速度」一个框（图标 + 数字）。
	var out: Array = []
	# ① 数值框（只有场上单位 / 工事才有值意义）
	if card.kind == "盟友" or card.kind == "工事":
		var hp_now: int = pl.health if pl != null else card.health
		var hp_txt: String = "%d/%d" % [hp_now, card.health] if pl != null else str(card.health)
		var pw_now: int = pl.effective_power() if pl != null else card.power
		var pw_txt: String = str(pw_now)
		if pl != null and pw_now != card.power:
			pw_txt = "%d（原 %d）" % [pw_now, card.power]
		out.append({
			"type": "stats", "kind": "stats", "col": Color("6b6155"),
			"items": [
				{"icon": UiAssets.badge_icon("power"), "text": pw_txt, "col": UiTheme.STAT_POWER},
				{"icon": UiAssets.badge_icon("health"), "text": hp_txt,
						"col": UiTheme.STAT_HEALTH},
			],
		})
		# ⚠️ 移速 / 射程一律走 `effective_*()`：夜鸭的奇数回合 -1、暗影领主、动员的
		# 场上修正都要看得见（旧注释里那条「栏里写速 2、实际只走得动 1 格」的教训）。
		var rng_shown: int = pl.effective_range() if pl != null else card.attack_range
		var spd_shown: int = pl.effective_speed() if pl != null else card.move_speed
		# 场上修正（夜鸭 / 暗影领主 / 动员）改了数值时标出原值 —— 否则玩家会以为卡面写错了
		var rng_txt: String = str(rng_shown)
		if pl != null and rng_shown != card.attack_range:
			rng_txt = "%d（原 %d）" % [rng_shown, card.attack_range]
		var spd_txt: String = str(spd_shown)
		if pl != null and spd_shown != card.move_speed:
			spd_txt = "%d（原 %d）" % [spd_shown, card.move_speed]
		var mv_items: Array = [
			{"icon": UiAssets.badge_icon("range"), "text": rng_txt,
					"col": UiTheme.INK_600},
		]
		if card.kind == "盟友":
			mv_items.append({"icon": UiAssets.badge_icon("speed"), "text": spd_txt,
					"col": UiTheme.INK_600})
		out.append({"type": "stats", "kind": "stats", "col": Color("6b6155"), "items": mv_items})
	# ② 效果正文：单独一个框，**高度随文字量**（`CardInfoBoxes.box_h` 折行数出来）
	out.append({"type": "caption", "kind": "caption", "title": "效果", "col": Color("2a5a8a")})
	out.append({"type": "text", "kind": "text", "col": Color("2a5a8a"),
			"segs": CardText.parse(card.effect_text)})
	# ③ 字段解释框：每个字段一个，框内「图标 名字：解释」
	for a: String in card.affixes:
		var ac := CardData.affix_colors(a)
		var col: Color = (ac[1] as Color).darkened(0.30)   # 亮色压暗，浅底上才读得清
		out.append({
			"type": "line", "kind": "affix",
			"glyph": CardData.affix_glyph(a),
			"col": col,
			"title": CardData.affix_label(a),
			"segs": [{"text": CardData.affix_label(a), "bold": true},
					{"text": "：" + CardData.affix_desc(a)}],
		})
	# ④ buff 框：每种一个（附魔按用户口径也算 buff）
	if card.has_enchant():
		out.append({
			"type": "line", "kind": "enchant",
			"icon": UiAssets.enchant_icon(card.enchant),
			"col": CardData.enchant_color(card.enchant).darkened(0.12),
			"title": CardData.enchant_name(card.enchant),
			"segs": [{"text": "附魔 · " + CardData.enchant_name(card.enchant), "bold": true},
					{"text": "：" + CardData.enchant_desc(card.enchant)}],
		})
	if pl != null:
		for e: Dictionary in pl.status_entries():
			var k := str(e.get("kind", "buff"))
			out.append({
				"type": "line", "kind": "buff",
				"glyph": "up" if k == "buff" else ("down" if k == "debuff" else "dot"),
				"col": e.get("col", UiTheme.INK_600),
				"title": str(e.get("label", "")),
				"segs": [{"text": str(e.get("label", ""))}],
			})
	return out



func _draw_info_panel() -> void:
	## 左侧信息栏（悬停优先，其次选中的卡）：卡的**详细效果**。
	## 手牌卡底沉出窗口后，「程 / 速」这类小字只能在这里看全，所以这栏要写满：
	##   编号·名字 → 种类·费用·稀有度 → 数值（战场单位带当前/上限）→ 词条 →
	##   每回合行动数 → 效果正文（按面板宽度自动换行，放不下画省略号）。
	_hover_purge_stale()   # R294：手牌变了 → 先清掉过期的悬停，别让左栏停在旧卡上
	var card: CardData = null
	var pl: Placement = null
	if _hover_card != null:
		card = _hover_card
		pl = _hover_pl
	elif selection != null:
		if selection[0] == "hand":
			card = engine.state.hand[selection[1]]
		elif selection[0] == "board":
			pl = engine.state.unit_at(selection[1])
			if pl != null:
				card = pl.card
	if card == null:
		return
	var top := GRID_Y
	UiTheme.draw_panel_bg(self, Rect2(INFO_X, top, INFO_W, GRID_H))
	draw_rect(Rect2(INFO_X, top, INFO_W, GRID_H), UiTheme.INK_300, false, 1.0)
	var left := INFO_X + 10.0
	var right := INFO_X + INFO_W - 10.0
	var inner_w := INFO_W - 20.0
	var y := top + 21.0
	_draw_string_nw(_font_bold, UiTheme.FS_CAPTION, "#%d %s" % [card.id, card.card_name],
			Vector2(left, y), card.rarity_color())
	y += 17.0
	# 费用：显示**当前实际费用**（悬停/选中手牌时套用本回合减费，低于卡面则标绿）
	var hand_idx := _hover_hand
	if hand_idx < 0 and selection != null and selection[0] == "hand":
		hand_idx = selection[1]
	var show_cost := card.cost
	var cost_low := false
	if hand_idx >= 0 and hand_idx < engine.state.hand.size() \
				and engine.state.hand[hand_idx] == card:
		show_cost = engine.cost_of(card)
		cost_low = show_cost < card.cost
	var cost_line: String = "%s · 费用 %d%s · %s" % [card.kind, show_cost,
			"（原 %d）" % card.cost if cost_low else "", card.rarity_name()]
	if card.x_cost:
		# X 费卡（流星雨）：费用随剩余能量浮动 → 左栏直接写「费用 X（消耗全部能量）」
		cost_line = "%s · 费用 X（消耗全部能量）· %s" % [card.kind, card.rarity_name()]
	_draw_string_nw(_font, UiTheme.FS_MICRO, cost_line,
			Vector2(left, y), COL_COST_LOW_BG if cost_low else UiTheme.INK_600)
	y += 13.0
	draw_line(Vector2(left, y), Vector2(right, y), Color("cfcbc2"), 1.0)
	y += 17.0
	# R262（用户口径）：**「现在打出会造成多少伤害」**——只对**卡面文案给不出确数**的技能卡显示
	#（终结 2+X / 连环戏法 5→10 / 偷袭 6→12 / 流星雨 8×X）。这类卡玩家只能心算，
	# 详情里直接报当前真实值；数值与结算同源（`GameEngine.spell_now()` → `_spell_dmg()`）。
	# ⚠️ 只在**手牌**上显示：费用区 / 弃牌区 / 敌方卡上算这个数没有意义。
	if hand_idx >= 0 and hand_idx < engine.state.hand.size() \
				and engine.state.hand[hand_idx] == card:
		var now := engine.spell_now(card)
		if not now.is_empty():
			_draw_string_nw(_font_bold, UiTheme.FS_MICRO,
					"现在打出：%d 点伤害" % int(now.get("dmg", 0)), Vector2(left, y),
					Color("a3241c"))
			y += 15.0
			_draw_string_nw(_font, UiTheme.FS_MICRO, str(now.get("note", "")),
					Vector2(left + 6.0, y), Color("8a5a2a"))
			y += 19.0
	if not card.traits.is_empty():
		var tt := ""
		for t in card.traits:
			tt += (" · " if tt != "" else "") + str(t)
		_draw_string_nw(_font, UiTheme.FS_MICRO, "词条：" + tt, Vector2(left, y), Color("886000"))
		y += 17.0
	# R297：**框体流**（用户口径）—— 数值两框 → 效果文本框 → 字段框 → buff 框。
	# 以前这些全是纯文本行「力量 3 生命 5 / 字段：嘲讽 · 次元 / · 护盾：免疫…」，
	# 一层层堆下来读不出结构；现在每类一个框，**框高随内容量变**（`CardInfoBoxes.box_h`）。
	var blocks := _info_blocks(card, pl)
	# R302：把「提及」的命中矩形交出去（悬停「素体」两个字才弹说明）。
	# 用户口径：**不要**再把摘要固定列在详情底部 —— 那块地方还给效果框 / buff 框。
	_mention_hits.clear()
	CardInfoBoxes.draw_all(self, blocks, left, y, inner_w, CardInfoBoxes.FS,
			top + GRID_H - 12.0, _mention_hits)



func _info_panel_rect() -> Rect2:
	## 左栏（卡牌详情）的矩形 —— 绘制与「鼠标能不能停在上面」共用这一个口。
	return Rect2(INFO_X, GRID_Y, INFO_W, GRID_H)


func _draw_mention_tip() -> void:
	## R302：悬停（触屏：点住）效果文本里的「提及」→ 弹真实卡面 / 道具说明。
	## 与奖励面板 / 事件页**同一套**悬浮件（`Mention.draw_tip`：暗底 + 金边）。
	## 位置：优先贴命中矩形**右侧**，放不下换左侧，最后夹进窗口。
	var ref: Dictionary = _hover_mention if not _hover_mention.is_empty() else _mention_pin
	if ref.is_empty():
		return
	var sz := Mention.tip_size(_font, ref)
	var anchor: Rect2 = ref.get("rect", Rect2())
	var x := anchor.end.x + 10.0
	# 命中就在左栏里 → 浮窗放到左栏**右外侧**（它比左栏还宽，贴右侧会把左栏盖掉）
	if anchor.end.x <= INFO_X + INFO_W:
		x = INFO_X + INFO_W + 8.0
	if x + sz.x > WINDOW_W - 8.0:
		x = anchor.position.x - sz.x - 10.0
	x = clampf(x, 8.0, maxf(8.0, WINDOW_W - sz.x - 8.0))
	var y := clampf(anchor.position.y - 8.0, 8.0, maxf(8.0, WINDOW_H - sz.y - 8.0))
	Mention.draw_tip(self, _font, _font_bold, ref, Vector2(x, y))


func _draw_game_over() -> void:
	var win := engine.result == "胜利"
	var cx := GRID_X + GRID_W / 2
	var cy := GRID_Y + GRID_H / 2
	var col := COL_WIN if win else COL_LOSE
	UiTheme.draw_panel_bg(self, Rect2(GRID_X + 12, cy - 58, GRID_W - 24, 116))
	draw_rect(Rect2(GRID_X + 12, cy - 58, GRID_W - 24, 116), col, false, 3.0)
	_draw_string_center(_font_bold, UiTheme.FS_HEADING, "胜  利" if win else "失  败", Vector2(cx, cy - 20), col)
	_draw_string_center(_font, UiTheme.FS_MICRO, engine.result_reason, Vector2(cx, cy + 28), UiTheme.INK_600)


func _draw_banner() -> void:
	## 回合切换大字横幅：淡入 → 停留 → 上浮淡出。
	if _banner.is_empty():
		return
	var p := clampf(float(_now() - int(_banner.start)) / int(_banner.dur), 0.0, 1.0)
	var alpha: float = minf(p * 8.0, 1.0) * minf((1.0 - p) * 5.0, 1.0)
	var col: Color = _banner.col
	col.a = alpha
	var cx := GRID_X + GRID_W / 2
	var cy := GRID_Y + GRID_H * 0.42 - 18.0 * p
	draw_rect(Rect2(cx - 150, cy - 30, 300, 60), Color(1, 1, 1, 0.72 * alpha))
	draw_rect(Rect2(cx - 150, cy - 30, 300, 60), Color(col.r, col.g, col.b, alpha), false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_HEADING, str(_banner.text), Vector2(cx, cy + 8), col)


func _draw_confetti() -> void:
	## 胜利彩带（旋转的小纸条）。
	for c: Dictionary in _confetti:
		draw_set_transform(c.pos, c.rot)
		var sz: Vector2 = c.size
		draw_rect(Rect2(-sz / 2.0, sz), c.col)
	draw_set_transform(Vector2.ZERO, 0.0)



func _zone_panel_cards() -> Array:
	## 当前打开的「区域浏览面板」里的卡（都没打开 → 空数组）。
	## 效果类面板同名合并 / 卡组面板同 id 合并：只放代表卡（与面板显示一致）。
	if _effects_visible:
		return _merged_effects(engine.state.effects).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _enemy_effects_visible:
		return _merged_effects(engine.state.enemy_effects).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _run_deck_visible:
		return _merged_deck(_run_deck_cards()).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _deck_visible:
		return _merged_deck(engine.state.deck).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _void_visible:
		return _merged_deck(engine.state.void_cards).map(
				func(m: Dictionary) -> CardData: return m["card"])
	# R301：弃牌区不再走本面板（改全屏浏览窗 `_open_discard_view()`）
	return []


func _zone_panel_counts() -> Array:
	## 与 _zone_panel_cards 平行的合并张数（弃牌区不合并 → 空数组）。
	if _effects_visible:
		return _merged_effects(engine.state.effects).map(
				func(m: Dictionary) -> int: return m["count"])
	if _enemy_effects_visible:
		return _merged_effects(engine.state.enemy_effects).map(
				func(m: Dictionary) -> int: return m["count"])
	if _run_deck_visible:
		return _merged_deck(_run_deck_cards()).map(
				func(m: Dictionary) -> int: return m["count"])
	if _deck_visible:
		return _merged_deck(engine.state.deck).map(
				func(m: Dictionary) -> int: return m["count"])
	if _void_visible:
		return _merged_deck(engine.state.void_cards).map(
				func(m: Dictionary) -> int: return m["count"])
	return []


func _merged_deck(cards: Array) -> Array:
	## 牌堆按**卡面签名**合并显示：[{card, count}]。
	## ⚠️ R207：不能只按 `id` 合并 —— 商店附魔（R181）生成的是**同 id 的独立副本**，
	##    按 id 合并会把「+10 攻击的那张」并进原卡、只留其中一个卡面，
	##    玩家在「完整卡组」里就看不见自己花钱买的附魔了（卡名一样、数值不一样）。
	## 排序用（费用, id）而非出现顺序 —— 玩家不能从面板推出抽牌顺序。
	var order: Array = []
	var by_key := {}
	for c: CardData in cards:
		var key := "%d|%d|%d|%d|%s" % [c.id, c.cost, c.power, c.health,
				",".join(c.affixes)]
		if not by_key.has(key):
			var e := {"card": c, "count": 0}
			by_key[key] = e
			order.append(e)
		by_key[key]["count"] += 1
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = a["card"]
		var cb: CardData = b["card"]
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		if ca.id != cb.id:
			return ca.id < cb.id
		return ca.power < cb.power)
	return order


## 区域浏览面板里卡与卡的间距（R115）：卡 58×70 + 18 → 正好装下骑在框上的
## 数值（图标半径 8.5，左右各一份 = 17 ≤ 18）。绘制与悬停判定**共用**这一个常数。
## R117：卡从 58×70 长到 63×76（k = 76/70 ≈ 1.086）→ 每侧外溢 9.2×1.086 ≈ 10px。
## 18 只够 9px，抬到 20。代价是每行列数 14 → 13（卡本来就变大了，可接受）。
const ZONE_CARD_GAP := 20.0


func _zone_panel_layout(n: int) -> Dictionary:
	## 区域浏览面板的网格布局：绘制与悬停判定共用一份，改一处即可。
	## R155 分页：面板高度封顶 → 放不下的行走**翻页**（page_rows / pages）。
	## ⚠️ 不做滚动 —— Godot 4.3 画布没有裁剪，滚到一半的行会画出面板外。
	# 先按可用宽度尽量多排几列（至少 1 列），再按张数算行数
	var cols := maxi(1, int((WINDOW_W - 180.0) / (CARD_W + ZONE_CARD_GAP)))
	cols = mini(cols, maxi(n, 1))
	var rows := maxi(1, int(ceil(float(n) / float(cols))))
	var grid_w := cols * (CARD_W + ZONE_CARD_GAP) - ZONE_CARD_GAP
	var pw := minf(WINDOW_W - 80.0, grid_w + 60.0)
	var rows_fit := maxi(1, int((WINDOW_H - 40.0 - 86.0 + ZONE_CARD_GAP) / (CARD_H + ZONE_CARD_GAP)))
	var page_rows := mini(rows, rows_fit)
	var pages := maxi(1, int(ceil(float(rows) / float(page_rows))))
	var ph := minf(WINDOW_H - 40.0, page_rows * (CARD_H + ZONE_CARD_GAP) + 86.0)
	var px := (WINDOW_W - pw) / 2
	var py := (WINDOW_H - ph) / 2
	var x0 := px + (pw - grid_w) / 2
	return {"cols": cols, "px": px, "py": py, "pw": pw, "ph": ph, "x0": x0,
			"page_rows": page_rows, "pages": pages}


func _zone_card_rect(i: int, L: Dictionary) -> Rect2:
	## 面板里第 i 张卡的矩形（悬停判定用）。R155：y 按**页内行号**算（非本页的卡落到面板外）。
	var cols: int = L["cols"]
	var row_in_page := int(i / cols) - _zone_page * int(L["page_rows"])
	return Rect2(L["x0"] + (i % cols) * (CARD_W + ZONE_CARD_GAP),
			L["py"] + 42.0 + row_in_page * (CARD_H + ZONE_CARD_GAP), CARD_W, CARD_H)


func _zone_panel_rect() -> Rect2:
	## 当前打开的区域面板外框（R155「点面板外才关闭」的判定；绘制与输入共用）。
	var L := _zone_panel_layout(maxi(_zone_panel_cards().size(), 1))
	return Rect2(L["px"], L["py"], L["pw"], L["ph"])


func _zone_close_rect() -> Rect2:
	## 面板右上「×」关闭按钮。
	var L := _zone_panel_layout(maxi(_zone_panel_cards().size(), 1))
	return Rect2(L["px"] + L["pw"] - 36.0, L["py"] + 8.0, 26.0, 26.0)


func _zone_prev_page_rect() -> Rect2:
	var L := _zone_panel_layout(maxi(_zone_panel_cards().size(), 1))
	return Rect2(L["px"] + 16.0, L["py"] + L["ph"] - 32.0, 34.0, 26.0)


func _zone_next_page_rect() -> Rect2:
	var L := _zone_panel_layout(maxi(_zone_panel_cards().size(), 1))
	return Rect2(L["px"] + L["pw"] - 50.0, L["py"] + L["ph"] - 32.0, 34.0, 26.0)


func _draw_zone_panel(title: String, cards: Array, counts: Array = []) -> void:
	## 区域浏览面板（R155 facelift）：羊皮纸 + 金边（与奖励悬浮窗同一语言）、标题栏、
	## 右上「×」、**分页**（滚轮或点 ‹ ›；旧版「点任意处关闭」改成「点面板外 / × 关闭」）。
	## 悬停任意一张 → 左侧信息栏显示它的明细（判定走 _zone_card_rect）。
	## counts 非空时与 cards 平行：>1 的在左下角画「×N」合并张数角标。
	var n := cards.size()
	var L := _zone_panel_layout(n)
	var pages: int = L["pages"]
	_zone_page = clampi(_zone_page, 0, pages - 1)   # 卡数会变 → 页码钳回合法区间
	var pw: float = L["pw"]
	var ph: float = L["ph"]
	var px: float = L["px"]
	var py: float = L["py"]
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	UiTheme.draw_panel_bg(self, Rect2(px, py, pw, ph))
	draw_rect(Rect2(px, py, pw, ph), UiTheme.ACCENT_GOLD, false, 2.0)
	_draw_string_center(_font_bold, UiTheme.FS_LABEL, "%s — 点击面板外关闭" % title,
			Vector2(WINDOW_W / 2, py + 24), UiTheme.INK_800)
	if pages > 1:
		_draw_string_center(_font, UiTheme.FS_CAPTION, "第 %d/%d 页（滚轮翻页）" % [_zone_page + 1, pages],
				Vector2(WINDOW_W / 2, py + ph - 15), UiTheme.INK_500)
		_draw_string_center(_font_bold, UiTheme.FS_HEADING, "<",
				_zone_prev_page_rect().get_center() + Vector2(0, 1),
				UiTheme.INK_600 if _zone_page > 0 else UiTheme.INK_300)
		_draw_string_center(_font_bold, UiTheme.FS_HEADING, ">",
				_zone_next_page_rect().get_center() + Vector2(0, 1),
				UiTheme.INK_600 if _zone_page < pages - 1 else UiTheme.INK_300)
	# 右上「×」
	draw_rect(_zone_close_rect(), Color("c9bfa6"), true)
	draw_rect(_zone_close_rect(), UiTheme.INK_300, false, 1.0)
	_draw_string_center(_font_bold, UiTheme.FS_LABEL, "×",
			_zone_close_rect().get_center() + Vector2(0, 1), UiTheme.INK_800)
	if n == 0:
		return
	var page_rows: int = L["page_rows"]
	var cols: int = L["cols"]
	for i in n:
		var row_in_page := int(i / cols) - _zone_page * page_rows
		if row_in_page < 0 or row_in_page >= page_rows:
			continue
		var c: CardData = cards[i]
		var face := _zone_card_rect(i, L)
		_draw_card_face(c, face, c.health, false, false)
		_draw_counter_badge(c, face)
		if not counts.is_empty():
			_draw_count_badge(face, counts[i])


func _wrap_lines(font: Font, px: int, text: String, max_w: float) -> PackedStringArray:
	## 折行唯一口 = `TextWrap.wrap_plain`（R292）—— 以前这里是第七份「逐字累加」的
	## 私有实现，行首照样会撞标点。现在全工程共用一套规则。
	return PackedStringArray(TextWrap.wrap_plain(font, text, max_w, px))


func _relic_panel_rows() -> Array:
	## 道具面板的每行内容：[名称行, 描述折行数组, 来源色]。
	var ids := engine.self_relics
	var repo := RelicRepo.load_json()
	var rows: Array = []
	for i in ids.size():
		var rel := repo.get_relic(ids[i])
		var nm := rel.relic_name if rel != null else str(ids[i])
		var desc := rel.desc if rel != null else ""
		var scol := rel.badge_color() if rel != null else Color.GRAY
		var tag := rel.tag_line() if rel != null else "道具"
		# R343：名字与标签**分开画** —— 传奇道具名要单独换色，混在一整串里就得整串变金
		#（标签也跟着金，「来源 · 时机」就不好读了）。位置按名字实际宽度顺排。
		var ncol: Color = rel.name_color(Color("4a3c14")) if rel != null else Color("4a3c14")
		rows.append(["「%s」" % nm, "（%s）" % tag,
				_wrap_lines(_font, RELIC_P_DESC, desc, RELIC_PANEL_W - 96.0), scol, ncol])
	return rows


func _relic_panel_rows_height() -> float:
	var h := 0.0
	for r in _relic_panel_rows():
		h += RELIC_P_ROWH + (r[2] as PackedStringArray).size() * RELIC_P_LINE + 10.0
	return h


func _draw_relic_panel() -> void:
	## 道具浏览面板：本局全部道具 + 完整说明（长描述自动折行；太多时滚轮翻动）。
	var ids := engine.self_relics
	var n := ids.size()
	var pw := minf(WINDOW_W - 160.0, RELIC_PANEL_W)
	var ph := minf(WINDOW_H - 40.0, 620.0)
	var px := (WINDOW_W - pw) / 2
	var py := (WINDOW_H - ph) / 2
	var rows := _relic_panel_rows()
	var scroll_max := maxf(0.0, _relic_panel_rows_height() + 66.0 - ph)
	_relic_scroll = clampf(_relic_scroll, 0.0, scroll_max)
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	UiTheme.draw_panel_bg(self, Rect2(px, py, pw, ph))
	draw_rect(Rect2(px, py, pw, ph), UiTheme.INK_600, false, 2.0)
	# R344：整块面板是浅底（羊皮纸），文字一律**不描边** —— 描边色是深色，
	# 描在小字号笔画外面等于给每个字套一圈灰边，13px 的说明读起来就是糊的。
	_draw_string_center(_font_bold, UiTheme.FS_SUBHEAD,
			"道具 %d 个 — 悬浮即可看说明，这里是放大版%s" % [n,
					"（滚轮翻动 · 点击任意处关闭）" if scroll_max > 0.0
					else "（点击任意处关闭）"],
			Vector2(WINDOW_W / 2, py + 30), UiTheme.INK_800, -1)
	if n == 0:
		_draw_string_center(_font, UiTheme.FS_BODY, "本局还没有道具",
				Vector2(WINDOW_W / 2, py + 76), UiTheme.INK_500, -1)
		return
	var y := py + 56.0 - _relic_scroll
	for r in rows:
		var name_str: String = r[0]
		var tag_str: String = r[1]
		var dlines: PackedStringArray = r[2]
		var scol: Color = r[3]
		var ncol: Color = r[4]
		var row_h: float = RELIC_P_ROWH + dlines.size() * RELIC_P_LINE + 10.0
		# 只画面板内可见的行（滚出面板的内容自然被面板矩形盖不住 → 手动跳过）
		if y + row_h > py + 46.0 and y < py + ph - 8.0:
			draw_rect(Rect2(px + 16, y - 16, 10, row_h - 8.0), scol, true)
			_draw_string_nw(_font_bold, RELIC_P_NAME, name_str,
					Vector2(px + 36, y), ncol, -1)
			var nw: float = _font_bold.get_string_size(name_str,
					HORIZONTAL_ALIGNMENT_LEFT, -1, RELIC_P_NAME).x
			_draw_string_nw(_font_bold, RELIC_P_NAME, tag_str,
					Vector2(px + 36 + nw + 6.0, y), Color("4a3c14"), -1)
			for d_i in dlines.size():
				_draw_string_nw(_font, RELIC_P_DESC, dlines[d_i],
						Vector2(px + 36, y + RELIC_P_ROWH - 8.0 + d_i * RELIC_P_LINE),
						UiTheme.INK_600, -1)
		y += row_h


## 道具悬浮说明面板的排版常量（R107）：四周留白一致，每行基线取**行槽中心**，
## 于是文字块上下留白相等。原来「首行基线写死 y+22、面板高 = 24 + 18n」是贴顶的
## （上 ~6px / 下 ~17px），配合折行处行首多出的空格，看着就是「说明文字错位」。
const RELIC_TIP_W := 480.0
const RELIC_TIP_PAD := 12.0
const RELIC_TIP_SIZE := 13
const RELIC_TIP_LINE := 18.0


func _draw_relic_tip_panel() -> void:
	## 道具悬停说明：浮动折行面板（长描述如「叠加态的鸭」不溢出）。
	## 位置优先贴在道具栏上方；上方放不下就翻到下方。两个轴都夹进窗口内。
	if _hover_relic_tip == "":
		return
	var w := RELIC_TIP_W
	var inner := w - RELIC_TIP_PAD * 2.0
	var lines := CardFace.wrap_text(_font, _hover_relic_tip, inner, RELIC_TIP_SIZE)
	var h := RELIC_TIP_PAD * 2.0 + lines.size() * RELIC_TIP_LINE
	var z := _relic_zone_rect()
	var x: float = clampf(z.position.x + z.size.x - w, 8.0, WINDOW_W - w - 8.0)
	var y: float = z.position.y - h - 10.0
	if y < 8.0:
		y = clampf(z.position.y + z.size.y + 10.0, 8.0, WINDOW_H - h - 8.0)
	draw_rect(Rect2(x, y, w, h), Color(0.10, 0.11, 0.15, 0.95), true)
	draw_rect(Rect2(x, y, w, h), UiTheme.ACCENT_GOLD, false, 1.2)
	for li in lines.size():
		# 行槽 = [y+pad + li*line, +line]，基线取槽中心下方 0.36em（与 _draw_string_center 同约定）
		var by: float = y + RELIC_TIP_PAD + RELIC_TIP_LINE * (float(li) + 0.5) \
				+ RELIC_TIP_SIZE * 0.36
		draw_string(_font, Vector2(x + RELIC_TIP_PAD, by), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, inner, RELIC_TIP_SIZE, Color("f0ead8"))


func _draw_log_panel() -> void:
	## 对局记录面板：覆盖左侧信息栏区域，显示引擎日志尾部。
	var rect := Rect2(INFO_X, GRID_Y, INFO_W, GRID_H)
	draw_rect(rect, Color("2b2b2b"))
	draw_rect(rect, UiTheme.INK_300, false, 1.0)
	_draw_string_nw(_font_bold, UiTheme.FS_CAPTION, "对局记录（L 关闭）",
			Vector2(INFO_X + 10, GRID_Y + 18), Color("f0f0f0"))
	var lines := engine.log
	var show := mini(lines.size(), 21)
	var y := GRID_Y + 40.0
	for i in range(lines.size() - show, lines.size()):
		var t := str(lines[i])
		if t.length() > 28:
			t = t.substr(0, 28) + "…"
		_draw_string_nw(_font, UiTheme.FS_MICRO, t, Vector2(INFO_X + 8, y), Color("d8d8d8"))
		y += 17.0


# ------------------------------------------------------------ 每帧刷新工具栏文字

func _process(delta: float) -> void:
	# R281：卡名超宽时是**横向滚动**的 —— 需要连续重绘才会动。
	# 自持循环：`_draw_name_marquee()` 记时刻 → 这里看到 → 请求下一帧 → 继续画。
	if CardFace.scrolling_recent():
		queue_redraw()
	if _demo_tip_text != "":
		_hover_relic_tip = _demo_tip_text   # 演示：合成鼠标移动会清提示 → 每帧重设
	if _demo_hover_idx >= 0 and engine != null \
			and _demo_hover_idx < engine.state.hand.size():
		_hover_hand = _demo_hover_idx          # 演示：左栏信息面板常驻显示这张卡
		_hover_card = engine.state.hand[_demo_hover_idx]
		_hover_pl = null
	if engine == null:
		return
	# R186：触屏长按到时 → 右键等价（放弃取牌 / 取消专注 / 取消选中）。
	# 同时摘掉待结算的左键按下 —— 否则松手时模拟鼠标会补发一发左键点击。
	_sync_pick()
	# 演示：选卡页一展开就补一次预选（一次性；出图能看到「选中金框 + 描述条」）。
	if _demo_pick_sel >= 0 and _pick != null and _pick.visible and _pick.is_picking():
		_pick._toggle(_demo_pick_sel)
		_demo_pick_sel = -1
	if _lp_active and not _lp_fired and _drag_idx < 0 and not _grid_dragging \
			and (_pick == null or not _pick.visible) and _now() - _lp_t0 >= LP_MS:
		_lp_fired = true
		_lp_active = false
		_press_idx = -1
		_grid_drag_arm = false
		_on_right_click()
		queue_redraw()
	if _shot_pending:
		_demo_tick()
	if _net_mode:
		_net_poll(delta)
	_grid_intro_tick(delta)         # R136/R146：开场巡场（自己半场 → 对方半场放大 → 拖回我方）
	# R215：开场弹窗**不点也会关** —— 5 秒到点自动收起（倒计时由这里逐帧推进重绘）。
	if _ee_popup:
		if ee_popup_expired():
			_ee_popup = false
		queue_redraw()
	# R77：鸭语耳环逐张出牌 —— 放在 _tick_anims 之前，优先把「下一张」推出去，
	# 这样同一帧里刚出的牌动画能立刻开始播。
	var earring_busy := _tick_earring_autoplay()
	var anim_busy := _tick_anims()
	if _tick_cues(delta):
		queue_redraw()   # R288：通用演出 / 镜头补间进行中
	_hand_sync()          # R151 P0-1/2：手牌差异 → 抽牌飞入 / 弃牌·消耗飞出
	_energy_tick()        # R151 P0-3：能量变化量飘字
	# R151 P1-6/7：回合归属 —— 敌方回合手牌下沉 +6 / 暗罩 0.22；我方回合上浮 −3 / 无罩（~150ms 缓动）
	var turn_foe: bool = engine.current_side != GameEngine.SIDE_SELF and not engine.over
	_hand_turn_dy = lerpf(_hand_turn_dy, 6.0 if turn_foe else -3.0, minf(1.0, delta * 8.0))
	_turn_dim = lerpf(_turn_dim, 0.22 if turn_foe else 0.0, minf(1.0, delta * 8.0))
	if not _hand_fly.is_empty():
		var n3 := _now()
		_hand_fly = _hand_fly.filter(func(f): return n3 - int(f.start) < int(f.dur))
		if not _hand_fly.is_empty():
			queue_redraw()  # 手牌飞行动画播放中
	if UiRoll.rolling("energy") or UiRoll.rolling("hp_self") or UiRoll.rolling("hp_opp") \
			or UiRoll.rolling("opp_energy") or UiRoll.rolling("hp_self_bar") \
			or UiRoll.rolling("hp_opp_bar"):
		queue_redraw()      # P0-3：数字滚动中
	if anim_busy:
		queue_redraw()  # 动画播放中逐帧重绘
	if earring_busy:
		queue_redraw()
	# R180：脉冲动画统一**节流重绘**（_pulse_redraw 每 PULSE_FRAME_MS 才真正 queue_redraw）。
	# 原来这 9 个 _board_has_* 每个都逐帧 queue_redraw，且 _board_has_actable()（己方回合恒真）
	# 单独就能让整个场景每帧全量 _draw —— 安卓 GL Compatibility 上这是「越打越卡」的主因。
	if _board_has_taunt() or _board_has_frozen() or _board_has_sleep() \
			or _board_has_fuse() or _board_has_shield() or _board_has_activatable() \
			or _board_has_actable() or _cancel_armed \
			or (engine != null and _board_has_pulsing_field()) \
			or _relic_bar_lit():          # R314：道具栏有亮着的徽章 → 呼吸要连续重绘
		_pulse_redraw()
	if not _confetti.is_empty():
		if _tick_confetti(delta):
			queue_redraw()
		else:
			_confetti.clear()
			queue_redraw()
	if not _banner.is_empty():
		if _now() - int(_banner.start) < int(_banner.dur):
			queue_redraw()
		else:
			_banner = {}
	# 结算面板：等所有攻击/命中/击破/飘字等动画特效播完后再弹出。
	if engine.over and not _over_shown and not anim_busy:
		_show_over(engine.result == "胜利")
	# 地图总览的「下一步可走」绿环 / 棋盘双箭头呼吸脉动 → 同走脉冲节流（R180）。
	if _map_visible or _grid_scrollable():
		_pulse_redraw()
	if not _tutorial_finished:
		_tut_poll()
	if _net_mode:
		if engine.over:
			turn_label.text = "对局结束"
		elif engine.current_side == GameEngine.SIDE_SELF:
			turn_label.text = "我方回合 · 第 %d 回合" % engine.turn_number
		else:
			turn_label.text = "%s 行动中" % NetSession.opp_name
	elif engine.current_side == GameEngine.SIDE_SELF and not engine.over:
		turn_label.text = "我方回合 · 第 %d 回合" % engine.turn_number
	elif engine.over:
		turn_label.text = "对局结束"
	else:
		turn_label.text = "对手回合"
	# R155/R156：顶栏血量条改自绘（图标 + 滚动数字），这里只触发重绘 + 维护按钮禁用态
	hp_strip.queue_redraw()
	# R207：顶栏「卡组」看的是**完整卡组** → 本场牌堆抽空也不该变灰（整副牌还在）
	var has_any_deck := RunState.run_active and not RunState.deck_ids.is_empty()
	if not has_any_deck and engine != null and not engine.state.deck.is_empty():
		has_any_deck = true
	deck_btn.disabled = not has_any_deck and not _run_deck_visible
	map_btn.disabled = not _mapview_available()
	status_label.text = status_text
