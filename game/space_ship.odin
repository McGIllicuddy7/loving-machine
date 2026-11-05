package game
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

Spaceship :: struct {
	using _parent: eng.Entity,
	is_player:     bool,
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
			} else {
				eng.spawn_explosion(
					this.phys.position + eng.get_forward_vector(this) * 100,
					10,
					this.phys.velocity,
				)
			}
		}
	}
}

ship_on_render :: proc(this: ^Spaceship) {

}

ship_destructor :: proc(this: ^Spaceship) {

}

ship_on_event :: proc(this: ^Spaceship, ev: eng.Event) {
	switch v in ev.data {
	case eng.CollisionEvent:
		rvel := linalg.length2(v.relative_velocity) / 100
		this.health -= cast(i32)math.floor(rvel)
	}
	if this.health < 0 {
		eng.destroy_entity(this.self_ref)
	}
}

ship_on_level_transfer :: proc(this: ^Spaceship) {}
