local _,C=...
-- Original, per-quest handshake: a missing reply never means a missing quest.
C.AutoShare={prefix="GGNEED1",queue={},replies={},seen={},suppressed={},lastQuery={},serial=0}
local A=C.AutoShare
function A:Enabled()
    return C.State.data.settings.party~=false and C.Auto:Enabled("autoSharePickup") and C.QuestShare:PartySignature()~=nil
end
function A:Reset()
    self.queue={};self.replies={};self.lastQuery={};self.request=nil
end
function A:Suppress(id)
    self.suppressed[id]=C.QuestShare:Clock()+120
    for i=#self.queue,1,-1 do if self.queue[i].id==id then table.remove(self.queue,i) end end
    if self.request and self.request.id==id then self.request=nil end
end
function A:Accepted(first,second)
    if not C.Safe(first) or not C.Safe(second) then return end
    local id=second or first;local now=C.QuestShare:Clock()
    if type(id)~="number" or id<1 or id>10000000 or id~=math.floor(id) then return end
    -- A shared quest, whether accepted manually or automatically, never relays.
    if C.Call(GetQuestID)==id and C.QuestShare:OfferingPlayer() then self:Suppress(id) end
    if not self:Enabled() or (self.suppressed[id] or 0)>now or (self.seen[id] or 0)>now then return end
    self.seen[id]=now+120
    if #self.queue<40 then
        self.queue[#self.queue+1]={id=id,at=now+1,expires=now+90,signature=C.QuestShare:PartySignature()}
    end
end
function A:Needed(id)
    -- A missed pickup is still needed after moving on to a later part.
    -- Explicit Share Quests remains separate and can offer the whole log.
    if not C.Auto:Scheduled(id,"pickup") then return false end
    if C.State.facts.active[id] or C.State.data.completedQuests[id] then return false end
    local api=C_QuestLog or {}
    if C.Call(api.IsOnQuest,id)==true then return false end
    -- Require a known unfinished quest as well as a scheduled pickup.
    local done=C.Call(api.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,id)
    if done~=false and done~=0 then return false end
    local ok,index=C.QuestShare:ExpandedLog(function()return C.QuestShare:LogIndex(id)end)
    return ok and not index
end
function A:Send(packet)
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function" or #packet>255 then return false end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,self.prefix,packet,"PARTY")
    if C.Social then C.Social.lastSend=C.Now() end
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    return ok and C.Safe(result) and (result==true or result==success)
end
function A:Receive(prefix,message,channel,sender)
    if not C.Safe(prefix) or prefix~=self.prefix or not C.Safe(message) or not C.Safe(channel) or not C.Safe(sender) then return end
    if type(message)~="string" or #message>255 or channel~="PARTY" or C.State.data.settings.party==false or not C.QuestShare:PartySignature() then return end
    local key=C.API:PlayerKey(sender);local me=C.API:Character();local own=C.API:PlayerKey(me.name,me.realm)
    if not key or key==own or not C.API:GroupMembers()[key] or C.API:IsIgnored(sender) then return end
    local kind,id,nonce,target=message:match("^([QN]);(%d+);([%d%-]+);(.*)$")
    id=tonumber(id)
    if not kind or not id or id<1 or id>10000000 or #nonce>32 then return end
    local now=C.QuestShare:Clock()
    if kind=="Q" then
        if target~="" or now-(self.lastQuery[key] or -1000)<5 or C.QuestShare:Blocked() then return end
        self.lastQuery[key]=now
        if self:Needed(id) then self.replies[key]={id=id,nonce=nonce,target=key,expires=now+8,signature=C.QuestShare:PartySignature()} end
    else
        local r=self.request
        if target~=own or not r or r.id~=id or r.nonce~=nonce or r.expires<now or r.signature~=C.QuestShare:PartySignature() then return end
        r.needs[key]=now
    end
end
function A:QuestTitle(id)
    local title=C_QuestLog and C.Call(C_QuestLog.GetTitleForQuestID,id)
    if not title then
        local ok,value=C.QuestShare:ExpandedLog(function()
            local index=C.QuestShare:LogIndex(id)
            return index and C.Call(GetQuestLogTitle,index)
        end)
        if ok then title=value end
    end
    title=C.Text(title)
    if title=="" or #title>180 then title="Quest #"..id end
    return title
end
function A:Tick()
    local q=C.QuestShare;local now=q:Clock();local signature=q:PartySignature()
    for id,expires in pairs(self.seen) do if expires<now then self.seen[id]=nil end end
    for id,expires in pairs(self.suppressed) do if expires<now then self.suppressed[id]=nil end end
    if not signature or C.State.data.settings.party==false then self:Reset();return end
    if not self:Enabled() then self.queue={};self.request=nil end
    if self.request and (self.request.expires<now or self.request.signature~=signature) then self.request=nil end
    if q:Blocked() then return end
    if C.Social and C.Now()-(C.Social.lastSend or -1000)<2 then return end
    -- Replies report only this quest, and are checked again just before sending.
    for key,reply in pairs(self.replies) do
        self.replies[key]=nil
        if reply.expires>=now and reply.signature==signature and C.API:GroupMembers()[key] and not C.API:IsIgnored(key) and self:Needed(reply.id) then
            self:Send(table.concat({"N",reply.id,reply.nonce,key},";"));return true
        end
    end
    -- The explicit share-all sequence owns the native share dialog until done.
    if q.session or not self:Enabled() or now-(q.lastSharedAt or -1000)<5 then return end
    local r=self.request
    if r then
        if now<r.sentAt+2 then return end
        local needed=false
        for key,at in pairs(r.needs) do
            if now-at<=8 and C.API:GroupMembers()[key] and not C.API:IsIgnored(key) then needed=true end
        end
        if not needed then return end
        self.request=nil
        local title=self:QuestTitle(r.id)
        if type(SendChatMessage)=="function" and q:WithQuest(r.id,true) then
            pcall(SendChatMessage,"{GroupGains} shared ["..title.."] with you automatically.","PARTY")
            return true
        end
        return
    end
    local entry=self.queue[1]
    if not entry then return end
    if entry.expires<now or entry.signature~=signature or (self.suppressed[entry.id] or 0)>now then table.remove(self.queue,1);return end
    if now<entry.at then return end
    if not q:WithQuest(entry.id,false) then
        if now<entry.at+5 then return end -- allow QUEST_ACCEPTED to precede the log update
        table.remove(self.queue,1);return
    end
    table.remove(self.queue,1);self.serial=self.serial+1
    local nonce=tostring(math.floor(now*1000)).."-"..self.serial
    self.request={id=entry.id,nonce=nonce,sentAt=now,expires=now+10,signature=signature,needs={}}
    if not self:Send("Q;"..entry.id..";"..nonce..";") then self.request=nil end
    return true
end
