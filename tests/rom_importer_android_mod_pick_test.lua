-- Android mod / save Import must open the SAF picker (love.system.pickFile
-- with kind) and consume picked_mod.zip / picked_save.sav on focus, mirroring
-- the ROM flow.  Self-contained: `luajit tests/rom_importer_android_mod_pick_test.lua`.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("rom importer android mod/save pick")
local eq = S.eq
local check = S.check

local RomImporter = require("src.import.RomImporter")
local owned=require('tests.modkit.install_fs')()
local function pump(ri)
  for _=1,1000 do if not ri._localModInstall then return end;ri:_stepModInstall()end
  error('mobile installer did not terminate')
end

love.system = love.system or {}
local saved = {
  getOS = love.system.getOS,
  pickFile = love.system.pickFile,
}

local pickCalls = {}
love.system.getOS = function() return "Android" end
love.system.pickFile = function(kind)
  pickCalls[#pickCalls + 1] = kind or "rom"
  return true
end

local function freshImporter(ready)
  return setmetatable({
    android = true,
    workState = nil,
    tab = "mods",
    ready = {
      red = ready.red and true or false,
      blue = ready.blue and true or false,
    },
    saveNotice = {},
    modNotice = nil,
    androidPendingVersion = nil,
    _installMod = function(self, source)
      self._installed = source
      self.modNotice = { ok = true, text = "Installed test" }
    end,
    _importSave = function(self, version, source)
      self._imported = { version = version, source = source }
      self.saveNotice[version] = { ok = true, text = "Imported" }
    end,
    _savedropTarget = RomImporter._savedropTarget,
    _refreshMods = function() end,
    _refreshSlots = function() end,
  }, RomImporter)
end

-- Choose mod with nothing pending opens the mod picker.
pickCalls = {}
local ri = freshImporter({ red = true, blue = true })
ri:chooseMod()
pump(ri)
eq(#pickCalls, 1, "chooseMod opens the picker when no pending zip exists")
eq(pickCalls[1], "mod", "chooseMod asks pickFile for a mod")

-- Pending USB zip installs without opening the picker.
love.filesystem.write("usb_mod.zip", "PK\0fake")
owned.archives['PK\0fake']={['manifest.json']=require('src.link.Json').encode({id='androidprobe',name='Native Android probe',version='1.0.0',api=2,entry='main.lua'}),
  ['main.lua']='local mod=...;mod.exports.native=true'}
pickCalls = {}
ri = freshImporter({ red = true, blue = true })
ri:chooseMod()
check(love.filesystem.getInfo('usb_mod.zip')~=nil,'pending source survives until the installer closes it')
pump(ri)
eq(#pickCalls, 0, "chooseMod installs a pending zip without opening the picker")
eq(owned.files['mods/androidprobe/main.lua'],'local mod=...;mod.exports.native=true','chooseMod installs the pending native package')
check(love.filesystem.getInfo("usb_mod.zip") == nil,
  "successful install removes the pending zip")

-- Focus consumes picked_mod.zip even when both ROMs are already ready.
love.filesystem.write("picked_mod.zip", "PK\0saf")
ri = freshImporter({ red = true, blue = true })
ri:focus(true)
eq(ri._installed, "picked_mod.zip", "focus installs the SAF mod drop")
check(love.filesystem.getInfo("picked_mod.zip") == nil,
  "successful focus install removes picked_mod.zip")

-- Choose save opens the sav picker when nothing is pending.
pickCalls = {}
ri = freshImporter({ red = true, blue = true })
ri.tab = "blue"
ri:chooseSaveImport("blue")
eq(#pickCalls, 1, "chooseSaveImport opens the picker when no pending sav exists")
eq(pickCalls[1], "sav", "chooseSaveImport asks pickFile for a sav")
eq(ri.androidPendingVersion, "blue", "pending version is remembered for focus")

-- Focus consumes picked_save.sav into the remembered version.
love.filesystem.write("picked_save.sav", string.rep("S", 32))
ri = freshImporter({ red = true, blue = true })
ri.androidPendingVersion = "blue"
ri:focus(true)
check(ri._imported ~= nil, "focus imports the SAF save drop")
eq(ri._imported.version, "blue", "focus imports into the pending version")
eq(ri._imported.source, "picked_save.sav", "focus reads the SAF save filename")
check(love.filesystem.getInfo("picked_save.sav") == nil,
  "successful focus import removes picked_save.sav")

love.system.getOS = saved.getOS
love.system.pickFile = saved.pickFile
-- leftover cleanup if a failed assertion left files behind
love.filesystem.remove("usb_mod.zip")
love.filesystem.remove("picked_mod.zip")
love.filesystem.remove("picked_save.sav")
owned.restore()

S.finish()
