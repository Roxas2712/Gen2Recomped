local path=arg[1]or'src/render/ShaderVariantKeyCache.lua';local K=assert(loadfile(path))();local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local order,kinds,values={},{},{}
for i=1,8 do local n='flag'..i;order[i]=n;kinds[n]=i%2==0 and'bool'or'float'end
local plan={order=order,kinds=kinds};local s=assert(K.new(plan,values,16));local seen={}
local function reference()
 local pieces,constants={},{}
 for _,n in ipairs(order)do if values[n]then pieces[#pieces+1]=n..'='..values[n];constants[n]=values[n]end end
 return table.concat(pieces,';'),constants
end
for state=0,3^8-1 do
 local digits=state
 for i,n in ipairs(order)do
  local digit=digits%3;digits=math.floor(digits/3)
  local literals=kinds[n]=='bool'and{[1]='false',[2]='true'}or{[1]='0.0',[2]='1.0'}
  local old=values[n];values[n]=literals[digit];K.update(s,n,old,values[n])
 end
 check(not seen[s.signature],'distinct source key has distinct signature');seen[s.signature]=true
 local key,constants=reference();local row=K.get(s)
 if row then check(row.key==key,'cached source key exactly matches old builder')else K.put(s,key,constants)end
 check(s.count<=16,'bounded key cache')
end
-- Revisit all cached states using the independent key's literal assignments.
for _,row in pairs(s.rows)do
 for _,n in ipairs(order)do local old=values[n];values[n]=row.constants[n];K.update(s,n,old,values[n])end
 check(K.get(s)==row and K.get(s).key==reference(),'revisit reuses immutable key and constants')
end
local signature=s.signature;K.update(s,'notInPlan',nil,'1.0');check(s.signature==signature,'irrelevant scalar has no key weight')
local wide={order={},kinds={}}
for i=1,33 do local n='a'..i;wide.order[i]=n;wide.kinds[n]='float'end
local ws=assert(K.new(wide,{},16));for _,n in ipairs(wide.order)do K.update(ws,n,nil,'1.0')end
check(ws.signature==3^33-1 and ws.signature<2^53,'largest supported signature is exact')
wide.order[34]='extra';wide.kinds.extra='float';check(K.new(wide,{})==nil,'wide plan uses legacy builder')
K.update(s,order[1],values[order[1]],'unsupported');check(s.disabled and K.get(s)==nil and s.count==0,'unknown literal disables memoization')
print('SHADER_VARIANT_KEYS_OK',checks)
