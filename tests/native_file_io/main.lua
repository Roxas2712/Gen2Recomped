-- Actual Windows/LuaJIT/LÖVE file test, launched with the repository root as
-- the one argument. No ROM, mod, player profile, dialog or GPU is used.
function love.load(args)
  local root=assert(args[1],'repository root required'):gsub('\\','/')
  package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
  local Native=require('src.core.NativeFile')
  local Picker=require('src.core.FilePicker')
  local fs=love.filesystem
  local checks=0
  local function eq(a,b,label)
    checks=checks+1;assert(a==b,(label or 'values differ')..': '..tostring(a)..' ~= '..tostring(b))
  end
  local dir='owned-'..tostring(os.time())..'-'..love.math.random(1,999999)..'-用户-é-🎮'
  local files={}
  local oldOpen=io.open
  local ok,why=xpcall(function()
    eq(love.system.getOS(),'Windows','real Windows host')
    eq(require('ffi').os,'Windows','real Windows FFI')
    assert(fs.createDirectory(dir))
    -- Verify compatibility with declarations already loaded by other engine
    -- services, in both orderings, and actual atomic download replacement.
    local Publish=require('src.net.DownloadPublish')
    local before=dir..'/before-publish';local after=dir..'/after-publish'
    files[#files+1]=before;files[#files+1]=after
    assert(fs.write(before,'publisher first'))
    assert(Publish(fs.getSaveDirectory()..'/'..before,fs.getSaveDirectory()..'/'..after))
    eq(Native.read(fs.getSaveDirectory()..'/'..after),'publisher first','publisher declarations before reader')
    local expected=string.rep('\0PNG\255\r\n',20000)..'end'
    for _,name in ipairs{'Pokémon é.png','精灵 🎮.spritepack','ascii.png'}do
      local rel=dir..'/'..name;files[#files+1]=rel
      assert(fs.write(rel,expected))
      local path=fs.getSaveDirectory()..'/'..rel
      io.open=function()error('ANSI io.open must not be used on Windows')end
      eq(Native.read(path),expected,'wide read exact multi-block binary')
      eq(Picker.read(path),expected,'public picker uses native wide reader')
      eq(Picker.basename(path),name,'original name retained')
      io.open=oldOpen
      local replacement=rel..'.next';files[#files+1]=replacement
      assert(fs.write(replacement,'replacement'))
      assert(Publish(fs.getSaveDirectory()..'/'..replacement,path))
      eq(Picker.read(path),'replacement','download publisher declarations coexist after reader')
      eq(fs.remove(rel),true,'read handles closed before removal')
    end
    -- These refusals still close any opened handle and cannot alias a path
    -- through the current Windows ANSI codepage.
    local missing=fs.getSaveDirectory()..'/'..dir..'/missing.png'
    local bytes,err=Native.read(missing);eq(bytes,nil,'missing path');eq(type(err),'string')
    bytes,err=Native.read(missing..'\255');eq(bytes,nil,'invalid UTF-8 refused');eq(err,'invalid UTF-8 file path')
    local empty=dir..'/empty.png';files[#files+1]=empty;assert(fs.write(empty,''))
    bytes,err=Native.read(fs.getSaveDirectory()..'/'..empty);eq(bytes,nil);eq(err,'empty file')
    eq(fs.remove(empty),true,'empty-file handle closed')
  end,debug.traceback)
  io.open=oldOpen
  for _,rel in ipairs(files)do fs.remove(rel)end
  fs.remove(dir)
  if ok then print('NATIVE_FILE_IO_WINDOWS '..checks..' checks passed')
  else io.stderr:write(tostring(why)..'\n')end
  love.event.quit(ok and 0 or 1)
end
