# -*- coding: utf-8 -*-
"""R835 测试翻面：道具总数 83→84、一层初始池 11→12。

都是「新增一件初始道具」的必然连锁 —— 断言本身没变，只是被写死的数字。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
P = "scripts/test_engine.gd"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def rep(old, new, n=1):
    s = read(P)
    c = s.count(old)
    if c != n:
        print("!! count=%d 期望 %d\n   %r" % (c, n, old[:120]))
        sys.exit(1)
    io.open(ROOT + P, "w", encoding="utf-8", newline="").write(s.replace(old, new, n))
    print("ok  %r..." % old[:56].replace("\r", "\\r"))


# ── 初始池 11 → 12（两处）──────────────────────────────────────────────
rep('\tcheck(relic_repo.initial_ids().size() == 11 and relic_repo.get_relic(6001) != null\r\n',
    '\tcheck(relic_repo.initial_ids().size() == 12 and relic_repo.get_relic(6001) != null\r\n')
rep('"道具库：11 个初始道具全部加载（+ 栅栏修复术 6021 / 行囊 6030 / 勇气徽章 6031 / 陶罐 6032 / R341 惊奇盒子 6047 · 洞窟绳 6048 / R745 工具箱 6068 / R830 首饰盒 6088）")',
    '"道具库：12 个初始道具全部加载（+ 栅栏修复术 6021 / 行囊 6030 / 勇气徽章 6031 / 陶罐 6032 / R341 惊奇盒子 6047 · 洞窟绳 6048 / R745 工具箱 6068 / R830 首饰盒 6088 / R835 空故事书 6089）")')

rep('\tcheck(r244_init.size() == 11 and r244_init.has(6030) and not r244_init.has(6003),\r\n',
    '\tcheck(r244_init.size() == 12 and r244_init.has(6030) and not r244_init.has(6003),\r\n')
rep('"R244 初始道具池：移除鸡煲 6003、加入行囊 6030（R830 后共 11 个）")',
    '"R244 初始道具池：移除鸡煲 6003、加入行囊 6030（R835 后共 12 个）")')

rep('\tcheck(r245_init.size() == 11 and r245_init.has(6031) and r245_init.has(6032),\r\n',
    '\tcheck(r245_init.size() == 12 and r245_init.has(6031) and r245_init.has(6032),\r\n')

# ── 道具总数 83 → 84（三处）────────────────────────────────────────────
rep('"R577b 保真锁：83 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087 / R830 +首饰盒 6088）")',
    '"R577b 保真锁：84 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087 / R830 +首饰盒 6088 / R835 +空故事书 6089）")')

rep('\tcheck(r810_repo.all_relics().size() == 83, "R824 数据层：道具总数 83 件（+鸭子闹钟 6085 / R826 音乐盒 6086 / R829 这是礼帽 6087 / R830 首饰盒 6088）")',
    '\tcheck(r810_repo.all_relics().size() == 84, "R824 数据层：道具总数 84 件（+鸭子闹钟 6085 / R826 音乐盒 6086 / R829 这是礼帽 6087 / R830 首饰盒 6088 / R835 空故事书 6089）")')

rep('\tcheck(r834_demo_all == 83,\r\n',
    '\tcheck(r834_demo_all == 84,\r\n')
rep('"R829 试玩版：demo 下 all_relics 仍是 83（道具档「全部登陆」）")',
    '"R829 试玩版：demo 下 all_relics 仍是 84（道具档「全部登陆」）")')

print("\n全部通过")
