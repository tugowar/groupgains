local _,C=...
C.UI={rows={}}
local U=C.UI
local colors={pickup={.22,.42,.59},objective={.55,.30,.14},turnin={.28,.43,.22},summons={.56,.45,.22}}
local function label(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 12,"")
    f:SetJustifyH("LEFT");f:SetWordWrap(true)
    return f
end
local function button(parent,text,w,click)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w or 90,24);b:SetText(text);b:SetScript("OnClick",click);return b
end
local function panel(name,w,h)
    local f=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    f:SetSize(w,h);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=false,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(.075,.065,.065,.97);f:SetBackdropBorderColor(.65,.48,.28,1)
    f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self)self:StartMoving()end)
    f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-2,-2)
    table.insert(UISpecialFrames,name)
    return f
end
function U:Copy(title,value)
    if not self.copy then
        local f=panel("GroupGainsCopy",620,330);self.copy=f
        f.title=label(f,16);f.title:SetPoint("TOPLEFT",18,-18)
        f.note=label(f,11);f.note:SetPoint("TOPLEFT",18,-46);f.note:SetWidth(578)
        f.note:SetText("Ctrl+A, Ctrl+C to copy; paste into your browser. Escape closes this window.")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-82);scroll:SetPoint("BOTTOMRIGHT",-36,18)
        f.edit=CreateFrame("EditBox",nil,scroll)
        f.edit:SetMultiLine(true);f.edit:SetAutoFocus(false);f.edit:SetFontObject(ChatFontNormal)
        f.edit:SetWidth(554);f.edit:SetMaxLetters(0);f.edit:SetScript("OnEscapePressed",function()f:Hide()end)
        scroll:SetScrollChild(f.edit)
    end
    self.copy.title:SetText(title);self.copy.edit:SetText(value)
    self.copy:Show();self.copy.edit:SetFocus();self.copy.edit:HighlightText()
end
function U:Choose(mode)
    if not self.chooser then
        local f=panel("GroupGainsChoose",490,540);self.chooser=f
        f.title=label(f,18);f.title:SetPoint("TOPLEFT",18,-18)
        f.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
        f.search:SetSize(420,24);f.search:SetPoint("TOPLEFT",24,-53);f.search:SetAutoFocus(false)
        f.search:SetScript("OnTextChanged",function()self:RenderChoices()end)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-91);scroll:SetPoint("BOTTOMRIGHT",-36,20)
        f.content=CreateFrame("Frame",nil,scroll);f.content:SetWidth(420);scroll:SetScrollChild(f.content)
        f.rows={}
    end
    self.chooseMode=mode;self.chooser.title:SetText(mode=="chapter" and "Choose a chapter" or "Choose a part")
    self.chooser.search:SetText("");self:RenderChoices();self.chooser:Show()
end
function U:RenderChoices()
    if not self.chooser then return end
    for _,row in ipairs(self.chooser.rows) do row:Hide() end
    local chapter=C.State:Current()
    local items=self.chooseMode=="chapter" and C.Guide.chapters or chapter.parts
    local term=self.chooser.search:GetText():lower()
    local n=0
    for _,item in ipairs(items) do
        if item.title:lower():find(term,1,true) then
            n=n+1
            local row=self.chooser.rows[n]
            if not row then row=button(self.chooser.content,"",418);self.chooser.rows[n]=row end
            row:SetPoint("TOPLEFT",0,-(n-1)*36);row:SetHeight(32)
            row:SetText((self.chooseMode=="part" and string.format("%02d  ",item.number) or "")..item.title)
            local chosen=item
            row:SetScript("OnClick",function()
                if self.chooseMode=="chapter" then C.State:Select(chosen.id)
                else C.State:Select(chapter.id,chosen.id) end
                self.chooser:Hide()
            end)
            row:Show()
        end
    end
    self.chooser.content:SetHeight(math.max(1,n*36))
end
function U:Next(delta)
    local chapter,part=C.State:Current()
    for i,p in ipairs(chapter.parts) do
        if p==part and chapter.parts[i+delta] then C.State:Select(chapter.id,chapter.parts[i+delta].id);return end
    end
    if delta>0 then self:Choose("chapter") end
end
function U:Details(task)
    C.State.data.selectedTask=task.id
    local text=C.Text(task.title)
    if task.questId then text=text.."  #"..task.questId end
    if task.questLevel then text=text.." · Quest level "..task.questLevel end
    local p=task.point
    if p then text=text.."\n"..C.Text(p.zoneName).." · "..string.format("%.1f, %.1f",p.x,p.y) end
    if task.note and task.note~="" then text=text.."\n"..C.Text(task.note) end
    self.details:SetText(text)
    self.detailText=text
    self.discord:SetShown(task.discord~=nil)
