local _,C=...
C.Social={prefix="GROUPGAINS2",channelName="GroupGainsCompanions",peers={},queue={},lastBroadcast=-1000,lastInbound={},lastReply={}}
local M=C.Social
function M:Enabled()
    local s=C.State.data.settings
    return s.guild or s.friends or s.everyone or s.party
end
function M:Blocked()
    return (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance())
end
function M:ChatLocked()
    -- The realm-wide AreOutgoingAddonChatMessagesRestricted flag can remain
    -- true while supported addon transports work. Use the active chat lock
    -- before sending, then honor the actual SendAddonMessage result.
    return C_ChatInfo and C.Call(C_ChatInfo.InChatMessagingLockdown)==true
end
function M:Packet()
    local chapter,part=C.State:Current()
    local done,total=C.State:Progress(part)
    return table.concat({"2",C.Guide.revision,chapter.id,part.id,done==total and "1" or "0",tostring(C.State.facts.level or 1),C.State.data.settings.everyone and "1" or "0"},";")
end
function M:FriendNames()
    local now=C.Now()
    if self.friendsAt~=now or not self.friendNames then
        self.friendNames=C.API:Friends();self.friendsAt=now
    end
    return self.friendNames
end
function M:IsFriend(sender)
    local friends=self:FriendNames()
    local key=C.API:PlayerKey(sender)
    if not key then return false end
    for name in pairs(friends) do
        if C.API:PlayerKey(name)==key then return true end
    end
    return false
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
    if audience~="guild" and audience~="friends" and audience~="everyone" and audience~="party" then return end
    C.State.data.settings[audience]=enabled==true
    -- Opting out stops queued traffic immediately and removes cached matches.
    self.queue={};self.peers={};self.lastInbound={};self.lastReply={};self.search=nil;self.searchNotice=nil;self.requestedSearch=nil
    if audience=="party" then
        self.partySearchPending=nil
        if enabled then self.groupSignature=nil;self:GroupChanged() end
    end
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
        (channel=="PARTY" or channel=="RAID") and s.party or channel=="CHANNEL" and s.everyone
    if channel=="GUILD" and self:GuildPeekActive() and packet=="Q;"..self.search.nonce..";"..self:Packet() then allowed=true end
    if not allowed or #self.queue>=100 then return end
    if packet and packet:sub(1,2)=="Q;" then
        for _,queued in ipairs(self.queue) do
            local sameTarget=queued.target==target or channel=="WHISPER" and C.API:PlayerKey(queued.target)==C.API:PlayerKey(target)
            if queued.channel==channel and sameTarget and queued.packet:sub(1,2)=="Q;" then queued.packet=packet;return end
        end
    end
    self.queue[#self.queue+1]={channel=channel,target=target,packet=packet or self:Packet()}
end
function M:OutgoingAllowed(m)
    local s=C.State.data.settings
    if m.channel=="GUILD" then return (s.guild or self:GuildPeekActive() and m.packet:find("Q;"..self.search.nonce..";",1,true)==1) and IsInGuild and IsInGuild() end
    if m.channel=="WHISPER" then return s.friends and not C.API:IsIgnored(m.target) and self:IsFriend(m.target) end
    if m.channel=="PARTY" or m.channel=="RAID" then return s.party and IsInGroup and IsInGroup() end
    if m.channel=="CHANNEL" then
        if not s.everyone or self.channelFailure then return false end
        local id=self:ChannelID()
        if id then m.target=tostring(id);return true end
    end
    return false
end
function M:Tick()
    if C.AutoShare and C.AutoShare:Tick() then return end
    if C.PartyProgress and C.PartyProgress:Pump() then return end
    self:SyncChannel()
    if not self:Enabled() and not self:GuildPeekActive() then self.queue={};return end
    if self:Blocked() then return end
    if self:ChatLocked() then return end
    if C.Now()-(self.lastSend or -1000)<2 then return end
    local m
    repeat m=table.remove(self.queue,1) until not m or self:OutgoingAllowed(m)
    if not m then return end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then self.lastError="Addon messaging is unavailable in this client.";return end
    self.lastSend=C.Now()
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,self.prefix,m.packet,m.channel,m.target)
    if not C.Safe(result) then self.lastError="The game did not provide a readable addon-message result.";return end
    local results=Enum and Enum.SendAddonMessageResult
    local success=results and results.Success or 0
    if ok and C.Safe(result) and (result==success or result==true) then
        self.lastError=nil
        if m.channel=="CHANNEL" then self.everyoneStatus="Sharing with opted-in Group Gains users reachable on this channel." end
        return
    end
    local reason=ok and "unknown result" or "API error"
    if ok and type(result)=="number" then
        reason=tostring(result)
        for name,value in pairs(results or {}) do if value==result then reason=name;break end end
    end
    self.lastError="The game declined a "..m.channel.." companion message ("..reason..")."
    if m.channel=="CHANNEL" then
        local transient=results and (result==results.AddonMessageThrottle or result==results.ChannelThrottle or result==results.AddOnMessageLockdown)
        if not ok or not transient then
            -- No public-chat fallback or attempt to bypass a rejected transport.
            self.channelFailure=true;self.everyoneStatus="The client does not allow this Everyone channel. Guild/friends and opted-in party/raid still work."
            self:LeaveEveryoneChannel()
        end
    end
