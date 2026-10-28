package engine
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:strings"
import "core:sync"
import "vendor:raylib"
import "vendor:raylib/rlgl"
MAX_STAR_COUNT :: 8192

GraphicsObject :: struct {
	transform:      Transform,
	scale:          Vec3,
	mesh_id:        string,
	mesh_diffuse:   string,
	mesh_normal:    string,
	mesh_roughness: f32,
	mesh_metallic:  f32,
	tint:           raylib.Color,
}

@(private = "file")
GCmdDrawRectangle :: struct {
	x, y, width, height: i32,
	color:               raylib.Color,
}
@(private = "file")
GCmdDrawRectangleRounded :: struct {
	x, y, width, height: i32,
	color:               raylib.Color,
}

@(private = "file")
GCmdDrawCircle :: struct {
	x, y, radius: i32,
	color:        raylib.Color,
}

@(private = "file")
GCmdDrawTriangle :: struct {
	points: [3]raylib.Vector2,
	color:  raylib.Color,
}

@(private = "file")
GCmdDrawText :: struct {
	x, y, text_height: i32,
	content:           string,
	color:             raylib.Color,
}

@(private = "file")
GCmdDrawTexture :: struct {
	x, y, max_width, max_height: i32,
	name:                        string,
	color:                       raylib.Color,
}

@(private = "file")
GCmdBeginScissor :: struct {
	x, y, width, height: i32,
}

@(private = "file")
GCmdEndScissor :: struct {}

@(private = "file")
GCmdLoadModel :: struct {
	name:  string,
	model: raylib.Model,
}

@(private = "file")
GCmdEnsureModelLoaded :: struct {
	name: string,
}

@(private = "file")
GCmdEnsureTextureLoaded :: struct {
	name: string,
}

@(private = "file")
GCmdLoadTexture :: struct {
	name:    string,
	texture: raylib.Texture2D,
}


@(private = "file")
EGraphicsCommand :: union {
	GCmdDrawRectangle,
	GCmdDrawRectangleRounded,
	GCmdDrawTriangle,
	GCmdDrawCircle,
	GCmdDrawText,
	GCmdBeginScissor,
	GCmdEndScissor,
	GCmdDrawTexture,
	GCmdLoadModel,
	GCmdLoadTexture,
	GCmdEnsureModelLoaded,
	GCmdEnsureTextureLoaded,
}

GraphicsCommand :: struct {
	layer:   int,
	command: EGraphicsCommand,
}

GraphicsCommandBuffer :: struct {
	lock:            sync.Mutex,
	camera:          raylib.Camera3D,
	light_direction: raylib.Vector3,
	objects:         [dynamic]GraphicsObject,
	commands:        [dynamic]GraphicsCommand,
	arena:           mem.Dynamic_Arena,
}

GraphicsStar :: struct {
	pos:    raylib.Vector3,
	radius: f32,
}

GraphicsSkyBox :: struct {
	_lock:          sync.Mutex,
	sun_pos:        raylib.Vector3,
	sun_rad:        f32,
	star_count:     int,
	star_poses:     [MAX_STAR_COUNT]raylib.Vector3,
	star_rads:      [MAX_STAR_COUNT]raylib.Vector3,
	star_rotations: [MAX_STAR_COUNT]raylib.Quaternion,
	sky_color:      raylib.Color,
	sun_color:      raylib.Color,
	star_color:     raylib.Color,
}

GraphicsContext :: struct {
	meshes:               map[string]raylib.Model,
	textures:             map[string]raylib.Texture2D,
	light_depth_buffer:   raylib.RenderTexture2D,
	base_diffuse_map:     raylib.RenderTexture2D,
	base_normal_map:      raylib.RenderTexture2D,
	font:                 raylib.Font,
	shader:               raylib.Shader,
	material:             raylib.Material,
	particle_material:    raylib.Material,
	particle_shader:      raylib.Material,
	base_mat:             raylib.Material,
	swap_lock:            sync.Mutex,
	write_command_buffer: ^GraphicsCommandBuffer,
	read_command_buffer:  ^GraphicsCommandBuffer,
	sky_box:              GraphicsSkyBox,
}

