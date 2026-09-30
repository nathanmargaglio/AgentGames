# Browser co-op

Debug supports solo play and one host plus one guest. Both players open the browser game from the Game Portal. The host runs the arena; the guest sends movement and swat inputs over a direct Godot WebRTC data channel. There is no account, matchmaking, signaling server, or gameplay server.

Published play uses [GitHub Pages](https://nathanmargaglio.github.io/AgentGames/). Neither player needs to run a local server. Local HTTP/HTTPS serving is only for pre-publication development and testing; stop it afterward. GitHub Pages serves the client files, and the host player's browser runs the shared game simulation.

## Connect two agents

1. The host selects **Host co-op**, chooses a connection mode, and selects **Create invitation**. Wait for the invitation to finish gathering network addresses.
2. Select **Copy invitation link** and send it privately to the guest. The guest opens it. Alternatively, the guest selects **Join co-op**, pastes the invitation code or link, and selects **Use code**.
3. The guest selects **Copy code** and sends their **answer code** back to the host.
4. The host pastes that answer and selects **Use code**. Both screens should show **Connected**.
5. The guest selects **Ready to play** to enable audio. The host selects **Start co-op run**.

### Same network and connection modes

Both players can use the same home/work LAN, including a mix of Wi-Fi and Ethernet. No manual IP, port forwarding, local game server, or router NAT/hairpin setting is normally needed: WebRTC connects to local host addresses. The two computers must be allowed to reach each other.

- **Automatic** is the default and supports both same-network and internet connections. It gathers local addresses plus public addresses using STUN when available.
- **Same network / LAN** gathers only local addresses and uses no public STUN/TURN service. Choose it for a same-network test, especially when public address discovery is blocked or slow. Hosts choose the mode before any discovery begins; the guest inherits it from the invitation without configuring anything.

Changing the mode discards the previous invitation; create and share a fresh one. Retry keeps the chosen mode. Answers for another mode are rejected, so an old answer cannot silently change the host's configuration.

Guest Wi-Fi or access-point/client isolation may keep devices apart even on the same SSID. Use the main Wi-Fi or Ethernet, and check VPN/firewall restrictions or a browser's local-network permission if prompted. A game setting cannot bypass network isolation. Both computers still need internet to load the published game from Pages; LAN gameplay and pairing do not depend on public address discovery. Browser privacy can replace local IPs with `.local` names; those are included in the codes automatically.

Use **Network addresses & connection help** to inspect the addresses gathered by the browser. IPs/ports are bundled in the codes, so there is nothing to type manually. Browsers may substitute `.local` hostnames for private IPs. Invitations use a URL fragment, which is removed after reading and is not sent to the static web server. Codes are specific to that session; create a fresh invitation after a disconnect or retry.

For a first test, use two computers on the same Wi-Fi and open the deployed Game Portal on each. To test an unpublished local build, run `python3 tools/serve.py --lan --port 8765` from the repository root. It generates a temporary local HTTPS certificate and prints LAN URLs containing this computer's IP. Open the same HTTPS LAN URL on both computers and accept the local self-signed certificate warning in each test browser. Godot requires a secure context, so plain HTTP IP-address links cannot run the game. The certificate's private key stays outside the served repository and is deleted on normal shutdown. The static-file server is only needed to load the game, while gameplay still uses WebRTC. Your local firewall must allow that HTTPS port. If clipboard permission is unavailable, select/copy and paste the codes manually instead. Two separate browser windows also work on one computer, but switching focus pauses the team. Keyboard Tab/Enter and Xbox D-pad/stick/A/B navigate the pairing screen; clipboard buttons support controller users when browser clipboard permissions allow it. Manual text exchange can still require the keyboard or another application.

## Shared game loop

Each agent has a visible avatar, separate spawn point, and independent swat cooldown. The host controls player movement limits, bug health, hits, score, round timers, and upgrades. Bugs chase the nearer agent. Co-op has 50% more bugs (nine in round one, capped at 42), with the same timer budget per original solo wave. The HUD shows team score and each player's kills. Clearing the arena opens a shared upgrade screen; the host picks one upgrade for both agents. The host can restart the run for both.

Either player can pause. Focus loss also pauses the team. Each paused player must resume before the clock continues; a host cannot resume a guest who is still paused. A missing guest input heartbeat pauses the host. Disconnecting either browser stops the run with retry/back options, rather than silently turning it into a solo game.

## Network limits

Browsers cannot listen for arbitrary incoming TCP/UDP connections. They exchange WebRTC session descriptions and ICE candidates before connecting. Debug gathers candidates before generating each invitation/answer, allowing private manual exchange without a signaling service. In Automatic mode a public STUN service (`stun:stun.l.google.com:19302`) helps discover addresses and does not carry gameplay. Same network / LAN initializes an empty ICE-server list and uses host candidates exclusively. [Godot WebRTC documentation](https://docs.godotengine.org/en/4.6/tutorials/networking/webrtc.html).

Some NATs, firewalls, and enterprise networks cannot establish a direct connection. Debug reports failure/timeout and offers retry. Try the same Wi-Fi or another network. Reliable support for those networks would require a TURN relay with an approved hosting/budget decision; none is configured. GitHub Pages only delivers static files.

Guest messages cannot set scores, positions, round transitions, or upgrades. The host bounds movement, validates reach/aim/line of sight, and enforces independent cooldowns. Codes and packets have size limits, incoming packets have a rate limit, and outgoing snapshots have a bounded queue. This is a small testing implementation with local guest movement prediction and host correction, without production latency compensation or matchmaking.

## Validation

`npm run test:browser` connects two independent Chromium clients in both Automatic and LAN modes using real invitation/answer codes and WebRTC, then exercises both agents' real movement/swat input, shared upgrades, pause, focus loss, and disconnect/retry. The LAN test rejects any attempt to initialize public discovery servers, verifies host-only candidates on both sides, and checks that the guest inherits the host mode. Headless gameplay checks cover authority, cooldowns, collision, invalid input, timer expiry, and synchronized restart; they simulate the transport because native headless WebRTC needs a separate Godot extension. Physical controllers, other browser engines, and connections across separate real networks still require manual testing.
