--!strict
-- Playing together without chat (spec 3 and 4.4): one-tap pings that show up in the world for
-- everyone, emotes, and the friend loot bonus.

export type PingKind = "Here" | "Help" | "Look"

export type PingInfo = {
	label: string,
	color: Color3,
}

local PINGS: { [PingKind]: PingInfo } = {
	Here = { label = "Here!", color = Color3.fromRGB(150, 230, 60) },
	Help = { label = "Help!", color = Color3.fromRGB(255, 110, 130) },
	Look = { label = "Look!", color = Color3.fromRGB(255, 205, 60) },
}

return table.freeze({
	pings = table.freeze(PINGS),
	-- Menu order.
	pingOrder = table.freeze({ "Here", "Help", "Look" } :: { PingKind }),
	-- How long a ping marker stays up, the per-player cooldown, and how far from yourself
	-- you may place one (a "Look!" ping goes where your camera points).
	pingSeconds = 6,
	pingCooldown = 1.5,
	pingRange = 200,
	-- Emotes built into the default Roblox character (Animate's PlayEmote).
	emotes = table.freeze({
		table.freeze({ id = "wave", label = "Wave" }),
		table.freeze({ id = "cheer", label = "Cheer" }),
		table.freeze({ id = "dance", label = "Dance" }),
	}),
	-- Extra coins per coin pickup for each friend in the same server, up to the max.
	friendCoinBonus = 1,
	maxFriendsCounted = 3,
})
