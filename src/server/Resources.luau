--!strict
-- Resources: server-owned resource counts per player. Values live in player attributes (for
-- example player:GetAttribute("Wood")) so every client can read its own count for the UI, but only
-- this module changes them; attributes set on a client never replicate back to the server.
--
-- This is the one balance store for the game: building costs, scrap pickups and vending purchases
-- all go through Resources.add / Resources.trySpend, so nothing keeps a second copy of a balance.
-- To add a resource kind, add its name to KINDS (and a start value to START).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BuildingConfig = require(Shared:WaitForChild("BuildingConfig"))
local ScrapConfig = require(Shared:WaitForChild("ScrapConfig"))

local Resources = {}

Resources.KINDS = { "Wood", "Scrap" }
Resources.START = { Wood = 0, Scrap = ScrapConfig.START_SCRAP }

local function valid(kind: string): boolean
	return table.find(Resources.KINDS, kind) ~= nil
end

function Resources.get(player: Player, kind: string): number
	local v = player:GetAttribute(kind)
	return if type(v) == "number" then v else 0
end

function Resources.snapshot(player: Player): { [string]: number }
	local out = {}
	for _, kind in ipairs(Resources.KINDS) do
		out[kind] = Resources.get(player, kind)
	end
	return out
end

function Resources.set(player: Player, kind: string, amount: number)
	assert(valid(kind), `unknown resource {kind}`)
	player:SetAttribute(kind, math.max(0, math.floor(amount)))
end

function Resources.add(player: Player, kind: string, amount: number)
	assert(type(amount) == "number" and amount >= 0 and amount == amount, "add needs a positive amount")
	Resources.set(player, kind, Resources.get(player, kind) + amount)
end

function Resources.canAfford(player: Player, cost: { [string]: number }): boolean
	for kind, amount in pairs(cost) do
		if not valid(kind) or type(amount) ~= "number" or amount < 0 or amount ~= amount then
			return false -- unknown resource or a negative / NaN price
		end
		if Resources.get(player, kind) < amount then
			return false
		end
	end
	return true
end

-- Takes the whole cost or nothing. Returns true when paid.
function Resources.trySpend(player: Player, cost: { [string]: number }): boolean
	if not Resources.canAfford(player, cost) then
		return false
	end
	for kind, amount in pairs(cost) do
		Resources.set(player, kind, Resources.get(player, kind) - amount)
	end
	return true
end

local started = false
function Resources.start()
	if started then
		return
	end
	started = true
	local function onPlayer(player: Player)
		for _, kind in ipairs(Resources.KINDS) do
			if player:GetAttribute(kind) == nil then
				player:SetAttribute(kind, Resources.START[kind] or 0)
			end
		end
		-- Testing stock until shops and dispensers hand out Wood.
		player.CharacterAdded:Connect(function()
			if Resources.get(player, "Wood") < BuildingConfig.TEST_WOOD then
				Resources.set(player, "Wood", BuildingConfig.TEST_WOOD)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
		if p.Character and Resources.get(p, "Wood") < BuildingConfig.TEST_WOOD then
			Resources.set(p, "Wood", BuildingConfig.TEST_WOOD)
		end
	end
end

return Resources
