--!strict
-- BuildingController: the blueprint tool.
--   B           equip / put away the blueprint
--   1-6         wall, floor, roof, corner wall, corner floor, corner roof (only while equipped)
--   R           rotate 90 degrees
--   Q / Escape  put the blueprint away
--   Left click  build (the server checks it again and charges Wood)
--   H           Studio only: dev hammer, left click damages a building piece
-- E is never bound here, so shop and dispenser prompts keep working.
--
-- The preview is a local model under the camera, so nobody else sees it. Its colour comes from
-- BuildGrid.evaluate, the same function the server runs before building.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared:WaitForChild("BuildingConfig"))
local BuildGrid = require(Shared:WaitForChild("BuildGrid"))
local CrosshairController = require(script.Parent:WaitForChild("CrosshairController"))
local BuildUI = require(script.Parent:WaitForChild("BuildUI"))

local BuildingController = {}

local player = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()
local PREVIEW_OK = Color3.fromRGB(80, 230, 110)
local PREVIEW_BAD = Color3.fromRGB(240, 70, 60)
local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local equipped = false
local hammer = false
local selected = 1
local rotOffset = 0
local lastPlace = 0
local lastHammer = 0
local pending = false
local flashUntil = 0
local current: { ok: boolean, reason: string?, request: BuildGrid.Request?, boxes: { BuildGrid.Box }? } = { ok = false }

local registry = BuildGrid.newRegistry()
local grids: { [string]: BuildGrid.Grid } = {}
local zones: { BuildGrid.Zone } = {}
local buildsFolder: Instance
local previewModel: Model
local previewParts: { Part } = {}
local placeRemote: RemoteFunction
local hammerRemote: RemoteEvent
local started = false

----------------------------------------------------------------------------------------------
-- Preview

local function previewPart(n: number): Part
	local p = previewParts[n]
	if not p then
		p = Instance.new("Part")
		p.Name = "Ghost"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.55
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local hl = Instance.new("SelectionBox")
		hl.Adornee = p
		hl.LineThickness = 0.06
		hl.SurfaceTransparency = 1
		hl.Parent = p
		p.Parent = previewModel
		previewParts[n] = p
	end
	return p
end

local function showPreview(boxes: { BuildGrid.Box }?, ok: boolean)
	local n = 0
	if boxes then
		for _, b in ipairs(boxes) do
			n += 1
			local p = previewPart(n)
			p.CFrame = b.cf
			p.Size = b.size
			p.Color = if ok then PREVIEW_OK else PREVIEW_BAD
			local sb = p:FindFirstChildOfClass("SelectionBox") :: SelectionBox
			sb.Color3 = p.Color
			p.Transparency = 0.55
			sb.Visible = true
		end
	end
	for m = n + 1, #previewParts do
		previewParts[m].Transparency = 1
		local sb = previewParts[m]:FindFirstChildOfClass("SelectionBox") :: SelectionBox
		sb.Visible = false
	end
end

----------------------------------------------------------------------------------------------
-- Aim

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = { previewModel }
	if player.Character then
		table.insert(ex, player.Character)
	end
	params.FilterDescendantsInstances = ex
	return params
end

local function pieceOf(inst: Instance?): Model?
	local node = inst
	while node and node ~= buildsFolder and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, "BuildPiece") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function distToZone(grid: BuildGrid.Grid, p: Vector3): number
	local l = grid.frame:PointToObjectSpace(p)
	local dx = math.max(math.abs(l.X) - grid.halfX, 0)
	local dz = math.max(math.abs(l.Z) - grid.halfZ, 0)
	return math.sqrt(dx * dx + dz * dz) + math.abs(l.Y) * 0.5
end

-- Which grid to build on: the piece being looked at, else the nearest piece, else the nearest island.
local function pickGrid(hitInst: Instance?, point: Vector3): BuildGrid.Grid?
	local piece = pieceOf(hitInst)
	if piece then
		local g = grids[piece:GetAttribute("Grid") :: string]
		if g then
			return g
		end
	end
	local best, bestD = nil, BuildingConfig.GRID_PICK_RADIUS
	for model in pairs(registry.pieces) do
		local pp = model.PrimaryPart
		local pos = if pp then pp.Position else nil
		if pos then
			local d = (pos - point).Magnitude
			if d < bestD then
				best, bestD = model, d
			end
		end
	end
	if best then
		local g = grids[best:GetAttribute("Grid") :: string]
		if g then
			return g
		end
	end
	local g, gd = nil, math.huge
	for _, grid in pairs(grids) do
		local d = distToZone(grid, point)
		if d < gd then
			g, gd = grid, d
		end
	end
	return g
