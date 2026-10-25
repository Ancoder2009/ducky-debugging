extends CharacterBody2D
class_name Player

const SCENE: PackedScene = preload("uid://chm5u0dwpi7yc")

@export var server_http: HTTPRequest
@export var sprite: AnimatedSprite2D
@export var camera: Camera2D
@export var quack: AudioStreamPlayer2D
@export var chat_label: Label
@export var chat_anim: AnimationPlayer

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0

var target_pos: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		Global.player_chatted.connect(func(chat: String) -> void:
			chat_send.rpc_id(1, chat)
		)
	else:
		camera.queue_free()

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if velocity == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("run")

	# if Input.is_action_just_pressed("attack"):
	# 	duck_quack()

	var direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if direction:
		if direction.x:
			sprite.flip_h = sign(direction.x) == -1
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()

func _process(delta: float) -> void:
	if is_multiplayer_authority(): return
	global_position = global_position.lerp(target_pos, delta * 20)

static func create(id: int) -> Player:
	var p: Player = SCENE.instantiate()
	p.name = str(id)
	return p

@rpc("authority", "call_remote", "unreliable")
func _update_pos(pos: Vector2) -> void:
	target_pos = pos


func _on_pos_sync_timeout() -> void:
	if not is_multiplayer_authority(): return
	_update_pos.rpc(global_position)

var q_debounce: bool = false

func duck_quack() -> void:
	if q_debounce: return
	q_debounce = true
	quack.play()
	await get_tree().create_timer(0.5).timeout
	q_debounce = false

var c: String = ""
@rpc("authority", "call_remote", "reliable")
func chat_send(chat: String) -> void:
	if multiplayer.is_server():
		c = chat
		server_http.request("https://vector.profanity.dev", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({message = chat}))

@rpc("any_peer", "call_remote", "reliable")
func chat_recv(chat: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		quack.play()
		chat_label.text = chat
		chat_anim.play("appear")


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var msg: Dictionary = JSON.parse_string(body.get_string_from_utf8())
	if not msg.isProfanity:
		chat_recv.rpc(c)
	else:
		chat_recv.rpc(censor_with_symbols(c))

func censor_with_symbols(input: String, symbol_pattern: String = "!$%@^") -> String:
	var result: String = ""
	for i: int in range(input.length()):
		result += symbol_pattern[i % symbol_pattern.length()]
	return result
