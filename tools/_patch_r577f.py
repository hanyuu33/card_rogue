# -*- coding: utf-8 -*-
"""R577f：把「单层转动 + 蓝色边缘光」（P1 原黄，不加深）落进游戏。

口径（店长）：删掉中心亮斑柔光 / 完整硬环 / 图标爆白，只留
  ① 贴图标 alpha 轮廓的冷蓝边缘光（恒定、不呼吸）
  ② 唯一动态层：暖琥珀渐隐拖尾弧，每格错相 22°。
颜色保持预览默认档「P1 原黄」，**不加深**。

补丁可重跑（每个锚点 exact-replace + count==1，已打过则 SKIP）；
`--check-only` 只验锚点不写盘。ROOT 可被外部覆盖，便于从 HEAD 干净版重放。
行尾：battle_scene / test_engine / test_smoke 是 CRLF，其余 LF —— apply() 自动归一化。
"""
import io
import os
import sys

ROOT = r'E:/work/card_rogue'
CHECK_ONLY = '--check-only' in sys.argv

# ---------------------------------------------------------------- 新增纯静态光效口
RELIC_FX = '''## R577f：道具图标高亮的光效参数唯一口（纯静态，无 class_name → 消费方显式 preload）。
## 店长口径：「单层（只有转动那一层）＋蓝色边缘光」，转动层换回 P1 暖琥珀，
## 「不需要加深」→ 保持预览默认档原黄，不用加深一档 / 两档。
## 这里只放常量与纯函数：亮/灭判定仍在 GameEngine.relic_highlight()，一行不动。
const SWEEP_CYCLE_MS := 2400.0
const SWEEP_PHASE_STEP_DEG := 22.0
const SWEEP_SEGMENTS := 9
const SWEEP_SEG_DEG := 11.0
const SWEEP_WIDTH := 3.0
## 预览默认档：头 (255,222,150) / 尾 (214,140,40)，标签「P1 原黄」。
## ⚠️ 别改成加深一档 (255,208,108) —— 店长已明确「不需要加深」。
const SWEEP_HEAD := Color(1.0, 0.870588, 0.588235)
const SWEEP_TAIL := Color(0.839216, 0.549020, 0.156863)
const SWEEP_ALPHA := 0.941176
## 蓝色边缘光：预生成在 assets/ui/relic_rim_<id>.png，恒定、不呼吸。
const RIM_BLUE := Color(0.337255, 0.698039, 1.0)
const RIM_HALO := Color(0.219608, 0.541176, 0.941176)
## 亮图标本体只做极轻冷调，所有分量 <= 1（LDR 画布不会爆白吃掉贴图细节）。
const ICON_LIT := Color(0.97, 0.99, 1.0, 1.0)


static func sweep_phase(now_ms: float) -> float:
\t## 唯一动态层的主时钟相位 0..1（2.4s 一圈）。
\treturn fmod(now_ms, SWEEP_CYCLE_MS) / SWEEP_CYCLE_MS


static func sweep_angle(now_ms: float, i: int) -> float:
\t## 每格按格位 +22° 错相，六条弧像一道光波扫过，不是齐转（齐转 = 齐闪）。
\treturn 360.0 * sweep_phase(now_ms) + float(i) * SWEEP_PHASE_STEP_DEG


static func sweep_color(j: int) -> Color:
\t## 第 j 段短弧：头亮尾深 + 渐隐拖尾（与预览 9 段插值同源）。
\tvar k := 1.0 - float(j) / float(SWEEP_SEGMENTS)
\tvar col := SWEEP_TAIL.lerp(SWEEP_HEAD, k)
\tcol.a = SWEEP_ALPHA * pow(k, 1.7)
\treturn col
'''

# ---------------------------------------------------------------- 1. battle_scene.gd
BS = 'scripts/battle_scene.gd'
BS_PRELOAD_OLD = 'const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")\n'
BS_PRELOAD_NEW = '''const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")
## R577f：光效参数唯一口（同样无 class_name，显式 preload headless 才读得到）。
const RelicFx = preload("res://scripts/relic_fx.gd")
'''

