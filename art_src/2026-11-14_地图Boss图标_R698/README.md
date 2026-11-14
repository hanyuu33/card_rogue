# R698 地图 Boss 房图标（codex 出图）

> 2026-11-14 · 起因：全库图片体检时发现「Boss 房图标整条缺失」——
> `RogueMap.TYPE_LABELS` 里有 10 种节点类型，`assets/ui/map_icons/` 只有 9 张，
> 缺 `boss`。`UiAssets.node_icon("boss")` 的两级回退（`map_icons/boss.png` →
> `map_boss.png`）全落空，于是地图上的 Boss 格只画一个汉字「王」。

## 调用约定（沿用 R562 实测）

| 项 | 做法 |
|---|---|
| 出图工具 | `codex exec --json -i <参考图>` → codex 内置 `image_gen` |
| 参考图 | `assets/ui/map_icons/elite.png`（只借描边粗细 / 色块逻辑 / 徽章构图） |
| 代理 | 必须 `HTTP(S)_PROXY=http://127.0.0.1:7897` |
| 取图 | 图落 `~/.codex/generated_images/<thread>/exec-*.png`，由 `_run_boss.py` 解析 JSONL 复制到 `raw/` |
| 后处理 | `_prep_mapicon.py`：按 alpha 外框归一 → 主体占画布 92% → 居中贴 256×256 透明画布 |

## 三版迭代

| 版本 | 结果 | 问题 |
|---|---|---|
| v1 | 骷髅 + 王冠 + 交叉双斧 + 红披风 | 徽章铺满画布，左 / 下被画布**切掉**（留白 0px） |
| v2 | 同构图 + 构图锁（缩到 76%） | 主体完整了，但**元素过密**，缩到 73px 糊成一团、且比同目录图标小一圈 |
| **v3（定稿）** | **只留王冠 + 牛角骷髅** | 元素干净、大色块，73px 下王冠与骷髅仍可辨 |

v3 的关键是「SIMPLICITY LOCK」：明确写出「这是地图上的小图钉不是海报」「每个形状不小于画布 1/12」
「不许加铆钉 / 裂纹 / 细饰」，并显式列 `NO crossed axes / NO banner / NO cape` 把 v1/v2 的堆料压掉。

## 产物

- `art_src/2026-11-14_地图Boss图标_R698/raw/boss_v3.png` —— 1254×1254 原图（留档）
- `assets/ui/map_icons/boss.png` —— 256×256 RGBA，主体占幅 91% 宽 / 88% 高，
  与 `battle`(94%/93%)、`elite`(91%/97%) 同一量级

## 验收

- 并排对比 `_review/map_icons_compare.png`（160px）与 `_review/map_icons_small.png`（73px = 游戏内实际尺寸）。
- 运行时：`UiAssets.node_icon("boss")` 返回非 null（128×128，与其它节点同口径）。
- 守卫断言：`scripts/test_engine.gd` 里按 `RogueMap.TYPE_LABELS` 逐类型验「取得到图」，
  不再只验路径字符串拼得对。
