# 提示词存档 — 2026-10-22 豚鼠吟游诗人 CG

三条提示词共用前缀：
`FULL-BLEED wide cinematic … key visual, 16:9 horizontal composition, no white background, no border, no text, no watermark.`

---

## hero（主选）→ CG_guinea_pig_bard_hero_2560x1440.png
源图：`FULL_BLEED_wide_cinematic_key__2026-10-22T07-16-40.png`

```
An anthropomorphic GUINEA PIG BARD seated on a mossy stone, three-quarter view, body on the LEFT THIRD of the frame, a small Celtic harp held at his right side so the instrument and its glowing strings fill the right side of frame, leaving airy negative space in the upper right.

ANATOMY IS CRITICAL - correct guinea pig features: NO TAIL AT ALL, absolutely no visible tail; blunt squared-off muzzle with a split upper lip; tiny folded rounded rose-petal ears (not pointed, not long); Abyssinian rosette coat with clear circular fur whorls and swirls; stout barrel-shaped body, very short stubby legs, small four-toed paws with tiny claws; large round glossy black eyes set on the sides of the head; long straight whiskers. Species must read unmistakably as a GUINEA PIG, not a hamster, not a chinchilla, not a squirrel, not a mouse.

Costume: worn dark-teal travelling cloak with gold-thread embroidery and a frayed hem, brown leather doublet with brass buckles, wide belt with pouches and a pan flute, wine-red neck scarf, a single small brass bell hanging from the harp frame.

Scene: ancient mossy oaks and giant ferns, faint ruined stone tower and a low moon behind the canopy, drifting fireflies, glowing mushroom caps, spiral ribbons of golden musical light curling off the harp strings. Warm amber firelight from the lower left, cool blue moonlight rim light from the right, soft volumetric haze.

Art direction: painted fantasy illustration in the style of a dark storybook bestiary - clean bold ink outlines, thick visible brushwork, rich oil-texture shading, semi-realistic animal anatomy with expressive cartoon warmth, strong warm-versus-cool colour contrast, cinematic depth of field, high detail.
```

---

## night（备选一）→ CG_guinea_pig_bard_night_2560x1440.png
源图：`FULL_BLEED_wide_cinematic_key__2026-10-22T07-15-33.png`

```
A plump anthropomorphic GUINEA PIG BARD sitting on a mossy boulder in a twilight forest clearing, playing a small Celtic harp (clarsach) with both front paws, its strings glowing faint golden light. Round chubby body covered in fluffy tri-colour rosette fur (cream, warm caramel brown, dark chocolate patches), small folded round ears, glossy black button eyes, twitching whiskers, tiny pink paw pads, short stubby legs, small tail. Fantasy bard costume: dark teal hooded travelling cloak with tattered hem and gold embroidery, brown leather doublet with brass buckles, belt with pouches and a pan flute, wine-red scarf, feathered cap hanging on the harp frame, one small brass bell on the strap.

Scene: ancient mossy oaks, giant ferns, glowing mushrooms, drifting fireflies and dust motes, distant ruined stone tower and a low moon behind the canopy; warm amber campfire light from the left, cool blue moonlight rim light from the right, soft volumetric god rays, small luminous musical notes and ribbons of light curling off the harp strings.

Art direction: painted fantasy illustration matching a dark storybook bestiary - clean bold ink outlines, thick painterly brushwork, rich oil-texture shading, semi-realistic animal anatomy with expressive cartoon eyes, warm-versus-cool colour contrast, high detail, cinematic composition with the bard slightly off-centre and generous empty space at the top for UI overlay.
```

---

## anime（备选二）→ CG_guinea_pig_bard_anime_2560x1440.png
源图：`FULL_BLEED_wide_cinematic_anim_2026-10-22T07-15-18.png`

```
A gentle GUINEA PIG GIRL BARD (kemonomimi: small round fluffy guinea-pig ears on top of her head, one soft fluffy curled tail, fluffy cream-and-caramel patchy hair) sitting on a flower-covered tree root in a sunlit forest glade, hugging and plucking a small golden harp. Soft watercolour Japanese anime illustration style: pastel mint and cream palette, delicate lace and ribbon details, white daisies and ivy woven into her braided hair, flowing cream-and-sage layered dress with gold trim, big sparkling amber eyes, gentle smile, blush, long lashes. Airy backlit forest background with translucent leaves, petals, floating light bokeh and warm sunlight rays.

Style: soft pastel watercolour anime illustration, ultra-detailed lace, gentle glow, dreamy and cozy, delicate lineart, high resolution wide desktop wallpaper composition, subject centred with breathing room around.
```

---

## 踩坑记录
- 首次「night」提示词未写死「无尾」，结果尾巴与五趾人脚出戏；hero 追加 `NO TAIL AT ALL` + 物种排除清单（hamster/chinchilla/squirrel/mouse）后特征才稳。
- 「anime」版即使写了 curled tail 也会画成大尾巴——豚鼠本无尾，若转正典需改成 `NO TAIL`。
- 1536×1024 是工具可控的最宽比例（非绝对 16:9），必须靠纵向裁切到 1536×864 再放大。