end
function M:FanOut(packet,partyOnly)
    local s=C.State.data.settings
    if s.party then
        if IsInRaid and IsInRaid() then self:Queue("RAID",nil,packet)
        elseif IsInGroup and IsInGroup() then self:Queue("PARTY",nil,packet) end
    end
    if partyOnly then return end
    if s.guild and IsInGuild and IsInGuild() then self:Queue("GUILD",nil,packet) end
    if s.friends then
        local names={}
        for name in pairs(self:FriendNames()) do names[#names+1]=name end
        table.sort(names)
        for i=1,math.min(#names,40) do
            local index=((self.friendOffset or 0)+i-1)%#names+1
            self:Queue("WHISPER",names[index],packet)
        end
        if #names>0 then self.friendOffset=((self.friendOffset or 0)+40)%#names end
    end
    if s.everyone and self:SyncChannel() then self:Queue("CHANNEL",nil,packet) end
end
function M:Announce()
    if not self:Enabled() then return end
    if self:Blocked() then self.pending=true;return end
    local now=C.Now()
    if now-self.lastBroadcast<60 then self.pending=true;return end
    self.lastBroadcast=now;self.pending=false
    self:FanOut(self:Packet())
end
function M:SearchRemaining()
    return math.max(0,8-(C.Now()-(self.lastSearch or -1000)))
end
function M:GuildPeekActive()
    return self.search and self.search.scope=="guild" and C.Now()<(self.search.deadline or 0) and C.Call(IsInGuild)==true
end
function M:RequestSearch(scope)
    if self:SearchRemaining()>0 then self.requestedSearch={scope=scope};return false end
    self.requestedSearch=nil
    return self:SearchNow(scope)
end
function M:SearchNow(partyOnly)
    local guildOnly=partyOnly=="guild"
    if guildOnly and not C.Call(IsInGuild) then self.searchNotice="You are not in a guild.";return false end
    if not guildOnly and not self:Enabled() then self.searchNotice="Matching is off. Enable Party, Guild or Friends to search.";return false end
    if self:Blocked() then self.searchNotice="Search pauses during combat and instances.";return false end
    if self:ChatLocked() then self.searchNotice=nil;return false end
    local now=C.Now()
    if self:SearchRemaining()>0 then return false end
    self.nextAutomaticSearch=now+60
    if not partyOnly then self.lastBroadcast=now;self.pending=false end
    self.lastSearch=now;self.searchNotice=nil;self.lastError=nil;self.friendNames=nil
    if not partyOnly or guildOnly then self.routeSearchPending=nil;self.partySearchPending=nil end
    self.searchSerial=(self.searchSerial or 0)+1
    local nonce=tostring(now).."-"..self.searchSerial
    self.search={nonce=nonce,started=now,replies={},scope=guildOnly and "guild" or nil,deadline=now+20}
    -- Replace stale heartbeats/old searches; never relay somebody else's state.
    local pending=self.queue;self.queue={}
    local packet="Q;"..nonce..";"..self:Packet()
    for _,queued in ipairs(pending) do
        if queued.packet:sub(1,2)=="Q;" and not guildOnly then
            queued.packet=packet
            self.queue[#self.queue+1]=queued
        elseif queued.packet:sub(1,2)=="R;" then self.queue[#self.queue+1]=queued end
    end
    if guildOnly then self:Queue("GUILD",nil,packet) else self:FanOut(packet,partyOnly) end
    self.search.targets=#self.queue
    self.search.deadline=now+math.max(12,#self.queue*2+8)
    if #self.queue==0 then self.searchNotice="No reachable players in your enabled audiences. Friends must be online in the same WoW version, realm and faction." end
    self:Tick()
    if C.UI then C.UI:RenderMatches() end
    return true
end
function M:RouteChanged()
    self.requestedSearch=nil
    self.routeSearchPending=self:Enabled() or nil
    self.search=nil;self.searchNotice=nil
    -- Drop outdated route announcements; replies remain bounded by their nonce.
    local pending=self.queue;self.queue={}
    for _,message in ipairs(pending) do
        if message.packet:sub(1,2)=="R;" then self.queue[#self.queue+1]=message end
    end
    self:CheckRouteSearch()
    if C.UI then C.UI:RenderMatches() end
end
function M:CheckRouteSearch()
    if self.requestedSearch and self:SearchRemaining()==0 and not self:Blocked() and not self:ChatLocked() then
        local request=self.requestedSearch;self.requestedSearch=nil;self:SearchNow(request.scope);return
    end
    if not self:Enabled() then self.routeSearchPending=nil;return end
    if self.routeSearchPending and not self:Blocked() and not self:ChatLocked() and self:SearchRemaining()==0 then self:SearchNow() end
end
function M:CanRecommend(name,group)
    return not C.API:IsIgnored(name) and not (group or C.API:GroupMembers())[C.API:PlayerKey(name)]
end
function M:SearchStatus()
    if self:Blocked() then return "Search pauses during combat and instances." end
    if self:ChatLocked() then return "Search pauses while the game's chat messaging lock is active." end
    if self.requestedSearch then return "Searching in "..self:SearchRemaining().."s · eight-second search cooldown." end
    if self.routeSearchPending then return "Chapter/part changed · searching in "..self:SearchRemaining().."s." end
    if self.searchNotice then return self.searchNotice end
    if self.lastError then return self.lastError end
    if not self.search then return "Find companions now checks your party, guild and online friends, including Battle.net friends." end
    local compatible,other,different=0,0,0
    local group=C.API:GroupMembers()
    for name,status in pairs(self.search.replies) do
        if self:CanRecommend(self.peers[name] and self.peers[name].name or name,group) then
        if status=="different" then different=different+1
        elseif self.peers[name] and C.State:Adjacent(self.peers[name].partId) then compatible=compatible+1
        else other=other+1 end
        end
    end
    local active=C.Now()<self.search.deadline
    local text=(self.search.scope=="guild" and "Guild peek · " or "")..(active and "Searching" or "Search complete").." · "..compatible.." compatible · "..other.." other parts · "..different.." different guide"
    if not active and compatible+other+different==0 then text=text..". No available replies outside your current group and ignore list." end
    return text
end
function M:GroupChanged()
    local signature=""
    local grouped=IsInGroup and IsInGroup()
    if grouped then
        local names={}
        local raid=IsInRaid and IsInRaid()
        for i=1,(C.Call(GetNumGroupMembers) or 1) do
            local name,realm=C.Call(UnitFullName,(raid and "raid" or "party")..i)
            if name then names[#names+1]=name.."-"..(realm or "") end
        end
        table.sort(names);signature=(raid and "raid:" or "party:")..table.concat(names,",")
    end
    if signature==self.groupSignature then return end
    self.groupSignature=signature
    for name,p in pairs(self.peers) do if p.channel=="PARTY" or p.channel=="RAID" then self.peers[name]=nil end end
    self.partySearchPending=grouped and C.State.data.settings.party or nil
end
function M:CheckPartySearch()
    if self.routeSearchPending then self:CheckRouteSearch();return end
    if self.partySearchPending and not self:Blocked() and self:SearchRemaining()==0 then
        if self:SearchNow(true) then self.partySearchPending=nil end
    end
end
function M:Allowed(channel,sender,localID,channelName,broadConsent)
    if C.API:IsIgnored(sender) then return false end
    local s=C.State.data.settings
    if channel=="GUILD" then return s.guild and IsInGuild and IsInGuild() end
    if channel=="WHISPER" then return s.friends and self:IsFriend(sender) end
    if channel=="PARTY" or channel=="RAID" then return s.party and IsInGroup and IsInGroup() end
    if not s.everyone or not broadConsent then return false end
    if channel=="CHANNEL" and not self.channelFailure then
        local id=self:ChannelID()
        if not id or localID~=id then return false end
        return type(channelName)=="string" and channelName:lower()==self.channelName:lower()
    end
    return false
end
function M:Receive(prefix,message,channel,sender,target,zoneChannelID,localID,channelName)
    if (not self:Enabled() and not self:GuildPeekActive()) or self:Blocked() then return end
    if not C.Safe(prefix) or not C.Safe(message) or not C.Safe(channel) or not C.Safe(sender) or not C.Safe(localID) or not C.Safe(channelName) then return end
    if prefix~=self.prefix or type(message)~="string" or #message>255 or type(sender)~="string" or #sender>100 then return end
    local kind,nonce,body=message:match("^([QR]);([%d%-]+);(.+)$")
    if kind then if #nonce>32 then return end;message=body end
    local version,revision,chapter,part,complete,level,broad=message:match("^(%d+);([a-f0-9]+);([%w%-]+);([a-f0-9]+);([01]);(%d+);([01])$")
    if version~="2" then return end
    local peekReply=kind=="R" and channel=="GUILD" and self:GuildPeekActive() and nonce==self.search.nonce and not C.API:IsIgnored(sender)
    if not peekReply and not self:Allowed(channel,sender,localID,channelName,broad=="1") then return end
    level=tonumber(level)
    if not level or level<1 or level>100 then return end
    local me=C.API:Character()
    -- Native messages can alternate between Name and Name-Realm. Share one
    -- identity across audiences, counters and rate limits; retain the native
    -- address for display, whispers and invites. Different realms stay distinct.
    local key=C.API:PlayerKey(sender)
    if not key or key==C.API:PlayerKey(me.name,me.realm) then return end
    local now=C.Now()
    local tracked=0
    for name,at in pairs(self.lastReply) do
        if now-at>300 then self.lastReply[name]=nil else tracked=tracked+1 end
    end
    if tracked>=200 and not self.lastReply[key] then return end
    if kind=="Q" and now-(self.lastReply[key] or -1000)>=15 then
        -- One bounded answer on the same authorized audience. Replies never
        -- cause replies, and no third-party data is forwarded.
        self.lastReply[key]=now
        self:Queue(channel,channel=="WHISPER" and sender or nil,"R;"..nonce..";"..self:Packet())
    end
    local compatible=revision==C.Guide.revision and C.State.parts[part] and C.State.parts[part].chapterId==chapter
    if kind=="R" and self.search and nonce==self.search.nonce and (self.search.scope~="guild" or peekReply) then
        local replies=0;for _ in pairs(self.search.replies) do replies=replies+1 end
        if replies<200 or self.search.replies[key] then self.search.replies[key]=compatible and "known" or "different" end
    end
    if not compatible then if C.UI then C.UI:RenderMatches() end;return end
    if now-(self.lastInbound[key] or -1000)<5 and not peekReply then return end
    local count=0
    for _ in pairs(self.peers) do count=count+1 end
    if count>=200 and not self.peers[key] then return end
    self.lastInbound[key]=now
    local previous=self.peers[key]
    local guildNonce=peekReply and nonce or previous and previous.guildNonce
    local display=previous and previous.name:find("-",1,true) and not sender:find("-",1,true) and previous.name or sender
    self.peers[key]={name=display,partId=part,chapterId=chapter,level=level,complete=complete=="1",seen=now,channel=channel,localID=localID,channelName=channelName,broadConsent=broad=="1",guildNonce=guildNonce}
    if C.UI then C.UI:RenderMatches() end
end
function M:Matches(scope)
    local result={}
    local group=C.API:GroupMembers()
    for name,p in pairs(self.peers) do
        local peek=self.search and self.search.scope=="guild" and p.guildNonce==self.search.nonce and C.Call(IsInGuild)==true
        local allowed=self:Allowed(p.channel,p.name,p.localID,p.channelName,p.broadConsent)
        if C.Now()-p.seen>300 or not (allowed or peek) then
            self.peers[name]=nil;self.lastInbound[name]=nil
        elseif (scope=="guild" and peek or scope~="guild" and allowed) and C.State:Adjacent(p.partId) and self:CanRecommend(p.name,group) then result[#result+1]=p end
    end
    table.sort(result,function(a,b)return a.name<b.name end)
    return result
end
function M:NotifyMatches(count)
    if count==0 then self.waitingForMatches=true
    elseif count>1 and self.waitingForMatches then
        self.waitingForMatches=false
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Group Gains: "..count.." people are leveling just like you! Open See who is leveling.",1,1,0) end
    end
end
function M:CheckAutomaticSearch()
    if not self.nextAutomaticSearch then self.nextAutomaticSearch=C.Now()+60;return end
    if C.Now()<self.nextAutomaticSearch or not self:Enabled() or self:Blocked() or self:ChatLocked() then return end
    -- Finish an ongoing search and its queue, including a temporary guild peek.
    if #self.queue>0 or self.search and C.Now()<(self.search.deadline or 0) then return end
    if self:SearchRemaining()==0 then self:SearchNow() end
end
function M:Start()
    if self.started then return end
    self.started=true
    if C_ChatInfo then C.Call(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix) end
    self.nextAutomaticSearch=C.Now()+60
    self:SyncChannel();self:GroupChanged()
    -- Ask for replies immediately, even when the tracker was already open.
    -- Keep the request pending if the client is not ready to send at login.
    self.routeSearchPending=self:Enabled() or nil
    self:CheckRouteSearch()
    C_Timer.NewTicker(2,function()
        self:CheckRouteSearch()
        self:CheckPartySearch()
        self:Tick()
        self:CheckAutomaticSearch()
        if self.pending and C.Now()-self.lastBroadcast>=60 then self:Announce() end
        if C.Companions then C.Companions:KeepRoster() end
        if self.search and C.UI then C.UI:RenderMatches() end
    end)
end
