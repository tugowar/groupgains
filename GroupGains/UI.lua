local _,C=...
C.UI={rows={},searchButtons={},panels={}}
local U=C.UI
local colors={pickup={.22,.42,.59},objective={.55,.30,.14},turnin={.28,.43,.22},summons={.56,.45,.22}}
function U:Label(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 12,"")
    f:SetJustifyH("LEFT");f:SetWordWrap(true);return f
end
function U:Button(parent,text,w,click)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w or 90,24);b:SetText(text);b:SetScript("OnClick",click)
    b:SetScript("OnMouseDown",function()self:FocusParent(b)end);return b
end
function U:Tip(frame,title,body)
    frame:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title)
        if body then GameTooltip:AddLine(type(body)=="function" and body() or body,1,.92,.75,true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function()GameTooltip:Hide()end)
end
function U:Icon(parent,kind,title,click)
    local b=self:Button(parent,"",22,click);b:SetHeight(22)
    local texture=kind=="book" and "Interface\\Icons\\INV_Misc_Book_09" or kind=="gear" and "Interface\\Icons\\Trade_Engineering" or kind=="map" and "Interface\\Icons\\INV_Misc_Map_01"
    if texture then
        local t=b:CreateTexture(nil,"ARTWORK");t:SetSize(16,16);t:SetPoint("CENTER");t:SetTexture(texture)
    elseif kind=="invite" then
        b:SetText("+")
    elseif kind=="speaker" then
        local function bar(x,y,w,h,rotation)
            local t=b:CreateTexture(nil,"ARTWORK");t:SetColorTexture(.96,.81,.46,1);t:SetSize(w,h);t:SetPoint("CENTER",x,y)
            if rotation then t:SetRotation(rotation) end
        end
        bar(-5,0,4,6);bar(-1,0,3,12);bar(4,0,2,7);bar(8,0,2,12)
    elseif kind=="link" then
        -- Box with an outgoing arrow: geometric textures avoid missing font glyphs.
        local function line(x,y,w,h,rotate)
            local t=b:CreateTexture(nil,"ARTWORK");t:SetColorTexture(.96,.81,.46,1);t:SetSize(w,h);t:SetPoint("TOPLEFT",x,-y)
            if rotate then t:SetRotation(rotate) end
        end
        line(5,8,1,9);line(5,16,10,1);line(14,12,1,5);line(5,8,4,1)
        line(9,8,10,2,math.pi/4);line(13,4,5,2);line(17,4,2,6)
    else b:SetText(kind) end
    if kind=="speaker" or kind=="A" then
        b.slash=b:CreateTexture(nil,"OVERLAY");b.slash:SetColorTexture(1,.25,.18,1);b.slash:SetSize(21,2);b.slash:SetPoint("CENTER");b.slash:SetRotation(math.pi/4);b.slash:Hide()
    end
    self:Tip(b,title);return b
end
function U:FocusParent(frame)
    while frame and frame~=UIParent do
        for _,panel in ipairs(self.panels) do if panel==frame then self:FocusPanel(panel);return end end
        frame=frame:GetParent()
    end
