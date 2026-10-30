-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original shared E/FRLG party art; host identities and effects remain separate.
local M={ROOT='data/generated/gba/pokemon/party/'}
local supported={emerald=true,firered=true,leafgreen=true}
M.files={'bg.rgba','slot_main.rgba','slot_main_selected.rgba','slot_main_multi.rgba',
 'slot_main_multi_selected.rgba','slot_wide.rgba','slot_wide_selected.rgba','slot_wide_multi.rgba',
 'slot_wide_multi_selected.rgba','slot_wide_empty.rgba','cancel_button.rgba','cancel_button_selected.rgba',
 'confirm_button.rgba','confirm_button_selected.rgba','status_balls.rgba','hold_icons.rgba',
 'status_icons.rgba','manifest.lua'}
function M.labels(version)
 return {level='gText_Lv',choose='gText_ChoosePokemon',use='gText_UseOnWhichPokemon',
  teach='gText_TeachWhichPokemon',give='gText_GiveToWhichPokemon',move='gText_MoveToWhere',action='gText_DoWhatWithPokemon',
  cancel=version=='emerald'and'gText_Cancel2'or'gFameCheckerText_Cancel',
  confirm=version=='emerald'and'gText_Confirm2'or'gText_PartyMenu_OK'}
end
function M.context(version)
 local Loader=require('compat.gen1-rs.Loader')
 local gv={current=version,get=function()return version end}
 local bindings={['src.core.GameVersion']=gv,__package={loaded={}}}
 local load=Loader.new(version,bindings)
 if version=='emerald'then return load,{game=version},load('src.import.gba.syms').of(version)end
 local V=load('src.import.gba.versions_frlg');V.select(version)
 -- The shared extractor imports versions before using explicit keys. FR/LG
 -- have their own address table, not an RS/E symbol-table entry.
 bindings['src.import.gba.versions']=V
 return Loader.new(version,bindings),{game=version,keys=V}
end
function M.extract(x)
 local version=x.version;if not supported[version]then return end
 x:beginStage('Original field party chrome')
 local load,options,S=M.context(version)
 local rom={id=version};function rom:get(at)return x.rom:u8(at)end
 local Fs=require('src.import.CacheFs')
 local cache={write=function(_,path,bytes)
  assert(path:sub(1,#M.ROOT)==M.ROOT or path=='data/generated/gba/pokemon/summary/status_icons.rgba')
  local ok,why=Fs.write(path,bytes);assert(ok,why);return true
 end}
 assert(load('src.import.gba.party_chrome_extract').run(rom,cache,options))
 local IR=load('src.core.game3.scripting.text_ir');local labels=not S and require('src.import.gba.text_labels.'..version)
 local text={}
 for role,name in pairs(M.labels(version))do
  local at=assert(S and S.off(name)or labels[name]or options.keys.NAMED_TEXTS[name],'Missing native party label '..name);local raw={}
  for i=0,2047 do local b=rom:get(at+i);raw[#raw+1]=b;if b==255 then break end end
  assert(raw[#raw]==255,'Unterminated native party text '..name)
  text[role]=IR.decode(raw,{dialect=version=='emerald'and'rse'or'frlg'})
 end
 x._constants.gen3NativeParty={format=1,version=version,root=M.ROOT,textIR=text,resources={}}
 for _,name in ipairs(M.files)do
  local path=M.ROOT..name;assert(Fs.exists(path),'Missing native party output '..path)
  x._constants.gen3NativeParty.resources[#x._constants.gen3NativeParty.resources+1]=path
 end
 x:write('constants',x._constants)
end
function M.valid(spec,version)
 if not(supported[version]and type(spec)=='table'and spec.format==1 and spec.version==version
  and spec.root==M.ROOT and type(spec.textIR)=='table'and type(spec.resources)=='table'
  and#spec.resources==#M.files)then return false end
 for role in pairs(M.labels(version))do if type(spec.textIR[role])~='table'or#spec.textIR[role]==0 then return false end end
 for i,name in ipairs(M.files)do if spec.resources[i]~=M.ROOT..name then return false end end
 return true
end
function M.missing(version)
 if not supported[version]then return{}end
 local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
 local f=raw and loadstring(raw);if f then setfenv(f,{})end
 local ok,t=false,nil;if f then ok,t=pcall(f)end
 if not(ok and type(t)=='table'and M.valid(t.gen3NativeParty,version))then return{'<'..version..':native-party>'}end
 for _,name in ipairs(M.files)do if not Fs.exists(M.ROOT..name)then return{M.ROOT..name}end end
 return{}
end
return M
