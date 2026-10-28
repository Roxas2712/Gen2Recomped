local P=require('src.import.Gen3FrlgPresentation')
local function encode(t)
 if type(t)=='table'then local a={};for k,v in pairs(t)do a[#a+1]='['..(type(k)=='number'and tostring(k)or string.format('%q',k))..']='..encode(v)end;return '{'..table.concat(a,',')..'}'end
 if type(t)=='string'then return string.format('%q',t)end
 return tostring(t)
end
local count=0
for version,at in pairs(P.TEXT_WINDOWS)do
 local font={}
 for _,r in ipairs({{'dialogueFrame','message',0},{'signpostFrame','sign',1},{'standardFrame','standard',3}})do
  font[r[1]]={image='assets/generated/'..r[1]..'.png',fill={1,1,1},
   source=r[1]=='standardFrame'and string.format('ROM:gStdTextWindow_Gfx %07X, gTextWindowPalettes[3] %07X',at.standard,at.palette+96)
   or string.format('ROM:gfx %07X, gTextWindowPalettes[%d] %07X',at[r[2]],r[3],at.palette+32*r[3])}
 end
 local function fs()return {read=function()return 'return '..encode(font)end,exists=function()return true end}end
 assert(#P.textMissing(version,fs())==0);count=count+1
 for _,key in ipairs({'dialogueFrame','signpostFrame','standardFrame'})do
  local row=font[key];local source=row.source;row.source='wrong edition';assert(#P.textMissing(version,fs())==1);row.source=source;count=count+1
  row.fill[2]=0;assert(#P.textMissing(version,fs())==1);row.fill[2]=1;count=count+1
 end
 assert(#P.textMissing(version,{read=fs().read,exists=function()return false end})==3);count=count+1
 assert(#P.textMissing(version,{read=function()return 'invalid lua' end})==1);count=count+1
end
assert(#P.textMissing('sapphire',{})==0);count=count+1
print('PASS_FRLG_TEXT_WINDOW_READINESS',count)
