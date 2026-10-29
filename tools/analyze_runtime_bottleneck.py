#!/usr/bin/env python3
"""Read an explicit QA capture; never start a game or change its settings."""
import argparse
import json
import math
import statistics
from pathlib import Path


def frame_summary(frames):
    values = sorted(float(f['ms']) for f in frames if isinstance(f.get('ms'), (int, float))
                    and math.isfinite(f['ms']) and f['ms'] >= 0)
    if not values:
        return {'frames': 0}
    result = {'frames': len(values), 'focused': sum(f.get('focused') is True for f in frames),
              'meanMs': statistics.mean(values), 'medianMs': statistics.median(values),
              'p95Ms': values[math.ceil(len(values) * .95) - 1], 'maxMs': values[-1]}
    for key in ('updateMs', 'drawMs', 'presentMs', 'eventPumpMs', 'drawcalls', 'shaderSwitches', 'canvasSwitches'):
        rows = [f[key] for f in frames if isinstance(f.get(key), (int, float)) and math.isfinite(f[key])]
        if rows:
            result[key] = statistics.mean(rows)
    return result


def locate(value):
    if isinstance(value, dict):
        if isinstance(value.get('sampling'), dict) and 'self' in value['sampling']:
            return value
        if 'self' in value and 'states' in value and 'samples' in value:
            return {'sampling': value, 'legs': []}
        for child in value.values():
            found = locate(child)
            if found is not None:
                return found
    return None


def analyze(value):
    data = locate(value)
    if data is None:
        raise ValueError('No runtime bottleneck capture in this report')
    sample = data['sampling']
    total = sample.get('samples', 0)
    def shares(rows):
        return [dict(row, samplePercent=100 * row['hits'] / total if total else 0) for row in rows]
    legs = [dict(name=leg['name'], **frame_summary(leg['frames'])) for leg in data.get('legs', [])]
    paired = {}
    for leg in data.get('legs', []):
        # The diagnostic driver records reverse-order A/B legs. Combine all
        # frames, preserving rejected/unfocused frames in the evidence.
        name = leg['name'].rsplit('-', 1)[0]
        paired.setdefault(name, []).extend(leg['frames'])
    return {'qualifiedFps': False, 'instrumented': True, 'gpuTimeMeasured': False,
            'sampling': frame_summary(sample['frames']), 'samples': total,
            'states': {k: 100 * v / total if total else 0 for k, v in sample['states'].items()},
            'self': shares(sample['self']), 'inclusive': shares(sample['inclusive']),
            'stacks': shares(sample['stacks']), 'overflow': sample.get('overflow', {}),
            'legs': legs, 'pairedCases': {k: frame_summary(v) for k, v in paired.items()},
            'graphicsRestored': data.get('restored'),
            'visualQualityIntentionallyAltered': data.get('visualQualityIntentionallyAltered', False)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    result = analyze(json.loads(args.capture.read_text()))
    if args.json:
        print(json.dumps(result, indent=2))
        return
    print('Diagnostic capture: sampling shares, not GPU timings or qualified FPS.')
    print(f"Samples: {result['samples']}; frame observation: {result['sampling']}")
    print('VM sampling shares:', result['states'])
    for kind in ('self', 'inclusive', 'stacks'):
        print('\n' + kind + ' (inclusive entries overlap):')
        for row in result[kind][:20]:
            print(f"{row['samplePercent']:6.2f}% {row['hits']:6g}  {row['name']}")
    print('\nBalanced graphics cuts; diagnostic only, full restoration:', result['graphicsRestored'])
    for name, row in result['pairedCases'].items():
        print(name, row)
    if result['overflow']:
        print('Bounded capture overflow:', result['overflow'])


if __name__ == '__main__':
    main()
