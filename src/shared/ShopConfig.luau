--!strict
-- ShopConfig: what each vending machine sells. Machines are the team scrap stations' vending machines
-- (tag "VendingMachine", attribute Machine). Prices and goods are resource tables that go straight to
-- the Resources module, so the shop never keeps a balance of its own.

local ShopConfig = {}

export type Item = {
	id: string,
	name: string,
	description: string,
	give: { [string]: number },
	cost: { [string]: number },
}
export type Machine = { title: string, items: { Item }, emptyText: string? }

ShopConfig.MACHINES = {
	Materials = {
		title = "Materials",
		items = {
			{ id = "Wood10", name = "Wood x10", description = "One wall, floor or roof", give = { Wood = 10 }, cost = { Scrap = 5 } },
			{ id = "Wood50", name = "Wood x50", description = "Bulk crate", give = { Wood = 50 }, cost = { Scrap = 20 } },
		},
	},
	Guns = {
		title = "Guns",
		items = {},
		emptyText = "No stock yet. Weapons are coming soon.",
	},
} :: { [string]: Machine }

ShopConfig.USE_DISTANCE = 10 -- studs from the machine's front (the server adds a little slack)
ShopConfig.BUY_COOLDOWN = 0.2 -- seconds between purchases per player

function ShopConfig.find(machine: string, itemId: string): Item?
	local m = ShopConfig.MACHINES[machine]
	if not m then
		return nil
	end
	for _, it in ipairs(m.items) do
		if it.id == itemId then
			return it
		end
	end
	return nil
end

return ShopConfig
