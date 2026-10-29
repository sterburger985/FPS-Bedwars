--!strict
-- MapKit: the Part-built pieces of the map (design board "FPS Bedwars Map Upgrade Plan", 2026-10-28).
-- Everything here is plain axis-aligned Parts: exact box collision (doorways can never be closed by a
-- convex hull) and classic Roblox studs on Plastic tops. Templates go to ServerStorage.MapAssets and are
-- cloned by MapBuilder; each template's pivot is its ground centre with the front facing local -Z.
--
--   KitStarter      24 x 24 starter building (2 x 2 build cells): doorway at -Z, bed half roofed
--   KitShop         20 x 12 wood + metal shop stall: counter and sign face -Z
--   CoverWall       12 x 3.5 x 2 low stone wall (shoot over)
--   CoverBarricade  10 x 3.9 x 1 wooden barricade (shoot over)
--   CoverCrates     two 5-stud metal crates + one 4-stud crate on top (full cover)
-- plus MapKit.ledge() for the raised rim ledges and MapKit.studTexture() for studs on meshes.

local ServerStorage = game:GetService("ServerStorage")

local MapKit = {}

-- Classic 1 x 1 stud image (Creator Store decal 7447638611 "Stud Texture"); tiles one stud per stud.
MapKit.STUD_IMAGE = "rbxassetid://7447638591"

local WOOD_DARK = Color3.fromRGB(94, 58, 30)
local PLANKS = Color3.fromRGB(185, 122, 66)
local FLOOR = Color3.fromRGB(217, 168, 119)
local ROOF = Color3.fromRGB(124, 63, 36)
local METAL = Color3.fromRGB(169, 179, 188)
local CRATE_WOOD = Color3.fromRGB(176, 112, 60)
local CRATE_METAL = Color3.fromRGB(107, 123, 140)
local STONE = Color3.fromRGB(154, 165, 177)
local STONE_CAP = Color3.fromRGB(183, 192, 201)
local LAMP = Color3.fromRGB(255, 211, 107)
local LEDGE = Color3.fromRGB(205, 180, 126)

type Opts = {material: Enum.Material?, studs: boolean?, collide: boolean?, query: boolean?, cf: CFrame?}

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, opts: Opts?): Part
	local o: Opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = o.cf or CFrame.new(pos)
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.studs then
		-- classic studs only render on Plastic
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
	end
	p.CanCollide = if o.collide == nil then true else o.collide
	p.CanQuery = if o.query == nil then p.CanCollide else o.query
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function lamp(parent: Instance, name: string, pos: Vector3, range: number)
	local l = part(parent, name, Vector3.new(0.8, 1, 0.8), pos, LAMP, {material = Enum.Material.Neon, collide = false})
	l.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Range = range
	light.Brightness = 0.7
	light.Shadows = false
	light.Parent = l
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = CFrame.new()
	return m
end

