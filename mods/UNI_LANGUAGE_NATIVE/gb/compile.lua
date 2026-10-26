return function(rom,p,root,own,dependencies)
 local S=require('src.core.SaveSerializer')
 local I=require('src.import.ImageWriter')
 local R=dependencies and dependencies.Rom or require('src.import.Rom')
 local files,report={}, {dialogue=0,assets=0,catalogs={},language=p.language or 'de'}
 local function decode(r)
  if r.format then
   local text=decode(r.format)
   if r.parameters then
    text=text:gsub('{([A-Z]+)}',function(token)
     if token=='DONE' or token=='PROMPT'then return ''end
     return assert(r.parameters[token],'Unbound native template field '..token)
    end)
   end
   return (text:gsub('{DONE}',''):gsub('{PROMPT}',''):gsub('^[\n\r\v\f]+',''):gsub('[\n\r\v\f]+$',''))
  elseif r.parts then
   local out={}
   for _,part in ipairs(r.parts) do
    if part.token then out[#out+1]=part.token elseif part.number then out[#out+1]=('%0'..part.width..'d'):format(part.number) else
     assert(part.off>=0 and part.off+part.size<=#rom,'Text span outside ROM')
     local chars={}
     local j,last=part.off+1,part.off+part.size
     while j<=last do
      local first=rom:byte(j);local code=tostring(first);j=j+1
      if p.encoding=='korean-gen2' and first>=1 and first<=11 then
       assert(j<=last,'Truncated Korean character in text recipe')
       code=code..':'..rom:byte(j);j=j+1
      end
      chars[#chars+1]=assert(p.charmap[code],'Unknown ROM character '..code)
     end
     out[#out+1]=table.concat(chars)
    end
   end
   return table.concat(out)
  elseif r.tilemap then
   local b=r.tilemap;assert(b.off>=0 and b.size>0 and b.off+b.size<=#rom,'Tilemap outside ROM')
   assert(b.cells>0 and b.cells<=360 and b.fill>=0 and b.fill<=255,'Invalid tilemap dimensions')
   local out={};local i,last=b.off+1,b.off+b.size;local terminated=false
   while i<=last do
    local tile=rom:byte(i);i=i+1
    if tile==255 then assert(i==last+1,'Trailing tilemap bytes');terminated=true;break end
    local count=1
    if b.rle then assert(i<=last,'Truncated tilemap run');count=rom:byte(i);i=i+1;assert(count>0,'Empty tilemap run')end
    assert(#out+count<=b.cells,'Tilemap overflow')
    for _=1,count do out[#out+1]=tile end
   end
   assert(terminated,'Unterminated tilemap')
   while #out<b.cells do out[#out+1]=b.fill end
   return out
  elseif r.bytes then
   local b=r.bytes;assert(b.off>=0 and b.off+b.size<=#rom,'Byte recipe outside ROM')
   return {rom:byte(b.off+1,b.off+b.size)}
  elseif r.empty then return ''
  elseif r.array then local out={};for i,v in ipairs(r.array) do out[i]=decode(v) end;return out
  elseif r.table then local out={};for _,v in ipairs(r.table) do out[v[1]]=decode(v[2]) end;return out
  else return r.value end
 end
 for _,cat in ipairs(p.catalogs) do
  local data=decode(own(root..cat))
  local n=0;for _ in pairs(data) do n=n+1 end
  report.catalogs[cat]=n
  if cat=='dialogue.lua' then report.dialogue=n end
  files['lang/'..cat]=S.encode(data)
 end
 files['lang/charmap.lua']=S.encode(p.fontmap)
 for _,name in ipairs({'runtime_patterns','runtime_system_patterns'}) do files['lang/'..name..'.lua']=S.encode({}) end
 local streams={}
 for path,r in pairs(own(root..'assets.lua')) do
  local raw={}
  for _,t in ipairs(r.tiles) do
   assert(t.off>=0 and t.off+t.size<=#rom,'Graphics span outside ROM')
   local data
   if t.lz then
    if not streams[t.off] then streams[t.off]=R.decompressLz3(rom:sub(t.off+1,t.off+t.size)) end
    local source=streams[t.off];data={}
    for j=t.start+1,t.start+t.length do data[#data+1]=assert(source[j]) end
   else
    local start=t.off+(t.start or 0)
    data={rom:byte(start+1,start+(t.length or t.size))}
   end
   for _,b in ipairs(data) do raw[#raw+1]=b end
  end
  local image=(r.bits==1 and I.decode1bpp or I.decode2bpp)(raw,r.width,r.height,r.transparent)
  if r.palettes then
   for index,t in ipairs(r.tiles) do
    local tx=((index-1)%(r.width/8))*8;local ty=math.floor((index-1)/(r.width/8))*8
    local shades={}
    for y=0,7 do for x=0,7 do shades[y*8+x+1]=image:getPixel(tx+x,ty+y) end end
    for y=0,7 do for x=0,7 do
     local red=shades[(t.flipY and 7-y or y)*8+(t.flipX and 7-x or x)+1];local c=t.palette[4-math.floor(red*3+0.5)]
     image:setPixel(tx+x,ty+y,c[1]/255,c[2]/255,c[3]/255,c[4]/255)
    end end
   end
  end
  if r.matte then image=I.matteColor0(image) end
  if r.ink then image:mapPixel(function(_,_,red) return 0,0,0,red<0.5 and 1 or 0 end) end
  -- Authored labels are tiny monochrome masks, applied at compile time.
  -- They never run in the frame loop and cannot change metatile geometry.
  for _,patch in ipairs(r.authoredPixels or {}) do
   assert(patch.x>=0 and patch.y>=0 and patch.y+#patch.rows<=r.height,'Label outside graphics sheet')
   for y,row in ipairs(patch.rows) do
    assert(patch.x+#row<=r.width,'Label outside graphics sheet')
    for x=1,#row do
     local pixel=row:sub(x,x);assert(pixel=='0' or pixel=='1','Invalid label pixel')
     local color=patch.colors and patch.colors[tonumber(pixel)+1]
     if color then image:setPixel(patch.x+x-1,patch.y+y-1,unpack(color))
     else image:setPixel(patch.x+x-1,patch.y+y-1,0,0,0,pixel=='1' and 1 or 0) end
    end
   end
  end
  files[path]=image:encode('png'):getString();report.assets=report.assets+1
 end
 return {files=files,report=report,operations={{registry='strings',method='override',key='__rom_language_source_gb__',value='active'}}}
end
