# R793 道具图标：刺墙 6073 / 应急装甲 6074

## 来由

店长口径：

- **刺墙**：工事被攻击时，使攻击者受到 4 伤害。
- **应急装甲**（图片为机械装甲）：单回合最多受到 20 伤害。

## 文件

| 文件 | 说明 |
|---|---|
| `raw/6073_刺墙.png` | 生成原图（1024×1024，白底，右下角带水印） |
| `raw/6074_应急装甲.png` | 生成原图（1024×1024，**棋盘格伪透明**，右下角带水印） |
| `processed/relic_icon_6073.png` | 成品 128×128 RGBA（透明） |
| `processed/relic_icon_6074.png` | 成品 128×128 RGBA（透明） |
| `prompts/图标两件.txt` | 实际使用的提示词 |

## 管线

1. 生成：内置图像生成（`ImageGen`），`size 1024x1024` / `quality high` /
   `background transparent`，参考图 = `assets/ui/relic_icon_6070.png`（板甲），
   让新图和 R792 三件保持同一套描边与明暗。
2. 去水印：右下角 `[0.86w, 0.93h] → 右下` 涂白（生成图固定带水印）。
3. 抠图：`tools/_make_r793_icons.py` → 复用 `tools/_make_r755_icons.cut()`。
   - 棋盘格 / 白底都靠**从四边泛洪**判背景（不按亮度算 alpha —— 灰石会被判半透明）；
   - 前景收 2px、背景 RGB 刷成描边深色、RGB 与 A 分开降采样再合并；
   - 按 `alpha >= 8` 取 bbox 居中，`pad_pct` 刺墙 0.08 / 机械装甲 0.07。
4. ⚠️ `_make_r755_icons` 的构建代码在**模块顶层**（无 main 保护），import 会顺带重跑
   它那两张旧图 → 脚本在 import 前后对 md5，变了就 `git checkout` 还原。

## 验收

- 两张都是 `alpha extrema (0, 255)`、四角全透明（无白雾）。
- 44px（道具栏 `RelicBarLayout.CELL = 44.0`）下轮廓可辨：刺墙看尖刺 + 石墙，
  机械装甲看胸甲 + 琥珀核心。
