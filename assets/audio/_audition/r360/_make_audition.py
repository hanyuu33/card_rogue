# -*- coding: utf-8 -*-
"""R360 第三层 / 启示者 Boss 选曲试听包生成器。

把 raw/ 里下载的曲子统一摊到 audition/ 目录（zip 解出 mp3），
再生成自包含试听页 `试听.html`（相对路径引用本地 mp3，零网络）。
试听页按「第三层地图」/「启示者 Boss」/「对照·现有曲目」分组。
"""
import os
import shutil
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "audition")

# (显示名, 源文件名, 分组, 曲目页, 备注)
CANDIDATES = [
    # ---- 第三层地图 ----
    ("Soaring", "PerituneMaterial_Soaring.mp3", "map",
     "https://peritune.com/blog/2021/01/01/soaring/",
     "标签直接写着「天空・飞空艇・SF」；开阔爽快，适合白天高空直道"),
    ("Firmament3 Calm", "PerituneMaterial_Firmament3_Calm.mp3", "map",
     "https://peritune.com/blog/2020/07/01/firmament3/",
     "天空题材的造语（虚构语言）人声，Calm 版庄严而不吵，压得住「登舰」的仪式感"),
    ("Polar Lights", "PerituneMaterial_Polar_Lights.mp3", "map",
     "https://peritune.com/blog/2021/12/01/polar_lights/",
     "极光 / 冰 / SF 氛围，冷静辽阔，最不抢戏的一首"),
    ("Time and Pray", "PerituneMaterial_Time_and_Pray.mp3", "map",
     "https://peritune.com/blog/2020/10/30/time_and_pray/",
     "圣域・遗迹感，纯管弦无科幻音色；要「古老圣所」而非「机械战舰」时选它"),
    # ---- 启示者 Boss ----
    ("Firmament3 Active", "PerituneMaterial_Firmament3_Active.mp3", "boss",
     "https://peritune.com/blog/2020/07/01/firmament3/",
     "同曲的 Active 版：焦躁 + 勇壮 + 圣咏，最能撑「启示者」的宗教审判气质"),
    ("Rituale Machina", "PeriTune_Rituale_Machina.mp3", "boss",
     "https://peritune.com/blog/2026/07/30/rituale-machina/",
     "工业铁克诺 + 机械仪式，金属撞击的节拍像舰体在转阶段"),
    ("Rapid4", "PerituneMaterial_Rapid4.mp3", "boss",
     "https://peritune.com/blog/2018/11/27/rapid4/",
     "作者标明「空中战」的赛博战斗曲，疾走感最强，适合三阶段总攻"),
    ("Rapid5", "PerituneMaterial_Rapid5.mp3", "boss",
     "https://peritune.com/blog/2021/03/15/rapid5/",
     "Rapid4 的后辈：赛博 + 管弦 + DnB，比 Rapid4 更华丽"),
    ("Cyber Noir", "PerituneMaterial_Cyber_Noir.mp3", "boss",
     "https://peritune.com/blog/2021/08/31/cyber_noir/",
     "暗黑赛博朋克，冷硬压迫；Boss 段要「阴沉」不要「热血」时用它"),
    ("Relentless", "PeriTune_Relentless.mp3", "boss",
     "https://peritune.com/blog/2026/08/10/relentless/",
     "2026 新曲，185BPM 交响战斗，纯压迫；但见「版权」一节（新规约）"),
    ("Augury", "PerituneMaterial_Augury.mp3", "boss",
     "https://peritune.com/blog/",
     "「预兆 / 占卜」，与 Revelator（启示者）同义联想，神秘带戏剧性"),
    ("Havoc", "PerituneMaterial_Havoc.mp3", "boss",
     "https://peritune.com/blog/",
     "浩劫感，混乱激烈；适合第三阶段舰内起火"),
    ("Demise", "PerituneMaterial_Demise.mp3", "boss",
     "https://peritune.com/blog/",
     "崩坏 / 终结，低沉压迫；可做「残血」段落"),
]

GROUP_LABEL = {
    "map": "第三层地图（高空直道 · 白天科幻空艇）",
    "boss": "启示者 Boss 战（三阶段专属）",
}
GROUP_TIP = {
    "map": "要求：开阔、有高度感、不抢探索的注意力；不能像战斗曲。",
    "boss": "要求：机械 / 神圣压迫感，能撑住「远景舰炮 → 近景屏障 → 舰内起火」三段推进。",
}