@(private = "file")
command_buffer_write_lock :: proc() {
	ctx := get_graphics_context()
	sync.mutex_lock(&ctx.swap_lock)
	this := ctx.write_command_buffer
	sync.mutex_lock(&this.lock)
}

@(private = "file")
write_buffer_alloc :: proc() -> mem.Allocator {
	this := get_graphics_context().write_command_buffer
	return mem.dynamic_arena_allocator(&this.arena)
}

@(private = "file")
command_buffer_write_unlock :: proc() {
	ctx := get_graphics_context()
	this := ctx.write_command_buffer
	sync.mutex_unlock(&this.lock)
	sync.mutex_unlock(&ctx.swap_lock)
}

@(private = "file")
command_buffer_write_cmd :: proc(cmd: GraphicsCommand) {
	this := get_graphics_context().write_command_buffer
	append(&this.commands, cmd)
}

@(private = "file")
command_buffer_write_object :: proc(object: GraphicsObject) {
	this := get_graphics_context().write_command_buffer
	append(&this.objects, object)
}

@(private = "file")
graphics_register_mesh :: proc(name: string, mesh: raylib.Model) {
	this := get_graphics_context()
	assert(!(name in this.meshes))
	name := strings.clone(name)
	this.meshes[name] = mesh
}

@(private = "file")
graphics_register_texture :: proc(name: string, texture: raylib.Texture2D) {
	this := get_graphics_context()
	assert(!(name in this.textures))
	name := strings.clone(name)
	this.textures[name] = texture
}

@(private = "file")
graphics_ensure_mesh_registered :: proc(name: string) {
	this := get_graphics_context()
	if !(name in this.meshes) {
		path := fmt.ctprintf("assets/%s\n", name)
		md := raylib.LoadModel(path)
		name := strings.clone(name)
		this.meshes[name] = md
	}
}

@(private = "file")
graphics_ensure_texture_registered :: proc(name: string) {
	this := get_graphics_context()
	if !(name in this.textures) {
		path := fmt.ctprintf("assets/%s\n", name)
		md := raylib.LoadTexture(path)
		name := strings.clone(name)
		this.textures[name] = md
	}
}


get_graphics_context :: proc() -> ^GraphicsContext {
	return ENGINE.graphics_context
}


draw_rectangle :: proc(x, y, width, height: i32, color: raylib.Color, layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdDrawRectangle{x, y, width, height, color}
	command_buffer_write_cmd(cmd)
}
draw_rectangle_rounded :: proc(x, y, width, height: i32, color: raylib.Color, layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdDrawRectangleRounded{x, y, width, height, color}
	command_buffer_write_cmd(cmd)
}
draw_circle :: proc(x, y, radius: i32, color: raylib.Color, layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdDrawCircle{x, y, radius, color}
	command_buffer_write_cmd(cmd)
}
draw_text :: proc(text: string, x, y, text_height: i32, color: raylib.Color, layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	text := strings.clone(text, write_buffer_alloc())
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdDrawText{x, y, text_height, text, color}
	command_buffer_write_cmd(cmd)
}

draw_texture :: proc(
	id: string,
	x, y, max_width, max_height: i32,
	color: raylib.Color,
	layer := 0,
) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	id := strings.clone(id, write_buffer_alloc())
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdDrawTexture{x, y, max_width, max_height, id, color}
	command_buffer_write_cmd(cmd)
}

begin_scissor :: proc(x, y, width, height: i32, layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdBeginScissor{x, y, width, height}
	command_buffer_write_cmd(cmd)
}
end_scissor :: proc(layer := 0) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	cmd.layer = layer
	cmd.command = GCmdEndScissor{}
	command_buffer_write_cmd(cmd)
}

register_model :: proc(name: string, model: raylib.Model) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	name := strings.clone(name, write_buffer_alloc())
	cmd.layer = -1
	cmd.command = GCmdLoadModel{name, model}
	command_buffer_write_cmd(cmd)
}

