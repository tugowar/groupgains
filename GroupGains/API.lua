local _,C=...
C.API={}
local A=C.API
function A:Level()
    local level=C.Call(UnitLevel,"player")
    if type(level)~="number" or level<1 or level>255 or level%1~=0 then level=1 end
    -- PLAYER_LEVEL_UP can precede UnitLevel's update. Keep the event's level
    -- until the normal player API catches up so a queued sync cannot undo it.
    if self.pendingLevel and level>=self.pendingLevel then self.pendingLevel=nil end
    return math.max(level,self.pendingLevel or 0)
end
function A:LevelChanged(level)
    if C.Safe(level) and type(level)=="number" and level>=1 and level<=255 and level%1==0 then
        self.pendingLevel=math.max(level,self.pendingLevel or 0)
        C.State.facts.level=self:Level()
        C.State:Changed(true)
    end
    self:QueueRefresh()
end
function A:Character()
    local name,realm=C.Call(UnitFullName,"player")
    local _,class=C.Call(UnitClass,"player")
    local _,race=C.Call(UnitRace,"player")
    race=race=="Scourge" and "undead" or string.lower(race or "")
    local professions={__array=true}
    if GetProfessions and GetProfessionInfo then
        local indexes={GetProfessions()}
        for _,index in pairs(indexes) do
            local profession,_,rank,_,_,_,skillLine=C.Call(GetProfessionInfo,index)
            if profession and C.Safe(rank) and C.Safe(skillLine) then
                professions[#professions+1]={name=C.Text(profession),rank=rank,skillLine=skillLine}
            end
        end
    end
    return {guid=C.Call(UnitGUID,"player") or "",name=C.Text(name),realm=C.Text(realm or C.Call(GetRealmName)),
        race=race,class=string.lower(class or ""),level=C.Call(UnitLevel,"player") or 1,
        guild=C.Text(C.Call(GetGuildInfo,"player")),professions=professions}
end
function A:Capture(full)
    local facts={active={},completed={},objectives={},ready={},level=self:Level()}
    local api=C_QuestLog or {}
    for _,id in ipairs(C.Call(api.GetAllCompletedQuestIDs) or {}) do
        if C.Safe(id) and type(id)=="number" and C.State.questIds[id] then facts.completed[id]=true end
    end
    if not api.GetAllCompletedQuestIDs and GetQuestsCompleted then
        local completed={};C.Call(GetQuestsCompleted,completed)
        for id,done in pairs(completed) do if done and C.State.questIds[id] then facts.completed[id]=true end end
    end
    local function captureQuest(id,index,complete)
        if C.Safe(id) and type(id)=="number" and id>0 then
            facts.active[id]=true
            facts.ready[id]=C.Call(api.IsComplete,id)==true or complete==true or complete==1
            local objectives={}
            local entries=C.Call(api.GetQuestObjectives,id)
            if not entries and index and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
                entries={}
                for n=1,math.min(C.Call(GetNumQuestLeaderBoards,index) or 0,100) do
                    local text,_,finished=C.Call(GetQuestLogLeaderBoard,n,index)
                    if C.Safe(text) and C.Safe(finished) and type(text)=="string" then
                        local fulfilled,required=text:match("(%d+)%s*/%s*(%d+)%s*$")
                        entries[#entries+1]={text=text,finished=finished==true or finished==1,numFulfilled=tonumber(fulfilled),numRequired=tonumber(required)}
                    end
                end
            end
            for _,o in ipairs(entries or {}) do
                if C.Safe(o.text) and C.Safe(o.finished) and C.Safe(o.numRequired) and C.Safe(o.numFulfilled) then
                    objectives[#objectives+1]={text=C.Text(o.text),finished=o.finished==true,required=o.numRequired,count=o.numFulfilled}
                end
            end
            facts.objectives[id]=objectives
        end
    end
    local count=C.Call(api.GetNumQuestLogEntries) or C.Call(GetNumQuestLogEntries) or 0
    for index=1,math.min(count,1000) do
        local info=C.Call(api.GetInfo,index)
        if info then
            if info and C.Safe(info.isHeader) and not info.isHeader then captureQuest(info.questID,index) end
        else
            local _,_,_,header,_,complete,_,id=C.Call(GetQuestLogTitle,index)
            if C.Safe(header) and not header then captureQuest(id,index,complete) end
        end
    end
    -- Check the visible part and previously active quests by ID as well. A
    -- collapsed or not-yet-refreshed quest-log listing can omit an accepted quest.
    local candidates={}
    for id in pairs(C.State.facts.active or {}) do candidates[id]=true end
    local chapter=C.State:Current()
    for _,part in ipairs(chapter and chapter.parts or {}) do
        for _,task in ipairs(part.tasks) do if task.questId then candidates[task.questId]=true end end
    end
    if full then for id in pairs(C.State.questIds) do candidates[id]=true end end
    for id in pairs(candidates) do
        local index=C.Call(api.GetLogIndexForQuestID or GetQuestLogIndexByID,id)
        if not facts.active[id] and (C.Call(api.IsOnQuest,id)==true or type(index)=="number" and index>0) then
            captureQuest(id,index)
        end
        if C.Call(api.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,id)==true then facts.completed[id]=true end
    end
    return facts
end
function A:Accepted(first,second)
    -- Forever sends questId; Classic variants send questIndex, questId.
    if not C.Safe(first) or not C.Safe(second) then return end
    local id=first
    if second~=nil then id=second end
    if type(id)=="number" and id>0 then
        C.State.facts.active[id]=true
        C.State:Changed(true)
    end
    self:QueueRefresh()
end
function A:RestoreAutomatic(taskId)
    -- Refresh before releasing the override so the checkbox immediately reflects
    -- an already accepted/completed quest, without waiting for another event.
    self:Refresh()
    C.State:Set(taskId,nil)
end
function A:Refresh(full) C.State:ApplyFacts(self:Capture(full)) end
function A:Sync()
    self:Refresh(true)
    local active,overrides=0,0
    for _ in pairs(C.State.facts.active) do active=active+1 end
    for id,value in pairs(C.State.data.overrides) do
        local task=C.State.tasks[id]
        if task and value==false and C.State:Automatic(task) then overrides=overrides+1 end
    end
    C.Print("Quest log synced: "..active.." active quests."..(overrides>0 and " "..overrides.." manual unchecked tasks remain; use A to restore automatic tracking." or ""))
end
function A:QueueRefresh()
    if self.pending then return end
    self.pending=true
    C_Timer.After(0.3,function()self.pending=false;self:Refresh()end)
end
function A:Map(task)
    if InCombatLockdown and InCombatLockdown() then C.Print("Use the map button after combat.");return end
    local point=task.point
    if not point or not point.mapId or not C_Map then C.Print("This task has no verified map coordinates.");return end
    local info=C.Call(C_Map.GetMapInfo,point.mapId)
    if not info or C.Normalize(info.name)~=C.Normalize(point.zoneName) then
        C.Print("Map ID is not verified in this client. "..(point.zoneName or point.zone).." "..string.format("%.1f, %.1f",point.x,point.y)..". Use the guide link.")
        return
    end
    if not point.x or not point.y or point.x<0 or point.x>100 or point.y<0 or point.y>100 then return end
    if C.Navigation then C.Navigation:Set(task) end
end
function A:StartingChapter()
    local mapId=C_Map and C.Call(C_Map.GetBestMapForUnit,"player")
    for _=1,8 do
        if not mapId then break end
        for _,starter in ipairs(C.Guide.starters or {}) do if starter.mapId==mapId then return starter.chapterId end end
        local info=C_Map and C.Call(C_Map.GetMapInfo,mapId)
        mapId=info and C.Safe(info.parentMapID) and info.parentMapID or nil
        if mapId==0 then break end
    end
end
function A:PlayerKey(name,realm)
    if not C.Safe(name) or not C.Safe(realm) or type(name)~="string" or name=="" then return nil end
    local short,qualified=name:match("^([^-]+)%-(.+)$")
    realm=qualified or (type(realm)=="string" and realm~="" and realm) or C.Call(GetNormalizedRealmName) or C.Call(GetRealmName) or ""
    return (short or name):lower().."-"..realm:gsub("%s",""):lower()
end
function A:GroupMembers()
    local names={}
    if not C.Call(IsInGroup) then return names end
    local raid=C.Call(IsInRaid)
    for i=1,(raid and 40 or 4) do
        local name,realm=C.Call(UnitFullName,(raid and "raid" or "party")..i)
        local key=self:PlayerKey(name,realm)
        if key then names[key]=true end
    end
    return names
end
function A:IsIgnored(name)
    local key=self:PlayerKey(name)
    if not key then return true end
    local api=C_FriendList or {}
    if C.Call(api.IsIgnored or IsIgnored,name)==true or C.Call(api.IsOnIgnoredList,name)==true then return true end
    for i=1,math.min(C.Call(api.GetNumIgnores or GetNumIgnores) or 0,500) do
        if self:PlayerKey(C.Call(api.GetIgnoreName or GetIgnoreName,i))==key then return true end
    end
    return false
end
function A:Friends()
    local result={}
    if C_FriendList then
        for i=1,(C.Call(C_FriendList.GetNumFriends) or 0) do
            local f=C.Call(C_FriendList.GetFriendInfoByIndex,i)
            if f and C.Safe(f.connected) and f.connected and C.Safe(f.name) then result[C.Text(f.name)]=true end
        end
    end
    -- Only online WoW characters reachable in this client/region/realm/faction.
    -- Never retain or export BattleTags, account IDs, real names or friend notes.
    local ownRealm=C.Call(GetNormalizedRealmName) or C.Call(GetRealmName) or ""
    local ownRealmID=C.Call(GetRealmID)
    local faction,localizedFaction=C.Call(UnitFactionGroup,"player")
    local function addGame(game)
        if type(game)~="table" then return end
        for _,key in ipairs({"clientProgram","isOnline","isAppearOffline","isInCurrentRegion","wowProjectID","characterName","realmName","realmID","factionName"}) do
            if not C.Safe(game[key]) then return end
        end
        if game.clientProgram~="WoW" or not game.isOnline or game.isAppearOffline or game.isInCurrentRegion==false then return end
        if not WOW_PROJECT_ID or game.wowProjectID~=WOW_PROJECT_ID then return end
        if not faction or (game.factionName~=faction and game.factionName~=localizedFaction) then return end
        local realm=game.realmName
        local sameRealm=ownRealmID and game.realmID and ownRealmID==game.realmID or type(realm)=="string" and realm:gsub("%s",""):lower()==ownRealm:gsub("%s",""):lower()
        if not sameRealm or type(game.characterName)~="string" or game.characterName=="" then return end
        result[game.characterName]=true
    end
    if C_BattleNet and BNGetNumFriends then
        for i=1,math.min(C.Call(BNGetNumFriends) or 0,500) do
            for account=1,math.min(C.Call(C_BattleNet.GetFriendNumGameAccounts,i) or 0,20) do
                addGame(C.Call(C_BattleNet.GetFriendGameAccountInfo,i,account))
            end
        end
    end
    for name in pairs(result) do if self:IsIgnored(name) then result[name]=nil end end
    return result
end
