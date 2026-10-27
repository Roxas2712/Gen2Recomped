package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local V = require("src.core.GameVersion")
V.set("red")
local P = require("src.ui.PokedexMenu")
local function listing(numbers,limit,digits)
  local data={constants={dexSize=limit,dexDigits=digits or 3},pokemon={}}
  local seen={}
  for _,n in ipairs(numbers)do
    local id="MON"..n
    data.pokemon[id]={id=id,name=id,dex=n};seen[id]=true
  end
  return P.new({data=data,save={pokedex={seen=seen,owned={}}},stack={push=function()end}}).items
end
local dense=listing({1,2,3},3)
T.eq(#dense,3,"complete native roster retains every row")
for i=1,3 do T.eq(dense[i].label,("%03d MON%d"):format(i,i),"native row text remains unchanged")end
local sparse=listing({1,3,152,201},200)
T.eq(#sparse,3,"gaps do not hide later registered species and dexSize remains the bound")
for i,n in ipairs{1,3,152}do
  T.eq(sparse[i].value,"MON"..n,"national order remains sorted across gaps")
  T.eq(sparse[i].label,("%03d MON%d"):format(n,n),"display retains each species national number")
end
local extended=listing({152},200,4)
T.eq(#extended,1,"a sparse extension is reachable")
T.eq(extended[1].label,"0152 MON152","custom dexDigits remains effective")
T.eq(#listing({152},151),0,"outside-bound species remain excluded")
T.finish("pokedex_sparse_national")
