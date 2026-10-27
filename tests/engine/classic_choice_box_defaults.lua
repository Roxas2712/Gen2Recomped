package.path = "./?.lua;./?/init.lua;" .. package.path
local T=require("tests.modkit")
local Theme=require("src.ui.Theme")
local Choice=require("src.ui.ChoiceBox")
local original=Theme.choiceBox
local function check(x,y,w,h,label)
  T.eq(Theme.choiceBox,original,label.." preserves the public table")
  T.same({Theme.choiceBox.tx,Theme.choiceBox.ty,Theme.choiceBox.tw,Theme.choiceBox.th},{x,y,w,h},label)
  local box=Choice.new({},function()end)
  T.same({box.tx,box.ty,box.tw,box.th},{x,y,w,h},label.." reaches the actual widget")
end
check(14,7,6,5,"classic defaults match pinned Gen1 reference")
for _,kind in ipairs{"isGen3Cache","isGen4Cache","isGen5Cache"}do
  Theme.load({[kind]=true});check(13,7,7,6,kind.." retains native geometry")
  Theme.load({});check(14,7,6,5,"return to classic resets geometry")
end
Theme.load({field={theme={choiceBox={tx=2,tw=9}}}})
check(2,7,9,5,"authored theme remains authoritative")
T.finish("classic_choice_box_defaults")
