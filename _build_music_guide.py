#!/usr/bin/env python3
"""音乐试听指南 HTML 生成器：读 manifest，出自包含试听页/直链的指南。"""
import base64
import json
from pathlib import Path

MANIFEST = Path("E:/work/card_rogue/assets/audio/_audition/music_manifest.json")
OUT = Path("E:/work/card_rogue/assets/audio/_audition/试听指南.html")

SLOTS = [
    ("title", "标题页", "明亮·温暖·冒险感", "title.ogg"),
    ("class_pick", "角色选择", "轻快·期待", "class_pick.ogg"),
    ("map", "地图探索", "悠闲·森林·旅行感", "map.ogg"),
    ("deck", "卡组编辑/图鉴", "安静·专注", "deck.ogg"),
    ("battle", "普通战斗", "节奏感·不过重", "battle.ogg"),
    ("battle_elite", "精英战斗", "紧张·压迫", "battle_elite.ogg"),
    ("battle_boss", "Boss 战", "戏剧性·宏大", "battle_boss.ogg"),
    ("battle_boss_dark", "暗影系 Boss", "冷冽·激烈", "battle_boss_dark.ogg"),
    ("event", "事件页", "神秘·略带戏剧", "event.ogg"),
    ("reward", "奖励/宝箱", "惊喜·愉悦", "reward.ogg"),
    ("victory", "胜利结算", "成就·明亮", "victory.ogg"),
    ("defeat", "失败结算", "低沉·不甘", "defeat.ogg"),
]
# 氛围备注（来自音乐素材清单.md §3）
NOTES = {
    ("title", "Poema"): "史诗感开场，适合标题",
    ("title", "Morning Snowfields"): "晨光雪原，清透治愈",
    ("title", "きらめく世界"): "Bright/Warm/Cute/Fantasy，闪烁明亮",
    ("title", "空の匂い"): "天空气息，开阔",
    ("class_pick", "Positive_Happy"): "明快正向，选择界面合适",
    ("class_pick", "Sakuya2"): "日系抒情",
    ("class_pick", "Enjoyable 3"): "愉悦轻松",
    ("class_pick", "Cheerful Steps"): "轻快步伐感",
    ("map", "Sketch Forest"): "森林素描感，契合森林层",
    ("map", "Wonder 5"): "惊奇探索感",
    ("map", "森林ループ"): "Warm/Calm/Gentle/Healing/Piano",
    ("map", "Drifting Friday"): "漂浮悠闲",
    ("deck", "Teatime"): "午后茶会，安静整理感",
    ("deck", "Piano Refreshing"): "钢琴清爽",
    ("deck", "静かな祈り"): "安静祈祷，专注不打扰",
    ("battle", "Fight"): "标准战斗节奏",
    ("battle", "Wonder 2"): "轻快带张力",
    ("battle", "サイバー32"): "电子战斗感",
    ("battle_elite", "Battlefield 5"): "战场压迫感",
    ("battle_elite", "Strategy 4"): "策略紧张",
    ("battle_elite", "Raid 2"): "突袭感",
    ("battle_elite", "Breakthrough"): "突破推进感",
    ("battle_boss", "Dramatic"): "戏剧性宏大，正统 Boss 感",
    ("battle_boss", "Rapid 4"): "高速压迫",
    ("battle_boss", "Havoc"): "混乱激烈",
    ("battle_boss", "Valiant"): "英勇决战感",
    ("battle_boss", "Burning Heart"): "激燃摇滚，代表作",
    ("battle_boss_dark", "霜蝶の夢"): "冷冽幻想",
    ("battle_boss_dark", "超常現象"): "Mysterious/Dark/Fantasy",
    ("battle_boss_dark", "Black_Crystal"): "暗色水晶，冷调",
    ("battle_boss_dark", "Crimson_Moon"): "血月，危险感",
    ("event", "Augury"): "预兆／占卜感，事件契合",
    ("event", "Royal_Baroque"): "巴洛克宫廷，戏剧性",
    ("reward", "Wish4"): "希望／许愿，开箱惊喜",
    ("reward", "Music-box_Pleasant"): "音乐盒愉悦，可爱治愈",
    ("reward", "Harvest"): "丰收感，获得奖励契合",
    ("victory", "Soaring"): "翱翔上升，成就明亮",
    ("victory", "Holy Place"): "圣地庄严，胜利崇高感",
    ("victory", "シャイニングスター"): "闪亮之星，代表作",
    ("victory", "ハルジオン"): "代表作，明亮温柔",
    ("defeat", "Grief 2"): "悲伤低沉",
    ("defeat", "Music-box_Sad"): "音乐盒悲伤，温柔收尾",
    ("defeat", "Demise"): "终焉感，失败沉重",
    ("defeat", "月と狼"): "代表作，苍凉",
}
LIB_TAG = {"PeriTune": "PT", "OpenTracks": "OT", "魔王魂": "魔"}


