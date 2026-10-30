
package engine
import "base:builtin"
import "base:runtime"
import "core:encoding/cbor"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:strings"

EntityBlob :: struct {
	this_ref:  EntityRef,
	type_name: string,
	data:      string,
}

DaemonBlob :: struct {
	type_name: string,
	data:      string,
}

SaveStateBlob :: struct {
	entities:    []EntityBlob,
	daemons:     []DaemonBlob,
	system_data: map[string]string,
}

EntitySpawnData :: struct {
	class:       string,
	custom_data: string,
	transform:   Transform,
}

MeshSpawnData :: struct {
	mesh:      EntityMesh,
	transform: Transform,
}

DaemonSpawnData :: struct {
	name: string,
	data: string,
}

SystemInputData :: struct {
	target: string,
	data:   string,
}

LevelData :: struct {
	player_class:      string,
	player_spawns:     []Transform,
	entity_spawn_data: []EntitySpawnData,
	mesh_spawn_data:   []MeshSpawnData,
	daemon_spawn_data: []DaemonSpawnData,
}

EntityClass :: struct {
	id:                 typeid,
	create_at_location: #type proc(transform: Transform, data: string) -> ^Entity,
	on_update:          #type proc(this: ^Entity, delta_time: f32),
	on_render:          #type proc(this: ^Entity),
	on_event:           #type proc(this: ^Entity, event: Event),
	destructor:         #type proc(this: ^Entity),
	on_level_transfer:  #type proc(this: ^Entity),
	deserialize:        #type proc(blob: EntityBlob) -> ^Entity,
}

DaemonClass :: struct {
	id:          typeid,
	create:      #type proc(data: string) -> ^Daemon,
	on_update:   #type proc(this: ^Daemon, dt: f32),
	on_event:    #type proc(this: ^Daemon, event: Event),
	on_render:   #type proc(this: ^Daemon),
	on_destroy:  #type proc(this: ^Daemon),
	deserialize: #type proc(blob: DaemonBlob) -> ^Daemon,
}

GameTypeInformation :: struct {
	entity_classes: map[string]EntityClass,
	daemon_classes: map[string]DaemonClass,
}


RTTI: GameTypeInformation

deserialize_entity_proc :: proc($T: typeid) -> #type proc(blob: EntityBlob) -> ^Entity {
	out :: proc(blob: EntityBlob) -> ^Entity {
		tmp := new(T, engine_alloc())
		err := cbor.unmarshal(transmute([]u8)blob.data, tmp, allocator = engine_alloc())
		if err != nil {
			fmt.printf("%v\n", err)
		}
		assert(err == nil)
		return tmp
	}
	return out
}
deserialize_daemon_proc :: proc($T: typeid) -> #type proc(blob: DaemonBlob) -> ^Daemon {
	out :: proc(blob: DaemonBlob) -> ^Daemon {
		tmp := new(T, engine_alloc())
		err := cbor.unmarshal(transmute([]u8)blob.data, tmp, allocator = engine_alloc())
		if err != nil {
			fmt.printf("%v\n", err)
		}
		assert(err == nil)
		return tmp
	}
	return out
}

register_entity_class :: proc(
	$type: typeid,
	on_update: proc(this: ^Entity, delta_time: f32),
	on_render: proc(this: ^Entity),
	on_event: proc(this: ^Entity, event: Event),
	destructor: proc(this: ^Entity),
	on_level_transfer: proc(this: ^Entity),
	create_at_location_proc: #type proc(transform: Transform, data: string) -> ^Entity = nil,
) {
	info := type_info_of(type)
	name: string
	#partial switch v in info.variant {
	case runtime.Type_Info_Named:
		name = v.name
	case:
		fmt.eprintfln("ERROR CANNOT REGISTER AN UNNAMED TYPE\n")
		assert(false)
	}
	class: EntityClass
	class.on_update = on_update
	class.on_render = on_render
	class.on_event = on_event
	class.on_level_transfer = on_level_transfer
	class.id = type
	class.deserialize = deserialize_entity_proc(type)
	class.create_at_location = create_at_location_proc
	assert(name not_in RTTI.entity_classes)
	RTTI.entity_classes[name] = class
}

