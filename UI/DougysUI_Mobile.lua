-- GitHub allowlist shim. Real mobile UI is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local function good(src)
    return type(src) == "string" and #src > 50
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
    error("DougysUI_Mobile: no request()")
end

local function fetch(u)
    local okGet, src = pcall(function()
        return game:HttpGet(u)
    end)
    if okGet and good(src) then
        return src
    end
    local ok, res = pcall(rawReq, {
        Url = u,
        Method = "GET",
    })
    if not ok then
        error("DougysUI_Mobile: request failed: " .. tostring(res))
    end
    local body = type(res) == "table" and (res.Body or res.body) or (type(res) == "string" and res or nil)
    local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
    if good(body) and (not code or code == 200) then
        return body
    end
    error("DougysUI_Mobile: failed to fetch API: " .. tostring(code or "blocked"))
end

local src = fetch(url)
local fn, err = loadstring(src, "DougysUI_Mobile")
if not fn then
    error("DougysUI_Mobile: compile failed: " .. tostring(err))
end
return fn()
