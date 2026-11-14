# -*- coding: utf-8 -*-
"""在 HEAD 版副本上重放 R692 的引擎 / 战斗界面 / 测试补丁，产出「干净 HEAD + 只含 R692」的三个 blob。

用法：python tools/_idx_r692.py
"""
import re
import subprocess

REPO = "E:/work/card_rogue/"
TMP = "E:/work/_r692idx/"


def run_patch(src, subs, tag):
    """读 tools/<src>，按 subs 改写路径，写到临时文件后执行（带 --write）。"""
    code = open(REPO + "tools/" + src, "rb").read().decode("utf-8")
    for o, n in subs:
        assert code.count(o) >= 1, "[%s] 路径锚点缺失：%s" % (tag, o)
        code = code.replace(o, n)
    dst = TMP + "_run_" + src
    open(dst, "wb").write(code.encode("utf-8"))
    r = subprocess.run(["python", dst, "--write"], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    print("[%s] rc=%d" % (tag, r.returncode))
    for line in (r.stdout or "").strip().splitlines()[-4:]:
        print("   ", line)
    if r.returncode != 0:
        print((r.stderr or "")[-1200:])
        raise SystemExit(1)


# ① 引擎
run_patch("_patch_r692_engine.py", [
    ('P = "E:/work/card_rogue/scripts/game_engine.gd"', 'P = "E:/work/_r692idx/game_engine.gd"'),
], "engine")

# ② 测试（test_engine + test_assemble）
run_patch("_patch_r692_tests.py", [
    ('P = "E:/work/card_rogue/scripts/test_engine.gd"', 'P = "E:/work/_r692idx/test_engine.gd"'),
    ('PA = "E:/work/card_rogue/scripts/test_assemble.gd"', 'PA = "E:/work/_r692idx/test_assemble.gd"'),
], "tests")

# ③ 旧锁反转
run_patch("_patch_r692_legacy.py", [
    ('P = "E:/work/card_rogue/scripts/test_engine.gd"', 'P = "E:/work/_r692idx/test_engine.gd"'),
], "legacy")

# ③b 测试里的两处手工修正（脚本化不了：字段名 / 变量名撞车）
te = open(TMP + "test_engine.gd", "rb").read().decode("utf-8")
FIX = [
    ('and dm_mom.move_speed == 1 and dm_mom.rarity == 1 and dm_mom.class == "森林精魄"',
     'and dm_mom.move_speed == 1 and dm_mom.rarity == 1 and dm_mom.card_class == "森林精魄"'),
]
for o, n in FIX:
    assert te.count(o) == 1, "test_engine 修正锚点 %d" % te.count(o)
    te = te.replace(o, n)
import re as _re
st = te.find("	var dm_e := _new_engine([], 20, 20, -1, false)")
assert st > 0
en = te.find("	# ③ 最左列", st)
assert en > st
seg = te[st:en]
seg = _re.sub(r"dm_e", "dmm_e", seg)
te = te[:st] + seg + te[en:]
open(TMP + "test_engine.gd", "wb").write(te.encode("utf-8"))
print("[tests] 应用 card_class / dmm_e 两处修正")

# ④ battle_scene：本轮只有两条播报分支，直接对 HEAD 副本做定点插入
bs = open(TMP + "battle_scene.gd", "rb").read().decode("utf-8")
CR = "\r\n"
anchor = '\t\t"water_element":' + CR
assert bs.count(anchor) == 1, bs.count(anchor)
block = CR.join([
    '\t\t"duck_mother":',
    '\t\t\t_say("鸭妈妈：两侧共召唤 %d 只「小鸭」" % int(data.get("count", 0)))',
    '\t\t"duckling":',
    '\t\t\tvar dk_name := ""',
    '\t\t\tif data.get("card") is CardData:',
    '\t\t\t\tdk_name = (data["card"] as CardData).card_name',
    '\t\t\tif dk_name == "":',
    '\t\t\t\t_say("小鸭：手卡没有效果卡 → 落空")',
    '\t\t\telse:',
    '\t\t\t\t_say("小鸭：手卡「%s」费用 -1" % dk_name)',
]) + CR
bs = bs.replace(anchor, anchor + block)
open(TMP + "battle_scene.gd", "wb").write(bs.encode("utf-8"))
print("[battle_scene] 插入两条播报")

# ⑤ 自检：重建出来的文件里不能有并行线的痕迹
GUARD = {
    "game_engine.gd": ["func use_tool"],
    "battle_scene.gd": ["_use_tool_slot", "SHOP_POS"],
    "test_engine.gd": ["R692b"],
}
for f, marks in GUARD.items():
    txt = open(TMP + f, "rb").read().decode("utf-8", errors="replace")
    for m in marks:
        if m in txt:
            raise SystemExit("[%s] 混入并行线标记：%s" % (f, m))
print("自检通过：三个文件都不含并行线改动")
