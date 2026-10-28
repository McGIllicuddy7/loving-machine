package engine
import "base:intrinsics"
import "base:runtime"
import "core:container/queue"
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import "core:sync"

import "vendor:raylib"


Log :: struct {
	content:        cstring,
	remaining_time: f64,
}

Logs :: struct {
	lock:   sync.Mutex,
	values: [dynamic]Log,
}
MAX_ENTITY_COUNT :: 16384
POOLED_CHEAP_ENTITY_COUNT :: 16384

EventData :: union {
	CollisionEvent,
}
Event :: struct {
	target: EntityRef,
	data:   EventData,
}

EntityTag :: enum {}

EntityMesh :: struct {
	name:                  string,
	diffuse_map_name:      string,
	normal_map_name:       string,
	color:                 raylib.Color,
	offset:                Transform,
	use_custom_dimensions: bool,
	length:                f64,
	width:                 f64,
	height:                f64,
}

OnUpdateType :: #type proc(this: ^Entity, delta_time: f32)
OnRenderType :: #type proc(this: ^Entity)
OnEventType :: #type proc(this: ^Entity, event: Event)
DestructorType :: #type proc(this: ^Entity)


EntityVtable :: struct {
	on_update:  OnUpdateType,
	on_render:  OnRenderType,
	on_event:   OnEventType,
	destructor: DestructorType,
}

DEFAULT_ENTITY_TABLE: EntityVtable = {}
/*
	any fields here will be destroyed in the calling code for destructor
	nearly any functionality for most entities should be usable with the base entity class maybe with altarations to on_update or on_event
	meshes will be rendered automatically, on_render is for custom other rendering,for example ui
	use engine_alloc() or the provided allocation functions(eg string_clone) for all allocations stored in the entity otherwise REALLLY BAD THINGS
*/
Entity :: struct {
	_type:            typeid,
	tags:             bit_set[EntityTag],
	self_ref:         EntityRef,
	phys:             PhysicsObject,
	control_rotation: Quat,
	mesh:             EntityMesh,
	health:           i32,
	on_update:        #type proc(this: ^Entity, delta_time: f32),
	on_render:        #type proc(this: ^Entity),
	on_event:         #type proc(this: ^Entity, event: Event),
	destructor:       #type proc(this: ^Entity),
}

TaggedEntity :: struct {
	tag: EntityRef,
	ptr: ^Entity,
}


EntityManager :: struct {
	alloc_lock:                  sync.Mutex,
	entities:                    [MAX_ENTITY_COUNT]^Entity,
	generations:                 [MAX_ENTITY_COUNT]u32,
	cheap_entity_pool_buffer:    [POOLED_CHEAP_ENTITY_COUNT]Entity,
	cheap_entity_pool_allocated: [POOLED_CHEAP_ENTITY_COUNT]bool,
	destroy_list_lock:           sync.Mutex,
	to_destroy_list:             queue.Queue(EntityRef),
	entity_list:                 [dynamic]^Entity,
	physics_object_list:         [dynamic]TaggedPhysicsObject,
}

World :: struct {
	camera:                raylib.Camera3D,
	camera_set_this_frame: bool,
	entities:              EntityManager,
	event_lock:            sync.Mutex,
	events:                queue.Queue(Event),
}

_get_entity_manager :: proc() -> ^EntityManager {
	return &ENGINE.world.entities
}

_get_world :: proc() -> ^World {
	return &ENGINE.world
}


Engine :: struct {
	level_arena:              mem.Dynamic_Arena,
	level_allocator:          mem.Mutex_Allocator,
	frame_arena:              mem.Dynamic_Arena,
	frame_allocator:          mem.Mutex_Allocator,
	engine_backing_allocator: mem.Mutex_Allocator,
	engine_allocator:         mem.Allocator,
	graphics_context:         ^GraphicsContext,
	logs:                     Logs,
	world:                    World,
}


ENGINE: Engine

frame_alloc :: proc() -> mem.Allocator {
	return mem.mutex_allocator(&ENGINE.frame_allocator)
}

level_alloc :: proc() -> mem.Allocator {
	return mem.mutex_allocator(&ENGINE.level_allocator)
}

setup_world :: proc() {
	{
		manager := _get_entity_manager()
		manager^ = {}
		manager.entity_list = make([dynamic]^Entity, engine_alloc())
		manager.physics_object_list = make([dynamic]TaggedPhysicsObject, engine_alloc())
		queue.init(&manager.to_destroy_list)
	}
	{
		world := _get_world()
		queue.init(&world.events)
		world.camera_set_this_frame = false
		world.camera.fovy = 90.
		world.camera.position = {}
		world.camera.target = {1, 0, 0}
		world.camera.up = {0, 0, 1}
		world.camera.projection = .PERSPECTIVE
	}
}