ensure_model_loaded :: proc(name: string) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	name := strings.clone(name, write_buffer_alloc())
	cmd.layer = -1
	cmd.command = GCmdEnsureModelLoaded{name}
	command_buffer_write_cmd(cmd)
}

register_texture :: proc(name: string, texture: raylib.Texture2D) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	name := strings.clone(name, write_buffer_alloc())
	cmd.layer = -1
	cmd.command = GCmdLoadTexture{name, texture}
	command_buffer_write_cmd(cmd)
}

ensure_texture_loaded :: proc(name: string) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	cmd := GraphicsCommand{}
	name := strings.clone(name, write_buffer_alloc())
	cmd.layer = -1
	cmd.command = GCmdEnsureTextureLoaded{name}
	command_buffer_write_cmd(cmd)
}

bind_model :: proc(
	mesh_id: string,
	transform: Transform,
	scale: Vec3,
	tint: raylib.Color,
	diffuse: string = "",
	normal: string = "",
	roughness: f32 = 1.,
	metallic: f32 = 0.,
) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	object := GraphicsObject{}
	object.mesh_id = strings.clone(mesh_id, write_buffer_alloc())
	object.mesh_diffuse = strings.clone(diffuse, write_buffer_alloc())
	object.mesh_normal = strings.clone(normal, write_buffer_alloc())
	object.mesh_roughness = roughness
	object.mesh_metallic = metallic
	object.transform = transform
	object.scale = scale
	object.tint = tint
	command_buffer_write_object(object)
}

set_camera :: proc(camera: raylib.Camera3D) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	get_graphics_context().write_command_buffer.camera = camera
}

draw_graphics_objects :: proc(
	this: ^GraphicsContext,
	meshes: []GraphicsObject,
	camera: raylib.Camera3D,
	light_camera: raylib.Camera,
	depth_pass: bool,
) {
	dir_loc := raylib.GetShaderLocation(this.shader, "light_direction")
	//assert(dir_loc != -1)
	tmp := linalg.normalize(raylib.Vector3{0, 0, -1})
	raylib.SetShaderValue(this.shader, dir_loc, &tmp, .VEC3)
	rough_loc := raylib.GetShaderLocation(this.shader, "roughness")
	metal_loc := raylib.GetShaderLocation(this.shader, "metallic")
	depth_pass_loc := raylib.GetShaderLocation(this.shader, "is_depth_pass")
	{
		tmp: i32 = 1 if depth_pass else 0
		raylib.SetShaderValue(this.shader, depth_pass_loc, &tmp, .INT)
		tmp2: raylib.Camera3D = light_camera
		cam_mat := raylib.GetCameraProjectionMatrix(&tmp2, 1.) * raylib.GetCameraMatrix(tmp2)
		cam_mat_loc := raylib.GetShaderLocation(this.shader, "light_matrix")
		raylib.BeginMode3D(light_camera)
		light_view := rlgl.GetMatrixModelview()
		light_proj := rlgl.GetMatrixProjection()
		light_view_proj := light_view * light_proj
		raylib.SetShaderValueMatrix(this.shader, cam_mat_loc, cam_mat)
		raylib.EndMode3D()
		//assert(cam_mat_loc != -1)
		//		fmt.printf("%v\n", light_view_proj)

	}
	diffuse_col_loc := raylib.GetShaderLocation(this.shader, "colDiffuse")
	raylib.BeginMode3D(camera)
	rlgl.SetClipPlanes(0.01, 1000.)
	if !depth_pass {
		rlgl.DisableDepthMask()
		rlgl.DisableDepthTest()
		trans := make_slice([]raylib.Matrix, MAX_STAR_COUNT)
		defer delete(trans)
		for i in 0 ..< this.sky_box.star_count {
			trans[i] = raylib.MatrixCompose(
				this.sky_box.star_poses[i] + camera.position,
				this.sky_box.star_rotations[i],
				this.sky_box.star_rads[i],
			)
		}
		raylib.DrawMeshInstanced(
			this.meshes["star"].meshes[0],
			this.particle_material,
			&trans[0],
			cast(i32)this.sky_box.star_count,
		)
		rlgl.EnableDepthMask()
		rlgl.EnableDepthTest()
	}
	for &i in this.read_command_buffer.objects {
		if !(i.mesh_id in this.meshes) {
			continue
		}
		pos := cast([3]f32)i.transform.position
		scale := cast(raylib.Vector3)i.scale
		base_rot := i.transform.rotation
		pi :: math.PI
		if i.mesh_id == "cylinder" {
			base_rot = base_rot * linalg.quaternion_from_euler_angles_f64(0., 00., pi / 2, .XYZ)
		}
		msh := &this.meshes[i.mesh_id]
		trans := raylib.MatrixCompose(pos, cast(raylib.Quaternion)base_rot, scale)
		if !depth_pass {
			c_col := cast([4]f32)i.tint / 255.
			raylib.SetShaderValue(this.shader, diffuse_col_loc, &c_col, .VEC4)
			if i.mesh_diffuse != "" {
				this.material.maps[0].texture = this.textures[i.mesh_diffuse]
			} else {
				this.material.maps[0].texture = this.base_diffuse_map.texture
			}
			if i.mesh_normal != "" {
				this.material.maps[1].texture = this.textures[i.mesh_normal]
			} else {
				this.material.maps[1].texture = this.base_normal_map.texture
			}
			if depth_pass {
				this.material.maps[2].texture = this.base_diffuse_map.texture
			} else {
				this.material.maps[2].texture = this.light_depth_buffer.depth
			}
			raylib.SetShaderValue(this.shader, rough_loc, &i.mesh_roughness, .FLOAT)
			raylib.SetShaderValue(this.shader, metal_loc, &i.mesh_metallic, .FLOAT)
		}
		for j in 0 ..< msh.meshCount {
			cur := msh.meshes[j]
			if depth_pass {
				raylib.DrawMesh(cur, this.base_mat, trans)
			} else {
				raylib.DrawMesh(cur, this.material, trans)
			}

		}
	}
	//	rlgl.DisableDepthMask()
	//rlgl.DisableDepthTest()
	raylib.EndMode3D()

}

