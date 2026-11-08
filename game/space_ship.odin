package game
import "../libnav"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import "eng"
import "vendor:raylib"
Vec3 :: eng.Vec3
Quat :: eng.Quat
EntityRef :: eng.EntityRef
Transform :: eng.Transform
PhysicsObject :: eng.PhysicsObject
string_clone :: eng.string_clone
Entity :: eng.Entity

ShipAiMode :: enum {}

ShipAiData :: struct {
	target_entity:            EntityRef,
	movement_target_position: Vec3,
	moving_to_pos:            bool,
	dodge_remaining_time:     f64,
	dodge_direction:          f64,
	remaining_check_time:     f64,
}

Spaceship :: struct {
	using _parent:        eng.Entity,
	is_player:            bool,
	ai_info:              ShipAiData,
	dodge_remaining_time: f64,
	dodge_direction:      Vec3,
}

create_space_ship :: proc(pos: Vec3, rotation: Quat, is_player: bool) -> (EntityRef, ^Spaceship) {
	vtable: eng.EntityVtable
	vtable.on_render = ship_on_render
	vtable.on_update = ship_on_update
	vtable.destructor = ship_destructor
	vtable.on_event = ship_on_event
	rf, ship := eng.create_entity(Spaceship, vtable)
	ship.is_player = is_player
	ship.phys.position = pos
	ship.phys.rotation = rotation
	ship.phys.width = 0.5
	ship.phys.height = 0.5
	ship.phys.collision_response = .Elastic
	ship.phys.length = 2.
	ship.mesh.name = string_clone("cylinder")
	ship.mesh.diffuse_map_name = string_clone("metal_diffuse.png")
	ship.mesh.normal_map_name = string_clone("metal_normal.png")
	ship.health = 100
	if is_player {
		ship.tags |= {.ShouldTransferLevel, .Actor}
	} else {
		ship.tags |= {.Actor}
	}
	pi := math.PI
	return rf, ship
}

ship_on_update :: proc(this: ^Spaceship, dt: f32) {
	if (this.is_player) {
		eng.handle_movement_input_simple_3d(this, 10., 1., dt)
		eng.attach_camera_to(this, {-1, 0.0, 0.6}, Quat(1))
		if raylib.IsMouseButtonPressed(.LEFT) {
			rs, hit := eng.raycast(
				this.phys.position,
				eng.get_forward_vector(this),
				100.,
				{this.self_ref},
			)
			if hit {
				eng.spawn_explosion(rs.hit_location, 10.)
				eng.apply_point_damage(
					this.self_ref,
					rs.hit_entity,
					rs.hit_location,
					-rs.hit_normal,
					25,
				)
			} else {
				eng.spawn_explosion(
					this.phys.position + eng.get_forward_vector(this) * 100,
					10,
					this.phys.velocity,
				)
			}
		}
	} else {
		ship_ai_update(this, dt)
	}
}

ship_on_render :: proc(this: ^Spaceship) {
	trs := this.phys.trans
	trs.position -= eng.get_forward_vector(this) * (2)
	eng.bind_model("sphere", trs, {0.5, 0.5, 0.5}, raylib.RED)
	if this.ai_info.moving_to_pos {
		trs.position = this.ai_info.movement_target_position
		eng.bind_model("sphere", trs, {2, 2, 2}, raylib.GREEN)
	}
}

ship_destructor :: proc(this: ^Spaceship) {

}

ship_on_event :: proc(this: ^Spaceship, ev: eng.Event) {
	switch v in ev.data {
	case eng.CollisionEvent:
		rvel := linalg.length2(v.relative_velocity) / 100
		this.health -= cast(i32)math.floor(rvel)
	case eng.EntityDestroyedEvent:
	case eng.EntityPointDamageEvent:
		if v.damaged_entity == this.self_ref {
			this.health -= v.damage
		}
	case eng.EntityRadialDamageEvent:
		if v.damaged_entity == this.self_ref {
			this.health -= v.damage
		}
	}
	if this.health < 0 {
		eng.destroy_entity(this.self_ref)
		eng.spawn_explosion(this.phys.position, 100, this.phys.velocity)
	}
}

ship_on_level_transfer :: proc(this: ^Spaceship) {
	this.ai_info = {}
}

ship_ai_update :: proc(this: ^Spaceship, dt: f32) {
	info := &this.ai_info
	ship_ai_update_movement(this, dt)
}

ship_ai_update_movement :: proc(this: ^Spaceship, dt: f32) {
	info := &this.ai_info
	this.phys.velocity +=
		libnav.calculate_missile_frame_acceleration(
			10,
			info.movement_target_position - this.phys.position,
			-this.phys.velocity,
			{},
			true,
		) *
		cast(f64)dt
	if linalg.distance(this.phys.position, info.movement_target_position) > 0.1 {
		t_rot := eng.rotate_to_look_in_direction(
			this.phys.rotation,
			linalg.normalize(info.movement_target_position - this.phys.position),
			cast(f64)dt,
			10,
		)
		this.phys.rotation = t_rot
	}
}
