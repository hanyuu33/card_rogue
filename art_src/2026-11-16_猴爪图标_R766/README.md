# R766 猴爪（6066）+ 懊悔（9265）

> 2026-11-16 · 店长原话（**下文口径已按下方修订**，原话保留以便追溯）：
> 「新增道具 猴爪 —— 每场战斗前三个回合，将一张任意其他职业随机卡加入你的手卡，
>   将一张懊悔加入你的卡组；
>   懊悔：1费诅咒。选弃牌区一张其他职业卡消失。次元。」
>
> **口径修订（店长当天追加）**：原文「任意其他职业随机卡」里的「任意」已去掉 ——
> 「任意」+「随机」连用既重复又暧昧（读起来像「可以随便挑」，实际是引擎摇号）。
> 现行四语文案统一为 **「将一张随机其他职业卡加入手牌」**
> （en `a random card of another class` / ja `他職のランダムなカード1枚` /
> es `una carta aleatoria de otra clase`），`relics.json` · `noncard_zh_canonical.json` ·
> `noncard_{en,ja,es}.json` 六处一致，无「任意」残留。

---

## 一、口径拆解（三件事各自只有一个判据口）

| 原文 | 落地口径 | 唯一判据 / 唯一口 |
|---|---|---|
| 「其他职业随机卡」 | 有明确职业归属、且不是玩家当前职业的卡 | `GameEngine._other_class_card()` |
| 「加入你的**手卡**」 | 当场进手牌（满手按既有口径改投弃牌区） | `_grant_to_hand()` |
| 「加入你的**卡组**」 | **永久**卡组（`RunState.deck_ids`），本场抽牌堆不掺 | `RunState.add_card()` |
| 「选弃牌区一张其他职业卡**消失**」 | 从弃牌区抹掉（本场对战移除，不回手牌也不进消耗区） | `regret_pick()` |
| 「次元」 | 既有字段：打出后进消耗区、不进弃牌区 | `affixes: ["次元"]`（复用） |

⚠️ **「其他职业」与「诗」6069 的口径故意不同**：
`_poem_ally()` 把公用卡（class 留空）也算「其他职业」，因为诗吃的是「不是我谱的曲」；
猴爪要的是「从别人家借来的卡」，所以公用卡**不算**。两处各有注释交叉指认，别后来统一掉。

⚠️ **「加入卡组」不是「塞进抽牌堆」**：卡面用的是「卡组」，就是终身那一份。
所以本场战斗抽不到这张懊悔，下一场才见到 —— 这是**设计**，日志里也明说了
（「懊悔」加入卡组（本场抽牌堆不掺））。

## 二、数据

| 表 | 条目 |
|---|---|
| `cards.json` | **9265 懊悔**：`kind=诅咒` · `cost=1` · `affixes=["次元"]` · `target_mode=none` · `color=暗影` · `effect_text="选弃牌区一张其他职业卡消失。"` |
| `relics.json` | **6066 猴爪**：`kind=战斗` · `source=奖励` · `tier=稀有` |

四语文案（按 canonical rules：**手牌**不是手卡、**消失 = 本场对战移除**、**弃牌区**）：

| | 卡 9265 | 遗物 6066 |
|---|---|---|
| zh | 懊悔 · 选弃牌区一张其他职业卡消失。 | 猴爪 · 每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌，并将一张「懊悔」加入卡组。 |
| en | Regret · Choose a card of another class in the discard pile. It is Banished. | Monkey's Paw · At the start of each of the first three turns of every battle: add a random card of another class to your Hand, and add a Regret to your Deck. |
| ja | 後悔 · 捨て札置き場から他職のカード1枚を選ぶ。それは消滅する。 | 猿の手 · 戦闘ごとの最初の3ターン開始時：他職のランダムなカード1枚を手札に加え、デッキに「後悔」を1枚加える。 |
| es | Arrepentimiento · Elige una carta de otra clase en la pila de descarte. Se destierra. | Pata de mono · Al inicio de cada uno de los tres primeros turnos de cada combate: añade una carta aleatoria de otra clase a tu mano y añade un Arrepentimiento a tu mazo. |

## 三、引擎（`scripts/game_engine.gd`）

