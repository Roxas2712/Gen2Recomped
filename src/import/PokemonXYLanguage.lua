-- Only act on exact first-run prompt receipts, never on a frame timer alone.
-- Integration by Roxas2712. This preference never edits the game's save.
local M={names={'english','spanish','french','german','italian','japanese','korean'}}
local Json=require('src.link.Json')
function M.path(session)return session.data..'/language-'..session.edition..'.json'end
function M.new(session,emit)
 local file=io.open(M.path(session),'rb');local remembered
 if file then local bytes=file:read(16384);file:close();local ok,v=pcall(Json.decode,bytes);if ok and type(v)=='table'and v.version==1 then for _,name in ipairs(M.names)do if v.language==name then remembered=name end end end end
 local self={remembered=remembered,active=true,seen=false,aDown=false}
 function self:reset()
  local path=M.path(session);local f=io.open(path,'rb')
  if f then f:close();if not os.rename(path,path..'.previous')then emit{event='notice',message='Sprachauswahl konnte nicht zurückgesetzt werden.'};return false end end
  self.remembered=nil;self.active=false;self.plan=nil
  emit{event='notice',message='Sprachauswahl zurückgesetzt. Der nächste ungespeicherte Start fragt wieder.'}
  return true
 end
 function self:remember(name)
  local path=M.path(session);local f=io.open(path..'.pending','wb')
  local written=f and f:write(Json.encode{version=1,language=name});local closed=f and f:close()
  self.active=false;self.plan=nil
  if not written or not closed or not os.rename(path..'.pending',path)then emit{event='notice',message='Sprachauswahl konnte nicht gespeichert werden. Beim nächsten Start bitte erneut wählen.'};return false end
  self.remembered=name
  emit{event='notice',message='Sprachauswahl für '..session.edition:upper()..' gemerkt.'}
  return true
 end
 function self:buttons(stage,buttons,n)
  if not self.active then return buttons end
  local bit=require('bit');local a=bit.band(buttons,1)~=0
  if stage>0 then self.seen=true end
  if stage>=2 and a and not self.aDown then self:remember(M.names[stage-1]);return buttons end
  self.aDown=a
  if not self.seen and n>1200 then self.active=false;return buttons end
  if self.remembered and stage==1 and not self.started then
   self.started=true;self.plan={}
   for i,name in ipairs(M.names)do if name==self.remembered then
    for _=1,i-1 do self.plan[#self.plan+1]={128,3};self.plan[#self.plan+1]={0,3}end
   end end
   self.plan[#self.plan+1]={1,3};self.plan[#self.plan+1]={0,12}
  end
  if self.committing and self.plan and #self.plan==0 then self:remember(self.committing);return buttons end
  if self.plan and #self.plan>0 then
   local row=self.plan[1];local answer=row[1];row[2]=row[2]-1
   if row[2]==0 then table.remove(self.plan,1)end
   self.aDown=answer==1;return answer
  end
  if self.started and self.plan and #self.plan==0 then
   if stage>=2 then
    if M.names[stage-1]==self.remembered then self.plan={{1,3},{0,3}};self.started=nil;self.committing=self.remembered;return 1
    else self.plan=nil;self.remembered=nil;self.started=nil end
   end
  end
  return buttons
 end
 return self
end
return M
