# -*- coding: utf-8 -*-
"""R794b：从 HEAD 版 test_engine.gd 重建「只含本轮断言」的干净副本。

工作区那份 test_engine.gd 里混着并行线 5 个 hunk（R289 卡牌数 29 / R792 测试函数 +121 行 /
工具池 / 刺墙等）。这里只用**本轮的 10 处替换**在 HEAD 版本上重放，产出干净 blob。
"""
import io
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
CLEAN = "E:/tmp/r794b_test_engine_clean.gd"

s = subprocess.run(["git", "-C", ROOT, "show", "HEAD:scripts/test_engine.gd"],
                   capture_output=True, check=True).stdout.decode("utf-8")
s = s.replace("\r\n", "\n")          # CRLF 规范成 LF，写回时再转回来

R794_BLOCK = (
    "\t# ---- R794b：难度 12「昂贵」—— 商店商品售价 +40%（信物除外）----\n"
    "\tvar r794_shop := FileAccess.get_file_as_string(\"res://scripts/shop_scene.gd\").replace(\"\\r\\n\", \"\\n\")\n"
    "\n"
    "\tcheck(RunState.DIFF_SHOP_PRICE_FROM == 12 and RunState.DIFF_SHOP_PRICE_MUL == 1.4,\n"
    "\t\t\t\"R794b 商店涨价的档位与倍率口径（12 档起 ×1.4）\")\n"
    "\n"
    "\tRunState.set_difficulty(11)\n"
    "\n"
    "\tcheck(RunState.shop_price_mul() == 1.0 and RunState.shop_price_mul(true) == 1.0,\n"
    "\t\t\t\"R794b 难度 11 及以下商店不加价（信物一律不加）\")\n"
    "\n"
    "\tRunState.set_difficulty(12)\n"
    "\n"
    "\tcheck(RunState.difficulty_name() == \"昂贵\" and RunState.shop_price_mul() == 1.4\n"
    "\t\t\tand RunState.shop_price_mul(true) == 1.0\n"
    "\t\t\tand RunState.difficulty_note().contains(\"40%\"),\n"
    "\t\t\t\"R794b 难度 12 = 昂贵：非信物 ×1.4 / 信物 ×1.0（%s）\" % RunState.difficulty_note())\n"
    "\n"
    "\tcheck(RunState.difficulty_summary().contains(\"商店 ×1.4\"),\n"
    "\t\t\t\"R794b 数值摘要列出「商店 ×1.4」（%s）\" % RunState.difficulty_summary())\n"
    "\n"
    "\tcheck_src(r794_shop.find(\"func _shelf_price(\") >= 0\n"
    "\t\t\tand r794_shop.find(\"_pay(int(t.price))\") < 0\n"
    "\t\t\tand r794_shop.find(\"var price: int = e[\\\"price\\\"]\") < 0\n"
    "\t\t\tand r794_shop.find(\"var price: int = ench[\\\"price\\\"]\") < 0\n"
    "\t\t\tand r794_shop.find(\"var del_price: int = _row3[0][\\\"price\\\"]\") < 0,\n"
    "\t\t\t\"R794b 商店售价只走 _shelf_price()：陷阱 / 服务 / 附魔 / 删卡都不再直读原价\")\n"
    "\n"
)

pairs = [
    ("and RunState.DIFFICULTY_NAMES.size() == 12,",
     "and RunState.DIFFICULTY_NAMES.size() == 13,", "NAMES.size"),
    ('"难度 10 = 噩梦；档位名共 12 个（%s）"',
     '"难度 10 = 噩梦；档位名共 13 个（%s）"', "NAMES 文案"),
    ('check(RunState.difficulty == 11, "难度档位：越界输入被钳制到 11")',
     'check(RunState.difficulty == 12, "难度档位：越界输入被钳制到 12")', "越界钳制"),
    ("check(RunState.DIFFICULTY_COUNT == 12 and RunState.DIFFICULTY_BATTLE_HEAL.size() == 12",
     "check(RunState.DIFFICULTY_COUNT == 13 and RunState.DIFFICULTY_BATTLE_HEAL.size() == 13", "COUNT"),
    ("and RunState.DIFFICULTY_REST_PCT.size() == 12",
     "and RunState.DIFFICULTY_REST_PCT.size() == 13", "REST_PCT"),
    ("and RunState.DIFFICULTY_TEXTS.size() == 12",
     "and RunState.DIFFICULTY_TEXTS.size() == 13", "TEXTS"),
    ('"难度档位：共 12 档；战斗胜利回血恒 0 / 篝火 40%%(0档)·25%%(1档起)（R237 恢复）")',
     '"难度档位：共 13 档；战斗胜利回血恒 0 / 篝火 40%%(0档)·25%%(1档起)（R237 恢复）")', "档数文案"),
    ("check(SteamAchievements.APEX_DIFF == 11,",
     "check(SteamAchievements.APEX_DIFF == 12,", "APEX"),
    ('"R740 巅峰成就门槛 = 难度 11（0~11 共 12 档的最高档）")',
     '"R740 巅峰成就门槛 = 难度 12（0~12 共 13 档的最高档）")', "APEX 文案"),
    ("\tRunState.set_difficulty(99)\n",
     R794_BLOCK + "\tRunState.set_difficulty(99)\n", "插入断言块"),
]

for old, new, tag in pairs:
    n = s.count(old)
    if n != 1:
        print("!! %s 命中 %d 次" % (tag, n))
        sys.exit(1)
    s = s.replace(old, new, 1)

io.open(CLEAN, "wb").write(s.replace("\n", "\r\n").encode("utf-8"))
print("write %s" % CLEAN)
print("--- 干净版 vs 工作区（应只剩并行线那几个 hunk）---")
subprocess.run(["git", "-C", ROOT, "diff", "--no-index", "--stat",
                CLEAN, ROOT + "scripts/test_engine.gd"])
