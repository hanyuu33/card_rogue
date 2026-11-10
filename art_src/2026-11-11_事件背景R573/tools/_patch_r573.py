# -*- coding: utf-8 -*-
"""R573 补丁：① 删除蓝色大肥鱼（bluefish）事件 ② 飞行器文案改成喷气背包 ③ 文档登记。

纪律：
  · 全部 Python exact-replace + assert count==1，锚点按 repr 抄，不猜缩进。
  · CRLF 文件（test_engine.gd）统一转 LF 处理、写回时再转 CRLF，bareLF 必须仍为 0。
  · LF 文件写回时不做任何换行转换（Edit 工具会把 CRLF 转 LF，这里一律不碰）。
  · 可重跑：已打过的补丁会因 count==0 直接断言失败，不会二次破坏。
"""
from pathlib import Path

ROOT = Path(r"E:\work\card_rogue")


def patch(rel: str, pairs, crlf: bool = False):
    p = ROOT / rel
    raw = p.read_bytes()
    s = raw.decode("utf-8")
    if crlf:
        assert raw.count(b"\r\n") > 0, rel + " 不是 CRLF"
        s = s.replace("\r\n", "\n")
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, "%s 锚点命中 %d 次：%r" % (rel, n, old[:70])
        s = s.replace(old, new, 1)
    out = (s.replace("\n", "\r\n") if crlf else s).encode("utf-8")
    p.write_bytes(out)
    b = p.read_bytes()
    bare = b.count(b"\n") - b.count(b"\r\n")
    assert (bare == 0) if crlf else (b.count(b"\r\n") == 0), rel + " 行尾被污染"
    print("OK", rel, "(CRLF)" if crlf else "(LF)")


# ---------------------------------------------------------------- game_layers.gd
patch("scripts/game_layers.gd", [
    (
        '\t\t#               绝赞五换一（hero，随机删 5 张不同名的卡 → 得「英雄」）\n'
        '\t\t#               蓝色大肥鱼（bluefish，可将一张「鲸鱼之怒」加入卡组）\n'
        '\t\t# 从第一层挪来的：鸭之凝视（gaze，获得道具「一袋米抗几楼」）\n',
        '\t\t#               绝赞五换一（hero，随机删 5 张不同名的卡 → 得「英雄」）\n'
        '\t\t# R573：蓝色大肥鱼（bluefish）事件已删除，不再登记，别照旧文档补回来。\n'
        '\t\t# 从第一层挪来的：鸭之凝视（gaze，获得道具「一袋米抗几楼」）\n',
    ),
    (
        '\t\t\t"hero": 20,       # 绝赞五换一（第二层专属）：随机删 5 张不同名的卡 → 得「英雄」\n'
        '\t\t\t"bluefish": 20,   # 蓝色大肥鱼（第二层专属）：可将一张「鲸鱼之怒」加入卡组\n'
        '\t\t\t"gaze": 18,',
        '\t\t\t"hero": 20,       # 绝赞五换一（第二层专属）：随机删 5 张不同名的卡 → 得「英雄」\n'
        '\t\t\t"gaze": 18,',
    ),
    (
        '\t"hero": "绝赞五换一",\n'
        '\t"bluefish": "蓝色大肥鱼",\n'
        '\t"apple_doctor": "苹果与医生",\n',
        '\t"hero": "绝赞五换一",\n'
        '\t"apple_doctor": "苹果与医生",\n',
    ),
])


