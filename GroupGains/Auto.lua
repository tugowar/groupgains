local _,C=...
C.Auto={actions={}}
local A=C.Auto
function A:Enabled(key)
    local s=C.State.data.settings
    return s.autoEnabled~=false and s[key]~=false and not C.Call(InCombatLockdown) and not C.Call(IsShiftKeyDown)
end
function A:Scheduled(id,kind)
    if not C.Safe(id) or type(id)~="number" then return false end
    if kind=="pickup" and (C.State.facts.active[id] or C.State.data.completedQuests[id]) then return false end
    local _,part=C.State:Current()
    local seen={}
    while part and not seen[part.id] do
        seen[part.id]=true
        for _,task in ipairs(part.tasks) do
            if task.questId==id and task.kind==kind and not C.State:Done(task) then return true end
        end
        if kind~="pickup" then break end -- turn-ins still belong to the current part
        local previous
        local chapter=C.State.chapters[part.chapterId]
        for i,p in ipairs(chapter.parts) do if p==part then previous=chapter.parts[i-1];break end end
        if not previous then
            -- Follow only an unambiguous authored predecessor. Alternative
            -- starter routes are not all treated as this character's past.
            for from,to in pairs(C.Guide.nextParts or {}) do
                if to==part.id and C.State.parts[from] then
                    if previous then return false end
                    previous=C.State.parts[from]
                end
            end
        end
        part=previous
    end
    return false
end
function A:Act(key,fn,...)
    if type(fn)~="function" or self.actions[key] then return end
    self.actions[key]=true
    local ok=pcall(fn,...)
    if not ok then C.Print("The game did not allow that quest action. Continue using the quest dialog.") end
end
function A:OnEvent(event)
    if event=="QUEST_FINISHED" or event=="GOSSIP_CLOSED" then self.actions={};return end
    -- Shared offers have a separate, roster-checked GroupGains path. They do
    -- not fall through to NPC automation, even if the IDs match this part.
    if event=="QUEST_DETAIL" and (C.Call(UnitIsPlayer,"questnpc")==true or C.Call(UnitIsPlayer,"npc")==true) then return end
    -- Never move, target, interact with an NPC, or choose a reward.
    if not C.Call(UnitExists,"questnpc") and not C.Call(UnitExists,"npc") then return end
    if event=="GOSSIP_SHOW" or event=="QUEST_GREETING" then
        self.actions={}
        if event=="GOSSIP_SHOW" and C_GossipInfo then
            if self:Enabled("autoTurnIn") then
                for _,q in ipairs(C.Call(C_GossipInfo.GetActiveQuests) or {}) do
                    if C.Safe(q.isComplete) and q.isComplete and self:Scheduled(q.questID,"turnin") then self:Act("active:"..q.questID,C_GossipInfo.SelectActiveQuest,q.questID);return end
                end
            end
            if self:Enabled("autoAccept") then
                for _,q in ipairs(C.Call(C_GossipInfo.GetAvailableQuests) or {}) do
                    if self:Scheduled(q.questID,"pickup") then self:Act("offer:"..q.questID,C_GossipInfo.SelectAvailableQuest,q.questID);return end
                end
            end
        end
        -- Clients without quest IDs in greeting menus are left to the player;
        -- the detail/progress dialog still provides an exact quest ID.
    elseif event=="QUEST_DETAIL" then
        local id=C.Call(GetQuestID)
        if self:Enabled("autoAccept") and self:Scheduled(id,"pickup") then self:Act("accept:"..id,AcceptQuest) end
    elseif event=="QUEST_PROGRESS" then
        local id=C.Call(GetQuestID)
        if self:Enabled("autoTurnIn") and self:Scheduled(id,"turnin") and C.Call(IsQuestCompletable)==true then self:Act("complete:"..id,CompleteQuest) end
    elseif event=="QUEST_COMPLETE" then
        local id=C.Call(GetQuestID)
        -- Zero is deliberate: even a single selectable item is left to you.
        if self:Enabled("autoTurnIn") and self:Scheduled(id,"turnin") and C.Call(GetNumQuestChoices)==0 then self:Act("reward:"..id,GetQuestReward,0) end
    end
end
