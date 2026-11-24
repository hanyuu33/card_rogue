# -*- coding: utf-8 -*-
"""R807 记忆更新：MEMORY.md（CRLF）+ MEMORY_ROUNDS.md（LF）+ 2026-11-18.md（LF）。"""
import io
import os
import sys

M = os.path.dirname(os.path.abspath(__file__))
if not os.path.basename(M) == "memory":
    M = "E:/work/.workbuddy/memory"


def rw(name, eol, pairs):
    p = os.path.join(M, name)
    s = io.open(p, "rb").read().decode("utf-8")
    for old, new, cnt in pairs:
        o = old.replace("\n", eol)
        n = new.replace("\n", eol)
        c = s.count(o)
        if c != cnt:
            print("FAIL %s count=%d expect=%d\n  %r" % (name, c, cnt, old[:80]))
            sys.exit(1)
        s = s.replace(o, n)
    io.open(p, "wb").write(s.encode("utf-8"))
    print("OK   %s" % name)


E = "\r\n"

rw("MEMORY.md", E, [
    ("## 当前状态（2026-11-18 · R804 已推送）",
     "## 当前状态（2026-11-18 · R807 已推送）", 1),

    ("- 基线：engine **6668✓** / reward 26 / bgm 39 / traps 206 / trapinput 77 / content 15 / smoke 75 / assemble 0 / mana PASS；道具 **75** / 工具 16 / 奖励池 **32（一般 26 + 传奇 6）** / 图鉴 336。",
     "- 基线：engine **6682✓** / reward 26 / bgm 39 / traps 206 / trapinput 77 / content 15 / smoke 75 / assemble 0 / mana PASS；道具 **75** / 工具 16 / 奖励池 **32（一般 26 + 传奇 6）** / 图鉴 **337** / 事件 30 组（第二层池 16 种）。", 1),

    ("- 号段：道具 **6080**、工具 **7016**、卡 **9275**、轮次 **R806**（新号 6081 / 7017 / 9276 / **R807**）。",
     "- 号段：道具 **6080**、工具 **7016**、卡 **9276**、轮次 **R807**（新号 6081 / 7017 / 9277 / **R808**）。", 1),

    # git 铁律：撞号
    ("- worktree 提交未推 ≠ 安全（R794 的 worktree 被并行会话整个删过，靠共享对象库找回）—— **push 才是安全**。取号后、push 前都要再 `fetch`。",
     "- worktree 提交未推 ≠ 安全（R794 的 worktree 被并行会话整个删过，靠共享对象库找回）—— **push 才是安全**。取号后、push 前都要再 `fetch`。\n"
     "- **轮次号会被并行线抢（R807 踩）**：本地按 R805 干到一半，`origin/main` 上已经有 R805 蜂蜜 / R806 法术卷轴。光改编号不够 —— `test_engine.gd` 里再出现一个 `func _test_r805()` 就是**同文件同名函数，GDScript 直接解析失败**。开工 `fetch` 后先 `git log --oneline -5 origin/main` 认号，别只看本地。\n"
     "- 落后远端又要带上自己的提交 → 先 `git commit` 再 `git rebase origin/main`（别 stash、别 reset）。冲突只会出现在「同一处追加」的文件（本轮只有 `test_engine.gd` 的两处函数追加点，规则＝两侧全留）；auto-merge 过的 JSON 必须 `json.load()` 一遍，`validate_spanish.py` 的条数逐条核。", 1),

    # 机制铁律：GUI 结果行固定串
    ("- **文本三处齐改**：`effect_text` 只写本卡效果",
     "- **GUI 结果行写成固定串，绝不插 `%s`（R807）**：`GameI18n.source()` 靠中文原文的「全串精确 / 逐行 / 模板」匹配，行里塞动态名字（道具名、数值）会让英日西三语那一行永远回落中文。要显示动态名，就放到本来就按 id 取译名的地方（奖励页 / 图鉴）。\n"
     "- **文本三处齐改**：`effect_text` 只写本卡效果", 1),
])

