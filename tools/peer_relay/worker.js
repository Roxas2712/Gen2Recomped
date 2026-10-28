// Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import { DurableObject } from 'cloudflare:workers';
const UUID = '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}';
const roomPattern = new RegExp(`^(play|arena):${UUID}$`);
const utf8 = new TextEncoder();
function decode(s) {
  if (!/^[A-Za-z0-9_-]+$/.test(s)) throw Error('invalid');
  return Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
}
export async function verifyTicket(token, secret, room, now = Date.now()) {
  if (typeof token !== 'string' || token.length > 4096 || !secret) throw Error('invalid');
  const parts = token.split('.');
  if (parts.length !== 3) throw Error('invalid');
  const header = JSON.parse(new TextDecoder().decode(decode(parts[0])));
  const claims = JSON.parse(new TextDecoder().decode(decode(parts[1])));
  if (header.alg !== 'HS256' || header.typ !== 'JWT') throw Error('invalid');
  const key = await crypto.subtle.importKey('raw', Uint8Array.from(atob(secret), c => c.charCodeAt(0)), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
  if (!await crypto.subtle.verify('HMAC', key, decode(parts[2]), utf8.encode(parts[0] + '.' + parts[1]))) throw Error('invalid');
  if (claims.iss !== 'modcompass' || claims.aud !== 'retro-peer-v1' || claims.room !== room || !roomPattern.test(room)
    || !['left', 'right'].includes(claims.role) || !/^[a-f0-9]{64}$/.test(claims.client || '')
    || !Number.isSafeInteger(claims.issued) || !Number.isInteger(claims.exp) || claims.exp * 1000 <= now
    || claims.exp * 1000 > now + 95_000 || claims.issued > now * 1000 + 5_000_000) throw Error('invalid');
  return claims;
}
function send(ws, data) { try { ws.send(JSON.stringify(data)); } catch {} }
export class PeerRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS leases (role TEXT PRIMARY KEY, client TEXT, issued INTEGER, expires INTEGER)');
    this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('{"t":"ping"}', '{"t":"pong"}'));
  }
  async fetch(request) {
    const room = new URL(request.url).pathname.slice('/v1/rooms/'.length);
    let claims;
    try { claims = await verifyTicket(request.headers.get('X-Retro-Ticket'), this.env.PEER_SIGNING_KEY, room); }
    catch { return new Response('Unauthorized', { status: 401 }); }
    const previous = this.ctx.storage.sql.exec('SELECT * FROM leases WHERE role = ?', claims.role).toArray()[0];
    if (previous && previous.issued > claims.issued) return new Response('Stale device lease', { status: 409 });
    this.ctx.storage.sql.exec('INSERT OR REPLACE INTO leases VALUES (?, ?, ?, ?)', claims.role, claims.client, claims.issued, claims.exp);
    for (const old of this.ctx.getWebSockets(claims.role)) old.close(4001, 'Connection replaced');
    const pair = new WebSocketPair(); const client = pair[0], server = pair[1];
    this.ctx.acceptWebSocket(server, [claims.role]);
    server.serializeAttachment({ claims, connection: crypto.randomUUID(), window: Date.now(), count: 0, bytes: 0 });
    await this.ctx.storage.setAlarm(Date.now() + 30_000);
    this.ready();
    return new Response(null, { status: 101, webSocket: client, headers: { 'Sec-WebSocket-Protocol': 'retro-peer-v1' } });
  }
  ready() {
    const all = this.ctx.getWebSockets().filter(ws => ws.readyState === 1 && ws.deserializeAttachment()?.claims.exp * 1000 > Date.now());
    if (all.length === 2) for (const ws of all) send(ws, { t: 'ready', peer: all.find(v => v !== ws).deserializeAttachment().connection });
  }
  async webSocketMessage(ws, message) {
    const meta = ws.deserializeAttachment();
    if (!meta || meta.claims.exp * 1000 <= Date.now()) return ws.close(4003, 'Session authorization expired');
    if (typeof message !== 'string' || utf8.encode(message).length > 96 * 1024) return ws.close(1009, 'Message too large');
    if (Date.now() - meta.window > 1000) { meta.window = Date.now(); meta.count = 0; meta.bytes = 0; }
    meta.count++; meta.bytes += utf8.encode(message).length;
    if (meta.count > 80 || meta.bytes > 1024 * 1024) return ws.close(4008, 'Message rate exceeded');
    ws.serializeAttachment(meta);
    let frame; try { frame = JSON.parse(message); } catch { return ws.close(1007, 'Invalid message'); }
    if (frame.t === 'renew') {
      try {
        const c = await verifyTicket(frame.ticket, this.env.PEER_SIGNING_KEY, meta.claims.room);
        if (c.client !== meta.claims.client || c.role !== meta.claims.role || c.issued < meta.claims.issued) throw Error('invalid');
        meta.claims = c; ws.serializeAttachment(meta);
        this.ctx.storage.sql.exec('INSERT OR REPLACE INTO leases VALUES (?, ?, ?, ?)', c.role, c.client, c.issued, c.exp);
        send(ws, { t: 'renewed' }); return;
      } catch { return ws.close(4003, 'Session authorization refused'); }
    }
    const valid = frame.t === 'signal' && [4, 5].includes(frame.kind) && typeof frame.a === 'string' && frame.a.length <= 32768 && typeof frame.b === 'string' && frame.b.length <= 32
      || frame.t === 'packet' && Number.isSafeInteger(frame.sequence) && frame.sequence > 0 && typeof frame.body === 'string' && utf8.encode(frame.body).length <= 32768
      || frame.t === 'ack' && Number.isSafeInteger(frame.after) && frame.after >= 0
      || frame.t === 'bye';
    if (!valid) return ws.close(1007, 'Invalid frame');
    for (const peer of this.ctx.getWebSockets()) if (peer !== ws && peer.readyState === 1 && peer.deserializeAttachment().claims.exp * 1000 > Date.now()) send(peer, frame);
  }
  webSocketClose(ws) {
    for (const peer of this.ctx.getWebSockets()) if (peer !== ws) send(peer, { t: 'waiting' });
    try { ws.close(); } catch {}
  }
  webSocketError(ws) { this.webSocketClose(ws); }
  async alarm() {
    for (const ws of this.ctx.getWebSockets()) if (ws.deserializeAttachment().claims.exp * 1000 <= Date.now()) ws.close(4003, 'Session authorization expired');
    if (this.ctx.getWebSockets().some(ws => ws.readyState === 1)) await this.ctx.storage.setAlarm(Date.now() + 30_000);
    else this.ctx.storage.sql.exec('DELETE FROM leases');
  }
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/health') return Response.json({ protocol: 'retro-peer-v1', relay: 'websocket' });
    const room = url.pathname.slice('/v1/rooms/'.length);
    if (!url.pathname.startsWith('/v1/rooms/') || !roomPattern.test(room)) return new Response('Not found', { status: 404 });
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return new Response('WebSocket required', { status: 426 });
    const protocols = (request.headers.get('Sec-WebSocket-Protocol') || '').split(',').map(v => v.trim());
    const token = protocols.find(v => v.startsWith('auth.'))?.slice(5);
    try { await verifyTicket(token, env.PEER_SIGNING_KEY, room); } catch { return new Response('Unauthorized', { status: 401 }); }
    const headers = new Headers(request.headers); headers.set('X-Retro-Ticket', token);
    return env.PEER_ROOMS.getByName(room).fetch(new Request(request, { headers }));
  }
};
