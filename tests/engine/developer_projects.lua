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
response={repositories={{id=3,repository='../private',verified=false}}};check(not D.list(1),'invalid repository identities are rejected')
print('Developer projects: '..n..' checks passed')