end

local function feetHeight(): number?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return nil
	end
	return hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
end

local function headPos(): Vector3?
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else nil
end

local function wood(): number
	local v = player:GetAttribute("Wood")
	return if type(v) == "number" then v else 0
end

local function evaluateAim()
	local pieceId = BuildingConfig.PIECE_ORDER[selected]
	local ray = CrosshairController.aimRay()
	local dir = ray.Direction.Unit
	local result = workspace:Raycast(ray.Origin, dir * BuildingConfig.AIM_RANGE, rayParams())
	local point: Vector3
	if result then
		point = result.Position + result.Normal * 0.05
	else
		-- aiming into the air: use where the ray crosses the height of the player's feet
		local fy = feetHeight()
		if fy and dir.Y < -0.05 then
			local t = (fy + 0.05 - ray.Origin.Y) / dir.Y
			point = ray.Origin + dir * math.clamp(t, 0, BuildingConfig.AIM_RANGE)
		else
			point = ray.Origin + dir * BuildingConfig.AIM_RANGE * 0.6
		end
	end
	local grid = pickGrid(result and result.Instance, point)
	if not grid then
		current = { ok = false, reason = "Nowhere to build" }
		return
	end
	local localPoint = grid.frame:PointToObjectSpace(point)
	local localLook = grid.frame:VectorToObjectSpace(dir)
	local request = BuildGrid.targetFor(grid, localPoint, localLook, pieceId, rotOffset, registry)
	local ok, reason, _, world = BuildGrid.evaluate({
		request = request,
		grids = grids,
		state = registry,
		zones = zones,
		origin = headPos(),
		maxDistance = BuildingConfig.MAX_PLACE_DISTANCE,
		resources = { Wood = wood() },
		exclude = { buildsFolder, previewModel },
	})
	current = { ok = ok, reason = reason, request = request, boxes = world }
end

----------------------------------------------------------------------------------------------
-- Actions

local function refreshUI()
	BuildUI.setOpen(equipped, hammer)
	BuildUI.select(selected)
	BuildUI.setWood(wood())
	CrosshairController.setMode(if equipped then "build" elseif hammer then "hammer" else "default")
	if not equipped then
		CrosshairController.setValid(nil)
		showPreview(nil, false)
	end
end

local function setEquipped(on: boolean)
	equipped = on
	if on then
		hammer = false
	end
	refreshUI()
end

local function setHammer(on: boolean)
	hammer = on and IS_STUDIO
	if hammer then
		equipped = false
	end
	refreshUI()
	if hammer then
		BuildUI.setStatus("Dev hammer: click a building piece", "info")
	end
end

local function flash(text: string, kind: string)
	BuildUI.setStatus(text, kind)
	flashUntil = os.clock() + 1.2
end

local function tryPlace()
	local now = os.clock()
	if pending or now - lastPlace < BuildingConfig.PLACE_COOLDOWN then
		return
	end
	if not current.ok or not current.request then
		flash("Can't build: " .. (current.reason or "invalid"), "bad")
		return
	end
	lastPlace = now
	pending = true
	local request = current.request
	task.spawn(function()
		local okCall, ok, reason = pcall(placeRemote.InvokeServer, placeRemote, request)
		pending = false
		if not okCall then
			flash("Can't build: no answer from server", "bad")
		elseif not ok then
			flash("Can't build: " .. tostring(reason or "refused"), "bad")
		end
	end)
end

local function hammerHit()
	local now = os.clock()
	if now - lastHammer < BuildingConfig.HAMMER_COOLDOWN then
		return
	end
	lastHammer = now
	CrosshairController.kick(5)
	local ray = CrosshairController.aimRay()
	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * BuildingConfig.HAMMER_RANGE, rayParams())
	if result and pieceOf(result.Instance) then
		hammerRemote:FireServer(result.Instance)
	end
end

