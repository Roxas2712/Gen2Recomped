-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Session-scoped in-memory files, consumed through the host's image API.
-- Never writes localized graphics into the English import cache.
return function(mod,own)
 local Assets=require('src.render.Assets');local Runtime=require('src.mods.Runtime')
 local marker='ula.fork.assets';mod.events:on(marker,function()end)
 local state={exists=Assets.exists,decode=function(path)
  if type(path)=='string' then return Assets.imageData(path) end
  return love.image.newImageData(path)
 end}
 state.bus=Runtime.events;state.files={};state.paths={}
 Assets.languageLayer(mod.id,state,function()return state.bus==Runtime.events and Runtime.wants(marker)end)
 function state:set(data,compiled)
  self.files={};self.paths={};self.titleBindings={}
  if compiled then
   local prefix='ula-fork/'..compiled.key..'/'
   local asian=compiled.profile.encoding=='korean-gen2' or compiled.profile.encoding=='japanese-gen2'
   local pending={}
   for path,bytes in pairs(compiled.files)do if path:match('%.png$')then self.files[prefix..path]=bytes end end
   for path,bytes in pairs(compiled.files)do if path:match('^assets/generated/.*%.png$')then
    local compatible=not asian
    if asian and self.exists(path)then
     local ok,a=pcall(self.decode,path);local got,b=pcall(self.decode,love.data.newByteData(bytes))
     compatible=ok and got and a:getWidth()==b:getWidth()and a:getHeight()==b:getHeight()
     if ok and a.release then a:release()end;if got and b.release then b:release()end
    end
    if compatible then self.paths[path]=prefix..path else pending[#pending+1]=path end
   end end
   local function asset(path)return compiled.files[path] and prefix..path or nil end
   self.titleBindings=own('@host/title.lua').bind(data,compiled,prefix,require('src.core.GameVersion').get(),self.files)
   if asian then
    local font=assert(compiled.catalogs.fork_font,'Native Asian font is not compiled')
    data.font.pages=data.font.pages or{}
    for id,page in pairs(font.pages)do
     local row={};for k,v in pairs(page)do row[k]=v end;row.image=assert(asset(page.path));row.path=nil
     data.font.pages['ula-'..id]=row
    end
    local lookup={};for _,row in ipairs(data.font.charmap or{})do lookup[row.seq]=row end
    for seq,code in pairs(font.charmap)do
     if lookup[seq]then lookup[seq].code=code else data.font.charmap[#data.font.charmap+1]={seq=seq,code=code}end
    end
   end
   if not asian then
   local main=asset('assets/fonts/font.png')
   if main then data.font.image=main;data.font.pages=data.font.pages or {};data.font.pages.main={image=main,base=128,glyphsPerRow=16}end
   local extra=asset('assets/fonts/font_extra.png')
   if extra then data.font.imageExtra=extra;data.font.pages=data.font.pages or {};data.font.pages.extra={image=extra,base=data.font.extraBase or 96,glyphsPerRow=16}end
   local c=compiled.catalogs
   local lookup={};for _,row in ipairs(data.font.charmap or {})do lookup[row.seq]=row end
   for seq,code in pairs(c.charmap or {})do
    if lookup[seq]then lookup[seq].code=code else data.font.charmap[#data.font.charmap+1]={seq=seq,code=code}end
   end
   local pages=c.font_pages or {}
   for id,page in pairs(pages.pages or {})do data.font.pages['ula-'..id]={image=assert(asset(page.path)),base=page.base,glyphsPerRow=16}end
   for id,page in pairs(pages.singlePages or {})do data.font.pages['ula-single-'..id]={image=assert(asset(page.path)),base=page.base,glyphsPerRow=16}end
   if pages.kana then local p=pages.kana;data.font.pages['ula-kana']={image=assert(asset(p.path)),base=p.base,glyphsPerRow=16}end
   end
   local routes=own('@host/asset_routes.lua');self.routed=0;self.unrouted=pending
   local titleRouted={};for _,path in pairs(self.titleBindings)do titleRouted[path]=true;self.routed=self.routed+1 end
   for source in pairs(compiled.files)do if source:match('^assets/')and not source:match('^assets/generated/')and source:match('%.png$')then
    local matched=false
    for _,path in ipairs(routes.candidates(source))do
    local target=asset(source)
    if target and self.exists(path)then
     local ok,a=pcall(self.decode,path)
     local got,b=pcall(self.decode,love.data.newByteData(compiled.files[source]))
     if ok and got and a:getWidth()==b:getWidth() and a:getHeight()==b:getHeight()then self.paths[path]=target;self.routed=self.routed+1;matched=true end
     if ok and a.release then a:release()end;if got and b.release then b:release()end
    end
    end
    if not matched and not titleRouted[source]and not source:match('^assets/fonts/')then self.unrouted[#self.unrouted+1]=source end
   end end
  end
  -- The fork lays out its battle HUD in 15 columns, while the retail
  -- FontBattleExtra recipe has 16. Route only the localized HP/KP tile into
  -- the native atlas, preserving every native cap, rule and bar segment.
  if compiled and require('src.core.GameVersion').generation()==2 then
   local payload=compiled.files['assets/fonts/font_battle_extra.png']
   local nativePath='assets/generated/battle/font_battle_extra.png'
   if payload and self.exists(nativePath)then
    local ok,native=pcall(self.decode,Assets.resolve(nativePath))
    local got,source=pcall(self.decode,love.data.newByteData(payload))
    if ok and got and native:getWidth()==120 and native:getHeight()==16 and source:getWidth()>=8 and source:getHeight()>=8 then
     native:paste(source,0,8,0,0,8,8)
     local path='ula-fork/'..compiled.key..'/hud-label.png'
     self.files[path]=native:encode('png'):getString();self.paths[nativePath]=path;self.routed=self.routed+1
    end
    if ok and native.release then native:release()end;if got and source.release then source:release()end
   end
  end
  if not compiled and require('src.core.GameVersion').get()=='emerald'then
   local info=mod.imports:info('emerald_en')
   if info then
    local badges=own('@host/type_badges.lua')
    local bytes=assert(mod.imports:read('emerald_en',0,info.size))
    local payload,spec=badges.compile(require('src.import.RomGba').new(bytes),own('@host/addresses/emerald_assets.lua').__symbolOff)
    self.files['ula-fork/english-type-badges.png']=payload;self.paths[badges.path]='ula-fork/english-type-badges.png'
    data.constants.gen3Summary.typeBadges=spec
   end
  end
  if ({firered=true,leafgreen=true,emerald=true})[require('src.core.GameVersion').get()]then
   local game=require('src.core.GameVersion').get();local S=own('@host/gen3_summary.lua')
   local entry
   if compiled then for _,row in ipairs(own('catalog.lua'))do if row.game==game and row.language==compiled.language then entry=row;break end end end
   local id=entry and(entry.sourceId or entry.id)or game..'_en';local info=mod.imports:info(id)
   local base=mod.imports:info(game..'_en')
   if info and base then
    local bytes=assert(mod.imports:read(id,0,info.size));local english=assert(mod.imports:read(game..'_en',0,base.size))
    local off=entry and own(entry.assets).symbols.off or own('@host/addresses/'..game..'_assets.lua').__symbolOff
    local files,spec=S.resources(require('src.import.RomGba').new(bytes),off,game,english)
    for path,payload in pairs(files)do local target='ula-fork/summary-parity/'..path;self.files[target]=payload;self.paths[path]=target end
    data.constants.ulaSummaryParts=spec
    local named=compiled and compiled.catalogs.named or S.englishWords(english,own('@host/addresses/'..game..'.lua'),own)
    data.constants.ulaSummaryWords=S.words(named,data.strings)
   end
  end
  Assets.invalidate()
 end
 return state
end
