-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local Registry=require('src.mods.Registry')
local Merge=require('src.mods.Merge')
local base={row={list={1},kept='native'}}
local registry=Registry.new('probe')
registry.base=function()return base end
registry:patch('row',{list={__append={2}}},'earlier')
local input={list={__append={3}}}
local calls=0
local function transform(current,patch)
  calls=calls+1
  return Merge.deepMerge(current or {},patch)
end
local result=registry:patchTransformed('row',input,'later',transform)
T.same(result.list,{1,2,3},'admission returns the converted effective row')
T.same(base.row.list,{1},'admission never mutates native base')
input.list.__append[1]=99
T.same(registry:get('row').list,{1,2,3},'authored patch is detached at admission')
local before=calls
registry:get('row');registry:get('row')
T.eq(calls,before,'unchanged reads use the memoized fold')
-- Native merge writes the folded row back into Data. Subsequent preference
-- changes still start from the first-touch native base, including after freeze.
base.row=registry:get('row');registry:freeze()
registry:preferOwner('row','later')
T.same(registry:get('row').list,{1,3},'preferred transform excludes earlier native operation after merge')
registry:preferOwner('row','earlier')
T.same(registry:get('row').list,{1,2},'preferred native owner excludes transform')
registry:preferOwner('row',nil)
T.same(registry:get('row').list,{1,2,3},'clearing preference restores original operation sequence')
registry:rollback('earlier')
T.same(registry:get('row').list,{1,3},'rollback recomputes authored extension')
registry:rollback('later')
T.same(registry:get('row').list,{1},'removing every owner returns the pristine base')
T.eq(registry:get('row').kept,'native','unrelated base field remains intact')
T.raises(function()registry:patchTransformed('row',{},'blocked',transform)end,'frozen','frozen registry rejects conversion')
local rejected=Registry.new('rejected')
rejected.base=function()return base end
T.raises(function()rejected:patchTransformed('row',{},'bad',function(current,patch)
  current.list[1]=17;patch.changed=true;error('conversion refused')
end)end,'conversion refused','rejected transform remains diagnostic')
T.eq(next(rejected.ops),nil,'rejected transform adds no operation')
T.eq(next(rejected.owners),nil,'rejected transform claims no ownership')
T.same(base.row.list,{1,2,3},'failed conversion cannot mutate its input base')
local compose=Registry.new('scripts',{semantics='compose'})
T.raises(function()compose:patchTransformed('row',{},'bad',transform)end,'record-only','compose contract stays explicit')
local ids=Registry.new('numeric');ids.numericIds=true
ids:patchTransformed(7,{v=8},'owner',transform)
T.eq(ids:get(7).v,8,'native numeric registry contract remains supported')
ids:rollback('owner');T.eq(ids:get(7),nil,'new numeric id disappears after rollback')
local native=Registry.new('native');local data={row={v=1}}
native.base=function()return data end
native:patch('row',{v=2},'pack');data.row=native:get('row')
native:remove('row','delete');data.row=nil
native:rollback('delete');T.eq(native:get('row').v,2,'rollback can expose a merged row removed from Data')
native:rollback('pack');local nextRow=native:each()
local id,row=nextRow()
T.eq(id,'row','iterator retains native first-touch row after all owners retire')
T.eq(row.v,1,'iterator exposes restored pristine native row')
T.finish('transformed registry arbitration and native fold bases')
