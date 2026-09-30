# AgentGames

This project is called "AgentGames". It's a general project for implementing various games through a single entrypoint. The goal is to allow us to create games and iterate on them, branch from them, etc., in an easy and efficient way. The main workflow will be to have agents running on this machine (e.g., Codex, Claude, etc.) building everything.

# Technologies

We will focus on developing games on this machine in a headless manner. We should set up our development process/pipeline accordingly. I expect us to leverage agent tools (such as MCPs) for most of this work.

We will focus on leveraging Godot with Blender. We're using Godot since it is one of the best game frameworks for agents. Similarly for Blender. You should set this up on this machine and make sure you can use these tools effectively. For now, we will focus on publishing games only to the browser which will run in a GitHub Page. Every game should be compatible with both mouse and keyboard and an Xbox controller unless otherwise noted.

I expect many of our games to include online multiplayer. By default, this should be minimal. I don't want to run a server if we can avoid it. Players should be able to connect directly to each other (i.e., one hosts, etc.). We won't need a server for game discoverablity, etc., to start.

I've given you an OpenRouter API key in .env which can be used for anything in OpenRouter that you deem appropriate. The expectation is that you will use this to generate content when warranted. I've only given you a $10 per month budget, so use it wisely. My expectation is that you will use this mostly to generate very light/minimal placeholders that you can't generate yourself. For example, you may use OpenRouter to generate sound effects, music, speech, or maybe even videos. If you need to generate something substantial, you should explicitly tell me with a plan so that I can approve and raise your budget. You should always try to use your existing subscription to generate content first (i.e., if you're Codex, then you should be able to generate images if needed, etc.). Additionally, I expect you to leverage Blender for 3D assets.

We will deploy our games through GitHub Pages. We will build everything locally and push those builds in their entirety to GitHub. We will deal with large filesizes and related issues later. So the expectation is that everytime we push changes to GitHub, the Pages are updated so that I can see the new versions online.

# Workflow

The root of this directory will be the "shared" space which will hold agent instructions, common tools, etc. for the rest of the projects. The actual games should exist in a directory named `games` such that each subdirectory of that directory corresponds to a single game, e.g., `games/cat-game` is where a game named "Cat Game" might be located. The root of the project should have an `index.html` which provides a simple interface for linking to the other games (the Game Portal). This should be a nice, but minimal, interface for seeing the available games as well as some light metadata for the games. Clicking on a game in the portal should navigate to the game itself.

AgentGames, itself, should use semver. Any change to AgentGames should bump the version accordingly. The version of AgentGames should be shown in the corner of the main Game Portal so that I can easily understand what version I'm looking at. Additionally, we should maintain a `CHANGES.json` file which you will update every time there's a version bump. Every entry should include the version, datetime of the change, and a small description of the change. There should be a section of the Game Portal which provides a paginated view of these changes. Each game, itself, should also be similarly versioned. The version and changes for each game should be exposed in the Game Portal (not the games themselves). Every push to GitHub should also push a tag with the version.

Whenever we're pushing a versioned update, we should rebuild any games which have been updated. This should happen BEFORE we push to GitHub since GitHub pages will host those builds directly out of GitHub.

# Initialization

To start, I need you to initialize this project. This should include creating the README.md with appropriate (but minimal) information about the project, an AGENTS.md file for providing instructions to agents, setting up the local environment and tooling (installing Godot, Blender, etc.) and making sure that set up process is documented, and creating the initial Game Portal.

As part of this, I want you to create a very simple game named "Debug" which utilizes this entire workflow. It should have simple models made in Blender, the game should be built in Godot, and it should use some assets from OpenRouter (specifically for sound effects and music). The game, itself, should be a simple first-person shooter (or really swatter) where you're running around swatting bugs. The game should take place in a server and you're playing as an agent. The game should include a simple score system, upgrades, etc. It is round based where bugs get harder to kill as you go. Failure to kill all bugs in a round causes the game to end.

When this is complete, I expect you to push this to GitHub such that it deploys to GitHub Pages. I have GitHub pages configured to deploy from "/ (root)" for the "main" branch, so that should happen automatically.