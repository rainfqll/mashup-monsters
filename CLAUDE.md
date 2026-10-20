# Mashup Monsters

Read `docs/GAME_DESIGN.md` at the start of every session. It is the full spec and source of truth.

## Concept

A kid-friendly (ages 6-14, Minimal maturity) Roblox game. Players explore floating islands,
collect creature parts (duck heads, frog legs, bat wings...), stitch them into a mashup monster
at their lab, and use the creature's abilities (swim, super jump, glide, light) to reach new
islands with rarer parts. Solo-complete, co-op-better. Mobile first. Works without chat.
Original IP only, no Toolbox scripts.

## Tech stack (proposed, awaiting approval)

- Luau, `--!strict` wherever practical
- Rojo (files on disk sync into Studio; git is the source of truth for code)
- Rokit for pinning tools: rojo, selene, stylua, luau-lsp
- ProfileStore for player data (session-locked, versioned schema with migrations)
- Roblox skills from `TabooHarmony/roblox-brain` (installed under `.agents/skills`, linked in `.claude/skills`)

## Folder structure (proposed)

```
src/
  server/     Services/ (PlayerDataService, PartService, StitchService, CreatureService, TradeService, CrewService)
  client/     Controllers/ (UIController, CreatureController, InputController, PingController), UI/
  shared/     Config/ (Parts, Rarities, Abilities, Islands, Combos), Types, Remotes
docs/
```

Content is data-driven: a new part = one entry in `Config/Parts.luau` + a model.

## Coding rules (from spec section 6)

1. Server authority: client asks, server decides. Validate every remote (types, ranges, ownership, distance, cooldowns) and rate-limit.
2. Random rolls on the server only.
3. Safe saving: retries with backoff, session locking, save on leave and `BindToClose`, trades never lose items.
4. No deprecated APIs; check docs when unsure.
5. Clean up connections (player leave, UI close, creature despawn).
6. Performance: pool spawned objects, stream large worlds, lightweight pickups, test low-end mobile.
7. UI: follow `roblox-gui` skill. Mobile first, keep top bar / joystick / jump areas clear, scale sizing + constraints, big touch targets, icons over text, controller focus, chunky rounded style with thick dark outlines, lime green + purple brand.
8. Juice: button tweens + sounds, rarity-colored shake-glow-burst reveals, stitch particles.
9. Analytics funnel events: joined, first part, first stitch, first ride, first new island, first co-op action.
10. Small readable modules; comments explain why, not what.

## How we work

- One phase at a time. Plan first, build, playtest, commit, short plain-language report, then stop for review.
- Never delete/overwrite the user's Studio work without asking; commit before large changes.
- Studio MCP: **not connected** in the current (cloud) session, so code is written on disk and the user syncs and playtests in Studio.

## Current phase

**Phase 0: Setup**. Docs written; project setup proposed and waiting for the user's OK.
