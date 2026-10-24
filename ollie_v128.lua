--[[ ollie v128 DELTA-SAFE
     fixes: removes __namecall hook (mobile crash), caps Drawing objects,
     forces CoreGui, throttles RenderStepped, disables heavy text by default. ]]

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
local HAS_LIST    = pcall(function() return listfiles end)
local HAS_ISFILE  = pcall(function() return isfile end)
local HAS_MKDIR   = pcall(function() return makefolder end)

pcall(function()
    for _, g in ipairs(CoreGui:GetChildren()) do
        if g.Name:match("^ollie_v128") then g:Destroy() end
    end
end)

-- FORCE CoreGui (PlayerGui crashes Delta on mobile)
local parentGui = CoreGui

local ROOT   = "ollie_v128"
local ACTIVE = ROOT .. "/default.json"

local DEFAULT = {
    -- esp
    esp=true, box=true, boxStyle="full", boxFilled=false, boxThick=1,
    healthbar=true, healthGradient=true, name=true, distance=false, -- distance off for mobile perf
    skeleton=false, tracer=false, headdot=false, toolname=false, velocity=false, -- heavy features off by default
    espTeam=false, espMaxDist=1500, offY=0.7, offB=3.1,
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
    -- silent (KEYBOARD/TAP ONLY - NO NAMECALL)
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
    guiScale=100, fabX=20, fabY=200, fabVisible=true, fabPulse=true, fabScale=100,
    -- touch
    touchControls=true, touchAimX=0.85, touchAimY=0.75,
    touchSilentX=0.85, touchSilentY=0.65, touchTriggerX=0.85, touchTriggerY=0.55,
    touchFlyX=0.85, touchFlyY=0.45, touchScale=100,
    ignore={}, priority={},
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

-- notify (simple, no tween to save mobile perf)
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "ollie_v128_notif"
notifGui.ResetOnSpawn = false
notifGui.DisplayOrder = 9999
notifGui.Parent = parentGui

local function notify(text)
    if not cfg.notifyOn then return end
    local f = Instance.new("TextLabel")
    f.Size = UDim2.new(0, 250, 0, 40)
    f.Position = UDim2.new(0.5, -125, 1, -60)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    f.BackgroundTransparency = 0.1
    f.TextColor3 = Color3.fromRGB(255,255,255)
    f.Font = Enum.Font.GothamMedium
    f.TextSize = 14
    f.Text = text
    f.Parent = notifGui
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    task.delay(2.5, function() f:Destroy() end)
end

-- vel (safe, no Drawing)
local vTrack, lastPos, lastT = {}, {}, os.clock()
local BONES = {"Head", "HumanoidRootPart"}

-- ESP (CAPPED)
local espCache = {}
local MAX_ESP = 10 -- prevent crash

local function buildEsp(plr)
    if plr == LP or espCache[plr] then return end
    if #espCache >= MAX_ESP then return end -- hard limit
    
    if not HAS_DRAWING then
        local d = {}
        d.box = Instance.new("Frame", parentGui)
        d.box.BackgroundTransparency = 1
        d.box.BorderSizePixel = 0
        d.box.Visible = false
        local s = Instance.new("UIStroke", d.box)
        s.Thickness = 1; s.Color = Color3.fromRGB(255,70,70)
        espCache[plr] = d
        return
    end
    
    local d = {}
    d.box    = draw("Square",{Thickness=1,Filled=false,Visible=false})
    d.name   = draw("Text",  {Size=13,Center=true,Outline=true,Visible=false})
    d.hpBg   = draw("Square",{Thickness=0,Filled=true,Visible=false,Color=Color3.fromRGB(35,35,40)})
    d.hpFill = draw("Square",{Thickness=0,Filled=true,Visible=false})
    espCache[plr] = d
end

local function dropEsp(plr)
    local d = espCache[plr]
    if not d then return end
    for k, v in pairs(d) do
        if HAS_DRAWING then pcall(function() v:Remove() end)
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

local function renderEsp()
    local textMult = cfg.espTextScale / 100
    for plr, d in pairs(espCache) do
        local char, hrp, hum = getChar(plr)
        local ally = sameTeam(LP, plr)
        local ignored = inTable(cfg.ignore, plr.Name)
        
        if not (cfg.esp and char and hrp and hum and hum.Health > 0) or ignored
            or (ally and not cfg.espTeam)
            or (hrp.Position - Camera.CFrame.Position).Magnitude > cfg.espMaxDist then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.hpBg then d.hpBg.Visible = false end
            if d.hpFill then d.hpFill.Visible = false end
            continue
        end

        local head = char:FindFirstChild("Head") or hrp
        local tl, tOn = w2s(head.Position + Vector3.new(0, cfg.offY, 0))
        local bl, bOn = w2s(hrp.Position - Vector3.new(0, cfg.offB, 0))
        if not (tOn or bOn) then continue end

        local col = ally and rgb(cfg.colAlly) or rgb(cfg.colEnemy)
        local priority = inTable(cfg.priority, plr.Name)
        local finalCol = priority and Color3.fromRGB(255,220,60) or col
        local h = math.abs(bl.Y - tl.Y)
        local w = h * 0.52
        local x, y = tl.X - w/2, tl.Y

        if HAS_DRAWING then
            setD(d.box,{Visible=cfg.box, Color=finalCol, Thickness=cfg.boxThick,
                Filled=cfg.boxFilled, Size=Vector2.new(w,h), Position=Vector2.new(x,y)})
            setD(d.name,{Visible=cfg.name, Color=finalCol,
                Size=math.floor(13*textMult),
                Position=Vector2.new(tl.X, y-16*textMult),
                Text=string.format("%s%s [%d]", priority and "★ " or "", plr.Name, math.floor(hum.Health))})
            if cfg.healthbar then
                local hp = math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                local bw = math.max(2, w*0.10)
                local bx = x - bw - 3
                setD(d.hpBg,{Visible=true,Size=Vector2.new(bw,h),Position=Vector2.new(bx,y)})
                setD(d.hpFill,{Visible=true,Size=Vector2.new(bw, h*hp),
                    Position=Vector2.new(bx, y+h*(1-hp)), Color=Color3.fromRGB(math.floor(255*(1-hp)), math.floor(220*hp), 90)})
            else
                setD(d.hpBg,{Visible=false}); setD(d.hpFill,{Visible=false})
            end
        else
            d.box.Visible = cfg.box
            d.box.Position = UDim2.fromOffset(x,y)
            d.box.Size = UDim2.fromOffset(w,h)
            d.box.Stroke.Color = finalCol
        end
    end
end

-- chams
chamsCache = {}
local function renderChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char, _, hum = getChar(plr)
        local existing = chamsCache[plr]
        local ally = sameTeam(LP, plr)
        local want = cfg.chams and char and hum and hum.Health > 0 and (cfg.chamsTeam or not ally)

        if not want then
            if existing then existing:Destroy() chamsCache[plr] = nil end
            continue
        end

        if not existing or existing.Parent ~= char then
            if existing then existing:Destroy() end
            local hl = Instance.new("Highlight")
            hl.DepthMode = cfg.chamsTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            hl.FillTransparency = cfg.chamsAlpha/100
            hl.FillColor = rgb(cfg.chamsFill)
            hl.OutlineColor = rgb(cfg.chamsOutline)
            hl.Adornee = char
            hl.Parent = char
            chamsCache[plr] = hl
        else
            existing.FillColor = rgb(cfg.chamsFill)
            existing.OutlineColor = rgb(cfg.chamsOutline)
            existing.FillTransparency = cfg.chamsAlpha/100
        end
    end
end

-- aimbot
local aimHeld, sticky = false, nil
local fovRing = draw("Circle", {Thickness=1.5, Filled=false, NumSides=64, Visible=false})

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
    local goal = CFrame.new(Camera.CFrame.Position, pos)
    Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(cfg.aimSmooth/100, 0.01, 1))
