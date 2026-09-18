if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local env = (getgenv and getgenv()) or _G
local RUNTIME = "__DougysHubLoader"

local GAMES = {
	[10449761463] = {
		name = "The Strongest Battlegrounds",
		script = "https://raw.githubusercontent.com/vegetoku256/Dougy-sUI/refs/heads/main/Games/TSB.lua",
	},
}

local PROVIDERS = {
	{ name = "Dougy's", url = "https://dougys.duckdns.org/" },
}

local C = {
	bg = Color3.fromRGB(16, 16, 18),
	panel = Color3.fromRGB(28, 26, 22),
	header = Color3.fromRGB(46, 36, 20),
	hover = Color3.fromRGB(54, 46, 30),
	divider = Color3.fromRGB(62, 52, 36),
	stroke = Color3.fromRGB(140, 140, 140),
	text = Color3.fromRGB(242, 242, 242),
	textDim = Color3.fromRGB(186, 186, 186),
	accent = Color3.fromRGB(224, 176, 48),
	ink = Color3.fromRGB(16, 16, 18),
	err = Color3.fromRGB(232, 120, 96),
	shadow = Color3.fromRGB(0, 0, 0),
}

local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local place = GAMES[game.PlaceId]
local compact = false
local selected = 1
local busy = false
local gui, card, statusLbl, keyBox
local providerBtns = {}
local conns = {}

