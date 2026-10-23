-- GALAXY PING LAGGER + Active On Steal
-- Clean Single Panel | Black + Purple | Background Selector | Minimize to Topbar

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local plr              = Players.LocalPlayer
local plrGui           = plr:WaitForChild("PlayerGui")

-- State
local laggerEnabled     = false
local listeningFor      = nil
local remote            = nil
local brainrotMode      = false
local lastBrainrotState = nil
local loopTask          = nil
local isMinimized       = false

-- Backgrounds
local BACKGROUNDS = {
    106344835483006,
    112180017939463,
    124053948669794,
    134260766475623,
}
local currentBgIndex = 2

-- ══════════════════════════════════════════════════════════════════════
-- DESTROY OLD GUI
-- ══════════════════════════════════════════════════════════════════════
for _, kid in pairs(plrGui:GetChildren()) do
    if kid.Name == "GalaxyLaggerGui" or kid.Name == "SharkLaggerGui" then kid:Destroy() end
end

local screen = Instance.new("ScreenGui")
screen.Name         = "GalaxyLaggerGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 15
screen.Parent       = plrGui

-- ══════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════
local CONFIG_FILE = "GalaxyPingLagger_Config.json"

local DEFAULT_CFG = {
    power         = 100000,
    interval      = 0.125,
    keybindKb     = "F",
    keybindGp     = "ButtonR2",
    autoBrainrot  = true,
    bgIndex       = 2,
}
local cfg = {
    power         = DEFAULT_CFG.power,
    interval      = DEFAULT_CFG.interval,
    keybindKb     = DEFAULT_CFG.keybindKb,
    keybindGp     = DEFAULT_CFG.keybindGp,
    autoBrainrot  = DEFAULT_CFG.autoBrainrot,
    bgIndex       = DEFAULT_CFG.bgIndex,
}

local function resolveKb(name)
    if not name or name == "" or name == "None" then return nil end
    local ok, val = pcall(function() return Enum.KeyCode[name] end)
    return (ok and val) or nil
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok and encoded and writefile then
        pcall(writefile, CONFIG_FILE, encoded)
    end
end

local function loadConfig()
    if not (isfile and readfile and isfile(CONFIG_FILE)) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok or type(data) ~= "table" then return end

    cfg.power         = tonumber(data.power) or DEFAULT_CFG.power
    cfg.interval      = tonumber(data.interval) or DEFAULT_CFG.interval
    cfg.keybindKb     = type(data.keybindKb) == "string" and data.keybindKb or DEFAULT_CFG.keybindKb
    cfg.keybindGp     = type(data.keybindGp) == "string" and data.keybindGp or DEFAULT_CFG.keybindGp
    cfg.autoBrainrot  = type(data.autoBrainrot) == "boolean" and data.autoBrainrot or DEFAULT_CFG.autoBrainrot
    cfg.bgIndex       = tonumber(data.bgIndex) or DEFAULT_CFG.bgIndex
    if cfg.bgIndex < 1 or cfg.bgIndex > #BACKGROUNDS then cfg.bgIndex = 1 end
    currentBgIndex = cfg.bgIndex
end

loadConfig()

-- ══════════════════════════════════════════════════════════════════════
-- COLOURS
-- ══════════════════════════════════════════════════════════════════════
local C = {
    bg      = Color3.fromRGB(8, 5, 14),
    card    = Color3.fromRGB(14, 9, 24),
    purp1   = Color3.fromRGB(95, 25, 175),
    purp2   = Color3.fromRGB(145, 50, 235),
    purp3   = Color3.fromRGB(185, 90, 255),
    white   = Color3.fromRGB(255, 255, 255),
    dim     = Color3.fromRGB(255, 255, 255), -- labels white
    green   = Color3.fromRGB(55, 225, 125),
    red     = Color3.fromRGB(255, 75, 95),
    waiting = Color3.fromRGB(255, 185, 55),
    inputBg = Color3.fromRGB(10, 6, 18),
}

