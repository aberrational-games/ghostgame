class_name ServerMatchManager
extends Node

# Maps peer_id (int) to the player's Node3D
var active_players: Dictionary[int, Node3D] = { }

@onready var walkie_manager: ServerWalkieManager = $ServerWalkieManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	walkie_manager.channel_state_changed.connect(_on_channel_state_changed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_channel_state_changed(
	channel_id: int,
	state: int,
	listeners: Array[int],
	transmitters: Array[int],
) -> void:
	# Add only the players who are on the channel OR or near to the listeners to the list
	var need_to_know: Dictionary[int, bool] = { }

	for peer_id in listeners:
		need_to_know[peer_id] = true

	for peer_id in transmitters:
		need_to_know[peer_id] = true

	for peer_id in listeners:
		var listener: Node3D = active_players.get(peer_id)
		if !listener:
			continue
		for player_id in active_players:
			if player_id == peer_id:
				continue
			if need_to_know.has(player_id):
				continue
			var player: Node3D = active_players.get(player_id)
			if !player:
				continue
			var distance: float = listener.global_position.distance_to(player.global_position)
			if distance <= Services.WalkieTalkieConfig.WALKIE_AUDIBLE_RANGE:
				need_to_know[player_id] = true

	for peer_id in need_to_know.keys():
		# receive_channel_state.rpc_id(peer_id, channel_id, state, listeners, transmitters)
		pass
