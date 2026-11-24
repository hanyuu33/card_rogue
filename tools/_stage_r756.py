# -*- coding: utf-8 -*-
"""R756: 从混合的工作区 diff 里只挑属于 R756 的 hunk，构造干净的 patch 并 --cached 到 index。

背景：并行会话（R757：遥测 / 漩涡 / 3 张机械卡 / 术语）改在同一批文件里。逐文件
`git add` 会把别人的改动一起提交，所以这里**按 hunk 的 old_start 行号**精确挑（不用
序号 —— 两套分割方式算出的序号会错位），交叉行再做行级剔除 / 改写，最后重算 @@ 计数。

用法：python tools/_stage_r756.py [--apply]
"""
import re
import subprocess
import sys

# 文件 -> 属于 R756 的 hunk 的 old_start 行号
PICK = {
    "scripts/battle_scene.gd": [8658, 8683],
    "scripts/run_state.gd": [447, 1626],
    "scripts/game_engine.gd": [588, 2512, 3765, 4633, 4654, 8940],
    "scripts/event_scene.gd": [82, 267, 288, 305, 314, 1674, 2195, 2752, 2784, 2812],
    "scripts/field_state.gd": [168],
    "scripts/test_engine.gd": [384, 412, 18810, 18822, 20109, 20365, 20377,
                               42823, 42831, 66380, 66416, 66452],
    "scripts/test_reward.gd": [37],
    "cards.json": [6648],
    "relics.json": [198, 451],
    "i18n/cards_en.json": [2, 1281],
    "i18n/cards_ja.json": [2, 1281],
    "i18n/cards_es.json": [2, 1281],
    "i18n/zh_canonical.json": [1, 1614],
    "i18n/noncard_zh_canonical.json": [33, 64],
    "i18n/noncard_en.json": [101, 225],
    "i18n/noncard_ja.json": [101, 225],
    "i18n/noncard_es.json": [101, 225],
    "i18n/narrative_zh_canonical.json": [44, 167],
    "i18n/narrative_en.json": [27, 150],
    "i18n/narrative_ja.json": [27, 150],
    "i18n/narrative_es.json": [27, 150],
    "i18n/event_ui_zh_canonical.json": [71],
    "i18n/event_ui_en.json": [64],
    "i18n/event_ui_ja.json": [64],
    "i18n/event_ui_es.json": [64],
    # i18n/source_aliases.json 没法按 hunk 拆（整文件只有一个连续 hunk），
    # 改由 tools/_stage_r756_aliases.py 直接构造 blob 进 index。
}

# 行级剔除：删掉含这些关键字的 +/- 行（是并行线的改动）
DROP = {
    ("i18n/source_aliases.json", 2): ["驿站门口"],
}
# 就地改写：把误合并进来的对方内容改回归属
REWRITE_RE = {
    ("scripts/test_engine.gd", 18810): [(r"期望 78 / 66", "期望 76 / 66")],
    # 并行线把 count 改成了 323（含 3 张机械卡），我只加了代偿 → 320
    ("i18n/cards_en.json", 2): [(r'"count": \d+,', '"count": 320,')],
    ("i18n/cards_ja.json", 2): [(r'"count": \d+,', '"count": 320,')],
    ("i18n/cards_es.json", 2): [(r'"count": \d+,', '"count": 320,')],
}
# 截断：从含 anchor 的 + 行往前找第一个「只有逗号收尾的括号行」，把它到 hunk 末尾的
# 所有 + 行删掉（那些是并列线新增的 9253/9254/9255）
CUT_AFTER = {
    ("cards.json", 6648): "9253",
    ("i18n/cards_en.json", 1281): "9253",
    ("i18n/cards_ja.json", 1281): "9253",
    ("i18n/cards_es.json", 1281): "9253",
    ("i18n/zh_canonical.json", 1614): "9253",
}

HDR = re.compile(r"^diff --git ")
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


def split(text):
    head, hunks, cur = [], [], None
    for ln in text.splitlines(keepends=True):
        if HDR.match(ln):
            head.append(ln)
        elif HUNK.match(ln):
            if cur is not None:
                hunks.append(cur)
            cur = [ln]
        elif cur is None:
            head.append(ln)
        else:
            cur.append(ln)
    if cur is not None:
        hunks.append(cur)
    return head, hunks


