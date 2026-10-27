package game
import "core:container/queue"
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import "core:sync"
import "engine"
import "vendor:raylib"

Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject

MAX_ENTITY_COUNT :: 16384
ENTITY_POOL_SIZE :: 4096
Event :: union {}

EntityTag :: enum {}

EntityMesh :: struct {
	name:  string,
	color: raylib.Color,
}

//demcent and france 1968
Entity :: struct {
	this_type:        typeid,
	tags:             bit_set[EntityTag],
	phys:             PhysicsObject,
	control_rotation: Quat,
	mesh:             string,
	on_update:        proc(this: ^Entity, delta_time: f32),
	on_event:         proc(this: ^Entity, event: Event),
	destructor:       proc(this: ^Entity),
}
