-- Native, data-only import review. No package is evaluated as a Lua program.
local M={}
local I=require('src.storage.BankInterop')
local S=require('src.core.SaveSerializer')
local function allowed() return require('src.storage.AccountStorage').check() end
function M.load(self,bytes)
  local ok,why=allowed();if not ok then return nil,why end
  local f=self._bankOverlay;if not f then return nil,'Open the Bank first.' end
  f.interop=nil;f.interopConsent=false;f.interopBytes=nil
  local preview,problem=I.preview(bytes,f.interopVersion)
  if not preview then f.notice=problem;return nil,problem end
  f.interop=preview;f.interopBytes=bytes;f.notice='Package checked. Review the source, Lua fields and blocked records before importing.'
  return true
end
function M.choose(self)
  local f=self._bankOverlay;if not f then return end
  local ok,why=allowed();if not ok then f.notice=why;return end
  local path=self.chooseFileByExt and self.chooseFileByExt({'lua'},'Legacy Bank package')
  if path then
    local file=io.open(path,'rb')
    if not file then f.notice='The selected package could not be read.';return end
    local bytes=file:read(I.MAX_BYTES+1);file:close();return M.load(self,bytes)
  end
  -- Explicit inbox selection works on consoles and mobile without borrowing
  -- the ROM/save picker's asynchronous callback or consuming another import.
  local fs=love.filesystem;fs.createDirectory('imports/bank');f.interopInbox={}
  for _,name in ipairs(fs.getDirectoryItems('imports/bank') or {}) do
    if name:match('^[%w_.%-]+%.lua$') and not name:find('..',1,true) then f.interopInbox[#f.interopInbox+1]=name end
  end
  table.sort(f.interopInbox)
  f.notice=#f.interopInbox>0 and 'Choose a package from the Bank import folder.' or 'Drop a package here, or copy it into imports/bank/ and choose Import again.'
end
function M.draw(self,f,x,y,w,h,s,button,text,col)
  local top=y
  text('LEGACY BANK · LUA DATA INTERCHANGE',x,top,w,true);top=top+38*s
  button('IMPORT PACKAGE',x,top,w*.49,'interopChoose')
  button('EXPORT SELECTED COPY',x+w*.51,top,w*.49,'interopExport');top=top+48*s
  local info='Imports create Bank copies. Original saves and Vaults stay intact. Legacy item inventories and transactions remain in the full archive; they are not automatically equipped.'
  local font=self.hintFont;local _,lines=font:getWrap(info,w)
  love.graphics.setFont(font);col(37,68,79);love.graphics.printf(info,x,top,w,'left');top=top+#lines*font:getHeight()+16*s
  button('SOURCE GAME · '..(f.interopVersion and require('src.core.GameVersion').info(f.interopVersion).label or 'FROM PACKAGE'),x,top,w,'interopVersion');top=top+47*s
  if f.interopInbox then
    for i,name in ipairs(f.interopInbox) do
      if i>12 then break end
      button(name,x,top,w,'interopInbox',{name=name});top=top+42*s
    end
    if #f.interopInbox>12 then text('Showing the first 12 files. Remove reviewed files from the inbox to see more.',x,top,w);top=top+30*s end
  end
  local p=f.interop
  if not p then text('KASC Legacy package v1 / Vault v1–2 and RetroRecomped Bank-copy v1.',x,top,w);return end
  local items=0;for _ in pairs(p.items or {}) do items=items+1 end
  text(('%d Pokémon copies · %d archived item types · %d blocked'):format(#p.entries,items,#p.blocked),x,top,w,true);top=top+36*s
  text('PROVIDER · '..p.provider..' · DATA NODES · '..p.lua.nodes,x,top,w);top=top+30*s
  local fields={};for _,field in ipairs(p.lua.fields) do fields[#fields+1]=field.name..' ('..field.kind..')' end
  local label='LUA FIELDS · '..table.concat(fields,', ')
  local _,fieldLines=font:getWrap(label,w);love.graphics.printf(label,x,top,w,'left');top=top+#fieldLines*font:getHeight()+16*s
  for index,row in ipairs(p.blocked) do
    if index>8 then break end
    local detail=row.id..' · '..row.reason;local _,wrapped=font:getWrap(detail,w)
    love.graphics.printf(detail,x,top,w,'left');top=top+#wrapped*font:getHeight()+8*s
  end
  if #p.blocked>0 then text('Resolve blocked records at their source. Nothing has been imported.',x,top,w);return end
  button(f.interopConsent and '✓ IMPORT COPIES INTO MY ACCOUNT BANK' or '□ IMPORT COPIES INTO MY ACCOUNT BANK',x,top,w,'interopConsent');top=top+46*s
  button('CONFIRM IMPORT',x,top,w,'interopCommit')
end
function M.press(self,r)
  local f=self._bankOverlay
  if not r.action:match('^interop') then return false end
  local ok,why=allowed();if not ok then f.notice=why;return true end
  if r.action=='interopChoose' then M.choose(self)
  elseif r.action=='interopInbox' then
    -- The selected name originates from our bounded listing; validate again
    -- because callers can also invoke the action programmatically.
    if type(r.name)~='string' or not r.name:match('^[%w_.%-]+%.lua$') or r.name:find('..',1,true) then f.notice='Invalid package name.';return true end
    local path='imports/bank/'..r.name;local info=love.filesystem.getInfo(path)
    if not info or not info.size or info.size>I.MAX_BYTES then f.notice='Invalid package size.';return true end
    M.load(self,love.filesystem.read(path));f.interopInbox=nil
  elseif r.action=='interopVersion' then
    local ready={false};for _,v in ipairs(require('src.core.GameVersion').ORDER) do if self.ready[v] then ready[#ready+1]=v end end
    local index=1;for i,v in ipairs(ready) do if v==f.interopVersion then index=i end end
    f.interopVersion=ready[index%#ready+1] or nil
    if f.interopBytes then M.load(self,f.interopBytes) end
  elseif r.action=='interopConsent' then f.interopConsent=not f.interopConsent
  elseif r.action=='interopCommit' then
    local receipt,problem=I.commit(f.interop,f.interopConsent)
    if receipt then f.bank=require('src.storage.PokemonBank').list();f.interopConsent=false;f.notice='Imported '..#receipt.entries..' verified copies. Full Lua archive preserved.' else f.notice=problem end
  elseif r.action=='interopExport' then
    local entry=f.inspected and f.inspected.entry
    if not entry or not entry.id then f.notice='Select a saved Bank Pokémon before exporting its copy and origin information.';return true end
    local api=I.facade('retrorecomped','1');local package,problem=api:export(entry.id,true)
    if not package then f.notice=problem;return true end
    local fs=require('src.core.SaveData').persistenceFs();fs.createDirectory('bank/exports')
    local path='bank/exports/'..entry.id..'.lua'
    local written,err=require('src.core.SaveSafety').atomicWrite(fs,path,S.encode(package),{decode=require('src.core.SaveSafety').decodeAny})
    f.notice=written and ('Bank copy exported to '..(fs.mapPath and fs.mapPath(path) or path)) or err
  end
  return true
end
return M
