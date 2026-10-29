--!strict
-- BuildGrid: the one placement calculation shared by the client preview and the server.
--
--  * targetFor()  turns an aim point into a grid slot request (client only, pure maths)
--  * footprint()  turns a request into occupied slot keys and collision boxes
--  * evaluate()   decides if a request is allowed and why not; the client runs it every frame for
--                 the preview colour and the server runs exactly the same function before it builds
--
-- Grid space (per grid, see BuildingConfig): origin at the island's level ground, x/z cells of
-- CELL studs with edges on multiples of CELL, levels every STOREY studs.
--   cell (i, k)        x in [CELL*i, CELL*(i+1)], z in [CELL*k, CELL*(k+1)]
--   slab key  S:i:j:k  floor or roof tile of cell (i, k) on level j (y = STOREY*j .. +SLAB_THICKNESS)
--   wall key  W:i:j:k:d  storey j wall on a cell edge; d = 0 runs along x at z = CELL*k starting at
--                        x = CELL*i, d = 1 runs along z at x = CELL*i starting at z = CELL*k
--   cell edges, numbered for rotation: 0 = -z (south), 1 = +x (east), 2 = +z (north), 3 = -x (west)
--   cell corners: 0 = (-x,-z), 1 = (+x,-z), 2 = (+x,+z), 3 = (-x,+z); corner c joins edges c and c-1
--
-- A request is { piece, grid, i, j, k, rot } with integers only. For a straight wall rot is the
-- edge of cell (i, k); for corner pieces it is the corner; for floors and roofs it only turns the
-- planks. The server never accepts a position, only these slot numbers, so pieces are always on
-- the grid.

local CollectionService = game:GetService("CollectionService")

local BuildingConfig = require(script.Parent:WaitForChild("BuildingConfig"))

local CELL = BuildingConfig.CELL
local STOREY = BuildingConfig.STOREY
local WT = BuildingConfig.WALL_THICKNESS
local ST = BuildingConfig.SLAB_THICKNESS

local BuildGrid = {}

export type Grid = { id: string, frame: CFrame, halfX: number, halfZ: number }
export type Request = { piece: string, grid: string, i: number, j: number, k: number, rot: number }
export type Box = { cf: CFrame, size: Vector3 } -- cf in grid space or world space, as labelled
export type Zone = { cf: CFrame, size: Vector3 }
export type Footprint = {
	slabs: { { i: number, j: number, k: number } },
	walls: { { key: string, i: number, j: number, k: number, d: number } },
	keys: { string },
	boxes: { Box }, -- grid space
}
-- Read access to what is already built, implemented by the Registry below on both sides.
export type State = {
	slabAt: (self: any, grid: string, i: number, j: number, k: number) -> string?,
	wallAt: (self: any, grid: string, key: string) -> string?,
}
export type EvalInput = {
	request: Request,
	grids: { [string]: Grid },
	state: State,
	zones: { Zone },
	origin: Vector3?, -- the builder's head; distance is skipped when nil
	maxDistance: number,
	resources: { [string]: number }?, -- skipped when nil
	exclude: { Instance }, -- left out of the world overlap test (the Builds folder, previews)
}

----------------------------------------------------------------------------------------------
-- Keys and footprints

function BuildGrid.slabKey(i: number, j: number, k: number): string
	return `S:{i}:{j}:{k}`
end

function BuildGrid.wallKey(i: number, j: number, k: number, d: number): string
	return `W:{i}:{j}:{k}:{d}`
end

-- Normalised wall slot of edge e (0-3) of cell (i, k), storey j.
function BuildGrid.edgeSlot(i: number, j: number, k: number, e: number): (number, number, number, number)
	if e == 0 then
		return i, j, k, 0
	elseif e == 1 then
		return i + 1, j, k, 1
	elseif e == 2 then
		return i, j, k + 1, 0
	else
		return i, j, k, 1
	end
end

-- The two cells on either side of a wall slot.
function BuildGrid.wallCells(i: number, k: number, d: number): (number, number, number, number)
	if d == 0 then
		return i, k - 1, i, k
	else
		return i - 1, k, i, k
	end
end

