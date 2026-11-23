# -*- coding: utf-8 -*-
## R859：旧「挨打 -1」测试先清掉甲壳 —— 甲壳本身由 _test_r857 覆盖，
## 这些用例只测「受伤递减口」，不该被新加的 10 点甲挡住（挡住 = 不算挨打）。
import io

P = "scripts/test_engine.gd"
src = io.open(P, encoding="utf-8", newline="").read()
NL = "\r\n"


def rep(old, new, tag):
    global src
    o = old.replace("\n", NL)
    n = new.replace("\n", NL)
    c = src.count(o)
    assert c == 1, "[%s] 锚点命中 %d 次" % (tag, c)
    src = src.replace(o, n, 1)


# ① R63 段：普攻两下打醒
rep(
"""	r63_e.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)

	check(r63_dd_p.sleep_left == FieldState.SLEEP_TURNS - 1,""",
"""	# R859：沉睡单位上场自带甲壳，甲没破就不算「挨打」——本段只测受伤递减口，
	# 先把甲清掉（甲壳本身在 `_test_r857()` 里单独覆盖）。
	r63_dd_p.armor = 0
	r63_e.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)

	check(r63_dd_p.sleep_left == FieldState.SLEEP_TURNS - 1,""",
"r63_e",
)

# ② R63 受伤口
rep(
"""	r63_f._hit_unit(r63_f_p, 10, "测试")

	check(r63_f_p.sleep_left == FieldState.SLEEP_TURNS - 1""",
"""	r63_f_p.armor = 0   # R859：同上，先破甲再测「受伤 -1」
	r63_f._hit_unit(r63_f_p, 10, "测试")

	check(r63_f_p.sleep_left == FieldState.SLEEP_TURNS - 1""",
"r63_f",
)

# ③ R76-A 段
rep(
"""	# 挨第1 下：沉睡 2 → 1，还不能动

	r76_sleep.attack(""",
"""	# R859：先破甲 —— 甲还在时挨打不算「挨打」（甲壳见 `_test_r857()`）。
	r76_sp.armor = 0

	# 挨第1 下：沉睡 2 → 1，还不能动

	r76_sleep.attack(""",
"r76",
)

# ④ R122 段
rep(
"""	r122_sleep.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)

	check(r122_sp.sleep_left == 1,""",
"""	r122_sp.armor = 0   # R859：先破甲，只测受伤口与回合口的配合
	r122_sleep.attack(Vector2i(1, 1), Vector2i(0, 1), GameEngine.SIDE_SELF)

	check(r122_sp.sleep_left == 1,""",
"r122",
)

# ⑤ R539 激光炮 + 对照
rep(
"""	r539_e._hit_unit(r539_p1, 3, "测试", true, true)""",
"""	r539_p1.armor = 0   # R859：先破甲，本段只测「与恶魔鸭共用同一套沉睡语义」
	r539_e._hit_unit(r539_p1, 3, "测试", true, true)""",
"r539a",
)
rep(
"""	r539_e._hit_unit(r539_duck, 3, "测试", true, true)""",
"""	r539_duck.armor = 0
	r539_e._hit_unit(r539_duck, 3, "测试", true, true)""",
"r539b",
)

io.open(P, "w", encoding="utf-8", newline="").write(src)
print("ok", len(src))
