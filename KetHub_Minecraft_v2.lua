local env = getgenv()
if env.KetHubUnload then
    pcall(env.KetHubUnload)
end
env.KetHubLoaded = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")

local LP = Players.LocalPlayer

local HUB = "Ket Hub"
local VERSION = "beta"
local KEY = "KetHubNewEra2026"
local DISCORD = "https://discord.gg/WXWyuDQsD"
local CREATOR_NICK = "tgezik3"
local CREATOR_MAIN = "roblox_user_4113481652"
local CREATOR_ID = 4113481652

local FS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
local ROOT, CFGDIR, KEYFILE, PREFSFILE = "KetHub", "KetHub/configs", "KetHub/key.txt", "KetHub/prefs.json"

local function mkdir(path)
    if type(makefolder) ~= "function" then return end
    if type(isfolder) == "function" and isfolder(path) then return end
    pcall(makefolder, path)
end

if FS then
    mkdir(ROOT)
    mkdir(CFGDIR)
end

local function readFile(path)
    if not FS then return nil end
    local ok, data = pcall(function()
        if isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end

local function writeFile(path, data)
    if not FS then return false end
    return (pcall(writefile, path, data))
end

local function readJson(path)
    local raw = readFile(path)
    if not raw then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return ok and data or nil
end

local function writeJson(path, tbl)
    return writeFile(path, HttpService:JSONEncode(tbl))
end

local running = true
local conns = {}
local guis = {}
local drawings = {}

local function keep(conn)
    conns[#conns + 1] = conn
    return conn
end

local prefs = readJson(PREFSFILE) or {}
prefs.pins = type(prefs.pins) == "table" and prefs.pins or {}
prefs.binds = type(prefs.binds) == "table" and prefs.binds or {}
local prefsDirty = false

local function savePrefs()
    prefsDirty = true
end

task.spawn(function()
    while running do
        task.wait(1.5)
        if prefsDirty then
            prefsDirty = false
            writeJson(PREFSFILE, prefs)
        end
    end
end)

local function keyFromName(name)
    if type(name) ~= "string" then return nil end
    local ok, kc = pcall(function() return Enum.KeyCode[name] end)
    if ok then return kc end
end

local menuKey = keyFromName(prefs.menuKey) or Enum.KeyCode.RightShift
local panicKey = keyFromName(prefs.panicKey)
local currentMode = prefs.mode == "Mobile" and "Mobile" or "PC"

local isTester = LP.Name:lower() == CREATOR_NICK:lower() or LP.Name:lower() == CREATOR_MAIN:lower()

local stats = { fps = 60, ping = 0 }
local startTime = tick()

local function samplePing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(v) == "number" then
        stats.ping = math.floor(v + 0.5)
    else
        pcall(function() stats.ping = math.floor(LP:GetNetworkPing() * 1000 + 0.5) end)
    end
end

samplePing()

local frames, frameStamp = 0, tick()
keep(RunService.RenderStepped:Connect(function()
    frames = frames + 1
    local now = tick()
    if now - frameStamp >= 0.5 then
        stats.fps = math.floor(frames / (now - frameStamp) + 0.5)
        frames, frameStamp = 0, now
        samplePing()
    end
end))

local T = {
    bg = Color3.fromRGB(16, 16, 21),
    side = Color3.fromRGB(20, 20, 27),
    card = Color3.fromRGB(27, 27, 36),
    card2 = Color3.fromRGB(37, 37, 50),
    line = Color3.fromRGB(42, 42, 56),
    accent = Color3.fromRGB(124, 108, 255),
    accent2 = Color3.fromRGB(80, 200, 255),
    off = Color3.fromRGB(56, 56, 72),
    text = Color3.fromRGB(232, 232, 240),
    dim = Color3.fromRGB(135, 135, 158),
    good = Color3.fromRGB(80, 220, 120),
    warn = Color3.fromRGB(255, 200, 80),
    bad = Color3.fromRGB(235, 80, 90),
}

local function new(class, props)
    local obj = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else obj[k] = v end
    end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(obj, r)
    local radius = typeof(r) == "UDim" and r or UDim.new(0, r)
    return new("UICorner", { CornerRadius = radius, Parent = obj })
end

local function stroke(obj, color, thickness, transparency)
    return new("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = obj,
    })
end

local function label(props)
    local base = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props) do base[k] = v end
    return new("TextLabel", base)
end

local function tween(obj, time, props, style)
    TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function pingColor(v)
    if v < 80 then return T.good elseif v < 150 then return T.warn end
    return T.bad
end

local function fpsColor(v)
    if v >= 55 then return T.good elseif v >= 30 then return T.warn end
    return T.bad
end

local function fire(cb, ...)
    if not cb then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(cb, table.unpack(args, 1, args.n))
        if not ok then warn("[Ket Hub] " .. tostring(err)) end
    end)
end

local function notify(text, duration)
    local gui = new("ScreenGui", { Name = "KetHub_Toast", ResetOnSpawn = false, DisplayOrder = 1100, Parent = CoreGui })
    local frame = new("Frame", {
        Size = UDim2.fromOffset(300, 40),
        Position = UDim2.new(0.5, -150, 0, -50),
        BackgroundColor3 = T.card,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(frame, 10)
    stroke(frame, T.accent, 1, 0.3)
    local line = label({
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        Text = text,
        Font = Enum.Font.GothamBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = frame,
    })
    tween(frame, 0.3, { Position = UDim2.new(0.5, -150, 0, 18) })
    task.delay(duration or 3, function()
        if not frame.Parent then return end
        tween(frame, 0.3, { Position = UDim2.new(0.5, -150, 0, -50) })
        tween(line, 0.3, { TextTransparency = 1 })
        task.wait(0.4)
        gui:Destroy()
    end)
end

local avatars = {}

local function headshot(userId)
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok then return img end
end

task.spawn(function() avatars.me = headshot(LP.UserId) end)

task.spawn(function()
    local id
    for _, name in ipairs({ CREATOR_MAIN, CREATOR_NICK }) do
        local ok, result = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
        if ok and type(result) == "number" then
            id = result
            break
        end
    end
    avatars.creator = headshot(id or CREATOR_ID)
end)

local function makeAvatar(parent, size, pos, key, ring)
    local img = new("ImageLabel", {
        Size = UDim2.fromOffset(size, size),
        Position = pos,
        BackgroundColor3 = T.card2,
        BorderSizePixel = 0,
        Image = "",
        Parent = parent,
    })
    corner(img, UDim.new(1, 0))
    stroke(img, ring or T.accent, 2, 0.1)
    task.spawn(function()
        local waited = 0
        while running and not avatars[key] and waited < 15 do
            task.wait(0.2)
            waited = waited + 0.2
        end
        if avatars[key] and img.Parent then img.Image = avatars[key] end
    end)
    return img
end

local gameName = "Minecraft"
do
    local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
    if ok and info and info.Name then gameName = info.Name end
end

local function makeGameIcon(parent, size, pos)
    local img = new("ImageLabel", {
        Size = UDim2.fromOffset(size, size),
        Position = pos,
        BackgroundColor3 = T.card2,
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Parent = parent,
    })
    corner(img, math.floor(size * 0.22))
    stroke(img, T.line, 1, 0)
    local fallback = label({
        Size = UDim2.new(1, 0, 1, 0),
        Text = string.upper(string.sub(gameName, 1, 2)),
        Font = Enum.Font.GothamBlack,
        TextSize = math.max(9, math.floor(size * 0.34)),
        TextColor3 = T.accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = img,
    })
    task.spawn(function()
        local sources = {
            "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
            "rbxthumb://type=GameIcon&id=" .. tostring(game.PlaceId) .. "&w=150&h=150",
            "rbxthumb://type=Asset&id=" .. tostring(game.PlaceId) .. "&w=150&h=150",
        }
        for _, url in ipairs(sources) do
            if not running or not img.Parent then return end
            img.Image = url
            local waited = 0
            while running and img.Parent and not img.IsLoaded and waited < 2.5 do
                task.wait(0.1)
                waited = waited + 0.1
            end
            if img.IsLoaded then
                fallback.Visible = false
                return
            end
        end
    end)
    return img
end

local function makeDraggable(handle, target, onEnd)
    local state = { moved = false }
    local dragging, startInput, startPos = false, nil, nil
    keep(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            state.moved = false
            startInput = input.Position
            startPos = target.Position
        end
    end))
    keep(UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - startInput
        if not state.moved then
            if delta.Magnitude < 5 then return end
            state.moved = true
            startInput = input.Position
            startPos = target.Position
            return
        end
        target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end))
    keep(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and state.moved and onEnd then onEnd() end
            dragging = false
        end
    end))
    return state
end

