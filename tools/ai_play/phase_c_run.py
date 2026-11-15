# -*- coding: utf-8 -*-
"""Phase C 编排：起一次引擎，循环打 N 局机器人，跑完关掉，再汇总事件流。

为什么要一个脚本包住整个流程
----------------------------
之前分三步手敲（launch → balance_sim → analyze），两次都被 SIGTERM：
`launch.py` 用 Popen 起的引擎是**当前 shell 的子进程**，shell 一结束就被收走，
后半段命令就跑在死进程上（症状是「接口已在运行」却连到旧代码）。

把「启动 / 循环 / 关闭 / 汇总」放进同一个进程树里，中途不会被谁收走；
顺带把逐局调用关进脚本内部，不靠反复调工具推进。

胜负不靠 stdout 猜
------------------
`roam.py` 回到标题页时一律打印「全灭」——通关也回标题，所以那个词不可信。
真正的判据是引擎自己写的 `run_end.win`，这里直接读事件流。
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PY = sys.executable or "python"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def project_name() -> str:
    """`user://` 落在 app_userdata/<project.godot 的 config/name>，名字是中文，别写死。"""
    for line in (ROOT / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/name="):
            return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit("读不到 project.godot 的 config/name")


def telemetry_path() -> Path:
    base = os.environ.get("APPDATA") or str(Path.home() / "AppData/Roaming")
    return Path(base) / "Godot" / "app_userdata" / project_name() / "telemetry.jsonl"


def summarise(path: Path) -> dict:
    """按 run 聚合：每局是否有 run_end、输赢。"""
    runs = {}
    if not path.exists():
        return runs
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        rid = e.get("run")
        if not rid:
            continue
        r = runs.setdefault(rid, {"seed": e.get("seed"), "cls": e.get("cls"),
                                  "battles": 0, "end": None, "win": None})
        ev = e.get("ev")
        if ev == "battle":
            r["battles"] += 1
        elif ev == "run_end":
            r["end"] = "closed"
            r["win"] = bool(e.get("win"))
    return runs


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--class", dest="cls", default="机械之心",
                    help="机械之心 / 暗影刺客 / 森林精魄")
    ap.add_argument("--steps", type=int, default=300, help="单局步数上限")
    ap.add_argument("--seed0", type=int, default=2000, help="起始种子（逐局 +1）")
    ap.add_argument("--port", type=int, default=8770)
    ap.add_argument("--keep", action="store_true", help="不清空已有事件流")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    tp = telemetry_path()
    tp.parent.mkdir(parents=True, exist_ok=True)
    if not args.keep and tp.exists():
        bak = tp.with_suffix(".jsonl.bak-%d" % int(time.time()))
        tp.rename(bak)
        print("旧事件流已备份 → %s" % bak.name)

    sys.path.insert(0, str(HERE))
    import launch as L  # noqa: E402

    rc = L.launch(args.port, headless=True, extra=["--sim", "--telemetry"])
    if rc != 0:
        return rc

    before = len(summarise(tp))
    t_all = time.time()
    tally = {}
    try:
        for i in range(args.runs):
            seed = str(args.seed0 + i).zfill(10)
            t0 = time.time()
            cmd = [PY, str(HERE / "roam.py"), "--new", "--class", args.cls,
                   "--seed", seed, "--steps", str(args.steps)]
            if args.quiet:
                cmd.append("-q")
            p = subprocess.run(cmd, cwd=str(HERE), capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            out = (p.stdout or "") + (p.stderr or "")
            # 单局完整输出留档：卡住时唯一能看清「停在哪一步」的东西。
            (HERE / ("_roam_%s.log" % seed)).write_text(out, encoding="utf-8")
            (HERE / "_roam_last.log").write_text(out, encoding="utf-8")
            how = "?"
            for line in reversed(out.strip().splitlines()):
                if line.strip() and not line.startswith(" "):
                    how = line.strip()[:60]
                    break
            # 胜负从事件流读（roam 的「全灭」不可信：通关也回标题）
            runs = summarise(tp)
            ended = sum(1 for r in runs.values() if r["end"])
            won = sum(1 for r in runs.values() if r["win"])
            print("[%d/%d] seed=%s  %5.1fs  局累计=%d 已收尾=%d 胜=%d  | %s"
                  % (i + 1, args.runs, seed, time.time() - t0,
                     len(runs), ended, won, how))
            tally[how] = tally.get(how, 0) + 1
    finally:
        L.stop()

    runs = summarise(tp)
    ended = [r for r in runs.values() if r["end"]]
    won = [r for r in ended if r["win"]]
    print("---")
    print("共 %d 局 / 用时 %.0fs" % (len(runs), time.time() - t_all))
    print("已收尾 %d 局（未收尾的说明中途断了，事件流里只剩半截）" % len(ended))
    if ended:
        print("通关 %d / %d = %.0f%%" % (len(won), len(ended),
                                        100.0 * len(won) / len(ended)))
        print("平均每局战斗场次 %.1f"
              % (sum(r["battles"] for r in ended) / float(len(ended))))
    print("事件流：%s" % tp)
    print("下一步：python tools/analyze_balance.py --sim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
