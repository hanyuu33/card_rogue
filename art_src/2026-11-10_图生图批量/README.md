# 图生图批量产出（R552 后续阶段）

> 2026-11-10 · 用 R552 立好的 14 桶风格参考图，走 ImageGen 图生图批量产出全卡池缺图卡。
> 目标覆盖 306 张。参考图只借「风格」，不借「内容」。

## 桶 → 参考图映射（14 桶）

| 桶 | 参考图 id | 参考图说明 | 位置 |
|---|---|---|---|
| 森林陆兽 | 9038 | 老虎（橙黑条纹） | assets/pics/9038.png |
| 鸟类 | 9039 | 乌鸦（蓝紫光泽边） | assets/pics/9039.png |
| 树人/植物 | 8003 | 树人（树皮块面平涂） | assets/pics/8003.png |
| 机械构装体 | 8025 | 素体（钢灰+冷青缝线） | assets/pics/8025.png |
| 暗影人形 | 9204 | 赏金猎人（兜帽斗篷） | assets/pics/9204.png |
| 暗影生物 | 8006 | 影子猫（影子本体） | assets/pics/8006.png |
| 亡灵/骷髅 | 1053 | 骷髅兵（冷绿鬼火眼） | assets/pics/1053.png |
| 龙 | 1013 | 灰烬龙（橙烬裂纹） | assets/pics/1013.png |
| 建筑/塔 | 9019 | 箭塔（木制瞭望塔） | assets/pics/9019.png |
| 元素/魔像 | 9236 / 9068 | 火元素 / 水元素 | assets/pics/9236.png / 9068.png |
| 人形角色 | 9132 | 俄倪厄 | assets/pics/9132.png |
| 技能特效 | 9004 | 击退 | assets/pics/9004.png |
| 鸭子 | 9001 | 鸭子骑士 | assets/pics/9001.png |
| 道具/物品 | 9179 | 惊奇盒子 | assets/pics/9179.png |

## 图生图固定纪律（每次必守）

1. `input_fidelity=low`（绝不用 high/medium，会锁死内容）。
2. 首句固定：
   `Use the reference image ONLY AS AN ART-STYLE REFERENCE: copy its drawing technique
   (cel shading, clean black line art, 2-3 flat tone steps, dark blurred background + bright subject).
   Do NOT copy its character, its scene, its pose, its composition, its props, its colour scheme.
   Paint a COMPLETELY DIFFERENT subject.`
3. 每张卡 prompt 完整写自己的设定（角色/背景/姿势/道具/配色），不能只写「风格+一个名词」。
4. 验收：放大到 ≥500px 确认赛璐璐（描边清晰/平涂/暗底亮主体）+ 内容是目标卡自己的设定。
5. 技能/效果类抽象卡沿用「只画物不画人」惯例（参照 R537 拳脚三张）。

## ⚠️ 主体来源纪律 + 禁用卡牌元素（R560 店长追加）

**规范 A（主体不许凭空捏造）：** 非「盟友」「工事」的卡（技能/效果/场地），**不得凭空捏造一个人形/生物主体**（兜帽人、黑影人、骷髅死神、奔跑剪影等一律禁止）。主体只能来自三类既有素材：
1. 已有 CG 角色（如 `class_cg_rogue.png` 暗影刺客少女、`class_cg_forest.png` 森林精灵）；
2. 已有盟友卡图（如 9232 厄运的使者、9233 灵魂收割者）；
3. 已有工事/道具卡图。
若该卡本质是抽象效果（暗杀、标记、气浪、符文、斩击），就**只画抽象物**（匕首、符文法阵、能量气浪、刀光），不要硬塞角色。

**规范 B（禁用卡牌元素）：** 卡图里**不得随便放进「卡牌」**。只有该卡效果本身是「抽牌 / 卡牌」相关时，卡牌元素才允许出现。

**补充（构图）：** 构图**不要求完整角色**，根据情况适当聚焦（比如突袭只需匕首+敌人惊慌的脸部/手部特写，不必全身）。

**典型违规 → 改法：**
- 「技能卡画了个兜帽人摆姿势」→ 去掉人，只画抽象物（匕首/符文/气浪）；或改用已有 CG 角色做特写动作。
- 「技能卡飞着几张牌」且效果非抽牌 → 去掉卡牌元素。

