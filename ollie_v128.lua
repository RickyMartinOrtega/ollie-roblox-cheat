--[[ ollie roblox cheat v128 — DELTA MOBILE ULTIMATE + GUI SCALE
     NEW over v64:
       · GUI SCALE — one slider, 50% → 200%, uses UIScale on the frame
         so every widget (tabs, sliders, toggles, player list) scales clean
       · FAB SCALE — independent FAB size 60% → 150%
       · ESP TEXT SCALE — text size multiplier so scaled UI matches game
       · collapsible sections in the gui (tap a header to fold)
       · keyboard binds for every feature (desktop fallback on mobile rigs)
       · right-thumb quick toggles along the bottom edge
       · everything v64 had: silent multi-hook, triggerbot, player list,
         profiles, waypoints, cam lock, crosshair, watermark, auto-click
     every API pcall'd. Drawing falls back to ScreenGui ESP.
     requires: nothing mandatory. delta mobile is the target. ]]

-- ═══════════════════════════════════════════════════════════════════════
-- B · bootstrap
-- ═══════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_MOBILE   = UserInputService.TouchEnabled
local HAS_DRAWING = pcall(function() local d = Drawing.new("Square") d:Remove() end)
local HAS_WRITE   = pcall(function() return writefile end)
local HAS_HOOK    = pcall(function() return hookmetamethod, getrawmetatable, setreadonly, newcclosure end)
local HAS_NAMECALL= pcall(function() return getnamecallmethod end)
local HAS_LIST    = pcall(function() return listfiles end)
local HAS_ISFILE  = pcall(function() return isfile end)
local HAS_MKDIR   = pcall(function() return makefolder end)

pcall(function()
    for _, g in ipairs(CoreGui:GetChildren()) do
        if g.Name:match("^ollie_v128") then g:Destroy() end
    end
end)

local parentGui = CoreGui
pcall(function() parentGui = LP:WaitForChild("PlayerGui") end)

-- ═══════════════════════════════════════════════════════════════════════
-- C · config
-- ═══════════════════════════════════════════════════════════════════════
local ROOT   = "ollie_v128"
local ACTIVE = ROOT .. "/default.json"

local DEFAULT = {
    -- esp
    esp=true, box=true, boxStyle="full", boxFilled=false, boxThick=1,
    healthbar=true, healthGradient=true, name=true, distance=true,
    skeleton=true, tracer=true, headdot=false, toolname=true, velocity=false,
    espTeam=false, espMaxDist=2000, offY=0.7, offB=3.1,
    espTextScale=100,
    colEnemy={255,70,70}, colAlly={200,200,220}, colTracer={255,70,70},
    -- chams
    chams=false, chamsTeam=false, chamsTop=true,
    chamsFill={255,70,70}, chamsOutline={255,255,255}, chamsAlpha=40,
    -- aim
    aim=true, aimFov=180, aimSmooth=30, aimPredict=16, aimPart="Head",
    aimMode="closest", aimVisCheck=false, aimSticky=true, aimTeamCheck=true,
    aimFovRing=true, aimMaxDist=1500, aimJitter=2, aimHumanCurve=true,
    aimFovColor={255,90,90},
    -- silent
    silent=false, silentVis=false, silentHitbox="Head",
    silentPredict=16, silentFov=200, silentTeamCheck=true, silentHitchance=90,
    -- trigger
    trigger=false, triggerDelay=45, triggerHitchance=75,
    triggerFov=45, triggerHitbox="HumanoidRootPart", triggerTeamCheck=true,
    -- move
    walkspeed=32, jumppower=80, noclip=false, fly=false, flySpeed=60,
    infJump=false, fullbright=false, antiFling=true, antiFall=false,
    gravity=196.2, camFov=70,
    -- misc
    notifyOn=true, watermark=true, crosshair=true, crosshairColor={255,255,255},
    crosshairSize=8, crosshairGap=4, hudFps=true, hudPing=true, hudTime=true,
    autoClicker=false, autoClickCPS=10, camLock=false,
    -- ui
    guiX=20, guiY=20, guiOpen=true, guiTab="esp", guiCollapsed=false,
    guiScale=100,          -- NEW: 50–200 (%)
    fabX=20, fabY=200, fabVisible=true, fabPulse=true,
    fabScale=100,          -- NEW: 60–150 (%)
    -- touch
    touchControls=true,
    touchAimX=0.85, touchAimY=0.75,
    touchSilentX=0.85, touchSilentY=0.65,
    touchTriggerX=0.85, touchTriggerY=0.55,
    touchFlyX=0.85, touchFlyY=0.45,
    touchScale=100,        -- NEW: touch button scale 60–150 (%)
    -- data
    ignore={}, priority={},
    keybinds={},
}

local cfg = {}
local function deepclone(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = deepclone(x) end
    return c
end
for k, v in pairs(DEFAULT) do cfg[k] = deepclone(v) end

local function profilePath(name) return ROOT .. "/" .. tostring(name) .. ".json" end

local function saveCfg(name)
    name = name or "default"
    if not HAS_WRITE then return end
    pcall(function()
        if HAS_MKDIR then makefolder(ROOT) end
        writefile(profilePath(name), HttpService:JSONEncode(cfg))
    end)
end

local function loadCfg(name)
    name = name or "default"
    if not (HAS_WRITE and HAS_ISFILE) then return end
    pcall(function()
        if isfile(profilePath(name)) then
            local d = HttpService:JSONDecode(readfile(profilePath(name)))
            for k, v in pairs(d) do if DEFAULT[k] ~= nil then cfg[k] = v end end
        end
    end)
end

local function listProfiles()
    local out = {"default"}
    if not (HAS_LIST and HAS_WRITE) then return out end
    pcall(function()
        for _, f in ipairs(listfiles(ROOT)) do
            local m = f:match("([^/\\]+)%.json$")
            if m and m ~= "default" then table.insert(out, m) end
        end
    end)
    table.sort(out)
    return out
end

loadCfg("default")

local function rgb(t, a)
    if type(t) ~= "table" then return Color3.new(1,1,1), a or 255 end
    return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255), a or 255
end

-- ═══════════════════════════════════════════════════════════════════════
-- U · utils
-- ═══════════════════════════════════════════════════════════════════════
local function draw(class, props)
    if not HAS_DRAWING then return nil end
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props) do pcall(function() d[k] = v end) end
    return d
end

local function setD(d, props)
    if not d then return end
    for k, v in pairs(props) do pcall(function() d[k] = v end) end
end

local function getChar(plr)
    local c = plr.Character
    if not c then return nil end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("Humanoid")
end

local function w2s(p)
    local sp, on = Camera:WorldToViewportPoint(p)
    return Vector2.new(sp.X, sp.Y), on and sp.Z > 0
end

local function sameTeam(a, b)
    local ta, tb = a.Team, b.Team
    return ta ~= nil and ta == tb
end

local function partOf(char, name)
    return char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart")
end

local function inTable(t, v)
    if not t then return false end
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true
local function raycastVisible(part)
    if not part or not LP.Character then return false end
    visParams.FilterDescendantsInstances = {LP.Character, Camera}
    local hit = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, visParams)
    return hit == nil or hit.Instance:IsDescendantOf(part.Parent)
end

local function keyName(input) return tostring(input.KeyCode):gsub("Enum.KeyCode.", "") end

local SKEL = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local BONES = {"Head","UpperTorso","LowerTorso","HumanoidRootPart",
    "LeftUpperArm","RightUpperArm","LeftHand","RightHand"}

-- ═══════════════════════════════════════════════════════════════════════
-- N · notify
-- ═══════════════════════════════════════════════════════════════════════
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "ollie_v128_notif"
notifGui.ResetOnSpawn = false
notifGui.IgnoreGuiInset = true
notifGui.DisplayOrder = 9999
notifGui.Parent = parentGui

local notifHolder = Instance.new("Frame")
notifHolder.Size = UDim2.new(1, -40, 0, 260)
notifHolder.Position = UDim2.new(0, 20, 1, -280)
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = notifGui

