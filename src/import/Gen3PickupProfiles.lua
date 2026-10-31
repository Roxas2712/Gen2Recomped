-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Exact owned-cartridge table locations, not redistributed item tables.
local rows={
 ruby={sha1='f28b6ffc97847e94a6c21a63cacf633ee5c8df1e',style='fixed',items=0x1FAD5E,count=10,wide=true},
 sapphire={sha1='3ccbbd45f8553c36463f13b938e833f652b793e4',style='fixed',items=0x1FACEE,count=10,wide=true},
 firered={sha1='41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc',style='fixed',items=2426952,count=16},
 leafgreen={sha1='574fa542ffebb14be69902d1d36f1ec0a4afd71e',style='fixed',items=2426916,count=16},
 emerald={sha1='f3ae088181bf583e55daf962a92bb46f4f1d07b7',style='level',common=0x31C440,rare=0x31C464,cuts=0x31C47A,
  pyramid50=0x61379C,pyramidOpen=0x61392C,pyramidCuts=0x613F86},
}
return{REVISION=1,get=function(edition,sha1)
 local p=rows[edition];if p and p.sha1==sha1 then return p end
end}
