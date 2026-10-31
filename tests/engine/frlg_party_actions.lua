-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3FrlgPartyActions')
local X=require('src.import.RomExtractorGen3');local Party=require('src.ui.Gen3PartyMenu')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local Assets=require('src.import.Gen3NativePartyAssets')
local listRows={{0,1,2},{10,0,2},{11,0,2},{12,0,2},{13,0,2},{14,0,2},
 {0,2},{4,5,9},{8,7,9},{15,0,2},{16,0,2},{17,0,2}}
local ids={148,15,19,70,57,249,127,100,91,208,135,230}
local moves={'FLASH','CUT','FLY','STRENGTH','SURF','ROCK_SMASH','WATERFALL','TELEPORT','DIG','MILK_DRINK','SOFT_BOILED','SWEET_SCENT'}
local function fixture(version,mode)
 local words,bytes,text={},{},{};local base,anchor,messagesAt,moveNames=4096,8192,12288,16384
 local function put(at,value)words[at]=value end
 local names=require('src.import.gba.text_labels.'..version)
 local first=base+30*8;put(anchor,0);local at=first
 for i,list in ipairs(listRows)do put(anchor+i*4,at+0x08000000);for j,value in ipairs(list)do bytes[at+j-1]=value end;at=at+#list end
 for i=0,17 do
  local str=20000+i*100;if i==9 then str=20200 end
  put(base+i*8,str+0x08000000);put(base+i*8+4,0x08002001+i*2)
  text[str]=i==5 and 'TAKE'or i==7 and 'TAKE'or 'LABEL'..i
 end
 for i,id in ipairs(ids)do
  local str=moveNames+id*13;put(base+(17+i)*8,str+0x08000000)
  put(base+(17+i)*8+4,0x08003001);text[str]=moves[i]
 end
 for i=0,26 do local str=30000+i*100;put(messagesAt+i*4,str+0x08000000);text[str]=i==21 and ''or'MESSAGE'..i end
 for i,name in ipairs{'gText_ChoosePokemon','gText_ChoosePokemonCancel','gText_ChoosePokemonConfirm'}do
  put(messagesAt+(i-1)*4,names[name]+0x08000000);text[names[name]]='MESSAGE'..(i-1)
 end
 if mode=='bad-list'then bytes[first]=2 end
 if mode=='bad-callback'then put(base+18*8+4,0x08003000)end
 if mode=='bad-move'then put(base+19*8,moveNames+1+0x08000000)end
 if mode=='bad-empty'then text[32100]='not empty'end
 if mode=='ambiguous-messages'then
  for i=0,2 do put(40000+i*4,words[messagesAt+i*4])end
 end
 local rom={size=0x500000}
 function rom:u32(o)return words[o]or 0 end
 function rom:u8(o)return bytes[o]or 0 end
 function rom:pointer(o)local value=self:u32(o);return value>=0x08000000 and value<0x08000000+self.size and value-0x08000000 or nil end
 local x=setmetatable({version=version,manifest={metatileAttributes={bytes=4}},rom=rom,_constants={sentinel=true},_moveIds={},
  beginStage=function()end,symbol=function(_,key)return key=='sPartyMenuActions'and anchor or key=='gMoveNames'and moveNames end,
  layoutValue=function(_,_,fallback)return fallback end,readString=function(_,o)return text[o]end,
  write=function(self,key,value)self.written={key,value}end},X)
 for i,id in ipairs(ids)do x._moveIds[id]=moves[i]end
 return x,anchor,moveNames
end
for _,version in ipairs{'firered','leafgreen'}do
 local x,anchor,moveNames=fixture(version);x:extractPartyActions();local record=x._constants.gen3PartyActions
 T.eq(M.valid(record,version),true,'actual extractor admits the FRLG pointer-array layout')
 T.eq(record.labels.toss,nil,'FRLG has eighteen fixed rows; Hoenn TOSS cannot shift FLASH away')
 T.eq(record.messages.doWhatWithMon,'MESSAGE22');T.eq(record.messages.restoreWhichMove,'MESSAGE23')
 T.eq(record.messages.doWhatWithItem,'MESSAGE25');T.eq(record.messages.doWhatWithMail,'MESSAGE26')
 for i,move in ipairs(moves)do T.eq(record.fieldMoves[i].move,move);T.eq(record.fieldMoves[i].index,ids[i])end
 local p=setmetatable({game={data={constants=x._constants}}},Party)
 local rows=p:fieldMovesOf({moves={{id='STRENGTH'},{id='BITE'},{id='SURF'},{id='DIG'}}})
 T.same({rows[1].move,rows[2].move,rows[3].move},{'STRENGTH','SURF','DIG'},'owned move order reaches the real party submenu')
 T.eq(x._constants.sentinel,true);T.eq(x.written[1],'constants')
 for _,mode in ipairs{'bad-list','bad-callback','bad-move','bad-empty','ambiguous-messages'}do
  local bad,a,m=fixture(version,mode);T.raises(function()M.extract(bad,a,m)end)
  T.eq(bad._constants.gen3PartyActions,nil,'invalid/ambiguous ROM data cannot certify completed imports')
 end
end
local oldRead,oldExists,oldValid=Fs.read,Fs.exists,Assets.valid
Assets.valid=function()return true end;Fs.exists=function()return true end
local constants={gen3NativeParty={}};Fs.read=function()return Writer.encode(constants)end
for _,version in ipairs{'firered','leafgreen'}do
 constants.gen3PartyActions=nil
 T.eq(Assets.missing(version)[1],'<'..version..':native-party-field-actions>','old completed caches refresh their absent actions')
 constants.gen3PartyActions=require('tests.fixtures.frlg_party_actions').record(version)
 T.eq(#Assets.missing(version),0)
end
Fs.read,Fs.exists,Assets.valid=oldRead,oldExists,oldValid
T.finish('Actual FRLG party actions, native message enum, field menu and completed-cache admission')
