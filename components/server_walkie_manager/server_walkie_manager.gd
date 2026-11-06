class_name ServerWalkieManager
extends Node

enum ChannelState {
	IDLE,
	TRANSMITTING,
	JAMMED,
}


class ChannelData:
	var listeners: Array[int] = []
	var transmitters: Array[int] = []
	var state: ChannelState = ChannelState.IDLE


var channels: Array[ChannelData] = []
var peer_channel_map: Dictionary[int, int] = { } #peer_id (int), channel_id (int)

signal channel_state_changed(
	channel_id: int,
	state: int,
	listeners: Array[int],
	transmitters: Array[int],
)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	for channel_count in range(WalkieTalkieConfig.CHANNEL_COUNT):
		channels.append(ChannelData.new())


@rpc("any_peer", "reliable", "call_local")
func tune_channel(channel_id: int) -> void:
	if not multiplayer.is_server():
		return
	if channel_id < -1 or channel_id >= WalkieTalkieConfig.CHANNEL_COUNT:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_remove_player_from_channels(sender_id)
	if channel_id == -1:
		return
	var target_channel: ChannelData = channels[channel_id]
	target_channel.listeners.append(sender_id)
	peer_channel_map[sender_id] = channel_id
	_recalculate_channel_state(channel_id)


@rpc("any_peer", "reliable", "call_local")
func request_transmit(channel_id: int, is_transmitting: bool) -> void:
	if not multiplayer.is_server():
		return
	if channel_id < 0 or channel_id >= WalkieTalkieConfig.CHANNEL_COUNT:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var target_channel: ChannelData = channels[channel_id]

	# Add/Remove sender_id from listeners/transmitters based on is_transmitting
	if is_transmitting:
		if target_channel.transmitters.has(sender_id):
			return
		else:
			if target_channel.listeners.has(sender_id):
				target_channel.listeners.erase(sender_id)
			target_channel.transmitters.append(sender_id)
	else:
		if target_channel.listeners.has(sender_id):
			return
		else:
			if target_channel.transmitters.has(sender_id):
				target_channel.transmitters.erase(sender_id)
			target_channel.listeners.append(sender_id)
	_recalculate_channel_state(channel_id)


func _recalculate_channel_state(channel_id: int) -> void:
	# Change target_channel state based on amount of transmitters
	var target_channel: ChannelData = channels[channel_id]
	if target_channel.transmitters.size() == 0:
		target_channel.state = ChannelState.IDLE
	elif target_channel.transmitters.size() == 1:
		target_channel.state = ChannelState.TRANSMITTING
	else:
		target_channel.state = ChannelState.JAMMED
	channel_state_changed.emit(
		channel_id,
		target_channel.state,
		target_channel.listeners,
		target_channel.transmitters,
	)


func _remove_player_from_channels(sender_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Remove sender_id from previous channel if they were on any
	if peer_channel_map.has(sender_id):
		var previous_channel_id = peer_channel_map.get(sender_id)
		var previous_channel: ChannelData = channels[previous_channel_id]
		previous_channel.listeners.erase(sender_id)
		previous_channel.transmitters.erase(sender_id)
		peer_channel_map.erase(sender_id)
		_recalculate_channel_state(previous_channel_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_from_channels(peer_id)
