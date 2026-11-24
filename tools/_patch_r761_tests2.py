# -*- coding: utf-8 -*-
"""R761 补丁 10：test_engine.gd 里被「招募」与「诗」顶掉的另外两处计数。

① R226 玩家技能卡 103 → 104（招募 9264 是技能卡，但不含「造成…伤害」→ dmg 仍 42）
② R577b 道具总数 62 → 63（诗 6069）
"""
import sys

P = "scripts/test_engine.gd"
raw = open(P, "rb").read()
if raw.count(b"\n") != raw.count(b"\r\n"):
    print("FAIL: 行尾不纯 CRLF")
    sys.exit(1)
t = raw.decode("utf-8").replace("\r\n", "\n")


def rep(old, new, tag):
    global t
    n = t.count(old)
    if n != 1:
        print("FAIL: %s 命中 %d 次\n%r" % (tag, n, old[:120]))
        sys.exit(1)
    t = t.replace(old, new, 1)
    print("  ok", tag)


rep("check(r226_skills == 103 and r226_dmg == 42 and r226_leak.is_empty(),",
    "check(r226_skills == 104 and r226_dmg == 42 and r226_leak.is_empty(),",
    "R226 技能卡 104")

rep("check(icon577_src_ok and icon577_repo.all_relics().size() == 62,\n"
    "\n"
    '\t\t\t"R577b 保真锁：62 件道具的 id 都能在 relics.json 源文本里找到")',
    "check(icon577_src_ok and icon577_repo.all_relics().size() == 63,\n"
    "\n"
    '\t\t\t"R577b 保真锁：63 件道具的 id 都能在 relics.json 源文本里找到'
    '（R761 +诗 6069）")',
    "R577b 道具 63")

rep("\t# ① 数据层：62 件道具逐件都有图标（R743 烤肉改成工具 → 61 件；R745 加回工具箱 6068）。",
    "\t# ① 数据层：63 件道具逐件都有图标（R743 烤肉改成工具 → 61 件；R745 加回工具箱 6068；"
    "R761 加吟游诗人赠品「诗」6069）。",
    "R577b 注释 63")

open(P, "wb").write(t.replace("\n", "\r\n").encode("utf-8"))
print("test_engine.gd OK")
