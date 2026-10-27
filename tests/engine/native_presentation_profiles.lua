-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local P=require('src.core.game3.profile')
local Font=require('src.render.Font')
local Assets=require('src.render.Assets');local previousImage=Assets.image
local previousGame=package.loaded['src.core.Game'];package.loaded['src.core.Game']=nil
Assets.image=function()return{getDimensions=function()return 128,128 end}end
local records={}
for _,id in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 V.set(id)
 local row=P.active();records[id]=row
 T.eq(P.isGame3Version(id),true);T.eq(P.resolveId(),id)
 T.eq(row.id,id);T.eq(row.label,V.info(id).label);T.eq(row.generation,3)
 T.eq(P.family(),V.layout(id));T.eq(row.family,V.layout(id))
 T.eq(P.forSession(),row);T.eq(P.forSession({}),row);T.eq(P.forSession({version=''}),row)
 T.eq(P.forSession({version=id}),row);T.eq(P.sessionVersion({version=id}),id)
 T.eq(row.font.module,'src.ui.game3.frlg_font')
 T.eq(row.ui.battleSpriteLayout,(id=='ruby'or id=='sapphire')and'rs'or nil)
 T.eq(row.capabilities,nil,'metadata does not invent a gameplay capability registry')
 T.eq(row.save,nil);T.eq(row.extractors,nil)
 for _,target in ipairs{row,row.ui,row.font}do
  T.raises(function()target.changed=true end,'read-only')
 end
 T.eq(P.active(),row,'unchanged version facts reuse a stable immutable record')
 T.eq(package.loaded['src.core.Game'],nil,'queries cannot bootstrap a game')
 local session={version=id,party={hp=23},options={battleScene=0}}
 for _=1,20 do T.eq(P.forSession(session),row)end
 T.eq(session.party.hp,23);T.eq(session.options.battleScene,0)
 -- The selected font really is the native proportional font, not merely a
 -- module-name string that bypasses its glyph/face resources.
 Font.load({font={pages={main={image='NATIVE',base=0,glyphWidth=8,glyphHeight=8,advance=7}},
  faces={small={image='SMALL',base=0,glyphWidth=8,glyphHeight=8,advance=4}},
  charmap={{seq='A',code=13},{seq=' ',code=0}}}})
 local F=require(row.font.module)
 T.eq(F.measure('AAA'),21);T.eq(F.measure('AAA',{small=true}),12)
 T.eq(Font.advanceOf(13),7)
end
V.set('gold')
for _,id in ipairs{'red','gold','crystal','missing'}do
 T.eq(P.isGame3Version(id),false);T.eq(P.of(id),nil);T.eq(P.resolveId(id),nil)
 T.eq(P.forSession({version=id}),nil)
end
T.eq(P.active(),nil);T.eq(P.family(),nil)
T.eq(P.forSession(2),nil);T.eq(P.forSession({version=2}),nil)
T.eq(P.isGame3Version(nil),false);T.eq(P.isGame3Version({}),false)
T.eq(P.forSession({version='ruby'}).id,'ruby','an explicit metadata query does not switch the active native edition')
T.eq(V.get(),'gold')
local original=V.VERSIONS.ruby
V.VERSIONS.ruby={id='ruby',generation=3,label='NATIVE RUBY',layout='rse'}
local replacement=P.of('ruby');T.neq(replacement,records.ruby);T.eq(replacement.label,'NATIVE RUBY')
V.VERSIONS.ruby.label='UPDATED';T.eq(P.of('ruby').label,'UPDATED')
V.VERSIONS.ruby.layout='custom';T.eq(P.of('ruby').family,'custom')
V.VERSIONS.ruby=original;T.eq(P.of('ruby').label,original.label)
local before=P.of('ruby');P.reset();T.neq(P.of('ruby'),before)
T.eq(before.id,'ruby','immutable metadata can be retained without a game/save owner')
Assets.image=previousImage;package.loaded['src.core.Game']=previousGame
T.finish('native edition/font/layout profiles, immutable cache and non-GBA isolation')
