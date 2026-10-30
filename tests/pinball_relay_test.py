"""Real localhost TCP coverage; never contacts the public relay."""
import asyncio
import importlib.util
import json
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('pinball_relay',Path(__file__).resolve().parents[1]/'tools/pinball_relay.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class RelayTest(unittest.IsolatedAsyncioTestCase):
 async def asyncSetUp(self):
  self.relay=module.Relay();self.clients=[]
  self.server=await asyncio.start_server(self.relay.client,'127.0.0.1',0,limit=32768)
  self.port=self.server.sockets[0].getsockname()[1]
 async def asyncTearDown(self):
  for r,w in self.clients:w.close();await w.wait_closed()
  self.server.close();await self.server.wait_closed()
  await asyncio.sleep(.01)
 async def client(self):
  c=await asyncio.open_connection('127.0.0.1',self.port);self.clients.append(c);return c
 async def send(self,c,msg):
  c[1].write((json.dumps(msg)+'\n').encode());await c[1].drain()
 async def recv(self,c):return json.loads(await asyncio.wait_for(c[0].readline(),2))
 async def test_pair_scores_full_room_and_disconnect(self):
  a=await self.client();await self.send(a,{'type':'host'})
  hosted=await self.recv(a);self.assertRegex(hosted['code'],r'^[A-Z2-9]{6}$')
  b=await self.client();await self.send(b,{'type':'join','code':hosted['code']})
  self.assertEqual((await self.recv(a))['type'],'paired');self.assertEqual((await self.recv(b))['type'],'paired')
  c=await self.client();await self.send(c,{'type':'join','code':hosted['code']})
  self.assertEqual((await self.recv(c))['reason'],'full')
  msg={'type':'pinball_duel','protocol':1,'kind':'score','seq':1,'frame':18000,'score':'999999999999','done':True}
  await self.send(a,msg);self.assertEqual(await self.recv(b),msg)
  b[1].close();await b[1].wait_closed()
  self.assertEqual((await self.recv(a))['type'],'peer_gone')
 async def test_live_picture_larger_than_four_kib(self):
  a=await self.client();await self.send(a,{'type':'host'});code=(await self.recv(a))['code']
  b=await self.client();await self.send(b,{'type':'join','code':code});await self.recv(a);await self.recv(b)
  msg={'type':'pinball_duel','protocol':1,'kind':'picture','png':'A'*26000,'frame':600}
  await self.send(a,msg);self.assertEqual(await self.recv(b),msg)
  await self.send(a,dict(msg,png='A'*27001))
  self.assertEqual((await self.recv(b))['type'],'peer_gone')
 async def test_unknown_room(self):
  a=await self.client();await self.send(a,{'type':'join','code':'AAAAAA'})
  self.assertEqual((await self.recv(a))['reason'],'not_found')
 async def test_unrelated_payload_disconnects_without_forwarding(self):
  a=await self.client();await self.send(a,{'type':'host'});code=(await self.recv(a))['code']
  b=await self.client();await self.send(b,{'type':'join','code':code});await self.recv(a);await self.recv(b)
  await self.send(a,{'type':'rom_upload','payload':'not permitted'})
  self.assertEqual((await self.recv(b))['type'],'peer_gone')

if __name__=='__main__':unittest.main()
