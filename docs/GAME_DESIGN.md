# Mashup Monsters: Game Design and Kickoff Spec

> This is the original kickoff prompt, saved so future sessions can re-read it.
> It is the source of truth for scope. Update it only when we agree on a change.

You are my lead Roblox engineer. We are building a Roblox game called Mashup Monsters from scratch. I am new to Roblox development, so explain decisions briefly in plain language, work in small milestones, and stop for my review at the end of each phase. Do not try to build the whole game at once.

## 1. First steps (before writing any game code)

1. Save this entire prompt to `docs/GAME_DESIGN.md` so you can re-read it in future sessions.
2. Create a `CLAUDE.md` at the project root that summarizes: the game concept, the tech stack, the folder structure, the coding rules in section 6, and the current phase. Keep it updated as we go.
3. Install the Roblox skills from roblox-brain and use them throughout: `npx skills add TabooHarmony/roblox-brain`. At minimum, use these when relevant: `roblox-gui`, `roblox-architecture`, `roblox-networking`, `roblox-security`, `roblox-data`, `roblox-luau-types`, `roblox-game-design`.
4. Check whether the Roblox Studio MCP server is connected (tools like `execute_luau`, `screen_capture`, `start_stop_play`, `get_console_output`). If it is, use it to build and test inside Studio. If it is not, tell me and continue with code on disk.
5. Propose the project setup (section 5) and wait for my OK before creating files beyond `docs/` and `CLAUDE.md`.
6. Initialize git and commit after every working milestone with a clear message.

## 2. The game in one sentence

Explore colorful floating islands, collect weird creature parts (duck heads, frog legs, bat wings, jellyfish tails), stitch them together in your lab to build your own mashup monster, and use its abilities to reach new islands and find rarer parts, alone or with friends.

## 3. Target audience and hard requirements

- **All ages**, especially kids 6 to 14. The game must qualify for a Minimal (or at most Mild) content maturity label: no realistic violence or blood, no scary content, no crude humor, no gambling visuals (no slot machines, roulette, casino theming). (Art style: semi-realistic since the Realism Upgrade, see 4.9; friendly, never scary.)
- **Mobile first.** Most players are on phones. Every screen must work on a small landscape phone, then tablet, PC, and controller.
- **Works without chat.** Young players often cannot chat. Co-op must work through pings, emotes, and obvious visual cues.
- **Solo complete, co-op better.** A solo player can do everything. Friends make it faster, funnier, and unlock extra rewards.
- **Original IP only.** No Roblox logos or branding, no copyrighted characters, no free-model scripts from the Toolbox.
- **Built for Roblox's discovery algorithm**, which rewards long-term retention (D1, D2 to D7, D8 to D28), play-through rate, low first-play bounce, and intentional co-play days (friends returning together). Design decisions should support those.

## 4. Game design spec

### 4.1 Core loop (one session = 10 to 25 minutes)

1. **Explore** an island and collect creature parts (glowing pickups, hidden spots, small challenges).
2. **Open mystery bundles** (bought with in-game coins, found in the world) for a random part with a rarity reveal.
3. **Stitch** parts at the Stitch Station in your lab: pick one part per slot, pull the lever, a new creature is born.
4. **Use abilities.** The parts decide what your creature can do. Abilities unlock new paths and islands.
5. **Earn coins** from exploring and from creatures displayed in your lab, then upgrade and repeat.

### 4.2 Creature system (the heart of the game)

- 4 slots: `Head`, `Body`, `Legs`, `Back` (wings, tails, fins, shells).
- Each part has: `id`, `displayName`, `slot`, `rarity`, `ability` (optional), `stats` (speed, jump, swim, glide, carry), `modelName`, `colorTheme`.
- Abilities come from parts. Examples:
  - Legs: Frog Legs = super jump, Cheetah Legs = speed boost, Duck Feet = swim
  - Back: Bat Wings = glide, Jellyfish Tail = swim + glow, Turtle Shell = shield
  - Head: Mole Nose = dig up buried parts, Owl Head = reveals hidden parts, Firefly Head = light in dark caves
  - Body: Bear Body = carry heavy objects, Snail Body = sticky climbing
- Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret. Each rarity has a color and a reveal effect.
- **Set bonuses:** 2+ parts from the same animal give a small stat bonus. Specific secret combos create a named "Secret Mashup" with a special effect (this drives discovery and social sharing).
- **Modular models:** every part model has standard Attachments (`NeckAttach`, `HipAttach`, `BackAttach`, `RootAttach`) so ANY combination snaps together cleanly. For the prototype, build parts from simple Roblox primitives (blocky, colorful, cute). Real art from Blender replaces them later without code changes.
- Creatures follow the player as a companion. The player can ride their active creature to use movement abilities.
- **Collection:** a creature book (discovered parts and combos) and a lab display shelf. Displayed creatures earn coins over time (capped, so players come back).

### 4.3 World and progression

