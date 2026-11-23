# -*- coding: utf-8 -*-
"""R852：重写 test_engine 的 R380 段（10 档「?」房恢复刷商店，代价从战斗/事件/宝箱扣）。"""
import io, os

ROOT = r"E:\work\card_rogue"
p = os.path.join(ROOT, r"scripts\test_engine.gd")
with io.open(p, "r", encoding="utf-8", newline="") as f:
    s = f.read()
assert "\r\n" in s, "test_engine 应为 CRLF"

# ---------- ① 难度表注释（20548 附近）----------
old = "\t# 10 = 精英出现增多（R380：「?」房不再刷商店 + 明房 / 「?」房精英出现概率 ×1.3）。".replace("\n", "\r\n")
new = ("\t# 10 = 精英出现增多（R380 / R852：明房 / 「?」房精英出现概率 ×1.3；R852 起「?」房照旧刷商店，\r\n"
       "\t#      加权代价只从战斗 / 事件 / 宝箱扣，商店占比不变）。")
assert s.count(old) == 1, "难度表注释 %d 处" % s.count(old)
s = s.replace(old, new)

# ---------- ② 整段替换 R380 段 ----------
mark = "\t# ================= R380：难度 10「精英出现增多」 ================="
i = s.index(mark)
j = s.index("\tRunState.set_difficulty(0)", i)
blk = s[i:j]
assert "r380_bad3" in blk and "unknown_shop_allowed" in blk and len(blk) < 5000, "定位失败 len=%d" % len(blk)

