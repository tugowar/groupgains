local _,C=...
-- Only the hovered task is requested. Replies contain the sender's own state,
-- stay within the current party/raid, and share discovery's two-second budget.
C.PartyProgress={prefix="GGPROGRESS1",queue={},cache={},lastReply={},requests={},serial=0}
local P=C.PartyProgress
function P:Enabled()
    return C.State.data.settings.party and C.Call(IsInGroup)==true
end
function P:Roster()
    local roster={}
    if not C.Call(IsInGroup) then return roster end
    local me=C.API:Character();local own=C.API:PlayerKey(me.name,me.realm)
    local raid=C.Call(IsInRaid)
    for i=1,(raid and 40 or 4) do
        local unit=(raid and "raid" or "party")..i
        local name,realm=C.Call(UnitFullName,unit)
        local key=C.API:PlayerKey(name,realm)
        if key and key~=own and not C.API:IsIgnored(key) then
            roster[key]={name=C.Text(name)..(realm and realm~="" and "-"..C.Text(realm) or ""),online=C.Call(UnitIsConnected,unit)~=false}
        end
    end
    return roster
end
function P:RefreshRoster()
    local roster=self:Roster();local keys={}
    for key in pairs(roster) do keys[#keys+1]=key end;table.sort(keys)
    local signature=table.concat(keys,";")
    if signature~=self.rosterSignature or not self:Enabled() then
        self.rosterSignature=signature;self.queue={};self.cache={};self.lastReply={};self.requests={};self.request=nil;self.lastQuery=nil
    end
    self.roster=roster;return roster
end
function P:LocalStatus(task)
    if not task then return "N",0,0 end
    if C.State:Done(task) then return "C",0,0 end
    if C.State.data.overrides[task.id]==false then return "M",0,0 end
    if task.questId then
        if not C.State.facts.active[task.questId] then return "S",0,0 end
        if task.kind=="turnin" and C.State.facts.ready[task.questId] then return "T",0,0 end
        local objective=C.State:MatchedObjective(task)
        if objective and type(objective.count)=="number" and type(objective.required)=="number" and objective.required>0 and objective.required<=1000000 and objective.count>=0 then
            return "P",math.floor(math.min(objective.count,objective.required)),math.floor(objective.required)
        end
        return "I",0,0
    end
    return "S",0,0
end
function P:Describe(code,count,required)
    if code=="P" then return tostring(count).."/"..tostring(required) end
    return ({C="Completed",M="Marked incomplete",S="Not started",T="Ready to turn in",I="In progress",N="Not in their guide",X="Different guide version"})[code] or "Progress unavailable"
end
function P:Watch(taskId)
    if self.watched~=taskId then
        self.watched=taskId
        self.requests={};self.request=nil
        -- Never send an old hover request after the pointer moves away.
        for i=#self.queue,1,-1 do if self.queue[i].kind=="Q" then table.remove(self.queue,i) end end
    end
end
function P:Enqueue(entry)
    for i,queued in ipairs(self.queue) do
        if queued.key==entry.key then self.queue[i]=entry;return end
    end
    if #self.queue<41 then self.queue[#self.queue+1]=entry end
end
function P:Pump()
    local roster=self:RefreshRoster()
    if not self:Enabled() then return false end
    local now=C.Now()
    for nonce,request in pairs(self.requests) do if now-request.at>30 then self.requests[nonce]=nil end end
    if self.watched and C.State.tasks[self.watched] and next(roster) and now-(self.lastQuery or -1000)>=5 then
        self.serial=self.serial+1;self.lastQuery=now
        self.request={id=self.watched,nonce=tostring(now).."-"..self.serial,at=now}
        self:Enqueue({kind="Q",key="request",id=self.watched,nonce=self.request.nonce,revision=C.Guide.revision,at=now})
    end
    if C.Social:ChatLocked() or now-(C.Social.lastSend or -1000)<2 then return false end
    local entry
    repeat
        entry=table.remove(self.queue,1)
        if entry and (now-entry.at>20 or entry.kind=="R" and not roster[entry.key] or entry.kind=="Q" and self.watched~=entry.id) then entry=nil end
    until entry or #self.queue==0
    if not entry then return false end
    local packet=table.concat({entry.kind,entry.revision,entry.id,entry.nonce},";")
    if entry.kind=="R" then
        local code,count,required="X",0,0
        if entry.revision==C.Guide.revision then code,count,required=self:LocalStatus(C.State.tasks[entry.id]) end
        packet=packet..";"..code..";"..count..";"..required
    end
    if #packet>255 or not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function" then return false end
    C.Social.lastSend=now
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,self.prefix,packet,C.Call(IsInRaid) and "RAID" or "PARTY")
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    self.sendFailed=not (ok and C.Safe(result) and (result==success or result==true))
    if entry.kind=="Q" and not self.sendFailed then
        self.requests[entry.nonce]={id=entry.id,at=now}
    end
    -- No ordinary-chat fallback or retry loop on a rejected message.
    return true
end
function P:Receive(prefix,message,channel,sender)
    if not C.Safe(prefix) or prefix~=self.prefix or not self:Enabled() then return end
    if not C.Safe(message) or not C.Safe(sender) or not C.Safe(channel) then return end
    if type(message)~="string" or #message>255 or (channel~="PARTY" and channel~="RAID") then return end
    local key=C.API:PlayerKey(sender);local roster=self:RefreshRoster()
    if not key or not roster[key] or not roster[key].online or C.API:IsIgnored(sender) then return end
    local kind,revision,id,nonce,tail=message:match("^([QR]);([a-f0-9]+);([%w%-]+);([%d%-]+)(.*)$")
    if not kind or #revision>32 or #id>32 or #nonce>32 then return end
    local now=C.Now()
    if kind=="Q" then
        if tail~="" or now-(self.lastReply[key] or -1000)<5 then return end
        self.lastReply[key]=now
        self:Enqueue({kind="R",key=key,revision=revision,id=id,nonce=nonce,at=now})
    else
        local request=self.requests[nonce]
        if not request or now-request.at>30 or id~=request.id or id~=self.watched or revision~=C.Guide.revision then return end
        local code,count,required=tail:match("^;([CMSTIPNX]);(%d+);(%d+)$")
        count,required=tonumber(count),tonumber(required)
        if not code or count>1000000 or required>1000000 or count>required or (code=="P" and required<1) or (code~="P" and (count~=0 or required~=0)) then return end
        self.cache[key]={id=id,code=code,count=count,required=required,seen=now}
        if C.UI and C.UI.RefreshTaskTooltip then C.UI:RefreshTaskTooltip() end
    end
end
function P:Lines(task)
    local roster=self:RefreshRoster();local lines={"You: "..self:Describe(self:LocalStatus(task))}
    local keys={};for key in pairs(roster) do keys[#keys+1]=key end;table.sort(keys)
    if #keys==0 then lines[#lines+1]="Not in a party with other players." end
    for _,key in ipairs(keys) do
        local member=roster[key];local cached=self.cache[key];local status
        if not member.online then status="Offline"
        elseif not self:Enabled() then status="Party sharing off"
        elseif cached and cached.id==task.id and C.Now()-cached.seen<=30 then
            status=self:Describe(cached.code,cached.count,cached.required)
            if C.Now()-cached.seen>10 then status=status.." · "..(C.Now()-cached.seen).."s ago" end
        else status="Progress unavailable" end
        lines[#lines+1]=member.name..": "..status
    end
    return lines
end
function P:Start()
    if C_ChatInfo then C.Call(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix) end
end
