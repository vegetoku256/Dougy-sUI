-- GitHub allowlist shim. TSB loads this file for UI; pick mobile vs PC here.
local PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local function good(src)
    return type(src) == "string" and #src > 50
end

local function fetch(u)
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
    if type(rawReq) == "function" then
        local ok, res = pcall(rawReq, {
            Url = u,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0",
                ["Accept"] = "*/*",
            },
        })
        if ok then
            local body = type(res) == "table" and (res.Body or res.body) or (type(res) == "string" and res or nil)
            local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
            if good(body) and (not code or code == 200) then
                return body
            end
        end
    end
    local ok, src = pcall(function()
        return game:HttpGet(u)
    end)
    if ok and good(src) then
        return src
    end
    error("DougysUI: failed to fetch API")
end

local function isMobileClient()
    local uis = game:GetService("UserInputService")
    local exec = ""
    pcall(function()
        if identifyexecutor then
            exec = string.lower(tostring(identifyexecutor()))
        end
    end)
    pcall(function()
        if getexecutorname then
            exec = exec .. " " .. string.lower(tostring(getexecutorname()))
        end
    end)
    if string.find(exec, "delta", 1, true)
        or string.find(exec, "hydrogen", 1, true)
        or string.find(exec, "codex", 1, true)
        or string.find(exec, "arceus", 1, true)
        or string.find(exec, "trigon", 1, true)
        or string.find(exec, "vegax", 1, true)
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
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize
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
local mobile
if forced == true then
    mobile = true
elseif forced == false then
    mobile = false
else
    mobile = isMobileClient()
end

if getgenv then
    getgenv().DOUGYS_UI_MOBILE = mobile
end

local src = fetch(mobile and MOBILE or PC)
local fn, err = loadstring(src, mobile and "DougysUI_Mobile" or "DougysUI")
if not fn then
    error("DougysUI: compile failed: " .. tostring(err))
end
return fn()
