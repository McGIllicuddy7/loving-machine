package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "game"
import "game/engine"
import "vendor:raylib"
//3,490,216

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
	fmt.printf("MAPS:%d\n", raylib.MAX_MATERIAL_MAPS)
	for i in 0 ..< 100 {
		_, tmp := engine.create_entity(engine.Entity)
		sz := 20
		tmp.phys.position =
			{
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
			} *
			1
		tmp.phys.rotation = Quat(1)
		tmp.phys.height = 1.
		tmp.phys.width = 1.
		tmp.phys.length = 1.
		tmp.mesh.name = engine.string_clone("cube")
		tmp.mesh.color = raylib.WHITE
	}
	for !raylib.WindowShouldClose() {
		engine.game_tick()
	}
}
