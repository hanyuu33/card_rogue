# Steam 发布路线图（R608 起）— 只做计划，不改代码

> 建立日期：2026-11-12。基线：工作树 R607 状态，六套回归最近一次全绿（engine 5765✓ / smoke 68-0）。
> 本文只登记「要做的事 + 判据」，不记录已完成细节；每轮落地后请在 HANDOFF / 日志里另记。
>
> **2026-11-12 修订**：店长定案「英文版一定要做，最好还有日文版，但不是现在」→
> 决策 Q1 落定，新增「线 E：本地化」；其中 **E0 地基从 R608 起每轮生效**（零额外工期），
> 翻译本体排到 R614 之后。

---

## 0. 现状体检（本次实测，非推测）

| 项 | 现状 | 判定 |
|---|---|---|
| 品牌 | `GameBrand`：中《嘎嘎乱杀》／英 `Quackill`／`risusumai`／`v1.0.0` | ✅ 已定稿 |
| `GameBrand.FOOTER` | R763 改为纯 `v{v}`；标题页统一走 `footer_text()`，不再显示「开发版」 | ✅ 已收口 |
| Steam 成就桥 | `scripts/steam_achievements.gd` 完整：9 成就 + `Engine.get_singleton` 反射 + `storeStats` 落盘 + AppID 三级回落 | ✅ 代码就绪 |
| GodotSteam 插件 | `addons/godotsteam/` **已装 4.15 GDExtension**（plugin 4.1–4.3，Steamworks SDK 1.62）；4.3 编辑器与导出包都实测加载成功（`has_singleton(Steam)=true`，815 个方法，导出目录自动带 `libgodotsteam.*.dll` + `steam_api64.dll`） | ✅ R740 已装（只剩「后台建成就」没做） |
| 成就数量 / 层次 | 8 个，全是「进度型」（初见 / 通关 / 难度） | ⚠️ 偏少，缺长尾（组合、图鉴、每日） |
| 导出预设 | 四个预设均改用 `Quackill*.exe/apk`；产品名 Quackill、厂牌 risusumai、exe 版本资源 1.0.0 | ✅ R763 已收口 |
| 桌面纹理 | 卡图 `compress/mode=2` + `high_quality=true`，生成 **bptc + astc 双变体** | ⚠️ 纹理 PSNR 仍待重测；R763 已产出真实 260.1MB 包 |
| 存档 | `run_save.sav`（局内）/ `profile.json`（玩家）/ `run_records.json` / `run_pending.json` / `save_trace.log`（取证，带时间戳、会涨） | ⚠️ 云存档需白名单，`save_trace.log` 不能同步 |
| 本地化 | **英 / 日 / 西数据层已收尾（R784 / R788）**：331 卡 / 64 道具 / 209 特性；日文同形词运行时回落已修，西语 23,043 项校验通过，i18n 专项 39 通过 0 失败 | ✅ 四语卡面排版 0 问题；日文字体字形仍见 E3 |
| 新手引导 | 教程机制代码在（`battle_scene._tutorial` + 7350+ 行引导条），但 **42 个关卡 `tutorial` 全为 `[]`**；且引导条只剩 36..52 共 16px 高度（源码注释明说必须先改版式） | ❌ 休眠态，恢复成本高于「新做一套」 |
| 每日挑战 | R762 已接模式选择、UTC 日期种子、固定职业/难度/标准初始卡组、每日一次、续档、本地成绩与 Steam 榜桥 | ⚠️ 本地闭环已完成；自有 AppID 的真实建榜/上传/下载待验 |
| 组合系统 | 唯一入口 `_open_combo()`；候选池 24 张；`combo_trigger` 卡 **仅 2 张**（9246 / 9247）；机械之心可用候选仅 4 张；R588「产物继承 traits / id」**未修** | ⚠️ 保真 bug + 内容面窄 |
| 联机 | `net.gd` 局域网 UDP 广播 + TCP 47812（Python 版移植） | ⚠️ 影响隐私政策 / 防火墙 / 商店页措辞，见决策 Q4 |
| 分辨率 | 1280×720，`canvas_items` + `expand` | ✅ 天然适配 Deck / 各种 16:9 |
| 包体 | R763 正式 Windows 包实测 **260.1MB**（`dist/Quackill_release.exe`，嵌入 pck）；R741 已把 `release/*` 排除出 4 个预设 | ✅ 已瘦身，B3 实测有数 |