local function shortOf(title)
    local letters = {}
    for word in title:gmatch("%S+") do
        letters[#letters + 1] = word:sub(1, 1):upper()
        if #letters == 3 then break end
    end
    if #letters == 1 then return title:sub(1, 2):upper() end
    return table.concat(letters)
end

local binder = { capture = nil }
local Hub = {}
local Quick = { buttons = {}, meta = {}, provider = nil, gui = nil, drag = nil }

local keyToId = {}
local function rebuildBinds()
    keyToId = {}
    for id, name in pairs(prefs.binds) do keyToId[name] = id end
end
rebuildBinds()

function Quick.size()
    return prefs.floatSize or (currentMode == "Mobile" and 52 or 46)
end

local function quickGui()
    if Quick.gui and Quick.gui.Parent then return Quick.gui end
    Quick.gui = new("ScreenGui", {
        Name = "KetHub_Quick",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 998,
        Enabled = not prefs.hidePins,
        Parent = CoreGui,
    })
    guis[#guis + 1] = Quick.gui
    return Quick.gui
end

local PIN_RING_ON = ColorSequence.new({
    ColorSequenceKeypoint.new(0, T.accent),
    ColorSequenceKeypoint.new(1, T.accent2),
})
local PIN_RING_OFF = ColorSequence.new(T.line)

local function paintQuick(entry, active)
    entry.ring.Color = active and PIN_RING_ON or PIN_RING_OFF
    tween(entry.inner, 0.12, { BackgroundColor3 = active and Color3.fromRGB(44, 38, 88) or T.card })
    entry.text.TextColor3 = active and Color3.new(1, 1, 1) or T.dim
    entry.dot.Visible = active
end

function Quick.count()
    local n = 0
    for _ in pairs(Quick.buttons) do n = n + 1 end
    return n
end

function Quick.add(id, title, short)
    if Quick.buttons[id] then return end
    local gui = quickGui()
    local size = Quick.size()
    local pos = prefs.pins[id]
    if not pos then
        local n = Quick.count()
        pos = { x = 0.93 - 0.08 * math.floor(n / 6), y = 0.2 + 0.11 * (n % 6) }
        prefs.pins[id] = pos
        savePrefs()
    end

    local holder = new("Frame", {
        Name = id,
        Size = UDim2.fromOffset(size, size + 16),
        Position = UDim2.new(pos.x, -size / 2, pos.y, -size / 2),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    local circle = new("TextButton", {
        Size = UDim2.fromOffset(size, size),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(size / 2, size / 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = holder,
    })
    corner(circle, UDim.new(1, 0))
    local ring = new("UIGradient", { Color = PIN_RING_OFF, Rotation = 45, Parent = circle })
    local scale = new("UIScale", { Scale = 1, Parent = circle })
    local inner = new("Frame", {
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = T.card,
        BorderSizePixel = 0,
        Parent = circle,
    })
    corner(inner, UDim.new(1, 0))
    local text = label({
        Size = UDim2.new(1, 0, 1, 0),
        Text = short or shortOf(title),
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(size * 0.3),
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = inner,
    })
    local dot = new("Frame", {
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.new(1, -11, 0, 1),
        BackgroundColor3 = T.good,
        BorderSizePixel = 0,
        Visible = false,
        Parent = circle,
    })
    corner(dot, UDim.new(1, 0))
    stroke(dot, T.bg, 2, 0)
    local caption = label({
        Size = UDim2.new(0, size + 28, 0, 12),
        Position = UDim2.new(0, -14, 0, size + 3),
        Text = title,
        TextSize = 9,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.55,
        Visible = prefs.pinLabels ~= false,
        Parent = holder,
    })

    local entry = { holder = holder, circle = circle, ring = ring, inner = inner, text = text, dot = dot, caption = caption, scale = scale }
    Quick.buttons[id] = entry

    circle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local origin = holder.AbsolutePosition
            Quick.drag = {
                id = id,
                holder = holder,
                scale = scale,
                start = Vector2.new(input.Position.X, input.Position.Y),
                base = origin,
                cur = origin,
                target = origin,
                moved = false,
            }
            tween(scale, 0.08, { Scale = 0.92 })
        end
    end)

    local item = Quick.provider and Quick.provider(id)
    if item and item.kind == "toggle" then paintQuick(entry, item.get()) end
end

function Quick.remove(id)
    local entry = Quick.buttons[id]
    if entry then entry.holder:Destroy() end
    Quick.buttons[id] = nil
    prefs.pins[id] = nil
    savePrefs()
end

function Quick.sync(id, active)
    if not id then return end
    local entry = Quick.buttons[id]
    if entry then paintQuick(entry, active) end
end

function Quick.restore()
    for id in pairs(prefs.pins) do
        local meta = Quick.meta[id]
        if meta and not Quick.buttons[id] then Quick.add(id, meta.title, meta.short) end
    end
end

function Quick.rebuild()
    local ids = {}
    for id in pairs(Quick.buttons) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        Quick.buttons[id].holder:Destroy()
        Quick.buttons[id] = nil
    end
    for _, id in ipairs(ids) do
        local meta = Quick.meta[id]
        if meta then Quick.add(id, meta.title, meta.short) end
    end
end

function Quick.resetPositions()
    for id in pairs(Quick.buttons) do prefs.pins[id] = nil end
    savePrefs()
    Quick.rebuild()
end

function Quick.setHidden(hidden)
    quickGui().Enabled = not hidden
end

function Quick.setLabels(show)
    for _, entry in pairs(Quick.buttons) do entry.caption.Visible = show end
end

function Quick.trigger(id, fromButton)
    local item = Quick.provider and Quick.provider(id)
    if not item then return end
    if item.kind == "toggle" then
        item.set(not item.get())
        if not fromButton then
            notify(item.title .. (item.get() and ": ON" or ": OFF"), 1.2)
        end
    else
        item.run()
        local entry = Quick.buttons[id]
        if entry then
            paintQuick(entry, true)
            task.delay(0.2, function()
                if Quick.buttons[id] then paintQuick(Quick.buttons[id], false) end
            end)
        end
        if not fromButton then notify(item.title, 1.2) end
    end
end

keep(UIS.InputChanged:Connect(function(input)
    local drag = Quick.drag
    if not drag or prefs.lockPins or not Quick.gui then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local pointer = Vector2.new(input.Position.X, input.Position.Y)
    if not drag.moved then
        if (pointer - drag.start).Magnitude < 7 then return end
        drag.moved = true
        drag.start = pointer
        drag.base = drag.holder.AbsolutePosition
        drag.cur = drag.base
        tween(drag.scale, 0.1, { Scale = 1.14 })
        return
    end
    local area = Quick.gui.AbsoluteSize
    local size = drag.holder.AbsoluteSize
    local want = drag.base + (pointer - drag.start)
    drag.target = Vector2.new(math.clamp(want.X, 0, area.X - size.X), math.clamp(want.Y, 0, area.Y - size.Y))
end))

keep(RunService.RenderStepped:Connect(function(dt)
    local drag = Quick.drag
    if not drag or not drag.moved then return end
    drag.cur = drag.cur:Lerp(drag.target, 1 - math.exp(-dt * 28))
    drag.holder.Position = UDim2.fromOffset(drag.cur.X, drag.cur.Y)
end))

keep(UIS.InputEnded:Connect(function(input)
    local drag = Quick.drag
    if not drag then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    Quick.drag = nil
    tween(drag.scale, 0.12, { Scale = 1 })
    if drag.moved and Quick.gui then
        local area = Quick.gui.AbsoluteSize
        local half = Quick.size() / 2
        local cx = math.clamp((drag.target.X + half) / area.X, 0.03, 0.97)
        local cy = math.clamp((drag.target.Y + half) / area.Y, 0.05, 0.95)
        prefs.pins[drag.id] = { x = cx, y = cy }
        savePrefs()
        tween(drag.holder, 0.14, { Position = UDim2.new(cx, -half, cy, -half) })
    else
        Quick.trigger(drag.id, true)
    end
end))

keep(UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if binder.capture then
        local cb = binder.capture
        binder.capture = nil
        cb(input.KeyCode)
        return
    end
    if UIS:GetFocusedTextBox() then return end
    local kc = input.KeyCode
    if kc == menuKey then
        if Hub.toggle then Hub.toggle() end
        return
    end
    if panicKey and kc == panicKey then
        if Hub.panic then Hub.panic() end
        return
    end
    local id = keyToId[kc.Name]
    if id then Quick.trigger(id, false) end
end))

local MODULE_URL = "https://raw.githubusercontent.com/screengui/bytehub/refs/heads/main/Byte%20Hub/minerscave/modules/"
local MODULE_FILES = {
    killAura = "kill-aura.lua",
    targetStrafe = "target-strafe.lua",
    hitbox = "hitbox-expander.lua",
    combatLog = "auto-combat-log.lua",
    safeZone = "auto-safe-zone.lua",
    noFall = "no-fall.lua",
    sprint = "sprint.lua",
    autoEat = "auto-eat.lua",
    jesus = "jesus.lua",
    infiniteHealth = "infinite-health.lua",
    fullbright = "fullbright.lua",
    xray = "xray.lua",
    chestEsp = "chest-esp.lua",
    lavaEsp = "lava-esp.lua",
    playerEsp = "player-esp.lua",
}

local function pullModule(file)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(MODULE_URL .. file))()
    end)
    if ok then return result end
end

local function loadModules(onProgress)
    local mods = {}
    pullModule("Essentials.lua")
    local total, done = 0, 0
    for _ in pairs(MODULE_FILES) do total = total + 1 end
    onProgress(0, total)
    for name, file in pairs(MODULE_FILES) do
        task.spawn(function()
            mods[name] = pullModule(file)
            done = done + 1
            onProgress(done, total)
        end)
    end
    local waited = 0
    while done < total and waited < 25 do
        task.wait(0.1)
        waited = waited + 0.1
    end
    return setmetatable(mods, {
        __index = function()
            return {
                start = function() notify("This module failed to load", 3) end,
                stop = function() end,
            }
        end,
    })
end

local function loadGameRefs()
    local ok, refs = pcall(function()
        local r = {}
        r.remotes = ReplicatedStorage:WaitForChild("GameRemotes", 10)
        local scripts = LP:WaitForChild("PlayerScripts", 10)
        r.main = scripts:WaitForChild("MainLocalScript", 10)
        r.cglobals = require(r.main:WaitForChild("CGlobals", 10))
        local assets = ReplicatedStorage:WaitForChild("AssetsMod", 10)
        r.blockInfo = require(assets:WaitForChild("BlockInfo", 10))
        r.itemInfo = require(assets:WaitForChild("ItemInfo", 10))
        r.itemLevels = require(assets:WaitForChild("ItemLevels", 10))
        r.blockHighlights = require(r.main:WaitForChild("BlockHighlights", 10))
        return r
    end)
    if ok and refs and refs.remotes then return refs end
end

local TIERS = { Diamond = 4, Ruby = 3, Iron = 2, Gold = 2, Steel = 2, Stone = 1 }
local ARMOR = { Helmet = 103, Chestplate = 102, Leggings = 101, Boots = 100 }

local function createFeatures(G, Mods)
    local F = {}
    local remotes = G.remotes
    local abb = remotes:WaitForChild("AcceptBreakBlock", 5)
    local bb = remotes:WaitForChild("BreakBlock", 5)
    local attack = remotes:WaitForChild("Attack", 5)
    local moveItem = remotes:WaitForChild("MoveItem", 5)
    local sortItem = remotes:FindFirstChild("SortItem") or remotes:FindFirstChild("SortItems")
    local useBlock = remotes:FindFirstChild("UseBlock")
    local placeRemote = remotes:FindFirstChild("PlaceBlock")
    local dropItem = remotes:FindFirstChild("DropItem")

    local loops = {}
    local function startLoop(name, interval, fn)
        local token = {}
        loops[name] = token
        task.spawn(function()
            while loops[name] == token and running do
                pcall(fn)
                task.wait(interval)
            end
        end)
    end
    local function stopLoop(name)
        loops[name] = nil
    end

    _G.delay = 0
    _G.radius = 10
    _G.speed = 5
    _G.tbdelay = 0
    _G.selectedTargeting = "nearest"

    F.hasGive = ReplicatedStorage:FindFirstChild("admingui") ~= nil
    F.isTester = isTester

    local character = LP.Character or LP.CharacterAdded:Wait()
    local inventory = character:WaitForChild("Inventory", 10)
    local instamine = false

    local function ensureGamemode(char)
        if not char:FindFirstChild("Gamemode") then
            local v = Instance.new("IntValue")
            v.Name = "Gamemode"
            v.Parent = char
        end
    end

    ensureGamemode(character)

    keep(LP.CharacterAdded:Connect(function(newChar)
        character = newChar
        inventory = newChar:WaitForChild("Inventory", 10)
        ensureGamemode(newChar)
        local gm = newChar:FindFirstChild("Gamemode")
        if gm and instamine then gm.Value = 1 end
    end))

    if not env.KetHubHooked then
        env.KetHubHooked = true
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/SUUUUUS00000/MEGGD-Anti-kick/refs/heads/main/MEGGD%20Best%20Anti-kick.lua"))()
        end)
        if hookmetamethod and getnamecallmethod then
            local oldIndex, oldNamecall
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if self == LP and type(key) == "string" and key:lower() == "kick" then
                    return error("Expected ':' not '.' calling member function Kick", 2)
                end
                return oldIndex(self, key)
            end)
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if self == LP and getnamecallmethod():lower() == "kick" then
                    return
                end
                return oldNamecall(self, ...)
            end)
        end
    end

    pcall(function()
        env.KetHubArmorLag = LP.PlayerGui.HUDGui.Inventory.Mirror.VPFrame[""].ChildAdded:Connect(function(child)
            if child:IsA("UnionOperation") then
                task.wait()
                child:Destroy()
            end
        end)
    end)

    if isTester then
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/screengui/archives/main/inv-viewerV2.lua", true))()
            LP.PlayerGui:WaitForChild("invviewer", 5).Enabled = false
        end)
    end

    local function decode(slot)
        if not slot then return nil end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, slot.Value)
        return ok and data or nil
    end

    local function decodeCounted(slot)
        local data = decode(slot)
        return data and data.count and data.count > 0 and data or nil
    end

    local function getTier(name)
        for prefix, tier in pairs(TIERS) do
            if string.find(name, "^" .. prefix) then
                local after = string.sub(name, #prefix + 1, #prefix + 1)
                if after == "" or after == " " or string.match(after, "%u") then
                    return tier
                end
            end
        end
        local info = G.itemInfo[name]
        return info and (info.tier or info.Tier) or 0
    end

    local function getArmorType(name)
        for kind, id in pairs(ARMOR) do
            if string.find(name, kind) then return id end
        end
    end

    local function isBetter(new, old)
        local newTier, oldTier = getTier(new.name), getTier(old.name)
        local newDur, oldDur = new.durability or 0, old.durability or 0
        local newInfo, oldInfo = G.itemInfo[new.name], G.itemInfo[old.name]
        local newMax = newInfo and newInfo.durability or 100
        local oldMax = oldInfo and oldInfo.durability or 100

        if oldDur <= oldMax * 0.1 and newDur > newMax * 0.1 then
            if newTier >= oldTier - 1 then return true end
        end

        if newTier > oldTier then
            if newDur > newMax * 0.1 or oldDur <= oldMax * 0.05 then return true end
        elseif newTier == oldTier then
            if newDur > oldDur then return true end
        end

        if newTier == oldTier and newDur == oldDur then
            return newMax > oldMax
        end
        return false
    end

    local function equipBestArmor()
        local inv = LP.Character and LP.Character:FindFirstChild("Inventory")
        if not inv then return end

        local best = {
            [103] = { tier = -1, dur = -1 },
            [102] = { tier = -1, dur = -1 },
            [101] = { tier = -1, dur = -1 },
            [100] = { tier = -1, dur = -1 },
        }

        for i = 0, 35 do
            local data = decode(inv:FindFirstChild("Slot" .. i))
            if data and data.count and data.count >= 1 and data.name then
                local armorSlot = getArmorType(data.name)
                if armorSlot then
                    local tier = getTier(data.name)
                    local dur = data.durability or 0
                    local current = best[armorSlot]
                    if tier > current.tier or (tier == current.tier and dur > current.dur) then
                        best[armorSlot] = { tier = tier, dur = dur, idx = i, name = data.name }
                    end
                end
            end
        end

        for slot, item in pairs(best) do
            if item.idx then
                local equipped = decode(inv:FindFirstChild("Slot" .. slot))
                if not equipped or equipped.count <= 0 or isBetter(item, equipped) then
                    moveItem:InvokeServer(item.idx, slot, true)
                end
            end
        end
    end

    local function slotButton(index)
        local hud = LP.PlayerGui:FindFirstChild("HUDGui")
        local bar = hud and hud:FindFirstChild("Hotbar")
        if not bar then return nil end
        local x = index * 40 + 6
        for _, btn in ipairs(bar:GetChildren()) do
            if btn:IsA("TextButton") and btn.Position.X.Offset == x then return btn end
        end
    end

    local function selectSlot(index)
        local btn = slotButton(index)
        if btn and getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
        end
    end

    local function itemSpeed(name, required, better)
        local info = G.itemInfo[name]
        if info and (info.tooltype == required or info.tooltype == better) then
            return G.itemLevels.speedMul[info.level] or 1
        end
        return 1
    end

    local function bestToolSlot(blockName)
        local info = G.blockInfo[blockName]
        if not info then return nil end
        local bestSlot, bestSpeed = nil, 0
        for i = 0, 8 do
            local slot = inventory and inventory:FindFirstChild("Slot" .. i)
            local data = slot and decodeCounted(slot)
            if data then
                local speed = itemSpeed(data.name, info.toolRequire, info.betterTool)
                if speed > bestSpeed then
                    bestSpeed = speed
                    bestSlot = i
                end
            end
        end
        return bestSlot
    end

    local function selectedSlotValue()
        local model = Workspace:FindFirstChild(LP.Name)
        return model and model:FindFirstChild("SelectedSlot")
    end

    local function coordLabel()
        local hud = LP.PlayerGui:FindFirstChild("HUDGui")
        local frame = hud and hud:FindFirstChild("DataFrame")
        if not frame then return nil end
        return frame:FindFirstChild("Coord") or frame:FindFirstChild("Coords") or frame:FindFirstChild("coordinates")
    end

    local function readCoords()
        local lbl = coordLabel()
        if not lbl then return nil end
        local x, y, z = lbl.Text:match("(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)%s*,%s*(%-?%d+%.?%d*)")
        if not x then return nil end
        return math.floor(tonumber(x)), math.floor(tonumber(y)), math.floor(tonumber(z))
    end

    F.readCoords = readCoords

    local worldMod, idMod
    local function worldRefs()
        if worldMod and idMod then return worldMod, idMod end
        local ok = pcall(function()
            worldMod = require(LP.PlayerScripts.MainLocalScript.CWorld)
            idMod = require(ReplicatedStorage.AssetsMod.IDs)
        end)
        if ok then return worldMod, idMod end
        notify("Your executor can't use require()", 3)
    end

    local function modToggle(name)
        return function(on)
            local m = Mods[name]
            if on then m.start() else m.stop() end
        end
    end

    F.killAura = modToggle("killAura")
    F.targetStrafe = modToggle("targetStrafe")
    F.hitbox = modToggle("hitbox")
    F.combatLog = modToggle("combatLog")
    F.safeZone = modToggle("safeZone")
    F.noFall = modToggle("noFall")
    F.sprint = modToggle("sprint")
    F.autoEat = modToggle("autoEat")
    F.jesus = modToggle("jesus")
    F.fullbright = modToggle("fullbright")
    F.xray = modToggle("xray")
    F.chestEsp = modToggle("chestEsp")
    F.lavaEsp = modToggle("lavaEsp")
    F.playerEsp = modToggle("playerEsp")

    function F.infiniteHealth(on)
        if on then
            Mods.infiniteHealth.start(moveItem, _G.useTaskSpawn)
        else
            Mods.infiniteHealth.stop()
        end
    end

    local triggerOn = false
    local function triggerStep()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        if not hrp or not cam then return end

        local view = cam.ViewportSize
        local ray = cam:ViewportPointToRay(view.X / 2, view.Y / 2)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude

        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        if not hit then return end

        local model = hit.Instance:FindFirstAncestorOfClass("Model")
        if not model or model == char or not model:FindFirstChildOfClass("Humanoid") then return end

        local targetHrp = model:FindFirstChild("HumanoidRootPart")
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and targetHrp then
            local d = hrp.Position - targetHrp.Position
            if d.X * d.X + d.Z * d.Z <= (_G.RANGE_SQ or 625) then
                attack:InvokeServer(model)
            end
        end
    end

    function F.triggerbot(on)
        triggerOn = on
        if not on then return end
        task.spawn(function()
            while triggerOn and running do
                pcall(triggerStep)
                task.wait(_G.tbdelay or 0)
            end
        end)
    end

    function F.autoArmor(on)
        if on then startLoop("armor", 0.15, equipBestArmor) else stopLoop("armor") end
    end

    function F.autoTool(on)
        if not on then return stopLoop("tool") end
        startLoop("tool", 0, function()
            local selected = selectedSlotValue()
            if not selected then return end
            local pos = G.cglobals.TargetBlockCoordinate
            local block = G.cglobals.BlockUnderMouse
            if pos and block and G.blockHighlights.IsBreaking(pos) then
                local best = bestToolSlot(block.Name)
                if best and selected.Value ~= best then selectSlot(best) end
            end
        end)
    end

    function F.reach(on)
        G.cglobals["PLAYER_REACH"] = on and 9e9 or 19.5
    end

    local function humanoid()
        return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    end

    function F.walkSpeed(v)
        local h = humanoid()
        if h then h.WalkSpeed = v end
    end

    function F.jumpPower(v)
        local h = humanoid()
        if h then h.JumpPower = v end
    end

    local infiniteJump = false
    keep(UIS.JumpRequest:Connect(function()
        if not infiniteJump then return end
        local h = humanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))

    function F.infiniteJump(on)
        infiniteJump = on
    end

    local platform = Instance.new("Part")
    platform.Anchored = true
    platform.Size = Vector3.new(5, 1, 5)
    platform.Transparency = 1
    platform.CanCollide = false
    platform.Parent = Workspace

    local airConn
    function F.airWalk(on)
        if airConn then
            airConn:Disconnect()
            airConn = nil
        end
        if not on then
            platform.CanCollide = false
            return
        end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local y = hrp.Position.Y - 3
        platform.CanCollide = true
        airConn = RunService.Heartbeat:Connect(function()
            local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if root then
                platform.Position = Vector3.new(root.Position.X, y, root.Position.Z)
            end
        end)
    end

    function F.freeze(on)
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = on end
    end

    function F.suicide()
        local h = humanoid()
        if h then h.Health = 0 end
    end

    function F.immortality()
        moveItem:InvokeServer(101, 9, true)
    end

    function F.tpCoords(x, y, z)
        local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
        if not (nx and ny and nz) then
            return notify("Enter all three coordinates", 3)
        end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(math.floor(nx * 3), math.floor(ny * 3), math.floor(nz * 3))
        end
    end

    function F.playerNames()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then list[#list + 1] = p.Name end
        end
        table.sort(list)
        return list
    end

    function F.tpPlayer(name)
        if not name then return notify("Select a player first", 3) end
        local target = Players:FindFirstChild(name)
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local targetHrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp and targetHrp then
            hrp.CFrame = targetHrp.CFrame
        else
            notify("Player is not available", 3)
        end
    end

    local cross = { on = false, rainbow = false, color = Color3.fromRGB(188, 50, 252), lines = nil, conn = nil }

    local function crossRefresh()
        if not (cross.on or cross.rainbow) then
            if cross.conn then
                cross.conn:Disconnect()
                cross.conn = nil
            end
            for _, l in ipairs(cross.lines or {}) do l.Visible = false end
            return
        end
        if not cross.lines then
            cross.lines = {}
            for i = 1, 4 do
                local l = Drawing.new("Line")
                l.Thickness = 2.5
                l.Transparency = 1
                l.Visible = false
                cross.lines[i] = l
                drawings[#drawings + 1] = l
            end
        end
        if cross.conn then return end
        cross.conn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local c = cam.ViewportSize / 2
            local color = cross.rainbow and Color3.fromHSV((tick() * 0.5) % 1, 1, 1) or cross.color
            local gap, len = 5, 14
            local L = cross.lines
            L[1].From, L[1].To = Vector2.new(c.X - gap - len, c.Y), Vector2.new(c.X - gap, c.Y)
            L[2].From, L[2].To = Vector2.new(c.X + gap, c.Y), Vector2.new(c.X + gap + len, c.Y)
            L[3].From, L[3].To = Vector2.new(c.X, c.Y - gap - len), Vector2.new(c.X, c.Y - gap)
            L[4].From, L[4].To = Vector2.new(c.X, c.Y + gap), Vector2.new(c.X, c.Y + gap + len)
            for i = 1, 4 do
                L[i].Color = color
                L[i].Visible = true
            end
        end)
    end

    function F.crosshair(on)
        cross.on = on
        crossRefresh()
    end

    function F.rainbowCrosshair(on)
        cross.rainbow = on
        crossRefresh()
    end

    function F.crosshairColor(color)
        cross.color = color
    end

    function F.invViewer(on)
        if not isTester then return notify("Only for testers", 3) end
        local gui = LP.PlayerGui:FindFirstChild("invviewer")
        if gui then gui.Enabled = on end
    end

    local hiddenSlots = {
        "Slot100", "Slot101", "Slot102", "Slot103",
        "Slot80", "Slot81", "Slot82", "Slot83", "Slot84",
        "Slot85", "Slot86", "Slot87", "Slot88",
    }

    function F.moreSlots(on)
        if not on then return stopLoop("slots") end
        startLoop("slots", 0, function()
            local inv = LP.PlayerGui.HUDGui.Inventory
            inv.Chest.Visible = true
            inv.Crafting.Visible = false
            inv.Mirror.Visible = false
            inv.ResultSlot.Visible = false
            for _, name in ipairs(hiddenSlots) do
                local slot = inv.Slots:FindFirstChild(name)
                if slot then slot.Visible = false end
            end
        end)
    end

    local protect = { on = false, name = "Protected", hooked = {}, added = nil }

    local function escape(s)
        return (s:gsub("%p", "%%%0"))
    end

    local function swapLabel(lbl)
        if not protect.on then return end
        if lbl.Text:find(LP.Name, 1, true) then
            lbl.Text = lbl.Text:gsub(escape(LP.Name), (protect.name:gsub("%%", "%%%%")))
        end
    end

    local function hookLabel(lbl)
        if protect.hooked[lbl] then return end
        protect.hooked[lbl] = lbl:GetPropertyChangedSignal("Text"):Connect(function()
            swapLabel(lbl)
        end)
        swapLabel(lbl)
    end

    local function protectOff()
        if not protect.on then return end
        protect.on = false
        if protect.added then
            protect.added:Disconnect()
            protect.added = nil
        end
        for lbl, conn in pairs(protect.hooked) do
            conn:Disconnect()
            if lbl.Parent and lbl.Text:find(protect.name, 1, true) then
                lbl.Text = lbl.Text:gsub(escape(protect.name), (LP.Name:gsub("%%", "%%%%")))
            end
        end
        protect.hooked = {}
    end

    local function protectOn()
        if protect.on then return end
        protect.on = true
        for _, d in ipairs(game:GetDescendants()) do
            if d:IsA("TextLabel") then hookLabel(d) end
        end
        protect.added = game.DescendantAdded:Connect(function(d)
            if d:IsA("TextLabel") then hookLabel(d) end
        end)
    end

    function F.nameProtect(on)
        if on then protectOn() else protectOff() end
    end

    function F.protectName(value)
        if value == "" then return end
        local wasOn = protect.on
        if wasOn then protectOff() end
        protect.name = value
        if wasOn then protectOn() end
    end

    function F.instamine(on)
        instamine = on
        local gm = LP.Character and LP.Character:FindFirstChild("Gamemode")
        if gm then gm.Value = on and 1 or 0 end
    end

    function F.fastBreak(on)
        if on then startLoop("fastbreak", 0, function() abb:InvokeServer() end) else stopLoop("fastbreak") end
    end

    function F.autoDrop(on)
        if not on then return stopLoop("drop") end
        startLoop("drop", 0, function() dropItem:InvokeServer(true) end)
    end

    local function runNuker(name, radius)
        startLoop(name, 0, function()
            local x, y, z = readCoords()
            if not x then return end
            if radius == 0 then
                bb:FireServer(x, y - 1, z)
                abb:InvokeServer()
                return
            end
            for ox = -radius, radius do
                for oy = -radius, radius do
                    for oz = -radius, radius do
                        task.spawn(function()
                            if loops[name] == nil then return end
                            bb:FireServer(x + ox, y - 1 + oy, z + oz)
                            abb:InvokeServer()
                        end)
                    end
                end
            end
        end)
    end

    function F.nuker(on)
        if on then runNuker("nuker", 0) else stopLoop("nuker") end
    end

    function F.nuker3(on)
        if on then runNuker("nuker3", 1) else stopLoop("nuker3") end
    end

    function F.nuker5(on)
        if on then runNuker("nuker5", 2) else stopLoop("nuker5") end
    end

    local function heldBlock()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local selected = char:FindFirstChild("SelectedSlot")
        if not selected then return end
        local slotGui = LP.PlayerGui.HUDGui.Inventory.Slots:FindFirstChild("Slot" .. selected.Value)
        local display = slotGui and slotGui:FindFirstChild("Slot") and slotGui.Slot:FindFirstChild("Display")
        local holder = display and display:FindFirstChild("SlotB")
        local first = holder and holder:GetChildren()[1]
        if not first then return end
        return first.Name, selected.Value
    end

    local function placeAt(world, px, py, pz, blockId, slot)
        local block, chunk = world.getBlock(px, py, pz)
        local free = block == nil
        if not free then
            for _, v in pairs(block) do
                if v == 0 then
                    free = true
                    break
                end
            end
        end
        if not free then return end
        world.placeBlock(px, py, pz, chunk, 1, blockId)
        local ok, name = placeRemote:InvokeServer(px, py, pz, slot, 1)
        if not ok then chunk:change(px % 16, py, pz % 16, name) end
    end

    local shapes = {
        single = { { 0, 0, 0 } },
        area = {},
        highwayX = {},
        highwayZ = {},
    }

    for ox = -1, 1 do
        for oz = -1, 1 do
            shapes.area[#shapes.area + 1] = { ox, 0, oz }
        end
    end

    for o = -2, 2 do
        shapes.highwayX[#shapes.highwayX + 1] = { o, 0, 0 }
        shapes.highwayZ[#shapes.highwayZ + 1] = { 0, 0, o }
        if o == -2 or o == 2 then
            shapes.highwayX[#shapes.highwayX + 1] = { o, 1, 0 }
            shapes.highwayZ[#shapes.highwayZ + 1] = { 0, 1, o }
        end
    end

    local scaffolds = {}

    local function setScaffold(name, shape, on)
        if scaffolds[name] then
            scaffolds[name]:Disconnect()
            scaffolds[name] = nil
        end
        if not on then return end
        local world, ids = worldRefs()
        if not world then return end
        local lbl = coordLabel()
        if not lbl then return notify("Coordinates label not found", 3) end
        scaffolds[name] = lbl:GetPropertyChangedSignal("Text"):Connect(function()
            local blockName, slot = heldBlock()
            if not blockName then return end
            local info = ids.ByName.Blocks[blockName]
            if not info then return end
            local x, y, z = readCoords()
            if not x then return end
            for _, o in ipairs(shape) do
                task.spawn(placeAt, world, x + o[1], y - 1 + o[2], z + o[3], info.id, slot)
            end
        end)
    end

    function F.scaffold(on) setScaffold("single", shapes.single, on) end
    function F.scaffold3(on) setScaffold("area", shapes.area, on) end
    function F.highwayX(on) setScaffold("hx", shapes.highwayX, on) end
    function F.highwayZ(on) setScaffold("hz", shapes.highwayZ, on) end

    function F.reloadChunks()
        local ok, err = pcall(function()
            local CWorld = require(LP.PlayerScripts.MainLocalScript.CWorld)
            for _, row in pairs(CWorld.RenderingChunks) do
                for _, chunk in pairs(row) do
                    for _, key in ipairs({ "BlockerPart", "vfold", "vlfold" }) do
                        if chunk[key] then pcall(function() chunk[key]:Destroy() end) end
                    end
                end
            end
            table.clear(CWorld.World)
            table.clear(CWorld.LoadingChunks)
            table.clear(CWorld.RenderingChunks)
            table.clear(CWorld.LoadingReqQueue)
            local queue = CWorld.ProcessingBlocks
            if typeof(queue) == "table" then
                if queue.clear then
                    pcall(function() queue:clear() end)
                elseif queue.Contents then
                    table.clear(queue.Contents)
                else
                    table.clear(queue)
                end
            end
        end)
        if not ok then notify("Reload failed: " .. tostring(err), 3) end
    end

    function F.chestDump()
        for i = 36, 62 do
            task.spawn(function() moveItem:InvokeServer(i, i - 27, true) end)
        end
    end

    function F.getLava()
        local x, y, z = readCoords()
        if x and useBlock then useBlock:InvokeServer(x, y - 2, z, 0) end
    end

    local function chestDupe(mode)
        if not sortItem then return end
        if mode == 1 then
            sortItem:InvokeServer(36)
        else
            for i = 36, 62 do
                task.spawn(function() sortItem:InvokeServer(i) end)
            end
        end
    end

    function F.dupeFirst() chestDupe(1) end
    function F.dupeAll() chestDupe(2) end

    function F.autoDupe(on)
        if on then startLoop("autodupe", 0, function() chestDupe(2) end) else stopLoop("autodupe") end
    end

    function F.dumpDupe()
        F.chestDump()
        chestDupe(2)
    end

    local function cursorCount()
        local hud = LP.PlayerGui:FindFirstChild("HUDGui")
        local slot = hud and hud.Inventory.Slots:FindFirstChild("Slot-1")
        local count = slot and slot:FindFirstChild("SlotNA") and slot.SlotNA:FindFirstChild("Count")
        return count and tonumber(count.Text)
    end

    local function heldItem()
        local char = LP.Character
        local selected = char and char:FindFirstChild("SelectedSlot")
        local inv = char and char:FindFirstChild("Inventory")
        if not selected or not inv then return nil end
        local data = decodeCounted(inv:FindFirstChild("Slot" .. selected.Value))
        if not data then return nil end
        return selected.Value, data
    end

    local function dupeHeld(quiet)
        local cursor = cursorCount()
        if cursor and cursor > 0 and cursor < 64 then
            moveItem:InvokeServer(-1, 82, true, -(64 - cursor))
            return true
        end
        local index, data = heldItem()
        if not index then
            if not quiet then notify("Hold an item in your hotbar first", 3) end
            return false
        end
        if data.count >= 64 then return true end
        moveItem:InvokeServer(index, 82, true, -(64 - data.count))
        return true
    end

    function F.dupeHeld()
        dupeHeld(false)
    end

    function F.autoDupeHeld(on)
        if on then startLoop("dupeheld", 0.25, function() dupeHeld(true) end) else stopLoop("dupeheld") end
    end

    function F.infiniteItems()
        local huge = -9.9999999992e100
        local cursor = cursorCount()
        if cursor and cursor > 0 then
            moveItem:InvokeServer(-1, 0, true, huge)
            return
        end
        local index = heldItem()
        if not index then return notify("Hold an item in your hotbar first", 3) end
        moveItem:InvokeServer(index, index == 0 and 1 or 0, true, huge)
    end

    function F.giveItem(name, amount)
        if not name or name == "" then return notify("Enter an item name", 3) end
        local admin = ReplicatedStorage:FindFirstChild("admingui")
        if admin then admin:FireServer(name, amount) end
    end

    function F.antiAfk(on)
        if not getconnections then return notify("getconnections is not supported", 3) end
        for _, c in ipairs(getconnections(LP.Idled)) do
            if on then c:Disable() else c:Enable() end
        end
    end

    local function remoteLoad(url)
        return function()
            local ok = pcall(function() loadstring(game:HttpGet(url, true))() end)
            if not ok then notify("Failed to load script", 3) end
        end
    end

    F.loadVape = remoteLoad("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua")
    F.loadDupeGui = remoteLoad("https://gist.githubusercontent.com/raw/b8d379c1e296ade8305c2fe4df652537")
    F.loadXrayGui = remoteLoad("https://raw.githubusercontent.com/screengui/archives/refs/heads/main/ORE%20ESP%20creepypro123")
    F.loadInfiniteYield = remoteLoad("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
    F.loadKeyboard = remoteLoad("https://raw.githubusercontent.com/advxzivhsjjdhxhsidifvsh/mobkeyboard/main/main.txt")
    F.loadRemoteSpy = remoteLoad("https://raw.githubusercontent.com/REDzHUB/RS/main/SimpleSpyMobile")

    function F.loadTexturePack()
        remoteLoad("https://raw.githubusercontent.com/screengui/bytehub/refs/heads/main/realtexturepack.lua")()
        F.reloadChunks()
    end

    function F.cleanup()
        running = false
        loops = {}
        for _, c in pairs(scaffolds) do c:Disconnect() end
        if airConn then airConn:Disconnect() end
        if cross.conn then cross.conn:Disconnect() end
        protectOff()
        pcall(function() platform:Destroy() end)
        if env.KetHubArmorLag then pcall(function() env.KetHubArmorLag:Disconnect() end) end
        pcall(function() LP.PlayerGui.invviewer:Destroy() end)
    end

    return F
end

local function createStartup()
    local gui = new("ScreenGui", {
        Name = "KetHub_Startup",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1001,
        Parent = CoreGui,
    })
    guis[#guis + 1] = gui

    local card = new("CanvasGroup", {
        Size = UDim2.fromOffset(380, 236),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = T.bg,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = gui,
    })
    corner(card, 14)
    stroke(card, T.accent, 1, 0.5)
    local cardScale = new("UIScale", { Scale = 0.92, Parent = card })

    local topLine = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = card,
    })
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.accent),
            ColorSequenceKeypoint.new(1, T.accent2),
        }),
        Parent = topLine,
    })

    local function makePage()
        return new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = card })
    end

    local loadingPage, keyPage, modePage = makePage(), makePage(), makePage()
    local S = {}

    local function show(page, w, h)
        tween(card, 0.15, { GroupTransparency = 1 })
        task.wait(0.17)
        loadingPage.Visible = page == loadingPage
        keyPage.Visible = page == keyPage
        modePage.Visible = page == modePage
        card.Size = UDim2.fromOffset(w, h)
        tween(card, 0.25, { GroupTransparency = 0 })
    end

    makeAvatar(loadingPage, 62, UDim2.fromOffset(20, 26), "me")
    makeGameIcon(loadingPage, 46, UDim2.new(1, -66, 0, 26))
    label({
        Size = UDim2.new(1, -190, 0, 24),
        Position = UDim2.fromOffset(96, 26),
        Text = LP.DisplayName,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = loadingPage,
    })
    label({
        Size = UDim2.new(1, -190, 0, 16),
        Position = UDim2.fromOffset(96, 50),
        Text = "@" .. LP.Name,
        TextSize = 12,
        TextColor3 = T.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = loadingPage,
    })
    label({
        Size = UDim2.new(1, -110, 0, 16),
        Position = UDim2.fromOffset(96, 70),
        Text = HUB .. "  |  " .. gameName,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.accent,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = loadingPage,
    })

    local function pill(x, title)
        local f = new("Frame", {
            Size = UDim2.fromOffset(165, 34),
            Position = UDim2.fromOffset(x, 108),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            Parent = loadingPage,
        })
        corner(f, 8)
        label({
            Size = UDim2.fromOffset(50, 34),
            Position = UDim2.fromOffset(12, 0),
            Text = title,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = T.dim,
            Parent = f,
        })
        return label({
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.fromOffset(58, 0),
            Text = "--",
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = f,
        })
    end

    local pingVal = pill(20, "PING")
    local fpsVal = pill(195, "FPS")

    local bar = new("Frame", {
        Size = UDim2.fromOffset(340, 6),
        Position = UDim2.fromOffset(20, 162),
        BackgroundColor3 = T.off,
        BorderSizePixel = 0,
        Parent = loadingPage,
    })
    corner(bar, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = bar })
    corner(fill, 3)
    local status = label({
        Size = UDim2.fromOffset(260, 18),
        Position = UDim2.fromOffset(20, 174),
        Text = "Starting...",
        TextSize = 11,
        TextColor3 = T.dim,
        Parent = loadingPage,
    })
    label({
        Size = UDim2.fromOffset(70, 18),
        Position = UDim2.fromOffset(290, 174),
        Text = VERSION,
        TextSize = 11,
        TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = loadingPage,
    })

    task.spawn(function()
        while running and gui.Parent do
            pingVal.Text = stats.ping .. " ms"
            pingVal.TextColor3 = pingColor(stats.ping)
            fpsVal.Text = tostring(stats.fps)
            fpsVal.TextColor3 = fpsColor(stats.fps)
            task.wait(0.2)
        end
    end)

    local keyEvent = Instance.new("BindableEvent")
    local modeEvent = Instance.new("BindableEvent")

    makeGameIcon(keyPage, 40, UDim2.fromOffset(20, 18))
    label({
        Size = UDim2.fromOffset(250, 22),
        Position = UDim2.fromOffset(70, 18),
        Text = HUB,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Parent = keyPage,
    })
    label({
        Size = UDim2.fromOffset(250, 16),
        Position = UDim2.fromOffset(70, 42),
        Text = "Key System  |  " .. gameName,
        TextSize = 11,
        TextColor3 = T.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = keyPage,
    })
    label({
        Size = UDim2.fromOffset(340, 34),
        Position = UDim2.fromOffset(20, 74),
        Text = "Join our Discord server and open the Key tab to get your key.",
        TextSize = 12,
        TextColor3 = T.dim,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = keyPage,
    })

    local keyBox = new("TextBox", {
        Size = UDim2.fromOffset(340, 40),
        Position = UDim2.fromOffset(20, 114),
        BackgroundColor3 = T.card,
        Text = "",
        PlaceholderText = "Enter your key",
        PlaceholderColor3 = T.dim,
        TextColor3 = T.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        Parent = keyPage,
    })
    corner(keyBox, 8)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = keyBox })
    local keyStroke = stroke(keyBox, T.line, 1, 0)
    keyBox.Focused:Connect(function() tween(keyStroke, 0.12, { Color = T.accent }) end)
    keyBox.FocusLost:Connect(function() tween(keyStroke, 0.12, { Color = T.line }) end)

    local checkBtn = new("TextButton", {
        Size = UDim2.fromOffset(222, 40),
        Position = UDim2.fromOffset(20, 164),
        BackgroundColor3 = T.accent,
        Text = "Check Key",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = keyPage,
    })
    corner(checkBtn, 8)

    local getBtn = new("TextButton", {
        Size = UDim2.fromOffset(110, 40),
        Position = UDim2.fromOffset(250, 164),
        BackgroundColor3 = T.card2,
        Text = "Get Key",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = T.text,
        BorderSizePixel = 0,
        Parent = keyPage,
    })
    corner(getBtn, 8)

    local keyStatus = label({
        Size = UDim2.fromOffset(340, 18),
        Position = UDim2.fromOffset(20, 212),
        Text = "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = keyPage,
    })

    local linkBtn = new("TextButton", {
        Size = UDim2.fromOffset(340, 18),
        Position = UDim2.fromOffset(20, 238),
        BackgroundTransparency = 1,
        Text = "discord.gg/WXWyuDQsD",
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = T.accent2,
        Parent = keyPage,
    })

    local function copyInvite()
        if type(setclipboard) == "function" then
            pcall(setclipboard, DISCORD)
            keyStatus.Text = "Discord link copied"
            keyStatus.TextColor3 = T.good
        else
            keyStatus.Text = DISCORD
            keyStatus.TextColor3 = T.accent2
        end
    end

    getBtn.MouseButton1Click:Connect(copyInvite)
    linkBtn.MouseButton1Click:Connect(copyInvite)

    local function shake()
        local base = card.Position
        for _, dx in ipairs({ 9, -9, 6, -6, 3, 0 }) do
            card.Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset)
            task.wait(0.04)
        end
    end

    local checking = false
    local function submitKey()
        if checking then return end
        checking = true
        local typed = (keyBox.Text:gsub("%s", ""))
        if typed == KEY then
            keyStatus.Text = "Key accepted"
            keyStatus.TextColor3 = T.good
            writeFile(KEYFILE, KEY)
            task.wait(0.5)
            keyEvent:Fire()
        else
            keyStatus.Text = typed == "" and "Enter a key first" or "Wrong key, try again"
            keyStatus.TextColor3 = T.bad
            shake()
        end
        checking = false
    end

    checkBtn.MouseButton1Click:Connect(submitKey)
    keyBox.FocusLost:Connect(function(enter)
        if enter then submitKey() end
    end)

    label({
        Size = UDim2.fromOffset(380, 24),
        Position = UDim2.fromOffset(20, 18),
        Text = "Choose your interface",
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        Parent = modePage,
    })
    label({
        Size = UDim2.fromOffset(380, 16),
        Position = UDim2.fromOffset(20, 44),
        Text = "Saved for next time. You can change it in Settings.",
        TextSize = 11,
        TextColor3 = T.dim,
        Parent = modePage,
    })

    local recommended = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and "Mobile" or "PC"

    local function modeCard(x, name, sub, lines)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(180, 150),
            Position = UDim2.fromOffset(x, 80),
            BackgroundColor3 = T.card,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = modePage,
        })
        corner(btn, 12)
        local line = stroke(btn, name == recommended and T.accent or T.line, 1.5, 0)
        label({
            Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.fromOffset(0, 18),
            Text = name,
            Font = Enum.Font.GothamBlack,
            TextSize = 30,
            TextColor3 = T.accent,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = btn,
        })
        label({
            Size = UDim2.new(1, -20, 0, 18),
            Position = UDim2.fromOffset(10, 64),
            Text = sub,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = btn,
        })
        label({
            Size = UDim2.new(1, -24, 0, 34),
            Position = UDim2.fromOffset(12, 86),
            Text = lines,
            TextSize = 11,
            TextColor3 = T.dim,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = btn,
        })
        if name == recommended then
            local tag = new("Frame", {
                Size = UDim2.fromOffset(104, 20),
                Position = UDim2.new(0.5, -52, 1, -28),
                BackgroundColor3 = T.accent,
                BackgroundTransparency = 0.8,
                BorderSizePixel = 0,
                Parent = btn,
            })
            corner(tag, 10)
            label({
                Size = UDim2.new(1, 0, 1, 0),
                Text = "RECOMMENDED",
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = T.accent,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = tag,
            })
        end
        btn.MouseEnter:Connect(function()
            tween(btn, 0.12, { BackgroundColor3 = T.card2 })
            tween(line, 0.12, { Color = T.accent })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.12, { BackgroundColor3 = T.card })
            tween(line, 0.12, { Color = name == recommended and T.accent or T.line })
        end)
        btn.MouseButton1Click:Connect(function()
            modeEvent:Fire(name)
        end)
    end

    modeCard(20, "PC", "Keyboard and mouse", "Wide menu, hotkeys for every feature")
    modeCard(220, "Mobile", "Touch controls", "Bigger buttons and movable quick buttons")

    function S.setStatus(text, fraction)
        status.Text = text
        if fraction then tween(fill, 0.25, { Size = UDim2.new(fraction, 0, 1, 0) }) end
    end

    function S.begin()
        loadingPage.Visible = true
        tween(card, 0.4, { GroupTransparency = 0 })
        tween(cardScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    end

    function S.fail(message)
        status.Text = message
        status.TextColor3 = T.bad
        fill.BackgroundColor3 = T.bad
        task.wait(4)
        tween(card, 0.3, { GroupTransparency = 1 })
        task.wait(0.35)
        gui:Destroy()
    end

    function S.hasSavedKey()
        local saved = readFile(KEYFILE)
        return saved ~= nil and (saved:gsub("%s", "")) == KEY
    end

    function S.askKey()
        show(keyPage, 380, 268)
        keyEvent.Event:Wait()
    end

    function S.askMode()
        show(modePage, 420, 250)
        return modeEvent.Event:Wait()
    end

    function S.close()
        tween(card, 0.3, { GroupTransparency = 1 })
        tween(cardScale, 0.3, { Scale = 1.05 })
        task.wait(0.35)
        gui:Destroy()
    end

    return S
end

local PALETTE = {
    Color3.fromRGB(188, 50, 252), Color3.fromRGB(255, 70, 70),
    Color3.fromRGB(70, 150, 255), Color3.fromRGB(60, 220, 100),
    Color3.fromRGB(255, 220, 50), Color3.fromRGB(80, 220, 220),
    Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 105, 180),
    Color3.fromRGB(255, 255, 255),
}

