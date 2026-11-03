# 冒险手记：共用 UI 第一批

## 已接入
- UiTheme.apply_button：森林布面主按钮、米色次按钮、灰色禁用态；独立悬停亮度、按下压暗、键盘焦点。
- UiTheme.apply_chip：工具栏、页签、卡组/道具入口。小尺寸使用简洁细边与同族配色，避免完整纹饰挤占文字。
- UiTheme.control_theme：由 TopBar 初始化，自动继承到输入框、下拉框、弹出菜单、滚动条、滑块、进度条、默认面板与提示。
- 大弹窗使用蕨叶纸张与灰绿布框，小信息框使用细黄铜线，按高度选择，避免纹饰压住文字。
- 暂停菜单、顶部生命/金币状态栏、卡组浮窗、道具标签、提及提示与轻提示已接入。

## 保留
奖励页 v1/v2 的独立素材、脚本及预览场景保留。本轮开始时的共用脚本位于 before/；此备份包含此前未提交的改动，不等同于 Git HEAD。
页面独有布局、战斗棋盘/专用按钮、卡面与角色场景插画没有在本批重绘。

## 素材
新按钮由内置 image_gen 编辑旧蓝金按钮生成（没有使用 CLI）；原始结果 button_forest_source.png 保留。项目素材 assets/ui/adventure_shared/：button_forest、button_paper、button_disabled、panel_journal。
按用户允许的切取流程裁掉透明余白、缩放到按钮 400×92 / 面板 800×480；旧素材均未覆盖。森林底板复用 reward_adventure_v2/18.png，浅色和禁用按钮复用 reward_layered/03.png 与 04.png。

生成提示词：Edit this single horizontal transparent RPG button. Preserve exact horizontal silhouette, same aspect ratio and thin border width, empty center for Chinese text. Replace royal navy and ornamental gold with dark moss forest green woven cloth and simple muted antique brass trim; small understated leaf notches at left and right, remove fleur-de-lis and court scrollwork. Japanese illustrated Western medieval fantasy adventurer journal style, subtle hand painted texture, restrained and practical, no text no numbers, no glow. Center must be evenly dark and legible. Transparent outside. This is a scalable reusable game button, straight unobstructed central area.

## 验证
- 通用控件预览 scenes/adventure_ui_preview.tscn：实机截图，检查主题继承、按钮材质、禁用态及菜单打开暂停 / 关闭恢复。
- 主菜单 title、图鉴 gallery、战斗暂停菜单：实机截图检查。
- test_smoke.gd：64 通过 / 0 失败，完整日志 smoke.log。烟测 stderr 含直接调用绘制函数时的 Drawing is only allowed 诊断和锚点警告；实机 gallery、menu、控件预览无脚本错误。title 截图退出时报告 2 resources still in use，未影响页面显示，保留为后续排查项。

预览命令：Godot.exe --path D:/work/card_rogue res://scenes/adventure_ui_preview.tscn -- --screenshot
