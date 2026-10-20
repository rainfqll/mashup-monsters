--!strict
-- PlayerDataService: the only module that reads or writes saved player data (coins, parts, creature book). Keeping saves behind one owner makes session locking and safe retries possible.
-- Phase 0 stub: starts cleanly and does nothing yet. Real work arrives in Phase 1.

local PlayerDataService = {}

function PlayerDataService.start(): () end

return PlayerDataService
