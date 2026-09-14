
package main
import "core:math"
import "core:math/rand"
import "vendor:raylib"
rl :: raylib
EntityType :: enum {}
Entity :: struct {
	type:      EntityType,
	name:      string,
	position:  rl.Vector3,
	velocity:  rl.Vector3,
	rotation:  rl.Quaternion,
	health:    u32,
	is_player: bool,
}

EntityRef :: struct {
	idx: u32,
	gen: u32,
}

EntityBox :: struct {
	exists: bool,
	gen:    u32,
	entity: Entity,
}

StaticObject :: struct {
	mesh_name: string,
	transform: rl.Transform,
	color:     rl.Color,
}
ENTITY_COUNT :: 16384

Runtime :: struct {
	entities:      [ENTITY_COUNT]EntityBox,
	objects:       [dynamic]StaticObject,
	loaded_meshes: map[string]rl.Model,
	camera:        rl.Camera3D,
}

@(private)
runtime: Runtime

setup_runtime :: proc() {
	rl.InitWindow(640 * 2, 480 * 2, "hello window!")
	runtime.loaded_meshes = make(map[string]rl.Model)
	map_insert(&runtime.loaded_meshes, "cube", rl.LoadModelFromMesh(rl.GenMeshCube(1., 1., 1.)))
	runtime.camera.fovy = 90.
	runtime.camera.position = {0, 0, 0}
	runtime.camera.projection = rl.CameraProjection.PERSPECTIVE
	runtime.camera.target = {1, 0, 0}
	runtime.camera.up = {0, 0, 1}
}

teardown_runtime :: proc() {
	for _, i in runtime.loaded_meshes {
		rl.UnloadModel(i)
	}
	delete(runtime.objects)
	rl.CloseWindow()
	rl.CloseAudioDevice()
}


runtime_step :: proc() {
	rl.UpdateCamera(&runtime.camera, rl.CameraMode.FREE)
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode3D(runtime.camera)
	for i in runtime.objects {
		axis, angle := rl.QuaternionToAxisAngle(i.transform.rotation)
		rl.DrawModelEx(
			runtime.loaded_meshes[i.mesh_name],
			i.transform.translation,
			axis,
			angle,
			i.transform.scale,
			i.color,
		)
	}
	rl.EndMode3D()
	rl.EndDrawing()
}


gen_map_debug :: proc() {
	for _i in 0 ..< 1000 {
		hue := cast(f32)(rand.uint32() % 360)
		x := cast(i32)(rand.uint32() % 100) - 50
		y := cast(i32)(rand.uint32() % 100) - 50
		z := cast(i32)(rand.uint32() % 100) - 50
		ex := cast(f32)(rand.uint32() % 360)
		ey := cast(f32)(rand.uint32() % 360)
		tmp: StaticObject
		sx := cast(f32)(rand.uint32() % 10) / 10. + 0.5
		sy := cast(f32)(rand.uint32() % 10) / 10. + 0.5
		sz := cast(f32)(rand.uint32() % 10) / 10. + 0.5
		tmp.transform.scale = {sx, sy, sz}
		tmp.transform.rotation = rl.QuaternionFromEuler(ex, ey, 0.0)
		tmp.transform.translation = {cast(f32)x, cast(f32)y, cast(f32)z}
		tmp.mesh_name = "cube"
		tmp.color = rl.ColorFromHSV(hue, 1., 1.)
		append_elem(&runtime.objects, tmp)
	}
}
