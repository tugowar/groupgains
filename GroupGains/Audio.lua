local _,C=...
C.Audio={}
local A=C.Audio
-- These paths reference Blizzard audio already installed with WoW. No sound
-- recordings or other addons' code/assets are distributed with GroupGains.
A.sounds={
    {id="orc-male",label="Orc Male · Good job",path="Sound/Character/Orc/OrcVocalMale/OrcMaleCongratulations02.ogg"},
    {id="orc-female",label="Orc Female · Congratulations",path="Sound/Character/Orc/OrcVocalFemale/OrcFemaleCongratulations01.ogg"},
    {id="troll-male",label="Troll Male · Congratulations",path="Sound/Character/Troll/TrollVocalMale/TrollMaleCongratulations01.ogg"},
    {id="undead-male",label="Undead Male · Congratulations",path="Sound/Character/Scourge/ScourgeVocalMale/UndeadMaleCongratulations02.ogg"},
    {id="quest-complete",label="Game quest complete",path="Sound/Interface/iquestcomplete.ogg"},
    {id="quest-update",label="Game objective complete",path="Sound/Interface/iquestupdate.ogg"},
    {id="map-ping",label="Map ping",path="Sound/Interface/MapPing.ogg"},
    {id="bell-horde",label="Horde bell",path="Sound/Doodad/BellTollHorde.ogg"},
    {id="boat",label="Boat docked",path="Sound/Doodad/BoatDockedWarning.ogg"},
    {id="window-open",label="Window open",path="Sound/Interface/AuctionWindowOpen.ogg"},
    {id="window-close",label="Window close",path="Sound/Interface/AuctionWindowClose.ogg"},
}
A.events={
    {id="Progress",label="Objective progress",default="quest-update"},
    {id="Objective",label="Objective complete",default="window-close"},
    {id="Quest",label="Quest complete",default="orc-male"},
}
A.channels={{id="Master",label="Master volume"},{id="SFX",label="Effects"},{id="Music",label="Music"},{id="Ambience",label="Ambience"},{id="Dialog",label="Dialog"}}
function A:Sound(id)
    for _,sound in ipairs(self.sounds) do if sound.id==id then return sound end end
end
function A:Settings()
    local s=C.State.data.settings
    if s.audioDefaultsVersion~=1 then
        -- Upgrade the previous defaults once; retain other selected sounds.
        if s.audioProgressSound=="map-ping" then s.audioProgressSound="quest-update" end
        if s.audioObjectiveSound=="quest-update" then s.audioObjectiveSound="window-close" end
        s.audioDefaultsVersion=1
    end
    for _,event in ipairs(self.events) do
        local key="audio"..event.id
        if s[key.."Enabled"]==nil then s[key.."Enabled"]=true end
        if not self:Sound(s[key.."Sound"]) then s[key.."Sound"]=event.default end
    end
    local valid=false
    for _,channel in ipairs(self.channels) do if channel.id==s.audioChannel then valid=true end end
    if not valid then s.audioChannel="Master" end
    if type(s.audioProgressDelay)~="number" then s.audioProgressDelay=.5 end
    s.audioProgressDelay=math.max(0,math.min(1,s.audioProgressDelay))
    return s
end
function A:Reset()
    self.previous=nil;self.lastProgress=nil
    self:Settings()
end
function A:Play(event,preview)
    local s=self:Settings();local key="audio"..event
    if s.audioEnabled==false or (not preview and s[key.."Enabled"]==false) then return false end
    local sound=self:Sound(s[key.."Sound"])
    if not sound or type(PlaySoundFile)~="function" then return false end
    local now=C.Call(GetTime) or C.Now()
    if event=="Progress" and not preview and now-(self.lastProgress or -1000)<s.audioProgressDelay then return false end
    local ok,played=pcall(PlaySoundFile,sound.path,s.audioChannel)
    if not ok or not C.Safe(played) or played==false then return false end
    if event=="Progress" and not preview then self.lastProgress=now end
    return true
end
function A:Observe()
    local s=self:Settings();local facts=C.State.facts
    local snapshot={};local events={}
    for id in pairs(C.State.questIds) do
        if facts.active[id] and not facts.completed[id] then
            local rows=facts.objectives[id] or {}
            -- An accept event can arrive before the quest log has loaded. Wait
            -- for its actual state, rather than treating missing data as zero.
            if facts.ready[id]~=nil or #rows>0 then
                local q={ready=facts.ready[id]==true,objectives={}}
                local previous=self.previous and self.previous[id]
                for index,row in ipairs(rows) do
                    local text=C.Normalize((row.text or ""):gsub("%d+%s*/%s*%d+", ""))
                    local objective={text=text,count=row.count,required=row.required,done=row.finished==true}
                    q.objectives[index]=objective
                    local before=previous and previous.objectives[index]
                    if before and before.text==text and before.required==objective.required then
                        if not before.done and objective.done then events.Objective=true end
                        if type(before.count)=="number" and type(objective.count)=="number" and objective.count>before.count then events.Progress=true end
                    end
                end
                if previous and not previous.ready and q.ready then events.Quest=true end
                snapshot[id]=q
            end
        end
    end
    -- Seed silently on login/acceptance; manual checkboxes and historical
    -- turn-ins never generate sounds. Muted changes still update the baseline.
    self.previous=snapshot
    for _,event in ipairs({"Quest","Objective","Progress"}) do
        if events[event] and s["audio"..event.."Enabled"] then self:Play(event);return end
    end
end
