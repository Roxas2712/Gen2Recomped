-- Inspect canvas size before allocating decoded pixels from downloaded art.
local M={}
function M.size(bytes)
  if type(bytes)~='string' then return end
  local function be(i,n) local v=0;for p=i,i+n-1 do local b=bytes:byte(p);if not b then return end;v=v*256+b end;return v end
  local function le(i,n) local v=0;for p=i+n-1,i,-1 do local b=bytes:byte(p);if not b then return end;v=v*256+b end;return v end
  if bytes:sub(1,8)=='\137PNG\13\10\26\10' and bytes:sub(13,16)=='IHDR' then return be(17,4),be(21,4) end
  if bytes:sub(1,3)=='GIF' then return le(7,2),le(9,2) end
  if bytes:sub(1,4)=='RIFF' and bytes:sub(9,12)=='WEBP' then
    local chunk=bytes:sub(13,16)
    if chunk=='VP8X' then local w,h=le(25,3),le(28,3);if w and h then return w+1,h+1 end
    elseif chunk=='VP8 ' and bytes:sub(24,26)=='\157\1\42' then local w,h=le(27,2),le(29,2);if w and h then return w%16384,h%16384 end
    elseif chunk=='VP8L' and bytes:byte(21)==47 and #bytes>=25 then
      local a,b,c,d=bytes:byte(22,25);return 1+a+(b%64)*256,1+math.floor(b/64)+c*4+(d%16)*1024
    end
  end
  if bytes:sub(1,2)=='\255\216' then
    local p=3
    while p<#bytes do
      if bytes:byte(p)~=255 then return end
      while bytes:byte(p)==255 do p=p+1 end
      local marker=bytes:byte(p);p=p+1
      if not marker then return end
      if marker==217 or marker==218 then return end
      if marker~=216 and marker~=1 and not (marker>=208 and marker<=215) then
        local length=be(p,2);if not length or length<2 or p+length-1>#bytes then return end
        if marker>=192 and marker<=207 and marker~=196 and marker~=200 and marker~=204 then return be(p+5,2),be(p+3,2) end
        p=p+length
      end
    end
  end
end
function M.allowed(bytes,limit)
  local w,h=M.size(bytes)
  return w and h and w>=1 and h>=1 and w<=limit and h<=limit or false
end
return M
