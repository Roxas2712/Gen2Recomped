local T = require("tests.harness")
love = require("tests.love_stub")
local SDK = require("tests.modkit.sdk")
local Json = require("src.link.Json")
local Serializer = require("src.core.SaveSerializer")
local Version = require("src.core.GameVersion")
local Save = require("src.core.SaveData")
local Game = require("src.core.Game")
local Stack = require("src.core.StateStack")
local World = require("src.world.OverworldController")
local Maps = require("src.world.MapLoader")
local Native = require("src.core.Checkpoint")
local Pokemon = require("src.pokemon.Pokemon")

local randomState = "checkpoint-rng-A"
love.math.getRandomState = function()
	return randomState
end
love.math.setRandomState = function(value)
	assert(value:match("^checkpoint%-rng%-"), "invalid RNG encoding")
	randomState = value
end
love.math.newRandomGenerator = function()
	return {
		setState = function(_, value)
			assert(value:match("^checkpoint%-rng%-"), "invalid RNG encoding")
		end,
	}
end
local function copy(value)
	return assert(Serializer.decode(Serializer.encode(value)))
end

for _, version in ipairs({ "red", "gold" }) do
	for _, level in ipairs({ 1, 2, 3 }) do
		Version.set(version)
		local id = "checkpoint_" .. level
		local fs = SDK.memfs({
			["mods/" .. id .. "/manifest.json"] = Json.encode({
				id = id,
				name = id,
				version = "1.0.0",
				api = level,
				entry = "main.lua",
			}),
			["mods/" .. id .. "/main.lua"] = [[return function(mod)
        mod.exports.checkpoints = mod.checkpoints
        mod.exports.events = {}
        mod.exports.nativeEvents = {}
        for _, name in ipairs({'map.entered', 'map.exited', 'map.reloaded', 'game.ready',
            'save.loading', 'save.loaded', 'screen.pushed', 'screen.popped',
            'world.live_maps_preparing', 'world.live_maps_updated'}) do
          mod.events:on(name, function() mod.exports.nativeEvents[#mod.exports.nativeEvents + 1] = name end)
        end
        mod.events:on('checkpoint.restored', function(ev)
          mod.exports.events[#mod.exports.events + 1] = ev
        end)
      end]],
		})
		local loaded = SDK.loadMods({ "mods/" .. id }, { fs = fs })
		T.eq(#loaded.errors, 0, version .. "/API-" .. level .. " loads checkpoint facade")
		local exports = loaded.loader.exports[id]
		local checkpoints = assert(exports.checkpoints)
		for _, method in ipairs({ "inspect", "capture", "restore", "resume", "ensureNormalSave" }) do
			T.eq(type(checkpoints[method]), "function", "public checkpoint method: " .. method)
		end
		Stack:init()
		Game.stack, Game.data, Game.renderer = Stack, loaded.data, require("src.render.Renderer")
		Game.input = {
			isDown = function()
				return false
			end,
			pressed = function()
				return false
			end,
		}
		Game.save = Save.newGame({ version = version, noHooks = true, pcItems = { FIX_POTION = 1 } })
		Save.validate(Game.save, Game.data)
		Game.save.party = { Pokemon.new(Game.data, "FIXMON_A", 5) }
		Game.save.meta.playthroughId = "native-checkpoint-test"
		Game.save.player.map, Game.save.player.x, Game.save.player.y = "FIX_TOWN", 2, 3
		Game.save.modData = { [id] = { quest = 4 }, another_mod = { quest = 9 } }
		Game.overworld, Game.world, Game.mods = World, World, loaded.loader
		loaded.loader.game, loaded.loader.modSave = Game, Game.save.modData
		if version == "gold" then
			Stack:setWorldOwner({ world = World })
			Stack.worldState, Stack.worldOwner.world = World, World
		else
			Stack.states = { World }
		end
		World:_checkpointRebuild({ map = "FIX_TOWN", x = 2, y = 3, facing = "down" })
		randomState = "checkpoint-rng-A"
		local options = Game.save.options
		World.customRecord = { ownedByMod = true }
		local custom = World.customRecord
		local capability = checkpoints:inspect(Game)
		T.check(capability.canCapture and capability.canRestore, "settled native control is admitted")
		local cp, code, message = checkpoints:capture(Game)
		assert(cp, message or code)
		T.eq(cp.format, 1, "public data format is one")
		T.eq(cp.save.options, nil, "checkpoint excludes global options")
		T.eq(cp.runtime.overworld.map, "FIX_TOWN", "checkpoint carries native map identity")
		T.eq(cp.rng.love, randomState, "capture preserves gameplay RNG")
		local captured = Serializer.encode(cp)
		Game.save.money = cp.save.money + 50
		Game.save.modData[id].quest = 40
		Game.save.modData.another_mod.quest = 90
		options.musicVolume = 0.17
		World.player.cellX, World.player.px = 4, 64
		randomState = "checkpoint-rng-B"
		local ok, why, detail = checkpoints:restore(Game, cp)
		T.check(ok, "native restore succeeds: " .. tostring(why) .. " " .. tostring(detail))
		T.eq(Game.save.money, cp.save.money, "native progress rewinds")
		T.eq(Game.save.modData.another_mod.quest, 9, "all saved mod progress rewinds")
		T.eq(loaded.loader.modSave, Game.save.modData, "mod-save service rebinds to restored progress")
		T.eq(Game.save.options, options, "current options object is preserved")
		T.eq(Game.save.options.musicVolume, 0.17, "current option value is preserved")
		T.eq(World.customRecord, custom, "unknown mod-owned controller field retains identity")
		T.eq(World.player.cellX, 2, "native player position rewinds")
		T.eq(randomState, "checkpoint-rng-A", "native RNG rewinds")
		T.eq(#exports.events, 1, "exactly one committed restore event")
		T.eq(exports.events[1].game, Game, "event carries reconstructed game")
		T.eq(exports.events[1].kind, "overworld", "event carries semantic kind")
		T.eq(exports.events[1].checkpoint, nil, "event exposes no checkpoint payload")
		T.eq(Serializer.encode(cp), captured, "caller checkpoint remains detached and unchanged")

		local beforeSave, beforePlayer, beforeMap = Game.save, World.player, World.map
		local function rejected(mutator, expected)
			local invalid = copy(cp)
			mutator(invalid)
			local accepted, reason = checkpoints:restore(Game, invalid)
			T.eq(accepted, false, "invalid checkpoint is refused")
			T.eq(reason, expected, "refusal identifies the validation failure")
			T.eq(Game.save, beforeSave, "validation leaves native save untouched")
			T.eq(World.player, beforePlayer, "validation leaves native player untouched")
			T.eq(World.map, beforeMap, "validation leaves native map untouched")
		end
		rejected(function(v)
			v.format = 99
		end, "unsupported_format")
		rejected(function(v)
			v.identity.playthroughId = "different"
		end, "wrong_playthrough")
		rejected(function(v)
			v.runtime.overworld.map = "ABSENT_MAP"
		end, "invalid_map")
		rejected(function(v)
			v.runtime.overworld.x = -1
		end, "invalid_position")
		rejected(function(v)
			v.save.inventory = { ABSENT_ITEM = 1 }
		end, "invalid_content")
		rejected(function(v)
			v.save.inventory = { FIX_POTION = false }
		end, "invalid_content")
		rejected(function(v)
			v.save.party[1].species = "ABSENT_SPECIES"
		end, "invalid_content")
		rejected(function(v)
			v.save.party = true
		end, "invalid_checkpoint")
		rejected(function(v)
			v.rng.love = "broken"
		end, "invalid_rng")
		rejected(function(v)
			v.save.options = {}
		end, "invalid_checkpoint")
		T.eq(#exports.events, 1, "validation failure emits no restore event")

		local originalRebuild = World._checkpointRebuild
		World._checkpointRebuild = function(self, position)
			originalRebuild(self, position)
			randomState = "checkpoint-rng-injected-error"
			error("deliberate native build failure")
		end
		local restored, reason = checkpoints:restore(Game, cp)
		World._checkpointRebuild = originalRebuild
		T.eq(restored, false, "failed reconstruction is refused")
		T.eq(reason, "restore_failed", "successful rollback is distinguished from rollback failure")
		T.eq(Game.save, beforeSave, "rollback retains original native save object")
		T.eq(World.player, beforePlayer, "rollback retains original native player object")
		T.eq(World.map, beforeMap, "rollback retains original native map and resource owner")
		T.eq(Maps.load(Game.data, "FIX_TOWN"), beforeMap, "rollback restores the map cache")
		T.eq(randomState, "checkpoint-rng-A", "failed reconstruction restores RNG")
		T.eq(#exports.events, 1, "rollback emits no committed event")

		World.player.moving = true
		T.eq(checkpoints:inspect(Game).reason, "movement_busy", "movement cannot be checkpointed")
		World.player.moving = false
		local battle = { isBattleState = true }
		Stack.states = { battle }
		T.eq(checkpoints:inspect(Game).reason, "unsupported_battle", "unqualified battle is refused")
		local title = { screenId = "TitleState" }
		Stack.states = { title }
		Game.save.money = cp.save.money + 7
		local titleSave = Game.save
		World._checkpointRebuild = function()
			error("deliberate resume failure")
		end
		local resumed, resumeReason = checkpoints:resume(Game, cp)
		World._checkpointRebuild = originalRebuild
		T.eq(resumed, false, "title reconstruction failure is refused")
		T.eq(resumeReason, "resume_failed", "title reconstruction reports its own failure")
		T.eq(Stack:top(), title, "failed resume retains the usable original title")
		T.eq(Game.save, titleSave, "failed resume retains original title session")
		T.check(checkpoints:resume(Game, cp), "existing title-selected identity resumes")
		T.eq(Native.inspect(Game).kind, "overworld", "resume restores native overworld ownership")
		T.eq(#exports.events, 2, "successful resume emits one additional committed event")
		T.eq(Game.save.options, options, "resume preserves current options")
		T.eq(checkpoints:resume(Game, cp), false, "resume outside title is refused")
		local target = copy(cp)
		target.runtime.overworld.map, target.save.player.map = "FIX_ROUTE", "FIX_ROUTE"
		T.check(checkpoints:restore(Game, target), "checkpoint reconstructs another installed map")
		T.eq(World.map.id, "FIX_ROUTE", "native map changes to the checkpoint target")
		T.check(checkpoints:restore(Game, cp), "native checkpoint returns across maps")
		local legacy = copy(cp)
		legacy.rng = nil
		randomState = "checkpoint-rng-legacy-current"
		T.check(checkpoints:restore(Game, legacy), "legacy overworld checkpoint without RNG remains readable")
		T.eq(randomState, "checkpoint-rng-legacy-current", "legacy payload leaves current RNG intact")
		T.eq(#exports.nativeEvents, 0, "reconstruction suppresses ordinary map/load/screen events")
		cp = assert(checkpoints:capture(Game))
		Game.save.money = Game.save.money + 1
		local anchored, anchorReason = checkpoints:ensureNormalSave(Game, cp)
		T.eq(anchored, false, "anchoring rejects stale runtime")
		T.eq(anchorReason, "runtime_changed", "anchoring reports stale runtime before writing")
		Game.save.money = cp.save.money
		local normalPath = "save" .. Version.saveSuffix(version) .. ".lua"
		fs.write(normalPath, Serializer.encode(cp.save))
		local previousBytes = fs.read(normalPath)
		anchored, anchorReason = checkpoints:ensureNormalSave(Game, cp)
		T.check(anchored, "existing selected normal save is accepted")
		T.eq(anchorReason, "already_exists", "existing progress is never replaced by anchoring")
		T.eq(fs.read(normalPath), previousBytes, "existing progress bytes remain unchanged")
		local hadNormal = Save.saveFileExists(version)
		local nativeAnchored, nativeReason = Native.ensureNormalSave(Game, cp)
		T.check(nativeAnchored, "live anchoring uses the real normal save lifecycle: " .. tostring(nativeReason))
		T.eq(
			nativeReason,
			hadNormal and "already_exists" or "saved",
			"native anchoring distinguishes new and existing progress"
		)
		T.check(Save.saveFileExists(version), "native anchoring leaves ordinary progress")
		local current = assert(checkpoints:capture(Game))
		nativeAnchored, nativeReason = Native.ensureNormalSave(Game, current)
		T.check(nativeAnchored, "repeated native anchoring is idempotent")
		T.eq(nativeReason, "already_exists", "repeated native anchoring skips writes")
		loaded.release()
	end
end
T.finish()
