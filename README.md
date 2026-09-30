# AgentGames

Small browser games built and iterated by agents, using Godot and Blender.

**[Play the games](https://nathanmargaglio.github.io/AgentGames/)** · [Agent workflow](AGENTS.md) · [Setup](docs/SETUP.md)

The root is shared tooling and the Game Portal. Each game lives in `games/<slug>/`, with its Godot source, editable Blender assets, metadata, history, and committed browser export in `play/`.

```sh
python3 tools/setup.py          # pinned local tools, dependencies, and release hook
python3 tools/build.py --all    # rebuild changed games and refresh the portal catalog
python3 tools/test.py           # headless gameplay + build checks
npm run test:browser            # Chromium/WebGL, Xbox controls, and two-client co-op
python3 tools/serve.py --port 8765
# Add --lan for local HTTPS + IP links to test with a second computer.
```

Open `http://localhost:8765/AgentGames/`. Debug is a solo or two-player co-op first-person swatter: clear timed bug waves, select upgrades, and chase your best score. For co-op, host a session, share the invitation link, paste the guest’s answer, then start together. Use WASD/mouse/click or Xbox sticks/RT; Esc/Start pauses.

Finished updates are published to GitHub Pages by default unless the user asks to keep them local. Every published update bumps AgentGames, and changed games receive their own version bumps. Histories and versions appear in the portal. Builds happen locally **before** committing and pushing; GitHub Pages serves `main` at `/` without a game build action. Local servers are only development/test tools; published co-op uses a direct connection between the two browsers.

```sh
python3 tools/release.py --bump patch --game debug:patch \
  --message "Describe the change" --push
```

See [releases and new games](docs/WORKFLOW.md), [MCP tools](docs/SETUP.md#mcp), [multiplayer defaults](docs/MULTIPLAYER.md), and [asset provenance](games/debug/ASSETS.md). OpenRouter generation is opt-in; normal builds and gameplay use no API key or paid service.
