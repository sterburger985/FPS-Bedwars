-- Client entry point. Lives in StarterPlayerScripts, so it runs once per session and survives
-- respawns; each controller handles CharacterAdded itself.
local StarterGui = game:GetService("StarterGui")

local FPSController = require(script:WaitForChild("FPSController"))
local CrosshairController = require(script:WaitForChild("CrosshairController"))
local BuildingController = require(script:WaitForChild("BuildingController"))
local HotbarController = require(script:WaitForChild("HotbarController"))
local HUDController = require(script:WaitForChild("HUDController"))
local ScrapPickupController = require(script:WaitForChild("ScrapPickupController"))
local VendingController = require(script:WaitForChild("VendingController"))

-- Our hotbar replaces Roblox's tool bar, and our health readout replaces Roblox's health bar
-- (only the display; the Humanoid's health is untouched).
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

FPSController.start()
CrosshairController.start()
BuildingController.start()
HotbarController.start()
HUDController.start()
ScrapPickupController.start()
VendingController.start()