-- ══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════════════
local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function isGamepad(kc)
    local n = kc.Name
    return n:sub(1,6)=="Button" or n:sub(1,10)=="Thumbstick" or n:sub(1,4)=="DPad" or n=="ButtonSelect" or n=="ButtonStart"
end

local BLACKLISTED = {
    [Enum.KeyCode.Escape] = true,
    [Enum.KeyCode.LeftControl] = true,
    [Enum.KeyCode.Unknown] = true,
}

-- ══════════════════════════════════════════════════════════════════════
-- MAIN FRAME
-- ══════════════════════════════════════════════════════════════════════
local MAIN_W, MAIN_H = 250, 345
local TOPBAR_H = 44

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
mainFrame.Position = UDim2.new(0.5, -MAIN_W/2, 0.5, -MAIN_H/2)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BackgroundTransparency = 1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screen
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 14)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = C.purp1
mainStroke.Thickness = 1.6
mainStroke.Transparency = 0.3

makeDraggable(mainFrame)

-- Background Image (fully visible, no black overlay)
local bgImage = Instance.new("ImageLabel", mainFrame)
bgImage.Name = "BackgroundImage"
bgImage.Size = UDim2.new(1, 0, 1, 0)
bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://" .. tostring(BACKGROUNDS[currentBgIndex])
bgImage.ImageTransparency = 0
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ZIndex = 1
Instance.new("UICorner", bgImage).CornerRadius = UDim.new(0, 14)

-- ══════════════════════════════════════════════════════════════════════
-- TOPBAR
-- ══════════════════════════════════════════════════════════════════════
local topbar = Instance.new("Frame", mainFrame)
topbar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
topbar.BackgroundColor3 = Color3.fromRGB(10, 5, 18)
topbar.BackgroundTransparency = 0.55
topbar.BorderSizePixel = 0
topbar.ZIndex = 10
Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 14)

-- Title
local titleImg = Instance.new("ImageLabel", topbar)
titleImg.Size = UDim2.new(1, -60, 1, -4)
titleImg.Position = UDim2.new(0, 4, 0, 2)
titleImg.BackgroundTransparency = 1
titleImg.Image = "rbxassetid://106568800047171"
titleImg.ScaleType = Enum.ScaleType.Fit
titleImg.ZIndex = 12

-- Minimize button (only the − , no contour)
local closeBtn = Instance.new("TextButton", topbar)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundTransparency = 1
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Text = "−"
closeBtn.TextColor3 = C.white
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 20
closeBtn.ZIndex = 13

closeBtn.MouseEnter:Connect(function() tw(closeBtn, {TextColor3 = C.purp3}, 0.1) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, {TextColor3 = C.white}, 0.1) end)

-- ══════════════════════════════════════════════════════════════════════
-- CONTENT
-- ══════════════════════════════════════════════════════════════════════
local content = Instance.new("Frame", mainFrame)
content.Size = UDim2.new(1, 0, 1, -TOPBAR_H)
content.Position = UDim2.new(0, 0, 0, TOPBAR_H)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ZIndex = 4

local function makeRow(y, h)
    local row = Instance.new("Frame", content)
    row.Size = UDim2.new(1, -22, 0, h or 34)
    row.Position = UDim2.new(0, 11, 0, y)
    row.BackgroundColor3 = C.card
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.ZIndex = 5
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local s = Instance.new("UIStroke", row)
    s.Color = C.purp1
    s.Thickness = 1
    s.Transparency = 0.65
    return row
end

local Y = 10
local GAP = 7

-- ── STATE ─────────────────────────────────────────────────────────────
local stateRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local stateLbl = Instance.new("TextLabel", stateRow)
stateLbl.Size = UDim2.new(0.4, 0, 1, 0)
stateLbl.Position = UDim2.new(0, 12, 0, 0)
stateLbl.BackgroundTransparency = 1
stateLbl.Text = "State"
stateLbl.TextColor3 = C.dim
stateLbl.Font = Enum.Font.GothamBold
stateLbl.TextSize = 12
stateLbl.TextXAlignment = Enum.TextXAlignment.Left
stateLbl.ZIndex = 6