local function snapNumber(v, min, max, step)
    v = math.floor(v / step + 0.5) * step
    return math.clamp(v, min, max)
end

local function buildHub(mode, F, switchMode, unload)
    local old = CoreGui:FindFirstChild("KetHub_Main")
    if old then old:Destroy() end

    local mobile = mode == "Mobile"
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local W = mobile and math.min(560, vp.X - 20) or math.min(660, vp.X - 20)
    local H = mobile and math.min(340, vp.Y - 20) or math.min(460, vp.Y - 20)
    local compact = W < 520
    local SIDE = compact and 98 or 144
    local TOP = mobile and 46 or 44
    local ROW = mobile and 46 or 40
    local ROWD = mobile and 56 or 48
    local KNOB = mobile and 20 or 16
    local BTN_H = mobile and 36 or 30

    local gui = new("ScreenGui", {
        Name = "KetHub_Main",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        Parent = CoreGui,
    })

    local win = new("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(W, H),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = T.bg,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        Parent = gui,
    })
    corner(win, 10)
    stroke(win, T.line, 1, 0)
    local winScale = new("UIScale", { Scale = 1, Parent = win })

    local stateItems, quickItems, indicators = {}, {}, {}

    local topbar = new("Frame", {
        Size = UDim2.new(1, 0, 0, TOP),
        BackgroundColor3 = T.side,
        BorderSizePixel = 0,
        Parent = win,
    })
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = T.line,
        BorderSizePixel = 0,
        Parent = topbar,
    })
    makeGameIcon(topbar, 30, UDim2.fromOffset(10, (TOP - 30) / 2))
    label({
        Size = UDim2.new(1, -110, 0, 20),
        Position = UDim2.fromOffset(48, 5),
        Text = HUB,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        Parent = topbar,
    })
    label({
        Size = UDim2.new(1, -110, 0, 14),
        Position = UDim2.fromOffset(48, 25),
        Text = gameName .. "  |  " .. VERSION,
        TextSize = 10,
        TextColor3 = T.dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = topbar,
    })
    local closeBtn = new("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -40, 0.5, -15),
        BackgroundColor3 = T.card,
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = T.dim,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = topbar,
    })
    corner(closeBtn, 8)
    closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.12, { BackgroundColor3 = T.bad, TextColor3 = Color3.new(1, 1, 1) }) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.12, { BackgroundColor3 = T.card, TextColor3 = T.dim }) end)
    makeDraggable(topbar, win)

    local side = new("Frame", {
        Size = UDim2.new(0, SIDE, 1, -TOP),
        Position = UDim2.fromOffset(0, TOP),
        BackgroundColor3 = T.side,
        BorderSizePixel = 0,
        Parent = win,
    })
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = T.line,
        BorderSizePixel = 0,
        Parent = side,
    })

    local searchH = mobile and 36 or 32
    local searchBox = new("TextBox", {
        Size = UDim2.new(1, -16, 0, searchH),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = T.card,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = T.dim,
        TextColor3 = T.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        Parent = side,
    })
    corner(searchBox, 8)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), Parent = searchBox })
    local searchStroke = stroke(searchBox, T.line, 1, 0)
    searchBox.Focused:Connect(function() tween(searchStroke, 0.12, { Color = T.accent }) end)
    searchBox.FocusLost:Connect(function() tween(searchStroke, 0.12, { Color = T.line }) end)

    local tabHolder = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -(searchH + 50)),
        Position = UDim2.fromOffset(0, searchH + 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = side,
    })
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tabHolder })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabHolder })

    local footer = label({
        Size = UDim2.new(1, -16, 0, 30),
        Position = UDim2.new(0, 10, 1, -34),
        Text = "",
        TextSize = 10,
        TextColor3 = T.dim,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = side,
    })

    local function refreshFooter()
        footer.Text = mobile and "Tap the round button to open or close" or ("[" .. menuKey.Name .. "] show / hide")
    end

    local content = new("Frame", {
        Size = UDim2.new(1, -(SIDE + 16), 1, -(TOP + 12)),
        Position = UDim2.fromOffset(SIDE + 8, TOP + 8),
        BackgroundTransparency = 1,
        Parent = win,
    })

    local tabNames = { "Home", "Combat", "Player", "Visuals", "World", "Dupe", "Others", "Settings", "Configs", "Credits" }
    local tabButtons, pages, orders = {}, {}, {}
    local pageByName, tabNameOf = {}, {}
    local currentTab = 1
    local searchActive = false
    local entries = {}
    local currentSection = {}

    local function nextOrder(page)
        orders[page] = (orders[page] or 0) + 1
        return orders[page]
    end

    local function makePage()
        local page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = mobile and 5 or 4,
            ScrollBarImageColor3 = T.accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false,
            Parent = content,
        })
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
        new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = page })
        return page
    end

    local searchPage = makePage()
    local searchTitle = label({
        Size = UDim2.new(1, 0, 0, 24),
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.dim,
        LayoutOrder = 0,
        Parent = searchPage,
    })
    local searchHint = label({
        Size = UDim2.new(1, 0, 0, 40),
        Text = "Nothing found. Try: kill, speed, dupe, esp",
        TextSize = 12,
        TextColor3 = T.dim,
        TextWrapped = true,
        LayoutOrder = 1,
        Visible = false,
        Parent = searchPage,
    })

    local function renderTab()
        for i, p in ipairs(pages) do p.Visible = i == currentTab end
        for i, b in ipairs(tabButtons) do
            local active = i == currentTab
            tween(b.btn, 0.12, { BackgroundTransparency = active and 0.82 or 1 })
            b.btn.TextColor3 = active and T.text or T.dim
            b.bar.Visible = active
        end
    end

    local function restoreRows()
        for _, e in ipairs(entries) do
            e.row.Parent = e.page
            e.row.LayoutOrder = e.order
            e.row.Visible = not (e.sec and e.sec.collapsed)
        end
    end

    local function setTab(idx)
        currentTab = idx
        if searchActive then
            searchActive = false
            restoreRows()
            searchPage.Visible = false
            searchBox.Text = ""
        end
        renderTab()
    end

    for i, name in ipairs(tabNames) do
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, mobile and 40 or 36),
            BackgroundColor3 = T.accent,
            BackgroundTransparency = 1,
            Text = name,
            Font = Enum.Font.GothamMedium,
            TextSize = compact and 12 or 13,
            TextColor3 = T.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = tabHolder,
        })
        new("UIPadding", { PaddingLeft = UDim.new(0, compact and 10 or 14), Parent = btn })
        corner(btn, 8)
        local bar = new("Frame", {
            Size = UDim2.fromOffset(3, 16),
            Position = UDim2.new(0, -8, 0.5, -8),
            BackgroundColor3 = T.accent,
            BorderSizePixel = 0,
            Visible = false,
            Parent = btn,
        })
        corner(bar, 2)
        btn.MouseButton1Click:Connect(function() setTab(i) end)
        tabButtons[i] = { btn = btn, bar = bar }
        local page = makePage()
        pages[i] = page
        pageByName[name] = page
        tabNameOf[page] = name
    end

    local function runSearch()
        local q = string.lower(searchBox.Text)
        q = (q:gsub("^%s+", ""))
        q = (q:gsub("%s+$", ""))

        if q == "" then
            if searchActive then
                searchActive = false
                restoreRows()
                searchPage.Visible = false
                renderTab()
            end
            return
        end

        searchActive = true
        restoreRows()
        for _, p in ipairs(pages) do p.Visible = false end
        for _, b in ipairs(tabButtons) do
            b.btn.BackgroundTransparency = 1
            b.btn.TextColor3 = T.dim
            b.bar.Visible = false
        end
        searchPage.Visible = true

        local count = 0
        for _, e in ipairs(entries) do
            if e.text:find(q, 1, true) then
                count = count + 1
                e.row.Parent = searchPage
                e.row.LayoutOrder = count + 1
                e.row.Visible = true
            end
        end
        searchTitle.Text = count > 0 and (count .. (count == 1 and " RESULT" or " RESULTS")) or "NO RESULTS"
        searchHint.Visible = count == 0
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(runSearch)

    local function registerRow(page, row, title, desc, kw)
        local sec = currentSection[page]
        entries[#entries + 1] = {
            row = row,
            page = page,
            order = row.LayoutOrder,
            sec = sec,
            text = string.lower(title .. " " .. (desc or "") .. " " .. (kw or "") .. " " .. (sec and sec.name or "") .. " " .. (tabNameOf[page] or "")),
        }
        if sec then sec.rows[#sec.rows + 1] = row end
    end

    local function section(page, text)
        local sec = { rows = {}, collapsed = false, name = text }
        currentSection[page] = sec
        local header = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        label({
            Size = UDim2.new(1, -30, 1, 0),
            Text = string.upper(text),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = T.dim,
            Parent = header,
        })
        local arrow = label({
            Size = UDim2.fromOffset(22, 28),
            Position = UDim2.new(1, -26, 0, 0),
            Text = "-",
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = T.dim,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = header,
        })
        header.MouseButton1Click:Connect(function()
            sec.collapsed = not sec.collapsed
            arrow.Text = sec.collapsed and "+" or "-"
            for _, r in ipairs(sec.rows) do r.Visible = not sec.collapsed end
        end)
    end

    local function flat(page, text)
        currentSection[page] = nil
        label({
            Size = UDim2.new(1, 0, 0, 26),
            Text = string.upper(text),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = T.dim,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
    end

    local function titleBlock(row, title, desc, rightPad)
        if desc then
            label({ Size = UDim2.new(1, -rightPad, 0, 22), Position = UDim2.fromOffset(12, 6), Text = title, Parent = row })
            label({
                Size = UDim2.new(1, -rightPad, 0, 14),
                Position = UDim2.fromOffset(12, 27),
                Text = desc,
                TextSize = 10,
                TextColor3 = T.dim,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
        else
            label({ Size = UDim2.new(1, -rightPad, 1, 0), Position = UDim2.fromOffset(12, 0), Text = title, Parent = row })
        end
    end

    local function makeSwitch(parent, pos)
        local sw = new("Frame", {
            Size = UDim2.fromOffset(40, 22),
            Position = pos,
            BackgroundColor3 = T.off,
            BorderSizePixel = 0,
            Parent = parent,
        })
        corner(sw, 11)
        local dot = new("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = sw,
        })
        corner(dot, 8)
        return function(on, animate)
            local color = on and T.accent or T.off
            local pos2 = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            if animate then
                tween(sw, 0.15, { BackgroundColor3 = color })
                tween(dot, 0.15, { Position = pos2 })
            else
                sw.BackgroundColor3 = color
                dot.Position = pos2
            end
        end
    end

    local popup = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 50,
        Parent = win,
    })
    local popupCard = new("Frame", {
        Size = UDim2.fromOffset(math.min(300, W - 40), math.min(320, H - 50)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = T.card,
        BorderSizePixel = 0,
        Active = true,
        Parent = popup,
    })
    corner(popupCard, 12)
    stroke(popupCard, T.line, 1, 0)
    local popupTitle = label({
        Size = UDim2.new(1, -24, 0, 30),
        Position = UDim2.fromOffset(14, 6),
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = popupCard,
    })
    local popupList = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -48),
        Position = UDim2.fromOffset(8, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = popupCard,
    })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = popupList })
    local quickPanel = new("Frame", {
        Size = UDim2.new(1, -24, 1, -52),
        Position = UDim2.fromOffset(12, 44),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = popupCard,
    })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = quickPanel })

    local function closePopup()
        popup.Visible = false
        binder.capture = nil
    end

    popup.MouseButton1Click:Connect(closePopup)

    local function openPopup(title, values, current, onPick)
        popupTitle.Text = title
        quickPanel.Visible = false
        popupList.Visible = true
        popupCard.Size = UDim2.fromOffset(math.min(300, W - 40), math.min(320, H - 50))
        for _, c in ipairs(popupList:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        if #values == 0 then
            label({
                Size = UDim2.new(1, 0, 0, 34),
                Text = "No options available",
                TextColor3 = T.dim,
                LayoutOrder = 1,
                Parent = popupList,
            })
        end
        for i, v in ipairs(values) do
            local selected = v == current
            local opt = new("TextButton", {
                Size = UDim2.new(1, 0, 0, mobile and 42 or 36),
                BackgroundColor3 = selected and T.accent or T.card2,
                BackgroundTransparency = selected and 0.7 or 0,
                Text = v,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = T.text,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = i,
                Parent = popupList,
            })
            corner(opt, 8)
            opt.MouseButton1Click:Connect(function()
                closePopup()
                onPick(v)
            end)
        end
        popup.Visible = true
    end

    local function refreshIndicator(id)
        if indicators[id] then indicators[id]() end
    end

    local function openQuick(id, title)
        for _, c in ipairs(quickPanel:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        popupTitle.Text = title
        popupList.Visible = false
        quickPanel.Visible = true
        popupCard.Size = UDim2.fromOffset(math.min(300, W - 40), mobile and 168 or 214)

        local rowH = mobile and 54 or 48
        local pinRow = new("TextButton", {
            Size = UDim2.new(1, 0, 0, rowH),
            BackgroundColor3 = T.card2,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Parent = quickPanel,
        })
        corner(pinRow, 8)
        label({ Size = UDim2.new(1, -70, 0, 20), Position = UDim2.fromOffset(12, 7), Text = "Floating button", Parent = pinRow })
        label({
            Size = UDim2.new(1, -70, 0, 14),
            Position = UDim2.fromOffset(12, 28),
            Text = "Round button you can move",
            TextSize = 10,
            TextColor3 = T.dim,
            Parent = pinRow,
        })
        local paint = makeSwitch(pinRow, UDim2.new(1, -54, 0.5, -11))
        paint(Quick.buttons[id] ~= nil, false)
        pinRow.MouseButton1Click:Connect(function()
            if Quick.buttons[id] then
                Quick.remove(id)
            else
                local meta = Quick.meta[id]
                Quick.add(id, meta.title, meta.short)
            end
            paint(Quick.buttons[id] ~= nil, true)
            refreshIndicator(id)
        end)

        if not mobile then
            local keyRow = new("Frame", {
                Size = UDim2.new(1, 0, 0, rowH),
                BackgroundColor3 = T.card2,
                BorderSizePixel = 0,
                LayoutOrder = 2,
                Parent = quickPanel,
            })
            corner(keyRow, 8)
            label({ Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(12, 7), Text = "Keybind", Parent = keyRow })
            label({
                Size = UDim2.new(1, -140, 0, 14),
                Position = UDim2.fromOffset(12, 28),
                Text = "Backspace clears it",
                TextSize = 10,
                TextColor3 = T.dim,
                Parent = keyRow,
            })
            local kbtn = new("TextButton", {
                Size = UDim2.fromOffset(112, BTN_H),
                Position = UDim2.new(1, -122, 0.5, -BTN_H / 2),
                BackgroundColor3 = T.card,
                Text = prefs.binds[id] or "None",
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = T.accent,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = keyRow,
            })
            corner(kbtn, 6)
            kbtn.MouseButton1Click:Connect(function()
                kbtn.Text = "press a key..."
                kbtn.TextColor3 = T.warn
                binder.capture = function(kc)
                    if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
                        prefs.binds[id] = nil
                    elseif kc == menuKey or (panicKey and kc == panicKey) then
                        notify("That key is reserved", 2)
                    elseif kc ~= Enum.KeyCode.Escape and kc ~= Enum.KeyCode.Unknown then
                        for other, name in pairs(prefs.binds) do
                            if name == kc.Name and other ~= id then
                                prefs.binds[other] = nil
                                refreshIndicator(other)
                            end
                        end
                        prefs.binds[id] = kc.Name
                    end
                    rebuildBinds()
                    savePrefs()
                    kbtn.Text = prefs.binds[id] or "None"
                    kbtn.TextColor3 = T.accent
                    refreshIndicator(id)
                end
            end)
        end

        local done = new("TextButton", {
            Size = UDim2.new(1, 0, 0, BTN_H + 4),
            BackgroundColor3 = T.accent,
            Text = "Done",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            LayoutOrder = 3,
            Parent = quickPanel,
        })
        corner(done, 8)
        done.MouseButton1Click:Connect(closePopup)
        popup.Visible = true
    end

    local function quickButton(row, id, title, x)
        local qbtn = new("TextButton", {
            Size = UDim2.fromOffset(34, 28),
            Position = UDim2.new(1, x, 0.5, -14),
            BackgroundColor3 = T.card2,
            Text = "...",
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = T.dim,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(qbtn, 8)
        indicators[id] = function()
            local on = Quick.buttons[id] ~= nil or prefs.binds[id] ~= nil
            qbtn.TextColor3 = on and T.accent or T.dim
        end
        indicators[id]()
        qbtn.MouseButton1Click:Connect(function() openQuick(id, title) end)
    end

    local function toggle(page, id, title, desc, cb, kw, opts)
        opts = opts or {}
        local value = opts.initial or false
        local locked = opts.locked
        local quick = id ~= nil and opts.quick ~= false and not locked
        local row = new("TextButton", {
            Size = UDim2.new(1, 0, 0, desc and ROWD or ROW),
            BackgroundColor3 = T.card,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        titleBlock(row, title, desc, locked and 150 or (quick and 128 or 76))

        local paint
        if locked then
            label({
                Size = UDim2.fromOffset(110, 20),
                Position = UDim2.new(1, -122, 0.5, -10),
                Text = "ONLY FOR TESTERS",
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = T.warn,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = row,
            })
        else
            paint = makeSwitch(row, UDim2.new(1, -54, 0.5, -11))
            paint(value, false)
        end

        if quick then
            Quick.meta[id] = { title = title, short = opts.short or shortOf(title) }
            quickButton(row, id, title, -96)
        end

        local function set(v, silent)
            if locked then return end
            value = v and true or false
            paint(value, not silent)
            Quick.sync(id, value)
            if not silent then fire(cb, value) end
        end

        row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.card2 }) end)
        row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = T.card }) end)
        row.MouseButton1Click:Connect(function()
            if locked then return notify("Only for testers", 2) end
            set(not value)
        end)

        if id and not locked then
            stateItems[id] = { kind = "bool", get = function() return value end, set = set, default = false }
        end
        if quick then
            quickItems[id] = { kind = "toggle", title = title, get = function() return value end, set = set }
        end
        registerRow(page, row, title, desc, kw)
    end

    local function buildSlider(row, min, max, step, fmt, barY, rightMargin, boxY, getV, setV)
        local bar = new("Frame", {
            Size = UDim2.new(1, -(12 + rightMargin), 0, 6),
            Position = UDim2.fromOffset(12, barY),
            BackgroundColor3 = T.off,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(bar, 3)
        local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = bar })
        corner(fill, 3)
        local knob = new("Frame", {
            Size = UDim2.fromOffset(KNOB, KNOB),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = bar,
        })
        corner(knob, KNOB / 2)
        local hit = new("TextButton", {
            Size = UDim2.new(1, -rightMargin, 0, mobile and 36 or 30),
            Position = UDim2.fromOffset(6, barY - (mobile and 15 or 12)),
            BackgroundTransparency = 1,
            Text = "",
            Parent = row,
        })
        local box = new("TextBox", {
            Size = UDim2.fromOffset(60, 24),
            Position = UDim2.new(1, -72, 0, boxY),
            BackgroundColor3 = T.card2,
            Text = "",
            TextColor3 = T.accent,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            ClearTextOnFocus = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(box, 6)

        local function refresh()
            local frac = math.clamp((getV() - min) / (max - min), 0, 1)
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, -KNOB / 2, 0.5, -KNOB / 2)
            box.Text = fmt(getV())
        end

        local function fromX(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            setV(snapNumber(min + rel * (max - min), min, max, step))
            refresh()
        end

        box.FocusLost:Connect(function()
            local n = tonumber(string.match(box.Text, "-?%d+%.?%d*"))
            if n then setV(snapNumber(n, min, max, step)) end
            refresh()
        end)

        local dragging, scroller = false, nil
        hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                scroller = row:FindFirstAncestorOfClass("ScrollingFrame")
                if scroller then scroller.ScrollingEnabled = false end
                fromX(input.Position.X)
            end
        end)
        keep(UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end))
        keep(UIS.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if scroller then scroller.ScrollingEnabled = true end
            end
        end))
        refresh()
        return refresh
    end

    local function slider(page, id, title, desc, min, max, step, default, fmt, cb, kw)
        local value = default
        local height = desc and (mobile and 74 or 66) or (mobile and 64 or 56)
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        if desc then
            label({ Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(12, 5), Text = title, Parent = row })
            label({
                Size = UDim2.new(1, -90, 0, 14),
                Position = UDim2.fromOffset(12, 25),
                Text = desc,
                TextSize = 10,
                TextColor3 = T.dim,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
        else
            label({ Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(12, 5), Text = title, Parent = row })
        end
        local barY = height - (mobile and 18 or 15)
        local refresh = buildSlider(row, min, max, step, fmt, barY, 24, 5,
            function() return value end,
            function(v)
                if v ~= value then
                    value = v
                    fire(cb, v)
                end
            end)
        if id then
            stateItems[id] = {
                kind = "number",
                get = function() return value end,
                set = function(v, silent)
                    value = snapNumber(v, min, max, step)
                    refresh()
                    if not silent then fire(cb, value) end
                end,
                default = default,
            }
        end
        registerRow(page, row, title, desc, kw)
    end

    local function input(page, id, title, desc, default, placeholder, cb, kw)
        local value = default or ""
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, desc and ROWD or ROW),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        titleBlock(row, title, desc, 156)
        local box = new("TextBox", {
            Size = UDim2.fromOffset(136, BTN_H),
            Position = UDim2.new(1, -146, 0.5, -BTN_H / 2),
            BackgroundColor3 = T.card2,
            Text = value,
            PlaceholderText = placeholder or "",
            PlaceholderColor3 = T.dim,
            TextColor3 = T.text,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            ClearTextOnFocus = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(box, 6)
        new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })
        box.FocusLost:Connect(function()
            value = box.Text
            fire(cb, value)
        end)
        if id then
            stateItems[id] = {
                kind = "string",
                get = function() return value end,
                set = function(v, silent)
                    value = tostring(v)
                    box.Text = value
                    if not silent then fire(cb, value) end
                end,
                default = default or "",
            }
        end
        registerRow(page, row, title, desc, kw)
    end

    local function dropdown(page, id, title, desc, getValues, default, cb, kw)
        local value = default
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, desc and ROWD or ROW),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        titleBlock(row, title, desc, 166)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(146, BTN_H),
            Position = UDim2.new(1, -156, 0.5, -BTN_H / 2),
            BackgroundColor3 = T.card2,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(btn, 6)
        local shown = label({
            Size = UDim2.new(1, -28, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            Text = value or "Select",
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = btn,
        })
        label({
            Size = UDim2.fromOffset(18, BTN_H),
            Position = UDim2.new(1, -22, 0, 0),
            Text = "v",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = T.dim,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = btn,
        })
        local function set(v, silent)
            value = v
            shown.Text = v or "Select"
            if not silent then fire(cb, v) end
        end
        btn.MouseButton1Click:Connect(function()
            openPopup(title, getValues(), value, function(choice) set(choice) end)
        end)
        if id then
            stateItems[id] = { kind = "string", get = function() return value end, set = set, default = default }
        end
        registerRow(page, row, title, desc, kw)
    end

    local function swatches(page, id, title, default, cb)
        local value = default
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, mobile and 74 or 66),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        label({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 5), Text = title, Parent = row })
        local holder = new("Frame", {
            Size = UDim2.new(1, -24, 0, 32),
            Position = UDim2.fromOffset(12, mobile and 34 or 31),
            BackgroundTransparency = 1,
            Parent = row,
        })
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = holder,
        })
        local rings = {}
        local function refresh()
            for col, ring in pairs(rings) do ring.Transparency = col == value and 0 or 1 end
        end
        local function set(v, silent)
            value = v
            refresh()
            if not silent then fire(cb, v) end
        end
        for i, col in ipairs(PALETTE) do
            local sw = new("TextButton", {
                Size = UDim2.fromOffset(mobile and 30 or 26, mobile and 30 or 26),
                BackgroundColor3 = col,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = i,
                Parent = holder,
            })
            corner(sw, UDim.new(1, 0))
            rings[col] = new("UIStroke", {
                Color = Color3.new(1, 1, 1),
                Thickness = 2,
                Transparency = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Parent = sw,
            })
            sw.MouseButton1Click:Connect(function() set(col) end)
        end
        refresh()
        stateItems[id] = { kind = "color", get = function() return value end, set = set, default = default }
        registerRow(page, row, title, "color", "colour crosshair gun")
    end

    local function button(page, id, title, desc, cb, kw, text, danger)
        local quick = id ~= nil
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, desc and ROWD or ROW),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        titleBlock(row, title, desc, quick and 170 or 120)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(88, BTN_H),
            Position = UDim2.new(1, -98, 0.5, -BTN_H / 2),
            BackgroundColor3 = danger and T.bad or T.accent,
            Text = text or "Run",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(btn, 8)
        btn.MouseButton1Click:Connect(function() fire(cb) end)
        if quick then
            Quick.meta[id] = { title = title, short = shortOf(title) }
            quickItems[id] = { kind = "action", title = title, run = function() fire(cb) end }
            quickButton(row, id, title, -140)
        end
        registerRow(page, row, title, desc, kw)
    end

    local function keyBindRow(page, title, desc, getName, onSet, allowClear, kw)
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, ROWD),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(page),
            Parent = page,
        })
        corner(row, 8)
        titleBlock(row, title, desc, 166)
        local kbtn = new("TextButton", {
            Size = UDim2.fromOffset(136, BTN_H),
            Position = UDim2.new(1, -146, 0.5, -BTN_H / 2),
            BackgroundColor3 = T.card2,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        corner(kbtn, 6)
        local function show(capturing)
            kbtn.Text = capturing and "press a key..." or (getName() or "None")
            kbtn.TextColor3 = capturing and T.warn or T.accent
        end
        show(false)
        kbtn.MouseButton1Click:Connect(function()
            show(true)
            binder.capture = function(kc)
                if (kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete) and allowClear then
                    onSet(nil)
                elseif kc ~= Enum.KeyCode.Escape and kc ~= Enum.KeyCode.Unknown then
                    onSet(kc)
                end
                show(false)
                refreshFooter()
            end
        end)
        registerRow(page, row, title, desc, kw)
    end

    local function int(v) return tostring(math.floor(v + 0.5)) end
    local function dec(v) return string.format("%.2f", v) end

    do
        local p = pageByName.Home
        flat(p, "Welcome")
        local prof = new("Frame", {
            Size = UDim2.new(1, 0, 0, 76),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(prof, 8)
        makeAvatar(prof, 52, UDim2.fromOffset(12, 12), "me")
        label({
            Size = UDim2.new(1, -150, 0, 22),
            Position = UDim2.fromOffset(76, 14),
            Text = LP.DisplayName,
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = prof,
        })
        label({
            Size = UDim2.new(1, -150, 0, 16),
            Position = UDim2.fromOffset(76, 38),
            Text = "@" .. LP.Name,
            TextSize = 11,
            TextColor3 = T.dim,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = prof,
        })

        flat(p, "Game")
        local gameCard = new("Frame", {
            Size = UDim2.new(1, 0, 0, 76),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(gameCard, 8)
        makeGameIcon(gameCard, 52, UDim2.fromOffset(12, 12))
        label({
            Size = UDim2.new(1, -90, 0, 22),
            Position = UDim2.fromOffset(76, 14),
            Text = gameName,
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = gameCard,
        })
        local gameSub = label({
            Size = UDim2.new(1, -90, 0, 16),
            Position = UDim2.fromOffset(76, 38),
            Text = "",
            TextSize = 11,
            TextColor3 = T.dim,
            Parent = gameCard,
        })

        flat(p, "Live stats")
        local grid = new("Frame", {
            Size = UDim2.new(1, 0, 0, 122),
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        new("UIGridLayout", {
            CellSize = UDim2.new(1 / 3, -6, 0, 58),
            CellPadding = UDim2.fromOffset(9, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = grid,
        })
        local function tile(order, title)
            local f = new("Frame", { BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = order, Parent = grid })
            corner(f, 8)
            label({
                Size = UDim2.new(1, -16, 0, 14),
                Position = UDim2.fromOffset(10, 9),
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = T.dim,
                Parent = f,
            })
            local v = label({
                Size = UDim2.new(1, -16, 0, 24),
                Position = UDim2.fromOffset(10, 26),
                Text = "--",
                Font = Enum.Font.GothamBold,
                TextSize = 17,
                TextScaled = true,
                Parent = f,
            })
            new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 8, Parent = v })
            return v
        end
        local tPing, tFps, tPlayers = tile(1, "PING"), tile(2, "FPS"), tile(3, "PLAYERS")
        local tSession, tMem, tPos = tile(4, "SESSION"), tile(5, "MEMORY"), tile(6, "POSITION")

        flat(p, "Info")
        local info = new("Frame", {
            Size = UDim2.new(1, 0, 0, 84),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(info, 8)
        local infoText = label({
            Size = UDim2.new(1, -24, 1, -16),
            Position = UDim2.fromOffset(12, 8),
            Text = "",
            Font = Enum.Font.Code,
            TextSize = 12,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = info,
        })

        local executor = "Unknown"
        if type(identifyexecutor) == "function" then
            local ok, name = pcall(identifyexecutor)
            if ok and name then executor = tostring(name) end
        end

        task.spawn(function()
            while running and grid.Parent do
                if win.Visible and pages[1].Visible then
                    tPing.Text = stats.ping .. " ms"
                    tPing.TextColor3 = pingColor(stats.ping)
                    tFps.Text = tostring(stats.fps)
                    tFps.TextColor3 = fpsColor(stats.fps)
                    tPlayers.Text = tostring(#Players:GetPlayers())
                    local s = math.floor(tick() - startTime)
                    tSession.Text = string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
                    local okm, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
                    tMem.Text = okm and string.format("%d MB", mem) or "--"
                    local x, y, z = F.readCoords()
                    tPos.Text = x and (x .. ", " .. y .. ", " .. z) or "--"
                    gameSub.Text = string.format("Players %d / %d", #Players:GetPlayers(), Players.MaxPlayers)
                    infoText.Text = string.format(
                        "Executor   %s\nInterface  %s\nMenu key   %s\nVersion    %s",
                        executor, mode, mobile and "round button" or menuKey.Name, VERSION)
                end
                task.wait(0.5)
            end
        end)
    end

    do
        local p = pageByName.Combat
        section(p, "Combat")
        toggle(p, "killAura", "Kill Aura", "Attacks players within reach", F.killAura, "attack hit")
        toggle(p, "targetStrafe", "Target Strafe", "Circles around your target (blatant)", F.targetStrafe, "orbit circle")
        toggle(p, "triggerbot", "Triggerbot", "Attacks when your crosshair is on a player", F.triggerbot, "aim")
        toggle(p, "hitbox", "Hitbox Expander", "Makes player hitboxes bigger", F.hitbox, "hitbox size")
        toggle(p, "combatLog", "Auto Combat Log", "Leaves the game below 30% health", F.combatLog, "leave escape")
        toggle(p, "safeZone", "Auto Safe Zone", "Teleports to a safe zone when low", F.safeZone, "teleport escape")
        section(p, "Extra")
        button(p, nil, "Vape V4 (PC ONLY)", "Loads Vape V4", F.loadVape, "vape client", "Load")
    end

    local coordValues = { x = "", y = "", z = "" }
    local selectedPlayer = nil

    do
        local p = pageByName.Player
        section(p, "Movement")
        toggle(p, "sprint", "Sprint", "A little faster", F.sprint, "run speed")
        toggle(p, "noFall", "No Fall", "No fall damage", F.noFall, "fall damage")
        toggle(p, "infiniteJump", "Infinite Jump", "Jump again in mid-air", F.infiniteJump, "air jump double")
        toggle(p, "airWalk", "Air Walk", "Walk on air", F.airWalk, "float platform")
        toggle(p, "jesus", "Jesus", "Walk on water", F.jesus, "water")
        toggle(p, "freeze", "Freeze", "Freeze yourself in place", F.freeze, "anchor stop")
        slider(p, "walkSpeed", "Walk Speed", "Default is 12", 8, 100, 1, 12, int, F.walkSpeed, "speed run")
        slider(p, "jumpPower", "Jump Power", "Default is 25", 10, 150, 1, 25, int, F.jumpPower, "jump height")

        section(p, "Survival")
        toggle(p, "autoEat", "Auto Eat", "Eats for you", F.autoEat, "food hunger")
        toggle(p, "autoArmor", "Auto Armor", "Equips the best armor", F.autoArmor, "equip")
        toggle(p, "autoTool", "Auto Tool", "Picks the best tool for mining", F.autoTool, "pickaxe")
        toggle(p, "infiniteHealth", "Infinite Health", "Needs emerald leggings", F.infiniteHealth, "hp god")
        toggle(p, "reach", "Reach", "Block interaction range, not attack range", F.reach, "distance")
        button(p, "immortality", "Immortality", "Put an item in the first slot first", F.immortality, "god", "Run")
        button(p, nil, "Suicide", "Kills your character", F.suicide, "kill die reset", "Run", true)

        section(p, "Teleport")
        local coordRow = new("Frame", {
            Size = UDim2.new(1, 0, 0, mobile and 56 or 50),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(coordRow, 8)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = coordRow,
        })
        new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = coordRow })
        for _, axis in ipairs({ "x", "y", "z" }) do
            local box = new("TextBox", {
                Size = UDim2.new(1 / 3, -6, 0, BTN_H + 4),
                BackgroundColor3 = T.card2,
                Text = "",
                PlaceholderText = string.upper(axis),
                PlaceholderColor3 = T.dim,
                TextColor3 = T.text,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                ClearTextOnFocus = false,
                BorderSizePixel = 0,
                Parent = coordRow,
            })
            corner(box, 6)
            box.FocusLost:Connect(function() coordValues[axis] = box.Text end)
        end
        registerRow(p, coordRow, "Coordinates", "X Y Z", "teleport position")
        button(p, nil, "Teleport to Coordinates", "Uses the X, Y, Z above", function()
            F.tpCoords(coordValues.x, coordValues.y, coordValues.z)
        end, "tp go", "Go")
        dropdown(p, nil, "Select Player", "Pick a player to teleport to", F.playerNames, nil, function(name)
            selectedPlayer = name
        end, "players list")
        button(p, nil, "Teleport to Player", "Goes to the selected player", function()
            F.tpPlayer(selectedPlayer)
        end, "tp go player", "Go")
    end

    do
        local p = pageByName.Visuals
        section(p, "Crosshair")
        toggle(p, "crosshair", "Crosshair+", "A cooler crosshair", F.crosshair, "aim")
        toggle(p, "rainbowCrosshair", "Rainbow Crosshair", "Crosshair that changes colors", F.rainbowCrosshair, "rgb")
        swatches(p, "crosshairColor", "Crosshair+ Color", PALETTE[1], F.crosshairColor)
        section(p, "World view")
        toggle(p, "fullbright", "Fullbright", "Makes everything bright", F.fullbright, "light dark")
        toggle(p, "xray", "X-Ray", "See ores through blocks", F.xray, "ore")
        toggle(p, "chestEsp", "Chest ESP", "See chests through blocks", F.chestEsp, "esp")
        toggle(p, "lavaEsp", "Lava ESP", "See lava through blocks", F.lavaEsp, "esp")
        toggle(p, "playerEsp", "Player ESP", "See players through blocks", F.playerEsp, "esp wallhack")
        button(p, nil, "XRay GUI", "Loads the ore ESP GUI", F.loadXrayGui, "ore esp", "Load")
        section(p, "Interface")
        toggle(p, "invViewer", "Inventory Viewer", "See other players' inventories", F.invViewer, "inventory", { locked = not F.isTester })
        toggle(p, "moreSlots", "More Slots", "Extra inventory space", F.moreSlots, "inventory")
        toggle(p, "nameProtect", "Name Protect", "Hides your name in the UI", F.nameProtect, "streamer hide")
    end

    do
        local p = pageByName.World
        section(p, "Mining")
        toggle(p, "instamine", "Instamine", "Instant mining, client side", F.instamine, "break")
        toggle(p, "fastBreak", "Fast Break", "Breaks blocks fast with the right tool", F.fastBreak, "mine")
        toggle(p, "nuker", "Nuker", "Breaks the block below you", F.nuker, "mine")
        toggle(p, "nuker3", "Nuker 3x3", "Breaks blocks in a 3x3x3 area", F.nuker3, "mine")
        toggle(p, "nuker5", "Nuker 5x5", "Breaks blocks in a 5x5x5 area", F.nuker5, "mine")
        toggle(p, "autoDrop", "Auto Drop Selected Item", "Drops the selected item nonstop", F.autoDrop, "throw")
        section(p, "Building")
        toggle(p, "scaffold", "Scaffold", "Places a block below you", F.scaffold, "bridge")
        toggle(p, "scaffold3", "Scaffold 3x3", "Places a 3x3 floor below you", F.scaffold3, "bridge")
        toggle(p, "highwayX", "Highway Builder X", "Builds a highway along X", F.highwayX, "bridge road")
        toggle(p, "highwayZ", "Highway Builder Z", "Builds a highway along Z", F.highwayZ, "bridge road")
        section(p, "Tools")
        button(p, "reloadChunks", "Reload Chunks", "Reloads the world around you", F.reloadChunks, "refresh", "Run")
        button(p, "chestDump", "Chest Stealer / Dumper", "Moves items between you and a chest", F.chestDump, "steal dump", "Run")
        button(p, "getLava", "Get Lava", "Bucket must be in the first slot", F.getLava, "bucket", "Run")
    end

    do
        local p = pageByName.Dupe
        local giveName, giveAmount = "", ""
        section(p, "Held item")
        button(p, "dupeHeld", "Dupe Held Item", "Hold it in the hotbar, no need to open the inventory", F.dupeHeld, "copy duplicate stack", "Dupe")
        toggle(p, "autoDupeHeld", "Auto Dupe Held Item", "Keeps the held stack full", F.autoDupeHeld, "copy duplicate loop")
        button(p, "infiniteItems", "Get Infinite Items", "Hold the item first", F.infiniteItems, "unlimited", "Run")
        section(p, "Chest")
        button(p, "dupeFirst", "Dupe First Chest Slot", "Open a chest first", F.dupeFirst, "copy duplicate", "Dupe")
        button(p, "dupeAll", "Dupe Entire Chest", "Open a chest first", F.dupeAll, "copy duplicate", "Dupe")
        toggle(p, "autoDupe", "Auto Dupe Entire Chest", "Keeps duping the open chest", F.autoDupe, "copy duplicate loop")
        button(p, "dumpDupe", "Dump + Dupe Entire Chest", "Dumps your items, then dupes them", F.dumpDupe, "copy duplicate", "Run")
        section(p, "Legacy")
        button(p, nil, "Dupe GUI", "External GUI by Argentum", F.loadDupeGui, "gui", "Load")
        if F.hasGive then
            section(p, "Give")
            input(p, nil, "Item Name", "Name of the item", "", "Item name", function(v) giveName = v end, "give")
            input(p, nil, "Amount", "How many to give", "", "Amount", function(v) giveAmount = v end, "give")
            button(p, nil, "Give Item", "Gives the item above", function()
                F.giveItem(giveName, tonumber(giveAmount) or 1)
            end, "give", "Give")
        end
    end

    do
        local p = pageByName.Others
        section(p, "Scripts")
        button(p, "infiniteYield", "Infinite Yield", "Admin commands", F.loadInfiniteYield, "iy admin", "Load")
        button(p, "mobileKeyboard", "Mobile Keyboard", "On-screen keyboard", F.loadKeyboard, "osk", "Load")
        button(p, "remoteSpy", "Remote Spy", "Mobile and PC remote spy", F.loadRemoteSpy, "spy", "Load")
        section(p, "Texture packs")
        button(p, nil, "Vanilla Texture Pack", "Replaces textures with Minecraft ones", F.loadTexturePack, "texture", "Apply")
    end

    do
        local p = pageByName.Settings
        section(p, "Combat settings")
        slider(p, "killAuraDelay", "Kill Aura Delay", "Seconds between hits", 0, 2, 0.05, 0, dec, function(v) _G.delay = v end, "cooldown")
        slider(p, "strafeRadius", "Target Strafe Distance", "Distance from the target", 1, 16, 1, 10, int, function(v) _G.radius = v end, "radius")
        slider(p, "strafeSpeed", "Target Strafe Speed", "Rotation speed", 1, 20, 1, 5, int, function(v) _G.speed = v end, "orbit")
        slider(p, "triggerDelay", "Triggerbot Delay", "Seconds between hits", 0, 1, 0.01, 0, dec, function(v) _G.tbdelay = v end, "cooldown")
        dropdown(p, "targeting", "Targeting Method", "For Kill Aura and Target Strafe", function() return { "nearest", "lowest" } end, "nearest", function(v)
            _G.selectedTargeting = v
        end, "target")

        section(p, "General")
        input(p, "protectName", "Name Protect Name", "Replacement name", "Protected", "Protected", F.protectName, "streamer")
        toggle(p, "antiAfk", "Anti AFK", "No kick for idling", F.antiAfk, "idle")

        section(p, "Floating buttons")
        toggle(p, nil, "Show floating buttons", "Hide them all without removing", function(on)
            prefs.hidePins = not on
            Quick.setHidden(not on)
            savePrefs()
        end, "quick pins", { initial = not prefs.hidePins })
        toggle(p, nil, "Lock button positions", "Stops accidental dragging", function(on)
            prefs.lockPins = on
            savePrefs()
        end, "quick pins drag", { initial = prefs.lockPins or false })
        toggle(p, nil, "Show button names", "Small name under each round button", function(on)
            prefs.pinLabels = on
            Quick.setLabels(on)
            savePrefs()
        end, "quick pins names labels", { initial = prefs.pinLabels ~= false })
        slider(p, nil, "Button size", "Size of floating buttons", 36, 72, 2, Quick.size(), int, function(v)
            prefs.floatSize = v
            savePrefs()
            Quick.rebuild()
        end, "quick pins")
        button(p, nil, "Reset button positions", "Puts them back in a column", function()
            Quick.resetPositions()
        end, "quick pins", "Reset")

        section(p, "Menu")
        if not mobile then
            keyBindRow(p, "Menu key", "Key that opens the menu", function() return menuKey.Name end, function(kc)
                if kc then
                    menuKey = kc
                    prefs.menuKey = kc.Name
                    savePrefs()
                end
            end, false, "hotkey bind keybind")
            keyBindRow(p, "Panic key", "Turns every feature off", function() return panicKey and panicKey.Name end, function(kc)
                panicKey = kc
                prefs.panicKey = kc and kc.Name or nil
                savePrefs()
            end, true, "hotkey panic disable")
        end
        button(p, nil, "Turn everything off", "Disables every active feature", function()
            if Hub.panic then Hub.panic() end
        end, "panic disable", "Off")

        local modeRow = new("Frame", {
            Size = UDim2.new(1, 0, 0, ROWD),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(modeRow, 8)
        titleBlock(modeRow, "Interface", "Saved for next launch", 190)
        for i, name in ipairs({ "PC", "Mobile" }) do
            local b = new("TextButton", {
                Size = UDim2.fromOffset(mobile and 64 or 58, BTN_H),
                Position = UDim2.new(1, -((mobile and 64 or 58) * (3 - i) + 8 * (3 - i) + 2), 0.5, -BTN_H / 2),
                BackgroundColor3 = name == mode and T.accent or T.card2,
                Text = name,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = name == mode and Color3.new(1, 1, 1) or T.dim,
                BorderSizePixel = 0,
                Parent = modeRow,
            })
            corner(b, 8)
            b.MouseButton1Click:Connect(function()
                if name ~= mode then switchMode(name) end
            end)
        end
        registerRow(p, modeRow, "Interface", "Switch between PC and Mobile", "mode layout phone")
        button(p, nil, "Unload Ket Hub", "Turns everything off and removes the menu", unload, "close destroy exit", "Unload", true)
    end

    do
        local p = pageByName.Configs
        if not FS then
            flat(p, "Status")
            local warnRow = new("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = T.card,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(p),
                Parent = p,
            })
            corner(warnRow, 8)
            label({
                Size = UDim2.new(1, -24, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                Text = "Your executor has no file access, configs are unavailable.",
                TextSize = 12,
                TextColor3 = T.bad,
                TextWrapped = true,
                Parent = warnRow,
            })
        end

        flat(p, "Save current settings")
        local nameRow = new("Frame", {
            Size = UDim2.new(1, 0, 0, mobile and 50 or 44),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(nameRow, 8)
        local nameBox = new("TextBox", {
            Size = UDim2.new(1, -112, 0, BTN_H),
            Position = UDim2.new(0, 8, 0.5, -BTN_H / 2),
            BackgroundColor3 = T.card2,
            Text = "",
            PlaceholderText = "Config name",
            PlaceholderColor3 = T.dim,
            TextColor3 = T.text,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            ClearTextOnFocus = false,
            BorderSizePixel = 0,
            Parent = nameRow,
        })
        corner(nameBox, 6)
        new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = nameBox })
        local saveBtn = new("TextButton", {
            Size = UDim2.fromOffset(86, BTN_H),
            Position = UDim2.new(1, -94, 0.5, -BTN_H / 2),
            BackgroundColor3 = T.accent,
            Text = "Save",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = nameRow,
        })
        corner(saveBtn, 6)

        flat(p, "Saved configs")
        local listHolder = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listHolder })

        local function collect()
            local out = {}
            for id, item in pairs(stateItems) do
                local v = item.get()
                if item.kind == "color" then
                    v = { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
                end
                out[id] = v
            end
            return out
        end

        local function distribute(data)
            for id, v in pairs(data) do
                local item = stateItems[id]
                if item then
                    if item.kind == "color" then
                        if type(v) == "table" and #v >= 3 then item.set(Color3.fromRGB(v[1], v[2], v[3])) end
                    elseif item.kind == "bool" and type(v) == "boolean" then
                        item.set(v)
                    elseif item.kind == "number" and type(v) == "number" then
                        item.set(v)
                    elseif item.kind == "string" and type(v) == "string" then
                        item.set(v)
                    end
                end
            end
        end

        local refreshList
        refreshList = function()
            for _, c in ipairs(listHolder:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
            end
            local files = {}
            if FS and type(listfiles) == "function" then
                local ok, res = pcall(listfiles, CFGDIR)
                if ok and type(res) == "table" then
                    for _, f in ipairs(res) do
                        local n = tostring(f):match("([^/\\]+)%.json$")
                        if n then files[#files + 1] = n end
                    end
                end
            end
            table.sort(files)

            if #files == 0 then
                label({
                    Size = UDim2.new(1, 0, 0, 26),
                    Text = "No saved configs yet",
                    TextSize = 12,
                    TextColor3 = T.dim,
                    LayoutOrder = 1,
                    Parent = listHolder,
                })
                return
            end

            for i, n in ipairs(files) do
                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, ROW),
                    BackgroundColor3 = T.card,
                    BorderSizePixel = 0,
                    LayoutOrder = i,
                    Parent = listHolder,
                })
                corner(row, 8)
                label({
                    Size = UDim2.new(1, -150, 1, 0),
                    Position = UDim2.fromOffset(12, 0),
                    Text = n,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = row,
                })
                local loadBtn = new("TextButton", {
                    Size = UDim2.fromOffset(56, BTN_H - 2),
                    Position = UDim2.new(1, -124, 0.5, -(BTN_H - 2) / 2),
                    BackgroundColor3 = T.accent,
                    Text = "Load",
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    TextColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    Parent = row,
                })
                corner(loadBtn, 6)
                local delBtn = new("TextButton", {
                    Size = UDim2.fromOffset(56, BTN_H - 2),
                    Position = UDim2.new(1, -62, 0.5, -(BTN_H - 2) / 2),
                    BackgroundColor3 = T.card2,
                    Text = "Delete",
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    TextColor3 = T.bad,
                    BorderSizePixel = 0,
                    Parent = row,
                })
                corner(delBtn, 6)

                loadBtn.MouseButton1Click:Connect(function()
                    local data = readJson(CFGDIR .. "/" .. n .. ".json")
                    if data then
                        distribute(data)
                        notify("Loaded: " .. n, 2)
                    else
                        notify("Failed to load: " .. n, 2)
                    end
                end)
                delBtn.MouseButton1Click:Connect(function()
                    if type(delfile) == "function" then
                        pcall(delfile, CFGDIR .. "/" .. n .. ".json")
                        notify("Deleted: " .. n, 2)
                    else
                        notify("delfile is not supported", 2)
                    end
                    refreshList()
                end)
            end
        end

        saveBtn.MouseButton1Click:Connect(function()
            if not FS then return notify("No file access", 2) end
            local name = nameBox.Text:gsub("[^%w_%-]", "")
            if name == "" then return notify("Enter a config name", 2) end
            if writeJson(CFGDIR .. "/" .. name .. ".json", collect()) then
                notify("Saved: " .. name, 2)
                nameBox.Text = ""
            else
                notify("Save failed", 2)
            end
            refreshList()
        end)

        flat(p, "Reset")
        button(p, nil, "Reset to defaults", "Turns every feature off", function()
            for _, item in pairs(stateItems) do item.set(item.default) end
            notify("Settings reset", 2)
        end, "default clear", "Reset", true)

        refreshList()
    end

    do
        local p = pageByName.Credits

        local function copyButton(parent, value)
            local b = new("TextButton", {
                Size = UDim2.fromOffset(70, BTN_H),
                Position = UDim2.new(1, -82, 0.5, -BTN_H / 2),
                BackgroundColor3 = T.accent,
                Text = "Copy",
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                Parent = parent,
            })
            corner(b, 8)
            b.MouseButton1Click:Connect(function()
                if type(setclipboard) == "function" then
                    pcall(setclipboard, value)
                    notify("Copied: " .. value, 2)
                else
                    notify("Clipboard is not supported", 2)
                end
            end)
        end

        flat(p, "Creator")
        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 156),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(card, 10)
        local banner = new("Frame", {
            Size = UDim2.new(1, 0, 0, 66),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = card,
        })
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, T.accent),
                ColorSequenceKeypoint.new(1, T.accent2),
            }),
            Rotation = 20,
            Parent = banner,
        })
        local av = makeAvatar(card, 84, UDim2.fromOffset(18, 24), "creator", T.card)
        local ring = av:FindFirstChildOfClass("UIStroke")
        if ring then
            ring.Thickness = 4
            ring.Transparency = 0
        end
        label({
            Size = UDim2.new(1, -130, 0, 26),
            Position = UDim2.fromOffset(116, 72),
            Text = CREATOR_NICK,
            Font = Enum.Font.GothamBold,
            TextSize = 20,
            Parent = card,
        })
        label({
            Size = UDim2.new(1, -130, 0, 14),
            Position = UDim2.fromOffset(116, 99),
            Text = "In-game nick",
            TextSize = 11,
            TextColor3 = T.dim,
            Parent = card,
        })
        local tag = new("Frame", {
            Size = UDim2.fromOffset(158, 22),
            Position = UDim2.fromOffset(116, 122),
            BackgroundColor3 = T.accent,
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
            Parent = card,
        })
        corner(tag, 11)
        label({
            Size = UDim2.new(1, 0, 1, 0),
            Text = "CREATOR  &  DEVELOPER",
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = T.accent,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = tag,
        })

        flat(p, "Main account")
        local acc = new("Frame", {
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(acc, 8)
        label({ Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(12, 9), Text = "Roblox username", TextSize = 10, TextColor3 = T.dim, Parent = acc })
        label({
            Size = UDim2.new(1, -110, 0, 20),
            Position = UDim2.fromOffset(12, 28),
            Text = "@" .. CREATOR_MAIN,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = acc,
        })
        copyButton(acc, CREATOR_MAIN)

        flat(p, "Community")
        local disc = new("Frame", {
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(disc, 8)
        label({ Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(12, 9), Text = "Discord server", TextSize = 10, TextColor3 = T.dim, Parent = disc })
        label({
            Size = UDim2.new(1, -110, 0, 20),
            Position = UDim2.fromOffset(12, 28),
            Text = "discord.gg/WXWyuDQsD",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = T.accent2,
            Parent = disc,
        })
        copyButton(disc, DISCORD)

        flat(p, "Core")
        local core = new("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = T.card,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(p),
            Parent = p,
        })
        corner(core, 8)
        label({
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.fromOffset(12, 0),
            Text = "Features based on Byte Hub by PurpleApple",
            TextSize = 12,
            TextColor3 = T.dim,
            Parent = core,
        })
    end

    local orbSize = mobile and 64 or 56
    local orbPos = prefs.orb
    local orb = new("TextButton", {
        Name = "OpenButton",
        Size = UDim2.fromOffset(orbSize, orbSize),
        Position = orbPos and UDim2.new(orbPos.x, -orbSize / 2, orbPos.y, -orbSize / 2) or UDim2.new(0, 16, 0.5, -orbSize / 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(orb, UDim.new(1, 0))
    local ringGradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.accent),
            ColorSequenceKeypoint.new(0.5, T.accent2),
            ColorSequenceKeypoint.new(1, T.accent),
        }),
        Parent = orb,
    })
    TweenService:Create(ringGradient, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 }):Play()
    local orbScale = new("UIScale", { Scale = 1, Parent = orb })
    local inner = new("Frame", {
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = orb,
    })
    corner(inner, UDim.new(1, 0))
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 30, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 20)),
        }),
        Rotation = 90,
        Parent = inner,
    })
    label({
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0.5, -17),
        Text = "KET",
        Font = Enum.Font.GothamBlack,
        TextSize = mobile and 17 or 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = inner,
    })
    label({
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 0.5, 3),
        Text = "HUB",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = T.accent2,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = inner,
    })

    local orbDrag = makeDraggable(orb, orb, function()
        local area = gui.AbsoluteSize
        local pos, size = orb.AbsolutePosition, orb.AbsoluteSize
        prefs.orb = {
            x = math.clamp((pos.X + size.X / 2) / area.X, 0.02, 0.98),
            y = math.clamp((pos.Y + size.Y / 2) / area.Y, 0.04, 0.96),
        }
        savePrefs()
    end)

    orb.MouseEnter:Connect(function()
        if not orbDrag.moved then tween(orbScale, 0.12, { Scale = 1.08 }) end
    end)
    orb.MouseLeave:Connect(function() tween(orbScale, 0.12, { Scale = 1 }) end)
    orb.MouseButton1Down:Connect(function() tween(orbScale, 0.08, { Scale = 0.92 }) end)
    orb.MouseButton1Up:Connect(function() tween(orbScale, 0.12, { Scale = 1 }) end)

    local hub = {}

    function hub.setOpen(v)
        if v then
            win.Visible = true
            winScale.Scale = 0.94
            tween(winScale, 0.2, { Scale = 1 })
        else
            win.Visible = false
            closePopup()
        end
    end

    function hub.isOpen()
        return win.Visible
    end

    closeBtn.MouseButton1Click:Connect(function() hub.setOpen(false) end)
    orb.MouseButton1Click:Connect(function()
        if orbDrag.moved then return end
        hub.setOpen(not win.Visible)
    end)

    function hub.snapshot()
        local raw = {}
        for id, item in pairs(stateItems) do raw[id] = item.get() end
        return raw
    end

    function hub.restore(raw)
        for id, v in pairs(raw) do
            local item = stateItems[id]
            if item then item.set(v, true) end
        end
    end

    function hub.disableAll()
        for _, item in pairs(stateItems) do
            if item.kind == "bool" and item.get() then pcall(item.set, false) end
        end
    end

    function hub.destroy()
        gui:Destroy()
    end

    Quick.provider = function(id) return quickItems[id] end
    Quick.restore()
    for id, item in pairs(quickItems) do
        if item.kind == "toggle" then Quick.sync(id, item.get()) end
    end

    refreshFooter()
    setTab(1)
    return hub
