local _,C=...
local U=C.UI
function U:OpenFinder()
    if not self.finder then
        local f=self:Panel("GroupGainsFinder",620,450);self.finder=f
        local title=self:Label(f,18);title:SetPoint("TOPLEFT",18,-18);title:SetText("See who is leveling")
        f.note=self:Label(f,11);f.note:SetPoint("TOPLEFT",18,-49);f.note:SetWidth(576)
        f.scroll,f.content=self:Scroll(f,18,-90,558,265);f.rows={}
        f.empty=self:Label(f.content,12);f.empty:SetPoint("TOPLEFT",4,-10);f.empty:SetWidth(530)
        f.empty:SetText("No compatible replies yet. Both players need Group Gains and matching enabled. Try Search now.")
        f.search=self:SearchButton(f,150);f.search:SetPoint("BOTTOMLEFT",18,18)
        f.guild=self:Button(f,"Peek at guild only real quick",230,function()C.Social:RequestSearch("guild");self:RenderMatches()end)
        f.guild:SetPoint("TOPRIGHT",-40,-16)
        self:Tip(f.guild,"One-time guild search","Shows matching guildmates who reply to this search. Your saved matching settings stay unchanged.")
        f:SetResizable(true)
        if f.SetResizeBounds then f:SetResizeBounds(620,450,1200,950) else f:SetMinResize(620,450);f:SetMaxResize(1200,950) end
        local grip=CreateFrame("Button",nil,f);grip:SetSize(22,22);grip:SetPoint("BOTTOMRIGHT",-4,4)
        local texture=grip:CreateTexture(nil,"ARTWORK");texture:SetAllPoints();texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetScript("OnMouseDown",function(_,button)if button=="LeftButton" then self:FocusPanel(f);f:StartSizing("BOTTOMRIGHT") end end)
        grip:SetScript("OnMouseUp",function()f:StopMovingOrSizing();C.State.data.finderSize={width=f:GetWidth(),height=f:GetHeight()} end)
        f:SetScript("OnSizeChanged",function()self:LayoutFinder()end)
        local size=C.State.data.finderSize
        if size then f:SetSize(math.max(620,math.min(1200,size.width)),math.max(450,math.min(950,size.height))) end
    end
    self:ShowPanel(self.finder);self:LayoutFinder();C.Social:RequestSearch();self:RenderMatches()
end
function U:LayoutFinder()
    local f=self.finder;if not f then return end
    local w,h=f:GetWidth(),f:GetHeight()
    f.note:SetWidth(w-44);f.scroll:SetSize(w-62,h-145);f.content:SetWidth(w-62)
    f.empty:SetWidth(w-84)
    self:RenderFinder()
end
function U:RenderFinder()
    local f=self.finder;if not f or not f:IsShown() then return end
    local radius=C.State:MatchRadius()
    local guildOnly=C.Social.search and C.Social.search.scope=="guild"
    f.note:SetText((guildOnly and "Guild peek · " or "").."Players using Group Gains within "..radius.." part"..(radius==1 and "" or "s").." ahead or behind you, including across chapter boundaries.")
    f.guild:SetEnabled(C.Social:SearchRemaining()==0)
    local matches=C.Social:Matches(guildOnly and "guild" or nil)
    for _,r in ipairs(f.rows) do r:Hide() end
    f.empty:SetShown(#matches==0)
    local offset=0
    for i,p in ipairs(matches) do
        local row=f.rows[i]
        if not row then
            row=CreateFrame("Frame",nil,f.content);row:SetWidth(554)
            local bg=row:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.19,.15,.10,.8)
            row.name=self:Label(row,13);row.name:SetPoint("TOPLEFT",8,-7);row.name:SetWidth(385)
            row.info=self:Label(row,11);row.info:SetPoint("TOPLEFT",8,-28);row.info:SetWidth(385)
            row.invite=self:Icon(row,"invite","Invite to group");row.invite:SetPoint("TOPRIGHT",-8,-10)
            self:Tip(row.invite,"Invite to group","Send a party invite to this player. One click sends one invite.")
            row.whisper=self:Button(row,"Send Whisper",138);row.whisper:SetPoint("RIGHT",row.invite,"LEFT",-5,0)
            self:Tip(row.whisper,"Send a group invitation",C.Companions.message.."\nOne click sends one whisper. Each player has a 30-second cooldown.")
            f.rows[i]=row
        end
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-offset)
        row:SetWidth(f:GetWidth()-66);row.name:SetWidth(f:GetWidth()-265);row.info:SetWidth(f:GetWidth()-265)
        row.name:SetText(C.Text(p.name).." · Level "..p.level)
        local part=C.State.parts[p.partId];local chapter=C.State.chapters[p.chapterId]
        row.info:SetText(C.Text(chapter.title).."\nPart "..string.format("%02d",part.number).." · "..C.Text(part.title).."\n"..C.Text(p.channel).." · seen "..math.max(0,C.Now()-p.seen).."s ago")
        local height=math.max(86,36+row.info:GetStringHeight());row:SetHeight(height);offset=offset+height+5
        local remaining=math.max(C.Companions:WhisperRemaining(p.name),5-(C.Now()-(C.Companions.lastWhisper or -1000)))
        row.whisper:SetText(remaining>0 and "Wait "..remaining.."s" or "Send Whisper")
        row.whisper:SetEnabled(remaining<=0 and not C.Call(InCombatLockdown))
        row.whisper:SetScript("OnClick",function()C.Companions:Whisper(p.name);self:RenderFinder()end)
        row.invite:SetEnabled(C.Companions:CanInvite(p.name))
        row.invite:SetScript("OnClick",function()C.Companions:Invite(p.name);self:RenderFinder()end)
        row:Show()
    end
    f.content:SetHeight(math.max(100,offset))
