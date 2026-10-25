-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Mail=require("src.pokemon.Gen2Mail")
local Menu=require("src.ui.Menu")
local ListMenu=require("src.ui.ListMenu")
local TextBox=require("src.render.TextBox")
local Strings=require("src.core.Strings")
local M={}
function M.new(game,opts)
  opts=opts or {};Mail.reclaimQuarantine(game.save)
  local entries={}
  for i,letter in ipairs(Mail.mailbox(game.save)) do
    entries[#entries+1]={label=(letter.author~="" and letter.author) or Strings("MAIL"),value=i}
  end
  if #entries==0 then return TextBox.new(game,Strings("There's no MAIL\nhere."),opts.onCancel) end
  local list
  local function say(text)game.stack:push(TextBox.new(game,Strings(text)))end
  local function removed(index)
    -- Both the displayed rows and native mailbox shift by the same index.
    list.index=index;list:removeCurrent()
  end
  list=ListMenu.new(game,Strings("MAILBOX"),entries,{onCancel=opts.onCancel,onChoose=function(item)
    local index=item.value
    local letter=Mail.mailbox(game.save)[index];if not letter then return end
    game.stack:push(Menu.new(game,{
      {label=Strings("READ"),onSelect=function()require("src.ui.Gen2MailMenu").read(game,letter)end},
      {label=Strings("GIVE"),onSelect=function()
        require("src.ui.Screens").push(game,"PartyMenu",{pickOnly=true,onSwitch=function(mon)
          local slot
          for i,member in ipairs(game.save.party or {})do if mon==member then slot=i;break end end
          if not slot or Mail.mailbox(game.save)[index]~=letter or not Mail.moveFromPcToParty(game.save,index,slot) then say(Strings("That POKéMON can't\nhold this MAIL."));return end
          removed(index);say("MAIL attached.")
        end})
      end},
      {label=Strings("MOVE TO BAG"),onSelect=function()
        game.stack:push(TextBox.new(game,Strings("The MAIL will lose\nits message. OK?"),nil,{
          defaultNo=true,choice=function(yes)
            if not yes then return end
            local current=Mail.mailbox(game.save)[index];if current~=letter then return end
            if not require("src.inventory.Bag").add(game.save,current.type,1,game.data) then say("The PACK is full.");return end
            Mail.deleteFromPc(game.save,index);removed(index);say("MAIL moved to PACK.")
          end}))
      end},
      {label=Strings("CANCEL")},
    },{tx=7,ty=8,tw=13,th=10}))
  end})
  -- Row values must follow the dense mailbox after every deletion.
  local remove=list.removeCurrent
  function list:removeCurrent()
    remove(self)
    for i,row in ipairs(self.items)do row.value=i end
  end
  return list
end
return M
