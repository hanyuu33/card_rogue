# 战斗 UI / 三层地形（2026-11-04）

本批修改真实 `scenes/battle.tscn` 使用的 `scripts/battle_scene.gd`，未建立平行游戏页面、未改引擎规则。

- 双方生命：浅纸信息牌、血滴素材、滚动数字；保留无限 HP。敌方牌位于关卡铭牌下方。
- 手牌：可读纸底数量提示，保留上限与满手颜色。
- 双方效果：60×52 卡图缩略图，58px 步进；保留悬停详情、同名合并、剩余次数、溢出摘要与点击展开、原效果卡拖放范围。无卡图时以卡名回退，不伪造卡图。
- 回合提示：复用森林绿素材横幅，保留时序和淡入淡出。
- 移除常驻格线、后排色罩与半场直线。保留移动/选目标、火墙、场地等必要操作高亮，单位归属改为底部短线。
- 第一层草岸/溪水/木桥；第二层机械甲板与钢制战区（无桥）；第三层舰船甲板/云海。

## 素材与几何

内置 imagegen 生成，源图保留本目录。正式素材 `assets/ui/adventure_shared/battlefield_{1,2,3}.png`。
按用户允许的裁切方式，`tools/prepare_battle_terrain.py` 将源图重排成 900×1350：
三列各 300px、上下后排各 225px，中央四行合计 900px。
绘制映射到真实 372×660 逻辑战场，随棋盘滚动；第一层桥两边为 x=124/248，后排分界为 y=110/550。
图画中的石岸/舰船边缘有自然起伏，分区裁切基准严格对齐格界。

生成提示词规格（内置模式，非 CLI）：

1. Portrait 2:3 top-down orthographic battlefield background for Japanese illustrated western fantasy card game. No cards, UI, text, grid lines, tile borders. Top and bottom sixth forest grassy river banks; middle four sixths clear turquoise stream. Vertical wooden footbridge in central third connecting both banks. Daylight, sage greens, aged wood, quiet playable surface, no horizon. 实际生成桥偏窄，已通过三条纵切片重新映射到等宽三列。
2. Portrait 2:3 orthographic straight-down Japanese painted mechanical fantasy card battlefield. No UI, text, cards, bridge or chasm. Continuous steel factory floor. Top and bottom sixth brass-edged command decks. Horizontal mechanical seams at y=1/6 and 5/6; subtle vertical structural seams at x=1/3 and 2/3. No horizontal grid or checkerboard. Small pipes and gears on outer margins, quiet center, warm brass and desaturated teal steel. 使用用户纠正后的无桥版本。
3. Portrait 2:3 top-down orthographic sci-fi airship battlefield, Japanese painted fantasy. No cards, UI, text, grid. Top and bottom sixth opposing pale-metal battleship decks with navy panels and cyan conduits. Central four sixths luminous white clouds and blue sky below, no bridge, quiet open placement area, no horizon.

## 验证与边界

运行 `_verify.py`（设置 GODOT_BIN）执行现有 engine / reward / bgm / smoke 回归。
运行 Godot `--path . --script tools/verify_battle_style.gd` 验证效果槽位边界并捕获三层战场、下滚视图、回合横幅。
截图来自真实战斗场景，注入效果卡并切换层号用于视觉检查；不是三层逐关通关证明。截图关卡仍为同一鸭子关，场外地图背景仍随该关配置。
未改历史 CG 事件、故事关闭按钮、卡牌规则。待补：缺失的旧效果卡图；非常规分辨率及逐种效果交互人工体验。
截图中迅捷/石肤无原始卡图，显示文字回退；送葬可见卡图缩略图。
