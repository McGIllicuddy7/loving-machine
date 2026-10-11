package xcx

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:mem"
import "vendor:raylib"
SCREEN_WIDTH_UNITS :: 1.9
SCREEN_HEIGHT_UNITS :: 1.5

WorldObjectKind :: enum {
	Box,
	Sphere,
}

WorldObject :: struct {
	kind:               WorldObjectKind,
	color:              raylib.Color,
	emmisive_color:     raylib.Color,
	emmisive_color_mul: f32,
	pos:                linalg.Vector3f32,
	scale:              linalg.Vector3f32,
	rotation:           quaternion128,
}

World :: struct {
	object_arena: mem.Dynamic_Arena,
	objects:      [dynamic]^WorldObject,
	camera:       raylib.Camera3D,
	shader:       raylib.Shader,
	old_shader:   raylib.Shader,
	cube_mesh:    raylib.Mesh,
	sphere_mesh:  raylib.Mesh,
	cone_mesh:    raylib.Mesh,
	torus_mesh:   raylib.Mesh,
	material:     raylib.Material,
	light_pos:    linalg.Vector3f32,
	light_color:  raylib.Color,
	depth_map:    raylib.RenderTexture2D,
}

world_draw_objects :: proc(this: ^World) {
	col_diffuse_loc := raylib.GetShaderLocation(this.shader, "colDiffuse")
	col_emmisive_loc := raylib.GetShaderLocation(this.shader, "colEmmisive")
	for i in this.objects {
		cl := (cast([4]f32)i.color) / 255.
		cr := cast([4]f32)i.emmisive_color / 255 * i.emmisive_color_mul
		raylib.SetShaderValue(this.shader, col_diffuse_loc, &cl, .VEC4)
		raylib.SetShaderValue(this.shader, col_emmisive_loc, &cr, .VEC4)
		switch i.kind {
		case .Box:
			raylib.DrawMesh(
				this.cube_mesh,
				this.material,
				raylib.MatrixCompose(i.pos, i.rotation, i.scale),
			)
		case .Sphere:
			raylib.DrawMesh(
				this.sphere_mesh,
				this.material,
				raylib.MatrixCompose(i.pos, i.rotation, i.scale),
			)
		}
	}
}

world_create :: proc() -> ^World {
	out := new(World)
	out.objects = make([dynamic]^WorldObject)
	mem.dynamic_arena_init(&out.object_arena)
	out.camera.fovy = 90.
	out.camera.position = {0, 0, 0.8}
	out.camera.target = {0, 0, 0}
	out.camera.up = {0, 1, 0}
	out.camera.projection = .PERSPECTIVE
	out.depth_map = raylib.LoadRenderTexture(raylib.GetScreenWidth(), raylib.GetScreenHeight())
	SCALE :: 0.1
	out.cube_mesh = raylib.GenMeshCube(1. * SCALE, 1. * SCALE, 1. * SCALE)
	out.sphere_mesh = raylib.GenMeshSphere(1. * SCALE, 32, 32)
	out.cone_mesh = raylib.GenMeshCone(1. * SCALE, 1. * SCALE, 32)
	out.torus_mesh = raylib.GenMeshTorus(1. * SCALE, 1. * SCALE, 32, 32)
	out.material = raylib.LoadMaterialDefault()
	out.old_shader = out.material.shader
	out.shader = raylib.LoadShader("xcx/xcx_vert.vert", "xcx/xcx_frag.frag")
	out.material.shader = out.shader
	out.light_pos = {0, -0.2, .8}
	out.light_color = raylib.WHITE
	return out
}

world_destroy :: proc(this: ^World) {
	delete(this.objects)
	mem.dynamic_arena_destroy(&this.object_arena)
	raylib.UnloadMesh(this.cone_mesh)
	raylib.UnloadMesh(this.sphere_mesh)
	raylib.UnloadMesh(this.torus_mesh)
	raylib.UnloadMesh(this.cube_mesh)
	this.material.shader = this.old_shader
	raylib.UnloadMaterial(this.material)
	raylib.UnloadShader(this.shader)
	free(this)
}

world_render :: proc(this: ^World) {

	drawing_depth_loc := raylib.GetShaderLocation(this.shader, "rendering_depth_mode")
	drawing_depth_value: i32 = 1
	mtx := raylib.Camera{}
	mtx.fovy = 90
	mtx.position = this.light_pos
	mtx.projection = .PERSPECTIVE
	mtx.target = {0, 0., 0.}
	mtx.up = {0, 1, 0}
	{
		camera_position_loc := raylib.GetShaderLocation(this.shader, "camera_position")
		raylib.SetShaderValue(this.shader, camera_position_loc, &this.camera.position, .VEC3)
		light_position_loc := raylib.GetShaderLocation(this.shader, "input_light_pos")
		raylib.SetShaderValue(this.shader, light_position_loc, &this.light_pos, .VEC3)
	}

	raylib.SetShaderValue(this.shader, drawing_depth_loc, &drawing_depth_value, .INT)
	{
		raylib.BeginMode3D(this.camera)
		cl := to_vec4_color(this.light_color)
		col_idx := raylib.GetShaderLocation(this.shader, "input_light_color")
		assert(col_idx != -1)
		raylib.SetShaderValue(this.shader, col_idx, &cl, .VEC4)
		world_draw_objects(this)
		raylib.EndMode3D()
	}

}

world_create_object :: proc(
	this: ^World,
	kind: WorldObjectKind,
	color: raylib.Color,
	position: raylib.Vector3,
	scale: raylib.Vector3,
	rotation := quaternion128(1),
) -> ^WorldObject {
	obj := new(WorldObject, mem.dynamic_arena_allocator(&this.object_arena))
	obj.kind = kind
	obj.color = color
	obj.pos = position
	obj.scale = scale
	obj.rotation = rotation
	append(&this.objects, obj)
	return obj
}

world_reset :: proc(this: ^World) {
	clear(&this.objects)
	mem.dynamic_arena_reset(&this.object_arena)
}

to_vec4_color :: proc(col: raylib.Color) -> linalg.Vector4f32 {
	return (cast([4]f32)col) / 255.
}