- **Hub:** Your Lab on a starter island (Stitch Station, display shelf, bundle machine).
- Islands gated by abilities, so progress feels earned:
  1. Meadow Isle (starter, no ability needed)
  2. Lily Lagoon (needs swim)
  3. Cliffside Peaks (needs super jump)
  4. Windy Canyons (needs glide)
  5. Glowcap Caves (needs light)
- Each island has its own part pool, a few hidden spots, and one small puzzle or challenge.

### 4.4 Co-op features (solo players are never blocked)

- **Shared lab:** friends can join a crew and use one lab together. Crew progress advances when 2+ members play together.
- **Team pickups:** giant fossil parts (rare and better) need 2 players to dig out. Solo players can use an NPC lab assistant who does it slower.
- **Combo creatures:** two players can fuse their active creatures into a temporary Giant Mashup for boss events.
- **Trading:** safe two-sided trade window (both confirm, server validates everything).
- **Friend bonus:** +loot per friend in the server. Inviter and invited both get a starter bonus after the new player's first creature.
- **Communication without chat:** one-tap pings (Here!, Help!, Look!), emotes, and visual markers.

### 4.5 Retention hooks

- **Daily:** a free daily bundle, a "Part of the Day" with boosted drop rate, and display shelf coins to collect.
- **Weekly:** limited-time event parts and a weekly Secret Mashup hint.
- **Long term:** complete the creature book, unlock all islands, collect every Secret Mashup.

### 4.6 First-time experience (critical for the algorithm)

- New players must stitch their first creature within 3 minutes, with almost no reading.
- Guided steps with arrows and icons: grab 3 glowing parts nearby, walk to the Stitch Station, pull the lever, watch the reveal, ride your creature off the first ledge.
- No popups or shop prompts in the first session before the first creature is made.

### 4.7 Monetization (later phase, not in the prototype)

- Cosmetics (creature colors, lab decorations, stitch effects), a season pass, and convenience items that do not make the game pay-to-win.
- Mystery bundles use in-game coins only in the prototype. Before adding any Robux-purchased random items, check Roblox's current policy for paid random items and our maturity label, and tell me what it requires.

### 4.8 World Upgrade (agreed October 2026, after Phase 5c; overrides older notes where they differ)

- **Look and feel:** much flashier and more detailed than the prototype: AI-generated 3D art (Studio), animated
  creatures (walk, flap, wag, squash and stretch), VFX and sound on every action, terrain-based islands, lighting.
- **Open world:** islands form one connected world. Teleport pads become **portals**; a portal switches on when you
  first reach it the normal way. A **mini map** shows islands, portals, you and friends.
- **Monsters (fantasy remake):** the farm animals are replaced by original fantasy creature families. Parts players
  already own convert to the matching new part. Each creature has **3 moves from its parts** (head, legs, back) plus a
  **signature move that depends on the mix**, and the **body gives a passive perk**. Moves cost **stamina**.
- **Battles:** real-time action. You ride your creature, move, and tap move buttons; bosses telegraph big attacks
  to dodge. Cartoon only (sparkles, bonks, splashes; enemies get "tired" and poof into stars): stays Minimal/Mild.
- **Wild monsters** roam the outer islands (never on Meadow Isle) and guard eggs; each island has a **boss**.
- **Start:** players pick one of a few **starter monsters** at a stand on Meadow Isle. No loose parts lying around.
- **Eggs** are rare finds (hidden spots, wild monsters, bosses, coin bundles) and hatch a **part from that island's
  creatures**. Rarer egg, better part.
- **Warp item** (teleport to any switched-on portal from anywhere): a rare **chance drop from bosses**; it can also
  be bought **directly** (no chance) for Robux or for a very high coin price. A **3x luck** boost raises drop chances.
  Policy: any Robux purchase that changes a random outcome (the luck boost) counts as a paid random item: show the
  exact odds before buying and hide it where PolicyService says paid random items are restricted. No gambling
  visuals. Robux products come with the monetization work (spec 4.7), after the gameplay is fun.

### 4.9 Realism Upgrade (agreed October 2026; overrides "cute/storybook" look notes)

- **Semi-realistic look** for the world, the monsters and the menus: natural colors and light, real-looking
  textures, detailed models, lots of nature detail (like the top Roblox adventure/creature games), still
  friendly and never scary. Must keep running well on phones (instanced props, streaming, sensible detail).
- **Menus:** an adventure-game style instead of bubbly: darker panels, thin gold edges, smaller corners,
  cleaner fonts. Big touch targets stay.
- **Monsters:** remade in a semi-realistic creature style that matches the world; mix-and-match works the same.
- **Day/night cycle** (about 20 minutes per day, nights bright enough to play) and **weather** per region
  (rain, fog, snow on the peaks, dust in the canyons).

## 5. Technical setup (propose, then wait for my OK)

- Code on disk with Rojo so code lives in git and syncs into Studio. Use Rokit (or Aftman) to install tools: `rojo`, `selene` (linter), `stylua` (formatter), `luau-lsp`.
- Luau with types: `--!strict` on every script where practical.
- Data: ProfileStore (or an equivalent session-locked wrapper) for player data, with a versioned schema and migrations.
- Suggested folder structure (adjust if you have a better one and explain why):

