# -*- coding: utf-8 -*-
"""R826 回归翻面：加 7 张音符卡（9277~9283）+ 音乐盒 6086 后，
把写死条数的断言一次性翻面。SPELL_BASE_DMG[9283] 49 -> 7（表登记卡面首个 N）。
只做 exact-replace + count 断言，不碰换行符（CRLF/LF 自动识别）。"""
import io

ROOT = r"E:\work\card_rogue"


def do(rel, repls):
    path = ROOT + "\\" + rel
    raw = open(path, "rb").read()
    nl = "\r\n" if b"\r\n" in raw else "\n"
    text = raw.decode("utf-8")
    for old, new in repls:
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = text.count(o)
        assert c == 1, "锚点出现 %d 次（期望 1）[%s]: %r" % (c, rel, old[:60])
        text = text.replace(o, n)
    open(path, "wb").write(text.encode("utf-8"))
    print("OK %s：%d 处替换" % (rel, len(repls)))


# ---------- game_engine.gd（CRLF）----------
do(r"scripts\game_engine.gd", [
    ("9283: 49,    # Si（音符；随机 7 × 7，总量）",
     "9283: 7,     # Si（音符；随机 7 伤 × 7 次，表登记卡面首个 N）"),
])

# ---------- test_engine.gd（CRLF）----------
do(r"scripts\test_engine.gd", [
    # 图鉴总数 337 -> 344
    ("repo.all_cards().size() == 337,",
     "repo.all_cards().size() == 344,"),
    ("\"图鉴 = 337 张（R807 玩家 +1",
     "\"图鉴 = 344 张（R826 玩家 +7：do/re/mi/fa/sol/la/si 9277~9283（吟游诗人 · 音符 · 次元 · rarity 5 不进随机池）；R807 玩家 +1"),
    # 图鉴分组 259 -> 266
    ("grp_player.size() == 259 and grp_enemy.size() == 78,",
     "grp_player.size() == 266 and grp_enemy.size() == 78,"),
    ("（期望 259 / 78（R807 玩家 +1",
     "（期望 266 / 78（R826 玩家 +7：音符 9277~9283；R807 玩家 +1"),
    # 第二层起始道具池 10 -> 11（16976 附近）
    ("l2ids.size() == 10 and l2ids.has(6014)",
     "l2ids.size() == 11 and l2ids.has(6014)"),
    ("and l2ids.has(6067) and l2ids.has(6085),",
     "and l2ids.has(6067) and l2ids.has(6085) and l2ids.has(6086),"),
    ("\"第二层起始道具池 10 件（",
     "\"第二层起始道具池 11 件（"),
    ("R509 记忆药水 6067 + R824 鸭子闹钟 6085）",
     "R509 记忆药水 6067 + R824 鸭子闹钟 6085 + R826 音乐盒 6086）"),
    # 角色系统 吟游诗人 9 -> 16
    ("int(dr_cls_count.get(PlayerClass.BARD, 0)) == 9",
     "int(dr_cls_count.get(PlayerClass.BARD, 0)) == 16"),
    ("吟游诗人 9（R800 +2：余音 / 音符）",
     "吟游诗人 16（R826 +7：do/re/mi/fa/sol/la/si 音符卡；R800 +2：余音 / 音符）"),
    # R226 玩家技能卡 111 -> 118，直接伤害 44 -> 48
    ("r226_skills == 111 and r226_dmg == 44",
     "r226_skills == 118 and r226_dmg == 48"),
    # R577b 保真锁 80 -> 81
    ("\"R577b 保真锁：80 件道具的 id",
     "\"R577b 保真锁：81 件道具的 id"),
    ("缺陷时钟 6084 / R824 +鸭子闹钟 6085）",
     "缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086）"),
    # R246 二层起始道具池 10 -> 11
    ("r246_l2.size() == 10 and r246_l2.has(6033)",
     "r246_l2.size() == 11 and r246_l2.has(6033)"),
    # R824 数据层 80 -> 81
    ("r810_repo.all_relics().size() == 80, \"R824 数据层：道具总数 80 件（+鸭子闹钟 6085）",
     "r810_repo.all_relics().size() == 81, \"R824 数据层：道具总数 81 件（+鸭子闹钟 6085 / R826 音乐盒 6086）"),
    # R824 池 10 -> 11（⑥ 段）
    ("# ── ⑤ 池子分流：10 = 5 + 5，互不重叠（R824 加的鸭子闹钟 6085 归鸭绅士）──",
     "# ── ⑤ 池子分流：11 = 6 + 5，互不重叠（R824 鸭子闹钟 6085 归鸭绅士 / R826 音乐盒 6086 归卷卷）──"),
    ("check(r822_all.size() == 10,",
     "check(r822_all.size() == 11,"),
    ("\"R824 池：二层起始池全量 10 件（R822 的 9 + 鸭子闹钟 6085，实际 %d）\"",
     "\"R824 池：二层起始池全量 11 件（R822 的 9 + 鸭子闹钟 6085 + 音乐盒 6086，实际 %d）\""),
    ("check(r822_bun.size() == 5, \"R822 池：卷卷 5 件（实际 %d）\" % r822_bun.size())",
     "check(r822_bun.size() == 6, \"R822 池：卷卷 6 件（实际 %d）\" % r822_bun.size())"),
    ("check(r822_union.size() == 10,",
     "check(r822_union.size() == 11,"),
    ("\"R824 池：5 + 5 = 10 件，一件没丢（实际 %d）\"",
     "\"R824 池：6 + 5 = 11 件，一件没丢（实际 %d）\""),
])