# ---------------------------------------------------------------- event_scene.gd
patch("scripts/event_scene.gd", [
    (
        '##   * event + bluefish 蓝色大肥鱼（第二层专属）：把一张「鲸鱼之怒」加入卡组，或放弃；\n',
        '##   * R573：蓝色大肥鱼（bluefish）事件已删除，旧存档只剩「已移除」兜底页；\n',
    ),
    (
        '##   事件 = rest / treasure / whisper / struggle / gaze / pear / apple_doctor / bluefish /\n'
        '##          moon（R351 赏月）/ relic_chest。\n',
        '##   事件 = rest / treasure / whisper / struggle / gaze / pear / apple_doctor /\n'
        '##          moon（R351 赏月）/ relic_chest / flyer（R555 飞行器）。\n',
    ),
    (
        'const WHALE_CARD_ID := 9050       # 鲸鱼之怒（蓝色大肥鱼事件的奖励卡，不可奖励获取）\n',
        'const WHALE_CARD_ID := 9050       # 鲸鱼之怒（占卜室幻象「鲸鱼」的解读奖励，不可奖励获取）\n',
    ),
    (
        'const FLYER_DESC := """空地中央停着一架旧飞行器，桨叶歪歪地指着天。\n'
        '坐上去，它能把你直接送到任何一个还没去过的房间——\n'
        '代价是 1 块巧克力；巧克力只剩 1 块或没有的时候，它飞不起来。"""\n'
        '\n'
        'const FLYER_TAKEN_DESC := """引擎已经热起来了，桨叶搅得空气嗡嗡响。\n'
        '回到地图后挑一个没去过的房间，它就把你送过去。"""\n',
        'const FLYER_DESC := """空地中央立着一架旧喷气背包，两只喷口还留着一点余温。\n'
        '背上它，你能直接飞到任何一个还没去过的房间——\n'
        '代价是 1 块巧克力；巧克力只剩 1 块或没有的时候，它飞不起来。"""\n'
        '\n'
        'const FLYER_TAKEN_DESC := """喷口已经热起来了，暖橙色的火苗轻轻跳着。\n'
        '回到地图后挑一个没去过的房间，它就把你送过去。"""\n',
    ),
    (
        'const BLUEFISH_DESC := """一条通体蓝色的大肥鱼搁浅在岸边，肚皮一起一伏，像还在做梦。\n'
        '它翻了个身，从嘴里吐出一枚亮晶晶的东西——\n'
        '「鲸鱼之怒」：1 费技能，造成 11 点伤害，\n'
        '随后可从弃牌堆选 2 张卡回到手牌；用掉之后本场战斗里不再出现。\n'
        '要不要把它捡起来？"""\n'
        '\n'
        'const BLUEFISH_TAKEN_DESC := """大肥鱼心满意足地打了个嗝，翻着肚皮漂远了。\n'
        '「鲸鱼之怒」已经躺进你的卡组——什么时候用它，就看你了。"""\n',
        '# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。\n'
        'const RETIRED_EVENT_DESC := """这里原本有一条蓝色大肥鱼。它已经游走了。"""\n',
    ),
    (
        'var _bluefish_taken := false  # 蓝色大肥鱼：是否已收下「鲸鱼之怒」\n',
        '',
    ),
    (
        'func _is_bluefish() -> bool:\n'
        '\t## 蓝色大肥鱼（第二层专属事件）：可将一张「鲸鱼之怒」（9050）加入卡组。\n'
        '\treturn _is_event_node() and _pending_kind() == "bluefish"\n',
        'func _is_bluefish() -> bool:\n'
        '\t## R573 已下线：只用来认出旧存档 / 脏数据里的 bluefish，\n'
        '\t## 让它走「已移除」兜底页，而不是落进 _is_treasure() 误开宝箱发奖励。\n'
        '\treturn _is_event_node() and _pending_kind() == "bluefish"\n',
    ),
    (
        '\t\t"whisper", "divination", "moon", "arcane", "bluefish", "hero":\n',
        '\t\t"whisper", "divination", "moon", "arcane", "hero":\n',
    ),
    (
        '\t\tif args[i] == "--bluefish":  # 演示：伪装 run 蓝色大肥鱼事件（截图验证）\n'
        '\t\t\tRunState.run_active = true\n'
        '\t\t\tRunState.pending_node = {"type": "event"}\n'
        '\t\t\tRunState.pending_event = "bluefish"\n',
        '\t\t# R573：--bluefish 演示参数随事件一起删除。\n',
    ),
    (
        '\telif _is_bluefish():\n'
        '\t\tevent_name.text = "蓝 色 大 肥 鱼"\n'
        '\t\tdesc.text = BLUEFISH_TAKEN_DESC if _bluefish_taken else BLUEFISH_DESC\n'
        '\t\tif _bluefish_taken:\n'
        '\t\t\t_collapse_to_leave()\n'
        '\t\t\tresult_label.text = "「鲸鱼之怒」已加入卡组——用掉之后本场战斗里不再出现。"\n'
        '\t\t\tresult_label.add_theme_color_override("font_color", UiTheme.RARITY_RARE)\n'
        '\t\telse:\n'
        '\t\t\trest_btn.text = "收下「鲸鱼之怒」（加入卡组）"\n'
        '\t\t\trest_btn.disabled = false\n'
        '\t\t\t$Center/LeaveBtn.text = "不捡（放弃）"\n'
        '\t\t\tresult_label.text = ""\n',
        '\telif _is_bluefish():\n'
        '\t\t# R573 已下线：只留「离开」，不给卡、不发奖励（旧存档 / 脏数据兜底）。\n'
        '\t\tevent_name.text = "蓝 色 大 肥 鱼"\n'
        '\t\tdesc.text = RETIRED_EVENT_DESC\n'
        '\t\t_collapse_to_leave()\n'
        '\t\tresult_label.text = "这个事件已经从游戏里移除了。"\n',
    ),
    (
        '\tif _is_bluefish():\n'
        '\t\tif _bluefish_taken:\n'
        '\t\t\t_on_leave()\n'
        '\t\t\treturn\n'
        '\t\tRunState.add_card(WHALE_CARD_ID)\n'
        '\t\t_bluefish_taken = true\n'
        '\t\t_claim_reward(rest_btn)   # R147\n'
        '\t\tvar wcard := CardRepo.load_json().get_card(WHALE_CARD_ID)\n'
        '\t\tvar wname := wcard.card_name if wcard != null else "鲸鱼之怒"\n'
        '\t\t_collapse_to_leave()\n'
        '\t\tdesc.text = BLUEFISH_TAKEN_DESC\n'
        '\t\tresult_label.text = "「%s」已加入卡组：%s" % [wname,\n'
        '\t\t\t\tCardText.naturalize(wcard.effect_text) if wcard != null else ""]\n'
        '\t\tresult_label.add_theme_color_override("font_color", UiTheme.RARITY_RARE)\n'
        '\t\t_redraw()\n'
        '\t\treturn\n',
        '\tif _is_bluefish():\n'
        '\t\t# R573 兜底：任何残留点击都只关页，绝不发「鲸鱼之怒」。\n'
        '\t\t_on_leave()\n'
        '\t\treturn\n',
    ),
])


