local _, C = ...
C.version = "0.9.0"
C.build = "20261029.4"
function C.Safe(value) return not (issecretvalue and issecretvalue(value)) end
function C.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok,a,b,c,d,e,f,g,h = pcall(fn,...)
    if not ok or not C.Safe(a) then return nil end
    return a,b,c,d,e,f,g,h
end
function C.Text(text)
    if not C.Safe(text) then return "" end
    return tostring(text or ""):gsub("|",""):gsub("[%c]"," ")
end
function C.Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe6c77aGroup Gains:|r "..C.Text(text)) end
end
function C.Normalize(text)
    return C.Text(text):lower():gsub("’","'"):gsub("[%p%c]"," "):gsub("%s+"," "):match("^%s*(.-)%s*$")
end
local function escape(s)
    return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('[%z\1-\31]',function(c)
        return string.format("\\u%04x",c:byte())
    end)..'"'
end
function C.JSON(value)
    local kind=type(value)
    if kind=="string" then return escape(value)
    elseif kind=="boolean" then return value and "true" or "false"
    elseif kind=="number" then return tostring(value)
    elseif kind~="table" then return "null" end
    local out={}
    if value.__array then
        for i=1,#value do out[#out+1]=C.JSON(value[i]) end
        return "["..table.concat(out,",").."]"
    end
    local keys={}
    for k in pairs(value) do if k~="__array" then keys[#keys+1]=k end end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    for _,k in ipairs(keys) do out[#out+1]=escape(tostring(k))..":"..C.JSON(value[k]) end
    return "{"..table.concat(out,",").."}"
end
function C.Now() return C.Call(GetServerTime) or C.Call(time) or 0 end