take_sky_box :: proc() -> ^GraphicsSkyBox {
	out := &get_graphics_context().sky_box
	sync.mutex_lock(&out._lock)
	return out
}

release_sky_box :: proc(box: ^GraphicsSkyBox) {
	sync.mutex_unlock(&box._lock)
}

graphics_step :: proc() {
	bx := take_sky_box()
	defer release_sky_box(bx)
	this := get_graphics_context()
	max_layer_idx := 0
	for i in this.read_command_buffer.commands {
		if i.layer > max_layer_idx {
			max_layer_idx = i.layer
		}
		if i.layer == -1 {
			switch v in i.command {
			case GCmdDrawRectangle:
			case GCmdDrawRectangleRounded:
			case GCmdDrawTriangle:
			case GCmdDrawCircle:
			case GCmdDrawText:
			case GCmdBeginScissor:
			case GCmdEndScissor:
			case GCmdDrawTexture:
			case GCmdLoadModel:
				graphics_register_mesh(v.name, v.model)
			case GCmdLoadTexture:
				graphics_register_texture(v.name, v.texture)
			case GCmdEnsureModelLoaded:
				graphics_ensure_mesh_registered(v.name)
			case GCmdEnsureTextureLoaded:
				graphics_ensure_texture_registered(v.name)
			}
		}
	}
	{

		light_dir := this.read_command_buffer.light_direction
		light_cam: raylib.Camera3D
		light_cam.position = {0, 0, 1024} + this.read_command_buffer.camera.position
		light_cam.fovy = 50.
		light_cam.projection = .ORTHOGRAPHIC
		light_cam.target = {0, 0, 0}
		light_cam.up = {0, 1, 0}
		light_pos_loc := raylib.GetShaderLocation(this.shader, "light_pos")
		{
			view_pos_loc := raylib.GetShaderLocation(this.shader, "view_pos")
			raylib.SetShaderValue(this.shader, view_pos_loc, &{}, .VEC3)
		}
		{
			light_col_loc := raylib.GetShaderLocation(this.shader, "light_color")
			col: [4]f32
			base_col: raylib.Color = {255, 254, 253, 0}
			col.rgb = cast([3]f32)base_col.rgb / 255.
			col.a = 1.
			raylib.SetShaderValue(this.shader, light_col_loc, &col, .VEC4)

		}
		raylib.SetShaderValue(this.shader, light_pos_loc, &light_cam.position, .VEC3)
		{
			raylib.BeginTextureMode(this.light_depth_buffer)
			raylib.ClearBackground(raylib.WHITE)
			draw_graphics_objects(
				this,
				this.read_command_buffer.objects[:],
				light_cam,
				light_cam,
				true,
			)
			raylib.EndTextureMode()
		}
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		@(static) dbg := false
		if raylib.IsKeyPressed(.SPACE) {
			dbg = !dbg
		}
		if dbg {
			raylib.DrawTexture(this.light_depth_buffer.depth, 0, 0, raylib.WHITE)
		} else {
			{
				draw_graphics_objects(
					this,
					this.read_command_buffer.objects[:],
					this.read_command_buffer.camera,
					light_cam,
					false,
				)
			}
		}
		for layer in 0 ..= max_layer_idx {
			for i in this.read_command_buffer.commands {
				if i.layer != layer {
					continue
				}
				switch v in i.command {
				case GCmdDrawRectangle:
					{
						raylib.DrawRectangle(v.x, v.y, v.width, v.height, v.color)
					}
				case GCmdDrawRectangleRounded:
					{
						raylib.DrawRectangleRounded(
							{cast(f32)v.x, cast(f32)v.y, cast(f32)v.width, cast(f32)v.height},
							0.1,
							16,
							v.color,
						)
					}
				case GCmdDrawTriangle:
					{
						raylib.DrawTriangle(v.points[0], v.points[1], v.points[2], v.color)
					}
				case GCmdDrawCircle:
					{
						raylib.DrawCircle(v.x, v.y, cast(f32)v.radius, v.color)
					}
				case GCmdDrawText:
					{
						raylib.DrawTextEx(
							this.font,
							strings.clone_to_cstring(v.content, context.temp_allocator),
							[2]f32{cast(f32)v.x, cast(f32)v.y},
							cast(f32)v.text_height,
							1.,
							v.color,
						)

					}
				case GCmdBeginScissor:
					{
						raylib.BeginScissorMode(v.x, v.y, v.width, v.height)
					}
				case GCmdEndScissor:
					{
						raylib.EndScissorMode()
					}
				case GCmdDrawTexture:
					{
						if !(v.name in this.textures) {
							continue
						}
						texture := this.textures[v.name]
						tw := cast(f32)texture.width
						th := cast(f32)texture.height
						w := cast(f32)v.max_width
						h := cast(f32)v.max_height
						aspect_ratio := cast(f32)texture.height / cast(f32)texture.width
						dh := w * aspect_ratio
						dw := w
						if aspect_ratio * w > h {
							dh = h
							dw = h / aspect_ratio
						}
						x := cast(f32)v.x
						y := cast(f32)v.y
						raylib.DrawTexturePro(
							texture,
							{0., 0., tw, th},
							{x, y, w, h},
							{0, 0},
							0.,
							v.color,
						)
					}
				case GCmdLoadModel:
				case GCmdLoadTexture:
				case GCmdEnsureModelLoaded:
				case GCmdEnsureTextureLoaded:
				}
			}
		}
		render_logs()
		raylib.EndDrawing()
		update_logs()
		{
			reset_cmd_buffer(this.read_command_buffer)
			sync.mutex_lock(&this.swap_lock)
			defer sync.mutex_unlock(&this.swap_lock)
			tmp := this.write_command_buffer
			this.write_command_buffer = this.read_command_buffer
			this.read_command_buffer = tmp
		}
	}
}

