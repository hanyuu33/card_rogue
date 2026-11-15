# R761 · 吟游诗人（隐藏职业）CG + 头像

## 需求（店长口径）

> 吟游诗人 CG 用卷卷的图重新委托 codex 生成一张，以确保人物在图中的位置和现在其他几个职业
> 一样（卷卷为初始事件 CG，新图要改变姿势，站姿，和其他人一样略微朝左而不是右）。

参照事实（量出来的，不是感觉）：

| 素材 | 人物横向位置 | 朝向 | 取景 |
|---|---|---|---|
| `class_cg_forest.png` 1280×676 | 约 60~72% | 略微朝左 | 全身到脚踝 |
| `class_cg_rogue.png` 1280×720 | 约 65~85% | 朝左（半侧） | 腰部以上 |
| `class_cg_mech.png` 1280×720 | 约 58~80% | 朝左（半侧） | 膝上 |
| `bg_curtain.png` 1600×900（卷卷） | 约 30~75%，**居中偏左** | **朝右**（坐姿） | 坐姿全身 |

→ 新图要：**站姿**、**略微朝左**、人物落在**右半边（60%~80%）**、左侧留空给详情面板。

## 管线

```
python _run_codex.py            # CG + 头像各一版（代理 7897 / prompt 走 stdin / JSONL 取图）
python _finish.py               # 关键色抠底 → 1280×720 CG / 320² 透明头像，落到 assets/ui/
```

- 参考图：CG 与头像都用 `assets/ui/bg_curtain.png`（卷卷本体，坐姿那张）。
- 头像按老规矩出**洋红底**再抠（直接要透明底会被后端画成棋盘格）。
- 道具图标「诗」走 `_run_codex_icon.py` + `_finish_icon.py`（参考图 = `relic_icon_6052.png`
  竖琴，只借画风）；这张原图是**真透明**（四角 alpha=0），所以不走棋盘格泛洪，
  直接 bbox → 正方形居中 → 128，RGB / A 分开降采样。

## 定稿（R761）

| 产出 | 来源 | 说明 |
|---|---|---|
| `assets/ui/class_cg_bard.png` 1280×720 | `raw/cg_bard_v2.png` | v1 人物偏小、头顶离画面顶太远 → 写 `cg_bard_v2.txt` 重新委托（头贴顶边、胸像到膝上、占宽 58%~85%），**定稿 v2 直缩**（不再二次裁切） |
| `assets/ui/class_avatar_bard.png` 320² | `raw/avatar_bard_v1.png` | 洋红判据抠底 + `GaussianBlur` 羽化 alpha + bbox 裁成正方形 |
| `assets/ui/relic_icon_6069.png` 128² | `raw/icon_relic_6069.png` | 卷轴 + 红丝带 + 金音符；与 6052/6067/6068 并排核过线宽与饱和度（`_preview_r761_relic_icon.png`） |

验收页（都在本目录）：`_R761_CG对比_森林_刺客_机械_吟游.png`（四职业并排看位置/朝向）、
`_R761_头像预览.png`；道具图标并排页在工程根 `_preview_r761_relic_icon.png`。
三张都已肉眼核验通过。

> ⚠️ 工作区里另有一批**不是这条线出的**吟游诗人图（`avatar_bard_magenta_v1.png` /
> `bard_poem_generated_v1.png` / `bg_curtain_class_select_v1.png` / `bg_bard_class_select_v2.png`），
> 没有任何代码引用它们。本轮**没有**替换或删除，等店长定夺。
