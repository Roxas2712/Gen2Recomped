-- Actual loopback TCP, including unequal poll rates and input pipelines.
local socket=require('socket');local N=require('src.tcg.Net')
local bind=assert(socket.bind('127.0.0.1',0));local _,port=bind:getsockname();bind:close()
local a=N.new('host',nil,port,'tcg-loopback',string.rep('\0',32768))
local b=N.new('join','127.0.0.1',port,'tcg-loopback',string.rep('\255',32768))
local deadline=socket.gettime()+10
while not(a.remote and b.remote)do a:update();b:update();assert(not a.error,a.error);assert(not b.error,b.error);assert(socket.gettime()<deadline,'TCP handshake timeout');socket.sleep(.001)end
local counts={0,0};local hash=string.rep('f',64)
while counts[1]<60 or counts[2]<60 do
 for i,net in ipairs{a,b}do
  net:update();assert(not net.error,net.error)
  if counts[i]<60 then
   local d,btn,other,otherbtn=net:inputs(i==1 and 254 or 253,255,hash)
   if d then assert(counts[i]<6 and d==255 and other==255 and btn==255 and otherbtn==255 or counts[i]>=6 and d==254 and other==253 and btn==255 and otherbtn==255);counts[i]=counts[i]+1 end
  end
 end
 assert(socket.gettime()<deadline,'TCP input timeout');socket.sleep(.001)
end
b:close();local closedDeadline=socket.gettime()+1;while not a.error and socket.gettime()<closedDeadline do a:update();socket.sleep(.001)end;assert(a.error and a.state=='closed','Disconnect must stop the network session')
print('TCG actual TCP: full 32-KiB saves, 60 lockstep frames and disconnect: PASS')
