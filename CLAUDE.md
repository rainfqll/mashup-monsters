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
    Services/  PlayerDataService, SocialService, PickupService, StarterService, EggService, StitchService,
               BundleService, ShelfService, CreatureService, IslandService, ChallengeService, FossilService,
               TradeService, CrewService
  client/      -> StarterPlayerScripts.Client  init.client.luau = only LocalScript, starts controllers in order
    Controllers/ InputController, DataController, UIController, PickupController, CreatureController,
                 TutorialController, IslandController, ChallengeController, ShelfController, StarterController,
                 EggController, FossilController, TradeController, PingController
    UI/        Theme, Panel (standard pop-up), PartCard (card + reflowing grid), PartIcon (3D part picture), Hud, InventoryScreen,
               BookScreen, StitchScreen, CreaturePreview (spinning ViewportFrame), BundleScreen, RevealOverlay
  shared/      -> ReplicatedStorage.Shared
    Types.luau   Slot, Rarity, PartStats, PartDefinition
    Remotes.luau the ONLY place remotes are declared; server calls Remotes.createAll() at startup
    Config/      Parts, Rarities, Abilities (riding/glide/updraft tuning), Bundles (price, odds, coin value),
                 Islands (order + gate ability), Challenges, Combos (set bonus, Secret Mashups), Shelf (coins/hour),
                 Starters (the 3 starter monsters), Eggs (tiers, odds, island families), RetiredIds (old ids -> new)
    Daily.luau   UTC day, daily reset, Part of the Day (same for everyone, no storage)
    Water.luau   terrain-water check at the feet, shared by the client and server water gates
    Creatures.luau        loadout rules: parseLoadout (validates untrusted input), summarize, MAX_SAVED
    CreatureAssembler.luau builds a creature Model from PartModels by snapping attachments
  server/RateLimit.luau  per-player remote cooldowns
tools/build_creature_parts.luau  turns AI-generated creatures into ReplicatedStorage.PartModels (model contract)
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
- Studio world (not in git): `ReplicatedStorage.PartModels` (17 block models then; replaced by AI models in World Upgrade W2a),
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
  Part models: 25 block models (replaced by AI models in World Upgrade W2a).
- Known gaps: Glowcap Caves (Light) not built; weekly Secret hint and event parts (later); abilities Dig/Reveal/
  Climb/Carry/Shield still no gameplay; challenge repeat cooldowns reset on rejoin (a few coins at most);
  economy numbers are first guesses (tune after playtests).

**Phase 5: Co-op: PAUSED after 5c** (5a pings/emotes/friend bonus, 5b fossils + Bolt, 5c trading; the 2-player
test of trading/co-op dig/pings is still pending). Left: 5d crews + invite bonus, 5e fusion boss.

**World Upgrade (between Phase 5c and 5d), user decisions:** open world + fast-travel portals (portal stones you
switch on by reaching them the normal way; replace the travel pads), friendly NPCs with quests, Studio AI-generated
3D art, done now before the rest of Phase 5. Milestones: W1 art, W2 connected world + portals, W3 detail pass
(terrain, village, props, lighting), W4 NPCs + quests (save v6).
- W1 DONE: `ReplicatedStorage.Art` (Studio-owned, AI-generated): `Egg` (Top + Bottom MeshParts centered on the
  origin), `Coin` (MeshPart), `BundleMachine` (MeshPart, copy of the look). Textures are SurfaceAppearance ColorMaps
  so `SurfaceAppearance.Color` can tint them (the reveal tints the egg to the rarity color). Part cards show a still
  3D icon (`UI/PartIcon`), pickups show the real part model in a ForceField bubble (client side, PickupController),
  Rare+ pickups glow. The machine's old look is in `ServerStorage.WorldBackup.BundleMachine_OldLook`; the tagged
  `Body` is now invisible and the mesh `Look` sits on the Pad.
