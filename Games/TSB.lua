-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"
local UI_PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local UI_MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local hostGui
local statusLbl
local function status(msg)
    pcall(function()
        if statusLbl then
            statusLbl.Text = tostring(msg)
        end
    end)
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
    hostGui = Instance.new("ScreenGui")
    hostGui.Name = "DougysUiKind"
    hostGui.ResetOnSpawn = false
    hostGui.IgnoreGuiInset = true
    hostGui.DisplayOrder = 1000000
    hostGui.Parent = parent
    statusLbl = Instance.new("TextLabel")
    statusLbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    statusLbl.BackgroundTransparency = 0.1
    statusLbl.BorderSizePixel = 0
    statusLbl.Font = Enum.Font.SourceSansBold
    statusLbl.TextSize = 18
    statusLbl.TextColor3 = Color3.fromRGB(255, 220, 80)
    statusLbl.TextWrapped = true
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Text = "MOBILE | bar"
    statusLbl.Size = UDim2.new(1, 0, 0, 72)
    statusLbl.Position = UDim2.fromOffset(0, 0)
    statusLbl.ZIndex = 10000
    statusLbl.Parent = hostGui
end)

local waitFn = (task and task.wait) or wait
pcall(waitFn, 0.3)

local mobile = true
pcall(function()
    local forced = getgenv() and getgenv().DOUGYS_UI_MOBILE
    if forced == false then
        mobile = false
    end
end)
if getgenv then
    getgenv().DOUGYS_UI_MOBILE = mobile
    getgenv()._DUI_HOST = hostGui
    getgenv()._DUI_STATUS = status
end
status((mobile and "MOBILE | after wait") or "PC | after wait")

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

local rawReq
pcall(function()
    if syn then
        rawReq = syn.request
    end
end)
pcall(function()
    if not rawReq and http then
        rawReq = http.request
    end
end)
pcall(function()
    if not rawReq then
        rawReq = http_request
    end
end)
pcall(function()
    if not rawReq then
        rawReq = request
    end
end)
if type(rawReq) ~= "function" then
    status("MOBILE | no request()")
    error("TSB: no request()")
end

local uiStub = false
local STUB = "return getgenv()._DUI_LIB"

local function fetch(u)
    if uiStub and isUiUrl(u) then
        return STUB
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

local function revealOurs(parent, moveIfNested)
    if not parent then
        return 0
    end
    local n = 0
    local kids = parent:GetChildren()
    for i = 1, #kids do
        local child = kids[i]
        if child:IsA("ScreenGui") and child ~= hostGui then
            local order = 0
            pcall(function()
                order = child.DisplayOrder
            end)
            if order >= 500000 then
                pcall(function()
                    child.Enabled = true
                    child.IgnoreGuiInset = true
                    child.DisplayOrder = 999999
                end)
                if moveIfNested and parent:IsA("ScreenGui") then
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
                else
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function adoptUi()
    local n = 0
    pcall(function()
        if gethui then
            local h = gethui()
            n = n + revealOurs(h, h and h:IsA("ScreenGui"))
        end
    end)
    pcall(function()
        n = n + revealOurs(game:GetService("CoreGui"), false)
    end)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        n = n + revealOurs(lp and lp:FindFirstChild("PlayerGui"), false)
    end)
    return n
end

