# -*- coding: utf-8 -*-
"""生成「本地试听页」：读 music_manifest.json + raw/ 已下载文件，
输出 试听_本地.html（每槽位一组 <audio controls>，全部走本地文件，零网络）。
原始「试听指南.html」（在线链接版）保持不变。
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "music_manifest.json")
LIB_DIR = {"PeriTune": "peritune", "魔王魂": "maou", "OpenTracks": "opentracks"}
SLOT_LABEL = {
    "title": "标题页", "class_pick": "角色选择", "map": "地图探索",
    "deck": "卡组编辑/图鉴", "battle": "普通战斗", "battle_elite": "精英战斗",
    "battle_boss": "Boss 战", "battle_boss_dark": "暗影系 Boss",
    "event": "事件页", "reward": "奖励/宝箱", "victory": "胜利结算",
    "defeat": "失败结算",
    "battle_hot": "战斗·热血追加候选（R175 追加：魔王魂 金属/战斗曲 + PeriTune 战闘曲）",
}


def local_file(lib: str, t: dict) -> str:
    if lib == "PeriTune":
        return "raw/peritune/" + os.path.basename(t["mp3"]) if t.get("mp3") else ""
    if lib == "魔王魂":
        return "raw/maou/" + os.path.basename(t["ogg"])
    if lib == "OpenTracks":
        return "raw/opentracks/%s.mp3" % t["detail"].rstrip("/").rsplit("/", 1)[-1]
    return ""


def main() -> None:
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    secs = []
    for slot, tracks in manifest.items():
        cards = []
        for t in tracks:
            f = local_file(t["lib"], t)
            exists = f and os.path.exists(os.path.join(HERE, f))
            audio = ('<audio controls preload="none" src="%s"></audio>' % f
                     if exists else '<span class="miss">未下载</span>')
            cards.append(
                '<div class="card"><div class="chead"><span class="lib">%s</span>'
                '<span class="cname">%s</span></div>%s</div>'
                % (t["lib"], t["name"], audio))
        secs.append('<section><h2>%s <code>%s.ogg</code></h2><div class="grid">%s'
                    '</div></section>'
                    % (SLOT_LABEL.get(slot, slot), slot, "".join(cards)))
    html = """<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>BGM 本地试听（raw/）</title>
<style>
body{font-family:system-ui,"Microsoft YaHei",sans-serif;background:#14161c;color:#e8e6e3;margin:24px}
h1{font-size:20px} h2{font-size:16px;color:#d8b86c;margin:22px 0 8px}
code{background:#262a33;padding:2px 6px;border-radius:4px;font-size:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:10px}
.card{background:#1d2027;border:1px solid #2e323d;border-radius:10px;padding:10px 12px}
.chead{display:flex;gap:8px;align-items:center;margin-bottom:8px}
.lib{background:#3a3f4d;border-radius:4px;font-size:11px;padding:1px 6px;flex:none}
.cname{font-size:13px;word-break:break-all}
audio{width:100%;height:32px}
.miss{color:#a33;font-size:12px}
p.tip{color:#9aa0ab;font-size:12px}
</style></head><body>
<h1>BGM 本地试听</h1>
<p class="tip">全部来自本目录 raw/ 已下载文件（preload=none，点播放才加载）。
选定后：转 OGG → 存入 assets/audio/bgm/ → 登记 credits.md → bgm.gd 挂载（-12dB）。</p>
@@SECTIONS@@
</body></html>""".replace("@@SECTIONS@@", "\n".join(secs))
    out = os.path.join(HERE, "试听_本地.html")
    with open(out, "wb") as f:
        f.write(html.encode("utf-8"))
    print("生成", out)


if __name__ == "__main__":
    main()
