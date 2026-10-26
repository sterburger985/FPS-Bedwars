--!strict
-- PrepareAssets: turns the raw Import 3D results (workspace.FPSB_Islands, workspace.FPSB_Structures)
-- into clean templates in ServerStorage.MapAssets.
--   * one Model per template, pivot at the Blender origin (island top centre / model bottom centre)
--   * materials + MaterialVariants from each part's name suffix
--   * collision, shadows and query flags per role
-- ORIGINS is generated from blender/ (mesh_origins.json): the offset from each MeshPart's
-- bounding-box centre to its template origin, already mapped Blender -> Roblox
-- (Roblox = (-x, z, y)). Regenerate it whenever the Blender generators change.

local ServerStorage = game:GetService("ServerStorage")

local PrepareAssets = {}

local ORIGINS: {[string]: {t: string, o: Vector3}} = {
	["Arch_Rock"] = {t = "Arch_Rock", o = Vector3.new(0.0475, -9.2503, 0.1771)},
	["Banner_Base_Concrete"] = {t = "BannerMast", o = Vector3.new(0.0000, -0.3000, -0.0000)},
	["Banner_Flag_Cloth"] = {t = "BannerMast", o = Vector3.new(0.0000, -19.5500, 0.0012)},
	["Banner_Pole_Steel"] = {t = "BannerMast", o = Vector3.new(0.0000, -12.3000, -0.0000)},
	["Bed_Blanket_Cloth"] = {t = "Bed", o = Vector3.new(0.0000, -1.4000, 0.6000)},
	["Bed_Frame_Wood"] = {t = "Bed", o = Vector3.new(0.0000, -1.6000, -0.0000)},
	["Bed_Pillow_Linen"] = {t = "Bed", o = Vector3.new(0.0000, -1.5500, -2.6000)},
	["CDisp_Banners_Canvas"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -11.5000, 11.2000)},
	["CDisp_Body_Steel"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -9.0000, -0.0000)},
	["CDisp_Core_Glow"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -6.9000, -0.0000)},
	["CDisp_Lights_Glow"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -16.9000, 3.0000)},
	["CDisp_Roof_Rust"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -10.9350, -0.0000)},
	["CDisp_Tube_Glass"] = {t = "CenterDispenser", o = Vector3.new(0.0000, -6.9000, -0.0000)},
	["CI_Pad_Concrete"] = {t = "CenterIsland", o = Vector3.new(0.0000, 0.0250, -0.0000)},
	["CI_Rim_Rock"] = {t = "CenterIsland", o = Vector3.new(5.0524, 14.1183, 4.2534)},
	["CI_Top_Sand"] = {t = "CenterIsland", o = Vector3.new(5.2819, -0.1210, 4.5881)},
	["CI_Under_Rock"] = {t = "CenterIsland", o = Vector3.new(5.4260, 36.7596, 3.6236)},
	["CI_Under_RockDark"] = {t = "CenterIsland", o = Vector3.new(3.7395, 80.5823, 2.4973)},
	["Dispenser_Body_Steel"] = {t = "ResourceDispenser", o = Vector3.new(0.0000, -4.0000, 0.4500)},
	["Dispenser_Core_Glow"] = {t = "ResourceDispenser", o = Vector3.new(0.0000, -4.1500, -0.0000)},
	["Dispenser_Housing_Rust"] = {t = "ResourceDispenser", o = Vector3.new(0.0000, -4.3000, -2.7000)},
	["Dispenser_Tube_Glass"] = {t = "ResourceDispenser", o = Vector3.new(0.0000, -4.1500, -0.0000)},
	["Distant_01_RockDark"] = {t = "Distant_01", o = Vector3.new(0.0000, -7.5041, 0.0000)},
	["Distant_02_RockDark"] = {t = "Distant_02", o = Vector3.new(0.0000, -5.9690, 0.0000)},
	["Distant_03_RockDark"] = {t = "Distant_03", o = Vector3.new(0.0000, -6.4476, 0.0000)},
	["Distant_04_RockDark"] = {t = "Distant_04", o = Vector3.new(0.0000, -6.4812, 0.0000)},
	["Distant_05_RockDark"] = {t = "Distant_05", o = Vector3.new(0.0000, -8.2281, 0.0000)},
	["Distant_06_RockDark"] = {t = "Distant_06", o = Vector3.new(0.0000, -5.3612, 0.0000)},
	["Outcrop_01_Rock"] = {t = "Outcrop_01", o = Vector3.new(0.3299, -1.4605, 0.1575)},
	["Outcrop_02_Rock"] = {t = "Outcrop_02", o = Vector3.new(-0.0186, -2.2173, -0.1030)},
	["Outcrop_03_Rock"] = {t = "Outcrop_03", o = Vector3.new(-0.1675, -1.2861, -0.0659)},
	["Outcrop_04_Rock"] = {t = "Outcrop_04", o = Vector3.new(0.1315, -2.3275, -0.0447)},
	["Outcrop_05_Rock"] = {t = "Outcrop_05", o = Vector3.new(-0.1425, -1.5592, 0.0343)},
	["Outcrop_06_Rock"] = {t = "Outcrop_06", o = Vector3.new(-0.2259, -1.3654, -0.2097)},
	["Outcrop_07_Rock"] = {t = "Outcrop_07", o = Vector3.new(-0.2231, -1.1368, 0.0190)},
	["Outcrop_08_Rock"] = {t = "Outcrop_08", o = Vector3.new(-0.0769, -2.0992, 0.0012)},
	["Outcrop_09_Rock"] = {t = "Outcrop_09", o = Vector3.new(-0.1303, -1.2946, 0.1392)},
	["Outcrop_10_Rock"] = {t = "Outcrop_10", o = Vector3.new(-0.1057, -1.4652, 0.0757)},
	["Platform_Deck_Concrete"] = {t = "ResourcePlatform", o = Vector3.new(0.0000, 1.0000, -0.0000)},
	["Platform_Rim_Rock"] = {t = "ResourcePlatform", o = Vector3.new(-1.0717, 6.1919, -0.0839)},
	["Platform_Rim_Steel"] = {t = "ResourcePlatform", o = Vector3.new(0.0000, 0.8500, -0.0000)},
	["Platform_Under_Rock"] = {t = "ResourcePlatform", o = Vector3.new(-0.0632, 12.7903, 0.1856)},
	["Platform_Under_RockDark"] = {t = "ResourcePlatform", o = Vector3.new(-0.9054, 30.7418, 0.1267)},
	["Shed_Frame_Steel"] = {t = "StarterShed", o = Vector3.new(0.0000, -7.0000, 0.5500)},
	["Shed_Lamp_Glow"] = {t = "StarterShed", o = Vector3.new(0.0000, -11.0500, 12.6000)},
	["Shed_Slab_Concrete"] = {t = "StarterShed", o = Vector3.new(0.0000, -0.5000, -0.0000)},
	["Shed_Walls_Rust"] = {t = "StarterShed", o = Vector3.new(0.0000, -7.3844, 0.0062)},
	["Shop_CounterTop_Steel"] = {t = "ShopStall", o = Vector3.new(0.0000, -3.3000, 2.2000)},
	["Shop_Fittings_Wood"] = {t = "ShopStall", o = Vector3.new(-0.0500, -4.6000, -0.1250)},
	["Shop_Floor_Concrete"] = {t = "ShopStall", o = Vector3.new(0.0000, -0.3000, -0.0000)},
	["Shop_Frame_Steel"] = {t = "ShopStall", o = Vector3.new(0.0000, -8.2000, 0.0500)},
	["Shop_Lights_Glow"] = {t = "ShopStall", o = Vector3.new(0.0000, -10.2000, 1.0000)},
	["Shop_SignFace_Steel"] = {t = "ShopStall", o = Vector3.new(0.0000, -14.7000, 8.1000)},
	["Shop_Walls_Rust"] = {t = "ShopStall", o = Vector3.new(0.0000, -6.4331, 0.3214)},
	["TI1_Rim_Rock"] = {t = "TeamIsland_1", o = Vector3.new(3.4922, 14.2851, -9.8966)},
	["TI1_Top_Sand"] = {t = "TeamIsland_1", o = Vector3.new(4.5661, -0.1874, -10.0465)},
	["TI1_Under_Rock"] = {t = "TeamIsland_1", o = Vector3.new(4.8402, 34.8199, -9.0340)},
	["TI1_Under_RockDark"] = {t = "TeamIsland_1", o = Vector3.new(3.3570, 72.3341, -8.1043)},
	["TI2_Rim_Rock"] = {t = "TeamIsland_2", o = Vector3.new(-0.6909, 14.6462, -9.1364)},
	["TI2_Top_Sand"] = {t = "TeamIsland_2", o = Vector3.new(-1.3808, -0.0409, -9.9416)},
	["TI2_Under_Rock"] = {t = "TeamIsland_2", o = Vector3.new(-0.8909, 37.5440, -9.9244)},
	["TI2_Under_RockDark"] = {t = "TeamIsland_2", o = Vector3.new(-0.6351, 71.7398, -8.5390)},
	["TI3_Rim_Rock"] = {t = "TeamIsland_3", o = Vector3.new(-1.1916, 15.2151, -10.7930)},
	["TI3_Top_Sand"] = {t = "TeamIsland_3", o = Vector3.new(-1.1916, -0.0947, -11.4897)},
	["TI3_Under_Rock"] = {t = "TeamIsland_3", o = Vector3.new(-1.4503, 38.8239, -10.7518)},
	["TI3_Under_RockDark"] = {t = "TeamIsland_3", o = Vector3.new(-1.0233, 72.2312, -8.1225)},
	["TI4_Rim_Rock"] = {t = "TeamIsland_4", o = Vector3.new(-0.4981, 15.1239, -16.3409)},
	["TI4_Top_Sand"] = {t = "TeamIsland_4", o = Vector3.new(-0.4714, -0.0965, -16.8495)},
	["TI4_Under_Rock"] = {t = "TeamIsland_4", o = Vector3.new(-0.1029, 37.6295, -15.8518)},
	["TI4_Under_RockDark"] = {t = "TeamIsland_4", o = Vector3.new(-0.0710, 73.1007, -12.8157)},
	["TI5_Rim_Rock"] = {t = "TeamIsland_5", o = Vector3.new(-3.6435, 16.8178, -10.6783)},
	["TI5_Top_Sand"] = {t = "TeamIsland_5", o = Vector3.new(-4.6614, -0.0592, -10.5140)},
	["TI5_Under_Rock"] = {t = "TeamIsland_5", o = Vector3.new(-3.8571, 41.3081, -9.2675)},
	["TI5_Under_RockDark"] = {t = "TeamIsland_5", o = Vector3.new(-2.5688, 74.6129, -2.6628)},
}

