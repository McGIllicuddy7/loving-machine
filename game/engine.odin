package game
import "core:container/queue"
import "core:fmt"
import "core:mem"
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
}

EntityType :: enum {
	InanimateObject,
	Bullet,
	Missile,
	Ship,
}

EntityMesh :: enum {
	Sphere,
	Cube,
	Cylinder,
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

Entity :: struct {
	_object_lock: sync.Mutex,
	engine:       PhysicsObject,
	this_ref:     EntityRef,
	tags:         bit_set[EntityTag],
	type:         EntityType,
	mesh:         EntityMesh,
	inventory:    Inventory,
	fuel:         i32,
	health:       i32,
}

DamageEvent :: struct {
	damaged_entity:  EntityRef,
	damaging_entity: EntityRef,
	damage:          i32,
}

Event :: union {
	engine.CollisionEvent,
	DamageEvent,
}

System :: proc(delta_time: f32)

EventHook :: proc(event: Event) -> (consumed_event: bool)

EntityMetaData :: struct {
	is_alive:   bool,
	generation: u32,
}

Level :: struct {
	entities:         [MAX_ENTITY_COUNT]Entity,
	entity_meta_data: #soa[MAX_ENTITY_COUNT]EntityMetaData,
	level_arena:      mem.Dynamic_Arena,
	frame_arena:      mem.Dynamic_Arena,
	event_queue:      queue.Queue(Event),
}

GameRuntime :: struct {
	level:   Level,
	systems: map[string]System,
	hooks:   map[string]EventHook,
}

RUNTIME: GameRuntime

frame_allocator :: proc() -> mem.Allocator {
	return mem.dynamic_arena_allocator(&RUNTIME.level.frame_arena)
}

level_allocator :: proc() -> mem.Allocator {
	return mem.dynamic_arena_allocator(&RUNTIME.level.level_arena)
}

game_init :: proc() {
	RUNTIME.systems = make(map[string]System)
	RUNTIME.hooks = make(map[string]EventHook)
	mem.dynamic_arena_init(&RUNTIME.level.level_arena)
	mem.dynamic_arena_init(&RUNTIME.level.frame_arena)
	queue.init(&RUNTIME.level.event_queue)
	raylib.InitWindow(1200, 900, "odin")
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


run_systems :: proc() {}

run_graphics :: proc() {}

game_loop :: proc() {}

fsprintf :: proc(fmtr: string, args: ..any) -> string {
	return fmt.aprintf(fmtr, args, allocator = frame_allocator())
}

lsprintf :: proc(fmtr: string, args: ..any) -> string {
	return fmt.aprintf(fmtr, args, allocator = level_allocator())
}
