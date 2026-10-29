-- Server entry point. Starts the gameplay services in order.
local Resources = require(script:WaitForChild("Resources"))
local BuildingService = require(script:WaitForChild("BuildingService"))

Resources.start()
BuildingService.start()
