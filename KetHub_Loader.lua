local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local env = getgenv()
if env.KetHubLoading then return end
env.KetHubLoading = true

local BASE = "https://github.com/yijtfjyfjtd/KetHub/blob/main/KetHub_Minecraft_v2.lua"
local SCRIPT = BASE .. "KetHub_Minecraft_v2.lua"
local REQUIRED = { "AcceptBreakBlock", "BreakBlock", "Attack", "MoveItem", "PlaceBlock" }

local C = {
    bg = Color3.fromRGB(16, 16, 21),
    card = Color3.fromRGB(27, 27, 36),
    off = Color3.fromRGB(56, 56, 72),
    accent = Color3.fromRGB(124, 108, 255),
    accent2 = Color3.fromRGB(80, 200, 255),
    text = Color3.fromRGB(232, 232, 240),
    dim = Color3.fromRGB(135, 135, 158),
    good = Color3.fromRGB(80, 220, 120),
    bad = Color3.fromRGB(235, 80, 90),
}

local gameName = "Minecraft"
pcall(function()
    gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name
end)

local function make(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then obj[k] = v end
    end
    obj.Parent = props.Parent
    return obj
end

local function round(obj, r)
    return make("UICorner", { CornerRadius = r or UDim.new(0, 10), Parent = obj })
end

local function text(parent, props)
    local base = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    }
    for k, v in pairs(props) do base[k] = v end
    return make("TextLabel", base)
end

local function tween(obj, time, props, style)
    TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local gui = make("ScreenGui", {
    Name = "KetHub_Loader",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1200,
    Parent = CoreGui,
})

local card = make("CanvasGroup", {
    Size = UDim2.fromOffset(360, 190),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Parent = gui,
})
round(card, UDim.new(0, 14))
make("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.5, Parent = card })
local cardScale = make("UIScale", { Scale = 0.92, Parent = card })

local topLine = make("Frame", {
    Size = UDim2.new(1, 0, 0, 3),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = card,
})
make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accent2),
    }),
    Parent = topLine,
})

local icon = make("ImageLabel", {
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.fromOffset(20, 20),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
    Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150",
    ScaleType = Enum.ScaleType.Crop,
    Parent = card,
})
round(icon, UDim.new(0, 12))

text(card, {
    Size = UDim2.new(1, -110, 0, 24),
    Position = UDim2.fromOffset(84, 20),
    Text = "Ket Hub",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
})
text(card, {
    Size = UDim2.new(1, -110, 0, 16),
    Position = UDim2.fromOffset(84, 46),
    Text = gameName,
    TextSize = 12,
    TextColor3 = C.dim,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
text(card, {
    Size = UDim2.fromOffset(60, 14),
    Position = UDim2.new(1, -78, 0, 22),
    Text = "beta",
    TextSize = 10,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right,
})

local labels = { "Looking for the game", "LOVING Ket Hub", "Starting" }
local dots, rows = {}, {}

for i, name in ipairs(labels) do
    local y = 86 + (i - 1) * 22
    local dot = make("Frame", {
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.fromOffset(22, y + 4),
        BackgroundColor3 = C.off,
        BorderSizePixel = 0,
        Parent = card,
    })
    round(dot, UDim.new(1, 0))
    dots[i] = dot
    rows[i] = text(card, {
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.fromOffset(42, y),
        Text = name,
        TextColor3 = C.dim,
    })
end

local barBack = make("Frame", {
    Size = UDim2.new(1, -40, 0, 5),
    Position = UDim2.new(0, 20, 1, -22),
    BackgroundColor3 = C.off,
    BorderSizePixel = 0,
    Parent = card,
})
round(barBack, UDim.new(1, 0))
local bar = make("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = barBack,
})
round(bar, UDim.new(1, 0))
make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accent2),
    }),
    Parent = bar,
})

local function progress(fraction)
    tween(bar, 0.3, { Size = UDim2.new(fraction, 0, 1, 0) })
end

local function step(i, state)
    local color = state == "done" and C.good or state == "fail" and C.bad or state == "active" and C.accent or C.off
    tween(dots[i], 0.15, { BackgroundColor3 = color })
    rows[i].TextColor3 = state == "pending" and C.dim or C.text
    if state == "active" then
        task.spawn(function()
            while env.KetHubLoading and dots[i].Parent and dots[i].BackgroundColor3 == C.accent do
                tween(dots[i], 0.45, { BackgroundTransparency = 0.55 })
                task.wait(0.45)
                tween(dots[i], 0.45, { BackgroundTransparency = 0 })
                task.wait(0.45)
            end
            if dots[i].Parent then dots[i].BackgroundTransparency = 0 end
        end)
    end
end

local function close(wait)
    task.wait(wait or 0)
    tween(card, 0.3, { GroupTransparency = 1 })
    tween(cardScale, 0.3, { Scale = 1.05 })
    task.wait(0.35)
    gui:Destroy()
    env.KetHubLoading = nil
end

local function fail(i, message)
    step(i, "fail")
    tween(bar, 0.2, { BackgroundColor3 = C.bad })
    text(card, {
        Size = UDim2.new(1, -40, 0, 16),
        Position = UDim2.new(0, 20, 1, -44),
        Text = message,
        TextColor3 = C.bad,
        TextSize = 11,
    })
    close(3.5)
end

local function looksLikeMinecraft()
    local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
    if not remotes or not ReplicatedStorage:FindFirstChild("AssetsMod") then return false end
    local found = 0
    for _, name in ipairs(REQUIRED) do
        if remotes:FindFirstChild(name) then found = found + 1 end
    end
    return found >= 3
end

local function fetch(url)
    for _ = 1, 3 do
        local ok, body = pcall(game.HttpGet, game, url, true)
        if ok and type(body) == "string" and #body > 50 then return body end
        task.wait(0.6)
    end
end

tween(card, 0.4, { GroupTransparency = 0 })
tween(cardScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

if not game:IsLoaded() then game.Loaded:Wait() end

step(1, "active")
progress(0.1)

local found = false
for i = 1, 24 do
    if looksLikeMinecraft() then
        found = true
        break
    end
    progress(0.1 + i * 0.01)
    task.wait(0.25)
end

if not found then
    return fail(1, "No supported Minecraft game not found")
end

step(1, "done")
progress(0.4)
step(2, "active")

if BASE:find("YOUR_NAME", 1, true) then
    return fail(2, "Set your GitHub link in the loader first")
end

local source = fetch(SCRIPT)
if not source then
    return fail(2, "Could not download the script")
end

step(2, "done")
progress(0.75)
step(3, "active")

local run, err = loadstring(source)
if not run then
    warn("[Ket Hub] " .. tostring(err))
    return fail(3, "The script has an error")
end

progress(1)
step(3, "done")
close(0.4)

local ok, runErr = pcall(run)
if not ok then
    warn("[Ket Hub] " .. tostring(runErr))
end
