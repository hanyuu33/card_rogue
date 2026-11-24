# -*- coding: utf-8 -*-
"""R836 原子提交：临时 index + commit-tree。

⚠️ 工作区里 `run_state.gd` / `test_engine.gd` **混着并行线 R835（空故事书 6089）的未提交改动**，
   所以这两个文件不能直接取工作区内容 —— 这里用「HEAD 版本 + 重放我的替换」构造干净 blob。
   `battle_scene.gd` / `ui_assets.gd` / `test_smoke.gd` 三个文件的 diff 全部是本人的（逐 hunk 核过），
   直接用工作区内容。
"""
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r836_commit.idx"
MSG = "_commit_r836.txt"

FROM_WORKTREE = ["scripts/battle_scene.gd", "scripts/ui_assets.gd", "scripts/test_smoke.gd"]
FROM_HEAD_PATCH = ["scripts/run_state.gd", "scripts/test_engine.gd"]
NEW_FILES = [
    "assets/fx/clock_face.png",
    "assets/fx/clock_face.png.import",
    "assets/ui/图片命名说明.txt",
    "tools/_make_r836_clock.py",
]
ART_DIR = "art_src/2026-11-20_缺陷时钟时针_R836"


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


def cat_head(rel):
    return subprocess.run(["git", "cat-file", "blob", "HEAD:" + rel], cwd=ROOT,
                          capture_output=True).stdout


def patch_run_state(b):
    """R836：角标触发后不画（注释 + `>0`）。"""
    o1 = ("\t##   * 缺陷时钟（6084，R832）→ 本场**还差几张牌**触发。它的计数在引擎里，\n"
          "\t##     由战斗界面当第二参 `clock_left` 递进来；没有战斗上下文（图鉴 / 商店 / 奖励页）\n"
          "\t##     时是默认的 -1 → 不画。本场已触发过 → 「0」照画（跟火柴同口径：得让玩家\n"
          "\t##     看见这一场已经用光了）。\n").encode()
    n1 = ("\t##   * 缺陷时钟（6084，R832）→ 本场**还差几张牌**触发。它的计数在引擎里，\n"
          "\t##     由战斗界面当第二参 `clock_left` 递进来；没有战斗上下文（图鉴 / 商店 / 奖励页）\n"
          "\t##     时是默认的 -1 → 不画。\n"
          "\t##     ⚠️ R836（用户口径）：**触发之后本场就不再画角标**，直到下一场重新数 ——\n"
          "\t##        画「0」会被读成「还差 0 张、马上再来一次」，反而骗人。\n").encode()
    o2 = ("\t\tDEFECT_CLOCK_BADGE_ID:\n"
          "\t\t\treturn str(clock_left) if clock_left >= 0 else \"\"\n").encode()
    n2 = ("\t\tDEFECT_CLOCK_BADGE_ID:\n"
          "\t\t\t# R836：0 也**不画**（本场已经触发过，这一场不会再来了）。\n"
          "\t\t\treturn str(clock_left) if clock_left > 0 else \"\"\n").encode()
    for o, n, tag in ((o1, n1, "注释"), (o2, n2, "分支")):
        assert b.count(o) == 1, "run_state %s 命中 %d" % (tag, b.count(o))
        b = b.replace(o, n)
    return b


def patch_test_engine(b):
    """R836：两条角标断言改成「不画」+ 下一场补一条「重新出现」。CRLF 文件。"""
    def crlf(s):
        return s.replace("\n", "\r\n").encode()
    o1 = crlf("\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
              "\t\t\t\"R832 角标：触发后画「0」（本场用光）\")\n")
    n1 = crlf("\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"\",\n"
              "\t\t\t\"R836 角标：触发后本场**不画**（实际「%s」）\"\n"
              "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n")
    o2 = crlf("\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"0\",\n"
              "\t\t\t\"R832 角标：再打 6 张仍画「0」\")\n")
    n2 = crlf("\tcheck(RunState.relic_badge_text(6084, r832_e.defect_clock_left()) == \"\",\n"
              "\t\t\t\"R836 角标：再打 6 张仍然不画（实际「%s」）\"\n"
              "\t\t\t\t% RunState.relic_badge_text(6084, r832_e.defect_clock_left()))\n")
    o3 = crlf("\tcheck(r832_e2.defect_clock_left() == 12,\n"
              "\t\t\t\"R832 缺陷时钟：下一场重新数到 12（实际 %d）\" % r832_e2.defect_clock_left())\n")
    n3 = crlf("\tcheck(r832_e2.defect_clock_left() == 12,\n"
              "\t\t\t\"R832 缺陷时钟：下一场重新数到 12（实际 %d）\" % r832_e2.defect_clock_left())\n"
              "\tcheck(RunState.relic_badge_text(6084, r832_e2.defect_clock_left()) == \"12\",\n"
              "\t\t\t\"R836 角标：下一场重新出现（画「12」，实际「%s」）\"\n"
              "\t\t\t\t% RunState.relic_badge_text(6084, r832_e2.defect_clock_left()))\n")
    for o, n, tag in ((o1, n1, "断言1"), (o2, n2, "断言2"), (o3, n3, "下一场")):
        assert b.count(o) == 1, "test_engine %s 命中 %d" % (tag, b.count(o))
        b = b.replace(o, n)
    return b