end
function U:OpenSettings(tab)
    if not self.settings then self:CreateSettings() end
    self:SetTab(tab or self.settingsTab or "finder");self:ShowPanel(self.settings)
end
function U:CreateSettings()
    local f=self:Panel("GroupGainsSettings",690,640);self.settings=f;self.pages={};self.tabs={}
    f:SetBackdropColor(.075,.065,.065,.82)
    local icon=f:CreateTexture(nil,"ARTWORK");icon:SetSize(68,68);icon:SetPoint("TOPLEFT",16,-9)
    icon:SetTexture("Interface\\AddOns\\GroupGains\\Media\\GroupGainsIcon")
    local title=self:Label(f,22);title:SetPoint("TOPLEFT",92,-20);title:SetText("Group Gains")
    local subtitle=self:Label(f,12);subtitle:SetPoint("TOPLEFT",93,-49);subtitle:SetText("Find your leveling group on the fly")
    local version=self:Label(f,10);version:SetPoint("TOPRIGHT",-42,-22);version:SetSize(250,14);version:SetJustifyH("RIGHT")
    version:SetText("v"..C.version.." · build "..C.build)
    local x=16
    for _,spec in ipairs({{"finder","Friend Finder",104},{"journal","Quest journal",108},{"dungeons","Dungeons",88},{"auto","Auto",58},{"link","Link to Leveling Guide",166},{"ui","UI Settings",98}}) do
        local id=spec[1];local b=self:Button(f,spec[2],spec[3],function()self:SetTab(id)end)
        b:SetPoint("TOPLEFT",x,-89);x=x+spec[3]+4;self.tabs[id]=b
        local page=CreateFrame("Frame",nil,f);page:SetPoint("TOPLEFT",16,-130);page:SetSize(650,490);self.pages[id]=page
    end
    self:CreateFinderSettings(self.pages.finder);self:CreateJournal(self.pages.journal);self:CreateDungeons(self.pages.dungeons);self:CreateLink(self.pages.link);self:CreateUISettings(self.pages.ui)
    self:CreateAuto(self.pages.auto)
    f:SetScript("OnHide",function()if self.linkKey then self.linkKey:SetText("");self.linkKey:ClearFocus() end end)
end
function U:SetTab(id)
    if not self.pages[id] then return end
    self.settingsTab=id
    for key,page in pairs(self.pages) do page:SetShown(key==id);self.tabs[key]:SetEnabled(key~=id) end
    if id~="link" then self.linkKey:SetText("");self.linkKey:ClearFocus() end
    self:RenderAudience();self:RenderAudit();self:RenderJournal();self:RenderLink();self:RenderUISettings();self:RenderAuto()
