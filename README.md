# AgentGames

Small browser games built and iterated by agents, using Godot and Blender.

**[Play the games](https://nathanmargaglio.github.io/AgentGames/)** · [Agent workflow](AGENTS.md) · [Setup](docs/SETUP.md)

The root is shared tooling and the Game Portal. Each game lives in `games/<slug>/`, with its Godot source, editable Blender assets, metadata, history, and committed browser export in `play/`.

```sh
python3 tools/setup.py          # pinned local tools, dependencies, and release hook
python3 tools/build.py --all    # rebuild changed games and refresh the portal catalog
python3 tools/test.py           # headless gameplay + build checks
npm run test:browser            # actual Chromium/WebGL + emulated Xbox controls
python3 tools/serve.py --port 8765
```

Open `http://localhost:8765/AgentGames/`. Debug is a solo first-person swatter: clear timed bug waves, select an upgrade, and chase your local best score. Use WASD/mouse/click or Xbox sticks/RT; Esc/Start pauses.

Every published update bumps AgentGames, and changed games receive their own version bumps. Histories and versions appear in the portal. Builds happen locally **before** committing and pushing; GitHub Pages serves `main` at `/` without a game build action.

```sh
python3 tools/release.py --bump patch --game debug:patch \
  --message "Describe the change" --push
```

See [releases and new games](docs/WORKFLOW.md), [MCP tools](docs/SETUP.md#mcp), [multiplayer defaults](docs/MULTIPLAYER.md), and [asset provenance](games/debug/ASSETS.md). OpenRouter generation is opt-in; normal builds and gameplay use no API key or paid service.
