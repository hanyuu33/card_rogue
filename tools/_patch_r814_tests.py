# -*- coding: utf-8 -*-
"""R814：给 test_engine.gd 追加 _test_r814 并登记调用（CRLF 文件，走 python）。"""
import io

P = "E:/work/card_rogue/scripts/test_engine.gd"
s = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in s
assert "_test_r814" not in s

# ── 登记调用（放在 _test_r811() 之后）──
reg_anchor = "\t_test_r811()\r\n"
assert s.count(reg_anchor) == 1, s.count(reg_anchor)
s = s.replace(reg_anchor, reg_anchor + "\t_test_r814()\r\n")

FUNC = '''\r
\r
func _test_r814() -> void:\r
\t## R814 试玩版（Steam 试玩切片）：只开森林精魄 + 暗影刺客、难度≤1、每职业 60 张卡、\r
\t## 组合素材与组合触发卡一张不少、事件与道具全量可用、剧情不可解锁、二层 Boss 即收尾。\r
\t## 口径来源：用户 2026-11-19 的试玩版需求。改这几个数字之前先确认需求有没有变。\r
\tvar r814_repo := CardRepo.load_json()\r
\tvar r814_relics := RelicRepo.load_json()\r
\r
\t# ── ① 闸门：默认不是试玩版；试玩版优先级高于发布版 ──\r
\tGameBuild.set_test_demo(-1)\r
\tcheck(not GameBuild.is_demo(), "R814 闸门：默认（编辑器 / 普通导出）不是试玩版")\r
\tGameBuild.set_test_release(1)\r
\tGameBuild.set_test_demo(1)\r
\tcheck(GameBuild.is_demo(), "R814 闸门：set_test_demo(1) 后 is_demo 为真")\r
\tcheck(not GameBuild.is_release(),\r
\t\t\t"R814 闸门：试玩版压过发布版 —— 即使强开 release，is_release 也恒 false")\r
\r
\t# ── ② 职业 / 难度：只开两个职业，上限 1 ──\r
\tcheck(UnlockSystem.is_class_unlocked(PlayerClass.DRUID), "R814 职业：森林精魄可选")\r
\tcheck(UnlockSystem.is_class_unlocked(PlayerClass.ROGUE), "R814 职业：暗影刺客可选")\r
\tcheck(not UnlockSystem.is_class_unlocked(PlayerClass.MECH),\r
\t\t\t"R814 职业：机械之心在试玩版不可选（选人界面显示「未解锁」）")\r
\tcheck(UnlockSystem.difficulty_cap(PlayerClass.DRUID) == 1,\r
\t\t\t"R814 难度：森林精魄上限 = 1（0 轻松 + 1 微恙）")\r
\tcheck(UnlockSystem.difficulty_cap(PlayerClass.ROGUE) == 1, "R814 难度：暗影刺客上限 = 1")\r
\tcheck(UnlockSystem.global_max_difficulty() == 1,\r
\t\t\t"R814 难度：随机摇人的「尽可能高」也封在 1")\r
\r
\t# ── ③ 卡池：每职业正好 60 张 ──\r
\tfor r814_cid: String in [PlayerClass.DRUID, PlayerClass.ROGUE]:\r
\t\tvar r814_pool := r814_repo.reward_pool_for(r814_cid)\r
\t\tcheck(r814_pool.size() == 60,\r
\t\t\t\t"R814 卡池：%s 奖励池 = 60 张（实际 %d）" % [r814_cid, r814_pool.size()])\r
\t\tvar r814_ids := {}\r
\t\tfor r814_c: CardData in r814_pool:\r
\t\t\tr814_ids[r814_c.id] = true\r
\t\t# 组合链必须全在池里：素材（带 upper_effect 的卡）+ 触发卡（传授 / 影缚 / 宝石兽）。\r
\t\t# 判据刻意用「该进池的卡」集合去比对，而不是写死 id 名单 —— 新增素材卡会自动被覆盖。\r
\t\tvar r814_missing: Array[String] = []\r
\t\tfor r814_c: CardData in r814_repo.all_cards():\r
\t\t\tif r814_c.card_class != r814_cid or r814_c.rarity > 2:\r
\t\t\t\tcontinue\r
\t\t\tif r814_c.locked or r814_c.event_only:\r
\t\t\t\tcontinue\r
\t\t\tvar r814_is_mat: bool = r814_c.upper_effect.size() > 0 or r814_c.combo_trigger != ""\r
\t\t\tif r814_is_mat and not r814_ids.has(r814_c.id):\r
\t\t\t\tr814_missing.append("%d %s" % [r814_c.id, r814_c.name])\r
\t\tcheck(r814_missing.is_empty(),\r
\t\t\t\t"R814 组合：%s 的组合素材 / 触发卡全在池内（缺 %s）" % [r814_cid, str(r814_missing)])\r
\r
\t# 传授 8084（森林精魄）/ 影缚 8085（暗影刺客）/ 宝石兽 9246（死亡触发组合）三张是组合入口。\r
\tfor r814_id: int in [8084, 8085, 9246]:\r
\t\tvar r814_cls := r814_repo.get_card(r814_id).card_class\r
\t\tvar r814_hit := false\r
\t\tfor r814_c: CardData in r814_repo.reward_pool_for(r814_cls):\r
\t\t\tif r814_c.id == r814_id:\r
\t\t\t\tr814_hit = true\r
\t\tcheck(r814_hit, "R814 组合：%d 在 %s 的试玩版奖励池里" % [r814_id, r814_cls])\r
\r
\t# ── ④ 事件 / 道具：试玩版一件都不裁 ──\r
\tvar r814_ev := GameLayers.event_weights(GameLayers.LAYER_DEFAULT).size()\r
\tvar r814_relic_n := r814_relics.reward_ids().size()\r
\tcheck(r814_ev >= 10 and r814_relic_n >= 20,\r
\t\t\t"R814 内容：试玩版事件 %d 种 / 奖励道具 %d 件照常可用" % [r814_ev, r814_relic_n])\r
\r
\t# ── ⑤ 剧情：恒不解锁（剧情锁卡连带进不了池）──\r
\tcheck(not ProfileData.is_story_unlocked("episode1"),\r
\t\t\t"R814 剧情：试玩版里 episode1 也是未解锁状态")\r
\tvar r814_goose := r814_repo.get_card(9187)\r
\tcheck(r814_goose != null and r814_goose.locked,\r
\t\t\t"R814 剧情：鹅 9187 仍是剧情锁卡（试玩版不放进奖励池）")\r
\tvar r814_goose_in := false\r
\tfor r814_c: CardData in r814_repo.reward_pool_for(PlayerClass.DRUID):\r
\t\tif r814_c.id == 9187:\r
\t\t\tr814_goose_in = true\r
\tcheck(not r814_goose_in, "R814 剧情：剧情锁卡不在试玩版奖励池里")\r
\r
\t# ── ⑥ 图鉴 / 可获得池同步：被裁的卡在试玩版里「不存在」──\r
\tcheck(not CardRepo.demo_allows(r814_repo.get_card(9077)),\r
\t\t\t"R814 图鉴：被裁掉的陨石术 9077 在试玩版里不存在")\r
\tcheck(CardRepo.demo_allows(r814_repo.get_card(8001)),\r
\t\t\t"R814 图鉴：初始卡（木栅栏 8001）不被裁")\r
\tcheck(CardRepo.demo_allows(r814_repo.get_card(8004)),\r
\t\t\t"R814 图鉴：初始专属卡（熊 8004）不被裁")\r
\r
\t# ── ⑦ 结算：二层 Boss 打完后不进第三层 → 走「胜利？」──\r
\tvar r814_bs := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")\r
\tcheck_src(r814_bs.contains(\r
\t\t\t"if GameBuild.is_demo() and _run_next_layer == GameLayers.LAYER_THREE:"),\r
\t\t\t"R814 结算：试玩版把「二层 Boss 的下一层」截成 0")\r
\tvar r814_sum := FileAccess.get_file_as_string("res://scripts/run_summary_scene.gd")\r
\tcheck_src(r814_sum.contains("!= GameLayers.LAYER_THREE"),\r
\t\t\t"R814 结算：标题判据「没停在第三层 → 胜利？」未变，试玩版直接复用")\r
\r
\t# ── ⑧ 复位（后面的用例不该继承试玩版状态）──\r
\tGameBuild.set_test_demo(-1)\r
\tGameBuild.set_test_release(-1)\r
\tcheck(not GameBuild.is_demo() and not GameBuild.is_release(),\r
\t\t\t"R814 复位：用例结束后回到测试版口径")\r
'''

if not s.endswith("\r\n"):
    s += "\r\n"
s += FUNC.replace("\n", "\r\n").replace("\r\r\n", "\r\n")

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("appended; CRLF =", s.count("\r\n"), "LF-only =", s.count("\n") - s.count("\r\n"))
