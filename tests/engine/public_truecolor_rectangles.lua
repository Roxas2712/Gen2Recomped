package.path = "./?.lua;./?/init.lua;" .. package.path
local T=require("tests.modkit")
local P=require("src.render.PaletteFX")
local Perf=require("src.core.Performance")
Perf.hotPathHoist=true
P.clearTrueColor();P.setPass("world")
P.markTrueColor(1,2,3,4)
local pool,n=P._trueColorRectsForEngine("world");local private=pool[1]
T.eq(n,1,"native count sees one mark")
P.clearTrueColor();P.markTrueColor(8,9,3,4)
local again=P._trueColorRectsForEngine("world")
T.eq(again[1],private,"unobserved native path reuses its private record")
local rows=P.trueColorRects("world");local retained=rows[1]
T.eq(#rows,1,"public array contains only live marks")
T.neq(retained,private,"public records do not expose the pool")
T.eq(select("#",P.trueColorRects("world")),1,"public return arity matches the pinned reference")
P.markTrueColor(10,11,1,2);T.eq(#rows,2,"same-frame marks update an already returned array")
P.clearTrueColor();T.eq(#rows,0,"clear empties the public array")
P.markTrueColor(20,21,1,2)
T.eq(P.trueColorRects("world"),rows,"public array identity remains stable")
T.eq(retained.x,8,"retained public record is not rewritten by a later frame")
T.neq(rows[1],retained,"later frames use fresh public records")
rows[1].x=77
local visible,count=P._trueColorRectsForEngine("world")
T.eq(visible[1].x,77,"native rendering honours public record edits")
rows[1]=nil;P.markTrueColor(30,31,1,2)
T.eq(#rows,1,"new marks append correctly after caller removal")
T.eq(rows[1].x,30,"no sparse public holes after caller removal")
P.clearTrueColor();P.setPass("ui");P.setMarkOffset(12);P.markTrueColor(1,2,3,4)
T.eq(P.trueColorRects("ui")[1].x,13,"classic UI mark offset is restored")
P.clearTrueColor();P.markTrueColor(1,2,3,4)
T.eq(P.trueColorRects("ui")[1].x,1,"clear resets UI mark offset")
P.setPass(nil);P.markTrueColor(1,2,3,4)
T.eq(#P.trueColorRects("ui"),1,"upright/no-pass draws add no rectangle")
local invalid=P.trueColorRects("invalid");invalid[1]={}
T.eq(#P.trueColorRects("invalid"),0,"unknown pass returns an independent empty array")
local original=P.trueColorRects;local custom={{colors=false,x=1,y=2,w=3,h=4}};local calls=0
P.trueColorRects=function(pass)calls=calls+1;T.eq(pass,"world","public override receives the pass");return custom end
for _,enabled in ipairs{false,true}do
 Perf.hotPathHoist=enabled
 local returned,size=P._trueColorRectsForEngine("world")
 T.eq(returned,custom,"public override remains authoritative")
 T.eq(size,1,"old one-result overrides need no count adaptation")
end
T.eq(calls,2,"both flag states dispatch through the public override")
P.trueColorRects=original
T.finish("public_truecolor_rectangles")
