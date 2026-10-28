-- Explicit local notice acceptance. This is not a third-party content licence.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local E={VERSION=1,FILE='minigames/enrollment.lua'}
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local Safety=require('src.core.SaveSafety')
local T=require('src.pokewalker.minigames.Locale')
E.BODY={
 'Minigames may use additional graphics, sounds and other content. Third-party content and trademarks remain with their respective rights holders. This project claims no ownership of them.',
 'Use additional files only when you are permitted to use them for the intended purpose. A local import, a free download or this confirmation does not grant a licence.',
 'Read and accept these notices before opening the minigames. You can withdraw acceptance in Friends & cloud. This notice does not replace the separate selection and review of optional asset packs.',
}
local function key(catalogue)
 local ids={};for i,id in ipairs(catalogue or{})do ids[i]=id end
 table.sort(ids)
 return S.encode({version=E.VERSION,body=E.BODY,games=ids})
end
function E.accepted(catalogue)
 local fs=Saves.persistenceFs();local raw=fs and fs.read(E.FILE)
 if type(raw)~='string'or #raw>32768 then return false end
 local ok,value=pcall(S.decode,raw)
 return ok and type(value)=='table'and value.schema==1 and value.accepted==true
  and value.version==E.VERSION and value.notice==key(catalogue)or false
end
function E.accept(fs,version,catalogue)
 if not fs or not fs.write then return nil,'The confirmation could not be saved. Minigames remain locked.'end
 if fs~=Saves.persistenceFs()or version~=E.VERSION then return nil,'The profile or notices changed. Read them again before accepting.'end
 local bytes=S.encode({schema=1,version=E.VERSION,notice=key(catalogue),accepted=true,acceptedAt=os.time(),language=require('src.translation.Service').launcherTarget or'en'})
 return Safety.atomicWrite(fs,E.FILE,bytes,{decode=Safety.decodeAny})
end
function E.revoke()
 local fs=Saves.persistenceFs()
 if not fs or not fs.write then return nil,'The confirmation could not be saved. Minigames remain locked.'end
 local ok,why=Safety.atomicWrite(fs,E.FILE,S.encode({schema=1,accepted=false}),{decode=Safety.decodeAny})
 if ok then
  local H=package.loaded['src.ui.WalkerMinigames']
  if H and H.active then H.active:close(true)end
 end
 return ok,why
end
function E.open(hub)
 hub.enrolling=true;hub.gateChecked=false;hub.gateFocus=1
 hub.gateFs=Saves.persistenceFs();hub.gateVersion=E.VERSION;hub.gateNotice=nil
end
function E.action(hub,action)
 if action=='back'or action=='pause'then hub:close(true);return true end
 if action=='up'or action=='left'then hub.gateFocus=(hub.gateFocus-2)%3+1
 elseif action=='down'or action=='right'then hub.gateFocus=hub.gateFocus%3+1
 elseif action=='a'then
  if hub.gateFocus==1 then hub.gateChecked=not hub.gateChecked;hub.gateNotice=nil
  elseif hub.gateFocus==2 then
   if not hub.gateChecked then hub.gateNotice='Read the notices and tick the confirmation first.';return true end
   local ok,why=E.accept(hub.gateFs,hub.gateVersion,hub.GAME_MODULES)
   if not ok then hub.gateNotice=why or 'The confirmation could not be saved. Minigames remain locked.';return true end
   hub.enrolling=nil;hub.hits=nil;hub:_initialize()
  else hub:close(true)end
 end
 return true
end
function E.draw(hub,x,y,w,h)
 local g=love.graphics;local G=require('src.pokewalker.minigames.Gfx')
 local pw=math.min(w-24,760);local px=x+(w-pw)/2;local py=y+12;local ph=h-24
 local file=require('src.translation.Service').launcherFont
 local function font(size)return file and g.newFont(file,size)or g.newFont(size)end
 if not hub.gateFonts or hub.gateFontFile~=file then
  hub.gateFonts={title=font(22),body=font(14),small=font(12)};hub.gateFontFile=file
 end
 local f=hub.gateFonts;local pad=18;local width=pw-2*pad
 G.card(px,py,pw,ph,16,G.CARD,1)
 local heading=T('MINIGAMES · CONTENT NOTICES')
 G.setc(G.GOLD);G.fit(heading,px+pad,py+16,width,f.title,'left')
 local label=T('I have read the notices. I confirm that I am permitted to use any additional files I provide for the intended purpose.')
 local _,lines=f.body:getWrap(label,width-34)
 local ch=math.max(44,#lines*f.body:getHeight()+16)
 local bw=(width-12)/2
 local _,acceptLines=f.body:getWrap(T('ACCEPT & CONTINUE'),bw-12)
 local bh=math.max(44,#acceptLines*f.body:getHeight()+16)
 local by=py+ph-pad-bh;local cy=by-12-ch-22
 local body={};for _,value in ipairs(E.BODY)do body[#body+1]=T(value)end
 body=table.concat(body,'\n\n')
 local ty=py+54;local available=cy-ty-12
 local _,wrapped=f.body:getWrap(body,width);local bodyFont=f.body
 if #wrapped*bodyFont:getHeight()>available then bodyFont=f.small end
 g.setFont(bodyFont);G.setc(G.INK);g.printf(body,px+pad,ty,width,'left')
 local _,finalLines=bodyFont:getWrap(body,width)
 hub.gateLayout={bodyBottom=ty+#finalLines*bodyFont:getHeight(),checkTop=cy,buttonsBottom=by+bh,panelBottom=py+ph}
 hub.hits=G.newHits()
 G.button(hub.hits,px+pad,cy,width,ch,'',function()hub.gateFocus=1;E.action(hub,'a')end,nil,f.body,hub.gateFocus==1 and hub.keyed)
 g.setFont(f.body);G.setc(G.INK)
 g.print(hub.gateChecked and'[x]'or'[ ]',px+pad+8,cy+10)
 g.printf(label,px+pad+32,cy+8,width-40,'left')
 if hub.gateNotice then
  G.setc(G.RED);G.fit(T(hub.gateNotice),px+pad,cy+ch+3,width,f.small,'left')
 end
 local function button(label,xx,focus,kind)
  G.button(hub.hits,xx,by,bw,bh,'',function()hub.gateFocus=focus;E.action(hub,'a')end,kind,f.body,hub.gateFocus==focus and hub.keyed)
  g.setFont(f.body);G.setc(G.INK);g.printf(T(label),xx+6,by+8,bw-12,'center')
 end
 button('ACCEPT & CONTINUE',px+pad,2,hub.gateChecked and'accent'or nil)
 button('BACK WITHOUT ACCEPTING',px+pad+bw+12,3,nil)
end
return E
