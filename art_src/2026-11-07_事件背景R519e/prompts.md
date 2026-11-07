# R519e 事件背景 · 画风修正后的提示词

## 用户口径

「这些事件图的风格太写实了。注意生成时契合游戏风格，你可以参考占卜那种风格」

## 问题定性

R519d 那批的 raw 文件名是 `Semi_realistic_painted_fantasy` —— 不是模型跑偏，是**提示词写错了**：

| | R519d（错） | 占卜室 / R519e（对） |
|---|---|---|
| 渲染 | semi-realistic painted fantasy | **2D cel-shaded cartoon illustration** |
| 描边 | 无 | **粗黑描边包住每个形体** |
| 上色 | 厚涂渐变、脏污、颗粒 | **平涂色块，2 级明暗，硬边阴影** |
| 石/木/铁 | 照片级纹理、苔藓、铁锈 | 概括成色块 + 一道亮边 |
| 烟雾 | 体积雾、扩散 | 一条硬边曲线 |
| 饱和 | 暗黄泥浆 | 低饱和冷灰蓝 + 单一暖点 |
| 缩到 1280 看 | 糊成一团暗块 | 剪影干净、一眼可读 |

占卜室目录里本来就有 `废弃_v1_写实厚涂.png` —— 同一课早就踩过一次，只是没带过来。

## 风格底（每张必贴，一字不改）

```
2D ANIME GAME BACKGROUND for a light-fantasy mobile trading-card game,
hand-drawn cel-shaded cartoon illustration, NOT a render.
THICK CLEAN BLACK OUTLINE around every shape and every object.
Flat colour blocks, exactly TWO shading steps per object, hard-edged shadow shapes,
no soft gradient inside a colour area.
Limited low-saturation palette: cool charcoal blue-grey stone, muted purple, one warm amber accent.
Simple readable shapes, clear silhouette, drawn detail only where the eye lands.
aesthetic: cozy hand-painted storybook, the same art direction as a fortune-teller's candle-lit parlour.

NO photorealistic texture, NO photographic stone / metal / wood grain, NO rust, NO moss, NO grime,
NO volumetric fog, NO god rays, NO depth-of-field, NO film grain, NO noise,
NO 3D render, NO sculpted PBR material, NO muddy brown palette, NO dark western comic style,
NO cross-hatching, NO airbrush.

EMPTY scene. NO people, NO characters, NO creatures, NO text, NO letters, NO watermark.

COMPOSITION: all detail lives in the UPPER TWO THIRDS of the frame.
The BOTTOM THIRD is a calm empty floor / ground fading to near-black, keep it clean and simple.
```

## 六张主题（接在风格底后）

| kind | 追加描述 |
|---|---|
| `smith` | A tidy duck-artisan smithy interior: stone hearth with a bright orange fire, wooden anvil bench, a large fantasy playing card held over the fire by long iron tongs, a few tools hanging on the wall. Warm amber firelight is the only bright thing. |
| `struggle` | A cracked wasteland at the edge of a battlefield: broken ground plates, dark red mist rising in flat ribbon shapes, the vague silhouette of a metal dragon forming out of the mist, low flat horizon. |
| `oblivion` | A still black forest pool at dusk: dark water surface reflecting absolutely nothing, tall slim silhouettes of trees, faint blue-grey glow from the water, a few flat grey stones at the rim. |
| `snow_leopard` | A dusk snow slope: smooth flat white-blue snowbanks, a trail of paw prints leading away into the distance, sparse bare trees, cold violet sky. NO animal body, only the trail. |
| `adventurer` | A stone ledge at the foot of a cliff: an old leather travel pack, an open notebook with blank pages, a flint hanging from the pack buckle, dry grass. Still life, no figure. |
| `martial` | Under a huge old tree: an elderly man sitting cross-legged seen from behind in silhouette, a wooden staff across his knees, a boulder split by fist strikes beside him, flat grass ground. |

## 生成参数

- `size: 1536x1024`
- `image1: style_ref/bg_divination.png`
- `input_fidelity: low` —— 只借画风，不借场景（`_style_prompts.md` §四·用法一）
- prompt = 「只借画风」声明 + 风格底 + 主题

