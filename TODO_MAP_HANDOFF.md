# 地图 UI 接手 TODO — 2026-11-04 暂停点

## 当前授权与 Git 状态

用户最后要求：**暂停，只记录 TODO；由另一个 agent 推送，再由另一台电脑接手。**

**2026-11-04 推送已完成。** 全部地图实现已由推送 agent 提交为 `aa1da91`（26 个文件：5 个改动的 .gd + `HANDOFF.md`、新脚本 `map_visual.gd`、新素材与 `.import`、`art_src/2026-11-04_map_ui/` 全部图片与日志、两个 tools 脚本、本文件）并推送到 `main`。本地 HEAD == 远端 `aa1da91`，工作区干净。另一台电脑直接 `git pull` 就能拿到全部代码、素材、工具、截图和日志，不需要再从第一台机器拷任何东西。

推送后**又复跑了一次完整回归**：engine 5298 / reward 26 / bgm 39 / smoke 64 = 5427 全部通过。也就是说第三层全明补丁（`run_state.gd::known_node` 的 `LAYER_THREE` 提前返回 + `verify_map_concept.gd` 的新断言）**没有打坏四套通用回归用例**。下文「验证状态」段落里"补丁前"的记录是补丁时点的历史事实，保留不改。

**仍然没做、下一台必须先做的两件事**：① 跑 `tools/verify_map_concept.gd` 验收第三层全明；② 用新截图覆盖 `art_src/2026-11-04_map_ui/layer3.png`（现在这张仍是补丁前带云的旧图，不能当交付）。

## 用户确定的设计与规则

1. 按 `art_src/2026-11-04_map_concept/concept.png` 落地：浅纸、森林绿皮革、旧黄铜；保留真实地图的房间/通路规则。
2. **右侧不放图例，不加独立道具大面板**。预留两列宽度，道具从第二行右1列开始，先向下、再排左列。
3. 巧克力、完整卡组、设置在顶部第一行。完整卡组保留原功能。
4. 云只遮房间内容，不能让真实通路难辨；所有连接来自 `doors`，不可按生成图复制路线。概念图两角宝箱仅为示意，代码现行右上固定商店应保留。
5. **第三层全明**，所有有效房间都可看见；保持第三层直道、无巧克力消耗，不能出现探索云。
6. 维持战斗内地图总览与地图页一致。CG、战斗数值、地图生成规则不在本轮改造范围。

## 已做但未提交的实现

- `scripts/map_scene.gd`：地图 x 从227移到150，仍118px格、7×5、y94；地图右沿976，为右侧两列留空。顶部巧克力/完整卡组/设置坐标分别约x978/1106/1216（1280画布），y12。标题、首领牌、标记工具按钮换现有素材风格。
- 道具98×26，行步进30，列步进104，首行y56；1280×720时右列x1158、左列x1054，每列21个可见位置。右列填满再左列。超过42件在两列内部滚轮滚动；保持悬停说明、点击完整列表，隐藏行返回屏外零尺寸rect，绘制跳过。无专门面板底。
- `scripts/map_visual.gd` 新增：房间底板和云雾几何共用。未知房间深绿、已知浅纸；云纹理占房间中央60%，桥附近留空。未知房间图标仍根本不绘制，避免内容泄漏。
- `scripts/map_bridge.gd`：新俯视桥素材；ALONG0.40、CROSS0.23、未知桥不再缩小（1.0），未知桥浅色不透明，已走过暖黄、可前往青绿。通路仍从真实doors绘制。
- 地图绘制顺序改为底板→图标→云→桥→状态，桥端不被云盖。
- `scripts/battle_scene.gd`：战斗内地图总览使用同一云几何，桥同样移到云后；未动战斗本身规则。
- `scripts/test_smoke.gd`：旧R407断言“完整卡组必须在首个道具右边”改为“第一行按钮必须在第二行道具上方且不相交”，符合新口径。其余20件道具不重叠/不压固定UI检查保留。
- **最后刚改、未验证**：`scripts/run_state.gd::known_node` 在id合法性检查后增加第三层返回非void房间可见；`tools/verify_map_concept.gd` 增加第三层清空seen_ids后所有有效房间仍known的断言。

## 素材与工具（必须一起带走）

