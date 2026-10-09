package main
import "core:fmt"
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
	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		raylib.DrawFPS(850, 50)
		raylib.EndDrawing()
	}
}