NEW = """\t# ================= R380 / R852：难度 10「精英出现增多」 =================
\t# 用户口径（R380）：「当前难度 10 还没有新增效果，做成精英出现增多 —— 各种途径出现
\t#   精英的概率上调约 30%」。
\t# R852（用户口径）：「10 难度起，? 依旧需要刷新商店。概率从事件，普通战斗，宝箱里面扣」
\t#   → 原「10 档「?」房裁掉 shop」撤销；精英 +30% 多出来的权重只从 battle / event / chest
\t#     扣，**shop 一分不扣**（商店占比与低难度逐位相同）。

\t# ① 常量 + 取值函数（界面 / 地图生成 / 测试唯一口）
\tcheck(RunState.DIFF_ELITE_FROM == 10 and is_equal_approx(RunState.DIFF_ELITE_MUL, 1.3),
\t\t\t"R380 常量：10 档起精英出现概率 ×1.3（约 +30%）")
\tRunState.set_difficulty(9)
\tcheck(RunState.elite_weight_mul() == 1.0,
\t\t\t"R380 难度 9：精英概率不动（只 10 档变）")
\tRunState.set_difficulty(10)
\tcheck(is_equal_approx(RunState.elite_weight_mul(), 1.3),
\t\t\t"R380 难度 10：精英概率 ×1.3")
\tcheck(RogueMap.WEIGHTS_UNKNOWN.has("shop"),
\t\t\t"R852 「?」房权重表：商店键恒在（10 档不再裁 shop）")

\t# ② 权重占比对拍：直接采 `_weighted_far`（col 3 / row 2 + norm 1.0 → 距离系数恰为 1）
\tvar r852_shares := {}
\tfor r852_d in 2:
\t\tRunState.set_difficulty(0 if r852_d == 0 else 10)
\t\tvar r852_rng := RandomNumberGenerator.new()
\t\tr852_rng.seed = 852000 + r852_d
\t\tvar r852_cnt := {"battle": 0, "event": 0, "elite": 0, "chest": 0, "shop": 0}
\t\tvar r852_n := 40000
\t\tfor r852_t in r852_n:
\t\t\tvar r852_got := RogueMap._weighted_far(RogueMap.WEIGHTS_UNKNOWN, r852_rng, 3, 2, 1.0)
\t\t\tr852_cnt[r852_got] = int(r852_cnt[r852_got]) + 1
\t\tvar r852_sh := {}
\t\tfor r852_k in r852_cnt:
\t\t\tr852_sh[r852_k] = 100.0 * float(r852_cnt[r852_k]) / float(r852_n)
\t\tr852_shares[r852_d] = r852_sh
\tvar r852_s0: Dictionary = r852_shares[0]
\tvar r852_s1: Dictionary = r852_shares[1]
\tcheck(absf(float(r852_s1["shop"]) - float(r852_s0["shop"])) < 0.4,
\t\t\t"R852 10 档「?」房商店占比 = 0 档（%.2f%% vs %.2f%%）"
\t\t\t% [float(r852_s1["shop"]), float(r852_s0["shop"])])
\tvar r852_er: float = float(r852_s1["elite"]) / maxf(0.01, float(r852_s0["elite"]))
\tcheck(r852_er > 1.25 and r852_er < 1.35,
\t\t\t"R852 10 档「?」房精英占比 ≈ ×1.3（%.2f%% → %.2f%%，比值 %.3f）"
\t\t\t% [float(r852_s0["elite"]), float(r852_s1["elite"]), r852_er])
\tvar r852_pool0: float = float(r852_s0["battle"]) + float(r852_s0["event"]) + float(r852_s0["chest"])
\tvar r852_pool1: float = float(r852_s1["battle"]) + float(r852_s1["event"]) + float(r852_s1["chest"])
\tcheck(r852_pool1 < r852_pool0 - 1.0,
\t\t\t"R852 代价只从战斗 / 事件 / 宝箱扣（三类合计 %.2f%% → %.2f%%）" % [r852_pool0, r852_pool1])

\t# ③ 实测对拍：同一批种子分别按 0 档 / 10 档生成
\tvar r380_elite := [0, 0]        # [0 档, 10 档] 精英格总数
\tvar r380_qshop := [0, 0]        # 「?」房刷出来的商店格数
\tvar r380_shop := [0, 0]         # 全部商店格数（含保底）
\tvar r380_maps := [0, 0]
\tfor r380_layer: int in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
\t\tfor r380_k in 120:
\t\t\tfor r380_d in 2:
\t\t\t\tRunState.set_difficulty(0 if r380_d == 0 else 10)
\t\t\t\tvar r380_rng := RandomNumberGenerator.new()
\t\t\t\tr380_rng.seed = 380000 + r380_k * 17 + r380_layer
\t\t\t\tvar r380_map: Array = RogueMap.generate(r380_rng, r380_layer)
\t\t\t\tvar r380_ns := 0
\t\t\t\tfor r380_c: Dictionary in r380_map:
\t\t\t\t\tif RogueMap.is_void(r380_c):
\t\t\t\t\t\tcontinue
\t\t\t\t\tvar r380_t := str(r380_c.get("type", ""))
\t\t\t\t\tif r380_t == "elite":
\t\t\t\t\t\tr380_elite[r380_d] += 1
\t\t\t\t\telif r380_t == "shop":
\t\t\t\t\t\tr380_ns += 1
\t\t\t\t\t\tif bool(r380_c.get("hidden", false)):
\t\t\t\t\t\t\tr380_qshop[r380_d] += 1
\t\t\t\tr380_maps[r380_d] += 1
\t\t\t\tr380_shop[r380_d] += r380_ns
\tvar r380_ratio: float = float(r380_elite[1]) / maxf(1.0, float(r380_elite[0]))
\tcheck(r380_ratio > 1.15 and r380_ratio < 1.45,
\t\t\t"R380 实测 %d 张图：10 档精英格 / 0 档 = %.2f（用户口径约 +30%%）"
\t\t\t% [r380_maps[0] + r380_maps[1], r380_ratio])
\tcheck(r380_qshop[1] > 0 and r380_qshop[0] > 0,
\t\t\t"R852 实测：10 档「?」房照旧刷商店（%d 间 vs 0 档 %d 间）"
\t\t\t% [r380_qshop[1], r380_qshop[0]])
\tvar r380_avg0: float = float(r380_shop[0]) / float(maxi(1, r380_maps[0]))
\tvar r380_avg1: float = float(r380_shop[1]) / float(maxi(1, r380_maps[1]))
\tcheck(absf(r380_avg1 - r380_avg0) < 0.5,
\t\t\t"R852 实测：10 档每层商店数 = 0 档（%.2f vs %.2f 间）" % [r380_avg1, r380_avg0])

\t# ④ 源码锁：难度口径必须从 RunState 读，别在 rogue_map 里写死 1.3
\tvar r380_src := FileAccess.get_file_as_string("res://scripts/rogue_map.gd")
\tcheck_src(r380_src.find("RunState.elite_weight_mul()") >= 0
\t\t\tand r380_src.find("str(k) == \\"shop\\"") >= 0,
\t\t\t"R852 源码：精英概率读 RunState 唯一口，「?」表对 shop 单列豁免")

"""
NEW = NEW.replace("\r\n", "\n").replace("\n", "\r\n")
s = s[:i] + NEW + s[j:]

with io.open(p, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("test_engine.gd OK, 段长 %d -> %d" % (len(blk), len(NEW)))
