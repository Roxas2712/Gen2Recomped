package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local M=require('src.mods.ModAccess')
local count=0;local function check(v,m) assert(v,m);count=count+1 end
local installed={{id='local-mod',version='1.0.0',github='Author/Project'}}
local release={version='1.1.0',zip={url='https://github.com/Author/Project/releases/download/v1.1.0/local-mod.zip'}}
check(M.updateAllowed('local-mod',release,'author/project',installed),'an installed manual mod can update from its original repository without an account')
check(not M.updateAllowed('new-mod',release,'author/project',installed),'the guest update exception never authorizes installing a new mod')
check(not M.updateAllowed('local-mod',release,'other/project',installed),'a different claimed repository cannot replace the installed source')
local bad={version='2.0.0',zip={url='https://github.com/Attacker/Project/releases/download/v2.0.0/local-mod.zip'}}
check(not M.updateAllowed('local-mod',bad,'Author/Project',installed),'foreign repository ZIPs are rejected before download')
for _,url in ipairs({'https://github.com/Author/Project/releases/download/../attack.zip','https://github.com/Author/Project/releases/download/v2/file.zip?redirect=other','http://github.com/Author/Project/releases/download/v2/file.zip'}) do
 bad.zip.url=url;check(not M.updateAllowed('local-mod',bad,'Author/Project',installed),'traversal, redirect queries and insecure update URLs are rejected')
end
release.version='1.0.0';check(not M.updateAllowed('local-mod',release,'Author/Project',installed),'a same-version download cannot pretend to be a guest update')
release.version='0.9.0';check(not M.updateAllowed('local-mod',release,'Author/Project',installed),'guest updates cannot downgrade installed versions')
release.version='1.1.0';installed[1].updateCheck=false
check(not M.updateAllowed('local-mod',release,'Author/Project',installed),'the author’s update opt-out is respected')
installed[1].updateCheck=true;installed[1].github=nil
local options={modInstallSources={['local-mod']={repo='Author/Project',version='1.0.0'}}}
check(M.repository(installed[1],options)=='Author/Project' and M.updateAllowed('local-mod',release,'Author/Project',installed,options),'saved source metadata keeps repository tracking when a package omits its github field')
options.modInstallSources['local-mod'].version='0.5.0'
check(not M.repository(installed[1],options),'a stale receipt cannot attach its repository to a different installed version')
local Zip=require('src.mods.LauncherMods');local calls=0
Zip._installZipInner=function(path) calls=calls+1;return true,'local-mod','1.0.0' end
check(Zip.installZip('manual.zip') and calls==1,'manual ZIP installation never consults an account gate')
print('Guest mod access: '..count..' checks passed')
