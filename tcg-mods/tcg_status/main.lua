-- Optional example by Roxas2712. Enable it on the TCG cartridge page.
api.on('draw',function()
 local info=api.info()
 api.draw.rectangle(0,0,160,11,{0,.05,.1,.85})
 api.draw.text((info.online and 'ONLINE' or 'SOLO')..'  TCG API '..api.version..'  '..info.frame,3,1,{.7,.9,1,1})
end)
