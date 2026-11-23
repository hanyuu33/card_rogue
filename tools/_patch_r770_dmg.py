# -*- coding: utf-8 -*-
"""R770：给 test_engine 补一段「伤害数字美术规格」的纯函数断言。

插在 R384 段落（预览口只读）之后、R386（对话气泡）之前。
锚点用行内容匹配，不做模糊查找；命中行数必须恰好 1，否则直接拒绝写入。
行尾保持 CRLF（test_engine.gd 在 CRLF 名单里）。
"""
import io
import sys

P = 'scripts/test_engine.gd'
ANCHOR = 'R384 源码：预览口只读'

raw = open(P, 'rb').read()
text = raw.decode('utf-8')
if 'R770：伤害数字' in text:
    sys.exit('[patch] 已经打过这个补丁了，停止')

lines = text.split('\r\n')
hits = [i for i, ln in enumerate(lines) if ANCHOR in ln]
if len(hits) != 1:
    sys.exit('[patch] 锚点命中 %d 次（应为 1），停止' % len(hits))
idx = hits[0]
print('[patch] 锚点在第 %d 行：%s' % (idx + 1, lines[idx].strip()[:60]))

BLOCK = '''
	# ══════════════════════════════════════════════════════════════════
	# R770：伤害数字的美术规格（scripts/dmg_number.gd）
	# 纯函数、不碰场景 → 曲线 / 分级 / 配色全在这里直接测；「真的画进 _draw 会不会刷
	# ERROR」交给 smoke。⚠️ 这些数值是观感的**下限**，不是拟合结果：调曲线时要一起改。
	# ══════════════════════════════════════════════════════════════════
	var r770_a0: Dictionary = DmgNumber.anim(0.0)
	var r770_am: Dictionary = DmgNumber.anim(0.5)
	var r770_a1: Dictionary = DmgNumber.anim(1.0)
	check(float(r770_a0["alpha"]) < 0.05,
			"R770 曲线：t=0 不该立刻全亮（前 4% 是显形段）")
	check(float(r770_am["alpha"]) > 0.9,
			"R770 曲线：中段要定住不淡（数字得留在眼前读）")
	check(float(r770_a1["alpha"]) < 0.02, "R770 曲线：t=1 必须淡尽")
	# 弹性：开段必须冲过 1 再回落 —— 这是「弹」的全部来源，不冲就只是淡入
	var r770_peak := 0.0
	for i in 17:
		var r770_s: Dictionary = DmgNumber.anim(float(i) / 16.0 * 0.16)
		r770_peak = maxf(r770_peak, float(r770_s["scale"]))
	check(r770_peak > 1.15,
			"R770 曲线：开段要冲过 1.15 再回落（实测峰值 %.2f）" % r770_peak)
	check(absf(float(r770_am["scale"]) - 1.0) < 0.06, "R770 曲线：中段缩放在 1 附近")
	check(float(r770_a1["dy"]) < -40.0,
			"R770 曲线：末帧要飘够高度（实测 %.1f）" % float(r770_a1["dy"]))
	check(float(DmgNumber.anim(0.9)["dy"]) > float(r770_a1["dy"]),
			"R770 曲线：上飘必须单调（后段变慢但不回头）")
	# 分级两道坎
	check(DmgNumber.tier_of_amount(14) == DmgNumber.TIER_NORMAL, "R770 分级：14 = 普通")
	check(DmgNumber.tier_of_amount(15) == DmgNumber.TIER_HEAVY, "R770 分级：15 = 重击")
	check(DmgNumber.tier_of_amount(30) == DmgNumber.TIER_FATAL, "R770 分级：30 = 致命")
	check(DmgNumber.tier_of_amount(-35) == DmgNumber.TIER_FATAL, "R770 分级：负数取绝对值")
	check(DmgNumber.size_scale(DmgNumber.TIER_FATAL) > DmgNumber.size_scale(DmgNumber.TIER_HEAVY)
			and DmgNumber.size_scale(DmgNumber.TIER_HEAVY)
			> DmgNumber.size_scale(DmgNumber.TIER_NORMAL),
			"R770 分级：字号倍率必须 普通 < 重击 < 致命")
	# 判据：只认整串数字，说明文字不许被当成分量
	check(DmgNumber.amount_of_text("-12") == -12, "R770 判据：-12 是伤害数字")
	check(DmgNumber.amount_of_text("+7") == 7, "R770 判据：+7 是治疗数字")
	check(DmgNumber.amount_of_text("接下 5") < 0, "R770 判据：说明文字不当数字画")
	check(DmgNumber.amount_of_text("-3 暴击") < 0, "R770 判据：带后缀的不当纯数字")
	check(DmgNumber.amount_of_text("冰封") < 0, "R770 判据：纯中文不当数字画")
	# 配色：默认红走金白分级；特殊色（中毒绿）必须保留色相 —— 功能性区分不能被吞
	var r770_pn: Dictionary = DmgNumber.palette(DmgNumber.TIER_NORMAL, UiTheme.SIDE_FOE)
	var r770_pf: Dictionary = DmgNumber.palette(DmgNumber.TIER_FATAL, UiTheme.SIDE_FOE)
	check((r770_pn["core"] as Color) != (r770_pf["core"] as Color),
			"R770 配色：普通与致命必须不同色")
	check((r770_pn["core"] as Color).v - (r770_pn["edge"] as Color).v > 0.65,
			"R770 配色：core 与 edge 明度差 > 0.65（成对定，符号才立得住）")
	var r770_pois := Color("6fbf3a")
	var r770_pp: Dictionary = DmgNumber.palette(DmgNumber.TIER_NORMAL, r770_pois)
	var r770_pc: Color = r770_pp["core"]
	check(absf(r770_pc.h - r770_pois.h) < 0.03,
			"R770 配色：中毒数字保留毒绿色相（不能被金白吞掉）")
	check(r770_pc.v > 0.9, "R770 配色：保留色相也要提亮到 v>0.9（暗绿读不出来）")
	# 源码守卫：飘字与拖卡预览必须共用同一套笔法（两处各写一份必然漂移）
	var r770_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check_src(r770_bs.find("DmgNumber.amount_of_text") >= 0
			and r770_bs.find("_paint_dmg_number(_font_bold, Vector2.ZERO") >= 0
			and r770_bs.find("_paint_dmg_number(_font_bold, center") >= 0,
			"R770 源码：飘字与预览共用 _paint_dmg_number（数字 + 预览两个调用点）")
	check_src(r770_bs.find("_draw_string_box_center(_font_bold, size, txt,") >= 0,
			"R770 源码：说明类飘字仍走带底条样式（不能全换成大字）")
'''

insert = BLOCK.split('\n')
# BLOCK 首尾各有一个空串（三引号自带），去掉首尾
while insert and insert[0] == '':
    insert.pop(0)
while insert and insert[-1] == '':
    insert.pop()

out = lines[:idx + 1] + insert + lines[idx + 1:]
new = '\r\n'.join(out)
open(P, 'wb').write(new.encode('utf-8'))
print('[patch] 已插入 %d 行，总行数 %d -> %d' % (len(insert), len(lines), len(out)))