## ⚠️ 借角色形象时的「动作/姿势」纪律（R559 店长追加，最重要）

图生图借「具体角色形象」时（image1=已有卡图/CG，input_fidelity=medium），**参考图的动作/姿势/手势会被一起学走**，即使 prompt 里写了新动作也压不住（9065 自愈保留「手托光球」、9064 和风守护几乎原样保留「一手前伸飞扑」）。

**铁律：借角色时，prompt 必须同时明确写三样——角色、动作/姿势、背景/场景，并且显式否定参考图的旧动作。**

正确写法模板：
```
Keep this reference character's design exactly: <角色外观要素>.
Now depict a NEW POSE and NEW ACTION, do NOT keep the reference image's pose or hand gesture:
<新动作 + 新姿势 + 新背景 + 新道具，逐项写清>.
```
- 关键句：`do NOT keep the reference image's pose or hand gesture`（显式否定旧动作）。
- 动作要用动词写具体（如「双手结印施放气流」「盘腿静坐疗伤」），不能只写「施法/守护」这类抽象词，否则模型会回到参考图姿势。
- 若写具体动作后仍学走参考图姿势，改用 codex 纯文生图（不喂参考图），用文字把角色外观要素写全即可。

**借画风（低保真）与借角色（中保真）的区别：**
- 借画风：`input_fidelity=low`，首句「只借风格不借内容」，参考图只提供描边/平涂/暗底亮主体的技法。
- 借角色：`input_fidelity=medium`，首句「Keep this reference character's design exactly」锁定外观，但**必须追加否定旧姿势 + 写全新动作**。

## ⚠️ 手部特写、动作冲突、动线符号、局部改图（R561 沉淀）

**① 手部 / 特写为主体 → 解剖结构必须在 prompt 里写死。**
现象：手部特写最容易出 AI 硬伤——9110 活力转移两只手全画成右手（左掌朝观者时拇指跑到外侧）、9119 起手式拇指反折 + 四指僵硬如爪。手部是主体，瑕疵最显眼。
铁律：显式写 `one LEFT hand and one RIGHT hand, anatomically distinct and CORRECT` / `four fingers wrap naturally around the grip, thumb lies along the near side` / `every finger and thumb fully visible` / `NO mirrored duplicate hands, NO six fingers, NO bent-back thumb, NO stiff clawed fingers`。
效果：写死后各返工一轮即合格；不写则反复翻车。

**② 参考图动作与新动作「方向冲突」→ 一开始就切 codex 纯文生图。**
现象：9173 身法要「后仰躲箭」，但借角色用的 image1=`8002_shadow` 自身是**前倾冲刺**，图生图 medium 连出三版都是弓步 / 奔跑 / 前倾，怎么加否定句都拽不回来。
铁律：当参考图自带动作与目标动作相反（前倾 vs 后仰、站姿 vs 卧姿），**别再调图生图**，直接 codex 纯文生图；形象一致性靠文字把外观要素写全即可（银白短发紫渐变 / 绯红瞳 / 深紫兜帽 / 黑紧身衣 / 银月牙项链），实测锁得住。
这是 R559「若写具体动作后仍学走姿势，改用 codex」的强化版：不是试过再改，而是方向冲突就别喂参考图。

**③ codex 纯文生图会把「动线」画成实打实的箭头符号。**
现象：身法 prompt 写了 `one clean curved motion line traces her backward dodge arc`，出图多了一条白色示意箭头，店长判「莫名其妙多了个箭头」。
铁律：凡是要动感的图，prompt 写死
`ABSOLUTELY NO arrows, NO arrow symbols, NO direction markers, NO motion-trail lines, NO speed lines, NO arc lines, NO graphic symbols of any kind`，让姿态本身表达动感。**不要给「动线 / 一条弧线提示」这类模糊词**。

**④ 只改「单个元素的方向 / 角度」→ 优先局部图像编辑，不重画。**
现象：身法水平横飞的箭「方向导致逻辑很差」，店长要求逆时针转 30°。
做法（PIL）：抠出箭条 → `rotate(-30)`（PIL 负角＝顺时针，右端箭头往下）→ 用箭区上下缘背景色做垂直渐变 + 高斯模糊抹掉原水平箭 → 贴回 → 扫描亮像素清掉孤立的旧断羽碎片。
铁律：局部旋转能保留已验收的角色、比重生成省；但**必须检查旧元素残留**（第一次直接贴回出现双箭重影）。方向逻辑：箭头朝右下的俯射角比水平横飞更合理。

