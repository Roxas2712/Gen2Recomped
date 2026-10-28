-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.core.Gen3RsOptionValues')
local Serialize=require('src.core.SaveSerializer')
local fields={textSpeed='textSpeed',battleScene='battleAnim',battleStyle='battleStyle',sound='stereo',
  buttonMode='gen3ButtonMode',frameType='gen3Frame'}
local choices={textSpeed={5,3,1},battleScene={true,false},battleStyle={'shift','set'},sound={false,true},
  buttonMode={1,2,3},frameType={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}}
for _,key in ipairs(M.keys)do
  for i,value in ipairs(choices[key])do
    local options={custom='keep',unrelated=true};M.set(options,key,i-1)
    T.eq(options[fields[key]],value,'native option writes original host field: '..key)
    T.eq(M.read(options)[key],i-1,'native option round trip: '..key)
    T.eq(options.custom,'keep','unrelated mod options remain')
    local raw=Serialize.encode(options);M.read(options)
    T.eq(Serialize.encode(options),raw,'reading options never mutates them')
  end
  for _,value in ipairs{-1,#choices[key],1.5}do
    T.eq(pcall(M.set,{},key,value),false,'invalid native enum is rejected: '..key)
  end
end
T.same(M.read(),{textSpeed=1,battleScene=0,battleStyle=0,sound=0,buttonMode=0,frameType=0},'missing values have native host defaults')
T.eq(M.read({textSpeed='fast',gen3Frame=21,gen3ButtonMode=99}).textSpeed,1,'unknown legacy value does not corrupt native enum')
T.finish('RS native options preserve host field meanings, false values, frames and unrelated settings')
