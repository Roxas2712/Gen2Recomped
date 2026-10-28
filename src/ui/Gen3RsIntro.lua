local Boot = require('src.ui.Gen3RsBoot')
return {new=function(game, onDone) return Boot.new(game, 'intro', {onDone=onDone}) end}
