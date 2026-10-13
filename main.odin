package main
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "engine/physics"
import "vendor:raylib"
ObjectSet :: struct {
	values: []physics.TaggedPhysicsObject,
}

make_object_set :: proc() -> ObjectSet {
	out: ObjectSet
	i := 0
	DZ :: 10
	DY :: 10
	DX :: 10
	count := (DX * 2 + 1) * (DY * 2 + 1) * (DZ * 2 + 1) - 1
	out.values = make_slice([]physics.TaggedPhysicsObject, count)
	for dz in -DZ ..= DZ {
		for dy in -DY ..= DY {
			for dx in -DX ..= DX {
				if (dx == 0 && dy == 0 && dz == 0) {
					continue
				}
				pos := physics.Vec3{cast(f64)dx, cast(f64)dy, cast(f64)dz}
				vel := physics.Vec3 {
					rand.float64() * 2 - 1,
					rand.float64() * 2 - 1,
					rand.float64() * 2. - 1,
				}
				obj := new(physics.PhysicsObject)
				obj.height = 0.5
				obj.width = .5
				obj.length = 0.5
				obj.rotation = quaternion256(1)
				obj.velocity = vel
				obj.position = pos * 10.
				out.values[i] = {{cast(u32)i, 0}, obj}
				i += 1
			}
		}
	}
	return out
}

main :: proc() {
	raylib.InitWindow(1000, 1000, "gay")
	defer raylib.CloseWindow()
	camera := raylib.Camera3D {
		position   = {0, 0, 0},
		up         = {0, 0, 1},
		target     = {1, 0, 0},
		fovy       = 90.,
		projection = .PERSPECTIVE,
	}
	objects := make_object_set()
	frame_arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&frame_arena)
	frame_allocator := mem.dynamic_arena_allocator(&frame_arena)
	for !raylib.WindowShouldClose() {
		events := physics.physics_update(objects.values, 1. / 60., frame_allocator)
		delete(events)
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		raylib.UpdateCamera(&camera, .FREE)
		raylib.BeginMode3D(camera)
		for i in objects.values {
			disp: raylib.Vector3 = {0.25, 0.25, 0.25}
			pos: raylib.Vector3 = cast(raylib.Vector3)i.ptr.position
			bx: raylib.BoundingBox = {pos - disp, pos + disp}
			//	raylib.DrawBoundingBox(bx, raylib.GREEN)
		}
		raylib.EndMode3D()
		raylib.DrawFPS(850, 50)
		raylib.EndDrawing()
		mem.dynamic_arena_reset(&frame_arena)

	}
}
