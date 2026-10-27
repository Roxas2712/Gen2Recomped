-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Help=require('src.ui.game3.help_system')
local Text=require('src.render.Gen3HelpText')
local Version=require('src.core.GameVersion')
local original=package.loaded['src.core.Game'];local base=Help.draw
local function fixture(edition)
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local facts={schema=1,edition=edition,romSha1=Version.info().sha1,
  topics={},entries={},contexts={},topicOrder={4,1,2,3,5,6},topicFlags={},cancel='HelpCancel',
  frame={tiles={},palette={}},keypad={tiles={},regions={}}}
 for i=1,6 do facts.topics[i]={label='Topic'..i,description='Description'..i}end
 for i=1,5 do facts.entries[i]={};for n=1,10 do facts.entries[i][n]={question='Question'..n,answer='Answer'..n}end end
 for context=0,35 do
  facts.contexts[context]={};facts.topicFlags[context]={true,true,true,true,true,true}
  for topic=1,5 do facts.contexts[context][topic]={1,2,3,4,5,6,7,8,9,10}end
 end
 for i,tile in ipairs{0,1,2,4,6,9,12,13,14,15,32,33,34}do
  facts.keypad.regions[i]={tile=tile,width=(i==3 or i==4)and 16 or(i==5 or i==6)and 24 or 8,height=12}
 end
 for i=1,288 do facts.frame.tiles[i]=0x21 end
 for i=1,16 do facts.frame.palette[i]=i-1 end
 for i=1,2048 do facts.keypad.tiles[i]=0x21 end
 facts.keypad.tiles[513]=0x43 -- second tile row, sixteen tiles per row
 game.data.constants.gen3Help=facts
 game.data.text={HelpCancel='CANCEL'}
 for i=1,6 do game.data.text['Topic'..i]='TOPIC '..i;game.data.text['Description'..i]='DESCRIPTION '..i end
 for i=1,10 do game.data.text['Question'..i]='QUESTION '..i;game.data.text['Answer'..i]=('LONG ANSWER\n'):rep(12)end
 local pressed={}
 game.input={wasPressed=function(_,key)return pressed[key]==true end,isDown=function()return false end}
 local world={ticks=0,update=function(self)self.ticks=self.ticks+1 end};game.stack:push(world)
 local function key(name)
  pressed[name]=true;game.stack:update(1/60);pressed[name]=nil
 end
 return f,game,facts,world,key
