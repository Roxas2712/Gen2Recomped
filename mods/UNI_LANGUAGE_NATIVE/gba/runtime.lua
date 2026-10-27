return function(mod,game,active)
 local S=require('src.core.Strings')
 local Zoom=require('src.render.Zoom')
 if not Zoom._ulaOffsetLabel then
  Zoom._ulaOffsetLabel=Zoom.offsetLabel
  Zoom.offsetLabel=function(offset)
   if active() then
    offset=math.floor(tonumber(offset) or 0)
    if offset>0 then return S('IN%d',offset) end
    if offset<0 then return S('OUT%d',-offset) end
   end
   return Zoom._ulaOffsetLabel(offset)
  end
 end
 local FrameCap=require('src.core.FrameCap')
 if not FrameCap._ulaLabel then
  FrameCap._ulaLabel=FrameCap.label
  FrameCap.label=function(value)
   local label=FrameCap._ulaLabel(value)
   if active() then label=label:gsub('^DISPLAY',function()return S('DISPLAY')end) end
   return label
  end
 end
 if game~='firered' and game~='leafgreen' then return end
 -- Retail non-English FRLG copies the native item name at every quantity.
 -- Calling the regular buffer command preserves engine variable resolution
 -- and other hooks without duplicating the script VM's variable rules.
 mod.hooks:wrap('script.command',function(next,ctx,op,row)
  if active() and op=='bufferitemnameplural' then
   local native={}
   for k,v in pairs(row) do native[k]=v end
   native.op='bufferitemname'
   return next(ctx,native.op,native)
  end
  return next(ctx,op,row)
 end)
 local Jump=require('src.core.game3.minigames.pokemon_jump.game')
 -- A process-wide module can outlive a loader. Resolve the current overlay
 -- on each call, including its event owner, bus, game and selected language.
 if not Jump._ulaEnglishPrizeItemName then
  Jump._ulaEnglishPrizeItemName=Jump.prizeItemName
  Jump.prizeItemName=function(itemId,quantity,name)
   local state=active()
   if state and (state.game=='firered' or state.game=='leafgreen')
    and state.display.language~='en' then return tostring(name or '') end
   return Jump._ulaEnglishPrizeItemName(itemId,quantity,name)
  end
 end
end
