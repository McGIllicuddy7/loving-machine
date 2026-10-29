package game
import "core:math"
import "core:math/linalg"
import "core:strings"
import "engine"
import "vendor:raylib"
Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject
string_clone :: engine.string_clone

Spaceship :: struct {
	using _parent: engine.Entity,
	is_player:     bool,
}

create_space_ship :: proc(pos: Vec3, rotation: Quat, is_player: bool) -> (EntityRef, ^Spaceship) {
	vtable: engine.EntityVtable
	vtable.on_render = ship_on_render
	vtable.on_update = ship_on_update
	vtable.destructor = ship_destructor
	rf, ship := engine.create_entity(Spaceship, vtable)
	ship.is_player = is_player
	ship.phys.position = pos
	ship.phys.rotation = rotation
	ship.phys.width = 0.5
	ship.phys.height = 0.5
	ship.phys.collision_response = .Slide
	ship.phys.length = 2.
	ship.mesh.name = string_clone("cylinder")
	pi := math.PI
	return rf, ship
}

ship_on_update :: proc(this: ^Spaceship, dt: f32) {
	if (this.is_player) {
		engine.handle_movement_input_simple_3d(this, 10., 1., dt)
		engine.attach_camera_to(this, {-1, 0.0, 0.6}, Quat(1))
	}
}

ship_on_render :: proc(this: ^Spaceship) {

}

ship_destructor :: proc(this: ^Spaceship) {

}

ship_on_event :: proc(this: ^Spaceship, ev: engine.Event) {

}

ship_on_level_transfer :: proc(this: ^Spaceship) {}
