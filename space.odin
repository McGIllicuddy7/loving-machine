package main
import "game"
import "game/engine"
import "vendor:raylib"
Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject

spawn_asteroid :: proc(pos: Vec3) -> EntityRef {
	rf, ptr := game.create_entity()
	ptr.tags |= {.IsVisible}
	ptr.tint = raylib.DARKGRAY
	ptr.health = 1
	ptr.mesh = "sphere"
	ptr.physics.height = 1.
	ptr.physics.width = 1.
	ptr.physics.length = 1.
	ptr.physics.scale = {1, 1, 1}
	ptr.physics.position = pos
	ptr.physics.rotation = Quat(1)
	return rf
}
