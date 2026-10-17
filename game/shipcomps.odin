package game
//import "engine"
import "core:math/linalg"
import "core:strings"
import "vendor:raylib"
Vec3f :: raylib.Vector3
ShipComponentType :: enum (u8) {
	Cockpit,
	Cabin,
	Hold,
	Engine,
	FuelTank,
	PointDefenseWeapon,
	TorpedoTube,
	Laser,
	Magazine,
}

ShipComponent :: struct {
	type:              ShipComponentType,
	is_on_fire:        bool,
	direction:         Vec3f,
	offset:            Vec3f,
	length:            f32,
	width:             f32,
	height:            f32,
	health:            i32,
	damage_resistance: i32,
	temperature:       i32,
	pressure:          i32,
}

ShipData :: struct {
	components: []ShipComponent,
}

destroy_ship_data :: proc(data: ShipData) {
	delete(data.components)
}

clone_ship_data :: proc(data: ShipData) -> ShipData {
	out := data
	out.components = make_slice([]ShipComponent, len(data.components))
	for i in 0 ..< len(out.components) {
		out.components[i] = data.components[i]
	}
	return out
}

ShipComponentHitResult :: struct {
	component:              ^ShipComponent,
	distance_from_previous: f32,
}

raycast_against_entity_ship_components :: proc(
	entity: ^Entity,
	start: Vec3,
	direction: Vec3,
	ignored: []^ShipComponent = {},
) -> [dynamic]ShipComponentHitResult {
	ship_physics: PhysicsObject = entity.physics
	data: ShipData = entity.ship_data
	out := make([dynamic]ShipComponentHitResult)
	start_0 := start - ship_physics.position
	inv := linalg.quaternion_inverse(ship_physics.rotation)
	start_0 = linalg.quaternion_mul_vector3(inv, start_0)
	dir := linalg.quaternion_mul_vector3(inv, direction)
	hits := make(map[rawptr]u8)
	defer delete(hits)
	first := false
	for {
		hit := false
		hit_dist: f32 = 0.
		hit_rs: ^ShipComponent = nil
		hit_pos := start_0
		for &i in data.components {
			for j in ignored {
				if &i == j {
					continue
				}
			}
			if &i in hits {
				continue
			}
			bx: raylib.BoundingBox
			bx.min = i.offset - raylib.Vector3{i.length, i.width, i.height} / 2
			bx.max = i.offset + raylib.Vector3{i.length, i.width, i.height} / 2
			s := cast(raylib.Vector3)start_0
			d := cast(raylib.Vector3)dir
			h := raylib.GetRayCollisionBox(raylib.Ray{position = s, direction = d}, bx)
			if h.hit {
				if h.distance < hit_dist || !hit {
					hit_dist = h.distance
					hit = true
					hit_rs = &i
					hit_pos = auto_cast (i.offset)
				}
			}
		}
		if !hit {
			break
		}
		hits[hit_rs] = 1
		start_0 = hit_pos
		rs: ShipComponentHitResult
		rs.component = hit_rs
		rs.distance_from_previous = 0. if first else hit_dist
		first = false
		append(&out, rs)
	}
	return out
}

get_all_components_of_type :: proc(
	entity: ^Entity,
	type: ShipComponentType,
	is_functioning := true,
) -> []^ShipComponent {
	out := make([dynamic]^ShipComponent)
	for &i in entity.ship_data.components {
		if (i.health > 0 || !is_functioning) && i.type == type {
			append(&out, &i)
		}
	}
	return out[:]
}

get_all_components_of_type_facing_in_direction :: proc(
	entity: ^Entity,
	type: ShipComponentType,
	direction: Vec3,
	is_functioning := true,
	dot_threshold := 0.01,
) -> []^ShipComponent {
	out := make([dynamic]^ShipComponent)
	trans: linalg.Quaternionf64 = entity.physics.rotation
	for &i in entity.ship_data.components {
		if (i.health > 0 || !is_functioning) && i.type == type {
			d0 := cast([3]f64)i.direction
			dir := linalg.quaternion256_mul_vector3(trans, d0)
			if (linalg.dot(dir, direction) > dot_threshold) {
				append(&out, &i)
			}
		}
	}
	return out[:]
}

