# 卡图批次 C · 森林精魄基础法术 ×6（R252）

| id | 卡名 | 费 | 字段 | 一句话画面 |
|---|---|---|---|---|
| 9003 | 火焰箭 | 2 | 火焰 | 掌心射出凝聚的火焰长矛（**无箭头无箭杆，纯戏法**） |
| 9004 | 击退 | 1 | 风 | 扇形气流把铠甲敌人推退，地面拖出两道擦痕 |
| 9005 | 智慧 | 1 | 奥术 | 精灵少女思考中：略仰头、右手食指竖放在嘴上，身后浮着蓝卡与法阵 |
| 9010 | 削弱 | 1 | 诅咒 | **鸭子队长**（9012 金甲鸭）垂头垮肩、剑尖杵地、紫咒缠身 |
| 9011 | 寒冰箭 | 2 | 冰霜 | 冰晶长矛贯穿，目标下半身封进冰壳 |
| 9042 | 撕咬 | 1 | — | **猎犬**（9040）獠牙外露低吼，背上升起红橙斗气 |

## 用户口径（R252 原话摘要）

- 火焰箭：**没有箭头，是完全的戏法**。
- 撕咬：以之前生成的**猎犬**为主体。
- 削弱：以**鸭子队长**的图为主体（被施术者）。
- 智慧：森林精魄角色做思考状态——**略微仰头，右手食指竖放在嘴上的思考动作**。
- 击退 / 寒冰箭：本批未指定，按上一版建议出图（可随时重做）。

## 六张的主色分配（防撞脸）

橙红（9003）/ 青白（9004）/ 青蓝（9005）/ 金紫（9010）/ 冰蓝（9011）/ 棕红（9042）。
六张的主色调互不重叠，缩到战场卡（77×92）也能靠色块分开。

## 角色一致性（R253 修正）

⚠️ **第一版画成了尖耳精灵 + 偏高的身材，不对。** 森林精魄角色的正典是 **Q 版（三到四头身）**：

- 大圆头、琥珀金色大眼睛、浅金长卷发垂过膝；
- **头顶一对黑猫耳 + 一条蓬松黑猫尾**，**没有尖耳 / 精灵耳**；
- 绿叶叠成的短裙 + 几朵小雏菊，耳侧别一朵白雏菊，赤脚；
- 参照物 = `8002_forest`（职业立绘）与 `9007`（火球术），三张新图要与这两张并排看不出破绽。

R253 的提示词固定写死下面几句，效果稳定：
`A tiny CHIBI anime forest spirit girl, only three to four heads tall, huge round head with big
amber-gold eyes, long wavy ash-blonde hair flowing past her knees, fluffy BLACK CAT EARS on top of
her head and a big fluffy BLACK CAT TAIL, NO elf ears, NO pointed ears, short dress made entirely of
overlapping green leaves with tiny white daisies, a white daisy beside one cat ear, barefoot`

**「不需要实体书页」**：9005 第一版画了两本摊开的书 + 书页，被否。现在只留两片半透明的蓝色
**发光卡形光片**（纯光，没有纸），提示词里显式写
`NO books, NO open books, NO paper pages, NO parchment, NO scrolls, NO physical props`。
- 鸭子队长 = 9012 那身：金黄色鸭、华丽金色板甲（胸口鸢尾花浮雕）、尖顶金盔、棕色皮带、橙蹼。
- 猎犬 = 9040 那只：棕色短毛、奶白胸斑、垂耳、肌肉厚实。

## 出图记录

- 一次过 5 张（9003 / 9004 / 9005 / 9011 / 9042）。
- 9010 **出了 2 张**：
  - 第 1 张（`A_big_plump_YELLOW_DUCK_standi_…`）：仰头张喙、紫电缠身，读起来像「被电到」，
    不像「力量被抽走」→ 弃用（已删除，未留档）。
  - 第 2 张（`A_big_plump_YELLOW_DUCK_knight_…`）：垂头、喙闭合、剑尖杵地、膝盖发软 → **采用**。
