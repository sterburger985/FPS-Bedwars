--!strict
-- HotbarController: the equipment strip at the bottom centre (Rust-style).
--   * slots come from the server (player attribute "Hotbar"); empty slots stay empty
--   * 1-6 select a slot, the mouse wheel cycles through the slots that hold something,
--     pressing the selected slot again puts the item away
--   * shortcuts: B = blueprint, H = dev hammer (Studio), Q = put away
--   * the selected slot gets the blue highlight; the server is told (Remotes.Equip) so it knows what
--     is in hand, and BuildingController switches the blueprint or hammer on or off
-- Resources (Wood, Scrap) never take a slot.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local HUDStyle = require(script.Parent:WaitForChild("HUDStyle"))
local BuildingController = require(script.Parent:WaitForChild("BuildingController"))
local FPSController = require(script.Parent:WaitForChild("FPSController"))

local HotbarController = {}

local player = Players.LocalPlayer
local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local slots: { string } = {}
local selected = 0 -- 0 = hands empty
local frames: { Frame } = {}
local equipRemote: RemoteEvent
local started = false

local function itemIn(n: number): string
	return slots[n] or ""
end

local function draw()
	for n, f in ipairs(frames) do
		local item = itemIn(n)
		local icon = f:FindFirstChild("Icon")
		if icon and icon:GetAttribute("Item") ~= item then
			icon:Destroy()
			icon = nil
		end
		if not icon and item ~= "" then
			HUDStyle.icon(f, item)
			local made = f:FindFirstChild("Icon")
			if made then
				made:SetAttribute("Item", item)
			end
		end
		local on = n == selected
		local stroke = f:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if on then HUDStyle.ACCENT else HUDStyle.BORDER
		stroke.Transparency = if on then 0 else HUDStyle.BORDER_ALPHA
		stroke.Thickness = if on then 2 else 1
		f.BackgroundColor3 = if on then HUDStyle.ACCENT else HUDStyle.PANEL
		f.BackgroundTransparency = if on then 0.6 else HUDStyle.PANEL_ALPHA
		local name = f:FindFirstChild("ItemName") :: TextLabel
		local def = Items.DEFS[item]
		name.Text = if on and def then def.name else ""
	end
end

local function select(n: number)
	if n ~= 0 and itemIn(n) == "" then
		return -- empty slots do nothing
	end
	if n == selected then
		n = 0 -- pressing the held slot again puts it away
	end
	selected = n
	local item = itemIn(n)
	equipRemote:FireServer(n)
	BuildingController.setTool(if item ~= "" then item else nil)
	draw()
end

function HotbarController.select(n: number)
	select(n)
end

function HotbarController.selected(): (number, string)
	return selected, itemIn(selected)
end

local function slotOf(item: string): number?
	for n = 1, Items.HOTBAR_SIZE do
		if itemIn(n) == item then
			return n
		end
	end
	return nil
end

local function cycle(dir: number)
	local filled = {}
	for n = 1, Items.HOTBAR_SIZE do
		if itemIn(n) ~= "" then
			table.insert(filled, n)
		end
	end
	if #filled == 0 then
		return
	end
	local at = table.find(filled, selected)
	local nextIndex = if at then (at - 1 + dir) % #filled + 1 else (if dir > 0 then 1 else #filled)
	local target = filled[nextIndex]
	if target ~= selected then
		select(target)
	end
end

local function readSlots()
	local raw = player:GetAttribute("Hotbar")
	slots = {}
	if type(raw) == "string" then
		local n = 0
		for part in string.gmatch(raw .. ",", "([^,]*),") do
			n += 1
			slots[n] = part
		end
	end
	if selected ~= 0 and itemIn(selected) == "" then
		selected = 0
		BuildingController.setTool(nil)
	end
	draw()
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	HUDStyle.scaled(gui)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -HUDStyle.EDGE)
	bar.Size = UDim2.fromOffset(HUDStyle.hotbarWidth(), HUDStyle.SLOT)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, HUDStyle.GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	for n = 1, Items.HOTBAR_SIZE do
		local f = HUDStyle.panel(bar, "Slot" .. n, UDim2.fromOffset(HUDStyle.SLOT, HUDStyle.SLOT))
		f.LayoutOrder = n
		local num = HUDStyle.label(f, tostring(n), 11, true, HUDStyle.MUTED)
		num.Name = "Number"
		num.Position = UDim2.fromOffset(4, 2)
		num.Size = UDim2.fromOffset(10, 12)
		num.TextXAlignment = Enum.TextXAlignment.Left
		num.ZIndex = 3
		local name = HUDStyle.label(f, "", 10, true, HUDStyle.TEXT)
		name.Name = "ItemName"
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -2)
		name.Size = UDim2.new(1, -4, 0, 11)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 3
		table.insert(frames, f)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

function HotbarController.start()
	if started then
		return
	end
	started = true
	equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Equip") :: RemoteEvent
	build()
	player:GetAttributeChangedSignal("Hotbar"):Connect(readSlots)
	readSlots()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.Escape then
			if selected ~= 0 and not FPSController.isCursorFree() then
				select(selected) -- put the item away
			end
			return
		end
		if processed or FPSController.isCursorFree() then
			return
		end
		local n = KEYS[input.KeyCode]
		if n then
			select(n)
		elseif input.KeyCode == Enum.KeyCode.B then
			local s = slotOf("Blueprint")
			if s then
				select(s)
			end
		elseif input.KeyCode == Enum.KeyCode.H and RunService:IsStudio() then
			local s = slotOf("Hammer")
			if s then
				select(s)
			end
		elseif input.KeyCode == Enum.KeyCode.Q and selected ~= 0 then
			select(selected)
		end
	end)
	-- the wheel is bound above the camera's own zoom binding so it always reaches the hotbar
	ContextActionService:BindActionAtPriority("HotbarWheel", function(_, state, input)
		if state ~= Enum.UserInputState.Change or FPSController.isCursorFree() then
			return Enum.ContextActionResult.Pass
		end
		cycle(if input.Position.Z > 0 then -1 else 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)

	-- respawn and death put the item away (the server clears "Equipped" too)
	player.CharacterAdded:Connect(function(char)
		selected = 0
		BuildingController.setTool(nil)
		draw()
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			if selected ~= 0 then
				selected = 0
				BuildingController.setTool(nil)
				draw()
			end
		end)
	end)
end

return HotbarController
