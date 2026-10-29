--!strict
-- BuildUI: compact blueprint bar at the bottom of the screen.
--   six piece slots (key, name, cost), the selected one highlighted, the Wood count, and a status
--   line that turns red with the reason when the piece can't be built. A small key hint shows
--   when the blueprint is put away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildingConfig"))

local BuildUI = {}

local FONT = Font.fromEnum(Enum.Font.GothamMedium)
local FONT_BOLD = Font.fromEnum(Enum.Font.GothamBold)
local PANEL = Color3.fromRGB(20, 22, 24)
local TEXT = Color3.fromRGB(232, 228, 220)
local MUTED = Color3.fromRGB(150, 146, 138)
local ACCENT = Color3.fromRGB(226, 170, 82)
local GOOD = Color3.fromRGB(110, 226, 130)
local BAD = Color3.fromRGB(244, 92, 80)

local gui: ScreenGui
local bar: Frame
local slots: { Frame } = {}
local woodLabel: TextLabel
local status: TextLabel
local hint: TextLabel

local function label(parent: Instance, text: string, size: number, font: Font, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.Text = text
	t.Parent = parent
	return t
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

function BuildUI.create(isStudio: boolean)
	gui = Instance.new("ScreenGui")
	gui.Name = "BuildUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -14)
	bar.Size = UDim2.fromOffset(6 * 88 + 6 * 6 + 98, 64)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar

	for n, id in ipairs(BuildingConfig.PIECE_ORDER) do
		local def = BuildingConfig.PIECES[id]
		local s = Instance.new("Frame")
		s.Name = id
		s.LayoutOrder = n
		s.Size = UDim2.fromOffset(88, 58)
		s.BackgroundColor3 = PANEL
		s.BackgroundTransparency = 0.25
		corner(s, 6)
		local stroke = Instance.new("UIStroke")
		stroke.Color = ACCENT
		stroke.Thickness = 2
		stroke.Enabled = false
		stroke.Parent = s
		local key = label(s, tostring(n), 12, FONT_BOLD, MUTED)
		key.Name = "Key"
		key.Position = UDim2.fromOffset(6, 4)
		key.Size = UDim2.fromOffset(12, 12)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local name = label(s, def.displayName, 12, FONT_BOLD, TEXT)
		name.Name = "PieceName"
		name.Position = UDim2.fromOffset(4, 18)
		name.Size = UDim2.new(1, -8, 0, 16)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local cost = def.cost.Wood or 0
		local c = label(s, `{cost} Wood`, 11, FONT, MUTED)
		c.Name = "Cost"
		c.Position = UDim2.fromOffset(4, 38)
		c.Size = UDim2.new(1, -8, 0, 14)
		s.Parent = bar
		table.insert(slots, s)
	end

	local wood = Instance.new("Frame")
	wood.Name = "Wood"
	wood.LayoutOrder = 99
	wood.Size = UDim2.fromOffset(98, 58)
	wood.BackgroundColor3 = PANEL
	wood.BackgroundTransparency = 0.25
	corner(wood, 6)
	local wt = label(wood, "WOOD", 11, FONT_BOLD, MUTED)
	wt.Position = UDim2.fromOffset(0, 8)
	wt.Size = UDim2.new(1, 0, 0, 12)
	woodLabel = label(wood, "0", 22, FONT_BOLD, ACCENT)
	woodLabel.Name = "Amount"
	woodLabel.Position = UDim2.fromOffset(0, 24)
	woodLabel.Size = UDim2.new(1, 0, 0, 24)
	wood.Parent = bar

	status = label(gui, "", 14, FONT_BOLD, TEXT)
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -84)
	status.Size = UDim2.fromOffset(520, 20)
	status.TextStrokeTransparency = 0.5
	status.Visible = false

	hint = label(gui, if isStudio then "[B] Blueprint    [H] Dev hammer" else "[B] Blueprint", 13, FONT_BOLD, TEXT)
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -14)
	hint.Size = UDim2.fromOffset(320, 18)
	hint.TextTransparency = 0.2
	hint.TextStrokeTransparency = 0.6

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function BuildUI.setOpen(open: boolean, hammer: boolean?)
	bar.Visible = open
	status.Visible = open or hammer == true
	hint.Visible = not open and not hammer
end

function BuildUI.select(index: number)
	for n, s in ipairs(slots) do
		local on = n == index
		local stroke = s:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = on
		end
		s.BackgroundTransparency = if on then 0.05 else 0.35
		local key = s:FindFirstChild("Key") :: TextLabel
		key.TextColor3 = if on then ACCENT else MUTED
	end
end

function BuildUI.setWood(n: number)
	woodLabel.Text = tostring(n)
end

-- kind: "ok" | "bad" | "info"
function BuildUI.setStatus(text: string, kind: string)
	status.Text = text
	status.TextColor3 = if kind == "ok" then GOOD elseif kind == "bad" then BAD else TEXT
end

return BuildUI
