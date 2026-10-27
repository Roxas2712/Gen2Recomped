-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cartridge windows and native panel drawing share the admitted battle owner.
local Native=require('src.battle.Gen3Battle')
local Battle=require('src.core.game3.battle')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Call=require('src.compat.gen1.SourceCall')
local Scope=require('src.render.GraphicsScope')
local Version=require('src.core.GameVersion')
local C={WIN={MSG=0,ACTION_PROMPT=1,ACTION_MENU=2,MOVE_NAME_1=3,MOVE_NAME_2=4,MOVE_NAME_3=5,
 MOVE_NAME_4=6,PP=7,DUMMY=8,PP_REMAINING=9,MOVE_TYPE=10,SWITCH_PROMPT=11,YESNO=12,LEVEL_UP_BOX=13,LEVEL_UP_BANNER=14}}
local function owner()
 local screen=Battle._screen();if screen then return screen end
 local g=require('src.compat.gen1.NativeSession').game()
 return g and{game=g,data=g.data}
end
function C.layout()
 local v=Version.get();return(v=='ruby'or v=='sapphire')and'rs'or v=='emerald'and'emerald'or'frlg'
end
function C.isHoenn()return C.layout()~='frlg'end
function C.window(id)
 assert(type(id)=='number'and id%1==0 and id>=0 and id<=14,'invalid battle window')
 local s=owner();if not s then return nil,'no native GBA owner'end
 local c=s.data.constants;local rec=c.gen3BattleWindows
 local row=rec and rec.templates and rec.templates[id+1]
 if not row and rec then
  row=({[0]=rec.message,rec.prompt,rec.action})[id]
  if id>=3 and id<=6 then row=rec.moves and rec.moves[id-2]end
 end
 if not row then return nil,'window not present in imported native templates'end
 local w,h=row.width or row.w,row.height or row.h
 if Battle._screen()==s and id<=6 then
  local windows=Native.windows(s)
  local frame=({[0]=windows.message,windows.prompt,windows.action})[id]
  if id>=3 then frame=windows.moves and windows.moves[id-2]end
  if frame then return{left=frame.textX/8,top=frame.row1/8,w=frame.cols or frame.tw-2,h=frame.th-2,x=frame.textX,y=frame.row1}end
 end
 return{left=row.left,top=row.top%20,w=w,h=h,x=row.left*8,y=(row.top%20)*8}
end
function C.textOrigin(id)
 local w,why=C.window(id);if not w then return nil,why end
 local dx=id==1 and 1 or id==9 and 2 or 0
 return w.x+dx,w.y+1,w.w*8,id>=3 and id<=7 or id==10 or id==11
end
function C.messageOrigin()
 if C.layout()~='emerald'then return 10,122,224 end
 return C.textOrigin(C.WIN.MSG)
end
local function colorRecord(fg,shadow)
 -- Numeric aliases retain the earlier foreground/shadow tuple contract.
 -- Return detached values: presentation callers cannot edit imported data.
 local a={fg[1],fg[2],fg[3],fg[4]or 1}
 local b={shadow[1],shadow[2],shadow[3],shadow[4]or 1}
 return{a[1],a[2],a[3],a[4],fg=a,shadow=b,bg={0,0,0,0}},b
end
local function colorIndex(value)
 assert(type(value)=='number'and value%1==0 and value>=0 and value<16,'invalid native textbox colour index')
 return value
end
local function packedColor(value)
 local r,g,b=require('src.render.Gen3IndexedPalette').rgb(value)
 local function channel(n)return(n*8+math.floor(n/4))/255 end
 return{channel(r),channel(g),channel(b),1}
end
local function packedPalette(palette)
 if type(palette)~='table'or #palette~=16 then return end
 for i=1,16 do
  local v=palette[i]
  if type(v)~='number'or v%1~=0 or v<0 or v>65535 then return end
 end
 return palette
end
function C.textboxColors(fg,shadow)
 local explicit=fg~=nil or shadow~=nil
 fg,shadow=colorIndex(fg==nil and 1 or fg),colorIndex(shadow==nil and 8 or shadow)
 local s=owner();local version=Version.get()
 local gba=version=='firered'or version=='leafgreen'or version=='emerald'or version=='ruby'or version=='sapphire'
 local constants=gba and s and s.data and s.data.constants or{}
 if not explicit and s and gba then
  local a,b=Native.textColors(s,'message')
  if a and b then return colorRecord(a,b)end
 end
 local rs=version=='ruby'or version=='sapphire'
 local record
 if rs then record=constants.gen3RsBattlePanel else record=constants.gen3BattleTextbox end
 if rs and not(type(record)=='table'and record.format==1 and record.version==version)then record=nil end
 local palette=type(record)=='table'and packedPalette(record.palette)
 if palette then return colorRecord(packedColor(palette[fg+1]),packedColor(palette[shadow+1]))end
 -- Older native imports retain named role colours. They are authoritative
 -- only for that role's exact indices (or the legacy no-argument query).
 local role=not rs and type(record)=='table'and record.text and record.text.message
 local indices=role and role.indices
 if s and gba and type(indices)=='table'and indices.fg==fg and indices.shadow==shadow then
  local a,b=Native.textColors(s,'message')
  if a and b then return colorRecord(a,b)end
 end
 local white=require('src.ui.game3.frlg_font').COLOR.WHITE
 local colors,second=colorRecord(white.fg,white.shadow)
 return colors,second,'native textbox palette unavailable'
