# 全游戏冒险风 UI · 2026-11-03

## 风格与范围
米色纸张、浅鼠尾草布面、森林绿与旧黄铜点缀；日系西方古代幻想，弱化宫廷纹章。奖励页保留较深的独立变体，其余页面不强制跟随深色。

13 个现行正式场景均通过游戏引擎截图检查（截图参数提供场景所需的数据，不是另外搭建的 UI）。卡组选取额外用 `--edit vendor --editpick 3` 检查有牌状态；reward.png 来自 battle.tscn 的真实奖励覆盖层。

| 页面 | 本批修改/继承 |
|---|---|
| 主菜单、图鉴 | 继承通用按钮、表单与面板；保留原插画、卡牌与筛选流程 |
| 选角 | 明亮角色说明纸面、头像姓名牌、种子输入框、确认按钮；保留难度与职业机制 |
| 地图 | 减轻场景压暗、纸色/绿格、森林色 HUD；真实圆形头像 HUD 已检查 |
| 战斗 | 材质化回合结束大按钮、浅色关卡铭牌、共用菜单/浮窗；不改拖牌/点击判定 |
| 事件 | 独立浅色阅读面板、底部安全余量、明亮缺图回退；休息处新增林间篝火背景 |
| 商店 | 纸色商品板、统一标题/离开/说明条；保留猫商人、货架、买卖逻辑 |
| 起点道具 | 走 curtain.tscn 的现有 CG 事件，仅按钮继承新样式；旧 relic_pick 不作为现行页面改造 |
| 卡组编辑 | 继承纸面与按钮，检查实际 vendor 选卡状态 |
| 设置 | 浅色设置行、细边控件、统一返回按钮 |
| 故事、记录、禁卡 | 纸面/文字对比度、统一返回操作；保留列表与滚动 |
| 开场过场 | 保留原 CG、对话框、时序和三选一布局，只更换按钮样式 |
| 奖励覆盖层 | 正式 attach 默认使用 Adventure v2；原版通过 --legacy-rewards 保留 |

## 复用与版本
- draw_action / draw_info_card 收口自绘控件材质，原点击矩形不变。
- RewardPanel 的布局由纯函数 cards_layout_for_viewport 提供，实例绘制和测试共同使用。
- removed tools/restyle_pages.py：一次性旧迁移脚本已失效，移除避免接手者误运行覆盖新样式。
- 旧素材与原奖励页快照保持；没有增加第二个正式游戏入口。两个 preview 场景明确仅用于开发，不充当正式页面截图。

## 新素材与提示词
使用内置 image_gen，未使用 CLI；最终项目素材位于 assets/ui/adventure_shared/。
1. panel_journal_light.png：编辑旧 reward_adventure_v2/18.png，裁透明余白、缩放到 800×480；源图 panel_bright_source.png。
提示词：Edit this reusable game UI panel keeping the exact rectangular outline, full blank center and transparent outside. Make a brighter airy Japanese illustrated Western medieval fantasy adventurer journal version: ivory linen and pale sage green fabric edging instead of dark forest green, narrow antique brass trim, tiny leaf/compass details confined to corners. Remove large watermark and keep almost all center evenly bright cream for dark text. Warm natural daylight palette. Restrained practical adventurer equipment, no royal heraldry, no crowns, no baroque ornament, no words or numbers. Preserve alpha transparency outside; no drop shadows beyond a small soft edge. Intended for real game menus and windows.
2. rest_clearing.png：新生成休息处背景，旧背景未覆盖。
提示词：A polished 16:9 background illustration for a Japanese anime styled Western medieval fantasy card roguelike rest event. Warm forest clearing at late afternoon, painterly soft linework, mossy stones, a modest campfire near the upper center around one quarter from the top, a rolled travel blanket and simple kettle beside it, delicate leafy trees framing sides, shafts of golden daylight, inviting adventurous mood. No characters, no words, no UI, no borders, no cards, no icons. The lower half is quiet low detail pale grassy ground so an ivory UI panel can overlay it without fighting busy details. Natural sage green, cream, honey amber and muted earth colors, bright and readable, no palace architecture, no royal symbols. Full bleed landscape.

## 验证
命令：`GODOT_BIN=<Godot.exe> python -X utf8 _verify.py`（Windows 默认 GBK 无法输出测试摘要的勾号，显式 UTF-8）。
结果：engine 5298 / reward 26 / bgm 39 / smoke 64，全部通过，合计 5427 个断言/用例。
本批更新了已过时的视觉源码锁：从旧手画品质框/横幅字符串改为真实素材像素可读性和 1280×720、1600×900 的布局边界检查；回合结束输入接线检查兼容 LF/CRLF，没有移除输入逻辑验证。
各页面日志与截图同目录。headless 音频退出噪音及烟测直接调用绘制的诊断仍会出现；验证脚本已辨别脚本错误并全部通过。没有把截图检查当作全部事件分支人工通关。
