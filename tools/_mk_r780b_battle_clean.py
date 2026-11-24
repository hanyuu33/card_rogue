# -*- coding: utf-8 -*-
"""R780b：把 HEAD 版 battle_scene.gd + 我这一轮的改动，拼成一份**干净版本**。

用途：工作区里并行线正在写 `--handbonus`（半成品，解析不过），
不能拿工作区文件做语法/出图验证，也不能直接提交。
干净版本 = HEAD + 我的 hunk，用来 ① 验证我的改动单独成立 ② 作为提交内容备查。

`_draw_damage_cap_aura` 的函数体**从工作区实文件里抠**（那份才是我最新一版），
不在本脚本里硬编码第二份 —— 免得改了加强版忘了同步这里。
"""
import io
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"


def blk(s):
    return s.replace("\n", NL)


def read(p):
    return io.open(p, encoding="utf-8", newline="").read()


head = subprocess.run(["git", "-C", ROOT, "show", "HEAD:scripts/battle_scene.gd"],
                      capture_output=True)
if head.returncode != 0:
    sys.exit("git show 失败")
s = head.stdout.decode("utf-8")

ws = read(ROOT + "scripts/battle_scene.gd")
_a = ws.find("func _draw_damage_cap_aura(")
_b = ws.find("func _draw_stun_aura(", _a)
if _a < 0 or _b < 0:
    sys.exit("工作区里找不到 aura 函数")
AURA_TEXT = ws[_a:_b]          # 含结尾空行

pairs = []

pairs.append((
    blk('''	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。'''),
    blk('''	if engine.damage_cap_left(p) == 0:
		# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度已经吃满，
		# 接下来谁打它都进不去。这是**看卡面看不出来**的隐藏状态 ——
		# 卡面只写「每回合最多受到 20 点伤害」，不写「这一刻已经满了」，
		# 而玩家恰恰要靠这个决定「还要不要继续砸它」。
		# 图标由 `_state_slots()` 送进右上角圆槽，环与薄金罩在这里画。
		_draw_damage_cap_aura(center, w, h)
	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。''')))

pairs.append((
    blk('''	if p == null or p.card == null:
		return out
	if p.frozen:
		out.append({"glyph": "frozen", "label": "冰封"})'''),
    blk('''	if p == null or p.card == null:
		return out
	if engine.damage_cap_left(p) == 0:
		# R780b：本回合额度吃满 = 现在打它没用。**排在队列最前** —— 冰封 / 眩晕说的是
		# 「它不能动」，这条说的是「你打不动」，玩家下一步怎么打直接取决于它。
		out.append({"glyph": "immune", "label": "免伤"})
	if p.frozen:
		out.append({"glyph": "frozen", "label": "冰封"})''')))

pairs.append((
    blk('''func _draw_stun_aura(center: Vector2, w: float, h: float) -> void:'''),
    AURA_TEXT + blk('''func _draw_stun_aura(center: Vector2, w: float, h: float) -> void:''')))

pairs.append((
    blk('''		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。'''),
    blk('''		"damage_capped":
			# R780b：赫尔墨斯 / 量产型赫尔墨斯本回合的 20 点伤害额度吃掉了多少。
			# 额度满时引擎把扣血压到 0，`fx_impact` 判的是 `dmg > 0` → 不会发，
			# 于是敌人一拳打上去**画面一动不动**，看着像卡死了。这条就是补那个反馈。
			# 文案写「免伤 N」而不是「0 伤」：N 是**被上限吃掉**的量，玩家据此判断
			# 「这回合还吃不吃得动」；与能量屏障的「护盾 · 0 伤」（护盾碎掉，另一种事）区分开。
			var dcap_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var dcap_blocked := int(data.get("blocked", 0))
			if dcap_cell.x >= 0 and dcap_blocked > 0:
				var dcap_at := _hit_cue_at(dcap_cell)
				_bursts.append({"pos": _cell_center(dcap_cell), "sc": _grid_scroll,
						"start": dcap_at, "dur": 460, "col": Color("ffd863"), "big": false})
				_floaters.append({"pos": _cell_center(dcap_cell) + Vector2(0, -14),
						"sc": _grid_scroll, "text": "免伤 %d" % dcap_blocked,
						"col": Color("ffd863"), "start": dcap_at, "dur": 1400, "size": 17})
		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。''')))

for i, (o, n) in enumerate(pairs):
    c = s.count(o)
    if c != 1:
        sys.exit("第 %d 处锚点计数 %d" % (i + 1, c))
    s = s.replace(o, n, 1)

out = ROOT + "tools/_tmp_r780b_battle_clean.gd"
io.open(out, "w", encoding="utf-8", newline="").write(s)
print("CLEAN_OK lines=%d aura_lines=%d" % (s.count(NL), AURA_TEXT.count(NL)))