export type MaterialSpec = {material: Enum.Material, variant: string?, color: Color3, transparency: number?, reflectance: number?}

-- Suffix -> look. Variants are named MaterialVariants in MaterialService.
PrepareAssets.MATERIALS = {
	RockDark = {material = Enum.Material.Slate, variant = "FPSB_RockDark", color = Color3.fromRGB(196, 186, 176)},
	Rock = {material = Enum.Material.Rock, variant = "FPSB_CliffRock", color = Color3.fromRGB(236, 226, 212)},
	Sand = {material = Enum.Material.Sand, variant = "FPSB_PaleDirt3", color = Color3.fromRGB(244, 236, 222)},
	-- weathered steel tinted rust-brown: the generated rust variants were painted red panels and the
	-- built-in CorrodedMetal read as blotchy camo on the corrugated meshes (compared in-scene 2026-10-25)
	Rust = {material = Enum.Material.Metal, variant = "FPSB_Steel", color = Color3.fromRGB(212, 146, 100)},
	Steel = {material = Enum.Material.Metal, variant = "FPSB_Steel", color = Color3.fromRGB(190, 186, 180)},
	Concrete = {material = Enum.Material.Concrete, variant = "FPSB_Concrete", color = Color3.fromRGB(226, 224, 218)},
	Wood = {material = Enum.Material.WoodPlanks, variant = "FPSB_Wood1", color = Color3.fromRGB(222, 210, 196)},
	Cloth = {material = Enum.Material.Fabric, color = Color3.fromRGB(150, 150, 150)}, -- recoloured per team by MapBuilder
	Linen = {material = Enum.Material.Fabric, color = Color3.fromRGB(214, 208, 194)},
	Canvas = {material = Enum.Material.Fabric, color = Color3.fromRGB(70, 72, 76)},
	Glow = {material = Enum.Material.Neon, color = Color3.fromRGB(255, 170, 60)},
	Glass = {material = Enum.Material.Glass, color = Color3.fromRGB(180, 205, 210), transparency = 0.55, reflectance = 0.05},
} :: {[string]: MaterialSpec}

