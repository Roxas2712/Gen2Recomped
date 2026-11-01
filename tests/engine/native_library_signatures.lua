-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T=require('tests.harness')
local ffi=require('ffi')
local N=require('src.core.NativeLibrary')
local total=0
for _,path in ipairs{'src/import/PokemonXYABI.lua','src/pinball/ABI.lua'}do
 local file=assert(io.open(path,'rb'));local source=file:read('*a');file:close()
 local declarations=assert(source:match('local declarations=%[%[(.-)%]%]'))
 ffi.cdef(declarations)
 local signatures=N.signatures(declarations)
 local expected=0
 for name in declarations:gmatch('(ascendant_[%w_]+)%s*%(')do
  expected=expected+1;T.check(signatures[name]~=nil,name)
  T.check(pcall(ffi.typeof,signatures[name]),'Callable Windows export: '..name)
 end
 local count=0;for _ in pairs(signatures)do count=count+1 end
 T.eq(count,expected,'All declared native exports have exact pointer signatures')
 total=total+count
end
T.eq(total,32)
T.finish('native export pointer signatures')