BS_PHASE_OLD = '''func _relic_lit_phase() -> float:
\t## 呼吸相位（0..1）：柔光 / 图标提亮 / 外环共用同一相位，别各跳各的。
\treturn 0.5 + 0.5 * sin(float(_now()) / 220.0)
'''
BS_PHASE_NEW = '''func _relic_lit_phase() -> float:
\t## R577f：唯一动态层（暖黄转动弧）的主时钟相位 0..1，周期 2.4s。
\t## 柔光 / 硬环 / 图标爆白三层都删了，只剩这一层在转，别再引入第二套节奏。
\treturn RelicFx.sweep_phase(float(_now()))


func _relic_sweep_angle(i: int) -> float:
\t## R577f：转动弧起始角（度），每格按格位错相；test_smoke 直接调它验。
\treturn RelicFx.sweep_angle(float(_now()), i)


func _draw_relic_sweep(rect: Rect2, i: int) -> void:
\t## R577f：**唯一动态层** —— 9 段短弧拼出 99° 渐隐拖尾，绕图标缓慢转动。
\t## 没有完整硬环、没有中心亮斑、没有第二层柔光（店长口径：单层）。
\tvar cc := rect.get_center()
\tvar rad := rect.size.x * 0.5 + 9.0
\tvar a0 := _relic_sweep_angle(i)
\tfor j in RelicFx.SWEEP_SEGMENTS:
\t\tvar ang0 := deg_to_rad(a0 - (float(j) + 1.0) * RelicFx.SWEEP_SEG_DEG)
\t\tvar ang1 := deg_to_rad(a0 - float(j) * RelicFx.SWEEP_SEG_DEG)
\t\tdraw_arc(cc, rad, ang0, ang1, 5, RelicFx.sweep_color(j), RelicFx.SWEEP_WIDTH, true)
'''

BS_MOD_DOC_OLD = '''\t## R577e：**图标本体**的着色 —— 亮着的提亮成青白，灰掉的压灰，其余原色。
\t## 这是「道具图标高亮」的界面分发口（test_smoke 直接调它验，不靠截图猜）。
'''
BS_MOD_DOC_NEW = '''\t## R577f：图标本体的着色 —— 亮着的只做极轻冷调（分量 <= 1，LDR 不爆白），
\t## 灰掉的压灰，其余原色。高亮交给「蓝色边缘光 + 暖黄转动弧」两层。
\t## 这是界面分发口（test_smoke 直接调它验，不靠截图猜）。
'''
BS_MOD_BODY_OLD = '''\tif _relic_icon_lit(i):
\t\tvar ph := _relic_lit_phase()
\t\treturn Color(1.10 + 0.14 * ph, 1.22 + 0.16 * ph, 1.34 + 0.16 * ph, 1.0)
\treturn Color.WHITE
'''
BS_MOD_BODY_NEW = '''\tif _relic_icon_lit(i):
\t\treturn RelicFx.ICON_LIT
\treturn Color.WHITE
'''

BS_DRAW_HEAD_OLD = '''\t\t# R577c（店长口径）：去掉每件道具的横条底 / 边框 / 来源色块，图标本身就是格子。
\t\t# R577e：高亮 = **图标本体提亮** + 外圈青白呼吸环；环画在图标之后才看得全，
\t\t# 底层柔光用 fx_glow 贴图（R577c 不要框，硬边圆盘不再画）。
\t\tvar lit577e := _relic_icon_lit(i)
\t\tif lit577e and _fx_glow_tex != null:
\t\t\tdraw_texture_rect(_fx_glow_tex, rect.grow(13.0), false,
\t\t\t\t\tColor(0.56, 0.92, 1.0, 0.30 + 0.22 * _relic_lit_phase()))
'''
BS_DRAW_HEAD_NEW = '''\t\t# R577c（店长口径）：去掉每件道具的横条底 / 边框 / 来源色块，图标本身就是格子。
\t\t# R577f：高亮 = 蓝色边缘光（恒定、贴轮廓）+ 唯一动态层暖黄转动弧。
\t\t# 中心亮斑柔光 / 完整硬环 / 图标爆白三层全删（店长：单层 + 蓝边，不需要加深）。
\t\tvar lit577f := _relic_icon_lit(i)
'''

