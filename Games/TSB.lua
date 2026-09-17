-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"
local UI_PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local UI_MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"

local env = (getgenv and getgenv()) or _G

local function good(src)
	return type(src) == "string" and #src > 50
end

local function isDeny(src)
	return type(src) == "string" and string.find(src, "-- luarmor deny", 1, true) ~= nil
end

local function isUiUrl(u)
	if type(u) ~= "string" then
		return false
	end
	local s = string.lower(u)
	return string.find(s, "dougysui", 1, true) or string.find(s, "/ui/", 1, true)
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

local hostGui
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
		parent = lp and lp:FindFirstChild("PlayerGui")
	end
	if not parent then
		return
	end
	hostGui = Instance.new("ScreenGui")
	hostGui.Name = "DougysUiKind"
	hostGui.ResetOnSpawn = false
	hostGui.IgnoreGuiInset = true
	hostGui.DisplayOrder = 1000000
	hostGui.Parent = parent
end)

local forced = env.DOUGYS_UI_MOBILE
local mobile
if forced == true then
	mobile = true
elseif forced == false then
	mobile = false
else
	mobile = isMobileClient()
end
env.DOUGYS_UI_MOBILE = mobile
env._DUI_HOST = hostGui

-- ponytail: keep the first real request(); later env.request is a Lua wrapper that dies on teleport
if type(env.__DUI_RAW_REQ) ~= "function" then
	local found
	pcall(function()
		if syn then
			found = syn.request
		end
	end)
	pcall(function()
		if type(found) ~= "function" and http then
			found = http.request
		end
	end)
	pcall(function()
		if type(found) ~= "function" then
			found = http_request
		end
	end)
	pcall(function()
		if type(found) ~= "function" then
			found = request
		end
	end)
	env.__DUI_RAW_REQ = found
end
local rawReq = env.__DUI_RAW_REQ
if type(rawReq) ~= "function" then
	warn("TSB: close Roblox fully (not just change server), then execute again")
	error("TSB: close Roblox fully (not just change server), then execute again", 0)
end

local uiStub = false
local STUB = "return getgenv()._DUI_LIB"
local depth = 0

local function fetch(u)
	if uiStub and isUiUrl(u) then
		return STUB
	end
	if depth > 2 then
		error("TSB: request loop")
	end
	depth = depth + 1
	local ok, res = pcall(rawReq, {
		Url = u,
		Method = "GET",
		Headers = {
			["User-Agent"] = "Mozilla/5.0",
			["Accept"] = "*/*",
		},
	})
	depth = depth - 1
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

local function prepareUi(src)
	local ws = string.find(src, 'if type(__lr_lib) == "table" then', 1, true)
	if ws then
		src = string.sub(src, 1, ws - 1) .. "\nreturn __lr_lib\n"
	end
	return src
end

local function getUi()
	if uiStub then
		return STUB
	end
	local src = prepareUi(fetch(mobile and UI_MOBILE or UI_PC))
	local fn, err = loadstring(src, "DougysUI")
	src = nil
	if not fn and mobile then
		fn, err = loadstring(prepareUi(fetch(UI_PC)), "DougysUI")
	end
	if not fn then
		error("TSB: UI compile failed: " .. tostring(err))
	end
	local ok, lib = pcall(fn)
	if not ok or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
		error("TSB: UI run failed: " .. tostring(lib))
	end
	env._DUI_LIB = lib
	uiStub = true
	return STUB
end

local function hookedReq(opts, ...)
	local u
	if type(opts) == "table" then
		u = opts.Url or opts.url
	elseif type(opts) == "string" then
		u = opts
	end
	if isUiUrl(u) then
		local body = getUi()
		return {
			StatusCode = 200,
			status_code = 200,
			Body = body,
			body = body,
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

env.__DUI_HOOK = hookedReq
env.__DUI_ON_REQ = hookedReq
if type(env.__DUI_DISPATCH) ~= "function" then
	env.__DUI_DISPATCH = function(opts, ...)
		local fn = env.__DUI_ON_REQ
		if type(fn) == "function" then
			return fn(opts, ...)
		end
		return env.__DUI_RAW_REQ(opts, ...)
	end
end
pcall(function()
	env.request = env.__DUI_DISPATCH
	env.http_request = env.__DUI_DISPATCH
end)

if env.__DUI_GAME ~= game then
	env.__DUI_GAME = game
	pcall(function()
		if hookmetamethod then
			local old
			old = hookmetamethod(game, "__namecall", function(self, ...)
				local method = getnamecallmethod()
				if method == "HttpGet" or method == "HttpGetAsync" then
					local u = ...
					if isUiUrl(u) then
						return getUi()
					end
					if type(u) == "string" and string.find(u, "api.dougys.duckdns.org", 1, true) then
						return fetch(u)
					end
				end
				return old(self, ...)
			end)
		end
	end)
end

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
	if isDeny(loaderSrc) then
		return run(loaderSrc)
	end
	getUi()
	return run(loaderSrc)
end

local key = env.script_key or _G.script_key or ""
if key == "" then
	error("missing script_key", 0)
end
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local payload = fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid)
if mobile then
	payload = "getgenv().DOUGYS_UI_MOBILE=true\n" .. payload
	payload = string.gsub(payload, "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4%-xM", "Q6QhyofwluRSohJgezfv44vU4O4lN-aV")
	payload = string.gsub(payload, "DougysUI%.lua", "DougysUI_Mobile.lua")
end
if not isDeny(payload) then
	getUi()
end
return run(payload)
