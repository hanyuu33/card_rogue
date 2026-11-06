## 2026-11-07 R515 事件插图第二批（delivery / arcane / lake_lady）（当前最新）

- 用户口径：从「第一层权重前六」里挑了 `delivery` / `arcane` / `lake_lady` 三张先做。
  `whisper` 已在 R514 并入二层起点池、`struggle` 暂不生成 → 这两张不做。
- 产出（3 张插图，无背景）：`assets/ui/event_delivery.png` / `event_arcane.png` /
  `event_lake_lady.png`，**640 × 480（4:3，2× 素材）**，与 `event_gaze` 同规格。
- 画面：`delivery` = 苔石台上一排木箱／麻袋／卷包 + 半截手推车，暖午后、无人物；
  `arcane` = 林中石砌泉池、泉眼泛青光 + 枝上悬挂蓝宝石护符；
  `lake_lady` = 蓝调黄昏湖面伸出一只手、同心涟漪、水下模糊人影倒影、芦苇与浮花。
- 只做插图**不做整屏背景**：三张在默认纸底上实测不吃字、不抢按钮（截图见
  `art_src/2026-11-07_事件插图R515/_review/`）。
- 流水线（`art_src/2026-11-07_事件插图R515/tools/`）：
  - `process_r515.py`：后端默认水印「AI生成 WORKBUDDY」固定在右下 y≈728~760 →
    **统一保留到 y=706**（不逐张检测：`lake_lady` 的白色花瓣会把检测顶到 673，多切 39px），
    再居中裁 4:3 → resize 640×480（LANCZOS）→ UnsharpMask(1.2/55/2) 补锐度。
  - 提示词沿用 `art_src/_style_prompts.md` A 套（日式动漫赛璐璐），显式写死
    `NO border / NO frame / NO letterbox / NO black bars`——AI 仍会在底部塞纯色带（R512 的坑）。
  - `shoot_r515.py`：`res://scenes/event.tscn -- <kind> --screenshot`，三张 4~5 秒出图。
- 顺带：新图跑过一次 `godot --headless --import`，三张 `.import` 已入版本库
  （`UiAssets` 虽有「导入失败就直读原始 PNG」的兜底，但项目里其余素材都带 `.import`，保持一致）。
- 文档：`assets/ui/图片命名说明.txt` 三行标 ★R515；`UI设计规范.md` 插图节改写为
  「已提供插图 4 张」+ R515 出图口径。
- **待出图（剩 8 种）**：一层 `martial`(人类老者/无烟斗限制不适用) / `oblivion` / `snow_leopard`(不画烟斗) /
  `adventurer` / `smith`；二层 `apple_doctor`；特殊 `relic_chest`（大宝箱房必现）/ `delivery_done`（可与 delivery 共用）。
  R512 暂缓仍挂着的：`pear` / `hero` / `bluefish`。

## 2026-11-06 R514 鸭鸭低语并入二层起点三选一 + 事件池收敛

- 用户口径（逐条）：`struggle`（挣扎）**标记暂不生成**；`whisper`（鸭鸭低语）**改为第二层初始事件
  （起点「卷卷三选一」）的一个选项，不再单独作为事件**；`martial`（武术大师）**是人类**，不是鸭；
  `snow_leopard`（雪豹出现）出图**不需要烟斗**。
- 落地（代码两处）：
  - `game_layers.LAYERS[1].events` 删 `"whisper": 27` → 第一层事件池 **11 → 10 种**。
    `event_scene` 的 whisper 分支**保留**，只服务旧存档 / `--whisper` 演示（与 R512 的 treasure 同口径）。
  - `RelicRepo.layer2_ids()` 加 `6010` → 二层起始池 **7 → 8 件**。`RunState._roll_relic_choice()`
    本来就是「从池里随机抽 3 件不重复」，所以**仍是三选一**，鸭之低语每局约 3/8 概率出现、不是必出
    （用户口径「随机池新增一件，仍然三选一」）。
  - `6010` 是**双池特例**：它同时留在 `event_ids()` 里（事件道具分类、旧存档、图鉴都不变），
    所以 `test_engine` 的「二层起始池不与初始/奖励/事件池重叠」断言为它开了显式例外。