BS_DRAW_TAIL_OLD = '''\t\telse:
\t\t\tdraw_texture_rect(tex, rect, false, _relic_icon_modulate(i))
\t\t# R577e 顶环：画在图标**之后**，完整压在图标外沿上（旧版画在前面被 44x44 吃掉）。
\t\tif lit577e:
\t\t\tvar lit_ph := _relic_lit_phase()
\t\t\tvar lit_col := Color(0.56, 0.92, 1.0)
\t\t\tvar cc := rect.get_center()
\t\t\tdraw_arc(cc, rect.size.x * 0.66, 0.0, TAU, 40,
\t\t\t\t\tColor(lit_col.r, lit_col.g, lit_col.b, 0.72 + 0.24 * lit_ph), 2.2, true)
'''
BS_DRAW_TAIL_NEW = '''\t\telse:
\t\t\tdraw_texture_rect(tex, rect, false, _relic_icon_modulate(i))
\t\t\t# R577f：蓝色边缘光贴图标 alpha 轮廓，画在本体之后；缺 rim 时只画弧。
\t\t\tvar rim577f := UiAssets.relic_rim(int(ids[i]))
\t\t\tif lit577f and rim577f != null:
\t\t\t\tdraw_texture_rect(rim577f, rect, false, Color.WHITE)
\t\t# R577f：唯一动态层 —— 暖黄渐隐拖尾弧，画在蓝边之后，每格错相 22°。
\t\tif lit577f:
\t\t\t_draw_relic_sweep(rect, i)
'''

# ---------------------------------------------------------------- 2. ui_assets.gd
UA = 'scripts/ui_assets.gd'
UA_OLD = '''\treturn get_tex("relic_icon_%d" % id)


static func div_orb_glass() -> Texture2D:
'''
UA_NEW = '''\treturn get_tex("relic_icon_%d" % id)


static func relic_rim_path(id: int) -> String:
\t## R577f：沿图标 alpha 轮廓预生成的「蓝色边缘光」叠加图（128x128 RGBA）。
\t## 文件名即契约；换 rim 只覆盖 assets/ui/relic_rim_<id>.png。
\treturn path_for("relic_rim_%d" % id)


static func relic_rim(id: int) -> Texture2D:
\t## R577f：蓝色边缘光**唯一取图口**。缺图返回 null → 界面只画转动弧，照常可玩。
\t## 6061~6063 三样信物走 R543 的 key_icon_*，且不参与高亮判定，故无 rim。
\tif id == 6061 or id == 6062 or id == 6063:
\t\treturn null
\treturn get_tex("relic_rim_%d" % id)


static func div_orb_glass() -> Texture2D:
'''

# ---------------------------------------------------------------- 3. test_engine.gd
TE = 'scripts/test_engine.gd'
TE_PRELOAD_OLD = 'const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")\n'
TE_PRELOAD_NEW = '''const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")
## R577f：光效参数唯一口（同样无 class_name，显式 preload）。
const RelicFx = preload("res://scripts/relic_fx.gd")
'''

TE_R577E_LOCK_OLD = '''\tvar r577e_p_icon := r577e_bs.find("draw_texture_rect(tex, rect, false, _relic_icon_modulate(i))")
\tvar r577e_p_ring := r577e_bs.find("R577e 顶环")
\tcheck_src(r577e_p_icon > 0 and r577e_p_ring > r577e_p_icon,
\t\t\t"R577e 源码：外环画在图标之后（不会被 44x44 贴图吃掉）")
'''
TE_R577E_LOCK_NEW = '''\tvar r577e_p_icon := r577e_bs.find("draw_texture_rect(tex, rect, false, _relic_icon_modulate(i))")
\tvar r577f_p_rim := r577e_bs.find("draw_texture_rect(rim577f, rect, false, Color.WHITE)")
\tvar r577f_p_arc := r577e_bs.find("_draw_relic_sweep(rect, i)")
\tcheck_src(r577e_p_icon > 0 and r577f_p_rim > r577e_p_icon and r577f_p_arc > r577f_p_rim,
\t\t\t"R577f 源码：蓝边与转动弧都画在图标之后（不会被 44x44 贴图吃掉）")
'''