- 常量：`MONKEY_CLAW_RELIC_ID=6066` / `MONKEY_CLAW_TURNS=3` / `REGRET_CARD_ID=9265`
- `_other_class_card(c)` / `_random_other_class_card()`（走引擎 `rng` → 同种子同结果、回放可复现）
- `_claw_tick()`：接在我方回合开始、**抽牌与耳环自动出牌之后**
  （手牌状态已稳定，不会出现「先塞一张再抽牌」把满手判定算在两套口径上）。
  每回合**现问** `turn_number`，不另存计数器 → 读档续战 / 重开都对得上。
- `regret_pending` + `regret_options()` + `regret_pick(discard_index)`
- 出牌分支 `REGRET_CARD_ID`：弃牌区没有其他职业卡 → 白打、不开面板（不会卡在选卡页）
- 三处 pending 守卫：`use_spell` 开头 / `_instinct_panel_open` / 失眠抽牌

## 四、界面（`scripts/battle_scene.gd`）

照乌鸦（crow）那套五处接线原样复制，只换结算口与文案：
`_pick_active_kind()` → `_build_pick_cfg()` → 确认分发 `regret_pick()` →
右键/取消守卫（必须选一张）→ 结束回合守卫（把面板弹回来）→ 结束回合按钮禁用 → action 分发。

## 五、图标

`assets/ui/relic_icon_6066.png`（128×128 透明，codex 纯文生图）。

第一版（`prompts/claw.txt`）画的是细长垂挂的爪臂，128 方画布里**只占宽 37%**，
与 `relic_icon_6065 / 6069` 并排明显偏小。第二版（`prompts/claw_compact.txt`）把三根指头
**蜷进掌心收成团状**，并把「宽高比接近 1」「不要细长垂挂」写进 prompt，
出来 76×122、覆盖率 35.8%，视觉重量与同族对齐 → 定稿。

> 这是「图标要按目标显示尺寸验收」的又一次实践：细长物在方形图标格里天然吃亏，
> 得改**构图**而不是缩放到更大。

## 六、验收

| 项 | 结果 |
|---|---|
| `_verify.py` | **八套全绿**：engine **6252✓ 0✗**（+24 条 R766 断言）/ reward 26 / bgm 39 / traps 183 / trapinput 70 / smoke 75 / assemble 0 / mana PASS |
| 实机截图 | `tools/_shot_r766_regret.gd` → `_shots/r766_regret_pick.png`（选卡页只列 2 张别职业卡，本职业 8018 被过滤） |
| 计数收口 | 图鉴 325→326 · 玩家 247→248 · 公用 26→27 · 道具 63→64（engine 与 reward 两套各改一处） |

### R766 断言覆盖（24 条）

数据在库（3）· 「其他职业」判据三连（本职业 false / 别职业 true / 诅咒 false）+ 公用卡 false（4）·
前三个回合各发一张 + 第 4 回合停手 + 外来卡只进手牌不进抽牌堆（6）·
没这件道具时一张不发（2）· 懊悔候选只列别职业、选中即消失、结算收口（5）·
弃牌区没有别职业卡时白打（1）· 选卡期间不许出别的牌（1）· 其余为文案与边界。

## 七、复现

```bash
P="C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
"$P" -X utf8 tools/_patch_r766_data.py     # 数据（已跑；有 assert 防重复）
"$P" -X utf8 tools/_patch_r766_engine.py   # 引擎（同上）
"$P" -X utf8 tools/_patch_r766_ui.py       # 界面
"$P" -X utf8 tools/_patch_r766_ui_fix.py   # 界面接缝修正（L() 不补前导换行）
"$P" -X utf8 tools/_patch_r766_test.py     # 测试段
"$P" -X utf8 tools/_patch_r766_counts.py   # 计数收口

# 图标
cd art_src/2026-11-16_猴爪图标_R766
"$P" -X utf8 _run_codex.py claw_c
"$P" -X utf8 _finish.py --write
```

## 八、踩到的两个坑

1. **`L()` 只做 `"\\r\\n".join`，不补前导换行** —— 界面补丁 C/D/E/G 四处把新块直接粘在了上一行末尾，
   解析器报 `Expected end of statement after expression`。补丁脚本里凡是「在新块前插入」的，
   要么第一个元素留 `''`，要么显式加 `\r\n`。（`tools/_patch_r766_ui_fix.py`）
2. **`game_engine.gd` 是 CRLF**：写回时必须 `newline="\r\n"` 或直接写 bytes，
   否则整个文件变成 20407 行全量 diff（行尾全 LF）。改完先 `git diff --stat` 看一眼行数。
