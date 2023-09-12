extends RigidBody2D

@export var max_thrust = 4096

@onready var planet = %Planet
@onready var progress_bar = %ProgressBar

const THRUST_SPEED = 48
const BOOST_MULTIPLIER = 5
const G = 64 # gravitational constant

# Util
var debug_mode = false

# Ship
enum LanderStates {
	ORBIT,
	AIRBORNE,
	COLLIDING,
	GROUNDED
}

var ship_state = LanderStates.ORBIT
var thrust_force = 0.0
var rotation_target = 0.0
var rotation_damping = true
var gravity_vector := Vector2.ZERO
var thrust_vector := Vector2.ZERO
var orbit_velocity := Vector2.ZERO
var final_velocity : Vector2

func _integrate_forces(state):
	var radius = global_position.distance_to(planet.global_position)
	var planet_direction = global_position.direction_to(planet.global_position)
	
	orbit_velocity = sqrt(G * planet.mass / radius) * planet_direction.rotated(deg_to_rad(-90))
	
	if ship_state == LanderStates.ORBIT:
		linear_velocity = orbit_velocity

func _physics_process(delta):
	var wish_thrust = Input.get_axis("thrust_down", "thrust_up")
	var wish_rotate = Input.get_axis("rotate_left", "rotate_right")
	var booster = (Input.get_action_strength("ui_accept") + 1) * BOOST_MULTIPLIER
	
	# Rotation
	if ship_state != LanderStates.GROUNDED:
		rotation_target += wish_rotate / 50;
		if wish_rotate == 0:
			rotation_target = move_toward(rotation_target, 0.0, 0.01)
		
		rotation_target = clamp(rotation_target, -3, 3)
		$CollisionShape2D.rotate(rotation_target * delta)

	match(ship_state):
		LanderStates.ORBIT:
			if wish_thrust != 0:
				ship_state = LanderStates.AIRBORNE
		LanderStates.AIRBORNE:
			thrust_force = clamp(thrust_force + wish_thrust * THRUST_SPEED, 0, max_thrust)
			%ProgressBar.value = (thrust_force / max_thrust) * 100
			$CollisionShape2D/Thrust.scale = Vector2(1, 1) * thrust_force / max_thrust
			if thrust_force != 0 and !$ThrustLoop.playing:
				$ThrustLoop.playing = true
			elif thrust_force == 0:
				$ThrustLoop.playing = false
			thrust_vector = booster * thrust_force * Vector2(0, -1).rotated($CollisionShape2D.rotation)
			
			apply_central_force(thrust_vector)
			
			if get_contact_count() > 0:
				ship_state = LanderStates.COLLIDING
				return
				
			final_velocity = linear_velocity
		LanderStates.COLLIDING:
			if final_velocity.length() > 200:
				Events.emit_signal("explode")
				$Explosion.playing = true
				$ExplosionSprite.play("default")
				$CollisionShape2D/Sprite2D.set_visible(false)
			else:
				Events.emit_signal("win")
				$Victory.playing = true
				
			ship_state = LanderStates.GROUNDED
		LanderStates.GROUNDED:
			if Input.is_action_pressed("ui_accept"):
				get_tree().reload_current_scene()
			
	# Calculate and apply gravity
	var radius = global_position.distance_to(planet.global_position)
	var force_gravity = (G * planet.mass * mass) / pow(radius, 2)
	var planet_direction = global_position.direction_to(planet.global_position)
	var distance_to_surface = radius - planet.get_node("CollisionShape2D").shape.radius
	
	gravity_vector = planet_direction * force_gravity
	apply_central_force(gravity_vector)
	
	# DEBUG
	if debug_mode:
		queue_redraw()
		
	$Arrow.look_at(planet.global_position)
	
func _draw():
	if debug_mode:
		draw_line(Vector2.ZERO, gravity_vector, Color(1, 0, 0))
		draw_line(Vector2.ZERO, thrust_vector, Color(0, 1, 0))
		draw_line(Vector2.ZERO, linear_velocity, Color(0, 0, 1))
