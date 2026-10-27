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
}
