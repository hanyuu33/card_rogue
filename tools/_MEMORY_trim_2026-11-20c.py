# -*- coding: utf-8 -*-
"""R840 记忆压缩 v3：MEMORY.md 10.2k（注入 ~10.4k 就截断，末尾两条被砍）。

做法（不是换措辞，是真减字数）：
1. UI 细则（角标取数口 / 浮层 CanvasLayer / 点自身）→ 迁进 `MEMORY_UI.md`，本体留指针；
2. 文本细则（四个口 / 卡面两源 / 道具 desc 五处）→ 迁进 `MEMORY_MECHANICS.md`，本体留指针；
3. 原文整份备份到 `_bk_MEMORY_pre_trim_2026-11-20b.md`（压缩删的是叙述，不是事实）。
"""
import io
import os

P = r"E:/work/.workbuddy/memory/MEMORY.md"
UI = r"E:/work/.workbuddy/memory/MEMORY_UI.md"
ME = r"E:/work/.workbuddy/memory/MEMORY_MECHANICS.md"
BK = r"E:/work/.workbuddy/memory/_bk_MEMORY_pre_trim_2026-11-20b.md"

# ---------- 要迁出的片段（原文照抄，逐字断言）----------
TO_UI = """
## 迁入 · R840（原 MEMORY.md「机制与文本」段）

- **浮层要盖住兄弟面板只能挂 `CanvasLayer`**；删字段类机制三处齐清（读 / 写 / `_move_key`）。
  点自身（R748）：`_on_board_click` 的 `if cell == src: return` 夹在 move 之后、`_cancel_armed` 之前。
- **`_draw_string_center()` 自带 `px*0.36` 基线补偿（R809）**：传文字视觉中心即可，别再按字高手动偏移。
- **道具计数角标唯一取数口 = `RunState.relic_badge_text()`**（R809）：lucky7 生效回合不画、
  火柴 0 也画、已耗尽 `""`；第二参 `clock_left := -1` **只给「计数活在引擎里」的道具**
  （目前仅缺陷时钟 6084），由 `battle_scene._draw_relic_badge()` 传 `engine.defect_clock_left()`。
  ⚠️ **绝不把引擎计数复制一份进 RunState**（读档续战后角标与实际触发两套账）。
  **R836（用户口径）：缺陷时钟 `clock_left == 0`（本场已触发）也不画** —— 是「火柴 0 也画」的例外
  （写「0」会被读成「还差 0 张」）；下一场新引擎复位，角标自然回来。
"""

TO_MECHANICS = """
## 迁入 · R840（原 MEMORY.md「机制与文本」段）

- **文本四个口（R833 全量对齐）**：① `cards.json`＝玩家看到的卡面中文；
  ② `i18n/zh_canonical.json` / `noncard_zh_canonical.json`＝译文母本；
  ③ `i18n/cards_*.json` / `noncard_*.json`＝按 id 的译文；④ 组合动作 `assemble_rules.effect_text()`＝组合产物卡面。
  **①必须与②逐字相同、④必须与①对齐**（`test_assemble._fx_in_text` 保真锁）。
  统一术语：手卡→手牌、弃牌堆→弃牌区、生命值→生命、一回合行动两次→每回合可以行动两次；
  **「卡组 → 抽牌库」要逐张确认**（`state.deck` 战斗待抽区 vs `RunState.deck` 本局构筑）。
  体检 `python tools/_audit_text_sources.py`（A~G 全 0），`_test_r833()` 拦回潮。
- **卡面文本两个源（R831）**：静态 `cards.json`（图鉴 / 未成长时）与动态引擎函数
  （如 `_charge_up_text()`）必须同改，否则只有成长后才看到旧口径。
- **道具 desc 显示源**：`RelicData.desc = GameI18n.relic_desc(id, relics.json.desc)` ——
  中文读 `relics.json`，英/日/西读 `noncard_{lang}.json`（缺则回退 en 再回退中文）。
  改文案要 `relics.json` + `noncard_zh/en/ja/es` **五处齐改**。
"""

