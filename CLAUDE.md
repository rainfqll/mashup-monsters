# Mashup Monsters

Read `docs/GAME_DESIGN.md` at the start of every session. It is the full spec and source of truth.
The user is new to Roblox development: explain decisions briefly in plain language, work in small
milestones, and stop for review at the end of each phase.

## Concept

A kid-friendly (ages 6-14, Minimal maturity) Roblox game. Players explore floating islands,
collect creature parts (duck heads, frog legs, bat wings...), stitch them into a mashup monster
at their lab, and use the creature's abilities (swim, super jump, glide, light) to reach new
islands with rarer parts. Solo-complete, co-op-better. Mobile first. Works without chat.
Original IP only, no Toolbox scripts.

## Tech stack (approved)

- Luau, `--!strict` on every file (`.luaurc` also sets strict)
- **Rojo 7.7.1**: code is files on disk, synced into Studio. Git owns the code.
- **Rokit** pins tools in `rokit.toml`: rojo, wally, selene, stylua. luau-lsp comes from the VS Code extension.
- **Wally** for packages (`wally.toml`). Server-only libraries go in `[server-dependencies]` and install to `ServerPackages/`.
- **ProfileStore** for player data (to be added in Phase 1: verify the Wally package name/version first,
  then add `ServerPackages` to `default.project.json` under ServerStorage).
- Roblox skills from `TabooHarmony/roblox-brain` in `.agents/skills` (linked in `.claude/skills`).
  Load `roblox-collaboration-mode` first, then the domain skill (gui, architecture, networking, security, data, luau-types, game-design...).

## Who owns what (important)

- **Code: files on disk.** `src/` syncs to Studio via `rojo serve`. Never edit synced scripts inside Studio
  (directly or through MCP); Rojo would overwrite them. Edit the files.
- **World: Studio.** Islands, Stitch Station, decorations, lighting live in the place file (published to
  Roblox; version history is the backup). Rojo does not touch Workspace/Lighting. Build these with the
  Studio MCP or by hand. Never delete or overwrite the user's Studio work without asking.
- Place files (`*.rbxl`) are git-ignored.

## Folder structure

```
default.project.json   Rojo mapping (only code folders)
src/
  server/      -> ServerScriptService.Server   init.server.luau = only server Script, starts services in order
    Services/  PlayerDataService, PartService, StitchService, CreatureService, TradeService, CrewService
  client/      -> StarterPlayerScripts.Client  init.client.luau = only LocalScript, starts controllers in order
    Controllers/ InputController, UIController, CreatureController, PingController
    UI/        (added in Phase 1)
  shared/      -> ReplicatedStorage.Shared
    Types.luau   Slot, Rarity, PartStats, PartDefinition
    Remotes.luau the ONLY place remotes are declared; server calls Remotes.createAll() at startup
    Config/      (added in Phase 1: Parts, Rarities, Abilities, Islands, Combos)
docs/          GAME_DESIGN.md (spec), HOW_TO_SYNC.md (user setup steps)
```

Patterns: services/controllers are plain modules with a `start()`; the entry script calls them in an
explicit order and errors loudly. No frameworks, no event bus, no Init/Start ceremony beyond that.
Content is data-driven: a new part = one entry in `Config/Parts.luau` + a model.

## Coding rules (from spec section 6)

1. Server authority: client asks, server decides. Validate every remote (types, NaN, ranges, ownership, distance, cooldowns) and rate-limit.
2. Random rolls on the server only.
3. Safe saving: retries with backoff, session locking, save on leave and `BindToClose`, trades never lose items.
4. No deprecated APIs; check docs when unsure (Studio MCP `get_roblox_docs` if available).
5. Clean up connections (player leave, UI close, creature despawn).
6. Performance: pool spawned objects, stream large worlds, lightweight pickups, test low-end mobile.
7. UI: follow `roblox-gui` skill. Mobile first, keep top bar / joystick / jump areas clear, scale sizing + constraints, big touch targets, icons over text, controller focus, chunky rounded style with thick dark outlines, lime green + purple brand.
8. Juice: button tweens + sounds, rarity-colored shake-glow-burst reveals, stitch particles.
9. Analytics funnel events: joined, first part, first stitch, first ride, first new island, first co-op action.
10. Small readable modules; comments explain why, not what.

## Checks before every commit

```
stylua --check src
selene src
rojo build -o build.rbxl      # proves the project maps cleanly (file is git-ignored)
```
Plus, when the Studio MCP is connected: sync, `start_stop_play`, `get_console_output` (no errors), `screen_capture`.

## Agreed spec adjustments

- Trading (Phase 5): friends-only, short countdown before final confirm, fresh Secret parts not tradable for a short time.
- Bundle reveal: "hatching/unboxing" look, nothing resembling slot machines.

## Current phase

**Phase 0: Setup: DONE.** The user cloned the repo on their Mac (`~/Documents/mashup-monsters`), Rojo
syncs, and Play shows "server ready (6 services)" and "client ready (4 controllers)" in Output.
Repo: https://github.com/rainfqll/mashup-monsters (public).

**Next: Phase 1 (Parts and inventory)**, in Claude Code on the Mac with the Studio MCP connected.
Start by showing the user a short Phase 1 plan and any decisions (multiple choice), then wait for OK.

Notes for the next session:
- The user is on a Mac without Homebrew. Pushing from the Mac needs GitHub sign-in: the GitHub CLI `.pkg`
  from https://cli.github.com, then `gh auth login`. Help them set this up before the first push.
- Harmless Studio noise in Output (not ours, ignore): `ContentId rbxassetid://203785492 ... Asset type
  does not match`, `Asset id 12946311200 should reference a Folder Instance named R15Anim`, and
  `CorePackages...ReactFiberWorkLoop` stack traces (x5, Client). Our messages start with `[Mashup Monsters]`.
- Rojo must be connected in Edit mode (not during Play). On connect, Rojo may ask to Accept changes.
