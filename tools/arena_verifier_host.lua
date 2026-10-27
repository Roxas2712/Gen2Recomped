-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Private worker entry point. Only the operator mounts executable game data.
package.path = './?.lua;./?/init.lua;' .. package.path
love = require('tests.love_stub')
local ffi = require('ffi')
ffi.cdef('unsigned char *SHA256(const unsigned char *, size_t, unsigned char *);')
local crypto = ffi.load(assert(os.getenv('RETRO_VERIFIER_CRYPTO'), 'Missing SHA-256 library'))
love.data = {
  hash = function(algorithm, bytes)
    assert(algorithm == 'sha256', 'Unsupported digest')
    local out = ffi.new('unsigned char[32]')
    assert(crypto.SHA256(bytes, #bytes, out) ~= nil, 'SHA-256 failed')
    return ffi.string(out, 32)
  end,
  encode = function(container, encoding, bytes)
    assert(container == 'string' and encoding == 'hex', 'Unsupported encoding')
    return (bytes:gsub('.', function(c) return ('%02x'):format(c:byte()) end))
  end,
}
local Json = require('src.link.Json')
local function read(path)
  local f = assert(io.open(path, 'rb'));local bytes = f:read('*a');f:close();return bytes
end
local function restoreIndices(v)
  if type(v) ~= 'table' then return v end
  local out = {}
  for k, value in pairs(v) do
    local n = type(k) == 'string' and k:match('^%d+$') and tonumber(k)
    out[n or k] = restoreIndices(value)
  end
  return out
end
local function run()
  local bytes = read(assert(arg[1]));assert(#bytes <= 32 * 1024 * 1024, 'Replay is too large')
  local job = assert(Json.decode(bytes))
  local V = require('src.core.GameVersion');assert(V.info(job.edition), 'Unknown edition');V.set(job.edition)
  assert(V.generation(job.edition) <= 3 or job.edition=='platinum', 'Edition is not qualified for native verification')
  local Data = require('src.core.Data');Data:load()
  local loader = require('src.mods.Loader').new({noMods=true});loader:load(Data)
  require('src.battle.TypeChart').load(Data)
  local P = require('src.link.Protocol');local Proof = require('src.link.ArenaProof')
  for _, team in ipairs(job.teams) do
    assert(type(team.bank) == 'table' and #team.bank == #team.party and #team.party >= 1 and #team.party <= 6, 'Missing frozen Bank identities')
    for i, raw in ipairs(team.bank) do
      local entry = restoreIndices(raw)
      assert(entry.schema == 1 and entry.source.version == job.edition and not entry.mon.isEgg, 'Invalid Bank identity')
      local wire = P.packMon(entry.mon)
      local native = assert(P.unpackMon(Data, wire, {strict=true,forceLevel=job.level}))
      assert(Proof.same(P.packMon(native), team.party[i]), 'Frozen team differs from the native Bank reconstruction')
    end
  end
  local Input = require('src.core.Input');Input:init();require('src.render.Font').load(Data)
  local stack = {list={}}
  function stack:push(s) self.list[#self.list+1]=s;if s.enter then s:enter() end end
  function stack:pop() table.remove(self.list) end
  function stack:top() return self.list[#self.list] end
  function stack:update(dt) local s=self:top();if s and s.update then s:update(dt) end end
  local save = require('src.core.SaveData').newGame();save.player.name='HOST';save.party={}
  save.options.textSpeed='fast';save.options.masterVolume=0
  for _, wire in ipairs(job.teams[1].party) do save.party[#save.party+1]=assert(P.unpackMon(Data,wire,{strict=true,forceLevel=job.level})) end
  local game = {data=Data,input=Input,save=save,stack=stack}
  return require('src.link.ArenaReplay').run(game, job)
end
local ok, proof = pcall(run)
local result = ok and {ok=true,proof=proof} or {ok=false,reason=tostring(proof):sub(1,500)}
local output = assert(io.open(assert(arg[2]), 'wb'));output:write(Json.encode(result));output:close()
os.exit(ok and 0 or 2)
