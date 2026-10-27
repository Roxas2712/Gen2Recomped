-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Pure source planning for an optional compiler optimization. This module does
-- not change graphics state. Unknown syntax keeps its original runtime branch.
local B={}
local scalar={float=true,bool=true}
local qualifier={highp=true,mediump=true,lowp=true,LOVE_HIGHP_OR_MEDIUMP=true}
local function blank(text)return(text:gsub('[^\n]',' '))end
local function uncomment(source)
 local pieces,at={},1
 while at<=#source do
  local first=source:find('/',at,true)
  if not first then pieces[#pieces+1]=source:sub(at);break end
  pieces[#pieces+1]=source:sub(at,first-1)
  local pair=source:sub(first,first+1);local finish
  if pair=='//'then finish=source:find('\n',first+2,true)or(#source+1)
  elseif pair=='/*'then local last=source:find('*/',first+2,true);if not last then return end;finish=last+2 end
  if finish then pieces[#pieces+1]=blank(source:sub(first,finish-1));at=finish
  else pieces[#pieces+1]='/';at=first+1 end
 end
 return table.concat(pieces)
end
local function pattern(name)return'%f[%w_]'..name..'%f[^%w_]'end
local function withoutDirectives(clean)
 local continued=false;local out={}
 for line in(clean..'\n'):gmatch('(.-)\n')do
  local directive=continued or line:match('^%s*#')~=nil
  continued=directive and line:match('\\%s*$')~=nil
  out[#out+1]=directive and blank(line)or line
 end
 return table.concat(out,'\n')
end
function B.plan(source)
 if type(source)~='string'then return nil,'source is not text'end
 local clean=uncomment(source);if not clean then return nil,'unfinished comment'end
 local code=withoutDirectives(clean)
 local declarations,names={},{}
 local at=1
 while true do
  local first,last,body=code:find('%f[%w_]uniform%s+([^;{}]+);',at)
  if not first then break end
  local q,kind,name=body:match('^([%w_]+)%s+([%w_]+)%s+([%a_][%w_]*)%s*$')
  if not(q and qualifier[q])then kind,name=body:match('^([%w_]+)%s+([%a_][%w_]*)%s*$')end
  if scalar[kind]and name and not name:match('^love_')and not name:match('^pokeport')then
   if names[name]and names[name]~=kind then return nil,'conflicting uniform kinds'end
   names[name]=kind;declarations[#declarations+1]={first,last}
  end
  at=last+1
 end
 local conditions={};at=1
 while true do
  local first,last=code:find('%f[%w_]if%f[^%w_]%s*%(',at)
  if not first then break end
  local depth,finish=1,last+1
  while finish<=#clean and depth>0 do
   local c=clean:sub(finish,finish)
   if c=='('then depth=depth+1 elseif c==')'then depth=depth-1 end
   finish=finish+1
  end
  if depth~=0 then return nil,'unfinished branch condition'end
  conditions[#conditions+1]={last,finish-1};at=finish
 end
 -- Uniform arithmetic remains dynamic. Reject possible shadow declarations,
 -- member names and macros before substituting any read in an if condition.
 -- A comma may introduce another local declaration; conservatively reject
 -- that spelling even when it is merely a function argument.
 local outside=clean
 local ranges={};for _,r in ipairs(declarations)do ranges[#ranges+1]=r end
 table.sort(ranges,function(a,b)return a[1]>b[1]end)
 for _,r in ipairs(ranges)do outside=outside:sub(1,r[1]-1)..blank(outside:sub(r[1],r[2]))..outside:sub(r[2]+1)end
 local order={}
 for name in pairs(names)do
  local use=pattern(name)
  local shadow=outside:find('[%w_]+%s+'..name..'%f[^%w_]')
   or outside:find('[,%.]%s*'..name..'%f[^%w_]')
  local macro=false;local pos=1
  while true do
   local a,b=outside:find(use,pos);if not a then break end
   if code:sub(a,b)~=clean:sub(a,b)then macro=true;break end
   pos=b+1
  end
  if shadow or macro then names[name]=nil
  else
   local used=false;for _,r in ipairs(conditions)do if clean:sub(r[1],r[2]):find(use)then used=true;break end end
   if used then order[#order+1]=name else names[name]=nil end
  end
 end
 table.sort(order)
 return{source=source,clean=clean,kinds=names,order=order,conditions=conditions}
end
function B.literal(kind,value)
 if kind=='bool'and type(value)=='boolean'then return tostring(value)end
 if kind=='float'and type(value)=='number'then
  if value==1 then return'1.0'end
  if value==0 and 1/value==math.huge then return'0.0'end
 end
end
function B.key(plan,values)
 local constants,key={},{}
 for _,name in ipairs(plan.order)do
  local literal=B.literal(plan.kinds[name],values[name])
  if literal then constants[name]=literal;key[#key+1]=name..'='..literal end
 end
 return constants,table.concat(key,';'),#key
end
function B.rewrite(plan,constants)
 local source=plan.source
 for i=#plan.conditions,1,-1 do
  local range=plan.conditions[i];local first,last=range[1],range[2]
  local lexical=plan.clean:sub(first,last);local original=source:sub(first,last)
  local changes={}
  for _,name in ipairs(plan.order)do
   local value=constants[name]
   if value then
    assert(value=='0.0'or value=='1.0'or value=='true'or value=='false','unqualified literal')
    local at=1
    while true do
     local a,b=lexical:find(pattern(name),at);if not a then break end
     changes[#changes+1]={a,b,value};at=b+1
    end
   end
  end
  table.sort(changes,function(a,b)return a[1]>b[1]end)
  for _,c in ipairs(changes)do original=original:sub(1,c[1]-1)..c[3]..original:sub(c[2]+1)end
  source=source:sub(1,first-1)..original..source:sub(last+1)
 end
 return source
end
return B
