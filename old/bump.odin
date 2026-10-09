package xcx
FRAG_SHADER_SOURCE :: #load("../xcx_frag.glsl", cstring)
import "core:math"
import "core:strings"
import "vendor:raylib"

Object :: struct {
	input:       raylib.RenderTexture2D,
	target:      raylib.RenderTexture2D,
	shader:      raylib.Shader,
	light_pos:   raylib.Vector3,
	light_color: raylib.Color,
	dbg:         bool,
	dbg_normals: bool,
}

Material :: enum {
	BLACK_PLASTIC, //0
	WHITE_PLASTIC, //1
	GRAY_PLASTIC, //2
	RED_PLASTIC, //3
	GREEN_PLASTIC, //4
	BLUE_PLASTIC, //5
	BROWN_PLASTIC, //6
	BEIGE_PLASTIC, //7
	LIGHT_WOOD, //8
	DARK_WOOD, //9
	LIGHT_METAL, //10
	DARK_METAL, //11
	BLACK_PAINT, //12
	WHITE_PAINT, //13
	GRAY_PAINT, //14
	RED_PAINT, //15
	GREEN_PAINT, //16
	BLUE_PAINT, //17
	BROWN_PAINT, //18
	BEIGE_PAINT, //19
	WHITE_LIGHT, //20
	RED_LIGHT, //21
	GREEN_LIGHT, //22
	BLUE_LIGHT, //23
	PINK_LIGHT, //24
	ORANGE_LIGHT, //25
	VOID,
	VOID_LIGHT,
}

PixelData :: struct {
	height:       f32,
	glass_height: f32,
	material:     Material,
}

process_object :: proc(this: ^Object) {
	{
		dir_loc := raylib.GetShaderLocation(this.shader, "input_light_pos")
		mat_loc := raylib.GetShaderLocation(this.shader, "input_light_color")
		raylib.SetShaderValue(this.shader, dir_loc, &this.light_pos, .VEC3)
		mat := (cast([4]f32)this.light_color) / (255.)
		raylib.SetShaderValue(this.shader, mat_loc, &mat, .VEC4)
	}
	{
		dbg_lock := raylib.GetShaderLocation(this.shader, "display_raw")
		v: i32 = 0
		if this.dbg {
			v = 1
		}
		raylib.SetShaderValue(this.shader, dbg_lock, &v, .INT)
		dbg_norm_lock := raylib.GetShaderLocation(this.shader, "display_normals")
		v = 0
		if this.dbg_normals {
			v = 1
		}
		raylib.SetShaderValue(this.shader, dbg_norm_lock, &v, .INT)

	}

	width_loc := raylib.GetShaderLocation(this.shader, "render_width")
	height_loc := raylib.GetShaderLocation(this.shader, "render_height")
	width: f32 = cast(f32)this.target.texture.width
	height: f32 = cast(f32)this.target.texture.width
	raylib.SetShaderValue(this.shader, width_loc, &width, .FLOAT)
	raylib.SetShaderValue(this.shader, height_loc, &height, .FLOAT)
	raylib.BeginTextureMode(this.target)
	raylib.ClearBackground(raylib.BLACK)
	raylib.BeginShaderMode(this.shader)
	raylib.DrawTextureRec(
		this.input.texture,
		(raylib.Rectangle) {
			0,
			0,
			cast(f32)this.input.texture.width,
			-cast(f32)this.input.texture.height,
		},
		(raylib.Vector2){0, 0},
		raylib.WHITE,
	)
	raylib.EndShaderMode()
	raylib.EndTextureMode()
}

create_object :: proc(width: i32, height: i32) -> ^Object {
	out := new(Object)
	out.shader = raylib.LoadShaderFromMemory(nil, FRAG_SHADER_SOURCE)
	out.input = raylib.LoadRenderTexture(width, height)
	out.target = raylib.LoadRenderTexture(width, height)
	out.light_pos = raylib.Vector3{cast(f32)width / 2, cast(f32)height, 400}
	out.light_color = raylib.WHITE
	return out
}

destroy_object :: proc(this: ^Object) {
	raylib.UnloadShader(this.shader)
	raylib.UnloadRenderTexture(this.input)
	raylib.UnloadRenderTexture(this.target)
	free(this)
}

