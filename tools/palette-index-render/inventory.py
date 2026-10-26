#!/usr/bin/env python3
"""Refresh/check the source inventory; no game, generated assets or profiles."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / 'docs/palette-index-rendering.md'
START = '<!-- palette-inventory:start -->'
END = '<!-- palette-inventory:end -->'
MODULES = ('SpriteRenderer', 'TileRenderer', 'PaletteFX')
SITES = re.compile(r'\bmapPixel\s*\(|\b(?:[A-Za-z_][\w]*\.)+newImage\b')


def purpose(path):
    if path.startswith('mods/DRAMATIC_SHAPE/'):
        return 'Voxel RGBA texture/readback/animation; compatibility consumer'
    if path.startswith('src/import/'):
        return 'Import/editor/launcher image construction; outside world-palette switch'
    if path.startswith('src/compat/gen1/'):
        return 'Native compatibility RGBA upload or explicit mod palette substitution'
    if re.search(r'/(Gen[345]|Hgss|Pokewalker)', path) or path.startswith('src/core/game3/'):
        return 'Separate Gen 3/4/5 or device path; excluded by X5'
    reasons = {
        'SpriteRenderer': 'Cached OBJ palette and color-zero alpha bake',
        'TileRenderer': 'Atlas/tile animation/border/keyed-image construction; see table above',
        'Assets': 'Resolved PNG load, missing-image fallback; no palette mapping',
        'BattleState': 'Cached species-palette/cropped picture; balls/HP art PNG loads',
        'PartyMenu': 'Cached Gen 2 species icon or DMG OBP icon; plain/egg PNG loads',
        'PicBox': 'Cached species palette for script picture popup',
        'UnownPuzzle': 'Cached puzzle-art palette or plain PNG fallback',
        'Credits': 'Credits background white-to-alpha bake or plain PNG load',
        'Gen2Intro': 'Intro PNG load and color-zero matte',
        'HudTiles': 'Native HUD/OBJ tile raster upload',
        'GbcColorCorrection': 'Independent display correction LUT; preserve',
        'FontHD': 'Font raster/atlas upload; outside palette switch',
        'SecondScreen': 'Screen/canvas conversion; outside palette switch',
        'ProfileAvatar': 'Account avatar decode; outside palette switch',
    }
    return reasons.get(Path(path).stem, 'Cached screen/effect artwork PNG load; no world palette bake')


def inventory():
    consumers, sites = [], []
    for base in ('src', 'mods/DRAMATIC_SHAPE', 'mods/examples'):
        for file in sorted((ROOT / base).rglob('*.lua')):
            path = file.relative_to(ROOT).as_posix()
            references = {module: [] for module in MODULES}
            in_comment = False
            for number, line in enumerate(file.read_text(errors='replace').splitlines(), 1):
                # All known long comments use --[[...]]. Ignore prose matches;
                # this is a lexical inventory, not a dynamic call-graph proof.
                if in_comment:
                    if ']]' in line:
                        in_comment = False
                    continue
                if line.lstrip().startswith('--[['):
                    in_comment = ']]' not in line
                    continue
                code = line.split('--', 1)[0].strip()
                if not code:
                    continue
                for module in MODULES:
                    if module in code:
                        references[module].append(number)
                if SITES.search(code):
                    operations = ', '.join(sorted(set(
                        'mapPixel' if 'mapPixel' in match.group() else 'newImage'
                        for match in SITES.finditer(code))))
                    sites.append(f'| [{path}:{number}](../{path}#L{number}) | {operations} | {purpose(path)} |')
            for module, lines in references.items():
                if lines:
                    anchors = ', '.join(f'[{n}](../{path}#L{n})' for n in lines)
                    consumers.append(f'| `{path}` | {module} | {anchors} |')
    return '\n'.join([
        START, '### Reproducible source references', '',
        'Generated with `python3 tools/palette-index-render/inventory.py`. '
        'This lists lexical references (including re-exports), not an inferred dynamic call graph. '
        'Indirect image consumers are described explicitly above. Generation-specific files '
        'remain listed to make the X5 exclusions reviewable.', '',
        '| Consumer / definition | Surface | Lines |', '| --- | --- | --- |',
        *consumers, '', '### Image construction and pixel callbacks', '',
        'All `mapPixel` and qualified `newImage` references in engine Lua and DRAMATIC_SHAPE '
        'are retained, including capability checks and import-time sites. PNG loads are '
        'not palette bakes. Gen 3 sections inside shared files remain excluded by X5; '
        'the table above identifies the Gen 1/2 functions.', '',
        '| Site | Operation | Reason / boundary |', '| --- | --- | --- |',
        *sites, END,
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    current = DOC.read_text()
    before, rest = current.split(START, 1)
    _, after = rest.split(END, 1)
    updated = before + inventory() + after
    if args.check:
        if current != updated:
            raise SystemExit('Palette inventory is stale; run tools/palette-index-render/inventory.py')
        print('Palette source inventory matches the current tree')
    else:
        DOC.write_text(updated)


if __name__ == '__main__':
    main()
