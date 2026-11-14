# R690 工具图标 + 「陷阱」机制改名「工具」+ 两个新工具

> 2026-11-14 · 店长指令四件事：
> ① 把四张缺图卡应用到游戏 ② 陷阱机制改名「工具」
> ③ 新增小血瓶（回复 20% 生命 / 售价 50）、法力药剂（回复 2 点费用 / 售价 35）
> ④ 查地图商店保底，若为 1 提到 2。

---

## ① 四张卡图转正

`python tools/cardart.py approve <id>` 逐张（**绝不 `approve all`**，`_pending` 还有 116 张别人的）：

| 卡 | 结果 |
|---|---|
| 9248 种子 | → `assets/pics/9248.png` |
| 9249 被眷顾者 | → `assets/pics/9249.png` |
| 9250 鸭妈妈 | → `assets/pics/9250.png` |
| 9251 小鸭 | → `assets/pics/9251.png` |

`python _art_index.py`：**319/319 已完成，待做 0，暂不做 0**（首次 100%）。`.import` 已随 Godot 运行自动生成。
出图过程见 `art_src/2026-11-14_缺图收口_R690/README.md`。

## ② 「陷阱」→「工具」改名（只改机制名，不动具体道具名）

**口径**：改的是**分类/机制名**。具体道具仍叫「炼金炸弹 / 冰冻陷阱 / 毒瓶 / 穿刺陷阱」——
「冰冻陷阱」就是一个陷阱，这个名字不变；变的是「这一栏叫什么」。

内部标识符（`trap` / `TrapData` / `RunState.traps` / `trap_fields` / 7001+ id 段）**一个字没动**，
改动只在玩家可见文案：

| 文件 | 位置 | 改后 |
|---|---|---|
| `battle_scene.gd` | 4 条 `_say` 操作提示 | 「再使用工具」「没有可以放置工具的空格」「工具没有放置…」「这格已经不能放置工具了」 |
| `battle_scene.gd` | 卡名回落 `"陷阱"` | `"工具"` |
| `shop_scene.gd` | 第二行右组题签 `"陷阱"` | `"工具"` |
| `shop_scene.gd` | 满栏提示 | 「工具栏已满（x/x），先在对战里用掉一个」 |
| `shop_scene.gd` | 购买成功提示 | 「获得工具「x」· 价格」 |
| `map_scene.gd` | 左下栏头 | 「工具 x/3」 |
| `trap_data.gd` / `trap_art.gd` / `traps.json` | 注释 | 同步改口径说明 |

⚠️ 商店题签 `"工具"` 与地图栏头是**硬编码中文**（原「陷阱」也是），英日环境不翻译 —— 这是既有缺口，
本轮**没有**扩大它，也没有顺手引入新的 i18n 键（要改是三语 + canonical 四份文件，属独立轮次）。

## ③ 两个新工具

### 数据（`traps.json`，id 段续到 7006）

| id | 名 | 售价 | 字段 | 说明 |
|---|---|---|---|---|
| 7005 | 小血瓶 | 50 | `heal_pct: 20` | 使用后回复 20% 生命（上限为最大生命） |
| 7006 | 法力药剂 | 35 | `energy: 2` | 使用后回复 2 点费用 |

`TrapData` 新增 `heal_pct` / `energy` 两字段 + `is_usable()`（**判据只看数据**：
带这两个字段之一就是使用型，界面与引擎共用这一个口，不靠 id 硬编码）。

### 「工具」分两类

| 类型 | 交互 | 结算 |
|---|---|---|
| 放置型（7001~7004） | 从栏位**拖**到战场空格 | 敌人踩到触发（原有逻辑，一字未改） |
| 使用型（7005/7006） | **轻点即用**，拖不动（提示「点一下就能用，不用拖」） | `GameEngine.use_tool(id)` 立即结算 |

引擎新增 `use_tool(id)`：回血走 `_op_heal(SIDE_SELF, …)`（吃既有回血口径 + game_over 检查，
`ceili(max_hp * pct / 100)` 且**至少 1 点**）；回费直接 `state.energy +=`（与拆解 8049 同口径，
不污染 `self_energy_spent`、允许超额）。发出 `tool_used` 事件供界面用。
界面口 `battle_scene._use_tool_slot()`：敌方回合拦截 → 结算 → `RunState.consume_trap(slot)`（用了就没）。

### 图标（codex 纯文生图，与本批陷阱图标同族）

