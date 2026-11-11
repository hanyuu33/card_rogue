# Steam 专有成就体系（R576 起，R577 补 AppID 接入）

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

## 二、代码侧

- **抽象层**：`scripts/steam_achievements.gd`（`class_name SteamAchievements`）。
  全部走 `Engine.has_singleton("Steam")` + `call()` 反射，**从不直接引用 `Steam` 标识符**——
  因此未装 GodotSteam 时也能正常编译运行（测试版 / 本地开发不受影响）。
- **初始化**：`title_scene._ready` 调 `SteamAchievements.init()` —— 内部走
  `steamInitEx(app_id)` 拿回 `{status, verbal}`；未装插件 / 初始化失败都只**记状态**，
  绝不中断游戏（成就静默丢弃，游玩与回归不受影响）。
- **运行状态**：`SteamAchievements.is_ready()` / `status_text()` —— 未装插件、Steam 客户端
  没开、AppID 无效分别是不同文案，可直接显示在设置页或写进玩家反馈日志。
- **触发点**（物理事件，幂等；`unlock()` 成功后立即 `storeStats()` 落盘，防崩溃丢成就）：
  | 成就 | 触发点 |
  |---|---|
  | `FIRST_STEP` | `run_state.start_run()` |
  | `FIRST_BOSS` | `unlock_system.note_boss_seen()`（仅第一层） |
  | `LAYER2_CLEAR` | `unlock_system.note_layer_two_cleared()` |
  | `FULL_CLEAR` / 职业通关 / 高难度 | `battle_scene` 真通关块（`current_layer == LAYER_THREE`） |

## 三、AppID 怎么填（留空就是发行形态）

代码里只有一处：

```gdscript
# scripts/steam_achievements.gd
const APP_ID := 0
```

**`0` 不是「待填的占位符」，它就是发行版的正确值。** 初始化时按三级回落取实际 AppID：

| 优先级 | 来源 | 用在哪 | 要不要入库 |
|---|---|---|---|
| 1 | `SteamAchievements.APP_ID` 常量 | 想固定写死时 | 改代码 |
| 2 | 项目根 `steam_appid.txt` | **本地离线调试** | ❌ 已在 `.gitignore` |
| 3 | 都没有（= 0）→ 交给环境变量 `SteamAppId` | **Steam 发行版** | 不需要文件 |

**发行版为什么不用填**：从 Steam 客户端启动游戏时，客户端会把 AppID 注入 `SteamAppId`
环境变量，`steamInitEx(0)` 自己会读它。**发行包也不该带 `steam_appid.txt`** —— 带了反而会
覆盖客户端注入的值（Valve 明确要求移除）。这一点本项目已天然满足：`export_presets.cfg`
四个预设的 `exclude_filter` 都含 `*.txt`，该文件进不了包。

**本地离线调试怎么填**：

1. 复制 `steam_appid.txt.template` → `steam_appid.txt`（去掉 `.template` 后缀）
2. 内容**只留纯数字**：自有 App 填后台的 App ID；还没拿到就填 `480`
   （Valve 公开的 Spacewar 测试 App，人人可用）
3. 放项目根（和 `project.godot` 同级）；不想配就别建这个文件，等价于留空

> ⚠️ 内容不是纯整数（比如把模板里的 `#` 注释一起留下了）时，`_read_local_appid()` 会返回 0
> 并回落到环境变量 —— 不会崩，但等于没配。填完记得把注释删干净。

## 四、Steamworks 后台配置步骤

1. **加入 Steamworks**（`partner.steamgames.com`）→ 创建 App → 拿到 **AppID**。
2. 进入 **App Admin → 成就（Achievements）** → 「添加成就」，逐个填入上表的
   **API Name**、显示名、描述，以及图标（规格见下）。
3. 设好成就后，**必须点「发布（Publish）」** 让改动生效（Steam 成就改动默认是
   草稿态，不发布的话游戏里调 `setAchievement` 不会记录）。
4. 每张成就图另存 **64×64 的两版**（已达成彩色 / 未达成灰阶），见下。
5. 测试：用测试 AppID 上传 build，Steam 客户端切到对应分支运行，验证解锁。
   进游戏前先看 `SteamAchievements.status_text()` 的输出 —— 它是「客户端没开 / AppID 无效 /
   插件没装」的第一手判据，比闷头猜快得多。

### 成就图标规格

每个成就要传**两张**图：

| 项 | 要求 |
|---|---|
| 尺寸 | **64 × 64** 像素正方形（后台会校验，尺寸不对传不上去） |
| 格式 | JPG / PNG / TGA |
| 张数 | 每个成就 2 张：`Achieved`（彩色）+ `Unachieved`（灰阶 / 剪影） |

> 建议沿用游戏内卡图同一套画风做 64px 缩略，未达成版统一转灰阶 —— 玩家一眼能看出
> 「还没拿到」，跟卡面观感也统一。最终以后台表单的实际提示为准（Valve 会小幅调整）。

## 五、GodotSteam 集成（可选外部依赖）

游戏用的是 **Godot 4.3（GL Compatibility）**，对应 GodotSteam 的 **4.1–4.3 专用预编译包**：

1. 下载 `godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`
   （`https://codeberg.org/godotsteam/godotsteam/releases`，选 4.1–4.3 的 gde 包）。
2. 解压到**项目根目录**，得到 `addons/godotsteam/`（含 `.gdextension` + `steam_api64.dll` 等）。
3. 重启 Godot 编辑器让 GDExtension 加载。
4. **AppID 一般不用管** —— 留空即读环境变量（发行形态）。只有本地离线调试才按
   「三、AppID 怎么填」放一份 `steam_appid.txt`；发行包靠 `*.txt` 排除规则天然不带它。
5. 导出时确保 `steam_api64.dll` 进包（GodotSteam 包已含，`export_filter="all_resources"` 会带上）。

> ⚠️ **Overlay 已知坑**：GodotSteam 的 Steam Overlay 在编辑器里用 Forward+ 渲染器不显示，
> 但本项目是 **GL Compatibility**，且导出后经 Steam 客户端启动正常 —— 无需改渲染器。

## 六、与测试版 / 发布版的关系

- Steam 成就是**物理事件**的反映，**独立于** `GameBuild.is_release()` 的版本闸门：
  只要装了 GodotSteam 且 Steam 在运行，测试版 / 发布版都会触发。
- 未装 GodotSteam 时（本地开发 / 当前测试版），所有解锁**静默跳过**，不影响回归与正常游玩。
- 回归护栏（`test_engine.gd` 的 R577 块）锁死三条：`APP_ID` 默认 0、零处裸引用 `Steam.`
  标识符、六个成就钩子在不就绪时全部静默不崩。
