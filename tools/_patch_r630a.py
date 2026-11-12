# -*- coding: utf-8 -*-
"""R630 补丁：test_engine 增加「整局统计三出口」回归判据。

纪律：exact-replace + 断言命中恰好 1 次；test_engine.gd 是 CRLF 且**每行后带一个空行**
（即行尾 `\\r\\n\\r\\n`），新插内容必须同款，否则整段风格不一致。
"""
import io
import sys

PATH = "scripts/test_engine.gd"

ANCHOR = "\tRunState.end_run()\r\n\r\n\r\n\r\n\t# ⑦ 结算页文案格式化（静态函数，界面与回归共用一份）"

NEW = """\t# ---- R630：整局统计的两个出口（记录快照 / 存档往返 / 老档兜底）----
\t# 用户口径：「3 层胜利后只统计了三层的战斗和精英战斗」。根因两条：
\t#   ① `RunRecord.snapshot()` 取的是本层 `battle_wins/elite_wins`（换层即清零）
\t#      → 记录页的「战斗胜场」永远只等于**最后一层**（2 层、3 层都一样）；
\t#   ② `RunSave` 只存本层两个数 → 关游戏再「继续游戏」后整局累计从 0 起算。
\tRunState.reset_total_stats()
\tRunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.default_id(), 6301211)
\tRunState.run_active = true
\tRunState.on_battle_won("battle")
\tRunState.on_battle_won("battle")
\tRunState.on_battle_won("elite")
\tRunState.advance_layer(GameLayers.LAYER_TWO)
\tRunState.on_battle_won("battle")
\tRunState.on_battle_won("elite")
\tRunState.advance_layer(GameLayers.LAYER_THREE)
\tRunState.on_battle_won("battle")
\t# 整局 = 4 普通 / 2 精英；第 3 层自己的 = 1 普通 / 0 精英
\tvar r630_rec := RunRecord.snapshot()
\tcheck(int(r630_rec.get("battles", -1)) == 4 and int(r630_rec.get("elites", -1)) == 2,
\t\t\t"R630 记录快照：按整局记（普通 4 / 精英 2，实际 %s/%s）"
\t\t\t\t% [str(r630_rec.get("battles", "?")), str(r630_rec.get("elites", "?"))])
\tcheck(RunState.battle_wins == 1 and RunState.elite_wins == 0,
\t\t\t"R630 记录快照：本层计数仍是第 3 层自己的（1/0，实际 %d/%d）"
\t\t\t\t% [RunState.battle_wins, RunState.elite_wins])
\tvar r630_save := RunSave.snapshot()
\tcheck(int(r630_save.get("total_battle_wins", -1)) == 4
\t\t\tand int(r630_save.get("total_elite_wins", -1)) == 2
\t\t\tand r630_save.has("total_damage"),
\t\t\t"R630 存档：整局三项（战斗 / 精英 / 伤害）都进档")
\tRunState.total_battle_wins = 0
\tRunState.total_elite_wins = 0
\tRunState.total_damage = 0
\tRunSave.apply(r630_save)
\tcheck(RunState.total_battle_wins == 4 and RunState.total_elite_wins == 2,
\t\t\t"R630 存档：读档后整局累计回填（%d/%d）"
\t\t\t\t% [RunState.total_battle_wins, RunState.total_elite_wins])
\t# 老档（R630 之前）没有 total_* 三个键 → 用本层数兜底，不能清成 0
\tvar r630_old := r630_save.duplicate(true)
\tr630_old.erase("total_battle_wins")
\tr630_old.erase("total_elite_wins")
\tr630_old.erase("total_damage")
\tr630_old["battle_wins"] = 2
\tr630_old["elite_wins"] = 1
\tRunState.total_battle_wins = 9
\tRunState.total_elite_wins = 9
\tRunSave.apply(r630_old)
\tcheck(RunState.total_battle_wins == 2 and RunState.total_elite_wins == 1,
\t\t\t"R630 老档兜底：缺 total_* 时用本层数接上（%d/%d）"
\t\t\t\t% [RunState.total_battle_wins, RunState.total_elite_wins])
\tRunState.end_run()

"""


def main() -> int:
    s = io.open(PATH, encoding="utf-8", newline="").read()
    n = s.count(ANCHOR)
    print("[verify] anchor count =", n)
    if n != 1:
        print("[abort] 锚点命中不是 1，未写入")
        return 1
    # 新段落按“行尾 + 空行”风格落盘
    lines = NEW.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    body = "".join(l + "\r\n\r\n" for l in lines)
    out = s.replace(ANCHOR, body + ANCHOR, 1)
    io.open(PATH, "w", encoding="utf-8", newline="").write(out)
    b = io.open(PATH, "rb").read()
    print("[done] bareLF =", b.count(b"\n") - b.count(b"\r\n"),
          "| CRLF =", b.count(b"\r\n"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
