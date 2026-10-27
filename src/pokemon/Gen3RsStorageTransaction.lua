-- Native storage edits a private working copy. A picked-up Pokemon must never
-- disappear from an autosave while it is still attached to the cursor.
local M={};M.__index=M
local function copy(t,seen)
  if type(t)~='table'then return t end
  seen=seen or {};if seen[t]then return seen[t]end
  local out={};seen[t]=out;for k,v in pairs(t)do out[copy(k,seen)]=copy(v,seen)end;return out
end
local function apply(to,from)
  for k in pairs(to)do if from[k]==nil then to[k]=nil end end
  for k,v in pairs(from)do
    if type(v)=='table'and type(to[k])=='table'then apply(to[k],v)else to[k]=copy(v)end
  end
end
local function snapshot(save)
  return require('src.core.SaveSerializer').encode({party=save.party,boxes=save.boxes,box=save.box,
    currentBox=save.currentBox,boxNames=save.boxNames})
end
function M.new(game)
  local save,data=game.save,game.data
  local self=setmetatable({game=game,baseline=snapshot(save),originals={},released={},rows={}},M)
  self.session={party={},storage={currentBox=math.max(1,math.min(14,save.currentBox or 1)),boxes={},items={}}}
  local function view(raw)
    assert(type(raw)=='table'and not self.originals[raw],'Duplicate Pokemon in PC input')
    local work=copy(raw)
    local proxy=setmetatable({_host=work},{__index=function(_,key)
      if key=='maxHp'then return work.maxHp or work.maxHP or work.stats and work.stats.hp end
      if key=='isEgg'then return work.isEgg==true or work.egg==true end
      if key=='status'then return work.status or work.statusWord end
      if key=='markings'then return work.markings or work.gen3Markings end
      if key=='heldItem'or key=='item'then
        local id=work.heldItem or work.item;return type(id)=='number'and id or id and data.items[id]and data.items[id].index or 0
      end
      return work[key]
    end,__newindex=function(_,key,value)
      assert(key~='heldItem'and key~='item','RS storage does not edit held items')
      work[key]=value
      -- Cartridge imports and link records retain these known host aliases.
      if key=='status'and value==nil and work.statusWord~=nil then work.statusWord=0 end
      if key=='markings'then work.gen3Markings=value end
    end})
    local row={original=raw,work=work,view=proxy};self.originals[raw]=row;self.rows[proxy]=row
    return proxy
  end
  for i=1,6 do if(save.party or {})[i]then self.session.party[#self.session.party+1]=view(save.party[i])end end
  local boxes=save.boxes or save.box and save.box.boxes or {}
  if not save.boxes and save.box and not save.box.boxes then boxes={[1]=save.box.mons or save.box}end
  for b=1,14 do
    local raw=boxes[b]or {};local slots=raw.mons or raw;local mons={}
    for i=1,30 do if slots[i]then mons[i]=view(slots[i])end end
    self.session.storage.boxes[b]={mons=mons,name=(save.boxNames or {})[b]or raw.name or ('BOX '..b),
      wallpaper=raw.wallpaper and raw.wallpaper+1 or (b-1)%4+1}
  end
  self.initialNames={};self.initialWallpapers={}
  for i=1,14 do local b=self.session.storage.boxes[i];self.initialNames[i]=b.name;self.initialWallpapers[i]=b.wallpaper end
  return self
end
function M:confirmRelease(mon)assert(self.rows[mon]);self.released[mon]=true end
function M:commit()
  assert(not self.committed,'PC transaction already committed')
  assert(snapshot(self.game.save)==self.baseline,'PC save changed outside its working session')
  local s=self.session;assert(#s.party>=1 and #s.party<=6,'Invalid PC party size')
  local seen={};local function check(mon)
    if not mon then return end
    assert(self.rows[mon]and not seen[mon]and not self.released[mon],'Unknown or duplicated Pokemon in PC output');seen[mon]=true
  end
  for i=1,6 do check(s.party[i])end
  for b=1,14 do for i=1,30 do check(s.storage.boxes[b].mons[i])end end
  for mon in pairs(self.rows)do assert(seen[mon]or self.released[mon],'Pokemon missing from PC output')end
  -- Validate everything before touching the authoritative tables.
  local save=self.game.save
  for mon in pairs(seen)do local r=self.rows[mon];apply(r.original,r.work)end
  local party=save.party or {};for i=1,6 do party[i]=s.party[i]and self.rows[s.party[i]].original end;save.party=party
  local boxes=save.boxes or {};save.boxes=boxes
  for b=1,14 do
    local box=boxes[b]or {};local slots=box.mons or box;boxes[b]=box
    for i=1,30 do local mon=s.storage.boxes[b].mons[i];slots[i]=mon and self.rows[mon].original end
    local work=s.storage.boxes[b]
    if work.name~=self.initialNames[b]then save.boxNames=save.boxNames or {};save.boxNames[b]=work.name end
    if work.wallpaper~=self.initialWallpapers[b]then box.wallpaper=work.wallpaper-1 end
  end
  if s.storage.currentBox~=(save.currentBox or 1)then save.currentBox=s.storage.currentBox end
  -- Retain legacy fields: the authoritative current-format boxes now win.
  self.committed=true
end
return M
