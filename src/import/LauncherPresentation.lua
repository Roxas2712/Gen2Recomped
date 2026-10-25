-- Public operator placements have a short, memory-only lease. An old feed or
-- an offline device must not keep showing a campaign after it was withdrawn.
local P={URL='https://pokexpert.de/api/launcher/presentation.json'}
local function now() return love.timer.getTime() end
local function https(url)
  if type(url)~='string' or #url>1000 or url:find('[%c%s]') then return false end
  local host=url:match('^https://([^/;?#]+)')
  return host and not host:find('@',1,true) and not host:find('\\',1,true)
end
local function text(value,limit)
  return type(value)=='string' and #value<=limit and not value:find('[%z\1-\8\11\12\14-\31\127]')
end
function P.parse(doc)
  if type(doc)~='table' or doc.schema_version~=1 or type(doc.week_enabled)~='boolean'
    or type(doc.promotions_enabled)~='boolean' or type(doc.items)~='table' or #doc.items>4 then return nil end
  local state={week_enabled=doc.week_enabled,items={}}
  if state.week_enabled and type(doc.week)=='table' and text(doc.week.catalogue_id,160) then
    state.week={catalogue_id=doc.week.catalogue_id}
  end
  if doc.promotions_enabled then for i,item in ipairs(doc.items) do
    if type(item)~='table' or (item.kind~='announcement' and item.kind~='promotion')
      or not text(item.title,320) or not text(item.description,960) or not https(item.url) then return nil end
    local image=type(item.image)=='string' and #item.image<=1000 and item.image:match('^https://pokexpert%.de/[^%c%s]+$') and item.image or nil
    state.items[#state.items+1]={kind=item.kind,title=item.title,description=item.description,url=item.url,
      thumbnail=image,catalogueId='operator-placement-'..i,_communityResolved=true}
  end end
  return state
end
function P.current(self)
  local t,wall=now(),os.time()
  if self._presentation and self._presentationAt and self._presentationWall
    and t>=self._presentationAt and t-self._presentationAt<120
    and wall>=self._presentationWall and wall-self._presentationWall<120 then return self._presentation end
end
function P.week(self)
  local state=P.current(self)
  return state and state.week_enabled and state.week or nil
end
function P.items(self)
  local state=P.current(self)
  return state and state.items or {}
end
function P.update(self)
  local enabled=not self._settings or self:_settings().modCompassEnabled~=false
  if not enabled or self.section~='mods' then
    if self._presentationJob then self._presentationJob:cancel();self._presentationJob=nil end
    if not enabled then self._presentation=nil;self._presentationAt=nil;self._presentationWall=nil;self._presentationNext=nil end
    return
  end
  -- Some mobile performance clocks pause during device sleep. Wall time also
  -- expires the lease, so reopening the app cannot revive an old promotion.
  if self._presentation and not P.current(self) then self._presentation=nil;self._presentationNext=0 end
  if self._presentationJob then
    local result=self._presentationJob:poll()
    if result then
      self._presentationJob=nil
      local state=result.kind=='done' and P.parse(result.first)
      if state then self._presentation=state;self._presentationAt=now();self._presentationWall=os.time() end
    end
  end
  if not self._presentationJob and now()>=(self._presentationNext or 0) then
    self._presentationNext=now()+60
    self._presentationJob=require('src.cloud.Task').new(function()
      local status,body=require('src.cloud.Http').request('GET',P.URL,{headers={Accept='application/json',['User-Agent']='RetroRecomped/1.0'}})
      if status~=200 or type(body)~='string' or #body>16384 then return nil end
      local ok,doc=pcall(require('src.link.Json').decode,body)
      return ok and doc or nil
    end)
  end
end
return P
