-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Colors=require('src.ui.game3.summary_chrome')
local Ui=require('src.core.game3.battle.ui')
local previous,edition=package.loaded['src.core.Game'],Version.get()
for _,version in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 Version.set(version)
 local data={constants={}};package.loaded['src.core.Game']={data=data}
 T.eq(Colors.manifest(),nil,'missing imported resources stay absent')
 local parts={palette={},textColors={}}
 for index=9,12 do
  parts.textColors[index*3+2]=index;parts.textColors[index*3+3]=index+4
  parts.palette[128+index]={index/31,.25,.75,1}
  parts.palette[132+index]={.125,index/31,.5,1}
 end
 data.constants.gen3Summary={parts=parts}
 for _,row in ipairs{{0,30,11},{1,30,10},{7,30,10},{8,30,9},{15,30,9},{16,30,12},{30,30,12},{1,5,10},{2,5,9},{3,5,12}}do
  local index=Ui.ppColorIndex(row[1],row[2]);T.eq(index,row[3])
  local color=Colors.manifest().moveTextColors[index]
  T.check(math.abs(color.fg[1]/255-parts.palette[128+index][1])<1e-12);T.check(math.abs(color.shadow[2]/255-parts.palette[132+index][2])<1e-12)
 end
 local colors=Colors.manifest();colors.moveTextColors[9].fg[1]=0
 T.eq(Colors.manifest().moveTextColors[9].fg[1],9/31*255,'a consumer cannot mutate the native palette')
 parts.palette[137][1]=.5;T.eq(Colors.manifest().moveTextColors[9].fg[1],127.5,'live native palette edits are observable')
 data.constants.gen3Summary=nil;T.eq(Colors.manifest(),nil,'retired resource tables are not cached')
 Version.set('gold');T.eq(Colors.manifest(),nil,'Gen2 retains its native summary owner')
end
package.loaded['src.core.Game']=previous;Version.set(edition)
T.finish('native PP thresholds and detached current summary palette')
