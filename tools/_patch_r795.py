# -*- coding: utf-8 -*-
"""R795：结算 / 记录里难度显示成「数字 + 名称」。

做两件事：
  1. 改工作区的 .gd / i18n（工作区里混着并行线未提交的改动，所以只做定点替换）；
  2. 对「混装文件」额外生成一份**干净副本**（HEAD 内容 + 同一批替换），
     供 `git update-index --cacheinfo` 入索引 —— 提交时不会夹带别人的改动。

脚本可重跑（`swap()` 发现已换过就原样返回）。
"""
import io
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLEAN = "E:/tmp/r795_clean"


def read(p):
    return io.open(os.path.join(ROOT, p), "rb").read().decode("utf-8")


def write(p, s):
    with io.open(os.path.join(ROOT, p), "wb") as f:
        f.write(s.encode("utf-8"))


def head_text(p, crlf=False):
    raw = subprocess.run(["git", "-C", ROOT, "show", "HEAD:" + p],
                         capture_output=True, check=True).stdout.decode("utf-8")
    return raw.replace("\r\n", "\n") if crlf else raw


def dump_clean(name, s, crlf=False):
    os.makedirs(CLEAN, exist_ok=True)
    if crlf:
        s = s.replace("\r\n", "\n").replace("\n", "\r\n")
    with io.open(os.path.join(CLEAN, name), "wb") as f:
        f.write(s.encode("utf-8"))


def swap(text, old, new):
    """old → new；已经换过（new 在、old 不在）就原样返回 —— 脚本可重跑。"""
    if old in text:
        assert text.count(old) == 1, old[:50]
        return text.replace(old, new, 1)
    assert new in text, "既没找到 old 也没找到 new：" + old[:50]
    return text


def line_of(text, needle):
    for i, line in enumerate(text.split("\n")):
        if needle in line:
            return i + 1
    raise AssertionError("找不到行：" + needle)


# ============================================================ 1. run_state.gd
OLD_RS = '''static func difficulty_name() -> String:
\treturn DIFFICULTY_NAMES[_diff()]
'''
NEW_RS = '''static func difficulty_name() -> String:
\treturn difficulty_name_at(_diff())


static func difficulty_name_at(d: int) -> String:
\t## 指定档位的名称。`d` 越界（旧版本记录 / 脏数据）→ 钳到合法区间，绝不越界取数组。
\treturn DIFFICULTY_NAMES[clampi(d, 0, DIFFICULTY_COUNT - 1)]


static func difficulty_label(d: int = -1) -> String:
\t## R795：「数字 + 名称」（例 `12 昂贵`）—— 结算副标题 / 对战记录共用的**唯一口**。
\t## 数字就是角色选择界面档位框里的那个 0~12，名称紧跟其后，玩家不用再自己对照。
\t## `d < 0` = 当前档；越界 / 缺失由 `clampi` 兜住 —— **兼容旧版本记录文件**就靠这一句：
\t## 老记录只存了档位数字（`difficulty`），名称一律现推，不落盘也不怕以后改名。
\tvar i := _diff() if d < 0 else clampi(d, 0, DIFFICULTY_COUNT - 1)
\treturn "%d %s" % [i, DIFFICULTY_NAMES[i]]
'''

# ============================================== 2. run_summary_scene.gd（结算）
OLD_SUM = '\tvar sub := "%s · %s" % [GameLayers.layer_name(lay), RunState.DIFFICULTY_NAMES[diff]]\n'
NEW_SUM = '''\t# R795（用户口径）：副标题要带**档位数字** —— 原来只拼名字（「噩梦」），玩家对不上
\t# 自己在角色选择界面挑的是第几档。数字 + 名称统一走 `RunState.difficulty_label()`。
\tvar sub := "%s · %s" % [GameLayers.layer_name(lay),
\t\t\tGameI18n.ui("shell", "RUN_SUMMARY_DIFFICULTY", "难度 %s") % RunState.difficulty_label(diff)]
'''

# ============================================== 3. record_list_scene.gd（记录）
NEW_REC_DETAIL = '''\t# R795：难度写成「数字 + 名称」（`RunState.difficulty_label()` 唯一口）—— 原来只有
\t# 档位数字，看不出是哪一档。旧记录只存了数字，名称现推；越界脏数据由它钳住。
\tdraw_string(_font, Vector2(x0 + 250.0, top + 26.0),
\t\t\tGameI18n.ui("shell", "RECORD_CLASS_DIFFICULTY_TIME", "角色：%s · 难度 %s · 用时 %s")
\t\t\t% [PlayerClass.legacy_id(str(rec.get("class", "?"))),
\t\t\tRunState.difficulty_label(int(rec.get("difficulty", 2))),
\t\t\tRunRecord.fmt_secs(int(rec.get("secs", 0)))],
\t\t\tHORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
'''
NEW_REC_ROW = '''\t# R795：同详情 —— 「难度 12 昂贵 · 用时 5 分」（数字 + 名称）。
\tdraw_string(_font, r.position + Vector2(596, 22),
\t\t\tGameI18n.ui("shell", "RECORD_ROW_DIFFICULTY_TIME", "难度 %s · 用时 %s") % [
\t\t\tRunState.difficulty_label(int(rec.get("difficulty", 2))),
\t\t\tRunRecord.fmt_secs(int(rec.get("secs", 0)))],
\t\t\tHORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
'''