- `martial` 无需改代码：文案本来就是「树底下坐着一位老人」，只是把「人类」写进出口径文档。
- 断言同步（4 处）：第一层池 6549 / 20310 两处 `11 → 10`（20310 由「11 种」改「10 种」）；
  二层起始池 7646 `7 → 8`（新增 6010）、20598 `7 → 8`；`seen_kinds` 里 whisper 由「必须出现」
  改成「必须不出现」；重叠判定跳过 6010。
- 文档：`assets/ui/图片命名说明.txt`（whisper 不做图 / struggle 暂不生成 / martial 人类 / 雪豹无烟斗，
  插图与背景两段都标）、`UI设计规范.md` 事件插图节加「R514 口径（出图前必读）」。
- 回归：`_verify.py` 全通过 —— mana PASS / engine **5236** / reward 26 / bgm 39 / smoke 64。

## 2026-11-06 R512 事件素材第一批 + 宝箱事件退场

- 用户口径（逐条）：`hero` / `struggle` / `pear` / `bluefish` **暂缓不做**；**宝箱从事件中移除**；
  赏月 = 月夜天空下画架上的月夜写生；鸭之凝视 = 黑暗中恶魔鸭两只眼盯着你 + 分层明暗；
  熔炉 = 机械里红热的炉子；洞穴 / 卡片商人按前案；契约的核心 = **契约文刻在石台上**，
  且**核心的标志已有素材**（不重画，复用 `reward_icons/core.png`）；其余事件本轮不生成。
- **宝箱退场**：`game_layers.LAYERS[1].events` 删 `"treasure": 31`，`roll_event_kind()` 的三处
  兜底 `return "treasure"` 改 `return ""`（调用方 `_make_cells` 本就把空串降级成普通战斗）。
  `event_scene` 的 treasure 分支保留，只服务旧存档 / `--treasure` 演示。
  第一层事件池 12 → **11 种**（第二层本来就是 14 种，不含 treasure）。
- **顺手修 bug**：`martial`（武术大师 R473）**一直没进 `_kind()`**，落到末尾 `return "rest"`
  → 房间里点亮休息处的篝火 + 铺休息处空地背景 + 暖橙主题色。现在补 `_kind()` 分支、
  主题色归「交易 / 匠人」金。
- **6 张素材**（详细过程见 `art_src/2026-11-06_事件插图R512/README.md`）：
  `bg_moon` / `bg_furnace` / `bg_cave` / `bg_card_merchant` / `bg_core_contract`（1280×720）
  + `event_gaze`（640×480，2× 基准 320×240，四边羽化）。
- **契约的核心**：底图的石台中央**故意留成空凹槽**（圆心 648,406，外沿 363×118 透视椭圆），
  核心本体由 `event_scene._make_core_icon()` 叠 `reward_icons/core.png`
  （常量 `CORE_ICON_CX/CY/SIZE = 648/350/200`，与占卜球同一套 KEEP_ASPECT_COVERED 重算）；
  取走核心（`_core_pick == "core"` 或已有道具）后隐掉 —— 对应文案「只剩一圈浅浅的凹痕」。
- **两个潜伏坑（`event_*.png` 一张都没有时一直是死代码，本轮首爆）**：
  ① `TextureRect` 默认 `EXPAND_KEEP_SIZE` 会把 320×240 的框顶成贴图原生 640×480 → 图位移 + 溢出；
  ② `add_child` 是「加到最上层」→ 插图盖住文案与按钮。修法 `EXPAND_IGNORE_SIZE` + `move_child(tr, 1)`，
  两条都进了 `check_src` 断言。
- 回归 `_verify.py` 全通过：mana PASS / engine **5228**（+12 条 R512 断言）/ reward 26 / bgm 39 / smoke 64。
- 六态截图已核验（`--moon` / `--furnace` / `--cave` / `--cardmerchant` / `--corecontract` / `--gaze`）。
- **下一步（R514 起）**：剔除项 = `whisper`（已不是独立事件）/ `struggle`（暂不生成）/
  `treasure`（已下线）/ `rest`（内置篝火）；`hero` / `pear` / `bluefish` 仍是 R512 暂缓。
  第一层待出图：`delivery` / `arcane` / `martial`（**人类老者**）/ `lake_lady` / `oblivion` /
  `snow_leopard`（**不画烟斗**）/ `adventurer` / `smith`；第二层待出图：`apple_doctor`；
  特殊：`relic_chest`（大宝箱房必现）、`delivery_done`（可与 delivery 共用）。

