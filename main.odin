package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import "vendor:raylib"
import "xcx"
main :: proc() {
	raylib.InitWindow(1000, 800, "xcx")
	raylib.SetTargetFPS(61)
	defer raylib.CloseWindow()
	{
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		raylib.EndDrawing()
	}
	world := xcx.world_create()
	defer xcx.world_destroy(world)
	for !raylib.WindowShouldClose() {
		xcx.world_reset(world)
		//15*10
		//19*10
		//raylib.UpdateCamera(&world.camera, .FREE)
		xcx.world_create_object(world, .Box, raylib.WHITE, {0., 0., 0.}, {10., 10., 2.})
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		xcx.world_render(world)
		raylib.DrawFPS(850, 50)
		raylib.EndDrawing()
	}
}
