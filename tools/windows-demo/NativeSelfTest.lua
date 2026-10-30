-- Isolated, actual Windows file/process/FFI checks; no player data.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
function M.run(check)
 local fs=love.filesystem;local base='native-fixtures-Ömega %!'
 assert(fs.createDirectory(base))
 local root=fs.getSaveDirectory()..'/'..base
 local File=require('src.core.NativeFile')
 local old='SYNTHETIC ORIGINAL SAVE';local target=root..'/own-save.fixture'
 assert(File.atomicWrite(target,old));assert(File.atomicWrite(target,'SYNTHETIC NEW SAVE'))
 check(File.read(target)=='SYNTHETIC NEW SAVE','Wide atomic writes can replace existing files without an ANSI path')
 assert(fs.createDirectory(base..'/blocked'))
 local ok=File.atomicWrite(root..'/blocked','SYNTHETIC RECOVERY')
 local recovery=false
 for _,name in ipairs(fs.getDirectoryItems(base))do if name:match('^blocked%.pending%-')then
  recovery=fs.read(base..'/'..name)=='SYNTHETIC RECOVERY'
 end end
 check(not ok and recovery and fs.getInfo(base..'/blocked','directory')~=nil,'Failed replacements preserve the old target and completed recovery bytes')
 local Saves=require('src.pinball.SaveFiles')
 local session={player=root,locale='en'}
 local initial=string.rep('A',32768);local imported=string.rep('B',32768)
 assert(File.atomicWrite(Saves.path(session),initial));assert(File.atomicWrite(root..'/incoming.fixture',imported))
 assert(Saves.import(session,root..'/incoming.fixture'))
 local backup=false
 for _,name in ipairs(fs.getDirectoryItems(base))do
  if name:match('^solo%-en%-1%.sav%.before%-import%-')then backup=fs.read(base..'/'..name)==initial end
 end
 check(Saves.exists(session)and File.read(Saves.path(session))==imported and backup,'Pinball imports preserve the previous SRAM in a separate backup')
 local Backend=require('src.import.PokemonXYBackend');local sdk=assert(Backend.runtime(),'Bundled Windows game SDK missing')
 local Process=require('src.translation.DesktopProcess');local Json=require('src.link.Json')
 local args={'Ömega %!','quote"inside','trailing\\','','slash\\"quoted'}
 local command={assert(Backend.file('python')),'-X','utf8','-c','import json,sys;print(json.dumps(sys.argv[1:],ensure_ascii=False))'}
 for _,value in ipairs(args)do command[#command+1]=value end
 local pipe=assert(Process.argv(command,true));local lines={};for line in pipe:lines()do lines[#lines+1]=line end
 assert(pipe:close());local actual=Json.decode(table.concat(lines,'\n'))
 for i,value in ipairs(args)do assert(actual[i]==value,'Native argv round trip '..i)end
 check(#actual==#args,'CreateProcessW passes Unicode, empty arguments, percent signs, quotes and backslashes literally')
 local cfile=root..'/own-library.c';local dll=root..'/own-library.dll'
 assert(File.atomicWrite(cfile,'__declspec(dllexport) int ascendant_fixture_answer(void) { return 42; }\n'))
 -- Match the real import workers: their bundled UTF-8 Python host starts
 -- Clang, including its linker children. Starting Clang directly from the
 -- legacy LOVE host gives those children the host's ANSI code page instead.
 pipe=assert(Process.argv({assert(Backend.file('python')),'-X','utf8','-c',
  'import os,pathlib,subprocess,sys;os.environ["PATH"]=str(pathlib.Path(sys.argv[1]).parent)+os.pathsep+os.environ.get("PATH","");sys.exit(subprocess.run(sys.argv[1:]).returncode)',
  sdk..'/compiler/bin/clang.exe','-v','-shared','-O2',cfile,'-o',dll},true))
 lines={};for line in pipe:lines()do lines[#lines+1]=line end
 assert(pipe:close(),table.concat(lines,'\n'))
 local lib=require('src.core.NativeLibrary').load(dll,'int ascendant_fixture_answer(void);')
 check(lib.ascendant_fixture_answer()==42,'The bundled UTF-8 import host compiles a DLL and the final EXE loads its Unicode path through GetProcAddress')
 -- Loading alone resolves this DLL's dependencies; Vulkan API execution is
 -- covered by the separate native SDK test, not by an invented API export.
 local driver=require('src.core.NativeLibrary').load(sdk..'/vulkan/vulkan_lvp.dll','')
 check(type(driver)=='table','Packaged software Vulkan driver and its dependencies load inside the final Windows host')
 local ffi=require('ffi');local bridge=require('src.import.PokemonXYABI').load(assert(Backend.file('bridge')))
 local places=ffi.new('AscendantPlace[4]')
 for layout=0,5 do
  local count=tonumber(bridge.ascendant_3ds_layout(1280,720,layout,0,false,false,places,4))
  assert(count>0 and count<=4)
  for i=0,count-1 do assert(places[i].width>0 and places[i].height>0)end
 end
 check(true,'The packaged 3DS Windows bridge loads through the final EXE and supplies all six layouts')
 return {syntheticOnly=true,realCartridgeGameplay=false}
end
return M
