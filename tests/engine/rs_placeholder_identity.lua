-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.core.Gen3RsTextPlaceholders')
local X=require('src.import.RomExtractorGen3');local Box=require('src.render.TextBox')
local Fs,W=require('src.import.CacheFs'),require('src.import.LuaWriter')
local Assets=require('src.import.Gen3RsPlaceholderAssets');local V=require('src.core.GameVersion')
local old,oldLoad,read,write=V.get(),love.filesystem.load,Fs.read,Fs.write
love.filesystem.load=loadfile
local loader=require('compat.gen1-rs.Loader').new('ruby')
local native=loader('src.import.gba.text_placeholders_extract')
local roles={'EVIL_TEAM','GOOD_TEAM','EVIL_LEADER','GOOD_LEADER','EVIL_LEGENDARY','GOOD_LEGENDARY'}
local translated=require('src.translation.rompack.gba_text')
local Content=require('src.mods.TextContent')
for _,edition in ipairs{'ruby','sapphire'}do
  V.set(edition)
  local symbols=native.rsSymbols(edition)
  T.eq(symbols.EVIL_TEAM,edition=='ruby'and'gExpandedPlaceholder_Magma'or'gExpandedPlaceholder_Aqua','native selected opposing team')
  T.eq(symbols.EVIL_LEADER,edition=='ruby'and'gExpandedPlaceholder_Maxie'or'gExpandedPlaceholder_Archie','native selected opposing leader')
  T.eq(symbols.EVIL_LEGENDARY,edition=='ruby'and'gExpandedPlaceholder_Groudon'or'gExpandedPlaceholder_Kyogre','native selected opposing legendary')
  local load=require('compat.gen1-rs.Loader').new(edition);local S=load('src.import.gba.syms').of(edition)
  local memory,expected,bySymbol={}, {},{}
  local n=0
  for key,symbol in pairs(symbols)do
    if not bySymbol[symbol]then
      n=n+1;local off=assert(S.off(symbol));local text=assert(S.size(symbol))<=1 and''or string.char(65+n)
      bySymbol[symbol]=text
      for i=1,#text do local b=text:byte(i);memory[off+i-1]=b>=65 and b-65+0xbb or b-48+0xa1 end
      memory[off+#text]=255
    end
    expected[key]=bySymbol[symbol]
  end
  local bodies={};Fs.write=function(path,body)bodies[path]=body;return true end;Fs.read=function(path)return bodies[path]end
  local x={version=edition,_constants={},rom={u8=function(_,off)return assert(memory[off],'Unexpected fixture byte '..off)end},beginStage=function()end}
  Assets.extract(x);local spec=x._constants.gen3RsPlaceholders
  T.eq(M.valid(spec,edition),true,'real native extractor yields edition metadata')
  for key,value in pairs(expected)do T.eq(spec.values[key],value,'ROM bytes retained: '..key)end
  bodies['data/generated/constants.lua']=W.encode(x._constants)
  T.eq(#Assets.missing(edition),0,'native placeholder file and host constants agree')
  T.check(#Assets.missing(edition=='ruby'and'sapphire'or'ruby')>0,'opposite-edition cache rejected')
  local game={data={constants=x._constants},save={version=edition,player={name='PLAYER',gender='boy',rival='STALE'}}}
  local raw={};for code=8,13 do raw[#raw+1]=string.char(253,code)end;raw[#raw+1]=string.char(255)
  local decoded=assert(X.new(table.concat(raw),edition,{charmap={}}):readText(0))
  local tokens={};for _,key in ipairs(roles)do tokens[#tokens+1]='{'..key..'}'end
  T.eq(decoded,table.concat(tokens),'actual host decoder preserves six role identities')
  local nodes={};for code=8,13 do nodes[#nodes+1]={t='ph',code=code}end
  T.eq(translated.plain(nodes,edition),decoded,'translated IR preserves the same role identities')
  T.eq(Content.source(decoded,3,edition,true),decoded,'native mod reader retains the RS role dialect')
  T.eq(Content.write(decoded,3,edition),decoded,'authored RS mod text retains native roles')
  local values={};for _,key in ipairs(roles)do values[#values+1]=spec.values[key]end
  T.eq(Box.substitute(game,decoded),table.concat(values),'actual TextBox expands native role words')
  T.eq(Box.substitute(game,'{VERSION}'),expected.VERSION,'dialogue version comes from own cartridge')
  T.eq(Box.substitute(game,'{RIVAL}{KUN}'),expected.RIVAL_MALE..expected.KUN_MALE,'male player uses original opposite rival')
  game.save.player.gender='girl'
  T.eq(Box.substitute(game,'{RIVAL}{KUN}'),expected.RIVAL_FEMALE..expected.KUN_FEMALE,'female player uses original opposite rival')
  T.eq(Box.substitute(game,'{AQUA}/{MAGMA}'),'AQUA/MAGMA','explicit literal team names never swap')
  for _,key in ipairs(roles)do local value=spec.values[key];spec.values[key]=nil
    T.eq(M.valid(spec,edition),false,'lost role invalidates host metadata: '..key);spec.values[key]=value
  end
  bodies['data/generated/gba/text/placeholders.lua']='return invalid lua'
  T.check(#Assets.missing(edition)>0,'corrupt native placeholder file rejected safely')
end
for _,edition in ipairs{'emerald','firered','leafgreen','red','gold'}do
  for code=8,13 do T.eq(M.token(code,edition),nil,'other edition keeps its existing placeholder dialect')end
  if edition=='emerald'or edition=='firered'or edition=='leafgreen'then
    for _,role in ipairs(roles)do
      local token='{'..role..'}'
      T.eq(pcall(Content.source,token,3,edition,true),false,'non-RS native reader rejects RS role: '..edition..'/'..role)
      T.eq(pcall(Content.write,token,3,edition),false,'non-RS authored text rejects RS role: '..edition..'/'..role)
    end
  end
end
Fs.read,Fs.write,love.filesystem.load=read,write,oldLoad;V.set(old)
T.finish('RS native team, leader, legendary, version and gendered dialogue identities')