unload_world :: proc() {
	{
		manager := _get_entity_manager()
		for i in manager.entities {
			if i != nil {
				finalize_entity(i)
			}
		}
		for &i in manager.entities {
			if i != nil {
				delete_entity_backing_after_finalization(i)
				i = nil
			}
		}
		delete(manager.physics_object_list)
		delete(manager.entity_list)
		queue.destroy(&manager.to_destroy_list)
		manager.physics_object_list = {}
		manager.entity_list = {}
		manager.to_destroy_list = {}
	}
	{
		world := _get_world()
		for queue.len(world.events) > 0 {
			tmp := queue.pop_front(&world.events)
			destroy_event(tmp)
		}
		queue.destroy(&world.events)
	}
}

init :: proc(use_graphics := true) {
	mem.mutex_allocator_init(&ENGINE.engine_backing_allocator, context.allocator)
	ENGINE.engine_allocator = mem.mutex_allocator(&ENGINE.engine_backing_allocator)
	mem.dynamic_arena_init(&ENGINE.level_arena)
	mem.dynamic_arena_init(&ENGINE.frame_arena)
	ENGINE.frame_allocator.backing = mem.dynamic_arena_allocator(&ENGINE.frame_arena)
	ENGINE.level_allocator.backing = mem.dynamic_arena_allocator(&ENGINE.level_arena)
	if use_graphics {
		ENGINE.graphics_context = create_graphics_context()
	}
	setup_world()
}


fini :: proc() {
	unload_world()
	mem.dynamic_arena_destroy(&ENGINE.level_arena)
	mem.dynamic_arena_destroy(&ENGINE.frame_arena)
	if ENGINE.graphics_context != nil {
		destroy_graphics_context(ENGINE.graphics_context)
	}
	for i in ENGINE.logs.values {
		delete(i.content)
	}
	delete(ENGINE.logs.values)
}

fsprintf :: proc(fmtr: string, args: ..any) -> string {
	return fmt.aprintf(fmtr, args, allocator = frame_alloc())
}

lsprintf :: proc(fmtr: string, args: ..any) -> string {
	return fmt.aprintf(fmtr, args, allocator = level_alloc())
}

reset_frame_alloc :: proc() {
	sync.lock(&ENGINE.frame_allocator.mutex)
	defer sync.unlock(&ENGINE.frame_allocator.mutex)
	mem.dynamic_arena_free_all(&ENGINE.frame_arena)
}

reset_level_alloc :: proc() {
	sync.lock(&ENGINE.level_allocator.mutex)
	defer sync.unlock(&ENGINE.level_allocator.mutex)
	mem.dynamic_arena_free_all(&ENGINE.level_arena)
}

log :: proc(msg: string, duration := 5.) {
	sync.mutex_lock(&ENGINE.logs.lock)
	defer sync.mutex_unlock(&ENGINE.logs.lock)
	msg := Log{strings.clone_to_cstring(msg), duration}
	append(&ENGINE.logs.values, msg)
}


engine_alloc :: proc() -> mem.Allocator {
	return ENGINE.engine_allocator
}

destroy_mesh :: proc(msh: ^EntityMesh) {
	if msh.name != "" {
		string_free(msh.name)
	}
	if msh.diffuse_map_name != "" {
		string_free(msh.diffuse_map_name)
	}
	if msh.normal_map_name != "" {
		string_free(msh.normal_map_name)
	}
}

string_clone :: proc(s: string) -> string {
	return strings.clone(s, engine_alloc())
}

string_free :: proc(s: string) {
	delete(s, engine_alloc())
}


destroy_event :: proc(ev: Event) {
	switch v in ev.data {
	case CollisionEvent:
	case:
	}
}

create_entity :: proc(
	$T: typeid,
	vtable := DEFAULT_ENTITY_TABLE,
	loc := #caller_location,
) -> (
	EntityRef,
	^T,
) {
	create_entity_inner :: proc(
		$T: typeid,
		vtable: EntityVtable,
		loc: runtime.Source_Code_Location,
	) -> (
		EntityRef,
		^T,
	) {
		out: ^T = nil
		out_ref: EntityRef
		manager := _get_entity_manager()
		sync.lock(&manager.alloc_lock)
		defer sync.unlock(&manager.alloc_lock)
		for i in 0 ..< len(manager.entities) {
			if manager.entities[i] == nil {
				out = new(T, engine_alloc(), loc)
				mem.set(out, 0, size_of(out^))
				manager.generations[i] += 1
				out_ref.gen = manager.generations[i]
				out_ref.idx = cast(u32)i
				tmp: ^Entity = cast(^Entity)out
				tmp.destructor = vtable.destructor
				tmp.on_event = vtable.on_event
				tmp.on_render = vtable.on_render
				tmp.on_update = vtable.on_update
				tmp.self_ref = out_ref
				manager.entities[i] = tmp
				break
			}
		}
		return out_ref, out
	}
	when !intrinsics.type_is_struct(T) {
		#panic("type must inherit entity")
	} else when T == Entity {
		return create_entity_inner(T, vtable, loc)
	} else when intrinsics.type_has_field(T, "_parent") {
		when intrinsics.type_field_type(T, "_parent") == Entity && offset_of(T, _parent) == 0 {
			return create_entity_inner(T, vtable, loc)
		} else {
			#panic("type must inherit entity")
		}
	} else {
		#panic("type must inherit entity")
	}
}