## 2026-11-06 R510 削弱火墙术 + APK 出包（当前最新）
- 用户口径：「削弱火墙术：基础伤害和基础单体伤害上限都调整到 14 点，延迟伤害下调到 7 点。之后打包 APK」
- 落地：`FIRE_WALL_DMG 15→14`、`FIRE_WALL_CAP 15→14`、`FIRE_WALL_PASS_DMG 8→7`；`SPELL_BASE_DMG[9084] 15→14`（R348「表 == 卡面首个 N 点伤害」口径）；cards.json 卡面文案同步 14 / 7 / 14。
- **语义后果（不是 bug）**：上限 == 即时之后，「开场就站在这行」的单位一次吃满 14、之后再穿过不再追加；开场不在、后来走进去的先吃 7，还能再穿一次补到 14。R387 的「上限 = CAP + 即时伤害增量」公式没动，附魔 +10 → 即时 24 / 经过 17 / 上限 24（R387 断言已同步）。
- 顺手：`battle_scene` 的 `--fire` 演示文案改成读常量（旧文案写死 15 / 10，那个 10 早就和 8 脱节）；`_cardtable.py` 重生成 `release/卡牌总表_R506.md/.html`。
- 回归：`_verify.py` 全通过 —— mana PASS / engine **5208** / reward 26 / bgm 39 / smoke 64。
- 出包：`dist/DuckCardsRogue_R510.apk`，203,883,963 B（194.4 MB），md5 `d0ddbe0d42ff07e7309c8cf41a2fe780`；v1/v2/v3 全 true / 1 signer；包内 `cards.json`(160,255 B) / `relics.json`(15,551 B) / `stories.json`(3,035 B) 与工作区逐字节一致、卡 296 张、9084 卡面已是 14 / 7 / 14、垃圾条目 0。出包前清 `.godot/imported` 孤儿缓存 214 个文件（39.8 MB，全是源图早删的废弃版本图）。本轮**没有**重出桌面包（`dist/DuckCardsRogue.exe` 仍是旧的）。
- 提交：`c769dc4`（数值 + 断言 + 卡表）、`7c3ba87`（两处测试注释 15→14），文档提交随后。APK 不入库。
## 2026-11-05 商店货架重做（R508 · 当前最新）
- 用户报的四件事全部落地：①「神秘商店」标题框不再被卡牌压住 ②左上角生命条不再压卡牌
  ③第一行整行收到 y=100、行距 10→8 ④货架素材重做，去掉护栏、加后挡板。
- 「上一轮只做了一半」的根因：`_draw_shelves()` 改成读 `UiAssets.get_tex("shelf_open")`，
  而 `shelf_open.png` **从来没有生成过** → 一路走缺图回退，画出「深棕横条 + 两端 8px 竖撑」，
  这就是用户口中的"护栏"。现在拆成 `_draw_shelf_backs()`（后挡板，画在商品之前）+
  `_draw_shelf_boards()`（层板，画在商品之后，板下 9 条渐隐横带当投影）。
- 新素材 `shelf_board.png`（1070×32，从旧 shelf.png 裁真实横板，两端 alpha 淡出）+
  `shelf_back.png`（512×176 程序化竖木纹背板，左右 10px alpha 渐隐）。
  旧 `assets/ui/shelf.png` 已归档为 `art_src/2026-11-05_商店货架/source_shelf.png` 并从
  assets/ui 删除（游戏代码不再引用，留着只是多 1.6MB 包体）。复现：`python tools/gen_shelf_textures.py`。
- 顺带修掉的两处：`_goods_icon_box()` 收成图标几何唯一口（绘制 / 悬浮详情共用）；商店图标纹理
  64 → 96px（实际画到 84~120px，64 是被放大在用）。
- 新门禁 `tools/verify_shop_shelf.gd`（三分辨率布局断言 + 截图，输出 `SHOP SHELF PASS`，
  **断言读 `scene.size` 逻辑尺寸，不是 root.size 物理窗口**）；`verify_shop_popup.gd` 仍 PASS。
- `_verify.py` 全通过：mana / engine **5298** / reward **26** / bgm **39** / smoke **64**。
  engine 的 R481 源码锁下界从 `func _draw_shelves()` 改为 `func _draw_shelf_backs()`。
- 细节、截图清单与边界见 `art_src/2026-11-05_商店货架/README.md`。

