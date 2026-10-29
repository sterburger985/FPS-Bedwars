--!strict
-- BuildingService: the server side of blueprint building.
--
--  * publishes the build grids (one per BuildFloor) and the no-build zones to ReplicatedStorage
--  * validates every placement with the same BuildGrid.evaluate the client preview uses, plus a
--    rate limit and the builder's real head position, then charges the cost once and builds
--  * owns piece health: BuildingService.damage(partOrModel, amount) is the hook for weapons
--  * a Studio-only dev hammer remote for testing destruction
--
-- Remotes (ReplicatedStorage.Remotes): BuildPlace (RemoteFunction, request -> ok, reason) and
-- DevHammer (RemoteEvent, part).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared:WaitForChild("BuildingConfig"))
local BuildGrid = require(Shared:WaitForChild("BuildGrid"))
local Resources = require(script.Parent:WaitForChild("Resources"))

local BuildingService = {}

local PIECE_TAG = "BuildPiece"

local registry = BuildGrid.newRegistry()
local grids: { [string]: BuildGrid.Grid } = {}
local zones: { BuildGrid.Zone } = {}
local buildsFolder: Folder
local started = false

----------------------------------------------------------------------------------------------
-- Setup: grids, zones, remotes

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

local function publishGrids()
	local out = folder(ReplicatedStorage, "BuildGrids")
	out:ClearAllChildren()
	for _, floor in ipairs(CollectionService:GetTagged("BuildFloor")) do
		if floor:IsA("BasePart") and floor:IsDescendantOf(workspace) and floor.Parent then
			local id = floor.Parent.Name
			local c = Instance.new("Configuration")
			c.Name = id
			c:SetAttribute("Frame", floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0))
			c:SetAttribute("HalfX", floor.Size.X / 2)
			c:SetAttribute("HalfZ", floor.Size.Z / 2)
			c.Parent = out
		end
	end
	grids = BuildGrid.readGrids(out)
end

local function addZone(out: Folder, name: string, inst: Instance, margin: number)
	local cf: CFrame, size: Vector3
	if inst:IsA("Model") then
		cf, size = inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		cf, size = inst.CFrame, inst.Size
	else
		return
	end
	local extra = BuildingConfig.ZONE_EXTRA_HEIGHT
	local c = Instance.new("Configuration")
	c.Name = name
	c:SetAttribute("CFrame", cf * CFrame.new(0, extra / 2, 0))
	c:SetAttribute("Size", size + Vector3.new(margin * 2, margin * 2 + extra, margin * 2))
	c.Parent = out
end

