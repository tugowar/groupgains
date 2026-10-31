local _,C=...
C.Diagnostics={}
local function flag(v) return v==true and "yes" or v==false and "no" or "unavailable" end
function C.Diagnostics:Report()
    local version,build,date,interface=C.Call(GetBuildInfo)
    local members=C.API:GuildMembers();local known,online=0,0
    for _,member in pairs(members) do known=known+1;if member.online then online=online+1 end end
    local s=C.State.data.settings;local t=C.Social.lastTransport;local character=C.API:Character()
    return table.concat({
        "Group Gains "..C.version.." / build "..C.build,
        "Primary target: WoW Forever; Classic Era is a compatibility test client.",
        "Client: "..C.Text(version).." / build "..C.Text(build).." / interface "..C.Text(interface).." / project "..C.Text(WOW_PROJECT_ID),
        "Character: "..C.Text(character.race).." "..C.Text(character.class).." / level "..C.Text(character.level),
        "Guide profile: "..C.Text(C.Guide.activeProfile or C.Guide.profile.race..":"..C.Guide.profile.class),
        "Realm: "..C.Text(C.Call(GetRealmName)),
        "In guild: "..flag(C.Call(IsInGuild)).." / name: "..C.Text(C.Call(GetGuildInfo,"player")),
        "Guild roster: "..known.." known / "..online.." online",
        "Matching: guild "..flag(s.guild)..", friends "..flag(s.friends)..", party "..flag(s.party)..", everyone "..flag(s.everyone),
        "Search range: "..C.State:MatchRadius().." parts ahead/behind"..(type(s.searchRange)=="number" and " (custom)" or " (automatic)"),
        "Finder: "..C.Social:SearchStatus(),
        "Last send: "..(t and t.channel.." / "..t.result.." / "..math.max(0,C.Now()-t.at).."s ago" or "no attempt this session"),
        "Active chat lock: "..flag(C_ChatInfo and C.Call(C_ChatInfo.InChatMessagingLockdown)),
        "Realm restriction flag (informational): "..flag(C_ChatInfo and C.Call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)),
        "No character keys, friend identities or position coordinates are included."
    },"\n")
end