- 经验：**「虚弱 / 被削弱」要靠体态（垂头、垮肩、卸力）表达，不能靠表情（张嘴只会读成喊叫 / 震惊）。**

## R254 重画：9004 / 9005

用户口径：**「智慧卡图依旧不够还原，与其他图对齐」** + **「击退的图太奇怪了，去掉森林精魄角色，只展示敌人被气波击退的画面」**。

### 9005 智慧

R253 那版的问题（并排 9003 一眼可见）：发色偏**银灰**、耳朵画成**大灰狐耳**、身材偏高 → 和 9003 不是同一个人。

- 改法：**给参照图**（`image1 = assets/pics/9003.png`、`image2 = assets/pics/8002_forest.png`、`input_fidelity = high`），
  提示词开头写死 `Draw the EXACT SAME CHARACTER as the two reference images`，并在负向枚举
  `NO grey or silver hair, NO fox ears, NO elf ears, NO pointed ears`。
- 出了 2 张：第 1 张尾巴画成**两条**（黑尾左右各一条）→ 弃用；第 2 张只有右侧一条黑尾、食指明确竖在唇上 → 采用。
- 第 2 张额外写死 `EXACTLY ONE single big fluffy BLACK TAIL on her right side only, NO tail on her left side`
  与 `RIGHT index finger clearly extended straight and pressed vertically against her lips, the other three fingers curled into a loose fist`。

> **经验：角色还原靠「给参照图 + EXACT SAME CHARACTER」比堆文字描述稳得多；纯文字提示词一定会漂。**

### 9004 击退

- 原构图 = 精灵少女挥手 + 铠甲骑士被推退，双主体被否（「太奇怪」）。
- 现在 = **只留敌人**：铠甲骑士整个人被掀离地面、身体后仰、盾牌护脸、铠甲凹陷、地面碎石尘土爆开，
  白绿色气波从左下斜扫而来，长条速度线 + 落叶。
- 提示词写死：`ONLY the armored enemy and the shockwave ... NO spell caster, NO second character, NO girl,
  NO hands, NO mage silhouette, NO arm entering the frame`。

两张都是满屏背景（bbox = 全图，不裁），按老链处理：切底部 11% 水印 → 1.1117 cover → LANCZOS 448×403 → `--headless --import` → `_art_index.py --check`（通过）。

## R255 重画 9003 火焰箭：改成「投射物」

用户口径：**「火焰箭是投射物」**。

R252/R253 那版把火焰画成**从掌心向前延伸的长矛状火焰**（读成持续喷出的火柱 / 贴在手上的武器），不对。
现在改成：**已经射出去的一发火焰弹**——掌心前方约两米处有一团独立飞行的火焰弹，
**手掌与火焰之间有明显空隙**，弹体是带白热核心的水滴 / 彗星形，拖长尾、火星与速度线飞向画面右缘。

**同时保留 R252 的「完全没有箭头」口径**：弹体不画箭杆、不画箭头、不画箭羽，纯火焰。

提示词关键句：
`a compact elongated spear-shaped BOLT OF PURE FIRE is FLYING through the air about two meters in front of her hand,
as a distinct flying PROJECTILE with clearly visible empty air between her palm and the flame ... NOT a continuous beam,
NOT a flamethrower stream coming out of her palm, NO arrow shaft, NO arrowhead, NO feathers, NO bow`

> **经验：法系卡要区分「弹体已离手」（投射物）与「光柱 / 火焰自掌心延伸」（引导）——差别只在「手与弹之间有没有空隙」，必须在提示词里写死。**

## R256 重画 9004 击退：气波轨迹要读得出「推」

用户口径：**「气流的轨迹不对，要体现被击退」**。

R254 那版的问题：气波画成**绕着敌人转的一整圈漩涡**——读者只能看出「他在风里」，看不出「被谁往哪个方向推走」。

三次试错：