# ---------------------------------------------------------------- test_engine.gd (CRLF)
patch("scripts/test_engine.gd", [
    (
        '\tcheck(l2_ev_kinds.size() == 15 and l2_ev_kinds.has("smith") \\\n',
        '\tcheck(l2_ev_kinds.size() == 14 and l2_ev_kinds.has("smith") \\\n',
    ),
    (
        '\t\t\t"第二层事件池：鸭梨山大 / 绝赞五换一 / 蓝色大肥鱼 / 苹果与医生 + 凝视 + 遗忘之泉 + 鸭鸭工匠 + 卡片商人 + 占卜室 + R351 赏月 + R454 熔炉 + R458 契约的核心 + R467 洞穴 + R473 武术大师 + R555 飞行器 = 15 种子类型")\n',
        '\t\t\t"第二层事件池：鸭梨山大 / 绝赞五换一 / 苹果与医生 + 凝视 + 遗忘之泉 + 鸭鸭工匠 + 卡片商人 + 占卜室 + R351 赏月 + R454 熔炉 + R458 契约的核心 + R467 洞穴 + R473 武术大师 + R555 飞行器 = 14 种子类型（R573 删除蓝色大肥鱼）")\n',
    ),
    (
        '\tcheck(pear_ev_kinds.has("bluefish") and not ev_kinds_layer.has("bluefish"),\n'
        '\t\t\t"蓝色大肥鱼只在第二层事件池（第一层不含 bluefish，不串层）")\n'
        '\tcheck(GameLayers.event_name("bluefish") == "蓝色大肥鱼", "蓝色大肥鱼事件的显示名")\n'
        '\tvar bf_ev_w := GameLayers.event_weights(GameLayers.LAYER_TWO)\n'
        '\tcheck(int(bf_ev_w.get("bluefish", 0)) > 0,\n'
        '\t\t\t"蓝色大肥鱼在第二层事件权重 > 0（可被抽到）")\n',
        '\t# ==== R573：蓝色大肥鱼（bluefish）事件已删除 ====\n'
        '\tcheck(not pear_ev_kinds.has("bluefish") and not ev_kinds_layer.has("bluefish"),\n'
        '\t\t\t"R573：蓝色大肥鱼已从两层事件池删除（都不含 bluefish）")\n'
        '\tcheck(not GameLayers.EVENT_NAMES.has("bluefish"),\n'
        '\t\t\t"R573：EVENT_NAMES 不再登记蓝色大肥鱼")\n'
        '\tcheck(int(GameLayers.event_weights(GameLayers.LAYER_TWO).get("bluefish", 0)) == 0,\n'
        '\t\t\t"R573：蓝色大肥鱼在第二层权重为 0（抽不到）")\n'
        '\tvar bf_src := FileAccess.get_file_as_string("res://scripts/event_scene.gd")\n'
        '\tcheck_src("BLUEFISH_DESC" not in bf_src and "_bluefish_taken" not in bf_src\n'
        '\t\t\tand "--bluefish" not in bf_src,\n'
        '\t\t\t"R573 源码锁：事件场景不再有蓝色大肥鱼的文案 / 状态 / 演示入口")\n',
    ),
    (
        '\tcheck(q_l2_ev_seen.has("pear") or q_l2_ev_seen.has("hero") or q_l2_ev_seen.has("bluefish"),\n'
        '\t\t\t"第二层地图多次生成：出鸭梨山大/绝赞五换一/蓝色大肥鱼专属事件")\n',
        '\tcheck(q_l2_ev_seen.has("pear") or q_l2_ev_seen.has("hero"),\n'
        '\t\t\t"第二层地图多次生成：出鸭梨山大/绝赞五换一专属事件（R573 已删蓝色大肥鱼）")\n'
        '\tcheck(not q_l2_ev_seen.has("bluefish"),\n'
        '\t\t\t"R573：第二层地图 40 次生成里不再出现蓝色大肥鱼")\n',
    ),
], crlf=True)


