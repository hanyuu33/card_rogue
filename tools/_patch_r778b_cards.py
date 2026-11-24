# -*- coding: utf-8 -*-
"""R778b：cards.json 数值与文本改动（exact-replace，逐块断言）。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
P = ROOT + "cards.json"

s = io.open(P, "r", encoding="utf-8", newline="").read()
assert s.count("\n") == s.count("\r\n"), "存在裸 LF，先查清楚"
s = s.replace("\r\n", "\n")


def block(cid):
    key = '\n    {\n      "id": %d,\n' % cid
    i = s.index(key)
    j = s.index("\n    }", i + len(key))
    return key, s[i:j]


def rep_in(cid, old, new, tag=""):
    global s
    key, body = block(cid)
    n = body.count(old)
    if n != 1:
        print("FAIL[%s %d] count=%d  %r" % (tag, cid, n, old[:50]))
        sys.exit(1)
    s = s.replace(body, body.replace(old, new, 1), 1)
    print("OK %d %s" % (cid, tag or old[:24]))


# ---- 1. 鸭子弓手 18 → 15 ----
rep_in(9017, '"health": 18,', '"health": 15,', "鸭子弓手血量 15")

# ---- 2. 鸭子队长 55 → 50 ----
rep_in(9012, '"health": 55,', '"health": 50,', "鸭子队长血量 50")

# ---- 3. 灰烬龙：删效果 + 删「战吼」trait ----
rep_in(1013, '"effect_text": "登场后首个回合开始时：对所有敌方单位造成 4 点伤害。",',
       '"effect_text": "",', "灰烬龙效果清空")
rep_in(1013, '"traits": [\n        "龙",\n        "战吼"\n      ],',
       '"traits": [\n        "龙"\n      ],', "灰烬龙删战吼 trait")

# ---- 4. 构状体 → 构装体（9242 文本 + 9243~9245 名字与 traits）----
key, body = block(9242)
cnt = body.count("构状体")
assert cnt == 5, cnt
s = s.replace(body, body.replace("构状体", "构装体"), 1)
print("OK 9242 构装体 x%d" % cnt)

for cid in (9243, 9244, 9245):
    key, body = block(cid)
    assert body.count("构状体") == 2, (cid, body.count("构状体"))
    s = s.replace(body, body.replace("构状体", "构装体"), 1)
    print("OK %d 形态卡改名/改 trait" % cid)

# ---- 5. 计量工坊三只 60 → 80 ----
for cid in (9260, 9261, 9262):
    rep_in(cid, '"health": 60,', '"health": 80,', "血量 80")

# ---- 6. 俄倪厄 9132：血 80 → 100、移 1 → 3 ----
rep_in(9132, '"health": 80,', '"health": 100,', "俄倪厄血量 100")
key, body = block(9132)
assert body.count('"move_speed": 1,') == 1
rep_in(9132, '"move_speed": 1,', '"move_speed": 3,', "俄倪厄移速 3")

# ---- 7. 量产型赫卡同克瑞斯 9133：血 35 → 60 + 效果换新 + trait ----
rep_in(9133, '"health": 35,', '"health": 60,', "血 60")
rep_in(9133, '"effect_text": "铸造：我方回合结束时倒计时 -1；减到 0 时破坏自身，并在原地立起一座「钢铁要塞」。",',
       '"effect_text": "每回合开始时，给随机一个其他友方单位 10 护甲。",', "效果换成铸甲")
rep_in(9133, '"traits": [\n        "机械",\n        "铸造"\n      ],',
       '"traits": [\n        "机械",\n        "铸甲"\n      ],', "trait 铸造→铸甲")

# ---- 8. 敌人效果卡删除「效果区多张本卡不可叠加。」----
ENEMY_EFFECT_IDS = [9013, 9015, 9024, 9049, 9115, 9117, 9125, 9139,
                    9147, 9178, 9209, 9210, 9212, 9240]
SENT = "效果区多张本卡不可叠加。"
for cid in ENEMY_EFFECT_IDS:
    key, body = block(cid)
    if SENT not in body:
        print("FAIL %d 不含目标句" % cid)
        sys.exit(1)
    s = s.replace(body, body.replace(SENT, ""), 1)
print("OK 删除不可叠加描述 x%d" % len(ENEMY_EFFECT_IDS))

io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n"))
print("CARDS DONE")