```
src/
  server/            -- Scripts and server-only modules
    Services/        -- PlayerDataService, PartService, StitchService, CreatureService, TradeService, CrewService
  client/            -- LocalScripts and client modules
    Controllers/     -- UIController, CreatureController, InputController, PingController
    UI/              -- UI components
  shared/            -- ModuleScripts used by both
    Config/          -- Parts.lua, Rarities.lua, Abilities.lua, Islands.lua, Combos.lua
    Types.lua
    Remotes.lua      -- one place that defines every RemoteEvent/RemoteFunction
docs/
```

- All game content is data-driven. Adding a new part should mean adding one entry to `Parts.lua` plus a model, not writing new code.

## 6. Coding rules (always follow)

1. **Server authority.** The client only asks; the server decides. The server validates every remote call (types, ranges, ownership, distance, cooldowns) and rate-limits remotes. Never trust the client for coins, parts, rarity rolls, trades, or abilities.
2. **Random rolls happen on the server only.**
3. **Saving is safe:** retries with backoff, session locking, save on leave and on server shutdown (`BindToClose`), never lose items in a failed trade.
4. **No deprecated APIs.** If unsure, check the Roblox docs (use the Studio MCP docs-search skill if available).
5. **Clean up connections** when players leave, UIs close, or creatures despawn. No memory leaks.
6. **Performance:** pool frequently spawned objects, stream large worlds, keep part pickups lightweight, test on low-end mobile settings.
7. **UI rules** (follow the `roblox-gui` skill): mobile first, keep the top bar, joystick, and jump button areas clear, use scale-based sizing with constraints, big touch targets, icons over text, controller focus support, chunky rounded style with thick dark outlines, lime green and purple brand colors.
8. **Make actions feel good:** button press tweens and sounds, a shake-glow-burst reveal for bundles colored by rarity, particles on stitching.
9. **Analytics:** log custom events for each funnel step (joined, first part, first stitch, first ride, first new island, first co-op action) so we can find where players drop off.
10. **Small, readable modules** with comments that explain why, not what.

## 7. Build phases (stop and report after each one)

For every phase: build it, playtest it in Studio (use `start_stop_play`, `screen_capture`, and `get_console_output` if the Studio MCP is connected), fix errors, commit, then give me a short report: what works, what to test myself, known issues, and what is next.

### Phase 0: Setup
- Project structure, Rojo sync, tooling, git, `CLAUDE.md`, empty services that start without errors.
- **Done when:** I can open Studio, sync, press Play, and see no errors.

### Phase 1: Parts and inventory
- `Parts.lua` with ~16 starter parts (4 per slot) across Common to Epic, built from primitives.
- Part pickups placed on Meadow Isle; picking one up adds it to inventory (server-validated).
- Player data saves and loads inventory and coins.
- Simple inventory UI (grid of parts, filter by slot, rarity colors).
- **Done when:** I can collect parts, leave, rejoin, and still have them.

### Phase 2: Stitch Station and creatures
- Stitch Station with 4 slot buttons, a preview, and a lever.
- Server builds the creature from parts using attachments; it spawns and follows the player.
- Riding the creature; movement abilities (jump, swim, glide, speed) work while riding.
- Creature book records discovered parts.
- **Done when:** any combination of parts produces a working creature with the right abilities, on phone and PC.

### Phase 3: First-time experience and the starter islands
- Guided tutorial (section 4.6), timed to under 3 minutes.
- Meadow Isle and Lily Lagoon with an ability gate between them, hidden spots, coin pickups.
- Mystery bundle machine (coins) with the rarity reveal animation.
- **Done when:** a brand-new player gets from spawn to riding their first creature in under 3 minutes without reading instructions.

### Phase 4: Progression
- Cliffside Peaks and Windy Canyons, set bonuses, the first Secret Mashup combos, display shelf coins (capped), daily bundle and Part of the Day.
- **Done when:** there is a clear 1 to 2 hour progression path and reasons to come back tomorrow.

### Phase 5: Co-op
- Crew system with shared lab, team pickups plus the solo NPC assistant, friend loot bonus, invite bonus, pings and emotes, safe trading.
- Combo creature fusion for a first simple boss event (cartoon, not scary).
- **Done when:** 2 players can join, share a lab, dig a giant fossil together, trade safely, and a solo player can still do everything.

### Phase 6: Polish and launch prep
- Test every screen in the Device Simulator (small phone, tablet, PC, controller).
- Performance pass on low-end mobile.
- Sound, music, particles, and juice pass.
- Analytics events verified.
- A checklist for the Maturity & Compliance Questionnaire answers (expected: Minimal).
- **Done when:** the game is ready for a soft launch.

## 8. How to work with me

- Start with Phase 0. Before writing code, show me a short plan for the phase and any decisions I need to make (use multiple choice questions where possible).
- If something in this spec is a bad idea technically or for players, tell me and suggest a better option.
- Keep reports short and in plain language. Tell me exactly what to click or test in Studio.
- Never delete or overwrite my work in Studio without asking first, and commit before any large change.
