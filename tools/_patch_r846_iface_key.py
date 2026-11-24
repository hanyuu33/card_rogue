# -*- coding: utf-8 -*-
"""R846：删掉界面键 battle.BATTLE_ENERGY_DODGE。

闪躲 9103 不再给「全员嘲讽」窗口 → 费用面板那行状态没有了，这个 key 成了死键，
`validate_interface.py` 会报「未在源文件中找到」。四处（canonical + en/ja/es）一起删，
并把 `expected_counts.battle` 80 → 79。
"""
import io

CANON = "i18n/interface_zh_canonical.json"
PLAINS = ["i18n/interface_en.json", "i18n/interface_ja.json", "i18n/interface_es.json"]


def main():
    # ① canonical：整块 4 行删掉
    raw = io.open(CANON, "r", encoding="utf-8", newline="").read()
    crlf = raw.count("\r\n") == raw.count("\n")
    txt = raw.replace("\r\n", "\n") if crlf else raw
    block = ('      "BATTLE_ENERGY_DODGE": {\n'
             '        "source": "scripts/battle_energy_hud.gd:46",\n'
             '        "zh": "闪躲：友军嘲讽"\n'
             '      },\n')
    assert txt.count(block) == 1, "canonical 条目命中 %d 次" % txt.count(block)
    txt = txt.replace(block, "")
    old_cnt = '"battle": 80,'
    assert txt.count(old_cnt) == 1, "expected_counts.battle 命中 %d 次" % txt.count(old_cnt)
    txt = txt.replace(old_cnt, '"battle": 79,')
    io.open(CANON, "w", encoding="utf-8", newline="").write(
        txt.replace("\n", "\r\n") if crlf else txt)
    print("%s 删键 + battle 80→79（%s）" % (CANON, "CRLF" if crlf else "LF"))

    # ② en / ja / es：单行删掉
    for p in PLAINS:
        raw = io.open(p, "r", encoding="utf-8", newline="").read()
        crlf = raw.count("\r\n") == raw.count("\n")
        txt = raw.replace("\r\n", "\n") if crlf else raw
        keep = [l for l in txt.split("\n") if '"BATTLE_ENERGY_DODGE"' not in l]
        assert len(keep) == len(txt.split("\n")) - 1, "%s 命中数不是 1" % p
        txt = "\n".join(keep)
        io.open(p, "w", encoding="utf-8", newline="").write(
            txt.replace("\n", "\r\n") if crlf else txt)
        print("%s 删键" % p)


if __name__ == "__main__":
    main()
