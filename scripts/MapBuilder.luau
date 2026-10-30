--!strict
-- MapBuilder: builds Workspace.Map for FPS Bedwars from ServerStorage.MapAssets.
-- Spec: docs/superpowers/specs/2026-10-25-map-design.md
--
-- Coordinates: map centre is the origin, +Y up. Team islands sit on a ring of radius
-- TEAM_RADIUS at 72-degree steps. Every island's local -Z faces the map centre.
-- Re-running build() destroys and rebuilds Workspace.Map only.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local MapKit = require(script.Parent:WaitForChild("MapKit"))

local MapBuilder = {}

MapBuilder.TEAM_RADIUS = 285
MapBuilder.TEAM_TOP_Y = 200
MapBuilder.CENTER_TOP_Y = 206
MapBuilder.OCEAN_Y = 0
MapBuilder.KILL_Y = 60
MapBuilder.GRID = 12

MapBuilder.TEAMS = {
	{name = "Red", angle = 90, color = Color3.fromRGB(196, 52, 46), brick = "Bright red"},
	{name = "Blue", angle = 18, color = Color3.fromRGB(46, 98, 196), brick = "Bright blue"},
	{name = "Green", angle = -54, color = Color3.fromRGB(60, 150, 64), brick = "Bright green"},
	{name = "Yellow", angle = -126, color = Color3.fromRGB(214, 176, 44), brick = "Bright yellow"},
	{name = "Purple", angle = 162, color = Color3.fromRGB(128, 64, 180), brick = "Royal purple"},
}

local AMBER = Color3.fromRGB(255, 170, 60)
local CYAN = Color3.fromRGB(60, 220, 255)
local NEUTRAL_SIGN = Color3.fromRGB(120, 124, 130)

-- Island-local layout (studs). Build zone: x -60..60, z -42..54 (120 x 96, 6 toward the back).
-- Which team island to build: "GLB" = Sterling's blocky GLB island (imports/team-island-blocky.glb,
-- 2026-10-27), "Rust" = the original generated island with the rusted shed.
MapBuilder.TEAM_STYLE = "GLB"
-- Team shop: "Scrap" = Sterling's scrap dropper + vending machines (imports/scrap-dropper.obj, 2026-10-30),
-- "Kit" = the MapKit wood and metal stall from the 2026-10-28 upgrade.
MapBuilder.SHOP_STYLE = "Scrap"

