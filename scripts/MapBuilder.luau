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

local MapBuilder = {}

MapBuilder.TEAM_RADIUS = 285
MapBuilder.TEAM_TOP_Y = 200
MapBuilder.CENTER_TOP_Y = 206
MapBuilder.OCEAN_Y = 0
MapBuilder.KILL_Y = 60
MapBuilder.GRID = 12

MapBuilder.TEAMS = {
	{name = "Red", angle = 90, color = Color3.fromRGB(196, 52, 46)},
	{name = "Blue", angle = 18, color = Color3.fromRGB(46, 98, 196)},
	{name = "Green", angle = -54, color = Color3.fromRGB(60, 150, 64)},
	{name = "Yellow", angle = -126, color = Color3.fromRGB(214, 176, 44)},
	{name = "Purple", angle = 162, color = Color3.fromRGB(128, 64, 180)},
}

local AMBER = Color3.fromRGB(255, 170, 60)
local CYAN = Color3.fromRGB(60, 220, 255)
local NEUTRAL_SIGN = Color3.fromRGB(120, 124, 130)

-- Island-local layout (studs). Build zone: x -60..60, z -42..54 (120 x 96, 6 toward the back).
-- Which team island to build: "GLB" = Sterling's blocky GLB island (imports/team-island-blocky.glb,
-- 2026-10-27), "Rust" = the original generated island with the rusted shed.
MapBuilder.TEAM_STYLE = "GLB"

-- Island-local layout for the GLB island (studs, local -Z faces the centre).
-- GLB (x, z) maps to island-local (1.75x, 1.75z): see blender/fpsb_glb_island.py.
MapBuilder.LAYOUT_GLB = {
	buildZone = {center = Vector3.new(0, 0, 0), size = Vector3.new(120, 0, 96)},
	spawn = Vector3.new(0, 0, 2),
	bed = CFrame.new(-39.9, 0.53, 10.9) * CFrame.Angles(0, math.pi, 0), -- headboard against the wall opposite the door
	bedCheckFrom = Vector3.new(-39.1, 3, 20.8),  -- 3 studs outside the hut doorway (doorway faces +Z)
	shopSign = {cframe = CFrame.new(32.56, 7.26, -20.38), size = Vector3.new(7.4, 2.0, 0.1), face = Enum.NormalId.Back},
}

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

local function spawnPad(parent: Instance, cf: CFrame, team: string, color: Color3)
	local s = Instance.new("SpawnLocation")
	s.Name = "SpawnPad"
	s.Anchored = true
	s.Size = Vector3.new(8, 1, 8)
	s.CFrame = cf * CFrame.new(MapBuilder.LAYOUT.spawn or Vector3.new(0, 0, 2)) * CFrame.new(0, -0.45, 0)
	s.Material = Enum.Material.Concrete
	s.MaterialVariant = "FPSB_Concrete"
	s.Color = Color3.fromRGB(205, 203, 198)
	s.Neutral = true -- team assignment arrives with the team system
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
	ring.Size = Vector3.new(8.6, 0.9, 8.6)
	ring.CFrame = s.CFrame * CFrame.new(0, -0.02, 0)
	ring.Material = Enum.Material.Metal
	ring.Color = color
	ring.Parent = s
	tag(s, "SpawnPad", {Team = team})
	s.Parent = parent
end

local function buildGLBTeamIsland(parent: Instance, team: {name: string, angle: number, color: Color3})
	local L = MapBuilder.LAYOUT_GLB
	local cf = MapBuilder.teamCFrame(team.name)
	local f = folder(team.name, parent)
	f:SetAttribute("Team", team.name)

	place("GLBIsland", cf, f, "Island")

	-- the GLB's own bed hut (door removed) is the starter building
	local hut = place("GLBHut", cf, f, "StarterShed")
	eachPart(hut, "_glow", function(p)
		addLight(p, Color3.fromRGB(255, 200, 140), 10, 0.6)
	end)

	local bed = place("Bed", cf * L.bed, f, "Bed")
	eachPart(bed, "_Cloth", function(p)
		p.Color = team.color
	end)
	tag(bed, "Bed", {Team = team.name})

	local shop = place("GLBShop", cf, f, "Shop")
	eachPart(shop, "_Cloth", function(p)
		p.Color = team.color
	end)
	eachPart(shop, "_glow", function(p)
		addLight(p, Color3.fromRGB(255, 214, 160), 12, 0.6)
	end)
	-- legible label: a thin sign face in front of the GLB's sign board, carrying the SurfaceGui
	local face = Instance.new("Part")
	face.Name = "Shop_SignFace_Steel"
	face.Anchored = true
	face.CanCollide = false
	face.CanQuery = false
	face.CanTouch = false
	face.CastShadow = false
	face.Material = Enum.Material.SmoothPlastic
	face.Color = Color3.fromRGB(43, 42, 46)
	face.Size = L.shopSign.size
	face.CFrame = cf * L.shopSign.cframe
	face.Parent = shop
	signGui(shop, team.color, "SHOP")
	local gui = face:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.Face = L.shopSign.face
	end
	tag(shop, "Shop", {Team = team.name})

	local banner = place("GLBBanner", cf, f, "Banner")
	eachPart(banner, "_Cloth", function(p)
		p.Color = team.color
	end)

	buildFloor(f, cf, L.buildZone)
	spawnPad(f, cf, team.name, team.color)
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

	-- the GLB's own amethyst gem dropper is the high-tier dispenser
	local disp = place("GLBDropper", cf, f, "CenterDispenser")
	eachPart(disp, "_amethyst_glow", function(p)
		addLight(p, Color3.fromRGB(179, 92, 255), 14, 0.6) -- restrained, like the old cyan core
	end)
	tag(disp, "ResourceDispenser", {Tier = "High"})

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
		local plat = place("ResourcePlatform", cf, f, "RP_" .. a.name .. b.name)
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
	terrain.WaterColor = Color3.fromRGB(38, 62, 78)
	terrain.WaterTransparency = 0.25
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 6
end

function MapBuilder.applyLighting()
	Lighting.ClockTime = 13
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 72, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true
	for _, n in ipairs({"DepthOfField", "SunRays"}) do
		local e = Lighting:FindFirstChild(n)
		if e then
			e:Destroy()
		end
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.22
	atm.Offset = 0.12
	atm.Color = Color3.fromRGB(205, 218, 230)
	atm.Decay = Color3.fromRGB(120, 145, 170)
	atm.Glare = 0
	atm.Haze = 0.6
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChild("FPSB_Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "FPSB_Grade"
	;(cc :: ColorCorrectionEffect).Saturation = -0.04
	;(cc :: ColorCorrectionEffect).Contrast = 0.06
	;(cc :: ColorCorrectionEffect).TintColor = Color3.fromRGB(255, 252, 248)
	cc.Parent = Lighting
end

function MapBuilder.build(opts: {ocean: boolean?}?): Model
	for _, n in ipairs({"Map", "Baseplate", "SpawnLocation"}) do
		local old = workspace:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
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
	MapBuilder.applyLighting()
	return map
end

return MapBuilder
