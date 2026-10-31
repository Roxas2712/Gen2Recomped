-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
function M.record(version)
 local r={format=1,version=version,labels={},messages={},fieldMoves={}}
 for _,key in ipairs{'summary','switch','cancel','item','give','takeItem','mail','takeMail',
  'read','shift','sendOut','enter','noEntry','store','register','trade1','trade2'}do r.labels[key]=key end
 for _,key in ipairs{'chooseMon','chooseMonOrCancel','chooseMonAndConfirm','moveToWhere',
  'teachWhichMon','useOnWhichMon','giveToWhichMon','nothingToCut','cantSurfHere','alreadySurfing',
  'currentTooFast','enjoyCycling','inUseAlready','cantUseHere','noMonForBattle','notEnoughHp',
  'doWhatWithMon','restoreWhichMove','boostPpWhichMove','doWhatWithItem','doWhatWithMail'}do r.messages[key]=key end
 for _,key in ipairs{'FLASH','CUT','FLY','STRENGTH','SURF','ROCK_SMASH','WATERFALL',
  'TELEPORT','DIG','MILK_DRINK','SOFT_BOILED','SWEET_SCENT'}do r.fieldMoves[#r.fieldMoves+1]={move=key,label=key}end
 return r
end
return M
