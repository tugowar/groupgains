local _,C=...
C.API={}
local A=C.API
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
function A:Capture()
    local facts={active={},completed={},objectives={},ready={},level=C.Call(UnitLevel,"player") or 1}
    local api=C_QuestLog
    if not api then return facts end
    for _,id in ipairs(C.Call(api.GetAllCompletedQuestIDs) or {}) do
        if C.Safe(id) and type(id)=="number" and C.State.questIds[id] then facts.completed[id]=true end
    end
    local count=C.Call(api.GetNumQuestLogEntries) or 0
    for index=1,math.min(count,1000) do
        local info=C.Call(api.GetInfo,index)
        if info and C.Safe(info.questID) and info.questID and info.questID>0 and not info.isHeader then
            local id=info.questID
            facts.active[id]=true
            facts.ready[id]=C.Call(api.IsComplete,id)==true
            local objectives={}
            for _,o in ipairs(C.Call(api.GetQuestObjectives,id) or {}) do
                if C.Safe(o.text) and C.Safe(o.finished) and C.Safe(o.numRequired) and C.Safe(o.numFulfilled) then
                    objectives[#objectives+1]={text=C.Text(o.text),finished=o.finished==true,required=o.numRequired,count=o.numFulfilled}
                end
            end
            facts.objectives[id]=objectives
        end
    end
    return facts
end
function A:Refresh() C.State:ApplyFacts(self:Capture()) end
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
    local set=false
    if C_Map.SetUserWaypoint and UiMapPoint and C.Call(C_Map.CanSetUserWaypointOnMap,point.mapId) then
        local ok,result=pcall(function()
            local p=UiMapPoint.CreateFromCoordinates(point.mapId,point.x/100,point.y/100)
            return C_Map.SetUserWaypoint(p)
        end)
        set=ok and result~=false
        if set and C_SuperTrack then C.Call(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
    end
    if not set and TomTom and TomTom.AddWaypoint then
        local ok=pcall(TomTom.AddWaypoint,TomTom,point.mapId,point.x/100,point.y/100,{title=C.Text(task.title),persistent=false,minimap=true,world=true})
        set=ok
    end
    if C_Map.OpenWorldMap then C.Call(C_Map.OpenWorldMap,point.mapId)
    elseif OpenWorldMap then C.Call(OpenWorldMap,point.mapId) end
    C.Print(set and (point.approach and "Waypoint set to the dungeon approach; interior position is not recorded." or "Map waypoint set.") or "This map cannot take a waypoint here. Coordinates: "..string.format("%.1f, %.1f",point.x,point.y))
end
function A:Friends()
    local result={}
    if not C_FriendList then return result end
    for i=1,(C.Call(C_FriendList.GetNumFriends) or 0) do
        local f=C.Call(C_FriendList.GetFriendInfoByIndex,i)
        if f and C.Safe(f.connected) and f.connected and C.Safe(f.name) then result[C.Text(f.name)]=true end
    end
    return result
end
