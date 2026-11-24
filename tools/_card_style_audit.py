#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""卡图风格审计 —— 按 frames/style-prompt.md 的水彩基准扫描全部卡图。

判定不靠人工逐张看，而是用三个可复现的色彩统计量做初筛：
    L    亮度均值（0-255）      水彩基准偏亮，旧暗底/写实偏低
    dark 暗像素占比（L<60）     旧风格大面积压暗，水彩几乎没有死黑
    hi   高光占比（L>200）      水彩的象牙白高光铺得多

门限（对 2026-11-24 batch01-04 的 16 张新基准图与全库抽检标定）：
    A_ok      dark<0.12 且 L>135 且 hi>0.08   → 疑已符合水彩基准
    C_fix     dark>=0.12 或 L<=120            → 风格不符，需重做
    其余                                        → B_amb 待人工复核

已知局限：白底写实渲染（如 9142 白底无人机）与亮调水彩在统计量上会接近，
所以 A 类必须人工复核；REVIEW 里记录了本轮的目检结论。

用法：
    python tools/_card_style_audit.py                # 扫描并写出 tsv + md
    python tools/_card_style_audit.py --stdout       # 只打印统计
"""
import argparse
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("需要 numpy 与 Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PICS = os.path.join(ROOT, "assets", "pics")
CARDS = os.path.join(ROOT, "cards.json")
OUT_TSV = os.path.join(ROOT, "art_src", "卡图风格审计_R861.tsv")
OUT_MD = os.path.join(ROOT, "art_src", "卡图风格审计_R861.md")

# 已有新风格候选（未落盘）的卡号 → 批次目录
CANDIDATES = {}
for _d in ("2026-11-23_卡图风格修复_batch01", "2026-11-24_卡图风格修复_batch02",
           "2026-11-24_卡图风格修复_batch03", "2026-11-24_卡图风格修复_batch04"):
    _p = os.path.join(ROOT, "art_src", _d)
    if not os.path.isdir(_p):
        continue
    for _f in os.listdir(_p):
        if _f.endswith(".png"):
            _id = _f.split("_")[0]
            if _id.isdigit():
                CANDIDATES[int(_id)] = _d

# 人工目检结论（2026-11-24，覆盖自动分档落在 A/AMB 的 25 张）
#   ok   = 目检确认符合水彩基准
#   fix  = 目检确认不符（写实 CG / 赛璐璐 / 霓虹 / 巴洛克等）
#   spec = 非卡图插画资产（剪影图标、白底物品特写、科幻飞船、素描稿），需单独定夺
REVIEW = {
    8027: ("fix", "暗调机械车间+黑发少女，写实向"),
    8039: ("fix", "带卡框的界面示意，非插画"),
    8040: ("fix", "蓝色科技格子示意"),
    8061: ("fix", "森林传送门，亮绿赛璐璐"),
    8079: ("spec", "白底木箱+蛇的物品特写"),
    9006: ("fix", "森林战斗，亮绿赛璐璐硬边"),
    9013: ("ok", "鸭子天使，米黄厚涂，接近水彩基准"),
    9031: ("fix", "白狼雪林，写实 CG"),
    9074: ("ok", "森林小仙子，浅绿透明水彩，完全符合"),
    9132: ("spec", "黑白灰素描风武僧，非彩色插画"),
    9135: ("fix", "白骨女武神，巴洛克厚涂"),
    9154: ("spec", "纯色底剪影图标"),
    9185: ("spec", "纯色底闪电人形剪影"),
    9183: ("ok", "森林少女与狐狸，柔和低对比"),
    9200: ("spec", "科幻飞船，非本作题材"),
    9201: ("spec", "科幻飞船，非本作题材"),
    9202: ("spec", "科幻飞船，非本作题材"),
    9252: ("spec", "纯色底岩石剪影图标"),
    9271: ("fix", "糖果屋，暗调厚涂"),
    9284: ("fix", "亮调卡通鸭子，非水彩"),
    9043: ("fix", "冰晶柱，蓝白硬边"),
    9077: ("fix", "森林火光，暗底高饱和"),
    9141: ("fix", "暗底科学家，写实向"),
    8026: ("fix", "亮色机甲，写实渲染"),
    9034: ("fix", "旧野狐，暖调写实动物插画"),
}


def measure(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    lum = 0.299 * a[:, :, 0] + 0.587 * a[:, :, 1] + 0.114 * a[:, :, 2]
    mx = a.max(2)
    mn = a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    return (float(lum.mean()), float(lum.std()), float(sat.mean()),
            float((lum < 60).mean()), float((lum > 200).mean()))


def load_cards():
    with open(CARDS, encoding="utf-8") as fh:
        data = json.load(fh)
    cards = data["cards"] if isinstance(data, dict) and "cards" in data else data
    return {int(c["id"]): c for c in cards if "id" in c}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true", help="只打印统计，不写文件")
    args = ap.parse_args()

    cards = load_cards()
    rows = []
    for fn in sorted(os.listdir(PICS)):
        stem, ext = os.path.splitext(fn)
        if ext.lower() != ".png" or not stem.isdigit():
            continue
        cid = int(stem)
        L, sd, sat, dark, hi = measure(os.path.join(PICS, fn))
        if dark < 0.12 and L > 135 and hi > 0.08:
            auto = "A_ok"
        elif dark >= 0.12 or L <= 120:
            auto = "C_fix"
        else:
            auto = "B_amb"
        verdict, note = REVIEW.get(cid, (None, ""))
        if verdict is None:
            # 未经目检的图：C_fix 直接进重做池，亮调灰区一律标待复核
            verdict = "fix" if auto == "C_fix" else "amb"
        if cid in CANDIDATES:
            verdict = "B_candidate"
        c = cards.get(cid, {})
        rows.append(dict(id=cid, name=c.get("name", ""), faction=c.get("class", ""),
                         L=L, sd=sd, sat=sat, dark=dark, hi=hi, auto=auto,
                         verdict=verdict, note=note,
                         cand=CANDIDATES.get(cid, "")))

    from collections import Counter
    cnt = Counter(r["verdict"] for r in rows)
    print("总计 %d 张：%s" % (len(rows), dict(cnt)))
    print("自动分档：", dict(Counter(r["auto"] for r in rows)))
    if args.stdout:
        return

    with open(OUT_TSV, "w", encoding="utf-8", newline="") as fh:
        fh.write("卡号\t卡名\t阵营\t亮度均值\t亮度标准差\t饱和度\t暗像素占比\t高光占比\t自动分档\t结论\t候选批次\t备注\n")
        for r in rows:
            fh.write("\t".join([
                str(r["id"]), r["name"], r["faction"],
                "%.1f" % r["L"], "%.1f" % r["sd"], "%.3f" % r["sat"],
                "%.3f" % r["dark"], "%.3f" % r["hi"], r["auto"], r["verdict"],
                r["cand"], r["note"]]) + "\n")

    def table(items, cols=6):
        items = list(items)
        out = []
        for i in range(0, len(items), cols):
            out.append("| " + " | ".join(items[i:i + cols]) + " |")
        return "\n".join(out)

    ok = [r for r in rows if r["verdict"] == "ok"]
    spec = [r for r in rows if r["verdict"] == "spec"]
    cand = [r for r in rows if r["verdict"] == "B_candidate"]
    fix = [r for r in rows if r["verdict"] == "fix"]
    amb = [r for r in rows if r["verdict"] == "B_amb"]
    by_fac = Counter(r["faction"] for r in fix)

    L = []
    L.append("# 卡图风格审计（R861，2026-11-24）\n")
    L.append("> 基准：`frames/style-prompt.md` 的固定水彩风格块 ——「细腻动漫笔触 + 分层水彩与不透明颜料、"
             "象牙白/奶油色高光、纸纹质感、暖漫射光、克制装饰」。\n")
    L.append("> 本表解决一个问题：**当前 `assets/pics/` 里哪些卡图不是这套风格、需要重做**。"
             "全表由 `tools/_card_style_audit.py` 可复现生成。\n")
    L.append("## 一、结论\n")
    L.append("| 分档 | 张数 | 含义 |")
    L.append("|---|---|---|")
    L.append("| 不符需重做（fix） | %d | 暗底/写实 CG/霓虹/巴洛克，与基准不符 |" % len(fix))
    L.append("| 已有候选待落盘（candidate） | %d | batch01-04 已出水彩候选，尚未覆盖 `assets/pics/` |" % len(cand))
    L.append("| 已符合基准（ok） | %d | 目检确认是水彩，可不动 |" % len(ok))
    L.append("| 非卡图插画（spec） | %d | 剪影图标/白底物品/科幻飞船/素描稿，需单独定夺 |" % len(spec))
    L.append("| 待人工复核（amb） | %d | 指标落在灰区且未目检 |" % len(amb))
    L.append("| **合计** | **%d** | |" % len(rows))
    L.append("\n按阵营拆分「不符需重做」：\n")
    L.append("| 阵营 | 张数 |")
    L.append("|---|---|")
    for k, v in by_fac.most_common():
        L.append("| %s | %d |" % (k or "无职业字段（结构体/事件/通用）", v))

    L.append("\n## 二、判定方法（可复现，不靠手感）\n")
    L.append("对每张图算四个统计量：亮度均值 `L`、亮度标准差、饱和度、暗像素占比 `dark`（L<60）、"
             "高光占比 `hi`（L>200）。门限由 2026-11-24 的 16 张新水彩基准图与全库抽检标定：\n")
    L.append("```")
    L.append("A_ok   dark < 0.12 且 L > 135 且 hi > 0.08   新基准图实测 L=140~184、dark<=0.08、hi>=0.11")
    L.append("C_fix  dark >= 0.12 或 L <= 120              旧图实测 L=45~119、dark 0.11~0.79、hi<=0.06")
    L.append("其余                                          灰区，进人工复核")
    L.append("```")
    L.append("\n**已知局限**：白底写实渲染（如 9142 白底无人机）统计量会贴近亮调水彩，"
             "故 A 类必须目检。本轮已对 25 张 A/灰区样本逐张目检，结论写进 `Review` 列。\n")

    L.append("## 三、已符合基准（可不动）\n")
    L.append(table(["`%d` %s" % (r["id"], r["name"]) for r in ok], 4))
    L.append("\n## 四、非卡图插画（需你定夺）\n")
    L.append("| 卡号 | 卡名 | 实际情况 |")
    L.append("|---|---|---|")
    for r in spec:
        L.append("| %d | %s | %s |" % (r["id"], r["name"], r["note"]))
    L.append("\n这批要么是纯色底剪影图标、要么是科幻飞船，和「日式二次元 + 西方奇幻」整体方向不符，"
             "但不是重画能解决的——属于**资产本身选错**，建议单独排一轮定夺。\n")

    L.append("## 五、已有候选待落盘（16 张，出图完成但未覆盖游戏素材）\n")
    L.append("| 卡号 | 卡名 | 阵营 | 候选批次 |")
    L.append("|---|---|---|---|")
    for r in cand:
        L.append("| %d | %s | %s | `%s` |" % (r["id"], r["name"], r["faction"], r["cand"]))
    L.append("\n落盘前注意：8031 / 8035 / 8042 是 1254² 正方，需按 448:403 裁；"
             "9032 耳尖、9034 尾巴贴边，裁切要保全主体。\n")

    L.append("## 六、不符需重做（%d 张，逐卡见 tsv）\n" % len(fix))
    L.append(table(["`%d` %s" % (r["id"], r["name"]) for r in fix], 6))
    L.append("\n## 七、待人工复核（%d 张）\n" % len(amb))
    if amb:
        L.append(table(["`%d` %s" % (r["id"], r["name"]) for r in amb], 6))
    else:
        L.append("（本轮无）")
    L.append("\n## 附：字段说明\n")
    L.append("逐卡数据见 `art_src/卡图风格审计_R861.tsv`。"
             "改图或换图后重跑 `python tools/_card_style_audit.py` 即可刷新，"
             "结论列里 `fix` 消失即表示该卡已收口。\n")

    with open(OUT_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))
    print("已写出：%s" % OUT_MD)
    print("已写出：%s" % OUT_TSV)


if __name__ == "__main__":
    main()
