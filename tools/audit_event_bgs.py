# -*- coding: utf-8 -*-
"""审计：哪些事件还没有背景图（bg_<kind>.png）。

`event_scene` 取背景的唯一入口是 `UiAssets.event_bg(kind)` → `assets/ui/bg_<kind>.png`
（`rest` 例外，走 `adventure_shared/rest_clearing.png`）。缺图不是报错，而是退回
`_add_fallback_bg()` 的程序化暗底 + 主题色光晕 —— 所以「缺」这件事没人会崩，
只会一直悄悄用兜底，靠肉眼发现。这个脚本就是把它变成一行命令能查的事。

判定口径按 `UI设计规范.md` 的约定：
  · 要「站进去」的场景  → 补 `bg_<kind>.png`（整屏 1280×720）
  · 左右布局的事件     → 补 `side_<kind>.png`（侧图 742×742），**不吃** `bg_`
  · 只要一个符号性画面 → 补 `event_<kind>.png`（插图，320×240 框）即可，不算缺

左右布局的名单**直接从 `event_scene.gd` 的 `SIDE_LAYOUT_KINDS` 读**，不手抄 ——
R519g 把 `martial` 改成左右布局时，手抄就会漏。

用法：
    python tools/audit_event_bgs.py            # 表格
    python tools/audit_event_bgs.py --json     # 机读
    python tools/audit_event_bgs.py --strict   # 有缺就返回非 0（给 CI 用）
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ROOT / "scripts" / "game_layers.gd"
SCENE = ROOT / "scripts" / "event_scene.gd"
UI = ROOT / "assets" / "ui"

# 不走随机事件池、只在特定分支出现的 kind —— 不在本轮「补图」范围内
SPECIAL = {
    "whisper": "R514 起并入二层起点池，只剩旧存档 / --whisper 演示",
    "treasure": "R512 起移出事件池，只剩旧存档 / --treasure 演示",
    "delivery_done": "运送委托的「兑付」承载页，复用 delivery 语境",
    "relic_chest": "大宝箱房固定分支，不是随机事件",
}
# 只给符号性画面、不需要整屏背景的（已有 event_<kind>.png 插图）
SYMBOLIC = {"gaze", "lake_lady"}


def read_names() -> dict[str, str]:
    src = LAYERS.read_text(encoding="utf-8")
    body = re.search(r"const EVENT_NAMES := \{(.*?)\n\}", src, re.S).group(1)
    return dict(re.findall(r'"([a-z_]+)":\s*"([^"]+)"', body))


def read_weights() -> dict[str, dict[int, int]]:
    """kind -> {层号: 权重}。直接按 LAYERS 的 events 块抠，避免手抄。"""
    src = LAYERS.read_text(encoding="utf-8")
    out: dict[str, dict[int, int]] = {}
    for lm in re.finditer(r"\n\t(\d+): \{(.*?)\n\t\},", src, re.S):
        layer = int(lm.group(1))
        ev = re.search(r'"events": \{(.*?)\n\t\t\}', lm.group(2), re.S)
        if not ev:
            continue
        for k, w in re.findall(r'"([a-z_]+)":\s*(\d+)', ev.group(1)):
            out.setdefault(k, {})[layer] = int(w)
    return out


def read_side_kinds() -> set[str]:
    """左右布局的 kind —— 它们用侧图 `side_<kind>.png`，不吃整屏 `bg_<kind>.png`。"""
    src = SCENE.read_text(encoding="utf-8")
    m = re.search(r"const SIDE_LAYOUT_KINDS\s*:=\s*\[(.*?)\]", src, re.S)
    return set(re.findall(r'"([a-z_]+)"', m.group(1))) if m else set()


def main() -> int:
    names = read_names()
    weights = read_weights()
    side_kinds = read_side_kinds()
    have_bg = {p.stem[3:] for p in UI.glob("bg_*.png")}
    have_side = {p.stem[5:] for p in UI.glob("side_*.png")}
    have_pic = {p.stem[6:] for p in UI.glob("event_*.png")}
    rest_bg = (UI / "adventure_shared" / "rest_clearing.png").exists()

    rows = []
    for kind, cn in names.items():
        is_side = kind in side_kinds
        if is_side:
            has_bg = kind in have_side
        elif kind == "rest":
            has_bg = rest_bg
        else:
            has_bg = kind in have_bg
        has_pic = kind in have_pic
        layers = sorted(weights.get(kind, {}))
        w = weights.get(kind, {})
        if has_bg:
            verdict, todo = "OK", ""
        elif kind in SPECIAL:
            verdict, todo = "特殊分支", SPECIAL[kind]
        elif kind in SYMBOLIC and has_pic:
            verdict, todo = "有插图", "符号性画面，按约定不需要整屏背景"
        elif has_pic:
            verdict, todo = "仅插图", "有插图但按约定该是整屏场景 → 建议补 bg_"
        elif is_side:
            verdict, todo = "缺", "补 side_<kind>.png（侧图 742×742）"
        else:
            verdict, todo = "缺", "补 bg_<kind>.png（整屏 1280×720）"
        rows.append({
            "kind": kind, "name": cn, "layers": layers,
            "weights": w, "bg": has_bg, "pic": has_pic, "side": is_side,
            "verdict": verdict, "todo": todo,
        })

    if "--json" in sys.argv:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        miss = [r for r in rows if r["verdict"] in ("缺", "仅插图")]
        print("事件共 %d 个；已有整屏背景 %d 个；待补 %d 个\n"
              % (len(rows), sum(1 for r in rows if r["bg"]), len(miss)))
        head = "%-14s %-9s %-8s %-6s %-6s %-4s %s"
        print(head % ("kind", "名称", "出现层", "权重", "背景", "插图", "结论"))
        print("-" * 96)
        for r in rows:
            lay = ",".join(str(x) for x in r["layers"]) or "-"
            wt = "/".join(str(r["weights"].get(x, 0)) for x in r["layers"]) or "-"
            cell = ("侧✓" if r["bg"] else "侧—") if r["side"] else ("✓" if r["bg"] else "—")
            print(head % (r["kind"], r["name"], lay, wt, cell,
                          "✓" if r["pic"] else "—",
                          r["verdict"] + (("：" + r["todo"]) if r["todo"] else "")))
        if miss:
            print("\n待补清单：")
            for r in miss:
                print("  %-14s %-9s %s" % (r["kind"], r["name"], r["todo"]))

    if "--strict" in sys.argv:
        return 1 if any(r["verdict"] in ("缺", "仅插图") for r in rows) else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
