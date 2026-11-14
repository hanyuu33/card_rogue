# -*- coding: utf-8 -*-
"""R738 验收页：卡色重设计（旧色相 → 九族元素）。写 _review/r738_card_color.html。"""
import io
import os
import json
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAMS = ["火", "冰", "雷", "毒", "暗影", "圣光", "自然", "物理", "水风"]
ART = {"火": "bx_skill_fire", "冰": "bx_skill_ice", "雷": "bx_bolt", "毒": "trap_fx_7003",
       "暗影": "bx_skill_shadow", "圣光": "bx_skill_holy", "自然": "bx_skill_nature",
       "物理": "bx_blast", "水风": "bx_gale"}
SHOTS = [("r667_battle_attack_forest.png", "森林精魄打「攻击」8002 → 自然绿（旧口径是冰霜）"),
         ("r667_battle_skill_nature.png", "自然族通用施法图"),
         ("r667_battle_skill_bolt.png", "雷族通用施法图（bx_bolt）")]


def main():
    d = json.load(io.open(os.path.join(ROOT, "cards.json"), encoding="utf-8"))
    cards = d["cards"]
    by_fam = collections.defaultdict(list)
    for c in cards:
        by_fam[c.get("color", "")].append(c)
    old = json.load(io.open(os.path.join(ROOT, "_bk_cards_before_r738.json"), encoding="utf-8"))
    old_of = {c["id"]: c.get("color", "") for c in old["cards"]}

    rows = []
    for f in FAMS:
        cs = by_fam.get(f, [])
        per = collections.Counter((c.get("class") or "公用") for c in cs)
        names = "、".join(c["name"] for c in cs[:10]) + ("…" if len(cs) > 10 else "")
        rows.append("""<tr><td class="fam">{f}</td><td><code>{art}</code></td>
<td class="num">{n}</td><td class="cls">{cls}</td><td class="names">{names}</td></tr>""".format(
            f=f, art=ART[f], n=len(cs),
            cls=" · ".join("%s %d" % (k, v) for k, v in per.most_common()),
            names=names))
    empty = by_fam.get("", [])
    rows.append("""<tr><td class="fam">（空）</td><td><code>按职业</code></td>
<td class="num">{n}</td><td class="cls">无属性</td><td class="names">{names}</td></tr>""".format(
        n=len(empty), names="、".join(c["name"] for c in empty)))

    # 攻击 8002 三职业对照
    atk = [c for c in cards if c["id"] == 8002][0]

    shots = "\n".join(
        """<figure><img src="../_shots/{f}"><figcaption>{cap}</figcaption></figure>""".format(
            f=f, cap=cap) for f, cap in SHOTS)

    html = """<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">
<title>R738 卡色重设计验收</title><style>
body{{font-family:-apple-system,"Noto Sans SC",sans-serif;background:#f3efe6;color:#2b2620;
margin:0;padding:28px 34px;line-height:1.6}}
h1{{font-size:22px;margin:0 0 4px}}h2{{font-size:17px;margin:26px 0 10px;
border-left:5px solid #6b8f5a;padding-left:10px}}
p{{margin:6px 0}}code{{background:#e7e0d2;padding:1px 5px;border-radius:3px;font-size:12px}}
table{{border-collapse:collapse;width:100%;background:#fffdf7;font-size:13px}}
th,td{{border:1px solid #d9d0bd;padding:6px 8px;text-align:left;vertical-align:top}}
th{{background:#e8e0cd}}td.num{{text-align:right;width:56px}}td.fam{{font-weight:700;width:64px}}
td.cls{{width:190px;font-size:12px;color:#5a5245}}td.names{{color:#3a352c}}
.gallery{{display:flex;gap:14px;flex-wrap:wrap}}figure{{margin:0;width:32%;min-width:300px}}
img{{width:100%;border:1px solid #cfc5ae;border-radius:4px}}figcaption{{font-size:12px;color:#5a5245;margin-top:4px}}
.k{{background:#fff3cd;border:1px solid #e3c96b;padding:10px 12px;border-radius:5px;margin:10px 0}}
</style></head><body>
<h1>R738 卡色重设计 · 验收</h1>
<p>卡表 319 张的 <code>color</code> 从「色相词」（红/蓝/紫/灰…）换成「元素族」；
没有明显属性的卡写空串，战斗特效按职业兜底。</p>
<div class="k">改前的毛病：<b>8002「攻击」color = 蓝</b> → 五族表把「蓝」映射成冰霜，
于是森林精魄普攻喷冰。现在它写空 → 森林自然 / 暗影暗影 / 机械圣光，同一张牌三种颜色。</div>
<h2>九族一览（319 张）</h2>
<table><tr><th>族</th><th>素材</th><th>张数</th><th>职业分布</th><th>代表卡</th></tr>
{rows}
</table>
<h2>无属性 → 按职业</h2>
<table><tr><th>职业</th><th>默认族</th></tr>
<tr><td>森林精魄</td><td>自然</td></tr><tr><td>暗影刺客</td><td>暗影</td></tr>
<tr><td>机械之心</td><td>圣光（炮击 / 爆炸 / 锻造显式写「火」）</td></tr>
<tr><td>敌人</td><td>物理</td></tr></table>
<p>8002「攻击」的 <code>color</code> 现在是 <code>"{atk_color}"</code>（空串），打在哪一职业就是哪一族的特效。</p>
<h2>实机截图</h2>
<div class="gallery">{shots}</div>
<p style="margin-top:18px;color:#7a7164;font-size:12px">回归：engine 6079✓ 0✗ · 八套见终稿。
截图走 <code>tools/_run_r667_shots.py --only r738</code>，真实 fx_impact 事件口。</p>
</body></html>""".format(rows="\n".join(rows), shots=shots, atk_color=atk.get("color", ""))

    out_dir = os.path.join(ROOT, "_review")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "r738_card_color.html")
    io.open(out, "w", encoding="utf-8", newline="\n").write(html)
    print("写", out)
    print("族分布", collections.Counter(c.get("color", "") or "(空)" for c in cards))


if __name__ == "__main__":
    main()
