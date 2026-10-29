local _,C=...
-- Original implementation: native quest sharing, not simulated clicks or NPC automation.
C.QuestShare={prefix="GGSHARE1",offers={},lastOffer={}}
local Q=C.QuestShare
function Q:Clock()
    -- Fractional elapsed time ensures the full five seconds between offers.
    return C.Call(GetTime) or C.Now()
end
function Q:PartySignature()
    if not C.Call(IsInGroup) or C.Call(IsInRaid) then return nil end
    local names={};for name in pairs(C.API:GroupMembers()) do names[#names+1]=name end
    table.sort(names)
    if #names>0 then return table.concat(names,";") end
end
function Q:Blocked()
    return C.Call(InCombatLockdown)==true or C_ChatInfo and C.Call(C_ChatInfo.InChatMessagingLockdown)==true
end
function Q:ExpandedLog(fn)
    -- Native log indexes omit collapsed sections on some clients. Open them
    -- only during this synchronous read/share, then restore the user's view.
    local collapsed,ordinal={},0
    local canExpand=type(ExpandQuestHeader)=="function" and type(CollapseQuestHeader)=="function" and type(GetQuestLogTitle)=="function"
    local previous=C.Call(GetQuestLogSelection)
    if canExpand then
        for i=1,math.min(C.Call(GetNumQuestLogEntries) or 0,1000) do
            local _,_,_,header,closed=C.Call(GetQuestLogTitle,i)
            if C.Safe(header) and header then ordinal=ordinal+1;if C.Safe(closed) and closed then collapsed[ordinal]=true end end
        end
    end
    if next(collapsed) then C.Call(ExpandQuestHeader,0) end
    local ok,value=pcall(fn)
    if next(collapsed) then
        local headers={};ordinal=0
        for i=1,math.min(C.Call(GetNumQuestLogEntries) or 0,1000) do
            local _,_,_,header=C.Call(GetQuestLogTitle,i)
            if C.Safe(header) and header then ordinal=ordinal+1;if collapsed[ordinal] then headers[#headers+1]=i end end
        end
        for i=#headers,1,-1 do C.Call(CollapseQuestHeader,headers[i]) end
        if type(previous)=="number" and previous>0 then C.Call(SelectQuestLogEntry,previous) end
    end
    return ok,value
end
function Q:LogIndex(id)
    local api=C_QuestLog or {}
    local index=C.Call(api.GetLogIndexForQuestID or GetQuestLogIndexByID,id)
    if type(index)~="number" or index<1 then return end
    local info=C.Call(api.GetInfo,index)
    if info and C.Safe(info.questID) and C.Safe(info.isHeader) then
        if not info.isHeader and info.questID==id then return index end
    else
        local _,_,_,header,_,_,_,questID=C.Call(GetQuestLogTitle,index)
        if C.Safe(header) and C.Safe(questID) and not header and questID==id then return index end
    end
end
function Q:WithQuest(id,share,expanded)
    if not expanded then
        local ok,value=self:ExpandedLog(function()return self:WithQuest(id,share,true)end)
        return ok and value==true
    end
    if type(SelectQuestLogEntry)~="function" or type(GetQuestLogPushable)~="function" then return false end
    local index=self:LogIndex(id);if not index then return false end
    local previous=C.Call(GetQuestLogSelection)
    local ok,eligible=pcall(function()
        SelectQuestLogEntry(index)
        local pushable=C.Call(GetQuestLogPushable)
        if pushable~=true and pushable~=1 then return false end
        if share then
            -- Announce only the quest currently being offered; no full-log broadcast.
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                pcall(C_ChatInfo.SendAddonMessage,self.prefix,"1;"..id,"PARTY")
                if C.Social then C.Social.lastSend=C.Now() end
            end
            if QuestLogPushQuest()==false then return false end
            self.lastSharedAt=self:Clock()
            if C.AutoShare then C.AutoShare:Suppress(id) end
        end
        return true
    end)
    if type(previous)=="number" and previous>0 then C.Call(SelectQuestLogEntry,previous) end
    return ok and eligible==true
end
function Q:Candidates()
    local ok,ids=self:ExpandedLog(function()
        local result={}
        for id in pairs(C.API:Capture(true).active) do
            if self:WithQuest(id,false,true) then result[#result+1]=id end
        end
        table.sort(result,function(a,b)return (self:LogIndex(a) or 10000)<(self:LogIndex(b) or 10000)end)
        while #result>40 do table.remove(result) end
        return result
    end)
    return ok and ids or {}
end
function Q:UpdateButton()
    if C.UI and C.UI.share then C.UI.share:SetText(self.session and "Stop Sharing" or "Share Quests") end
end
function Q:Cancel(message)
    local active=self.session~=nil;self.session=nil;self:UpdateButton()
    if active and message then C.Print(message) end
end
function Q:StartSharing()
    if self.session then return false end
    local signature=self:PartySignature()
    if not signature then C.Print("Join a party to share quests.");return false end
    if self:Blocked() then C.Print("Quest sharing is unavailable during combat or a chat lock.");return false end
    if C.Now()-(self.lastStarted or -1000)<30 then C.Print("Please wait before starting another quest-sharing sequence.");return false end
    if type(QuestLogPushQuest)~="function" or type(SendChatMessage)~="function" then C.Print("Native quest sharing is unavailable in this client.");return false end
    local quests=self:Candidates()
    if #quests==0 then C.Print("There are no shareable quests in your quest log.");return false end
    local ok,result=pcall(SendChatMessage,"I'm about to share the quests I have. Sharing starts in 5 seconds, with 5 seconds to accept each quest. {GroupGains}","PARTY")
    if not ok or result==false then C.Print("The party announcement was blocked; quest sharing did not start.");return false end
    self.lastStarted=C.Now()
    self.session={quests=quests,signature=signature,nextAt=self:Clock()+5,index=1,attempted=0}
    self:UpdateButton();return true
end
function Q:Tick()
    for name,offer in pairs(self.offers) do if C.Now()>offer.expires then self.offers[name]=nil end end
    if C.AutoShare then C.AutoShare:Tick() end
    local s=self.session
    if not s then return end
    if s.signature~=self:PartySignature() then self:Cancel("Party changed; quest sharing stopped.");return end
    if self:Blocked() then self:Cancel("Combat or a chat lock stopped quest sharing.");return end
    if self:Clock()<s.nextAt or self:Clock()-(self.lastSharedAt or -1000)<5 then return end
    local id=s.quests[s.index]
    if not id then self:Cancel("Quest sharing finished. Offered "..s.attempted.." quests; the game checks each recipient's eligibility.");return end
    if self:WithQuest(id,true) then s.attempted=s.attempted+1 end
    s.index=s.index+1;s.nextAt=self:Clock()+5
end
function Q:Receive(prefix,message,channel,sender)
    if not C.Safe(prefix) or not C.Safe(message) or not C.Safe(channel) or not C.Safe(sender) then return end
    if prefix~=self.prefix or channel~="PARTY" or type(message)~="string" or #message>20 then return end
    local key=C.API:PlayerKey(sender)
    if not key or not C.API:GroupMembers()[key] or C.API:IsIgnored(sender) then return end
    local own=C.API:Character();if key==C.API:PlayerKey(own.name,own.realm) then return end
    local id=tonumber(message:match("^1;(%d+)$"))
    if not id or id<1 or id>10000000 or C.Now()-(self.lastOffer[key] or -1000)<4 then return end
    self.lastOffer[key]=C.Now();self.offers[key]={id=id,expires=C.Now()+12}
    self:TryAccept()
end
function Q:OfferingPlayer()
    -- Only identify the actual player offering this dialog, never the target.
    for _,unit in ipairs({"questnpc","npc"}) do
        if C.Call(UnitIsPlayer,unit)==true then
            local name,realm=C.Call(UnitFullName,unit)
            local key=C.API:PlayerKey(name,realm)
            if key and C.API:GroupMembers()[key] then return key end
        end
    end
end
function Q:QuestDetail()
    self.pending=nil
    local id=C.Call(GetQuestID)
    if type(id)~="number" then return end
    local key=self:OfferingPlayer()
    if key then
        if C.AutoShare then C.AutoShare:Suppress(id) end
        self.pending={id=id,key=key,expires=C.Now()+12};self:TryAccept()
    end
end
function Q:TryAccept()
    local p=self.pending
    if not p or p.expires<C.Now() or not C.Auto or not C.Auto:Enabled("autoShared") then return end
    local offer=self.offers[p.key]
    if not offer or offer.id~=p.id or offer.expires<C.Now() or not C.API:GroupMembers()[p.key] or C.API:IsIgnored(p.key) then return end
    if self:OfferingPlayer()~=p.key or C.Call(GetQuestID)~=p.id or C.Call(QuestFlagsPVP)==true or type(AcceptQuest)~="function" then return end
    if C.AutoShare then C.AutoShare:Suppress(p.id) end
    self.pending=nil;self.offers[p.key]=nil
    local ok=pcall(AcceptQuest)
    if not ok then C.Print("The game did not allow accepting the shared quest. Use the quest dialog.") end
end
function Q:DungeonKey()
    local inside,kind=C.Call(IsInInstance)
    if not inside or kind~="party" then return end
    local name,_,difficulty,_,_,_,_,id=C.Call(GetInstanceInfo)
    if not C.Safe(id) or not C.Safe(difficulty) or not C.Safe(name) then return end
    if id or name then return tostring(id or name)..":"..tostring(difficulty or 0) end
end
function Q:CheckDungeon()
    local key=self:DungeonKey()
    if key~=self.dungeon then
        self.dungeon=key;self.prompted=nil
        self:Cancel("Changed zone; quest sharing stopped.")
        if C.UI and C.UI.sharePrompt then C.UI.sharePrompt:Hide() end
    end
    if not key or self.prompted==key or not self:PartySignature() or self:Blocked() then return end
    self.prompted=key
    if C.UI then C.UI:OfferQuestSharing(key) end
end
function Q:GroupChanged()
    self.offers={};self.lastOffer={};self.pending=nil
    if C.AutoShare then C.AutoShare:Reset() end
    self:Tick();self:CheckDungeon()
end
function Q:Start()
    if C_ChatInfo then C.Call(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix) end
    if C_ChatInfo and C.AutoShare then C.Call(C_ChatInfo.RegisterAddonMessagePrefix,C.AutoShare.prefix) end
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(.5,function()self:Tick()end) end
    self:CheckDungeon()
end
