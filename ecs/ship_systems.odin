package ecs
import "../game"
import "../game/engine"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:strings"
import "vendor:raylib"
Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject

input_system :: proc(dt: f32) {
	ents := game.get_all_entities_with_tag(.IsPlayer)
	//defer delete(ents)
	if len(ents) <= game.RUNTIME.player_idx {
		return
	}
	player_entity := ents[game.RUNTIME.player_idx]
	d_pitch := 0.
	d_yaw := 0.
	d_roll := 0.
	player_entity.physics.angular_velocity = {}
	{
		ds := cast([2]f64)raylib.GetMouseDelta()
		d_pitch += ds.y / 5
		d_yaw -= ds.x / 5.
	}
	if raylib.IsKeyDown(.Q) {
		d_roll -= 1.
	}
	if raylib.IsKeyDown(.E) {
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
	if raylib.IsKeyPressed(.X) {
		dir := game.get_forward_vector(player_entity)
		guns := game.get_all_components_of_type_facing_in_direction(player_entity, .Laser, dir)
		defer delete(guns)
		for i in guns {
			pos := game.get_comp_pos(player_entity, i) + dir * 1.1
			if player_entity.inventory.items[game.InventoryItem.Bullet] > 0 {
				player_entity.inventory.items[game.InventoryItem.Bullet] -= 1
				spawn_bullet(
					pos,
					dir,
					player_entity.physics.velocity,
					player_entity.physics.rotation,
				)
			}
		}
	}
	player_entity.physics.angular_velocity = {d_roll, d_pitch, d_yaw}
	player_entity.physics.velocity = linalg.quaternion_mul_vector3(
		player_entity.physics.rotation,
		d_vec * 10.,
	)
	{
		game.set_camera_pos_rot(player_entity, {-0.25, 0.0, 0.3}, Quat(1))
	}
}

event_handler :: proc(event: game.Event) -> bool {
	switch v in event {
	case engine.CollisionEvent:
		handle_collision_event(v)
	case game.EntityDestroyedEvent:
		event_on_entity_destroyed(v)
	case game.DamageEvent:
		event_on_entity_damaged(v)
	}
	return true
}

handle_collision_event :: proc(v: engine.CollisionEvent) {
	//engine.log(fmt.tprint(v))
	//et := game.get_entity(v.collided_with_entity)	
	base := game.get_entity(v.collider_entity)
	if base == nil {
		return
	}
	if base.physics.is_projectile {
		game.destroy_entity(v.collided_with_entity, v.collided_with_entity)
		return
	}
	mass := base.physics.mass
	rv := v.relative_velocity
	vel := linalg.length(rv)
	if (vel < 20.) {
		return
	}
	dir := rv / vel
	damage := ke_to_damage(mass, vel)
	engine.log(fmt.tprintf("damage:%d\n", damage))
	game.apply_damage(
		v.collided_with_entity,
		v.collider_entity,
		damage,
		dir,
		base.physics.position,
	)
}


ke_to_damage :: proc(mass: f64, velocity: f64) -> i32 {
	ke := 0.5 * mass * velocity
	damage := cast(i32)ke / 100
	return damage
}

event_on_entity_damaged :: proc(v: game.DamageEvent) {
	et := game.get_entity(v.damaged_entity)
	if et == nil {
		return
	}
	et.health -= v.damage
	rc := game.raycast_against_entity_ship_components(et, v.point, v.direction)
	defer delete(rc)
	damage := v.damage
	for i in rc {
		damage -= cast(i32)i.distance_from_previous / 10
		damage -= i.component.damage_resistance
		if damage < 0 {
			break
		}
		i.component.health -= damage
	}
	if (et.health) < 0 {
		game.destroy_entity(v.damaged_entity, v.damaging_entity)
	}

}

event_on_entity_destroyed :: proc(v: game.EntityDestroyedEvent) {
	if v.destroyed_entity != v.destroying_entity {
		engine.log(fmt.tprintf("entity:%d destroyed", v.destroyed_entity.idx))
	}
	_ = v
}

spawn_bullet :: proc(
	pos: Vec3,
	direction: Vec3,
	base_velocity: Vec3,
	rotation: quaternion256,
) -> EntityRef {
	rf, ptr := game.create_entity()
	ptr.type = .Bullet
	ptr.physics.is_projectile = true
	ptr.tint = raylib.RED
	ptr.health = 1
	ptr.mesh = strings.clone("cylinder")
	scale := 0.5
	rad := 0.25
	ptr.lifetime = 5.
	ptr.physics.height = rad * scale
	ptr.physics.width = rad * scale
	ptr.physics.length = 1 * scale
	ptr.physics.position = pos
	ptr.physics.mass = 10
	ptr.model_scale = {ptr.physics.length, ptr.physics.width, ptr.physics.height}
	ptr.physics.rotation = rotation
	ptr.physics.velocity = direction * 50 + base_velocity
	return rf
}
