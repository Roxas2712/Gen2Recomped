-- Original native vector artwork by Roxas2712. No Gen1 launcher atlas.
-- Geometry is expressed on a 24-unit canvas and drawn at the caller's scale.
local Icons={NAMES={},ATLASES={}}
local shapes={
 ['x']={{'line',5,5,19,19},{'line',19,5,5,19}},
 ['check']={{'line',4,12,9,17,20,6}},
 ['plus']={{'line',4,12,20,12},{'line',12,4,12,20}},
 ['minus']={{'line',4,12,20,12}},
 ['chevron-left']={{'line',15,5,8,12,15,19}},
 ['chevron-right']={{'line',9,5,16,12,9,19}},
 ['chevron-up']={{'line',5,15,12,8,19,15}},
 ['chevron-down']={{'line',5,9,12,16,19,9}},
 ['arrow-left']={{'line',20,12,4,12,10,6},{'line',4,12,10,18}},
 ['arrow-right']={{'line',4,12,20,12,14,6},{'line',20,12,14,18}},
 ['arrow-up']={{'line',12,20,12,4,6,10},{'line',12,4,18,10}},
 ['arrow-down']={{'line',12,4,12,20,6,14},{'line',12,20,18,14}},
 ['arrow-up-down']={{'line',8,20,8,4,4,8},{'line',8,4,12,8},{'line',16,4,16,20,12,16},{'line',16,20,20,16}},
 ['arrow-left-right']={{'line',21,8,3,8,7,4},{'line',3,8,7,12},{'line',3,16,21,16,17,12},{'line',21,16,17,20}},
 ['chevrons-up']={{'line',5,12,12,5,19,12},{'line',5,19,12,12,19,19}},
 ['folder']={{'line',3,19,3,5,10,5,12,8,21,8,21,19,3,19}},
 ['folder-open']={{'line',3,18,3,5,10,5,12,8,20,8,20,11},{'line',3,18,7,11,22,11,18,19,3,19}},
 ['save']={{'rectangle','line',4,3,16,18},{'rectangle','line',8,3,8,6},{'rectangle','line',8,14,8,7}},
 ['download']={{'line',12,3,12,15,7,10},{'line',12,15,17,10},{'line',4,16,4,21,20,21,20,16}},
 ['upload']={{'line',12,16,12,4,7,9},{'line',12,4,17,9},{'line',4,16,4,21,20,21,20,16}},
 ['trash']={{'line',4,6,20,6},{'line',8,6,8,3,16,3,16,6},{'line',6,6,7,21,17,21,18,6},{'line',10,9,10,17},{'line',14,9,14,17}},
 ['pencil']={{'line',4,20,5,15,17,3,21,7,9,19,4,20},{'line',14,6,18,10}},
 ['paintbrush']={{'line',10,14,19,3,22,6,13,17,10,14},{'line',10,14,6,14,4,18,2,20,8,21,12,18,13,17}},
 ['file-pen-line']={{'line',16,8,16,3,4,3,4,21,12,21},{'line',12,3,16,7,12,7,12,3},{'line',12,20,13,16,20,9,23,12,16,19,12,20}},
 ['copy']={{'rectangle','line',3,3,12,12},{'rectangle','line',8,8,13,13}},
 ['undo-2']={{'line',3,11,3,5,9,5},{'line',3,10,8,6,15,6,20,10,20,15,16,19,10,19}},
 ['redo-2']={{'line',21,11,21,5,15,5},{'line',21,10,16,6,9,6,4,10,4,15,8,19,14,19}},
 ['rotate-ccw']={{'line',3,10,3,4,9,4},{'line',3,9,8,4,15,4,20,9,20,15,15,20,8,20,4,16}},
 ['ellipsis']={{'circle','fill',5,12,1.5},{'circle','fill',12,12,1.5},{'circle','fill',19,12,1.5}},
 ['lock']={{'rectangle','line',5,10,14,11},{'line',8,10,8,5,10,3,14,3,16,5,16,10},{'line',12,14,12,17}},
 ['lock-open']={{'rectangle','line',5,10,14,11},{'line',8,10,8,5,10,3,14,3,16,5},{'line',12,14,12,17}},
 ['mail']={{'rectangle','line',3,5,18,14},{'line',3,5,12,13,21,5}},
 ['search']={{'circle','line',10,10,6},{'line',15,15,21,21}},
 ['globe']={{'circle','line',12,12,9},{'line',3,12,21,12},{'line',12,3,8,8,8,16,12,21,16,16,16,8,12,3}},
 ['settings']={{'circle','line',12,12,4},{'line',9,3,15,3,15,6,18,8,21,8,21,15,18,15,16,18,16,21,9,21,9,18,6,16,3,16,3,9,6,9,9,6,9,3}},
 ['puzzle']={{'line',4,4,10,4,10,2,14,2,14,4,20,4,20,10,22,10,22,14,20,14,20,20,14,20,14,17,10,17,10,20,4,20,4,14,7,14,7,10,4,10,4,4}},
 ['heart']={{'line',12,21,3,12,3,6,7,3,12,7,17,3,21,6,21,12,12,21}},
 ['package']={{'line',3,7,12,3,21,7,21,18,12,22,3,18,3,7,12,11,21,7},{'line',12,11,12,22},{'line',7,5,16,9}},
 ['backpack']={{'rectangle','line',5,6,14,16},{'rectangle','line',8,13,8,6},{'line',9,6,9,3,15,3,15,6}},
 ['list-filter']={{'line',3,5,21,5},{'line',6,11,18,11},{'line',10,17,14,17}},
 ['eye']={{'line',2,12,7,6,17,6,22,12,17,18,7,18,2,12},{'circle','line',12,12,3}},
 ['award']={{'circle','line',12,9,6},{'line',7,14,6,22,12,19,18,22,17,14}},
 ['book-open']={{'line',12,21,3,18,3,3,12,6,21,3,21,18,12,21,12,6}},
 ['shield-check']={{'line',12,2,21,6,19,17,12,22,5,17,3,6,12,2},{'line',8,12,11,15,16,9}},
 ['map-pin']={{'line',12,22,5,12,5,6,9,2,15,2,19,6,19,12,12,22},{'circle','line',12,8,3}},
 ['grid-2x2']={{'rectangle','line',3,3,7,7},{'rectangle','line',14,3,7,7},{'rectangle','line',3,14,7,7},{'rectangle','line',14,14,7,7}},
 ['sliders-horizontal']={{'line',3,6,21,6},{'line',3,12,21,12},{'line',3,18,21,18},{'circle','fill',8,6,2},{'circle','fill',16,12,2},{'circle','fill',10,18,2}},
 ['expand']={{'line',3,9,3,3,9,3},{'line',15,3,21,3,21,9},{'line',21,15,21,21,15,21},{'line',9,21,3,21,3,15}},
 ['users']={{'circle','line',9,7,4},{'circle','line',18,8,3},{'line',2,21,2,16,5,13,13,13,16,16,16,21},{'line',17,13,22,16,22,21}},
 ['user-round']={{'circle','line',12,7,4},{'line',4,21,4,16,8,12,16,12,20,16,20,21}},
 ['wallet']={{'rectangle','line',3,5,18,15},{'rectangle','line',15,10,7,6},{'circle','fill',18,13,1}},
 ['flag']={{'line',5,22,5,3,13,3,13,5,21,5,20,14,12,14,12,12,5,12}},
 ['sparkles']={{'line',12,2,14,9,21,11,14,13,12,20,10,13,3,11,10,9,12,2},{'line',20,1,20,5},{'line',18,3,22,3}},
 ['shuffle']={{'line',3,5,7,5,17,19,21,19,18,16},{'line',21,19,18,22},{'line',3,19,7,19,17,5,21,5,18,2},{'line',21,5,18,8}},
 ['triangle-alert']={{'line',12,2,23,21,1,21,12,2},{'line',12,8,12,14},{'circle','fill',12,18,1}},
 ['circle-help']={{'circle','line',12,12,10},{'line',8,8,9,6,14,6,16,8,16,10,12,13,12,15},{'circle','fill',12,18,1}},
 ['music']={{'line',8,18,8,5,20,3,20,16},{'line',8,8,20,6},{'circle','fill',5,18,3},{'circle','fill',17,16,3}},
 ['play']={{'polygon','fill',6,3,21,12,6,21}},
 ['square']={{'rectangle','fill',4,4,16,16}},
 ['monitor']={{'rectangle','line',2,3,20,14},{'line',12,17,12,22},{'line',7,22,17,22}},
 ['gamepad-2']={{'line',5,6,19,6,23,18,20,21,15,15,9,15,4,21,1,18,5,6},{'line',5,10,11,10},{'line',8,7,8,13},{'circle','fill',16,10,1},{'circle','fill',19,12,1}},
 ['chart-no-axes-column']={{'rectangle','line',3,12,4,9},{'rectangle','line',10,3,4,18},{'rectangle','line',17,8,4,13}},
}
for name in pairs(shapes)do Icons.NAMES[#Icons.NAMES+1]=name end
table.sort(Icons.NAMES)
function Icons.has(name)return shapes[name]~=nil end
function Icons.draw(name,x,y,size,color,alpha)
 local commands=shapes[name]
 if not commands then return false end
 local g=love.graphics
 g.push('all');g.translate(x,y);g.scale(size/24,size/24)
 g.setLineWidth(1.6);g.setColor(color[1]/255,color[2]/255,color[3]/255,alpha or 1)
 for _,command in ipairs(commands)do g[command[1]](unpack(command,2)) end
 g.pop();return true
end
return Icons