ShipYard :: struct {
	tags:               bit_set[EntityTag],
	type:               EntityType,
	position:           Vec3,
	velocity:           Vec3,
	angular_velocity:   Vec3,
	facing:             Vec3,
	up:                 Vec3,
	length:             f64,
	width:              f64,
	height:             f64,
	components:         [dynamic]ShipComponent,
	inventory:          Inventory,
	fuel:               i32,
	tint:               raylib.Color,
	mesh:               string,
	is_projectile:      bool,
	is_static:          bool,
	use_dims_for_scale: bool,
	model_scale:        Vec3,
	health:             i32,
}

ship_yard_build :: proc(yard: ^ShipYard) -> (EntityRef, ^Entity) {
	ent: Entity
	ent.physics.position = yard.position
	ent.physics.rotation = linalg.quaternion_look_at_f64(
		yard.position,
		yard.position + yard.facing,
		yard.up,
	)
	ent.physics.collision_response = .Slide
	ent.physics.is_projectile = yard.is_projectile
	ent.physics.is_static = yard.is_static
	ent.physics.length = yard.length
	ent.physics.width = yard.width
	ent.physics.height = yard.height
	ent.model_scale =
		{yard.length, yard.width, yard.height} if yard.use_dims_for_scale else yard.model_scale
	ent.fuel = yard.fuel
	ent.tint = yard.tint
	ent.tags = yard.tags
	ent.health = yard.health
	ent.type = yard.type
	ent.mesh = strings.clone(yard.mesh)
	ent.physics.velocity = yard.velocity
	ent.physics.angular_velocity = yard.angular_velocity
	ent.ship_data.components = make_slice([]ShipComponent, len(yard.components))
	for i, idx in yard.components {
		ent.ship_data.components[idx] = i
	}
	return create_entity(ent)
}

create_ship_yard :: proc(type: EntityType) -> ^ShipYard {
	out := new(ShipYard)
	out.components = make([dynamic]ShipComponent)
	out.facing = {1, 0, 0}
	out.up = {0, 0, 1}
	out.fuel = 0
	out.health = 1
	out.height = 1.
	out.width = 1
	out.length = 1
	out.is_projectile = false
	out.is_static = false
	out.model_scale = {1, 1, 1}
	out.mesh = strings.clone("cube")
	out.use_dims_for_scale = true
	out.tint = {255, 255, 255, 255}
	out.type = type
	return out
}

destroy_ship_yard :: proc(yard: ^ShipYard) {
	delete(yard.components)
	delete(yard.mesh)
	free(yard)
}

ship_yard_set_pos :: proc(yard: ^ShipYard, pos: Vec3) {
	yard.position = pos
}

ship_yard_set_looking_in_direction :: proc(yard: ^ShipYard, direction: Vec3) {
	rot := linalg.quaternion_look_at_f64({}, direction, yard.up)
	yard.up = linalg.quaternion256_mul_vector3(rot, yard.up)
	yard.facing = direction
}

ship_yard_set_tag :: proc(yard: ^ShipYard, tag: EntityTag) {
	yard.tags |= {tag}
}

ship_yard_unset_tag :: proc(yard: ^ShipYard, tag: EntityTag) {
	yard.tags ~= {tag}
}

ship_yard_set_dims :: proc(yard: ^ShipYard, length: f64, width: f64, height: f64) {
	yard.length = length
	yard.height = height
	yard.width = width
}

ship_yard_set_use_dims_for_scale :: proc(yard: ^ShipYard, use_dims_for_scale: bool) {
	yard.use_dims_for_scale = use_dims_for_scale
}

ship_yard_add_to_inventory :: proc(yard: ^ShipYard, item: InventoryItem, count: i32) {
	yard.inventory.items[item] += count
	assert(yard.inventory.items[item] >= 0)
}