前置声明（每张都带）：

```
Use the reference image ONLY AS AN ART-STYLE REFERENCE.
Copy its drawing technique: the thick black outline, the flat cel-shaded colour blocks,
the low-saturation palette, the edge treatment, the level of detail.
Do NOT copy its scene, its room, its crystal ball, its curtains, its candle, its composition,
its camera angle. Paint a COMPLETELY DIFFERENT scene.
```

## 验收（缩到 1280×720 再看）

1. 有没有黑描边 —— 没有就是废图。
2. 缩图后剪影是否一眼可读，有没有糊成暗块。
3. 石块/木头是否还长着照片纹理。
4. 下三分之一是否留空、够暗，正文卡片压上去不打架。
5. 和 `bg_divination.png` 并排看，是不是同一个世界里的两张图。

---

# R519f 构图契约修正（追加）

## 用户口径

「雪豹为什么要刻意做成半张图的效果？没有必要」。

## 契约改了两句

### ① 下三分之一：从「留空压暗」改成「铺满整张」

原写法（**废除**）：

```
The BOTTOM THIRD is calm empty ground fading to near-black, keep it clean and simple.
```

新写法：

```
The scene FILLS THE WHOLE FRAME from top to bottom.
The ground runs off the bottom edge and is DRAWN - grass tufts, pebbles, roots, bushes,
cast shadows, a visible silhouette, two tonal steps.
It may be one shade darker than the rest, but it is NOT a flat single-colour fill,
NOT a black bar, NOT a void.
There must be NO horizontal line across the frame where drawn detail stops and colour begins.
```

「留空」＝不放主体，不是不放画面。

### ② 主体位置：从「上三分之二」改成「左/右三分之一」

原写法（**对坐地题材不成立**）：

```
All detail lives in the UPPER TWO THIRDS of the frame.
```

新写法：

```
A UI text panel will later cover the CENTER of this image.
Place all subjects in the LEFT THIRD or the RIGHT THIRD, or in the UPPER TWO THIRDS.
The CENTER strip stays visually empty - only plain scenery there.
```

卡片遮挡：纵向 y≈47% 往下、横向约 26%–74%。

## 返工记录

| kind | 次数 | 问题 | 改法 |
|---|---|---|---|
| `snow_leopard` | 2 | 下半张纯色空块 | 前景雪堤铺满下半 + 碎石枯草 + 脚印延续 |
| `martial` | 3 | 老人被卡片盖住 | 老人移左 18%、38%–62% 高度线；石头移右同高 |

`martial` 第 2 版是「把人整体上移」—— 坐地题材做不到，反而把天空画成橙粉落日、
明度跳出整套，废掉。

---

# R519h 休息处篝火（追加）

## 结论先行：这类主体不要出整屏背景

整屏 4 版全废（位置约束写了「左三分之一」「中心 11% 不超 22%」「bottom-left corner」
「整堆在上半部」都没用），最终走左右布局。失败对照见 `UI设计规范.md` §4.56。

**规则：主体必须避开某块 UI 区域时，不要靠提示词赌位置，换布局。**

## 侧图（一次过）

`image1 = style_ref/bg_divination.png`，`input_fidelity: low`，`size = 1024x1024`。
关键句：

```
SUBJECT: ONE BIG BURNING CAMPFIRE, the hero of the picture, large and close.
TALL FLAMES as three or four big flat hard-edged shapes:
deep orange outer flame, bright yellow inner flame, small pale core.
A few flat diamond-shaped sparks. Thin smoke is ONE hard-edged curved ribbon.
One flat lighter shape of firelight on the dirt, clean edge.
The campfire sits slightly LEFT of centre, nothing cut off by the edges.
The RIGHT SIDE is deliberately QUIET: the same drawn dirt ground continues,
darker toward the right edge, NEVER a solid rectangle, NEVER a hard edge.
```

夜景暗调、火焰是唯一暖点。水印在方图内 → `patch_wm()` 修补（不能像 martial 那样裁掉）。
