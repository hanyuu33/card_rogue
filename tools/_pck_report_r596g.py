import collections
import struct
import sys

path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/r596g.pck'
buf = open(path, 'rb').read()

pos = 0
magic = buf[pos:pos + 4]
assert magic == b'GDPC', magic
pos += 4
pack_version, vmaj, vmin, vpatch = struct.unpack_from('<4I', buf, pos)
pos += 16
flags = struct.unpack_from('<I', buf, pos)[0]
pos += 4
file_base = struct.unpack_from('<Q', buf, pos)[0]
pos += 8
pos += 16 * 4
file_count = struct.unpack_from('<I', buf, pos)[0]
pos += 4

entries = []
for _ in range(file_count):
    plen = struct.unpack_from('<I', buf, pos)[0]
    pos += 4
    p = buf[pos:pos + plen].decode('utf-8')
    pos += plen
    off, size = struct.unpack_from('<QQ', buf, pos)
    pos += 16
    pos += 16
    fl = struct.unpack_from('<I', buf, pos)[0]
    pos += 4
    entries.append((p, size, fl))

print('PCK %s  文件 %d 个  %.1f MB' % (path, len(entries), sum(e[1] for e in entries) / 1048576))

byext = collections.Counter()
for p, s, f in entries:
    import os
    ext = os.path.splitext(p)[1].lower()
    if '.ctex' in p:
        for tag in ('bptc', 'astc', 's3tc', 'etc2'):
            if '.%s.' % tag in p:
                ext = '.' + tag
                break
    byext[ext] += s
print('--- 按类型 ---')
for k, v in byext.most_common(10):
    print('  %-12s %7.1f MB' % (k, v / 1048576))

leak = [e for e in entries if '_pending' in e[0] or '_preview' in e[0] or '_bk_' in e[0]]
print('--- 临时目录残留 %d 个 ---' % len(leak))
for p, s, f in leak[:8]:
    print('   %8d  %s' % (s, p))
print('残留合计 %.2f MB' % (sum(e[1] for e in leak) / 1048576))
