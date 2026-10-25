-- ROM-free geometry contracts; source textures are never decoded or edited here.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local C=require('src.import.LauncherCobblemon')
local Json=require('src.link.Json')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local base='assets/launcher/cobblemon/'
local function read(path) local f=assert(io.open(path,'rb'));local b=f:read('*a');f:close();return b end
for _,name in ipairs({'haunter','delibird'}) do
  local model=assert(Json.decode(read(base..name..'.launcher.json')))
  check(model.source=='Cobblemon Assets' and model.license=='CC-BY-NC-3.0','derived mesh retains its third-party attribution')
  for i,bone in ipairs(model.bones) do
    check(bone.parent==nil or bone.parent<i,'parents precede children and cannot form a traversal cycle')
  end
  local a=C.geometry(model,name,2,{action=0});local b=C.geometry(model,name,4,{action=1})
  check(#a>0 and #a==#b and #a%6==0,'a complete animated mesh has stable triangle capacity')
  local changed=false
  for i,v in ipairs(a) do
    for _,x in ipairs(v) do assert(type(x)=='number' and x==x and math.abs(x)<10000,'finite mesh coordinates') end
    assert(v[3]>=0 and v[3]<=1 and v[4]>=0 and v[4]<=1,'UVs stay within the pinned texture')
    if v[1]~=b[i][1] or v[2]~=b[i][2] then changed=true end
  end
  check(changed,'mascot action and idle motion actually move the model')
  local again=C.geometry(model,name,2,{action=0})
  for i,v in ipairs(a) do for j,x in ipairs(v) do assert(x==again[i][j],'equal animation time produces identical mesh data') end end
  n=n+1
end
local model={width=16,height=16,idle={},bones={{name='torso',pivot={0,0,0},rotation={0,0,0},cubes={
  {['from']={-1,0,-1},to={1,2,1},pivot={0,0,0},rotation={0,0,0},faces={north={0,0,8,8}}}}}}}
local v=C.geometry(model,'haunter',0,{action=0})
check(v[1][2]<v[3][2] and v[1][3]==0 and v[1][4]==0 and v[3][3]==.5 and v[3][4]==.5,
  'front face maps texture top-left to model top-left without a rotated face')
check(C.draw('spring',0,{x=0,y=0,alpha=1},1)==false,'unavailable models use the existing seasonal fallback')
print('Cobblemon launcher geometry: '..n..' checks passed')