local function getUi()
    if uiStub then
        return STUB
    end
    status("MOBILE | fetch UI")
    local src = fetch(mobile and UI_MOBILE or UI_PC)
    status((mobile and "MOBILE | UI " or "PC | UI ") .. tostring(#src) .. "b")
    local ws = string.find(src, 'if type(__lr_lib) == "table" then', 1, true)
    if ws then
        src = string.sub(src, 1, ws - 1) .. "\nreturn __lr_lib\n"
        status("MOBILE | stripped wrap")
    end
    local splitAt = "    return applyBackgroundMode, stopWeather, refreshWeatherIfActive, startAntiAfk, stopAntiAfk, getOpenOverlayTransparency, getOpenOverlayColor, destroyWeatherPools\n    end)()"
    local sa, sb = string.find(src, splitAt, 1, true)
    if sa then
        src = string.sub(src, 1, sb) .. "\n    return (function()\n" .. string.sub(src, sb + 1)
        local closeAt = "    builtinsComplete = true\n    layoutShell()\n    return window\nend"
        local ca, cb = string.find(src, closeAt, 1, true)
        if not ca then
            closeAt = "    builtinsComplete = true\n    pcall(layoutShell)\n    return window\nend"
            ca, cb = string.find(src, closeAt, 1, true)
        end
        if ca then
            src = string.sub(src, 1, ca - 1) .. "    builtinsComplete = true\n    pcall(layoutShell)\n    return window\n    end)()\nend" .. string.sub(src, cb + 1)
            status("MOBILE | split CreateWindow")
        end
    end
    status("MOBILE | compiling UI")
    local fn, err = loadstring(src, "DougysUI")
    src = nil
    if not fn then
        status("MOBILE | UI compile fail, trying PC")
        local pcsrc = fetch(UI_PC)
        local pws = string.find(pcsrc, 'if type(__lr_lib) == "table" then', 1, true)
        if pws then
            pcsrc = string.sub(pcsrc, 1, pws - 1) .. "\nreturn __lr_lib\n"
        end
        fn, err = loadstring(pcsrc, "DougysUI")
        pcsrc = nil
        if not fn then
            status("MOBILE | UI compile: " .. tostring(err))
            error(err)
        end
        status("MOBILE | using PC UI")
    end
    status("MOBILE | UI lib")
    local ok, lib = pcall(fn)
    if not ok or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        status("MOBILE | UI run: " .. tostring(lib))
        error(lib)
    end
    local orig = lib.CreateWindow
    lib.CreateWindow = function(self, cfg)
        status("MOBILE | CreateWindow")
        pcall(function()
            local m = Instance.new("Frame")
            m.Size = UDim2.fromOffset(72, 72)
            m.Position = UDim2.fromOffset(8, 80)
            m.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
            m.BorderSizePixel = 0
            m.ZIndex = 9999
            m.Parent = hostGui
        end)
        local okw, win = pcall(orig, self, cfg)
        if not okw then
            status("MOBILE | CW ERR: " .. tostring(win))
            error(win)
        end
        local n = 0
        pcall(function()
            n = adoptUi()
        end)
        status("MOBILE | CW OK adopted " .. tostring(n))
        return win
    end
    if getgenv then
        getgenv()._DUI_LIB = lib
    end
    uiStub = true
    return STUB
end

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

status("MOBILE | hooks")
pcall(function()
    if getgenv then
        getgenv().request = hookedReq
        getgenv().http_request = hookedReq
    end
end)
pcall(function()
    if hookmetamethod then
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
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
        end)
    end
end)

local function run(src)
    local fn, err = loadstring(src, "TSB")
    if not fn then
        status("MOBILE | compile: " .. tostring(err))
        error("TSB: compile failed: " .. tostring(err))
    end
    local ok, res = pcall(fn)
    if not ok then
        status("MOBILE | run: " .. tostring(res))
        error(res)
    end
    return res
end

status("MOBILE | fetch loader")
local loaderSrc = fetch(LOADER)
local api = loaderSrc:match('API%s*=%s*"([^"]+)"') or "https://api.dougys.duckdns.org"
local eid = loaderSrc:match('EXCHANGE%s*=%s*"([^"]+)"')
local ch = loaderSrc:match('CHALLENGE%s*=%s*"([^"]+)"')
if not eid or not ch then
    status("MOBILE | run loader")
    getUi()
    local result = run(loaderSrc)
    status("MOBILE | done adopted " .. tostring(adoptUi()))
    return result
end

local key = (getgenv and getgenv().script_key) or _G.script_key or ""
if key == "" then
    status("MOBILE | missing script_key")
    error("missing script_key", 0)
end
status("MOBILE | exchange")
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local payload = fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid)
if mobile then
    payload = "getgenv().DOUGYS_UI_MOBILE=true\n" .. payload
    payload = string.gsub(payload, "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4%-xM", "Q6QhyofwluRSohJgezfv44vU4O4lN-aV")
    payload = string.gsub(payload, "DougysUI%.lua", "DougysUI_Mobile.lua")
end
status("MOBILE | preload UI")
getUi()
status("MOBILE | TSB")
local result = run(payload)
status("MOBILE | done adopted " .. tostring(adoptUi()))
return result
