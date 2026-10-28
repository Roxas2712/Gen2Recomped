local function F(...) return require('src.translation.Service').launcherFormat(...) end
local function L(value) return require('src.translation.Service').launcherLookup(value) end
local V={}
local GOLD={245,196,98}
local function icon(kind,x,y,s)
 local g=love.graphics;g.push('all');g.setColor(1,.79,.32);g.setLineWidth(3*s)
 if kind=='egg' then g.ellipse('line',x,y,15*s,21*s);g.circle('fill',x-5*s,y-4*s,4*s);g.circle('fill',x+6*s,y+9*s,3*s)
 elseif kind=='bolt' then g.polygon('fill',x+5*s,y-23*s,x-15*s,y+3*s,x-2*s,y+3*s,x-7*s,y+23*s,x+16*s,y-5*s,x+2*s,y-5*s)
 elseif kind=='band' then g.rectangle('line',x-19*s,y-12*s,38*s,24*s,6*s);g.rectangle('fill',x-6*s,y-15*s,12*s,30*s,3*s)
 elseif kind=='bell' then g.arc('line','open',x,y-4*s,17*s,math.pi,2*math.pi);g.line(x-17*s,y-4*s,x-20*s,y+13*s,x+20*s,y+13*s,x+17*s,y-4*s);g.circle('fill',x,y+20*s,4*s)
 elseif kind=='claw' then for i=-1,1 do g.line(x+i*13*s,y+18*s,x+i*10*s,y-12*s,x+i*8*s+7*s,y-20*s) end
 else g.circle('fill',x,y+3*s,17*s);g.setColor(.39,.85,.55);g.ellipse('fill',x+8*s,y-18*s,10*s,4*s) end
 g.pop()
end
function V.draw(self,f,x,y,w,text,button)
 local s,g=self._s,love.graphics;local doc=f.shop
 text('THE ARENA EXCHANGE',true,self.palette().ink)
 text(F('%d LIGA COINS',doc.coins),true,GOLD)
 text(F('+%d per win / +%d per loss · %d%% winner item-drop chance',doc.win_coins,doc.loss_coins,doc.drop_percent))
 text(doc.notice);button('BACK TO THE ARENA','shopBack');button('REFRESH WALLET & PURCHASES','shop')
 local edition=f.shopEdition or 'crystal'
 button(L('ITEM EDITION: ')..edition:upper()..L(' · CLICK TO CHANGE'),'shopEdition')
 button('COLLECT ALL PURCHASES & DROPS INTO ITEM BANK','shopCollect')
 if f.shopPending then button(L('RETRY PENDING PURCHASE: ')..f.shopPending.item,'shopRetry') end
 if f.shopConfirm then
  local c=f.shopConfirm;text('CONFIRM PURCHASE',true,self.palette().link)
  text(F('%s · %d coins · %s',L(c.title),c.price,edition:upper()))
  button('BUY & KEEP IN MY ACCOUNT','shopConfirm');button('CANCEL','shopCancel')
 else
  for _,row in ipairs(doc.catalogue or {}) do
   local supported=require('src.core.GameVersion').generation(edition)>=row.generation
   -- The item art is drawn in native UI units and remains sharp at any DPI.
   local at=y();local h=145*s;local p=require('src.import.LauncherLibrary').paint
   p.surface(x,at,w,h,12*s,supported and GOLD or self.palette().detail,false)
   icon(row.icon,x+42*s,at+43*s,s)
   text(F('%s · %d COINS',L(row.title),row.price),true,supported and self.palette().ink or self.palette().detail,80*s)
   text(F('GEN %d+ · %s',row.generation,L(row.description)),false,nil,80*s)
   button(supported and (doc.coins>=row.price and 'CHOOSE ITEM' or 'MORE COINS NEEDED') or 'UNAVAILABLE IN THIS EDITION','shopBuy:'..row.id)
  end
 end
 text(f.notice)
 text('RECENT MATCH REWARDS',true,self.palette().link)
 for _,entry in ipairs(doc.earnings or {}) do text(F('%s · +%d coins · %s',L(entry.outcome:upper()),entry.coins,entry.created_at)) end
 if #(doc.earnings or {})==0 then text('Finish a native league battle to earn your first coins.') end
end
return V
