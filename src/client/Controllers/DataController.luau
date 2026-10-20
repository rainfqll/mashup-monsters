--!strict
-- DataController: holds the latest copy of this player's data that the server sent.
-- Read-only on purpose; changes only ever come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type Listener = (Types.PlayerSnapshot) -> ()

local snapshot: Types.PlayerSnapshot? = nil
local listeners: { Listener } = {}

local DataController = {}

-- nil until the server has loaded the save.
function DataController.get(): Types.PlayerSnapshot?
	return snapshot
end

-- Calls `listener` with every new snapshot (and right away if one already arrived).
-- Returns a function that stops listening.
function DataController.onChanged(listener: Listener): () -> ()
	table.insert(listeners, listener)
	if snapshot ~= nil then
		task.spawn(listener, snapshot)
	end
	return function()
		local index = table.find(listeners, listener)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

function DataController.start(): ()
	Remotes.event("DataSnapshot").OnClientEvent:Connect(function(newSnapshot: Types.PlayerSnapshot)
		snapshot = newSnapshot
		for _, listener in table.clone(listeners) do
			task.spawn(listener, newSnapshot)
		end
	end)
	-- Ask only after listening, so the first snapshot can't arrive before we're ready.
	Remotes.event("ClientReady"):FireServer()
end

return DataController
