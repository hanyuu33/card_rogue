# R842 · 龙石板事件素材（事件整屏背景 / 事件插图 / 道具 6090 图标）

三张图共用一套驱动 `_run_slab.py`（纯文生图，无参考图）：

```
python _run_slab.py [tag]     # tag = bg_dragon_slab / event_dragon_slab / relic_icon_6090
```

prompt 走 stdin 读 `prompts/<tag>.txt`，图落 `~/.codex/generated_images/<thread>/exec-*.png`，
**由脚本抄进 `raw/`**（不抄就随 thread 目录被清掉）。代理 `http://127.0.0.1:7897`，一张图一次会话。

## 出图提示词（原文，英文）

`prompts/bg_dragon_slab.txt`（**实际落地的是这一张**）：

```
A wide 16:9 background illustration for a fantasy card roguelike event screen, hand-drawn anime
fantasy style, thick clean dark outlines, flat cel shading with two or three tone steps, warm
saturated ochre, amber and dusty gold palette, soft painted background.

Scene: a dry ochre wasteland at low sun. ONE weathered stone slab stands tilted in the
mid-distance, a little taller than a person, top corner chipped off. Its face is carved with a
single coiled eastern dragon in shallow relief: the body spirals once around the centre of the
slab, the head resting near the upper third, worn scales and claws flattened by wind so only the
raised ridges catch the light. The dragon's eye socket still holds a small hollow of old gold
paint that glows faintly. Hairline cracks and pale lichen spread across the stone, a thin drift of
sand piled at its base, dry grass at the edges.

Composition: the slab sits in the upper right part of the frame, roughly one third of the frame
height, seen three-quarter from the front so the carved dragon still reads clearly at thumbnail
size. Low golden side light from the left, long soft shadow falling to the right. The entire lower
half of the frame is open empty dusty ground fading into warm haze, deliberately calm and almost
empty, with only faint sand ripples and drifting dust so interface text can be read over it. The
horizon sits high, around the upper third, with warm hazy sky and a few thin clouds above.

Hard constraints: exactly one slab, exactly one coiled dragon carved INTO the stone, exactly one
gold eye. The dragon is a relief on the stone, never a separate living creature.

NOT a sword, NOT a human statue, NOT a temple gate, NOT a flying dragon in the sky, NOT a dragon
emerging out of the stone, NOT gold coins, NOT neon magic runes covering the surface, NOT a
pedestal, NOT a busy foreground, NOT a crowd of objects, NOT text of any kind.

no text, no letters, no signature, no watermark, no frame, no border, no UI elements.
```

`prompts/event_dragon_slab.txt` 是同一主体的**方形居中版**（早期先出的一张），构图要求
「石板略偏右、三分之四视角、左上低角度金光」——留作备选，代码里被整屏背景压住不显示（见下）。

`prompts/relic_icon_6090.txt`：单件道具图标口径（一枚打磨得极亮的龙鳞，鳞面带龙眼纹样，
橙金配色、厚描边、纯白底居中）。

## 设计口径

**为什么最后要出整屏 `bg_` 而不是只留 `event_`**：`event_scene` 给 `event_<kind>.png` 的框是
`320×240`、贴在 `y 116..356`，而对话框从 `y≈351` 起 —— 那块图**下沿会被对话框切掉一大半**。
R802 定的规矩就是「有 `bg_<kind>` 就不叠 `event_<kind>`」，整屏图铺底才留得出正文与选项的位置。
所以这张背景的构图硬约束是**下半屏几乎留白**（只有沙纹与尘雾），石板压在上三分之一、偏右，
不与正中对话框（`x≈339..947 / y≈351..702`，1280×720 坐标）打架。

**石板上的龙必须是浮雕**，不能是一条从石头里钻出来的活龙 —— 这是这个事件的语义：
石板是一块「会等你先开口」的死物，龙是刻上去的。判据可数量化：恰好一块石板、恰好一条盘龙、
恰好一只涂金漆的龙眼。三条同时对上才不会滑成「飞天龙的风景画」。