local notifList = Instance.new("UIListLayout")
notifList.Padding = UDim.new(0, 8)
notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifList.SortOrder = Enum.SortOrder.LayoutOrder
notifList.Parent = notifHolder

local function notify(text, accent)
    if not cfg.notifyOn then return end
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    f.BackgroundTransparency = 0.05
    f.BorderSizePixel = 0
    f.Parent = notifHolder
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -8)
    bar.Position = UDim2.new(0, 2, 0, 4)
    bar.BackgroundColor3 = accent or Color3.fromRGB(140, 90, 240)
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = f

    f.Position = UDim2.new(1, 0, 0, 0)
    TweenService:Create(f, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position=UDim2.new(0, 0, 0, 0)}):Play()

    task.delay(3, function()
        local t = TweenService:Create(f, TweenInfo.new(0.25),
            {BackgroundTransparency=1, Position=UDim2.new(1, 0, 0, 0)})
        t:Play()
        t.Completed:Wait()
        f:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- S · velocity
-- ═══════════════════════════════════════════════════════════════════════
local vTrack, lastPos, lastT = {}, {}, os.clock()

-- ═══════════════════════════════════════════════════════════════════════
-- E · esp
-- ═══════════════════════════════════════════════════════════════════════
local espCache = {}
local fallbackGui, fallbackHolder

if not HAS_DRAWING then
    fallbackGui = Instance.new("ScreenGui")
    fallbackGui.Name = "ollie_v128_esp"
    fallbackGui.ResetOnSpawn = false
    fallbackGui.IgnoreGuiInset = true
    fallbackGui.DisplayOrder = 5
    fallbackGui.Parent = parentGui
    fallbackHolder = Instance.new("Frame")
    fallbackHolder.Size = UDim2.new(1,0,1,0)
    fallbackHolder.BackgroundTransparency = 1
    fallbackHolder.Parent = fallbackGui
end

local function buildEsp(plr)
    if plr == LP or espCache[plr] then return end
    if not HAS_DRAWING then
        local d = {}
        d.box = Instance.new("Frame", fallbackHolder)
        d.box.BackgroundTransparency = 1
        d.box.BorderSizePixel = 0
        d.box.Visible = false
        local s = Instance.new("UIStroke", d.box)
        s.Thickness = 1; s.Color = Color3.fromRGB(255,70,70)
        d.name = Instance.new("TextLabel", fallbackHolder)
        d.name.BackgroundTransparency = 1
        d.name.TextColor3 = Color3.fromRGB(255,255,255)
        d.name.Font = Enum.Font.GothamMedium
        d.name.TextSize = 12
        d.name.Visible = false
        d.name.Text = plr.Name
        espCache[plr] = d
        return
    end
    local d = {}
    d.box    = draw("Square",{Thickness=1,Filled=false,Visible=false})
    d.name   = draw("Text",  {Size=13,Center=true,Outline=true,Visible=false})
    d.hpBg   = draw("Square",{Thickness=0,Filled=true,Visible=false,Color=Color3.fromRGB(35,35,40)})
    d.hpFill = draw("Square",{Thickness=0,Filled=true,Visible=false})
    d.dist   = draw("Text",  {Size=12,Center=true,Outline=true,Color=Color3.fromRGB(200,200,200),Visible=false})
    d.tool   = draw("Text",  {Size=11,Center=true,Outline=true,Color=Color3.fromRGB(180,220,255),Visible=false})
    d.vel    = draw("Text",  {Size=11,Center=true,Outline=true,Color=Color3.fromRGB(200,160,255),Visible=false})
    d.tracer = draw("Line",  {Thickness=1,Visible=false})
    d.head   = draw("Circle",{Thickness=1,Filled=true,NumSides=16,Radius=3,Visible=false})
    d.skel   = {}
    for i = 1, #SKEL do d.skel[i] = draw("Line",{Thickness=2,Visible=false,Color=Color3.new(1,1,1)}) end
    d.corners = {}
    for i = 1, 8 do d.corners[i] = draw("Line",{Thickness=2,Visible=false}) end
    espCache[plr] = d
end

local function dropEsp(plr)
    local d = espCache[plr]
    if not d then return end
    for k, v in pairs(d) do
        if k == "skel" or k == "corners" then
            for _, l in ipairs(v) do pcall(function() l:Remove() end) end
        elseif HAS_DRAWING then pcall(function() v:Remove() end)
        else pcall(function() v:Destroy() end) end
    end
    espCache[plr] = nil
end

for _, p in ipairs(Players:GetPlayers()) do buildEsp(p) end
Players.PlayerAdded:Connect(buildEsp)
Players.PlayerRemoving:Connect(function(p)
    dropEsp(p); vTrack[p]=nil; lastPos[p]=nil
    local c = chamsCache[p]; if c then c:Destroy() end; chamsCache[p]=nil
end)

local function hideEsp(d)
    if HAS_DRAWING then
        setD(d.box,{Visible=false}); setD(d.name,{Visible=false})
        setD(d.hpBg,{Visible=false}); setD(d.hpFill,{Visible=false})
        setD(d.dist,{Visible=false}); setD(d.tool,{Visible=false}); setD(d.vel,{Visible=false})
        setD(d.tracer,{Visible=false}); setD(d.head,{Visible=false})
        for _, l in ipairs(d.skel) do setD(l,{Visible=false}) end
        for _, l in ipairs(d.corners) do setD(l,{Visible=false}) end
    else
        d.box.Visible = false; d.name.Visible = false
    end
end

local function renderEsp()
    local textMult = cfg.espTextScale / 100
    for plr, d in pairs(espCache) do
        local char, hrp, hum = getChar(plr)
        local ally = sameTeam(LP, plr)
        local ignored = inTable(cfg.ignore, plr.Name)
        if not (cfg.esp and char and hrp and hum and hum.Health > 0) or ignored
            or (ally and not cfg.espTeam)
            or (hrp.Position - Camera.CFrame.Position).Magnitude > cfg.espMaxDist then
            hideEsp(d); continue
        end

        local head = char:FindFirstChild("Head") or hrp
        local tl, tOn = w2s(head.Position + Vector3.new(0, cfg.offY, 0))
        local bl, bOn = w2s(hrp.Position - Vector3.new(0, cfg.offB, 0))
        if not (tOn or bOn) then hideEsp(d); continue end

        local col = ally and rgb(cfg.colAlly) or rgb(cfg.colEnemy)
        local priority = inTable(cfg.priority, plr.Name)
        local finalCol = priority and Color3.fromRGB(255,220,60) or col
        local h = math.abs(bl.Y - tl.Y)
        local w = h * 0.52
        local x, y = tl.X - w/2, tl.Y

        if HAS_DRAWING then
            if cfg.boxStyle == "corner" then
                setD(d.box,{Visible=false})
                local cw = w * 0.25
                local ch = h * 0.15
                setD(d.corners[1],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x,y), To=Vector2.new(x+cw,y)})
                setD(d.corners[2],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x,y), To=Vector2.new(x,y+ch)})
                setD(d.corners[3],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x+w,y), To=Vector2.new(x+w-cw,y)})
                setD(d.corners[4],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x+w,y), To=Vector2.new(x+w,y+ch)})
                setD(d.corners[5],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x,y+h), To=Vector2.new(x+cw,y+h)})
                setD(d.corners[6],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x,y+h), To=Vector2.new(x,y+h-ch)})
                setD(d.corners[7],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x+w,y+h), To=Vector2.new(x+w-cw,y+h)})
                setD(d.corners[8],{Visible=cfg.box, Color=finalCol, From=Vector2.new(x+w,y+h), To=Vector2.new(x+w,y+h-ch)})
            else
                for _, l in ipairs(d.corners) do setD(l,{Visible=false}) end
                setD(d.box,{Visible=cfg.box, Color=finalCol, Thickness=cfg.boxThick,
                    Filled=cfg.boxFilled, Size=Vector2.new(w,h), Position=Vector2.new(x,y)})
            end

            setD(d.name,{Visible=cfg.name, Color=finalCol,
                Size=math.floor(13*textMult),
                Position=Vector2.new(tl.X, y-16*textMult),
                Text=string.format("%s%s [%d]", priority and "★ " or "", plr.Name, math.floor(hum.Health))})

            if cfg.healthbar then
                local hp = math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                local bw = math.max(2, w*0.10)
                local bx = x - bw - 3
                setD(d.hpBg,{Visible=true,Size=Vector2.new(bw,h),Position=Vector2.new(bx,y)})
                local colHp
                if cfg.healthGradient then
                    colHp = Color3.fromRGB(math.floor(255*(1-hp)), math.floor(220*hp), math.floor(90+60*hp))
                else
                    colHp = Color3.fromRGB(60,220,90)
                end
                setD(d.hpFill,{Visible=true,Size=Vector2.new(bw, h*hp),
                    Position=Vector2.new(bx, y+h*(1-hp)), Color=colHp})
            else setD(d.hpBg,{Visible=false}); setD(d.hpFill,{Visible=false}) end

            if cfg.distance then
                setD(d.dist,{Visible=true, Size=math.floor(12*textMult),
                    Position=Vector2.new(tl.X,y+h+2*textMult),
                    Text=string.format("%dm", math.floor((hrp.Position-Camera.CFrame.Position).Magnitude))})
            else setD(d.dist,{Visible=false}) end

            if cfg.toolname then
                local tool = char:FindFirstChildOfClass("Tool")
                setD(d.tool,{Visible=tool ~= nil, Size=math.floor(11*textMult),
                    Position=Vector2.new(tl.X,y-30*textMult), Text=tool and tool.Name or ""})
            else setD(d.tool,{Visible=false}) end

            if cfg.velocity then
                local v = vTrack[plr] and vTrack[plr]["HumanoidRootPart"]
                setD(d.vel,{Visible=v ~= nil, Size=math.floor(11*textMult),
                    Position=Vector2.new(tl.X,y+h+16*textMult),
                    Text=v and string.format("%.0f st/s", v.Magnitude) or ""})
            else setD(d.vel,{Visible=false}) end

            if cfg.tracer then
                setD(d.tracer,{Visible=true,Color=rgb(cfg.colTracer),
                    From=Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y),
                    To=Vector2.new(tl.X, y+h)})
            else setD(d.tracer,{Visible=false}) end

            if cfg.headdot then
                setD(d.head,{Visible=true,Color=finalCol,Position=tl+Vector2.new(0,4)})
            else setD(d.head,{Visible=false}) end

            local idx = 0
            for _, pair in ipairs(SKEL) do
                idx += 1
                local line = d.skel[idx]
                local a, b = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                if line and cfg.skeleton and a and b then
                    local pa, oa = w2s(a.Position)
                    local pb, ob = w2s(b.Position)
                    if oa and ob then setD(line,{Visible=true,Color=finalCol,From=pa,To=pb})
                    else setD(line,{Visible=false}) end
                elseif line then setD(line,{Visible=false}) end
            end
        else
            d.box.Visible = cfg.box
            d.box.Position = UDim2.fromOffset(x,y)
            d.box.Size = UDim2.fromOffset(w,h)
            d.box.Stroke.Color = finalCol
            d.name.Visible = cfg.name
            d.name.Position = UDim2.new(0, tl.X-70, 0, y-18)
            d.name.Size = UDim2.fromOffset(140, 16)
            d.name.Text = plr.Name
            d.name.TextColor3 = finalCol
            d.name.TextSize = math.floor(12*textMult)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- H · chams
