import io, re, sys

SRC = 'E:/tmp/r783b.full.diff'
OUT = 'E:/tmp/r783b.mine.diff'
KEEP = {3, 4, 5, 6}   # 第 0 个 hunk = --handbonus 演示分支；第 6 个 = 金框重写

lines = open(SRC, encoding='utf-8', newline='').read().split('\n')
head = []
hunks = []
cur = None
for ln in lines:
    if ln.startswith('@@'):
        cur = [ln]
        hunks.append(cur)
    elif cur is None:
        head.append(ln)
    else:
        cur.append(ln)

print('hunks', len(hunks))
out = list(head)
delta = 0
for i, h in enumerate(hunks):
    m = re.match(r'@@ -(\d+),(\d+) \+(\d+),(\d+) @@', h[0])
    os_, oc, ns, nc = map(int, m.groups())
    body = [l for l in h[1:] if l[:1] in ('+', '-', ' ') or l == '']
    # 校验计数
    ac = sum(1 for l in body if l.startswith('+'))
    dc = sum(1 for l in body if l.startswith('-'))
    assert oc - dc + ac == nc, (i, ac, nc, dc, oc)
    if i in KEEP:
        new_ns = os_ + delta
        h[0] = '@@ -%d,%d +%d,%d @@' % (os_, oc, new_ns, nc)
        out.extend(h)
        delta += ac - dc
    # 跳过的 hunk 不影响 delta（因为不被应用）

txt = '\n'.join(out)
if not txt.endswith('\n'):
    txt += '\n'
open(OUT, 'w', encoding='utf-8', newline='').write(txt)
print('written', OUT, 'delta', delta)
