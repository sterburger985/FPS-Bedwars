--!strict
-- FPSController: locked first-person camera.
--  * CameraMode LockFirstPerson (Roblox's own camera, so normal movement, jumping and climbing stay)
--  * field of view and mouse sensitivity from BuildingConfig (FOV, MOUSE_SENSITIVITY)
--  * hides the local head, hats and hair every frame so nothing blocks the view
--  * re-applies on every respawn; set FPSController.setSensitivity(n) from a settings menu later

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildingConfig"))

local FPSController = {}

local player = Players.LocalPlayer
local sensitivity = BuildingConfig.MOUSE_SENSITIVITY
local hidden: { BasePart } = {}
local started = false

-- Parts that sit in front of the first-person camera: the head and anything welded to it.
local function collectHidden(char: Model)
	table.clear(hidden)
	local head = char:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") then
		return
	end
	table.insert(hidden, head)
	local function scan(inst: Instance)
		if inst:IsA("Accessory") then
			local handle = inst:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				table.insert(hidden, handle)
			end
		end
	end
	for _, c in ipairs(char:GetChildren()) do
		scan(c)
	end
	char.ChildAdded:Connect(function(c)
		task.defer(scan, c)
	end)
end

function FPSController.setSensitivity(n: number)
	sensitivity = math.clamp(n, 0.1, 4)
	UserInputService.MouseDeltaSensitivity = sensitivity
end

function FPSController.start()
	if started then
		return
	end
	started = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5
	UserInputService.MouseDeltaSensitivity = sensitivity

	player.CharacterAdded:Connect(collectHidden)
	if player.Character then
		task.spawn(collectHidden, player.Character)
	end

	-- After Roblox's camera update, so our values win.
	RunService:BindToRenderStep("FPSController", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if cam and cam.FieldOfView ~= BuildingConfig.FOV then
			cam.FieldOfView = BuildingConfig.FOV
		end
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		UserInputService.MouseIconEnabled = false -- the crosshair replaces the cursor
		for _, p in ipairs(hidden) do
			p.LocalTransparencyModifier = 1
		end
	end)
end

return FPSController
