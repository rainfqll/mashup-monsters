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
- **ProfileStore** (`lm-loleris/profilestore@1.0.3`, the official package) for player data, mapped at
  `ServerStorage.ServerPackages`. Only `PlayerDataService` touches it. Store `PlayerData_Studio` in Studio,
  `PlayerData` live; keys `player_<UserId>`; save schema has a `version` field + `migrate()`.
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
    Services/  PlayerDataService, PickupService, StitchService, BundleService, ShelfService, CreatureService,
               IslandService, ChallengeService, TradeService, CrewService
  client/      -> StarterPlayerScripts.Client  init.client.luau = only LocalScript, starts controllers in order
    Controllers/ InputController, DataController, UIController, PickupController, CreatureController,
                 TutorialController, IslandController, ChallengeController, ShelfController, PingController
    UI/        Theme, Panel (standard pop-up), PartCard (card + reflowing grid), Hud, InventoryScreen,
               BookScreen, StitchScreen, CreaturePreview (spinning ViewportFrame), BundleScreen, RevealOverlay
  shared/      -> ReplicatedStorage.Shared
    Types.luau   Slot, Rarity, PartStats, PartDefinition
    Remotes.luau the ONLY place remotes are declared; server calls Remotes.createAll() at startup
    Config/      Parts, Rarities, Abilities (riding/glide/updraft tuning), Bundles (price, odds, coin value),
                 Islands (order + gate ability), Challenges, Combos (set bonus, Secret Mashups), Shelf (coins/hour)
    Daily.luau   UTC day, daily reset, Part of the Day (same for everyone, no storage)
    Water.luau   terrain-water check at the feet, shared by the client and server water gates
    Creatures.luau        loadout rules: parseLoadout (validates untrusted input), summarize, MAX_SAVED
    CreatureAssembler.luau builds a creature Model from PartModels by snapping attachments
  server/RateLimit.luau  per-player remote cooldowns
tools/build_part_models.luau  rebuilds ReplicatedStorage.PartModels in Studio (git backup of the models)
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

**Phase 0: Setup: DONE.** Repo: https://github.com/rainfqll/mashup-monsters (public).

**Phase 1: Parts and inventory: DONE (awaiting user review).** Verified in Studio with real DataStore
access: collect parts on Meadow Isle, stop, play again, inventory still there.
- Pickups: Studio-owned invisible BaseParts tagged `PickupSpot` with a `PartId` attribute
  (`Workspace.MeadowIsle.PickupSpots`). `PartService` (now `PickupService`) builds a glowing pickup on each; collecting uses the
  server's own Touched (no collect remote) + distance check; pickups are pooled and respawn after 30 s.
- Remotes: `ClientReady` (client->server once), `DataSnapshot` and `PartCollected` (server->client).
- Placeholder Meadow Isle was built in Studio via MCP (floating disc, hills, trees). The template
  Baseplate was moved to ServerStorage, not deleted. Studio API access is ON and the place is published.
- Spec change: parts have `abilities: { Ability }` (a list) instead of one `ability`.
- Deferred: button sounds (juice pass), slot icons instead of tab words, real part models/icons (Phase 2),
  analytics funnel events (with the tutorial in Phase 3), device-emulator check by the user.

**Phase 2: Stitch Station and creatures: DONE (awaiting user review).** Verified in Studio: stitch at the
station, creature follows, ride/hop off, super jump, glide, swim gate (bounce without Swim, allowed with
Swim, wading counts as water), respawn while riding, unstitch returns parts, book, save v2 + rejoin,
server rejects bad stitch requests (far, wrong slot, not owned, junk).
- Decisions: stitched parts move into the creature and come back on unstitch; 3 saved creatures, 1 out;
  Ride button (hop on/off); free Stitchy Blob body when Body is empty; any slot may be empty (min 1 part).
- Save v2: `creatures` (loadouts), `activeCreature` (0 = none), `discovered` (book). v1 migrates by marking
  inventory parts discovered; unparseable creatures are taken apart into the inventory, never deleted.
- Remotes added: `Stitch` (Function, returns ok + message), `Unstitch`, `SetActiveCreature`, `ToggleRide`.
- Studio world (not in git): `ReplicatedStorage.PartModels` (17 models; rebuild with tools/build_part_models.luau),
  `MeadowIsle.Lab` with `StitchStation` (the Table part is tagged `StitchStation`), `MeadowIsle.TestPond`
  (raised pool + terrain water, for swim testing until Lily Lagoon).
- Riding: server welds creature under the HumanoidRootPart, sets HipHeight = seatOffset.Y + halfHeight and
  WalkSpeed/JumpPower from Config/Abilities; client does follow (AlignPosition, player has network
  ownership), sit animation (from the Animate script), glide (fall-speed cap) and the water gate.
- Known gaps: the water gate is client-side (fine for progression, an exploiter could skip it; add a server
  check when islands gate rewards); abilities Dig/Reveal/Climb/Carry/Shield have no gameplay yet;
  button sounds; device-emulator check by the user; ride button position is a fixed 42% height (verify vs
  jump button on small phones).

**Phase 3: First-time experience and starter islands: DONE (awaiting user review).** Goal: spawn -> riding the
first creature in under 3 minutes without reading. Verified in Studio on a fresh save: starter trail -> stitch screen
pre-filled -> stitch -> ride -> river -> Lily Lagoon, all 5 funnel events, coins, bundle machine + hatching reveal.
- Decisions: starters Duck Head + Duck Feet + Pig Tail (makes a Swim creature); floating river Meadow -> Lagoon;
  coins 5 each, bundle 50 (~5 min); odds shown on the machine; hatching egg reveal, nothing slot-machine-like.
