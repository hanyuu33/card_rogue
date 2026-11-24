# -*- coding: utf-8 -*-
"""R780 提交 v3：降级 → add → commit → 恢复，全在一个进程里做完。

教训（v2 踩到）：add 完之后工作区恢复、脚本退出，再到外面敲 `git commit`——
这中间并行线又 `git add` 了同样的两个文件（他们的完整版含 R781），
于是我的「按路径提交」把他们的半套代码一起带上了（`_test_r781` 15 处 + 抽卡 3 行），
一旦 push 就是构建断裂。所以 add 与 commit 之间不能留任何空档。
"""
import io
import os
import re
import shutil
import subprocess
import sys

ROOT = "E:/work/card_rogue"
BK = "E:/tmp/r780_files"
NL = "\r\n"

FILES = ["scripts/game_engine.gd", "scripts/test_engine.gd"]
MINE = [
    "cards.json",
    "i18n/zh_canonical.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/cards_es.json",
    "scripts/placement.gd",
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
]


def rd(p):
    return io.open(p, encoding="utf-8", newline="").read()


def wr(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def git(*args):
    r = subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("git %s 失败: %s" % (" ".join(args), r.stderr))
    return r.stdout


os.makedirs(BK, exist_ok=True)
for f in FILES:
    shutil.copy2(os.path.join(ROOT, f), os.path.join(BK, os.path.basename(f)))

try:
    # ── 1) game_engine.gd：抽卡那几行降级回 HEAD ──
    p = os.path.join(ROOT, "scripts/game_engine.gd")
    lines = rd(p).split(NL)
    target = None
    for k, ln in enumerate(lines):
        if "RunState.hand_draw_per_turn() + extra_draw" in ln:
            target = k
            break
    if target is None:
        sys.exit("找不到 hand_draw_per_turn 那段")
    top = target
    while top - 1 >= 0 and lines[top - 1].lstrip().startswith("#"):
        top -= 1
    dropped = target - top + 1
    if dropped < 2 or dropped > 5:
        sys.exit("抽卡那段行数异常：%d" % dropped)
    lines[top:target + 1] = ["\t\tvar drawn := _draw_many(FieldState.HAND_DRAW_PER_TURN + extra_draw)"]
    wr(p, NL.join(lines))

    # ── 2) test_engine.gd：删 `_test_r78x()` 调用行 + 整个函数体 ──
    p = os.path.join(ROOT, "scripts/test_engine.gd")
    s = rd(p)
    call_pat = re.compile(r"\t_test_r78\d\(\)" + re.escape(NL))
    calls = call_pat.findall(s)
    if len(calls) != 1:
        sys.exit("调用行命中 %d 次（应为 1）" % len(calls))
    fname = re.search(r"_test_r78\d", calls[0]).group(0)
    s = call_pat.sub("", s, count=1)
    start_mark = "func %s() -> void:" % fname
    i = s.find(start_mark)
    if i < 0:
        sys.exit("找不到 %s" % start_mark)
    j = s.find(NL + "func ", i)
    if j < 0:
        j = len(s) - len(NL)
    nlines = s[i:j + len(NL)].count(NL)
    if nlines < 60 or nlines > 160:
        sys.exit("%s 行数异常：%d" % (fname, nlines))
    s = s[:i] + s[j + len(NL):]
    wr(p, s)

    # ── 3) add + commit：中间不留空档 ──
    git("add", *MINE)
    staged = git("diff", "--cached", "--numstat")
    print("=== 提交前 staged（只看我的 8 个） ===")
    for ln in staged.strip().split("\n"):
        if any(ln.endswith(m) for m in MINE):
            print("  " + ln)
    git("commit", "--quiet", "-F", "_commit_r780.txt", "--", *MINE)
    print("commit OK")
finally:
    for f in FILES:
        shutil.copy2(os.path.join(BK, os.path.basename(f)), os.path.join(ROOT, f))
    print("工作区已恢复（含并行线改动）")

# ── 4) 校验提交本身 ──
head_ge = git("show", "HEAD:scripts/game_engine.gd")
head_te = git("show", "HEAD:scripts/test_engine.gd")
print("=== 校验 ===")
print("  提交内 hand_draw_per_turn :", head_ge.count("hand_draw_per_turn"), "（应为 0）")
print("  提交内 _test_r781        :", head_te.count("_test_r781"), "（应为 0）")
print("  提交内 _cap_turn_damage  :", head_ge.count("_cap_turn_damage"), "（应为 3）")
print("  提交内 R780 测试段       :", head_te.count("R780"), "（应为 10 左右）")
print("=== 提交文件 ===")
print(git("show", "--stat", "--oneline", "HEAD").strip())
