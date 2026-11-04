# 地图 UI 实现素材 / 暂停检查点

当前详细状态与下一步见仓库根 `TODO_MAP_HANDOFF.md`。用户已要求暂停，由另一个agent提交推送。

本目录素材使用内置imagegen生成，提示词见prompts.txt；裁切/缩放脚本为tools/prepare_map_materials.py。正式消耗文件在assets/ui/adventure_shared/，无需原机器generated_images路径。

map.png/relic_scroll.png为真实场景注入道具后的截图。**layer3.png与visual.log来自第三层全明补丁之前，第三层截图仍有云，必须重跑更新，不能作为验收图。** last_verified日志为补丁之前5427项通过的完整回归记录。
