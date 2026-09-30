# Games and releases

## Iteration

Work on feature branches or isolated Git worktrees. Keep each game's source and authored assets inside `games/<slug>/`; shared scripts, documentation, and portal assets belong at the root. Rebuild with `python3 tools/build.py --game <slug>` and serve the repository over HTTP. Opening exported HTML directly with `file://` does not work.

A build imports Godot resources, exports to a temporary directory, installs the finished files in `games/<slug>/play/`, and records source and output hashes in `build.json`. Unchanged games are skipped. Blender assets regenerate when their generator changes. Use `--force` to export anyway or `--assets` to regenerate the game's Blender assets. Build tools and toolchain pins participate in source fingerprints. `.godot/`, paid generation intermediates, and testing artifacts stay local.

Each game's `game.json` provides its ID, version, name, description, genre, player count, supported controls, cover, history path, and browser entry. The generated `web/catalog.json` exposes this metadata to the portal. Each game also has `VERSION` and newest-first `CHANGES.json`; entries contain `version`, timezone-qualified `datetime`, and `description`.

## Publish

Before publishing, finish the implementation and merge it locally into `main`. Run from the root:

```sh
# A shared portal/documentation update:
python3 tools/release.py --bump patch --message "Improve portal navigation" --push

# A game update, which also bumps AgentGames:
python3 tools/release.py --bump minor --game debug:minor \
  --message "Add a new bug type" --push
```

Repeat `--game slug:kind` for multiple updated games. Semver bumps are `patch` for fixes, `minor` for new compatible features, and `major` for breaking changes; versions below 1.0 indicate experiments. The command updates versions and histories, builds changed games, refreshes the catalog, checks all build hashes, runs headless and browser tests, commits all nonignored project changes, creates annotated tags, and optionally pushes `main` plus those tags atomically. Omit `--push` to prepare a local tagged release.

AgentGames tags are `v0.1.0`; game tags are `debug/v0.1.0`. A shared release always has a new AgentGames tag. Changed games have new game tags. Never move a published tag. If the push fails after local preparation, fix the cause, then push the already-created commit and tags together; do not rerun the bump blindly.

The pre-push hook validates `main`, blocks stale builds and unchanged versions, and requires current tags in the same push. Branches remain free for iteration. Install hooks with setup or `git config core.hooksPath tools/hooks`. Git hooks are local guardrails, not repository enforcement against someone explicitly bypassing them.

GitHub Pages serves `main` from the root. All browser exports are committed with their source; no compilation runs on GitHub. `.nojekyll` preserves exported assets. After publishing, check the Pages deployment and open the site to verify the live version. Browser tests can run against it with:

```sh
AGENTGAMES_TEST_URL=https://nathanmargaglio.github.io/AgentGames/ npm run test:browser
```

## Add or branch a game

Create `games/<slug>/` with a Godot `project.godot`, scene/script sources, web export preset named `Web`, `game.json`, `VERSION`, and `CHANGES.json`. Start new games at `0.1.0` and supply a cover. A fork should have a new slug, name, and independent version history. Avoid sharing mutable assets across game folders unless deliberately moving them into shared tooling.

Use Debug as the starting example. Add `.gdignore` to `art/`, `web/`, `tests/`, and `play/` so Godot does not recursively import source libraries or its own web exports. Exclude those paths and the portal cover in the export preset. Keep web thread support disabled and use Compatibility rendering. Include `tests/smoke.gd` for gameplay rules where useful, and extend browser tests for the new game's flow.

Support mouse/keyboard and an Xbox controller in gameplay **and menus**. Pause timers when the game is paused or loses focus. Require a player gesture to start audio. Keep game versions in the portal, not inside the game UI. Record generated-asset provenance and spend. Follow `docs/MULTIPLAYER.md` for browser networking.

Rebuild and release with an AgentGames bump and `--game <slug>:initial`, which keeps the new game at its initial version and creates its first tag. For an existing game use `patch`, `minor`, or `major`. Initializing a whole empty repository is the sole use of `--initial`.
