# R842 · 龙石板事件素材（事件整屏背景 / 事件插图 / 道具 6090 图标）

> **R842c 纠错（店长口径）**：「龙错了，注意游戏的西幻风格。地点也不对，注意一层是在森林/水边。」
> 首版把龙画成了**东方盘龙**、场景画成了**干旱荒漠**，两处都跑偏。现行版本 = 森林溪畔 + 西幻带翼龙，
> 出图带上既有背景作参考图。首版原图归档在 `_v1_wasteland/`（仅留痕，不再使用）。

三张图共用一套驱动 `_run_slab.py`：

```
python _run_slab.py <tag> [参考图路径]   # tag = bg_dragon_slab / event_dragon_slab / relic_icon_6090
```

prompt 走 stdin 读 `prompts/<tag>.txt`，图落 `~/.codex/generated_images/<thread>/exec-*.png`，
**由脚本抄进 `raw/`**（不抄就随 thread 目录被清掉）。代理 `http://127.0.0.1:7897`，一张图一次会话。
第二个参数是可选的 `-i` 参考图（R842c 新增），只借环境/雾气/光/笔触，主体一律重画。

## 参考图怎么选（关键）

| 出图 | 参考图 | 借什么 | 明令不许抄什么 |
|---|---|---|---|
| `bg_dragon_slab` | `assets/ui/bg_sword.png`（`林中的剑` 整屏雾林） | 雾气、天光、青绿灰调、下半屏留白构图 | 那把剑、那座裂开的石碑、居中立碑的构图 |
| `event_dragon_slab` | `assets/ui/event_sword.png`（`林中的剑` 4:3 特写） | 厚涂笔触、暖金林光、石上长苔的画法 | 剑、构图、任何武器 |

一层的既有事件（`sword` / `lake_lady`）就是这套基调：**雾林 + 溪水 + 暖金光**，不是荒漠。
上一版 prompt 里写 `hand-drawn anime fantasy style, thick clean dark outlines, flat cel shading`
—— 与库里既有一层事件图（厚涂奇幻）也不一致，这次一并换成 `painterly fantasy game art`。

## 出图提示词（原文，英文）

`prompts/bg_dragon_slab.txt`（**实际落地的是这一张**）：

```
A wide 16:9 background illustration for a fantasy card roguelike event screen, painterly fantasy
game background, hand-painted look with soft visible brushwork, stylized idealized forms, NOT
photorealistic, NOT a photo, NOT a 3D render, no cartoon outlines. Cool damp forest palette of
mossy teal-green and grey, with one warm ochre-amber accent on the stone.

THE REFERENCE IMAGE is provided ONLY to borrow its environment, mist, light shafts, brushwork and
overall color balance. Do NOT copy its sword, do NOT copy its broken stone monument, do NOT copy
its central vertical composition. This is a completely different object in the same forest.

Scene: a misty evergreen forest clearing beside a shallow forest stream. Wide moss-covered trunks
recede into pale fog, tall ferns and long grass at the edges, small yellow wildflowers, a fallen
log half sunk in moss, smooth wet stones in the water. A thin veil of low mist drifts over the
stream. Shafts of soft morning sun slant down through the canopy from the upper left.

Subject: ONE weathered stone slab of ochre-yellow sandstone, standing tilted in the moss near the
water's edge, a little taller than a person, its top corner chipped off. Its face is carved with a
single WESTERN dragon in shallow relief: a four-legged wyrm with leathery bat-like wings folded
along its back, a lizard head with swept-back horns and snarling fanged jaws, a ridged spine, and a
long barbed tail coiling once around the centre of the slab. The carving is worn almost smooth by
weather, so only the raised ridges catch the light. One eye socket still holds a small hollow of
old gold paint that glows faintly warm. Hairline cracks and pale lichen creep across the stone,
moss climbing the base, water lapping at a few fallen pebbles in front of it.

Composition: the slab sits in the upper right part of the frame, roughly one third of the frame
height, seen three-quarter from the front so the carved dragon still reads clearly at thumbnail
size. Warm side light from the upper left, soft long shadow falling to the right. The entire lower
half of the frame is deliberately calm and almost empty — smooth misty forest floor and still
water fading into cool grey-green haze, with only faint grass and drifting mist — so interface text
can be read over it. The horizon sits high, around the upper third, dense forest and pale fog above.

Hard constraints: exactly one slab, exactly one WESTERN dragon carved INTO the stone, exactly one
gold eye. The dragon is a relief on the stone, never a separate living creature.

NOT an eastern serpentine dragon, NOT a long snake-like body, NOT an oriental lion-dragon, NOT a
coiled Chinese dragon, NOT a dragon orb or pearl, NOT cloud-and-wave oriental motifs, NOT a
desert, NOT a wasteland, NOT sand dunes, NOT dry cracked earth, NOT a temple gate, NOT a human
statue, NOT a sword, NOT a flying dragon in the sky, NOT a dragon emerging out of the stone, NOT
gold coins, NOT glowing neon runes covering the surface, NOT a pedestal, NOT a crowd of objects,
NOT thick cartoon outlines.

no text, no letters, no signature, no watermark, no frame, no border, no UI elements.
```

`prompts/event_dragon_slab.txt` 是同一主体的 **4:3 特写版**（石板占满画面、龙纹压到能数清鳞片），
参考图换成 `event_sword.png`。代码里被整屏背景压住不显示，是缺图时的兜底。

