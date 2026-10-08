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

Color :: enum {
	BLACK, //0
	RED, //1
	GREEN, //2
	YELLOW, //3
	BLUE, //4
	MAGENTA, //5
	CYAN, //6
	WHITE, //7
	BRIGHT_BLACK, //8
	BRIGHT_RED, //9
	BRIGHT_GREEN, //10
	BRIGHT_YELLOW, //11
	BRIGHT_BLUE, //12
	BRIGHT_MAGENTA, //13
	BRIGHT_CYAN, //14
	BRIGHT_WHITE, //15
	EMMISIVE_BLACK, //16
	EMMISIVE_RED, //17
	EMMISIVE_GREEN, //18
	EMMISIVE_YELLOW, //19
	EMMISIVE_BLUE, //20
	EMMISIVE_MAGENTA, //21
	EMMISIVE_CYAN, //22
	EMMISIVE_WHITE, //23
}

PixelData :: struct {
	height:       f32,
	glass_height: f32,
	color:        Color,
}

process_object :: proc(this: ^Object) {
	{
		dir_loc := raylib.GetShaderLocation(this.shader, "input_light_pos")
		col_loc := raylib.GetShaderLocation(this.shader, "input_light_color")
		raylib.SetShaderValue(this.shader, dir_loc, &this.light_pos, .VEC3)
		col := (cast([4]f32)this.light_color) / (255.)
		raylib.SetShaderValue(this.shader, col_loc, &col, .VEC4)
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
	out.light_pos = raylib.Vector3{cast(f32)width / 2, cast(f32)height, 200}
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
	b := cast(u8)data.color
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

clear_background :: proc(color: Color, bmp_height: f32, glass_height: f32 = 0.) {
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	raylib.ClearBackground(col)
}

draw_rectangle :: proc(
	x, y, width, height: i32,
	color: Color,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	raylib.DrawRectangle(x, y, width, height, col)
}

draw_circle :: proc(
	x, y: i32,
	radius: f32,
	color: Color,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	raylib.DrawCircle(x, y, radius, col)
}

draw_circle_raised :: proc(
	x, y: i32,
	radius: f32,
	color: Color,
	bmp_height: f32,
	outer_bmp_height: f32,
	ring_size: i32,
	glass_height: f32 = 0.,
) {
	for i in 0 ..< ring_size {
		l := cast(f32)i / cast(f32)ring_size
		h := outer_bmp_height * (1 - l) + bmp_height * l
		data: PixelData
		data.color = color
		data.height = h
		data.glass_height = glass_height
		col := pixel_data_to_color(data)
		raylib.DrawCircle(x, y, radius - cast(f32)i, col)
	}
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	raylib.DrawCircle(x, y, radius - cast(f32)ring_size, col)
}

draw_rectangle_raised :: proc(
	x, y, width, height: i32,
	color: Color,
	bmp_height: f32,
	outer_bmp_height: f32,
	ring_size: i32,
	glass_height: f32 = 0.,
) {
	for i in 0 ..< ring_size {
		l := cast(f32)i / cast(f32)ring_size
		h := outer_bmp_height * (1 - l) + bmp_height * l
		data: PixelData
		data.color = color
		data.height = h
		data.glass_height = glass_height
		col := pixel_data_to_color(data)
		raylib.DrawRectangle(x + i, y + i, width - 2 * i, height - 2 * i, col)
	}
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	raylib.DrawRectangle(
		x + ring_size,
		y + ring_size,
		width - ring_size * 2,
		height - ring_size * 2,
		col,
	)
}

draw_text :: proc(
	text: string,
	x, y: i32,
	text_height: i32,
	color: Color,
	bmp_height: f32,
	glass_height: f32 = 0.,
) {
	data: PixelData
	data.color = color
	data.height = bmp_height
	data.glass_height = glass_height
	col := pixel_data_to_color(data)
	s := strings.clone_to_cstring(text, context.temp_allocator)
	raylib.DrawText(s, x, y, text_height, col)
}
