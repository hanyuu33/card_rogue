# -*- coding: utf-8 -*-
"""R805：三个 i18n 校验器的写死计数同步。"""
import io

JOBS = [
    ("E:/work/card_rogue/i18n/validate_event_ui.py",
     'EXPECTED_COUNTS = {"options": 97, "results": 71, "pickers": 5, "rest_dynamic": 3}',
     'EXPECTED_COUNTS = {"options": 99, "results": 73, "pickers": 5, "rest_dynamic": 3}'),
    ("E:/work/card_rogue/i18n/validate_narrative.py",
     'check(len(ZH["events"]) == 29, "事件页为 29 组（26 常规 + 篝火 + 旧存档兜底；R793 +林中的剑；R794 +巧克力工厂）")',
     'check(len(ZH["events"]) == 30, "事件页为 30 组（26 常规 + 篝火 + 旧存档兜底；R793 +林中的剑；R794 +巧克力工厂；R805 +诡异洋房）")'),
    ("E:/work/card_rogue/i18n/validate_narrative.py",
     'check(sum(len(x["texts"]) for x in ZH["events"].values()) == 72, "事件正文共 72 段（含 3 条休息处动态追加；R793 +2；R794 +2）")',
     'check(sum(len(x["texts"]) for x in ZH["events"].values()) == 74, "事件正文共 74 段（含 3 条休息处动态追加；R793 +2；R794 +2；R805 +2）")'),
    ("E:/work/card_rogue/i18n/validate_spanish.py",
     'check(len(CARDS_ES["cards"]) == 336, "cards 共 336 张")',
     'check(len(CARDS_ES["cards"]) == 337, "cards 共 337 张（R805 +诅咒娃娃 9276）")'),
    ("E:/work/card_rogue/i18n/validate_spanish.py",
     '# 卡牌：336 个稳定 ID（R800',
     '# 卡牌：337 个稳定 ID（R805 +诅咒娃娃 9276；R800'),
]

for path, old, new in JOBS:
    d = io.open(path, encoding="utf-8").read()
    assert d.count(old) == 1, "%s 锚点命中 %d 次：%r" % (path, d.count(old), old[:60])
    io.open(path, "w", encoding="utf-8", newline="\n").write(d.replace(old, new))
    print("ok", path.split("/")[-1], "->", new[:46])
