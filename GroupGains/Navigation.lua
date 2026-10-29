local _,C=...
C.Navigation={}
local N=C.Navigation
local function xy(vector)
    if not vector then return end
    local x,y=C.Call(vector.GetXY,vector)
    if C.Safe(x) and C.Safe(y) and type(x)=="number" and type(y)=="number" then return x,y end
end
local function angle(y,x)
    if math.atan2 then return math.atan2(y,x) end
    if x>0 then return math.atan(y/x) end
    if x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) end
    return y>0 and math.pi/2 or y<0 and -math.pi/2 or 0
end
function N:Remove()
    self.point=nil;self.world=nil;self.continent=nil
    if self.arrow then self.arrow:Hide() end
    if self.pin then self.pin:Hide() end
end
function N:World(map,x,y)
    if not C_Map or not CreateVector2D then return end
    return C.Call(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
end
function N:Direction()
    local p=self.point;if not p then return end
    local map=C_Map and C.Call(C_Map.GetBestMapForUnit,"player")
    local position=map and C.Call(C_Map.GetPlayerMapPosition,map,"player")
    local px,py=xy(position);if not px then return end
    local continent,world=self:World(map,px,py)
    if not continent or continent~=self.continent then return end
    local x,y=xy(world);local tx,ty=xy(self.world);if not x or not tx then return end
    -- Derive north and east from the current map instead of assuming world axes.
    local _,north=self:World(map,px,py-.001);local nx,ny=xy(north)
    local _,east=self:World(map,px+.001,py);local ex,ey=xy(east)
    if not nx or not ex then return end
    nx,ny,ex,ey=nx-x,ny-y,ex-x,ey-y
    local nl,el=math.sqrt(nx*nx+ny*ny),math.sqrt(ex*ex+ey*ey)
    if nl==0 or el==0 then return end
    local dx,dy=tx-x,ty-y
    local facing=C.Call(GetPlayerFacing);if type(facing)~="number" then return end
    local northward=(dx*nx+dy*ny)/nl;local eastward=(dx*ex+dy*ey)/el
    return math.sqrt(dx*dx+dy*dy),angle(-eastward,northward)-facing
end
function N:CreateArrow()
    if self.arrow then return end
    local f=CreateFrame("Button","GroupGainsArrow",UIParent);self.arrow=f
    f:SetSize(184,132);f:SetFrameStrata("MEDIUM");f:SetClampedToScreen(true)
    f:SetPoint("TOP",UIParent,"TOP",0,-100)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:RegisterForClicks("RightButtonUp")
    f:SetScript("OnClick",function(_,button)if button=="RightButton" then self:Remove() end end)
    f:SetScript("OnDragStart",function()f:StartMoving()end)
    f:SetScript("OnDragStop",function()f:StopMovingOrSizing();C.State.data.arrowPosition={x=f:GetLeft(),y=f:GetTop()}end)
    local pos=C.State.data.arrowPosition
    if pos then f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",pos.x,pos.y) end
    f.title=C.UI:Label(f,11);f.title:SetPoint("TOPLEFT",6,-5);f.title:SetWidth(172);f.title:SetJustifyH("CENTER")
    f.distance=C.UI:Label(f,12);f.distance:SetPoint("BOTTOMLEFT",6,8);f.distance:SetWidth(172);f.distance:SetJustifyH("CENTER")
    for _,label in ipairs({f.title,f.distance}) do label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1,-1) end
    f.pointer=f:CreateTexture(nil,"ARTWORK");f.pointer:SetSize(76,76);f.pointer:SetPoint("CENTER",0,-4)
    f.pointer:SetTexture("Interface\\AddOns\\GroupGains\\Media\\WaypointArrow")
    C.UI:Tip(f,"Group Gains waypoint","Drag to move the arrow. Right-click here or the gold map marker to remove it. Distance is straight-line yards.")
    local elapsed=0
    f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>=.1 then elapsed=0;self:Update()end end)
end
function N:DrawArrow(rotation)
    self.arrow.pointer:SetRotation(rotation);self.arrow.pointer:Show()
end
function N:UpdatePin()
    local map=WorldMapFrame;local p=self.point
    if not map or not map:IsShown() or not p then if self.pin then self.pin:Hide() end;return end
    local current=C.Call(map.GetMapID,map)
    local x,y
    if current==p.mapId then x,y=p.x/100,p.y/100
    elseif self.world and self.continent then
        local id,position=C.Call(C_Map.GetMapPosFromWorldPos,self.continent,self.world,current)
        if id==current then x,y=xy(position) end
    end
    if not x or x<0 or x>1 or y<0 or y>1 then if self.pin then self.pin:Hide() end;return end
    local canvas=C.Call(map.GetCanvas,map) or map.ScrollContainer and map.ScrollContainer.Child
    if not canvas then return end
    if not self.pin then
        self.pin=CreateFrame("Button",nil,canvas);self.pin:SetSize(24,24);self.pin:RegisterForClicks("RightButtonUp")
        local bg=self.pin:CreateTexture(nil,"ARTWORK");bg:SetSize(15,15);bg:SetPoint("CENTER");bg:SetColorTexture(1,.77,.12,1);bg:SetRotation(math.pi/4)
        local dot=self.pin:CreateTexture(nil,"OVERLAY");dot:SetSize(5,5);dot:SetPoint("CENTER");dot:SetColorTexture(.15,.08,.02,1)
        self.pin:SetScript("OnClick",function(_,button)if button=="RightButton" then self:Remove() end end)
        C.UI:Tip(self.pin,"Group Gains waypoint",function()return C.Text(self.title).."\nRight-click to remove." end)
    end
    self.pin:SetParent(canvas);self.pin:SetFrameLevel(canvas:GetFrameLevel()+25)
    self.pin:ClearAllPoints();self.pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight());self.pin:Show()
end
function N:Update()
    if not self.point then return end
    local distance,rotation=self:Direction()
    if distance then
        self.arrow.distance:SetText(distance<5 and "Arrived" or string.format("%d yards",math.floor(distance+.5)))
        self:DrawArrow(rotation)
    else
        self.arrow.pointer:Hide()
        self.arrow.distance:SetText("Direction unavailable\n"..C.Text(self.point.zoneName))
    end
    self:UpdatePin()
end
function N:Set(task)
    self:Remove();self.point=task.point;self.title=task.title
    self.continent,self.world=self:World(task.point.mapId,task.point.x/100,task.point.y/100)
    self:CreateArrow();self.arrow.title:SetText(C.Text(task.title));self.arrow:Show()
    if C_Map.OpenWorldMap then C.Call(C_Map.OpenWorldMap,task.point.mapId) else C.Call(OpenWorldMap,task.point.mapId) end
    self:Update()
    C.Print(task.point.approach and "Waypoint set at the dungeon approach. Right-click the marker or arrow to remove." or "Waypoint set. Drag the arrow to move it; right-click to remove.")
end
