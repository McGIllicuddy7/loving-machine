package physics
import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/fixed"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:time"
import "vendor:raylib"

Vec3 :: [3]f64
Quat :: quaternion256
EntityRef :: struct {
	idx: u32,
	gen: u32,
}

Transform :: struct {
	position: Vec3,
	rotation: Quat,
	scale:    Vec3,
}

PhysicsObject :: struct {
	using trans: Transform,
	velocity:    Vec3,
	length:      f64, //x,
	width:       f64, //y,
	height:      f64, //z,
}

TaggedPhysicsObject :: struct {
	ref: EntityRef,
	ptr: ^PhysicsObject,
}


get_vertices :: proc(obj: PhysicsObject) -> [8]Vec3 {
	x_dim := obj.length / 2
	y_dim := obj.width / 2
	z_dim := obj.height / 2
	out: [8]Vec3 = {
		{-x_dim, -y_dim, -z_dim},
		{-x_dim, -y_dim, z_dim},
		{-x_dim, y_dim, -z_dim},
		{-x_dim, y_dim, z_dim},
		{x_dim, -y_dim, -z_dim},
		{x_dim, -y_dim, z_dim},
		{x_dim, y_dim, -z_dim},
		{x_dim, y_dim, z_dim},
	}
	for &i in out {
		i = linalg.quaternion256_mul_vector3(obj.rotation, i) + obj.position
	}
	return out
}

get_normals :: proc(object: PhysicsObject) -> [6]Vec3 {
	out: [6]Vec3 = {{0, 0, -1}, {0, 0, 1}, {0, -1, 0}, {0, 1, 0}, {-1, 0, 0}, {1, 0, 0}}
	for &i in out {
		i = linalg.quaternion256_mul_vector3(object.rotation, i)
	}
	return out
}

get_collision_vectors :: proc(object: PhysicsObject) -> [26]Vec3 {
	out: [26]Vec3
	count := 0
	for z in -1 ..= 1 {
		for y in -1 ..= 1 {
			for x in -1 ..= 1 {
				if z == 0 && y == 0 && x == 0 {
					continue
				}
				v0: Vec3 = linalg.normalize(Vec3{cast(f64)x, cast(f64)y, cast(f64)z})
				out[count] = v0
				count += 1
			}
		}
	}
	for &i in out {
		i = linalg.quaternion256_mul_vector3(object.rotation, i)
	}
	return out
}

check_collision_objects :: proc(object_a: PhysicsObject, object_b: PhysicsObject) -> bool {
	return true
}

raycast_against_object :: proc(
	start: Vec3,
	direction: Vec3,
	distance: f64,
	object: PhysicsObject,
) -> (
	hit: bool,
	hit_location: Vec3,
	hit_normal: Vec3,
) {
	s0 := start - object.position
	q0 := linalg.quaternion_inverse(object.rotation)
	s0 = linalg.quaternion256_mul_vector3(q0, s0)
	dir := linalg.quaternion256_mul_vector3(q0, direction)
	dir_x := 0.000001 if (dir.x == 0) else dir.x
	dir_y := 0.000001 if (dir.y == 0) else dir.y
	dir_z := 0.000001 if (dir.z == 0) else dir.z
	inv_dir_x := 1 / dir_x
	inv_dir_y := 1 / dir_y
	inv_dir_z := 1 / dir_z
	x_min := -object.length / 2
	x_max := object.length / 2
	y_min := -object.width / 2
	y_max := object.width / 2
	z_min := -object.height / 2
	z_max := object.height / 2
	t_min_x := (x_min - s0.x) * inv_dir_x
	t_max_x := (x_max - s0.x) * inv_dir_x
	if (inv_dir_x < 0) {
		tmp := t_min_x
		t_min_x = t_max_x
		t_max_x = tmp
	}
	t_min_y := (y_min - s0.y) * inv_dir_y
	t_max_y := (y_max - s0.y) * inv_dir_y
	if (inv_dir_y < 0) {
		tmp := t_min_y
		t_min_y = t_max_y
		t_max_y = tmp
	}
	t_min_z := (z_min - s0.z) * inv_dir_z
	t_max_z := (z_max - s0.z) * inv_dir_z
	if (inv_dir_z < 0) {
		tmp := t_min_z
		t_min_z = t_max_z
		t_max_z = tmp
	}
	hit_distance := 0.
	normal: Vec3
	if t_min_x > t_max_y || t_min_y > t_max_x {
		return
	}
	if t_min_y > t_max_z || t_min_z > t_max_y {
		return
	}
	if t_min_z > t_max_x || t_min_x > t_max_z {
		return
	}
	tmin := max(t_min_x, t_min_y, t_min_z)
	tmax := min(t_max_x, t_max_y, t_max_z)
	if tmax < 0 {
		return
	}
	hit_distance = 0 if tmin < 0 else tmin
	hit_point_act := start + direction * hit_distance
	hit_point := s0 + dir * hit_distance
	epsilon := 0.01
	h_normal: Vec3
	if (abs(hit_point.x - x_min) < epsilon) {
		h_normal = {-1, 0, 0}
	} else if (abs(hit_point.x - x_max) < epsilon) {
		h_normal = {1, 0, 0}
	} else if (abs(hit_point.y - y_min) < epsilon) {
		h_normal = {0, -1, 0}
	} else if (abs(hit_point.y - y_max) < epsilon) {
		h_normal = {0, 1, 0}
	} else if (abs(hit_point.z - z_min) < epsilon) {
		h_normal = {0, 0, -1}
	} else if (abs(hit_point.z - z_max) < epsilon) {
		h_normal = {0, 0, 1}
	}
	hit = true
	hit_location = hit_point_act
	hit_normal = linalg.quaternion256_mul_vector3(object.rotation, h_normal)
	return
}

