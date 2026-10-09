"""Rebuild the bundled Korean/Latin OFL font subset from a local upstream TTC.
Usage: python3 scripts/subset-font.py /path/to/NotoSansCJK-Regular.ttc
Requires fonttools; source collection must have the Korean face at index 1.
Keep the original font's license/attribution when redistributing the subset.
"""
from pathlib import Path
import argparse
from fontTools import subset
from fontTools.ttLib import TTFont
parser=argparse.ArgumentParser();parser.add_argument('source_ttc');args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
font=TTFont(args.source_ttc,fontNumber=1)
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True
codepoints=set(range(32,127))|set(range(0xAC00,0xD7A4))|set(range(0x3131,0x318F))
codepoints.update([0xD7,0xB7,0x2022,0x2013,0x2014,0x2190,0x2191,0x2192,0x2193,0x25CF])
for path in (root/'game/run_state.gd',root/'scenes/main.gd'):
 codepoints.update(ord(c) for c in path.read_text(encoding='utf-8') if ord(c)>=32)
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=sorted(codepoints));subsetter.subset(font)
font.save(root/'assets/fonts/NotoSansKR-Subset.otf')
print('Bundled font subset rebuilt.')
