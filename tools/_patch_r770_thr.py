## R770 阈值改口径：>20 重击 / >40 致命（店长口径）。
## test_engine.gd 是 CRLF —— 只用本脚本做 exact-replace，别用编辑器改。
import io

P = "scripts/test_engine.gd"
d = open(P, "rb").read().decode("utf-8")

old = (
    '\t# 分级两道坎\r\n'
    '\tcheck(DmgNumber.tier_of_amount(14) == DmgNumber.TIER_NORMAL, "R770 分级：14 = 普通")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(15) == DmgNumber.TIER_HEAVY, "R770 分级：15 = 重击")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(30) == DmgNumber.TIER_FATAL, "R770 分级：30 = 致命")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(-35) == DmgNumber.TIER_FATAL, "R770 分级：负数取绝对值")\r\n'
)
new = (
    '\t# 分级两道坎：店长口径 **严格大于** 20 / 40 —— 20 仍是普通、40 仍是重击\r\n'
    '\tcheck(DmgNumber.tier_of_amount(20) == DmgNumber.TIER_NORMAL, "R770 分级：20 = 普通（门槛是 >20）")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(21) == DmgNumber.TIER_HEAVY, "R770 分级：21 = 重击")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(40) == DmgNumber.TIER_HEAVY, "R770 分级：40 = 重击（门槛是 >40）")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(41) == DmgNumber.TIER_FATAL, "R770 分级：41 = 致命")\r\n'
    '\tcheck(DmgNumber.tier_of_amount(-45) == DmgNumber.TIER_FATAL, "R770 分级：负数取绝对值")\r\n'
    '\tcheck(DmgNumber.HEAVY_AT == 20 and DmgNumber.FATAL_AT == 40,\r\n'
    '\t\t\t"R770 分级：两道坎常量必须是 20 / 40（改口径要同改断言与 MEMORY_UI）")\r\n'
)
assert d.count(old) == 1, "anchor count=%d" % d.count(old)
d = d.replace(old, new)

open(P, "wb").write(d.encode("utf-8"))
raw = open(P, "rb").read()
print("patch ok  CRLF=%d  LF-only=%d" % (raw.count(b"\r\n"), raw.count(b"\n") - raw.count(b"\r\n")))
