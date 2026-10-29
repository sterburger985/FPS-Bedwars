--!strict
-- MapSpin: slowly spins decorative map parts tagged "FPSB_Spin" (the centre's Amethyst Beacon halo and
-- crystal). Runs on each client only, so the motion costs no network traffic. Attribute SpinSpeed is
-- degrees per second about the part's own vertical axis (negative = the other way).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "FPSB_Spin"

RunService.RenderStepped:Connect(function(dt: number)
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local speed = inst:GetAttribute("SpinSpeed")
			local deg = if typeof(speed) == "number" then speed else 20
			inst.CFrame = inst.CFrame * CFrame.Angles(0, math.rad(deg) * dt, 0)
		end
	end
end)