register_daemon_class :: proc(
	$type: typeid,
	on_update: #type proc(this: ^Daemon, dt: f32),
	on_event: #type proc(this: ^Daemon, event: Event),
	on_render: #type proc(this: ^Daemon),
	on_destroy: #type proc(this: ^Daemon),
	create_proc: #type proc(data: string) -> ^Daemon = nil,
) {
	info := type_info_of(type)
	name: string
	#partial switch v in info.variant {
	case runtime.Type_Info_Named:
		name = v.name
	case:
		fmt.eprintfln("ERROR CANNOT REGISTER AN UNNAMED TYPE\n")
		assert(false)
	}
	class: DaemonClass
	class.id = type
	class.on_update = on_update
	class.on_render = on_render
	class.on_destroy = on_destroy
	class.on_event = on_event
	class.create = create_proc
	class.deserialize = deserialize_daemon_proc(type)
	assert(name not_in RTTI.daemon_classes)
	RTTI.daemon_classes[name] = class
}


serialize_entity :: proc(entity: ^Entity, allocator: mem.Allocator) -> EntityBlob {
	an: any
	an.data = entity
	an.id = entity._type
	out: EntityBlob
	out.this_ref = entity.self_ref
	out.type_name = entity_type_name(entity)
	data, err := cbor.marshal(an, allocator = allocator)
	if err != nil {
		fmt.printf("%v\n", err)
	}
	assert(err == nil)
	out.data = transmute(string)data
	return out
}

deserialize_entity :: proc(entity_data: EntityBlob) -> ^Entity {
	type := RTTI.entity_classes[entity_data.type_name]
	out_entity := type.deserialize(entity_data)
	out_entity.self_ref = entity_data.this_ref
	out_entity._type = type.id
	out_entity.destructor = type.destructor
	out_entity.on_event = type.on_event
	out_entity.on_level_transfer = type.on_level_transfer
	out_entity.on_render = type.on_render
	out_entity.on_update = type.on_update
	return out_entity
}

serialize_daemon :: proc(daemon: ^Daemon, allocator: mem.Allocator) -> DaemonBlob {
	an: any
	an.data = daemon
	an.id = daemon._type
	out: DaemonBlob
	out.type_name = daemon_type_name(daemon)
	data, err := cbor.marshal(an, allocator = allocator)
	if err != nil {
		fmt.printf("%v\n", err)
	}
	assert(err == nil)
	out.data = transmute(string)data
	return out
}


deserialize_daemon :: proc(daemon_data: DaemonBlob) -> ^Daemon {
	type := RTTI.daemon_classes[daemon_data.type_name]
	out_daemon := type.deserialize(daemon_data)
	out_daemon._type = type.id
	out_daemon.on_event = type.on_event
	out_daemon.on_render = type.on_render
	out_daemon.on_update = type.on_update
	out_daemon.on_destroy = type.on_destroy
	return out_daemon
}

entity_type_name :: proc(et: ^Entity) -> string {
	info := type_info_of(et._type)
	name: string
	#partial switch v in info.variant {
	case runtime.Type_Info_Named:
		name = v.name
	case:
		fmt.eprintfln("ERROR HAS NO NAME:%v\n", et._type)
		assert(false)
	}
	return name
}

daemon_type_name :: proc(et: ^Daemon) -> string {
	info := type_info_of(et._type)
	name: string
	#partial switch v in info.variant {
	case runtime.Type_Info_Named:
		name = v.name
	case:
		fmt.eprintfln("ERROR HAS NO NAME:%v\n", et._type)
		assert(false)
	}
	return name
}

save_game_state :: proc(world: ^World, allocator: mem.Allocator) -> SaveStateBlob {
	entity_blobs := make([dynamic]EntityBlob, allocator)
	reserve(&entity_blobs, MAX_ENTITY_COUNT)
	daemon_blobs := make([dynamic]DaemonBlob, allocator)
	reserve(&daemon_blobs, len(world.daemons))
	system_blobs := make(map[string]string, allocator)
	reserve(&system_blobs, len(ENGINE.systems))
	for i in world.entities.entities {
		if i != nil {
			tmp := serialize_entity(i, allocator)
			append(&entity_blobs, tmp)
		}
	}
	for i in world.daemons {
		if i != nil {
			tmp := serialize_daemon(i, allocator)
			append(&daemon_blobs, tmp)
		}
	}
	for i, j in ENGINE.systems {
		data := j->on_save(allocator)
		if data != "" {
			system_blobs[strings.clone(i, allocator)] = data
		}
	}
	out: SaveStateBlob
	out.daemons = daemon_blobs[:]
	out.entities = entity_blobs[:]
	out.system_data = system_blobs
	return out
}

