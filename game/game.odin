package game
import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sync"
import "engine"
import "vendor:raylib"

Vec3 :: engine.Vec3
Quat :: engine.Quat
EntityRef :: engine.EntityRef
Transform :: engine.Transform
PhysicsObject :: engine.PhysicsObject

MAX_ENTITY_COUNT :: 16384

EntityTag :: enum {
	OnFire,
	IsPlayer,
	IsVisible,
	IsTransferred,
}

EntityType :: enum {
	InanimateObject = 0,
	Bullet,
	Missile,
	Ship,
}


InventoryItem :: enum {
	Bullet,
	Missile,
	COUNT,
}

INVENTORY_ITEM_COUNT :: cast(i64)InventoryItem.COUNT

Inventory :: struct {
	items: [INVENTORY_ITEM_COUNT]i32,
}

AiData :: struct {}

Entity :: struct {
	_object_lock: sync.Mutex,
	physics:      PhysicsObject,
	this_ref:     EntityRef,
	tags:         bit_set[EntityTag],
	type:         EntityType,
	mesh:         string,
	inventory:    Inventory,
	fuel:         i32,
	health:       i32,
	tint:         raylib.Color,
	ai_data:      AiData,
}

DamageEvent :: struct {
	damaged_entity:  EntityRef,
	damaging_entity: EntityRef,
	damage:          i32,
}

EntityDestroyedEvent :: struct {
	destroyed_entity:  EntityRef,
	destroying_entity: EntityRef,
}

Event :: union {
	engine.CollisionEvent,
	DamageEvent,
	EntityDestroyedEvent,
}

System :: proc(delta_time: f32)

EventHook :: proc(event: Event) -> (consumed_event: bool)
LevelLoader :: proc(path: string, traveller_count: int) -> (spawns: []Transform)

EntityMetaData :: struct {
	is_alive:   bool,
	generation: u32,
}

LoadLevelInfo :: struct {
	path:        string,
	loader:      LevelLoader,
	should_load: bool,
	is_transfer: bool,
}

Level :: struct {
	entities:         [MAX_ENTITY_COUNT]Entity,
	entity_meta_data: #soa[MAX_ENTITY_COUNT]EntityMetaData,
	event_queue:      queue.Queue(Event),
	destructor_queue: queue.Queue(EntityRef),
}

GameRuntime :: struct {
	dbg_camera:    raylib.Camera3D,
	level:         Level,
	systems:       map[string]System,
	hooks:         map[string]EventHook,
	transfer_lock: sync.Mutex,
	transfer_info: LoadLevelInfo,
}

RUNTIME: GameRuntime


game_init :: proc() {
	engine.init()
	RUNTIME.systems = make(map[string]System)
	RUNTIME.hooks = make(map[string]EventHook)
	queue.init(&RUNTIME.level.event_queue)
}

register_system :: proc(name: string, system: System) {
	RUNTIME.systems[name] = system
}

register_event_hook :: proc(name: string, hook: EventHook) {
	RUNTIME.hooks[name] = hook
}

deregister_system :: proc(name: string) {
	delete_key(&RUNTIME.systems, name)
}

deregister_event_hook :: proc(name: string) {
	delete_key(&RUNTIME.hooks, name)
}

broadcast_event :: proc(event: Event) {
	queue.push_back(&RUNTIME.level.event_queue, event)
}

process_events :: proc() {
	for {
		if queue.len(RUNTIME.level.event_queue) == 0 {
			break
		}
		ev := queue.pop_front(&RUNTIME.level.event_queue)
		for _, hook in RUNTIME.hooks {
			if (hook(ev)) {
				break
			}
		}
	}
	for {
		if queue.len(RUNTIME.level.destructor_queue) == 0 {
			break
		}
		et := queue.pop_front(&RUNTIME.level.destructor_queue)
		finalize_entity(et)
	}
}

run_systems :: proc() {
	RUNTIME.transfer_info = {}
	ft := raylib.GetFrameTime()
	for _, sys in RUNTIME.systems {
		sys(ft)
	}
	physics_buffer := make([dynamic]engine.TaggedPhysicsObject)
	defer delete(physics_buffer)
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			tg := engine.TaggedPhysicsObject{}
			tg.ref.idx = cast(u32)i
			tg.ref.gen = RUNTIME.level.entity_meta_data[i].generation
			tg.ptr = &RUNTIME.level.entities[i].physics
			append(&physics_buffer, tg)
		}
	}
	events := engine.physics_update(physics_buffer[:], 1. / 60, engine.frame_alloc())
	for i in events {
		queue.append(&RUNTIME.level.event_queue, i)
	}

}

run_graphics :: proc() {
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			tmp := &RUNTIME.level.entities[i]
			if .IsVisible in tmp.tags {
				engine.bind_model(tmp.mesh, tmp.physics.trans, tmp.tint)
			}
		}
	}
}

game_loop :: proc() {
	for !raylib.WindowShouldClose() {
		engine.reset_frame_alloc()
		game_tick()
		engine.graphics_step()
	}
}


game_tick :: proc() {
	run_systems()
	run_graphics()
	process_events()
	handle_level_transfer()
}


