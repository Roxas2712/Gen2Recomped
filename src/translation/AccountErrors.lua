-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Known validation rules become reviewed templates. No field value is sent
-- to a translator; unrecognized server messages retain their diagnostic text.
local E={}
local fields={email='Email',password='Password',name='Nickname / display name',code='Email code',
 friend_tag='Friend tag',player='Player',dex='National species number',level='Level',moves='Moves',
 title='Title',capacity='Capacity (2–64)',team_size='Team size (1–6)',reason='Reason',
 avatar='Avatar',image_base64='Profile image',repository='Repository',repositories='Repositories'}
function E.validation(field,message)
 if type(message)~='string'then return message end
 local S=require('src.translation.Service');local label=fields[field]
 if not label then return S.launcherLookup(message)end
 local text
 if message:match(' field is required%.$')then text=S.launcherLookup('Please complete this field.')
 elseif message:match('must be a valid email address%.$')then text=S.launcherLookup('Enter a valid email address.')
 elseif message:match('confirmation does not match%.$')then text=S.launcherLookup('The confirmation does not match.')
 elseif message:match('has already been taken%.$')then text=S.launcherLookup('This value is already in use.')
 elseif message:match('must be an integer%.$')then text=S.launcherLookup('Enter a whole number.')
 elseif message:match('must be accepted%.$')then text=S.launcherLookup('Please read and accept this agreement.')
 else
  local min=message:match('must be at least (%d+) characters%.$')
  local max=message:match('must not be greater than (%d+) characters%.$')
  if min then text=S.launcherFormat('Enter at least %d characters.',tonumber(min))
  elseif max then text=S.launcherFormat('Enter at most %d characters.',tonumber(max))end
 end
 return text and S.launcherFormat('%s: %s',S.launcherLookup(label),text)or S.launcherLookup(message)
end
return E