-- Island-local layout for the GLB island (studs, local -Z faces the centre).
-- Upgrade 2026-10-28 (design board "FPS Bedwars Map Upgrade Plan", Sterling's changes): the 2 x 2 starter
-- building and bed sit dead centre, the team spawns at its bed, the banner moved to the back edge.
-- Cover, ledge and rock spots were ray-checked on the island (flat ground, no props in the way).
MapBuilder.LAYOUT_GLB = {
	buildZone = {center = Vector3.new(0, 0, 0), size = Vector3.new(120, 0, 96)},
	starter = CFrame.new(0, 0, 0),               -- KitStarter, on the 12-stud grid, doorway faces the centre (-Z)
	bed = CFrame.new(0, 0.4, 6.6),               -- inside the starter (relative to it), headboard on the back wall
	spawn = Vector3.new(0, 0.4, -4),             -- the team spawn: inside, in front of the bed
	bedCheckFrom = Vector3.new(0, 3, -15),       -- 3 studs outside the doorway
	shop = CFrame.new(36, 0, -24) * CFrame.Angles(0, math.pi / 2, 0), -- KitShop, counter faces the island middle
	-- Scrap station (Sterling, 2026-10-30): same spot, its 24 x 13 footprint centred where the shop was.
	-- The station pivot is the dropper's floor centre; the vending deck runs toward the island back (+Z)
	-- and the vending machines face the island middle (-X).
	scrapStation = CFrame.new(36, 0, -24) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(4.8, 0, 0),
	banner = CFrame.new(0, 0, 74.8),             -- GLB banner moved from the front (z -37.4) to the back (z +37.4)
	shopSign = {cframe = CFrame.new(32.56, 7.26, -20.38), size = Vector3.new(7.4, 2.0, 0.1), face = Enum.NormalId.Back},
	cover = {
		{kind = "CoverWall", cf = CFrame.new(-31, 0, -47)}, -- flanks the GLB's tall front fence (x -22..2)
		{kind = "CoverWall", cf = CFrame.new(26, 0, -47)},
		{kind = "CoverRock", cf = CFrame.new(60, 0, -24)},
		{kind = "CoverBarricade", cf = CFrame.new(-57.6, 0.96, -6.6) * CFrame.Angles(0, math.rad(90), 0)},
		{kind = "CoverBarricade", cf = CFrame.new(62, 0, 8) * CFrame.Angles(0, math.rad(90), 0)},
		{kind = "CoverCrates", cf = CFrame.new(53.2, 1.09, 42.8)},
	},
	ledges = {
		{cf = CFrame.new(-20, 0.62, 48), size = Vector3.new(20, 1.5, 2.6)},
		{cf = CFrame.new(25, 0, 48), size = Vector3.new(20, 2.2, 2.6)},
		{cf = CFrame.new(-61.6, 0, 6), size = Vector3.new(2.6, 1.2, 12)},
		{cf = CFrame.new(61.6, 0, -17), size = Vector3.new(2.6, 1.8, 12)},
	},
	rimRocks = {
		{kind = "RimRockB", cf = CFrame.new(10, 0, -48.5) * CFrame.Angles(0, math.rad(30), 0)},
		{kind = "RimRockA", cf = CFrame.new(61.2, 0, 23.8) * CFrame.Angles(0, math.rad(-20), 0)},
		{kind = "RimRockB", cf = CFrame.new(-62, 0, -30)},
		{kind = "RimRockA", cf = CFrame.new(0.2, 0, 47.7) * CFrame.Angles(0, math.rad(45), 0)},
	},
}

-- Cover on the centre island, off the Red and Green approach lines (the other approaches already have
-- the GLB's rocks, huts and watchtower).
MapBuilder.CENTRE_COVER = {
	{kind = "CoverWall", cf = CFrame.new(14, 0, -56)},
	{kind = "CoverBarricade", cf = CFrame.new(22.3, 0, 59.5) * CFrame.Angles(0, math.rad(36), 0)},
}

-- Amethyst Beacon (the high-tier dispenser): dropper scale and the light column.
MapBuilder.BEACON = {scale = 1.3, columnHeight = 60}

MapBuilder.LAYOUT_RUST = {
	buildZone = {center = Vector3.new(0, 0, 6), size = Vector3.new(120, 0, 96)},
	bedCheckFrom = Vector3.new(0, 3, 18.5),
	shed = Vector3.new(0, 0, 34),               -- doorway faces -Z (the yard and the centre)
	bedInShed = Vector3.new(0, 1, 7.2),         -- on the slab, headboard against the back wall
	spawn = Vector3.new(0, 0, 2),
	shop = Vector3.new(-36, 0, 6),              -- open front faces +X (toward the spawn)
	banner = Vector3.new(18, 0, 40),
	outcrops = {
		{pos = Vector3.new(-54, 0, 34), yaw = 20},
		{pos = Vector3.new(54, 0, 34), yaw = -35},
		{pos = Vector3.new(-50, 0, -30), yaw = 70},
		{pos = Vector3.new(50, 0, -30), yaw = -10},
	},
}

-- Which centre island to build: "GLB" = Sterling's central-island GLB (v2: imports/bedwars-central-island-v2.glb,
-- 2026-10-28, scaled x1.5, huts with open doorways), "Rust" = the original generated centre.
MapBuilder.CENTRE_STYLE = "GLB"

-- Centre-local layout for the GLB centre (studs, origin = sand top at the map centre).
MapBuilder.LAYOUT_GLB_CENTRE = {
	-- Neutral shop at the centre: off for v2 (Sterling, 2026-10-28). Set to a CFrame to bring one back
	-- (v1 used CFrame.new(0, 0, 49) * CFrame.Angles(0, math.pi, 0)).
	shop = nil :: CFrame?,
	-- GLBShop's pivot is the team-island centre; this moves the stall itself onto the shop point
	shopFromPivot = CFrame.new(-35.56, 0, 25.56),
}

-- Which resource platforms to build: "GLB" = Sterling's dispenser island (imports/bedwars-dispenser-island.obj,
-- 2026-10-28, x1, fake dispensed items removed), "Rust" = the original generated concrete platform.
MapBuilder.PLATFORM_STYLE = "GLB"

-- Number of shops the map should have (MapChecks reads this): one per team, plus the centre's if any.
function MapBuilder.expectedShops(): number
	local centreShop = MapBuilder.CENTRE_STYLE ~= "GLB" or MapBuilder.LAYOUT_GLB_CENTRE.shop ~= nil
	return #MapBuilder.TEAMS + (if centreShop then 1 else 0)
end

-- The active layout (MapChecks reads this).
MapBuilder.LAYOUT = if MapBuilder.TEAM_STYLE == "GLB" then MapBuilder.LAYOUT_GLB else MapBuilder.LAYOUT_RUST

local function deg(a: number): number
	return math.rad(a)
end

-- Position on the ring for a polar angle (degrees, counter-clockwise seen from above, 0 = +X).
function MapBuilder.ringPoint(radius: number, angleDeg: number, y: number): Vector3
	local a = deg(angleDeg)
	return Vector3.new(radius * math.cos(a), y, -radius * math.sin(a))
end

-- CFrame at a ring point whose -Z (LookVector) faces the map centre.
function MapBuilder.facingCentre(p: Vector3): CFrame
	local target = Vector3.new(0, p.Y, 0)
	return CFrame.lookAt(p, target)
end

