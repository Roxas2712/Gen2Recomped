-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Resolve a native resource through an unchanged, unique literal-pool context.
-- Pointer words may move; every surrounding non-pointer word must still agree.
-- Ambiguous contexts are rejected. Inputs and witnesses stay local to the user.
return function(base,target)
 local function word(s,at)
  local a,b,c,d=s:byte(at+1,at+4);if not d then return end
  return a+b*256+c*65536+d*16777216
 end
 local function pointer(n,size)return n and n>=0x08000000 and n<0x08000000+size end
 local function pack(n)return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256)end
 local cache={}
 return function(offset)
  if cache[offset]~=nil then return cache[offset]or nil end
  local needle=pack(0x08000000+offset);local position,answer,refs=1,nil,0
  while refs<32 do
   local hit=base:find(needle,position,true);if not hit then break end
   position=hit+1;refs=refs+1;local at=hit-1
   if at%4==0 then
    for _,radius in ipairs({32,64,128})do
     local first=math.max(0,at-radius);local last=math.min(#base,at+radius+4)
     local mask,runs={},{};local start
     for p=first,last-4,4 do
      local isPointer=pointer(word(base,p),#base);mask[p]=isPointer
      if not isPointer then start=start or p elseif start then runs[#runs+1]={start,p-start};start=nil end
     end
     if start then runs[#runs+1]={start,last-start}end
     table.sort(runs,function(a,b)return a[2]>b[2]end)
     local run=runs[1]
     if run and run[2]>=16 then
      local length=math.min(run[2],48)
      local anchorAt=run[1]+run[2]<=at and run[1]+run[2]-length or run[1]
      local anchor=base:sub(anchorAt+1,anchorAt+length)
      local cursor,matches,found,probes=1,0,nil,0
      for _=1,128 do
       local where=target:find(anchor,cursor,true);if not where then break end;cursor=where+1
       probes=probes+1
       local shifted=where-1-anchorAt;local valid=first+shifted>=0 and last+shifted<=#target
       if valid then for p=first,last-4,4 do
        local dst=word(target,p+shifted)
        if mask[p]then if not pointer(dst,#target)then valid=false;break end
        elseif base:sub(p+1,p+4)~=target:sub(p+shifted+1,p+shifted+4)then valid=false;break end
       end end
       if valid then
        local value=word(target,at+shifted)
        if pointer(value,#target)then matches=matches+1;found=value-0x08000000 end
       end
      end
      if probes==128 and target:find(anchor,cursor,true)then matches=2 end
      if matches==1 then
       if answer and answer~=found then cache[offset]=false;return end
       answer=found;break
      end
     end
    end
   end
  end
  cache[offset]=answer or false;return answer
 end
end
