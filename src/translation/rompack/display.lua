-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
local D={}
function D.metric(text,def,language)
 if type(text)~='string'or not def then return text end
 local function number(v,unit)
  local s=('%.1f'):format(tonumber(v)or 0)
  if language and language~='en'then s=s:gsub('%.',',')end
  return s..' '..unit
 end
 if text:match('^%d+\'%d%d"?$')then
  return number(def.heightM or def.height,'m')
 elseif text:match('^%d+[.,]%d lbs%.?$')or text:match('^%d+[.,]%d kg%.?$')then
  -- FRLG's localized native page table can already say kg while its host
  -- consumer still supplies the original pounds value. Use species data.
  return number(def.weightKg or def.weight,'kg')
 elseif text:match('^%?+\'%?+"?$')then return '?.? m'
 elseif text:match('^%?+%.%? lbs%.?$')or text:match('^%?+%.%? kg%.?$')then return '???.? kg'end
 return text
end
function D.install(mod)
 local Entry=require('src.ui.Gen3DexEntry');local FRLG=require('src.ui.Gen3PokedexFRLG');local Font=require('src.render.Font');local Runtime=require('src.mods.Runtime')
 local marker='ula.fork.metric-dex';mod.events:on(marker,function()end)
 local state=Entry.__ulaMetricDisplay
 if not state then
  state={draw=Entry.draw,frlgDraw=FRLG.drawEntry};Entry.__ulaMetricDisplay=state
  local draw,width=Font.draw,Font.width
  Font.draw=function(text,...)
   return draw(state.live and state.live()and D.metric(text,state.def,state.language)or text,...)
  end
  Font.width=function(text,...)
   return width(state.live and state.live()and D.metric(text,state.def,state.language)or text,...)
  end
  local code=Font.drawCode
  Font.drawCode=function(c,x,y,...)
   -- FireRed draws its inch quote separately, at the height row's baseline.
   if state.live and state.live()and state.localized and state.frlg and c==0xB2 and y==60 then return end
   return code(c,x,y,...)
  end
  local function render(fn,self,frlg,...)
   if not(state.live and state.live()and state.localized)then return fn(self,...)end
   local previous,previousFrlg=state.def,state.frlg;state.def=self.def;state.frlg=frlg
   local ok,value=pcall(fn,self,...);state.def=previous;state.frlg=previousFrlg
   if not ok then error(value,0)end
   return value
  end
  Entry.draw=function(self,...)return render(state.draw,self,false,...)end
  FRLG.drawEntry=function(self,...)return render(state.frlgDraw,self,true,...)end
 end
 local bus=Runtime.events;state.live=function()return Runtime.events==bus and Runtime.wants(marker)end
 return {set=function(_,language)state.localized=language~='en';state.language=language end}
end
return D
