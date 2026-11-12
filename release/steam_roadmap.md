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
| 品牌 | `GameBrand`：中《嘎嘎乱杀》／英 `Quackill`／`risusumai`／`v1.0` | ✅ 已定稿 |
| `GameBrand.FOOTER` | 仍是 `v{v}-rogue · 肉鸽开发版` | ⚠️ 发布前必改 |
| Steam 成就桥 | `scripts/steam_achievements.gd` 完整：8 成就 + `Engine.get_singleton` 反射 + `storeStats` 落盘 + AppID 三级回落 | ✅ 代码就绪 |
| GodotSteam 插件 | **`addons/` 不存在** | ❌ 硬缺口（成就全链路未实机验证） |
| 成就数量 / 层次 | 8 个，全是「进度型」（初见 / 通关 / 难度） | ⚠️ 偏少，缺长尾（组合、图鉴、每日） |
| 导出预设 | Windows Desktop（debug+release）、Android（debug+release） | ✅ 在，但 `export_path` 仍是 `dist/DuckCardsRogue.apk` |
| 桌面纹理 | 卡图 `compress/mode=2` + `high_quality=true`，生成 **bptc + astc 双变体** | ⚠️ 包体账（281MB）是按 Android/astc 记的，**桌面侧未重测** |
| 存档 | `run_save.sav`（局内）/ `profile.json`（玩家）/ `run_records.json` / `run_pending.json` / `save_trace.log`（取证，带时间戳、会涨） | ⚠️ 云存档需白名单，`save_trace.log` 不能同步 |
| 本地化 | **零**：无 `.translation`、无 `TranslationServer`，文案硬编码在 `cards.json` / `stories.json` / 各 `_scene.gd` | ⚠️ 英/日版已定要做（Q1），见第 5 章 |
| 新手引导 | 教程机制代码在（`battle_scene._tutorial` + 7350+ 行引导条），但 **42 个关卡 `tutorial` 全为 `[]`**；且引导条只剩 36..52 共 16px 高度（源码注释明说必须先改版式） | ❌ 休眠态，恢复成本高于「新做一套」 |
| 每日挑战 | 零代码。但 `seed_override` / `seed_code` / `RunRecord` / `record_list_scene` / 难度档位全齐 | ✅ 地基好，单项成本最低 |
| 组合系统 | 唯一入口 `_open_combo()`；候选池 24 张；`combo_trigger` 卡 **仅 2 张**（9246 / 9247）；机械之心可用候选仅 4 张；R588「产物继承 traits / id」**未修** | ⚠️ 保真 bug + 内容面窄 |
| 联机 | `net.gd` 局域网 UDP 广播 + TCP 47812（Python 版移植） | ⚠️ 影响隐私政策 / 防火墙 / 商店页措辞，见决策 Q4 |
| 分辨率 | 1280×720，`canvas_items` + `expand` | ✅ 天然适配 Deck / 各种 16:9 |
| 包体 | 预估 281MB（PCK 236.2 + lib 130 + ogg 28.5 + 字体 15.2） | ⚠️ 桌面 lib 不需要 v7a/arm64 |

---

## 1. 线 A：Steam 技术接入（P0）

| # | 事项 | 要点 | 判据 |
|---|---|---|---|
| A1 | 安装 GodotSteam（GDExtension，对齐 4.3） | 只引 GDExtension，不引 GDNative；`addons/godotsteam/`；**不进 Android 预设** | `SteamAchievements.status_text()` 返回「已连接 Steam」 |
| A2 | AppID 与本地联调 | 用 Spacewar `480` 或放 `steam_appid.txt`（**发行包不带**）；`APP_ID` 常量保持 0 | 本地 status=0；发行包内无 `steam_appid.txt` |
| A3 | 8 个成就逐个实机解锁 | 用测试 build 引信触发 `note_*`；核对后台 API 名大小写完全一致 | Steam 后台显示 8/8 可解锁、`storeStats` 生效 |
| A4 | 成就长尾补 4~6 个 | 建议：首次组合 / 组合产物达 N 种 / 图鉴全收 / 每日挑战首胜 / 无伤过精英 / 单回合斩杀 100+ | 后台 + 代码 `API_*` 两处同名 |
| A5 | 云存档（Steam Auto-Cloud 或 Remote Storage） | 只同步 `profile.json` + `run_records.json` + `run_save.sav`；**排除** `save_trace.log` / `*_test.*` | A 机打一半→B 机续档成功；冲突时取「本地 mtime 新」，且 `save_trace` 有记录 |
| A6 | 单实例互斥 | 双开会抢同一个 `user://`（`run_save` 注释里已有警告） | 第二个进程弹「已在运行」并退出，不产生半截档 |
| A7 | 存档格式版本迁移框架 | 现在 `RunRecord.FORMAT=1`，加字段可空；`run_save` 无版本号 | 用旧档启动不崩、不丢；有 `save_version` 字段 |
| A8 | 桌面端日志与反馈出口 | `--log-file` 落到 `user://`；设置页加「导出诊断包」 | 崩溃后能拿到日志；玩家能一键打包 |
| A9 | Overlay / Deck 自评 | Overlay 默认可用；Deck 评级先做 Playable 诚实自评 | 提交时 Steam 后台填 Deck 兼容性 |

> A1–A3 是关键路径：成就代码已写完但**从未实机跑过**，越早验越安全。

---

## 2. 线 B：发行工程与包体（P0）