reset_cmd_buffer :: proc(buffer: ^GraphicsCommandBuffer) {
	clear(&buffer.commands)
	clear(&buffer.objects)
	mem.dynamic_arena_free_all(&buffer.arena)
}

destroy_cmd_buffer :: proc(buffer: ^GraphicsCommandBuffer) {
	delete(buffer.commands)
	delete(buffer.objects)
	mem.dynamic_arena_destroy(&buffer.arena)
	free(buffer)
}

create_command_buffer :: proc() -> ^GraphicsCommandBuffer {
	out := new(GraphicsCommandBuffer)
	out.objects = make([dynamic]GraphicsObject)
	out.commands = make([dynamic]GraphicsCommand)
	out.camera.fovy = 90.
	out.camera.position = {0, 0, 0}
	out.camera.target = {1, 0, 0}
	out.camera.up = {0, 0, 1}
	out.camera.projection = .PERSPECTIVE
	mem.dynamic_arena_init(&out.arena)
	return out
}

create_graphics_context :: proc() -> ^GraphicsContext {
	raylib.InitWindow(1000, 1000, "hello window!")
	raylib.SetTargetFPS(61)
	{
		raylib.BeginDrawing()
		raylib.EndDrawing()
	}
	raylib.DisableCursor()
	out := new(GraphicsContext)
	out.meshes = make(map[string]raylib.Model)
	out.textures = make(map[string]raylib.Texture)
	{
		cube := raylib.GenMeshCube(1., 1., 1.)
		cube_model := raylib.LoadModelFromMesh(cube)
		out.meshes[strings.clone("cube")] = cube_model
		sphere := raylib.GenMeshSphere(0.5, 16, 16)
		sphere_model := raylib.LoadModelFromMesh(sphere)
		out.meshes[strings.clone("sphere")] = sphere_model
		cylinder := raylib.GenMeshCylinder(0.5, 1., 16)
		cylinder_model := raylib.LoadModelFromMesh(cylinder)
		out.meshes[strings.clone("cylinder")] = cylinder_model
		cone := raylib.GenMeshCone(0.5, 1., 16)
		cone_model := raylib.LoadModelFromMesh(cone)
		out.meshes[strings.clone("cone")] = cone_model
		torus := raylib.GenMeshTorus(0.5, 1., 16, 16)
		torus_model := raylib.LoadModelFromMesh(torus)
		out.meshes[strings.clone("torus")] = torus_model
		star_model := raylib.LoadModelFromMesh(raylib.GenMeshSphere(1., 3, 3))
		out.meshes[strings.clone("star")] = star_model

	}
	{
		out.light_depth_buffer = _create_shadowmap(1024, 1024)
	}
	{
		out.base_diffuse_map = raylib.LoadRenderTexture(1000, 1000)
		raylib.BeginTextureMode(out.base_diffuse_map)
		raylib.ClearBackground(raylib.WHITE)
		raylib.EndTextureMode()
	}
	{
		out.base_normal_map = raylib.LoadRenderTexture(1000, 1000)
		raylib.BeginTextureMode(out.base_normal_map)
		raylib.ClearBackground(raylib.BLUE)
		raylib.EndTextureMode()
	}
	{
		STAR_COUNT :: 2048
		#assert(STAR_COUNT < MAX_STAR_COUNT)
		out.sky_box.star_count = STAR_COUNT
		out.sky_box.sun_pos = {0, 50, 1000}
		out.sky_box.sun_rad = 1.
		out.sky_box.sun_color = raylib.WHITE
		out.sky_box.star_color = {250, 250, 255, 255}
		out.sky_box.sky_color = {0, 0, 50, 255}
		rng_state := rand.PCG_Random_State{1917, 6162004}
		rng := rand.pcg_random_generator(&rng_state)
		for i in 0 ..< out.sky_box.star_count {
			theta := rand.float32_range(0., 2 * math.PI, rng)
			phi := rand.float32_range(0., 2 * math.PI, rng)
			rad := rand.float32_range(0.9, 1)
			sz := rand.float32_range(0.8, 1.1)
			x := math.cos(theta) * math.sin(phi) * rad * 500.
			y := math.sin(theta) * math.sin(phi) * rad * 500.
			z := math.cos(phi) * rad * 500.
			out.sky_box.star_poses[i] = {x, y, z}
			out.sky_box.star_rotations[i] = raylib.QuaternionFromEuler(
				rand.float32_range(0., 2 * math.PI, rng),
				rand.float32_range(0., 2 * math.PI, rng),
				rand.float32_range(0., 2 * math.PI, rng),
			)
			out.sky_box.star_rads[i] = sz
		}
	}
	{
		out.particle_material = raylib.LoadMaterialDefault()
		out.particle_material.shader = raylib.LoadShader("instance.vert", "instance.frag")
	}
	out.shader = raylib.LoadShader("main.vert", "main.frag")
	out.base_mat = raylib.LoadMaterialDefault()
	out.material = raylib.LoadMaterialDefault()
	out.material.shader = out.shader
	out.font = raylib.LoadFont("Ac437_IBM_VGA_9x16.ttf")
	out.write_command_buffer = create_command_buffer()
	out.read_command_buffer = create_command_buffer()
	return out
}