destroy_entity :: proc(rf: EntityRef) {
	manager := _get_entity_manager()
	sync.mutex_lock(&manager.destroy_list_lock)
	defer sync.mutex_unlock(&manager.destroy_list_lock)
	queue.push_back(&manager.to_destroy_list, rf)
}


finalize_entity :: proc(et: ^Entity) {
	if et != nil {
		if et.destructor != nil {
			et->destructor()
		}
		destroy_mesh(&et.mesh)
	}
}

delete_entity_backing_after_finalization :: proc(et: ^Entity) {
	free(et, engine_alloc())
}

frame_destroy_entities :: proc() {
	manager := _get_entity_manager()
	for {
		rf: EntityRef
		{
			sync.mutex_lock(&manager.destroy_list_lock)
			defer sync.mutex_unlock(&manager.destroy_list_lock)
			if queue.len(manager.to_destroy_list) == 0 {
				break
			}
			rf = queue.pop_front(&manager.to_destroy_list)
		}
		if cast(u32)len(manager.entities) <= rf.idx {
			continue
		}
		if manager.generations[rf.idx] != rf.gen {
			continue
		}
		if manager.entities[rf.idx] == nil {
			continue
		}
		finalize_entity(manager.entities[rf.idx])
		delete_entity_backing_after_finalization(manager.entities[rf.idx])
		{
			sync.lock(&manager.alloc_lock)
			defer sync.unlock(&manager.alloc_lock)
			manager.entities[rf.idx] = nil
		}
	}
}

get_entity :: proc(et: EntityRef) -> ^Entity {
	manager := _get_entity_manager()
	if et.idx < len(manager.entities) {
		if et.gen == manager.generations[et.idx] {
			return manager.entities[et.idx]
		}
	}
	return nil
}

get_all_entities :: proc() -> []^Entity {
	return _get_entity_manager().entity_list[:]
}

_get_all_physics_objects :: proc() -> []TaggedPhysicsObject {
	return _get_entity_manager().physics_object_list[:]
}

broadcast_event :: proc(ev: Event) {
	world := _get_world()
	sync.mutex_lock(&world.event_lock)
	defer sync.mutex_unlock(&world.event_lock)
	queue.push_back(&world.events, ev)
}

game_tick :: proc() {
	engine := &ENGINE
	world := _get_world()
	world.camera_set_this_frame = false
	mem.dynamic_arena_free_all(&engine.frame_arena)
	manager := _get_entity_manager()
	delta_time := cast(f32)(1. / 60.)
	if engine.graphics_context != nil {
		delta_time = raylib.GetFrameTime()
	}
	clear(&manager.entity_list)
	idx := 0
	for &i in manager.entities {
		if i != nil {
			idx += 1
			append(&manager.entity_list, i)
		}
	}
	entity_list := get_all_entities()
	{
		clear(&manager.physics_object_list)
		for i in entity_list {
			assert(i != nil)
			append(&manager.physics_object_list, TaggedPhysicsObject{i.self_ref, &i.phys})
		}
		events := physics_update(_get_all_physics_objects(), cast(f64)delta_time, frame_alloc())
		world := _get_world()
		sync.lock(&world.event_lock)
		defer sync.unlock(&world.event_lock)
		for i in events {
			queue.push_back(&world.events, Event{i.collided_with_entity, i})
		}
	}
	{

		for i in entity_list {
			if i.on_update != nil {
				i->on_update(delta_time)
			}
		}
	}
	if ENGINE.graphics_context != nil {
		for i in entity_list {
			if i.on_render != nil {
				i->on_render()
			}
		}
		if !world.camera_set_this_frame {
			raylib.UpdateCamera(&world.camera, .FREE)
		}
		set_camera(world.camera)
		for i in entity_list {
			if i.mesh.name != "" {
				trs := i.mesh.offset
				if trs.rotation == Quat(0) {
					trs.rotation = Quat(1)
				}
				trs.rotation = i.phys.rotation * trs.rotation
				trs.position = linalg.quaternion256_mul_vector3(trs.rotation, trs.position)
				trs.position += i.phys.position
				dims := Vec3{i.phys.length, i.phys.width, i.phys.height}
				if i.mesh.use_custom_dimensions {
					dims = {i.mesh.length, i.mesh.width, i.mesh.height}
				}
				bind_model(i.mesh.name, trs, dims, i.mesh.color)
			}
		}
		graphics_step()
	}
	{

		for {
			ev: Event
			{
				world := _get_world()
				sync.mutex_lock(&world.event_lock)
				defer sync.mutex_unlock(&world.event_lock)
				if queue.len(world.events) == 0 {
					break
				}
				ev = queue.pop_front(&world.events)
			}
		}
	}
	frame_destroy_entities()
}
