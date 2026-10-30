--!strict
-- HUDController: the only player-status display is health (bottom right), plus a small scrap counter
-- beside the hotbar. No hunger, thirst or other survival stats.
--   * health reads the Humanoid directly (Health / MaxHealth), so it can't drift from the real value;
--     it updates on damage, healing and respawn, and is clamped to 0..MaxHealth
--   * the scrap counter reads the player's server-owned "Scrap" attribute and pulses "+1" on pickup
-- Roblox's default health bar is turned off in init.client (the Humanoid itself is untouched).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HUDStyle = require(script.Parent:WaitForChild("HUDStyle"))

local HUDController = {}

local player = Players.LocalPlayer
local healthFill: Frame
local healthText: TextLabel
local scrapText: TextLabel
local scrapPop: TextLabel
local healthConn: RBXScriptConnection?
local started = false

local function setHealth(hp: number, max: number)
	max = math.max(max, 1)
	local v = math.clamp(hp, 0, max)
	healthText.Text = tostring(math.ceil(v))
	TweenService:Create(healthFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(v / max, 1) }):Play()
end

local function bindHumanoid(char: Model)
	if healthConn then
		healthConn:Disconnect()
		healthConn = nil
	end
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	setHealth(hum.Health, hum.MaxHealth)
	healthConn = hum.HealthChanged:Connect(function(hp)
		setHealth(hp, hum.MaxHealth)
	end)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		setHealth(hum.Health, hum.MaxHealth)
	end)
end

local function scrap(): number
	local v = player:GetAttribute("Scrap")
	return if type(v) == "number" then v else 0
end

function HUDController.start()
	if started then
		return
	end
	started = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	HUDStyle.scaled(gui)

	-- health: bottom right, cross icon + green bar + number
	local hp = HUDStyle.panel(gui, "Health", UDim2.fromOffset(214, 30))
	hp.AnchorPoint = Vector2.new(1, 1)
	hp.Position = UDim2.new(1, -HUDStyle.EDGE, 1, -HUDStyle.EDGE)
	hp.BackgroundColor3 = HUDStyle.HEALTH_BACK
	hp.BackgroundTransparency = 0.25
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(30, 3)
	bar.Size = UDim2.new(1, -33, 1, -6)
	bar.BackgroundTransparency = 1
	bar.ClipsDescendants = true
	bar.Parent = hp
	healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = HUDStyle.HEALTH
	healthFill.BorderSizePixel = 0
	healthFill.Parent = bar
	local icon = Instance.new("Frame")
	icon.Name = "Cross"
	icon.Position = UDim2.fromOffset(3, 3)
	icon.Size = UDim2.fromOffset(24, 24)
	icon.BackgroundColor3 = HUDStyle.HEALTH
	icon.BackgroundTransparency = 0.2
	icon.BorderSizePixel = 0
	icon.Parent = hp
	HUDStyle.box(icon, "V", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(5, 15), HUDStyle.TEXT)
	HUDStyle.box(icon, "H", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(15, 5), HUDStyle.TEXT)
	healthText = HUDStyle.label(bar, "100", 16, true)
	healthText.Name = "Value"
	healthText.Position = UDim2.fromOffset(8, 0)
	healthText.Size = UDim2.new(1, -8, 1, 0)
	healthText.TextXAlignment = Enum.TextXAlignment.Left
	healthText.TextStrokeTransparency = 0.7
	healthText.ZIndex = 2

	-- scrap counter: just right of the hotbar
	local sc = HUDStyle.panel(gui, "Scrap", UDim2.fromOffset(112, 30))
	sc.AnchorPoint = Vector2.new(0, 1)
	sc.Position = UDim2.new(0.5, HUDStyle.hotbarWidth() / 2 + 10, 1, -HUDStyle.EDGE)
	local sIcon = Instance.new("Frame")
	sIcon.Name = "IconBox"
	sIcon.Position = UDim2.fromOffset(3, 3)
	sIcon.Size = UDim2.fromOffset(24, 24)
	sIcon.BackgroundTransparency = 1
	sIcon.Parent = sc
	HUDStyle.icon(sIcon, "Scrap")
	local cap = HUDStyle.label(sc, "SCRAP", 10, true, HUDStyle.MUTED)
	cap.Position = UDim2.fromOffset(32, 0)
	cap.Size = UDim2.new(0, 40, 1, 0)
	cap.TextXAlignment = Enum.TextXAlignment.Left
	scrapText = HUDStyle.label(sc, "0", 16, true)
	scrapText.Name = "Value"
	scrapText.AnchorPoint = Vector2.new(1, 0)
	scrapText.Position = UDim2.new(1, -8, 0, 0)
	scrapText.Size = UDim2.new(0, 44, 1, 0)
	scrapText.TextXAlignment = Enum.TextXAlignment.Right
	scrapPop = HUDStyle.label(sc, "", 14, true, HUDStyle.GOOD)
	scrapPop.Name = "Pop"
	scrapPop.AnchorPoint = Vector2.new(1, 1)
	scrapPop.Position = UDim2.new(1, -8, 0, -2)
	scrapPop.Size = UDim2.fromOffset(60, 16)
	scrapPop.TextXAlignment = Enum.TextXAlignment.Right
	scrapPop.TextTransparency = 1
	scrapPop.TextStrokeTransparency = 1

	gui.Parent = player:WaitForChild("PlayerGui")

	scrapText.Text = tostring(scrap())
	player:GetAttributeChangedSignal("Scrap"):Connect(function()
		scrapText.Text = tostring(scrap())
	end)
	local collected = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ScrapCollected") :: RemoteEvent
	collected.OnClientEvent:Connect(function(amount: number)
		scrapPop.Text = `+{amount}`
		scrapPop.TextTransparency = 0
		scrapPop.TextStrokeTransparency = 0.6
		scrapPop.Position = UDim2.new(1, -8, 0, -2)
		TweenService:Create(scrapPop, TweenInfo.new(0.9), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.new(1, -8, 0, -16),
		}):Play()
	end)

	player.CharacterAdded:Connect(bindHumanoid)
	if player.Character then
		task.spawn(bindHumanoid, player.Character)
	end
end

return HUDController
