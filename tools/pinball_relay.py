#!/usr/bin/env python3
"""Optional private two-person score-duel relay. Contributions by Roxas2712.

Bind localhost by default. Explicit --bind 0.0.0.0 allows remote clients when
this host's firewall permits TCP connections. Game code/data never cross it.
"""
import argparse
import asyncio
import json
import secrets
import time

class Relay:
    def __init__(self):
        self.rooms={}
        self.connections=set()

    async def client(self,reader,writer):
        if len(self.connections)>=128:
            writer.close();return
        self.connections.add(writer)
        peer=None;code=None;window=time.monotonic();messages=0
        async def send(target,msg):
            if target and not target.is_closing():
                target.write((json.dumps(msg,separators=(',',':'))+'\n').encode())
                await asyncio.wait_for(target.drain(),5)
        try:
            hello=json.loads(await asyncio.wait_for(reader.readline(),15))
            if not isinstance(hello,dict):return
            if hello.get('type')=='host':
                while True:
                    code=''.join(secrets.choice('ABCDEFGHJKLMNPQRSTUVWXYZ23456789') for _ in range(6))
                    if code not in self.rooms:break
                self.rooms[code]=[writer,None,time.monotonic()]
                await send(writer,{'type':'hosted','code':code})
            elif hello.get('type')=='join':
                code=str(hello.get('code','')).upper();room=self.rooms.get(code)
                if not room or room[1] or time.monotonic()-room[2]>600:
                    await send(writer,{'type':'join_error','reason':'not_found' if not room else 'full'});return
                room[1]=writer;peer=room[0]
                await send(peer,{'type':'paired'});await send(writer,{'type':'paired'})
            else:return
            while True:
                raw=await asyncio.wait_for(reader.readline(),600 if not peer else 30)
                if not raw:break
                now=time.monotonic()
                if now-window>=1:window=now;messages=0
                messages+=1
                if messages>60 or len(raw)>32768:break
                msg=json.loads(raw)
                if not isinstance(msg,dict) or msg.get('type')!='pinball_duel' or msg.get('protocol')!=1:break
                if msg.get('kind')=='picture'and(not isinstance(msg.get('png'),str)or len(msg['png'])>27000):break
                room=self.rooms.get(code)
                if not room:break
                peer=room[1] if room[0] is writer else room[0]
                if peer:await send(peer,msg)
        except (ValueError,ConnectionError,asyncio.TimeoutError,asyncio.LimitOverrunError):
            pass
        finally:
            room=self.rooms.get(code)
            if room and writer in room[:2]:self.rooms.pop(code,None)
            else:room=None
            if room:
                other=room[1] if room[0] is writer else room[0]
                try:await send(other,{'type':'peer_gone'})
                except (ConnectionError,asyncio.TimeoutError):pass
            self.connections.discard(writer);writer.close()
            try:await writer.wait_closed()
            except ConnectionError:pass

async def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bind',default='127.0.0.1');p.add_argument('--port',type=int,default=7781)
    args=p.parse_args();relay=Relay()
    server=await asyncio.start_server(relay.client,args.bind,args.port,limit=32768)
    print('Private Pinball relay listening on %s:%d'%(args.bind,args.port),flush=True)
    async with server:await server.serve_forever()

if __name__=='__main__':
    try:asyncio.run(main())
    except KeyboardInterrupt:pass