1. 螺旋管（r254 原版）→ 否，同上。
2. 正面气波盘：气波正对镜头成一个圆盘，敌人从盘里飞出来 → **像传送门**，方向反而更模糊。
3. 侧视气波墙（**采用**）：气波画成一块**立在画面左侧、只见厚度与前缘的竖弧墙**（像音爆的边缘），
   一束水平速度线从左贯到右，人被打飞、披风朝右拉直，地面上**一道被犁出的长土沟**从左边一路划到他身下。

**让「击退」可读的四件套**（以后画击退/撞飞类一律照这个）：
① 人物整体沿同一方向后仰、双脚离地、鞋跟拖后；② 披风/布料朝来向拉直；③ 地面犁痕/擦痕指向推飞方向；
④ 速度线单向贯通，**不要绕圈**。

提示词关键句：
`a TALL VERTICAL CRESCENT WALL OF COMPRESSED AIR standing at the LEFT of the frame, SEEN EDGE-ON ... NOT a disc,
NOT a portal, NOT a circle facing the camera` + `a long straight FURROW is plowed through the dirt floor ... below his flight path`

> **经验：单向动作的构图必须「拒绝一切闭环」——圆盘/环/漩涡一旦出现，方向感立刻被读成「被吸进去」而不是「被推出去」。**
改前/改后对照：`art_src/_review/_r256_knockback_before_after.png`

## R257 第三版 9004 击退：砍掉地面轨迹，改成「横着被打飞」

用户口径：**「依然很奇怪，尤其是地面的轨迹毫无道理」**——R256 那版在地面犁出了一道长土沟，
可人明明已经腾空，脚下根本没有东西在刮地，**这条沟纯属我自作主张加的假线索**（而且披风方向也画反了：
人朝右飞，布料应因惯性拖向**左**，即来向）。

这一版做的是减法：

| 项目 | R256 | R257 |
|---|---|---|
| 地面 | 一道犁地长沟 + 土块 | **只有原来站位处一小团被掀起的尘土 + 几块碎石，路面平整** |
| 气波 | 侧视竖弧墙占半幅 | 只剩**胸口一团紧凑的白光冲击爆点**，不画墙、不画盘 |
| 人物 | 45° 后仰、脚还在找地 | **几乎水平、完全腾空**（头朝右=飞向，靴子朝左=来向） |
| 披风 | 朝右（错） | **朝左拖**（朝来向，符合惯性） |
| 背景 | 满屏特效 | 右侧留大片空林做负空间，指示被打飞的方向 |

- 提示词负面清单写死：`NO furrow, NO trench, NO groove, NO ditch, NO track, NO skid marks, NO scrape line`，
  以及 `NOT a wall, NOT a disc, NOT a circle, NOT a ring, NOT a sphere, NOT a loop, NOT a spiral, NOT a vortex`。
- 出了 3 版（B/C 见对照图，均未采用）：B 盾牌在手但整体偏黑、受力点在腰；C 白天亮光但受力点偏低、盾牌像浮在空中。
- **采用 A**：胸口受力、披风朝左、腾空横飞。
- 对照图：`art_src/_review/_r257_knockback_versions.png`

> **经验：先问「这个痕迹在物理上是谁留下的」。人已腾空就不该有地面拖痕；站地滑退才配擦痕。
> 加线索必须过一遍物理检查，否则读者第一反应就是「毫无道理」。**

## 处理流程（同批次 A / B）

1. 白底图按非白像素 bbox 裁边 + 内缩 6px；**这六张都是满屏背景，bbox = 全图，等于不裁**。
2. 切底部 11% 去「AI生成 WORKBUDDY」水印。
3. 按 448×403（1.1117）cover 裁剪 → LANCZOS 缩到 448×403。
4. 落 `assets/pics/<id>.png` → `--headless --import` 生成 `.import`。
5. `python _art_index.py --check` 复核。

`raw/` 里的原始图已按 `<id>.png` 命名，重做时直接覆盖同名文件即可。
