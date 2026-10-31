-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FRLG's manifest names the action-list pointer array, not Hoenn's SHIFT text.
local M={}
local keys={'summary','switch','cancel','item','give','takeItem','mail','takeMail',
 'read','cancel2','shift','sendOut','enter','noEntry','store','register','trade1','trade2'}
local lists={{0,1,2},{10,0,2},{11,0,2},{12,0,2},{13,0,2},{14,0,2},
 {0,2},{4,5,9},{8,7,9},{15,0,2},{16,0,2},{17,0,2}}
local messages={chooseMon=0,chooseMonOrCancel=1,chooseMonAndConfirm=2,moveToWhere=3,
 teachWhichMon=4,useOnWhichMon=5,giveToWhichMon=6,nothingToCut=7,cantSurfHere=8,
 alreadySurfing=9,currentTooFast=10,enjoyCycling=11,inUseAlready=12,cantUseHere=13,
 noMonForBattle=14,notEnoughHp=16,doWhatWithMon=22,restoreWhichMove=23,
 boostPpWhichMove=24,doWhatWithItem=25,doWhatWithMail=26}
function M.valid(record,version)
 if type(record)~='table'or record.format~=1 or record.version~=version
  or type(record.labels)~='table'or type(record.fieldMoves)~='table'
  or #record.fieldMoves~=12 or type(record.messages)~='table'then return false end
 for _,key in ipairs(keys)do
  if key~='cancel2'and(type(record.labels[key])~='string'or record.labels[key]=='')then return false end
 end
 local seen={}
 for _,row in ipairs(record.fieldMoves)do
  if type(row.move)~='string'or seen[row.move]or type(row.label)~='string'or row.label==''then return false end
  seen[row.move]=true
 end
 for key in pairs(messages)do if type(record.messages[key])~='string'or record.messages[key]==''then return false end end
 return true
end
function M.extract(x,anchor,moveNames)
 local rom=x.rom
 assert(anchor and moveNames and rom:u32(anchor)==0,'FRLG party action-list anchor unavailable')
 local first=assert(rom:pointer(anchor+4),'FRLG first action list unavailable')
 for i,list in ipairs(lists)do
  local at=assert(rom:pointer(anchor+i*4),'FRLG action list missing')
  for j,value in ipairs(list)do assert(rom:u8(at+j-1)==value,'FRLG action-list enum mismatch')end
 end
 local base=first-(#keys+12)*8;assert(base>=0,'FRLG cursor options outside ROM')
 local rows,funcs,labels={},{},{}
 for i=0,#keys+11 do
  local at=base+i*8;local text=assert(rom:pointer(at),'FRLG action text pointer missing')
  local fn=rom:u32(at+4)
  assert(fn and fn%2==1 and fn>=0x08000000 and fn<0x08000000+rom.size,'FRLG cursor callback invalid')
  rows[i]={text=text,label=x:readString(text,64)};funcs[i]=fn
  assert(type(rows[i].label)=='string'and rows[i].label~='','FRLG action label empty')
 end
 assert(rows[2].text==rows[9].text and rows[5].label==rows[7].label,'FRLG repeated CANCEL/TAKE mismatch')
 for i,key in ipairs(keys)do if key~='cancel2'then labels[key]=rows[i-1].label end end
 local fieldMoves,seen={},{};local stride=x:layoutValue('moveNameLength',13)
 for i=#keys,#keys+11 do
  local delta=rows[i].text-moveNames
  assert(funcs[i]==funcs[#keys]and delta>=0 and delta%stride==0,'FRLG field-move row mismatch')
  local index=delta/stride;local move=x._moveIds and x._moveIds[index]
  assert(type(move)=='string'and not seen[move],'FRLG field-move identity invalid');seen[move]=true
  fieldMoves[#fieldMoves+1]={move=move,index=index,label=rows[i].label}
 end
 -- FRLG inserts TWO_MONS_ARE_NEEDED, so its empty/message slots differ from Hoenn.
 local names=require('src.import.gba.text_labels.'..x.version)
 local tableAt,count=nil,0
 for at=0,rom.size-108,4 do
  if rom:u32(at)==names.gText_ChoosePokemon+0x08000000
   and rom:u32(at+4)==names.gText_ChoosePokemonCancel+0x08000000
   and rom:u32(at+8)==names.gText_ChoosePokemonConfirm+0x08000000 then tableAt,count=at,count+1 end
 end
 assert(count==1,'FRLG party message table is ambiguous')
 local empty=assert(rom:pointer(tableAt+21*4),'FRLG empty message pointer absent')
 assert(x:readString(empty,64)=='','FRLG message enum is misaligned')
 local text={}
 for key,index in pairs(messages)do text[key]=x:readString(assert(rom:pointer(tableAt+index*4)),128)end
 local record={format=1,version=x.version,labels=labels,fieldMoves=fieldMoves,messages=text,
  source=('ROM:sCursorOptions %07X; sPartyMenuActions %07X; sActionStringTable %07X'):format(base,anchor,tableAt)}
 assert(M.valid(record,x.version),'FRLG party action record incomplete')
 x._constants=x._constants or{};x._constants.gen3PartyActions=record;x:write('constants',x._constants)
 return record
end
return M
