# Steam 专有成就体系（R576）

> 与游戏内 **story 成就**（`stories.json` → 解锁剧情段）完全独立。story 成就是游戏内的
> 「剧情解锁条件」，Steam 成就是 Steamworks 后台定义的**进度徽章**，通过 Steam API 解锁、
> 展示在商店页与玩家档案里。

## 一、成就清单（Steamworks 后台照此建）

| API name（代码里写死） | 显示名（后台可自定） | 触发条件 |
|---|---|---|
| `FIRST_STEP` | 初次启程 | 开始第一局游戏 |
| `FIRST_BOSS` | 直面恐惧 | 见到第一层的 Boss |
| `LAYER2_CLEAR` | 深入腹地 | 打通第二层 |
| `FULL_CLEAR` | 完整通关 | 打通第三层（真胜利） |
| `CLEAR_FOREST` | 森林的加冕 | 用森林精魄通关 |
| `CLEAR_ROGUE` | 影中的圆满 | 用暗影刺客通关 |
| `CLEAR_MECH` | 机械的觉醒 | 用机械之心通关 |
| `CLEAR_HARD` | 越难越勇 | 在难度 5 及以上通关 |

> ⚠️ **API name 必须与代码完全一致**（`scripts/steam_achievements.gd` 里的 `API_*` 常量）。
> Steamworks 后台的「API Name」字段区分大小写、全大写；显示名 / 描述可以随便改，不影响解锁。

## 二、代码侧（已落地，无需再改）

- **抽象层**：`scripts/steam_achievements.gd`（`class_name SteamAchievements`）。
  全部走 `Engine.has_singleton("Steam")` + `call()` 反射，**从不直接引用 `Steam` 标识符**——
  因此未装 GodotSteam 时也能正常编译运行（测试版 / 本地开发不受影响）。
- **初始化**：`title_scene._ready` 调 `SteamAchievements.init()`（未装插件则静默跳过）。
- **触发点**（物理事件，幂等）：
  | 成就 | 触发点 |
  |---|---|
  | `FIRST_STEP` | `run_state.start_run()` |
  | `FIRST_BOSS` | `unlock_system.note_boss_seen()`（仅第一层） |
  | `LAYER2_CLEAR` | `unlock_system.note_layer_two_cleared()` |
  | `FULL_CLEAR` / 职业通关 / 高难度 | `battle_scene` 真通关块（`current_layer == LAYER_THREE`） |

## 三、Steamworks 后台配置步骤

1. **加入 Steamworks**（`partner.steamgames.com`）→ 创建 App → 拿到 **AppID**。
2. 进入 **App Admin → 成就（Achievements）** → 「添加成就」，逐个填入上表的
   **API Name**、显示名、描述，以及图标（Steam 成就图标规格见后台）。
3. 设好成就后，**必须点「发布（Publish）」** 让改动生效（Steam 成就改动默认是
   草稿态，不发布游戏里调 `setAchievement` 不会记录）。
4. 测试：用测试 AppID 上传 build，Steam 客户端切到对应分支运行，验证解锁。

## 四、GodotSteam 集成（可选外部依赖）

游戏用的是 **Godot 4.3（GL Compatibility）**，对应 GodotSteam 的 **4.1–4.3 专用预编译包**：

1. 下载 `godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`
   （`https://codeberg.org/godotsteam/godotsteam/releases`，选 4.1–4.3 的 gde 包）。
2. 解压到**项目根目录**，得到 `addons/godotsteam/`（含 `.gdextension` + `steam_api64.dll` 等）。
3. 重启 Godot 编辑器让 GDExtension 加载。
4. 项目根放 `steam_appid.txt`，内容 = 你的 AppID（**仅开发期**；发行后 Steam 客户端自动注入，别把测试 AppID 带进发行包）。
5. 导出时确保 `steam_api64.dll` 进包（GodotSteam 包已含，`export_filter="all_resources"` 会带上）。

> ⚠️ **Overlay 已知坑**：GodotSteam 的 Steam Overlay 在编辑器里用 Forward+ 渲染器不显示，
> 但本项目是 **GL Compatibility**，且导出后经 Steam 客户端启动正常 —— 无需改渲染器。

## 五、与测试版 / 发布版的关系

- Steam 成就是**物理事件**的反映，**独立于** `GameBuild.is_release()` 的版本闸门：
  只要装了 GodotSteam 且 Steam 在运行，测试版 / 发布版都会触发。
- 未装 GodotSteam 时（本地开发 / 当前测试版），所有解锁**静默跳过**，不影响回归与正常游玩。