- Plan revised after W1 (user decisions, spec 4.8): fantasy remake with 3 moves + a signature move per mashup and a
  body perk, stamina, real-time battles, wild monsters (never on Meadow) + island bosses, starter choice, rare eggs
  that hatch island parts, warp item (boss chance drop, or buy outright; luck boost; Robux later with odds shown and
  PolicyService checks). New order: W2 monsters + starters + eggs, W3 animation/juice, W4 battles, W5 open world +
  portals + mini map, W6 bosses, W7 quest characters; then Phase 5d/5e.
- W2a DONE: six families x 4 slots (Ember, Tide, Thunder = Common starters; Crystal, Glowcap, Moss), all AI-made
  chibi creatures (upright: head, body, 2 arms + 2 legs = the Legs part, back piece). Save v6 converts old part and
  secret ids (`Config/RetiredIds.luau`; Parts/Combos refuse retired ids). Part models come from
  `tools/build_creature_parts.luau`: sources in `ServerStorage.ArtSource.CreatureStaging` (one generated creature per
  family, already normalized), facing found from label votes (override with a "Facing" attribute; check with
  measurements, not screenshots: Ember's turned head and Crystal's side eyes fooled the eye). Limbs snap one by one
  (LegFL/LegFR/LegBL/LegBR, WingL/WingR sockets), so legs always stand at the body's corners. Riders sit on the head
  (or on a shell/hump). Creatures are built at 1.3x part size (CreatureAssembler CREATURE_SCALE). Old block models
  are in `ServerStorage.WorldBackup.OldPartModels`. World spot PartIds were remapped to the new ids.
- W2b DONE then REPLACED by W2d: starter stand `MeadowIsle.StarterStand` (invisible `Pedestal_*` blocks tagged
  `StarterPedestal` with a "Starter" attribute, facing spawn; StarterService adds the Choose prompts, StarterController
  draws the monsters + signs and hides the prompts after you chose). Choosing stitches the starter right away (save v7
  `starterChosen`; records FirstPart + FirstStitch). Tutorial: ChooseStarter -> Ride -> GoToIsland (guide to the first
  locked island your creature can reach; targets are `GuideTarget` parts with an "Island" attribute). Routes from
  Meadow: river -> Lagoon (Swim), `Workspace.ThunderTrail` stone path to the first jump ledge (Super Jump), and
  `Workspace.WindRoute` (Wind Tower updraft on Meadow + WindCloud1/2 updrafts) -> Canyons (Glide). Old starter spots and
  the CollectStarterPart remote are gone (spots in `ServerStorage.WorldBackup`).
- W2d DONE (user feedback on W2b: a pop-up, not 3 ready-made monsters, "less like Pokemon"): new players build
  their first monster in the "Make your first Mashup!" pop-up (`UI/StarterScreen`): each slot flips between the
  Ember/Tide/Thunder parts, live 3D preview, "Can/Goes to" line; it needs at least one travel ability. Server:
  StarterService `CreateStarter` RemoteFunction + `Starters.parse`; save v7 `starterMade` (replaces the never-released
  `starterChosen`). The stand (W2b) is in `ServerStorage.WorldBackup.StarterStand_W2b`. No coins in the home area
  (Meadow coins in WorldBackup). The SpawnLocation is invisible (old look in WorldBackup).
- Next (user decisions): ONE big connected land instead of islands; players spawn in "Stitch Square" (the home
  plaza); walking/riding is free, teleporting needs a game pass (a portal in Stitch Square, locked for players
  without the pass); no "grand portal".
