local _,C=...
C.Social={prefix="GROUPGAINS2",channelName="GroupGainsCompanions",peers={},queue={},lastBroadcast=-1000,lastInbound={}}
local M=C.Social
function M:Enabled()
    local s=C.State.data.settings
    return s.guild or s.friends or s.everyone
end
function M:Blocked()
    return (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance())
end
function M:Packet()
    local chapter,part=C.State:Current()
    local done,total=C.State:Progress(part)
    return table.concat({"2",C.Guide.revision,chapter.id,part.id,done==total and "1" or "0",tostring(C.State.facts.level or 1),C.State.data.settings.everyone and "1" or "0"},";")
end
function M:IsFriend(sender)
    local friends=C.API:Friends()
    local short=sender:match("^[^-]+")
    local realm=sender:match("^[^-]+%-(.+)$")
    local own=(C.Call(GetNormalizedRealmName) or C.Call(GetRealmName) or ""):gsub("%s","")
    return friends[sender] or ((not realm or realm==own) and friends[short]) or false
end
function M:ChannelID()
    local id,name=C.Call(GetChannelName,self.channelName)
    if not C.Safe(name) then return nil end
    if type(id)=="number" and id>0 and type(name)=="string" and name:lower()==self.channelName:lower() then return id end
end
function M:LeaveEveryoneChannel()
    if self.joinRequested or self.channelOwned then C.Call(LeaveChannelByName,self.channelName) end
    self.joinRequested=nil;self.channelOwned=nil
end
function M:SyncChannel()
    if not C.State.data.settings.everyone then
        self:LeaveEveryoneChannel();return nil
    end
    if self:Blocked() or self.channelFailure then return nil end
    local id=self:ChannelID()
    if id then self.channelOwned=true;self.everyoneStatus="Channel joined; reach depends on your realm.";return id end
    if type(JoinTemporaryChannel)~="function" or type(GetChannelName)~="function" or type(LeaveChannelByName)~="function" then
        self.channelFailure=true;self.everyoneStatus="Everyone channel unavailable in this client. Party/raid matching remains available.";return nil
    end
    if not self.joinRequested then
        self.joinRequested=C.Now()
        local ok=pcall(JoinTemporaryChannel,self.channelName)
        if not ok then self.channelFailure=true;self.everyoneStatus="The client declined the Everyone channel.";return nil end
        self.everyoneStatus="Joining the opt-in Group Gains channel..."
    elseif C.Now()-self.joinRequested>15 then
        self.everyoneStatus="Everyone channel did not join. Toggle Everyone off/on to retry."
    end
    return nil
end
function M:SetAudience(audience,enabled)
    if audience~="guild" and audience~="friends" and audience~="everyone" then return end
    C.State.data.settings[audience]=enabled==true
    -- Opting out stops queued traffic immediately and removes cached matches.
    self.queue={};self.peers={};self.lastInbound={}
    if audience=="everyone" then
        self.channelFailure=nil;self.everyoneStatus=nil
        if not enabled then self:LeaveEveryoneChannel() end
    end
    self:SyncChannel()
    if self:Enabled() then self:Announce() else self.pending=false end
    if C.UI then C.UI:RenderMatches() end
end
function M:Queue(channel,target,packet)
    local s=C.State.data.settings
    local allowed=channel=="GUILD" and s.guild or channel=="WHISPER" and s.friends or
        (channel=="PARTY" or channel=="RAID" or channel=="CHANNEL") and s.everyone
    if not allowed or #self.queue>=100 then return end
    self.queue[#self.queue+1]={channel=channel,target=target,packet=packet or self:Packet()}
end
function M:OutgoingAllowed(m)
    local s=C.State.data.settings
    if m.channel=="GUILD" then return s.guild and IsInGuild and IsInGuild() end
    if m.channel=="WHISPER" then return s.friends and self:IsFriend(m.target) end
    if m.channel=="PARTY" or m.channel=="RAID" then return s.everyone and IsInGroup and IsInGroup() end
    if m.channel=="CHANNEL" then
        if not s.everyone or self.channelFailure then return false end
        local id=self:ChannelID()
        if id then m.target=tostring(id);return true end
    end
    return false
end
function M:Tick()
    self:SyncChannel()
    if not self:Enabled() then self.queue={};return end
    if self:Blocked() then return end
    if C_ChatInfo and C.Call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)==true then return end
    local m
    repeat m=table.remove(self.queue,1) until not m or self:OutgoingAllowed(m)
    if not m or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,self.prefix,m.packet,m.channel,m.target)
    if not C.Safe(result) then return end
    local results=Enum and Enum.SendAddonMessageResult
    local success=results and results.Success or 0
    if ok and C.Safe(result) and (result==success or result==true) then
        self.lastError=nil
        if m.channel=="CHANNEL" then self.everyoneStatus="Sharing with opted-in Group Gains users reachable on this channel." end
        return
    end
    self.lastError="The game declined a companion message."
    if m.channel=="CHANNEL" then
        local transient=results and (result==results.AddonMessageThrottle or result==results.ChannelThrottle or result==results.AddOnMessageLockdown)
        if not ok or not transient then
            -- No public-chat fallback or attempt to bypass a rejected transport.
            self.channelFailure=true;self.everyoneStatus="The client does not allow this Everyone channel. Guild/friends and opted-in party/raid still work."
            self:LeaveEveryoneChannel()
        end
    end
