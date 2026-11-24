# -*- coding: utf-8 -*-
"""R767：更新 R762 的两条旧断言（口径变了：卡组改随机构筑、规则版本 1→2），
并给续档往返补上 daily_fx。test_engine.gd 是 CRLF。"""
import sys

P = "scripts/test_engine.gd"
raw = open(P, "rb").read()
assert raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"
if b"R767 \xe8\xb5\xb7\xe4\xb8\xba\xe9\x9a\x8f\xe6\x9c\xba\xe6\x9e\x84\xe7\xad\x91" in raw:
    print("已经打过补丁，跳过")
    sys.exit(0)


def rep(old, new, tag):
    global raw
    o = old.replace("\n", "\r\n").encode("utf-8")
    n = new.replace("\n", "\r\n").encode("utf-8")
    c = raw.count(o)
    if c != 1:
        print("锚点异常[%s]: %d" % (tag, c))
        sys.exit(1)
    raw = raw.replace(o, n, 1)
    print("ok", tag)


rep(
    '''	check(PlayerClass.ids().has(str(c0.get("class", "")))
			and int(c0.get("difficulty", -1)) == DailyChallenge.FIXED_DIFFICULTY
			and c0.get("deck", []) == PlayerClass.start_deck_ids(str(c0.get("class", ""))),
			"R762 固定配置：可见职业轮换 / 难度 2 / 标准初始 13 张，隐藏职业不入池")''',
    '''	# R767：卡组不再是「标准 13 张」，改成每日随机构筑（15 张起）—— 结构细节交给 `_test_r767`，
	# 这里只锁「角色在可见三职业里 + 难度固定 + 卡组非空」。
	check(PlayerClass.ids().has(str(c0.get("class", "")))
			and int(c0.get("difficulty", -1)) == DailyChallenge.FIXED_DIFFICULTY
			and (c0.get("deck", []) as Array).size() >= 13,
			"R762 固定配置：可见职业轮换 / 固定难度 / 卡组非空（R767 起为随机构筑）")''',
    "固定配置",
)

rep(
    '''	check(DailyChallenge.leaderboard_name(d0) == "DAILY_20261116_V1",
			"R762 Steam 榜名：每天 + 规则版本各一张")''',
    '''	# R767：榜名里的版本号写成表达式 —— 修饰池一变就得升 `RULES_VERSION`，别回来改字符串。
	check(DailyChallenge.leaderboard_name(d0) == "DAILY_20261116_V%d" % DailyChallenge.RULES_VERSION,
			"R762 Steam 榜名：每天 + 规则版本各一张（V%d）" % DailyChallenge.RULES_VERSION)''',
    "榜名",
)

rep(
    '''	var r762_snap := RunSave.snapshot()
	RunState.daily_date = ""
	RunState.daily_rules = 0
	RunSave.apply(r762_snap)
	check(RunState.daily_date == d0 and RunState.daily_rules == DailyChallenge.RULES_VERSION,
			"R762 续档：daily_date / rules 随 snapshot → apply 往返")''',
    '''	# R767：塞一个**非空**的修饰汇总再存档 —— 摇到的东西可能是空效果，
	# 拿它当基准测不出「有没有进档」。
	RunState.daily_fx = {"gold": 42, "energy": 1}
	var r762_snap := RunSave.snapshot()
	RunState.daily_date = ""
	RunState.daily_rules = 0
	RunState.daily_fx = {}
	RunSave.apply(r762_snap)
	check(RunState.daily_date == d0 and RunState.daily_rules == DailyChallenge.RULES_VERSION,
			"R762 续档：daily_date / rules 随 snapshot → apply 往返")
	check(int(RunState.daily_fx.get("gold", 0)) == 42
			and int(RunState.daily_fx.get("energy", 0)) == 1,
			"R767 续档：修饰汇总随存档往返（漏了它续档后换层金币 / 费用会跳变）")''',
    "续档 fx",
)

open(P, "wb").write(raw)
out = open(P, "rb").read()
print("CRLF ok:", out.count(b"\r\n") == out.count(b"\n"))