end
function U:FocusPanel(frame)
    -- Keep the entire window above the other window's nested scroll/buttons.
    local ordered={}
    for _,panel in ipairs(self.panels) do if panel~=frame then ordered[#ordered+1]=panel end end
    ordered[#ordered+1]=frame;self.panels=ordered
    local level=20
    local function top(f)
        local highest=f:GetFrameLevel()
        for _,child in ipairs({f:GetChildren()}) do highest=math.max(highest,top(child)) end
        return highest
    end
    for _,panel in ipairs(ordered) do
        panel:SetFrameLevel(level);level=top(panel)+10
    end
    self:UpdateEscape()
end
function U:TopPane()
    for i=#self.panels,1,-1 do
        local panel=self.panels[i]
        if not panel.escapeIgnored and panel:IsShown() then return panel end
    end
end
function U:CloseTopPane()
    local panel=self:TopPane()
    if panel then panel:Hide() end
end
function U:UpdateEscape()
    if self.escape and not self.handlingEscape then self.escape:SetShown(self:TopPane()~=nil) end
end
function U:CreateEscapeHandler()
    if self.escape then return end
    -- Blizzard closes every registered special frame. Register one invisible
    -- dispatcher instead, so one Escape closes only our foreground pane.
    local f=CreateFrame("Frame","GroupGainsEscape",UIParent);f:Hide();self.escape=f
    f:SetScript("OnHide",function()
        if self.handlingEscape then return end
        self.handlingEscape=true;self:CloseTopPane();self.handlingEscape=false
        self:UpdateEscape()
    end)
    table.insert(UISpecialFrames,"GroupGainsEscape")
end
function U:ShowPanel(frame)
    frame:Show();self:FocusPanel(frame)
end
function U:Panel(name,w,h)
    self:CreateEscapeHandler()
    local f=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    f.escapeIgnored=name=="GroupGainsTracker" or name=="GroupGainsMinimized"
    f:SetSize(w,h);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(.075,.065,.065,1);f:SetBackdropBorderColor(.65,.48,.28,1)
    self.panels[#self.panels+1]=f;f:SetToplevel(true)
    f:SetScript("OnShow",function()self:FocusPanel(f)end)
    f:HookScript("OnHide",function()self:UpdateEscape()end)
    f:SetScript("OnMouseDown",function()self:FocusPanel(f)end)
    f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(frame)self:FocusPanel(frame);frame:StartMoving()end)
    f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
    f.close=self:Icon(f,"X","Close",function()f:Hide()end);f.close:SetPoint("TOPRIGHT",-8,-8)
    return f
end
function U:Scroll(parent,x,y,w,h)
    local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    s:SetPoint("TOPLEFT",x,y);s:SetSize(w,h)
    local content=CreateFrame("Frame",nil,s);content:SetSize(w,1);s:SetScrollChild(content)
    return s,content
end
function U:Copy(title,value)
    if not self.copy then
        local f=self:Panel("GroupGainsCopy",620,330);self.copy=f
        f.title=self:Label(f,16);f.title:SetPoint("TOPLEFT",18,-18);f.title:SetWidth(550)
        local note=self:Label(f,11);note:SetPoint("TOPLEFT",18,-48);note:SetWidth(578)
        note:SetText("Ctrl+A, Ctrl+C to copy; paste into your browser. Escape closes this window.")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-82);scroll:SetPoint("BOTTOMRIGHT",-36,18)
        f.edit=CreateFrame("EditBox",nil,scroll);f.edit:SetMultiLine(true);f.edit:SetAutoFocus(false);f.edit:SetFontObject(ChatFontNormal)
        f.edit:SetWidth(554);f.edit:SetMaxLetters(0);f.edit:SetScript("OnEscapePressed",function()f:Hide()end);scroll:SetScrollChild(f.edit)
    end
    self.copy.title:SetText(title);self.copy.edit:SetText(value);self:ShowPanel(self.copy);self.copy.edit:SetFocus();self.copy.edit:HighlightText()
end
function U:Choose(mode,journal)
    if not self.chooser then
        local f=self:Panel("GroupGainsChoose",490,540);self.chooser=f
        f.title=self:Label(f,18);f.title:SetPoint("TOPLEFT",18,-18)
        f.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.search:SetSize(420,24);f.search:SetPoint("TOPLEFT",24,-53);f.search:SetAutoFocus(false)
        f.search:SetScript("OnTextChanged",function()self:RenderChoices()end)
        f.scroll,f.content=self:Scroll(f,18,-91,420,425);f.rows={}
    end
    self.chooseMode=mode;self.chooseJournal=journal
    self.chooser.title:SetText(mode=="chapter" and "Choose a chapter" or "Choose a part")
    self.chooser.search:SetText("");self:RenderChoices();self:ShowPanel(self.chooser)
end
function U:ChapterLabel(chapter)
    local levels=chapter.levels
    if type(levels)~="table" or not levels[1] then return chapter.title end
    local range=tostring(levels[1])..(levels[2] and levels[2]~=levels[1] and "–"..levels[2] or "")
    return chapter.title.." · Levels "..range
end
function U:RenderChoices()
    if not self.chooser then return end
    for _,r in ipairs(self.chooser.rows) do r:Hide() end
    local chapter=self.chooseJournal and C.State.chapters[self.journalChapter] or C.State:Current()
    local items=self.chooseMode=="chapter" and C.Guide.chapters or chapter.parts
    local term=self.chooser.search:GetText():lower();local n=0
    for _,item in ipairs(items) do
        local label=self.chooseMode=="chapter" and self:ChapterLabel(item) or string.format("%02d  ",item.number)..item.title
        local complete=false
        if self.chooseMode=="part" then
            local done,total=C.State:Progress(item);complete=total>0 and done==total
            label=(complete and "[Done]" or "["..done.."/"..total.."]").."  "..label
        end
        if label:lower():find(term,1,true) then
            n=n+1;local r=self.chooser.rows[n]
            if not r then r=self:Button(self.chooser.content,"",418);self.chooser.rows[n]=r end
            r:SetPoint("TOPLEFT",0,-(n-1)*38);r:SetHeight(34)
            r:SetText(label)
            r.completed=complete
            -- Native button art, grayed without disabling navigation.
            for _,region in ipairs({r:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    region:SetDesaturated(complete)
                    region:SetVertexColor(complete and .7 or 1,complete and .7 or 1,complete and .7 or 1)
                end
            end
            r:GetFontString():SetTextColor(complete and .72 or 1,complete and .72 or .82,complete and .72 or 0)
            local text=r:GetFontString();text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"");text:SetWidth(398);text:SetWordWrap(true)
            r:SetScript("OnClick",function()
                if self.chooseJournal then
                    if self.chooseMode=="chapter" then self.journalChapter=item.id;self.journalPart=item.parts[1].id else self.journalPart=item.id end
                    self:RenderJournal()
                elseif self.chooseMode=="chapter" then C.State:Select(item.id) else C.State:Select(chapter.id,item.id) end
                self.chooser:Hide()
            end);r:Show()
        end
    end
    self.chooser.content:SetHeight(math.max(1,n*38))
end
function U:Next(delta)
    local chapter,part=C.State:Current()
    for i,p in ipairs(chapter.parts) do
        if p==part and chapter.parts[i+delta] then C.State:Select(chapter.id,chapter.parts[i+delta].id);return end
    end
end
function U:NextChapter(delta)
    local current=C.State:Current()
    for i,chapter in ipairs(C.Guide.chapters) do
        local nextChapter=C.Guide.chapters[i+delta]
        if chapter==current and nextChapter then C.State:Select(nextChapter.id);return end
    end
end
function U:TaskMetadata(task)
    local lines={}
    if task.questId then
        local giver=task.kind=="turnin" and task.turnInNpc or task.questGiver
        if (not giver or giver=="") and (task.kind=="pickup" or task.kind=="turnin") then giver=task.point and task.point.label end
        lines[#lines+1]=(task.kind=="turnin" and "Turn in: " or "Questgiver: ")..C.Text(giver and giver~="" and giver or "Not recorded").." · Min level "..(task.minLevel~=nil and tostring(task.minLevel) or "unknown")
    end
    local p=task.point
    if p and type(p.x)=="number" and type(p.y)=="number" then lines[#lines+1]=C.Text(p.zoneName or p.zone).." · "..string.format("%.1f, %.1f",p.x,p.y)
    elseif task.questId then lines[#lines+1]="Coordinates not recorded" end
    return table.concat(lines,"\n")
end
function U:TaskText(task)
    local progress=C.State:ObjectiveProgress(task)
    return C.Text(task.title)..(task.questId and " #"..task.questId or "")..(task.questLevel and " · Quest level "..task.questLevel or "")..(progress and "\nProgress: "..progress or "").."\n"..self:TaskMetadata(task).."\n"..C.Text(task.note)
end
function U:RefreshTaskTooltip()
    local frame=self.hoveredTask
    if not frame then return end
    if not frame:IsVisible() or not frame.task then
        self.hoveredTask=nil
        if C.PartyProgress then C.PartyProgress:Watch(nil) end
        GameTooltip:Hide();return
    end
    local task=frame.task
    if C.PartyProgress then C.PartyProgress:Watch(task.id) end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:SetText(C.Text(task.title))
    GameTooltip:AddLine(self:TaskText(task),1,.92,.75,true)
    if C.PartyProgress then
        GameTooltip:AddLine(" ");GameTooltip:AddLine("Party task progress",1,.82,.35)
        for _,line in ipairs(C.PartyProgress:Lines(task)) do GameTooltip:AddLine(line,.9,.9,.85,true) end
        GameTooltip:AddLine("Live sharing needs GroupGains and Party enabled on both players.",.7,.7,.7,true)
    end
    GameTooltip:AddLine("Click for instructions.",.7,.7,.7,true);GameTooltip:Show()
end
function U:TaskTooltip(frame,task)
    frame.task=task
    frame:SetScript("OnEnter",function()
        frame.tipElapsed=0;self.hoveredTask=frame;self:RefreshTaskTooltip()
        if C.PartyProgress then C.Social:Tick() end
    end)
    local function leave()
        if self.hoveredTask==frame then
            self.hoveredTask=nil
            if C.PartyProgress then C.PartyProgress:Watch(nil) end
            GameTooltip:Hide()
        end
    end
    frame:SetScript("OnLeave",leave);frame:SetScript("OnHide",leave)
    frame:SetScript("OnUpdate",function(_,elapsed)
        if self.hoveredTask~=frame then return end
        frame.tipElapsed=(frame.tipElapsed or 0)+elapsed
        if frame.tipElapsed>=.5 then frame.tipElapsed=0;self:RefreshTaskTooltip() end
    end)
end
function U:GuideLink(task)
    local chapter=C.State.chapters[task.chapterId]
    if chapter then self:Copy("Open the guide in your browser",chapter.url..(task.webStop and "#stop-"..task.webStop or "")) end
end
function U:Details(task)
    if not task then return end
    C.State.data.selectedTask=task.id
    if not self.taskWindow then
        local f=self:Panel("GroupGainsTask",460,340);self.taskWindow=f
        f.scroll,f.content=self:Scroll(f,18,-38,404,237)
        f.text=self:Label(f.content,12);f.text:SetPoint("TOPLEFT",0,0);f.text:SetWidth(400);f.text:SetJustifyV("TOP")
        f.discord=self:Button(f,"Copy summon Discord",180,function()local t=C.State.tasks[self.detailTask];if t and t.discord then self:Copy("Find an in-game summon on Discord",t.discord) end end);f.discord:SetPoint("BOTTOMLEFT",18,18)
    end
    self.detailTask=task.id;self.taskWindow.text:SetText(self:TaskText(task));self.taskWindow.content:SetHeight(self.taskWindow.text:GetStringHeight()+8);self.taskWindow.scroll:SetVerticalScroll(0);self.taskWindow.discord:SetShown(task.discord~=nil);self:ShowPanel(self.taskWindow)
end
function U:TaskRows(content,rows,part,width,hideCompleted)
    local y=0;local i=0
    for _,task in ipairs(part.tasks) do
        if not hideCompleted or not C.State:Done(task) then
        i=i+1
        local r=rows[i]
        if not r then
            r=CreateFrame("Frame",nil,content);r.bg=r:CreateTexture(nil,"BACKGROUND");r.bg:SetAllPoints()
            r.check=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate");r.check:SetSize(24,24);r.check:SetPoint("TOPLEFT",2,-17);r.check:RegisterForClicks("LeftButtonUp","RightButtonUp")
            r.select=CreateFrame("Button",nil,r);r.select:SetPoint("TOPLEFT",29,-5)
            r.kind=self:Label(r.select,9);r.kind:SetPoint("TOPLEFT")
            r.title=self:Label(r.select,11);r.title:SetPoint("TOPLEFT",0,-14)
            r.meta=self:Label(r.select,10);r.meta:SetTextColor(.85,.83,.75)
            r.link=self:Icon(r,"link","Copy guide link",nil);r.link:SetPoint("TOPRIGHT",-3,-4)
            r.map=self:Icon(r,"map","See on map",nil);r.map:SetPoint("TOPRIGHT",-3,-29)
            r.auto=self:Icon(r,"A","Resume automatic quest tracking",nil);r.auto:SetPoint("TOPRIGHT",-28,-4)
            rows[i]=r
        end
        local manual=C.State.data.overrides[task.id]~=nil
        r:ClearAllPoints();r:SetPoint("TOPLEFT",0,-y);r:SetWidth(width)
        local rgb=colors[task.kind] or {.29,.23,.38};r.bg:SetColorTexture(rgb[1],rgb[2],rgb[3],.4)
        local tw=width-62;r.select:SetWidth(tw);r.kind:SetWidth(tw-(manual and 24 or 0));r.title:SetWidth(tw);r.meta:SetWidth(tw)
        r.kind:SetText(task.kind:upper():gsub("_"," ")..(task.optional and " · OPTIONAL" or "")..(manual and " · MANUAL" or ""))
        local progress=C.State:ObjectiveProgress(task)
        r.title:SetText(C.Text(task.title)..(progress and " · |cffffffff"..progress.."|r" or "")..(task.questId and " |cffb5a995#"..task.questId.."|r" or ""))
        local titleHeight=math.max(13,r.title:GetStringHeight())
        r.meta:ClearAllPoints();r.meta:SetPoint("TOPLEFT",0,-(17+titleHeight));r.meta:SetText(self:TaskMetadata(task))
        local height=math.max(58,24+titleHeight+r.meta:GetStringHeight())
        r:SetHeight(height);r.select:SetHeight(height-10);y=y+height+3
        r.check:SetChecked(C.State:Done(task))
        r.check:SetScript("OnClick",function(_,mouse)if mouse=="RightButton" then C.API:RestoreAutomatic(task.id) else C.State:Set(task.id,not C.State:Done(task)) end end)
        r.auto:SetShown(manual);r.auto:SetScript("OnClick",function()C.API:RestoreAutomatic(task.id)end)
        r.link:SetScript("OnClick",function()self:GuideLink(task)end);r.map:SetScript("OnClick",function()C.API:Map(task)end)
        r.select:SetScript("OnClick",function()self:Details(task)end)
        self:TaskTooltip(r.select,task)
        r:Show()
        end
    end
    for n=i+1,#rows do rows[n]:Hide() end
    self:RefreshTaskTooltip()
    content:SetHeight(math.max(1,y))
end
function U:SearchButton(parent,width)
    local b=self:Button(parent,"Search now",width,function()C.Social:RequestSearch();self:RenderMatches()end)
    self:Tip(b,"Find companions",function()return C.Social:SearchStatus() end)
    self.searchButtons[#self.searchButtons+1]=b;return b
end
function U:RenderMatches()
    if not self.frame then return end
    local count=#C.Social:Matches()
    if C.Social.NotifyMatches then C.Social:NotifyMatches(count) end
    self.matches:SetText(count==1 and "1 person is leveling just like you!" or count.." people are leveling just like you!")
    local remaining=C.Social:SearchRemaining()
    for _,b in ipairs(self.searchButtons) do b:SetText(remaining>0 and "Search ("..remaining.."s)" or "Search now");b:SetEnabled(remaining==0) end
    if self.RenderFinder then self:RenderFinder() end
    if self.RenderAudience then self:RenderAudience() end
end
function U:Render()
    if not self.frame then return end
    local chapter,part=C.State:Current();local done,total=C.State:Progress(part)
    self.chapter:SetText(chapter.title);self.part:SetText(string.format("%02d · %s",part.number,part.title))
    self.progress:SetText(done.."/"..total.." Completed"..(total>0 and done==total and " · Part complete" or ""))
    self:RefreshQuickSettings()
    if self.renderedPart~=part.id then self.scroll:SetVerticalScroll(0);self.renderedPart=part.id end
    self:TaskRows(self.content,self.rows,part,356,not C.State.data.settings.showCompletedTasks)
    self.scroll:SetVerticalScroll(math.min(self.scroll:GetVerticalScroll(),math.max(0,self.content:GetHeight()-self.scroll:GetHeight())))
    self.showCompleted:SetText(C.State.data.settings.showCompletedTasks and "Hide Completed" or "Show Completed")
    local chapterIndex,partIndex
    for i,ch in ipairs(C.Guide.chapters) do if ch==chapter then chapterIndex=i end end
    for i,p in ipairs(chapter.parts) do if p==part then partIndex=i end end
    self.prevChapter:SetEnabled(chapterIndex>1);self.nextChapter:SetEnabled(chapterIndex<#C.Guide.chapters)
    self.prevPart:SetEnabled(partIndex>1);self.nextPart:SetEnabled(partIndex<#chapter.parts)
    if self.RenderJournal then self:RenderJournal() end
    if self.chooser and self.chooser:IsShown() then self:RenderChoices() end
    if self.taskWindow and self.taskWindow:IsShown() and C.State.tasks[self.detailTask] then self.taskWindow.text:SetText(self:TaskText(C.State.tasks[self.detailTask]));self.taskWindow.content:SetHeight(self.taskWindow.text:GetStringHeight()+8) end
    self:RenderMatches()
end
function U:ApplyDisplay(mode)
    self.applyingDisplay=true
    self.frame:SetShown(mode=="open");self.mini:SetShown(mode=="minimized")
    self.applyingDisplay=false;self.displayMode=mode
end
function U:SetDisplay(mode)
    if not self.frame then return end
    C.State.data.trackerMode=mode;C.State.data.visible=mode~="hidden"
    if self.combatActive then self.combatRestore=mode end
    self:ApplyDisplay(mode)
end
function U:Open() self:SetDisplay("open") end
function U:Toggle() self:SetDisplay(self.displayMode=="open" and "hidden" or "open") end
function U:Combat(entering)
    if not self.frame then return end
    if entering then
        if self.combatActive then return end
        self.combatActive=true;self.combatRestore=self.displayMode
        local mode=C.State.data.settings.combatMode or "minimize"
        if self.displayMode~="hidden" then
            if mode=="hide" then self:ApplyDisplay("hidden") elseif mode=="minimize" then self:ApplyDisplay("minimized") end
        end
    elseif self.combatActive then
        self.combatActive=false;self:ApplyDisplay(self.combatRestore or "open");self.combatRestore=nil
    end
end
function U:Create()
    local f=self:Panel("GroupGainsTracker",400,470);self.frame=f;f:SetFrameStrata("MEDIUM")
    local title=self:Label(f,13);title:SetPoint("TOPLEFT",12,-13);title:SetText("Group Gains")
    f.close:SetScript("OnClick",function()self:SetDisplay("hidden")end)
    self.minimize=self:Icon(f,"_","Minimize",function()self:SetDisplay("minimized")end);self.minimize:SetPoint("TOPRIGHT",-34,-8)
    self.settingsButton=self:Icon(f,"gear","Settings",function()self:OpenSettings()end);self.settingsButton:SetPoint("TOPRIGHT",-60,-8)
    self.book=self:Icon(f,"book","Dungeon guides",function()self:OpenSettings("dungeons")end);self.book:SetPoint("TOPRIGHT",-86,-8)
    self.autoToggle=self:Icon(f,"A","Toggle quest automation",function()self:ToggleSetting("autoEnabled")end);self.autoToggle:SetPoint("TOPRIGHT",-112,-8)
    self.audioToggle=self:Icon(f,"speaker","Toggle quest audio (silent switch)",function()self:ToggleSetting("audioEnabled")end);self.audioToggle:SetPoint("TOPRIGHT",-138,-8)
    self.chapter=self:Button(f,"Choose chapter",376,function()self:Choose("chapter")end);self.chapter:SetPoint("TOPLEFT",12,-36);self.chapter:SetHeight(30)
    local chapterText=self.chapter:GetFontString();chapterText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"");chapterText:SetWidth(356);chapterText:SetWordWrap(true)
    self:Tip(self.chapter,"Change chapter",function()local chapter=C.State:Current();return chapter.title end)
    self.part=self:Button(f,"Choose part",376,function()self:Choose("part")end);self.part:SetPoint("TOPLEFT",12,-70);self.part:SetHeight(30)
    local partText=self.part:GetFontString();partText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"");partText:SetWidth(356);partText:SetWordWrap(true)
    self:Tip(self.part,"Change part",function()local _,p=C.State:Current();return p.title end)
    self.progress=self:Label(f,10);self.progress:SetPoint("TOPLEFT",12,-106)
    self.scroll,self.content=self:Scroll(f,12,-124,356,240)
    local specs={{"prevChapter","<< Chapter",64,function()self:NextChapter(-1)end},{"prevPart","< Part",39,function()self:Next(-1)end},
        {"showCompleted","Show Completed",112,function()C.State.data.settings.showCompletedTasks=not C.State.data.settings.showCompletedTasks;self.scroll:SetVerticalScroll(0);self:Render()end},
        {"sync","Sync",36,function()C.API:Sync()end},
        {"nextPart","Part >",39,function()self:Next(1)end},{"nextChapter","Chapter >>",64,function()self:NextChapter(1)end}}
    local x=12
    for _,spec in ipairs(specs) do
        local b=self:Button(f,spec[2],spec[3],spec[4]);self[spec[1]]=b;b:SetPoint("BOTTOMLEFT",x,71);x=x+spec[3]+4
        b:GetFontString():SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",9,"")
    end
    self.matches=self:Label(f,11);self.matches:SetPoint("BOTTOMLEFT",12,51);self.matches:SetWidth(376)
    self.finderButton=self:Button(f,"See who is leveling",226,function()self:OpenFinder()end);self.finderButton:SetPoint("BOTTOMLEFT",12,18)
    self.share=self:Button(f,"Share Quests",144,function()
        if C.QuestShare then
            if C.QuestShare.session then C.QuestShare:Cancel("Quest sharing stopped.") else C.QuestShare:StartSharing() end
        end
    end);self.share:SetPoint("BOTTOMRIGHT",-12,18)
    self:Tip(self.share,"Share quests with your party","Announce in party chat, wait 5 seconds, then offer each shareable quest in your log 5 seconds apart. Click again to stop.")
    self.versionLabel=self:Label(f,9);self.versionLabel:SetPoint("BOTTOMRIGHT",-12,5);self.versionLabel:SetSize(376,11)
    self.versionLabel:SetJustifyH("RIGHT");self.versionLabel:SetTextColor(.80,.75,.65)
    self.versionLabel:SetText("v"..C.version.." · build "..C.build)
    local mini=self:Panel("GroupGainsMinimized",190,34);self.mini=mini;mini:SetFrameStrata("MEDIUM")
    mini:ClearAllPoints();mini:SetPoint("TOPLEFT",f,"TOPLEFT")
    local restore=self:Button(mini,"Group Gains",148,function()self:Open()end);restore:SetPoint("TOPLEFT",6,-5)
    self:Tip(restore,"Restore tracker");mini.close:SetScript("OnClick",function()self:SetDisplay("hidden")end)
    local function dragMini()mini:StartMoving()end
    local function stopMini()
        mini:StopMovingOrSizing()
        local x,y=mini:GetLeft(),mini:GetTop()
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
        mini:ClearAllPoints();mini:SetPoint("TOPLEFT",f,"TOPLEFT")
        C.State.data.position={x=x,y=y}
    end
    restore:RegisterForDrag("LeftButton");restore:SetScript("OnDragStart",dragMini);restore:SetScript("OnDragStop",stopMini)
    mini:SetScript("OnDragStart",dragMini);mini:SetScript("OnDragStop",stopMini)
    local pos=C.State.data.position;if pos then f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",pos.x,pos.y) end
    f:SetScript("OnDragStop",function()f:StopMovingOrSizing();C.State.data.position={x=f:GetLeft(),y=f:GetTop()}end)
    local function hidden()if not self.applyingDisplay then self:SetDisplay("hidden") end end
    f:SetScript("OnHide",hidden);mini:SetScript("OnHide",hidden)
    self:Render();self:ApplyDisplay(C.State.data.trackerMode or (C.State.data.visible==false and "hidden" or "open"))
    if C.Call(InCombatLockdown) then self:Combat(true) end
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1,function()self:RenderMatches()end) end
end
function U:ToggleSetting(key)
    local s=C.State.data.settings;s[key]=s[key]==false
    self:RefreshQuickSettings()
    if self.RenderUISettings then self:RenderUISettings() end
    if self.RenderAuto then self:RenderAuto() end
end
function U:RefreshQuickSettings()
    local s=C.State.data.settings
    if self.audioToggle then self.audioToggle.slash:SetShown(s.audioEnabled==false) end
    if self.autoToggle then self.autoToggle.slash:SetShown(s.autoEnabled==false) end
    if self.frame then self.frame:SetBackdropColor(.075,.065,.065,s.trackerOpacity or .5) end
end
