-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Explicit argument positions survive native Japanese/Korean sentence order.
local T={}
function T.format(template,values)
 local out,index={},1;local sequential=0
 while index<=#template do
  local first=template:find('%',index,true)
  if not first then out[#out+1]=template:sub(index);break end
  out[#out+1]=template:sub(index,first-1)
  if template:sub(first+1,first+1)=='%'then out[#out+1]='%';index=first+2
  else
   local tail=template:sub(first);local position,flags,width,precision,kind,finish=tail:match('^%%(%d+)%$([-+ #0]*)(%d*)(%.?%d*)([cdiouxXeEfgGqs])()')
   if not position then
    flags,width,precision,kind,finish=tail:match('^%%([-+ #0]*)(%d*)(%.?%d*)([cdiouxXeEfgGqs])()')
    sequential=sequential+1;position=sequential
   end
   assert(kind,'Unsupported native format directive')
   position=tonumber(position);assert(position and position>=1 and position<=values.n,'Native format argument is missing')
   assert(tonumber(width or'')==nil or tonumber(width)<=1024,'Native format width outside bounds')
   assert(tonumber((precision or''):sub(2))==nil or tonumber(precision:sub(2))<=1024,'Native format precision outside bounds')
   out[#out+1]=string.format('%'..flags..width..precision..kind,values[position]);index=first+finish-1
  end
 end
 return table.concat(out)
end
-- Rebind both classes in one pass so an intervening number cannot shift a
-- later string argument. No values are inserted into a global text catalog.
function T.rebind(target,source,order)
 if type(target)~='string'or type(source)~='string'then return target end
 local bindings={};for token in source:gmatch('{([^{}]+)}')do
  if token:match('^RAM:')or token:match('^NUM:')or token=='STRBUF'or token=='NUM'then bindings[#bindings+1]='{'..token..'}'end
 end
 local position=0
 return(target:gsub('{([A-Z]+)}',function(token)
  if token~='STRBUF'and token~='NUM'then return'{'..token..'}'end
  position=position+1;return bindings[order and order[position]or position]or'{'..token..'}'
 end))
end
function T.install(mod,live)
 local S=require('src.core.Strings');local state=S.__ulaNativeArguments
 if not state then
  state={get=S.get};S.__ulaNativeArguments=state
  S.get=function(source,...)
   if state.live and state.live()and state.active and select('#',...)>0 then
    local text=S.lookup(source)
    if type(text)=='string'and text:find('%%%d+%$')then
     local values={n=select('#',...),...};local ok,result=pcall(T.format,text,values)
     if ok then return result end
    end
   end
   return state.get(source,...)
  end
 end
 state.live=live
 return{set=function(_,language)state.active=language=='ja'or language=='ko'end}
end
return T
