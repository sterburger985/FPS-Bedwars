--!strict
-- CrosshairController: four-line crosshair with a dark outline, exactly at the centre of the
-- viewport (IgnoreGuiInset, so it matches camera:ViewportPointToRay at the viewport centre).
--   setMode("default" | "build" | "hammer")
--   setValid(true | false | nil)   build mode colour: green / red / neutral
--   kick(amount)                   spread the lines out (weapon fire), eases back by itself
--   aimRay()                       the camera ray through the crosshair, for every aim test

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CrosshairController = {}

local LOOKS = {
	default = { gap = 5, length = 7, thickness = 2, color = Color3.fromRGB(245, 245, 245), dot = false },
	build = { gap = 3, length = 5, thickness = 2, color = Color3.fromRGB(235, 235, 235), dot = true },
	hammer = { gap = 4, length = 6, thickness = 2, color = Color3.fromRGB(255, 176, 64), dot = true },
}
local VALID = Color3.fromRGB(96, 232, 120)
local INVALID = Color3.fromRGB(244, 82, 72)

local gui: ScreenGui
local lines: { Frame } = {}
local dot: Frame
local mode = "default"
local valid: boolean? = nil
local spread = 0
local started = false

local function makeBar(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = f
	f.Parent = parent
	return f
end

local function layout()
	local look = LOOKS[mode]
	local color = look.color
	if mode == "build" and valid ~= nil then
		color = if valid then VALID else INVALID
	end
	local g = look.gap + spread
	local L, T = look.length, look.thickness
	local off = g + L / 2
	-- up, down, left, right
	local spec = {
		{ UDim2.fromOffset(0, -off), UDim2.fromOffset(T, L) },
		{ UDim2.fromOffset(0, off), UDim2.fromOffset(T, L) },
		{ UDim2.fromOffset(-off, 0), UDim2.fromOffset(L, T) },
		{ UDim2.fromOffset(off, 0), UDim2.fromOffset(L, T) },
	}
	for n, f in ipairs(lines) do
		f.Position = spec[n][1]
		f.Size = spec[n][2]
		f.BackgroundColor3 = color
	end
	dot.Visible = look.dot
	dot.BackgroundColor3 = color
end

function CrosshairController.setMode(m: string)
	if LOOKS[m] and m ~= mode then
		mode = m
		layout()
	end
end

function CrosshairController.setValid(v: boolean?)
	if v ~= valid then
		valid = v
		layout()
	end
end

function CrosshairController.kick(amount: number?)
	spread = math.min(spread + (amount or 4), 18)
end

function CrosshairController.aimRay(): Ray
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	return cam:ViewportPointToRay(vs.X / 2, vs.Y / 2)
end

function CrosshairController.start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = gui
	for _, name in ipairs({ "Up", "Down", "Left", "Right" }) do
		table.insert(lines, makeBar(root, name))
	end
	dot = makeBar(root, "Dot")
	dot.Size = UDim2.fromOffset(2, 2)
	dot.Position = UDim2.fromOffset(0, 0)
	layout()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function(dt)
		if spread > 0 then
			spread = math.max(0, spread - dt * 40)
			layout()
		end
	end)
end

return CrosshairController
