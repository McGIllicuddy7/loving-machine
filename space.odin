package main
import "core:math/linalg"
import "core:strings"
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
	ptr.tint = raylib.GRAY
	ptr.health = 1
	ptr.mesh = strings.clone("sphere")
	ptr.physics.height = 1.
	ptr.physics.width = 1.
	ptr.physics.length = 1.
	ptr.physics.position = pos
	ptr.physics.mass = 10.
	ptr.model_scale = {1, 1, 1}
	ptr.physics.rotation = Quat(1)
	ptr.physics.velocity = -linalg.normalize(pos)
	return rf
}

BASE_SHIP_DESIGN := game.ShipDesign {
	.Ship,
	"cylinder",
	100,
	100,
	2.,
	0.5,
	0.5,
	[]game.ShipCompSpec {
		{
			type = .Cockpit,
			offset = {0.8, 0.0, 0.0},
			dim = {0.2, 0.2, 0.2},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .Engine,
			offset = {-0.8, 0.0, 0.0},
			dim = {0.2, 0.1, 0.1},
			direction = Vec3{-1, 0, 0},
		},
		{type = .Hold, offset = {0.4, 0.0, 0.0}, dim = {0.4, 0.4, 0.4}, direction = Vec3{1, 0, 0}},
		{
			type = .FuelTank,
			offset = {0., 0.0, 0.0},
			dim = {1., 0.25, 0.25},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .PointDefenseWeapon,
			offset = {0.5, 0.25, -0.1},
			dim = {0.1, 0.1, 0.1},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .PointDefenseWeapon,
			offset = {0.5, -0.25, -0.1},
			dim = {0.1, 0.1, 0.1},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .TorpedoTube,
			offset = {0.8, 0.0, -0.2},
			dim = {0.1, 0.1, 0.1},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .Laser,
			offset = {0.8, 0.5, 0.2},
			dim = {0.1, 0.1, 0.1},
			direction = Vec3{1, 0, 0},
		},
		{
			type = .Laser,
			offset = {0.8, -0.5, 0.2},
			dim = {0.1, 0.1, 0.1},
			direction = Vec3{1, 0, 0},
		},
	},
	[]game.ItemCount{game.ItemCount{.Bullet, 100}},
}

spawn_base_ship :: proc(pos: Vec3, facing: Vec3, is_player: bool) -> (EntityRef, ^game.Entity) {
	yard := game.ship_yard_from_design(&BASE_SHIP_DESIGN)
	defer game.destroy_ship_yard(yard)
	game.ship_yard_set_pos(yard, pos)
	game.ship_yard_set_looking_in_direction(yard, facing)
	if (is_player) {
		game.ship_yard_set_tag(yard, .IsPlayer)
	}
	return game.ship_yard_build(yard)
}
