package libnav
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:path/slashpath"
import "vendor:raylib"
Vec3 :: linalg.Vector3f64

distance :: linalg.distance
length :: linalg.length
normalize :: linalg.normalize

calculate_projectile_direction :: proc(
	max_velocity: f64,
	relative_position: Vec3,
	target_relative_velocity: Vec3,
	target_acc: Vec3,
) -> Vec3 {
	vel_len := max_velocity
	guess_time := length(relative_position) / vel_len
	for _i in 0 ..< 10 {
		travel_distance := vel_len * guess_time
		new_pos :=
			relative_position +
			target_relative_velocity * guess_time +
			1 / 2 * target_acc * guess_time * guess_time
		new_dist := length(new_pos)
		guess_time = (new_dist / vel_len)
	}
	return normalize(
		relative_position +
		target_relative_velocity * guess_time +
		1 / 2 * target_acc * guess_time * guess_time,
	)
}

calculate_missile_frame_acceleration :: proc(
	acceleration: f64,
	target_relative_position: Vec3,
	target_relative_velocity: Vec3,
	target_acceleration: Vec3,
	should_halt: bool,
) -> Vec3 {
	if acceleration == 0. {
		return {}
	}
	/*
		d = 1/2at^2
		2d/a =t^2
		t = sqrt(2d/a)
	*/
	guess_time := math.sqrt(2 * length(target_relative_position) / acceleration)
	for _i in 0 ..< 10 {
		guess_position :=
			target_relative_position +
			target_relative_velocity * guess_time +
			1 / 2 * target_acceleration * guess_time * guess_time
		guess_time = math.sqrt(2 * length(guess_position) / acceleration)
	}
	guess_position :=
		target_relative_position +
		target_relative_velocity * guess_time +
		1 / 2 * target_acceleration * guess_time * guess_time
	if length(guess_position) == 0 {
		return {}
	}
	if should_halt {
		dt := linalg.dot(guess_position, target_relative_velocity)
		if dt < -0.9 {
			remaining := math.sqrt(2 * length(target_relative_position) / acceleration)
			r2 := length(target_relative_velocity) / acceleration
			if remaining <= r2 + (1. / 60.) {
				return -normalize(guess_position) * acceleration
			}
		}
		return normalize(guess_position) * acceleration
	} else {
		return normalize(guess_position) * acceleration
	}
}


