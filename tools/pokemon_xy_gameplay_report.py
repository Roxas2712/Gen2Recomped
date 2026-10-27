#!/usr/bin/env python3
"""Summarize the owned gameplay probe, keeping redraws and emulation separate.

Integration by Roxas2712. Reads telemetry only; never opens a game or save.
"""
import argparse
import csv
import json
import math
from pathlib import Path


def distribution(values):
    values = sorted(values)
    if not values:
        return {'samples': 0}
    return dict(samples=len(values), mean_ms=sum(values) / len(values),
                p95_ms=values[math.ceil(len(values) * .95) - 1],
                p99_ms=values[math.ceil(len(values) * .99) - 1],
                max_ms=values[-1])


def report(folder):
    with (folder / 'frames.csv').open() as stream:
        rows = list(csv.DictReader(stream))
    slow = {}
    path = folder / 'slow-frames.jsonl'
    if path.exists():
        slow = {item['frame']: item for item in map(json.loads, path.read_text().splitlines())}
    groups = {}
    events = []
    last_frame = None
    for row in rows:
        phase = row['phase']
        group = groups.setdefault(phase, dict(seconds=0, focused_seconds=0,
                                              emulated_frames=0, redraw=[], native=[],
                                              focused_redraw=[], focused_native=[]))
        dt = float(row['dt_ms'])
        group['seconds'] += dt / 1000
        if row['focused'] == 'true':
            group['focused_seconds'] += dt / 1000
        instrumented = row.get('qa_instrumentation') == 'true'
        if not instrumented:
            group['redraw'].append(dt)
            if row['focused'] == 'true':
                group['focused_redraw'].append(dt)
        frame = int(row['emu_frame'])
        if last_frame is not None and frame > last_frame:
            group['emulated_frames'] += frame - last_frame
            worker = float(row['worker_ms'])
            if not instrumented:
                group['native'].append(worker)
                if row['focused'] == 'true':
                    group['focused_native'].append(worker)
            if worker > 50:
                event = dict(seconds=float(row['seconds']), phase=phase,
                             frame=frame, worker_ms=worker,
                             focused_at_completion=row['focused'] == 'true',
                             qa_instrumentation=instrumented)
                if frame in slow:
                    event['native_status'] = slow[frame].get('stats')
                events.append(event)
        last_frame = frame
    for group in groups.values():
        group['redraw'] = distribution(group['redraw'])
        group['native'] = distribution(group['native'])
        group['focused_redraw'] = distribution(group['focused_redraw'])
        group['focused_native'] = distribution(group['focused_native'])
        group['emulated_hz_including_waits'] = group['emulated_frames'] / max(.001, group['seconds'])
    return dict(run=folder.name, phases=groups, slow_completed_native_frames=events,
                caveats=['Redraw cadence is not game FPS or proof of forward progress.',
                         'Native samples are observed completed frames, not every native frame.',
                         'Focus is sampled at completion; a whole stall may span focus changes.',
                         'PNG/state QA intervals are excluded from distributions, retained in events.',
                         'Waits/loading remain in wall-clock emulation rate; no blanket smoothness verdict.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    print(json.dumps(report(args.folder), indent=2))


if __name__ == '__main__':
    main()