def replace_stmt(text, key, new_block):
    """把包含 key 的那一条 draw_string(...) 语句整体换掉。"""
    i = text.index(key)
    start = text.rindex("\tdraw_string(", 0, i)
    end = text.index("UiTheme.PAGE_INK)\n", i) + len("UiTheme.PAGE_INK)\n")
    return text[:start] + new_block + text[end:]


# ============================================================ 执行 .gd 改动
rs = swap(read("scripts/run_state.gd"), OLD_RS, NEW_RS)
write("scripts/run_state.gd", rs)
dump_clean("run_state.gd", swap(head_text("scripts/run_state.gd"), OLD_RS, NEW_RS))

summ = swap(read("scripts/run_summary_scene.gd"), OLD_SUM, NEW_SUM)
write("scripts/run_summary_scene.gd", summ)

rec = read("scripts/record_list_scene.gd")
if NEW_REC_DETAIL in rec:
    rec_new = rec
else:
    rec_new = replace_stmt(rec, '"RECORD_CLASS_DIFFICULTY_TIME"', NEW_REC_DETAIL)
    rec_new = replace_stmt(rec_new, '"RECORD_ROW_DIFFICULTY_TIME"', NEW_REC_ROW)
write("scripts/record_list_scene.gd", rec_new)

# ============================================================ 4. i18n
SUM_LINE = line_of(summ, '"RUN_SUMMARY_DIFFICULTY", "难度 %s"')
REC_DETAIL_LINE = line_of(rec_new, '"RECORD_CLASS_DIFFICULTY_TIME"')
REC_ROW_LINE = line_of(rec_new, '"RECORD_ROW_DIFFICULTY_TIME"')
print("行号：结算难度 %d / 记录详情 %d / 记录行 %d" % (SUM_LINE, REC_DETAIL_LINE, REC_ROW_LINE))

ZH_DETAIL_OLD = ('"source": "scripts/record_list_scene.gd:345",\n'
                 '        "zh": "角色：%s · 难度 %d · 用时 %s"')
ZH_DETAIL_NEW = ('"source": "scripts/record_list_scene.gd:' + str(REC_DETAIL_LINE) + '",\n'
                 '        "zh": "角色：%s · 难度 %s · 用时 %s"')
ZH_ROW_OLD = ('"source": "scripts/record_list_scene.gd:460",\n'
              '        "zh": "难度 %d · 用时 %s"')
ZH_ROW_NEW = ('"source": "scripts/record_list_scene.gd:' + str(REC_ROW_LINE) + '",\n'
              '        "zh": "难度 %s · 用时 %s"')
NEW_KEY_ZH = ('      "RUN_SUMMARY_DIFFICULTY": {\n'
              '        "source": "scripts/run_summary_scene.gd:' + str(SUM_LINE) + '",\n'
              '        "zh": "难度 %s"\n'
              '      },\n')
ANCHOR_KEY = '      "RUN_SUMMARY_VICTORY": {'


def patch_zh(t):
    t = swap(t, ZH_DETAIL_OLD, ZH_DETAIL_NEW)
    t = swap(t, ZH_ROW_OLD, ZH_ROW_NEW)
    if '"RUN_SUMMARY_DIFFICULTY"' not in t:
        t = swap(t, ANCHOR_KEY, NEW_KEY_ZH + ANCHOR_KEY)
    t = swap(t, '"shell": 214,', '"shell": 215,')
    return t


write("i18n/interface_zh_canonical.json", patch_zh(read("i18n/interface_zh_canonical.json")))
dump_clean("interface_zh_canonical.json", patch_zh(head_text("i18n/interface_zh_canonical.json")))