- `assets/ui/adventure_shared/map_forest.png` 与 `.import`：第一层新明亮森林背景；二/三层仍读原层背景。
- `assets/ui/adventure_shared/map_bridge_clear.png` 与 `.import`：新清晰木桥（上下原向，左右旋转90°）。
- `art_src/2026-11-04_map_ui/forest_source.png`、`bridge_source.png`：内置imagegen原始输出。
- `tools/prepare_map_materials.py`：用Pillow复现森林1600×900缩放、透明桥alpha包围盒裁切及128×256内缩放；不是手工临时路径依赖。
- `tools/verify_map_concept.gd`：真实地图场景、隔离测试存档；28件道具截图、更多道具滚轮测试、第三层截图与几何断言。
- 生成提示词见 `art_src/2026-11-04_map_ui/prompts.txt`。

## 验证状态：切勿混淆时间点

最后完整回归在“第三层全明”补丁**之前**：engine5298、reward26、bgm39、smoke64，5427全部通过。日志已复制到 `art_src/2026-11-04_map_ui/last_verified_*.log`，文件名表示补丁前已验证状态，不代表当前HEAD加工作区全部通过。

专用视觉检查此前通过：两列顺序、顶部按钮与地图不重叠、桥/云矩形净空、滚轮溢出、第三层加载。**当时没有断言第三层全明**；用户提醒后检查截图，发现第三层旧known_node仍隐藏远处房间，于是最后补上全明规则，但尚未再次运行。

现有截图：

- `map.png`：最新第一层28件道具、有云。测试道具排除鹰哨6026，否则整图被揭示，无法验云。
- `relic_scroll.png`：大量道具滚轮后。
- **`layer3.png` 是补丁前旧截图，仍有云，不能拿作最终交付！** 下一位必须重跑覆盖，确认全明。
- `visual.log` 是补丁前成功日志；新增第三层断言还没跑。

早期遇到的`Material`类名冲突已修成`PanelMaterial`；R407旧布局断言已更新。不要误把更早失败日志当当前结果。

## 下一位按顺序做

1. `git status -sb`，确认本文件列出的未提交改动，读diff。不要reset/clean。确认所有新素材/工具/source图都带入提交。
2. 优先运行最新 `verify_map_concept.gd`，看新增第三层全明断言；检查新 `layer3.png`：起点/精英/商店/休息/首领全部显示，无巧克力、无迷雾。同时检查战斗内地图总览第三层也全明。
3. 跑 `_verify.py` 完整回归。新增RunState规则可能影响依赖第三层状态的旧视野用例；失败时核对用例是否清理层号，不能简单删断言。
4. 人工检查第一层/第二层/第三层：地图全在可见范围、两列道具不盖地图；按钮第一行、道具第二行；通路清晰且只存在于真实doors；未知房间内容不泄漏；顶部设置/完整卡组/标记工具仍可操作。
5. 检查道具交互：0/1/21/22/42/>42件；右列向下满后转左列；滚轮到两端不越界；滚动后悬停与点击对应正确条目；道具说明不被顶部按钮盖住。现测试为28件和约55件，其他边界建议补充。
6. 视反馈微调视觉：当前未知格框内的浅纸边偏宽，云较小；左侧标记按钮复用宽横幅素材后边角略挤。尚未向用户声称视觉完全定稿。道具区没有大背景板；请保留用户这一点要求。
7. 清理过时注释：map_scene文件头的居中227、旧“桥在云下”、道具无限向地图堆叠说明，map_bridge关于未知桥更小/灰蓝等注释有些尚未更新。`_fog_rand`等旧helper是否还有使用可核查；不要为了清理引入功能变更。
8. 可选性能整理：`_relic_slot_list`目前每次调用重新建数组，`_relic_rect`逐项调用；数量很大时可按尺寸/道具数/scroll_row缓存，保持唯一命中几何。
9. 完成后更新HANDOFF与本TODO、保存最终截图/日志，明确文件列表提交；推送main并检查本地/远端一致和工作区干净，再交另一台电脑。若只先同步WIP，提交消息和交接必须明确“第三层补丁待验证”。

## 本机命令

```powershell
Set-Location D:\work\card_rogue
$env:GODOT_BIN='D:\work\card_godot_demo\Godot.exe'
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -X utf8 _verify.py
# 真实渲染测试不要headless；建议等待进程退出再读图/日志
Start-Process -FilePath D:\work\card_godot_demo\Godot.exe -ArgumentList '--path . --script tools/verify_map_concept.gd --log-file art_src/2026-11-04_map_ui/visual.log' -WindowStyle Hidden -Wait
git -c core.whitespace=cr-at-eol diff --check
```

换电脑请改Godot/Python路径。项目资源路径均为res://或仓库相对路径，不依赖本机generated_images目录。历史本机`_backups/`不属于本轮，不删除、不上传。
