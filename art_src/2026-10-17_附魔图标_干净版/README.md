# 附魔图标 · 干净版（R216）

## 为什么做这一批

用户反馈：「附魔中为什么次元图标是有白底的？」

排查结论：旧的 `shop_icon_damage / dimension / save.png` 是 2026-10-15「SD 贴纸风」生成图 ——
**圆角板内是不透明米白 `(242,242,238)`**，只有板外一圈 alpha=0。放在浅色货架上看不出来，
贴到卡面那枚深色附魔徽章上就是一块白方块。
`shop_icon_costdown.png` 当年是真透明（alpha 直通），**没有动**（用户口径：旧的正常不许重做）。

抠图救不回这三张：白描边与米白底板同色，色距阈值 14 / 40 两档都会把描边啃成毛边
（见 `tools/_matte.py`，留作物证）。所以按纯洋红底重画。

## 产出

| 文件 | 来源 |
| --- | --- |
| `Flat_game_UI_icon_sheet_on_a_s_….png` | 2×2 合集（费用 -1 / 伤害 +10 / 次元 / 保存），1024² |
| `A_single_game_UI_icon_centered_….png` | 单独重画的燃烧剑（合集里那把太瘦，15px 徽章上像根蜡烛） |

提示词要点：`solid pure magenta #FF00FF background` · `thick dark ink outline` ·
`flat bright fills` · `no white outline / no glow / no drop shadow / no frame / no text`。
合集提示词里写明「2x2 grid，each centered in its own quadrant」—— 分片因此可以按象限对号入座。

## 处理（`tools/_chroma_key.py`）

1. 洋红指数 `m = min(r,b) - g`：纯洋红 255，本批图案色（红/橙/绿/蓝/紫/白/灰）都 ≤ 0。
2. **从边框泛洪** `m >= 40` → 背景整块清 0。**投影必须靠这一步吃掉**：
   建模成 `(255k, 0, 255k)` 时 `m = 255k`，不判它就留下一个暗红方块（第一版就踩了）。
3. 其余像素按混色比例反解：`f = m/255`，`alpha = 1-f`，`C = (P - f·M)/(1-f)`。
   抗锯齿边因此是**半透明前景**，不留粉边。
4. 最大连通块 → 裁 bbox → 等比缩到最长边 52 → 居中放进 64×64（52 是上限，
   再大图案的方角会顶出徽章圆环 `ir = r*0.86`）。

```bash
python tools/_chroma_key.py                                  # 合集 → 四枚（costdown 会被覆盖，记得 git checkout 还原）
python tools/_chroma_key.py --single <png> damage            # 单张 → 一枚
```

⚠️ 替换 `assets/ui/shop_icon_*.png` 之后**必须**重跑
`godot --headless --path . --editor --quit-after 120`，否则读的是 `.godot/imported` 里的旧纹理。
