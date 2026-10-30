--!strict
-- InventoryService: each player's equipment hotbar and the item they hold. Server-owned.
--
--   player attribute "Hotbar"   comma-separated item ids, one per slot (empty slots are blank)
--   player attribute "Equipped" the item id in the player's hands, or ""
--
-- Clients ask to hold a slot with Remotes.Equip(slot) (0 = hands empty); the server checks the slot
-- really holds an item. Other systems check InventoryService.equipped(player) before acting, so a
-- client can't build without the blueprint in hand or use an item it doesn't own.
-- Resources (Wood, Scrap) are not items: they live in the Resources module and never take a slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local InventoryService = {}

local hotbars: { [Player]: { string } } = {}
local started = false

local function publish(player: Player)
	local slots = hotbars[player] or {}
	local parts = {}
	for n = 1, Items.HOTBAR_SIZE do
		parts[n] = slots[n] or ""
	end
	player:SetAttribute("Hotbar", table.concat(parts, ","))
end

local function allowed(item: string): boolean
	local def = Items.DEFS[item]
	return def ~= nil and (not def.studioOnly or RunService:IsStudio())
end

function InventoryService.slots(player: Player): { string }
	return table.clone(hotbars[player] or {})
end

function InventoryService.has(player: Player, item: string): boolean
	return table.find(hotbars[player] or {}, item) ~= nil
end

-- Puts an item in the first empty slot. Returns the slot, or nil when the hotbar is full.
function InventoryService.give(player: Player, item: string): number?
	if not allowed(item) then
		return nil
	end
	local slots = hotbars[player]
	if not slots then
		slots = {}
		hotbars[player] = slots
	end
	for n = 1, Items.HOTBAR_SIZE do
		if slots[n] == nil or slots[n] == "" then
			slots[n] = item
			publish(player)
			return n
		end
	end
	return nil
end

function InventoryService.take(player: Player, item: string)
	local slots = hotbars[player]
	local n = slots and table.find(slots, item)
	if slots and n then
		slots[n] = ""
		if player:GetAttribute("Equipped") == item then
			player:SetAttribute("Equipped", "")
		end
		publish(player)
	end
end

function InventoryService.equipped(player: Player): string
	local v = player:GetAttribute("Equipped")
	return if type(v) == "string" then v else ""
end

function InventoryService.equip(player: Player, slot: number): boolean
	if slot == 0 then
		player:SetAttribute("Equipped", "")
		return true
	end
	local slots = hotbars[player]
	local item = slots and slots[slot]
	if not item or item == "" then
		return false
	end
	player:SetAttribute("Equipped", item)
	return true
end

function InventoryService.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local equip = Instance.new("RemoteEvent")
	equip.Name = "Equip"
	equip.Parent = remotes
	equip.OnServerEvent:Connect(function(player: Player, slot: any)
		if type(slot) ~= "number" or slot ~= slot or slot ~= math.floor(slot) or slot < 0 or slot > Items.HOTBAR_SIZE then
			return
		end
		InventoryService.equip(player, slot)
	end)

	local function onPlayer(player: Player)
		hotbars[player] = {}
		for _, item in ipairs(Items.STARTER) do
			InventoryService.give(player, item)
		end
		publish(player)
		player:SetAttribute("Equipped", "")
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Equipped", "") -- respawn with empty hands
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		hotbars[p] = nil
	end)
end

return InventoryService