## 2026-11-05 UI polish 接手收尾（当前最新）
- 另一 agent 留下的未提交 UI 统一批次已完成验收并收尾：高清浅纸面板九宫格、卡面/徽章 Lanczos 分桶缓存、商店与附魔图标统一、 compact 按钮自适应、战斗地图总览浅纸化、记录/故事关闭按钮共用、设置开关与列表边框统一。
- 新增素材 `panel_journal_light_hd.png` 与 `service_vitality.png` 已登记；附魔图标实际映射已同步 `UI设计规范.md`。实现、三种分辨率截图与验证说明见 `art_src/2026-11-05_ui_polish/README.md`。
- 接手后只清理两处同值三元表达式，没有扩大视觉改动；缺失旧卡图继续按用户要求排除，CG 布局与命中区域未改。
- 最终 `_verify.py`：mana 通过；engine 5298 / reward 26 / bgm 39 / smoke 64，全部通过。截图覆盖 1280×720、1920×1080、1024×768，日志无脚本错误；不宣称逐分支人工通关。
- 提交与推送状态以 git log 和远端 main 为准；本机此前 `4420fa2`、`e82db9f` 两条交接收尾提交也应随本次一起推送。

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

## 2026-11-05 接手审计（当前状态，优先于历史暂停记录）
- 当前用户已授权继续工作；历史“暂停/只记录”不是现行限制。
- Git 起点为 84304e9，main 与本地 origin/main 跟踪引用一致，工作区干净；未联网核验远端。
- 已完成：地图实现 aa1da91、第三层全明复验 8bdb4a0、R367 修复 f32dbcd、奖励分类图标 21096da、小尺寸图标 84304e9。旧文中“第三层截图未更新”“R367 尚未定位”“地图未提交”均已过期。
- 待完成：故事详情关闭按钮素材；战斗法力 HUD 专项门禁/文档登记；缺失旧卡图；地图战斗总览及道具 0/1/21/22/42/>42 数量边界、滚动后交互人工验收；非常规分辨率检查。
- 待核实：关卡提示去描边是否已全面完成；历史 Drawing is only allowed 和退出资源提示是否仍可复现。
- 美术约束继续沿用浅纸、森林绿、旧黄铜；优先原素材裁切，缺素材时参考现有风格生成。CG 与正式 curtain 布局保留。
- 本次仅完成交接审计与状态更新。尝试追加边界验证时系统 python 别名不可用，脚本未改；已启动现有地图验证，结果需查 visual.log，不作为新增边界验证通过的证据。
## 2026-11-05 图标小尺寸清晰度
- 奖励原始大图直接缩到64px时细节采样噪点明显，UiAssets.small_icon增加Lanczos预缩放和缓存；奖励使用64px纹理，地图使用128px纹理。
- 删卡重新生成单独剪刀，无卡牌。地图原素材为64×64，新增9张大轮廓、少细节透明素材 assets/ui/map_icons/，地图页、图例、战斗地图总览通过 node_icon 共用；无素材的首领仍用原文字回退。
- 内置imagegen生成；完整提示词见 art_src/2026-11-05_icon_clarity/prompts.txt。原地图素材保留。
- 实机奖励及地图截图已更新原验证目录；改前对照保存在本目录。原生1280×720下检查64px奖励与约73px地图图标，未声称所有屏幕缩放比例均已验收。
- verify_reward_icons / verify_map_concept 通过；_verify.py：5298+26+39+64=5427 全通过；diff --check通过。
- 本轮本地提交未推送，原未跟踪奖励素材未动。
## 2026-11-04 奖励分类图标与难度数字框体
- 按用户纠正，从奖励含义独立生成五种透明图标：卡牌三选一、传说卡、道具、删卡、核心；不是改造旧数值徽章。两张误生成盾牌未接入项目。
- 正式 reward_panel_adventure_v2 按 kind/legendary 选择 assets/ui/reward_icons/ 素材；旧奖励样式仍使用原徽章，领取逻辑未修改。
- class_pick_scene：难度数字独立绿底黄铜框，左右箭头使用共享按钮框；保留原命中区域和难度逻辑。
- 实际战斗奖励浮层、角色选择 0/5/10 截图：art_src/2026-11-04_reward_icons/；工具 tools/verify_reward_icons.gd。使用受控奖励数据在正式场景验收，不是通关截图。
- _verify.py：engine 5298 / reward 26 / bgm 39 / smoke 64，5427 全通过。视觉日志无报错。生成工具为内置 imagegen，完整提示词见该目录 prompts.txt。
- 本轮本地提交未推送；原有未跟踪奖励页素材保留。
## 2026-11-04 R367 烟测失败已修复
- 根因：本机 run_records 已达 KEEP=100，新增会淘汰旧记录；旧断言要求数量 +1，产生误报，游戏写入逻辑无需修改。
- scripts/test_smoke.gd：检查保留上限、旧记录顺序、新败北内容与两次调用的完整结果一致；补充 pending 文件备份恢复。
- 验证：python -X utf8 _verify.py：engine 5298 / reward 26 / bgm 39 / smoke 64，5427 全通过；git diff --check 通过。
- 本轮本地提交，未推送；原有未跟踪奖励页素材未修改。地图其他人工验收待办仍保留。
## 2026-11-04 换机接手验证（E:/work）
- 已重建 Godot 4.3 素材导入缓存，重跑 verify_map_concept.gd，MAP UI PASS。
- 已更新 map/relic_scroll/layer3 截图；目视确认第三层五个房间全明、无探索雾、无巧克力控件。
- 本机完整回归：engine 5298、reward 26、bgm 39 通过；smoke 64 通过 / 1 失败：R367 失败记录调两次新增 0 条（预期 1）。尚未定位，不得称完整回归通过。
- 待继续：定位 R367 的记录状态/写入问题；战斗地图总览与其他道具边界人工验收尚未完成。
- 原有未跟踪奖励页素材保留，未加入本轮提交。此次仅本地提交，未推送。
# UI 改造交接（2026-11-03）

