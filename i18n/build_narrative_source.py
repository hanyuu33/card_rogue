# -*- coding: utf-8 -*-
"""R664：从权威中文提取事件 / 剧情底本，并应用已审计的 canonical 修正。"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
OUT = I18N / "narrative_zh_canonical.json"
EVENT_PATH = ROOT / "scripts/event_scene.gd"
STORY_PATH = ROOT / "stories.json"

EVENT_NAMES = {
    "whisper": "鸭鸭低语", "gaze": "鸭之凝视", "pear": "鸭梨山大",
    "apple_doctor": "苹果与医生", "snow_leopard": "雪豹出现",
    "adventurer": "冒险家的遗物", "martial": "武术大师", "flyer": "飞行器",
    "bluefish": "蓝色大肥鱼", "moon": "赏月", "relic_chest": "宝箱层",
    "hero": "绝赞五换一", "arcane": "奥秘之泉", "oblivion": "遗忘之泉",
    "smith": "鸭鸭工匠", "struggle": "挣扎", "delivery": "运送委托",
    "delivery_done": "委托完成", "cave": "洞穴", "card_merchant": "卡片商人",
    "divination": "占卜室", "lake_lady": "湖中仙女", "furnace": "熔炉",
    "core_contract": "契约的核心", "treasure": "卡牌宝箱", "rest": "休息处",
}

CONSTANT_EVENTS = {
    "WHISPER_DESC": "whisper", "WHISPER_TAKEN_DESC": "whisper",
    "GAZE_DESC": "gaze", "GAZE_TAKEN_DESC": "gaze",
    "PEAR_DESC": "pear", "PEAR_TAKEN_DESC": "pear",
    "APPLE_DESC": "apple_doctor", "APPLE_TAKEN_DESC": "apple_doctor",
    "SNOW_DESC": "snow_leopard", "SNOW_CLOSED_DESC": "snow_leopard",
    "SNOW_CHEESE_DESC": "snow_leopard", "ADVENTURER_DESC": "adventurer",
    "ADVENTURER_NOTE_DESC": "adventurer", "ADVENTURER_FLINT_DESC": "adventurer",
    "MARTIAL_DESC": "martial", "MARTIAL_BRAWL_DESC": "martial",
    "MARTIAL_KICK_DESC": "martial", "MARTIAL_PUNCH_DESC": "martial",
    "FLYER_DESC": "flyer", "FLYER_TAKEN_DESC": "flyer",
    "RETIRED_EVENT_DESC": "bluefish", "MOON_DESC": "moon",
    "MOON_TAKEN_DESC": "moon", "COIN_TAKEN_DESC": "moon",
    "CHEST_LAYER_DESC": "relic_chest", "HERO_DESC": "hero",
    "HERO_TAKEN_DESC": "hero", "ARCANE_DESC": "arcane",
    "ARCANE_CHARM_TAKEN_DESC": "arcane", "OBLIVION_DESC": "oblivion",
    "OBLIVION_DONE_DESC": "oblivion", "SMITH_DESC": "smith",
    "SMITH_DONE_DESC": "smith", "STRUGGLE_DESC": "struggle",
    "STRUGGLE_TAKEN_DESC": "struggle", "DELIVERY_DESC": "delivery",
    "DELIVERY_TAKEN_DESC": "delivery", "DELIVERY_DONE_DESC": "delivery_done",
    "CAVE_DESC": "cave", "CAVE_TAKEN_DESC": "cave",
    "MERCHANT_DESC": "card_merchant", "MERCHANT_DONE_DESC": "card_merchant",
    "DIVINATION_DESC": "divination", "DIVINATION_DONE_DESC": "divination",
    "DIV_WHALE_DESC": "divination", "DIV_LIQUID_DESC": "divination",
    "DIV_THORN_DESC": "divination", "DIV_FEAST_DESC": "divination",
    "LAKE_DESC": "lake_lady", "LAKE_DONE_DESC": "lake_lady",
    "FURNACE_DESC": "furnace", "FURNACE_DONE_DESC": "furnace",
    "CORE_DESC": "core_contract", "CORE_CONTRACT_DESC": "core_contract",
    "CORE_TAKEN_DESC": "core_contract",
}

# _rest_desc() 与宝箱结果页不是常量，但同样是玩家可见正文，必须纳入覆盖。
INLINE_TEXTS = {
    "rest": {
        "REST_DESC": "前路的战斗还在等着你。\n在篝火旁休息，恢复 %d%% 最大生命；\n也可以烤一块肉带在身上，留到 Boss 战前享用；\n还可以往火里添一根柴，让火替你烧掉卡组里的一张牌。\n（三样只能挑一样——选完这一处就到头了。）",
        "REST_SACRAMENT_DESC": "篝火旁摆着一份还没凉透的圣餐。\n你在坐下之前就把它分掉了——到达篝火处回复 50% 最大生命（已结算）；\n也可以烤一块肉带在身上，留到 Boss 战前享用；\n还可以往火里添一根柴，让火替你烧掉卡组里的一张牌。\n（剩下两样只能挑一样——选完这一处就到头了。）",
    },
    "treasure": {
        "TREASURE_DESC": "路旁放着一只落满灰尘的宝箱……\n不需要付出任何代价。也可以转身离开，分文不取。",
        "TREASURE_OPENED_DESC": "箱盖掀开，里面是一叠卡牌……\n请在上面的奖励悬浮窗里查看并挑走一张。",
    },
    "relic_chest": {
        "RELIC_CHEST_OPENED_DESC": "箱盖吱呀一声打开——里面躺着一件道具。\n「%s」已放进待领奖励，请在上面弹出的奖励悬浮窗里查看。",
        "RELIC_CHEST_EMPTY_DESC": "箱底只剩一层灰——奖励道具你已经全都拿到了。",
    },
}

# 只修正明确的术语 / 现行规则漂移；文学表达与数值不擅自重写。
CANONICAL_OVERRIDES = {
    "WHISPER_DESC": "深处的鸭鸣在你耳畔回荡，绕梁不散……\n获得「鸭之低语」：你将不再能控制自己接下来的前进方向\n（每一步都由系统随机决定）；\n但每个我方回合开始时，你会随机获得一种强化——\n本回合费用 +1 / 我方单位攻击与技能伤害 +1 / 本回合多抽 1 张卡。",
    "GAZE_DESC": "一只巨大的鸭眼自虚空中睁开，死死盯着你。\n它不说话，只是看着——看得你后背发凉，手里莫名多了一袋米。\n获得「一袋米抗几楼」：每回合第一次我方生命受到伤害后，抽 1 张卡，\n且本回合内你的技能造成的伤害 +1。\n也可以别过头去，假装没看见。",
    "APPLE_DESC": "路边坐着一位医生，膝上摊着一本病历，抬头看了你一眼：\n「拿个苹果走吧。吃了它，就别再来找我。」\n获得「苹果」：最大生命 +7，并回复至最大生命。\n也可以什么也不接，转身离开——只是路上别再回头。",
    "PEAR_TAKEN_DESC": "肩上那座鸭梨山，你已经背起来了。\n往后每一次受伤，都会让你更「强大」一点——\n只是那点强大，补不回已经失去的生命。",
    "HERO_DESC": "一块巨大的告示牌立在路中央，上面龙飞凤舞地写着五个大字：绝赞五换一！\n交出卡组里 5 张「不同名」的卡（随机挑 5 种，每种各 1 张），\n就能换回一位「英雄」——5 费 5 力量 25 生命，只是它上场时，\n你必须额外丢弃 4 张手牌作为代价。\n卡组里凑不出 5 种不同的卡时，这笔买卖做不成，只能转身离开。",
    "DELIVERY_DESC": "驿站门口堆着一批贴了封条的货箱，脚夫收了钱就不见了人影。\n选择承运：平铺挑 1~6 张「货物」加入卡组（3 费工事，0 力量 / 6 生命，替你承受伤害）；\n货物被破坏时会从卡组中删除——毁了就真的毁了。\n带着货物走进第二层，第一个事件房的货主会按张兑付报酬，接得越多兑得越多；\n兑付完成后这些货物会被货主收走（同样从卡组里删除）。\n也可以不接，转身离开。",
}


def main():
    source = EVENT_PATH.read_text(encoding="utf-8-sig")
    constants = dict(re.findall(r'^const\s+([A-Z0-9_]+)\s*:=\s*"""(.*?)"""', source, re.M | re.S))
    assert set(constants) == set(CONSTANT_EVENTS), (
        "事件常量覆盖漂移", sorted(set(constants) - set(CONSTANT_EVENTS)),
        sorted(set(CONSTANT_EVENTS) - set(constants)))
    events = {}
    for key, event_key in CONSTANT_EVENTS.items():
        row = events.setdefault(event_key, {"name": EVENT_NAMES[event_key], "texts": {}})
        row["texts"][key] = CANONICAL_OVERRIDES.get(key, constants[key])
    for event_key, texts in INLINE_TEXTS.items():
        row = events.setdefault(event_key, {"name": EVENT_NAMES[event_key], "texts": {}})
        row["texts"].update(texts)
    assert set(events) == set(EVENT_NAMES)
    assert sum(len(row["texts"]) for row in events.values()) == 61

    story_source = json.loads(STORY_PATH.read_text(encoding="utf-8-sig"))
    stories = {}
    for entry in story_source["episodes"] + story_source["profiles"]:
        stories[entry["id"]] = {
            "chapter": entry["chapter"], "title": entry["title"], "text": entry["text"],
        }
    achievements = {
        entry["id"]: {"name": entry["name"], "hint": entry["hint"]}
        for entry in story_source["achievements"]
    }
    assert len(stories) == 11 and sum(len(x["text"]) for x in stories.values()) == 54
    assert len(achievements) == 11

    data = {
        "version": 1,
        "updated": "2026-11-13",
        "purpose": "R664 事件、剧情与剧情成就提示的英日翻译底本。event_scene.gd 与 stories.json 权威中文不动。",
        "rules": [
            "保留短句白描与台词边界，不新增剧情、不删改条件或奖励。",
            "卡名、道具名、角色名、关卡名与专名必须复用 glossary.json / cards_*.json / noncard_*.json。",
            "统一使用手牌、卡组、抽牌堆、弃牌区、力量、生命、最大生命；删除与消失不得混用。",
            "动态占位符 %s / %d / %% 必须逐类保留；英文与日文不得改动程序字段。",
            "canonical 只修正已核实的术语与规则漂移，不把实现异常翻译成规则。",
        ],
        "canonical_overrides": sorted(CANONICAL_OVERRIDES),
        "events": events,
        "stories": stories,
        "achievements": achievements,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("wrote", OUT.name, "events", len(events), "event texts",
          sum(len(x["texts"]) for x in events.values()), "stories", len(stories),
          "story lines", sum(len(x["text"]) for x in stories.values()),
          "achievements", len(achievements))


if __name__ == "__main__":
    main()