-- ═══════════════════════════════════════════════════════════════════════
chamsCache = {}

local function renderChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char, _, hum = getChar(plr)
        local existing = chamsCache[plr]
        local ally = sameTeam(LP, plr)
        local ignored = inTable(cfg.ignore, plr.Name)
        local want = cfg.chams and char and hum and hum.Health > 0
            and (cfg.chamsTeam or not ally) and not ignored

        if not want then
            if existing then existing:Destroy() chamsCache[plr] = nil end
            continue
        end

        if not existing or existing.Parent ~= char then
            if existing then existing:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Name = "ollie_cham"
            hl.DepthMode = cfg.chamsTop and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded
            hl.FillTransparency = cfg.chamsAlpha/100
            hl.OutlineTransparency = 0
            hl.FillColor = rgb(cfg.chamsFill)
            hl.OutlineColor = rgb(cfg.chamsOutline)
            hl.Adornee = char
            hl.Parent = char
            chamsCache[plr] = hl
        else
            existing.FillColor = rgb(cfg.chamsFill)
            existing.OutlineColor = rgb(cfg.chamsOutline)
            existing.FillTransparency = cfg.chamsAlpha/100
            existing.DepthMode = cfg.chamsTop and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- A · aimbot
-- ═══════════════════════════════════════════════════════════════════════
local aimHeld, sticky = false, nil
local humanAccel = {}

local fovRing = draw("Circle", {
    Thickness=1.5, Filled=false, NumSides=64,
    Color=Color3.fromRGB(255,255,255), Visible=false,
})

local function pickTarget()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if cfg.aimSticky and sticky then
        local char, hrp, hum = getChar(sticky)
        if char and hrp and hum and hum.Health > 0 then
            local p = partOf(char, cfg.aimPart)
            local sp, on = w2s(p.Position)
            if on and (sp - center).Magnitude <= cfg.aimFov * 1.4 then return sticky, p end
        end
        sticky = nil
    end
    local best, bestPart, bestScore = nil, nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP or inTable(cfg.ignore, plr.Name) then continue end
        local char, hrp, hum = getChar(plr)
        if not (char and hrp and hum and hum.Health > 0) then continue end
        if cfg.aimTeamCheck and sameTeam(LP, plr) then continue end
        if (hrp.Position - Camera.CFrame.Position).Magnitude > cfg.aimMaxDist then continue end
        local part = partOf(char, cfg.aimPart)
        local sp, on = w2s(part.Position)
        if not on then continue end
        local d = (sp - center).Magnitude
        if d > cfg.aimFov then continue end
        if cfg.aimVisCheck and not raycastVisible(part) then continue end
        local score = d
        if cfg.aimMode == "lowest" then score = hum.Health end
        if cfg.aimMode == "distance" then score = (hrp.Position - Camera.CFrame.Position).Magnitude end
        if inTable(cfg.priority, plr.Name) then score = score * 0.5 end
        if score < bestScore then best, bestPart, bestScore = plr, part, score end
    end
    if best and cfg.aimSticky then sticky = best end
    return best, bestPart
end

local function renderAim()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if cfg.aimFovRing and cfg.aim and fovRing then
        setD(fovRing,{Visible=true, Position=center, Radius=cfg.aimFov,
            Color=aimHeld and rgb(cfg.aimFovColor) or Color3.fromRGB(200,200,200)})
    elseif fovRing then fovRing.Visible = false end

    if not (cfg.aim and aimHeld) then return end
    local plr, part = pickTarget()
    if not part then return end
    local pos = part.Position
    local v = vTrack[plr] and vTrack[plr][part.Name]
    if v and cfg.aimPredict > 0 then pos = pos + v * (cfg.aimPredict/100) end
    if cfg.aimJitter > 0 then
        local j = cfg.aimJitter/100
        pos = pos + Vector3.new((math.random()-0.5)*j,(math.random()-0.5)*j,(math.random()-0.5)*j)
    end
    local goal = CFrame.new(Camera.CFrame.Position, pos)
    local base = math.clamp(cfg.aimSmooth/100, 0.01, 1)
    if cfg.aimHumanCurve then
        local a = humanAccel[plr] or 0
        a = math.min(1, a + 0.15)
        humanAccel[plr] = a
        base = base * (0.3 + a * 0.7)
    end
    Camera.CFrame = Camera.CFrame:Lerp(goal, base)
end

-- ═══════════════════════════════════════════════════════════════════════
-- Z · silent aim
-- ═══════════════════════════════════════════════════════════════════════
local silentOn = false

