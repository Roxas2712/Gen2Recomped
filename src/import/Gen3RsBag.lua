-- Private native RS bag resources. Extraction uses the pinned reference;
-- text decoding and cache routing remain the host's own responsibilities.
local M = {}
local ROOT = 'data/generated/gba/'
local TOSS_TEXT={'gOtherText_HowManyToToss','gOtherText_OkayToThrowAwayPrompt',
  'gOtherText_ThrewAwayItem','OtherText_Yes','OtherText_No'}
local MACHINE_TEXT={'gOtherText_BootedTM','gOtherText_BootedHM','gOtherText_ContainsMove'}

function M.machineReady(spec,version)
  if not M.tossReady(spec,version)or type(spec.machineText)~='table'then return false end
  for _,key in ipairs(MACHINE_TEXT)do if type(spec.machineText[key])~='string'then return false end end
  return spec.machineText.gOtherText_ContainsMove:find('{VAR1}',1,true)~=nil
end

function M.tossReady(spec,version)
  if not(type(spec)=='table'and spec.format==1 and spec.version==version
    and(version=='ruby'or version=='sapphire')and type(spec.tossTextIR)=='table')then return false end
  for _,key in ipairs(TOSS_TEXT)do if type(spec.tossTextIR[key])~='table'then return false end end
  return true
end

function M.extract(extractor, load, rom, cache)
  extractor:beginStage('Ruby/Sapphire native bag')
  local A = load('src.import.gba.rs.assets')
  A.text = function(_, off) return extractor:readText(off) end
  for _, module in ipairs({'extract_bag', 'extract_common_ui'}) do
    assert(load('src.import.gba.rs.'..module).run(rom, cache))
  end
  local S = load('src.import.gba.syms').of(extractor.version)
  local D = load('src.ui.game3.rs.bag_menu_data')
  local texts = {}
  local function text(key)
    texts[key] = assert(extractor:readText(S.off(key)), 'Missing RS bag text '..key)
  end
  for _, key in pairs(D.ACTION_TEXT) do text(key) end
  for _, key in pairs(D.RETURN_TEXT) do text(key) end
  for _, key in ipairs({'gOtherText_CloseBag', 'gOtherText_ReturnTo',
    'gOtherText_WhatWillYouDo2', 'gOtherText_SwitchWhichItem'}) do text(key) end

  local K = load('src.import.gba.rse.boot_gfx')
  local c = A.context(rom, cache, {}, 'rse/bag_chrome')
  local colors = c:pal('gFontDefaultPalette', 16)
  local palette = K.palList(colors, 0, 16)
  local frames, frameTable = {}, S.off('text_window.o:sTextWindowFrameGraphics')
  assert(S.count('text_window.o:sTextWindowFrameGraphics', 8) == 20, 'Native RS frame count')
  local map = {}
  for tile=0,8 do map[#map+1]=string.char(tile,0) end
  for i=0,19 do
    local gfx = rom:readString(assert(c:ptr(frameTable+i*8)), 9*32)
    local pal = c:palAt(assert(c:ptr(frameTable+i*8+4)), 16)
    local pixels,w,h=K.bakeText(gfx,table.concat(map),3,3,{linear=true,mapWidth=3})
    frames[i+1]=c:png('frame_'..i..'.png',w,h,pixels,pal,true)
  end
  assert(A.finish(c,{screen='bag_chrome',frames=frames}))
  extractor._constants.gen3RsBag = {format=1, version=extractor.version,
    bag=ROOT..'rse/bag/manifest.lua', common=ROOT..'rse/common_ui/manifest.lua',
    chrome=ROOT..'rse/bag_chrome/manifest.lua', text=texts, palette=palette}
  local ir=load('src.core.game3.scripting.text_ir');local toss={}
  for _,key in ipairs(TOSS_TEXT)do
    local at=assert(S.off(key));local bytes={};local ended=false
    for i=0,1023 do
      local b=rom:get(at+i);bytes[#bytes+1]=b
      if b==255 then ended=true;break end
    end
    assert(ended,'Unterminated native RS toss label '..key)
    toss[key]=ir.decode(bytes,{dialect='rs'})
  end
  extractor._constants.gen3RsBag.tossTextIR=toss
  local machine={}
  for _,key in ipairs(MACHINE_TEXT)do machine[key]=assert(extractor:readText(S.off(key)))end
  assert(machine.gOtherText_ContainsMove:find('{VAR1}',1,true),'RS machine move buffer missing')
  extractor._constants.gen3RsBag.machineText=machine
end

function M.missing(version)
  local Fs = require('src.import.CacheFs')
  local missing = {}
  local raw=Fs.read('data/generated/constants.lua');local constants=raw and loadstring(raw)
  if constants then setfenv(constants,{})end
  local ok,spec=false,nil
  if constants then ok,spec=pcall(constants)end
  if not ok or type(spec)~='table'or not M.tossReady(spec.gen3RsBag,version)then
    missing[#missing+1]='<rs:native-bag-toss-text>'
  end
  if not ok or type(spec)~='table'or not M.machineReady(spec.gen3RsBag,version)then
    missing[#missing+1]='<rs:native-machine-text>'
  end
  for _, sub in ipairs({'bag','common_ui','bag_chrome'}) do
    local path = ROOT..'rse/'..sub..'/manifest.lua'
    local body = Fs.read(path)
    local chunk = body and loadstring(body,'@'..path)
    if chunk then setfenv(chunk,{}) end
    local ok,man = false,nil
    if chunk then ok,man=pcall(chunk) end
    if not ok or type(man)~='table' or man.layout~='rs' or man.game~=version
      or type(man.files)~='table' or #man.files==0 then
      missing[#missing+1]=path
    else
      for _,file in ipairs(man.files) do
        if type(file)~='string' or not Fs.exists(file) then missing[#missing+1]=tostring(file) end
      end
    end
  end
  return missing
end

return M
