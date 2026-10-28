-- Only for shaders emitting custom, already canvas-oriented clip coordinates.
-- Standard 2D shaders using transform_projection already follow LÖVE's backend.
local C={}
local function majorVersion()
 return love and love.getVersion and love.getVersion() or 11
end
function C.shader(source)
 local major=majorVersion()
 if major<12 then return source end
 local count
 source,count=source:gsub("vec4%s+position%s*%(","vec4 legacyPosition(")
 if count==0 then return source end
 return "#define POKEPORT_NATIVE_CLIP_SPACE 1\n"..source..[[
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
 vec4 clip=legacyPosition(transform_projection,vertex_position);
 clip.y*=love_ClipSpaceParams.x;
 return clip;
}
#endif
]]
end
-- Old mod shaders often pre-reflect GL clip Y for a Canvas. LÖVE 12's
-- presentation needs that legacy reflection removed as well as its native
-- backend convention applied. A normal 2D vertex shader uses its incoming
-- transform and must not receive this conversion.
function C.legacyShader(source)
 if majorVersion()<12 or type(source)~='string'
  or source:find('POKEPORT_NATIVE_CLIP_SPACE',1,true)
  or source:find('love_ClipSpaceParams',1,true) then return source end
 local _,finish,matrix=source:find('vec4%s+position%s*%(%s*mat4%s+([%a_][%w_]*)%s*,')
 if not finish then return source end
 local opening=source:find('{',finish,true)
 local body=opening and source:match('%b{}',opening)
 if not body then return source end
 body=body:gsub('/%*.-%*/',''):gsub('//[^\n]*','')
 if body:find('%f[%w_]'..matrix..'%f[^%w_]')then return source end
 return (C.shader(source):gsub('clip.y%*=love_ClipSpaceParams.x;',
  'clip.y*=-love_ClipSpaceParams.x;'))
end
return C
