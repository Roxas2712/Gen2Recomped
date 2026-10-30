"""Serial real-socket and SQLite recovery checks, run only by NAS QA."""
import json
import atexit
from pathlib import Path
import socket
import sys
import tempfile
import subprocess
import time
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.gen1_session_relay import Relay, PROFILE
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import qa_storage as qa
qa._storage = qa.Storage(Path(__file__).resolve().parents[1])
atexit.register(qa._storage.close)
qa.qa_source(Path(__file__).resolve().parents[1])


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='gen1-relay-')
        self.path = Path(self.temp.name) / 'journal.sqlite'
        self.relay = Relay(self.path, port=0)
        self.clients = []

    def tearDown(self):
        for client in self.clients:
            client.close()
        self.relay.close()
        self.temp.cleanup()

    def client(self):
        client = socket.create_connection(self.relay.address)
        client.setblocking(False)
        self.clients.append(client)
        return client

    def exchange(self, client, message=None):
        if message:
            client.sendall((json.dumps(message) + '\n').encode())
        buf = b''
        for _ in range(24):
            self.relay.step(0.002)
            try:
                part = client.recv(65536)
                if not part:
                    break
                buf += part
            except BlockingIOError:
                pass
        return [json.loads(row) for row in buf.splitlines()]

    def open(self, client, **fields):
        rows = self.exchange(client, dict(type='session_open', mode='trade', profile=PROFILE, **fields))
        return next(row for row in rows if row['type'] == 'session_welcome')

    def test_commit_survives_relay_restart_and_seat_recovery(self):
        a, b = self.client(), self.client()
        host = self.open(a)
        peer = self.open(b, room=host['room'])
        self.assertEqual((host['seat'], peer['seat']), (0, 1))
        self.assertEqual(host['seed'], peer['seed'])
        stored = self.relay.db.execute('SELECT token0 FROM rooms').fetchone()[0]
        self.assertNotEqual(stored, host['token'])
        self.assertTrue(stored.startswith('sha256:'))
        digest = '0123456789abcdef'
        frame = dict(type='session_publish', key='confirm', body=dict(type='game3_trade_confirm', digest=digest))
        self.exchange(a, frame)
        rows = self.exchange(b, frame)
        commit = next(r for r in rows if r.get('body', {}).get('type') == 'trade_commit')
        self.assertEqual(commit['body']['digests'], [digest, digest])
        self.relay.close()
        self.relay = Relay(self.path, port=0)
        recovered = self.client()
        rows = self.exchange(recovered, dict(type='session_open', profile=PROFILE, mode='trade', room=host['room'], token=host['token']))
        self.assertIn(commit, rows)
        replay = self.exchange(recovered, frame)
        self.assertEqual(len(replay), 1)
        self.assertEqual(replay[0]['ordinal'], 1)
        count = self.relay.db.execute('SELECT COUNT(*) FROM events').fetchone()[0]
        self.assertEqual(count, 3)
        changed = dict(frame, body=dict(type='game3_trade_confirm', digest='ffffffffffffffff'))
        self.exchange(recovered, changed)
        self.assertEqual(self.relay.db.execute('SELECT COUNT(*) FROM events').fetchone()[0], count)

    def test_tokens_profiles_and_digest_mismatch(self):
        a, b = self.client(), self.client()
        host = self.open(a)
        peer = self.open(b, room=host['room'])
        self.exchange(a, dict(type='session_publish', key='confirm', body=dict(type='game3_trade_confirm', digest='0000000000000000')))
        rows = self.exchange(b, dict(type='session_publish', key='confirm', body=dict(type='game3_trade_confirm', digest='1111111111111111')))
        self.assertTrue(any(r.get('body', {}).get('type') == 'trade_abort' for r in rows))
        wrong = self.client()
        rows = self.exchange(wrong, dict(type='session_open', mode='trade', profile=PROFILE, room=host['room'], token='wrong'))
        self.assertFalse(any(r['type'] == 'session_welcome' for r in rows))
        forged = self.client()
        rows = self.exchange(forged, dict(type='session_open', mode='trade', profile='wrong'))
        self.assertTrue(rows and rows[0]['type'] == 'session_error')

    def test_actual_lua_tcp_channel_codec_and_native_commit(self):
        child = qa.qa_popen(['luajit', 'tests/fixtures/gen1_interfaces/transport/client.lua',
                                  '%s:%s' % self.relay.address], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 20
        while child.poll() is None and time.monotonic() < deadline:
            self.relay.step(0.002)
        if child.poll() is None:
            child.kill()
        output = child.communicate(timeout=2)[0].decode()
        self.assertEqual(child.returncode, 0, output)
        self.assertIn('ACTUAL_LUA_CABLE_RELAY_OK', output)
        self.assertIn('ACTUAL_CROSS_ENGINE_RECONNECT_OK', output)
        print('Verified actual TCP trade and Gen1/native shared-kernel reconnect.', flush=True)

    def test_client_cannot_publish_a_commit(self):
        a = self.client()
        self.open(a)
        self.exchange(a, dict(type='session_publish', key='block', body=dict(type='trade_commit', n=1, digests=['a', 'a'])))
        self.assertEqual(self.relay.db.execute('SELECT COUNT(*) FROM events').fetchone()[0], 0)


if __name__ == '__main__':
    unittest.main()