local function track(conn)
	conns[#conns + 1] = conn
	return conn
end

local function disconnectAll()
	for i = 1, #conns do
		pcall(function()
			conns[i]:Disconnect()
		end)
	end
	conns = {}
end

local function hostParent()
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
		local lp = Players.LocalPlayer
		if lp then
			parent = lp:WaitForChild("PlayerGui", 5)
		end
	end
	return parent
end

local function destroyGui()
	disconnectAll()
	busy = false
	local g = gui
	gui, card, statusLbl, keyBox = nil, nil, nil, nil
	providerBtns = {}
	if env[RUNTIME] == destroyGui then
		env[RUNTIME] = nil
	end
	if g then
		pcall(function()
			g:Destroy()
		end)
	end
end

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

local function good(src)
	return type(src) == "string" and #src > 50
end

local function fetch(url)
	local fn = nativeReq()
	if type(fn) == "function" then
		local ok, res = pcall(fn, {
			Url = url,
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
	local ok2, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok2 and good(body) then
		return body
	end
	error("fetch failed", 0)
end

local function applyFocus(obj, order)
	pcall(function()
		obj.Selectable = true
		if obj:IsA("GuiButton") then
			obj.AutoButtonColor = false
		end
		if type(order) == "number" then
			obj.SelectionOrder = order
		end
	end)
	local img = Instance.new("Frame")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 6, 1, 6)
	img.Position = UDim2.fromOffset(-3, -3)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = C.accent
	st.Transparency = 0
	st.Parent = img
	pcall(function()
		obj.SelectionImageObject = img
	end)
end

local function setStatus(text, isErr)
	if not statusLbl then
		return
	end
	statusLbl.Text = text or ""
	statusLbl.TextColor3 = isErr and C.err or C.textDim
end

local function isCompact()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vs.X < 700 or vs.Y < 500 then
		return true
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return UserInputService.TouchEnabled and vs.X < 900
end

local function layoutCard()
	if not card then
		return
	end
	compact = isCompact()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local inset = GuiService:GetGuiInset()
	local pad = compact and 12 or 20
	local width = math.min(compact and 360 or 400, math.max(260, vs.X - pad * 2))
	card.Size = UDim2.fromOffset(width, 0)
	local focused = keyBox and keyBox:IsFocused()
	if compact and focused then
		card.Position = UDim2.new(0.5, 0, 0, inset.Y + 12)
		card.AnchorPoint = Vector2.new(0.5, 0)
	else
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function openUrl(url)
	local opened = false
	pcall(function()
		GuiService:OpenBrowserWindow(url)
		opened = true
	end)
	if not opened then
		pcall(function()
			if setclipboard then
				setclipboard(url)
			end
		end)
		setStatus("Link copied. Paste it in your browser.")
		return
	end
	setStatus("Opened the key page in your browser.")
end

local function paintProviders()
	for i = 1, #providerBtns do
		local row = providerBtns[i]
		local on = i == selected
		row.btn.BackgroundColor3 = on and C.hover or C.bg
		row.mark.BackgroundColor3 = on and C.accent or C.divider
		row.lbl.FontFace = on and FONT_BOLD or FONT
	end
end

local function unlock()
	if busy or not place then
		return
	end
	local key = keyBox and string.gsub(keyBox.Text or "", "^%s*(.-)%s*$", "%1") or ""
	if key == "" then
		setStatus("Paste your key first.", true)
		if keyBox then
			keyBox:CaptureFocus()
		end
		return
	end
	busy = true
	setStatus("Loading the hub...")
	env.script_key = key
	_G.script_key = key
	local url = place.script .. "?t=" .. tostring(os.time())
	local ok, srcOrErr = pcall(fetch, url)
	if not ok then
		busy = false
		setStatus("Could not download the hub. Try again.", true)
		return
	end
	local fn, err = loadstring(srcOrErr, "TSB")
	if not fn then
		busy = false
		setStatus("Could not compile the hub. Check your key and try again.", true)
		warn("[Dougy's] compile: " .. tostring(err))
		return
	end
	local ran, runErr = pcall(fn)
	if not ran then
		busy = false
		setStatus("Could not load the hub. Check your key and try again.", true)
		warn("[Dougy's] hub failed: " .. tostring(runErr))
		return
	end
	destroyGui()
end

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function build()
	local parent = hostParent()
	if not parent then
		warn("[Dougy's] no GUI parent")
		return
	end

	if type(env[RUNTIME]) == "function" then
		pcall(env[RUNTIME])
	elseif typeof(env[RUNTIME]) == "Instance" then
		pcall(function()
			env[RUNTIME]:Destroy()
		end)
		env[RUNTIME] = nil
	end

	gui = mk("ScreenGui", {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Name = "DH" .. tostring(math.random(100000, 999999)),
	}, parent)
	env[RUNTIME] = destroyGui

	mk("Frame", {
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true,
	}, gui)

	local lift = mk("Frame", {
		BackgroundColor3 = C.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 4, 0.5, 6),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 1,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, lift)

	card = mk("Frame", {
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 0),
		ZIndex = 2,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
	mk("UIStroke", { Color = C.divider, Thickness = 1 }, card)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	}, card)

	track(card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		lift.Size = UDim2.fromOffset(card.AbsoluteSize.X, card.AbsoluteSize.Y)
		lift.AnchorPoint = card.AnchorPoint
		local pos = card.Position
		lift.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 4, pos.Y.Scale, pos.Y.Offset + 6)
	end))

	local header = mk("Frame", {
		BackgroundColor3 = C.header,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, compact and 48 or 52),
		LayoutOrder = 1,
	}, card)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, header)
	mk("Frame", {
		BackgroundColor3 = C.header,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 10),
	}, header)

	mk("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_BOLD,
		Text = "Dougy's",
		TextColor3 = C.text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -64, 0, 22),
	}, header)

	mk("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = place and place.name or "This place is not supported",
		TextColor3 = C.textDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -64, 0, 16),
	}, header)

	local closeBtn = mk("TextButton", {
		BackgroundColor3 = C.hover,
		BorderSizePixel = 0,
		FontFace = FONT_BOLD,
		Text = "Close",
		TextColor3 = C.text,
		TextSize = 13,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(64, 44),
	}, header)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
	applyFocus(closeBtn, 9)
	track(closeBtn.Activated:Connect(destroyGui))
	track(closeBtn.MouseEnter:Connect(function()
		closeBtn.BackgroundColor3 = C.divider
	end))
	track(closeBtn.MouseLeave:Connect(function()
		closeBtn.BackgroundColor3 = C.hover
	end))

	local body = mk("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
	}, card)
	mk("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, body)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, body)

	statusLbl = mk("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "",
		TextColor3 = C.textDim,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
	}, body)

	track(UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			destroyGui()
		end
	end))
	local cam = workspace.CurrentCamera
	if cam then
		track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCard))
	end

	if not place then
		setStatus("This place is not supported. Close this panel and run the loader in The Strongest Battlegrounds.")
		layoutCard()
		return
	end

	setStatus("Paste your key, then unlock. Need a key? Open the key site below.")

	mk("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "Key",
		TextColor3 = C.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
	}, body)

	keyBox = mk("TextBox", {
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		FontFace = FONT,
		PlaceholderText = "Paste your key",
		PlaceholderColor3 = C.textDim,
		Text = tostring(env.script_key or _G.script_key or ""),
		TextColor3 = C.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, keyBox)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, keyBox)
	mk("UIStroke", { Color = C.stroke, Thickness = 1 }, keyBox)
	applyFocus(keyBox, 1)
	track(keyBox.Focused:Connect(function()
		layoutCard()
	end))
	track(keyBox.FocusLost:Connect(function(enter)
		layoutCard()
		if enter then
			unlock()
		end
	end))

	mk("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "Key site",
		TextColor3 = C.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 4,
	}, body)

	local list = mk("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 5,
	}, body)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, list)

	for i = 1, #PROVIDERS do
		local p = PROVIDERS[i]
		local row = mk("TextButton", {
			BackgroundColor3 = C.bg,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = i,
		}, list)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		mk("UIStroke", { Color = C.divider, Thickness = 1 }, row)
		local mark = mk("Frame", {
			BackgroundColor3 = C.divider,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 1, 0),
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, mark)
		local lbl = mk("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = FONT,
			Text = p.name,
			TextColor3 = C.text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -24, 1, 0),
		}, row)
		applyFocus(row, 1 + i)
		providerBtns[i] = { btn = row, mark = mark, lbl = lbl }
		track(row.Activated:Connect(function()
			selected = i
			paintProviders()
			setStatus("Using " .. p.name .. ".")
		end))
	end
	paintProviders()

	local getKey = mk("TextButton", {
		BackgroundColor3 = C.accent,
		BorderSizePixel = 0,
		FontFace = FONT_BOLD,
		Text = "Get your key",
		TextColor3 = C.ink,
		TextSize = 16,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 6,
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, getKey)
	applyFocus(getKey, 7)
	track(getKey.Activated:Connect(function()
		local p = PROVIDERS[selected] or PROVIDERS[1]
		openUrl(p.url)
	end))
	track(getKey.MouseEnter:Connect(function()
		getKey.BackgroundColor3 = Color3.fromRGB(232, 192, 72)
	end))
	track(getKey.MouseLeave:Connect(function()
		getKey.BackgroundColor3 = C.accent
	end))

	local unlockBtn = mk("TextButton", {
		BackgroundColor3 = C.hover,
		BorderSizePixel = 0,
		FontFace = FONT_BOLD,
		Text = "Unlock",
		TextColor3 = C.text,
		TextSize = 16,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 7,
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, unlockBtn)
	applyFocus(unlockBtn, 8)
	track(unlockBtn.Activated:Connect(unlock))
	track(unlockBtn.MouseEnter:Connect(function()
		unlockBtn.BackgroundColor3 = C.divider
	end))
	track(unlockBtn.MouseLeave:Connect(function()
		unlockBtn.BackgroundColor3 = C.hover
	end))

	layoutCard()
end

build()
