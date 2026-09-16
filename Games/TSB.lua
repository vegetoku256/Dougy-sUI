-- Games/TSB.lua
-- PlaceId: 10449761463

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.PlaceId ~= 10449761463 then
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    warn("[TSB] LocalPlayer unavailable")
    return
end

-- ReplicatedStorage/Info.lua
local MA_KEY = "Purple"
local SKILL_HOLD_S = 0.08
local SCAN_DT = 0.03
local WHIRL_GAP_S = 3
local SWITCH_TIMEOUT_S = 8
local NOTIFY_GAP_S = 4
local SAFE_Y = 400 -- arena floor ~438; client kill-plane is Y < -500
local IDLE_X, IDLE_Z = 2200, 2200
local IDLE_Y_DEFAULT = 200
local BARRAGE_ANIM = 17799224866
local BARRAGE_FINISHER = 17799198808
local HEAD_FIRST_ANIM = 18179181663
local VK_ANIM = 17838006839
local TWIN_FANG_ANIM = 18896229321
local TWIN_FANGS2_ANIM = 18896232119
local TWIN_FANG_TP_WAIT = 0.15
local TWIN_FANG_VOID_WAIT = 2.6
local TWIN_FANG_KILL_LEAD = 0.5
local FANG_STEP = 50 -- livecframes/HRP rejects deltas > 60; Smooth Grab skips follow if gap > 100, flags rollback if a local victim jumps > 75
local FANG_BOX_SHIFT = 110 -- 0.5s before kill: step this far up, then instant snap
local FANG_STAND_Y = -499 -- kill-plane is Y < -500; look down so grabbed victims sit under it
local CFG_FILE = "TSB_settings.json"
local RUNTIME_KEY = "__DougysTSB_10449761463"

local cfg = {
    targetMode = "Nearest",
    selectedNames = {},
    selectedMoves = { "M1" },
    includeDummies = true,
    skipFriends = false,
    autoPurple = true,
    spectateTarget = true,
    autoUlt = false,
    softlockFinishers = false,
    twinFangDeath = false,
    skipDeathCounter = false,
    toggleInvis = false,
    overlayChar = true,
    overlayUltBar = true,
    overlayUlted = true,
    overlayDeathCounter = true,
    overlayOutline = true,
    depth = 6,
    attackGap = 0.01,
    animPick = "Box Idle",
    loopAnim = false,
    animAll = false,
    animWalk = false,
    animSideDash = false,
    animClipFrom = 0,
    animClipTo = 0,
    idlePad = true,
    idlePadY = IDLE_Y_DEFAULT,
}

