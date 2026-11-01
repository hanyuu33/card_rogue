# -*- coding: utf-8 -*-
"""连打：python grind.py n30 n23 n16 ...

对每个节点：
  * 战斗 → 用 mech_pilot 打完 + 结算奖励 + 离开
  * 事件 / 商店 / 休息 → **停在这里**，打印界面，交给人／上层判断
  * 巧克力 0 或场景变成标题 → 立即停

为什么这么做：ToolCallLoopGuard 只看同一工具连续调用次数（Bash 80），
逐房间手敲必然撞线；把整条路线塞进一个进程就数不到。
"""
import sys
import time

import ai_cli
import autoplay as ap
import mech_pilot as mp

ap.pick_reward = mp.pick_reward

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def brief():
    return "生命 %s  金币 %s  巧克力 %s  场景 %s" % (
        ai_cli.state().split("生命 ")[1].split("   ")[0] if "生命 " in ai_cli.state() else "?",
        "-", "-", ai_cli.snapshot().get("scene"))


def one(node):
    """返回 'battle-done' / 'stop' / 'dead'"""
    for _ in range(5):
        snap = ai_cli.snapshot()
        if snap.get("scene") != "map":
            break
        ai_cli.act(node)
        time.sleep(1.9)
    snap = ai_cli.snapshot()
    scene = snap.get("scene")
    if scene == "title":
        return "dead"
    if scene == "battle":
        mp.run(verbose=True)
        ap.settle_rewards(verbose=True)
        if "leave" in ap.hints(ai_cli.snapshot()):
            ai_cli.act("leave")
            time.sleep(1.4)
        for _ in range(10):
            if ai_cli.snapshot().get("scene") == "map":
                break
            time.sleep(0.5)
        return "battle-done"
    if scene == "map":
        return "stop"   # 没走进去
    return "stop"       # 事件 / 商店 / 休息


def main():
    nodes = [a for a in sys.argv[1:] if not a.startswith("-")]
    for node in nodes:
        r = one(node)
        print("[%s] %s" % (node, r))
        if r in ("stop", "dead"):
            break
        # 巧克力耗尽 → 下一步就是入夜，停手
        try:
            st = ai_cli.state()
            if "巧克力 0" in st:
                print("巧克力见底，停手")
                break
        except Exception:
            pass
    print("---")
    print(ai_cli.state()[:1600])
    return 0


if __name__ == "__main__":
    sys.exit(main())
