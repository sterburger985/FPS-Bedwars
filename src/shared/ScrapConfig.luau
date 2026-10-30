--!strict
-- ScrapConfig: scrap dropper and pickup settings, read by ScrapDropperService (server) and the scrap
-- pickup visuals (client). The droppers are the team scrap stations (tag "ScrapDropper").

local ScrapConfig = {}

ScrapConfig.INTERVAL = 5 -- seconds between drops while a dropper has room
ScrapConfig.PER_DROP = 1 -- pickups created per drop
ScrapConfig.MAX_ACTIVE = 5 -- uncollected pickups per dropper; generation pauses when full
ScrapConfig.LIFETIME = 60 -- seconds before an uncollected pickup is removed
ScrapConfig.VALUE = 1 -- scrap per pickup

ScrapConfig.PROMPT_DISTANCE = 8 -- how close a player must be to see the collect prompt
ScrapConfig.SERVER_RANGE_SLACK = 4 -- extra distance the server allows (movement, latency)

-- Where pickups rest, relative to the dropper's ScrapOutput attachment (station space, studs).
-- One spot per possible pickup, so they never pile into each other.
ScrapConfig.SPOTS = {
	Vector3.new(0, 0, 0),
	Vector3.new(1.9, 0, 1.7),
	Vector3.new(-1.9, 0, 1.7),
	Vector3.new(1.9, 0, -1.7),
	Vector3.new(-1.9, 0, -1.7),
}

ScrapConfig.START_SCRAP = 0 -- scrap each player starts the session with

return ScrapConfig
