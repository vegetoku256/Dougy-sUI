-- DougysUI mobile single-window library.
-- Desktop parity source: UI/DougysUI.lua. Keep the public API synchronized.

local UILib = {}
UILib.__index = UILib

-- Alias for backwards compatibility
local EclipseUI = UILib

--=============================================================================
-- ANTI-DETECTION SYSTEM
--=============================================================================
-- Generate random string for names to avoid detection
local function generateRandomName(length)
    length = length or math.random(8, 16)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""
    for i = 1, length do
        local idx = math.random(1, #chars)
        result = result .. chars:sub(idx, idx)
    end
    return result
end

-- Generate a unique ID for this session to avoid conflicts
local SESSION_ID = generateRandomName(8)

-- Stealth names - randomized each load
local StealthNames = {
    gui = generateRandomName(),
    splash = generateRandomName(),
    blur = generateRandomName(),
    container = generateRandomName(),
    panel = generateRandomName(),
    module = generateRandomName(),
}

--=============================================================================
-- SERVICES
--=============================================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local Player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local BLUR_ATTR = "_DUIBlur"

-- Try to use a protected GUI parent to avoid detection
local function getStealthParent()
    -- Try gethui first (most executors support this)
    if gethui then
        local success, result = pcall(gethui)
        if success and result then
            return result
        end
    end
    
    -- Try to protect the GUI
    if syn and syn.protect_gui then
        local gui = Instance.new("ScreenGui")
        syn.protect_gui(gui)
        gui.Parent = CoreGui
        return gui.Parent
    end
    
    -- Fallback to CoreGui but with random timing
    task.wait(math.random() * 0.1)
    return CoreGui
end

local StealthParent = getStealthParent()

local function copyToClipboard(text)
    local fns = { setclipboard, toclipboard }
    if syn and type(syn.write_clipboard) == "function" then
        table.insert(fns, syn.write_clipboard)
    end
    for i = 1, #fns do
        local fn = fns[i]
        if type(fn) == "function" then
            local ok = pcall(fn, text)
            if ok then
                return true
            end
        end
    end
    return false
end

local function reapOrphanFx(keepGui)
    pcall(function()
        if getgenv then
            local prev = getgenv()._DUIFxConn
            if prev then
                prev:Disconnect()
                getgenv()._DUIFxConn = nil
            end
        end
    end)
    local parents = {}
    local seen = {}
    local function addParent(p)
        if p and not seen[p] then
            seen[p] = true
            table.insert(parents, p)
        end
    end
    pcall(function()
        if gethui then
            addParent(gethui())
        end
    end)
    addParent(CoreGui)
    addParent(StealthParent)
    pcall(function()
        addParent(Player:FindFirstChild("PlayerGui"))
    end)
    for pi = 1, #parents do
        local parent = parents[pi]
        local kids = parent:GetChildren()
        for ki = 1, #kids do
            local child = kids[ki]
            if child:IsA("ScreenGui") and child ~= keepGui then
                local descs = child:GetDescendants()
                for di = 1, #descs do
                    if string.find(descs[di].Name, "_FxBg", 1, true) then
                        pcall(function()
                            child:Destroy()
                        end)
                        break
                    end
                end
            end
        end
    end
    pcall(function()
        local blurs = Lighting:GetChildren()
        for i = 1, #blurs do
            local b = blurs[i]
            if b:IsA("BlurEffect") then
                local tagged = false
                pcall(function()
                    tagged = b:GetAttribute(BLUR_ATTR) == true
                end)
                if tagged then
                    pcall(function()
                        b:Destroy()
                    end)
                end
            end
        end
    end)
end

--=============================================================================
-- CONFIGURATION
--=============================================================================
local Config = {
    panelWidth = 210,
    panelMinWidth = 180,
    panelMaxWidth = 350,
    headerHeight = 52,
    moduleHeight = 52,
    settingHeight = 48,
    padding = 6,
    cornerRadius = 10,
    controlRadius = 6,
    chipRadius = 4,
    animDuration = 0.12,
    notifyDuration = 3,
    isMobile = UIS.TouchEnabled,
    uiScale = 1.0,
    baseTextSize = 13,
    saveFileName = "DougysUI_Settings.dat", -- Fixed save file name for persistence
    debugMode = false,
}

local function pickFont(primary, fallback)
    local ok = pcall(function()
        local t = Instance.new("TextLabel")
        t.Font = primary
        t:Destroy()
    end)
    if ok then
        return primary
    end
    return fallback
end

local FONT_TITLE = pickFont(Enum.Font.BuilderSansBold, Enum.Font.GothamBold)
local FONT_BODY = pickFont(Enum.Font.BuilderSansMedium, Enum.Font.Gotham)
local FONT_VALUE = pickFont(Enum.Font.Code, Enum.Font.Code)
local FONT_ICON = pickFont(Enum.Font.GothamBold, Enum.Font.GothamBold)
local FONT_DROP = pickFont(Enum.Font.BuilderSans, Enum.Font.Gotham)
local CHEVRON_DN = "v"
local CHEVRON_UP = "^"

--=============================================================================
-- SETTINGS SAVE/LOAD SYSTEM
--=============================================================================
local SavedSettings = {
    theme = "Dark",
    notifyPosition = "TopRight",
    fpsCap = 60,
    toggleKey = "RightShift",
    debugMode = false,
    arrayListPosition = "Right",
    themeColoredText = false,
    backgroundMode = "Blur", -- Blur | Black | Snow | Rain | Stars | Matrix | Bubbles
    backgroundParticleDensity = 40, -- 15-500
    backgroundSpeed = 100, -- 20-300 percent
    backgroundSize = 100, -- 10-200 percent
    backgroundOpacity = 50, -- 10-100 percent
    backgroundDirection = "Down", -- Down | Up | Left | Right | Diagonal
    freecamSpeed = 60, -- 10-250
    freecamUpKey = "E",
    freecamDownKey = "Q",
    antiafkMethod = "M1 VirtualUser (Idled)",
    antiafkEnabled = false,
    showOpenHint = true, -- "Press <key> to open" when the menu is closed
    lowGraphics = false,
    noGraphics = false,
    pinnedPanels = {}, -- map of panel title -> boolean
    toggleStates = {}, -- Store toggle states per game: { [placeId] = { [moduleName] = true/false } }
    dropdownStates = {}, -- Store dropdown states per game: { [placeId] = { [dropdownName] = value } }
    inputStates = {}, -- Store input values per game: { [placeId] = { [inputName] = value } }
    -- Note: uiScale is NOT saved to prevent off-screen issues on reload
}

-- Helper function to get current game's PlaceId
local function getCurrentPlaceId()
    return tostring(game.PlaceId)
end

-- Helper function to get game-specific toggle states
local function getGameToggleStates()
    local placeId = getCurrentPlaceId()
    if not SavedSettings.toggleStates then
        SavedSettings.toggleStates = {}
    end
    if not SavedSettings.toggleStates[placeId] then
        SavedSettings.toggleStates[placeId] = {}
    end
    return SavedSettings.toggleStates[placeId]
end

-- Helper function to get game-specific dropdown states
local function getGameDropdownStates()
    local placeId = getCurrentPlaceId()
    if not SavedSettings.dropdownStates then
        SavedSettings.dropdownStates = {}
    end
    if not SavedSettings.dropdownStates[placeId] then
        SavedSettings.dropdownStates[placeId] = {}
    end
    return SavedSettings.dropdownStates[placeId]
end

-- Helper function to get game-specific input states
local function getGameInputStates()
    local placeId = getCurrentPlaceId()
    if not SavedSettings.inputStates then
        SavedSettings.inputStates = {}
    end
    if not SavedSettings.inputStates[placeId] then
        SavedSettings.inputStates[placeId] = {}
    end
    return SavedSettings.inputStates[placeId]
end

--=============================================================================
-- GLOBAL STATE FOR ARRAYLIST (tracks all enabled toggles)
--=============================================================================
local ActiveModules = {} -- { [name] = true/false }
local ArrayListSubscribers = {}

local function notifyArrayList()
    for _, fn in ipairs(ArrayListSubscribers) do
        pcall(fn, ActiveModules)
    end
end

local function setModuleActive(name, active)
    if active then
        ActiveModules[name] = true
    else
        ActiveModules[name] = nil
    end
    notifyArrayList()
end

--=============================================================================
-- DEBUG LOG
--=============================================================================
local DebugLogs = {}
local DebugSubscribers = {}

local function debugLog(msg)
    if not Config.debugMode then return end
    local entry = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(msg)
    table.insert(DebugLogs, entry)
    if #DebugLogs > 100 then table.remove(DebugLogs, 1) end
    for _, fn in ipairs(DebugSubscribers) do pcall(fn, entry) end
end

local function canSaveFiles()
    return writefile and readfile and isfile
end

local function loadSettings()
    if not canSaveFiles() then return SavedSettings end
    
    pcall(function()
        if isfile(Config.saveFileName) then
            local data = readfile(Config.saveFileName)
            local decoded = HttpService:JSONDecode(data)
            if decoded then
                for k, v in pairs(decoded) do
                    SavedSettings[k] = v
                end
            end
        end
        -- Ensure dropdownStates, toggleStates, and inputStates are initialized (they might not exist in old save files)
        if not SavedSettings.dropdownStates then
            SavedSettings.dropdownStates = {}
        end
        if not SavedSettings.toggleStates then
            SavedSettings.toggleStates = {}
        end
        if not SavedSettings.inputStates then
            SavedSettings.inputStates = {}
        end
        SavedSettings.lowGraphics = SavedSettings.lowGraphics == true
        SavedSettings.noGraphics = SavedSettings.noGraphics == true
        if type(SavedSettings.pinnedPanels) ~= "table" then
            SavedSettings.pinnedPanels = {}
        end
    end)
    
    return SavedSettings
end

local function saveSettings()
    if not canSaveFiles() then return false end
    
    local ok = pcall(function()
        local data = HttpService:JSONEncode(SavedSettings)
        writefile(Config.saveFileName, data)
    end)
    
    return ok
end

-- Load settings on start
loadSettings()

local VALID_BACKGROUND_MODES = {
    Blur = true, Black = true, Snow = true, Rain = true,
    Stars = true, Matrix = true, Bubbles = true,
}
local BACKGROUND_MODE_CYCLE = { "Blur", "Black", "Snow", "Rain", "Stars", "Matrix", "Bubbles" }
local VALID_BACKGROUND_DIRECTIONS = { Down = true, Up = true, Left = true, Right = true, Diagonal = true }
local ANIMATED_BACKGROUND_MODES = { Snow = true, Rain = true, Stars = true, Matrix = true, Bubbles = true }

local function normalizeBackgroundMode()
    local m = SavedSettings.backgroundMode
    if type(m) ~= "string" or not VALID_BACKGROUND_MODES[m] then
        SavedSettings.backgroundMode = "Blur"
    end
end
normalizeBackgroundMode()

local function normalizeBackgroundParticleDensity()
    local d = tonumber(SavedSettings.backgroundParticleDensity) or 40
    SavedSettings.backgroundParticleDensity = math.clamp(math.floor(d + 0.5), 15, 500)
end
normalizeBackgroundParticleDensity()

local function normalizeBackgroundSpeed()
    local v = tonumber(SavedSettings.backgroundSpeed) or 100
    SavedSettings.backgroundSpeed = math.clamp(math.floor(v + 0.5), 20, 300)
end
normalizeBackgroundSpeed()

local function normalizeBackgroundSize()
    local v = tonumber(SavedSettings.backgroundSize) or 100
    SavedSettings.backgroundSize = math.clamp(math.floor(v + 0.5), 10, 200)
end
normalizeBackgroundSize()

local function normalizeBackgroundOpacity()
    local v = tonumber(SavedSettings.backgroundOpacity) or 50
    SavedSettings.backgroundOpacity = math.clamp(math.floor(v + 0.5), 10, 100)
end
normalizeBackgroundOpacity()

local function normalizeBackgroundDirection()
    local d = SavedSettings.backgroundDirection
    if type(d) ~= "string" or not VALID_BACKGROUND_DIRECTIONS[d] then
        SavedSettings.backgroundDirection = "Down"
    end
end
normalizeBackgroundDirection()

local function normalizeFreecamSpeed()
    local v = tonumber(SavedSettings.freecamSpeed) or 60
    SavedSettings.freecamSpeed = math.clamp(math.floor(v + 0.5), 10, 250)
end
normalizeFreecamSpeed()

local function isValidKeyName(str)
    return type(str) == "string" and Enum.KeyCode[str] ~= nil
end

local function normalizeFreecamKeys()
    if not isValidKeyName(SavedSettings.freecamUpKey) then
        SavedSettings.freecamUpKey = "E"
    end
    if not isValidKeyName(SavedSettings.freecamDownKey) then
        SavedSettings.freecamDownKey = "Q"
    end
end
normalizeFreecamKeys()

local function keyFromName(name, fallback)
    if isValidKeyName(name) then
        return Enum.KeyCode[name]
    end
    return fallback
end

local ANTIAFK_METHOD_OPTIONS = {
    "M1 VirtualUser (Idled)",
    "M2 Click simulate",
    "M3 Nudge move + restore",
    "M4 Micro teleport",
}
local ANTIAFK_VALID = {}
for _, opt in ipairs(ANTIAFK_METHOD_OPTIONS) do
    ANTIAFK_VALID[opt] = true
end

local function normalizeAntiAfkMethod()
    if type(SavedSettings.antiafkMethod) ~= "string" or not ANTIAFK_VALID[SavedSettings.antiafkMethod] then
        SavedSettings.antiafkMethod = ANTIAFK_METHOD_OPTIONS[1]
    end
end
normalizeAntiAfkMethod()

if type(SavedSettings.antiafkEnabled) ~= "boolean" then
    SavedSettings.antiafkEnabled = false
end
if type(SavedSettings.showOpenHint) ~= "boolean" then
    SavedSettings.showOpenHint = true
end

SavedSettings.lowGraphics = SavedSettings.lowGraphics == true
SavedSettings.noGraphics = SavedSettings.noGraphics == true
if type(SavedSettings.pinnedPanels) ~= "table" then
    SavedSettings.pinnedPanels = {}
end

--=============================================================================
-- THEMES (each id recasts the whole shell, not just the accent)
--=============================================================================
local TEXT = Color3.fromRGB(242, 242, 242)
local TEXT_DIM = Color3.fromRGB(186, 186, 186)

local function makeTheme(name, accent, pal, animStyle)
    return {
        name = name,
        bg = pal.bg,
        overlay = Color3.fromRGB(0, 0, 0),
        panel = pal.panel,
        panelHeader = pal.header,
        accent = accent,
        accentDark = accent,
        text = pal.text,
        textDim = pal.textDim,
        enabled = accent,
        disabled = pal.stroke,
        hover = pal.hover,
        stroke = pal.stroke,
        divider = pal.divider,
        notification = accent,
        animStyle = animStyle or "Fade",
    }
end

local Themes = {
    ["Dark"] = makeTheme("Dark", Color3.fromRGB(224, 176, 48), {
        bg = Color3.fromRGB(16, 16, 18),
        panel = Color3.fromRGB(28, 26, 22),
        header = Color3.fromRGB(46, 36, 20),
        hover = Color3.fromRGB(54, 46, 30),
        divider = Color3.fromRGB(62, 52, 36),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Fade"),
    ["Impact"] = makeTheme("Impact", Color3.fromRGB(224, 80, 80), {
        bg = Color3.fromRGB(16, 15, 16),
        panel = Color3.fromRGB(32, 22, 22),
        header = Color3.fromRGB(50, 24, 24),
        hover = Color3.fromRGB(60, 32, 32),
        divider = Color3.fromRGB(68, 40, 32),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Slide"),
    ["Future"] = makeTheme("Future", Color3.fromRGB(110, 168, 224), {
        bg = Color3.fromRGB(15, 16, 18),
        panel = Color3.fromRGB(22, 26, 34),
        header = Color3.fromRGB(28, 40, 56),
        hover = Color3.fromRGB(38, 50, 66),
        divider = Color3.fromRGB(46, 56, 74),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Scale"),
    ["Meteor"] = makeTheme("Meteor", Color3.fromRGB(192, 128, 224), {
        bg = Color3.fromRGB(16, 15, 18),
        panel = Color3.fromRGB(26, 22, 34),
        header = Color3.fromRGB(42, 28, 50),
        hover = Color3.fromRGB(52, 36, 60),
        divider = Color3.fromRGB(60, 44, 68),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Fade"),
    ["Aristois"] = makeTheme("Aristois", Color3.fromRGB(224, 176, 80), {
        bg = Color3.fromRGB(16, 16, 15),
        panel = Color3.fromRGB(28, 26, 20),
        header = Color3.fromRGB(46, 38, 20),
        hover = Color3.fromRGB(54, 46, 28),
        divider = Color3.fromRGB(62, 52, 36),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Slide"),
    ["LiquidBounce"] = makeTheme("LiquidBounce", Color3.fromRGB(64, 192, 160), {
        bg = Color3.fromRGB(15, 17, 17),
        panel = Color3.fromRGB(20, 32, 30),
        header = Color3.fromRGB(24, 44, 40),
        hover = Color3.fromRGB(34, 54, 48),
        divider = Color3.fromRGB(42, 62, 56),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Fade"),
    ["Vape"] = makeTheme("Vape", Color3.fromRGB(128, 160, 208), {
        bg = Color3.fromRGB(15, 16, 18),
        panel = Color3.fromRGB(22, 26, 36),
        header = Color3.fromRGB(28, 38, 50),
        hover = Color3.fromRGB(38, 46, 60),
        divider = Color3.fromRGB(46, 54, 68),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Slide"),
    ["Wurst"] = makeTheme("Wurst", Color3.fromRGB(224, 128, 64), {
        bg = Color3.fromRGB(16, 15, 14),
        panel = Color3.fromRGB(32, 24, 18),
        header = Color3.fromRGB(50, 32, 18),
        hover = Color3.fromRGB(60, 40, 24),
        divider = Color3.fromRGB(68, 48, 32),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Fade"),
    ["Catppuccin"] = makeTheme("Catppuccin", Color3.fromRGB(224, 144, 176), {
        bg = Color3.fromRGB(16, 15, 17),
        panel = Color3.fromRGB(30, 22, 32),
        header = Color3.fromRGB(46, 28, 42),
        hover = Color3.fromRGB(56, 36, 50),
        divider = Color3.fromRGB(64, 44, 58),
        stroke = Color3.fromRGB(140, 140, 140),
        text = TEXT,
        textDim = TEXT_DIM,
    }, "Scale"),
}

-- Apply saved theme
local CurrentTheme = Themes[SavedSettings.theme] or Themes["Dark"]

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================
local function create(className, props, children)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    -- Auto-randomize Name if not explicitly set (stealth)
    if not props or not props.Name then
        inst.Name = generateRandomName(6)
    end
    if children then
        for _, child in ipairs(children) do
            if child then child.Parent = inst end
        end
    end
    return inst
end

local function makeRounded(obj, r)
    create("UICorner", { CornerRadius = UDim.new(0, r or Config.cornerRadius), Parent = obj })
end

local function roundTopBar(bar)
    makeRounded(bar, Config.cornerRadius)
    local cap = create("Frame", {
        BackgroundColor3 = bar.BackgroundColor3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Config.cornerRadius + 1),
        Position = UDim2.new(0, 0, 1, -(Config.cornerRadius + 1)),
        ZIndex = bar.ZIndex or 1,
        Parent = bar,
    })
    bar:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
        cap.BackgroundColor3 = bar.BackgroundColor3
    end)
    return cap
end

-- Hairline chrome. Round follows UICorner; miter boxes the control.
local OUTLINE = Color3.fromRGB(232, 232, 228)
local OUTLINE_THICK = 1
local OUTLINE_FADE = 0.4
local DESTROY_RED = Color3.fromRGB(216, 120, 112)

local function makeStroke(obj, color, thickness)
    local c = OUTLINE
    if color == DESTROY_RED then
        c = DESTROY_RED
    end
    local stroke = create("UIStroke", {
        Parent = obj,
        Color = c,
        Thickness = OUTLINE_THICK,
        Transparency = (color == DESTROY_RED) and 0 or OUTLINE_FADE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
    })
    return stroke
end

local function keycodeToString(kc)
    local str = tostring(kc)
    return str:match("([^%.]+)$") or str
end

local function stringToKeycode(str)
    return Enum.KeyCode[str] or Enum.KeyCode.RightShift
end

local function getTextSize(text, size, font)
    return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100))
end

local function tween(obj, props, duration, style, dir)
    local ti = TweenInfo.new(duration or Config.animDuration, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

local function scaled(value)
    return math.floor(value * Config.uiScale + 0.5)
end

--=============================================================================
-- FPS CAP HELPER
--=============================================================================
local function applyFpsCap(v)
    v = math.clamp(tonumber(v) or 60, 10, 500)
    local names = { "setfpscap", "set_fps_cap", "fpscap", "setfps" }
    for _, n in ipairs(names) do
        local fn = rawget(_G, n)
        if type(fn) == "function" then
            local ok = pcall(fn, v)
            if ok then return true end
        end
    end
    local envs = { getgenv and getgenv() or nil, _G, getrenv and getrenv() or nil, _ENV }
    for _, e in ipairs(envs) do
        if type(e) == "table" then
            for _, n in ipairs(names) do
                local fn = rawget(e, n)
                if type(fn) == "function" then
                    local ok = pcall(fn, v)
                    if ok then return true end
                end
            end
        end
    end
    if syn and type(syn.set_fps_cap) == "function" then
        local ok = pcall(syn.set_fps_cap, v)
        if ok then return true end
    end
    if type(setfflag) == "function" then
        local ok = pcall(function() setfflag("DFIntTaskSchedulerTargetFps", tostring(v)) end)
        if ok then return true end
    end
    return false
end

--=============================================================================
-- THEME SUBSCRIBERS (pub/sub for reactive theme changes)
--=============================================================================
local ThemeSubscribers = {}
local function subscribeTheme(fn)
    table.insert(ThemeSubscribers, fn)
    return fn
end
local function publishTheme(theme)
    CurrentTheme = theme
    for _, fn in ipairs(ThemeSubscribers) do
        pcall(fn, theme)
    end
end

local function themedTextColor(t)
    t = t or CurrentTheme
    if SavedSettings.themeColoredText then
        return t.accent
    end
    return t.text
end

--=============================================================================
-- HOVER STATE TRACKER (for fixing theme change hover bug)
--=============================================================================
local HoverStates = {}
local function trackHover(element, baseColor, hoverColor)
    HoverStates[element] = {
        isHovered = false,
        baseColor = baseColor,
        hoverColor = hoverColor,
    }
    
    element.MouseEnter:Connect(function()
        if HoverStates[element] then
            HoverStates[element].isHovered = true
            tween(element, { BackgroundColor3 = HoverStates[element].hoverColor }, 0.08)
        end
    end)
    
    element.MouseLeave:Connect(function()
        if HoverStates[element] then
            HoverStates[element].isHovered = false
            tween(element, { BackgroundColor3 = HoverStates[element].baseColor }, 0.08)
        end
    end)
    
    return HoverStates[element]
end

local function updateHoverColors(element, baseColor, hoverColor)
    if HoverStates[element] then
        HoverStates[element].baseColor = baseColor
        HoverStates[element].hoverColor = hoverColor
        if HoverStates[element].isHovered then
            element.BackgroundColor3 = hoverColor
        else
            element.BackgroundColor3 = baseColor
        end
    end
end

local function makeSeam(parent, edge)
    local f = create("Frame", {
        BackgroundColor3 = CurrentTheme.divider or CurrentTheme.hover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = (parent.ZIndex or 1) + 1,
        Parent = parent,
    })
    if edge == "left" then
        f.Size = UDim2.new(0, 1, 1, 0)
        f.Position = UDim2.fromOffset(0, 0)
    elseif edge == "right" then
        f.AnchorPoint = Vector2.new(1, 0)
        f.Size = UDim2.new(0, 1, 1, 0)
        f.Position = UDim2.new(1, 0, 0, 0)
    else
        f.AnchorPoint = Vector2.new(0, 1)
        f.Size = UDim2.new(1, 0, 0, 1)
        f.Position = UDim2.new(0, 0, 1, 0)
    end
    subscribeTheme(function(t)
        if f and f.Parent then
            f.BackgroundColor3 = t.divider or t.hover
        end
    end)
    return f
end

local focusSeq = 0

local function applyFocusStyle(obj, order)
    if not obj then
        return
    end
    pcall(function()
        obj.Selectable = true
        obj.AutoButtonColor = false
    end)
    if type(order) ~= "number" then
        focusSeq = focusSeq + 1
        order = focusSeq
    end
    pcall(function()
        obj.SelectionOrder = order
    end)
    local img = Instance.new("Frame")
    img.Name = generateRandomName(6)
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(1, 4, 1, 4)
    img.Position = UDim2.fromOffset(-2, -2)
    local st = Instance.new("UIStroke")
    st.Thickness = 2
    st.Color = CurrentTheme.accent
    st.Transparency = 0
    st.Parent = img
    obj.SelectionImageObject = img
    subscribeTheme(function(t)
        if st and st.Parent then
            st.Color = t.accent
        end
    end)
    return img
end

local function bindActivate(obj, fn)
    applyFocusStyle(obj)
    if obj and obj:IsA("GuiButton") then
        obj.Activated:Connect(fn)
    end
end

local function createStateCell(parent, enabled, opts)
    opts = opts or {}
    local mode = opts.mode or "mark"
    local h = opts.size or 14
    local w = h
    if mode == "switch" then
        w = opts.width or 40
        h = opts.size or 24
    end
    local cell = create("Frame", {
                BackgroundColor3 = enabled and CurrentTheme.accent or CurrentTheme.stroke,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(w, h),
        Position = opts.position,
        AnchorPoint = opts.anchor,
        ZIndex = opts.zIndex or 2,
        Parent = parent,
    })
    makeRounded(cell, mode == "switch" and math.floor(h / 2) or 4)
    local stroke = create("UIStroke", {
        Color = OUTLINE,
        Thickness = OUTLINE_THICK,
        Transparency = OUTLINE_FADE,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
        Parent = cell,
    })
    local knobM = 2
    local knobH = math.max(8, h - knobM * 2)
    local knob = create("Frame", {
        BackgroundColor3 = CurrentTheme.bg,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(knobH, knobH),
        Position = enabled and UDim2.fromOffset(w - knobH - knobM, knobM) or UDim2.fromOffset(knobM, knobM),
        Visible = mode == "switch",
        ZIndex = (opts.zIndex or 2) + 1,
        Parent = cell,
    })
    makeRounded(knob, math.floor(knobH / 2))
    local tickSz = math.max(4, h - 8)
    local tick = create("Frame", {
        BackgroundColor3 = CurrentTheme.text,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(tickSz, tickSz),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Visible = mode ~= "switch" and enabled == true,
        ZIndex = (opts.zIndex or 2) + 1,
        Parent = cell,
    })
    makeRounded(tick, 2)
    local state = enabled and true or false
    local api = {}
    local function layout(animate)
        local t = CurrentTheme
        stroke.Color = OUTLINE
        tick.BackgroundColor3 = t.bg
        if mode == "switch" then
            knob.Visible = true
            tick.Visible = false
            knob.BackgroundColor3 = t.bg
            local pos = state and UDim2.fromOffset(w - knobH - knobM, knobM) or UDim2.fromOffset(knobM, knobM)
            if animate == false then
                cell.BackgroundColor3 = state and t.accent or t.stroke
                cell.BackgroundTransparency = 0
                knob.Position = pos
            else
                tween(cell, { BackgroundColor3 = state and t.accent or t.stroke }, 0.10)
                tween(knob, { Position = pos }, 0.10)
            end
        else
            knob.Visible = false
            tick.Visible = state
            if animate == false then
                cell.BackgroundColor3 = state and t.accent or t.stroke
                cell.BackgroundTransparency = 0
            else
                tween(cell, {
                    BackgroundColor3 = state and t.accent or t.stroke,
                    BackgroundTransparency = 0,
                }, 0.10)
            end
        end
    end
    function api:Set(on, animate)
        state = on and true or false
        layout(animate)
    end
    function api:Paint(t)
        t = t or CurrentTheme
        stroke.Color = OUTLINE
        tick.BackgroundColor3 = t.bg
        if mode == "switch" then
            cell.BackgroundColor3 = state and t.accent or t.stroke
            cell.BackgroundTransparency = 0
            knob.BackgroundColor3 = t.bg
        else
            cell.BackgroundColor3 = state and t.accent or t.stroke
            cell.BackgroundTransparency = 0
            tick.Visible = state
        end
    end
    function api:Get()
        return state
    end
    api.Instance = cell
    api.Width = w
    api.Height = h
    subscribeTheme(function(t)
        api:Paint(t)
    end)
    layout(false)
    return api
end

local function createPinGlyph(parent, color)
    local box = create("Frame", {
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(8, 8),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Parent = parent,
    })
    makeRounded(box, 2)
    local api = { Root = box }
    function api:Paint(c)
        box.BackgroundColor3 = c
    end
    return api
end

local function styleField(obj)
    obj.BackgroundColor3 = CurrentTheme.bg
    obj.BorderSizePixel = 0
    makeRounded(obj, Config.controlRadius)
    local st = makeStroke(obj, CurrentTheme.stroke)
    return st
end

--=============================================================================
-- INITIAL LOAD FLAG (suppress notifications on startup)
--=============================================================================
local isInitialLoad = true
task.spawn(function()
    task.wait(3) -- Allow 3 seconds for initial load
    isInitialLoad = false
end)

--=============================================================================
-- MAIN WINDOW CREATION
--=============================================================================
function UILib:CreateWindow(cfg)
    cfg = cfg or {}
    
    -- Apply saved or configured theme
    local themeName = SavedSettings.theme or cfg.Theme or "Dark"
    if Themes[themeName] then
        CurrentTheme = Themes[themeName]
    end
    
    local theme = CurrentTheme
    local toggleKey = stringToKeycode(SavedSettings.toggleKey) or cfg.ToggleKey or Enum.KeyCode.RightShift
    local notifyPosition = SavedSettings.notifyPosition or cfg.NotifyPosition or "TopRight"
    local overlayOpacity = cfg.OverlayOpacity or 0.4
    
    -- New config options - properly check for nil (default to true) but respect false
    -- Simple ternary: if nil, default to true; otherwise use the value directly
    local showSearchBar = cfg.SearchBar == nil and true or cfg.SearchBar
    local searchBarPosition = cfg.SearchBarPosition == "Bottom" and "Bottom" or "Top"
    local showArrayList = cfg.ArrayList == nil and true or cfg.ArrayList
    local showSplash = cfg.SplashScreen == nil and true or cfg.SplashScreen
    local enableBlur = cfg.BlurEffect == nil and true or cfg.BlurEffect
    -- Panel snapping removed (was causing bugs)
    local autoHideOnChat = cfg.AutoHideOnChat == nil and true or cfg.AutoHideOnChat
    
    -- Removed debug prints for stealth
    
    local splashTitle = cfg.SplashTitle or cfg.Title or "Menu"
    local splashSubtitle = cfg.SplashSubtitle or cfg.Subtitle or ""
    
    Config.debugMode = SavedSettings.debugMode or false
    
    debugLog("CreateWindow called with config")

    reapOrphanFx(nil)

    local savedNav = {
        autoSelect = nil,
        guiNav = nil,
    }
    pcall(function()
        savedNav.autoSelect = GuiService.AutoSelectGuiEnabled
        savedNav.guiNav = GuiService.GuiNavigationEnabled
    end)
    pcall(function()
        GuiService.AutoSelectGuiEnabled = false
        GuiService.GuiNavigationEnabled = false
        GuiService.SelectedObject = nil
    end)
    
    -- Main ScreenGui with randomized name for stealth
    local gui = create("ScreenGui", {
        Name = StealthNames.gui .. "_" .. generateRandomName(4), -- Random name to avoid detection
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = math.random(900000, 999999), -- Randomize display order
        Parent = StealthParent
    })

    local windowPanels = {}
    local shellConns = {}

    local function getInsetY()
        local ok, inset = pcall(function()
            return GuiService:GetGuiInset()
        end)
        if ok and inset then
            return inset.Y
        end
        return 0
    end

    local TOP_MARGIN = 8
    local NAV_BREAKPOINT = 540
    local SHELL_RADIUS = 10
    local DRAWER_RADIUS = 8
    local FIELD_RADIUS = 6
    local ROW_RADIUS = 4
    local Z_FX = 1
    local Z_OVERLAY = 2
    local Z_ARRAY = 40
    local Z_FREECAM = 45
    local Z_SHELL = 50
    local Z_DRAWER = 60
    local Z_LAUNCHER = 70
    local Z_MODAL = 80
    local Z_NOTIF = 90

    local function getGuiInset()
        local ok, inset = pcall(function()
            return GuiService:GetGuiInset()
        end)
        if ok and inset then
            return inset
        end
        return Vector2.new(0, 0)
    end

    local function getSafeBounds()
        local vp = gui.AbsoluteSize
        local inset = getGuiInset()
        local x = inset.X
        local y = inset.Y
        local w = math.max(1, vp.X - inset.X)
        local h = math.max(1, vp.Y - inset.Y)
        return x, y, w, h
    end

    local function isNarrowLayout()
        local _, _, w = getSafeBounds()
        return w < NAV_BREAKPOINT
    end

    local function isCompactViewport()
        return isNarrowLayout() or UIS.TouchEnabled
    end

    local function isTouchPrimary()
        return UIS.TouchEnabled == true
    end

    local function minTouchLogical(n)
        local s = Config.uiScale
        if s < 0.01 then
            s = 1
        end
        return math.max(n, math.ceil(44 / s))
    end

    local function getMainHeaderH()
        if isTouchPrimary() then
            return minTouchLogical(52)
        end
        return minTouchLogical(44)
    end

    local function getSearchBarH()
        return minTouchLogical(44)
    end

    local function getMenuBtnSize()
        return minTouchLogical(44)
    end

    local function getStateCellSize()
        return 24
    end

    local function getSwitchW()
        return 40
    end

    local scaleListeners = {}
    local function addScaleListener(fn)
        table.insert(scaleListeners, fn)
    end

    local function getPanelWidth()
        local _, _, w = getSafeBounds()
        if isNarrowLayout() then
            return math.min(520, math.max(1, w - 16))
        end
        return math.min(760, math.max(1, w - 24))
    end

    local function nextGamePanelSlot()
        return UDim2.fromOffset(0, 0)
    end

    local function reflowGamePanels()
    end

    local function getModuleH()
        return minTouchLogical(scaled(Config.moduleHeight))
    end

    local function getSettingH()
        return minTouchLogical(math.floor(Config.settingHeight * Config.uiScale + 0.5))
    end

    local function getHeaderBtnSize()
        return minTouchLogical(44)
    end

    local function getFieldH()
        return minTouchLogical(48)
    end

    -- Position offset space (IgnoreGuiInset). Never assign AbsolutePosition back to Position.
    local function offsetFromUDim(pos)
        local vp = gui.AbsoluteSize
        return pos.X.Scale * vp.X + pos.X.Offset, pos.Y.Scale * vp.Y + pos.Y.Offset
    end

    local function clampOffset(x, y, visW, visH, scaleMul)
        local vp = gui.AbsoluteSize
        local s = scaleMul or 1
        if s < 0.01 then
            s = 1
        end
        local maxX = math.max(0, (vp.X - visW) / s)
        local maxY = math.max(0, (vp.Y - visH) / s)
        return math.clamp(x, 0, maxX), math.clamp(y, 0, maxY)
    end

    local function guiContains(obj, screenPos)
        if not obj or not obj.Parent then
            return false
        end
        local p = obj.AbsolutePosition
        local s = obj.AbsoluteSize
        return screenPos.X >= p.X and screenPos.X <= p.X + s.X and screenPos.Y >= p.Y and screenPos.Y <= p.Y + s.Y
    end

    local dragOwner = nil
    local panelFrontZ = 2

    local function siblingIndex(inst)
        local parent = inst.Parent
        if not parent then
            return 0
        end
        local kids = parent:GetChildren()
        for i = 1, #kids do
            if kids[i] == inst then
                return i
            end
        end
        return 0
    end

    local function topmostPanelAt(screenPos)
        local best, bestZ, bestSib = nil, -1e9, -1
        for _, p in ipairs(windowPanels) do
            local inst = p.Instance
            if inst and inst.Visible and guiContains(inst, screenPos) then
                local z = inst.ZIndex
                local sib = siblingIndex(inst)
                if z > bestZ or (z == bestZ and sib >= bestSib) then
                    best = p
                    bestZ = z
                    bestSib = sib
                end
            end
        end
        return best
    end

    local function topmostPanelAtMouse()
        local m = UIS:GetMouseLocation()
        local top = topmostPanelAt(m)
        if top then
            return top
        end
        local insetY = getInsetY()
        top = topmostPanelAt(Vector2.new(m.X, m.Y - insetY))
        if top then
            return top
        end
        return topmostPanelAt(Vector2.new(m.X, m.Y + insetY))
    end

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragOwner = nil
        end
    end)

    local function getRightStackPosition()
        local pw = getPanelWidth()
        local xOff = -pw - 8
        if gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.X + xOff < TOP_MARGIN then
            return UDim2.fromOffset(TOP_MARGIN, TOP_MARGIN)
        end
        return UDim2.new(1, xOff, 0, TOP_MARGIN)
    end

    --=========================================================================
    -- SPLASH: same panel chrome as the menu (header + body, not a status strip)
    --=========================================================================
    local splashGui
    local menuReadyToShow = false
    
    if showSplash then
        local headerH = Config.headerHeight
        local hasSub = type(splashSubtitle) == "string" and splashSubtitle ~= ""
        local titleW = getTextSize(tostring(splashTitle or ""), 14, FONT_TITLE).X + 24
        local subNeed = 0
        if hasSub then
            subNeed = getTextSize(splashSubtitle, 13, FONT_BODY).X + 24
        end
        local splashW = math.clamp(math.max(Config.panelWidth, titleW, subNeed), Config.panelWidth, 280)
        local bodyH = (hasSub and 22 or 6) + 16
        local splashH = headerH + bodyH
        splashGui = create("Frame", {
            Name = StealthNames.splash,
            Size = UDim2.fromOffset(splashW, splashH),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = theme.panel,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 9999,
            Parent = gui
        })
        makeRounded(splashGui, Config.cornerRadius)
        splashGui.AnchorPoint = Vector2.new(0.5, 0.5)
        local function layoutSplash()
            local sx, sy, sw, sh = getSafeBounds()
            local w = math.min(splashW, math.max(80, sw - 16))
            local h = math.min(splashH, math.max(48, sh - 16))
            splashGui.Size = UDim2.fromOffset(w, h)
            splashGui.Position = UDim2.fromOffset(sx + sw * 0.5, sy + sh * 0.5)
        end
        layoutSplash()
        gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if splashGui and splashGui.Parent then
                layoutSplash()
            end
        end)
        splashGui.AnchorPoint = Vector2.new(0.5, 0.5)
        local function layoutSplash()
            local sx, sy, sw, sh = getSafeBounds()
            local w = math.min(splashW, math.max(80, sw - 16))
            local h = math.min(splashH, math.max(48, sh - 16))
            splashGui.Size = UDim2.fromOffset(w, h)
            splashGui.Position = UDim2.fromOffset(sx + sw * 0.5, sy + sh * 0.5)
        end
        layoutSplash()
        gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if splashGui and splashGui.Parent then
                layoutSplash()
            end
        end)

        local splashHeader = create("Frame", {
            BackgroundColor3 = theme.panelHeader,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, headerH),
            Position = UDim2.fromOffset(0, 0),
            Parent = splashGui
        })
        roundTopBar(splashHeader)

        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.fromOffset(6, 0),
            Text = splashTitle,
            TextColor3 = theme.text,
            Font = FONT_TITLE,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = splashHeader
        })

        local splashBody = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, bodyH),
            Position = UDim2.fromOffset(0, headerH),
            Parent = splashGui
        })

        if hasSub then
            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 0, 18),
                Position = UDim2.fromOffset(6, 4),
                Text = splashSubtitle,
                TextColor3 = theme.textDim,
                Font = FONT_BODY,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = splashBody
            })
        end

        local splashBar = create("Frame", {
            BackgroundColor3 = theme.hover,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -16, 0, 4),
            Position = UDim2.new(0, 8, 1, -10),
            Parent = splashBody
        })
        makeRounded(splashBar, Config.chipRadius)

        local splashProgress = create("Frame", {
            BackgroundColor3 = theme.accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = splashBar
        })
        makeRounded(splashProgress, Config.chipRadius)

        task.spawn(function()
            tween(splashProgress, { Size = UDim2.new(1, 0, 1, 0) }, 0.5, Enum.EasingStyle.Quad)
            task.wait(0.58)
            if splashGui then splashGui:Destroy() end
            menuReadyToShow = true
        end)
    else
        menuReadyToShow = true
    end
    
    --=========================================================================
    -- BLUR EFFECT (Lighting; lazy-created if user picks Blur after BlurEffect=false)
    --=========================================================================
    local blurEffect = nil
    local function tagBlur(b)
        if not b then
            return
        end
        pcall(function()
            b:SetAttribute(BLUR_ATTR, true)
        end)
    end
    if enableBlur then
        blurEffect = Instance.new("BlurEffect")
        blurEffect.Name = StealthNames.blur
        blurEffect.Size = 0
        blurEffect.Parent = Lighting
        tagBlur(blurEffect)
    end
    
    local function ensureBlurEffect()
        if blurEffect and blurEffect.Parent then
            return blurEffect
        end
        blurEffect = Instance.new("BlurEffect")
        blurEffect.Name = StealthNames.blur
        blurEffect.Size = 0
        blurEffect.Parent = Lighting
        tagBlur(blurEffect)
        return blurEffect
    end
    
    --=========================================================================
    -- FULLSCREEN EFFECT LAYER (procedural snow / rain, over overlay, under panels)
    --=========================================================================
    local effectLayer = create("Frame", {
        Name = generateRandomName(8) .. "_FxBg",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 1,
        Active = false,
        Parent = gui
    })
    
    -- Dark overlay background (when menu is open)
    local overlay = create("Frame", {
        Name = generateRandomName(8),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.overlay,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = Z_OVERLAY,
        Active = false,
        Parent = gui
    })

    local windowTitleText = tostring(cfg.Title or "Menu")
    local windowSubtitleText = tostring(cfg.Subtitle or "")
    local activePanel = nil
    local drawerOpen = false
    local fullMode = true
    local pinnedMode = false
    local builtinsComplete = false
    local firstScriptSelected = false
    local panelNavRows = {}
    local navGroupLabels = {}
    local categoryScrollPos = {}
    local layoutShell
    local selectCategory
    local setDrawerOpen
    local refreshNavList
    local applyPageChrome
    local syncPinnedMode
    local dismissTopModal
    local openSelectorSheet
    local closeSelectorSheet
    local layoutSelectorSheet
    local selectorOwner = nil
    local helpHostClose
    local compactSearchOpen = false
    local compactSearchBtn
    local notifContainer
    local arrayList
    local searchBarFrame
    local searchInput
    local searchResults
    local changelogFrame
    local shellUserMoved = false
    local uiVisible = true

    local shell = create("Frame", {
        Name = generateRandomName(8),
        BackgroundColor3 = theme.bg,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
        ZIndex = Z_SHELL,
        Parent = gui
    })
    makeRounded(shell, SHELL_RADIUS)
    makeStroke(shell, theme.stroke, 1)
    if showSplash then
        shell.Visible = false
    end

    local shellHeader = create("Frame", {
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, getMainHeaderH()),
        ZIndex = Z_SHELL + 1,
        Active = true,
        Parent = shell
    })
    roundTopBar(shellHeader)

    local navMenuBtn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(getMenuBtnSize(), getMainHeaderH()),
        Position = UDim2.fromOffset(4, 0),
        Text = "Menu",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 14,
        AutoButtonColor = false,
        ZIndex = Z_SHELL + 2,
        Parent = shellHeader
    })
    applyFocusStyle(navMenuBtn)

    local hideMenuBtn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(minTouchLogical(52), getMainHeaderH()),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 0),
        Text = "Hide",
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 14,
        AutoButtonColor = false,
        ZIndex = Z_SHELL + 2,
        Parent = shellHeader
    })
    applyFocusStyle(hideMenuBtn)

    compactSearchBtn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(minTouchLogical(52), getMainHeaderH()),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -minTouchLogical(60), 0, 0),
        Text = "Search",
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 13,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = Z_SHELL + 2,
        Parent = shellHeader
    })
    applyFocusStyle(compactSearchBtn)
    compactSearchBtn.Activated:Connect(function()
        compactSearchOpen = true
        if searchBarFrame then
            searchBarFrame.Visible = showSearchBar
        end
        layoutShell()
        if searchInput then
            pcall(function()
                searchInput:CaptureFocus()
            end)
        end
    end)

    local shellTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -140, 0, windowSubtitleText ~= "" and 22 or getMainHeaderH()),
        Position = UDim2.fromOffset(70, 4),
        Text = windowTitleText,
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = Z_SHELL + 2,
        Parent = shellHeader
    })
    local shellSubtitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -140, 0, 16),
        Position = UDim2.fromOffset(70, 24),
        Text = windowSubtitleText,
        TextColor3 = theme.textDim,
        Font = FONT_BODY,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = windowSubtitleText ~= "",
        ZIndex = Z_SHELL + 2,
        Parent = shellHeader
    })

    local searchSlot = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, getMainHeaderH()),
        ZIndex = Z_SHELL + 1,
        Parent = shell
    })

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -getMainHeaderH()),
        Position = UDim2.fromOffset(0, getMainHeaderH()),
        ZIndex = Z_SHELL + 1,
        ClipsDescendants = true,
        Parent = shell
    })

    local sidebar = create("Frame", {
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 160, 1, 0),
        ZIndex = Z_SHELL + 2,
        Parent = body
    })
    local sidebarStroke = makeSeam(sidebar, "right")

    local navScroll = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.stroke,
        BorderSizePixel = 0,
        ZIndex = Z_SHELL + 3,
        Parent = sidebar
    })
    create("UIListLayout", {
        Parent = navScroll,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    })
    create("UIPadding", {
        Parent = navScroll,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8)
    })

    local drawerScrim = create("TextButton", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = Z_DRAWER,
        Parent = body
    })
    applyFocusStyle(drawerScrim)

    local panelContainer = create("ScrollingFrame", {
        Name = StealthNames.container,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -160, 1, 0),
        Position = UDim2.fromOffset(160, 0),
        ZIndex = Z_SHELL + 2,
        ClipsDescendants = true,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.stroke,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingEnabled = false,
        Parent = body
    })
    create("UIListLayout", {
        Parent = panelContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6)
    })

    local uiScaleObj = create("UIScale", {
        Scale = 1,
        Parent = body
    })

    local modalHost = create("Frame", {
        Name = generateRandomName(8),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = Z_MODAL,
        Parent = gui
    })

    local launcher = create("TextButton", {
        Name = generateRandomName(8),
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(minTouchLogical(48), minTouchLogical(48)),
        Position = UDim2.new(1, -60, 1, -60),
        Text = "Menu",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 14,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = Z_LAUNCHER,
        Parent = gui
    })
    makeRounded(launcher, FIELD_RADIUS)
    makeStroke(launcher, theme.stroke, 1)
    applyFocusStyle(launcher)
    trackHover(launcher, theme.panelHeader, theme.hover)

    local function clampLauncher()
        local sx, sy, sw, sh = getSafeBounds()
        local sz = launcher.AbsoluteSize
        if sz.X < 1 then
            sz = Vector2.new(minTouchLogical(48), minTouchLogical(48))
        end
        local x, y = offsetFromUDim(launcher.Position)
        x = math.clamp(x, sx + 8, sx + sw - sz.X - 8)
        y = math.clamp(y, sy + 8, sy + sh - sz.Y - 8)
        launcher.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    end

    local launcherDragging = false
    local launcherMoved = false
    local launcherStart = Vector2.new()
    local launcherOrig = UDim2.new()
    launcher.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        launcherDragging = true
        launcherMoved = false
        launcherStart = Vector2.new(input.Position.X, input.Position.Y)
        launcherOrig = launcher.Position
    end)
    table.insert(shellConns, UIS.InputChanged:Connect(function(input)
        if not launcherDragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local d = Vector2.new(input.Position.X, input.Position.Y) - launcherStart
        if d.Magnitude > 8 then
            launcherMoved = true
        end
        if launcherMoved then
            local ox, oy = offsetFromUDim(launcherOrig)
            launcher.Position = UDim2.fromOffset(ox + d.X, oy + d.Y)
            clampLauncher()
        end
    end))
    table.insert(shellConns, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            launcherDragging = false
        end
    end))

    local function navRowHeight()
        return minTouchLogical(48)
    end

    local function sidebarWidth()
        if isNarrowLayout() then
            local _, _, sw = getSafeBounds()
            local shellW = math.min(520, math.max(1, sw - 16))
            return math.min(260, math.floor(shellW * 0.78 + 0.5))
        end
        return math.clamp(160, 144, 176)
    end

    setDrawerOpen = function(open, instant)
        if pinnedMode or not isNarrowLayout() then
            drawerOpen = false
            drawerScrim.Visible = false
            if not pinnedMode and not isNarrowLayout() then
                sidebar.Visible = true
            end
            return
        end
        drawerOpen = open and true or false
        sidebar.Visible = true
        sidebar.ZIndex = Z_DRAWER + 1
        navScroll.ZIndex = Z_DRAWER + 2
        local sideW = sidebarWidth()
        drawerScrim.Visible = drawerOpen
        drawerScrim.ZIndex = Z_DRAWER
        local target = drawerOpen and 0 or -sideW
        if instant then
            sidebar.Position = UDim2.fromOffset(target, 0)
        else
            tween(sidebar, { Position = UDim2.fromOffset(target, 0) }, 0.14)
        end
    end

    layoutShell = function()
        local sx, sy, sw, sh = getSafeBounds()
        local narrow = isNarrowLayout()
        local margin = narrow and 8 or 12
        local headerH = getMainHeaderH()
        local searchH = 0
        if showSearchBar and searchBarFrame and searchBarFrame.Visible then
            searchH = getSearchBarH() + 8
        end
        local shellW
        local shellH
        if pinnedMode then
            shellW = math.min(360, math.max(1, sw - 16))
            shellH = math.min(math.floor(sh * 0.55 + 0.5), sh - 16)
            shell.Position = UDim2.fromOffset(sx + sw - shellW - 8, sy + sh - shellH - minTouchLogical(56) - 8)
            navMenuBtn.Visible = false
            sidebar.Visible = false
            drawerScrim.Visible = false
            panelContainer.ScrollingEnabled = true
            panelContainer.Size = UDim2.new(1, 0, 1, 0)
            panelContainer.Position = UDim2.fromOffset(0, 0)
            shellTitle.Text = "Pinned"
            shellSubtitle.Visible = false
        else
            if narrow then
                shellW = math.min(520, math.max(1, sw - 16))
                shellH = math.max(1, sh - 16)
            else
                shellW = math.min(760, math.max(1, sw - 24))
                shellH = math.min(600, math.max(1, sh - 24))
            end
            if not shellUserMoved then
                shell.Position = UDim2.fromOffset(
                    math.floor(sx + (sw - shellW) * 0.5 + 0.5),
                    math.floor(sy + (sh - shellH) * 0.5 + 0.5)
                )
            else
                local x, y = offsetFromUDim(shell.Position)
                x = math.clamp(x, sx + 8, sx + sw - shellW - 8)
                y = math.clamp(y, sy + 8, sy + sh - shellH - 8)
                shell.Position = UDim2.fromOffset(x, y)
            end
            shellTitle.Text = windowTitleText
            shellSubtitle.Visible = windowSubtitleText ~= ""
            navMenuBtn.Visible = narrow
            local sideW = sidebarWidth()
            if narrow then
                sidebar.Size = UDim2.new(0, sideW, 1, 0)
                sidebar.Position = UDim2.fromOffset(drawerOpen and 0 or -sideW, 0)
                sidebar.ZIndex = Z_DRAWER + 1
                navScroll.ZIndex = Z_DRAWER + 2
                drawerScrim.Visible = drawerOpen
                panelContainer.Size = UDim2.new(1, 0, 1, 0)
                panelContainer.Position = UDim2.fromOffset(0, 0)
            else
                setDrawerOpen(false, true)
                sidebar.Visible = true
                sidebar.Size = UDim2.new(0, sideW, 1, 0)
                sidebar.Position = UDim2.fromOffset(0, 0)
                sidebar.ZIndex = Z_SHELL + 2
                drawerScrim.Visible = false
                panelContainer.Size = UDim2.new(1, -sideW, 1, 0)
                panelContainer.Position = UDim2.fromOffset(sideW, 0)
            end
            panelContainer.ScrollingEnabled = false
            panelContainer.CanvasPosition = Vector2.new()
        end
        shell.Size = UDim2.fromOffset(math.max(1, shellW), math.max(1, shellH))
        shellHeader.Size = UDim2.new(1, 0, 0, headerH)
        navMenuBtn.Size = UDim2.fromOffset(getMenuBtnSize() + 8, headerH)
        hideMenuBtn.Size = UDim2.fromOffset(minTouchLogical(52), headerH)
        local titleLeft = (narrow and not pinnedMode) and (getMenuBtnSize() + 12) or 12
        local titleRight = minTouchLogical(56)
        if compactSearchBtn and compactSearchBtn.Visible then
            titleRight = titleRight + minTouchLogical(56)
        end
        if windowSubtitleText ~= "" and not pinnedMode then
            shellTitle.Size = UDim2.new(1, -(titleLeft + titleRight), 0, 22)
            shellTitle.Position = UDim2.fromOffset(titleLeft, 6)
            shellSubtitle.Size = UDim2.new(1, -(titleLeft + titleRight), 0, 16)
            shellSubtitle.Position = UDim2.fromOffset(titleLeft, 28)
        else
            shellTitle.Size = UDim2.new(1, -(titleLeft + titleRight), 1, 0)
            shellTitle.Position = UDim2.fromOffset(titleLeft, 0)
        end
        local searchTop = 0
        if showSearchBar and searchBarPosition == "Top" and searchSlot then
            searchSlot.Size = UDim2.new(1, 0, 0, searchH)
            searchSlot.Position = UDim2.fromOffset(0, headerH)
            searchTop = searchH
        else
            searchSlot.Size = UDim2.new(1, 0, 0, 0)
            searchSlot.Position = UDim2.fromOffset(0, headerH)
        end
        local bottomSearch = 0
        if showSearchBar and searchBarPosition == "Bottom" then
            bottomSearch = getSearchBarH() + 8
        end
        body.Position = UDim2.fromOffset(0, headerH + searchTop)
        body.Size = UDim2.new(1, 0, 1, -(headerH + searchTop + bottomSearch))
        notifContainer.Size = UDim2.fromOffset(
            math.min(400, math.max(120, sw - 16)),
            math.max(80, sh - 24)
        )
        notifContainer.ZIndex = Z_NOTIF
        clampLauncher()
        if arrayList then
            local maxW = isNarrowLayout() and math.max(80, math.floor(sw * 0.46 + 0.5)) or 280
            arrayList.Size = UDim2.fromOffset(maxW, arrayList.AbsoluteSize.Y)
            arrayList.ZIndex = Z_ARRAY
        end
        if splashGui and splashGui.Parent then
            local maxSplashW = math.max(80, sw - 16)
            local maxSplashH = math.max(48, sh - 16)
            local cur = splashGui.AbsoluteSize
            local splashW = math.min(math.max(cur.X, 160), maxSplashW)
            local splashH = math.min(math.max(cur.Y, 48), maxSplashH)
            splashGui.Size = UDim2.fromOffset(splashW, splashH)
            splashGui.Position = UDim2.fromOffset(sx + (sw - splashW) * 0.5, sy + (sh - splashH) * 0.5)
            splashGui.AnchorPoint = Vector2.new(0, 0)
        end
        if showSearchBar and searchBarFrame then
            local compact = narrow and (shellH - headerH - minTouchLogical(44) - 80) < 200
            if compactSearchBtn then
                compactSearchBtn.Visible = compact and not compactSearchOpen and not pinnedMode
            end
            if compact and not compactSearchOpen then
                searchSlot.Size = UDim2.new(1, 0, 0, 0)
                if searchBarFrame then
                    searchBarFrame.Visible = false
                end
                if searchBarPosition == "Top" then
                    body.Position = UDim2.fromOffset(0, headerH)
                    body.Size = UDim2.new(1, 0, 1, -headerH)
                end
            elseif compactSearchOpen or not compact then
                if searchBarFrame and uiVisible and not pinnedMode then
                    searchBarFrame.Visible = showSearchBar
                end
            end
        end
    end

    local shellDragging = false
    local shellDragStart = Vector2.new()
    local shellOrig = UDim2.new()
    shellHeader.InputBegan:Connect(function(input)
        if pinnedMode or (isNarrowLayout() and not UIS.KeyboardEnabled) then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local mouse = UIS:GetMouseLocation()
        if guiContains(navMenuBtn, mouse) or guiContains(hideMenuBtn, mouse) then
            return
        end
        shellDragging = true
        shellUserMoved = true
        shellDragStart = Vector2.new(input.Position.X, input.Position.Y)
        shellOrig = shell.Position
    end)
    table.insert(shellConns, UIS.InputChanged:Connect(function(input)
        if not shellDragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local d = Vector2.new(input.Position.X, input.Position.Y) - shellDragStart
        local ox, oy = offsetFromUDim(shellOrig)
        shell.Position = UDim2.fromOffset(ox + d.X, oy + d.Y)
        layoutShell()
    end))
    table.insert(shellConns, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            shellDragging = false
        end
    end))

    local function makeNavGroupLabel(text, order)
        local lab = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Text = text,
            TextColor3 = theme.textDim,
            Font = FONT_TITLE,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = order,
            ZIndex = Z_SHELL + 4,
            Parent = navScroll
        })
        navGroupLabels[text] = lab
        return lab
    end
    makeNavGroupLabel("Script", 0)
    makeNavGroupLabel("UI", 100)

    local scriptNavCount = 0
    local BUILTIN_NAV_ORDER = {
        Settings = 101,
        Misc = 102,
        Graphics = 103,
        Debug = 104,
    }

    local function paintCategoryNav(p)
        local row = panelNavRows[p]
        if not row then
            return
        end
        local t = CurrentTheme
        local selected = activePanel == p
        row.BackgroundColor3 = selected and t.hover or t.panel
        local lab = row:FindFirstChild("NavLabel")
        if lab then
            lab.Font = selected and FONT_TITLE or FONT_BODY
            lab.TextColor3 = selected and t.text or t.textDim
        end
        local rail = row:FindFirstChild("NavRail")
        if rail then
            rail.BackgroundTransparency = selected and 0 or 1
            rail.BackgroundColor3 = t.accent
        end
        local mark = row:FindFirstChild("NavMark")
        if mark then
            mark.Visible = selected
            mark.TextColor3 = t.accent
        end
        local hidden = p._manuallyHidden == true
        row.Visible = not hidden
        if p.Name == "Debug" and p._navGroup == "UI" then
            row.Visible = Config.debugMode == true and not hidden
        end
    end

    refreshNavList = function()
        for _, p in ipairs(windowPanels) do
            paintCategoryNav(p)
        end
        local scriptHeader = navGroupLabels["Script"]
        local uiHeader = navGroupLabels["UI"]
        local hasScript = false
        local hasUI = false
        for _, p in ipairs(windowPanels) do
            local row = panelNavRows[p]
            if row and row.Visible then
                if p._navGroup == "Script" then
                    hasScript = true
                else
                    hasUI = true
                end
            end
        end
        if scriptHeader then
            scriptHeader.Visible = hasScript
        end
        if uiHeader then
            uiHeader.Visible = hasUI
        end
    end

    applyPageChrome = function(p, stacked)
        if not p or not p.Instance then
            return
        end
        local headerH = minTouchLogical(44)
        if stacked then
            p.Instance.Size = UDim2.new(1, 0, 0, 0)
            p.Instance.AutomaticSize = Enum.AutomaticSize.Y
            if p._scroll then
                p._scroll.ScrollingEnabled = false
                p._scroll.Size = UDim2.new(1, 0, 0, 0)
                p._scroll.AutomaticSize = Enum.AutomaticSize.Y
            end
        else
            p.Instance.AutomaticSize = Enum.AutomaticSize.None
            p.Instance.Size = UDim2.new(1, 0, 1, 0)
            if p._scroll then
                p._scroll.ScrollingEnabled = true
                p._scroll.AutomaticSize = Enum.AutomaticSize.None
                p._scroll.Size = UDim2.new(1, 0, 1, -headerH)
                p._scroll.Position = UDim2.fromOffset(0, headerH)
            end
        end
    end

    selectCategory = function(panel, opts)
        opts = opts or {}
        if not panel or not panel.Instance then
            return
        end
        if activePanel and activePanel._scroll then
            categoryScrollPos[activePanel] = activePanel._scroll.CanvasPosition
        end
        activePanel = panel
        if not pinnedMode then
            for _, p in ipairs(windowPanels) do
                if p.Instance then
                    local show = (p == panel) and not p._manuallyHidden
                    if p.Name == "Debug" and p._navGroup == "UI" and not Config.debugMode then
                        show = false
                    end
                    p.Instance.Visible = show
                    applyPageChrome(p, false)
                    if p.Instance.Parent ~= panelContainer then
                        p.Instance.Parent = panelContainer
                    end
                end
            end
            if panel._scroll and categoryScrollPos[panel] then
                panel._scroll.CanvasPosition = categoryScrollPos[panel]
            end
        end
        refreshNavList()
        if isNarrowLayout() and not opts.keepDrawer then
            setDrawerOpen(false)
        end
    end

    local function nearestVisiblePanel(except)
        local found = nil
        for _, p in ipairs(windowPanels) do
            if p ~= except and not p._manuallyHidden then
                if p.Name == "Debug" and p._navGroup == "UI" and not Config.debugMode then
                    -- skip
                else
                    if p._navGroup == "Script" then
                        return p
                    end
                    if not found then
                        found = p
                    end
                end
            end
        end
        return found
    end

    syncPinnedMode = function()
        if fullMode then
            for _, p in ipairs(windowPanels) do
                if p.Instance then
                    p.Instance.Parent = panelContainer
                    applyPageChrome(p, false)
                end
            end
            if activePanel then
                selectCategory(activePanel, { keepDrawer = true })
            end
            layoutShell()
            return
        end
        local pinned = {}
        for _, p in ipairs(windowPanels) do
            if p.Pinned and not p._manuallyHidden and p.Instance then
                if not (p.Name == "Debug" and p._navGroup == "UI" and not Config.debugMode) then
                    table.insert(pinned, p)
                end
            end
        end
        if #pinned == 0 then
            pinnedMode = false
            shell.Visible = false
            layoutShell()
            return
        end
        pinnedMode = true
        shell.Visible = true
        setDrawerOpen(false, true)
        for _, p in ipairs(windowPanels) do
            if p.Instance then
                local keep = false
                for i = 1, #pinned do
                    if pinned[i] == p then
                        keep = true
                        break
                    end
                end
                p.Instance.Visible = keep
                if keep then
                    p.Instance.Parent = panelContainer
                    applyPageChrome(p, true)
                end
            end
        end
        for i = 1, #pinned do
            pinned[i].Instance.LayoutOrder = i
        end
        layoutShell()
    end

    -- AddPanel maps to a category page inside the shared content host.
    -- Optional position is accepted and ignored; it would fight the single-window layout.
    local function registerCategoryNav(p)
        if not p or panelNavRows[p] then
            return
        end
        local rowH = navRowHeight()
        local row = create("TextButton", {
            BackgroundColor3 = CurrentTheme.panel,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, rowH),
            Text = "",
            AutoButtonColor = false,
            ZIndex = Z_SHELL + 4,
            Parent = navScroll
        })
        makeRounded(row, ROW_RADIUS)
        local rail = create("Frame", {
            Name = "NavRail",
            BackgroundColor3 = CurrentTheme.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, -12),
            Position = UDim2.fromOffset(0, 6),
            ZIndex = Z_SHELL + 5,
            Parent = row
        })
        local mark = create("TextLabel", {
            Name = "NavMark",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(14, rowH),
            Position = UDim2.new(1, -18, 0, 0),
            Text = ">",
            TextColor3 = CurrentTheme.accent,
            Font = FONT_ICON,
            TextSize = 12,
            Visible = false,
            ZIndex = Z_SHELL + 5,
            Parent = row
        })
        create("TextLabel", {
            Name = "NavLabel",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -28, 1, 0),
            Position = UDim2.fromOffset(12, 0),
            Text = p.Name or "Panel",
            TextColor3 = CurrentTheme.text,
            Font = FONT_BODY,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = Z_SHELL + 5,
            Parent = row
        })
        if p._navGroup == "Script" then
            scriptNavCount = scriptNavCount + 1
            row.LayoutOrder = scriptNavCount
        else
            row.LayoutOrder = BUILTIN_NAV_ORDER[p.Name] or 110
        end
        panelNavRows[p] = row
        applyFocusStyle(row)
        bindActivate(row, function()
            if p._manuallyHidden then
                p:showFromNavigator()
            else
                if not fullMode then
                    fullMode = true
                    pinnedMode = false
                    shell.Visible = true
                    uiVisible = true
                    syncPinnedMode()
                end
                selectCategory(p)
            end
        end)
        paintCategoryNav(p)
        refreshNavList()
    end

    navMenuBtn.Activated:Connect(function()
        if pinnedMode then
            return
        end
        setDrawerOpen(not drawerOpen)
        layoutShell()
    end)
    drawerScrim.Activated:Connect(function()
        setDrawerOpen(false)
        layoutShell()
    end)
    
    -- Notification container
    notifContainer = create("Frame", {
        Name = generateRandomName(8),
        Size = UDim2.fromOffset(math.min(500, math.max(120, gui.AbsoluteSize.X - 30)), 600),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = Z_NOTIF,
        Parent = gui
    })
    
    local function updateNotifPosition()
        local sx, sy, sw, sh = getSafeBounds()
        local pad = 8
        notifContainer.ZIndex = Z_NOTIF
        if notifyPosition == "TopRight" then
            notifContainer.AnchorPoint = Vector2.new(1, 0)
            notifContainer.Position = UDim2.fromOffset(sx + sw - pad, sy + pad)
        elseif notifyPosition == "TopLeft" then
            notifContainer.AnchorPoint = Vector2.new(0, 0)
            notifContainer.Position = UDim2.fromOffset(sx + pad, sy + pad)
        elseif notifyPosition == "BottomRight" then
            notifContainer.AnchorPoint = Vector2.new(1, 1)
            notifContainer.Position = UDim2.fromOffset(sx + sw - pad, sy + sh - pad)
        elseif notifyPosition == "BottomLeft" then
            notifContainer.AnchorPoint = Vector2.new(0, 1)
            notifContainer.Position = UDim2.fromOffset(sx + pad, sy + sh - pad)
        end
    end
    updateNotifPosition()
    
    create("UIListLayout", {
        Parent = notifContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        VerticalAlignment = notifyPosition:find("Bottom") and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top,
        HorizontalAlignment = notifyPosition:find("Left") and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
    })
    
    --=========================================================================
    -- ARRAY LIST (shows enabled modules when menu is hidden)
    --=========================================================================
    arrayList = create("Frame", {
        Name = generateRandomName(8),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, TOP_MARGIN),
        Visible = false,
        Active = false,
        ZIndex = Z_ARRAY,
        Parent = gui
    })
    
    create("UIListLayout", {
        Parent = arrayList,
        SortOrder = Enum.SortOrder.Name,
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Right
    })
    
    local arrayListLabels = {}
    
    local function updateArrayList()
        for _, data in pairs(arrayListLabels) do
            local inst = data.frame or data
            if inst and inst.Parent then inst:Destroy() end
        end
        arrayListLabels = {}
        
        local sorted = {}
        for name, _ in pairs(ActiveModules) do
            table.insert(sorted, name)
        end
        table.sort(sorted, function(a, b) return #a > #b end)
        
        for i, name in ipairs(sorted) do
            local label = create("Frame", {
                Name = name,
                BackgroundColor3 = CurrentTheme.bg,
                BackgroundTransparency = 0.08,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(80, 24),
                LayoutOrder = i,
                Parent = arrayList
            })
            makeRounded(label, Config.chipRadius)
            
            local textLbl = create("TextLabel", {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.fromOffset(0, 24),
                Position = UDim2.fromOffset(8, 0),
                Text = name,
                TextColor3 = themedTextColor(),
                Font = FONT_TITLE,
                TextSize = math.max(12, scaled(12)),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextStrokeColor3 = Color3.new(0, 0, 0),
                TextStrokeTransparency = 0.55,
                Parent = label
            })
            pcall(function()
                textLbl.SelectionName = name
            end)

            local function fitWidth()
                local tw = textLbl.TextBounds.X
                if tw < 1 then
                    tw = textLbl.AbsoluteSize.X
                end
                if tw < 1 then
                    tw = getTextSize(name, 14, FONT_TITLE).X
                end
                label.Size = UDim2.fromOffset(math.ceil(tw) + 16, 24)
            end
            fitWidth()
            textLbl:GetPropertyChangedSignal("TextBounds"):Connect(fitWidth)
            textLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWidth)
            
            arrayListLabels[name] = { frame = label, text = textLbl }
        end
    end

    subscribeTheme(function(t)
        for _, data in pairs(arrayListLabels) do
            if data.frame and data.frame.Parent then
                data.frame.BackgroundColor3 = t.bg
            end
            if data.text and data.text.Parent then
                data.text.TextColor3 = themedTextColor(t)
            end
        end
    end)

    local function refreshArrayListVisibility()
        arrayList.Active = false
        if not showArrayList then
            arrayList.Visible = false
            return
        end
        arrayList.Visible = (not uiVisible) and next(ActiveModules) ~= nil
    end
    
    table.insert(ArrayListSubscribers, function()
        updateArrayList()
        refreshArrayListVisibility()
    end)
    
    --=========================================================================
    -- GLOBAL SEARCH BAR
    --=========================================================================
    local panelNavFrame
    local allSearchItems = {} -- Store references to ALL searchable items (modules, dropdowns, sliders, etc.)
    
    local function layoutSearchBar()
        if not searchBarFrame then
            return
        end
        local searchH = getSearchBarH()
        searchBarFrame.Size = UDim2.new(1, -16, 0, searchH)
        searchBarFrame.AnchorPoint = Vector2.new(0, 0)
        searchBarFrame.Position = UDim2.fromOffset(8, 4)
        searchBarFrame.Parent = searchSlot
        if searchResults then
            searchResults.Parent = modalHost
            searchResults.ZIndex = Z_MODAL + 2
            local slotPos = searchSlot.AbsolutePosition
            local slotSize = searchSlot.AbsoluteSize
            if slotSize.X < 1 then
                slotSize = Vector2.new(shell.AbsoluteSize.X - 16, searchH)
                slotPos = shell.AbsolutePosition + Vector2.new(8, shellHeader.AbsoluteSize.Y)
            end
            searchResults.AnchorPoint = Vector2.new(0, 0)
            searchResults.Size = UDim2.fromOffset(math.max(80, slotSize.X), searchResults.AbsoluteSize.Y)
            searchResults.Position = UDim2.fromOffset(slotPos.X, slotPos.Y + searchH + 1)
        end
    end

    local searchStroke
    local searchMatchBtns = {}
    local searchSel = 1
    local searchActivateSel
    local closeSearchResultsFn

    if showSearchBar then
        local searchH = getSearchBarH()
        searchBarFrame = create("Frame", {
            Name = generateRandomName(8),
            BackgroundColor3 = theme.panel,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(math.min(300, math.max(80, gui.AbsoluteSize.X - 24)), searchH),
            AnchorPoint = searchBarPosition == "Bottom" and Vector2.new(0.5, 1) or Vector2.new(0.5, 0),
            Position = searchBarPosition == "Bottom" and UDim2.new(0.5, 0, 1, -TOP_MARGIN) or UDim2.new(0.5, 0, 0, TOP_MARGIN),
            ZIndex = Z_SHELL + 3,
            Visible = true,
            Parent = searchSlot
        })
        makeRounded(searchBarFrame, Config.cornerRadius)
        searchStroke = makeStroke(searchBarFrame, theme.stroke, 1)
        
        searchInput = create("TextBox", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.fromOffset(6, 0),
            Text = "",
            PlaceholderText = "Search modules...",
            TextColor3 = theme.text,
            PlaceholderColor3 = theme.textDim,
            Font = FONT_BODY,
            TextSize = 13,
            ClearTextOnFocus = false,
            Parent = searchBarFrame
        })
        create("UIPadding", { Parent = searchInput, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
        applyFocusStyle(searchInput)
        
        searchResults = create("Frame", {
            Name = generateRandomName(8),
            BackgroundColor3 = theme.bg,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AnchorPoint = searchBarPosition == "Bottom" and Vector2.new(0, 1) or Vector2.new(0, 0),
            Position = searchBarPosition == "Bottom" and UDim2.fromOffset(0, -4) or UDim2.fromOffset(0, searchH + 1),
            ClipsDescendants = true,
            Visible = false,
            ZIndex = Z_MODAL + 2,
            Parent = modalHost
        })
        makeRounded(searchResults, Config.cornerRadius)
        makeStroke(searchResults, theme.stroke, 1)
        
        create("UIListLayout", {
            Parent = searchResults,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 1)
        })
        
        local function setSearchAccent(on)
            if searchStroke then
                searchStroke.Color = on and CurrentTheme.accent or OUTLINE
            end
        end

        local function highlightSearchSel()
            for i, btn in ipairs(searchMatchBtns) do
                if btn and btn.Parent then
                    btn.BackgroundColor3 = (i == searchSel) and CurrentTheme.hover or CurrentTheme.bg
                end
            end
        end

        local function closeSearchResults()
            searchResults.Visible = false
            if compactSearchOpen and isNarrowLayout() then
                compactSearchOpen = false
                layoutShell()
            end
            if searchInput and not searchInput:IsFocused() then
                setSearchAccent(false)
            end
        end
        closeSearchResultsFn = closeSearchResults

        local function flashSearchTarget(elem)
            if not elem or not elem.Parent then
                return
            end
            local orig = elem.BackgroundColor3
            local st = elem:FindFirstChildOfClass("UIStroke")
            local origSt
            if st then
                origSt = st.Color
                st.Color = OUTLINE
            end
            elem.BackgroundColor3 = CurrentTheme.hover
            task.delay(0.18, function()
                if elem and elem.Parent then
                    elem.BackgroundColor3 = orig
                    if st and st.Parent then
                        st.Color = origSt or OUTLINE
                    end
                end
            end)
        end

        local function activateSearchItem(mod)
            searchInput.Text = ""
            closeSearchResults()
            if searchInput then
                searchInput:ReleaseFocus()
            end

            for _, p in ipairs(windowPanels) do
                if p.Name == mod.panel then
                    if mod.group and p._navGroup and p._navGroup ~= mod.group then
                        -- skip
                    else
                        setDrawerOpen(false, true)
                        if p._manuallyHidden and p.showFromNavigator then
                            p:showFromNavigator()
                        else
                            selectCategory(p)
                        end
                        if p._scroll and mod.instance then
                            pcall(function()
                                local y = mod.instance.AbsolutePosition.Y - p._scroll.AbsolutePosition.Y + p._scroll.CanvasPosition.Y
                                p._scroll.CanvasPosition = Vector2.new(0, math.max(0, y - 8))
                            end)
                        end
                        break
                    end
                end
            end

            local targetElement = mod.row or mod.instance
            if targetElement and targetElement.Parent then
                local elementsToFlash = {}
                if mod.row and mod.row:IsA("GuiObject") then
                    table.insert(elementsToFlash, mod.row)
                end
                if mod.instance then
                    local row = mod.instance:FindFirstChild("Row")
                    if row then
                        table.insert(elementsToFlash, row)
                    end
                end
                if #elementsToFlash == 0 and mod.instance and mod.instance:IsA("GuiObject") then
                    table.insert(elementsToFlash, mod.instance)
                end
                for _, elem in ipairs(elementsToFlash) do
                    flashSearchTarget(elem)
                end
            end
        end
        searchActivateSel = function()
            local modBtn = searchMatchBtns[searchSel]
            if modBtn and modBtn._searchMod then
                activateSearchItem(modBtn._searchMod)
            end
        end
        
        local function performSearch(query)
            for _, child in ipairs(searchResults:GetChildren()) do
                if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
            end
            searchMatchBtns = {}
            searchSel = 1
            
            if query == "" then
                closeSearchResults()
                return
            end
            
            local matches = {}
            local lowerQuery = string.lower(query)
            for _, item in ipairs(allSearchItems) do
                if string.find(string.lower(item.name), lowerQuery, 1, true) then
                    table.insert(matches, item)
                end
            end

            searchResults.Visible = true
            setSearchAccent(true)

            if #matches == 0 then
                local empty = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 26),
                    Text = "No matching controls",
                    TextColor3 = CurrentTheme.textDim,
                    Font = FONT_BODY,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 502,
                    Parent = searchResults
                })
                create("UIPadding", { Parent = empty, PaddingLeft = UDim.new(0, 8) })
                tween(searchResults, { Size = UDim2.new(1, 0, 0, 30) }, 0.10)
                return
            end
            
            local shown = math.min(#matches, 7)
            local resultH = isCompactViewport() and 44 or 28
            local resultHeight = shown * (resultH + 1)
            tween(searchResults, { Size = UDim2.new(1, 0, 0, resultHeight) }, 0.10)
            
            for i, mod in ipairs(matches) do
                if i > 7 then break end
                local resultBtn = create("TextButton", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, resultH),
                    Text = mod.name .. " [" .. tostring(mod.group or "") .. " / " .. mod.panel .. "]",
                    TextColor3 = theme.text,
                    Font = FONT_BODY,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    ZIndex = 502,
                    Parent = searchResults
                })
                create("UIPadding", { Parent = resultBtn, PaddingLeft = UDim.new(0, 8) })
                resultBtn._searchMod = mod
                applyFocusStyle(resultBtn, i)
                trackHover(resultBtn, theme.bg, theme.hover)
                resultBtn.Activated:Connect(function()
                    activateSearchItem(mod)
                end)
                table.insert(searchMatchBtns, resultBtn)
            end
            highlightSearchSel()
        end
        
        searchInput:GetPropertyChangedSignal("Text"):Connect(function()
            performSearch(searchInput.Text)
        end)

        searchInput.Focused:Connect(function()
            setSearchAccent(true)
        end)
        
        searchInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                if searchActivateSel then
                    searchActivateSel()
                end
                return
            end
            task.delay(0.2, function()
                if searchInput and not searchInput:IsFocused() then
                    closeSearchResults()
                end
            end)
        end)

        searchInput.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            local k = input.KeyCode
            if k == Enum.KeyCode.Down then
                if #searchMatchBtns > 0 then
                    searchSel = searchSel + 1
                    if searchSel > #searchMatchBtns then
                        searchSel = 1
                    end
                    highlightSearchSel()
                end
            elseif k == Enum.KeyCode.Up then
                if #searchMatchBtns > 0 then
                    searchSel = searchSel - 1
                    if searchSel < 1 then
                        searchSel = #searchMatchBtns
                    end
                    highlightSearchSel()
                end
            elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
                if searchActivateSel then
                    searchActivateSel()
                end
            end
        end)

        subscribeTheme(function(t)
            searchBarFrame.BackgroundColor3 = t.panel
            searchInput.TextColor3 = t.text
            searchInput.PlaceholderColor3 = t.textDim
            searchResults.BackgroundColor3 = t.bg
            if searchStroke then
                if searchInput:IsFocused() or searchResults.Visible then
                    searchStroke.Color = t.accent
                else
                    searchStroke.Color = OUTLINE
                end
            end
            local rs = searchResults:FindFirstChildOfClass("UIStroke")
            if rs then
                rs.Color = OUTLINE
            end
            for _, child in ipairs(searchResults:GetChildren()) do
                if child:IsA("TextButton") then
                    updateHoverColors(child, t.bg, t.hover)
                    child.TextColor3 = t.text
                elseif child:IsA("TextLabel") then
                    child.TextColor3 = t.textDim
                end
            end
        end)
    end
    
    --=========================================================================
    -- CHANGELOG VIEWER
    --=========================================================================
    local changelogEntries = {}
    local changelogCloseBtn
    
    -- Tooltip
    local tooltip = create("Frame", {
        Name = "Tooltip",
        Visible = false,
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        ZIndex = Z_MODAL + 5,
        Parent = modalHost
    })
    makeRounded(tooltip, Config.controlRadius)
    makeStroke(tooltip, theme.stroke, 1)
    create("UIPadding", { Parent = tooltip, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
    
    local tooltipText = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tooltip
    })
    
    local tooltipTarget = nil
    local tooltipDelay = 0.4
    
    local function showTooltip(text, target, fromFocus)
        if not text or text == "" then return end
        if UIS.TouchEnabled and not UIS.KeyboardEnabled and not fromFocus then
            return
        end
        tooltipTarget = target
        tooltipText.Text = text
        local bounds = TextService:GetTextSize(text, 14, FONT_BODY, Vector2.new(260, 2000))
        local _, _, sw = getSafeBounds()
        local maxW = math.floor(sw * 0.8 + 0.5)
        local w = math.min(maxW, math.max(48, bounds.X + 16))
        local h = math.max(24, bounds.Y + 12)
        tooltip.Size = UDim2.fromOffset(w, h)
        
        task.delay(tooltipDelay, function()
            if tooltipTarget == target then
                local mouse = UIS:GetMouseLocation()
                local screen = gui.AbsoluteSize
                local x = math.clamp(mouse.X + 12, 0, math.max(0, screen.X - tooltip.AbsoluteSize.X))
                local y = math.clamp(mouse.Y + 18, 0, math.max(0, screen.Y - tooltip.AbsoluteSize.Y))
                tooltip.Position = UDim2.fromOffset(x, y)
                tooltip.Visible = true
            end
        end)
    end
    
    local function hideTooltip()
        tooltipTarget = nil
        tooltip.Visible = false
    end
    helpHostClose = hideTooltip
    
    local function attachTooltip(element, text)
        if not text or text == "" then return end
        element.MouseEnter:Connect(function() showTooltip(text, element) end)
        element.MouseLeave:Connect(function() hideTooltip() end)
        pcall(function()
            element.SelectionGained:Connect(function() showTooltip(text, element, true) end)
            element.SelectionLost:Connect(function()
                if tooltipTarget == element then
                    hideTooltip()
                end
            end)
        end)
        if UIS.TouchEnabled then
            local holder = element
            if element:IsA("TextButton") and element.Parent then
                holder = element.Parent
            end
            local info = create("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(minTouchLogical(44), minTouchLogical(44)),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                Text = "i",
                TextColor3 = CurrentTheme.textDim,
                Font = FONT_TITLE,
                TextSize = 14,
                AutoButtonColor = false,
                ZIndex = 6,
                Parent = holder
            })
            applyFocusStyle(info)
            info.Activated:Connect(function()
                showTooltip(text, info, true)
                tooltip.Visible = true
                local sx, sy, sw, sh = getSafeBounds()
                local maxW = math.floor(sw * 0.8 + 0.5)
                tooltip.Size = UDim2.fromOffset(math.min(maxW, tooltip.AbsoluteSize.X), tooltip.AbsoluteSize.Y)
                local mouse = UIS:GetMouseLocation()
                local x = math.clamp(mouse.X + 8, sx, sx + sw - tooltip.AbsoluteSize.X)
                local y = math.clamp(mouse.Y + 8, sy, sy + sh - tooltip.AbsoluteSize.Y)
                tooltip.Position = UDim2.fromOffset(x, y)
            end)
        end
    end
    
    -- Follow mouse for tooltip
    UIS.InputChanged:Connect(function(input)
        if tooltip.Visible and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouse = UIS:GetMouseLocation()
            local screen = gui.AbsoluteSize
            local x = math.clamp(mouse.X + 12, 0, screen.X - tooltip.AbsoluteSize.X)
            local y = math.clamp(mouse.Y + 18, 0, screen.Y - tooltip.AbsoluteSize.Y)
            tooltip.Position = UDim2.fromOffset(x, y)
        end
    end)
    
    -- Reopen hint (when UI is hidden)
    local hint = create("Frame", {
        Name = generateRandomName(8),
        Visible = false,
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, TOP_MARGIN),
        Size = UDim2.fromOffset(240, 32),
        ZIndex = 500,
        Parent = gui
    })
    makeRounded(hint, Config.cornerRadius)
    makeStroke(hint, theme.stroke, 1)
    
    local hintLayout = create("UIListLayout", {
        Parent = hint,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    
    local hintPrefix = create("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 32),
        Text = "Press",
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 14,
        LayoutOrder = 1,
        Parent = hint
    })
    
    local hintKey = create("TextLabel", {
        BackgroundColor3 = theme.hover,
        BackgroundTransparency = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 22),
        Text = keycodeToString(toggleKey),
        TextColor3 = theme.text,
        Font = FONT_VALUE,
        TextSize = 13,
        Parent = hint
    })
    makeRounded(hintKey, Config.chipRadius)
    create("UIPadding", {
        Parent = hintKey,
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    })
    
    local hintSuffix = create("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 32),
        Text = "to open",
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 14,
        LayoutOrder = 3,
        Parent = hint
    })
    
    local hintText = hintPrefix
    
    local mobileOpenBtn = create("TextButton", {
        Name = generateRandomName(8),
        Visible = false,
        Active = false,
        Selectable = false,
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(140, 44),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, TOP_MARGIN + 46),
        Text = "Open Menu",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 15,
        AutoButtonColor = false,
        ZIndex = 500,
        Parent = gui
    })
    makeRounded(mobileOpenBtn, Config.cornerRadius)
    makeStroke(mobileOpenBtn, theme.stroke, 1)
    applyFocusStyle(mobileOpenBtn)
    
    local menuBtnSize = getMenuBtnSize()
    local toggleBtn = create("TextButton", {
        Name = "ToggleButton",
        Visible = false,
        Active = false,
        Selectable = false,
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(menuBtnSize, menuBtnSize),
        Position = UDim2.new(1, -(menuBtnSize + 20), 1, -(menuBtnSize + 20)),
        Text = "x",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 16,
        AutoButtonColor = false,
        ZIndex = 999,
        Parent = gui
    })
    makeRounded(toggleBtn, Config.cornerRadius)
    local toggleBtnStroke = makeStroke(toggleBtn, theme.stroke, 1)
    applyFocusStyle(toggleBtn)
    
    local function updateToggleBtnAppearance()
        local t = CurrentTheme
        toggleBtn.BackgroundColor3 = t.panelHeader
        toggleBtn.TextColor3 = t.text
        if uiVisible then
            toggleBtn.Text = "x"
            if toggleBtnStroke then toggleBtnStroke.Color = OUTLINE end
        else
            toggleBtn.Text = "="
            if toggleBtnStroke then toggleBtnStroke.Color = OUTLINE end
        end
    end
    
    local function clampToggleBtn()
        local vp = gui.AbsoluteSize
        local sz = toggleBtn.AbsoluteSize
        if sz.X < 1 then
            sz = Vector2.new(menuBtnSize, menuBtnSize)
        end
        local x, y = offsetFromUDim(toggleBtn.Position)
        x, y = clampOffset(x, y, sz.X, sz.Y, 1)
        toggleBtn.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
    end

    local function layoutHintAndMobileOpen()
        hint.Position = UDim2.new(0.5, 0, 0, TOP_MARGIN)
        local openY = TOP_MARGIN
        if hint.Visible then
            local hintH = hint.AbsoluteSize.Y
            if hintH < 1 then
                hintH = 32
            end
            openY = TOP_MARGIN + hintH + 8
        end
        mobileOpenBtn.Position = UDim2.new(0.5, 0, 0, openY)
    end

    -- Make toggle button draggable
    do
        local dragging, dragStart, startPos = false, Vector2.new(), toggleBtn.Position
        
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = toggleBtn.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        clampToggleBtn()
                    end
                end)
            end
        end)
        
        UIS.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - dragStart
            local x = startPos.X.Scale * gui.AbsoluteSize.X + startPos.X.Offset + delta.X
            local y = startPos.Y.Scale * gui.AbsoluteSize.Y + startPos.Y.Offset + delta.Y
            local sz = toggleBtn.AbsoluteSize
            if sz.X < 1 then
                sz = Vector2.new(menuBtnSize, menuBtnSize)
            end
            x, y = clampOffset(x, y, sz.X, sz.Y, 1)
            toggleBtn.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
        end)
    end
    
    local function updateHintText()
        hintKey.Text = keycodeToString(toggleKey)
        local prefixW = getTextSize("Press", 14, FONT_BODY).X
        local keyW = getTextSize(hintKey.Text, 13, FONT_VALUE).X + 12
        local suffixW = getTextSize("to open", 14, FONT_BODY).X
        hint.Size = UDim2.fromOffset(math.ceil(prefixW + keyW + suffixW + 28), 36)
    end
    updateHintText()
    trackHover(toggleBtn, theme.panelHeader, theme.hover)
    trackHover(mobileOpenBtn, theme.panelHeader, theme.hover)
    subscribeTheme(function(t)
        hint.BackgroundColor3 = t.panel
        hintPrefix.TextColor3 = t.text
        hintKey.TextColor3 = t.text
        hintKey.BackgroundColor3 = t.hover
        hintSuffix.TextColor3 = t.text
        local hs = hint:FindFirstChildOfClass("UIStroke")
        if hs then hs.Color = OUTLINE end
        tooltip.BackgroundColor3 = t.panelHeader
        tooltipText.TextColor3 = t.text
        local ts = tooltip:FindFirstChildOfClass("UIStroke")
        if ts then ts.Color = OUTLINE end
        mobileOpenBtn.BackgroundColor3 = t.panelHeader
        mobileOpenBtn.TextColor3 = t.text
        local ms = mobileOpenBtn:FindFirstChildOfClass("UIStroke")
        if ms then ms.Color = OUTLINE end
        updateHoverColors(toggleBtn, t.panelHeader, t.hover)
        updateHoverColors(mobileOpenBtn, t.panelHeader, t.hover)
        updateToggleBtnAppearance()
    end)
    
    --=========================================================================
    -- BACKGROUND MODE (Blur / Black / Snow / Rain / Stars / Matrix / Bubbles)
    --=========================================================================
    local currentBgMode = SavedSettings.backgroundMode
    local applyBackgroundMode, stopWeather, refreshWeatherIfActive, startAntiAfk, stopAntiAfk
    local getOpenOverlayTransparency, getOpenOverlayColor, destroyWeatherPools
    local destroyed = false
    local fxConns = {}
    applyBackgroundMode, stopWeather, refreshWeatherIfActive, startAntiAfk, stopAntiAfk, getOpenOverlayTransparency, getOpenOverlayColor, destroyWeatherPools = (function()
    local weatherConn = nil
    local overlayTw, blurTw
    local rainPool = {}
    local snowPool = {}
    local starPool = {}
    local matrixPool = {}
    local bubblePool = {}
    local allFxPools = { rainPool, snowPool, starPool, matrixPool, bubblePool }
    local antiAfkGeneration = 0
    local antiAfkConns = {}
    
    local function getParticleDensity()
        return math.clamp(tonumber(SavedSettings.backgroundParticleDensity) or 40, 15, 500)
    end

    local function countFromDensity(per, lo, hi)
        return math.clamp(math.floor(getParticleDensity() * per + 0.5), lo, hi)
    end
    
    local function getBgSpeedMul()
        return math.clamp(tonumber(SavedSettings.backgroundSpeed) or 100, 20, 300) / 100
    end
    
    local function getBgSizeMul()
        return math.clamp(tonumber(SavedSettings.backgroundSize) or 100, 10, 200) / 100
    end
    
    local function getBgOpacityMul()
        return math.clamp(tonumber(SavedSettings.backgroundOpacity) or 50, 10, 100) / 100
    end
    
    local function getBgDir()
        local d = SavedSettings.backgroundDirection
        if d == "Up" then
            return 0, -1
        elseif d == "Left" then
            return -1, 0
        elseif d == "Right" then
            return 1, 0
        elseif d == "Diagonal" then
            return 0.72, 1
        end
        return 0, 1
    end
    
    local function wrapFx(d, dirX, dirY)
        dirX = dirX or 0
        dirY = dirY or 1
        if dirY > 0.2 and d.y > 1.12 then
            d.y = -math.random() * 0.28
            d.x = math.random()
        elseif dirY < -0.2 and d.y < -0.14 then
            d.y = 1 + math.random() * 0.28
            d.x = math.random()
        end
        if dirX > 0.2 and d.x > 1.12 then
            d.x = -math.random() * 0.28
            d.y = math.random()
        elseif dirX < -0.2 and d.x < -0.14 then
            d.x = 1 + math.random() * 0.28
            d.y = math.random()
        end
        if d.x < -0.2 or d.x > 1.2 then
            d.x = math.random()
        end
        if d.y < -0.2 or d.y > 1.2 then
            d.y = math.random()
        end
    end
    
    local function getTargetRainCount()
        return countFromDensity(1.5, 20, 750)
    end
    
    local function getTargetSnowCount()
        return countFromDensity(1.3, 16, 650)
    end
    
    local function getTargetStarCount()
        return countFromDensity(1.2, 14, 600)
    end
    
    local function getTargetMatrixCount()
        return countFromDensity(1.4, 18, 700)
    end
    
    local function getTargetBubbleCount()
        return countFromDensity(0.65, 10, 325)
    end
    
    local function getOpenOverlayTransparency()
        if currentBgMode == "Blur" then
            return 1 - overlayOpacity
        elseif currentBgMode == "Black" then
            return 1 - math.clamp(overlayOpacity + 0.2, 0.55, 0.94)
        elseif ANIMATED_BACKGROUND_MODES[currentBgMode] then
            return 1 - math.clamp(overlayOpacity, 0.28, 0.55)
        end
        return 1 - overlayOpacity
    end
    
    local function getOpenOverlayColor()
        if currentBgMode == "Blur" then
            return CurrentTheme.overlay
        elseif currentBgMode == "Black" then
            return Color3.new(0, 0, 0)
        elseif currentBgMode == "Snow" then
            return Color3.fromRGB(8, 8, 8)
        elseif currentBgMode == "Rain" then
            return Color3.fromRGB(8, 8, 8)
        elseif currentBgMode == "Stars" then
            return Color3.fromRGB(8, 8, 8)
        elseif currentBgMode == "Matrix" then
            return Color3.fromRGB(8, 8, 8)
        elseif currentBgMode == "Bubbles" then
            return Color3.fromRGB(8, 8, 8)
        end
        return CurrentTheme.overlay
    end
    
    local function hidePool(pool)
        for _, d in ipairs(pool) do
            if d.frame and d.frame.Parent then
                d.frame.Visible = false
            end
        end
    end
    
    local function stopWeather()
        if weatherConn then
            pcall(function()
                weatherConn:Disconnect()
            end)
            pcall(function()
                if getgenv and getgenv()._DUIFxConn == weatherConn then
                    getgenv()._DUIFxConn = nil
                end
            end)
            weatherConn = nil
        end
        effectLayer.Visible = false
        for _, pool in ipairs(allFxPools) do
            hidePool(pool)
        end
    end

    local function destroyWeatherPools()
        stopWeather()
        for _, pool in ipairs(allFxPools) do
            for _, d in ipairs(pool) do
                if d.frame then
                    pcall(function()
                        d.frame:Destroy()
                    end)
                end
            end
            for i = #pool, 1, -1 do
                pool[i] = nil
            end
        end
    end
    
    local function trimPool(pool, n)
        while #pool > n do
            local d = table.remove(pool)
            if d.frame then
                pcall(function()
                    d.frame:Destroy()
                end)
            end
        end
    end
    
    local function applyFxLook(d)
        local sizeMul = getBgSizeMul()
        local opMul = getBgOpacityMul()
        if d.bw and d.bh then
            d.frame.Size = UDim2.fromOffset(
                math.max(1, math.floor(d.bw * sizeMul + 0.5)),
                math.max(1, math.floor(d.bh * sizeMul + 0.5))
            )
        end
        if d.isText then
            d.frame.TextTransparency = math.clamp(1 - opMul * (d.alpha or 0.85), 0, 1)
            d.frame.TextSize = math.max(8, math.floor((d.baseText or 14) * sizeMul + 0.5))
        else
            d.frame.BackgroundTransparency = math.clamp(1 - opMul * (d.alpha or 0.85), 0, 1)
        end
        local stroke = d.frame:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Transparency = math.clamp(1 - opMul * 0.55, 0.2, 0.9)
        end
    end
    
    local function syncRainPoolToCount(n)
        n = math.clamp(math.floor(n), 12, 750)
        trimPool(rainPool, n)
        while #rainPool < n do
            local rw = math.random(4, 8)
            local rh = math.random(28, 52)
            local f = create("Frame", {
                Parent = effectLayer,
                BackgroundColor3 = Color3.fromRGB(214, 222, 230),
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(rw, rh),
                Visible = false,
                ZIndex = 2,
            })
            table.insert(rainPool, {
                frame = f,
                x = math.random(),
                y = math.random(),
                spd = 0.55 + math.random() * 0.65,
                drift = (math.random() - 0.5) * 0.14,
                bw = rw,
                bh = rh,
                alpha = 0.62 + math.random() * 0.22,
            })
        end
    end
    
    local function syncSnowPoolToCount(n)
        n = math.clamp(math.floor(n), 10, 650)
        trimPool(snowPool, n)
        while #snowPool < n do
            local sz = math.random(8, 16)
            local f = create("Frame", {
                Parent = effectLayer,
                BackgroundColor3 = Color3.fromRGB(230, 230, 230),
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(sz, sz),
                Visible = false,
                ZIndex = 2,
            })
            makeRounded(f, math.max(2, math.floor(sz / 2)))
            table.insert(snowPool, {
                frame = f,
                x = math.random(),
                y = math.random(),
                spd = 0.1 + math.random() * 0.18,
                drift = (math.random() - 0.5) * 0.22,
                vr = (math.random() - 0.5) * 120,
                bw = sz,
                bh = sz,
                alpha = 0.55 + math.random() * 0.25,
            })
        end
    end
    
    local function syncStarPoolToCount(n)
        n = math.clamp(math.floor(n), 12, 600)
        trimPool(starPool, n)
        while #starPool < n do
            local sz = math.random(2, 5)
            local f = create("Frame", {
                Parent = effectLayer,
                BackgroundColor3 = Color3.fromRGB(220, 220, 220),
                BackgroundTransparency = 0.4,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(sz, sz),
                Visible = false,
                ZIndex = 2,
            })
            makeRounded(f, math.max(1, math.floor(sz / 2)))
            table.insert(starPool, {
                frame = f,
                x = math.random(),
                y = math.random(),
                spd = 0.04 + math.random() * 0.08,
                drift = (math.random() - 0.5) * 0.06,
                bw = sz,
                bh = sz,
                alpha = 0.5 + math.random() * 0.3,
            })
        end
    end
    
    local MATRIX_GLYPHS = { "0", "1", "0", "1", "1", "0" }
    
    local function syncMatrixPoolToCount(n)
        n = math.clamp(math.floor(n), 14, 700)
        trimPool(matrixPool, n)
        while #matrixPool < n do
            local glyph = MATRIX_GLYPHS[math.random(1, #MATRIX_GLYPHS)]
            local ts = math.random(12, 18)
            local f = create("TextLabel", {
                Parent = effectLayer,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(ts, ts + 4),
                Text = glyph,
                TextColor3 = Color3.fromRGB(170, 210, 170),
                Font = FONT_VALUE,
                TextSize = ts,
                TextTransparency = 0.35,
                Visible = false,
                ZIndex = 2,
            })
            table.insert(matrixPool, {
                frame = f,
                x = math.random(),
                y = math.random(),
                spd = 0.35 + math.random() * 0.55,
                drift = (math.random() - 0.5) * 0.04,
                bw = ts,
                bh = ts + 4,
                alpha = 0.55 + math.random() * 0.25,
                isText = true,
                baseText = ts,
            })
        end
    end
    
    local function syncBubblePoolToCount(n)
        n = math.clamp(math.floor(n), 8, 325)
        trimPool(bubblePool, n)
        while #bubblePool < n do
            local sz = math.random(10, 22)
            local f = create("Frame", {
                Parent = effectLayer,
                BackgroundColor3 = Color3.fromRGB(190, 200, 210),
                BackgroundTransparency = 0.45,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(sz, sz),
                Visible = false,
                ZIndex = 2,
            })
            makeRounded(f, math.floor(sz / 2))
            table.insert(bubblePool, {
                frame = f,
                x = math.random(),
                y = math.random(),
                spd = 0.08 + math.random() * 0.14,
                drift = (math.random() - 0.5) * 0.18,
                vr = (math.random() - 0.5) * 40,
                bw = sz,
                bh = sz,
                alpha = 0.4 + math.random() * 0.25,
            })
        end
    end
    
    local function showPool(pool)
        local dirX, dirY = getBgDir()
        for _, d in ipairs(pool) do
            d.x = math.random()
            if dirY >= 0 then
                d.y = -0.15 - math.random() * 0.4
            else
                d.y = 1.05 + math.random() * 0.3
            end
            if dirX > 0.4 and math.abs(dirY) < 0.2 then
                d.x = -0.12 - math.random() * 0.2
                d.y = math.random()
            elseif dirX < -0.4 and math.abs(dirY) < 0.2 then
                d.x = 1.08 + math.random() * 0.2
                d.y = math.random()
            end
            applyFxLook(d)
            d.frame.Visible = true
        end
    end
    
    local function startFxLoop(pool, kind)
        stopWeather()
        effectLayer.Visible = true
        showPool(pool)
        weatherConn = RunService.Heartbeat:Connect(function(dt)
            if destroyed then
                return
            end
            if type(dt) ~= "number" then
                dt = 1 / 60
            end
            local dirX, dirY = getBgDir()
            local speedMul = getBgSpeedMul()
            local wobbleT = tick()
            local sizeMul = getBgSizeMul()
            local opMul = getBgOpacityMul()
            for _, d in ipairs(pool) do
                if d.frame and d.frame.Parent then
                    local vx = dirX * d.spd + (d.drift or 0)
                    local vy = dirY * d.spd
                    if kind == "snow" or kind == "bubbles" then
                        vx = vx + math.sin(wobbleT * 0.65 + d.y * 4) * 0.0009
                    elseif kind == "stars" then
                        vx = vx * 0.35
                        vy = vy * 0.35
                    end
                    d.x = d.x + vx * dt * speedMul
                    d.y = d.y + vy * dt * speedMul
                    if d.vr then
                        d.frame.Rotation = (d.frame.Rotation + d.vr * dt * speedMul) % 360
                    end
                    wrapFx(d, dirX, dirY)
                    d.frame.Position = UDim2.new(d.x, 0, d.y, 0)
                    if d.bw and d.bh then
                        d.frame.Size = UDim2.fromOffset(
                            math.max(1, math.floor(d.bw * sizeMul + 0.5)),
                            math.max(1, math.floor(d.bh * sizeMul + 0.5))
                        )
                    end
                    if d.isText then
                        d.frame.TextTransparency = math.clamp(1 - opMul * (d.alpha or 0.85), 0, 1)
                        d.frame.TextSize = math.max(8, math.floor((d.baseText or 14) * sizeMul + 0.5))
                    else
                        d.frame.BackgroundTransparency = math.clamp(1 - opMul * (d.alpha or 0.85), 0, 1)
                    end
                end
            end
        end)
        table.insert(fxConns, weatherConn)
        pcall(function()
            if getgenv then
                getgenv()._DUIFxConn = weatherConn
            end
        end)
    end
    
    local function startRainLoop()
        syncRainPoolToCount(getTargetRainCount())
        startFxLoop(rainPool, "rain")
    end
    
    local function startSnowLoop()
        syncSnowPoolToCount(getTargetSnowCount())
        startFxLoop(snowPool, "snow")
    end
    
    local function startStarsLoop()
        syncStarPoolToCount(getTargetStarCount())
        startFxLoop(starPool, "stars")
    end
    
    local function startMatrixLoop()
        syncMatrixPoolToCount(getTargetMatrixCount())
        startFxLoop(matrixPool, "matrix")
    end
    
    local function startBubblesLoop()
        syncBubblePoolToCount(getTargetBubbleCount())
        startFxLoop(bubblePool, "bubbles")
    end
    
    local function startAnimatedBackground(mode)
        if mode == "Snow" then
            startSnowLoop()
        elseif mode == "Rain" then
            startRainLoop()
        elseif mode == "Stars" then
            startStarsLoop()
        elseif mode == "Matrix" then
            startMatrixLoop()
        elseif mode == "Bubbles" then
            startBubblesLoop()
        else
            stopWeather()
            effectLayer.Visible = false
        end
    end
    
    local function refreshWeatherIfActive()
        if not uiVisible then
            return
        end
        if ANIMATED_BACKGROUND_MODES[currentBgMode] then
            startAnimatedBackground(currentBgMode)
        end
    end
    
    local function stopAntiAfk()
        antiAfkGeneration = antiAfkGeneration + 1
        for _, c in ipairs(antiAfkConns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        for i = #antiAfkConns, 1, -1 do
            antiAfkConns[i] = nil
        end
    end
    
    local function startAntiAfk()
        stopAntiAfk()
        if not SavedSettings.antiafkEnabled then
            return
        end
        local gen = antiAfkGeneration
        local VirtualUser = game:GetService("VirtualUser")
        local method = SavedSettings.antiafkMethod or ANTIAFK_METHOD_OPTIONS[1]
        
        local function vuClick2()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
        
        if method == "M1 VirtualUser (Idled)" then
            table.insert(
                antiAfkConns,
                Player.Idled:Connect(function()
                    task.wait(math.random(1, 3))
                    if gen ~= antiAfkGeneration then
                        return
                    end
                    vuClick2()
                end)
            )
            task.spawn(function()
                while gen == antiAfkGeneration do
                    task.wait(60)
                    if gen ~= antiAfkGeneration then
                        break
                    end
                    vuClick2()
                end
            end)
        elseif method == "M2 Click simulate" then
            task.spawn(function()
                while gen == antiAfkGeneration do
                    task.wait(48 + math.random() * 18)
                    if gen ~= antiAfkGeneration then
                        break
                    end
                    pcall(function()
                        VirtualUser:CaptureController()
                        local sz = gui.AbsoluteSize
                        local v = Vector2.new(sz.X * 0.5, sz.Y * 0.5)
                        VirtualUser:Button1Down(v)
                        task.wait(0.04)
                        VirtualUser:Button1Up(v)
                    end)
                end
            end)
        elseif method == "M3 Nudge move + restore" then
            task.spawn(function()
                while gen == antiAfkGeneration do
                    task.wait(42 + math.random() * 20)
                    if gen ~= antiAfkGeneration then
                        break
                    end
                    local char = Player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum then
                        local orig = hrp.CFrame
                        pcall(function()
                            VirtualUser:CaptureController()
                            if VirtualUser.SendKeyEvent then
                                VirtualUser:SendKeyEvent(true, Enum.KeyCode.W, false)
                                task.wait(0.03)
                                VirtualUser:SendKeyEvent(false, Enum.KeyCode.W, false)
                            elseif VirtualUser.SendKey then
                                VirtualUser:SendKey(true, Enum.KeyCode.W)
                                task.wait(0.03)
                                VirtualUser:SendKey(false, Enum.KeyCode.W)
                            end
                        end)
                        pcall(function()
                            hum:Move(Vector3.new(0.12, 0, 0), true)
                        end)
                        task.wait(0.07)
                        pcall(function()
                            hrp.CFrame = orig
                        end)
                    end
                end
            end)
        elseif method == "M4 Micro teleport" then
            task.spawn(function()
                while gen == antiAfkGeneration do
                    task.wait(35 + math.random() * 15)
                    if gen ~= antiAfkGeneration then
                        break
                    end
                    local char = Player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            hrp.CFrame = hrp.CFrame * CFrame.new(1e-7, 1e-7, 0)
                        end)
                    end
                end
            end)
        end
    end
    
    local function cancelTw(t)
        if t then
            pcall(function()
                t:Cancel()
            end)
        end
    end

    local function applyBackgroundMode(mode, instant)
        currentBgMode = mode
        stopWeather()
        overlay.BackgroundColor3 = getOpenOverlayColor()
        cancelTw(overlayTw)
        cancelTw(blurTw)
        overlayTw = nil
        blurTw = nil

        if mode ~= "Blur" and blurEffect then
            if instant then
                blurEffect.Size = 0
            else
                blurTw = tween(blurEffect, { Size = 0 }, 0.2)
            end
        elseif mode == "Blur" then
            local b = ensureBlurEffect()
            if uiVisible then
                if instant then
                    b.Size = 8
                else
                    blurTw = tween(b, { Size = 8 }, 0.25)
                end
            else
                if instant then
                    b.Size = 0
                else
                    blurTw = tween(b, { Size = 0 }, 0.2)
                end
            end
        end

        if uiVisible then
            local tOpen = getOpenOverlayTransparency()
            if instant then
                overlay.BackgroundTransparency = tOpen
            else
                overlayTw = tween(overlay, { BackgroundTransparency = tOpen }, 0.25)
            end
            if ANIMATED_BACKGROUND_MODES[mode] then
                startAnimatedBackground(mode)
            else
                effectLayer.Visible = false
            end
        else
            if instant then
                overlay.BackgroundTransparency = 1
            else
                overlayTw = tween(overlay, { BackgroundTransparency = 1 }, 0.2)
            end
            effectLayer.Visible = false
        end
    end
    return applyBackgroundMode, stopWeather, refreshWeatherIfActive, startAntiAfk, stopAntiAfk, getOpenOverlayTransparency, getOpenOverlayColor, destroyWeatherPools
    end)()
    
    local function setUIVisible(visible)
        uiVisible = visible
        if visible then
            fullMode = true
            pinnedMode = false
            shell.Visible = true
            launcher.Visible = false
            if searchBarFrame then
                searchBarFrame.Visible = showSearchBar
            end
            if type(closeSelectorSheet) == "function" then
                closeSelectorSheet()
            end
            if type(helpHostClose) == "function" then
                helpHostClose()
            end
            setDrawerOpen(false, true)
            if activePanel then
                selectCategory(activePanel, { keepDrawer = true })
            else
                syncPinnedMode()
            end
        else
            fullMode = false
            if type(closeSelectorSheet) == "function" then
                closeSelectorSheet()
            end
            if type(helpHostClose) == "function" then
                helpHostClose()
            end
            setDrawerOpen(false, true)
            local anyPinned = false
            for _, p in ipairs(windowPanels) do
                if p.Pinned and not p._manuallyHidden then
                    if not (p.Name == "Debug" and p._navGroup == "UI" and not Config.debugMode) then
                        anyPinned = true
                        break
                    end
                end
            end
            if anyPinned then
                pinnedMode = true
                shell.Visible = true
                syncPinnedMode()
            else
                pinnedMode = false
                shell.Visible = false
            end
            launcher.Visible = true
            clampLauncher()
            if searchBarFrame then
                searchBarFrame.Visible = false
            end
        end
        hint.Visible = (not visible) and SavedSettings.showOpenHint ~= false and UIS.KeyboardEnabled == true
        mobileOpenBtn.Visible = false
        toggleBtn.Visible = false
        if panelNavFrame then
            panelNavFrame.Visible = false
        end
        layoutHintAndMobileOpen()
        updateToggleBtnAppearance()
        refreshArrayListVisibility()
        applyBackgroundMode(currentBgMode, false)
        layoutShell()
        debugLog("UI visibility set to: " .. tostring(visible))
    end
    
    --=========================================================================
    -- AUTO-HIDE ON CHAT (lower DisplayOrder when chat is focused)
    --=========================================================================
    if autoHideOnChat then
        local originalDisplayOrder = gui.DisplayOrder
        local isChatActive = false
        
        -- Try to detect chat via multiple methods
        task.spawn(function()
            while gui and gui.Parent do
                local chatFocused = false
                
                -- Method 1: Check TextService focused textbox
                pcall(function()
                    local focused = UIS:GetFocusedTextBox()
                    if focused and not focused:IsDescendantOf(gui) then
                        chatFocused = true
                    end
                end)
                
                -- Method 2: Check CoreGui chat elements
                if not chatFocused then
                    pcall(function()
                        local chatGui = CoreGui:FindFirstChild("ExperienceChat") or CoreGui:FindFirstChild("Chat")
                        if chatGui then
                            for _, desc in ipairs(chatGui:GetDescendants()) do
                                if desc:IsA("TextBox") and desc:IsFocused() then
                                    chatFocused = true
                                    break
                                end
                            end
                        end
                    end)
                end
                
                -- Method 3: Check PlayerGui for any focused textbox
                if not chatFocused then
                    pcall(function()
                        local playerGui = Player:FindFirstChild("PlayerGui")
                        if playerGui then
                            for _, desc in ipairs(playerGui:GetDescendants()) do
                                if desc:IsA("TextBox") and desc:IsFocused() then
                                    chatFocused = true
                                    break
                                end
                            end
                        end
                    end)
                end
                
                -- Update display order based on chat state
                if chatFocused ~= isChatActive then
                    isChatActive = chatFocused
                    if chatFocused then
                        gui.DisplayOrder = 1
                        debugLog("Chat detected - lowering UI priority")
                    else
                        gui.DisplayOrder = originalDisplayOrder
                        debugLog("Chat closed - restoring UI priority")
                    end
                end
                
                task.wait(0.1) -- Check more frequently
            end
        end)
    end
    
    -- Toggle key listener
    local toggleConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleKey then
            setUIVisible(not uiVisible)
        end
    end)
    
    mobileOpenBtn.Visible = false
    toggleBtn.Visible = false

    hideMenuBtn.Activated:Connect(function()
        setUIVisible(false)
    end)

    launcher.Activated:Connect(function()
        if launcherMoved then
            launcherMoved = false
            return
        end
        setUIVisible(true)
    end)
    
    mobileOpenBtn.Activated:Connect(function()
        setUIVisible(true)
    end)
    
    toggleBtn.Activated:Connect(function()
        setUIVisible(not uiVisible)
    end)
    
    -- Initial overlay / background (instant; matches saved backgroundMode)
    applyBackgroundMode(SavedSettings.backgroundMode, true)
    updateToggleBtnAppearance()
    
    -- Apply saved FPS cap
    if SavedSettings.fpsCap and SavedSettings.fpsCap ~= 60 then
        task.defer(function()
            applyFpsCap(SavedSettings.fpsCap)
        end)
    end
    
    --=========================================================================
    -- WINDOW OBJECT & METHODS
    --=========================================================================
    local window = {
        Instance = gui,
        Container = panelContainer,
        Theme = theme,
        _panels = windowPanels,
        _toggleKey = toggleKey,
        _notifyPosition = notifyPosition,
        _connections = { toggleConn },
    }
    setmetatable(window, { __index = UILib })
    for i = 1, #fxConns do
        table.insert(window._connections, fxConns[i])
    end
    for i = 1, #shellConns do
        table.insert(window._connections, shellConns[i])
    end
    
    --=========================================================================
    -- NOTIFICATION SYSTEM (Configurable)
    --=========================================================================
    -- Store notification config
    local notifyConfig = cfg.NotifyConfig or {
        backgroundColor = nil,
        textColor = nil,
        accentColor = nil,
        fontSize = 14,
        minWidth = 300,
        maxWidth = 400,
        padding = {top = 12, bottom = 12, left = 16, right = 16}
    }
    
    -- Size presets
    local sizePresets = {
        small = {fontSize = 14, minWidth = 250, maxWidth = 320, padding = {top = 10, bottom = 10, left = 14, right = 14}},
        medium = {fontSize = 16, minWidth = 300, maxWidth = 400, padding = {top = 12, bottom = 12, left = 16, right = 16}},
        large = {fontSize = 18, minWidth = 350, maxWidth = 500, padding = {top = 14, bottom = 14, left = 18, right = 18}}
    }
    
    -- Apply size preset if specified
    if notifyConfig.size and sizePresets[notifyConfig.size] then
        local preset = sizePresets[notifyConfig.size]
        notifyConfig.fontSize = notifyConfig.fontSize or preset.fontSize
        notifyConfig.minWidth = notifyConfig.minWidth or preset.minWidth
        notifyConfig.maxWidth = notifyConfig.maxWidth or preset.maxWidth
        notifyConfig.padding = notifyConfig.padding or preset.padding
    end
    
    function window:SetNotifyConfig(config)
        notifyConfig = config or notifyConfig
    end
    
    function window:Notify(text, duration, options)
        -- Skip notifications during initial load (first 3 seconds)
        if isInitialLoad then
            return
        end
        
        options = options or {}
        duration = duration or options.duration or Config.notifyDuration
        
        -- Get config from options or use defaults
        local bgColor = options.backgroundColor or notifyConfig.backgroundColor or theme.panel
        local txtColor = options.textColor or notifyConfig.textColor or theme.text
        local accColor = options.accentColor or notifyConfig.accentColor
        local fontSize = options.fontSize or notifyConfig.fontSize or 14
        local minW = options.minWidth or notifyConfig.minWidth or 300
        local maxW = options.maxWidth or notifyConfig.maxWidth or 400
        local padding = options.padding or notifyConfig.padding or {top = 12, bottom = 12, left = 16, right = 16}
        local sx, _, sw = getSafeBounds()
        local vpMax = math.max(120, sw - 16)
        maxW = math.min(maxW, vpMax, 400)
        minW = math.min(minW, maxW)
        
        -- Calculate text size to determine notification width
        local textSize = getTextSize(tostring(text), fontSize, FONT_BODY)
        local notifWidth = math.clamp(textSize.X + padding.left + padding.right + 50, minW, maxW)
        
        local LINE_W = accColor and 3 or 0
        local notif = create("Frame", {
            BackgroundColor3 = bgColor,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(notifWidth, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = notifContainer
        })
        makeRounded(notif, Config.cornerRadius)
        makeStroke(notif, theme.stroke, 1)

        local accentLine
        if accColor then
            accentLine = create("Frame", {
                BackgroundColor3 = accColor,
                BorderSizePixel = 0,
                Size = UDim2.new(0, LINE_W, 1, 0),
                Position = UDim2.fromOffset(0, 0),
                ZIndex = 2,
                Parent = notif
            })
        end

        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -LINE_W, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(LINE_W, 0),
            Parent = notif
        })
        create("UIPadding", {
            Parent = holder,
            PaddingTop = UDim.new(0, padding.top),
            PaddingBottom = UDim.new(0, padding.bottom),
            PaddingLeft = UDim.new(0, padding.left),
            PaddingRight = UDim.new(0, padding.right),
        })

        local closeSz = isCompactViewport() and 44 or 24
        local notifLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(closeSz + 4), 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(0, 0),
            Text = tostring(text),
            TextColor3 = txtColor,
            Font = FONT_BODY,
            TextSize = fontSize,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = holder
        })

        local closeBtnNotif = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(closeSz, closeSz),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Text = "x",
            TextColor3 = theme.textDim,
            Font = FONT_TITLE,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = holder
        })
        applyFocusStyle(closeBtnNotif)
        closeBtnNotif.MouseEnter:Connect(function()
            closeBtnNotif.TextColor3 = CurrentTheme.text
        end)
        closeBtnNotif.MouseLeave:Connect(function()
            closeBtnNotif.TextColor3 = CurrentTheme.textDim
        end)
        
        notif.BackgroundTransparency = 1
        notifLabel.TextTransparency = 1
        if accentLine then
            accentLine.BackgroundTransparency = 1
        end
        
        tween(notif, { BackgroundTransparency = 0 }, 0.12)
        tween(notifLabel, { TextTransparency = 0 }, 0.12)
        if accentLine then
            tween(accentLine, { BackgroundTransparency = 0 }, 0.12)
        end
        
        local function dismiss()
            tween(notif, { BackgroundTransparency = 1 }, 0.12)
            tween(notifLabel, { TextTransparency = 1 }, 0.12)
            if accentLine then
                tween(accentLine, { BackgroundTransparency = 1 }, 0.12)
            end
            task.delay(0.13, function()
                if notif and notif.Parent then notif:Destroy() end
            end)
        end
        
        closeBtnNotif.Activated:Connect(dismiss)
        task.delay(duration, function()
            if notif and notif.Parent then dismiss() end
        end)
        
        return notif
    end
    
    --=========================================================================
    -- SET NOTIFICATION POSITION
    --=========================================================================
    function window:SetNotifyPosition(pos)
        notifyPosition = pos
        window._notifyPosition = pos
        SavedSettings.notifyPosition = pos
        saveSettings()
        updateNotifPosition()
        
        local layout = notifContainer:FindFirstChildOfClass("UIListLayout")
        if layout then
            layout.VerticalAlignment = pos:find("Bottom") and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
            layout.HorizontalAlignment = pos:find("Left") and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
        end
    end
    
    --=========================================================================
    -- SET THEME
    --=========================================================================
    function window:SetTheme(themeName)
        if Themes[themeName] then
            publishTheme(Themes[themeName])
            window.Theme = CurrentTheme
            theme = CurrentTheme
            SavedSettings.theme = themeName
            saveSettings()
            
            if currentBgMode == "Blur" then
                overlay.BackgroundColor3 = CurrentTheme.overlay
            end
            updateToggleBtnAppearance()
            
            window:Notify("Theme changed to " .. themeName, 2)
        end
    end
    
    function window:SetBackgroundMode(mode)
        if type(mode) ~= "string" or not VALID_BACKGROUND_MODES[mode] then
            return
        end
        SavedSettings.backgroundMode = mode
        saveSettings()
        applyBackgroundMode(mode, false)
    end
    
    --=========================================================================
    -- SET TOGGLE KEY
    --=========================================================================
    function window:SetToggleKey(keyCode)
        toggleKey = keyCode
        window._toggleKey = keyCode
        SavedSettings.toggleKey = keycodeToString(keyCode)
        saveSettings()
        updateHintText()
    end
    
    --=========================================================================
    -- SET UI SCALE
    --=========================================================================
    function window:SetScale(scale)
        Config.uiScale = math.clamp(scale, 0.8, 1.3)
        uiScaleObj.Scale = 1
        for i = 1, #scaleListeners do
            pcall(scaleListeners[i])
        end
        layoutShell()
        layoutSearchBar()
        if selectorSheet and selectorSheet.Visible then
            layoutSelectorSheet()
        end
    end
    
    function window:GetScale()
        return Config.uiScale
    end
    
    --=========================================================================
    -- TOGGLE VISIBILITY
    --=========================================================================
    function window:Toggle()
        setUIVisible(not uiVisible)
    end
    
    function window:Show()
        setUIVisible(true)
    end
    
    function window:Hide()
        setUIVisible(false)
    end
    
    --=========================================================================
    -- GRAPHICS / FREECAM (used by Graphics panel and Destroy)
    --=========================================================================
    local freecamMobileHud = nil
    local startFreecam, stopFreecam, destroyFreecamHud, applyLowGraphics, applyNoGraphics
    startFreecam, stopFreecam, destroyFreecamHud, applyLowGraphics, applyNoGraphics = (function()
    local freecamOn = false
    local freecamBindName = generateRandomName(10)
    local freecamRenderConn = nil
    local freecamInputConns = {}
    local prevCamType, prevSubject
    local prevAutoRotate = true
    local prevMouseBehavior = Enum.MouseBehavior.Default
    local freecamPos = Vector3.new()
    local freecamYaw, freecamPitch = 0, 0
    local freecamRmbHeld = false
    local freecamMobileDir = Vector3.new(0, 0, 0)
    local freecamLookTouch = nil
    local freecamLookLast = nil
    local noGraphicsOn = false
    local freecamSinkName = generateRandomName(10)

    local function setPlayerControlsEnabled(enabled)
        pcall(function()
            local ps = Player:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if not pm then
                return
            end
            local mod = require(pm)
            if type(mod) == "table" and type(mod.GetControls) == "function" then
                local controls = mod:GetControls()
                if enabled then
                    controls:Enable()
                else
                    controls:Disable()
                end
            end
        end)
    end

    local function sinkFreecamMoveKeys(sink)
        pcall(function()
            ContextActionService:UnbindAction(freecamSinkName)
        end)
        if not sink then
            return
        end
        pcall(function()
            ContextActionService:BindActionAtPriority(
                freecamSinkName,
                function()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                Enum.ContextActionPriority.High.Value,
                Enum.KeyCode.W,
                Enum.KeyCode.A,
                Enum.KeyCode.S,
                Enum.KeyCode.D,
                Enum.KeyCode.Z,
                Enum.KeyCode.Q,
                Enum.KeyCode.E,
                Enum.KeyCode.Space,
                Enum.KeyCode.LeftControl,
                Enum.KeyCode.Up,
                Enum.KeyCode.Down,
                Enum.KeyCode.Left,
                Enum.KeyCode.Right,
                keyFromName(SavedSettings.freecamUpKey, Enum.KeyCode.E),
                keyFromName(SavedSettings.freecamDownKey, Enum.KeyCode.Q)
            )
        end)
    end

    local function disconnectFreecamInputs()
        for _, c in ipairs(freecamInputConns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        freecamInputConns = {}
        if freecamRenderConn then
            pcall(function()
                freecamRenderConn:Disconnect()
            end)
            freecamRenderConn = nil
        end
        pcall(function()
            RunService:UnbindFromRenderStep(freecamBindName)
        end)
    end

    local function destroyFreecamHud()
        if freecamMobileHud then
            pcall(function()
                freecamMobileHud:Destroy()
            end)
            freecamMobileHud = nil
        end
        freecamMobileDir = Vector3.new(0, 0, 0)
    end

    local function restorePlayerCamera()
        sinkFreecamMoveKeys(false)
        setPlayerControlsEnabled(true)
        pcall(function()
            UIS.MouseBehavior = prevMouseBehavior or Enum.MouseBehavior.Default
        end)
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.AutoRotate = prevAutoRotate
            end)
            cam.CameraSubject = hum
            cam.CameraType = Enum.CameraType.Custom
        else
            if prevCamType then
                cam.CameraType = prevCamType
            else
                cam.CameraType = Enum.CameraType.Custom
            end
            if prevSubject then
                cam.CameraSubject = prevSubject
            end
        end
    end

    local function stopFreecam()
        freecamOn = false
        disconnectFreecamInputs()
        destroyFreecamHud()
        freecamRmbHeld = false
        freecamLookTouch = nil
        restorePlayerCamera()
    end

    local function isOverInteractiveGui(screenPos)
        for _, d in ipairs(gui:GetDescendants()) do
            if d.Visible and (d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ImageButton")) then
                if guiContains(d, screenPos) then
                    return true
                end
            end
        end
        return false
    end

    local function buildFreecamHud()
        destroyFreecamHud()
        local bsz = isCompactViewport() and 44 or 40
        local hudW = (bsz + 4) * 4 + 8
        local hudH = bsz * 2 + 8
        local hud = create("Frame", {
            Name = generateRandomName(8),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(hudW, hudH),
            Position = UDim2.fromOffset(8, math.max(8, gui.AbsoluteSize.Y - hudH - 8)),
            ZIndex = 900,
            Parent = gui
        })
        subscribeTheme(function()
        end)
        local function addDirBtn(text, pos, vec)
            local btn = create("TextButton", {
                BackgroundColor3 = CurrentTheme.panel,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(bsz, bsz),
                Position = pos,
                Text = text,
                TextColor3 = CurrentTheme.text,
                Font = FONT_TITLE,
                TextSize = 14,
                AutoButtonColor = false,
                ZIndex = 901,
                Parent = hud
            })
            makeRounded(btn, Config.controlRadius)
            makeStroke(btn, CurrentTheme.stroke)
            applyFocusStyle(btn)
            subscribeTheme(function(t)
                btn.BackgroundColor3 = t.panel
                btn.TextColor3 = t.text
                local st = btn:FindFirstChildOfClass("UIStroke")
                if st then
                    st.Color = OUTLINE
                end
            end)
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    freecamMobileDir = freecamMobileDir + vec
                end
            end)
            btn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    freecamMobileDir = freecamMobileDir - vec
                end
            end)
        end
        addDirBtn("W", UDim2.fromOffset(bsz + 8, 0), Vector3.new(0, 0, -1))
        addDirBtn("A", UDim2.fromOffset(4, bsz + 4), Vector3.new(-1, 0, 0))
        addDirBtn("S", UDim2.fromOffset(bsz + 8, bsz + 4), Vector3.new(0, 0, 1))
        addDirBtn("D", UDim2.fromOffset((bsz + 4) * 2 + 4, bsz + 4), Vector3.new(1, 0, 0))
        addDirBtn("Up", UDim2.fromOffset((bsz + 4) * 3 + 4, 0), Vector3.new(0, 1, 0))
        addDirBtn("Dn", UDim2.fromOffset((bsz + 4) * 3 + 4, bsz + 4), Vector3.new(0, -1, 0))
        local hx = math.clamp(8, 0, math.max(0, gui.AbsoluteSize.X - hudW))
        local hy = math.clamp(gui.AbsoluteSize.Y - hudH - 8, 0, math.max(0, gui.AbsoluteSize.Y - hudH))
        hud.Position = UDim2.fromOffset(hx, hy)
        hud:SetAttribute("HudW", hudW)
        hud:SetAttribute("HudH", hudH)
        freecamMobileHud = hud
    end

    local function applyFreecamLook(dx, dy)
        if type(dx) ~= "number" or type(dy) ~= "number" then
            return
        end
        if dx == 0 and dy == 0 then
            return
        end
        freecamYaw = freecamYaw - dx * 0.25
        freecamPitch = math.clamp(freecamPitch - dy * 0.25, -89, 89)
    end

    local function freecamRotation()
        return CFrame.Angles(0, math.rad(freecamYaw), 0) * CFrame.Angles(math.rad(freecamPitch), 0, 0)
    end

    local function applyFreecamToCamera(cam)
        pcall(function()
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CameraSubject = nil
            cam.CFrame = CFrame.new(freecamPos) * freecamRotation()
        end)
    end

    local function freecamStep(dt)
        if type(dt) ~= "number" or dt <= 0 then
            dt = 1 / 60
        end
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        if freecamRmbHeld then
            local ok, delta = pcall(function()
                return UIS:GetMouseDelta()
            end)
            if ok and delta then
                applyFreecamLook(delta.X, delta.Y)
            end
        end
        local move = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Z) then
            move = move + Vector3.new(0, 0, -1)
        end
        if UIS:IsKeyDown(Enum.KeyCode.S) then
            move = move + Vector3.new(0, 0, 1)
        end
        if UIS:IsKeyDown(Enum.KeyCode.A) then
            move = move + Vector3.new(-1, 0, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.D) then
            move = move + Vector3.new(1, 0, 0)
        end
        if UIS:IsKeyDown(keyFromName(SavedSettings.freecamUpKey, Enum.KeyCode.E)) or UIS:IsKeyDown(Enum.KeyCode.Space) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(keyFromName(SavedSettings.freecamDownKey, Enum.KeyCode.Q)) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            move = move + Vector3.new(0, -1, 0)
        end
        move = move + freecamMobileDir
        local rot = freecamRotation()
        if move.Magnitude > 0 then
            local world = rot:VectorToWorldSpace(move)
            if world.Magnitude > 0 then
                local speed = tonumber(SavedSettings.freecamSpeed) or 60
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
                    speed = speed * 2.5
                end
                freecamPos = freecamPos + world.Unit * speed * dt
            end
        end
        applyFreecamToCamera(cam)
    end

    local function setFreecamLookHeld(held)
        freecamRmbHeld = held and true or false
        pcall(function()
            if freecamRmbHeld then
                UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            else
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
    end

    local function startFreecam()
        local cam = workspace.CurrentCamera
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if (not hum or not hrp) and cam == nil then
            window:Notify("Freecam: no camera", 3)
            return false
        end
        if not cam then
            window:Notify("Freecam: no camera", 3)
            return false
        end
        disconnectFreecamInputs()
        destroyFreecamHud()
        freecamOn = true
        prevCamType = cam.CameraType
        prevSubject = cam.CameraSubject
        prevMouseBehavior = UIS.MouseBehavior
        prevAutoRotate = true
        if hum then
            prevAutoRotate = hum.AutoRotate
            pcall(function()
                hum.AutoRotate = false
            end)
        end
        sinkFreecamMoveKeys(true)
        setPlayerControlsEnabled(false)
        freecamPos = cam.CFrame.Position
        local look = cam.CFrame.LookVector
        freecamPitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
        freecamYaw = math.deg(math.atan2(-look.X, -look.Z))
        applyFreecamToCamera(cam)
        local bindPriority = Enum.RenderPriority.Last.Value
        local bindOk = pcall(function()
            RunService:BindToRenderStep(freecamBindName, bindPriority, freecamStep)
        end)
        if not bindOk then
            freecamRenderConn = RunService.RenderStepped:Connect(freecamStep)
            table.insert(window._connections, freecamRenderConn)
        end
        table.insert(freecamInputConns, UIS.InputBegan:Connect(function(input)
            if not freecamOn then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                setFreecamLookHeld(true)
            elseif input.UserInputType == Enum.UserInputType.Touch then
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                if not isOverInteractiveGui(pos) then
                    freecamLookTouch = input
                    freecamLookLast = pos
                end
            end
        end))
        table.insert(freecamInputConns, UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                setFreecamLookHeld(false)
            elseif input.UserInputType == Enum.UserInputType.Touch then
                if freecamLookTouch == input then
                    freecamLookTouch = nil
                    freecamLookLast = nil
                end
            end
        end))
        table.insert(freecamInputConns, UIS.InputChanged:Connect(function(input)
            if not freecamOn then
                return
            end
            if input.UserInputType == Enum.UserInputType.Touch and freecamLookTouch == input and freecamLookLast then
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                applyFreecamLook(pos.X - freecamLookLast.X, pos.Y - freecamLookLast.Y)
                freecamLookLast = pos
            end
        end))
        table.insert(freecamInputConns, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if not freecamOn then
                return
            end
            local newCam = workspace.CurrentCamera
            if newCam then
                applyFreecamToCamera(newCam)
            end
        end))
        table.insert(freecamInputConns, Player.CharacterAdded:Connect(function(newChar)
            if not freecamOn then
                return
            end
            task.defer(function()
                if not freecamOn then
                    return
                end
                setPlayerControlsEnabled(false)
                sinkFreecamMoveKeys(true)
                local newHum = newChar:FindFirstChildOfClass("Humanoid")
                if not newHum then
                    newHum = newChar:WaitForChild("Humanoid", 3)
                end
                if newHum and freecamOn then
                    prevAutoRotate = newHum.AutoRotate
                    pcall(function()
                        newHum.AutoRotate = false
                    end)
                end
            end)
        end))
        for _, c in ipairs(freecamInputConns) do
            table.insert(window._connections, c)
        end
        if UIS.TouchEnabled then
            buildFreecamHud()
        end
        return true
    end

    local function applyLowGraphics(on)
        if on then
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            pcall(function()
                Lighting.GlobalShadows = false
            end)
            pcall(function()
                local tr = workspace:FindFirstChildOfClass("Terrain")
                if tr then
                    tr.Decoration = false
                end
            end)
            pcall(function()
                local cap = 8000
                local n = 0
                for _, inst in ipairs(workspace:GetDescendants()) do
                    if inst:IsA("BasePart") then
                        inst.CastShadow = false
                        n = n + 1
                        if n >= cap then
                            break
                        end
                    end
                end
            end)
            -- ponytail: CastShadow not restored on disable; rejoin resets part shadows
        else
            pcall(function()
                local okAuto = pcall(function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
                end)
                if not okAuto then
                    -- ponytail: Automatic missing on some clients; Level21 as fallback
                    pcall(function()
                        settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
                    end)
                end
            end)
            pcall(function()
                Lighting.GlobalShadows = true
            end)
            pcall(function()
                local tr = workspace:FindFirstChildOfClass("Terrain")
                if tr then
                    tr.Decoration = true
                end
            end)
        end
    end

    local function set3dRenderingEnabled(enabled)
        local ok = pcall(function()
            RunService:Set3dRenderingEnabled(enabled)
        end)
        if ok then
            return true
        end
        pcall(function()
            UserSettings():GetService("UserGameSettings")
        end)
        return false
    end

    local function applyNoGraphics(on)
        if on then
            local ok = set3dRenderingEnabled(false)
            if not ok then
                return false
            end
            noGraphicsOn = true
            return true
        end
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        noGraphicsOn = false
        return true
    end
    return startFreecam, stopFreecam, destroyFreecamHud, applyLowGraphics, applyNoGraphics
    end)()
    
    --=========================================================================
    -- DESTROY
    --=========================================================================
    function window:Destroy()
        if window._destroyed then
            return
        end
        window._destroyed = true
        destroyed = true
        pcall(function()
            if type(closeSelectorSheet) == "function" then
                closeSelectorSheet()
            end
        end)
        pcall(function()
            if type(helpHostClose) == "function" then
                helpHostClose()
            end
        end)
        pcall(function()
            setDrawerOpen(false, true)
        end)
        pcall(function()
            window:HideChangelog()
        end)

        pcall(stopWeather)
        pcall(destroyWeatherPools)
        for i = 1, #fxConns do
            local c = fxConns[i]
            if c then
                pcall(function()
                    c:Disconnect()
                end)
            end
        end

        pcall(function()
            gui.Enabled = false
        end)

        debugLog("Untoggling all active modules before destroy...")
        local modulesToUntoggle = {}

        for _, panel in ipairs(window._panels or {}) do
            if panel._modules then
                for _, module in ipairs(panel._modules) do
                    pcall(function()
                        if module._isToggle and module.Get and module.Set and module.Instance then
                            local isEnabled = module:Get()
                            if isEnabled then
                                table.insert(modulesToUntoggle, module)
                                debugLog("Will untoggle: " .. tostring(module.Instance.Name))
                            end
                        end
                    end)
                end
            end
        end

        for _, module in ipairs(modulesToUntoggle) do
            pcall(function()
                module:TriggerCallback(false)
                module:Set(false)
            end)
        end

        pcall(function()
            task.wait(0.3)
        end)

        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        pcall(stopFreecam)
        pcall(destroyFreecamHud)
        pcall(applyNoGraphics, false)
        pcall(stopAntiAfk)

        for _, conn in ipairs(window._connections or {}) do
            if conn then
                pcall(function()
                    conn:Disconnect()
                end)
            end
        end
        pcall(function()
            if blurEffect then
                blurEffect:Destroy()
            end
        end)
        pcall(function()
            gui:Destroy()
        end)
        pcall(function()
            reapOrphanFx(nil)
        end)
        pcall(function()
            if savedNav.autoSelect ~= nil then
                GuiService.AutoSelectGuiEnabled = savedNav.autoSelect
            end
            if savedNav.guiNav ~= nil then
                GuiService.GuiNavigationEnabled = savedNav.guiNav
            end
            GuiService.SelectedObject = nil
        end)
        debugLog("Window destroyed")
    end
    
    --=========================================================================
    -- CHANGELOG METHODS
    --=========================================================================
    function window:AddChangelog(version, changes, date)
        local timestamp = date or os.date("%Y-%m-%d")
        local text = changes
        if type(changes) == "table" then
            local lines = {}
            for _, line in ipairs(changes) do
                table.insert(lines, tostring(line))
            end
            text = table.concat(lines, "\n")
        else
            text = tostring(changes or "")
        end
        table.insert(changelogEntries, {
            version = version,
            changes = text,
            timestamp = timestamp
        })
        debugLog("Changelog entry added: " .. tostring(version) .. " (" .. timestamp .. ")")
    end
    
    function window:ShowChangelog()
        if changelogFrame then
            changelogFrame.Visible = true
            local vp = gui.AbsoluteSize
            local clW = math.min(changelogFrame.AbsoluteSize.X, math.min(750, math.max(160, vp.X - 16)))
            local clH = math.min(changelogFrame.AbsoluteSize.Y, math.min(650, math.max(160, vp.Y - 16)))
            changelogFrame.Size = UDim2.fromOffset(clW, clH)
            return
        end
        
        local changelogElements = {
            frame = nil,
            header = nil,
            titleLabel = nil,
            stroke = nil,
            scrollBar = nil,
            versionLabels = {},
            dateLabels = {},
            changeLabels = {},
            dividers = {},
            gripBars = {},
            emptyLabel = nil,
        }
        
        local _, _, sw, sh = getSafeBounds()
        local clW = math.min(shell.AbsoluteSize.X > 1 and shell.AbsoluteSize.X or sw, sw - 16)
        local clH = math.min(math.floor(sh * 0.88 + 0.5), sh - 16)
        changelogFrame = create("Frame", {
            Name = generateRandomName(8),
            BackgroundColor3 = theme.bg,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(math.max(160, clW), math.max(160, clH)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            ZIndex = Z_MODAL + 5,
            Parent = modalHost
        })
        changelogElements.frame = changelogFrame
        makeRounded(changelogFrame, Config.cornerRadius)
        local frameStroke = makeStroke(changelogFrame, theme.stroke, 1)
        changelogElements.stroke = frameStroke
        
        local clHeaderH = isCompactViewport() and 44 or 40
        local changelogHeader = create("Frame", {
            BackgroundColor3 = theme.panelHeader,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, clHeaderH),
            ZIndex = 801,
            Parent = changelogFrame
        })
        changelogElements.header = changelogHeader
        roundTopBar(changelogHeader)
        
        local titleLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(clHeaderH + 12), 1, 0),
            Position = UDim2.fromOffset(12, 0),
            Text = "Changelog",
            TextColor3 = theme.text,
            Font = FONT_TITLE,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = changelogHeader
        })
        changelogElements.titleLabel = titleLabel
        
        changelogCloseBtn = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(clHeaderH, clHeaderH),
            Position = UDim2.new(1, -clHeaderH, 0, 0),
            Text = "x",
            TextColor3 = theme.textDim,
            Font = FONT_TITLE,
            TextSize = 16,
            AutoButtonColor = false,
            ZIndex = 802,
            Parent = changelogHeader
        })
        applyFocusStyle(changelogCloseBtn)
        changelogCloseBtn.MouseEnter:Connect(function()
            changelogCloseBtn.TextColor3 = CurrentTheme.text
        end)
        changelogCloseBtn.MouseLeave:Connect(function()
            changelogCloseBtn.TextColor3 = CurrentTheme.textDim
        end)
        
        local function hideCl()
            window:HideChangelog()
        end
        changelogCloseBtn.Activated:Connect(hideCl)
        
        local clDragging, clDragStart, clStartPos = false, Vector2.new(), changelogFrame.Position
        changelogHeader.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local mouse = UIS:GetMouseLocation()
                if guiContains(changelogCloseBtn, mouse) then
                    return
                end
                clDragging = true
                clDragStart = input.Position
                clStartPos = changelogFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        clDragging = false
                    end
                end)
            end
        end)
        
        local clDragConn = UIS.InputChanged:Connect(function(input)
            if not clDragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - clDragStart
            changelogFrame.Position = UDim2.new(
                clStartPos.X.Scale, clStartPos.X.Offset + delta.X,
                clStartPos.Y.Scale, clStartPos.Y.Offset + delta.Y
            )
        end)
        table.insert(window._connections, clDragConn)
        
        local resizeHandle = create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.new(1, -16, 1, -16),
            Text = "",
            ZIndex = 801,
            Visible = not isTouchPrimary(),
            Parent = changelogFrame
        })
        for i = 0, 2 do
            local bar = create("Frame", {
                BackgroundColor3 = theme.stroke,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(10 - i * 3, 1),
                Position = UDim2.new(1, -(12 - i * 3), 1, -(4 + i * 3)),
                Parent = resizeHandle
            })
            table.insert(changelogElements.gripBars, bar)
        end
        applyFocusStyle(resizeHandle)
        
        local resizing, resizeStart, startSize = false, Vector2.new(), changelogFrame.Size
        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                startSize = changelogFrame.Size
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        resizing = false
                    end
                end)
            end
        end)
        
        local resizeConn = UIS.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - resizeStart
            local vp2 = gui.AbsoluteSize
            local maxW = math.min(1000, math.max(120, vp2.X - 16))
            local maxH = math.min(800, math.max(120, vp2.Y - 16))
            local minW = math.min(400, maxW)
            local minH = math.min(300, maxH)
            local newW = math.clamp(startSize.X.Offset + delta.X, minW, maxW)
            local newH = math.clamp(startSize.Y.Offset + delta.Y, minH, maxH)
            changelogFrame.Size = UDim2.fromOffset(newW, newH)
        end)
        table.insert(window._connections, resizeConn)
        
        local changelogScroll = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -16, 1, -(clHeaderH + 12)),
            Position = UDim2.fromOffset(8, clHeaderH + 4),
            ScrollBarThickness = 6,
            ScrollBarImageColor3 = theme.stroke,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 801,
            Parent = changelogFrame
        })
        changelogElements.scrollBar = changelogScroll
        
        create("UIListLayout", {
            Parent = changelogScroll,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10)
        })
        
        for i, entry in ipairs(changelogEntries) do
            local entryFrame = create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = i,
                ZIndex = 1,
                Parent = changelogScroll
            })
            
            local versionLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, 0, 0, 18),
                Text = "v" .. entry.version,
                TextColor3 = theme.text,
                Font = FONT_VALUE,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
                Parent = entryFrame
            })
            table.insert(changelogElements.versionLabels, versionLabel)
            
            local dateLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, 0, 0, 18),
                Position = UDim2.new(0.5, 0, 0, 0),
                Text = entry.timestamp,
                TextColor3 = theme.textDim,
                Font = FONT_BODY,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 2,
                Parent = entryFrame
            })
            table.insert(changelogElements.dateLabels, dateLabel)
            
            local changesText = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.fromOffset(0, 20),
                AutomaticSize = Enum.AutomaticSize.Y,
                Text = entry.changes,
                TextColor3 = theme.text,
                Font = FONT_BODY,
                TextSize = 14,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                RichText = true,
                ZIndex = 2,
                Parent = entryFrame
            })
            table.insert(changelogElements.changeLabels, changesText)
            
            if i < #changelogEntries then
                local divider = create("Frame", {
                    BackgroundColor3 = theme.stroke,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.new(0, 0, 1, 4),
                    ZIndex = 2,
                    Parent = entryFrame
                })
                table.insert(changelogElements.dividers, divider)
            end
        end
        
        if #changelogEntries == 0 then
            changelogElements.emptyLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 100),
                Text = "No changelog entries yet",
                TextColor3 = theme.textDim,
                Font = FONT_BODY,
                TextSize = 14,
                ZIndex = 2,
                Parent = changelogScroll
            })
        end
        
        local themeUpdateConnection = subscribeTheme(function(newTheme)
            if changelogElements.frame then
                changelogElements.frame.BackgroundColor3 = newTheme.bg
            end
            if changelogElements.stroke then
                changelogElements.stroke.Color = OUTLINE
            end
            if changelogElements.header then
                changelogElements.header.BackgroundColor3 = newTheme.panelHeader
            end
            if changelogElements.titleLabel then
                changelogElements.titleLabel.TextColor3 = newTheme.text
            end
            if changelogElements.scrollBar then
                changelogElements.scrollBar.ScrollBarImageColor3 = newTheme.stroke
            end
            if changelogCloseBtn then
                changelogCloseBtn.TextColor3 = newTheme.textDim
            end
            for _, lab in ipairs(changelogElements.versionLabels) do
                if lab and lab.Parent then
                    lab.TextColor3 = newTheme.text
                end
            end
            for _, lab in ipairs(changelogElements.dateLabels) do
                if lab and lab.Parent then
                    lab.TextColor3 = newTheme.textDim
                end
            end
            for _, lab in ipairs(changelogElements.changeLabels) do
                if lab and lab.Parent then
                    lab.TextColor3 = newTheme.text
                end
            end
            for _, d in ipairs(changelogElements.dividers) do
                if d and d.Parent then
                    d.BackgroundColor3 = newTheme.stroke
                end
            end
            for _, bar in ipairs(changelogElements.gripBars) do
                if bar and bar.Parent then
                    bar.BackgroundColor3 = newTheme.stroke
                end
            end
            if changelogElements.emptyLabel and changelogElements.emptyLabel.Parent then
                changelogElements.emptyLabel.TextColor3 = newTheme.textDim
            end
        end)
        table.insert(window._connections, themeUpdateConnection)
    end
    
    function window:HideChangelog()
        if changelogFrame then
            changelogFrame.Visible = false
        end
    end
    
    --=========================================================================
    -- DEBUG MODE
    --=========================================================================
    local debugPanel

    function window:SetDebugMode(enabled)
        Config.debugMode = enabled and true or false
        SavedSettings.debugMode = Config.debugMode
        saveSettings()
        debugLog("Debug mode " .. (Config.debugMode and "enabled" or "disabled"))
        if not debugPanel then
            return
        end
        if Config.debugMode then
            debugPanel._manuallyHidden = false
            if fullMode and activePanel == debugPanel then
                debugPanel.Instance.Visible = true
            end
        else
            if debugPanel.SetPinned then
                debugPanel:SetPinned(false)
            end
            debugPanel._manuallyHidden = true
            debugPanel.Instance.Visible = false
            if activePanel == debugPanel then
                local nextP = nearestVisiblePanel(debugPanel)
                if nextP then
                    selectCategory(nextP)
                end
            end
        end
        refreshNavList()
    end
    
    function window:GetDebugLogs()
        return DebugLogs
    end
    
    --=========================================================================
    -- ARRAY LIST METHODS
    --=========================================================================
    function window:SetArrayListPosition(pos)
        SavedSettings.arrayListPosition = pos
        saveSettings()
        local sx, sy, sw = getSafeBounds()
        local pad = 10
        if pos == "Left" then
            arrayList.AnchorPoint = Vector2.new(0, 0)
            arrayList.Position = UDim2.fromOffset(sx + pad, sy + pad)
            local layout = arrayList:FindFirstChildOfClass("UIListLayout")
            if layout then layout.HorizontalAlignment = Enum.HorizontalAlignment.Left end
        else
            arrayList.AnchorPoint = Vector2.new(1, 0)
            arrayList.Position = UDim2.fromOffset(sx + sw - pad, sy + pad)
            local layout = arrayList:FindFirstChildOfClass("UIListLayout")
            if layout then layout.HorizontalAlignment = Enum.HorizontalAlignment.Right end
        end
        arrayList.ZIndex = Z_ARRAY
        arrayList.Active = false
    end
    
    --=========================================================================
    -- PANEL NAVIGATOR (menu-only, bottom-left, not a listed panel)
    --=========================================================================
    local panelNavLayout

    panelNavFrame = create("Frame", {
        Name = generateRandomName(8),
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -8),
        AutomaticSize = Enum.AutomaticSize.XY,
        ZIndex = 480,
        Visible = false,
        Active = false,
        Parent = gui,
    })
    makeRounded(panelNavFrame, Config.cornerRadius)
    makeStroke(panelNavFrame, theme.stroke, 1)

    local panelNavTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 132, 0, 18),
        Text = "Panels",
        TextColor3 = theme.textDim,
        Font = FONT_TITLE,
        TextSize = 13,
        Parent = panelNavFrame,
    })
    create("UIPadding", {
        Parent = panelNavFrame,
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })
    panelNavLayout = create("UIListLayout", {
        Parent = panelNavFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    })

    local navCells = {}

    local function paintNavRow(row, hidden)
        local t = CurrentTheme
        row.BackgroundColor3 = t.bg
        local lab = row:FindFirstChild("NavLabel")
        if lab then
            lab.TextColor3 = hidden and t.textDim or t.text
        else
            row.TextColor3 = hidden and t.textDim or t.text
        end
        local cell = navCells[row]
        if cell then
            cell:Set(not hidden, false)
        end
    end

    local function refreshPanelNavTheme()
        if not panelNavFrame then
            return
        end
        panelNavFrame.Visible = false
        panelNavFrame.Active = false
    end

    subscribeTheme(refreshPanelNavTheme)

    local function centerPanelOnScreen(p)
    end

    local function registerPanelNav(p)
    end

    local openDropdownCloser
    local openDropdownNav
    local openNestedCloser
    local keybindCancel
    local focusedFieldRestore

    local selectorScrim = create("TextButton", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = Z_MODAL + 1,
        Parent = modalHost
    })
    applyFocusStyle(selectorScrim)
    local selectorSheet = create("Frame", {
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(280, 200),
        Visible = false,
        ZIndex = Z_MODAL + 2,
        Parent = modalHost
    })
    makeRounded(selectorSheet, DRAWER_RADIUS)
    makeStroke(selectorSheet, theme.stroke, 1)
    local selectorHead = create("Frame", {
        BackgroundColor3 = theme.panelHeader,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, minTouchLogical(48)),
        Parent = selectorSheet
    })
    local selectorTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -96, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        Text = "Select",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = selectorHead
    })
    local selectorCloseBtn = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(minTouchLogical(44), minTouchLogical(44)),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0),
        Text = "Close",
        TextColor3 = theme.text,
        Font = FONT_BODY,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = selectorHead
    })
    applyFocusStyle(selectorCloseBtn)
    local selectorFilter = create("TextBox", {
        BackgroundColor3 = theme.bg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 0, minTouchLogical(44)),
        Position = UDim2.fromOffset(8, minTouchLogical(48) + 4),
        Text = "",
        PlaceholderText = "Filter",
        TextColor3 = theme.text,
        PlaceholderColor3 = theme.textDim,
        Font = FONT_BODY,
        TextSize = 13,
        Visible = false,
        ClearTextOnFocus = false,
        Parent = selectorSheet
    })
    applyFocusStyle(selectorFilter)
    makeRounded(selectorFilter, FIELD_RADIUS)
    local selectorList = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 1, -minTouchLogical(48) - 8),
        Position = UDim2.fromOffset(4, minTouchLogical(48) + 4),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = theme.stroke,
        Parent = selectorSheet
    })
    create("UIListLayout", {
        Parent = selectorList,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    })
    local selectorDone = create("TextButton", {
        BackgroundColor3 = theme.hover,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 0, minTouchLogical(48)),
        Position = UDim2.new(0, 8, 1, -minTouchLogical(52)),
        Text = "Done",
        TextColor3 = theme.text,
        Font = FONT_TITLE,
        TextSize = 14,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = Z_MODAL + 3,
        Parent = selectorSheet
    })
    makeRounded(selectorDone, FIELD_RADIUS)
    applyFocusStyle(selectorDone)
    local selectorOptSel = 1
    local selectorOptBtns = {}

    layoutSelectorSheet = function()
        local _, _, sw, sh = getSafeBounds()
        local maxH = math.floor(sh * 0.7 + 0.5)
        local sheetW
        local sheetH = math.min(maxH, math.max(180, selectorList.AbsoluteCanvasSize.Y + minTouchLogical(56) + 24))
        if selectorDone.Visible then
            sheetH = math.min(maxH, sheetH + minTouchLogical(56))
        end
        if selectorFilter.Visible then
            sheetH = math.min(maxH, sheetH + minTouchLogical(48))
        end
        if isNarrowLayout() then
            sheetW = math.min(shell.AbsoluteSize.X, sw)
            selectorSheet.AnchorPoint = Vector2.new(0.5, 1)
            selectorSheet.Position = UDim2.new(0.5, 0, 1, -8)
        else
            sheetW = math.min(420, math.max(280, shell.AbsoluteSize.X * 0.55))
            selectorSheet.AnchorPoint = Vector2.new(0.5, 0.5)
            selectorSheet.Position = UDim2.fromScale(0.5, 0.5)
        end
        selectorSheet.Size = UDim2.fromOffset(sheetW, sheetH)
        local top = minTouchLogical(48)
        if selectorFilter.Visible then
            selectorFilter.Position = UDim2.fromOffset(8, top + 4)
            top = top + minTouchLogical(48) + 8
        end
        local bottom = selectorDone.Visible and (minTouchLogical(56) + 8) or 8
        selectorList.Position = UDim2.fromOffset(4, top)
        selectorList.Size = UDim2.new(1, -8, 1, -(top + bottom))
        selectorDone.Position = UDim2.new(0, 8, 1, -minTouchLogical(52))
    end

    local function rebuildSelectorList()
        for _, ch in ipairs(selectorList:GetChildren()) do
            if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") then
                ch:Destroy()
            end
        end
        selectorOptBtns = {}
        selectorOptSel = 1
        if not selectorOwner then
            return
        end
        local opts = selectorOwner.getOptions()
        local filter = string.lower(selectorFilter.Text or "")
        local shown = 0
        if #opts == 0 then
            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, minTouchLogical(48)),
                Text = "No options",
                TextColor3 = CurrentTheme.textDim,
                Font = FONT_BODY,
                TextSize = 14,
                Parent = selectorList
            })
            return
        end
        for i = 1, #opts do
            local opt = opts[i]
            if filter == "" or string.find(string.lower(tostring(opt)), filter, 1, true) then
                shown = shown + 1
                local optH = minTouchLogical(48)
                local row = create("TextButton", {
                    BackgroundColor3 = CurrentTheme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, optH),
                    Text = "",
                    AutoButtonColor = false,
                    Parent = selectorList
                })
                applyFocusStyle(row)
                local selected = false
                if selectorOwner.isMultiple then
                    local sv = selectorOwner.getSelected()
                    selected = type(sv) == "table" and sv[opt] == true
                else
                    selected = selectorOwner.getSelected() == opt
                end
                local mark = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(22, optH),
                    Position = UDim2.fromOffset(6, 0),
                    Text = selected and "+" or "",
                    TextColor3 = CurrentTheme.accent,
                    Font = FONT_ICON,
                    TextSize = 14,
                    Parent = row
                })
                create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -36, 1, 0),
                    Position = UDim2.fromOffset(28, 0),
                    Text = tostring(opt),
                    TextColor3 = selected and CurrentTheme.accent or CurrentTheme.text,
                    Font = selected and FONT_TITLE or FONT_BODY,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row
                })
                local captured = opt
                row.Activated:Connect(function()
                    if selectorOwner.isMultiple then
                        selectorOwner.applyMulti(captured)
                        rebuildSelectorList()
                        layoutSelectorSheet()
                    else
                        selectorOwner.applySingle(captured)
                        closeSelectorSheet()
                    end
                end)
                table.insert(selectorOptBtns, { btn = row, opt = captured, mark = mark })
            end
        end
    end

    closeSelectorSheet = function()
        if selectorOwner and selectorOwner.setOpenVisual then
            selectorOwner.setOpenVisual(false)
        end
        selectorOwner = nil
        selectorScrim.Visible = false
        selectorSheet.Visible = false
        modalHost.Active = false
        selectorFilter.Text = ""
        if openDropdownCloser == closeSelectorSheet then
            openDropdownCloser = nil
            openDropdownNav = nil
        end
    end

    openSelectorSheet = function(ctl)
        if not ctl then
            return
        end
        if selectorOwner == ctl then
            closeSelectorSheet()
            return
        end
        if openDropdownCloser then
            openDropdownCloser()
        end
        selectorOwner = ctl
        if ctl.setOpenVisual then
            ctl.setOpenVisual(true)
        end
        selectorTitle.Text = ctl.label or "Select"
        selectorFilter.Visible = #(ctl.getOptions() or {}) > 8
        selectorDone.Visible = ctl.isMultiple == true
        selectorFilter.Text = ""
        rebuildSelectorList()
        selectorScrim.Visible = true
        selectorSheet.Visible = true
        modalHost.Active = true
        layoutSelectorSheet()
        tween(selectorSheet, { BackgroundTransparency = 0 }, 0.14)
        openDropdownCloser = closeSelectorSheet
        openDropdownNav = {
            move = function(delta)
                if #selectorOptBtns == 0 then
                    return
                end
                selectorOptSel = selectorOptSel + delta
                if selectorOptSel < 1 then
                    selectorOptSel = #selectorOptBtns
                end
                if selectorOptSel > #selectorOptBtns then
                    selectorOptSel = 1
                end
                for i, data in ipairs(selectorOptBtns) do
                    data.btn.BackgroundColor3 = (i == selectorOptSel) and CurrentTheme.hover or CurrentTheme.bg
                end
                pcall(function()
                    GuiService.SelectedObject = selectorOptBtns[selectorOptSel].btn
                end)
            end,
            activate = function()
                local data = selectorOptBtns[selectorOptSel]
                if data and data.btn then
                    data.btn.Activated:Wait()
                end
            end
        }
        -- Don't Wait on Activated for keyboard; fire the same handler
        openDropdownNav.activate = function()
            local data = selectorOptBtns[selectorOptSel]
            if not data or not selectorOwner then
                return
            end
            if selectorOwner.isMultiple then
                selectorOwner.applyMulti(data.opt)
                rebuildSelectorList()
            else
                selectorOwner.applySingle(data.opt)
                closeSelectorSheet()
            end
        end
    end

    selectorScrim.Activated:Connect(function()
        closeSelectorSheet()
    end)
    selectorCloseBtn.Activated:Connect(function()
        closeSelectorSheet()
    end)
    selectorDone.Activated:Connect(function()
        closeSelectorSheet()
    end)
    selectorFilter:GetPropertyChangedSignal("Text"):Connect(function()
        if selectorOwner then
            rebuildSelectorList()
        end
    end)
    subscribeTheme(function(t)
        selectorSheet.BackgroundColor3 = t.panel
        selectorHead.BackgroundColor3 = t.panelHeader
        selectorTitle.TextColor3 = t.text
        selectorCloseBtn.TextColor3 = t.text
        selectorFilter.BackgroundColor3 = t.bg
        selectorFilter.TextColor3 = t.text
        selectorDone.BackgroundColor3 = t.hover
        selectorDone.TextColor3 = t.text
        selectorList.ScrollBarImageColor3 = t.stroke
        local st = selectorSheet:FindFirstChildOfClass("UIStroke")
        if st then
            st.Color = OUTLINE
        end
        if selectorOwner then
            rebuildSelectorList()
        end
        shell.BackgroundColor3 = t.bg
        shellHeader.BackgroundColor3 = t.panelHeader
        shellTitle.TextColor3 = t.text
        shellSubtitle.TextColor3 = t.textDim
        navMenuBtn.TextColor3 = t.text
        hideMenuBtn.TextColor3 = t.text
        if compactSearchBtn then
            compactSearchBtn.TextColor3 = t.text
        end
        sidebar.BackgroundColor3 = t.panel
        launcher.BackgroundColor3 = t.panelHeader
        launcher.TextColor3 = t.text
        drawerScrim.BackgroundColor3 = Color3.new(0, 0, 0)
        refreshNavList()
    end)

    local function restoreLiftedPanel()
        if focusedFieldRestore then
            local sc = focusedFieldRestore.scroll
            local pos = focusedFieldRestore.pos
            if sc and sc.Parent then
                sc.CanvasPosition = pos
            end
            focusedFieldRestore = nil
        end
    end

    local function beginFieldLift(box)
        if not box then
            return
        end
        restoreLiftedPanel()
        local scroll
        for _, p in ipairs(windowPanels) do
            if p._scroll and box:IsDescendantOf(p._scroll) then
                scroll = p._scroll
                break
            end
        end
        if not scroll then
            return
        end
        focusedFieldRestore = { scroll = scroll, pos = scroll.CanvasPosition }
        local kbY = 0
        pcall(function()
            if UIS.OnScreenKeyboardVisible then
                kbY = UIS.OnScreenKeyboardSize.Y
            end
        end)
        local bottom = box.AbsolutePosition.Y + box.AbsoluteSize.Y
        local limit = gui.AbsoluteSize.Y - kbY - 12
        if bottom > limit then
            scroll.CanvasPosition = scroll.CanvasPosition + Vector2.new(0, bottom - limit)
        end
    end

    table.insert(window._connections, UIS:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(function()
        local box = UIS:GetFocusedTextBox()
        if box and box:IsDescendantOf(gui) then
            beginFieldLift(box)
        end
    end))
    table.insert(window._connections, UIS.TextBoxFocused:Connect(function(box)
        if box and box:IsDescendantOf(gui) then
            beginFieldLift(box)
        end
    end))
    
    --=========================================================================
    -- ADD PANEL (Section/Category)
    --=========================================================================
    function window:AddPanel(name, position)
        local theme = CurrentTheme
        local btnSize = getHeaderBtnSize()
        local headerH = minTouchLogical(44)
        local retainedPosition = position
        local isBuiltin = not builtinsComplete
        local navGroup = isBuiltin and "UI" or "Script"

        local panel = create("Frame", {
            Name = generateRandomName(8),
            BackgroundColor3 = theme.panel,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            AutomaticSize = Enum.AutomaticSize.None,
            Active = true,
            ClipsDescendants = true,
            Visible = false,
            Parent = panelContainer
        })

        local header = create("Frame", {
            Name = "Header",
            BackgroundColor3 = theme.panelHeader,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, headerH),
            Active = true,
            Parent = panel
        })

        local headerTitle = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(btnSize * 2 + 16), 1, 0),
            Position = UDim2.fromOffset(10, 0),
            Text = name,
            TextColor3 = themedTextColor(theme),
            Font = FONT_TITLE,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = header
        })

        local collapseBtn = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(btnSize, btnSize),
            Position = UDim2.new(1, -(btnSize + 4), 0.5, -btnSize / 2),
            Text = CHEVRON_DN,
            TextColor3 = theme.textDim,
            Font = FONT_ICON,
            TextSize = scaled(14),
            AutoButtonColor = false,
            Active = true,
            ZIndex = 3,
            Parent = header
        })
        applyFocusStyle(collapseBtn)
        collapseBtn.MouseEnter:Connect(function()
            collapseBtn.TextColor3 = CurrentTheme.text
        end)
        collapseBtn.MouseLeave:Connect(function()
            collapseBtn.TextColor3 = CurrentTheme.textDim
        end)

        local pinBtn = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(btnSize, btnSize),
            Position = UDim2.new(1, -(btnSize * 2 + 4), 0.5, -btnSize / 2),
            Text = "",
            AutoButtonColor = false,
            Active = true,
            ZIndex = 3,
            Parent = header
        })
        makeRounded(pinBtn, FIELD_RADIUS)
        local pinGlyph = createPinGlyph(pinBtn, theme.textDim)
        applyFocusStyle(pinBtn)
        attachTooltip(pinBtn, "Keep this panel visible when the menu is closed")

        local scroll = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, -headerH),
            Position = UDim2.fromOffset(0, headerH),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 5,
            ScrollBarImageColor3 = theme.stroke,
            Active = true,
            Parent = panel
        })
        
        local content = create("Frame", {
            Name = "Content",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = false,
            Active = true,
            Parent = scroll
        })
        
        create("UIListLayout", {
            Parent = content,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2)
        })
        
        create("UIPadding", {
            Parent = content,
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8)
        })
        
        local collapsed = false

        local function clampPanelToViewport()
        end
        
        local function setTreeSelectable(root, on)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("GuiButton") or d:IsA("TextBox") then
                    pcall(function()
                        d.Selectable = on
                    end)
                end
            end
        end

        bindActivate(collapseBtn, function()
            collapsed = not collapsed
            collapseBtn.Text = collapsed and CHEVRON_UP or CHEVRON_DN
            collapseBtn.Rotation = 0
            scroll.Visible = not collapsed
            content.Visible = not collapsed
            setTreeSelectable(content, not collapsed)
            if collapsed then
                pcall(function()
                    GuiService.SelectedObject = nil
                end)
            end
        end)

        local panelObj
        panelObj = {
            Instance = panel,
            Header = header,
            Content = content,
            Name = name,
            Pinned = false,
            _modules = {},
            _panelWidth = 0,
            _clamp = clampPanelToViewport,
            _userMoved = false,
            _rightStack = isBuiltin,
            _manuallyHidden = false,
            _navGroup = navGroup,
            _scroll = scroll,
            _retainedPosition = retainedPosition,
            _collapsed = false,
        }

        -- ponytail: duplicate panel-name pin keys share one saved flag
        local function updatePinVisual()
            local t = CurrentTheme
            if panelObj.Pinned then
                pinBtn.BackgroundColor3 = t.accent
                pinBtn.BackgroundTransparency = 0.55
                pinGlyph:Paint(t.text)
            else
                pinBtn.BackgroundTransparency = 1
                pinGlyph:Paint(t.textDim)
            end
        end

        function panelObj:SetPinned(v)
            panelObj.Pinned = v and true or false
            SavedSettings.pinnedPanels = SavedSettings.pinnedPanels or {}
            SavedSettings.pinnedPanels[name] = panelObj.Pinned
            saveSettings()
            updatePinVisual()
            if not fullMode then
                syncPinnedMode()
            end
        end

        function panelObj:GetPinned()
            return panelObj.Pinned == true
        end

        function panelObj:showFromNavigator()
            panelObj._manuallyHidden = false
            local row = panelNavRows[panelObj]
            if row then
                row.Visible = true
            end
            if not fullMode then
                fullMode = true
                pinnedMode = false
                uiVisible = true
                shell.Visible = true
                syncPinnedMode()
            end
            selectCategory(panelObj)
            if row then
                pcall(function()
                    navScroll.CanvasPosition = Vector2.new(0, math.max(0, row.AbsolutePosition.Y - navScroll.AbsolutePosition.Y + navScroll.CanvasPosition.Y - 8))
                end)
            end
        end

        function panelObj:toggleFromNavigator()
            if panelObj._manuallyHidden then
                panelObj:showFromNavigator()
            else
                panelObj._manuallyHidden = true
                panel.Visible = false
                local row = panelNavRows[panelObj]
                if row then
                    row.Visible = false
                end
                if activePanel == panelObj then
                    local nextP = nearestVisiblePanel(panelObj)
                    if nextP then
                        selectCategory(nextP)
                    end
                end
                refreshNavList()
            end
        end

        bindActivate(pinBtn, function()
            panelObj:SetPinned(not panelObj.Pinned)
        end)
        pinBtn.MouseEnter:Connect(function()
            if not panelObj.Pinned then
                pinGlyph:Paint(CurrentTheme.text)
            end
        end)
        pinBtn.MouseLeave:Connect(function()
            updatePinVisual()
        end)

        if SavedSettings.pinnedPanels and SavedSettings.pinnedPanels[name] == true then
            panelObj.Pinned = true
            updatePinVisual()
        end
        
        subscribeTheme(function(t)
            panel.BackgroundColor3 = t.panel
            header.BackgroundColor3 = t.panelHeader
            headerTitle.TextColor3 = themedTextColor(t)
            collapseBtn.TextColor3 = t.textDim
            updatePinVisual()
            local stroke = panel:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = OUTLINE end
        end)
        
        table.insert(windowPanels, panelObj)
        registerCategoryNav(panelObj)
        addScaleListener(function()
            local h = minTouchLogical(44)
            header.Size = UDim2.new(1, 0, 0, h)
            collapseBtn.Size = UDim2.fromOffset(h, h)
            pinBtn.Size = UDim2.fromOffset(h, h)
            if not pinnedMode then
                applyPageChrome(panelObj, false)
            else
                applyPageChrome(panelObj, true)
            end
        end)
        if isBuiltin and name == "Settings" then
            selectCategory(panelObj, { keepDrawer = true })
        elseif (not isBuiltin) and (not firstScriptSelected) then
            firstScriptSelected = true
            selectCategory(panelObj)
        else
            panel.Visible = false
        end
        
        --=====================================================================
        -- ADD MODULE (with expandable settings)
        --=====================================================================
        function panelObj:AddModule(cfg)
            cfg = cfg or {}
            local theme = CurrentTheme
            local hasSettings = cfg.settings and #cfg.settings > 0
            local persistToggle = cfg.persist ~= false
            local moduleH = getModuleH()
            local isToggle = cfg.type == "toggle" or cfg.type == nil
            local isButton = cfg.type == "button"
            local isDestroy = isButton and cfg.name == "Destroy UI"
            
            local moduleHolder = create("Frame", {
                Name = generateRandomName(8),
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, moduleH),
                AutomaticSize = Enum.AutomaticSize.None,
                Parent = content
            })
            
            local moduleRow = create("Frame", {
                Name = "Row",
                BackgroundColor3 = theme.panel,
                BackgroundTransparency = isButton and 1 or 0,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, moduleH),
                Parent = moduleHolder
            })
            
            local moduleNameStr = cfg.name or "Module"
            local enabled = cfg.default or false
            local gameToggleStates = getGameToggleStates()
            if persistToggle and isToggle and gameToggleStates[moduleNameStr] ~= nil then
                enabled = gameToggleStates[moduleNameStr]
            end

            local hitTarget = moduleRow
            if isButton then
                hitTarget = create("Frame", {
                    BackgroundColor3 = theme.hover,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, -10, 0, math.max(22, moduleH - 4)),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Parent = moduleRow
                })
                makeRounded(hitTarget, Config.controlRadius)
                makeStroke(hitTarget, isDestroy and DESTROY_RED or theme.divider, 1)
                trackHover(hitTarget, theme.hover, theme.stroke)
            else
                trackHover(moduleRow, theme.panel, theme.hover)
            end
            
            local moduleBtn = create("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = "",
                AutoButtonColor = false,
                Parent = hitTarget
            })
            applyFocusStyle(moduleBtn)
            local rowDragSkip = false
            local rowPressPos
            moduleBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    rowDragSkip = false
                    rowPressPos = Vector2.new(input.Position.X, input.Position.Y)
                end
            end)
            moduleBtn.InputChanged:Connect(function(input)
                if not rowPressPos then
                    return
                end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    local d = Vector2.new(input.Position.X, input.Position.Y) - rowPressPos
                    if d.Magnitude > 10 then
                        rowDragSkip = true
                    end
                end
            end)
            
            local stateCell
            local cellSz = getStateCellSize()
            local switchW = getSwitchW()
            local expandW = hasSettings and minTouchLogical(44) or 0
            if isToggle then
                stateCell = createStateCell(moduleRow, enabled, {
                    mode = "switch",
                    size = cellSz,
                    width = switchW,
                    position = UDim2.fromOffset(6, math.floor((moduleH - cellSz) / 2)),
                    zIndex = 3,
                })
                local stateWord = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(28, moduleH),
                    Position = UDim2.fromOffset(6 + switchW + 4, 0),
                    Text = enabled and "On" or "Off",
                    TextColor3 = theme.textDim,
                    Font = FONT_BODY,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 3,
                    Parent = moduleRow
                })
                moduleRow:SetAttribute("StateWord", true)
                stateCell._word = stateWord
            end
            
            local function getInitialTextColor()
                if isDestroy then
                    return DESTROY_RED
                end
                return themedTextColor()
            end
            
            local textLeft = 8
            local textRight = 8
            if isToggle then
                textLeft = 6 + switchW + 8 + 28
            end
            if hasSettings then
                textRight = expandW + 4
            end
            
            local moduleNameLabel = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -(textLeft + textRight), 1, 0),
                Position = UDim2.fromOffset(isButton and 4 or textLeft, 0),
                Text = cfg.name or "Module",
                TextColor3 = getInitialTextColor(),
                Font = FONT_TITLE,
                TextSize = math.max(13, scaled(13)),
                TextXAlignment = isButton and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = moduleBtn
            })
            if isButton then
                moduleNameLabel.Size = UDim2.new(1, hasSettings and -22 or -8, 1, 0)
                moduleNameLabel.Position = UDim2.fromOffset(4, 0)
            end
            local moduleName = moduleNameLabel
            
            local expandBtn
            local expanded = false
            
            if hasSettings then
                expandBtn = create(isButton and "TextLabel" or "TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(expandW, isButton and math.max(22, moduleH - 4) or moduleH),
                    Position = UDim2.new(1, -expandW, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Text = CHEVRON_DN,
                    TextColor3 = theme.textDim,
                    Font = FONT_ICON,
                    TextSize = 12,
                    ZIndex = 4,
                    Parent = hitTarget
                })
                if expandBtn:IsA("TextButton") then
                    expandBtn.AutoButtonColor = false
                    applyFocusStyle(expandBtn)
                end
            end
            
            local settingsContainer
            local settingsLayout
            if hasSettings then
                settingsContainer = create("Frame", {
                    Name = "Settings",
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, -10, 0, 0),
                    Position = UDim2.fromOffset(10, moduleH),
                    ClipsDescendants = true,
                    Visible = false,
                    AutomaticSize = Enum.AutomaticSize.None,
                    Parent = moduleHolder
                })
                create("Frame", {
                    BackgroundColor3 = theme.accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 2, 1, 0),
                    Position = UDim2.fromOffset(0, 0),
                    Parent = settingsContainer
                })
                
                settingsLayout = create("UIListLayout", {
                    Parent = settingsContainer,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 4)
                })
                
                create("UIPadding", {
                    Parent = settingsContainer,
                    PaddingTop = UDim.new(0, 6),
                    PaddingBottom = UDim.new(0, 6),
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 8)
                })
            end
            
            local function updateState()
                local currentTheme = CurrentTheme
                if moduleNameLabel and typeof(moduleNameLabel) == "Instance" and moduleNameLabel:IsA("TextLabel") and moduleNameLabel.Parent then
                    if isDestroy then
                        moduleNameLabel.TextColor3 = DESTROY_RED
                    else
                        moduleNameLabel.TextColor3 = themedTextColor(currentTheme)
                    end
                end
                if stateCell then
                    stateCell:Set(enabled)
                    if stateCell._word then
                        stateCell._word.Text = enabled and "On" or "Off"
                    end
                end
            end
            
            -- Function to toggle settings expansion (with smooth animation)
            local function layoutExpanded()
                if not settingsContainer then
                    moduleHolder.Size = UDim2.new(1, 0, 0, moduleH)
                    return
                end
                if not expanded then
                    settingsContainer.Visible = false
                    settingsContainer.Size = UDim2.new(1, 0, 0, 0)
                    moduleHolder.Size = UDim2.new(1, 0, 0, moduleH)
                    return
                end
                local h = 12
                if settingsLayout then
                    h = settingsLayout.AbsoluteContentSize.Y + 12
                end
                if h < 12 then
                    h = 12
                end
                settingsContainer.Visible = true
                settingsContainer.Size = UDim2.new(1, 0, 0, h)
                moduleHolder.Size = UDim2.new(1, 0, 0, moduleH + h)
            end

            local function toggleExpand()
                if not hasSettings then return end
                expanded = not expanded
                if expandBtn then
                    expandBtn.Text = expanded and CHEVRON_UP or CHEVRON_DN
                    expandBtn.Rotation = 0
                end
                
                if expanded then
                    settingsContainer.Visible = true
                    settingsContainer.BackgroundTransparency = 1
                    layoutExpanded()
                    tween(settingsContainer, { BackgroundTransparency = 0 }, 0.12)
                    openNestedCloser = function()
                        if expanded then
                            toggleExpand()
                        end
                    end
                else
                    tween(settingsContainer, { BackgroundTransparency = 1 }, 0.10)
                    task.delay(0.10, function()
                        if not expanded then
                            layoutExpanded()
                        end
                    end)
                    openNestedCloser = nil
                    layoutExpanded()
                end
                debugLog("Module '" .. (cfg.name or "Module") .. "' expanded: " .. tostring(expanded))
            end

            if settingsLayout then
                settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    if expanded then
                        layoutExpanded()
                    end
                end)
            end
            addScaleListener(function()
                moduleH = getModuleH()
                moduleRow.Size = UDim2.new(1, 0, 0, moduleH)
                layoutExpanded()
            end)
            
            if cfg.type == "toggle" or cfg.type == nil then
                -- Apply initial state if it was loaded from saved settings
                local gameToggleStates = getGameToggleStates()
                local wasLoadedFromSave = persistToggle and gameToggleStates[moduleNameStr] ~= nil
                if wasLoadedFromSave then
                    -- State was loaded from saved settings, apply it visually
                    updateState()
                    setModuleActive(moduleNameStr, enabled)
                    -- Call callback with saved state (notifications are suppressed during initial load by Notify function)
                    if cfg.callback then
                        task.delay(0.5, function()
                            task.spawn(cfg.callback, enabled)
                        end)
                    end
                elseif (not persistToggle) and enabled then
                    updateState()
                    setModuleActive(moduleNameStr, enabled)
                    if cfg.callback then
                        task.delay(0.5, function()
                            task.spawn(cfg.callback, enabled)
                        end)
                    end
                end

                local longPressFired = false
                local pressToken = 0
                
                moduleBtn.Activated:Connect(function()
                    if rowDragSkip then
                        rowDragSkip = false
                        return
                    end
                    if longPressFired then
                        longPressFired = false
                        return
                    end
                    enabled = not enabled
                    updateState()
                    -- Save toggle state (game-specific) unless persist = false
                    if persistToggle then
                        local gameToggleStates = getGameToggleStates()
                        gameToggleStates[moduleNameStr] = enabled
                        saveSettings()
                    end
                    -- Update ArrayList
                    setModuleActive(moduleNameStr, enabled)
                    if cfg.callback then
                        task.spawn(cfg.callback, enabled)
                    end
                    if cfg.notify then
                        local notifyMsg = cfg.notifyText or (cfg.name .. (enabled and " enabled" or " disabled"))
                        local notifyDur = cfg.notifyDuration or 2
                        local notifyOpts = cfg.notifyConfig
                        if notifyOpts == "default" or notifyOpts == nil then
                            window:Notify(notifyMsg, notifyDur)
                        else
                            window:Notify(notifyMsg, notifyDur, notifyOpts)
                        end
                    end
                end)

                if UIS.TouchEnabled and hasSettings then
                    moduleRow.InputBegan:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.Touch then
                            return
                        end
                        local mouse = UIS:GetMouseLocation()
                        if expandBtn and guiContains(expandBtn, mouse) then
                            return
                        end
                        pressToken = pressToken + 1
                        local token = pressToken
                        longPressFired = false
                        task.delay(0.4, function()
                            if token == pressToken then
                                longPressFired = true
                                toggleExpand()
                            end
                        end)
                    end)
                    moduleRow.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch then
                            pressToken = pressToken + 1
                        end
                    end)
                end
            elseif cfg.type == "button" then
                local longPressFired = false
                local pressToken = 0
                -- Enhanced button click animation
                moduleBtn.MouseButton1Down:Connect(function()
                    moduleRow.BackgroundColor3 = CurrentTheme.bg
                end)
                
                moduleBtn.MouseButton1Up:Connect(function()
                    local hs = HoverStates[moduleRow]
                    if hs and hs.isHovered then
                        moduleRow.BackgroundColor3 = CurrentTheme.hover
                    else
                        moduleRow.BackgroundColor3 = CurrentTheme.panelHeader
                    end
                end)
                
                moduleBtn.Activated:Connect(function()
                    if rowDragSkip then
                        rowDragSkip = false
                        return
                    end
                    if longPressFired then
                        longPressFired = false
                        return
                    end
                    if hasSettings then
                        toggleExpand()
                        return
                    end
                    if cfg.callback then
                        task.spawn(cfg.callback)
                    end
                    if cfg.notify then
                        local notifyMsg = cfg.notifyText or (cfg.name .. " activated")
                        local notifyDur = cfg.notifyDuration or 2
                        local notifyOpts = cfg.notifyConfig
                        if notifyOpts == "default" or notifyOpts == nil then
                            window:Notify(notifyMsg, notifyDur)
                        else
                            window:Notify(notifyMsg, notifyDur, notifyOpts)
                        end
                    end
                end)

                if UIS.TouchEnabled and hasSettings then
                    moduleRow.InputBegan:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.Touch then
                            return
                        end
                        local mouse = UIS:GetMouseLocation()
                        if expandBtn and guiContains(expandBtn, mouse) then
                            return
                        end
                        pressToken = pressToken + 1
                        local token = pressToken
                        longPressFired = false
                        task.delay(0.4, function()
                            if token == pressToken then
                                longPressFired = true
                                toggleExpand()
                            end
                        end)
                    end)
                    moduleRow.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch then
                            pressToken = pressToken + 1
                        end
                    end)
                end
            end
            
            if cfg.tooltip then
                attachTooltip(moduleRow, cfg.tooltip)
            end
            
            -- Expand button click
            if hasSettings and expandBtn and expandBtn:IsA("GuiButton") then
                expandBtn.Activated:Connect(toggleExpand)
            end
            
            -- RIGHT-CLICK to expand settings (alternative to arrow)
            if hasSettings then
                moduleRow.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton2 then
                        toggleExpand()
                        end
                    end)
            end
            
            -- Track module for search
            table.insert(allSearchItems, {
                name = cfg.name or "Module",
                panel = name,
                group = navGroup,
                itemType = "module",
                instance = moduleHolder,
                row = moduleRow
            })
            
            -- Theme subscriber - update hover colors and toggle indicator
            subscribeTheme(function(t)
                if isButton then
                    updateHoverColors(hitTarget, t.hover, t.stroke)
                    local st = hitTarget:FindFirstChildOfClass("UIStroke")
                    if st then
                        st.Color = isDestroy and DESTROY_RED or OUTLINE
                    end
                else
                    updateHoverColors(moduleRow, t.panel, t.hover)
                end
                if moduleNameLabel and moduleNameLabel.Parent then
                    if isDestroy then
                        moduleNameLabel.TextColor3 = DESTROY_RED
                    else
                        moduleNameLabel.TextColor3 = themedTextColor(t)
                    end
                end
                if expandBtn then expandBtn.TextColor3 = t.textDim end
                if settingsContainer then settingsContainer.BackgroundColor3 = t.bg end
                if stateCell then
                    stateCell:Paint(t)
                end
            end)
            
            local moduleObj = {
                Instance = moduleHolder,
                Row = moduleRow,
                SettingsContainer = settingsContainer,
                _controls = {},
                _callback = cfg.callback, -- Store callback for destroy functionality
                _isToggle = isToggle, -- Store if this is a toggle
                _moduleName = moduleNameLabel, -- Store reference to update text color when setting changes
                _isButton = isButton, -- Store if this is a button
            }
            
            function moduleObj:Set(val)
                enabled = val
                updateState()
                -- Also update ArrayList
                if self._isToggle then
                    setModuleActive(cfg.name or "Module", enabled)
                end
            end
            
            function moduleObj:Get()
                return enabled
            end
            
            -- Method to trigger the callback (for destroy functionality)
            function moduleObj:TriggerCallback(val)
                if self._callback then
                    task.spawn(self._callback, val)
                end
            end
            
            if hasSettings and settingsContainer then
                for _, setting in ipairs(cfg.settings) do
                    local ctrl = panelObj:_addSetting(settingsContainer, setting)
                    if type(setting.capture) == "function" then
                        pcall(setting.capture, ctrl)
                    end
                    table.insert(moduleObj._controls, ctrl)
                end
            end
            
            table.insert(panelObj._modules, moduleObj)
            return moduleObj
        end
        
        --=====================================================================
        -- INTERNAL: Add setting to a container
        --=====================================================================
        function panelObj:_addSetting(container, setting)
            local theme = CurrentTheme
            local settingType = setting.type or "label"
            
            if settingType == "label" then
                local isBold = setting.bold == true
                local fontSize = math.max(13, setting.fontSize or 14)
                local fontColor = setting.color or (isBold and theme.text or theme.textDim)
                
                local displayText = setting.text or ""
                if isBold then
                    displayText = "<b>" .. displayText .. "</b>"
                end
                
                local labelHeight = math.max(scaled(fontSize + 4), getSettingH())
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, labelHeight),
                    Text = displayText,
                    TextColor3 = fontColor,
                    Font = FONT_BODY,
                    TextSize = fontSize,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = container
                })
                
                label:SetAttribute("IsBold", isBold)
                label:SetAttribute("FontSize", fontSize)
                label:SetAttribute("OriginalText", setting.text or "")
                if setting.color then
                    label:SetAttribute("HasCustomColor", true)
                    label:SetAttribute("CustomColorR", fontColor.R)
                    label:SetAttribute("CustomColorG", fontColor.G)
                    label:SetAttribute("CustomColorB", fontColor.B)
                end
                
                if setting.tooltip then attachTooltip(label, setting.tooltip) end
                if not setting.color then
                    subscribeTheme(function(t)
                        if label and label.Parent then
                            local bold = label:GetAttribute("IsBold")
                            label.TextColor3 = bold and t.text or t.textDim
                        end
                    end)
                end
                return label
                
            elseif settingType == "divider" then
                local wrap = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 11),
                    Parent = container
                })
                local divider = create("Frame", {
                    BackgroundColor3 = theme.divider or theme.hover,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromOffset(0, 5),
                    Parent = wrap
                })
                subscribeTheme(function(t)
                    if divider and divider.Parent then
                        divider.BackgroundColor3 = t.divider or t.hover
                    end
                end)
                return wrap
                
            elseif settingType == "toggle" then
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, getSettingH()),
                    Parent = container
                })
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -(getSwitchW() + 14), 1, 0),
                    Position = UDim2.fromOffset(getSwitchW() + 12, 0),
                    Text = setting.text or "Toggle",
                    TextColor3 = themedTextColor(theme),
                    Font = FONT_BODY,
                    TextSize = math.max(13, scaled(13)),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row
                })
                
                local cellSz = getStateCellSize()
                local switchW = getSwitchW()
                local hitW = math.max(switchW + 8, isCompactViewport() and 44 or 28)
                local hit = create("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(hitW, getSettingH()),
                    Position = UDim2.fromOffset(0, 0),
                    Text = "",
                    AutoButtonColor = false,
                    Parent = row
                })
                applyFocusStyle(hit)
                local setDragSkip = false
                local setPressPos
                hit.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        setDragSkip = false
                        setPressPos = Vector2.new(input.Position.X, input.Position.Y)
                    end
                end)
                hit.InputChanged:Connect(function(input)
                    if not setPressPos then
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        if (Vector2.new(input.Position.X, input.Position.Y) - setPressPos).Magnitude > 10 then
                            setDragSkip = true
                        end
                    end
                end)
                local state = setting.default or false
                local cell = createStateCell(hit, state, {
                    mode = "switch",
                    size = cellSz,
                    width = switchW,
                    position = UDim2.fromOffset(4, math.floor((getSettingH() - cellSz) / 2)),
                    zIndex = 3,
                })
                
                hit.Activated:Connect(function()
                    if setDragSkip then
                        setDragSkip = false
                        return
                    end
                    state = not state
                    cell:Set(state)
                    if setting.callback then task.spawn(setting.callback, state) end
                end)
                
                if setting.tooltip then attachTooltip(row, setting.tooltip) end

                subscribeTheme(function(t)
                    label.TextColor3 = themedTextColor(t)
                end)
                
                return {
                    Set = function(_, v)
                        state = v and true or false
                        cell:Set(state, false)
                    end,
                    Get = function() return state end
                }
                
            elseif settingType == "slider" then
                local sliderHitH = minTouchLogical(44)
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 16 + sliderHitH),
                    Parent = container
                })
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.6, 0, 0, 16),
                    Text = setting.text or "Slider",
                    TextColor3 = themedTextColor(theme),
                    Font = FONT_BODY,
                    TextSize = scaled(15),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Parent = row
                })
                
                local valueLabel = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.4, 0, 0, 16),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    Text = tostring(setting.default or setting.min or 0) .. (setting.suffix or ""),
                    TextColor3 = theme.text,
                    Font = FONT_VALUE,
                    TextSize = 13,
                    Parent = row
                })
                
                local sliderHit = create("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, sliderHitH),
                    Position = UDim2.fromOffset(0, 16),
                    Text = "",
                    AutoButtonColor = false,
                    Parent = row
                })
                applyFocusStyle(sliderHit)
                
                local sliderBg = create("Frame", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 6),
                    Position = UDim2.fromOffset(0, 4),
                    Parent = sliderHit
                })
                makeRounded(sliderBg, 3)
                
                local sliderFill = create("Frame", {
                    BackgroundColor3 = theme.accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 0, 1, 0),
                    Parent = sliderBg
                })
                makeRounded(sliderFill, 3)
                
                local handle = create("Frame", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(12, 12),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Parent = sliderFill
                })
                makeRounded(handle, 6)
                makeStroke(handle, OUTLINE, 1)
                
                local min = setting.min or 0
                local max = setting.max or 100
                local step = setting.step or 1
                local value = math.clamp(setting.default or min, min, max)
                local rounding = setting.rounding or 0
                local suffix = setting.suffix or ""
                
                local function updateSlider(v, skipCallback, programmatic)
                    value = math.clamp(v, min, max)
                    value = math.floor(value / step + 0.5) * step
                    local pct = (value - min) / math.max(0.0001, max - min)
                    if programmatic then
                        tween(sliderFill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.08)
                    else
                        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
                    end
                    local display = rounding > 0 and (math.floor(value * 10^rounding + 0.5) / 10^rounding) or value
                    valueLabel.Text = tostring(display) .. suffix
                    -- Call callback unless we're skipping it (for initial setup)
                    if not skipCallback and setting.callback then
                        task.spawn(setting.callback, value)
                end
                end
                -- Initialize slider with default value and call callback
                updateSlider(value, false) -- Call callback on initial setup
                
                local dragging = false
                
                local function updateFromInput(input)
                    local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / math.max(1, sliderBg.AbsoluteSize.X), 0, 1)
                    local newVal = min + (max - min) * rel
                    updateSlider(newVal)
                end
                
                sliderHit.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateFromInput(input)
                    end
                end)

                sliderHit.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end
                    if GuiService.SelectedObject ~= sliderHit then
                        return
                    end
                    if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Down then
                        updateSlider(value - step, false, true)
                    elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.Up then
                        updateSlider(value + step, false, true)
                    end
                end)
                
                local sliderDragConn = UIS.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromInput(input)
                    end
                end)
                table.insert(window._connections, sliderDragConn)
                
                local sliderEndConn = UIS.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                table.insert(window._connections, sliderEndConn)
                
                if setting.tooltip then attachTooltip(row, setting.tooltip) end
                
                -- Theme subscriber for slider
                subscribeTheme(function(t)
                    label.TextColor3 = themedTextColor(t)
                    valueLabel.TextColor3 = t.text
                    sliderBg.BackgroundColor3 = t.bg
                    sliderFill.BackgroundColor3 = t.accent
                    handle.BackgroundColor3 = t.bg
                    local st = sliderBg:FindFirstChildOfClass("UIStroke")
                    if st then
                        st.Color = OUTLINE
                    end
                    local hs = handle:FindFirstChildOfClass("UIStroke")
                    if hs then
                        hs.Color = OUTLINE
                    end
                end)
                
                return {
                    _row = row,
                    _sliderBg = sliderHit,
                    Set = function(_, v) updateSlider(v, false, true) end,
                    Get = function() return value end
                }
                
            elseif settingType == "button" then
                local wrap = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, getSettingH() + 8),
                    Parent = container
                })
                local btn = create("TextButton", {
                    BackgroundColor3 = theme.hover,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, -16, 0, getSettingH()),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Text = setting.text or "Button",
                    TextColor3 = theme.text,
                    Font = FONT_BODY,
                    TextSize = math.max(14, scaled(15)),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    AutoButtonColor = false,
                    Parent = wrap
                })
                makeRounded(btn, Config.controlRadius)
                makeStroke(btn, theme.divider, 1)
                applyFocusStyle(btn)
                
                local baseColor = theme.hover
                local hoverColor = theme.stroke
                
                btn.MouseEnter:Connect(function()
                    tween(btn, { BackgroundColor3 = hoverColor }, 0.08)
                end)
                
                btn.MouseLeave:Connect(function()
                    tween(btn, { BackgroundColor3 = baseColor }, 0.08)
                end)
                
                btn.MouseButton1Down:Connect(function()
                    btn.BackgroundColor3 = CurrentTheme.bg
                end)
                
                btn.MouseButton1Up:Connect(function()
                    btn.BackgroundColor3 = HoverStates[btn] and HoverStates[btn].isHovered and CurrentTheme.stroke or CurrentTheme.hover
                end)
                
                btn.Activated:Connect(function()
                    if setting.callback then task.spawn(setting.callback) end
                    if setting.notify then
                        local notifyMsg = setting.notifyText or (setting.text .. " clicked")
                        local notifyDur = setting.notifyDuration or 2
                        local notifyOpts = setting.notifyConfig
                        if notifyOpts == "default" or notifyOpts == nil then
                            window:Notify(notifyMsg, notifyDur)
                        else
                            window:Notify(notifyMsg, notifyDur, notifyOpts)
                        end
                    end
                end)
                
                subscribeTheme(function(t)
                    baseColor = t.hover
                    hoverColor = t.stroke
                    btn.TextColor3 = t.text
                    local st = btn:FindFirstChildOfClass("UIStroke")
                    if st then st.Color = OUTLINE end
                    if not btn:IsMouseOver() then
                        btn.BackgroundColor3 = baseColor
                    end
                end)
                
                if setting.tooltip then attachTooltip(btn, setting.tooltip) end
                return btn
                
            elseif settingType == "input" then
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, getSettingH() + getFieldH() + 8),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = container
                })
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, getSettingH()),
                    Text = setting.text or "Input",
                    TextColor3 = themedTextColor(theme),
                    Font = FONT_BODY,
                    TextSize = scaled(15),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Parent = row
                })
                local inputNameStr = (setting.name or setting.text or "Input")
                local gameInputStates = getGameInputStates()
                
                -- Load saved value if available, otherwise use default
                local savedValue = gameInputStates[inputNameStr]
                local defaultValue = savedValue ~= nil and savedValue or (setting.default or "")
                
                local fieldH = getFieldH()
                local inputBox = create("TextBox", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, fieldH),
                    Position = UDim2.new(0, 0, 0, getSettingH() + 4),
                    Text = defaultValue,
                    PlaceholderText = setting.placeholder or "",
                    TextColor3 = theme.text,
                    PlaceholderColor3 = theme.textDim,
                    Font = FONT_BODY,
                    TextSize = math.max(14, scaled(14)),
                    ClearTextOnFocus = setting.clearOnFocus or false,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row
                })
                local inputStroke = styleField(inputBox)
                applyFocusStyle(inputBox)
                create("UIPadding", { Parent = inputBox, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
                
                inputBox.Focused:Connect(function()
                    inputStroke.Color = CurrentTheme.accent
                    beginFieldLift(inputBox)
                end)
                
                inputBox.FocusLost:Connect(function(enter)
                    inputStroke.Color = OUTLINE
                    restoreLiftedPanel()
                    gameInputStates[inputNameStr] = inputBox.Text
                    saveSettings()
                    debugLog("Input saved: " .. inputNameStr .. " = " .. tostring(inputBox.Text))
                    if setting.callback then task.spawn(setting.callback, inputBox.Text) end
                end)
                
                subscribeTheme(function(t)
                    label.TextColor3 = themedTextColor(t)
                    inputBox.BackgroundColor3 = t.bg
                    inputBox.TextColor3 = t.text
                    inputBox.PlaceholderColor3 = t.textDim
                    if not inputBox:IsFocused() then
                        inputStroke.Color = OUTLINE
                    else
                        inputStroke.Color = t.accent
                    end
                end)
                
                if setting.tooltip then attachTooltip(row, setting.tooltip) end
                
                return {
                    _row = row,
                    _inputBox = inputBox, -- For highlighting
                    Set = function(_, t) inputBox.Text = tostring(t or "") end,
                    Get = function() return inputBox.Text end
                }
                
            elseif settingType == "keybind" then
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, getSettingH()),
                    Parent = container
                })
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Text = setting.text or "Keybind",
                    TextColor3 = themedTextColor(theme),
                    Font = FONT_BODY,
                    TextSize = scaled(15),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Parent = row
                })
                
                local fieldH = getFieldH()
                local keyBtn = create("TextButton", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0.48, 0, 0, fieldH),
                    Position = UDim2.new(0.52, 0, 0.5, -fieldH / 2),
                    Text = keycodeToString(setting.default or Enum.KeyCode.Unknown),
                    TextColor3 = theme.text,
                    Font = FONT_VALUE,
                    TextSize = 13,
                    Parent = row
                })
                local keyStroke = styleField(keyBtn)
                keyStroke.Transparency = 1
                applyFocusStyle(keyBtn)
                
                local listening = false
                local currentKey = setting.default or Enum.KeyCode.Unknown
                local listenConn
                
                local function stopListen(restore)
                    listening = false
                    if listenConn then
                        listenConn:Disconnect()
                        listenConn = nil
                    end
                    if keybindCancel == stopListen then
                        keybindCancel = nil
                    end
                    keyStroke.Color = OUTLINE
                    if restore then
                        keyBtn.Text = keycodeToString(currentKey)
                    end
                end
                
                keyBtn.Activated:Connect(function()
                    if listening then return end
                    if not UIS.KeyboardEnabled then
                        keyBtn.Text = "Keyboard required"
                        task.delay(1.4, function()
                            if not listening and keyBtn and keyBtn.Parent then
                                keyBtn.Text = keycodeToString(currentKey)
                            end
                        end)
                        return
                    end
                    listening = true
                    keyBtn.Text = "Press key"
                    keyStroke.Color = CurrentTheme.accent
                    keybindCancel = function()
                        stopListen(true)
                    end
                    
                    listenConn = UIS.InputBegan:Connect(function(input)
                        if input.UserInputType ~= Enum.UserInputType.Keyboard then
                            return
                        end
                        if input.KeyCode == Enum.KeyCode.Escape then
                            stopListen(true)
                            return
                        end
                        currentKey = input.KeyCode
                        keyBtn.Text = keycodeToString(currentKey)
                        stopListen(false)
                        if setting.callback then task.spawn(setting.callback, currentKey) end
                    end)
                end)
                
                subscribeTheme(function(t)
                    label.TextColor3 = themedTextColor(t)
                    keyBtn.BackgroundColor3 = t.bg
                    keyBtn.TextColor3 = t.text
                    if not listening then
                        keyStroke.Color = OUTLINE
                    else
                        keyStroke.Color = t.accent
                    end
                end)
                
                if setting.tooltip then attachTooltip(row, setting.tooltip) end
                
                return {
                    _row = row,
                    _keyBtn = keyBtn, -- For highlighting
                    Set = function(_, kc) currentKey = kc; keyBtn.Text = keycodeToString(kc) end,
                    Get = function() return currentKey end
                }
                
            elseif settingType == "dropdown" then
                local dropLabelH = 18
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, dropLabelH + getFieldH() + 4),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = container
                })
                
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, dropLabelH),
                    Text = setting.text or "Dropdown",
                    TextColor3 = themedTextColor(theme),
                    Font = FONT_BODY,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row
                })
                
                local isMultiple = setting.multiple == true
                local options = setting.options or {}
                local selectedValues = {}
                
                -- Get dropdown name for saving/loading (prioritize name, then text)
                local persistDrop = setting.persist ~= false
                local dropdownNameStr = (setting.name or setting.text) or "Dropdown"
                local gameDropdownStates = getGameDropdownStates()
                
                -- Initialize selected values (check for saved state first)
                if isMultiple then
                    -- Check for saved multi-select state
                    if persistDrop and gameDropdownStates[dropdownNameStr] and type(gameDropdownStates[dropdownNameStr]) == "table" then
                        for _, v in ipairs(gameDropdownStates[dropdownNameStr]) do
                            selectedValues[v] = true
                        end
                    elseif setting.default and type(setting.default) == "table" then
                        for _, v in ipairs(setting.default) do
                            selectedValues[v] = true
                        end
                    end
                else
                    -- Check for saved single-select state
                    if persistDrop and gameDropdownStates[dropdownNameStr] ~= nil then
                        selectedValues = gameDropdownStates[dropdownNameStr]
                else
                    selectedValues = setting.default or options[1] or ""
                    end
                end
                
                local function getDisplayText()
                    if isMultiple then
                        local selected = {}
                        for opt, _ in pairs(selectedValues) do
                            table.insert(selected, opt)
                        end
                        if #selected == 0 then return "None selected" end
                        if #selected == 1 then return selected[1] end
                        if #selected <= 2 then return table.concat(selected, ", ") end
                        return #selected .. " selected"
                    else
                        return tostring(selectedValues)
                    end
                end
                
                local dropH = getFieldH()
                local dropBtn = create("TextButton", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, dropH),
                    Position = UDim2.new(0, 0, 0, dropLabelH),
                    Text = getDisplayText(),
                    TextColor3 = CurrentTheme.text,
                    Font = FONT_DROP,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    AutoButtonColor = false,
                    Parent = row
                })
                local dropStroke = styleField(dropBtn)
                applyFocusStyle(dropBtn)
                create("UIPadding", { Parent = dropBtn, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 16) })
                local dropArrow = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(16, dropH),
                    Position = UDim2.new(1, -16, 0, 0),
                    Text = CHEVRON_DN,
                    TextColor3 = theme.textDim,
                    Font = FONT_ICON,
                    TextSize = 14,
                    Parent = dropBtn
                })
                
                -- Call callback with saved value if it was loaded (notifications are suppressed during initial load by Notify function)
                local wasLoadedFromSave = persistDrop and gameDropdownStates[dropdownNameStr] ~= nil
                if wasLoadedFromSave and setting.callback then
                    task.delay(0.5, function()
                        task.spawn(function()
                            if isMultiple then
                                local result = {}
                                for k, _ in pairs(selectedValues) do
                                    table.insert(result, k)
                                end
                                setting.callback(result)
                            else
                                setting.callback(selectedValues)
                            end
                        end)
                    end)
                end
                
                -- Use ScrollingFrame for dropdowns with many options
                local maxVisibleOptions = 6
                local needsScroll = #options > maxVisibleOptions
                
                local dropList = create(needsScroll and "ScrollingFrame" or "Frame", {
                    BackgroundColor3 = theme.bg,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, dropLabelH + dropH + 2),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 100,
                    Parent = row
                })
                
                if needsScroll then
                    dropList.ScrollBarThickness = 6
                    dropList.ScrollBarImageColor3 = theme.stroke
                    dropList.CanvasSize = UDim2.new(0, 0, 0, 0)
                    dropList.AutomaticCanvasSize = Enum.AutomaticSize.Y
                end
                
                makeRounded(dropList, Config.controlRadius)
                makeStroke(dropList, theme.stroke)
                
                create("UIListLayout", {
                    Parent = dropList,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1)
                })

                local open = false
                local optionButtons = {}
                local dropOptSel = 1

                local function closeDrop()
                    if selectorOwner and selectorOwner.dropBtn == dropBtn then
                        closeSelectorSheet()
                    end
                    open = false
                    dropArrow.Text = CHEVRON_DN
                    dropStroke.Color = OUTLINE
                    dropList.Visible = false
                    dropList.Size = UDim2.new(1, 0, 0, 0)
                    if openDropdownCloser == closeDrop then
                        openDropdownCloser = nil
                        openDropdownNav = nil
                    end
                end

                local function updateOptionVisuals()
                    for i, data in ipairs(optionButtons) do
                        if isMultiple and data.cell then
                            data.cell:Set(selectedValues[data.opt] == true, false)
                        end
                        if data.btn then
                            data.btn.BackgroundColor3 = (i == dropOptSel and open) and CurrentTheme.hover or CurrentTheme.bg
                        end
                    end
                    dropBtn.Text = getDisplayText()
                    dropArrow.Text = open and CHEVRON_UP or CHEVRON_DN
                end

                local function applyMulti(opt)
                    selectedValues[opt] = not selectedValues[opt]
                    if not selectedValues[opt] then selectedValues[opt] = nil end
                    updateOptionVisuals()
                    local result = {}
                    for k, _ in pairs(selectedValues) do
                        table.insert(result, k)
                    end
                    if persistDrop then
                        local gameDropdownStates = getGameDropdownStates()
                        gameDropdownStates[dropdownNameStr] = result
                        saveSettings()
                    end
                    if setting.callback then
                        task.spawn(setting.callback, result)
                    end
                end

                local function applySingle(opt)
                    selectedValues = opt
                    dropBtn.Text = selectedValues
                    closeDrop()
                    if persistDrop then
                        local gameDropdownStates = getGameDropdownStates()
                        gameDropdownStates[dropdownNameStr] = selectedValues
                        if not SavedSettings.dropdownStates then
                            SavedSettings.dropdownStates = {}
                        end
                        saveSettings()
                    end
                    if setting.callback then task.spawn(setting.callback, selectedValues) end
                end
                
                local function buildOptions()
                    for _, child in ipairs(dropList:GetChildren()) do
                        if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
                    end
                    optionButtons = {}
                    dropOptSel = 1

                    if #options == 0 then
                        create("TextLabel", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 24),
                            Text = "No options",
                            TextColor3 = CurrentTheme.textDim,
                            Font = FONT_BODY,
                            TextSize = 14,
                            Parent = dropList
                        })
                        return
                    end
                    
                    for _, opt in ipairs(options) do
                        if isMultiple then
                            local optH = getFieldH()
                            local optRow = create("Frame", {
                                BackgroundColor3 = theme.bg,
                                BorderSizePixel = 0,
                                Size = UDim2.new(1, 0, 0, optH),
                                ZIndex = 101,
                                Parent = dropList
                            })
                            trackHover(optRow, theme.bg, theme.hover)
                            
                            local cell = createStateCell(optRow, selectedValues[opt] == true, {
                                mode = "mark",
                                size = 16,
                                position = UDim2.new(0, 8, 0.5, -8),
                                zIndex = 102,
                            })
                            
                            local optLabel = create("TextLabel", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, -36, 1, 0),
                                Position = UDim2.fromOffset(28, 0),
                                Text = opt,
                                TextColor3 = CurrentTheme.text,
                                Font = FONT_DROP,
                                TextSize = 13,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 102,
                                Parent = optRow
                            })
                            
                            local clickBtn = create("TextButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.fromScale(1, 1),
                                Text = "",
                                AutoButtonColor = false,
                                ZIndex = 103,
                                Parent = optRow
                            })
                            applyFocusStyle(clickBtn)
                            
                            table.insert(optionButtons, { btn = optRow, cell = cell, opt = opt, click = clickBtn, label = optLabel })
                            
                            clickBtn.Activated:Connect(function()
                                applyMulti(opt)
                            end)
                        else
                            local optH = getFieldH()
                            local optRow = create("Frame", {
                                BackgroundColor3 = theme.bg,
                                BorderSizePixel = 0,
                                Size = UDim2.new(1, 0, 0, optH),
                                ZIndex = 101,
                                Parent = dropList
                            })
                            trackHover(optRow, theme.bg, theme.hover)
                            local optLabel = create("TextLabel", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, -16, 1, 0),
                                Position = UDim2.fromOffset(8, 0),
                                Text = opt,
                                TextColor3 = CurrentTheme.text,
                                Font = FONT_DROP,
                                TextSize = 13,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 102,
                                Parent = optRow
                            })
                            local optBtn = create("TextButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.fromScale(1, 1),
                                Text = "",
                                AutoButtonColor = false,
                                ZIndex = 103,
                                Parent = optRow
                            })
                            applyFocusStyle(optBtn)
                            table.insert(optionButtons, { btn = optRow, opt = opt, click = optBtn, label = optLabel })
                            
                            optBtn.Activated:Connect(function()
                                applySingle(opt)
                            end)
                    end
                end
                end
                buildOptions()
                
                dropBtn.Activated:Connect(function()
                    local ctl = {
                        label = setting.text or "Dropdown",
                        isMultiple = isMultiple,
                        dropBtn = dropBtn,
                        getOptions = function()
                            return options
                        end,
                        getSelected = function()
                            return selectedValues
                        end,
                        applySingle = applySingle,
                        applyMulti = applyMulti,
                        setOpenVisual = function(on)
                            open = on
                            dropArrow.Text = on and CHEVRON_UP or CHEVRON_DN
                            dropStroke.Color = on and CurrentTheme.accent or OUTLINE
                        end
                    }
                    openSelectorSheet(ctl)
                end)
                
                -- Theme subscriber for dropdown options
                subscribeTheme(function(t)
                    label.TextColor3 = themedTextColor(t)
                    dropBtn.BackgroundColor3 = t.bg
                    dropBtn.TextColor3 = t.text
                    dropArrow.TextColor3 = t.textDim
                    dropList.BackgroundColor3 = t.bg
                    if dropStroke then
                        dropStroke.Color = open and t.accent or OUTLINE
                    end
                    local listStroke = dropList:FindFirstChildOfClass("UIStroke")
                    if listStroke then
                        listStroke.Color = OUTLINE
                    end
                    if needsScroll then
                        dropList.ScrollBarImageColor3 = t.stroke
                    end
                    for _, data in ipairs(optionButtons) do
                        if data.btn then
                            updateHoverColors(data.btn, t.bg, t.hover)
                        if data.label then
                            data.label.TextColor3 = t.text
                        elseif data.btn:IsA("TextButton") then
                            data.btn.TextColor3 = t.text
                        end
                        end
                        if data.cell then
                            data.cell:Paint(t)
                        end
                    end
                    for _, child in ipairs(dropList:GetChildren()) do
                        if child:IsA("TextLabel") and child.Text == "No options" then
                            child.TextColor3 = t.textDim
                        end
                    end
                    updateOptionVisuals()
                end)
                
                if setting.tooltip then attachTooltip(row, setting.tooltip) end

                return {
                    _row = row, -- Expose row for search tracking
                    _dropBtn = dropBtn, -- Expose button for highlighting
                    Set = function(_, v)
                        if isMultiple and type(v) == "table" then
                            selectedValues = {}
                            for _, val in ipairs(v) do selectedValues[val] = true end
                        else
                            selectedValues = v
                        end
                        updateOptionVisuals()
                    end,
                    Get = function()
                        if isMultiple then
                            local result = {}
                            for k, _ in pairs(selectedValues) do table.insert(result, k) end
                            return result
                        end
                        return selectedValues
                    end,
                    SetOptions = function(_, newOpts)
                        options = newOpts
                        buildOptions()
                        if selectorOwner and selectorOwner.dropBtn == dropBtn then
                            rebuildSelectorList()
                            layoutSelectorSheet()
                        end
                    end
                }
            end
        end
        
        --=====================================================================
        -- SHORTHAND METHODS
        --=====================================================================
        function panelObj:AddLabel(text, tooltip, formatOptions)
            formatOptions = formatOptions or {}
            return self:_addSetting(content, { 
                type = "label", 
                text = text, 
                tooltip = tooltip,
                bold = formatOptions.bold,
                fontSize = formatOptions.fontSize,
                color = formatOptions.color
            })
        end
        
        function panelObj:AddDivider()
            return self:_addSetting(content, { type = "divider" })
        end
        
        function panelObj:AddToggle(cfg)
            cfg.type = "toggle"
            return self:AddModule(cfg)
        end
        
        function panelObj:AddButton(cfg)
            cfg.type = "button"
            return self:AddModule(cfg)
        end
        
        function panelObj:AddDropdown(cfg)
            local control = self:_addSetting(content, {
                type = "dropdown",
                text = cfg.text or cfg.name,
                name = cfg.name,
                options = cfg.options,
                default = cfg.default,
                multiple = cfg.multiple,
                persist = cfg.persist,
                callback = cfg.callback,
                tooltip = cfg.tooltip
            })
            -- Track for search (use returned row and dropBtn for proper highlighting)
            table.insert(allSearchItems, {
                name = cfg.text or cfg.name or "Dropdown",
                panel = name,
                group = navGroup,
                itemType = "dropdown",
                instance = control._row,
                row = control._dropBtn or control._row
            })
            return control
        end
        
        function panelObj:AddSlider(cfg)
            local control = self:_addSetting(content, {
                type = "slider",
                text = cfg.text or cfg.name,
                min = cfg.min,
                max = cfg.max,
                step = cfg.step,
                default = cfg.default,
                rounding = cfg.rounding,
                suffix = cfg.suffix,
                callback = cfg.callback,
                tooltip = cfg.tooltip
            })
            -- Track for search (use returned row for proper highlighting)
            table.insert(allSearchItems, {
                name = cfg.text or cfg.name or "Slider",
                panel = name,
                group = navGroup,
                itemType = "slider",
                instance = control._row,
                row = control._sliderBg or control._row
            })
            return control
        end
        
        function panelObj:AddInput(cfg)
            local control = self:_addSetting(content, {
                type = "input",
                name = cfg.name, -- Pass name for saving
                text = cfg.text or cfg.name,
                default = cfg.default,
                placeholder = cfg.placeholder,
                clearOnFocus = cfg.clearOnFocus,
                callback = cfg.callback,
                tooltip = cfg.tooltip
            })
            -- Track for search (use returned row for proper highlighting)
            table.insert(allSearchItems, {
                name = cfg.text or cfg.name or "Input",
                panel = name,
                group = navGroup,
                itemType = "input",
                instance = control._row,
                row = control._inputBox or control._row
            })
            return control
        end
        
        function panelObj:AddKeybind(cfg)
            local control = self:_addSetting(content, {
                type = "keybind",
                text = cfg.text or cfg.name,
                default = cfg.default,
                callback = cfg.callback,
                tooltip = cfg.tooltip
            })
            -- Track for search (use returned row for proper highlighting)
            table.insert(allSearchItems, {
                name = cfg.text or cfg.name or "Keybind",
                panel = name,
                group = navGroup,
                itemType = "keybind",
                instance = control._row,
                row = control._keyBtn or control._row
            })
            return control
        end
        
        return panelObj
    end
    
    --=========================================================================
    -- CREATE DEFAULT SETTINGS PANEL
    --=========================================================================
    local settingsPanel = window:AddPanel("Settings", getRightStackPosition())
    settingsPanel._rightStack = true

    debugPanel = window:AddPanel("Debug", getRightStackPosition())
    debugPanel._rightStack = true
    window.DebugPanel = debugPanel
    window:SetDebugMode(Config.debugMode)

    do
        local logScroll = create("ScrollingFrame", {
            BackgroundColor3 = CurrentTheme.bg,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 160),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = CurrentTheme.stroke,
            Parent = debugPanel.Content
        })
        create("UIListLayout", {
            Parent = logScroll,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 1)
        })
        create("UIPadding", {
            Parent = logScroll,
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4)
        })
        local logLabels = {}
        local emptyLog = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Text = "No logs",
            TextColor3 = CurrentTheme.textDim,
            Font = FONT_VALUE,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = logScroll
        })
        local function addLogLine(entry)
            if emptyLog then
                emptyLog:Destroy()
                emptyLog = nil
            end
            local lab = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -4, 0, 14),
                Text = entry,
                TextColor3 = CurrentTheme.textDim,
                Font = FONT_VALUE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = logScroll
            })
            table.insert(logLabels, lab)
            while #logLabels > 100 do
                local old = table.remove(logLabels, 1)
                if old then
                    old:Destroy()
                end
            end
        end
        for _, entry in ipairs(DebugLogs) do
            addLogLine(entry)
        end
        table.insert(DebugSubscribers, function(entry)
            addLogLine(entry)
        end)
        subscribeTheme(function(t)
            logScroll.BackgroundColor3 = t.bg
            logScroll.ScrollBarImageColor3 = t.stroke
            if emptyLog then
                emptyLog.TextColor3 = t.textDim
            end
            for _, lab in ipairs(logLabels) do
                if lab and lab.Parent then
                    lab.TextColor3 = t.textDim
                end
            end
        end)
    end
    
    -- UI Scale control with +/- buttons
    do
        local compactScale = isCompactViewport()
        local btnSz = compactScale and 44 or 24
        local dispW = 56
        local scaleRow = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, compactScale and (getSettingH() + 8 + btnSz) or (math.max(getSettingH(), btnSz) + 4)),
            Parent = settingsPanel.Content
        })
        
        local ctrlW = btnSz * 2 + dispW + 8
        local scaleLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = compactScale and UDim2.new(1, 0, 0, getSettingH()) or UDim2.new(1, -ctrlW, 0, getSettingH()),
            Text = "UI Scale",
            TextColor3 = theme.text,
            Font = FONT_BODY,
            TextSize = math.max(14, scaled(14)),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = scaleRow
        })
        
        local ctrlY = compactScale and (getSettingH() + 4) or 0
        local minusBtn = create("TextButton", {
            BackgroundColor3 = theme.hover,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(btnSz, btnSz),
            Position = compactScale and UDim2.fromOffset(0, ctrlY) or UDim2.new(1, -ctrlW, 0.5, -btnSz / 2),
            Text = "-",
            TextColor3 = theme.text,
            Font = FONT_TITLE,
            TextSize = 16,
            ZIndex = 2,
            AutoButtonColor = false,
            Parent = scaleRow
        })
        makeRounded(minusBtn, Config.controlRadius)
        trackHover(minusBtn, theme.hover, theme.stroke)
        
        local scaleDisplay = create("TextLabel", {
            BackgroundColor3 = theme.bg,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(dispW, btnSz),
            Position = compactScale and UDim2.fromOffset(btnSz + 4, ctrlY) or UDim2.new(1, -(btnSz + dispW + 4), 0.5, -btnSz / 2),
            Text = string.format("%.2fx", Config.uiScale),
            TextColor3 = theme.text,
            Font = FONT_VALUE,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 2,
            Parent = scaleRow
        })
        makeRounded(scaleDisplay, Config.controlRadius)
        
        local plusBtn = create("TextButton", {
            BackgroundColor3 = theme.hover,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(btnSz, btnSz),
            Position = compactScale and UDim2.fromOffset(btnSz + 8 + dispW, ctrlY) or UDim2.new(1, -btnSz, 0.5, -btnSz / 2),
            Text = "+",
            TextColor3 = theme.text,
            Font = FONT_TITLE,
            TextSize = 16,
            ZIndex = 2,
            AutoButtonColor = false,
            Parent = scaleRow
        })
        makeRounded(plusBtn, Config.controlRadius)
        trackHover(plusBtn, theme.hover, theme.stroke)
        
        local function updateScaleDisplay()
            scaleDisplay.Text = string.format("%.2fx", Config.uiScale)
        end
        
        bindActivate(minusBtn, function()
            local newScale = math.max(0.8, Config.uiScale - 0.05)
            window:SetScale(newScale)
            updateScaleDisplay()
        end)
        
        bindActivate(plusBtn, function()
            local newScale = math.min(1.3, Config.uiScale + 0.05)
            window:SetScale(newScale)
            updateScaleDisplay()
        end)
        
        attachTooltip(scaleRow, "Adjust UI size with +/- buttons (0.8x - 1.3x)")
        
        subscribeTheme(function(t)
            scaleLabel.TextColor3 = t.text
            scaleDisplay.BackgroundColor3 = t.bg
            scaleDisplay.TextColor3 = t.text
            updateHoverColors(minusBtn, t.hover, t.stroke)
            updateHoverColors(plusBtn, t.hover, t.stroke)
            minusBtn.TextColor3 = t.text
            plusBtn.TextColor3 = t.text
        end)
    end
    
    settingsPanel:AddDivider()
    
    -- UI Toggle Key
    settingsPanel:AddKeybind({
        text = "Toggle Key",
        default = toggleKey,
        tooltip = "Key to show/hide the UI",
        callback = function(kc)
            window:SetToggleKey(kc)
            window:Notify("Toggle key changed to " .. keycodeToString(kc), 2)
        end
    })
    
    -- FPS Cap
    settingsPanel:AddSlider({
        text = "FPS Cap",
        min = 10,
        max = 500,
        step = 10,
        default = SavedSettings.fpsCap or 60,
        suffix = " fps",
        tooltip = "Limit client FPS (requires executor support)",
        callback = function(v)
            SavedSettings.fpsCap = v
            saveSettings()
            local ok = applyFpsCap(v)
            if not ok then
                window:Notify("FPS cap not supported by your executor", 3)
            end
        end
    })
    
    settingsPanel:AddDivider()
    
    -- Notification Position
    settingsPanel:AddDropdown({
        text = "Notify Pos",
        options = { "TopRight", "TopLeft", "BottomRight", "BottomLeft" },
        default = notifyPosition,
        tooltip = "Where notifications appear",
        callback = function(v)
            window:SetNotifyPosition(v)
        end
    })
    
    settingsPanel:AddDivider()
    
    -- ArrayList Position
    settingsPanel:AddDropdown({
        text = "ArrayList Pos",
        options = { "Right", "Left" },
        default = SavedSettings.arrayListPosition or "Right",
        tooltip = "Position of the active modules list",
        callback = function(v)
            window:SetArrayListPosition(v)
        end
    })
    
    settingsPanel:AddDivider()
    
    -- Theme Colored Text Toggle
    settingsPanel:_addSetting(settingsPanel.Content, {
        type = "toggle",
        text = "Theme Colored Text",
        default = SavedSettings.themeColoredText == true,
        tooltip = "Color labels with the theme accent. Off uses white",
        callback = function(v)
            SavedSettings.themeColoredText = v and true or false
            saveSettings()
            publishTheme(CurrentTheme)
            updateArrayList()
            window:Notify("Theme colored text " .. (v and "enabled" or "disabled"), 2)
        end
    })
    
    settingsPanel:AddDivider()
    
    -- Debug Mode Toggle
    settingsPanel:_addSetting(settingsPanel.Content, {
        type = "toggle",
        text = "Debug Mode",
        default = Config.debugMode,
        tooltip = "Show debug information for troubleshooting",
        callback = function(v)
            window:SetDebugMode(v)
            window:Notify("Debug mode " .. (v and "enabled" or "disabled"), 2)
        end
    })
    
    settingsPanel:AddDivider()
    
    settingsPanel:AddButton({
        name = "Join Discord",
        type = "button",
        tooltip = "Copy the Discord invite link",
        notify = false,
        callback = function()
            if copyToClipboard("https://discord.gg/dZvUNnvKgU") then
                window:Notify("Copied Discord invite", 2)
            else
                window:Notify("Could not copy invite", 2)
            end
        end
    })
    
    -- Show Changelog button
    settingsPanel:AddButton({
        name = "View Changelog",
        type = "button",
        tooltip = "View update history",
        notify = false,
        callback = function()
            window:ShowChangelog()
        end
    })
    
    settingsPanel:AddDivider()
    
    -- Destroy UI button
    settingsPanel:AddButton({
        name = "Destroy UI",
        type = "button",
        tooltip = "Completely removes the UI from the game",
        notify = false,
        callback = function()
            task.spawn(function()
                pcall(function()
                    window:Notify("Destroying UI...", 1)
                end)
                pcall(function()
                    window:Destroy()
                end)
            end)
        end
    })
    
    --=========================================================================
    -- MISC PANEL (under Settings: background, theme)
    --=========================================================================
    local miscPanel = window:AddPanel("Misc", getRightStackPosition())
    miscPanel._rightStack = true

    miscPanel:AddButton({
        name = "Background",
        notify = false,
        tooltip = "Open backdrop and particle settings",
        settings = {
            {
                type = "dropdown",
                text = "Mode",
                persist = false,
                options = BACKGROUND_MODE_CYCLE,
                default = SavedSettings.backgroundMode,
                tooltip = "Fullscreen backdrop when the menu is open",
                callback = function(v)
                    window:SetBackgroundMode(v)
                    if not isInitialLoad then
                        window:Notify("Background: " .. tostring(v), 2)
                    end
                end,
            },
            {
                type = "slider",
                text = "Density",
                min = 15,
                max = 500,
                step = 1,
                default = SavedSettings.backgroundParticleDensity,
                tooltip = "Particle count for animated backgrounds",
                callback = function(v)
                    SavedSettings.backgroundParticleDensity = math.clamp(math.floor(v + 0.5), 15, 500)
                    saveSettings()
                    refreshWeatherIfActive()
                end,
            },
            {
                type = "slider",
                text = "Speed",
                min = 20,
                max = 300,
                step = 1,
                default = SavedSettings.backgroundSpeed,
                suffix = "%",
                tooltip = "Particle travel speed",
                callback = function(v)
                    SavedSettings.backgroundSpeed = math.clamp(math.floor(v + 0.5), 20, 300)
                    saveSettings()
                    refreshWeatherIfActive()
                end,
            },
            {
                type = "slider",
                text = "Size",
                min = 10,
                max = 200,
                step = 1,
                default = SavedSettings.backgroundSize,
                suffix = "%",
                tooltip = "Particle size",
                callback = function(v)
                    SavedSettings.backgroundSize = math.clamp(math.floor(v + 0.5), 10, 200)
                    saveSettings()
                    refreshWeatherIfActive()
                end,
            },
            {
                type = "slider",
                text = "Opacity",
                min = 10,
                max = 100,
                step = 1,
                default = SavedSettings.backgroundOpacity,
                suffix = "%",
                tooltip = "Particle opacity",
                callback = function(v)
                    SavedSettings.backgroundOpacity = math.clamp(math.floor(v + 0.5), 10, 100)
                    saveSettings()
                    refreshWeatherIfActive()
                end,
            },
            {
                type = "dropdown",
                text = "Direction",
                persist = false,
                options = { "Down", "Up", "Left", "Right", "Diagonal" },
                default = SavedSettings.backgroundDirection,
                tooltip = "Particle travel direction",
                callback = function(v)
                    if VALID_BACKGROUND_DIRECTIONS[v] then
                        SavedSettings.backgroundDirection = v
                        saveSettings()
                        refreshWeatherIfActive()
                    end
                end,
            },
        },
    })
    
    local themeNames = {}
    for name, _ in pairs(Themes) do
        table.insert(themeNames, name)
    end
    table.sort(themeNames)
    
    miscPanel:AddDropdown({
        text = "Theme",
        options = themeNames,
        default = CurrentTheme.name,
        tooltip = "Change UI color theme and animations",
        callback = function(v)
            window:SetTheme(v)
        end,
    })
    
    miscPanel:AddDropdown({
        text = "Anti-AFK method",
        options = ANTIAFK_METHOD_OPTIONS,
        default = SavedSettings.antiafkMethod,
        tooltip = "The 1st method is usually all you need. For games that teleport you after idling, the other methods may help.",
        callback = function(v)
            SavedSettings.antiafkMethod = v
            saveSettings()
            if SavedSettings.antiafkEnabled then
                startAntiAfk()
            end
        end,
    })
    
    miscPanel:AddToggle({
        name = "Show open hint",
        default = SavedSettings.showOpenHint ~= false,
        persist = false,
        tooltip = "Show Press <key> to open when the menu is closed",
        callback = function(on)
            SavedSettings.showOpenHint = on and true or false
            saveSettings()
            hint.Visible = (not uiVisible) and SavedSettings.showOpenHint
            layoutHintAndMobileOpen()
        end,
    })

    miscPanel:AddToggle({
        name = "Anti-AFK enabled",
        default = SavedSettings.antiafkEnabled,
        callback = function(on)
            SavedSettings.antiafkEnabled = on and true or false
            saveSettings()
            if on then
                startAntiAfk()
            else
                stopAntiAfk()
            end
        end,
    })

    --=========================================================================
    -- GRAPHICS PANEL (under Misc)
    --=========================================================================
    local graphicsPanel = window:AddPanel("Graphics", getRightStackPosition())
    graphicsPanel._rightStack = true

    local function updateGraphicsPosition()
    end

    local lowGraphicsMod
    lowGraphicsMod = graphicsPanel:AddToggle({
        name = "Low graphics",
        default = SavedSettings.lowGraphics == true,
        persist = false,
        tooltip = "Lower quality and shadows for FPS. Saved between sessions. Use for overnight AFK.",
        callback = function(on)
            applyLowGraphics(on)
            SavedSettings.lowGraphics = on and true or false
            saveSettings()
            if not isInitialLoad then
                window:Notify(on and "Low graphics enabled" or "Low graphics disabled", 3)
            end
        end,
    })

    local noGraphicsMod
    noGraphicsMod = graphicsPanel:AddToggle({
        name = "No graphics",
        default = SavedSettings.noGraphics == true,
        persist = false,
        tooltip = "Disable 3D rendering. The world is invisible; the server and this menu still run. Saved between sessions.",
        callback = function(on)
            if on then
                local ok = applyNoGraphics(true)
                if not ok then
                    SavedSettings.noGraphics = false
                    saveSettings()
                    if noGraphicsMod then
                        noGraphicsMod:Set(false)
                    end
                    setModuleActive("No graphics", false)
                    if not isInitialLoad then
                        window:Notify("No graphics not supported on this client", 3)
                    end
                    return
                end
                SavedSettings.noGraphics = true
                saveSettings()
                if not isInitialLoad then
                    window:Notify("No graphics enabled - 3D rendering off", 3)
                end
            else
                applyNoGraphics(false)
                SavedSettings.noGraphics = false
                saveSettings()
                if not isInitialLoad then
                    window:Notify("No graphics disabled", 3)
                end
            end
        end,
    })

    graphicsPanel:AddDivider()

    local freecamMod
    freecamMod = graphicsPanel:AddToggle({
        name = "Freecam",
        default = false,
        persist = false,
        tooltip = "Spectator camera. Hold right click to look, WASD to move. Nested settings save speed and up/down keys. Character TPs do not move you.",
        settings = {
            {
                type = "slider",
                text = "Speed",
                min = 10,
                max = 250,
                step = 1,
                default = SavedSettings.freecamSpeed,
                tooltip = "Base studs per second. Shift multiplies by 2.5",
                callback = function(v)
                    SavedSettings.freecamSpeed = math.clamp(math.floor(v + 0.5), 10, 250)
                    saveSettings()
                end,
            },
            {
                type = "keybind",
                text = "Up key",
                default = keyFromName(SavedSettings.freecamUpKey, Enum.KeyCode.E),
                tooltip = "Rise while Freecam is on. Space still works",
                callback = function(kc)
                    SavedSettings.freecamUpKey = keycodeToString(kc)
                    saveSettings()
                    if freecamOn then
                        sinkFreecamMoveKeys(true)
                    end
                end,
            },
            {
                type = "keybind",
                text = "Down key",
                default = keyFromName(SavedSettings.freecamDownKey, Enum.KeyCode.Q),
                tooltip = "Descend while Freecam is on. LeftControl still works",
                callback = function(kc)
                    SavedSettings.freecamDownKey = keycodeToString(kc)
                    saveSettings()
                    if freecamOn then
                        sinkFreecamMoveKeys(true)
                    end
                end,
            },
        },
        callback = function(on)
            if on then
                local ok = startFreecam()
                if not ok then
                    if freecamMod then
                        freecamMod:Set(false)
                    end
                    setModuleActive("Freecam", false)
                    return
                end
                if not isInitialLoad then
                    window:Notify("Freecam enabled", 2)
                end
            else
                stopFreecam()
                if not isInitialLoad then
                    window:Notify("Freecam disabled", 2)
                end
            end
        end,
    })

    local function updateMiscPosition()
    end

    local function relayoutFloatingUi()
        layoutSearchBar()
        layoutShell()
        if changelogFrame and changelogFrame.Visible then
            local _, _, sw, sh = getSafeBounds()
            local clW = math.min(shell.AbsoluteSize.X, sw - 16)
            local clH = math.min(math.floor(sh * 0.88 + 0.5), sh - 16)
            changelogFrame.Size = UDim2.fromOffset(clW, clH)
        end
        if selectorSheet and selectorSheet.Visible then
            layoutSelectorSheet()
        end
        clampLauncher()
        layoutHintAndMobileOpen()
        if freecamMobileHud then
            local hudW = freecamMobileHud:GetAttribute("HudW") or 168
            local hudH = freecamMobileHud:GetAttribute("HudH") or 120
            local _, _, sw, sh = getSafeBounds()
            local hx = math.clamp(8, 0, math.max(0, sw - hudW))
            local hy = math.clamp(sh - hudH - 8, 0, math.max(0, sh - hudH))
            freecamMobileHud.Position = UDim2.fromOffset(hx, hy)
            freecamMobileHud.ZIndex = Z_FREECAM
        end
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayoutFloatingUi)
    task.defer(function()
        clampToggleBtn()
        layoutHintAndMobileOpen()
        relayoutFloatingUi()
    end)
    
    task.defer(function()
        if SavedSettings.antiafkEnabled then
            startAntiAfk()
        end
    end)
    
    -- Apply saved ArrayList position
    if SavedSettings.arrayListPosition then
        window:SetArrayListPosition(SavedSettings.arrayListPosition)
    end
    
    --=========================================================================
    -- MENU ENTRANCE ANIMATION (after splash)
    --=========================================================================
    if showSplash then
        -- COMPLETELY hide menu until splash finishes
        panelContainer.Visible = false
        if searchBarFrame then searchBarFrame.Visible = false end
        if panelNavFrame then panelNavFrame.Visible = false end
        
        -- Show menu AFTER splash disappears
        task.defer(function()
            local n = 0
            while not menuReadyToShow and n < 40 do
                task.wait(0.05)
                n = n + 1
            end
            panelContainer.Visible = true
            shell.Visible = true
            if searchBarFrame and showSearchBar then searchBarFrame.Visible = true end
            layoutShell()
        end)
    end
    
    -- Welcome notification (after splash)
    task.defer(function()
        task.wait(showSplash and 0.7 or 0)
        local saveStatus = canSaveFiles() and "Settings will be saved" or "Settings won't save (no file access)"
        window:Notify("UI loaded - " .. saveStatus, 4)
    end)

    local keyNavConn = UIS.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        local k = input.KeyCode
        local boxFocused = false
        pcall(function()
            boxFocused = UIS:GetFocusedTextBox() ~= nil
        end)
        if openDropdownNav and not boxFocused then
            if k == Enum.KeyCode.Up then
                openDropdownNav.move(-1)
                return
            elseif k == Enum.KeyCode.Down then
                openDropdownNav.move(1)
                return
            elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter or k == Enum.KeyCode.Space then
                openDropdownNav.activate()
                return
            end
        end
        if k ~= Enum.KeyCode.Escape and k ~= Enum.KeyCode.ButtonB then
            return
        end
        if tooltip.Visible then
            hideTooltip()
            return
        end
        if keybindCancel then
            keybindCancel()
            return
        end
        if selectorSheet and selectorSheet.Visible then
            closeSelectorSheet()
            return
        end
        if searchResults and searchResults.Visible then
            if closeSearchResultsFn then
                closeSearchResultsFn()
            end
            if searchInput then
                searchInput:ReleaseFocus()
            end
            return
        end
        if searchInput and searchInput:IsFocused() then
            searchInput:ReleaseFocus()
            return
        end
        if drawerOpen then
            setDrawerOpen(false)
            layoutShell()
            return
        end
        if changelogFrame and changelogFrame.Visible then
            window:HideChangelog()
            return
        end
        if openDropdownCloser then
            openDropdownCloser()
            return
        end
        if uiVisible or pinnedMode then
            setUIVisible(false)
            return
        end
        if openNestedCloser then
            openNestedCloser()
        end
    end)
    table.insert(window._connections, keyNavConn)

    builtinsComplete = true
    layoutShell()
    return window
end

--=============================================================================
-- RETURN MODULE
--=============================================================================
return UILib