- W3a DONE (logic tested; visual check pending): ONE connected land from Roblox Terrain, made by
  `tools/generate_world.luau` (run in Studio in row batches; tune constants and re-run). Layout: Stitch Square
  (cobblestone plaza, y~21.8 rendered) in the home meadows; north a 52-wide river (Swim) to the Lily Lagoon
  wetlands; east a cliff with 4 jump steps (rises ~11-13, Super Jump only) up to the Cliffside Peaks plateau (~82)
  with snowy mountains and a stream; south a bottomless chasm (Glide: Wind Bluff hill + 2 `ChasmWinds` updrafts) to
  the Windy Canyons desert (floor ~42, mesas ~94, open ring valley); ocean and beaches around. Region ids are the
  old island ids (zones resized: home x -640..252 z -210..210; river and chasm belong to no region). Characters'
  `MaxSlopeAngle` is 50 (IslandService) so steep terrain stays a gate. A failed gate now puts you back at your last
  safe spot. Old island parts are in `ServerStorage.WorldBackup.Islands_v1` (tags stripped). Kept and moved: lab,
  hatchery, shelf (lifted 1.8), fossils, eggs, 36 coins (12 per region, none at home), summit chest (plateau
  ~(290,82,100)), Wind Rings + updrafts (ring valley), `WaySigns` (signs + GuideTargets at the dock, the steps
  and the bluff). Home region shows as "Stitch Square". Terrain colors set; animated grass (Terrain.Decoration)
  must be ticked by hand in Studio.
- W3b DONE: Stitch Square town (`StitchSquare.Town`): monster fountain in the middle (spawn just south of it,
  facing it), lab tower behind the Stitch Station, 8 cottages ring, 2 market stalls, 12 lamp posts, welcome sign,
  stepping-stone paths (terrain dirt paths looked jagged at 4-stud voxels, so paths are grass + slate stones).
- W3c DONE: `tools/scatter_props.luau` plants `Workspace.Nature` (oaks + flower bushes at home, willows + glowing
  mushrooms in the Lagoon, pines on the Peaks, cacti in the Canyons; ~415 props, trees have invisible trunk
  colliders). Prop/town templates (AI-generated) live in `ServerStorage.ArtSource.Props`.
- W3d DONE: storybook lighting (Atmosphere haze, bloom, sun rays, `Storybook` color correction, Terrain clouds),
  sea extended to 2,600 studs, a waterfall where the plateau stream meets the cliff, and `AmbienceController`
  (client: pollen/fireflies/snow/dust around the camera + a color mood per region).
- W3e DONE: portals (`Workspace.Portals`: Stitch Square west side, Lagoon bank, Peaks steps top, Canyons floor;
  the glowing `Gate` part is tagged `Portal` with an Island attribute, `Arrival_*` parts tagged `IslandArrival`).
  Travel needs the Portal Pass game pass (`Config/Monetization.portalPassId`, 0 = not created yet: the pop-up says
  "Coming soon"; Studio test: ServerStorage attribute `DevPortalPass` = true). Server: PassService (ownership,
  PassState), PortalService (PortalOpened, PortalTravel: pass + nearby portal + destination already reached).
  Client: PortalController, round mini map (top-right, coins moved left of it, toasts moved down) and the big
  map (`MapScreen`, view mode from the mini map, travel mode at portals), drawn from `Config/WorldMap` data.
  Travel pads and their code are gone.
- W2c DONE (code; hands-on check pending): loose part pickups removed everywhere (spots in
  `ServerStorage.WorldBackup.OldPickupSpots`); 12 personal eggs (`EggSpots` folders, tag `EggSpot`, attributes Island +
  Tier, Treasure eggs also PartId): per island 2 Plain, 1 Shiny (hard spot), 1 Treasure holding the next island's key
  part (Lagoon: Thunder Legs, Peaks: Ember Wings, Canyons: Tide Tail), so every starter can reach all islands. Server
  rolls from the island's families (EggService, `CollectEgg` RemoteFunction); save v7 `eggSpots` (6 h respawn per
  player). Hatching plays the egg reveal and says which island a new ability opens.
- Studio MCP: take ONE screen_capture at a time (parallel captures hang). Generated meshes need a minute before
  their textures render (grey at first). Name segments with a comma string ("head, body, ...") to get clean names.

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