-- Suffixes checked longest first so "_RockDark" wins over "_Rock".
local SUFFIX_ORDER = {"RockDark", "Rock", "Sand", "Rust", "Steel", "Concrete", "Wood", "Cloth", "Linen", "Canvas", "Glow", "Glass"}

function PrepareAssets.suffixOf(name: string): string?
	for _, s in ipairs(SUFFIX_ORDER) do
		if string.sub(name, -(#s + 1)) == "_" .. s then
			return s
		end
	end
	return nil
end

local function applyLook(part: MeshPart, suffix: string)
	local spec = PrepareAssets.MATERIALS[suffix]
	part.Material = spec.material
	part.MaterialVariant = spec.variant or ""
	part.Color = spec.color
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
end

local function applyCollision(part: MeshPart, suffix: string)
	local n = part.Name
	part.Anchored = true
	local decorative = string.find(n, "^Distant_") ~= nil
		or string.find(n, "_Under_") ~= nil
		or suffix == "Glow" or suffix == "Cloth" or suffix == "Linen" or suffix == "Canvas"
		or string.find(n, "SignFace") ~= nil or string.find(n, "Lights") ~= nil or string.find(n, "Lamp") ~= nil
	if decorative then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = string.find(n, "^Distant_") == nil
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	else
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = true
		-- islands, rocks, walls and frames need accurate collision; small solid props are fine with hulls
		local precise = suffix == "Rock" or suffix == "Sand" or suffix == "Rust" or suffix == "Steel"
			or suffix == "Concrete" or suffix == "Wood"
		part.CollisionFidelity = if precise then Enum.CollisionFidelity.PreciseConvexDecomposition
			else Enum.CollisionFidelity.Hull
	end
	if string.find(n, "^Distant_") then
		part.CastShadow = false
	end
end

-- Re-applies materials and collision to the existing templates (after changing MATERIALS).
function PrepareAssets.restyle(): number
	local n = 0
	for _, d in ipairs(ServerStorage:WaitForChild("MapAssets"):GetDescendants()) do
		if d:IsA("MeshPart") then
			local suffix = PrepareAssets.suffixOf(d.Name)
			if suffix then
				applyLook(d, suffix)
				applyCollision(d, suffix)
				n += 1
			end
		end
	end
	return n
end

-- Builds ServerStorage.MapAssets from the import containers. Returns a report.
function PrepareAssets.run(sources: {Instance}): {templates: number, parts: number, missing: {string}, unknown: {string}}
	-- Merge: only templates rebuilt from `sources` are replaced; everything else in MapAssets stays.
	local folder = ServerStorage:FindFirstChild("MapAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MapAssets"
		folder.Parent = ServerStorage
	end

	local models: {[string]: Model} = {}
	local seen: {[string]: boolean} = {}
	local unknown = {}
	local count = 0
	for _, src in ipairs(sources) do
		for _, d in ipairs(src:GetDescendants()) do
			if d:IsA("MeshPart") then
				local info = ORIGINS[d.Name]
				local suffix = PrepareAssets.suffixOf(d.Name)
				if not info or not suffix then
					table.insert(unknown, d.Name)
					continue
				end
				seen[d.Name] = true
				local m = models[info.t]
				local originCF = CFrame.new(d.Position + info.o)
				if not m then
					m = Instance.new("Model")
					m.Name = info.t
					models[info.t] = m
					d.Parent = m
					m.PrimaryPart = d
					-- Pivot through PrimaryPart.PivotOffset (a Model with a PrimaryPart ignores WorldPivot).
					d.PivotOffset = d.CFrame:ToObjectSpace(originCF)
				else
					d.Parent = m
				end
				applyLook(d, suffix)
				applyCollision(d, suffix)
				count += 1
			end
		end
	end
	-- parts listed in ORIGINS that these sources did not provide (expected when importing a subset)
	local missing = {}
	for name in pairs(ORIGINS) do
		if not seen[name] then
			table.insert(missing, name)
		end
	end
	for name, m in pairs(models) do
		local existing = (folder :: Folder):FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		m:PivotTo(CFrame.new())
		m.Parent = folder
	end
	local n = 0
	for _ in pairs(models) do
		n += 1
	end
	return {templates = n, parts = count, missing = missing, unknown = unknown}
end

return PrepareAssets
