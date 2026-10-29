-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local E=require('src.render.ShaderEntryPrecision')
local function entry(q)
 return q..' vec4 effect('..q..' vec4 color, Image tex, '..q..' vec2 uv, '..q..' vec2 sc) {\n if(uv.x<0.1)discard;return Texel(tex,uv)*color;\n}'
end
for _,q in ipairs{'lowp','mediump','highp'}do
 local authored=entry(q);local result,changed=E.source(authored)
 T.eq(changed,true,q..' entry admitted')
 T.check(result:find(q..' vec4 pokeportQualifiedPixelEffect(',1,true)~=nil,'body retains original precision')
 T.check(result:find('vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)',1,true)~=nil,'host default prototype has its own entry')
 T.check(result:find('return pokeportQualifiedPixelEffect(color, tex, uv, screen);',1,true)~=nil,'producer executes through the forwarding entry')
 T.check(result:find('if(uv.x<0.1)discard;return Texel(tex,uv)*color;',1,true)~=nil,'discard, texture, and authored arithmetic unchanged')
 T.eq(select(2,E.source(result)),false,'adaptation idempotent')
 local commented='/* mediump vec4 effect(vec4 fake) {} */\n'..authored
 T.check(select(2,E.source(commented)),'commented declarations do not create extra entries')
 local withDirectives='#ifdef PIXEL\n#define CUSTOM_PRECISION precision highp float;\nCUSTOM_PRECISION\n'..authored..'\n#endif'
 T.check(select(2,E.source(withDirectives)),'literal parameter qualifiers survive user float precision directives')
end
for _,source in ipairs{
 'vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){return c;}',
 '// '..entry('mediump'):gsub('\n',' '),
 '/* '..entry('mediump')..' */',
 '/* unfinished '..entry('mediump'),
 entry('mediump'):gsub('mediump vec2 uv','vec2 uv'),
 entry('mediump'):gsub('Image tex','sampler2D tex'),
 entry('mediump')..'\n'..entry('highp'),
 '#define effect renamed\n'..entry('mediump'),
 '#define Image samplerCube\n'..entry('mediump'),
 'precision highp sampler2D;\n'..entry('mediump'),
 'void pixelmain(){}\n'..entry('mediump'),
 'void pokeportQualifiedPixelEffect(){}\n'..entry('mediump'),
}do
 local result,changed=E.source(source);T.eq(result,source,'unknown/custom entry is not guessed');T.eq(changed,false)
end
-- Constructor and validator share adaptation without falsely owning the
-- independent legacy clip-space uniform for a pixel-only source.
local savedLove=love
package.loaded['src.render.LegacyShaderCompat']=nil
local selected,canvas,compiled,validated=nil,nil,{},{}
love={getVersion=function()return 12,0,0 end,graphics={
 newShader=function(a,b,c)compiled[#compiled+1]={a,b,c};return{hasUniform=function()return false end}end,
 validateShader=function(es,a,b,c)validated[#validated+1]={es,a,b,c};return true,'native validator result'end,
 getShader=function()return selected end,getCanvas=function()return canvas end,
 setShader=function(s)selected=s end,setCanvas=function(c)canvas=c end,pop=function()end,
}}
local C=require('src.render.LegacyShaderCompat');T.check(C.install(),'LOVE12 entry adapter installed')
local options={defines={OWNED_TEST=1}};local authored=entry('mediump')
love.graphics.newShader(authored,options)
T.check(compiled[1][1]~=authored,'actual constructor receives qualified compatibility source');T.eq(compiled[1][2],options,'options retain identity')
T.eq(compiled[1][1]:find('pokeportLegacyCanvasY',1,true),nil,'pixel entry never receives vertex projection changes')
local ok,message=love.graphics.validateShader(false,authored,options)
T.eq(ok,true,'validator result retained');T.eq(message,'native validator result');T.eq(validated[1][2],compiled[1][1],'validation and compile use identical source')
local nativeOptions={defines={POKEPORT_NATIVE_CLIP_SPACE=1}}
love.graphics.newShader(authored,nativeOptions);T.eq(compiled[2][1],authored,'explicit native compiler contract preserved')
love=savedLove
T.finish('qualified legacy shader entry precision')