projectile_main :: proc() {
	for i in t0 {
		fmt.printf("at init:%s\n", i)
	}
	raylib.InitWindow(1000, 1000, "invaders")
	raylib.SetTargetFPS(61)
	outer: for !raylib.WindowShouldClose() {
		for {
			if raylib.WindowShouldClose() {
				continue outer
			}
			if raylib.IsKeyPressed(.SPACE) {
				break
			}
			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			raylib.DrawText("Press Space to Continue", 200, 400, 16, raylib.WHITE)
			raylib.EndDrawing()
		}
		{
			Vec2 :: linalg.Vector2f32
			Entity :: struct {
				pos:        Vec2,
				vel:        Vec2,
				lifetime:   f32,
				is_missile: bool,
			}
			player_pos := Vec2{800, 500}
			player_vel := Vec2{}
			player_forward: f32 = 0.
			player_health := 10
			entities := make([dynamic]Entity)
			defer delete(entities)
			spawn_entity :: proc(
				entities: ^[dynamic]Entity,
				pos: Vec2,
				vel: Vec2,
				lifetime: f32,
				is_missile: bool,
			) {
				for &i in entities {
					if i.lifetime <= 0 {
						i.lifetime = lifetime
						i.pos = pos
						i.vel = vel
						return
					}
				}
				append(entities, Entity{pos, vel, lifetime, is_missile})
			}
			frame_counter := 0
			projectile_velocity :: 400
			projectile_acc :: 600
			player_velocity :: 250
			for player_health > 0 {
				frame_counter += 1
				frame_counter %= 65536
				if raylib.WindowShouldClose() {
					break
				}
				dt := raylib.GetFrameTime()
				frd := raylib.Vector2Rotate({1, 0}, player_forward)
				right := raylib.Vector2Rotate({0, 1}, player_forward)
				old_vel := player_vel
				{
					b_vel := Vec2{}
					if raylib.IsKeyDown(.W) {
						b_vel.x += 1
					}
					if raylib.IsKeyDown(.S) {
						b_vel.x -= 1
					}
					if raylib.IsKeyDown(.A) {
						b_vel.y -= 1
					} else if raylib.IsKeyDown(.D) {
						b_vel.y += 1
					}
					player_vel =
						frd * b_vel.x * player_velocity + right * b_vel.y * player_velocity / 2
					if distance(raylib.GetMousePosition(), player_pos) > 5. &&
					   !raylib.IsKeyDown(.LEFT_SHIFT) {
						dt := raylib.GetMousePosition() - player_pos
						tmp := math.atan2(dt.y, dt.x)
						player_forward = tmp
					}
					player_pos += player_vel * dt
					if player_pos.x > 1000 {
						player_pos.x -= 1000.
					}
					if player_pos.x < 0 {
						player_pos.x = 1000 - player_pos.x
					}
					if player_pos.y > 1000 {
						player_pos.y -= 1000.
					}
					if player_pos.y < 0 {
						player_pos.y = 1000 - player_pos.y
					}
				}
				for &i in entities {
					if i.lifetime > 0 {
						i.lifetime -= dt
						i.pos += i.vel * dt
						if i.pos.x > 1000 {
							i.pos.x -= 1000.
						}
						if i.pos.x < 0 {
							i.pos.x = 1000 - i.pos.x
						}
						if i.pos.y > 1000 {
							i.pos.y -= 1000.
						}
						if i.pos.y < 0 {
							i.pos.y = 1000 - i.pos.y
						}
						if i.is_missile {
							dac := cast([2]f64)((player_vel - old_vel) / dt).xy
							rpos := player_pos - i.pos
							rpos3: Vec3 = {cast(f64)rpos.x, cast(f64)rpos.y, 0}
							rvel := player_vel - i.vel
							rvel3: Vec3 = {cast(f64)rvel.x, cast(f64)rvel.y, 0}
							ac := calculate_missile_frame_acceleration(
								projectile_acc,
								rpos3,
								rvel3,
								{},
								true,
							)
							i.vel.x += cast(f32)ac.x * dt
							i.vel.y += cast(f32)ac.y * dt
						}
						if linalg.distance(i.pos, player_pos) < 10 {
							player_health -= 1
							i.lifetime = -1.
						}
					}
				}
				if frame_counter % 4 == 0 && rand.float32() < 0.1 {
					dac := cast([2]f64)((player_vel - old_vel) / dt).xy
					dir := calculate_projectile_direction(
						projectile_velocity,
						{cast(f64)player_pos.x - 500, cast(f64)player_pos.y - 500, 0},
						{cast(f64)player_vel.x, cast(f64)player_vel.y, 0},
						{dac.x, dac.y, 0},
					)
					d2 := cast([2]f32)dir.xy
					spawn_entity(&entities, {500, 500}, d2 * projectile_velocity, 10, false)
				}
				if frame_counter % 50 == 0 && rand.float32() < 0.9 {
					spawn_entity(&entities, {500, 500}, {}, 20, true)
				}
				raylib.BeginDrawing()
				raylib.ClearBackground(raylib.BLACK)
				raylib.DrawText(
					fmt.ctprintf("health:%d", player_health),
					800,
					20,
					16,
					raylib.WHITE,
				)
				raylib.DrawTriangle(
					player_pos + frd * 10,
					player_pos - (frd + right / 2) * 10,
					player_pos - (frd - right / 2) * 10,
					raylib.GREEN,
				)
				for i in entities {
					if i.lifetime > 0. {
						col := raylib.RED if !i.is_missile else raylib.PINK
						raylib.DrawCircleV(i.pos, 3, col)
					}
				}
				raylib.EndDrawing()
			}
		}
		for {
			if raylib.WindowShouldClose() {
				continue outer
			}
			if raylib.IsKeyPressed(.SPACE) {
				break
			}
			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			raylib.DrawText("Game Over, Press space to continue", 200, 400, 16, raylib.WHITE)
			raylib.EndDrawing()
		}
	}
}

t0: [dynamic]string
@(init)
_x :: proc "contextless" () {
	context = runtime.default_context()
	append(&t0, "hello world!")
}
