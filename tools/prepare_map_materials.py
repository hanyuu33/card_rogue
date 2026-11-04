from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
src = root / 'art_src/2026-11-04_map_ui'
dst = root / 'assets/ui/adventure_shared'
Image.open(src/'forest_source.png').convert('RGB').resize((1600, 900), Image.Resampling.LANCZOS).save(dst/'map_forest.png')
bridge = Image.open(src/'bridge_source.png').convert('RGBA')
bounds = bridge.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
bridge = bridge.crop(bounds)
bridge.thumbnail((128, 256), Image.Resampling.LANCZOS)
bridge.save(dst/'map_bridge_clear.png')
