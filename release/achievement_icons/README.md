# Steam 成就图标（9 条 · 铜 / 银 / 金）

Steamworks 后台「成就」页每条都要传**两张 64×64**：达成版 + 未达成版。这里就是那两张。

## 设计口径：一套徽章，不是九张插画

Steam 的成就列表是一整片图标并排显示，所以判断标准不是「每张好不好看」，而是
**九枚摆在一起像不像一套**。据此定了三条硬规矩：

| 规矩 | 做法 | 为什么 |
|---|---|---|
| 一枚只有一个金属色 | 全彩源图先转灰度，只留明暗结构，再「镀」上单一金属色阶 | 每张自带配色 → 并排就是九张彩色小画，拼不成一套 |
| 等级用材质表达 | 铜 / 银 / 金三档，色阶不同、形状完全一致 | 玩家扫一眼就知道哪条难，不必去读描述 |
| 未达成统一灰石 | 三档共用同一种暖中性灰 + 压暗 28% | 达成才「显色」，这是 Steam 的常规读法 |

外加两处几何归一化，解决「同一档却是九种大小」：

- **包围盒归一**：按主体实心区域的包围盒裁紧，再按面积缩放到统一占比（最长边兜底 74%）。
- **亮度归一**：把主体平均亮度用 gamma 拉到同一目标值（142），否则源图偏亮的会发白、偏暗的近黑。

## 等级划分

按**拿到它有多难**，不是按剧情顺序：

| 等级 | 成就 | 判定依据 |
|---|---|---|
| 🥉 铜 | `FIRST_STEP` `FIRST_BOSS` `LAYER2_CLEAR` | 进度型：开始一局 / 见到一层 Boss / 打通二层 —— 玩下去就有 |
| 🥈 银 | `FULL_CLEAR` `CLEAR_FOREST` `CLEAR_ROGUE` `CLEAR_MECH` | 通关型：任意职业打穿三层，或指定职业通关 |
| 🥇 金 | `CLEAR_HARD` `CLEAR_APEX` | 高难型：难度 ≥5 通关 / 难度 12 通关（12 档要凑齐三信物才开三层，商店还要贵 40%） |

改等级只需动 `tools/make_achievement_icons.py` 里 `ACHIEVEMENTS` 的第三列。

## 目录

```
release/achievement_icons/
├── 64/               ← 上传用（64×64 透明 PNG，18 个文件）
│   ├── FIRST_STEP.png          已达成（铜/银/金金属色）
│   ├── FIRST_STEP_locked.png   未达成（灰石压暗）
│   └── ...（其余 8 条同构）
├── 512/              ← 512×512 达成版，商店页 / 攻略站配图用，别传后台
├── src/              ← 1024 方图原图（按 <API>.png 命名，改版从这重跑）
├── preview.html      ← 一页看全 9×2（浏览器打开）
└── preview.png       ← 同上，单图版（发给人看用）
```

> `release/` 下有 `.gdignore`，Godot 不会把这里的图当游戏资源扫描 —— 之前这里的
> HTML 总表曾被当作资源打进 pck，白胖了 105MB（R741 修的）。

## 规格

| 项 | 值 |
|---|---|
| 上传尺寸 | **64 × 64**，PNG 带 alpha（后台校验尺寸，别的尺寸传不上去） |
| 张数 | 每条 2 张：`<API>.png`（achieved）+ `<API>_locked.png`（unachieved） |
| 形状 | 圆形金属牌：同色系深底 + 受光金属环 + 中心浮雕符号 |
| 环的光照 | 左上亮 → 右下暗（对角方向光；环是等半径的，径向光对它无效） |

## 怎么重出一批

1. AI 出图（1024×1024 方图，存 `src/<API>.png`）。提示词里固定这几句：
   - `thick bold black ink outlines, flat cel shading`
   - `centered single subject filling the frame, readable at 64x64`
   - **`solid` / `no large dark void, no see-through areas`** —— 这条最关键：
     主体中心大片暗的话，金属化后中间会空掉（`CLEAR_HARD` 第一版就废在这）
   - `No text, no letters, no numbers, no watermark, no border frame`
2. `python tools/make_achievement_icons.py`

流水线做的事（都写在脚本注释里）：裁边去水印 → 灰度 → 去细节（中值 + unsharp + 压 5 档色阶）
→ 抽背景成 alpha → 包围盒与亮度归一 → 金属着色 → 套圆牌骨架 → 64px 锐化 → 出预览。

> ⚠️ 不要直接把 1024 原图传给 Steam：既超尺寸，也带着「AI生成」水印。

## 上传步骤

1. Steamworks → App Admin → 成就（Achievements）→ 选中那条。
2. `Achieved` 图标传 `64/<API>.png`，`Unachieved` 传 `64/<API>_locked.png`。
3. 全部填好后**必须点「发布（Publish）」**，否则草稿态不生效、游戏里 `setAchievement` 也不会记录。

## 清单（API name ↔ 显示名 ↔ 等级）

| API | 显示名 | 等级 | 画面 |
|---|---|---|---|
| `FIRST_STEP` | 初次启程 | 🥉 铜 | 石板上的一枚鸭蹼印 |
| `FIRST_BOSS` | 直面恐惧 | 🥉 铜 | 铁门半开，门后带角的影子和两只红眼 |
| `LAYER2_CLEAR` | 深入腹地 | 🥉 铜 | 火把照着的螺旋石阶往下 |
| `FULL_CLEAR` | 完整通关 | 🥈 银 | 三重拱门透出白光，拱心挂一顶小金冠 |
| `CLEAR_FOREST` | 森林的加冕 | 🥈 银 | 树枝与鹿角编成的冠，中心一颗发光种子 |
| `CLEAR_ROGUE` | 影中的圆满 | 🥈 银 | 弯匕横在影子做的月牙前 |
| `CLEAR_MECH` | 机械的觉醒 | 🥈 银 | 齿轮与铜管拼成的心脏，核心发光 |
| `CLEAR_HARD` | 越难越勇 | 🥇 金 | 被熔岩裂缝劈开的实心盾（难度 ≥5） |
| `CLEAR_APEX` | 巅峰之上 | 🥇 金 | 裂开的铁锁板，白光从裂缝里炸出来（难度 12） |
