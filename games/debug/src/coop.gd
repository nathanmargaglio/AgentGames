extends Node
# One browser host, one guest. Pairing codes contain SDP + fully gathered ICE.
signal connected
signal disconnected(reason: String)
signal packet(data: Dictionary)
signal pairing_changed

const MAX_CODE := 32768
const MAX_PACKET := 24000
var role: String = "solo"
var network_mode: String = "auto"
var failed: bool = false
var peer: WebRTCPeerConnection
var channel: WebRTCDataChannel
var online: bool = false
var code: String = ""
var addresses: String = "Gathering network addresses…"
var notice: String = ""
var description: Dictionary = {}
var candidates: Array = []
var age: float = 0
var connecting_age: float = 0
var remote_applied: bool = false
var rate_time: float = 0
var packets_this_second: int = 0

func begin(kind: String, network: String = "auto") -> void:
	close()
	role = kind
	network_mode = network if network in ["auto","lan"] else "auto"
	if not OS.has_feature("web"):
		fail("Co-op is available in the browser build. Open Debug from the Game Portal.")
		return
	notice = "Choose a connection mode, then create an invitation." if role == "host" else "Paste the host's invitation or open their invitation link."
	addresses = "Create an invitation to gather addresses." if role == "host" else "The host's invitation will choose the connection mode."
	pairing_changed.emit()

func create_invitation() -> void:
	if role != "host" or online or failed:
		return
	begin("host",network_mode)
	if not create_peer():
		return
	notice = "Gathering invitation…"
	addresses = "Gathering network addresses…"
	if peer.create_offer() != OK:
		fail("Could not create an invitation. Retry hosting.")
		return
	pairing_changed.emit()

func ice_configuration() -> Dictionary:
	return {"iceServers":[] if network_mode == "lan" else [{"urls":["stun:stun.l.google.com:19302"]}]}

func create_peer() -> bool:
	peer = WebRTCPeerConnection.new()
	if peer.initialize(ice_configuration()) != OK:
		fail("Could not initialize WebRTC. Try a current browser.")
		return false
	peer.session_description_created.connect(on_description)
	peer.ice_candidate_created.connect(on_candidate)
	channel = peer.create_data_channel("debug-coop",{"negotiated":true,"id":1,"ordered":true})
	if channel == null:
		fail("Could not create the co-op data channel.")
		return false
	return true

func on_description(kind: String, sdp: String) -> void:
	description = {"type":kind,"sdp":sdp}
	if peer.set_local_description(kind,sdp) != OK:
		fail("Could not prepare the connection code. Retry pairing.")

func on_candidate(media: String, index: int, candidate: String) -> void:
	if candidates.size() < 64:
		candidates.append({"media":media,"index":index,"candidate":candidate})

func accept_code(raw: String) -> void:
	if role == "solo" or failed or remote_applied:
		return
	var parsed := JSON.new()
	if raw.length() > MAX_CODE or parsed.parse(raw.strip_edges()) != OK:
		notice = "Invalid code. Paste the complete invitation or answer."
		pairing_changed.emit()
		return
	var data = parsed.data
	var expected := "answer" if role == "host" else "offer"
	if not (data is Dictionary) or data.get("game") != "debug-coop-1" or data.get("type") != expected or not (data.get("sdp") is String) or not (data.get("candidates") is Array) or data.candidates.size() > 64:
		notice = "Expected a Debug %s code. Ask the other player to copy it again." % expected
		pairing_changed.emit()
		return
	var network = data.get("network","auto")
	if not (network is String) or network not in ["auto","lan"] or (role == "host" and network != network_mode):
		notice = "Connection modes do not match. Ask the guest to use your current invitation and return a fresh answer."
		pairing_changed.emit()
		return
	for candidate in data.candidates:
		if not (candidate is Dictionary) or not (candidate.get("media") is String) or not (candidate.get("index") is float or candidate.get("index") is int) or not (candidate.get("candidate") is String):
			notice = "Invalid network address in the code. Copy it again."
			pairing_changed.emit()
			return
	if role == "guest":
		network_mode = network
		if not create_peer():
			return
	elif peer == null:
		notice = "Create an invitation before using the guest's answer."
		pairing_changed.emit()
		return
	if peer.set_remote_description(expected,data.sdp) != OK:
		fail("Could not read the connection description. Create a fresh session.")
		return
	for candidate in data.candidates:
		if peer.add_ice_candidate(candidate.media,int(candidate.index),candidate.candidate) != OK:
			fail("Could not use the network addresses. Create a fresh session.")
			return
	remote_applied = true
	notice = "Connecting to guest…" if role == "host" else "Gathering answer… Copy it back to the host when ready."
	pairing_changed.emit()

