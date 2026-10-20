--!strict
-- One small challenge per island (spec 4.3). The first completion gives a guaranteed part;
-- after that, each completion pays a few coins with a cooldown, so they stay worth replaying.
-- Ids are saved in player data (challengesDone), so never rename one once it has shipped.
--
-- World pieces (built in Studio), matched by the string attribute "Challenge":
--   * kind "Chest": a part tagged "ChallengeChest"; the reward is a prompt on it.
--   * kind "Rings": parts tagged "ChallengeRing" with a number attribute "Order" (1, 2, 3...).
--     Fly through them in order within `timeLimit` seconds. Ring size comes from the part.

export type ChallengeKind = "Chest" | "Rings"

export type ChallengeDefinition = {
	id: string,
	kind: ChallengeKind,
	displayName: string,
	island: string,
	firstReward: string,
	repeatCoins: number,
	repeatCooldown: number,
	timeLimit: number?,
}

local LIST: { ChallengeDefinition } = {
	{
		id = "PeaksSummit",
		kind = "Chest",
		displayName = "Summit Chest",
		island = "CliffsidePeaks",
		firstReward = "OwlWings",
		repeatCoins = 10,
		repeatCooldown = 300,
	},
	{
		id = "CanyonRings",
		kind = "Rings",
		displayName = "Wind Rings",
		island = "WindyCanyons",
		firstReward = "EagleWings",
		repeatCoins = 15,
		repeatCooldown = 300,
		timeLimit = 45,
	},
}

local byId: { [string]: ChallengeDefinition } = {}
for _, challenge in LIST do
	assert(byId[challenge.id] == nil, `Duplicate challenge id "{challenge.id}"`)
	byId[challenge.id] = table.freeze(challenge)
end

local Challenges = {}

Challenges.list = table.freeze(LIST)

function Challenges.get(id: string): ChallengeDefinition?
	return byId[id]
end

return table.freeze(Challenges)