-- 24 x 24 starter building. Floor top at y 0.4, walls 1 thick and 9 tall, 6 x 8 doorway at -Z,
-- 4 x 3 windows in both side walls, solid roof over the back 16 studs, open beams over the front 8.
function MapKit.starter(): Model
	local m = model("KitStarter")
	part(m, "Starter_Floor", Vector3.new(24, 0.4, 24), Vector3.new(0, 0.2, 0), FLOOR, {studs = true})
	local wall = {material = Enum.Material.WoodPlanks}
	-- back wall
	part(m, "Starter_WallBack", Vector3.new(24, 9, 1), Vector3.new(0, 4.9, 11.5), PLANKS, wall)
	-- side walls with a window (z -2..2, y 4.4..7.4)
	for _, sx in ipairs({-1, 1}) do
		local x = sx * 11.5
		part(m, "Starter_WallSide", Vector3.new(1, 9, 9), Vector3.new(x, 4.9, -6.5), PLANKS, wall)
		part(m, "Starter_WallSide", Vector3.new(1, 9, 9), Vector3.new(x, 4.9, 6.5), PLANKS, wall)
		part(m, "Starter_WallSide", Vector3.new(1, 4, 4), Vector3.new(x, 2.4, 0), PLANKS, wall)
		part(m, "Starter_WallSide", Vector3.new(1, 2, 4), Vector3.new(x, 8.4, 0), PLANKS, wall)
	end
	-- front wall with the 6 x 8 doorway (x -3..3, y 0.4..8.4)
	part(m, "Starter_WallFront", Vector3.new(9, 9, 1), Vector3.new(-7.5, 4.9, -11.5), PLANKS, wall)
	part(m, "Starter_WallFront", Vector3.new(9, 9, 1), Vector3.new(7.5, 4.9, -11.5), PLANKS, wall)
	part(m, "Starter_Lintel", Vector3.new(6, 1, 1), Vector3.new(0, 8.9, -11.5), PLANKS, wall)
	-- door frame trim (inside the wall ends, does not narrow the doorway)
	for _, sx in ipairs({-1, 1}) do
		part(m, "Starter_DoorTrim", Vector3.new(0.6, 8.6, 1.4), Vector3.new(sx * 3.3, 4.7, -11.5), WOOD_DARK, {material = Enum.Material.Wood})
	end
	-- corner posts
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do
			part(m, "Starter_Post", Vector3.new(1.4, 10.2, 1.4), Vector3.new(sx * 11.5, 5.1, sz * 11.5), WOOD_DARK, {material = Enum.Material.Wood})
		end
	end
	-- partial roof: solid over the bed half (z -4..12.5), beams over the door half
	part(m, "Starter_Roof", Vector3.new(25, 0.8, 16.5), Vector3.new(0, 9.8, 4.25), ROOF, {studs = true})
	for _, z in ipairs({-11.5, -8.5, -5.5}) do
		part(m, "Starter_Beam", Vector3.new(25, 0.8, 0.8), Vector3.new(0, 9.8, z), WOOD_DARK, {material = Enum.Material.Wood})
	end
	-- lantern beside the door
	part(m, "Starter_LanternArm", Vector3.new(0.4, 0.4, 1), Vector3.new(4.6, 7.1, -12.4), WOOD_DARK, {collide = false})
	lamp(m, "Starter_Lantern_glow", Vector3.new(4.6, 6.4, -12.9), 12)
	return m
end

