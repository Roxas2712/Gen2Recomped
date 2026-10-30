#!/usr/bin/env python3
"""Opt-in Gen1 compatibility relay. Roxas2712; see NOTICE.md.

Run explicitly on a trusted LAN/VPN. This tool opens no router ports and installs
no service. SQLite retains seat credentials, the ordered transcript and commits.
Use TLS/VPN outside a trusted LAN; seat tokens are bearer credentials.
"""
import argparse
import hashlib
import json
import secrets
import selectors
import socket
import sqlite3
from pathlib import Path

PROFILE = 'gen1-session-v1:2aec7650cb01845a4e98f1dbcf8a5c652990d984'
MAX_FRAME, MAX_QUEUE, MAX_EVENTS, MAX_ROOMS = 32768, 2 * 1024**2, 4096, 64
ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ'


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


class Relay:
    def __init__(self, database, host='127.0.0.1', port=7780):
        self.db = sqlite3.connect(str(database))
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('PRAGMA max_page_count=24576')  # Refuse growth beyond ~96 MiB.
        self.db.executescript('''
          CREATE TABLE IF NOT EXISTS rooms(code TEXT PRIMARY KEY, mode TEXT NOT NULL, profile TEXT NOT NULL,
            token0 TEXT NOT NULL, token1 TEXT, seed INTEGER NOT NULL, committed INTEGER NOT NULL DEFAULT 0);
          CREATE TABLE IF NOT EXISTS events(room TEXT NOT NULL, ordinal INTEGER NOT NULL, seat INTEGER NOT NULL,
            key TEXT NOT NULL, body TEXT NOT NULL, PRIMARY KEY(room,ordinal), UNIQUE(room,seat,key));
        ''')
        self.selector = selectors.DefaultSelector()
        self.listener = socket.socket()
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind((host, port))
        self.listener.listen(8)
        self.listener.setblocking(False)
        self.selector.register(self.listener, selectors.EVENT_READ, None)
        self.clients = {}

    @property
    def address(self):
        return self.listener.getsockname()

    def drop(self, sock):
        client = self.clients.pop(sock, None)
        if client is None:
            return
        self.selector.unregister(sock)
        sock.close()
        if client.get('room'):
            self.broadcast(client['room'], {'type': 'session_presence', 'seat': client['seat'], 'online': False})

    def emit(self, client, message):
        line = (canonical(message) + '\n').encode()
        if len(client['tx']) + len(line) > MAX_QUEUE:
            raise ValueError('Receive queue full; reconnect to replay the transcript.')
        client['tx'].extend(line)
        self.selector.modify(client['socket'], selectors.EVENT_READ | selectors.EVENT_WRITE, client)

    def broadcast(self, room, message):
        for client in list(self.clients.values()):
            if client.get('room') == room:
                try:
                    self.emit(client, message)
                except ValueError:
                    self.drop(client['socket'])

    def event(self, room, ordinal, seat, body):
        return {'type': 'session_event', 'room': room, 'ordinal': ordinal, 'seat': seat, 'body': json.loads(body)}

    def receive(self, client, message):
        if not isinstance(message, dict):
            raise ValueError('Object required.')
        kind = message.get('type')
        if kind == 'session_open':
            if client.get('room'):
                raise ValueError('Connection already owns a seat.')
            if message.get('profile') != PROFILE or message.get('mode') not in ('trade', 'battle'):
                raise ValueError('Unsupported negotiated feature profile.')
            code, token = message.get('room'), message.get('token')
            with self.db:
                if not code:
                    if self.db.execute('SELECT COUNT(*) FROM rooms').fetchone()[0] >= MAX_ROOMS:
                        raise ValueError('Room budget full; preserve existing journals before maintenance.')
                    code = ''.join(secrets.choice(ALPHABET) for _ in range(8))
                    token = secrets.token_hex(32)
                    self.db.execute('INSERT INTO rooms(code,mode,profile,token0,seed) VALUES(?,?,?,?,?)',
                                    (code, message['mode'], PROFILE, 'sha256:'+hashlib.sha256(token.encode()).hexdigest(), secrets.randbelow(2147483646)+1))
                    seat = 0
                else:
                    row = self.db.execute('SELECT mode,profile,token0,token1 FROM rooms WHERE code=?', (code,)).fetchone()
                    if not row or row[:2] != (message['mode'], PROFILE):
                        raise ValueError('Room/profile mismatch.')
                    if token:
                        digest = 'sha256:'+hashlib.sha256(str(token).encode()).hexdigest()
                        seats = [i for i, stored in enumerate(row[2:]) if stored and secrets.compare_digest(
                            stored, digest)]
                        if not seats:
                            raise ValueError('Seat recovery refused.')
                        seat = seats[0]
                    elif row[3] is None:
                        seat, token = 1, secrets.token_hex(32)
                        self.db.execute('UPDATE rooms SET token1=? WHERE code=?', ('sha256:'+hashlib.sha256(token.encode()).hexdigest(), code))
                    else:
                        raise ValueError('Room full; use the original recovery token.')
            # A recovered seat replaces its old socket, without creating a second player.
            for old in list(self.clients.values()):
                if old.get('room') == code and old.get('seat') == seat:
                    self.drop(old['socket'])
            client.update(room=code, seat=seat)
            self.emit(client, {'type': 'session_welcome', 'room': code, 'seat': seat, 'token': token,
                               'profile': PROFILE, 'mode': message['mode'], 'seed': self.db.execute('SELECT seed FROM rooms WHERE code=?', (code,)).fetchone()[0]})
            for ordinal, sender, body in self.db.execute('SELECT ordinal,seat,body FROM events WHERE room=? ORDER BY ordinal', (code,)):
                self.emit(client, self.event(code, ordinal, sender, body))
            self.broadcast(code, {'type': 'session_presence', 'seat': seat, 'online': True})
            return
        if kind != 'session_publish' or not client.get('room'):
            raise ValueError('Join a room first.')
        key, payload = message.get('key'), message.get('body')
        if not isinstance(key, str) or not 1 <= len(key) <= 64 or not isinstance(payload, dict) or not isinstance(payload.get('type'), str):
            raise ValueError('Invalid publication.')
        body = canonical(payload)
        if len(body.encode()) > MAX_FRAME - 256:
            raise ValueError('Publication too large.')
        room, seat = client['room'], client['seat']
        notifications = []
        with self.db:
            prior = self.db.execute('SELECT ordinal,body FROM events WHERE room=? AND seat=? AND key=?', (room, seat, key)).fetchone()
            if prior:
                if prior[1] != body:
                    raise ValueError('A confirmed message key cannot change.')
                self.emit(client, self.event(room, prior[0], seat, body))
                return
            mode, committed = self.db.execute('SELECT mode,committed FROM rooms WHERE code=?', (room,)).fetchone()
            if committed:
                raise ValueError('Room transaction is terminal; recover its existing transcript.')
            ordinal = self.db.execute('SELECT COALESCE(MAX(ordinal),0)+1 FROM events WHERE room=?', (room,)).fetchone()[0]
            if ordinal >= MAX_EVENTS:
                raise ValueError('Transcript budget reached; stop this session.')
            if mode == 'trade' and key not in ('hello', 'party', 'pick', 'block', 'confirm', 'abort'):
                raise ValueError('Unknown trade message key.')
            if mode == 'trade' and payload['type'] == 'trade_commit':
                raise ValueError('Only the relay may issue a commit.')
            if key == 'confirm' and mode == 'trade':
                digest = payload.get('digest')
                if payload['type'] != 'game3_trade_confirm' or not isinstance(digest, str) or len(digest) != 16 or any(c not in '0123456789abcdef' for c in digest):
                    raise ValueError('Invalid confirmation digest.')
            self.db.execute('INSERT INTO events VALUES(?,?,?,?,?)', (room, ordinal, seat, key, body))
            notifications.append(self.event(room, ordinal, seat, body))
            if mode == 'trade' and key in ('confirm', 'abort'):
                confirmations = self.db.execute("SELECT seat,body FROM events WHERE room=? AND key='confirm' ORDER BY seat", (room,)).fetchall()
                commit = None
                if key == 'abort':
                    commit = {'type': 'trade_abort', 'why': 'Player cancelled.'}
                elif len(confirmations) == 2:
                    digests = [json.loads(row[1])['digest'] for row in confirmations]
                    commit = {'type': 'trade_commit', 'n': 1, 'digests': digests} if digests[0] == digests[1] else {'type': 'trade_abort', 'why': 'Offer digests differ.'}
                if commit:
                    encoded = canonical(commit)
                    self.db.execute('INSERT INTO events VALUES(?,?,?,?,?)', (room, ordinal+1, -1, 'decision', encoded))
                    self.db.execute('UPDATE rooms SET committed=1 WHERE code=?', (room,))
                    notifications.append(self.event(room, ordinal+1, -1, encoded))
        # COMMIT reached stable storage before any client sees the decision.
        for notification in notifications:
            self.broadcast(room, notification)

    def step(self, timeout=0.1):
        for key, mask in self.selector.select(timeout):
            if key.data is None:
                sock, _ = self.listener.accept()
                if len(self.clients) >= 16:
                    sock.close()
                    continue
                sock.setblocking(False)
                client = {'socket': sock, 'rx': bytearray(), 'tx': bytearray()}
                self.clients[sock] = client
                self.selector.register(sock, selectors.EVENT_READ, client)
                continue
            client, sock = key.data, key.fileobj
            try:
                if mask & selectors.EVENT_READ:
                    data = sock.recv(8192)
                    if not data:
                        self.drop(sock)
                        continue
                    client['rx'].extend(data)
                    while b'\n' in client['rx']:
                        line, _, rest = client['rx'].partition(b'\n')
                        client['rx'] = bytearray(rest)
                        if len(line) > MAX_FRAME:
                            raise ValueError('Frame budget exceeded.')
                        self.receive(client, json.loads(line, parse_constant=lambda _: (_ for _ in ()).throw(ValueError('Nonfinite number.'))))
                    if len(client['rx']) > MAX_FRAME:
                        raise ValueError('Frame budget exceeded.')
                if mask & selectors.EVENT_WRITE and client['tx']:
                    sent = sock.send(client['tx'])
                    del client['tx'][:sent]
                if client.get('closing') and not client['tx']:
                    self.drop(sock)
                    continue
                if sock in self.clients:
                    self.selector.modify(sock, selectors.EVENT_READ | (selectors.EVENT_WRITE if client['tx'] else 0), client)
            except (OSError, ValueError, TypeError, sqlite3.Error, RecursionError) as problem:
                if sock not in self.clients:
                    continue
                try:
                    self.emit(client, {'type': 'session_error', 'message': str(problem)[:160]})
                    client['closing'] = True
                    self.selector.modify(sock, selectors.EVENT_WRITE, client)
                except (OSError, ValueError):
                    self.drop(sock)

    def close(self):
        for sock in list(self.clients):
            self.drop(sock)
        self.selector.close()
        self.listener.close()
        self.db.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=7780)
    parser.add_argument('--db', type=Path, required=True)
    args = parser.parse_args()
    args.db.parent.mkdir(parents=True, exist_ok=True)
    relay = Relay(args.db, args.host, args.port)
    print('Gen1 feature relay listening on %s:%s' % relay.address, flush=True)
    try:
        while True:
            relay.step()
    except KeyboardInterrupt:
        pass
    finally:
        relay.close()


if __name__ == '__main__':
    main()
