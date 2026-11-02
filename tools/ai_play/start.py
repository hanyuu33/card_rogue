# -*- coding: utf-8 -*-
"""开新局一条命令：python start.py [职业] [优先级...]

做三件事：
  1. new_run（默认机械之心）
  2. 开场道具三选一 —— 按下面 GOOD 的优先级挑，挑不到就走「不拿」
  3. 走到地图，打印当前房间 / 可前往 / 地图类型

为什么要有这个脚本：开局每次都要「读三个选项 → 查 relics.json → 点一下 → 等转场」，
四五次工具调用就为了一件事。锚在技能不会的话，这里按名字打分就够用了；
不认识的选项一律不拿（宁可少一件道具，也别拿「源数之力」这种 -5 血换随机卡的）。

优先级依据（实测，机械之心）：
  类固醇   +10 最大生命并同补 → 起手 66 血太薄，这是最直接的容错
  陶罐     随机 2 件道具（曾开出机械核心 / 风妖精 / 鸭之眼 / 鸭血 / 快速符文）
  勇气徽章 精英与 Boss 首回合 +1 费 → 后期关键
  行囊     +100 金币（能换 2~4 张卡），代价是一张木栅栏
  鸭血     复制两张卡（配「攻击」堆爆发）
  栅栏修复术 木栅栏可合并，间接精简卡组
"""
import json
import os
import sys
import time

import ai_cli
import autoplay as ap

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
RELIC_JSON = os.path.join(HERE, "..", "..", "relics.json")

GOOD = {
    "类固醇": 100,
    "陶罐": 95,
    "勇气徽章": 85,
    "行囊": 70,
    "鸭血": 65,
    "栅栏修复术": 55,
    "失忆药水": 50,
    "惊奇盒子": 45,
    "洞窟绳": 30,
}

BAD = {"源数之力", "-5", "失去 5 点最大生命"}


def relic_names():
    try:
        with open(RELIC_JSON, encoding="utf-8") as f:
            return {int(x["id"]): x.get("name", "") for x in json.load(f).get("relics", [])}
    except Exception:
        return {}


def pick_opening(verbose=True):
    """开场三选一。返回 True 表示已经处理。"""
    snap = ai_cli.snapshot()
    if snap.get("scene") != "event":
        return False
    d = ap.hints(snap)
    cands = [k for k in d if k.startswith("b") and k[1:].isdigit() and "摇摇头" not in d[k]]
    skip = [k for k in d if "摇摇头" in d[k] or "不拿" in d[k]]
    if not cands:
        return False
    best, best_score = None, 0
    for k in cands:
        hint = d[k]
        score = 0
        for name, w in GOOD.items():
            if name in hint:
                score = max(score, w)
        if any(b in hint for b in BAD):
            score = -100
        if verbose:
            print("  选项 %-4s %-22s 评分 %d" % (k, hint[:22], score))
        if score > best_score:
            best, best_score = k, score
    if best is None and skip:
        if verbose:
            print("  没有值得拿的 → %s" % d[skip[0]][:16])
        ai_cli.act(skip[0])
        time.sleep(1.6)
        return True
    if best is None:
        return False
    if verbose:
        print("  → 拿 %s" % d[best][:22])
    ai_cli.act(best)
    time.sleep(1.8)
    return True


def leave_any(limit=8):
    """把开局剩下的确认/离开按钮都点掉，直到进地图。"""
    for _ in range(limit):
        snap = ai_cli.snapshot()
        if snap.get("scene") in ("map", "title"):
            return snap
        ids = [x["id"] for x in snap.get("targets", [])]
        for k in ("b0", "ok", "leave"):
            if k in ids:
                ai_cli.act(k)
                time.sleep(1.7)
                break
        else:
            time.sleep(0.7)
    return ai_cli.snapshot()


def brief():
    j = json.loads(ai_cli.get("/json", timeout=10))
    print("NODE=%s SCENE=%s HP=%s/%s GOLD=%s CHOC=%s DECK=%s"
          % (j.get("node"), j.get("scene"), j.get("hp"), j.get("max_hp"),
             j.get("gold"), j.get("chocolate"), len(j.get("deck") or [])))
    t = ai_cli.state()
    for key, n in (("当前房间", 200), ("未走的房间", 380)):
        i = t.find(key)
        if i >= 0:
            print(t[i:i + n].rstrip())
    snap = ai_cli.snapshot()
    print("可点: " + " ".join("%s:%s" % (x["id"], x["hint"][:12]) for x in snap.get("targets", [])))


def main():
    cls = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "机械之心"
    rep = ai_cli.new_run(cls)
    print("开新局 %s → %s" % (cls, (rep.get("msg") or "")[:40]))
    time.sleep(1.6)
    pick_opening()
    leave_any()
    brief()
    return 0


if __name__ == "__main__":
    sys.exit(main())
