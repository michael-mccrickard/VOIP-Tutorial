extends Node

var input : AudioStreamPlayer
var output : AudioStreamPlayer2D
var index : int
var effect : AudioEffectOpusChunked
var playback_stream : AudioStreamOpusChunked
# Identifier for the remote peer we are communicating with.
var partner_id : int = 0
# Push-to-talk mode flag.
var talk_mode := false
#@export var outputPath : NodePath
var receiveBuffer : Array[PackedByteArray] = []
var audioIsReady = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setupAudio(id):
        input = AudioStreamPlayer.new()
        set_multiplayer_authority(id)
        if is_multiplayer_authority():
                input.stream = AudioStreamMicrophone.new()
                input.name = "NewInput"
                var microphone_bus_name := "MicrophoneBus"
                index = AudioServer.get_bus_index(microphone_bus_name)
                if index == -1:
                        microphone_bus_name = "Record"
                        index = AudioServer.get_bus_index(microphone_bus_name)
                if index != -1:
                        AudioServer.set_bus_mute(index, true)
                        input.bus = microphone_bus_name
                        effect = _get_opus_effect_for_bus(index)
                        if effect == null:
                                push_error("AudioEffectOpusChunked not found on bus '%s'." % microphone_bus_name)
                else:
                        push_error("Unable to find a microphone bus. Configure 'MicrophoneBus' with an AudioEffectOpusChunked effect.")
                input.autoplay = true
                input.play()
                add_child(input)

                output = AudioStreamPlayer2D.new()
                playback_stream = AudioStreamOpusChunked.new()
                output.stream = playback_stream
                output.bus = "Master"
                output.autoplay = true
                add_child(output)
                output.play()

        audioIsReady = true
        print("chilling")

func _get_opus_effect_for_bus(bus_index: int) -> AudioEffectOpusChunked:
        if bus_index == -1:
                return null

        var effect_count := AudioServer.get_bus_effect_count(bus_index)
        for i in range(effect_count):
                var candidate := AudioServer.get_bus_effect(bus_index, i)
                if candidate is AudioEffectOpusChunked:
                        return candidate

        for i in range(effect_count - 1, -1, -1):
                var removable := AudioServer.get_bus_effect(bus_index, i)
                if removable is AudioEffectCapture:
                        AudioServer.remove_bus_effect(bus_index, i)

        var opus_effect := AudioEffectOpusChunked.new()
        AudioServer.add_bus_effect(bus_index, opus_effect, 0)
        return opus_effect

# Store the id of the remote peer that audio should be sent to.
func set_partner_id(id: int):
	partner_id = id

# Clear the stored remote peer id.
func clear_partner_id():
	partner_id = 0

# Toggle push-to-talk mode and return the new state.
func toggle_talk_mode() -> bool:
	talk_mode = !talk_mode
	return talk_mode

# Retrieve the current push-to-talk state.
func is_talk_mode() -> bool:
	return talk_mode

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
        if !audioIsReady:
                return

        processMic2()
        processVoice()


func processVoice():
        if playback_stream == null or receiveBuffer.size() <= 0:
                return

        while playback_stream.chunk_space_available() > 0 and receiveBuffer.size() > 0:
                var packet : PackedByteArray = receiveBuffer[0]
                receiveBuffer.remove_at(0)
                playback_stream.push_opus_packet(packet, 0, 0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data : PackedByteArray):
        receiveBuffer.append(data)

func processMic2():
        if effect == null or !is_multiplayer_authority():
                return

        var prepend := PackedByteArray()
        while effect.chunk_available():
                var opusdata : PackedByteArray = effect.read_opus_packet(prepend)
                effect.drop_chunk()
                if talk_mode and partner_id != 0 and opusdata.size() > 0:
                        sendData.rpc_id(partner_id, opusdata)