function MapBuilder.teamCFrame(team: string): CFrame
	for _, t in ipairs(MapBuilder.TEAMS) do
		if t.name == team then
			return MapBuilder.facingCentre(MapBuilder.ringPoint(MapBuilder.TEAM_RADIUS, t.angle, MapBuilder.TEAM_TOP_Y))
		end
	end
	error("unknown team " .. team)
end

local function assets(): Folder
	local f = ServerStorage:FindFirstChild("MapAssets")
	assert(f and f:IsA("Folder"), "ServerStorage.MapAssets missing: run PrepareAssets first")
	return f :: Folder
end

local function place(name: string, cf: CFrame, parent: Instance, newName: string?): Model
	local tmpl = assets():FindFirstChild(name)
	assert(tmpl and tmpl:IsA("Model"), "missing template " .. name)
	local m = (tmpl :: Model):Clone()
	m:PivotTo(cf)
	m.Name = newName or name
	m.Parent = parent
	return m
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function eachPart(m: Instance, suffix: string, fn: (BasePart) -> ())
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and string.sub(d.Name, -#suffix) == suffix then
			fn(d)
		end
	end
end

local function tag(inst: Instance, t: string, attrs: {[string]: any}?)
	CollectionService:AddTag(inst, t)
	if attrs then
		for k, v in pairs(attrs) do
			inst:SetAttribute(k, v)
		end
	end
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

local function signGui(shop: Model, accent: Color3, label: string)
	eachPart(shop, "SignFace_Steel", function(face)
		local g = Instance.new("SurfaceGui")
		g.Name = "ShopSign"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.6
		g.Parent = face
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(30, 31, 33)
		bg.BorderSizePixel = 0
		bg.Parent = g
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0.14, 0)
		bar.Position = UDim2.fromScale(0, 0.86)
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		bar.Parent = bg
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 0.8)
		t.Position = UDim2.fromScale(0, 0.03)
		t.BackgroundTransparency = 1
		t.Text = label
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(236, 232, 222)
		t.Parent = bg
	end)
end

local function buildFloor(parent: Instance, cf: CFrame, zone: {center: Vector3, size: Vector3})
	-- One invisible, perfectly level slab per island: the building system snaps to it.
	local p = Instance.new("Part")
	p.Name = "BuildFloor"
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p.Size = Vector3.new(zone.size.X, 1, zone.size.Z)
	p.CFrame = cf * CFrame.new(zone.center.X, -0.5, zone.center.Z)
	p:SetAttribute("GridSize", MapBuilder.GRID)
	tag(p, "BuildFloor")
	p.Parent = parent
end

local function spawnPad(parent: Instance, cf: CFrame, team: string, color: Color3, brick: string?)
	local s = Instance.new("SpawnLocation")
	s.Name = "SpawnPad"
	s.Anchored = true
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = cf * CFrame.new(MapBuilder.LAYOUT.spawn or Vector3.new(0, 0, 2)) * CFrame.new(0, -0.45, 0)
	s.Material = Enum.Material.Plastic
	s.TopSurface = Enum.SurfaceType.Studs
	s.Color = Color3.fromRGB(226, 222, 214)
	-- the team spawns only at its own bed (Teams are created by setupTeams)
	s.Neutral = brick == nil
	if brick then
		s.TeamColor = BrickColor.new(brick)
	end
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0
	for _, d in ipairs(s:GetChildren()) do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	-- thin team-colour border so each spawn reads at a glance
	local ring = Instance.new("Part")
	ring.Name = "SpawnTrim"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Size = Vector3.new(6.8, 0.92, 6.8)
	ring.CFrame = s.CFrame * CFrame.new(0, -0.03, 0)
	ring.Material = Enum.Material.Metal
	ring.Color = color
	ring.Parent = s
	tag(s, "SpawnPad", {Team = team})
	s.Parent = parent
end