# ---------- test_reward.gd（CRLF）----------
do(r"scripts\test_reward.gd", [
    ("check(all.size() == 337, \"卡牌库 337 张（R807 +1",
     "check(all.size() == 344, \"卡牌库 344 张（R826 +7：do/re/mi/fa/sol/la/si 9277~9283（吟游诗人 · 音符 · 次元 · rarity 5 不进奖励池）；R807 +1"),
])

# ---------- _probe_content_override.gd（CRLF）----------
do(r"tools\_probe_content_override.gd", [
    ("读到的就是 pck 基线（337 张卡，卡名不变）",
     "读到的就是 pck 基线（344 张卡，卡名不变）"),
    ("数量仍为 337（整份替换，不是合并）",
     "数量仍为 344（整份替换，不是合并）"),
    ("_check(\"基线卡牌 337 张\", base_count == 337, str(base_count))",
     "_check(\"基线卡牌 344 张\", base_count == 344, str(base_count))"),
    ("_check(\"覆盖后仍是 337 张\", ov.all_cards().size() == 337, str(ov.all_cards().size()))",
     "_check(\"覆盖后仍是 344 张\", ov.all_cards().size() == 344, str(ov.all_cards().size()))"),
    ("_check(\"坏 JSON 回落基线\", broken.all_cards().size() == 337 and broken.get_card(CARD_ID).card_name == base_name,",
     "_check(\"坏 JSON 回落基线\", broken.all_cards().size() == 344 and broken.get_card(CARD_ID).card_name == base_name,"),
    ("_check(\"空结构回落基线\", empty.all_cards().size() == 337, str(empty.all_cards().size()))",
     "_check(\"空结构回落基线\", empty.all_cards().size() == 344, str(empty.all_cards().size()))"),
])

# ---------- _probe_mod_loader.gd（LF）----------
do(r"tools\_probe_mod_loader.gd", [
    ("##   1. 没有 mod 目录时读到的就是 pck 基线（337 张）",
     "##   1. 没有 mod 目录时读到的就是 pck 基线（344 张）"),
    ("##   2. 单个 mod 新增一张卡 → 338，基线卡不动",
     "##   2. 单个 mod 新增一张卡 → 345，基线卡不动"),
    ("##   3. 两个 mod 各加一张 → 339（**可共存**，谁也不用交出整份 cards.json）",
     "##   3. 两个 mod 各加一张 → 346（**可共存**，谁也不用交出整份 cards.json）"),
    ("##  12. 全部卸载后回到 337",
     "##  12. 全部卸载后回到 344"),
    ("_check(\"基线 337 张\", base_count == 337, str(base_count))",
     "_check(\"基线 344 张\", base_count == 344, str(base_count))"),
    ("_check(\"空 mod 根 = 基线 337\", CardRepo.load_json().all_cards().size() == 337,",
     "_check(\"空 mod 根 = 基线 344\", CardRepo.load_json().all_cards().size() == 344,"),
    ("_check(\"单 mod 加卡后 338\", r2.all_cards().size() == 338, str(r2.all_cards().size()))",
     "_check(\"单 mod 加卡后 345\", r2.all_cards().size() == 345, str(r2.all_cards().size()))"),
    ("_check(\"两个 mod 共存 = 339\", r3.all_cards().size() == 339, str(r3.all_cards().size()))",
     "_check(\"两个 mod 共存 = 346\", r3.all_cards().size() == 346, str(r3.all_cards().size()))"),
    ("_check(\"深合并后总数仍是 339\", r4.all_cards().size() == 339, str(r4.all_cards().size()))",
     "_check(\"深合并后总数仍是 346\", r4.all_cards().size() == 346, str(r4.all_cards().size()))"),
    ("_check(\"坏清单目录被跳过\", r6.all_cards().size() == 339, str(r6.all_cards().size()))",
     "_check(\"坏清单目录被跳过\", r6.all_cards().size() == 346, str(r6.all_cards().size()))"),
    ("_check(\"剔除后总数不变（340 = 337 + A/B/C）\", r8.all_cards().size() == 340, str(r8.all_cards().size()))",
     "_check(\"剔除后总数不变（347 = 344 + A/B/C）\", r8.all_cards().size() == 347, str(r8.all_cards().size()))"),
    ("_check(\"启停：停用前是 340\", before_off == 340, str(before_off))",
     "_check(\"启停：停用前是 347\", before_off == 347, str(before_off))"),
    ("_check(\"停用后总数 339\", r_off.all_cards().size() == 339, str(r_off.all_cards().size()))",
     "_check(\"停用后总数 346\", r_off.all_cards().size() == 346, str(r_off.all_cards().size()))"),
    ("_check(\"重新启用后回到 340\", r_on.all_cards().size() == 340, str(r_on.all_cards().size()))",
     "_check(\"重新启用后回到 347\", r_on.all_cards().size() == 347, str(r_on.all_cards().size()))"),
    ("_check(\"卸载后回到 337\", after.all_cards().size() == 337, str(after.all_cards().size()))",
     "_check(\"卸载后回到 344\", after.all_cards().size() == 344, str(after.all_cards().size()))"),
])

print("=== 全部翻面完成 ===")