def old_start_of(hunk):
    return int(HUNK.match(hunk[0].rstrip("\r\n")).group(1))


def do_cut(body, anchor):
    """删掉 anchor 之前那一行的收尾逗号起、到末尾的所有 + 行。"""
    ai = None
    for i, ln in enumerate(body):
        if ln.startswith("+") and anchor in ln:
            ai = i
            break
    if ai is None:
        print("   [!!] CUT 找不到 anchor %s" % anchor)
        return body
    bi = None
    for j in range(ai - 1, -1, -1):
        if not body[j].startswith("+"):
            continue
        # ⚠️ strip() 不会去掉 diff 的 "+" 前缀，得先切掉第一个字符再比
        if body[j][1:].strip() == "},":
            bi = j
            break
    if bi is None:
        print("   [!!] CUT 找不到收尾括号 %s" % anchor)
        return body
    out = []
    for i, ln in enumerate(body):
        if i >= bi and ln.startswith("+"):
            continue
        out.append(ln)
    return out


def rebuild(hunk, flt, rewrites, do_cut_anchor, offset):
    m = HUNK.match(hunk[0].rstrip("\r\n"))
    old_start = int(m.group(1))
    tail = m.group(5)
    body = []
    for ln in hunk[1:]:
        if flt and (ln.startswith("+") or ln.startswith("-")) \
                and not ln.startswith(("+++", "---")) and flt(ln):
            continue
        for pat, rep in rewrites:
            if ln.startswith("+"):
                ln = re.sub(pat, rep, ln)
        body.append(ln)
    if do_cut_anchor:
        body = do_cut(body, do_cut_anchor)
    ctx = sum(1 for l in body if l.startswith(" "))
    adds = sum(1 for l in body if l.startswith("+"))
    dels = sum(1 for l in body if l.startswith("-"))
    hdr = "@@ -%d,%d +%d,%d @@%s\n" % (old_start, ctx + dels, old_start + offset, ctx + adds, tail)
    return [hdr] + body, adds - dels


parts = []
nh = 0
for f, picks in PICK.items():
    r = subprocess.run(["git", "diff", "--", f], capture_output=True)
    text = r.stdout.decode("utf-8", "replace")
    if not text.strip():
        print("[skip] %-40s 无 diff" % f)
        continue
    head, hunks = split(text)
    by_start = {old_start_of(h): h for h in hunks}
    out = list(head)
    offset = 0
    got = 0
    for s in picks:
        h = by_start.get(s)
        if h is None:
            print("[!!] %s 找不到 old_start=%d（有 %s）" % (f, s, sorted(by_start)))
            continue
        flt = None
        kws = DROP.get((f, s))
        if kws:
            flt = lambda ln, kws=kws: any(k in ln for k in kws)
        newh, delta = rebuild(h, flt, REWRITE_RE.get((f, s), []),
                              CUT_AFTER.get((f, s)), offset)
        out.extend(newh)
        offset += delta
        got += 1
    parts.append("".join(out))
    nh += got
    print("[pick] %-40s %2d hunk(s)  net %+d" % (f, got, offset))

patch = "".join(parts)
with open("_r756_stage.patch", "w", encoding="utf-8", newline="") as fh:
    fh.write(patch)
print("\nwrote _r756_stage.patch  (%d files, %d hunks)" % (len(parts), nh))

if "--apply" in sys.argv:
    chk = subprocess.run(["git", "apply", "--cached", "--check", "_r756_stage.patch"],
                         capture_output=True)
    print("check rc=%d\n%s" % (chk.returncode,
                               (chk.stdout + chk.stderr).decode("utf-8", "replace")[:3000]))
    if chk.returncode == 0:
        ap = subprocess.run(["git", "apply", "--cached", "_r756_stage.patch"],
                            capture_output=True)
        print("apply rc=%d\n%s" % (ap.returncode,
                                   (ap.stdout + ap.stderr).decode("utf-8", "replace")[:2000]))
