--!strict
-- ScrapDropperService: every team scrap station (tag "ScrapDropper") drops scrap pickups on its pad.
--
--  * every ScrapConfig.INTERVAL seconds a dropper with room makes PER_DROP pickups, up to MAX_ACTIVE
--    uncollected at once; while full it waits, and the next drop comes a full interval after a pickup
--    is collected or expires
--  * a pickup lasts LIFETIME seconds, then it is removed
--  * collecting: the pickup's ProximityPrompt (E, "Collect Scrap (+1)") fires on the server; the server
--    checks the pickup is still there and not already taken, and that the player is alive and in range,
--    then marks it taken before anything else, adds the scrap through Resources and removes it.
--    Two players pressing at once: the first one wins, the second finds it already taken.
--  * the station's attribute "Drops" counts drops so clients can animate the claw
--
-- Remotes.ScrapCollected (RemoteEvent, server -> collecting player): amount, for the "+1" feedback.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ScrapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScrapConfig"))
local Resources = require(script.Parent:WaitForChild("Resources"))

local ScrapDropperService = {}

type Pickup = { model: Model, spot: number, expiresAt: number, taken: boolean, dropper: Dropper }
type Dropper = { station: Model, output: Attachment, pickups: { Pickup }, nextAt: number }

local droppers: { [Model]: Dropper } = {}
local pickupFolder: Folder
local collectedRemote: RemoteEvent
local started = false

local function template(): Model?
	local assets = ServerStorage:FindFirstChild("MapAssets")
	local t = assets and assets:FindFirstChild("ScrapPickup")
	return if t and t:IsA("Model") then t else nil
end

local function freeSpot(d: Dropper): number?
	for n = 1, #ScrapConfig.SPOTS do
		local used = false
		for _, p in ipairs(d.pickups) do
			if p.spot == n then
				used = true
				break
			end
		end
		if not used then
			return n
		end
	end
	return nil
end

local function remove(p: Pickup)
	local list = p.dropper.pickups
	local i = table.find(list, p)
	if i then
		table.remove(list, i)
	end
	if p.model.Parent then
		p.model:Destroy()
	end
end

local function collect(p: Pickup, player: Player)
	if p.taken or not p.model.Parent then
		return -- already collected (another player got there first) or expired
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return
	end
	local range = ScrapConfig.PROMPT_DISTANCE + ScrapConfig.SERVER_RANGE_SLACK
	if (root.Position - p.model:GetPivot().Position).Magnitude > range then
		return
	end
	p.taken = true -- before anything that could yield, so it can only be collected once
	remove(p)
	Resources.add(player, "Scrap", ScrapConfig.VALUE)
	collectedRemote:FireClient(player, ScrapConfig.VALUE)
end

local function spawnPickup(d: Dropper): boolean
	local spot = freeSpot(d)
	local t = template()
	if not spot or not t then
		return false
	end
	local m = t:Clone()
	m.Name = "ScrapPickup"
	for _, part in ipairs(m:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	-- invisible hit box that carries the prompt and is the model's pivot
	local box = Instance.new("Part")
	box.Name = "Hitbox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(2.4, 1.6, 2.4)
	box.CFrame = m:GetPivot() * CFrame.new(0, 0.8, 0)
	box.Parent = m
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = `Collect Scrap (+{ScrapConfig.VALUE})`
	prompt.ObjectText = "Scrap"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ScrapConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	local yaw = CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	m:PivotTo(d.output.WorldCFrame * CFrame.new(ScrapConfig.SPOTS[spot]) * yaw)
	m:SetAttribute("Team", d.station:GetAttribute("Team"))
	CollectionService:AddTag(m, "ScrapPickup")
	local p: Pickup = { model = m, spot = spot, expiresAt = os.clock() + ScrapConfig.LIFETIME, taken = false, dropper = d }
	table.insert(d.pickups, p)
	prompt.Triggered:Connect(function(player)
		collect(p, player)
	end)
	m.Parent = pickupFolder
	return true
end

local function addDropper(station: Instance)
	if not station:IsA("Model") or not station:IsDescendantOf(workspace) or droppers[station] then
		return
	end
	local out: Instance? = nil
	for _, d in ipairs(station:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == "ScrapOutput" then
			out = d
			break
		end
	end
	if not out or not out:IsA("Attachment") then
		warn(`ScrapDropper {station:GetFullName()} has no ScrapOutput attachment`)
		return
	end
	droppers[station] = { station = station, output = out, pickups = {}, nextAt = os.clock() + ScrapConfig.INTERVAL }
end

local function step()
	local now = os.clock()
	for station, d in pairs(droppers) do
		if not station.Parent then
			for _, p in ipairs(table.clone(d.pickups)) do
				remove(p)
			end
			droppers[station] = nil
			continue
		end
		for _, p in ipairs(table.clone(d.pickups)) do
			if not p.model.Parent then
				p.taken = true -- removed by something else: free its spot
				remove(p)
			elseif now >= p.expiresAt and not p.taken then
				p.taken = true
				remove(p)
			end
		end
		if #d.pickups >= ScrapConfig.MAX_ACTIVE then
			d.nextAt = now + ScrapConfig.INTERVAL -- full: pause, restart the timer when there is room
		elseif now >= d.nextAt then
			local made = 0
			for _ = 1, ScrapConfig.PER_DROP do
				if #d.pickups < ScrapConfig.MAX_ACTIVE and spawnPickup(d) then
					made += 1
				end
			end
			if made > 0 then
				station:SetAttribute("Drops", ((station:GetAttribute("Drops") :: number?) or 0) + 1)
			end
			d.nextAt = now + ScrapConfig.INTERVAL
		end
	end
end

-- Uncollected pickups at a station (for tests and future UI).
function ScrapDropperService.activeCount(station: Model): number
	local d = droppers[station]
	return if d then #d.pickups else 0
end

function ScrapDropperService.start()
	if started then
		return
	end
	started = true
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "ScrapPickups"
	pickupFolder.Parent = workspace
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	collectedRemote = Instance.new("RemoteEvent")
	collectedRemote.Name = "ScrapCollected"
	collectedRemote.Parent = remotes

	if not template() then
		warn("ScrapDropperService: ServerStorage.MapAssets.ScrapPickup is missing; no scrap will drop")
	end
	for _, s in ipairs(CollectionService:GetTagged("ScrapDropper")) do
		addDropper(s)
	end
	CollectionService:GetInstanceAddedSignal("ScrapDropper"):Connect(addDropper)
	task.spawn(function()
		while true do
			step()
			task.wait(0.25)
		end
	end)
end

return ScrapDropperService
