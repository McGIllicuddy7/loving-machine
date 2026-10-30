package engine

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "vendor:raylib"

InputAxis :: enum {
	X,
	Y,
	Z,
	Roll,
	Pitch,
	Yaw,
}

MovementInput :: struct {
	acceleration_input: Vec3,
	rotation_input:     Vec3,
}

random_vec3 :: proc() -> Vec3 {
	r := rand.float64()
	theta := rand.float64_range(0, 2 * math.PI)
	phi := rand.float64_range(0, 2 * math.PI)
	return(
		Vec3{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3f :: proc() -> Vec3f {
	r := rand.float32()
	theta := rand.float32_range(0, 2 * math.PI)
	phi := rand.float32_range(0, 2 * math.PI)
	return(
		Vec3f{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3_n :: proc() -> Vec3 {
	r := 1.
	theta := rand.float64_range(0, 2 * math.PI)
	phi := rand.float64_range(0, 2 * math.PI)
	return(
		Vec3{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3f_n :: proc() -> Vec3f {
	r: f32 = 1.
	theta := rand.float32_range(0, 2 * math.PI)
	phi := rand.float32_range(0, 2 * math.PI)
	return(
		Vec3f{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

get_input_axis :: proc(axis: InputAxis) -> f64 {
	out: f64 = 0.
	switch axis {
	case .X:
		{
			if raylib.IsKeyDown(.W) {
				out += 1.
			}
			if raylib.IsKeyDown(.S) {
				out -= 1.
			}
		}
	case .Y:
		{
			if raylib.IsKeyDown(.A) {
				out += 1.
			}
			if raylib.IsKeyDown(.D) {
				out -= 1.
			}
		}
	case .Z:
		{
			if raylib.IsKeyDown(.SPACE) {
				out += 1.
			}
			if raylib.IsKeyDown(.Z) {
				out -= 1.
			}
		}
	case .Roll:
		{
			if raylib.IsKeyDown(.Q) {
				out -= 1.
			}
			if raylib.IsKeyDown(.E) {
				out += 1.
			}
		}
	case .Pitch:
		{
			out = cast(f64)raylib.GetMouseDelta().y
		}
	case .Yaw:
		{
			out = -cast(f64)raylib.GetMouseDelta().x
		}
	}
	return out
}

player_get_movement_input_3d :: proc() -> MovementInput {
	dv := Vec3{get_input_axis(.X), get_input_axis(.Y), get_input_axis(.Z)}
	d_theta := Vec3{get_input_axis(.Roll), get_input_axis(.Pitch), get_input_axis(.Yaw)}
	return {dv, d_theta}
}

execute_movement_input_simple_3d :: proc(this: ^Entity, input: MovementInput, dt: f32) {
	rot := this.phys.rotation
	dv := linalg.quaternion256_mul_vector3(rot, input.acceleration_input)
	this.phys.velocity = dv
	this.phys.angular_velocity = input.rotation_input
}


handle_movement_input_simple_3d :: proc(
	this: ^Entity,
	max_velocity: f64,
	angular_velocity_mul: f64,
	dt: f32,
) {
	input := player_get_movement_input_3d()
	input.acceleration_input *= max_velocity
	input.rotation_input *= angular_velocity_mul
	execute_movement_input_simple_3d(this, input, dt)
}

spawn_explosion :: proc(pos: Vec3, radius: f64) {
	spawn_particle_system(
		pos,
		{},
		radius,
		.Addititve,
		true,
		texture = "circle",
		drag = 0.8,
		spawn_func = proc(pos: Vec3f, dir: Vec3f, radius: f32, input: ^[dynamic]Particle) {
			for i in 0 ..< 1000 {
				part: Particle
				p := random_vec3f_n() * 0.0
				part.position = p + pos
				part.velocity = random_vec3f() * radius * 0.25
				part.remaining_lifetime = rand.float64() * 0.1
				part.tint = cast(raylib.Color)math.lerp(
					cast([4]f32)raylib.RED,
					cast([4]f32)raylib.ORANGE,
					rand.float32(),
				)
				part.scale = {0.025, 0.025, 0.025} * radius
				append(input, part)
			}
		},
	)

	spawn_particle_system(
		pos,
		{},
		radius,
		.Alpha,
		true,
		texture = "circle",
		drag = 0.8,
		spawn_func = proc(pos: Vec3f, dir: Vec3f, radius: f32, input: ^[dynamic]Particle) {
			for i in 0 ..< 500 {
				part: Particle
				p := random_vec3f_n() * 0.0
				part.position = p + pos
				part.velocity = random_vec3f() * radius * 0.1
				part.remaining_lifetime = rand.float64() * 4
				part.tint = cast(raylib.Color)math.lerp(
					cast([4]f32)raylib.BLACK,
					cast([4]f32)raylib.GRAY,
					rand.float32(),
				)
				part.scale = {0.05, 0.05, 0.05} * radius
				append(input, part)
			}
		},
	)
}