local function pickSilent()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestPart, bestDist = nil, nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP or inTable(cfg.ignore, plr.Name) then continue end
        local char, hrp, hum = getChar(plr)
        if not (char and hrp and hum and hum.Health > 0) then continue end
        if cfg.silentTeamCheck and sameTeam(LP, plr) then continue end
        local part = char:FindFirstChild(cfg.silentHitbox) or hrp
        local sp, on = w2s(part.Position)
        if not on then continue end
        local d = (sp - center).Magnitude
        if d > cfg.silentFov then continue end
        if cfg.silentVis and not raycastVisible(part) then continue end
        if inTable(cfg.priority, plr.Name) then d = d * 0.5 end
        if d < bestDist then best, bestPart, bestDist = plr, part, d end
    end
    return best, bestPart
end

local function silentGoal()
    if not (silentOn or cfg.silent) then return nil end
    local plr, part = pickSilent()
    if not part then return nil end
    local pos = part.Position
    local v = plr and vTrack[plr] and vTrack[plr][part.Name]
    if v and cfg.silentPredict > 0 then pos = pos + v * (cfg.silentPredict/100) end
    if math.random(1,100) > cfg.silentHitchance then return nil end
    return pos, part
end

if HAS_HOOK then
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, k)
            if self == game:GetService("Players").LocalPlayer:GetMouse() then
                local goal, part = silentGoal()
                if goal then
                    if k == "Hit" then return CFrame.new(goal) end
                    if k == "Target" then return part end
                    if k == "UnitRay" then
                        local o = Camera.CFrame.Position
                        return Ray.new(o, (goal - o).Unit * 5000)
                    end
                end
            end
            return oldIndex(self, k)
        end)
        setreadonly(mt, true)
    end)
end

if HAS_HOOK and HAS_NAMECALL then
    pcall(function()
        local mt = getrawmetatable(game)
        if mt.__namecall then
            local oldNC = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local m = getnamecallmethod()
                if m == "Raycast" or m == "FindPartOnRay"
                    or m == "FindPartOnRayWithIgnoreList"
                    or m == "FindPartOnRayWithWhitelist" then
                    local goal = silentGoal()
                    if goal then
                        local args = {...}
                        if m == "Raycast" and args[2] then
                            local dir = goal - args[1]
                            if dir.Magnitude > 0 then
                                args[2] = dir.Unit * (args[2].Magnitude or 5000)
                                return oldNC(self, table.unpack(args))
                            end
                        end
                    end
                end
                return oldNC(self, ...)
            end)
            setreadonly(mt, true)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- T · trigger
-- ═══════════════════════════════════════════════════════════════════════
local trigLast = 0
local function renderTrigger()
    if not cfg.trigger then return end
    local now = os.clock()
    if now - trigLast < cfg.triggerDelay/1000 then return end
    trigLast = now
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP or inTable(cfg.ignore, plr.Name) then continue end
        local char, hrp, hum = getChar(plr)
        if not (char and hrp and hum and hum.Health > 0) then continue end
        if cfg.triggerTeamCheck and sameTeam(LP, plr) then continue end
        local part = char:FindFirstChild(cfg.triggerHitbox) or hrp
        local sp, on = w2s(part.Position)
        if not on then continue end
        if (sp - center).Magnitude > cfg.triggerFov then continue end
        if raycastVisible(part) and math.random(1,100) <= cfg.triggerHitchance then
            pcall(function()
                VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2), Camera.CFrame)
            end)
            break
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- M · movement
-- ═══════════════════════════════════════════════════════════════════════
local flyBV, flyBG
local fullRestore = {}
local savedGravity

local function renderMove()
    local char, hrp, hum = getChar(LP)
    if not (char and hrp and hum) then return end
    hum.WalkSpeed = cfg.walkspeed
    hum.JumpPower = cfg.jumppower

    if cfg.noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    if cfg.infJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end

    if cfg.antiFall and hum:GetState() == Enum.HumanoidStateType.Freefall then
        if hrp.Velocity.Y < -20 then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
        end
    end

    if cfg.gravity ~= 196.2 then
        if not savedGravity then savedGravity = workspace.Gravity end
        workspace.Gravity = cfg.gravity
    elseif savedGravity then
        workspace.Gravity = savedGravity; savedGravity = nil
    end

    if cfg.camFov ~= 70 and Camera then Camera.FieldOfView = cfg.camFov end

    if cfg.antiFling then
        if hrp.Velocity.Magnitude > 500 then
            hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero
        end
    end

    if cfg.fly then
        hum.PlatformStand = true
        if not flyBV or flyBV.Parent ~= hrp then
            if flyBV then flyBV:Destroy() end
            if flyBG then flyBG:Destroy() end
            flyBV = Instance.new("BodyVelocity", hrp)
            flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
            flyBV.Velocity = Vector3.zero
            flyBG = Instance.new("BodyGyro", hrp)
            flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
            flyBG.P = 12000
        end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * cfg.flySpeed
        flyBG.CFrame = Camera.CFrame
    else
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum.PlatformStand then hum.PlatformStand = false end
    end

    if cfg.fullbright then
        if not Lighting:FindFirstChild("ollie_amb") then
            fullRestore.Amb = Lighting.Ambient
            fullRestore.Out = Lighting.OutdoorAmbient
            fullRestore.Bri = Lighting.Brightness
            fullRestore.Clk = Lighting.ClockTime
            local cc = Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "ollie_amb"; cc.Brightness = 0.35; cc.Contrast = 0.1
            Lighting.Ambient = Color3.fromRGB(180,180,180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
            Lighting.Brightness = 2
            Lighting.ClockTime = 12
        end
    else
        local cc = Lighting:FindFirstChild("ollie_amb")
        if cc then
            cc:Destroy()
            Lighting.Ambient = fullRestore.Amb or Lighting.Ambient
            Lighting.OutdoorAmbient = fullRestore.Out or Lighting.OutdoorAmbient
            Lighting.Brightness = fullRestore.Bri or Lighting.Brightness
            Lighting.ClockTime = fullRestore.Clk or Lighting.ClockTime
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- X · misc
-- ═══════════════════════════════════════════════════════════════════════
local lastClick = 0
local camLockTarget = nil

local chH = draw("Line", {Thickness=1, Visible=false})
local chV = draw("Line", {Thickness=1, Visible=false})
local chDot = draw("Circle", {Thickness=0, Filled=true, Radius=2, NumSides=12, Visible=false})

local function renderCrosshair()
    if not (cfg.crosshair and HAS_DRAWING) then
        if chH then chH.Visible = false end
        if chV then chV.Visible = false end
        if chDot then chDot.Visible = false end
        return
    end
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local sz, gap = cfg.crosshairSize, cfg.crosshairGap
    local col = rgb(cfg.crosshairColor)
    setD(chH,{Visible=true,Color=col,Thickness=1,
        From=c+Vector2.new(-sz-gap,0), To=c+Vector2.new(sz+gap,0)})
    setD(chV,{Visible=true,Color=col,Thickness=1,
        From=c+Vector2.new(0,-sz-gap), To=c+Vector2.new(0,sz+gap)})
    setD(chDot,{Visible=true,Color=col,Position=c,Radius=2})
end

local function renderMisc()
    if cfg.autoClicker then
        local now = os.clock()
        if now - lastClick >= 1/math.max(cfg.autoClickCPS,1) then
            lastClick = now
            pcall(function()
                VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2), Camera.CFrame)
            end)
        end
    end

    if cfg.camLock and camLockTarget then
        local char, hrp = getChar(camLockTarget)
        if char and hrp then
            Camera.CameraType = Enum.CameraType.Scriptable
            local goal = CFrame.new(hrp.Position + Vector3.new(0, 5, 8), hrp.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, 0.15)
        end
    elseif camLockTarget then
        camLockTarget = nil
        Camera.CameraType = Enum.CameraType.Custom
    end
end

local wmGui = Instance.new("ScreenGui")
wmGui.Name = "ollie_v128_wm"
wmGui.ResetOnSpawn = false
wmGui.IgnoreGuiInset = true
wmGui.Parent = parentGui

