"""Read-only image inspection; writes only audit metadata, never image pixels."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from PIL import Image


def inspect(root: Path):
    rows, errors, hashes = [], [], {}
    media = root / 'app/entry/src/main/resources/base/media'
    derived_path = root / 'docs/validation/engineering-images.json'
    derived = json.loads(derived_path.read_text(encoding='utf-8')) if derived_path.is_file() else {}
    engineering = {asset['key']: asset for asset in derived.get('assets', [])}
    for path in sorted((root / 'assets/images').rglob('*.png')):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        rel = path.relative_to(root).as_posix()
        with Image.open(path) as source:
            source.load()
            rgba = source.convert('RGBA')
            alpha = rgba.getchannel('A')
            histogram = alpha.histogram()
            extrema = alpha.getextrema()
            transparent = sum(histogram[:16]) / (source.width * source.height)
            visible = sum(histogram[128:]) / (source.width * source.height)
            kind = path.parent.name
            expects_alpha = kind in ('sticker', 'empty') or path.stem.startswith(('ip_', 'zodiac_', 'beast_'))
            row = dict(key=path.stem, file=rel, group=kind, width=source.width,
                       height=source.height, format=source.format, mode=source.mode,
                       sha256=digest, bytes=path.stat().st_size, alphaMin=extrema[0],
                       alphaMax=extrema[1], transparentFraction=round(transparent, 6),
                       visibleFraction=round(visible, 6), alphaBounds=alpha.getbbox())
            if min(source.size) < 600:
                errors.append(f'{rel}: resolution below 600px')
            if expects_alpha and (extrema[0] != 0 or extrema[1] < 200 or transparent < .02 or visible < .03):
                errors.append(f'{rel}: invalid/empty alpha distribution')
            if digest in hashes:
                errors.append(f'{rel}: duplicate of {hashes[digest]}')
            hashes[digest] = rel
            derivative = engineering.get(path.stem)
            if derivative:
                engineering_copy = root / derivative['file']
                if derivative['sourceSha256'] != digest or not engineering_copy.is_file() or hashlib.sha256(engineering_copy.read_bytes()).hexdigest() != derivative['sha256']:
                    errors.append(f'{rel}: derived engineering media missing or mismatched')
                else:
                    with Image.open(engineering_copy) as decoded:
                        decoded.load()
                        if decoded.size != source.size or decoded.convert('RGBA').getchannel('A').tobytes() != alpha.tobytes():
                            errors.append(f'{rel}: derived dimensions/alpha changed')
                row['engineeringFile'] = derivative['file']
                row['engineeringSha256'] = derivative['sha256']
            else:
                engineering_copy = media / path.name
                if not engineering_copy.is_file() or hashlib.sha256(engineering_copy.read_bytes()).hexdigest() != digest:
                    errors.append(f'{rel}: engineering media missing or mismatched')
            rows.append(row)
    counts = Counter(row['group'] for row in rows)
    targets = {'cover': 12, 'background': 12, 'sticker': 30, 'empty': 5}
    for kind, count in targets.items():
        if counts[kind] != count:
            errors.append(f'{kind}: expected {count}, found {counts[kind]}')
    for prefix, count in [('ip_', 6), ('zodiac_', 11), ('beast_', 7), ('festival_', 8)]:
        actual = sum(row['key'].startswith(prefix) for row in rows)
        if actual != count:
            errors.append(f'{prefix}: expected {count}, found {actual}')
    return dict(status='pass' if not errors else 'block', scope='image file integrity only; not Gate C or legal approval',
                total=len(rows), counts=dict(counts), errors=errors, assets=rows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app_root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.app_root.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'assets'}, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'pass' else 1)