## 最新暂停点：2026-11-04 地图实现尚未提交

用户要求暂停，只记录TODO，由另一个agent推送并转另一台电脑。**先读根目录 `TODO_MAP_HANDOFF.md`**：完整列出当前文件、素材、验证时间点、接手步骤与命令。**推送已完成**：地图实现已提交为 `aa1da91` 并推到 `main`（远端此前为 b84a2ab，只有概念图），本地/远端一致、工作区干净；推送后复跑完整回归 5427 项全通过，但第三层全明的专用视觉验收与 `layer3.png` 截图仍未更新。

地图两列道具/顶部第一行控件/新地形材质/清晰桥与内缩云已做，补丁前5427项回归通过。最后新增第三层known_node全明规则及断言尚未跑；现有layer3截图仍是旧有云图，必须更新后再交付。以本节为准，后文旧状态仅历史记录。

## 最新进度：2026-11-04 概念图确认后落地

用户已要求按概念图修改战场/卡框。已替换战场素材外框、战斗内卡牌材质和姓名牌；保留现有卡图/数值/稀有度/附魔。战场格子和滚动逻辑保持。结束按钮无副文案、HP单行、无敌方手牌；上方明确“完整卡组”，右下明确“抽牌库”。真实入口验证分别打开4张构筑和1张剩余牌，详见 `art_src/2026-11-04_battle_instruments/README.md` 和对应截图。先前暂停状态已结束，以此节为准。

## 最新：2026-11-04 战斗 UI

后续微调：效果图 34×34、粗框44×44；×N/余N 移至右侧、无底色，双方共用。原点击/悬停仍按整行命中，浏览大卡角标未改。真实场景截图与验证见 `art_src/2026-11-04_effect_strip/`，复现脚本 `tools/verify_effect_strip.gd`。

用户已授权继续实施战斗 UI（覆盖此前“只记录”在战斗部分的限制）。已调整双方 HP、手牌提示、效果缩略图栏、回合横幅与三层地形。第一层桥按中列 1/3 宽裁切；第二层按纠正取消桥、改机械地板与压格界接缝；第三层甲板/云海。保留原逻辑格子、滚动、选目标高亮、效果悬停/展开/拖放。

源图、素材几何、生成提示词、真实场景截图、验证方式：`art_src/2026-11-04_battle_ui/README.md`。专用截图/槽位断言：`tools/verify_battle_style.gd`；裁切可由 `tools/prepare_battle_terrain.py` 重现。
本轮回归 engine 5298 / reward 26 / bgm 39 / smoke 64 全部通过。仍需用户视觉反馈；未逐关人工通关。旧卡图缺失仍以卡名回退；故事 X 素材仍待办，CG 页面未动。此节优先于下方历史待办状态。

## 当前任务
统一全游戏 UI。共享控件第一批已落地；接下来扩大到真实游戏场景的专用布局/材质，允许更明亮的配色。