end
function M:Announce()
    if not self:Enabled() then return end
    if self:Blocked() then self.pending=true;return end
    local now=C.Now()
    if now-self.lastBroadcast<60 then self.pending=true;return end
    self.lastBroadcast=now;self.pending=false
    local s=C.State.data.settings
    local packet=self:Packet()
    if s.guild and IsInGuild and IsInGuild() then self:Queue("GUILD",nil,packet) end
    if s.friends then
        local names={}
        for name in pairs(C.API:Friends()) do names[#names+1]=name end
        table.sort(names)
        for i=1,math.min(#names,40) do
            local index=((self.friendOffset or 0)+i-1)%#names+1
            self:Queue("WHISPER",names[index],packet)
        end
        if #names>0 then self.friendOffset=((self.friendOffset or 0)+40)%#names end
    end
    if s.everyone then
        if IsInRaid and IsInRaid() then self:Queue("RAID",nil,packet)
        elseif IsInGroup and IsInGroup() then self:Queue("PARTY",nil,packet) end
        if self:SyncChannel() then self:Queue("CHANNEL",nil,packet) end
    end
end
function M:Allowed(channel,sender,localID,channelName,broadConsent)
    local s=C.State.data.settings
    if channel=="GUILD" then return s.guild and IsInGuild and IsInGuild() end
    if channel=="WHISPER" then return s.friends and self:IsFriend(sender) end
    if not s.everyone or not broadConsent then return false end
    if channel=="PARTY" or channel=="RAID" then return IsInGroup and IsInGroup() end
    if channel=="CHANNEL" and not self.channelFailure then
        local id=self:ChannelID()
        if not id or localID~=id then return false end
        return type(channelName)=="string" and channelName:lower()==self.channelName:lower()
    end
    return false
end
function M:Receive(prefix,message,channel,sender,target,zoneChannelID,localID,channelName)
    if not self:Enabled() or self:Blocked() then return end
    if not C.Safe(prefix) or not C.Safe(message) or not C.Safe(channel) or not C.Safe(sender) or not C.Safe(localID) or not C.Safe(channelName) then return end
    if prefix~=self.prefix or type(message)~="string" or #message>230 or type(sender)~="string" or #sender>100 then return end
    local version,revision,chapter,part,complete,level,broad=message:match("^(%d+);([a-f0-9]+);([%w%-]+);([a-f0-9]+);([01]);(%d+);([01])$")
    if version~="2" or revision~=C.Guide.revision or not C.State.parts[part] or C.State.parts[part].chapterId~=chapter then return end
    if not self:Allowed(channel,sender,localID,channelName,broad=="1") then return end
    level=tonumber(level)
    if not level or level<1 or level>100 then return end
    local me=C.API:Character()
    if sender==me.name or sender==me.name.."-"..me.realm:gsub("%s","") then return end
    local now=C.Now()
    if now-(self.lastInbound[sender] or -1000)<5 then return end
    local count=0
    for _ in pairs(self.peers) do count=count+1 end
    if count>=200 and not self.peers[sender] then return end
    self.lastInbound[sender]=now
    self.peers[sender]={name=sender,partId=part,chapterId=chapter,level=level,complete=complete=="1",seen=now,channel=channel,localID=localID,channelName=channelName,broadConsent=broad=="1"}
    -- Never relay a peer's data or answer a broadcast with another broadcast.
    if C.UI then C.UI:RenderMatches() end
end
function M:Matches()
    local result={}
    for name,p in pairs(self.peers) do
        if C.Now()-p.seen>300 or not self:Allowed(p.channel,name,p.localID,p.channelName,p.broadConsent) then
            self.peers[name]=nil;self.lastInbound[name]=nil
        elseif C.State:Adjacent(p.partId) then result[#result+1]=p end
    end
    table.sort(result,function(a,b)return a.name<b.name end)
    return result
end
function M:Start()
    if C_ChatInfo then C.Call(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix) end
    self:SyncChannel();self:Announce()
    C_Timer.NewTicker(2,function()
        self:Tick()
        if self.pending and C.Now()-self.lastBroadcast>=60 then self:Announce() end
    end)
    C_Timer.NewTicker(120,function()
        self:Matches()
        if self:Enabled() then self:Announce() end
        if C.UI then C.UI:RenderMatches() end
    end)
end
