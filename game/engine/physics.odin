package engine
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:sync"

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
	using trans:      Transform,
	is_projectile:    bool,
	is_static:        bool,
	velocity:         Vec3,
	angular_velocity: Vec3,
	length:           f64, //x,
	width:            f64, //y,
	height:           f64, //z,
}

TaggedPhysicsObject :: struct {
	ref: EntityRef,
	ptr: ^PhysicsObject,
}

CollisionEvent :: struct {
	collided_with_entity: EntityRef,
	collider_entity:      EntityRef,
	normal:               Vec3,
	relative_velocity:    Vec3,
}

TileMapNode :: struct {
	children: [dynamic]TaggedPhysicsObject,
}
Tile :: struct {
	x: i64,
	y: i64,
	z: i64,
}
TileMap :: struct {
	tile_sz_x: f64,
	tile_sz_y: f64,
	tile_sz_z: f64,
	tiles:     map[Tile][dynamic]TaggedPhysicsObject,
}

CollisionData :: struct {
	objects:  []TaggedPhysicsObject,
	tile_map: TileMap,
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

get_object_radius :: proc(obj: PhysicsObject) -> f64 {
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
	dists: [8]f64 = {
		linalg.length(out[0]),
		linalg.length(out[1]),
		linalg.length(out[2]),
		linalg.length(out[3]),
		linalg.length(out[4]),
		linalg.length(out[5]),
		linalg.length(out[6]),
		linalg.length(out[7]),
	}
	return max(dists[0], dists[1], dists[2], dists[3], dists[4], dists[5], dists[6], dists[7])
}

//returns normal poi64ing from b to a
check_collision_objects :: proc(
	object_a: PhysicsObject,
	object_b: PhysicsObject,
) -> (
	hit: bool,
	normal: Vec3,
	depth: f64,
) {
	r_a := get_object_radius(object_a)
	r_b := get_object_radius(object_b)
	dist := linalg.distance(object_a.position, object_b.position)
	if dist > r_a + r_b {
		return
	}
	a_vecs := get_collision_vectors(object_a)
	b_vecs := get_collision_vectors(object_b)
	a_poi64s := get_vertices(object_a)
	b_poi64s := get_vertices(object_b)
	min_dist := dist
	min_normal := a_vecs[0]
	for i in a_vecs {
		a_min := linalg.dot(a_poi64s[0], i)
		a_max := a_min
		b_min := linalg.dot(b_poi64s[0], i)
		b_max := b_min
		for j in a_poi64s {
			tmp := linalg.dot(j, i)
			if tmp < a_min {
				a_min = tmp
			}
			if tmp > a_max {
				a_max = tmp
			}
		}
		for j in b_poi64s {
			tmp := linalg.dot(j, i)
			if tmp < b_min {
				b_min = tmp
			}
			if tmp > b_max {
				b_max = tmp
			}
		}
		if a_max < b_min || b_max < a_min {
			return
		}
		delta := min(abs(a_min - b_max), abs(b_min - a_max))
		if delta < min_dist {
			min_dist = delta
			min_normal = i
		}
	}
	for i in a_vecs {
		a_min := linalg.dot(a_poi64s[0], i)
		a_max := a_min
		b_min := linalg.dot(b_poi64s[0], i)
		b_max := b_min
		for j in a_poi64s {
			tmp := linalg.dot(j, i)
			if tmp < a_min {
				a_min = tmp
			}
			if tmp > a_max {
				a_max = tmp
			}
		}
		for j in b_poi64s {
			tmp := linalg.dot(j, i)
			if tmp < b_min {
				b_min = tmp
			}
			if tmp > b_max {
				b_max = tmp
			}
		}
		if a_max < b_min || b_max < a_min {
			return
		}
		delta := min(abs(a_min - b_max), abs(b_min - a_max))
		if delta < min_dist {
			min_dist = delta
			min_normal = i
		}
	}
	hit = true
	depth = min_dist
	normal = min_normal
	d0 := (object_a.position - object_a.position)
	if linalg.dot(normal, d0) < 0.0 {
		normal *= -1
	}
	return
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
	dir_x := 0.0000001 if (dir.x == 0) else dir.x
	dir_y := 0.0000001 if (dir.y == 0) else dir.y
	dir_z := 0.0000001 if (dir.z == 0) else dir.z
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
	hit_poi64_act := start + direction * hit_distance
	hit_poi64 := s0 + dir * hit_distance
	epsilon := 0.01
	h_normal: Vec3
	if (abs(hit_poi64.x - x_min) < epsilon) {
		h_normal = {-1, 0, 0}
	} else if (abs(hit_poi64.x - x_max) < epsilon) {
		h_normal = {1, 0, 0}
	} else if (abs(hit_poi64.y - y_min) < epsilon) {
		h_normal = {0, -1, 0}
	} else if (abs(hit_poi64.y - y_max) < epsilon) {
		h_normal = {0, 1, 0}
	} else if (abs(hit_poi64.z - z_min) < epsilon) {
		h_normal = {0, 0, -1}
	} else if (abs(hit_poi64.z - z_max) < epsilon) {
		h_normal = {0, 0, 1}
	}
	hit = true
	hit_location = hit_poi64_act
	hit_normal = linalg.quaternion256_mul_vector3(object.rotation, h_normal)
	return
}

generate_collision_data :: proc(
	objects: []TaggedPhysicsObject,
	allocator: mem.Allocator,
) -> CollisionData {
	data: CollisionData
	data.objects = objects
	data.tile_map.tile_sz_x = 2.
	data.tile_map.tile_sz_y = 2.
	data.tile_map.tile_sz_z = 2.
	data.tile_map.tiles = make(map[Tile][dynamic]TaggedPhysicsObject, allocator)
	reserve_map(&data.tile_map.tiles, len(objects))
	for i in objects {
		if i.ptr.is_projectile {
			continue
		}
		dx := cast(i64)math.round(i.ptr.length / data.tile_map.tile_sz_x)
		dy := cast(i64)math.round(i.ptr.width / data.tile_map.tile_sz_y)
		dz := cast(i64)math.round(i.ptr.height / data.tile_map.tile_sz_z)
		for z in -dz ..= dz {
			for y in -dy ..= dy {
				for x in -dx ..= dx {
					px := x + cast(i64)(i.ptr.position.x / data.tile_map.tile_sz_x)
					py := y + cast(i64)(i.ptr.position.y / data.tile_map.tile_sz_y)
					pz := z + cast(i64)(i.ptr.position.z / data.tile_map.tile_sz_z)
					ps := Tile{px, py, pz}
					if !(ps in data.tile_map.tiles) {
						data.tile_map.tiles[ps] = make([dynamic]TaggedPhysicsObject, allocator)
						reserve_dynamic_array(&data.tile_map.tiles[ps], 8)
					}
					append(&data.tile_map.tiles[ps], i)
				}
			}
		}
	}
	return data
}

physics_update :: proc(
	objects: []TaggedPhysicsObject,
	delta_time: f64,
	frame_allocator: mem.Allocator,
) -> [dynamic]CollisionEvent {
	CollisionPair :: struct {
		a: EntityRef,
		b: EntityRef,
	}
	data: CollisionData = generate_collision_data(objects, frame_allocator)
	{
		/*	fmt.pri64f("values:\n")
		for i, j in data.tile_map.tiles {
			fmt.pri64f("\t%v %d\n", i, len(j))
		}*/
	}
	events := make([dynamic]CollisionEvent, frame_allocator)
	hit_set := make(map[CollisionPair]u8)
	defer delete(hit_set)

	for i in objects {
		id := i.ref
		phys := i.ptr
		old_rot := phys.rotation
		phys.rotation =
			linalg.quaternion_from_euler_angles_f64(
				phys.angular_velocity.x * delta_time,
				phys.angular_velocity.y * delta_time,
				phys.angular_velocity.z * delta_time,
				.XYZ,
			) *
			phys.rotation
		if (phys.velocity == Vec3{0, 0, 0}) {
			continue
		}
		base_pos := phys.position
		old_pos := phys.position
		max_disp := linalg.length(phys.velocity * delta_time)
		DELTA :: 0.01
		disp: f64 = 0.00
		nvel := phys.velocity / (linalg.length(phys.velocity))
		for disp < max_disp {
			old_pos = phys.position
			if (disp + DELTA) > max_disp {
				disp = max_disp
			} else {
				disp = disp + DELTA
			}
			phys.position = base_pos + disp * nvel
			hit_ref, hit_obj, hit_norm, max_depth, did_hit := check_collision_against(i, data)
			if did_hit {
				phys.rotation = old_rot
				phys.position = old_pos
				phys.angular_velocity *= -0.5
				p := CollisionPair{i.ref, hit_ref}
				if !(p in hit_set) {
					hit_set[p] = 0
					p2 := CollisionPair{hit_ref, i.ref}
					hit_set[p2] = 0
					e1 := CollisionEvent {
						i.ref,
						hit_ref,
						hit_norm,
						hit_obj.velocity - phys.velocity,
					}
					e2 := CollisionEvent {
						hit_ref,
						i.ref,
						-hit_norm,
						phys.velocity - hit_obj.velocity,
					}
					append(&events, e1)
					append(&events, e2)
					phys.velocity = linalg.reflect(phys.velocity, e1.normal) * 0.5
					hit_obj.velocity = linalg.reflect(hit_obj.velocity, e2.normal) * 0.5
				}
				break
			}
		}
	}
	return events
}

check_collision_against :: proc(
	obj: TaggedPhysicsObject,
	set: CollisionData,
) -> (
	hit_ref: EntityRef,
	hit_obj: ^PhysicsObject,
	hit_norm: Vec3,
	max_depth: f64,
	did_hit: bool,
) {
	max_depth = -1.
	px := cast(i64)(obj.ptr.position.x / set.tile_map.tile_sz_x)
	py := cast(i64)(obj.ptr.position.y / set.tile_map.tile_sz_y)
	pz := cast(i64)(obj.ptr.position.z / set.tile_map.tile_sz_z)
	for dz in -cast(i64)1 ..= 1 {
		for dy in -cast(i64)1 ..= 1 {
			for dx in -cast(i64)1 ..= 1 {
				ps_act := Tile{px + dx, py + dy, pz + dz}
				if !(ps_act in set.tile_map.tiles) {
					continue
				}
				list := set.tile_map.tiles[ps_act]
				for i in list {
					if obj.ref.idx == i.ref.idx {
						continue
					}
					col, norm, depth := check_collision_objects(obj.ptr^, i.ptr^)
					if col {
						if depth > max_depth {
							max_depth = depth
							hit_norm = norm
							hit_obj = i.ptr
							hit_ref = i.ref
							did_hit = true
						}
					}
				}
			}
		}
	}

	return
}