# ---- en / ja / es
LANGS = {
    "en": ("Class: %s · Difficulty %d · Time %s", "Class: %s · Difficulty %s · Time %s",
           "Difficulty %d · Time %s", "Difficulty %s · Time %s", "Difficulty %s"),
    "ja": ("クラス：%s · 難易度 %d · 時間 %s", "クラス：%s · 難易度 %s · 時間 %s",
           "難易度 %d · 時間 %s", "難易度 %s · 時間 %s", "難易度 %s"),
    "es": ("Clase: %s · Dificultad %d · Tiempo %s", "Clase: %s · Dificultad %s · Tiempo %s",
           "Dificultad %d · Tiempo %s", "Dificultad %s · Tiempo %s", "Dificultad %s"),
}
for lang, (old_c, new_c, old_r, new_r, new_key) in LANGS.items():
    p = "i18n/interface_%s.json" % lang

    def patch_lang(t, old_c=old_c, new_c=new_c, old_r=old_r, new_r=new_r, new_key=new_key):
        t = swap(t, '"' + old_c + '"', '"' + new_c + '"')
        t = swap(t, '"' + old_r + '"', '"' + new_r + '"')
        a = '      "RUN_SUMMARY_VICTORY":'
        return swap(t, a, '      "RUN_SUMMARY_DIFFICULTY": "' + new_key + '",\n' + a)

    write(p, patch_lang(read(p)))
    dump_clean("interface_%s.json" % lang, patch_lang(head_text(p)))

# ============================================================ 5. test_engine.gd（CRLF）
ANCHOR_TE = '\t\t\t"难度档位：共 13 档；战斗胜利回血恒 0 / 篝火 40%%(0档)·25%%(1档起)（R237 恢复）")\n'
NEW_TE = '''
\t# ---- R795：难度显示「数字 + 名称」（结算副标题 / 对战记录）----
\tcheck(RunState.difficulty_label(0) == "0 轻松" and RunState.difficulty_label(12) == "12 昂贵"
\t\t\tand RunState.difficulty_name_at(11) == "上锁",
\t\t\t"R795 难度标签＝数字 + 名称（0 → %s / 12 → %s / 11 名 %s）" % [
\t\t\tRunState.difficulty_label(0), RunState.difficulty_label(12),
\t\t\tRunState.difficulty_name_at(11)])

\t# 旧版本记录文件兼容：档位只存了数字，名称现推；越界 / 负数一律钳住，不许越界取数组。
\tcheck(RunState.difficulty_label(99) == "12 昂贵" and RunState.difficulty_label(-5) == "0 轻松"
\t\t\tand RunState.difficulty_name_at(999) == "昂贵",
\t\t\t"R795 旧记录越界档位被钳制（99 → %s / -5 → %s）" % [
\t\t\tRunState.difficulty_label(99), RunState.difficulty_label(-5)])

\tRunState.set_difficulty(7)

\tcheck(RunState.difficulty_label() == "7 贫瘠" and RunState.difficulty_label(-1) == "7 贫瘠",
\t\t\t"R795 不带参数＝当前档（%s）" % RunState.difficulty_label())

\tvar r795_sum := FileAccess.get_file_as_string("res://scripts/run_summary_scene.gd").replace("\\r\\n", "\\n")
\tvar r795_rec := FileAccess.get_file_as_string("res://scripts/record_list_scene.gd").replace("\\r\\n", "\\n")
\tvar r795_state := FileAccess.get_file_as_string("res://scripts/run_state.gd").replace("\\r\\n", "\\n")

\tcheck_src(r795_sum.find("RunState.difficulty_label(diff)") >= 0
\t\t\tand r795_sum.find("RunState.DIFFICULTY_NAMES[diff]") < 0,
\t\t\t"R795 结算副标题带档位数字（不再只拼 DIFFICULTY_NAMES）")

\tcheck_src(r795_rec.find("RunState.difficulty_label(int(rec.get(\\"difficulty\\", 2)))") >= 0
\t\t\tand r795_rec.find("难度 %d") < 0,
\t\t\t"R795 记录行 / 详情都出「数字 + 名称」（不再只有 %d）")

\tcheck_src(r795_state.find("func difficulty_label(d: int = -1)") >= 0
\t\t\tand r795_state.find("DIFFICULTY_NAMES[clampi(d, 0, DIFFICULTY_COUNT - 1)]") >= 0,
\t\t\t"R795 难度标签唯一口在 RunState，越界由 clampi 兜住")

\tRunState.set_difficulty(0)
'''
te = read("scripts/test_engine.gd").replace("\r\n", "\n")
te_new = swap(te, ANCHOR_TE, ANCHOR_TE + NEW_TE)
write("scripts/test_engine.gd", te_new.replace("\n", "\r\n"))
dump_clean("test_engine.gd",
           swap(head_text("scripts/test_engine.gd", crlf=True), ANCHOR_TE, ANCHOR_TE + NEW_TE),
           crlf=True)

print("ok：工作区已改 + 干净副本在 " + CLEAN)