end
function U:CreateFinderSettings(p)
    self.audience={}
    for i,spec in ipairs({{"guild","Guild"},{"friends","Friends"},{"party","Party"},{"everyone","Everyone"}}) do
        local key=spec[1];local check=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate")
        check:SetSize(26,26);check:SetPoint("TOPLEFT",(i-1)*160,0)
        local name=self:Label(p,12);name:SetPoint("LEFT",check,"RIGHT",2,0);name:SetText(spec[2])
        check:SetScript("OnClick",function()C.Social:SetAudience(key,not C.State.data.settings[key]);self:RenderAudience()end)
        self.audience[key]=check
    end
    self:Tip(self.audience.friends,"Friends","Includes in-game friends and Battle.net friends playing on the same WoW version, realm and faction.")
    self:Tip(self.audience.party,"Party","Find compatible party members and share task progress when a party member hovers a task. Only the requested task is shared within your current party or raid; no quest log is broadcast.")
    self:Tip(self.audience.everyone,"Everyone · opt-in","Share your chapter, part and level on the dedicated Group Gains channel. Availability depends on the game server; no public chat messages are sent.")
    local note=self:Label(p,11);note:SetPoint("TOPLEFT",0,-35);note:SetWidth(642)
    note:SetText("Guild, both kinds of friends, and party are on by default. Everyone is opt-in. Match distance: levels 1–31 ±1 part, 32–44 ±2 parts, 45+ ±3 parts. Uses your character’s current level.")
    local title=self:Label(p,16);title:SetPoint("TOPLEFT",0,-81);title:SetText("Whispers and groups")
    local help=self:Label(p,10);help:SetPoint("TOPLEFT",0,-107);help:SetWidth(642)
    help:SetText("Only whispers tagged {GroupGains} or {GuildGains} are counted. Message text is not saved. Group counts track shared party/raid membership observed while this addon is running.")
    self.auditScroll,self.auditContent=self:Scroll(p,0,-151,620,285)
    self.auditText=self:Label(self.auditContent,11);self.auditText:SetPoint("TOPLEFT",0,0);self.auditText:SetWidth(612);self.auditText:SetJustifyV("TOP")
    local clear=self:Button(p,"Clear this character's log",222,function()C.Companions:ClearAudit()end);clear:SetPoint("BOTTOMLEFT",0,8)
    self:Tip(clear,"Clear local audit log","Clears whisper/group history for this character only. Quest progress is unchanged.")
