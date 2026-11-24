# -*- coding: utf-8 -*-
"""R807c：更新 MEMORY.md 里的包体基线（测试版重打后的真实数字）。"""
import io

P = 'E:/work/.workbuddy/memory/MEMORY.md'

OLD = "- 包体：R763 正式 exe 260.1MB；R750 测试版 exe 251.17MB / APK 213.46MB。"
NEW = ("- 包体：**R807 测试版 exe 282.57MB / APK 244.75MB**（发布版 exe 80.37MB + pck 202.19MB "
       "+ content 1.08MB）。R763 正式 exe 260.1MB；R750 测试版 exe 251.17MB / APK 213.46MB。")

b = io.open(P, 'rb').read()
s = b.decode('utf-8')
assert s.count(OLD) == 1, ('anchor count', s.count(OLD))
s = s.replace(OLD, NEW)
io.open(P, 'wb').write(s.encode('utf-8'))

b2 = io.open(P, 'rb').read()
print('CRLF=%d LF=%d' % (b2.count(b'\r\n'), b2.count(b'\n')))
print([l for l in b2.decode('utf-8').splitlines() if '包体' in l][0])
