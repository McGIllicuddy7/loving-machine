package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "ecs"
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
	fmt.printf("size of entity:%d, sizeof level:%d\n", size_of(game.Entity), size_of(game.Level))
	game.game_init()
	defer game.game_fini()
	register_systems_and_hooks()
	startup_logic()
	game.game_loop()
}

register_systems_and_hooks :: proc() {
	game.register_system("input", ecs.input_system)
	game.register_event_hook("event hook", ecs.event_handler)
}

startup_logic :: proc() {
	for _i in 0 ..< 100 {
		spawn_asteroid(
			{rand.float64() * 2 - 1, rand.float64() * 2 - 1, rand.float64() * 2 - 1} * 10.,
		)
	}
	spawn_base_ship({-20, 0, 0}, {1, 0, 0}, true)
}
