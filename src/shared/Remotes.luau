--!strict
-- Every RemoteEvent / RemoteFunction in the game is declared in DEFINITIONS below.
-- Keeping them in one list means the whole client-to-server attack surface can be
-- reviewed in a single file, and nothing can create a remote "on the side".
--
-- Server: call Remotes.createAll() once at startup, before any service connects handlers.
-- Both sides: get a remote with Remotes.event / Remotes.unreliableEvent / Remotes.func.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteKind = "Event" | "UnreliableEvent" | "Function"

local DEFINITIONS: { [string]: RemoteKind } = {
	-- Client -> server, once: "my UI is listening, send my data". Lets the snapshot never
	-- arrive before the client is ready for it. No arguments are read.
	ClientReady = "Event",
	-- Server -> client: full copy of the player's own coins and inventory (small, so no diffs).
	DataSnapshot = "Event",
	-- Server -> client: (partId) the player just collected, for the pop-up and button bounce.
	-- Collecting itself needs no remote: the server detects the touch.
	PartCollected = "Event",
	-- Client -> server: (loadout) stitch these parts at a nearby station. Returns
	-- (ok: boolean, message: string?) so the screen can show why a stitch was refused.
	Stitch = "Function",
	-- Client -> server: (index) take creature apart at a nearby station; parts return to the bag.
	Unstitch = "Event",
	-- Client -> server: (index) which saved creature is out; 0 puts it away.
	SetActiveCreature = "Event",
	-- Client -> server: () hop on or off your creature. The server checks distance.
	ToggleRide = "Event",
	-- Client -> server: (spotName) touched a personal tutorial starter part. Server checks the
	-- spot is real, the player is next to it, and the tutorial is still running.
	CollectStarterPart = "Event",
	-- Client -> server: () buy one mystery bundle at a nearby machine. Returns
	-- (partId: string?, message: string?); the roll happens on the server.
	OpenBundle = "Function",
}

local FOLDER_NAME = "Remotes"

-- Bounded so a missing remote shows up as a clear error instead of a silent hang.
local WAIT_SECONDS = 15

local Remotes = {}

function Remotes.createAll(): ()
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	assert(
		ReplicatedStorage:FindFirstChild(FOLDER_NAME) == nil,
		"Remotes folder already exists; createAll must run once"
	)

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for name, kind in DEFINITIONS do
		local remote: Instance
		if kind == "Event" then
			remote = Instance.new("RemoteEvent")
		elseif kind == "UnreliableEvent" then
			remote = Instance.new("UnreliableRemoteEvent")
		else
			remote = Instance.new("RemoteFunction")
		end
		remote.Name = name
		remote.Parent = folder
	end

	-- Parent last so clients never see a half-filled folder.
	folder.Parent = ReplicatedStorage
end

local function findRemote(name: string, expected: RemoteKind): Instance
	local kind = DEFINITIONS[name]
	if kind == nil then
		error(`Unknown remote "{name}". Declare it in Remotes.luau first.`, 3)
	end
	if kind ~= expected then
		error(`Remote "{name}" is a {kind}, not a {expected}.`, 3)
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_SECONDS)
	if folder == nil then
		error(`Remotes folder did not appear within {WAIT_SECONDS}s.`, 3)
	end
	local remote = folder:WaitForChild(name, WAIT_SECONDS)
	if remote == nil then
		error(`Remote "{name}" did not appear within {WAIT_SECONDS}s.`, 3)
	end
	return remote
end

function Remotes.event(name: string): RemoteEvent
	local remote = findRemote(name, "Event")
	assert(remote:IsA("RemoteEvent"), `"{name}" is not a RemoteEvent`)
	return remote
end

function Remotes.unreliableEvent(name: string): UnreliableRemoteEvent
	local remote = findRemote(name, "UnreliableEvent")
	assert(remote:IsA("UnreliableRemoteEvent"), `"{name}" is not an UnreliableRemoteEvent`)
	return remote
end

function Remotes.func(name: string): RemoteFunction
	local remote = findRemote(name, "Function")
	assert(remote:IsA("RemoteFunction"), `"{name}" is not a RemoteFunction`)
	return remote
end

return Remotes