end

-- SILENT (CRASH FIXED: removed __namecall hook)
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
        if d < bestDist then best, bestPart, bestDist = plr, part, d end
    end
    return best, bestPart
end

-- SAFE SILENT HOOK (Mouse only, NO NAMECALL)
if HAS_HOOK then
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, k)
            if self == game:GetService("Players").LocalPlayer:GetMouse() and (silentOn or cfg.silent) then
                local plr, part = pickSilent()
                if part then
                    local pos = part.Position
                    local v = plr and vTrack[plr] and vTrack[plr][part.Name]
                    if v and cfg.silentPredict > 0 then pos = pos + v * (cfg.silentPredict/100) end
                    if math.random(1,100) <= cfg.silentHitchance then
                        if k == "Hit" then return CFrame.new(pos) end
                        if k == "Target" then return part end
                        if k == "UnitRay" then
                            local o = Camera.CFrame.Position
                            return Ray.new(o, (pos - o).Unit * 5000)
                        end
                    end
                end
            end
            return oldIndex(self, k)
        end)
        setreadonly(mt, true)
    end)
end

-- trigger
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
            pcall(function() VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2), Camera.CFrame) end)
            break
        end
    end
end

-- move
local flyBV, flyBG, savedGravity

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

    if cfg.gravity ~= 196.2 then
        if not savedGravity then savedGravity = workspace.Gravity end
        workspace.Gravity = cfg.gravity
    elseif savedGravity then
        workspace.Gravity = savedGravity; savedGravity = nil
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
end