## 流程

1. `ImageGen(image1=<桶参考图>, input_fidelity=low, prompt=<完整设定>)`
2. 出图后取 savedPath，`python tools/cardart_prep.py <图> <id>` 裁 448×403 进 `_pending`。
3. 放大验收 → 合格进 `_pending` 等店长点头，`cardart.py approve` 才转正。

## ⚠️ codex 图生图管线 + 两条新纪律（R562 沉淀）

**管线段（店长 2026-11-10 指定：图生图也委托 codex）**

| 环节 | 正确做法 | 坑 |
|---|---|---|
| 调用 | `codex exec --json --skip-git-repo-check -C <repo> -i <参考图> < <prompt.txt>` | ① 位置参数 + stdin 重定向会报 `No prompt provided via stdin`，prompt 必须走 stdin；② Python subprocess 不认 bash shim `~/bin/codex`，要直指 `~/.local/codex-cli/.../bin/codex.exe` |
| 代理 | `HTTP(S)_PROXY=http://127.0.0.1:7897`（Clash） | 继承环境的 `63248` 沙箱代理会 `HTTP CONNECT failed 502`；直连（无代理）直接超时 |
| 取图 | 图落 `~/.codex/generated_images/<thread_id>/exec-*.png`，从 JSONL 里正则取路径再复制 | codex 在 workspace-write 沙箱里 `copyFile` 会「拒绝访问」，它自己拷不出来，必须由脚本抄 |
| 后处理 | `python tools/cardart_prep.py <raw> <id>` → 448×403 → `_pending` | 同前 |

- 单张耗时 70~100s，20 张一批约 25 分钟；写进 `_run_batch.py` 一把跑完（循环关在脚本里，避免工具连击判定）。
- codex 的 GPT Image 输入**恒为高保真**（没有 `input_fidelity` 参数），所以「只借画风」不能再靠 low 参数，只能靠 prompt 首句把「不要抄角色/姿势/场景/构图/配色」逐项写死。

**纪律 E（新增）：参考图的「占幅/构图」会被一起学走 —— 全身卡必须写死 78% 高度 + 上下留白。**
现象：借 8073（紧贴画框的全身机甲）出 4 张全身卡，1254 方图里头顶到 y≈2%、靴底到 y≈99%，
而 448×403 裁窗固定要切掉上下各 63px（5%），结果**头脚同时被削**，改裁窗也没用（比例固定、余量不够）。
铁律：全身体主体（盟友/敌人/角色）一律在 prompt 写
`Scale the figure to about 78% of the frame height, centre it, at least 8% empty background at the TOP and at the BOTTOM edge; the top of the head and both feet must be FULLY visible and NOT cropped; do NOT fill the frame edge-to-edge like the reference image, pull the camera back.`
返工只重出图、不动裁切。半身/特写/场景卡不受此限。

**纪律 F（新增）：验收必须看「成品 448×403」，不能只看 raw。**
raw 1254 方图看着完美，裁成 448×403 后可能削头削脚、主体偏移、留白过多。
流程固定为：出图 → 裁切 → **拼 448 卡面总览逐格看** → 有问题回退重出图。

**纪律 G（新增）：prompt 守不住留白时，用「画布延展」兜底，不要改裁窗。**
R562 返工第二批里，9167/8032 的 v2 已写死「76% 高度 + 上下 8% 留白 + 所有部件在框内」，GPT Image 仍给出约 90% 占幅（8025 参考图的紧贴画框构图再次被学走），裁窗削掉右上肩甲与天线杆尖端。
兜底做法见 `art_src/2026-11-10_机械之心放量_R562/_pad_v3.py`：成图等比缩到 84% → 居中贴回 1254 方图 → 底图用同图 GaussianBlur(30) 并压暗 0.8 → 边缘 24px 羽化 → 再走标准 `cardart_prep.py`。
优点：确定性 100%，画风一笔不改，内容不用重抽（避免重出图把已经合格的主题又画歪）；暗蓝灰背景羽化后只像自然暗角。**纪律 E 的「不动裁切」依然成立**——改的是 raw 画布，不是 448×403 裁窗。
适用：内容验收合格、仅四周贴边。若主体本身画错，仍必须重出图。

