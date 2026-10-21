--!strict
-- Robux products (spec 4.7). Everything here is a convenience, never needed to finish the game.
--
-- Portal Pass (game pass): lets you step into any portal and travel to any region you have
-- already reached. Without it you walk and ride, which is the whole open world anyway.
-- Create the pass in the Creator Dashboard (Monetization > Passes) and put its id here;
-- while the id is 0, the portals say "coming soon" instead of opening the shop.
-- In Studio, the ServerStorage attribute "DevPortalPass" = true pretends you own it.

return table.freeze({
	portalPassId = 0,
	portalPassName = "Portal Pass",
})
