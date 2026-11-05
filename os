-- TRAPPED loader. It keeps a copy of itself as TRAPPED.lua in your executor's workspace folder
-- (needed for the re-run after teleport), then starts the script below.
local SRC=[=====[





local BOOT_FILE="TRAPPED_boot.log"
local bootLines={}
local function bootLog(msg)
    local line=os.date("%H:%M:%S").." [main] "..tostring(msg)
    bootLines[#bootLines+1]=line
    pcall(function()
        if type(appendfile)=="function" then appendfile(BOOT_FILE,line.."\n")
        elseif type(writefile)=="function" then
            local old=(type(isfile)=="function" and isfile(BOOT_FILE) and readfile(BOOT_FILE)) or ""
            writefile(BOOT_FILE,old..line.."\n")
        end
    end)
end

pcall(function()
    if type(isfile)=="function" and type(readfile)=="function" and isfile(BOOT_FILE) then
        local t=readfile(BOOT_FILE)
        if #t>40000 then
            local ls={}
            for l in t:gmatch("[^\n]+") do ls[#ls+1]=l end
            writefile(BOOT_FILE,table.concat(ls,"\n",math.max(1,#ls-150)).."\n")
        end
    end
end)
local function getgenvSafe() return (type(getgenv)=="function") and getgenv() or _G end
local BOOT=getgenvSafe().__TRAPPED_BOOT      
pcall(function() getgenvSafe().__TRAPPED_BOOT=nil end)
local bootReason=(type(BOOT)=="table" and BOOT.reason) or "manual"
bootLog("──── boot reason="..bootReason.." place="..tostring(game.PlaceId)
    .." job="..tostring(game.JobId):sub(1,8))
pcall(function()
    local name,ver=(identifyexecutor or getexecutorname or function() return "unknown" end)()
    bootLog("executor="..tostring(name).." "..tostring(ver or ""))
end)
if type(BOOT)=="table" and BOOT.fromPlace then
    bootLog("re-run after teleport from place="..tostring(BOOT.fromPlace).." (stub waited "
        ..tostring(BOOT.waited or "?").."s)")
end


local prevUnloaded=false
pcall(function()
    local old=(type(getgenv)=="function" and getgenv().TRAPPED) or _G.TRAPPED
    if old and type(old)=="table" and old.Destroy then
        old:Destroy(); prevUnloaded=true
    end
end)
bootLog("previous instance: "..(prevUnloaded and "found and unloaded" or "none"))


local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local HttpService     = game:GetService("HttpService")
local RunService      = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local LP              = Players.LocalPlayer
if not LP then                     
    pcall(function() Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
    LP=Players.LocalPlayer
    local t0=os.clock()
    while not LP and os.clock()-t0<15 do task.wait(0.1); LP=Players.LocalPlayer end
end
if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end




local SUPPORT_LINK="https://discord.gg/mxGZt84yN3"
local LICENSED={ok=true}
do
    local KA={name="Os",ownerid="5u62iZZCCC",version="1.0",api="https://keyauth.win/api/1.2/"}
    if KA.ownerid~="" and KA.name~="" then
        LICENSED.ok=false
        local reqf=(syn and syn.request) or http_request or request or (http and http.request)
        local function hwid()
            local ok,v=pcall(function() return gethwid and gethwid() end)
            if ok and v then return tostring(v) end
            ok,v=pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
            return ok and tostring(v) or "unknown"
        end
        local function enc(t)
            local out={}
            for k,v in pairs(t) do out[#out+1]=HttpService:UrlEncode(k).."="..HttpService:UrlEncode(tostring(v)) end
            return table.concat(out,"&")
        end
        local function call(t)
            if not reqf then return nil,"this executor has no HTTP request function" end
            local ok,res=pcall(reqf,{Url=KA.api,Method="POST",Headers={["Content-Type"]="application/x-www-form-urlencoded"},Body=enc(t)})
            if not ok or not res or not res.Body then return nil,"could not reach the license server" end
            local okj,j=pcall(function() return HttpService:JSONDecode(res.Body) end)
            if not okj or type(j)~="table" then return nil,"bad answer from the license server" end
            return j
        end
        local sid
        local function check(key,fresh)
            if fresh then sid=nil end
            if not sid then
                local j,e=call({type="init",ver=KA.version,name=KA.name,ownerid=KA.ownerid})
                if not j then return false,e,true end
                if not j.success then return false,tostring(j.message or "init failed") end
                sid=j.sessionid
            end
            local j,e=call({type="license",key=key,hwid=hwid(),sessionid=sid,name=KA.name,ownerid=KA.ownerid})
            if not j then return false,e,true end
            if not j.success then return false,tostring(j.message or "invalid key") end
            
            
            do
                local subs=j.info and j.info.subscriptions
                if type(subs)=="table" and #subs>0 then
                    local alive=false
                    for _,sb in ipairs(subs) do
                        local tl=tonumber(sb.timeleft)
                        local ex=tonumber(sb.expiry)
                        local dead=(tl~=nil and tl<=0) or (tl==nil and ex~=nil and ex>0 and ex<=os.time())
                        if not dead then alive=true end
                    end
                    if not alive then return false,"Key expired" end
                end
            end
            LICENSED.info=j.info; LICENSED.at=os.clock()
            LICENSED.key=key; LICENSED.hwid=hwid()
            return true,"ok"
        end
        local function nice(m)
            m=tostring(m or ""); local l=m:lower()
            if l:find("expire",1,true) or l:find("subscription",1,true) then return "Key expired. Buy a new one in our Discord." end
            if l:find("hwid",1,true) or l:find("hardware",1,true) or l:find("device",1,true) then return "Key is locked to another device. Ask support for a reset." end
            if l:find("ban",1,true) then return "This key or device is banned." end
            if l:find("pause",1,true) then return "License paused. Contact support." end
            if l:find("not found",1,true) or l:find("invalid",1,true) then return "Invalid key. Check it and try again." end
            return m
        end
        
        LICENSED.recheck=function()
            local k=LICENSED.key
            if not k then return true end
            local ok,why,net=check(k,true)
            if ok or net then return true end
            return false,why
        end
        local saved
        pcall(function() if isfile and isfile("TRAPPED_key.txt") then saved=readfile("TRAPPED_key.txt"):gsub("%s","") end end)
        if saved and saved~="" then
            local ok,why,net=check(saved)
            for _=1,2 do if ok or not net then break end task.wait(2); ok,why,net=check(saved) end
            LICENSED.ok=ok
            if not ok then LICENSED.why=nice(why) end
        end
        local function promptKey(opts)
            opts=opts or {}
            if LICENSED.promptOpen then return end          
            LICENSED.promptOpen=true
            
            local TS=game:GetService("TweenService")
            local UISv=game:GetService("UserInputService")
            local function new(cls,props,kids)
                local o=Instance.new(cls)
                for k,v in pairs(props) do o[k]=v end
                return o
            end
            local sg=new("ScreenGui",{Name=HttpService:GenerateGUID(false):sub(1,12),ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1000000})
            pcall(function() sg.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
            if not sg.Parent then sg.Parent=LP:WaitForChild("PlayerGui") end
            if opts.fade then                      
                local fl=new("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.45),Size=UDim2.fromOffset(560,60),
                    BackgroundTransparency=1,Text=opts.fade,Font=Enum.Font.GothamBold,TextSize=28,TextColor3=Color3.fromRGB(255,110,110),
                    TextStrokeTransparency=0.6,TextTransparency=1,Parent=sg})
                TS:Create(fl,TweenInfo.new(0.35),{TextTransparency=0}):Play()
                task.wait(1.7)
                TS:Create(fl,TweenInfo.new(0.6),{TextTransparency=1,TextStrokeTransparency=1}):Play()
                task.wait(0.7)
                fl:Destroy()
            end
            local dim=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,Parent=sg})
            TS:Create(dim,TweenInfo.new(0.4),{BackgroundTransparency=0.45}):Play()
            local card=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(420,330),
                BackgroundColor3=Color3.fromRGB(10,10,10),BorderSizePixel=0,Parent=sg})
            new("UICorner",{CornerRadius=UDim.new(0,18),Parent=card})
            local cst=new("UIStroke",{Color=Color3.fromRGB(60,60,60),Thickness=1,Parent=card})
            local scale=new("UIScale",{Scale=0.9,Parent=card})
            TS:Create(scale,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
            new("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(20,20,20),Color3.fromRGB(8,8,8)),Parent=card})
            local function text(props)
                local d={BackgroundTransparency=1,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=Color3.new(1,1,1),
                    TextXAlignment=Enum.TextXAlignment.Left,Parent=card}
                for k,v in pairs(props) do d[k]=v end
                return new("TextLabel",d)
            end
            
            local av=new("Frame",{Position=UDim2.fromOffset(28,26),Size=UDim2.fromOffset(52,52),BackgroundColor3=Color3.fromRGB(24,24,24),
                BorderSizePixel=0,Parent=card})
            new("UICorner",{CornerRadius=UDim.new(1,0),Parent=av})
            new("UIStroke",{Color=Color3.new(1,1,1),Thickness=2,Parent=av})
            text({Text="T",Font=Enum.Font.GothamBold,TextSize=22,TextXAlignment=Enum.TextXAlignment.Center,Position=UDim2.fromOffset(28,26),Size=UDim2.fromOffset(52,52)})
            task.spawn(function()
                pcall(function()
                    local img=Players:GetUserThumbnailAsync(LP.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
                    local pic=new("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=img,ZIndex=3,Parent=av})
                    new("UICorner",{CornerRadius=UDim.new(1,0),Parent=pic})
                end)
            end)
            text({Text="TRAPPED",Font=Enum.Font.GothamBold,TextSize=22,Position=UDim2.fromOffset(94,28),Size=UDim2.fromOffset(240,26)})
            text({Text="Welcome, "..LP.DisplayName,TextSize=12,TextColor3=Color3.fromRGB(150,150,150),Position=UDim2.fromOffset(94,56),Size=UDim2.fromOffset(240,18)})
            local x=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,18),Size=UDim2.fromOffset(28,28),
                BackgroundColor3=Color3.fromRGB(24,24,24),Text="X",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(170,170,170),
                BorderSizePixel=0,AutoButtonColor=false,Parent=card})
            new("UICorner",{CornerRadius=UDim.new(0,8),Parent=x})
            new("Frame",{Position=UDim2.fromOffset(28,96),Size=UDim2.new(1,-56,0,1),BackgroundColor3=Color3.fromRGB(40,40,40),BorderSizePixel=0,Parent=card})
            text({Text="LICENSE KEY",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=Color3.fromRGB(110,110,110),Position=UDim2.fromOffset(28,112),Size=UDim2.fromOffset(200,14)})
            local box=new("Frame",{Position=UDim2.fromOffset(28,132),Size=UDim2.new(1,-56,0,46),BackgroundColor3=Color3.fromRGB(22,22,22),BorderSizePixel=0,ClipsDescendants=true,Parent=card})
            new("UICorner",{CornerRadius=UDim.new(0,12),Parent=box})
            local bst=new("UIStroke",{Color=Color3.fromRGB(50,50,50),Thickness=1,Parent=box})
            local tb=new("TextBox",{Position=UDim2.fromOffset(16,0),Size=UDim2.new(1,-32,1,0),BackgroundTransparency=1,Text="",
                PlaceholderText="Paste your key here",PlaceholderColor3=Color3.fromRGB(100,100,100),TextColor3=Color3.new(1,1,1),
                Font=Enum.Font.Code,TextSize=13,ClearTextOnFocus=false,ClipsDescendants=true,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
            tb.Focused:Connect(function() TS:Create(bst,TweenInfo.new(0.15),{Color=Color3.new(1,1,1)}):Play() end)
            tb.FocusLost:Connect(function() TS:Create(bst,TweenInfo.new(0.15),{Color=Color3.fromRGB(50,50,50)}):Play() end)
            local dot=new("Frame",{Position=UDim2.fromOffset(30,198),Size=UDim2.fromOffset(8,8),BackgroundColor3=Color3.fromRGB(110,110,110),BorderSizePixel=0,Parent=card})
            new("UICorner",{CornerRadius=UDim.new(1,0),Parent=dot})
            local msg=text({Text=LICENSED.why or "Enter the key you bought to continue",TextColor3=Color3.fromRGB(150,150,150),Position=UDim2.fromOffset(46,193),Size=UDim2.new(1,-74,0,18)})
            local b=new("TextButton",{Position=UDim2.fromOffset(28,228),Size=UDim2.new(1,-56,0,48),BackgroundColor3=Color3.new(1,1,1),
                Text="Activate",TextColor3=Color3.new(0,0,0),Font=Enum.Font.GothamBold,TextSize=15,BorderSizePixel=0,AutoButtonColor=false,Parent=card})
            new("UICorner",{CornerRadius=UDim.new(0,12),Parent=b})
            b.MouseEnter:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(215,215,215)}):Play() end)
            b.MouseLeave:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.new(1,1,1)}):Play() end)
            text({Text="Your key is locked to this device the first time you use it.",TextSize=11,TextColor3=Color3.fromRGB(100,100,100),
                TextXAlignment=Enum.TextXAlignment.Center,Position=UDim2.fromOffset(28,292),Size=UDim2.new(1,-56,0,16)})
            local ds=new("TextButton",{Position=UDim2.fromOffset(28,306),Size=UDim2.new(1,-56,0,18),BackgroundTransparency=1,
                Text="Need a key?  Copy our Discord invite",Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=Color3.fromRGB(150,150,150),
                AutoButtonColor=false,Parent=card})
            ds.MouseButton1Click:Connect(function()
                local ok=pcall(function() setclipboard(SUPPORT_LINK) end)
                ds.Text=ok and "Invite copied. Paste it in your browser." or SUPPORT_LINK
            end)
            
            local function markExpired()
                card.Size=UDim2.fromOffset(420,376)
                ds.Position=UDim2.fromOffset(28,320); ds.Size=UDim2.new(1,-56,0,40)
                ds.BackgroundTransparency=0; ds.BackgroundColor3=Color3.fromRGB(88,101,242)
                ds.Font=Enum.Font.GothamBold; ds.TextSize=13; ds.TextColor3=Color3.new(1,1,1)
                ds.Text="Copy Discord invite  -  buy a new key"
                if not ds:FindFirstChildOfClass("UICorner") then new("UICorner",{CornerRadius=UDim.new(0,12),Parent=ds}) end
            end
            if tostring(LICENSED.why or ""):lower():find("expired",1,true) then markExpired() end
            
            do
                local dragging,start,orig=false,nil,nil
                card.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 and i.Position.Y-card.AbsolutePosition.Y<90 then
                        dragging=true; start=i.Position; orig=card.Position
                    end
                end)
                UISv.InputChanged:Connect(function(i)
                    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
                        local d=i.Position-start
                        card.Position=UDim2.new(orig.X.Scale,orig.X.Offset+d.X,orig.Y.Scale,orig.Y.Offset+d.Y)
                    end
                end)
                UISv.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
            end
            local function status(txt,col)
                msg.Text=txt; msg.TextColor3=col
                TS:Create(dot,TweenInfo.new(0.2),{BackgroundColor3=col}):Play()
            end
            local function shake()
                local p0=card.Position
                for _,dx in ipairs({-10,10,-7,7,-3,3,0}) do
                    card.Position=UDim2.new(p0.X.Scale,p0.X.Offset+dx,p0.Y.Scale,p0.Y.Offset); task.wait(0.03)
                end
            end
            local busy,done,closed=false,false,false
            local function submit()
                if busy or done then return end
                local key=tb.Text:gsub("%s","")
                if key=="" then status("Type your key first",Color3.fromRGB(255,190,90)); return end
                busy=true; b.Text="Checking..."; status("Checking your key...",Color3.fromRGB(150,150,150))
                local ok,why=check(key,true)
                busy=false; b.Text="Activate"
                if ok then
                    LICENSED.ok=true; done=true
                    pcall(function() if writefile then writefile("TRAPPED_key.txt",key) end end)
                    local ex=""
                    pcall(function()
                        local sub=LICENSED.info and LICENSED.info.subscriptions and LICENSED.info.subscriptions[1]
                        if sub and sub.timeleft then
                            local d=math.floor(tonumber(sub.timeleft)/86400)
                            ex=d>3650 and " (lifetime)" or (" ("..d.." days left)")
                        end
                    end)
                    status("Key accepted"..ex,Color3.fromRGB(110,230,140))
                    b.Text="Welcome"
                    TS:Create(b,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(110,230,140)}):Play()
                else
                    status(nice(why),Color3.fromRGB(255,110,110))
                    if nice(why):lower():find("expired",1,true) then markExpired() end
                    task.spawn(shake)
                end
            end
            b.MouseButton1Click:Connect(submit)
            tb.FocusLost:Connect(function(enter) if enter then submit() end end)
            x.MouseButton1Click:Connect(function() closed=true end)
            local t0=os.clock()
            while not done and not closed and sg.Parent and os.clock()-t0<600 do task.wait(0.1) end
            if done then
                task.wait(0.9)
                TS:Create(scale,TweenInfo.new(0.25),{Scale=0.92}):Play()
                TS:Create(dim,TweenInfo.new(0.25),{BackgroundTransparency=1}):Play()
                task.wait(0.28)
            end
            pcall(function() sg:Destroy() end)
            LICENSED.promptOpen=false
        end
        LICENSED.prompt=promptKey
        LICENSED.nice=nice
        if not LICENSED.ok then promptKey() end
    end
end
if not LICENSED.ok then return end



local function myChar()
    if not LP then return nil end
    local c=LP.Character
    if c and c.Parent then return c end
    local ws=workspace
    if not ws then return c end
    local folder=ws:FindFirstChild("Characters")
    local m=folder and folder:FindFirstChild(LP.Name)
    if m then return m end
    return ws:FindFirstChild(LP.Name) or c
end


local State={}
local Refs={}
local Hub={Version="7.4.0",Name="TRAPPED"}

Hub.dev=false                      

local Signal={}; Signal.__index=Signal
function Signal.new() return setmetatable({_h={}},Signal) end
function Signal:Connect(fn)
    self._h[fn]=true
    return {Disconnect=function() self._h[fn]=nil end}
end
function Signal:Fire(...) for f in pairs(self._h) do task.spawn(f,...) end end
Hub.Changed=Signal.new()

local Counters={greens=0}

local function DC(v)
    if type(v)~="table" then return v end
    local o={}; for k,w in pairs(v) do o[k]=DC(w) end; return o
end
function Hub:Get(id) return State[id] end
function Hub:Set(id,v)
    State[id]=v
    for _,fn in ipairs(Refs[id] or {}) do task.spawn(fn,v) end
    Hub.Changed:Fire(id,v)
end
local function seed(id,def)
    Hub._defs=Hub._defs or {}
    if Hub._defs[id]==nil and def~=nil then Hub._defs[id]=DC(def) end
    if State[id]==nil then State[id]=DC(def) end
end
local function bind(id,fn)
    if not Refs[id] then Refs[id]={} end
    table.insert(Refs[id],fn)
end
local function pushAll(tbl)
    for id,v in pairs(tbl) do
        State[id]=DC(v)
        for _,fn in ipairs(Refs[id] or {}) do task.spawn(fn,v) end
        Hub.Changed:Fire(id,v)
    end
end


seed("shoot.perfect",true)
seed("shoot.greenAt",72)
seed("shoot.delay",0)
seed("shoot.variance",false)
seed("shoot.debug",false)
seed("shoot.journal",true)
seed("shoot.key","E")
seed("shoot.exact",true)
seed("shoot.lead",false)
seed("shoot.keyHold",570)
seed("shoot.padHold",624)
seed("shoot.learn",false)
seed("ui.menuKey","RightShift")
seed("ui.notifs",true)
seed("ui.animations",true)
seed("ui.scale",1)
seed("ui.autoSave",true)
seed("menus.custom","")
seed("extras.antiAfk",true)
seed("extras.fps",false)
seed("settings.rerunOnTeleport",true)
seed("settings.scriptUrl","")
local statusUpdaters={}
seed("ui.posX",0)
seed("ui.posY",0)


local CFG_FILE="TRAPPED_Default.json"
local function hasFS() return type(readfile)=="function" and type(writefile)=="function" end
local function cfgSave()
    if not hasFS() then return false end
    local snap={}
    for k,v in pairs(State) do
        if type(k)=="string" then snap[k]=v end
    end
    return (pcall(function()
        writefile(CFG_FILE,HttpService:JSONEncode({s=snap,v=Hub.Version}))
    end))
end

local function verNum(v)
    local a,b,c=tostring(v or "0"):match("(%d+)%.(%d+)%.?(%d*)")
    return (tonumber(a) or 0)*10000+(tonumber(b) or 0)*100+(tonumber(c) or 0)
end
local MIGRATIONS={
    {to=70400,run=function(c)
        if c["shoot.contestAware"]==nil then c["shoot.contestAware"]=true end     
        if c["play.man"]==nil then c["play.man"]=true end
        for k in pairs(c) do                                                     
            if type(k)=="string" and k:find("^shoot%.fine%.") and k:find("~c",1,true) then c[k]=nil end
        end
    end},
}
local function cfgLoad()
    if not hasFS() then return nil end
    local ok,d=pcall(function() return HttpService:JSONDecode(readfile(CFG_FILE)) end)
    if not (ok and type(d)=="table" and type(d.s)=="table") then return nil end
    local from=verNum(d.v)
    local changed=false
    for _,m in ipairs(MIGRATIONS) do
        if from<m.to then
            if not changed then pcall(writefile,CFG_FILE..".bak",readfile(CFG_FILE)); changed=true end
            pcall(m.run,d.s)
        end
    end
    if changed then bootLog("settings upgraded from v"..tostring(d.v or "?").." to v"..Hub.Version) end
    return d.s
end
local saveToken=0
function Hub:QueueSave()
    if State["ui.autoSave"]==false then return end
    saveToken=saveToken+1
    local mine=saveToken
    task.delay(0.6,function() if mine==saveToken then cfgSave() end end)
end


local Conns={}
local function track(c) Conns[#Conns+1]=c; return c end
local gui
local Ambients={}

Hub.alive=true

function Hub.TrimLog(file,maxLines,header)
    pcall(function()
        if type(isfile)~="function" or type(readfile)~="function" or type(writefile)~="function" or not isfile(file) then return end
        local t=readfile(file)
        if #t<30000 then return end
        local ls={}
        for l in t:gmatch("[^\n]+") do ls[#ls+1]=l end
        if #ls<=maxLines then return end
        local keep={}
        if header then keep[1]=ls[1] end
        for i=#ls-math.floor(maxLines*2/3)+1,#ls do keep[#keep+1]=ls[i] end
        writefile(file,table.concat(keep,"\n").."\n")
    end)
end
Hub.TrimLog("TRAPPED_license.log",500,false)
Hub.TrimLog("TRAPPED_journal2.csv",3000,true)
Hub.TrimLog("TRAPPED_play.log",1500,false)

function Hub:Destroy()
    Hub.alive=false
    for _,c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for _,t in ipairs(Ambients) do pcall(function() t:Cancel() end) end
    if gui then pcall(function() gui:Destroy() end) end
    pcall(function() if _G.TRAPPED==Hub then _G.TRAPPED=nil end end)
    pcall(function() if type(getgenv)=="function" and getgenv().TRAPPED==Hub then getgenv().TRAPPED=nil end end)
    pcall(function() _G.__TRAPPED_AGLOG_COPY=nil; _G.__TRAPPED_AGLOG_SAVE=nil end)
end


local C={
    Bg0=Color3.fromRGB(5,5,5),
    Bg1=Color3.fromRGB(11,11,11),
    Bg2=Color3.fromRGB(17,17,17),
    Bg3=Color3.fromRGB(25,25,25),
    Bg4=Color3.fromRGB(36,36,36),
    Line=Color3.fromRGB(38,38,38),
    LineHi=Color3.fromRGB(66,66,66),
    Txt=Color3.fromRGB(246,246,246),
    Sec=Color3.fromRGB(170,170,170),
    Dim=Color3.fromRGB(112,112,112),
    Mut=Color3.fromRGB(72,72,72),
    White=Color3.new(1,1,1),
    Black=Color3.new(0,0,0),
}
local F={B=Enum.Font.GothamBold,M=Enum.Font.GothamMedium,R=Enum.Font.Gotham,Mono=Enum.Font.RobotoMono}
local EASE=Enum.EasingStyle.Quint


local function New(cls,props)
    local obj=Instance.new(cls)
    local par
    for k,v in pairs(props) do
        if k=="Parent" then par=v else pcall(function() obj[k]=v end) end
    end
    if par then obj.Parent=par end
    return obj
end
local function Corner(o,r) return New("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=o}) end
local function CornerFull(o) return New("UICorner",{CornerRadius=UDim.new(1,0),Parent=o}) end
local function Pad(o,l,r,t,b)
    return New("UIPadding",{PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or 0),
        PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or 0),Parent=o})
end
local function Stroke(o,col,th,tr)
    return New("UIStroke",{Color=col,Thickness=th or 1,Transparency=tr or 0,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=o})
end
local function List(o,dir,pad,ha,va)
    return New("UIListLayout",{
        FillDirection=dir or Enum.FillDirection.Vertical,
        HorizontalAlignment=ha or Enum.HorizontalAlignment.Left,
        VerticalAlignment=va or Enum.VerticalAlignment.Top,
        Padding=UDim.new(0,pad or 0),SortOrder=Enum.SortOrder.LayoutOrder,Parent=o})
end
local function dur(t) if State["ui.animations"]==false then return 0 end return t end
local function Tw(obj,props,t,sty,dir)
    return TweenService:Create(obj,
        TweenInfo.new(dur(t or 0.25),sty or EASE,dir or Enum.EasingDirection.Out),props)
end
local function P(obj,props,t,sty,dir)
    local tw=Tw(obj,props,t,sty,dir); tw:Play(); return tw
end

local ambientOn=false
local function ambient(obj,props,t,sty,dir,rev)
    local tw=TweenService:Create(obj,
        TweenInfo.new(t,sty or Enum.EasingStyle.Sine,dir or Enum.EasingDirection.InOut,-1,rev or false),props)
    Ambients[#Ambients+1]=tw
    if ambientOn and State["ui.animations"]~=false then tw:Play() end
    return tw
end
local function setAmbient(on)
    ambientOn=on
    for _,t in ipairs(Ambients) do
        if on and State["ui.animations"]~=false then pcall(function() t:Play() end)
        else pcall(function() t:Pause() end) end
    end
end
local function IsPri(t) return t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.Touch end
local function MX() return UIS:GetMouseLocation().X end
local function MP() return UIS:GetMouseLocation() end
local function MkLbl(props)
    local l=New("TextLabel",{BackgroundTransparency=1,Font=F.M,TextColor3=C.Txt,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
    for k,v in pairs(props) do pcall(function() l[k]=v end) end
    return l
end
local function MkBtn(props)
    local b=New("TextButton",{BackgroundTransparency=1,AutoButtonColor=false,Text="",
        Font=F.M,TextColor3=C.Txt,TextSize=13})
    for k,v in pairs(props) do pcall(function() b[k]=v end) end
    return b
end


local dUpd,dEnd=nil,nil
local function bDrag(u,e) dUpd=u; dEnd=e end
track(UIS.InputChanged:Connect(function(i)
    if dUpd and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then dUpd(i) end
end))
track(UIS.InputEnded:Connect(function(i)
    if dEnd and IsPri(i.UserInputType) then
        local f=dEnd; dUpd=nil; dEnd=nil; f(i)
    end
end))


local capturing=nil
local function beginCapture(cb)
    capturing=function(inp)
        local t=inp.UserInputType
        if t==Enum.UserInputType.Keyboard then
            if inp.KeyCode==Enum.KeyCode.Unknown then return end
            capturing=nil
            cb(inp.KeyCode==Enum.KeyCode.Escape and nil or inp.KeyCode.Name)
        elseif tostring(t):find("Gamepad",1,true) then            
            local n=inp.KeyCode.Name
            if n:find("^Button") or n:find("^DPad") then
                capturing=nil
                cb(n)
            end
        end
    end
end


local W,H=780,560
local SW=210
local HEAD=84

do
    local locs={}
    pcall(function() locs[#locs+1]=game:GetService("CoreGui") end)
    pcall(function() locs[#locs+1]=LP and LP:FindFirstChildOfClass("PlayerGui") end)
    for _,loc in pairs(locs) do
        pcall(function()
            local ex=loc and loc:FindFirstChild("TRAPPED")
            if ex then ex:Destroy() end
            for _,ch in ipairs(loc and loc:GetChildren() or {}) do
                if ch:GetAttribute("_T") then ch:Destroy() end
            end
        end)
    end
end
gui=New("ScreenGui",{Name=HttpService:GenerateGUID(false):sub(1,14),ResetOnSpawn=false,IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999999})
gui:SetAttribute("_T",true)
do
    local parented=false
    if type(gethui)=="function" then
        parented=pcall(function() gui.Parent=gethui() end) and gui.Parent~=nil
    end
    if not parented then
        parented=pcall(function() gui.Parent=game:GetService("CoreGui") end) and gui.Parent~=nil
    end
    if not parented and LP then
        gui.Parent=LP:WaitForChild("PlayerGui",30)
    end
end

local function vpSize()
    local cam=workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280,720)
end
local root=New("Frame",{Name="Root",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(W,H),BackgroundTransparency=1,Visible=false,Parent=gui})
local uiScale=New("UIScale",{Scale=1,Parent=root})
local function finalScale()
    local vp=vpSize()
    local s=math.clamp(tonumber(State["ui.scale"]) or 1,0.75,1.25)
    s=math.min(s,(vp.X-40)/W,(vp.Y-40)/H)
    return math.max(0.5,s)
end


for _,s in ipairs({{10,0.86},{22,0.92},{38,0.96}}) do
    local sh=New("Frame",{Position=UDim2.fromOffset(-s[1],-s[1]+10),
        Size=UDim2.fromOffset(W+s[1]*2,H+s[1]*2),BackgroundColor3=C.Black,
        BackgroundTransparency=s[2],BorderSizePixel=0,ZIndex=0,Parent=root})
    Corner(sh,16+s[1])
end

local win=New("CanvasGroup",{Name="Window",Size=UDim2.fromScale(1,1),BackgroundColor3=C.Bg1,
    BorderSizePixel=0,GroupTransparency=1,ZIndex=2,Parent=root})
Corner(win,16)
Stroke(win,C.LineHi,1,0.35)

local bgLayer=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=1,Parent=win})
New("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(17,17,17),Color3.fromRGB(7,7,7)),Rotation=90,Parent=bgLayer})


local topLine=New("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=20,Parent=win})
local topGrad=New("UIGradient",{Transparency=NumberSequence.new{
    NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.35),NumberSequenceKeypoint.new(1,1)},
    Offset=Vector2.new(-1,0),Parent=topLine})
ambient(topGrad,{Offset=Vector2.new(1,0)},3.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,false)


local sidebar=New("Frame",{Size=UDim2.new(0,SW,1,0),BackgroundColor3=C.Bg0,BackgroundTransparency=0.15,
    BorderSizePixel=0,ZIndex=2,Parent=win})
New("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.new(0,1,1,0),
    BackgroundColor3=C.Line,BorderSizePixel=0,ZIndex=3,Parent=sidebar})

local logo=New("Frame",{Position=UDim2.fromOffset(24,24),Size=UDim2.fromOffset(34,34),BackgroundColor3=C.White,
    BorderSizePixel=0,ZIndex=4,Parent=sidebar})
Corner(logo,10)
local logoT=MkLbl({Text="T",Font=F.B,TextSize=17,TextColor3=C.Black,TextXAlignment=Enum.TextXAlignment.Center,
    Size=UDim2.fromScale(1,1),ZIndex=5,Parent=logo})

task.spawn(function()
    pcall(function()
        local lp=game:GetService("Players").LocalPlayer
        local img=game:GetService("Players"):GetUserThumbnailAsync(lp.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
        if not img or img=="" then return end
        local uc=logo:FindFirstChildOfClass("UICorner"); if uc then uc.CornerRadius=UDim.new(0,17) end
        Stroke(logo,C.White,1.5,0)
        logo.BackgroundColor3=C.Bg3
        logoT.Visible=false
        New("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=img,ScaleType=Enum.ScaleType.Crop,
            ZIndex=5,Parent=logo})
        local pic=logo:FindFirstChildOfClass("ImageLabel")
        if pic then Corner(pic,17) end
    end)
end)
MkLbl({Text="TRAPPED",Font=F.B,TextSize=15,Position=UDim2.fromOffset(70,23),Size=UDim2.fromOffset(120,18),
    ZIndex=4,Parent=sidebar})
MkLbl({Text="v"..Hub.Version,Font=F.Mono,TextSize=10,TextColor3=C.Dim,Position=UDim2.fromOffset(70,42),
    Size=UDim2.fromOffset(120,14),ZIndex=4,Parent=sidebar})


local content=New("Frame",{Position=UDim2.fromOffset(SW,0),Size=UDim2.new(1,-SW,1,0),
    BackgroundTransparency=1,ZIndex=2,Parent=win})
local titleLbl=MkLbl({Text="",Font=F.B,TextSize=23,Position=UDim2.fromOffset(32,22),
    Size=UDim2.new(1,-150,0,30),ZIndex=4,Parent=content})
local subLbl=MkLbl({Text="",Font=F.R,TextSize=12,TextColor3=C.Dim,Position=UDim2.fromOffset(32,54),
    Size=UDim2.new(1,-150,0,16),ZIndex=4,Parent=content})
local pagesHolder=New("Frame",{Position=UDim2.fromOffset(0,HEAD),Size=UDim2.new(1,0,1,-HEAD),
    BackgroundTransparency=1,ClipsDescendants=true,ZIndex=3,Parent=content})


local dragHandle=New("Frame",{Size=UDim2.new(1,0,0,76),BackgroundTransparency=1,ZIndex=3,Parent=win})


local function winBtn(xOff,kind)
    local b=MkBtn({AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-xOff,0,22),Size=UDim2.fromOffset(32,32),
        BackgroundColor3=C.Bg3,BackgroundTransparency=1,ZIndex=30,Parent=win})
    Corner(b,9)
    local bars={}
    local function bar(w,rot)
        local f=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
            Size=UDim2.fromOffset(w,2),Rotation=rot or 0,BackgroundColor3=C.Sec,BorderSizePixel=0,ZIndex=31,Parent=b})
        Corner(f,1); bars[#bars+1]=f
    end
    if kind=="hide" then bar(11) else bar(14,45); bar(14,-45) end
    b.MouseEnter:Connect(function()
        P(b,{BackgroundTransparency=0},0.15)
        for _,f in ipairs(bars) do P(f,{BackgroundColor3=C.White},0.15) end
    end)
    b.MouseLeave:Connect(function()
        P(b,{BackgroundTransparency=1},0.2)
        for _,f in ipairs(bars) do P(f,{BackgroundColor3=C.Sec},0.2) end
    end)
    return b
end
local btnHide=winBtn(58,"hide")
local btnClose=winBtn(20,"close")


do
    local sub=LICENSED.info and LICENSED.info.subscriptions and LICENSED.info.subscriptions[1]
    local left0=sub and tonumber(sub.timeleft)
    if left0 then
        local pill=New("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-100,0,22),Size=UDim2.fromOffset(0,32),
            AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=C.Bg3,BorderSizePixel=0,ZIndex=30,Parent=win})
        pill.Name="LicPill"
        Corner(pill,9); Stroke(pill,C.Line,1,0); Pad(pill,12,12,0,0)
        local dot=New("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(0,16),Size=UDim2.fromOffset(7,7),
            BackgroundColor3=Color3.fromRGB(110,230,140),BorderSizePixel=0,ZIndex=31,Parent=pill})
        Corner(dot,4)
        local lbl=New("TextLabel",{Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(0,32),AutomaticSize=Enum.AutomaticSize.X,
            BackgroundTransparency=1,Font=F.Mono,TextSize=11,TextColor3=C.Sec,Text="",ZIndex=31,Parent=pill})
        task.spawn(function()
            while Hub.alive and pill.Parent do
                local left=left0-(os.clock()-(LICENSED.at or os.clock()))
                local col=Color3.fromRGB(110,230,140)
                if left0>315360000 then lbl.Text="LICENSE  LIFETIME"
                elseif left<=0 then lbl.Text="LICENSE  EXPIRED"; col=Color3.fromRGB(255,110,110)
                else
                    local d=math.floor(left/86400); local h=math.floor(left%86400/3600)
                    local m=math.floor(left%3600/60); local sc=math.floor(left%60)
                    lbl.Text=string.format("LICENSE  %dd %02dh %02dm %02ds",d,h,m,sc)
                    if left<86400 then col=Color3.fromRGB(255,190,90) end
                end
                dot.BackgroundColor3=col
                task.wait(1)
            end
        end)
    end
end


local function iconTarget(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local parts={}
    local ring=New("Frame",{Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(16,16),BackgroundTransparency=1,
        ZIndex=5,Parent=c})
    CornerFull(ring)
    parts[#parts+1]={Stroke(ring,col,1.6,0),"Color"}
    local function solid(x,y,w,h,r)
        local f=New("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=col,
            BorderSizePixel=0,ZIndex=5,Parent=c})
        if r then Corner(f,r) end
        parts[#parts+1]={f,"BackgroundColor3"}
    end
    solid(8,8,4,4,2); solid(9,0,2,3); solid(9,17,2,3); solid(0,9,3,2); solid(17,9,3,2)
    return c,function(col2,t) for _,p in ipairs(parts) do P(p[1],{[p[2]]=col2},t or 0.2) end end
end
local function iconGrid(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local parts={}
    for _,xy in ipairs({{2,2},{11,2},{2,11},{11,11}}) do
        local f=New("Frame",{Position=UDim2.fromOffset(xy[1],xy[2]),Size=UDim2.fromOffset(7,7),
            BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
        Corner(f,2); parts[#parts+1]=f
    end
    return c,function(col2,t) for _,f in ipairs(parts) do P(f,{BackgroundColor3=col2},t or 0.2) end end
end

local function iconShield(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local outer=New("Frame",{Position=UDim2.fromOffset(3,2),Size=UDim2.fromOffset(14,16),BackgroundColor3=col,
        BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(outer,5)
    local inner=New("Frame",{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(8,8),BackgroundColor3=C.Bg1,
        BorderSizePixel=0,ZIndex=6,Parent=c})
    Corner(inner,3)
    return c,function(col2,t) P(outer,{BackgroundColor3=col2},t or 0.2) end
end

local function iconSliders(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local parts={}
    local function solid(x,y,w,h,r)
        local f=New("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=col,
            BorderSizePixel=0,ZIndex=5,Parent=c})
        if r then Corner(f,r) end
        parts[#parts+1]={f,"BackgroundColor3"}
    end
    solid(2,5,16,2,1); solid(2,13,16,2,1); solid(11,2,5,8,2.5); solid(4,10,5,8,2.5)
    return c,function(col2,t) for _,p in ipairs(parts) do P(p[1],{[p[2]]=col2},t or 0.2) end end
end

local ICON={}
function ICON.ball(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local ring=New("Frame",{Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(16,16),BackgroundTransparency=1,
        BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(ring,8)
    local st=Stroke(ring,col,2,0)
    local l1=New("Frame",{Position=UDim2.fromOffset(9,2),Size=UDim2.fromOffset(2,16),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    local l2=New("Frame",{Position=UDim2.fromOffset(2,9),Size=UDim2.fromOffset(16,2),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    return c,function(col2,t2) P(st,{Color=col2},t2 or 0.2); P(l1,{BackgroundColor3=col2},t2 or 0.2); P(l2,{BackgroundColor3=col2},t2 or 0.2) end
end
function ICON.user(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=5,Parent=parent})
    local head=New("Frame",{Position=UDim2.fromOffset(6,2),Size=UDim2.fromOffset(8,8),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(head,4)
    local body=New("Frame",{Position=UDim2.fromOffset(3,11),Size=UDim2.fromOffset(14,7),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(body,3)
    return c,function(col2,t2) P(head,{BackgroundColor3=col2},t2 or 0.2); P(body,{BackgroundColor3=col2},t2 or 0.2) end
end
function ICON.radar(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=5,Parent=parent})
    local sts,fr={},{}
    for _,sz in ipairs({18,10}) do
        local f=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(sz,sz),
            BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5,Parent=c})
        Corner(f,sz/2); sts[#sts+1]=Stroke(f,col,1.5,0)
    end
    local dot=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(4,4),
        BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(dot,2)
    return c,function(col2,t2) for _,st in ipairs(sts) do P(st,{Color=col2},t2 or 0.2) end P(dot,{BackgroundColor3=col2},t2 or 0.2) end
end
function ICON.hat(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=5,Parent=parent})
    local top=New("Frame",{Position=UDim2.fromOffset(5,3),Size=UDim2.fromOffset(10,9),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(top,4)
    local brim=New("Frame",{Position=UDim2.fromOffset(2,12),Size=UDim2.fromOffset(16,3),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
    Corner(brim,1.5)
    return c,function(col2,t2) P(top,{BackgroundColor3=col2},t2 or 0.2); P(brim,{BackgroundColor3=col2},t2 or 0.2) end
end
function ICON.bolt(parent,col,pos)
    local c=New("Frame",{Position=pos or UDim2.new(),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,
        ZIndex=5,Parent=parent})
    local parts={}
    for _,r in ipairs({{9,2,3,9},{6,9,8,3},{8,11,3,7}}) do
        local f=New("Frame",{Position=UDim2.fromOffset(r[1],r[2]),Size=UDim2.fromOffset(r[3],r[4]),BackgroundColor3=col,BorderSizePixel=0,ZIndex=5,Parent=c})
        Corner(f,1); parts[#parts+1]=f
    end
    return c,function(col2,t2) for _,f in ipairs(parts) do P(f,{BackgroundColor3=col2},t2 or 0.2) end end
end


local notifHolder=New("Frame",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-20,1,-20),
    Size=UDim2.fromOffset(310,330),BackgroundTransparency=1,ZIndex=400,Parent=gui})
List(notifHolder,nil,8,Enum.HorizontalAlignment.Right,Enum.VerticalAlignment.Bottom)

function Hub:Notify(text,kind)
    if State["ui.notifs"]==false or not Hub.alive or not notifHolder.Parent then return end
    if State["ui.stream"]==true and kind~="error" then return end
    Hub._nseq=(Hub._nseq or 0)+1
    local slots={}
    for _,c in ipairs(notifHolder:GetChildren()) do
        if c:IsA("Frame") then slots[#slots+1]=c end
    end
    table.sort(slots,function(a,b) return a.LayoutOrder<b.LayoutOrder end)
    while #slots>=4 do
        pcall(function() slots[1]:Destroy() end)
        table.remove(slots,1)
    end
    local col=kind=="success" and C.White or kind=="info" and C.Dim or C.Sec
    local slot=New("Frame",{Size=UDim2.fromOffset(300,46),BackgroundTransparency=1,
        LayoutOrder=Hub._nseq,ZIndex=400,Parent=notifHolder})
    local toast=New("Frame",{Position=UDim2.fromOffset(330,0),Size=UDim2.fromScale(1,1),BackgroundColor3=C.Bg2,
        BorderSizePixel=0,ZIndex=401,Parent=slot})
    Corner(toast,12); Stroke(toast,C.LineHi,1,0.3)
    local bar=New("Frame",{Position=UDim2.new(0,14,0.5,-9),Size=UDim2.fromOffset(3,18),BackgroundColor3=col,
        BorderSizePixel=0,ZIndex=402,Parent=toast})
    Corner(bar,2)
    MkLbl({Text=tostring(text),TextSize=12,Position=UDim2.fromOffset(30,0),Size=UDim2.new(1,-42,1,-3),
        ZIndex=402,Parent=toast})
    local prog=New("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,14,1,-3),Size=UDim2.new(1,-28,0,1),
        BackgroundColor3=C.White,BackgroundTransparency=0.75,BorderSizePixel=0,ZIndex=402,Parent=toast})
    P(toast,{Position=UDim2.fromOffset(0,0)},0.4)
    TweenService:Create(prog,TweenInfo.new(3,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,0,1)}):Play()
    task.delay(3,function()
        if not toast or not toast.Parent then return end
        P(toast,{Position=UDim2.fromOffset(330,0)},0.3)
        task.wait(dur(0.32)+0.02)
        pcall(function() slot:Destroy() end)
    end)
end


local Section={}; Section.__index=Section
local function newSection(inner) return setmetatable({inner=inner,n=0},Section) end

local function makeCard(parent,order)
    local card=New("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.Bg2,
        BorderSizePixel=0,LayoutOrder=order,Parent=parent})
    Corner(card,16); Stroke(card,C.Line,1,0)
    local hl=New("Frame",{Position=UDim2.fromOffset(20,0),Size=UDim2.new(1,-40,0,1),BackgroundColor3=C.White,
        BackgroundTransparency=0.9,BorderSizePixel=0,ZIndex=3,Parent=card})
    New("UIGradient",{Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)},Parent=hl})
    local inner=New("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Parent=card})
    List(inner,nil,0); Pad(inner,24,24,6,6)
    return newSection(inner)
end

function Section:_row(h)
    self.n=self.n+1
    return New("Frame",{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,LayoutOrder=self.n,Parent=self.inner})
end
function Section:Divider()
    self.n=self.n+1
    New("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Line,BackgroundTransparency=0.35,BorderSizePixel=0,
        LayoutOrder=self.n,Parent=self.inner})
end

local function descExtra(desc,rightW)
    if not desc or desc=="" then return 0 end
    local avail=(W-SW)-62-34-rightW            
    local cpl=math.max(12,math.floor(avail/6.0))
    local lines=math.ceil(#desc/cpl)
    return math.max(0,lines-1)*14
end
local function rowText(row,label,desc,rightW,extra)
    MkLbl({Text=label,TextSize=13,Position=UDim2.new(0,0,0,desc and 12 or 0),
        Size=UDim2.new(1,-rightW,0,desc and 20 or row.Size.Y.Offset),Parent=row})
    if desc then
        MkLbl({Text=desc,Font=F.R,TextSize=11,TextColor3=C.Dim,Position=UDim2.fromOffset(0,32),
            Size=UDim2.new(1,-rightW,0,16+(extra or 0)),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=row})
    end
end


local function MakeSwitch(parent,id,w,h,pos,anchor)
    local pad=3
    local kd=h-pad*2
    local c=New("Frame",{AnchorPoint=anchor or Vector2.new(1,0.5),Position=pos or UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,ZIndex=3,Parent=parent})
    local glow=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(w+18,h+18),BackgroundColor3=C.White,BackgroundTransparency=1,
        BorderSizePixel=0,ZIndex=1,Parent=c})
    CornerFull(glow)
    local track=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Bg4,BorderSizePixel=0,ZIndex=2,Parent=c})
    CornerFull(track)
    local ts=Stroke(track,C.LineHi,1,0.2)
    local knob=New("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,pad,0.5,0),
        Size=UDim2.fromOffset(kd,kd),BackgroundColor3=C.Dim,BorderSizePixel=0,ZIndex=3,Parent=track})
    CornerFull(knob)
    local on,down=false,false
    local function layout()
        local kw=down and kd+6 or kd
        P(knob,{Size=UDim2.fromOffset(kw,kd),
            Position=on and UDim2.new(1,-(kw+pad),0.5,0) or UDim2.new(0,pad,0.5,0),
            BackgroundColor3=on and C.Black or C.Dim},0.25)
    end
    local function visual(v)
        on=(v==true)
        P(track,{BackgroundColor3=on and C.White or C.Bg4},0.25)
        P(ts,{Transparency=on and 1 or 0.2},0.25)
        P(glow,{BackgroundTransparency=on and 0.9 or 1},0.35)
        layout()
    end
    visual(State[id]); bind(id,visual)
    local hit=MkBtn({Size=UDim2.fromScale(1,1),ZIndex=6,Parent=c})
    hit.MouseButton1Click:Connect(function() Hub:Set(id,not(State[id]==true)) end)
    hit.MouseButton1Down:Connect(function() down=true; layout() end)
    hit.MouseButton1Up:Connect(function() down=false; layout() end)
    hit.MouseLeave:Connect(function() if down then down=false; layout() end end)
    return c
end

function Section:Toggle(label,id,default,desc)
    seed(id,default)
    local ex=descExtra(desc,70)
    local row=self:_row((desc and 64 or 52)+ex)
    rowText(row,label,desc,70,ex)
    MakeSwitch(row,id,46,26)
end

function Section:Slider(label,id,minV,maxV,default,dec,suffix,desc)
    dec=dec or 0; suffix=suffix or ""; seed(id,default)
    local ex=descExtra(desc,100)
    local row=self:_row((desc and 84 or 72)+ex)
    rowText(row,label,desc,100,ex)
    local ty=(desc and 66 or 54)+ex
    local vb=New("TextBox",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,desc and 10 or 8),
        Size=UDim2.fromOffset(76,26),BackgroundColor3=C.Bg3,BorderSizePixel=0,Font=F.Mono,TextSize=11,
        TextColor3=C.Txt,ClearTextOnFocus=false,Text="",ZIndex=4,Parent=row})
    Corner(vb,8)
    local vbs=Stroke(vb,C.Line,1,0)
    local trackF=New("Frame",{Position=UDim2.fromOffset(0,ty),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.Bg4,
        BorderSizePixel=0,ZIndex=3,Parent=row})
    CornerFull(trackF)
    local fill=New("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=3,Parent=trackF})
    CornerFull(fill)
    local knobGlow=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.fromOffset(26,26),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,
        ZIndex=3,Parent=trackF})
    CornerFull(knobGlow)
    local knob=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.fromOffset(14,14),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4,Parent=trackF})
    CornerFull(knob)
    local function fmt(v)
        if dec==0 then return tostring(math.floor(v+0.5))..suffix end
        return string.format("%."..dec.."f",v)..suffix
    end
    local function visual(v)
        v=math.clamp(tonumber(v) or minV,minV,maxV)
        local f=(v-minV)/(maxV-minV)
        fill.Size=UDim2.new(f,0,1,0)
        knob.Position=UDim2.new(f,0,0.5,0); knobGlow.Position=UDim2.new(f,0,0.5,0)
        if not vb:IsFocused() then vb.Text=fmt(v) end
    end
    visual(State[id]); bind(id,visual)
    local function commit(v)
        local step=dec==0 and 1 or 10^-dec
        v=math.floor(v/step+0.5)*step
        Hub:Set(id,math.clamp(math.floor(v*1e6+0.5)/1e6,minV,maxV))
    end
    vb.Focused:Connect(function() P(vbs,{Color=C.White},0.15); vb.Text=tostring(tonumber(State[id]) or minV) end)
    vb.FocusLost:Connect(function()
        P(vbs,{Color=C.Line},0.2)
        local n=tonumber(vb.Text:match("-?%d+%.?%d*"))
        if n then commit(n) end
        visual(State[id])
    end)
    local dragging=false
    local function applyX(x)
        local w=trackF.AbsoluteSize.X; if w<=0 then return end
        commit(minV+math.clamp((x-trackF.AbsolutePosition.X)/w,0,1)*(maxV-minV))
    end
    local zone=MkBtn({Position=UDim2.fromOffset(-6,ty-12),Size=UDim2.new(1,12,0,28),ZIndex=6,Parent=row})
    zone.InputBegan:Connect(function(i)
        if not IsPri(i.UserInputType) then return end
        dragging=true; applyX(MX())
        P(knob,{Size=UDim2.fromOffset(18,18)},0.15)
        P(knobGlow,{BackgroundTransparency=0.88},0.2)
        bDrag(function(inp) if dragging then applyX(inp.Position.X) end end,function()
            dragging=false
            P(knob,{Size=UDim2.fromOffset(14,14)},0.2)
            P(knobGlow,{BackgroundTransparency=1},0.3)
        end)
    end)
end

function Section:Keybind(label,id,default,desc)
    seed(id,default)
    local ex=descExtra(desc,120)
    local row=self:_row((desc and 64 or 52)+ex)
    rowText(row,label,desc,120,ex)
    local cap=New("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(96,32),BackgroundColor3=C.Bg3,AutoButtonColor=false,Font=F.Mono,TextSize=11,
        TextColor3=C.Txt,Text="",BorderSizePixel=0,ZIndex=4,Parent=row})
    Corner(cap,9)
    local cs=Stroke(cap,C.Line,1,0)
    local listening=false
    local function visual(v) cap.Text=tostring(v or "None") end
    visual(State[id]); bind(id,visual)
    cap.MouseButton1Click:Connect(function()
        listening=true
        cap.Text="press a key"
        P(cs,{Color=C.White},0.15)
        beginCapture(function(name)
            listening=false
            P(cs,{Color=C.Line},0.2)
            if name then Hub:Set(id,name) else visual(State[id]) end
        end)
    end)
    cap.MouseEnter:Connect(function() if not listening then P(cap,{BackgroundColor3=C.Bg4},0.15) end end)
    cap.MouseLeave:Connect(function() P(cap,{BackgroundColor3=C.Bg3},0.2) end)
end

function Section:Button(label,fn,style)
    local row=self:_row(60)
    local primary=(style=="primary")
    local btn=MkBtn({Position=UDim2.new(0,0,0.5,-19),Size=UDim2.new(1,0,0,38),
        BackgroundColor3=primary and C.White or C.Bg3,BackgroundTransparency=0,BorderSizePixel=0,ZIndex=3,Parent=row})
    Corner(btn,10)
    local bs=primary and nil or Stroke(btn,C.Line,1,0)
    MkLbl({Text=label,Font=F.B,TextSize=12,TextColor3=primary and C.Black or C.Txt,
        TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1),ZIndex=4,Parent=btn})
    btn.MouseEnter:Connect(function()
        P(btn,{BackgroundColor3=primary and C.Sec or C.Bg4},0.15)
        if bs then P(bs,{Color=C.LineHi},0.15) end
    end)
    btn.MouseLeave:Connect(function()
        P(btn,{BackgroundColor3=primary and C.White or C.Bg3},0.2)
        if bs then P(bs,{Color=C.Line},0.2) end
    end)
    btn.MouseButton1Down:Connect(function() P(btn,{Size=UDim2.new(1,-8,0,36),Position=UDim2.new(0,4,0.5,-18)},0.08) end)
    btn.MouseButton1Up:Connect(function() P(btn,{Size=UDim2.new(1,0,0,38),Position=UDim2.new(0,0,0.5,-19)},0.15) end)
    btn.MouseButton1Click:Connect(function() task.spawn(fn) end)
end


function Section:Status(label,refresh)
    local row=self:_row(34)
    MkLbl({Text=label,TextSize=12,TextColor3=C.Sec,Size=UDim2.new(0.38,0,1,0),Parent=row})
    local v=MkLbl({Font=F.Mono,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,
        Position=UDim2.fromScale(0.38,0),Size=UDim2.fromScale(0.62,1),Parent=row})
    local function upd()
        local ok,t,col=pcall(refresh)
        if ok then v.Text=tostring(t or ""); v.TextColor3=col or C.Txt end
    end
    upd()
    return upd
end


function Section:Input(label,id,placeholder,desc)
    local ex=descExtra(desc,206)
    local row=self:_row((desc and 64 or 52)+ex)
    rowText(row,label,desc,206,ex)
    local box=New("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(196,32),BackgroundColor3=C.Bg3,BorderSizePixel=0,ZIndex=4,Parent=row})
    Corner(box,9)
    local bs=Stroke(box,C.Line,1,0)
    local tb=New("TextBox",{Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-20,1,0),BackgroundTransparency=1,
        Font=F.Mono,TextSize=11,TextColor3=C.Txt,PlaceholderColor3=C.Mut,PlaceholderText=placeholder or "",
        ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,
        Text=tostring(State[id] or ""),ZIndex=5,Parent=box})
    tb.Focused:Connect(function() P(bs,{Color=C.White},0.15) end)
    tb.FocusLost:Connect(function()
        P(bs,{Color=C.Line},0.2)
        Hub:Set(id,tb.Text)
    end)
    bind(id,function(v) if not tb:IsFocused() then tb.Text=tostring(v or "") end end)
end

function Section:Collapsible(title,desc,builder)
    local head=self:_row(64)
    rowText(head,title,desc,50)
    local chev=New("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-4,0.5,0),
        Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,ZIndex=4,Parent=head})
    for _,a in ipairs({{4,45},{10,-45}}) do
        local arm=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(a[1],6),
            Size=UDim2.fromOffset(8,2),Rotation=a[2],BackgroundColor3=C.Sec,BorderSizePixel=0,ZIndex=4,Parent=chev})
        Corner(arm,1)
    end
    self.n=self.n+1
    local body=New("Frame",{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1,ClipsDescendants=true,
        LayoutOrder=self.n,Parent=self.inner})
    local contentF=New("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Parent=body})
    local lay=List(contentF,nil,0)
    builder(newSection(contentF))
    local open=false
    local hit=MkBtn({Size=UDim2.fromScale(1,1),ZIndex=6,Parent=head})
    hit.MouseButton1Click:Connect(function()
        open=not open
        P(body,{Size=UDim2.new(1,0,0,open and lay.AbsoluteContentSize.Y or 0)},0.4)
        P(chev,{Rotation=open and 180 or 0},0.35)
    end)
    hit.MouseEnter:Connect(function() for _,a in ipairs(chev:GetChildren()) do P(a,{BackgroundColor3=C.White},0.15) end end)
    hit.MouseLeave:Connect(function() for _,a in ipairs(chev:GetChildren()) do P(a,{BackgroundColor3=C.Sec},0.2) end end)
end


local Pages={}
local function newPage(name,title,sub)
    local cg=New("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,GroupTransparency=1,
        Visible=false,Parent=pagesHolder})
    local scroll=New("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=2,ScrollBarImageColor3=C.Mut,CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,Parent=cg})
    
    
    
    local list=New("Frame",{Position=UDim2.fromOffset(32,6),Size=UDim2.new(1,-62,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=scroll})
    Pad(list,0,0,0,32)
    List(list,nil,14)
    local page={cg=cg,list=list,title=title,sub=sub,n=0}
    function page:order() self.n=self.n+1; return self.n end
    function page:Group(text)
        MkLbl({Text=string.upper(text),Font=F.B,TextSize=10,TextColor3=C.Dim,Size=UDim2.new(1,0,0,16),
            LayoutOrder=self:order(),Parent=self.list})
        return makeCard(self.list,self:order())
    end
    Pages[name]=page
    return page
end


local NAV={
    {page="Shooting",name="Auto Time",icon=iconTarget},
    {page="Offense",name="Offense",icon=ICON.ball},
    {page="Defense",name="Defense",icon=iconShield},
    {page="Dribble",name="Dribble",icon=ICON.ball},
    {page="Player",name="Player",icon=ICON.user},
    {page="Scout",name="Scout",icon=ICON.radar},
    {page="Session",name="Session",icon=ICON.radar},
    {page="Squad",name="Squad",icon=ICON.user},
    {page="Players",name="Players",icon=ICON.user},
    {page="Builds",name="Builds",icon=ICON.user},
    {page="Cosmetics",name="Cosmetics",icon=ICON.hat},
    {page="Extras",name="Extras",icon=ICON.bolt},
    {page="Menus",name="Game Menus",icon=iconGrid},
    {page="Settings",name="Settings",icon=iconSliders},
}
local navTop=100

local NAVSTEP=math.min(46,math.floor((560-navTop-62)/#NAV))
local NAVH=NAVSTEP-4
local navItems={}
local selector=New("Frame",{Position=UDim2.fromOffset(14,navTop),Size=UDim2.new(1,-28,0,NAVH),
    BackgroundColor3=C.Bg3,BorderSizePixel=0,ZIndex=3,Parent=sidebar})
Corner(selector,10); Stroke(selector,C.Line,1,0.2)
local indGlow=New("Frame",{Position=UDim2.fromOffset(0,navTop),Size=UDim2.fromOffset(46,NAVH),BackgroundColor3=C.White,
    BorderSizePixel=0,ZIndex=3,Parent=sidebar})
New("UIGradient",{Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0.88),
    NumberSequenceKeypoint.new(1,1)},Parent=indGlow})
local indicator=New("Frame",{Position=UDim2.fromOffset(0,navTop+math.floor((NAVH-18)/2)),Size=UDim2.fromOffset(3,18),
    BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=6,Parent=sidebar})
Corner(indicator,2)

MkLbl({Text="NAVIGATION",Font=F.B,TextSize=10,TextColor3=C.Mut,Position=UDim2.fromOffset(28,navTop-26),
    Size=UDim2.fromOffset(150,14),ZIndex=4,Parent=sidebar})

for i,def in ipairs(NAV) do
    local item=New("Frame",{Position=UDim2.fromOffset(14,navTop+(i-1)*NAVSTEP),Size=UDim2.new(1,-28,0,NAVH),
        BackgroundTransparency=1,ZIndex=4,Parent=sidebar})
    local _,setIcon=def.icon(item,C.Dim,UDim2.fromOffset(14,math.floor((NAVH-20)/2)))
    local lbl=MkLbl({Text=def.name,TextSize=13,TextColor3=C.Dim,Position=UDim2.fromOffset(46,0),
        Size=UDim2.new(1,-50,1,0),ZIndex=5,Parent=item})
    local hit=MkBtn({Size=UDim2.fromScale(1,1),ZIndex=8,Parent=item})
    local entry={page=def.page,lbl=lbl,setIcon=setIcon,active=false}
    navItems[i]=entry
    hit.MouseEnter:Connect(function()
        if entry.active then return end
        P(lbl,{TextColor3=C.Sec},0.15); setIcon(C.Sec,0.15)
    end)
    hit.MouseLeave:Connect(function()
        if entry.active then return end
        P(lbl,{TextColor3=C.Dim},0.2); setIcon(C.Dim,0.2)
    end)
    hit.MouseButton1Click:Connect(function() Hub.SwitchPage(def.page) end)
end


local hint=New("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,24,1,-22),Size=UDim2.fromOffset(160,24),
    BackgroundTransparency=1,ZIndex=4,Parent=sidebar})
MkLbl({Text="TOGGLE MENU",Font=F.B,TextSize=9,TextColor3=C.Mut,Size=UDim2.fromOffset(78,24),ZIndex=5,Parent=hint})
local chip=New("TextLabel",{Position=UDim2.fromOffset(80,1),Size=UDim2.fromOffset(0,22),AutomaticSize=Enum.AutomaticSize.X,
    BackgroundColor3=C.Bg3,BorderSizePixel=0,Font=F.Mono,TextSize=10,TextColor3=C.Sec,Text="",ZIndex=5,Parent=hint})
Corner(chip,6); Stroke(chip,C.Line,1,0); Pad(chip,8,8,0,0)
local function updateChip() chip.Text=tostring(State["ui.menuKey"] or "RightShift") end
bind("ui.menuKey",updateChip); updateChip()


local activePage=nil
local pageTok=0
local function moveNav(idx)
    local y=navTop+(idx-1)*NAVSTEP
    P(selector,{Position=UDim2.fromOffset(14,y)},0.45)
    P(indGlow,{Position=UDim2.fromOffset(0,y)},0.45)
    P(indicator,{Position=UDim2.fromOffset(0,y+math.floor((NAVH-18)/2))},0.45)
    for i,e in ipairs(navItems) do
        local a=(i==idx)
        e.active=a
        P(e.lbl,{TextColor3=a and C.White or C.Dim},0.25)
        e.lbl.Font=a and F.B or F.M
        e.setIcon(a and C.White or C.Dim,0.25)
    end
end

function Hub.SwitchPage(name,instant)
    local new=Pages[name]
    if not new or name==activePage then return end
    pageTok=pageTok+1
    local tok=pageTok
    local old=activePage and Pages[activePage]
    activePage=name
    if old then
        P(old.cg,{GroupTransparency=1,Position=UDim2.new(0,0,0,-10)},0.2,Enum.EasingStyle.Quad)
        task.delay(dur(0.22),function() if Pages[activePage]~=old then old.cg.Visible=false end end)
    end
    new.cg.Visible=true
    if instant then
        new.cg.Position=UDim2.new(); new.cg.GroupTransparency=0
        titleLbl.Text=new.title; subLbl.Text=new.sub
        titleLbl.TextTransparency=0; subLbl.TextTransparency=0
    else
        new.cg.Position=UDim2.new(0,0,0,18); new.cg.GroupTransparency=1
        P(new.cg,{GroupTransparency=0,Position=UDim2.new()},0.45)
        P(titleLbl,{TextTransparency=1},0.12); P(subLbl,{TextTransparency=1},0.12)
        task.delay(dur(0.13),function()
            if tok~=pageTok then return end
            titleLbl.Text=new.title; subLbl.Text=new.sub
            P(titleLbl,{TextTransparency=0},0.35); P(subLbl,{TextTransparency=0},0.35)
        end)
    end
    for i,e in ipairs(navItems) do if e.page==name then moveNav(i) end end
end


local UI={frac=nil}
local function uiStatus(kind,pct,src)
    if UI.setStatus then pcall(UI.setStatus,kind,pct,src) end
end


local buildOk,buildErr=pcall(function()


do
    local pg=newPage("Shooting","Auto Time","Perfect releases, handled for you.")

    
    local hero=New("Frame",{Size=UDim2.new(1,0,0,224),BackgroundColor3=C.Bg2,BorderSizePixel=0,ClipsDescendants=true,
        LayoutOrder=pg:order(),Parent=pg.list})
    Corner(hero,16); Stroke(hero,C.Line,1,0)
    local sweep=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=1,Parent=hero})
    local sweepG=New("UIGradient",{Rotation=20,Offset=Vector2.new(-1,0),Transparency=NumberSequence.new{
        NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.42,1),NumberSequenceKeypoint.new(0.5,0.955),
        NumberSequenceKeypoint.new(0.58,1),NumberSequenceKeypoint.new(1,1)},Parent=sweep})
    ambient(sweepG,{Offset=Vector2.new(1,0)},7.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,false)

    local tile=New("Frame",{Position=UDim2.fromOffset(28,26),Size=UDim2.fromOffset(50,50),BackgroundColor3=C.Bg3,
        BorderSizePixel=0,ZIndex=3,Parent=hero})
    Corner(tile,13); Stroke(tile,C.LineHi,1,0.3)
    iconTarget(tile,C.White,UDim2.fromOffset(15,15))
    MkLbl({Text="Auto Time",Font=F.B,TextSize=20,Position=UDim2.fromOffset(94,26),Size=UDim2.new(1,-200,0,26),
        ZIndex=3,Parent=hero})
    MkLbl({Text="Releases your shot at the top of the meter.",Font=F.R,TextSize=12,TextColor3=C.Dim,
        TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,
        Position=UDim2.fromOffset(94,54),Size=UDim2.new(1,-200,0,32),ZIndex=3,Parent=hero})
    MakeSwitch(hero,"shoot.perfect",62,34,UDim2.new(1,-28,0,51),Vector2.new(1,0.5))

    New("Frame",{Position=UDim2.fromOffset(28,102),Size=UDim2.new(1,-56,0,1),BackgroundColor3=C.Line,
        BackgroundTransparency=0.3,BorderSizePixel=0,ZIndex=3,Parent=hero})

    
    local ind=New("Frame",{Position=UDim2.fromOffset(28,120),Size=UDim2.fromOffset(32,32),BackgroundTransparency=1,
        ZIndex=3,Parent=hero})
    local pulse=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(10,10),BackgroundTransparency=1,Visible=false,ZIndex=3,Parent=ind})
    CornerFull(pulse)
    local pulseS=Stroke(pulse,C.White,1.5,0.3)
    ambient(pulse,{Size=UDim2.fromOffset(32,32)},2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,false)
    ambient(pulseS,{Transparency=1},2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,false)
    local spin=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(26,26),BackgroundTransparency=1,Visible=false,ZIndex=3,Parent=ind})
    CornerFull(spin)
    local spinS=Stroke(spin,C.White,2,0)
    local spinG=New("UIGradient",{Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0),
        NumberSequenceKeypoint.new(0.35,0.2),NumberSequenceKeypoint.new(0.5,1),NumberSequenceKeypoint.new(1,1)},
        Parent=spinS})
    ambient(spinG,{Rotation=360},1.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,false)
    local dotGlow=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(22,22),BackgroundColor3=C.White,BackgroundTransparency=1,BorderSizePixel=0,
        ZIndex=3,Parent=ind})
    CornerFull(dotGlow)
    local dot=New("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(10,10),BackgroundColor3=C.Mut,BorderSizePixel=0,ZIndex=4,Parent=ind})
    CornerFull(dot)

    local stLbl=MkLbl({Text="DISABLED",Font=F.B,TextSize=13,TextColor3=C.Dim,Position=UDim2.fromOffset(76,119),
        Size=UDim2.new(1,-120,0,18),ZIndex=3,Parent=hero})
    local stSub=MkLbl({Text="",Font=F.R,TextSize=12,TextColor3=C.Dim,Position=UDim2.fromOffset(76,139),
        Size=UDim2.new(1,-120,0,16),ZIndex=3,Parent=hero})

    local statusTok=0
    function UI.setStatus(kind,pct,src)
        statusTok=statusTok+1
        local tok=statusTok
        local enabled=State["shoot.perfect"]==true
        if kind=="idle" and not enabled then kind="off" end
        if not enabled then kind="off" end
        local text,sub,tc
        if kind=="off" then
            text,sub,tc="DISABLED","Turn on to release shots automatically.",C.Dim
        elseif kind=="idle" then
            text,sub,tc="ENABLED","Ready. Hold your shoot key to shoot.",C.White
        elseif kind=="tracking" then
            text,sub,tc="TRACKING","Following the shot meter...",C.White
        else
            text="RELEASED"
            sub=(pct and pct>0) and string.format("Released at %d%% of the meter.",math.floor(pct*100+0.5))
                or "Released on the hold timer."
            tc=C.White
        end
        stLbl.Text=text
        P(stLbl,{TextColor3=tc},0.25)
        stSub.TextTransparency=1; stSub.Text=sub
        P(stSub,{TextTransparency=0},0.3)
        local lit=(kind~="off")
        P(dot,{BackgroundColor3=lit and C.White or C.Mut},0.3)
        P(dotGlow,{BackgroundTransparency=lit and 0.86 or 1},0.35)
        pulse.Visible=(kind=="idle")
        spin.Visible=(kind=="tracking")
        if kind=="released" then
            task.delay(1.8,function()
                if tok==statusTok then UI.frac=nil; UI.setStatus("idle") end
            end)
        end
    end
    bind("shoot.perfect",function() UI.frac=nil; UI.setStatus("idle") end)

    
    MkLbl({Text="SHOT METER",Font=F.B,TextSize=10,TextColor3=C.Mut,Position=UDim2.fromOffset(28,172),
        Size=UDim2.fromOffset(120,14),ZIndex=3,Parent=hero})
    local pctLbl=MkLbl({Text="--",Font=F.Mono,TextSize=11,TextColor3=C.Sec,TextXAlignment=Enum.TextXAlignment.Right,
        AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-28,0,171),Size=UDim2.fromOffset(80,14),ZIndex=3,Parent=hero})
    local mTrack=New("Frame",{Position=UDim2.fromOffset(28,194),Size=UDim2.new(1,-56,0,6),BackgroundColor3=C.Bg4,
        BorderSizePixel=0,ZIndex=3,Parent=hero})
    CornerFull(mTrack)
    local mFill=New("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4,Parent=mTrack})
    CornerFull(mFill)
    New("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(120,120,120),C.White),Parent=mFill})
    local marker=New("Frame",{Position=UDim2.new(0.98,-1,0.5,-8),Size=UDim2.fromOffset(2,16),BackgroundColor3=C.White,
        BackgroundTransparency=0.35,BorderSizePixel=0,ZIndex=5,Parent=mTrack})
    Corner(marker,1)
    local function placeMarker(v)
        local f=math.clamp((tonumber(v) or 98)/100,0,1)
        P(marker,{Position=UDim2.new(f,-1,0.5,-8)},0.3)
    end
    bind("shoot.greenAt",placeMarker); placeMarker(State["shoot.greenAt"])

    local cur,shown=0,-1
    track(RunService.RenderStepped:Connect(function(dt)
        if not root.Visible then return end
        local target=UI.frac or 0
        cur=cur+(target-cur)*math.min(1,dt*(UI.frac and 18 or 6))
        if math.abs(cur-shown)>0.002 then
            shown=cur
            mFill.Size=UDim2.new(math.clamp(cur,0,1),0,1,0)
            pctLbl.Text=UI.frac and string.format("%d%%",math.floor(cur*100+0.5)) or "--"
        end
    end))

    
    local t=pg:Group("Timing")
    t:Keybind("Shoot key","shoot.key","E","The key you hold to shoot.")
    t:Divider()
    t:Toggle("Hold to full bar","shoot.fullBar",true,"Hold the shoot button and Auto Time lets go at the right moment, every time. Turn off to release at a fixed 72% of the bar instead.")
    t:Divider()
    t:Collapsible("Advanced","Timing options.",function(a)
        a:Divider()
        a:Toggle("Hold-time fallback","shoot.exact",true,"Fixed hold time, used only if no meter is found.")
        a:Divider()
        a:Slider("Keyboard hold","shoot.keyHold",300,1000,570,0," ms","Hold time of a perfect keyboard release.")
        a:Divider()
        a:Slider("Controller hold","shoot.padHold",300,1000,624,0," ms","Hold time of a perfect controller release.")
        a:Divider()
        a:Toggle("Fine timing","shoot.fine",true,"Shifts the release by a few milliseconds per shot type, learned from the game's verdict. The aim stays at 77%.")
        a:Divider()
        a:Toggle("Contest-aware timing","shoot.contestAware",true,"When a defender is close, the release uses its own timing, starting a few milliseconds earlier and learning from the game's verdict. Fixes contested shots landing late. The aim stays at 77%.")
        a:Divider()
        if Hub.dev then
            a:Divider()
            a:Toggle("Shot journal","shoot.journal",true,"Saves one line per shot to TRAPPED_journal2.csv (shot type, release, verdict, contest, ping).")
            a:Divider()
            a:Button("Copy Auto Time log",function()
                if _G.__TRAPPED_AGLOG_COPY then _G.__TRAPPED_AGLOG_COPY() end
            end)
        end
    end)

    
    do
        local STYLES={"None","Bat","Roblox","Rocket","Hoop","Vertical","Funnel","Funnel2","Pill","Arrow","Tube","Diamond"}
        local mg=pg:Group("Meter style")
        local function profile()
            local fw=Hub.Framework and Hub.Framework()
            local pc=fw and fw.Controllers and fw.Controllers.Player
            return fw,pc and pc.ProfileData
        end
        local function current()
            local _,pd=profile()
            local m=pd and pd.SavedSettings and pd.SavedSettings.Meter
            return m and m.Type
        end
        local function setStyle(name)
            local fw,pd=profile()
            if not fw then Hub:Notify("Game not found yet. Join a game first.","warn"); return end
            local ok=false
            pcall(function()
                local w=fw.Services.PlayerService.UpdateSetting
                w:Fire({"Meter"},"Type",name); ok=true
            end)
            if not ok then
                ok=pcall(function()
                    game:GetService("ReplicatedStorage").Aero.AeroRemoteServices.PlayerService.UpdateSetting:FireServer({"Meter"},"Type",name)
                end)
            end
            pcall(function() pd.SavedSettings.Meter.Type=name end)
            
            local function hideOld()
                pcall(function()
                    local ch=myChar()
                    if not ch then return end
                    local PROPS={ImageLabel="ImageTransparency",ImageButton="ImageTransparency",Frame="BackgroundTransparency",
                        TextLabel="TextTransparency",UIStroke="Transparency"}
                    for _,d in ipairs(ch:GetDescendants()) do
                        if d:IsA("BillboardGui") and d.Name:sub(-5)=="Meter" then
                            local mine=(d.Name==name.."Meter")
                            for _,x in ipairs(d:GetDescendants()) do
                                local pr=PROPS[x.ClassName]
                                if pr then
                                    Hub._meterOrig=Hub._meterOrig or setmetatable({},{__mode="k"})
                                    local o=Hub._meterOrig[x]
                                    if mine then
                                        if o ~= nil then x[pr]=o; Hub._meterOrig[x]=nil end   
                                    else
                                        if o==nil then Hub._meterOrig[x]=x[pr] end
                                        x[pr]=1
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            hideOld(); task.delay(0.3,hideOld); task.delay(1,hideOld)
            bootLog("meter style: set to "..name.." ("..(ok and "sent" or "FAILED")..")")
            Hub:Notify(ok and ("Meter style: "..name) or "Could not change the meter style","info")
        end
        local upd
        upd=mg:Status("Current meter",function()
            local c=current()
            return c and tostring(c) or "unknown",Color3.fromRGB(110,230,140)
        end)
        mg:Divider()
        local function step(d)
            local c=current()
            local i=1
            for k,v in ipairs(STYLES) do if v==c then i=k end end
            setStyle(STYLES[((i-1+d)%#STYLES)+1])
            task.delay(0.4,function() pcall(upd) end)
        end
        mg:Button("Next meter style",function() step(1) end,"primary")
        mg:Button("Previous meter style",function() step(-1) end)
        task.spawn(function() while Hub.alive do task.wait(3); pcall(upd) end end)
    end

    if not Hub.dev then State["shoot.debug"]=false; State["shoot.journal"]=false end
    State["dev.trace"]=false; State["shoot.watch"]=false      
State["shoot.delay"]=0; State["shoot.lead"]=false; State["shoot.learn"]=false
State["shoot.variance"]=false          
State["shoot.watch"]=false             
UI.setStatus(State["shoot.perfect"]==true and "idle" or "off")
end








do
    local PLAZA_PLACE=115776365257536
    local pg=newPage("Menus","Game Menus","Open the game's menus and shops from anywhere.")
    
    
    local fwTry,fwNext=0,0
    local function framework()
        local fw=Hub._fw
        if fw then
            if rawget(fw,"Controllers")~=nil then return fw end      
            Hub._fw=nil
        end
        local now=os.clock()
        if now<fwNext then return nil end
        fwTry=fwTry+1
        fwNext=now+math.min(3*fwTry,30)                              
        pcall(function()
            if type(getgc)~="function" then fwNext=now+3600; return end
            for _,t in ipairs(getgc(true)) do
                if type(t)=="table" then
                    local c=rawget(t,"Controllers")
                    if type(c)=="table" and rawget(t,"Services")~=nil and type(rawget(c,"Gui"))=="table" then
                        Hub._fw=t; fwTry=0; break
                    end
                end
            end
        end)
        return Hub._fw
    end
    Hub.Framework=framework
    local function guiCtl()
        local fw=framework()
        local g=fw and fw.Controllers and fw.Controllers.Gui
        if g then return g end
        local ok,res=pcall(function()
            local ps=LP:FindFirstChild("PlayerScripts")
            local m=ps and ps:FindFirstChild("Aero") and ps.Aero:FindFirstChild("Controllers")
                and ps.Aero.Controllers:FindFirstChild("Gui")
            return m and require(m)
        end)
        if ok and type(res)=="table" and type(res.ShowComponent)=="function" then return res end
        return nil
    end
    local function comp(name)
        local g=guiCtl()
        return g and g.ActiveComponents and g.ActiveComponents[name], g
    end
    local function notLoaded(label)
        Hub:Notify(label.." only exists in the Plaza. Use \"Go to the Plaza\".","warn")
    end
    local function showComp(name,label,...)
        local c,g=comp(name)
        if not g then Hub:Notify("Game menu controller not found","error"); return false end
        if not c then notLoaded(label or name); return false end
        local ok,err=pcall(g.ShowComponent,g,name,...)
        if not ok then Hub:Notify((label or name)..": "..tostring(err),"error"); return false end
        return true
    end
    local function tabMenu(method,label,...)
        local tm,g=comp("TabMenu")
        if not g then Hub:Notify("Game menu controller not found","error"); return end
        if not tm then Hub:Notify("The tab menu is not loaded in this place","warn"); return end
        local ok,err=pcall(tm[method],tm,...)
        if not ok then Hub:Notify(label..": "..tostring(err),"error") end
    end
    local function tabPage(name,label)
        local tm,g=comp("TabMenu")
        if not g then Hub:Notify("Game menu controller not found","error"); return end
        if not tm or not tm.Pages or not tm.Pages[name] then
            Hub:Notify(label.." is not available here","warn"); return
        end
        local ok,err=pcall(tm.OpenOnPage,tm,name,function() tm.Pages[name]:Show() end)
        if not ok then Hub:Notify(label..": "..tostring(err),"error") end
    end
    local function goPlaza()
        if game.PlaceId==PLAZA_PLACE then Hub:Notify("You are already in the Plaza","info"); return end
        Hub:Notify("Teleporting to the Plaza...","warn")
        task.wait(0.4)
        pcall(function() TeleportService:Teleport(PLAZA_PLACE,LP) end)
    end
    local function closeAll()
        local g=guiCtl()
        if g and type(g.HideAllComponents)=="function" then pcall(g.HideAllComponents,g) end
        Hub:Notify("Game menus closed","info")
    end

    local shops=pg:Group("Plaza shops (Plaza only)")
    local stores={{"Elevate","Elevate"},{"Sole Kicks","Sole Kicks"},{"New Threads","New Threads"},
        {"Five Star","Five Star"},{"Round2NYC","Round2NYC"},{"League store","Leagues"}}
    for _,d in ipairs(stores) do
        shops:Button(d[1],function() showComp("Store",d[1],d[2]) end)
        shops:Divider()
    end
    shops:Button("Barber shop",function() showComp("BarberShop","The barber shop") end)
    shops:Divider()
    shops:Button("Dye shop",function() showComp("Dye","The dye shop") end)
    shops:Divider()
    shops:Button("Go to the Plaza",function() goPlaza() end)

    local tm=pg:Group("Tab menu pages (any place)")
    tm:Button("Tab menu",function() showComp("TabMenu","The tab menu") end)
    tm:Divider()
    tm:Button("Coin store",function() tabMenu("OpenStore","Coin store","Coins") end)
    tm:Divider()
    tm:Button("Ticket store",function() tabMenu("OpenStore","Ticket store","Tickets") end)
    tm:Divider()
    tm:Button("Season pass",function() tabMenu("LoadSeasonPass","Season pass") end)
    tm:Divider()
    tm:Button("Daily tasks",function() tabMenu("LoadDailyTasks","Daily tasks") end)
    tm:Divider()
    tm:Button("Profile",function() tabMenu("LoadProfile","Profile") end)
    tm:Divider()
    tm:Button("Inventory",function() tabPage("Inventory","Inventory") end)
    tm:Divider()
    tm:Button("Animation store",function() tabPage("AnimationStore","Animation store") end)

    local gm=pg:Group("Other game menus")
    gm:Button("Stat sheet",function() showComp("Statsheet","The stat sheet") end)
    gm:Divider()
    gm:Button("Emote wheel",function() showComp("EmoteWheel","The emote wheel") end)
    gm:Divider()
    gm:Button("Celebrations",function() showComp("Celebrations","Celebrations") end)
    gm:Divider()
    gm:Button("Quick chat",function() showComp("QuickChat","Quick chat") end)
    gm:Divider()
    gm:Button("Close all game menus",function() closeAll() end)

    local cu=pg:Group("Open by name")
    cu:Input("Menu name","menus.custom","e.g. Pickups","Any menu loaded in this place, by exact name.")
    cu:Divider()
    cu:Button("Open it",function()
        local n=tostring(State["menus.custom"] or ""):gsub("%s","")
        if n=="" then Hub:Notify("Type a menu name first","warn"); return end
        showComp(n,n)
    end)
end






do
    local pgO=newPage("Offense","Offense","Automatic plays while you have the ball. Needs Auto Time on for shots.")
    local pgD=newPage("Defense","Defense","Help on the other end of the floor.")
    local pgX=newPage("Extras","Extras","Movement, camera and daily extras.")

    
    local o1=pgO:Group("Shooting")
    o1:Toggle("Auto shoot when open","play.autoShoot",false,"Starts your shot when you have the ball, are in range and no defender is close. Auto Time releases it.")
    o1:Divider()
    o1:Slider("Shot range","play.shotRange",10,45,26,0," studs","Only shoot this close to the hoop.")
    o1:Divider()
    o1:Slider("Open distance","play.openDist",3,15,7,0," studs","Nearest defender must be at least this far away.")
    o1:Divider()
    o1:Toggle("Auto free throw","play.autoFT",false,"Shoots by itself when you stand still on the free-throw circle with the ball.")
    o1:Divider()
    o1:Toggle("Jump shot height","play.jumpOn",false,"Changes how high you go up on a jump shot. Only your own jump shots.")
    o1:Divider()
    o1:Slider("Extra height","play.jumpH",0,8,2,1," studs","How much higher you go on a jump shot, on top of the game's normal jump.")
    o1:Divider()
    o1:Toggle("Always dunk when driving","play.alwaysDunk",false,"When you shoot with the ball close to the hoop while moving, the game gets the dunk request (the same one the Jump key sends) instead of a layup.")
    o1:Divider()
    o1:Slider("Dunk range","play.dunkRange",6,25,14,0," studs","Only turns a shot into a dunk this close to the hoop.")
    local o2=pgO:Group("Movement")
    o2:Toggle("Auto drive to hoop","play.drive",false,"Walks a human-like path toward a shooting spot, around defenders. Any movement key you press takes over.")
    o2:Divider()
    o2:Toggle("Auto post-up","play.autoPost",false,"Holds the post stance (G) when you have the ball near the hoop with a defender on you.")
    o2:Divider()
    o2:Slider("Post range","play.postRange",6,22,12,0," studs","Post up only this close to the hoop.")
    local o3=pgO:Group("Passing and handles")
    o3:Toggle("Auto pass when closed down","play.autoPass",false,"Passes to the most open teammate when a defender is right on you and a teammate is clearly more open.")
    o3:Divider()
    o3:Slider("Pass trigger","play.passTrigger",2,10,4,0," studs","Pass only when a defender is this close to you.")

    
    local pgB=newPage("Dribble","Dribble","Combos and escapes while you have the ball. Moves are Z, X and C, the game's own dribble keys.")
    local b0=pgB:Group("Extend my moves")
    b0:Toggle("Extend my dribble moves","play.dribExtend",false,"Works with a controller. When you do a dribble move yourself (d-pad, or Z X C V on the keyboard), it adds more moves right after, so one tap becomes a combo. Z is left, X is down, C is right, V is up.")
    b0:Divider()
    b0:Slider("Extra moves","play.dribExtra",1,4,2,0,"","How many moves it adds after yours.")
    local b1=pgB:Group("Combo 1")
    b1:Keybind("Combo 1 key","play.dribKey","N","Click, then press a key. Runs the chain Z, X, C, X, Z while you have the ball. Pick a key the game does not use (the game already uses E, Q, F, R, T, G, H, L, P, B, V, Z, X, C and the number keys). On a controller every button is already used by the game, so use Extend my moves above.")
    b1:Divider()
    b1:Slider("Combo 1 moves","play.dribCount",2,5,3,0,"","How many moves in the chain (Z, X, C, X, Z).")
    local b2=pgB:Group("Custom combos")
    b2:Keybind("Combo 2 key","play.drib2Key","None","Press while you have the ball to run combo 2.")
    b2:Divider()
    b2:Input("Combo 2 moves","play.drib2Seq","X C X","Letters Z (left), X (down), C (right) and V (up), in the order to play, up to 6 moves.")
    b2:Divider()
    b2:Keybind("Combo 3 key","play.drib3Key","None","Press while you have the ball to run combo 3.")
    b2:Divider()
    b2:Input("Combo 3 moves","play.drib3Seq","Z Z C","Letters Z, X and C in the order to play, up to 6 moves.")
    local b3=pgB:Group("Timing")
    b3:Slider("Move gap","play.dribGap",120,450,220,0," ms","Time between moves.")
    local b7=pgB:Group("Glide step back")
    b7:Toggle("Glide step back","play.glide",false,"When you do a step back (keyboard, d-pad or right stick, it reacts to the game's own step back move), you slide backward a bit further, like a glide. Only your own step back.")
    b7:Divider()
    b7:Slider("Glide distance","play.glideDist",1,12,4,0," studs","How far the glide carries you back. Higher is longer.")
    b7:Divider()
    b7:Slider("Glide speed","play.glideTime",15,70,35,0,"","How fast it happens, in hundredths of a second. Lower is a quicker burst.")
    local b5=pgB:Group("Ankle breaker")
    b5:Toggle("Auto ankle breaker","play.dribAnkle",false,"When a defender is close and moving, runs a combo aimed at his off side, away from where he is moving, to try to break his ankles. The server decides if it works.")
    b5:Divider()
    b5:Slider("Ankle range","play.dribAnkleDist",3,9,6,0," studs","Start the combo when the defender is this close.")
    b5:Divider()
    b5:Slider("Which combo","play.dribAnkleCombo",1,3,1,0,"","1, 2 or 3: the combo to run.")
    b5:Divider()
    b5:Slider("Ankle cooldown","play.dribAnkleCd",1,10,4,0," s","Minimum time between attempts.")
    b5:Divider()
    b5:Toggle("Skip Tough Ankles defenders","play.dribSkipTough",true,"Does not try on a defender who has the Tough Ankles badge (it lowers the chance of being broken). If the badge cannot be read, it tries anyway.")
    b5:Divider()
    b5:Toggle("Longer chain when off balance","play.dribLong",true,"When the defender is shifting fast, backpedaling or reacting, runs a longer chain, since every move is its own roll.")
    local b4=pgB:Group("Auto escape")
    b4:Toggle("Auto escape combo","play.dribAuto",false,"When a defender gets close while you have the ball, runs combo 1 by itself. Never while you are shooting.")
    b4:Divider()
    b4:Slider("Escape distance","play.dribAutoDist",3,10,5,0," studs","Run it when the nearest defender is this close.")
    b4:Divider()
    b4:Slider("Escape cooldown","play.dribAutoCd",1,8,3,0," s","Minimum time between automatic combos.")

    
    local d1=pgD:Group("Guarding")
    d1:Toggle("Auto guard","play.guard",false,"Holds the guard stance (G) while an opponent with the ball is close, and through their shot so your hands stay up.")
    d1:Divider()
    d1:Slider("Guard distance","play.guardRange",5,20,12,0," studs","How close the ball handler must be.")
    d1:Divider()
    d1:Toggle("Follow ball handler","play.follow",true,"While guarding, stay between the ball handler and the hoop they are attacking.")
    d1:Divider()
    d1:Toggle("Flip attacked hoop","play.flipHoop",false,"Turn on only if Auto Play drives / spaces toward the wrong hoop. Swaps which hoop counts as yours to attack.")
    local d2=pgD:Group("Stealing")
    d2:Toggle("Auto steal","play.steal",false,"Reaches only when the ball handler is in range, one try per cooldown.")
    d2:Divider()
    d2:Toggle("Lane steal","play.lane",false,"Reaches when an opponent is catching a pass near you, instead of waiting for the dribbler.")
    d2:Divider()
    d2:Slider("Steal range","play.stealRange",3,10,5,0," studs","Only reach when they are this close.")
    d2:Divider()
    d2:Slider("Steal cooldown","play.stealCd",1,5,2,1," s","Minimum time between attempts.")
    local d3=pgD:Group("Block and rebound")
    d3:Toggle("Auto block","play.block",false,"Jumps to contest when a nearby opponent starts a shot, layup or dunk.")
    d3:Divider()
    d3:Slider("Block range","play.blockRange",6,25,14,0," studs","Only react to shooters this close.")
    d3:Divider()
    d3:Slider("Block delay","play.blockDelay",0,400,120,0," ms","Wait after the shot starts before jumping. Dunks add extra.")
    d3:Divider()
    d3:Toggle("Auto rebound","play.rebound",false,"Jumps for a loose ball that is in the air near you. Experimental.")
    d3:Divider()
    d3:Slider("Rebound range","play.reboundRange",6,25,12,0," studs","How close the loose ball must be.")

    
    local x1=pgX:Group("Movement")
    x1:Toggle("Auto sprint","play.sprint",false,"Sprints while you move without the ball. Stops when you have the ball, shoot or guard.")
    x1:Divider()
    x1:Toggle("Infinite stamina","extras.infStam",false,"Keeps your stamina full on your screen: sprinting, the tired animation and the stamina bar all see a full tank. The server keeps its own count, so if it still slows you, tell me.")
    x1:Divider()
    x1:Toggle("Speed boost","play.speedOn",false,"Runs faster than normal. Keep it small: a big boost can look wrong to other players or be pulled back by the server.")
    x1:Divider()
    x1:Slider("Boost amount","play.speedMul",105,160,120,0,"%","How much faster than normal you run: 120% is a fifth faster.")
    local x2=pgX:Group("Camera")
    x2:Toggle("Custom field of view","play.fovOn",false,"Use the field of view below. Only changes your own camera.")
    x2:Divider()
    x2:Slider("Field of view","play.fov",60,120,70,0,"","Camera field of view.")
    local x3=pgX:Group("Daily")
    x3:Toggle("Auto-claim daily tasks","play.claim",false,"Collects finished daily tasks for you (the same call as the CLAIM button).")
    local x4=pgX:Group("Timing")
    x4:Toggle("Human-like timing","play.legit",true,"Adds a small random delay (80 to 200 ms) before auto block, rebound, steal and automatic shots.")


    local function fire(svc,name,...)
        local args={...}
        local ok=false
        pcall(function()
            local fw=Hub.Framework and Hub.Framework()
            local w=fw and fw.Services and fw.Services[svc] and fw.Services[svc][name]
            if type(w)=="table" and type(w.Fire)=="function" then
                w:Fire(table.unpack(args)); ok=true
            end
        end)
        if ok then return true end
        return (pcall(function()
            local r=game:GetService("ReplicatedStorage").Aero.AeroRemoteServices[svc][name]
            r:FireServer(table.unpack(args))
        end))
    end
    
    
    
    local Steer={dir=nil,at=0,realMag=0,ok=false}
    function Steer.set(d) Steer.dir=d; Steer.at=os.clock() end
    pcall(function()
        local ps=LP:FindFirstChild("PlayerScripts")
        local pmMod=ps and ps:FindFirstChild("PlayerModule")
        if not pmMod then return end
        local controls=require(pmMod):GetControls()
        local orig=controls.GetMoveVector
        local own=rawget(controls,"GetMoveVector")
        controls.GetMoveVector=function(self,...)
            local real=orig(self,...)
            Steer.realMag=real.Magnitude
            if Steer.dir and os.clock()-Steer.at<0.15 and real.Magnitude<0.1 then
                local cam=workspace.CurrentCamera
                local v=cam and cam.CFrame:VectorToObjectSpace(Steer.dir) or Steer.dir
                local flat=Vector3.new(v.X,0,v.Z)
                if flat.Magnitude>0.01 then return flat.Unit end
            end
            return real
        end
        Steer.ok=true
        track({Disconnect=function() Steer.dir=nil; pcall(function() controls.GetMoveVector=own end) end})
    end)
    Hub.SteerOK=function() return Steer.ok end
    local function teamOf(c) return c:GetAttribute("TeamIndex") or c:GetAttribute("Team") end
    
    local ballCache,ballAt,ballBusy=nil,0,false
    local function ballPart()
        if ballCache and ballCache.Parent then return ballCache end
        ballCache=nil
        local f=workspace:FindFirstChild("Basketballs")
        local b=f and f:FindFirstChild("Basketball")
        if b and b:IsA("BasePart") then ballCache=b; return b end
        
        if ballBusy or os.clock()-ballAt<6 then return nil end
        ballAt=os.clock(); ballBusy=true
        task.spawn(function()
            local n=0
            pcall(function()
                for _,d in ipairs(workspace:GetDescendants()) do
                    n=n+1
                    if n%1500==0 then task.wait() end
                    if d.Name=="Basketball" and d:IsA("BasePart") then ballCache=d; break end
                end
            end)
            ballBusy=false
        end)
        return nil
    end
    local plogBytes=0
    local function plog(msg)
        if type(appendfile)~="function" or State["stealth.quiet"]==true or not Hub.dev then return end
        plogBytes=plogBytes+#msg+10
        if plogBytes>60000 then                        
            plogBytes=0
            pcall(function() if type(writefile)=="function" then writefile("TRAPPED_play.log","(log restarted)\n") end end)
        end
        pcall(appendfile,"TRAPPED_play.log",os.date("%H:%M:%S ")..msg.."\n")
    end
    local function hasBall(c)
        if c:GetAttribute("Basketball") then return true end
        local af=c:FindFirstChild("Attributes")                 
        local bv=af and af:FindFirstChild("Basketball")
        if bv and bv:IsA("ValueBase") and bv.Value~=nil and bv.Value~=false and bv.Value~="" then return true end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        local b=ballPart()
        if hrp and b and (b.Position-hrp.Position).Magnitude<5 then return true end
        local m=c:FindFirstChild("Basketball",true)          
        return m~=nil and m:IsA("Motor6D") and m.Part1~=nil
    end
    local function opponent(me,c)
        local a,b=teamOf(me),teamOf(c)
        if a~=nil and b~=nil then return a~=b end
        if a~=nil and b==nil then return false end       
        local ha,hb=me:GetAttribute("HomeTeam"),c:GetAttribute("HomeTeam")
        if ha~=nil and hb~=nil then return ha~=hb end
        local ta,tb                                                  
        pcall(function()
            ta=LP.Team
            local pl=Players:GetPlayerFromCharacter(c)
            tb=pl and pl.Team
        end)
        if ta~=nil and tb~=nil then return ta~=tb end
        Hub._teamUnknownAt=os.clock()          
        return true
    end
    local nearList={}
    local function nearestHandler(me,maxD)
        local hrp=me:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local best,bd=nil,maxD
        local list,seen={},{}
        local mineTeam=teamOf(me)
        
        local function add(c) if c and c~=me and c.Name~="InvisCharacter" and not seen[c] and (mineTeam==nil or teamOf(c)~=nil) then seen[c]=true; list[#list+1]=c end end
        for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then add(pl.Character) end end
        local folder=workspace:FindFirstChild("Characters")      
        if folder then for _,c in ipairs(folder:GetChildren()) do if c:IsA("Model") then add(c) end end end
        nearList=list
        for _,c in ipairs(list) do
            if c~=me then
                local h=c:FindFirstChild("HumanoidRootPart")
                if h and hasBall(c) and opponent(me,c) then
                    local dist=(h.Position-hrp.Position).Magnitude
                    if dist<bd then best,bd=c,dist end
                end
            end
        end
        return best,bd
    end
    
    
    local manTgt=nil
    local function matchup(me,bh)
        local mh=me:FindFirstChild("HumanoidRootPart")
        if not mh then return nil end
        local defs,atks={{c=me,p=mh.Position}},{}
        for _,c in ipairs(nearList) do
            local h=c:FindFirstChild("HumanoidRootPart")
            if c~=me and h and c.Name~="InvisCharacter" then
                if opponent(me,c) then atks[#atks+1]={c=c,p=h.Position} else defs[#defs+1]={c=c,p=h.Position} end
            end
        end
        local prs={}
        for i,d in ipairs(defs) do
            for j,a in ipairs(atks) do
                local dx,dz=d.p.X-a.p.X,d.p.Z-a.p.Z
                local dd=dx*dx+dz*dz
                if i==1 and a.c==manTgt then dd=dd*0.4 end         
                prs[#prs+1]={i=i,j=j,d=dd}
            end
        end
        table.sort(prs,function(x,y) return x.d<y.d end)
        local du,au,asg={}, {}, {}
        for _,pr in ipairs(prs) do
            if not du[pr.i] and not au[pr.j] then du[pr.i]=true; au[pr.j]=true; asg[pr.i]=atks[pr.j].c end
        end
        local bhDef
        if bh then
            local bp=bh:FindFirstChild("HumanoidRootPart")
            for i=2,#defs do
                if asg[i]==bh and bp and (defs[i].p-bp.Position).Magnitude<=10 then bhDef=defs[i].c end
            end
        end
        return asg[1],bhDef
    end
    local guarding,lastSteal,acc,dbgWhy=false,0,0,nil
    local followTgt=nil
    local followGoal,followBall,followGap=nil,nil,3.5     
    local guardUntil,lastGuarded=0,nil
    
    local function attackGoal(c)
        local goals=Hub._goals
        local hh=c and c:FindFirstChild("HumanoidRootPart")
        if not goals or not hh then return nil end
        
        
        
        
        local home=c:GetAttribute("HomeTeam")
        local op=typeof(c:GetAttribute("OriginalPosition"))=="Vector3" and c:GetAttribute("OriginalPosition") or nil
        if type(home)=="boolean" or op then
            local cand={}
            for _,g in ipairs(goals) do
                if g.Parent and (Vector3.new(g.Position.X-hh.Position.X,0,g.Position.Z-hh.Position.Z)).Magnitude<130 then cand[#cand+1]=g end
            end
            if #cand>=2 then
                local def,dd=nil,math.huge
                if type(home)=="boolean" then
                    table.sort(cand,function(a,b) if math.abs(a.Position.X-b.Position.X)>1 then return a.Position.X<b.Position.X end return a.Position.Z<b.Position.Z end)
                    def=home and cand[1] or cand[#cand]
                else
                    for _,g in ipairs(cand) do
                        local d=(Vector3.new(g.Position.X-op.X,0,g.Position.Z-op.Z)).Magnitude
                        if d<dd then def,dd=g,d end
                    end
                end
                local atk,ad=nil,-1
                for _,g in ipairs(cand) do
                    if g~=def then
                        local d=(Vector3.new(g.Position.X-def.Position.X,0,g.Position.Z-def.Position.Z)).Magnitude
                        if d>ad then atk,ad=g,d end
                    end
                end
                if atk then
                    local r=(State["play.flipHoop"]==true) and def or atk
                    if c==myChar() then
                        local key=string.format("%s>%.0f,%.0f",tostring(home),r.Position.X,r.Position.Z)
                        if key~=Hub._atkLog then Hub._atkLog=key; pcall(plog,string.format("attacking hoop: home=%s -> hoop (%.0f,%.0f)%s",tostring(home),r.Position.X,r.Position.Z,State["play.flipHoop"]==true and " [flipped]" or "")) end
                    end
                    return r.Position
                end
            end
        end
        
        local look=Vector3.new(hh.CFrame.LookVector.X,0,hh.CFrame.LookVector.Z)
        local vel=Vector3.new(hh.AssemblyLinearVelocity.X,0,hh.AssemblyLinearVelocity.Z)
        local dirv=(vel.Magnitude>4 and vel.Unit) or (look.Magnitude>0.01 and look.Unit) or nil
        local best,bs=nil,-math.huge
        for _,g in ipairs(goals) do
            if g.Parent then
                local off=Vector3.new(g.Position.X-hh.Position.X,0,g.Position.Z-hh.Position.Z)
                if off.Magnitude>1 then
                    local sc=-off.Magnitude*0.01
                    if dirv then sc=sc+off.Unit:Dot(dirv) end
                    if sc>bs then best,bs=g,sc end
                end
            end
        end
        return best and best.Position or nil
    end
    
    
    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_follow") end)
    RunService:BindToRenderStep("TRAPPED_follow",Enum.RenderPriority.Last.Value,function()
        local t=followTgt
        if not t or not t.Parent or State["play.guard"]~=true then Hub._followFar=false; return end
        local me=myChar()
        local hum=me and me:FindFirstChildOfClass("Humanoid")
        local hh=t:FindFirstChild("HumanoidRootPart")
        local mine=me and me:FindFirstChild("HumanoidRootPart")
        if not (hum and hh and mine) then return end
        local dir
        if followGoal then
            
            local tg=Vector3.new(followGoal.X-hh.Position.X,0,followGoal.Z-hh.Position.Z)
            dir=tg.Magnitude>0.1 and tg.Unit or Vector3.new(0,0,1)
        else
            local toMe=Vector3.new(mine.Position.X-hh.Position.X,0,mine.Position.Z-hh.Position.Z)
            dir=toMe.Magnitude>0.1 and toMe.Unit or Vector3.new(0,0,1)
        end
        local spot=hh.Position+dir*followGap
        if followBall then                              
            local tb=Vector3.new(followBall.X-hh.Position.X,0,followBall.Z-hh.Position.Z)
            local sh=math.min(tb.Magnitude*0.3,4)
            if tb.Magnitude>0.1 then spot=spot+tb.Unit*sh end
        end
        local d=Vector3.new(spot.X-mine.Position.X,0,spot.Z-mine.Position.Z)
        Hub._followFar=d.Magnitude>9
        if d.Magnitude>1.2 then
            Steer.set(d.Unit)
        else
            
            
            local side=Vector3.new(-dir.Z,0,dir.X)
            local sgn=math.sin(os.clock()*5)>=0 and 1 or -1
            local mix=side*sgn*0.8+(d.Magnitude>0.3 and d.Unit*0.4 or Vector3.zero)
            if mix.Magnitude>0.05 then Steer.set(mix.Unit) end
        end
    end)
    track({Disconnect=function() followTgt=nil; pcall(function() RunService:UnbindFromRenderStep("TRAPPED_follow") end) end})
    local function setGuard(on)
        if guarding==on then return end
        if fire("InputService","HoldG",{HoldingG=on}) then guarding=on end
    end
    Hub.Changed:Connect(function(id)
        if id=="play.guard" and State[id]~=true then setGuard(false) end
    end)
    track({Disconnect=function() if guarding then pcall(setGuard,false) end end})
    local function humanDelay()
        if State["play.legit"]==false then return 0 end
        return 0.08+math.random()*0.12
    end
    local SHOT_ACTIONS={Shooting=true,Dunking=true,ClutchLayup=true,ContactLayup=true}
    local lastBlock,lastReb=0,0
    
    local COMBO={"Z","X","C","X","Z"}
    local comboBusy=false
    local BUSY_ACTIONS={Shooting=true,Dunking=true,ClutchLayup=true,ContactLayup=true,Passing=true,CatchingLob=true,PickingUp=true,Dropping=true,Stealing=true,Blocking=true}
    local function runCombo(seq,aimDir)
        if comboBusy then return end
        local me=myChar()
        if not me or not hasBall(me) then return end
        local act=tostring(me:GetAttribute("Action") or "")
        if act=="Shooting" or act=="Dunking" then return end
        comboBusy=true
        task.spawn(function()
            pcall(function()
                local gap=(tonumber(State["play.dribGap"]) or 220)/1000
                for i,key in ipairs(seq) do
                    local m=myChar()
                    if not m or not Hub.alive or not hasBall(m) then break end
                    local hum=m:FindFirstChildOfClass("Humanoid")
                    local dir=aimDir or (hum and hum.MoveDirection) or Vector3.new(0,0,0)
                    fire("InputService","Dribble",key,true,dir.X,0,dir.Z)
                    task.wait(0.05)
                    fire("InputService","Dribble",key,false,0,0,0)
                    task.wait(gap)
                end
            end)
            comboBusy=false                 
        end)
    end
    local function parseSeq(str)
        local seq={}
        for ch in tostring(str or ""):upper():gmatch("[ZXCV]") do
            seq[#seq+1]=ch
            if #seq>=6 then break end
        end
        return seq
    end
    local function combo1Seq()
        local n=math.clamp(math.floor(tonumber(State["play.dribCount"]) or 3),2,5)
        local seq={}
        for i=1,n do seq[i]=COMBO[i] end
        return seq
    end
    track(UIS.InputBegan:Connect(function(inp)
        if UIS:GetFocusedTextBox() or comboBusy then return end
        if inp.UserInputType~=Enum.UserInputType.Keyboard and not tostring(inp.UserInputType):find("Gamepad",1,true) then return end
        local name=inp.KeyCode.Name
        local k1,k2,k3=State["play.dribKey"],State["play.drib2Key"],State["play.drib3Key"]
        
        local MV={Z="Z",X="X",C="C",V="V",DPadLeft="Z",DPadDown="X",DPadRight="C",DPadUp="V"}
        if State["play.dribExtend"]==true and MV[name] and name~=k1 and name~=k2 and name~=k3 then
            local me=myChar()
            if me and hasBall(me) then
                local act=tostring(me:GetAttribute("Action") or "")
                if act~="Shooting" and act~="Dunking" then
                    local CYC={"Z","X","C","X","Z","C"}
                    local n=math.clamp(math.floor(tonumber(State["play.dribExtra"]) or 2),1,4)
                    local at=({Z=1,X=2,C=3,V=4})[MV[name]]
                    local seq={}
                    for j=1,n do seq[j]=CYC[(at+j-1)%#CYC+1] end
                    local gap=(tonumber(State["play.dribGap"]) or 220)/1000
                    task.delay(gap,function() if Hub.alive and State["play.dribExtend"]==true then runCombo(seq) end end)
                end
            end
            return
        end
        if k1 and k1~="None" and name==k1 then runCombo(combo1Seq())
        elseif k2 and k2~="None" and name==k2 then local q=parseSeq(State["play.drib2Seq"] or "X C X"); if #q>0 then runCombo(q) end
        elseif k3 and k3~="None" and name==k3 then local q=parseSeq(State["play.drib3Seq"] or "Z Z C"); if #q>0 then runCombo(q) end
        end
    end))
    
    do
        local lastAct,lastAnim
        track(RunService.Heartbeat:Connect(function()
            if not (State["dev.trace"]==true and Hub.dev==true) then lastAct=nil; return end
            local m=myChar()
            if not m then return end
            local act=tostring(m:GetAttribute("Action") or "")
            local an=tostring(m:GetAttribute("BaseAnimation") or "")
            if act~=lastAct or an~=lastAnim then
                lastAct,lastAnim=act,an
                local hum=m:FindFirstChildOfClass("Humanoid")
                bootLog(string.format("trace %.3f: action=%s anim=%s inAir=%s state=%s",os.clock()%1000,act,an,tostring(m:GetAttribute("InAir")),
                    hum and tostring(hum:GetState()) or "?"))
            end
        end))
    end
    
    do
        local lifting,t0,done=false,0,0
        local DUR=0.6
        track(RunService.Heartbeat:Connect(function(dt)
            local m=myChar()
            local hrp=m and m:FindFirstChild("HumanoidRootPart")
            if not hrp then lifting=false; return end
            local act=tostring(m:GetAttribute("Action") or "")
            local a=tostring(m:GetAttribute("BaseAnimation") or ""):lower()
            if lifting then
                local k=(os.clock()-t0)/DUR
                local H=math.clamp(tonumber(State["play.jumpH"]) or 2,0,8)
                local want=(k>=1 or State["play.jumpOn"]~=true or act~="Shooting") and 0 or H*math.sin(math.pi*k)
                local step=want-done
                if math.abs(step)>1e-4 then hrp.CFrame=hrp.CFrame+Vector3.new(0,step,0); done=want end
                if k>=1 or State["play.jumpOn"]~=true or act~="Shooting" then
                    if done~=0 then hrp.CFrame=hrp.CFrame-Vector3.new(0,done,0); done=0 end
                    lifting=false
                    bootLog("jump height: arc finished")
                end
                return
            end
            if State["play.jumpOn"]~=true or act~="Shooting" then return end
            if a:find("layup",1,true) or a:find("dunk",1,true) or a:find("floater",1,true) then return end
            if os.clock()-(Hub._jhAt or 0)<1 then return end
            Hub._jhAt=os.clock()
            lifting=true; t0=os.clock(); done=0
            local v=hrp.AssemblyLinearVelocity
            bootLog(string.format("jump height: lifting %.1f studs for %s (vy %.1f, state %s, inAir %s)",
                tonumber(State["play.jumpH"]) or 2,a,v.Y,
                tostring(m:FindFirstChildOfClass("Humanoid") and m:FindFirstChildOfClass("Humanoid"):GetState()),tostring(m:GetAttribute("InAir"))))
        end))
    end
    
    
    do
        local logged,lowAt,base,slowLogged=false,-99,{},false
        
        function Hub.DumpAttrs(tag)
            pcall(function()
                local m=myChar()
                if not m then return end
                local parts={}
                local f=m:FindFirstChild("Attributes")
                if f then
                    for _,c in ipairs(f:GetChildren()) do
                        local v=c:IsA("ValueBase") and c.Value or nil
                        if type(v)=="number" then parts[#parts+1]=c.Name.."="..string.format("%.2f",v)
                        elseif type(v)=="boolean" then parts[#parts+1]=c.Name.."="..tostring(v) end
                    end
                end
                table.sort(parts)
                local at={}
                for k,v in pairs(m:GetAttributes()) do
                    if type(v)=="number" then at[#at+1]=k.."="..string.format("%.2f",v) end
                end
                table.sort(at)
                local hum=m:FindFirstChildOfClass("Humanoid")
                bootLog("attrs ("..tag.."): values["..#parts.."] "..table.concat(parts," ").." | attributes "..table.concat(at," ")
                    ..(hum and string.format(" | humanoid WalkSpeed=%.1f",hum.WalkSpeed) or ""))
            end)
        end
        local SPEEDS={"WalkSpeed","SpeedBoost","AccelerationBoost"}
        local function getVal(m,name)
            local folder=m:FindFirstChild("Attributes")
            local v=folder and folder:FindFirstChild(name)
            if v and v:IsA("ValueBase") then return tonumber(v.Value),v end
            return tonumber(m:GetAttribute(name)),nil
        end
        track(RunService.Heartbeat:Connect(function()
            if State["extras.infStam"]~=true then logged=false; base={}; return end
            local m=myChar()
            if not m then return end
            local folder=m:FindFirstChild("Attributes")
            local sv=folder and folder:FindFirstChild("Stamina")
            local mv=folder and folder:FindFirstChild("MaxStamina")
            local top=(mv and tonumber(mv.Value)) or tonumber(m:GetAttribute("MaxStamina")) or 100
            
            local cur=(sv and sv:IsA("ValueBase") and tonumber(sv.Value)) or tonumber(m:GetAttribute("Stamina"))
            if cur and cur<top-0.5 and cur<45 then
                if os.clock()-lowAt>20 and os.clock()-(Hub._dumpLowAt or 0)>20 then Hub._dumpLowAt=os.clock(); Hub.DumpAttrs("stamina low "..string.format("%.0f",cur)) end
                lowAt=os.clock()
            end
            if not Hub._dumpFullAt then Hub._dumpFullAt=os.clock(); Hub.DumpAttrs("stamina on") end
            local low=(os.clock()-lowAt)<1.5
            if not low then
                for _,n in ipairs(SPEEDS) do
                    local v=getVal(m,n)
                    if v and v>0 then base[n]=v end                 
                end
            else
                for _,n in ipairs(SPEEDS) do
                    local want=base[n]
                    if State["play.speedOn"]==true and (n=="WalkSpeed" or n=="SpeedBoost") then want=nil end
                    local v,obj=getVal(m,n)
                    if want and v and v<want-0.01 then
                        if not slowLogged then slowLogged=true; bootLog(string.format("infinite stamina: the server cut %s to %.1f, putting it back to %.1f",n,v,want)) end
                        if obj then obj.Value=want end
                        m:SetAttribute(n,want)
                    end
                end
            end
            if sv and sv:IsA("ValueBase") then
                if (tonumber(sv.Value) or 0)<top then
                    if not logged then logged=true; bootLog(string.format("infinite stamina: refilled the game's stamina value %.0f -> %.0f",tonumber(sv.Value) or 0,top)) end
                    sv.Value=top
                end
            end
            local curA=tonumber(m:GetAttribute("Stamina"))
            if curA and curA<top then m:SetAttribute("Stamina",top) end
        end))
    end
    
    
    do
        local base,last,bLog={},{},0
        local NAMES={"WalkSpeed","SpeedBoost"}
        local dumped=false
        track(RunService.Heartbeat:Connect(function()
            local m=myChar()
            local folder=m and m:FindFirstChild("Attributes")
            if State["play.speedOn"]~=true then
                
                for n,v in pairs(base) do
                    local obj=folder and folder:FindFirstChild(n)
                    if obj and obj:IsA("ValueBase") and last[n] and tonumber(obj.Value)==last[n] then obj.Value=v end
                    if m and last[n] and tonumber(m:GetAttribute(n))==last[n] then m:SetAttribute(n,v) end
                end
                base,last={},{}
                return
            end
            if not folder then return end
            if not dumped and Hub.DumpAttrs then dumped=true; Hub.DumpAttrs("speed boost on") end
            if State["cfg.speed2"]~=true then            
                Hub:Set("cfg.speed2",true)
                if (tonumber(State["play.speedMul"]) or 0)<=105 then Hub:Set("play.speedMul",120) end
            end
            local mul=math.clamp((tonumber(State["play.speedMul"]) or 120)/100,1.05,1.6)
            for _,n in ipairs(NAMES) do
                local obj=folder:FindFirstChild(n)
                if obj and not obj:IsA("ValueBase") then obj=nil end
                local cur=obj and tonumber(obj.Value) or tonumber(m:GetAttribute(n))
                if cur then
                    if last[n]==nil or math.abs(cur-last[n])>0.001 then base[n]=cur end     
                    local want=base[n]*mul
                    if cur>0 and math.abs(cur-want)>0.001 then
                        if obj then obj.Value=want end
                        pcall(function() m:SetAttribute(n,want) end)
                    end
                    last[n]=want
                end
            end
            do   
                local hrp=m:FindFirstChild("HumanoidRootPart")
                local hum=m:FindFirstChildOfClass("Humanoid")
                local bw=tonumber(base.WalkSpeed)
                if hrp and hum and bw and bw>0 and hum.MoveDirection.Magnitude>0.1 then
                    local want=bw*mul
                    local v=hrp.AssemblyLinearVelocity
                    local cur=Vector3.new(v.X,0,v.Z).Magnitude
                    if cur>2 and cur<want*0.97 then
                        local d=hum.MoveDirection
                        hrp.CFrame=hrp.CFrame+Vector3.new(d.X,0,d.Z).Unit*math.min(want-cur,want*0.3)*(1/60)
                    end
                end
            end
            if os.clock()-bLog>5 then
                bLog=os.clock()
                bootLog(string.format("speed boost: WalkSpeed %.1f (server %.1f), SpeedBoost %.1f (server %.1f)",
                    tonumber(last.WalkSpeed) or 0,tonumber(base.WalkSpeed) or 0,tonumber(last.SpeedBoost) or 0,tonumber(base.SpeedBoost) or 0))
            end
        end))
    end
    
    do
        local glideAt,glideConn,glideAnim=0,nil,nil
        local function startGlide()
            local m=myChar(); local hrp=m and m:FindFirstChild("HumanoidRootPart")
            if not hrp or os.clock()-glideAt<0.5 then return end
            glideAt=os.clock()
            local dist=math.clamp(tonumber(State["play.glideDist"]) or 4,1,12)
            local T=math.clamp((tonumber(State["play.glideTime"]) or 35)/100,0.15,0.7)
            local back=-Vector3.new(hrp.CFrame.LookVector.X,0,hrp.CFrame.LookVector.Z)
            if back.Magnitude<0.1 then return end
            back=back.Unit
            local t0=os.clock()
            local p0=hrp.Position
            local moved=0                       
            local useCF=false
            bootLog(string.format("glide: step back seen, gliding %.1f studs over %.2fs",dist,T))
            local conn
            conn=RunService.Heartbeat:Connect(function(dt)
                local k=(os.clock()-t0)/T
                if k>=1 or not Hub.alive or not hrp.Parent or State["play.glide"]~=true then
                    if hrp.Parent then bootLog(string.format("glide: moved %.1f studs (%s)",(hrp.Position-p0):Dot(back),useCF and "cframe" or "velocity")) end
                    conn:Disconnect(); return
                end
                
                if not useCF and k>0.3 and (hrp.Position-p0):Dot(back)<dist*0.15 then useCF=true end
                local sp=(dist/T)*2*(1-k)
                if useCF then
                    local step=sp*(dt or 0.016)
                    moved=moved+step
                    hrp.CFrame=hrp.CFrame+back*step
                else
                    local v=back*sp
                    local cur=hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity=Vector3.new(v.X,cur.Y,v.Z)
                end
            end)
        end
        
        local lastX=0
        function Hub.GlideKey(k,down)
            if down~=true or State["play.glide"]~=true then return end
            if k=="X" then
                local t=os.clock(); lastX=t
                task.delay(0.28,function() if lastX==t and Hub.alive and State["play.glide"]==true then startGlide() end end)
            else lastX=0 end
        end
        local function hook(animator)
            if glideConn then glideConn:Disconnect() end
            glideAnim=animator
            glideConn=animator.AnimationPlayed:Connect(function(tr)
                if State["play.glide"]~=true or not Hub.alive then return end
                local nm=""
                pcall(function() nm=tostring(tr.Animation and tr.Animation.Name or tr.Name) end)
                local low=nm:lower():gsub("[%s_]","")
                local plain=low=="jog" or low=="idle" or low=="sprint" or low=="animation" or low:sub(1,3)=="jog" or low=="walk"
                if not plain and (Hub._glideLogN or 0)<60 then
                    Hub._glideLogN=(Hub._glideLogN or 0)+1
                    bootLog("glide: animation played: "..nm)
                end
                if low:find("stepback",1,true) and not low:find("snatch",1,true) then
                    task.defer(startGlide)
                end
            end)
        end
        track(RunService.Heartbeat:Connect(function()
            if State["play.glide"]~=true then return end
            local m=myChar()
            local hum=m and m:FindFirstChildOfClass("Humanoid")
            local an=hum and hum:FindFirstChildOfClass("Animator")
            if an and an~=glideAnim then pcall(hook,an) end
        end))
    end
    
    local ankAt,ankAcc=0,0
    track(RunService.Heartbeat:Connect(function(dt)
        ankAcc=ankAcc+dt
        if ankAcc<0.15 then return end
        ankAcc=0
        if State["play.dribAnkle"]~=true or comboBusy then return end
        if os.clock()-ankAt<(tonumber(State["play.dribAnkleCd"]) or 4) then return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            if not mine or not hasBall(me) then return end
            if BUSY_ACTIONS[tostring(me:GetAttribute("Action") or "")] then return end
            nearestHandler(me,0.001)
            local best,bd
            for _,c in ipairs(nearList) do
                local oh=c:FindFirstChild("HumanoidRootPart")
                if oh and opponent(me,c) then
                    local d=(oh.Position-mine.Position).Magnitude
                    if not bd or d<bd then best,bd=oh,d end
                end
            end
            if not best or bd>(tonumber(State["play.dribAnkleDist"]) or 6) then return end
            local defChar=best.Parent
            if State["play.dribSkipTough"]~=false and defChar then
                local tough=false
                pcall(function()
                    local bg=defChar:FindFirstChild("Badges",true)
                    for _,d in ipairs(bg and bg:GetDescendants() or {}) do
                        if d.Name:find("Tough Ankles",1,true) or (d:IsA("ImageLabel") and tostring(d.Image):find("14266519222",1,true)) then tough=true; break end
                    end
                end)
                if tough then return end
            end
            local rel=Vector3.new(best.Position.X-mine.Position.X,0,best.Position.Z-mine.Position.Z)
            if rel.Magnitude<0.5 then return end
            local fwd=rel.Unit
            local side=Vector3.new(-fwd.Z,0,fwd.X)
            local vel=Vector3.new(best.AssemblyLinearVelocity.X,0,best.AssemblyLinearVelocity.Z)
            local lat=vel:Dot(side)
            if lat==0 then lat=(math.random()<0.5) and 0.01 or -0.01 end    
            local offBal=false
            do
                local dact=tostring(defChar and defChar:GetAttribute("Action") or "")
                if dact~="" or (defChar and defChar:GetAttribute("InRetreat")==true) or math.abs(lat)>=8 then offBal=true end
                
                if vel:Dot(fwd)<-5 then offBal=true end
            end
            local sgn=(lat>0) and -1 or 1                              
            local aim=(side*sgn*0.9+fwd*0.2).Unit
            local w=math.clamp(math.floor(tonumber(State["play.dribAnkleCombo"]) or 1),1,3)
            local seq
            if w==2 then seq=parseSeq(State["play.drib2Seq"] or "X C X") elseif w==3 then seq=parseSeq(State["play.drib3Seq"] or "Z Z C") else seq=combo1Seq() end
            if not seq or #seq==0 then return end
            if offBal and State["play.dribLong"]~=false then                 
                local i=1
                while #seq<5 do seq[#seq+1]=COMBO[((i-1)%#COMBO)+1]; i=i+1 end
            end
            ankAt=os.clock()
            bootLog(string.format("ankle breaker: defender %.1f studs away, moving %.1f sideways, running %d moves%s",bd,lat,#seq,offBal and " (off balance)" or ""))
            runCombo(seq,aim)
        end)
    end))
    
    local escAt,escAcc=0,0
    track(RunService.Heartbeat:Connect(function(dt)
        escAcc=escAcc+dt
        if escAcc<0.2 then return end
        escAcc=0
        if State["play.dribAuto"]~=true or comboBusy then return end
        if os.clock()-escAt<(tonumber(State["play.dribAutoCd"]) or 3) then return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            if not mine or not hasBall(me) then return end
            local act=tostring(me:GetAttribute("Action") or "")
            if BUSY_ACTIONS[act] then return end
            nearestHandler(me,0.001)                                   
            local near=math.huge
            for _,c in ipairs(nearList) do
                local oh=c:FindFirstChild("HumanoidRootPart")
                if oh and opponent(me,c) then near=math.min(near,(oh.Position-mine.Position).Magnitude) end
            end
            if near<=(tonumber(State["play.dribAutoDist"]) or 5) then
                escAt=os.clock()
                runCombo(combo1Seq())
            end
        end)
    end))
    track(RunService.Heartbeat:Connect(function(dt)
        acc=acc+dt
        if acc<0.1 then return end
        acc=0
        local wantGuard,wantSteal=State["play.guard"]==true,State["play.steal"]==true
        local wantBlock,wantReb=State["play.block"]==true,State["play.rebound"]==true
        local fb=Hub.foulBlocked==true                               
        wantSteal=wantSteal and not fb; wantBlock=wantBlock and not fb
        local wantLane=State["play.lane"]==true and not fb
        if not wantGuard and not wantSteal and not wantBlock and not wantReb and not wantLane then return end
        pcall(function()
            local me=myChar()
            if not me then return end
            local inPlay=not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            if not inPlay or hasBall(me) then
                followTgt=nil
                if dbgWhy~="idle" then dbgWhy="idle"; plog("not defending (inPlay="..tostring(inPlay)..", youHaveBall="..tostring(hasBall(me))..")") end
                setGuard(false); return
            end
            local act=tostring(me:GetAttribute("Action") or "")
            if wantGuard then
                local grange=tonumber(State["play.guardRange"]) or 12
                if Hub.RefreshCourt then Hub.RefreshCourt() end
                local bh,bhd=nearestHandler(me,math.huge)         
                local mh=me:FindFirstChild("HumanoidRootPart")
                local ourBall=false                                
                for _,c in ipairs(nearList) do
                    if c~=me and not opponent(me,c) and hasBall(c) then ourBall=true; break end
                end
                local man,bhDef
                local unsure=os.clock()-(Hub._teamUnknownAt or -99)<2        
                if not ourBall and not unsure then man,bhDef=matchup(me,bh) end
                if not man and not ourBall and not unsure then
                    
                    local mhp=mh and mh.Position
                    local bestU,bdU=nil,math.huge
                    for _,c in ipairs(nearList) do
                        local oh=c:FindFirstChild("HumanoidRootPart")
                        if mhp and c~=me and oh and opponent(me,c) then
                            local covered=false
                            for _,t in ipairs(nearList) do
                                local th=t:FindFirstChild("HumanoidRootPart")
                                if t~=me and th and not opponent(me,t) and (Vector3.new(th.Position.X-oh.Position.X,0,th.Position.Z-oh.Position.Z)).Magnitude<8 then covered=true; break end
                            end
                            if not covered then
                                local dd=(Vector3.new(oh.Position.X-mhp.X,0,oh.Position.Z-mhp.Z)).Magnitude
                                if dd<bdU then bestU,bdU=c,dd end
                            end
                        end
                    end
                    man=bestU or bh
                end
                manTgt=man
                local h,hd
                
                
                if bh and bhd<=grange and (man==bh or not bhDef) then h=bh; hd=bhd end
                
                if not h and man and mh then
                    local oh=man:FindFirstChild("HumanoidRootPart")
                    if oh and SHOT_ACTIONS[tostring(man:GetAttribute("Action") or "")] and (oh.Position-mh.Position).Magnitude<=grange then
                        h=man; hd=(oh.Position-mh.Position).Magnitude; guardUntil=os.clock()+0.7
                    end
                end
                if not h and os.clock()<guardUntil and lastGuarded==man then h=lastGuarded end   
                if h then lastGuarded=h end
                setGuard(h~=nil)
                followTgt=nil; followGoal=nil; followBall=nil
                if State["play.follow"]~=false then
                    if h then
                        followTgt=h; followGoal=attackGoal(h); followGap=3.5
                    end
                end
                local why=h and ("guarding "..h.Name) or "no ball handler in range"
                if why~=dbgWhy then
                    dbgWhy=why; plog(why..(hd and string.format(" (%.1f studs) guard=%s",hd,tostring(guarding)) or ""))
                    if not h and os.clock()-(Hub._nearLogAt or 0)>20 then      
                        Hub._nearLogAt=os.clock()
                        local mhrp=me:FindFirstChild("HumanoidRootPart")
                        for _,c in ipairs(nearList) do
                            local oh=c:FindFirstChild("HumanoidRootPart")
                            plog(string.format("   near: %s dist=%s team=%s/%s ballAttr=%s motor=%s action=%s",c.Name,
                                (oh and mhrp) and string.format("%.1f",(oh.Position-mhrp.Position).Magnitude) or "?",
                                tostring(teamOf(me)),tostring(teamOf(c)),tostring(c:GetAttribute("Basketball")),
                                tostring(c:FindFirstChild("Basketball",true)~=nil),tostring(c:GetAttribute("Action"))))
                        end
                        local b=ballPart()
                        plog("   ball part: "..(b and (b:GetFullName().." pos "..tostring(b.Position)) or "none"))
                    end
                end
            end
            if wantBlock and act~="Shooting" and act~="Dunking" and act~="Blocking" and os.clock()-lastBlock>1.2 then
                local rng=tonumber(State["play.blockRange"]) or 14
                nearestHandler(me,0.001)                      
                local mh=me:FindFirstChild("HumanoidRootPart")
                for _,c in ipairs(nearList) do
                    local oh=c:FindFirstChild("HumanoidRootPart")
                    local ca=tostring(c:GetAttribute("Action") or "")
                    if mh and oh and SHOT_ACTIONS[ca] and opponent(me,c) and (oh.Position-mh.Position).Magnitude<=rng then
                        lastBlock=os.clock()
                        local delay=(tonumber(State["play.blockDelay"]) or 120)/1000+(ca=="Dunking" and 0.2 or 0)+humanDelay()
                        plog(string.format("block: %s is %s (%.1f studs), jumping in %.0f ms",c.Name,ca,(oh.Position-mh.Position).Magnitude,delay*1000))
                        task.delay(delay,function() if Hub.alive and State["play.block"]==true then fire("InputService","Jump") end end)
                        break
                    end
                end
            end
            if wantReb and act~="Shooting" and act~="Dunking" and os.clock()-lastReb>1.0 then
                local b=ballPart()
                local mh=me:FindFirstChild("HumanoidRootPart")
                if b and mh and (b.Position-mh.Position).Magnitude<=(tonumber(State["play.reboundRange"]) or 12)
                    and b.Position.Y>mh.Position.Y+2 and b.AssemblyLinearVelocity.Magnitude>1 then
                    local held=false
                    nearestHandler(me,0.001)
                    for _,c in ipairs(nearList) do if hasBall(c) and c:GetAttribute("Basketball") then held=true; break end end
                    if not held then
                        lastReb=os.clock()
                        plog("rebound: loose ball in the air, jumping")
                        task.delay(humanDelay(),function() if Hub.alive and State["play.rebound"]==true then fire("InputService","Jump") end end)
                    end
                end
            end
            if wantLane and act~="Shooting" and act~="Dunking" and os.clock()-lastSteal>(tonumber(State["play.stealCd"]) or 2) then
                nearestHandler(me,0.001)
                local mh=me:FindFirstChild("HumanoidRootPart")
                for _,c in ipairs(nearList) do
                    local oh=c:FindFirstChild("HumanoidRootPart")
                    if mh and oh and opponent(me,c) and tostring(c:GetAttribute("Action") or "")=="CatchingPass"
                        and (oh.Position-mh.Position).Magnitude<=(tonumber(State["play.stealRange"]) or 5)*1.5 then
                        lastSteal=os.clock()
                        plog("lane steal: "..c.Name.." is catching a pass")
                        task.delay(humanDelay(),function() if Hub.alive and State["play.lane"]==true then fire("InputService","Steal") end end)
                        break
                    end
                end
            end
            if wantSteal and act~="Shooting" and act~="Dunking" then
                local h=nearestHandler(me,tonumber(State["play.stealRange"]) or 5)
                local now=os.clock()
                if h and tostring(h:GetAttribute("Action") or "")~="Shooting"
                    and now-lastSteal>(tonumber(State["play.stealCd"]) or 2)+math.random()*0.3 then
                    lastSteal=now
                    local hn=h.Name
                    task.delay(humanDelay(),function()
                        if Hub.alive and State["play.steal"]==true and fire("InputService","Steal") then
                            Hub:Notify("Auto steal: reached for "..hn,"info")
                        end
                    end)
                end
            end
        end)
    end))

    
    local sprintOn,sacc=false,0
    local function setSprint(on)
        if sprintOn==on then return end
        if fire("InputService","Sprint",on) then sprintOn=on end
    end
    Hub.Changed:Connect(function(id)
        if id=="play.sprint" and State[id]~=true then pcall(setSprint,false) end
    end)
    track({Disconnect=function() if sprintOn then pcall(setSprint,false) end end})
    track(RunService.Heartbeat:Connect(function(dt)
        sacc=sacc+dt
        if sacc<0.15 then return end
        sacc=0
        if State["play.sprint"]~=true then return end
        pcall(function()
            local me=myChar()
            local hum=me and me:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local inPlay=not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            local act=tostring(me:GetAttribute("Action") or "")
            local moving=hum.MoveDirection.Magnitude>0.1
            local ok=inPlay and moving and not hasBall(me) and act=="" and me:GetAttribute("HoldingG")~=true
                and (State["play.guard"]~=true or Hub._followFar==true)       
                and not (State["safe.stamina"]==true and (tonumber(me:GetAttribute("Stamina")) or 100)<(tonumber(State["safe.staminaMin"]) or 20))
            if ok and not sprintOn and me:GetAttribute("Sprinting")~=true then setSprint(true)
            elseif not ok and sprintOn then setSprint(false) end
        end)
    end))

    
    local origFov=nil
    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_fov") end)
    RunService:BindToRenderStep("TRAPPED_fov",Enum.RenderPriority.Last.Value,function()
        local cam=workspace.CurrentCamera
        if not cam then return end
        if State["play.fovOn"]==true then
            if not origFov then origFov=cam.FieldOfView end
            local f=tonumber(State["play.fov"]) or 70
            if cam.FieldOfView~=f then cam.FieldOfView=f end
        elseif origFov then
            cam.FieldOfView=origFov; origFov=nil
        end
    end)
    track({Disconnect=function()
        pcall(function() RunService:UnbindFromRenderStep("TRAPPED_fov") end)
        pcall(function() if origFov and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=origFov end end)
    end})

    
    local function callSvc(name,...)
        local args={...}
        local ok,res,res2=pcall(function()
            local fw=Hub.Framework and Hub.Framework()
            local svc=fw and fw.Services and fw.Services.DailyTaskService
            if svc and type(svc[name])=="function" then return svc[name](svc,table.unpack(args)) end
            local r=game:GetService("ReplicatedStorage").Aero.AeroRemoteServices.DailyTaskService[name]
            return r:InvokeServer(table.unpack(args))
        end)
        if ok then return res,res2 end
        return nil
    end
    task.spawn(function()
        task.wait(8)
        while Hub.alive do
            if State["play.claim"]==true then
                pcall(function()
                    local data=callSvc("GetTasks")
                    local list=type(data)=="table" and data.Tasks
                    if type(list)~="table" then plog("daily tasks: no task list returned"); return end
                    local got=0
                    for _,t in ipairs(list) do
                        if type(t)=="table" and t.Completed and not t.Claimed and t.Index~=nil then
                            local okc=callSvc("ClaimTask",t.Index)
                            plog("daily task "..tostring(t.Index).." claim -> "..tostring(okc))
                            if okc then got=got+1 end
                            task.wait(1.2)
                        end
                    end
                    if got>0 then Hub:Notify("Claimed "..got.." daily task"..(got>1 and "s" or ""),"success") end
                end)
            end
            local waited=0
            while Hub.alive and waited<60 do task.wait(2); waited=waited+2 end
        end
    end)

    
    
    local goalCache,goalAt,circleCache,circleAt={}, 0, {}, 0
    local scanning=false
    local function refreshCourt()
        local now=os.clock()
        local have=#goalCache>0 and goalCache[1].Parent~=nil
        if scanning or now-goalAt<(have and 60 or 5) then return end
        goalAt=now; scanning=true
        
        task.spawn(function()
            local g,c,n={}, {}, 0
            pcall(function()
                for _,d in ipairs(workspace:GetDescendants()) do
                    n=n+1
                    if n%1500==0 then task.wait() end
                    if d:IsA("BasePart") then
                        if d.Name=="Goal" then g[#g+1]=d
                        elseif d.Name=="FreeThrowCricle_L" or d.Name=="FreeThrowCircle_L" then c[#c+1]=d end
                    end
                end
            end)
            if #g>0 or #goalCache==0 then goalCache,circleCache=g,c end
            Hub._goals=goalCache
            scanning=false
        end)
    end
    Hub.RefreshCourt=refreshCourt
    local function nearestOf(list,pos)
        local best,bd=nil,math.huge
        for _,g in ipairs(list) do
            if g.Parent then
                local d=Vector3.new(g.Position.X-pos.X,0,g.Position.Z-pos.Z).Magnitude
                if d<bd then best,bd=g,d end
            end
        end
        return best,bd
    end
    local lastAuto,standSince,warnedAG=0,nil,false
    local lastDriveSt,lastPostSt=nil,nil
    local function pressShoot(why)
        if State["shoot.perfect"]~=true then
            if not warnedAG then warnedAG=true; Hub:Notify("Turn Auto Time on first: it releases the automatic shots","warn") end
            return false
        end
        local kc=Enum.KeyCode[tostring(State["shoot.key"] or "E")]
        if not kc then return false end
        lastAuto=os.clock()
        plog("offense: shooting ("..why..")")
        return (pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true,kc,false,game) end))
    end
    
    
    
    
    local drive={on=false,dir=nil,startAt=0,pauseUntil=0,nextPause=0,gotBallAt=nil}
    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_drive") end)
    RunService:BindToRenderStep("TRAPPED_drive",Enum.RenderPriority.Last.Value,function()
        if not drive.on or not drive.dir or State["play.drive"]~=true then return end
        local now=os.clock()
        if now<drive.startAt or now<drive.pauseUntil then return end
        if Steer.realMag>0.1 then return end                        
        local t=now
        local a=math.sin(t*1.7)*0.12+math.sin(t*0.63+1.3)*0.08          
        local c,sn=math.cos(a),math.sin(a)
        local d=drive.dir
        Steer.set(Vector3.new(d.X*c-d.Z*sn,0,d.X*sn+d.Z*c))
    end)
    track({Disconnect=function() drive.on=false; pcall(function() RunService:UnbindFromRenderStep("TRAPPED_drive") end) end})
    
    
    local brain={heldSince=nil,prev=nil,prevAt=0,acc=0}
    local function brainAllows(a)
        if State["play.brain"]==false then return true end
        local pl=Hub._plan
        if not pl or os.clock()-pl.at>1.2 then return true end          
        return pl.name==a
    end
    local function segDist(p,a,b)                                       
        local ab=Vector3.new(b.X-a.X,0,b.Z-a.Z)
        local l2=ab.X*ab.X+ab.Z*ab.Z
        if l2<1e-6 then return (Vector3.new(p.X-a.X,0,p.Z-a.Z)).Magnitude end
        local t=math.clamp(((p.X-a.X)*ab.X+(p.Z-a.Z)*ab.Z)/l2,0,1)
        return (Vector3.new(p.X-(a.X+ab.X*t),0,p.Z-(a.Z+ab.Z*t))).Magnitude
    end
    local resetDir,resetUntil=nil,0
    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_reset") end)
    RunService:BindToRenderStep("TRAPPED_reset",Enum.RenderPriority.Last.Value,function()
        if not resetDir or os.clock()>resetUntil or Steer.realMag>0.1 then return end
        Steer.set(resetDir)
    end)
    track({Disconnect=function() resetDir=nil; pcall(function() RunService:UnbindFromRenderStep("TRAPPED_reset") end) end})
    track(RunService.Heartbeat:Connect(function(dt)
        brain.acc=brain.acc+dt
        if brain.acc<0.2 then return end
        brain.acc=0
        if State["play.brain"]==false then Hub._plan=nil; return end
        local wShoot,wDrive,wPass,wPost=State["play.autoShoot"]==true,State["play.drive"]==true,State["play.autoPass"]==true,State["play.autoPost"]==true
        if not (wShoot or wDrive or wPass or wPost) then Hub._plan=nil; return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            local inPlay=me and not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            if not (mine and inPlay and hasBall(me)) then brain.heldSince=nil; Hub._plan=nil; return end
            local now=os.clock()
            brain.heldSince=brain.heldSince or now
            local held=now-brain.heldSince
            refreshCourt()
            nearestHandler(me,0.001)
            local gp=attackGoal(me)
            if not gp then return end
            local mp=mine.Position
            local tg=Vector3.new(gp.X-mp.X,0,gp.Z-mp.Z)
            local gd=tg.Magnitude
            local tgu=gd>0.1 and tg.Unit or Vector3.new(0,0,1)
            local range=tonumber(State["play.shotRange"]) or 26
            local openReq=tonumber(State["play.openDist"]) or 7
            local postRange=tonumber(State["play.postRange"]) or 12
            
            local rawNear,effNear,nOn,laneBlocked=math.huge,math.huge,0,false
            local away=Vector3.new(0,0,0)
            local opps,mates={}, {}
            for _,c in ipairs(nearList) do
                local oh=c:FindFirstChild("HumanoidRootPart")
                if c~=me and oh then
                    if opponent(me,c) then
                        opps[#opps+1]=oh.Position
                        local off=Vector3.new(oh.Position.X-mp.X,0,oh.Position.Z-mp.Z)
                        local dist=off.Magnitude
                        rawNear=math.min(rawNear,dist)
                        local ahead=dist>0.1 and off.Unit:Dot(tgu) or 1
                        local eff=dist*(1.35-0.35*ahead)
                        local ca=tostring(c:GetAttribute("Action") or "")
                        if ca=="Blocking" or ca=="Jumping" then eff=eff*0.6 end
                        effNear=math.min(effNear,eff)
                        if dist<=6.5 then nOn=nOn+1 end
                        if dist<9 and dist>0.1 then away=away-off.Unit*(1-dist/9) end
                        if ahead>0.2 and segDist(oh.Position,mp,gp)<4.5 then laneBlocked=true end
                    else
                        mates[#mates+1]={c=c,p=oh.Position}
                    end
                end
            end
            local function minOpp(pos)
                local b=math.huge
                for _,q in ipairs(opps) do b=math.min(b,(Vector3.new(q.X-pos.X,0,q.Z-pos.Z)).Magnitude) end
                return b
            end
            
            local sclock=0
            pcall(function()
                if not (brain.clk and brain.clk.Parent) and now-(brain.clkAt or -99)>10 then
                    brain.clkAt=now; brain.clk=nil
                    local courts=workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Courts")
                    for _,d in ipairs(courts and courts:GetDescendants() or {}) do
                        if d:IsA("Configuration") and d:GetAttribute("Shotclock")~=nil then brain.clk=d; break end
                    end
                end
                sclock=tonumber(brain.clk and brain.clk:GetAttribute("Shotclock")) or 0
            end)
            local sc={shoot=0,drive=0,pass=0,post=0,reset=0,hold=0.2}
            if wShoot and gd<=range*1.05 then
                local need=openReq*math.clamp(gd/range,0.7,1)
                if held>5 then need=need*0.85 end
                local open=math.clamp((effNear-need*0.6)/(need*0.8),0,1.2)
                local rangeF=gd<=range*0.75 and 1 or math.max(0.3,1-(gd-range*0.75)/(range*0.3)*0.7)
                if rawNear<math.max(4.5,openReq*0.6) then open=0 end          
                if gd<range*0.35 and laneBlocked then open=open*0.5 end        
                sc.shoot=open*rangeF+((open>0.2) and math.min(held/8,0.25) or 0)
                if State["scout.useModel"]==true and Hub.PredictContest and effNear<math.huge then   
                    local pc=Hub.PredictContest(effNear)
                    if pc and pc>(tonumber(State["scout.maxC"]) or 25) then sc.shoot=sc.shoot*0.4 end
                end
            end
            if wDrive and gd>range*0.3 then
                local v=laneBlocked and 0.1 or (gd>range*0.5 and 0.6 or 0.45)
                if nOn>=2 then v=v*0.3 end
                if effNear<math.huge and effNear>openReq*1.6 then v=v+0.1 end
                sc.drive=v
            end
            local bestMate,bestM
            if wPass then
                for _,m in ipairs(mates) do
                    local dist=(Vector3.new(m.p.X-mp.X,0,m.p.Z-mp.Z)).Magnitude
                    local open=minOpp(m.p)
                    if dist>=6 and dist<=45 and open>=6 then
                        local lane=true
                        for _,q in ipairs(opps) do if segDist(q,mp,m.p)<3.5 then lane=false; break end end
                        local v=math.clamp(open/8,0,1.2)-(lane and 0 or 0.5)
                        if v>(bestM or 0) then bestMate,bestM=m.c,v end
                    end
                end
                if bestM and bestM>0.3 then
                    local pressure=(rawNear<5.5 and 0.3 or 0)+(nOn>=2 and 0.3 or 0)
                    sc.pass=bestM*0.5+pressure
                end
            end
            if wPost and gd<=postRange and rawNear<=6 and nOn<2 then sc.post=0.7 end
            if (wShoot or wDrive) and nOn>=2 and sc.pass<0.4 then sc.reset=0.6
            elseif rawNear<3 and sc.shoot<0.3 then sc.reset=0.35 end
            for k,v in pairs(sc) do sc[k]=v+(math.random()-0.5)*0.16 end    
            local pick,ps="hold",-1
            for k,v in pairs(sc) do if v>ps then pick,ps=k,v end end
            if pick=="hold" and held>1.2 then pick=wDrive and "drive" or "reset" end      
            
            if (held>6.5 or (sclock>0 and sclock<=3)) and (pick=="hold" or pick=="reset") then
                if sc.pass>0.3 then pick="pass"
                elseif wShoot and gd<=range*1.1 and rawNear>=4.5 then pick="shoot"
                elseif wDrive then pick="drive" end
            end
            
            local pv=brain.prev
            if pv and now-brain.prevAt<0.7 and sc[pv]~=nil and ps<sc[pv]+0.25 then pick=pv end
            if pick~=pv then brain.prev=pick; brain.prevAt=now end
            Hub._plan={name=pick,at=now,mate=bestMate and bestMate.Name or nil}
            if pick=="reset" then
                local d=(away.Magnitude>0.05) and away.Unit or -tgu
                resetDir=Vector3.new(d.X,0,d.Z).Unit; resetUntil=now+0.8
            end
            if pick~=brain.last then
                brain.last=pick
                plog(string.format("brain: %s (shoot %.2f drive %.2f pass %.2f post %.2f reset %.2f) hoop %.1f near %.1f on-me %d",
                    pick,sc.shoot,sc.drive,sc.pass,sc.post,sc.reset,gd,rawNear==math.huge and -1 or rawNear,nOn))
            end
        end)
    end))

    local oacc=0
    track(RunService.Heartbeat:Connect(function(dt)
        oacc=oacc+dt
        if oacc<0.2 then return end
        oacc=0
        local wShoot,wDrive,wFT=State["play.autoShoot"]==true,State["play.drive"]==true,State["play.autoFT"]==true
        if not (wShoot or wDrive or wFT) then drive.on=false; standSince=nil; drive.gotBallAt=nil; return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            local inPlay=me and not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            if not (mine and inPlay and hasBall(me)) then drive.on=false; standSince=nil; drive.gotBallAt=nil; return end
            local now=os.clock()
            if not drive.gotBallAt then
                drive.gotBallAt=now
                drive.startAt=now+0.35+math.random()*0.35                
                drive.nextPause=now+1.5+math.random()*2
            end
            local held=now-drive.gotBallAt
            local act=tostring(me:GetAttribute("Action") or "")
            if act~="" and act~="Dribbling" then drive.on=false; return end      
            refreshCourt()
            
            if wFT then
                local c,cd=nearestOf(circleCache,mine.Position)
                if c and cd<=4 and mine.AssemblyLinearVelocity.Magnitude<1 then
                    standSince=standSince or now
                    if now-standSince>1.2 and now-lastAuto>4 then
                        standSince=nil
                        pressShoot("free throw")
                        return
                    end
                else standSince=nil end
            end
            local goal,gd
            do                                                    
                local gpos=attackGoal(me)
                if gpos then goal={Position=gpos,Parent=true}; gd=(Vector3.new(gpos.X-mine.Position.X,0,gpos.Z-mine.Position.Z)).Magnitude
                else goal,gd=nearestOf(goalCache,mine.Position) end
            end
            if not goal then drive.on=false; return end
            local range=tonumber(State["play.shotRange"]) or 26
            nearestHandler(me,0.001)                                  
            local nearest,avoid=math.huge,Vector3.new(0,0,0)
            local rawNear,effNear=math.huge,math.huge
            local tg=Vector3.new(goal.Position.X-mine.Position.X,0,goal.Position.Z-mine.Position.Z)
            local tgu=tg.Magnitude>0.1 and tg.Unit or Vector3.new(0,0,1)
            for _,c in ipairs(nearList) do
                local oh=c:FindFirstChild("HumanoidRootPart")
                if oh and opponent(me,c) then
                    local off=Vector3.new(mine.Position.X-oh.Position.X,0,mine.Position.Z-oh.Position.Z)
                    local dist=off.Magnitude
                    nearest=math.min(nearest,dist)
                    if dist<9 and dist>0.1 then avoid=avoid+off.Unit*(1-dist/9)*1.3 end   
                    
                    rawNear=math.min(rawNear,dist)
                    local ahead=dist>0.1 and (-off.Unit):Dot(tgu) or 1
                    local eff=dist*(1.35-0.35*ahead)
                    local ca=tostring(c:GetAttribute("Action") or "")
                    if ca=="Blocking" or ca=="Jumping" then eff=eff*0.6 end   
                    effNear=math.min(effNear,eff)
                end
            end
            local openReq=tonumber(State["play.openDist"]) or 7
            
            local need=openReq*math.clamp(gd/range,0.7,1)
            if held>5 then need=need*0.85 end
            local isOpen=effNear>=need
            if State["scout.useModel"]==true and Hub.PredictContest and effNear<math.huge then
                local pc=Hub.PredictContest(effNear)
                if pc then isOpen=isOpen and pc<=(tonumber(State["scout.maxC"]) or 25) end
            end
            if rawNear<math.max(4.5,openReq*0.6) then isOpen=false end      

            
            
            if wDrive then
                local spotDist=range*0.75
                local want=(gd>spotDist+1 or (wShoot and not isOpen and gd>9)) and brainAllows("drive")
                local toGoal=Vector3.new(goal.Position.X-mine.Position.X,0,goal.Position.Z-mine.Position.Z)
                if want and toGoal.Magnitude>0.5 then
                    local dir=toGoal.Unit+avoid
                    drive.dir=dir.Magnitude>0.01 and dir.Unit or toGoal.Unit
                    drive.on=true
                    if now>=drive.nextPause and nearest>6 then              
                        drive.pauseUntil=now+0.12+math.random()*0.2
                        drive.nextPause=now+1.8+math.random()*2.6
                    end
                else
                    drive.on=false
                end
                local st=drive.on and "driving" or "stopped"
                if st~=lastDriveSt then lastDriveSt=st; plog(string.format("drive: %s (%.1f studs from the hoop, nearest defender %s, steering hook %s)",st,gd,nearest==math.huge and "none" or string.format("%.1f",nearest),Steer.ok and "ok" or "MISSING")) end
            else
                drive.on=false
            end

            if wShoot and gd<=range and held>=0.6 and now-lastAuto>1.6 and isOpen and brainAllows("shoot") then
                lastAuto=now
                local why=string.format("open: %.1f studs from the hoop, nearest defender %s (needed %.1f)",gd,nearest==math.huge and "none" or string.format("%.1f",nearest),need)
                task.delay(0.1+math.random()*0.3,function()
                    if Hub.alive and State["play.autoShoot"]==true then
                        local m=myChar()
                        if m and hasBall(m) and tostring(m:GetAttribute("Action") or "")~="Shooting" then
                            drive.on=false
                            pressShoot(why)
                        end
                    end
                end)
            end
        end)
    end))

    
    
    
    local sp={inSince=nil,spot=nil,on=false,untilT=0}
    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_space") end)
    RunService:BindToRenderStep("TRAPPED_space",Enum.RenderPriority.Last.Value,function()
        if not sp.on or not sp.spot or os.clock()>sp.untilT or State["play.space"]==false then return end
        if Steer.realMag>0.1 then return end
        local me=myChar()
        local mine=me and me:FindFirstChild("HumanoidRootPart")
        if not mine then return end
        local d=Vector3.new(sp.spot.X-mine.Position.X,0,sp.spot.Z-mine.Position.Z)
        sp.arrived=d.Magnitude<=2
        if d.Magnitude>2 then Steer.set(d.Unit) end
    end)
    track({Disconnect=function() sp.on=false; pcall(function() RunService:UnbindFromRenderStep("TRAPPED_space") end) end})
    local spAcc=0
    track(RunService.Heartbeat:Connect(function(dt)
        spAcc=spAcc+dt
        if spAcc<0.25 then return end
        spAcc=0
        if State["play.space"]==false then sp.on=false; return end
        local wantOff=State["play.autoShoot"]==true or State["play.drive"]==true or State["play.autoPass"]==true
        local wantDef=State["play.guard"]==true
        if not (wantOff or wantDef) then sp.on=false; sp.inSince=nil; return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            local inPlay=me and not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            if not (mine and inPlay) or hasBall(me) then sp.on=false; sp.inSince=nil; return end
            nearestHandler(me,0.001)                                   
            local mate,opp
            for _,c in ipairs(nearList) do
                if c~=me and hasBall(c) then
                    if opponent(me,c) then opp=c else mate=c end
                end
            end
            if os.clock()-(Hub._teamUnknownAt or -99)<2 then sp.on=false; return end
            local carrier=(mate and wantOff and mate) or (opp and wantDef and opp) or nil
            if not carrier then sp.on=false; sp.inSince=nil; return end
            refreshCourt()
            local gp=attackGoal(carrier)
            if not gp then return end
            local circ,cd=nil,math.huge
            for _,c in ipairs(circleCache) do
                if c.Parent then
                    local dd=Vector3.new(c.Position.X-gp.X,0,c.Position.Z-gp.Z).Magnitude
                    if dd<cd then circ,cd=c,dd end
                end
            end
            if not circ or cd<3 then return end
            local L=cd
            local u=Vector3.new(circ.Position.X-gp.X,0,circ.Position.Z-gp.Z).Unit
            local v=Vector3.new(-u.Z,0,u.X)
            local rel=Vector3.new(mine.Position.X-gp.X,0,mine.Position.Z-gp.Z)
            local a,l=rel:Dot(u),rel:Dot(v)
            
            local inPaint=a<=L*0.85 and a>=-L*0.4 and math.abs(l)<=L*0.7
            local now=os.clock()
            if carrier==mate and State["play.getOpen"]==true then
                
                local cp=carrier:FindFirstChild("HumanoidRootPart")
                if cp and (not sp.nextPick or now>=sp.nextPick) then
                    local cands={}
                    for _,side in ipairs({-1,1}) do
                        cands[#cands+1]=gp+u*(L*0.1)+v*(side*L*1.15)          
                        cands[#cands+1]=gp+u*(L*0.95)+v*(side*L*1.1)          
                        cands[#cands+1]=gp+u*(L*0.5)+v*(side*L*0.95)          
                        cands[#cands+1]=gp+u*(L*1.25)+v*(side*L*0.55)         
                    end
                    cands[#cands+1]=gp+u*(L*1.45)                            
                    local bestS,bestP=-math.huge,nil
                    for _,cand in ipairs(cands) do
                        local oppD=math.huge
                        for _,c in ipairs(nearList) do
                            local oh=c:FindFirstChild("HumanoidRootPart")
                            if c~=me and oh and opponent(me,c) then
                                oppD=math.min(oppD,(Vector3.new(oh.Position.X-cand.X,0,oh.Position.Z-cand.Z)).Magnitude)
                            end
                        end
                        local sc2=math.min(oppD,12)
                        for _,c in ipairs(nearList) do                         
                            local oh=c:FindFirstChild("HumanoidRootPart")
                            if c~=me and c~=carrier and oh and not opponent(me,c) then
                                local dm=(Vector3.new(oh.Position.X-cand.X,0,oh.Position.Z-cand.Z)).Magnitude
                                if dm<9 then sc2=sc2-(9-dm)*0.8 end
                            end
                        end
                        for _,c in ipairs(nearList) do                         
                            local oh=c:FindFirstChild("HumanoidRootPart")
                            if c~=me and oh and opponent(me,c) and segDist(oh.Position,cand,cp.Position)<3.5 then sc2=sc2-3; break end
                        end
                        local dCar=(Vector3.new(cp.Position.X-cand.X,0,cp.Position.Z-cand.Z)).Magnitude
                        if dCar<8 then sc2=sc2-2 end
                        sc2=sc2-0.04*(Vector3.new(cand.X-mine.Position.X,0,cand.Z-mine.Position.Z)).Magnitude+(math.random()-0.5)*1.2
                        if sp.spot and (Vector3.new(cand.X-sp.spot.X,0,cand.Z-sp.spot.Z)).Magnitude<4 and not sp.arrived then sc2=sc2+0.8 end   
                        if sc2>bestS then bestS,bestP=sc2,cand end
                    end
                    if bestP then
                        sp.spot=bestP; sp.on=true; sp.untilT=now+4; sp.inSince=nil
                        sp.nextPick=now+1.2+math.random()*1.4
                    end
                end
                return
            end
            if not inPaint then sp.inSince=nil; return end
            sp.inSince=sp.inSince or now
            if now-sp.inSince<2.2 then return end
            local spot
            if carrier==mate then
                
                local best,bs=nil,math.huge
                for _,side in ipairs({-1,1}) do
                    local cand=gp+u*(L*0.1)+v*(side*L*1.15)           
                    local taken=false
                    for _,c in ipairs(nearList) do
                        local oh=c:FindFirstChild("HumanoidRootPart")
                        if c~=me and oh and not opponent(me,c) and (Vector3.new(oh.Position.X-cand.X,0,oh.Position.Z-cand.Z)).Magnitude<L*0.45 then taken=true end
                    end
                    local dd=(Vector3.new(cand.X-mine.Position.X,0,cand.Z-mine.Position.Z)).Magnitude+(taken and 1000 or 0)
                    if dd<bs then best,bs=cand,dd end
                end
                spot=best
                if bs>=1000 then                                      
                    local side=(l>=0) and 1 or -1
                    spot=gp+u*(L*1.5)+v*(side*L*0.95)
                end
            elseif not manTgt then
                
                local best,bd=nil,math.huge
                for _,c in ipairs(nearList) do
                    local oh=c:FindFirstChild("HumanoidRootPart")
                    if c~=me and oh and opponent(me,c) then
                        local covered=false
                        for _,t in ipairs(nearList) do
                            local th=t:FindFirstChild("HumanoidRootPart")
                            if t~=me and th and not opponent(me,t) and (Vector3.new(th.Position.X-oh.Position.X,0,th.Position.Z-oh.Position.Z)).Magnitude<7 then covered=true; break end
                        end
                        if not covered then
                            local dd=(Vector3.new(oh.Position.X-mine.Position.X,0,oh.Position.Z-mine.Position.Z)).Magnitude
                            if dd<bd then best,bd=oh,dd end
                        end
                    end
                end
                if best then
                    local toG=Vector3.new(gp.X-best.Position.X,0,gp.Z-best.Position.Z)
                    spot=best.Position+(toG.Magnitude>0.1 and toG.Unit or u)*4
                end
            end
            if spot then sp.spot=spot; sp.on=true; sp.untilT=now+4; sp.inSince=nil end
        end)
    end))

    
    
    local lastPass,posting,pacc=0,false,0
    local function setPost(on)
        if posting==on then return end
        if fire("InputService","HoldG",{HoldingG=on}) then posting=on end
    end
    Hub.Changed:Connect(function(id)
        if id=="play.autoPost" and State[id]~=true then pcall(setPost,false) end
    end)
    track({Disconnect=function() if posting then pcall(setPost,false) end end})
    track(RunService.Heartbeat:Connect(function(dt)
        pacc=pacc+dt
        if pacc<0.2 then return end
        pacc=0
        local wPass,wPost=State["play.autoPass"]==true,State["play.autoPost"]==true
        if not wPass and not wPost then return end
        pcall(function()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            local inPlay=me and not (me:GetAttribute("InGame")==false and me:GetAttribute("OnCourt")==false)
            if not (mine and inPlay and hasBall(me)) then setPost(false); return end
            local act=tostring(me:GetAttribute("Action") or "")
            if act~="" and act~="Dribbling" then setPost(false); return end
            refreshCourt()
            nearestHandler(me,0.001)                               
            local function defenderDist(pos)
                local best=math.huge
                for _,c in ipairs(nearList) do
                    local oh=c:FindFirstChild("HumanoidRootPart")
                    if oh and opponent(me,c) then best=math.min(best,(oh.Position-pos).Magnitude) end
                end
                return best
            end
            local goal,gd
            do                                                    
                local gpos=attackGoal(me)
                if gpos then goal={Position=gpos,Parent=true}; gd=(Vector3.new(gpos.X-mine.Position.X,0,gpos.Z-mine.Position.Z)).Magnitude
                else goal,gd=nearestOf(goalCache,mine.Position) end
            end
            local onMe=defenderDist(mine.Position)
            if wPost then
                local want=goal~=nil and gd<=(tonumber(State["play.postRange"]) or 12) and onMe<=6 and brainAllows("post")
                setPost(want)
                local st=string.format("%s | hoop %s studs, defender %s studs, posting=%s",want and "want post" or "no post",
                    gd and string.format("%.1f",gd) or "none",onMe==math.huge and "none" or string.format("%.1f",onMe),tostring(posting))
                if st~=lastPostSt then lastPostSt=st; plog("post: "..st) end
            end
            if wPass and not posting and os.clock()-lastPass>2.5 and os.clock()-lastAuto>2 then
                if (State["play.brain"]~=false and brainAllows("pass")) or (State["play.brain"]==false and onMe<=(tonumber(State["play.passTrigger"]) or 4)) then
                    local bestC,bestScore,bestOpen
                    for _,c in ipairs(nearList) do
                        local oh=c:FindFirstChild("HumanoidRootPart")
                        if oh and not opponent(me,c) then
                            local dist=(oh.Position-mine.Position).Magnitude
                            local open=defenderDist(oh.Position)
                            if dist>=6 and dist<=45 and open>=6 and open>=onMe+3 then
                                local score=open-0.15*(goal and Vector3.new(goal.Position.X-oh.Position.X,0,goal.Position.Z-oh.Position.Z).Magnitude or 0)
                                if not bestScore or score>bestScore then bestC,bestScore,bestOpen=c,score,open end
                            end
                        end
                    end
                    if bestC then
                        lastPass=os.clock()
                        local nm=bestC.Name
                        task.delay(humanDelay(),function()
                            if not Hub.alive or State["play.autoPass"]~=true then return end
                            local m=myChar()
                            if m and hasBall(m) and tostring(m:GetAttribute("Action") or "")~="Passing" then
                                plog(string.format("pass: defender %.1f studs on you, %s is open (%.1f studs)",onMe,nm,bestOpen))
                                fire("InputService","Pass",{PassType=1,Player=nm})
                            end
                        end)
                    end
                end
            end
        end)
    end))

    
    local H={fire=fire,plog=plog,hasBall=hasBall,opponent=opponent,teamOf=teamOf,nearestHandler=nearestHandler,
        ballPart=ballPart,Steer=Steer,refreshCourt=refreshCourt,nearestOf=nearestOf,humanDelay=humanDelay}
    function H.near() return nearList end
    function H.goals() return goalCache end

    
    ;(function()
        local pg=newPage("Player","Player","Safety nets and game-flow helpers.")
        local s=pg:Group("Safety")
        s:Toggle("Ping-spike safe mode","safe.ping",false,"If your ping jumps above the limit, Auto Time skips its release for that shot, so a laggy release is left to you.")
        s:Divider()
        s:Slider("Ping limit","safe.pingMax",80,400,150,0," ms","Skip automatic releases above this ping.")
        s:Divider()
        s:Toggle("Foul guard","safe.foul",false,"Turns off auto steal, lane steal and auto block once you reach the foul limit below.")
        s:Divider()
        s:Slider("Foul limit","safe.foulMax",1,6,4,0," fouls","Stop reaching at this many fouls.")
        s:Divider()
        s:Toggle("Stamina saver","safe.stamina",false,"Auto sprint stops when your stamina falls below the level below.")
        s:Divider()
        s:Slider("Sprint stops at","safe.staminaMin",5,60,20,0,"%","Stamina percent.")
        local f=pg:Group("Game flow")
        f:Toggle("Emote after a make","flow.emote",false,"Plays your chosen emote right after a make (celebration, ball through the hoop, or a good release), then cancels it with a small step. Turn this on first.")
        f:Divider()
        f:Slider("Emote slot","flow.emoteSlot",1,8,1,0,"","Which slot on page 1 of your emote wheel.")

        
        local fcache
        local function myFouls()
            if fcache and fcache.Parent then return fcache:GetAttribute("Fouls") end
            fcache=nil
            if os.clock()-(H.foulScanAt or -99)<20 then return nil end   
            H.foulScanAt=os.clock()
            for _,root in ipairs({game:GetService("ReplicatedStorage"),workspace}) do
                for _,d in ipairs(root:GetDescendants()) do
                    if d.Name==LP.Name and d:IsA("BoolValue") and d:GetAttribute("Fouls")~=nil then
                        fcache=d; return d:GetAttribute("Fouls")
                    end
                end
            end
            return nil
        end
        task.spawn(function()
            while Hub.alive do
                local wait=2
                if State["safe.foul"]==true then
                    local ok,n=pcall(myFouls)
                    if ok and n~=nil then
                        local blocked=n>=(tonumber(State["safe.foulMax"]) or 4)
                        if blocked~=(Hub.foulBlocked==true) then
                            Hub.foulBlocked=blocked
                            Hub:Notify(blocked and ("Foul guard: "..n.." fouls, reaching is off") or "Foul guard: reaching is back on",blocked and "warn" or "info")
                            H.plog("foul guard: fouls="..tostring(n).." blocked="..tostring(blocked))
                        end
                    else
                        wait=8      
                    end
                else
                    Hub.foulBlocked=false
                end
                task.wait(wait)
            end
        end)

        
        
        local lastAct,emoteAt,emoteBusy="",0,false
        local lastPts=nil
        local lastRelSeen=nil
        local animCache
        local function findEmoteAnim(slot)
            if not (animCache and animCache.Parent) then
                animCache=nil
                local f=game:GetService("ReplicatedStorage"):FindFirstChild("Emotes",true)
                animCache=f
            end
            if not animCache then return nil end
            local list={}
            for _,d in ipairs(animCache:GetDescendants()) do if d:IsA("Animation") then list[#list+1]=d end end
            return list[math.clamp(slot,1,math.max(1,#list))]
        end
        local function playEmote(why)
            if emoteBusy or os.clock()-emoteAt<4 then return end
            emoteBusy=true; emoteAt=os.clock()
            H.plog("emote: make detected ("..why..")")
            bootLog("emote: playing ("..why..")")
            task.delay(0.35,function()
                pcall(function()
                    local slot=math.floor(tonumber(State["flow.emoteSlot"]) or 1)
                    local sent=false
                    local fw=Hub.Framework and Hub.Framework()
                    local gui=fw and fw.Controllers and fw.Controllers.Gui
                    local comp=gui and gui.GetComponent and gui:GetComponent("EmoteWheel")
                    local page=comp and comp.Pages and comp.Pages[1]
                    local entry=page and page[slot]
                    local pkg=entry and entry.Package
                    if pkg then
                        sent=H.fire("InputService","Emote",pkg)~=false
                        H.plog("emote: wheel slot "..slot.." sent")
                        bootLog("emote: wheel slot "..slot.." sent")
                    else
                        local keys={}
                        if comp then for k in pairs(comp) do keys[#keys+1]=tostring(k) end end
                        H.plog("emote: wheel data not found (component keys: "..table.concat(keys,",").."), trying the animation list")
                        local an=findEmoteAnim(slot)
                        if an then
                            H.fire("InputService","Emote",an)
                            H.plog("emote: sent animation "..an.Name)
                            bootLog("emote: wheel slot not found, sent animation "..an.Name)
                            sent=true
                        else H.plog("emote: no emote animations found"); bootLog("emote: nothing to play (no wheel slot, no emote animations)") end
                    end
                    if sent then
                        task.wait(0.9)
                        local m=myChar()
                        local hrp=m and m:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local t0=os.clock()
                            while os.clock()-t0<0.25 do H.Steer.set(hrp.CFrame.LookVector); task.wait(0.05) end
                        end
                    end
                end)
                emoteBusy=false
            end)
        end
        
        
        
        
        Hub.OnMakeVerdict=function(idx)
            if idx==5 and State["flow.emote"]==true and not Hub._makeSignalSeen then playEmote("perfect release") end
        end
        local lastMakeAt=0
        local function realMake(why)
            Hub._makeSignalSeen=true
            if os.clock()-lastMakeAt<2 then return end          
            lastMakeAt=os.clock()
            Hub.Makes=(Hub.Makes or 0)+1
            for _,fn in ipairs(Hub._makeFns or {}) do pcall(fn,why) end
            if State["flow.emote"]==true then playEmote(why) end
        end
        track(RunService.Heartbeat:Connect(function()
            local me=myChar()
            local act=me and tostring(me:GetAttribute("Action") or "") or ""
            local was=lastAct; lastAct=act
            
            local pts=tonumber(LP:GetAttribute("Points"))
            if pts then
                if lastPts and pts>lastPts then realMake("points went up") end
                lastPts=pts
            end
            if act=="Celebration" and was~="Celebration" then
                realMake("celebration")
                return
            end
            if State["flow.emote"]~=true then return end
            pcall(function() if Hub.RefreshCourt then Hub.RefreshCourt() end end)
            if Hub._lastRelAt~=lastRelSeen then
                lastRelSeen=Hub._lastRelAt
                bootLog(string.format("emote: shot released, watching the hoop (hoops found: %d, ball found: %s, real makes seen: %s)",
                    #(H.goals() or {}),tostring(H.ballPart()~=nil),tostring(Hub._makeSignalSeen==true)))
            end
            if os.clock()-(Hub._lastRelAt or -99)<3.5 then            
                local b=H.ballPart()
                if b then
                    for _,g in ipairs(H.goals()) do
                        if g.Parent then
                            local d=b.Position-g.Position
                            if math.abs(d.X)<1.8 and math.abs(d.Z)<1.8 and d.Y<0.5 and d.Y>-4.5 and b.AssemblyLinearVelocity.Y<-3 then
                                realMake("ball through hoop"); break
                            end
                        end
                    end
                end
            end
        end))
    end)()

    
    ;(function()
        local pg=Pages.Player
        local VIM=game:GetService("VirtualInputManager")

        
        local PLAY_KEYS={"play.autoShoot","play.autoFT","play.drive","play.autoPost","play.autoPass","play.guard","play.follow",
            "play.steal","play.lane","play.block","play.rebound","play.sprint","play.brain","play.space","play.man"}
        local STYLES={
            {name="Sharpshooter",info="Spots up and shoots open looks. Free throws and passes on, no driving.",
                on={"play.autoShoot","play.autoFT","play.autoPass","play.sprint","play.rebound"},
                set={["play.shotRange"]=30,["play.openDist"]=8,["play.passTrigger"]=4}},
            {name="Slasher",info="Attacks the rim. Drives, posts up and takes shots near the hoop.",
                on={"play.autoShoot","play.autoFT","play.drive","play.autoPost","play.sprint","play.rebound"},
                set={["play.shotRange"]=18,["play.openDist"]=5,["play.postRange"]=14}},
            {name="Lockdown",info="Pure defense. Guards, follows, steals, blocks and rebounds.",
                on={"play.guard","play.follow","play.steal","play.lane","play.block","play.rebound","play.sprint"},
                set={["play.guardRange"]=14,["play.stealRange"]=6,["play.blockRange"]=16}},
            {name="Playmaker",info="Runs the offense. Drives, passes under pressure, picks off passes.",
                on={"play.autoShoot","play.autoFT","play.drive","play.autoPass","play.steal","play.sprint"},
                set={["play.shotRange"]=22,["play.openDist"]=9,["play.passTrigger"]=5}},
            {name="Full auto",info="Everything on, tuned for both ends. Plays the whole game.",
                on=PLAY_KEYS,
                set={["play.shotRange"]=26,["play.openDist"]=7,["play.passTrigger"]=4,["play.guardRange"]=12}},
            {name="All off",info="Turns every Auto Play option off.",on={},set={}},
        }
        local g1=pg:Group("Play style")
        local infoRow=g1:_row(40)
        local infoL=MkLbl({Text="Pick a style. It sets the Auto Play toggles and distances for you.",Font=F.R,TextSize=12,
            TextColor3=C.Sec,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,
            Size=UDim2.fromScale(1,1),Parent=infoRow})
        local gridRow=g1:_row(math.ceil(#STYLES/3)*42)
        local grid=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Parent=gridRow})
        New("UIGridLayout",{CellSize=UDim2.new(1/3,-6,0,34),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder,Parent=grid})
        local btns={}
        local function paintStyles()
            for n,b in pairs(btns) do
                local on=(State["pro.style"]==n)
                P(b.btn,{BackgroundColor3=on and C.White or C.Bg3},0.15)
                P(b.lbl,{TextColor3=on and C.Black or C.Sec},0.15)
            end
        end
        for i,stl in ipairs(STYLES) do
            local btn=MkBtn({BackgroundColor3=C.Bg3,BackgroundTransparency=0,BorderSizePixel=0,LayoutOrder=i,Parent=grid})
            Corner(btn,10)
            local lbl=MkLbl({Text=stl.name,Font=F.B,TextSize=12,TextColor3=C.Sec,TextXAlignment=Enum.TextXAlignment.Center,
                Size=UDim2.fromScale(1,1),ZIndex=3,Parent=btn})
            btns[stl.name]={btn=btn,lbl=lbl}
            btn.MouseEnter:Connect(function() infoL.Text=stl.info end)
            btn.MouseButton1Click:Connect(function() Hub.ApplyStyle(stl.name) end)
        end
        function Hub.ApplyStyle(name)
            for _,stl in ipairs(STYLES) do
                if stl.name==name then
                    local on={}
                    for _,k in ipairs(stl.on) do on[k]=true end
                    for _,k in ipairs(PLAY_KEYS) do Hub:Set(k,on[k]==true) end
                    for k,v in pairs(stl.set) do Hub:Set(k,v) end
                    Hub:Set("pro.style",stl.name)
                    infoL.Text=stl.info
                    paintStyles()
                    Hub:Notify(stl.name.." style on","success")
                    return
                end
            end
        end
        paintStyles()

        
        local t=pg:Group("Takeover manager")
        t:Toggle("Takeover ready alert","pro.tkAlert",true,"Shows a message the moment your takeover meter is full.")
        t:Divider()
        t:Toggle("Auto activate takeover","pro.tkAuto",false,"Presses your takeover key for you when it is full and the moment is good: you are near the hoop with the ball, or a rival is attacking.")
        t:Divider()
        t:Keybind("Takeover key","pro.tkKey","T","The key the game uses to start takeover. Set it to yours.")
        local tkWas,tkAt=false,0
        task.spawn(function()
            while Hub.alive do
                task.wait(0.4)
                pcall(function()
                    local me=myChar()
                    if not me then return end
                    local fill=tonumber(me:GetAttribute("TakeoverFill")) or 0
                    local active=me:GetAttribute("Takeover")==true
                    local ready=(not active) and fill>=100
                    if ready and not tkWas and State["pro.tkAlert"]~=false then Hub:Notify("Takeover is ready","success") end
                    tkWas=ready
                    if ready and State["pro.tkAuto"]==true and os.clock()-tkAt>8 then
                        local good=false
                        local mh=me:FindFirstChild("HumanoidRootPart")
                        if mh then
                            H.refreshCourt()
                            local _,gd=H.nearestOf(H.goals(),mh.Position)
                            if H.hasBall(me) and gd and gd<34 then good=true end
                            if not good then
                                local h,hd=H.nearestHandler(me,22)
                                if h then good=true end
                            end
                        end
                        if good then
                            tkAt=os.clock()
                            local kc=Enum.KeyCode[tostring(State["pro.tkKey"] or "T")]
                            if kc then
                                VIM:SendKeyEvent(true,kc,false,game); task.wait(0.06); VIM:SendKeyEvent(false,kc,false,game)
                                H.plog("takeover: activated with "..tostring(State["pro.tkKey"]).." (fill "..fill..")")
                            end
                        end
                    end
                end)
            end
        end)

        
        local h=pg:Group("Highlight cam")
        h:Toggle("Highlight cam","pro.hl",false,"After a make the camera pushes in with black bars, then eases back. Only you see it.")
        h:Divider()
        h:Slider("Push-in strength","pro.hlAmt",5,35,18,0,"","How many degrees the field of view narrows.")
        local bars
        local function ensureBars()
            if bars and bars[1].Parent then return end
            bars={}
            for i=1,2 do
                bars[i]=New("Frame",{AnchorPoint=Vector2.new(0,i-1),Position=UDim2.new(0,0,i-1,0),Size=UDim2.new(1,0,0,0),
                    BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=50,Parent=gui})
            end
        end
        local hlBusy=false
        local function highlight()
            if hlBusy or State["pro.hl"]~=true then return end
            local cam=workspace.CurrentCamera
            if not cam then return end
            hlBusy=true
            ensureBars()
            local base=cam.FieldOfView
            local amt=tonumber(State["pro.hlAmt"]) or 18
            local t0=os.clock()
            local total=1.6
            for _,b in ipairs(bars) do TweenService:Create(b,TweenInfo.new(0.25),{Size=UDim2.new(1,0,0,70)}):Play() end
            pcall(function() RunService:UnbindFromRenderStep("TRAPPED_hl") end)
            RunService:BindToRenderStep("TRAPPED_hl",Enum.RenderPriority.Last.Value+1,function()
                local x=(os.clock()-t0)/total
                if x>=1 or not Hub.alive then
                    pcall(function() RunService:UnbindFromRenderStep("TRAPPED_hl") end)
                    cam.FieldOfView=base
                    for _,b in ipairs(bars) do TweenService:Create(b,TweenInfo.new(0.3),{Size=UDim2.new(1,0,0,0)}):Play() end
                    hlBusy=false
                    return
                end
                local k=(x<0.25) and (x/0.25) or (1-(x-0.25)/0.75)
                k=k*k*(3-2*k)
                cam.FieldOfView=base-amt*k
            end)
        end
        
        Hub._makeFns=Hub._makeFns or {}
        Hub._makeFns[#Hub._makeFns+1]=function() highlight() end
        Hub.Highlight=highlight
        h:Divider()
        h:Button("Preview",function() local was=State["pro.hl"]; State["pro.hl"]=true; highlight(); State["pro.hl"]=was end)

        
        local s=pg:Group("Stealth")
        s:Toggle("Quiet mode","stealth.quiet",false,"No game notifications from TRAPPED and no log files are written while this is on.")
        s:Divider()
        s:Keybind("Panic key","stealth.panic","Delete","Instantly turns everything off and removes the menu. Does not touch your saved settings.")
        s:Divider()
        s:Toggle("Hide menu when the game is minimised","stealth.autohide",true,"Hides the window if you alt-tab away, so it never shows up in a capture of the game.")
        track(UIS.InputBegan:Connect(function(i,gp)
            if UIS:GetFocusedTextBox() then return end
            local pk=Enum.KeyCode[tostring(State["stealth.panic"] or "Delete")]
            if pk and i.KeyCode==pk then
                pcall(function() Hub:Destroy() end)
            end
        end))
        track(UIS.WindowFocusReleased:Connect(function()
            if State["stealth.autohide"]~=false and root and root.Visible then
                Hub._hidByFocus=true; root.Visible=false
            end
        end))
        track(UIS.WindowFocused:Connect(function()
            if Hub._hidByFocus then Hub._hidByFocus=false; if root then root.Visible=true end end
        end))
    end)()

    
    ;(function()
        local pg=newPage("Session","Session","How your Auto Time shots are landing right now, by shot type and by build.")
        local S
        local function reset() S={m0=Hub.Makes or 0,shots=0,c={0,0,0,0,0,0,0,0},streak=0,best=0,t0=os.clock(),byType={},byBuild={},last=nil} end
        reset()
        local function typeOf(ctx)
            ctx=tostring(ctx or "")
            if ctx:find(":layup",1,true) then return "Layup / dunk" elseif ctx:find(":air",1,true) then return "In the air" end
            return "Ground shot"
        end
        local function buildOf(ctx) return tostring(ctx or ""):match("@([%w]+)") or "unknown" end
        local function bump(t,k,green,perfect)
            local e=t[k]; if not e then e={n=0,g=0,p=0}; t[k]=e end
            e.n=e.n+1; if green then e.g=e.g+1 end; if perfect then e.p=e.p+1 end
        end
        function Hub.SessionShot(idx,ctx,text,ms,ping)
            if type(idx)~="number" or idx<1 or idx>8 then return end
            S.shots=S.shots+1; S.c[idx]=S.c[idx]+1
            local green=idx>=4 and idx<=6
            if green then S.streak=S.streak+1; S.best=math.max(S.best,S.streak) else S.streak=0 end
            bump(S.byType,typeOf(ctx),green,idx==5); bump(S.byBuild,buildOf(ctx),green,idx==5)
            S.last={idx=idx,text=tostring(text or ""),ctx=ctx,ms=ms,ping=ping,t=os.clock()}
        end
        local function pct(a,b) return b>0 and (string.format("%d%%",math.floor(a/b*100+0.5))) or "-" end
        local function curBuild()
            local b=""
            pcall(function()
                local ch=(workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(LP.Name)) or LP.Character
                b=ch and tostring(ch:GetAttribute("BuildName") or "") or ""
            end)
            if b=="" then return nil,nil end
            return "@"..b:gsub("[^%w]",""):sub(1,12),b
        end

        local ups={}
        local function st(g,label,fn) ups[#ups+1]=g:Status(label,fn) end
        local gl=pg:Group("Last shot")
        st(gl,"Result",function()
            local l=S.last
            if not l then return "no auto shot yet",C.Dim end
            return l.text~="" and l.text or "-",(l.idx==5) and C.White or ((l.idx>=4 and l.idx<=6) and C.Sec or C.Dim)
        end)
        gl:Divider()
        st(gl,"Shot type",function() return S.last and typeOf(S.last.ctx) or "-" end)
        gl:Divider()
        st(gl,"Learned timing",function() return (S.last and S.last.ms) and string.format("%+.0f ms",S.last.ms) or "-" end)
        gl:Divider()
        st(gl,"Ping at release",function() return (S.last and S.last.ping) and string.format("%.0f ms",S.last.ping) or "-" end)

        local gs=pg:Group("This session")
        st(gs,"Auto shots",function() return tostring(S.shots) end)
        gs:Divider()
        st(gs,"Made shots (points went up)",function() return tostring(math.max(0,(Hub.Makes or 0)-(S.m0 or 0))) end)
        gs:Divider()
        st(gs,"Perfect",function() return pct(S.c[5],S.shots).."   ("..S.c[5]..")" end)
        gs:Divider()
        st(gs,"In the green (Good to Slightly late)",function() local g=S.c[4]+S.c[5]+S.c[6]; return pct(g,S.shots).."   ("..g..")" end)
        gs:Divider()
        st(gs,"Early",function() local e=S.c[1]+S.c[2]+S.c[3]; return pct(e,S.shots).."   ("..e..")" end)
        gs:Divider()
        st(gs,"Late",function() local l=S.c[7]+S.c[8]; return pct(l,S.shots).."   ("..l..")" end)
        gs:Divider()
        st(gs,"Green streak",function() return S.streak.."   (best "..S.best..")" end)
        gs:Divider()
        st(gs,"Session time",function() local m=math.floor((os.clock()-S.t0)/60); return string.format("%d min",m) end)

        local function tableText(t,maxRows)
            local names={}
            for k in pairs(t) do names[#names+1]=k end
            table.sort(names,function(a,b) return t[a].n>t[b].n end)
            if #names==0 then return "Nothing yet." end
            local out={}
            for i=1,math.min(#names,maxRows) do
                local e=t[names[i]]
                out[#out+1]=string.format("%-14s %3d shots   green %-4s perfect %s",names[i]:sub(1,14),e.n,pct(e.g,e.n),pct(e.p,e.n))
            end
            return table.concat(out,"\n")
        end
        local gt=pg:Group("By shot type")
        local typeL=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Sec,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-10),Parent=gt:_row(66)})
        local gb=pg:Group("By build")
        local buildL=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Sec,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-10),Parent=gb:_row(96)})
        local function summary()
            return string.format("TRAPPED session: %d auto shots, perfect %s, green %s, best streak %d\n\nBy shot type\n%s\n\nBy build\n%s",
                S.shots,pct(S.c[5],S.shots),pct(S.c[4]+S.c[5]+S.c[6],S.shots),S.best,tableText(S.byType,5),tableText(S.byBuild,8))
        end
        gb:Divider()
        gb:Button("Copy session summary",function()
            local txt=summary()
            if type(setclipboard)=="function" and pcall(setclipboard,txt) then Hub:Notify("Session summary copied","success")
            else Hub:Notify("No clipboard here","warn") end
        end)
        gb:Button("Reset session",function() reset(); Hub:Notify("Session reset","info") end)

        
        local KEYS={"shoot.greenAt","shoot.padTrim","shoot.keyHold","shoot.padHold","shoot.fine","shoot.learn"}
        local gp=pg:Group("Per-build settings")
        st(gp,"Current build",function() local _,nm=curBuild(); return nm or "-" end)
        gp:Divider()
        gp:Toggle("Load saved settings when the build changes","build.auto",false,"Each build has its own green. When you switch to a build you saved settings for, its Auto Time settings are loaded by themselves.")
        gp:Button("Save Auto Time settings for this build",function()
            local key,nm=curBuild()
            if not key then Hub:Notify("No build found on your character","warn"); return end
            local t={}
            for _,k in ipairs(KEYS) do if State[k]~=nil then t[k]=State[k] end end
            Hub:Set("build.set."..key,HttpService:JSONEncode(t))
            Hub:Notify("Saved settings for "..nm,"success")
        end)
        gp:Button("Forget this build's saved settings",function()
            local key,nm=curBuild()
            if not key or State["build.set."..key]==nil then Hub:Notify("Nothing saved for this build","info"); return end
            Hub:Set("build.set."..key,"")
            Hub:Notify("Forgot settings for "..nm,"info")
        end)
        function Hub.BuildSwitched(key,nm)
            if State["build.auto"]~=true then return end
            task.defer(function()
                local raw=State["build.set."..key]
                if type(raw)~="string" or raw=="" then return end
                local ok,t=pcall(function() return HttpService:JSONDecode(raw) end)
                if not ok or type(t)~="table" then return end
                local n=0
                for _,k in ipairs(KEYS) do if t[k]~=nil then Hub:Set(k,t[k]); n=n+1 end end
                if n>0 then Hub:Notify("Loaded saved settings for "..tostring(nm),"success") end
            end)
        end

        local acc=0
        track(RunService.Heartbeat:Connect(function(dt)
            acc=acc+dt
            if acc<0.5 or not pg.cg.Visible then return end
            acc=0
            for _,u in ipairs(ups) do pcall(u) end
            typeL.Text=tableText(S.byType,3)
            buildL.Text=tableText(S.byBuild,5)
        end))
    end)()

    
    
    
    ;(function()
        local pg=newPage("Players","Players","Everyone in the server with their avatar. Pick one to spectate, then try the extras.")
        local sel=nil                       
        local specOn=false
        local dirty=true
        local sigLast=""
        local function tChar(p)           
            if not p then return nil end
            local c=p.Character
            if c and c.Parent then return c end
            local f=workspace:FindFirstChild("Characters")
            return (f and f:FindFirstChild(p.Name)) or workspace:FindFirstChild(p.Name) or c
        end
        local function tHum(p) local c=tChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
        local function tRoot(p) local c=tChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
        local function myRoot() local m=myChar(); return m and m:FindFirstChild("HumanoidRootPart") end
        local function myHum() local m=myChar(); return m and m:FindFirstChildOfClass("Humanoid") end
        local function who(p)
            local d=p.DisplayName
            if d and d~="" and d~=p.Name then return d.."  (@"..p.Name..")" end
            return "@"..p.Name
        end
        local function others()
            local t={}
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p end end
            table.sort(t,function(a,b) return a.Name:lower()<b.Name:lower() end)
            return t
        end

        
        local function stopSpec()
            if not specOn then return end
            specOn=false
            pcall(function()
                local c=workspace.CurrentCamera
                if c then
                    c.CameraType=Enum.CameraType.Custom
                    local h=myHum(); if h then c.CameraSubject=h end
                end
            end)
            dirty=true
        end
        local function startSpec(p)
            if not p or p==LP then return end
            local h=tHum(p)
            if not h then Hub:Notify(p.Name.." has no character right now","warn"); return end
            sel=p; specOn=true
            pcall(function()
                local c=workspace.CurrentCamera
                c.CameraType=Enum.CameraType.Custom
                c.CameraSubject=h
            end)
            bootLog("players: spectating "..p.Name)
            dirty=true
            Hub:Notify("Spectating "..p.Name,"success")
        end
        local function stepSel(dir)
            local t=others()
            if #t==0 then Hub:Notify("Nobody else is here","info"); return end
            local i=table.find(t,sel) or (dir>0 and 0 or #t+1)
            i=i+dir
            if i>#t then i=1 elseif i<1 then i=#t end
            sel=t[i]; dirty=true
            if specOn then startSpec(sel) end
        end

        
        local gl=pg:Group("Everyone here")
        local row=gl:_row(60)
        local sf=New("ScrollingFrame",{Size=UDim2.new(1,0,1,-6),Position=UDim2.fromOffset(0,3),BackgroundTransparency=1,BorderSizePixel=0,
            ScrollBarThickness=2,ScrollBarImageColor3=C.Mut,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=row})
        List(sf,Enum.FillDirection.Vertical,6)
        local function render()
            dirty=false
            local items=others()
            for _,c in ipairs(sf:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
            row.Size=UDim2.new(1,0,0,math.clamp(math.max(#items,1)*54+6,60,330))
            if #items==0 then
                MkLbl({Text="Nobody else is in this server.",Font=F.R,TextSize=12,TextColor3=C.Dim,Size=UDim2.new(1,0,0,40),LayoutOrder=1,Parent=sf})
                return
            end
            for i,p in ipairs(items) do
                local isSel=(p==sel)
                local f=New("Frame",{Size=UDim2.new(1,-6,0,48),BackgroundColor3=isSel and C.Bg4 or C.Bg3,BorderSizePixel=0,LayoutOrder=i,Parent=sf})
                Corner(f,10)
                if isSel then Stroke(f,C.White,1,0.6) end
                local av=New("ImageLabel",{Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(36,36),BackgroundColor3=C.Bg4,BorderSizePixel=0,
                    Image="rbxthumb://type=AvatarHeadShot&id="..tostring(p.UserId).."&w=100&h=100",ZIndex=3,Parent=f})
                CornerFull(av)
                local right=8
                local function btn(label,w,on,fn)
                    local b=MkBtn({AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-right,0.5,0),Size=UDim2.fromOffset(w,26),
                        BackgroundColor3=on and C.White or C.Bg4,BorderSizePixel=0,ZIndex=3,Parent=f})
                    Corner(b,8)
                    MkLbl({Text=label,Font=F.B,TextSize=11,TextColor3=on and C.Black or C.Txt,TextXAlignment=Enum.TextXAlignment.Center,
                        Size=UDim2.fromScale(1,1),ZIndex=4,Parent=b})
                    b.MouseButton1Click:Connect(function() task.spawn(fn) end)
                    right=right+w+6
                end
                btn((specOn and isSel) and "Watching" or "Spectate",78,specOn and isSel,function() startSpec(p) end)
                btn(isSel and "Selected" or "Select",70,isSel,function() sel=p; dirty=true end)
                local pc=tChar(p); local ht=pc and pc:GetAttribute("HomeTeam")
                MkLbl({Text=who(p),Font=F.B,TextSize=12,TextColor3=C.Txt,Position=UDim2.fromOffset(54,6),
                    Size=UDim2.new(1,-right-62,0,18),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=3,Parent=f})
                MkLbl({Text=(ht==true and "Home team") or (ht==false and "Away team") or "Not on a team",Font=F.R,TextSize=10,TextColor3=C.Dim,
                    Position=UDim2.fromOffset(54,25),Size=UDim2.new(1,-right-62,0,14),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=3,Parent=f})
            end
        end
        local function sigNow()
            local s={}
            for _,p in ipairs(others()) do
                local pc=tChar(p); local ht=pc and pc:GetAttribute("HomeTeam")
                s[#s+1]=p.Name..":"..tostring(ht)
            end
            return table.concat(s,",").."|"..tostring(sel and sel.Name).."|"..tostring(specOn)
        end
        gl:Divider()
        gl:Button("Refresh list",function() dirty=true end)

        
        local gs=pg:Group("Selected player")
        local upName=gs:Status("Player",function() return sel and who(sel) or "none selected", sel and C.Txt or C.Dim end)
        gs:Divider()
        local upDist=gs:Status("Distance",function()
            local a,b=myRoot(),tRoot(sel)
            if not (a and b) then return "-" end
            return string.format("%.1f studs",(a.Position-b.Position).Magnitude)
        end)
        gs:Divider()
        local upAct=gs:Status("Doing",function()
            local c=tChar(sel)
            if not c then return "-" end
            local a=tostring(c:GetAttribute("Action") or "")
            return a~="" and a or "nothing special"
        end)
        gs:Divider()
        local upBall=gs:Status("Has the ball",function()
            local c=tChar(sel)
            if not c then return "-" end
            return (Hub.HasBall and Hub.HasBall(c)) and "yes" or "no"
        end)
        gs:Divider()
        local upStam=gs:Status("Stamina",function()
            local c=tChar(sel)
            if not c then return "-" end
            local f=c:FindFirstChild("Attributes")
            local sv=f and f:FindFirstChild("Stamina")
            local v=(sv and sv:IsA("ValueBase") and tonumber(sv.Value)) or tonumber(c:GetAttribute("Stamina"))
            return v and string.format("%.0f",v) or "-"
        end)
        gs:Divider()
        gs:Button("Spectate selected",function()
            if not sel then Hub:Notify("Pick a player first","warn"); return end
            startSpec(sel)
        end,"primary")
        gs:Button("Stop spectating",function() stopSpec(); Hub:Notify("Back to your own camera","info") end)
        gs:Button("Next player",function() stepSel(1) end)
        gs:Button("Previous player",function() stepSel(-1) end)
        gs:Divider()
        gs:Button("Go to them",function()
            local a,b=myRoot(),tRoot(sel)
            if not (a and b) then Hub:Notify("Pick a player first","warn"); return end
            a.CFrame=b.CFrame*CFrame.new(0,0,-4)
        end)
        gs:Button("Go behind them",function()
            local a,b=myRoot(),tRoot(sel)
            if not (a and b) then Hub:Notify("Pick a player first","warn"); return end
            a.CFrame=b.CFrame*CFrame.new(0,0,5)
        end)

        
        local gm=pg:Group("Fun: movement (moves you, not them)")
        gm:Toggle("Orbit them","pl.orbit",false,"Your character circles the selected player.")
        gm:Divider()
        gm:Slider("Orbit radius","pl.orbitR",4,24,8,0," studs","How far from them you circle.")
        gm:Divider()
        gm:Slider("Orbit speed","pl.orbitSpd",1,12,3,0,"","How fast you go round.")
        gm:Divider()
        gm:Toggle("Shadow them","pl.shadow",false,"Stay right behind them, facing the way they face, like a shadow.")
        gm:Divider()
        gm:Slider("Shadow gap","pl.shadowGap",3,16,5,0," studs","How far behind them.")
        gm:Divider()
        gm:Toggle("Mirror their movement","pl.mirror",false,"Runs the same direction they run (a second of you pressing a key takes over).")
        gm:Divider()
        gm:Toggle("Stare at them","pl.stare",false,"Keeps your character turned toward them.")
        gm:Divider()
        gm:Toggle("Copycat moves","pl.copy",false,"Plays the same dribble moves, shots and celebrations they play, right after they do.")

        
        local gv=pg:Group("Fun: visual (only you see it)")
        gv:Toggle("Spotlight","pl.spot",false,"Outlines the selected player through walls so you never lose them.")
        gv:Divider()
        gv:Toggle("Rainbow glow","pl.rainbow",false,"Their outline cycles through colours.")
        gv:Divider()
        gv:Toggle("Big head","pl.bighead",false,"Their head looks bigger on your screen.")
        gv:Divider()
        gv:Slider("Head size","pl.headMul",15,60,25,0,"","In tenths: 25 is two and a half times bigger.")
        gv:Divider()
        gv:Toggle("Only show them","pl.solo",false,"Hides every other player on your screen so you see only the selected one (and you).")

        
        local ang=0
        local glow=nil
        local headOrig={}                   
        local hidden={}                     
        local copyConn,copyTracks,copyKey=nil,{},nil
        local function stopCopy()
            if copyConn then copyConn:Disconnect(); copyConn=nil end
            for _,t in pairs(copyTracks) do pcall(function() t:Stop(0.1) end) end
            copyTracks={}; copyKey=nil
        end
        local function startCopy()
            stopCopy()
            local th=tHum(sel)
            local an=th and th:FindFirstChildOfClass("Animator")
            local mh=myHum()
            local ma=mh and mh:FindFirstChildOfClass("Animator")
            if not (an and ma) then return end
            copyKey=tostring(sel)..tostring(th)
            copyConn=an.AnimationPlayed:Connect(function(tr)
                pcall(function()
                    local pr=tr.Priority
                    if pr==Enum.AnimationPriority.Core or pr==Enum.AnimationPriority.Idle or pr==Enum.AnimationPriority.Movement then return end
                    local id=tr.Animation and tr.Animation.AnimationId
                    if not id or id=="" then return end
                    local a=Instance.new("Animation"); a.AnimationId=id
                    local mine=ma:LoadAnimation(a)
                    mine.Priority=Enum.AnimationPriority.Action
                    mine:Play(0.1)
                    copyTracks[tr]=mine
                    tr.Stopped:Connect(function() pcall(function() mine:Stop(0.1) end); copyTracks[tr]=nil end)
                end)
            end)
        end
        local function clearHead()
            for o,v in pairs(headOrig) do
                pcall(function()
                    if o:IsA("SpecialMesh") then o.Scale=v else o.Size=v end
                end)
            end
            headOrig={}
        end
        local function clearHidden()
            for p in pairs(hidden) do pcall(function() p.LocalTransparencyModifier=0 end) end
            hidden={}
        end
        local function clearGlow() if glow then pcall(function() glow:Destroy() end); glow=nil end end

        local hAcc=0
        track(RunService.Heartbeat:Connect(function(dt)
            if not Hub.alive then return end
            
            if specOn then
                if not sel or not sel.Parent then
                    stopSpec(); Hub:Notify("That player left","info")
                else
                    local h=tHum(sel)
                    local c=workspace.CurrentCamera
                    if h and c and c.CameraSubject~=h and c.CameraType~=Enum.CameraType.Scriptable then c.CameraSubject=h end
                end
            end
            local tr,mr,th,mh=tRoot(sel),myRoot(),tHum(sel),myHum()
            local live=(sel~=nil and sel~=LP and sel.Parent~=nil and tr~=nil)
            
            if live and mr then
                if State["pl.orbit"]==true then
                    ang=ang+dt*(tonumber(State["pl.orbitSpd"]) or 3)*0.5
                    local rad=tonumber(State["pl.orbitR"]) or 8
                    local pos=Vector3.new(tr.Position.X+math.cos(ang)*rad,tr.Position.Y,tr.Position.Z+math.sin(ang)*rad)
                    mr.CFrame=CFrame.lookAt(pos,Vector3.new(tr.Position.X,pos.Y,tr.Position.Z))
                    mr.AssemblyLinearVelocity=Vector3.zero
                elseif State["pl.shadow"]==true then
                    local gap=tonumber(State["pl.shadowGap"]) or 5
                    local look=Vector3.new(tr.CFrame.LookVector.X,0,tr.CFrame.LookVector.Z)
                    if look.Magnitude>0.05 then
                        look=look.Unit
                        local pos=Vector3.new(tr.Position.X-look.X*gap,tr.Position.Y,tr.Position.Z-look.Z*gap)
                        mr.CFrame=CFrame.lookAt(pos,pos+look)
                        mr.AssemblyLinearVelocity=Vector3.zero
                    end
                else
                    if State["pl.mirror"]==true and th and mh then pcall(function() mh:Move(th.MoveDirection,false) end) end
                    if State["pl.stare"]==true then
                        mr.CFrame=CFrame.lookAt(mr.Position,Vector3.new(tr.Position.X,mr.Position.Y,tr.Position.Z))
                    end
                end
            end
            
            if live and State["pl.copy"]==true then
                if copyKey~=(tostring(sel)..tostring(th)) then startCopy() end
            elseif copyConn then stopCopy() end
            
            local ch=tChar(sel)
            if live and ch and (State["pl.spot"]==true or State["pl.rainbow"]==true) then
                if not glow or glow.Adornee~=ch or not glow.Parent then
                    clearGlow()
                    pcall(function()
                        glow=Instance.new("Highlight")
                        glow.Adornee=ch
                        glow.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                        glow.FillTransparency=0.65
                        glow.OutlineTransparency=0
                        glow.Parent=workspace.CurrentCamera
                    end)
                end
                if glow then
                    local col=(State["pl.rainbow"]==true) and Color3.fromHSV((os.clock()*0.35)%1,0.9,1) or Color3.fromRGB(255,255,255)
                    glow.FillColor=col; glow.OutlineColor=col
                end
            else clearGlow() end
            hAcc=hAcc+dt
            if hAcc>=0.25 then
                hAcc=0
                
                if live and ch and State["pl.bighead"]==true then
                    local hd=ch:FindFirstChild("Head")
                    local k=math.clamp((tonumber(State["pl.headMul"]) or 25)/10,1.5,6)
                    if hd then
                        pcall(function()
                            local ms=hd:FindFirstChildOfClass("SpecialMesh")
                            if ms then
                                if headOrig[ms]==nil then clearHead(); headOrig[ms]=ms.Scale end
                                ms.Scale=headOrig[ms]*k
                            elseif hd:IsA("BasePart") then
                                if headOrig[hd]==nil then clearHead(); headOrig[hd]=hd.Size end
                                hd.Size=headOrig[hd]*k
                            end
                        end)
                    end
                elseif next(headOrig)~=nil then clearHead() end
                
                if live and State["pl.solo"]==true then
                    for _,p in ipairs(Players:GetPlayers()) do
                        local pcx=tChar(p)
                        if p~=LP and p~=sel and pcx then
                            for _,d in ipairs(pcx:GetDescendants()) do
                                if d:IsA("BasePart") and not hidden[d] then hidden[d]=true; d.LocalTransparencyModifier=1 end
                            end
                        end
                    end
                    for part in pairs(hidden) do
                        if sel and tChar(sel) and part:IsDescendantOf(tChar(sel)) then
                            pcall(function() part.LocalTransparencyModifier=0 end); hidden[part]=nil
                        end
                    end
                elseif next(hidden)~=nil then clearHidden() end
                
                local s=sigNow()
                if s~=sigLast then sigLast=s; dirty=true end
                if dirty then pcall(render) end
                if pg.cg.Visible then
                    pcall(upName); pcall(upDist); pcall(upAct); pcall(upBall); pcall(upStam)
                end
            end
        end))
        track(Players.PlayerRemoving:Connect(function(p) if p==sel then sel=nil; if specOn then stopSpec() end end; dirty=true end))
        track({Disconnect=function()
            pcall(stopSpec); pcall(stopCopy); pcall(clearHead); pcall(clearHidden); pcall(clearGlow)
        end})
        pcall(render)
    end)()

    
    ;(function()
        local pg=newPage("Squad","Squad","Everyone here with an invite button, your party, and incoming invites. It uses the game's own party system.")
        local function svc()
            local fw=Hub.Framework and Hub.Framework()
            return fw and fw.Services and fw.Services.PartyService
        end
        local function send(name,...)
            local args={...}
            local ok=pcall(function()
                local s=svc(); local w=s and s[name]
                if type(w)=="table" and type(w.Fire)=="function" then w:Fire(table.unpack(args)) else error("no wrapper") end
            end)
            if ok then return true end
            return (pcall(function()
                game:GetService("ReplicatedStorage").Aero.AeroRemoteServices.PartyService[name]:FireServer(table.unpack(args))
            end))
        end
        local party=nil          
        local invited={}         
        local invites={}         
        local dirty=true
        local function nameOf(x) return type(x)=="table" and x.Name or (typeof(x)=="Instance" and x.Name) or tostring(x) end
        local function setParty(r)
            if type(r)~="table" or r.Id==nil then
                if party~=nil then party=nil; dirty=true end
                return
            end
            local names={}
            for _,p in ipairs(r.Players or {}) do names[#names+1]=nameOf(p) end
            table.sort(names)
            local np={code=tostring(r.Id),owner=nameOf(r.Owner),players=names}
            local sig=np.code.."|"..np.owner.."|"..table.concat(names,",")
            if not party or party.sig~=sig then np.sig=sig; party=np; dirty=true else party.sig=sig end
        end
        local fetching=false
        local function fetch()
            if fetching then return end
            fetching=true
            task.spawn(function()
                pcall(function()
                    local s=svc()
                    if s then setParty(s:getParty()) end
                end)
                fetching=false
            end)
        end
        local hInv,hUpd=false,false
        local function hook()
            if hInv and hUpd then return end
            local s=svc()
            if not s then return end
            if not hInv then hInv=pcall(function()
                s.partyInvitation:Connect(function(code,from)
                    if not Hub.alive then return end
                    local nm=nameOf(from)
                    for i=#invites,1,-1 do if invites[i].from==nm then table.remove(invites,i) end end
                    invites[#invites+1]={code=code,from=nm,at=os.clock(),plr=from}
                    dirty=true
                    Hub:Notify(nm.." invited you to their party","info")
                    if State["squad.autoFriend"]==true then
                        task.spawn(function()
                            local fr=false
                            pcall(function() fr=LP:IsFriendsWith(typeof(from)=="Instance" and from.UserId or 0) end)
                            if fr and Hub.alive then
                                send("joinParty",code)
                                for i=#invites,1,-1 do if invites[i].code==code then table.remove(invites,i) end end
                                dirty=true
                            end
                        end)
                    end
                end)
            end) end
            if not hUpd then hUpd=pcall(function()
                s.updateParty:Connect(function(r) if Hub.alive then setParty(r); dirty=true end end)
            end) end
        end

        
        local function mkList(group)
            local row=group:_row(56)
            local sf=New("ScrollingFrame",{Size=UDim2.new(1,0,1,-6),Position=UDim2.fromOffset(0,3),BackgroundTransparency=1,BorderSizePixel=0,
                ScrollBarThickness=2,ScrollBarImageColor3=C.Mut,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=row})
            List(sf,Enum.FillDirection.Vertical,6)
            return {row=row,sf=sf}
        end
        local function render(L,items,empty)
            for _,c in ipairs(L.sf:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
            L.row.Size=UDim2.new(1,0,0,math.clamp(math.max(#items,1)*46+6,56,250))
            if #items==0 then
                MkLbl({Text=empty,Font=F.R,TextSize=12,TextColor3=C.Dim,Size=UDim2.new(1,0,0,40),LayoutOrder=1,Parent=L.sf})
                return
            end
            for i,it in ipairs(items) do
                local f=New("Frame",{Size=UDim2.new(1,-6,0,40),BackgroundColor3=C.Bg3,BorderSizePixel=0,LayoutOrder=i,Parent=L.sf})
                Corner(f,10)
                local right=8
                for j=#(it.buttons or {}),1,-1 do
                    local b=it.buttons[j]
                    local btn=MkBtn({AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-right,0.5,0),Size=UDim2.fromOffset(b.w or 78,26),
                        BackgroundColor3=b.on and C.White or C.Bg4,BackgroundTransparency=b.dim and 0.5 or 0,BorderSizePixel=0,ZIndex=3,Parent=f})
                    Corner(btn,8)
                    MkLbl({Text=b.label,Font=F.B,TextSize=11,TextColor3=b.on and C.Black or C.Txt,TextXAlignment=Enum.TextXAlignment.Center,
                        Size=UDim2.fromScale(1,1),ZIndex=4,Parent=btn})
                    if b.fn then btn.MouseButton1Click:Connect(function() task.spawn(b.fn) end) end
                    right=right+(b.w or 78)+6
                end
                MkLbl({Text=it.name,Font=F.B,TextSize=12,TextColor3=it.color or C.Txt,Position=UDim2.fromOffset(12,4),
                    Size=UDim2.new(1,-right-16,0,18),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=3,Parent=f})
                MkLbl({Text=it.sub or "",Font=F.R,TextSize=10,TextColor3=C.Dim,Position=UDim2.fromOffset(12,21),
                    Size=UDim2.new(1,-right-16,0,14),TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=3,Parent=f})
            end
        end

        local gp=pg:Group("Your party")
        local upCode=gp:Status("Party code",function() return party and party.code or "not in a party", party and C.Txt or C.Dim end)
        gp:Divider()
        local upLead=gp:Status("Leader",function() return party and party.owner or "-" end)
        gp:Divider()
        local upCount=gp:Status("Members",function() return party and tostring(#party.players) or "0" end)
        gp:Divider()
        local memberList=mkList(gp)
        gp:Divider()
        gp:Button("Copy party code",function()
            if not party then Hub:Notify("You are not in a party","warn"); return end
            if type(setclipboard)=="function" and pcall(setclipboard,party.code) then Hub:Notify("Party code copied","success")
            else Hub:Notify("Party code: "..party.code,"info") end
        end)
        gp:Button("Leave party",function()
            if not party then Hub:Notify("You are not in a party","warn"); return end
            send("leaveParty"); party=nil; dirty=true; task.delay(0.6,fetch)
        end)

        local gi=pg:Group("Players here")
        local playerList=mkList(gi)
        gi:Divider()
        gi:Button("Invite everyone not in a party",function()
            local n=0
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and not (party and table.find(party.players,p.Name)) and (invited[p.Name] or 0)<os.clock() then
                    send("partyInvitation",p.Name); invited[p.Name]=os.clock()+30; n=n+1
                    task.wait(0.35)
                end
            end
            dirty=true
            Hub:Notify(n>0 and ("Invited "..n.." players") or "Nobody left to invite","info")
        end,"primary")

        local gv=pg:Group("Invitations")
        local inviteList=mkList(gv)
        gv:Divider()
        gv:Toggle("Auto accept invites from friends","squad.autoFriend",false,"Joins the party by itself when a Roblox friend invites you. Invites from anyone else wait here for you to accept.")

        local gj=pg:Group("Join with a code")
        gj:Input("Party code","squad.code","paste a code","Paste a party code, then press Join.")
        gj:Button("Join party",function()
            local c=tostring(State["squad.code"] or ""):gsub("%s+","")
            if c=="" then Hub:Notify("Paste a party code first","warn"); return end
            send("joinParty",c); task.delay(0.8,fetch)
        end)

        local function buildLists()
            local me=party and party.owner==LP.Name
            local mem={}
            if party then
                for _,n in ipairs(party.players) do
                    local item={name=n..((n==party.owner) and "  (leader)" or "")..((n==LP.Name) and "  (you)" or ""),color=(n==party.owner) and Color3.fromRGB(255,170,0) or C.Txt}
                    local ch=workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(n)
                    item.sub=ch and tostring(ch:GetAttribute("BuildName") or "") or ""
                    if me and n~=LP.Name then item.buttons={{label="Kick",fn=function() send("kickPlayer",n); task.delay(0.6,fetch) end}} end
                    mem[#mem+1]=item
                end
            end
            render(memberList,mem,"No one yet. Invite players below.")
            local pl={}
            local list=Players:GetPlayers()
            table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end)
            for _,p in ipairs(list) do
                if p~=LP then
                    local n=p.Name
                    local inParty=party and table.find(party.players,n)
                    local ch=workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild(n)
                    local b
                    if inParty then b={label="In party",dim=true}
                    elseif (invited[n] or 0)>os.clock() then b={label="Invited",dim=true}
                    else b={label="Invite",on=true,fn=function() send("partyInvitation",n); invited[n]=os.clock()+30; dirty=true end} end
                    pl[#pl+1]={name=n,sub=(ch and tostring(ch:GetAttribute("BuildName") or "") or "not on the floor"),buttons={b}}
                end
            end
            render(playerList,pl,"No other players in this server.")
            local iv={}
            for _,v in ipairs(invites) do
                iv[#iv+1]={name=v.from,sub="invited you to their party",buttons={
                    {label="Accept",on=true,fn=function()
                        send("joinParty",v.code)
                        for i=#invites,1,-1 do if invites[i]==v then table.remove(invites,i) end end
                        dirty=true; task.delay(0.8,fetch)
                    end},
                    {label="Decline",w=64,fn=function()
                        for i=#invites,1,-1 do if invites[i]==v then table.remove(invites,i) end end
                        dirty=true
                    end}}}
            end
            render(inviteList,iv,"No invites right now.")
            upCode(); upLead(); upCount()
        end

        local acc,lastN,pollN=0,-1,0
        track(RunService.Heartbeat:Connect(function(dt)
            acc=acc+dt
            if acc<1 then return end
            acc=0
            pcall(hook)
            local now=os.clock()
            for i=#invites,1,-1 do if now-invites[i].at>30 then table.remove(invites,i); dirty=true end end
            for n,t in pairs(invited) do if t<now then invited[n]=nil; dirty=true end end
            local cnt=#Players:GetPlayers()
            if cnt~=lastN then lastN=cnt; dirty=true end
            if not pg.cg.Visible then pollN=0; return end
            pollN=pollN+1
            if pollN%5==1 then fetch() end
            if dirty then dirty=false; pcall(buildLists) end
        end))
        task.delay(0.8,function() pcall(hook); fetch(); pcall(buildLists) end)
    end)()

    
    ;(function()
        local pg=newPage("Builds","Builds","Pick a player: their build, ratings, badges and a 3D view of their character.")
        local sel=LP.Name
        local pick=pg:Group("Player")
        local chipRow=pick:_row(44)
        local chips=New("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,
            ScrollBarImageColor3=C.Mut,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,
            ScrollingDirection=Enum.ScrollingDirection.X,Parent=chipRow})
        List(chips,Enum.FillDirection.Horizontal,8)

        
        local ov=pg:Group("Overview")
        local ovRow=ov:_row(84)
        local ovCells={}
        for i=1,4 do
            local cell=New("Frame",{Position=UDim2.new((i-1)/4,(i==1) and 0 or 4,0,6),Size=UDim2.new(0.25,-6,1,-12),
                BackgroundColor3=C.Bg3,BorderSizePixel=0,Parent=ovRow})
            Corner(cell,12)
            local big=MkLbl({Text="-",Font=F.B,TextSize=22,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Center,
                Position=UDim2.fromOffset(0,10),Size=UDim2.new(1,0,0,30),Parent=cell})
            local cap=MkLbl({Text="",Font=F.B,TextSize=9,TextColor3=C.Mut,TextXAlignment=Enum.TextXAlignment.Center,
                Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,0,16),Parent=cell})
            ovCells[i]={big=big,cap=cap}
        end

        local view=pg:Group("3D view")
        local vrow=view:_row(250)
        local vp=New("ViewportFrame",{Size=UDim2.new(1,0,1,-8),Position=UDim2.fromOffset(0,4),BackgroundColor3=C.Bg3,
            BorderSizePixel=0,Ambient=Color3.fromRGB(170,170,170),LightColor=Color3.fromRGB(255,255,255),
            LightDirection=Vector3.new(-0.4,-0.7,-0.6),Parent=vrow})
        Corner(vp,12)
        local vcam=New("Camera",{FieldOfView=35,Parent=vp})
        vp.CurrentCamera=vcam
        local vNote=MkLbl({Text="",Font=F.R,TextSize=11,TextColor3=C.Mut,Size=UDim2.fromScale(1,1),ZIndex=3,Parent=vp})

        
        local CATS={
            {"Finishing",{"PostHook","CloseShot","DrivingDunk","DrivingLayup","StandingDunk"}},
            {"Shooting",{"MovingShot","FreeThrow","MidRangeShot","ThreePointShot"}},
            {"Playmaking",{"BallHandle","PostControl","PassAccuracy"}},
            {"Defense",{"Rebound","Steal","PerimeterDefense","InteriorDefense","Block","Boxout","LateralSpeed"}},
            {"Physicals",{"Acceleration","Speed","Stamina","Strength","Vertical"}},
        }
        local NICE={PostHook="Post Hook",CloseShot="Close Shot",DrivingDunk="Driving Dunk",DrivingLayup="Driving Layup",StandingDunk="Standing Dunk",
            MovingShot="Moving Shot",FreeThrow="Free Throw",MidRangeShot="Mid-Range Shot",ThreePointShot="Three-Point Shot",
            BallHandle="Ball Handle",PostControl="Post Control",PassAccuracy="Pass Accuracy",Rebound="Rebound",Steal="Steal",
            PerimeterDefense="Perimeter Defense",InteriorDefense="Interior Defense",Block="Block",Boxout="Boxout",LateralSpeed="Lateral Speed",
            Acceleration="Acceleration",Speed="Speed",Stamina="Stamina",Strength="Strength",Vertical="Vertical"}
        local bars={}
        local ratingNote
        for ci,cat in ipairs(CATS) do
            local g=pg:Group(cat[1])
            if ci==1 then
                ratingNote=g:_row(30)
                ratingNote=MkLbl({Text="",Font=F.R,TextSize=11,TextColor3=C.Mut,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,
                    Size=UDim2.fromScale(1,1),Parent=ratingNote.Parent and ratingNote or ratingNote})
            end
            for _,name in ipairs(cat[2]) do
                local row=g:_row(26)
                MkLbl({Text=NICE[name] or name,Font=F.M,TextSize=12,TextColor3=C.Sec,Size=UDim2.new(0,150,1,0),Parent=row})
                local track=New("Frame",{Position=UDim2.new(0,156,0.5,-4),Size=UDim2.new(1,-210,0,8),BackgroundColor3=C.Bg3,BorderSizePixel=0,Parent=row})
                Corner(track,4)
                local fill=New("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.White,BorderSizePixel=0,Parent=track})
                Corner(fill,4)
                local val=MkLbl({Text="-",Font=F.Mono,TextSize=12,TextColor3=C.Txt,TextXAlignment=Enum.TextXAlignment.Right,
                    Position=UDim2.new(1,-40,0,0),Size=UDim2.fromOffset(40,26),Parent=row})
                bars[name]={fill=fill,val=val}
            end
        end

        local bg=pg:Group("Badges")
        local brow=bg:_row(150)
        local badgeL=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Txt,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=brow})

        local ig=pg:Group("Details")
        local irow=ig:_row(300)
        local info=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Txt,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=irow})
        local ag=pg:Group("Every attribute")
        local arow=ag:_row(420)
        local allA=MkLbl({Text="",Font=F.Mono,TextSize=10,TextColor3=C.Sec,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=arow})

        local function charOf(name)
            local f=workspace:FindFirstChild("Characters")
            local c=f and f:FindFirstChild(name)
            if c then return c end
            local p=Players:FindFirstChild(name)
            return p and p.Character or nil
        end
        local function feet(inches)
            inches=tonumber(inches)
            if not inches then return "?" end
            return string.format("%d'%d\"",math.floor(inches/12),math.floor(inches%12))
        end
        local function sortedAttrs(inst)
            local keys={}
            for k in pairs(inst:GetAttributes()) do keys[#keys+1]=k end
            table.sort(keys)
            return keys
        end
        local function show(v)
            if typeof(v)=="Vector3" then return string.format("(%.1f, %.1f, %.1f)",v.X,v.Y,v.Z) end
            if type(v)=="number" then return (v%1==0) and tostring(v) or string.format("%.2f",v) end
            return tostring(v)
        end
        
        local function ownSlot()
            local slot
            pcall(function()
                local fw=Hub.Framework and Hub.Framework()
                local pc=fw and fw.Controllers and fw.Controllers.Player
                slot=pc and pc.SlotData
            end)
            return type(slot)=="table" and slot or nil
        end

        
        local cloneM,cloneOf,angle=nil,nil,0
        local function buildView(ch)
            if cloneM then pcall(function() cloneM:Destroy() end); cloneM=nil end
            cloneOf=ch
            vNote.Text=""
            if not ch then vNote.Text="No character on the floor for this player"; return end
            local cl
            local was=ch.Archivable
            pcall(function() ch.Archivable=true end)
            local ok=pcall(function() cl=ch:Clone() end)
            pcall(function() ch.Archivable=was end)
            if not ok or not cl then vNote.Text="This character cannot be copied for the 3D view"; return end
            for _,d in ipairs(cl:GetDescendants()) do
                if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BodyMover") then
                    pcall(function() d:Destroy() end)
                elseif d:IsA("BasePart") then
                    d.Anchored=true; d.CanCollide=false
                end
            end
            local hum=cl:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end) end
            cl.Parent=vp
            cloneM=cl
            local okb,cf,size=pcall(function() return cl:GetBoundingBox() end)
            if okb then
                cl:PivotTo(CFrame.new(-cf.Position.X,-cf.Position.Y,-cf.Position.Z)*cl:GetPivot())
                vcam.CFrame=CFrame.lookAt(Vector3.new(0,0.4,math.max(7,size.Y*1.9)),Vector3.new(0,0,0))
            end
        end

        
        local profCache,profBusy={},{}
        local refreshInfo
        local function fetchProf(name)
            local c=profCache[name]
            if (c and os.clock()-c.t<30) or profBusy[name] then return end
            profBusy[name]=true
            task.spawn(function()
                local r
                pcall(function()
                    local fw=Hub.Framework and Hub.Framework()
                    r=fw.Services.InterfaceService:GetProfile(name)
                end)
                profBusy[name]=nil
                profCache[name]={t=os.clock(),d=type(r)=="table" and r or false}
                if sel==name then pcall(refreshInfo) end
            end)
        end
        function refreshInfo()
            local ch=charOf(sel)
            local plr=Players:FindFirstChild(sel)
            local mine=(sel==LP.Name)
            local slot=mine and ownSlot() or nil
            local prof,bd
            if not mine then
                fetchProf(sel)
                local c=profCache[sel]
                prof=c and c.d or nil
                bd=prof and type(prof.BuildData)=="table" and prof.BuildData or nil
                if bd then slot={Attributes=bd.Attributes or bd.Ratings,Badges=bd.Badges,MaxBadges=bd.MaxBadges,Vitals=bd,Info=bd} end
            end
            local L={}
            local function add(k,v) if v~=nil and tostring(v)~="" then L[#L+1]=string.format("%-14s %s",k,tostring(v)) end end
            local a=function(n) return ch and ch:GetAttribute(n) or nil end
            
            local vit=slot and slot.Vitals
            local height=(vit and vit.Height) or a("Height")
            local function cell(i,big,cap) ovCells[i].big.Text=tostring(big or "-"); ovCells[i].cap.Text=cap end
            cell(1,a("Overall") or (bd and bd.Overall),"OVERALL")
            cell(2,a("Position") or (bd and bd.Position),"POSITION")
            cell(3,height and feet(height),"HEIGHT")
            cell(4,a("TakeoverType") or (slot and slot.Info and slot.Info.Takeover),"TAKEOVER")
            
            local ratingVals={}
            if slot and type(slot.Attributes)=="table" then
                for _,grp in pairs(slot.Attributes) do
                    if type(grp)=="table" then for k,v in pairs(grp) do ratingVals[k]=tonumber(v) end end
                end
            end
            for name,b in pairs(bars) do
                local v=ratingVals[name]
                if v then
                    b.val.Text=tostring(math.floor(v+0.5)); b.val.TextColor3=C.Txt
                    P(b.fill,{Size=UDim2.fromScale(math.clamp(v/99,0,1),1),BackgroundTransparency=(v>=85) and 0 or (v>=70 and 0.15 or 0.4)},0.2)
                else
                    b.val.Text="-"; b.val.TextColor3=C.Mut
                    P(b.fill,{Size=UDim2.fromScale(0,1)},0.2)
                end
            end
            if mine then
                ratingNote.Text=slot and "Your ratings, read from the game." or "Could not read your ratings yet. Open the game's menu once, or try again in a moment."
            else
                local c=profCache[sel]
                if bd and slot and slot.Attributes then ratingNote.Text="Ratings read from the game's player profile."
                elseif bd then ratingNote.Text="The game's profile for this player has no rating numbers, only the build summary below."
                elseif c and c.d==false then ratingNote.Text="Could not load this player's profile."
                else ratingNote.Text="Loading this player's profile..." end
            end
            
            local BL={}
            if slot and type(slot.Badges)=="table" then
                local names={}
                for n in pairs(slot.Badges) do names[#names+1]=n end
                table.sort(names)
                for _,n in ipairs(names) do
                    local lv=slot.Badges[n]
                    local mx=slot.MaxBadges and slot.MaxBadges[n]
                    BL[#BL+1]=string.format("%-26s level %s%s",n,tostring(lv),mx and (" of "..tostring(mx)) or "")
                end
            end
            if #BL==0 then
                BL[1]=mine and "No badges equipped, or they could not be read yet." or (bd and "This player's profile does not list badges." or "Loading...")
            end
            local bp,mbp=a("BadgePoints"),a("MaxBadgePoints")
            if bp then table.insert(BL,1,string.format("Badge points %s / %s",tostring(bp),tostring(mbp or "?"))) ; table.insert(BL,2,"") end
            badgeL.Text=table.concat(BL,"\n")
            
            add("Player",sel..(plr and plr.DisplayName~=sel and (" ("..plr.DisplayName..")") or ""))
            if ch then
                add("Build",a("BuildName")); add("Position",a("Position")); add("Overall",a("Overall"))
                add("Height",height and (feet(height).."  ("..tostring(height).." in)"))
                add("Weight",(vit and vit.Weight) or a("Weight") and (tostring((vit and vit.Weight) or a("Weight")).." lb"))
                if vit then
                    for _,k in ipairs({"Wingspan","Wing","Body","BodyType"}) do if vit[k]~=nil then add(k,tostring(vit[k])) end end
                end
                add("Hand",a("Hand")); add("Grade",a("Grade"))
                add("Team",a("TeamIndex") and (a("TeamIndex")..(a("HomeTeam")==true and " (home)" or (a("HomeTeam")==false and " (away)" or ""))))
                add("Takeover meter",a("TakeoverFill") and (tostring(math.floor(a("TakeoverFill"))).."%"..(a("Takeover")==true and "  ACTIVE" or "")))
                add("Stamina",a("Stamina") and tostring(math.floor(a("Stamina"))))
                add("Walk speed",a("WalkSpeed") and show(a("WalkSpeed")))
                add("Shot speed",a("ShotSpeed")); add("Power",a("Power"))
                add("Shot animation",a("BaseAnimation")); add("Action",a("Action"))
                local hum=ch:FindFirstChildOfClass("Humanoid")
                local w,h2,d2
                if hum then w,h2,d2=hum:FindFirstChild("BodyWidthScale"),hum:FindFirstChild("BodyHeightScale"),hum:FindFirstChild("BodyDepthScale") end
                if w and h2 and d2 then add("Body scale",string.format("W %.2f  H %.2f  D %.2f",w.Value,h2.Value,d2.Value)) end
            else
                L[#L+1]="No character on the floor right now."
            end
            if bd then
                L[#L+1]=""
                add("Profile build",bd.BuildName); add("Profile overall",bd.Overall)
                local ks={}
                for k,v in pairs(bd) do if type(v)~="table" then ks[#ks+1]=k end end
                table.sort(ks)
                for _,k in ipairs(ks) do if k~="BuildName" and k~="Overall" then add(k,show(bd[k])) end end
                local st=type(prof.Statistics)=="table" and prof.Statistics.Park
                if type(st)=="table" then
                    local g=function(k) return tonumber(st[k]) or 0 end
                    add("Park record",string.format("%d games  %d W",g("GamesPlayed"),g("Wins")))
                    if g("ThreesAttempted")>0 then add("Park 3PT",string.format("%d/%d (%d%%)",g("ThreesMade"),g("ThreesAttempted"),math.floor(g("ThreesMade")/g("ThreesAttempted")*100))) end
                    if g("TwosAttempted")>0 then add("Park 2PT",string.format("%d/%d (%d%%)",g("TwosMade"),g("TwosAttempted"),math.floor(g("TwosMade")/g("TwosAttempted")*100))) end
                end
            end
            if plr then
                local pa=function(n) return plr:GetAttribute(n) end
                L[#L+1]=""
                add("Nickname",pa("BuildNickname")); add("Reputation",pa("Reputation")); add("Title",pa("Title"))
                add("Record",pa("Wins") and (tostring(pa("Wins")).." W  "..tostring(pa("Losses") or 0).." L"))
                add("Season",pa("SeasonWins") and (tostring(pa("SeasonWins")).." W  "..tostring(pa("SeasonLosses") or 0).." L  streak "..tostring(pa("SeasonStreak") or 0)))
                add("Games",pa("GamesPlayed"))
                add("Totals",pa("Points") and string.format("%s pts  %s reb  %s ast  %s stl  %s blk",tostring(pa("Points")),tostring(pa("Rebounds") or 0),tostring(pa("Assists") or 0),tostring(pa("Steals") or 0),tostring(pa("Blocks") or 0)))
                add("VIP",pa("VIP")==true and "yes" or nil)
            end
            info.Text=table.concat(L,"\n")
            local A={}
            if ch then
                A[#A+1]="-- character --"
                for _,k in ipairs(sortedAttrs(ch)) do A[#A+1]=k.." = "..show(ch:GetAttribute(k)) end
            end
            if plr then
                A[#A+1]=""; A[#A+1]="-- player --"
                for _,k in ipairs(sortedAttrs(plr)) do A[#A+1]=k.." = "..show(plr:GetAttribute(k)) end
            end
            allA.Text=table.concat(A,"\n")
        end

        local chipBtns={}
        local function paintChips()
            for n,b in pairs(chipBtns) do
                local on=(n==sel)
                P(b.btn,{BackgroundColor3=on and C.White or C.Bg3},0.15)
                P(b.lbl,{TextColor3=on and C.Black or C.Sec},0.15)
            end
        end
        local function rebuildChips()
            for _,b in pairs(chipBtns) do pcall(function() b.btn:Destroy() end) end
            chipBtns={}
            local names={}
            for _,p in ipairs(Players:GetPlayers()) do names[#names+1]=p.Name end
            table.sort(names,function(x,y) if x==LP.Name then return true elseif y==LP.Name then return false end return x:lower()<y:lower() end)
            for i,n in ipairs(names) do
                local btn=MkBtn({Size=UDim2.fromOffset(0,32),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=C.Bg3,
                    BackgroundTransparency=0,BorderSizePixel=0,LayoutOrder=i,Parent=chips})
                Corner(btn,10); Pad(btn,12,12,0,0)
                local lbl=MkLbl({Text=(n==LP.Name) and "You" or n,Font=F.B,TextSize=11,TextColor3=C.Sec,
                    Size=UDim2.fromOffset(0,32),AutomaticSize=Enum.AutomaticSize.X,ZIndex=3,Parent=btn})
                chipBtns[n]={btn=btn,lbl=lbl}
                btn.MouseButton1Click:Connect(function()
                    sel=n; paintChips(); buildView(charOf(sel)); refreshInfo()
                end)
            end
            if not chipBtns[sel] then sel=LP.Name end
            paintChips()
        end

        local nameKey=""
        local acc=0
        track(RunService.Heartbeat:Connect(function(dt)
            if not pg.cg.Visible then return end
            angle=angle+dt*0.9
            if cloneM then pcall(function()
                cloneM:PivotTo(CFrame.new(cloneM:GetPivot().Position)*CFrame.Angles(0,angle,0))
            end) end
            acc=acc+dt
            if acc<1 then return end
            acc=0
            pcall(function()
                local names={}
                for _,p in ipairs(Players:GetPlayers()) do names[#names+1]=p.Name end
                table.sort(names)
                local key=table.concat(names,",")
                if key~=nameKey then nameKey=key; rebuildChips() end
                local ch=charOf(sel)
                if ch~=cloneOf then buildView(ch) end
                refreshInfo()
            end)
        end))
        task.delay(0.5,function() pcall(function() rebuildChips(); buildView(charOf(sel)); refreshInfo() end) end)
    end)()

    
    ;(function()
        local pg=newPage("Scout","Scout","Live read on everyone on the floor, and what your own shots teach it.")
        local rg=pg:Group("Matchup radar")
        rg:Toggle("Matchup radar","scout.radar",false,"Live panel: side, overall, stamina, takeover and hot or cold streak for every player.")
        rg:Divider()
        local row=rg:_row(168)
        local radar=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Txt,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=row})
        local cg=pg:Group("Contest predictor")
        cg:Toggle("Use predictor for auto shoot","scout.useModel",false,"Auto shoot uses the predicted contest below instead of a fixed open distance, once it has learned from enough shots.")
        cg:Divider()
        cg:Slider("Max predicted contest","scout.maxC",5,60,25,0,"%","Shoot only when the predicted contest is at or under this.")
        cg:Divider()
        local crow=cg:_row(76)
        local cl=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Txt,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=crow})
        local zg=pg:Group("Shot chart")
        local zrow=zg:_row(132)
        local zl=MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Txt,Position=UDim2.fromOffset(0,8),
            Size=UDim2.new(1,0,1,-12),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Parent=zrow})
        zg:Divider()
        zg:Button("Reset what Scout has learned",function()
            for k in pairs(State) do
                if type(k)=="string" and (k:sub(1,8)=="scout.c." or k:sub(1,8)=="scout.n." or k:sub(1,8)=="scout.z.") then State[k]=nil end
            end
            Hub:Notify("Scout data cleared","info")
        end)

        
        Hub.HasBall=function(c) local ok,r=pcall(H.hasBall,c); return ok and r==true end
        function Hub.HoopDist()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            if not mine then return nil end
            H.refreshCourt()
            local _,gd=H.nearestOf(H.goals(),mine.Position)
            local hum=me:FindFirstChildOfClass("Humanoid")
            return (gd and gd<math.huge) and gd or nil,mine.AssemblyLinearVelocity.Magnitude,H.hasBall(me),hum and hum.MoveDirection.Magnitude or 0
        end
        
        function Hub.ShotContext()
            local me=myChar()
            local mine=me and me:FindFirstChild("HumanoidRootPart")
            if not mine then return nil end
            H.refreshCourt()
            local _,gd=H.nearestOf(H.goals(),mine.Position)
            H.nearestHandler(me,0.001)
            local nearest=math.huge
            for _,c in ipairs(H.near()) do
                local oh=c:FindFirstChild("HumanoidRootPart")
                if oh and H.opponent(me,c) then nearest=math.min(nearest,(oh.Position-mine.Position).Magnitude) end
            end
            return (gd and gd<math.huge) and gd or nil,(nearest<math.huge) and nearest or nil
        end
        
        function Hub.RecordShot(lbl,idx)
            local contest
            pcall(function()
                local gui=lbl:FindFirstAncestorOfClass("BillboardGui")
                local ct=gui and gui:FindFirstChild("Contest",true)
                contest=ct and tonumber(tostring(ct.Text):match("([%d%.]+)"))
            end)
            local gd,dd=Hub._relGd,Hub._relDef
            if dd and contest then
                local b=math.min(9,math.floor(dd/2))
                Hub:Set("scout.c."..b,(tonumber(State["scout.c."..b]) or 0)+contest)
                Hub:Set("scout.n."..b,(tonumber(State["scout.n."..b]) or 0)+1)
            end
            if gd then
                local z=math.min(4,math.floor(gd/8))
                local q=math.max(0,100-math.abs(idx-5)*20)            
                Hub:Set("scout.z."..z..".q",(tonumber(State["scout.z."..z..".q"]) or 0)+q)
                Hub:Set("scout.z."..z..".n",(tonumber(State["scout.z."..z..".n"]) or 0)+1)
            end
        end
        local function bucketAvg(b)
            local n=tonumber(State["scout.n."..b]) or 0
            if n<2 then return nil,n end
            return (tonumber(State["scout.c."..b]) or 0)/n,n
        end
        function Hub.PredictContest(dist)
            local b=math.min(9,math.floor(dist/2))
            local v=bucketAvg(b)
            if v then return v end
            for k=1,3 do
                local lo,hi=bucketAvg(b-k),bucketAvg(b+k)
                if lo and hi then return (lo+hi)/2 elseif lo or hi then return lo or hi end
            end
            return nil
        end

        local function pad(sv,n) sv=tostring(sv); return sv..string.rep(" ",math.max(0,n-#sv)) end
        task.spawn(function()
            while Hub.alive do
                pcall(function()
                    
                    if State["scout.radar"]==true and pg.cg.Visible then
                        local okR,errR=pcall(function()
                            local me=myChar()
                            local lines={pad("PLAYER",14)..pad("SIDE",5)..pad("OVR",5)..pad("STA",6).."NOTES"}
                            local rows={}
                            if me then pcall(H.nearestHandler,me,0.001) end          
                            local seen={}
                            local function addRow(c,label)
                                if not c or c==me or seen[c] or c.Name=="InvisCharacter" then return end
                                seen[c]=true
                                local side=(me and H.opponent(me,c)) and "OPP" or "TM"
                                local sta=tonumber(c:GetAttribute("Stamina"))
                                local note={}
                                if c:GetAttribute("Takeover") then note[#note+1]="TAKEOVER"
                                elseif (tonumber(c:GetAttribute("TakeoverFill")) or 0)>0 then note[#note+1]=string.format("tko %d",tonumber(c:GetAttribute("TakeoverFill")) or 0) end
                                if c:GetAttribute("Cold") then note[#note+1]="COLD" end
                                if sta and sta<35 then note[#note+1]="TIRED" end
                                if H.hasBall(c) then note[#note+1]="BALL" end
                                rows[#rows+1]={side=side,text=pad(tostring(label or c.Name):sub(1,13),14)..pad(side,5)..pad(tostring(c:GetAttribute("Overall") or "?"),5)
                                    ..pad(sta and (math.floor(sta).."%") or "?",6)..table.concat(note," ")}
                            end
                            for _,pl in ipairs(Players:GetPlayers()) do if pl~=LP then addRow(pl.Character,pl.Name) end end
                            for _,c in ipairs(H.near()) do addRow(c) end
                            table.sort(rows,function(a,b) if a.side~=b.side then return a.side>b.side end return a.text<b.text end)
                            for i=1,math.min(#rows,9) do lines[#lines+1]=rows[i].text end
                            if #rows==0 then lines[#lines+1]="nobody else on the floor yet"
                            elseif #rows>9 then lines[#lines+1]="+"..(#rows-9).." more" end
                            radar.Text=table.concat(lines,"\n")
                        end)
                        if not okR then radar.Text="radar error: "..tostring(errR) end
                    end
                    
                    if pg.cg.Visible then
                        local total=0
                        for b=0,9 do total=total+(tonumber(State["scout.n."..b]) or 0) end
                        local gd,dd=Hub.ShotContext()
                        local pc=dd and Hub.PredictContest(dd)
                        cl.Text=string.format("Shots learned from: %d\nNearest defender: %s\nPredicted contest now: %s",total,
                            dd and string.format("%.1f studs",dd) or "none",
                            pc and string.format("~%d%%",math.floor(pc+0.5)) or (total<20 and "still learning" or "no data at this distance"))
                        local names={"0-8","8-16","16-24","24-32","32+"}
                        local zl2={pad("ZONE (studs)",14)..pad("SHOTS",7).."RELEASE QUALITY"}
                        local best,bq
                        for z=0,4 do
                            local n=tonumber(State["scout.z."..z..".n"]) or 0
                            local q=n>0 and (tonumber(State["scout.z."..z..".q"]) or 0)/n or nil
                            if q and (not bq or q>bq) and n>=3 then best,bq=names[z+1],q end
                            zl2[#zl2+1]=pad(names[z+1],14)..pad(n,7)..(q and (math.floor(q).."%") or "-")
                        end
                        zl2[#zl2+1]=best and ("Best zone so far: "..best) or "Take a few shots from each range to see your best zone."
                        zl.Text=table.concat(zl2,"\n")
                    end
                end)
                task.wait(0.7)
            end
        end)
    end)()

    
    ;(function()
        local RS=game:GetService("ReplicatedStorage")
        local pg=newPage("Cosmetics","Cosmetics","Try on accessories, clothes and full mascot costumes. Visual only, and only you can see it.")
        local CATS={}
        pcall(function()
            local a=RS:FindFirstChild("Accessories")
            if a then
                local seen={}
                for _,c in ipairs(a:GetChildren()) do
                    if c:IsA("Folder") and not seen[c.Name] then seen[c.Name]=true; CATS[#CATS+1]=c.Name end
                end
            end
        end)
        if #CATS==0 then CATS={"Hats"} end
        CATS[#CATS+1]="Shirts"; CATS[#CATS+1]="Pants"
        local PAGE_N=12
        local function isClothes(c) return c=="Shirts" or c=="Pants" end
        local st={ci=1,page=1,list={},worn={},wornName={},tiles={}}

        local function mainPart(inst)
            if inst:IsA("BasePart") then return inst end
            return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart",true)
        end
        local function key(item) if type(item)=='table' then return item.kind..tostring(item.tpl) end return item:GetFullName() end

        
        local function buildList()
            st.list={}
            local q=string.lower(tostring(State["cos.search"] or ""))
            local cat0=CATS[st.ci]
            if isClothes(cat0) then
                for _,c in ipairs(st.clothes or {}) do
                    if c.kind==(cat0=="Shirts" and "Shirt" or "Pants") and (q=="" or string.find(string.lower(c.name),q,1,true)) then
                        st.list[#st.list+1]=c
                    end
                end
                st.page=1
                return
            end
            if cat0=="Mascots" then
                pcall(function()
                    local folder=RS.Accessories:FindFirstChild("Mascots")
                    for _,d in ipairs(folder and folder:GetChildren() or {}) do
                        if d:IsA("Model") and (q=="" or string.find(string.lower(d.Name),q,1,true)) then st.list[#st.list+1]=d end
                    end
                    table.sort(st.list,function(a,b) return a.Name<b.Name end)
                end)
                st.page=1
                return
            end
            pcall(function()
                local folder=RS.Accessories:FindFirstChild(CATS[st.ci])
                if not folder then return end
                for _,d in ipairs(folder:GetDescendants()) do
                    if d:IsA("BasePart") or d:IsA("Model") then
                        local mp=mainPart(d)
                        if mp and mp:FindFirstChildWhichIsA("Attachment") and (q=="" or string.find(string.lower(d.Name),q,1,true)) then
                            if not (d:IsA("BasePart") and d.Parent and d.Parent:IsA("Model") and mainPart(d.Parent)==d) then
                                st.list[#st.list+1]=d
                            end
                        end
                    end
                end
                table.sort(st.list,function(a,b) return a.Name<b.Name end)
            end)
            st.page=1
        end
        local function charAttachment(char,name)
            for _,d in ipairs(char:GetDescendants()) do
                if d:IsA("Attachment") and d.Name==name then return d end
            end
        end
        local refreshAll          
        local function takeOff(cat)
            local rs=st.restore and st.restore[cat]
            if rs then pcall(rs); st.restore[cat]=nil end
            local w=st.worn[cat]
            if w and typeof(w)=="Instance" then pcall(function() w:Destroy() end) end
            st.worn[cat]=nil; st.wornName[cat]=nil
            if st.wornKey then st.wornKey[cat]=nil end
        end
        st.restore={}
        
        local function harvestClothes()
            if st.clothes or st.scanning then return end
            st.scanning=true
            task.spawn(function()
                local out,seen,n={}, {}, 0
                for _,root in ipairs({workspace,RS}) do
                    pcall(function()
                        for _,d in ipairs(root:GetDescendants()) do
                            n=n+1
                            if n%1500==0 then task.wait() end
                            local kind,tpl
                            if d:IsA("Shirt") then kind,tpl="Shirt",d.ShirtTemplate
                            elseif d:IsA("Pants") then kind,tpl="Pants",d.PantsTemplate end
                            if kind and tpl and tpl~="" and not seen[kind..tpl] then
                                seen[kind..tpl]=true
                                local who=d.Parent and d.Parent.Name or "?"
                                out[#out+1]={kind=kind,tpl=tpl,name=kind.." "..(#out+1).." ("..who..")"}
                            end
                        end
                    end)
                end
                st.clothes=out; st.scanning=false
                if Hub.alive then pcall(function() buildList(); refreshAll() end) end
            end)
        end
        local function wearClothes(item,cat)
            local char=myChar()
            if not char then Hub:Notify("No character yet","warn"); return false end
            local cls=item.kind
            local inst=char:FindFirstChildOfClass(cls)
            local prop=(cls=="Shirt") and "ShirtTemplate" or "PantsTemplate"
            local created=false
            if not inst then inst=Instance.new(cls); inst.Parent=char; created=true end
            takeOff(cat)
            local orig=inst[prop]
            inst[prop]=item.tpl
            st.restore[cat]=function()
                if created then inst:Destroy() elseif inst.Parent then inst[prop]=orig end
            end
            st.worn[cat]=true; st.wornName[cat]=item.name
            st.wornKey=st.wornKey or {}; st.wornKey[cat]=key(item)
            return true
        end
        
        local function suitUp(item,cat)
            local char=myChar()
            if not char then Hub:Notify("No character yet","warn"); return false end
            takeOff(cat)
            local clone=item:Clone()
            for _,d in ipairs(clone:GetDescendants()) do
                if d:IsA("Humanoid") or d:IsA("Motor6D") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Animator") then d:Destroy() end
            end
            local hidden={}
            for _,d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name~="HumanoidRootPart" then hidden[#hidden+1]={d,"Transparency",d.Transparency}; d.Transparency=1
                elseif d:IsA("Decal") then hidden[#hidden+1]={d,"Transparency",d.Transparency}; d.Transparency=1 end
            end
            local parts,anchor={},nil
            for _,d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored=true; d.CanCollide=false; d.CanQuery=false; d.CanTouch=false; d.Massless=true
                    parts[#parts+1]=d
                end
            end
            clone.Parent=char
            local matched={}
            for _,p in ipairs(parts) do
                local cp=char:FindFirstChild(p.Name)
                if cp and cp:IsA("BasePart") and cp.Name~="HumanoidRootPart" then matched[p]=cp; anchor=anchor or p end
            end
            if not anchor then
                clone:Destroy()
                for _,h in ipairs(hidden) do pcall(function() h[1][h[2]]=h[3] end) end
                Hub:Notify(item.Name.." does not fit your character","warn")
                return false
            end
            for _,p in ipairs(parts) do                 
                if not matched[p] then
                    local wc=Instance.new("WeldConstraint"); wc.Part0=anchor; wc.Part1=p; wc.Parent=p
                end
            end
            for p,cp in pairs(matched) do
                local w=Instance.new("Weld"); w.Part0=cp; w.Part1=p; w.C0=CFrame.Angles(0,(State["cos.flip"]~=false) and math.pi or 0,0); w.C1=CFrame.new(); w.Parent=p
            end
            for _,p in ipairs(parts) do p.Anchored=false end
            st.restore[cat]=function()
                clone:Destroy()
                for _,h in ipairs(hidden) do pcall(function() h[1][h[2]]=h[3] end) end
            end
            st.mascotItem=item
            st.worn[cat]=clone; st.wornName[cat]=item.Name
            st.wornKey=st.wornKey or {}; st.wornKey[cat]=key(item)
            return true
        end
        local function wear(item,cat)
            if type(item)=="table" then return wearClothes(item,cat) end
            if cat=="Mascots" then return suitUp(item,cat) end
            local char=myChar()
            if not char then Hub:Notify("No character yet","warn"); return false end
            local clone=item:Clone()
            local mp=mainPart(clone)
            local att=mp and mp:FindFirstChildWhichIsA("Attachment")
            if not att then clone:Destroy(); Hub:Notify(item.Name.." has no attachment point","warn"); return false end
            local target=charAttachment(char,att.Name)
            if not target then clone:Destroy(); Hub:Notify("Your character has no "..att.Name.." spot","warn"); return false end
            takeOff(cat)
            local parts=clone:IsA("BasePart") and {clone} or clone:GetDescendants()
            for _,p in ipairs(parts) do
                if p:IsA("BasePart") then
                    p.Anchored=false; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.Massless=true
                    if p~=mp then
                        local wc=Instance.new("WeldConstraint"); wc.Part0=mp; wc.Part1=p; wc.Parent=p
                    end
                end
            end
            local w=Instance.new("Weld")
            w.Part0=target.Parent; w.Part1=mp; w.C0=target.CFrame; w.C1=att.CFrame; w.Parent=mp
            clone.Parent=char
            st.worn[cat]=clone; st.wornName[cat]=item.Name
            st.wornKey=st.wornKey or {}; st.wornKey[cat]=key(item)
            return true
        end

        
        local top=pg:Group("Browse")
        
        local chipRows=math.ceil(#CATS/4)
        local chipRow=top:_row(chipRows*40)
        local chipScroll=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Parent=chipRow})
        New("UIGridLayout",{CellSize=UDim2.new(0.25,-6,0,32),CellPadding=UDim2.fromOffset(8,8),
            SortOrder=Enum.SortOrder.LayoutOrder,Parent=chipScroll})
        local chips={}
        local function paintChips()
            for i,ch in ipairs(chips) do
                local on=(i==st.ci)
                P(ch.btn,{BackgroundColor3=on and C.White or C.Bg3},0.15)
                P(ch.lbl,{TextColor3=on and C.Black or C.Sec},0.15)
            end
        end
        for i,name in ipairs(CATS) do
            local btn=MkBtn({BackgroundColor3=C.Bg3,BackgroundTransparency=0,
                BorderSizePixel=0,LayoutOrder=i,Parent=chipScroll})
            Corner(btn,16)
            local lbl=MkLbl({Text=name,Font=F.B,TextSize=12,TextColor3=C.Sec,TextXAlignment=Enum.TextXAlignment.Center,
                Size=UDim2.fromScale(1,1),ZIndex=3,Parent=btn})
            chips[i]={btn=btn,lbl=lbl}
            btn.MouseEnter:Connect(function() if st.ci~=i then P(btn,{BackgroundColor3=C.Bg4},0.12) end end)
            btn.MouseLeave:Connect(function() if st.ci~=i then P(btn,{BackgroundColor3=C.Bg3},0.15) end end)
            btn.MouseButton1Click:Connect(function() st.ci=i; if isClothes(CATS[i]) then harvestClothes() end; buildList(); refreshAll() end)
        end
        top:Divider()
        top:Toggle("Turn mascots around","cos.flip",true,"If a mascot's face points backward, switch this. It refits the mascot you are wearing.")
        top:Divider()
        top:Input("Search","cos.search","type part of a name","Filters the current category.")
        top:Divider()

        
        local gridRow=top:_row(4*104+3*8+8)
        local grid=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Parent=gridRow})
        New("UIGridLayout",{CellSize=UDim2.new(1/3,-6,0,104),CellPadding=UDim2.fromOffset(8,8),
            SortOrder=Enum.SortOrder.LayoutOrder,Parent=grid})
        local emptyL=MkLbl({Text="Nothing in this category matches.",Font=F.R,TextSize=12,TextColor3=C.Dim,
            TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1),Visible=false,Parent=gridRow})

        local function viewport(parent,item)
            local vp=New("ViewportFrame",{Size=UDim2.new(1,0,1,-30),BackgroundTransparency=1,BorderSizePixel=0,
                Ambient=Color3.fromRGB(190,190,190),LightColor=Color3.fromRGB(255,255,255),Parent=parent})
            pcall(function()
                local c=item:Clone()
                local mp=mainPart(c)
                if not mp then c:Destroy(); return end
                local cf,size
                if c:IsA("Model") then cf,size=c:GetBoundingBox() else cf,size=c.CFrame,c.Size end
                c.Parent=vp
                local cam=Instance.new("Camera")
                local ext=math.max(size.X,size.Y,size.Z,0.2)
                local dist=ext*1.7/math.tan(math.rad(35))
                cam.FieldOfView=70
                cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(ext*0.35,ext*0.25,dist),cf.Position)
                cam.Parent=vp; vp.CurrentCamera=cam
            end)
            return vp
        end
        local gridTok=0
        local function buildGrid()
            gridTok=gridTok+1
            local myTok=gridTok
            for _,t in ipairs(st.tiles) do pcall(function() t:Destroy() end) end
            st.tiles={}
            local from=(st.page-1)*PAGE_N
            emptyL.Visible=(#st.list==0)
            emptyL.Text=st.scanning and "Looking for clothes in the game..." or "Nothing in this category matches."
            for i=1,PAGE_N do
                local item=st.list[from+i]
                if not item then break end
                if i>1 and (i-1)%3==0 then
                    task.wait()                                  
                    if myTok~=gridTok or not Hub.alive then return end
                end
                local cat=CATS[st.ci]
                local tile=New("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=C.Bg3,BorderSizePixel=0,
                    LayoutOrder=i,Parent=grid})
                Corner(tile,12)
                local stroke=Stroke(tile,C.Line,1,0)
                if type(item)=="table" then
                    New("ImageLabel",{Size=UDim2.new(1,0,1,-30),BackgroundTransparency=1,Image=item.tpl,ScaleType=Enum.ScaleType.Fit,Parent=tile})
                else
                    viewport(tile,item)
                end
                MkLbl({Text=(type(item)=="table") and item.name or item.Name,Font=F.M,TextSize=10,TextColor3=C.Sec,TextXAlignment=Enum.TextXAlignment.Center,
                    TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,TextYAlignment=Enum.TextYAlignment.Center,
                    Position=UDim2.new(0,6,1,-30),Size=UDim2.new(1,-12,0,28),Parent=tile})
                local tag=MkLbl({Text="WORN",Font=F.B,TextSize=9,TextColor3=C.Black,BackgroundTransparency=0,
                    BackgroundColor3=C.White,TextXAlignment=Enum.TextXAlignment.Center,AnchorPoint=Vector2.new(1,0),
                    Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(38,14),Visible=false,ZIndex=5,Parent=tile})
                Corner(tag,7)
                local isWorn=(st.wornKey and st.wornKey[cat]==key(item))
                tag.Visible=isWorn
                stroke.Color=isWorn and C.White or C.Line
                tile.MouseEnter:Connect(function() if not tag.Visible then P(stroke,{Color=C.LineHi},0.12) end end)
                tile.MouseLeave:Connect(function() if not tag.Visible then P(stroke,{Color=C.Line},0.15) end end)
                tile.MouseButton1Click:Connect(function()
                    if st.wornKey and st.wornKey[cat]==key(item) then
                        takeOff(cat); st.wornKey[cat]=nil
                    else
                        pcall(wear,item,cat)
                    end
                    refreshAll()
                end)
                st.tiles[#st.tiles+1]=tile
            end
        end

        
        local pagerRow=top:_row(44)
        local pageL=MkLbl({Text="",Font=F.B,TextSize=12,TextColor3=C.Sec,TextXAlignment=Enum.TextXAlignment.Center,
            Size=UDim2.new(1,-120,1,0),Position=UDim2.fromOffset(60,0),Parent=pagerRow})
        local function pagerBtn(txt,x,fn)
            local b=MkBtn({Position=UDim2.new(x,x==0 and 0 or -46,0.5,-17),Size=UDim2.fromOffset(46,34),BackgroundColor3=C.Bg3,
                BackgroundTransparency=0,BorderSizePixel=0,Parent=pagerRow})
            Corner(b,10); Stroke(b,C.Line,1,0)
            MkLbl({Text=txt,Font=F.B,TextSize=14,TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1),Parent=b})
            b.MouseEnter:Connect(function() P(b,{BackgroundColor3=C.Bg4},0.12) end)
            b.MouseLeave:Connect(function() P(b,{BackgroundColor3=C.Bg3},0.15) end)
            b.MouseButton1Click:Connect(fn)
        end
        local function pages() return math.max(1,math.ceil(#st.list/PAGE_N)) end
        pagerBtn("<",0,function() st.page=((st.page-2)%pages())+1; buildGrid(); refreshAll(true) end)
        pagerBtn(">",1,function() st.page=(st.page%pages())+1; buildGrid(); refreshAll(true) end)

        
        do
            local ig=pg:Group("Wear your own (asset ID)")
            ig:Input("Asset ID","cos.asset","paste a Roblox asset id","The number from a Creator Store model, a catalog accessory or a character model link.")
            ig:Divider()
            local function isRig(inst)
                local n=0
                for _,d in ipairs(inst:GetDescendants()) do
                    if d:IsA("BasePart") and (d.Name=="UpperTorso" or d.Name=="Head" or d.Name=="LeftUpperArm" or d.Name=="RightUpperLeg") then n=n+1 end
                end
                return n>=2
            end
            local function loadAsset()
                local id=tostring(State["cos.asset"] or ""):match("%d+")
                if not id then Hub:Notify("Type an asset id first","warn"); return end
                local ok,objs=pcall(function() return game:GetObjects("rbxassetid://"..id) end)
                if not ok or type(objs)~="table" or #objs==0 then
                    Hub:Notify("Could not load asset "..id..". It must be a model or an accessory you are allowed to use.","warn")
                    bootLog("cosmetics: asset "..id.." did not load: "..tostring(objs))
                    return
                end
                for _,o in ipairs(objs) do
                    if o:IsA("Accessory") or o:IsA("Hat") then
                        local h=o:FindFirstChild("Handle")
                        if h then
                            local ok2=wear(o,"Imported")
                            Hub:Notify(ok2 and ("Wearing "..o.Name) or ("Could not fit "..o.Name),ok2 and "success" or "warn")
                            return
                        end
                    elseif (o:IsA("Model") or o:IsA("Folder")) and isRig(o) then
                        st.customOn=false
                        local ok2=suitUp(o,"Mascots")
                        if ok2 then st.wornName["Mascots"]=o.Name end
                        pcall(refreshAll,true)
                        Hub:Notify(ok2 and ("Wearing "..o.Name) or ("Could not fit "..o.Name),ok2 and "success" or "warn")
                        return
                    end
                end
                
                for _,o in ipairs(objs) do
                    for _,d in ipairs(o:GetDescendants()) do
                        if d:IsA("Accessory") and d:FindFirstChild("Handle") then
                            local ok2=wear(d,"Imported")
                            Hub:Notify(ok2 and ("Wearing "..d.Name) or ("Could not fit "..d.Name),ok2 and "success" or "warn")
                            return
                        end
                    end
                end
                Hub:Notify("That asset is not a character model or an accessory","warn")
            end
            ig:Button("Wear it",function() task.spawn(function() pcall(loadAsset) end) end,"primary")
            ig:Button("Take it off",function()
                pcall(takeOff,"Imported"); pcall(takeOff,"Mascots"); pcall(refreshAll,true)
            end)
        end

        
        do
            local cg=pg:Group("Mix game mascots")
            local names={}
            pcall(function()
                for _,d in ipairs(RS.Accessories.Mascots:GetChildren()) do
                    if d:IsA("Model") then names[#names+1]=d.Name end
                end
                table.sort(names)
            end)
            local SLOTS={
                {"Head",{"Head"}},
                {"Torso",{"UpperTorso","LowerTorso"}},
                {"Arms",{"LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand"}},
                {"Legs",{"LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}},
            }
            local pick={}
            for i=1,#SLOTS do pick[i]=1 end
            local standard={HumanoidRootPart=true}
            for _,sl in ipairs(SLOTS) do for _,n in ipairs(sl[2]) do standard[n]=true end end
            local updFns={}
            local function build()
                local model=Instance.new("Model"); model.Name="CustomMascot"
                for i,sl in ipairs(SLOTS) do
                    local src=RS.Accessories.Mascots:FindFirstChild(names[pick[i]] or "")
                    if src then
                        if i==1 then                      
                            local hd=src:FindFirstChild("Head")
                            if hd and hd:IsA("BasePart") then hd:Clone().Parent=model end
                            for _,d in ipairs(src:GetChildren()) do
                                if d:IsA("BasePart") and not standard[d.Name] then d:Clone().Parent=model end
                            end
                        else
                            for _,pn in ipairs(sl[2]) do
                                local part=src:FindFirstChild(pn)
                                if part and part:IsA("BasePart") then part:Clone().Parent=model end
                            end
                        end
                    end
                end
                return model
            end
            local function wearCustom()
                if #names==0 then Hub:Notify("No mascots found in this game","warn"); return end
                local m=build()
                if suitUp(m,"Mascots") then
                    local lbl={}
                    for i,sl in ipairs(SLOTS) do lbl[#lbl+1]=sl[1]..": "..tostring(names[pick[i]]) end
                    st.wornName["Mascots"]="Custom ("..table.concat(lbl,", ")..")"
                    pcall(refreshAll,true)
                end
            end
            for i,sl in ipairs(SLOTS) do
                local upd=cg:Status(sl[1],function() return names[pick[i]] or "none",Color3.fromRGB(110,230,140) end)
                updFns[#updFns+1]=upd
                cg:Button(sl[1].." : next mascot",function()
                    if #names==0 then return end
                    pick[i]=pick[i]%#names+1; upd()
                    if st.customOn then wearCustom() end
                end)
                cg:Divider()
            end
            cg:Button("Random mix",function()
                if #names==0 then return end
                for i=1,#SLOTS do pick[i]=math.random(1,#names) end
                for _,u in ipairs(updFns) do pcall(u) end
                st.customOn=true; wearCustom()
            end)
            cg:Button("Wear custom mascot",function() st.customOn=true; wearCustom() end,"primary")
            cg:Button("Take it off",function() st.customOn=false; pcall(takeOff,"Mascots"); pcall(refreshAll,true) end)
        end

        
        local wg=pg:Group("Wearing now")
        local wearRow=wg:_row(60)
        local wearHolder=New("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Parent=wearRow})
        local wearL=MkLbl({Text="",Font=F.R,TextSize=12,TextColor3=C.Sec,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
            TextTruncate=Enum.TextTruncate.None,Position=UDim2.fromOffset(0,10),Size=UDim2.new(1,0,1,-10),Parent=wearHolder})
        wg:Divider()
        wg:Button("Take off everything",function()
            for k in pairs(st.worn) do takeOff(k) end
            st.wornKey={}
            refreshAll()
        end)

        refreshAll=function(keepGrid)
            paintChips()
            if not keepGrid then buildGrid() end
            pageL.Text=string.format("%s   page %d of %d   %d items",CATS[st.ci],st.page,pages(),#st.list)
            local lines={}
            for _,c in ipairs(CATS) do
                if st.wornName[c] then lines[#lines+1]=c..":  "..st.wornName[c] end
            end
            wearL.Text=#lines>0 and table.concat(lines,"\n") or "Nothing on yet. Click an item above to wear it, click it again to take it off."
            wearRow.Size=UDim2.new(1,0,0,math.max(60,24+#lines*16))
        end
        Hub.Changed:Connect(function(id)
            if id=="cos.search" then buildList(); refreshAll()
            elseif id=="cos.flip" and st.worn["Mascots"] and st.mascotItem then
                local it=st.mascotItem
                task.defer(function() pcall(suitUp,it,"Mascots"); pcall(refreshAll,true) end)
            end
        end)
        
        
        task.spawn(function()
            while Hub.alive and not pg.cg.Visible do task.wait(0.4) end
            if Hub.alive then task.wait(0.25); pcall(function() buildList(); refreshAll() end) end
        end)
        track({Disconnect=function() for k in pairs(st.worn) do pcall(takeOff,k) end end})
    end)()
end


do
    local pg=newPage("Settings","Settings","Interface and behaviour.")
    local a=pg:Group("Interface")
    a:Keybind("Menu key","ui.menuKey","RightShift","Shows and hides this window.")
    a:Divider()
    a:Toggle("Notifications","ui.notifs",true,"Small pop-ups for releases and status.")
    a:Divider()
    a:Toggle("Animations","ui.animations",true,"Turn off for instant transitions.")
    a:Divider()
    a:Slider("Interface scale","ui.scale",0.75,1.25,1,2,"x","Resizes the whole window.")
    local b=pg:Group("General")
    b:Toggle("Anti-AFK","extras.antiAfk",true,"Prevents idle kicks.")
    b:Divider()
    b:Toggle("FPS unlocker","extras.fps",false,"Raises the FPS cap to 240.")
    b:Divider()
    b:Toggle("Auto-save settings","ui.autoSave",true,"Saves changes shortly after you make them.")
    local r=pg:Group("Re-run after teleport")
    r:Toggle("Re-run after teleport","settings.rerunOnTeleport",true,"Brings the menu back in the next server.")
    
    local SUPPORT_INVITE="https://discord.gg/mxGZt84yN3"                 
    local UPDATE_URL=""                     
    local CHANGELOG={
        "7.4  Real man-to-man guard, smarter shot selection, contest-aware Auto Time, diagnostics, settings search"
        ,"7.0  Play styles, takeover manager, highlight cam, stealth tools, license key",
        "6.9  New cosmetics browser, matchup radar fix, avatar in the menu",
        "6.8  Fine timing for Auto Time, shot journal",
    }
    local function textRow(g,h)
        local row=g:_row(h)
        return MkLbl({Text="",Font=F.Mono,TextSize=11,TextColor3=C.Sec,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,
            TextYAlignment=Enum.TextYAlignment.Top,Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-10),Parent=row})
    end
    local function clip(txt,okMsg,file)
        if type(setclipboard)=="function" and pcall(setclipboard,txt) then Hub:Notify(okMsg,"success"); return true end
        if file and type(writefile)=="function" and pcall(writefile,file,txt) then Hub:Notify("No clipboard here: saved to "..file,"info"); return true end
        Hub:Notify("Could not copy","error"); return false
    end
    local function verNum(v)
        local t={}
        for n in tostring(v):gmatch("%d+") do t[#t+1]=tonumber(n) end
        return t
    end
    local function newer(a,b)               
        local x,y=verNum(a),verNum(b)
        for i=1,math.max(#x,#y) do
            local p,q=x[i] or 0,y[i] or 0
            if p~=q then return p>q end
        end
        return false
    end

    
    local lg=pg:Group("License")
    local licL=textRow(lg,84)
    local function licText()
        if LICENSED.key==nil then return "No license on this copy (developer build)." end
        local k=LICENSED.key
        local masked=#k>8 and (k:sub(1,4).."..."..k:sub(-4)) or "****"
        local left="unknown"
        local sub=LICENSED.info and LICENSED.info.subscriptions and LICENSED.info.subscriptions[1]
        local l0=sub and tonumber(sub.timeleft)
        if l0 then
            if l0>315360000 then left="lifetime"
            else
                local l=l0-(os.clock()-(LICENSED.at or os.clock()))
                if l<=0 then left="expired" else
                    left=string.format("%dd %02dh %02dm %02ds",math.floor(l/86400),math.floor(l%86400/3600),math.floor(l%3600/60),math.floor(l%60))
                end
            end
        end
        local h=tostring(LICENSED.hwid or "?")
        return "Key        "..masked.."\nTime left  "..left.."\nDevice ID  "..h:sub(1,18)..(#h>18 and "..." or "").."\nPlan       "..tostring(sub and sub.subscription or "?")
    end
    task.spawn(function()
        while Hub.alive do licL.Text=licText(); task.wait(1) end
    end)
    lg:Divider()
    lg:Button("Copy device ID",function()
        if LICENSED.hwid then clip(tostring(LICENSED.hwid),"Device ID copied (send it to support to reset your key)") else Hub:Notify("No license on this copy","info") end
    end)
    lg:Divider()
    lg:Button("Change key",function()
        pcall(function() if writefile then writefile("TRAPPED_key.txt","") end end)
        Hub:Notify("Saved key removed. Run the script again to enter a new one.","warn")
    end)

    
    local PRESETS={
        {name="Legit",info="Looks like a good human player. Only Auto Time plus light help, with random timing, safety nets on and the menu kept quiet.",
            style="All off",
            set={["shoot.perfect"]=true,["shoot.variance"]=false,["shoot.fine"]=true,["play.legit"]=true,
                ["play.rebound"]=true,["play.sprint"]=true,["play.autoFT"]=true,
                ["safe.ping"]=true,["safe.pingMax"]=140,["safe.foul"]=true,["safe.foulMax"]=3,["safe.stamina"]=true,["safe.staminaMin"]=25,
                ["stealth.quiet"]=true,["stealth.autohide"]=true,["pro.tkAuto"]=false,["pro.hl"]=false}},
        {name="Semi-legit",info="Plays both ends but at a human pace: guard, block, rebound and free throws, with random timing and foul protection. No auto shooting or driving.",
            style="All off",
            set={["shoot.perfect"]=true,["shoot.variance"]=false,["shoot.fine"]=true,["play.legit"]=true,
                ["play.guard"]=true,["play.follow"]=true,["play.block"]=true,["play.rebound"]=true,["play.autoFT"]=true,["play.sprint"]=true,
                ["play.guardRange"]=10,["play.blockRange"]=12,
                ["safe.ping"]=true,["safe.pingMax"]=160,["safe.foul"]=true,["safe.foulMax"]=4,["safe.stamina"]=true,["safe.staminaMin"]=20,
                ["stealth.quiet"]=false,["stealth.autohide"]=true,["pro.tkAlert"]=true,["pro.tkAuto"]=false}},
        {name="Blatant",info="Everything on, no random delays, no safety limits, plus an emote after every make. Fastest and strongest, and the most obvious to anyone watching.",
            style="Full auto",
            set={["shoot.perfect"]=true,["shoot.variance"]=false,["shoot.fine"]=true,["play.legit"]=false,
                ["play.shotRange"]=32,["play.openDist"]=5,["play.passTrigger"]=4,
                ["safe.ping"]=false,["safe.foul"]=false,["safe.stamina"]=false,
                ["stealth.quiet"]=false,["pro.tkAlert"]=true,["pro.tkAuto"]=true,["pro.hl"]=true,["flow.emote"]=true}},
    }
    local cp=pg:Group("Config presets")
    local cpL=textRow(cp,62)
    local function showPreset()
        local n=State["cfg.preset"]
        for _,pr in ipairs(PRESETS) do if pr.name==n then cpL.Text="Active: "..pr.name.."\n"..pr.info; return end end
        cpL.Text="Pick a preset. Each one sets Auto Time, Auto Play and the safety options in one tap. You can still change anything after."
    end
    local pendingPreset,pendingAt,undoSnap=nil,0,nil
    for i,pr in ipairs(PRESETS) do
        cp:Divider()
        cp:Button("Apply "..pr.name.." config",function()
            local n=0
            for k,v in pairs(pr.set) do if State[k]~=v then n=n+1 end end
            if pendingPreset~=pr.name or os.clock()-pendingAt>6 then
                pendingPreset,pendingAt=pr.name,os.clock()
                Hub:Notify(pr.name..": changes "..n.." settings. Tap again within 6 seconds to apply.","info")
                return
            end
            pendingPreset=nil
            undoSnap={}
            for k in pairs(pr.set) do undoSnap[k]=State[k] end
            undoSnap["cfg.preset"]=State["cfg.preset"]
            if Hub.ApplyStyle then Hub.ApplyStyle(pr.style) end
            for k,v in pairs(pr.set) do Hub:Set(k,v) end
            Hub:Set("cfg.preset",pr.name)
            showPreset()
            Hub:Notify(pr.name.." config applied. \"Undo last preset\" puts your old settings back.","success")
        end,pr.name=="Legit" and "primary" or nil)
    end
    cp:Divider()
    cp:Button("Undo last preset",function()
        if not undoSnap then Hub:Notify("No preset to undo","info"); return end
        for k,v in pairs(undoSnap) do if v~=nil then Hub:Set(k,v) end end
        undoSnap=nil
        showPreset()
        Hub:Notify("Previous settings restored","success")
    end)
    showPreset()

    
    local pf=pg:Group("Profiles")
    local function snapshot()
        local t={}
        for k,v in pairs(State) do
            if type(k)=="string" and not k:match("^shoot%.fine") and not k:match("^scout%.") and not k:match("^cfg%.")
               and not k:match("^ui%.pos") and k~="shoot.holdAuto" and k~="prof.import"
               and (type(v)=="boolean" or type(v)=="number" or type(v)=="string") then t[k]=v end
        end
        return t
    end
    local function applySnap(t)
        local n=0
        for k,v in pairs(t) do
            if type(k)=="string" and not k:match("^cfg%.") and not k:match("^ui%.pos") then Hub:Set(k,v); n=n+1 end
        end
        return n
    end
    for i=1,3 do
        local file="TRAPPED_profile_"..i..".json"
        pf:Button("Save to profile "..i,function()
            local ok=pcall(function() writefile(file,HttpService:JSONEncode(snapshot())) end)
            Hub:Notify(ok and ("Saved profile "..i) or "Could not save profile","info")
        end)
        pf:Divider()
        pf:Button("Load profile "..i,function()
            local ok,t=pcall(function() return HttpService:JSONDecode(readfile(file)) end)
            if ok and type(t)=="table" then Hub:Notify("Loaded profile "..i.." ("..applySnap(t).." settings)","success")
            else Hub:Notify("Profile "..i.." is empty","warn") end
        end)
        pf:Divider()
    end
    pf:Button("Copy settings as text (share)",function() clip(HttpService:JSONEncode(snapshot()),"Settings copied. Send it to anyone.","TRAPPED_export.txt") end)
    pf:Divider()
    pf:Input("Import settings","prof.import","paste the text here","Paste a settings text from a friend, then press the button below.")
    pf:Divider()
    pf:Button("Import pasted settings",function()
        local ok,t=pcall(function() return HttpService:JSONDecode(tostring(State["prof.import"] or "")) end)
        if ok and type(t)=="table" then Hub:Notify("Imported "..applySnap(t).." settings","success")
        else Hub:Notify("That text is not a settings export","error") end
    end)
    pf:Divider()
    pf:Button("Reset everything to defaults",function()
        local n=0
        for id,def in pairs(Hub._defs or {}) do
            if not tostring(id):match("^ui%.pos") and not tostring(id):match("^cfg%.") then Hub:Set(id,DC(def)); n=n+1 end
        end
        for k in pairs(State) do
            if type(k)=="string" and (k:match("^shoot%.fine") or k:match("^scout%.")) then State[k]=nil end
        end
        Hub:Notify("Reset "..n.." settings to defaults","success")
    end)

    
    local hk=pg:Group("Hotkeys")
    hk:Keybind("Toggle Auto Time","hk.green","None","One key to switch Auto Time on and off.")
    hk:Divider()
    hk:Keybind("Toggle Full auto","hk.full","None","Switches the Full auto play style on, or everything off.")
    hk:Divider()
    hk:Keybind("Toggle Quiet mode","hk.quiet","None","Turns Quiet mode on and off.")
    track(UIS.InputBegan:Connect(function(inp)
        if UIS:GetFocusedTextBox() or inp.UserInputType~=Enum.UserInputType.Keyboard then return end
        local n=inp.KeyCode.Name
        if n==State["hk.green"] then
            Hub:Set("shoot.perfect",not (State["shoot.perfect"]==true))
            Hub:Notify("Auto Time "..(State["shoot.perfect"]==true and "on" or "off"),"info")
        elseif n==State["hk.full"] then
            local want=(State["pro.style"]=="Full auto") and "All off" or "Full auto"
            if Hub.ApplyStyle then Hub.ApplyStyle(want) end
        elseif n==State["hk.quiet"] then
            Hub:Set("stealth.quiet",not (State["stealth.quiet"]==true))
            Hub:Notify("Quiet mode "..(State["stealth.quiet"]==true and "on" or "off"),"info")
        end
    end))

    
    local lf=pg:Group("Look and feel")
    lf:Slider("Menu opacity","ui.opacity",50,100,100,0,"%","How see-through the window is.")
    lf:Divider()
    lf:Toggle("Performance mode","ui.perf",false,"Turns off animations and the live radar for weaker PCs.")
    lf:Divider()
    lf:Toggle("Stream mode","ui.stream",false,"Hides your avatar and the license countdown in the menu, and hides TRAPPED's pop-up notifications (errors still show), for recording or streaming.")
    lf:Divider()
    lf:Keybind("Stream mode key","ui.streamKey","None","Press this key in the game to switch stream mode on or off.")
    lf:Divider()
    lf:Button("Reset menu position",function()
        Hub:Set("ui.posX",0); Hub:Set("ui.posY",0)
        root.Position=UDim2.new(0.5,0,0.5,0)
        Hub:Notify("Menu centred","info")
    end)
    local function applyLook()
        local op=tonumber(State["ui.opacity"]) or 100
        pcall(function() win.BackgroundTransparency=(100-op)/100*0.7 end)
        pcall(function() sidebar.BackgroundTransparency=0.15+(100-op)/100*0.5 end)
        local stream=State["ui.stream"]==true
        pcall(function()
            local pill=win:FindFirstChild("LicPill"); if pill then pill.Visible=not stream end
            for _,d in ipairs(logo:GetChildren()) do if d:IsA("ImageLabel") then d.Visible=not stream end end
            logoT.Visible=stream
        end)
    end
    track(UIS.InputBegan:Connect(function(i)
        if UIS:GetFocusedTextBox() then return end
        local k=State["ui.streamKey"]
        if k and k~="None" and i.KeyCode.Name==k then Hub:Set("ui.stream",State["ui.stream"]~=true) end
    end))
    Hub.Changed:Connect(function(id,v)
        if id=="ui.opacity" or id=="ui.stream" then applyLook()
        elseif id=="ui.perf" then
            if v then
                Hub._perfPrev={anim=State["ui.animations"],radar=State["scout.radar"]}
                Hub:Set("ui.animations",false); Hub:Set("scout.radar",false)
            else
                local p=Hub._perfPrev or {}
                Hub:Set("ui.animations",p.anim~=false); Hub:Set("scout.radar",p.radar~=false)
            end
        end
    end)
    task.delay(1.5,applyLook)

    
    if SUPPORT_INVITE~="" then
        local sp=pg:Group("Support")
        sp:Button("Copy Discord invite",function() clip(SUPPORT_INVITE,"Invite copied") end)
    end

    local c=pg:Group("Session")
    c:Button("Rejoin server",function()
        Hub:Notify("Rejoining...","warn")
        task.delay(0.5,function() pcall(function() TeleportService:Teleport(game.PlaceId,LP) end) end)
    end)
    c:Divider()

    c:Button("Unload TRAPPED",function()
        Hub:Notify("Unloading...","warn")
        task.delay(0.35,function() Hub:UnloadForGood() end)
    end,"primary")

    
    do
        local box=New("TextBox",{LayoutOrder=0,Size=UDim2.new(1,0,0,36),BackgroundColor3=C.Bg3,BorderSizePixel=0,Text="",
            PlaceholderText="Search settings",PlaceholderColor3=C.Dim,TextColor3=C.Txt,Font=F.R,TextSize=13,ClearTextOnFocus=false,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=pg.list})
        Corner(box,10); Stroke(box,C.Line,1,0); Pad(box,12,12,0,0)
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local q=box.Text:lower():gsub("^%s+",""):gsub("%s+$","")
            local kids={}
            for _,ch in ipairs(pg.list:GetChildren()) do
                if ch~=box and ch:IsA("GuiObject") then kids[#kids+1]=ch end
            end
            table.sort(kids,function(x,y) return x.LayoutOrder<y.LayoutOrder end)
            for i=1,#kids-1,2 do
                local lab,card=kids[i],kids[i+1]
                local hit=(q=="")
                if not hit then
                    if lab:IsA("TextLabel") and lab.Text:lower():find(q,1,true) then hit=true end
                    for _,d in ipairs(card:GetDescendants()) do
                        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:lower():find(q,1,true) then hit=true; break end
                    end
                end
                lab.Visible=hit; card.Visible=hit
            end
        end)
    end
end

end) 


local menuTok=0
function Hub:ToggleMenu(force)
    local show=force
    if show==nil then show=not root.Visible end
    menuTok=menuTok+1
    local tok=menuTok
    if show then
        root.Visible=true
        setAmbient(true)
        local s=finalScale()
        if State["ui.animations"]==false then
            uiScale.Scale=s; win.GroupTransparency=0
        else
            uiScale.Scale=s*0.95; win.GroupTransparency=1
            P(uiScale,{Scale=s},0.45)
            P(win,{GroupTransparency=0},0.35)
        end
    else
        P(uiScale,{Scale=finalScale()*0.97},0.25)
        P(win,{GroupTransparency=1},0.22)
        task.delay(dur(0.25),function()
            if tok==menuTok then root.Visible=false; setAmbient(false) end
        end)
    end
end

dragHandle.InputBegan:Connect(function(inp)
    if not IsPri(inp.UserInputType) then return end
    local vp=vpSize()
    local ox=(0.5*vp.X+root.Position.X.Offset)-MP().X
    local oy=(0.5*vp.Y+root.Position.Y.Offset)-MP().Y
    bDrag(function(inp2)
        
        local pos=(inp2.UserInputType==Enum.UserInputType.MouseMovement) and MP()
            or (Vector2.new(inp2.Position.X,inp2.Position.Y)+game:GetService("GuiService"):GetGuiInset())
        local nx=pos.X+ox-0.5*vp.X
        local ny=pos.Y+oy-0.5*vp.Y
        local sc=uiScale.Scale
        local hw,hh=W*sc/2,H*sc/2
        nx=math.clamp(nx,hw-0.5*vp.X,vp.X-hw-0.5*vp.X)
        ny=math.clamp(ny,hh-0.5*vp.Y,vp.Y-hh-0.5*vp.Y)
        root.Position=UDim2.new(0.5,nx,0.5,ny)
    end,function()
        Hub:Set("ui.posX",root.Position.X.Offset)
        Hub:Set("ui.posY",root.Position.Y.Offset)
    end)
end)
btnHide.MouseButton1Click:Connect(function() Hub:ToggleMenu(false) end)
btnClose.MouseButton1Click:Connect(function() Hub:UnloadForGood() end)

pcall(function()
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if root.Visible then uiScale.Scale=finalScale() end
    end))
end)

track(UIS.InputBegan:Connect(function(inp)
    if capturing then capturing(inp); return end
    if UIS:GetFocusedTextBox() then return end
    if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
    local mk=State["ui.menuKey"]
    if mk and inp.KeyCode.Name==mk then Hub:ToggleMenu() end
end))

Hub.Changed:Connect(function(id,v)
    if id=="ui.scale" then
        if root.Visible then P(uiScale,{Scale=finalScale()},0.25) end
    elseif id=="ui.animations" then
        setAmbient(root.Visible)
    elseif id=="extras.fps" then
        pcall(function() if type(setfpscap)=="function" then setfpscap(v and 240 or 60) end end)
    end
    if type(id)=="string" then Hub:QueueSave() end
end)


local VU=game:GetService("VirtualUser")
track(LP.Idled:Connect(function()
    if State["extras.antiAfk"]==false then return end
    pcall(function()
        local cf=workspace.CurrentCamera and workspace.CurrentCamera.CFrame
        VU:Button2Down(Vector2.new(0,0),cf)
        task.wait(0.1)
        VU:Button2Up(Vector2.new(0,0),cf)
    end)
end))


local VK={E=0x45,R=0x52,F=0x46,Q=0x51,Space=0x20}
local KEYCODE_TO_VK={
    E=VK.E,R=VK.R,F=VK.F,Q=VK.Q,Space=VK.Space,
    G=0x47,T=0x54,V=0x56,B=0x42,N=0x4E,M=0x4D,Z=0x5A,X=0x58,C=0x43,
    One=0x31,Two=0x32,Three=0x33,Four=0x34,
}


do




local CAS=game:GetService("ContextActionService")


local LEAD_BASE=0.000


local agLog={}
local agLogT0=os.clock()
local function alog(...)
    local n=select("#",...)
    local parts={}
    for i=1,n do parts[i]=tostring((select(i,...))) end
    local s=string.format("[%8.3f] ",os.clock()-agLogT0)..table.concat(parts," ")
    agLog[#agLog+1]=s
    if #agLog>900 then table.remove(agLog,1) end
    if State["shoot.debug"]==true then print("[AG3]",s) end
end

local function agSafe(name,fn)
    return function(...)
        local ok,err=pcall(fn,...)
        if not ok then alog("ERROR in "..name..": "..tostring(err)) end
    end
end

local CAPS={"keyrelease","keypress","firesignal","getconnections","hookmetamethod",
    "getnamecallmethod","checkcaller","newcclosure","writefile","setclipboard"}
local function capLine()
    local t={}
    for _,n in ipairs(CAPS) do
        local f
        pcall(function() f=getfenv()[n] end)
        if f==nil and type(getgenv)=="function" then f=getgenv()[n] end
        t[#t+1]=n.."="..((type(f)=="function") and "Y" or "n")
    end
    local vim=pcall(function() return game:GetService("VirtualInputManager") end)
    t[#t+1]="VIM="..(vim and "Y" or "n")
    local pads="?"
    pcall(function() pads=tostring(#UIS:GetConnectedGamepads()) end)
    t[#t+1]="gamepads="..pads
    return table.concat(t," ")
end
local function agDump()
    local head={
        "TRAPPED AG LOG  v"..Hub.Version.."  "..os.date("%Y-%m-%d %H:%M:%S"),
        "caps: "..capLine(),
        string.format("settings: greenAt=%s delay=%s variance=%s key=%s holdAuto=%s trim=%s padTrim=%s perfect=%s",
            tostring(State["shoot.greenAt"]),tostring(State["shoot.delay"]),tostring(State["shoot.variance"]),
            tostring(State["shoot.key"]),tostring(State["shoot.holdAuto"]),
            tostring(State["shoot.trim"]),tostring(State["shoot.padTrim"]),tostring(State["shoot.perfect"])),
        "character: "..(myChar() and myChar():GetFullName() or "NIL"),
        "-----",
    }
    return table.concat(head,"\n").."\n"..table.concat(agLog,"\n")
end
_G.__TRAPPED_AGLOG_COPY=function()
    local ok=false
    if type(setclipboard)=="function" then ok=pcall(setclipboard,agDump()) end
    Hub:Notify(ok and "Log copied to clipboard" or "No clipboard API available",ok and "success" or "warn")
end
_G.__TRAPPED_AGLOG_SAVE=function()
    local ok=false
    if type(writefile)=="function" then ok=pcall(writefile,"TRAPPED_ag_log.txt",agDump()) end
    if not ok then Hub:Notify("Could not save log","error") end
end


local function readSeq(g)
    local kp=g.Transparency.Keypoints
    local ts,vs={},{}
    for i=1,#kp do
        local k=kp[i]
        ts[i]=k.Time; vs[i]=k.Value
    end
    return ts,vs
end
local function evalArr(ts,vs,t)
    local n=#ts
    if t<=ts[1] then return vs[1] end
    for i=2,n do
        local ti=ts[i]
        if t<=ti then
            local t0=ts[i-1]
            local d=ti-t0
            if d<=1e-6 then return vs[i] end
            return vs[i-1]+(vs[i]-vs[i-1])*(t-t0)/d
        end
    end
    return vs[n]
end
local VIS_STEPS=200
local function visFrac(ts,vs,o,sign)
    local n,cnt=VIS_STEPS,0
    for i=0,n-1 do
        local t=(i+0.5)/n+sign*o
        if t<0 then t=0 elseif t>1 then t=1 end
        if evalArr(ts,vs,t)<0.5 then cnt=cnt+1 end
    end
    return cnt/n
end
local function offAxis(g)
    local r=g.Rotation%180
    return (math.abs(r-90)<45) and g.Offset.Y or g.Offset.X
end

local meters={}
local function scanMeters()
    local list={}
    local ch=myChar()
    if ch then
        for _,d in ipairs(ch:GetDescendants()) do
            if d.Name=="Meter_Fill" and d:IsA("GuiObject") then
                local g=d:FindFirstChildOfClass("UIGradient")
                local bb=d:FindFirstAncestorWhichIsA("BillboardGui") or d:FindFirstAncestorWhichIsA("SurfaceGui")
                if g and bb then list[#list+1]={fill=d,grad=g,gui=bb} end
            end
        end
    end
    meters=list
end



local AG={Held=nil,T0=0,Fired=false,Shot=0,StartO={},Min={},Convs={},LastF=nil,LastT=nil,Vel=0,Peak=0,Still=nil,
    MeterSeen=false,LastScan=0,Warned=false,LastRelAt=0,LastHoldMs=0,Ctx="?",RelCtx="?",RelFrac=0,FbDone=-1,
    IsLayup=false,Hist={},FMax={},FullMode=false,RelSendAt=-10,LastRelKind=nil,BridgeUntil=0,KeyLock=false,LastBeginT=-10,LastManual=nil}

local function agEnabled() return State["shoot.perfect"]==true and State["shoot.watch"]~=true end

local function pingSec()
    local ms=0
    pcall(function() ms=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return (tonumber(ms) or 0)/1000
end


local spoofUntil,spoofCode,spoofInput=0,nil,nil

local padKeyAt,padKeyV=-99,Enum.KeyCode.ButtonX
function AG.padKey()
    if os.clock()-padKeyAt<3 then return padKeyV end
    padKeyAt=os.clock()
    pcall(function()
        local fw=Hub.Framework and Hub.Framework()
        local pc=fw and fw.Controllers and fw.Controllers.Player
        local shared=(fw and fw.Shared) or (pc and pc.Shared)
        local inputs=pc and pc.ProfileData and pc.ProfileData.SavedSettings and pc.ProfileData.SavedSettings.Inputs
        local binds=shared and shared.Binds and shared.Binds:GetMap("Gamepad",inputs)
        local n=binds and binds.Shoot
        if type(n)=="string" and n~="None" and Enum.KeyCode[n] then
            if padKeyV~=Enum.KeyCode[n] then alog("controller shoot button: "..n) end
            padKeyV=Enum.KeyCode[n]
        end
    end)
    return padKeyV
end

local jumpAt,jumpKb,jumpPad=-99,"Space",Enum.KeyCode.ButtonY
function AG.jumpKeys()
    if os.clock()-jumpAt<3 then return jumpKb,jumpPad end
    jumpAt=os.clock()
    pcall(function()
        local fw=Hub.Framework and Hub.Framework()
        local pc=fw and fw.Controllers and fw.Controllers.Player
        local shared=(fw and fw.Shared) or (pc and pc.Shared)
        local inputs=pc and pc.ProfileData and pc.ProfileData.SavedSettings and pc.ProfileData.SavedSettings.Inputs
        local kb=shared and shared.Binds and shared.Binds:GetMap("Keyboard",inputs)
        local gp=shared and shared.Binds and shared.Binds:GetMap("Gamepad",inputs)
        if kb and type(kb.Jump)=="string" and kb.Jump~="None" then jumpKb=kb.Jump end
        local n=gp and (gp.JumpClutch or gp.Jump)
        if type(n)=="string" and n~="None" and Enum.KeyCode[n] then jumpPad=Enum.KeyCode[n] end
    end)
    return jumpKb,jumpPad
end

local function fireShootFalse()
    local ok=false
    pcall(function()
        local fw=Hub.Framework and Hub.Framework()
        local w=fw and fw.Services and fw.Services.InputService and fw.Services.InputService.Shoot
        if type(w)=="table" and type(w.Fire)=="function" then w:Fire({Shoot=false}); ok=true end
    end)
    if not ok then
        ok=pcall(function()
            game:GetService("ReplicatedStorage").Aero.AeroRemoteServices.InputService.Shoot:FireServer({Shoot=false})
        end)
    end
    return ok,"remote"
end
local fakeEnd
local spoofHits={btn=0,state=0,idx=0}
local BRIDGE_DELAY=0.03
local padConnLogged=false
local ENDSTATE=Enum.UserInputState.End
local padHook=0
local padOwner={}
local function hookShared()
    local g=(type(getgenv)=="function") and getgenv() or _G
    g.__TRAPPED_HOOKS=g.__TRAPPED_HOOKS or {}
    return g.__TRAPPED_HOOKS
end
function Hub.PadHook() return padHook end
local function installPadHook()
    if padHook~=0 then return padHook==1 end
    if type(hookmetamethod)~="function" or type(getnamecallmethod)~="function" then
        padHook=-1; alog("pad hook: hookmetamethod/getnamecallmethod missing"); return false
    end
    
    
    
    local SH=hookShared()
    local old,oldIdx
    local ok,err=pcall(function()
        local inWatchLog=false
        local h=function(self,...)
            local nm0=getnamecallmethod()
            if State["play.glide"]==true and Hub.GlideKey and nm0=="FireServer" then
                local k1,d1=...
                pcall(function()
                    if typeof(self)=="Instance" and self.Name=="Dribble" and self.Parent and self.Parent.Name=="InputService"
                        and not (type(checkcaller)=="function" and checkcaller()) then Hub.GlideKey(k1,d1) end
                end)
                if setnamecallmethod then pcall(setnamecallmethod,nm0) end
            end
            if (State["shoot.watch"]==true or (State["dev.trace"]==true and Hub.dev==true)) and not inWatchLog then
                inWatchLog=true
                local m0=nm0
                local args=table.pack(...)
                pcall(function()
                    if m0=="FireServer" and typeof(self)=="Instance" then
                        local par=self.Parent and self.Parent.Name
                        if (par=="InputService" or par=="MeterService") and self.Name~="MoveDirection" then
                            Hub.WatchRemote(par.."."..self.Name,args)
                        end
                    end
                end)
                inWatchLog=false
                
                if setnamecallmethod then pcall(setnamecallmethod,nm0) end
            end
            if State["play.alwaysDunk"]==true and State["shoot.watch"]~=true and Hub.HoopDist then
                local a1=(...)
                local ok2,res=pcall(function()
                    if getnamecallmethod()~="FireServer" or typeof(self)~="Instance" or self.Name~="Shoot" then return nil end
                    if not (self.Parent and self.Parent.Name=="InputService") then return nil end
                    if type(checkcaller)=="function" and checkcaller() then return nil end
                    if type(a1)~="table" or a1.Shoot~=true or a1.UseSpace==true then return nil end
                    local gd,spd,ball,mv=Hub.HoopDist()
                    local rng=tonumber(State["play.dunkRange"]) or 14
                    local why
                    if not gd then why="no hoop found"
                    elseif ball==nil or ball==false then why="no ball"
                    elseif gd>rng then why=string.format("%.1f studs from the hoop (range %.0f)",gd,rng)
                    elseif spd<3 and mv<0.1 then why="not moving" end
                    if why then
                        if os.clock()-(Hub._dunkWhyAt or 0)>2 then Hub._dunkWhyAt=os.clock(); bootLog("always dunk: not used ("..why..")") end
                        return nil
                    end
                    return {Shoot=true,UseSpace=true,Input=a1.Input or "E"}
                end)
                if not ok2 and os.clock()-(Hub._dunkErrAt or 0)>2 then Hub._dunkErrAt=os.clock(); bootLog("always dunk: error "..tostring(res)) end
                if setnamecallmethod then pcall(setnamecallmethod,nm0) end
                if ok2 and res then
                    local jump=self.Parent:FindFirstChild("Jump")
                    task.defer(function() if jump then pcall(function() jump:FireServer() end) end end)
                    bootLog("always dunk: shot turned into a dunk request")
                    if setnamecallmethod then pcall(setnamecallmethod,nm0) end
                    return old(self,res)
                end
            end
            if spoofUntil>os.clock() and self==UIS then
                local m=getnamecallmethod()
                if m=="IsGamepadButtonDown" then
                    local _,b=...
                    if b==spoofCode and not (type(checkcaller)=="function" and checkcaller()) then
                        spoofHits.btn=spoofHits.btn+1
                        return false
                    end
                elseif m=="GetGamepadState" and not (type(checkcaller)=="function" and checkcaller()) then
                    local res=old(self,...)
                    if type(res)=="table" then
                        local out={}
                        for i,v in ipairs(res) do
                            local okk,kc=pcall(function() return v.KeyCode end)
                            out[i]=(okk and kc==spoofCode) and fakeEnd(v) or v
                        end
                        spoofHits.state=spoofHits.state+1
                        return out
                    end
                    return res
                end
            end
            return old(self,...)
        end
        local hi=function(self,k)
                if self==spoofInput and spoofInput~=nil and k=="UserInputState"
                    and spoofUntil>os.clock() and not (type(checkcaller)=="function" and checkcaller()) then
                    spoofHits.idx=spoofHits.idx+1
                    return ENDSTATE
                end
            return oldIdx(self,k)
        end
        if SH.nsOrig then
            old=SH.nsOrig; oldIdx=SH.ixOrig
            alog("pad hook: reusing the existing hook layer")
        else
            local tn=function(self,...)
                local f=SH.ns
                if f then return f(self,...) end
                return SH.nsOrig(self,...)
            end
            if type(newcclosure)=="function" then tn=newcclosure(tn) end
            SH.nsOrig=hookmetamethod(game,"__namecall",tn)
            old=SH.nsOrig
            pcall(function()
                local ti=function(self,k)
                    local f=SH.ix
                    if f then return f(self,k) end
                    return SH.ixOrig(self,k)
                end
                if type(newcclosure)=="function" then ti=newcclosure(ti) end
                SH.ixOrig=hookmetamethod(game,"__index",ti)
                alog("pad index hook installed")
            end)
            if SH.ixOrig==nil then
                
                SH.ixOrig=function(self,k) return self[k] end
            end
            oldIdx=SH.ixOrig
        end
        SH.ns=h; SH.ix=hi
        SH.owner=padOwner
    end)
    padHook=(ok and old~=nil) and 1 or -1
    alog("pad hook installed:",tostring(padHook==1),ok and "" or tostring(err))
    return padHook==1
end
task.spawn(function()
    while Hub.alive do
        task.wait(2)
        if (State["play.alwaysDunk"]==true or State["play.glide"]==true or (State["dev.trace"]==true and Hub.dev==true)) and padHook==0 then pcall(installPadHook) end
    end
end)
track({Disconnect=function()
    spoofUntil=0
    local ok2,SH=pcall(hookShared)
    if ok2 and SH.owner==padOwner then SH.ns=nil; SH.ix=nil; SH.owner=nil end
end})

function fakeEnd(inp)
    return setmetatable({
        UserInputState=Enum.UserInputState.End,
        KeyCode=inp.KeyCode, UserInputType=inp.UserInputType,
    },{__index=function(_,k)
        local ok,v=pcall(function() return inp[k] end)
        return ok and v or nil
    end})
end

local function sendPadRelease(h)
    local inp=h.input
    if not inp then alog("pad release: no input object"); return false,"no-input" end
    local how={}
    spoofUntil=os.clock()+0.6; spoofCode=inp.KeyCode; spoofInput=inp
    task.delay(0.7,function() if spoofUntil<=os.clock() then spoofInput=nil end end)
    if padHook==1 then how[#how+1]="spoof" end
    local f=fakeEnd(inp)
    local fired=false
    if type(firesignal)=="function" then
        if pcall(firesignal,UIS.InputEnded,f,false) then fired=true; how[#how+1]="firesignal" end
    end
    if not fired and type(getconnections)=="function" then
        local okc,cons=pcall(getconnections,UIS.InputEnded)
        if okc and cons then
            local n=0
            for _,c in ipairs(cons) do
                local fn=c.Function
                if type(fn)=="function" then
                    n=n+1
                    task.spawn(function() pcall(fn,f,false) end)
                end
            end
            if n>0 then fired=true; how[#how+1]="getconnections("..n..")" end
        end
    end
    pcall(function()
        local kcE=Enum.KeyCode[State["shoot.key"] or "E"]
        if not kcE then return end
        local fk=setmetatable({UserInputState=ENDSTATE,KeyCode=kcE,UserInputType=Enum.UserInputType.Keyboard},
            {__index=function(_,k) local ok,v=pcall(function() return inp[k] end) return ok and v or nil end})
        if type(firesignal)=="function" and pcall(firesignal,UIS.InputEnded,fk,false) then how[#how+1]="fakeKey" end
    end)
    pcall(function()
        if type(firesignal)~="function" then return end
        if pcall(firesignal,inp.Changed,"UserInputState") then how[#how+1]="changed" end
        local okS,sig=pcall(function() return inp:GetPropertyChangedSignal("UserInputState") end)
        if okS and sig and pcall(firesignal,sig) then how[#how+1]="propChanged" end
    end)
    
    if type(keypress)=="function" and type(keyrelease)=="function" then
        local label=State["shoot.key"] or "E"
        local vk=KEYCODE_TO_VK[label] or VK.E
        AG.BridgeUntil=os.clock()+0.5
        pcall(keypress,vk)
        task.delay(BRIDGE_DELAY,function() pcall(keyrelease,vk) end)
        how[#how+1]="kbBridge"
    end
    spoofHits.btn=0; spoofHits.state=0; spoofHits.idx=0
    task.delay(0.65,function()
        alog(string.format("spoof hits: IsGamepadButtonDown=%d GetGamepadState=%d UserInputState=%d",
            spoofHits.btn,spoofHits.state,spoofHits.idx))
    end)
    if not padConnLogged and type(getconnections)=="function" then
        padConnLogged=true
        for _,sigName in ipairs({"InputBegan","InputEnded"}) do
            pcall(function()
                local cons=getconnections(UIS[sigName])
                local n=0
                for _,c in ipairs(cons) do
                    local fn=c.Function
                    if type(fn)=="function" then
                        n=n+1
                        if n<=30 then
                            local src="?"
                            pcall(function()
                                local sc=getfenv(fn).script
                                src=sc and sc:GetFullName() or "?"
                            end)
                            alog("conn "..sigName..": "..src)
                        end
                    end
                end
                alog(sigName.." connections: "..n)
            end)
        end
    end
    local casDone=false
    pcall(function()
        local info=CAS:GetAllBoundActionInfo()
        local want=Enum.KeyCode[State["shoot.key"] or "E"]
        local both,anyPad,allNames={},{},{}
        for name,ai in pairs(info) do
            if name~="TRAPPED_AGSINK" and type(ai)=="table" and type(ai.inputTypes)=="table" then
                local hasPad,hasKey=false,false
                local types={}
                for _,it in ipairs(ai.inputTypes) do
                    types[#types+1]=tostring(it)
                    if it==AG.padKey() or tostring(it):find(AG.padKey().Name,1,true) then hasPad=true end
                    if want and it==want then hasKey=true end
                end
                allNames[#allNames+1]=name.."["..table.concat(types,"/").."]"
                if hasPad then
                    anyPad[#anyPad+1]=name
                    if hasKey then both[#both+1]=name end
                end
            end
        end
        local use=(#both>0) and both or anyPad
        alog("CAS ButtonX actions: "..table.concat(anyPad,",").." | using: "..table.concat(use,","))
        if #anyPad==0 then alog("CAS all bound: "..table.concat(allNames,"; ")) end
        for _,name in ipairs(use) do
            local okc,err=pcall(function() CAS:CallFunction(name,ENDSTATE,inp) end)
            alog("CAS CallFunction "..name.." ok="..tostring(okc)..(okc and "" or (" err="..tostring(err))))
            if okc then casDone=true; how[#how+1]="cas("..name..")" end
        end
    end)
    return fired or padHook==1 or casDone, table.concat(how,"+")
end


local sinkTok=0
local function sinkBegins(kc,dur2)
    sinkTok=sinkTok+1
    local my=sinkTok
    pcall(function()
        CAS:BindActionAtPriority("TRAPPED_AGSINK",function(_,state)
            if state==Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
            return Enum.ContextActionResult.Pass
        end,false,Enum.ContextActionPriority.High.Value+500,kc)
    end)
    task.delay(dur2,function()
        if my==sinkTok then pcall(function() CAS:UnbindAction("TRAPPED_AGSINK") end) end
    end)
end

local function sendKeyRelease(h)
    local label=(h.label~="Square" and h.label) or State["shoot.key"] or "E"
    local vk=h.vk or KEYCODE_TO_VK[label] or VK.E
    local kc=Enum.KeyCode[label]
    local how={}
    AG.KeyLock=true
    if kc then sinkBegins(kc,0.45) end

    local function viaVIM()
        if not kc then return false end
        return (pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(false,kc,false,game)
        end))
    end

    local okK=false
    if type(keyrelease)=="function" then
        okK=(pcall(keyrelease,vk))
        if okK then how[#how+1]="keyrelease" end
    end
    if not okK then
        if viaVIM() then how[#how+1]="VIM" end
    else
        task.delay(0.06,function()
            local down=false
            pcall(function() down=kc~=nil and UIS:IsKeyDown(kc) end)
            if down and viaVIM() then alog("backup VIM release (Roblox still saw the key down)") end
        end)
    end
    return #how>0, table.concat(how,"+")
end

local function agSend()
    local h=AG.Held
    if not h then return false,"no-held" end
    AG.RelSendAt=os.clock()
    AG.LastRelKind=h.kind
    
    if h.jump then return fireShootFalse() end
    if h.kind=="pad" then return sendPadRelease(h) end
    return sendKeyRelease(h)
end

local MIN_HOLD_MS=250
local function learnHold(ms)
    if ms<MIN_HOLD_MS then alog("learnHold ignored (too short): "..math.floor(ms)); return end
    local old=tonumber(State["shoot.holdAuto"])
    local new=old and (old*0.5+ms*0.5) or ms
    Hub:Set("shoot.holdAuto",math.floor(new+0.5))
end






local AGL={relLag=0,relPing=0,relGreen="?"}
function AGL.C(ctx)
    local v=tonumber(State["shoot.fine."..ctx])
    if v then return v end
    
    
    local base,tier=ctx:match("^(.-)~c(%d)$")
    if base then return AGL.C(base)+(tier=="1" and -6 or -12) end
    
    
    local ss0=tonumber(ctx:match("|ss([%d%.]+)"))
    local kind=ctx:match(":(%a+)")
    if ss0 and kind then
        local lo,hi
        for k,v in pairs(State) do
            if type(k)=="string" and type(v)=="number" and k:sub(1,16)=="shoot.fine.good." then
                local c2=k:sub(17)
                if c2~=ctx and not c2:find("~c",1,true) and c2:match(":(%a+)")==kind and (c2:find(":full",1,true)~=nil)==(ctx:find(":full",1,true)~=nil)
                    and (c2:find(":pad",1,true)~=nil)==(ctx:find(":pad",1,true)~=nil)
                    and (c2:find(":jmp",1,true)~=nil)==(ctx:find(":jmp",1,true)~=nil) then
                    local s2=tonumber(c2:match("|ss([%d%.]+)"))
                    if s2 then
                        local d=s2-ss0
                        if d<=0 then if not lo or d>lo.d then lo={d=d,v=v} end
                        else if not hi or d<hi.d then hi={d=d,v=v} end end
                    end
                end
            end
        end
        if lo and hi and hi.d-lo.d>0 then
            local w=(-lo.d)/(hi.d-lo.d)
            return math.clamp(lo.v+(hi.v-lo.v)*w,-120,120)
        elseif lo or hi then
            local n=lo or hi
            if math.abs(n.d)<=0.4 then return math.clamp(n.v,-120,120) end
        end
    end
    
    if ctx:find(":full",1,true) then
        
        
        if ctx:find(":jmp",1,true) then return 6 end
        return ctx:find(":pad",1,true) and -math.floor(BRIDGE_DELAY*1000+0.5) or 0
    end
    
    
    local ss=tonumber(ctx:match("|ss([%d%.]+)"))
    if ss and ss>=1.7 and ss<1.95 then return 5 end
    if ss and ss>=1.35 and ss<1.55 then return -5 end
    return 0
end



function AGL.green()
    local out="?"
    pcall(function()
        local c=myChar()
        local mg=c and c:FindFirstChild("Meter_Green",true)
        local g=mg and mg:FindFirstChildWhichIsA("UIGradient",true)
        if not g then return end
        local ks={}
        for _,k in ipairs(g.Transparency.Keypoints) do ks[#ks+1]=string.format("%.3f:%.2f",k.Time,k.Value) end
        out=string.format("k=%s;off=%.2f/%.2f;rot=%d",table.concat(ks,"|"),g.Offset.X,g.Offset.Y,g.Rotation)
    end)
    return out
end
AGL.ct={at=0,tier=0}

function AGL.tier()
    if State["shoot.contestAware"]==false then return 0 end
    local now=os.clock()
    if now<AGL.ct.at then return AGL.ct.tier end
    AGL.ct.at=now+0.15
    local t=0
    pcall(function()
        local me=myChar()
        local mine=me and me:FindFirstChild("HumanoidRootPart")
        if not mine then return end
        H.nearestHandler(me,0.001)
        local nearest=math.huge
        for _,c in ipairs(H.near()) do
            local oh=c:FindFirstChild("HumanoidRootPart")
            if oh and H.opponent(me,c) then nearest=math.min(nearest,(oh.Position-mine.Position).Magnitude) end
        end
        t=nearest<=5 and 2 or (nearest<=9 and 1 or 0)
    end)
    AGL.ct.tier=t
    return t
end



function AGL.fracFor(ctx,bucket)
    local v=tonumber(State["shoot.frac."..ctx..":"..bucket]) or tonumber(State["shoot.frac."..ctx])
    return v or 0.25
end
function AGL.bucket()
    local gd
    pcall(function() if Hub.ShotContext then gd=Hub.ShotContext() end end)
    if not gd then return "m" end
    return gd>=23 and "3" or (gd>=13 and "m" or "c")
end
function AGL.ms(ctx)       
    if State["shoot.fine"]==false and not tostring(ctx):find(":full",1,true) then return 0 end
    return math.clamp(AGL.C(ctx),-120,120)
end

local function agRelease(frac,target,src,lagApplied)
    if AG.Fired then return end
    if State["safe.ping"]==true and pingSec()*1000>(tonumber(State["safe.pingMax"]) or 150) then
        AG.Fired=true                      
        if os.clock()-(Hub._pingWarnAt or 0)>3 then
            Hub._pingWarnAt=os.clock()
            Hub:Notify(string.format("Ping %.0f ms: Auto Time skipped this release",pingSec()*1000),"warn")
        end
        alog(string.format("ping-spike safe mode: release skipped (%.0f ms)",pingSec()*1000))
        return
    end
    AG.Fired=true
    AG.RelVel=AG.VelLock or AG.Vel
    AG.RelCtx=AG.Ctx; AG.RelFrac=tonumber(frac) or 0; AG.RelTarget=tonumber(target) or 0
    AG.RelWin=(AG.WinFor==AG.T0) and AG.Win or nil; AG.RelBucket=AG.WinBucket; AG.RelFr=nil
    AGL.relLag=lagApplied or AGL.ms(AG.Ctx); AGL.relPing=pingSec()*1000
    AGL.relGreen=AGL.green()
    Hub._relGd,Hub._relDef=nil,nil
    Hub._lastRelAt=os.clock()
    alog("release ctx="..AG.RelCtx)
    local d=(tonumber(State["shoot.delay"]) or 0)/1000
    if not lagApplied and src=="meter" and AGL.relLag>0 then d=d+AGL.relLag/1000 end
    task.spawn(agSafe("release",function()
        if d>0 then task.wait(d) end
        local ok,how=agSend()
        
        if Hub.ShotContext then task.defer(function() pcall(function() Hub._relGd,Hub._relDef=Hub.ShotContext() end) end) end
        AG.LastRelAt=os.clock()
        local holdMs=(os.clock()-AG.T0)*1000
        AG.LastHoldMs=holdMs
        alog(string.format("RELEASE src=%s frac=%.3f aim=%.3f hold=%.0fms via=%s ok=%s",
            src,frac,target,holdMs,tostring(how),tostring(ok)))
        if ok then
            Counters.greens=Counters.greens+1
            if src=="meter" and frac>=target-0.07 then learnHold(holdMs) end
            UI.frac=(src=="timer") and nil or frac
            uiStatus("released",(src=="timer") and 0 or frac,src)
            if src=="timer" then Hub:Notify("Auto Time (hold timer)","success")
            elseif src=="exact" then Hub:Notify(string.format("Auto Time  exact %.0f ms",holdMs),"success")
            else Hub:Notify(string.format("Auto Time  %.0f%%",frac*100),"success") end
        else
            uiStatus(agEnabled() and "idle" or "off")
            Hub:Notify("Auto Time: release failed ("..tostring(how)..")","error")
        end
        if State["shoot.debug"]==true then task.delay(1.5,function() if Hub.alive and _G.__TRAPPED_AGLOG_SAVE then _G.__TRAPPED_AGLOG_SAVE() end end) end
    end))
end

local function agTimerMs()
    local a=tonumber(State["shoot.holdAuto"])
    if a and a>=MIN_HOLD_MS then return a end
    return nil
end


local function agExact() return State["shoot.exact"]==true end
local function agExactMs(h)
    local isPad=(h~=nil and h.kind=="pad")
    local base=tonumber(State[isPad and "shoot.padHold" or "shoot.keyHold"]) or (isPad and 624 or 570)
    local trim=tonumber(State[isPad and "shoot.padTrim" or "shoot.trim"]) or 0
    local ms=base-trim                       
    if isPad then ms=ms-BRIDGE_DELAY*1000 end 
    return ms
end




local function agContext(style)
    local air=false
    pcall(function()
        local ch=myChar()
        if ch and (ch:GetAttribute("InAir")==true or (tonumber(ch:GetAttribute("DunkVertical")) or 0)>0 and ch:GetAttribute("Action")=="Dunk") then air=true end
        local hum=ch and ch:FindFirstChildOfClass("Humanoid")
        if hum and not air then
            local st=hum:GetState()
            air=(st==Enum.HumanoidStateType.Freefall or st==Enum.HumanoidStateType.Jumping
                or st==Enum.HumanoidStateType.Flying or hum.FloorMaterial==Enum.Material.Air)
        end
    end)
    
    
    local ss="?"
    pcall(function()
        local ch=myChar()
        local v=ch and tonumber(ch:GetAttribute("ShotSpeed"))
        if v then ss=string.format("%.2f",math.floor(v*20+0.5)/20) end
    end)
    
    
    local lay,dunk=false,false
    pcall(function()
        local ch=myChar()
        local a=ch and tostring(ch:GetAttribute("BaseAnimation") or ""):lower() or ""
        if a:find("layup",1,true) or a:find("dunk",1,true) or a:find("floater",1,true)
            or a:find("underrim",1,true) then lay=true end
        if a:find("dunk",1,true) or a:find("slam",1,true) then dunk=true end
    end)
    AG.IsLayup=lay
    local tr=AGL.tier()
    
    local bn=""
    pcall(function()
        local ch=myChar()
        local b=ch and tostring(ch:GetAttribute("BuildName") or "") or ""
        if b~="" then
            bn="@"..b:gsub("[^%w]",""):sub(1,12)
            if Hub._lastBuild~=bn then
                Hub._lastBuild=bn
                if State["build.auto"]==true and type(State["build.set."..bn])=="string" and State["build.set."..bn]~="" then
                    if Hub.BuildSwitched then pcall(Hub.BuildSwitched,bn,b) end
                else
                    Hub:Notify("Build detected: "..b..". Auto Time is learning its timing: the first few shots may be off.","info")
                end
            end
        end
    end)
    return tostring(style or "?").."|ss"..ss..(dunk and ":dunk" or (lay and ":layup" or (air and ":air" or ":ground")))..bn..(State["shoot.fullBar"]==true and ":full" or "")..((AG.Held and AG.Held.jump) and ":jmp" or ((AG.Held and AG.Held.kind=="pad") and ":pad" or ""))..(tr>0 and ("~c"..tr) or "")
end


local fbHooked=setmetatable({},{__mode="k"})
local function hookFeedback()
    local ch=myChar()
    local lbl=ch and ch:FindFirstChild("ReleaseTiming",true)
    if not lbl or fbHooked[lbl] or not lbl:IsA("TextLabel") then return end
    fbHooked[lbl]=true
    local fbFn=agSafe("feedback",function()
        local t=lbl.Text:lower()
        if t=="" then return end
        if (State["dev.trace"]==true and Hub.dev==true) then
            local ct
            pcall(function()
                local gui=lbl:FindFirstAncestorOfClass("BillboardGui")
                local c=gui and gui:FindFirstChild("Contest",true)
                ct=c and c.Text
            end)
            bootLog(string.format("trace %.3f: game feedback \"%s\" %s",os.clock()%1000,lbl.Text,ct and ("("..ct..")") or ""))
        end
        if State["shoot.watch"]==true then
            if Hub.WatchVerdict then pcall(Hub.WatchVerdict,lbl.Text,lbl) end
            return
        end
        if AG.FbDone==AG.LastRelAt then return end     
        AG.FbDone=AG.LastRelAt
        local since=os.clock()-AG.LastRelAt
        alog(string.format('feedback "%s" (%.2fs after our release)',lbl.Text,since))
        local manual=AG.LastManual and AG.LastManual.t>AG.LastRelAt and os.clock()-AG.LastManual.t<3
        if manual then
            if t:find("perfect",1,true) and State["shoot.learn"]==true then
                local k=(AG.LastManual.kind=="pad") and "shoot.padHold" or "shoot.keyHold"
                local old=tonumber(State[k])
                local new=old and (old*0.5+AG.LastManual.ms*0.5) or AG.LastManual.ms
                Hub:Set(k,math.floor(new+0.5))
                alog(string.format("learned perfect %s hold: %.0f ms -> %s now %s",
                    AG.LastManual.kind,AG.LastManual.ms,k,tostring(State[k])))
            end
            return 
        end
        if since>12 then return end   
        
        if State["shoot.journal"]==true and State["stealth.quiet"]~=true and type(appendfile)=="function" then
            pcall(function()
                local gui=lbl:FindFirstAncestorOfClass("BillboardGui")
                local ct=gui and gui:FindFirstChild("Contest",true)
                local contest=ct and tostring(ct.Text):match("([%d%.]+)") or ""
                local fn="TRAPPED_journal2.csv"
                if type(isfile)=="function" and not isfile(fn) then
                    writefile(fn,"time,ctx,aim_percent,release_percent,hold_ms,verdict,contest,ping_ms,lag_ms,C_ms,green,version\n")
                end
                local baseAt=tonumber(State["shoot.greenAt"]) or 72
                Hub._jn=(Hub._jn or 0)+1
                if Hub._jn%150==0 then Hub.TrimLog(fn,3000,true) end
                appendfile(fn,string.format("%s,%s,%.1f,%.1f,%.0f,%s,%s,%.0f,%.1f,%.1f,%s,%s\n",os.date("%H:%M:%S"),
                    (tostring(AG.RelCtx):gsub(",",";")),baseAt,AG.RelFrac*100,AG.LastHoldMs,
                    (lbl.Text:gsub(",","")),contest,AGL.relPing,AGL.relLag,AGL.C(AG.RelCtx),(AGL.relGreen:gsub(",",";")),Hub.Version))
            end)
        end
        
        
        
        local idx
        if t:find("very early",1,true) then idx=1
        elseif t:find("slightly early",1,true) then idx=3
        elseif t:find("early",1,true) then idx=2
        elseif t:find("good",1,true) then idx=4
        elseif t:find("perfect",1,true) then idx=5
        elseif t:find("slightly late",1,true) then idx=6
        elseif t:find("very late",1,true) then idx=8
        elseif t:find("late",1,true) then idx=7 end
        if State["stealth.quiet"]~=true then
            pcall(function()
                local w=AG.RelWin and string.format("%.0f-%.0f%%",AG.RelWin.s*100,(AG.RelWin.s+AG.RelWin.L)*100) or "?"
                local pk=Hub.WatchTake and Hub.WatchTake()
                if pk and AG.RelFrac and AG.RelFrac>0 and AG.FullMode then       
                    local dl=pk.peak-AG.RelFrac
                    local v=tonumber(AG.RelVel) or 0
                    
                    if pk.peak<0.93 and v>0.5 and dl>0.02 then
                        local tau=math.clamp(dl/v,0.05,0.3)
                        local old=tonumber(State["shoot.runOnTau"])
                        Hub:Set("shoot.runOnTau",old and (old*0.6+tau*0.4) or tau)
                    end
                end
                bootLog(string.format("shot %s: released at %.1f%% (aim %.1f%%), fine %+.0f ms, ping %.0f, held %.0f ms, meter froze at %s -> %s",
                    tostring(AG.RelCtx),AG.RelFrac*100,(AG.RelTarget or 0)*100,AGL.C(AG.RelCtx),AGL.relPing,AG.LastHoldMs or 0,pk and string.format("%.1f%%",pk.peak*100) or "?",lbl.Text))
            end)
        end
        if idx and Hub.RecordShot then pcall(Hub.RecordShot,lbl,idx) end
        if idx and Hub.SessionShot then pcall(Hub.SessionShot,idx,AG.RelCtx,lbl.Text,AGL.C(AG.RelCtx),AGL.relPing) end
        if idx and idx>=4 and idx<=6 and Hub.OnMakeVerdict then pcall(Hub.OnMakeVerdict,idx) end
        if idx==4 or idx==5 then
            
            local c=AGL.C(AG.RelCtx)
            if State["shoot.fine"]~=false or AG.RelCtx:find(":full",1,true) then Hub:Set("shoot.fine.good."..AG.RelCtx,c) end
            AG.missRun=AG.missRun or {}
            AG.missRun[AG.RelCtx]=0
            local stK="shoot.fine.step."..AG.RelCtx
            Hub:Set(stK,math.max(1,(tonumber(State[stK]) or 6)*0.5))
            if idx==4 and (State["shoot.fine"]~=false or AG.RelCtx:find(":full",1,true)) then
                
                
                local nudged=math.clamp(c+math.max(1,(tonumber(State[stK]) or 3)*0.8),-120,120)
                Hub:Set("shoot.fine."..AG.RelCtx,nudged)
                alog(string.format("GOOD for %s: %+.1f ms kept as fallback, trying %+.1f ms for Perfect",AG.RelCtx,c,nudged))
                return
            end
            alog(string.format("%s for %s: timing %+.1f ms remembered (ping %.0f)",idx==5 and "PERFECT" or "GOOD",AG.RelCtx,c,AGL.relPing))
            return
        end
        if idx and idx~=5 then
            
            
            local sgn=(idx>5) and 1 or -1
            local stK,lsK="shoot.fine.step."..AG.RelCtx,"shoot.fine.last."..AG.RelCtx
            
            
            local step=tonumber(State[stK]) or 6
            local last=tonumber(State[lsK]) or 0
            if last~=0 and last~=sgn then step=math.max(1,step*0.5)
            elseif last==sgn then step=math.min(14,step*1.4) end
            Hub:Set(stK,step); Hub:Set(lsK,sgn)
            
            local c=AGL.C(AG.RelCtx)
            
            AG.missRun=AG.missRun or {}
            AG.missRun[AG.RelCtx]=(AG.missRun[AG.RelCtx] or 0)+1
            local gd=tonumber(State["shoot.fine.good."..AG.RelCtx])
            if gd and AG.missRun[AG.RelCtx]==1 then c=gd end
            if State["shoot.fine"]~=false or AG.RelCtx:find(":full",1,true) then
                c=math.clamp(c-math.clamp(idx-5,-3,3)*step,-120,120)
                Hub:Set("shoot.fine."..AG.RelCtx,c)
            end
            alog(string.format("tier %d (%s): %s fine timing now %+.1f ms (ping %.0f)",idx,t,AG.RelCtx,c,AGL.relPing))
            return
        elseif idx==5 then
            alog(string.format("PERFECT for %s (fine timing %+.1f ms, ping %.0f)",AG.RelCtx,AGL.C(AG.RelCtx),AGL.relPing))
            return
        end
        if AG.LastRelKind=="pad" then
            local pt=tonumber(State["shoot.padTrim"]) or 0
            local step=t:find("very",1,true) and 16 or 8
            if t:find("late",1,true) then pt=pt+step
            elseif t:find("early",1,true) then pt=pt-step end
            pt=math.clamp(pt,-80,150)
            Hub:Set("shoot.padTrim",pt)
            alog("controller trim now "..pt)
            return
        end
        local trim=tonumber(State["shoot.trim"]) or 0
        local auto=tonumber(State["shoot.holdAuto"])
        if t:find("late",1,true) then
            trim=trim+8
            if auto then Hub:Set("shoot.holdAuto",math.max(MIN_HOLD_MS,auto-10)) end
        elseif t:find("early",1,true) then
            trim=trim-8
            if auto then Hub:Set("shoot.holdAuto",auto+10) end
        end
        Hub:Set("shoot.trim",math.clamp(trim,-80,120))
    end)
    track(lbl:GetPropertyChangedSignal("Text"):Connect(fbFn))
    
    
    local gui=lbl:FindFirstAncestorOfClass("BillboardGui")
    if gui then
        track(gui:GetAttributeChangedSignal("Active"):Connect(function()
            if gui:GetAttribute("Active")==true then task.delay(0.06,fbFn) end
        end))
    end
end

local function agBaseline(m)
    local g=m.grad
    if AG.StartO[g]~=nil then return end
    AG.StartO[g]=offAxis(g)
end

local function agBegin(hit)
    AG.Held=hit; AG.T0=os.clock(); AG.Fired=false; AG.Shot=AG.Shot+1
    AG.Hist={}
    AG.StartO={}; AG.Min={}; AG.LastF=nil; AG.LastT=nil; AG.Vel=0; AG.VelLock=nil; AG.VF0=nil; AG.Peak=0; AG.Still=nil
    AG.MeterSeen=false; AG.Warned=false
    if hit.kind=="pad" then installPadHook() end
    scanMeters(); AG.LastScan=AG.T0
    for _,m in ipairs(meters) do agBaseline(m) end
    hookFeedback()
    pcall(function()
        local ch=myChar(); local parts={}
        if ch then for k,v in pairs(ch:GetAttributes()) do parts[#parts+1]=k.."="..tostring(v) end end
        table.sort(parts)
        alog("ctx at arm: "..agContext("?").." attrs: "..table.concat(parts," "))
    end)
    UI.frac=0
    uiStatus("tracking")
    alog("ARMED shot#"..AG.Shot,hit.kind,hit.label,"meters="..#meters,"timerMs="..tostring(agTimerMs()))
    local my=AG.Shot
    local ms=agTimerMs()
    if ms and ms>0 and not agExact() and not hit.jump then
        task.spawn(agSafe("timer",function()
            task.wait(ms/1000)
            if AG.Held and not AG.Fired and AG.Shot==my and agEnabled() and not AG.MeterSeen then
                alog("timer fired (no meter seen)")
                agRelease(0,0,"timer")
            end
        end))
    end
end


local function isPadType(t)
    return t==Enum.UserInputType.Gamepad1 or t==Enum.UserInputType.Gamepad2
        or t==Enum.UserInputType.Gamepad3 or t==Enum.UserInputType.Gamepad4
end

track(UIS.InputBegan:Connect(agSafe("inputBegan",function(inp,gpe)
    if capturing or UIS:GetFocusedTextBox() then return end
    local t=inp.UserInputType
    if (State["dev.trace"]==true and Hub.dev==true) and (t==Enum.UserInputType.Keyboard or isPadType(t)) then
        bootLog(string.format("trace %.3f: input down %s",os.clock()%1000,inp.KeyCode.Name))
    end
    local hit=nil
    if t==Enum.UserInputType.Keyboard then
        local kn=State["shoot.key"] or "E"
        if inp.KeyCode.Name==kn then hit={kind="key",label=kn,vk=KEYCODE_TO_VK[kn] or VK.E} end
    elseif isPadType(t) and inp.KeyCode==AG.padKey() then
        hit={kind="pad",label="Square",vk=VK.E,input=inp,code=inp.KeyCode}
    end
    if hit and hit.kind=="key" then hit.code=inp.KeyCode end
    if not hit then
        
        local jk,jp=AG.jumpKeys()
        local ball=false
        pcall(function() local m=myChar(); ball=m~=nil and Hub.HasBall~=nil and Hub.HasBall(m) end)
        if (t==Enum.UserInputType.Keyboard and inp.KeyCode.Name==jk) or (isPadType(t) and inp.KeyCode==jp) then
            bootLog("jump button pressed ("..inp.KeyCode.Name.."): "..(ball and "Auto Time armed" or "not armed, no ball found"))
        end
        
        ball=true
        if ball and t==Enum.UserInputType.Keyboard and inp.KeyCode.Name==jk then
            hit={kind="key",label=jk,vk=KEYCODE_TO_VK[jk],jump=true,code=inp.KeyCode}
        elseif ball and isPadType(t) and inp.KeyCode==jp then
            hit={kind="pad",label="Jump",vk=VK.E,input=inp,jump=true,code=inp.KeyCode}
        end
    end
    if not hit then return end
    if hit.kind=="key" and os.clock()<AG.BridgeUntil then
        alog("ignored own keyboard bridge press")
        return
    end
    local now=os.clock()
    local since=now-AG.RelSendAt
    alog(string.format("INPUT down %s %s gpe=%s sinceRelease=%.3fs lock=%s",tostring(t.Name),inp.KeyCode.Name,tostring(gpe),since,tostring(AG.KeyLock)))
    if hit.kind=="key" then
        
        
        local gap=now-AG.LastBeginT
        AG.LastBeginT=now
        if AG.KeyLock and (since<0.35 or gap<0.25) then
            alog(string.format("IGNORED key-repeat after our release (since=%.3fs gap=%.3fs)",since,gap))
            local kc=Enum.KeyCode[hit.label]
            if kc then sinkBegins(kc,0.45) end
            return
        end
        AG.KeyLock=false
    end
    if agEnabled() then agBegin(hit) else AG.Held=hit; AG.T0=os.clock(); AG.Fired=false; hookFeedback() end
end)))

track(UIS.InputEnded:Connect(agSafe("inputEnded",function(inp)
    local t=inp.UserInputType
    local isKey=(t==Enum.UserInputType.Keyboard and AG.Held and AG.Held.kind=="key" and inp.KeyCode.Name==AG.Held.label)
    local isPad=(isPadType(t) and ((AG.Held and AG.Held.jump and AG.Held.kind=="pad") and inp.KeyCode==AG.Held.code or inp.KeyCode==AG.padKey()))
    if isKey or isPad then
        local since=os.clock()-AG.RelSendAt
        alog(string.format("INPUT up   %s %s sinceRelease=%.3fs",tostring(t.Name),inp.KeyCode.Name,since))
        if isKey and since>0.12 then AG.KeyLock=false end
        if not AG.Fired then
            if AG.Held then
                AG.LastManual={kind=AG.Held.kind,ms=(os.clock()-AG.T0)*1000,t=os.clock()}
                alog(string.format("manual hold %.0f ms (%s)",AG.LastManual.ms,AG.Held.kind))
            end
            UI.frac=nil
            uiStatus(agEnabled() and "idle" or "off")
        end
        AG.Held=nil
    end
end)))


local agLastSample=0
track(RunService.Heartbeat:Connect(agSafe("heartbeat",function(dt)
    if not AG.Held or AG.Fired or not agEnabled() then return end
    local now=os.clock()
    local exact=agExact()
    local liveMeter=false
    if exact and not AG.MeterSeen then
        for _,m in ipairs(meters) do
            if m.grad.Parent and m.gui.Parent and m.gui.Enabled then liveMeter=true; break end
        end
    end
    if exact and not AG.MeterSeen and not AG.Held.jump and (not liveMeter or now-AG.T0>agExactMs(AG.Held)/1000+0.45) then
        local tgt=AG.T0+agExactMs(AG.Held)/1000
        local rem=tgt-now
        
        if rem<=math.min(dt or 0.017,0.03) then
            if rem>0 then while os.clock()<tgt do end end
            agRelease(UI.frac or 0,0,"exact")
            return
        end
    end
    if now-AG.T0<0.02 then return end

    local best,bestMoved=nil,0.012
    for _,m in ipairs(meters) do
        if m.grad.Parent and m.gui.Parent and m.gui.Enabled then
            local mv=math.abs(offAxis(m.grad)-(AG.StartO[m.grad] or offAxis(m.grad)))
            if mv>bestMoved then best=m; bestMoved=mv end
        end
    end
    if not best and now-AG.LastScan>0.08 then
        AG.LastScan=now
        scanMeters()
        for _,m in ipairs(meters) do agBaseline(m) end
    end
    if not best then
        if now-AG.T0>0.8 and not AG.Warned then
            AG.Warned=true
            alog("no live meter after 0.8s (meters known: "..#meters..")")
            pcall(function()
                local m=myChar()
                bootLog(string.format("no shot meter appeared after %s (animation %s, action %s, meters known %d)",
                    AG.Held and AG.Held.jump and "a Space / Y press" or "the shoot press",
                    tostring(m and m:GetAttribute("BaseAnimation")),tostring(m and m:GetAttribute("Action")),#meters))
            end)
            if not agTimerMs() and not exact and not (AG.Held and AG.Held.jump) then
                Hub:Notify("No shot meter found. Is the game's Shot Meter setting on?","warn")
            end
        end
        return
    end

    local g=best.grad
    local style=best.gui.Name
    local o=offAxis(g)
    local ts,vs=readSeq(g)
    local fm,fp=visFrac(ts,vs,o,-1),visFrac(ts,vs,o,1)

    local mn=AG.Min[g]
    if not mn then
        mn={fm,fp}; AG.Min[g]=mn
    else
        if fm<mn[1] then mn[1]=fm end
        if fp<mn[2] then mn[2]=fp end
    end

    local conv=AG.Convs[style]
    if not conv then
        local im,ip=fm-mn[1],fp-mn[2]
        if math.max(im,ip)>0.05 then
            conv=(im>=ip) and -1 or 1
            AG.Convs[style]=conv
            alog("direction for "..style..": "..conv)
        else
            return
        end
    end
    local frac=(conv==-1) and fm or fp
    AG.MeterSeen=true
    UI.frac=frac

    if AG.LastF and now>AG.LastT then
        AG.Vel=AG.Vel*0.6+((frac-AG.LastF)/(now-AG.LastT))*0.4
    end
    AG.LastF,AG.LastT=frac,now

    AG.Ctx=agContext(style)
    
    
    
    local baseAt=tonumber(State["shoot.greenAt"]) or 72
    local target=baseAt/100
    
    
    AG.FullMode=false
    if State["shoot.fullBar"]==true then
        local fmax=AG.FMax[g]
        if not fmax then
            fmax=0
            for i=-50,50 do
                local f=visFrac(ts,vs,i*0.02,conv)
                if f>fmax then fmax=f end
            end
            AG.FMax[g]=fmax
        end
        if fmax>0.3 and fmax<=1.01 then
            
            
            if not AG.VelLock then
                if frac>=0.2 and not AG.VF0 then AG.VF0,AG.VT0=frac,now end
                if AG.VF0 and frac>=0.45 and now>AG.VT0 then
                    AG.VelLock=(frac-AG.VF0)/(now-AG.VT0)
                end
            end
            local vv=AG.VelLock or 0
            target=math.max(0.3,fmax-0.025-vv*(tonumber(State["shoot.runOnTau"]) or 0.13))      
            local wf=tonumber(State["shoot.watchFreeze"])
            if wf then                                                          
                target=math.clamp(wf-vv*(tonumber(State["shoot.runOnTau"]) or 0.13),0.3,fmax)
            end       
            AG.FullMode=true
            if State["shoot.timedHold"]==true and not AG.Fired then
                
                local H=tonumber(State["shoot.watchHold"]) or 468
                local lagMs=AGL.ms(AG.Ctx)
                local tgt=AG.T0+(H+lagMs)/1000
                local rem=tgt-now
                if rem<=math.min(dt or 0.017,0.03) then
                    if rem>0 then while os.clock()<tgt do end end
                    AG.TimedHold=H
                    agRelease(frac,target,"meter",lagMs)
                    return
                end
                if not AG.TopLogged then
                    AG.TopLogged=true
                    bootLog(string.format("Auto Time (full bar, %s): copying the watched script, timed hold %.0f ms %+d ms fine",style,H,lagMs))
                end
                return
            end
            if not AG.TopLogged then
                AG.TopLogged=true
                bootLog(string.format("Auto Time (full bar, %s): the fill tops out at %.1f%%, releasing at %.1f%%",style,fmax*100,target*100))
            end
        end
    end
    local lagNow=AGL.ms(AG.Ctx)
    local isPad=(AG.Held~=nil and AG.Held.kind=="pad")
    local trimMs=isPad and (tonumber(State["shoot.padTrim"]) or 0) or (tonumber(State["shoot.trim"]) or 0)
    local lead=pingSec()*0.5+LEAD_BASE+trimMs/1000+(isPad and BRIDGE_DELAY or 0)
    
    
    local pred=(State["shoot.lead"]==true) and (frac+math.max(AG.Vel,0)*lead) or frac

    if now-agLastSample>0.1 then
        agLastSample=now
        alog(string.format("sample %s frac=%.3f pred=%.3f aim=%.3f vel=%.2f off=%.3f",style,frac,pred,target,AG.Vel,o))
    end

    
    
    
    AG.Hist[#AG.Hist+1]={now,frac}
    while #AG.Hist>0 and now-AG.Hist[1][1]>0.30 do table.remove(AG.Hist,1) end
    if #AG.Hist>=5 and (AG.Hist[#AG.Hist][1]-AG.Hist[1][1])>=0.12 then
        local n,sx,sy,sxx,sxy=#AG.Hist,0,0,0,0
        local t0=AG.Hist[1][1]
        for _,p in ipairs(AG.Hist) do
            local x=p[1]-t0
            sx=sx+x; sy=sy+p[2]; sxx=sxx+x*x; sxy=sxy+x*p[2]
        end
        local den=n*sxx-sx*sx
        if den>1e-9 then
            local m=(n*sxy-sx*sy)/den
            local b0=(sy-m*sx)/n
            if m>0.35 and m<14 then
                local tc=t0+(target-b0)/m+lagNow/1000         
                local rem=tc-now
                if rem<=0 then agRelease(frac,target,"meter",lagNow); return end
                if rem<=0.045 then
                    while os.clock()<tc do end
                    agRelease(target,target,"meter",lagNow); return
                end
                return                                        
            end
        end
    end
    if pred>=target then agRelease(frac,target,"meter"); return end

    if frac>AG.Peak+0.002 then
        AG.Peak=frac; AG.Still=nil
    elseif AG.Peak>0.6 then
        if frac<AG.Peak-0.04 then agRelease(AG.Peak,target,"passed"); return end
        if frac>=AG.Peak-0.01 then
            AG.Still=AG.Still or now
            if now-AG.Still>(AG.FullMode and 0.05 or 0.2) then agRelease(frac,target,"stall"); return end
        end
    end
end)))



do
    local W={st={},active=false,keyDown=nil,keyUp=nil,logAt=0,samples={},remN=0,remAt=0}
    local function isShootKey(inp)
        local t=inp.UserInputType
        if t==Enum.UserInputType.Keyboard then return inp.KeyCode.Name==(State["shoot.key"] or "E") end
        return isPadType(t) and inp.KeyCode==AG.padKey()
    end
    track(UIS.InputBegan:Connect(function(inp)
        if State["shoot.watch"]==true and isShootKey(inp) then W.keyDown=os.clock(); W.keyUp=nil end
    end))
    track(UIS.InputEnded:Connect(function(inp)
        if State["shoot.watch"]==true and isShootKey(inp) then W.keyUp=os.clock(); W.upFrac=W.last end
    end))
    local function fmtArg(v,depth)
        local t=typeof(v)
        if t=="number" then return (v%1==0) and tostring(v) or string.format("%.3f",v)
        elseif t=="string" then return '"'..v:sub(1,24)..'"'
        elseif t=="boolean" or t=="nil" then return tostring(v)
        elseif t=="Vector3" then return string.format("v(%.2f,%.2f,%.2f)",v.X,v.Y,v.Z)
        elseif t=="Instance" then return "<"..v.Name..">"
        elseif t=="table" and (depth or 0)<1 then
            local out,n={},0
            for k,x in pairs(v) do
                n=n+1; if n>5 then out[#out+1]="..."; break end
                out[#out+1]=tostring(k).."="..fmtArg(x,1)
            end
            return "{"..table.concat(out,",").."}"
        end
        return t
    end
    
    function Hub.WatchRemote(name,args)
        local now=os.clock()
        if now-W.remAt>1 then W.remAt=now; W.remN=0 end
        if name=="InputService.Shoot" and type(args[1])=="table" then      
            if args[1].Shoot==true then W.shootAt=now
            elseif args[1].Shoot==false and W.shootAt then W.gap=(now-W.shootAt)*1000; W.gapAt=now; W.shootAt=nil end
            if args[1].Shoot==true or args[1].Shoot==false then
                
                task.defer(function() pcall(function()
                    local me=myChar()
                    local hrp=me and me:FindFirstChild("HumanoidRootPart")
                    local at={}
                    if me then for k,v in pairs(me:GetAttributes()) do
                        if type(v)~="table" and #at<14 then at[#at+1]=k.."="..tostring(v) end
                    end end
                    local gd,dd
                    if Hub.ShotContext then gd,dd=Hub.ShotContext() end
                    local vel=hrp and hrp.AssemblyLinearVelocity
                    bootLog(string.format("watch state (%s): hoop %s, nearest defender %s, speed %s, attrs [%s]",
                        args[1].Shoot and "press" or "release",gd and string.format("%.1f",gd) or "?",dd and string.format("%.1f",dd) or "none",
                        vel and string.format("%.1f",vel.Magnitude) or "?",table.concat(at,", ")))
                end) end)
            end
        end
        W.remN=W.remN+1
        if W.remN>30 then return end
        local parts={}
        for i=1,args.n do parts[i]=fmtArg(args[i]) end
        bootLog(string.format("watch remote %.3f: %s(%s)",now%1000,name,table.concat(parts,", ")))
    end
    local function finish()
        if not W.active then return end
        W.active=false
        local held=(W.keyDown and W.keyUp and W.keyUp>=W.keyDown and os.clock()-W.keyUp<3) and (W.keyUp-W.keyDown)*1000 or nil
        local ctx; pcall(function() ctx=agContext("?") end)
        local an,ss
        pcall(function()
            local ch=myChar()
            an=ch and ch:GetAttribute("BaseAnimation"); ss=ch and ch:GetAttribute("ShotSpeed")
        end)
        W.pend={t=os.clock(),peak=W.peak,rel=W.upFrac or W.peak,dur=(W.lastAt-W.t0)*1000,held=held,top=W.top,
            curve=table.concat(W.samples," "),ping=pingSec()*1000,ctx=ctx,anim=an,ss=ss}
        W.upFrac=nil
    end
    function Hub.WatchTake()
        if W.active then finish() end
        local p=W.pend
        if p and os.clock()-p.t<4 then W.pend=nil; return p end
    end
    function Hub.WatchVerdict(text,lbl)
        if os.clock()-W.logAt<0.4 then return end
        W.logAt=os.clock()
        if W.active then finish() end        
        local p=W.pend
        pcall(function()
            local gui=lbl and lbl:FindFirstAncestorOfClass("BillboardGui")
            local ct=gui and gui:FindFirstChild("Contest",true)
            if ct then bootLog("watch contest: "..tostring(ct.Text)) end
        end)
        if p and os.clock()-p.t<4 then
            bootLog(string.format("watch: held %s, meter ran %.0f ms, let go at %.1f%% (peak %.1f%%, top %.1f%%), ping %.0f, ctx %s, anim %s, shot speed %s -> %s",
                p.held and string.format("%.0f ms",p.held) or "? (no key event)",p.dur,p.rel*100,p.peak*100,(p.top or 0)*100,p.ping or 0,
                tostring(p.ctx),tostring(p.anim),tostring(p.ss),tostring(text)))
            bootLog("watch curve: "..tostring(p.curve))
            if tostring(text):lower():find("perfect",1,true) then
                
                if W.gap and os.clock()-(W.gapAt or 0)<4 and W.gap>250 and W.gap<900 then
                    local hh=tonumber(State["shoot.watchHold"])
                    hh=hh and (hh*0.8+W.gap*0.2) or W.gap
                    Hub:Set("shoot.watchHold",hh)
                    bootLog(string.format("watch: this Perfect was a %.0f ms hold, average %.0f ms",W.gap,hh))
                end
                local n=(tonumber(State["shoot.watchN"]) or 0)+1
                local m=tonumber(State["shoot.watchFreeze"])
                m=m and (m*0.8+p.peak*0.2) or p.peak
                Hub:Set("shoot.watchN",n); Hub:Set("shoot.watchFreeze",m)
                bootLog(string.format("watch: %d Perfect releases seen, the meter froze at %.1f%% on average",n,m*100))
            end
        else
            bootLog("watch: verdict "..tostring(text).." (no meter data for this shot)")
        end
        W.pend=nil
    end
    track(RunService.Heartbeat:Connect(agSafe("watch",function()
        if State["shoot.watch"]~=true and State["shoot.perfect"]~=true then return end
        local now=os.clock()
        if State["shoot.watch"]==true and not W.hooked then W.hooked=true; pcall(installPadHook) end
        if now-(W.fbAt or 0)>1 then W.fbAt=now; pcall(hookFeedback) end
        if now-(W.scanAt or 0)>0.5 then W.scanAt=now; scanMeters() end
        local m
        for _,x in ipairs(meters) do
            if x.grad.Parent and x.gui.Parent and x.gui.Enabled then m=x; break end
        end
        if not m then if W.active and now-W.lastAt>0.3 then finish() end return end
        local g=m.grad
        local ts,vs=readSeq(g)
        local o=offAxis(g)
        local fm,fp=visFrac(ts,vs,o,-1),visFrac(ts,vs,o,1)
        local s=W.st[g]
        if not s then s={fm=fm,fp=fp}; W.st[g]=s end
        if not W.active then
            local dm,dp=fm-s.fm,fp-s.fp
            if math.max(dm,dp)>0.05 then
                s.conv=(dm>=dp) and -1 or 1
                W.active=true; W.t0=now; W.lastAt=now; W.peak=0; W.last=0; W.samples={}; W.sampleAt=0
                local top=AG.FMax[g]
                if not top then
                    top=0
                    for i=-50,50 do local f=visFrac(ts,vs,i*0.02,s.conv); if f>top then top=f end end
                    AG.FMax[g]=top
                end
                W.top=top
            else
                s.fm,s.fp=math.min(s.fm,fm),math.min(s.fp,fp)
                if math.max(dm,dp)<0.01 then s.fm,s.fp=fm,fp end
            end
            return
        end
        local frac=((s.conv or -1)==-1) and fm or fp
        W.last=frac
        if now-W.sampleAt>=0.06 and #W.samples<18 then
            W.sampleAt=now
            W.samples[#W.samples+1]=string.format("%.0f%%@%d",frac*100,(now-W.t0)*1000)
        end
        if frac>W.peak+0.002 then W.peak=frac; W.lastAt=now end
        if frac<W.peak-0.03 or (W.peak>0.5 and now-W.lastAt>0.25) then
            finish()
            s.fm,s.fp=fm,fp
        end
    end)))
end
alog("Auto Time v"..Hub.Version.." loaded | "..capLine())
end









do
local queueTp=(type(queue_on_teleport)=="function" and queue_on_teleport)
    or (type(queueonteleport)=="function" and queueonteleport)
    or (syn and type(syn.queue_on_teleport)=="function" and syn.queue_on_teleport)
    or (fluxus and type(fluxus.queue_on_teleport)=="function" and fluxus.queue_on_teleport)

local STUB=[==[
local LOG="TRAPPED_boot.log"
local T0=os.clock()
local function log(m)
    pcall(function()
        local line=os.date("%H:%M:%S").." [stub] "..tostring(m).."\n"
        if type(appendfile)=="function" then appendfile(LOG,line)
        elseif type(writefile)=="function" then
            local old=(type(isfile)=="function" and isfile(LOG) and readfile(LOG)) or ""
            writefile(LOG,old..line)
        end
    end)
end
local g=(type(getgenv)=="function") and getgenv() or _G
local function toast(t)
    if State["stealth.quiet"]==true then return end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="TRAPPED",Text=t,Duration=8})
    end)
end
if g.__TRAPPED_STUB_BUSY then log("another stub run is in progress, skipping"); return end
g.__TRAPPED_STUB_BUSY=true
log("stub started reason=@REASON@ fromPlace=@PLACE@ nowPlace="..tostring(game.PlaceId))
local ok,err=pcall(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local Players=game:GetService("Players")
    local lp=Players.LocalPlayer
    while not lp do task.wait(0.1); lp=Players.LocalPlayer end
    lp:WaitForChild("PlayerGui",30)
    repeat task.wait(0.1) until workspace.CurrentCamera or os.clock()-T0>10
    task.wait(1.5)
    log(string.format("game ready after %.1fs (place %s)",os.clock()-T0,tostring(game.PlaceId)))

    if g.__TRAPPED_LOADED_JOB==game.JobId and "@REASON@"~="test" then
        log("already re-run in this server (job "..tostring(game.JobId):sub(1,8)..", duplicate stub), skipping"); return
    end
    if type(isfile)=="function" and isfile("TRAPPED_off.flag") then
        log("TRAPPED was unloaded by the user, not re-running"); return
    end
    local cfg=nil
    pcall(function()
        if type(isfile)=="function" and isfile("TRAPPED_Default.json") then
            cfg=game:GetService("HttpService"):JSONDecode(readfile("TRAPPED_Default.json")).s
        end
    end)
    if cfg and cfg["settings.rerunOnTeleport"]==false and "@REASON@"~="test" then
        log("re-run is switched off in settings, not re-running"); return
    end

    local src,how
    if type(isfile)=="function" and type(readfile)=="function" and isfile("TRAPPED.lua") then
        local okr,s=pcall(readfile,"TRAPPED.lua")
        if okr and type(s)=="string" and #s>1000 then src=s; how="TRAPPED.lua ("..#s.." bytes)"
        else log("TRAPPED.lua exists but could not be read / is too small") end
    end
    if not src then
        local url=(cfg and cfg["settings.scriptUrl"]) or @URL@
        if type(url)=="string" and url~="" then
            local okh,s=pcall(function() return game:HttpGet(url) end)
            if okh and type(s)=="string" and #s>1000 then src=s; how="url "..url
            else log("HttpGet failed: "..tostring(s)) end
        end
    end
    if not src and type(g.__TRAPPED_SRC)=="string" then src=g.__TRAPPED_SRC; how="getgenv cache" end
    if not src then
        log("FAILED: no script source. Save the script as TRAPPED.lua in the executor workspace folder, or set a Script URL in Settings.")
        toast("Re-run failed: save the script as TRAPPED.lua in your workspace folder.")
        return
    end
    log("source: "..how)
    g.__TRAPPED_BOOT={reason="@REASON@",fromPlace="@PLACE@",waited=string.format("%.1f",os.clock()-T0)}
    local fn,cerr=loadstring(src,"=TRAPPED")
    if not fn then
        log("COMPILE ERROR: "..tostring(cerr))
        toast("Re-run failed: script did not compile (see TRAPPED_boot.log)")
        return
    end
    g.__TRAPPED_LOADED_JOB=game.JobId
    log("running script")
    local okx,rerr=xpcall(fn,function(e) return tostring(e).."\n"..debug.traceback() end)
    if okx then log("script finished OK")
    else log("SCRIPT ERROR: "..tostring(rerr)); toast("Re-run error (see TRAPPED_boot.log)") end
end)
if not ok then log("STUB ERROR: "..tostring(err)) end
g.__TRAPPED_STUB_BUSY=nil
]==]

local function makeStub(reason)
    local s=STUB
    s=s:gsub("@REASON@",function() return reason end)
    s=s:gsub("@PLACE@",function() return tostring(game.PlaceId) end)
    s=s:gsub("@URL@",function() return string.format("%q",tostring(State["settings.scriptUrl"] or "")) end)
    return s
end


local function compat()
    local hasHttpGet=false
    pcall(function() hasHttpGet=(type(game.HttpGet)=="function") end)
    local rows={
        {"queue_on_teleport",queueTp~=nil,true},
        {"readfile",type(readfile)=="function",true},
        {"writefile",type(writefile)=="function",true},
        {"isfile",type(isfile)=="function",true},
        {"loadstring",type(loadstring)=="function",true},
        {"appendfile",type(appendfile)=="function",false},
        {"getgenv",type(getgenv)=="function",false},
        {"HttpGet",hasHttpGet,false},
        {"setclipboard",type(setclipboard)=="function",false},
        {"delfile",type(delfile)=="function",false},
    }
    local missing,optional={}, {}
    for _,r in ipairs(rows) do
        if not r[2] then
            if r[3] then missing[#missing+1]=r[1] else optional[#optional+1]=r[1] end
        end
    end
    return rows,missing,optional
end

local function srcInfo()
    local hasFile,size,ver=false,0,nil
    pcall(function()
        if type(isfile)=="function" and isfile("TRAPPED.lua") then
            local src=readfile("TRAPPED.lua")
            hasFile=true; size=#src
            ver=src:match('Version="([%d%.]+)"')
            if src:find("TRAPPED_LOADER",1,true) then ver=nil end       
        end
    end)
    local url=tostring(State["settings.scriptUrl"] or "")
    return hasFile,size,url,ver
end

function Hub.SourceStatus()
    local hasFile,size,url,ver=srcInfo()
    if hasFile and ver and ver~=Hub.Version then
        return "OUTDATED v"..ver.." (running v"..Hub.Version..")",C.Sec
    end
    if hasFile then return "TRAPPED.lua  v"..tostring(ver or "?").."  "..math.floor(size/1024).." KB",C.White end
    if url~="" then return "Script URL", C.Sec end
    return "missing: save as TRAPPED.lua",C.Dim
end
function Hub.HookStatus()
    local _,missing=compat()
    if #missing>0 then return "missing "..table.concat(missing,", "),C.Dim end
    if State["settings.rerunOnTeleport"]==false then return "switched off",C.Dim end
    return "ready",C.White
end

local function refreshStatus()
    for _,u in ipairs(statusUpdaters) do pcall(u) end
end
Hub.RefreshStatus=refreshStatus
Hub.Changed:Connect(function(id)
    if id=="settings.scriptUrl" or id=="settings.rerunOnTeleport" then refreshStatus() end
end)


local tpQueued=false
local function queueRerun(why)
    if State["settings.rerunOnTeleport"]==false then
        bootLog("queue skipped ("..why.."): re-run is switched off"); return false
    end
    if tpQueued then return true end
    if not queueTp then
        bootLog("queue FAILED ("..why.."): this executor has no queue_on_teleport")
        Hub:Notify("Re-run: this executor has no queue_on_teleport","warn")
        return false
    end
    local hasFile,size,url=srcInfo()
    if not hasFile and url=="" then
        bootLog("queue WARNING ("..why.."): no TRAPPED.lua in workspace and no Script URL, the stub will have nothing to load")
        Hub:Notify("Re-run needs TRAPPED.lua in your workspace folder","warn")
    end
    local ok,err=pcall(queueTp,makeStub("teleport"))
    if ok then
        tpQueued=true
        bootLog("stub queued ("..why..") source="..(hasFile and ("TRAPPED.lua "..size.." bytes") or (url~="" and "url" or "NONE")))
        return true
    end
    bootLog("queue FAILED ("..why.."): "..tostring(err))
    Hub:Notify("Re-run: queue_on_teleport failed","error")
    return false
end
Hub.QueueRerun=function() return queueRerun("manual") end



Hub.Changed:Connect(function(id)
    if id~="settings.rerunOnTeleport" then return end
    cfgSave()
    tpQueued=false
    if State[id]==false then
        local cleared=false
        pcall(function()
            local clr=clear_teleport_queue or clearqueueonteleport
            if clr then clr(); cleared=true end
        end)
        bootLog("re-run switched off, saved"..(cleared and ", teleport queue cleared" or " (this executor cannot clear the queue; the stub will skip itself)"))
    else
        queueRerun("switched on")
    end
end)

function Hub.Compat()
    local rows,missing,optional=compat()
    local t={}
    for _,r in ipairs(rows) do t[#t+1]=r[1].."="..(r[2] and "Y" or "n") end
    bootLog("compat: "..table.concat(t," "))
    local hasFile,size,url=srcInfo()
    bootLog("source: TRAPPED.lua="..(hasFile and (size.." bytes") or "missing").." url="..(url~="" and url:sub(1,80) or "none")
        .." queued="..tostring(tpQueued))
    refreshStatus()
    if #missing>0 then Hub:Notify("Missing: "..table.concat(missing,", "),"error")
    elseif not hasFile and url=="" then Hub:Notify("APIs OK, but TRAPPED.lua is not in your workspace","warn")
    else Hub:Notify("Re-run ready ("..(#optional>0 and "optional missing: "..table.concat(optional,", ") or "all APIs present")..")","success") end
end


function Hub.TestRerun()
    if type(loadstring)~="function" then Hub:Notify("No loadstring in this executor","error"); return end
    bootLog("test re-run requested")
    Hub:Notify("Running re-run stub... the menu will reload","warn")
    task.delay(0.4,function()
        local fn,err=loadstring(makeStub("test"),"=TRAPPED_stub")
        if not fn then bootLog("test: stub compile error "..tostring(err)); Hub:Notify("Stub compile error","error"); return end
        task.spawn(fn)
    end)
end

function Hub.CopyBootLog()
    local text=table.concat(bootLines,"\n")
    pcall(function()
        if type(isfile)=="function" and isfile(BOOT_FILE) then text=readfile(BOOT_FILE) end
    end)
    local lines={}
    for l in text:gmatch("[^\n]+") do lines[#lines+1]=l end
    while #lines>120 do table.remove(lines,1) end
    local ok=type(setclipboard)=="function" and pcall(setclipboard,table.concat(lines,"\n"))
    Hub:Notify(ok and "Boot log copied" or "No clipboard API (log is in TRAPPED_boot.log)",ok and "success" or "warn")
end


function Hub:UnloadForGood()
    pcall(function() if type(writefile)=="function" then writefile("TRAPPED_off.flag","1") end end)
    pcall(function()
        local clr=clear_teleport_queue or clearqueueonteleport
        if clr then clr() end
    end)
    bootLog("unloaded by user: re-run disabled until TRAPPED is run manually again")
    self:Destroy()
end


task.spawn(function()
    pcall(function()
        track(LP.OnTeleport:Connect(function(tpState)
            bootLog("teleport state: "..tostring(tpState))
            if tpState==Enum.TeleportState.Started or tpState==Enum.TeleportState.InProgress then
                if queueRerun("OnTeleport") then
                    Hub:Notify("Teleporting. TRAPPED will re-run on arrival.","success")
                end
            end
        end))
    end)
    pcall(function()
        track(TeleportService.TeleportInitFailed:Connect(function(_,res,msg)
            bootLog("teleport FAILED: "..tostring(res).." "..tostring(msg))
        end))
    end)
    pcall(function()
        track(Players.PlayerRemoving:Connect(function(p)
            if p==LP then bootLog("local player leaving the server"); queueRerun("leaving") end
        end))
    end)
    
    task.wait(3)
    if not Hub.alive then return end
    local hasFile,size,url,fver=srcInfo()
    if hasFile and fver and fver~=Hub.Version then
        bootLog("WARNING: workspace TRAPPED.lua is v"..fver.." but v"..Hub.Version.." is running; a teleport re-run would load the OLD file")
        Hub:Notify("Workspace TRAPPED.lua is v"..fver.." (old). Replace it with v"..Hub.Version,"warn")
    end
    local _,missing=compat()
    bootLog(string.format("startup check: missing=%s file=%s url=%s",
        #missing>0 and table.concat(missing,",") or "none",hasFile and (size.." bytes") or "no",url~="" and "yes" or "no"))
    queueRerun("startup")
    refreshStatus()
end)
end


local saved=cfgLoad()
do
    local n=0
    if saved then for _ in pairs(saved) do n=n+1 end end
    bootLog("config: "..(saved and (n.." settings loaded from "..CFG_FILE) or "none found, using defaults"))
    if bootReason=="manual" then
        pcall(function()
            if type(isfile)=="function" and isfile("TRAPPED_off.flag") and type(delfile)=="function" then
                delfile("TRAPPED_off.flag"); bootLog("cleared TRAPPED_off.flag")
            end
        end)
    end
end
for _,k in ipairs({"play.brain","play.space","play.getOpen"}) do State[k]=false end
if saved then
    if saved["shoot.greenAt"]==90 then saved["shoot.greenAt"]=98 end
    pushAll(saved)
    for _,k in ipairs({"play.brain","play.space","play.getOpen"}) do State[k]=false end     
    
    if (tonumber(State["shoot.holdAuto"]) or 999)<250 then State["shoot.holdAuto"]=nil end
    if State["cfg.trimReset"]~=true then
        Hub:Set("cfg.trimReset",true)
        Hub:Set("shoot.trim",0)
    end
    if State["cfg.back77"]~=true then
        Hub:Set("cfg.back77",true)
        Hub:Set("shoot.greenAt",77)
        Hub:Set("shoot.exact",true)
    end
    if State["cfg.dribKeyN"]~=true then          
        Hub:Set("cfg.dribKeyN",true)
        if State["play.dribKey"]=="V" then Hub:Set("play.dribKey","N") end
    end
    if State["cfg.fullBar1"]~=true then       
        Hub:Set("cfg.fullBar1",true)
        Hub:Set("shoot.fullBar",true)
        State["shoot.autoBuild"]=nil
    end
    if State["cfg.winAbs1"]~=true then       
        Hub:Set("cfg.winAbs1",true)
        for k in pairs(State) do
            if type(k)=="string" and (k:sub(1,11)=="shoot.frac." ) then State[k]=nil end
        end
    end
    if State["cfg.fullAim4"]~=true then          
        Hub:Set("cfg.fullAim4",true)
        State["shoot.runOnTau"]=nil
        for k in pairs(State) do
            if type(k)=="string" and k:find(":full",1,true) and k:sub(1,5)=="shoot" then State[k]=nil end
        end
    end
    if State["cfg.fullAim3"]~=true then          
        Hub:Set("cfg.fullAim3",true)
        State["shoot.freezeDelta"]=nil; State["shoot.runOnTau"]=nil
        for k in pairs(State) do
            if type(k)=="string" and k:find(":full",1,true) and k:sub(1,5)=="shoot" then State[k]=nil end
        end
    end
    if State["cfg.fullAim2"]~=true then          
        Hub:Set("cfg.fullAim2",true)
        State["shoot.freezeDelta"]=nil
        for k in pairs(State) do
            if type(k)=="string" and k:find(":full",1,true) and k:sub(1,5)=="shoot" then State[k]=nil end
        end
    end
    if State["cfg.green72"]~=true then          
        Hub:Set("cfg.green72",true)
        Hub:Set("shoot.greenAt",72)
    end
    if State["cfg.layupAuto45"]~=true then    
        Hub:Set("cfg.layupAuto45",true)
        State["shoot.layupAt"]=nil
        for k in pairs(State) do
            if type(k)=="string" and k:sub(1,10)=="shoot.ctx." and k:find(":layup",1,true) then State[k]=nil end
        end
    end
    if State["cfg.fine68"]~=true then
        Hub:Set("cfg.fine68",true)
        for k in pairs(State) do
            if type(k)=="string" and (k:sub(1,12)=="shoot.lagC." ) then State[k]=nil end
        end
    end
    if State["cfg.lag54"]~=true then           
        Hub:Set("cfg.lag54",true)
        for k in pairs(State) do
            if type(k)=="string" and k:sub(1,10)=="shoot.ctx." then State[k]=nil end
        end
    end
    if State["cfg.ctxReset44"]~=true then      
        Hub:Set("cfg.ctxReset44",true)
        for k in pairs(State) do
            if type(k)=="string" and k:sub(1,10)=="shoot.ctx." then State[k]=nil end
        end
    end
    if State["cfg.fix2"]~=true then
        Hub:Set("cfg.fix2",true)
        Hub:Set("shoot.perfect",true)
    end
end


pcall(function()
    local vp=vpSize()
    local sc=finalScale()
    local hw,hh=W*sc/2,H*sc/2
    local nx=math.clamp(tonumber(State["ui.posX"]) or 0,hw-0.5*vp.X,vp.X-hw-0.5*vp.X)
    local ny=math.clamp(tonumber(State["ui.posY"]) or 0,hh-0.5*vp.Y,vp.Y-hh-0.5*vp.Y)
    root.Position=UDim2.new(0.5,nx,0.5,ny)
end)

Hub.SwitchPage("Shooting",true)
Hub:ToggleMenu(true)
bootLog("menu shown (build "..(buildOk and "OK" or ("ERROR: "..tostring(buildErr)))..")")

pcall(function()
    _G.TRAPPED=Hub
    if type(getgenv)=="function" then getgenv().TRAPPED=Hub end
end)

task.delay(0.5,function()
    if bootReason=="teleport" then
        Hub:Notify("TRAPPED re-run after teleport  |  "..tostring(State["ui.menuKey"]).." to toggle","success")
    else
        Hub:Notify("TRAPPED v"..Hub.Version.."  |  "..tostring(State["ui.menuKey"]).." to toggle","success")
    end
end)

if not buildOk then
    task.delay(0.9,function()
        Hub:Notify("Build error (see console)","error")
        warn("[TRAPPED build] "..tostring(buildErr))
    end)
end


task.delay(2.5,function()
    if Hub.alive and State["ui.firstRun"]~=true then
        Hub:Set("ui.firstRun",true)
        Hub:Notify("Welcome. Open Settings > Config presets and pick Legit, Semi-legit or Blatant to get started.","info")
    end
end)





local function relock(why,headline)
    if LICENSED.relocking or not LICENSED.prompt then return false end
    LICENSED.relocking=true
    
    pcall(function() Hub:ToggleMenu(false) end)
    task.spawn(function()
        while Hub.alive and not LICENSED.ok do
            pcall(function() root.Visible=false end)
            task.wait(0.15)
        end
    end)
    local snap={}
    for k,v in pairs(State) do
        if v==true and type(k)=="string" and (k:find("^shoot%.") or k:find("^play%.") or k:find("^pro%.") or k:find("^flow%.")) then snap[#snap+1]=k end
    end
    for _,k in ipairs(snap) do pcall(Hub.Set,Hub,k,false) end
    LICENSED.ok=false; LICENSED.why=why
    pcall(LICENSED.prompt,{fade=headline})
    if LICENSED.ok then
        for _,k in ipairs(snap) do pcall(Hub.Set,Hub,k,true) end
        LICENSED.relocking=false; LICENSED.expiredShown=false
        pcall(function() Hub:ToggleMenu(true) end)
        return true
    end
    Hub:UnloadForGood()
    return false
end
task.spawn(function()
    local warned=false
    local t=0
    while Hub.alive do
        task.wait(10); t=t+10
        pcall(function()
            local sub=LICENSED.info and LICENSED.info.subscriptions and LICENSED.info.subscriptions[1]
            local left0=sub and tonumber(sub.timeleft)
            if left0 and left0<=315360000 and not LICENSED.expiredShown
                and left0-(os.clock()-(LICENSED.at or os.clock()))<=0 then
                LICENSED.expiredShown=true
                if relock("Key expired. Buy a new one in our Discord.","Your key has expired") then warned=false end
                return
            end
            if left0 and left0<=315360000 and not warned then
                local left=left0-(os.clock()-(LICENSED.at or os.clock()))
                if left>0 and left<3*86400 then
                    warned=true
                    local d=math.max(1,math.ceil(left/86400))
                    Hub:Notify("Your key expires in "..d.." day"..(d>1 and "s" or "")..". Renew it in our Discord.","warn")
                end
            end
        end)
        if t>=600 then
            t=0
            local rc=LICENSED.recheck
            if rc then
                local okc,res,why=pcall(rc)
                if okc and res==false then
                    local expd=tostring(why or ""):lower():find("expire",1,true)
                    local msg=LICENSED.nice and LICENSED.nice(why) or tostring(why or "License no longer valid")
                    if relock(msg,expd and "Your key has expired" or "License no longer valid") then warned=false; t=0 end
                    if not LICENSED.ok then return end
                end
            end
        end
    end
end)

print("[TRAPPED] v"..Hub.Version.." ready")
return Hub]=====]

local function selfSave()
    if type(writefile)~="function" then return end
    local want="local S=[=====["..SRC.."]=====]\nreturn loadstring(S)()\n"
    local have
    if type(isfile)=="function" and type(readfile)=="function" and isfile("TRAPPED.lua") then
        local ok,t=pcall(readfile,"TRAPPED.lua")
        if ok then have=t end
    end
    if have~=want then pcall(writefile,"TRAPPED.lua",want) end
end
pcall(selfSave)

local fn,err=loadstring(SRC)
if not fn then warn("[TRAPPED] failed to load: "..tostring(err)); return end
return fn()
