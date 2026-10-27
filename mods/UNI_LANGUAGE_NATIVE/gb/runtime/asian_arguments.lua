-- Native sentence order can differ from the US engine's argument order.
-- Keep the actual cartridge prose and reorder values by reviewed RAM roles.
return function(mod,orders,active)
 local Common=require('src.core.gen2.CommonText')
 local patch=Common.__ulaAsianArguments
 if not patch then
  patch={of=Common.of,fill=Common.fill,pages=setmetatable({},{__mode='k'})}
  Common.__ulaAsianArguments=patch
  Common.of=function(text,label,values)
   if not patch.active() then return patch.of(text,label,values)end
   local pages=patch.of(text,label)
   if not pages then return nil end
   patch.pages[pages]={order=patch.orders[label],body=Common.get(text,label)}
   return values and Common.fill(pages,values)or pages
  end
  Common.fill=function(pages,values)
   local entry=patch.active()and pages and patch.pages[pages]
   if not entry then return patch.fill(pages,values)end
   values=values or {};local position=0
   -- Fill the linear source before pagination. A scrolling line is repeated
   -- on the next page and must not consume the next argument a second time.
   local body=entry.body:gsub('{(%u+)}',function(name)
    if name=='PLAYER'or name=='RIVAL'then return values[name:lower()]or '{'..name..'}'end
    if name~='STRBUF'and name~='NUM'then return '{'..name..'}'end
    position=position+1
    local index=entry.order and entry.order[position]or position
    local value=values[index]
    return value~=nil and tostring(value)or ''
   end)
   return Common.pages(body)
  end
 end
 patch.active=active;patch.orders=orders
end
