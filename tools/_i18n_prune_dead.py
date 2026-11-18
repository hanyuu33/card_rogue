# -*- coding: utf-8 -*-
"""清掉界面底本与三语译文里的死 key，并同步 expected_counts 锁定数。

死 key 判定依据（2026-11-18 实测）：
  reward.REWARD_TOOL_FULL_SWAP / _BTN  R755 起换成 REWARD_TOOL_SWAP_HEAD
  map.GALLERY_SUMMARY_LOCKED           R753 起移除（test_engine 有「不再包含」断言）
  shell.STORY_GRANTS_BOTH              源码已无调用
  shell.RECORD_MORE_RELICS             R713 起移除（test_engine 有断言）
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEAD = {
    "reward": ["REWARD_TOOL_FULL_SWAP", "REWARD_TOOL_FULL_BTN"],
    "map": ["GALLERY_SUMMARY_LOCKED"],
    "shell": ["STORY_GRANTS_BOTH", "RECORD_MORE_RELICS"],
}
SCOPES = ("shop", "reward", "map", "battle", "shell", "shared")


def main():
    for name in ("interface_zh_canonical", "interface_en", "interface_ja", "interface_es"):
        p = ROOT / "i18n" / (name + ".json")
        d = json.loads(p.read_text(encoding="utf-8"))
        removed = 0
        for scope, keys in DEAD.items():
            kv = d.get("scopes", {}).get(scope, {})
            for k in keys:
                if k in kv:
                    del kv[k]
                    removed += 1
        if name == "interface_zh_canonical":
            counts = d.setdefault("expected_counts", {})
            for scope in SCOPES:
                if scope in counts:
                    counts[scope] = len(d["scopes"][scope])
            d["updated"] = "2026-11-18"
            print("expected_counts →", counts)
        p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("%s: 删除 %d 条" % (name, removed))


if __name__ == "__main__":
    main()