---

## 1. 线 A：Steam 技术接入（P0）

| # | 事项 | 要点 | 判据 |
|---|---|---|---|
| A1 | 安装 GodotSteam（GDExtension，对齐 4.3） | 只引 GDExtension，不引 GDNative；`addons/godotsteam/`；**不进 Android 预设** | `SteamAchievements.status_text()` 返回「已连接 Steam」 → **R740 达成** |
| A2 | AppID 与本地联调 | 用 Spacewar `480` 或放 `steam_appid.txt`（**发行包不带**）；`APP_ID` 常量保持 0 | 本地 status=0；发行包内无 `steam_appid.txt` → **R740 `--appid 480` 实测 status=0** |
| A3 | 9 个成就逐个实机解锁 | 用测试 build 引信触发 `note_*`；核对后台 API 名大小写完全一致 | Steam 后台显示 9/9 可解锁、`storeStats` 生效 → **卡在「后台还没建这 9 个成就」** |
| A3′ | 成就图标（铜/银/金三档） | 单色金属徽章一套：进度型铜、通关型银、高难型金；未达成统一灰石 | ✅ `release/achievement_icons/` 9×2 张 64px 已备好，直接上传 |
| A4 | 成就长尾补 4~6 个 | 建议：首次组合 / 组合产物达 N 种 / 图鉴全收 / 每日挑战首胜 / 无伤过精英 / 单回合斩杀 100+ | 后台 + 代码 `API_*` 两处同名 |
| A5 | 云存档（Steam Auto-Cloud 或 Remote Storage） | 只同步 `profile.json` + `run_records.json` + `run_save.sav` + `daily_challenge.json`（每日次数跨机一致）；**排除** `save_trace.log` / `run_pending.json` / `*_test.*` | A 机打一半→B 机续档成功；冲突时取「本地 mtime 新」，且 `save_trace` 有记录 |
| A6 | 单实例互斥 | `AppInstanceGuard` 在 autoload 首位抢 `user://instance.lock/`；活 PID 拒绝，死 PID 回收；headless / 截图探针跳过 | 静态回归已覆盖抢锁 / 拒绝 / 回收；R763 真机双开弹窗仍需一次人工验收 |
| A7 | 存档格式版本迁移框架 | 现在 `RunRecord.FORMAT=1`，加字段可空；`run_save` 无版本号 | 用旧档启动不崩、不丢；有 `save_version` 字段 |
| A8 | 桌面端日志与反馈出口 | 项目开启 `user://logs/godot.log`（5 份轮转）；设置页「导出诊断包」打成本机 zip | ✅ R763 已落代码与测试；真实玩家机崩溃复现仍待发售后验证 |
| A9 | Overlay / Deck 自评 | Overlay 默认可用；Deck 评级先做 Playable 诚实自评 | 提交时 Steam 后台填 Deck 兼容性 |

> A1–A3 是关键路径：成就代码已写完但**从未实机跑过**，越早验越安全。

### 1.1 R740 实测记录（GodotSteam 已装 + 一条命令自检）

**装的是什么**：`godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`
（GodotSteam 4.15 / Steamworks SDK 1.62，`compatibility_minimum = 4.1`，正好配 4.3）。
来源：`https://codeberg.org/godotsteam/godotsteam/releases/download/v4.15-gde/godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`
（11.5MB 包 → 解压 37MB 到 `addons/godotsteam/`，全平台二进制原样保留，不裁剪）。

**一个必须知道的坑**：GDExtension 要被认出来，`res://.godot/extension_list.cfg` 里必须有
`res://addons/godotsteam/godotsteam.gdextension` 这一行。这个文件由**编辑器打开工程时**写入；
本机 `--headless --editor` 跑扫描时被 `Scan thread aborted` 打断（工程大 + 退出太快），
手写该行后一切正常。**换机器 / 新克隆**后若自检报「未加载」，先看这一行在不在。

**自检命令**（项目根，把 `GODOT` 换成本机 Godot 4.3）：