_create_shadowmap :: proc(width: i32, height: i32) -> raylib.RenderTexture2D {
	//https://github.com/raysan5/raylib/blob/master/examples/shaders/shaders_shadowmap_rendering.c
	out: raylib.RenderTexture2D
	out.id = rlgl.LoadFramebuffer()
	out.texture.width = width
	out.texture.height = height
	rlgl.EnableFramebuffer(out.id)
	out.depth.id = rlgl.LoadTextureDepth(width, height, false)
	out.depth.width = width
	out.depth.height = height
	out.depth.format = cast(raylib.PixelFormat)19
	out.depth.mipmaps = 1
	rlgl.FramebufferAttach(
		out.id,
		out.depth.id,
		cast(i32)rlgl.FramebufferAttachType.DEPTH,
		cast(i32)rlgl.FramebufferAttachTextureType.TEXTURE2D,
		0,
	)
	if (rlgl.FramebufferComplete(out.id)) {
		raylib.TraceLog(.INFO, "FBO: [ID %i] Framebuffer object created successfully", out.id)
		rlgl.DisableFramebuffer()
	} else {
		raylib.TraceLog(.WARNING, "FBO: Framebuffer object can not be created")
	}
	return out
}
_unload_shadowmap_render_texture :: proc(target: raylib.RenderTexture2D) {
	if (target.id > 0) {
		rlgl.UnloadFramebuffer(target.id)
	}
}

