## 2026-11-04 奖励分类图标与难度数字框体
- 按用户纠正，从奖励含义独立生成五种透明图标：卡牌三选一、传说卡、道具、删卡、核心；不是改造旧数值徽章。两张误生成盾牌未接入项目。
- 正式 reward_panel_adventure_v2 按 kind/legendary 选择 assets/ui/reward_icons/ 素材；旧奖励样式仍使用原徽章，领取逻辑未修改。
- class_pick_scene：难度数字独立绿底黄铜框，左右箭头使用共享按钮框；保留原命中区域和难度逻辑。
- 实际战斗奖励浮层、角色选择 0/5/10 截图：art_src/2026-11-04_reward_icons/；工具 tools/verify_reward_icons.gd。使用受控奖励数据在正式场景验收，不是通关截图。
- _verify.py：engine 5298 / reward 26 / bgm 39 / smoke 64，5427 全通过。视觉日志无报错。生成工具为内置 imagegen，完整提示词见该目录 prompts.txt。
- 本轮本地提交未推送；原有未跟踪奖励页素材保留。