local stateToggle = Instance.new("TextButton", stateRow)
stateToggle.Size = UDim2.new(0, 68, 0, 24)
stateToggle.Position = UDim2.new(1, -80, 0.5, -12)
stateToggle.BackgroundColor3 = C.inputBg
stateToggle.BackgroundTransparency = 0.15
stateToggle.BorderSizePixel = 0
stateToggle.AutoButtonColor = false
stateToggle.Text = "OFF"
stateToggle.TextColor3 = C.purp3
stateToggle.Font = Enum.Font.GothamBlack
stateToggle.TextSize = 11
stateToggle.ZIndex = 7
Instance.new("UICorner", stateToggle).CornerRadius = UDim.new(1, 0)

-- ── MODE (V1 / V2 / V3) ───────────────────────────────────────────────
local MODES = {
    { name = "V1", power = 72000 },
    { name = "V2", power = 100000 },
    { name = "V3", power = 120000 },
}
local currentMode = 2 -- default V2

-- detect current mode from saved power
for i, m in ipairs(MODES) do
    if cfg.power == m.power then
        currentMode = i
        break
    end
end
cfg.power = MODES[currentMode].power

local modeRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local modeLbl = Instance.new("TextLabel", modeRow)
modeLbl.Size = UDim2.new(0.3, 0, 1, 0)
modeLbl.Position = UDim2.new(0, 12, 0, 0)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "Mode"
modeLbl.TextColor3 = C.dim
modeLbl.Font = Enum.Font.GothamBold
modeLbl.TextSize = 12
modeLbl.TextXAlignment = Enum.TextXAlignment.Left
modeLbl.ZIndex = 6

local modeBtns = {}

local function updateModeButtons()
    for i, btn in ipairs(modeBtns) do
        if i == currentMode then
            btn.TextColor3 = C.white
            btn.BackgroundTransparency = 0.05
            btn.BackgroundColor3 = C.purp1
        else
            btn.TextColor3 = C.purp3
            btn.BackgroundTransparency = 0.15
            btn.BackgroundColor3 = C.inputBg
        end
    end
end

local function setMode(index)
    currentMode = index
    cfg.power = MODES[index].power
    updateModeButtons()
    saveConfig()
end

for i, m in ipairs(MODES) do
    local btn = Instance.new("TextButton", modeRow)
    btn.Size = UDim2.new(0, 42, 0, 24)
    btn.Position = UDim2.new(1, -140 + (i - 1) * 46, 0.5, -12)
    btn.BackgroundColor3 = C.inputBg
    btn.BackgroundTransparency = 0.15
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = m.name
    btn.TextColor3 = C.purp3
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 12
    btn.ZIndex = 7
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseButton1Click:Connect(function()
        setMode(i)
    end)

    modeBtns[i] = btn
end

updateModeButtons()

-- ── DELAY ─────────────────────────────────────────────────────────────
local delayRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local delayLbl = Instance.new("TextLabel", delayRow)
delayLbl.Size = UDim2.new(0.4, 0, 1, 0)
delayLbl.Position = UDim2.new(0, 12, 0, 0)
delayLbl.BackgroundTransparency = 1
delayLbl.Text = "Delay"
delayLbl.TextColor3 = C.dim
delayLbl.Font = Enum.Font.GothamBold
delayLbl.TextSize = 12
delayLbl.TextXAlignment = Enum.TextXAlignment.Left
delayLbl.ZIndex = 6

local delayBox = Instance.new("TextBox", delayRow)
delayBox.Size = UDim2.new(0, 96, 0, 24)
delayBox.Position = UDim2.new(1, -108, 0.5, -12)
delayBox.BackgroundColor3 = C.inputBg
delayBox.BackgroundTransparency = 0.15
delayBox.BorderSizePixel = 0
delayBox.Text = tostring(cfg.interval)
delayBox.TextColor3 = C.white
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 12
delayBox.ClearTextOnFocus = false
delayBox.ZIndex = 7
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 7)