destroy_graphics_context :: proc(this: ^GraphicsContext) {
	for key, value in this.meshes {
		raylib.UnloadModel(value)
		delete(key)
	}
	for key, value in this.textures {
		raylib.UnloadTexture(value)
		delete(key)
	}
	delete(this.meshes)
	delete(this.textures)
	raylib.UnloadFont(this.font)
	raylib.UnloadShader(this.shader)
	destroy_cmd_buffer(this.read_command_buffer)
	destroy_cmd_buffer(this.write_command_buffer)
	free(this)
}

render_logs :: proc() {
	this := &ENGINE.logs
	sync.mutex_lock(&this.lock)
	defer sync.mutex_unlock(&this.lock)
	height := cast(int)len(this.values)
	if (height > 32) {
		height = 32
	}
	dy := 800 - 25 * height
	start := 0
	if (len(this.values) > 32) {
		start = len(this.values) - 32
	}
	lgs := this.values[start:]
	for i in lgs {
		raylib.DrawTextEx(
			get_graphics_context().font,
			i.content,
			{0, cast(f32)dy},
			25.,
			1.,
			raylib.DARKGREEN,
		)
		dy += 25
	}
}

update_logs :: proc() {
	this := &ENGINE.logs
	sync.mutex_lock(&this.lock)
	defer sync.mutex_unlock(&this.lock)
	out_set := make([dynamic]Log)
	ft := raylib.GetFrameTime()
	for i in 0 ..< len(this.values) {
		this.values[i].remaining_time -= cast(f64)ft
		if this.values[i].remaining_time >= 0. {
			append(&out_set, this.values[i])
		} else {
			delete(this.values[i].content)
		}
	}
	delete(this.values)
	this.values = out_set
}
