// Real Worker/DO runtime over HTTPS and WSS. No production accounts or data.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, randomUUID } from 'node:crypto';
const origin = process.env.PEER_TEST_ORIGIN;
const key = Buffer.from(process.env.PEER_TEST_KEY, 'base64');
function ticket(room, role, extra = {}) {
  const body = { iss: 'modcompass', aud: 'retro-peer-v1', room, role, client: (role === 'left' ? 'a' : 'b').repeat(64),
    issued: Date.now() * 1000, exp: Math.floor(Date.now() / 1000) + 75, ...extra };
  const a = Buffer.from(JSON.stringify({ typ: 'JWT', alg: 'HS256' })).toString('base64url');
  const b = Buffer.from(JSON.stringify(body)).toString('base64url');
  return `${a}.${b}.${createHmac('sha256', key).update(a + '.' + b).digest('base64url')}`;
}
function open(room, role, token = ticket(room, role)) {
  const ws = new WebSocket(origin.replace('https:', 'wss:') + '/v1/rooms/' + room, ['retro-peer-v1', 'auth.' + token]);
  const queue = [], waiters = [];
  ws.onmessage = event => { const f = JSON.parse(event.data); const w = waiters.shift(); if (w) w(f); else queue.push(f); };
  return { ws, ready: new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; }),
    next: () => queue.length ? Promise.resolve(queue.shift()) : Promise.race([new Promise(resolve => waiters.push(resolve)), new Promise((_, reject) => setTimeout(() => reject(Error('No relay message')), 4000).unref())]),
    send: f => ws.send(JSON.stringify(f)), close: () => ws.close() };
}
test('health and unauthenticated boundary', async () => {
  const d = await (await fetch(origin + '/health')).json(); assert.equal(d.protocol, 'retro-peer-v1');
  assert.equal((await fetch(origin + '/v1/rooms/play:' + randomUUID())).status, 426);
  const p = open('play:' + randomUUID(), 'left', ticket('play:' + randomUUID(), 'left'));
  await assert.rejects(p.ready);
});
test('two authorized peers signal and relay packets without cross-room disclosure', async () => {
  const room = 'play:' + randomUUID(), a = open(room, 'left'), b = open(room, 'right');
  try {
    await Promise.all([a.ready, b.ready]); assert.equal((await a.next()).t, 'ready'); assert.equal((await b.next()).t, 'ready');
    a.send({ t: 'signal', kind: 5, a: 'candidate:fixture', b: '0' }); assert.equal((await b.next()).a, 'candidate:fixture');
    a.send({ t: 'packet', sequence: 1, body: '{"type":"hello"}' }); assert.equal((await b.next()).sequence, 1);
    b.send({ t: 'ack', after: 1 }); assert.equal((await a.next()).after, 1);
    a.send({ t: 'renew', ticket: ticket(room, 'left') }); assert.equal((await a.next()).t, 'renewed');
    a.send({ t: 'bye' }); assert.equal((await b.next()).t, 'bye');
  } finally { a.close(); b.close(); }
});
test('expired, wrong-role and forged tickets cannot connect', async () => {
  for (const extra of [{ exp: 1 }, { role: 'admin' }, { aud: 'other' }]) {
    const room = 'play:' + randomUUID(), p = open(room, 'left', ticket(room, 'left', extra)); await assert.rejects(p.ready);
  }
  const room = 'play:' + randomUUID(), good = ticket(room, 'left'), p = open(room, 'left', good.slice(0, -3) + 'xxx'); await assert.rejects(p.ready);
});
test('replacement closes the old device and rejects replay of its older lease', async () => {
  const room = 'arena:' + randomUUID(), oldToken = ticket(room, 'left', { issued: Date.now() * 1000 - 10000 });
  const a = open(room, 'left', oldToken); await a.ready;
  const gone = new Promise(resolve => { a.ws.onclose = resolve; });
  const b = open(room, 'left'); await b.ready; await gone;
  const replay = open(room, 'left', oldToken); await assert.rejects(replay.ready); b.close();
});
test('invalid and oversized frames terminate only their own connection', async () => {
  for (const frame of [{ t: 'packet', sequence: -1, body: '{}' }, { t: 'packet', sequence: 1, body: 'x'.repeat(32769) }]) {
    const a = open('play:' + randomUUID(), 'left'); await a.ready;
    const gone = new Promise(resolve => { a.ws.onclose = resolve; }); a.send(frame); await gone;
  }
});
