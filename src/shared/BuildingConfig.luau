--!strict
-- BuildingConfig: every tunable number for first-person building lives here. Both the client
-- preview and the server validation read this one table, so changing a value changes both sides.
--
-- Grid model (all distances in studs, in the grid's local space; see BuildGrid.luau):
--   * a grid is a team island's (or the centre's) BuildFloor; local y = 0 is the island's level
--     ground and x/z cells are CELL studs square, with cell edges on multiples of CELL
--   * level j is the horizontal plane y = j * STOREY; floors and roofs sit on a level, walls fill
--     the storey between level j and j + 1
--   * pieces placed off a structure keep that structure's grid, so a bridge stays on the grid of
--     the island it started from

local BuildingConfig = {}

BuildingConfig.CELL = 12 -- grid size: one floor tile is CELL x CELL
BuildingConfig.STOREY = 12 -- vertical step: wall height and level spacing
BuildingConfig.WALL_THICKNESS = 1
BuildingConfig.SLAB_THICKNESS = 1 -- floors and roofs
BuildingConfig.ROTATION_STEP = 90 -- degrees per R press
BuildingConfig.MAX_LEVEL = 5 -- highest level a slab can sit on (5 storeys above the ground)
BuildingConfig.MAX_LEVEL_BELOW = 0 -- no building below the island ground level

BuildingConfig.MAX_PLACE_DISTANCE = 22 -- from the player's head to the nearest point of the piece
BuildingConfig.SERVER_DISTANCE_SLACK = 6 -- extra allowance on the server for movement and latency
BuildingConfig.AIM_RANGE = 26 -- how far the blueprint ray looks
BuildingConfig.GRID_PICK_RADIUS = 30 -- an existing piece this close to the aim point lends its grid
BuildingConfig.MAP_RADIUS = 430 -- no building further than this from the map centre (x, z)

BuildingConfig.OVERLAP_SHRINK = 0.2 -- each piece box is shrunk this much per side for overlap tests

BuildingConfig.PLACE_COOLDOWN = 0.15 -- seconds between placements (client and server)
BuildingConfig.RATE_BURST = 5 -- server token bucket: burst size
BuildingConfig.RATE_PER_SECOND = 5 -- server token bucket: refill per second

-- No-build zones: the bounding box of each of these, grown by the margin (studs, each side).
BuildingConfig.ZONE_MARGINS = {
	-- The starter building fills exactly 2 x 2 cells but its roof overhangs them by about half a
	-- stud; -1 keeps its zone inside those cells so players can build right up to its walls.
	-- (A wall across the doorway still overlaps the building's front wall and is refused.)
	StarterShed = -1,
	Bed = 2,
	SpawnPad = 4,
	Shop = 3,
	ResourceDispenser = 6,
	CenterDispenser = 10, -- the Amethyst Beacon plaza
}
BuildingConfig.ZONE_EXTRA_HEIGHT = 24 -- zones also reach this far above the object

-- Order of the pieces on the right-click piece wheel (clockwise from the top).
BuildingConfig.PIECE_ORDER = { "Wall", "Floor", "Roof", "Stairs", "CornerWall", "CornerFloor", "CornerRoof" }

export type PieceDef = {
	displayName: string,
	kind: "wall" | "slab" | "stairs",
	corner: boolean,
	roof: boolean,
	cost: { [string]: number },
	health: number,
	material: Enum.Material,
	color: Color3,
}

BuildingConfig.PIECES = {
	Wall = {
		displayName = "Wall",
		kind = "wall",
		corner = false,
		roof = false,
		cost = { Wood = 10 },
		health = 300,
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(150, 112, 76),
	},
	Floor = {
		displayName = "Floor",
		kind = "slab",
		corner = false,
		roof = false,
		cost = { Wood = 10 },
		health = 250,
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(134, 98, 66),
	},
	Roof = {
		displayName = "Roof",
		kind = "slab",
		corner = false,
		roof = true,
		cost = { Wood = 10 },
		health = 250,
		material = Enum.Material.Slate,
		color = Color3.fromRGB(92, 80, 70),
	},
	Stairs = {
		-- a straight flight filling one cell and one storey, climbing toward the side R points it at
		displayName = "Stairs",
		kind = "stairs",
		corner = false,
		roof = false,
		cost = { Wood = 15 },
		health = 300,
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(142, 104, 70),
	},
	CornerWall = {
		displayName = "Corner Wall",
		kind = "wall",
		corner = true,
		roof = false,
		cost = { Wood = 15 },
		health = 400,
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(150, 112, 76),
	},
	CornerFloor = {
		displayName = "Corner Floor",
		kind = "slab",
		corner = true,
		roof = false,
		cost = { Wood = 15 },
		health = 350,
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(134, 98, 66),
	},
	CornerRoof = {
		displayName = "Corner Roof",
		kind = "slab",
		corner = true,
		roof = true,
		cost = { Wood = 15 },
		health = 350,
		material = Enum.Material.Slate,
		color = Color3.fromRGB(92, 80, 70),
	},
} :: { [string]: PieceDef }

-- Resources
BuildingConfig.TEST_WOOD = 100 -- testing stock: each spawn tops Wood up to at least this much

-- Dev hammer (Studio only)
BuildingConfig.HAMMER_DAMAGE = 60
BuildingConfig.HAMMER_COOLDOWN = 0.3
BuildingConfig.HAMMER_RANGE = 14

-- First person
BuildingConfig.FOV = 85
BuildingConfig.MOUSE_SENSITIVITY = 1 -- multiplier on top of the player's Roblox sensitivity

return BuildingConfig