render_object :: proc(this: ^Object, x: i32, y: i32, width: i32, height: i32) {
	if this.dbg {
		raylib.DrawTexturePro(
			this.input.texture,
			(raylib.Rectangle) {
				0,
				0,
				cast(f32)this.input.texture.width,
				-cast(f32)this.input.texture.height,
			},
			(raylib.Rectangle){0, 0, cast(f32)width, cast(f32)height},
			{0, 0},
			0.,
			raylib.WHITE,
		)
	} else {
		raylib.DrawTexturePro(
			this.target.texture,
			(raylib.Rectangle) {
				0,
				0,
				cast(f32)this.input.texture.width,
				-cast(f32)this.input.texture.height,
			},
			(raylib.Rectangle){0, 0, cast(f32)width, cast(f32)height},
			{0, 0},
			0.,
			raylib.WHITE,
		)
	}
}


pixel_data_to_color :: proc(data: PixelData) -> raylib.Color {
	r := cast(u8)math.floor(data.height * 255. / 10. + 5.)
	g := cast(u8)math.floor(data.glass_height * 255.)
	b := cast(u8)data.material
	return {r, g, b, 255}
}

test_compilation :: proc() {
	raylib.InitWindow(640, 480, "gay")
	defer raylib.CloseWindow()
	raylib.BeginDrawing()
	raylib.ClearBackground(raylib.BLACK)
	raylib.EndDrawing()
	raylib.SetTraceLogLevel(.ALL)
	shader := raylib.LoadShaderFromMemory(nil, FRAG_SHADER_SOURCE)
	raylib.UnloadShader(shader)
}

begin_editing :: proc(object: ^Object) {
	raylib.BeginTextureMode(object.input)
}

end_editing :: proc(object: ^Object) {
	_ = object
	raylib.EndTextureMode()
}

clear_background :: proc(material: Material, bmp_height: f32, glass_height: f32 = 0.) {
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	raylib.ClearBackground(mat)
}

draw_rectangle :: proc(
	x, y, width, height: i32,
	material: Material,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	raylib.DrawRectangle(x, y, width, height, mat)
}

draw_circle :: proc(
	x, y: i32,
	radius: f32,
	material: Material,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	raylib.DrawCircle(x, y, radius, mat)
}

draw_circle_raised :: proc(
	x, y: i32,
	radius: f32,
	material: Material,
	bmp_height: f32,
	outer_bmp_height: f32,
	ring_size: i32,
	glass_height: f32 = 0.,
) {
	for i in 0 ..< ring_size {
		l := cast(f32)i / cast(f32)ring_size
		h := outer_bmp_height * (1 - l) + bmp_height * l
		data: PixelData
		data.material = material
		data.height = h
		data.glass_height = glass_height
		mat := pixel_data_to_color(data)
		raylib.DrawCircle(x, y, radius - cast(f32)i, mat)
	}
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	raylib.DrawCircle(x, y, radius - cast(f32)ring_size, mat)
}

draw_rectangle_raised :: proc(
	x, y, width, height: i32,
	material: Material,
	bmp_height: f32,
	outer_bmp_height: f32,
	ring_size: i32,
	glass_height: f32 = 0.,
) {
	for i in 0 ..< ring_size {
		l := cast(f32)i / cast(f32)ring_size
		h := outer_bmp_height * (1 - l) + bmp_height * l
		data: PixelData
		data.material = material
		data.height = h
		data.glass_height = glass_height
		mat := pixel_data_to_color(data)
		raylib.DrawRectangle(x + i, y + i, width - 2 * i, height - 2 * i, mat)
	}
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	raylib.DrawRectangle(
		x + ring_size,
		y + ring_size,
		width - ring_size * 2,
		height - ring_size * 2,
		mat,
	)
}

draw_text :: proc(
	text: string,
	x, y: i32,
	text_height: i32,
	material: Material,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.material = material
	data.height = bmp_height
	data.glass_height = glass_height
	mat := pixel_data_to_color(data)
	s := strings.clone_to_cstring(text, context.temp_allocator)
	raylib.DrawText(s, x, y, text_height, mat)
}
