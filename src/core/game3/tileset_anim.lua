-- Animation observes the existing native clock. It never advances the game,
-- source scripts, RNG or a second terrain timer.
local A={_visible={}}
local function native()return require('src.core.game3.tileset_native')end
function A.install()A.invalidate()end
function A.invalidate()A._visible={};A._current=nil end
function A.enterMap(pair)A._current=pair;A._visible[pair]=true;return true end
function A.bindPair(pair,atlas)if not(pair and atlas)then return false end;A._visible[pair]=true;return true end
function A.unbindPair(pair)A._visible[pair]=nil end
function A.setVisiblePairs(pairs)A._visible=pairs or{}end
function A.step()native().update()end
A.stepRse=A.step
A.release=A.invalidate
return A