PATCHERS = {
    "scripts/run_state.gd": patch_run_state,
    "scripts/test_engine.gd": patch_test_engine,
}


def main():
    staged = run("git", "diff", "--cached", "--name-only").strip()
    if staged:
        sys.exit("真实 index 里已有暂存内容，先确认归属：\n" + staged)
    if os.path.exists(TMPIDX):
        os.remove(TMPIDX)
    head = run("git", "rev-parse", "HEAD").strip()
    print("base HEAD =", head)

    tienv = {"GIT_INDEX_FILE": TMPIDX}
    run("git", "read-tree", head, env=tienv)

    # ① 工作区即干净的文件
    mine = list(FROM_WORKTREE)
    for f in FROM_WORKTREE:
        h = run("git", "hash-object", "-w", "--", f).strip()
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        print("  worktree", h, f)

    # ② 构造干净版（HEAD + 只重放我的替换）
    for f in FROM_HEAD_PATCH:
        clean = PATCHERS[f](cat_head(f))
        # 逐字节确认：干净版里**不含**并行线的标志串（R835/空故事书/6089）
        for bad in ("R835", "story_book", "6089"):
            if bad.encode() in clean:
                sys.exit("干净版 %s 里混进了并行线内容：%s" % (f, bad))
        tmp = "E:/tmp/_r836_clean_" + os.path.basename(f)
        with open(tmp, "wb") as fh:
            fh.write(clean)
        h = run("git", "hash-object", "-w", "--", tmp).strip()
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        mine.append(f)
        print("  cleaned ", h, f)

    # ③ 新增文件 + 修改过的命名说明
    art_files = []
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, ART_DIR)):
        for fn in sorted(files):
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT).replace("\\", "/")
            art_files.append(rel)
    for f in NEW_FILES + sorted(art_files):
        h = run("git", "hash-object", "-w", "--", f).strip()
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        mine.append(f)
    print("  new/art files:", len(NEW_FILES) + len(art_files))

    tree = run("git", "write-tree", env=tienv).strip()
    commit = subprocess.run(["git", "commit-tree", tree, "-p", head, "-F", os.path.join(ROOT, MSG)],
                            cwd=ROOT, capture_output=True)
    if commit.returncode != 0:
        sys.exit("commit-tree 失败：" + commit.stderr.decode("utf-8", "replace"))
    csha = commit.stdout.decode().strip()
    run("git", "update-ref", "HEAD", csha, head)
    print("new commit =", csha)

    # ④ 校验：提交里每个文件都要与「预期来源」逐字节一致
    bad = []
    for f in mine:
        got = subprocess.run(["git", "cat-file", "blob", "HEAD:" + f], cwd=ROOT,
                             capture_output=True).stdout
        want = open(os.path.join(ROOT, f), "rb").read() if not f.startswith("scripts/") or f in FROM_WORKTREE \
            else PATCHERS[f](cat_head(f))
        if got != want:
            bad.append(f)
    print("VERIFY", "OK" if not bad else "MISMATCH " + str(bad))

    # ⑤ 提交里不许混进并行线的文件
    names = [n for n in run("git", "show", "--name-only", "--pretty=format:", "HEAD").split("\n") if n.strip()]
    allowed_prefix = [ART_DIR, "assets/fx/clock_face", "assets/ui/图片命名说明.txt", "tools/_make_r836_clock.py"]
    extra = [n for n in names if n not in mine and not any(n.startswith(p) for p in allowed_prefix)]
    print("files in commit:", len(names))
    for n in names:
        print("   ", n)
    if extra:
        sys.exit("混进了不属于本轮的文件：" + str(extra))
    if bad:
        sys.exit("校验失败，先别 push")
    print("R836 提交完成（未 push）")


if __name__ == "__main__":
    main()
