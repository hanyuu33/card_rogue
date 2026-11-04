from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / 'art_src/2026-11-04_battle_instruments/panel_source.png').convert('RGBA')
bounds = image.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
image.crop(bounds).resize((128, 128), Image.Resampling.LANCZOS).save(root / 'assets/ui/adventure_shared/battle_instrument_panel.png')
image.crop(bounds).resize((64, 64), Image.Resampling.LANCZOS).save(root / 'assets/ui/adventure_shared/battle_card_trim.png')
