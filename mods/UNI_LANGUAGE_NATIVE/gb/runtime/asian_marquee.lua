-- Scroll in rendered glyphs, so UTF-8 and multi-character font macros stay whole.
return function(active)
 local M=require('src.ui.Marquee');local Font=require('src.render.Font')
 local p=M.__ulaAsianMarquee
 if not p then
  p={at=M.at,clip=M.clip};M.__ulaAsianMarquee=p
  local function slice(text,spans,first,last)
   if not spans[first] or last<first then return '' end
   return text:sub(spans[first].from,spans[math.min(last,#spans)].to)
  end
  M.clip=function(text,room)
   if not p.active()then return p.clip(text,room)end
   text=text or '';return slice(text,Font.split(text),1,room)
  end
  M.at=function(text,room,elapsed)
   if not p.active()then return p.at(text,room,elapsed)end
   text=text or '';local spans=Font.split(text);local over=#spans-room
   if over<=0 then return text end
   local now=elapsed%(M.HOLD*2+over*M.STEP);local offset
   if now<M.HOLD then offset=0
   elseif now<M.HOLD+over*M.STEP then offset=math.floor((now-M.HOLD)/M.STEP)
   else offset=over end
   return slice(text,spans,offset+1,offset+room)
  end
 end
 p.active=active
end
