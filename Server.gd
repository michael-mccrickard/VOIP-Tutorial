extends Node
#Server.gd

var peer = ENetMultiplayerPeer.new()
var serverIsReady : bool
var partner_id : int = 0
var port_local = 8910
var port_remote = 4242

func _ready():
	if OS.has_feature("dedicated_server"):
		print("Dedicated server enabled")
		start_matchmaking_server()
	else:
		print("Desktop server or client build")

		if "--server" in OS.get_cmdline_args():
			_on_host_button_down()
			print("hosting on " + str(port_local))
			
		multiplayer.peer_connected.connect(peerConnected)
		multiplayer.peer_disconnected.connect(peerDisconnected)


func start_matchmaking_server():
	var server = ENetMultiplayerPeer.new()
	var result = server.create_server(port_remote, 32)
	if result == OK:
		print("Matchmaking server is running.")
		serverIsReady = true
		peer = server              # <-- critical!
		multiplayer.multiplayer_peer = peer
	else:
		print("Failed to start matchmaking server.")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !OS.has_feature("dedicated_server"): return
	if serverIsReady:
		peer.poll()
	pass

var connected_clients := []

func peerConnected(id):
	if id != 1: # Skip server itself if assigned as id 1
		connected_clients.append(id)
		print("peer connected! " + str(id))
	partner_id = id
	AudioManager.set_partner_id(partner_id)
	if connected_clients.size() == 2:
		print("Two clients connected! Start match.")
		# Start game/matchmaking logic

func peerDisconnected(id):
	if id in connected_clients:
		connected_clients.erase(id)
	print("peer disconnected! " + str(id))
	if id == partner_id:
		partner_id = 0
		AudioManager.clear_partner_id()

func _on_host_button_down():
	var error = peer.create_server(port_local)
	if error:
		print("we have an error for server: " + error)
	multiplayer.multiplayer_peer = peer
	$"../Status".text = "You are hosting the app locally, id = " + str(multiplayer.get_unique_id())

	partner_id = 0
	AudioManager.clear_partner_id()
	AudioManager.setupAudio(1)