local delayStroke = Instance.new("UIStroke", delayBox)
delayStroke.Color = C.purp1
delayStroke.Thickness = 1
delayStroke.Transparency = 0.45

delayBox.Focused:Connect(function() tw(delayStroke, {Color = C.purp3, Transparency = 0}, 0.1) end)
delayBox.FocusLost:Connect(function()
    tw(delayStroke, {Color = C.purp1, Transparency = 0.45}, 0.1)
    local n = tonumber(delayBox.Text)
    if n then
        cfg.interval = math.clamp(n, 0.001, 3)
        delayBox.Text = tostring(cfg.interval)
        saveConfig()
    else
        delayBox.Text = tostring(cfg.interval)
    end
end)

-- ── KEYBIND ───────────────────────────────────────────────────────────
local kbRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local kbLbl = Instance.new("TextLabel", kbRow)
kbLbl.Size = UDim2.new(0.4, 0, 1, 0)
kbLbl.Position = UDim2.new(0, 12, 0, 0)
kbLbl.BackgroundTransparency = 1
kbLbl.Text = "Keybind"
kbLbl.TextColor3 = C.dim
kbLbl.Font = Enum.Font.GothamBold
kbLbl.TextSize = 12
kbLbl.TextXAlignment = Enum.TextXAlignment.Left
kbLbl.ZIndex = 6

local kbBindBtn = Instance.new("TextButton", kbRow)
kbBindBtn.Size = UDim2.new(0, 96, 0, 24)
kbBindBtn.Position = UDim2.new(1, -108, 0.5, -12)
kbBindBtn.BackgroundColor3 = C.inputBg
kbBindBtn.BackgroundTransparency = 0.15
kbBindBtn.BorderSizePixel = 0
kbBindBtn.AutoButtonColor = false
kbBindBtn.Text = cfg.keybindKb ~= "" and cfg.keybindKb or "None"
kbBindBtn.TextColor3 = C.white
kbBindBtn.Font = Enum.Font.GothamBold
kbBindBtn.TextSize = 11
kbBindBtn.ZIndex = 7
Instance.new("UICorner", kbBindBtn).CornerRadius = UDim.new(0, 7)

local kbStroke = Instance.new("UIStroke", kbBindBtn)
kbStroke.Color = C.purp1
kbStroke.Thickness = 1
kbStroke.Transparency = 0.45

-- ── CONTROLLER ────────────────────────────────────────────────────────
local gpRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local gpLbl = Instance.new("TextLabel", gpRow)
gpLbl.Size = UDim2.new(0.45, 0, 1, 0)
gpLbl.Position = UDim2.new(0, 12, 0, 0)
gpLbl.BackgroundTransparency = 1
gpLbl.Text = "Controller"
gpLbl.TextColor3 = C.dim
gpLbl.Font = Enum.Font.GothamBold
gpLbl.TextSize = 12
gpLbl.TextXAlignment = Enum.TextXAlignment.Left
gpLbl.ZIndex = 6

local gpBindBtn = Instance.new("TextButton", gpRow)
gpBindBtn.Size = UDim2.new(0, 96, 0, 24)
gpBindBtn.Position = UDim2.new(1, -108, 0.5, -12)
gpBindBtn.BackgroundColor3 = C.inputBg
gpBindBtn.BackgroundTransparency = 0.15
gpBindBtn.BorderSizePixel = 0
gpBindBtn.AutoButtonColor = false
gpBindBtn.Text = cfg.keybindGp ~= "" and cfg.keybindGp or "None"
gpBindBtn.TextColor3 = C.white
gpBindBtn.Font = Enum.Font.GothamBold
gpBindBtn.TextSize = 11
gpBindBtn.ZIndex = 7
Instance.new("UICorner", gpBindBtn).CornerRadius = UDim.new(0, 7)

