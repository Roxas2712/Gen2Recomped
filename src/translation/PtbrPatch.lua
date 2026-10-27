-- Offline PT-BR construction from the player's supported US cartridge.
-- Copyright (c) 2026 Roxas2712. GPL-3.0; translation credits in the bundle.
local P={INDEX='assets/language-patches/pt-BR/index.json'}
local function hash(kind,bytes)return love.data.encode('string','hex',love.data.hash('string',kind,bytes))end
function P.recipes()
 local bytes=love.filesystem.read(P.INDEX)
 if not bytes then return {} end
 local data=assert(require('src.link.Json').decode(bytes))
 assert(data.format=='native-ptbr-bps-v1' and type(data.recipes)=='table','Invalid PT-BR patch index')
 return data.recipes
end
local function specs(manifest)
 local out={};for _,entry in ipairs(require('src.mods.ModImports').of(manifest) or {})do out[entry.id]=entry end;return out
end
function P.describe(version,manifest)
 local entries=specs(manifest);local first
 for _,recipe in ipairs(P.recipes())do if recipe.game==version then
  assert(recipe.path:match('^assets/language%-patches/pt%-BR/[%w%-]+%.bps$'),'Invalid PT-BR patch path')
  local state={recipe=recipe,baseEntry=entries[recipe.baseImportId],targetEntry=entries[recipe.sourceId],automatic=true}
  assert(state.baseEntry and state.targetEntry,'Missing PT-BR base/target declaration')
  state.baseReady=require('src.mods.ModImports').have(manifest,state.baseEntry) or false
  first=first or state
  if state.baseReady then return state end
 end end
 return first
end
function P.prepare(version,manifest,progress)
 local state=assert(P.describe(version,manifest),'No automatic PT-BR patch for this edition')
 assert(state.baseReady,'Import the supported US ROM once to prepare Portuguese')
 local r=state.recipe
 local patch=assert(love.filesystem.read(r.path),'PT-BR patch is unavailable')
 assert(#patch==r.patchSize and hash('sha256',patch)==r.patchSha256,'PT-BR patch identity mismatch')
 local Imports=require('src.mods.ModImports')
 local api=Imports.api(manifest)
 local parts={}
 for offset=0,r.baseSize-1,4*1024*1024 do
  local bytes,why=api:read(r.baseImportId,offset,math.min(4*1024*1024,r.baseSize-offset))
  parts[#parts+1]=assert(bytes,why or 'Could not read US base ROM')
  if progress then progress(offset+#bytes,r.baseSize,'read')end
 end
 local source=table.concat(parts);parts=nil
 assert(#source==r.baseSize and hash('sha1',source)==r.baseSha1,'PT-BR requires the exact supported US base')
 local result=require('src.translation.Bps').apply(source,patch,r.targetSize,progress)
 assert(#result==r.targetSize and hash('sha1',result)==r.targetSha1 and hash('md5',result)==r.targetMd5,'Generated Portuguese source failed verification')
 -- The original US source is read-only. Publish the fully verified language
 -- image through the same atomic private import store as manual inputs.
 local ok,why=Imports.install(manifest,state.targetEntry,result)
 assert(ok,why or 'Could not retain the prepared Portuguese language data')
 assert(Imports.have(manifest,state.targetEntry),'Prepared Portuguese data is not ready')
 return true
end
return P