```bash
# ① 只读体检：插件在不在 / Steamworks 连没连上 / 后台成就名对不对
$GODOT --headless --path . --script res://tools/steam_selftest.gd

# ② 没登 Steam 客户端也能验链路：用 Valve 公开测试 App Spacewar
$GODOT --headless --path . --script res://tools/steam_selftest.gd -- --appid 480

# ③ 真解锁 + 读回（后台建好 9 个成就、且拿得到自有 AppID 之后才跑）
$GODOT --headless --path . --script res://tools/steam_selftest.gd -- --unlock --hooks
```

退出码：`0` 全绿 / `1` 插件没加载 / `2` Steamworks 没连上 / `3` 后台成就名对不上 / `4` 解锁失败。

**实测结果（2026-11-15）**：

| 检查 | 结果 |
|---|---|
| 4.3 编辑器进程内加载插件 | ✅ `has_singleton(Steam)=true`，815 个方法 |
| `--export-release` 导出产物 | ✅ 自动带 `libgodotsteam.windows.template_release.x86_64.dll` **和** `steam_api64.dll`（都在 exe 同目录，不用手工拷） |
| 导出包内跑 engine 全套 | ✅ 全通过；包内同样识别到插件（日志：本机已装 GodotSteam） |
| AppID 480 实连 | ✅ `status=0`，账号 `みうバニー`，`getNumAchievements()=0`（Spacewar 本来就没成就） |
| 9 个成就名比对后台 | ❌ 后台一个都没建 → 这正是 A3 的唯一阻塞 |
| 不传 AppID 直接跑 | `status=1`（No appID found）—— 正常，发行版由 Steam 客户端注入 |

**还剩两步**（都在 Steamworks 后台，不在代码里）：
1. 后台按 `release/steam_achievements.md` 第一节建 9 个成就（API Name 一字不差）。
2. 拿到 AppID 后跑命令 ③，看到 `9 个成就解锁调用全部成功` + 客户端弹出成就，A3 就算过。

**给玩家/自己看的追踪开关**：设环境变量 `QUACKILL_STEAM_TRACE=1` 再启动游戏，
每次成就触发会打 `[steam-trace] FIRST_STEP`（即使 Steam 没连上也记一行），
用来确认「玩到那个节点时该解锁的到底有没有被调」。

---

## 2. 线 B：发行工程与包体（P0）

| # | 事项 | 要点 | 判据 |
|---|---|---|---|
| B1 | 名实一致收尾 | `FOOTER` 去「肉鸽开发版」；`export_path` 改 `dist/Quackill.exe` / `dist/Quackill.apk`；`description` / `copyright` / `company_name=risusumai` / `product_name=Quackill` | ✅ R763 完成；历史文档与旧归档包名保留，活动脚本 / 预设无旧名 |
| B1′ | `rcedit` 工具链 | Godot 只有配置了 rcedit 才能把版本资源 / 图标写进 exe；本机已放 `C:\Users\Administrator\.workbuddy\binaries\rcedit\rcedit-x64.exe` 并写入编辑器设置 `export/windows/rcedit`。来源 rcedit v2.0.0，SHA-256 `3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a` | 换机必须重配；否则导出只得到 Godot Engine 版本资源 |
| B2 | **桌面纹理变体重测** | `high_quality=true` → bptc + astc；Windows 走 bptc/S3TC。要重跑 `tools/shot_r596g_tex.gd` + `_psnr_r596g.py`（**关 `content_scale_mode`**） | 桌面 PSNR ≥ 45dB；内存 / 首屏加载不劣化 |
| B3 | 桌面包体重算 | 桌面不带 v7a/arm64 两份 lib；PCK 走 bptc 体积与 astc 不同 | ✅ R789 实测 `dist/Quackill.exe` **277.1MB = 引擎 80.4MB + 内嵌 PCK 196.7MB**（GDPC 头在 84.28MB）；桌面纹理 PSNR 仍待 B2 |
| B4 | Windows release 预设核查 | 图标用 `assets/ui/icon.ico`；`config/icon` 现指向 `icon_android_legacy.png`（**桌面也用它**，需确认尺寸观感） | 干净机双击可跑，任务栏图标正确 |
| B5 | Steam 构建上传 | `steamcmd` + `app_build_<id>.vdf` + `depot_build.vdf`；**两个 depot**：① exe + pck ② `content/`（见 §2.1） | 上传成功、Steam 客户端能下、能启动 |
| B6 | 版本号单一来源 | `GameBrand.VERSION=1.0.0`；Windows exe FileVersion / ProductVersion 已实测 1.0.0；Android versionName 1.0.0 | ✅ 代码与包体完成；Steam depot / build 描述待后台填写 |
| B7 | 自动更新验证 | Steam 管更新，验证「存档不被覆盖」「更新后旧档可读」，并**记录一次真实下载体积** | 改一句文案 → 续档正常，且下载量只有对应 JSON（不是整个 exe） |

