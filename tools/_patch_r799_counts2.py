# -*- coding: utf-8 -*-
"""R799：reward / content 两套里的卡数计数 +2（全部是单行内替换，不动行尾）。"""

def patch(path, pairs):
    d = open(path, "rb").read().decode("utf-8")
    for old, new in pairs:
        assert d.count(old) == 1, (path, old[:40], d.count(old))
        d = d.replace(old, new)
    open(path, "wb").write(d.encode("utf-8"))
    b = open(path, "rb").read()
    print("%-38s CRLF=%d LFonly=%d" % (path, b.count(b"\r\n"),
          b.count(b"\n") - b.count(b"\r\n")))


NOTE = "R799 +2：连斩 9272 / 炮火就位 9273；"

patch("scripts/test_reward.gd", [
    ('check(all.size() == 332, "卡牌库 332 张（',
     'check(all.size() == 334, "卡牌库 334 张（' + NOTE),
    ('check(pool.size() == 202, "奖励池 202 张（',
     'check(pool.size() == 204, "奖励池 204 张（' + NOTE),
    ('check(pool2.size() == 220, "注入后奖励池 220 张（',
     'check(pool2.size() == 222, "注入后奖励池 222 张（' + NOTE),
])

patch("tools/_probe_content_override.gd", [
    ("（332 张卡，卡名不变）", "（334 张卡，卡名不变）"),
    ("数量仍为 332（整份替换，不是合并）", "数量仍为 334（整份替换，不是合并）"),
    ('_check("基线卡牌 332 张", base_count == 332, str(base_count))',
     '_check("基线卡牌 334 张", base_count == 334, str(base_count))'),
    ('_check("覆盖后仍是 332 张", ov.all_cards().size() == 332, str(ov.all_cards().size()))',
     '_check("覆盖后仍是 334 张", ov.all_cards().size() == 334, str(ov.all_cards().size()))'),
    ('broken.all_cards().size() == 332', 'broken.all_cards().size() == 334'),
    ('empty.all_cards().size() == 332', 'empty.all_cards().size() == 334'),
])
