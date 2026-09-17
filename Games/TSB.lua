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

local rawReq = (syn and syn.request) or (http and http.request) or http_request or request
local wrap = newcclosure or function(fn)
    return fn
end

local uiSrc
local mobile

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
    local g = Instance.new("ScreenGui")
    g.Name = "DougysUiKind"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 2147483647
    g.Parent = parent
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
    statusLbl.Parent = g
end)

local function patchUi(src)
    if not mobile or not good(src) then
        return src
    end
    src = "do local c=math.clamp function math.clamp(x,a,b) if type(a)=='number' and type(b)=='number' and a>b then a,b=b,a end return c(x,a,b) end end\n" .. src
    src = string.gsub(src, "math.max%(1, vp%.X %- inset%.X%)", "math.max(160, vp.X - inset.X)", 1)
    src = string.gsub(src, "math.max%(1, vp%.Y %- inset%.Y%)", "math.max(160, vp.Y - inset.Y)", 1)
    local hide = "if showSplash then\n        shell.Visible = false\n    end"
    local a, b = string.find(src, hide, 1, true)
    if a then
        src = string.sub(src, 1, a - 1) .. string.sub(src, b + 1)
    end
    local needle = "return __lr_lib"
    local last
    local pos = 1
    while true do
        local s = string.find(src, needle, pos, true)
        if not s then
            break
        end
        last = s
        pos = s + 1
    end
    if last then
        src = string.sub(src, 1, last - 1) .. [[
do
  local lib = __lr_lib
  if type(lib) == "table" and type(lib.CreateWindow) == "function" then
    local orig = lib.CreateWindow
    lib.CreateWindow = function(self, cfg)
      local st = getgenv and getgenv()._DUI_STATUS
      if st then st("CreateWindow") end
      local ok, win = pcall(orig, self, cfg)
      if not ok then
        if st then st("CW ERR: " .. tostring(win)) end
        error(win)
      end
      if st then st("CW OK") end
      return win
    end
  end
end
return __lr_lib]] .. string.sub(src, last + #needle)
    end
    return src
end

status("fetch UI")
uiSrc = patchUi(fetch(mobile and UI_MOBILE or UI_PC))
status("UI " .. tostring(#uiSrc) .. "b")

local function hookedReq(opts, ...)
    local u
    if type(opts) == "table" then
        u = opts.Url or opts.url
    elseif type(opts) == "string" then
        u = opts
    end
    if isUiUrl(u) then
        return {
            StatusCode = 200,
            status_code = 200,
            Body = uiSrc,
            body = uiSrc,
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
    if getgenv then
        getgenv().request = reqHook
        getgenv().http_request = reqHook
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

status("fetch loader")
local loaderSrc = fetch(LOADER)
local api = loaderSrc:match('API%s*=%s*"([^"]+)"') or "https://api.dougys.duckdns.org"
local eid = loaderSrc:match('EXCHANGE%s*=%s*"([^"]+)"')
local ch = loaderSrc:match('CHALLENGE%s*=%s*"([^"]+)"')
if not eid or not ch then
    status("run loader")
    return run(loaderSrc)
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
status("payload done")
return result
