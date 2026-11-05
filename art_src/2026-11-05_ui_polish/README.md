# 2026-11-05 UI 统一收尾

本目录保存另一 agent 留下、由接手 agent 完成验收的 UI polish 批次。沿用浅纸、森林绿、旧黄铜，不改 CG 布局、玩法逻辑或既有命中区域。

## 落地内容

- `UiTheme.draw_panel_bg()` 使用 `panel_journal_light_hd.png` 做独立角部九宫格拉伸；小面板仍走原有浅色样式。职业详情、记录详情等同步调整内容内边距。
- `UiAssets.filtered()` 对卡面纸底、卡图、卡框与徽章按显示尺寸分桶做 Lanczos 预缩放和缓存；职业头像也走小尺寸缓存。
- 商店与附魔图标统一走 `UiAssets.shop_icon()`：删卡、卡牌、费用、伤害、次元、保存、起手、最大生命分别映射到现有奖励/地图/共享素材；新增 `service_vitality.png` 补齐最大生命服务。
- 原生 Button 与自绘按钮在小尺寸下使用紧凑样式，并按实际宽度降低字号，避免「完整卡组」「返回标题」「回合结束」等文字被挤压。
- 战斗内地图总览改为浅纸面板，房间材质与主地图一致；记录/故事详情共用 `UiTheme.draw_close()`，设置页开关改为森林绿/浅纸药丸样式，禁卡表与故事列表边框统一为旧黄铜。
- 接手时仅清理两处同值三元表达式，没有继续扩大视觉范围；缺失旧卡图仍按用户要求排除。

## 验证

- `tools/verify_ui_polish.gd` 对三种按钮文字做可用宽度断言，并在受控正式场景截图。
- 已覆盖 1280×720、1920×1080、1024×768；各 10 张：title / settings / gallery / class_pick / map / battle / shop / story / record_list / ban。
- `visual.log`、`visual_hd.log`、`visual_1024.log` 均为 `AUDIT CAPTURE DONE`，无脚本错误。战斗图展示的是战斗中地图总览，记录图展示的是详情浮层。
- 最终 `_verify.py`：mana 通过；engine 5298 / reward 26 / bgm 39 / smoke 64，全部通过。
- 验收是受控场景和上述三种窗口尺寸，不表示逐事件分支人工通关或所有设备比例均已穷举。

## 新增素材

- `assets/ui/adventure_shared/panel_journal_light_hd.png`：1553×947，RGBA；目标角部 34px，源图角部 68px。
- `assets/ui/adventure_shared/service_vitality.png`：1254×1254，RGBA；通过 64px Lanczos 缓存用于商店与附魔图标。
- 两个槽位已登记到 `assets/ui/图片命名说明.txt`；附魔图标映射契约已同步到 `UI设计规范.md`。
