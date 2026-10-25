extends Area2D
class_name Bug

const SCENE: PackedScene = preload("uid://cr57orxoihmd7")

@export var anim: AnimationPlayer

static func create(pos: Vector2) -> Bug:
	var b: Bug = SCENE.instantiate()
	b.global_position = pos
	return b

static var amount: int = 0:
	set(value): amount = value; Global.bug_amt_changed.emit(amount)

func _enter_tree() -> void:
	amount += 1

func _exit_tree() -> void:
	amount -= 1
	Global.bug_amt_decreased.emit()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and is_multiplayer_authority():
		_animate.rpc()
		anim.play("despawn")
		await anim.animation_finished
		queue_free()

@rpc("authority", "reliable")
func _animate() -> void:
	anim.play("despawn")
