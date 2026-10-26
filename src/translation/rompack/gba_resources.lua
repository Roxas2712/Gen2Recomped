-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Use a private instance of the installed host's asset decoder. Its source is
-- read from that host at runtime and is never copied into the mod archive.
return function(mod,entry,own,bytes,english)
 local Merge=require('src.mods.Merge')
 local manifest=Merge.deepCopy(require('src.link.Json').decode(assert(love.filesystem.read(require('src.core.GameVersion').info().manifest))))
 local localMeta=own(entry.assets);local base=own('@host/addresses/'..entry.game..'_assets.lua')
 local offsets={};local function remember(a,b)
  if type(a)=='number'and type(b)=='number'and a>=65536 and b>=65536 then
    if offsets[a]==nil then offsets[a]=#english+b elseif offsets[a]~=#english+b then offsets[a]=false end
  end
 end
 local function pair(a,b)
  if type(a)=='table'and type(b)=='table'then for k,v in pairs(a)do pair(v,b[k])end else remember(a,b)end
 end
 pair(base,localMeta.fields)
 for name,off in pairs(base.__symbolOff or{})do
  local row=localMeta.symbols.off and localMeta.symbols.off[name]
  if row then remember(off,row[1])end
 end
 for _,method in ipairs({'address','sym'})do for key,row in pairs(localMeta.calls[method]or{})do remember(tonumber(key),row[1])end end
 local p=own(entry.profile);local addresses=own('@host/addresses/'..entry.game..'.lua')
 for label,row in pairs(p.texts)do remember(addresses[label],row[1])end
 local function move(t,seen)
  seen=seen or {};if seen[t]then return end;seen[t]=true
  for k,v in pairs(t)do if type(v)=='number'and offsets[v]then t[k]=offsets[v]elseif type(v)=='table'then move(v,seen)end end
 end
 local source=assert(love.filesystem.read('src/import/RomExtractorGen3.lua'))
 local chunk=assert(loadstring(source,'@ula-private-host-gba'))
 local environment=setmetatable({require=function(name)
  if name=='src.import.Gen3ScriptOps'then return Merge.deepCopy(require(name))end
  return require(name)
 end},{__index=_G})
 setfenv(chunk,environment);local E=chunk()
 E.applyAddressMap(manifest.addressMap);E.applyStageOverrides(manifest.stageOverrides)
 local locate=own('@host/gba_relocate.lua')(english,bytes);local automatic=0
 local function resolve(t)
  for _,v in pairs(t or{})do
   if type(v)=='table'then resolve(v)
   elseif type(v)=='number'and v>=65536 and v<#english and offsets[v]==nil then
    local found=locate(v);if found then offsets[v]=#english+found;automatic=automatic+1 end
   end
  end
 end
 resolve((entry.game=='firered'or entry.game=='leafgreen')and E.FRLG_NAMING or E.EMERALD_NAMING)
 if entry.game=='emerald'then resolve(E.POKENAV and E.POKENAV.BUTTONS);resolve(E.POKENAV and E.POKENAV.BUTTON_PALS)end
 for key,value in pairs(E)do if type(key)=='string'and key:match('^[A-Z][A-Z0-9_]*$')and type(value)=='table'then move(value)end end
 move(manifest.symbols)
 move(manifest.font)
 local sceneKeys={}
 for _,scene in ipairs(manifest.scenes or{})do
  local before=scene.graphics;move(scene)
  sceneKeys[('SCENE_%07X'):format(scene.graphics)]=('SCENE_%07X'):format(before)
 end
 move(manifest.sceneOverlays or{})
 local glyphs=entry.glyphsPath and own(entry.glyphsPath,entry.language)or entry.glyphs or {[0x15]='ß',[0xf1]='Ä',[0xf2]='Ö',[0xf3]='Ü',[0xf4]='ä',[0xf5]='ö',[0xf6]='ü'}
 for code,glyph in pairs(glyphs)do manifest.charmap[tostring(code)]=glyph end
 for code,glyph in pairs(p.decodeGlyphs or{})do manifest.charmap[tostring(code)]=glyph end
 -- Unmapped native structures are read from the exact English base. Localized
 -- objects occupy a separate address range, including every followed pointer.
 -- This prevents a valid but unrelated target string/bitmap at a US address
 -- from being mistaken for the corresponding localized resource.
 assert(#english==16*1024*1024 and #bytes==16*1024*1024,'Unsupported GBA image size')
 local combined=english..bytes
 local rom=require('src.import.RomGba').new(english)
 rom.u8=function(_,off)return assert(combined:byte(off+1),'Native resource read outside verified inputs')end
 local u32=rom.u32
 rom.u32=function(r,off)
  local word=u32(r,off)
  if off>=#english and word>=0x08000000 and word<0x08000000+#bytes then return word+#english end
  return word
 end
 rom.pointer=function(r,off)
  local word=r:u32(off)
  if word>=0x08000000 and word<0x08000000+#combined then return word-0x08000000 end
 end
 local lz77,read=rom.lz77,rom.bytes
 rom.lz77=function(r,off)return lz77(r,offsets[off]or off)end
 rom.bytes=function(r,off,length)return read(r,offsets[off]or off,length)end
 rom.sub=function(_,off,length)off=offsets[off]or off;return combined:sub(off+1,off+length)end
 local self=setmetatable({rom=rom,version=entry.game,manifest=manifest,symbols=manifest.symbols,layout=manifest.layout,stage=0,counts={}},E)
 local files,tables,report={},{},{images=0,stages={},relocatedNativeResources=automatic}
 self.write=function(_,name,value)tables[name]=value end
 self.saveImage=function(_,image,path)
  files['assets/generated/'..path]=image:encode('png'):getString();report.images=report.images+1
  if image.release then image:release()end
 end
 self.bgLayer=function(s,image,layer)
  -- Hardware tilemaps are 32 columns, while the visible GBA surface is 30.
  -- The host's painter can write the two off-screen columns into a 240px
  -- ImageData and abort the whole picture. Clip only those invisible pixels.
  local w,h=image:getDimensions()
  local surface={setPixel=function(_,x,y,...)
   if x>=0 and y>=0 and x<w and y<h then image:setPixel(x,y,...)end
  end}
  return E.bgLayer(s,surface,layer)
 end
 E.ulaTrainerCard=function(s)
  if entry.game~='emerald'then return end
  local c=s._constants or{};s:trainerCardArt(c);s:trainerCardBadges(c);s._constants=c;s:write('constants',c)
 end
 local stages={'extractFont','extractScenes','extractSummaryScreen','extractBattleHud','extractPartyMenu','extractBagScreen','extractFireRedItemPc','extractTMCaseScreen','extractBerryPouchScreen','extractFireRedTeachyTV','extractFireRedIntro','extractFireRedOakSpeech','extractFireRedTitle','extractFireRedStartMenu','extractFireRedTrainerCard','ulaTrainerCard','extractFireRedPokedex','extractFireRedSummary','extractFireRedRegionMap','extractFireRedStorage','extractFireRedPocketArt','extractFireRedNaming','extractEmeraldNaming','extractEmeraldMapPopup','extractFireRedSpecialTexts','extractPokenav','extractBattleTextbox','extractPokedexScreen','extractSummaryWindows'}
 -- Native side scenes own lettering too. Keep their rendering output; do not
 -- import their regenerated rules, flags or mechanics into the live dataset.
 for _,name in ipairs({'extractSlotMachine','extractFireRedMapPreviews','extractFireRedTrainerTower','extractFireRedSSAnneArt','extractFireRedExtraArt'})do stages[#stages+1]=name end
 for _,stage in ipairs(stages)do
  -- Structural discovery scans the one English address space. Following a
  -- verified resource then reads its localized payload through the reader.
  -- Font face discovery additionally searches after the target width table.
  rom.size=stage=='extractFont'and #combined or #english
  local ok,why=pcall(E[stage],self);report.stages[stage]={passed=ok,error=not ok and tostring(why)or nil}
  print('ULA_GBA_RESOURCE_STAGE',entry.game,stage,ok,tostring(why))
 end
 -- Easy Chat's word strings are not in the field-dialogue address census.
 -- Its own structural decoder can read the localized table directly. Only
 -- text is transferred later, after checking the host's group/word identities.
 local originalRom=self.rom;local before=tables.constants
 self.rom=require('src.import.RomGba').new(bytes);self._constants={}
 local wordMap=self:charmap()
 local alphabet=own('vendor/src/core/game3/scripting/text_ir.lua').CHARMAP
 for code,glyph in pairs(alphabet)do if wordMap[code]==nil then wordMap[code]=glyph end end
 wordMap[0x55]='POKéBLOCK'
 for code=0x56,0x59 do wordMap[code]=''end
 if p.texts['sEasyChatGroupNamePointers[0]']then self.easyChatNames=function(s,count)
   local names={}
   for i=0,count-1 do
    local row=assert(p.texts['sEasyChatGroupNamePointers['..i..']'],'Localized Easy Chat name recipe missing')
    names[i+1]=assert(s:readText(row[1],64),'Localized Easy Chat name missing')
   end
   return p.texts['sEasyChatGroupNamePointers[0]'][1],names
  end
 elseif (entry.game=='firered'or entry.game=='leafgreen')then
  local tableAt=offsets[0x3EDF98]and offsets[0x3EDF98]-#english or locate(0x3EDF98)
  if tableAt then self.easyChatNames=function(s,count)
   local names={}
   for i=0,count-1 do
    local ptr=assert(s.rom:pointer(tableAt+i*4),'Localized Easy Chat group pointer missing')
    names[i+1]=assert(s:readText(ptr,64),'Localized Easy Chat group label missing')
   end
   return tableAt,names
  end end
 end
 local easyOk,easyError=pcall(E.extractEasyChat,self)
 local easy=self._constants.gen3EasyChat
 self.rom=originalRom;self._constants=before;tables.constants=before
 report.stages.localizedEasyChat={passed=easyOk and easy~=nil,error=not easyOk and tostring(easyError)or nil}
 if tables.scenes then
  local normalized={};for id,value in pairs(tables.scenes)do normalized[sceneKeys[id]or id]=value end
  -- Roles still name the private decoder's relocated addresses. Normalize
  -- those references with the records so title/intro layers stay reachable.
  for _,ids in pairs(normalized._roles or{})do for i,id in ipairs(ids)do
   ids[i]=sceneKeys[id]or id
   assert(normalized[ids[i]],'Localized scene role has no layer: '..tostring(ids[i]))
  end end
  tables.scenes=normalized
 end
 -- A second face may share the normal page's filename. Its decoded image
 -- must have the same cell geometry as the metadata consumed by Font.load.
 -- Otherwise the glyph quads drift into adjacent rows (ink becomes shadow).
 local font=tables.font
 if font then
  local present={};for _,row in ipairs(font.charmap or{})do present[row.seq]=true end
  for seq,code in pairs({["'"]=0xB4,['"']=0xB2})do
   if not present[seq]then font.charmap[#font.charmap+1]={seq=seq,code=code}end
  end
 end
 if font then for _,group in ipairs({font.pages or{},font.faces or{}})do for _,face in pairs(group)do
  local payload=face.image and files[face.image]
  if payload then
   local image=love.image.newImageData(love.data.newByteData(payload))
   local columns=face.glyphsPerRow or 16;local count=face.widths and #face.widths or 512
   assert(image:getWidth()==columns*face.glyphWidth and image:getHeight()==math.ceil(count/columns)*face.glyphHeight,'Localized font image/cell geometry mismatch: '..face.image)
   image:release()
  end
 end end end
 report.offsets=0;for _ in pairs(offsets)do report.offsets=report.offsets+1 end
 return {files=files,tables=tables,easyChat=easy,report=report}
end
