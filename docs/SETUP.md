# Local setup

Tested on Ubuntu 24.04 x86-64. The project pins Godot 4.6.1, its matching web export templates, and Blender 4.5.3 LTS in `tools/toolchain.json`. Archive SHA-256 hashes are recorded there and checked during setup. Tools install in `~/.local/share/agentgames`; symlinks go in `~/.local/bin`. No sudo is required on this machine.

Prerequisites: Python 3.12+, Node.js/npm, Git, curl, ffmpeg, and uv. These were already available on the initialization machine. On a fresh Ubuntu installation:

```sh
sudo apt-get update
sudo apt-get install -y python3 curl git ffmpeg unzip xz-utils libx11-6 libxi6 \
  libxrender1 libxxf86vm1 libxkbcommon0 libgl1 libegl1 libnss3 libatk1.0-0 \
  libatk-bridge2.0-0 libatspi2.0-0 libdrm2 libgbm1 libasound2t64 \
  libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libcups2
```

Install Node.js and uv using their official installers if missing. Then, from the repository root:

```sh
python3 tools/setup.py
export PATH="$HOME/.local/bin:$PATH"
python3 tools/build.py --all
python3 tools/test.py
npm run test:browser
python3 tools/serve.py --port 8765
```

Setup installs npm dependencies from `package-lock.json`, MCP dependencies from `uv.lock`, the pinned Chromium archive, and `core.hooksPath=tools/hooks`. The Python Chromium installer avoids a download/extraction hang observed with Playwright's installer under Node 26. Browser tests use the full Chromium executable with software WebGL; no display or GPU is required. Screenshots stay in ignored `artifacts/`.

`GODOT_BIN` and `BLENDER_BIN` can override tool paths. On other operating systems, install the pinned versions manually, install matching export templates, use `npm ci`, `npx playwright install chromium --no-shell`, and `uv sync --frozen`, then configure the hooks. The automated binary installer supports Linux x86-64.

## Headless authoring

```sh
godot --headless --path games/debug --editor --import
blender --background --python games/debug/art/generate.py
python3 tools/build.py --game debug --assets
```

Blender creates the native `art/models.blend`, optimized GLB models, and the portal cover. Godot imports GLB rather than `.blend`, keeping exports independent of Blender import subprocesses. Godot uses GDScript, Compatibility rendering, and a single-threaded Web preset, which works on GitHub Pages without cross-origin isolation headers. [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## MCP

A local stdio server wraps the same tools: `list_games`, `build_game`, `validate_project`, `test_games`, and `inspect_toolchain`, plus the `agentgames://workflow` resource. It cannot push or generate paid assets. Its build call can regenerate Blender assets when requested.

```sh
uv run python tools/mcp_server.py
uv run python tools/test_mcp.py
```

Launch your agent from the repository root. Claude Code can use `.mcp.json`; Codex has project-local `.codex/config.toml`. Codex loads project MCP configuration for trusted projects; reconnect/restart the client after initial setup. [Official Codex MCP configuration](https://developers.openai.com/codex/mcp/). These files configure this repository's server without changing global agent settings.

The CLI commands remain available to any agent with shell tools, even when its client does not expose a local MCP server.

## OpenRouter

Copy `.env.example` to `.env` and set `OPENROUTER_API_KEY` only when generating assets. Never add it to a Godot project or web code.

```sh
python3 tools/generate_audio.py music
python3 tools/generate_audio.py effects
```

These are explicit paid calls, separate from setup/build/release. The generator reserves $0.04 per request in `tools/asset-spend.json`, enforces a conservative $1/month local cap, and checks account monthly usage against the owner's $10/month budget. Reservations remain after a failed or interrupted request. Account limits should also remain enabled in OpenRouter because other tools can spend outside this ledger. Substantial generation requires an approved plan and budget increase.

The initial clips cost $0.08 in total according to response usage records. Provider prices and availability can change; check them before changing the generator or model. [Lyria clip pricing](https://openrouter.ai/google/lyria-3-clip-preview) · [Audio API](https://openrouter.ai/docs/guides/overview/multimodal/audio).