end
function U:CreateDungeons(p)
    local title=self:Label(p,16);title:SetPoint("TOPLEFT",0,0);title:SetText("Dungeon progression charts")
    local note=self:Label(p,12);note:SetPoint("TOPLEFT",0,-30);note:SetWidth(638)
    note:SetText("Choose a dungeon to copy its progression chart link. Paste the link into your browser to see its quests and prerequisites.")
    self.dungeonScroll,self.dungeonContent=self:Scroll(p,0,-80,615,396)
    self.dungeonButtons={}
    for i,dungeon in ipairs(C.DungeonLinks or {}) do
        local entry=dungeon
        local b=self:Button(self.dungeonContent,entry.title.."  >",596,function()
            self:Copy(entry.title.." · progression chart",entry.url)
        end)
        b:SetPoint("TOPLEFT",0,-(i-1)*38)
        self:Tip(b,"Copy dungeon progression link",entry.url)
        self.dungeonButtons[#self.dungeonButtons+1]=b
    end
    self.dungeonContent:SetHeight(math.max(1,#self.dungeonButtons*38))
end
function U:RenderAudience()
    if not self.audience then return end
    for key,b in pairs(self.audience) do b:SetChecked(C.State.data.settings[key]) end
end
function U:RenderAudit()
    if not self.auditText then return end
    local db=C.Companions:Data();local list={};local lines={}
    for _,p in pairs(db.people) do list[#list+1]=p end
    table.sort(list,function(a,b)return a.lastAt>b.lastAt end)
    for _,p in ipairs(list) do lines[#lines+1]=C.Text(p.name).."\n  Sent "..p.sent.." · Received "..p.received.." · Grouped together "..p.grouped.."\n" end
    if #lines==0 then lines[1]="No marked whispers or shared groups recorded for this character yet." end
    if #db.events>0 then
        lines[#lines+1]="\nRECENT ACTIVITY"
        local names={sent="Whisper sent to",received="Whisper received from",grouped="Grouped with"}
        for i=#db.events,math.max(1,#db.events-49),-1 do
            local e=db.events[i];local when=C.Call(date,"%m/%d %H:%M",e.at) or tostring(e.at)
            lines[#lines+1]=when.." · "..(names[e.kind] or e.kind).." "..C.Text(e.name)
        end
    end
    self.auditText:SetText(table.concat(lines,"\n"));self.auditContent:SetHeight(math.max(1,self.auditText:GetStringHeight()+12))
end
function U:CreateJournal(p)
    local chapter,part=C.State:Current();self.journalChapter=chapter.id;self.journalPart=part.id
    self.journalChapterButton=self:Button(p,"Choose chapter",638,function()self:Choose("chapter",true)end);self.journalChapterButton:SetPoint("TOPLEFT",0,0)
    self.journalPartButton=self:Button(p,"Choose part",638,function()self:Choose("part",true)end);self.journalPartButton:SetPoint("TOPLEFT",0,-32)
    self.journalProgress=self:Label(p,11);self.journalProgress:SetPoint("TOPLEFT",0,-66);self.journalProgress:SetWidth(638)
    self.journalScroll,self.journalContent=self:Scroll(p,0,-96,615,310);self.journalRows={}
    local follow=self:Button(p,"Track this part",145,function()C.State:Select(self.journalChapter,self.journalPart);self:Open()end);follow:SetPoint("BOTTOMLEFT",0,40)
    self.markEarlier=self:Button(p,"Mark every part complete before the current part",415,function()self:ConfirmEarlierParts()end)
    self.markEarlier:SetPoint("LEFT",follow,"RIGHT",10,0)
    self:Tip(self.markEarlier,"Complete earlier parts","Uses the part currently shown in your tracker. Marks earlier chapters and parts complete for this character. The current part stays unchanged.")
    local hint=self:Label(p,10);hint:SetPoint("BOTTOMLEFT",0,12);hint:SetWidth(638)
    hint:SetText("Click a checkbox to change completion. Right-click it, or click A, to resume automatic tracking. Browsing the journal does not move your tracker.")
end
function U:ConfirmEarlierParts()
    if not self.earlierConfirm then
        local f=self:Panel("GroupGainsCompleteEarlier",560,240);self.earlierConfirm=f
        f.title=self:Label(f,17);f.title:SetPoint("TOPLEFT",18,-18);f.title:SetText("Complete earlier parts")
        f.message=self:Label(f,13);f.message:SetPoint("TOPLEFT",18,-56);f.message:SetWidth(520)
        f.note=self:Label(f,11);f.note:SetPoint("TOPLEFT",18,-142);f.note:SetWidth(520)
        f.note:SetText("Only this character's guide checkboxes change. The current part stays unchanged. You can undo individual tasks in Quest Journal.")
        f.yes=self:Button(f,"Yes, proceed",145,function()
            if C.State:MarkBeforeCurrent(f.chapterId,f.partId) then f:Hide();self:RenderJournal();self:RenderChoices()
            else self:ConfirmEarlierParts() end
        end);f.yes:SetPoint("BOTTOMLEFT",18,18)
        f.no=self:Button(f,"Cancel",100,function()f:Hide()end);f.no:SetPoint("LEFT",f.yes,"RIGHT",10,0)
    end
    local chapter,part=C.State:Current();local f=self.earlierConfirm
    f.chapterId,f.partId=chapter.id,part.id
    f.message:SetText("You are going to mark everything complete before "..C.Text(chapter.title).." · "..string.format("Part %02d · ",part.number)..C.Text(part.title)..". Do you want to proceed?")
    f.message:SetHeight(f.message:GetStringHeight())
    f.note:ClearAllPoints();f.note:SetPoint("TOPLEFT",f.message,"BOTTOMLEFT",0,-16)
    f:SetHeight(math.max(240,56+f.message:GetStringHeight()+16+f.note:GetStringHeight()+70))
    local earlier=C.State:PartsBefore(chapter.id,part.id);f.yes:SetEnabled(earlier and #earlier>0)
    self:ShowPanel(f)
end
function U:RenderJournal()
    if not self.journalContent or not self.settings:IsShown() or self.settingsTab~="journal" then return end
    local chapter=C.State.chapters[self.journalChapter];local part=C.State.parts[self.journalPart]
    if not chapter or not part then return end
    self.journalChapterButton:SetText(chapter.title);self.journalPartButton:SetText(string.format("Part %02d · %s",part.number,part.title))
    local done,total=C.State:Progress(part);self.journalProgress:SetText(done.."/"..total.." tasks completed for this character")
    if self.renderedJournal~=part.id then self.journalScroll:SetVerticalScroll(0);self.renderedJournal=part.id end
    self:TaskRows(self.journalContent,self.journalRows,part,615)
end
function U:CreateLink(p)
    local title=self:Label(p,16);title:SetPoint("TOPLEFT",0,0);title:SetText("Link this character to your leveling guide")
    self.linkCharacter=self:Label(p,12);self.linkCharacter:SetPoint("TOPLEFT",0,-32);self.linkCharacter:SetWidth(638)
    local note=self:Label(p,12);note:SetPoint("TOPLEFT",0,-66);note:SetWidth(638)
    note:SetText("Character-specific guide key\nEnter a guide linking key only, never your Battle.net password or OAuth token.")
    self.linkKey=CreateFrame("EditBox",nil,p,"InputBoxTemplate");self.linkKey:SetSize(474,28);self.linkKey:SetPoint("TOPLEFT",6,-115);self.linkKey:SetAutoFocus(false);self.linkKey:SetMaxLetters(256);self.linkKey:SetPassword(true)
    self.linkKey:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local save=self:Button(p,"Save key locally",150,function()
        if C.Companions:SaveLinkKey(self.linkKey:GetText()) then self.linkKey:SetText("");self.linkKey:ClearFocus();self:RenderLink() else self.linkStatus:SetText("Enter a key without spaces (up to 256 characters).") end
    end);save:SetPoint("TOPLEFT",490,-116)
    self.linkStatus=self:Label(p,11);self.linkStatus:SetPoint("TOPLEFT",0,-160);self.linkStatus:SetWidth(638)
    local clear=self:Button(p,"Remove saved key",170,function()C.Companions:SaveLinkKey("");self.linkKey:SetText("");self:RenderLink()end);clear:SetPoint("TOPLEFT",0,-191)
    local detail=self:Label(p,12);detail:SetPoint("TOPLEFT",0,-240);detail:SetWidth(638)
    detail:SetText("WoW addons cannot connect directly to a website. The key is stored locally for this character; it is not validated or linked yet. It is never broadcast or included in progress exports. Saved addon files are readable, so this field cannot protect an account credential.\n\nTo update the website now, copy your progress and import it while signed in on Cohort Gaming.")
    local export=self:Button(p,"Export this character's progress",270,function()self:Copy("Copy progress for Cohort Gaming",C.JSON(C.State:Export()))end);export:SetPoint("BOTTOMLEFT",0,35)
    local web=self:Button(p,"Open website link",175,function()self:Copy("Open Cohort Gaming", "https://cohortgaming.com/group-gains/")end);web:SetPoint("LEFT",export,"RIGHT",10,0)
end
function U:RenderLink()
    if not self.linkStatus then return end
    local char=C.API:Character()
    self.linkCharacter:SetText(C.Text(char.name).." · "..C.Text(char.realm).." · "..C.Text(char.race).." "..C.Text(char.class))
    self.linkStatus:SetText(C.State.data.guideLinkKey and "Key saved for this character · connection not verified" or "No key saved for this character")
end
function U:CreateUISettings(p)
    local title=self:Label(p,16);title:SetPoint("TOPLEFT",0,0);title:SetText("During combat, make the tracker…")
    self.combatOptions={}
    for i,spec in ipairs({{"stay","Stay open"},{"minimize","Minimize (default)"},{"hide","Hide"}}) do
        local key=spec[1];local b=CreateFrame("CheckButton",nil,p,"UIRadioButtonTemplate");b:SetSize(20,20);b:SetPoint("TOPLEFT",(i-1)*210,-32)
        local text=self:Label(p,12);text:SetPoint("LEFT",b,"RIGHT",10,0);text:SetText(spec[2])
        b:SetScript("OnClick",function()C.State.data.settings.combatMode=key;self:RenderUISettings()end);self.combatOptions[key]=b
    end
    local note=self:Label(p,11);note:SetPoint("TOPLEFT",0,-68);note:SetWidth(630)
    note:SetText("Your tracker returns to its previous state after combat. Drag its header to move it. Escape closes the foremost extra pane; it never closes the tracker.")
    local label=self:Label(p,12);label:SetPoint("TOPLEFT",0,-114);label:SetText("Tracker background opacity")
    self.opacity=CreateFrame("Slider",nil,p,"OptionsSliderTemplate");self.opacity:SetPoint("TOPLEFT",0,-141);self.opacity:SetSize(300,18);self.opacity:SetMinMaxValues(.1,1);self.opacity:SetValueStep(.05)
    if self.opacity.SetObeyStepOnDrag then self.opacity:SetObeyStepOnDrag(true) end
    self.opacityValue=self:Label(p,12);self.opacityValue:SetPoint("LEFT",self.opacity,"RIGHT",15,0)
    self.opacity:SetScript("OnValueChanged",function(_,value)C.State.data.settings.trackerOpacity=value;self.opacityValue:SetText(math.floor(value*100+.5).."%");self:RefreshQuickSettings()end)
    self.audioOption=self:SettingCheck(p,"audioEnabled","Enable quest audio",-183,function()self:RefreshQuickSettings();self:RenderUISettings()end)
    self.audioChannel=self:Button(p,"Sound channel",270,function()self:ChooseSound("channel")end);self.audioChannel:SetPoint("TOPLEFT",220,-183)
    self.audioEvents={}
    for i,event in ipairs(C.Audio.events) do
        local id=event.id;local key="audio"..id;local y=-226-(i-1)*42
        local check=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate");check:SetSize(26,26);check:SetPoint("TOPLEFT",0,y)
        local name=self:Label(p,12);name:SetPoint("LEFT",check,"RIGHT",6,0);name:SetWidth(180);name:SetText(event.label)
        check:SetScript("OnClick",function()C.State.data.settings[key.."Enabled"]=not C.State.data.settings[key.."Enabled"];self:RenderUISettings()end)
        local choose=self:Button(p,"Choose sound",270,function()self:ChooseSound(id)end);choose:SetPoint("TOPLEFT",220,y)
        local preview=self:Button(p,"Play",100,function()
            if not C.Audio:Play(id,true) then C.Print("Audio is muted or this game sound could not be played. Check the selected sound channel's volume.") end
        end);preview:SetPoint("TOPLEFT",505,y)
        self.audioEvents[id]={check=check,choose=choose,preview=preview}
    end
    local hint=self:Label(p,10);hint:SetPoint("TOPLEFT",0,-352);hint:SetWidth(630)
    hint:SetText("Quest complete plays when all quest objectives are ready for turn-in. Only game audio is used.")
    local delayLabel=self:Label(p,12);delayLabel:SetPoint("TOPLEFT",0,-379);delayLabel:SetText("Minimum time between objective progress sounds")
    self.audioDelay=CreateFrame("Slider",nil,p,"OptionsSliderTemplate");self.audioDelay:SetPoint("TOPLEFT",0,-405);self.audioDelay:SetSize(300,18);self.audioDelay:SetMinMaxValues(0,1);self.audioDelay:SetValueStep(.1)
    if self.audioDelay.SetObeyStepOnDrag then self.audioDelay:SetObeyStepOnDrag(true) end
    self.audioDelayValue=self:Label(p,12);self.audioDelayValue:SetPoint("LEFT",self.audioDelay,"RIGHT",15,0)
    self.audioDelay:SetScript("OnValueChanged",function(_,value)C.State.data.settings.audioProgressDelay=value;self.audioDelayValue:SetText(string.format("%.1f seconds",value))end)
    self.profile=self:Label(p,10);self.profile:SetPoint("TOPLEFT",0,-443);self.profile:SetWidth(630)
end
function U:RenderUISettings()
    if not self.combatOptions then return end
    for key,b in pairs(self.combatOptions) do b:SetChecked((C.State.data.settings.combatMode or "minimize")==key) end
    self.audioOption:SetChecked(C.State.data.settings.audioEnabled~=false);self.opacity:SetValue(C.State.data.settings.trackerOpacity or .5)
    local audio=C.Audio:Settings()
    for _,channel in ipairs(C.Audio.channels) do if channel.id==audio.audioChannel then self.audioChannel:SetText("Channel: "..channel.label) end end
    for id,row in pairs(self.audioEvents) do
        row.check:SetChecked(audio["audio"..id.."Enabled"])
        row.choose:SetText(C.Audio:Sound(audio["audio"..id.."Sound"]).label.." >")
    end
    self.audioDelay:SetValue(audio.audioProgressDelay)
    local char=C.API:Character();local profile=C.Guide.profile
    local mismatch=char.race~=profile.race or char.class~=profile.class
    self.profile:SetText("Guide profile: "..C.Text(profile.race).." "..C.Text(profile.class).." · pack "..C.Guide.revision:sub(1,8)..(mismatch and "\nDurotar adapts to your race/class. Other chapters use the exported profile; export a route for this character to change those chapters." or ""))
end
function U:ChooseSound(event)
    if not self.soundPicker then
        local f=self:Panel("GroupGainsSoundPicker",390,460);self.soundPicker=f
        f.title=self:Label(f,16);f.title:SetPoint("TOPLEFT",18,-18);f.title:SetWidth(335)
        f.scroll,f.content=self:Scroll(f,18,-55,330,380);f.rows={}
    end
    local f=self.soundPicker;local items=event=="channel" and C.Audio.channels or C.Audio.sounds
    f.title:SetText(event=="channel" and "Choose sound channel" or "Choose "..event:lower().." sound")
    for _,row in ipairs(f.rows) do row:Hide() end
    for i,item in ipairs(items) do
        local row=f.rows[i]
        if not row then row=self:Button(f.content,"",328);f.rows[i]=row end
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(i-1)*32);row:SetText(item.label)
        row:SetScript("OnClick",function()
            C.State.data.settings[event=="channel" and "audioChannel" or "audio"..event.."Sound"]=item.id
            self:RenderUISettings();f:Hide()
        end);row:Show()
    end
    f.content:SetHeight(math.max(1,#items*32));f.scroll:SetVerticalScroll(0);self:ShowPanel(f)
end
function U:SettingCheck(parent,key,label,y,changed)
    local check=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");check:SetSize(26,26);check:SetPoint("TOPLEFT",0,y)
    local text=self:Label(parent,12);text:SetPoint("LEFT",check,"RIGHT",6,0);text:SetWidth(460);text:SetText(label)
    check:SetScript("OnClick",function()C.State.data.settings[key]=not C.State.data.settings[key];if changed then changed() end end)
    return check
end
function U:CreateAuto(p)
    local title=self:Label(p,16);title:SetPoint("TOPLEFT",0,0);title:SetText("Quest automation and party sharing")
    self.autoOptions={}
    for i,spec in ipairs({{"autoEnabled","Enable quest automation"},{"autoAccept","Accept pickups from this part or earlier parts"},{"autoTurnIn","Turn in quests scheduled for turn-in in this part"},{"autoShared","Accept quests shared by party members using GroupGains"},{"autoSharePickup","Share newly accepted quests when GroupGains party members need them"}}) do
        self.autoOptions[spec[1]]=self:SettingCheck(p,spec[1],spec[2],-30-i*45,function()self:RefreshQuickSettings();self:RenderAuto()end)
    end
    local text=self:Label(p,12);text:SetPoint("TOPLEFT",0,-310);text:SetWidth(630)
    text:SetText("NPC pickups can be in this part or an earlier part of your route; future and unlisted pickups stay manual. Turn-ins must be in this part. New pickups are shared after a GroupGains party member confirms an unfinished pickup in their current or earlier parts. Shared quests are not shared back.\n\nReward choices stay manual. Hold Shift to bypass Auto; combat also pauses it. The A button pauses automatic actions.\n\nShare Quests and the dungeon popup offer the whole shareable log, including quests outside the current part. They announce first, wait 5 seconds, then share quests 5 seconds apart. Automatic pickup sharing announces each quest after offering it.")
end
function U:RenderAuto()
    for key,check in pairs(self.autoOptions or {}) do check:SetChecked(C.State.data.settings[key]~=false) end
end
function U:OfferQuestSharing(key)
    if not self.sharePrompt then
        local f=self:Panel("GroupGainsSharePrompt",430,175);self.sharePrompt=f
        local title=self:Label(f,16);title:SetPoint("TOPLEFT",18,-18);title:SetText("Share your quests?")
        local text=self:Label(f,12);text:SetPoint("TOPLEFT",18,-52);text:SetWidth(390)
        text:SetText("Would you like to share all the quests? Announce to the party, wait 5 seconds, then share each eligible quest 5 seconds apart.")
        f.yes=self:Button(f,"Yes",110,function()
            f:Hide()
            if C.QuestShare and C.QuestShare:DungeonKey()==f.dungeonKey then C.QuestShare:StartSharing() end
        end);f.yes:SetPoint("BOTTOMLEFT",18,18)
        f.no=self:Button(f,"No",110,function()f:Hide()end);f.no:SetPoint("BOTTOMRIGHT",-18,18)
    end
    self.sharePrompt.dungeonKey=key;self:ShowPanel(self.sharePrompt)
end