**纪律 H（新增）：卡面语义要过一遍「物理合理性」。**
8032 的锅不在画风，而在把「侦察」直译成「雷达发射扫描光锥」——雷达是被动接收件，且卡片效果是被动校射加成。以后写 prompt 前先读 `cards.json` 的 `effect_text`，确认发光/动作符合机制：机械之心的青光一律来自能量缝线与传感器，天线、碟、炮口这类机械件默认不自发光。

## R563 口径变更：原「暂不做」15 张也全部出图（店长 2026-11-11）

店长指令「补上，并且之前标记不做的你也做了」→ 真实缺图 12 张 + `art_plan.json.skip` 15 张一次性补齐，共 27 张。
**台账必须同步**：给 skip 里的卡出图后，若不清空 skip，`_art_index.py --check` 的体检③会报
「把 id=X 标成暂不做，但它已经有图了」。所以 R563 把 `skip` 清空、`updated` 与 `note` 一并更新，
`--md` 重写索引；图先停在 `_pending`，approve 转正后才计入「已完成」。

原 15 张里 13 张是「敌方效果卡：规则载体，不占格子、不出卡面」「启示者阶段被动」「衍生召唤物」。
这些图**只作全卡池图鉴/备用，不改变引擎行为**（战斗界面仍只画特效，不画卡面）。
出图方向一律按规范 A 画成物件／特效，不塞人形；鸭子系走 9001 桶、机械系走 8025 桶、启示者体系对齐 9200 深蓝灰＋青＋紫白。

**新增的一条实操经验：成对卡要共用一套造型。**
9157「罐子（诅咒）」与 9158「罐子（工事）」是同一只陶罐的两种状态，
prompt 里必须把「squat round clay jar / cracked pale glaze / blank talisman / crimson-violet leak」逐项写一致，
只改尺寸、铁箍、底座和是否渗漏；否则模型会画成两只完全不同的罐子。

## R563 返工第三批沉淀的三条新经验（2026-11-11）

**纪律 I：借「同卡旧作」保画风时，必须逐项写死要被替换掉的形态。**
9014 远古虚骨龙是本管线第一次用「当前正式图」当参考图（要保留它的赛璐璐描边、暗云＋橙雷配色、亡灵骨色）。
GPT Image 高保真输入会把旧图形态一起学走：旧图是有翼、有角、正面平视、居中站定的幻想骨龙。
prompt 首段因此逐项写明「DO NOT keep its bat wings / horned fantasy-dragon head / four sturdy legs / armoured plates /
front-facing flat standing pose / centred symmetrical composition / scale」，并把真实 *Coelurus fragilis* 的解剖
（小长头、细长中空颈椎、三指弯爪、修长后肢、超长尾、无翼无角、二足）写进 SUBJECT；
构图另写「extreme low-angle worm's-eye view + lunging down + open mouth toward camera + foreshortened near claw」。
结果一次通过：仰视张口、前爪透视放大、长尾甩向左上，压迫感成立，不再是标本式平视。
**结论：同卡重绘的 prompt 里，「保留什么」和「必须换掉什么」要写成两张等量清单，只写前者必翻车。**

**纪律 J：「试着生成一版」＝候选，不能自动覆盖 `_pending`。**
9149 疲惫店长只说「也可以试着生成一版」，而驱动脚本按惯例把 v2 直接裁进了 `_pending/9149.png`，覆盖了已验收的铅锤版。
补救：把 v2 另存 `候选_9149_疲惫_篝火版.png`，用 v1 重新裁回 `_pending/9149.png`，再出两版对比页交店长选。
以后凡措辞是「试着／也可以／先出一版看看」的，一律 `suffix=_v2` 出图后**不覆盖**，另存候选目录 + 对比页。

**纪律 K：角色卡可以借职业 CG，但要换姿势＋换背景＋写死占幅。**
R563 三张借 `class_cg_forest` / `class_cg_mech` 都成功（9168 祈祷、9149 篝火打瞌睡、9242 黑化技师），
关键是 HEAD 段写「keep face / hair / ears / outfit EXACTLY，repaint in cel shading」，
紧接一段「NEW POSE AND NEW ACTION — do NOT keep the reference's standing pose or bright daylight / glass lab background」，
再写暗夜林／暗化工坊背景与半身或 76% 全身占幅。CG 是明亮厚涂横图，不写死这三项就会被带成白天厚涂。

