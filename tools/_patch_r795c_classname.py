# -*- coding: utf-8 -*-
"""R795c：职业名 / 记录行种子标签的显示口径修正。

* 记录页原来只调 `PlayerClass.legacy_id()`：中文 id 直接画到 en / ja / es 界面上，
  旧记录里的「德鲁伊」又认不出译名 → 统一走新增的 `PlayerClass.display_name_of()`。
* 列表行第二列的「种子：」是硬编码中文（R261），英文界面露中文 → 走 `RECORD_SEED`。

跑法：在**干净树**（worktree at HEAD）里 `python tools/_patch_r795c_classname.py`。
主仓工作区是并行线的草稿，别在那里直接跑。脚本可重跑（已改就跳过）。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = "\t"


def read(p):
    return io.open(os.path.join(ROOT, p), "rb").read().decode("utf-8")


def write(p, s):
    io.open(os.path.join(ROOT, p), "wb").write(s.encode("utf-8"))


def swap(text, old, new, times=1):
    """old → new；已经换过（new 在、old 不在）就原样返回 —— 脚本可重跑。"""
    if old in text:
        n = text.count(old)
        assert n == times, (old[:50], "count=%d want=%d" % (n, times))
        return text.replace(old, new, times)
    assert new in text, "既没找到 old 也没找到 new：" + old[:50]
    return text


def lf(s):
    return s.replace("\r\n", "\n")


def crlf(s):
    return s.replace("\n", "\r\n")


# ==================================================== 1. player_class.gd：新增唯一口
PC_OLD = ('static func name_of(cid: String) -> String:\n'
          + T + 'return GameI18n.class_name_of(cid)\n')

PC_NEW = ('static func name_of(cid: String) -> String:\n'
          + T + 'return GameI18n.class_name_of(cid)\n'
          + '\n'
          + '\n'
          + 'static func display_name_of(cid: String) -> String:\n'
          + T + '## 界面上显示职业名的**唯一口**：先把旧名归一到现行 id（德鲁伊 → 森林精魄），\n'
          + T + '## 再按当前语言取译名。\n'
          + T + '## 为什么不能只调其中一个：只做 `legacy_id()` 会把中文原名「森林精魄」直接画到\n'
          + T + '## 英文 / 日文 / 西班牙语界面上（记录页原来的毛病，R795c 修）；只做 `name_of()`\n'
          + T + '## 又认不出旧记录里存的「德鲁伊」（2026-10-03 改名前的老数据）。\n'
          + T + 'return name_of(legacy_id(cid))\n')

_ps = lf(read("scripts/player_class.gd"))
if "func display_name_of(" not in _ps:
    _ps = swap(_ps, PC_OLD, PC_NEW)
write("scripts/player_class.gd", _ps)

# ==================================================== 2. record_list_scene.gd：两处职业名
REC_OLD = 'PlayerClass.legacy_id(str(rec.get("class", "?")))'
REC_NEW = 'PlayerClass.display_name_of(str(rec.get("class", "?")))'
rs = lf(read("scripts/record_list_scene.gd"))
if "PlayerClass.display_name_of(" not in rs:
    rs = swap(rs, REC_OLD, REC_NEW, times=2)
    assert rs.count("PlayerClass.legacy_id(") == 0

# ==================================================== 3. 列表行种子标签走 i18n
SEED_OLD = '"种子：%s" % ("—" if row_seed == 0 else RunState.seed_text_of(row_seed)),'
SEED_NEW = ('GameI18n.ui("shell", "RECORD_SEED", "种子：%s")'
            ' % ("—" if row_seed == 0 else RunState.seed_text_of(row_seed)),')
if SEED_OLD in rs:
    rs = swap(rs, SEED_OLD, SEED_NEW)
write("scripts/record_list_scene.gd", rs)

# ==================================================== 4. curtain_lines.gd：统一写法
CU_OLD = T + 'return PlayerClass.name_of(PlayerClass.legacy_id(cls))'
CU_NEW = T + 'return PlayerClass.display_name_of(cls)'
write("scripts/curtain_lines.gd", swap(lf(read("scripts/curtain_lines.gd")), CU_OLD, CU_NEW))

# ==================================================== 5. test_engine.gd：五条断言
TE_BLOCK = [
    '',
    T + '# ---- R795c：职业名显示 = 「旧名归一 + 按当前语言翻译」 ----',
    T + '# 记录页原来只调 legacy_id()：中文 id 直接画到 en / ja / es 界面上；旧记录里的',
    T + '# 「德鲁伊」又认不出译名。唯一口 = PlayerClass.display_name_of()。',
    T + 'check(PlayerClass.display_name_of(PlayerClass.DRUID) == "森林精魄"',
    T + T + T + 'and PlayerClass.display_name_of("德鲁伊") == "森林精魄"',
    T + T + T + 'and PlayerClass.display_name_of(PlayerClass.ROGUE) == "暗影刺客"',
    T + T + T + 'and PlayerClass.display_name_of("游荡者") == "暗影刺客",',
    T + T + T + '"R795c 职业名：现行 id 与旧 id 都归一到「%s」" % PlayerClass.display_name_of("德鲁伊"))',
    '',
    T + 'var r795c_lang := GameSettings.language',
    T + 'GameSettings.set_language("en", true)',
    T + 'GameSettings._loaded = false',
    T + 'GameSettings.ensure_loaded()',
    T + 'check(PlayerClass.display_name_of(PlayerClass.DRUID) == "Forest Spirit"',
    T + T + T + 'and PlayerClass.display_name_of("德鲁伊") == "Forest Spirit",',
    T + T + T + '"R795c 英文界面下职业名译出（%s）" % PlayerClass.display_name_of(PlayerClass.DRUID))',
    T + 'GameSettings.set_language(r795c_lang, true)',
    T + 'GameSettings._loaded = false',
    T + 'GameSettings.ensure_loaded()',
    T + 'check(PlayerClass.display_name_of(PlayerClass.DRUID) == "森林精魄",',
    T + T + T + '"R795c 语言切回后职业名仍是中文（%s）" % PlayerClass.display_name_of(PlayerClass.DRUID))',
    '',
    T + 'var r795c_rec := FileAccess.get_file_as_string("res://scripts/record_list_scene.gd").replace("\\r\\n", "\\n")',
    T + 'check_src(r795c_rec.find("PlayerClass.legacy_id(") < 0',
    T + T + T + 'and r795c_rec.count("PlayerClass.display_name_of(") == 2,',
    T + T + T + '"R795c 记录页两处职业名都走 display_name_of()（不再裸 legacy_id）")',
    T + 'check_src(r795c_rec.count("RECORD_SEED") == 2,',
    T + T + T + '"R795c 记录行 / 详情种子标签都走 RECORD_SEED（英文界面不再露中文）")',
]

te = lf(read("scripts/test_engine.gd"))
if "R795c 职业名" in te:
    print("· test_engine 已有 R795c 断言，跳过")
else:
    lines = te.split("\n")
    anchor = None
    for i, ln in enumerate(lines):
        if "R795 难度标签唯一口在 RunState" in ln:
            anchor = i
            break
    assert anchor is not None, "找不到 R795 断言尾"
    tail = None
    for k in range(anchor, min(anchor + 12, len(lines))):
        if lines[k].strip() == "RunState.reset(50)":
            tail = k
            break
    assert tail is not None, "找不到 RunState.reset(50)"
    lines[tail:tail] = TE_BLOCK
    write("scripts/test_engine.gd", crlf("\n".join(lines)))

print("ok：player_class / record_list_scene / curtain_lines / test_engine 已改")
