-- Client entry point. Lives in StarterPlayerScripts, so it runs once per session and survives
-- respawns; each controller handles CharacterAdded itself.
local StarterGui = game:GetService("StarterGui")

local FPSController = require(script:WaitForChild("FPSController"))
local CrosshairController = require(script:WaitForChild("CrosshairController"))
local BuildingController = require(script:WaitForChild("BuildingController"))

-- Keys 1-6 belong to the blueprint, so the default tool hotbar is turned off.
-- (A custom weapon hotbar will replace it.)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			break
		end
		task.wait(0.5)
	end
end)

FPSController.start()
CrosshairController.start()
BuildingController.start()