-- Scrap station collision (template space, the station pivot): invisible exact boxes, because the
-- station meshes never collide (PrepareAssets). Shots still hit the visible meshes.
local STATION_COLLIDERS = {
	{"Floor", Vector3.new(0, 0.23, 0), Vector3.new(13.7, 0.46, 11.7)},
	{"Deck", Vector3.new(-11.63, 0.25, 0), Vector3.new(9.95, 0.5, 11.7)},
	{"Pad", Vector3.new(0, 0.865, 0), Vector3.new(6.2, 0.93, 6.2)},
	{"Pillar", Vector3.new(5, 4.3, 4), Vector3.new(1.4, 7.8, 1.4)},
	{"Pillar", Vector3.new(-5, 4.3, 4), Vector3.new(1.4, 7.8, 1.4)},
	{"Pillar", Vector3.new(5, 4.3, -4), Vector3.new(1.4, 7.8, 1.4)},
	{"Pillar", Vector3.new(-5, 4.3, -4), Vector3.new(1.4, 7.8, 1.4)},
	{"PillarBase", Vector3.new(5, 1.28, 4), Vector3.new(2.2, 1.76, 2.2)},
	{"PillarBase", Vector3.new(-5, 1.28, 4), Vector3.new(2.2, 1.76, 2.2)},
	{"PillarBase", Vector3.new(5, 1.28, -4), Vector3.new(2.2, 1.76, 2.2)},
	{"PillarBase", Vector3.new(-5, 1.28, -4), Vector3.new(2.2, 1.76, 2.2)},
	{"Roof", Vector3.new(0, 10.22, 0), Vector3.new(14.4, 4.04, 12.85)},
	{"Railing", Vector3.new(-16.3, 1.04, 0), Vector3.new(0.2, 1.28, 11.3)},
	{"BackWall", Vector3.new(-10.55, 4.45, 5.47), Vector3.new(12.5, 8.1, 0.75)},
	{"VendGuns", Vector3.new(-10.35, 3.75, 4.18), Vector3.new(3.2, 6.7, 2.55)},
	{"VendMaterials", Vector3.new(-13.75, 3.75, 4.18), Vector3.new(3.2, 6.7, 2.55)},
}
MapBuilder.SCRAP_OUTPUT = Vector3.new(0, 1.33, 0) -- top of the glowing pad under the claw (template space)

local function invisiblePart(name: string, cf: CFrame, size: Vector3, collide: boolean, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function vendLabel(vend: Model, text: string)
	eachPart(vend, "_label_" .. string.lower(text), function(face)
		local g = Instance.new("SurfaceGui")
		g.Name = "Label"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.LightInfluence = 0.5
		g.Parent = face
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.92, 0.8)
		t.Position = UDim2.fromScale(0.04, 0.1)
		t.BackgroundTransparency = 1
		t.Text = string.upper(text)
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(34, 36, 40)
		t.Parent = g
	end)
end

-- The team's scrap station: claw-machine scrap dropper plus the Guns and Materials vending machines.
-- Tags: the station is "Shop" (no-build zone, MapChecks) and "ScrapDropper" (with a ScrapOutput
-- attachment on the pad); each machine is "VendingMachine" with attribute Machine = "Guns" | "Materials"
-- and a ProximityPrompt (E). Game scripts (ScrapDropperService, ShopService) find them by tag.
local function buildScrapStation(f: Instance, cf: CFrame, team: {name: string, color: Color3}): Model
	local station = place("ScrapStation", cf, f, "Shop")
	local claw = place("ScrapClaw", cf, station, "Claw")
	claw:SetAttribute("Rest", cf) -- clients animate the claw from here
	local colliders = folder("Colliders", station)
	for _, c in ipairs(STATION_COLLIDERS) do
		invisiblePart(c[1], cf * CFrame.new(c[2]), c[3], true, colliders)
	end
	local out = invisiblePart("ScrapOutput", cf * CFrame.new(MapBuilder.SCRAP_OUTPUT), Vector3.new(1, 0.2, 1), false, station)
	local att = Instance.new("Attachment")
	att.Name = "ScrapOutput"
	att.Parent = out
	-- pad glow
	eachPart(station, "_yellow_glow", function(p)
		if not p:FindFirstChildOfClass("PointLight") then
			addLight(p, Color3.fromRGB(255, 190, 80), 10, 0.6)
		end
	end)
	for _, m in ipairs({{"VendGuns", "Guns", -10.35}, {"VendMaterials", "Materials", -13.75}}) do
		local vend = place(m[1], cf, station, m[1])
		vendLabel(vend, m[2])
		local promptPart = invisiblePart("PromptPart", cf * CFrame.new(m[3], 3.4, 2.7), Vector3.new(2.6, 2, 0.4), false, vend)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "VendPrompt"
		prompt.ActionText = if m[2] == "Materials" then "Buy Materials" else "Browse Guns"
		prompt.ObjectText = m[2] .. " Vending"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Default
		prompt.Parent = promptPart
		tag(vend, "VendingMachine", {Machine = m[2], Team = team.name})
	end
	tag(station, "Shop", {Team = team.name})
	tag(station, "ScrapDropper", {Team = team.name})
	return station
end
MapBuilder.buildScrapStation = buildScrapStation

