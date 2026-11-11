# -*- coding: utf-8 -*-
"""R575 隔离提交：并行会话把 R576（Steam 成就 / credits）整套 staged 在共享 index 里，
而 run_state.gd 同时被两条线改过。整文件 git add 会把对方的半成品带进来
（且 SteamAchievements 类还没进 HEAD，带上就编译不过）。

做法：
  1. 只把本轮 tools 目录 add 进 index（让新文件能被 pathspec 解析）；
  2. 临时从工作区 run_state.gd 摘掉对方那 2 行；
  3. `git commit -- <本轮路径>`：提交 HEAD + 指定路径的工作区内容，忽略其它已暂存改动；
  4. 立刻还原工作区，并重新 `git add scripts/run_state.gd` —— 对方的 2 行回到 staged，
     状态与提交前一致（HEAD 已含我方改动，因此 staged diff 正好又是那 2 行）。

全部在单次调用内完成，缩短与并行会话的竞态窗口。
"""
import subprocess
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")
RS = ROOT / "scripts" / "run_state.gd"
TOOLS = "art_src/2026-11-11_事件触发时定事件_R575/tools"
MSG = ROOT / "art_src/2026-11-11_事件触发时定事件_R575/_commit_msg.txt"
MY = [
    "HANDOFF.md",
    "scripts/game_layers.gd",
    "scripts/rogue_map.gd",
    "scripts/run_state.gd",
    "scripts/map_scene.gd",
    "scripts/event_scene.gd",
    "scripts/test_engine.gd",
    TOOLS,
]
PARALLEL_LINES = (
    "\t# R576 Steam 成就：初次启程（幂等，重复开局无害）。\n"
    "\tSteamAchievements.note_first_step()\n"
).encode("utf-8")


def git(*args, check=True):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    out = r.stdout.decode("utf-8", "replace") + r.stderr.decode("utf-8", "replace")
    if check and r.returncode:
        raise RuntimeError("git %s 失败 rc=%d\n%s" % (" ".join(args), r.returncode, out[-1500:]))
    return out.strip()


def main() -> None:
    head_before = git("rev-parse", "HEAD")
    staged_rs = git("diff", "--cached", "--", "scripts/run_state.gd")
    parallel = "SteamAchievements.note_first_step()" in staged_rs
    print("HEAD before:", head_before, "parallel staged:", parallel, flush=True)

    full = RS.read_bytes()
    if parallel:
        assert full.count(PARALLEL_LINES) == 1, "并行线 2 行不唯一，停止提交"
    try:
        if parallel:
            RS.write_bytes(full.replace(PARALLEL_LINES, b"", 1))
        # 新文件先入 index，pathspec 才能解析；其它已 staged 内容不会被这次提交带走
        git("add", "--", TOOLS)
        git("commit", "-F", str(MSG), "--", *MY)
    finally:
        if parallel:
            RS.write_bytes(full)
            git("add", "--", "scripts/run_state.gd")

    print("\nHEAD after:", git("rev-parse", "HEAD"), flush=True)
    print("\n--- commit ---\n" + git("show", "--stat", "--oneline", "HEAD"), flush=True)
    print("\n--- unexpected staged (parallel line only) ---", flush=True)
    print(git("diff", "--cached", "--name-only"), flush=True)
    print("\n--- status ---\n" + git("status", "--short"), flush=True)


if __name__ == "__main__":
    main()
