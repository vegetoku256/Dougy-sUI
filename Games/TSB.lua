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
            local u = ...
            if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
                return fetch(u)
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
return run(fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid))
