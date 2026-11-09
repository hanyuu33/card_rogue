# 2026-11-09 信物图标 R543

三样「第三层信物」的小图标：完美螺钉 6061 / 生命之种 6062 / 屠戮匕首 6063。
成品 = 仓库 `assets/ui/key_icon_{screw,seed,dagger}.png`（512×512 透明底）。

## 采用 / 弃用
* screw_v1 / seed_v1：`background:transparent` 又没生效，出成**棋盘格假透明 RGB**；
  用「棋盘两色放宽判据（min>=196 低饱和）四角 BFS + 最大连通块」抠净，**采用**。
* dagger_v1：背景被画成**深灰棋盘格**（白底判据失效）+ 右下角模型水印 → **弃用**。
* dagger_v2：改 prompt 指定 plain solid pure white background + 斜置占 70% → 白底抠净，**采用**。
  横向细长构图在 44px 徽章里会缩成细线（R130 教训），必须竖/斜置。

## 处理
tools/process_r543_icons.py：四角 BFS 抠连通底 → 羽化边缘圈 → 只留最大 alpha 连通块
（顺带去水印）→ 裁 bbox → 512×512 画布居中 → 44px 验收拼图。