local gpStroke = Instance.new("UIStroke", gpBindBtn)
gpStroke.Color = C.purp1
gpStroke.Thickness = 1
gpStroke.Transparency = 0.45

-- ── ACTIVE ON STEAL ───────────────────────────────────────────────────
local stealRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local stealLbl = Instance.new("TextLabel", stealRow)
stealLbl.Size = UDim2.new(0.6, 0, 1, 0)
stealLbl.Position = UDim2.new(0, 12, 0, 0)
stealLbl.BackgroundTransparency = 1
stealLbl.Text = "Active On Steal"
stealLbl.TextColor3 = C.dim
stealLbl.Font = Enum.Font.GothamBold
stealLbl.TextSize = 12
stealLbl.TextXAlignment = Enum.TextXAlignment.Left
stealLbl.ZIndex = 6

local stealToggle = Instance.new("TextButton", stealRow)
stealToggle.Size = UDim2.new(0, 68, 0, 24)
stealToggle.Position = UDim2.new(1, -80, 0.5, -12)
stealToggle.BackgroundColor3 = C.inputBg
stealToggle.BackgroundTransparency = 0.15
stealToggle.BorderSizePixel = 0
stealToggle.AutoButtonColor = false
stealToggle.Text = cfg.autoBrainrot and "ON" or "OFF"
stealToggle.TextColor3 = C.purp3
stealToggle.Font = Enum.Font.GothamBlack
stealToggle.TextSize = 11
stealToggle.ZIndex = 7
Instance.new("UICorner", stealToggle).CornerRadius = UDim.new(1, 0)

-- ── BACKGROUND SELECTOR ───────────────────────────────────────────────
local bgRow = makeRow(Y, 34)
Y = Y + 34 + GAP

local bgLbl = Instance.new("TextLabel", bgRow)
bgLbl.Size = UDim2.new(0.4, 0, 1, 0)
bgLbl.Position = UDim2.new(0, 12, 0, 0)
bgLbl.BackgroundTransparency = 1
bgLbl.Text = "Background"
bgLbl.TextColor3 = C.dim
bgLbl.Font = Enum.Font.GothamBold
bgLbl.TextSize = 12
bgLbl.TextXAlignment = Enum.TextXAlignment.Left
bgLbl.ZIndex = 6

-- Left arrow
local bgLeft = Instance.new("TextButton", bgRow)
bgLeft.Size = UDim2.new(0, 26, 0, 24)
bgLeft.Position = UDim2.new(1, -108, 0.5, -12)
bgLeft.BackgroundColor3 = C.inputBg
bgLeft.BackgroundTransparency = 0.15
bgLeft.BorderSizePixel = 0
bgLeft.AutoButtonColor = false
bgLeft.Text = "◀"
bgLeft.TextColor3 = C.white
bgLeft.Font = Enum.Font.GothamBold
bgLeft.TextSize = 12
bgLeft.ZIndex = 7
Instance.new("UICorner", bgLeft).CornerRadius = UDim.new(0, 6)

-- Counter
local bgCounter = Instance.new("TextLabel", bgRow)
bgCounter.Size = UDim2.new(0, 42, 0, 24)
bgCounter.Position = UDim2.new(1, -78, 0.5, -12)
bgCounter.BackgroundColor3 = C.inputBg
bgCounter.BackgroundTransparency = 0.15
bgCounter.BorderSizePixel = 0
bgCounter.Text = currentBgIndex .. " / " .. #BACKGROUNDS
bgCounter.TextColor3 = C.white
bgCounter.Font = Enum.Font.GothamBold
bgCounter.TextSize = 11
bgCounter.ZIndex = 7
Instance.new("UICorner", bgCounter).CornerRadius = UDim.new(0, 6)

