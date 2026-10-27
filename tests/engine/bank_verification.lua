package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local signed,account=true,'1';local written=false;local other=false
package.loaded['src.cloud.RetroCloud']={signedIn=function()return signed end,accountId=function()return account end,
 open=function()return{has=function()return written end,write=function()written=true;return true end,read=function()return'return {}'end}end}
package.loaded['src.core.SaveData']={persistenceFs=function()return{read=function()return'return {}'end}end}
local digest=string.rep('a',64)
package.loaded['src.cloud.NativeAccount']={request=function(method,path)
 T.check(path=='/bank/entries/'..digest..'/verification','verification stays scoped to the selected immutable Bank digest')
 return{account_id=other and'2'or account,bank_digest=digest,state=method=='POST'and'pending'or'legal'}
end}
local B=require('src.cloud.BankVerification')
T.check(not B.request({}),'unbanked live Pokémon cannot claim a verified Bank identity')
local result=assert(B.request({id=digest}));T.check(written and result.state=='pending','first check syncs the exact owned Bank copy')
T.eq(assert(B.request({id=digest},true)).state,'legal','refresh reads the saved worker report')
other=true;T.check(not B.request({id=digest},true),'another account report is refused')
signed=false;T.check(not B.request({id=digest},true),'signed-out profiles cannot read Bank reports')
T.finish('Bank verification account boundaries')