-- 20 x 12 shop stall, customer side at -Z. The sign is Shop_SignFace_Steel (MapBuilder adds the SurfaceGui)
-- and the stripe under it is Shop_Stripe_Cloth (recoloured per team).
function MapKit.shop(): Model
	local m = model("KitShop")
	part(m, "Shop_Deck", Vector3.new(20, 0.4, 12), Vector3.new(0, 0.2, 0), Color3.fromRGB(196, 160, 118), {studs = true})
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do
			part(m, "Shop_Post", Vector3.new(1, 9.6, 1), Vector3.new(sx * 9.5, 5.0, sz * 5.5), WOOD_DARK, {material = Enum.Material.Wood})
		end
	end
	part(m, "Shop_BackWall", Vector3.new(18, 9.4, 0.8), Vector3.new(0, 5.1, 5.6), Color3.fromRGB(154, 98, 51), {material = Enum.Material.WoodPlanks})
	-- shelves with supplies
	for _, sx in ipairs({-1, 1}) do
		part(m, "Shop_Shelf", Vector3.new(6, 0.4, 1.4), Vector3.new(sx * 5.5, 5.2, 4.5), WOOD_DARK, {material = Enum.Material.Wood})
	end
	part(m, "Shop_SupplyCrate", Vector3.new(1.6, 1.6, 1.6), Vector3.new(-6.6, 6.2, 4.5), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	part(m, "Shop_SupplyCrate", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-4.5, 6.1, 4.5), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	part(m, "Shop_SupplyCrate", Vector3.new(1.6, 1.6, 1.6), Vector3.new(4.8, 6.2, 4.5), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	part(m, "Shop_SupplyCrate", Vector3.new(1.4, 1.4, 1.4), Vector3.new(6.8, 6.1, 4.5), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	-- stock behind the counter
	part(m, "Shop_StockCrate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(-6, 1.6, 2.6), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	part(m, "Shop_StockCrate", Vector3.new(1.6, 1.6, 1.6), Vector3.new(-6, 3.6, 2.6), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	part(m, "Shop_StockCrate", Vector3.new(2, 2, 2), Vector3.new(6, 1.4, 2.8), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	-- counter: planks body, metal top (waist height 3.9)
	part(m, "Shop_Counter", Vector3.new(16, 3.1, 2), Vector3.new(0, 1.95, -3), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	part(m, "Shop_CounterTop", Vector3.new(16.6, 0.4, 2.6), Vector3.new(0, 3.7, -3), METAL, {material = Enum.Material.DiamondPlate})
	-- corrugated metal roof, high at the front
	part(m, "Shop_Roof", Vector3.new(22, 0.5, 14), Vector3.zero, METAL,
		{material = Enum.Material.Metal, cf = CFrame.new(0, 10.1, 0) * CFrame.Angles(math.rad(4), 0, 0)})
	-- sign + team stripe (no collision: they hang above head height)
	part(m, "Shop_SignFace_Steel", Vector3.new(12, 2.6, 0.4), Vector3.new(0, 8.3, -6.4), Color3.fromRGB(43, 42, 46), {collide = false})
	part(m, "Shop_Stripe_Cloth", Vector3.new(12, 0.5, 0.45), Vector3.new(0, 6.85, -6.4), Color3.fromRGB(196, 52, 46), {material = Enum.Material.Plastic, collide = false})
	lamp(m, "Shop_Lamp_glow", Vector3.new(-8.6, 8.8, -5.3), 12)
	lamp(m, "Shop_Lamp_glow", Vector3.new(8.6, 8.8, -5.3), 12)
	-- supply crates outside the stall
	part(m, "Shop_OutsideCrate", Vector3.new(3, 3, 3), Vector3.new(11.8, 1.5, -3.5), CRATE_WOOD, {material = Enum.Material.WoodPlanks, studs = false})
	part(m, "Shop_OutsideCrate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(-11.7, 1.2, -4), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	return m
end

function MapKit.coverWall(): Model
	local m = model("CoverWall")
	part(m, "Cover_Wall", Vector3.new(12, 3, 2), Vector3.new(0, 1.5, 0), STONE, {material = Enum.Material.Plastic})
	part(m, "Cover_WallCap", Vector3.new(12.4, 0.5, 2.4), Vector3.new(0, 3.25, 0), STONE_CAP, {studs = true})
	return m
end

function MapKit.coverBarricade(): Model
	local m = model("CoverBarricade")
	for _, sx in ipairs({-1, 1}) do
		part(m, "Cover_BarricadePost", Vector3.new(1, 4.4, 1), Vector3.new(sx * 4.2, 2.2, 0), WOOD_DARK, {studs = true})
	end
	for _, y in ipairs({0.8, 2.1, 3.4}) do
		part(m, "Cover_BarricadePlank", Vector3.new(10, 1, 0.6), Vector3.new(0, y, 0), CRATE_WOOD, {material = Enum.Material.WoodPlanks})
	end
	return m
end

function MapKit.coverCrates(): Model
	local m = model("CoverCrates")
	part(m, "Cover_Crate", Vector3.new(5, 5, 5), Vector3.new(-2.6, 2.5, 0), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	part(m, "Cover_Crate", Vector3.new(5, 5, 5), Vector3.new(2.6, 2.5, 0.3), Color3.fromRGB(122, 138, 154), {material = Enum.Material.DiamondPlate})
	part(m, "Cover_Crate", Vector3.new(4, 4, 4), Vector3.new(-0.5, 7, 0), CRATE_METAL, {material = Enum.Material.DiamondPlate})
	return m
end

-- A raised rim ledge: a studded slab standing on the island top (pivot = bottom centre).
function MapKit.ledge(parent: Instance, cf: CFrame, size: Vector3): Part
	return part(parent, "RimLedge", size, Vector3.zero, LEDGE, {studs = true, cf = cf * CFrame.new(0, size.Y / 2, 0)})
end

-- Classic studs on a MeshPart's upward faces.
function MapKit.studTexture(p: BasePart)
	if p:FindFirstChild("Studs") then
		return
	end
	local t = Instance.new("Texture")
	t.Name = "Studs"
	t.Texture = MapKit.STUD_IMAGE
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU = 1
	t.StudsPerTileV = 1
	t.Parent = p
end

-- (Re)builds the kit templates in ServerStorage.MapAssets. Returns the number of templates.
function MapKit.prepare(): number
	local folder = ServerStorage:FindFirstChild("MapAssets")
	assert(folder, "ServerStorage.MapAssets missing")
	local made = {MapKit.starter(), MapKit.shop(), MapKit.coverWall(), MapKit.coverBarricade(), MapKit.coverCrates()}
	for _, m in ipairs(made) do
		local old = folder:FindFirstChild(m.Name)
		if old then
			old:Destroy()
		end
		m.Parent = folder
	end
	return #made
end

return MapKit