def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def main():
    import re as _re
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    # 规范化：刮来的 title 等字段可能带页面缩进空白（\r\n\t），统一折叠
    def _norm(o):
        if isinstance(o, dict): return {k: _norm(v) for k, v in o.items()}
        if isinstance(o, list): return [_norm(v) for v in o]
        if isinstance(o, str): return _re.sub(r"\s+", " ", o).strip()
        return o
    m = _norm(m)
    rows = []
    for slot, cn, mood, fname in SLOTS:
        cards = []
        for c in m.get(slot, []):
            note = NOTES.get((slot, c["name"]), "")
            links = []
            if c.get("page"):
                links.append(f'<a class="btn" href="{esc(c["page"])}" target="_blank">试听页</a>')
            elif c.get("detail"):
                links.append(f'<a class="btn" href="{esc(c["detail"])}" target="_blank">试听页</a>')
            if c.get("mp3"):
                links.append(f'<a class="btn dl" href="{esc(c["mp3"])}" target="_blank">下载 mp3/zip</a>')
            if c.get("loop"):
                links.append(f'<a class="btn dl" href="{esc(c["loop"])}" target="_blank">下载 loop(ogg)</a>')
            if c.get("drive"):
                links.append(f'<a class="btn dl" href="{esc(c["drive"])}" target="_blank">Drive 下载</a>')
            if c.get("download"):
                links.append(f'<a class="btn dl" href="{esc(c["download"])}" target="_blank">下载页</a>')
            if c.get("ogg"):
                links.append(f'<a class="btn dl" href="{esc(c["ogg"])}" target="_blank">下载 ogg</a>')
            badge = LIB_TAG.get(c["lib"], "?")
            okmark = "" if c.get("ok") else ' <span class="fail">未解析</span>'
            cards.append(
                f'<div class="card"><div class="chead"><span class="lib lib-{esc(c["lib"])}">{esc(badge)}</span>'
                f'<span class="cname">{esc(c.get("title") or c["name"])}</span>{okmark}</div>'
                f'<div class="note">{esc(note)}</div>'
                f'<div class="links">{"".join(links) if links else "<span class=nolink>仅清单记录，无直链</span>"}</div></div>')
        rows.append(
            f'<section><h2>{esc(cn)} <code>{esc(fname)}</code><span class="mood">{esc(mood)}</span></h2>'
            f'<div class="grid">{"".join(cards)}</div></section>')

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8">
<title>card_rogue BGM 试听指南</title>
<style>
body{font-family:"Microsoft YaHei",system-ui,sans-serif;background:#f5f1e8;color:#2a2620;max-width:1100px;margin:0 auto;padding:24px}
h1{font-size:22px;border-bottom:3px solid #b08d3f;padding-bottom:8px}
.intro{background:#fffaf0;border:1px solid #d8c9a3;border-radius:8px;padding:12px 16px;font-size:13px;line-height:1.7}
section{margin-top:26px}
h2{font-size:16px;color:#6b4f1d;display:flex;align-items:center;gap:10px}
h2 code{background:#eee3c8;border-radius:4px;padding:1px 7px;font-size:12px}
.mood{font-size:12px;color:#8a7a58;font-weight:normal}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:10px;margin-top:8px}
.card{background:#fffdf7;border:1px solid #d8c9a3;border-radius:8px;padding:10px 12px}
.chead{display:flex;align-items:center;gap:8px}
.lib{font-size:10px;font-weight:700;border-radius:4px;padding:1px 6px;color:#fff}
.lib-PeriTune{background:#7a5af8}.lib-OpenTracks{background:#2e8b57}.lib-魔王魂{background:#b05a2a}
.cname{font-weight:600;font-size:14px}
.fail{color:#c00;font-size:11px}
.note{font-size:12px;color:#7a6f52;margin:4px 0 8px}
.links{display:flex;gap:6px;flex-wrap:wrap}
.btn{font-size:12px;text-decoration:none;border:1px solid #b08d3f;color:#6b4f1d;border-radius:5px;padding:3px 10px;background:#fff}
.btn:hover{background:#f3e7c8}
.btn.dl{background:#b08d3f;color:#fff;border-color:#8a6d2f}
.nolink{font-size:11px;color:#a39880}
footer{margin-top:32px;font-size:12px;color:#8a7a58;border-top:1px dashed #cbbd97;padding-top:10px;line-height:1.8}
</style></head><body>
<h1>card_rogue BGM 试听指南（候选池）</h1>
<div class="intro">
<b>怎么用：</b>每个槽位有 2–5 个候选。点 <b>「试听页」</b> 在曲库网站上直接试听
（PeriTune / OpenTracks / 魔王魂 三家页面都带播放器）；听到合适的记下曲名。<br>
<b>「下载」</b>按钮是直链（能点的都可以直接下）。PeriTune 老曲目的下载在 Google Drive 上的会标
「Drive 下载」。选中后把结论告诉我（或直接改 <code>音乐素材清单.md</code> 的「试听」列），
我来下载 OGG、改名、登记 credits.md 并挂接到场景。<br>
<b>建议顺序：</b>先定 P0 三首 —— <code>title</code> / <code>battle</code> / <code>battle_boss</code>，
这三首定基调，其余容易对齐。<br>
<b>许可提醒：</b>PeriTune = CC BY 4.0 <b>必须署名</b>；魔王魂建议署名；OpenTracks 不需要。
三家均禁止 AI 训练与作为主体内容。
</div>
""" + "".join(rows) + """
<footer>
图例：<span class="lib lib-PeriTune">PT</span> PeriTune（需署名）·
<span class="lib lib-OpenTracks">OT</span> OpenTracks（免署名）·
<span class="lib lib-魔王魂">魔</span> 魔王魂（建议署名）<br>
槽位文件名 = 选定后存入 <code>assets/audio/bgm/</code> 的统一命名（OGG 格式）。
</footer>
</body></html>"""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(html.encode("utf-8"))  # write_bytes: Windows 下 write_text 会把 \n 翻成 \r\n
    print(f"guide -> {OUT} ({len(html)} bytes)")


main()
