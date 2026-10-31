package.path='./?.lua;'..package.path
local P=require('tools.windows-demo.Profile')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local data={['Gen2Recomp/options.lua']='original options',['Gen2Recomp/saves/red/slot1.lua']='original save',
 ['Gen2Recomp/data/generated/cache.lua']='original import',['LOVE/Gen2Recomp-NativePreview-20261023-1/options.lua']='older preview'}
local writes=0;local unmounted=false;local readOnly=false
local fs={getAppdataDirectory=function()return'C:/Users/Ömega/AppData/Roaming'end,
 mountFullPath=function(_,_,permission)readOnly=permission=='read';return true end,
 unmountFullPath=function()unmounted=true;return true end,
 getDirectoryItems=function(path)if path=='__retro_windows_profiles'then return{'Gen2Recomp','LOVE','UnrelatedApp','RetroRecomped-Windows-Demo'}else return{'Gen2Recomp-NativePreview-20261023-1'}end end,
 getInfo=function(path)path=path:gsub('^__retro_windows_profiles/','');if data[path]then return{type='file'}end;for key in pairs(data)do if key:sub(1,#path+1)==path..'/'then return{type='directory'}end end end,
 read=function(path)return data[path]end,write=function(path,bytes)writes=writes+1;data[path]=bytes;return true end,
 remove=function(path)data[path]=nil;return true end}
local rows=assert(P.scan(fs))
check(#rows==2 and readOnly and unmounted and writes==0,'discovery reads both fused and LOVE profiles without writing any existing data')
check(rows[1].identity=='Gen2Recomp'and rows[1].imports and rows[1].progress,'normal saves and ROM caches are recognized')
check(not P.choose(rows),'ambiguous profiles require a choice rather than merging accounts')
check(P.choose(rows,{identity='LOVE/Gen2Recomp-NativePreview-20261023-1'}).identity:match('^LOVE/'),'a remembered profile keeps its exact old path')
check(P.choose({rows[1]}).identity=='Gen2Recomp','a single existing profile is selected automatically')
check(P.choose({}).new,'a clean installation gets a stable standard profile')
for _,bad in ipairs{'../Gen2Recomp','C:/private','LOVE/../Gen2Recomp','UnrelatedApp','RetroRecomped-Windows-Demo','RetroRecomped-qa-20261030'}do check(not P.valid(bad),'reject unrelated, QA and escaping profile '..bad)end
check(P.remember(fs,rows[1])and P.readChoice(fs).identity=='Gen2Recomp','only the bootstrap selection is remembered')
check(data['Gen2Recomp/options.lua']=='original options'and data['Gen2Recomp/saves/red/slot1.lua']=='original save'and data['Gen2Recomp/data/generated/cache.lua']=='original import','selection preserves original options, saves and ROM cache bytes')
data[P.FILE]='damaged selection';local before=writes
check(not P.remember(fs,rows[1])and writes==before,'damaged selections remain intact for recovery')
fs.mountFullPath=function()return false end
check(not P.scan(fs),'inaccessible profile discovery cannot masquerade as an empty installation')
print('Windows demo profiles: '..n..' checks passed (filesystem fixture)')
