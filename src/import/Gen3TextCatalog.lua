-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Bind existing address metadata to verified cartridge bytes. The cache owns
-- decoded text and layout operands; no private decoder or ROM is distributed.
local M={REVISION=1}
function M.bind(extractor,text,addresses)
 local rows={schema=M.REVISION,named={},records={}}
 local count=0
 for label,off in pairs(addresses)do
  local isText=type(label)=='string'and(label:match('^[gs]Text_')or label:match('^gOtherText_')
   or label:match('^BattleText_')or label:match('^BattleStatText_')
   or label:match('_Text_')or label:match('^Text_')or label:match('Names%['))
  if isText and type(off)=='number'and off>=0 and off%1==0 and off<extractor.rom.size then
   local id=('TEXT_%06X'):format(off)
   local row=rows.records[id]
   if not row then
    local ok,plain,used,ir=pcall(extractor.readText,extractor,off,4096,nil,true)
    if ok and plain and ir then
     -- Keep the native script decoder's existing value authoritative. The
     -- snapshot lets readers distinguish later registry edits from that value.
     row={plain=plain,ir=ir,nativePlain=text[id],address=off,bytes=used}
     rows.records[id]=row
    end
   end
   if row then rows.named[label]=id;count=count+1 end
  end
 end
 return rows,count
end
function M.extract(extractor,text)
 local Version=require('src.core.GameVersion')
 local edition=type(extractor.version)=='table'and extractor.version.id or extractor.version
 local info=Version.info(edition)
 if not(info and info.generation==3 and extractor.manifest.romSha1==info.sha1)then
  return nil,'named text requires a verified native GBA source'
 end
 local ok,digest=pcall(require('src.import.RomVerification').sha1,extractor.rom.data)
 if not ok or digest~=info.sha1 then return nil,'named text cartridge fingerprint mismatch'end
 -- These GPL address facts already serve native language imports. Preserve
 -- their provenance; the runtime contains only independently decoded results.
 local addresses=require('src.translation.rompack.addresses.'..edition)
 local rows,count=M.bind(extractor,text,addresses)
 rows.edition=edition;rows.romSha1=digest
 return rows,count
end
return M
