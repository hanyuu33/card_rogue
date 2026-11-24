# -*- coding: utf-8 -*-
"""R836d：smoke 加一条「缺陷时钟时针动画 + 角标口径」的真场景断言。

为什么放 smoke 不放 engine：动画是**绘制层**的事（fx 字典 + 画在棋盘正中），
engine 套件没有 battle_scene 实例，只有真场景能验「fx 起在哪、素材有没有、入口接没接上」。
角标那半条在 engine 的 `_test_r832` 里也有（纯数据层），两边各守一层。

⚠️ test_smoke.gd 是 CRLF。
"""
ROOT = "E:/work/card_rogue/"
TE = "scripts/test_smoke.gd"
b = open(ROOT + TE, "rb").read()


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8")


def rep(b, old, new, tag):
    assert b.count(old) == 1, "[%s] 命中 %d 次" % (tag, b.count(old))
    return b.replace(old, new)


# ① 注册一条真场景用例（插在 _check_battle 那条之前）
anchor = crlf(
    "\t\t[\"res://scenes/battle.tscn\", func():\n"
    "\t\t\t\t_reset()\n"
    "\t\t\t\tRunState.start_run(_map())\n"
    "\t\t\t\tRunState.pending_node = {\"type\": \"battle\"}\n"
    "\t\t\t\tRunState.pending_level = RunState.next_level({\"type\": \"battle\"}),\n"
    "\t\t\t_check_battle],\n"
)
new = crlf(
    "\t\t# R836（用户口径）：缺陷时钟触发时战斗区正中要播「时针转动」，且触发之后\n"
    "\t\t#   本场不再显示计数。纯绘制 + 一个 fx 字典，只有真场景能验位置与入口。\n"
    "\t\t[\"res://scenes/battle.tscn\", func():\n"
    "\t\t\t\t_reset()\n"
    "\t\t\t\tRunState.start_run(_map())\n"
    "\t\t\t\tRunState.pending_node = {\"type\": \"battle\"}\n"
    "\t\t\t\tRunState.pending_level = RunState.next_level({\"type\": \"battle\"}),\n"
    "\t\t\t_check_r836_clock_fx],\n"
    "\t\t[\"res://scenes/battle.tscn\", func():\n"
    "\t\t\t\t_reset()\n"
    "\t\t\t\tRunState.start_run(_map())\n"
    "\t\t\t\tRunState.pending_node = {\"type\": \"battle\"}\n"
    "\t\t\t\tRunState.pending_level = RunState.next_level({\"type\": \"battle\"}),\n"
    "\t\t\t_check_battle],\n"
)
b = rep(b, anchor, new, "smoke.reg")

# ② 断言函数（追加到文件末尾）
FUNC = crlf(
    "\n"
    "\n"
    "func _check_r836_clock_fx(scene) -> void:\n"
    "\t## R836（用户口径）：缺陷时钟触发 → 战斗区正中播「时针转动」的小动画；\n"
    "\t## 角标在**触发之后本场不再显示**（下一场重新数）。\n"
    "\t## 断言四件事：① 素材真的在（缺图会静默退化成程序化表盘，出货不能靠兜底）\n"
    "\t## ② fx 起在棋盘正中、时长对 ③ 起始入口只在触发分支里被调 ④ 角标口径。\n"
    "\tif UiAssets.clock_face() == null:\n"
    "\t\t_smoke_fail(\"R836 钟面：assets/fx/clock_face.png 没被导入（会退化成程序化表盘）\")\n"
    "\t\treturn\n"
    "\tRunState.relics = [6084]\n"
    "\tRunState.spent_relics = []\n"
    "\tscene.engine.self_relics = [6084]\n"
    "\tscene._clock_fx = {}\n"
    "\tscene._start_clock_fx()\n"
    "\tif scene._clock_fx.is_empty():\n"
    "\t\t_smoke_fail(\"R836 时针动画：触发后没有起 fx\")\n"
    "\t\treturn\n"
    "\tvar cp: Vector2 = scene._clock_fx[\"pos\"]\n"
    "\tvar want := Vector2(scene.GRID_X + scene.GRID_W * 0.5, scene.GRID_Y + scene.GRID_H * 0.5)\n"
    "\tif cp.distance_to(want) > 0.5:\n"
    "\t\t_smoke_fail(\"R836 时针动画：没画在战斗区正中（%s vs %s）\" % [str(cp), str(want)])\n"
    "\t\treturn\n"
    "\tif int(scene._clock_fx[\"dur\"]) != 1150:\n"
    "\t\t_smoke_fail(\"R836 时针动画：时长漂移（%d）\" % int(scene._clock_fx[\"dur\"]))\n"
    "\t\treturn\n"
    "\t# 角标口径：>0 才画；0（本场已触发）/ -1（没有战斗上下文）都不画\n"
    "\tif RunState.relic_badge_text(6084, 0) != \"\":\n"
    "\t\t_smoke_fail(\"R836 角标：触发后本场不该再显示计数\")\n"
    "\t\treturn\n"
    "\tif RunState.relic_badge_text(6084) != \"\":\n"
    "\t\t_smoke_fail(\"R836 角标：无战斗上下文时不该画\")\n"
    "\t\treturn\n"
    "\tif RunState.relic_badge_text(6084, 7) != \"7\":\n"
    "\t\t_smoke_fail(\"R836 角标：未触发时应画「7」（实际「%s」）\"\n"
    "\t\t\t\t% RunState.relic_badge_text(6084, 7))\n"
    "\t\treturn\n"
    "\t# 入口守卫：绘制与起始都必须接在这个文件里（别被后来的改动悄悄摘掉）\n"
    "\tvar src := FileAccess.get_file_as_string(\"res://scripts/battle_scene.gd\")\n"
    "\tif not src.is_empty():\n"
    "\t\tif not src.contains(\"\\t_draw_clock_fx()\"):\n"
    "\t\t\t_smoke_fail(\"R836 守卫：`_draw()` 里没有接 `_draw_clock_fx()`\")\n"
    "\t\t\treturn\n"
    "\t\tif not src.contains(\"\\t\\t\\t_start_clock_fx()\"):\n"
    "\t\t\t_smoke_fail(\"R836 守卫：defect_clock 分支没有起动画\")\n"
    "\t\t\treturn\n"
    "\tprint(\"SMOKE OK R836 缺陷时钟：时针动画起在棋盘正中 / 素材在位 / 角标触发后不画\")\n"
)
b = b + FUNC
open(ROOT + TE, "wb").write(b)
print("smoke 断言已加")