end
function U:RenderMatches()
    if not self.frame then return end
    local settings=C.State.data.settings
    self.guild:SetText(settings.guild and "Guild: on" or "Guild: off")
    self.everyone:SetText(settings.everyone and "Everyone: on" or "Everyone: off")
    self.friends:SetText(settings.friends and "Friends: on" or "Friends: off")
    local matches=C.Social:Matches()
    local lines={}
    for i=1,math.min(#matches,3) do
        local p=matches[i]
        lines[#lines+1]=C.Text(p.name).." · Lvl "..p.level.." · "..C.Text(C.State.parts[p.partId].title)
    end
    self.matches:SetText(not C.Social:Enabled() and "Matching is off. Choose who can see your chapter, part and level above." or (#lines>0 and table.concat(lines,"\n") or (C.Social:Blocked() and "Matching pauses in instances and combat." or (settings.everyone and (C.Social.everyoneStatus or "Everyone is limited to supported Group Gains channels and party/raid.") or "No recent guild/friend matches within one part. Everyone matching requires opt-in."))))
end
function U:Render()
    if not self.frame then return end
    local chapter,part=C.State:Current()
    local done,total=C.State:Progress(part)
    self.chapter:SetText(chapter.title)
    self.part:SetText(string.format("PART %02d · %s",part.number,part.title))
    self.progress:SetText(done.."/"..total.." tasks"..(done==total and " · Part complete" or "").." · Click checkbox to toggle; right-click restores automatic.")
    local char=C.API:Character()
    local mismatch=char.race~=C.Guide.profile.race or char.class~=C.Guide.profile.class
    self.profile:SetText((mismatch and "|cffff8b73Different character! Rebuild the website route pack. " or "|cffb5a995")..C.Guide.profile.race.." "..C.Guide.profile.class.." · pack "..C.Guide.revision:sub(1,8).."|r")
    for _,row in ipairs(self.rows) do row:Hide() end
    for i,task in ipairs(part.tasks) do
        local row=self.rows[i]
        if not row then
            row=CreateFrame("Frame",nil,self.content,"BackdropTemplate")
            row:SetSize(420,56)
            row.bg=row:CreateTexture(nil,"BACKGROUND");row.bg:SetAllPoints()
            row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.check:SetSize(26,26);row.check:SetPoint("TOPLEFT",5,-15);row.check:RegisterForClicks("LeftButtonUp","RightButtonUp")
            row.select=CreateFrame("Button",nil,row);row.select:SetPoint("TOPLEFT",37,-5);row.select:SetSize(370,48)
            row.kind=label(row.select,10);row.kind:SetPoint("TOPLEFT",0,0);row.kind:SetWidth(368)
            row.title=label(row.select,12);row.title:SetPoint("TOPLEFT",0,-17);row.title:SetWidth(368)
            self.rows[i]=row
        end
        row:SetPoint("TOPLEFT",0,-(i-1)*60)
        local rgb=colors[task.kind] or {.29,.23,.38}
        row.bg:SetColorTexture(rgb[1],rgb[2],rgb[3],.65)
        row.kind:SetText(task.kind:upper():gsub("_"," ")..(task.optional and " · OPTIONAL" or "")..(C.State.data.overrides[task.id]~=nil and " · MANUAL" or ""))
        row.title:SetText(C.Text(task.title)..(task.questId and " |cffb5a995#"..task.questId.."|r" or ""))
        row.check:SetChecked(C.State:Done(task))
        row.check:SetScript("OnClick",function(_,mouse)
            if mouse=="RightButton" then C.State:Set(task.id,nil)
            else C.State:Set(task.id,not C.State:Done(task)) end
        end)
        row.select:SetScript("OnClick",function()self:Details(task)end)
        row:Show()
    end
    self.content:SetHeight(math.max(1,#part.tasks*60))
    self:Details(C.State.tasks[C.State.data.selectedTask] or part.tasks[1])
    self:RenderMatches()
end
function U:Create()
    local f=panel("GroupGainsTracker",470,700);self.frame=f
    f:SetFrameStrata("MEDIUM");f:SetClampedToScreen(true)
    local icon=f:CreateTexture(nil,"ARTWORK");icon:SetSize(56,56);icon:SetPoint("TOPLEFT",9,-6);icon:SetTexture("Interface\\AddOns\\GroupGains\\Media\\GroupGains")
    local title=label(f,22);title:SetPoint("TOPLEFT",69,-14);title:SetText("Group Gains")
    local subtitle=label(f,11);subtitle:SetPoint("TOPLEFT",70,-39);subtitle:SetWidth(360);subtitle:SetText("Find your leveling group on the fly")
    self.profile=label(f,10);self.profile:SetPoint("TOPLEFT",16,-66);self.profile:SetWidth(435)
    self.chapter=button(f,"Choose chapter",432,function()self:Choose("chapter")end);self.chapter:SetPoint("TOPLEFT",16,-86)
    self.part=button(f,"Choose part",432,function()self:Choose("part")end);self.part:SetPoint("TOPLEFT",16,-116);self.part:SetHeight(33)
    self.progress=label(f,10);self.progress:SetPoint("TOPLEFT",16,-154);self.progress:SetWidth(436)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-182);scroll:SetPoint("TOPRIGHT",-34,-182);scroll:SetHeight(240)
    self.content=CreateFrame("Frame",nil,scroll);self.content:SetSize(420,1);scroll:SetScrollChild(self.content)
    self.details=label(f,11);self.details:SetPoint("TOPLEFT",16,-433);self.details:SetSize(435,75);self.details:SetJustifyV("TOP")
    local help=CreateFrame("Frame",nil,f)
    help:SetAllPoints(self.details);help:EnableMouse(true)
    help:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Task instructions")
        GameTooltip:AddLine(U.detailText or "",1,.92,.75,true);GameTooltip:Show()
    end)
    help:SetScript("OnLeave",function()GameTooltip:Hide()end)
    self.map=button(f,"See on map",100,function()local t=C.State.tasks[C.State.data.selectedTask];if t then C.API:Map(t)end end);self.map:SetPoint("TOPLEFT",16,-514)
    self.web=button(f,"Guide link",90,function()local ch=C.State:Current();local t=C.State.tasks[C.State.data.selectedTask];self:Copy("Open the guide in your browser",ch.url.."#stop-"..t.webStop)end);self.web:SetPoint("LEFT",self.map,"RIGHT",6,0)
    self.discord=button(f,"Copy summon Discord",168,function()local t=C.State.tasks[C.State.data.selectedTask];if t and t.discord then self:Copy("Find an in-game summon on Discord",t.discord)end end);self.discord:SetPoint("LEFT",self.web,"RIGHT",6,0)
    local prev=button(f,"Previous part",110,function()self:Next(-1)end);prev:SetPoint("TOPLEFT",16,-546)
    local next=button(f,"Next part",100,function()self:Next(1)end);next:SetPoint("LEFT",prev,"RIGHT",6,0)
    local export=button(f,"Export progress",138,function()self:Copy("Copy progress for Cohort Gaming",C.JSON(C.State:Export()))end);export:SetPoint("TOPLEFT",244,-546)
    self.guild=button(f,"Guild: on",102,function()C.Social:SetAudience("guild",not C.State.data.settings.guild)end);self.guild:SetPoint("TOPLEFT",16,-581)
    self.friends=button(f,"Friends: on",104,function()C.Social:SetAudience("friends",not C.State.data.settings.friends)end);self.friends:SetPoint("LEFT",self.guild,"RIGHT",6,0)
    self.everyone=button(f,"Everyone: off",188,function()C.Social:SetAudience("everyone",not C.State.data.settings.everyone)end);self.everyone:SetPoint("LEFT",self.friends,"RIGHT",6,0)
    self.everyone:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Everyone matching · opt-in")
        GameTooltip:AddLine("Share your chapter, part and level with other opted-in Group Gains users on the dedicated channel and in your party/raid. Reach is limited by the client and realm; this is not an all-realms directory.",1,.92,.75,true)
        GameTooltip:AddLine(C.Social.everyoneStatus or "Off until you enable it. Guild and friend matching are separate.",.8,.8,.8,true);GameTooltip:Show()
    end)
    self.everyone:SetScript("OnLeave",function()GameTooltip:Hide()end)
    self.matches=label(f,10);self.matches:SetPoint("TOPLEFT",16,-614);self.matches:SetSize(432,62);self.matches:SetJustifyV("TOP")
    local pos=C.State.data.position
    if pos then f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",pos.x,pos.y) end
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();C.State.data.position={x=self:GetLeft(),y=self:GetTop()}
    end)
    self:Render()
    f:SetShown(C.State.data.visible~=false)
    f:SetScript("OnHide",function()C.State.data.visible=false end)
    f:SetScript("OnShow",function()C.State.data.visible=true end)
end
function U:Toggle()
    if not self.frame then return end
    self.frame:SetShown(not self.frame:IsShown())
end
