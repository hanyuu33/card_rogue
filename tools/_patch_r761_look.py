# -*- coding: utf-8 -*-
"""R761 补丁 3/9：外观映射 —— 职业色 / 元素族 / 素材键 / 卡图边框。

四个文件各一处 match，全部只加「吟游诗人」这一支，别的一律不动。
"""
import io

ROOT = r"E:\work\card_rogue\scripts"


def edit(name, pairs):
    p = ROOT + "\\" + name
    with io.open(p, "rb") as f:
        b = f.read()
    for old, new in pairs:
        o = old.encode("utf-8")
        c = b.count(o)
        assert c == 1, "%s 锚点命中 %d 次：%r" % (name, c, old[:60])
        b = b.replace(o, new.encode("utf-8"))
    with io.open(p, "wb") as f:
        f.write(b)
    print(name, "OK")


# ---------------------------------------------------------------- ui_theme.gd
edit("ui_theme.gd", [
    (
        'const CLASS_MECH := Color("b8860b")    ## 机械之心 黄铜\n',
        'const CLASS_MECH := Color("b8860b")    ## 机械之心 黄铜\n'
        '## R761：吟游诗人（隐藏职业）—— 青碧。故意避开森林的绿、刺客的紫、机械的黄铜，\n'
        '## 卡面左侧竖条 / 纸底色 / 选人界面描边一眼能认出是「另一个职业」。\n'
        'const CLASS_BARD := Color("1f8f8a")   ## 吟游诗人 青碧\n',
    ),
    (
        '\t\t"机械之心":\n'
        '\t\t\treturn CLASS_MECH\n'
        '\t\t"敌人":\n',
        '\t\t"机械之心":\n'
        '\t\t\treturn CLASS_MECH\n'
        '\t\t"吟游诗人":\n'
        '\t\t\treturn CLASS_BARD\n'
        '\t\t"敌人":\n',
    ),
])

# ---------------------------------------------------------------- fx_art.gd
edit("fx_art.gd", [
    (
        '\t"机械之心": FAM_HOLY,\n'
        '}\n',
        '\t"机械之心": FAM_HOLY,\n'
        '\t## R761：吟游诗人 = 水风（琴音如风）。现存八个族里唯一没被任何职业占用的一个，\n'
        '\t## 卡面写空 `color` 时它就是「吟游诗人的默认特效」。\n'
        '\t"吟游诗人": FAM_STORM,\n'
        '}\n',
    ),
])

# ---------------------------------------------------------------- ui_assets.gd
edit("ui_assets.gd", [
    (
        '\t\t"机械之心":\n'
        '\t\t\tkey = "mech"\n'
        '\tif key == "":\n'
        '\t\treturn null\n'
        '\treturn get_tex("class_" + key)\n',
        '\t\t"机械之心":\n'
        '\t\t\tkey = "mech"\n'
        '\t\t"吟游诗人":\n'
        '\t\t\tkey = "bard"   # R761：隐藏职业，缺图时调用方一律回退\n'
        '\tif key == "":\n'
        '\t\treturn null\n'
        '\treturn get_tex("class_" + key)\n',
    ),
    (
        '\t\t"机械之心":\n'
        '\t\t\treturn "mech"\n'
        '\treturn ""\n',
        '\t\t"机械之心":\n'
        '\t\t\treturn "mech"\n'
        '\t\t"吟游诗人":\n'
        '\t\t\treturn "bard"   # R761：class_cg_bard / class_avatar_bard\n'
        '\treturn ""\n',
    ),
])

# ---------------------------------------------------------------- card_face.gd
edit("card_face.gd", [
    (
        '\t\t"机械之心":\n'
        '\t\t\treturn "mech"\n'
        '\treturn "common"\n',
        '\t\t"机械之心":\n'
        '\t\t\treturn "mech"\n'
        '\t\t"吟游诗人":\n'
        '\t\t\t## R761：隐藏职业。`art_frame_bard.png` 还没做 → 走 `_draw_art_frame` 的同色细线\n'
        '\t\t\t## 回退（青碧），既不是公用白框、也不会空白。\n'
        '\t\t\treturn "bard"\n'
        '\treturn "common"\n',
    ),
    (
        '\t\t"common":\n'
        '\t\t\tcol = Color("f6f9fc")\n',
        '\t\t"common":\n'
        '\t\t\tcol = Color("f6f9fc")\n'
        '\t\t"bard":\n'
        '\t\t\tcol = Color("1f8f8a")   # R761：与 UiTheme.CLASS_BARD 同色\n',
    ),
])
