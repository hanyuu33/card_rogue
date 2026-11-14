# -*- coding: utf-8 -*-
"""R738 卡色重设计（一次性迁移，已执行；重跑幂等，保留作判定口径的出处）：把 cards.json 的 `color` 从「色相词」改成「元素族」。

旧语义：红/橙/蓝/紫/黑/金/白/绿/灰/棕/黄 = 卡面配色，被 FxArt 五族硬映射，
        于是机械之心（蓝）全变冰霜、暗影刺客（紫）全变暗影 —— 属性完全由职业决定。
新语义：火 / 冰 / 雷 / 毒 / 暗影 / 圣光 / 自然 / 物理 / 水风 = **这张卡读起来像什么**；
        空串 = 没有明显属性 → 运行时按职业（见 FxArt.family_of）。

只改 `"color": "..."` 这一行，逐行文本替换，不动缩进 / 字段顺序 / CRLF。
用法：python tools/_migrate_r738_card_color.py [--write]
"""
import io
import sys
import json
import shutil
import collections

FAMILIES = ["火", "冰", "雷", "毒", "暗影", "圣光", "自然", "物理", "水风"]

# ── 显式指定（其余按职业默认）──
OVERRIDE = {}
def put(fam, ids):
    for i in ids:
        assert i not in OVERRIDE, "重复指定 %d" % i
        OVERRIDE[i] = fam

# 森林精魄：默认自然，显式挑出元素卡 / 物理卡 / 后勤卡
put("火", [9003, 9007, 9054, 9077, 9083, 9084, 9236])
put("冰", [9011, 9043, 9044])
put("雷", [9006])
put("毒", [8082])
put("水风", [9045, 9060, 9063, 9064, 9068, 9082, 8028, 9186])
put("物理", [9004, 9019, 9035, 9042, 9055, 9066, 9070, 9071, 9079, 9080, 9235])
put("暗影", [9010, 9039, 9062, 9175])
put("", [8002, 9002, 9005, 9041, 9056, 9057, 9058, 9059, 9061,
         9075, 9076, 9078, 8084, 9085, 9249])

# 暗影刺客：默认暗影，显式挑出物理 / 水风 / 自然 / 后勤
put("物理", [9086, 9087, 9088, 9090, 9096, 9104, 9119, 9160, 9204, 9205])
put("水风", [9091, 9095])
put("自然", [9099, 8010])
put("", [9089, 9092, 9093, 9094, 9097, 9098, 9101, 9103,
         9110, 8066, 9122, 9156, 9171, 9173, 9176, 9190])

# 机械之心：默认圣光（店长「光和火」），炮击/爆炸/锻造走火，充能走雷，装甲走物理
put("火", [8037, 8047, 8053, 8071, 8073, 8074, 8075, 9145, 9146, 9161,
           9162, 9163, 9166, 9172, 9211, 9219, 9192])
put("雷", [8030, 8041, 8077, 8078, 9170])
put("物理", [8029, 8034, 8038, 8044, 8049, 8050, 8052, 8055, 8058,
             9164, 9220, 9221])

# 公用：默认空（跟当前职业），诅咒走暗影，器械走物理
put("物理", [8001, 9018, 9072, 8065, 9179, 9215, 9216, 9217])
put("圣光", [9023, 9168, 9180, 9181])
put("自然", [9022, 9177, 9183, 9213])
put("暗影", [9149, 9154, 9157, 9182, 9185])
put("火", [9169])
put("冰", [8081])
put("水风", [9050])

# 敌人：默认物理，按意象显式指定
put("火", [1013, 1014, 1061, 1071, 9020, 9025, 9028, 9135, 9138,
           9139, 9201, 9209, 9241, 9243])
put("冰", [1031, 9024, 9210])
put("雷", [9152, 9202])
put("毒", [1050])
put("暗影", [1051, 1053, 1054, 1055, 9008, 9009, 9014, 9027, 9029,
             9115, 9116, 9117, 9118, 9123, 9124, 9125, 9178, 9240, 9242])
put("圣光", [9021, 9130, 9137, 9141, 9200, 9203, 9207, 9208, 9223, 9244])
put("自然", [9212, 9214])
put("水风", [9140, 9188, 9245])

# 职业默认（没有显式指定 + 无属性 时用）
DEFAULT = {"森林精魄": "自然", "暗影刺客": "暗影", "机械之心": "圣光",
           "敌人": "物理", "": ""}


def main():
    write = "--write" in sys.argv
    raw = io.open("cards.json", "r", encoding="utf-8", newline="").read()
    crlf = raw.count("\r\n")
    lines = raw.split("\n")

    # 逐行扫：id 行记当前卡，color 行记下「行号 → 卡 id」
    cur = None
    hits = 0
    line_of = {}
    new_of = {}
    for idx, ln in enumerate(lines):
        stripped = ln.strip()
        if stripped.startswith('"id":'):
            cur = int(stripped.split(":")[1].strip().rstrip(","))
        if stripped.startswith('"color":'):
            assert cur is not None, "color 出现在 id 之前"
            line_of[cur] = idx
            new_of[cur] = OVERRIDE.get(cur)
            hits += 1

    # 读一遍卡表拿 class / 旧色，补默认族
    d = json.load(io.open("cards.json", encoding="utf-8"))
    cards = d["cards"] if isinstance(d, dict) else d
    cls_of = {c["id"]: (c.get("class") or "") for c in cards}
    old_of = {c["id"]: c.get("color", "") for c in cards}
    assert hits == len(cards), "color 行 %d != 卡数 %d" % (hits, len(cards))

    for cid in new_of:
        if new_of[cid] is None:
            new_of[cid] = DEFAULT.get(cls_of[cid], "")
    bad = [f for f in set(new_of.values()) if f and f not in FAMILIES]
    assert not bad, "非法族名 %s" % bad

    # 回填
    out = list(lines)
    k = 0
    for cid, idx in line_of.items():
        ln = lines[idx]
        fam = new_of[cid]
        # 只换引号里的值：保留前导缩进、冒号后空格、行尾 \r
        i = ln.index('"color":')
        q1 = ln.index('"', i + 8)
        q2 = ln.index('"', q1 + 1)
        out[idx] = ln[:q1 + 1] + fam + ln[q2:]
        k += 1
    assert k == hits, "回填 %d != %d" % (k, hits)

    new_raw = "\n".join(out)
    assert new_raw.count("\r\n") == crlf, "CRLF 数量变了"

    # 报告
    print("卡数 %d，color 行 %d，CRLF %d" % (len(cards), hits, crlf))
    print("新族分布", collections.Counter(
        (new_of[c] or "(空→职业)") for c in new_of))
    trans = collections.Counter((old_of[c], new_of[c] or "(空)") for c in new_of)
    print("\n旧→新 迁移（前 30）")
    for (o, n), v in trans.most_common(30):
        print("  %s → %-6s %d" % (o, n, v))

    if write:
        shutil.copyfile("cards.json", "_bk_cards_before_r738.json")
        with io.open("cards.json", "w", encoding="utf-8", newline="") as f:
            f.write(new_raw)
        print("\n已写入 cards.json（备份 _bk_cards_before_r738.json）")
    else:
        print("\n[dry-run] 加 --write 才落盘")


if __name__ == "__main__":
    main()
