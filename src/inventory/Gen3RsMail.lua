-- Stable save IDs and atomic host transfers around the pinned mail policy.
-- Projection and composing receipts never modify the authoritative save.
local M={};M.__index=M
local Bag=require('src.inventory.Bag')
local Serializer=require('src.core.SaveSerializer')
local function clone(v)
  if type(v)~='table'then return v end
  local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function integer(n,lo,hi)
  return type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi
end
local function replace(target,source)
  for k in pairs(target)do target[k]=nil end
  for k,v in pairs(source)do target[k]=v end
end
local function wordsValid(words)
  if type(words)~='table'then return false end
  for i=1,9 do if not integer(words[i],0,65535)then return false end end
  for i in pairs(words)do if not integer(i,1,9)then return false end end
  return true
end
function M.new(game)
  local self=setmetatable({game=game,items={},numbers={},species={},speciesNumbers={}},M)
  local spec=game.data and game.data.constants and game.data.constants.gen3RsBag
  if not(type(spec)=='table'and spec.format==1 and(spec.version=='ruby'or spec.version=='sapphire'))
    or(game.save.version and game.save.version~=spec.version)then self.reason='edition';return self end
  self.version=spec.version
  for id,d in pairs(game.data.items or{})do if integer(d.index,1,65535)then
    if self.items[d.index]then self.reason='duplicate_item';return self end
    self.items[d.index]=id;self.numbers[id]=d.index
  end end
  for id,d in pairs(game.data.pokemon or{})do if integer(d.index,1,65535)then
    if self.species[d.index]then self.reason='duplicate_species';return self end
    self.species[d.index]=id;self.speciesNumbers[id]=d.index
  end end
  local load=require('compat.gen1-rs.Loader').new(self.version,{
    ['src.core.game3.profile']={forSession=function()return{mail={exportEmpty=true,
      newRecord=function(s,r)
        r.trainerId=s.trainerId+s.secretId*65536;r._rsNewMail=true
      end}}end},
  })
  self.native=load('src.core.game3.mail')
  self.valid,self.reason=self:refresh();return self
end
function M:isMail(id)return self.native and self.native.isMailItem(self.numbers[id])or false end
function M:fingerprint()
  local s=self.game.save;local party={}
  for i,mon in ipairs(s.party or{})do
    party[i]={item=mon.item,heldItem=mon.heldItem,mail=mon.mail,species=mon.species,
      personality=mon.personality,isEgg=mon.isEgg,egg=mon.egg}
  end
  return Serializer.encode({inventory=s.inventory,bagOrder=s.bagOrder,slots=s.gen3RsBagSlots,
    pyramid=s.gen3PyramidBag,mail=s.gen3RsMail,party=party,player=s.player})
end
function M:project()
  if not self.native then return nil,self.reason or'edition'end
  local save=self.game.save;local stored=save.gen3RsMail
  if save.party~=nil and type(save.party)~='table'then return nil,'invalid_party'end
  for i,mon in pairs(save.party or{})do
    if not integer(i,1,6)or i>#save.party or type(mon)~='table'then return nil,'invalid_party'end
  end
  if stored~=nil and(type(stored)~='table'or stored.format~=1 or stored.version~=self.version
    or type(stored.records)~='table')then return nil,'invalid_mail' end
  local player=save.player or{}
  local s={version=self.version,name=player.name or'',gender=player.gender,
    trainerId=math.floor(tonumber(player.id)or 0)%65536,
    secretId=math.floor(tonumber(player.secretId or save.secretId)or 0)%65536,
    party={},mail={}}
  local records=stored and stored.records or{}
  for i in pairs(records)do if not integer(i,1,16)then return nil,'invalid_slot'end end
  for i=1,16 do
    local r=records[i]
    if r==nil then s.mail[i]=self.native.clear()
    else
      if type(r)~='table'or not self:isMail(r.item)or not self.speciesNumbers[r.species]
        or not wordsValid(r.words)or type(r.playerName)~='string'
        or not integer(r.trainerId,0,4294967295)
        or(r.unownLetter~=nil and(not integer(r.unownLetter,0,27)or self.speciesNumbers[r.species]~=201))then
        return nil,'invalid_record'
      end
      local native=clone(r);native.itemId=self.numbers[r.item]
      native.species=r.unownLetter and(30000+r.unownLetter)or self.speciesNumbers[r.species]
      native.item,native.unownLetter=nil,nil;native.design=self.native.designOf(native.itemId)
      s.mail[i]=native
    end
  end
  local used={}
  if #(save.party or{})>6 then return nil,'invalid_party'end
  for i,mon in ipairs(save.party or{})do
    if mon.heldItem~=nil and mon.heldItem~=mon.item then return nil,'ambiguous_held_item'end
    local n=self.numbers[mon.item]or 0
    if mon.item~=nil and mon.item~=0 and not self.numbers[mon.item]then return nil,'unknown_held'end
    local projected={species=self.speciesNumbers[mon.species],personality=mon.personality,
      item=n,heldItem=n,mail=mon.mail}
    if not projected.species then return nil,'unknown_species'end
    if self.native.isMailItem(n)then
      local id=mon.mail
      if not integer(id,0,5)or used[id]or self.native.isEmpty(s.mail[id+1])
        or s.mail[id+1].itemId~=n then return nil,'missing_held_mail'end
      used[id]=true
    elseif mon.mail~=nil and mon.mail~=255 then return nil,'dangling_mail'end
    s.party[i]=projected
  end
  for i=1,6 do if not self.native.isEmpty(s.mail[i])and not used[i-1]then return nil,'orphan_held_mail'end end
  return s
