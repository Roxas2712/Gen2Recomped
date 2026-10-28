-- Same module-page hierarchy as the normal library, with native Pinball saves.
-- Contributions by Roxas2712.
local M={};local S=require('src.core.Strings')
function M.draw(self,RI,x,y,w,session,preview,actions,register)
 local s,g=self._s,love.graphics;local L=require('src.import.LauncherLibrary');local paint=L.paint;local P=RI.palette()
 local top=y;local gap,pad=14*s,16*s
 local function text(value,tx,ty,tw,font,color)paint.text(self,font or self.hintFont,S(value),tx,ty,tw,color)end
 local function chip(label,tx,ty,tw,action,enabled)
  local r=self:_chipButton(tx,ty,label,{w=tw,h=36*s,kind='accent',enabled=enabled})
  if enabled~=false then register(r,action)end
 end
 local function surface(tx,ty,tw,th,hot)if paint.surface then paint.surface(tx,ty,tw,th,14*s,P.link,hot)end end
 if self._sb and self._sb.back then register(self._sb.back,actions.back)
 else chip('‹',x,y,42*s,actions.back);y=y+44*s end
 local small=w<650*s;local hero=(small and 300 or 206)*s
 local artW=math.min(w*.2,146*s);local left=small and w or math.max(artW+210*s,w*.55)
 surface(x,y,w,hero)
 if preview then
  g.push('all')
  if g.intersectScissor then g.intersectScissor(x+w*.5,y,w*.5,hero)else g.setScissor(x+w*.5,y,w*.5,hero)end
  local scale=math.max(w*.5/preview:getWidth(),hero/preview:getHeight())
  g.setColor(1,1,1,.68);g.draw(preview,x+w*.75-preview:getWidth()*scale/2,y+(hero-preview:getHeight()*scale)/2,0,scale,scale)
  g.pop()
 end
 -- A solid left surface preserves the title/action contrast in every theme.
 g.setColor(.025,.04,.06,.95);g.rectangle('fill',x,y,math.min(left,w),hero)
 require('src.import.LauncherHardware').cartridge(self,'pinballrs',x+pad+artW/2,y+hero/2,artW,156*s)
 local tx=x+artW+pad*2;local tw=math.min(w-pad-(tx-x),math.max(190*s,left-(tx-x)-pad))
 text('Pokémon Pinball',tx,y+pad,tw,self.gameNameFont)
 text('Ruby & Sapphire',tx,y+52*s,tw,self.tabLabelFont,P.link)
 if session then
  self:_playButton(tx,y+hero-(small and 110 or 62)*s,tw,44*s,'Pokémon Pinball',true,false)
  local r=self.playButtonRect;self.playButtonRect=nil;register(r,actions.play)
 end
 chip('ORIGINAL CARTRIDGE IMAGE',tx,y+83*s,tw,actions.design)
 local iw=math.min(190*s,w*.33)
 g.setColor(.025,.04,.06,.94);g.rectangle('fill',x+w-iw-pad,y+hero-58*s,iw,36*s,8*s,8*s)
 chip(session and 'Re-import ROM'or 'Import ROM',x+w-iw-pad,y+hero-58*s,iw,actions.import)
 y=y+hero+24*s
 text(session and 'BETA / READY TO PLAY'or 'BETA / ROM REQUIRED',x,y,w,self.stateFont,session and P.link or P.warning);y=y+38*s
 if not session then return y-top end
 local col=(w-gap)/2;local narrow=col<250*s
 local rightX=narrow and x or x+col+gap;local rightY=narrow and y+172*s+gap or y
 local lw=narrow and w or col
 surface(x,y,lw,172*s)
 text('SAVE FILES',x+pad,y+pad,lw-pad*2,self.labelFont,P.detail)
 local bw=(lw-pad*2-10*s)/2
 chip('Import save',x+pad,y+51*s,bw,actions.saveImport)
 chip('Export save',x+pad+bw+10*s,y+51*s,bw,actions.saveExport,actions.saved)
 text('Native SRAM · separate saves per language',x+pad,y+100*s,lw-pad*2,nil,P.detail)
 text('F5 / F8 · exact quick state',x+pad,y+127*s,lw-pad*2,nil,P.detail)
 local rw=narrow and w or col;local count=#actions.profiles;local rh=58*s+count*52*s
 surface(rightX,rightY,rw,rh)
 text('SAVE SLOT',rightX+pad,rightY+pad,rw-pad*2,self.labelFont,P.detail)
 for i,row in ipairs(actions.profiles)do
  local ry=rightY+48*s+(i-1)*52*s
  chip((row.selected and '✓ 'or '')..row.name..(row.saved and ' · SRAM'or ''),rightX+pad,ry,rw-pad*2,row.select)
 end
 y=math.max(y+172*s,rightY+rh)+24*s
 return y-top
end
return M
