package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "game"
import "game/engine"
import "vendor:raylib"
//3,490,216
Vec3f :: engine.Vec3f

main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	game_main()
	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
}

game_main :: proc() {
	engine.init()
	defer engine.fini()
	fmt.printf("MAPS:%d\n", raylib.MAX_MATERIAL_MAPS)

	for i in 0 ..< 100 {
		_, tmp := engine.create_entity(engine.Entity)
		sz := 6
		tmp.phys.position =
			{
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
			} *
			1
		tmp.phys.rotation = Quat(1)
		tmp.phys.height = 1.
		tmp.phys.width = 1.
		tmp.phys.length = 1.
		tmp.mesh.name = engine.string_clone("cube")
		tmp.mesh.color = raylib.WHITE
	}
	spawn_repeating_explosion({})
	for !raylib.WindowShouldClose() {
		engine.game_tick()
	}
}

spawn_repeating_explosion :: proc(loc: Vec3) {
	random_particle :: proc(center: Vec3f, direction: Vec3f) -> engine.Particle {
		particle: engine.Particle
		dir := engine.random_vec3f_n()
		rad := rand.float32_range(0.0005, 0.005)
		vel := rand.float32_range(0., 5.)
		scale := rand.float32_range(0.1, 0.5)
		particle.velocity = dir * vel + direction
		particle.position = center
		particle.remaining_lifetime = rand.float64_range(0.1, 10)
		particle.rotation = quaternion128(1)
		particle.scale = {scale, scale, scale}
		particle.tint = raylib.RED
		return particle
	}

	func :: proc(this: ^engine.ParticleSystem, dt: f32) -> bool {
		hit := false
		for &i in this.system.particles {
			if i.remaining_lifetime > 0. {
				i.tint.rgb = cast([3]u8)(cast([3]f32)i.tint.rgb - dt)
				hit = true
			}
		}
		if !hit {
			if rand.float32() < 1 * dt {
				for i in 0 ..< 512 {
					engine.try_spawn_particle(this, random_particle({}, {}))
				}
			}
		}
		return false

	}
	spawner :: proc(
		center: engine.Vec3f,
		direction: engine.Vec3f,
		list: ^[dynamic]engine.Particle,
	) {
		for i in 0 ..< 512 {
			append(list, random_particle(center, direction))
		}
	}
	engine.spawn_particle_system(
		loc,
		{},
		.Addititve,
		spawn_func = spawner,
		check_post_update_func_to_destroy = true,
		post_update_func = func,
	)
}
