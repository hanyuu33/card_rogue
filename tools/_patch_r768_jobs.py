# -*- coding: utf-8 -*-
"""R768：把 _run_codex.py 的 JOBS 从 v1（带交通标志牌面）换成 v2（纯象形火柴人）。"""
import io
import re

P = r"E:\work\card_rogue\art_src\2026-11-16_诅咒火柴人_R768\_run_codex.py"
s = io.open(P, encoding="utf-8", newline="").read()

# 整段替换：从第一行 "# regret_a" 到 JOBS 列表的 "]" 结束
pat = re.compile(r"# regret_a =.*?\nJOBS = \[.*?\n\]\n", re.S)
m = pat.search(s)
assert m, "没找到 JOBS 段落，先 dump 看看"
print("matched block:\n" + m.group(0))

NEW = '''# v1（regret_a/b/c）= 带交通标志牌面的版本，店长退回：「只是要交通标志风格的
#   火柴人，不是要交通标志！」—— 牌子本身多余，留作参照，不再使用。
# v2 = 只留象形火柴人，背景统一深紫 #1B1420，四张诅咒卡成一套。
JOBS = [
    ("regret_v2", "regret_v2"),           # 9265 懊悔：跪地抱头
    ("flaw", "flaw_v1"),                  # 9154 破绽：站立，身体被青色裂缝劈开
    ("paralysis", "paralysis_v1"),        # 9185 麻痹：僵直后仰 + 三道黄闪电
    ("compensation", "compensation_v1"),  # 9252 代偿：弯腰背石头
]
'''
s2 = s[:m.start()] + NEW + s[m.end():]
assert s2.count('("regret_v2"') == 1
io.open(P, "w", encoding="utf-8", newline="").write(s2)
print("OK -> JOBS rewritten")
