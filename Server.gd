extends Node

var peer = ENetMultiplayerPeer.new()
@export var playerScene : PackedScene
var serverIsReady : bool
var partner_id : int = 0

@export var gameSpawnLocation : NodePath
# Called when the node enters the scene tree for the first time.
func _ready():
	if "--server" in OS.get_cmdline_args():
		_on_host_button_down()
		print("hosting on " + str(8910))
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
        partner_id = id
        AudioManager.set_partner_id(partner_id)

func peerDisconnected(id):
        print("peer disconnected! " + str(id))
        if id == partner_id:
                partner_id = 0
                AudioManager.clear_partner_id()

func _on_host_button_down():
        var error = peer.create_server(8910)
        if error:
                print("we have an error for server: " + error)
        multiplayer.multiplayer_peer = peer
        $"../Status".text = "You are hosting the app, id = " + str(multiplayer.get_unique_id())

        partner_id = 0
        AudioManager.clear_partner_id()
        AudioManager.setupAudio(1)
