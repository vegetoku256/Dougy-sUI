-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"
local UI_PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local UI_MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local function good(src)
    return type(src) == "string" and #src > 50
end

local inFetch = false
local function fetch(u)
    if not inFetch then
        inFetch = true
        local ok, src = pcall(function()
            return game:HttpGet(u)
        end)
        inFetch = false
        if ok and good(src) then
            return src
        end
    end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) ~= "function" then
        error("TSB: failed to fetch API: blocked")
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
    error("TSB: failed to fetch API: " .. tostring(code or "blocked"))
end

local function isMobileClient()
    local uis = game:GetService("UserInputService")
    local exec = ""
    pcall(function()
        if identifyexecutor then
            exec = string.lower(tostring(identifyexecutor()))
        end
    end)
    if string.find(exec, "delta", 1, true)
        or string.find(exec, "hydrogen", 1, true)
        or string.find(exec, "codex", 1, true)
        or string.find(exec, "arceus", 1, true)
        or string.find(exec, "trigon", 1, true)
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
    local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
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
local mobile = (forced == true) or (forced ~= false and isMobileClient())
if getgenv then
    getgenv().DOUGYS_UI_MOBILE = mobile
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
        parent = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 3))
    end
    if not parent then
        return
    end
    local g = Instance.new("ScreenGui")
    g.Name = "DougysUiKind"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 2147483647
    g.Parent = parent
    local t = Instance.new("TextLabel")
    t.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    t.BackgroundTransparency = 0.15
    t.BorderSizePixel = 0
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = 22
    t.TextColor3 = Color3.fromRGB(255, 220, 80)
    t.Text = mobile and "DougysUI: MOBILE" or "DougysUI: PC"
    t.Size = UDim2.new(1, 0, 0, 44)
    t.Position = UDim2.fromOffset(0, 0)
    t.Parent = g
    local later = (task and task.delay) or function(sec, fn)
        spawn(function()
            wait(sec)
            fn()
        end)
    end
    later(10, function()
        pcall(function()
            g:Destroy()
        end)
    end)
end)

local uiSrc = fetch(mobile and UI_MOBILE or UI_PC)

local function isUiUrl(u)
    if type(u) ~= "string" then
        return false
    end
    local s = string.lower(u)
    if string.find(s, "dougysui", 1, true) then
        return true
    end
    if string.find(s, "/ui/", 1, true) then
        return true
    end
    return false
end

local wrap = newcclosure or function(fn)
    return fn
end

pcall(function()
    if not hookmetamethod then
        return
    end
    local old
    old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        local method = getnamecallmethod()
        if method == "HttpGet" or method == "HttpGetAsync" then
            local u = ...
            if isUiUrl(u) then
                return uiSrc
            end
            if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
                return fetch(u)
            end
        end
        return old(self, ...)
    end))
end)

pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = wrap(function(self, ...)
        local method = getnamecallmethod()
        if method == "HttpGet" or method == "HttpGetAsync" then
            local u = ...
            if isUiUrl(u) then
                return uiSrc
            end
            if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
                return fetch(u)
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

pcall(function()
    if not hookfunction then
        return
    end
    local oldHttp
    oldHttp = hookfunction(game.HttpGet, wrap(function(self, u, ...)
        if isUiUrl(u) then
            return uiSrc
        end
        if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
            return fetch(u)
        end
        return oldHttp(self, u, ...)
    end))
end)

local function run(src)
    local fn, err = loadstring(src, "TSB")
    if not fn then
        error("TSB: compile failed: " .. tostring(err))
    end
    return fn()
end

local loaderSrc = fetch(LOADER)
local api = loaderSrc:match('API%s*=%s*"([^"]+)"') or "https://api.dougys.duckdns.org"
local eid = loaderSrc:match('EXCHANGE%s*=%s*"([^"]+)"')
local ch = loaderSrc:match('CHALLENGE%s*=%s*"([^"]+)"')
if not eid or not ch then
    return run(loaderSrc)
end

local key = (getgenv and getgenv().script_key) or _G.script_key or ""
if key == "" then
    error("missing script_key", 0)
end
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local payload = fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid)
if mobile then
    payload = "getgenv().DOUGYS_UI_MOBILE=true\n" .. payload
    payload = string.gsub(payload, "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4%-xM", "Q6QhyofwluRSohJgezfv44vU4O4lN-aV")
    payload = string.gsub(payload, "DougysUI%.lua", "DougysUI_Mobile.lua")
end
return run(payload)