### 2.1 内容热更（R789 已落地，避免每次更新全量重下）

**问题**：单文件 exe 里数据与引擎捆在一起，改一张卡的效果文本也会让整个 277MB 的 exe 变化，
Steam 只能近乎全量重下。而 Steam 的更新粒度是**文件**，不是"包"。

**实测规模**（真正高频变动的只有 1.04MB）：

| 文件 | 大小 | 变更频率 |
|---|---|---|
| `cards.json` | 177.6KB | 每轮加卡 / 调数值 |
| `i18n/*.json` | 28 个文件，约 0.83MB | 改文案 / 翻译 |
| `relics.json` / `stories.json` / `traps.json` | 16.4KB / 9.3KB / 3.0KB | 偶尔 |
| 其余（PCK 内美术 / 音频 / 引擎） | 196.7MB + 80.4MB | 发版级 |

**做法**：`scripts/data_paths.gd` 给静态数据加了覆盖层，读取顺序
`CARDROGUE_CONTENT_DIR`（测试）→ **exe 同目录 `content/`** → pck 内 `res://` 基线。
发布时 `_release.py` 自动把 32 个 JSON 同步到 `content/`，基线仍留在 pck 里当兜底。

**安全网**（探针 `tools/_probe_content_override.gd`，已并入 `_verify.py` 的 `content` 套件，8 项）：
- 覆盖生效、数量与基线一致（整份替换，**不是**增量合并）；
- 语法坏 / 结构空（`{"cards": []}`）→ 打 warning 并回落 pck 基线，不崩；
- 译文 JSON 同样走覆盖；清掉 `content/` 后自动回到基线。

**边界（写清楚，免得误期待）**：
- 只能热更**静态数据**。美术 / 场景 / 脚本的热修需要"补丁 pck + `load_resource_pack`"（L2，未做）；
  引擎本体（80.4MB）不热更，走正常发版。
- 关卡数值目前在 `scripts/game_levels.gd` 里是代码，改关卡仍要发版；要热更得先把关卡数据化。
- 安装目录**只读不写**：补丁一律由 Steam 下发，游戏自己不去改安装目录。

---

## 3. 线 C：商店页与合规（P0，可与代码并行）

| # | 事项 | 要点 |
|---|---|---|
| C1 | Steamworks 后台开户 | $100 入场费、税务表（W-8BEN）、银行信息。**不需要版号、不需要商标**（已查证） |
| C2 | **命名必须在 store page review 前定死** | 通过 pre-release review 后不能自改，要提工单；大改兜底是重发新 app（丢愿望单/评测） |
| C3 | 商店页素材 | 主胶囊 616×353、小胶囊 231×87、竖版 374×448、页头 460×215、logo、≥5 张 1920×1080 截图、预告片（建议有）、GIF |
| C4 | 文案 | 中英双语商店页、短描述 / 长描述、标签（Roguelike Deckbuilder / Card Game / Singleplayer / Pixel or 2D / Turn-Based）、系统需求、支持语言表 |
| C5 | 内容调查 + **生成式 AI 披露** | 预生成（卡图 / 主视觉 / 厂牌徽记 / 商店素材）如实填；实时生成选「无」。口径见日志「Steam 的 AI 披露」条 |
| C6 | 年龄分级问卷 | 含战斗 / 无血腥，按 Steam 自评 |
| C7 | 隐私政策 | 有 LAN 联机（UDP 广播 / TCP）→ 至少说明「仅局域网、不向服务器上传」；若日后做 Steam 联机需重写 |
| C8 | Coming Soon → 发布 | 先上 Coming Soon 收愿望单，再走 build review → store page review → 手动 Release |
| C9 | 软著（建议不阻塞） | 出海纠纷的基础证据；30–45 天、800–1500 元 |
| C10 | Demo / Next Fest（可选） | Demo 要单独 depot 与存档隔离；曝光收益大、成本中等 |