TE_ANCHOR = '\t# ================= R339：续档不重复计数 / 一层只打一次 Boss =================\n'
TE_R577F_BLOCK = '''\t# ============ R577f：单层转动 + 蓝色边缘光（P1 原黄，不加深） ============
\tcheck(RelicFx.SWEEP_CYCLE_MS == 2400.0 and RelicFx.SWEEP_PHASE_STEP_DEG == 22.0
\t\t\tand RelicFx.SWEEP_SEGMENTS == 9,
\t\t\t"R577f 数据：唯一动态层 2.4s 一圈 / 每格错相 22° / 9 段拖尾")
\tcheck(RelicFx.sweep_phase(0.0) == 0.0 and RelicFx.sweep_phase(2400.0) == 0.0
\t\t\tand RelicFx.sweep_phase(600.0) > 0.24 and RelicFx.sweep_phase(600.0) < 0.26,
\t\t\t"R577f 数据：主时钟相位守恒（0 / 2.4s 归零，600ms = 0.25）")
\tcheck(absf(RelicFx.sweep_angle(1000.0, 1) - RelicFx.sweep_angle(1000.0, 0)
\t\t\t- RelicFx.SWEEP_PHASE_STEP_DEG) < 0.001,
\t\t\t"R577f 数据：相邻两格弧角差恒为 22°（不齐转）")
\tvar r577f_head := RelicFx.sweep_color(0)
\tcheck(r577f_head.r > 0.99 and r577f_head.g > 0.86 and r577f_head.b > 0.58
\t\t\tand r577f_head.b < 0.60,
\t\t\t"R577f 数据：转动层是 P1 原黄档（未加深）")
\tcheck(RelicFx.sweep_color(8).a < r577f_head.a * 0.1,
\t\t\t"R577f 数据：拖尾末端几乎全透明（渐隐）")
\tvar r577f_lit := RelicFx.ICON_LIT
\tcheck(r577f_lit.r <= 1.0 and r577f_lit.g <= 1.0 and r577f_lit.b <= 1.0,
\t\t\t"R577f 数据：图标本体着色分量 <= 1（LDR 不爆白）")
\tvar r577f_missing := 0
\tfor r577f_id in range(6001, 6061):
\t\tif not ResourceLoader.exists("res://assets/ui/relic_rim_%d.png" % r577f_id):
\t\t\tr577f_missing += 1
\tcheck(r577f_missing == 0,
\t\t\t"R577f 素材：60 张蓝色边缘光贴图齐全（缺 %d）" % r577f_missing)
\tvar r577f_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
\tvar r577f_ua := FileAccess.get_file_as_string("res://scripts/ui_assets.gd")
\tcheck_src(r577f_bs.contains("func _draw_relic_sweep(")
\t\t\tand r577f_bs.contains("func _relic_sweep_angle(")
\t\t\tand r577f_ua.contains("func relic_rim("),
\t\t\t"R577f 源码：单层转动与蓝色边缘光各有唯一口")
\tcheck_src(not r577f_bs.contains("R577e 顶环")
\t\t\tand not r577f_bs.contains("_fx_glow_tex, rect.grow(13.0)")
\t\t\tand not r577f_bs.contains("Color(1.10 + 0.14 * ph"),
\t\t\t"R577f 源码：中心亮斑 / 完整硬环 / 爆白 modulate 全删")

'''

# ---------------------------------------------------------------- 4. test_smoke.gd
SM = 'scripts/test_smoke.gd'
SM_OLD_ASSERT = '''\tvar r577e_lit_col: Variant = scene._relic_icon_modulate(0)
\tif r577e_lit_col.r <= 1.0 or r577e_lit_col.b <= 1.0:
\t\t_smoke_fail("R577e 界面分发：亮着的图标本体没提亮（%s）" % str(r577e_lit_col))
\t\treturn
'''
SM_NEW_ASSERT = '''\tvar r577e_lit_col: Variant = scene._relic_icon_modulate(0)
\tif r577e_lit_col == Color.WHITE:
\t\t_smoke_fail("R577f 界面分发：亮着的图标本体应走极轻冷调（%s）" % str(r577e_lit_col))
\t\treturn
\tif r577e_lit_col.r > 1.0 or r577e_lit_col.g > 1.0 or r577e_lit_col.b > 1.0:
\t\t_smoke_fail("R577f 界面分发：图标着色分量 >1 会爆白（%s）" % str(r577e_lit_col))
\t\treturn
'''

