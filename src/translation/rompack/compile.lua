-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
return function(mod,entry,own)
 local info=assert(mod.imports:info(entry.sourceId or entry.id),'Missing language ROM')
 local profile=own(entry.profile)
 assert(profile.sha1==info.sha1 and profile.md5==info.md5 and profile.size==info.size,'ROM/profile mismatch')
 local function hash(bytes)return love.data.encode('string','hex',love.data.hash('sha256',bytes))end
 local paths={'@host/compile.lua','@host/lz3.lua','@host/asian_font.lua','@host/pc_labels.lua','gb/compile.lua',entry.profile,entry.root..'assets.lua','compiler.lua','cache_codec.lua'}
 for _,name in ipairs(profile.catalogs)do paths[#paths+1]=entry.root..name end
 table.sort(paths)
 local recipe={'native-rompack-gb-v1',mod.languageRecipe,entry.game,entry.language,info.sha1}
 for _,path in ipairs(paths)do recipe[#recipe+1]=path..':'..hash(assert(mod:read(path)))end
 local key=hash(table.concat(recipe,'\n'))
 -- The shared compiler replays a registry marker. The host freezes its
 -- registries before game.ready; this adapter applies its display data
 -- directly and needs no late registry mutation.
 local proxy=setmetatable({content={strings={override=function()end}}},{__index=mod})
 local files,report=own('compiler.lua')(proxy,key,function()
  local bytes=assert(mod.imports:read(entry.sourceId or entry.id,0,info.size))
  local result=own('gb/compile.lua')(bytes,profile,entry.root,own,{Rom=own('@host/lz3.lua')})
  result.files['lang/fork_pc_labels.lua']=require('src.core.SaveSerializer').encode(own('@host/pc_labels.lua').decode(bytes,profile,entry.game))
  if profile.encoding=='japanese-gen2'or profile.encoding=='korean-gen2'then
   local S=require('src.core.SaveSerializer')
   local pages=assert(S.decode(result.files['lang/font_pages.lua']))
   local font=own('@host/asian_font.lua').materialize(result.files,pages,profile.fontmap)
   result.files['lang/fork_font.lua']=S.encode(font)
  end
  return result
 end)
 local catalogs={}
 local S=require('src.core.SaveSerializer')
 for path,bytes in pairs(files)do
  local name=path:match('^lang/(.+)%.lua$')
  if name then catalogs[name]=assert(S.decode(bytes,{maxBytes=16*1024*1024,maxNodes=500000,maxDepth=40}))end
 end
 return {files=files,catalogs=catalogs,report=report,key=key,profile=profile}
end
