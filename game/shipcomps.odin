package game
//import "engine"
//import "vendor:raylib"
ShipTileType :: enum {
	Armor,
	FuelTank,
	Engine,
	CockPit,
	PointDefenseWeapon,
	LaserCannon,
	TorpedoTube,
	Cabin,
}

ShipTile :: struct {
	type:              ShipTileType,
	health:            i16,
	damage_resistance: i16,
	pressure:          i16,
	temperature:       i16,
	is_on_fire:        bool,
}

SHIP_LENGTH :: 11
SHIP_WIDTH :: 5

ShipTileSet :: struct {
	tiles: [SHIP_LENGTH][SHIP_WIDTH][SHIP_WIDTH]ShipTile,
}

make_tile_by_type :: proc(type: ShipTileType) -> ShipTile {
	out: ShipTile
	out.type = type
	out.damage_resistance = 2
	out.health = 10
	out.pressure = 1000
	out.temperature = 290
	return out
}

base_ship_tile_set :: proc() -> ShipTileSet {
	out: ShipTileSet
	for &i in out.tiles {
		for &j in i {
			for &k in j {
				k = make_tile_by_type(.Armor)
			}
		}
	}
	return out
}


get_room :: proc(this: ^ShipTileSet, x: i32, y: i32, z: i32) -> ^ShipTile {
	x_act := x
	y_act := SHIP_WIDTH + y
	z_act := SHIP_WIDTH + z
	if (x_act) < 0 || x_act >= SHIP_LENGTH {
		return nil
	}
	if (y_act) < 0 || y_act >= SHIP_WIDTH {
		return nil
	}
	if (z_act) < 0 || z_act >= SHIP_WIDTH {
		return nil
	}
	return &this.tiles[x_act][y_act][z_act]
}

create_room :: proc(
	this: ^ShipTileSet,
	type: ShipTileType,
	center_x: i32,
	center_y: i32,
	center_z: i32,
	depth: i32,
	width: i32,
	height: i32,
) {
	min_x := center_x - depth / 2
	min_y := center_y - width / 2
	min_z := center_z - height / 2
	for x in min_x ..< min_x + depth {
		for y in min_y ..< min_y + width {
			for z in min_z ..< min_z + height {
				ptr := get_room(this, x, y, z)
				if ptr == nil {
					continue
				}
				ptr^ = make_tile_by_type(type)
			}
		}
	}
}