func _process(delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	age += delta
	if remote_applied:
		connecting_age += delta
	if code.is_empty() and not description.is_empty() and peer.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE:
		code = JSON.stringify({"game":"debug-coop-1","network":network_mode,"type":description.type,"sdp":description.sdp,"candidates":candidates})
		var found: Array[String] = []
		for candidate in candidates:
			var parts: PackedStringArray = candidate.candidate.split(" ")
			if parts.size() > 7:
				var address := "%s:%s (%s)" % [parts[4],parts[5],parts[7]]
				if address not in found:
					found.append(address)
		addresses = "\n".join(found) if not found.is_empty() else "No usable address found. Try another network."
		notice = "Invitation ready. Send the link or code to your teammate." if role == "host" else "Answer ready. Send this code back to the host."
		pairing_changed.emit()
	var state := peer.get_connection_state()
	if state in [WebRTCPeerConnection.STATE_FAILED,WebRTCPeerConnection.STATE_DISCONNECTED,WebRTCPeerConnection.STATE_CLOSED]:
		fail(connection_help("Connection lost or blocked."))
		return
	if channel == null:
		return
	channel.poll()
	if channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if not online:
			online = true
			notice = "Connected — two agents ready."
			pairing_changed.emit()
			connected.emit()
		rate_time += delta
		if rate_time >= 1:
			rate_time = 0
			packets_this_second = 0
		while channel != null and channel.get_available_packet_count() > 0:
			var bytes := channel.get_packet()
			packets_this_second += 1
			if bytes.size() > MAX_PACKET or packets_this_second > 120:
				fail("The other browser sent too much data. Session closed.")
				return
			var parsed := JSON.new()
			if parsed.parse(bytes.get_string_from_utf8()) == OK and parsed.data is Dictionary:
				packet.emit(parsed.data)
	elif online:
		fail("Your teammate disconnected. The run has stopped.")
	elif (remote_applied and connecting_age > 60) or (code.is_empty() and age > 25 and role == "host"):
		fail(connection_help("Connection timed out. Check that the host pasted the answer."))

func connection_help(reason: String) -> String:
	if network_mode == "lan":
		return reason + " Both devices must be on the same LAN. Guest Wi-Fi/client isolation, a VPN, or a firewall can block peer connections. Retry on the main Wi-Fi or Ethernet."
	return reason + " On the same LAN, try Same network / LAN mode. Otherwise try another network; some routers require a relay."

func send(data: Dictionary) -> void:
	if online and channel != null and channel.get_buffered_amount() < 96000:
		channel.put_packet(JSON.stringify(data).to_utf8_buffer())

func fail(reason: String) -> void:
	close(false)
	failed = true
	notice = reason
	pairing_changed.emit()
	disconnected.emit(reason)

func close(reset_role: bool = true) -> void:
	online = false
	failed = false
	if channel != null:
		channel.close()
	channel = null
	if peer != null:
		peer.close()
	peer = null
	code = ""
	description = {}
	candidates = []
	addresses = "Gathering network addresses…"
	age = 0
	connecting_age = 0
	remote_applied = false
	rate_time = 0
	packets_this_second = 0
	if reset_role:
		role = "solo"

func _exit_tree() -> void:
	close()
