# -*- coding: utf-8 -*-
"""R761 补丁 8/9：unlock_system.gd + ai_bridge.gd —— 隐藏职业不参与解锁，但可被指令开局。

* `UnlockSystem`：吟游诗人**不进解锁体系**（它没有故事 / 难度进度），开关打开即可用；
* `ai_bridge.new_run`：允许 `playable_ids()`（开关打开时含吟游诗人）；
* `ai_bridge` 新增 `POST /mode {"bard":true}` —— 店长「用指令打开特殊版本」的那条通道
  （命令行 `-- --bard` 是另一条，两条都落在 `PlayerClass.set_bard_enabled()`）。
"""
import io

UN = r"E:\work\card_rogue\scripts\unlock_system.gd"
AB = r"E:\work\card_rogue\scripts\ai_bridge.gd"


def edit(p, pairs):
    with io.open(p, "rb") as f:
        b = f.read()
    for old, new in pairs:
        o = old.encode("utf-8")
        c = b.count(o)
        assert c == 1, "%s 锚点命中 %d 次：%r" % (p, c, old[:70])
        b = b.replace(o, new.encode("utf-8"))
    with io.open(p, "wb") as f:
        f.write(b)
    print(p.split("\\")[-1], "OK")


edit(UN, [
    (
        'static func is_class_unlocked(cid: String) -> bool:\n'
        '\t## 该职业当前是否可选。\n'
        '\tif not GameBuild.is_release():\n',
        'static func is_class_unlocked(cid: String) -> bool:\n'
        '\t## 该职业当前是否可选。\n'
        '\t## R761：隐藏职业（吟游诗人）**不参与解锁体系** —— 它没有故事条件、也不该写进\n'
        '\t## 玩家档案的 `unlocked_classes`：开关打开就整份可用，关着根本不上界面。\n'
        '\tif PlayerClass.is_hidden_class(cid):\n'
        '\t\treturn PlayerClass.bard_enabled()\n'
        '\tif not GameBuild.is_release():\n',
    ),
    (
        'static func difficulty_cap(cid: String) -> int:\n'
        '\t## 该职业当前**可选到的最高难度**（含）。\n'
        '\tif not GameBuild.is_release():\n',
        'static func difficulty_cap(cid: String) -> int:\n'
        '\t## 该职业当前**可选到的最高难度**（含）。\n'
        '\t## R761：隐藏职业不给难度进度留档（它只给店长自测），开关打开即最高档。\n'
        '\tif PlayerClass.is_hidden_class(cid):\n'
        '\t\treturn RunState.DIFFICULTY_COUNT - 1\n'
        '\tif not GameBuild.is_release():\n',
    ),
])

edit(AB, [
    (
        '\tif not PlayerClass.ids().has(cid):\n'
        '\t\treturn {"ok": false, "msg": "职业只能是：%s" % "、".join(PlayerClass.ids())}\n',
        '\t# R761：`playable_ids()` = 可见三个 +（开关打开时）吟游诗人。随机摇人仍走 `ids()`，\n'
        '\t# 所以「吟游诗人不能被随机到」不受这里影响。\n'
        '\tif not PlayerClass.playable_ids().has(cid):\n'
        '\t\treturn {"ok": false, "msg": "职业只能是：%s" % "、".join(PlayerClass.playable_ids())}\n',
    ),
    (
        '\tif clean == "/rewind":\n'
        '\t\t_send(c, 200, "application/json; charset=utf-8", JSON.stringify(rewind_battle()))\n'
        '\t\treturn\n',
        '\tif clean == "/mode":\n'
        '\t\t# R761：隐藏职业「吟游诗人」的开关 —— 店长口径「只能我用指令打开的特殊版本」。\n'
        '\t\t# `{"bard":true}` 打开 / `{"bard":false}` 关掉；不传就是查询。\n'
        '\t\t# 与命令行 `-- --bard` 落在同一个唯一写入口 `PlayerClass.set_bard_enabled()`。\n'
        '\t\tvar dm: Variant = JSON.parse_string(body) if body.strip_edges() != "" else {}\n'
        '\t\tif dm is Dictionary and (dm as Dictionary).has("bard"):\n'
        '\t\t\tPlayerClass.set_bard_enabled(bool((dm as Dictionary)["bard"]))\n'
        '\t\t_send(c, 200, "application/json; charset=utf-8", JSON.stringify({\n'
        '\t\t\t"ok": true,\n'
        '\t\t\t"bard": PlayerClass.bard_enabled(),\n'
        '\t\t\t"playable": PlayerClass.playable_ids(),\n'
        '\t\t\t"msg": "吟游诗人：%s（选人界面%s）" % [\n'
        '\t\t\t\t\t"已开启" if PlayerClass.bard_enabled() else "已关闭",\n'
        '\t\t\t\t\t"已出现，需回到选人界面查看" if PlayerClass.bard_enabled() else "不再出现"],\n'
        '\t\t}))\n'
        '\t\treturn\n'
        '\tif clean == "/rewind":\n'
        '\t\t_send(c, 200, "application/json; charset=utf-8", JSON.stringify(rewind_battle()))\n'
        '\t\treturn\n',
    ),
])
