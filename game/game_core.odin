package game
import "core:fmt"
import "core:mem"
import "engine"
import "vendor:raylib"
GameClass :: struct {
	using system_base: engine.System,
}

init_game_class_system :: proc() {
	game := new(GameClass, engine.engine_alloc())
	game.on_destroy = game_class_on_destroy
	game.on_event = game_class_on_event
	game.on_level_transfer = game_class_on_level_transfer
	game.on_load = game_class_on_load
	game.on_render = game_class_on_render
	game.on_save = game_class_on_save
	game.on_level_transfer = game_class_on_level_transfer
	game.on_update = game_class_on_update
	engine.register_system("game_state", game)
	engine.register_entity_class(
		Spaceship,
		ship_on_update,
		ship_on_render,
		ship_on_event,
		ship_destructor,
		ship_on_level_transfer,
	)
}

game_class_on_update :: proc(this: ^GameClass, dt: f32) {
	if raylib.IsKeyPressed(.F) {
		engine.save_game("save.cbor")
	}
	if raylib.IsKeyPressed(.G) {
		engine.load_game("save.cbor")
	}
}
game_class_on_event :: proc(this: ^GameClass, event: engine.Event) {

}
game_class_on_render :: proc(this: ^GameClass) {

}
game_class_on_destroy :: proc(this: ^GameClass) {

}
game_class_on_save :: proc(this: ^GameClass, allocator: mem.Allocator) -> string {
	return ""
}
game_class_on_load :: proc(this: ^GameClass, data: string) {

}
game_class_on_level_transfer :: proc(this: ^GameClass) {

}

game_setup :: proc() {
	init_game_class_system()
}