local function publishZones()
	local out = folder(ReplicatedStorage, "BuildZones")
	out:ClearAllChildren()
	local m = BuildingConfig.ZONE_MARGINS
	local islands = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("TeamIslands")
	if islands then
		for _, island in ipairs(islands:GetChildren()) do
			local shed = island:FindFirstChild("StarterShed")
			if shed then
				addZone(out, island.Name .. "_Starter", shed, m.StarterShed)
			end
		end
	end
	for _, tag in ipairs({ "Bed", "SpawnPad", "Shop", "ResourceDispenser" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsDescendantOf(workspace) then
				local margin = if inst.Name == "CenterDispenser" then m.CenterDispenser else m[tag]
				addZone(out, tag .. "_" .. (inst.Parent and inst.Parent.Name or "?"), inst, margin)
			end
		end
	end
	zones = BuildGrid.readZones(out)
end

----------------------------------------------------------------------------------------------
-- Building pieces

local function shade(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function trim(parent: Instance, cf: CFrame, size: Vector3, color: Color3)
	local t = Instance.new("Part")
	t.Name = "Trim"
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.Material = Enum.Material.Wood
	t.Color = color
	t.CFrame = cf
	t.Size = size
	t.TopSurface = Enum.SurfaceType.Smooth
	t.BottomSurface = Enum.SurfaceType.Smooth
	t.Parent = parent
end

local function buildModel(req: BuildGrid.Request, fp: BuildGrid.Footprint, world: { BuildGrid.Box }, player: Player): Model
	local def = BuildingConfig.PIECES[req.piece]
	local model = Instance.new("Model")
	model.Name = req.piece
	model.ModelStreamingMode = Enum.ModelStreamingMode.Default
	model:SetAttribute("Piece", req.piece)
	model:SetAttribute("Grid", req.grid)
	model:SetAttribute("Keys", table.concat(fp.keys, ";"))
	model:SetAttribute("Slot", `{req.i},{req.j},{req.k},{req.rot}`)
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Team", if player.Team then player.Team.Name else "")
	model:SetAttribute("MaxHealth", def.health)
	model:SetAttribute("Health", def.health)
	local frameColor = shade(def.color, 0.62)
	for n, b in ipairs(world) do
		local p = Instance.new("Part")
		p.Name = if n == 1 then "Main" else "Part"
		p.Anchored = true
		p.CanTouch = false
		p.Material = def.material
		p.Color = def.color
		p.CFrame = b.cf
		p.Size = b.size
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("BaseColor", def.color)
		p.Parent = model
		if n == 1 then
			model.PrimaryPart = p
		end
		-- frame beams on wall panels (not on the small corner post), slightly proud of both faces
		if def.kind == "wall" and b.size.Y > 2 and math.max(b.size.X, b.size.Z) > 2 then
			local long = math.max(b.size.X, b.size.Z)
			local along = if b.size.X > b.size.Z then Vector3.xAxis else Vector3.zAxis
			local depth = BuildingConfig.WALL_THICKNESS + 0.2
			local beam = 0.7
			local function sz(a: number, h: number): Vector3
				return if along == Vector3.xAxis then Vector3.new(a, h, depth) else Vector3.new(depth, h, a)
			end
			local hy = b.size.Y / 2 - beam / 2
			trim(model, b.cf * CFrame.new(0, hy, 0), sz(long, beam), frameColor)
			trim(model, b.cf * CFrame.new(0, -hy, 0), sz(long, beam), frameColor)
			local off = along * (long / 2 - beam / 2)
			trim(model, b.cf + b.cf:VectorToWorldSpace(off), sz(beam, b.size.Y - beam * 2), frameColor)
			trim(model, b.cf - b.cf:VectorToWorldSpace(off), sz(beam, b.size.Y - beam * 2), frameColor)
		end
	end
	CollectionService:AddTag(model, PIECE_TAG)
	model.Parent = buildsFolder
	return model
end

----------------------------------------------------------------------------------------------
-- Placement requests

type Bucket = { tokens: number, last: number, lastPlace: number }
local buckets: { [Player]: Bucket } = {}

local function rateOk(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BuildingConfig.RATE_BURST, last = now, lastPlace = 0 }
		buckets[player] = b
	end
	b.tokens = math.min(BuildingConfig.RATE_BURST, b.tokens + (now - b.last) * BuildingConfig.RATE_PER_SECOND)
	b.last = now
	if b.tokens < 1 or now - b.lastPlace < BuildingConfig.PLACE_COOLDOWN * 0.8 then
		return false
	end
	b.tokens -= 1
	b.lastPlace = now
	return true
end

local function headOf(player: Player): (Vector3?, Humanoid?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if not hum or hum.Health <= 0 or not head or not head:IsA("BasePart") then
		return nil, nil
	end
	return head.Position, hum
end

local function sanitize(raw: any): BuildGrid.Request?
	if type(raw) ~= "table" then
		return nil
	end
	return {
		piece = raw.piece,
		grid = raw.grid,
		i = raw.i,
		j = raw.j,
		k = raw.k,
		rot = raw.rot,
	} :: any
end

function BuildingService.place(player: Player, raw: any): (boolean, string?)
	local req = sanitize(raw)
	if not req then
		return false, "Bad request"
	end
	local origin = headOf(player)
	if not origin then
		return false, "You are not alive"
	end
	if not rateOk(player) then
		return false, "Building too fast"
	end
	local ok, reason, fp, world = BuildGrid.evaluate({
		request = req,
		grids = grids,
		state = registry,
		zones = zones,
		origin = origin,
		maxDistance = BuildingConfig.MAX_PLACE_DISTANCE + BuildingConfig.SERVER_DISTANCE_SLACK,
		resources = Resources.snapshot(player),
		exclude = { buildsFolder },
	})
	if not ok or not fp or not world then
		return false, reason
	end
	local def = BuildingConfig.PIECES[req.piece]
	-- charge exactly once, only after every check passed; nothing below can fail or yield
	if not Resources.trySpend(player, def.cost) then
		return false, "Not enough Wood"
	end
	local model = buildModel(req, fp, world, player)
	registry:add(model)
	return true, nil
end

----------------------------------------------------------------------------------------------
-- Health and destruction

function BuildingService.pieceOf(inst: Instance?): Model?
	local node = inst
	while node and node ~= buildsFolder do
		if node:IsA("Model") and CollectionService:HasTag(node, PIECE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

function BuildingService.destroy(model: Model)
	registry:remove(model)
	model:Destroy()
end

-- Damage a building piece (pass any part of it, or the model). Returns true if it was destroyed.
function BuildingService.damage(target: Instance, amount: number, _attacker: Player?): boolean
	local model = BuildingService.pieceOf(target)
	if not model or not model.Parent or type(amount) ~= "number" or amount <= 0 then
		return false
	end
	local max = model:GetAttribute("MaxHealth") :: number
	local hp = (model:GetAttribute("Health") :: number) - amount
	if hp <= 0 then
		BuildingService.destroy(model)
		return true
	end
	model:SetAttribute("Health", hp)
	local f = 0.55 + 0.45 * (hp / max) -- darken as it weakens
	for _, p in ipairs(model:GetChildren()) do
		local base = p:GetAttribute("BaseColor")
		if p:IsA("BasePart") and typeof(base) == "Color3" then
			p.Color = shade(base, f)
		end
	end
	return false
end

----------------------------------------------------------------------------------------------

local lastHammer: { [Player]: number } = {}

function BuildingService.start()
	if started then
		return
	end
	started = true
	buildsFolder = folder(workspace, "Builds")
	for _, m in ipairs(buildsFolder:GetChildren()) do
		if m:IsA("Model") then
			registry:add(m)
		end
	end
	publishGrids()
	publishZones()

	local remotes = folder(ReplicatedStorage, "Remotes")
	local placeRemote = Instance.new("RemoteFunction")
	placeRemote.Name = "BuildPlace"
	placeRemote.Parent = remotes
	placeRemote.OnServerInvoke = function(player: Player, raw: any)
		local ok, reason = BuildingService.place(player, raw)
		return ok, reason
	end

	local hammer = Instance.new("RemoteEvent")
	hammer.Name = "DevHammer"
	hammer.Parent = remotes
	hammer.OnServerEvent:Connect(function(player: Player, part: any)
		if not RunService:IsStudio() or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
			return
		end
		local now = os.clock()
		if now - (lastHammer[player] or 0) < BuildingConfig.HAMMER_COOLDOWN * 0.8 then
			return
		end
		local origin = headOf(player)
		local model = BuildingService.pieceOf(part)
		if not origin or not model then
			return
		end
		local cf, size = model:GetBoundingBox()
		local l = cf:PointToObjectSpace(origin)
		local h = size / 2
		local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
		if (l - c).Magnitude > BuildingConfig.HAMMER_RANGE + BuildingConfig.SERVER_DISTANCE_SLACK then
			return
		end
		lastHammer[player] = now
		BuildingService.damage(part, BuildingConfig.HAMMER_DAMAGE, player)
	end)

	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
		lastHammer[p] = nil
	end)
end

return BuildingService
