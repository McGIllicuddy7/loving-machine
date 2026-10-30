package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "core:encoding/cbor"
import "game"
import "game/engine"
import "vendor:raylib"
//3,490,216
Vec3f :: engine.Vec3f
Quat :: engine.Quat
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
	engine.init()
	defer engine.fini()
	game.game_setup()
	t, _ := game.create_space_ship({10, 0, 0}, quaternion256(1), true)
	for i in 0 ..< 1000 {
		_, tmp := engine.create_entity(engine.Entity)
		sz := 6
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
		tmp.mesh.name = engine.string_clone("cube")
		tmp.mesh.diffuse_map_name = engine.string_clone("metal_diffuse.png")
		tmp.mesh.normal_map_name = engine.string_clone("metal_normal.png")
		tmp.mesh.color = raylib.WHITE
	}
	for !raylib.WindowShouldClose() {
		engine.game_tick()
	}
}