| # | 事项 | 要点 | 判据 |
|---|---|---|---|
| B1 | 名实一致收尾 | `FOOTER` 去「肉鸽开发版」；`export_path` 改 `dist/Quackill.exe` / `dist/Quackill.apk`；`description` / `copyright` / `company_name=risusumai` / `product_name=Quackill` | `git grep` 无 `DuckCardsRogue`；导出文件名 = `Quackill.exe` |
| B2 | **桌面纹理变体重测** | `high_quality=true` → bptc + astc；Windows 走 bptc/S3TC。要重跑 `tools/shot_r596g_tex.gd` + `_psnr_r596g.py`（**关 `content_scale_mode`**） | 桌面 PSNR ≥ 45dB；内存 / 首屏加载不劣化 |
| B3 | 桌面包体重算 | 桌面不带 v7a/arm64 两份 lib；PCK 走 bptc 体积与 astc 不同 | 产出真实 `.pck` + exe 体积表，替换「预估 281MB」 |
| B4 | Windows release 预设核查 | 图标用 `assets/ui/icon.ico`；`config/icon` 现指向 `icon_android_legacy.png`（**桌面也用它**，需确认尺寸观感） | 干净机双击可跑，任务栏图标正确 |
| B5 | Steam 构建上传 | `steamcmd` + `app_build_<id>.vdf` + `depot_build.vdf`；只一个 depot（exe + pck） | 上传成功、Steam 客户端能下、能启动 |
| B6 | 版本号单一来源 | `GameBrand.VERSION` = depot 描述 = exe 版本资源 = Steam build 描述 | 三处一致 |
| B7 | 自动更新验证 | Steam 管更新，验证「存档不被覆盖」「更新后旧档可读」 | 手改一个旧版本 → 更新 → 续档正常 |

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

### D3 每日挑战（选做，成本最低的一项）

| # | 事项 | 要点 |
|---|---|---|
| D3-1 | 日期派生种子 | `seed_of("daily", yyyymmdd)` → 固定角色 / 难度 / 地图；不动 `run_rng` |
| D3-2 | 一天一次 | 存档记 `daily_date`；时间回拨只做宽松校验（不外连校时） |
| D3-3 | 固定配置 | 角色、难度、卡组锁定，排除随机开局变量 |
| D3-4 | 成绩记录 | 复用 `RunRecord`（加 `daily: true` 标记）+ `record_list_scene` 分页签 |
| D3-5 | Steam 排行榜（可选） | 需额外 Leaderboard API 桥接；不做则「本地榜」 |
| D3-6 | 入口 | 标题页一个「每日挑战」按钮，不与「开始对战」抢视觉（R579/R607 明确不加副标题/不堆字号） |

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

---

## 6. 决策点（Q1 已定，其余待定）

| # | 问题 | 状态 / 影响 |
|---|---|---|
| ~~Q1~~ | ~~英文版做不做~~ | ✅ **已定**：英必做、日次之，本体排 R614+；地基 E0 立即生效 |
| Q2 | Steam Deck 目标 | Verified 需手柄映射 / 可读性（M 级）；Playable 成本低但降权 |
| Q3 | 每日挑战配不配 Steam 排行榜 | 配 → 多一次 Leaderboard 桥接 + 后台配置 |
| Q4 | LAN 联机在 Steam 版：保留 / 隐藏 / 升级 Steam P2P | 影响隐私政策、防火墙弹窗、商店页标签 |
| Q5 | 首发带不带 Demo / 走不走 Next Fest | 带 → 额外 depot + 存档隔离 |
| Q6 | 组合补充范围 | 只修 bug + 扩卡（小） vs 加图鉴 / 预览 / 成就（中） |
| Q7 | 日文名怎么定 | 直用 `Quackill` / 片假名 / 片假名+副标；**必须在 store page review 前定** |

---

## 7. 建议批次（轮次制，规模 S/M/L）

| 轮次 | 内容 | 规模 |
|---|---|---|
| R608 | 线 B 全部（名实一致 + 桌面纹理/包体重测 + 预设核查） | M |
| R609 | 线 A1–A3（GodotSteam + 8 成就实机） | M |
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

- [ ] 六套回归全绿：assemble 0 / engine 5765+ 0✗ / reward 26 / bgm 39 / smoke 68-0 / mana PASS
- [ ] `SteamAchievements.status_text()` = 已连接；8（或 12）成就后台可解锁
- [ ] 干净 Windows 机（无 Godot、无 VC 运行库、路径含中文、非管理员）双击可跑
- [ ] 1080p / 1440p / 4K + 系统缩放 150% 下 UI 不溢出不重叠（`tools/probe_ui_text.gd` 0 溢出）
- [ ] Alt+Tab / Alt+F4 / 休眠唤醒 / 拔音频设备 / 双显示器 均不崩
- [ ] 杀软误报自查（Godot 导出 exe 常见）
- [ ] 存档：损坏恢复、跨机续档、更新后旧档可读
- [ ] 发行包内无 `steam_appid.txt`、无 `_preview` / `_review` / `_bk_*` / `_pending`
- [ ] 商店页：胶囊 5 张、截图 5+、文案中英、AI 披露已填、语言表与实际一致
- [ ] 版本号三处一致；`FOOTER` 无「开发版」字样
- [ ] （本地化轮）`probe_ui_text.gd` 三语 0 溢出；卡面 303 条 effect_text 全部重验；语言表 = 实际支持语言