local wm = Instance.new("TextLabel")
wm.Size = UDim2.new(1, -20, 0, 22)
wm.Position = UDim2.new(0, 10, 0, 8)
wm.BackgroundTransparency = 1
wm.TextColor3 = Color3.fromRGB(230,230,240)
wm.Font = Enum.Font.GothamMedium
wm.TextSize = 12
wm.TextXAlignment = Enum.TextXAlignment.Left
wm.Text = "ollie v128"
wm.Parent = wmGui

local fpsAcc, fpsCount, fps = 0, 0, 0

task.spawn(function()
    while task.wait(0.5) do
        if cfg.watermark then
            wm.Visible = true
            local parts = {"ollie v128"}
            if cfg.hudFps then table.insert(parts, string.format("%d fps", math.floor(fps))) end
            if cfg.hudPing then
                local okp, ping = pcall(function() return LP:GetNetworkPing() end)
                table.insert(parts, string.format("%d ms", math.floor((okp and ping or 0)*1000)))
            end
            if cfg.hudTime then table.insert(parts, os.date("%H:%M:%S")) end
            wm.Text = table.concat(parts, "  ·  ")
        else wm.Visible = false end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- TOUCH · buttons with scale
-- ═══════════════════════════════════════════════════════════════════════
local touchGui = Instance.new("ScreenGui")
touchGui.Name = "ollie_v128_touch"
touchGui.ResetOnSpawn = false
touchGui.IgnoreGuiInset = true
touchGui.DisplayOrder = 40
touchGui.Parent = parentGui

local function makeTouchButton(label, x, y, color, onDown, onUp)
    local b = Instance.new("TextButton")
    local sz = math.floor(68 * (cfg.touchScale/100))
    b.Size = UDim2.fromOffset(sz, sz)
    b.Position = UDim2.new(x, 0, y, 0)
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.BackgroundColor3 = color or Color3.fromRGB(50, 40, 70)
    b.BackgroundTransparency = 0.15
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = math.floor(12 * (cfg.touchScale/100))
    b.Text = label
    b.AutoButtonColor = false
    b.Parent = touchGui
    Instance.new("UICorner", b).CornerRadius = UDim.new(0.5, 0)

    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(255,255,255)
    s.Thickness = 2
    s.Transparency = 0.4

    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            TweenService:Create(b, TweenInfo.new(0.12), {
                Size=UDim2.fromOffset(sz-8,sz-8),
                BackgroundColor3=Color3.fromRGB(140,90,240),
            }):Play()
            if onDown then onDown() end
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            TweenService:Create(b, TweenInfo.new(0.15), {
                Size=UDim2.fromOffset(sz,sz),
                BackgroundColor3=color or Color3.fromRGB(50,40,70),
            }):Play()
            if onUp then onUp() end
        end
    end)
    return b
end

local touchAim = makeTouchButton("AIM", cfg.touchAimX, cfg.touchAimY, Color3.fromRGB(60,40,70),
    function() aimHeld=true; sticky=nil end,
    function() aimHeld=false; sticky=nil end)

local touchSilent = makeTouchButton("SILENT", cfg.touchSilentX, cfg.touchSilentY, Color3.fromRGB(50,50,80),
    function() silentOn=true end,
    function() silentOn=false end)

local touchTrigger = makeTouchButton("TRIG", cfg.touchTriggerX, cfg.touchTriggerY, Color3.fromRGB(80,40,40),
    function() cfg.trigger=true end,
    function() cfg.trigger=false end)

local touchFly = makeTouchButton("FLY", cfg.touchFlyX, cfg.touchFlyY, Color3.fromRGB(50,70,60),
    function()
        cfg.fly = not cfg.fly
        notify("fly " .. (cfg.fly and "on" or "off"))
        saveCfg()
    end, nil)

local function updateTouchVisibility()
    local sz = math.floor(68 * (cfg.touchScale/100))
    touchAim.Visible = cfg.touchControls and cfg.aim
    touchSilent.Visible = cfg.touchControls and (cfg.silent or HAS_HOOK)
    touchTrigger.Visible = cfg.touchControls
    touchFly.Visible = cfg.touchControls
    touchAim.Position = UDim2.new(cfg.touchAimX, 0, cfg.touchAimY, 0)
    touchSilent.Position = UDim2.new(cfg.touchSilentX, 0, cfg.touchSilentY, 0)
    touchTrigger.Position = UDim2.new(cfg.touchTriggerX, 0, cfg.touchTriggerY, 0)
    touchFly.Position = UDim2.new(cfg.touchFlyX, 0, cfg.touchFlyY, 0)
    for _, b in ipairs({touchAim, touchSilent, touchTrigger, touchFly}) do
        b.Size = UDim2.fromOffset(sz, sz)
        b.TextSize = math.floor(12 * (cfg.touchScale/100))
    end
end
updateTouchVisibility()

-- ═══════════════════════════════════════════════════════════════════════
-- FAB with scale
-- ═══════════════════════════════════════════════════════════════════════
local fabGui = Instance.new("ScreenGui")
fabGui.Name = "ollie_v128_fab"
fabGui.ResetOnSpawn = false
fabGui.IgnoreGuiInset = true
fabGui.DisplayOrder = 100
fabGui.Parent = parentGui

local fab = Instance.new("TextButton")
local fabSize = math.floor(56 * (cfg.fabScale/100))
fab.Size = UDim2.fromOffset(fabSize, fabSize)
fab.Position = UDim2.new(0, cfg.fabX, 0, cfg.fabY)
fab.BackgroundColor3 = Color3.fromRGB(140, 90, 240)
fab.TextColor3 = Color3.fromRGB(255,255,255)
fab.Font = Enum.Font.GothamBold
fab.TextSize = math.floor(24 * (cfg.fabScale/100))
fab.Text = "O"
fab.AutoButtonColor = false
fab.Visible = cfg.fabVisible
fab.Parent = fabGui
Instance.new("UICorner", fab).CornerRadius = UDim.new(0.5, 0)

local fabStroke = Instance.new("UIStroke", fab)
fabStroke.Color = Color3.fromRGB(255,255,255)
fabStroke.Thickness = 3
fabStroke.Transparency = 0.3

local function applyFabScale()
    local s = math.floor(56 * (cfg.fabScale/100))
    fab.Size = UDim2.fromOffset(s, s)
    fab.TextSize = math.floor(24 * (cfg.fabScale/100))
end

if cfg.fabPulse then
    task.spawn(function()
        while fab and fab.Parent do
            if cfg.fabPulse and fab.Visible then
                TweenService:Create(fabStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {Transparency=0.7, Thickness=4}):Play()
                task.wait(1)
                TweenService:Create(fabStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {Transparency=0.3, Thickness=3}):Play()
                task.wait(1)
            else task.wait(0.5) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- G · main gui with UIScale
-- ═══════════════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "ollie_v128"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Enabled = cfg.guiOpen
gui.Parent = parentGui

local BASE_W = 360
local BASE_H_OPEN = 520
local BASE_H_CLOSED = 46

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(BASE_W, cfg.guiCollapsed and BASE_H_CLOSED or BASE_H_OPEN)
frame.Position = UDim2.new(0, cfg.guiX, 0, cfg.guiY)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.ClipsDescendants = true
frame.AnchorPoint = Vector2.new(0, 0)
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

-- NEW: UIScale — this is the whole point of v128
local uiScale = Instance.new("UIScale", frame)
uiScale.Scale = math.clamp(cfg.guiScale/100, 0.5, 2)

-- gradient bg
local bgGrad = Instance.new("UIGradient", frame)
bgGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 16, 32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
}
bgGrad.Rotation = 135

-- subtle glow behind frame
local glowGui = Instance.new("ScreenGui")
glowGui.Name = "ollie_v128_glow"
glowGui.ResetOnSpawn = false
glowGui.IgnoreGuiInset = true
glowGui.DisplayOrder = 59
glowGui.Parent = parentGui

