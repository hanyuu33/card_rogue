# -*- coding: utf-8 -*-
"""R805：把洋房结果行改成**固定中文串**（动态 %s 会让 GameI18n.source 的模板匹配落空）。保持 LF。"""
import io

P = "E:/work/card_rogue/scripts/event_scene.gd"
d = open(P, "rb").read().decode("utf-8")
assert d.count("\r\n") == 0


def rep(old, new, cnt=1):
    global d
    assert d.count(old) == cnt, "锚点命中 %d 次：%r" % (d.count(old), old[:80])
    d = d.replace(old, new)


rep(
    '\tvar relic_id := RunState.roll_legendary_relic()\n'
    '\tvar relic_name := ""\n'
    '\tif relic_id > 0:\n'
    '\t\tRunState.queue_relic_reward(relic_id)\n'
    '\t\tvar rd := RelicRepo.load_json().get_relic(relic_id)\n'
    '\t\trelic_name = rd.relic_name if rd != null else str(relic_id)\n',
    '\tvar relic_id := RunState.roll_legendary_relic()\n'
    '\tif relic_id > 0:\n'
    '\t\tRunState.queue_relic_reward(relic_id)\n'
)

rep(
    '\tif relic_id > 0:\n'
    '\t\t_house_result = ("「%s」和一组史诗卡牌已放进待领奖励——在上面弹出的奖励页里挑；"\n'
    '\t\t\t\t% relic_name) + "「诅咒娃娃」已加入卡组，它不会走。"\n'
    '\telse:\n'
    '\t\t_house_result = ("传奇道具已经全部拿过了，屋里只剩那组史诗卡牌——"\n'
    '\t\t\t\t+ "「诅咒娃娃」照样钻进你的卡组，它不会走。")\n',
    '\t# ⚠️ 结果行必须是**固定串**：`GameI18n.source()` 靠「全串精确 / 模板」匹配中文原文，\n'
    '\t#    这里若插进道具名（%s），英文 / 日文 / 西语的模板就对不上，那一行会一直是中文。\n'
    '\t#    道具名本来就会在奖励页里出现，不必在结果行再复述一遍。\n'
    '\tif relic_id > 0:\n'
    '\t\t_house_result = "「诅咒娃娃」已加入卡组，它不会走。一件传奇道具和一组史诗卡牌在上面等你挑。"\n'
    '\telse:\n'
    '\t\t_house_result = "「诅咒娃娃」已加入卡组，它不会走。传奇道具已全部拿过，上面只剩一组史诗卡牌。"\n'
)

io.open(P, "wb").write(d.encode("utf-8"))
print("ok lines=%d" % d.count("\n"))
