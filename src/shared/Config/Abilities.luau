--!strict
-- Tuning numbers for riding and abilities, kept in one place so balancing never means
-- hunting through code. First-pass values; tune them in playtests.

return table.freeze({
	ride = table.freeze({
		-- Studio defaults are WalkSpeed 16 / JumpPower 50; riding should feel a bit better.
		walkSpeed = 20,
		walkSpeedPerSpeedStat = 2,
		-- The Speed ability (Cheetah Legs) on top of the stat bonus.
		speedAbilityBonus = 10,
		jumpPower = 50,
		jumpPowerPerJumpStat = 3,
		-- The SuperJump ability (Frog Legs) on top of the stat bonus.
		-- ~16 studs high with Frog Legs, vs ~6.5 for a normal jump.
		superJumpBonus = 20,
		-- How close you must be to your creature to hop on.
		mountDistance = 25,
	}),
	glide = table.freeze({
		-- Gliding caps fall speed (studs/second). Lower = floatier.
		maxFallSpeed = 12,
		fallSpeedPerGlideStat = 1,
		minFallSpeed = 6,
		-- Rising speed inside a Windy Canyons updraft while gliding (studs/second).
		updraftSpeed = 28,
	}),
	light = table.freeze({
		brightness = 2,
		range = 22,
		color = Color3.fromRGB(255, 250, 180),
	}),
	glow = table.freeze({
		brightness = 1,
		range = 12,
		color = Color3.fromRGB(150, 220, 255),
	}),
})
