extends Node

var input : AudioStreamPlayer
var output : AudioStreamPlayer
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
# Debug counters used to limit how many diagnostic lines we print.
var _mic_debug_count := 0
var _playback_debug_count := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var actual_mix_rate = AudioServer.get_mix_rate()
	print("Actual audio server mix rate:", actual_mix_rate)
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
						_print_effect_diagnostics(microphone_bus_name)
		else:
			push_error("Unable to find a microphone bus. Configure 'MicrophoneBus' with an AudioEffectOpusChunked effect.")
		input.autoplay = true
		input.play()
		add_child(input)

		output = AudioStreamPlayer.new()
		playback_stream = AudioStreamOpusChunked.new()
		_configure_playback_stream()
		output.stream = playback_stream
		output.bus = "Master"
		output.autoplay = true
		add_child(output)
		output.play()

	audioIsReady = true
	print("chilling")

func _print_effect_diagnostics(bus_name: String) -> void:
	if effect == null:
		return

	var audio_mix_rate := AudioServer.get_mix_rate()
	var effect_mix_rate : Variant = "unknown"
	if effect.has_method("get_mix_rate"):
		effect_mix_rate = effect.get_mix_rate()

	var effect_channels : Variant = "unknown"
	if effect.has_method("get_channels"):
		effect_channels = effect.get_channels()

	print("Opus capture effect configured on bus '%s'. AudioServer mix rate=%s, effect mix rate=%s, channels=%s" % [bus_name, audio_mix_rate, effect_mix_rate, effect_channels])
	if effect_mix_rate == "unknown" or effect_channels == "unknown":
		print("Effect available properties:", _collect_property_names(effect))

func _configure_playback_stream() -> void:
	if playback_stream == null:
		return

	var target_mix_rate := AudioServer.get_mix_rate()
	var before_mix_rate : Variant = "unavailable"
	if playback_stream.has_method("get_mix_rate"):
		before_mix_rate = playback_stream.get_mix_rate()

	var property_names := _collect_property_names(playback_stream)
	if playback_stream.has_method("set_mix_rate"):
		playback_stream.set_mix_rate(target_mix_rate)
	else:
		print("AudioStreamOpusChunked is missing set_mix_rate(). Properties:", property_names)

	var after_mix_rate : Variant = before_mix_rate
	if playback_stream.has_method("get_mix_rate"):
		after_mix_rate = playback_stream.get_mix_rate()
	else:
		after_mix_rate = target_mix_rate

	print("Configured playback stream mix rate. target=%s, before=%s, after=%s" % [target_mix_rate, before_mix_rate, after_mix_rate])
	if playback_stream.has_method("get_channels"):
		print("Playback stream channels:", playback_stream.get_channels())
	else:
		print("Playback stream property list:", property_names)

func _collect_property_names(obj: Object) -> Array:
	var names : Array = []
	for property in obj.get_property_list():
		if property.has("name"):
			names.append(property["name"])
	return names

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
	processMic()
	processVoice()

func processVoice():
        if playback_stream == null or receiveBuffer.size() <= 0:
                return

        while playback_stream.chunk_space_available() and receiveBuffer.size() > 0:
                var packet : PackedByteArray = receiveBuffer[0]
                receiveBuffer.remove_at(0)
                playback_stream.push_opus_packet(packet, 0, 0)

                if _playback_debug_count < 5:
                        var playback_mix_rate : Variant = "unknown"
                        if playback_stream.has_method("get_mix_rate"):
                                playback_mix_rate = playback_stream.get_mix_rate()
                        print("Playback chunk #%s pushed: size=%s bytes, queued packets remaining=%s, playback mix rate=%s" % [_playback_debug_count + 1, packet.size(), receiveBuffer.size(), playback_mix_rate])
                        _playback_debug_count += 1

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data : PackedByteArray):
	receiveBuffer.append(data)

func processMic():
	if effect == null or !is_multiplayer_authority():
		return

        var prepend := PackedByteArray()
        while effect.chunk_available():
                var opusdata : PackedByteArray = effect.read_opus_packet(prepend)
                effect.drop_chunk()
                var should_send := talk_mode and partner_id != 0 and opusdata.size() > 0

                if _mic_debug_count < 5:
                        var effect_mix_rate : Variant = "unknown"
                        if effect.has_method("get_mix_rate"):
                                effect_mix_rate = effect.get_mix_rate()
                        print("Mic chunk #%s: size=%s bytes, should_send=%s, talk_mode=%s, partner_id=%s, effect mix rate=%s" % [_mic_debug_count + 1, opusdata.size(), should_send, talk_mode, partner_id, effect_mix_rate])
                        _mic_debug_count += 1

                if should_send:
                        sendData.rpc_id(partner_id, opusdata)
