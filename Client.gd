extends Node

#var server_ip = "127.0.0.1"
var server_ip = "192.168.1.153"

var peer = ENetMultiplayerPeer.new()
@export var playerScene : PackedScene
var clientConnected : bool
@export var gameSpawnLocation : NodePath

func _ready():
	multiplayer.peer_connected.connect(peerConnected)
	multiplayer.peer_disconnected.connect(peerDisconnected)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if clientConnected:
		peer.poll()
	pass

func peerConnected(id):
	print("peer connected! " + str(id))
	var p = playerScene.instantiate()
	get_node(gameSpawnLocation).add_child(p)
	p.name = str(id)
	p.get_node("AudioManager").setupAudio(id)
	$"../Status".text = "You are a client connected to the app, id = " + str(multiplayer.get_unique_id())
	
func peerDisconnected(id):
	print("peer disconnected! " + str(id))

func _on_connect_to_server_button_down():
	peer.create_client(server_ip, 8910)
	
	multiplayer.multiplayer_peer = peer
	
	var p = playerScene.instantiate()
	get_node(gameSpawnLocation).add_child(p)
	p.name = str(multiplayer.get_unique_id())
	p.get_node("AudioManager").setupAudio(multiplayer.get_unique_id())
	clientConnected = true
	pass # Replace with function body.