local function buildGLBTeamIsland(parent: Instance, team: {name: string, angle: number, color: Color3, brick: string})
	local L = MapBuilder.LAYOUT_GLB
	local cf = MapBuilder.teamCFrame(team.name)
	local f = folder(team.name, parent)
	f:SetAttribute("Team", team.name)

	place("GLBIsland", cf, f, "Island")
	place("UXTeam", cf, f, "Underside")

	-- 2 x 2 starter building dead centre, bed inside (the team spawn is in front of it)
	local starterCf = cf * L.starter
	place("KitStarter", starterCf, f, "StarterShed")
	local bed = place("Bed", starterCf * L.bed, f, "Bed")
	eachPart(bed, "_Cloth", function(p)
		p.Color = team.color
	end)
	tag(bed, "Bed", {Team = team.name})

	if MapBuilder.SHOP_STYLE == "Scrap" then
		-- scrap dropper + vending machines where the shop was, machines facing the island middle
		buildScrapStation(f, cf * L.scrapStation, team)
	else
		-- wood and metal shop, counter facing the island middle
		local shop = place("KitShop", cf * L.shop, f, "Shop")
		eachPart(shop, "_Cloth", function(p)
			p.Color = team.color
		end)
		signGui(shop, team.color, "SHOP")
		tag(shop, "Shop", {Team = team.name})
	end

	-- banner on the back edge, away from the map centre
	local banner = place("GLBBanner", cf * L.banner, f, "Banner")
	eachPart(banner, "_Cloth", function(p)
		p.Color = team.color
	end)

	-- FPS cover on the rim, off the main routes
	local cover = folder("Cover", f)
	for _, c in ipairs(L.cover) do
		place(c.kind, cf * c.cf, cover)
	end
	-- terrain detail outside the build zone
	local detail = folder("Terrain", f)
	for _, l in ipairs(L.ledges) do
		MapKit.ledge(detail, cf * l.cf, l.size)
	end
	for _, r in ipairs(L.rimRocks) do
		place(r.kind, cf * r.cf, detail)
	end

	buildFloor(f, cf, L.buildZone)
	spawnPad(f, starterCf, team.name, team.color, team.brick)
end

local function buildTeamIsland(parent: Instance, index: number, team: {name: string, angle: number, color: Color3})
	if MapBuilder.TEAM_STYLE == "GLB" then
		buildGLBTeamIsland(parent, team)
		return
	end
	local L = MapBuilder.LAYOUT_RUST
	local cf = MapBuilder.teamCFrame(team.name)
	local f = folder(team.name, parent)
	f:SetAttribute("Team", team.name)

	place("TeamIsland_" .. index, cf, f, "Island")

	local shed = place("StarterShed", cf * CFrame.new(L.shed), f, "StarterShed")
	local shedLamp: BasePart? = nil
	eachPart(shed, "Lamp_Glow", function(p)
		p.Color = Color3.fromRGB(255, 214, 150)
		shedLamp = p
	end)
	if shedLamp then
		addLight(shedLamp, Color3.fromRGB(255, 200, 140), 12, 0.8)
	end

	local bed = place("Bed", cf * CFrame.new(L.shed + L.bedInShed), f, "Bed")
	eachPart(bed, "_Cloth", function(p)
		p.Color = team.color
	end)
	tag(bed, "Bed", {Team = team.name})

	local shop = place("ShopStall", cf * CFrame.new(L.shop) * CFrame.Angles(0, -math.pi / 2, 0), f, "Shop")
	signGui(shop, team.color, "SHOP")
	eachPart(shop, "Lights_Glow", function(p)
		p.Color = Color3.fromRGB(255, 226, 180)
		addLight(p, Color3.fromRGB(255, 214, 160), 14, 0.7)
	end)
	tag(shop, "Shop", {Team = team.name})

	local banner = place("BannerMast", cf * CFrame.new(L.banner), f, "Banner")
	eachPart(banner, "_Cloth", function(p)
		p.Color = team.color
	end)

	local rocks = folder("Outcrops", f)
	-- same four footprints on every island; which rock shape fills each slot rotates per island
	for i, slot in ipairs(L.outcrops) do
		local n = ((index - 1) * 2 + i - 1) % 10 + 1
		place(string.format("Outcrop_%02d", n), cf * CFrame.new(slot.pos) * CFrame.Angles(0, deg(slot.yaw), 0), rocks)
	end

	buildFloor(f, cf, L.buildZone)
	spawnPad(f, cf, team.name, team.color)
end

