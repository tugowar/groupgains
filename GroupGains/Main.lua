local _,C=...
local events=CreateFrame("Frame")
local initialized=false
local function initialize()
    if initialized then return end
    if not C.Guide or not C.Guide.chapters or #C.Guide.chapters==0 then C.Print("No route pack installed.");return end
    if C.Guide.schema~=1 then C.Print("This guide database needs a newer Group Gains addon. Install a compatible addon update.");return end
    local key=C.Call(UnitGUID,"player")
    -- Wait until the client identifies this character; never mix anonymous alts.
    if not key then return end
    initialized=true
    -- Accept a legacy SavedVariables file copied to GroupGains.lua during upgrade.
    -- An existing Group Gains database always wins over the legacy copy.
    GroupGainsDB=type(GroupGainsDB)=="table" and GroupGainsDB or (type(CutiesDB)=="table" and CutiesDB or {})
    CutiesDB=nil
    C.State:Initialize(GroupGainsDB,key)
    C.API:Refresh();C.UI:Create()
    if C.PartyProgress then C.PartyProgress:Start() end
    C.Social:Start()
    if C.QuestShare then C.QuestShare:Start() end
    if C.Companions then C.Companions:GroupChanged() end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","GOSSIP_SHOW","GOSSIP_CLOSED","QUEST_GREETING","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_FINISHED","QUEST_ACCEPTED","QUEST_TURNED_IN","QUEST_REMOVED","QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","QUEST_LOG_CRITERIA_UPDATE","QUEST_DATA_LOAD_RESULT","QUEST_QUERY_COMPLETE","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","PLAYER_GUILD_UPDATE","CHAT_MSG_ADDON","GROUP_ROSTER_UPDATE","FRIENDLIST_UPDATE","IGNORELIST_UPDATE","BN_BLOCK_LIST_UPDATED","BN_FRIEND_ACCOUNT_ONLINE","BN_FRIEND_ACCOUNT_OFFLINE","BN_FRIEND_INFO_CHANGED","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_LOGOUT"}) do
        pcall(events.RegisterEvent,events,event)
    end
    SLASH_GROUPGAINS1="/groupgains";SLASH_GROUPGAINS2="/gg";SLASH_GROUPGAINS3="/gains"
    SlashCmdList.GROUPGAINS=function(command)
        command=(command or ""):lower()
        if command=="export" then C.UI:Copy("Copy progress for Cohort Gaming",C.JSON(C.State:Export()))
        elseif command=="sync" then C.API:Sync()
        elseif command=="settings" then C.UI:OpenSettings()
        elseif command=="journal" then C.UI:OpenSettings("journal")
        elseif command=="dungeons" then C.UI:OpenSettings("dungeons")
        elseif command=="chapters" then C.UI:Choose("chapter")
        elseif command=="auto" then local task=C.State.data.selectedTask;if task then C.API:RestoreAutomatic(task) end
        elseif command=="search" then C.Social:RequestSearch()
        elseif command=="status" then C.Print("Version "..C.version.." ("..C.build.."); API "..tostring(select(4,GetBuildInfo())).."; route "..C.Guide.revision)
        else C.UI:Open();C.Social:RequestSearch() end
    end
    C.Print("Ready. /groupgains opens the tracker. Guild, friends and party matching are on by default; Everyone is opt-in. /gg search finds companions now.")
end
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if (...)=="GroupGains" and IsLoggedIn and IsLoggedIn() then initialize() end
    elseif event=="PLAYER_LOGIN" then initialize()
    elseif event=="CHAT_MSG_ADDON" and initialized then
        if C.AutoShare then C.AutoShare:Receive(...) end
        if C.QuestShare then C.QuestShare:Receive(...) end
        if C.PartyProgress then C.PartyProgress:Receive(...) end
        C.Social:Receive(...)
    elseif event=="GROUP_ROSTER_UPDATE" and initialized then
        if C.QuestShare then C.QuestShare:GroupChanged() end
        C.Social:GroupChanged();C.Social:CheckPartySearch()
        if C.Companions then C.Companions:GroupChanged() end
        C.UI:RenderMatches()
    elseif (event=="CHAT_MSG_WHISPER" or event=="CHAT_MSG_WHISPER_INFORM") and initialized then
        local message,name=...;if C.Companions then C.Companions:WhisperEvent(event,message,name,select(11,...)) end
    elseif event=="PLAYER_REGEN_DISABLED" and initialized then C.UI:Combat(true);if C.QuestShare then C.QuestShare:Tick() end
    elseif event=="PLAYER_REGEN_ENABLED" and initialized then C.UI:Combat(false);C.Social:CheckPartySearch();if C.QuestShare then C.QuestShare:CheckDungeon() end
    elseif event=="PLAYER_LOGOUT" and initialized then if C.Companions then C.Companions:KeepRoster() end
    elseif (event=="FRIENDLIST_UPDATE" or event=="IGNORELIST_UPDATE" or event=="BN_BLOCK_LIST_UPDATED" or event:find("^BN_FRIEND_")) and initialized then
        C.Social.friendNames=nil
        if C.UI then C.UI:RenderMatches() end
    elseif event=="PLAYER_ENTERING_WORLD" and initialized then
        C.State:LocateNewCharacter(true);C.API:QueueRefresh();C.Social:GroupChanged();C.Social:CheckPartySearch()
        if C.QuestShare then C.QuestShare:CheckDungeon() end
    elseif initialized and C.Auto and (event=="GOSSIP_SHOW" or event=="GOSSIP_CLOSED" or event=="QUEST_GREETING" or event=="QUEST_DETAIL" or event=="QUEST_PROGRESS" or event=="QUEST_COMPLETE" or event=="QUEST_FINISHED") then
        if C.QuestShare then
            if event=="QUEST_DETAIL" then C.QuestShare:QuestDetail()
            elseif event=="QUEST_FINISHED" or event=="GOSSIP_CLOSED" then C.QuestShare.pending=nil end
        end
        C.Auto:OnEvent(event)
    elseif event=="QUEST_ACCEPTED" and initialized then
        C.API:Accepted(...)
        if C.AutoShare then C.AutoShare:Accepted(...) end
    elseif event=="PLAYER_LEVEL_UP" and initialized then
        C.API:LevelChanged(...)
    elseif event=="QUEST_TURNED_IN" and initialized then
        local id=...
        if C.Safe(id) and type(id)=="number" then C.State.data.completedQuests[id]=true end
        C.API:QueueRefresh()
    elseif initialized then C.API:QueueRefresh() end
end)