ship_yard_set_fuel :: proc(yard: ^ShipYard, fuel: i32) {
	yard.fuel = fuel
}

ship_yard_set_color :: proc(yard: ^ShipYard, color: raylib.Color) {
	yard.tint = color
}

ship_yard_set_mesh :: proc(yard: ^ShipYard, mesh: string) {
	delete(yard.mesh)
	yard.mesh = strings.clone(mesh)
}

ship_yard_set_is_projectile :: proc(yard: ^ShipYard, is_projectile: bool) {
	yard.is_projectile = is_projectile
}

ship_yard_set_is_static :: proc(yard: ^ShipYard, is_static: bool) {
	yard.is_static = is_static
}

ship_yard_set_model_scale :: proc(yard: ^ShipYard, scale: Vec3) {
	yard.model_scale = scale
}

ship_yard_set_health :: proc(yard: ^ShipYard, health: i32) {
	yard.health = health
}

ship_yard_set_velocity :: proc(yard: ^ShipYard, velocity: Vec3) {
	yard.velocity = velocity
}

ship_yard_set_angular_velocity :: proc(yard: ^ShipYard, angular_velocity: Vec3) {
	yard.angular_velocity = angular_velocity
}

get_comp_max_health :: proc(type: ShipComponentType) -> i32 {
	switch type {
	case .Cockpit:
		return 10
	case .Cabin:
		return 10
	case .Hold:
		return 10
	case .Engine:
		return 20
	case .FuelTank:
		return 5
	case .PointDefenseWeapon:
		return 5
	case .TorpedoTube:
		return 5
	case .Laser:
		return 5
	case .Magazine:
		return 5
	}
	return 0
}

get_comp_damage_reistance :: proc(type: ShipComponentType) -> i32 {
	switch type {
	case .Cockpit:
		return 2
	case .Cabin:
		return 2
	case .Hold:
		return 2
	case .Engine:
		return 5
	case .FuelTank:
		return 0
	case .PointDefenseWeapon:
		return 1
	case .TorpedoTube:
		return 1
	case .Laser:
		return 1
	case .Magazine:
		return 3
	}
	return 0
}

ship_yard_add_component :: proc(
	yard: ^ShipYard,
	type: ShipComponentType,
	offset: Vec3,
	length: f64,
	width: f64,
	height: f64,
	direction: Vec3 = {1, 0, 0},
) {
	comp: ShipComponent
	comp.type = type
	comp.offset = cast([3]f32)comp.offset
	comp.length = cast(f32)length
	comp.width = cast(f32)width
	comp.height = cast(f32)height
	comp.direction = cast([3]f32)direction
	comp.pressure = 1000
	comp.temperature = 290
	comp.damage_resistance = get_comp_damage_reistance(type)
	comp.health = get_comp_max_health(type)
}

ItemCount :: struct {
	item:  InventoryItem,
	count: i32,
}

ShipCompSpec :: struct {
	type:      ShipComponentType,
	offset:    Vec3,
	dim:       Vec3,
	direction: Vec3,
}

ShipDesign :: struct {
	type:       EntityType,
	mesh:       string,
	fuel:       i32,
	health:     i32,
	length:     f64,
	width:      f64,
	height:     f64,
	components: []ShipCompSpec,
	inventory:  []ItemCount,
}


ship_yard_from_design :: proc(design: ^ShipDesign) -> ^ShipYard {
	out := create_ship_yard(design.type)
	out.fuel = design.fuel
	out.health = design.health
	out.length = design.length
	out.width = design.width
	out.height = design.height
	ship_yard_set_mesh(out, design.mesh)
	for i in design.inventory {
		ship_yard_add_to_inventory(out, i.item, i.count)
	}
	for i in design.components {
		dir := Vec3{1, 0, 0} if i.direction == {} else i.direction
		ship_yard_add_component(out, i.type, i.offset, i.dim.x, i.dim.y, i.dim.z)
	}
	return out
}
