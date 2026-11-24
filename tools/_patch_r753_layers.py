# -*- coding: utf-8 -*-
"""R753：game_layers.gd 登记事件「奇异雕像」。"""
p = 'scripts/game_layers.gd'
txt = open(p, 'rb').read().decode('utf-8')
print('crlf before', txt.count('\r\n'))
crlf = txt.count('\r\n') > 0


def rep(old, new):
    global txt
    if crlf:
        old = old.replace('\n', '\r\n')
        new = new.replace('\n', '\r\n')
    c = txt.count(old)
    assert c == 1, (c, old[:70])
    txt = txt.replace(old, new, 1)


# 第二层专属：工具相关的事件都在这层（熔炉 / 契约之后再加一个）
rep('''			"flyer": 16,
''', '''			"flyer": 16,
			# R753 奇异雕像（第二层专属）：祭拜 → 接下来三场战斗必定掉落工具；
			# 摧毁 → 工具栏用「石头」（7012，砸单个目标 15 伤）填满。
			# 和熔炉 / 契约的核心同层：这一层本来就在「拿工具、投工具」的语境里。
			"statue": 16,
''')

rep('''	"flyer": "飞行器",
''', '''	"flyer": "飞行器",
	"statue": "奇异雕像",
''')

open(p, 'wb').write(txt.encode('utf-8'))
print('ok')
