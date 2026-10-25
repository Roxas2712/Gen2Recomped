package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local Json=require('src.link.Json')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local account='one@example.test'
package.loaded['src.cloud.RetroCloud']={account=function() return account end}
local response;local sent
package.loaded['src.cloud.NativeAccount']={request=function(method,path,payload) sent={method=method,path=path,payload=payload};return response end}
local D=require('src.cloud.DeveloperProjects')
local proof=Json.encode({service='modcompass',account=1,repository='author/first',nonce='public-nonce'})
response={id=1,repository='author/first',verified=false,proof=proof,proof_url='https://invalid.example'}
local project=assert(D.prepare('author/first','policy-v1'))
check(sent.payload.terms_version=='policy-v1' and sent.payload.developer_rights_accepted,'project registration carries the reviewed agreement version')
check(project.proof_url==nil and D.proofUrl(project):find('https://github.com/author/first/new/HEAD?',1,true)==1,'proof links are built locally from the project identity')
response={repositories={{id=1,repository='author/first',verified=false},{id=2,repository='author/second',verified=false}},page=1,total=2}
local list=assert(D.list(1))
check(list.repositories[1].proof==proof and not list.repositories[2].proof,'refresh preserves each repository proof independently')
account='two@example.test';check(not D.list(1).repositories[1].proof,'account switches never reuse another account project proof')
response={id=2,repository='author/second',verified=true};check(D.verify(2).verified and sent.path=='/developer/repositories/2/verify','verification selects one project by server identifier')
check(not D.verify(-1),'invalid project ids cannot become API paths')
response={id=4,repository='author/branch',verified=false,proof=Json.encode({service='modcompass',account=1,repository='author/branch',nonce='branch-proof'}),proof_url='https://github.com/author/branch/new/release%2Fnext?filename=.modcompass-developer.json'}
local branch=assert(D.prepare('author/branch','policy-v1'))
check(D.proofUrl(branch)==response.proof_url,'prepared GitHub links retain the actual repository default branch')
check(not D.uploadCover({id=4,verified=false},'bytes','Credit','Cover',true),'unverified projects cannot upload a cover')
check(not D.uploadCover({id=4,verified=true},'bytes','Credit','Cover',false),'cover publication needs separate image rights consent')
local header='\137PNG\13\10\26\10'..string.char(0,0,0,13)..'IHDR'..string.char(0,0,0,64,0,0,0,64)
love.data={encode=function() return 'encoded-png' end}
response={digest=string.rep('a',64),status='pending_review'}
check(D.uploadCover({id=4,verified=true},header,'Artist','Mod preview',true).status=='pending_review','verified developers can submit a selected cover to review')
check(sent.path=='/developer/repositories/4/cover' and sent.payload.artwork_rights_accepted and sent.payload.credit=='Artist','the upload is bound to the verified repository and explicit rights choice')
response={repositories={{id=3,repository='../private',verified=false}}};check(not D.list(1),'invalid repository identities are rejected')
print('Developer projects: '..n..' checks passed')
