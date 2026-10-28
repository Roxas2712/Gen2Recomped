-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native zero-based option values over the host's existing persisted fields.
local M={}
M.keys={'textSpeed','battleScene','battleStyle','sound','buttonMode','frameType'}
local fields={textSpeed='textSpeed',battleScene='battleAnim',battleStyle='battleStyle',sound='stereo',
  buttonMode='gen3ButtonMode',frameType='gen3Frame'}
local values={textSpeed={5,3,1},battleScene={true,false},battleStyle={'shift','set'},sound={false,true}}
local defaults={textSpeed=1,battleScene=0,battleStyle=0,sound=0,buttonMode=0,frameType=0}
function M.read(options)
  local out={};options=options or{}
  for _,key in ipairs(M.keys)do
    local value=options[fields[key]];local n=defaults[key]
    if values[key]then
      for i,v in ipairs(values[key])do if v==value then n=i-1;break end end
    elseif type(value)=='number'and value%1==0 and value>=1 and value<=(key=='frameType'and 20 or 3)then n=value-1 end
    out[key]=n
  end
  return out
end
function M.set(options,key,value)
  assert(fields[key]and type(value)=='number'and value%1==0 and value>=0)
  local choices=values[key];local count=choices and#choices or(key=='frameType'and 20 or 3)
  assert(value<count,'Invalid native RS option value')
  if choices then options[fields[key]]=choices[value+1]else options[fields[key]]=value+1 end
end
return M
