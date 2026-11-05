package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:sys/posix"
import "core:time"

import "core:encoding/cbor"
import "game"
import "game/eng"
import "libgraph"
import "libnav"
import "vendor:raylib"

//3,490,216
Vec3f :: eng.Vec3f
Vec3 :: eng.Vec3
Quat :: eng.Quat
main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	game_main()
	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
}

game_main :: proc() {
	eng.init()
	defer eng.fini()
	game.game_setup()
	t, _ := game.create_space_ship({10, 0, 0}, quaternion256(1), true)
	for i in 0 ..< 1000 {
		_, tmp := eng.create_entity(eng.Entity)
		sz := 5
		tmp.phys.position =
			{
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
			} *
			1
		tmp.phys.rotation = Quat(1)
		tmp.phys.height = 0.5
		tmp.phys.width = 0.5
		tmp.phys.length = 0.5
		tmp.phys.is_static = true
		tmp.mesh.name = eng.string_clone("cube")
		tmp.mesh.diffuse_map_name = eng.string_clone("metal_diffuse.png")
		tmp.mesh.normal_map_name = eng.string_clone("metal_normal.png")
		tmp.mesh.color = raylib.WHITE
	}
	eng.eng_run()
}