raycasting_test :: proc() {
	success_count := 0
	time_count: u128 = 0
	max_dur: f64 = 0
	degenerate: struct {
		object:    PhysicsObject,
		start:     Vec3,
		direction: Vec3,
		length:    f64,
		hit:       bool,
	}
	for _ in 0 ..< 10000 {
		pitch: f64 = cast(f64)(rand.float32() * 360)
		yaw := cast(f64)(rand.float32() * 360)
		rot := linalg.quaternion_from_euler_angles_f64(pitch, yaw, cast(f64)0.0, .XYZ)
		pos_x: f64 = cast(f64)(rand.int32_range(-100, 101))
		pos_y: f64 = cast(f64)(rand.int32_range(-100, 101))
		pos_z: f64 = cast(f64)(rand.int32_range(-100, 101))
		pos: Vec3 = {pos_x, pos_y, pos_z}
		scale_x: f64 = cast(f64)(rand.int32_range(1, 10))
		scale_y: f64 = cast(f64)(rand.int32_range(1, 10))
		scale_z: f64 = cast(f64)(rand.int32_range(1, 10))
		obj: PhysicsObject
		obj.position = pos
		obj.rotation = rot
		obj.scale = {1, 1, 1}
		obj.length = scale_x
		obj.width = scale_y
		obj.height = scale_z
		for _ in 0 ..< 10000 {
			dpos_x: f64 = cast(f64)(rand.int32_range(-100, 101)) * 15
			dpos_y: f64 = cast(f64)(rand.int32_range(-100, 101)) * 15
			dpos_z: f64 = cast(f64)(rand.int32_range(-100, 101)) * 15
			vs: Vec3 = {dpos_x, dpos_y, dpos_z}
			if vs == {0, 0, 0} {
				continue
			}
			{
				s0 := vs + pos
				delta := -linalg.normalize(vs)
				len := linalg.length(vs) * 4
				{
					t0 := time.now()
					hit, _, _ := raycast_against_object(s0, delta, len, obj)
					if !hit {
						fmt.printf(
							"failed to hit:start:%v, delta:%v, len:%v, object:%v\n",
							s0,
							delta,
							len,
							obj,
						)
					}
					assert(hit)
					success_count += 1
					dur := time.since(t0)
					if time.duration_milliseconds(dur) > 1 {
						fmt.printf(
							"took:%f milliseconds to run\n",
							time.duration_milliseconds(dur),
						)
					}
					tmp_dur := time.duration_microseconds(dur)
					t_time := cast(u128)tmp_dur
					time_count += t_time
					if tmp_dur > max_dur {
						max_dur = tmp_dur
						degenerate.direction = delta
						degenerate.hit = hit
						degenerate.length = len
						degenerate.start = s0
						degenerate.object = obj
					}
				}
			}
			{
				t0 := time.now()
				s0 := vs + pos
				delta := linalg.normalize(vs)
				len := linalg.length(vs) * 4
				hit, _, _ := raycast_against_object(s0, delta, len, obj)
				if hit {
					fmt.printf(
						"failed to miss:start:%v, delta:%v, len:%v, object:%v\n",
						s0,
						delta,
						len,
						obj,
					)
				}
				assert(!hit)
				success_count += 1
				dur := time.since(t0)
				if time.duration_milliseconds(dur) > 1 {
					fmt.printf("took:%f milliseconds to run\n", time.duration_milliseconds(dur))
				}
				tmp_dur := time.duration_microseconds(dur)
				t_time := cast(u128)tmp_dur
				time_count += t_time
				if tmp_dur > max_dur {
					max_dur = tmp_dur
					degenerate.direction = delta
					degenerate.hit = hit
					degenerate.length = len
					degenerate.start = s0
					degenerate.object = obj
				}
			}
		}
		if success_count % 1000000 == 0 {
			fmt.printf("success count:%d\n", success_count)
		}
	}
	fmt.printf(
		"took on average:%v microseconds and at most %f microseconds\n degenerate example:%v\n",
		cast(f64)time_count / cast(f64)success_count,
		max_dur,
		degenerate,
	)
}
