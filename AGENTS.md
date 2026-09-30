# AgentGames agent instructions

This repository is an agent-driven browser game playground. Treat `PROMPT.md` as the original product brief. The root is shared; each game is isolated in `games/<slug>/`. Follow the user's current instructions when they differ from this file.

## Tools and iteration

- Use pinned Godot 4.6.1 with GDScript and Compatibility rendering, plus Blender 4.5.3 LTS for original 3D assets. Work headlessly using the CLI or the repository MCP server; see `docs/SETUP.md`.
- Run from the root. Start with `python3 tools/validate.py` and inspect `game.json`, `VERSION`, and `CHANGES.json` for affected games. Use `rg` for file/text searches.
- Keep source, editable Blender libraries, and game-specific asset generators together. Import GLB files in Godot; ignore `art/`, `web/`, `tests/`, and `play/` with `.gdignore`.
- Use `python3 tools/build.py --game <slug>` after changes. Use `--assets` when the Blender generator changes. Never edit exported files directly; change their source, including the custom HTML shell, and rebuild.
- For browser tests use `npm run test:browser`; screenshots go to ignored `artifacts/`. Test actual gameplay rules with headless checks where useful. Do not mistake a successful Godot process exit for clean import/parse output.
- Feature branches and Git worktrees are welcome for experiments. Ask for parallel agents only when the user wants delegation; do not spawn them by default.

## Game defaults

- Publish to the browser. Use Web export preset `Web`, disable threads and extensions, and keep relative links working under `/AgentGames/`. GitHub Pages cannot supply custom isolation headers.
- Support mouse/keyboard and an Xbox controller in gameplay and all menus unless the user explicitly makes an exception. Keep focus indicators and readable UI. Pause round timers when paused or focus is lost. Start audio after a player gesture.
- Every game has `game.json`, `VERSION`, and a newest-first `CHANGES.json`. Show game versions and histories in the portal, not in game UI. The portal reads generated `web/catalog.json`.
- Default future multiplayer to a small authoritative host with WebRTC and manual invitation/answer exchange. Read `docs/MULTIPLAYER.md`; direct peer connectivity is not guaranteed behind every NAT. Do not provision signaling, game servers, or relays without a concrete approved need.

## Assets and spending

- Use existing subscription image tools when an original raster asset is useful. Use Blender for 3D and code for simple UI/vector/procedural assets. Do not spend on assets you can reasonably author locally.
- OpenRouter's owner budget is $10/month. For light placeholders, use opt-in generation scripts and record prompts, model, filenames, generation IDs, and cost in `tools/asset-spend.json` and game asset notes. The initial generator uses a conservative $1/month local cap. Substantial generation requires a plan and explicit owner approval to increase the budget.
- Never run paid generation during normal setup, build, test, or release. Keep `.env` local; no keys in Godot resources, logs, browser bundles, or commits. Reuse committed generated assets.

## Versions and publishing

- Every published AgentGames change, including documentation/shared tooling, needs an appropriate semver bump and a `CHANGES.json` entry with version, timezone-qualified datetime, and short description. Changed games also need independent bumps/history entries.
- From `main`, use `python3 tools/release.py --bump patch --game debug:patch --message "Describe the change" --push`, adjusting bump kinds and games. The release helper rebuilds, validates, tests, commits, tags, and pushes atomically. Include only intentional project work; it stages all nonignored files.
- Rebuild every changed game BEFORE pushing. Commit complete exports in `games/<slug>/play/`; no GitHub compilation. The root portal is `index.html`, and Pages serves `main` at `/`.
- Push annotated `v<AgentGames version>` and `<game>/v<game version>` tags alongside releases. Never move published tags or force push. The local `tools/hooks/pre-push` gate catches stale builds and missing bumps/tags; keep it enabled.
- Initialization is version `0.1.0` for AgentGames and Debug. Unpublished iteration can share the pending release version. Once released, use a new version for the next publication.
- Check `git diff` and build/test results before release. After pushing, verify the Pages deployment and live portal version. Report the URL, versions/tags, validation, spend, and any material limitations. Publishing is authorized when the user asks to deploy/push; avoid repeated permission requests.
