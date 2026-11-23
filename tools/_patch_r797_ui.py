# -*- coding: utf-8 -*-
"""R797：relic_repo 奖励池 + trap_art 程序化兜底 + 四语/三语/术语表/条数。"""
import json

ROOT = "E:/tmp/wt794/"
fails = []


def patch(path, pairs, nl="\n"):
    raw = open(ROOT + path, "rb").read().decode("utf-8")
    for old, new in pairs:
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = raw.count(o)
        if c != 1:
            fails.append("%s: %d → %r" % (path, c, old[:46]))
            continue
        raw = raw.replace(o, n)
    open(ROOT + path, "wb").write(raw.encode("utf-8"))
    print("patched %-28s CRLF %d / LF %d" % (path, raw.count("\r\n"), raw.count("\n")))


# ---------- relic_repo：6078 进奖励池 ----------
patch("scripts/relic_repo.gd", [
    ("""			6070, 6071, 6072, 6073, 6074, 6076, 6077]""",
     """			6070, 6071, 6072, 6073, 6074, 6076, 6077, 6078]"""),
    ("""	# R796：加「兔脚」6076（战后金币 +10、工具掉率 +10% 加算）与「钻头」6077
	#   （X 费卡 X ≥ 6 时翻倍）。都是「战后 / 出牌时」被动，一般档、不锁剧情。""",
     """	# R796：加「兔脚」6076（战后金币 +10、工具掉率 +10% 加算）与「钻头」6077
	#   （X 费卡 X ≥ 6 时翻倍）。都是「战后 / 出牌时」被动，一般档、不锁剧情。
	# R797：加「龟壳」6078（上回合没攻击过的己方单位受伤 -2，至少 1）。同样一般档。"""),
])

# ---------- trap_art：河豚配色 + 程序化兜底 ----------
patch("scripts/trap_art.gd", [
    ("""		7014: return Color(0.58, 0.72, 0.98)   # 智慧药剂 · 智慧蓝""",
     """		7014: return Color(0.58, 0.72, 0.98)   # 智慧药剂 · 智慧蓝
		7015: return Color(0.94, 0.62, 0.38)   # 河豚 · 河豚橙"""),
    ("""		7014: _wisdom(ci, c, s, ink)""",
     """		7014: _wisdom(ci, c, s, ink)
		7015: _puffer(ci, c, s, ink)"""),
    ("""static func _bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:""",
     """static func _puffer(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R797 河豚 7015：圆身 + 一圈短刺 + 小尾鳍（程序化兜底；有 png 时整段不走）。
	var w := maxf(1.2, s * 0.028)
	var body := c + Vector2(-s * 0.03, s * 0.01)
	# 刺：12 根放射短线，长度带一点参差（免得像太阳）
	for k in 12:
		var a := TAU * float(k) / 12.0
		var d := Vector2(cos(a), sin(a))
		var far := s * (0.34 if k % 3 == 0 else 0.29)
		ci.draw_line(body + d * s * 0.20, body + d * far, col, w, true)
	ci.draw_circle(body, s * 0.21, col)
	# 眼睛：白点 + 黑瞳（小尺寸下就是一深一浅两个点）
	ci.draw_circle(body + Vector2(s * 0.09, -s * 0.05), s * 0.045,
			Color(1, 1, 1, col.a))
	ci.draw_circle(body + Vector2(s * 0.10, -s * 0.05), s * 0.022, col)
	# 尾鳍：两个三角
	var tail := c + Vector2(s * 0.26, s * 0.02)
	ci.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(s * 0.11, -s * 0.10),
			tail + Vector2(s * 0.11, s * 0.10)]), col)


static func _bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:"""),
])

# ---------- 四语：龟壳 6078 ----------
NONCARD = {
    "i18n/noncard_zh_canonical.json": {
        "name": "龟壳",
        "desc": "你上回合没有攻击过的己方单位，受到的伤害 -2（至少仍受 1 点）。"},
    "i18n/noncard_en.json": {
        "name": "Turtle Shell",
        "desc": "Your allies that did not attack last turn take 2 less damage "
                "(still at least 1)."},
    "i18n/noncard_ja.json": {
        "name": "亀の甲羅",
        "desc": "前のターンに攻撃していない自分の味方が受けるダメージ -2（最低でも 1 は受ける）。"},
    "i18n/noncard_es.json": {
        "name": "Caparazón de tortuga",
        "desc": "Tus aliados que no atacaron en el turno anterior reciben 2 puntos "
                "menos de daño (como mínimo 1)."},
}
for f, row in NONCARD.items():
    d = json.loads(open(ROOT + f, encoding="utf-8").read())
    assert "6078" not in d["relics"], f
    d["relics"]["6078"] = row
    open(ROOT + f, "w", encoding="utf-8", newline="").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print("%-34s relics %d" % (f, len(d["relics"])))

# ---------- 三语：河豚 7015 ----------
TRAPS = {
    "i18n/traps_en.json": {
        "name": "Pufferfish",
        "desc": "Drag it onto an empty battlefield cell. An enemy that steps on it "
                "is knocked back to the cell it came from and takes 3 damage; "
                "the tool is then used up."},
    "i18n/traps_ja.json": {
        "name": "フグ",
        "desc": "戦場の空きマスにドラッグして設置する。踏んだ敵は元いたマスまで弾き戻され、"
                "3 ダメージを受ける。使用後は消費される。"},
    "i18n/traps_es.json": {
        "name": "Pez globo",
        "desc": "Arrástrala a una casilla vacía del campo. El enemigo que la pise "
                "retrocede a la casilla de la que venía y recibe 3 de daño; "
                "después, la herramienta se consume."},
}
for f, row in TRAPS.items():
    d = json.loads(open(ROOT + f, encoding="utf-8").read())
    assert "7015" not in d["traps"], f
    d["traps"]["7015"] = row
    open(ROOT + f, "w", encoding="utf-8", newline="").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    print("%-34s traps %d" % (f, len(d["traps"])))

print("失败：", fails if fails else "无")
