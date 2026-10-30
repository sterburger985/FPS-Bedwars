--!strict
-- VendingController: the menu for the scrap stations' vending machines.
--   * press E at a machine (its ProximityPrompt) to open; E, Esc, Close or walking away shuts it
--   * the mouse is freed while it is open; the view holds still
--   * each row shows the price; Buy asks the server (Remotes.ShopBuy), which checks and charges
--   * balances shown are the player's own server-owned attributes, so they update the moment a
--     purchase or pickup lands
-- Guns has no stock yet and says so.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local HUDStyle = require(script.Parent:WaitForChild("HUDStyle"))
local FPSController = require(script.Parent:WaitForChild("FPSController"))

local VendingController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local window: Frame
local title: TextLabel
local list: Frame
local message: TextLabel
local balances: TextLabel
local buyRemote: RemoteFunction
local openMachine: Model? = nil
local started = false

local function costText(cost: { [string]: number }): string
	local parts = {}
	for kind, n in pairs(cost) do
		table.insert(parts, `{n} {kind}`)
	end
	return table.concat(parts, " + ")
end

local function balanceText(): string
	local s = player:GetAttribute("Scrap")
	local w = player:GetAttribute("Wood")
	return `Scrap {if type(s) == "number" then s else 0}    Wood {if type(w) == "number" then w else 0}`
end

local function button(parent: Instance, text: string, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = HUDStyle.ACCENT
	b.BackgroundTransparency = 0.25
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.FontFace = HUDStyle.FONT_BOLD
	b.TextSize = 14
	b.TextColor3 = HUDStyle.TEXT
	b.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = b
	b.Parent = parent
	return b
end

function VendingController.close()
	if not openMachine then
		return
	end
	openMachine = nil
	window.Visible = false
	FPSController.freeCursor("vending", false)
end

local function buy(itemId: string)
	local m = openMachine
	if not m then
		return
	end
	message.Text = "..."
	message.TextColor3 = HUDStyle.MUTED
	local okCall, ok, text = pcall(buyRemote.InvokeServer, buyRemote, m, itemId)
	if openMachine ~= m then
		return
	end
	if not okCall then
		message.Text = "No answer from the server"
		message.TextColor3 = HUDStyle.BAD
	else
		message.Text = tostring(text)
		message.TextColor3 = if ok then HUDStyle.GOOD else HUDStyle.BAD
	end
end

function VendingController.open(machine: Model)
	local kind = machine:GetAttribute("Machine")
	local def = type(kind) == "string" and ShopConfig.MACHINES[kind] or nil
	if not def then
		return
	end
	openMachine = machine
	title.Text = `{string.upper(def.title)} VENDING`
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if #def.items == 0 then
		local empty = HUDStyle.label(list, def.emptyText or "Nothing for sale", 14, false, HUDStyle.MUTED)
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.TextWrapped = true
	end
	for n, item in ipairs(def.items) do
		local row = HUDStyle.panel(list, item.id, UDim2.new(1, 0, 0, 52))
		row.LayoutOrder = n
		local name = HUDStyle.label(row, item.name, 15, true)
		name.Position = UDim2.fromOffset(12, 6)
		name.Size = UDim2.new(1, -140, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local desc = HUDStyle.label(row, `{item.description}  ·  {costText(item.cost)}`, 12, false, HUDStyle.MUTED)
		desc.Position = UDim2.fromOffset(12, 27)
		desc.Size = UDim2.new(1, -140, 0, 16)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		local b = button(row, "Buy", UDim2.fromOffset(104, 34))
		b.Name = "Buy"
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -9, 0.5, 0)
		b.Activated:Connect(function()
			buy(item.id)
		end)
	end
	message.Text = ""
	balances.Text = balanceText()
	window.Visible = true
	FPSController.freeCursor("vending", true)
end

function VendingController.start()
	if started then
		return
	end
	started = true
	buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopBuy") :: RemoteFunction

	gui = Instance.new("ScreenGui")
	gui.Name = "Vending"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	HUDStyle.scaled(gui)
	window = HUDStyle.panel(gui, "Window", UDim2.fromOffset(420, 300))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.48)
	window.BackgroundTransparency = 0.15
	window.Visible = false
	title = HUDStyle.label(window, "", 16, true)
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.new(1, -60, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(window, "X", UDim2.fromOffset(28, 26))
	close.Name = "Close"
	close.BackgroundColor3 = HUDStyle.PANEL
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Activated:Connect(VendingController.close)
	list = Instance.new("Frame")
	list.Name = "Items"
	list.Position = UDim2.fromOffset(12, 42)
	list.Size = UDim2.new(1, -24, 1, -110)
	list.BackgroundTransparency = 1
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	message = HUDStyle.label(window, "", 13, true)
	message.Position = UDim2.new(0, 14, 1, -60)
	message.Size = UDim2.new(1, -28, 0, 18)
	message.TextXAlignment = Enum.TextXAlignment.Left
	balances = HUDStyle.label(window, "", 13, true, HUDStyle.MUTED)
	balances.Position = UDim2.new(0, 14, 1, -32)
	balances.Size = UDim2.new(1, -28, 0, 18)
	balances.TextXAlignment = Enum.TextXAlignment.Left
	gui.Parent = player:WaitForChild("PlayerGui")

	local function refresh()
		if openMachine then
			balances.Text = balanceText()
		end
	end
	player:GetAttributeChangedSignal("Scrap"):Connect(refresh)
	player:GetAttributeChangedSignal("Wood"):Connect(refresh)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player or prompt.Name ~= "VendPrompt" then
			return
		end
		local machine = prompt:FindFirstAncestorWhichIsA("Model")
		if not machine then
			return
		end
		if openMachine == machine then
			VendingController.close()
		else
			VendingController.open(machine)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if openMachine and input.KeyCode == Enum.KeyCode.Escape then
			VendingController.close()
		end
	end)
	-- shut when the player walks away or dies
	RunService.Heartbeat:Connect(function()
		local m = openMachine
		if not m then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local front = m:FindFirstChild("PromptPart") :: BasePart?
		if not root or not hum or hum.Health <= 0 or not m.Parent
			or (front and (root.Position - front.Position).Magnitude > ShopConfig.USE_DISTANCE + 2) then
			VendingController.close()
		end
	end)
end

return VendingController