end

local function main()
    local startup = createStartup()
    startup.begin()
    startup.setStatus("Checking game...", 0.05)
    task.wait(0.3)

    local refs = loadGameRefs()
    if not refs then
        startup.fail("This game is not supported.")
        env.KetHubLoaded = nil
        return
    end

    startup.setStatus("Loading modules...", 0.1)
    local mods = loadModules(function(done, total)
        startup.setStatus("Loading modules " .. done .. "/" .. total, 0.1 + 0.8 * (done / total))
    end)

    startup.setStatus("Setting up features...", 0.95)
    local features = createFeatures(refs, mods)
    startup.setStatus("Ready", 1)
    task.wait(0.4)

    if not startup.hasSavedKey() then
        startup.askKey()
    end

    local mode = prefs.mode
    if mode ~= "PC" and mode ~= "Mobile" then
        mode = startup.askMode()
        prefs.mode = mode
        savePrefs()
    end
    currentMode = mode
    startup.close()

    local hub
    local unloading = false

    local function unload()
        if unloading then return end
        unloading = true
        if hub then
            pcall(hub.disableAll)
            hub.destroy()
        end
        features.cleanup()
        if prefsDirty then writeJson(PREFSFILE, prefs) end
        running = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for _, d in ipairs(drawings) do pcall(function() d:Remove() end) end
        for _, g in ipairs(guis) do pcall(function() g:Destroy() end) end
        env.KetHubLoaded = nil
        env.KetHubUnload = nil
    end

    env.KetHubUnload = unload

    local function switchMode(newMode)
        local snap = hub.snapshot()
        hub.destroy()
        currentMode = newMode
        prefs.mode = newMode
        savePrefs()
        hub = buildHub(newMode, features, switchMode, unload)
        Hub.current = hub
        hub.restore(snap)
        Quick.rebuild()
        hub.setOpen(true)
    end

    Hub.toggle = function()
        if hub then hub.setOpen(not hub.isOpen()) end
    end

    Hub.panic = function()
        if hub then hub.disableAll() end
        notify("Everything is off", 2)
    end

    hub = buildHub(mode, features, switchMode, unload)
    Hub.current = hub
    hub.setOpen(true)
end

local ok, err = pcall(main)
if not ok then
    warn("[Ket Hub] " .. tostring(err))
    if env.KetHubUnload then pcall(env.KetHubUnload) end
    for _, g in ipairs(guis) do pcall(function() g:Destroy() end) end
    env.KetHubLoaded = nil
end
