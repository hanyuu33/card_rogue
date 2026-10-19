#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R247 卡图索引 —— 一眼看清「哪些卡有图 / 哪些卡待做 / 哪些卡不做」。

为什么需要这个工具：
    R247 删掉了 62 张程序生成的占位卡图（120×160 纯渐变 + 卡号水印）。
    删完之后 assets/pics 里**只剩真图**，没有图的卡再没有占位文件可查 ——
    「还有哪些卡差图」只能靠肉眼翻图鉴，翻不过来。本工具把 cards.json
    与 assets/pics 对账，随时输出三张清单，并顺手做四项体检。

状态判定（唯一来源，不接受第三种写法）：
    已完成 = assets/pics 里有 `<id>.png` 或 `<id>_<后缀>.png`（职业变体 / 沉睡图）
    暂不做 = art_plan.json 的 `skip`（理由写在那里，改那张表就能改状态）
    待做   = 其余全部

用法：
    python _art_index.py              摘要（数量 + 覆盖率 + 体检）
    python _art_index.py --todo       待做清单
    python _art_index.py --skip       暂不做清单（带理由）
    python _art_index.py --done       已完成清单
    python _art_index.py --md         重写 卡图索引.md
    python _art_index.py --check      只体检；有问题退出码 1（可挂自检）
    python _art_index.py --json       机器可读
  过滤：--group player|enemy   --class 森林精魄   --kind 盟友

体检四项：
    ① 占位图残留 —— 卡图宽度 < 300 或高度 < 270（真图规范 448×403，最小 512×456）
    ② 孤儿图 —— assets/pics 里有图，但没有对应卡
    ③ 计划失效 —— art_plan.json 的 skip 引用了不存在的卡 / 已经有图的卡
    ④ 规格不足 —— 真图但尺寸小于规范（只提醒，不算失败）