## 已有工作
- UiTheme：共享按钮、标签、面板、表单主题；TopBar：生命/金币与可复用圆形头像。
- 暂停菜单、卡组/道具浮窗、提及提示、轻提示接入。
- reward_panel.gd：原分层素材奖励页；reward_panel_adventure_v2.gd：保留式冒险风变体，本批正式 attach 默认切到 v2（--legacy-rewards 可看原版）。
- adventure_ui_preview.tscn 与 reward_adventure_preview.tscn 是开发预览，不是正常流程页面。
- 原始素材、截图、改动前副本与生成提示词位于 art_src/2026-11-03_*。

## 验证
共享改造：test_smoke.gd 64 通过 / 0 失败；主菜单、图鉴、暂停菜单真实场景已截图。圆形头像已在开发预览验证，本批已在真实地图场景验证。
烟测会打印直接调用绘制函数的 Drawing is only allowed 诊断；title 截图退出有资源未释放提示，详见共享 UI README，尚未定位。

## 仓库边界
_backups/ 在本会话开始前就存在，不属于本轮成果；作为本机备份通过 .git/info/exclude 排除，不提交、不删除。
本批已覆盖13个现行正式场景的截图，细分分支依靠5427项自动验证，未声称逐个事件分支人工通关。不要把开发预览的通过等同于所有游戏交互已验证。

## 下一步
主场景统一已完成。后续细化需按用户反馈做小范围调整；保持现有CG事件布局；逐个特殊事件分支和非常规分辨率仍需按需人工体验，避免为统一而改写已有完成度较高的界面。

## 本批完成（共享之后的全页面统一）
共享阶段提交并推送：424b142。当前批统一正式场景、切换正式奖励入口到 v2、加入浅布面底板和林间篝火背景，删除过时一次性迁移工具。详细变更、素材提示词、截图和日志：art_src/2026-11-03_full_adventure_ui/README.md。
自动回归：5298 engine、26 reward、39 bgm、64 smoke，全部通过。
运行环境：Windows PowerShell，Python 需 `-X utf8`；Godot 路径 D:/work/card_godot_demo/Godot.exe。
当前批提交将使用说明性提交消息；完成推送后以 git log 和远端 main 哈希为准。

## 用户纠正：CG 起始事件
起始道具三选一正式路由一直为 map -> curtain（有CG），未改成 relic_pick。之前将旧 relic_pick 纳入截图展示与样式修改不当，现恢复其原始脚本；curtain 的对话框额外覆盖也已移除，只继承共用按钮新样式。后续不得拿旧页面当正式流程。

## 待办交接（2026-11-03 20:12 本机记录，均未开工）

用户口述的下一批 UI 修整，**只记录、不动手**，按下列顺序做：

### 1. 关卡提示去掉字体描边
战斗里所有居中/左上文字默认都吃自动描边：`battle_scene.gd::_auto_outline(px)`（约 8865 行）
= `clampi(int(round(px / 4.0)), 2, 5)`，由 `_draw_string_center()` / `_draw_string_nw()` 在
`outline == 0` 时自动套用（`_draw_string_box_center` 也走 `_draw_string_center`）。
「明确不描边」的既有口径（R309）是 **outline 传负数** → 函数内归 0。
做法：只在关卡提示那几处调用点传 `-1`，**不要**把 `_auto_outline` 全局改成 0 ——
卡牌名、飘字、单位徽标还靠这圈描边压在花背景上，一改全糊。

### 2. 回合切换提示要重做
现实现 `battle_scene.gd::_draw_banner()`（约 16077 行）：300×60 白底 0.72 透明矩形 + 2px 彩色描边
+ `UI_FS_HEADING` 大字，alpha 淡入 → 停留 → 上浮 18px 淡出；数据在 `_banner = {text, col, start, dur}`。
用户口径是「目前不好看」，需要重新设计（建议往新亮色 UI 靠：素材带 / 图形化 / 少描边），
不是调颜色。注意：`_banner = {}` 在十几处出图分支里被手动清场（1403 / 3043 / 3070 / 3474 /
3493 / 3518 / 3553 / 3579 / 3913 …），重构结构时别把这些清场点漏掉。

### 3. 故事界面「×」关闭按钮要素材
`story_scene.gd::_draw_detail()` 里用 `draw_string(_font_bold, …, "×")` 画（约 490~493 行），
命中区是 `_detail_close_rect()`（约 194 行）。需要一张自己的关闭按钮素材（圆形 / 盾形，
与新亮色 UI 同色系），接入后 `_detail_close_rect()` 必须仍然是唯一命中矩形，
`_draw()` 与 `_input` 两处都读它，别另起一套坐标。

