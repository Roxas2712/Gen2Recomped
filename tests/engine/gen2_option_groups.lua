-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local before=Version.get()
local Menu=require('src.ui.OptionsMenu');local Stack=require('src.core.StateStack')
local Groups=require('src.ui.Gen2OptionGroups');local Save=require('src.core.SaveData')
local function session()
 local g={data=T.fixtures.fresh(),save=Save.newGame(),writes=0,input={pressed={}}}
 g.input.wasPressed=function(self,key)return self.pressed[key]==true end
 g.stack=setmetatable({}, {__index=Stack});g.stack:init()
 g.writeOptions=function(self)self.writes=self.writes+1;self.persisted=Save.encode(self.save)end
 return g
end
local function press(g,key)
 g.input.pressed={[key]=true};g.stack:top():update(1/60);g.input.pressed={}
end
for _,edition in ipairs({'gold','silver','crystal'}) do
 Version.set(edition);local g=session();local done,cancel=0,0
 local m=Menu.new(g,{onDone=function(o)T.eq(o,g.save.options,'completion receives actual native options');done=done+1 end,onCancel=function()cancel=cancel+1 end})
 g.stack:push(m)
 T.eq(m.options,g.save.options,edition..' observes actual native table')
 local ids={};for _,r in ipairs(m.rows)do ids[r.id]=r end
 T.eq(m:visible()[1].id,'group.speed',edition..' reference group order begins SPEED')
 local flat={};for i,row in ipairs(m.rows)do flat[i]=row end
 for _,group in ipairs(Groups.groups)do
  local child=m:focusRow(group.members[1])
  -- Some reference ids differ from the shared native names. Find a present member.
  if not child then for _,id in ipairs(group.members)do if ids[id]then child=m:focusRow(id);break end end end
  if child then
   T.eq(g.stack:top(),child,edition..' focus opens actual group page')
   T.eq(child.options,g.save.options,edition..' group edits native option table')
   T.eq(child:row(),ids[child:row().id],edition..' keeps exact native row handler identity')
   press(g,'b');T.eq(g.stack:top(),m,edition..' BACK restores parent')
  end
 end
 local page=m:focusRow('textSpeed');local previous=g.save.options.textSpeed
 press(g,'right');T.neq(g.save.options.textSpeed,previous,edition..' native value handler runs')
 T.eq(g.writes,1,edition..' change persists through native writer exactly once')
 T.eq(assert(Save.decode(g.persisted)).options.textSpeed,g.save.options.textSpeed,edition..' normal save codec retains selected value')
 press(g,'left');T.eq(g.save.options.textSpeed,previous,edition..' left reverses the native text-speed ladder')
 T.eq(g.writes,2,edition..' reversal also reaches normal persistence')
 press(g,'b');T.eq(done,0,edition..' group does not finish root')
 T.same(m.rows,flat,edition..' flat hook rows retained unchanged')
 local count=#g.stack.states;T.eq(m:focusRow('absent'),nil,edition..' absent focus fails honestly')
 T.eq(#g.stack.states,count,edition..' absent focus cannot open another page')
 press(g,'b');T.eq(done,1,edition..' root completion once');T.eq(cancel,1,edition..' caller cancellation once')
 m:leave_();T.eq(done,1,edition..' retired root cannot repeat completion')
end
Version.set('red');local g=session();local m=Menu.new(g);T.eq(m.view,nil,'Gen1 retains its flat menu path')
Version.set('emerald');g=session();m=Menu.new(g);T.eq(m.view,nil,'Gen3 retains its independent option presentation')
local custom={id='own',label='OWN',step=function()end};local native={id='textSpeed',label='TEXT'}
local grouped=Groups.build({native,custom},function()end)
T.eq(grouped[2],custom,'unknown authored rows remain accessible at root')
T.eq(grouped[#grouped].cancel,true,'BACK remains reachable')
Version.set(before);T.finish('native Gen2 grouped options, handler identity and persistence')
