package engine
import "vendor:raylib"

GraphicsObject :: struct {
	transform: Transform,
	mesh_id:   string,
	tint:      raylib.Color,
}

GCmdDrawRectangle :: struct {
	x, y, width, height: i32,
	color:               raylib.Color,
}

GCmdDrawCircle :: struct {
	x, y, radius: i32,
	color:        raylib.Color,
}

GCmdDrawTriangle :: struct {
	points: [3]raylib.Vector2,
	color:  raylib.Color,
}

GCmdDrawText :: struct {
	x, y, text_height: i32,
	content:           string,
	color:             raylib.Color,
}

GCmdDrawTexture :: struct {
	x, y, width, height: i32,
	image:               ^raylib.Texture2D,
	color:               raylib.Color,
}

GCmdBeginScissor :: struct {
	x, y, width, height: i32,
}

GCmdEndScissor :: struct {}

GraphicsCommandBuffer :: struct {
	camera:  raylib.Camera3D,
	objects: []GraphicsObject,
}

GraphicsContext :: struct {
	meshes: map[string]raylib.Mesh,
	font:   raylib.Font,
}
