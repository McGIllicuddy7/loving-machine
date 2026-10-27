package engine
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sync"
Log :: struct {
	content:        cstring,
	remaining_time: f64,
}

Logs :: struct {
	lock:   sync.Mutex,
	values: [dynamic]Log,
}
Engine :: struct {
	level_arena:      mem.Dynamic_Arena,
	level_allocator:  mem.Mutex_Allocator,
	frame_arena:      mem.Dynamic_Arena,
	frame_allocator:  mem.Mutex_Allocator,
	graphics_context: ^GraphicsContext,
	logs:             Logs,
}

ENGINE: Engine

frame_alloc :: proc() -> mem.Allocator {
	return mem.mutex_allocator(&ENGINE.frame_allocator)
}

level_alloc :: proc() -> mem.Allocator {
	return mem.mutex_allocator(&ENGINE.level_allocator)
}

init :: proc() {
	mem.dynamic_arena_init(&ENGINE.level_arena)
	mem.dynamic_arena_init(&ENGINE.frame_arena)
	ENGINE.frame_allocator.backing = mem.dynamic_arena_allocator(&ENGINE.frame_arena)
	ENGINE.level_allocator.backing = mem.dynamic_arena_allocator(&ENGINE.level_arena)
	ENGINE.graphics_context = create_graphics_context()
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

fini :: proc() {
	mem.dynamic_arena_destroy(&ENGINE.level_arena)
	mem.dynamic_arena_destroy(&ENGINE.frame_arena)
	destroy_graphics_context(ENGINE.graphics_context)
	for i in ENGINE.logs.values {
		delete(i.content)
	}
	delete(ENGINE.logs.values)
}

Pool :: struct($T: typeid, $size: int) {
	lock:  sync.Mutex,
	pool:  [size]T,
	table: [size]bool,
}

pool_alloc :: proc(pool: ^Pool($T, $size)) -> ^T {
	sync.lock(&pool.lock)
	defer sync.unlock(&pool.lock)
	for i in 0 ..< size {
		if !pool.table[i] {
			pool.table[i] = true
			mem.set(&pool.pool[i], 0, sizeof(pool.pool[i]))
			return &pool.pool[i]
		}
	}
	return nil
}

pool_free :: proc(pool: ^Pool($T, $size), ptr: ^T) {
	sync.lock(&pool.lock)
	defer sync.unlock(&pool.lock)
	pt := cast(uintptr)ptr
	start := cast(uintptr)&pool.pool[0]
	end := cast(uintptr)&pool.pool[size - 1]
	if start <= pt && pt < end {
		i := (pt - start) / sizeof(T)
		pool.table[i] = false
		assert(&pool.pool[i] == ptr)
		mem.set(&pool.pool[i], 0, sizeof(T))
	} else {
		panic("attempted to free a non allocated pointer")
	}
	return nil
}
