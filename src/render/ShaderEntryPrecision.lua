-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- LÖVE 12 declares effect() before user code. GLSL precision qualifiers on
-- that definition must match its prototype. Keep an explicitly qualified
-- producer body behind a forwarding entry using the host's original defaults.
local E={}
local helper='pokeportQualifiedPixelEffect'
local precision={lowp=true,mediump=true,highp=true}
local function blank(s)return(s:gsub('[^\n]',' '))end
local function uncomment(source)
 local out,at={},1
 while at<=#source do
  local a=source:find('/',at,true)
  if not a then out[#out+1]=source:sub(at);break end
  out[#out+1]=source:sub(at,a-1)
  local pair=source:sub(a,a+1);local finish
  if pair=='//'then finish=source:find('\n',a+2,true)or(#source+1)
  elseif pair=='/*'then local b=source:find('*/',a+2,true);if not b then return nil end;finish=b+2 end
  if finish then out[#out+1]=blank(source:sub(a,finish-1));at=finish
  else out[#out+1]='/';at=a+1 end
 end
 return table.concat(out)
end
local function parameter(text,kind)
 local q,name=text:match('^%s*([%a_][%w_]*)%s+'..kind..'%s+([%a_][%w_]*)%s*$')
 return precision[q]and name~=nil
end
function E.source(source)
 if type(source)~='string'then return source,false end
 local code=uncomment(source)
 if not code or code:find(helper,1,true)or code:find('void%s+pixelmain%s*%(')
  or code:find('#%s*define%s+effect%f[^%w_]')
  or code:find('#%s*define%s+Image%f[^%w_]')
  or code:find('precision%s+[%w_]+%s+sampler2D%f[^%w_]')then return source,false end
 -- Conditional alternative entries and macro-authored signatures require the
 -- producer's own compiler policy. Never guess which branch or precision wins.
 local count=0
 for _ in code:gmatch('%f[%w_]vec4%s+effect%s*%b()%s*{')do count=count+1 end
 if count~=1 then return source,false end
 local first,_,q,args=code:find('%f[%w_]([%a_][%w_]*)%s+vec4%s+effect%s*(%b())%s*{')
 if not first or not precision[q]then return source,false end
 local parameters={}
 for p in args:sub(2,-2):gmatch('[^,]+')do parameters[#parameters+1]=p end
 if #parameters~=4 or not parameter(parameters[1],'vec4')
  or not parameters[2]:match('^%s*Image%s+[%a_][%w_]*%s*$')
  or not parameter(parameters[3],'vec2')or not parameter(parameters[4],'vec2')then return source,false end
 local a,b=code:find('%f[%w_]effect%f[^%w_]',first)
 local renamed=source:sub(1,a-1)..helper..source:sub(b+1)
 -- This entry precedes any user precision directives, exactly like LÖVE's
 -- prototype. The helper's three numeric parameters retain explicit precision.
 local prefix=('#ifdef PIXEL\n%s vec4 %s%s;\n'):format(q,helper,args)..[[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
 return pokeportQualifiedPixelEffect(color, tex, uv, screen);
}
#endif
#line 1
]]
 return prefix..renamed,true
end
return E
