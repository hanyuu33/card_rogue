# -*- coding: utf-8 -*-
"""R631 补丁：道具三选一卡片 / 共享悬浮件的文字严格限定。

① `relic_pick_scene` 三选一卡片：字号写死 15、行距写死 24、**没有高度上限** ——
   描述一长就画到卡片框外（用户口径「描述超过了格子」）。
   改成 `CardFace.fit_text_lines`：折行 → 放不下缩字号（15→11）→ 缩到底才截断补「…」。
② `mention.relic_tip_metrics` 行距写死 19：FS_LABEL 的真实行高可能 > 19 → 相邻两行叠字。
   改成取字体真实行高。
"""
import io

EDITS = [
    ("scripts/relic_pick_scene.gd",
     '''		# 描述（字符级换行）
		var y := 150.0
		for line: String in _wrap_text(rel.desc, rect.size.x - 40.0, 15):
			draw_string(_font, rect.position + Vector2(20, y), line,
					HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, UiTheme.FS_BODY, Color("cfcabb"))
			y += 24.0''',
     '''		# 描述（R631：**严格限定在卡片内**）
		# 原来字号写死 15、行距写死 24、**没有任何高度上限**：描述一长就画到卡片框外。
		# 现在 折行 → 放不下缩字号（FS_BODY → 11）→ 缩到底才截断补「…」，绝不越框。
		var desc_w: float = rect.size.x - 40.0
		var desc_top := 150.0
		var desc_h: float = rect.size.y - desc_top - 18.0
		var fit := CardFace.fit_text_lines(_font, rel.desc, desc_w, desc_h,
				UiTheme.FS_BODY, 11, 99, true)
		var dfs: int = int(fit["fs"])
		var dlh: float = float(fit["line_h"]) + 2.0
		var dlines: Array = fit["lines"]
		var shown: int = mini(dlines.size(), maxi(0, int(floor(desc_h / dlh))))
		var y := desc_top
		for li in shown:
			var ln: String = str(dlines[li])
			if li == shown - 1 and dlines.size() > shown:
				ln = CardFace.ellipsize(_font, ln + "…", desc_w, dfs)
			# width 传 -1：`draw_string` 的 width 会把超出部分裁掉（贴边的字凭空消失）。
			draw_string(_font, rect.position + Vector2(20, y + dfs * 0.92), ln,
					HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color("cfcabb"))
			y += dlh'''),
    ("scripts/mention.gd",
     '''	var line := 19.0''',
     '''	# R631：行距取字体真实行高（写死的 19 配 FS_LABEL 会叠字）；量法与画法共用这一个数。
	var line: float = maxf(font.get_height(UiTheme.FS_LABEL), 19.0)'''),
]

for path, old, new in EDITS:
    s = io.open(path, encoding="utf-8", newline="").read()
    n = s.count(old)
    assert n == 1, (path, n)
    s = s.replace(old, new, 1)
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    b = io.open(path, "rb").read()
    print(path, "CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