end
function M:refresh()
  if not self.native then return false,self.reason end
  local s,why=self:project();self.session=s;self.valid=s~=nil;self.reason=why
  return self.valid,why
end
function M:bagCopy()
  local s=self.game.save
  return{inventory=clone(s.inventory or{}),bagOrder=clone(s.bagOrder or{}),
    gen3RsBagSlots=clone(s.gen3RsBagSlots),gen3PyramidBag=s.gen3PyramidBag}
end
function M:commit(s,bag)
  local save=self.game.save;local records={}
  for i=1,16 do local r=s.mail[i]
    if not self.native.isEmpty(r)then
      local stable=clone(r);stable.item=assert(self.items[r.itemId])
      local number,letter=self.native.mailSpeciesToSpecies(r.species)
      stable.species=assert(self.species[number]);stable.unownLetter=number==201 and letter or nil
      stable.itemId=nil;stable.design=nil;records[i]=stable
    end
  end
  save.gen3RsMail=save.gen3RsMail or{format=1,version=self.version,records={}}
  replace(save.gen3RsMail.records,records)
  for i,mon in ipairs(save.party or{})do local p=s.party[i]
    mon.item=p.item~=0 and self.items[p.item]or nil
    if mon.heldItem~=nil then mon.heldItem=mon.item end
    mon.mail=p.mail~=255 and p.mail or nil
  end
  if bag then
    save.inventory=save.inventory or{};save.bagOrder=save.bagOrder or{}
    replace(save.inventory,bag.inventory);replace(save.bagOrder,bag.bagOrder)
    save.gen3RsBagSlots=bag.gen3RsBagSlots
  end
  self:refresh();assert(self.valid,'Committed invalid mail state');return true
end
function M:prepareGive(index,id,selection)
  local s,why=self:project();if not s then return nil,why end
  local mon=s.party[index];local original=(self.game.save.party or{})[index]
  if not mon or original.isEgg or original.egg then return nil,'invalid_mon'end
  if not self:isMail(id)then return nil,'not_mail'end
  if self.native.monHasMail(mon)then return nil,'holding_mail'end
  local bag=self:bagCopy()
  if not Bag.remove(bag,id,1,self.game.data,selection)then return nil,'missing_item'end
  local previous=mon.item
  if previous~=0 and not Bag.add(bag,self.items[previous],1,self.game.data)then return nil,'bag_full'end
  local mailId=self.native.giveMailToMon(s,mon,self.numbers[id])
  if mailId==self.native.MAIL_NONE then return nil,'mail_slots_full'end
  return{owner=self,session=s,bag=bag,record=s.mail[mailId+1],index=index,
    mon=original,previous=previous~=0 and self.items[previous]or nil,before=self:fingerprint(),finished=false}
end
function M:accept(tx,words)
  if type(tx)~='table'or tx.owner~=self or tx.finished then return false,'finished'end
  if not wordsValid(words)then return false,'invalid_words'end
  if tx.before~=self:fingerprint()or(self.game.save.party or{})[tx.index]~=tx.mon then
    tx.finished=true;return false,'stale'
  end
  tx.record.words=clone(words);tx.finished=true;return self:commit(tx.session,tx.bag)
end
function M:cancel(tx)
  if type(tx)~='table'or tx.owner~=self or tx.finished then return false end
  tx.finished=true;return true
end
function M:readParty(index)
  local s,why=self:project();if not s then return nil,why end
  local mon=s.party[index]
  if not mon or not self.native.monHasMail(mon)then return nil,'no_mail'end
  return clone(self.native.get(s,mon.mail))
end
function M:mailbox()
  local s,why=self:project();if not s then return nil,why end
  local out={}
  for id=6,15 do if not self.native.isEmpty(s.mail[id+1])then out[#out+1]={id=id,record=clone(s.mail[id+1])}end end
  return out
end
function M:store(index)
  local s,why=self:project();if not s then return false,why end
  local mon=s.party[index]
  if not mon or not self.native.monHasMail(mon)then return false,'no_mail'end
  for id=6,15 do if self.native.isEmpty(s.mail[id+1])then
    s.mail[id+1]=clone(self.native.get(s,mon.mail));self.native.takeMailFromMon(s,mon)
    return self:commit(s)
  end end
  return false,'mailbox_full'
end
function M:take(index)
  local s,why=self:project();if not s then return false,why end
  local mon=s.party[index]
  if not mon or not self.native.monHasMail(mon)then return false,'no_mail'end
  local bag=self:bagCopy()
  if not Bag.add(bag,self.items[mon.item],1,self.game.data)then return false,'bag_full'end
  self.native.takeMailFromMon(s,mon);return self:commit(s,bag)
end
function M:moveToBag(mailId)
  local s,why=self:project();if not s then return false,why end
  if not integer(mailId,6,15)or self.native.isEmpty(s.mail[mailId+1])then return false,'no_mail'end
  local bag=self:bagCopy();local r=s.mail[mailId+1]
  if not Bag.add(bag,self.items[r.itemId],1,self.game.data)then return false,'bag_full'end
  self.native.clear(r);return self:commit(s,bag)
end
function M:giveFromMailbox(mailId,index)
  local s,why=self:project();if not s then return false,why end
  if not integer(mailId,6,15)or self.native.isEmpty(s.mail[mailId+1])then return false,'no_mail'end
  local mon=s.party[index];local original=(self.game.save.party or{})[index]
  if not mon or original.isEgg or original.egg then return false,'invalid_mon'end
  if mon.item~=0 then return false,'holding_item'end
  local record=clone(s.mail[mailId+1])
  if self.native.giveMailToMon2(s,mon,record)==255 then return false,'mail_slots_full'end
  self.native.clear(s.mail[mailId+1]);return self:commit(s)
end
return M