# ---------------------------------------------------------------- _playthrough.gd
patch("_playthrough.gd", [
    (
        '\t\t"bluefish":\n'
        '\t\t\tRunState.add_card(9050)\n'
        '\t\t\tRunState.complete_current()\n',
        '',
    ),
])


# ---------------------------------------------------------------- 图片命名说明.txt
patch("assets/ui/图片命名说明.txt", [
    (
        '· kind 的唯一出处是 `event_scene._kind()`（25 个分支），这张表按它列全。\n',
        '· kind 的唯一出处是 `event_scene._kind()`（R573 后 24 个在册事件 + 1 个已下线兜底）。\n',
    ),
    (
        '· 「暂缓」= R512 用户口径明确这一轮不做，别自作主张补。\n',
        '· R573：蓝色大肥鱼事件已删除；绝赞五换一 / 鸭梨山大 / 飞行器三张整屏背景已补齐。\n'
        '  R512 那一档「暂缓」至此全部收口。\n',
    ),
    (
        '  event_pear.png          鸭梨山大          （R512 暂缓）\n'
        '  event_hero.png          绝赞五换一        （R512 暂缓）\n'
        '  event_bluefish.png      蓝色大肥鱼        （R512 暂缓）\n',
        '  event_pear.png          鸭梨山大          （R573 改走整屏背景 bg_pear，不做插图）\n'
        '  event_hero.png          绝赞五换一        （R573 改走整屏背景 bg_hero，不做插图）\n'
        '  event_flyer.png         飞行器            （R555 新增；R573 改走整屏背景 bg_flyer，不做插图）\n',
    ),
    (
        '  bg_pear.png             鸭梨山大          （R512 暂缓）\n'
        '  bg_hero.png             绝赞五换一        （R512 暂缓）\n'
        '  bg_bluefish.png         蓝色大肥鱼        （R512 暂缓）\n',
        '  bg_pear.png             鸭梨山大          ★R573 已提供（巨大的梨 + 小人／小车参照物）\n'
        '  bg_hero.png             绝赞五换一        ★R573 已提供（五张换一张；本游戏羊皮纸墨蓝金框卡面）\n'
        '  bg_flyer.png            飞行器            ★R573 已提供（喷气式背包，无桨叶无机翼）\n',
    ),
])

print("=== R573 补丁完成 ===")
