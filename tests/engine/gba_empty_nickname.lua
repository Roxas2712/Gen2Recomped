-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Naming=require('src.ui.NamingScreen')
local Serialize=require('src.core.SaveSerializer')
local function gameFor(edition,nickname)
 V.set(edition)
 local mon={species='BULBASAUR',nickname=nickname,level=5,hp=19,moves={{id='TACKLE',pp=35}}}
 local g={data=T.fixtures.fresh(),save={party={mon},inventory={POKE_BALL=3},flags={OWNED=true}}}
 if edition~='red' then
  -- Synthetic key cells exercise the Gen3 START-to-OK path independently
  -- of owned ROM extraction; native keyboard artwork is checked separately.
  g.data.constants.gen3Keyboard={opensOn='upper',cycle={'upper','lower'},pages={
   {name='upper',label='ABC',rows={'ABCDEFGH','IJKLMNOP','QRSTUVWX','YZ      '}},
   {name='lower',label='abc',rows={'abcdefgh','ijklmnop','qrstuvwx','yz      '}}}}
 end
 local input
 g.input={wasPressed=function(_,key)return key==input end}
 local pops=0
 g.stack={pop=function()pops=pops+1 end}
 return g,mon,function(screen,key)input=key;screen:update(1/60);input=nil end,function()return pops end
end
for _,edition in ipairs{'emerald','firered','leafgreen'}do
 for _,old in ipairs{false,'OWN NAME'}do
  for _,entry in ipairs{'','   ','A','A B','éPK'}do
   local g,mon,press,pops=gameFor(edition,old or nil)
   local before=Serialize.encode(g.save);local callbacks=0
   local screen=Naming.new(g,{kind='mon',mon=mon,default=mon.nickname,maxLen=10,onDone=function(name)
    callbacks=callbacks+1;T.eq(pops(),1,'Naming closes before releasing the caller')
    if name and #name>0 then mon.nickname=name end
   end})
   -- Glyphs are the keyboard buffer, not the host Pokemon. Drive the actual
   -- confirmation input after entering the requested edge-case buffer.
   for i=1,#entry do screen.glyphs[i]=entry:sub(i,i)end
   T.eq(Serialize.encode(g.save),before,'Opening and editing the keyboard preserve the owned mon')
   press(screen,'start');if callbacks==0 then press(screen,'a')end
   T.eq(callbacks,1,'Blank confirmation must still complete the caller')
   local expected=entry:find('%S')and entry or(old or nil)
   T.eq(mon.nickname,expected,'Empty or all-space Gen3 names retain the previous nickname exactly')
   T.eq(mon.hp,19);T.eq(mon.moves[1].pp,35);T.eq(g.save.inventory.POKE_BALL,3)
  end
 end
 -- Player/rival/box defaults are independent from Pokemon nickname changes.
 for _,kind in ipairs{'player','rival','box'}do
  local g,_,press=gameFor(edition)
  local name;local s=Naming.new(g,{kind=kind,default='DEFAULT',onDone=function(n)name=n end})
  press(s,'start');if not name then press(s,'a')end
  T.eq(name,'DEFAULT','Other naming contracts keep their existing empty defaults')
 end
end
local g,_,press=gameFor('red');local answer
local s=Naming.new(g,{kind='mon',onDone=function(n)answer=n end});press(s,'start')
T.eq(answer,'A','Gen1 keeps its separate naming behavior')
T.finish('Gen3 blank nickname completion and caller ownership')