local function wallBox(i: number, j: number, k: number, d: number): Box
	if d == 0 then
		return { cf = CFrame.new(CELL * i + CELL / 2, STOREY * j + STOREY / 2, CELL * k), size = Vector3.new(CELL, STOREY, WT) }
	end
	return { cf = CFrame.new(CELL * i, STOREY * j + STOREY / 2, CELL * k + CELL / 2), size = Vector3.new(WT, STOREY, CELL) }
end

local function slabBox(i: number, j: number, k: number, rot: number): Box
	local cf = CFrame.new(CELL * i + CELL / 2, STOREY * j + ST / 2, CELL * k + CELL / 2) * CFrame.Angles(0, rot * math.pi / 2, 0)
	return { cf = cf, size = Vector3.new(CELL, ST, CELL) }
end

-- Offsets of the cell sharing corner c (dx along x, dz along z).
local function cornerDir(c: number): (number, number)
	local dx = if c == 1 or c == 2 then 1 else -1
	local dz = if c >= 2 then 1 else -1
	return dx, dz
end

function BuildGrid.footprint(req: Request): Footprint?
	local def = BuildingConfig.PIECES[req.piece]
	if not def then
		return nil
	end
	local i, j, k, rot = req.i, req.j, req.k, req.rot % 4
	local fp: Footprint = { slabs = {}, walls = {}, keys = {}, boxes = {} }
	if def.kind == "slab" then
		local cells = { { i, k } }
		if def.corner then
			local dx, dz = cornerDir(rot)
			table.insert(cells, { i + dx, k })
			table.insert(cells, { i, k + dz })
		end
		for _, c in ipairs(cells) do
			table.insert(fp.slabs, { i = c[1], j = j, k = c[2] })
			table.insert(fp.keys, BuildGrid.slabKey(c[1], j, c[2]))
			table.insert(fp.boxes, slabBox(c[1], j, c[2], if def.corner then 0 else rot))
		end
	else
		local edges = if def.corner then { rot, (rot + 3) % 4 } else { rot }
		for _, e in ipairs(edges) do
			local wi, wj, wk, d = BuildGrid.edgeSlot(i, j, k, e)
			local key = BuildGrid.wallKey(wi, wj, wk, d)
			table.insert(fp.walls, { key = key, i = wi, j = wj, k = wk, d = d })
			table.insert(fp.keys, key)
			table.insert(fp.boxes, wallBox(wi, wj, wk, d))
		end
		if def.corner then
			-- corner post closes the gap where the two arms meet
			local px = CELL * i + (if rot == 1 or rot == 2 then CELL else 0)
			local pz = CELL * k + (if rot >= 2 then CELL else 0)
			table.insert(fp.boxes, { cf = CFrame.new(px, STOREY * j + STOREY / 2, pz), size = Vector3.new(WT, STOREY, WT) })
		end
	end
	return fp
end

function BuildGrid.toWorld(grid: Grid, boxes: { Box }): { Box }
	local out = {}
	for _, b in ipairs(boxes) do
		table.insert(out, { cf = grid.frame * b.cf, size = b.size })
	end
	return out
end

