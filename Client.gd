extends Node

#var server_ip = "127.0.0.1"
var server_ip = "192.168.1.170"

var peer = ENetMultiplayerPeer.new()
@export var playerScene : PackedScene
var serverIsReady : bool
var partner_id : int = 0

@export var gameSpawnLocation : NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
	multiplayer.peer_connected.connect(peerConnected)
	multiplayer.peer_disconnected.connect(peerDisconnected)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if serverIsReady:
		peer.poll()
	pass

func peerConnected(id):
	print("peer connected! " + str(id))
	if id != multiplayer.get_unique_id():
		partner_id = id
		AudioManager.set_partner_id(partner_id)
	#var p = playerScene.instantiate()
	#add_child(p)
	#p.name = str(id)
	#p.get_node("AudioManager").setupAudio(id)

func peerDisconnected(id):
	print("peer disconnected! " + str(id))
	if id == partner_id:
		partner_id = 0
		AudioManager.clear_partner_id()

func _on_connect_to_server_pressed():
	var error = peer.create_client(server_ip, 8910)
	if error:
		print("we have an error for client: " + error)
	multiplayer.multiplayer_peer = peer
	$"../Status".text = "You are connected to the app, id = " + str(multiplayer.get_unique_id())

	partner_id = 0
	AudioManager.clear_partner_id()
	AudioManager.setupAudio(multiplayer.get_unique_id())

	#var p = playerScene.instantiate()
	#get_node(gameSpawnLocation).add_child(p)
	#p.name = str(1)
	#p.get_node("AudioManager").setupAudio(1)
	#serverIsReady = true
	#pass # Replace with function body.