---

## 4. 线 D：内容补充（P1）

### D1 组合系统补充（建议先做，影响平衡与图鉴）

| # | 事项 | 依据 |
|---|---|---|
| D1-1 | **修 R588：组合产物继承 `traits` / `id` 等** | `tools/probe_combo_inherit.gd` 已能探测；现在是保真漏洞（产物丢属性槽） |
| D1-2 | 候选池按职业校准 | 机械之心满足「上下半都有」的只有 4 张（森林精魄 6 张），抽不满体验差 |
| D1-3 | 扩 `combo_trigger` 卡 | 现在仅 9246（死亡时）/ 9247（回合开始时）；建议每职业再各 1 张，覆盖 `use_after` / `enter` |
| D1-4 | 组合产物进图鉴 | 图鉴 312 张不含产物；产物无 `id` 卡片，需在图鉴加「组合页」或详情可查 |
| D1-5 | 组合页可读性 | 候选只显钩子（上半），产物预览要能一眼看到「变成什么」 |
| D1-6 | **禁止做成 assemble 动作**（回归锁保留） | 否则组合出「再组合一张卡」套娃 |
| D1-7 | 成就联动 | 「首次组合」「产物达 N 种」→ 接 A4 |

### D2 新手指引（选做）

三条路线，成本差一个量级：

| 方案 | 做法 | 成本 | 评价 |
|---|---|---|---|
| A. 复活教程关 | 填 `game_levels` 的 `tutorial` 数组 + 引导条 | **高**：引导条只剩 16px 高，必须先改版式（侧栏 / 收窄单行） | 老代码但 UI 空间已死 |
| B. 首局教学关（推荐） | 第一局强制进一张「教学专用关卡」（已有 `_demo_pending` / 新手试炼底子），3–5 步气泡：出牌 → 能量 → 结束回合 → 选路 | 中 | 不动版式，可随时跳过 |
| C. 图文引导页 | `opening_scene` 后插入一页 4 格说明 | 低 | 效果最弱，但能兜底 |

- 推荐：**B 为主 + C 兜底**；不做全程强制教程（roguelike 玩家反感）。
- 判据：新玩家 5 分钟内能独立完成「出牌 → 结束回合 → 地图选路 → 打完第一战」。

### D3 每日挑战（R762 已落地本地闭环）

| # | 事项 | R762 状态与判据 |
|---|---|---|
| D3-1 | 日期派生种子 | ✅ `DailyChallenge.seed_for_date()` 独立派生 UTC 日期 + 规则版本；不消耗 `run_rng` |
| D3-2 | 一天一次 | ✅ 开局即写入 `daily_challenge.json`；同日拒绝重开，续档不重复计次；写盘失败回滚，不外连校时 |
| D3-3 | 固定配置 | ✅ 可见三职业轮换、固定难度 2、该职业标准 13 张初始卡组；战斗奖励仍沿用标准账号规则 |
| D3-4 | 成绩记录 | 🟡 `RunRecord` 已带 `daily_date` / `daily_rules`，每日页有本地高分；战绩页每日/普通分页签未做 |
| D3-5 | Steam 排行榜 | 🟡 每天 + 规则版本独立榜，降序 Numeric、keep-best 上传、读取前十及离线降级已接；自有 AppID 实机验收待做 |
| D3-6 | 入口 | ✅ 「开始游戏」→ 模式选择页；标准模式仍进原选人页，不在标题页堆按钮 |

---

## 5. 线 E：本地化（英必做 / 日次之 / 本体不在本轮）

> **店长定案（2026-11-12）**：英文版**一定要做**，最好还有日文版，**但不是现在**。
> 因此本线分两半：**E0 地基现在就生效**（不占工期，只为不涨价），**E1–E6 排到内容定稿之后**。

