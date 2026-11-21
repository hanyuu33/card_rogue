# -*- coding: utf-8 -*-
"""R847：加 `_test_r847()`（场地边框素材）并注册（test_engine.gd，CRLF 保持）。"""
import io
import sys

P = r"E:\work\card_rogue\scripts\test_engine.gd"

REG_OLD = '\t_test_r846()\r\n'
REG_NEW = '\t_test_r846()\r\n\t_test_r847()\r\n'

FUNC = '''

func _test_r847() -> void:
	## R847：六张场地卡的**边框素材** —— 有图、尺寸对、而且**中间真的透**。
	## 为什么要单测透明度：单位卡画在边框**下面**，中心若留着白底，站上去的单位会被
	## 一块白膜糊住（抠图脚本 `art_src/2026-11-21_场地边框_R847/_cut_frames.py` 跑的是
	## 「四边泛洪 + 中心泛洪」两道掩膜，这条断言就是那份自检的复制）。
	## 顺带钉住「缺图必须回退」——`draw_frame()` 返回 false 调用方才去画斜纹，
	## 若哪天有人改成「没图就什么都不画」，空格子会变成完全看不出挂着场地。
	var fs_ids: Array[int] = [8028, 8036, 8037, 9186, 8082, 9224]
	for fid: int in fs_ids:
		var ftex := FieldArt.frame_of(fid)
		check(ftex != null, "R847 场地 %d 应有边框素材 field_frame_%d.png" % [fid, fid])
		if ftex == null:
			continue
		check(ftex.get_width() == 248 and ftex.get_height() == 220,
				"R847 场地 %d 边框应 248×220（格子 124×110 的 2×），实际 %d×%d"
				% [fid, ftex.get_width(), ftex.get_height()])
		var fimg := ftex.get_image()
		check(fimg != null, "R847 场地 %d 边框取不到 Image，无法核透明度" % fid)
		if fimg == null:
			continue
		check(fimg.get_pixel(fimg.get_width() / 2, fimg.get_height() / 2).a == 0.0,
				"R847 场地 %d 边框中心必须全透（否则糊住站上去的单位）" % fid)
	check(not FieldArt.has_frame(999999),
			"R847 未知 id 不该有边框素材（缺图要回退程序化画法，不能静默不画）")
'''


def main() -> int:
    raw = io.open(P, "rb").read().decode("utf-8")
    if raw.count(REG_OLD) != 1:
        print("注册点命中 %d 次" % raw.count(REG_OLD))
        return 2
    raw = raw.replace(REG_OLD, REG_NEW, 1)
    if not raw.endswith("\r\n"):
        raw += "\r\n"
    raw += FUNC.replace("\n", "\r\n")
    io.open(P, "wb").write(raw.encode("utf-8"))
    print("PATCH ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
