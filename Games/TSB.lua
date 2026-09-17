-- GitHub allowlist shim. Real TSB loader is fetched from the Dougys API.
-- No HttpGet/request hooks: those survive a server hop and block the next execute.
local LOADER = "https://api.dougys.duckdns.org/loader/JzS9pLWIVJHcRHGNwg_xp3bXTjnfFFN2"
local UI_PC = "https://api.dougys.duckdns.org/ui/hXF-UCRNy1-NR8RFvcc6wCaN52Sx4-xM"
local UI_MOBILE = "https://api.dougys.duckdns.org/ui/Q6QhyofwluRSohJgezfv44vU4O4lN-aV"
local GITHUB = "https://raw.githubusercontent.com/vegetoku256/Dougy-sUI/main/Games/TSB.lua"

pcall(function()
	rconsoleprint("[Dougys] start\n")
end)

local env = (getgenv and getgenv()) or _G
env.__DUI_ON_HTTPGET = nil
env.__DUI_ON_REQ = nil
pcall(function()
	if restorefunction then
		pcall(restorefunction, Instance.new)
	end
	if hookfunction then
		hookfunction(game.IsLoaded, function()
			return true
		end)
	end
end)

local function fail(msg)
	pcall(function()
		rconsoleprint("[Dougys] " .. tostring(msg) .. "\n")
	end)
	warn("[Dougys] " .. tostring(msg))
	error(tostring(msg))
end

local function good(src)
	return type(src) == "string" and #src > 50
end

local function isDeny(src)
	return type(src) == "string" and string.find(src, "-- luarmor deny", 1, true) ~= nil
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
	local lp = game:GetService("Players").LocalPlayer
	parent = lp and (lp:FindFirstChildWhichIsA("PlayerGui") or lp:FindFirstChild("PlayerGui"))
	if not parent then
		pcall(function()
			parent = game:GetService("CoreGui")
		end)
	end
	if not parent then
		pcall(function()
			if gethui then
				parent = gethui()
			end
		end)
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
if env.__DUI_JOB ~= tostring(game.JobId) then
	env._DUI_LIB = nil
	env.__DougysTSB_10449761463 = nil
	env.__DUI_JOB = tostring(game.JobId)
end
pcall(function()
	env.gethui = function()
		return hostGui
	end
end)

local function nativeReq()
	local fn
	pcall(function()
		if syn then
			fn = syn.request
		end
	end)
	pcall(function()
		if type(fn) ~= "function" and http then
			fn = http.request
		end
	end)
	pcall(function()
		if type(fn) ~= "function" then
			fn = http_request
		end
	end)
	pcall(function()
		if type(fn) ~= "function" then
			fn = request
		end
	end)
	return fn
end

local function fetch(u)
	local fn = nativeReq()
	if type(fn) ~= "function" then
		fail("no request()")
	end
	local res, done
	local function go()
		local ok, r = pcall(fn, {
			Url = u,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Mozilla/5.0",
				["Accept"] = "*/*",
			},
		})
		if ok then
			res = r
		else
			res = { _err = r }
		end
		done = true
	end
	if task and task.spawn then
		task.spawn(go)
		local i = 0
		while not done and i < 80 do
			task.wait(0.1)
			i = i + 1
		end
		if not done then
			fail("API fetch hung")
		end
	else
		go()
	end
	if type(res) == "table" and res._err then
		fail("request failed: " .. tostring(res._err))
	end
	local body = type(res) == "table" and (res.Body or res.body) or (type(res) == "string" and res or nil)
	local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
	if good(body) and (not code or code == 200) then
		return body
	end
	fail("failed to fetch API: " .. tostring(code or "blocked"))
end

local function prepareUi(src)
	local ws = string.find(src, 'if type(__lr_lib) == "table" then', 1, true)
	if ws then
		src = string.sub(src, 1, ws - 1) .. "\nreturn __lr_lib\n"
	end
	return src
end

local function getUi()
	if type(env._DUI_LIB) == "table" and type(env._DUI_LIB.CreateWindow) == "function" then
		return env._DUI_LIB
	end
	local src = prepareUi(fetch(mobile and UI_MOBILE or UI_PC))
	local fn, err = loadstring(src, "DougysUI")
	src = nil
	if not fn and mobile then
		fn, err = loadstring(prepareUi(fetch(UI_PC)), "DougysUI")
	end
	if not fn then
		fail("UI compile failed: " .. tostring(err))
	end
	local ok, lib = pcall(fn)
	if not ok or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
		fail("UI run failed: " .. tostring(lib))
	end
	env._DUI_LIB = lib
	return lib
end

local function run(src)
	local fn, err = loadstring(src, "TSB")
	if not fn then
		fail("compile failed: " .. tostring(err))
	end
	return fn()
end

pcall(function()
	local qt = queue_on_teleport or queueonteleport or queueteleport
	if type(qt) ~= "function" then
		return
	end
	local key = tostring(env.script_key or "")
	qt(string.format(
		'getgenv().script_key=%q\npcall(function() rconsoleprint("[Dougys] teleport\\n") end)\nlocal q=(syn and syn.request)or(http and http.request)or http_request or request\nlocal r=q({Url="%s?t="..math.random(1,9999999),Method="GET"})\nloadstring((type(r)=="table"and(r.Body or r.body))or r)()',
		key,
		GITHUB
	))
end)

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
	fail("missing script_key")
end
local hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
local payload = fetch(api .. "/api/v1/sessions/exchange?eid=" .. eid .. "&c=" .. ch .. "&k=" .. key .. "&h=" .. hwid)
if mobile then
	payload = "getgenv().DOUGYS_UI_MOBILE=true\n" .. payload
	payload = string.gsub(payload, "hXF-UCRNy1-NR8RFvcc6wCaN52Sx4%-xM", "Q6QhyofwluRSohJgezfv44vU4O4lN-aV")
	payload = string.gsub(payload, "DougysUI%.lua", "DougysUI_Mobile.lua")
end
warn("[Dougys] running")
pcall(function()
	rconsoleprint("[Dougys] running\n")
end)
return run(payload)
