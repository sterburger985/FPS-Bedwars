--!strict
-- Items: equipment that can sit in the hotbar. Resources (Wood, Scrap) are not items; they are
-- balances in the Resources module and never take a hotbar slot.

export type ItemDef = { name: string, studioOnly: boolean? }

local Items = {}

Items.HOTBAR_SIZE = 6

Items.DEFS = {
	Blueprint = { name = "Blueprint" },
	Hammer = { name = "Dev Hammer", studioOnly = true },
} :: { [string]: ItemDef }

-- What every player starts with, in slot order (studio-only items are skipped outside Studio).
Items.STARTER = { "Blueprint", "Hammer" }

return Items
