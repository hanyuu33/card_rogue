# -*- coding: utf-8 -*-
"""补齐卡库特性（traits）的英日译名。

背景：GameI18n.source() 最后由 glossary.json 兜底；es/ja 都有 _lang_chain
回落到 en，所以**只要 en 补上，三语都不会再露出中文特性名**。
本表覆盖 2026-11-18 探针实测的 76 条英文缺口，并同步给出日文。

python tools/_i18n_add_traits.py        # 写入
python tools/_i18n_add_traits.py --check # 只看哪些还没登记
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
G = ROOT / "i18n" / "glossary.json"

# 中文特性: (English, 日本語)
TERMS = {
    "传承": ("Legacy", "伝承"),
    "伤害转移": ("Damage Transfer", "ダメージ転移"),
    "兔": ("Rabbit", "兎"),
    "冰霜": ("Frost", "氷霜"),
    "加护": ("Blessing", "加護"),
    "协同": ("Synergy", "シナジー"),
    "发条": ("Clockwork", "発条"),
    "号令": ("Command", "号令"),
    "咏唱者": ("Chanter", "詠唱者"),
    "增量": ("Increment", "増量"),
    "复仇": ("Revenge", "復讐"),
    "奥术": ("Arcane", "奥術"),
    "奥秘": ("Mystery", "奥秘"),
    "寒霜": ("Chill", "寒霜"),
    "巨炮": ("Cannon", "巨砲"),
    "废铁": ("Scrap", "スクラップ"),
    "弓手": ("Archer", "弓手"),
    "恶魔召唤": ("Demon Summon", "悪魔召喚"),
    "成长": ("Growth", "成長"),
    "扑击": ("Pounce", "飛びかかり"),
    "执法": ("Enforcement", "執行"),
    "折射": ("Refraction", "屈折"),
    "护甲积攒": ("Armor Gain", "装甲蓄積"),
    "拾荒": ("Scavenge", "スカベンジ"),
    "持续改造": ("Persistent Upgrade", "永続改造"),
    "改造供能": ("Upgrade Charge", "改造チャージ"),
    "改造层数": ("Upgrade Stacks", "改造スタック"),
    "改造抽牌": ("Upgrade Draw", "改造ドロー"),
    "改造攻程": ("Upgrade Range", "改造射程"),
    "改造生命层": ("Upgrade Health Stacks", "改造HPスタック"),
    "施法者": ("Caster", "術者"),
    "暗影领主": ("Shadow Lord", "暗影の領主"),
    "暗杀": ("Assassinate", "暗殺"),
    "暗杀召唤": ("Assassin Summon", "暗殺召喚"),
    "机械成长": ("Mech Growth", "機械成長"),
    "枭熊本能": ("Owlbear Instinct", "オウルベア本能"),
    "模仿改造": ("Mimic Upgrade", "模倣改造"),
    "治疗": ("Healing", "治療"),
    "测量": ("Survey", "測量"),
    "激光炮": ("Laser Cannon", "レーザー砲"),
    "炮击": ("Bombard", "砲撃"),
    "爆炎": ("Flame Burst", "爆炎"),
    "犬": ("Hound", "犬"),
    "狐": ("Fox", "狐"),
    "狼": ("Wolf", "狼"),
    "猫": ("Cat", "猫"),
    "百眼": ("Hundred Eyes", "百眼"),
    "祭坛": ("Altar", "祭壇"),
    "穿行": ("Phasing", "すり抜け"),
    "精进": ("Mastery", "精進"),
    "自主改造": ("Self Upgrade", "自律改造"),
    "自我复制": ("Self-Copy", "自己複製"),
    "范围": ("Area", "範囲"),
    "虎": ("Tiger", "虎"),
    "行动力成长": ("Mobility Growth", "行動力成長"),
    "装配": ("Equip", "装備"),
    "计算": ("Compute", "計算"),
    "迅捷": ("Swift", "迅速"),
    "远程": ("Ranged", "遠隔"),
    "通缉": ("Wanted", "指名手配"),
    "野性": ("Feral", "野生"),
    "量产护甲": ("Mass Armor", "量産装甲"),
    "量产锻造": ("Mass Forge", "量産鍛造"),
    "闪电": ("Lightning", "雷"),
    "队长": ("Captain", "隊長"),
    "阵亡双动": ("On-Death: Double Action", "死亡時二動"),
    "阵亡机动": ("On-Death: Maneuver", "死亡時機動"),
    "阵亡猎杀": ("On-Death: Hunt", "死亡時狩猟"),
    "陶瓷": ("Ceramic", "セラミック"),
    "集束": ("Cluster", "クラスター"),
    "风": ("Wind", "風"),
    "风暴": ("Storm", "嵐"),
    "骨骼": ("Bone", "骨格"),
    "鸦": ("Crow", "鴉"),
    "鼠": ("Rat", "鼠"),
    "齿轮": ("Gear", "歯車"),
}


def main():
    d = json.loads(G.read_text(encoding="utf-8"))
    traits = d.setdefault("traits", {})
    if "--check" in sys.argv:
        missing = [k for k in TERMS if k not in traits]
        print("未登记:", len(missing), missing)
        return
    added = []
    for zh, (en, ja) in TERMS.items():
        if zh in traits:
            continue
        traits[zh] = {"en": en, "ja": ja}
        added.append(zh)
    d["updated"] = "2026-11-18"
    G.write_bytes((json.dumps(d, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print("新增特性译名:", len(added))
    for zh in added:
        print("  %s = %s / %s" % (zh, traits[zh]["en"], traits[zh]["ja"]))


if __name__ == "__main__":
    main()
