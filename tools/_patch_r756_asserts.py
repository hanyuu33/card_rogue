# -*- coding: utf-8 -*-
"""R756 遗留红灯：把 test_engine.gd 里三处过期断言改成实测值。

实测（cards.json）：total 323 / player 245 / enemy 78。
R756 自己引入三张敌人卡：9253 常数测量员 / 9254 精密计算者 / 9255 负载增量员
（game_engine.gd「三个单位一套」），从未提交，所以断言一直停在 320 / 75。

保持 CRLF 原样回写。
"""
import sys
import pathlib

P = pathlib.Path("scripts/test_engine.gd")

raw = P.read_bytes()
print("CRLF" if b"\r\n" in raw else "LF", "size=%d" % len(raw))

REPL = [
    # 1) 图鉴总数 320 -> 323
    ("check(repo.all_cards().size() == 320,",
     "check(repo.all_cards().size() == 323,"),

    ('"图鉴 = 320 张（R756 +1：代偿 9252',
     '"图鉴 = 323 张（R756 +3：常数测量员 9253 / 精密计算者 9254 / 负载增量员 9255（三个单位一套）；R756 +1：代偿 9252'),

    # 2) 分组 245 + 75 -> 245 + 78
    ("check(grp_player.size() == 245 and grp_enemy.size() == 75,",
     "check(grp_player.size() == 245 and grp_enemy.size() == 78,"),

    ("（期望 244 / 75（R692",
     "（期望 245 / 78（R756 敌人 +3：常数测量员 9253 / 精密计算者 9254 / 负载增量员 9255；R692"),

    # 3) 按角色统计：敌人 75 -> 78
    ('and int(dr_cls_count.get("敌人", 0)) == 75',
     'and int(dr_cls_count.get("敌人", 0)) == 78'),

    ("（期望 78 / 66 / 75 / 75 / 公用 26，R756 公用 +1",
     "（期望 78 / 66 / 75 / 78 / 公用 26，R756 敌人 +3（常数测量员 9253 / 精密计算者 9254 / 负载增量员 9255）；R756 公用 +1"),
]

pairs = [(o.encode("utf-8"), n.encode("utf-8")) for o, n in REPL]

bad = False
for i, (old, _new) in enumerate(pairs):
    n = raw.count(old)
    print("anchor[%d] hits=%d  %s" % (i, n, REPL[i][0][:50]))
    if n != 1:
        bad = True
if bad:
    print("ABORT: 有锚点不是唯一命中，未写入")
    sys.exit(2)

out = raw
for old, new in pairs:
    out = out.replace(old, new, 1)

assert out.count(b"\r\n") == raw.count(b"\r\n"), "CRLF count changed"
assert out.count(b"\n") == raw.count(b"\n"), "LF count changed"

P.write_bytes(out)
print("OK  bytes %d -> %d" % (len(raw), len(out)))
