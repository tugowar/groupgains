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
    C.API:Refresh();C.UI:Create();C.Social:Start()
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","QUEST_ACCEPTED","QUEST_TURNED_IN","QUEST_REMOVED","QUEST_LOG_UPDATE","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","PLAYER_GUILD_UPDATE","CHAT_MSG_ADDON"}) do
        pcall(events.RegisterEvent,events,event)
    end
    SLASH_GROUPGAINS1="/groupgains";SLASH_GROUPGAINS2="/gg"
    SlashCmdList.GROUPGAINS=function(command)
        command=(command or ""):lower()
        if command=="export" then C.UI:Copy("Copy progress for Cohort Gaming",C.JSON(C.State:Export()))
        elseif command=="chapters" then C.UI:Choose("chapter")
        elseif command=="auto" then local task=C.State.data.selectedTask;if task then C.State:Set(task,nil) end
        elseif command=="status" then C.Print("Version "..C.version.."; API "..tostring(select(4,GetBuildInfo())).."; route "..C.Guide.revision)
        else C.UI:Toggle() end
    end
    C.Print("Ready. /groupgains opens the tracker. Guild/friend matching is on by default; Everyone is opt-in. Check the three controls in the tracker.")
end
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if (...)=="GroupGains" and IsLoggedIn and IsLoggedIn() then initialize() end
    elseif event=="PLAYER_LOGIN" then initialize()
    elseif event=="CHAT_MSG_ADDON" and initialized then C.Social:Receive(...)
    elseif event=="QUEST_TURNED_IN" and initialized then
        local id=...
        if C.Safe(id) and type(id)=="number" then C.State.data.completedQuests[id]=true end
        C.API:QueueRefresh()
    elseif initialized then C.API:QueueRefresh() end
end)
