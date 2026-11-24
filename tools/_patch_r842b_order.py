# -*- coding: utf-8 -*-
# R842b：修 `_rare_value_order()` 洗牌键的格式化参数个数（4 个 %d 只喂 3 个），
# 并补一条「结果真的跟着种子走」的断言（原测试只验了确定性，退化能溜过去）。
import io

# ── ① run_state.gd（LF）：%d:%d:%d:%d → %d:%d:%d ──
P1 = "scripts/run_state.gd"
t1 = io.open(P1, "r", encoding="utf-8", newline="").read()
for v in ("a", "b"):
    old = '"%%d:%%d:%%d:%%d" %% [run_seed, stay, %s]' % v
    new = '"%%d:%%d:%%d" %% [run_seed, stay, %s]' % v
    n = t1.count(old)
    assert n == 1, "run_state %s: count=%d" % (v, n)
    t1 = t1.replace(old, new)
    print("OK run_state key(%s)" % v)
assert '"%d:%d:%d:%d"' not in t1
io.open(P1, "w", encoding="utf-8", newline="").write(t1)

# ── ② test_engine.gd（CRLF）：补种子相关性断言 ──
P2 = "scripts/test_engine.gd"
lines = io.open(P2, "r", encoding="utf-8", newline="").read().splitlines(keepends=True)
eol = "\r\n" if lines[0].endswith("\r\n") else "\n"

anchor = [i for i, L in enumerate(lines)
          if "R842 稀有价值：同一局同一间房删哪几张是派生的" in L]
assert len(anchor) == 1, anchor
i = anchor[0]
assert lines[i].rstrip("\r\n").endswith("))"), repr(lines[i])

block = [
    "\t# R842b：洗牌**必须真的跟着种子走**。原来的写法是 4 个 %d 配 3 个参数 ——",
    "\t# 格式化报错后 hash 全退化成同值，`sort_custom` 落到 `a < b` 兜底，",
    "\t# 结果等于「按 deck 顺序截前 N 张」：看着确定、其实一次都没洗。",
    "\tvar r842_orders: Dictionary = {}",
    "\tfor r842_s in [11, 22, 33, 44, 55, 66, 77, 88]:",
    "\t\tRunState.run_seed = r842_s",
    "\t\tr842_orders[str(RunState.rare_value_targets(repo))] = true",
    "\tRunState.run_seed = r842_sv_seed",
    "\tcheck(r842_orders.size() >= 2,",
    "\t\t\t\"R842 稀有价值：删哪几张跟着种子走（8 个种子共 %d 种结果）\" % r842_orders.size())",
]
for k, L in enumerate(block):
    lines.insert(i + 1 + k, L + eol)
print("OK test insert at L%d" % (i + 2))

io.open(P2, "w", encoding="utf-8", newline="").write("".join(lines))

# 复核换行
b = io.open(P2, "rb").read()
print("test_engine CRLF=%d lone-LF=%d" % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
