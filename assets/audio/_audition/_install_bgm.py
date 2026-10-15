# -*- coding: utf-8 -*-
"""BGM 接入器（R176）—— 把选定的 PeriTune loop 曲装进 assets/audio/bgm/。

- 源：`_audition/raw/peritune/PerituneMaterial_<Name>_loop.zip`
      （PeriTune 官方「loop 版」整包，内含 .mp3/.ogg/.m4a 三种容器）
- 取包内 **.ogg**（Godot 的 AudioStreamOggVorbis 循环最稳）→
      `assets/audio/bgm/<slot>.ogg`
- 幂等：目标已存在且 > 1KB 时跳过（--force 可强制覆盖）
- 校验：OggS 魔数 + 大小

槽位映射（2026-10-16 用户拍板，见 `选曲记录.md`）：
    title        标题页            Holy_Place
    class_pick   角色选择          Piano_Refreshing
    map          第一层地图        Poema
    map2         第二层地图        Strategy4
    battle       一般战斗          Dramatic
    battle_elite 精英战斗          EpicBattle
    battle_boss  Boss 战斗         Raid_FolkMetal
"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw", "peritune")
DST = os.path.abspath(os.path.join(HERE, "..", "bgm"))

# (槽位, zip 主名 PeriTune 侧)
SLOTS = [
    ("title", "Holy_Place"),
    ("class_pick", "Piano_Refreshing"),
    ("map", "Poema"),
    ("map2", "Strategy4"),
    ("battle", "Dramatic"),
    ("battle_elite", "EpicBattle"),
    ("battle_boss", "Raid_FolkMetal"),
]


def main() -> int:
    force = "--force" in sys.argv
    os.makedirs(DST, exist_ok=True)
    ok, fail = 0, []
    for slot, name in SLOTS:
        out = os.path.join(DST, "%s.ogg" % slot)
        if os.path.exists(out) and os.path.getsize(out) > 1024 and not force:
            print("跳过（已存在）%s.ogg  %.2f MB"
                  % (slot, os.path.getsize(out) / 1048576))
            ok += 1
            continue
        zpath = os.path.join(RAW, "PerituneMaterial_%s_loop.zip" % name)
        if not os.path.exists(zpath):
            print("  !! 缺 zip:", zpath)
            fail.append(slot)
            continue
        with zipfile.ZipFile(zpath) as z:
            members = [m for m in z.namelist() if m.lower().endswith(".ogg")]
            if not members:
                print("  !! zip 内无 ogg:", zpath)
                fail.append(slot)
                continue
            data = z.read(members[0])
        if data[:4] != b"OggS":
            print("  !! 不是 Ogg 流:", members[0])
            fail.append(slot)
            continue
        with open(out, "wb") as f:
            f.write(data)
        print("装入 %-12s <- %-28s  %.2f MB"
              % (slot + ".ogg", members[0], len(data) / 1048576))
        ok += 1
    print("\n== 汇总 ==  成功 %d / 失败 %d   →  %s" % (ok, len(fail), DST))
    for f in fail:
        print("   失败:", f)
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
