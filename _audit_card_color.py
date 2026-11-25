# -*- coding: utf-8 -*-
"""R737 卡色重设计 · 只读审计：按卡面文本推断「元素族」，对比现有 color。

输出：
  1. 每张卡的推荐族（含依据词），写到 _audit_card_color.tsv
  2. 终端打印族分布、现有 color → 推荐族的迁移矩阵、冲突样例
不改 cards.json，不做任何写盘以外的副作用。
"""
import io
import json
import collections

# 族 -> 关键词（先名称、再 effect_text、再 traits，分级加权）
RULES = [
    ("冰", ["冰", "寒", "冻", "霜", "雪"]),
    ("火", ["火", "焰", "燃", "烧", "熔", "爆", "灰烬", "焦", "烟"]),
    ("雷", ["雷", "电", "充能", "静电", "闪电", "过载"]),
    ("毒", ["毒", "腐蚀", "酸", "疫"]),
    ("暗影", ["影", "暗", "诅咒", "献祭", "灵魂", "噩兆", "死", "血", "吞噬", "邪", "骨"]),
    ("圣光", ["圣", "光", "祝福", "净化", "祈祷", "神", "裁决", "辉", "佑"]),
    ("自然", ["自然", "藤", "林", "兽", "生长", "治愈", "生命", "花粉", "种子",
              "荆棘", "风", "叶", "根", "草", "月", "泉", "雨"]),
]
# 无明显属性的机制词（用于判定「无属性」）
MECH = ["抽", "费", "护甲", "移动", "攻击", "伤害", "生命", "力量", "牌", "手牌",
        "弃", "牌库", "召唤", "沉默", "嘲讽", "冰冻", "眩晕", "标记", "复制", "费用"]

COLOR2FAM = {"红": "火", "橙": "火", "蓝": "冰", "紫": "暗影", "黑": "暗影",
             "金": "圣光", "白": "圣光", "绿": "自然", "灰": "", "棕": "", "黄": ""}


def hit(text, words):
    return [w for w in words if w in text]


def infer(card):
    """返回 (族, 依据)。名称命中优先，其次效果文本，最后 traits。"""
    name = str(card.get("name", ""))
    eff = str(card.get("effect_text", ""))
    traits = " ".join(card.get("traits", []) or [])
    for field, text, tag in (("名", name, 3), ("效", eff, 2), ("词", traits, 1)):
        best = None
        for fam, words in RULES:
            h = hit(text, words)
            if h and (best is None or len(h) > len(best[1])):
                best = (fam, h)
        if best and tag >= 2:
            return best[0], "%s:%s" % (field, "/".join(best[1]))
    # 只剩 traits 命中时，要求机制词不占多数（traits 常是「攻击/防御」这类）
    for fam, words in RULES:
        h = hit(traits, words)
        if h:
            return fam, "词:%s" % "/".join(h)
    return "", ""


def main():
    d = json.load(io.open("cards.json", encoding="utf-8"))
    cards = d["cards"] if isinstance(d, dict) else d
    rows = []
    for c in cards:
        fam, why = infer(c)
        rows.append((c.get("id"), c.get("name"), c.get("class") or "(公用)",
                     c.get("kind"), c.get("color", ""), fam, why,
                     str(c.get("effect_text", ""))[:60].replace("\t", " ")))
    with io.open("_audit_card_color.tsv", "w", encoding="utf-8", newline="\n") as f:
        f.write("id\tname\tclass\tkind\told\tnew\twhy\teffect\n")
        for r in rows:
            f.write("\t".join(str(x) for x in r) + "\n")

    print("总数", len(rows))
    print("推荐族分布", collections.Counter(r[5] or "(无属性)" for r in rows))
    print()
    # 迁移矩阵：现有 color 行 × 推荐族列
    fams = ["火", "冰", "雷", "毒", "暗影", "圣光", "自然", ""]
    print("old\\new".ljust(8) + "".join((f or "无").ljust(6) for f in fams))
    for col in ["红", "橙", "蓝", "紫", "黑", "金", "白", "绿", "灰", "棕", "黄"]:
        line = col.ljust(8)
        for fam in fams:
            n = sum(1 for r in rows if r[4] == col and r[5] == fam)
            line += str(n).ljust(6)
        print(line)
    print()
    print("=== 现有 color 与推荐族不一致（按族变化计）")
    diff = [r for r in rows if COLOR2FAM.get(r[4], "") != r[5]]
    print("不一致", len(diff), "/", len(rows))
    by = collections.Counter((r[4], r[5] or "无") for r in diff)
    for k, v in by.most_common(20):
        print("  %s → %s : %d" % (k[0], k[1], v))
    print()
    print("=== 无属性卡（将按职业取族）")
    for r in rows:
        if not r[5]:
            print("  %-5s %-10s %-6s %s | %s" % (r[0], r[1], r[2], r[3], r[7]))


if __name__ == "__main__":
    main()
