"""Payload-only aggregate counters for private HTTPS fixtures; never retain bodies or headers."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import threading
import time


class TrafficMeter:
    def __init__(self):
        self.lock = threading.Lock()
        self.groups = {}
        self.started = None
        self.finished = None

    def record(self, path, incoming, outgoing, status):
        group = ('verifier' if '/verifier/' in path else 'battle_wire' if path.endswith('/battle-wire')
                 else 'presence' if path.endswith('/play/presence') else 'other_client_api')
        with self.lock:
            instant = time.monotonic()
            self.started = instant if self.started is None else self.started
            self.finished = instant
            row = self.groups.setdefault(group, dict(requests=0, request_body_bytes=0, response_body_bytes=0, failures=0, status_codes={}))
            row['requests'] += 1
            row['request_body_bytes'] += incoming
            row['response_body_bytes'] += outgoing
            row['failures'] += int(status >= 400)
            row['status_codes'][str(status)] = row['status_codes'].get(str(status), 0) + 1

    def snapshot(self):
        with self.lock:
            return {key: dict(value, status_codes=dict(value['status_codes'])) for key, value in self.groups.items()}

    def elapsed_seconds(self):
        with self.lock:
            return round(self.finished - self.started, 2) if self.started is not None else 0