----------------------------------------------------------------------------------------------
-- Zone (the island's level build area) tests, in grid space

local EPS = 0.01

local function cellInZone(grid: Grid, i: number, k: number): boolean
	return CELL * i >= -grid.halfX - EPS
		and CELL * (i + 1) <= grid.halfX + EPS
		and CELL * k >= -grid.halfZ - EPS
		and CELL * (k + 1) <= grid.halfZ + EPS
end
BuildGrid.cellInZone = cellInZone

local function wallInZone(grid: Grid, i: number, k: number, d: number): boolean
	local x0, z0 = CELL * i, CELL * k
	local x1 = if d == 0 then x0 + CELL else x0
	local z1 = if d == 1 then z0 + CELL else z0
	return x0 >= -grid.halfX - EPS and x1 <= grid.halfX + EPS and z0 >= -grid.halfZ - EPS and z1 <= grid.halfZ + EPS
end

----------------------------------------------------------------------------------------------
-- Support ("connection") rules

local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function isRoof(piece: string?): boolean
	local def = piece and BuildingConfig.PIECES[piece]
	return def ~= nil and def.roof
end

-- Is there a wall of storey js on any of cell (i, k)'s four edges?
local function wallAround(state: State, gid: string, i: number, js: number, k: number): boolean
	for e = 0, 3 do
		local wi, wj, wk, d = BuildGrid.edgeSlot(i, js, k, e)
		if state:wallAt(gid, BuildGrid.wallKey(wi, wj, wk, d)) then
			return true
		end
	end
	return false
end

local function slabSupported(grid: Grid, state: State, i: number, j: number, k: number, roof: boolean): boolean
	local gid = grid.id
	if not roof and j == 0 then
		-- on the island ground, or straight off its edge (the first tile of a bridge)
		if cellInZone(grid, i, k) then
			return true
		end
		for _, n in ipairs(NEIGHBOURS) do
			if cellInZone(grid, i + n[1], k + n[2]) then
				return true
			end
		end
	end
	if j >= 1 and wallAround(state, gid, i, j - 1, k) then
		return true -- resting on the walls below
	end
	if not roof and wallAround(state, gid, i, j, k) then
		return true -- floor at the foot of a wall
	end
	for _, n in ipairs(NEIGHBOURS) do
		if state:slabAt(gid, i + n[1], j, k + n[2]) then
			return true -- extends a floor or roof beside it (bridges)
		end
	end
	return false
end

local function wallSupported(grid: Grid, state: State, i: number, j: number, k: number, d: number): boolean
	local gid = grid.id
	if j == 0 and wallInZone(grid, i, k, d) then
		return true
	end
	if j >= 1 and state:wallAt(gid, BuildGrid.wallKey(i, j - 1, k, d)) then
		return true -- stacked on the wall below
	end
	local ai, ak, bi, bk = BuildGrid.wallCells(i, k, d)
	for _, c in ipairs({ { ai, ak }, { bi, bk } }) do
		local below = state:slabAt(gid, c[1], j, c[2])
		if below and not isRoof(below) then
			return true -- standing on a floor (roofs cap a building)
		end
		if state:slabAt(gid, c[1], j + 1, c[2]) then
			return true -- hanging under a floor or roof
		end
	end
	return false
end

----------------------------------------------------------------------------------------------
-- Oriented box intersection (separating axis test), for the no-build zones

local function obbOverlap(a: Box, b: Zone): boolean
	local axA = { a.cf.RightVector, a.cf.UpVector, a.cf.LookVector }
	local axB = { b.cf.RightVector, b.cf.UpVector, b.cf.LookVector }
	local hA = { a.size.X / 2, a.size.Y / 2, a.size.Z / 2 }
	local hB = { b.size.X / 2, b.size.Y / 2, b.size.Z / 2 }
	local t = b.cf.Position - a.cf.Position
	local axes = {}
	for n = 1, 3 do
		table.insert(axes, axA[n])
		table.insert(axes, axB[n])
	end
	for p = 1, 3 do
		for q = 1, 3 do
			local c = axA[p]:Cross(axB[q])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, L in ipairs(axes) do
		local rA, rB = 0, 0
		for n = 1, 3 do
			rA += math.abs(L:Dot(axA[n])) * hA[n]
			rB += math.abs(L:Dot(axB[n])) * hB[n]
		end
		if math.abs(t:Dot(L)) >= rA + rB - 0.05 then
			return false
		end
	end
	return true
end
BuildGrid.obbOverlap = obbOverlap

local function closestDistance(box: Box, p: Vector3): number
	local l = box.cf:PointToObjectSpace(p)
	local h = box.size / 2
	local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	return (l - c).Magnitude
end

----------------------------------------------------------------------------------------------
-- World overlap: map geometry and players, using each box's exact collision geometry

local probe: Part? = nil
local function getProbe(): Part
	if not probe then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		probe = p
	end
	return probe :: Part
end

local function characterOf(part: BasePart): Model?
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then
			return m
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function BuildGrid.overlapReason(worldBoxes: { Box }, exclude: { Instance }): string?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = false
	local p = getProbe()
	local s = BuildingConfig.OVERLAP_SHRINK * 2
	for _, b in ipairs(worldBoxes) do
		p.CFrame = b.cf
		p.Size = Vector3.new(math.max(b.size.X - s, 0.05), math.max(b.size.Y - s, 0.05), math.max(b.size.Z - s, 0.05))
		for _, hit in ipairs(workspace:GetPartsInPart(p, params)) do
			if characterOf(hit) then
				return "A player is in the way"
			end
			if hit.CanCollide and not hit:IsA("Terrain") and not CollectionService:HasTag(hit, "BuildFloor") then
				return "Blocked by the map"
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------
-- The shared decision

local function isInt(n: any): boolean
	return type(n) == "number" and n == n and n == math.floor(n) and math.abs(n) < 1e5
end

-- Returns ok, reason (nil when ok), and the footprint plus world boxes when the request is well formed.
function BuildGrid.evaluate(input: EvalInput): (boolean, string?, Footprint?, { Box }?)
	local req = input.request
	if type(req) ~= "table" or type(req.piece) ~= "string" or type(req.grid) ~= "string" then
		return false, "Bad request"
	end
	local def = BuildingConfig.PIECES[req.piece]
	local grid = input.grids[req.grid]
	if not def or not grid then
		return false, "Bad request"
	end
	if not (isInt(req.i) and isInt(req.j) and isInt(req.k) and isInt(req.rot)) or req.rot < 0 or req.rot > 3 then
		return false, "Bad request"
	end
	local fp = BuildGrid.footprint(req)
	if not fp then
		return false, "Bad request"
	end
	local world = BuildGrid.toWorld(grid, fp.boxes)

	-- height and map bounds
	local minLevel = if def.roof then 1 else BuildingConfig.MAX_LEVEL_BELOW
	local maxLevel = if def.kind == "wall" then BuildingConfig.MAX_LEVEL - 1 else BuildingConfig.MAX_LEVEL
	if req.j < minLevel or req.j > maxLevel then
		return false, "Out of the build area", fp, world
	end
	for _, b in ipairs(world) do
		local p = b.cf.Position
		if Vector2.new(p.X, p.Z).Magnitude > BuildingConfig.MAP_RADIUS then
			return false, "Out of the build area", fp, world
		end
	end

	-- reach
	if input.origin then
		local best = math.huge
		for _, b in ipairs(world) do
			best = math.min(best, closestDistance(b, input.origin))
		end
		if best > input.maxDistance then
			return false, "Too far away", fp, world
		end
	end

	-- slots already taken
	for _, s in ipairs(fp.slabs) do
		if input.state:slabAt(grid.id, s.i, s.j, s.k) then
			return false, "Space already built", fp, world
		end
	end
	for _, w in ipairs(fp.walls) do
		if input.state:wallAt(grid.id, w.key) then
			return false, "Space already built", fp, world
		end
	end

	-- connection to the island or to an existing structure (one supported part is enough)
	local supported = false
	for _, s in ipairs(fp.slabs) do
		if slabSupported(grid, input.state, s.i, s.j, s.k, def.roof) then
			supported = true
			break
		end
	end
	for _, w in ipairs(fp.walls) do
		if supported then
			break
		end
		supported = wallSupported(grid, input.state, w.i, w.j, w.k, w.d)
	end
	if not supported then
		return false, if def.roof then "Roofs need walls or a roof beside them" else "Needs a connection", fp, world
	end

	-- spawn, starter building, shop, dispenser and beacon zones
	for _, b in ipairs(world) do
		for _, z in ipairs(input.zones) do
			if obbOverlap(b, z) then
				return false, "Restricted area", fp, world
			end
		end
	end

	-- terrain, props and players
	local blocked = BuildGrid.overlapReason(world, input.exclude)
	if blocked then
		return false, blocked, fp, world
	end

	-- cost
	if input.resources then
		for kind, amount in pairs(def.cost) do
			if (input.resources[kind] or 0) < amount then
				return false, `Not enough {kind}`, fp, world
			end
		end
	end
	return true, nil, fp, world
end

----------------------------------------------------------------------------------------------
-- Aim to request (client). point and look are in grid space.

function BuildGrid.targetFor(grid: Grid, point: Vector3, look: Vector3, piece: string, rotOffset: number, state: State): Request
	local def = BuildingConfig.PIECES[piece]
	local gx, gz = point.X / CELL, point.Z / CELL
	local i, k = math.floor(gx), math.floor(gz)
	local fx, fz = gx - i, gz - k
	local corner = if fx < 0.5 then (if fz < 0.5 then 0 else 3) else (if fz < 0.5 then 1 else 2)
	local req: Request = { piece = piece, grid = grid.id, i = i, j = 0, k = k, rot = 0 }

	if def.kind == "slab" then
		req.j = if def.roof then math.max(1, math.floor(point.Y / STOREY) + 1) else math.max(0, math.floor(point.Y / STOREY + 0.5))
		req.rot = if def.corner then (corner + rotOffset) % 4 else rotOffset % 4
		if state:slabAt(grid.id, i, req.j, k) then
			-- aiming at an existing tile: offer the next tile in the look direction
			if math.abs(look.X) > math.abs(look.Z) then
				req.i += if look.X > 0 then 1 else -1
			else
				req.k += if look.Z > 0 then 1 else -1
			end
		end
	else
		req.j = math.max(0, math.floor(point.Y / STOREY))
		if def.corner then
			req.rot = (corner + rotOffset) % 4
		else
			local dists = { fz, 1 - fx, 1 - fz, fx } -- edges 0-3
			local e, best = 0, math.huge
			for n = 1, 4 do
				if dists[n] < best then
					e, best = n - 1, dists[n]
				end
			end
			req.rot = (e + rotOffset) % 4
			local wi, wj, wk, d = BuildGrid.edgeSlot(i, req.j, k, req.rot)
			if state:wallAt(grid.id, BuildGrid.wallKey(wi, wj, wk, d)) then
				req.j += 1 -- aiming at an existing wall: offer the one above it
			end
		end
	end
	return req
end

----------------------------------------------------------------------------------------------
-- Registry: which slots are filled, built from the piece models (server and client)

local Registry = {}
Registry.__index = Registry

export type Registry = typeof(setmetatable({} :: { slots: { [string]: { [string]: Model } }, pieces: { [Model]: boolean } }, Registry))

function BuildGrid.newRegistry(): Registry
	return setmetatable({ slots = {}, pieces = {} }, Registry)
end

function Registry.add(self: Registry, model: Model)
	local gid = model:GetAttribute("Grid")
	local keys = model:GetAttribute("Keys")
	if type(gid) ~= "string" or type(keys) ~= "string" then
		return
	end
	local g = self.slots[gid]
	if not g then
		g = {}
		self.slots[gid] = g
	end
	for key in string.gmatch(keys, "[^;]+") do
		g[key] = model
	end
	self.pieces[model] = true
end

function Registry.remove(self: Registry, model: Model)
	if not self.pieces[model] then
		return
	end
	self.pieces[model] = nil
	for _, g in pairs(self.slots) do
		for key, m in pairs(g) do
			if m == model then
				g[key] = nil
			end
		end
	end
end

function Registry.slabAt(self: Registry, gid: string, i: number, j: number, k: number): string?
	local g = self.slots[gid]
	local m = g and g[BuildGrid.slabKey(i, j, k)]
	return if m then m:GetAttribute("Piece") :: string else nil
end

function Registry.wallAt(self: Registry, gid: string, key: string): string?
	local g = self.slots[gid]
	local m = g and g[key]
	return if m then m:GetAttribute("Piece") :: string else nil
end

----------------------------------------------------------------------------------------------
-- Published grids and zones (the server writes them, both sides read them)

function BuildGrid.readGrids(folder: Instance): { [string]: Grid }
	local out = {}
	for _, c in ipairs(folder:GetChildren()) do
		local frame = c:GetAttribute("Frame")
		local hx, hz = c:GetAttribute("HalfX"), c:GetAttribute("HalfZ")
		if typeof(frame) == "CFrame" and type(hx) == "number" and type(hz) == "number" then
			out[c.Name] = { id = c.Name, frame = frame, halfX = hx, halfZ = hz }
		end
	end
	return out
end

function BuildGrid.readZones(folder: Instance): { Zone }
	local out = {}
	for _, c in ipairs(folder:GetChildren()) do
		local cf, size = c:GetAttribute("CFrame"), c:GetAttribute("Size")
		if typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
			table.insert(out, { cf = cf, size = size })
		end
	end
	return out
end

return BuildGrid