### E0 地基（P0，从 R608 起每轮遵守）

| # | 纪律 | 为什么现在就要 |
|---|---|---|
| E0-1 | 新增玩家可见文案统一走取文口，**不再裸写中文串** | R608–R613 每轮都在加文本，晚一轮就多一批回头账 |
| E0-2 | 新数据字段**禁止用中文当枚举值** | 见 E1，这是本作 i18n 最大的坑 |
| E0-3 | `GameBrand` 的 `display_name()` / `footer_text()` 预留按 locale 分支（内部仍返回中文） | 名字 / 厂牌 / 版本串是第一批要翻的，且已发生过一次改名 |
| E0-4 | 新文本必须过 `fit_font_size()` / `fit_text_lines()` | 英文长度约中文 1.5–2 倍，不走自适应口就要返工 |

### E1 真实拦路虎：中文当枚举（实测）

- `cards.json` 里 `kind`（6 个唯一值）/ `class`（4）/ `color`（11）**全是中文当值**。
- 生产代码里 `kind == "盟友"` / `kind == "技能"` / `is_fort()` 这类判断 **81 处**
  （`game_engine` 46 / `battle_scene` 27 / `card_data` 3 / 其余 5），测试里另有 162 处。
- 两条路，**现在不用选**，但别再加新债：
  - 路 A（低风险，倾向）：保留数据中文值，加 `CardText.enum_key()` 单向映射（`盟友→ALLY`），
    只翻显示层，逻辑层一行不动；老存档零迁移。
  - 路 B（干净但贵）：`cards.json` 改英文 key，全库 81 + 162 处判断跟着改，老存档要迁移。

### E2 文本规模（实测，`python tools/_i18n_cost_probe.py`）

| 层 | 待翻量 | 明细 |
|---|---|---|
| `scripts/*.gd` | ≈ **4700 段** | 含 CJK 字面量 15374 段，其中 `test_*` 10666 段是断言不用翻；`game_engine` 1619 / `battle_scene` 1030 / `event_scene` 264 / `game_levels` 170 |
| `cards.json` | **2005** 串 | `name` 316 + `effect_text` 308（唯一 303）+ `traits`/`affixes` 内嵌中文 |
| `relics.json` | **309** 串 | 道具名 / 描述 |
| `stories.json` | **108** 串 | 4 profile + 6 episode 剧情 |

> 卡面正文长度（中文）：308 条，中位 39 字、P90 67 字、最长 341 字 → 最长那条本来就是
> 靠缩字号救的，翻成英文后需要重点盯。

### E3 字体

现只有 `SourceHanSansCN-Bold/Regular`（包内 15.2MB）。假名有，但**汉字是简体字形**，
日文玩家会看出「字不对」（如「直」「骨」「今」）。→ 日文版需 Source Han Sans JP 或全域版，
走字形子集化（只保留用到的字），预估 +3~6MB。

### E4 排版比翻译更重

- 英文平均长 1.5–2 倍 → **303 条 `effect_text` 全要在卡面重验**。
  R602 的 `tools/probe_ui_text.gd`（19 场景 / 82 Label / 94 Button）直接复用，加 `en` / `ja` 两套跑。
- 日文无空格断行，`text_wrap.gd` 要加 CJK 连续段分支，否则会从词中间断。
- 卡面数值徽章 / 字段框 / 顶部圆槽这些几何口不随语言变，但卡名基线按 `em` 比例定位（R602）—— 英文单词更长，需实测。

### E5 流程与验收

- 代码层：CSV/PO → `.translation` + `TranslationServer` + `tr()`；数据层用 `key → text` 表，不复制整份 json。
- 探针：翻译覆盖率（未翻 key 清单）+ 三语截图回归（沿用 `tools/_shot_scenes.gd`）。
- 商店页语言表：English / Japanese / Simplified Chinese。Steam 支持 app 名本地化（中文区《嘎嘎乱杀》/ 英文区 `Quackill`）；**日文名待定**（可直用 Quackill）。

### E6 为什么现在不做（写下来，免得反复讨论）

