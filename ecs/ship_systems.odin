package ecs
import "../game"
import "../game/engine"
import "core:math/linalg"
import "vendor:raylib"
Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject

input_system :: proc(dt: f32) {
	ents := game.get_all_entities_with_tag(.IsPlayer)
	//defer delete(ents)
	if len(ents) < 1 {
		return
	}
	player_entity := ents[0]
	d_pitch := 0.
	d_yaw := 0.
	d_roll := 0.
	player_entity.physics.angular_velocity = {}
	if raylib.IsKeyDown(.Q) {
		d_yaw += 1.
	}
	if raylib.IsKeyDown(.E) {
		d_yaw -= 1.
	}
	if raylib.IsKeyDown(.R) {
		d_pitch -= 1.
	}
	if raylib.IsKeyDown(.F) {
		d_pitch += 1.
	}
	if raylib.IsKeyDown(.T) {
		d_roll -= 1.
	}
	if raylib.IsKeyDown(.G) {
		d_roll += 1.
	}
	d_vec := Vec3{0, 0, 0}
	if raylib.IsKeyDown(.W) {
		d_vec.x += 1.
	}
	if raylib.IsKeyDown(.S) {
		d_vec.x -= 1.
	}
	if raylib.IsKeyDown(.A) {
		d_vec.y += 1.
	}
	if raylib.IsKeyDown(.D) {
		d_vec.y -= 1.
	}
	if raylib.IsKeyDown(.Z) {
		d_vec.z -= 1.
	}
	if raylib.IsKeyDown(.SPACE) {
		d_vec.z += 1.
	}
	player_entity.physics.angular_velocity = {d_roll, d_pitch, d_yaw}
	player_entity.physics.velocity = linalg.quaternion_mul_vector3(
		player_entity.physics.rotation,
		d_vec * 10.,
	)
	{
		game.set_camera_pos_rot(player_entity, {-1.5, 0.0, 0.6} + d_vec * 10. / 60., Quat(1))
	}
}
