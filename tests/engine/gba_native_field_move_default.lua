-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local _,imageFile=require('tools.sprite-runtime.cpu-gpu').install(love)
local Native=require('src.world.Gen3FieldMove')
local Source=require('src.core.game3.field_move_show_mon')
local V=require('src.core.GameVersion');local Serialize=require('src.core.SaveSerializer')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 Source.release()
 local f=require('tools.session-runtime.fixture').new(edition);local g=f.game
 g.data.pokemon={OWNED={spriteFront='owned-field-front.png'}}
 imageFile('owned-field-front.png',16,16,string.rep(string.char(17,31,47,255),256))
 local strip={width=256,height=80,indexed=string.rep('\1',256*80),palette={}}
 for i=1,16 do strip.palette[i]=i end
 local art={schema=1,edition=edition,romSha1=V.info(edition).sha1,strips={indoors=strip,outdoors=strip}}
 g.data.constants.gen3FieldMovePresentation=art
 local previous=package.loaded['src.core.game3.field_move_show_mon']
 package.loaded['src.core.game3.field_move_show_mon']=nil
 local done=0;local before=Serialize.encode(g.save)
 T.eq(Native.show(g,{species='OWNED'},function()done=done+1 end),true)
 local state=g.stack:top()
 T.check(state.effect~=nil,'ordinary mod-free HM uses its imported cartridge band: '..edition)
 T.eq(state.options.presentation,'cartridge','no cached facade or observer is required')
 local frame=state.frame;state:draw()
 T.eq(state.frame,frame,'drawing cannot advance the admitted field-move clock')
 T.eq(Serialize.encode(g.save),before,'the cut-in cannot edit the save')
 local ticks=0
 while not state.done and ticks<256 do g.stack:update(1/60);ticks=ticks+1 end
 T.check(state.done and ticks<256,'the actual cartridge presentation completes within its own program')
 T.eq(done,1,'ordinary HM continuation runs exactly once')
 T.eq(g.stack:top(),f.world,'field control returns to its original owner')
 g.data.constants.gen3FieldMovePresentation=nil
 T.eq(Native.show(g,{species='OWNED'}),true,'an older import without native artwork still plays its sweep')
 state=g.stack:top();T.eq(state.effect,nil,'missing native artwork uses the existing fallback');state:cancel()
 for _,record in ipairs{true,false,{}, {schema=99}, {schema=1,edition='foreign',romSha1=art.romSha1,strips=art.strips},
   {schema=1,edition=edition,romSha1=string.rep('0',40),strips=art.strips}}do
  g.data.constants.gen3FieldMovePresentation=record
  T.eq(Native.show(g,{species='OWNED'}),true,'older/mismatched artwork retains the existing fallback')
  state=g.stack:top();T.eq(state.effect,nil,'unverified art never enters the cartridge renderer');state:cancel()
 end
 g.data.constants.gen3FieldMovePresentation=art
 T.eq(Native.show(g,{species='OWNED'},nil,{pose=false}),true)
 state=g.stack:top();T.eq(state.effect,nil,'explicit caller presentation options retain their previous meaning')
 T.eq(state.player,nil,'explicit pose=false remains authoritative');state:cancel()
 package.loaded['src.core.game3.field_move_show_mon']=previous
end
T.finish('Native imported HM presentation by default, no observer, authenticated fallback and explicit caller isolation')