local glow = Instance.new("Frame")
glow.Size = UDim2.new(1, 20, 1, 20)
glow.Position = UDim2.new(0, -10, 0, -10)
glow.BackgroundColor3 = Color3.fromRGB(140, 90, 240)
glow.BackgroundTransparency = 0.8
glow.BorderSizePixel = 0
glow.Parent = glowGui
Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 20)
local glowGrad = Instance.new("UIGradient", glow)
glowGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 90, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 200)),
}
glowGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.7),
    NumberSequenceKeypoint.new(0.5, 0.3),
    NumberSequenceKeypoint.new(1, 0.7),
}

-- title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleGrad = Instance.new("UIGradient", titleBar)
titleGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 60, 160)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 90, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 200)),
}
titleGrad.Rotation = 90

local titleCover = Instance.new("Frame")
titleCover.Size = UDim2.new(1, 0, 0, 8)
titleCover.Position = UDim2.new(0, 0, 1, -8)
titleCover.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
titleCover.BorderSizePixel = 0
titleCover.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -160, 1, 0)
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "ollie · v128"
titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 16
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

-- scale indicator pill in title bar
local scalePill = Instance.new("TextLabel")
scalePill.Size = UDim2.fromOffset(52, 24)
scalePill.Position = UDim2.new(1, -150, 0.5, -12)
scalePill.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
scalePill.TextColor3 = Color3.fromRGB(255,255,255)
scalePill.Font = Enum.Font.GothamBold
scalePill.TextSize = 11
scalePill.Text = math.floor(cfg.guiScale) .. "%"
scalePill.Parent = titleBar
Instance.new("UICorner", scalePill).CornerRadius = UDim.new(0, 8)

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.fromOffset(42, 42)
collapseBtn.Position = UDim2.new(1, -88, 0, 2)
collapseBtn.BackgroundTransparency = 1
collapseBtn.Text = "—"
collapseBtn.TextColor3 = Color3.fromRGB(255,255,255)
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 22
collapseBtn.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(42, 42)
closeBtn.Position = UDim2.new(1, -46, 0, 2)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,160,160)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = titleBar

-- gui drag
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        -- keep glow with frame
        local fp = frame.AbsolutePosition
        glow.Position = UDim2.new(0, fp.X - 10, 0, fp.Y - 10)
        glow.Size = UDim2.new(0, frame.AbsoluteSize.X + 20, 0, frame.AbsoluteSize.Y + 20)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            dragging = false
            cfg.guiX = math.floor(frame.AbsolutePosition.X)
            cfg.guiY = math.floor(frame.AbsolutePosition.Y)
            saveCfg()
        end
    end
end)

-- collapse
local collapsed = cfg.guiCollapsed
local function applyCollapse(animate)
    collapsed = not collapsed
    cfg.guiCollapsed = collapsed
    local targetH = collapsed and BASE_H_CLOSED or BASE_H_OPEN
    for _, v in ipairs(frame:GetChildren()) do
        if v ~= titleBar and v ~= bgGrad and v ~= uiScale and v:IsA("GuiObject") then
            v.Visible = not collapsed
        end
    end
    if animate then
        TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size=UDim2.fromOffset(BASE_W, targetH)}):Play()
    else
        frame.Size = UDim2.fromOffset(BASE_W, targetH)
    end
end
collapseBtn.MouseButton1Click:Connect(function() applyCollapse(true) end)
if collapsed then applyCollapse(false) end

closeBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
    glowGui.Enabled = false
    cfg.guiOpen = false
    fab.Visible = cfg.fabVisible
    saveCfg()
end)

fab.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        gui.Enabled = not gui.Enabled
        glowGui.Enabled = gui.Enabled
        cfg.guiOpen = gui.Enabled
        if gui.Enabled then
            local fp = frame.AbsolutePosition
            glow.Position = UDim2.new(0, fp.X - 10, 0, fp.Y - 10)
            glow.Size = UDim2.new(0, frame.AbsoluteSize.X + 20, 0, frame.AbsoluteSize.Y + 20)
        end
        saveCfg()
    end
end)

-- fab drag
local fabDrag, fabDragStart, fabStartPos, fabHoldStart, fabDragReady
fab.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        fabDrag = false
        fabDragStart = input.Position
        fabStartPos = fab.Position
        fabHoldStart = os.clock()
        fabDragReady = false
        task.delay(0.18, function()
            if fabDragStart then fabDragReady = true end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if fabDragReady and fabDragStart and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - fabDragStart
        if delta.Magnitude > 5 then
            fabDrag = true
            fab.Position = UDim2.new(fabStartPos.X.Scale, fabStartPos.X.Offset + delta.X,
                fabStartPos.Y.Scale, fabStartPos.Y.Offset + delta.Y)
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if fabDrag then
            cfg.fabX = math.floor(fab.AbsolutePosition.X)
            cfg.fabY = math.floor(fab.AbsolutePosition.Y)
            saveCfg()
        end
        fabDragStart = nil
        fabDragReady = false
    end
end)

-- search
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -16, 0, 36)
searchBox.Position = UDim2.new(0, 8, 0, 52)
searchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
searchBox.BorderSizePixel = 0
searchBox.PlaceholderText = "search…"
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(230,230,240)
searchBox.PlaceholderColor3 = Color3.fromRGB(120,120,150)
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 13
searchBox.ClearTextOnFocus = false
searchBox.Parent = frame
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 10)

-- tab bar
local tabBar = Instance.new("ScrollingFrame")
tabBar.Size = UDim2.new(1, -16, 0, 42)
tabBar.Position = UDim2.new(0, 8, 0, 94)
tabBar.BackgroundTransparency = 1
tabBar.ScrollBarThickness = 0
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.Parent = frame
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local pageHolder = Instance.new("Frame")
pageHolder.Size = UDim2.new(1, -16, 1, -146)
pageHolder.Position = UDim2.new(0, 8, 0, 142)
pageHolder.BackgroundTransparency = 1
pageHolder.Parent = frame

local pages, tabButtons = {}, {}

local function makePage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 6
    sf.ScrollBarImageColor3 = Color3.fromRGB(140,90,240)
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = pageHolder
    local l = Instance.new("UIListLayout", sf)
    l.Padding = UDim.new(0, 6); l.SortOrder = Enum.SortOrder.LayoutOrder
    local order = 0
    pages[name] = {frame=sf, next=function() order += 1; return order end}
end

local function makeTab(name, label)
    makePage(name)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(76, 36)
    b.BackgroundColor3 = Color3.fromRGB(30,30,45)
    b.TextColor3 = Color3.fromRGB(210,210,225)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Text = label
    b.AutoButtonColor = false
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function()
        for _, pg in pairs(pages) do pg.frame.Visible = false end
        for _, btn in pairs(tabButtons) do
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(30,30,45)}):Play()
        end
        pages[name].frame.Visible = true
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(100,60,180)}):Play()
        cfg.guiTab = name
    end)
    return b
end

-- widgets
local function holderFor(tab, label)
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, -8, 0, 44)
    h.BackgroundTransparency = 1
    h.LayoutOrder = pages[tab].next()
    h:SetAttribute("label", label or "")
    h.Parent = pages[tab].frame
    return h
end

