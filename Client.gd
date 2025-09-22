extends Node
# Client.gd

var server_ip_local = "192.168.1.170"
var server_ip_remote = "157.245.120.11"  # Your Digital Ocean IP
var server_port = 4242  # Use the same port for both local and remote for consistency

var peer = ENetMultiplayerPeer.new()
var serverIsReady : bool
var partner_id : int = 0

func _ready():
	multiplayer.peer_connected.connect(peerConnected)
	multiplayer.peer_disconnected.connect(peerDisconnected)

func connect_client_to_server():
	var args = OS.get_cmdline_args()
	var use_local = "--local" in args
	var server_ip
	if use_local:
		server_ip = server_ip_local
	else:
		server_ip = server_ip_remote
		
	var conn_type
	if use_local:
		conn_type = "local"
	else:
		conn_type = "remote"
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_ip, server_port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		showStatus("Attempting connection to %s server at %s:%d..." % [conn_type, server_ip, server_port])
	else:
		showStatus("Failed to create client peer: %s" % error)

	if use_local:
		# Do things specific to local networking
		showStatus("You're connected to the local app, id = " + str(multiplayer.get_unique_id()))
		partner_id = 0
		AudioManager.clear_partner_id()
		AudioManager.setupAudio(multiplayer.get_unique_id())

func _process(delta):
	if serverIsReady:
		peer.poll()
	pass

func peerConnected(id):
	print("peer connected! " + str(id))
	if id != multiplayer.get_unique_id():
		partner_id = id
		AudioManager.set_partner_id(partner_id)

func peerDisconnected(id):
	print("peer disconnected! " + str(id))
	if id == partner_id:
		partner_id = 0
		AudioManager.clear_partner_id()
		
func _on_connect_to_server_pressed():
	connect_client_to_server()

func showStatus(_str: String):
	$"../Status".text = _str