- 文案还在动：R600 才清过一轮显示层文案、R607 还在改标题页 → 翻早了就是白翻。
- 只要 E0 四条守住，**延后不会涨价**；反过来，若 E0 不守，延后一个月就是几千条回头账。

### E7 英文版收尾实测（2026-11-18，R784）

店长问「英文本地化还没做完？」——实测主体早已完成，真正缺的是**特性（traits）译名**。
本轮已补完，英文版可上商店页。

| 层 | 实测结果 | 工具 |
|---|---|---|
| 卡牌 | 331/331，`name` 与 `effect_text` 全覆盖、零中文残留 | `tools/_i18n_gap.py` |
| 道具 / 职业 | 64/64 道具（含新增 6066 猴爪 = Monkey's Paw） | 同上 |
| 界面 | 源码 629 处 `GameI18n.ui()` 调用全覆盖；7 个「疑似缺」全是动态拼接前缀（`LEVEL_` / `MOD_` 等），en 里完整 key 都在 | 同上 |
| **特性 traits** | **原本 76 条无英文**（卡面特性栏会露中文）→ 已补 76 条英日译名 | `tools/_probe_traits.gd` |
| 卡面排版 | 图鉴逐卡四语刷新：**zh/en/ja/es 全部 ISSUES=0**，英文 5 行完整显示不裁切 | `tools/_probe_gallery_text.gd` |
| 场景排版 | 22 场景仅 1 处溢出 = `Toolbar/StatusLabel`，系 R113 设计好的 `clip_text + 省略号`，非缺陷 | `tools/probe_ui_text.gd -- --lang=en` |

**关键机制**：`GameI18n._lang_chain()` 让 es / ja 都回落到 en，所以**补齐英文即可保证三语都不露中文**。
日文特性名目前大量走英文回落（日文正文本身含汉字，探针的 CJK 判定对 ja 无效，别拿那个数字当缺口）。

**同步清理的历史欠账**：
- glossary 补登记 6066 猴爪、statue 奇异雕像（译文早已存在，只是术语表漏登）。
- 中文底本与三语译文删掉 5 条死 key（`REWARD_TOOL_FULL_*` R755 已换、`GALLERY_SUMMARY_LOCKED` R753 已移除、
  `STORY_GRANTS_BOTH` / `RECORD_MORE_RELICS` 源码无调用），`expected_counts` 同步为
  shop72 / reward123 / map244 / battle80 / shell214 / shared92。
- canonical 术语归一：6027 与 APPLE_DESC 的「最大生命值」→「最大生命」（权威 GDScript / relics.json 原文不动）。
- 验证脚本锁定数随内容更新：noncard 63→64、narrative 26 事件/64 段→27/68、spanish interface 829→825。

**R784 时尚未完成**：西语既定校验范围 41 项；日文部分特性名实际落到英文。
以上两项已由 R788 接续完成，见下节。

### E8 日文 / 西语收尾实测（2026-11-18，R788）

| 层 | 修复与实测 |
|---|---|
| 西语 | 补 9266–9270 五张诗人卡；331/331 卡、64/64 道具；修 4 处 `mazo`、9262 复用 `Golpe`、6048 数字锚点；特性表补 4 条并移除 3 条冗余映射。`validate_spanish.py` **23,043 checks 全绿** |
| 日文特性 | 真因不是缺译文，而是 `_collect_pairs()` 把显式 `ja == zh` 当未译跳过，再被 en 回落覆盖。现仅对 ja 放行同形字段：最终逐源复核的 **9 个实际英文特性→0**，27 个中日同形词正确保留；en / es 判定不变 |
| 共享术语 | 补道具档「稀有」、关卡「计量工坊」、Steam 成就「巅峰之上」及 6 个机制词的英日译名；`validate_glossary.py` 全绿 |
| 事件 UI | 对齐 R756 真源：契约选项/结果写明「咒缚 + 代偿」，占卜费用改 `%d` 动态模板，英日西同步；87 选项 / 67 结果校验全绿 |
| 底本 | `zh_canonical` 补回 9265 懊悔；苹果事件别名跟随「最大生命」规范术语修正 |

