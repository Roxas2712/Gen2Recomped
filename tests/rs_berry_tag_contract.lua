love=require('tests.love_stub');love.filesystem.load=loadfile
local checks=0
local function check(value,why)checks=checks+1;assert(value,why)end
local load=require('compat.gen1-rs.Loader').new('ruby')
local Data=load('src.ui.game3.rs.berry_tag_data')
for _,row in ipairs({{0,0,0},{1,0,0},{10,0,4},{20,0,8},{35,1,4},{100,3,9}})do
  local a,b=Data.sizeParts(row[1]);check(a==row[2]and b==row[3],'Native size conversion/rounding')
end
check(Data.sizeText({strings={unknown='???'}},0)=='???','Unknown original size')
for _,bad in ipairs({{}, {enigmaBerryNativeBytes={1,2}}, {enigmaBerryNativeBytes=string.rep('\0',1328)}})do
  check(Data.enigma(bad)==nil,'Invalid custom data must fall back')
end
local raw={};for i=1,1328 do raw[i]=0 end
raw[1],raw[2],raw[8],raw[9],raw[11],raw[21]=187,255,3,10,1,1
raw[1213],raw[1258]=255,255
local function checksum()
  local sum=0;for off=0,1323 do if off<12 or off>=20 then sum=sum+raw[off+1]end end
  for i=0,3 do raw[1325+i]=math.floor(sum/256^i)%256 end
end
checksum();local record=Data.enigma({enigmaBerryNativeBytes=raw})
check(record and record.name=='A'and record.firmness==3 and record.size==10 and #record.pic==1152,
  'Valid original Enigma structure')
raw[100]=1;check(Data.enigma({enigmaBerryNativeBytes=raw})==nil,'Invalid Enigma checksum')
checksum();check(Data.enigma({enigmaBerryNativeBytes=raw})~=nil,'Updated native checksum')
raw[11]=0;checksum();check(Data.enigma({enigmaBerryNativeBytes=raw})==nil,'Missing native berry stage duration')
raw[11]=1;raw[21]=0;checksum();check(Data.enigma({enigmaBerryNativeBytes=raw})==nil,'Missing native berry yield')
raw[21]=1;raw[50]=256;checksum();check(Data.enigma({enigmaBerryNativeBytes=raw})==nil,'Non-byte original data')
local Gate=require('src.import.Gen3RsBerryTagAssets')
check(not Gate.valid({format=1,version='ruby',resources={}},'ruby'),'Incomplete old import rejected')
local paths={};for i=1,49 do paths[i]='private-'..i end
check(Gate.valid({format=1,version='ruby',resources=paths},'ruby'),'Current matching metadata')
check(not Gate.valid({format=1,version='ruby',resources=paths},'sapphire'),'Mixed edition rejected')
check(not Gate.valid({format=1,version='emerald',resources=paths},'emerald'),'Other edition does not use RS scene')
print('RS_BERRY_TAG_CONTRACT_CHECKS',checks)
