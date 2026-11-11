## R577f：道具图标高亮的光效参数唯一口（纯静态，无 class_name → 消费方显式 preload）。
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
	## 唯一动态层的主时钟相位 0..1（2.4s 一圈）。
	return fmod(now_ms, SWEEP_CYCLE_MS) / SWEEP_CYCLE_MS


static func sweep_angle(now_ms: float, i: int) -> float:
	## 每格按格位 +22° 错相，六条弧像一道光波扫过，不是齐转（齐转 = 齐闪）。
	return 360.0 * sweep_phase(now_ms) + float(i) * SWEEP_PHASE_STEP_DEG


static func sweep_color(j: int) -> Color:
	## 第 j 段短弧：头亮尾深 + 渐隐拖尾（与预览 9 段插值同源）。
	var k := 1.0 - float(j) / float(SWEEP_SEGMENTS)
	var col := SWEEP_TAIL.lerp(SWEEP_HEAD, k)
	col.a = SWEEP_ALPHA * pow(k, 1.7)
	return col
