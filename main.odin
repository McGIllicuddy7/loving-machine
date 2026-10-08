package main
import "core:math/rand"
import "vendor:raylib"
import "xcx"
main :: proc() {
	raylib.InitWindow(1000, 800, "xcx")
	defer raylib.CloseWindow()
	{
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		raylib.EndDrawing()
	}
	obj := xcx.create_object(1000, 800)
	defer xcx.destroy_object(obj)
	regenerate_obj :: proc(obj: ^xcx.Object) {
		xcx.begin_editing(obj)
		xcx.clear_background(.BRIGHT_BLACK, 0., 0.)
		xcx.draw_rectangle_raised(200, 200, 600, 400, .WHITE, 2., 4., 20)
		for dy in cast(i32)0 ..< 40 {
			for dx in cast(i32)0 ..< 50 {
				if dy >= 10 && dy <= 20 && dx >= 10 && dx <= 30 {
					continue
				}
				v := cast(xcx.Color)rand.int31_max(24)
				rd := rand.float32() * 5
				ht := rand.float32() * 2. + 2.
				xcx.draw_circle(dx * 20, dy * 20, rd, v, ht)
			}
		}
		xcx.end_editing(obj)
	}
	regenerate_obj(obj)
	for !raylib.WindowShouldClose() {
		xcx.process_object(obj)
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		if raylib.IsKeyPressed(.S) {
			obj.dbg = true
			obj.dbg_normals = false
		}
		if raylib.IsKeyPressed(.H) {
			obj.dbg = false
			obj.dbg_normals = false
		}
		if raylib.IsKeyPressed(.N) {
			obj.dbg = false
			obj.dbg_normals = true
		}
		if raylib.IsKeyPressed(.R) {
			regenerate_obj(obj)
		}
		xcx.render_object(obj, 0, 0, 1000, 800)
		raylib.DrawFPS(850, 50)
		raylib.EndDrawing()
	}
}
