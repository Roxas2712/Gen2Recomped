-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Locations of gStdStrings/gStdStringPtrs in the admitted cartridges.
-- Names themselves are read from the user's ROM, including edition differences.
local M={REVISION=1}
local profiles={
 ruby={sha1='f28b6ffc97847e94a6c21a63cacf633ee5c8df1e',at=0x3CE048,count=19},
 sapphire={sha1='3ccbbd45f8553c36463f13b938e833f652b793e4',at=0x3CE0A0,count=19},
 emerald={sha1='f3ae088181bf583e55daf962a92bb46f4f1d07b7',at=0x58BAF0,count=30},
 firered={sha1='41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc',at=0x3E06B8,count=29},
 leafgreen={sha1='574fa542ffebb14be69902d1d36f1ec0a4afd71e',at=0x3E04F4,count=29},
}
function M.profile(edition,sha1)
 local p=profiles[edition];if p and p.sha1==sha1 then return p end
end
function M.valid(record,edition)
 local p=type(record)=='table'and M.profile(edition,record.romSha1)
 if not(p and record.format==M.REVISION and record.edition==edition
   and record.tableAddress==p.at and record.count==p.count and type(record.strings)=='table')then return false end
 for i=0,p.count-1 do
  if type(record.strings[i])~='string'or record.strings[i]==''then return false end
 end
 return true
end
function M.extract(rom,manifest,sha1,edition,decode)
 local p=M.profile(edition,sha1)
 if not(p and manifest and manifest.romSha1==sha1 and type(decode)=='function')then
  return nil,'unverified standard-string cartridge'
 end
 local ok,result=pcall(function()
  assert(p.at+p.count*4<=rom.size,'Standard-string table exceeds ROM')
  local out={format=M.REVISION,edition=edition,romSha1=sha1,tableAddress=p.at,count=p.count,strings={}}
  for i=0,p.count-1 do
   local at=assert(rom:pointer(p.at+i*4),'Invalid standard-string pointer')
   local length
   for j=0,63 do
    assert(at+j<rom.size,'Standard string exceeds ROM')
    if rom:u8(at+j)==255 then length=j;break end
   end
   assert(length and length>0,'Unterminated or empty standard string')
   local text=decode(at,length+1)
   assert(type(text)=='string'and text~=''and not text:find('{BYTE:',1,true),'Invalid standard-string text')
   out.strings[i]=text
  end
  return out
 end)
 if not ok then return nil,tostring(result)end
 return result
end
function M.lookup(record,edition,index)
 if not M.valid(record,edition)or type(index)~='number'or index%1~=0 or index<0 or index>=record.count then return nil end
 return record.strings[index]
end
function M.missing(edition)
 if not profiles[edition]then return{}end
 local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
 local f=raw and loadstring(raw);if f then setfenv(f,{})end
 local ok,c=false,nil;if f then ok,c=pcall(f)end
 return M.valid(ok and type(c)=='table'and c.gen3StandardStrings,edition)and{}or{'<gba:standard-script-strings>'}
end
return M
