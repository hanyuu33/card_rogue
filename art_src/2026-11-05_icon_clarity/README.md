## 2026-11-05 图标小尺寸清晰度
- 奖励原始大图直接缩到64px时细节采样噪点明显，UiAssets.small_icon增加Lanczos预缩放和缓存；奖励使用64px纹理，地图使用128px纹理。
- 删卡重新生成单独剪刀，无卡牌。地图原素材为64×64，新增9张大轮廓、少细节透明素材 assets/ui/map_icons/，地图页、图例、战斗地图总览通过 node_icon 共用；无素材的首领仍用原文字回退。
- 内置imagegen生成；完整提示词见 art_src/2026-11-05_icon_clarity/prompts.txt。原地图素材保留。
- 实机奖励及地图截图已更新原验证目录；改前对照保存在本目录。原生1280×720下检查64px奖励与约73px地图图标，未声称所有屏幕缩放比例均已验收。
- verify_reward_icons / verify_map_concept 通过；_verify.py：5298+26+39+64=5427 全通过；diff --check通过。
- 本轮本地提交未推送，原未跟踪奖励素材未动。
