# -*- coding: utf-8 -*-
"""R577f 回归驱动：备份 user:// → 跑 _verify.py 六套 → 逐文件还原比对。

一次调用 = 一整轮，循环关在脚本内部。
用法：python tools/_run_r577f_verify.py [工作目录]
判绿先看 Parse Error / SCRIPT ERROR，再看 RESTORE_VERIFY（只看文件集合 + 内容）。
"""
import io
import os
import shutil
import subprocess
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else r'E:/work/card_rogue'
UD = r'C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/卡牌肉鸽'
TAG = os.path.basename(os.path.normpath(ROOT)).replace('/', '_')[:24]
BK = r'E:/tmp/r577f_userdata_backup_' + TAG
_i = 0
while os.path.isdir(BK):
    _i += 1
    BK = r'E:/tmp/r577f_userdata_backup_%s_%d' % (TAG, _i)


def snap(base):
    out = {}
    for dp, _dns, fns in os.walk(base):
        for fn in fns:
            p = os.path.join(dp, fn)
            out[os.path.relpath(p, base).replace(os.sep, '/')] = io.open(p, 'rb').read()
    return out


def main():
    before = snap(UD)
    shutil.copytree(UD, BK)
    print('BACKUP %d files -> %s' % (len(before), BK), flush=True)

    proc = subprocess.run([sys.executable, '_verify.py'], cwd=ROOT,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900)
    txt = proc.stdout.decode('utf-8', 'replace')
    io.open(os.path.join(ROOT, '_verify_r577f.log'), 'w', encoding='utf-8').write(txt)
    print(txt.strip(), flush=True)
    print('VERIFY_RC', proc.returncode, flush=True)

    for dp, _dns, fns in os.walk(UD):
        for fn in fns:
            p = os.path.join(dp, fn)
            if os.path.relpath(p, UD).replace(os.sep, '/') not in before:
                os.remove(p)
    for rel, data in before.items():
        p = os.path.join(UD, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        cur = io.open(p, 'rb').read() if os.path.isfile(p) else None
        if cur != data:
            io.open(p, 'wb').write(data)
    after = snap(UD)
    diff = [k for k in sorted(set(before) | set(after)) if before.get(k) != after.get(k)]
    print('RESTORE_VERIFY', 'OK' if not diff else 'MISMATCH ' + str(diff[:12]), flush=True)
    return 0 if proc.returncode == 0 and not diff else 1


if __name__ == '__main__':
    sys.exit(main())