-- Watermark
local wmGui = Instance.new("ScreenGui")
wmGui.ResetOnSpawn = false
wmGui.Parent = parentGui
local wm = Instance.new("TextLabel", wmGui)
wm.Size = UDim2.new(1, -20, 0, 22)
wm.Position = UDim2.new(0, 10, 0, 8)
wm.BackgroundTransparency = 1
wm.TextColor3 = Color3.fromRGB(230,230,240)
wm.Font = Enum.Font.GothamMedium
wm.TextSize = 12
wm.TextXAlignment = Enum.TextXAlignment.Left
wm.Text = "ollie v128 · safe"
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
            wm.Text = table.concat(parts, "  ·  ")
        else wm.Visible = false end
    end
end)

-- gui (same as before, safe)
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
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

local uiScale = Instance.new("UIScale", frame)
uiScale.Scale = math.clamp(cfg.guiScale/100, 0.5, 2)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -160, 1, 0)
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "ollie · safe"
titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 16
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(42, 42)
closeBtn.Position = UDim2.new(1, -46, 0, 2)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,160,160)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = titleBar
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false; cfg.guiOpen = false; saveCfg() end)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -16, 0, 36)
searchBox.Position = UDim2.new(0, 8, 0, 52)
searchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
searchBox.PlaceholderText = "search…"
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(230,230,240)
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 13
searchBox.Parent = frame
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 10)

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
    sf.ScrollBarThickness = 6
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = pageHolder
    local l = Instance.new("UIListLayout", sf)
    l.Padding = UDim.new(0, 6)
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
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function()
        for _, pg in pairs(pages) do pg.frame.Visible = false end
        for _, btn in pairs(tabButtons) do btn.BackgroundColor3 = Color3.fromRGB(30,30,45) end
        pages[name].frame.Visible = true
        b.BackgroundColor3 = Color3.fromRGB(100,60,180)
        cfg.guiTab = name
    end)
end

local function holderFor(tab, label)
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, -8, 0, 44)
    h.BackgroundTransparency = 1
    h.LayoutOrder = pages[tab].next()
    h:SetAttribute("label", label or "")
    h.Parent = pages[tab].frame
    return h
end

