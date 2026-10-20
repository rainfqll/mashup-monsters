# How to get the code into Roblox Studio

You do this once per computer. After that, steps 5 to 7 are how you start every work session.

## How the pieces fit

- **Code** lives in this folder (and on GitHub). You edit it in VS Code or let Claude Code edit it.
- **Rojo** copies the code into Studio live while you work.
- **The world** (islands, Stitch Station, decorations) is built inside Studio and saved in your place.
  Rojo only touches the three code folders listed at the bottom, so it never overwrites your building.

## One-time setup

1. **Install the programs**
   - [Roblox Studio](https://create.roblox.com/)
   - [Git](https://git-scm.com/downloads)
   - [VS Code](https://code.visualstudio.com/) (optional but recommended; when you open this folder it
     offers to install the Luau, Selene, StyLua and Rojo extensions, so click **Install All**)
   - [Rokit](https://github.com/rojo-rbx/rokit), the tool installer. Follow the install steps in
     its README, then close and reopen your terminal.

2. **Get the code**
   ```
   git clone https://github.com/<your-name>/mashup-monsters.git
   cd mashup-monsters
   ```

3. **Install the pinned tools** (Rojo, Wally, Selene, StyLua) from inside the folder:
   ```
   rokit install
   ```
   If it asks whether to trust a tool, answer yes.

4. **Install the Rojo plugin into Studio** (close Studio first):
   ```
   rojo plugin install
   ```

## Every work session

5. **Open your place in Studio.** The first time, create a new **Baseplate**, then use
   **File > Publish to Roblox** and name it *Mashup Monsters*. Publishing gives the place a cloud home,
   with version history as its backup.

6. **Start Rojo** in a terminal inside the project folder and leave it running:
   ```
   rojo serve
   ```

7. **Connect.** In Studio, open the **Plugins** tab, click **Rojo**, then click **Connect**.
   It should say *Connected*.

## Phase 0 check

8. Open the Output window: **View > Output**.
9. Press **Play** (or F5).
10. You should see these two lines and no red text:
    ```
    [Mashup Monsters] server ready (6 services started)
    [Mashup Monsters] client ready (4 controllers started)
    ```
11. Press **Stop**.

Tell Claude what you saw. If anything is red, copy the red lines and paste them in.

## Letting Claude Code work inside Studio (recommended)

Run Claude Code on the same computer as Studio, then:

1. In Studio, open the **Assistant**, click **...** and choose **Manage MCP Servers**.
2. Turn on **Enable Studio as MCP server**. The quick-connect list there includes Claude Code.
3. Start Claude Code in this project folder. It reads `CLAUDE.md` and `docs/GAME_DESIGN.md`
   automatically.

## Where the code appears in Studio

| On disk       | In Studio                                      |
|---------------|------------------------------------------------|
| `src/server/` | ServerScriptService > Server (Script)           |
| `src/client/` | StarterPlayer > StarterPlayerScripts > Client   |
| `src/shared/` | ReplicatedStorage > Shared                      |

Don't edit these three in Studio. Rojo would replace those changes with the files on disk.
Everything else in Studio (Workspace, Lighting, your models) is yours to edit freely.