local function onInput(input: InputObject, processed: boolean)
	local key = input.KeyCode
	-- Escape opens the Roblox menu (processed), but it should still put the blueprint away.
	if key == Enum.KeyCode.Escape then
		if equipped then
			setEquipped(false)
		end
		if hammer then
			setHammer(false)
		end
		return
	end
	if processed then
		return -- typing in chat or clicking a menu
	end
	if key == Enum.KeyCode.B then
		setEquipped(not equipped)
	elseif key == Enum.KeyCode.H and IS_STUDIO then
		setHammer(not hammer)
	elseif equipped then
		local n = NUMBER_KEYS[key]
		if n then
			selected = n
			rotOffset = 0
			refreshUI()
		elseif key == Enum.KeyCode.R then
			rotOffset = (rotOffset + 1) % 4
		elseif key == Enum.KeyCode.Q then
			setEquipped(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryPlace()
		end
	elseif hammer and input.UserInputType == Enum.UserInputType.MouseButton1 then
		hammerHit()
	end
end

----------------------------------------------------------------------------------------------

local function describeLookedAt(): string?
	local ray = CrosshairController.aimRay()
	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * BuildingConfig.AIM_RANGE, rayParams())
	local piece = result and pieceOf(result.Instance)
	if not piece then
		return nil
	end
	local def = BuildingConfig.PIECES[piece:GetAttribute("Piece") :: string]
	return `{def and def.displayName or piece.Name}  {piece:GetAttribute("Health")}/{piece:GetAttribute("MaxHealth")}`
end

local function onFrame()
	if equipped then
		evaluateAim()
		showPreview(current.boxes, current.ok)
		CrosshairController.setValid(current.ok)
		if os.clock() > flashUntil then
			if current.ok then
				local def = BuildingConfig.PIECES[BuildingConfig.PIECE_ORDER[selected]]
				BuildUI.setStatus(`{def.displayName}  ·  Click build  ·  R rotate  ·  Q cancel`, "ok")
			else
				BuildUI.setStatus("Can't build: " .. (current.reason or "invalid"), "bad")
			end
		end
	elseif hammer and os.clock() > flashUntil then
		BuildUI.setStatus(describeLookedAt() or "Dev hammer: click a building piece", "info")
	end
end

local function watchFolder(folder: Instance, onChange: () -> ())
	folder.ChildAdded:Connect(onChange)
	folder.ChildRemoved:Connect(onChange)
	onChange()
end

function BuildingController.start()
	if started then
		return
	end
	started = true

	buildsFolder = workspace:WaitForChild("Builds")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	placeRemote = remotes:WaitForChild("BuildPlace") :: RemoteFunction
	hammerRemote = remotes:WaitForChild("DevHammer") :: RemoteEvent

	local gridFolder = ReplicatedStorage:WaitForChild("BuildGrids")
	watchFolder(gridFolder, function()
		grids = BuildGrid.readGrids(gridFolder)
	end)
	local zoneFolder = ReplicatedStorage:WaitForChild("BuildZones")
	watchFolder(zoneFolder, function()
		zones = BuildGrid.readZones(zoneFolder)
	end)

	-- Piece models replicate with their attributes already set, even when their parts are
	-- streamed out, so the registry always knows every filled slot.
	local function added(m: Instance)
		if m:IsA("Model") then
			registry:add(m)
		end
	end
	buildsFolder.ChildAdded:Connect(added)
	buildsFolder.ChildRemoved:Connect(function(m)
		if m:IsA("Model") then
			registry:remove(m)
		end
	end)
	for _, m in ipairs(buildsFolder:GetChildren()) do
		added(m)
	end

	previewModel = Instance.new("Model")
	previewModel.Name = "BlueprintPreview"
	previewModel.Parent = workspace.CurrentCamera

	BuildUI.create(IS_STUDIO)
	refreshUI()

	player:GetAttributeChangedSignal("Wood"):Connect(function()
		BuildUI.setWood(wood())
	end)

	player.CharacterAdded:Connect(function(char)
		setEquipped(false)
		setHammer(false)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			setEquipped(false)
			setHammer(false)
		end)
	end)

	-- the camera can be replaced; keep the preview under the current one
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		previewModel.Parent = workspace.CurrentCamera
	end)

	UserInputService.InputBegan:Connect(onInput)
	RunService:BindToRenderStep("BuildingController", Enum.RenderPriority.Camera.Value + 2, onFrame)
end

-- For tests and other systems
function BuildingController.getState()
	return { equipped = equipped, hammer = hammer, selected = selected, rot = rotOffset, current = current }
end

return BuildingController
