
package engine

EntityBlob :: struct {
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
	class:     string,
	transform: Transform,
}

MeshSpawnData :: struct {
	mesh:      EntityMesh,
	transform: Transform,
}

DaemonSpawnData :: struct {
	name: string,
}

SystemInputData :: struct {
	target: string,
	data:   string,
}

LevelData :: struct {
	player_spawn:      Transform,
	entity_spawn_data: []EntitySpawnData,
	mesh_spawn_data:   []MeshSpawnData,
	daemon_spawn_data: []DaemonSpawnData,
}

EntityClass :: struct {
	id:                 typeid,
	create_at_location: #type proc(location: Vec3, rotation: Quat) -> ^Entity,
	serialize:          #type proc(this: ^Entity),
	deserialize:        #type proc(data: string) -> ^Entity,
}

DaemonClass :: struct {
	id:          typeid,
	create:      #type proc() -> ^Daemon,
	serialize:   #type proc(this: ^Daemon) -> string,
	deserialize: #type proc(data: string) -> ^Daemon,
}

GameTypeInformation :: struct {
	entity_classes: map[string]EntityClass,
	daemon_classes: map[string]DaemonClass,
}