ROUNDS = """
## R807：诅咒娃娃 9276 + 第二层事件「诡异洋房」（事件池 16 种）

> 店长口径：「新增事件 诡异洋房。选项1：探索。获得一个随机**传奇道具**和一组**史诗卡牌**奖励
> （在事件中立即打开一个奖励页面来领取道具和卡牌，注意要一个没有战斗胜利标记的页面。），
> 将一张诅咒娃娃加入你的卡组。选项2：离开。」
>
> ⚠️ 本轮原定 R805，远端并行线已占 R805（蜂蜜 6079）/ R806（法术卷轴 6080）→ 撞号，
> 全量重编为 **R807**（同名 `func _test_r805()` 会让 GDScript 直接解析失败）。

### 诅咒娃娃 9276（图鉴 336 → 337）

- `kind:"诅咒"` / `rarity:6` / `unplayable:true` / `affixes:["保存"]` / `color:"暗影"` / cost 0 / `class:""`。
- 回合结束　`_curse_doll_tick()`（排在 `discard_hand()` **之前**）：手上有 N 张 → `_damage_player(SIDE_SELF, 3*N, "诅咒娃娃")`。
- 回合开始　`_curse_doll_return()`（排在抽牌 / `_egg_hatch_tick()` **之前**）：它在弃牌区就 `_grant_to_hand()` 爬回来。
- 手牌满时留在弃牌区（`_grant_to_hand()` 不静默消失、不破 `FieldState.HAND_LIMIT`）。
- 「甩不掉」三层：`保存` 让它常驻 → 每回合扣 3；玩家丢进弃牌区只躲一次 → 回合开始自己爬回来；手牌满也不吞。

### 事件「诡异洋房」haunted_house（第二层）

- `_on_main()` 第一分支 → `_explore_haunted_house()`：
  `RunState.roll_legendary_relic()` → `queue_relic_reward()` → `queue_card_reward("epic", [], "event")`
  → `RunState.add_card(9276)` → **直连 `_reward_panel.open()`** → 按钮收成「离开」。
- 「没有战斗胜利标记」＝**不经过 `_present_win_panel()`**（战斗链路才会先出金框「战斗胜利」+ 金币，
  点「查看奖励」才 open）。事件页 `_ready` 里本来就 `RewardPanel.attach(self, Vector2(12, 40))`，直接复用。
- `_reward_panel.open()` 读的是 `RunState.pending_rewards` → **必须先 queue 再 open**，空队列开出来是空页。
- 只探索一次：`_house_done` 置真后同键变「离开」；结果行留 `_house_result`（重绘要能复现）。
- 收益是全场最高档（传奇 + 必定史诗），代价只有一张诅咒卡 → 只放第二层。
- `RunState.roll_legendary_relic(exclude)`：**只从传奇档取**，取不到返回 **-1**（不回落一般池、不假装传奇），
  调用方据此换文案（`EXPLORED` / `EXPLORED_NO_RELIC`）。

### 文案 / 计数

- `narrative_*` 四语：`events.haunted_house`（name + `HAUNTED_DESC` 6 行 + `HAUNTED_TAKEN_DESC` 7 行）。
- `event_ui_*` 四语：`options.haunted_house.{EXPLORE,LEAVE}` + `results.haunted_house.{EXPLORED,EXPLORED_NO_RELIC}`。
- **结果行是两条固定串**，道具名只在奖励页出现（`%s` 会让三语落空，见 MEMORY.md 机制条）。
- `glossary.json` 的 `events` 必须补一条 —— `validate_narrative` 从 glossary 反查 key，漏了直接 KeyError。
- 计数：event_ui **97→99 / 71→73**、narrative **29→30 / 72→74**、spanish **336→337 / 176→180**。

### 素材 / 基线 / 提交

- 卡图 `assets/pics/9276.png`（448×404，dy=0，可见带内主体完整）；背景 `assets/ui/bg_haunted_house.png`
  （1280×720 RGB，下方 48% 只留雾、无物件 —— 给 y≈265..595 的对话框让位）；归档
  `art_src/2026-11-18_诡异洋房与诅咒娃娃_R807/`（prompt + raw + processed + `_compare3`）。
- 九套全绿：engine **6682**（R807 自身 +14 条；总数含远端 R805/R806 的 31 条）/ reward 26 / bgm 39 /
  traps 206 / trapinput 77 / content 15 / smoke 75 / assemble 0 / mana PASS。
  i18n 六器全绿：`cards=337 / relics=75 / event_ui=180 / events=30·74`。
- 提交 `ed047f4`（`git commit` 后 `rebase` 到远端 `c459f76` 之上；冲突仅在 `test_engine.gd` 的两处函数追加点，两侧全留）。
"""