-- Right arrow
local bgRight = Instance.new("TextButton", bgRow)
bgRight.Size = UDim2.new(0, 26, 0, 24)
bgRight.Position = UDim2.new(1, -32, 0.5, -12)
bgRight.BackgroundColor3 = C.inputBg
bgRight.BackgroundTransparency = 0.15
bgRight.BorderSizePixel = 0
bgRight.AutoButtonColor = false
bgRight.Text = "▶"
bgRight.TextColor3 = C.white
bgRight.Font = Enum.Font.GothamBold
bgRight.TextSize = 12
bgRight.ZIndex = 7
Instance.new("UICorner", bgRight).CornerRadius = UDim.new(0, 6)

local function updateBackground()
    bgImage.Image = "rbxassetid://" .. tostring(BACKGROUNDS[currentBgIndex])
    bgCounter.Text = currentBgIndex .. " / " .. #BACKGROUNDS
    cfg.bgIndex = currentBgIndex
    saveConfig()
end

bgLeft.MouseButton1Click:Connect(function()
    currentBgIndex = currentBgIndex - 1
    if currentBgIndex < 1 then currentBgIndex = #BACKGROUNDS end
    updateBackground()
end)

bgRight.MouseButton1Click:Connect(function()
    currentBgIndex = currentBgIndex + 1
    if currentBgIndex > #BACKGROUNDS then currentBgIndex = 1 end
    updateBackground()
end)

-- ══════════════════════════════════════════════════════════════════════
-- MINIMIZE
-- ══════════════════════════════════════════════════════════════════════
local function setMinimized(state)
    isMinimized = state
    if isMinimized then
        content.Visible = false
        tw(mainFrame, {Size = UDim2.new(0, MAIN_W, 0, TOPBAR_H)}, 0.18)
        closeBtn.Text = "+"
    else
        content.Visible = true
        tw(mainFrame, {Size = UDim2.new(0, MAIN_W, 0, MAIN_H)}, 0.18)
        closeBtn.Text = "−"
    end
end

closeBtn.MouseButton1Click:Connect(function()
    setMinimized(not isMinimized)
end)

-- ══════════════════════════════════════════════════════════════════════
-- KEYBIND LABELS
-- ══════════════════════════════════════════════════════════════════════
local function updateKbLabels()
    if listeningFor == "kb" then
        kbBindBtn.Text = "Press key..."
        kbBindBtn.TextColor3 = C.waiting
        tw(kbStroke, {Color = C.waiting, Transparency = 0}, 0.1)
    else
        kbBindBtn.Text = cfg.keybindKb ~= "" and cfg.keybindKb or "None"
        kbBindBtn.TextColor3 = C.white
        tw(kbStroke, {Color = C.purp1, Transparency = 0.45}, 0.1)
    end

    if listeningFor == "gp" then
        gpBindBtn.Text = "Press btn..."
        gpBindBtn.TextColor3 = C.waiting
        tw(gpStroke, {Color = C.waiting, Transparency = 0}, 0.1)
    else
        gpBindBtn.Text = cfg.keybindGp ~= "" and cfg.keybindGp or "None"
        gpBindBtn.TextColor3 = C.white
        tw(gpStroke, {Color = C.purp1, Transparency = 0.45}, 0.1)
    end
end

kbBindBtn.MouseButton1Click:Connect(function()
    listeningFor = (listeningFor == "kb") and nil or "kb"
    updateKbLabels()
end)

gpBindBtn.MouseButton1Click:Connect(function()
    listeningFor = (listeningFor == "gp") and nil or "gp"
    updateKbLabels()
end)

stealToggle.MouseButton1Click:Connect(function()
    cfg.autoBrainrot = not cfg.autoBrainrot
    stealToggle.Text = cfg.autoBrainrot and "ON" or "OFF"
    stealToggle.TextColor3 = C.purp3
    saveConfig()
end)

-- ══════════════════════════════════════════════════════════════════════
-- LAGGER LOGIC
-- ══════════════════════════════════════════════════════════════════════
local function findRemote()
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if not rrs then return nil end
    local rem
    for _, name in ipairs({"SetPlayerBlockList","UpdatePlayerBlockList","SetBlockList","UpdateBlockList"}) do
        local r = rrs:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then rem = r break end
    end
    if not rem then
        for _, c in ipairs(rrs:GetChildren()) do
            if c:IsA("RemoteEvent") and c.Name:find("Block") then rem = c break end
        end
    end
    return rem
