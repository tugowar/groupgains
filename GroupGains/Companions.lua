local _,C=...
C.Companions={sentAt={},inviteAt={},lineIds={},roster={},message="Hey we're close to the same spot in leveling. Want to group? {GroupGains}"}
local A=C.Companions
function A:Name(name)
    if not C.Safe(name) or type(name)~="string" or #name>100 or name:find("[%s|;]") then return nil end
    if name=="" then return nil end
    if not name:find("-",1,true) then name=name.."-"..(C.Call(GetNormalizedRealmName) or C.Call(GetRealmName) or ""):gsub("%s","") end
    return name:lower(),name
end
function A:Data()
    local s=C.State.data
    if not s.companionAudit then s.companionAudit={people={},events={}} end
    return s.companionAudit
end
function A:Person(name)
    local key,display=self:Name(name);if not key then return end
    local db=self:Data()
    if not db.people[key] then
        local count,oldest,at=0,nil,math.huge
        for id,p in pairs(db.people) do count=count+1;if (p.lastAt or 0)<at then oldest,at=id,p.lastAt or 0 end end
        if count>=200 then db.people[oldest]=nil end
        db.people[key]={name=display,sent=0,received=0,grouped=0}
    end
    return db.people[key],key
end
function A:Record(name,kind)
    local person=self:Person(name);if not person then return end
    person[kind]=(person[kind] or 0)+1;person.lastAt=C.Now()
    local events=self:Data().events
    events[#events+1]={name=person.name,kind=kind,at=C.Now()}
    while #events>200 do table.remove(events,1) end
    if C.UI and C.UI.RenderAudit then C.UI:RenderAudit() end
end
function A:WhisperEvent(event,message,name,lineId)
    if not C.Safe(message) or type(message)~="string" then return end
    local text=message:lower()
    if not text:find("{groupgains}",1,true) and not text:find("{guildgains}",1,true) then return end
    if not self:Name(name) then return end
    if C.Safe(lineId) and type(lineId)=="number" and lineId>0 then
        local key=event..":"..lineId
        if self.lineIds[key] then return end
        local count=0
        for id,at in pairs(self.lineIds) do if C.Now()-at>300 then self.lineIds[id]=nil else count=count+1 end end
        if count>=200 then self.lineIds={} end
        self.lineIds[key]=C.Now()
    end
    -- Never retain the message text, account identities, or unrelated whispers.
    self:Record(name,event=="CHAT_MSG_WHISPER_INFORM" and "sent" or "received")
end
function A:WhisperRemaining(name)
    local key=self:Name(name);if not key then return 0 end
    return math.max(0,30-(C.Now()-(self.sentAt[key] or -1000)))
end
function A:Whisper(name)
    local key=self:Name(name);if not key then return false end
    local eligible=false
    for _,p in ipairs(C.Social:Matches()) do if self:Name(p.name)==key then eligible=true end end
    if not eligible then C.Print("That match has expired. Search again.");return false end
    if self:WhisperRemaining(name)>0 or C.Now()-(self.lastWhisper or -1000)<5 then return false end
    if C.Call(InCombatLockdown) then C.Print("Send your invitation after combat.");return false end
    if C_ChatInfo and C.Call(C_ChatInfo.InChatMessagingLockdown)==true then C.Print("Whispers are currently restricted by the game.");return false end
    local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if type(send)~="function" then C.Print("Whispers are unavailable in this client.");return false end
    -- Only called synchronously by a player's click, never by search or a timer.
    for id,at in pairs(self.sentAt) do if C.Now()-at>=30 then self.sentAt[id]=nil end end
    self.sentAt[key]=C.Now();self.lastWhisper=C.Now()
    local ok,result=pcall(send,self.message,"WHISPER",nil,name)
    if not ok or not C.Safe(result) or result==false then C.Print("The game declined this whisper.");return false end
    -- Count on CHAT_MSG_WHISPER_INFORM, not on the send attempt.
    return true
end
function A:GroupChanged()
    local current={}
    local myName,myRealm=C.Call(UnitFullName,"player")
    if not C.Safe(myRealm) then myRealm=nil end
    local own=myName and self:Name(myName..(myRealm and myRealm~="" and "-"..myRealm:gsub("%s","") or ""))
    if C.Call(IsInGroup) then
        local raid=C.Call(IsInRaid)
        for i=1,math.min(C.Call(GetNumGroupMembers) or 0,40) do
            local unit=(raid and "raid" or "party")..i
            if not C.Call(UnitIsUnit,unit,"player") then
                local name,realm=C.Call(UnitFullName,unit)
                if C.Safe(realm) and type(name)=="string" then
                    local key,display=self:Name(name..(realm and realm~="" and "-"..realm:gsub("%s","") or ""))
                    if key and key~=own then current[key]=display end
                end
            end
        end
    end
    local db=self:Data()
    -- Persist the active membership briefly so /reload doesn't count a new group.
    local prior=self.roster
    if not self.rosterInitialized then
        prior=C.Now()-(db.rosterAt or 0)<600 and (db.roster or {}) or {}
        self.rosterInitialized=true
    end
    for key,name in pairs(current) do
        if not prior[key] then self:Record(name,"grouped") end
    end
    self.roster=current;db.roster=current;db.rosterAt=C.Now()
end
function A:CanInvite(name)
    local key=self:Name(name)
    if not key or C.Call(InCombatLockdown) then return false end
    if C.Now()-(self.inviteAt[key] or -1000)<30 or C.Now()-(self.lastInvite or -1000)<5 then return false end
    local api=C_PartyInfo or {}
    if type(api.InviteUnit or InviteUnit)~="function" then return false end
    if type(api.CanInvite)=="function" and C.Call(api.CanInvite)~=true then return false end
    if type(api.CanInvite)~="function" and C.Call(IsInGroup) and not C.Call(UnitIsGroupLeader,"player") and not C.Call(UnitIsGroupAssistant,"player") then return false end
    if C.Call(api.IsPartyFull)==true then return false end
    -- Revalidate live matches: grouped, ignored and stale players are excluded.
    for _,p in ipairs(C.Social:Matches()) do if self:Name(p.name)==key then return true end end
    return false
end
function A:Invite(name)
    if not self:CanInvite(name) then return false end
    local key=self:Name(name)
    for id,at in pairs(self.inviteAt) do if C.Now()-at>=30 then self.inviteAt[id]=nil end end
    self.inviteAt[key]=C.Now();self.lastInvite=C.Now()
    -- Called directly from the row button, never from discovery or a timer.
    -- Use InviteUnit, retaining the game's normal confirmation and eligibility.
    local invite=C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
    local ok,result=pcall(invite,name)
    if not ok or not C.Safe(result) or result==false then C.Print("The game could not send that group invite.");return false end
    return true
end
function A:KeepRoster()
    if self.rosterInitialized then self:Data().rosterAt=C.Now() end
end
function A:ClearAudit()
    C.State.data.companionAudit={people={},events={},roster=self.roster,rosterAt=C.Now()}
    if C.UI and C.UI.RenderAudit then C.UI:RenderAudit() end
end
function A:SaveLinkKey(value)
    if type(value)~="string" or #value>256 or value:find("[%s%c|]") then return false end
    C.State.data.guideLinkKey=value~="" and value or nil
    return true
end
