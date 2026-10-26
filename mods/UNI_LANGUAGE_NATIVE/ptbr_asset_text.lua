-- Some native scenes cache their own text IR inside graphics manifests.
-- Apply the same validated translation operations to those scene copies once
-- at compile time, retaining the base scene's art, spacing and controls.
return function(files,game,mod,operations)
 if game~='ruby' and game~='sapphire' then return end
 local path='data/generated/gba/rse/diploma/manifest.lua'
 local base=require('src.core.game3.dataset').cache()
 local W=require('src.import.LuaWriter')
 local IR=require('src.core.game3.scripting.text_ir')
 local man=assert(loadstring(assert(base:read(path))))()
 assert(man.layout=='rs','Unsupported diploma layout')
 local keys={gOtherText_DiplomaCertificationGameFreak=true,gOtherText_HoennDex=true,gOtherText_NationalDex=true}
 local source,target={},{}
 for key,row in mod.content.text:each() do if keys[key] then source[key]=row;target[key]=row end end
 assert(W.encode(man.text)==W.encode(assert(source.gOtherText_DiplomaCertificationGameFreak)),
  'Diploma scene text differs from the reviewed base')
 for _,op in ipairs(operations) do
  if op.registry=='text' and op.method=='override' and keys[op.key] then target[op.key]=op.value end
 end
 man.text=assert(target.gOtherText_DiplomaCertificationGameFreak)
 man.hoenn=IR.toPlain(assert(target.gOtherText_HoennDex),{})
 man.national=IR.toPlain(assert(target.gOtherText_NationalDex),{})
 man.textBytes=nil -- the original bytes no longer describe the translated IR
 files[path]=W.encode(man)
 -- RS contests read byte arrays directly, bypassing the normal registry.
 -- Store exact decoded translations beside those arrays for the scoped UI
 -- adapter. Original arrays stay intact for inactive-mod fallback.
 local path='data/generated/gba/rse/rs_contest_gfx/manifest.lua'
 local man=assert(loadstring(files[path] or assert(base:read(path))))()
 local byIR,ambiguous,byKey,original={},{},{},{}
 for key,row in mod.content.text:each()do original[key]=row end
 for _,op in ipairs(operations)do if op.registry=='text' and op.method=='override' then byKey[op.key]=op.value end end
 for key,row in pairs(byKey)do if original[key] then
  local identity=W.encode(original[key])
  if not ambiguous[identity] then
   if byIR[identity] and W.encode(byIR[identity])~=W.encode(row) then byIR[identity]=nil;ambiguous[identity]=true else byIR[identity]=row end
  end
 end end
 local aliases={["gText_AppealNumWhichMoveWillBePlayed"]="gText_Contest_WhichMoveWillBePlayed",["gText_AppealNumButItCantParticipate"]="gText_Contest_ButItCantParticipate",["gText_MonWasTooNervousToMove"]="ContestString_TooNervous",["gText_MonCantAppealNextTurn"]="ContestString_CantAppealNextTurn",["gText_AppealComboWentOverWell"]="ContestString_WentOverWell",["gText_AppealComboWentOverVeryWell"]="ContestString_WentOverVeryWell",["gText_AppealComboWentOverExcellently"]="ContestString_AppealComboExcellently",["gText_JudgeLookedAtMonExpectantly"]="ContestString_JudgeExpectantly2",["gText_RepeatedAppeal"]="ContestString_DissapointedRepeat",["gText_MonsXDidntGoOverWell"]="ContestString_DidntGoWell",["gText_MonsXWentOverGreat"]="ContestString_WentOverGreat",["gText_MonsXGotTheCrowdGoing"]="ContestString_GotCrowdGoing",["gText_CrowdContinuesToWatchMon"]="ContestString_CrowdWatches",["gText_MonsMoveIsIgnored"]="ContestString_Ignored2",["gText_AnnouncingResults"]="gContestText_AnnounceResults",["gText_PreliminaryResults"]="gContestText_PreliminaryResults",["gText_Round2Results"]="gContestText_Round2Results",["gText_ContestantsMonWon"]="gContestText_PokeWon",["gText_LinkStandby"]="gOtherText_LinkStandby",["gText_LinkStandby4"]="gOtherText_LinkStandby",["gText_CommunicationStandby"]="gOtherText_LinkStandby"}
 man.localizedTexts={};local missing={}
 for key,bytes in pairs(man.texts)do
  local decoded=IR.decode(bytes,{dialect='rs'})
  local sourceKey=aliases[key] or key
  local target=original[sourceKey] and W.encode(original[sourceKey])==W.encode(decoded) and byKey[sourceKey] or byIR[W.encode(decoded)]
  if not target and not IR.toPlain(decoded,{}):match('%a') then target=decoded end
  if target then
   local native={}
   for _,seg in ipairs(target)do
    -- Ruby's contest printer interprets FC 00 as its turn-number buffer,
    -- unlike the ordinary field decoder. Keep that native meaning.
    native[#native+1]=seg.t=='ext' and seg.cmd==0 and {t='strvar',n=1} or seg
   end
   man.localizedTexts[key]=native
  else missing[#missing+1]=key end
 end
 assert(#missing==0,'Untranslated native RS contest records: '..table.concat(missing,', '))
 files[path]=W.encode(man)

 -- Result comments and condition names live in a second raw-byte pack.
 local path='data/generated/gba/rse/contest_data/manifest.lua'
 local man=assert(loadstring(assert(base:read(path))))()
 for _,field in ipairs({'appealResultTexts','roundResultTexts','conditionTexts','invalidMoveNames'})do
  for index,entry in pairs(man[field])do
   local decoded=IR.decode(entry.bytes,{dialect='rs'})
   local target=byIR[W.encode(decoded)]
   if not target and not IR.toPlain(decoded,{}):match('%a')then target=decoded end
   assert(target,'Untranslated native contest '..field..':'..index)
   entry.localizedIR=target
  end
 end
 files[path]=W.encode(man)

 local path='data/generated/gba/rse/rs_egg_hatch/manifest.lua'
 local man=assert(loadstring(assert(base:read(path))))();man.localizedTexts={}
 for key,sourceKey in pairs({hatched='gOtherText_HatchedFromEgg',nickname='gOtherText_NickHatchPrompt',yes='OtherText_Yes',no='OtherText_No'})do
  local decoded=IR.decode(assert(man.texts[key]),{dialect='rs'})
  assert(W.encode(decoded)==W.encode(assert(original[sourceKey])),'Native egg-hatch source changed: '..key)
  man.localizedTexts[key]=assert(byKey[sourceKey],'Untranslated native hatch text: '..key)
 end
 files[path]=W.encode(man)

end
