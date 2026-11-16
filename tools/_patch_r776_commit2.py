# -*- coding: utf-8 -*-
"""R776 修正提交（第二次隔离提交）：动作事件改名 + 界面反馈 + reward 计数。

工作区仍混着并行会话的 9269 彩虹诗，做法同上一轮：
我的版本换入 → pathspec 提交 → 换回合并版本（还原前比 md5）。
"""
import hashlib
import os
import shutil
import subprocess

REPO = "E:/work/card_rogue"
MINE = "E:/tmp/r776_mine"
MERGED = "E:/tmp/r776_merged"

FILES = [
    "scripts/game_engine.gd",
    "scripts/battle_scene.gd",
    "scripts/test_reward.gd",
]
TOOLS = [
    "tools/_patch_r776_fix2.py",
    "tools/_patch_r776_commit.py",
    "tools/_patch_r776_commit2.py",
]

MSG = """R776 修正：动作事件 inspire→anthem、补界面反馈、reward 卡牌库计数

* `action.emit("inspire", ...)` 早已被 8077「激发」占用，battle_scene 的 inspire 分支只认
  count / dmg / cells —— 激励乐章复用它会让玩家看到「激发 ×N 轮」的假飘字。改名 `anthem`。
* 未知 kind 是被**静默忽略**的（不报错 ≠ 有反馈）：给 `anthem` / `organ` 各补一段界面反馈，
  管风琴飘字按引擎给的真正命中 `cells` 逐格挂，不做「全体 -N」那种假汇总。
  organ 事件补带 cells（空场时是空数组）。
* `test_reward.gd` 的「卡牌库 N 张」是独立于 test_engine 图鉴数的一条断言，上一版漏改 → 327→329。"""


def md5(path):
    with open(path, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def main():
    for f in FILES:
        shutil.copyfile(os.path.join(REPO, f), os.path.join(MERGED, f))
    print("[0] 已刷新合并版本快照")

    for f in FILES:
        shutil.copyfile(os.path.join(MINE, f), os.path.join(REPO, f))
    print("[1] 我的版本已换入工作区")

    subprocess.run(["git", "-C", REPO, "add"] + TOOLS, check=True)
    print("[2] 工具脚本已挂进 index")

    r = subprocess.run(["git", "-C", REPO, "commit", "-m", MSG, "--"] + FILES + TOOLS,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("[3] commit exit", r.returncode)
    print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr.strip())

    for f in FILES:
        cur = os.path.join(REPO, f)
        if md5(cur) == md5(os.path.join(MINE, f)):
            shutil.copyfile(os.path.join(MERGED, f), cur)
            print("[4] RESTORED", f)
        else:
            print("[4] PARALLEL_WROTE_KEEP_CURRENT", f)


main()