end

remote = findRemote()

local function buildPayload(power)
    local main = {}
    local nested = {{}}
    local current = nested[1]
    for _ = 1, 186 do
        local n = {}
        table.insert(current, n)
        current = n
    end
    local maxRep = math.min(math.floor(power / 188), 10000)
    for _ = 1, maxRep do
        table.insert(main, nested)
    end
    return main
end

local function toggleLagger(state)
    laggerEnabled = state

    if laggerEnabled then
        if not remote then
            remote = findRemote()
            if not remote then
                laggerEnabled = false
                toggleLagger(false)
                return
            end
        end

        stateToggle.Text = "ON"
        stateToggle.TextColor3 = C.purp3
        mainStroke.Color = C.purp3
        mainStroke.Transparency = 0.12

        local payload = buildPayload(cfg.power)

        if loopTask then task.cancel(loopTask) end
        loopTask = task.spawn(function()
            local currentDelay = cfg.interval
            while laggerEnabled do
                local ok = pcall(function()
                    remote:FireServer(payload)
                end)
                if not ok then
                    currentDelay = math.min(currentDelay * 1.5, 0.5)
                else
                    currentDelay = math.max(currentDelay * 0.995, 0.05)
                end
                task.wait(currentDelay)
            end
        end)
    else
        stateToggle.Text = "OFF"
        stateToggle.TextColor3 = C.purp3
        mainStroke.Color = C.purp1
        mainStroke.Transparency = 0.3

        if loopTask then
            task.cancel(loopTask)
            loopTask = nil
        end
    end
end

stateToggle.MouseButton1Click:Connect(function()
    toggleLagger(not laggerEnabled)
end)

-- ══════════════════════════════════════════════════════════════════════
-- ACTIVE ON STEAL
-- ══════════════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not cfg.autoBrainrot then
        if brainrotMode then
            brainrotMode = false
            lastBrainrotState = false
        end
        return
    end

    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    local hasBrainrot = hum.WalkSpeed < 25

    if lastBrainrotState == nil then
        lastBrainrotState = hasBrainrot
        brainrotMode = hasBrainrot
        return
    end

    if hasBrainrot and not lastBrainrotState then
        brainrotMode = true
        lastBrainrotState = true
        toggleLagger(true)
    elseif not hasBrainrot and lastBrainrotState then
        brainrotMode = false
        lastBrainrotState = false
        toggleLagger(false)
    end
end)

-- ══════════════════════════════════════════════════════════════════════
-- INPUT
-- ══════════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, processed)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Unknown then return end

    local isGp = isGamepad(kc)
    local isKb = input.UserInputType == Enum.UserInputType.Keyboard

    if listeningFor then
        if kc == Enum.KeyCode.Escape then
            listeningFor = nil
            updateKbLabels()
            return
        end
        if listeningFor == "kb" and isKb and not BLACKLISTED[kc] then
            cfg.keybindKb = kc.Name
            listeningFor = nil
            updateKbLabels()
            saveConfig()
            return
        end
        if listeningFor == "gp" and isGp then
            cfg.keybindGp = kc.Name
            listeningFor = nil
            updateKbLabels()
            saveConfig()
            return
        end
        return
    end

    if processed then return end

    if kc == Enum.KeyCode.LeftControl then
        setMinimized(not isMinimized)
        return
    end

    local kbEnum = resolveKb(cfg.keybindKb)
    local gpEnum = resolveKb(cfg.keybindGp)

    if (kbEnum and kc == kbEnum and isKb) or (gpEnum and kc == gpEnum and isGp) then
        toggleLagger(not laggerEnabled)
    end
end)

updateKbLabels()

task.spawn(function()
    while true do
        task.wait(5)
        saveConfig()
    end
end)