local function toggleWidget(tab, label, key, onChange)
    local h = holderFor(tab, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = cfg[key] and Color3.fromRGB(50,120,65) or Color3.fromRGB(50,36,44)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.Text = "  " .. label
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(42, 22)
    pill.Position = UDim2.new(1, -52, 0.5, -11)
    pill.BackgroundColor3 = cfg[key] and Color3.fromRGB(120,220,140) or Color3.fromRGB(80,60,80)
    pill.BorderSizePixel = 0
    pill.Parent = b
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = cfg[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        b.BackgroundColor3 = cfg[key] and Color3.fromRGB(50,120,65) or Color3.fromRGB(50,36,44)
        pill.BackgroundColor3 = cfg[key] and Color3.fromRGB(120,220,140) or Color3.fromRGB(80,60,80)
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quart),
            {Position=cfg[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        if onChange then onChange(cfg[key]) end
        saveCfg()
    end)
end

local function sliderWidget(tab, label, key, min, max, scale, onChange)
    scale = scale or 1
    local h = holderFor(tab, label)
    h.Size = UDim2.new(1, -8, 0, 62)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 26)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220,220,235)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = string.format("  %s: %s", label, tostring(math.floor(cfg[key]*scale)))
    lbl.Parent = h

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, 0, 0, 28)
    bar.Position = UDim2.new(0, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40,40,55)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = h
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

    local fill = Instance.new("Frame")
    local rel = math.clamp((cfg[key]*scale - min)/math.max(max-min,1e-6), 0, 1)
    fill.Size = UDim2.new(rel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(140,90,240)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)

    local function upd(mx)
        local r = math.clamp((mx - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local v = min + r*(max-min)
        cfg[key] = v/scale
        fill.Size = UDim2.new(r, 0, 1, 0)
        lbl.Text = string.format("  %s: %s", label, tostring(math.floor(v)))
        if onChange then onChange(cfg[key]) end
    end

    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; upd(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            upd(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            if drag then drag = false; saveCfg() end
        end
    end)
end

local function cycleWidget(tab, label, key, options)
    local h = holderFor(tab, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(45,50,80)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    local idx = 1
    for i, o in ipairs(options) do if o == cfg[key] then idx = i end end
    b.Text = string.format("  %s: %s", label, tostring(cfg[key]))
    b.AutoButtonColor = false
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        cfg[key] = options[idx]
        b.Text = string.format("  %s: %s", label, tostring(cfg[key]))
        saveCfg()
    end)
end

local function colorWidget(tab, label, key)
    local h = holderFor(tab, label)
    h.Size = UDim2.new(1, -8, 0, 52)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(40,40,55)
    b.TextColor3 = Color3.fromRGB(230,230,240)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "  " .. label .. "  (tap to cycle)"
    b.AutoButtonColor = false
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local sw = Instance.new("Frame", b)
    sw.Size = UDim2.new(0, 42, 0, 28)
    sw.Position = UDim2.new(1, -52, 0.5, -14)
    sw.BackgroundColor3 = rgb(cfg[key])
    sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 8)
    local r, g, bl = cfg[key][1], cfg[key][2], cfg[key][3]
    b.MouseButton1Click:Connect(function()
        r = (r + 40) % 256
        if r == 0 then g = (g + 80) % 256 end
        if g == 0 and r == 0 then bl = (bl + 120) % 256 end
        cfg[key] = {r, g, bl}
        sw.BackgroundColor3 = Color3.fromRGB(r, g, bl)
        saveCfg()
    end)
end

local function buttonWidget(tab, label, cb, accent)
    local h = holderFor(tab, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = accent or Color3.fromRGB(70,45,60)
    b.TextColor3 = Color3.fromRGB(255,220,225)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "  " .. label
    b.AutoButtonColor = false
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(cb)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    for _, page in pairs(pages) do
        for _, child in ipairs(page.frame:GetChildren()) do
            if child:IsA("Frame") then
                local lbl = (child:GetAttribute("label") or ""):lower()
                child.Visible = (q == "") or lbl:find(q, 1, true) ~= nil
            end
        end
    end
end)

-- tabs
makeTab("esp","ESP"); makeTab("aim","AIM"); makeTab("sil","SIL")
makeTab("trg","TRIG"); makeTab("move","MOVE"); makeTab("misc","MISC")
makeTab("plr","PLR"); makeTab("ui","UI"); makeTab("cfg","CFG")

-- ESP page
toggleWidget("esp","enabled","esp")
toggleWidget("esp","box","box")
cycleWidget("esp","box style","boxStyle",{"full","corner"})
toggleWidget("esp","filled box","boxFilled")
toggleWidget("esp","health bar","healthbar")
toggleWidget("esp","hp gradient","healthGradient")
toggleWidget("esp","name","name")
toggleWidget("esp","distance","distance")
toggleWidget("esp","skeleton","skeleton")
toggleWidget("esp","tracer","tracer")
toggleWidget("esp","head dot","headdot")
toggleWidget("esp","tool name","toolname")
toggleWidget("esp","velocity","velocity")
toggleWidget("esp","show teammates","espTeam")
toggleWidget("esp","chams","chams")
toggleWidget("esp","chams on team","chamsTeam")
toggleWidget("esp","chams on top","chamsTop")
sliderWidget("esp","esp max dist","espMaxDist",100,5000)
sliderWidget("esp","box thickness","boxThick",1,4)
sliderWidget("esp","cham alpha x100","chamsAlpha",0,100,100)
sliderWidget("esp","esp text scale %","espTextScale",50,200)
colorWidget("esp","enemy color","colEnemy")
colorWidget("esp","ally color","colAlly")
colorWidget("esp","tracer color","colTracer")
colorWidget("esp","cham fill","chamsFill")
colorWidget("esp","cham outline","chamsOutline")

-- AIM
toggleWidget("aim","enabled","aim")
toggleWidget("aim","fov ring","aimFovRing")
toggleWidget("aim","visibility","aimVisCheck")
toggleWidget("aim","sticky target","aimSticky")
toggleWidget("aim","team check","aimTeamCheck")
toggleWidget("aim","human curve","aimHumanCurve")
cycleWidget("aim","mode","aimMode",{"closest","lowest","distance"})
cycleWidget("aim","part","aimPart",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("aim","fov","aimFov",10,800)
sliderWidget("aim","smooth x100","aimSmooth",1,100,100)
sliderWidget("aim","predict x100","aimPredict",0,60,100)
sliderWidget("aim","jitter x100","aimJitter",0,100,100)
sliderWidget("aim","max dist","aimMaxDist",100,5000)
colorWidget("aim","fov color","aimFovColor")

-- SILENT
toggleWidget("sil","silent aim","silent")
toggleWidget("sil","visibility","silentVis")
toggleWidget("sil","team check","silentTeamCheck")
cycleWidget("sil","hitbox","silentHitbox",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("sil","fov","silentFov",10,800)
sliderWidget("sil","predict x100","silentPredict",0,60,100)
sliderWidget("sil","hitchance %","silentHitchance",1,100)

-- TRIGGER
toggleWidget("trg","enabled","trigger")
toggleWidget("trg","team check","triggerTeamCheck")
cycleWidget("trg","hitbox","triggerHitbox",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("trg","fov","triggerFov",5,180)
sliderWidget("trg","delay ms","triggerDelay",0,250)
sliderWidget("trg","hitchance %","triggerHitchance",1,100)

-- MOVE
sliderWidget("move","walkspeed","walkspeed",16,400)
sliderWidget("move","jumppower","jumppower",50,500)
sliderWidget("move","fly speed","flySpeed",10,400)
sliderWidget("move","gravity","gravity",0,400)
sliderWidget("move","camera fov","camFov",40,120)
toggleWidget("move","noclip","noclip")
toggleWidget("move","fly","fly")
toggleWidget("move","infinite jump","infJump")
toggleWidget("move","fullbright","fullbright")
toggleWidget("move","anti-fling","antiFling")
toggleWidget("move","anti-fall","antiFall")

-- MISC
toggleWidget("misc","notifications","notifyOn")
toggleWidget("misc","watermark","watermark")
toggleWidget("misc","hud fps","hudFps")
toggleWidget("misc","hud ping","hudPing")
toggleWidget("misc","hud time","hudTime")
toggleWidget("misc","crosshair","crosshair")
toggleWidget("misc","auto clicker","autoClicker")
sliderWidget("misc","crosshair size","crosshairSize",4,30)
sliderWidget("misc","crosshair gap","crosshairGap",0,12)
sliderWidget("misc","auto cps","autoClickCPS",1,30)
colorWidget("misc","crosshair color","crosshairColor")
buttonWidget("misc","teleport to screen center",function()
    local char, hrp = getChar(LP)
    if not (char and hrp) then notify("no character") return end
    local p = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local ray = Camera:ViewportPointToRay(p.X, p.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local hit = workspace:Raycast(ray.Origin, ray.Direction*5000, params)
    if hit then hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0,3,0))
        notify("teleported") else notify("no hit") end
end)

-- PLAYER LIST
local plrListHolder = holderFor("plr","player list")
plrListHolder.Size = UDim2.new(1, -8, 0, 320)
local plrList = Instance.new("ScrollingFrame")
plrList.Size = UDim2.new(1, 0, 1, 0)
plrList.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
plrList.BorderSizePixel = 0
plrList.ScrollBarThickness = 3
plrList.CanvasSize = UDim2.new(0,0,0,0)
plrList.AutomaticCanvasSize = Enum.AutomaticSize.Y
plrList.Parent = plrListHolder
Instance.new("UICorner", plrList).CornerRadius = UDim.new(0, 10)
local plrLayout = Instance.new("UIListLayout", plrList)
plrLayout.Padding = UDim.new(0, 4)
plrLayout.Parent = plrList

local function refreshPlayerList()
    for _, c in ipairs(plrList:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 32)
        row.BackgroundColor3 = inTable(cfg.priority, plr.Name) and Color3.fromRGB(80,65,25)
            or inTable(cfg.ignore, plr.Name) and Color3.fromRGB(60,25,25)
            or Color3.fromRGB(32, 32, 46)
        row.BorderSizePixel = 0
        row.Parent = plrList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -140, 1, 0)
        nm.Position = UDim2.new(0, 8, 0, 0)
        nm.BackgroundTransparency = 1
        nm.TextColor3 = Color3.fromRGB(230,230,240)
        nm.Font = Enum.Font.GothamMedium
        nm.TextSize = 12
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.Text = plr.Name
        nm.Parent = row

        local function btn(label, x, cb, col)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 40, 1, -6)
            b.Position = UDim2.new(1, x, 0, 3)
            b.BackgroundColor3 = col or Color3.fromRGB(55,55,80)
            b.TextColor3 = Color3.fromRGB(255,255,255)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 11
            b.Text = label
            b.AutoButtonColor = false
            b.Parent = row
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
            b.MouseButton1Click:Connect(function() cb() refreshPlayerList() end)
        end
        btn("spec", -132, function() camLockTarget = plr; cfg.camLock = true end,
            Color3.fromRGB(60,80,60))
        btn("pri", -88, function()
            if inTable(cfg.priority, plr.Name) then
                for i, v in ipairs(cfg.priority) do if v == plr.Name then table.remove(cfg.priority, i) break end end
            else table.insert(cfg.priority, plr.Name) end
            saveCfg()
        end, Color3.fromRGB(90,75,35))
        btn("ign", -44, function()
            if inTable(cfg.ignore, plr.Name) then
                for i, v in ipairs(cfg.ignore) do if v == plr.Name then table.remove(cfg.ignore, i) break end end
            else table.insert(cfg.ignore, plr.Name) end
            saveCfg()
        end, Color3.fromRGB(90,40,40))
    end
end
refreshPlayerList()
Players.PlayerAdded:Connect(function() task.wait(0.2); refreshPlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2); refreshPlayerList() end)

-- UI page — the new star of the show
sliderWidget("ui","gui scale %","guiScale",50,200,1,function(v)
    uiScale.Scale = math.clamp(v/100, 0.5, 2)
    scalePill.Text = math.floor(v) .. "%"
end)
sliderWidget("ui","fab scale %","fabScale",60,150,1,function(v)
    applyFabScale()
end)
sliderWidget("ui","touch btn scale %","touchScale",60,150,1,function(v)
    updateTouchVisibility()
end)
toggleWidget("ui","show fab","fabVisible")
toggleWidget("ui","fab pulse","fabPulse")
toggleWidget("ui","show touch buttons","touchControls")
buttonWidget("ui","reset ui position",function()
    cfg.guiX, cfg.guiY = 20, 20
    frame.Position = UDim2.new(0, 20, 0, 20)
    saveCfg()
    notify("gui repositioned")
end, Color3.fromRGB(60,60,90))

-- Touch positioning on UI page too
sliderWidget("ui","aim btn X %","touchAimX",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","aim btn Y %","touchAimY",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","silent btn X %","touchSilentX",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","silent btn Y %","touchSilentY",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","trig btn X %","touchTriggerX",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","trig btn Y %","touchTriggerY",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","fly btn X %","touchFlyX",0,100,100,function() updateTouchVisibility() end)
sliderWidget("ui","fly btn Y %","touchFlyY",0,100,100,function() updateTouchVisibility() end)

task.spawn(function()
    while task.wait(0.5) do
        updateTouchVisibility()
        fab.Visible = cfg.fabVisible
    end
end)

-- CFG
buttonWidget("cfg","save to default profile",function() saveCfg("default") notify("saved to default") end,
    Color3.fromRGB(50,80,55))
buttonWidget("cfg","load default profile",function() loadCfg("default") notify("loaded default") end,
    Color3.fromRGB(50,70,90))
buttonWidget("cfg","new profile (typed)",function()
    local name = "profile_" .. tostring(math.floor(os.clock()))
    saveCfg(name)
    notify("saved as " .. name)
end, Color3.fromRGB(55,55,80))
buttonWidget("cfg","cycle profiles",function()
    local list = listProfiles()
    local idx = 1
    for i, n in ipairs(list) do if n == (cfg._activeProfile or "default") then idx = i end end
    idx = (idx % #list) + 1
    cfg._activeProfile = list[idx]
    loadCfg(list[idx])
    notify("profile · " .. list[idx])
end, Color3.fromRGB(60,50,90))
buttonWidget("cfg","reset to default",function()
    for k, v in pairs(DEFAULT) do cfg[k] = deepclone(v) end
    saveCfg("default")
    notify("reset — rejoin to apply")
end, Color3.fromRGB(80,40,40))
buttonWidget("cfg","rejoin server",function()
    pcall(function() TeleportService:Teleport(game.PlaceId) end)
end, Color3.fromRGB(60,50,80))

-- open saved tab
if pages[cfg.guiTab] then
    for _, pg in pairs(pages) do pg.frame.Visible = false end
    pages[cfg.guiTab].frame.Visible = true
    if tabButtons[cfg.guiTab] then
        tabButtons[cfg.guiTab].BackgroundColor3 = Color3.fromRGB(100,60,180)
    end
end

-- sync glow to frame on first show
task.defer(function()
    local fp = frame.AbsolutePosition
    glow.Position = UDim2.new(0, fp.X - 10, 0, fp.Y - 10)
    glow.Size = UDim2.new(0, frame.AbsoluteSize.X + 20, 0, frame.AbsoluteSize.Y + 20)
end)

-- ═══════════════════════════════════════════════════════════════════════
-- L · main loop
-- ═══════════════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    local now = os.clock()
    local delta = math.max(now - lastT, 1/240)
    lastT = now

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char then continue end
        local store = vTrack[p] or {}
        vTrack[p] = store
        local pos = lastPos[p] or {}
        lastPos[p] = pos
        for _, boneName in ipairs(BONES) do
            local b = char:FindFirstChild(boneName)
            if b then
                local prev = pos[boneName]
                if prev then store[boneName] = (b.Position - prev) / delta end
                pos[boneName] = b.Position
            end
        end
    end

    if delta > 0 then
        fpsAcc = fpsAcc + 1/delta; fpsCount = fpsCount + 1
        if fpsCount >= 12 then fps = fpsAcc/fpsCount; fpsAcc, fpsCount = 0, 0 end
    end

    -- glow follows frame live
    if gui.Enabled then
        local fp = frame.AbsolutePosition
        local fs = frame.AbsoluteSize
        glow.Position = UDim2.new(0, fp.X - 10, 0, fp.Y - 10)
        glow.Size = UDim2.new(0, fs.X + 20, 0, fs.Y + 20)
    end

    renderEsp()
    renderChams()
    renderAim()
    renderTrigger()
    renderCrosshair()
    renderMove()
    renderMisc()
end)

-- ═══════════════════════════════════════════════════════════════════════
-- boot
-- ═══════════════════════════════════════════════════════════════════════
notify("ollie v128 · ready · gui " .. math.floor(cfg.guiScale) .. "%")
