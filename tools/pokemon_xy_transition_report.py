#!/usr/bin/env python3
"""Read the owned A-B-B-A transition telemetry; never launches a game.

Integration by Roxas2712. Keep control runs and frame-progress evidence so a
warm-cache pass cannot be described as proof that an old hitch was fixed.
"""
import argparse
import csv
import json
from pathlib import Path
from pokemon_xy_gameplay_report import distribution


def summarize(folder):
    with (folder / 'frames.csv').open() as stream:
        rows = list(csv.DictReader(stream))
    worker, redraw, slow = [], [], []
    previous = None
    seconds = focused = frames = 0
    for row in rows:
        frame = int(row['emu_frame'])
        relevant = row['phase'].startswith(('south-', 'north-'))
        if relevant:
            dt = float(row['dt_ms'])
            seconds += dt / 1000
            if row['focused'] == 'true':
                focused += dt / 1000
            instrumented = row['qa_instrumentation'] == 'true'
            if not instrumented:
                redraw.append(dt)
            if previous is not None and frame > previous:
                frames += frame - previous
                ms = float(row['worker_ms'])
                if not instrumented:
                    worker.append(ms)
                if ms > 50:
                    slow.append(dict(seconds=float(row['seconds']), phase=row['phase'],
                                     native_ms=ms, focused=row['focused'] == 'true',
                                     qa_instrumentation=instrumented))
        previous = frame
    endpoints = [name + '-' + str(index) + '.png'
                 for name in ('escissia', 'aquarellia') for index in range(1, 4)]
    return dict(run=folder.name, transition_seconds=seconds,
                focused_percent=100 * focused / max(.001, seconds),
                emulated_hz_including_waits=frames / max(.001, seconds),
                native_observed=distribution(worker), redraw=distribution(redraw),
                native_frames_over_50ms=slow,
                endpoints_present=all((folder / name).is_file() for name in endpoints),
                fatal=(folder / 'fatal.txt').exists())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    source = json.loads(args.manifest.read_text())
    assert [run['label'] for run in source] == ['baseline-1', 'candidate-1', 'candidate-2', 'baseline-2']
    result = []
    for run in source:
        result.append(dict(label=run['label'], bridge_sha256=run['bridge_sha256'],
                           **summarize(Path(run['output']))))
    print(json.dumps(dict(order='A-B-B-A', runs=result,
        scope='Y 3x, stereo off, same owned state and standard HID input; three round trips per run',
        caveats=['Not game-rendered FPS; native metrics sample observed completed frames.',
                 'Native observed means worker_ms: native execution/readback plus blank check, image copy and audio enqueue; not Rust CPU time alone.',
                 'QA screenshot intervals excluded from distributions, retained in slow-frame records.',
                 'A passing candidate cannot establish causality if controls also fail to reproduce old hitches.',
                 'No guarantee for later areas, other titles or cold driver/system caches.']), indent=2))


if __name__ == '__main__':
    main()
