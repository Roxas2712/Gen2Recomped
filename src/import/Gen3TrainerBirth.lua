-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
local Birth=require('src.pokemon.Gen3TrainerBirth')
function M.reader(extractor)
  local version=type(extractor.version)=='table' and extractor.version.id or extractor.version
  if not Birth.supports(version) then return nil end
  local names=extractor:need('gSpeciesNames','native trainer birth')
  if not names then return nil end
  local rom=extractor.rom
  local width=extractor:layoutValue('speciesNameLength',11)
  local function sum(at,length)
    local hash=0
    for n=0,length-1 do
      local byte=rom:u8(at+n)
      if byte==255 then return hash end
      hash=hash+byte
    end
    error('Unterminated native trainer/species name')
  end
  return {version=version,trainerHash=function(at)return sum(at,12)end,
    speciesHash=function(index)return sum(names+index*width,width)end}
end
local function read(Fs,path)
  local raw=Fs.read(path);local chunk=raw and loadstring(raw,'@'..path)
  if not chunk then return nil end
  setfenv(chunk,{})
  local ok,value=pcall(chunk)
  if ok and type(value)=='table' then return value end
end
function M.valid(version,constants,trainers)
  local recipe=type(constants)=='table' and constants.gen3TrainerBirth
  if not Birth.validRecipe(recipe,version) or type(trainers)~='table' then return false end
  local count,slots=0,0
  for _,trainer in pairs(trainers) do
    if type(trainer)~='table' or type(trainer.parties)~='table'
      or type(trainer.parties[1])~='table' then return false end
    count=count+1
    for _,slot in ipairs(trainer.parties[1]) do
      if not Birth.validSlot(version,slot) then return false end
      slots=slots+1
    end
  end
  return count==recipe.trainerCount and slots==recipe.partySlots
end
function M.missing(version)
  if not Birth.supports(version) then return {} end
  local Fs=require('src.import.CacheFs')
  if M.valid(version,read(Fs,'data/generated/constants.lua'),
    read(Fs,'data/generated/trainers.lua')) then return {} end
  return {'<gba:native-trainer-birth-'..version..'>'}
end
return M