load_game_state :: proc(world: ^World, state: SaveStateBlob) {
	unload_world(world)
	for i in state.entities {
		tmp := deserialize_entity(i)
		assert(world.entities.entities[i.this_ref.idx] == nil)
		world.entities.entities[i.this_ref.idx] = tmp
		world.entities.generations[i.this_ref.gen] = i.this_ref.gen
	}
	for i in state.daemons {
		tmp := deserialize_daemon(i)
		append(&world.daemons, tmp)
	}
	for i, j in state.system_data {
		if i in ENGINE.systems {
			ENGINE.systems[i]->on_load(j)
		}
	}
}

_save_game_impl :: proc(path: string) {
	state := save_game_state(_get_world(), frame_alloc())
	jsn, err := cbor.marshal(state, allocator = frame_alloc())
	assert(err == nil)
	err2 := os.write_entire_file(path, jsn)
	assert(err2 == nil)
}

_load_game_impl :: proc(path: string) {
	base, err := os.read_entire_file(path, frame_alloc())
	assert(err == nil)
	blob: SaveStateBlob
	err2 := cbor.unmarshal(base, &blob, allocator = frame_alloc())
	assert(err2 == nil)
	load_game_state(_get_world(), blob)
}

save_game :: proc(path: string) {
	ENGINE.loader_state.save_path = strings.clone(path, frame_alloc())
	ENGINE.loader_state.should_save = true
}

load_game :: proc(path: string) {
	ENGINE.loader_state.load_path = strings.clone(path, frame_alloc())
	ENGINE.loader_state.should_load = true
}

handle_loading :: proc() {
	if ENGINE.loader_state.should_save {
		_save_game_impl(ENGINE.loader_state.save_path)
	}
	if ENGINE.loader_state.should_load {
		_load_game_impl(ENGINE.loader_state.load_path)
	}
}

transfer_level :: proc(level: LevelData) {
	ENGINE.loader_state.transfer_data = level
	ENGINE.loader_state.should_transfer = true
}

_transfer_level_impl :: proc(data: LevelData) {
	saved := make([dynamic]^Entity)
	defer delete(saved)
	world := _get_world()
	for &i in world.entities.entities {
		if .ShouldTransferLevel in i.tags {
			append(&saved, i)
			i = nil
		}
	}
	for i in saved {
		if i.on_level_transfer != nil {
			i->on_level_transfer()
		}
	}
	unload_world(world)
	for i in data.daemon_spawn_data {
		if i.name in RTTI.daemon_classes {
			if RTTI.daemon_classes[i.name].create != nil {
				tmp := RTTI.daemon_classes[i.name].create(i.data)
				register_daemon(tmp)
			} else {
				fmt.printf(
					"ERROR:attempt to spawn daemon class:%s with data:%s does not have creation api(registered create procedure)\n",
					i.name,
					i.data,
				)
			}
		} else {
			fmt.printf(
				"ERROR:attempt to spawn daemon class:%s with data:%s does not exist\n",
				i.name,
				i.data,
			)
		}
	}
	for i in data.entity_spawn_data {
		if i.class in RTTI.entity_classes {
			if RTTI.entity_classes[i.class].create_at_location != nil {
				v := RTTI.entity_classes[i.class].create_at_location(i.transform, i.custom_data)
				_unsafe_create_entity_by_pointer(v)
			} else {
				fmt.printf(
					"ERROR:attempt to spawn daemon class:%s with transform:%v data:%s does not have creation api(registered create procedure)\n",
					i.class,
					i.transform,
					i.custom_data,
				)
			}
		} else {
			fmt.printf(
				"ERROR:attempt to spawn daemon class:%s with transform:%v data:%s does not exist\n",
				i.class,
				i.transform,
				i.custom_data,
			)
		}
	}
	for i in data.mesh_spawn_data {
		spawn_mesh(i)
	}
	for i, idx in saved {
		_unsafe_create_entity_by_pointer(i)
		i.phys.trans = data.player_spawns[idx]
	}
}

spawn_mesh :: proc(data: MeshSpawnData) {
	rf, et := create_entity(Entity)
	et.control_rotation = Quat(1)
	et.mesh = clone_mesh(data.mesh, engine_alloc())
	et.health = 1
	et.phys.trans = data.transform
	et.phys.is_static = true
	et.phys.length = data.mesh.length
	et.phys.width = data.mesh.width
	et.phys.height = data.mesh.height
}
