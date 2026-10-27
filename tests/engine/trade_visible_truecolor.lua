package.path="./?.lua;./?/init.lua;"..package.path
love=require("tests.love_stub")
local T=require("tests.modkit")
local Trade=require("src.ui.TradeAnim")
local pic={getDimensions=function()return 56,56 end}
local item={kind="pic",tx=7,ty=2,img=pic,trueColor=true}
local function frame(scroll)
 local trade=setmetatable({img={},bgp=0xe4},{__index=Trade})
 trade:drawMap({cells={},items={item}},-scroll,0,true)
 return trade.trueColorRect
end
for _,case in ipairs{{0,56},{56,0},{80,-24},{200,112},{240,72}}do
 local r=frame(case[1])
 T.eq(type(r),"table","a visible BG ring copy retains its rectangle")
 T.eq(r and r[1],case[2],"the visible copy owns the exclusion rectangle")
 T.eq(r and r[2],16,"native 7x7 slot stays on row two")
 T.eq(r and r[3],56,"native picture width is preserved")
 T.eq(r and r[4],56,"native picture height is preserved")
end
T.eq(frame(120),nil,"two fully offscreen copies add no rectangle")
item.trueColor=false
T.eq(frame(0),nil,"indexed art adds no true-color rectangle")
T.finish("trade_visible_truecolor")
