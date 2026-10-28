-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared desktop picker contract. RomImporter retains the one dialog launch
-- path, including pointer-grab release; importing this module starts nothing.
local Host=require('src.core.HostShell')
local M={IMAGE={label='Image',exts={'png','jpg','jpeg'}}}
local function promptOk(value)return type(value)=='string'and #value<=512 and not value:find('%z')end
local function kindOf(kind)
 kind=kind or M.IMAGE
 if type(kind)~='table'or type(kind.exts)~='table'or #kind.exts<1 or #kind.exts>16 then return end
 local label=kind.label or 'File'
 if type(label)~='string'or #label>128 or label:find('[%z\r\n|]')then return end
 local exts,seen={},{}
 for _,ext in ipairs(kind.exts)do
  if type(ext)~='string'or #ext>24 or not ext:match('^[%w][%w_.-]*$')then return end
  ext=ext:lower();if not seen[ext]then seen[ext]=true;exts[#exts+1]=ext end
 end
 return{label=label,exts=exts}
end
local function backend()
 if not Host.canSpawnProcess()then return end
 local os=love.system.getOS()
 if os=='OS X'or os=='Windows'then return os end
 if os=='Linux'then
  if Host.hasCommand('zenity')then return 'zenity'end
  if Host.hasCommand('kdialog')then return 'kdialog'end
 end
end
function M.available()return backend()~=nil end
function M.matches(name,kind)
 local k=kindOf(kind);if not k or type(name)~='string'then return false end
 name=name:lower()
 for _,ext in ipairs(k.exts)do if name:sub(-#ext-1)=='.'..ext then return true end end
 return false
end
local function shell(value)return "'"..value:gsub("'","'\\''").."'"end
local function apple(value)return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"'end
-- Untrusted UTF-8 travels as decimal bytes, never as PowerShell/cmd syntax.
local function windows(value)
 local bytes={};for i=1,#value do bytes[i]=tostring(value:byte(i))end
 return '([Text.Encoding]::UTF8.GetString([byte[]]@('..table.concat(bytes,',')..')))'
end
function M.commands(prompt,kind)
 local k=kindOf(kind)
 if not k or not promptOk(prompt)then return end
 local os=backend();if not os then return end
 local globs,types={},{}
 for i,ext in ipairs(k.exts)do globs[i]='*.'..ext;types[i]=apple(ext)end
 if os=='OS X'then
  local script='POSIX path of (choose file with prompt '..apple(prompt)..' of type {'..table.concat(types,', ')..'})'
  return{'osascript -e '..shell(script)..' 2>/dev/null'}
 elseif os=='Windows'then
  local patterns=table.concat(globs,';')
  local filter=k.label..' ('..patterns..')|'..patterns..'|All files (*.*)|*.*'
  local script=table.concat({'Add-Type -AssemblyName System.Windows.Forms;',
   '$d=New-Object System.Windows.Forms.OpenFileDialog;','$d.Title='..windows(prompt)..';',
   '$d.Filter='..windows(filter)..';',"if($d.ShowDialog() -eq 'OK'){$p=$d.FileName;$ascii=$true;",
   'foreach($c in $p.ToCharArray()){if([int]$c -lt 32 -or [int]$c -gt 126){$ascii=$false}};',
   '[Console]::OutputEncoding=[Text.Encoding]::UTF8;if($ascii){[Console]::Write($p)}else{',
   "$t=Join-Path $env:TEMP ('pokeport_base_'+[Guid]::NewGuid().ToString('N')+[IO.Path]::GetExtension($p));",
   'try{Copy-Item -LiteralPath $p -Destination $t -ErrorAction Stop;[Console]::Write($t)}catch{}}}'})
  local command='powershell -NoProfile -STA -Command "'..script..'"'
  if #command>7000 then return end
  return{command}
 elseif os=='zenity'then
  return{'zenity --file-selection --title='..shell(prompt)..' --file-filter='..shell(k.label..' | '..table.concat(globs,' '))..' 2>/dev/null'}
 else
  return{'kdialog --getopenfilename "$HOME" '..shell(table.concat(globs,' ')..'|'..k.label)..' --title '..shell(prompt)..' 2>/dev/null'}
 end
end
function M.open(prompt,kind)
 local k=kindOf(kind);if not k or not promptOk(prompt)then return end
 return require('src.import.RomImporter').chooseFileByExt(k.exts,nil,{title=prompt,label=k.label})
end
function M.basename(path)return tostring(path or''):match('([^/\\]+)$')or tostring(path or'')end
function M.read(path)
 if type(path)~='string'or path:find('%z')then return nil,'invalid native file path'end
 local opened,file,why=pcall(io.open,path,'rb')
 if not opened or not file then return nil,opened and why or file end
 local ok,bytes,err=pcall(file.read,file,'*a');pcall(file.close,file)
 if not ok then return nil,bytes end
 if not bytes or bytes==''then return nil,err or 'empty file'end
 return bytes
end
return M
