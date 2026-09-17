-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"
local UI_PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local UI_MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local function good(src)
    return type(src) == "string" and #src > 50
end

local function isUiUrl(u)
    if type(u) ~= "string" then
        return false
    end
    local s = string.lower(u)
    return string.find(s, "dougysui", 1, true) or string.find(s, "/ui/", 1, true)
end

local function isRobloxGui(name)
    local n = string.lower(tostring(name))
    return string.find(n, "roblox", 1, true)
        or string.find(n, "chat", 1, true)
        or string.find(n, "playerlist", 1, true)
        or string.find(n, "topbar", 1, true)
        or string.find(n, "bubble", 1, true)
        or string.find(n, "purchase", 1, true)
        or name == "DougysUiKind"
end

local rawReq = (syn and syn.request) or (http and http.request) or http_request or request
local wrap = newcclosure or function(fn)
    return fn
end

local uiSrc
local mobile
local hostGui

local statusLbl
local function status(msg)
    pcall(function()
        if statusLbl then
            statusLbl.Text = (mobile and "MOBILE | " or "PC | ") .. tostring(msg)
        end
    end)
end
if getgenv then
    getgenv()._DUI_STATUS = status
end

local function fetch(u)
    if uiSrc and isUiUrl(u) then
        return uiSrc
    end
    if type(rawReq) ~= "function" then
        error("TSB: no request()")
    end
    local ok, res = pcall(rawReq, {
        Url = u,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"] = "*/*",
        },
    })
    if not ok then
        error("TSB: request failed: " .. tostring(res))
    end
    local body = type(res) == "table" and (res.Body or res.body) or (type(res) == "string" and res or nil)
    local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
    if good(body) and (not code or code == 200) then
        return body
    end
    error("TSB: failed to fetch API: " .. tostring(code or "blocked"))
end

local function getUi()
    if good(uiSrc) then
        return uiSrc
    end
    status("fetch UI")
    uiSrc = fetch(mobile and UI_MOBILE or UI_PC)
    status("UI " .. tostring(#uiSrc) .. "b")
    return uiSrc
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
mobile = (forced == true) or (forced ~= false and isMobileClient())
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
    hostGui = Instance.new("ScreenGui")
    hostGui.Name = "DougysUiKind"
    hostGui.ResetOnSpawn = false
    hostGui.IgnoreGuiInset = true
    hostGui.DisplayOrder = 2147483647
    hostGui.Parent = parent
    if getgenv then
        getgenv()._DUI_HOST = hostGui
    end
    statusLbl = Instance.new("TextLabel")
    statusLbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    statusLbl.BackgroundTransparency = 0.1
    statusLbl.BorderSizePixel = 0
    statusLbl.Font = Enum.Font.SourceSansBold
    statusLbl.TextSize = 18
    statusLbl.TextColor3 = Color3.fromRGB(255, 220, 80)
    statusLbl.TextWrapped = true
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Text = mobile and "MOBILE | start" or "PC | start"
    statusLbl.Size = UDim2.new(1, 0, 0, 72)
    statusLbl.Position = UDim2.fromOffset(0, 0)
    statusLbl.ZIndex = 10000
    statusLbl.Parent = hostGui
end)

local function hookedReq(opts, ...)
    local u
    if type(opts) == "table" then
        u = opts.Url or opts.url
    elseif type(opts) == "string" then
        u = opts
    end
    if isUiUrl(u) then
        local body = getUi()
        return {
            StatusCode = 200,
            status_code = 200,
            Body = body,
            body = body,
            Success = true,
            success = true,
        }
    end
    if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
        local body = fetch(u)
        return {
            StatusCode = 200,
            status_code = 200,
            Body = body,
            body = body,
            Success = true,
            success = true,
        }
    end
    return rawReq(opts, ...)
end
local reqHook = wrap(hookedReq)

pcall(function()
    if hookfunction and type(request) == "function" then
        hookfunction(request, reqHook)
    end
end)
pcall(function()
    if hookfunction and type(http_request) == "function" then
        hookfunction(http_request, reqHook)
    end
end)
pcall(function()
    if hookfunction and syn and type(syn.request) == "function" then
        hookfunction(syn.request, reqHook)
    end
end)
pcall(function()
    if hookfunction and http and type(http.request) == "function" then
        hookfunction(http.request, reqHook)
    end
end)
pcall(function()
    if getgenv then
        getgenv().request = reqHook
        getgenv().http_request = reqHook
        if http then
            http.request = reqHook
        end
    end
end)

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
                return getUi()
            end
            if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
                return fetch(u)
            end
        end
        return old(self, ...)
    end))
end)

pcall(function()
    if not hookfunction then
        return
    end
    local oldHttp
    oldHttp = hookfunction(game.HttpGet, wrap(function(self, u, ...)
        if isUiUrl(u) then
            return getUi()
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
        status("compile: " .. tostring(err))
        error("TSB: compile failed: " .. tostring(err))
    end
    local ok, res = pcall(fn)
    if not ok then
        status("run: " .. tostring(res))
        error(res)
    end
    return res
end

local function adoptFrom(parent)
    if not hostGui or not parent then
        return 0
    end
    local n = 0
    local kids = parent:GetChildren()
    for i = 1, #kids do
        local child = kids[i]
        if child:IsA("ScreenGui") and child ~= hostGui and not isRobloxGui(child.Name) then
            local sub = child:GetChildren()
            for j = 1, #sub do
                pcall(function()
                    sub[j].Parent = hostGui
                end)
                n = n + 1
            end
            pcall(function()
                child:Destroy()
            end)
        end
    end
    return n
end

local function adoptUi()
    local n = 0
    pcall(function()
        if gethui then
            n = n + adoptFrom(gethui())
        end
    end)
    pcall(function()
        n = n + adoptFrom(hostGui.Parent)
    end)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        n = n + adoptFrom(lp and lp:FindFirstChild("PlayerGui"))
    end)
    pcall(function()
        local kids = game:GetService("CoreGui"):GetChildren()
        for i = 1, #kids do
            local child = kids[i]
            if child:IsA("ScreenGui") and child ~= hostGui and not isRobloxGui(child.Name) then
                local order = 0
                pcall(function()
                    order = child.DisplayOrder
                end)
                if order >= 500000 then
                    local sub = child:GetChildren()
                    for j = 1, #sub do
                        pcall(function()
                            sub[j].Parent = hostGui
                        end)
                        n = n + 1
                    end
                    pcall(function()
                        child:Destroy()
                    end)
                end
            end
        end
    end)
    pcall(function()
        if statusLbl then
            statusLbl.ZIndex = 10000
        end
    end)
    return n
end

status("fetch loader")
local loaderSrc = fetch(LOADER)
local api = loaderSrc:match('API%s*=%s*"([^"]+)"') or "https://api.dougys.duckdns.org"
local eid = loaderSrc:match('EXCHANGE%s*=%s*"([^"]+)"')
local ch = loaderSrc:match('CHALLENGE%s*=%s*"([^"]+)"')
if not eid or not ch then
    status("run loader")
    local result = run(loaderSrc)
    status("adopted " .. tostring(adoptUi()))
    return result
end

local key = (getgenv and getgenv().script_key) or _G.script_key or ""
if key == "" then
    status("missing script_key")
    error("missing script_key", 0)
end
status("exchange")
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local payload = fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid)
if mobile then
    payload = "getgenv().DOUGYS_UI_MOBILE=true\n" .. payload
    payload = string.gsub(payload, "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4%-xM", "Q6QhyofwluRSohJgezfv44vU4O4lN-aV")
    payload = string.gsub(payload, "DougysUI%.lua", "DougysUI_Mobile.lua")
end
status("run payload " .. tostring(#payload) .. "b")
local result = run(payload)
status("adopted " .. tostring(adoptUi()))
return result
