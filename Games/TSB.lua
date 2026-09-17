-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"

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
    local okPlat, plat = pcall(function()
        return uis:GetPlatform()
    end)
    if okPlat and (plat == Enum.Platform.IOS or plat == Enum.Platform.Android) then
        return true
    end
    local okPref, pref = pcall(function()
        return uis.PreferredInput
    end)
    if okPref and pref == Enum.PreferredInput.Touch then
        return true
    end
    if uis.TouchEnabled and not uis.KeyboardEnabled then
        return true
    end
    if uis.TouchEnabled and not uis.MouseEnabled then
        return true
    end
    local cam = workspace.CurrentCamera
    if cam then
        local vs = cam.ViewportSize
        if math.min(vs.X, vs.Y) <= 500 then
            return true
        end
    end
    return false
end

local mobile = isMobileClient()

local function rewriteUiUrl(u)
    if not mobile or type(u) ~= "string" then
        return u
    end
    if string.find(u, "DougysUI_Mobile", 1, true) then
        return u
    end
    u = string.gsub(u, "DougysUI%.lua", "DougysUI_Mobile.lua")
    u = string.gsub(u, "Q6QhyofwluRSohJgezfv44vU4O4lN%-aV", "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM")
    return u
end

pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    local wrap = newcclosure or function(fn)
        return fn
    end
    mt.__namecall = wrap(function(self, ...)
        local method = getnamecallmethod()
        if method == "HttpGet" or method == "HttpGetAsync" then
            local args = { ... }
            local u = args[1]
            if type(u) == "string" then
                u = rewriteUiUrl(u)
                args[1] = u
                if string.find(u, "api.dougys.duckdns.org", 1, true) then
                    return fetch(u)
                end
                return old(self, unpack(args))
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
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
    payload = string.gsub(payload, "UserInputService%.TouchEnabled and UI_MOBILE or UI_PC", "true and UI_MOBILE or UI_PC")
end
return run(payload)
