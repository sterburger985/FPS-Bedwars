--!strict
-- HUDStyle: one look for every HUD piece (hotbar, health, scrap counter, build panel, piece wheel,
-- vending menu). Understated survival-FPS style: dark see-through panels, thin grey borders, muted text,
-- one blue accent for the selected slot, a green health bar.
-- Sizes are designed at 1080p; HUDStyle.scaled(gui) adds a UIScale that follows the screen height.

local Workspace = game:GetService("Workspace")

local HUDStyle = {}

HUDStyle.PANEL = Color3.fromRGB(28, 28, 28)
HUDStyle.PANEL_ALPHA = 0.45 -- background transparency
HUDStyle.BORDER = Color3.fromRGB(110, 110, 106)
HUDStyle.BORDER_ALPHA = 0.55
HUDStyle.TEXT = Color3.fromRGB(226, 222, 214)
HUDStyle.MUTED = Color3.fromRGB(150, 146, 138)
HUDStyle.ACCENT = Color3.fromRGB(78, 148, 230) -- selected slot blue
HUDStyle.GOOD = Color3.fromRGB(128, 196, 92)
HUDStyle.BAD = Color3.fromRGB(226, 86, 74)
HUDStyle.HEALTH = Color3.fromRGB(110, 152, 56) -- health bar green
HUDStyle.HEALTH_BACK = Color3.fromRGB(40, 52, 30)
HUDStyle.SCRAP = Color3.fromRGB(176, 104, 54)

HUDStyle.FONT = Font.fromEnum(Enum.Font.GothamMedium)
HUDStyle.FONT_BOLD = Font.fromEnum(Enum.Font.GothamBold)

HUDStyle.SLOT = 62 -- hotbar slot size
HUDStyle.GAP = 5
HUDStyle.EDGE = 18 -- distance from the screen edges
HUDStyle.HOTBAR_SLOTS = 6

-- Hotbar width, so other pieces can sit beside it.
function HUDStyle.hotbarWidth(): number
	return HUDStyle.HOTBAR_SLOTS * HUDStyle.SLOT + (HUDStyle.HOTBAR_SLOTS - 1) * HUDStyle.GAP
end

function HUDStyle.panel(parent: Instance, name: string, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.BackgroundColor3 = HUDStyle.PANEL
	f.BackgroundTransparency = HUDStyle.PANEL_ALPHA
	f.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = HUDStyle.BORDER
	stroke.Transparency = HUDStyle.BORDER_ALPHA
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = f
	f.Parent = parent
	return f
end

function HUDStyle.label(parent: Instance, text: string, size: number, bold: boolean?, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = if bold then HUDStyle.FONT_BOLD else HUDStyle.FONT
	t.TextSize = size
	t.TextColor3 = color or HUDStyle.TEXT
	t.Text = text
	t.Parent = parent
	return t
end

function HUDStyle.box(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3, rot: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.Rotation = rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- Adds a UIScale that keeps the HUD the same share of the screen from 720p to 4K.
function HUDStyle.scaled(gui: ScreenGui)
	local s = Instance.new("UIScale")
	s.Parent = gui
	local function update()
		local cam = Workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 1080
		s.Scale = math.clamp(h / 1080, 0.7, 1.6)
	end
	update()
	local function watch()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end
	watch()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watch()
		update()
	end)
end

-- Small original item icons drawn from frames (no image assets).
function HUDStyle.icon(parent: Instance, item: string)
	local root = Instance.new("Frame")
	root.Name = "Icon"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromScale(0.62, 0.62)
	root.BackgroundTransparency = 1
	root.Parent = parent
	if item == "Blueprint" then
		-- rolled plan sheet with a grid
		local sheet = HUDStyle.box(root, "Sheet", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.7), Color3.fromRGB(52, 98, 158), -8)
		for n = 1, 3 do
			HUDStyle.box(sheet, "H", UDim2.fromScale(0.5, n / 4), UDim2.new(0.86, 0, 0, 1), Color3.fromRGB(196, 220, 248))
			HUDStyle.box(sheet, "V", UDim2.fromScale(n / 4, 0.5), UDim2.new(0, 1, 0.8, 0), Color3.fromRGB(196, 220, 248))
		end
		HUDStyle.box(sheet, "Roll", UDim2.fromScale(0.04, 0.5), UDim2.fromScale(0.1, 1.08), Color3.fromRGB(150, 180, 214))
	elseif item == "Hammer" then
		HUDStyle.box(root, "Handle", UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.14, 0.8), Color3.fromRGB(128, 86, 52), 35)
		HUDStyle.box(root, "Head", UDim2.fromScale(0.62, 0.32), UDim2.fromScale(0.58, 0.22), Color3.fromRGB(150, 150, 154), 35)
	elseif item == "Scrap" then
		HUDStyle.box(root, "A", UDim2.fromScale(0.42, 0.6), UDim2.fromScale(0.62, 0.36), Color3.fromRGB(110, 64, 34), -14)
		HUDStyle.box(root, "B", UDim2.fromScale(0.58, 0.42), UDim2.fromScale(0.5, 0.34), HUDStyle.SCRAP, 18)
		HUDStyle.box(root, "C", UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.3, 0.2), Color3.fromRGB(150, 150, 150), -6)
	elseif item == "Wood" then
		HUDStyle.box(root, "A", UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.9, 0.24), Color3.fromRGB(150, 104, 62))
		HUDStyle.box(root, "B", UDim2.fromScale(0.5, 0.66), UDim2.fromScale(0.9, 0.24), Color3.fromRGB(122, 82, 48))
	end
end

return HUDStyle