local function copyStrList(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    if src[1] ~= nil then
        for _, v in ipairs(src) do
            if type(v) == "string" and v ~= "" and v ~= "(no players)" then
                table.insert(out, v)
            end
        end
        return out
    end
    for k, v in pairs(src) do
        if type(k) == "string" and v == true and k ~= "(no players)" then
            table.insert(out, k)
        end
    end
    return out
end

local function nameSet(list)
    local set = {}
    for _, n in ipairs(list) do
        set[n] = true
    end
    return set
end

local function intersectVisible(saved, visible)
    local want = nameSet(copyStrList(saved))
    local out = {}
    for _, n in ipairs(visible) do
        if n ~= "(no players)" and want[n] then
            table.insert(out, n)
        end
    end
    return out
end

-- Keep offline / other-kit checks in cfg; UI only toggles what's on screen.
local function mergeVisibleChecks(saved, visible, selected)
    local vis = nameSet(visible)
    vis["(no players)"] = nil
    local sel = nameSet(copyStrList(selected))
    local out = {}
    local seen = {}
    for _, n in ipairs(copyStrList(saved)) do
        if n ~= "(no players)" and not vis[n] and not seen[n] then
            table.insert(out, n)
            seen[n] = true
        end
    end
    for _, n in ipairs(visible) do
        if n ~= "(no players)" and sel[n] and not seen[n] then
            table.insert(out, n)
            seen[n] = true
        end
    end
    return out
end

local function loadCfg()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return
    end
    pcall(function()
        if not isfile(CFG_FILE) then
            return
        end
        local data = HttpService:JSONDecode(readfile(CFG_FILE))
        if type(data) ~= "table" then
            return
        end
        if type(data.targetMode) == "string" then
            cfg.targetMode = data.targetMode
        end
        if type(data.depth) == "number" then
            cfg.depth = math.clamp(data.depth, 2, 20)
        end
        if type(data.animPick) == "string" then
            local pick = data.animPick
            if pick == "Off" or pick == "Box Idle" or pick == "Electric" or pick == "Square Up" or pick == "Rest Idle" or pick == "Sincere Apology" then
                cfg.animPick = pick
            elseif pick == "Nuclear Victim" then
                cfg.animPick = "Box Idle"
            end
        end
        if type(data.animClipFrom) == "number" then
            cfg.animClipFrom = math.clamp(data.animClipFrom, 0, 20)
        end
        if type(data.animClipTo) == "number" then
            cfg.animClipTo = math.clamp(data.animClipTo, 0, 20)
        end
        for _, key in ipairs({
            "includeDummies",
            "skipFriends",
            "autoPurple",
            "spectateTarget",
            "autoUlt",
            "softlockFinishers",
            "twinFangDeath",
            "skipDeathCounter",
            "toggleInvis",
            "overlayChar",
            "overlayUltBar",
            "overlayUlted",
            "overlayDeathCounter",
            "overlayOutline",
            "loopAnim",
            "animAll",
            "animWalk",
            "animSideDash",
            "idlePad",
        }) do
            if type(data[key]) == "boolean" then
                cfg[key] = data[key]
            end
        end
        cfg.selectedNames = copyStrList(data.selectedNames)
        local moves = copyStrList(data.selectedMoves)
        if #moves > 0 then
            cfg.selectedMoves = moves
        end
    end)
end

local function saveCfg()
    if type(writefile) ~= "function" then
        return
    end
    pcall(function()
        writefile(CFG_FILE, HttpService:JSONEncode({
            targetMode = cfg.targetMode,
            selectedNames = cfg.selectedNames,
            selectedMoves = cfg.selectedMoves,
            includeDummies = cfg.includeDummies,
            skipFriends = cfg.skipFriends,
            autoPurple = cfg.autoPurple,
            spectateTarget = cfg.spectateTarget,
            autoUlt = cfg.autoUlt,
            softlockFinishers = cfg.softlockFinishers,
            twinFangDeath = cfg.twinFangDeath,
            skipDeathCounter = cfg.skipDeathCounter,
            toggleInvis = cfg.toggleInvis,
            overlayChar = cfg.overlayChar,
            overlayUltBar = cfg.overlayUltBar,
            overlayUlted = cfg.overlayUlted,
            overlayDeathCounter = cfg.overlayDeathCounter,
            overlayOutline = cfg.overlayOutline,
            depth = cfg.depth,
            attackGap = cfg.attackGap,
            animPick = cfg.animPick,
            loopAnim = cfg.loopAnim,
            animAll = cfg.animAll,
            animWalk = cfg.animWalk,
            animSideDash = cfg.animSideDash,
            animClipFrom = cfg.animClipFrom,
            animClipTo = cfg.animClipTo,
            idlePad = cfg.idlePad,
            idlePadY = cfg.idlePadY,
        }))
    end)
end

loadCfg()

local SPECTATE_BIND = "DougysTSB_Spectate"
local PARK_BIND = "DougysTSB_Park"
local FANG_BIND = "DougysTSB_FangRep"
local CLIP_BIND = "DougysTSB_AnimClip"

local Info
pcall(function()
    local mod = ReplicatedStorage:FindFirstChild("Info")
    if mod then
        Info = require(mod)
    end
end)

local function sharedEnv()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env
        end
    end
    if type(shared) == "table" then
        return shared
    end
    if type(_G) == "table" then
        return _G
    end
    return nil
end

local env = sharedEnv()
local prev = env and env[RUNTIME_KEY]
if prev and type(prev.cleanup) == "function" then
    pcall(prev.cleanup)
end

local UI_PC = "https://raw.githubusercontent.com/vegetoku256/Dougy-sUI/70ee8be/UI/DougysUI.lua?t="
local UI_MOBILE = "https://raw.githubusercontent.com/vegetoku256/Dougy-sUI/70ee8be/UI/DougysUI_Mobile.lua?t="
local UI_URL = (UserInputService.TouchEnabled and UI_MOBILE or UI_PC)
    .. tostring(math.random(1000000, 9999999))

local okFetch, uiSource = pcall(function()
    return game:HttpGet(UI_URL)
end)
if not okFetch or type(uiSource) ~= "string" or uiSource == "" then
    error("[TSB] Failed to fetch DougysUI: " .. tostring(uiSource))
end

local uiFn, compileErr = loadstring(uiSource, "DougysUI")
if not uiFn then
    error("[TSB] Failed to compile DougysUI: " .. tostring(compileErr))
end

local okRun, Eclipse = pcall(uiFn)
if not okRun or type(Eclipse) ~= "table" or type(Eclipse.CreateWindow) ~= "function" then
    error("[TSB] Failed to load DougysUI: " .. tostring(Eclipse))
end

local Window = Eclipse:CreateWindow({
    Title = "The Strongest Battlegrounds",
    Subtitle = "Game: " .. tostring(game.PlaceId),
    ToggleKey = Enum.KeyCode.RightShift,
    SearchBar = false,
    ArrayList = true,
    SplashScreen = true,
    BlurEffect = true,
    AutoHideOnChat = true,
    SplashTitle = "The Strongest Battlegrounds",
    SplashSubtitle = "Dougy's Hub Loading...",
})

if Window.AddChangelog then
    Window:AddChangelog("1.3.0", {
        "Hitbox panel: local query box on other Live characters (skills/grabs/radius)",
    }, "2026-09-11")
    Window:AddChangelog("1.2.0", {
        "Move picker uses real skill names from the current kit, including awakening",
        "Auto ultimate when the bar is full",
        "Spectate holds a scriptable camera; the game was resetting CameraSubject",
    }, "2026-09-10")
    Window:AddChangelog("1.1.0", {
        "Under-floor park: stay under the target and M1 from there",
        "Nested targeting settings (right-click / v on the toggle)",
        "Debug panel can write a TSB report file in the executor folder",
    }, "2026-09-10")
    Window:AddChangelog("1.0.0", {
        "Martial Artist Invisible Auto Attack",
    }, "2026-09-10")
end

local actionCheckFn
pcall(function()
    local mod = ReplicatedStorage:FindFirstChild("ActionCheck")
    if mod then
        local ok, loaded = pcall(require, mod)
        if ok and type(loaded) == "table" and type(loaded.Check) == "function" then
            actionCheckFn = loaded.Check
        end
    end
end)

local DEBUG_DIR = "TSB debug report"
local debugReportPath
local debugEnabled = false
local playerDrop
local moveDrop

local runtime = {
    enabled = false,
    shutdown = false,
    ignoreToggle = false,
    destroyed = false,
    workGen = 0,
    window = Window,
    toggle = nil,
    conns = {},
    charConns = {},
    lastNotifyAt = {},
    lastDiagAt = 0,
    target = nil,
    waitingTarget = false,
    switchPending = false,
    heldM1 = false,
    m1ingSince = nil,
    heldVK = nil,
    lastCombatAt = 0,
    lastUltAt = 0,
    lastWhirlAt = 0,
    moveIdx = 0,
    ultNameSet = {},
    safeCFrame = nil,
    idlePlat = nil,
    cameraChanged = false,
    cameraSubject = nil,
    friendCache = {},
    humDisplay = nil,
    savedTrans = {},
    savedCollide = nil,
    savedColGroup = nil,
    surfaceCast = false,
    whirlPlanted = false,
    whirlPhase = nil,
    holdParkUntil = 0,
    fangBusy = false,
    fangVoiding = false,
    fangCf = nil,
    fangSent = nil,
    fangStopTween = nil,
    antiConn = nil,
    antiStart = nil,
    antiStop = nil,
    overlayConn = nil,
    overlayGui = nil,
    overlayStart = nil,
    overlayStop = nil,
    dropSyncing = false,
    moveRep = nil,
    fangAlign = nil,
    fangAtt0 = nil,
    fangAtt1 = nil,
    lastGroundY = nil,
    lastStandY = nil,
    camYaw = nil,
    camPitch = nil,
    mouseLocked = false,
    animPick = cfg.animPick,
    loopAnim = cfg.loopAnim,
    loopTrack = nil,
    animAll = cfg.animAll,
    animWalk = cfg.animWalk,
    animSideDash = cfg.animSideDash,
    overrideGen = 0,
    animClipFrom = cfg.animClipFrom,
    animClipTo = cfg.animClipTo,
    poseRetryAt = 0,
    clipKey = nil,
}

local function still(gen)
    return runtime.enabled and (not runtime.shutdown) and gen == runtime.workGen
end

local function connect(conn)
    if conn then
        table.insert(runtime.conns, conn)
    end
    return conn
end

local function disconnectList(list)
    for i = #list, 1, -1 do
        local c = list[i]
        list[i] = nil
        if c then
            pcall(function()
                c:Disconnect()
            end)
        end
    end
end

local function liveFolder()
    return Workspace:FindFirstChild("Live")
end

local function liveChar()
    local char = LocalPlayer.Character
    local live = liveFolder()
    if char and live and char.Parent == live then
        return char
    end
    return char
end

local function charHum(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function charRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function communicate(char)
    char = char or liveChar() or LocalPlayer.Character
    local rem = char and char:FindFirstChild("Communicate")
    if rem and rem:IsA("RemoteEvent") then
        return rem
    end
    return nil
end

local function moveset(char)
    char = char or liveChar()
    if char then
        local a = char:GetAttribute("Character")
        if a ~= nil then
            return a
        end
    end
    return LocalPlayer:GetAttribute("Character")
end

local function notify(msg, duration)
    if type(msg) ~= "string" or msg == "" then
        return
    end
    local now = os.clock()
    local last = runtime.lastNotifyAt[msg]
    if last and (now - last) < NOTIFY_GAP_S then
        return
    end
    runtime.lastNotifyAt[msg] = now
    if Window and Window.Notify then
        Window:Notify(msg, duration or 3)
    end
end

local function ensureDebugReport()
    if debugReportPath then
        return true
    end
    if not writefile then
        return false
    end
    pcall(function()
        if isfolder then
            if not isfolder(DEBUG_DIR) then
                makefolder(DEBUG_DIR)
            end
        elseif makefolder then
            makefolder(DEBUG_DIR)
        end
    end)
    debugReportPath = DEBUG_DIR .. "/debug-" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".txt"
    pcall(function()
        writefile(debugReportPath, "-- " .. debugReportPath .. "\n")
    end)
    return true
end

local function debugReport(tag, msg)
    if not debugEnabled then
        return
    end
    if not ensureDebugReport() then
        return
    end
    local line = os.date("%H:%M:%S") .. "[" .. tag .. "] " .. tostring(msg) .. "\n"
    pcall(function()
        if appendfile then
            appendfile(debugReportPath, line)
        elseif readfile and isfile and isfile(debugReportPath) then
            writefile(debugReportPath, readfile(debugReportPath) .. line)
        else
            writefile(debugReportPath, line)
        end
    end)
end

local function diag(reason)
    local now = os.clock()
    if now - runtime.lastDiagAt < 1 then
        return
    end
    runtime.lastDiagAt = now
    local char = liveChar()
    local t = runtime.target
    warn(string.format(
        "[TSB] gen=%d char=%s target=%s reason=%s",
        runtime.workGen,
        tostring(char and char.Name or "-"),
        tostring(t and t.Name or "-"),
        tostring(reason)
    ))
    debugReport("diag", reason)
end

local function fire(payload, opts)
    opts = opts or {}
    if runtime.destroyed then
        return false
    end
    if not opts.release then
        if runtime.shutdown or not runtime.enabled then
            return false
        end
        if opts.gen and opts.gen ~= runtime.workGen then
            return false
        end
    end
    local rem = communicate()
    if not rem then
        return false
    end
    local ok = pcall(function()
        rem:FireServer(payload)
    end)
    return ok
end

local function releaseHeld()
    if runtime.heldM1 then
        fire({ Goal = "LeftClickRelease" }, { release = true })
        runtime.heldM1 = false
    end
    if runtime.heldVK then
        local tool = runtime.heldVK
        runtime.heldVK = nil
        fire({ Goal = "Console Move End", Tool = tool }, { release = true })
    end
    runtime.surfaceCast = false
    runtime.whirlPlanted = false
    runtime.whirlPhase = nil
end

local function idlePos()
    return Vector3.new(IDLE_X, cfg.idlePadY, IDLE_Z)
end

local function nearIdle(pos)
    if not pos then
        return false
    end
    local dx = pos.X - IDLE_X
    local dz = pos.Z - IDLE_Z
    return dx * dx + dz * dz < 6400
end

local function captureSafe()
    local root = charRoot(liveChar() or LocalPlayer.Character)
    if not root or root.Position.Y < SAFE_Y then
        return
    end
    if nearIdle(root.Position) then
        return
    end
    runtime.safeCFrame = root.CFrame
end

local function restoreSafe()
    local char = LocalPlayer.Character
    local root = charRoot(char)
    if not char or not root then
        return
    end
    local dest = runtime.safeCFrame
    if not dest then
        local tRoot = charRoot(runtime.target)
        if tRoot and tRoot.Position.Y >= SAFE_Y then
            dest = CFrame.new(tRoot.Position + Vector3.new(0, 4, 0))
        end
    end
    if not dest then
        return
    end
    if not nearIdle(root.Position) and root.Position.Y >= 430 and root.Position.Y >= dest.Position.Y - 3 then
        return
    end
    pcall(function()
        char:PivotTo(dest)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function ensureIdlePlatform()
    local dest = CFrame.new(idlePos())
    local p = runtime.idlePlat
    if p and p.Parent then
        if (p.Position - dest.Position).Magnitude > 0.05 then
            p.CFrame = dest
        end
        return p
    end
    p = Instance.new("Part")
    p.Name = "DougysIdlePlat"
    p.Anchored = true
    p.CanCollide = true
    p.CanQuery = false
    p.CanTouch = false
    p.Size = Vector3.new(48, 2, 48)
    p.CFrame = dest
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(36, 36, 40)
    p.Transparency = 0.25
    p.Parent = Workspace
    runtime.idlePlat = p
    return p
end

local function goIdlePlatform()
    if not cfg.idlePad then
        restoreSafe()
        return
    end
    local plat = ensureIdlePlatform()
    local char = liveChar() or LocalPlayer.Character
    local root = charRoot(char)
    if not char or not root or not plat then
        return
    end
    local dest = plat.CFrame * CFrame.new(0, 5, 0)
    if (root.Position - dest.Position).Magnitude < 8 then
        return
    end
    pcall(function()
        char:PivotTo(dest)
        root.CFrame = dest
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function destroyIdlePlatform()
    local p = runtime.idlePlat
    runtime.idlePlat = nil
    if p then
        pcall(function()
            p:Destroy()
        end)
    end
end

-- Velocity Forward uses `(Distance or 55)`; 0 is falsy. lookAt(same XZ, target) is straight down → void.
local function facingAt(pos, targetRoot)
    local lv = targetRoot.CFrame.LookVector
    local look = Vector3.new(lv.X, 0, lv.Z)
    if look.Magnitude < 0.05 then
        look = Vector3.new(0, 0, -1)
    else
        look = look.Unit
    end
    return CFrame.lookAt(pos, pos + look)
end

local function onGroundCFrame(targetRoot)
    return facingAt(targetRoot.Position, targetRoot)
end

local function restoreParkBody(char)
    char = char or liveChar() or LocalPlayer.Character
    local saved = runtime.savedCollide
    local groups = runtime.savedColGroup
    runtime.savedCollide = nil
    runtime.savedColGroup = nil
    if saved then
        for d, v in pairs(saved) do
            if typeof(d) == "Instance" and d.Parent then
                pcall(function()
                    d.CanCollide = v
                end)
            end
        end
    end
    if groups then
        for d, g in pairs(groups) do
            if typeof(d) == "Instance" and d.Parent then
                pcall(function()
                    d.CollisionGroup = g
                end)
            end
        end
    end
end

-- TSB forces PlatformStand off. Torso/Head stay in playercol and pop you onto the floor.
local function sinkParkBody(char)
    if not char then
        return
    end
    if not runtime.savedCollide then
        runtime.savedCollide = {}
    end
    if not runtime.savedColGroup then
        runtime.savedColGroup = {}
    end
    local saved = runtime.savedCollide
    local groups = runtime.savedColGroup
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            if saved[d] == nil then
                saved[d] = d.CanCollide
            end
            if groups[d] == nil then
                groups[d] = d.CollisionGroup
            end
            d.CanCollide = false
            d.CollisionGroup = "nocol"
        end
    end
end

local function unlockSpectateMouse()
    if not runtime.mouseLocked then
        return
    end
    runtime.mouseLocked = false
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
end

local function restoreCamera()
    pcall(function()
        RunService:UnbindFromRenderStep(SPECTATE_BIND)
    end)
    pcall(function()
        LocalPlayer:SetAttribute("cameramode", nil)
    end)
    unlockSpectateMouse()
    runtime.camYaw = nil
    runtime.camPitch = nil
    local cam = Workspace.CurrentCamera
    local hum = charHum(LocalPlayer.Character)
    if cam then
        pcall(function()
            cam.CameraType = Enum.CameraType.Custom
            if hum then
                cam.CameraSubject = hum
            elseif runtime.cameraSubject ~= nil then
                cam.CameraSubject = runtime.cameraSubject
            end
        end)
    end
    runtime.cameraChanged = false
    runtime.cameraSubject = nil
end

local function spectateOwnView()
    unlockSpectateMouse()
    local cam = Workspace.CurrentCamera
    local hum = charHum(LocalPlayer.Character)
    if not cam then
        return
    end
    pcall(function()
        cam.CameraType = Enum.CameraType.Custom
        if hum then
            cam.CameraSubject = hum
        end
    end)
end

-- CharacterHandler Heartbeat forces CameraSubject back to you unless CameraType is Scriptable.
-- Custom + CameraSubject never wins. Scriptable CFrame + RMB orbit does.
local function spectateStep()
    if not runtime.enabled or runtime.shutdown or not cfg.spectateTarget then
        return
    end
    local target = runtime.target
    if not target or not target.Parent then
        if runtime.cameraChanged then
            spectateOwnView()
        end
        return
    end
    local cam = Workspace.CurrentCamera
    local look = target:FindFirstChild("Head") or charRoot(target)
    if not cam or not look then
        return
    end
    if not runtime.cameraChanged then
        runtime.cameraSubject = cam.CameraSubject
        runtime.cameraChanged = true
        pcall(function()
            LocalPlayer:SetAttribute("cameramode", true)
        end)
    end
    pcall(function()
        LocalPlayer:SetAttribute("cameramode", true)
    end)
    local focus = look.Position + Vector3.new(0, 1.5, 0)
    if runtime.camYaw == nil then
        local off = cam.CFrame.Position - focus
        if off.Magnitude < 1 then
            local lv = look.CFrame.LookVector
            runtime.camYaw = math.atan2(-lv.X, -lv.Z)
            runtime.camPitch = -0.2
        else
            runtime.camYaw = math.atan2(-off.X, -off.Z)
            runtime.camPitch = math.clamp(math.asin(math.clamp(off.Y / off.Magnitude, -1, 1)), -1.35, 1.35)
        end
    end
    local rmb = false
    pcall(function()
        rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end)
    if rmb then
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end)
        runtime.mouseLocked = true
        local delta = Vector2.zero
        pcall(function()
            delta = UserInputService:GetMouseDelta()
        end)
        runtime.camYaw = runtime.camYaw - delta.X * 0.006
        runtime.camPitch = math.clamp(runtime.camPitch - delta.Y * 0.006, -1.35, 1.35)
    else
        unlockSpectateMouse()
    end
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.new(focus) * CFrame.fromEulerAnglesYXZ(runtime.camPitch, runtime.camYaw, 0) * CFrame.new(0, 0, 14)
    end)
end

local function bindSpectate()
    pcall(function()
        RunService:UnbindFromRenderStep(SPECTATE_BIND)
    end)
    pcall(function()
        RunService:BindToRenderStep(SPECTATE_BIND, Enum.RenderPriority.Last.Value, spectateStep)
    end)
end

local function findTool(char, name)
    local function scan(parent)
        if not parent then
            return nil
        end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Tool") and (child.Name == name or child:GetAttribute("Name") == name) then
                return child
            end
        end
        return nil
    end
    return scan(char) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

-- StarterGui/Hotbar/Backpack: Cooldown overlay lives on the slot while the server CD runs.
local function moveOnCooldown(name)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local bar = pg and pg:FindFirstChild("Hotbar")
    local pack = bar and bar:FindFirstChild("Backpack")
    local slots = pack and pack:FindFirstChild("Hotbar")
    if not slots then
        return false
    end
    for _, slot in ipairs(slots:GetChildren()) do
        local base = slot:FindFirstChild("Base")
        local label = base and base:FindFirstChild("ToolName")
        if label and label.Text == name and base:FindFirstChild("Cooldown") then
            return true
        end
    end
    return false
end

-- ReplicatedStorage/Info.lua Skillsets.Base / Ultimate / CosmicUltimate
local function kitMoves()
    local base, ult = {}, {}
    runtime.ultNameSet = {}
    local key = moveset()
    local kit = Info and Info.Skillsets and key and Info.Skillsets[key]
    local function add(list, name, asUlt)
        if type(name) ~= "string" or name == "" then
            return
        end
        for _, existing in ipairs(list) do
            if existing == name then
                return
            end
        end
        table.insert(list, name)
        if asUlt then
            runtime.ultNameSet[name] = true
        end
    end
    if kit then
        for _, name in ipairs(kit.Base or {}) do
            add(base, name, false)
        end
        for _, name in ipairs(kit.Ultimate or {}) do
            add(ult, name, true)
        end
        for _, name in ipairs(kit.CosmicUltimate or {}) do
            add(ult, name, true)
        end
    else
        local char = liveChar() or LocalPlayer.Character
        local bag = LocalPlayer:FindFirstChild("Backpack")
        for _, parent in ipairs({ char, bag }) do
            if parent then
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("Tool") then
                        add(base, child:GetAttribute("Name") or child.Name, false)
                    end
                end
            end
        end
    end
    return base, ult
end

local function moveOptionList()
    local opts = { "M1" }
    local base, ult = kitMoves()
    for _, name in ipairs(base) do
        table.insert(opts, name)
    end
    for _, name in ipairs(ult) do
        table.insert(opts, name)
    end
    return opts
end

local function selectedMoveList()
    local allowed = {}
    for _, n in ipairs(moveOptionList()) do
        allowed[n] = true
    end
    local names = {}
    local src = cfg.selectedMoves
    if type(src) == "table" then
        if src[1] ~= nil then
            for _, n in ipairs(src) do
                if allowed[n] then
                    table.insert(names, n)
                end
            end
        else
            for n, v in pairs(src) do
                if v == true and allowed[n] then
                    table.insert(names, n)
                end
            end
        end
    end
    if #names == 0 then
        table.insert(names, "M1")
    end
    return names
end

local function wantsM1()
    for _, name in ipairs(selectedMoveList()) do
        if name == "M1" then
            return true
        end
    end
    return false
end

local function refreshMoveDrop()
    if not (moveDrop and moveDrop.SetOptions) then
        return
    end
    local opts = moveOptionList()
    runtime.dropSyncing = true
    pcall(function()
        moveDrop:SetOptions(opts)
        if moveDrop.Set then
            moveDrop:Set(intersectVisible(cfg.selectedMoves, opts))
        end
    end)
    runtime.dropSyncing = false
end

local function mouseAt(targetRoot)
    if targetRoot and targetRoot.Parent then
        return CFrame.new(targetRoot.Position)
    end
    local root = charRoot(liveChar())
    if root then
        return root.CFrame * CFrame.new(0, 0, -6)
    end
    return CFrame.new()
end

local function pauseAttacks(char)
    if not char then
        return true
    end
    local hum = charHum(char)
    if not hum or hum.Health <= 0 then
        return true
    end
    if char:FindFirstChild("FinalDeath") then
        return true
    end
    if runtime.enabled then
        return false
    end
    local root = charRoot(char)
    if root and root.Position.Y < SAFE_Y then
        return false
    end
    if actionCheckFn then
        local ok, result = pcall(actionCheckFn, char)
        if ok and result ~= true then
            return true
        end
    end
    if char:FindFirstChild("Ragdoll") or char:GetAttribute("Blocking") or Workspace:GetAttribute("NoAttack") or Workspace:GetAttribute("GlobalStun") then
        return true
    end
    return false
end

-- CharacterHandler/Client.lua: LeftClick needs MousePos. Release before M1ing exists drops the punch.
local function fireM1(gen, targetRoot)
    if runtime.heldM1 then
        return false
    end
    local char = liveChar() or LocalPlayer.Character
    local hum = charHum(char)
    if not char or not hum or hum.Health <= 0 or char:FindFirstChild("FinalDeath") then
        return false
    end
    local m1ing = char:FindFirstChild("M1ing")
    if m1ing then
        local t0 = runtime.m1ingSince
        if not t0 then
            runtime.m1ingSince = os.clock()
            return false
        end
        if os.clock() - t0 < 1 then
            return false
        end
    else
        runtime.m1ingSince = nil
    end
    local payload = {
        Goal = "LeftClick",
        MousePos = mouseAt(targetRoot),
    }
    if not fire(payload, { gen = gen }) then
        return false
    end
    runtime.heldM1 = true
    debugReport("m1", "fired at " .. tostring(runtime.target and runtime.target.Name))
    task.spawn(function()
        local t0 = os.clock()
        while runtime.heldM1 and still(gen) and os.clock() - t0 < 0.45 do
            local c = liveChar() or LocalPlayer.Character
            if c and c:FindFirstChild("M1ing") then
                break
            end
            task.wait(0.03)
        end
        if runtime.heldM1 then
            fire({ Goal = "LeftClickRelease" }, { release = true, gen = gen })
            runtime.heldM1 = false
        end
    end)
    return true
end

-- StarterGui/Hotbar/Backpack/LocalScript.lua: Console Move
-- Whirlwind Drop: CharacterHandler 17857788598. Pinning through the slam BV yeets through the floor.
local function killMovers(char)
    local root = charRoot(char)
    pcall(function()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if not char then
            return
        end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BodyVelocity") or d:IsA("LinearVelocity") or d:IsA("VectorForce") then
                d:Destroy()
            end
        end
    end)
end

local function endSurface()
    runtime.surfaceCast = false
    runtime.whirlPlanted = false
    runtime.whirlPhase = nil
    killMovers(liveChar() or LocalPlayer.Character)
end

local function fireSkill(gen, toolName, targetRoot)
    local char = liveChar() or LocalPlayer.Character
    local tool = findTool(char, toolName)
    if not tool then
        return false
    end
    if os.clock() - runtime.lastCombatAt < cfg.attackGap then
        return false
    end
    local whirl = toolName == "Whirlwind Drop"
    if not whirl and pauseAttacks(char) then
        return false
    end
    if whirl then
        if moveOnCooldown(toolName) then
            return false
        end
        runtime.surfaceCast = true
        runtime.whirlPhase = "plant"
        runtime.whirlPlanted = false
        local t0 = os.clock()
        while still(gen) and os.clock() - t0 < 0.6 do
            if runtime.whirlPlanted then
                break
            end
            task.wait(0.03)
        end
        if not still(gen) or not runtime.whirlPlanted then
            runtime.lastWhirlAt = os.clock()
            endSurface()
            return false
        end
        char = liveChar() or LocalPlayer.Character
        tool = findTool(char, toolName)
        if not tool then
            endSurface()
            return false
        end
    end
    pcall(function()
        tool:SetAttribute("Name", tool:GetAttribute("Name") or toolName)
    end)
    local ok = fire({
        Goal = "Console Move",
        Tool = tool,
        IsAutoActivate = true,
        MousePos = mouseAt(targetRoot),
    }, { gen = gen })
    if ok then
        runtime.heldVK = tool
        runtime.lastCombatAt = os.clock()
        debugReport("skill", toolName)
        local me = liveChar() or LocalPlayer.Character
        local myRoot = charRoot(me)
        if toolName == "Head First" or toolName == "Vanishing Kick" then
            runtime.holdParkUntil = os.clock() + (toolName == "Head First" and 3.5 or 2)
        end
        task.delay(whirl and 0.25 or SKILL_HOLD_S, function()
            if runtime.heldVK == tool then
                fire({ Goal = "Console Move End", Tool = tool }, { release = true, gen = gen })
                runtime.heldVK = nil
            end
        end)
        if whirl then
            runtime.lastWhirlAt = os.clock()
            runtime.whirlPhase = "play"
            local t1 = os.clock()
            local sawBV = false
            while still(gen) and os.clock() - t1 < 1.6 do
                local r = charRoot(liveChar() or LocalPlayer.Character)
                if r and r:FindFirstChild("VelForwardBv") then
                    sawBV = true
                elseif sawBV then
                    break
                elseif os.clock() - t1 > 0.35 then
                    break
                end
                task.wait(0.03)
            end
            endSurface()
        end
    elseif whirl then
        endSurface()
    end
    return ok
end

-- CharacterHandler/Client.lua: G + MoveDirection awakens
local function fireUlt(gen)
    if os.clock() - runtime.lastUltAt < 1 then
        return false
    end
    local char = liveChar() or LocalPlayer.Character
    local hum = charHum(char)
    if not char or not hum then
        return false
    end
    if char:GetAttribute("Ulted") then
        return false
    end
    local bar = tonumber(LocalPlayer:GetAttribute("Ultimate")) or 0
    if bar < 100 then
        return false
    end
    local ok = fire({
        Goal = "KeyPress",
        Key = Enum.KeyCode.G,
        MoveDirection = hum.MoveDirection,
        MousePos = mouseAt(charRoot(char)),
    }, { gen = gen })
    if ok then
        runtime.lastUltAt = os.clock()
        debugReport("ult", "G")
        task.delay(0.12, function()
            fire({ Goal = "KeyRelease", Key = Enum.KeyCode.G }, { release = true, gen = gen })
        end)
    end
    return ok
end

local function ownsPurple()
    local raw = LocalPlayer:GetAttribute("Characters")
    if type(raw) == "string" then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if ok and type(decoded) == "table" then
            for _, name in ipairs(decoded) do
                if name == MA_KEY then
                    return true
                end
            end
            return false
        end
    end
    return true
end

local function requestPurple(gen)
    if moveset() == MA_KEY then
        return true
    end
    if not ownsPurple() then
        return false
    end
    local char = liveChar() or LocalPlayer.Character
    local rem = communicate(char)
    if not rem then
        return false
    end
    if runtime.switchPending then
        return true
    end
    runtime.switchPending = true
    notify("Switching to Martial Artist")
    debugReport("char", "Change Character Purple")
    -- User Error Interface.lua: Change Character
    pcall(function()
        rem:FireServer({
            Goal = "Change Character",
            Character = MA_KEY,
        })
    end)
    local deadline = os.clock() + SWITCH_TIMEOUT_S
    while os.clock() < deadline and still(gen) do
        if moveset() == MA_KEY and liveChar() then
            runtime.switchPending = false
            return true
        end
        task.wait(0.1)
    end
    runtime.switchPending = false
    return moveset() == MA_KEY
end

local function invalidExclude(model)
    if not model or not model:IsA("Model") or not model.Parent then
        return true
    end
    if model:GetAttribute("FakeHumanoid") or model:FindFirstChild("FakeHumanoid") or model:FindFirstChild("FinalDeath") or model:GetAttribute("MoveEditorSandbox") or model:GetAttribute("ClonedChar") or model:GetAttribute("ClonedCharS") or model:GetAttribute("ClonedChar2") or model:GetAttribute("CloneOwner") then
        return true
    end
    local ff = model:FindFirstChildOfClass("ForceField")
    if ff and ff.Name == "AbsoluteImmortal" then
        return true
    end
    if model:FindFirstChild("AbsoluteImmortal") then
        return true
    end
    return false
end

local function isFriend(plr)
    if not plr or plr == LocalPlayer then
        return false
    end
    local cached = runtime.friendCache[plr.UserId]
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(function()
        return LocalPlayer:IsFriendsWith(plr.UserId)
    end)
    runtime.friendCache[plr.UserId] = ok and result == true
    return runtime.friendCache[plr.UserId]
end

local function hasDeathCounter(model)
    return model ~= nil and model:FindFirstChild("Counter") ~= nil
end

local function isValidTarget(model)
    if invalidExclude(model) then
        return false
    end
    if cfg.skipDeathCounter and hasDeathCounter(model) then
        return false
    end
    local live = liveFolder()
    if live and model.Parent ~= live then
        return false
    end
    if model == LocalPlayer.Character then
        return false
    end
    local hum = charHum(model)
    local root = charRoot(model)
    if not hum or not root or hum.Health <= 0 then
        return false
    end
    local plr = Players:GetPlayerFromCharacter(model)
    if plr then
        if plr == LocalPlayer then
            return false
        end
        if cfg.skipFriends and isFriend(plr) then
            return false
        end
        local myTeam = LocalPlayer.Team
        if myTeam and myTeam.Neutral == false and plr.Team == myTeam then
            return false
        end
        return true
    end
    return cfg.includeDummies == true
end

local function miscSetup()
    -- Infinite Yield source addcmd("antifling"): Stepped, other players' BaseParts CanCollide=false
    local function stopAnti()
        local conn = runtime.antiConn
        runtime.antiConn = nil
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end

    local function startAnti()
        stopAnti()
        runtime.antiConn = RunService.Stepped:Connect(function()
            if runtime.destroyed then
                return
            end
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, v in pairs(player.Character:GetDescendants()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                        end
                    end
                end
            end
        end)
    end

    local function kitOf(model)
        local key = model and model:GetAttribute("Character")
        if key == nil then
            local plr = Players:GetPlayerFromCharacter(model)
            key = plr and plr:GetAttribute("Character")
        end
        local kit = Info and Info.Skillsets and key and Info.Skillsets[key]
        return key, kit
    end

    local function ultMeter(model)
        local plr = Players:GetPlayerFromCharacter(model)
        if plr then
            return tonumber(plr:GetAttribute("Ultimate")) or 0
        end
        return tonumber(model and model:GetAttribute("Ultimate")) or 0
    end

    local function stopOverlay()
        local conn = runtime.overlayConn
        runtime.overlayConn = nil
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
        end
        local gui = runtime.overlayGui
        runtime.overlayGui = nil
        if gui then
            pcall(function()
                gui:Destroy()
            end)
        end
        local live = liveFolder()
        if live then
            for _, model in ipairs(live:GetChildren()) do
                local hl = model:FindFirstChild("DougysTSB_Outline")
                if hl then
                    pcall(function()
                        hl:Destroy()
                    end)
                end
            end
        end
    end

    local function ensureOverlayGui()
        local gui = runtime.overlayGui
        if gui and gui.Parent then
            return gui
        end
        gui = Instance.new("ScreenGui")
        gui.Name = "DougysTSB_Overlay"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer.PlayerGui
        runtime.overlayGui = gui
        return gui
    end

    local function makeBoard(gui)
        local bb = Instance.new("BillboardGui")
        bb.Name = "Board"
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = 140
        bb.Size = UDim2.fromOffset(260, 136)
        bb.StudsOffset = Vector3.new(0, 4.2, 0)
        bb.ResetOnSpawn = false
        bb.ClipsDescendants = true
        bb.Parent = gui
        local root = Instance.new("Frame")
        root.Name = "Root"
        root.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
        root.BackgroundTransparency = 0.28
        root.BorderSizePixel = 0
        root.ClipsDescendants = true
        root.Size = UDim2.fromScale(1, 1)
        root.Parent = bb
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = root
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0.05, 0)
        pad.PaddingRight = UDim.new(0.05, 0)
        pad.PaddingTop = UDim.new(0.08, 0)
        pad.PaddingBottom = UDim.new(0.08, 0)
        pad.Parent = root
        local list = Instance.new("UIListLayout")
        list.FillDirection = Enum.FillDirection.Vertical
        list.Padding = UDim.new(0.02, 0)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = root
        local row = Instance.new("Frame")
        row.Name = "CharRow"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0.32, 0)
        row.LayoutOrder = 1
        row.Parent = root
        local rowList = Instance.new("UIListLayout")
        rowList.FillDirection = Enum.FillDirection.Horizontal
        rowList.Padding = UDim.new(0.04, 0)
        rowList.SortOrder = Enum.SortOrder.LayoutOrder
        rowList.VerticalAlignment = Enum.VerticalAlignment.Center
        rowList.Parent = row
        local icon = Instance.new("ImageLabel")
        icon.Name = "CharIcon"
        icon.BackgroundTransparency = 1
        icon.LayoutOrder = 1
        icon.Size = UDim2.new(0.82, 0, 0.82, 0)
        icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = row
        local name = Instance.new("TextLabel")
        name.Name = "CharName"
        name.BackgroundTransparency = 1
        name.LayoutOrder = 2
        name.Size = UDim2.new(0.7, 0, 1, 0)
        name.Font = Enum.Font.GothamMedium
        name.TextScaled = true
        name.TextColor3 = Color3.fromRGB(245, 245, 245)
        name.TextStrokeTransparency = 0.35
        name.TextStrokeColor3 = Color3.new()
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Text = ""
        name.Parent = row
        local nameLimit = Instance.new("UITextSizeConstraint")
        nameLimit.MaxTextSize = 22
        nameLimit.Parent = name
        local function line(nm, order, color)
            local lab = Instance.new("TextLabel")
            lab.Name = nm
            lab.BackgroundTransparency = 1
            lab.Size = UDim2.new(1, 0, 0.19, 0)
            lab.LayoutOrder = order
            lab.Font = Enum.Font.Gotham
            lab.TextScaled = true
            lab.TextColor3 = color
            lab.TextStrokeTransparency = 0.35
            lab.TextStrokeColor3 = Color3.new()
            lab.TextXAlignment = Enum.TextXAlignment.Left
            lab.TextTruncate = Enum.TextTruncate.AtEnd
            lab.Text = ""
            lab.Visible = false
            lab.Parent = root
            local lim = Instance.new("UITextSizeConstraint")
            lim.MaxTextSize = 18
            lim.Parent = lab
            return lab
        end
        line("UltBar", 2, Color3.fromRGB(255, 214, 90))
        line("Ulted", 3, Color3.fromRGB(255, 132, 70))
        line("DeathCounter", 4, Color3.fromRGB(255, 72, 72))
        return bb
    end

    local function fitBoard(bb, head)
        local cam = Workspace.CurrentCamera
        local dist = 28
        if cam and head then
            dist = (cam.CFrame.Position - head.Position).Magnitude
        end
        local keep = 28
        local scale = dist > keep and (keep / dist) or 1
        bb.Size = UDim2.fromOffset(260 * scale, 136 * scale)
    end

    local function paintOutline(model, highlights)
        local hl = highlights[model]
        if cfg.overlayOutline ~= true then
            if hl then
                highlights[model] = nil
                pcall(function()
                    hl:Destroy()
                end)
            end
            return
        end
        if not (hl and hl.Parent == model) then
            if hl then
                pcall(function()
                    hl:Destroy()
                end)
            end
            hl = Instance.new("Highlight")
            hl.Name = "DougysTSB_Outline"
            hl.FillTransparency = 1
            hl.OutlineTransparency = 0
            hl.OutlineColor = Color3.fromRGB(255, 70, 70)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = model
            highlights[model] = hl
        end
    end

    local function paintBoard(bb, model)
        local key, kit = kitOf(model)
        local row = bb.Root.CharRow
        local showChar = cfg.overlayChar == true
        row.Visible = showChar
        if showChar then
            local id = kit and kit.ID
            row.CharIcon.Image = type(id) == "number" and ("rbxassetid://" .. id) or ""
            row.CharName.Text = (kit and kit.Name) or (key and tostring(key)) or "?"
        end
        local bar = bb.Root.UltBar
        local showBar = cfg.overlayUltBar == true
        bar.Visible = showBar
        if showBar then
            bar.Text = "Ult " .. tostring(math.clamp(math.floor(ultMeter(model) + 0.5), 0, 100)) .. "%"
        end
        local ultedLab = bb.Root.Ulted
        local ulted = model:GetAttribute("Ulted") == true
        local showUlted = cfg.overlayUlted == true and ulted
        ultedLab.Visible = showUlted
        if showUlted then
            ultedLab.Text = (kit and kit.UltimateName) or "ULT"
        end
        local dc = bb.Root.DeathCounter
        local showDc = cfg.overlayDeathCounter == true and key == "Bald" and hasDeathCounter(model)
        dc.Visible = showDc
        if showDc then
            dc.Text = "Death Counter"
        end
        bb.Enabled = showChar or showBar or showUlted or showDc
    end

    local function startOverlay()
        stopOverlay()
        local gui = ensureOverlayGui()
        if not gui then
            return
        end
        local boards = {}
        local highlights = {}
        runtime.overlayConn = RunService.Heartbeat:Connect(function()
            if runtime.destroyed then
                return
            end
            local seen = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local model = plr.Character
                    local head = model and (model:FindFirstChild("Head") or charRoot(model))
                    if model and head then
                        seen[model] = true
                        local bb = boards[model]
                        if not (bb and bb.Parent) then
                            bb = makeBoard(gui)
                            boards[model] = bb
                        end
                        bb.Adornee = head
                        fitBoard(bb, head)
                        paintBoard(bb, model)
                        paintOutline(model, highlights)
                    end
                end
            end
            for model, bb in pairs(boards) do
                if not seen[model] then
                    boards[model] = nil
                    if bb then
                        pcall(function()
                            bb:Destroy()
                        end)
                    end
                end
            end
            for model, hl in pairs(highlights) do
                if not seen[model] then
                    highlights[model] = nil
                    if hl then
                        pcall(function()
                            hl:Destroy()
                        end)
                    end
                end
            end
        end)
    end

    runtime.antiStart = startAnti
    runtime.antiStop = stopAnti
    runtime.overlayStart = startOverlay
    runtime.overlayStop = stopOverlay
end
miscSetup()

local function holdingGrab()
    return os.clock() < (runtime.holdParkUntil or 0)
end

local function hasTarget(model)
    if not model then
        return false
    end
    if cfg.skipDeathCounter and hasDeathCounter(model) then
        return false
    end
    if isValidTarget(model) then
        return true
    end
    if model ~= runtime.target or not model.Parent or not charRoot(model) then
        return false
    end
    if holdingGrab() then
        return true
    end
    return model:FindFirstChild("RootAnchor") ~= nil or model:FindFirstChild("BeingGrabbed") ~= nil
end

local function selectedSet()
    local set = {}
    local names = cfg.selectedNames
    if type(names) == "table" then
        if names[1] ~= nil then
            for _, n in ipairs(names) do
                set[n] = true
            end
        else
            for n, v in pairs(names) do
                if v == true then
                    set[n] = true
                end
            end
        end
    end
    return set
end

local function targetDistance(model)
    local myRoot = charRoot(liveChar() or LocalPlayer.Character)
    local root = charRoot(model)
    if not myRoot or not root then
        return math.huge
    end
    return (myRoot.Position - root.Position).Magnitude
end

local function pickTarget(current)
    if current and hasTarget(current) then
        if holdingGrab() or current:FindFirstChild("RootAnchor") or current:FindFirstChild("BeingGrabbed") then
            return current
        end
        if cfg.targetMode ~= "Selected" then
            return current
        end
        local sel = selectedSet()
        local plr = Players:GetPlayerFromCharacter(current)
        if next(sel) == nil or (plr and sel[plr.Name]) or sel[current.Name] then
            return current
        end
    end
    local live = liveFolder() or Workspace
    local best, bestDist, bestHp, bestName, bestId
    local sel = selectedSet()
    local useSel = cfg.targetMode == "Selected" and next(sel) ~= nil
    for _, model in ipairs(live:GetChildren()) do
        if isValidTarget(model) then
            local plr = Players:GetPlayerFromCharacter(model)
            if not useSel or (plr and sel[plr.Name]) or sel[model.Name] then
                local dist = targetDistance(model)
                local hum = charHum(model)
                local hp = hum and hum.Health or math.huge
                local name = plr and plr.Name or model.Name
                local id = plr and plr.UserId or 0
                local better = false
                if not best then
                    better = true
                elseif cfg.targetMode == "Lowest HP" then
                    if hp < bestHp or (hp == bestHp and dist < bestDist) then
                        better = true
                    end
                elseif dist < bestDist then
                    better = true
                elseif dist == bestDist and (name < bestName or (name == bestName and id < bestId)) then
                    better = true
                end
                if better then
                    best = model
                    bestDist = dist
                    bestHp = hp
                    bestName = name
                    bestId = id
                end
            end
        end
    end
    return best
end

local function groundSurfaceY(targetRoot)
    local origin = targetRoot.Position + Vector3.new(0, 8, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    local live = liveFolder()
    if live then
        table.insert(ignore, live)
    end
    local me = liveChar() or LocalPlayer.Character
    if me then
        table.insert(ignore, me)
    end
    params.FilterDescendantsInstances = ignore
    local hit = Workspace:Raycast(origin, Vector3.new(0, -180, 0), params)
    if hit then
        return hit.Position.Y
    end
    return targetRoot.Position.Y - 3
end

local function underCFrame(targetRoot)
    local pos = targetRoot.Position
    local floorY = groundSurfaceY(targetRoot)
    if pos.Y < SAFE_Y or floorY < SAFE_Y then
        floorY = runtime.lastGroundY
        if type(floorY) ~= "number" or floorY < SAFE_Y then
            floorY = 438
        end
    end
    local y = floorY - cfg.depth
    if pos.Y >= SAFE_Y and y > pos.Y - 3 then
        y = pos.Y - 3
    end
    if y < -400 then
        y = -400
    end
    local from = Vector3.new(pos.X, y, pos.Z)
    local lv = targetRoot.CFrame.LookVector
    local up = Vector3.new(lv.X, 0, lv.Z)
    if up.Magnitude < 0.05 then
        up = Vector3.new(0, 0, -1)
    else
        up = up.Unit
    end
    local at = pos
    if pos.Y < SAFE_Y then
        at = Vector3.new(pos.X, floorY, pos.Z)
    end
    if (at - from).Magnitude < 0.05 then
        at = from + Vector3.new(0, 1, 0)
    end
    return CFrame.lookAt(from, at, up)
end

local function restoreLocalLook(char)
    char = char or liveChar() or LocalPlayer.Character
    if not char then
        runtime.humDisplay = nil
        runtime.savedTrans = {}
        return
    end
    local hum = charHum(char)
    if hum and runtime.humDisplay ~= nil then
        pcall(function()
            hum.DisplayDistanceType = runtime.humDisplay
        end)
    end
    runtime.humDisplay = nil
    for d, trans in pairs(runtime.savedTrans) do
        if typeof(d) == "Instance" and d.Parent then
            pcall(function()
                d.Transparency = trans
                if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
                    d.LocalTransparencyModifier = 0
                end
            end)
        end
    end
    runtime.savedTrans = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
            d.LocalTransparencyModifier = 0
        end
    end
end

local function animIdPlaying(char, id)
    local hum = charHum(char)
    if not hum or not id then
        return false
    end
    local tracks
    local ok = pcall(function()
        tracks = hum:GetPlayingAnimationTracks()
    end)
    if not ok or type(tracks) ~= "table" then
        return false
    end
    for _, tr in ipairs(tracks) do
        local anim = tr.Animation
        local sid = anim and anim.AnimationId
        if type(sid) == "string" and tonumber(string.match(sid, "%d+")) == id then
            return true
        end
    end
    return false
end

local function skipM1(char)
    if not char then
        return false
    end
    if animIdPlaying(char, HEAD_FIRST_ANIM) or animIdPlaying(char, VK_ANIM) then
        return true
    end
    return animIdPlaying(char, BARRAGE_ANIM) or animIdPlaying(char, BARRAGE_FINISHER)
end

local function arenaFloorY(targetRoot)
    local fallback = runtime.lastGroundY
    if type(fallback) ~= "number" or fallback < SAFE_Y then
        fallback = 438
    end
    if not targetRoot then
        return fallback
    end
    local y = targetRoot.Position.Y
    if y < SAFE_Y then
        return fallback
    end
    local g = groundSurfaceY(targetRoot)
    if g >= SAFE_Y then
        runtime.lastGroundY = g
        return g
    end
    runtime.lastGroundY = y
    return y
end

-- Grab VFX lerps victim Y to the caster. Keep them on the arena; stay under yourself.
local function pinVictimFloor(target)
    local tRoot = charRoot(target)
    if not tRoot then
        return
    end
    local y = tRoot.Position.Y
    if y >= SAFE_Y then
        runtime.lastStandY = y
    end
    local floorY = arenaFloorY(tRoot)
    if y >= floorY - 0.5 then
        return
    end
    local standY = runtime.lastStandY
    if type(standY) ~= "number" or standY < floorY then
        standY = floorY + 3
    end
    local lift = standY - y
    pcall(function()
        target:PivotTo(target:GetPivot() + Vector3.new(0, lift, 0))
        local v = tRoot.AssemblyLinearVelocity
        tRoot.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0), v.Z)
        tRoot.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function parkUnder(target)
    if runtime.fangBusy then
        return
    end
    pinVictimFloor(target)
    local char = liveChar() or LocalPlayer.Character
    local root = charRoot(char)
    local tRoot = charRoot(target)
    if not char or not root or not tRoot then
        return
    end
    if runtime.surfaceCast then
        restoreParkBody(char)
        if runtime.whirlPhase == "play" then
            if root.Position.Y < 420 then
                killMovers(char)
                local cf = onGroundCFrame(tRoot)
                pcall(function()
                    char:PivotTo(cf)
                    root.CFrame = cf
                end)
            end
            return
        end
        local cf = onGroundCFrame(tRoot)
        pcall(function()
            char:PivotTo(cf)
            root.CFrame = cf
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        local hum = charHum(char)
        runtime.whirlPlanted = hum
            and hum.FloorMaterial ~= Enum.Material.Air
            and math.abs(root.Position.Y - tRoot.Position.Y) < 8
        return
    end
    killMovers(char)
    sinkParkBody(char)
    local cf = underCFrame(tRoot)
    pcall(function()
        char:PivotTo(cf)
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function fangPlaying(char)
    return animIdPlaying(char, TWIN_FANG_ANIM) or animIdPlaying(char, TWIN_FANGS2_ANIM)
end

local function fangTrack(char)
    local hum = charHum(char)
    if not hum then
        return nil
    end
    local tracks
    local ok = pcall(function()
        tracks = hum:GetPlayingAnimationTracks()
    end)
    if not ok or type(tracks) ~= "table" then
        return nil
    end
    for _, tr in ipairs(tracks) do
        local anim = tr.Animation
        local sid = anim and anim.AnimationId
        local id = type(sid) == "string" and tonumber(string.match(sid, "%d+"))
        if id == TWIN_FANG_ANIM or id == TWIN_FANGS2_ANIM then
            return tr
        end
    end
    return nil
end

local function fangNearEnd(char)
    local tr = fangTrack(char)
    if not tr then
        return false
    end
    local len, pos
    pcall(function()
        len = tr.Length
        pos = tr.TimePosition
    end)
    return type(len) == "number" and len > 0 and type(pos) == "number" and pos > len - 0.55
end

local function fangVictims()
    local live = liveFolder()
    local out = {}
    if not live then
        return out
    end
    for _, model in ipairs(live:GetChildren()) do
        if isValidTarget(model) then
            table.insert(out, model)
        end
    end
    return out
end

-- PlayerGui UnreliableRemoteEvent "*replicatemovement*": CharacterHandler Heartbeat FireServer(HRP.CFrame)
local function movementRemote()
    local cached = runtime.moveRep
    if cached and cached.Parent then
        return cached
    end
    runtime.moveRep = nil
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then
        return nil
    end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("UnreliableRemoteEvent") and string.find(string.lower(d.Name), "replicatemovement", 1, true) then
            runtime.moveRep = d
            return d
        end
    end
    return nil
end

local function clearFangAlign()
    local align = runtime.fangAlign
    local a0 = runtime.fangAtt0
    local a1 = runtime.fangAtt1
    runtime.fangAlign = nil
    runtime.fangAtt0 = nil
    runtime.fangAtt1 = nil
    if align then
        pcall(function()
            align:Destroy()
        end)
    end
    if a0 then
        pcall(function()
            a0:Destroy()
        end)
    end
    if a1 then
        pcall(function()
            a1:Destroy()
        end)
    end
end

local function bindFangAlign(root, cf)
    if not root or typeof(cf) ~= "CFrame" then
        return
    end
    local att0 = runtime.fangAtt0
    local att1 = runtime.fangAtt1
    local align = runtime.fangAlign
    if not att0 or att0.Parent ~= root then
        clearFangAlign()
        att0 = Instance.new("Attachment")
        att0.Name = "DougysFangA0"
        att0.Parent = root
        att1 = Instance.new("Attachment")
        att1.Name = "DougysFangA1"
        att1.Parent = Workspace.Terrain
        align = Instance.new("AlignPosition")
        align.Name = "DougysFangAlign"
        align.Mode = Enum.PositionAlignmentMode.TwoAttachment
        align.RigidityEnabled = true
        align.ReactionForceEnabled = false
        align.ApplyAtCenterOfMass = true
        align.MaxAxesForce = Vector3.new(1e9, 1e9, 1e9)
        align.MaxVelocity = 1e9
        align.Responsiveness = 200
        align.Attachment0 = att0
        align.Attachment1 = att1
        align.Parent = root
        runtime.fangAtt0 = att0
        runtime.fangAtt1 = att1
        runtime.fangAlign = align
    end
    att1.WorldCFrame = cf
end

local function sendLiveCFrame(cf)
    if typeof(cf) ~= "CFrame" then
        return
    end
    local now = Workspace:GetServerTimeNow()
    local seq = 0
    if type(shared) == "table" then
        shared._cmSeq = (shared._cmSeq or 0) + 1
        seq = shared._cmSeq
        if type(shared.livecframes) ~= "table" then
            shared.livecframes = {}
        end
        shared.livecframes[LocalPlayer] = cf
        if type(shared.ClientData) ~= "table" then
            shared.ClientData = {}
        end
        shared.ClientData[LocalPlayer] = {
            cframe = cf,
            falling = false,
            velY = 0,
            running = true,
            holdingSpace = false,
            seq = seq,
            clientT = now,
            serverReceivedAt = now,
        }
    end
    local payload = {
        cframe = cf,
        falling = false,
        velY = 0,
        running = true,
        holdingSpace = false,
        seq = seq,
        clientT = now,
    }
    local ure = ReplicatedStorage:FindFirstChild("UnreliableRemoteEvent")
    if ure then
        pcall(function()
            ure:FireServer(cf)
        end)
        pcall(function()
            ure:FireServer(payload, "CustomMoveStun")
        end)
    end
    local rem = movementRemote()
    if rem then
        pcall(function()
            rem:FireServer(cf)
        end)
    end
    local root = charRoot(liveChar() or LocalPlayer.Character)
    if root then
        pcall(function()
            root:SetAttribute("TweenId", math.random(1, 2000000000))
        end)
    end
end

local function applyFangCf(cf)
    if typeof(cf) ~= "CFrame" then
        return false
    end
    runtime.fangCf = cf
    local char = liveChar() or LocalPlayer.Character
    local root = charRoot(char)
    if not char or not root then
        return false
    end
    pcall(function()
        root.Anchored = false
        char:PivotTo(cf)
        root.CFrame = cf
        local freeze = char:FindFirstChild("Freeze")
        if freeze and freeze:GetAttribute("CustomMoveStun") ~= true then
            freeze:SetAttribute("CustomMoveStun", true)
        end
    end)
    bindFangAlign(root, cf)
    return true
end

local function replicatePivot(cf)
    if not applyFangCf(cf) then
        return false
    end
    runtime.fangSent = cf
    sendLiveCFrame(cf)
    return true
end

local function fangOriginCf(char)
    if type(shared) == "table" and type(shared.livecframes) == "table" then
        local lc = shared.livecframes[LocalPlayer]
        if typeof(lc) == "CFrame" and lc.Position.Y >= SAFE_Y then
            return lc
        end
    end
    if typeof(runtime.safeCFrame) == "CFrame" then
        return runtime.safeCFrame
    end
    local root = charRoot(char)
    if root and root.Position.Y >= SAFE_Y then
        return root.CFrame
    end
    local tRoot = charRoot(runtime.target)
    if tRoot and tRoot.Position.Y >= SAFE_Y then
        return tRoot.CFrame * CFrame.new(0, 0, 3)
    end
    return root and root.CFrame
end

local function stepCf(fromCf, toCf, step)
    if typeof(fromCf) ~= "CFrame" then
        return toCf, true
    end
    local delta = toCf.Position - fromCf.Position
    local maxStep = step or FANG_STEP
    if delta.Magnitude <= maxStep then
        return toCf, true
    end
    return fromCf + delta.Unit * maxStep, false
end

local function travelTo(goalCf, keepGoing, step)
    if typeof(goalCf) ~= "CFrame" then
        return false
    end
    local arrived = false
    while not runtime.destroyed and not arrived do
        if keepGoing and not keepGoing() then
            return false
        end
        runtime.fangSent, arrived = stepCf(runtime.fangSent, goalCf, step)
        replicatePivot(runtime.fangSent)
        task.wait()
    end
    return arrived
end

local function ensureFangRep(char)
    if not char then
        return
    end
    if not runtime.fangStopTween or not runtime.fangStopTween.Parent then
        local folder = Instance.new("Folder")
        folder.Name = "StopTween"
        folder.Parent = char
        runtime.fangStopTween = folder
    end
    local freeze = char:FindFirstChild("Freeze")
    if freeze then
        freeze:SetAttribute("CustomMoveStun", true)
        freeze:SetAttribute("NoStop", true)
    end
end

local function clearFangStop()
    local folder = runtime.fangStopTween
    runtime.fangStopTween = nil
    if folder then
        pcall(function()
            folder:Destroy()
        end)
    end
end

local function dunkCf(fromCf)
    if typeof(fromCf) ~= "CFrame" then
        return fromCf
    end
    local p = fromCf.Position
    local pos = Vector3.new(p.X, FANG_STAND_Y, p.Z)
    return CFrame.lookAt(pos, pos + Vector3.new(0, -1, 0), Vector3.new(0, 0, -1))
end

local function anyoneGrabbed()
    local me = liveChar() or LocalPlayer.Character
    local live = liveFolder()
    if not live then
        return false
    end
    for _, model in ipairs(live:GetChildren()) do
        if model ~= me and model:FindFirstChild("BeingGrabbed") then
            return true
        end
    end
    return false
end

local function grabCf(model)
    local tRoot = charRoot(model)
    if not tRoot then
        return nil
    end
    return tRoot.CFrame * CFrame.new(0, 0, 3)
end

local function pivotOnto(model, keepGoing)
    local cf = grabCf(model)
    if not cf then
        return false
    end
    return travelTo(cf, keepGoing)
end

local function fangReturnUp()
    runtime.fangVoiding = false
    local char = liveChar() or LocalPlayer.Character
    local root = charRoot(char)
    local hum = charHum(char)
    pcall(function()
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            if hum.Health <= 0 then
                hum.Health = hum.MaxHealth
            end
        end
    end)
    restoreParkBody(char)
    clearFangAlign()
    clearFangStop()
    local live = liveFolder()
    local me = char
    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model ~= me then
                local hum = charHum(model)
                local tRoot = charRoot(model)
                if hum and tRoot and hum.Health > 0 and tRoot.Position.Y < SAFE_Y then
                    pinVictimFloor(model)
                end
            end
        end
    end
    local dest = runtime.safeCFrame
    if cfg.idlePad then
        local plat = ensureIdlePlatform()
        if plat then
            dest = plat.CFrame * CFrame.new(0, 5, 0)
        end
    end
    if typeof(dest) == "CFrame" and typeof(runtime.fangSent) == "CFrame" then
        travelTo(dest)
        clearFangAlign()
        runtime.fangSent = nil
        return
    end
    restoreSafe()
end

local function runFangDeath()
    runtime.fangBusy = true
    runtime.fangVoiding = false
    local didVoid = false
    local function stillFang()
        if runtime.destroyed or not cfg.twinFangDeath then
            return false
        end
        return fangPlaying(liveChar() or LocalPlayer.Character)
    end
    pcall(function()
        local char = liveChar() or LocalPlayer.Character
        ensureFangRep(char)
        local origin = fangOriginCf(char)
        if typeof(origin) ~= "CFrame" then
            return
        end
        runtime.fangSent = origin
        replicatePivot(origin)
        local hopped = false
        local started = os.clock()
        local voidAt = started + TWIN_FANG_VOID_WAIT
        local shiftAt = voidAt - TWIN_FANG_KILL_LEAD
        local function beforeShift()
            return stillFang() and os.clock() < shiftAt
        end
        local hit = 0
        while beforeShift() do
            if fangNearEnd(liveChar() or LocalPlayer.Character) then
                break
            end
            local victims = fangVictims()
            if #victims == 0 then
                if not hopped then
                    return
                end
                break
            end
            hopped = pivotOnto(victims[(hit % #victims) + 1], beforeShift) or hopped
            hit = hit + 1
            local waitUntil = os.clock() + TWIN_FANG_TP_WAIT
            if waitUntil > shiftAt then
                waitUntil = shiftAt
            end
            while os.clock() < waitUntil and not runtime.destroyed do
                task.wait()
            end
        end
        if not hopped then
            return
        end
        if not stillFang() and not fangNearEnd(liveChar() or LocalPlayer.Character) then
            return
        end
        char = liveChar() or LocalPlayer.Character
        local root = charRoot(char)
        local hum = charHum(char)
        if not char or not root or typeof(runtime.fangSent) ~= "CFrame" then
            return
        end
        didVoid = true
        sinkParkBody(char)
        pcall(function()
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            end
        end)
        local sent = runtime.fangSent
        travelTo(sent + Vector3.new(0, FANG_BOX_SHIFT, 0), function()
            return not runtime.destroyed
        end, FANG_STEP)
        replicatePivot(dunkCf(runtime.fangSent or sent))
        runtime.fangVoiding = true
        local minUntil = os.clock() + 0.5
        while not runtime.destroyed and cfg.twinFangDeath do
            if not fangPlaying(liveChar() or LocalPlayer.Character) and os.clock() >= minUntil then
                break
            end
            task.wait()
        end
        local extra = os.clock() + 0.45
        while os.clock() < extra and not runtime.destroyed do
            task.wait()
        end
        local untilGrab = os.clock() + 2
        while os.clock() < untilGrab and not runtime.destroyed and anyoneGrabbed() do
            task.wait()
        end
        task.wait(0.25)
    end)
    if didVoid then
        fangReturnUp()
    else
        runtime.fangVoiding = false
        clearFangStop()
    end
    runtime.fangBusy = false
    runtime.fangCf = nil
    runtime.fangSent = nil
    clearFangAlign()
end

local function playerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    table.sort(names)
    if #names == 0 then
        table.insert(names, "(no players)")
    end
    return names
end

local function refreshPlayerDrop()
    local opts = playerNames()
    runtime.dropSyncing = true
    pcall(function()
        if playerDrop and playerDrop.SetOptions then
            playerDrop:SetOptions(opts)
            if playerDrop.Set then
                playerDrop:Set(intersectVisible(cfg.selectedNames, opts))
            end
        end
    end)
    runtime.dropSyncing = false
end

local function snapshotLine()
    local char = liveChar() or LocalPlayer.Character
    local root = charRoot(char)
    local t = runtime.target
    local tRoot = charRoot(t)
    return string.format(
        "on=%s gen=%d me=%s y=%.1f target=%s ty=%.1f mode=%s depth=%s gap=%s dummy=%s purple=%s",
        tostring(runtime.enabled),
        runtime.workGen,
        tostring(moveset(char)),
        root and root.Position.Y or 0,
        tostring(t and t.Name or "-"),
        tRoot and tRoot.Position.Y or 0,
        tostring(cfg.targetMode),
        tostring(cfg.depth),
        tostring(cfg.attackGap),
        tostring(cfg.includeDummies),
        tostring(moveset(char) == MA_KEY)
    )
end

local function runAttack(gen)
    debugReport("loop", debugEnabled and ("start " .. snapshotLine()))
    runtime.moveIdx = 0
    while still(gen) do
        local nextTarget = pickTarget(runtime.target)
        if nextTarget ~= runtime.target then
            runtime.target = nextTarget
            debugReport("target", tostring(nextTarget and nextTarget.Name or "none"))
        end
        if not nextTarget then
            goIdlePlatform()
            if not runtime.waitingTarget then
                runtime.waitingTarget = true
                notify("Waiting for a valid target")
                debugReport("idle", "no target")
            end
        else
            runtime.waitingTarget = false
            local root = charRoot(nextTarget)
            local char = liveChar() or LocalPlayer.Character
            if cfg.autoUlt then
                fireUlt(gen)
            end
            if root then
                local moves = selectedMoveList()
                local ulted = char and char:GetAttribute("Ulted") == true
                local skills = {}
                local wantWhirl = false
                for _, name in ipairs(moves) do
                    if name == "Whirlwind Drop" then
                        wantWhirl = true
                    elseif name ~= "M1" then
                        table.insert(skills, name)
                    end
                end
                if wantWhirl and os.clock() - runtime.lastWhirlAt >= WHIRL_GAP_S and not moveOnCooldown("Whirlwind Drop") then
                    fireSkill(gen, "Whirlwind Drop", root)
                end
                if #skills > 0 then
                    local fired = false
                    for _ = 1, #skills do
                        runtime.moveIdx = (runtime.moveIdx % #skills) + 1
                        local name = skills[runtime.moveIdx]
                        if not (runtime.ultNameSet[name] and not ulted) then
                            fired = fireSkill(gen, name, root)
                        end
                        if fired then
                            break
                        end
                    end
                end
            end
        end
        task.wait(SCAN_DT)
    end
    debugReport("loop", "stop")
end

local function startFeature()
    runtime.shutdown = false
    runtime.enabled = true
    runtime.workGen = runtime.workGen + 1
    runtime.waitingTarget = false
    captureSafe()
    local gen = runtime.workGen
    debugReport("toggle", debugEnabled and ("on " .. snapshotLine()))
    notify("Invisible Auto Attack on")
    kitMoves()
    refreshMoveDrop()
    if cfg.spectateTarget then
        bindSpectate()
    end
    task.spawn(function()
        if cfg.autoPurple then
            local ok = requestPurple(gen)
            if still(gen) and not ok then
                notify("Martial Artist switch failed, attacking anyway")
                debugReport("char", "switch failed, continue")
            end
        end
        kitMoves()
        refreshMoveDrop()
        if still(gen) then
            runAttack(gen)
        end
    end)
end

local function stopFeature(announce)
    runtime.enabled = false
    runtime.shutdown = true
    runtime.workGen = runtime.workGen + 1
    runtime.holdParkUntil = 0
    releaseHeld()
    restoreCamera()
    restoreLocalLook()
    restoreParkBody()
    restoreSafe()
    destroyIdlePlatform()
    runtime.target = nil
    runtime.waitingTarget = false
    debugReport("toggle", "off")
    if announce then
        notify("Invisible Auto Attack stopped")
    end
end

connect(RunService.Heartbeat:Connect(function()
    if runtime.fangVoiding then
        local char = liveChar() or LocalPlayer.Character
        local hum = charHum(char)
        local sent = runtime.fangSent or runtime.fangCf
        if typeof(sent) == "CFrame" then
            replicatePivot(dunkCf(sent))
        end
        if hum and hum.Health <= 0 then
            pcall(function()
                hum.Health = hum.MaxHealth
            end)
        end
    elseif runtime.fangBusy and runtime.fangCf then
        replicatePivot(runtime.fangCf)
    end
    if cfg.twinFangDeath and not runtime.destroyed and not runtime.fangBusy then
        if fangPlaying(liveChar() or LocalPlayer.Character) then
            runtime.fangBusy = true
            task.spawn(runFangDeath)
        end
    end
    if not runtime.enabled or runtime.shutdown or runtime.fangBusy then
        return
    end
    local t = runtime.target
    if t and hasTarget(t) then
        parkUnder(t)
        if wantsM1() and not runtime.surfaceCast then
            local me = liveChar() or LocalPlayer.Character
            if not skipM1(me) then
                fireM1(runtime.workGen, charRoot(t))
            end
        end
        task.defer(function()
            if runtime.fangBusy or not runtime.enabled or runtime.shutdown or runtime.target ~= t then
                return
            end
            pinVictimFloor(t)
        end)
    else
        restoreParkBody()
        goIdlePlatform()
    end
end))
pcall(function()
    RunService:BindToRenderStep(PARK_BIND, 1000, function()
        if not runtime.enabled or runtime.shutdown or runtime.fangBusy then
            return
        end
        local t = runtime.target
        if t and hasTarget(t) then
            parkUnder(t)
        else
            restoreParkBody()
            goIdlePlatform()
        end
    end)
end)
pcall(function()
    RunService:BindToRenderStep(FANG_BIND, Enum.RenderPriority.Last.Value + 1, function()
        if not runtime.fangBusy or not runtime.fangCf then
            return
        end
        local cf = runtime.fangCf
        if runtime.fangVoiding then
            cf = dunkCf(runtime.fangSent or cf)
        end
        applyFangCf(cf)
    end)
end)
connect(RunService.Stepped:Connect(function()
    if runtime.fangBusy and runtime.fangCf then
        local cf = runtime.fangCf
        if runtime.fangVoiding then
            cf = dunkCf(runtime.fangSent or cf)
        end
        applyFangCf(cf)
    end
    if not runtime.enabled or runtime.shutdown or runtime.fangBusy then
        return
    end
    local t = runtime.target
    if t and hasTarget(t) then
        parkUnder(t)
    end
end))

connect(Players.PlayerAdded:Connect(function()
    task.defer(refreshPlayerDrop)
end))
connect(Players.PlayerRemoving:Connect(function(plr)
    runtime.friendCache[plr.UserId] = nil
    task.defer(refreshPlayerDrop)
end))

-- AnimationBank.Emotes. Off = vanilla M1s. Loop uses Animator (not Communicate Emote; that stuns).
local NUCLEAR_VICTIM_ID = 85477175411484
local NUCLEAR_INVIS_T = 9.6
local ANIM_NAMES = { "Off", "Box Idle", "Electric", "Square Up", "Rest Idle", "Sincere Apology" }
local ANIM_IDS = {
    ["Box Idle"] = 17122254184,
    ["Electric"] = 101532381158436,
    ["Square Up"] = 95561134536060,
    ["Rest Idle"] = 15443688094,
    ["Sincere Apology"] = 118382652729061,
}
local m1Ids = {}
local function eatAnimIds(v)
    if type(v) == "number" then
        m1Ids[v] = true
    elseif type(v) == "table" then
        for _, x in pairs(v) do
            eatAnimIds(x)
        end
    end
end
if Info and Info.BaseM1 then
    eatAnimIds(Info.BaseM1)
end

local SIDE_DASH_IDS = {
    [10480793962] = true,
    [10480796021] = true,
}
local DASH_IDS = {
    [10491993682] = true,
}
if Info and type(Info.DodgeAnimations) == "table" then
    for _, id in pairs(Info.DodgeAnimations) do
        if type(id) == "number" then
            DASH_IDS[id] = true
        end
    end
end
local WALK_IDS = {
    [7815618175] = true,
    [84022163849541] = true,
    [131585091153240] = true,
    [79741533269101] = true,
}

local function selectedAnimId()
    if cfg.toggleInvis then
        return NUCLEAR_VICTIM_ID
    end
    return ANIM_IDS[runtime.animPick]
end

local function isWalkish(n, track)
    if n and WALK_IDS[n] then
        return true
    end
    if not track then
        return false
    end
    local p = track.Priority
    return p == Enum.AnimationPriority.Idle or p == Enum.AnimationPriority.Core or p == Enum.AnimationPriority.Movement
end

-- ponytail: clip dropdown is the asset; Loop / Override all actually apply it to combat
local function overlayAttacks()
    if cfg.toggleInvis then
        return true
    end
    return selectedAnimId() ~= nil and (runtime.loopAnim or runtime.animAll)
end

local function shouldSwap(n, track)
    local want = selectedAnimId()
    if not want or not n or n == want then
        return false
    end
    if cfg.toggleInvis then
        return true
    end
    if SIDE_DASH_IDS[n] then
        return runtime.animSideDash == true
    end
    if DASH_IDS[n] then
        return false
    end
    if isWalkish(n, track) then
        return runtime.animWalk == true
    end
    if runtime.animAll then
        return true
    end
    if runtime.loopAnim then
        return m1Ids[n] == true
    end
    return false
end

local function idFromAnim(anim)
    if typeof(anim) == "number" then
        return anim
    end
    if typeof(anim) == "string" then
        return tonumber(string.match(anim, "%d+"))
    end
    if typeof(anim) == "Instance" then
        return tonumber(string.match(anim.AnimationId or "", "%d+"))
    end
    return nil
end

local function animLib(char)
    local ch = char and char:FindFirstChild("CharacterHandler")
    local mod = ch and ch:FindFirstChild("AnimationPlayer")
    if not mod then
        return nil
    end
    local ok, lib = pcall(require, mod)
    if ok and type(lib) == "table" then
        return lib
    end
    return nil
end

local function isRealTrack(t)
    return typeof(t) == "Instance" and t:IsA("AnimationTrack")
end

local function trackOnHum(t, hum)
    if not isRealTrack(t) or not hum then
        return false
    end
    local ok = false
    pcall(function()
        local anim = t.Animator
        ok = anim ~= nil and anim.Parent == hum
    end)
    return ok
end

local function charBusy(char)
    return not char or char:FindFirstChild("Ragdoll") or char:FindFirstChild("FinalDeath")
end

-- AnimationPlayer returns a dummy table (always IsPlaying) on ragdoll / missing humanoid
local function playCustom(id, _, char)
    if not id then
        return nil
    end
    char = char or liveChar() or LocalPlayer.Character
    local hum = charHum(char)
    if not hum or hum.Health <= 0 or charBusy(char) then
        return nil
    end
    local tr
    pcall(function()
        local lib = animLib(char)
        if not (lib and lib.playAnimation) then
            return
        end
        tr = lib.playAnimation(hum, id)
        if not isRealTrack(tr) then
            tr = nil
            return
        end
        tr.Looped = true
        tr.Priority = Enum.AnimationPriority.Action4
        tr:AdjustWeight(1, 0)
        tr:Play(0)
    end)
    if not isRealTrack(tr) then
        return nil
    end
    return tr
end

local function preloadAnims()
    local char = liveChar() or LocalPlayer.Character
    local lib = animLib(char)
    local hum = charHum(char)
    local want = selectedAnimId()
    if not (lib and hum) then
        return
    end
    local ids = {
        [NUCLEAR_VICTIM_ID] = true,
    }
    for _, id in pairs(ANIM_IDS) do
        ids[id] = true
    end
    for id in pairs(ids) do
        if id ~= want then
            pcall(function()
                local tr = lib.playAnimation(hum, id)
                if isRealTrack(tr) then
                    tr:Play(0)
                    tr:Stop(0)
                end
            end)
        end
    end
end

local function stopClipLoop()
    pcall(function()
        RunService:UnbindFromRenderStep(CLIP_BIND)
    end)
end

local function startClipLoop(track)
    if not track then
        return
    end
    local a = tonumber(runtime.animClipFrom) or 0
    local b = tonumber(runtime.animClipTo) or 0
    if cfg.toggleInvis then
        a = NUCLEAR_INVIS_T
        b = NUCLEAR_INVIS_T
    end
    local freeze = a == b and a > 0
    local window = b > a
    local key = string.format("%.2f:%.2f:%s", a, b, freeze and "f" or (window and "w" or "n"))
    if runtime.clipKey == key and runtime.loopTrack == track then
        return
    end
    stopClipLoop()
    runtime.clipKey = key
    if not freeze and not window then
        pcall(function()
            track.Looped = true
            track:AdjustSpeed(1)
        end)
        return
    end
    local from = a
    local to = freeze and (a + 0.03) or b
    pcall(function()
        track.Looped = true
        track:AdjustSpeed(1)
        track.TimePosition = from
    end)
    RunService:BindToRenderStep(CLIP_BIND, 2000, function()
        if runtime.destroyed then
            stopClipLoop()
            return
        end
        pcall(function()
            if not track.IsPlaying then
                local now = os.clock()
                if now >= (runtime.poseRetryAt or 0) then
                    runtime.poseRetryAt = now + 0.25
                    track.Looped = true
                    track:Play(0)
                    track.TimePosition = from
                end
                return
            end
            local p = track.TimePosition
            if p >= to or p < from - 0.01 then
                track.TimePosition = from
            end
        end)
    end)
end

local function stopLoopAnim()
    stopClipLoop()
    runtime.clipKey = nil
    local t = runtime.loopTrack
    runtime.loopTrack = nil
    if isRealTrack(t) then
        pcall(function()
            t:Stop(0.1)
        end)
    end
end

local function ensurePose()
    local id = selectedAnimId()
    if not id or runtime.destroyed then
        return nil
    end
    local char = liveChar() or LocalPlayer.Character
    local hum = charHum(char)
    if not hum or hum.Health <= 0 or charBusy(char) then
        return nil
    end
    local t = runtime.loopTrack
    local same = false
    pcall(function()
        same = trackOnHum(t, hum) and idFromAnim(t.Animation) == id
    end)
    if same then
        pcall(function()
            t.Looped = true
            t.Priority = Enum.AnimationPriority.Action4
            t:AdjustWeight(1, 0)
            if not t.IsPlaying then
                t:Play(0)
            end
        end)
        return t
    end
    if t then
        stopLoopAnim()
    end
    runtime.loopTrack = playCustom(id, true, char)
    startClipLoop(runtime.loopTrack)
    return runtime.loopTrack
end

local function startLoopAnim()
    if runtime.destroyed or not selectedAnimId() then
        return
    end
    if not runtime.loopAnim and not cfg.toggleInvis then
        return
    end
    ensurePose()
end

local function finishOverride(gen)
    if runtime.destroyed or runtime.overrideGen ~= gen then
        return
    end
    if runtime.loopAnim or cfg.toggleInvis then
        startLoopAnim()
    else
        stopLoopAnim()
    end
end

local function holdPose(origTrack)
    if runtime.destroyed or not selectedAnimId() then
        return
    end
    ensurePose()
    runtime.overrideGen = runtime.overrideGen + 1
    local gen = runtime.overrideGen
    if origTrack then
        pcall(function()
            if runtime.loopAnim or cfg.toggleInvis then
                origTrack:Stop(0)
            else
                origTrack:AdjustWeight(0.001, 0)
            end
        end)
        local conn
        conn = origTrack.Stopped:Connect(function()
            if conn then
                conn:Disconnect()
            end
            finishOverride(gen)
        end)
        if conn then
            table.insert(runtime.charConns, conn)
        end
    end
end

local function bindAnimChar(char)
    local hum = charHum(char)
    if not hum then
        return
    end
    disconnectList(runtime.charConns)
    if not trackOnHum(runtime.loopTrack, hum) then
        stopLoopAnim()
    end
    table.insert(runtime.charConns, hum.Died:Connect(function()
        stopLoopAnim()
    end))
    preloadAnims()
    local function resumeLoopAfter(track)
        if not runtime.loopAnim and not cfg.toggleInvis then
            return
        end
        local conn
        conn = track.Stopped:Connect(function()
            if conn then
                conn:Disconnect()
            end
            if runtime.loopAnim or cfg.toggleInvis then
                startLoopAnim()
            end
        end)
        if conn then
            table.insert(runtime.charConns, conn)
        end
    end
    table.insert(runtime.charConns, hum.AnimationPlayed:Connect(function(track)
        if not selectedAnimId() or runtime.destroyed or not track then
            return
        end
        local n = idFromAnim(track.Animation)
        if track == runtime.loopTrack then
            return
        end
        if SIDE_DASH_IDS[n] then
            if runtime.animSideDash or cfg.toggleInvis then
                holdPose(track)
            else
                resumeLoopAfter(track)
            end
            return
        end
        if DASH_IDS[n] then
            if cfg.toggleInvis then
                holdPose(track)
            else
                resumeLoopAfter(track)
            end
            return
        end
        if not shouldSwap(n, track) then
            return
        end
        holdPose(track)
    end))
    table.insert(runtime.charConns, char.ChildRemoved:Connect(function(ch)
        if ch.Name == "InDash" and (runtime.loopAnim or cfg.toggleInvis) then
            startLoopAnim()
        end
    end))
    table.insert(runtime.charConns, char.ChildAdded:Connect(function(ch)
        if ch.Name ~= "M1ing" or runtime.destroyed then
            return
        end
        if not overlayAttacks() then
            return
        end
        ensurePose()
        runtime.overrideGen = runtime.overrideGen + 1
        local gen = runtime.overrideGen
        local function onGone()
            finishOverride(gen)
        end
        pcall(function()
            ch.Destroying:Connect(onGone)
        end)
        table.insert(runtime.charConns, ch.AncestryChanged:Connect(function()
            if not ch.Parent then
                onGone()
            end
        end))
    end))
end

local panel = Window:AddPanel("Martial Artist")
panel:AddLabel("Parks under the target through the floor and M1s. Right-click the toggle (or tap v) for targeting.")
panel:AddDivider()
runtime.toggle = panel:AddToggle({
    name = "Invisible Auto Attack",
    default = false,
    persist = false,
    tooltip = "Teleport under the target and attack. Nested: who, which named moves, auto ult, depth.",
    settings = {
        {
            type = "dropdown",
            name = "TSB Target Mode",
            text = "Target",
            options = { "Nearest", "Lowest HP", "Selected" },
            default = cfg.targetMode,
            persist = false,
            tooltip = "Nearest living match, lowest health, or the Players list",
            callback = function(v)
                cfg.targetMode = v
                saveCfg()
            end,
        },
        {
            type = "dropdown",
            name = "TSB Players",
            text = "Players",
            options = playerNames(),
            default = intersectVisible(cfg.selectedNames, playerNames()),
            multiple = true,
            persist = false,
            tooltip = "Used when Target is Selected. Empty = all valid players",
            capture = function(ctrl)
                playerDrop = ctrl
            end,
            callback = function(selected)
                if runtime.dropSyncing then
                    return
                end
                cfg.selectedNames = mergeVisibleChecks(cfg.selectedNames, playerNames(), selected)
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Include dummies",
            default = cfg.includeDummies,
            callback = function(on)
                cfg.includeDummies = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Skip friends",
            default = cfg.skipFriends,
            callback = function(on)
                cfg.skipFriends = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Skip death counter",
            default = cfg.skipDeathCounter,
            tooltip = "Do not attack anyone with Bald Death Counter (Counter accessory). Other targets are used; if they are the only selected player, wait it out.",
            callback = function(on)
                cfg.skipDeathCounter = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Toggle invisibility",
            default = cfg.toggleInvis,
            callback = function(on)
                cfg.toggleInvis = on
                runtime.clipKey = nil
                saveCfg()
                if on then
                    startLoopAnim()
                elseif runtime.loopAnim then
                    startLoopAnim()
                else
                    stopLoopAnim()
                end
            end,
        },
        {
            type = "slider",
            text = "Depth",
            min = 2,
            max = 20,
            step = 1,
            default = cfg.depth,
            suffix = " studs",
            tooltip = "How far below the target root. Stay close enough for M1s; too deep misses",
            callback = function(v)
                cfg.depth = v
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Safety pad",
            default = cfg.idlePad,
            tooltip = "When no target, stand on a remote pad instead of the arena. Off = stay where you were / return to the floor.",
            callback = function(on)
                cfg.idlePad = on
                saveCfg()
                if not runtime.enabled then
                    return
                end
                if on then
                    if not (runtime.target and hasTarget(runtime.target)) then
                        goIdlePlatform()
                    end
                    return
                end
                destroyIdlePlatform()
                restoreSafe()
            end,
        },
        {
            type = "toggle",
            text = "Auto Martial Artist",
            default = cfg.autoPurple,
            tooltip = "Switch to Purple when enabling. Off = keep current character",
            callback = function(on)
                cfg.autoPurple = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Spectate target",
            default = cfg.spectateTarget,
            tooltip = "Follow the target while you are under the floor. Hold right mouse to look around",
            callback = function(on)
                cfg.spectateTarget = on
                saveCfg()
                if on and runtime.enabled then
                    bindSpectate()
                else
                    restoreCamera()
                end
            end,
        },
        {
            type = "dropdown",
            name = "TSB Moves",
            text = "Moves",
            options = moveOptionList(),
            default = intersectVisible(cfg.selectedMoves, moveOptionList()),
            multiple = true,
            persist = false,
            tooltip = "M1 plus the current kit's named skills. Awakening skills fire only while ulted.",
            capture = function(ctrl)
                moveDrop = ctrl
            end,
            callback = function(selected)
                if runtime.dropSyncing then
                    return
                end
                local merged = mergeVisibleChecks(cfg.selectedMoves, moveOptionList(), selected)
                if #merged == 0 then
                    merged = { "M1" }
                end
                cfg.selectedMoves = merged
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Auto ultimate",
            default = cfg.autoUlt,
            callback = function(on)
                cfg.autoUlt = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Softlock finishers",
            default = cfg.softlockFinishers,
            tooltip = "Stay under the floor during land-wait finishers (Bullet Barrage). Softlocks both you and the victim. Off = stand on the floor until it lands.",
            callback = function(on)
                cfg.softlockFinishers = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Twin Fang instant death",
            default = cfg.twinFangDeath,
            callback = function(on)
                cfg.twinFangDeath = on
                saveCfg()
            end,
        },
    },
    callback = function(enabled)
        if runtime.destroyed then
            return
        end
        if runtime.ignoreToggle then
            return
        end
        if enabled then
            startFeature()
            return
        end
        stopFeature(true)
    end,
})

local animPanel = Window:AddPanel("Animations")
animPanel:AddLabel("Dropdown picks the clip. Loop / Override all apply it. All those off = vanilla M1s.")
animPanel:AddDivider()
animPanel:AddDropdown({
    name = "TSB M1 Anim",
    text = "M1 animation",
    options = ANIM_NAMES,
    default = runtime.animPick,
    persist = false,
    tooltip = "Replaces Info.BaseM1 clips. Off = vanilla punches. Flight/UFO/Carpet/Sleigh may offset.",
    callback = function(v)
        runtime.animPick = v
        cfg.animPick = v
        saveCfg()
        if not selectedAnimId() then
            stopLoopAnim()
            return
        end
        if runtime.loopAnim or cfg.toggleInvis then
            startLoopAnim()
        end
    end,
})
animPanel:AddToggle({
    name = "Loop animation",
    default = runtime.loopAnim,
    persist = false,
    callback = function(on)
        runtime.loopAnim = on
        cfg.loopAnim = on
        saveCfg()
        if on or cfg.toggleInvis then
            startLoopAnim()
        else
            stopLoopAnim()
        end
    end,
})
animPanel:AddToggle({
    name = "Override all attacks",
    default = runtime.animAll,
    persist = false,
    callback = function(on)
        runtime.animAll = on
        cfg.animAll = on
        saveCfg()
    end,
})
animPanel:AddToggle({
    name = "Override walk",
    default = runtime.animWalk,
    persist = false,
    callback = function(on)
        runtime.animWalk = on
        cfg.animWalk = on
        saveCfg()
    end,
})
animPanel:AddToggle({
    name = "Override side dashes",
    default = runtime.animSideDash,
    persist = false,
    callback = function(on)
        runtime.animSideDash = on
        cfg.animSideDash = on
        saveCfg()
    end,
})
animPanel:AddSlider({
    name = "TSB Anim Clip From",
    text = "Clip start",
    min = 0,
    max = 20,
    step = 0.05,
    rounding = 2,
    default = runtime.animClipFrom,
    suffix = "s",
    persist = false,
    tooltip = "Loop from this time. 0 with Clip end 0 = whole clip. Toggle invisibility freezes Nuclear Victim at 9.6s instead.",
    callback = function(v)
        runtime.animClipFrom = v
        cfg.animClipFrom = v
        saveCfg()
        if runtime.loopTrack then
            startClipLoop(runtime.loopTrack)
        end
    end,
})
animPanel:AddSlider({
    name = "TSB Anim Clip End",
    text = "Clip end",
    min = 0,
    max = 20,
    step = 0.05,
    rounding = 2,
    default = runtime.animClipTo,
    suffix = "s",
    persist = false,
    tooltip = "Loop until this time. Same as start (and not 0) freezes that pose. Both 0 = whole clip.",
    callback = function(v)
        runtime.animClipTo = v
        cfg.animClipTo = v
        saveCfg()
        if runtime.loopTrack then
            startClipLoop(runtime.loopTrack)
        end
    end,
})

local miscPanel = Window:AddPanel("Misc")
miscPanel:AddToggle({
    name = "Overlay",
    default = false,
    persist = false,
    tooltip = "Nameplate over other players. Nested: which lines to show.",
    settings = {
        {
            type = "toggle",
            text = "Character",
            default = cfg.overlayChar,
            tooltip = "Kit name plus Info.Skillsets icon",
            callback = function(on)
                cfg.overlayChar = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Ultimate bar",
            default = cfg.overlayUltBar,
            tooltip = "Player Ultimate attribute, 0-100",
            callback = function(on)
                cfg.overlayUltBar = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Ultimate mode",
            default = cfg.overlayUlted,
            tooltip = "Character Ulted, the awakening window, not the meter",
            callback = function(on)
                cfg.overlayUlted = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Death counter",
            default = cfg.overlayDeathCounter,
            tooltip = "Bald / Strongest Hero Counter accessory while it is running",
            callback = function(on)
                cfg.overlayDeathCounter = on
                saveCfg()
            end,
        },
        {
            type = "toggle",
            text = "Outline",
            default = cfg.overlayOutline,
            tooltip = "Red ESP outline on every other player, through walls",
            callback = function(on)
                cfg.overlayOutline = on
                saveCfg()
            end,
        },
    },
    callback = function(on)
        if on then
            runtime.overlayStart()
        else
            runtime.overlayStop()
        end
    end,
})
miscPanel:AddToggle({
    name = "Anti Fling",
    default = false,
    persist = false,
    callback = function(on)
        if on then
            runtime.antiStart()
        else
            runtime.antiStop()
        end
    end,
})

kitMoves()
refreshMoveDrop()

connect(RunService.Heartbeat:Connect(function()
    if runtime.destroyed or not selectedAnimId() then
        return
    end
    if not runtime.loopAnim and not cfg.toggleInvis then
        return
    end
    local char = liveChar() or LocalPlayer.Character
    local hum = charHum(char)
    if not hum or hum.Health <= 0 or charBusy(char) then
        return
    end
    local t = runtime.loopTrack
    local playing = trackOnHum(t, hum)
    if playing then
        pcall(function()
            playing = t.IsPlaying
        end)
    end
    if playing then
        return
    end
    local now = os.clock()
    if now < (runtime.poseRetryAt or 0) then
        return
    end
    runtime.poseRetryAt = now + 0.2
    if t and not trackOnHum(t, hum) then
        stopLoopAnim()
    end
    startLoopAnim()
end))

connect(LocalPlayer.CharacterRemoving:Connect(function()
    stopLoopAnim()
    disconnectList(runtime.charConns)
end))

connect(LocalPlayer.CharacterAdded:Connect(function(char)
    stopLoopAnim()
    task.spawn(function()
        pcall(function()
            local hum = char:WaitForChild("Humanoid", 8)
            local handler = char:WaitForChild("CharacterHandler", 8)
            if handler then
                handler:WaitForChild("AnimationPlayer", 8)
            end
            if hum then
                hum:WaitForChild("Animator", 8)
            end
        end)
        local t0 = os.clock()
        while os.clock() - t0 < 6 and char.Parent do
            if charHum(char) and animLib(char) and not charBusy(char) then
                break
            end
            task.wait(0.1)
        end
        if runtime.destroyed or not char.Parent then
            return
        end
        kitMoves()
        refreshMoveDrop()
        bindAnimChar(char)
        if runtime.loopAnim or cfg.toggleInvis then
            startLoopAnim()
        end
    end)
end))
connect(LocalPlayer:GetAttributeChangedSignal("Character"):Connect(function()
    kitMoves()
    refreshMoveDrop()
end))

local dbg = Window.DebugPanel
if dbg and dbg.AddToggle then
    dbg:AddToggle({
        name = "Log Auto Attack",
        default = false,
        persist = false,
        tooltip = "Write targeting, M1, and position lines to TSB debug report/ in the executor workspace",
        callback = function(on)
            debugEnabled = on
            if on then
                if ensureDebugReport() then
                    debugReport("file", debugReportPath)
                    notify("Writing " .. debugReportPath)
                else
                    notify("Executor has no writefile")
                end
            end
        end,
    })
    dbg:AddButton({
        name = "Dump snapshot",
        persist = false,
        tooltip = "Append one state line to the TSB debug report file",
        callback = function()
            local was = debugEnabled
            debugEnabled = true
            debugReport("snap", snapshotLine())
            debugEnabled = was
            if debugReportPath then
                notify("Wrote snapshot")
            else
                notify("Enable Log Auto Attack first")
            end
        end,
    })
end

task.defer(function()
    bindAnimChar(liveChar() or LocalPlayer.Character)
    if runtime.loopAnim or cfg.toggleInvis then
        startLoopAnim()
    end
end)

local function teardown()
    if runtime.destroyed then
        return
    end
    runtime.destroyed = true
    runtime.enabled = false
    runtime.shutdown = true
    runtime.workGen = runtime.workGen + 1
    if runtime.fangBusy or runtime.fangVoiding then
        fangReturnUp()
        runtime.fangBusy = false
    end
    releaseHeld()
    stopLoopAnim()
    restoreCamera()
    restoreLocalLook()
    restoreParkBody()
    restoreSafe()
    destroyIdlePlatform()
    if runtime.antiStop then
        runtime.antiStop()
    end
    if runtime.overlayStop then
        runtime.overlayStop()
    end
    pcall(function()
        RunService:UnbindFromRenderStep(PARK_BIND)
    end)
    pcall(function()
        RunService:UnbindFromRenderStep(FANG_BIND)
    end)
    clearFangAlign()
    clearFangStop()
    stopClipLoop()
    disconnectList(runtime.charConns)
    disconnectList(runtime.conns)
    if env and env[RUNTIME_KEY] == runtime then
        env[RUNTIME_KEY] = nil
    end
end

if Window.Instance then
    connect(Window.Instance.Destroying:Connect(teardown))
end

runtime.cleanup = function()
    teardown()
    pcall(function()
        if Window.Instance and Window.Instance.Parent then
            Window:Destroy()
        end
    end)
end
if env then
    env[RUNTIME_KEY] = runtime
end