end
T.eq(Help.isOpen(),false);T.eq(base(),nil);T.eq(Help.close(),false)
for _,edition in ipairs{'firered','leafgreen'}do
 local f,game,facts,world,key=fixture(edition)
 for _,invalid in ipairs{0,35,-1,36,1.5,'23'}do T.eq(Help.show(game,invalid),false)end
 T.eq(#game.stack.states,1)
 T.eq(Help.show(game,23),true);T.eq(Help.isOpen(),true);T.eq(Help.show(game,23),false)
 local state=game.stack:top();T.eq(state.level,'main');T.eq(state.menu.items[1].topic,4)
 key('a');T.eq(state.level,'questions');T.eq(state.topic,4);T.eq(#state.menu.items,11)
 for _=1,8 do key('down')end
 T.eq(state.menu.index,9);T.eq(state.menu.scroll,2,'native ListMenu scrolls its actual rows')
 key('a');T.eq(state.level,'answer');key('down');T.eq(state.articleScroll,1)
 key('b');T.eq(state.level,'questions');T.eq(state.menu.index,9);T.eq(world.ticks,0,'Help never updates the field')
 key('b');T.eq(state.level,'main');T.eq(state.menu.index,1)
 local paints=0;state.paint=function()paints=paints+1;return 9 end
 Help.draw=function()base();return base()end
 T.eq(state:draw(),9);T.eq(paints,1,'repeated source bases paint one native modal')
 T.eq(base(),nil,'outside-phase draw cannot repaint')
 local cover={};game.stack:push(cover);state:update(1/60);T.eq(state.menu.index,1)
 state:draw();T.eq(paints,2,'covered native Help can still be drawn')
 Help.draw=function()game.save={};return base()end
 local before=game.save;T.eq(state:draw(),false);T.eq(paints,2,'replaced save denies native paint')
 Help.draw=base;Help._service:poll();T.eq(Help.isOpen(),false);T.eq(game.stack:top(),cover)
 T.eq(state.game,nil);T.eq(state.menu,nil);game.stack:pop();game.save=before
 T.eq(Help.show(game,24),true);state=game.stack:top()
 local released=0;state.resources={{release=function()released=released+1 end}}
 Help._service:releaseOwner('unrelated');T.eq(Help.isOpen(),true)
 key('r');T.eq(Help.isOpen(),false);T.eq(released,1);T.eq(game.stack:top(),world)
 state:exit();T.eq(released,1,'resource release is idempotent')
 T.eq(Help.show(game,24),true);state=game.stack:top()
 local oldImageModule=love.image;love.image=love.image or{}
 local oldImage,oldData=love.graphics.newImage,love.image.newImageData
 local images,releases={},0
 love.image.newImageData=function(w,h)
  return{w=w,h=h,pixels={},setPixel=function(self,x,y,r,g,b,a)self.pixels[y*w+x+1]={r,g,b,a}end,release=function()end}
 end
 love.graphics.newImage=function(data)
  local image={data=data,setFilter=function()end,release=function()releases=releases+1 end}
  images[#images+1]=image;return image
 end
 state:art();T.eq(#state.resources,22);T.eq(#state.icons,13)
 local first,second=images[1].data.pixels[1],images[1].data.pixels[2]
 T.check(first[1]<second[1],'low nibble is the left original pixel')
 local icon=state.icons[1].data
 T.check(icon.pixels[65][1]>icon.pixels[1][1],'keypad second row uses the original sixteen-tile pitch')
 state:art();T.eq(#images,22,'no frame-time resource recreation')
 Help.close();T.eq(releases,22)
 T.eq(Help.show(game,24),true);state=game.stack:top()
 -- Use owned synthetic images for failure cleanup as well.
 local made=0
 love.graphics.newImage=function(data)
  made=made+1;if made==3 then error('injected Help upload failure')end
  return{setFilter=function()end,release=function()releases=releases+1 end}
 end
 T.raises(function()state:art()end,'injected Help upload failure')
 T.eq(releases,24);T.eq(#state.resources,0);T.eq(state.tiles,nil)
 Help.close();love.graphics.newImage,love.image.newImageData=oldImage,oldData
 love.image=oldImageModule
 -- Static IR preserves bank cell identity, icon width, placeholders and
 -- explicit cursor operands instead of flattening the original controls.
 local layout=Text.layout({{t='tag',control=0xF9,code=3},{t='tag',control=0xF8,code=2},
  {t='ext',cmd=18,args={72}},{t='ph',code=1},{t='nl'},{t='text',s='A\n\nB'},{t='eos'}},208,facts.keypad)
 T.eq(layout.glyphs[1].code,259);T.eq(layout.glyphs[2].icon,2)
 T.eq(layout.glyphs[3].x,72);T.eq(layout.height,60,'explicit blank lines retain their original rows')
 local translated=Text.layout({{t='tag',tag='{A_BUTTON}'},{t='text',s=' NEXT'}},208,facts.keypad)
 T.eq(translated.glyphs[1].icon,0,'translated tags retain actual keypad art')
 local other={data=game.data,save=game.save,stack=game.stack};T.eq(Help.show(other,23),false)
 -- Mod shutdown removes only its own Help, even under an unrelated screen.
 game.mods.mods={help_owner={enabled=true}}
 local G=require('src.core.Game3')
 T.eq(G._withCallbackOwner('help_owner',Help.show,game,25),true)
 state=game.stack:top();local unrelated={};game.stack:push(unrelated)
 Help._service:releaseOwner('help_owner');T.eq(game.stack:top(),unrelated)
 T.eq(Help.isOpen(),false);T.eq(state.game,nil);game.stack:pop()
 Help.draw=base;f.close();require('src.core.Game3').release()
end
for _,edition in ipairs{'emerald','ruby','sapphire'}do
 local f,game=fixture(edition);T.eq(Help.show(game,23),false);T.eq(Help.isOpen(),false);f.close()
end
Help._service:release();Help.draw=base;package.loaded['src.core.Game']=original;Version.set('firered')
T.finish('native Help modal, shared list input, structured text and owner retirement')
