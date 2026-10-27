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
    self.facts={active={},completed=self.data.completedQuests,objectives={},ready={}}
    self.chapters,self.parts,self.tasks,self.questIds={},{},{},{}
    for _,chapter in ipairs(C.Guide.chapters) do
        self.chapters[chapter.id]=chapter
        for _,part in ipairs(chapter.parts) do
            self.parts[part.id]=part;part.chapterId=chapter.id
            for _,task in ipairs(part.tasks) do
                self.tasks[task.id]=task;task.partId=part.id;task.chapterId=chapter.id
                if task.questId then self.questIds[task.questId]=true end
            end
        end
    end
    if not self.chapters[self.data.chapterId] then
        local starter=C.Guide.profile.race=="tauren" and "from-the-earth" or C.Guide.profile.race=="undead" and "undead-warlock" or "from-durotar"
        self.data.chapterId=self.chapters[starter] and starter or C.Guide.chapters[1].id
    end
    self:Select(self.data.chapterId,self.data.partId,true)
end
function S:Select(chapterId,partId,silent)
    local chapter=self.chapters[chapterId]
    if not chapter then return false end
    local part=self.parts[partId]
    if not part or part.chapterId~=chapterId then part=chapter.parts[1] end
    self.data.chapterId,self.data.partId=chapterId,part.id
    self.data.selectedTask=part.tasks[1].id
    if not silent then self:Changed(false) end
    return true
end
function S:Current() return self.chapters[self.data.chapterId],self.parts[self.data.partId] end
function S:ObjectiveDone(task)
    if self.facts.completed[task.questId] then return true end
    if not self.facts.active[task.questId] or task.delivery then return false end
    if self.facts.ready[task.questId] then return true end
    local target=C.Normalize(task.target)
    if target=="" then return false end
    local matches={}
    for _,obj in ipairs(self.facts.objectives[task.questId] or {}) do
        if C.Normalize(obj.text):find(target,1,true) then matches[#matches+1]=obj end
    end
    -- Website indexes are not assumed to be the client's objective order.
    if #matches~=1 then return false end
    local obj=matches[1]
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
function S:Changed(checkComplete)
    self.data.updatedAt=C.Now()
    local _,part=self:Current()
    if checkComplete then
        local done,total=self:Progress(part)
        local key=C.Guide.revision..":"..part.id
        if done==total and not self.data.announced[key] and (self.data.settings.guild or self.data.settings.friends or self.data.settings.everyone) then
            self.data.announced[key]=true
            if C.Social then C.Social:Announce() end
        end
    end
    if C.UI then C.UI:Render() end
end
function S:ApplyFacts(facts)
    for id in pairs(facts.completed or {}) do self.data.completedQuests[id]=true end
    facts.completed=self.data.completedQuests
    self.facts=facts
    self:Changed(true)
end
function S:Adjacent(partId)
    if partId==self.data.partId then return true end
    for _,id in ipairs(C.Guide.neighbors[self.data.partId] or {}) do if id==partId then return true end end
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
