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
	game.game_init()
	defer game.game_fini()
	register_systems_and_hooks()
	startup_logic()
	game.game_loop()
}

register_systems_and_hooks :: proc() {
	game.register_system("gay sex:3", proc(delta_time: f32) {
		engine.draw_rectangle_rounded(250, 250, 500, 25, raylib.DARKGRAY)
		engine.draw_text("henlo toast i love you", 300, 254, 16, raylib.DARKGREEN)
	})
}

startup_logic :: proc() {
	engine.log("hello world!", 40.)
	engine.log("hello toast i love you<3", 40.)
	for i in 0 ..< 25 {
		engine.log(fmt.tprintf("%d", i), cast(f64)i)
	}
}