`prompts/relic_icon_6090.txt`：单件道具图标口径（一枚打磨得极亮的龙鳞，鳞面带龙眼纹样，
橙金配色、厚描边、纯白底居中）。

## 设计口径

**为什么最后要出整屏 `bg_` 而不是只留 `event_`**：`event_scene` 给 `event_<kind>.png` 的框是
`320×240`、贴在 `y 116..356`，而对话框从 `y≈351` 起 —— 那块图**下沿会被对话框切掉一大半**。
R802 定的规矩就是「有 `bg_<kind>` 就不叠 `event_<kind>`」，整屏图铺底才留得出正文与选项的位置。
所以这张背景的构图硬约束是**下半屏几乎留白**（只有雾、草与水光），石板压在上三分之一、偏右，
不与正中对话框（`x≈339..947 / y≈351..702`，1280×720 坐标）打架。

**三层硬约束缺一不可**（这次踩坑就在第一、二层写错）：

1. **西幻**：`WESTERN dragon` 要拆成可数的形态特征 —— 四足、一对膜翼、蜥蜴头、后掠的角、尖齿、
   带棘的脊背、末端带倒钩的长尾。反例也点名：`NOT an eastern serpentine dragon / NOT a coiled
   Chinese dragon / NOT an oriental lion-dragon / NOT a dragon orb or pearl`，不点名它就会滑回盘龙。
2. **一层的地点**：`misty evergreen forest clearing beside a shallow forest stream` + 苔藓 / 蕨类 /
   野花 / 倒木 / 溪床卵石 / 低雾 / 林隙天光。反例 `NOT a desert / NOT a wasteland / NOT sand dunes`。
3. **浮雕而非活龙**：这是这个事件的语义 —— 石板是一块「会等你先开口」的死物，龙是刻上去的。
   可数量化：恰好一块石板、恰好一条龙、恰好一只涂金漆的龙眼。

**画风段别写反**：R807 那次把「厚涂、不要描边」写成照片级写实，出一张布偶实拍。这次两头都钉住：
`painterly fantasy game art, soft visible brushwork, stylized idealized forms` +
`NOT photorealistic, NOT a photo, NOT a 3D render, no cartoon outlines`。

**道具 6090「稀有价值」的图标只画「一枚鳞片」**：事件正文与奖励页都已经用文字讲清
「同名卡最多 3 张 / 每撕一张失 5 血」，图标再画三张卡或一把剪刀，在 44px 下只会糊成一团。
鳞片 + 龙眼纹样同时承担两件事：和龙石板同一套符号、和别的橙金道具（硬币 / 金币类）区分得开。

## 处理流程

- **整屏背景**：`raw/bg_dragon_slab.png`（1672×941，16:9）→ LANCZOS 直接缩到 **1280×720**，
  与既有 21 张 `bg_*.png` 同规格，无需裁切、无需抠底。
- **事件插图**：`raw/event_dragon_slab.png`（1448×1086，4:3）→ LANCZOS 缩到 **640×480**
  （与 `event_sword / event_lake_lady / event_factory` 同规格，`TextureRect` 按 2× 显示）。
  比例对不上时脚本会居中裁到目标比例再缩，**不拉伸**。
- 两张都由 `tools/_make_r842c_art.py` 一次跑完（raw → processed → `assets/ui`，并断言两份字节一致）。
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
| `raw/bg_dragon_slab.png` | 1672×941，1950 KB，codex 单次出图 **111s**（带参考图） |
| `processed/bg_dragon_slab.png` | 1280×720，1053 KB，与 `assets/ui/bg_dragon_slab.png` **同字节** |
| `raw/event_dragon_slab.png` | 1448×1086，2828 KB，codex 单次出图 **181s**（带参考图） |
| `processed/event_dragon_slab.png` | 640×480，582 KB，与 `assets/ui/event_dragon_slab.png` **同字节** |
| `raw/relic_icon_6090.png` | 1254×1254，1289 KB，codex 单次出图 **418s**（纯文生图） |
| `processed/relic_icon_6090.png` | 抠图 + 128×128 成品，19 KB，与 `assets/ui/relic_icon_6090.png` **同字节** |
| `_v1_wasteland/*_v1.png` | 首版（东方盘龙 + 荒漠），**仅本地留痕、不入库**（目录带 `.gdignore`，不参与构建，也不被 `--import` 扫到） |
| `processed/_preview_128px.png` / `_preview_64px.png` | 与 6086 / 6087 / 6089 三件橙金道具并排，128 与 64 两档尺寸 |

- 背景：**没出棋盘格伪透明、右下角也没水印**；直接缩放，未做二次修补。
- 图标：四角 alpha = 0、中心 alpha = 255（`tools/_make_r842_icon.py` 里是断言，不是肉眼）。
- 实机：`_shots/r842_dragon_slab_{normal,lethal,noally}.png` 三态截图（`tools/_shot_r842_event.gd`）——
  整屏背景铺满、石板在对话框右侧不与正文重叠、选项置灰两态都对。

## 与代码兜底的关系

`UiAssets.event_bg("dragon_slab")` 缺图返回 `null` 时，`event_scene` 会退回
`_add_fallback_bg()` 的渐变底 + 居中插图，事件本身照常可玩 —— 贴图只是外观层。
店长口径（R839b）：**美术素材一律委托 codex 出图，不用代码 / SVG 硬画**。
