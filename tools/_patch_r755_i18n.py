# -*- coding: utf-8 -*-
"""R755：新增两条 reward 文案（换装条标题 / 取消），四语同步。"""
import io

ROOT = "E:/work/card_rogue/i18n/"

CAN_OLD = """      "REWARD_TOOL_SWAP_TAG": {
        "source": "scripts/reward_panel.gd",
        "zh": "丢掉它"
      },
"""
CAN_NEW = CAN_OLD + """      "REWARD_TOOL_SWAP_HEAD": {
        "source": "scripts/reward_panel.gd",
        "zh": "工具栏已满 · 选一件换下"
      },
      "REWARD_TOOL_SWAP_CANCEL": {
        "source": "scripts/reward_panel.gd",
        "zh": "取消"
      },
"""

LANGS = {
    "en": ('"REWARD_TOOL_SWAP_TAG": "Discard",',
           '"REWARD_TOOL_SWAP_HEAD": "Tool bar is full · pick one to replace",',
           '"REWARD_TOOL_SWAP_CANCEL": "Cancel",'),
    "ja": ('"REWARD_TOOL_SWAP_TAG": "捨てる",',
           '"REWARD_TOOL_SWAP_HEAD": "ツールバー満杯・1つ選んで入れ替え",',
           '"REWARD_TOOL_SWAP_CANCEL": "キャンセル",'),
    "es": ('"REWARD_TOOL_SWAP_TAG": "Descartar",',
           '"REWARD_TOOL_SWAP_HEAD": "Barra llena · elige una para sustituir",',
           '"REWARD_TOOL_SWAP_CANCEL": "Cancelar",'),
}


def patch(path, old, new):
    raw = io.open(ROOT + path, "r", encoding="utf-8", newline="").read()
    assert raw.count(old) == 1, "%s: expected 1, got %d" % (path, raw.count(old))
    raw = raw.replace(old, new)
    io.open(ROOT + path, "w", encoding="utf-8", newline="").write(raw)
    print("patched", path)


patch("interface_zh_canonical.json", CAN_OLD, CAN_NEW)
for lang, (tag, head, cancel) in LANGS.items():
    old = "      " + tag + "\n"
    new = old + "      " + head + "\n      " + cancel + "\n"
    patch("interface_%s.json" % lang, old, new)
print("ok")
