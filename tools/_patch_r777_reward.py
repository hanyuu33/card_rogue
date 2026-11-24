# -*- coding: utf-8 -*-
"""test_reward.gd：卡牌库总数 327 → 331（R776 +2 / R777 +1 / R777b +1，都是隐藏职业卡）。"""
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "test_reward.gd")
s = io.open(P, "rb").read().decode("utf-8")

old = 'check(all.size() == 327, "卡牌库 327 张（R773 +1：'
new = ('check(all.size() == 331, "卡牌库 331 张（R777b +1：疾风乐章 9270（吟游诗人 · '
       '2 费史诗效果，职业隐藏 → 不进奖励池）；R777 +1：彩虹诗 9269（吟游诗人 · '
       '2 费稀有技能，同上）；R776 +2：激励乐章 9267 / 管风琴 9268（吟游诗人 · '
       '隐藏职业 → 不进奖励池）；R773 +1：')
n = s.count(old)
assert n == 1, "锚点命中 %d 次" % n
s = s.replace(old, new)
io.open(P, "wb").write(s.encode("utf-8"))
print("[ok] test_reward.gd 卡牌库 → 331")
