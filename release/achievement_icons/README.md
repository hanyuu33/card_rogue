# Steam 成就图标（9 条）

Steamworks 后台「成就」页每条都要传**两张 64×64**：达成版 + 未达成版。这里就是那两张。

## 目录

```
release/achievement_icons/
├── 64/               ← 上传用（64×64 PNG，18 个文件）
│   ├── FIRST_STEP.png          已达成（彩色）
│   ├── FIRST_STEP_locked.png   未达成（灰阶压暗）
│   └── ...（其余 8 条同构）
├── 512/              ← 512×512 彩色版，商店页 / 攻略站配图用，别传后台
├── src/              ← AI 出的 1024 方图（按 <API>.png 命名，改版从这重跑）
├── preview.html      ← 一页看全 9×2（浏览器打开）
└── preview.png       ← 同上，单图版（发给人看用）
```

## 规格与口径

| 项 | 值 |
|---|---|
| 上传尺寸 | **64 × 64**，PNG（后台校验尺寸，别的尺寸传不上去） |
| 张数 | 每条 2 张：`<API>.png`（achieved）+ `<API>_locked.png`（unachieved） |
| 画风 | 粗黑描边 + 单色系 + 一处发光，沿用 `assets/pics/` 卡图口径 |
| 未达成版 | 去色 + 压暗到 70%（不是纯剪影 —— 玩家仍能认出是什么，只是「灰掉了」） |

## 怎么重出一批

1. AI 出图（1024×1024 方图，存 `src/<API>.png`）。提示词模板里固定这四句：
   - `thick bold black ink outlines, flat cel shading with painterly texture`
   - `centered single subject filling the frame, readable at 64x64`
   - `Palette limited to <两三个颜色>`
   - `No text, no letters, no numbers, no watermark`
2. `python tools/make_achievement_icons.py` —— 四边各裁 72px（**顺手切掉右下角的 AI 水印**）、
   压 512 与 64、生成灰阶版、重出 `preview.png` / `preview.html`。

> ⚠️ 不要直接把 1024 原图传给 Steam：既超尺寸，也带着「AI生成」水印。

## 上传步骤

1. Steamworks → App Admin → 成就（Achievements）→ 选中那条。
2. `Achieved` 图标传 `64/<API>.png`，`Unachieved` 传 `64/<API>_locked.png`。
3. 全部填好后**必须点「发布（Publish）」**，否则草稿态不生效、游戏里 `setAchievement` 也不会记录。

## 清单（API name ↔ 显示名）

| API | 显示名 | 画面 |
|---|---|---|
| `FIRST_STEP` | 初次启程 | 石板上的一枚鸭蹼印 |
| `FIRST_BOSS` | 直面恐惧 | 铁门半开，门后带角的巨大影子和两只红眼 |
| `LAYER2_CLEAR` | 深入腹地 | 火把照着的螺旋石阶往下 |
| `FULL_CLEAR` | 完整通关 | 三重拱门透出白光，拱心挂一顶小金冠 |
| `CLEAR_FOREST` | 森林的加冕 | 树枝与鹿角编成的冠，中心一颗发光种子 |
| `CLEAR_ROGUE` | 影中的圆满 | 紫光弯匕横在影子做的月牙前 |
| `CLEAR_MECH` | 机械的觉醒 | 齿轮与铜管拼成的心脏，核心发青光 |
| `CLEAR_HARD` | 越难越勇 | 被熔岩裂缝劈开的铁盾 |
| `CLEAR_APEX` | 巅峰之上 | 裂开的铁锁板，白光从裂缝里炸出来（难度 11） |
