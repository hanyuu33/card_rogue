# 奖励页冒险风 v2（仅新增）

v1 页面、原始 18 张素材和正式入口均未覆盖。reward_panel_v1.gd.txt 和 v1.png 是本轮开始时的快照。

新增脚本 scripts/reward_panel_adventure_v2.gd 继承原页面，仅覆盖素材选择与说明框绘制。说明框宽 880 px，居中；保留动态折行、高度计算、效果提及命中。
新增预览 scenes/reward_adventure_preview.tscn，实际使用游戏卡牌与奖励交互。正式游戏仍使用 v1。

预览：Godot.exe --path D:/work/card_rogue res://scenes/reward_adventure_preview.tscn -- --r119pick
截图：追加 --screenshot，输出本目录 v2.png。

## 素材
内置 image_gen 编辑原图，透明背景；没有使用 CLI。三张新 PNG 保存在 assets/ui/reward_adventure_v2/，分别为 18（底板）、01（标题）、11（徽章）；其他素材复用 v1。

提示词要点：保留轮廓、留白、透明区域；Japanese illustrated Western medieval fantasy adventurer journal；muted forest sage cloth, aged brass, warm ivory paper；replace royal crest with faint fern and wandering star；replace fleur-de-lis with overlapping cards and leaf；badge uses simple brass rim and practical rivets；no crowns, no fleur-de-lis, no baroque scrollwork, no text or numbers。
