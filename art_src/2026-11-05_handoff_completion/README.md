# UI 待办收尾

法力素材：assets/ui/adventure_shared/battle_mana_meter.png；数值由 BattleEnergyHud 绘制。
`_verify.py` 已接入 headless 法力布局验证，真实截图运行 tools/verify_battle_mana.gd。
覆盖 0/5/6/7/12/99/125，125 仅排版压测，不代表真实费用上限。
关闭按钮参考现有 button_forest.png，通过内置 imagegen 生成透明圆形按钮；游戏使用64px Lanczos缓存缩图，绘制30px，命中仍唯一使用 _detail_close_rect。
提示词：Create one small game UI close button, transparent background. Reference image is style only: match its dark forest-green textured leather and thin aged brass double border. A simple circular medallion with a large cream/brass X at center, crisp thick diagonal strokes legible at 30 pixels. Front view, flat UI, no ornate palace motifs, no shadows outside silhouette, no text, one button centered filling image. Output PNG to use in a Japanese western fantasy parchment UI.

## 2026-11-05 本轮收尾（优先于以下历史待办）
- 缺失卡图按用户要求排除，不改动。
- 故事关闭按钮完成：参考共享绿色黄铜按钮生成 close_forest.png，保持唯一命中矩形与原CG布局。故事详情在1280×720、1024×768、1600×900检查并测试关闭；记录页补截图。
- 法力专项已接入 _verify.py，真实战斗0/5/6/7/12/99/125截图、布局断言通过；素材登记及README补齐。125仅压力测试，不表示真实费用上限。
- 地图0/1/21/22/42/55件数量边界、两列不重叠/不遮固定UI、滚轮两端饱和、点击完整列表通过。三层截图与战斗内第三层全明已检查；修复地图总览上叠加回合横幅。
- 已核实关卡文字与回合横幅传-1禁描边；横幅此前已使用共享素材，不重复改造。清理道具栏过时说明。
- 完整回归：engine5298/reward26/bgm39/smoke64及新增mana均通过；随后烟测绘制调用修正单独复跑64/0。绘制报错来自测试直接调用draw API，现改为draw信号回调，复跑无此报错。
- 标题真实截图退出无资源警告；headless烟测仍有音频退出资源告警，属于已知引擎边界，不宣称消除。验证日志见 art_src/2026-11-05_handoff_completion/。
- 验收范围是受控正式场景及上述尺寸，不是逐分支人工通关或所有设备穷举。可选缓存优化暂不需要；保持现有布局，不另造平行组件。
- 本轮本地提交，未推送。实现及截图由同一阶段提交保留。
