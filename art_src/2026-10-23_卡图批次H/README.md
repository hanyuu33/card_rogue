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
| 8069 | 共享护盾 | ⏸ 本轮未给方向，**仍在待做**（不是 skip） |
| 8038 | 无限装甲 | ⏸ 同上 |
| 8057 | 榴弹击手 | ⏸ 同上 |

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

## 处理链

1. 切底部 11% 水印（`h * 0.89`）
2. cover 到 1.1117（`448 / 403`）
3. LANCZOS 缩到 `448×403`
4. `--headless --path . --import`

## 验收

- 六张缩到 448×403 后主体完整、水印干净（对照图 `art_src/_review/_r335_batchH.png`）
- 图鉴详情 `gallery.tscn -- --screenshot --card <id>` 三张抽查正常
- `_art_index.py --check` → 体检通过（190 待做 / 21 暂不做 / 50 已完成）
