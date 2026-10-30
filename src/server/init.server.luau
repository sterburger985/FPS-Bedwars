-- Server entry point. Starts the gameplay services in order.
local Resources = require(script:WaitForChild("Resources"))
local InventoryService = require(script:WaitForChild("InventoryService"))
local BuildingService = require(script:WaitForChild("BuildingService"))
local ScrapDropperService = require(script:WaitForChild("ScrapDropperService"))
local ShopService = require(script:WaitForChild("ShopService"))

Resources.start()
InventoryService.start()
BuildingService.start()
ScrapDropperService.start()
ShopService.start()
