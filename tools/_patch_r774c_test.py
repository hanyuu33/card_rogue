# -*- coding: utf-8 -*-
# R774c：在 test_engine.gd 的 R774 断言后追加英文艺术字断言。
# test_engine.gd 是 CRLF，用 newline="" 读写保持行尾；插入的换行统一转 \r\n。
import io

p = "scripts/test_engine.gd"
with io.open(p, "r", encoding="utf-8", newline="") as f:
    s = f.read()

anchor = ('\tcheck_src(r770_bs.find("StatusBadge.paint(") >= 0,\r\n'
          '\t\t\t"R774 \u6e90\u7801\uff1a\u8bf4\u660e\u7c7b\u98d8\u5b57\u59d4\u6258\u7ed9 StatusBadge\uff08battle_scene \u53ea\u7559\u4e00\u884c\uff09")')

n = s.count(anchor)
assert n == 1, "anchor not unique (count=%d)" % n

new_block = '''
\t# R774c\uff1a\u975e\u4e2d\u6587\u8bed\u8a00\u7edf\u4e00\u7528\u82f1\u6587\u827a\u672f\u5b57\uff08\u5e97\u957f\u53e3\u5f84\u300c\u4ee5\u540e\u9664\u4e86\u4e2d\u6587\u7248\uff0c\u5168\u7528\u82f1\u6587\u7248\u827a\u672f\u5b57\u300d\uff09
\tvar r774c_missing := ""
\tfor r774_g: int in r774_glyphs:
\t\tif not StatusBadge.WORD_TEX_EN.has(r774_g):
\t\t\tr774c_missing += str(r774_g) + " "
\tcheck(r774c_missing == "", "R774c \u7d20\u6750\uff1a\u6bcf\u4e2a\u4e3b\u9898\u90fd\u6709\u82f1\u6587\u72b6\u6001\u8bcd\u56fe\uff08\u7f3a %s\uff09" % r774c_missing)
\t# \u82f1\u6587\u5173\u952e\u8bcd\u8868\u8986\u76d6 11 \u4e3b\u9898\uff08\u7f3a\u5173\u952e\u8bcd\uff0c\u82f1\u6587\u98d8\u5b57\u4f1a\u9000\u56de font \u4e2d\u6587\u515c\u5e95\uff09
\tvar r774c_en_seen := {}
\tfor r774_rule: Array in StatusBadge.RULES_EN:
\t\tr774c_en_seen[int(r774_rule[1])] = true
\tvar r774c_en_missing := ""
\tfor r774_g: int in r774_glyphs:
\t\tif not r774c_en_seen.has(r774_g):
\t\t\tr774c_en_missing += str(r774_g) + " "
\tcheck(r774c_en_missing == "", "R774c \u5173\u952e\u8bcd\uff1aRULES_EN \u8986\u76d6 11 \u4e3b\u9898\uff08\u7f3a %s\uff09" % r774c_en_missing)
\t# \u4e2d\u6587 / \u82f1\u6587\u8bcd\u8868\u4e00\u4e00\u5bf9\u5e94\uff08word_of \u9760\u5b83\u5207\u6362\uff0c\u6f0f\u4e00\u4e2a\u82f1\u6587\u8bcd\u5c31\u4f1a\u98d8\u7a7a\u4e32\uff09
\tvar r774c_word_missing := ""
\tfor r774_g: int in r774_glyphs:
\t\tif not StatusBadge.WORD_ZH.has(r774_g) or str(StatusBadge.WORD_ZH[r774_g]) == "":
\t\t\tr774c_word_missing += "zh" + str(r774_g) + " "
\t\tif not StatusBadge.WORD_EN.has(r774_g) or str(StatusBadge.WORD_EN[r774_g]) == "":
\t\t\tr774c_word_missing += "en" + str(r774_g) + " "
\tcheck(r774c_word_missing == "", "R774c \u8bcd\u8868\uff1aWORD_ZH / WORD_EN \u4e00\u4e00\u5bf9\u5e94\uff08\u7f3a %s\uff09" % r774c_word_missing)
\t# \u82f1\u6587\u7d20\u6750\u6587\u4ef6\u771f\u5b9e\u5b58\u5728\uff08\u8def\u5f84\u767b\u8bb0\u4e86\u4f46\u6587\u4ef6\u6ca1\u8fdb pck \u4f1a\u5728\u5b9e\u673a\u9759\u9ed8\u5931\u8d25\uff09
\tvar r774c_file_missing := ""
\tfor r774_g: int in r774_glyphs:
\t\tif not ResourceLoader.exists(str(StatusBadge.WORD_TEX_EN[r774_g])):
\t\t\tr774c_file_missing += str(r774_g) + " "
\tcheck(r774c_file_missing == "", "R774c \u7d20\u6750\uff1a\u82f1\u6587\u72b6\u6001\u8bcd\u56fe\u6587\u4ef6\u771f\u5b9e\u5b58\u5728\uff08\u7f3a %s\uff09" % r774c_file_missing)
'''

# 把块里的 \n 统一成 \r\n（与文件一致）
new_block = new_block.replace("\n", "\r\n")

s = s.replace(anchor, anchor + new_block, 1)

with io.open(p, "w", encoding="utf-8", newline="") as f:
    f.write(s)

print("OK patched test_engine.gd (inserted R774c assertions)")
