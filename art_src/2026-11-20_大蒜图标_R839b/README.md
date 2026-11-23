# R839b · 大蒜 7017 图标

## 出图提示词（原文，英文）

```
A cute hand drawn cartoon game item icon of a single garlic bulb, viewed from the front.
A fat rounded garlic bulb with creamy white papery skin and soft lavender purple streaks,
the lower half clearly split into four or five rounded separate cloves,
three soft vertical seams running up the bulb,
a short pointed dry papery stem stub on top, a small flat pale root base at the bottom.
Thick dark brown outline, flat cel shading with two or three tone steps,
warm saturated cream and lavender colors,
centered composition, single object isolated on a plain pure white background,
no text, no frame, no watermark, no shadow on the ground.
```

负面锁定（同一段末尾追加）：

```
NOT an onion, NOT a shallot, NOT a mushroom, NOT a pear, NOT a turnip,
no green leaves, no long green sprouts, no hanging roots, no basket, no plate, no knife.
```

- 尺寸 1024×1024 / quality=high / background=opaque（后端固定出白底，靠 `cut()` 抠）
- 原始文件：`raw/7017_大蒜.png`

## 设计口径

工具 7017 的效果是「封住一格 3 个我方回合」，**但图标本身不需要画「封锁」**——
战场上的封锁语义已经由 `_draw_seal_markers()` 承担（满格暗底 + 两道对角封条 + 右上角剩余回合）。
图标再叠一层「锁 / 叉 / 栅栏」，在 44px 下只会糊成一团黑，而且会被读成「这个道具不可用」。

所以这一张只解决一件事：**一眼认出是蒜头**。判据是两条可数量化特征 ——
①下半部能数出 4~5 瓣分离的蒜瓣；②顶部是**干枯纸质的断口尖**，不是圆顶、不是绿叶。
这两条同时对上，才不会滑到洋葱（圆顶、无分瓣）或梨（光滑、无瓣纹）。

## 处理流程

`tools/_make_r755_icons.py` 的 `cut()`：亮且不饱和 → 4-连通泛洪取背景 → RGB/A 分开降采样 →
按 alpha≥8 取 bbox → 居中留 7% 白边 → 128×128。
生成图的两个固定毛病（棋盘格伪透明、右下角水印）按老规矩先看一眼再决定要不要兜底涂白。

## 落地

- `processed/trap_icon_7017.png` → 拷到 `assets/ui/trap_icon_7017.png`（与前者同字节）。
- `scripts/trap_art.gd` 里 `_garlic()` 是**没有 png 时的程序化兜底**，贴图落盘后自动不走它，
  界面代码一行都不用动（与药瓶 / 烤肉 / 蘑菇同一套约定）。

## 实际结果

| 文件 | 内容 |
|---|---|
| `raw/7017_大蒜.png` | 1254×1254 原图，1270 KB，codex 单次出图 96s |
| `processed/trap_icon_7017.png` | 抠图 + 128×128 成品，与 `assets/ui/trap_icon_7017.png` **同字节** |
| `processed/_preview_44px.png` | 44px 实尺寸（炼金炸弹 / 爆炸蘑菇 / 工具袋 / 大蒜）—— 44px 下仍分得清 |
| `processed/_preview_88px.png` | 2× 高清，看瓣纹与纸感 |

- 背景：纯白，**没出棋盘格伪透明、右下角也没水印** —— 两个固定毛病这次都没犯，只走常规泛洪抠图。
- 自检：四角 alpha = 0、中心 alpha = 255（`tools/_make_r839b_icon.py` 里是断言，不是肉眼）。
- 实机：`_shots/r839_seal_board.png` —— 封锁格与工具栏都换成了贴图，无白底方块、无白边。

## 与代码兜底的关系

`scripts/trap_art.gd` 的 `_garlic()` 仍保留，只在 `assets/ui/trap_icon_7017.png` **缺失**时才走
（mod 去素材、旧包没带图这类情况）。贴图在时整段不进，与药瓶 / 烤肉 / 蘑菇同一套约定。
店长口径（R839b）：**美术素材一律委托 codex 出图，不用代码 / SVG 硬画**。
