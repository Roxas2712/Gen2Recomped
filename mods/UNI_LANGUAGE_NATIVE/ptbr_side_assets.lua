-- Include native side-menu art in the one-time language cache.
return function(game,files)
 local base=require('src.core.game3.dataset').cache()
 if game=='firered' or game=='leafgreen' then
  local path='data/generated/gba/fame_checker/bg.rgba'
  local bytes=assert(base:read(path));if files then files[path]=bytes end
  return {[path]=bytes}
 end
 if game~='ruby' and game~='sapphire' and game~='emerald' then return {} end
 local inputs={}
 local function collect(v)
  if type(v)=='table' then for _,x in pairs(v)do collect(x)end
  elseif type(v)=='string' and v:match('^data/generated/gba/[%w_/]+%.[%w]+$') then
   inputs[v]=assert(base:read(v),'Missing native side-menu asset '..v)
  end
 end
 local folders={'rse/berry_tag','rse/pokeblock','rse/berry_blender','rse_slot_machine','rse_roulette'}
 if game=='emerald' then folders[#folders+1]='rse/contest_gfx';folders[#folders+1]='rse/frontier_pass' else folders[#folders+1]='rse/rs_contest_gfx';folders[#folders+1]='rse/easy_chat_editor' end
 for _,folder in ipairs(folders)do
  local path='data/generated/gba/'..folder..'/manifest.lua'
  inputs[path]=assert(base:read(path));collect(assert(loadstring(inputs[path]))())
 end
 if files then for path,bytes in pairs(inputs)do
  if not path:match('/manifest.lua$') and not files[path] then files[path]=bytes end
 end end
 return inputs
end