DIARY = """
## R807 诡异洋房 + 诅咒娃娃（撞号 → 重编 R807）

店长这轮两件事收尾：① 连斩卡图采纳 b 版（已在 R804 推）；② 新事件「诡异洋房」＋新诅咒「诅咒娃娃 9276」。

**设计要点**
- 诅咒娃娃＝「甩不掉的账单」：`保存` 常驻手牌 → 回合结束每张扣 3；丢进弃牌区只躲一次 → 回合开始爬回手牌；
  手牌满就老实留在弃牌区（`_grant_to_hand` 不静默消失）。伤害走 `_damage_player()` 唯一口，
  lucky 7 免疫 / 鸭嘴减伤 / 不锈钢盆 / 死亡判定全部自动生效，不重复实现。
- 「没有战斗胜利标记的奖励页」＝事件页直连 `_reward_panel.open()`，整条 `_present_win_panel` 链路不碰。
  **open 读的是 `RunState.pending_rewards`**，所以必须先 queue 道具 + 卡牌再 open。
- 收益（传奇 + 必定史诗）太高，只挂第二层（事件池 15 → 16）。

**踩的坑**
1. **撞号**：本地按 R805 干到一半，`fetch` 才发现 `origin/main` 已有 R805 蜂蜜 / R806 法术卷轴。
   不只是编号难看 —— `test_engine.gd` 会出现两个 `func _test_r805()`，GDScript 直接解析失败。
   全量重编 R807（151 处标识 + `_test_r805`→`_test_r807` + art_src 目录改名）。
2. **改计数漏了 7 处**：`grp_player 258→259`、两处 `dr_cls_count[""] 28→29`、`test_reward 336→337`、
   `_probe_content_override` 四处 336→337，还有我自己写歪的两条 `check_src` 锚点（`_is_choco_factory():`
   后面追加了 haunted_house；以及断言「源码不含 `_present_win_panel`」—— 我自己在注释里写了这个词）。
   最后一条改成「剥掉注释行再判」，验的才是代码不是注释。
3. **`%s` 拼进结果行**：`GameI18n.source()` 靠中文原文匹配，插动态道具名 → 英日西那行永远中文。
   结果行改成两条固定串。
4. **`json.dumps(indent=1)` 整篇重排**（narrative 785+/785- 假噪音）：按文件选缩进 ——
   `zh_canonical` / `cards_*` 是 1 空格，`narrative_*` / `event_ui_*` / `glossary` 是 2 空格。

**rebase 合流**
`git commit`（R807）→ `git rebase origin/main`：只有 `test_engine.gd` 冲突（两处函数追加点，两侧全留），
glossary / validate_spanish / game_engine 自动合并。合完 `json.load` 全过、relics 75 / 蜂蜜 / 法术卷轴 / 诡异洋房
三条俱全，重跑九套 engine **6682** 全绿、i18n 六器全绿。

**提交**：`ed047f4` 已推送（`c459f76..ed047f4`）。存档 md5 全程 `3af5a6b4` / `6f91ff9c` 未变。
"""

# ROUNDS（LF）
p = os.path.join(M, "MEMORY_ROUNDS.md")
s = io.open(p, "rb").read().decode("utf-8")
if "## R807：" in s:
    print("--   MEMORY_ROUNDS.md 已有 R807")
else:
    if not s.endswith("\n"):
        s += "\n"
    s += ROUNDS
    io.open(p, "wb").write(s.encode("utf-8"))
    print("OK   MEMORY_ROUNDS.md 追加 R807")

# 日志（LF，append-only）
p = os.path.join(M, "2026-11-18.md")
s = io.open(p, "rb").read().decode("utf-8")
if "## R807 诡异洋房" in s:
    print("--   2026-11-18.md 已有 R807")
else:
    if not s.endswith("\n"):
        s += "\n"
    s += DIARY
    io.open(p, "wb").write(s.encode("utf-8"))
    print("OK   2026-11-18.md 追加 R807")

# 行尾复核
for f in ["MEMORY.md", "MEMORY_ROUNDS.md", "2026-11-18.md"]:
    b = io.open(os.path.join(M, f), "rb").read()
    crlf, lf = b.count(b"\r\n"), b.count(b"\n")
    tag = "PURE-CRLF" if crlf == lf and crlf > 0 else ("PURE-LF" if crlf == 0 else "MIXED!!")
    print("%-20s %s" % (f, tag))
