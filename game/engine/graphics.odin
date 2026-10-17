package engine
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import "core:sync"
import "vendor:raylib"

GraphicsObject :: struct {
	transform: Transform,
	scale:     Vec3,
	mesh_id:   string,
	tint:      raylib.Color,
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

GraphicsContext :: struct {
	meshes:               map[string]raylib.Model,
	textures:             map[string]raylib.Texture2D,
	font:                 raylib.Font,
	shader:               raylib.Shader,
	swap_lock:            sync.Mutex,
	write_command_buffer: ^GraphicsCommandBuffer,
	read_command_buffer:  ^GraphicsCommandBuffer,
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

bind_model :: proc(mesh_id: string, transform: Transform, scale: Vec3, tint: raylib.Color) {
	command_buffer_write_lock()
	defer command_buffer_write_unlock()
	object := GraphicsObject{}
	object.mesh_id = strings.clone(mesh_id, write_buffer_alloc())
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

graphics_step :: proc() {
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
	raylib.BeginDrawing()
	raylib.ClearBackground(raylib.BLACK)
	raylib.BeginMode3D(this.read_command_buffer.camera)
	{
		dir_loc := raylib.GetShaderLocation(this.shader, "light_direction")
		assert(dir_loc != -1)
		tmp := linalg.normalize(raylib.Vector3{2, 0, 1})
		raylib.SetShaderValue(this.shader, dir_loc, &tmp, .VEC3)
	}
	//	raylib.BeginShaderMode(this.shader)
	for i in this.read_command_buffer.objects {
		if !(i.mesh_id in this.meshes) {
			continue
		}
		angle, rot_axis := linalg.angle_axis_from_quaternion_f64(i.transform.rotation)
		pos := cast(raylib.Vector3)i.transform.position
		scale := cast(raylib.Vector3)i.scale
		msh := &this.meshes[i.mesh_id]
		old_shade := msh.materials[0].shader
		msh.materials[0].shader = this.shader
		base_rot := Quat(1)
		pi :: math.PI
		if i.mesh_id == "cylinder" || true {
			base_rot = linalg.quaternion_from_euler_angles_f64(0., 00., pi / 2, .XYZ)
		}
		msh.transform =
			raylib.MatrixCompose(pos, cast(quaternion128)i.transform.rotation, scale) *
			raylib.MatrixCompose({}, cast(quaternion128)base_rot, {1, 1, 1})
		raylib.DrawModel(msh^, {}, 1., i.tint)
		msh.materials[0].shader = old_shade
	}
	//	raylib.EndShaderMode()
	raylib.EndMode3D()
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
	}
	out.shader = raylib.LoadShader("main.vert", "main.frag")
	out.font = raylib.LoadFont("Ac437_IBM_VGA_9x16.ttf")
	out.write_command_buffer = create_command_buffer()
	out.read_command_buffer = create_command_buffer()
	return out
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
