--!strict
-- ScrapPickupController: client-only motion for the scrap stations, so it costs no network traffic.
--   * scrap pickups (tag "ScrapPickup") turn slowly and bob a little, so they read as items you can
--     take rather than map decoration (no glow or particles)
--   * a station's claw dips to the pad whenever the server drops scrap (station attribute "Drops")
-- Collecting itself is the pickup's ProximityPrompt, handled on the server; the "+1" is in HUDController.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ScrapPickupController = {}

local SPIN = math.rad(45) -- per second
local BOB = 0.12
local CLAW_DIP = 1.4
local CLAW_TIME = 0.7

local pickups: { [Model]: CFrame } = {}
local claws: { [Model]: number } = {} -- claw -> time the current dip started
local started = false

local function addPickup(m: Instance)
	if m:IsA("Model") then
		pickups[m] = m:GetPivot()
	end
end

local function watchStation(station: Instance)
	if not station:IsA("Model") then
		return
	end
	station:GetAttributeChangedSignal("Drops"):Connect(function()
		local claw = station:FindFirstChild("Claw")
		if claw and claw:IsA("Model") then
			claws[claw] = os.clock()
		end
	end)
end

function ScrapPickupController.start()
	if started then
		return
	end
	started = true
	for _, m in ipairs(CollectionService:GetTagged("ScrapPickup")) do
		addPickup(m)
	end
	CollectionService:GetInstanceAddedSignal("ScrapPickup"):Connect(addPickup)
	CollectionService:GetInstanceRemovedSignal("ScrapPickup"):Connect(function(m)
		pickups[m :: Model] = nil
	end)
	for _, s in ipairs(CollectionService:GetTagged("ScrapDropper")) do
		watchStation(s)
	end
	CollectionService:GetInstanceAddedSignal("ScrapDropper"):Connect(watchStation)

	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for m, base in pairs(pickups) do
			if m.Parent then
				local t = now - t0
				m:PivotTo(base * CFrame.new(0, 0.1 + BOB * math.sin(t * 2.2), 0) * CFrame.Angles(0, t * SPIN, 0))
			else
				pickups[m] = nil
			end
		end
		for claw, since in pairs(claws) do
			local rest = claw:GetAttribute("Rest")
			if typeof(rest) ~= "CFrame" or not claw.Parent then
				claws[claw] = nil
				continue
			end
			local k = (now - since) / CLAW_TIME
			if k >= 1 then
				claw:PivotTo(rest)
				claws[claw] = nil
			else
				claw:PivotTo(rest * CFrame.new(0, -CLAW_DIP * math.sin(k * math.pi), 0))
			end
		end
	end)
end

return ScrapPickupController