"""

import argparse
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
CARDS_JSON = os.path.join(ROOT, "cards.json")
ART_PLAN = os.path.join(ROOT, "art_plan.json")
PICS_DIR = os.path.join(ROOT, "assets", "pics")
MD_OUT = os.path.join(ROOT, "卡图索引.md")

# 真图规范（与 assets/ui/图片命名说明.txt 一致）：卡图窗比例 1.112，建议 448×403。
SPEC_W, SPEC_H = 448, 403
# 体检①的下限：低于这个尺寸基本就是旧占位图（当年是 120×160）。
MIN_W, MIN_H = 300, 270

STATE_DONE = "已完成"
STATE_TODO = "待做"
STATE_SKIP = "暂不做"

# 职业排序（清单里的分组顺序）：三职业 → 通用 → 敌方
CLASS_ORDER = ["森林精魄", "暗影刺客", "机械之心", "", "敌人"]
CLASS_LABEL = {"": "通用"}


# ── 读盘 ────────────────────────────────────────────────────────────────


def load_cards():
    with open(CARDS_JSON, encoding="utf-8") as f:
        data = json.load(f)
    return data["cards"] if isinstance(data, dict) else data


def load_plan():
    if not os.path.exists(ART_PLAN):
        return {}
    with open(ART_PLAN, encoding="utf-8") as f:
        return json.load(f).get("skip", {})


def png_size(path):
    """只读 PNG 头的 IHDR —— 不依赖 Pillow，纯 stdlib。"""
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def scan_art():
    """返回 {基础 id: [(后缀, 文件名, (宽,高)), ...]}。

    后缀 = 文件名里 id 之后的部分（`8002_forest` → `_forest`；`9116_sleep` → `_sleep`）。
    """
    out = {}
    if not os.path.isdir(PICS_DIR):
        return out
    for name in sorted(os.listdir(PICS_DIR)):
        if not name.lower().endswith(".png"):
            continue
        base = name[:-4]
        digits = ""
        for ch in base:
            if ch.isdigit():
                digits += ch
            else:
                break
        if not digits:
            continue                       # 不按 <id> 命名的图不算卡图
        suffix = base[len(digits):]
        out.setdefault(digits, []).append((suffix, name, png_size(os.path.join(PICS_DIR, name))))
    return out


# ── 分类 ────────────────────────────────────────────────────────────────


def classify(cards, art, skip):
    """给每张卡打状态；返回 [dict(card=..., state=..., variants=[...], reason="")]。"""
    rows = []
    for c in cards:
        cid = str(c.get("id"))
        variants = art.get(cid, [])
        if variants:
            state, reason = STATE_DONE, ""
        elif cid in skip:
            state, reason = STATE_SKIP, skip[cid]
        else:
            state, reason = STATE_TODO, ""
        rows.append({"card": c, "state": state, "variants": variants, "reason": reason})
    return rows


def sort_key(row):
    c = row["card"]
    cls = c.get("class") or ""
    return (CLASS_ORDER.index(cls) if cls in CLASS_ORDER else 99, int(c.get("id", 0)))


def label_class(c):
    return CLASS_LABEL.get(c.get("class") or "", c.get("class") or "通用")


# ── 体检 ────────────────────────────────────────────────────────────────


def health(rows, art, skip):
    """返回 (问题列表, 提醒列表)。问题 = 必须修；提醒 = 建议修。"""
    errors, warns = [], []
    ids = {str(r["card"]["id"]) for r in rows}

    # ① 占位图残留
    for cid, variants in art.items():
        for _suf, name, size in variants:
            if size is None:
                errors.append("占位图/坏图：%s（不是合法 PNG）" % name)
                continue
            if size[0] < MIN_W or size[1] < MIN_H:
                errors.append("占位图残留：%s 只有 %d×%d（真图规范 %d×%d）"
                              % (name, size[0], size[1], SPEC_W, SPEC_H))
            elif size[0] < SPEC_W or size[1] < SPEC_H:
                warns.append("允许但偏小：%s 是 %d×%d（规范 %d×%d）"
                             % (name, size[0], size[1], SPEC_W, SPEC_H))

    # ② 孤儿图
    for cid, variants in art.items():
        if cid not in ids:
            errors.append("孤儿图：%s（cards.json 里没有 id=%s 的卡）"
                          % (variants[0][1], cid))

    # ③ 计划失效
    for cid, reason in skip.items():
        if cid not in ids:
            errors.append("art_plan.json 的 skip 里有不存在的 id：%s（%s）" % (cid, reason))
        elif art.get(cid):
            errors.append("art_plan.json 把 id=%s 标成「暂不做」，但它已经有图了" % cid)
    return errors, warns


# ── 输出 ────────────────────────────────────────────────────────────────


def pct(a, b):
    return 0.0 if b == 0 else 100.0 * a / b


def print_summary(rows, errors, warns):
    total = len(rows)
    done = [r for r in rows if r["state"] == STATE_DONE]
    todo = [r for r in rows if r["state"] == STATE_TODO]
    skip = [r for r in rows if r["state"] == STATE_SKIP]
    print("卡图索引 —— 共 %d 张" % total)
    print("  已完成 %4d  (%5.1f%%)" % (len(done), pct(len(done), total)))
    print("  待做   %4d  (%5.1f%%)" % (len(todo), pct(len(todo), total)))
    print("  暂不做 %4d  (%5.1f%%)" % (len(skip), pct(len(skip), total)))
    print()
    print("按职业：")
    for cls in CLASS_ORDER + sorted({(r["card"].get("class") or "") for r in rows} - set(CLASS_ORDER)):
        sub = [r for r in rows if (r["card"].get("class") or "") == cls]
        if not sub:
            continue
        d = sum(1 for r in sub if r["state"] == STATE_DONE)
        t = sum(1 for r in sub if r["state"] == STATE_TODO)
        s = sum(1 for r in sub if r["state"] == STATE_SKIP)
        print("  %-6s %3d 张：有图 %3d / 待做 %3d / 不做 %2d" % (CLASS_LABEL.get(cls, cls), len(sub), d, t, s))
    print()
    if errors:
        print("体检：%d 个问题" % len(errors))
        for e in errors[:20]:
            print("  ✗ " + e)
        if len(errors) > 20:
            print("  … 还有 %d 条，跑 --check 看全部" % (len(errors) - 20))
    else:
        print("体检：通过（无占位图残留 / 无孤儿图 / 计划与素材一致）")
    if warns:
        print("提醒：%d 条（尺寸偏小，允许）" % len(warns))


def _w(text):
    """显示宽度：CJK 全角算 2 —— 终端里中文列才对得齐。"""
    import unicodedata
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1 for ch in str(text))


def _pad(text, width):
    text = str(text)
    return text + " " * max(0, width - _w(text))


def print_table(rows, state, show_reason=False):
    sub = [r for r in rows if r["state"] == state]
    sub.sort(key=sort_key)
    if not sub:
        print("（没有%s的卡）" % state)
        return
    heads = ["id", "卡名", "职业", "种类", "稀有", "费用"]
    tails = {STATE_DONE: "素材", STATE_SKIP: "理由"}
    if state in tails:
        heads.append(tails[state])
    widths = [5, 14, 10, 6, 4, 4] + ([9] if state in tails else [])
    print(" ".join(_pad(h, w) for h, w in zip(heads, widths)))
    for r in sub:
        c = r["card"]
        cells = [c.get("id"), c.get("name"), label_class(c), c.get("kind"),
                 c.get("rarity"), c.get("cost")]
        if state == STATE_DONE:
            cells.append("/".join(v[1] for v in r["variants"]))
        elif state == STATE_SKIP:
            cells.append(r["reason"])
        print(" ".join(_pad(v, w) for v, w in zip(cells, widths)).rstrip())


def md_table(rows, state):
    sub = [r for r in rows if r["state"] == state]
    sub.sort(key=sort_key)
    if not sub:
        return "（暂无）\n"
    if state == STATE_DONE:
        out = ["| id | 卡名 | 职业 | 种类 | 稀有度 | 素材 |", "|---|---|---|---|---|---|"]
        for r in sub:
            c = r["card"]
            files = "、".join("`%s`" % v[1] for v in r["variants"])
            out.append("| %s | %s | %s | %s | %s | %s |" % (
                c.get("id"), c.get("name"), label_class(c), c.get("kind"),
                rarity_name(int(c.get("rarity", 0))), files))
        return "\n".join(out) + "\n"
    if state == STATE_SKIP:
        out = ["| id | 卡名 | 职业 | 种类 | 理由 |", "|---|---|---|---|---|"]
        for r in sub:
            c = r["card"]
            out.append("| %s | %s | %s | %s | %s |" % (
                c.get("id"), c.get("name"), label_class(c), c.get("kind"), r["reason"]))
        return "\n".join(out) + "\n"
    out = ["| id | 卡名 | 职业 | 种类 | 稀有度 | 费用 |", "|---|---|---|---|---|---|"]
    for r in sub:
        c = r["card"]
        out.append("| %s | %s | %s | %s | %s | %s |" % (
            c.get("id"), c.get("name"), label_class(c), c.get("kind"),
            rarity_name(int(c.get("rarity", 0))), c.get("cost")))
    return "\n".join(out) + "\n"


RARITY_NAMES = ["普通", "稀有", "史诗", "初始", "怪物", "事件", "诅咒"]


def rarity_name(r):
    return RARITY_NAMES[r] if 0 <= r < len(RARITY_NAMES) else str(r)


def write_md(rows, errors, warns):
    total = len(rows)
    done = [r for r in rows if r["state"] == STATE_DONE]
    todo = [r for r in rows if r["state"] == STATE_TODO]
    skip = [r for r in rows if r["state"] == STATE_SKIP]

    L = []
    L.append("# 卡图索引")
    L.append("")
    L.append("> 本文件由 `python _art_index.py --md` **自动生成**，请勿手改。")
    L.append("> 要改状态只有两条路：往 `assets/pics/` 放图（→ 已完成），"
             "或在 `art_plan.json` 的 `skip` 里加一条理由（→ 暂不做）。")
    L.append("")
    L.append("## 一、总览")
    L.append("")
    L.append("| 状态 | 张数 | 占比 | 说明 |")
    L.append("|---|---|---|---|")
    L.append("| 已完成 | %d | %.1f%% | `assets/pics/` 里有真图 |" % (len(done), pct(len(done), total)))
    L.append("| 待做 | %d | %.1f%% | 缺图，还没排期 |" % (len(todo), pct(len(todo), total)))
    L.append("| 暂不做 | %d | %.1f%% | `art_plan.json` 明确跳过（带理由） |" % (len(skip), pct(len(skip), total)))
    L.append("| **合计** | **%d** | 100%% | cards.json 全部卡 |" % total)
    L.append("")
    L.append("### 按职业")
    L.append("")
    L.append("| 职业 | 张数 | 有图 | 待做 | 暂不做 | 覆盖率 |")
    L.append("|---|---|---|---|---|---|")
    for cls in CLASS_ORDER + sorted({(r["card"].get("class") or "") for r in rows} - set(CLASS_ORDER)):
        sub = [r for r in rows if (r["card"].get("class") or "") == cls]
        if not sub:
            continue
        d = sum(1 for r in sub if r["state"] == STATE_DONE)
        t = sum(1 for r in sub if r["state"] == STATE_TODO)
        s = sum(1 for r in sub if r["state"] == STATE_SKIP)
        L.append("| %s | %d | %d | %d | %d | %.1f%% |" % (
            CLASS_LABEL.get(cls, cls), len(sub), d, t, s, pct(d, len(sub))))
    L.append("")
    L.append("### 按种类")
    L.append("")
    kinds = sorted({c.get("kind") for c in (r["card"] for r in rows) if c})
    L.append("| 种类 | 张数 | 有图 | 待做 | 暂不做 |")
    L.append("|---|---|---|---|---|")
    for k in kinds:
        sub = [r for r in rows if r["card"].get("kind") == k]
        d = sum(1 for r in sub if r["state"] == STATE_DONE)
        t = sum(1 for r in sub if r["state"] == STATE_TODO)
        s = sum(1 for r in sub if r["state"] == STATE_SKIP)
        L.append("| %s | %d | %d | %d | %d |" % (k, len(sub), d, t, s))
    L.append("")
    L.append("## 二、待做（%d 张）" % len(todo))
    L.append("")
    L.append("按「职业 → id」排序。做图时把成品命名成 `<id>.png` 丢进 `assets/pics/` 即可，"
             "重跑本工具它就会自己挪到「已完成」。")
    L.append("")
    L.append(md_table(rows, STATE_TODO))
    L.append("## 三、暂不做（%d 张）" % len(skip))
    L.append("")
    L.append("这些卡当前**没有做图计划**。理由写在表里，改主意就从 `art_plan.json` 删掉对应行。")
    L.append("")
    L.append(md_table(rows, STATE_SKIP))
    L.append("## 四、已完成（%d 张）" % len(done))
    L.append("")
    L.append(md_table(rows, STATE_DONE))
    L.append("## 五、素材规格")
    L.append("")
    L.append("- 路径：`assets/pics/<卡牌id>.png`；职业变体 `<id>_<后缀>.png`（`forest` / `shadow` / `mech`）；"
             "沉睡图 `<id>_sleep.png`。")
    L.append("- 尺寸：**%d×%d**（卡图窗比例 1.112，横向）；四周留 6%% 安全边，整幅按 cover 铺满。"
             % (SPEC_W, SPEC_H))
    L.append("- 判存：`CardFace.art_for()` 先找变体、再找本图；都没有 → 卡面走职业色渐变横幅（不是 bug）。")
    L.append("- 体检：`python _art_index.py --check` 会拦「占位图残留 / 孤儿图 / 计划失效」。")
    L.append("")
    if errors:
        L.append("## 六、体检问题（%d）" % len(errors))
        L.append("")
        for e in errors:
            L.append("- %s" % e)
        L.append("")
    if warns:
        L.append("## 七、提醒（%d）" % len(warns))
        L.append("")
        for w in warns:
            L.append("- %s" % w)
        L.append("")

    with open(MD_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))
    print("已写入 %s（%d 张待做 / %d 张暂不做 / %d 张已完成）"
          % (os.path.basename(MD_OUT), len(todo), len(skip), len(done)))


def dump_json(rows):
    data = {
        "total": len(rows),
        "done": [r["card"]["id"] for r in rows if r["state"] == STATE_DONE],
        "todo": [r["card"]["id"] for r in rows if r["state"] == STATE_TODO],
        "skip": {str(r["card"]["id"]): r["reason"] for r in rows if r["state"] == STATE_SKIP},
    }
    print(json.dumps(data, ensure_ascii=False, indent=1))


def main():
    ap = argparse.ArgumentParser(add_help=True, description="卡图索引（R247）")
    ap.add_argument("--todo", action="store_true", help="待做清单")
    ap.add_argument("--skip", action="store_true", help="暂不做清单（带理由）")
    ap.add_argument("--done", action="store_true", help="已完成清单")
    ap.add_argument("--md", action="store_true", help="重写 卡图索引.md")
    ap.add_argument("--check", action="store_true", help="只体检；有问题退出码 1")
    ap.add_argument("--json", action="store_true", help="机器可读输出")
    ap.add_argument("--group", default="", help="过滤：player / enemy")
    ap.add_argument("--class", dest="klass", default="", help="过滤：森林精魄 / 暗影刺客 / 机械之心 / 敌人")
    ap.add_argument("--kind", default="", help="过滤：盟友 / 技能 / 效果 / 工事 / 场地 / 诅咒")
    args = ap.parse_args()

    cards = load_cards()
    art = scan_art()
    skip = load_plan()
    rows = classify(cards, art, skip)
    errors, warns = health(rows, art, skip)

    # 过滤只影响清单，不影响体检（体检永远看全量）
    view = rows
    if args.group:
        view = [r for r in view if (r["card"].get("group") or "") == args.group]
    if args.klass:
        view = [r for r in view if (r["card"].get("class") or "") == args.klass]
    if args.kind:
        view = [r for r in view if (r["card"].get("kind") or "") == args.kind]

    if args.check:
        for e in errors:
            print("✗ " + e)
        for w in warns:
            print("· " + w)
        print("体检：%s" % ("%d 个问题" % len(errors) if errors else "通过"))
        return 1 if errors else 0
    if args.json:
        dump_json(view)
        return 1 if errors else 0
    if args.todo:
        print_table(view, STATE_TODO)
    elif args.skip:
        print_table(view, STATE_SKIP, show_reason=True)
    elif args.done:
        print_table(view, STATE_DONE)
    elif args.md:
        write_md(rows, errors, warns)
    else:
        print_summary(view, errors, warns)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