NEW = """# card_rogue 长期笔记（E:/work/card_rogue）

> 只放铁律 + 当前状态。细则：`MEMORY_ROUNDS.md`（逐轮）/ `MEMORY_RULES.md`（压缩归档）/ `MEMORY_MECHANICS.md`（机制 + 文本四口）/ `MEMORY_UI.md`（界面绘制细则）/ `ART.md` / `YYYY-MM-DD.md`。
> 本体有注入上限（**10.1k 就会在末尾被砍**）→ 新内容只写 ROUNDS / 当日日志，细则写分册，别往本体堆。

## git

- 开工 `fetch`；绝不 force；只 add 自己文件，逐 hunk 看 `git diff --cached`。
- **轮次号会被并行线抢** → 认号看 `origin/main`；同号 `func _test_rXXX()` 让 GDScript 直接解析失败。
- **`git commit -- <paths>` ≠ 按 index 提交**（重 add 工作区、丢 `update-index --cacheinfo` 的 blob，R780b 删过别人分支）→ 临时索引 + `commit-tree`（模板 `tools/_commit_r780b2.py`），提交后 `git cat-file -p HEAD:<file>` 逐字节比。
- 主仓落后远端**别** `reset --mixed origin/main`（R797c）→ `worktree add /e/tmp/wt_push origin/main` → 拷文件 → commit → `push origin HEAD:main`。**跑回归期间绝不 stash**（R798）；**worktree 里提交未推 ≠ 安全**（R794 被并行会话删过）→ push 才算安全，取号后与 push 前各 `fetch`。
- 撞号：`git diff` 认 hunk → 按 `@@` 切 → `git apply --cached --recount` 只动索引；要追远端先 `commit` 再 `rebase origin/main`（不 stash / 不 reset），冲突只在「同一处追加」＝两侧全留；auto-merge 的 JSON 必须 `json.load()` 验、`validate_spanish.py` 条数逐条核。
- ⚠️ **并行线 `commit -a` 会捎走你未提交的改动**（R835 把 `game_engine.gd` 空故事书带进 49 行）→ 推前 `git show origin/main --stat` + `git show origin/main:<文件> | grep <自己的标识>`，只补剩下的；别拿「`git status` 不是 M」当「没改过」。
- ⚠️ **worktree 重放别拷自己已改过的文件**（R835 `run_save.gd` 二次插入）→ 拷**脚本**、原文件从 `HEAD`/`origin/main` 取，跑完 `grep -c` 确认只有 1 份。

## Godot / 打包 / 回归

- **备份目录必带 `.gdignore`**（`_bk_*` / `_pkg_hold/`）：副本 `class_name` 抢注缓存 + 被 export 排除 → APK 全脚本解析失败（黑屏）。加完 `rm .godot/global_script_class_cache.cfg` + `--editor --quit-after 2500` 重扫。
- `static var` 不许拿自身 `class_name` 当类型注解；新增 `class_name` 先 `--headless --path . --import`。
- 行尾**用 python 数字节**（Git Bash 的 `grep $'\\r'` 骗人）；`core.autocrlf=false`；CRLF = `battle_scene / card_data / field_state / game_engine / game_levels / placement / test_engine / test_smoke` + `cards.json` + `title.tscn` + 两个 `.bat`。⚠️ **Edit 会整篇转 LF**。
- 补丁一律 Write 成 `.py` 再跑（here-doc 吃双反斜杠）：exact-replace + `assert count==1`，锚点先 dump `repr`；CRLF 块要 `.replace("\\n","\\r\\n")`；GDScript 禁 `\\` 续行；**格式串裸 `%（` 必须写 `%%`**（否则该行 print 静默并到上一行）。
- 新素材（png + `.import`）后 `git status` 复核 + 跑一次 `--import`；读源码文本的断言必须 `check_src()`（导出包 `.gd` 是 binary tokens）。
- 回归 `python _verify.py`（**10 套**：assemble / mana / engine / reward / bgm / traps / trapinput / content / mod / smoke）：跑前备份 `app_userdata/卡牌肉鸽`（`profile.json` + `run_save.sav`），跑完逐文件还原 + `RESTORE_VERIFY`。末行「有失败」≠ 真红，**先 `grep ✗` 看是不是本轮**（工作区常有并行线半成品）。
- 出包 `python _release.py` / `bash release/build_apk.sh <纯数字>`，只认「0 失败」；`_preview/_review/_pkg_hold/_bk_*/_pending` 必带 `.gdignore`，`art_src/` 有意入库。

## 版本口径

- **发布版唯一闸门 `GameBuild.is_release()`**（tag `cardrogue_release` / `--release`）；**试玩第三档 `is_demo()`**（`cardrogue_demo` / `-- --demo`，`is_release()` 首行对 demo 短路 false）。解锁体系的新内容一律挂闸门之后。
- **试玩口径（R817）＝「修复跟着走、新增不跟着走」**：老 id 改数值 / 修 bug / 换文案自动同步（同一份 json），新卡 / 道具 / 工具 / 事件默认不进。落地 `demo_scope.json`（`demo_scope.gd` 唯一读口；卡 120 / 道具 84 / 工具 16 / 事件 24）；判据：卡 `CardRepo.demo_allows()`、道具 `RelicRepo._demo_ids()`、工具 `TrapRepo.all_traps()`、事件 `GameLayers.event_weights()`。**道具是「全部登陆」→ 新道具必须同时进表**（`_test_r817` 钉着「基线 == `all_relics()`」）。
- **「进了基线表」≠「试玩发得出来」（R834）**：`DemoScope.allows_relic()` 锁不住池子被裁 → 新道具要在 `GameBuild.set_test_demo(1)`（用完**必须复位 -1**）下按**真实发放池**再核；起点三选一读 `start_ids_for_layer()`（只查 `layer2_ids_for()` / `initial_ids()` 会漏场景那层）。
- **试玩打包**：预设 `Windows Desktop Demo` / `Android Demo`（`custom_features=cardrogue_demo`，出 `Quackill_demo.*`）；`_release.py --demo`（与 `--release` 互斥）、`build_apk.sh <轮次> demo`；demo 强制双文件 + 随包 `content/`。
- **试玩四道闸**：难度 ≤ **1**（`difficulty_cap` 与 `global_max_difficulty` 两处）、职业白名单 `UnlockSystem.DEMO_CLASSES`、剧情恒不解锁（`is_story_unlocked` / `is_card_unlocked` / `is_relic_unlocked` **三处都短路**，漏一处剧情卡就漏进池 —— 鹅 9187）、二层 Boss 即「胜利？」（复用 run_summary 判据）。
- ⚠️ **数内容条数绝不能用 `reward_pool_for()`**（含账号禁卡过滤）→ 用 `obtainable_cards()` + `card_class == cid`。**凡 `if GameBuild.is_release():` 的防御代码，加新档时逐个回看**（`start_run` / `class_pick` 就这么漏的）。
- **新增道具 / 工具 / 界面键要同步三处校验器**：`i18n/glossary.json`、`interface_zh_canonical.json` 的 `expected_counts.<scope>`、`validate_spanish.py` 写死条数 —— 都**不在十套里**，手动跑 `i18n/validate_*.py`。**`l10n.gd` 每条都要有西语**（`l10n_es.json` key 集合一致，写死 73）。
- **`tier` 不只是展示**：`roll_reward_relic()` 先摇 `legendary_chance()`（5% × 层，大宝箱 ×2 / Boss ×3）命中才走传奇池；改 tier 会连带红 3~4 条写死件数的断言。`RELIC_TIERS` 只有「一般 / 传奇」→ `relics.json` 写「稀有」的被 `normalize_tier` 归进一般（猴爪 6066）。
- **新增道具第四处最易漏：`relic_repo.reward_ids()` 那份硬编码 id 数组**（R805 蜂蜜：效果全对但抽不到），连同 `test_engine` 的「奖励池 N = 一般 X + 传奇 Y」一起改。
- 每日修饰只走 `DailyModifiers.fx_of()`（**必须进 `RunSave`**），卡组走 `_daily_pool()`；改池子 / 卡组同升两处 `RULES_VERSION`。精英强弱唯一判据 `RunState.elite_tier_for_chocolate()`；转场唯一收口 `SceneFx._swap_now()`。

## 机制与文本

- **按「节点 id」记账的局内状态，换层必须清（R837）**：每层地图 id 都是 0..34 **重号** → 账本留着就把新一层同号房间当「已记过」吞掉（空故事书 6089：12 个种子 9 个少算 1~4 页）。换层三件套＝`cleared_ids` / `seen_ids` / 自己那份账本，同在 `advance_layer()` 清；收口 `RunState.story_book_new_layer()`。
- **能靠「退出再进」重试的随机结果，一律由 `seed + layer + node` 派生**（R819 占卜室 / R822 鸭绅士）：`_div_stage` 这类字段一退出就归零，反复重进能重摇。收口 = `RunState.divination_roll_for()`（不摇 rng、不进存档、同房间同结果）。
- **规则类逻辑要查所有入口**（R815）：R192「第一层起点邻居不得是 ? 房」生成期写死 `hidden=false`，骰子重摇是另一条路把它掀了。凡「同一件事两个实现口」各测一遍。
- **格子级「不可使用」（大蒜 7017）= `FieldState.sealed_cells` 独立表**，绝不进 `trap_fields`（那是「踩到触发」）；连 **AI 的 4 条距离估算**一起挡（`_walk_search` / `_wall_depth` / `_engage_distance` / `_hp_pos_distance`），否则 AI 算得到、走不到，白掉一个行动。
- **死亡收尾**：`_hit_unit()` 只扣血；收口在 `end_turn()` 的 `_overload_tick()` 之后 `_destroy_dead()`，以及 `_trap_path_check()` 循环外一次。
- **卡牌实例身份**：进手牌 / 换实例必走 `_own_card()` / `_new_own_card()`；体检 `tools/check_card_own_copy.py` 高危须 0。**卡色＝元素族**：`color` 只写 火/冰/雷/毒/暗影/圣光/自然/物理/水风 或空串，唯一口 `FxArt.family_of()`。
- **道具判据一律 `RunState.has_relic()`**。`self_relics` 是引擎快照（只在构造 / 读档填）：测试只设 `RunState.relics` 时它是空的 → 判断静默失效；`_new_engine()` 也不填 → 每个道具测试引擎补 `eng.self_relics = RunState.active_relics()`（R810 六条假红）。例外：`engine.relic_highlight()` 读的就是它。
- **GUI 结果行写固定串，绝不插 `%s`（R807）**：`GameI18n.source()` 靠中文原文精确匹配，塞动态名字会让英日西永远回落中文；动态名放到按 id 取译名处（奖励页 / 图鉴）。
- **文本四个口 / 卡面文本两个源 / 道具 desc 五处齐改 → 见 `MEMORY_MECHANICS.md`「迁入 · R840」**。改动后必跑 `python tools/_audit_text_sources.py`（A~G 全 0）+ `_test_r833()`。
- **界面绘制细则（角标取数口 `relic_badge_text()` / 浮层挂 `CanvasLayer` / `_draw_string_center` 基线补偿 / 点自身判定）→ 见 `MEMORY_UI.md`「迁入 · R840」**。
- **mod 层三层顺序固定（R816）**：pck → 官方热更 `content/`（整份替换）→ mod 目录（按 `id` 深合并）；素材层反过来「先查 mod」。mod 新内容号段从 **90000** 起。编辑器与回归默认不扫 `user://mods`，要测设 `CARDROGUE_MODS_DIR`；启停存 `user://mods.cfg`（只记停用的）。

## 环境与工具

- Godot：`C:/Users/Administrator/.workbuddy/binaries/godot/Godot_v4.3-stable_win64_console.exe`（PATH 无 `godot`）。安卓 SDK `~/AndroidDev/android-sdk`，AVD `cr_test`；`build_apk.sh "" test` → `adb install -r -g`。拖拽换算：列表 `ROW_H`(76)、正文 `BODY_LINE_H`(26)，不许共用。
- **美术素材一律委托 codex 出图，不用代码 / SVG 硬画图案（店长 R839b 口径）**。程序化图案只作「没有 png」的兜底：`assets/ui/trap_icon_<id>.png` 一落盘，`TrapArt` 自动改走贴图，界面代码一行不动。
- **AI 出图走 codex**：`codex exec --json --skip-git-repo-check -C <repo>` 读 stdin 的 prompt（`-i` 带参考图），图落 `~/.codex/generated_images/<thread>/exec-*.png`，**必须由脚本抄出来**；代理 Clash `http://127.0.0.1:7897`；**一张图一次会话**，单张 220~300s。codex 会往 `HANDOFF.md` 追加交接 → 提交前 `git checkout HEAD -- HANDOFF.md`。模板：`art_src/2026-11-15_吟游诗人CG_R761/_run_codex.py`；单物件图标照 `art_src/2026-11-20_大蒜图标_R839b/_run_garlic.py`（prompt 写成纯英文 `.txt`，设计口径另放 `README.md`）。
- **codex 出 UI/特效素材三坑（R836）**：① 抠图不能按亮度（米白 `#EFE6D2` 与白底差一点）→ 走 R755 `_bg_mask` 边缘泛洪；② `from _make_r755_icons import _bg_mask` 会**执行那个模块主流程**（无 `__main__` 保护，会重写两张 assets/ui 图标）→ 复制函数或先加保护；③ 连续旋转的指针 / 齿轮**别用贴图转**（像素偏移 + 锯齿 + 刻度对不准），代码画角度；旋转轴程序测质心（钟面轴座偏 +6,+9）。
- 写 prompt 纪律见 `ART.md`（赛璐璐 / 参照图传染头身比 / 可数硬约束 / 可见带 268px）。**prompt 风格段写反了比不写更糟**（R807「厚涂、不要描边」→ 照片级写实布偶）。出图口两坑（R802）：`--lang=en` 只在配置文件存在时生效；非 headless 跑图前必须 `--import`（否则贴图静默空白）。生成图两固定毛病：棋盘格伪透明、右下角水印。
- **美术定稿权只在店长**：多版本取最新，不评判、不提议换版、不主动出包、不动未要求的卡图。别再动 `bg_*`/`map_bg_*`/`battle_bg_*`、`panel/scroll_parchment`、`side_*`（除 `side_statue`）、`relic_*`/`affix_*`/`shop_icon_*`、卡图；别开 VRAM 压缩。

## 当前状态（2026-11-20 · R819~R839 已推送 · 远端 main = 5608144c）

- 基线：engine **7032✓** / reward 26 / bgm 39 / traps 225 / trapinput 77 / content 15 / **mod 37** / smoke **77** / assemble 0 / mana PASS。道具 **84**（`reward_ids()` 41 条扣 5 件剧情锁 = 一般 30 + 传奇 6 ＝奖励池 36）/ 工具 **17** / 卡 **344**（图鉴可见 337）/ 事件 30 组（二层池 16）/ 界面条数 836。试玩：卡 120 / 道具 84 / 工具 16 / 事件 24。一层初始池 12 件。
- 号段：道具 **6089**、工具 **7017**、卡 **9283**、轮次 **R839**；新号 6090 / **7018** / 9284 / **R840**（R831~R838c 全是修文案 / 显示 / 锁测试 / 演出 / 计数，不占新号）。
- **存档写盘三处硬规则（R825）**：战斗完整结算后覆盖检查点；奖励成交当刻直存（不能只靠 `_process()`）；商店先发货再 `_sync_shop_state()`。Boss 有待领奖励时不许自动换层；恢复货架用 `_row3_template(true)`。
- **二层主持人（R822）**：卷卷 / **鸭绅士**权重相等，`RunState.layer2_host()` 按种子派生（`hash("%d:layer2host") % 2`，不摇 rng、不进存档）。二层起始 12 件按主持人分池（`duck_host_ids()` 6 抽 3；礼帽 6087 是「非鸭但归鸭绅士」特例），判据只在 `layer2_ids_for(host)`。
- **事件图文（R802）**：有 `bg_<kind>.png` 就不叠 `event_<kind>.png`；背景给对话框留位（y≈265..595 / x≈190..890），主体在上半、下方 45% 只留雾。
- ⚠️ 工作区常有不属于我的未提交：`mana_headless.log`、`_audit_card_color.*`、`.trailer_game.log`、`tools/_bin/`、`release/trailer`。别整文件 add。
- 显示唯一口：`RunState.difficulty_label(d=-1)`、`PlayerClass.display_name_of(cid)`。⚠️ `DIFFICULTY_NAMES/TEXTS` 仍是中文常量，glossary 有 en/ja、缺 es。
"""

old = io.open(P, encoding="utf-8").read()
if not os.path.exists(BK):
    io.open(BK, "w", encoding="utf-8", newline="").write(old)
    print("backup ->", BK)

# 断言：迁出前的原文确实还在旧版里（防止重复迁移）
for frag in ("道具计数角标唯一取数口", "文本四个口（R833 全量对齐）", "_draw_string_center()"):
    assert frag in old, "旧版缺少片段：%s" % frag

io.open(P, "w", encoding="utf-8", newline="").write(NEW)
with io.open(UI, "a", encoding="utf-8", newline="") as f:
    f.write(TO_UI)
with io.open(ME, "a", encoding="utf-8", newline="") as f:
    f.write(TO_MECHANICS)

print("MEMORY.md  %d -> %d chars (saved %d)" % (len(old), len(NEW), len(old) - len(NEW)))