get_entity :: proc(et: EntityRef) -> ^Entity {
	if et.idx >= len(RUNTIME.level.entity_meta_data) {
		return nil
	}
	if RUNTIME.level.entity_meta_data[et.idx].is_alive &&
	   RUNTIME.level.entity_meta_data[et.idx].generation == et.gen {
		return &RUNTIME.level.entities[et.idx]
	}
	return nil
}

entity_is_valid :: proc(et: EntityRef) -> bool {
	return get_entity(et) != nil
}

create_entity :: proc(base: Entity = {}) -> (EntityRef, ^Entity) {
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if !RUNTIME.level.entity_meta_data[i].is_alive {
			RUNTIME.level.entity_meta_data[i].generation += 1
			RUNTIME.level.entity_meta_data[i].is_alive = true
			idx := cast(u32)i
			gen := RUNTIME.level.entity_meta_data[i].generation
			rf := EntityRef{idx, gen}
			ptr := &RUNTIME.level.entities[i]
			ptr^ = base
			return rf, ptr
		}
	}
	return {}, nil

}

destroy_entity :: proc(ent: EntityRef, destroyer: EntityRef = {}) {
	queue.push_back(&RUNTIME.level.destructor_queue, ent)
	broadcast_event(EntityDestroyedEvent{ent, destroyer})
}

destroy_entity_by_ptr :: proc(ent: ^Entity, destroyer: EntityRef = {}) {
	if ent == nil {
		return
	}
	queue.push_back(&RUNTIME.level.destructor_queue, ent.this_ref)
	broadcast_event(EntityDestroyedEvent{ent.this_ref, destroyer})
}

run_entity_destructor :: proc(enty: ^Entity) {
	if enty == nil {
		return
	}
	if enty.mesh != "" {
		delete(enty.mesh)
	}
	enty^ = {}
}

finalize_entity :: proc(ent: EntityRef) {
	enty := get_entity(ent)
	run_entity_destructor(enty)
	RUNTIME.level.entity_meta_data[ent.idx].is_alive = false
}

handle_level_transfer :: proc() {
	if !RUNTIME.transfer_info.should_load {
		return
	}
	players := make([dynamic]Entity)
	defer delete(players)
	if RUNTIME.transfer_info.is_transfer {
		for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
			if RUNTIME.level.entity_meta_data[i].is_alive {
				if .IsTransferred in RUNTIME.level.entities[i].tags {
					tmp := entity_clone(RUNTIME.level.entities[i])
					append(&players, tmp)
				}
			}
		}
	}
	unload_level()
	spawns := RUNTIME.transfer_info.loader(RUNTIME.transfer_info.path, len(players))
	RUNTIME.transfer_info.should_load = false
	assert(len(players) <= len(spawns))
	for i, idx in players {
		tmp := i
		tmp.this_ref = {}
		tmp.ai_data = {}
		tmp.physics.velocity = {}
		tmp.physics.angular_velocity = {}
		tmp.physics.trans = spawns[idx]
		rf, et := create_entity(tmp)
		et.this_ref = rf
	}
}

unload_level :: proc() {
	queue.clear(&RUNTIME.level.destructor_queue)
	queue.clear(&RUNTIME.level.event_queue)
	RUNTIME.level.entity_meta_data = {}
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			run_entity_destructor(&RUNTIME.level.entities[i])
		}
	}
	engine.reset_level_alloc()
}

entity_clone :: proc(entity: Entity) -> Entity {
	tmp := entity
	tmp.mesh = strings.clone(tmp.mesh)
	return tmp
}

get_all_entities_with_tag :: proc(tag: EntityTag) -> [](^Entity) {
	out := make([dynamic]^Entity, engine.frame_alloc())
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			et := &RUNTIME.level.entities[i]
			if tag in et.tags {
				append(&out, et)
			}
		}
	}
	return out[:]
}

get_all_entities_with_set_of_tags :: proc(tags: []EntityTag) -> [](^Entity) {
	out := make([dynamic]^Entity, engine.frame_alloc())
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			et := &RUNTIME.level.entities[i]
			contains := true
			for j in tags {
				if !(j in et.tags) {
					contains = false
					break
				}
			}
			if contains {
				append(&out, et)
			}
		}
	}
	return out[:]
}

get_all_entities_with_any_of_set_of_tags :: proc(tags: []EntityTag) -> [](^Entity) {
	out := make([dynamic]^Entity, engine.frame_alloc())
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			et := &RUNTIME.level.entities[i]
			contains := false
			for j in tags {
				if j in et.tags {
					contains = true
					break
				}
			}
			if contains {
				append(&out, et)
			}
		}
	}
	return out[:]
}

get_all_entities_of_type :: proc(type: EntityType) -> []^Entity {
	out := make([dynamic]^Entity, engine.frame_alloc())
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			et := &RUNTIME.level.entities[i]
			if et.type == type {
				append(&out, et)
			}
		}
	}
	return out[:]
}

get_all_entities :: proc() -> []^Entity {
	out := make([dynamic]^Entity, engine.frame_alloc())
	for i in 0 ..< len(RUNTIME.level.entity_meta_data) {
		if RUNTIME.level.entity_meta_data[i].is_alive {
			et := &RUNTIME.level.entities[i]
			append(&out, et)
		}
	}
	return out[:]
}

game_fini :: proc() {
	engine.fini()
	queue.destroy(&RUNTIME.level.event_queue)
	delete(RUNTIME.hooks)
	delete(RUNTIME.systems)
}
