# -*- coding: utf-8 -*-
"""R758: 只挑属于 R758 的 hunk 进 index（按 old_start 行号，不用序号）。

工作区混着并行线（R757：遥测 / 漩涡 9186 费用与 locked / 术语）的未提交改动，逐文件
`git add` 会一起提交。这里按 hunk 精确挑；唯一一个「同一 hunk 里既有我的又有别人的」
（test_engine @75792：他们的遥测用例在前、我的 R758 用例在后）用 CUT_BEFORE 从分界行起切。

用法：python tools/_stage_r758.py [--apply]
"""
import re
import subprocess
import sys

PICK = {
    "scripts/game_engine.gd": [1095, 2690, 7325, 12535, 18628, 18697],
    "scripts/battle_scene.gd": [12084, 14656, 19277, 19324],
    "scripts/test_engine.gd": [384, 412, 12782, 13880, 13908, 18808, 75792],
    "scripts/game_levels.gd": [83, 99, 1418],
    "cards.json": [6669],
    "i18n/cards_en.json": [2, 1285],
    "i18n/cards_ja.json": [2, 1285],
    "i18n/cards_es.json": [2, 1285],
    "i18n/zh_canonical.json": [1619],
    "i18n/interface_en.json": [519],
    "i18n/interface_ja.json": [519],
    "i18n/interface_es.json": [519],
    "i18n/interface_zh_canonical.json": [1, 2297],
}

# 同一 hunk 内的分界：只保留含 anchor 的那条 + 行及其后的 + 行（前面的 + 是并行线的）
CUT_BEFORE = {
    ("scripts/test_engine.gd", 75792): "R758 计量工坊",
}

HDR = re.compile(r"^diff --git ")
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


def split(text):
    files, head, hunks, cur = [], None, None, None
    for ln in text.splitlines(keepends=True):
        if HDR.match(ln):
            if head is not None:
                files.append((head, hunks))
            head, hunks, cur = [ln], [], None
        elif HUNK.match(ln):
            m = HUNK.match(ln)
            cur = {"old": int(m.group(1)), "new": int(m.group(3)),
                   "hdr": ln, "body": []}
            hunks.append(cur)
        elif head is not None:
            (head if cur is None else cur["body"]).append(ln)
    if head is not None:
        files.append((head, hunks))
    return files


def cut(body, anchor):
    """丢掉 anchor 之前的 + 行（保留 - 与空行上下文）"""
    idx = None
    for i, ln in enumerate(body):
        if ln.startswith("+") and anchor in ln:
            idx = i
            break
    if idx is None:
        raise SystemExit("CUT_BEFORE 找不到锚点：%s" % anchor)
    out = []
    for i, ln in enumerate(body):
        if i < idx and ln.startswith("+"):
            continue
        out.append(ln)
    return out


def main():
    apply = "--apply" in sys.argv
    out = []
    for path, wanted in PICK.items():
        d = subprocess.run(["git", "diff", "-U3", "--", path],
                           capture_output=True).stdout.decode("utf-8")
        if not d:
            raise SystemExit("没有 diff：%s" % path)
        for head, hunks in split(d):
            got = []
            for h in hunks:
                if h["old"] not in wanted:
                    continue
                body = h["body"]
                a = CUT_BEFORE.get((path, h["old"]))
                if a:
                    body = cut(body, a)
                o = sum(1 for l in body if l[:1] in " -")
                n = sum(1 for l in body if l[:1] in " +")
                got.append((h, body, o, n))
            if len(got) != len(wanted):
                raise SystemExit("%s 命中 %d/%d 个 hunk（%s）" % (
                    path, len(got), len(wanted), [g[0]["old"] for g in got]))
            out.extend(head)
            for h, body, o, n in got:
                hdr = re.sub(r"^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@",
                             "@@ -%d,%d +%d,%d @@" % (h["old"], o, h["new"], n),
                             h["hdr"])
                out.append(hdr)
                out.extend(body)
    patch = "".join(out)
    with open("_r758_stage.patch", "w", encoding="utf-8", newline="") as f:
        f.write(patch)
    print("patch bytes=%d" % len(patch.encode("utf-8")))
    if apply:
        r = subprocess.run(["git", "apply", "--cached", "--verbose", "_r758_stage.patch"],
                           capture_output=True, text=True, encoding="utf-8")
        print("APPLY rc=%d" % r.returncode)
        print(r.stdout[-3000:])
        print(r.stderr[-3000:])


if __name__ == "__main__":
    main()
