--!strict
-- MapChecks: asserts the layout rules of Workspace.Map (spec §10 / plan Review Focus).
-- run(MapBuilder) -> {pass, failures, stats}

local CollectionService = game:GetService("CollectionService")

local MapChecks = {}

local function tagged(t: string): {Instance}
	local out = {}
	for _, i in ipairs(CollectionService:GetTagged(t)) do
		if i:IsDescendantOf(workspace) then
			table.insert(out, i)
		end
	end
	return out
end

local function params(exclude: {Instance}?): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = {workspace:FindFirstChild("Map") :: Instance}
	if exclude then
		local ex = RaycastParams.new()
		ex.FilterType = Enum.RaycastFilterType.Exclude
		ex.FilterDescendantsInstances = exclude
		return ex
	end
	return p
end

local function pivotOf(i: Instance): CFrame
	if i:IsA("Model") then
		return i:GetPivot()
	end
	return (i :: BasePart).CFrame
end

function MapChecks.run(MapBuilder: any): {pass: boolean, failures: {string}, stats: {[string]: any}}
	local failures: {string} = {}
	local stats: {[string]: any} = {}
	local function fail(msg: string)
		table.insert(failures, msg)
	end
	local map = workspace:FindFirstChild("Map")
	if not map then
		return {pass = false, failures = {"Workspace.Map missing"}, stats = stats}
	end
	local rp = params()

	-- 1. counts
	local expected = {Bed = 5, Shop = 6, ResourceDispenser = 6, SpawnPad = 5, BuildFloor = 6, KillHeight = 1}
	for t, n in pairs(expected) do
		local got = #tagged(t)
		stats["count_" .. t] = got
		if got ~= n then
			fail(string.format("count %s = %d, expected %d", t, got, n))
		end
	end
	local high = 0
	for _, d in ipairs(tagged("ResourceDispenser")) do
		if d:GetAttribute("Tier") == "High" then
			high += 1
		end
	end
	if high ~= 1 then
		fail("expected exactly one High tier dispenser, got " .. high)
	end
	if #(map :: Instance).TeamIslands:GetChildren() ~= 5 then
		fail("expected 5 team island folders")
	end
	if #(map :: Instance).ResourcePlatforms:GetChildren() ~= 5 then
		fail("expected 5 resource platforms")
	end

	-- 2. symmetry: every team object sits at the same island-local offset, islands on the ring
	local refOffsets: {[string]: Vector3} = {}
	for _, t in ipairs(MapBuilder.TEAMS) do
		local folder = (map :: Instance).TeamIslands:FindFirstChild(t.name)
		if not folder then
			fail("missing team folder " .. t.name)
			continue
		end
		local cf = MapBuilder.teamCFrame(t.name)
		local p = cf.Position
		local r = math.sqrt(p.X * p.X + p.Z * p.Z)
		if math.abs(r - MapBuilder.TEAM_RADIUS) > 0.05 then
			fail(string.format("%s radius %.3f", t.name, r))
		end
		local island = folder:FindFirstChild("Island") :: Model
		if (island:GetPivot().Position - p).Magnitude > 0.05 then
			fail(t.name .. " island pivot off its ring point")
		end
		for _, name in ipairs({"StarterShed", "Bed", "Shop", "Banner", "SpawnPad", "BuildFloor"}) do
			local inst = folder:FindFirstChild(name)
			if not inst then
				fail(t.name .. " missing " .. name)
				continue
			end
			local off = cf:PointToObjectSpace(pivotOf(inst).Position)
			if refOffsets[name] then
				if (off - refOffsets[name]).Magnitude > 0.05 then
					fail(string.format("%s %s offset differs by %.3f", t.name, name, (off - refOffsets[name]).Magnitude))
				end
			else
				refOffsets[name] = off
			end
		end
		local floor = folder:FindFirstChild("BuildFloor") :: BasePart
		stats["floorArea_" .. t.name] = floor.Size.X * floor.Size.Z

		-- 3. edge seams + level build zone: rays down every 4 studs across the build zone must hit
		-- at exactly the top height (build floor or flat sand) - no holes, no bumps
		local zone = MapBuilder.LAYOUT.buildZone
		local holes, bumps = 0, 0
		for x = -zone.size.X / 2 + 1, zone.size.X / 2 - 1, 4 do
			for z = -zone.size.Z / 2 + 1, zone.size.Z / 2 - 1, 4 do
				local o = cf:PointToWorldSpace(Vector3.new(x, 30, zone.center.Z + z))
				local hit = workspace:Raycast(o, Vector3.new(0, -80, 0), rp)
				if not hit then
					holes += 1
				elseif hit.Position.Y < MapBuilder.TEAM_TOP_Y - 0.15 then
					bumps += 1
				end
			end
		end
		-- the edge of the build zone must be backed by island, not air: rays just outside the zone
		local edgeAir = 0
		for x = -zone.size.X / 2, zone.size.X / 2, 4 do
			for _, z in ipairs({-zone.size.Z / 2 - 2, zone.size.Z / 2 + 2}) do
				local o = cf:PointToWorldSpace(Vector3.new(x, 5, zone.center.Z + z))
				if not workspace:Raycast(o, Vector3.new(0, -12, 0), rp) then
					edgeAir += 1
				end
			end
		end
		for z = -zone.size.Z / 2, zone.size.Z / 2, 4 do
			for _, x in ipairs({-zone.size.X / 2 - 2, zone.size.X / 2 + 2}) do
				local o = cf:PointToWorldSpace(Vector3.new(x, 5, zone.center.Z + z))
				if not workspace:Raycast(o, Vector3.new(0, -12, 0), rp) then
					edgeAir += 1
				end
			end
		end
		if holes > 0 then
			fail(string.format("%s build zone has %d holes", t.name, holes))
		end
		if bumps > 0 then
			fail(string.format("%s build zone has %d low spots", t.name, bumps))
		end
		if edgeAir > 0 then
			fail(string.format("%s build zone edge has %d air gaps", t.name, edgeAir))
		end

		-- 4. bed access: from 3 studs outside the doorway, a ray to the bed's centre hits the bed first
		local bed = folder:FindFirstChild("Bed") :: Model
		local shed = folder:FindFirstChild("StarterShed") :: Model
		local bedCf, bedSize = bed:GetBoundingBox()
		local door = shed:GetPivot() * CFrame.new(0, 3, -12.5 - 3)
		local hit = workspace:Raycast(door.Position, bedCf.Position - door.Position, params({folder:FindFirstChild("BuildFloor") :: Instance}))
		if not hit or not hit.Instance:IsDescendantOf(bed) then
			fail(string.format("%s bed not reachable through the doorway (hit %s)", t.name, hit and hit.Instance:GetFullName() or "nothing"))
		end
		stats.bedSize = bedSize
	end

	-- 5. grounded: every outcrop, shed, shop, banner, dispenser and platform rests on something
	local function groundCheck(m: Model)
		local ex = params({m})
		local probes: {Vector3} = {}
		if m.Name == "Arch" then
			-- the middle of an arch is its opening: probe under each leg instead (legs at local x = +-13)
			for _, x in ipairs({-13, 13}) do
				table.insert(probes, m:GetPivot():PointToWorldSpace(Vector3.new(x, 0, 0)))
			end
		else
			local cf, size = m:GetBoundingBox()
			table.insert(probes, cf.Position - Vector3.new(0, size.Y / 2, 0))
		end
		for _, base in ipairs(probes) do
			local hit = workspace:Raycast(base + Vector3.new(0, 1.5, 0), Vector3.new(0, -4, 0), ex)
			if not hit then
				fail(m:GetFullName() .. " is floating (nothing within 2.5 studs below)")
				return
			end
		end
	end
	for _, d in ipairs((map :: Instance):GetDescendants()) do
		if d:IsA("Model") and d.Parent and (d.Parent.Name == "Outcrops"
			or d.Name == "StarterShed" or d.Name == "Shop" or d.Name == "Banner"
			or d.Name == "ResourceDispenser" or d.Name == "CenterDispenser" or d.Name == "Arch") then
			groundCheck(d)
		end
	end

	-- 6. dispenser clearance: 8 horizontal rays at chest height from 4.5 studs out find >= 4 studs free
	for _, d in ipairs(tagged("ResourceDispenser")) do
		local cf, size = (d :: Model):GetBoundingBox()
		local blocked = 0
		for k = 0, 7 do
			local a = k * math.pi / 4
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local from = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 3, cf.Position.Z)
				+ dir * (math.max(size.X, size.Z) / 2 + 0.5)
			local hit = workspace:Raycast(from, dir * 4, params({d}))
			if hit then
				blocked += 1
			end
		end
		if blocked > 2 then
			fail(d:GetFullName() .. " boxed in: " .. blocked .. "/8 directions blocked within 4 studs")
		end
	end

	-- 7. heights
	local c = (map :: Instance).Center.Island :: Model
	if math.abs(c:GetPivot().Position.Y - MapBuilder.CENTER_TOP_Y) > 0.05 then
		fail("centre top height wrong")
	end
	for _, p in ipairs((map :: Instance).ResourcePlatforms:GetChildren()) do
		local m = p :: Model
		if math.abs(m:GetPivot().Position.Y - MapBuilder.TEAM_TOP_Y) > 0.05 then
			fail(p.Name .. " deck height wrong")
		end
	end

	return {pass = #failures == 0, failures = failures, stats = stats}
end

return MapChecks
