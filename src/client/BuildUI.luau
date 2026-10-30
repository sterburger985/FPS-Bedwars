--!strict
-- BuildUI: what the blueprint shows.
--   * a compact panel just above the hotbar: selected piece, its cost, the Wood count, and a status
--     line that turns red with the reason when the piece can't be built
--   * the piece wheel: hold right-click with the blueprint out, point at a piece, let go
-- The hotbar itself is HotbarController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildingConfig"))
local HUDStyle = require(script.Parent:WaitForChild("HUDStyle"))

local BuildUI = {}

local gui: ScreenGui
local panel: Frame
local pieceLabel: TextLabel
local woodLabel: TextLabel
local status: TextLabel
local wheel: Frame
local wheelCentre: TextLabel
local segments: { Frame } = {}

local WHEEL_RADIUS = 168
local SEG = Vector2.new(116, 50)

local function costOf(id: string): number
	return BuildingConfig.PIECES[id].cost.Wood or 0
end

function BuildUI.create()
	gui = Instance.new("ScreenGui")
	gui.Name = "BuildUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	HUDStyle.scaled(gui)

	-- panel above the hotbar
	panel = HUDStyle.panel(gui, "Panel", UDim2.fromOffset(math.max(HUDStyle.hotbarWidth(), 520), 28))
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -(HUDStyle.EDGE + HUDStyle.SLOT + 8))
	panel.Visible = false
	pieceLabel = HUDStyle.label(panel, "", 14, true)
	pieceLabel.Name = "Piece"
	pieceLabel.Position = UDim2.fromOffset(10, 0)
	pieceLabel.Size = UDim2.new(0.6, 0, 1, 0)
	pieceLabel.TextXAlignment = Enum.TextXAlignment.Left
	HUDStyle.label(panel, "RMB pieces   R rotate", 12, false, HUDStyle.MUTED).Size = UDim2.fromScale(1, 1)
	woodLabel = HUDStyle.label(panel, "", 14, true)
	woodLabel.Name = "Wood"
	woodLabel.AnchorPoint = Vector2.new(1, 0)
	woodLabel.Position = UDim2.new(1, -10, 0, 0)
	woodLabel.Size = UDim2.new(0.4, 0, 1, 0)
	woodLabel.TextXAlignment = Enum.TextXAlignment.Right

	status = HUDStyle.label(gui, "", 14, true)
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -(HUDStyle.EDGE + HUDStyle.SLOT + 42))
	status.Size = UDim2.fromOffset(560, 20)
	status.TextStrokeTransparency = 0.55
	status.Visible = false

	-- piece wheel, centred on the crosshair
	wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(0, 0)
	wheel.BackgroundTransparency = 1
	wheel.Visible = false
	wheel.Parent = gui
	local hub = HUDStyle.panel(wheel, "Hub", UDim2.fromOffset(120, 120))
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromOffset(0, 0)
	local hubCorner = hub:FindFirstChildOfClass("UICorner") :: UICorner
	hubCorner.CornerRadius = UDim.new(0.5, 0)
	wheelCentre = HUDStyle.label(hub, "", 13, true)
	wheelCentre.Size = UDim2.fromScale(1, 1)
	wheelCentre.TextWrapped = true
	local n = #BuildingConfig.PIECE_ORDER
	for idx, id in ipairs(BuildingConfig.PIECE_ORDER) do
		local a = (idx - 1) / n * math.pi * 2
		local seg = HUDStyle.panel(wheel, id, UDim2.fromOffset(SEG.X, SEG.Y))
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Position = UDim2.fromOffset(math.sin(a) * WHEEL_RADIUS, -math.cos(a) * WHEEL_RADIUS)
		local name = HUDStyle.label(seg, BuildingConfig.PIECES[id].displayName, 13, true)
		name.Position = UDim2.fromOffset(0, 7)
		name.Size = UDim2.new(1, 0, 0, 18)
		local cost = HUDStyle.label(seg, `{costOf(id)} Wood`, 11, false, HUDStyle.MUTED)
		cost.Name = "Cost"
		cost.Position = UDim2.fromOffset(0, 28)
		cost.Size = UDim2.new(1, 0, 0, 14)
		table.insert(segments, seg)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function BuildUI.setOpen(open: boolean)
	panel.Visible = open
	status.Visible = open
	if not open then
		BuildUI.showWheel(false)
	end
end

function BuildUI.showStatus(show: boolean)
	status.Visible = show
end

function BuildUI.setPiece(index: number, wood: number)
	local id = BuildingConfig.PIECE_ORDER[index]
	local cost = costOf(id)
	pieceLabel.Text = `{BuildingConfig.PIECES[id].displayName}  ·  {cost} Wood`
	woodLabel.Text = `Wood {wood}`
	woodLabel.TextColor3 = if wood >= cost then HUDStyle.TEXT else HUDStyle.BAD
end

-- kind: "ok" | "bad" | "info"
function BuildUI.setStatus(text: string, kind: string)
	status.Text = text
	status.TextColor3 = if kind == "ok" then HUDStyle.GOOD elseif kind == "bad" then HUDStyle.BAD else HUDStyle.TEXT
end

function BuildUI.showWheel(show: boolean)
	wheel.Visible = show
end

-- Highlights the segment under the cursor (or the current piece when the cursor is in the hub).
function BuildUI.highlight(index: number, current: number)
	for n, seg in ipairs(segments) do
		local stroke = seg:FindFirstChildOfClass("UIStroke") :: UIStroke
		local on = n == index
		stroke.Color = if on then HUDStyle.ACCENT else HUDStyle.BORDER
		stroke.Transparency = if on then 0 else HUDStyle.BORDER_ALPHA
		stroke.Thickness = if on then 2 else 1
		seg.BackgroundColor3 = if on then HUDStyle.ACCENT else HUDStyle.PANEL
		seg.BackgroundTransparency = if on then 0.55 else (if n == current then 0.25 else HUDStyle.PANEL_ALPHA)
	end
	local id = BuildingConfig.PIECE_ORDER[index]
	wheelCentre.Text = if id then BuildingConfig.PIECES[id].displayName else ""
end

-- Which piece a screen point picks: by angle around the screen centre, or nil inside the hub.
function BuildUI.pick(point: Vector2, viewport: Vector2): number?
	local scale = 1
	local s = gui:FindFirstChildOfClass("UIScale")
	if s then
		scale = s.Scale
	end
	local d = point - viewport / 2
	if d.Magnitude < 40 * scale then
		return nil
	end
	local n = #BuildingConfig.PIECE_ORDER
	local a = math.atan2(d.X, -d.Y) -- 0 at the top, clockwise
	if a < 0 then
		a += math.pi * 2
	end
	return math.floor(a / (math.pi * 2) * n + 0.5) % n + 1
end

return BuildUI
