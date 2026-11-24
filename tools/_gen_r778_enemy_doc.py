# -*- coding: utf-8 -*-
"""R778：把 _r778_levels.txt（godot dump）渲染成 Markdown 怪物配置总表。"""
import io
import json

ROOT = "E:/work/card_rogue/"
cards = {int(c["id"]): c for c in json.load(io.open(ROOT + "cards.json", encoding="utf-8"))["cards"]}


def card_name(i):
    c = cards.get(int(i))
    return "%s(%d)" % (c["name"], int(i)) if c else "?(%d)" % int(i)


def card_eff(i, limit=None):
    c = cards.get(int(i))
    if not c:
        return ""
    t = (c.get("effect_text") or "").replace("\n", " ").replace("**", "")
    t = " ".join(t.split())
    if limit and len(t) > limit:
        t = t[:limit] + "…"
    return t


levels = []
cur = None
for line in io.open(ROOT + "_r778_levels.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("LVL\t"):
        p = line.split("\t")
        cur = {"key": p[1], "name": p[2], "tier": p[3], "layer": p[4],
               "pp": p[5], "ehp": p[6], "misc": p[7:], "units": []}
        levels.append(cur)
    elif line.startswith("  UNIT\t") and cur is not None:
        p = line.split("\t")
        cur["units"].append({"id": int(p[1]), "name": p[2], "atk": int(p[3]),
                             "hp": int(p[4]), "rng": int(p[5]), "mv": int(p[6]), "cell": p[7]})

units = []
for line in io.open(ROOT + "_r778_levels.txt", encoding="utf-8"):
    if line.startswith("UNIT\t"):
        p = line.rstrip("\n").split("\t")
        units.append({"id": int(p[1]), "name": p[2], "atk": int(p[3]),
                      "hp": int(p[4]), "rng": int(p[5]), "mv": int(p[6]), "lvls": p[7].split(",")})

out = []
w = out.append

w("# 怪物配置总表（R778 快照）")
w("")
w("数据源：`scripts/game_levels.gd` 的 `enemy_units`（每项格式 `[id, 名字, 攻, 血, 程, 移, 格]`）"
  "＋ `cards.json` 的卡面（特性 / 效果文本）。")
w("")
w("**读法**")
w("")
w("- 「攻 / 血 / 程 / 移」是**入场实际值**（关卡数据），不是卡面值 —— 两者有差的会在第四节单独列出。")
w("- 「格」是 `(列, 行)`：列 0~2 是横向三列，行 0 = 敌方最深排、行 2 = 敌方前排（战场 3 列 × 6 行，前 3 行归敌方：`FieldState.OPPONENT_ROWS = 3`）。")
w("- 敌方总血条 = `enemy_hp_of()` =（关卡 enemy_hp + 精英 10 / Boss 20）× 2。")
w("")
w("统计：**%d 个战斗关卡**（含 1 个事件专属洞穴）、**%d 种怪物 id**。"
  % (len(levels), len(units)))
w("")

# ---- 一、按分级 ----
w("## 一、按分级 → 关卡 → 敌人")
w("")
order = ["普通敌人-简单", "普通敌人-困难", "精英敌人-简单", "精英敌人-困难", "Boss"]
for tier in order:
    grp = [l for l in levels if l["tier"] == tier]
    w("### %s（%d 关）" % (tier, len(grp)))
    w("")
    w("| 关卡 key | 关卡名 | 层 | 敌方血条 | 关卡效果卡 | 敌人（攻/血/程/移@格） |")
    w("|---|---|---|---|---|---|")
    for l in grp:
        eff = l["misc"][4].replace("effects=", "")
        eff = eff.strip("[]")
        effs = ", ".join(card_name(x) for x in eff.split(",") if x) if eff else "—"
        # 启示者：关卡表只登记第一阶段的舰炮，9202 / 9203 由引擎在转阶段时换上，
        # 只按表渲染会以为「只有一张效果卡」。这里把三段都写出来。
        if l["key"] == "boss_revelator":
            effs = " → ".join(card_name(k) for k in (9201, 9202, 9203))
        us = "<br>".join("%s %d(%d/%d/%d/%d@%s)" % (u["name"], u["id"], u["atk"], u["hp"],
                                                    u["rng"], u["mv"], u["cell"]) for u in l["units"])
        w("| `%s` | %s | %s | %s | %s | %s |" % (l["key"], l["name"], l["layer"],
                                                 l["ehp"].replace("ehp=", "").split("(")[0], effs, us))
    w("")

# ---- 二、按 id ----
w("## 二、按怪物 id（%d 种）" % len(units))
w("")
w("| id | 名字 | 攻 | 血 | 程 | 移 | 特性 | 效果 | 出场关卡 |")
w("|---|---|---|---|---|---|---|---|---|")
for u in sorted(units, key=lambda x: x["id"]):
    c = cards.get(u["id"], {})
    traits = "/".join(c.get("traits") or []) or "—"
    w("| %d | %s | %d | %d | %d | %d | %s | %s | %s |" % (
        u["id"], u["name"], u["atk"], u["hp"], u["rng"], u["mv"], traits,
        card_eff(u["id"], 110) or "—", "、".join(u["lvls"])))
w("")

# ---- 三、关卡通用参数 ----
w("## 三、关卡通用参数")
w("")
pp = sorted({l["pp"] for l in levels})
misc = sorted({tuple(l["misc"][0:4]) for l in levels})
w("- 玩家 HP：%s（全部关卡一致）" % "、".join(p.replace("pp=", "") for p in pp))
w("- 回合上限 / 洗牌 / 敌方 AI / 起手手牌：%s" % "、".join(str(m) for m in misc))
w("- 敌方总血条分布：%s" % "、".join(sorted({l["ehp"] for l in levels})))
w("")

# ---- 四、关卡值 vs 卡面值 ----
w("## 四、同一怪物在不同关卡里的入场值差异")
w("")
w("| id | 名字 | 入场值变体 → 出现关卡 |")
w("|---|---|---|")
vary = 0
for u in units:
    pass
var_map = {}
for l in levels:
    for u in l["units"]:
        sig = (u["atk"], u["hp"], u["rng"], u["mv"])
        var_map.setdefault(u["id"], {})
        var_map[u["id"]].setdefault(sig, [])
        if l["key"] not in var_map[u["id"]][sig]:
            var_map[u["id"]][sig].append(l["key"])
for uid in sorted(var_map):
    if len(var_map[uid]) <= 1:
        continue
    vary += 1
    nm = next(u["name"] for u in units if u["id"] == uid)
    vs = "<br>".join("%d/%d/%d/%d → %s" % (k[0], k[1], k[2], k[3], "、".join(v))
                     for k, v in var_map[uid].items())
    w("| %d | %s | %s |" % (uid, nm, vs))
w("")
w("共 %d 种怪物存在多套入场值（其余全部关卡一致）。" % vary)
w("")
w("## 五、入场值与卡面值不一致的怪物")
w("")
w("| id | 名字 | 入场 攻/血/程/移 | 卡面 攻/血/程/移 |")
w("|---|---|---|---|")
diff = 0
seen = set()
for u in units:
    if u["id"] in seen:
        continue
    seen.add(u["id"])
    c = cards.get(u["id"])
    if not c:
        continue
    a = (u["atk"], u["hp"], u["rng"], u["mv"])
    b = (int(c.get("power", 0)), int(c.get("health", 0)),
         int(c.get("attack_range", 0)), int(c.get("move_speed", 0)))
    if a != b:
        diff += 1
        w("| %d | %s | %d/%d/%d/%d | %d/%d/%d/%d |" % (u["id"], u["name"], a[0], a[1], a[2], a[3],
                                                      b[0], b[1], b[2], b[3]))
w("")
if diff == 0:
    w("**%d 种全部与卡面一致**，没有任何关卡覆盖入场值。" % len(seen))
else:
    w("共 %d 种不一致（其余 %d 种入场值与卡面一致）。" % (diff, len(seen) - diff))

w("")
w("## 附：启示者（`boss_revelator`）三阶段")
w("")
w("关卡表 `enemy_effects` 只登记第一阶段的「舰炮 9201」；9202 / 9203 由")
w("`GameEngine._revelator_enter_phase()` 在血量落到 2/3、1/3 时换上，**不进关卡表** ——")
w("只看表格会以为「Boss 只有一张效果卡」。")
w("")
w("| 阶段 | 效果卡 | 移速 | 攻击距离 | 每回合行动 |")
w("|---|---|---|---|---|")
w("| 1 | 舰炮 9201 | 2 | 2 | 1 |")
w("| 2 | 电磁屏障 9202 | 1 | 2 | 2 |")
w("| 3 | 紧急呼叫 9203 | 0 | 4 | 2 |")
w("")
w("血量 300，阶段血线 = 最大生命的 2/3、1/3（200 / 100），唯一口 `GameEngine.revelator_gate_hp()`；")
w("阶段 1 另有「每回合力量 +1」（`_revelator_grow()`）。")

io.open(ROOT + "_preview/r778_enemy_config.md", "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("WROTE", len(out), "lines; levels=%d units=%d diff=%d" % (len(levels), len(units), diff))
