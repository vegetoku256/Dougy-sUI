-- GitHub allowlist shim. Real mobile UI is fetched from the Dougys API.
local url = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local function good(src)
    return type(src) == "string" and #src > 50
end

local rawReq = (syn and syn.request) or (http and http.request) or http_request or request

local function fetch(u)
    if type(rawReq) ~= "function" then
        error("DougysUI_Mobile: no request()")
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
src = "do local c=math.clamp function math.clamp(x,a,b) if type(a)=='number' and type(b)=='number' and a>b then a,b=b,a end return c(x,a,b) end end\n" .. src
src = string.gsub(src, "math.max%(1, vp%.X %- inset%.X%)", "math.max(160, vp.X - inset.X)", 1)
src = string.gsub(src, "math.max%(1, vp%.Y %- inset%.Y%)", "math.max(160, vp.Y - inset.Y)", 1)
local fn, err = loadstring(src, "DougysUI_Mobile")
if not fn then
    error("DougysUI_Mobile: compile failed: " .. tostring(err))
end
return fn()
