local _,C=...
C.State={}
local S=C.State
function S:Initialize(db,key)
    db.schema=1
    db.characters=db.characters or {}
    db.characters[key]=db.characters[key] or {}
    self.data=db.characters[key]
    self.data.overrides=self.data.overrides or {}
    self.data.completedQuests=self.data.completedQuests or {}
    self.data.announced=self.data.announced or {}
    self.data.settings=self.data.settings or {}
    local settings=self.data.settings
    if settings.matchingVersion~=2 then
        -- Preserve explicit legacy opt-outs; new characters get guild/friends on.
        if settings.guild==nil then settings.guild=settings.social~=false end
        if settings.friends==nil then settings.friends=settings.social~=false end
        if settings.social==false then settings.guild=false;settings.friends=false end
        settings.everyone=false
        settings.social=nil;settings.matchingVersion=2
    end
    if settings.guild==nil then settings.guild=true end
    if settings.friends==nil then settings.friends=true end
    if settings.everyone==nil then settings.everyone=false end
    if settings.party==nil then settings.party=true end
    for _,key in ipairs({"audioEnabled","autoEnabled","autoAccept","autoTurnIn","autoShared","autoSharePickup"}) do if settings[key]==nil then settings[key]=true end end
    if settings.opacityVersion~=1 then
        -- Change the previous default once; preserve customized opacity.
        if settings.trackerOpacity==nil or settings.trackerOpacity==.6 then settings.trackerOpacity=.5 end
        settings.opacityVersion=1
    end
    if C.Audio then C.Audio:Reset() end
    if settings.combatMode~="stay" and settings.combatMode~="hide" then settings.combatMode="minimize" end
    self.facts={active={},completed=self.data.completedQuests,objectives={},ready={}}
    if C.Guide.durotarProfiles and C.API and C.API.Character then
        local character=C.API:Character()
        local variant=C.Guide.durotarProfiles[(character.race or "")..":"..(character.class or "")]
        for i,chapter in ipairs(C.Guide.chapters) do
            if chapter.id=="from-durotar" then
                self.baseDurotar=self.baseDurotar or chapter
                local chosen=variant or self.baseDurotar
                -- Replace only the Durotar edges; preserve its main-journey exit.
                self.baseDurotarExit=self.baseDurotarExit or (C.Guide.nextParts or {})[self.baseDurotar.parts[#self.baseDurotar.parts].id]
                local oldIds={};for _,part in ipairs(chapter.parts) do oldIds[part.id]=true end
                for id,edges in pairs(C.Guide.neighbors) do
                    if oldIds[id] then C.Guide.neighbors[id]=nil else
                        local keep={};for _,other in ipairs(edges) do if not oldIds[other] then keep[#keep+1]=other end end
                        C.Guide.neighbors[id]=keep
                    end
                end
                C.Guide.nextParts=C.Guide.nextParts or {}
                for id in pairs(oldIds) do C.Guide.nextParts[id]=nil end
                for n,part in ipairs(chosen.parts) do
                    local nextId=chosen.parts[n+1] and chosen.parts[n+1].id or self.baseDurotarExit
                    if nextId then
                        C.Guide.nextParts[part.id]=nextId
                        C.Guide.neighbors[part.id]=C.Guide.neighbors[part.id] or {}
                        table.insert(C.Guide.neighbors[part.id],nextId)
                        C.Guide.neighbors[nextId]=C.Guide.neighbors[nextId] or {}
                        table.insert(C.Guide.neighbors[nextId],part.id)
                    end
                end
                C.Guide.chapters[i]=chosen
                break
            end
        end
    end
    self.chapters,self.parts,self.tasks,self.questIds={},{},{},{}
    for _,chapter in ipairs(C.Guide.chapters) do
        self.chapters[chapter.id]=chapter
        for _,part in ipairs(chapter.parts) do
            if part.alternateStart and C.API and C.API.Character then
                part.baseTasks=part.baseTasks or part.tasks;part.tasks=part.baseTasks
                local race=C.API:Character().race
                local included=false
                for _,allowed in ipairs(part.alternateStart.races or {}) do if allowed==race then included=true end end
                if included then
                    local tasks={}
                    for _,task in ipairs(part.alternateStart.tasks) do tasks[#tasks+1]=task end
                    for _,task in ipairs(part.tasks) do tasks[#tasks+1]=task end
                    part.tasks=tasks
                end
            end
            self.parts[part.id]=part;part.chapterId=chapter.id
            for _,task in ipairs(part.tasks) do
                self.tasks[task.id]=task;task.partId=part.id;task.chapterId=chapter.id
                if task.questId then self.questIds[task.questId]=true end
            end
        end
    end
    if not self.chapters[self.data.chapterId] then
        local race=C.API and C.API.Character and C.API:Character().race or C.Guide.profile.race
        local starter=race=="tauren" and "from-the-earth" or race=="undead" and "undead-warlock" or race=="skyborne" and "from-zephras-isle" or "from-durotar"
        self.data.chapterId=self.chapters[starter] and starter or C.Guide.chapters[1].id
        self.data.autoStartPending=true
    end
    self:Select(self.data.chapterId,self.data.partId,true)
    self:LocateNewCharacter(false)
end
function S:LocateNewCharacter(final)
    if not self.data.autoStartPending then return end
    local chapter=C.API and C.API.StartingChapter and C.API:StartingChapter()
    if chapter and self.chapters[chapter] then self:Select(chapter,nil,true) end
    if chapter or final then self.data.autoStartPending=nil end
end
function S:Select(chapterId,partId,silent)
    local chapter=self.chapters[chapterId]
    if not chapter then return false end
    local part=self.parts[partId]
    if not part or part.chapterId~=chapterId then part=chapter.parts[1] end
    local changed=self.data.chapterId~=chapterId or self.data.partId~=part.id
    self.data.chapterId,self.data.partId=chapterId,part.id
    self.data.selectedTask=part.tasks[1].id
    if not silent then self.data.autoStartPending=nil;self:Changed(false) end
    if changed and not silent and C.Social and C.Social.RouteChanged then C.Social:RouteChanged() end
    return true
end
function S:Current() return self.chapters[self.data.chapterId],self.parts[self.data.partId] end
function S:MatchedObjective(task)
    if task.kind~="objective" or not self.facts.active[task.questId] or task.delivery then return end
    local target=C.Normalize(task.target)
    if target=="" then return end
    local matches={}
    for _,obj in ipairs(self.facts.objectives[task.questId] or {}) do
        if C.Normalize(obj.text):find(target,1,true) then matches[#matches+1]=obj end
    end
    -- Website indexes are not assumed to be the client's objective order.
    if #matches==1 then return matches[1] end
end
function S:ObjectiveProgress(task)
    local obj=self:MatchedObjective(task)
    if not obj then return end
    if type(obj.count)=="number" and type(obj.required)=="number" and obj.required>0 and obj.count>=0 then
        return string.format("%d/%d",math.min(obj.count,obj.required),obj.required)
    end
    if obj.finished then return "Complete" end
end
function S:ObjectiveDone(task)
    if self.facts.completed[task.questId] then return true end
    if not self.facts.active[task.questId] or task.delivery then return false end
    if self.facts.ready[task.questId] then return true end
    local obj=self:MatchedObjective(task)
    if not obj then return false end
    if task.count and obj.required and task.count~=obj.required then return false end
    return obj.finished==true
end
function S:Automatic(task)
    if task.kind=="pickup" then return self.facts.active[task.questId] or self.facts.completed[task.questId] or false end
    if task.kind=="turnin" then return self.facts.completed[task.questId] or false end
    if task.kind=="objective" then return self:ObjectiveDone(task) end
    if task.kind=="checkpoint" or task.kind=="catchup" then return (self.facts.level or 0)>=(task.level or 999) end
    return false
end
function S:Done(task)
    local value=self.data.overrides[task.id]
    if value~=nil then return value end
    return self:Automatic(task)
end
function S:Set(taskId,value)
    if not self.tasks[taskId] then return end
    self.data.overrides[taskId]=value
    self:Changed(true)
end
function S:Progress(part)
    local done=0
    for _,t in ipairs(part.tasks) do if self:Done(t) then done=done+1 end end
    return done,#part.tasks
end
function S:PartsBefore(chapterId,partId)
    local earlier={}
    -- Use the same website-authored chapter/part order as the chooser.
    for _,chapter in ipairs(C.Guide.chapters) do
        for _,part in ipairs(chapter.parts) do
            if chapter.id==chapterId and part.id==partId then return earlier end
            earlier[#earlier+1]=part
        end
    end
end
function S:MarkBeforeCurrent(chapterId,partId)
    -- The confirmation refers to the tracker, not a journal browsing selection.
    if self.data.chapterId~=chapterId or self.data.partId~=partId then return false end
    local earlier=self:PartsBefore(chapterId,partId)
    if not earlier then return false end
    local count=0
    for _,part in ipairs(earlier) do
        for _,task in ipairs(part.tasks) do
            self.data.overrides[task.id]=true;count=count+1
        end
    end
    -- This is guide progress only, never fabricated game quest history.
    -- Refresh once without advancing the current part or announcing old parts.
    self:Changed(false)
    return true,#earlier,count
end
function S:Changed(checkComplete)
    self.data.updatedAt=C.Now()
    if C.Audio then C.Audio:Observe() end
    local _,part=self:Current()
    if checkComplete then
        local done,total=self:Progress(part)
        local key=C.Guide.revision..":"..part.id
        if done==total and not self.data.announced[key] and (self.data.settings.guild or self.data.settings.friends or self.data.settings.everyone or self.data.settings.party) then
            self.data.announced[key]=true
            if C.Social then C.Social:Announce() end
        end
        if total>0 and done==total then
            local nextChapter,nextPart=self:FollowingPart()
            if nextPart then self:Select(nextChapter.id,nextPart.id);return end
        end
    end
    if C.UI then C.UI:Render() end
end
function S:FollowingPart()
    local chapter,part=self:Current()
    for i,p in ipairs(chapter.parts) do
        if p==part and chapter.parts[i+1] then return chapter,chapter.parts[i+1] end
    end
    -- Cross chapter boundaries only along the website's authored connections.
    local directed=C.Guide.nextParts and C.Guide.nextParts[part.id]
    if directed then
        local p=self.parts[directed]
        if p then return self.chapters[p.chapterId],p end
    end
    local nextChapter,nextPart
    local indexes={};for i,ch in ipairs(C.Guide.chapters) do indexes[ch.id]=i end
    for _,id in ipairs(C.Guide.neighbors[part.id] or {}) do
        local p=self.parts[id]
        local ch=p and self.chapters[p.chapterId]
        if ch and ch~=chapter and ch.parts[1]==p and indexes[ch.id]>indexes[chapter.id] then
            if nextPart then return nil end -- don't choose a branch for the player
            nextChapter,nextPart=ch,p
        end
    end
    return nextChapter,nextPart
end
function S:ApplyFacts(facts)
    for id in pairs(facts.completed or {}) do self.data.completedQuests[id]=true end
    facts.completed=self.data.completedQuests
    self.facts=facts
    self:Changed(true)
end
function S:MatchRadius()
    local level=tonumber(self.facts.level) or 1
    if level>=45 then return 3 end
    if level>=32 then return 2 end
    return 1
end
function S:Adjacent(partId)
    if not self.parts[partId] then return false end
    local start=self.data.partId
    if partId==start then return true end
    -- Walk only the website-authored connections, including chapter boundaries.
    -- A visited set keeps cycles and branching routes bounded.
    local seen={[start]=true};local frontier={start}
    for distance=1,self:MatchRadius() do
        local nextParts={}
        for _,id in ipairs(frontier) do
            for _,neighbor in ipairs(C.Guide.neighbors[id] or {}) do
                if self.parts[neighbor] and not seen[neighbor] then
                    if neighbor==partId then return true end
                    seen[neighbor]=true;nextParts[#nextParts+1]=neighbor
                end
            end
        end
        frontier=nextParts
        if #frontier==0 then break end
    end
    return false
end
function S:Export()
    local taskStates={}
    for id,task in pairs(self.tasks) do
        if self:Done(task) or self.data.overrides[id]~=nil then
            taskStates[id]={done=self:Done(task),manual=self.data.overrides[id]~=nil}
        end
    end
    local completed,active={__array=true},{__array=true}
    for id in pairs(self.data.completedQuests) do completed[#completed+1]=id end
    for id in pairs(self.facts.active or {}) do active[#active+1]=id end
    table.sort(completed);table.sort(active)
    local profile={race=C.Guide.profile.race,class=C.Guide.profile.class,party=C.Guide.profile.party,professions={__array=true}}
    for _,name in ipairs(C.Guide.profile.professions or {}) do profile.professions[#profile.professions+1]=name end
    return {schema=1,addonVersion=C.version,guideRevision=C.Guide.revision,
        exportedAt=C.Now(),profile=profile,character=C.API:Character(),
        chapterId=self.data.chapterId,partId=self.data.partId,tasks=taskStates,
        completedQuests=completed,activeQuests=active,trust="self-reported-addon-export"}
end
