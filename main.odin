package main
import "core:math/rand"
import "vendor:raylib"
import "xcx"
main :: proc() {
	raylib.InitWindow(1000, 800, "xcx")
	//	raylib.SetTargetFPS(61)
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
		xcx.draw_rectangle_raised(200, 200, 600, 400, .WHITE, 4., 2., 20)
		xcx.draw_text("my evil shader thing", 230, 220, 50, .BRIGHT_RED, 3.8, 0.1)
		colors: []xcx.Color = []xcx.Color {
			.BLACK,
			.RED,
			.YELLOW,
			.BRIGHT_RED,
			.EMMISIVE_RED,
			.EMMISIVE_YELLOW,
			.EMMISIVE_WHITE,
		}
		for dy in cast(i32)0 ..< 20 {
			for dx in cast(i32)0 ..< 25 {
				if dy * 40 >= 200 && dy * 40 <= 600 && dx * 40 >= 200 && dx * 40 <= 800 {
					continue
				}
				idx := rand.int31_max(cast(i32)len(colors))
				v := colors[idx]
				rd := rand.float32() * 5 + 2
				ht := rand.float32() * 2. + 5.
				xcx.draw_circle(dx * 40, dy * 40, rd, v, ht)
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
