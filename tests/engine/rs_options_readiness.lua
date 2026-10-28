-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local UI=require('src.ui.Gen3RsOptions')
local Fs,Writer=require('src.import.CacheFs'),require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get();local read=Fs.read
for _,version in ipairs{'ruby','sapphire'}do
  V.set(version)
  local d={title='OPTION',frameLabel='TYPE',frameCount=20,textPalette={},nativeWindow={foregroundColor=1,backgroundColor=15,shadowColor=8},
    selectedStyle=8,inactiveStyle=15,titleX=32,titleY=8,frameLabelX=120,frameNumberX=144,frameY=120,rows={}}
  for i=1,32 do d.textPalette[i]=0 end
  for i,n in ipairs{3,2,2,2,3,0,0}do
    d.rows[i]={text='OWNED ROW',x=32,y=40+(i-1)*16,choices={}}
    for j=1,n do d.rows[i].choices[j]={text='OWNED VALUE',x=120+j*20}end
  end
  local man={game=version,layout='rs',option=d}
  local game={data={constants={gen3RsParty={version=version,menus='data/generated/gba/rse/menus/manifest.lua'}}}}
  Fs.read=function()return Writer.encode(man)end
  T.check(UI.record(game),'complete own-edition option manifest is accepted')
  for _,field in ipairs{'title','frameLabel','frameCount','textPalette','nativeWindow','rows','selectedStyle','titleX','frameY'}do
    local value=d[field];d[field]=nil;T.eq(UI.record(game),nil,'missing option contract rejected: '..field);d[field]=value
  end
  local choice=d.rows[1].choices[3];d.rows[1].choices[3]=nil
  T.eq(UI.record(game),nil,'all three text speeds are required');d.rows[1].choices[3]=choice
  man.game=version=='ruby'and'sapphire'or'ruby';T.eq(UI.record(game),nil,'other edition manifest rejected');man.game=version
  Fs.read=function()return'return true'end;T.eq(UI.record(game),nil,'invalid decoded type rejected')
  Fs.read=function()return'return invalid lua'end;T.eq(UI.record(game),nil,'corrupt manifest rejected')
  for _,other in ipairs{'red','gold','firered','leafgreen','emerald'}do
    V.set(other);T.eq(UI.record(game),nil,'other game keeps its own options: '..other)
  end
end
Fs.read=read;V.set(old)
T.finish('RS original option labels, all choices, malformed resources and edition isolation')
