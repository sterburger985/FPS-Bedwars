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
	-- GLB team island (imports/team-island-blocky.glb via blender/fpsb_glb_island.py, glb_origins.json)
	["GI_Banner_Cloth"] = {t = "GLBBanner", o = Vector3.new(6.3000, -15.5750, 39.7250)},
	["GI_Banner_dark"] = {t = "GLBBanner", o = Vector3.new(6.3000, -7.0000, 36.4000)},
	["GI_Banner_glow"] = {t = "GLBBanner", o = Vector3.new(6.3000, -23.9750, 39.9000)},
	["GI_Banner_metal"] = {t = "GLBBanner", o = Vector3.new(6.3000, -23.1000, 39.9000)},
	["GI_Banner_white"] = {t = "GLBBanner", o = Vector3.new(6.3000, -16.1407, 39.5587)},
	["GI_Banner_wood_dark"] = {t = "GLBBanner", o = Vector3.new(6.3000, -11.3750, 39.9000)},
	["GI_Hut_glow"] = {t = "GLBHut", o = Vector3.new(35.7493, -5.8625, -17.8133)},
	["GI_Hut_metal"] = {t = "GLBHut", o = Vector3.new(39.9000, -4.3750, -12.6000)},
	["GI_Hut_rust"] = {t = "GLBHut", o = Vector3.new(39.9000, -4.5063, -12.6000)},
	["GI_Hut_wood"] = {t = "GLBHut", o = Vector3.new(40.1615, -3.7625, -14.1217)},
	["GI_Hut_wood_dark"] = {t = "GLBHut", o = Vector3.new(39.9000, -3.7625, -12.6000)},
	["GI_Island_dark"] = {t = "GLBIsland", o = Vector3.new(45.1500, -15.0500, 30.4500)},
	["GI_Island_glow"] = {t = "GLBIsland", o = Vector3.new(44.7125, -15.0413, 29.9250)},
	["GI_Island_grass"] = {t = "GLBIsland", o = Vector3.new(0.7840, 19.0631, -0.8556)},
	["GI_Island_metal"] = {t = "GLBIsland", o = Vector3.new(25.5500, -9.4500, 37.6469)},
	["GI_Island_pine"] = {t = "GLBIsland", o = Vector3.new(-0.1925, -8.1200, 1.4350)},
	["GI_Island_rock"] = {t = "GLBIsland", o = Vector3.new(0.7841, 27.6395, -0.8560)},
	["GI_Island_rock_dark"] = {t = "GLBIsland", o = Vector3.new(1.6341, 30.5544, -1.3461)},
	["GI_Island_rust"] = {t = "GLBIsland", o = Vector3.new(24.5000, -8.6625, 38.4344)},
	["GI_Island_sand"] = {t = "GLBIsland", o = Vector3.new(0.0000, 0.3500, -0.0000)},
	["GI_Island_wood"] = {t = "GLBIsland", o = Vector3.new(-2.5281, -6.3875, 7.6249)},
	["GI_Island_wood_dark"] = {t = "GLBIsland", o = Vector3.new(-0.0263, -7.4375, 1.3825)},
	["GI_Shop_Cloth"] = {t = "GLBShop", o = Vector3.new(-35.2334, -4.9875, 32.4287)},
	["GI_Shop_dark"] = {t = "GLBShop", o = Vector3.new(-32.5590, -7.2625, 20.9683)},
	["GI_Shop_glow"] = {t = "GLBShop", o = Vector3.new(-37.0916, -7.2625, 20.2907)},
	["GI_Shop_metal"] = {t = "GLBShop", o = Vector3.new(-35.6161, -6.0445, 26.2534)},
	["GI_Shop_rust"] = {t = "GLBShop", o = Vector3.new(-35.6161, -7.8064, 26.2534)},
	["GI_Shop_wood"] = {t = "GLBShop", o = Vector3.new(-36.1065, -5.3375, 25.1562)},
	["GI_Shop_wood_dark"] = {t = "GLBShop", o = Vector3.new(-35.6255, -4.9875, 25.5556)},
	-- GLB centre island v2 (imports/bedwars-central-island-v2.glb, x1.5, via blender/fpsb_glb_centre.py, glbc2_origins.json)
	["GC_Centre_banner"] = {t = "GLBCentre", o = Vector3.new(51.0000, -22.5000, -35.1000)},
	["GC_Centre_dirt_path"] = {t = "GLBCentre", o = Vector3.new(3.0000, 0.4500, 3.0000)},
	["GC_Centre_gold_trim"] = {t = "GLBCentre", o = Vector3.new(19.9553, -13.0853, -11.4150)},
	["GC_Centre_grass"] = {t = "GLBCentre", o = Vector3.new(3.0000, -5.4000, 3.0000)},
	["GC_Centre_lamp_glow"] = {t = "GLBCentre", o = Vector3.new(16.8000, -21.5550, -10.8000)},
	["GC_Centre_leaves"] = {t = "GLBCentre", o = Vector3.new(-1.5486, -9.6009, -1.7023)},
	["GC_Centre_metal"] = {t = "GLBCentre", o = Vector3.new(6.7500, -2.4000, -5.4000)},
	["GC_Centre_rock"] = {t = "GLBCentre", o = Vector3.new(-2.8948, 38.2199, -0.0538)},
	["GC_Centre_rock_dark"] = {t = "GLBCentre", o = Vector3.new(-2.8990, 39.6945, 0.3249)},
	["GC_Centre_roof"] = {t = "GLBCentre", o = Vector3.new(51.0000, -37.5000, -39.0000)},
	["GC_Centre_sand"] = {t = "GLBCentre", o = Vector3.new(3.0000, 0.4500, 3.0000)},
	["GC_Centre_stone_tile"] = {t = "GLBCentre", o = Vector3.new(7.8000, -5.8500, -15.3000)},
	["GC_Centre_wood"] = {t = "GLBCentre", o = Vector3.new(5.6794, -15.9000, 3.3721)},
	["GC_Centre_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-1.5392, -17.5500, -0.2363)},
	["GC_Dropper_amethyst_glow"] = {t = "GLBDropper", o = Vector3.new(0.0000, -11.0250, 0.0000)},
	["GC_Dropper_gold_trim"] = {t = "GLBDropper", o = Vector3.new(0.0000, -9.6750, 0.0000)},
	["GC_Dropper_metal"] = {t = "GLBDropper", o = Vector3.new(0.0000, -11.5500, 0.0000)},
	["GC_Dropper_rock"] = {t = "GLBDropper", o = Vector3.new(0.0000, -10.0815, 0.0000)},
	["GC_Dropper_stone_tile"] = {t = "GLBDropper", o = Vector3.new(0.0000, -7.2000, 0.0000)},
	["GC_HutEast01_lamp_glow"] = {t = "GLBCentre", o = Vector3.new(40.6917, -10.5000, -0.7393)},
	["GC_HutEast02_roof"] = {t = "GLBCentre", o = Vector3.new(44.0736, -13.8086, -1.7854)},
	["GC_HutEast03_roof"] = {t = "GLBCentre", o = Vector3.new(51.9264, -13.8086, -4.2146)},
	["GC_HutEast04_wood"] = {t = "GLBCentre", o = Vector3.new(41.1932, -6.3000, -0.8944)},
	["GC_HutEast05_wood"] = {t = "GLBCentre", o = Vector3.new(54.8068, -6.3000, -5.1056)},
	["GC_HutEast06_wood"] = {t = "GLBCentre", o = Vector3.new(50.7705, -6.3000, 5.9563)},
	["GC_HutEast07_wood"] = {t = "GLBCentre", o = Vector3.new(45.2295, -6.3000, -11.9563)},
	["GC_HutEast08_wood"] = {t = "GLBCentre", o = Vector3.new(50.7705, -11.9122, 5.9563)},
	["GC_HutEast09_wood"] = {t = "GLBCentre", o = Vector3.new(45.2295, -11.9122, -11.9563)},
	["GC_HutEast10_wood"] = {t = "GLBCentre", o = Vector3.new(50.7705, -12.9365, 5.9563)},
	["GC_HutEast11_wood"] = {t = "GLBCentre", o = Vector3.new(45.2295, -12.9365, -11.9563)},
	["GC_HutEast12_wood"] = {t = "GLBCentre", o = Vector3.new(50.7705, -13.9608, 5.9563)},
	["GC_HutEast13_wood"] = {t = "GLBCentre", o = Vector3.new(45.2295, -13.9608, -11.9563)},
	["GC_HutEast14_wood"] = {t = "GLBCentre", o = Vector3.new(50.7705, -14.9851, 5.9563)},
	["GC_HutEast15_wood"] = {t = "GLBCentre", o = Vector3.new(45.2295, -14.9851, -11.9563)},
	["GC_HutEast16_wood_dark"] = {t = "GLBCentre", o = Vector3.new(48.0000, -0.6000, -3.0000)},
	["GC_HutEast17_wood_dark"] = {t = "GLBCentre", o = Vector3.new(43.7163, -6.3000, 8.5309)},
	["GC_HutEast18_wood_dark"] = {t = "GLBCentre", o = Vector3.new(37.9537, -6.3000, -10.0981)},
	["GC_HutEast19_wood_dark"] = {t = "GLBCentre", o = Vector3.new(58.0463, -6.3000, 4.0981)},
	["GC_HutEast20_wood_dark"] = {t = "GLBCentre", o = Vector3.new(52.2837, -6.3000, -14.5309)},
	["GC_HutEast21_wood_dark"] = {t = "GLBCentre", o = Vector3.new(40.8350, -9.9000, -0.7836)},
	["GC_HutPlateau01_lamp_glow"] = {t = "GLBCentre", o = Vector3.new(-51.8860, -21.6000, -34.0807)},
	["GC_HutPlateau02_roof"] = {t = "GLBCentre", o = Vector3.new(-52.1646, -24.4989, -36.8568)},
	["GC_HutPlateau03_roof"] = {t = "GLBCentre", o = Vector3.new(-52.8354, -24.4989, -43.5432)},
	["GC_HutPlateau04_wood"] = {t = "GLBCentre", o = Vector3.new(-51.9384, -17.7000, -34.6031)},
	["GC_HutPlateau05_wood"] = {t = "GLBCentre", o = Vector3.new(-53.0616, -17.7000, -45.7969)},
	["GC_HutPlateau06_wood"] = {t = "GLBCentre", o = Vector3.new(-45.4106, -17.7000, -40.9113)},
	["GC_HutPlateau07_wood"] = {t = "GLBCentre", o = Vector3.new(-59.5894, -17.7000, -39.4887)},
	["GC_HutPlateau08_wood"] = {t = "GLBCentre", o = Vector3.new(-45.4106, -22.9097, -40.9113)},
	["GC_HutPlateau09_wood"] = {t = "GLBCentre", o = Vector3.new(-59.5894, -22.9097, -39.4887)},
	["GC_HutPlateau10_wood"] = {t = "GLBCentre", o = Vector3.new(-45.4106, -23.7292, -40.9113)},
	["GC_HutPlateau11_wood"] = {t = "GLBCentre", o = Vector3.new(-59.5894, -23.7292, -39.4887)},
	["GC_HutPlateau12_wood"] = {t = "GLBCentre", o = Vector3.new(-45.4106, -24.5486, -40.9113)},
	["GC_HutPlateau13_wood"] = {t = "GLBCentre", o = Vector3.new(-59.5894, -24.5486, -39.4887)},
	["GC_HutPlateau14_wood"] = {t = "GLBCentre", o = Vector3.new(-45.4106, -25.3681, -40.9113)},
	["GC_HutPlateau15_wood"] = {t = "GLBCentre", o = Vector3.new(-59.5894, -25.3681, -39.4887)},
	["GC_HutPlateau16_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-52.5000, -12.3000, -40.2000)},
	["GC_HutPlateau17_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-44.4385, -17.7000, -34.9787)},
	["GC_HutPlateau18_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-59.3635, -17.7000, -33.4812)},
	["GC_HutPlateau19_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-45.6365, -17.7000, -46.9188)},
	["GC_HutPlateau20_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-60.5615, -17.7000, -45.4213)},
	["GC_HutPlateau21_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-51.9010, -21.6000, -34.2300)},
	["GC_HutWest01_lamp_glow"] = {t = "GLBCentre", o = Vector3.new(-49.5878, -10.5000, 4.8926)},
	["GC_HutWest02_roof"] = {t = "GLBCentre", o = Vector3.new(-53.0178, -13.8086, 4.0168)},
	["GC_HutWest03_roof"] = {t = "GLBCentre", o = Vector3.new(-60.9822, -13.8086, 1.9832)},
	["GC_HutWest04_wood"] = {t = "GLBCentre", o = Vector3.new(-50.0965, -6.3000, 4.7628)},
	["GC_HutWest05_wood"] = {t = "GLBCentre", o = Vector3.new(-63.9035, -6.3000, 1.2372)},
	["GC_HutWest06_wood"] = {t = "GLBCentre", o = Vector3.new(-54.8661, -6.3000, -5.3569)},
	["GC_HutWest07_wood"] = {t = "GLBCentre", o = Vector3.new(-59.1339, -6.3000, 11.3569)},
	["GC_HutWest08_wood"] = {t = "GLBCentre", o = Vector3.new(-54.8661, -11.9122, -5.3569)},
	["GC_HutWest09_wood"] = {t = "GLBCentre", o = Vector3.new(-59.1339, -11.9122, 11.3569)},
	["GC_HutWest10_wood"] = {t = "GLBCentre", o = Vector3.new(-54.8661, -12.9365, -5.3569)},
	["GC_HutWest11_wood"] = {t = "GLBCentre", o = Vector3.new(-59.1339, -12.9365, 11.3569)},
	["GC_HutWest12_wood"] = {t = "GLBCentre", o = Vector3.new(-54.8661, -13.9608, -5.3569)},
	["GC_HutWest13_wood"] = {t = "GLBCentre", o = Vector3.new(-59.1339, -13.9608, 11.3569)},
	["GC_HutWest14_wood"] = {t = "GLBCentre", o = Vector3.new(-54.8661, -14.9851, -5.3569)},
	["GC_HutWest15_wood"] = {t = "GLBCentre", o = Vector3.new(-59.1339, -14.9851, 11.3569)},
	["GC_HutWest16_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-57.0000, -0.6000, 3.0000)},
	["GC_HutWest17_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-47.5065, -6.3000, -3.8647)},
	["GC_HutWest18_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-51.9598, -6.3000, 13.5757)},
	["GC_HutWest19_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-62.0402, -6.3000, -7.5757)},
	["GC_HutWest20_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-66.4935, -6.3000, 9.8647)},
	["GC_HutWest21_wood_dark"] = {t = "GLBCentre", o = Vector3.new(-49.7332, -9.9000, 4.8555)},
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
	-- GLB team island: keeps the GLB's own flat colours (Sterling, 2026-10-27). Keys are "GLB:<gltf material>";
	-- colours are the glTF baseColorFactor converted from linear to sRGB.
	["GLB:rock"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(143, 138, 132)},
	["GLB:rock_dark"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(109, 105, 100)},
	["GLB:sand"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(226, 201, 142)},
	["GLB:grass"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(76, 176, 74)},
	["GLB:pine"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(46, 139, 62)},
	["GLB:wood"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(176, 112, 60)},
	["GLB:wood_dark"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(110, 68, 38)},
	["GLB:metal"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(169, 179, 188)},
	["GLB:rust"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(192, 88, 44)},
	["GLB:dark"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(43, 42, 46)},
	["GLB:white"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(242, 239, 232)},
	["GLB:glow"] = {material = Enum.Material.Neon, color = Color3.fromRGB(255, 198, 74)},
	["GLB:Cloth"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(196, 52, 46)}, -- recoloured per team
	-- GLB centre island (Sterling, 2026-10-27): same flat-colour approach, keys "GLBC:<gltf material>"
	["GLBC:rock"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(156, 133, 113)},
	["GLBC:rock_dark"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(122, 101, 83)},
	["GLBC:dirt_path"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(196, 165, 116)},
	["GLBC:sand"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(220, 196, 147)},
	["GLBC:grass"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(95, 174, 69)},
	["GLBC:stone_tile"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(169, 169, 176)},
	["GLBC:gold_trim"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(242, 193, 78)},
	["GLBC:metal"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(185, 188, 196)},
	["GLBC:amethyst_glow"] = {material = Enum.Material.Neon, color = Color3.fromRGB(179, 92, 255)},
	["GLBC:wood_dark"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(94, 58, 30)},
	["GLBC:wood"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(154, 98, 51)},
	["GLBC:roof"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(124, 63, 36)},
	["GLBC:lamp_glow"] = {material = Enum.Material.Neon, color = Color3.fromRGB(255, 211, 107)},
	["GLBC:banner"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(125, 60, 201)},
	["GLBC:leaves"] = {material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(47, 125, 58)},
} :: {[string]: MaterialSpec}

-- Suffixes checked longest first so "_RockDark" wins over "_Rock".
local SUFFIX_ORDER = {"RockDark", "Rock", "Sand", "Rust", "Steel", "Concrete", "Wood", "Cloth", "Linen", "Canvas", "Glow", "Glass"}

function PrepareAssets.suffixOf(name: string): string?
	-- GLB island parts are named GI_<Template>_<gltf material>
	local glb = string.match(name, "^GI_%a+_(.+)$")
	if glb then
		local key = "GLB:" .. glb
		return if PrepareAssets.MATERIALS[key] then key else nil
	end
	-- GLB centre parts are named GC_<Template or HutNameNN>_<gltf material>
	local glbc = string.match(name, "^GC_%w+_(.+)$")
	if glbc then
		local key = "GLBC:" .. glbc
		return if PrepareAssets.MATERIALS[key] then key else nil
	end
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
		or suffix == "GLB:glow" or suffix == "GLB:Cloth" or suffix == "GLB:white"
		or suffix == "GLBC:lamp_glow" or suffix == "GLBC:banner"
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
		-- GLB parts are many boxes joined into one mesh per material: a single hull would wrap them all
		local precise = suffix == "Rock" or suffix == "Sand" or suffix == "Rust" or suffix == "Steel"
			or suffix == "Concrete" or suffix == "Wood" or string.sub(suffix, 1, 3) == "GLB"
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
