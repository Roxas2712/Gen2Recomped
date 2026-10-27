local Boot=require('src.ui.Gen3RsBoot')
return {new=function(game,onDone)
  local opts=type(onDone)=='table'and onDone or{onDone=onDone}
  return Boot.new(game,'intro',opts)
end}
