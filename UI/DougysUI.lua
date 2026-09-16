-- GitHub allowlist shim. Real desktop UI is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

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

local src = fetch(url)
local fn, err = loadstring(src, "DougysUI")
if not fn then
    error("DougysUI: compile failed: " .. tostring(err))
end
return fn()