**验证**：i18n 专项 **39/0**；特性探针以 ja-only 映射核对运行时来源，en 缺译 0 / ja 直接译文缺失与偏离 0 / es 缺译 0；四语卡面排版全部 `ISSUES=0`；
日文 22 场景 0 溢出，西语仅既有 `StatusLabel` 省略号截断；`TIER_BOSS` 统一为「ボス」；八套回归全绿（engine 6476✓ / smoke 75✓）。
日文字体仍使用简体字形的问题不因译文完成而消失，E3 的 JP 字体子集化仍是独立待办。

---

## 6. 决策点（Q1 已定，其余待定）

| # | 问题 | 状态 / 影响 |
|---|---|---|
| ~~Q1~~ | ~~英文版做不做~~ | ✅ **已定**：英必做、日次之，本体排 R614+；地基 E0 立即生效 |
| Q2 | Steam Deck 目标 | Verified 需手柄映射 / 可读性（M 级）；Playable 成本低但降权 |
| ~~Q3~~ | ~~每日挑战配不配 Steam 排行榜~~ | ✅ **已定要配**：R762 桥接已落地；待自有 AppID 实测建榜、keep-best 上传与前十读取 |
| Q4 | LAN 联机在 Steam 版：保留 / 隐藏 / 升级 Steam P2P | 影响隐私政策、防火墙弹窗、商店页标签 |
| Q5 | 首发带不带 Demo / 走不走 Next Fest | 带 → 额外 depot + 存档隔离 |
| Q6 | 组合补充范围 | 只修 bug + 扩卡（小） vs 加图鉴 / 预览 / 成就（中） |
| Q7 | 日文名怎么定 | 直用 `Quackill` / 片假名 / 片假名+副标；**必须在 store page review 前定** |

---

## 7. 建议批次（轮次制，规模 S/M/L）

| 轮次 | 内容 | 规模 |
|---|---|---|
| R608 | 线 B 全部（名实一致 + 桌面纹理/包体重测 + 预设核查） | M |
| R609 | 线 A1–A3（GodotSteam + 9 成就实机） | M |
| R610 | 线 A5/A6/A7（云存档 + 单实例 + 存档迁移） | M |
| R611 | D1 组合补充（R588 修复 + 候选池 + 扩卡 + 图鉴） | M |
| R612 | D3 每日挑战（含本地榜） | M |
| R613 | D2 新手引导（方案 B） | L |
| R614–R616 | 线 E 本地化：E1 方案落地 + E2 翻译 + E4 排版重验（先英，再日） | L×2 |
| 并行 | 线 C 商店页素材与文案（非代码，越早越好，命名已定死） | — |

> 若只能做一件事：**先 R608 + R609**。桌面包体与成就实机是两个「不做就无法提交」的门。
> **E0 不在批次里** —— 它是从现在起每一轮都要遵守的纪律，不是一轮任务。

---

## 8. 发布前总验收（DoD）

- [ ] 八套回归全绿：assemble 0 / mana PASS / engine 0✗ / reward 0✗ / bgm 0✗ / traps 0✗ / trapinput 0✗ / smoke 0 失败
- [ ] `SteamAchievements.status_text()` = 已连接；8（或 12）成就后台可解锁
- [ ] 干净 Windows 机（无 Godot、无 VC 运行库、路径含中文、非管理员）双击可跑
- [ ] 1080p / 1440p / 4K + 系统缩放 150% 下 UI 不溢出不重叠（`tools/probe_ui_text.gd` 0 溢出）
- [ ] Alt+Tab / Alt+F4 / 休眠唤醒 / 拔音频设备 / 双显示器 均不崩
- [ ] 杀软误报自查（Godot 导出 exe 常见）
- [ ] 存档：损坏恢复、跨机续档、更新后旧档可读
- [ ] 发行包内无 `steam_appid.txt`、无 `_preview` / `_review` / `_bk_*` / `_pending`
- [ ] 商店页：胶囊 5 张、截图 5+、文案中英、AI 披露已填、语言表与实际一致
- [ ] 版本号三处一致（代码 / exe 已 1.0.0，Steam depot 描述待填）；`FOOTER` 已无「开发版」字样
- [ ] （本地化轮）`probe_ui_text.gd` 三语 0 溢出；卡面 303 条 effect_text 全部重验；语言表 = 实际支持语言
