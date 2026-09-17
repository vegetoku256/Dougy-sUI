-- GitHub allowlist shim. Real mobile UI is fetched from the Dougys API.
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
        error("DougysUI_Mobile: failed to fetch API: " .. tostring(src))
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
    error("DougysUI_Mobile: failed to fetch API: " .. tostring(code or src))
end

local src = fetch(url)
src = "do local c=math.clamp function math.clamp(x,a,b) if type(a)=='number' and type(b)=='number' and a>b then a,b=b,a end return c(x,a,b) end end\n" .. src
src = string.gsub(src, "math.max%(1, vp%.X %- inset%.X%)", "math.max(160, vp.X - inset.X)")
src = string.gsub(src, "math.max%(1, vp%.Y %- inset%.Y%)", "math.max(160, vp.Y - inset.Y)")
src = string.gsub(src, "if showSplash then\n        shell.Visible = false\n    end", "")
src = string.gsub(
    src,
    "local vp = gui.AbsoluteSize\n        local inset = getGuiInset()",
    "local vp = gui.AbsoluteSize\n        if vp.X < 32 or vp.Y < 32 then local cam = workspace.CurrentCamera if cam and cam.ViewportSize.X >= 32 then vp = cam.ViewportSize end end\n        if vp.X < 32 or vp.Y < 32 then vp = Vector2.new(390, 844) end\n        local inset = getGuiInset()",
    1
)
local fn, err = loadstring(src, "DougysUI_Mobile")
if not fn then
    error("DougysUI_Mobile: compile failed: " .. tostring(err))
end
return fn()