**台账口径补充：「已弃用」与「暂不做」不是一回事。**
9158 罐子(工事) 店长确认旧召唤物机制已弃用 → 卡图、prompt、出图任务全删，`art_plan.json.skip` 写「已弃用，永久不出图」；
玩法数据（cards.json 条目、引擎常量、312 张图鉴断言）不动，留独立轮次清理。
`skip` 的语义因此有两种：方向未定暂缓（可恢复）／卡片弃用永不出图（不可恢复），理由文本必须写清是哪一种。

## R563 返工第四批沉淀（2026-11-11）

**纪律 L：状态/诅咒「标记」卡是一类独立画法，不能沿用物件卡的画法。**
店长要的是「交通标识那种抽象的标志，不过带颜色」——即**符号**，不是**东西**。
规范 A 只说了「抽象技能卡只画物、不塞人形」，容易顺手把「标记」也画成带铆钉、切面、飞散碎片的立体实物。
标记卡的固定配方：① 纯平色底（不模糊、不渐变、无场景）；② 统一外框（圆盘／三角路牌＋粗黑外环＋细白内环）；
③ 中央唯一一个大号几何符号，3~4 个平色，粗均匀黑描边；④ 禁止 3D/透视/倒角/金属高光/渐变/投影/铆钉/碎片/火花/粒子；
⑤ 成对的状态标记必须共用同一外框，只换符号与颜色（9154 冷青碎盾 / 9185 明黄电弧），才能一眼看出是同一套图标系统。
**若参考图本身是立体插画（如 9179 惊喜盒），就不要挂**：GPT Image 是高保真输入，实物感会被一起学走。
为此给 R562 的 `run_one` 补了 `ref=None` 分支（纯文字出图，命令不带 `-i`），向后兼容。

**纪律 M：借职业 CG 时，「体型/头身比」必须单独写死，不能只写脸和服装。**
9168 许愿 v2 写全了发色、兽耳、叶裙、白雏菊，却写了句 `Normal anime head-to-body proportion, NOT chibi`，
模型立刻把 CG 里 1:4 头身的小女孩画成成年少女。角色卡的 prompt 要分三段：
① keep face/hair/ears/outfit EXACTLY；② **CRITICAL — BODY PROPORTIONS**（头身比、头宽与肩宽关系、眼睛位置、四肢长度，
并列出「不许拉长/收窄/加宽/成熟化」的必禁清单）；③ NEW POSE / NEW BACKGROUND / 占幅。
「NOT chibi」不等于「正常比例」，以后禁止用这种含糊措辞代替具体头身比。

**纪律 G 补充判据（9242）：成品卡面头顶余量 < 5% 就视为「易削头」，直接走画布延展。**
不用等真的被裁：448×403 裁窗固定切上下各 63px（raw 1254 方图的 5%），头顶只剩约 10px 余量时，
任何后续缩放/再裁/换卡框都会削头。R563 的 9242 属此类，按 G 缩到 84% 居中即可，不重抽图。

**纪律 N（流程，店长 2026-11-11 指定）：批量任务增量交付，出一张就处理一张。**
「拿到图就可以开始处理并把对比发给我，没必要每次都等全部跑完」。
批量出图时，后台继续跑，前端每落盘一张就裁切＋拼进对比页随手发给店长；不要攒到整批跑完才验收。
好处是前几张就能发现方向跑偏，避免整批返工。实现上验收脚本要按「已存在的 raw」动态拼页，不要求全批齐全；
驱动脚本每完成一张写一行进度日志。同理，已定稿的指令**先丢后台再边跑边想**（店长 01:20 已纠正过一次）。

**纪律 J 补充（R563 店长 01:41）：候选＝默认不自动覆盖，不等于永远不换。**
「试着生成一版」出的候选，要出并列对比页交店长选；店长一旦说「怎么没换」／点名某版，
立即把那版转正到 `_pending`，旧版另存候选保留回退，并刷新所有含该卡的当前交付页（尤其全批次总览）——
不要只留一页对比，却让总览继续显示旧版，否则店长会以为根本没做。