end
function C.manifest()
 local s=owner();if not s then return nil,'no native GBA owner'end
 local c=s.data.constants;local text=Native.textbox(s)
 local copy=require('src.mods.Merge').deepCopy
 local version=Version.get();local rs=version=='ruby'or version=='sapphire'
 local textboxPal,windowPal,ppPal
 if rs then
  local panel,bag=c.gen3RsBattlePanel,c.gen3RsBag
  if type(panel)=='table'and panel.format==1 and panel.version==version then textboxPal=packedPalette(panel.palette)end
  if type(bag)=='table'and bag.format==1 and bag.version==version then windowPal=packedPalette(bag.palette);ppPal=windowPal end
 elseif Version.generation(version)==3 and text then
  textboxPal=packedPalette(text.palette);windowPal=packedPalette(text.windowPalette);ppPal=packedPalette(text.ppPalette)
 end
 local templates={}
 for id=0,14 do local row=C.window(id);if row then templates[id+1]={left=row.left,top=row.top,w=row.w,h=row.h}end end
 return{layout=C.layout()=='frlg'and'frlg'or'rse',assetLayout=C.layout(),
  windows={normal=templates},
  text=copy(text and text.text or{}),textboxPal=copy(textboxPal),windowTextPal=copy(windowPal),ppTextPal=copy(ppPal),native=true}
end
local function partyPhase(player)return'battle.partySummary.'..(player and'player'or'enemy')end
function C.drawPartyBar(x,y,balls,ox,opponent,opts)
 assert(opponent==nil or type(opponent)=='boolean','invalid party summary side')
 for _,value in pairs{x=x,y=y,ox=ox}do
  assert(type(value)=='number'and value==value and math.abs(value)<math.huge,'invalid party summary position')
 end
 assert(balls==nil or type(balls)=='table','invalid party summary slots')
 assert(opts==nil or type(opts)=='table','invalid party summary options')
 local player=not opponent;local phase=partyPhase(player)
 if Boundary.active(phase)then return Boundary.invoke(phase)end
 local screen=Battle._screen();if not screen then return false,'no native battle'end
 opts=opts or{}
 local ok,drawn=Scope.call(function()
  return Native.paintPartySummary(screen,player,{x=x,y=y,ox=ox,slots=balls,
   alpha=opts.alpha,ballHidden=opts.ballHidden,ballOx=opts.ballOx,extended=opts.extended})
 end)
 if not ok then error(drawn,0)end
 return drawn
end
local basePartyBar=C.drawPartyBar
function C._nativePartySummary(screen,player,body)
 if C.drawPartyBar==basePartyBar then return body()end
 local phase=partyPhase(player)
 if Boundary.active(phase)then return Boundary.invoke(phase)end
 local stage=require('src.core.game3.battle.stage').current(Call.owner(C,'drawPartyBar'))
 local bar=stage and stage.partyBar[player and'player'or'enemy']
 if not bar or not bar.visible then return body()end
 local ok,result=Scope.call(function()
  return Boundary.dispatch(phase,body,function()
   return Call.call(C,'drawPartyBar',bar.x,bar.y,bar.balls,bar.ox,not player,bar)
  end)
 end)
 if not ok then error(result,0)end
 return result
end
local modes={none='message',menu='action',moves='moves'}
local painted
local function serial()local r=package.loaded['src.render.Renderer'];return r and r.frameSerial end
function C.drawPanel(mode)
 assert(modes[mode],'invalid battle panel mode')
 local screen=Battle._screen();if not screen then painted=nil;return false,'no native battle'end
 local drawn,included
 if Boundary.active('battle.panel')then drawn=Boundary.invoke('battle.panel');included=drawn==true
 else drawn,included=require('src.battle.Gen3BattleFrames').panel(screen,modes[mode])end
 if drawn then
  painted={refs=setmetatable({screen},{__mode='v'}),view=Battle.getState(),mode=mode,
   target=Battle._renderTarget(),token=Scope.token(),serial=serial(),frame=screen.frame,included=included}
 else painted=nil end
 return drawn
end
function C.drawMenuFrames(mode)
 assert(modes[mode],'invalid battle panel mode')
 local screen=Battle._screen();if not screen then painted=nil;return false,'no native battle'end
 local receipt=painted;painted=nil
 local same=receipt and receipt.refs[1]==screen and receipt.view==Battle.getState()
  and receipt.mode==mode and receipt.frame==screen.frame and Battle._sameRenderTarget(receipt.target,Battle._renderTarget())
 if same then
  if receipt.serial~=nil then same=receipt.serial==serial()
  else same=receipt.token~=nil and receipt.token==Scope.token()end
 end
 local included=same and receipt.included or false
 local ok,drawn,count=Scope.call(function()return require('src.battle.Gen3BattleFrames').draw(screen,modes[mode],included)end)
 if not ok then error(drawn,0)end
 return drawn,count
end
C._service={release=function()painted=nil end,releaseOwner=function()painted=nil end,
 poll=function()
  if not painted then return end
  local screen=painted.refs[1]
  if not screen or screen~=Battle._screen()or painted.view~=Battle.getState()or painted.frame~=screen.frame then painted=nil end
 end}
require('src.core.game3.asset_stream').register(C._service)
local basePanel=C.drawPanel
function C._panel(screen,which,body)
 if C.drawPanel==basePanel then return body()end
 local mode=which=='action'and'menu'or which=='moves'and'moves'or'none'
 local ok,result=Scope.call(function()
  Boundary.dispatch('battle.panel',body,function()return Call.call(C,'drawPanel',mode)end)
 end)
 if not ok then error(result,0)end
 -- A presentation wrapper owns the panel even if its painter returns nil.
 return true
end
return C
