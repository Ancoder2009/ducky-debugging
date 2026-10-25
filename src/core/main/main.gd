extends Node

@export var players: Node
@export var bugs: Node
@export var progress_bar: ProgressBar
@export var chat: LineEdit
@export var end_anim: AnimationPlayer
@export var online_counter: Label

const BUG_SPAWN_RANGE: int = 1000

var end: bool = false

var req_killed: int = 2000
@export var killed: int = 0:
	set(value):
		killed = value; progress_bar.value = (float(killed) / req_killed) * 100
		save_data()
		if killed >= req_killed:
			if end: return
			end_anim.play("appear")
			end = true

var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
const port: int = 8000

func _ready() -> void:
	Global.bug_amt_changed.connect(func(amt: int) -> void:
		if multiplayer.is_server():
			Log.info("Bugs %d" % amt)
			if amt < 10:
				bugs.add_child.call_deferred(Bug.create(Vector2(randi_range(-BUG_SPAWN_RANGE, BUG_SPAWN_RANGE), randi_range(-BUG_SPAWN_RANGE, BUG_SPAWN_RANGE))), true)
	)
	Global.bug_amt_decreased.connect(func() -> void:
		if is_multiplayer_authority():
			killed += 1
	)
	if OS.has_feature("dedicated_server"):
		start_server()
	else:
		connect_to_server()
	

func start_server() -> void:
	Log.info("Server start")
	multiplayer.peer_connected.connect(func(id: int) -> void:
		Log.info("Player %d join" % id)
		players.add_child(Player.create(id))
	)
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		Log.info("Player %d left" % id)
		var p: Player = players.get_node_or_null(str(id))
		if p: p.queue_free()
	)
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	load_data()
	Global.bug_amt_changed.emit(0)

func save_data() -> void:
	var file: FileAccess = FileAccess.open("user://data.dat", FileAccess.WRITE)
	
	if file:
		file.store_var(killed)
		file.close()
		Log.info("Server saved data.")
	else:
		Log.warn("Server failed to write save.")

func load_data() -> void:
	if not FileAccess.file_exists("user://data.dat"):
		Log.info("No save found")
		return

	var file: FileAccess = FileAccess.open("user://data.dat", FileAccess.READ)
	if file:
		killed = file.get_var()
		Log.info("Load killed amount: %d" % killed)
		file.close()
		
func connect_to_server() -> void:
	if OS.is_debug_build():
		peer.create_client("ws://localhost:8000")
	else:
		peer.create_client("wss://ducky-debugging.ancoder.net")
	multiplayer.multiplayer_peer = peer
	Log.info("Client start")

func _input(event: InputEvent) -> void:
	if multiplayer.is_server(): return

	if event.is_action_pressed("ui_text_submit"):
		if get_viewport().gui_get_focus_owner() == null:
			chat.grab_focus()
			get_viewport().set_input_as_handled()


func _on_line_edit_text_submitted(new_text: String) -> void:
	if multiplayer.is_server(): return
	
	if not new_text.is_empty():
		Global.player_chatted.emit(new_text)
	
	chat.text = ""
	get_viewport().gui_release_focus()


func _on_player_changed(node: Node) -> void:
	online_counter.text = "Players Online: %d" % players.get_child_count()
