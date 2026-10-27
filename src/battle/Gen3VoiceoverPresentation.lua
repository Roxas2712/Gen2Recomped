-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native tutorial cues own their queue hold and palette-fade clock. UI only reads.
-- pokefirered ce6406d8: PokedudeAction_PrintVoiceoverMessage and
-- PokedudeAction_PrintMessageWithHealthboxPals (target 8, delay 4).
local Version=require('src.core.GameVersion')
local M={}
local function active(b)return Version.isFRLG()and b and b.game and b.data end
function M.queue(b,text,highlight)
 if type(text)~='string'or text==''then return false end
 b.queue[#b.queue+1]={text=text,gen3Voiceover=true,gen3VoiceoverHealthbox=highlight==true}
 return true
end
function M.gate(b)
 if not active(b)then return false end
 local s=b.gen3Voiceover
 if s then
  if s.phase~='message'then return true end
  if b.current==s.cue or b.queue[1]==s.cue then return false end
  s.phase=s.cue.gen3VoiceoverHealthbox and'unhighlight'or'out';s.clock=0
  return true
 end
 local cue=not b.current and b.queue[1]
 if not(cue and cue.gen3Voiceover)then return false end
 b.gen3Voiceover={phase='in',coefficient=0,healthboxCoefficient=0,clock=0,cue=cue}
 return true
end
function M.update(b)
 local s=active(b)and b.gen3Voiceover
 if not s or s.phase=='message'then return end
 s.clock=s.clock+1;if s.clock<5 then return end;s.clock=0
 if s.phase=='in'then
  s.coefficient=math.min(8,s.coefficient+1);s.healthboxCoefficient=s.coefficient
  if s.coefficient==8 then s.phase=s.cue.gen3VoiceoverHealthbox and'highlight'or'message'end
 elseif s.phase=='highlight'then
  s.healthboxCoefficient=math.max(0,s.healthboxCoefficient-1)
  if s.healthboxCoefficient==0 then s.phase='message'end
 elseif s.phase=='unhighlight'then
  s.healthboxCoefficient=math.min(8,s.healthboxCoefficient+1)
  if s.healthboxCoefficient==8 then s.phase='out'end
 elseif s.phase=='out'then
  s.coefficient=math.max(0,s.coefficient-1);s.healthboxCoefficient=s.coefficient
  if s.coefficient==0 then b.gen3Voiceover=nil end
 end
end
function M.dim(b)
 local s=active(b)and b.gen3Voiceover
 return s and s.coefficient/16 or 0
end
function M.lit(b)
 local s=active(b)and b.gen3Voiceover
 return not not s and s.cue.gen3VoiceoverHealthbox==true and s.healthboxCoefficient==0
  and s.coefficient>0 or false
end
return M