def collect() -> list:
    """把候选源文件摊到 audition/；zip 只取 mp3。返回 [(显示名, 相对路径, 分组, 备注)]"""
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for label, src, group, page, note in CANDIDATES:
        src_path = os.path.join(RAW, src)
        dst_path = os.path.join(OUT, src)
        if os.path.exists(src_path):
            if (not os.path.exists(dst_path)
                    or os.path.getsize(dst_path) != os.path.getsize(src_path)):
                shutil.copy2(src_path, dst_path)
        else:
            # zip 整包：从同名 zip 里取 mp3（PeriTune 新曲只发整包）
            zname = src.replace(".mp3", ".zip")
            zpath = os.path.join(RAW, zname)
            if os.path.exists(zpath) and zipfile.is_zipfile(zpath):
                with zipfile.ZipFile(zpath) as z:
                    members = [m for m in z.namelist() if m.lower().endswith(".mp3")]
                    if members:
                        with z.open(members[0]) as fsrc, open(dst_path, "wb") as fdst:
                            shutil.copyfileobj(fsrc, fdst)
            elif os.path.exists(zpath):
                print("  !! zip 损坏（可能还在下）", zname)
        if not os.path.exists(dst_path) or os.path.getsize(dst_path) < 200000:
            print("  !! 缺（或过小）", src)
            continue
        rows.append((label, src, group, note, page))
    return rows


def human_size(n: int) -> str:
    return "%.1f MB" % (n / 1048576.0)


CSS = """
:root{--bg:#12141a;--card:#1c1f27;--line:#2c313d;--fg:#e9e6e0;--dim:#98a0ae;--gold:#d9b970;--cy:#6fc3d8}
*{box-sizing:border-box}
body{margin:0;padding:28px 32px 60px;background:var(--bg);color:var(--fg);
  font-family:"Microsoft YaHei",system-ui,sans-serif;line-height:1.6}
h1{margin:0 0 4px;font-size:22px;letter-spacing:.5px}
.lead{color:var(--dim);font-size:13px;margin:0 0 22px}
h2{margin:30px 0 4px;font-size:16px;color:var(--gold);border-left:3px solid var(--gold);padding-left:9px}
.tip{color:var(--dim);font-size:12px;margin:0 0 12px;padding-left:12px}
.row{background:var(--card);border:1px solid var(--line);border-radius:10px;
  padding:12px 14px;margin-bottom:10px;display:grid;
  grid-template-columns:190px 1fr;gap:10px 16px;align-items:center}
.name{font-size:14px;font-weight:600}
.name small{display:block;color:var(--cy);font-weight:400;font-size:11px;margin-top:2px}
.ctrl audio{width:100%;height:34px;display:block}
.note{grid-column:1/-1;color:var(--dim);font-size:12px;border-top:1px dashed var(--line);padding-top:8px}
.note a{color:var(--cy);text-decoration:none}
.sz{color:#6b7280;font-size:11px}
footer{margin-top:34px;color:#6b7280;font-size:12px;border-top:1px solid var(--line);padding-top:14px}
"""


def main() -> None:
    rows = collect()
    if not rows:
        print("没有可试听的曲目")
        return
    parts = ["""<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>R360 第三层 / 启示者 Boss 选曲试听</title><style>%s</style></head><body>
<h1>第三层 · 启示者 Boss 选曲试听</h1>
<p class="lead">全部为 PeriTune 原曲（未裁剪、未变调）。点播放即可，文件就在同目录 <code>audition/</code>。</p>
""" % CSS]
    for group in ("map", "boss"):
        items = [r for r in rows if r[2] == group]
        if not items:
            continue
        parts.append("<h2>%s</h2><p class=\"tip\">%s</p>" % (GROUP_LABEL[group], GROUP_TIP[group]))
        for label, fname, _, note, page in items:
            size = human_size(os.path.getsize(os.path.join(OUT, fname)))
            parts.append(
                '<div class="row"><div class="name">%s<small>%s</small></div>'
                '<div class="ctrl"><audio controls preload="none" src="audition/%s"></audio></div>'
                '<div class="note">%s <span class="sz">· %s</span> <a href="%s" target="_blank">曲目页</a></div></div>'
                % (label, fname, fname, note, size, page))
    parts.append("""<footer>选定后：取 PeriTune 官方 <code>_loop.zip</code> 里的 .ogg →
<code>assets/audio/bgm/&lt;槽位&gt;.ogg</code> → <code>credits.md</code> 登记 → <code>bgm.gd</code> 挂槽位。
授权：2026-02 之前的曲目为 CC BY 4.0（商用 / 同梱均可）；2026-03 起的新曲为 PeriTune 独自规约（署名任意，商用可，但「同梱二次配布」仅限非营利）。</footer>
</body></html>""")
    out = os.path.join(HERE, "试听.html")
    with open(out, "wb") as f:
        f.write("\n".join(parts).encode("utf-8"))
    print("生成", out, "曲目", len(rows))


if __name__ == "__main__":
    main()
