# -*- coding: utf-8 -*-
"""R757 遥测：shop_scene.gd 接入（CRLF 文件，原样保留换行）。

1) `_roll()` 末尾：货架快照（分母）
2) `_buy_card` / `_buy_trap` 成交处：买了什么、花了多少
3) 新增 `_tele_shelf()`：把三行货位拼成一层数组（卡牌 / 工具 / 服务各带价格）
"""
import io

P = "scripts/shop_scene.gd"


def load(p):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    return (s.replace("\r\n", "\n") if crlf else s), crlf


def save(p, s, crlf):
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag, times=1):
    n = s.count(old)
    assert n == times, "%s: count=%d（期望 %d）" % (tag, n, times)
    print("  ok  %s" % tag)
    return s.replace(old, new)


s, crlf = load(P)

OLD1 = "\t_row3 = _row3_template()\n\t_reindex_rows()\n\t_sync_shop_state()"
NEW1 = (
    "\t_row3 = _row3_template()\n"
    "\t_reindex_rows()\n"
    "\t_sync_shop_state()\n"
    "\t# R757 遥测：**货架快照**（发布版才写）。成交记录只说明「买了什么」，\n"
    "\t# 摆出来的是什么才是分母 —— 「摆在店里没人买」和「根本没上过货架」\n"
    "\t# 是两件事，后者不该拉低这张卡的选择率。\n"
    "\t_tele_shelf()"
)
s = rep(s, OLD1, NEW1, "shop: 货架快照")

OLD2 = "\te[\"sold\"] = true\n\tRunState.add_card(card.id)"
NEW2 = (
    "\te[\"sold\"] = true\n"
    "\tRunState.add_card(card.id)\n"
    "\tTelemetry.note_shop(\"card\", card.id, price, true)"
)
s = rep(s, OLD2, NEW2, "shop: 买卡")

OLD3 = "\te[\"sold\"] = true\n\t_sync_shop_state()      # R390：售罄位要进货架存档，重进店不重摇\n\tRunState.gain_trap(int(t.id))"
NEW3 = (
    "\te[\"sold\"] = true\n"
    "\t_sync_shop_state()      # R390：售罄位要进货架存档，重进店不重摇\n"
    "\tRunState.gain_trap(int(t.id))\n"
    "\tTelemetry.note_shop(\"trap\", int(t.id), int(t.price), true)"
)
s = rep(s, OLD3, NEW3, "shop: 买工具")

# 新增 _tele_shelf()：插在 _sync_shop_state 定义之前
OLD4 = "func _sync_shop_state() -> void:"
NEW4 = (
    "func _tele_shelf() -> void:\n"
    "\t## R757 遥测：把三行货位拼成一层数组交给 `Telemetry`。\n"
    "\t## ⚠️ 只在**进货**时调一次（`_roll()` 末尾）—— 放进 `_sync_shop_state()` 会变成\n"
    "\t##    「每买一件就重记一份货架」，分母翻倍，选择率全错。\n"
    "\tif not Telemetry.is_enabled():\n"
    "\t\treturn\n"
    "\tvar items: Array = []\n"
    "\tfor e: Dictionary in _row1:\n"
    "\t\tvar c: CardData = e[\"card\"]\n"
    "\t\titems.append({\"k\": \"card\", \"id\": c.id, \"price\": _row1_price(e)})\n"
    "\tfor e2: Dictionary in _row2:\n"
    "\t\tif str(e2.get(\"kind\", \"\")) == \"trap\":\n"
    "\t\t\titems.append({\"k\": \"trap\", \"id\": int(e2[\"id\"]),\n"
    "\t\t\t\t\t\"price\": int((e2[\"trap\"] as TrapData).price)})\n"
    "\t\telse:\n"
    "\t\t\titems.append({\"k\": \"enchant\", \"id\": 0, \"price\": 0,\n"
    "\t\t\t\t\t\"name\": str(e2.get(\"id\", \"\"))})\n"
    "\tfor e3: Dictionary in _row3:\n"
    "\t\titems.append({\"k\": \"service\", \"id\": 0, \"price\": int(e3[\"price\"]),\n"
    "\t\t\t\t\"name\": str(e3.get(\"key\", \"\"))})\n"
    "\tTelemetry.note_shop_shelf(items, {\"layer\": RunState.current_layer,\n"
    "\t\t\t\"gold\": RunState.gold, \"hp\": RunState.hp, \"deck\": RunState.deck_ids.size()})\n"
    "\n"
    "\n"
    "func _sync_shop_state() -> void:"
)
s = rep(s, OLD4, NEW4, "shop: _tele_shelf")

save(P, s, crlf)
print("done. crlf=%s" % crlf)