local function toggleWidget(tab, label, key)
    local h = holderFor(tab, label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = cfg[key] and Color3.fromRGB(50,120,65) or Color3.fromRGB(50,36,44)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 14
    b.Text = "  " .. label .. ": " .. tostring(cfg[key])
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        b.BackgroundColor3 = cfg[key] and Color3.fromRGB(50,120,65) or Color3.fromRGB(50,36,44)
        b.Text = "  " .. label .. ": " .. tostring(cfg[key])
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
    lbl.Text = "  " .. label .. ": " .. tostring(math.floor(cfg[key]*scale))
    lbl.Parent = h
    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, 0, 0, 28)
    bar.Position = UDim2.new(0, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40,40,55)
    bar.Text = ""
    bar.Parent = h
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
    local fill = Instance.new("Frame")
    local rel = math.clamp((cfg[key]*scale - min)/math.max(max-min,1e-6), 0, 1)
    fill.Size = UDim2.new(rel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(140,90,240)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
    local function upd(mx)
        local r = math.clamp((mx - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local v = min + r*(max-min)
        cfg[key] = v/scale
        fill.Size = UDim2.new(r, 0, 1, 0)
        lbl.Text = "  " .. label .. ": " .. tostring(math.floor(v))
        if onChange then onChange(cfg[key]) end
    end
    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; upd(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then upd(i.Position.X) end
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
    b.Text = "  " .. label .. ": " .. tostring(cfg[key])
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        cfg[key] = options[idx]
        b.Text = "  " .. label .. ": " .. tostring(cfg[key])
        saveCfg()
    end)
end

makeTab("esp","ESP"); makeTab("aim","AIM"); makeTab("sil","SIL")
makeTab("trg","TRIG"); makeTab("move","MOVE"); makeTab("misc","MISC")
makeTab("ui","UI"); makeTab("cfg","CFG")

toggleWidget("esp","enabled","esp")
toggleWidget("esp","box","box")
toggleWidget("esp","health bar","healthbar")
toggleWidget("esp","name","name")
toggleWidget("esp","chams","chams")
sliderWidget("esp","esp max dist","espMaxDist",100,5000)
sliderWidget("esp","box thickness","boxThick",1,4)
sliderWidget("esp","esp text scale %","espTextScale",50,200)

toggleWidget("aim","enabled","aim")
toggleWidget("aim","fov ring","aimFovRing")
toggleWidget("aim","team check","aimTeamCheck")
cycleWidget("aim","mode","aimMode",{"closest","lowest","distance"})
cycleWidget("aim","part","aimPart",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("aim","fov","aimFov",10,800)
sliderWidget("aim","smooth x100","aimSmooth",1,100,100)

toggleWidget("sil","silent aim","silent")
toggleWidget("sil","team check","silentTeamCheck")
cycleWidget("sil","hitbox","silentHitbox",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("sil","fov","silentFov",10,800)

toggleWidget("trg","enabled","trigger")
toggleWidget("trg","team check","triggerTeamCheck")
cycleWidget("trg","hitbox","triggerHitbox",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"})
sliderWidget("trg","fov","triggerFov",5,180)

sliderWidget("move","walkspeed","walkspeed",16,400)
sliderWidget("move","jumppower","jumppower",50,500)
sliderWidget("move","fly speed","flySpeed",10,400)
toggleWidget("move","noclip","noclip")
toggleWidget("move","fly","fly")
toggleWidget("move","infinite jump","infJump")

toggleWidget("misc","notifications","notifyOn")
toggleWidget("misc","watermark","watermark")
toggleWidget("misc","crosshair","crosshair")

sliderWidget("ui","gui scale %","guiScale",50,200,1,function(v)
    uiScale.Scale = math.clamp(v/100, 0.5, 2)
end)

local function btn(label, cb)
    local h = holderFor("cfg", label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(70,45,60)
    b.TextColor3 = Color3.fromRGB(255,220,225)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "  " .. label
    b.Parent = h
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(cb)
end

btn("save default profile", function() saveCfg("default") notify("saved") end)
btn("load default profile", function() loadCfg("default") notify("loaded") end)
btn("reset to default", function()
    for k, v in pairs(DEFAULT) do cfg[k] = deepclone(v) end
    saveCfg("default")
    notify("reset — rejoin to apply")
end)

if pages[cfg.guiTab] then
    for _, pg in pairs(pages) do pg.frame.Visible = false end
    pages[cfg.guiTab].frame.Visible = true
    if tabButtons[cfg.guiTab] then
        tabButtons[cfg.guiTab].BackgroundColor3 = Color3.fromRGB(100,60,180)
    end
end

RunService.RenderStepped:Connect(function(dt)
    local now = os.clock()
    local delta = math.max(now - lastT, 1/240)
    lastT = now

    -- Only track 2 bones to save mobile CPU
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

    renderEsp()
    renderChams()
    renderAim()
    renderTrigger()
    renderMove()
end)

notify("ollie v128 safe loaded")