- Save v3: `tutorialDone`, `starterCollected`, `funnel` (milestones logged once). v2 -> v3 sets tutorialDone if the
  player already has a creature. `PickupService` (renamed from PartService) handles part bubbles, coins (`CoinSpot`),
  and starter spots (`StarterSpot`, collected through the `CollectStarterPart` remote; each player sees their own).
- `BundleService`: coins only, server rolls rarity from `Config/Bundles.odds`, `OpenBundle` RemoteFunction.
  The machine prompt stays hidden until the player has a creature (keeps the first minutes focused).
- `IslandService`: server water gate (teleports non-swimmers back, 1 s grace) + island zones (`IslandZone` parts
  with `Island`/`DisplayName`) that record FirstNewIsland. `CreatureService.canSwim` answers the gate.
- Analytics: onboarding funnel (Joined, FirstPart, FirstStitch, FirstRide, FirstNewIsland) + coin economy events.
- Dev switch: set the attribute `DevStoreSuffix` (string) on ServerStorage to play as a brand-new player on a
  separate Studio store (e.g. `_Fresh3`). Remove it to go back to your normal Studio save. Studio only.
- Studio world (not in git): `MeadowIsle.StarterSpots`, `CoinSpots`, `Zone`, `BundleMachine`; `LilyLagoon`
  (pool, islet, hidden parts, coins, Zone); `LagoonRiver` (glass floor + water, `GuideTarget`).
- Known gaps: coins respawn every 20 s, so a lagoon lap pays for a bundle quickly (tune after playtests);
  abilities Dig/Reveal/Climb/Carry/Shield still have no gameplay; button sounds; device-emulator check.

**Phase 4: Progression: DONE (awaiting user review).** Built in 3 milestones (4a islands, 4b combos, 4c daily).
Verified in Studio: super-jump ledges Lagoon -> Peaks, glide Peaks -> Canyons, gates send non-qualified arrivals home,
travel pads, summit chest (first reward, then coins + cooldown), Wind Rings course (server-checked, Eagle Wings),
Night Hopper secret (aura, book, Bat set bonus), shelf display + collect, daily bundle (once per UTC day).
- Decisions: 8 new parts (Goat/Bat/Eagle/Chicken/Cheetah pairs, first Legendary = Eagle Wings from the ring course);
  shelf = saved creatures not out, coins/hour by rarity, 8 h cap; daily reset at midnight UTC for everyone; Secret
  Mashups are looks only (name, aura, book page).
- Design fix: abilities can't stack across a single creature (Swim and Glide are both Back parts), so islands are
  linked by travel pads at the lab (unlocked on first legit arrival). Each gate needs exactly one ability.
- Updrafts (Windy Canyons, tag `Updraft`): gliding inside lifts you, so every glider can finish the ring course.
- Save v4: unlockedIslands, challengesDone, secretsFound, shelfStored/shelfUpdatedAt, dailyBundleDay. v3 -> v4 keeps
  Lily Lagoon unlocked for anyone who reached it. The shelf is "settled" before any creature change (no swap exploit).
- Remotes added: Notice, ChallengeProgress (server -> client); OpenBundle takes "daily".
- Studio world (not in git): `CliffsidePeaks` (JumpLedges from the Lagoon east edge, Summit pillar + SummitChest,
  GlideDeck), `WindyCanyons` (mesas, Updrafts, WindRings), `MeadowIsle.TravelPlaza` (3 pads + HomeArrival),
  `MeadowIsle.DisplayShelf` (Base tagged DisplayShelf, invisible Pedestal1-3 tagged ShelfPedestal), Lagoon `Travel`.
  Part models: 25 (tools/build_part_models.luau).
- Known gaps: Glowcap Caves (Light) not built; weekly Secret hint and event parts (later); abilities Dig/Reveal/
  Climb/Carry/Shield still no gameplay; challenge repeat cooldowns reset on rejoin (a few coins at most);
  economy numbers are first guesses (tune after playtests).

**Next: Phase 5 (Co-op).** Start with a short plan + decisions.

Notes for the next session:
- GitHub sign-in is set up on the Mac: `gh` (2.102.0, Intel build under Rosetta) lives in `~/.local/bin`,
  logged in as rainfqll, and `gh auth setup-git` is done, so `git push` just works. Push after each phase commit.
- Harmless Studio noise in Output (not ours, ignore): `ContentId rbxassetid://203785492 ... Asset type
  does not match`, `Asset id 12946311200 should reference a Folder Instance named R15Anim`,
  `[profilestore]: Roblox API services available`, and `UIBlox FoundationProvider` / `CorePackages...`
  stack traces. Our messages start with `[Mashup Monsters]`.
- Rojo must be connected in Edit mode (not during Play). On connect, Rojo may ask to Accept changes.
  Claude can start `rojo serve` itself; the user clicks Connect in the Rojo plugin.
- The Studio MCP `studio_id` changes when Studio reloads (e.g. after publishing): call `list_roblox_studios` again.
- Studio stops rendering when its window is minimized or hidden: prompts never show and `screen_capture` hangs.
  Ask the user to keep Studio visible during play tests. `screen_capture` in Edit mode often hangs; use Play mode
  with `camera_position`. ProximityPrompts only show when their part is on screen: point the camera first.
- StreamingEnabled is on: client code must handle tagged parts that stream in later (GetInstanceAddedSignal).
- Test saves: the string attribute `DevStoreSuffix` on ServerStorage switches to a separate Studio store.
