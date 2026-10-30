--!strict
-- ShopService: buying from the team scrap stations' vending machines (tag "VendingMachine",
-- attribute Machine). Prices and goods come from ShopConfig; balances come from Resources, so the
-- shop has no balance of its own.
--
-- Remotes.ShopBuy (RemoteFunction): (machine model, item id) -> ok, message.
-- The server checks the machine is real, sells that item, and the player is alive and standing at it,
-- then takes the whole price or nothing (Resources.trySpend) and hands over the goods.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local Resources = require(script.Parent:WaitForChild("Resources"))

local ShopService = {}

local lastBuy: { [Player]: number } = {}
local started = false

local function costText(cost: { [string]: number }): string
	local parts = {}
	for kind, n in pairs(cost) do
		table.insert(parts, `{n} {kind}`)
	end
	return table.concat(parts, " + ")
end

-- Is the player standing at this machine?
local function inReach(player: Player, machine: Model): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then
		return false
	end
	local front = machine:FindFirstChild("PromptPart")
	local at = if front and front:IsA("BasePart") then front.Position else machine:GetPivot().Position
	return (root.Position - at).Magnitude <= ShopConfig.USE_DISTANCE + 4
end

function ShopService.purchase(player: Player, machine: any, itemId: any): (boolean, string)
	if typeof(machine) ~= "Instance" or not machine:IsA("Model") or not machine:IsDescendantOf(workspace)
		or not CollectionService:HasTag(machine, "VendingMachine") then
		return false, "That isn't a vending machine"
	end
	local kind = machine:GetAttribute("Machine")
	local def = type(kind) == "string" and ShopConfig.MACHINES[kind] or nil
	if not def then
		return false, "That isn't a vending machine"
	end
	if type(itemId) ~= "string" then
		return false, "Unknown item"
	end
	local item = ShopConfig.find(kind :: string, itemId)
	if not item then
		return false, def.emptyText or "Not sold here"
	end
	if not inReach(player, machine) then
		return false, "Stand at the machine to buy"
	end
	local now = os.clock()
	if now - (lastBuy[player] or 0) < ShopConfig.BUY_COOLDOWN then
		return false, "Too fast"
	end
	lastBuy[player] = now
	if not Resources.trySpend(player, item.cost) then
		return false, `Needs {costText(item.cost)}`
	end
	for res, n in pairs(item.give) do
		Resources.add(player, res, n)
	end
	return true, `Bought {item.name}`
end

function ShopService.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local buy = Instance.new("RemoteFunction")
	buy.Name = "ShopBuy"
	buy.Parent = remotes
	buy.OnServerInvoke = function(player: Player, machine: any, itemId: any)
		return ShopService.purchase(player, machine, itemId)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastBuy[p] = nil
	end)
end

return ShopService
