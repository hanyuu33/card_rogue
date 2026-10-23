# 卡图批次 H —— R335（跨职业 6 张）

## 抽卡方式

`cards.json` 过滤 `group == player` + 无图 + 不在 `art_plan.json.skip`，三职业**分层随机各 3 张**，
固定种子 `random.Random(2026102315)` 可复现。本次抽到 9 张，用户只给了 6 张方向。

| 抽到 | 卡名 | 本次处理 |
|---|---|---|
| 9070 | 群起攻之 | ✅ 已出图 |
| 9055 | 狂暴 | ✅ 已出图 |
| 9148 | 新生 | ✅ 已出图 |
| 9160 | 弹跳飞刀 | ✅ 已出图 |
| 9096 | 回旋斩 | ✅ 已出图 |
| 9097 | 预判 | ✅ 已出图 |
| 8069 | 共享护盾 | ✅ 已出图（R336 补） |
| 8038 | 无限装甲 | ✅ 已出图（R336 补） |
| 8057 | 榴弹击手 | ✅ 已出图（R336 补） |

## 用户方向原文

- 群起攻之：多个动物（从卡图中找）朝同一方向（可以直接用堆叠图层的风格）
- 狂暴：以熊为主体
- 新生：土里发芽（一根芽）
- 弹跳飞刀：飞刀和飞刀的轨迹特效为主体，注重飞到弹跳的特效绘制
- 回旋斩：暗影刺客角色进行一周 360 度的斩击
- 预判：暗影刺客闪躲敌人的攻击，注意绘制残影

## 逐张落地

### 9070 群起攻之 —— `image1 = assets/pics/8004.png`（锁棕熊）

分层清单直接写进提示词，一层一句，让模型按「图层」堆而不是散放：

```
• FRONT LAYER (closest, fully rendered, sharpest): the grizzly charging on all fours
• SECOND LAYER (slightly darker, softer): a lean white wolf with cold blue eyes
• THIRD LAYER: a red-orange fox at full stretch, brush tail streaming back
• FOURTH LAYER: a wild hare mid-bound, ears swept back
• FIFTH LAYER (far, darkest, just shape): a horned stag and a dark crow in flight
```

关键补充：`all of them running in EXACTLY THE SAME DIRECTION`（同一朝向）+ 一句
`one warm low golden backlight ... rimming every layer's leading edge`（逆光把层切开）。
不写逆光的话，多层叠在一起会糊成一团深色。

### 9055 狂暴 —— `image1 = assets/pics/8004.png`（锁棕熊）

⚠️ **参考图里有森林精魄少女**，必须正面说明「NEW SCENE, alone」+ 反面 `NO elf girl`，
否则她会一起被带进来。另补 `NO cute expression`（这只熊原本画得很温顺）。
狂暴的视觉证据：人立而起 / 张口咆哮露舌 / 眼睛从深色变琥珀金 / 筋肉绷紧 /
落叶碎土旋涡 / 脚下泥土裂开渗熔金光。

### 9148 新生

「一根芽」是这张的全部难点。只写 `a sprout` 模型会给你一片苗圃，所以正反各写一遍：

```
ONE SINGLE young sprout ... Only ONE sprout in the whole image — exactly one
...
NO other plants in focus, NO flowers, NO mushrooms, NO animals
```

### 9160 弹跳飞刀

主体是「刀 + 轨迹」，所以要**先排除人**：`NO hand holding it, NO character, NO body parts`。
弹跳特效拆成可画的东西：三次急转折线 + 每个转折点的星芒/环形冲击波/溅射火花 + 转折处飞刀残影。
只写「弹跳轨迹」会得到一根弯线，看不出撞过东西。

### 9096 回旋斩 —— `image1 = assets/pics/9086.png`（暗影刺客正典）

⚠️ 与已定稿的 **9087 连刺**（紫白直线 + 同角度虚影）避让：形状从「线」改「闭合圆环」，
主光从紫白改**冷青**。提示词里写明 `a COMPLETE CLOSED CIRCULAR ARC`、
`the arc brightest and thickest at the leading edge`（有粗细变化才像挥出来的）、
`the ground scored in a circle`（地面刮痕坐实「转了一整圈」）。

### 9097 预判 —— `image1 = assets/pics/9086.png`（暗影刺客正典）

时间点必须选对：不是「被击中」，是「攻击到达前就已经挪开」。所以写
`she has already read it coming — this is the moment of PREDICTION, not the moment of impact`，
并反面 `NO wound, NO blood`。
残影要素：三到四个紫白虚影、**姿态由早到晚递进**、排成对角线、越早越淡。
攻击弧用**橙红**（敌方色），与她的紫黑形成冷暖对立，一眼分得清谁打谁。

### 8069 共享护盾 —— `image1 = 8027.png` + `image2 = 8055.png`（双参照）

这是本项目第一次用**两张参照锁两个主体**。生成器支持 `image1 / image2 / image3`，
所以「两个既有主体同框」不需要二选一、也不需要后期拼。

- `image1` = 8027 升级：机械之心角色的正典（黑长直 + 圆框眼镜 + 米色开衫）
- `image2` = 8055 钢铁卫士：履带底盘 + 暗钢装甲 + 黄铜发射环 + 蓝白六边形盾

提示词用 `CHARACTER A (from input image 1)` / `CHARACTER B (from input image 2)` 分段点名，
比只写「the same woman and the same robot」稳得多。

构图要点：卫士在**前景**背侧（占画面主体），角色在**后方**偏小——角色缩小是刻意的，
这张卡讲的是「盾挡住了」，不是「她长什么样」；如果两个人平均分画面，缩到 448×403 会两张脸都读不清。
再加一条 `NO extra characters`，否则工作坊场景很容易多出几个工人。

### 8038 无限装甲

「厚实」不等于「好看」，所以把「厚」翻译成**可数的层**：附加装甲板一层压一层、
新旧钢板与焊疤混排、侧裙挂备用板。这样「越改造越厚」的机制语义就落在画面上了。
另外刻意做成**没有上半身**的纯战车（双炮塔 + 履带），与 8055 钢铁卫士（履带 + 人形上身）
区分开，避免又一台「履带机器人」。

### 8057 榴弹击手

「右臂是炮管」的关键是**让左右不对称到一眼可读**：右臂从肩关节以下整条消失换成粗炮，
左手留正常三指机械手作为参照；站姿因右臂重量向左倾。炮管细节给三样：
旋转弹巢 / 叠层弹鼓 / 枪口内壁的装填余温（橙色）。

## 处理链

1. 切底部 11% 水印（`h * 0.89`）
2. cover 到 1.1117（`448 / 403`）
3. LANCZOS 缩到 `448×403`
4. `--headless --path . --import`

## 验收

- 六张缩到 448×403 后主体完整、水印干净（对照图 `art_src/_review/_r335_batchH.png`）
- 图鉴详情 `gallery.tscn -- --screenshot --card <id>` 三张抽查正常
- `_art_index.py --check` → 体检通过（190 待做 / 21 暂不做 / 50 已完成）