## 本机未完成 / 已知问题（接手前先看）

- **战斗法力面板（R507，本机已提交 `2475e14`）**：`scripts/battle_energy_hud.gd` 把费用数字 / 蓄力层数 /
  闪躲提示从 `battle_scene.gd::_draw_cost_zone()` 抽成独立自绘 HUD，底图是
  `assets/ui/adventure_shared/battle_mana_meter.png`；`battle_scene` 只负责传
  `_roll("energy", state.energy)` 与 `engine.max_energy()`。已用 `tools/verify_battle_mana.gd`
  跑过 0 / 5 / 125 三档 + 蓄力 + 闪躲，真实战斗场景截图在 `art_src/2026-11-03_battle_mana/`
  （`mana_verify.log` = `MANA HUD PASS`，errors 日志为空）。**尚未完成的四件事**：
  1. `tools/verify_battle_mana.gd` 是独立 SceneTree 脚本，**没接进 `_verify.py`**，四套门禁跑不到它；
  2. 只有一条源码锁（X/Y 分母来源，`test_engine.gd` 的 R507 那条），没有 smoke 级断言；
  3. `README` / `玩法说明.txt` / `图片命名说明.txt` 都还没登记 `battle_mana_meter.png`；
  4. 125 是脚本里强塞的极端值，真实上限 5~7；多位数排版只在 15px 小字下压测过，不够细。
- `record_list_scene.gd` / `story_scene.gd` 剩下的硬编码色改 `UiTheme`（`PAGE_MUTED` /
  `ADVENTURE_INPUT` / `draw_panel_bg`）：功能无风险，但**没有为这两处单独补截图**。
- 老卡卡图缺失：`协同攻击`、`快速出击`、`自愈`(9102) 等，卡图区显示半透明绿占位
  （R506 出图时发现，一直没处理）。
- 烟测里的 `Drawing is only allowed` 诊断、title 截图退出时资源未释放提示 —— 上一批就留着，仍未定位。

## 2026-11-04 最新暂停点：先审完整概念图
用户要求暂停实现，先看 art_src/2026-11-04_battle_instruments/concept.png 再决定。此图为生成提案，不是实机；最新口径为HP单行、结束按钮无副文案、无敌方手牌。暂停前九宫格材质/道具三列/按钮左移的代码保存为WIP。engine/reward/bgm通过；smoke 64通过2失败（满手横向界限、按钮高度旧断言），尚未处理。详见该目录README，后续先等用户反馈。

## 2026-11-04 地图概念图（仅图稿）
沿用战斗材质生成 art_src/2026-11-04_map_concept/concept.png；核心为云雾内缩、格边连接带、清晰桥面和状态区分。地图代码未改；7×5布局保留。图中路线是示意，正式实现必须读doors，并兼顾战斗内地图总览与第三层直道。等用户图稿反馈，详细思路/提示词见同目录README与prompt.txt。

## 2026-11-05 商店恢复
第二三层改图标陈列、悬浮详情和选中环；安卓首击查看再次点击购买。实机验证尚未完成。保留其他已有修改。

## 2026-11-05 商店弹窗修正
详情统一在三排商品之后绘制；320宽、22标题/18正文，按文本高度和商品中心定位，位于图标上方并限制屏幕边界。真实shop场景截图shop_popup_2/3.png已检查；verify_shop_popup.gd运行输出SHOP POPUP PASS。其他已有修改保留，未推送。

## 2026-11-05 UI遗留逐项同步
商店选卡/触屏按钮、价格与提示、故事领取与继续按钮、Mention浅纸浮窗、战斗滚动提示、牌库徽标已同步。新增共用自绘文字按钮，按宽高缩字并保留内边距；AGENTS登记文字禁止压边纪律。选卡标题增加独立浅纸底避免背景标题干扰。
验证：_verify.py全通过（mana、engine5298、reward26、bgm39、smoke64）；verify_ui_followup.gd在1280x720及1024x768出图，检查商店及故事文字留白；sync_mention为正式场景上的组件受控展示，不等同于真实悬停流程验收。截图sync_*.png。已有战斗地图/职业选择修改及旧截图保留，不混入本提交。未推送。
