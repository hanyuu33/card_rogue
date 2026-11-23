# -*- coding: utf-8 -*-
"""把本轮（难度 12 商店涨价）的标记从 R794 改成 R794b。

原因：并行线已经用掉 R794（兔脚 6076），主仓工作区里它的改动还没提交
（`run_state.gd` 的 `roll_battle_tool_drop` / `rabbit_foot_gold` 段）。
`run_state.gd` 里两种 R794 并存 → 对它**逐条精确替换**；
`shop_scene.gd` / `test_engine.gd` 的 diff 已逐条核过、只有本轮的改动 → 全量替换。
"""
import io, sys

ROOT = "E:/work/card_rogue/"


def patch(path, pairs, crlf):
    full = ROOT + path
    raw = io.open(full, "rb").read().decode("utf-8")
    s = raw.replace("\r\n", "\n") if crlf else raw
    for old, new, tag in pairs:
        n = s.count(old)
        if n != 1:
            print("!! %s [%s] 命中 %d 次" % (path, tag, n))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out = s.replace("\n", "\r\n") if crlf else s
    io.open(full, "wb").write(out.encode("utf-8"))
    print("ok %s" % path)


def all_swap(path, crlf):
    full = ROOT + path
    raw = io.open(full, "rb").read().decode("utf-8")
    s = raw.replace("\r\n", "\n") if crlf else raw
    n = s.count("R794")
    if n <= 0:
        print("!! %s 里没有 R794" % path)
        sys.exit(1)
    s = s.replace("R794", "R794b")
    out = s.replace("\n", "\r\n") if crlf else s
    io.open(full, "wb").write(out.encode("utf-8"))
    print("ok %s（全量替换 %d 处）" % (path, n))


# run_state.gd（LF，文件里还有并行线的 R794 兔脚，必须精确）
patch("scripts/run_state.gd", [
    ("#   12 = 昂贵（R794）：", "#   12 = 昂贵（R794b）：", "注释块"),
    ("## R794（用户口径）：难度 12「昂贵」", "## R794b（用户口径）：难度 12「昂贵」", "常量块"),
    ("## R794：商店成交价的难度倍率", "## R794b：商店成交价的难度倍率", "函数注释"),
], crlf=False)

all_swap("scripts/shop_scene.gd", crlf=True)
all_swap("scripts/test_engine.gd", crlf=True)

patch("scripts/steam_achievements.gd", [
    ("难度 12 再叠「商店售价 +40%」（R794）", "难度 12 再叠「商店售价 +40%」（R794b）", "注释"),
], crlf=False)

print("done")
