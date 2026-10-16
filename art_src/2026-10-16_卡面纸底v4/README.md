# 卡面纸底 v4（R193）

用户口径：「花纹不像是在下半，反而像是上半的。并且和文字很不搭。做成有个卡名框的样式，注意和卡名文字位置要契合，且能容纳尽可能大量的文字（在卡片宽度范围内）」。

## 文件

- `raw_ai_template.png`：ImageGen 生成的 1024×1536 竖版卡框原图（日式二次元 + 西幻，parchment + 底部 ornate 姓名牌）。
- `card_paper_v3_old.png`：R156~R192 使用的旧纸底（v3，顶部装饰重、底部姓名牌偏窄）。
- `card_paper_v4_new.png`：最终采用、裁水印并缩放到 640×772 的工程模板。
- `preview_montage.png`：PIL 仿真器在 battle / hand / reward / pick 四种尺寸下的合成预览。
- 处理脚本见 `art_src/tools/_process_card_paper.py`（已更新为 v4 流程）。

## 分区坐标（归一化）

- `art_ratio` = 0.662（卡图/文字区分隔金条顶部）
- 姓名牌内框：`x0=0.06, y0=0.745, x1=0.94, y1=0.94`
- 卡图窗：`x0=0.06, x1=0.94, y0=0.03, y1=0.647`

## 代码联动

- `scripts/ui_theme.gd`：新增 `CARD_NAMEPLATE_*` 常量，并将 `CARD_ART_RATIO` 改为 0.662。
- `scripts/card_face.gd`：`draw_pick()` / `_draw_text_zone()` / `draw_text_backing()` 全部改为按姓名牌内框排布；`draw()` 有纸底时不再手画底部框线，避免双重边框。