**道具 6090「稀有价值」的图标只画「一枚鳞片」**：事件正文与奖励页都已经用文字讲清
「同名卡最多 3 张 / 每撕一张失 5 血」，图标再画三张卡或一把剪刀，在 44px 下只会糊成一团。
鳞片 + 龙眼纹样同时承担两件事：和龙石板同一套符号、和别的橙金道具（硬币 / 金币类）区分得开。

## 处理流程

- **整屏背景**：`raw/bg_dragon_slab.png`（1672×941，正好 16:9）→ LANCZOS 直接缩到 **1280×720**，
  与既有 21 张 `bg_*.png` 同规格，无需裁切、无需抠底。
- **事件插图**：`raw/event_dragon_slab.png`（1199×1312 竖构图）→ 居中裁成 4:3 后缩到 640×480
  （与 `event_sword / event_factory` 同规格，`TextureRect` 按 2× 显示）。
- **道具图标**：走 R755/R839b 那套 `cut()` —— 判据「亮且不饱和」→ 四边向内 4-连通泛洪取背景 →
  描边内侧收 2px → RGB/A 分开降采样 → 按 alpha≥8 取 bbox → 居中留 6% 边 → **128×128**。
  `_bg_mask` / `cut` 在 `tools/_make_r842_icon.py` 里**照抄一份**，不 import
  `tools/_make_r755_icons.py`（那模块没有 `__main__` 保护，import 会把主流程跑掉、覆盖两张
  `assets/ui` 图标 —— R836 实测过的坑）。

## 落地

| 文件 | 用途 |
|---|---|
| `assets/ui/bg_dragon_slab.png` | 事件整屏背景（1280×720，**实际显示的就是这张**） |
| `assets/ui/event_dragon_slab.png` | 事件居中插图（640×480，被整屏背景压住不显示，留作备选） |
| `assets/ui/relic_icon_6090.png` | 道具「稀有价值」图标（128×128 RGBA） |

- 道具图标同时被 **R577b 的正文悬浮小图标**复用：事件文案里提到「稀有价值」时，
  名字右侧会画一个 `0.9 × 字号` 的小图标（`event_scene._on_tip_draw()`），落盘即生效，界面零改动。
- 三张图的 `.import` 都已生成（`--headless --path . --import`），`git status` 复核过。

## 实际结果

| 文件 | 内容 |
|---|---|
| `raw/bg_dragon_slab.png` | 1672×941，1817 KB，codex 单次出图 **89s** |
| `processed/bg_dragon_slab.png` | 1280×720，993 KB，与 `assets/ui/bg_dragon_slab.png` **同字节** |
| `raw/event_dragon_slab.png` | 1199×1312，2625 KB，codex 单次出图 **317s** |
| `raw/relic_icon_6090.png` | 1254×1254，1289 KB，codex 单次出图 **418s** |
| `processed/relic_icon_6090.png` | 抠图 + 128×128 成品，19 KB，与 `assets/ui/relic_icon_6090.png` **同字节** |
| `processed/_preview_128px.png` / `_preview_64px.png` | 与 6086 / 6087 / 6089 三件橙金道具并排，128 与 64 两档尺寸 |

- 背景：**没出棋盘格伪透明、右下角也没水印**；直接缩放，未做二次修补。
- 图标：四角 alpha = 0、中心 alpha = 255（`tools/_make_r842_icon.py` 里是断言，不是肉眼）。
- 实机：`_shots/r842_dragon_slab_{normal,lethal,noally}.png` 三态截图（`tools/_shot_r842_event.gd`）——
  整屏背景铺满、石板完整不被对话框遮挡、选项置灰两态都对。

## 与代码兜底的关系

`UiAssets.event_bg("dragon_slab")` 缺图返回 `null` 时，`event_scene` 会退回
`_add_fallback_bg()` 的渐变底 + 居中插图，事件本身照常可玩 —— 贴图只是外观层。
店长口径（R839b）：**美术素材一律委托 codex 出图，不用代码 / SVG 硬画**。