| 文件 | 内容 |
|---|---|
| `assets/ui/trap_icon_7005.png` | 小血瓶：圆肚玻璃瓶 + 木塞 + **猩红液体 + 红十字** + 两颗气泡（128x128 RGBA） |
| `assets/ui/trap_icon_7006.png` | 法力药剂：同款瓶 + **宝石蓝液体 + 蓝菱形** + 两颗气泡 |

与 7003 毒瓶**同一只瓶**（瓶型/描边/木塞/高光/气泡全一致），只换液体色与中央标记 ——
一眼看出是同一套（与 9154/9185 共用路牌外框同一条原则）。
prompt 直接复用 R663 的 `ICON_HEAD`，画风段一个字没改。去背走 R663 的边缘 flood-fill。
`TrapArt._potion()` 保留为**无素材时的程序化兜底**（贴图落盘后自动优先用贴图）。

### 西语

`i18n/traps_es.json` 补 7005/7006 两条（Frasco de Vida Pequeño / Poción de Maná），
desc 里的「工具」用 herramienta。英日无 traps 域（既有缺口，落回中文）。

## ④ 地图商店保底：**已经是 2，不用改**

`scripts/rogue_map.gd`：`SHOP_MIN := 2` / `SHOP_MAX := 2`（R369 店长口径「商店保底有 2 个」）。
加上右上角固定 1 间 → **每层至少 3 间商店**，再叠「?」房自己摇出来的。
`REST_MIN := 2`（篝火保底）同样是 2。`test_engine` 的 R369 段钉着这两条。

## 回归（2026-11-14 11:0x）

| 套件 | 结果 |
|---|---|
| assemble | 0 失败 |
| mana | PASS |
| engine | 5963✓ / 0✗ |
| reward | 26✓ / 0✗（奖励池 219，含并行线 R692 的鸭妈妈） |
| bgm | 39✓ / 0✗ |
| **traps** | **55✓ / 0✗**（新增 8 条：两工具数据 + `use_tool` 回血/回费/上限/拒收放置型 + 三处接线守卫） |
| **trapinput** | **36✓ / 0✗** |
| smoke | 72✓ / 0✗ |

- `_verify.py` 首跑报 `smoke 72✓/1✗`（`R215 记录页：应有 2 行，实际 3`）——**并行线在同一份 userdata 上同时跑 Godot**
  抢写 `run_records.json`；单独重跑 smoke 即 **72✓/0✗**，已确认非本轮引入。
- engine 日志里有一行 `ERROR: unsupported format character`（R313 段附近），出现在**并行线的 R692 改动区**，
  不影响断言（5963✓/0✗），未计入本轮。
- 存档：跑前备份 `_bk_r690_userdata`（含 `profile.json` + `run_save.sav`），
  跑后只覆盖还原被测试改动的 `battle_records.json` / `run_pending.json` / `run_records.json`，
  **RESTORE_VERIFY OK**；未删 live 多出的文件。

## 验收截图

- `_review_toolbar_zoom.png` —— 战斗工具栏三槽（3/3）：橙框炸弹 / 红框小血瓶 / 蓝框法力药剂。
  出图命令：`battle.tscn -- --screenshot --tooldemo --level 0 --shotframe 200`
  （`--tooldemo` 是本轮新加的出图参数：塞 `[7001,7005,7006]` 并置 `run_active`）。
- `_review_icon_compare.png` —— 毒瓶 / 小血瓶 / 法力药剂 三格并排，同族确认。
- `_review_battle_toolbar.png` —— 全屏原图。
- 商店截图已核：第二行右组题签显示**「工具」**，随机两个商品里出现小血瓶（红十字图标）。

## ⚠️ 未提交（并行线同名文件冲突）

`scripts/game_engine.gd` 与 `scripts/battle_scene.gd` 同时含**并行线 R692**（鸭妈妈/小鸭、生蛋鸭孵化时机、
飓风咆哮改每次触发、护甲图标）与**本轮 R690** 的改动，无法整文件干净提交。
本轮**未 commit、未 push**，改动全部留在工作树，按历次「归档」惯例留待店长统一提交。
仅本线独占的文件：`traps.json` / `trap_data.gd` / `trap_art.gd` / `shop_scene.gd` / `map_scene.gd` /
`test_traps.gd` / `i18n/traps_es.json` / `assets/pics/*.png` / `assets/ui/trap_icon_700[56].png` / 本目录。