SM_TAIL_OLD = '''\tif not scene._relic_bar_lit():
\t\t_smoke_fail("R577e 界面分发：有亮图标时呼吸重绘没接上")
\t\treturn


func _check_discard_view(scene: Variant) -> void:
'''
SM_TAIL_NEW = '''\tif not scene._relic_bar_lit():
\t\t_smoke_fail("R577e 界面分发：有亮图标时呼吸重绘没接上")
\t\treturn
\t# R577f 界面分发：单层转动 + 蓝色边缘光
\tif not ResourceLoader.exists("res://assets/ui/relic_rim_6042.png"):
\t\t_smoke_fail("R577f 界面分发：风妖精的蓝色边缘光贴图缺失")
\t\treturn
\tvar r577f_a0: float = scene._relic_sweep_angle(0)
\tvar r577f_a1: float = scene._relic_sweep_angle(1)
\tif absf(r577f_a1 - r577f_a0 - 22.0) > 0.001:
\t\t_smoke_fail("R577f 界面分发：相邻格转动弧没按 22° 错相")
\t\treturn
\tvar r577f_ph: float = scene._relic_lit_phase()
\tif r577f_ph < 0.0 or r577f_ph >= 1.0:
\t\t_smoke_fail("R577f 界面分发：主时钟相位越界（%f）" % r577f_ph)
\t\treturn


func _check_discard_view(scene: Variant) -> void:
'''


def path(rel_name):
    return os.path.join(ROOT, rel_name)


def apply(rel_name, old, new, label):
    p = path(rel_name)
    raw = io.open(p, 'rb').read()
    crlf = raw.count(b'\r\n') > 0
    s = raw.decode('utf-8').replace('\r\n', '\n')
    if new in s:
        print('SKIP ', label)
        return
    n = s.count(old)
    assert n == 1, '%s 锚点命中 %d 次（应为 1）' % (label, n)
    if CHECK_ONLY:
        print('CHECK', label)
        return
    out = s.replace(old, new, 1)
    data = (out.replace('\n', '\r\n') if crlf else out).encode('utf-8')
    io.open(p, 'wb').write(data)
    print('APPLY', label)


def ensure_new(rel_name, content, marker):
    p = path(rel_name)
    want = content.encode('utf-8')
    if os.path.isfile(p):
        got = io.open(p, 'rb').read()
        if got == want:
            print('SKIP ', rel_name)
            return
        assert marker.encode('utf-8') in got, '%s 不是本补丁管理的文件，不覆盖' % rel_name
        assert not CHECK_ONLY, 'check-only：%s 需要更新' % rel_name
        io.open(p, 'wb').write(want)
        print('UPDATE', rel_name)
        return
    assert not CHECK_ONLY, 'check-only：%s 尚未创建' % rel_name
    os.makedirs(os.path.dirname(p), exist_ok=True)
    io.open(p, 'wb').write(want)
    print('CREATE', rel_name)


def main():
    ensure_new('scripts/relic_fx.gd', RELIC_FX, 'R577f')
    apply(BS, BS_PRELOAD_OLD, BS_PRELOAD_NEW, 'BS preload')
    apply(BS, BS_PHASE_OLD, BS_PHASE_NEW, 'BS 主时钟 + 单层转动')
    apply(BS, BS_MOD_DOC_OLD, BS_MOD_DOC_NEW, 'BS modulate 注释')
    apply(BS, BS_MOD_BODY_OLD, BS_MOD_BODY_NEW, 'BS modulate 收回 <=1')
    apply(BS, BS_DRAW_HEAD_OLD, BS_DRAW_HEAD_NEW, 'BS 删中心亮斑')
    apply(BS, BS_DRAW_TAIL_OLD, BS_DRAW_TAIL_NEW, 'BS 蓝边 + 转动弧')
    apply(UA, UA_OLD, UA_NEW, 'UA 唯一取图口')
    apply(TE, TE_PRELOAD_OLD, TE_PRELOAD_NEW, 'TE preload')
    apply(TE, TE_R577E_LOCK_OLD, TE_R577E_LOCK_NEW, 'TE 适配 R577e 顺序锁')
    apply(TE, TE_ANCHOR, TE_R577F_BLOCK + TE_ANCHOR, 'TE R577f 三层判据')
    apply(SM, SM_OLD_ASSERT, SM_NEW_ASSERT, 'SM 适配爆白断言')
    apply(SM, SM_TAIL_OLD, SM_TAIL_NEW, 'SM R577f 界面分发')
    print('PATCH', 'CHECK OK' if CHECK_ONLY else 'DONE')


if __name__ == '__main__':
    main()
