class_name FieldArt
extends RefCounted
## R847：场地边框素材的**唯一绘制口**。
##
## 约定与 `TrapArt` 同一套：`assets/ui/field_frame_<场地卡 id>.png` 一落盘就自动改用贴图，
## 界面代码一行都不用动；缺图（mod 去素材 / 旧包没带图）时返回 false，
## 调用方继续走原来的程序化画法（45° 斜纹 + 冷色描边 + 名字角标）。
##
## ⚠️ **为什么按 id 而不是按「场地族」**：店长口径（R847）「漩涡和清泉不该一样」——
##    场地卡的辨识度必须靠**每张自己的图案**，不能靠「持续型一律冷青」这种族级配色。
##    所以文件名带 id，六张各一张，互不共用。
##
## 尺寸：格子是 `CELL_W`(124) × `CELL`(110)（battle_scene），素材按 **2×** 出图
## （248×220），绘制时铺满整格由 `draw_texture_rect` 缩采样 —— 边框线粗、
## 缩小后仍然是「一圈边」，不会糊成一块色块。
##
## ⚠️ 素材开口必须**装得下卡面**（R847b）：格子 110 高、场上单位卡 92.4 高，
##    所以开口高度必须 ≥ 84%（缩到格子后 92.4px）。v1 素材只做到 60% → 实机卡片上下
##    直接顶出边框。这条由 `art_src/.../_cut_frames.py` 的 `self_check()` 硬把关，
##    不达标就不许落地 —— **不要在绘制侧放大去凑**，那会把框推出格子压到邻格。
##
## ⚠️ 素材必须**中间全透**：单位卡画在边框**下面**，边框盖在上面当装饰；
##    中心若留着白底，站上去的单位会被一块白膜糊住。抠图脚本
##    `art_src/2026-11-21_场地边框_R847/_cut_frames.py` 里「四边泛洪 + 中心泛洪」
##    两道掩膜就是干这个的，有专门的断言。

const FRAME_PREFIX := "field_frame_"
## 边框相对格子的内缩。R847b：**从 2 改 0** —— 框是用来包住卡面的，内缩每 1px 就把
## 开口高度白送掉 2px；格子 110 高、卡面 92.4 高，本来就只剩 8.8px 余量，再内缩 2px
## 就必然露馅（实机：卡片上下顶出边框）。相邻格靠边框自己的深色外描边分格，不需要留缝。
const FRAME_INSET := 0.0


static func frame_of(id: int) -> Texture2D:
	## 该场地卡的边框贴图；没有就返回 null（调用方回退程序化画法）。
	## 走 `UiAssets.get_tex()` —— 它已经带「导入资源 → 直读 PNG」双保险与缺图缓存。
	return UiAssets.get_tex(FRAME_PREFIX + str(id))


static func has_frame(id: int) -> bool:
	return frame_of(id) != null


static func draw_frame(ci: CanvasItem, rect: Rect2, id: int, alpha := 1.0) -> bool:
	## 把边框铺满整格。返回 **false = 没有素材**，调用方必须继续画程序化版本，
	## 不能「没画成就算了」—— 否则缺图时格子会变成什么都不显示。
	var tex := frame_of(id)
	if tex == null:
		return false
	var r := rect.grow(-FRAME_INSET)
	if alpha < 1.0:
		ci.draw_texture_rect(tex, r, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		ci.draw_texture_rect(tex, r, false)
	return true
