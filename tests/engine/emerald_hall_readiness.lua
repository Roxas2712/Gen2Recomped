-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3EmeraldHallAssets')
local UI=require('src.ui.Gen3EmeraldHallOfFame');local V=require('src.core.GameVersion')
local Fs,W=require('src.import.CacheFs'),require('src.import.LuaWriter')
local old,read,exists=V.get(),Fs.read,Fs.exists;V.set('emerald')
local text={};for _,name in ipairs{'gText_Number','gText_Level','gText_IDNumber','gText_Name','gText_Time',
  'gText_WelcomeToHOF','gText_SavingDontTurnOffPower','gText_EggNickname','gText_LeagueChamp','gText_SaveFailed'}do text[name]={{t='text',s='OWNED LABEL'}}end
local spec={format=1,version='emerald',resources=M.resources(),manifest=M.ROOT..'emerald.lua',textIR=text,
  trainerPics={boy='OWNED_BOY.png',girl='OWNED_GIRL.png'}}
local constants={gen3EmeraldHall=spec}
local man={format=1,version='emerald',width=240,height=160,confettiFrames=17,frames={message_box={width=64,height=16}}}
local art={format_version=1,width=240,height=160,confetti={w=8,h=8,frames=17}}
local files,bodies={},{};for _,p in ipairs(spec.resources)do files[p]=true end
for _,p in pairs(spec.trainerPics)do files[p]=true end
local function write()
  bodies['data/generated/constants.lua']=W.encode(constants);bodies[spec.manifest]=W.encode(man)
  bodies[M.ROOT..'manifest.lua']=W.encode(art)
end
Fs.read=function(path)return bodies[path]end;Fs.exists=function(path)return files[path]or false end;write()
T.eq(M.valid(spec,'emerald'),true,'Emerald native ceremony metadata accepted')
T.eq(UI.available({data={constants=constants}}),true,'native Emerald ceremony selected')
T.eq(#M.missing(),0,'original bands, stripes, confetti, text and twenty frames ready')
for _,p in ipairs(spec.resources)do
  files[p]=nil;T.check(#M.missing()>0,'every native art/frame resource required: '..p);files[p]=true
end
for _,p in pairs(spec.trainerPics)do files[p]=nil;T.check(#M.missing()>0,'original trainer portrait required: '..p);files[p]=true end
local first=spec.resources[1];spec.resources[1]=spec.resources[2]
T.eq(M.valid(spec,'emerald'),false,'duplicated resources cannot substitute for native assets');spec.resources[1]=first
local keys={};for key in pairs(text)do keys[#keys+1]=key end
for _,key in ipairs(keys)do local value=text[key];text[key]=nil;write();T.check(#M.missing()>0,'original label required: '..key);text[key]=value end
for _,key in ipairs{'format','version','width','height','confettiFrames','frames'}do
  local value=man[key];man[key]=nil;write();T.check(#M.missing()>0,'native metadata required: '..key);man[key]=value
end
for _,key in ipairs{'w','h','frames'}do local value=art.confetti[key];art.confetti[key]=0;write();T.check(#M.missing()>0,'native confetti contract: '..key);art.confetti[key]=value end
write();bodies[spec.manifest]='return invalid lua';T.check(#M.missing()>0,'corrupt native manifest rejected safely')
constants.gen3EmeraldHall=nil;write();T.check(#M.missing()>0,'approximate old Hall import rejected')
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','red','gold'}do
  V.set(version);T.eq(UI.available({data={constants={gen3EmeraldHall=spec}}}),false,'other edition unchanged: '..version)
end
Fs.read,Fs.exists=read,exists;V.set(old)
T.finish('Emerald native Hall art, original labels, twenty frames and edition isolation')
