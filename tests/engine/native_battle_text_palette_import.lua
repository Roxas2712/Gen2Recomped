-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local Image=require('src.import.ImageWriter')
local Import=require('src.import.RomImporter')
local spec=X.BATTLE_TEXTBOX
local lz,blank=X.lz77ok,Image.blank
local function zeros(n)local out={};for i=1,n do out[i]=0 end;return out end
for _,edition in ipairs{'firered','leafgreen','emerald'}do
 local tiles,map,pal,menu=zeros(spec.TILES_BYTES),zeros(spec.TILEMAP_BYTES),zeros(spec.PALETTE_BYTES),zeros(spec.MENU_PALETTE_BYTES)
 for _,panel in ipairs(spec.PANELS)do for i=0,spec.PANEL_ROWS-1 do map[(panel.row+i)*spec.COLS*2+1]=1 end end
 for i=1,#pal do pal[i]=(i*73)%256 end
 local blobs={[spec.TILES]=tiles,[spec.TILEMAP]=map,[spec.PALETTE]=pal,[spec.MENU_PALETTE]=menu}
 X.lz77ok=function(_,at)return true,blobs[at]end
 Image.blank=function()error('synthetic reader does not bake GPU artwork')end
 local writes=0
 local x=setmetatable({rom={pointer=function()return nil end},_constants={retained=true},beginStage=function()end,
  write=function(_,name,value)T.eq(name,'constants');T.eq(value.retained,true);writes=writes+1 end},X)
 x:extractBattleTextbox();T.eq(writes,1)
 local result=x._constants.gen3BattleTextbox.palette;T.eq(#result,16)
 for i=1,16 do T.eq(result[i],pal[i*2-1]+pal[i*2]*256)end
 local first=result[1];pal[1]=0;T.eq(result[1],first,'raw bytes are detached from the serialized palette')
 pal[#pal]=nil;x._constants={};writes=0;x:extractBattleTextbox()
 T.eq(writes,0,'truncated palette cannot publish indexed metadata');T.eq(x._constants.gen3BattleTextbox,nil)
 T.check(Import.cacheContract(edition).marker:find('gba-textbox-palette-v1:',1,true)~=nil)
end
for _,edition in ipairs{'red','crystal','ruby','sapphire','platinum','black'}do
 local contract=Import.cacheContract(edition)
 if contract then T.eq(contract.marker:find('gba-textbox-palette-v1:',1,true),nil,'unaffected edition cache marker')end
end
X.lz77ok,Image.blank=lz,blank
T.finish('validated native textbox extraction retains the full raw palette and narrows cache revision')