-- Crystal, halo and a soft light column above the high-tier dispenser. None of it collides or stops
-- shots (PrepareAssets makes the GD_Beacon meshes non-colliding; the column is CanQuery false).
local function buildBeacon(parent: Instance, disp: Model)
	local box, size = disp:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local m = Instance.new("Model")
	m.Name = "Beacon"
	m.Parent = parent
	local base = CFrame.new(box.Position.X, top + 0.5, box.Position.Z)
	local crystal = place("BeaconCrystal", base, m, "Crystal")
	local halo = place("BeaconHalo", base * CFrame.new(0, 6.7, 0), m, "Halo")
	for _, d in ipairs(crystal:GetDescendants()) do
		if d:IsA("BasePart") then
			CollectionService:AddTag(d, "FPSB_Spin")
			d:SetAttribute("SpinSpeed", 12)
			if string.sub(d.Name, -8) == "_crystal" then
				addLight(d, Color3.fromRGB(190, 120, 255), 22, 1)
			end
		end
	end
	for _, d in ipairs(halo:GetDescendants()) do
		if d:IsA("BasePart") then
			CollectionService:AddTag(d, "FPSB_Spin")
			d:SetAttribute("SpinSpeed", -24)
		end
	end
	local h = MapBuilder.BEACON.columnHeight
	local function column(name: string, width: number, transparency: number, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transparency
		p.Size = Vector3.new(h, width, width)
		p.CFrame = base * CFrame.new(0, 16 + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = m
	end
	column("LightColumn", 3.2, 0.72, Color3.fromRGB(179, 92, 255))
	column("LightCore", 1, 0.35, Color3.fromRGB(231, 200, 255))
end

local function buildGLBCentreShop(f: Instance, shopCf: CFrame)
	local shop = place("GLBShop", shopCf, f, "Shop")
	eachPart(shop, "_Cloth", function(p)
		p.Color = NEUTRAL_SIGN
	end)
	eachPart(shop, "_glow", function(p)
		addLight(p, Color3.fromRGB(255, 214, 160), 12, 0.6)
	end)
	local S = MapBuilder.LAYOUT_GLB.shopSign
	local face = Instance.new("Part")
	face.Name = "Shop_SignFace_Steel"
	face.Anchored = true
	face.CanCollide = false
	face.CanQuery = false
	face.CanTouch = false
	face.CastShadow = false
	face.Material = Enum.Material.SmoothPlastic
	face.Color = Color3.fromRGB(43, 42, 46)
	face.Size = S.size
	face.CFrame = shopCf * S.cframe
	face.Parent = shop
	signGui(shop, NEUTRAL_SIGN, "SHOP")
	local gui = face:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.Face = S.face
	end
	tag(shop, "Shop", {Team = "Neutral"})
end

local function buildGLBCentre(parent: Instance)
	local L = MapBuilder.LAYOUT_GLB_CENTRE
	local cf = CFrame.new(0, MapBuilder.CENTER_TOP_Y, 0)
	local f = folder("Center", parent)

	local island = place("GLBCentre", cf, f, "Island")
	eachPart(island, "_lamp_glow", function(p)
		addLight(p, Color3.fromRGB(255, 211, 140), 10, 0.6)
	end)
	place("UXCentre", cf, f, "Underside")

	-- the GLB's own amethyst gem dropper is the high-tier dispenser, grown into the Amethyst Beacon
	local disp = place("GLBDropper", cf, f, "CenterDispenser")
	local box0, size0 = disp:GetBoundingBox()
	local bottom0 = box0.Position.Y - size0.Y / 2
	disp:ScaleTo(MapBuilder.BEACON.scale)
	local box1, size1 = disp:GetBoundingBox()
	disp:PivotTo(disp:GetPivot() + Vector3.new(0, bottom0 - (box1.Position.Y - size1.Y / 2), 0)) -- re-seat on the plaza
	eachPart(disp, "_amethyst_glow", function(p)
		addLight(p, Color3.fromRGB(179, 92, 255), 14, 0.6) -- restrained, like the old cyan core
	end)
	tag(disp, "ResourceDispenser", {Tier = "High"})
	buildBeacon(f, disp)

	local cover = folder("Cover", f)
	for _, c in ipairs(MapBuilder.CENTRE_COVER) do
		place(c.kind, cf * c.cf, cover)
	end

	-- neutral shop (optional): the team islands' GLB shop with a grey sign
	if L.shop then
		buildGLBCentreShop(f, cf * L.shop * L.shopFromPivot)
	end

	buildFloor(f, cf, {center = Vector3.zero, size = Vector3.new(96, 0, 96)})
end

local function buildCentre(parent: Instance)
	if MapBuilder.CENTRE_STYLE == "GLB" then
		buildGLBCentre(parent)
		return
	end
	local y = MapBuilder.CENTER_TOP_Y
	local f = folder("Center", parent)
	place("CenterIsland", CFrame.new(0, y, 0), f, "Island")

	-- output tray (-Z) faces away from the arch and shop, toward the open side of the centre
	local base = Vector3.new(0, y + 0.35, 0)
	local away = MapBuilder.ringPoint(1, 54 + 180, y + 0.35)
	local disp = place("CenterDispenser", CFrame.lookAt(base, away), f, "CenterDispenser")
	eachPart(disp, "Core_Glow", function(p)
		p.Color = CYAN
		addLight(p, CYAN, 14, 0.6) -- restrained: a stronger light floods the whole pad cyan
	end)
	eachPart(disp, "Lights_Glow", function(p)
		p.Color = Color3.fromRGB(255, 226, 180)
	end)
	tag(disp, "ResourceDispenser", {Tier = "High"})

	-- neutral shop on the in-between angle 54 degrees (between Red and Blue), facing the centre
	local shopPos = MapBuilder.ringPoint(66, 54, y)
	local shop = place("ShopStall", MapBuilder.facingCentre(shopPos), f, "Shop")
	signGui(shop, NEUTRAL_SIGN, "SHOP")
	eachPart(shop, "Lights_Glow", function(p)
		p.Color = Color3.fromRGB(255, 226, 180)
		addLight(p, Color3.fromRGB(255, 214, 160), 14, 0.7)
	end)
	tag(shop, "Shop", {Team = "Neutral"})

	-- low arch on the same angle, spanning across it, behind the dispenser
	place("Arch_Rock", MapBuilder.facingCentre(MapBuilder.ringPoint(36, 54, y)), f, "Arch")

	-- five low shelves of cover, one on each team's approach line
	local rocks = folder("Outcrops", f)
	for i, t in ipairs(MapBuilder.TEAMS) do
		local p = MapBuilder.ringPoint(48, t.angle, y)
		place(string.format("Outcrop_%02d", (i * 2 + 2) % 10 + 1),
			MapBuilder.facingCentre(p) * CFrame.Angles(0, math.pi / 2, 0), rocks)
	end

	buildFloor(f, CFrame.new(0, y, 0), {center = Vector3.zero, size = Vector3.new(96, 0, 96)})
end

local function buildPlatforms(parent: Instance)
	local f = folder("ResourcePlatforms", parent)
	local teams = MapBuilder.TEAMS
	local r = MapBuilder.TEAM_RADIUS * math.cos(deg(36))
	for i, a in ipairs(teams) do
		local b = teams[i % #teams + 1]
		-- half-angle between neighbours (wrap-safe)
		local mid = a.angle - 36
		local cf = MapBuilder.facingCentre(MapBuilder.ringPoint(r, mid, MapBuilder.TEAM_TOP_Y))
		local name = "RP_" .. a.name .. b.name
		if MapBuilder.PLATFORM_STYLE == "GLB" then
			-- Sterling's dispenser island (imports/bedwars-dispenser-island.obj, 2026-10-28)
			local plat = place("GLBPlatform", cf, f, name)
			place("UXPlatform", cf, plat, "Underside")
			eachPart(plat, "_gold_glow", function(p)
				addLight(p, Color3.fromRGB(255, 205, 120), 8, 0.5) -- corner lamps
			end)
			local disp = place("GLBDispenser", cf, plat, "ResourceDispenser")
			eachPart(disp, "_gold_glow", function(p)
				addLight(p, AMBER, 10, 0.6)
			end)
			tag(disp, "ResourceDispenser", {Tier = "Basic"})
			continue
		end
		local plat = place("ResourcePlatform", cf, f, name)
		local disp = place("ResourceDispenser", cf, plat, "ResourceDispenser")
		eachPart(disp, "Core_Glow", function(p)
			p.Color = AMBER
			addLight(p, AMBER, 10, 0.6)
		end)
		tag(disp, "ResourceDispenser", {Tier = "Basic"})
	end
end

local function buildEnvironment(parent: Instance)
	local f = folder("Environment", parent)
	local distant = folder("DistantIslands", f)
	local spots = {
		{a = 20, r = 2900, s = 7.0}, {a = 75, r = 3200, s = 8.5}, {a = 140, r = 2700, s = 6.0},
		{a = 205, r = 3300, s = 9.0}, {a = 260, r = 2800, s = 6.5}, {a = 320, r = 3100, s = 8.0},
	}
	for i, s in ipairs(spots) do
		local m = place(string.format("Distant_%02d", i), MapBuilder.facingCentre(MapBuilder.ringPoint(s.r, s.a, -30)), distant)
		m:ScaleTo(s.s)
	end

	-- far blocky mountain ranges and small islets (non-colliding, fade in the haze)
	local scenery = folder("Scenery", f)
	local mountains = {
		{kind = "DistMountainA", a = 35, r = 2300}, {kind = "DistMountainC", a = 125, r = 2600},
		{kind = "DistMountainB", a = 215, r = 2100}, {kind = "DistMountainD", a = 300, r = 2500},
	}
	for _, mt in ipairs(mountains) do
		place(mt.kind, MapBuilder.facingCentre(MapBuilder.ringPoint(mt.r, mt.a, -5)), scenery)
	end
	local islets = {
		{kind = "DistIsletA", a = 0, r = 760, y = 170, s = 1.2}, {kind = "DistIsletB", a = 48, r = 880, y = 225, s = 1.0},
		{kind = "DistIsletC", a = 100, r = 720, y = 150, s = 1.0}, {kind = "DistIsletA", a = 152, r = 940, y = 240, s = 1.5},
		{kind = "DistIsletB", a = 196, r = 700, y = 185, s = 1.3}, {kind = "DistIsletC", a = 238, r = 900, y = 160, s = 1.2},
		{kind = "DistIsletA", a = 284, r = 820, y = 210, s = 1.0}, {kind = "DistIsletB", a = 326, r = 950, y = 150, s = 1.6},
	}
	for _, it in ipairs(islets) do
		local m = place(it.kind, MapBuilder.facingCentre(MapBuilder.ringPoint(it.r, it.a, it.y)) * CFrame.Angles(0, math.rad(it.a * 3), 0), scenery)
		m:ScaleTo(it.s)
	end

	local kill = Instance.new("Part")
	kill.Name = "KillHeight"
	kill.Anchored = true
	kill.CanCollide = false
	kill.CanQuery = false
	kill.CanTouch = true
	kill.Transparency = 1
	kill.CastShadow = false
	kill.Size = Vector3.new(2048, 1, 2048)
	kill.CFrame = CFrame.new(0, MapBuilder.KILL_Y, 0)
	tag(kill, "KillHeight")
	kill.Parent = f
end

function MapBuilder.buildOcean()
	local terrain = workspace.Terrain
	-- No terrain:Clear(): the fills below overwrite the ocean slab in place, so re-running the
	-- builder never wipes terrain added elsewhere in the place.
	-- 4 x 4 blocks of 2048 cover 8192 x 8192 so no water edge is visible from the arena
	for ix = -2, 1 do
		for iz = -2, 1 do
			terrain:FillBlock(CFrame.new(ix * 2048 + 1024, -12, iz * 2048 + 1024), Vector3.new(2048, 24, 2048), Enum.Material.Water)
		end
		task.wait()
	end
	MapBuilder.applyWater()
end

-- Clear teal-blue water with a little more movement (design board, 2026-10-28).
function MapBuilder.applyWater()
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(32, 92, 120)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.4
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 8
end

-- One Team per island; players are auto-assigned and spawn only at their team's bed.
function MapBuilder.setupTeams()
	local Teams = game:GetService("Teams")
	for _, t in ipairs(MapBuilder.TEAMS) do
		local team = Teams:FindFirstChild(t.name) :: Team?
		if not team then
			local nt = Instance.new("Team")
			nt.Name = t.name
			nt.Parent = Teams
			team = nt
		end
		(team :: Team).TeamColor = BrickColor.new(t.brick)
		;(team :: Team).AutoAssignable = true
	end
end

function MapBuilder.applyLighting()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 72, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true
	for _, n in ipairs({"DepthOfField"}) do
		local e = Lighting:FindFirstChild(n)
		if e then
			e:Destroy()
		end
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	-- haze starts further out and thickens with distance: scenery fades, the arena stays crisp
	atm.Density = 0.28
	atm.Offset = 0.3
	atm.Color = Color3.fromRGB(205, 218, 230)
	atm.Decay = Color3.fromRGB(120, 145, 170)
	atm.Glare = 0.15
	atm.Haze = 1.2
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChild("FPSB_Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "FPSB_Grade"
	;(cc :: ColorCorrectionEffect).Saturation = 0.05
	;(cc :: ColorCorrectionEffect).Contrast = 0.08
	;(cc :: ColorCorrectionEffect).TintColor = Color3.fromRGB(255, 252, 248)
	cc.Parent = Lighting
	local rays = Lighting:FindFirstChild("SunRays") or Instance.new("SunRaysEffect")
	rays.Name = "SunRays"
	;(rays :: SunRaysEffect).Intensity = 0.03
	;(rays :: SunRaysEffect).Spread = 0.5
	rays.Parent = Lighting
end

function MapBuilder.build(opts: {ocean: boolean?}?): Model
	for _, n in ipairs({"Map", "Baseplate", "SpawnLocation"}) do
		local old = workspace:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	MapKit.prepare() -- Part-built templates (starter, shop, cover) are code: refresh them every build
	local map = Instance.new("Model")
	map.Name = "Map"
	local teams = folder("TeamIslands", map)
	for i, t in ipairs(MapBuilder.TEAMS) do
		buildTeamIsland(teams, i, t)
		task.wait()
	end
	buildCentre(map)
	buildPlatforms(map)
	buildEnvironment(map)
	map.Parent = workspace
	if not opts or opts.ocean ~= false then
		MapBuilder.buildOcean()
	end
	MapBuilder.applyWater()
	MapBuilder.applyLighting()
	MapBuilder.setupTeams()
	return map
end

-- Replaces just each team island's shop with the current SHOP_STYLE, leaving the rest of the map alone.
function MapBuilder.rebuildShops(): number
	local islands = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("TeamIslands")
	assert(islands, "Workspace.Map.TeamIslands missing: run build() first")
	local n = 0
	for _, team in ipairs(MapBuilder.TEAMS) do
		local f = islands:FindFirstChild(team.name)
		if f then
			local old = f:FindFirstChild("Shop")
			if old then
				old:Destroy()
			end
			local cf = MapBuilder.teamCFrame(team.name)
			if MapBuilder.SHOP_STYLE == "Scrap" then
				buildScrapStation(f, cf * MapBuilder.LAYOUT_GLB.scrapStation, team)
			else
				local shop = place("KitShop", cf * MapBuilder.LAYOUT_GLB.shop, f, "Shop")
				eachPart(shop, "_Cloth", function(p)
					p.Color = team.color
				end)
				signGui(shop, team.color, "SHOP")
				tag(shop, "Shop", {Team = team.name})
			end
			n += 1
		end
	end
	return n
end

return MapBuilder
