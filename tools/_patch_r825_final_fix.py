# -*- coding: utf-8 -*-
"""R825：奖励实际成交即时落盘；商店恢复兼容已持有匕首。保留原行尾。"""
from pathlib import Path

ROOT = Path(r"E:/work/card_rogue")


def replace(path, old, new):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    if crlf:
        text = text.replace("\r\n", "\n")
    count = text.count(old)
    assert count == 1, "%s anchor count=%d\n%s" % (path, count, old[:160])
    text = text.replace(old, new)
    out = text.replace("\n", "\r\n") if crlf else text
    p.write_bytes(out.encode("utf-8"))
    print("PATCH", path)


# 只有数据层确认成交才落盘；已领 / 非法选择保持 pending，不能被界面误了结。
replace("scripts/reward_panel.gd",
"""\tvar was_milk := _is_milk_entry(i)
\tRunState.claim_pending_reward(i)
\t_view = VIEW_LIST
""",
"""\tvar was_milk := _is_milk_entry(i)
\tif not RunState.claim_pending_reward(i):
\t\treturn
\t_save_reward_checkpoint()   # R825：成交当刻写盘；后续牛奶 / 鸭血分支 return 也不会漏
\t_view = VIEW_LIST
""")
replace("scripts/reward_panel.gd",
"""\tRunState.skip_pending_reward(i)
\t_view = VIEW_LIST
""",
"""\tif not RunState.skip_pending_reward(i):
\t\treturn
\t_save_reward_checkpoint()
\t_view = VIEW_LIST
""")
replace("scripts/reward_panel.gd",
"""\tRunState.claim_key_choice(_sel, take_key)
\t_view = VIEW_LIST
""",
"""\tif not RunState.claim_key_choice(_sel, take_key):
\t\treturn
\t_save_reward_checkpoint()
\t_view = VIEW_LIST
""")
replace("scripts/reward_panel.gd",
"""\tRunState.pick_pending_card(i, card_id)
\t_view = VIEW_LIST
""",
"""\tif not RunState.pick_pending_card(i, card_id):
\t\treturn
\t_save_reward_checkpoint()
\t_view = VIEW_LIST
""")
replace("scripts/reward_panel.gd",
"""\tvar res := RunState.duplicate_deck_cards(_repo_cards, _dup_sel)
\tvar nms: Array[String] = []
""",
"""\tvar res := RunState.duplicate_deck_cards(_repo_cards, _dup_sel)
\t_save_reward_checkpoint()   # 复制结果与 pending_relic 的清理一起落盘
\tvar nms: Array[String] = []
""")
replace("scripts/reward_panel.gd",
"""\tif RunState.claim_pending_reward(_sel):
\t\t_back_to_list()
""",
"""\tif RunState.claim_pending_reward(_sel):
\t\t_save_reward_checkpoint()
\t\t_back_to_list()
""")
replace("scripts/reward_panel.gd",
"""\t_core_grid = []
\t_back_to_list()
\treturn {"ok": true, "msg": "「%s」被献祭：第一段 %d 点伤害 → 「%s」得到「伤害 +%d」" % [
""",
"""\t_core_grid = []
\t_save_reward_checkpoint()
\t_back_to_list()
\treturn {"ok": true, "msg": "「%s」被献祭：第一段 %d 点伤害 → 「%s」得到「伤害 +%d」" % [
""")
replace("scripts/reward_panel.gd",
"""\t\t\tif RunState.claim_deck_delete_reward(_sel, di):
\t\t\t\t_deck_hover = -1
""",
"""\t\t\tif RunState.claim_deck_delete_reward(_sel, di):
\t\t\t\t_save_reward_checkpoint()
\t\t\t\t_deck_hover = -1
""")
replace("scripts/reward_panel.gd",
"""\t\t\t\tif RunState.reroll_pending_cards(_sel):
\t\t\t\t\t_pick_sel = -1
""",
"""\t\t\t\tif RunState.reroll_pending_cards(_sel):
\t\t\t\t\t_save_reward_checkpoint()   # 火柴次数与新候选必须同档恢复
\t\t\t\t\t_pick_sel = -1
""")
replace("scripts/reward_panel.gd",
"""\t\t\tif any_relic and _btn_claim_all_rect().has_point(pos):
\t\t\t\tRunState.claim_all_relic_rewards()
\t\t\t\t_root.queue_redraw()
""",
"""\t\t\tif any_relic and _btn_claim_all_rect().has_point(pos):
\t\t\t\tif RunState.claim_all_relic_rewards() > 0:
\t\t\t\t\t_save_reward_checkpoint()
\t\t\t\t_root.queue_redraw()
""")

# 新货架仍按「未持有才出售」；读档反查则必须能拿到曾经出售的 dagger 定义。
replace("scripts/shop_scene.gd",
"""func _row3_template() -> Array:
""",
"""func _row3_template(for_restore := false) -> Array:
""")
replace("scripts/shop_scene.gd",
"""\tif RunState.third_layer_locked() and not RunState.has_key(RunState.DAGGER_RELIC_ID):
\t\tout.append({"key": "dagger", "name": "屠戮匕首",
""",
"""\t# R825：for_restore 只供读档反查。已持有不代表存档里的已售罄货位可以消失；
\t# 若这里仍按「持有就删定义」，_restore_shop 会整店回退重摇，把其他成交位也抹掉。
\tif RunState.third_layer_locked() and (for_restore or not RunState.has_key(RunState.DAGGER_RELIC_ID)):
\t\tout.append({"key": "dagger", "name": "屠戮匕首",
""")
replace("scripts/shop_scene.gd",
"""\tfor d: Dictionary in _row3_template():
""",
"""\tfor d: Dictionary in _row3_template(true):
""")

# 源码守卫锁住成交直存和恢复专用模板，防止后续又回到只等下一帧。
replace("scripts/test_engine.gd",
"""\tcheck_src(r825_reward_src.contains("if _cached_n != RunState.pending_reward_count():\\n\\t\\t_refresh_btn()\\n\\t\\t_save_reward_checkpoint()")
\t\t\tand r825_reward_src.contains("func close() -> void:")
\t\t\tand r825_reward_src.contains("_save_reward_checkpoint()\\n\\tif not _closing_to_route"),
\t\t\t"R825 奖励：待领数变化与关窗两条路都落盘")
""",
"""\tcheck_src(r825_reward_src.contains("if not RunState.claim_pending_reward(i):\\n\\t\\treturn\\n\\t_save_reward_checkpoint()")
\t\t\tand r825_reward_src.contains("if not RunState.pick_pending_card(i, card_id):\\n\\t\\treturn\\n\\t_save_reward_checkpoint()")
\t\t\tand r825_reward_src.contains("if RunState.claim_all_relic_rewards() > 0:\\n\\t\\t\\t\\t_save_reward_checkpoint()")
\t\t\tand r825_reward_src.contains("_save_reward_checkpoint()\\n\\tif not _closing_to_route"),
\t\t\t"R825 奖励：领取 / 选卡 / 一键领取成交当刻落盘，关窗再兜底")
\tcheck_src(r825_shop_src.contains("func _row3_template(for_restore := false)")
\t\t\tand r825_shop_src.contains("for_restore or not RunState.has_key")
\t\t\tand r825_shop_src.contains("for d: Dictionary in _row3_template(true):"),
\t\t\t"R825 商店：已持有匕首也能恢复原货位，新货架仍不重复出售")
""")

print("R825 FINAL FIX OK")
