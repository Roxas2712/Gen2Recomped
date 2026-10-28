-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={};local PATH='data/generated/gba/text/placeholders.lua'
function M.extract(x)
  assert(x.version=='ruby'or x.version=='sapphire');x:beginStage('RS cartridge-specific dialogue placeholders')
  local load=require('compat.gen1-rs.Loader').new(x.version,{['src.core.GameVersion']={current=x.version,
    get=function()return x.version end,layout=function()return'rs'end}})
  local native=load('src.import.gba.text_placeholders_extract');local S=load('src.import.gba.syms').of(x.version)
  local offsets={};for key,symbol in pairs(native.rsSymbols(x.version))do offsets[key]=assert(S.off(symbol),'Missing native RS placeholder '..symbol)end
  local rom={get=function(_,off)return x.rom:u8(off)end}
  local values=native.extract(rom,offsets)
  local ok,why=require('src.import.CacheFs').write(PATH,native.serialize(values));assert(ok,why)
  local spec={format=1,version=x.version,values=values}
  assert(require('src.core.Gen3RsTextPlaceholders').valid(spec,x.version))
  x._constants.gen3RsPlaceholders=spec
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path);if not f then return end
    setfenv(f,{});local ok,value=pcall(f);return ok and type(value)=='table'and value or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3RsPlaceholders
  if not require('src.core.Gen3RsTextPlaceholders').valid(spec,version)then return{'<rs:edition-placeholders>'}end
  local original=read(PATH)
  if not original then return{PATH}end
  for key,value in pairs(spec.values)do if type(value)=='string'and original[key]~=value then return{PATH}end end
  return{}
end
return M
