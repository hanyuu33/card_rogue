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
## ⚠️ 素材必须**中间全透**：单位卡画在边框**下面**，边框盖在上面当装饰；
##    中心若留着白底，站上去的单位会被一块白膜糊住。抠图脚本
##    `art_src/2026-11-21_场地边框_R847/_cut_frames.py` 里「四边泛洪 + 中心泛洪」
##    两道掩膜就是干这个的，有专门的断言。

const FRAME_PREFIX := "field_frame_"
## 边框相对格子的内缩：相邻格的边框会**边贴边**，不留缝会连成一片大网格，
## 看不出「哪个格子挂着场地」。2px（1280×720 下）刚好把相邻两格分开，又不吃掉格内空间。
const FRAME_INSET := 2.0


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
