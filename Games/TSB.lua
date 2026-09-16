-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"

local function run(src)
    local fn, err = loadstring(src, "TSB")
    if not fn then
        error("TSB: compile failed: " .. tostring(err))
    end
    return fn()
end

local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if ok and type(src) == "string" and #src > 50 then
    return run(src)
end

local req = (syn and syn.request) or (http and http.request) or http_request or request
if type(req) ~= "function" then
    error("TSB: failed to fetch API: " .. tostring(src))
end

local res = req({
    Url = url,
    Method = "GET",
    Headers = {
        ["User-Agent"] = "Mozilla/5.0",
        ["Accept"] = "*/*",
    },
})
local body = type(res) == "table" and (res.Body or res.body) or nil
local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
if type(body) ~= "string" or #body < 50 or (code and code ~= 200) then
    error("TSB: failed to fetch API: " .. tostring(code or src))
end
return run(body)
