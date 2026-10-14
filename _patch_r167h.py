# -*- coding: utf-8 -*-
"""R167 批 H：记忆（MEMORY.md 长期纪律 + 今日日志）。"""
import io

MEM = [
    # 基线
    (
        "**基线（R164）：engine 2355✓ / reward 26✓ / replay 28✓ / smoke 29（0 Parse/SCRIPT ERROR）。**（R164 删除双重场地 9108 + 重构 test_engine.gd 后 engine 由 2369→2355）",
        "**基线（R167）：engine 2355✓ / reward 26✓ / replay 35✓ / smoke 29（0 Parse/SCRIPT ERROR）。**\n"
        "（R164 删双重场地 9108 + 重构 test_engine.gd，engine 2369→2355；R167 回放套件 +7 条 `skip_info` 断言，replay 28→35；\n"
        "`_probe_runsave.gd` 26 条全绿——续档探针不在 `_verify.py` 里，改续档逻辑要单独跑它）",
    ),
    # 录像纪律
    (
        "- 录像：run_rng / `battle_seed`→`engine.rng`，新玩家动作挂 `ReplayLog.act`。",
        "- 录像：run_rng / `battle_seed`→`engine.rng`，新玩家动作挂 `ReplayLog.act`。\n"
        "  ⚠️ **回放的 `battle_end` / `run_end` 是「无消费方」的信息条目**（R167）：每个\n"
        "  `_replay_tick()` 开头必须调 `ReplayLog.skip_info()`，否则它们排到队头后四个 tick 全部\n"
        "  空转、`_idx` 永不推进 → **回放永久卡死**。另有 60s「无进展」看门狗兜底。\n"
        "  ⚠️ **`RunState.end_run(clear_save := true)`**（R167）：通关 / 失败清续档；\n"
        "  **「返回标题」一律 `end_run(false)`**（只复位内存、保留续档 → 标题「继续游戏」能接着打）。",
    ),
    # 界面纪律（奖励 + 事件文案）
    (
        "- 界面层没有自动化断言 → 靠探针 / 出图核验。",
        "- 界面层没有自动化断言 → 靠探针 / 出图核验。\n"
        "- 奖励卡牌三选一（R167）：**点卡 = 选中看说明（金环 + 下方详情条），再点「确认选择这张」才入组**\n"
        "  —— 触屏没有悬停，旧版「点一张即入组」玩家看不到效果。详情条口径 = 悬停优先，否则显示「已点选」那张。\n"
        "- ⚠️ **事件可见文案一律用「」，禁用 `**`**（R167）：`desc` 是普通 Label，不渲染加粗，星号会原样露出来。\n"
        "- ⚠️ 事件页 `_refresh()` 的「非休息类事件」**白名单**：**加新事件子类型必须同步登记**，\n"
        "  否则会被当休息处、把选项按钮文案覆盖成「在这里休息（回复 N 生命）」（R167 工匠事件实锤）。",
    ),
]


def eol_of(raw: bytes) -> bytes:
    return b"\r\n" if raw.count(b"\r\n") > 0 else b"\n"


ok = True
path = r"D:\work\.workbuddy\memory\MEMORY.md"
raw = open(path, "rb").read()
eol = eol_of(raw).decode()
work = raw.decode("utf-8")
for i, (old, new) in enumerate(MEM):
    o = old.replace("\n", eol)
    n = new.replace("\n", eol)
    c = work.count(o)
    if c != 1:
        print("FAIL MEMORY edit#%d count=%d" % (i + 1, c))
        ok = False
        continue
    work = work.replace(o, n, 1)
if ok:
    open(path, "wb").write(work.encode("utf-8"))
    print("OK   MEMORY.md (%d edits)" % len(MEM))
else:
    print("MEMORY NOT WRITTEN")

LOG = r"D:\work\.workbuddy\memory\2026-10-14.md"
raw2 = open(LOG, "rb").read()
eol2 = eol_of(raw2).decode()
t2 = raw2.decode("utf-8")
tail = "## R166c 三个职业小头像改 Q 版"
idx = t2.find(tail)
assert idx >= 0, "anchor not found"
SEC = """## R167 四条实机问题修复（工匠文案 / 返回标题保留续档 / 回放卡死 / 安卓奖励界面）
- 用户报 4 条：① 事件「鸭鸭工匠」选项文本与实际不符；② 按返回标题后不能重连游戏；③ 播放重放经常卡死；
  ④ 安卓版：经常卡死（**主要发生在进入选人界面时**）+ 奖励界面点牌直接选走、看不到描述。
- **①工匠文案根因**：`event_scene._refresh()` 的「非休息类事件」早退**白名单漏了 `_is_smith()`** →
  先铺好的「锻造…」按钮文案随后被当休息处覆盖成「在这里休息（回复 N 生命）」→ 修：白名单补 `_is_smith()`。
  顺带发现同源文本 bug：`**铁栅栏**` / `**不同名**` 在普通 Label 上**不渲染加粗、星号原样显示** → 统一改「」。
- **②返回标题保留续档**：`RunState.end_run(clear_save := true)`；战斗/事件/地图/卡组编辑/选道具五处
  「返回标题」改调 `end_run(false)`（只复位内存、保留续档）→ 标题「继续游戏」从上一处地图检查点接着打。
  `_probe_runsave.gd` 补 4 条覆盖（26 条全绿）。
- **③回放卡死根因**：录像里的 `battle_end` / `run_end` **没有任何消费方** → 排到队头后四个 `_replay_tick()`
  全部空转、`_idx` 永不推进 = 永久卡死。新增 `ReplayLog.skip_info()`（每个 tick 开头调；跳 battle_end、
  run_end 处优雅收尾）+ 60s 无进展看门狗。`test_replay.gd` 新增 `_test_skip_info()`（+7 断言，replay 28→35）。
- **④安卓奖励「先看后拿」**：触屏无悬停 → 旧版点一张即入组。改成「点卡 = 选中 + 下方详情条（金环）→
  点『确认选择这张』才入组」；顺带修掉底部提示行与按钮重叠。加了 `--r119pick` 出图开关。
- **④安卓进选人界面偶发卡死的兜底**：`SceneFx.goto()` 不再「上一次转场没结束就默默丢掉这次切换」——
  实例被移出树时重建、卡住超 1.5s 强制接手（原来会一直吞 goto，表现就是「点哪都没反应」）。
- 新演示开关：`--smith`（伪装工匠事件出图核验）。
- 验证：`_verify.py` engine 2355 / reward 26 / **replay 35** / smoke 29，全绿；出图核验工匠事件文案 +
  奖励「选中待确认」界面；行尾全部保持原样（battle_scene/玩法说明 = CRLF，其余 LF）。
- 文档：`UI设计规范.md` §4.37（奖励先看后拿 + 事件文案铁律）；`release/玩法说明.txt` 补 R167。

"""
t2 = t2[:idx] + SEC + t2[idx:]
open(LOG, "wb").write(t2.encode("utf-8"))
print("OK   today log prepended R167 section")
